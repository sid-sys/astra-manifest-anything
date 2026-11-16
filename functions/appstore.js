/**
 * App Store (iPhone and iPad) purchases.
 *
 * Kept apart from `verifyPurchase` on purpose: these functions need three App
 * Store secrets, and a missing secret stops a deploy. Android purchases must
 * never depend on them.
 *
 * The app sends a transaction id. The server asks Apple's App Store Server API
 * what state that subscription is in, and trusts only Apple's answer. The
 * entitlement has the same shape as the Google one (`isSubscribed`,
 * `expiryTime`, ...) plus `store: "apple"`, so the rest of the app does not
 * care which store sold it. `purchaseToken` holds `ios:<originalTransactionId>`.
 */

const { onCall, onRequest, HttpsError } = require("firebase-functions/v2/https");
const { defineSecret } = require("firebase-functions/params");
const logger = require("firebase-functions/logger");
const crypto = require("crypto");

const APPSTORE_KEY_ID = defineSecret("APPSTORE_KEY_ID");
const APPSTORE_ISSUER_ID = defineSecret("APPSTORE_ISSUER_ID");
const APPSTORE_PRIVATE_KEY = defineSecret("APPSTORE_PRIVATE_KEY");

/** Must match the bundle id in ios/Runner.xcodeproj. */
const IOS_BUNDLE_ID = "live.coreinteractive.mayow";

const HOSTS = [
  { url: "https://api.storekit.itunes.apple.com", sandbox: false },
  { url: "https://api.storekit-sandbox.itunes.apple.com", sandbox: true },
];

const SECRETS = [APPSTORE_KEY_ID, APPSTORE_ISSUER_ID, APPSTORE_PRIVATE_KEY];

const b64url = (input) => Buffer.from(input).toString("base64url");

/** The signed token Apple wants on every App Store Server API call. */
function apiToken() {
  const header = { alg: "ES256", kid: APPSTORE_KEY_ID.value(), typ: "JWT" };
  const now = Math.floor(Date.now() / 1000);
  const payload = {
    iss: APPSTORE_ISSUER_ID.value(),
    iat: now,
    exp: now + 600,
    aud: "appstoreconnect-v1",
    bid: IOS_BUNDLE_ID,
  };
  const body = `${b64url(JSON.stringify(header))}.${b64url(JSON.stringify(payload))}`;
  const signature = crypto.sign("sha256", Buffer.from(body), {
    key: APPSTORE_PRIVATE_KEY.value().replace(/\\n/g, "\n"),
    dsaEncoding: "ieee-p1363",
  });
  return `${body}.${signature.toString("base64url")}`;
}

/** Reads the middle of a JWS. Safe here: it came straight from Apple over TLS. */
function decodeJws(jws) {
  try {
    return JSON.parse(
      Buffer.from(String(jws).split(".")[1], "base64url").toString("utf8"),
    );
  } catch {
    return null;
  }
}

/**
 * Asks Apple about one subscription. Production first, then the sandbox,
 * because TestFlight and App Review purchases live in the sandbox.
 * Returns null when Apple does not know the transaction.
 */
async function fetchSubscription(transactionId) {
  for (const host of HOSTS) {
    const response = await fetch(
      `${host.url}/inApps/v1/subscriptions/${encodeURIComponent(transactionId)}`,
      { headers: { Authorization: `Bearer ${apiToken()}` } },
    );
    // 404: this transaction belongs to the other environment. Try the next.
    if (response.status === 404) continue;
    if (!response.ok) {
      throw new Error(
        `App Store API ${response.status}: ${(await response.text()).slice(0, 300)}`,
      );
    }
    const data = await response.json();
    for (const group of data.data ?? []) {
      for (const last of group.lastTransactions ?? []) {
        const tx = decodeJws(last.signedTransactionInfo);
        if (!tx || tx.bundleId !== IOS_BUNDLE_ID) continue;
        return {
          status: last.status,
          tx,
          renewal: decodeJws(last.signedRenewalInfo) ?? {},
          sandbox: host.sandbox,
        };
      }
    }
    return null;
  }
  return null;
}

/** Turns Apple's answer into the fields the Google path also stores. */
function toFields(found) {
  const { status, tx, renewal } = found;
  // 1 active, 2 expired, 3 billing retry, 4 grace period, 5 revoked.
  const active = status === 1 || status === 4;
  const cancelled = active && renewal.autoRenewStatus === 0;
  let state = "SUBSCRIPTION_STATE_EXPIRED";
  if (status === 1) {
    state = cancelled
      ? "SUBSCRIPTION_STATE_CANCELED"
      : "SUBSCRIPTION_STATE_ACTIVE";
  } else if (status === 4) {
    state = "SUBSCRIPTION_STATE_IN_GRACE_PERIOD";
  } else if (status === 3) {
    state = "SUBSCRIPTION_STATE_ON_HOLD";
  }
  return {
    active,
    state,
    productId: tx.productId,
    originalTransactionId: String(tx.originalTransactionId),
    expiry: tx.expiresDate ? new Date(tx.expiresDate).toISOString() : null,
    started: tx.originalPurchaseDate
      ? new Date(tx.originalPurchaseDate).toISOString()
      : null,
    sandbox: found.sandbox,
  };
}

/**
 * Builds the two App Store functions. The helpers come from `index.js`, so
 * this file does not start a second copy of Firebase.
 */
module.exports = function appStoreFunctions({
  admin,
  entitlementDoc,
  assertRateLimit,
  VERIFY_LIMITS,
  PLAY_SUBSCRIPTIONS,
  TRIAL_WINDOW_DAYS,
  notifyAdminSubscribed,
}) {
  async function writeEntitlement(uid, fields, extra = {}) {
    await entitlementDoc(uid).set(
      {
        store: "apple",
        isSubscribed: fields.active,
        productId: fields.productId,
        purchaseToken: `ios:${fields.originalTransactionId}`,
        expiryTime: fields.expiry,
        subscribedAt: fields.started ?? new Date().toISOString(),
        state: fields.state,
        testPurchase: fields.sandbox,
        verifiedAt: new Date().toISOString(),
        ...extra,
      },
      { merge: true },
    );
  }

  const verifyApplePurchase = onCall(
    { timeoutSeconds: 60, memory: "256MiB", secrets: SECRETS },
    async (request) => {
      const uid = request.auth?.uid;
      if (!uid) {
        throw new HttpsError("unauthenticated", "Sign in to restore a purchase.");
      }
      await assertRateLimit(uid, "verify", VERIFY_LIMITS);

      const { productId, transactionId } = request.data ?? {};
      if (!PLAY_SUBSCRIPTIONS.has(productId)) {
        throw new HttpsError("invalid-argument", "Unknown product.");
      }
      if (
        typeof transactionId !== "string" ||
        !/^\d{6,20}$/.test(transactionId)
      ) {
        throw new HttpsError("invalid-argument", "Missing transaction id.");
      }

      let found;
      try {
        found = await fetchSubscription(transactionId);
      } catch (error) {
        logger.error("App Store verification failed", {
          uid,
          productId,
          reason: String(error?.message ?? error),
        });
        throw new HttpsError(
          "permission-denied",
          "We could not confirm that purchase with the App Store. If you " +
            "were charged, contact support and nothing will be lost.",
        );
      }
      if (!found || !PLAY_SUBSCRIPTIONS.has(found.tx.productId)) {
        throw new HttpsError(
          "permission-denied",
          "The App Store has no such subscription.",
        );
      }

      const fields = toFields(found);
      const token = `ios:${fields.originalTransactionId}`;

      // One Apple subscription belongs to one account.
      const existing = await admin
        .firestore()
        .collectionGroup("private")
        .where("purchaseToken", "==", token)
        .limit(2)
        .get();
      if (existing.docs.some((doc) => doc.ref.parent.parent?.id !== uid)) {
        logger.warn("Apple subscription presented by a second account", { uid });
        throw new HttpsError(
          "permission-denied",
          "That purchase is already linked to another account.",
        );
      }

      await writeEntitlement(uid, fields);

      if (
        fields.active &&
        fields.started &&
        Date.now() - Date.parse(fields.started) < 2 * 86400000
      ) {
        await notifyAdminSubscribed({
          uid,
          productId: fields.productId,
          purchaseToken: token,
          test: fields.sandbox,
          trial:
            Date.now() <
            Date.parse(fields.started) + TRIAL_WINDOW_DAYS * 86400000,
        });
      }

      logger.info("Apple purchase verified", {
        uid,
        productId,
        active: fields.active,
      });
      return { isSubscribed: fields.active, expiryTime: fields.expiry };
    },
  );

  /**
   * App Store Server Notifications (version 2). Apple calls this address when a
   * subscription renews, is cancelled, expires or is refunded.
   *
   * The body is NOT trusted. It only tells us which subscription changed; the
   * real state is then read from Apple's own API, so a forged request can do no
   * harm.
   */
  const appStoreNotifications = onRequest(
    { timeoutSeconds: 60, memory: "256MiB", secrets: SECRETS },
    async (req, res) => {
      try {
        const outer = decodeJws(req.body?.signedPayload);
        const data = outer?.data;
        const txInfo = decodeJws(data?.signedTransactionInfo);
        if (!txInfo?.transactionId || data?.bundleId !== IOS_BUNDLE_ID) {
          res.status(200).send("ignored");
          return;
        }

        const found = await fetchSubscription(String(txInfo.transactionId));
        if (!found) {
          res.status(200).send("unknown");
          return;
        }
        const fields = toFields(found);
        const token = `ios:${fields.originalTransactionId}`;

        const owner = await admin
          .firestore()
          .collectionGroup("private")
          .where("purchaseToken", "==", token)
          .limit(2)
          .get();
        const doc = owner.docs.find((d) => d.id === "entitlement");
        if (!doc) {
          // The app has not verified this purchase yet. It will when it opens.
          res.status(200).send("no owner yet");
          return;
        }
        const uid = doc.ref.parent.parent.id;
        await writeEntitlement(uid, fields, {
          lastBillingEvent: {
            type: outer.notificationType ?? "unknown",
            at: new Date().toISOString(),
          },
        });
        logger.info("App Store notification applied", {
          uid,
          type: outer.notificationType,
          active: fields.active,
        });
        res.status(200).send("ok");
      } catch (error) {
        logger.error("App Store notification failed", {
          reason: String(error?.message ?? error),
        });
        // A 500 makes Apple try again later.
        res.status(500).send("error");
      }
    },
  );

  return { verifyApplePurchase, appStoreNotifications };
};
