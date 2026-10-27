// shoot.js: draws every <out>/<name>.json (a ScreenGui dumped by dump.luau) with index.html in Chromium and saves
// <out>/<name>.png at 1280x720. Prints what it could not draw (images without a local PNG, ViewportFrames, notes).
//   node hood/tools/preview/ui/shoot.js <out dir> [--no-bg]
const fs = require('fs'), path = require('path');
let playwright;
try { playwright = require('playwright'); } catch (e) {
  try { playwright = require('/opt/node22/lib/node_modules/playwright'); } catch (e2) { console.error('playwright not found: npm install playwright'); process.exit(1); }
}
const out = path.resolve(process.argv[2] || path.join(__dirname, 'out'));
const bg = !process.argv.includes('--no-bg');
const page_url = 'file://' + path.join(__dirname, 'index.html');
(async () => {
  const browser = await playwright.chromium.launch({ args: ['--allow-file-access-from-files'] });
  const files = fs.readdirSync(out).filter(f => f.endsWith('.json')).sort();
  for (const f of files) {
    const tree = JSON.parse(fs.readFileSync(path.join(out, f), 'utf8'));
    // (the screen: SW x SH with a NOTCH each side, from shoot.sh; default 1280 x 720)
    const W = +process.env.SW || 1280, H = +process.env.SH || 720, notch = +process.env.NOTCH || 0;
    const page = await browser.newPage({ viewport: { width: W, height: H } });
    await page.goto(page_url);
    const report = await page.evaluate(([t, b, w, h, n]) => window.renderUI(t, { bg: b, w, h, notch: n }), [tree, bg, W, H, notch]);
    await page.waitForTimeout(150);
    const png = path.join(out, f.replace(/\.json$/, '.png'));
    await page.screenshot({ path: png });
    console.log('[shot] ' + path.basename(png));
    if (report.missingFiles.length) console.log('  missing files: ' + report.missingFiles.join(', '));
    if (report.unknownImages.length) console.log('  images with no local picture (' + report.unknownImages.length + '): ' + report.unknownImages.slice(0, 8).join(', '));
    if (report.viewports) console.log('  3D views not drawn: ' + report.viewports);
    for (const n of report.notes) console.log('  note: ' + n);
    if (f.startsWith('hud')) {
      // (the HUD's blocks: what overlaps, what runs off the screen; written beside the picture too)
      const lay = await page.evaluate(([w, h]) => window.layoutReport(w, h), [W, H]);
      fs.writeFileSync(png.replace(/\.png$/, '.layout.json'), JSON.stringify(lay, null, 1));
      for (const o of lay.overlaps) console.log(`  overlap: ${o.a} x ${o.b} (${o.w} x ${o.h} px)`);
      for (const o of lay.off) console.log(`  off screen: ${o.name} (${o.x0},${o.y0} - ${o.x1},${o.y1} on ${W} x ${H})`);
      if (!lay.overlaps.length && !lay.off.length) console.log('  layout: no overlaps, nothing off screen (' + lay.blocks.length + ' blocks)');
    }
    await page.close();
  }
  await browser.close();
})();
