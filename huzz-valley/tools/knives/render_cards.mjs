// Renders the owner's 30 knives (and his 5 Game Pass knives, his 18 Halloween knives) (his .glb geometry and colours, from tools/knives/knife_meshes.py) for the shop
// cards: each knife on a transparent square, diagonal (tip up-right) like his mock-up
// (design/knives/knifepictures-mockup.png), flat side to the camera with a small turn so its shape reads.
// Two pictures per knife: <key>.png (lit, glowing parts unlit like Roblox Neon) and <key>_glow.png (only the glowing
// parts, the rest black), which tools/knives/compose_cards.py turns into the finished card art.
// Usage (from huzz-valley/): NODE_PATH=$(npm root -g) node tools/knives/render_cards.mjs <meshes.json> <outDir> [size]
import { createRequire } from 'module';
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const require = createRequire(import.meta.url);
const { chromium } = require('playwright');
const here = path.dirname(fileURLToPath(import.meta.url));
const [meshFile, outDir, sizeArg] = process.argv.slice(2);
const S = Number(sizeArg || 768);
const meshes = JSON.parse(fs.readFileSync(meshFile, 'utf8'));
fs.mkdirSync(outDir, { recursive: true });

const PAGE = `<!doctype html><html><body style="margin:0;background:transparent"><script type="module">
import * as THREE from './three.module.min.js';
const renderer = new THREE.WebGLRenderer({ antialias: true, alpha: true, preserveDrawingBuffer: true });
renderer.setSize(${S}, ${S});
renderer.setClearColor(0x000000, 0);
document.body.appendChild(renderer.domElement);
const scene = new THREE.Scene();
scene.add(new THREE.AmbientLight('#ffffff', 1.1));
const key = new THREE.DirectionalLight('#ffffff', 2.2); key.position.set(-2, 3, 4); scene.add(key);
const fill = new THREE.DirectionalLight('#dfe6ff', 0.6); fill.position.set(3, -1, 2); scene.add(fill);
const rim = new THREE.DirectionalLight('#ffffff', 1.2); rim.position.set(2, 2, -3); scene.add(rim);
const camera = new THREE.OrthographicCamera(-1, 1, 1, -1, -10, 10);
camera.position.set(0, 0, 5); camera.lookAt(0, 0, 0);
let group = null;
window.draw = (parts, mode, glowCol) => {
  if (group) { scene.remove(group); group.traverse((o) => o.geometry && o.geometry.dispose()); }
  group = new THREE.Group();
  for (const p of parts) {
    const g = new THREE.BufferGeometry();
    g.setAttribute('position', new THREE.Float32BufferAttribute(p.pos, 3));
    g.computeVertexNormals();
    let mat;
    if (mode === 'glow') mat = new THREE.MeshBasicMaterial({ color: p.glow ? p.col : '#000000' });
    else if (p.glow) mat = new THREE.MeshBasicMaterial({ color: p.col });
    else mat = new THREE.MeshStandardMaterial({ color: p.col, metalness: Math.min(0.35, p.metal * 0.4), roughness: 0.42, flatShading: true });
    group.add(new THREE.Mesh(g, mat));
  }
  rim.color.set(glowCol || '#ffffff');
  // tip up-right (35 degrees over the horizontal), turned 18 degrees round the blade so the bevels catch the light
  const inner = new THREE.Group(); inner.add(group); group.rotation.y = THREE.MathUtils.degToRad(18);
  const outer = new THREE.Group(); outer.add(inner); outer.rotation.z = THREE.MathUtils.degToRad(-55);
  scene.add(outer);
  outer.updateMatrixWorld(true);
  const box = new THREE.Box3().setFromObject(outer);
  // fit the knife into 84% x 50% of the square, centred 58% down: the card crops its top and bottom a little, the
  // name and rarity line sit over the top, the button under it
  const w = box.max.x - box.min.x, h = box.max.y - box.min.y;
  const half = Math.max(w / 0.84, h / 0.50) / 2;
  const cx = (box.min.x + box.max.x) / 2, cy = (box.min.y + box.max.y) / 2 + half * 0.16;
  Object.assign(camera, { left: cx - half, right: cx + half, top: cy + half, bottom: cy - half });
  camera.updateProjectionMatrix();
  renderer.render(scene, camera);
  scene.remove(outer);
  group = outer;
};
window.ready = true;
</script></body></html>`;

const browser = await chromium.launch({ args: ['--use-gl=angle', '--use-angle=swiftshader', '--enable-unsafe-swiftshader'] });
const page = await browser.newPage({ viewport: { width: S, height: S } });
page.on('pageerror', (e) => console.error('page error:', e.message));
await page.route('http://cards.local/**', (route) => {
  const name = new URL(route.request().url()).pathname;
  if (name === '/index.html') return route.fulfill({ contentType: 'text/html', body: PAGE });
  route.fulfill({ contentType: 'text/javascript', body: fs.readFileSync(path.join(here, '../preview/motion3d/vendor/three.module.min.js')) });
});
await page.goto('http://cards.local/index.html');
await page.waitForFunction(() => window.ready === true);
const knives = JSON.parse(fs.readFileSync(path.join(here, 'knives.json'), 'utf8'));
const only = process.env.ONLY; // (e.g. ONLY=Exclusive: just the Game Pass knives; ONLY=halloween: his Halloween file's)
for (const k of knives) {
  if (only && k.rarity !== only && !k.file.startsWith(only + '/')) continue;
  const parts = meshes[k.key];
  if (!parts) continue;
  const glow = k.glow ? '#' + k.glow : '#ffffff';
  for (const mode of ['lit', 'glow']) {
    await page.evaluate(([p, m, g]) => window.draw(p, m, g), [parts, mode, glow]);
    await page.locator('canvas').screenshot({ path: path.join(outDir, `${k.key}${mode === 'glow' ? '_glow' : ''}.png`), omitBackground: true });
  }
}
await browser.close();
console.log(`rendered ${knives.length} knives -> ${outDir}`);
