# Pricing model

Private. Moved out of `lib/models/plan.dart`, where it lived as a doc
comment, when the client source was prepared for a public build mirror:
a unit cost and a margin formula are not things to publish alongside the
app they describe.

`test/pricing_test.dart` enforces these numbers against the catalogue and
fails the day a price, an allowance or a cost moves without the others.

## How these numbers were derived

A manifestation costs **$0.161** to produce. Measured, not estimated: three
real ones ran to 2,230, 2,249 and 2,253 characters, and at ElevenLabs
Turbo's $0.05 per thousand that is $0.112 of narration. The script adds
$0.022, the four questions that precede it $0.017, and storage, traffic and
functions about $0.010. Narration is 70% of the total, which is why the
script model barely moves the answer and the voice model decides it.

Affirmations are uncapped and cost about $0.05 a month per active user, on
Haiku rather than Opus. They were $0.25 on Opus, which is a point and a
half of margin on the thinnest plan spent on the cheapest thing in the app.

## The margin is measured on what actually arrives

Google Play takes 15%, so the dollar plans keep 85% and no more. The number
to design against is the one that reaches the bank.

    margin at n = (net monthly − n × $0.161 − $0.05) / net monthly


| manifests/month | $7.99 mo | $79.99 yr |
|-----------------|----------|-----------|
| net to us       |    $6.79 |     $5.67 |
| 6 (expected)    |    85.0% |     82.1% |
| **10 (the cap)** | **75.6%** | **70.7%** |
| 12              |    70.8% |     65.0% |

Ten holds 70% to 76% across the catalogue, inside the 60–70% band the owner
asked for with room above it.

The yearly plan in the weaker currency always binds: twelve months of cost
against one payment, so any cost movement hits it twelve times as hard. It
is the first plan to check and the last place anyone looks.

## The allowance is a ceiling, not a forecast

Ten a month is more than anyone is expected to use. It exists so the worst
case is known: without a cap, one automated client runs the margin
negative. At the six a month a real subscriber uses, every plan is near 88%.

Listening is not capped and never will be. Replaying a file that already
exists is free; making a new one is not. Capping the expensive half and
leaving the free half alone is both cheaper to honour and easier to explain
than the competitor who caps plays at three a day while advertising
unlimited generation.

## After the move to OpenAI "sage" and GPT-5.6 Luna (October 2026)

Manifestation narration is now OpenAI `gpt-4o-mini-tts`, voice `sage`, and the
manifestation script, the four questions and the five affirmation lines are
written by `gpt-5.6-luna`. ElevenLabs is commented out in `functions/index.js`,
not deleted: the voice is wanted back later.

One manifestation, about $0.042: narration $0.030 (about 2.5 minutes of audio,
at the $0.0119 a minute measured from a real story), writing about $0.002,
storage and traffic about $0.010. It was $0.161. The writing figure is
estimated from token counts; filter the function logs on "Writer usage" to
replace it with real numbers.

Margin on the shelf price, Google's cut ignored:

    margin at n = (price − n × $0.042 − $0.05) / price

| manifests/month | $7.99 monthly | $79.99 yearly ($6.67/mo) |
|-----------------|---------------|--------------------------|
| 30              | 83.6%         | 80.3%                    |
| 40              | 78.3%         | 74.0%                    |
| 50              | 73.1%         | 67.7%                    |
| 60              | 67.8%         | 61.4%                    |

The cap is still 10 (`MANIFEST_MONTHLY_LIMIT`, `Plan.manifestMonthly`).
Raising it means changing both and the unit cost in `test/pricing_test.dart`.
