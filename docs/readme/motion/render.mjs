// Renders a motion page frame-exact through headless Chrome.
// Needs Google Chrome, ffmpeg and img2webp (libwebp), and network for three.js from jsDelivr.
//   node render.mjs main                       → docs/readme/agrypnos-demo.webp (README) + .mp4 (master)
//   LIGHT=1 node render.mjs main               → the light version, as agrypnos-demo-light.*
//   CLIP=power node render.mjs howto          → docs/readme/agrypnos-howto-power.webp (LIGHT=1 for -light)
//   node render.mjs main --stills 0,4.4 <dir>  → PNG stills of those seconds into <dir>
// A page may set window.EXPORT = { size, webpScale, webpQuality, transparent, keyframes } to change the defaults.
// The README uses animated WebP: GitHub strips autoplay from <video>, and a GIF of this is ~10 MB.
// Pages are served over a local port: browsers refuse modules and WebGL textures from file://.
import { spawn } from 'node:child_process';
import { mkdirSync, mkdtempSync, rmSync, writeFileSync } from 'node:fs';
import { readFile } from 'node:fs/promises';
import { createServer } from 'node:http';
import { tmpdir } from 'node:os';
import { dirname, extname, join, normalize } from 'node:path';
import { fileURLToPath } from 'node:url';

const here = dirname(fileURLToPath(import.meta.url));
const [name = 'main', flag, list, stillDir] = process.argv.slice(2);
const CHROME = '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome';
const MP4_FPS = 30;
const WEBP_FPS = 25;          // 40 ms a frame, exact in WebP's millisecond timing
const light = process.env.LIGHT === '1';
const clip = process.env.CLIP;
const tag = `${clip ? `-${clip}` : ''}${light ? '-light' : ''}`;
const outBase = join(here, '..', `${name === 'main' ? 'agrypnos-demo' : `agrypnos-${name}`}${tag}`);

const TYPES = { '.html': 'text/html', '.js': 'text/javascript', '.mjs': 'text/javascript', '.png': 'image/png', '.jpg': 'image/jpeg' };
const server = createServer(async (req, res) => {
  const path = normalize(join(here, decodeURIComponent(new URL(req.url, 'http://x').pathname)));
  try {
    if (!path.startsWith(here)) throw new Error('outside the motion folder');
    const body = await readFile(path);
    res.writeHead(200, { 'content-type': TYPES[extname(path)] ?? 'application/octet-stream' });
    res.end(body);
  } catch {
    res.writeHead(404);
    res.end();
  }
});
await new Promise(r => server.listen(0, '127.0.0.1', r));

const profile = mkdtempSync(join(tmpdir(), 'agrypnos-render-'));
const chrome = spawn(CHROME, ['--headless=new', '--remote-debugging-port=0', `--user-data-dir=${profile}`,
  '--hide-scrollbars', '--force-color-profile=srgb', 'about:blank'], { stdio: ['ignore', 'ignore', 'pipe'] });
const wsUrl = await new Promise((resolve, reject) => {
  let log = '';
  chrome.stderr.on('data', d => { log += d; const m = log.match(/DevTools listening on (ws:\S+)/); if (m) resolve(m[1]); });
  chrome.on('exit', () => reject(new Error(`Chrome exited:\n${log}`)));
});

const ws = new WebSocket(wsUrl);
await new Promise(r => { ws.onopen = r; });
let nextId = 0;
const pending = new Map();
ws.onmessage = e => {
  const m = JSON.parse(e.data);
  if (m.method === 'Runtime.exceptionThrown') console.error('page:', m.params.exceptionDetails.exception?.description ?? m.params.exceptionDetails.text);
  if (m.method === 'Runtime.consoleAPICalled' && m.params.type === 'error') console.error('page:', m.params.args.map(a => a.value ?? a.description).join(' '));
  const p = pending.get(m.id);
  if (!p) return;
  pending.delete(m.id);
  m.error ? p.reject(new Error(m.error.message)) : p.resolve(m.result);
};
const send = (method, params = {}, sessionId) => new Promise((resolve, reject) => {
  const id = ++nextId;
  pending.set(id, { resolve, reject });
  ws.send(JSON.stringify({ id, method, params, sessionId }));
});

const { targetId } = await send('Target.createTarget', { url: 'about:blank' });
const { sessionId } = await send('Target.attachToTarget', { targetId, flatten: true });
const page = (method, params) => send(method, params, sessionId);
const evaluate = async expression => {
  const r = await page('Runtime.evaluate', { expression, awaitPromise: true, returnByValue: true });
  if (r.exceptionDetails) throw new Error(r.exceptionDetails.exception?.description ?? r.exceptionDetails.text);
  return r.result.value;
};
let W = 1280, H = 720;
const pixels = scale => page('Emulation.setDeviceMetricsOverride', { width: W, height: H, deviceScaleFactor: scale, mobile: false });

await pixels(1.5);
await page('Runtime.enable');
await page('Page.navigate', { url: `http://127.0.0.1:${server.address().port}/${name}.html?render${light ? '&light' : ''}${clip ? `&clip=${clip}` : ''}` });
while (await evaluate('document.readyState') !== 'complete') await new Promise(r => setTimeout(r, 50));
await Promise.race([evaluate('window.ready'),
  new Promise((_, reject) => setTimeout(() => reject(new Error('the page never became ready')), 30000))]);
const duration = await evaluate('window.DURATION');
let webpScale, webpQuality, transparent, keyframes;
({ size: [W, H] = [1280, 720], webpScale = 0.8, webpQuality = 50, transparent = false, keyframes = true } = await evaluate('window.EXPORT') ?? {});
await pixels(1.5);
if (transparent) await page('Emulation.setDefaultBackgroundColorOverride', { color: { r: 0, g: 0, b: 0, a: 0 } });

async function frame(t) {
  await evaluate(`seek(${t})`);
  const { data } = await page('Page.captureScreenshot', { format: 'png' });
  return Buffer.from(data, 'base64');
}

function run(cmd, args, input) {
  const child = spawn(cmd, args, { stdio: [input ? 'pipe' : 'ignore', 'ignore', 'inherit'] });
  const done = new Promise((resolve, reject) => child.on('exit', c => c === 0 ? resolve() : reject(new Error(`${cmd} ${c}`))));
  return { child, done };
}

async function frames(fps, each) {
  const total = Math.round(duration * fps);
  for (let i = 0; i < total; i++) {
    await each(await frame(i / fps), i);
    if (i % fps === 0) process.stdout.write(`\r${fps} fps ${i}/${total}`);
  }
}

try {
  if (flag === '--stills') {
    for (const t of list.split(',').map(Number)) writeFileSync(join(stillDir, `${name}${tag}-${t.toFixed(2)}.png`), await frame(t));
  } else {
    const { child, done } = run('ffmpeg', ['-hide_banner', '-loglevel', 'error', '-y',
      '-f', 'image2pipe', '-framerate', String(MP4_FPS), '-i', '-',
      '-c:v', 'libx264', '-pix_fmt', 'yuv420p', '-crf', '18', '-preset', 'slow', '-movflags', '+faststart', `${outBase}.mp4`], true);
    await frames(MP4_FPS, async png => {
      if (!child.stdin.write(png)) await new Promise(r => child.stdin.once('drain', r));
    });
    child.stdin.end();
    await done;

    await pixels(webpScale);  // main: 1024 wide, since GitHub shows a README at most ~830 px wide
    const dir = join(profile, 'webp');
    mkdirSync(dir);
    const files = [];
    await frames(WEBP_FPS, (png, i) => {
      files.push(join(dir, `${String(i).padStart(4, '0')}.png`));
      writeFileSync(files.at(-1), png);
    });
    // keyframes: every frame is stored whole (-kmax 1). Lossy partial frames treat slowly fading
    // pixels as unchanged and blend over the old ones, which leaves ghosts of earlier frames behind.
    // (libwebp reads -kmax 0 as "no keyframes", despite img2webp's help text.)
    await run('img2webp', ['-loop', '0', '-lossy', '-q', String(webpQuality), '-m', '4', ...(keyframes ? ['-kmax', '1'] : []),
      '-d', String(1000 / WEBP_FPS), ...files, '-o', `${outBase}.webp`]).done;
    console.log(`\nwrote ${outBase}.webp and ${outBase}.mp4`);
  }
} finally {
  ws.close();
  server.close();
  const exited = new Promise(r => chrome.once('exit', r));
  chrome.kill();
  await exited;
  rmSync(profile, { recursive: true, force: true, maxRetries: 5 });
}
