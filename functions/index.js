/**
 * Astra story generation.
 *
 * Claude writes the script, OpenAI narrates it, the audio lands in Storage and
 * the metadata in Firestore. This runs server-side for one reason above all
 * others: the API keys. Anything shipped inside an APK can be extracted from
 * it, so the keys live in Secret Manager and only this function ever sees them.
 */

const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { defineSecret } = require("firebase-functions/params");
const { setGlobalOptions } = require("firebase-functions/v2");
const logger = require("firebase-functions/logger");
const admin = require("firebase-admin");
const crypto = require("crypto");
const Anthropic = require("@anthropic-ai/sdk");
const OpenAI = require("openai");

admin.initializeApp();

const ANTHROPIC_API_KEY = defineSecret("ANTHROPIC_API_KEY");
const OPENAI_API_KEY = defineSecret("OPENAI_API_KEY");

// Same region as Firestore — keeps the round trips short.
setGlobalOptions({ region: "asia-south1", maxInstances: 10 });

/**
 * Audio bucket, named explicitly rather than using the project default.
 *
 * The default bucket was provisioned in us-east1; this one sits in asia-south1
 * alongside Firestore and this function, which is where the listeners are. A
 * bucket's region is permanent, so co-locating meant creating a second one
 * rather than moving the first.
 */
const AUDIO_BUCKET = "astra-manifest-audio-asia";

// ---------------------------------------------------------------- generation

const STORY_MODEL = "claude-opus-5";
const TTS_MODEL = "gpt-4o-mini-tts";
const TTS_VOICE = "marin";

/**
 * Voices the app may request, lowercased to match OpenAI's ids.
 *
 * An allowlist rather than a passthrough: an unrecognised value would fail the
 * synthesis call after the script has already been paid for, so anything not on
 * this list quietly becomes the default. All four read as a young woman — the
 * brief in VOICE_INSTRUCTIONS assumes that and would fight a baritone.
 */
const ALLOWED_VOICES = new Set(["marin", "coral", "shimmer", "sage"]);

/**
 * Every story is the same length now. The picker that set it was three taps of
 * friction in front of the one field that matters, and 5 minutes is what a
 * bedtime listen wants — long enough to settle into, short enough to finish.
 */
const STORY_MINUTES = 5;
const DEFAULT_MOOD = "Calm";

/**
 * How much each tier may generate. Listening is never capped — replay costs
 * nothing once the audio exists, so the limit belongs on the expensive half of
 * the operation only.
 *
 * The free tier is a day, not a story. The app this one is modelled on was
 * criticised hardest for paywalling before anyone had heard anything; a single
 * story answered that, but a day lets someone try more than one intention and
 * find out whether the thing is for them.
 *
 * These caps are the margin.
 *
 * A five-minute story costs about $0.10 to make — narration 59%, script 37%,
 * infrastructure 4% — and every plan in `plan.dart` is priced so a subscriber
 * who uses the whole allowance still leaves 80% gross after Google Play's cut.
 * Raising a limit here without moving the price there moves the margin; the
 * two numbers are one decision.
 *
 * Two trial stories costs about $0.21 per trial user, which is the real
 * acquisition cost of this app: at a 5% conversion rate it is roughly $4 of
 * production spent per subscriber won.
 */
const TRIAL_HOURS = 24;
const TRIAL_STORY_LIMIT = 2;
const PLUS_MONTHLY_LIMIT = 10;

/**
 * Narration pace, in words per minute, used to size the script.
 *
 * Measured from real output rather than assumed: a 586-word script came back as
 * 3m12s of audio, which is 183 wpm. The previous value of 110 was a guess, and
 * it meant a listener asking for seven minutes got about four — the script was
 * only ever long enough to fill the estimate, not the request.
 *
 * This sizes the request only. The duration reported to the player is measured
 * off the finished MP3, never computed from this number.
 */
const NARRATION_WPM = 183;

/**
 * Delivery direction for the narrator. gpt-4o-mini-tts takes this as prose,
 * which is the whole reason it beat the alternatives: the competition only
 * offers SSML tags, and none of them can express "sound certain, not hopeful".
 */
const VOICE_INSTRUCTIONS = `
Voice: A woman in her mid-twenties. Warm, smooth, unhurried.

Tone: Intimate and reassuring — speaking softly to someone lying down with
their eyes closed. Certain but never forceful. You are describing something
that has already happened, not something you hope for.

Pace: Slow and spacious. A full beat of silence at every paragraph break, a
short pause after each sentence. Never rush a line.

Delivery: Soft volume, gentle downward inflection at sentence ends, slight
breathiness. No upspeak, no announcer energy, no dramatic emphasis, no
smiling-voice brightness.
`.trim();

/**
 * The house style. Kept byte-stable and cached: it is the same on every
 * request, so paying to re-read it each time would be waste.
 */
const SYSTEM_PROMPT = `
You write first-person guided visualizations for a manifestation app. The
listener plays these with their eyes closed, usually at night, and hears them
as their own voice describing their own life.

Write in the first person, as "I". Not "you walk in" — "I walk in". Not "your
hands" — "my hands". The listener is saying this about themselves.

Write the scene as something that has already happened. Not "I will walk in" —
"I walk in". They should recognize the moment, not anticipate it.

Use simple, everyday English. Short sentences. Common words a twelve-year-old
would know. No literary flourish, no long clauses stacked together, no words
someone would have to stop and think about. Plain is the point: this is heard,
not read, and the listener is half asleep.

What makes these work is specificity. Generic affirmation is worthless here.
Use the details the listener gave you — their name, their words, the particular
thing they are reaching for — and add the concrete sensory detail that a real
memory would carry: what the room sounds like, what my hands are doing, who
else is there. A detail they did not think to mention but recognize instantly
is the entire effect.

Keep the emotional register low and certain. No exclamation, no crescendo, no
motivational-speaker cadence. The feeling you are aiming for is the quiet
satisfaction of an ordinary Tuesday in a life that already worked out.

Structure: open with a line that settles the body. Move into the scene. Stay
inside one moment rather than surveying a whole future. Close by handing the
feeling back to the listener for the day ahead.

Separate paragraphs with a blank line — each one becomes a spoken beat.

Never mention manifestation, the universe, energy, frequency, or vibration.
Never reference being an AI, a script, or a recording. Write only the words to
be spoken aloud: no headings, no stage directions, no narrator labels.
`.trim();

const STORY_SCHEMA = {
  type: "object",
  properties: {
    title: {
      type: "string",
      description:
        "Four to nine words naming the moment, in the listener's own plain vocabulary, first person where a pronoun is needed. No colon, no subtitle.",
    },
    script: {
      type: "string",
      description:
        "The narration itself, paragraphs separated by a blank line. Words to be spoken only.",
    },
  },
  required: ["title", "script"],
  additionalProperties: false,
};

/**
 * Writes the script.
 *
 * Runs at low effort deliberately: this is a single well-specified creative
 * task, not multi-step reasoning, and thinking tokens bill at output rates.
 * Effort is the dial to turn if story quality ever needs more room.
 */
async function writeScript({ profile, intention, scene, mood, lengthMinutes }) {
  const anthropic = new Anthropic({ apiKey: ANTHROPIC_API_KEY.value() });
  const targetWords = Math.round(lengthMinutes * NARRATION_WPM);

  const brief = [
    `Listener: ${profile.name || "the listener"}`,
    `Intention: ${intention}`,
    profile.aspiration ? `In their words: ${profile.aspiration}` : null,
    scene ? `The moment they asked for: ${scene}` : null,
    mood ? `Mood: ${mood}` : null,
    `Target length: about ${targetWords} words (${lengthMinutes} minutes read slowly).`,
  ]
    .filter(Boolean)
    .join("\n");

  const response = await anthropic.messages.create({
    model: STORY_MODEL,
    max_tokens: 8000,
    system: [
      {
        type: "text",
        text: SYSTEM_PROMPT,
        cache_control: { type: "ephemeral" },
      },
    ],
    output_config: {
      effort: "low",
      format: { type: "json_schema", schema: STORY_SCHEMA },
    },
    messages: [{ role: "user", content: brief }],
  });

  if (response.stop_reason === "refusal") {
    logger.warn("Story request declined", {
      category: response.stop_details?.category ?? null,
    });
    throw new HttpsError(
      "invalid-argument",
      "That request couldn't be written. Try describing the moment differently.",
    );
  }

  const text = response.content.find((block) => block.type === "text")?.text;
  if (!text) {
    throw new HttpsError("internal", "The story came back empty.");
  }

  const { title, script } = JSON.parse(text);
  // input_tokens is the *uncached remainder*, so the cache fields have to be
  // logged alongside it — otherwise the prompt looks 6x smaller than it is and
  // there is no way to tell whether caching is working at all.
  logger.info("Script written", {
    words: script.split(/\s+/).length,
    inputTokens: response.usage.input_tokens,
    cacheWrite: response.usage.cache_creation_input_tokens,
    cacheRead: response.usage.cache_read_input_tokens,
    outputTokens: response.usage.output_tokens,
  });

  return { title, script };
}

/**
 * Splits a script into synthesis-sized pieces on paragraph boundaries.
 *
 * gpt-4o-mini-tts accepts 2000 input tokens per request; this keeps chunks well
 * under that. Splitting on blank lines rather than a character count matters —
 * a chunk boundary mid-sentence produces an audible seam.
 */
function chunkScript(script, maxChars = 3000) {
  const paragraphs = script.split(/\n\s*\n/).map((p) => p.trim()).filter(Boolean);
  const chunks = [];
  let current = "";

  for (const paragraph of paragraphs) {
    if (current && current.length + paragraph.length + 2 > maxChars) {
      chunks.push(current);
      current = paragraph;
    } else {
      current = current ? `${current}\n\n${paragraph}` : paragraph;
    }
  }
  if (current) chunks.push(current);

  return chunks;
}

/** Narrates the script and returns one MP3 buffer. */
async function narrate(script, voice) {
  const openai = new OpenAI({ apiKey: OPENAI_API_KEY.value() });
  const chunks = chunkScript(script);

  // Sequential rather than parallel: the chunks are few, and serializing keeps
  // prosody consistent across the seams.
  const buffers = [];
  for (const chunk of chunks) {
    const speech = await openai.audio.speech.create({
      model: TTS_MODEL,
      voice,
      input: chunk,
      instructions: VOICE_INSTRUCTIONS,
      response_format: "mp3",
    });
    buffers.push(Buffer.from(await speech.arrayBuffer()));
  }

  logger.info("Narration rendered", {
    voice,
    chunks: chunks.length,
    bytes: buffers.reduce((sum, b) => sum + b.length, 0),
  });

  return Buffer.concat(buffers);
}

// Layer III bitrates in kbps, indexed by the header's bitrate nibble.
const MP3_BITRATE_V1 = [0, 32, 40, 48, 56, 64, 80, 96, 112, 128, 160, 192, 224, 256, 320, 0];
const MP3_BITRATE_V2 = [0, 8, 16, 24, 32, 40, 48, 56, 64, 80, 96, 112, 128, 144, 160, 0];
const MP3_SAMPLE_RATES = {
  3: [44100, 48000, 32000, 0], // MPEG 1
  2: [22050, 24000, 16000, 0], // MPEG 2 — what gpt-4o-mini-tts returns
  0: [11025, 12000, 8000, 0],  // MPEG 2.5
};

/**
 * Measures an MP3 by walking its frame headers, in seconds.
 *
 * The alternative was estimating from the word count, and that was wrong by
 * about 40% — the player showed 5m20s over audio that ran 3m12s, so the scrub
 * bar never reached the end and the library lied about every story's length.
 * Frame walking is exact and needs no decoder: each Layer III frame carries a
 * fixed number of samples, so the count and the sample rate give the duration.
 *
 * Handles the buffer being several MP3s concatenated, which is what narrating
 * in chunks produces — the walk simply crosses each boundary into the next
 * file's first frame.
 */
function mp3DurationSeconds(buffer) {
  let i = 0;
  let seconds = 0;

  while (i < buffer.length - 4) {
    // Frame sync: eleven set bits.
    if (buffer[i] === 0xff && (buffer[i + 1] & 0xe0) === 0xe0) {
      const version = (buffer[i + 1] >> 3) & 0x03;
      const layer = (buffer[i + 1] >> 1) & 0x03;
      const rates = MP3_SAMPLE_RATES[version];
      const sampleRate = rates ? rates[(buffer[i + 2] >> 2) & 0x03] : 0;
      const bitrate = (version === 3 ? MP3_BITRATE_V1 : MP3_BITRATE_V2)[
        (buffer[i + 2] >> 4) & 0x0f
      ];
      const padding = (buffer[i + 2] >> 1) & 0x01;

      if (layer === 1 && sampleRate && bitrate) {
        const samples = version === 3 ? 1152 : 576;
        seconds += samples / sampleRate;
        i += Math.floor(((samples / 8) * 1000 * bitrate) / sampleRate) + padding;
        continue;
      }
    }
    // Not a frame header — most often an ID3 tag or padding. Step past it.
    i++;
  }

  return Math.round(seconds);
}

/**
 * Stores the audio and returns a URL the player can stream.
 *
 * Uses Firebase's own download-token scheme rather than a signed URL: signed
 * URLs expire, and a story that stops playing after a week is worse than no
 * story. The token is an unguessable UUID and the URL only ever lives in the
 * owner's own Firestore document.
 */
async function storeAudio({ uid, storyId, audio }) {
  const bucket = admin.storage().bucket(AUDIO_BUCKET);
  const path = `users/${uid}/stories/${storyId}.mp3`;
  const token = crypto.randomUUID();

  await bucket.file(path).save(audio, {
    contentType: "audio/mpeg",
    metadata: { metadata: { firebaseStorageDownloadTokens: token } },
  });

  const encoded = encodeURIComponent(path);
  return {
    audioPath: path,
    audioUrl:
      `https://firebasestorage.googleapis.com/v0/b/${bucket.name}` +
      `/o/${encoded}?alt=media&token=${token}`,
  };
}

/**
 * Enforces the generation quota. Throws if the caller is over it.
 *
 * The trial clock starts on the first generation rather than at signup, and it
 * is stamped here rather than by the client — a free day that a device could
 * reset by clearing its storage is not a limit.
 */
async function assertWithinQuota(uid, profile) {
  const userDoc = admin.firestore().collection("users").doc(uid);
  const stories = userDoc.collection("stories");

  if (!profile.isSubscribed) {
    if (!profile.trialStartedAt) {
      await userDoc.set(
        { trialStartedAt: new Date().toISOString() },
        { merge: true },
      );
      return;
    }

    const startedAt = new Date(profile.trialStartedAt);
    const hoursElapsed = (Date.now() - startedAt.getTime()) / 3600000;

    if (hoursElapsed >= TRIAL_HOURS) {
      throw new HttpsError(
        "resource-exhausted",
        "Your free day has ended. Astra Plus keeps writing them.",
      );
    }

    const duringTrial = await stories
      .where("createdAt", ">=", startedAt.toISOString())
      .count()
      .get();

    if (duringTrial.data().count >= TRIAL_STORY_LIMIT) {
      throw new HttpsError(
        "resource-exhausted",
        `You've written ${TRIAL_STORY_LIMIT} stories on your free day. They replay as often as you like, and Astra Plus lifts the limit.`,
      );
    }
    return;
  }

  const monthStart = new Date();
  monthStart.setDate(1);
  monthStart.setHours(0, 0, 0, 0);

  const thisMonth = await stories
    .where("createdAt", ">=", monthStart.toISOString())
    .count()
    .get();

  if (thisMonth.data().count >= PLUS_MONTHLY_LIMIT) {
    throw new HttpsError(
      "resource-exhausted",
      `You've written ${PLUS_MONTHLY_LIMIT} stories this month. Your library replays without limit, and new stories unlock next month.`,
    );
  }
}

// ---------------------------------------------------------------- endpoints

/**
 * Writing and narrating are two calls, not one.
 *
 * Together they take around a hundred seconds, and for most of that the user
 * was staring at a spinner holding text that already existed — the script is
 * done after twenty. Splitting them puts the story on screen as soon as it is
 * written and lets the narration arrive behind it, which also means a story
 * abandoned after reading never costs a narration.
 */
exports.writeStory = onCall(
  {
    secrets: [ANTHROPIC_API_KEY],
    timeoutSeconds: 180,
    memory: "512MiB",
  },
  async (request) => {
    const uid = request.auth?.uid;
    if (!uid) {
      throw new HttpsError("unauthenticated", "Sign in to write a story.");
    }

    const { intention = "career", scene = "" } = request.data ?? {};

    const db = admin.firestore();
    const profileSnap = await db.collection("users").doc(uid).get();
    const profile = profileSnap.data() ?? {};

    await assertWithinQuota(uid, profile);

    const started = Date.now();
    const { title, script } = await writeScript({
      profile,
      intention,
      scene,
      mood: DEFAULT_MOOD,
      lengthMinutes: STORY_MINUTES,
    });

    const storyId = `story_${Date.now()}`;
    const story = {
      title,
      intention,
      script,
      // Provisional: estimated from the word count so the library has a length
      // to show before any audio exists. narrateStory replaces it with the
      // duration measured off the finished MP3.
      durationSeconds: Math.round(
        (script.split(/\s+/).length / NARRATION_WPM) * 60,
      ),
      voice: TTS_VOICE,
      createdAt: new Date().toISOString(),
      audioUrl: null,
      audioPath: null,
      downloaded: false,
    };

    await db.collection("users").doc(uid).collection("stories").doc(storyId).set(story);

    logger.info("Story written", { storyId, elapsedMs: Date.now() - started });

    return { id: storyId, ...story };
  },
);

/**
 * Narrates a story that has already been written.
 *
 * Idempotent: a story that already has audio returns it rather than paying for
 * a second recording, so a retry after a dropped connection is free.
 */
exports.narrateStory = onCall(
  {
    secrets: [OPENAI_API_KEY],
    timeoutSeconds: 540,
    memory: "1GiB",
  },
  async (request) => {
    const uid = request.auth?.uid;
    if (!uid) {
      throw new HttpsError("unauthenticated", "Sign in to narrate a story.");
    }

    const { storyId } = request.data ?? {};
    if (!storyId) {
      throw new HttpsError("invalid-argument", "Which story?");
    }

    // Read through the user's own collection, so a caller can only ever
    // narrate a story that belongs to them.
    const storyRef = admin
      .firestore()
      .collection("users")
      .doc(uid)
      .collection("stories")
      .doc(storyId);

    const snapshot = await storyRef.get();
    if (!snapshot.exists) {
      throw new HttpsError("not-found", "That story no longer exists.");
    }

    const story = snapshot.data();
    if (story.audioUrl) {
      return {
        audioUrl: story.audioUrl,
        audioPath: story.audioPath,
        durationSeconds: story.durationSeconds,
      };
    }

    const started = Date.now();
    const requestedVoice = String(story.voice ?? TTS_VOICE).toLowerCase();
    const voice = ALLOWED_VOICES.has(requestedVoice) ? requestedVoice : TTS_VOICE;

    const audio = await narrate(story.script, voice);
    const { audioUrl, audioPath } = await storeAudio({ uid, storyId, audio });

    // Measured off the finished audio, not estimated from the script — the
    // progress bar has to track the file the player is actually holding.
    const durationSeconds = mp3DurationSeconds(audio);

    await storyRef.set({ audioUrl, audioPath, durationSeconds, voice }, { merge: true });

    logger.info("Story narrated", {
      storyId,
      elapsedMs: Date.now() - started,
      durationSeconds,
      // Logged side by side so drift between what was asked for and what the
      // narration actually runs to stays visible without another measurement.
      requestedSeconds: STORY_MINUTES * 60,
    });

    return { audioUrl, audioPath, durationSeconds, voice };
  },
);
