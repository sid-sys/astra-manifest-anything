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

// ---------------------------------------------------------------- generation

const STORY_MODEL = "claude-opus-5";
const TTS_MODEL = "gpt-4o-mini-tts";
const TTS_VOICE = "marin";

/**
 * How many stories each tier may generate. Listening is never capped — replay
 * costs nothing once the audio exists, so the limit belongs on the expensive
 * half of the operation only.
 */
const FREE_STORY_LIMIT = 1;
const PLUS_MONTHLY_LIMIT = 15;

/** Narration pace, in words per minute. Slower than speech — this is a lullaby. */
const NARRATION_WPM = 110;

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
You write second-person guided visualizations for a manifestation app. The
listener plays these with their eyes closed, usually at night.

Write the scene as something that has already happened. Not "you will walk in"
— "you walk in". The listener should recognize the moment, not anticipate it.

What makes these work is specificity. Generic affirmation is worthless here.
Use the details the listener gave you — their name, their words, the particular
thing they are reaching for — and add the concrete sensory detail that a real
memory would carry: what the room sounds like, what their hands are doing, who
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
        "Four to seven words naming the moment, in the listener's own vocabulary. No colon, no subtitle.",
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
async function writeScript({ profile, intention, scene, lengthMinutes }) {
  const anthropic = new Anthropic({ apiKey: ANTHROPIC_API_KEY.value() });
  const targetWords = Math.round(lengthMinutes * NARRATION_WPM);

  const brief = [
    `Listener: ${profile.name || "the listener"}`,
    `Intention: ${intention}`,
    profile.aspiration ? `In their words: ${profile.aspiration}` : null,
    scene ? `The moment they asked for: ${scene}` : null,
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
  logger.info("Script written", {
    words: script.split(/\s+/).length,
    inputTokens: response.usage.input_tokens,
    outputTokens: response.usage.output_tokens,
    cacheRead: response.usage.cache_read_input_tokens,
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
async function narrate(script) {
  const openai = new OpenAI({ apiKey: OPENAI_API_KEY.value() });
  const chunks = chunkScript(script);

  // Sequential rather than parallel: the chunks are few, and serializing keeps
  // prosody consistent across the seams.
  const buffers = [];
  for (const chunk of chunks) {
    const speech = await openai.audio.speech.create({
      model: TTS_MODEL,
      voice: TTS_VOICE,
      input: chunk,
      instructions: VOICE_INSTRUCTIONS,
      response_format: "mp3",
    });
    buffers.push(Buffer.from(await speech.arrayBuffer()));
  }

  logger.info("Narration rendered", {
    chunks: chunks.length,
    bytes: buffers.reduce((sum, b) => sum + b.length, 0),
  });

  return Buffer.concat(buffers);
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
  const bucket = admin.storage().bucket();
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

/** Enforces the generation quota. Throws if the caller is over it. */
async function assertWithinQuota(uid, profile) {
  const stories = admin.firestore().collection("users").doc(uid).collection("stories");

  if (!profile.isSubscribed) {
    const existing = await stories.count().get();
    if (existing.data().count >= FREE_STORY_LIMIT) {
      throw new HttpsError(
        "resource-exhausted",
        "You've used your free story. Astra Plus writes as many as you want.",
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

// ----------------------------------------------------------------- endpoint

exports.generateStory = onCall(
  {
    secrets: [ANTHROPIC_API_KEY, OPENAI_API_KEY],
    // Narration of a 10-minute story takes a while; the default 60s is not enough.
    timeoutSeconds: 540,
    memory: "1GiB",
  },
  async (request) => {
    const uid = request.auth?.uid;
    if (!uid) {
      throw new HttpsError("unauthenticated", "Sign in to write a story.");
    }

    const {
      intention = "career",
      scene = "",
      lengthMinutes = 7,
      voice = TTS_VOICE,
    } = request.data ?? {};

    if (![5, 7, 10].includes(lengthMinutes)) {
      throw new HttpsError("invalid-argument", "Length must be 5, 7, or 10 minutes.");
    }

    const db = admin.firestore();
    const profileSnap = await db.collection("users").doc(uid).get();
    const profile = profileSnap.data() ?? {};

    await assertWithinQuota(uid, profile);

    const started = Date.now();
    const { title, script } = await writeScript({
      profile,
      intention,
      scene,
      lengthMinutes,
    });

    const storyId = `story_${Date.now()}`;
    const audio = await narrate(script);
    const { audioUrl, audioPath } = await storeAudio({ uid, storyId, audio });

    // Duration from the actual word count rather than the requested length —
    // the player's progress bar should track the audio, not the intent.
    const durationSeconds = Math.round(
      (script.split(/\s+/).length / NARRATION_WPM) * 60,
    );

    const story = {
      title,
      intention,
      script,
      durationSeconds,
      voice,
      createdAt: new Date().toISOString(),
      audioUrl,
      audioPath,
      downloaded: false,
    };

    await db.collection("users").doc(uid).collection("stories").doc(storyId).set(story);

    logger.info("Story delivered", {
      storyId,
      elapsedMs: Date.now() - started,
      durationSeconds,
    });

    return { id: storyId, ...story };
  },
);
