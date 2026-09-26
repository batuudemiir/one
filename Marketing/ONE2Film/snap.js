const { chromium } = require('playwright');
const path = require('path');
(async () => {
  const [w, h, ...times] = process.argv.slice(2);
  const browser = await chromium.launch();
  const page = await browser.newPage({ viewport: { width: +w, height: +h } });
  page.on('pageerror', e => console.error('PAGEERROR', e.message));
  page.on('console', m => console.log('console', m.text()));
  await page.goto('file://' + path.resolve('film.html') + `?w=${w}&h=${h}`);
  await page.evaluate(() => window.fontsReady());
  for (const t of times) {
    await page.evaluate(t => window.render(t), +t);
    await page.screenshot({ path: `snap_${w}x${h}_${t}.png` });
  }
  await browser.close();
})();
