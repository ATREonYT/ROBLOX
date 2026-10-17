// Renders exported UI JSON to PNG, optionally stacked under its reference page for a side-by-side.
// Usage: node shoot.js <ui.json> <out.png> <width> <height> [reference.png]
// STUDIO=1: leave images without an uploaded ID blank, as Studio shows them before the owner imports them.
const { chromium } = require('playwright');
const path = require('path');
(async () => {
  const [json, out, W, H, ref] = process.argv.slice(2);
  const browser = await chromium.launch({ args: ['--allow-file-access-from-files'] });
  const page = await browser.newPage({ viewport: { width: +W, height: +H * (ref ? 2 : 1) + (ref ? 8 : 0) } });
  await page.goto('file://' + path.resolve(__dirname, 'render.html'));
  if (process.env.STUDIO) await page.evaluate(() => { window.STUDIO = true; });
  const tree = JSON.parse(require('fs').readFileSync(json, 'utf8'));
  const bg = ref ? 'file://' + path.resolve(ref) : null;
  await page.evaluate(async ([t, w, h, b]) => { await window.renderUI(t, w, h, b); }, [tree, +W, +H, bg]);
  if (ref) {
    await page.evaluate(([src, w, h]) => {
      const img = document.createElement('img'); img.src = src; img.style.cssText = `display:block;width:${w}px;height:${h}px;margin-bottom:8px`;
      document.body.insertBefore(img, document.body.firstChild);
    }, ['file://' + path.resolve(ref), +W, +H]);
    await page.waitForTimeout(300);
  }
  await page.screenshot({ path: out, fullPage: true });
  await browser.close();
})();
