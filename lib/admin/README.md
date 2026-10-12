# Admin panel

Three screens (dashboard, users, one user) that read only from an
`AdminRepository`. Nothing in a screen knows whether the data is real.

| File | What it is |
| --- | --- |
| `admin_config.dart` | The admin email, store prices, store cut and every cost. **Edit costs here.** |
| `admin_models.dart` | `AdminUser`, `AdminEvent`, `AdminPayment`, `AdminStats` |
| `admin_repository.dart` | The abstract `AdminRepository` and the providers |
| `mock_admin_repository.dart` | About 50 made-up users from a fixed seed |
| `real_admin_repository.dart` | The real users, from the `adminOverview` Cloud Function |
| `admin_stats.dart` | Every dashboard number, worked out from the user list |

## Mock data and the `MOCK` flag

```
flutter run                                  # MOCK=true: everyone sees the panel, made-up data
flutter build appbundle --release --dart-define=MOCK=false
```

In a mock build **every signed-in user** can open Profile > Admin and sees a
"MOCK DATA" tag. A release build must set `MOCK=false`. As a second guard, the
default is `false` whenever the build is a release build, so forgetting the flag
shows nothing to the public rather than sample data.

## Hiding the button is NOT security

The Profile > Admin entry is only shown to `AdminConfig.adminEmail` in a real
build. That is a courtesy, not protection: an APK can be edited to show the
button to anyone.

**Whoever adds real data must make the server check the caller:**

- The `adminOverview`, `adminGrantTrial`, `adminDeleteAccount`, `adminBroadcast`
  and `adminCleanOldFields` Cloud Functions already refuse everyone except the
  admin account signed in with Google (`functions/index.js`, `ADMIN_EMAIL`).
- Any new Firestore collection, rule, Cloud Function or API that serves this
  data (for example `users/{uid}/events` when events are sent to Firestore) must
  check `request.auth.token.email == ADMIN_EMAIL` and `sign_in_provider ==
  google.com` itself. Never rely on the app to hide the button.
- Firestore rules: reading other users' documents must stay denied to every
  client; the admin reads through a Cloud Function with the Admin SDK.

## What is estimated in the real data

The server stores counts, not a timeline, and not receipts. So in a real build:

- **Payments** are estimated from the plan and its start date, at the prices in
  `AdminConfig`. The dashboard says so.
- **Events** are rebuilt from what is stored (wishes typed, things made,
  subscription start). To get a true timeline, send every
  `AnalyticsService.log` call to `users/{uid}/events` (see that file).

## Analytics

`AnalyticsService.log(type, detail)` counts events on the phone. `TrackingService`
calls it for: opened, onboarding_done, wish_typed, paywall_view, payment_attempt,
subscribed, and the manifestation and affirmation events.
