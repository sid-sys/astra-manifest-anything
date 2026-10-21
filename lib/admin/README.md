# Admin panel

Real data only: there is no mock or sample data anywhere in the app. Every
number comes from the `adminOverview` Cloud Function, or the panel shows an
error.

## Screens

| Screen | File |
| --- | --- |
| Dashboard (switch, six number cards, one chart card with a toggle, funnel, payment failures, sources) | `dashboard_screen.dart` |
| A list of people (all users, or the people behind a card, a bar or a reason) | `users_screen.dart` |
| One person (header, journey, what they told us, activity) | `user_detail_screen.dart` |
| Feedback and bug reports, with a "handled" tick | `admin_feedback_screen.dart` |
| Old tools (announcements, grant trial, delete account) | `../screens/admin_screen.dart` |

Tapping a number card, a chart bar, a failure reason or a source opens the real
people behind it. Names are the real name, else the real email, else
`Guest 3f9a2c`, else `No name`. Nothing is ever invented.

## Where to change things: `admin_config.dart`

- `adminEmail`: the one account that sees the panel.
- **"Real users only" rules**: `reviewEmails`, `testRobotDomains`,
  `automatedEmailPatterns`, `minOnboardingSeconds`. The rules themselves are in
  `admin_filter.dart` (`hiddenReason`), first match wins:
  1. your own account, 2. the Play review login, 3. a Google test-robot domain,
  4. a robot sign-up (name is the review email, or `testuser123@...`),
  5. a licence-tester purchase (Play says `testPurchase`),
  6. onboarding finished in under 25 seconds.
- Prices (from `PricingCatalog`), the store cut, AI costs, fixed monthly bills.
  **The fixed bills are estimates: replace them with your real bills.**

## How installs and uninstalls are counted

- The app reports once a day (`DeviceService`, `reportDevice` function). The
  server keeps **one record per phone** in `devices/{installId}`: a random id the
  app makes the first time, the install time Android reports for the package,
  the account that last signed in, the push address, and when it was last seen.
- **Installed** on day D: a phone whose install time is on day D. The person
  shown is its owner.
- **Uninstalled**: `checkUninstalls` runs daily at 04:00 (India time). It asks
  Google to validate every push address as a dry run (nothing is delivered,
  nobody is told). Only Google's own "not registered" or "invalid" answer marks
  a phone uninstalled with that day. If the phone reports in again later, the
  mark is removed.
- Limits: an uninstall can show a day or two late. Only Android phones that
  signed in are counted. **People who installed and never opened the app are not
  visible to us at all**: Play Console shows those installs.
- The `devices` collection is not in the Firestore rules, so no client can
  write or read it. Only Cloud Functions touch it.
- All days are UTC days.

## What else the app now records (server, `trackEvent`)

`steps.*` (first time each step happened), `openDays` (UTC dates the app was
opened), `recent` (last 60 events), `payFailures` (cancelled, failed, store not
available), and the onboarding timing (`onboarding_start`, `onboarding_page`,
`onboarding_done`). New onboarding question: where did you hear about Mayow
(`heardFrom` on the profile). New: Profile > "Send feedback or report a bug"
(`submitFeedback` function, `feedback` collection).

## Security

The Profile > Admin entry is only shown to `adminEmail`. **That is a courtesy,
not protection.** The server checks it again:

- `adminOverview`, `adminFeedback`, `adminSetFeedbackHandled`, `adminGrantTrial`,
  `adminDeleteAccount`, `adminBroadcast` and `adminCleanOldFields` all call
  `assertAdmin`: the verified token must carry the admin email, a verified
  email, and the `google.com` sign-in provider. Nothing the app sends is trusted.
- The panel is read-only except the "handled" tick on feedback.
- Any new Firestore collection or function that serves this data must repeat the
  same check. Never rely on the app to hide a button.

## What is estimated

Google Play does not hand over receipts, so **payments are estimated** from each
subscriber's plan, start and end, at the store prices, with the first charge
after the 7-day free trial. A licence-tester purchase is never counted as money.
Revenue is "paid in the last 30 days"; costs are the AI calls made in the last
30 days plus the fixed bills.

## Setup you must do yourself

1. Deploy the functions: `reportDevice`, `checkUninstalls`, `submitFeedback`,
   `adminFeedback`, `adminSetFeedbackHandled`, `adminOverview`, `trackEvent`,
   `verifyPurchase`.
2. Ship the new app build, so phones start reporting (installs only appear from
   then on).
3. Publish the updated privacy page (it now says the app records a random
   install id, the install time and the push address).
4. Replace the fixed monthly bills in `admin_config.dart` with your real ones.
