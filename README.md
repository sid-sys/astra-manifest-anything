# Astra — Manifest Anything

An AI manifestation app for Android: it writes first-person audio narratives set
in the life you're working toward, then plays them back as a nightly ritual.

Flutter + Firebase. Built after a review study of the iOS app *Stella — Manifest
Anything*, so several product decisions here are direct answers to what that
app's users complained about — see [Product decisions](#product-decisions).

## Running it

```bash
flutter pub get
flutter run
```

The app runs with no account and no network. Firebase is used for backup and
cross-device restore only; if it fails to start, storage falls back to the
device and nothing is blocked.

## Firebase

Project `astra-manifest`
([console](https://console.firebase.google.com/project/astra-manifest/overview)).
Android and web apps are registered and `lib/firebase_options.dart` is checked
in. Firestore lives in `asia-south1` with owner-only rules
([firestore.rules](firestore.rules)) — a user can read and write only documents
under their own uid.

Deploy rules with:

```bash
firebase deploy --only firestore
```

**One manual step remains:** enable Anonymous sign-in in the console under
Authentication → Sign-in method. Until that's on, `AuthService.signInSilently`
returns null and the app stays local-only — working, but not syncing.

## Layout

| Path | What lives there |
| --- | --- |
| `lib/models/` | `Story`, `JournalEntry`, `UserProfile`, `Plan` + the pricing table |
| `lib/services/` | Story generation, playback, region resolution, storage, auth |
| `lib/screens/` | One file per screen; `shell_screen.dart` is the five-tab frame |
| `lib/widgets/` | The shared design-system pieces |
| `lib/theme/` | Palette, type scale, spacing |
| `design/mockup.html` | The reference mockup all of the above was built from |

## Product decisions

Each of these is a response to a specific, repeated complaint in the reviews of
the app this one is modelled on.

**The paywall comes after the value, not before it.** Reviewers' loudest
complaint was being asked for detailed personal information and then hitting a
subscription wall before hearing anything. Astra grants one complete story on
the free tier, and the onboarding flow says so on every step.

**Prices always name the period they bill on.** A one-star theme was a price
displayed as monthly that charged weekly. `Plan.headline` cannot render an
amount without its period, and a test asserts that. The yearly tile prints its
own monthly equivalent so no comparison needs arithmetic.

**Pricing resolves by region.** India is priced in rupees, everywhere else in
dollars. The country comes from the device locale — no IP geolocation, no
network call, no personal data leaving the device — and Settings lets the user
correct it. Adding a region is a data change in `PricingCatalog`, never a UI
change.

**Playback is the product, so it has to be solid.** Three-star reviews were
almost entirely playback bugs: stories cutting off, refresh not working.
`PlaybackController` supports looping and a queue (both frequently requested and
absent from the original), and when a story's narration audio isn't ready it
runs a virtual clock and shows the script to read along rather than failing.

**No daily listen cap.** Paying subscribers of the original could generate 12
stories but play only 3 a day. A story you own here plays as often as you like.

**A journal.** Reviewers noted the absence of journaling or action-planning.
The evidence log is a first-class tab.

## Status

The story generator (`lib/services/story_generator.dart`) composes text on the
device — it is a stand-in with the same signature as the real path, which is a
Cloud Function calling the Claude API for the script and a TTS voice for the
audio, so no API key ships in the app. Until that lands, `Story.audioUrl` is
null and the player reads the script.

Play Billing is not wired: the paywall grants the plan locally so the rest of
the app can be exercised.

## Tests

```bash
flutter test
```

Covers the pricing rules per region and the onboarding gate.
