# Play Store listing — Astra

Written against the ASO principles in the playbook: the primary keyword goes in
the title, secondary keywords go in the short description, and the long
description is written for a human but carries the keywords Play indexes.

One rule shapes all of it, and it is not an ASO rule: **no claim we cannot
stand behind.** Astra writes stories. It does not deliver outcomes. Copy that
promises money or a returning ex is both a Play policy risk under Misleading
Claims and a direct contradiction of our own Terms, which say in as many words
that nothing here makes an outcome more likely. Every line below is written so
that a reviewer reading the Terms and the listing together finds them saying
the same thing.

---

## Title — 30 characters max

**`Manifestation Stories: Astra`** — 28 characters

Primary keyword first, brand second. The playbook's point about HabitKit
applies exactly: an indie app cannot afford to spend the front of its title on
a brand nobody is searching for. Nobody types "Astra"; people type
"manifestation".

Alternatives, if a different keyword tests better:

| Title | Chars | Primary keyword |
|---|---|---|
| `Manifestation Stories: Astra` | 28 | manifestation stories |
| `Manifestation App - Astra` | 25 | manifestation app |
| `Manifest & Affirmations: Astra` | 30 | manifest, affirmations |
| `Law of Attraction: Astra` | 24 | law of attraction |

Play indexes the title most heavily of anything. Do not change it casually
once it starts ranking — a title change resets the signal that took months to
build.

---

## Short description — 80 characters max

**`Personalized AI manifestation audio: affirmations, visualization & sleep`** — 72 characters

Carries the secondary keywords the title does not: *affirmations*,
*visualization*, *sleep*, *audio*, *AI*. No word is repeated from the title,
which would waste the space.

Alternatives:

- `AI manifestation stories & guided visualization for sleep and confidence` (72)
- `Manifest your dream life with personalized audio affirmations & stories` (70)

---

## Long description — 4000 characters max

Play indexes this text, unlike the App Store, so keywords earn their place here
— but it is read by humans deciding whether to install, so it is written to be
read. Keyword density is deliberately moderate: stuffing reads as spam to both
the algorithm and the person.

```
Astra writes manifestation stories in your own voice — personalized audio you
listen to with your eyes closed, about a life that already went right.

Tell Astra what you want. "I want to be earning $10,000 a month from my own
work." "I want us to be good again." "I want to wake up without hurting."
Astra writes a five-minute story where it has already happened, narrates it in
a calm human-sounding voice, and puts it in your library to play whenever you
need it.

Your first three stories are free. No card, no trial countdown.


WHY PERSONALIZED BEATS GENERIC

Most manifestation apps and affirmation apps hand everyone the same audio.
Astra writes yours from your own words — your name, the thing you are actually
reaching for, the details of your own life. That is what makes a visualization
land instead of washing over you.


WHAT YOU GET

• Personalized manifestation stories, written from what you tell us
• Calm, natural narration — not robotic text to speech
• Read along with the text while you listen
• Daily affirmations you swipe through, learning what you like
• A library that follows you to a new phone
• Loop any story, adjust the speed, save your favourites
• Streaks, so a daily practice is easy to keep


BUILT FOR THE MOMENTS YOU ACTUALLY USE IT

Astra is made for the ten minutes before sleep, the walk to work, the morning
you need to walk into a room like you belong there. Five minutes is long
enough to settle into and short enough to finish.

Choose what you are calling in: career, abundance, love, health, confidence or
peace. Astra writes around it.


HONEST ABOUT WHAT THIS IS

Astra is a wellbeing and reflection app. The stories are written as though your
wish has already happened, because that is the form — it is a writing style,
not a prediction. Astra does not guarantee any outcome, and it is not
financial, medical or psychological advice. If you are struggling, please talk
to a professional.

We also do not do the things that make these apps annoying. There is no
listening limit — replay anything you own as often as you like, forever. Prices
are always shown with the period they bill on. Your first three stories cost
nothing and we never ask for a card to get them.


ASTRA PLUS

Astra Plus writes 20 new stories a month, with unlimited listening and every
voice. Monthly or yearly, cancel any time in Google Play.

Subscriptions renew automatically until cancelled. Cancelling stops the next
payment and you keep Plus until the period you have paid for ends.


PRIVACY

Your profile photo never leaves your phone. We do not sell your data, we run no
advertising trackers, and you can delete your account and everything in it from
inside the app in about ten seconds.

Privacy policy: https://sid-sys.github.io/policies/privacy.html
Terms: https://sid-sys.github.io/policies/terms.html

Questions: support@coreinteractive.live
```

---

## Keywords being targeted

Not a Play field — Play reads the title, short description and long
description — but worth writing down so the copy above can be checked against
it, and so a future rewrite does not quietly drop one.

**Primary:** manifestation, manifestation app, manifest
**Secondary:** affirmations, law of attraction, visualization, guided
visualization, sleep affirmations, self affirmations, abundance, manifesting
**Long tail:** manifestation audio, personalized affirmations, AI affirmations,
manifest money, manifest love, dream life, positive affirmations

Validate popularity and difficulty before committing — the playbook uses
Astro; AppTweak, Sensor Tower and Google Keyword Planner also work. The advice
worth taking: for the primary keyword, compete for a hard high-value one rather
than dominate an easy dead one.

---

## Screenshots — the highest-impact thing after the title

Order matters more than polish, and the playbook's A/B result is worth
remembering: professionally redesigned screenshots **lost** to the original
self-made ones. Test before assuming.

1. **A generated story on the player screen**, mid-sentence, with the text
   visible. This is the product. Not the onboarding screen, not a welcome
   screen — the thing nobody else has.
2. **The home screen** with the question and a library of real stories.
3. **The wish box** with a real, specific wish typed into it — showing the
   input is what makes the output believable.
4. **The affirmations deck** mid-swipe.
5. **What's free**: three stories, no card.

Show the real interface. Caption each with a benefit in a few words, in the
app's own voice.

---

## Before submitting

- [ ] Play Console: create subscriptions `astra_plus_monthly` and
      `astra_plus_yearly` — billing fails without these exact ids
- [ ] Play Console → Users and permissions: give the Cloud Functions service
      account "View financial data", or `verifyPurchase` fails closed
- [ ] Data safety form — the privacy policy is the source of truth for it
- [ ] Account deletion URL: https://sid-sys.github.io/policies/delete-account.html
- [ ] Content rating questionnaire
- [ ] Feature graphic (1024x500) and the 512x512 icon from `assets/brand/`
- [ ] Test billing on an internal testing track with a licence tester account —
      there is no other way to exercise it
