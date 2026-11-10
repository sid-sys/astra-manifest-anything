# Mayow: what has been done so far

Written 18 October 2026, in plain words. The newest build is **1.0.7+49**.

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

## Admin panel (real data only, redesigned 21 October 2026)
- Follows `ADMIN_PANEL_PROMPT.md`. Brand colours (pink buttons and bars, yellow
  highlight), small logo, phone layout and a wide two-column layout.
- **Real users only** switch (on by default) hides your own account, the Play
  review login, Google test robots, automated sign-ups, licence-tester
  purchases and robots that finish onboarding in under 25 seconds, from every
  number. Tap the line to see who is hidden and why. Rules: `lib/admin/admin_config.dart`.
- Six number cards (each opens its people), one chart card with a toggle
  (Active users | Installs and uninstalls, 30 days, tap a bar to see the
  people), the install-to-subscribe funnel, why payments failed, and where
  people heard about us.
- All users (search, filters, sort by signed up / last seen / installed /
  uninstalled), one-user page (journey, what they told us, activity), and a
  feedback and bug list with a "handled" tick.
- New tracking: a daily phone report (`devices`), a daily uninstall check
  (Google dry run at 04:00 India time), open days, step times, payment failures,
  onboarding timing, a "where did you hear about us" question, and a
  Profile > "Send feedback or report a bug" box.
- Payments are still estimated from plan prices. Details and setup:
  `lib/admin/README.md`. Needs the functions deployed and a new app build.

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
2. Deploy the new functions and ship build 48, then publish the updated privacy page.
3. Test the release build on a phone: sign-in, audio, reminders, the admin panel.
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
