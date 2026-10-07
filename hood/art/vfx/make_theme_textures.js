// Hood station-theme textures: rain streaks, embers, bubbles, snowflakes, comets, fire puffs, straight wisps and
// the embossed X stamp for the themed punching-bag stations (HoodVFX.theme, d2_stations). Pure Node, same toolkit
// as make_aura_textures.js.
// Run:  node make_theme_textures.js [outDir]     (default: next to this file)
// White/grey on transparent (tinted in game by ParticleEmitter.Color); alpha fades to 0 at every border.
//   rain     256  single               a thin (~6 px) vertical line, bright in the middle (VelocityParallel)
//   ember    128  single               hot pin-point with a soft halo
//   bubble   256  single               soap/ooze bubble: thin rim, faint fill, a highlight and a crescent
//   snow     256  single               six-armed snowflake with side branches and a faint halo
//   comet    256  single (Beam)        a bright head at U ~0.14 with a tail fading toward U = 1 (sweeping arcs)
//   stamp    128  tiling Texture       the reference's embossed X: both diagonals as a 20 px groove drawn in
//                                      WHITE; Texture.Color3 tints it per theme (gold stays lemon, not olive)
//   firepuff 1024 4x4 Loop             a lumpy, round cartoon fire puff with a hot core (no pointed tip)
//   streakup 256  single               a straight, thin vertical wisp, fading in and out along its length
const zlib = require('zlib');
const fs = require('fs');
const path = require('path');

const OUT = process.argv[2] || __dirname;

// ---------------------------------------------------------------- PNG writer (RGBA8)
const CRC = new Int32Array(256).map((_, n) => { let c = n; for (let k = 0; k < 8; k++) c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1; return c; });
function crc32(buf) { let c = -1; for (const b of buf) c = CRC[(c ^ b) & 255] ^ (c >>> 8); return (c ^ -1) >>> 0; }
function chunk(type, data) {
  const len = Buffer.alloc(4); len.writeUInt32BE(data.length);
  const td = Buffer.concat([Buffer.from(type, 'ascii'), data]);
  const crc = Buffer.alloc(4); crc.writeUInt32BE(crc32(td));
  return Buffer.concat([len, td, crc]);
}
function writePng(file, w, h, rgba) {
  const raw = Buffer.alloc((w * 4 + 1) * h);
  for (let y = 0; y < h; y++) { raw[y * (w * 4 + 1)] = 0; rgba.copy(raw, y * (w * 4 + 1) + 1, y * w * 4, (y + 1) * w * 4); }
  const ihdr = Buffer.alloc(13); ihdr.writeUInt32BE(w, 0); ihdr.writeUInt32BE(h, 4); ihdr[8] = 8; ihdr[9] = 6;
  fs.writeFileSync(file, Buffer.concat([Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]), chunk('IHDR', ihdr), chunk('IDAT', zlib.deflateSync(raw, { level: 9 })), chunk('IEND', Buffer.alloc(0))]));
}

// ---------------------------------------------------------------- maths
const clamp = (x, a = 0, b = 1) => Math.max(a, Math.min(b, x));
const lerp = (a, b, t) => a + (b - a) * t;
const smooth = (a, b, x) => { const t = clamp((x - a) / (b - a)); return t * t * (3 - 2 * t); };
function rng(seed) { let s = seed >>> 0; return () => { s = (s + 0x6d2b79f5) >>> 0; let t = s; t = Math.imul(t ^ (t >>> 15), t | 1); t ^= t + Math.imul(t ^ (t >>> 7), t | 61); return ((t ^ (t >>> 14)) >>> 0) / 4294967296; }; }
// 2D gradient noise in [-1, 1].
function perlin(seed) {
  const r = rng(seed), p = new Uint8Array(512), g = [];
  const perm = [...Array(256).keys()];
  for (let i = 255; i > 0; i--) { const j = Math.floor(r() * (i + 1)); [perm[i], perm[j]] = [perm[j], perm[i]]; }
  for (let i = 0; i < 512; i++) p[i] = perm[i & 255];
  for (let i = 0; i < 256; i++) { const a = r() * Math.PI * 2; g.push([Math.cos(a), Math.sin(a)]); }
  const fade = t => t * t * t * (t * (t * 6 - 15) + 10);
  return (x, y) => {
    const xi = Math.floor(x), yi = Math.floor(y), xf = x - xi, yf = y - yi;
    const X = xi & 255, Y = yi & 255;
    const dot = (h, dx, dy) => { const v = g[h]; return v[0] * dx + v[1] * dy; };
    const n00 = dot(p[p[X] + Y], xf, yf), n10 = dot(p[p[X + 1] + Y], xf - 1, yf);
    const n01 = dot(p[p[X] + Y + 1], xf, yf - 1), n11 = dot(p[p[X + 1] + Y + 1], xf - 1, yf - 1);
    const u = fade(xf), v = fade(yf);
    return lerp(lerp(n00, n10, u), lerp(n01, n11, u), v) * 1.41;
  };
}
// Fractal noise remapped to roughly [0, 1].
function fbm(n, x, y, oct = 5) { let s = 0, a = 0.5, f = 1, t = 0; for (let i = 0; i < oct; i++) { s += a * n(x * f, y * f); t += a; a *= 0.5; f *= 2.03; } return clamp(0.5 + 0.5 * s / t * 1.6); }

// ---------------------------------------------------------------- float images
// a = alpha (shape), l = luminance (shading); both 0..1.
function img(w, h = w) { return { w, h, a: new Float32Array(w * h), l: new Float32Array(w * h).fill(1) }; }
function boxBlur(src, w, h, r) {
  if (r < 1) return src;
  const tmp = new Float32Array(w * h), out = new Float32Array(w * h), k = 2 * r + 1;
  for (let y = 0; y < h; y++) { let s = 0; for (let x = -r; x <= r; x++) s += src[y * w + clamp(x, 0, w - 1)]; for (let x = 0; x < w; x++) { tmp[y * w + x] = s / k; s += src[y * w + Math.min(w - 1, x + r + 1)] - src[y * w + Math.max(0, x - r)]; } }
  for (let x = 0; x < w; x++) { let s = 0; for (let y = -r; y <= r; y++) s += tmp[clamp(y, 0, h - 1) * w + x]; for (let y = 0; y < h; y++) { out[y * w + x] = s / k; s += tmp[Math.min(h - 1, y + r + 1) * w + x] - tmp[Math.max(0, y - r) * w + x]; } }
  return out;
}
// Three box passes approximate a gaussian of sigma ~ r.
function blur(arr, w, h, r) { let a = arr; const b = Math.max(1, Math.round(r * 0.8)); for (let i = 0; i < 3; i++) a = boxBlur(a, w, h, b); return a; }
// Soft round brush, max-combined (strokes never get brighter where they overlap themselves).
function splat(buf, w, h, cx, cy, r, v) {
  const x0 = Math.max(0, Math.floor(cx - r * 2)), x1 = Math.min(w - 1, Math.ceil(cx + r * 2));
  const y0 = Math.max(0, Math.floor(cy - r * 2)), y1 = Math.min(h - 1, Math.ceil(cy + r * 2));
  for (let y = y0; y <= y1; y++) for (let x = x0; x <= x1; x++) {
    const d2 = ((x - cx) ** 2 + (y - cy) ** 2) / (r * r);
    const s = v * Math.exp(-d2 * 1.6);
    if (s > buf[y * w + x]) buf[y * w + x] = s;
  }
}
function save(name, im) {
  const n = im.w * im.h, rgba = Buffer.alloc(n * 4);
  for (let i = 0; i < n; i++) {
    // Every texture fades to nothing at its border, so overlapping quads never show a straight edge.
    const x = i % im.w, y = Math.floor(i / im.w), edge = Math.min(x, y, im.w - 1 - x, im.h - 1 - y) / (im.w * 0.04);
    const a = clamp(im.a[i]) * smooth(0, 1, edge);
    // Where alpha is ~0 keep the colour white, so filtering never pulls dark fringes into the edges.
    const l = a < 0.004 ? 1 : clamp(im.l[i]);
    rgba[i * 4] = rgba[i * 4 + 1] = rgba[i * 4 + 2] = Math.round(l * 255);
    rgba[i * 4 + 3] = Math.round(a * 255);
  }
  writePng(path.join(OUT, name + '.png'), im.w, im.h, rgba);
  console.log('wrote', name, im.w + 'x' + im.h);
}
// Pack frames (each `cell` square, drawn by fn(frameIndex, img)) into a grid sheet.
function sheet(grid, cell, pad, fn) {
  const S = img(grid * cell);
  for (let f = 0; f < grid * grid; f++) {
    const inner = cell - 2 * pad, fr = img(inner);
    fn(f, fr);
    const ox = (f % grid) * cell + pad, oy = Math.floor(f / grid) * cell + pad;
    for (let y = 0; y < inner; y++) for (let x = 0; x < inner; x++) {
      const i = y * inner + x, j = (oy + y) * S.w + ox + x;
      // Fade the outer 3% so nothing touches the padding.
      const e = Math.min(x, y, inner - 1 - x, inner - 1 - y) / (inner * 0.03);
      S.a[j] = fr.a[i] * clamp(e); S.l[j] = fr.l[i];
    }
  }
  return S;
}

// ---------------------------------------------------------------- rain: vertical streak
function rain() {
  const N = 256, im = img(N);
  for (let y = 0; y < N; y++) for (let x = 0; x < N; x++) {
    const u = x / N - 0.5, v = y / N;
    const across = Math.exp(-((u / 0.009) ** 2)) + 0.2 * Math.exp(-((u / 0.02) ** 2));
    const along = smooth(0.04, 0.45, v) * (1 - smooth(0.7, 0.97, v));
    im.a[y * N + x] = clamp(across * along);
  }
  return im;
}
// ---------------------------------------------------------------- ember: hot point
function ember() {
  const N = 128, im = img(N);
  for (let y = 0; y < N; y++) for (let x = 0; x < N; x++) {
    const r = Math.hypot(x / N - 0.5, y / N - 0.5);
    im.a[y * N + x] = clamp(Math.exp(-((r / 0.075) ** 2)) + 0.55 * Math.exp(-((r / 0.2) ** 2)));
  }
  return im;
}
// ---------------------------------------------------------------- bubble
function bubble() {
  const N = 256, im = img(N), R = 0.4;
  for (let y = 0; y < N; y++) for (let x = 0; x < N; x++) {
    const u = x / N - 0.5, v = y / N - 0.5, r = Math.hypot(u, v);
    const rim = Math.exp(-(((r - R) / 0.022) ** 2));
    const fill = 0.16 * (1 - smooth(R - 0.02, R, r)) * (0.6 + 0.4 * r / R);
    const spot = Math.exp(-(((u + 0.15) / 0.07) ** 2 + ((v + 0.16) / 0.055) ** 2));
    const ang = Math.atan2(v, u), cres = Math.exp(-(((r - R * 0.8) / 0.025) ** 2)) * Math.max(0, Math.cos(ang - Math.PI / 4)) ** 3 * 0.55;
    im.a[y * N + x] = clamp(rim * 0.95 + fill + spot + cres);
    im.l[y * N + x] = 0.82 + 0.18 * clamp(rim + spot * 2 + cres);
  }
  return im;
}
// ---------------------------------------------------------------- snow: six-armed flake
function segDist(px, py, ax, ay, bx, by) {
  const dx = bx - ax, dy = by - ay, t = clamp(((px - ax) * dx + (py - ay) * dy) / (dx * dx + dy * dy));
  return Math.hypot(px - ax - t * dx, py - ay - t * dy);
}
function snow() {
  const N = 256, im = img(N), segs = [];
  for (let k = 0; k < 6; k++) {
    const a = k * Math.PI / 3 + Math.PI / 6, c = Math.cos(a), s = Math.sin(a), L = 0.4;
    segs.push([0, 0, c * L, s * L, 0.022]);
    for (const [f, len] of [[0.5, 0.13], [0.75, 0.09]]) {
      for (const sg of [-1, 1]) {
        const b = a + sg * Math.PI / 4;
        segs.push([c * L * f, s * L * f, c * L * f + Math.cos(b) * len, s * L * f + Math.sin(b) * len, 0.016]);
      }
    }
  }
  for (let y = 0; y < N; y++) for (let x = 0; x < N; x++) {
    const u = x / N - 0.5, v = y / N - 0.5;
    let a = 0;
    for (const [ax, ay, bx, by, w] of segs) a = Math.max(a, 1 - smooth(w * 0.6, w, segDist(u, v, ax, ay, bx, by)));
    const r = Math.hypot(u, v);
    a = Math.max(a, 1 - smooth(0.04, 0.06, r));
    im.a[y * N + x] = clamp(a + 0.22 * Math.exp(-((r / 0.2) ** 2)));
    im.l[y * N + x] = 0.85 + 0.15 * a;
  }
  return im;
}
// ---------------------------------------------------------------- comet: head + tail along U (Beam texture)
function comet() {
  const N = 256, im = img(N);
  for (let y = 0; y < N; y++) for (let x = 0; x < N; x++) {
    const u = 1 - x / N, v = y / N - 0.5; // head near U = 0 (a Beam's Attachment0 end), tail toward U = 1
    const head = Math.exp(-(((u - 0.86) / 0.05) ** 2 + (v / 0.09) ** 2));
    const t = clamp((u - 0.05) / 0.81); // 0 at the tail's end, 1 at the head
    const tail = (u < 0.86 ? t * t : Math.exp(-(((u - 0.86) / 0.04) ** 2))) * Math.exp(-((v / (0.025 + 0.06 * t)) ** 2));
    im.a[y * N + x] = clamp(head + tail * 0.9);
    im.l[y * N + x] = 0.85 + 0.15 * clamp(head * 2);
  }
  return im;
}
// ---------------------------------------------------------------- stamp: embossed X (tiling, no border)
// Both diagonals cut as one 20 px groove in white (alpha 0.9) with soft 1 px edges. The game tints it per theme
// through Texture.Color3 (a darker shade of the face, or the theme's own groove colour), so one PNG gives a
// saturated groove on every base colour: one X per facet per section, chunky enough to read from the aisle.
function stamp() {
  const N = 128, rgba = Buffer.alloc(N * N * 4);
  const diag = (x, y) => { const u = x / N, v = y / N; return Math.min(Math.abs(u - v), Math.abs(u + v - 1)) / Math.SQRT2 * N; }; // px to the X
  for (let y = 0; y < N; y++) for (let x = 0; x < N; x++) {
    let groove = 0;
    for (let sy = 0; sy < 3; sy++) for (let sx = 0; sx < 3; sx++) { // 3x3 supersampling for clean edges
      const px = x + (sx + 0.5) / 3, py = y + (sy + 0.5) / 3;
      if (diag(px, py) <= 10) groove += 1 / 9;
    }
    rgba[(y * N + x) * 4] = rgba[(y * N + x) * 4 + 1] = rgba[(y * N + x) * 4 + 2] = 255;
    rgba[(y * N + x) * 4 + 3] = Math.round(0.9 * groove * 255);
  }
  writePng(path.join(OUT, 'stamp.png'), N, N, rgba);
  console.log('wrote stamp', N + 'x' + N);
}
// ---------------------------------------------------------------- firepuff: round cartoon fire (4x4 Loop)
function firepuff(fr, f) {
  const N = fr.w, n1 = perlin(77), r = rng(91);
  // A soft lumpy blob: round lobes round a core make the outline, and the alpha falls off over the outer 20%
  // only, so a puff keeps a readable flame edge (no hard rim, no drawn lump outlines), with a hot core.
  const lobes = [];
  for (let i = 0; i < 8; i++) {
    const a = i / 8 * 6.283 + r() * 0.4, up = Math.sin(a) < 0 ? 1.15 : 0.85;
    lobes.push({ a, d: (0.15 + r() * 0.05) * up, rr: 0.13 + r() * 0.04, ph: r() * 6.283 });
  }
  const t = f / 16 * 6.283; // loop phase
  for (let y = 0; y < N; y++) for (let x = 0; x < N; x++) {
    const u = x / N - 0.5, v = y / N - 0.53;
    let dens = 1 - Math.hypot(u, v) / 0.24;
    for (const L of lobes) {
      const d = L.d * (1 + 0.12 * Math.sin(t + L.ph)), rr = L.rr * (1 + 0.15 * Math.sin(t * 2 + L.ph));
      dens = Math.max(dens, 1 - Math.hypot(u - Math.cos(L.a) * d, v - Math.sin(L.a) * d) / rr);
    }
    const warp = (fbm(n1, u * 6 + Math.cos(t) * 0.7, v * 6 + Math.sin(t) * 0.7, 3) - 0.5) * 0.25;
    const a = smooth(0.0, 0.2, dens + warp); // 0 at the outline, full 20% of the way in
    const core = 1 - Math.hypot(u, v + 0.02) / 0.24;
    fr.a[y * N + x] = clamp(a);
    fr.l[y * N + x] = clamp(0.9 + 0.1 * smooth(0, 0.8, core));
  }
}
// ---------------------------------------------------------------- streakup: straight tapered wisp
function streakup() {
  const N = 256, im = img(N), n1 = perlin(5);
  for (let y = 0; y < N; y++) for (let x = 0; x < N; x++) {
    const u = x / N - 0.5, h = 1 - y / N; // h = 0 at the root (bottom), 1 at the tip
    const w = 0.03 * (1 - 0.3 * h) + 0.012; // ~0.5 stud wide at 7 studs, soft (blurred) edges
    const cx = (fbm(n1, h * 2, 0.5, 2) - 0.5) * 0.02;
    const across = Math.exp(-(((u - cx) / w) ** 2) * 1.2);
    const along = smooth(0, 0.3, h) * (1 - smooth(0.55, 0.98, h)); // soft at both ends
    im.a[y * N + x] = clamp(across * along * (0.8 + 0.2 * fbm(n1, u * 20, h * 6, 3)));
  }
  return im;
}

save('rain', rain());
save('ember', ember());
save('bubble', bubble());
save('snow', snow());
save('comet', comet());
save('firepuff', sheet(4, 256, 8, (f, fr) => firepuff(fr, f)));
save('streakup', streakup());
stamp();
