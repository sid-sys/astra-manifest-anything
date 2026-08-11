# Play Console: subscriptions and the internal testing track

Everything in this file has to be done by hand in the Play Console by the
account owner. None of it can be scripted from here, and two steps involve a
signing key that should never exist anywhere but your machine and your password
manager.

The order matters. Billing cannot be tested until all five steps are done, and
each one fails silently in a different way if the one before it was skipped.

---

## 0. Before anything: the upload key

`android/key.properties` does not exist, so a release build today is signed with
the debug key and Play rejects it at upload. Generate the keystore yourself —
nobody else should ever have typed these passwords:

```bash
keytool -genkey -v -keystore %USERPROFILE%\astra-upload.jks -storetype JKS -keyalg RSA -keysize 2048 -validity 10000 -alias astra
```

Then create `android/key.properties` (already gitignored, and it must stay that
way):

```
storePassword=<what you just typed>
keyPassword=<what you just typed>
keyAlias=astra
storeFile=C:/Users/<you>/astra-upload.jks
```

Back the `.jks` file up somewhere you will still have it in five years. It is
the app's identity on Play permanently: lose it and you cannot ship an update to
your own listing, under any circumstances, ever. Play App Signing softens this —
enrol when prompted at first upload — but the upload key is still yours to keep.

Then:

```bash
flutter build appbundle --release
```

The bundle lands at `build/app/outputs/bundle/release/app-release.aab`.

---

## 1. Create the two subscriptions

Play Console → **Monetise → Products → Subscriptions → Create subscription**.

The product ids must match these strings exactly. They are hardcoded in
`lib/services/billing_service.dart` and allowlisted in `functions/index.js`; a
typo means the paywall finds no product and shows "Purchases are not available
on this device yet."

| Product ID             | Name        | Base plan ID       | Billing period |
| ---------------------- | ----------- | ------------------ | -------------- |
| `astra_plus_monthly`   | Astra Plus  | `monthly-autorenew`| 1 month        |
| `astra_plus_yearly`    | Astra Plus  | `yearly-autorenew` | 1 year         |

For each base plan: **auto-renewing**, no free trial, no introductory price.
(There is no trial anywhere in this product on purpose — three free stories is
the trial, and it has no clock to expire.)

Prices, matching `lib/models/plan.dart`:

| Base plan | India (INR) | United States (USD) |
| --------- | ----------- | ------------------- |
| Monthly   | ₹649        | $7.99               |
| Yearly    | ₹6,499      | $79.99              |

Set those two explicitly and let Play convert the rest. Then **activate** both
base plans — a subscription created but left inactive is invisible to the app
and produces exactly the same error as one that does not exist.

---

## 2. Let the server check receipts

This is the step that is easiest to skip and hardest to diagnose, because
everything looks fine until a real purchase is refused.

`verifyPurchase` asks the Play Developer API whether a purchase token is real,
authorised as the Cloud Functions service account. Without access it fails
closed: the user is charged by Google and gets no subscription.

The account is:

```
78503123511-compute@developer.gserviceaccount.com
```

1. Play Console → **Users and permissions → Invite new users**
2. Email: the address above
3. App permissions: add **Astra** only
4. Grant **View financial data, orders, and cancellation survey responses**
5. Also enable the Google Play Android Developer API for the
   `astra-manifest` project if it is not already on:
   <https://console.cloud.google.com/apis/library/androidpublisher.googleapis.com?project=astra-manifest>

Permission changes take up to 24 hours to propagate. Do this first, not last.

---

## 3. Upload to internal testing

Play Console → **Testing → Internal testing → Create new release**.

Upload the `.aab`. Internal testing needs no review, so the track is live within
minutes — but the *first ever* upload for a new app still has to clear the app
listing requirements, and Play will refuse to activate any track until the Data
Safety form and content rating questionnaire are complete. Those are still
outstanding.

Add testers by email under **Testers → Create email list**, then share the opt-in
URL Play gives you. Each tester has to open that URL and accept before Play will
show them the app.

---

## 4. Add licence testers

Play Console → **Setup → Licence testing** → add the same email addresses.

This is what makes purchases free and instantly renewable during testing. A
licence tester's monthly subscription renews every five minutes and cancels
without a refund request, which is the only practical way to exercise renewal
and expiry.

---

## Why billing cannot be verified before all of this

The paywall's failure path is deliberately indistinguishable from every cause,
so it is worth naming what each one looks like:

- **Products not created, or not activated** → the store returns no products,
  the paywall says "Purchases are not available on this device yet."
- **App sideloaded rather than installed from a Play track** → Play Billing
  refuses to initialise at all. Same message. This is why an APK built here and
  copied to a phone can never test billing, no matter how it is signed.
- **Service account not granted financial access** → the purchase *succeeds*,
  Google charges the card, and `verifyPurchase` throws. The user sees "We could
  not confirm that purchase with Google Play." This is the expensive one.

All three produce a user who paid nothing or paid twice, and only the third
costs anyone money — which is the argument for doing step 2 before step 3.
