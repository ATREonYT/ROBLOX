// Draws a frames JSON (from scene.luau) with three.js in headless Chromium, then encodes an H.264 MP4.
// Usage: node render.mjs frames.json out.mp4   (needs NODE_PATH with playwright, and ffmpeg)
// Frame boxes: {p:[x,y,z] centre, r:[9] row-major rotation, s:[sx,sy,sz], c:"#rrggbb"}. Roblox axes (Y up, -Z forward).
// Optional per frame: sprites [{p, s (width, studs), c, a (opacity), t (assets/fx name), r (rotation deg), add (glow)}]
// and ribbons [{pts [[x,y,z]...], w [widths], a [opacities], c, add}] (camera-facing strips: the slashes).
// Optional at the top: sky, ground (colours), grid (false to hide).
import { createRequire } from 'module';
import fs from 'fs';
import os from 'os';
import path from 'path';
import { execFileSync } from 'child_process';
import { fileURLToPath } from 'url';

const require = createRequire(import.meta.url);
const { chromium } = require('playwright');
const here = path.dirname(fileURLToPath(import.meta.url));
const [inFile, outFile] = process.argv.slice(2);
if (!inFile || !outFile) { console.error('usage: node render.mjs frames.json out.mp4'); process.exit(1); }
const data = JSON.parse(fs.readFileSync(inFile, 'utf8'));
const W = data.width || 1280, H = data.height || 720, fps = data.fps || 30;

// The page lives on a fake http origin so the ES module import works (file:// blocks modules).
const PAGE = `<!doctype html><html><body style="margin:0;overflow:hidden"><script type="module">
import * as THREE from './three.module.min.js';
const renderer = new THREE.WebGLRenderer({ antialias: true, preserveDrawingBuffer: true });
renderer.setSize(${W}, ${H});
renderer.shadowMap.enabled = true;
renderer.shadowMap.type = THREE.PCFSoftShadowMap;
document.body.appendChild(renderer.domElement);
const scene = new THREE.Scene();
const SKY = ${JSON.stringify(data.sky || '#9fd0f5')}, GROUND = ${JSON.stringify(data.ground || '#e3cf9c')};
scene.background = new THREE.Color(SKY);
scene.fog = new THREE.Fog(SKY, 80, 220);
const camera = new THREE.PerspectiveCamera(70, ${W} / ${H}, 0.1, 500); // Roblox default FOV
scene.add(new THREE.HemisphereLight('#dff0ff', '#b89c70', 1.6));
const sun = new THREE.DirectionalLight('#fff6e8', 1.8);
sun.castShadow = true;
sun.shadow.mapSize.set(2048, 2048);
Object.assign(sun.shadow.camera, { left: -25, right: 25, top: 25, bottom: -25, near: 1, far: 120 });
sun.shadow.bias = -0.0005;
scene.add(sun, sun.target);
const ground = new THREE.Mesh(new THREE.PlaneGeometry(1000, 1000), new THREE.MeshLambertMaterial({ color: GROUND }));
ground.rotation.x = -Math.PI / 2;
ground.receiveShadow = true;
scene.add(ground);
const grid = new THREE.GridHelper(400, 100, '#a88c55', '#a88c55'); // 4-stud cells
grid.material.transparent = true; grid.material.opacity = 0.45; grid.position.y = 0.01;
scene.add(grid);
grid.visible = ${data.grid === false ? 'false' : 'true'};
// particle pictures (assets/fx), loaded once
const loader = new THREE.TextureLoader();
const tex = {};
for (const n of ${JSON.stringify(fs.readdirSync(path.join(here, '../../../assets/fx')).map(f => f.replace('.png', '')))}) tex[n] = loader.load('./fx/' + n + '.png');
for (const n of ['aura-star', 'aura-ring']) tex[n] = loader.load('./icons/' + n + '.png'); // (the lobby's Aura stars)
const sprites = [];
const ribbonMeshes = [];
const unit = new THREE.BoxGeometry(1, 1, 1);
const pool = [];
const m = new THREE.Matrix4(), sc = new THREE.Matrix4();
window.draw = (f) => {
  f.boxes.forEach((b, i) => {
    let mesh = pool[i];
    if (!mesh) {
      mesh = pool[i] = new THREE.Mesh(unit, new THREE.MeshLambertMaterial());
      mesh.castShadow = mesh.receiveShadow = true;
      mesh.matrixAutoUpdate = false;
      scene.add(mesh);
    }
    const r = b.r, p = b.p;
    m.set(r[0], r[1], r[2], p[0], r[3], r[4], r[5], p[1], r[6], r[7], r[8], p[2], 0, 0, 0, 1);
    mesh.matrix.multiplyMatrices(m, sc.makeScale(b.s[0], b.s[1], b.s[2]));
    mesh.material.color.set(b.c);
    mesh.visible = true;
  });
  for (let i = f.boxes.length; i < pool.length; i++) pool[i].visible = false;
  const asList = (v) => (Array.isArray(v) ? v : []); // (Lune writes an empty list as {})
  const sp = asList(f.sprites);
  sp.forEach((q, i) => {
    let s = sprites[i];
    if (!s) { s = sprites[i] = new THREE.Sprite(new THREE.SpriteMaterial({ transparent: true, depthWrite: false })); scene.add(s); }
    const mat = s.material;
    const want = tex[(q.t || 'glow').toLowerCase()] || tex.glow;
    if (mat.map !== want) { mat.map = want; mat.needsUpdate = true; }
    const blend = q.add ? THREE.AdditiveBlending : THREE.NormalBlending;
    if (mat.blending !== blend) { mat.blending = blend; mat.needsUpdate = true; }
    mat.color.set(q.c); mat.opacity = q.a; mat.rotation = (q.r || 0) * Math.PI / 180;
    s.position.set(q.p[0], q.p[1], q.p[2]); s.scale.set(q.s, q.s, 1); s.visible = true;
  });
  for (let i = sp.length; i < sprites.length; i++) sprites[i].visible = false;
  const rb = asList(f.ribbons);
  rb.forEach((q, i) => {
    let mesh = ribbonMeshes[i];
    if (!mesh) {
      mesh = ribbonMeshes[i] = new THREE.Mesh(new THREE.BufferGeometry(), new THREE.MeshBasicMaterial({ vertexColors: true, transparent: true, depthWrite: false, side: THREE.DoubleSide }));
      scene.add(mesh);
    }
    const n = q.pts.length, pos = new Float32Array(n * 2 * 3), col = new Float32Array(n * 2 * 4), idx = [];
    const c = new THREE.Color(q.c), cam = new THREE.Vector3(...f.camera.pos);
    for (let k = 0; k < n; k++) {
      const p = new THREE.Vector3(...q.pts[k]);
      const a = new THREE.Vector3(...q.pts[Math.max(0, k - 1)]), b = new THREE.Vector3(...q.pts[Math.min(n - 1, k + 1)]);
      const dir = b.sub(a).normalize(), view = cam.clone().sub(p).normalize();
      const side = new THREE.Vector3().crossVectors(dir, view).normalize().multiplyScalar(q.w[k] / 2);
      [p.clone().add(side), p.clone().sub(side)].forEach((v, j) => {
        pos.set([v.x, v.y, v.z], (k * 2 + j) * 3);
        col.set([c.r, c.g, c.b, q.a[k]], (k * 2 + j) * 4);
      });
      if (k < n - 1) idx.push(k * 2, k * 2 + 1, k * 2 + 2, k * 2 + 1, k * 2 + 3, k * 2 + 2);
    }
    mesh.geometry.setAttribute('position', new THREE.BufferAttribute(pos, 3));
    mesh.geometry.setAttribute('color', new THREE.BufferAttribute(col, 4));
    mesh.geometry.setIndex(idx);
    mesh.material.blending = q.add ? THREE.AdditiveBlending : THREE.NormalBlending;
    mesh.material.needsUpdate = true;
    mesh.visible = true;
  });
  for (let i = rb.length; i < ribbonMeshes.length; i++) ribbonMeshes[i].visible = false;
  const [cx, cy, cz] = f.camera.pos, [lx, ly, lz] = f.camera.look;
  camera.position.set(cx, cy, cz);
  camera.lookAt(lx, ly, lz);
  sun.target.position.set(lx, 0, lz); // shadow box follows what the camera looks at
  sun.position.set(lx + 30, 60, lz + 20);
  renderer.render(scene, camera);
};
window.ready = true;
</script></body></html>`;

const tmp = fs.mkdtempSync(path.join(os.tmpdir(), 'motion3d-'));
const t0 = Date.now();
const browser = await chromium.launch({ args: ['--use-gl=angle', '--use-angle=swiftshader', '--enable-unsafe-swiftshader'] });
const page = await browser.newPage({ viewport: { width: W, height: H } });
page.on('pageerror', (e) => console.error('page error:', e.message));
await page.route('http://motion3d.local/**', (route) => {
  const name = new URL(route.request().url()).pathname;
  if (name === '/index.html') return route.fulfill({ contentType: 'text/html', body: PAGE });
  if (name.startsWith('/icons/')) return route.fulfill({ contentType: 'image/png', body: fs.readFileSync(path.join(here, '../../../assets/icons', path.basename(name))) });
  if (name.startsWith('/fx/')) return route.fulfill({ contentType: 'image/png', body: fs.readFileSync(path.join(here, '../../../assets/fx', path.basename(name))) });
  route.fulfill({ contentType: 'text/javascript', body: fs.readFileSync(path.join(here, 'vendor', 'three.module.min.js')) });
});
await page.goto('http://motion3d.local/index.html');
await page.waitForFunction(() => window.ready === true);
for (let i = 0; i < data.frames.length; i++) {
  await page.evaluate((f) => window.draw(f), data.frames[i]);
  await page.screenshot({ path: path.join(tmp, `f_${String(i + 1).padStart(4, '0')}.png`) });
}
await browser.close();
execFileSync('ffmpeg', ['-loglevel', 'error', '-y', '-framerate', String(fps), '-i', path.join(tmp, 'f_%04d.png'),
  '-c:v', 'libx264', '-pix_fmt', 'yuv420p', outFile]);
fs.rmSync(tmp, { recursive: true, force: true });
console.log(`rendered ${data.frames.length} frames in ${((Date.now() - t0) / 1000).toFixed(1)}s -> ${outFile}`);
