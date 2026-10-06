// Usage: node shoot.js scene.json views.json outDir
const { chromium } = require('playwright');
const http = require('http');
const fs = require('fs');
const path = require('path');

const [sceneFile, viewsFile, outDir] = process.argv.slice(2);
const root = __dirname;
const types = { '.html': 'text/html', '.js': 'text/javascript', '.json': 'application/json', '.png': 'image/png' };
// Effect textures come from hood/art/vfx (the same PNGs the game uploads); render/vfx holds preview-only extras.
const art = path.resolve(root, '../../../art/vfx');
const server = http.createServer((req, res) => {
  const url = decodeURIComponent(req.url.split('?')[0]);
  let p = path.join(root, url);
  if (url.startsWith('/vfx/') && !fs.existsSync(p)) p = path.join(art, url.slice(5));
  if (!(p.startsWith(root) || p.startsWith(art)) || !fs.existsSync(p) || fs.statSync(p).isDirectory()) { res.writeHead(404); return res.end(); }
  res.writeHead(200, { 'Content-Type': types[path.extname(p)] || 'application/octet-stream' });
  fs.createReadStream(p).pipe(res);
});

(async () => {
  await new Promise(r => server.listen(0, r));
  const port = server.address().port;
  const browser = await chromium.launch({
    executablePath: process.env.CHROME || '/opt/pw-browsers/chromium-1194/chrome-linux/chrome',
    args: ['--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--ignore-gpu-blocklist'],
  });
  const page = await browser.newPage({ viewport: { width: +(process.env.W || 1600), height: +(process.env.H || 1000) } });
  page.on('console', m => { if (m.type() === 'error') console.error('page:', m.text()); });
  page.on('pageerror', e => console.error('pageerror:', e.message));
  await page.goto(`http://localhost:${port}/index.html?w=${process.env.W || 1600}&h=${process.env.H || 1000}`);
  await page.waitForFunction('window.ready === true', null, { timeout: 60000 });
  const data = JSON.parse(fs.readFileSync(sceneFile, 'utf8'));
  const views = JSON.parse(fs.readFileSync(viewsFile, 'utf8'));
  const info = await page.evaluate(([d, o]) => window.loadScene(d, o), [data, views.options || {}]);
  console.log('loaded', JSON.stringify(info));
  fs.mkdirSync(outDir, { recursive: true });
  for (const v of views.views) {
    const url = await page.evaluate(c => window.shoot(c), v);
    fs.writeFileSync(path.join(outDir, v.name + '.png'), Buffer.from(url.split(',')[1], 'base64'));
    console.log('wrote', v.name);
  }
  await browser.close();
  server.close();
})().catch(e => { console.error(e); process.exit(1); });
