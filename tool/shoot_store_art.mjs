// Makes the Play Store screenshots: bold headline, bright background, and the
// real app screen in a phone. 1080x1920 each.
//
//   1. node tool/shoot_screenshots.mjs        (with SHOT_OUT=store/art/raw, the
//                                              demo web build serving on 8080)
//   2. node tool/shoot_store_art.mjs
//
// The slides are drawn by store/art/slide.html, in a browser, because the
// headline font has to be a real font. Chrome is driven over the DevTools
// Protocol, the same way tool/shoot_screenshots.mjs does it.

import { spawn } from 'node:child_process';
import { mkdir, writeFile } from 'node:fs/promises';
import { join, dirname } from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';

const CHROME = 'C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe';
const PORT = 9223;
const here = dirname(fileURLToPath(import.meta.url));
const page = join(here, '..', 'store', 'art', 'slide.html');
const OUT = join(here, '..', 'store', 'art', 'phone');

/** In the order they should appear on the store page. */
const SLIDES = [
  ['1-home.png', 'home'],
  ['2-questions.png', 'questions'],
  ['3-player.png', 'player'],
  ['4-affirmations.png', 'affirm'],
  ['5-library.png', 'library'],
  ['6-profile.png', 'profile'],
];

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

async function target() {
  for (let i = 0; i < 40; i++) {
    try {
      const pages = (await (await fetch(`http://127.0.0.1:${PORT}/json/list`)).json()).filter(
        (t) => t.type === 'page',
      );
      if (pages.length) return pages[0].webSocketDebuggerUrl;
    } catch {
      // Chrome is not up yet.
    }
    await sleep(500);
  }
  throw new Error('Chrome never opened its debugging port');
}

function connect(url) {
  const socket = new WebSocket(url);
  const pending = new Map();
  let id = 0;
  socket.addEventListener('message', (event) => {
    const message = JSON.parse(event.data);
    const waiting = pending.get(message.id);
    if (!waiting) return;
    pending.delete(message.id);
    message.error ? waiting.reject(new Error(message.error.message)) : waiting.resolve(message.result);
  });
  const open = new Promise((ok, no) => {
    socket.addEventListener('open', ok, { once: true });
    socket.addEventListener('error', no, { once: true });
  });
  const send = (method, params = {}) =>
    new Promise((resolve, reject) => {
      const n = ++id;
      pending.set(n, { resolve, reject });
      socket.send(JSON.stringify({ id: n, method, params }));
    });
  return { open, send, close: () => socket.close() };
}

await mkdir(OUT, { recursive: true });
const chrome = spawn(
  CHROME,
  [
    '--headless=new',
    `--remote-debugging-port=${PORT}`,
    `--user-data-dir=${join(here, '..', 'build', 'chrome-art')}`,
    '--allow-file-access-from-files',
    '--hide-scrollbars',
    '--no-first-run',
    'about:blank',
  ],
  { stdio: 'ignore' },
);

try {
  const client = connect(await target());
  await client.open;
  await client.send('Page.enable');
  await client.send('Emulation.setDeviceMetricsOverride', {
    width: 1080,
    height: 1920,
    deviceScaleFactor: 1,
    mobile: false,
  });

  for (const [file, slide] of SLIDES) {
    await client.send('Page.navigate', { url: `${pathToFileURL(page).href}?slide=${slide}` });
    // The page sets its title to "ready" once the font and the screen are in.
    for (let i = 0; i < 60; i++) {
      const { result } = await client.send('Runtime.evaluate', { expression: 'document.title' });
      if (result.value === 'ready') break;
      await sleep(500);
    }
    await sleep(500);
    const { data } = await client.send('Page.captureScreenshot', { format: 'png' });
    await writeFile(join(OUT, file), Buffer.from(data, 'base64'));
    console.log(file);
  }
  client.close();
} finally {
  chrome.kill();
}
