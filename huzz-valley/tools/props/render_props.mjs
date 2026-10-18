// Renders the owner's lobby props on their pads the way the game sets them up (Config/LobbyProps sizes, hover, the
// soft light and glow pool under each; Neon on his glow parts as SetupLobbyProps makes them), for the side by side with
// his reference shots (tools/props/props_vs_ref.py adds the titles, sparkles, bloom and the game's colour grade).
// Scenes: "three" (the three-pad side: Witch's Brew, Sweets & Treats, Free Spin, framed like ref-halloween-shop.png),
// "two" (the two-pad side: SHOP, LIKE THE GAME!, framed like ref-shop-like-reward.png), and one small tile per prop
// as the stand-in (plain parts) the pads show before he imports his meshes.
// Each scene: <name>.png (lit), <name>_glow.png (only glowing parts), <name>.json (each prop's top and box on screen).
// Usage (from huzz-valley/): NODE_PATH=$(npm root -g) node tools/props/render_props.mjs <meshes.json> <outDir>
import { createRequire } from 'module';
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const require = createRequire(import.meta.url);
const { chromium } = require('playwright');
const here = path.dirname(fileURLToPath(import.meta.url));
const [meshFile, outDir] = process.argv.slice(2);
fs.mkdirSync(outDir, { recursive: true });

// Config/LobbyProps (kept in step by hand: Scale, Hover, Glow)
const CFG = {
  Hover: 1.3,
  Props: {
    Shop_Stall: { Scale: 1.65, Glow: '#ffb040' },
    Like_Reward_Gift: { Scale: 2.3, Glow: '#fff096' },
    Pumpkin_Patch_Chest: { Scale: 2.2, Glow: '#ffc440' },
    Witch_Brew_Cauldron: { Scale: 2.5, Glow: '#c86aff' },
    Sweets_Treats_Coffin: { Scale: 2.3, Glow: '#ffa0dc' },
  },
};
const SCENES = [
  { name: 'three', w: 910, h: 746, pads: [['Witch_Brew_Cauldron', -7, -0.35], ['Sweets_Treats_Coffin', 0, 0.3], ['Pumpkin_Patch_Chest', 7, -0.3]],
    eye: [0, 6.2, 23], at: [0, 4.4, 0], fov: 46, mode: 'real' },
  { name: 'two', w: 1268, h: 556, pads: [['Shop_Stall', -4.5, 0.35], ['Like_Reward_Gift', 4.5, -0.3]],
    eye: [1.5, 9, 25], at: [1.5, 4.6, 0], fov: 36, mode: 'real' },
];
for (const key of Object.keys(CFG.Props)) {
  SCENES.push({ name: 'standin_' + key, w: 360, h: 360, pads: [[key, 0, 0.45]], eye: [0, 5.5, 14], at: [0, 3.6, 0], fov: 40, mode: 'standIn' });
}

const PAGE = `<!doctype html><html><body style="margin:0;background:transparent"><script type="module">
import * as THREE from './three.module.min.js';
window.setup = async (data, cfg) => {
  window.data = data; window.cfg = cfg;
  const loader = new THREE.TextureLoader();
  window.tex = await Promise.all(data.textures.map((u) => new Promise((res) => loader.load(u, (t) => {
    t.flipY = false; t.colorSpace = THREE.SRGBColorSpace; t.wrapS = t.wrapT = THREE.RepeatWrapping; res(t); }))));
  window.ready = true;
};
function studTex(base, light) {
  const c = document.createElement('canvas'); c.width = c.height = 64;
  const g = c.getContext('2d');
  g.fillStyle = base; g.fillRect(0, 0, 64, 64);
  g.fillStyle = 'rgba(0,0,0,0.18)'; g.beginPath(); g.arc(34, 34, 17, 0, 7); g.fill();
  g.fillStyle = light; g.beginPath(); g.arc(32, 32, 16, 0, 7); g.fill();
  g.strokeStyle = 'rgba(0,0,0,0.12)'; g.strokeRect(0.5, 0.5, 63, 63);
  const t = new THREE.CanvasTexture(c); t.wrapS = t.wrapT = THREE.RepeatWrapping; t.colorSpace = THREE.SRGBColorSpace; return t;
}
function poolTex(col) {
  const c = document.createElement('canvas'); c.width = c.height = 128;
  const g = c.getContext('2d');
  // the game's glow pool: three see-through circles (100% / 72% / 44% across, 0.18 / 0.3 / 0.42 opaque)
  for (const [r, a] of [[1, 0.18], [0.72, 0.3], [0.44, 0.42]]) {
    g.fillStyle = col; g.globalAlpha = a; g.beginPath(); g.arc(64, 64, 63 * r, 0, 7); g.fill();
  }
  const t = new THREE.CanvasTexture(c); t.colorSpace = THREE.SRGBColorSpace; return t;
}
window.draw = (scene, glowPass) => {
  const { data, cfg } = window;
  const renderer = window.renderer || new THREE.WebGLRenderer({ antialias: true, alpha: true, preserveDrawingBuffer: true });
  window.renderer = renderer;
  renderer.setSize(scene.w, scene.h);
  renderer.shadowMap.enabled = true; renderer.shadowMap.type = THREE.PCFSoftShadowMap;
  renderer.outputColorSpace = THREE.SRGBColorSpace;
  renderer.toneMapping = THREE.ACESFilmicToneMapping; renderer.toneMappingExposure = 1.05;
  if (!renderer.domElement.parentNode) document.body.appendChild(renderer.domElement);
  const s = new THREE.Scene();
  const black = new THREE.MeshBasicMaterial({ color: '#000000' });
  const tile = scene.mode === 'standIn';
  if (glowPass) { s.background = new THREE.Color('#000000'); renderer.toneMapping = THREE.NoToneMapping; }
  else if (!tile) {
    const c = document.createElement('canvas'); c.width = 2; c.height = 256;
    const g = c.getContext('2d'); const gr = g.createLinearGradient(0, 0, 0, 256);
    gr.addColorStop(0, '#3f8fe6'); gr.addColorStop(0.55, '#9cc8f2'); gr.addColorStop(1, '#d9ecfb');
    g.fillStyle = gr; g.fillRect(0, 0, 2, 256);
    const bg = new THREE.CanvasTexture(c); bg.colorSpace = THREE.SRGBColorSpace; s.background = bg;
  } else s.background = new THREE.Color('#2a2238');
  s.add(new THREE.HemisphereLight('#e6f1ff', '#7a5a34', glowPass ? 0 : 1.15));
  const sun = new THREE.DirectionalLight('#fffaf0', glowPass ? 0 : 2.4);
  sun.position.set(-14, 26, 18); sun.castShadow = true;
  sun.shadow.mapSize.set(2048, 2048);
  Object.assign(sun.shadow.camera, { left: -30, right: 30, top: 30, bottom: -30, near: 1, far: 90 });
  sun.shadow.bias = -0.0004;
  s.add(sun);
  // the plaza (his tan studs) and the sea beyond
  if (!tile) {
    const ft = studTex('#c58a42', '#cf9550'); ft.repeat.set(80, 40);
    const floor = new THREE.Mesh(new THREE.PlaneGeometry(80, 40), glowPass ? black : new THREE.MeshStandardMaterial({ map: ft, roughness: 0.9 }));
    floor.rotation.x = -Math.PI / 2; floor.position.set(0, 0, -6); floor.receiveShadow = true; s.add(floor);
    const sea = new THREE.Mesh(new THREE.PlaneGeometry(4000, 4000), glowPass ? black : new THREE.MeshBasicMaterial({ color: '#2f7fd8' }));
    sea.rotation.x = -Math.PI / 2; sea.position.y = -3; s.add(sea);
  } else {
    const floor = new THREE.Mesh(new THREE.CircleGeometry(6, 48), glowPass ? black : new THREE.MeshStandardMaterial({ color: '#5a4c6a', roughness: 1 }));
    floor.rotation.x = -Math.PI / 2; floor.receiveShadow = true; s.add(floor);
  }
  const anchors = [];
  for (const [key, x, yaw] of scene.pads) {
    const p = data.props[key]; const c = cfg.Props[key]; const k = c.Scale;
    // his pad: two grey cylinders (6 and 5.5 across, 0.4 thick each), top 0.8 over the floor
    const pt = studTex('#a3a2a5', '#b4b3b6'); pt.repeat.set(6, 6);
    const padMat = glowPass ? black : new THREE.MeshStandardMaterial({ map: pt, roughness: 0.8 });
    const p1 = new THREE.Mesh(new THREE.CylinderGeometry(3, 3, 0.4, 48), padMat); p1.position.set(x, 0.2, 0);
    const p2 = new THREE.Mesh(new THREE.CylinderGeometry(2.75, 2.75, 0.4, 48), padMat); p2.position.set(x, 0.6, 0);
    for (const m of [p1, p2]) { m.castShadow = true; m.receiveShadow = true; s.add(m); }
    if (!glowPass) {
      const pool = new THREE.Mesh(new THREE.CircleGeometry(3, 48), new THREE.MeshBasicMaterial({ map: poolTex(c.Glow), transparent: true, depthWrite: false }));
      pool.rotation.x = -Math.PI / 2; pool.position.set(x, 0.82, 0); s.add(pool);
      const light = new THREE.PointLight(c.Glow, 5, 12, 1.6); light.position.set(x, 0.8 + 0.9, 0); s.add(light);
    }
    // the prop: hovering, turned a little so its shape reads
    const group = new THREE.Group();
    const cy = 0.8 + cfg.Hover;
    if (scene.mode === 'real') {
      for (const r of p.real) {
        const g = new THREE.BufferGeometry();
        g.setAttribute('position', new THREE.Float32BufferAttribute(r.pos, 3));
        if (r.uv) g.setAttribute('uv', new THREE.Float32BufferAttribute(r.uv, 2));
        g.computeVertexNormals();
        let mat;
        if (glowPass) mat = r.neon ? new THREE.MeshBasicMaterial({ color: r.neon }) : black;
        else if (r.neon) mat = new THREE.MeshBasicMaterial({ color: r.neon });
        else mat = new THREE.MeshStandardMaterial({ color: r.col, map: r.tex >= 0 ? window.tex[r.tex] : null, roughness: 0.75, metalness: 0, side: THREE.DoubleSide });
        const m = new THREE.Mesh(g, mat); m.castShadow = !r.neon; group.add(m);
      }
    } else {
      const box = new THREE.BoxGeometry(1, 1, 1), ball = new THREE.SphereGeometry(0.5, 24, 16), cyl = new THREE.CylinderGeometry(0.5, 0.5, 1, 32).rotateZ(Math.PI / 2);
      for (const q of p.standIn) {
        const geo = q.shape === 'B' ? box : q.shape === 'S' ? ball : cyl;
        const mat = glowPass ? (q.glow ? new THREE.MeshBasicMaterial({ color: q.col }) : black)
          : q.glow ? new THREE.MeshBasicMaterial({ color: q.col }) : new THREE.MeshStandardMaterial({ color: q.col, roughness: 0.55 });
        const m = new THREE.Mesh(geo, mat);
        const R = q.R; // (rows of the 3x3)
        const M = new THREE.Matrix4().set(R[0] * q.s[0], R[1] * q.s[1], R[2] * q.s[2], q.c[0], R[3] * q.s[0], R[4] * q.s[1], R[5] * q.s[2], q.c[1], R[6] * q.s[0], R[7] * q.s[1], R[8] * q.s[2], q.c[2], 0, 0, 0, 1);
        m.matrixAutoUpdate = false; m.matrix.copy(M); m.castShadow = !q.glow; group.add(m);
      }
    }
    group.scale.setScalar(k); group.rotation.y = yaw; group.position.set(x, cy, 0);
    s.add(group);
    const top = cy + p.size[1] * k;
    anchors.push({ key, x, top: [x, top, 0], box: [x, cy, p.size[0] * k, p.size[1] * k, p.size[2] * k] });
  }
  const cam = new THREE.PerspectiveCamera(scene.fov, scene.w / scene.h, 0.1, 3000);
  cam.position.set(...scene.eye); cam.lookAt(new THREE.Vector3(...scene.at)); cam.updateMatrixWorld(true);
  renderer.render(s, cam);
  const proj = (v) => { const q = new THREE.Vector3(...v).project(cam); return [(q.x + 1) / 2 * scene.w, (1 - q.y) / 2 * scene.h]; };
  return anchors.map((a) => {
    const t = proj(a.top), up = proj([a.top[0], a.top[1] + 1, a.top[2]]);
    const [bx, by, sx, sy, sz] = a.box;
    const corners = [];
    for (const dx of [-0.5, 0.5]) for (const dy of [0, 1]) for (const dz of [-0.5, 0.5]) corners.push(proj([bx + dx * sx, by + dy * sy, dz * sz]));
    return { key: a.key, top: t, pxPerStud: Math.abs(t[1] - up[1]), box: corners };
  });
};
</script></body></html>`;

const browser = await chromium.launch({ args: ['--use-gl=angle', '--use-angle=swiftshader', '--enable-unsafe-swiftshader'] });
const page = await browser.newPage({ viewport: { width: 1300, height: 800 } });
page.on('pageerror', (e) => console.error('page error:', e.message));
page.on('console', (m) => { if (m.type() === 'error') console.error('console:', m.text()); });
await page.route('http://props.local/**', (route) => {
  const name = new URL(route.request().url()).pathname;
  if (name === '/index.html') return route.fulfill({ contentType: 'text/html', body: PAGE });
  route.fulfill({ contentType: 'text/javascript', body: fs.readFileSync(path.join(here, '../preview/motion3d/vendor/three.module.min.js')) });
});
await page.goto('http://props.local/index.html');
await page.waitForFunction(() => typeof window.setup === 'function');
const meshes = JSON.parse(fs.readFileSync(meshFile, 'utf8'));
await page.evaluate(([d, c]) => window.setup(d, c), [meshes, CFG]);
await page.waitForFunction(() => window.ready === true);
for (const sc of SCENES) {
  for (const glow of [false, true]) {
    await page.setViewportSize({ width: sc.w, height: sc.h });
    const anchors = await page.evaluate(([scene, g]) => window.draw(scene, g), [sc, glow]);
    await page.locator('canvas').screenshot({ path: path.join(outDir, `${sc.name}${glow ? '_glow' : ''}.png`) });
    if (!glow) fs.writeFileSync(path.join(outDir, `${sc.name}.json`), JSON.stringify(anchors));
  }
}
await browser.close();
console.log(`rendered ${SCENES.length} scenes -> ${outDir}`);
