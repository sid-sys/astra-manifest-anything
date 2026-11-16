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
2. **Buying on iOS.** Code is done; setup is yours. The app sends the App
   Store transaction id to `verifyApplePurchase` (`functions/appstore.js`),
   which asks Apple's App Store Server API what state it is in. Apple's
   renewals and cancels arrive at `appStoreNotifications`. You need:
   - Two subscriptions in App Store Connect with ids `astra_plus_monthly` and
     `astra_plus_yearly`, a 7 day free trial as an introductory offer, and the
     same prices as Play.
   - An In-App Purchase key (App Store Connect, Users and Access, Integrations,
     In-App Purchase). Give the server its three values:
     `firebase functions:secrets:set APPSTORE_KEY_ID`,
     `APPSTORE_ISSUER_ID`, `APPSTORE_PRIVATE_KEY` (paste the whole `.p8`).
   - Then `firebase deploy --only functions:verifyApplePurchase,functions:appStoreNotifications`.
   - In App Store Connect, App Information, App Store Server Notifications:
     set the Production and Sandbox URL to the address of
     `appStoreNotifications` (Version 2).
3. **Sign in with Apple.** Done in the app. Needs the Apple provider switched on
   in Firebase (Service ID, Team ID, key) and deleting an Apple account revokes
   Apple's token.
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

### Automatic TestFlight upload (optional)

Set these three and the signed build sends itself to TestFlight. Without them
the `.ipa` is kept for one day instead.

| Secret | What it is |
| --- | --- |
| `ASC_KEY_ID` | Key ID of an App Store Connect API key (Team key, access "App Manager") |
| `ASC_ISSUER_ID` | The Issuer ID on the same page |
| `ASC_KEY_P8_BASE64` | That key's `.p8` file, base64 |

Make the key at https://appstoreconnect.apple.com/access/integrations/api
(Team Keys tab). It is a different key from the In-App Purchase key.

Never commit these files. This repository is public. Keep them in `signing/`,
which git ignores.
