// walk.js <scene.json> <outDir> [W H N]: the avatar walks a route (WALK env, default spawn -> boxes -> ranges -> armory -> gate), a follow camera
// 12 back and 9 up (the reference's), the scene re-loaded per frame with the particle clock advanced. Frames -> f_NNNN.png
const { chromium } = require('playwright');
const http = require('http'), fs = require('fs'), path = require('path');
const [sceneFile, outDir, Wa, Ha, Na] = process.argv.slice(2);
const W = +(Wa || 960), H = +(Ha || 540), N = +(Na || 120), FPS = +(process.env.FPS || 10); // (FPS: the particle clock's frame rate)
const root = __dirname;
const art = path.join(__dirname, '..', '..', '..', 'art', 'vfx'); // (hood/art/vfx)
const types = { '.html': 'text/html', '.js': 'text/javascript', '.json': 'application/json', '.png': 'image/png', '.woff2': 'font/woff2', '.ttf': 'font/ttf' };
const server = http.createServer((req, res) => {
  const url = decodeURIComponent(req.url.split('?')[0]);
  let p = path.join(root, url);
  if (url.startsWith('/vfx/') && !fs.existsSync(p)) p = path.join(art, url.slice(5));
  if (!fs.existsSync(p) || fs.statSync(p).isDirectory()) { res.writeHead(404); return res.end(); }
  res.writeHead(200, { 'Content-Type': types[path.extname(p)] || 'application/octet-stream' });
  fs.createReadStream(p).pipe(res);
});
// the route (map frame x,z; the lobby's world x is +2400): WALK='x,z;x,z;...' or the default spawn tour
const WP = (process.env.WALK || '0,58;0,86;0,62;-44,55;-20,55;26,55;6,55;0,48;0,12').split(';').map(s => s.split(',').map(Number));
const segs = []; let total = 0;
for (let i = 0; i < WP.length - 1; i++) { const a = WP[i], b = WP[i + 1]; const L = Math.hypot(b[0] - a[0], b[1] - a[1]); segs.push([a, b, total, L]); total += L; }
function at(d) { for (const [a, b, s0, L] of segs) if (d <= s0 + L) { const u = (d - s0) / L; return [a[0] + (b[0] - a[0]) * u, a[1] + (b[1] - a[1]) * u, Math.atan2(b[0] - a[0], b[1] - a[1])]; } const l = segs[segs.length - 1]; return [l[1][0], l[1][1], 0]; }
function avatar(x, z, yaw, k) {
  const c = Math.cos(yaw), s = Math.sin(yaw); const out = [];
  const swing = Math.sin(k * 1.6) * 0.35;
  const C = (r, g, b) => [r / 255, g / 255, b / 255];
  const part = (n, size, o, col, tilt = 0) => { const wx = 2400 + x + c * o[0] + s * o[2], wz = z - s * o[0] + c * o[2];
    out.push({ c: col, cf: [wx, 0.12 + o[1], wz, c, 0, s, 0, 1, 0, -s, 0, c], k: 'Part', m: 'SmoothPlastic', n, s: size, sh: 'Block', shadow: true, t: 0 }); };
  part('AvLegL', [0.95, 2, 1], [-0.5, 1.0, swing], C(40, 110, 60)); part('AvLegR', [0.95, 2, 1], [0.5, 1.0, -swing], C(40, 110, 60));
  part('AvTorso', [2, 2, 1], [0, 3.0, 0], C(30, 110, 190));
  part('AvArmL', [0.95, 2, 1], [-1.5, 3.0, -swing], C(245, 205, 48)); part('AvArmR', [0.95, 2, 1], [1.5, 3.0, swing], C(245, 205, 48));
  part('AvHead', [1.25, 1.2, 1.2], [0, 4.6, 0], C(245, 205, 48));
  return out;
}
(async () => {
  await new Promise(r => server.listen(0, r));
  const port = server.address().port;
  const browser = await chromium.launch({ executablePath: process.env.CHROME || '/opt/pw-browsers/chromium-1194/chrome-linux/chrome',
    args: ['--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--ignore-gpu-blocklist', '--disable-gpu-watchdog'] });
  const page = await browser.newPage({ viewport: { width: W, height: H } });
  page.on('pageerror', e => console.error('pageerror:', e.message));
  await page.goto(`http://localhost:${port}/index.html?w=${W}&h=${H}`);
  await page.waitForFunction('window.ready === true', null, { timeout: 120000 });
  fs.mkdirSync(outDir, { recursive: true });
  const data = JSON.parse(fs.readFileSync(sceneFile, 'utf8'));
  const base = data.parts.length;
  let cam = null, yawS = null; const t0 = Date.now();
  for (let i = 0; i < N; i++) {
    const d = total * (i / (N - 1)) ** 1;
    const [x, z, yaw] = at(d);
    if (yawS === null) yawS = yaw; else { let dy = yaw - yawS; while (dy > Math.PI) dy -= 2 * Math.PI; while (dy < -Math.PI) dy += 2 * Math.PI; yawS += dy * 0.22; }
    data.parts.length = base; data.parts.push(...avatar(x, z, yaw + Math.PI, i));
    const want = [2400 + x - Math.sin(yawS) * 12, 9.2, z - Math.cos(yawS) * 12];
    cam = cam ? cam.map((v, k) => v + (want[k] - v) * 0.5) : want;
    const look = [2400 + x + Math.sin(yawS) * 1, 3.4, z + Math.cos(yawS) * 1];
    const out = path.join(outDir, 'f_' + String(i).padStart(4, '0') + '.png');
    await page.evaluate(([dd, o]) => window.loadScene(dd, o), [data, { time: 3 + i / FPS, bloom: true, lighting: 'HoodToy', lights: 24 }]);
    const url = await page.evaluate(c => window.shoot(c), { name: 'f' + i, pos: cam, look, fov: 70 });
    fs.writeFileSync(out, Buffer.from(url.split(',')[1], 'base64'));
    if ((i + 1) % 10 === 0) console.log(`${i + 1} frames, ${((Date.now() - t0) / (i + 1) / 1000).toFixed(1)} s/frame`);
  }
  await browser.close(); server.close();
})().catch(e => { console.error(e); process.exit(1); });
