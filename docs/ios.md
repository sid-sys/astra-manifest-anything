# Mayow on iOS

The iOS project builds on GitHub Actions (`.github/workflows/ios.yml`). This
page says what works, what does not yet, and what you must set up yourself.

## What the workflow does

- **unsigned** (every push to `master` that touches the app): builds the iOS
  app with no signing, to prove it compiles. Download `Runner-unsigned` from the
  run page. It cannot be installed on a phone or sent to the App Store.
- **signed** (by hand): builds an `.ipa` for TestFlight and the App Store.
  Actions, "iOS build", Run workflow, tick "Build a signed .ipa". Download
  `Mayow-ipa` from the run page, then upload it with Apple's Transporter app.

## What iOS still needs before it can ship

These are not done. The app compiles for iOS but would not work yet.

1. **Firebase for iOS.** `lib/firebase_options.dart` has no iOS entry, so the
   app stops at start-up on an iPhone. In the Firebase console add an iOS app
   with bundle id `live.coreinteractive.mayow`, then run `flutterfire configure` and
   commit the new `firebase_options.dart`. Keep `GoogleService-Info.plist` out
   of git; give it to the workflow as the secret below.
2. **Buying on iOS.** The server (`verifyPurchase`, `playNotifications`) only
   understands Google Play. An App Store purchase would never be verified, so
   the paywall would never open for an iPhone user. Needs App Store Server
   API verification and notifications, and App Store products for the plans.
3. **Sign in with Apple.** Apple requires it when an app offers Google sign-in.
4. **Apple Developer account** (paid) and an app record in App Store Connect.

## Secrets for the signed build

Repository, Settings, Secrets and variables, Actions:

| Secret | What it is |
| --- | --- |
| `IOS_CERT_P12_BASE64` | Your Apple Distribution certificate, exported as `.p12`, then base64 |
| `IOS_CERT_PASSWORD` | The password you set when exporting the `.p12` |
| `IOS_PROFILE_BASE64` | The App Store provisioning profile for `live.coreinteractive.mayow`, base64 |
| `IOS_TEAM_ID` | Your 10-character Apple team id |
| `GOOGLE_SERVICE_INFO_PLIST_BASE64` | `GoogleService-Info.plist` from Firebase, base64 |

To make base64 on Windows (PowerShell):

```powershell
[Convert]::ToBase64String([IO.File]::ReadAllBytes("C:\path\to\file")) | Set-Clipboard
```

Never commit these files. This repository is public.
