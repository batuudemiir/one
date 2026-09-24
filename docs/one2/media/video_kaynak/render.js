const { chromium } = require('playwright');
const { spawn } = require('child_process');
const [,, url, out, ffmpeg, only] = process.argv;
(async () => {
  const b = await chromium.launch();
  const p = await b.newPage({ viewport: { width: 1080, height: 1080 } });
  await p.goto(url); await p.evaluate(() => window.ready);
  const total = await p.evaluate(() => window.TOTAL), fps = 30;
  if (only) { // tek kare önizleme: only = saniye listesi
    for (const s of only.split(',')) {
      const d = await p.evaluate(t => { draw(t); return document.getElementById('c').toDataURL('image/png'); }, +s);
      require('fs').writeFileSync(`${out}_${s}.png`, Buffer.from(d.split(',')[1], 'base64'));
    }
    return b.close();
  }
  const n = Math.round(total * fps);
  const ff = spawn(ffmpeg, ['-y','-f','image2pipe','-framerate',String(fps),'-c:v','png','-i','-',
    '-c:v','libx264','-pix_fmt','yuv420p','-crf','20','-preset','slow','-movflags','+faststart', out], { stdio: ['pipe','ignore','inherit'] });
  for (let i = 0; i < n; i++) {
    const d = await p.evaluate(t => { draw(t); return document.getElementById('c').toDataURL('image/png'); }, i / fps);
    if (!ff.stdin.write(Buffer.from(d.split(',')[1], 'base64'))) await new Promise(r => ff.stdin.once('drain', r));
  }
  ff.stdin.end(); await new Promise(r => ff.on('close', r)); await b.close();
  console.log('frames', n, 'seconds', total);
})();
