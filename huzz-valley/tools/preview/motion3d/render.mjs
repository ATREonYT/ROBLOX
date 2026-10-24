// Draws a frames JSON (from scene.luau) with three.js in headless Chromium, then encodes an H.264 MP4.
// Usage: node render.mjs frames.json out.mp4   (needs NODE_PATH with playwright, and ffmpeg)
// Frame boxes: {p:[x,y,z] centre, r:[9] row-major rotation, s:[sx,sy,sz], c:"#rrggbb"}. Roblox axes (Y up, -Z forward).
// Optional per frame: sprites [{p, s (width, studs), c, a (opacity), t (assets/fx name, PascalCase or kebab), r (rotation
// deg), add (glow), b (Brightness), g + f (flipbook grid and frame, 0 = top left), flat (a level quad, not camera-facing),
// sq (Squash), v (velocity: VelocityParallel streaks)}], ribbons [{pts [[x,y,z]...], w [widths], a [opacities], c, cs
// (a colour per point), add, t (texture along the strip)}] (camera-facing strips: slashes, trails), lights [{p, c, b
// (Brightness), r (Range)}] (PointLights, up to 4) and caption (text drawn top left).
// Optional per frame too: bloom {i, size, th} (an imitation of BloomEffect: a thresholded blur, screen-blended),
// env {sky (zenith), horizon, fog [near, far], amb (ambient colour), stars (0-1), dim} (sky colour and daylight strength for that frame), fov (degrees, default 70), grades [{b, c, s, tint}] (ColorCorrectionEffects in order: Brightness
// added, Contrast, Saturation, TintColor multiplied, drawn over everything like Roblox's), overlay {bg, lines [{a (deg),
// w, len, c, x, y (offsets)}], fade [[pos, transparency]...]} (a full-screen ScreenGui frame: lines in a 2400 px square centred on the
// screen, each from the square's edge inwards, see Gameplay/SecretReveal's impact frame; bg optional; also rects, texts and dim:
// ScreenGui frames and TextScaled text in 1280 x 720 pixels, and a black fade, drawn in the page). Boxes may add sh ("ball"),
// n (Neon: unlit), a (opacity), add (additive) and e (0-1: a white Highlight fill); sh "cyl" is a Roblox Cylinder
// (round along its X axis), sh "wedge" a Roblox WedgePart (its slope from the bottom front edge up to the top back edge). Ribbons may add u (a texture coordinate per point, wrapping: Beam TextureMode Wrap).
// labels [{p, text, h (studs tall), c, o (outline colour), a (opacity), g ([top, middle, bottom] gradient)}]: BillboardGui text, camera-facing, Gotham-like.
// Sprite/ribbon t may also be a drawn shape: '@disc', '@ring<px>', '@runner<px>' (AuraFX's SurfaceGui circles).
// Optional at the top: sky, ground (colours), grid (false to hide), dim (0-1: daylight strength, for evening scenes),
// stills [frame numbers, 0-based]: with MOTION3D_KEEP=<dir> those frames are also kept there as still_<n>.png.
// meshFile (top level): a JSON of triangle meshes by name (tools/knives/knife_meshes.py: the owner's knives); then
// per frame meshes [{m (name), p, r (9), s (uniform scale, or [x, y, z] in the mesh's own axes), shell ({c, a, only}: drawn as a
// see-through additive glow skin, only over the parts whose node name starts with `only` when given), flat ({c, a}: the mesh in one unlit colour),
// skip (leave out the parts whose node name starts with it)}] draws them (glow parts unlit, like Neon). Top level underlay: true + per frame
// under {bg, rects [{x, y, w, h, c, a, round}]}: ScreenGui frames drawn BEHIND the 3D, which then has no sky, ground or fog.
// A mesh part may add pbr {metal, rough, env (how much it mirrors the sky: a .glb viewer 1, Roblox's
// EnvironmentSpecularScale), emis (0-1: a soft self-glow in its colour, a SurfaceAppearance emissive mask)}: then it is
// drawn shiny (three.js standard material over a plain sky-over-ground reflection) instead of flat.
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
const UNDER = ${data.underlay === true ? 'true' : 'false'};
const renderer = new THREE.WebGLRenderer({ antialias: true, preserveDrawingBuffer: true, alpha: UNDER });
renderer.setSize(${W}, ${H});
renderer.shadowMap.enabled = true;
renderer.shadowMap.type = THREE.PCFSoftShadowMap;
// the picture: the 3D canvas and a bloom canvas over it (screen blend), both under the colour grade
const stage = document.createElement('div');
stage.style.cssText = 'position:fixed;left:0;top:0;width:${W}px;height:${H}px;isolation:isolate';
document.body.appendChild(stage);
// underlay (top level underlay: true): ScreenGui frames BEHIND the 3D (a ViewportFrame over a backdrop): per frame
// under {bg, rects [{x, y, w, h, c, a, round (an ellipse: UICorner 1,0)}]} in 1280 x 720 pixels; then the 3D has no
// sky, ground or fog of its own (a ViewportFrame's empty space is see-through)
const underC = document.createElement('canvas');
underC.width = ${W}; underC.height = ${H};
underC.style.cssText = 'position:absolute;left:0;top:0';
if (UNDER) stage.appendChild(underC);
renderer.domElement.style.cssText = 'position:absolute;left:0;top:0';
stage.appendChild(renderer.domElement);
const bloomC = document.createElement('canvas');
bloomC.width = ${W}; bloomC.height = ${H};
bloomC.style.cssText = 'position:absolute;left:0;top:0;mix-blend-mode:screen;opacity:0';
stage.appendChild(bloomC);
document.body.insertAdjacentHTML('beforeend', '<svg width="0" height="0" style="position:absolute"><filter id="grade" color-interpolation-filters="sRGB"><feColorMatrix id="gradeM" type="matrix" values="1 0 0 0 0 0 1 0 0 0 0 0 1 0 0 0 0 0 1 0"/></filter><filter id="thr" color-interpolation-filters="sRGB"><feComponentTransfer><feFuncR id="thrR" type="linear" slope="1" intercept="0"/><feFuncG id="thrG" type="linear" slope="1" intercept="0"/><feFuncB id="thrB" type="linear" slope="1" intercept="0"/></feComponentTransfer></filter></svg>');
const overlay = document.createElement('canvas');
overlay.width = ${W}; overlay.height = ${H};
overlay.style.cssText = 'position:fixed;left:0;top:0;display:none';
document.body.appendChild(overlay);
// one ColorCorrectionEffect as a 4x5 matrix: tint (multiply), brightness (add), contrast (about 0.5), saturation
const gradeMatrix = (g) => {
  const b = g.b || 0, c = 1 + (g.c || 0), s = 1 + (g.s || 0);
  const L = [0.2126, 0.7152, 0.0722];
  const tv = (() => { const h = (g.tint || '#ffffff').replace('#', ''); return [0, 2, 4].map((i) => parseInt(h.substr(i, 2), 16) / 255); })();
  const M = [];
  for (let r = 0; r < 3; r++) {
    const row = [0, 0, 0, 0, 0];
    for (let k = 0; k < 3; k++) row[k] = c * ((1 - s) * L[k] * tv[k] + (r === k ? s * tv[k] : 0));
    row[4] = c * b + 0.5 * (1 - c);
    M.push(row);
  }
  M.push([0, 0, 0, 1, 0]);
  return M;
};
const mul = (A, B) => { // A after B (4x5 affine)
  const R = [];
  for (let r = 0; r < 4; r++) {
    const row = [0, 0, 0, 0, A[r][4]];
    for (let k = 0; k < 4; k++) { for (let j = 0; j < 5; j++) row[j] += A[r][k] * B[k][j]; }
    R.push(row);
  }
  return R;
};
const scene = new THREE.Scene();
const SKY = ${JSON.stringify(data.sky || '#9fd0f5')}, GROUND = ${JSON.stringify(data.ground || '#e3cf9c')};
scene.background = UNDER ? null : new THREE.Color(SKY);
scene.fog = UNDER ? null : new THREE.Fog(SKY, 80, 220);
const camera = new THREE.PerspectiveCamera(70, ${W} / ${H}, 0.1, 500); // Roblox default FOV
const DIM = ${data.dim ?? 1};
const hemi = new THREE.HemisphereLight(DIM < 1 ? '#9fb0e0' : '#dff0ff', DIM < 1 ? '#40384a' : '#b89c70', 1.6 * DIM);
scene.add(hemi);
const sun = new THREE.DirectionalLight(DIM < 1 ? '#c8d4ff' : '#fff6e8', 1.8 * DIM);
sun.castShadow = true;
sun.shadow.mapSize.set(2048, 2048);
Object.assign(sun.shadow.camera, { left: -25, right: 25, top: 25, bottom: -25, near: 1, far: 120 });
sun.shadow.bias = -0.0005;
scene.add(sun, sun.target);
const ground = new THREE.Mesh(new THREE.PlaneGeometry(1000, 1000), new THREE.MeshLambertMaterial({ color: GROUND }));
ground.rotation.x = -Math.PI / 2;
ground.receiveShadow = true;
scene.add(ground);
ground.visible = !UNDER;
// a sky dome (zenith and horizon colours per frame: Atmosphere) and a star field (Sky.StarCount at night)
const skyGeo = new THREE.SphereGeometry(450, 32, 16);
const skyCol = new Float32Array(skyGeo.attributes.position.count * 3);
skyGeo.setAttribute('color', new THREE.BufferAttribute(skyCol, 3));
const skyDome = new THREE.Mesh(skyGeo, new THREE.MeshBasicMaterial({ vertexColors: true, side: THREE.BackSide, fog: false, depthWrite: false }));
skyDome.visible = false; skyDome.renderOrder = -10;
scene.add(skyDome);
const starPos = [];
for (let i = 0; i < 2500; i++) {
  const u = Math.random() * 2 * Math.PI, v = Math.pow(Math.random(), 0.7) * 0.5 * Math.PI;
  starPos.push(Math.cos(u) * Math.cos(v) * 420, Math.sin(v) * 420 + 5, Math.sin(u) * Math.cos(v) * 420);
}
const starGeo = new THREE.BufferGeometry();
starGeo.setAttribute('position', new THREE.Float32BufferAttribute(starPos, 3));
const stars = new THREE.Points(starGeo, new THREE.PointsMaterial({ color: '#ffffff', size: 1.6, sizeAttenuation: false, transparent: true, opacity: 0, fog: false, depthWrite: false }));
scene.add(stars);
const grid = new THREE.GridHelper(400, 100, '#a88c55', '#a88c55'); // 4-stud cells
grid.material.transparent = true; grid.material.opacity = 0.45; grid.position.y = 0.01;
scene.add(grid);
grid.visible = ${data.grid === false ? 'false' : 'true'};
// particle pictures (assets/fx), loaded once; found by file name ('flame-sheet') or game name ('FlameSheet')
const loader = new THREE.TextureLoader();
const tex = {};
const loads = [];
const addTex = (n, url) => {
  let t;
  loads.push(new Promise((ok) => { t = loader.load(url, ok, undefined, ok); }));
  t.colorSpace = THREE.SRGBColorSpace;
  t.wrapS = THREE.RepeatWrapping; // (Beam Wrap: ribbons with u past 1 repeat the picture)
  tex[n] = tex[n.replace(/-/g, '')] = t;
};
for (const n of ${JSON.stringify(fs.readdirSync(path.join(here, '../../../assets/fx')).filter(f => f.endsWith('.png')).map(f => f.replace('.png', '')))}) addTex(n, './fx/' + n + '.png');
for (const n of ['aura-star', 'aura-star-white']) addTex(n, './icons/' + n + '.png'); // (the lobby's Aura stars)
// drawn shapes for the SurfaceGui circles AuraFX builds (no picture needed in the game): '@disc' (a round Frame),
// '@ring<px>' (a UIStroke ring <px> wide on a 256 px canvas, outer edge at the canvas edge), '@runner<px>' (the same
// ring under a UIGradient whose transparency runs 0 -> 0.55 -> 0.55 -> 0 across it: two bright ends)
const drawn = (name) => {
  const c = document.createElement('canvas'); c.width = c.height = 256;
  const g = c.getContext('2d');
  const m = /^@(disc|ring|runner)(\\d*)$/.exec(name);
  if (!m) return null;
  if (m[1] === 'disc') { g.fillStyle = '#fff'; g.beginPath(); g.arc(128, 128, 127, 0, Math.PI * 2); g.fill(); }
  else {
    const w = Math.max(1, Number(m[2] || 6));
    if (m[1] === 'runner') {
      const lg = g.createLinearGradient(0, 0, 256, 0);
      lg.addColorStop(0, 'rgba(255,255,255,1)'); lg.addColorStop(0.35, 'rgba(255,255,255,0.45)');
      lg.addColorStop(0.65, 'rgba(255,255,255,0.45)'); lg.addColorStop(1, 'rgba(255,255,255,1)');
      g.strokeStyle = lg;
    } else g.strokeStyle = '#fff';
    g.lineWidth = w; g.beginPath(); g.arc(128, 128, 128 - w / 2 - 0.5, 0, Math.PI * 2); g.stroke();
  }
  const t = new THREE.CanvasTexture(c); t.colorSpace = THREE.SRGBColorSpace;
  return t;
};
const pick = (name) => {
  const key = (name || 'glow').toLowerCase();
  if (key[0] === '@' && !tex[key]) { const t = drawn(key); if (t) tex[key] = t; }
  return tex[key] || tex.glow;
};
// one frame of a flipbook sheet (Roblox reads frames left to right, top to bottom)
const frames = {};
const frameOf = (name, g, f) => {
  const base = pick(name);
  if (!g) return base;
  const key = (name || '').toLowerCase() + '#' + g + '#' + f;
  let t = frames[key];
  if (!t) {
    t = frames[key] = base.clone();
    t.repeat.set(1 / g, 1 / g);
    t.offset.set((f % g) / g, 1 - (Math.floor(f / g) + 1) / g);
    t.needsUpdate = true;
  }
  return t;
};
const lights = [];
for (let i = 0; i < 4; i++) { const l = new THREE.PointLight('#ffffff', 0, 10, 1); scene.add(l); lights.push(l); } // (a fixed count: no shader rebuilds)
const caption = document.createElement('div');
caption.style.cssText = 'position:fixed;left:18px;top:14px;font:700 22px/1.2 Helvetica,Arial,sans-serif;color:#fff;text-shadow:0 2px 3px #000,0 0 2px #000';
document.body.appendChild(caption);
const flats = [];
const flatGeo = new THREE.PlaneGeometry(1, 1).rotateX(-Math.PI / 2); // level, facing up
const proj = new THREE.Vector3(), proj2 = new THREE.Vector3();
const sprites = [];
const ribbonMeshes = [];
const unit = new THREE.BoxGeometry(1, 1, 1);
const ball = new THREE.SphereGeometry(0.5, 32, 16);
const cyl = new THREE.CylinderGeometry(0.5, 0.5, 1, 40).rotateZ(Math.PI / 2); // (Roblox's Cylinder: round along X)
const wedge = (() => { // Roblox's WedgePart in a unit box: its side (Y, Z) is the triangle (-y,-z) (-y,+z) (+y,+z), along X
  const P = [[-0.5, -0.5], [-0.5, 0.5], [0.5, 0.5]]; // (y, z)
  const v = (x, i) => [x, P[i][0], P[i][1]];
  const tris = [
    [v(0.5, 0), v(0.5, 1), v(0.5, 2)], [v(-0.5, 0), v(-0.5, 2), v(-0.5, 1)], // the two triangle sides
    [v(-0.5, 0), v(0.5, 1), v(0.5, 0)], [v(-0.5, 0), v(-0.5, 1), v(0.5, 1)], // the bottom
    [v(-0.5, 1), v(0.5, 2), v(0.5, 1)], [v(-0.5, 1), v(-0.5, 2), v(0.5, 2)], // the back
    [v(-0.5, 2), v(0.5, 0), v(0.5, 2)], [v(-0.5, 2), v(-0.5, 0), v(0.5, 0)], // the slope
  ];
  for (const t of tris) { // each face wound outwards (away from the prism's middle)
    const [a, b, c] = t.map((p) => new THREE.Vector3(...p));
    const n = b.clone().sub(a).cross(c.clone().sub(a));
    if (n.dot(a.clone().sub(new THREE.Vector3(0, -1 / 6, 1 / 6))) < 0) [t[1], t[2]] = [t[2], t[1]];
  }
  const g = new THREE.BufferGeometry();
  g.setAttribute('position', new THREE.Float32BufferAttribute(tris.flat(2), 3));
  g.computeVertexNormals();
  return g;
})();
const labelTex = {}, labelSprites = [];
const textTexture = (q) => { // one canvas per text + colours, cached
  const key = q.text + '|' + q.c + '|' + (q.o || '') + '|' + (q.g || []).join(',');
  let t = labelTex[key];
  if (!t) {
    const cv = document.createElement('canvas'), px = 96;
    const ctx = cv.getContext('2d');
    ctx.font = '900 ' + px + 'px Montserrat, Arial Black, Helvetica, sans-serif';
    const w = Math.ceil(ctx.measureText(q.text).width) + px * 0.5;
    cv.width = w; cv.height = Math.ceil(px * 1.4);
    ctx.font = '900 ' + px + 'px Montserrat, Arial Black, Helvetica, sans-serif';
    ctx.textAlign = 'center'; ctx.textBaseline = 'middle'; ctx.lineJoin = 'round';
    if (q.o) { ctx.strokeStyle = q.o; ctx.lineWidth = px * 0.16; ctx.strokeText(q.text, w / 2, cv.height / 2); }
    if (q.g) { // a top-to-bottom gradient (a UIGradient with Rotation 90): [top, middle, bottom]
      const gr = ctx.createLinearGradient(0, cv.height / 2 - px * 0.5, 0, cv.height / 2 + px * 0.5);
      q.g.forEach((c, i) => gr.addColorStop(i / (q.g.length - 1), c));
      ctx.fillStyle = gr;
    } else ctx.fillStyle = q.c;
    ctx.fillText(q.text, w / 2, cv.height / 2);
    t = labelTex[key] = new THREE.CanvasTexture(cv);
    t.colorSpace = THREE.SRGBColorSpace;
    t.userData = { aspect: w / cv.height };
  }
  return t;
};
const pool = [];
const m = new THREE.Matrix4(), sc = new THREE.Matrix4();
const meshLib = {}, meshPool = [];
let envTex = null;
const envMap = () => { // a plain sky over a grey-brown ground, as a reflection (Roblox metal mirrors the sky)
  if (envTex) return envTex;
  const es = new THREE.Scene();
  const geo = new THREE.SphereGeometry(50, 32, 16);
  const pos = geo.attributes.position, cols = [];
  const top = new THREE.Color('#9ec4ff'), mid = new THREE.Color('#f4f6ff'), low = new THREE.Color('#6a6058');
  for (let i = 0; i < pos.count; i++) {
    const y = pos.getY(i) / 50;
    const c = y > 0 ? mid.clone().lerp(top, Math.min(1, y * 1.4)) : mid.clone().lerp(low, Math.min(1, -y * 4));
    cols.push(c.r, c.g, c.b);
  }
  geo.setAttribute('color', new THREE.Float32BufferAttribute(cols, 3));
  es.add(new THREE.Mesh(geo, new THREE.MeshBasicMaterial({ vertexColors: true, side: THREE.BackSide })));
  envTex = new THREE.PMREMGenerator(renderer).fromScene(es, 0.02).texture;
  return envTex;
};
const partMaterial = (q) => {
  if (q.glow) return new THREE.MeshBasicMaterial({ color: q.col });
  if (!q.pbr) return new THREE.MeshLambertMaterial({ color: q.col, flatShading: true });
  const b = q.pbr;
  return new THREE.MeshStandardMaterial({ color: q.col, metalness: b.metal, roughness: b.rough, flatShading: true,
    envMap: envMap(), envMapIntensity: b.env ?? 1, emissive: q.col, emissiveIntensity: b.emis || 0 });
};
window.addMeshes = (lib) => {
  for (const k in lib) {
    meshLib[k] = lib[k].map((q) => {
      const g = new THREE.BufferGeometry();
      g.setAttribute('position', new THREE.Float32BufferAttribute(q.pos, 3));
      g.computeVertexNormals();
      return { g, node: q.node || '', mat: partMaterial(q) };
    });
  }
};
const drawMeshes = (list) => {
  list.forEach((q, i) => {
    let e = meshPool[i];
    const key = q.m + (q.shell ? '|' + q.shell.c + '|' + q.shell.a + '|' + (q.shell.only || '') : '') + (q.flat ? '|flat' : '') + (q.skip ? '|skip:' + q.skip : '');
    if (!e || e.key !== key) {
      if (e) scene.remove(e.group);
      const grp = new THREE.Group();
      grp.matrixAutoUpdate = false;
      // shell {c, a}: the same mesh as a see-through glowing skin (a Neon glow shell round the blade)
      const shellMat = q.shell ? new THREE.MeshBasicMaterial({ color: q.shell.c, transparent: true, opacity: q.shell.a, blending: THREE.AdditiveBlending, depthWrite: false }) : null;
      // flat {c, a}: the mesh in one unlit colour (a Neon copy: the crate opening's light rim behind the knife)
      const flatMat = q.flat ? new THREE.MeshBasicMaterial({ color: q.flat.c, transparent: true, opacity: q.flat.a }) : null;
      for (const part of meshLib[q.m] || []) {
        if (shellMat && q.shell.only && !part.node.startsWith(q.shell.only)) continue;
        if (q.skip && part.node.startsWith(q.skip)) continue; // skip: parts whose node name starts with it are left out
        const mesh = new THREE.Mesh(part.g, shellMat || flatMat || part.mat); mesh.castShadow = !shellMat && !flatMat; grp.add(mesh);
      }
      scene.add(grp);
      e = meshPool[i] = { key, group: grp, flatMat };
    }
    if (e.flatMat) { e.flatMat.color.set(q.flat.c); e.flatMat.opacity = q.flat.a; }
    const r = q.r, p = q.p;
    m.set(r[0], r[1], r[2], p[0], r[3], r[4], r[5], p[1], r[6], r[7], r[8], p[2], 0, 0, 0, 1);
    const ss = Array.isArray(q.s) ? q.s : [q.s, q.s, q.s];
    e.group.matrix.multiplyMatrices(m, sc.makeScale(ss[0], ss[1], ss[2]));
    e.group.visible = true;
  });
  for (let i = list.length; i < meshPool.length; i++) if (meshPool[i]) meshPool[i].group.visible = false;
};
window.draw = (f) => {
  drawMeshes(Array.isArray(f.meshes) ? f.meshes : []);
  if (UNDER) { // ScreenGui frames behind the 3D (see underC)
    const ctx = underC.getContext('2d'), u = f.under || {}, k = ${W} / 1280;
    ctx.setTransform(1, 0, 0, 1, 0, 0);
    ctx.clearRect(0, 0, ${W}, ${H});
    const col = (hexc, a) => { const c = new THREE.Color(hexc); return 'rgba(' + [c.r, c.g, c.b].map((x) => Math.round(x * 255)).join(',') + ',' + a + ')'; };
    if (u.bg) { ctx.fillStyle = u.bg; ctx.fillRect(0, 0, ${W}, ${H}); }
    for (const r of (Array.isArray(u.rects) ? u.rects : [])) {
      ctx.fillStyle = col(r.c, r.a);
      if (r.round) { ctx.beginPath(); ctx.ellipse((r.x + r.w / 2) * k, (r.y + r.h / 2) * k, r.w / 2 * k, r.h / 2 * k, 0, 0, 2 * Math.PI); ctx.fill(); }
      else ctx.fillRect(r.x * k, r.y * k, r.w * k, r.h * k);
    }
  }
  f.boxes.forEach((b, i) => {
    let mesh = pool[i];
    if (!mesh) {
      mesh = pool[i] = new THREE.Mesh(unit, new THREE.MeshLambertMaterial());
      mesh.userData.lit = mesh.material;
      mesh.userData.neon = new THREE.MeshBasicMaterial({ transparent: true, depthWrite: false });
      mesh.castShadow = mesh.receiveShadow = true;
      mesh.matrixAutoUpdate = false;
      scene.add(mesh);
    }
    mesh.geometry = b.sh === 'ball' ? ball : b.sh === 'cyl' ? cyl : b.sh === 'wedge' ? wedge : unit;
    const lit = !b.n && !b.add && (b.a ?? 1) >= 1;
    mesh.material = lit ? mesh.userData.lit : mesh.userData.neon;
    mesh.castShadow = lit;
    if (!lit) {
      const nm = mesh.userData.neon, blend = b.add ? THREE.AdditiveBlending : THREE.NormalBlending;
      if (nm.blending !== blend) { nm.blending = blend; nm.needsUpdate = true; }
      nm.opacity = b.a ?? 1;
    } else {
      mesh.material.emissive.set('#ffffff').multiplyScalar(b.e || 0);
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
    const want = frameOf(q.t, q.g, q.f || 0);
    if (mat.map !== want) { mat.map = want; mat.needsUpdate = true; }
    const blend = q.add ? THREE.AdditiveBlending : THREE.NormalBlending;
    if (mat.blending !== blend) { mat.blending = blend; mat.needsUpdate = true; }
    mat.color.set(q.c).multiplyScalar(q.b || 1); mat.opacity = q.a;
    let rot = (q.r || 0) * Math.PI / 180;
    if (q.v) { // VelocityParallel: the picture's top points along its flight on screen
      proj.set(q.p[0], q.p[1], q.p[2]).project(camera);
      proj2.set(q.p[0] + q.v[0], q.p[1] + q.v[1], q.p[2] + q.v[2]).project(camera);
      rot = Math.atan2((proj2.y - proj.y) * ${H}, (proj2.x - proj.x) * ${W}) - Math.PI / 2;
    }
    mat.rotation = rot;
    const k = q.sq ? Math.pow(2, q.sq) : 1; // Squash > 0: taller and narrower
    s.position.set(q.p[0], q.p[1], q.p[2]); s.scale.set(q.s / k, q.s * k, 1); s.visible = !q.flat;
  });
  for (let i = sp.length; i < sprites.length; i++) sprites[i].visible = false;
  // level quads (orient Flat: sigils, rings, halos), turning about the vertical with their rotation
  let nf = 0;
  sp.forEach((q) => {
    if (!q.flat) return;
    let mesh = flats[nf];
    if (!mesh) {
      mesh = flats[nf] = new THREE.Mesh(flatGeo, new THREE.MeshBasicMaterial({ transparent: true, depthWrite: false, side: THREE.DoubleSide }));
      scene.add(mesh);
    }
    nf++;
    const mat = mesh.material;
    const want = frameOf(q.t, q.g, q.f || 0);
    if (mat.map !== want) { mat.map = want; mat.needsUpdate = true; }
    const blend = q.add ? THREE.AdditiveBlending : THREE.NormalBlending;
    if (mat.blending !== blend) { mat.blending = blend; mat.needsUpdate = true; }
    mat.color.set(q.c).multiplyScalar(q.b || 1); mat.opacity = q.a;
    mesh.position.set(q.p[0], q.p[1], q.p[2]); mesh.rotation.set(0, -(q.r || 0) * Math.PI / 180, 0);
    mesh.scale.set(q.s, 1, q.s); mesh.visible = true;
  });
  for (let i = nf; i < flats.length; i++) flats[i].visible = false;
  const ls = asList(f.lights);
  lights.forEach((l, i) => {
    const q = ls[i];
    if (!q) { l.intensity = 0; return; }
    l.position.set(q.p[0], q.p[1], q.p[2]); l.color.set(q.c); l.intensity = q.b * 30; l.distance = q.r; l.decay = 1;
  });
  caption.textContent = f.caption || '';
  const lb = asList(f.labels);
  lb.forEach((q, i) => {
    let s = labelSprites[i];
    if (!s) { s = labelSprites[i] = new THREE.Sprite(new THREE.SpriteMaterial({ transparent: true, depthWrite: false, fog: false })); s.renderOrder = 5; scene.add(s); }
    const t = textTexture(q);
    if (s.material.map !== t) { s.material.map = t; s.material.needsUpdate = true; }
    s.material.opacity = q.a ?? 1;
    s.position.set(q.p[0], q.p[1], q.p[2]);
    s.scale.set(q.h * 1.4 * t.userData.aspect, q.h * 1.4, 1);
    s.visible = true;
  });
  for (let i = lb.length; i < labelSprites.length; i++) labelSprites[i].visible = false;
  const rb = asList(f.ribbons);
  rb.forEach((q, i) => {
    let mesh = ribbonMeshes[i];
    if (!mesh) {
      mesh = ribbonMeshes[i] = new THREE.Mesh(new THREE.BufferGeometry(), new THREE.MeshBasicMaterial({ vertexColors: true, transparent: true, depthWrite: false, side: THREE.DoubleSide }));
      mesh.frustumCulled = false; // (its bounding sphere is worked out once: a reused strip far from its first place got culled)
      scene.add(mesh);
    }
    const n = q.pts.length, pos = new Float32Array(n * 2 * 3), col = new Float32Array(n * 2 * 4), uv = new Float32Array(n * 2 * 2), idx = [];
    const c = new THREE.Color(q.c), cam = new THREE.Vector3(...f.camera.pos);
    for (let k = 0; k < n; k++) {
      const p = new THREE.Vector3(...q.pts[k]);
      const a = new THREE.Vector3(...q.pts[Math.max(0, k - 1)]), b = new THREE.Vector3(...q.pts[Math.min(n - 1, k + 1)]);
      const dir = b.sub(a).normalize(), view = cam.clone().sub(p).normalize();
      const side = new THREE.Vector3().crossVectors(dir, view).normalize().multiplyScalar(q.w[k] / 2);
      if (q.cs) c.set(q.cs[k]);
      [p.clone().add(side), p.clone().sub(side)].forEach((v, j) => {
        pos.set([v.x, v.y, v.z], (k * 2 + j) * 3);
        col.set([c.r, c.g, c.b, q.a[k]], (k * 2 + j) * 4);
        uv.set([q.u ? q.u[k] : k / Math.max(1, n - 1), 1 - j], (k * 2 + j) * 2); // (Trail Stretch: the picture runs newest to oldest)
      });
      if (k < n - 1) idx.push(k * 2, k * 2 + 1, k * 2 + 2, k * 2 + 1, k * 2 + 3, k * 2 + 2);
    }
    mesh.geometry.setAttribute('position', new THREE.BufferAttribute(pos, 3));
    mesh.geometry.setAttribute('color', new THREE.BufferAttribute(col, 4));
    mesh.geometry.setAttribute('uv', new THREE.BufferAttribute(uv, 2));
    mesh.geometry.setIndex(idx);
    mesh.material.map = q.t ? pick(q.t) : null;
    mesh.material.blending = q.add ? THREE.AdditiveBlending : THREE.NormalBlending;
    mesh.material.needsUpdate = true;
    mesh.visible = true;
  });
  for (let i = rb.length; i < ribbonMeshes.length; i++) ribbonMeshes[i].visible = false;
  const [cx, cy, cz] = f.camera.pos, [lx, ly, lz] = f.camera.look;
  if (f.env) { // a per-frame sky colour and daylight (Lighting.ClockTime changing)
    const e = f.env;
    if (!UNDER) { scene.background.set(e.sky); scene.fog.color.set(e.horizon || e.sky); }
    if (e.fog && !UNDER) { scene.fog.near = e.fog[0]; scene.fog.far = e.fog[1]; }
    hemi.intensity = 1.6 * e.dim; sun.intensity = 1.8 * e.dim;
    if (e.amb) { hemi.color.set(e.amb); hemi.groundColor.set(e.amb).multiplyScalar(0.5); }
    if (e.horizon) { // zenith colour at the top of the dome, the horizon colour round its middle
      skyDome.visible = true;
      const zc = new THREE.Color(e.sky), hc = new THREE.Color(e.horizon), c = new THREE.Color();
      const pos = skyGeo.attributes.position;
      for (let i = 0; i < pos.count; i++) {
        const y = Math.max(0, pos.getY(i) / 450);
        c.copy(hc).lerp(zc, Math.min(1, Math.pow(y, 0.6) * 1.15));
        skyCol[i * 3] = c.r; skyCol[i * 3 + 1] = c.g; skyCol[i * 3 + 2] = c.b;
      }
      skyGeo.attributes.color.needsUpdate = true;
    }
    stars.material.opacity = e.stars || 0;
  }
  skyDome.position.set(f.camera.pos[0], 0, f.camera.pos[2]);
  stars.position.set(f.camera.pos[0], 0, f.camera.pos[2]);
  camera.fov = f.fov || 70;
  camera.updateProjectionMatrix();
  // the colour grades, over everything (as Roblox's post effects)
  let G = [[1, 0, 0, 0, 0], [0, 1, 0, 0, 0], [0, 0, 1, 0, 0], [0, 0, 0, 1, 0]];
  for (const g of asList(f.grades)) G = mul(gradeMatrix(g), G);
  document.getElementById('gradeM').setAttribute('values', G.map((r) => r.join(' ')).join(' '));
  stage.style.filter = 'url(#grade)';
  // a full-screen ScreenGui frame (the impact frame)
  const o = f.overlay;
  overlay.style.display = o ? 'block' : 'none';
  if (o) {
    const ctx = overlay.getContext('2d');
    ctx.setTransform(1, 0, 0, 1, 0, 0);
    ctx.clearRect(0, 0, ${W}, ${H});
    if (o.bg) { ctx.fillStyle = o.bg; ctx.fillRect(0, 0, ${W}, ${H}); }
    for (const l of asList(o.lines)) {
      const a = l.a * Math.PI / 180, r = 1200 - l.len / 2;
      const x = l.x ?? 1200 + Math.round(Math.sin(a) * r), y = l.y ?? 1200 - Math.round(Math.cos(a) * r); // (offsets in the square)
      ctx.setTransform(1, 0, 0, 1, ${W} / 2 - 1200 + x, ${H} / 2 - 1200 + y);
      ctx.rotate(a);
      const gr = ctx.createLinearGradient(0, -l.len / 2, 0, l.len / 2); // (UIGradient Rotation 90: top to bottom)
      const col = new THREE.Color(l.c);
      for (const [pos, tr] of asList(o.fade)) gr.addColorStop(pos, 'rgba(' + [col.r, col.g, col.b].map((x) => Math.round(x * 255)).join(',') + ',' + (1 - tr) + ')');
      ctx.fillStyle = gr;
      ctx.fillRect(-l.w / 2, -l.len / 2, l.w, l.len);
    }
    // ScreenGui frames and text (1280 x 720 pixels, scaled to the page): rects {x, y, w, h, c, a, fade (a
    // left-to-right UIGradient's [[pos, transparency]...])}, texts {text, x, y, w, h, c, a, o (UIStroke colour), ow
    // (its thickness), max (UITextSizeConstraint), italic, weight} drawn like TextScaled (as big as fits the box)
    const k = ${W} / 1280;
    const rgba = (hexc, a) => { const c = new THREE.Color(hexc); return 'rgba(' + [c.r, c.g, c.b].map((x) => Math.round(x * 255)).join(',') + ',' + a + ')'; };
    for (const r of asList(o.rects)) {
      ctx.setTransform(1, 0, 0, 1, 0, 0);
      if (r.fade) { // (vfade: true runs it top to bottom instead, a UIGradient at Rotation 90)
        const gr = r.vfade ? ctx.createLinearGradient(0, r.y * k, 0, (r.y + r.h) * k) : ctx.createLinearGradient(r.x * k, 0, (r.x + r.w) * k, 0);
        for (const [pos, tr] of asList(r.fade)) gr.addColorStop(pos, rgba(r.c, r.a * (1 - tr)));
        ctx.fillStyle = gr;
      } else ctx.fillStyle = rgba(r.c, r.a);
      if (r.rr) { ctx.beginPath(); ctx.roundRect(r.x * k, r.y * k, r.w * k, r.h * k, r.rr * k); ctx.fill(); if (r.s) { ctx.strokeStyle = rgba(r.s, r.a); ctx.lineWidth = (r.sw || 2) * k; ctx.stroke(); } } // (rr: UICorner radius; s, sw: a UIStroke)
      else ctx.fillRect(r.x * k, r.y * k, r.w * k, r.h * k);
    }
    for (const q of asList(o.texts)) {
      ctx.setTransform(1, 0, 0, 1, 0, 0);
      const style = (q.italic ? 'italic ' : '') + (q.weight >= 800 ? 900 : 700) + ' ';
      let px = Math.min(q.h * 0.82, q.max || 999);
      ctx.font = style + px + 'px Montserrat, Arial Black, Helvetica, sans-serif';
      const wid = ctx.measureText(q.text).width;
      if (wid > q.w * 0.98) { px *= q.w * 0.98 / wid; ctx.font = style + px + 'px Montserrat, Arial Black, Helvetica, sans-serif'; }
      ctx.textAlign = 'center'; ctx.textBaseline = 'middle'; ctx.lineJoin = 'round';
      const x = (q.x + q.w / 2) * k, y = (q.y + q.h / 2) * k;
      ctx.font = style + (px * k) + 'px Montserrat, Arial Black, Helvetica, sans-serif';
      if (q.o) { ctx.strokeStyle = rgba(q.o, q.a); ctx.lineWidth = (q.ow || 2) * 2 * k; ctx.strokeText(q.text, x, y); }
      ctx.fillStyle = rgba(q.c, q.a); ctx.fillText(q.text, x, y);
    }
    if (o.dim) { ctx.setTransform(1, 0, 0, 1, 0, 0); ctx.fillStyle = 'rgba(0,0,0,' + o.dim + ')'; ctx.fillRect(0, 0, ${W}, ${H}); }
  }
  camera.position.set(cx, cy, cz);
  camera.lookAt(lx, ly, lz);
  sun.target.position.set(lx, 0, lz); // shadow box follows what the camera looks at
  sun.position.set(lx + 30, 60, lz + 20);
  renderer.render(scene, camera);
  // bloom (an imitation of Roblox's BloomEffect): what's brighter than the threshold, blurred, screen-blended on top
  const bl = f.bloom;
  if (bl && bl.i > 0) {
    const t0 = Math.min(0.92, Math.max(0.3, 0.55 + (bl.th - 0.9) * 0.5));
    for (const id of ['thrR', 'thrG', 'thrB']) {
      const el = document.getElementById(id);
      el.setAttribute('slope', String(1 / (1 - t0))); el.setAttribute('intercept', String(-t0 / (1 - t0)));
    }
    const ctx = bloomC.getContext('2d');
    ctx.clearRect(0, 0, ${W}, ${H});
    ctx.filter = 'url(#thr) blur(' + Math.round(bl.size * 0.55) + 'px)';
    ctx.drawImage(renderer.domElement, 0, 0);
    ctx.drawImage(renderer.domElement, 0, 0); // (twice: a fuller glow)
    ctx.filter = 'none';
    bloomC.style.opacity = String(Math.min(1, bl.i * 0.75));
  } else {
    bloomC.style.opacity = '0';
  }
};
Promise.all(loads).then(() => { window.ready = true; });
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
if (data.meshFile) { // only the meshes the frames use
  const all = JSON.parse(fs.readFileSync(data.meshFile, 'utf8')), used = {};
  for (const f of data.frames) for (const q of (Array.isArray(f.meshes) ? f.meshes : [])) used[q.m] = all[q.m];
  await page.evaluate((lib) => window.addMeshes(lib), used);
}
const keep = process.env.MOTION3D_KEEP;
const stills = new Set(Array.isArray(data.stills) ? data.stills : []);
if (keep) fs.mkdirSync(keep, { recursive: true });
for (let i = 0; i < data.frames.length; i++) {
  await page.evaluate((f) => window.draw(f), data.frames[i]);
  const shot = path.join(tmp, `f_${String(i + 1).padStart(4, '0')}.png`);
  await page.screenshot({ path: shot });
  if (keep && stills.has(i)) fs.copyFileSync(shot, path.join(keep, `still_${i}.png`));
}
await browser.close();
execFileSync('ffmpeg', ['-loglevel', 'error', '-y', '-framerate', String(fps), '-i', path.join(tmp, 'f_%04d.png'),
  '-c:v', 'libx264', '-pix_fmt', 'yuv420p', outFile]);
fs.rmSync(tmp, { recursive: true, force: true });
console.log(`rendered ${data.frames.length} frames in ${((Date.now() - t0) / 1000).toFixed(1)}s -> ${outFile}`);
