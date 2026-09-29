// Renders store/feature-graphic/feature_graphic.html to a 1024x500 PNG.
//
//   node tool/shoot_feature_graphic.mjs
//
// Play wants exactly 1024x500, so that is the viewport and the capture — no
// resizing afterwards, which is what softens type.
//
// The page loads Playfair Display and Inter from Google Fonts, so this needs a
// network connection the first time. Without it Chrome falls back to Georgia
// and Arial and the banner stops matching the app.

import { spawn } from 'node:child_process';
import { mkdir, writeFile } from 'node:fs/promises';
import { join, dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { pathToFileURL } from 'node:url';

const CHROME = 'C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe';
const PORT = 9223;

const WIDTH = 1024;
const HEIGHT = 500;

const here = dirname(fileURLToPath(import.meta.url));
const PAGE = resolve(here, '..', 'store', 'feature-graphic', 'feature_graphic.html');
const OUT = resolve(here, '..', 'store', 'feature-graphic');

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

async function devtoolsTarget() {
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

function connect(url) {
  const socket = new WebSocket(url);
  const pending = new Map();
  let nextId = 0;

  socket.addEventListener('message', (event) => {
    const message = JSON.parse(event.data);
    const waiting = pending.get(message.id);
    if (!waiting) return;
    pending.delete(message.id);
    message.error
      ? waiting.reject(new Error(message.error.message))
      : waiting.resolve(message.result);
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
  await mkdir(OUT, { recursive: true });

  const chrome = spawn(
    CHROME,
    [
      '--headless=new',
      `--remote-debugging-port=${PORT}`,
      `--user-data-dir=${join(here, '..', 'build', 'chrome-banner')}`,
      '--hide-scrollbars',
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
      deviceScaleFactor: 1,
      mobile: false,
    });

    await client.send('Page.navigate', { url: pathToFileURL(PAGE).href });

    // Long enough for the webfonts to arrive. A banner captured before they do
    // is set in Georgia, which is close enough to Playfair to be missed and
    // far enough to look wrong next to the app.
    await sleep(6000);

    const { data } = await client.send('Page.captureScreenshot', {
      format: 'png',
      captureBeyondViewport: false,
    });

    const file = join(OUT, 'feature-graphic-1024x500.png');
    await writeFile(file, Buffer.from(data, 'base64'));
    console.log(`${file}  ${WIDTH}x${HEIGHT}`);

    client.close();
  } finally {
    chrome.kill();
  }
}

await main();
