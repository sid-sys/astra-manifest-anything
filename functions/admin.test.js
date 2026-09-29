/**
 * The admin gate, checked without booting Firebase.
 *
 * Run with `node admin.test.js`. Like clean.test.js, this reads the function
 * out of index.js rather than importing it — importing initialises the Admin
 * SDK and defines secrets, and a test that needs credentials to check an if
 * statement is a test nobody runs.
 *
 * What is being checked is one distinction: an email address identifies an
 * account, and an account is not a way of signing in. Firebase keeps one
 * account per address, so an address that also carries a password can be
 * opened without Google ever being involved. Everything below is about the
 * gate noticing that.
 */
const assert = require("node:assert");
const fs = require("node:fs");

const source = fs.readFileSync(`${__dirname}/index.js`, "utf8");

const emailMatch = source.match(/const ADMIN_EMAIL = "([^"]+)"/);
assert.ok(emailMatch, "ADMIN_EMAIL not found in index.js");
const ADMIN_EMAIL = emailMatch[1];

const match = source.match(/function assertAdmin\(request\)[\s\S]*?\n}/);
assert.ok(match, "assertAdmin() not found in index.js");

/** Stand-ins for the two things assertAdmin reaches for. */
class HttpsError extends Error {
  constructor(code, message) {
    super(message);
    this.code = code;
  }
}
const logger = { warn() {} };

// eslint-disable-next-line no-eval
const assertAdmin = eval(
  `(${match[0].replace("function assertAdmin", "function")})`,
);

/** A verified ID token, as Firebase would present it to the function. */
const request = ({
  email = ADMIN_EMAIL,
  verified = true,
  provider = "google.com",
} = {}) => ({
  auth: {
    uid: "uid-under-test",
    token: {
      email,
      email_verified: verified,
      firebase: { sign_in_provider: provider },
    },
  },
});

const refuses = (name, input) => {
  // No token at all is "unauthenticated" — there is nobody to refuse yet. A
  // token that fails the checks is "permission-denied". Keyed off the token
  // rather than off `auth`, because an auth block without one is the first
  // case, not the second.
  const signedIn = Boolean(input.auth?.token);

  assert.throws(
    () => assertAdmin(input),
    (error) => {
      assert.ok(error instanceof HttpsError, `${name}: wrong error type`);
      assert.strictEqual(
        error.code,
        signedIn ? "permission-denied" : "unauthenticated",
        `${name}: wrong code`,
      );
      // Same words whoever asks. "Wrong provider" would tell a stranger the
      // address was right and what to try next.
      assert.strictEqual(
        error.message,
        signedIn ? "Not available." : "Sign in first.",
        `${name}: message leaks why`,
      );
      return true;
    },
    `${name}: was allowed through`,
  );
};

// ------------------------------------------------------------------- allowed

assert.doesNotThrow(
  () => assertAdmin(request()),
  "the admin signed in with Google was refused",
);

// ------------------------------------------------------------------ refused

// The case this gate exists for. Same account, same verified address, opened
// with a password instead — which is what an email-only check would allow.
refuses("admin address over password", request({ provider: "password" }));

refuses("admin address as a guest", request({ provider: "anonymous" }));

refuses(
  "somebody else's Google account",
  request({ email: "someone.else@gmail.com" }),
);

// Near-misses on the address itself. There is a real sidharthbabu96@gmail.com
// on this project, so this is not hypothetical.
refuses("a similar address", request({ email: "sidharthbabu96@gmail.com" }));
refuses(
  "the address with different case",
  request({ email: ADMIN_EMAIL.toUpperCase() }),
);
refuses("the address with a suffix", request({ email: `${ADMIN_EMAIL}.uk` }));

refuses("an unverified address", request({ verified: false }));

// Built by hand rather than through the helper above: passing `undefined` to a
// default parameter takes the default, so `request({ verified: undefined })`
// would quietly test a verified token and pass for the wrong reason.
refuses("a token with no verified claim", {
  auth: {
    uid: "uid-under-test",
    token: { email: ADMIN_EMAIL, firebase: { sign_in_provider: "google.com" } },
  },
});

refuses("a token with no provider", {
  auth: {
    uid: "uid-under-test",
    token: { email: ADMIN_EMAIL, email_verified: true, firebase: {} },
  },
});

refuses("a token with no firebase claims at all", {
  auth: {
    uid: "uid-under-test",
    token: { email: ADMIN_EMAIL, email_verified: true },
  },
});

refuses("nobody signed in at all", {});
refuses("an auth block with no token", { auth: { uid: "x" } });

console.log("admin gate: all cases pass");
