// walk.js <scene.json> <outDir> [W H N]: the avatar walks a route (WALK env, default spawn -> boxes -> ranges -> armory -> gate), a follow camera
// 12 back and 9 up (the reference's), the scene re-loaded per frame with the particle clock advanced. Frames -> f_NNNN.png
const { chromium } = require('playwright');
const http = require('http'), fs = require('fs'), path = require('path');
const [sceneFile, outDir, Wa, Ha, Na] = process.argv.slice(2);
const W = +(Wa || 960), H = +(Ha || 540), N = CAMS ? CAMS.frames.length : +(Na || 120), FPS = +(process.env.FPS || 10); // (FPS: the particle clock's frame rate)
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
// GUIDE=<file> (Oct 27, ui/corevideo.luau's guide_frames.dat): the real HoodClient/GoalGuide's parts for each frame, recorded
// in the game harness on the same route (its route is used when WALK is not set)
const GUIDE = process.env.GUIDE ? JSON.parse(fs.readFileSync(process.env.GUIDE, 'utf8')) : null;
// CAMS=<file> (Oct 27, ui/firstvideo.luau's cams.json): a recorded play — per frame the game camera (c, l: eye and a
// point it looks at), the kid (a: x, y, z of the root, facing) and the parts the scripts added to the world (p); N is
// its frame count and the route, CAM and GUIDE are not used
const CAMS = process.env.CAMS ? JSON.parse(fs.readFileSync(process.env.CAMS, 'utf8')) : null;
// (the game harness has no raycast, so the guide's floor chevrons come at the feet's height there; in the game
// GoalGuide lays them 0.16 over the floor its ray finds: the same is done here against the scene's floor parts)
let floorParts = null;
function onFloor(p) {
  if (!/^Chevron/.test(p.n)) return p;
  const [x, y, z] = p.cf;
  let top = null;
  for (const q of floorParts) {
    const c = q.cf; if (Math.abs(c[7]) < 0.999) continue; // (upright parts only)
    if (Math.abs(x - c[0]) > q.s[0] / 2 || Math.abs(z - c[2]) > q.s[2] / 2) continue;
    const t = c[1] + q.s[1] / 2;
    if (t <= y + 2.3 && t >= y - 2.6 && (top === null || t > top)) top = t;
  }
  const cf = p.cf.slice(); if (top !== null) cf[1] = top + 0.16;
  // (see-through parts added per frame don't show in this renderer's walk: a chevron is drawn opaque, its colour mixed
  // with the hall's light floor by its transparency, which is how it reads on that floor)
  const k = 1 - (p.t || 0), fl = [0.86, 0.88, 0.92];
  return Object.assign({}, p, { cf, t: 0, c: p.c.map((v, j) => fl[j] + (v - fl[j]) * k) });
}
// CAM='back,up' (studs): the follow camera (default 12 back, 9.2 up; GUIDE walks use 12,12: from behind at head height the
// avatar hides the floor trail's first 15 studs, a player looking down a little sees it)
const CAM = (process.env.CAM || (GUIDE ? '12,12' : '12,9.2')).split(',').map(Number);
// the route (map frame x,z; the lobby's world x is +2400): WALK='x,z;x,z;...' or the default spawn tour
const WP = (process.env.WALK || (GUIDE && GUIDE.route) || '0,58;0,86;0,62;-44,55;-20,55;26,55;6,55;0,48;0,12').split(';').map(s => s.split(',').map(Number));
const segs = []; let total = 0;
for (let i = 0; i < WP.length - 1; i++) { const a = WP[i], b = WP[i + 1]; const L = Math.hypot(b[0] - a[0], b[1] - a[1]); segs.push([a, b, total, L]); total += L; }
function at(d) { for (const [a, b, s0, L] of segs) if (d <= s0 + L) { const u = (d - s0) / L; return [a[0] + (b[0] - a[0]) * u, a[1] + (b[1] - a[1]) * u, Math.atan2(b[0] - a[0], b[1] - a[1])]; } const l = segs[segs.length - 1]; return [l[1][0], l[1][1], 0]; }
function avatar(x, z, yaw, k, y0 = 0) {
  const c = Math.cos(yaw), s = Math.sin(yaw); const out = [];
  const swing = Math.sin(k * 1.6) * 0.35;
  const C = (r, g, b) => [r / 255, g / 255, b / 255];
  const part = (n, size, o, col, tilt = 0) => { const wx = 2400 + x + c * o[0] + s * o[2], wz = z - s * o[0] + c * o[2];
    out.push({ c: col, cf: [wx, y0 + 0.12 + o[1], wz, c, 0, s, 0, 1, 0, -s, 0, c], k: 'Part', m: 'SmoothPlastic', n, s: size, sh: 'Block', shadow: true, t: 0 }); };
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
  floorParts = data.parts.filter(q => q.k !== 'Terrain' && (q.t || 0) < 0.9 && q.s && q.cf);
  // START / END (env): render only frames START..END-1 (the camera's smoothing still runs from frame 0), so a long walk
  // can go in chunks, each with a fresh browser
  const START = +(process.env.START || 0), END = Math.min(N, +(process.env.END || N));
  let cam = null, yawS = null; const t0 = Date.now();
  for (let i = 0; i < END; i++) {
    if (CAMS) {
      if (i < START) continue;
      const f = CAMS.frames[i] || CAMS.frames[i - 1];
      data.parts.length = base;
      data.parts.push(...avatar(f.a[0] - 2400, f.a[2], f.a[3] + Math.PI, i, f.a[1] - 3.12));
      data.parts.push(...(f.p || []));
      await page.evaluate(([dd, o]) => window.loadScene(dd, o), [data, { time: 3 + i / FPS, bloom: true, lighting: process.env.LIGHTING || 'PlusOne', lights: 24 }]);
      const url = await page.evaluate(c => window.shoot(c), { name: 'f' + i, pos: f.c, look: f.l, fov: 70 });
      fs.writeFileSync(path.join(outDir, 'f_' + String(i).padStart(4, '0') + '.png'), Buffer.from(url.split(',')[1], 'base64'));
      if ((i + 1) % 10 === 0) console.log(`${i + 1} frames, ${((Date.now() - t0) / (i + 1 - START) / 1000).toFixed(1)} s/frame`);
      continue;
    }
    const d = total * (i / (N - 1)) ** 1;
    const [x, z, yaw] = at(d);
    if (yawS === null) yawS = yaw; else { let dy = yaw - yawS; while (dy > Math.PI) dy -= 2 * Math.PI; while (dy < -Math.PI) dy += 2 * Math.PI; yawS += dy * 0.22; }
    data.parts.length = base; data.parts.push(...avatar(x, z, yaw + Math.PI, i));
    if (GUIDE && Array.isArray(GUIDE.frames[i])) data.parts.push(...GUIDE.frames[i].map(onFloor)); // (an empty frame comes as {})
    const want = [2400 + x - Math.sin(yawS) * CAM[0], CAM[1], z - Math.cos(yawS) * CAM[0]];
    cam = cam ? cam.map((v, k) => v + (want[k] - v) * 0.5) : want;
    const look = [2400 + x + Math.sin(yawS) * 1, 3.4, z + Math.cos(yawS) * 1];
    if (i < START) continue;
    const out = path.join(outDir, 'f_' + String(i).padStart(4, '0') + '.png');
    await page.evaluate(([dd, o]) => window.loadScene(dd, o), [data, { time: 3 + i / FPS, bloom: true, lighting: 'HoodToy', lights: 24 }]);
    const url = await page.evaluate(c => window.shoot(c), { name: 'f' + i, pos: cam, look, fov: 70 });
    fs.writeFileSync(out, Buffer.from(url.split(',')[1], 'base64'));
    if ((i + 1) % 10 === 0) console.log(`${i + 1} frames, ${((Date.now() - t0) / (i + 1) / 1000).toFixed(1)} s/frame`);
  }
  await browser.close(); server.close();
})().catch(e => { console.error(e); process.exit(1); });
