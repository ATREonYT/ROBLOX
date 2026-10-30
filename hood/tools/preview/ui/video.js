// video.js <dir>: draws every <dir>/u_NNNN.json (all the player's ScreenGuis at one frame, dumped by firstvideo.luau)
// with index.html, on a see-through background, to <dir>/u_NNNN.png (1280x720), for ffmpeg to lay over the 3D frames.
// One browser page for all of them (a frame a few hundred ms). START / END (env) draw a slice.
const fs = require('fs'), path = require('path');
let playwright;
try { playwright = require('playwright'); } catch (e) { playwright = require(path.join(__dirname, '..', 'render14', 'node_modules', 'playwright')); }
const dir = path.resolve(process.argv[2]);
const url = 'file://' + path.join(__dirname, 'index.html');
(async () => {
  const browser = await playwright.chromium.launch({ executablePath: process.env.CHROME || undefined, args: ['--allow-file-access-from-files'] });
  const page = await browser.newPage({ viewport: { width: 1280, height: 720 } });
  const files = fs.readdirSync(dir).filter(f => /^u_\d+\.json$/.test(f)).sort();
  const START = +(process.env.START || 0), END = Math.min(files.length, +(process.env.END || files.length));
  const t0 = Date.now();
  for (let i = START; i < END; i++) {
    const f = files[i];
    let tree;
    try { tree = JSON.parse(fs.readFileSync(path.join(dir, f), 'utf8')); } catch (e) { console.log('skip ' + f); continue; }
    await page.goto(url);
    await page.evaluate(() => { document.body.style.background = 'transparent'; document.documentElement.style.background = 'transparent'; });
    await page.evaluate(t => window.renderUI(t, { bg: false, w: 1280, h: 720 }), tree);
    await page.screenshot({ path: path.join(dir, f.replace(/\.json$/, '.png')), omitBackground: true });
    if ((i + 1) % 100 === 0) console.log(`${i + 1} ui frames, ${((Date.now() - t0) / (i + 1 - START) / 1000).toFixed(2)} s/frame`);
  }
  await browser.close();
})().catch(e => { console.error(e); process.exit(1); });
