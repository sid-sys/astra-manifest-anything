// Takes the store screenshots, at store resolution, into files.
//
// Run the demo web build first:
//
//   flutter run -d web-server --web-port=8080 --dart-define=ASTRA_DEMO=true
//   node tool/shoot_screenshots.mjs
//
// Why this and not a browser by hand: Play wants six frames that agree with
// each other — same device size, same account, same moment in the app — and a
// person taking them one at a time gets six slightly different pictures. This
// asks Chrome for a 1080x2280 phone viewport, opens each screen by its own
// URL, waits for it to settle, and writes a PNG. Run it again after any change
// and the whole set is regenerated identically.
//
// Chrome is driven over the DevTools Protocol rather than Puppeteer so there
// is nothing to install: Node has had a WebSocket client built in since 22.

import { spawn } from 'node:child_process';
import { mkdir, writeFile, rm } from 'node:fs/promises';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';

const CHROME = 'C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe';
const ORIGIN = 'http://localhost:8080';
const PORT = 9222;

// A phone, described the way a phone actually describes itself: a small number
// of layout pixels at a high pixel density, rather than one enormous viewport.
//
// This matters more than it looks. Flutter lays out from the *CSS* width, so
// asking for a 1080-wide viewport gets a tablet — one column stretched across
// the whole frame with tiny type — and the screenshots come out looking like a
// desktop app photographed sideways. 360 at 3x is a normal Android phone, and
// it still writes out at 1080x2280.
const WIDTH = 360;
const HEIGHT = 760;
const DENSITY = 3;

const here = dirname(fileURLToPath(import.meta.url));
const OUT = join(here, '..', 'store', 'screenshots');

/** The six frames the listing asks for, in the order it asks for them. */
const FRAMES = [
  // The player and the questions wait longest: both push a second screen on
  // top of the shell after the first frame, and the questions then sit through
  // the pause that stands in for the server writing them.
  { file: '1-player.png', screen: 'player', settle: 12000 },
  { file: '2-home.png', screen: 'home', settle: 8000 },
  { file: '3-questions.png', screen: 'questions', settle: 12000 },
  { file: '4-affirmations.png', screen: 'affirm', settle: 8000 },
  { file: '5-library.png', screen: 'library', settle: 8000 },
  { file: '6-profile.png', screen: 'profile', settle: 8000 },
];

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

async function devtoolsTarget() {
  // Chrome needs a moment before its debugging port answers.
  for (let attempt = 0; attempt < 40; attempt++) {
    try {
      const res = await fetch(`http://127.0.0.1:${PORT}/json/list`);
      const pages = (await res.json()).filter((t) => t.type === 'page');
      if (pages.length) return pages[0].webSocketDebuggerUrl;
    } catch {
      // Not up yet.
    }
    await sleep(500);
  }
  throw new Error('Chrome never opened its debugging port');
}

/** One CDP connection, with promise-shaped commands over it. */
function connect(url) {
  const socket = new WebSocket(url);
  const pending = new Map();
  let nextId = 0;

  socket.addEventListener('message', (event) => {
    const message = JSON.parse(event.data);
    const waiting = pending.get(message.id);
    if (!waiting) return;
    pending.delete(message.id);
    message.error ? waiting.reject(new Error(message.error.message)) : waiting.resolve(message.result);
  });

  const open = new Promise((resolve, reject) => {
    socket.addEventListener('open', resolve, { once: true });
    socket.addEventListener('error', reject, { once: true });
  });

  const send = (method, params = {}) =>
    new Promise((resolve, reject) => {
      const id = ++nextId;
      pending.set(id, { resolve, reject });
      socket.send(JSON.stringify({ id, method, params }));
    });

  return { open, send, close: () => socket.close() };
}

async function main() {
  await rm(OUT, { recursive: true, force: true });
  await mkdir(OUT, { recursive: true });

  const profile = join(here, '..', 'build', 'chrome-shots');
  const chrome = spawn(
    CHROME,
    [
      '--headless=new',
      `--remote-debugging-port=${PORT}`,
      `--user-data-dir=${profile}`,
      // SwiftShader, because the Flutter canvas needs WebGL and a headless
      // Chrome has no GPU to borrow. Without this every frame comes out blank.
      '--use-gl=swiftshader',
      '--enable-unsafe-swiftshader',
      '--hide-scrollbars',
      '--mute-audio',
      '--no-first-run',
      '--no-default-browser-check',
      'about:blank',
    ],
    { stdio: 'ignore' },
  );

  try {
    const client = connect(await devtoolsTarget());
    await client.open;

    await client.send('Page.enable');
    await client.send('Emulation.setDeviceMetricsOverride', {
      width: WIDTH,
      height: HEIGHT,
      deviceScaleFactor: DENSITY,
      mobile: true,
    });

    // One throwaway load before the first real frame.
    //
    // The debug web build compiles its modules the first time each is asked
    // for, so the opening visit is many seconds slower than every one after
    // it — and the first screenshot came out blank, then came out showing the
    // wrong screen, because it was racing that. Paying the cost once here
    // means every frame below is taken from a warm server.
    await client.send('Page.navigate', { url: `${ORIGIN}/?screen=home` });
    await sleep(20000);

    for (const frame of FRAMES) {
      const url = `${ORIGIN}/?screen=${frame.screen}`;
      await client.send('Page.navigate', { url });

      // Flutter's debug build compiles modules as it loads them, so the first
      // paint is slow and the second visit to the same URL is much faster.
      // Waiting on a fixed clock is crude and reliable; waiting on a load event
      // is neither, because the canvas draws long after the document is done.
      await sleep(frame.settle);

      const { data } = await client.send('Page.captureScreenshot', {
        format: 'png',
        captureBeyondViewport: false,
      });

      await writeFile(join(OUT, frame.file), Buffer.from(data, 'base64'));
      console.log(`${frame.file}  ${frame.screen}`);
    }

    client.close();
  } finally {
    chrome.kill();
  }

  console.log(`\n${FRAMES.length} frames in store/screenshots, ${WIDTH}x${HEIGHT}`);
}

await main();
