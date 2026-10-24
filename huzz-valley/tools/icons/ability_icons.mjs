// Draws the 7 ability card pictures (Config/Powers Icon) as small 3D renders, in the look of the two icons on the
// owner's pictures b and c (design/owner-oct19: a purple bear trap with a light plate, a blue hex bubble), so every
// card has a sharp picture until he sends his own. Our renders, not his art: the two in his pictures are 60 px crops
// (blurry, CLAUDE.md rule 12); the rest had no picture at all.
// Since Oct 20 20:34 the cards show HIS power pictures ("bring back the old pictures for the powers ... We want to
// stand out": tools/icons/cut_power_tiles.py), so this only draws Speed Boost, the one his sheet doesn't have
// (the other six renders stay in the code for reference; don't put them back in ICONS over his pictures).
// Writes assets/icons/ability-<name>.png (384 x 384, transparent); then run tools/icons/pack_images.py.
// Usage (from huzz-valley/): NODE_PATH=/opt/node22/lib/node_modules node tools/icons/ability_icons.mjs
import { createRequire } from 'module';
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const require = createRequire(import.meta.url);
const { chromium } = require('playwright');
const here = path.dirname(fileURLToPath(import.meta.url));
const OUT = path.join(here, '../../assets/icons');
const SIZE = 384;
const ICONS = ['speed-boost'];

const PAGE = `<!doctype html><html><body style="margin:0;background:transparent"><script type="module">
import * as THREE from './three.module.min.js';
const S = ${SIZE};
const renderer = new THREE.WebGLRenderer({ antialias: true, alpha: true, preserveDrawingBuffer: true });
renderer.setPixelRatio(1);
renderer.setSize(S, S);
renderer.setClearColor(0x000000, 0);
document.body.appendChild(renderer.domElement);
const std = (c, o = {}) => new THREE.MeshStandardMaterial(Object.assign({ color: c, metalness: 0.35, roughness: 0.4 }, o));
function lights(scene) {
  scene.add(new THREE.HemisphereLight('#ffffff', '#4a4060', 1.6));
  const key = new THREE.DirectionalLight('#ffffff', 2.4); key.position.set(-2, 4, 3); scene.add(key);
  const rim = new THREE.DirectionalLight('#ffffff', 1.2); rim.position.set(3, 2, -3); scene.add(rim);
}
function camera(dist, height, fov = 30) {
  const cam = new THREE.PerspectiveCamera(fov, 1, 0.1, 100);
  cam.position.set(0, height, dist);
  cam.lookAt(0, 0, 0);
  return cam;
}
// a person: rounded body and a head (Body Double, Invisible, Glitchy)
function person(mat) {
  const g = new THREE.Group();
  const body = new THREE.Mesh(new THREE.CapsuleGeometry(0.42, 0.7, 8, 24), mat);
  body.position.y = -0.35;
  const head = new THREE.Mesh(new THREE.SphereGeometry(0.36, 32, 24), mat);
  head.position.y = 0.6;
  g.add(body, head);
  return g;
}
function sparkle(scene, x, y, s, color) {
  const shape = new THREE.Shape();
  for (let i = 0; i < 8; i++) {
    const a = (i / 8) * Math.PI * 2, r = i % 2 === 0 ? s : s * 0.28;
    const px = Math.sin(a) * r, py = Math.cos(a) * r;
    if (i === 0) shape.moveTo(px, py); else shape.lineTo(px, py);
  }
  const m = new THREE.Mesh(new THREE.ShapeGeometry(shape), new THREE.MeshBasicMaterial({ color, transparent: true, opacity: 0.95 }));
  m.position.set(x, y, 1.2);
  scene.add(m);
}
const BUILD = {
  'bear-trap'(scene) {
    const metal = std('#4f3f7a', { metalness: 0.55, roughness: 0.32 });
    const rim = std('#6f5ca6', { metalness: 0.55, roughness: 0.3 });
    const tooth = std('#cfc6ee', { metalness: 0.45, roughness: 0.28 });
    const ring = new THREE.Mesh(new THREE.TorusGeometry(1.05, 0.15, 18, 64), metal);
    ring.rotation.x = Math.PI / 2;
    scene.add(ring);
    const lip = new THREE.Mesh(new THREE.TorusGeometry(1.05, 0.07, 12, 64), rim);
    lip.rotation.x = Math.PI / 2; lip.position.y = 0.12;
    scene.add(lip);
    for (let i = 0; i < 16; i++) {
      const a = (i / 16) * Math.PI * 2;
      const t = new THREE.Mesh(new THREE.ConeGeometry(0.11, 0.42, 4), i % 2 ? metal : rim);
      t.position.set(Math.cos(a) * 1.0, 0.3, Math.sin(a) * 1.0);
      t.rotation.z = Math.cos(a) * 0.45; t.rotation.x = -Math.sin(a) * 0.45; // (leaning in, like open jaws)
      scene.add(t);
    }
    const bar = new THREE.Mesh(new THREE.BoxGeometry(2.4, 0.14, 0.2), metal);
    bar.position.y = 0.02; scene.add(bar);
    for (const x of [-1.22, 1.22]) {
      const coil = new THREE.Mesh(new THREE.CylinderGeometry(0.15, 0.15, 0.3, 16), rim);
      coil.rotation.z = Math.PI / 2; coil.position.set(x, 0.05, 0); scene.add(coil);
    }
    const plate = new THREE.Mesh(new THREE.BoxGeometry(0.62, 0.1, 0.62), tooth);
    plate.position.y = 0.16; plate.rotation.y = 0.5; scene.add(plate);
    scene.rotation.x = 0.1;
    return camera(5.6, 3.4);
  },
  shield(scene) {
    // a blue bubble with a hex net (a canvas texture), light from the top left
    const c = document.createElement('canvas'); c.width = 1024; c.height = 512;
    const g = c.getContext('2d');
    g.fillStyle = '#5fb8e6'; g.fillRect(0, 0, 1024, 512);
    g.strokeStyle = '#e6f8ff'; g.lineWidth = 6;
    const r = 34, h = Math.sqrt(3) * r;
    for (let row = -1; row < 512 / h + 1; row++) {
      for (let col = -1; col < 1024 / (1.5 * r) + 1; col++) {
        const cx = col * 1.5 * r, cy = row * h + (col % 2 ? h / 2 : 0);
        g.beginPath();
        for (let k = 0; k <= 6; k++) { const a = (k / 6) * Math.PI * 2; g.lineTo(cx + Math.cos(a) * r * 0.92, cy + Math.sin(a) * r * 0.92); }
        g.stroke();
      }
    }
    const tex = new THREE.CanvasTexture(c);
    tex.colorSpace = THREE.SRGBColorSpace;
    const ball = new THREE.Mesh(new THREE.SphereGeometry(1.15, 64, 48),
      new THREE.MeshStandardMaterial({ map: tex, metalness: 0.1, roughness: 0.25, transparent: true, opacity: 0.93, emissive: '#2a6f9a', emissiveIntensity: 0.35 }));
    scene.add(ball);
    const shine = new THREE.Mesh(new THREE.SphereGeometry(0.28, 24, 16), new THREE.MeshBasicMaterial({ color: '#ffffff', transparent: true, opacity: 0.55 }));
    shine.position.set(-0.5, 0.55, 0.85); shine.scale.set(1, 0.6, 0.3); scene.add(shine);
    return camera(5.3, 0.8);
  },
  'speed-boost'(scene) {
    const s = new THREE.Shape();
    const P = [[0.25, 1.2], [-0.55, -0.1], [-0.02, -0.1], [-0.3, -1.2], [0.6, 0.25], [0.05, 0.25], [0.35, 1.2]];
    P.forEach(([x, y], i) => (i ? s.lineTo(x, y) : s.moveTo(x, y)));
    const geo = new THREE.ExtrudeGeometry(s, { depth: 0.3, bevelEnabled: true, bevelThickness: 0.08, bevelSize: 0.06, bevelSegments: 3 });
    geo.center();
    const bolt = new THREE.Mesh(geo, std('#ffd34e', { metalness: 0.3, roughness: 0.3, emissive: '#7a5200', emissiveIntensity: 0.35 }));
    bolt.rotation.set(-0.15, 0.35, -0.12); bolt.scale.setScalar(1.05);
    scene.add(bolt);
    sparkle(scene, 0.85, 0.85, 0.22, '#fff6c8'); sparkle(scene, -0.9, -0.55, 0.16, '#fff6c8');
    return camera(6.4, 0.4);
  },
  'slow-wave'(scene) {
    const mat = (o) => new THREE.MeshStandardMaterial({ color: '#b48cff', emissive: '#4a2a90', emissiveIntensity: 0.5, transparent: true, opacity: o, metalness: 0.2, roughness: 0.35 });
    [0.45, 0.85, 1.25].forEach((r, i) => {
      const t = new THREE.Mesh(new THREE.TorusGeometry(r, 0.1 - i * 0.015, 16, 64), mat(1 - i * 0.25));
      t.rotation.x = Math.PI / 2; scene.add(t);
    });
    const orb = new THREE.Mesh(new THREE.SphereGeometry(0.26, 32, 24), std('#ffffff', { emissive: '#d8c4ff', emissiveIntensity: 0.6 }));
    orb.position.y = 0.12; scene.add(orb);
    return camera(5.2, 3.4);
  },
  invisible(scene) {
    const fig = person(new THREE.MeshStandardMaterial({ color: '#c8b8ff', transparent: true, opacity: 0.42, roughness: 0.3, emissive: '#6a58b0', emissiveIntensity: 0.4 }));
    scene.add(fig);
    // a faint shimmer shell round it (a little bigger, back faces only)
    const shell = person(new THREE.MeshBasicMaterial({ color: '#ffffff', transparent: true, opacity: 0.22, side: THREE.BackSide }));
    shell.scale.setScalar(1.08);
    scene.add(shell);
    sparkle(scene, 0.75, 0.7, 0.2, '#ffffff'); sparkle(scene, -0.8, 0.1, 0.15, '#e8dcff'); sparkle(scene, 0.6, -0.75, 0.12, '#ffffff');
    return camera(6.0, 0.5);
  },
  glitchy(scene) {
    const ghost = (c, x, o) => { const f = person(new THREE.MeshBasicMaterial({ color: c, transparent: true, opacity: o })); f.position.x = x; f.position.z = -0.2; scene.add(f); };
    ghost('#ff50c8', 0.22, 0.75); ghost('#4ef0e0', -0.22, 0.75);
    const fig = person(std('#2a3550', { roughness: 0.5, metalness: 0.1 })); scene.add(fig);
    for (const [y, x, w] of [[0.55, 0.35, 0.9], [-0.1, -0.3, 1.1], [-0.6, 0.25, 0.8]]) {
      const bar = new THREE.Mesh(new THREE.BoxGeometry(w, 0.08, 0.05), new THREE.MeshBasicMaterial({ color: y > 0 ? '#4ef0e0' : '#ff50c8' }));
      bar.position.set(x, y, 0.6); scene.add(bar);
    }
    return camera(6.0, 0.4);
  },
  'body-double'(scene) {
    const back = person(new THREE.MeshStandardMaterial({ color: '#ffb060', transparent: true, opacity: 0.45, roughness: 0.4 }));
    back.position.set(0.45, 0.08, -0.5); scene.add(back);
    const front = person(std('#ffb060', { roughness: 0.4, metalness: 0.15, emissive: '#7a3a00', emissiveIntensity: 0.25 }));
    front.position.set(-0.3, -0.05, 0.2); scene.add(front);
    return camera(6.0, 0.7);
  },
};
window.draw = (name) => {
  const scene = new THREE.Scene();
  lights(scene);
  const cam = BUILD[name](scene);
  renderer.render(scene, cam);
  return true;
};
window.ready = true;
</script></body></html>`;

const browser = await chromium.launch({ args: ['--use-gl=swiftshader', '--enable-webgl', '--ignore-gpu-blocklist'] });
const page = await browser.newPage({ viewport: { width: SIZE, height: SIZE } });
await page.route('http://icons.local/**', (route) => {
  const name = new URL(route.request().url()).pathname;
  if (name === '/index.html') return route.fulfill({ contentType: 'text/html', body: PAGE });
  route.fulfill({ contentType: 'text/javascript', body: fs.readFileSync(path.join(here, '../preview/motion3d/vendor/three.module.min.js')) });
});
await page.goto('http://icons.local/index.html');
await page.waitForFunction(() => window.ready === true);
for (const name of ICONS) {
  await page.evaluate((n) => window.draw(n), name);
  const file = path.join(OUT, `ability-${name}.png`);
  await page.locator('canvas').screenshot({ path: file, omitBackground: true });
  console.log('wrote', path.relative(process.cwd(), file));
}
await browser.close();
