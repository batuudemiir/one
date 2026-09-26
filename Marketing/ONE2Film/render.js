const { chromium } = require('playwright');
const { spawn } = require('child_process');
const fs = require('fs'), path = require('path');
(async () => {
  const [w, h, out, ff] = process.argv.slice(2);
  const FPS = 30;
  const browser = await chromium.launch();
  const page = await browser.newPage({ viewport: { width: +w, height: +h } });
  page.on('pageerror', e => { console.error('PAGEERROR', e.message); process.exit(1); });
  await page.goto('file://' + path.resolve('film.html') + `?w=${w}&h=${h}`);
  await page.evaluate(() => window.fontsReady());
  const dur = await page.evaluate(() => window.DURATION);
  fs.writeFileSync('events.json', JSON.stringify(await page.evaluate(() => window.EVENTS)));
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
