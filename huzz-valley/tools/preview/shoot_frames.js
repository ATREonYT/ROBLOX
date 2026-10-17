// Renders every frame_NNNN.json in a folder to frame_NNNN.png with one browser (for motion.sh).
// Usage: node shoot_frames.js <dir> <width> <height> [background.png]
const { chromium } = require('playwright');
const fs = require('fs');
const path = require('path');
(async () => {
  const [dir, W, H, bgFile] = process.argv.slice(2);
  const browser = await chromium.launch({ args: ['--allow-file-access-from-files'] });
  const page = await browser.newPage({ viewport: { width: +W, height: +H } });
  await page.goto('file://' + path.resolve(__dirname, 'render.html'));
  const bg = bgFile ? 'file://' + path.resolve(bgFile) : null;
  const files = fs.readdirSync(dir).filter(f => /^frame_\d+\.json$/.test(f)).sort();
  for (const f of files) {
    const tree = JSON.parse(fs.readFileSync(path.join(dir, f), 'utf8'));
    await page.evaluate(async ([t, w, h, b]) => { await window.renderUI(t, w, h, b); }, [tree, +W, +H, bg]);
    await page.screenshot({ path: path.join(dir, f.replace('.json', '.png')) });
  }
  await browser.close();
})();
