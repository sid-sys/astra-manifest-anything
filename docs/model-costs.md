# What a story costs, and who should write it

Measured on 13 August 2026 by sending the *same* brief to both providers and
reading the token counts out of the function logs. Prices are the published
list prices on the same date.

Change the writer by editing one line in `functions/index.js`:

```js
const STORY_PROVIDER = "anthropic";   // or "openai"
```

Both paths send the same system prompt and the same JSON schema and return the
same shape, so nothing downstream can tell them apart.

## List prices, per million tokens

| Model | Input | Cached input | Output |
| --- | --- | --- | --- |
| `claude-opus-5` | $5.00 | $0.50 | $25.00 |
| `gpt-5.6-sol` | $5.00 | $0.50 | $30.00 |
| `gpt-5.6-terra` | $2.00 | $0.20 | $12.00 |
| `gpt-5.6-luna` | $0.20 | $0.02 | $1.20 |
| `gpt-4o-mini-tts` | $12.00 per million characters | | |

## The same brief, both providers

| | Opus 5 | GPT-5.6 Terra |
| --- | --- | --- |
| Prompt tokens | 2,062 cached + 268 | 1,614 |
| Output tokens | 1,805 | 2,036 |
| Words written | 979 | 1,088 |
| Time | 33.3 s | 30.7 s |
| **Script cost (warm cache)** | **$0.047** | **$0.026** |
| Narration of that script | $0.063 | $0.070 |
| **Total per story** | **$0.114** | **$0.100** |

Terra is 45% cheaper *on the script* but only **12% cheaper per story**, and
the reason is the last row: narration is the dominant cost and Terra wrote 11%
more words than it was asked for, so it spends part of its own saving on TTS.
It also pushes the audio to about 5m56s against a 5-minute design target.

## Two things this measurement changed

**The planning number was stale, and one plan did not survive fixing it.**
`plan.dart` and `pricing_test.dart` assumed $0.105 a story. The measured cost
on Opus 5 is **$0.114** — about 9% over — because the script runs to ~1,800
output tokens rather than the ~1,200 the estimate assumed.

This section previously concluded the correction was safe: "margin at the
20-story cap is 71.5% rather than 73.7%, still above the 65% floor". That was
true of the dollar monthly plan and of no other. Checked against the whole
catalogue, ₹6,499/year fell to **63.6%** at the cap — under the floor its own
test enforces — because a yearly plan pays twelve months of cost up front out
of one payment, so a 9% cost rise hits it twelve times as hard.

Both are now fixed: the constant is $0.114, and the yearly rupee plan is
₹6,999, which restores 66.2% at the cap. The lesson worth keeping is that the
yearly plan in the weaker currency is the one to check first — it is where any
cost movement shows up, and it is the last place anyone looks.

**Sol is not worth considering.** At $30 per million output it costs *more*
per story than Opus 5 does. Switching provider to reach it would be paying
more for a lateral move.

## The recommendation, and why it is a judgement call

**Cheapest with genuinely good quality: `gpt-5.6-terra`.** Both stories were
publishable. Both obeyed the house style — no markdown, no em dashes, no
banned vocabulary — and both held the gender rule perfectly, using the name 19
and 29 times with zero gendered pronouns.

**Kept on Opus 5 anyway.** Three reasons, all visible in the samples:

1. It hit the length target (979 words against 900 asked; Terra overran to
   1,088), which matters because length is narration cost and runtime.
2. The prose is tighter. Terra explains its own theme out loud — "Confidence
   does not feel loud. It feels like being able to stay present." — which is
   the self-help register the system prompt explicitly forbids.
3. The dialogue carries more and narrates less.

Twelve percent of ten cents is about a penny a story. That is not worth a
regression in the one artifact the whole product is judged on. If volume grows
to where a penny a story is real money, Terra is a one-word change and this
file is the evidence for making it.

Luna and the mini tiers were not tested. They are plausible for the daily
affirmation batch — six short lines, far less demanding than a 900-word story —
and that is the next thing worth measuring.
