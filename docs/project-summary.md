# Mayow: what has been done so far

Written 18 October 2026, in plain words. The newest build is **1.0.7+47**.

## What the app is
Mayow (store name: "Personal Manifestation: Mayow", package `com.astraapp.astra`)
turns a typed wish into a personal audio manifestation, and writes five
affirmations. Flutter app, Firebase backend (project `astra-manifest`, functions
in `asia-south1`).

## Product and money
- **Free trial 7 days.** During the trial: 10 manifestations. After the trial: up
  to 60 a month. Affirmations are always free.
- **New accounts stop at the paywall.** They cannot reach the app without
  starting the trial. Accounts made before build 40 are not affected.
- **Countdown.** After the 10 trial manifestations, Home shows a live countdown
  to the end of the trial, for example `4D:21H:22M:20S`.
- **Trial reminder.** A notification goes out the day before the trial ends,
  with a way to cancel in Google Play. The paywall asks for notification
  permission and says why. The email version is written but switched off.
- **Prices:** $7.99 a month, $79.99 a year.
- **Voice and writing.** Manifestations are read by ElevenLabs (Turbo). Writing
  uses `gpt-5.6-luna` (manifestations, the four questions, affirmations).
  OpenAI "sage" is still used for stories.
- **Cost per manifestation about $0.124** (voice $0.112). At the 60-a-month cap
  the monthly plan keeps about 6% and the yearly plan loses about 12%, before
  Google's cut. At the 6 a month a real subscriber uses, margin is about 88%.
  Details in `docs/pricing-model.md`.

## Look and feel
- New violet design, 3D cat mascot (six poses), new icons, new logo and splash.
- The Play Store icon is also the launcher icon and the splash image.
- Streak card uses Google's animated fire emoji (credited in the licences page).
- Onboarding asks for notifications with a clear reason.

## Bugs fixed along the way
- Pause did not work, and music played over a silent or failed voice.
- Trial start reset every time the app opened (now uses Play's start time).
- Home Continue button did nothing on an empty box (now says "Use this idea").
- Several text and layout fixes; globe removed from "Writing your story".

## Admin panel (real data only)
- Dashboard: users, subscribers, active today, revenue, profit before and after
  Google's cut, a 14-day active chart, the joining-to-subscribing funnel.
- Users list with search and filters, and a detail page for each person.
- Only `sidharthbabu9@gmail.com` signed in with Google sees it, and the server
  checks the same thing again. Notes in `lib/admin/README.md`.
- Payments are estimated from plan prices (the server keeps no receipts).
- Each user is marked NEW APP or OLD APP (build 40 or newer).
- Old tools (announcements, grant trial, delete account) are behind a button.

## Play Store and legal
- Ready to upload, in `store/play/`: the `.aab` and `mapping` file, 512px app
  icon, 1024x500 feature graphic, phone and tablet screenshots, title and
  descriptions. `store/play/README.md` lists them.
- Release build has code shrinking and hiding switched on (65% of classes
  renamed). It has no guest login.
- Legal pages live in the public repo `sid-sys/policies` (privacy, terms,
  account deletion). Updated for the new name, the trial, and ElevenLabs/OpenAI.
- Creator-partner plan (ad text, form, agreement outline): `docs/creator-partner.md`.

## Deployed to Firebase
All functions, including `writeManifest` with the ElevenLabs voice,
`trialEndingNotice`, `adminOverview` and `trackEvent`. Hosting has the legal
pages.

## Still to do
1. In Play Console: set the free trial to **7 days** on both plans, upload the
   `.aab` and `mapping` file, paste the new title and descriptions, and update
   the subscription names and benefits.
2. Test the release build on a phone: sign-in, audio, reminders, the admin panel.
3. Delete the 3 test guest accounts in Firebase (listed in the chat history).
4. Replace the guessed fixed costs in `lib/admin/admin_config.dart` with real bills.
5. Decide about the thin margin at the 60-a-month cap (cheaper voice for the trial,
   or a lower cap).
6. Send each event to Firestore (`users/{uid}/events`) for a true timeline.
7. Optional: the email reminder (needs a mailbox and two secrets).

## How to build
```
flutter test
flutter build appbundle --release
```
Raise the number after `+` in `pubspec.yaml` and `kAppBuild` in
`lib/app_build.dart` together before each upload.
