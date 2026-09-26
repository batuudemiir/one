// Bir sahne dosyasını kare kare render eder, ffmpeg'e boru ile verir.
// Kullanım: node kit/render.js <sahne.html> <genişlik> <yükseklik> <çıktı.mp4> <ffmpeg> [events.json]
// Yalnız kare: node kit/render.js <sahne.html> <g> <y> --snap 5.5 12.6 ...
const { chromium } = require('playwright');
const { spawn } = require('child_process');
const fs = require('fs'), path = require('path');
(async () => {
  const [scene, w, h, out, ...rest] = process.argv.slice(2);
  const browser = await chromium.launch();
  const page = await browser.newPage({ viewport: { width: +w, height: +h } });
  page.on('pageerror', e => { console.error('PAGEERROR', e.message); process.exit(1); });
  await page.goto('file://' + path.resolve(scene) + `?w=${w}&h=${h}`);
  await page.evaluate(() => window.fontsReady());
  if (out === '--snap') {
    const base = path.basename(scene, '.html');
    for (const t of rest) {
      await page.evaluate(t => window.render(t), +t);
      await page.screenshot({ path: `snap_${base}_${t}.png` });
    }
    await browser.close(); return;
  }
  const [ff, eventsOut] = rest;
  const FPS = 30;
  const dur = await page.evaluate(() => window.DURATION);
  if (eventsOut) fs.writeFileSync(eventsOut, JSON.stringify({ duration: dur, events: await page.evaluate(() => window.EVENTS) }));
  const enc = spawn(ff, ['-loglevel', 'error', '-y', '-f', 'image2pipe', '-framerate', String(FPS), '-i', '-',
    '-c:v', 'libx264', '-preset', 'slow', '-crf', '14', '-pix_fmt', 'yuv420p', '-movflags', '+faststart', out], { stdio: ['pipe', 'inherit', 'inherit'] });
  const frames = Math.round(dur * FPS);
  for (let i = 0; i < frames; i++) {
    await page.evaluate(t => window.render(t), i / FPS);
    const buf = await page.screenshot({ type: 'png' });
    if (!enc.stdin.write(buf)) await new Promise(r => enc.stdin.once('drain', r));
    if (i % 150 === 0) console.log(out, i, '/', frames);
  }
  enc.stdin.end();
  await new Promise(r => enc.on('close', r));
  await browser.close();
})();
