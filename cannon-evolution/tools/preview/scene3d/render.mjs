// Renders the training lanes from tools/preview/dump_booths.luau's JSON with index.html (three.js) in the
// pre-installed Playwright Chromium. Run from this folder after `npm install`:
//   lune run tools/preview/dump_booths.luau /tmp/lanes.json       (from cannon-evolution/)
//   node render.mjs /tmp/lanes.json out/  [station mode view t ...]  e.g.  6 day lane 0  1 studio lane 0  1 day row 0
import { createRequire } from 'module';
import http from 'http';
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const require = createRequire(import.meta.url);
const { chromium } = require('playwright');
const here = path.dirname(fileURLToPath(import.meta.url));
const [dataPath, outDir, ...rest] = process.argv.slice(2);
const jobs = [];
for (let i = 0; i + 3 < rest.length + 1 && rest.length; i += 4) jobs.push({ station: rest[i], mode: rest[i + 1], view: rest[i + 2], t: Number(rest[i + 3] || 0) });
if (!jobs.length) jobs.push({ station: '1', mode: 'day', view: 'lane', t: 0 }, { station: '6', mode: 'day', view: 'lane', t: 0 });
fs.mkdirSync(outDir, { recursive: true });

const types = { '.html': 'text/html', '.js': 'text/javascript', '.mjs': 'text/javascript', '.json': 'application/json' };
const server = http.createServer((req, res) => {
  const file = path.join(here, decodeURIComponent(req.url.split('?')[0]));
  if (!file.startsWith(here) || !fs.existsSync(file) || fs.statSync(file).isDirectory()) { res.writeHead(404); res.end(); return; }
  res.writeHead(200, { 'Content-Type': types[path.extname(file)] || 'application/octet-stream' });
  fs.createReadStream(file).pipe(res);
});
await new Promise(r => server.listen(0, '127.0.0.1', r));
const port = server.address().port;

const browser = await chromium.launch({ args: ['--use-gl=angle', '--use-angle=swiftshader', '--enable-unsafe-swiftshader'] });
const page = await browser.newPage({ viewport: { width: 1280, height: 800 } });
page.on('console', m => { if (m.type() === 'error') console.log('page:', m.text()); });
page.on('pageerror', e => console.log('page error:', e.message));
await page.goto(`http://127.0.0.1:${port}/index.html`);
await page.waitForFunction(() => window.ready === true, null, { timeout: 30000 });
const data = JSON.parse(fs.readFileSync(dataPath, 'utf8'));
for (const j of jobs) {
  await page.evaluate(o => window.renderLane(o), { ...j, data });
  const out = path.join(outDir, `lane${j.station}-${j.mode}-${j.view}-${String(j.t).replace('.', '_')}.png`);
  await page.locator('canvas').screenshot({ path: out });
  console.log('saved', out);
}
await browser.close();
server.close();
