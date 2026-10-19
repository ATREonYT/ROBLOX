// A model of Roblox's daylight on the owner's lobby, to compare Config/Look settings before Studio (owner Oct 19:
// "you see how the objects dont have light only around them, there is even, nice, cartoony lighting over the map").
// NOT a Studio render: three.js with the parts as boxes (MeshParts are their bounding boxes), Lambert (matte) shading,
//   sun        = DirectionalLight, Lighting.Brightness x K.sun, coloured by ColorShift_Top, from ClockTime/latitude,
//                soft shadows (ShadowSoftness -> blur radius),
//   outdoor    = OutdoorAmbient (flat, every direction) x K.amb,
//   sky fill   = EnvironmentDiffuseScale x a blue-above / grey-below hemisphere (the skybox's light) x K.env,
//   lights     = every PointLight (Brightness x K.point, Range); Technology Future gives them shadows and the
//                inverse-square falloff, ShadowMap / Voxel a soft linear falloff and no shadows,
//   exposure   = 2 ^ ExposureCompensation, a tone curve that keeps darks and mid-tones as they are and rolls off only
//                the highlights (Khronos PBR Neutral: a Roblox part in plain sun shows about its own Color; ACES's toe
//                crushed dark floors and made every shadow look darker); the grade (ColorCorrection) and bloom are added
//                by light_compare.py.
// K is calibrated once (tools/preview/light/calibrate.py) so the Oct 17 look gives the cast-shadow ratio measured
// on the owner's Oct 17 recording.
// Usage (from huzz-valley/): NODE_PATH=$(npm root -g) node tools/preview/light/render_light.mjs <scene.json|calib> <looks.json> <outDir> [view]
//   looks.json: { "<name>": { Technology, Brightness, ClockTime, GeographicLatitude, OutdoorAmbient: [r,g,b],
//                 ColorShift_Top: [r,g,b], EnvironmentDiffuseScale, ShadowSoftness, ExposureCompensation,
//                 LightScale (our own PointLights' brightness x), K: {sun, amb, env, point} }, ... }
import { createRequire } from 'module';
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const require = createRequire(import.meta.url);
const { chromium } = require('playwright');
const here = path.dirname(fileURLToPath(import.meta.url));
const [sceneArg, looksFile, outDir, viewName = 'plaza'] = process.argv.slice(2);
fs.mkdirSync(outDir, { recursive: true });
const looks = JSON.parse(fs.readFileSync(looksFile, 'utf8'));

// the calibration scene: a floor, a 4-stud block, an avatar-sized block (cast shadows and lit / shaded faces)
function calibScene() {
  const parts = [];
  const add = (p, s, c, m = 'Plastic') => parts.push({ p, s, c, m, shape: 'Block', rot: [1, 0, 0, 0, 1, 0, 0, 0, 1], t: 0 });
  add([0, -0.5, 0], [200, 1, 200], [240, 228, 195]); // cream (the Oct 17 path)
  add([62, -0.4, 0], [60, 1, 200], [66, 62, 84]); // dark slate (the reference's floor)
  add([20, 2, 0], [4, 4, 4], [240, 228, 195]);
  add([42, 2, 0], [4, 4, 4], [66, 62, 84]);
  return { centre: [30, 0], parts, lights: [], calib: true };
}
const scene = sceneArg === 'calib' ? calibScene() : JSON.parse(fs.readFileSync(sceneArg, 'utf8'));
const VIEWS = {
  // standing on the plaza behind a player, looking at the props' pads and the podium boards (like the reference)
  plaza: { eye: [-104, 23, 37], at: [-82, 14, 2], fov: 70, w: 1280, h: 720, avatar: [-98, 12.5, 25] },
  calib: { eye: [31, 16, 34], at: [31, 0, -2], fov: 60, w: 960, h: 540 },
};
const view = VIEWS[sceneArg === 'calib' ? 'calib' : viewName];

const PAGE = `<!doctype html><html><body style="margin:0"><script type="module">
import * as THREE from './three.module.min.js';
THREE.ShaderChunk.tonemapping_pars_fragment = THREE.ShaderChunk.tonemapping_pars_fragment.replace(
  'vec3 CustomToneMapping( vec3 color ) { return color; }',
  \`vec3 CustomToneMapping( vec3 color ) {
    const float start = 0.76; const float desat = 0.15;
    color *= toneMappingExposure;
    float x = min( color.r, min( color.g, color.b ) );
    float offset = x < 0.08 ? x - 6.25 * x * x : 0.04;
    color -= offset;
    float peak = max( color.r, max( color.g, color.b ) );
    if ( peak < start ) return color;
    float d = 1.0 - start;
    float newPeak = 1.0 - d * d / ( peak + d - start );
    color *= newPeak / peak;
    float g = 1.0 - 1.0 / ( desat * ( peak - newPeak ) + 1.0 );
    return mix( color, vec3( newPeak ), g );
  }\`);
const lin = (c) => { c /= 255; return c <= 0.04045 ? c / 12.92 : Math.pow((c + 0.055) / 1.055, 2.4); };
window.render = (scene, look, view) => {
  const K = look.K;
  const renderer = new THREE.WebGLRenderer({ antialias: true, preserveDrawingBuffer: true });
  renderer.setSize(view.w, view.h);
  renderer.shadowMap.enabled = true;
  renderer.shadowMap.type = THREE.PCFSoftShadowMap;
  renderer.toneMapping = THREE.CustomToneMapping;
  renderer.toneMappingExposure = Math.pow(2, look.ExposureCompensation || 0);
  renderer.outputColorSpace = THREE.SRGBColorSpace;
  document.body.innerHTML = '';
  document.body.appendChild(renderer.domElement);
  const s3 = new THREE.Scene();
  // sky: Roblox's default daytime sky, blue overhead, pale at the horizon
  const sky = document.createElement('canvas'); sky.width = 4; sky.height = 256;
  const g = sky.getContext('2d'); const gr = g.createLinearGradient(0, 0, 0, 256);
  gr.addColorStop(0, '#3f9cf5'); gr.addColorStop(0.75, '#9fd0fb'); gr.addColorStop(1, '#d8ecff');
  g.fillStyle = gr; g.fillRect(0, 0, 4, 256);
  const skyTex = new THREE.CanvasTexture(sky); skyTex.colorSpace = THREE.SRGBColorSpace;
  s3.background = skyTex;
  s3.fog = new THREE.Fog(0xcfe4ff, 260, 900);
  const box = new THREE.BoxGeometry(1, 1, 1);
  const ball = new THREE.SphereGeometry(0.5, 20, 14);
  const cyl = new THREE.CylinderGeometry(0.5, 0.5, 1, 20); cyl.rotateZ(Math.PI / 2); // Roblox cylinders run along X
  const mats = new Map();
  const mat = (c, m) => {
    const key = c.join(',') + m;
    if (!mats.has(key)) {
      const col = new THREE.Color().setRGB(lin(c[0]), lin(c[1]), lin(c[2]), THREE.LinearSRGBColorSpace);
      mats.set(key, m === 'Neon' ? new THREE.MeshBasicMaterial({ color: col.clone().multiplyScalar(2.2) })
        : new THREE.MeshLambertMaterial({ color: col }));
    }
    return mats.get(key);
  };
  const addPart = (p) => {
    const geo = p.shape === 'Ball' ? ball : p.shape === 'Cylinder' ? cyl : box;
    const mesh = new THREE.Mesh(geo, mat(p.c, p.m));
    const r = p.rot;
    const m4 = new THREE.Matrix4().set(r[0] * p.s[0], r[1] * p.s[1], r[2] * p.s[2], p.p[0],
      r[3] * p.s[0], r[4] * p.s[1], r[5] * p.s[2], p.p[1], r[6] * p.s[0], r[7] * p.s[1], r[8] * p.s[2], p.p[2], 0, 0, 0, 1);
    mesh.matrixAutoUpdate = false; mesh.matrix.copy(m4);
    mesh.castShadow = p.m !== 'Neon'; mesh.receiveShadow = true;
    s3.add(mesh);
  };
  for (const p of scene.parts) addPart(p);
  if (!scene.calib) {
    const sea = new THREE.Mesh(new THREE.PlaneGeometry(4000, 4000), mat([52, 110, 196], 'Plastic'));
    sea.rotation.x = -Math.PI / 2; sea.position.set(scene.centre[0], 1, scene.centre[1]); sea.receiveShadow = true; s3.add(sea);
  }
  if (view.avatar) { // a blocky player (dark clothes, like the reference's): legs, torso, arms, head
    const [ax, ay, az] = view.avatar;
    const P = (o, s, c) => addPart({ p: [ax + o[0], ay + o[1], az + o[2]], s, c, m: 'Plastic', shape: 'Block', rot: [1, 0, 0, 0, 1, 0, 0, 0, 1] });
    P([-0.5, 1, 0], [1, 2, 1], [27, 27, 30]); P([0.5, 1, 0], [1, 2, 1], [27, 27, 30]);
    P([0, 3, 0], [2, 2, 1], [20, 20, 24]); P([-1.5, 3, 0], [1, 2, 1], [20, 20, 24]); P([1.5, 3, 0], [1, 2, 1], [20, 20, 24]);
    P([0, 4.6, 0], [1.2, 1.2, 1.2], [120, 82, 60]);
  }
  // sun: ClockTime and latitude to a direction (equinox; Roblox's sun crosses from east (+X) to west)
  const h = ((look.ClockTime ?? 14) - 12) * 15 * Math.PI / 180, lat = (look.GeographicLatitude ?? 28) * Math.PI / 180;
  const up = Math.cos(lat) * Math.cos(h), east = -Math.sin(h), south = Math.sin(lat) * Math.cos(h);
  const sunDir = new THREE.Vector3(east, Math.max(up, 0.05), south).normalize();
  const st = look.ColorShift_Top || [255, 255, 255];
  const sun = new THREE.DirectionalLight(new THREE.Color().setRGB(lin(st[0]), lin(st[1]), lin(st[2]), THREE.LinearSRGBColorSpace), look.Brightness * K.sun);
  const c = new THREE.Vector3(scene.centre[0], 10, scene.centre[1]);
  sun.position.copy(c.clone().add(sunDir.clone().multiplyScalar(300))); sun.target.position.copy(c);
  sun.castShadow = true;
  sun.shadow.mapSize.set(4096, 4096);
  const sc = sun.shadow.camera; sc.left = -190; sc.right = 190; sc.top = 190; sc.bottom = -190; sc.near = 10; sc.far = 700;
  sun.shadow.bias = -0.0004; sun.shadow.normalBias = 0.05;
  sun.shadow.radius = 1 + 7 * (look.ShadowSoftness ?? 0.2);
  sun.shadow.blurSamples = 16;
  s3.add(sun); s3.add(sun.target);
  const oa = look.OutdoorAmbient;
  s3.add(new THREE.AmbientLight(new THREE.Color().setRGB(lin(oa[0]), lin(oa[1]), lin(oa[2]), THREE.LinearSRGBColorSpace), K.amb));
  const eds = look.EnvironmentDiffuseScale ?? 0;
  if (eds > 0) s3.add(new THREE.HemisphereLight(new THREE.Color().setRGB(0.33, 0.55, 1.0, THREE.LinearSRGBColorSpace),
    new THREE.Color().setRGB(0.22, 0.2, 0.18, THREE.LinearSRGBColorSpace), eds * K.env));
  const future = look.Technology === 'Future';
  let shadowLights = 0;
  for (const L of scene.lights || []) {
    if (L.kind !== 'PointLight' && L.kind !== 'SpotLight') continue;
    let b = L.b * (look.LightScale?.[L.owner] ?? look.LightScale?.all ?? 1);
    const range = L.range * (look.RangeScale?.[L.owner] ?? look.RangeScale?.all ?? 1);
    if (b <= 0 || range <= 0) continue;
    const pl = new THREE.PointLight(new THREE.Color().setRGB(L.c[0], L.c[1], L.c[2], THREE.LinearSRGBColorSpace),
      b * K.point * (future ? 1 : 0.6), range, future ? 2 : 1);
    pl.position.set(L.p[0], L.p[1], L.p[2]);
    if (future && L.shadows && shadowLights < 8) { pl.castShadow = true; pl.shadow.mapSize.set(512, 512); shadowLights++; }
    s3.add(pl);
  }
  const cam = new THREE.PerspectiveCamera(view.fov, view.w / view.h, 0.5, 3000);
  cam.position.set(...view.eye); cam.lookAt(...view.at);
  // calibration: an invisible roof high over each floor casts one big shadow wherever the sun puts it; the page
  // reports where on screen that shadow's middle and a sunlit spot of the same floor are, for calibrate.py
  const probes = {};
  if (scene.calib) {
    const shift = sunDir.clone().multiplyScalar(-25 / sunDir.y); // from the roof (25 up) down to the floor
    cam.updateMatrixWorld();
    for (const [key, x, top] of [['cream', 0, 0], ['slate', 47, 0.1]]) {
      const roof = new THREE.Mesh(box, new THREE.MeshBasicMaterial({ colorWrite: false, depthWrite: false }));
      roof.scale.set(14, 0.5, 14); roof.position.set(x, 25, -6); roof.castShadow = true; s3.add(roof);
      const at = (v) => { const q = v.clone().project(cam); return [Math.round((q.x + 1) / 2 * view.w), Math.round((1 - q.y) / 2 * view.h)]; };
      probes[key + '_shadow'] = at(new THREE.Vector3(x + shift.x, top, -6 + shift.z));
      probes[key + '_sun'] = at(new THREE.Vector3(x + (key === 'cream' ? 15 : 4), top, 9));
    }
    cam.updateMatrixWorld();
  }
  renderer.render(s3, cam);
  return [renderer.domElement.toDataURL('image/png'), probes];
};
window.ready = true;
</script></body></html>`;

const browser = await chromium.launch({ args: ['--use-gl=angle', '--use-angle=swiftshader', '--enable-unsafe-swiftshader'] });
const page = await browser.newPage();
page.on('console', (m) => { if (m.type() === 'error') console.log('page:', m.text()); });
await page.route('http://light.local/**', (route) => {
  const name = new URL(route.request().url()).pathname;
  if (name === '/index.html') return route.fulfill({ contentType: 'text/html', body: PAGE });
  route.fulfill({ contentType: 'text/javascript', body: fs.readFileSync(path.join(here, '../motion3d/vendor/three.module.min.js')) });
});
await page.goto('http://light.local/index.html');
await page.waitForFunction(() => window.ready === true);
for (const [name, look] of Object.entries(looks)) {
  const [url, probes] = await page.evaluate(([s, l, v]) => window.render(s, l, v), [scene, look, view]);
  const file = path.join(outDir, `${sceneArg === 'calib' ? 'calib_' : ''}${name}.png`);
  fs.writeFileSync(file, Buffer.from(url.split(',')[1], 'base64'));
  if (Object.keys(probes).length) fs.writeFileSync(file.replace(/\.png$/, '.json'), JSON.stringify(probes));
  console.log('rendered', file);
}
await browser.close();
