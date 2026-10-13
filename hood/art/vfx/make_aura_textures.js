// Hood aura textures: soft clouds, curly wisps, mist, light rays, flames, electric arcs, glitter, a ground
// swirl and dust. Pure Node (no canvas): noise, gaussian splats and blurs on float buffers, saved as PNG.
// Run:  node make_aura_textures.js [outDir]     (default: next to this file)
// Every texture is white/grey on transparent so ParticleEmitter.Color / Beam.Color tint it in game. Grey
// inside a texture is shading (it darkens the tint), alpha is the shape. Flipbooks are square sheets whose
// frames are padded so mip filtering never bleeds one frame into the next.
//   aura    1024  2x2 static variants  billowy cloud puffs   (FlipbookStartRandom, Framerate 0)
//   wisp    1024  4x4 OneShot          a smoke curl growing, curling and breaking up
//   flame   1024  4x4 Loop             a cartoon flame tongue, loops seamlessly
//   arc     1024  2x2 Random           four electric bolts
//   mist     512  single               a wide, low-contrast fog patch
//   ray      512  single               vertical light shaft for particles (bright at the bottom)
//   shaft    512  single               horizontal light band for Beams (U runs along the beam)
//   glitter  256  single               four-point twinkle
//   swirl    512  single               three-armed vortex for a flat spinning ground decal
//   dust     128  single               soft irregular mote
//   softglow 256  single               gaussian glow, no hard rim (halos, floor and core glows)
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

// ---------------------------------------------------------------- aura: billowy cloud puffs (2x2 variants)
function cloud(fr, seed) {
  const N = fr.w, r = rng(seed), n1 = perlin(seed), n2 = perlin(seed + 7);
  // A cumulus cluster: a wide base row and smaller lobes billowing up out of it.
  const lobes = [];
  for (let i = 0; i < 5; i++) lobes.push([0.22 + i * 0.14 + (r() - 0.5) * 0.06, 0.6 + (r() - 0.5) * 0.06, 0.15 + r() * 0.05]);
  for (let i = 0; i < 3; i++) lobes.push([0.32 + i * 0.18 + (r() - 0.5) * 0.08, 0.42 + (r() - 0.5) * 0.08, 0.14 + r() * 0.06]);
  lobes.push([0.45 + (r() - 0.5) * 0.12, 0.3 + r() * 0.06, 0.12 + r() * 0.04]);
  const L = [-0.45, -0.75, 0.5], ll = Math.hypot(...L); L.forEach((v, i) => L[i] = v / ll);
  for (let y = 0; y < N; y++) for (let x = 0; x < N; x++) {
    let u = x / N, v = y / N;
    // Warp the lookup so lobe edges curl instead of being perfect circles.
    u += (fbm(n1, u * 4, v * 4, 4) - 0.5) * 0.12; v += (fbm(n2, u * 4, v * 4, 4) - 0.5) * 0.12;
    let dens = 0, shade = 0, wsum = 0;
    for (const [cx, cy, rr] of lobes) {
      const dx = (u - cx) / rr, dy = (v - cy) / rr, d2 = dx * dx + dy * dy;
      if (d2 >= 1) continue;
      const c = Math.pow(1 - d2, 1.4);
      dens += c;
      const nz = Math.sqrt(1 - d2);
      const lit = 0.58 + 0.42 * Math.max(0, dx * L[0] + dy * L[1] + nz * L[2]);
      shade += lit * c; wsum += c;
    }
    const D = 1 - Math.exp(-2.6 * dens);
    const detail = fbm(n1, u * 11 + 5, v * 11, 4);
    const i = y * N + x;
    fr.a[i] = smooth(0.08, 0.62, D * (0.78 + 0.32 * detail)) * 0.97;
    fr.l[i] = wsum > 0 ? clamp((shade / wsum) * (0.9 + 0.12 * detail)) : 1;
  }
  fr.a = blur(fr.a, N, N, 2);
}

// ---------------------------------------------------------------- wisp: curly smoke tendril (4x4 OneShot)
// The path is a clothoid: curvature grows along it, so it starts nearly straight and ends in a tight curl.
function curlPath(x0, y0, heading, len, k0, k1, dir) {
  const pts = [], ds = 0.0025;
  let x = x0, y = y0, th = heading;
  for (let s = 0; s <= len; s += ds) { pts.push([x, y, s / len]); const k = k0 + k1 * Math.pow(s / len, 2.2); th += dir * k * ds; x += Math.cos(th) * ds; y += Math.sin(th) * ds; }
  return pts;
}
function wisp(fr, f) {
  const N = fr.w, t = f / 15, n1 = perlin(91), n2 = perlin(92), n3 = perlin(93);
  const grow = smooth(0, 0.4, t) * 0.75 + 0.25;          // the tendril draws in from its base
  const curl = 1 + 0.25 * t;                             // and keeps curling tighter
  const lines = new Float32Array(N * N), fill = new Float32Array(N * N);
  // The main tendril, and a thinner branch that peels off a third of the way up and curls the other way.
  const main = curlPath(0, 0, -Math.PI / 2 + 0.25, 1.0, 0.4, 26 * curl, 1);
  const [bx, by] = main[Math.floor(main.length * 0.32)], [cx, cy] = main[Math.floor(main.length * 0.32) + 1];
  const branch = curlPath(bx, by, Math.atan2(cy - by, cx - bx) - 0.75, 0.5, 0.8, 24 * curl, -1);
  const strands = [[[0.036, 1, 0], main], [[0.024, 0.85, 0.32], branch]];
  // Fit the full-grown curl (first frame's shape at full length) into the frame, keeping its aspect.
  let x0 = 1e9, y0 = 1e9, x1 = -1e9, y1 = -1e9;
  for (const [, pts] of strands) for (const [x, y] of pts) { x0 = Math.min(x0, x); y0 = Math.min(y0, y); x1 = Math.max(x1, x); y1 = Math.max(y1, y); }
  const sc = 0.8 / Math.max(x1 - x0, y1 - y0), ox = 0.5 - (x0 + x1) / 2 * sc, oy = 0.5 - (y0 + y1) / 2 * sc;
  for (const [[w0, wt, from], pts] of strands) {
    for (let i = 1; i < pts.length; i++) {
      const s = pts[i][2];
      if (from + s * (1 - from) * 0.6 > grow) break; // the branch only grows once the main tendril reaches it
      const x = pts[i][0] * sc + ox, y = pts[i][1] * sc + oy;
      // Width tapers into the curl; the base thins out as the smoke detaches later in life.
      const w = w0 * sc * (1 - 0.6 * s) * smooth(0, 0.06, s) * (1 - 0.45 * smooth(0.5, 1, t));
      const cut = Math.max(0, (t - 0.5) * 1.6);
      const vis = wt * (t < 0.5 ? 1 : smooth(cut - 0.2, cut + 0.1, s));
      const px = pts[i - 1][0] - pts[i][0], py = pts[i - 1][1] - pts[i][1], pl = Math.hypot(px, py) || 1;
      const nx = -py / pl, ny = px / pl;
      // Bright edge lines either side and a soft body between: the "inked smoke" look.
      for (const side of [-1, 1]) splat(lines, N, N, (x + nx * w * side) * N, (y + ny * w * side) * N, N * 0.009, vis);
      splat(fill, N, N, x * N, y * N, w * N * 1.1, vis * 0.3);
    }
  }
  const warp = 0.01 + 0.03 * t, erode = smooth(0.5, 1.05, t) * 0.75;
  const L1 = blur(lines, N, N, 1.2), F1 = blur(fill, N, N, 3);
  for (let y = 0; y < N; y++) for (let x = 0; x < N; x++) {
    const u = x / N, v = y / N;
    const wx = u + (fbm(n1, u * 5, v * 5 - t, 4) - 0.5) * 2 * warp, wy = v + (fbm(n2, u * 5 + 3, v * 5 - t, 4) - 0.5) * 2 * warp;
    const sx = clamp(Math.round(wx * N), 0, N - 1), sy = clamp(Math.round(wy * N), 0, N - 1), j = sy * N + sx;
    const brk = smooth(erode - 0.1, erode + 0.25, fbm(n3, u * 9, v * 9 - t * 2, 4));
    const i = y * N + x;
    fr.a[i] = clamp(Math.max(L1[j] * 1.2, F1[j]) * brk * 1.1);
    fr.l[i] = clamp(0.78 + 0.22 * (L1[j] / (L1[j] + F1[j] + 1e-4)));
  }
}

// ---------------------------------------------------------------- flame: cartoon tongue (4x4 Loop)
function flame(fr, f) {
  const N = fr.w, t = f / 16, n1 = perlin(301), n2 = perlin(302);
  const ca = Math.cos(t * Math.PI * 2) * 0.9, sa = Math.sin(t * Math.PI * 2) * 0.9; // periodic in t
  const outer = new Float32Array(N * N), inner = new Float32Array(N * N);
  for (let y = 0; y < N; y++) for (let x = 0; x < N; x++) {
    const v = 1 - y / N;                // 0 bottom, 1 top
    let u = (x / N - 0.5) * 2;          // -1..1
    const sway = (fbm(n1, v * 2.2 + ca, sa + 4, 3) - 0.5) * 0.9 * Math.pow(v, 1.3);
    u -= sway;
    const flick = (fbm(n2, v * 4 + ca * 1.3, sa * 1.3 + 9, 3) - 0.5) * 0.25;
    // Teardrop half-width: round belly at the bottom, sharp tip at the top.
    // Round belly (a half circle at the bottom), then a long taper to a sharp tip.
    const hw = (vv) => vv < 0.05 ? 0 : vv < 0.3 ? 0.62 * Math.sqrt(clamp(1 - ((0.3 - vv) / 0.25) ** 2)) : 0.62 * Math.pow(clamp(1 - (vv - 0.3) / 0.65), 1.1);
    const ho = hw(v) * (1 + flick), hi = hw(Math.min(1, v * 1.35 + 0.02)) * 0.55 * (1 + flick);
    const i = y * N + x;
    outer[i] = ho > 0.002 ? smooth(ho, ho * 0.5, Math.abs(u)) : 0;
    inner[i] = hi > 0.002 ? smooth(hi, hi * 0.3, Math.abs(u)) : 0;
  }
  // A detached lick rising off the tip and shrinking (same position at t = 0 and t = 1).
  const ph = t, by = 0.12 + 0.12 * ph, br = 0.07 * (1 - ph);
  if (br > 0.005) splat(outer, N, N, (0.5 + (fbm(n1, 3, ph * 3) - 0.5) * 0.2) * N, by * N, br * N, 1 - ph);
  const O = blur(outer, N, N, 1.5), I = blur(inner, N, N, 2);
  for (let i = 0; i < N * N; i++) { fr.a[i] = clamp(O[i] * 1.05); fr.l[i] = clamp(0.62 + 0.38 * I[i] / Math.max(0.05, O[i])); }
}

// ---------------------------------------------------------------- arc: electric bolts (2x2 Random)
function bolt(pts, a, b, disp, depth, r) {
  if (depth === 0) { pts.push(b); return; }
  const mx = (a[0] + b[0]) / 2, my = (a[1] + b[1]) / 2, dx = b[0] - a[0], dy = b[1] - a[1], len = Math.hypot(dx, dy) || 1;
  const off = (r() - 0.5) * 2 * disp;
  const m = [mx - dy / len * off, my + dx / len * off];
  bolt(pts, a, m, disp * 0.55, depth - 1, r); bolt(pts, m, b, disp * 0.55, depth - 1, r);
}
function arc(fr, seed) {
  const N = fr.w, r = rng(seed), core = new Float32Array(N * N);
  const draw = (a, b, disp, width) => {
    const pts = [a]; bolt(pts, a, b, disp, 7, r);
    for (let i = 1; i < pts.length; i++) {
      const [x0, y0] = pts[i - 1], [x1, y1] = pts[i], steps = Math.ceil(Math.hypot(x1 - x0, y1 - y0) * N / 1.5);
      for (let k = 0; k <= steps; k++) splat(core, N, N, lerp(x0, x1, k / steps) * N, lerp(y0, y1, k / steps) * N, width * N, 1);
    }
    return pts;
  };
  const main = draw([0.06, 0.5 + (r() - 0.5) * 0.2], [0.94, 0.5 + (r() - 0.5) * 0.2], 0.2, 0.009);
  for (let b = 0; b < 2; b++) {
    const s = main[Math.floor(main.length * (0.25 + r() * 0.5))], ang = (r() - 0.5) * 1.6, l = 0.18 + r() * 0.2;
    draw(s, [s[0] + Math.cos(ang) * l, s[1] + Math.sin(ang) * l], 0.07, 0.0055);
  }
  const mid = blur(core, N, N, 3), glow = blur(core, N, N, 14);
  for (let i = 0; i < N * N; i++) { fr.a[i] = clamp(Math.max(core[i], mid[i] * 1.6, glow[i] * 3.2 * 0.5)); fr.l[i] = clamp(0.8 + 0.2 * core[i]); }
}

// ---------------------------------------------------------------- singles
function mist() {
  const N = 512, im = img(N), n1 = perlin(501), n2 = perlin(502);
  for (let y = 0; y < N; y++) for (let x = 0; x < N; x++) {
    const u = x / N, v = y / N, e = ((u - 0.5) / 0.46) ** 2 + ((v - 0.52) / 0.3) ** 2;
    const wu = u + (fbm(n2, u * 3, v * 3, 4) - 0.5) * 0.25;
    const n = fbm(n1, wu * 3.2, v * 4.5, 5);
    const i = y * N + x;
    im.a[i] = Math.exp(-3.2 * e) * smooth(0.18, 0.85, 0.3 + 0.7 * n) * 0.85;
    im.l[i] = 0.88 + 0.12 * n;
  }
  im.a = blur(im.a, N, N, 3);
  return im;
}
function ray() {
  const N = 512, im = img(N), r = rng(611), n1 = perlin(612);
  const subs = [...Array(4)].map(() => [(r() - 0.5) * 0.12, 0.012 + r() * 0.012, 0.35 + r() * 0.35]);
  for (let y = 0; y < N; y++) for (let x = 0; x < N; x++) {
    const up = 1 - y / N, u = x / N - 0.5;            // up: 0 at the bottom edge, 1 at the top
    const sig = 0.06 + 0.07 * up;                       // widens a little as it rises
    let c = Math.exp(-(u * u) / (2 * sig * sig));
    for (const [o, s, a] of subs) c = Math.max(c, a * Math.exp(-((u - o * (0.4 + up)) ** 2) / (2 * s * s)));
    const streak = 0.75 + 0.25 * fbm(n1, u * 30, up * 1.2, 3);
    im.a[y * N + x] = c * streak * smooth(0, 0.07, up) * Math.pow(1 - up, 1.15);
  }
  return im;
}
function shaft() {
  const N = 512, im = img(N), n1 = perlin(621);
  for (let y = 0; y < N; y++) for (let x = 0; x < N; x++) {
    const u = x / N, v = (y / N - 0.5) * 2;             // u along the beam, v across it
    const cross = Math.exp(-v * v / (2 * 0.3 * 0.3));
    const streak = 0.6 + 0.4 * fbm(n1, u * 2.5, v * 14, 4);
    im.a[y * N + x] = cross * streak * smooth(0, 0.06, u) * smooth(1, 0.8, u);
  }
  return im;
}
function glitter() {
  const N = 256, im = img(N);
  for (let y = 0; y < N; y++) for (let x = 0; x < N; x++) {
    const u = (x / N - 0.5) * 2, v = (y / N - 0.5) * 2, d = Math.hypot(u, v);
    const core = Math.exp(-d * d / 0.012);
    const halo = Math.exp(-d * d / 0.09) * 0.45;
    const fl = (a, b, w) => Math.exp(-Math.abs(b) / w) * Math.pow(clamp(1 - Math.abs(a)), 2.2);
    const cross = Math.max(fl(u, v, 0.025), fl(v, u, 0.025));
    const s = Math.SQRT1_2, du = (u + v) * s, dv = (u - v) * s;
    const diag = 0.45 * Math.max(fl(du * 1.6, dv, 0.02), fl(dv * 1.6, du, 0.02));
    im.a[y * N + x] = clamp(Math.max(core, halo, cross, diag));
  }
  return im;
}
function swirl() {
  const N = 512, im = img(N), n1 = perlin(701);
  for (let y = 0; y < N; y++) for (let x = 0; x < N; x++) {
    const u = (x / N - 0.5) * 2, v = (y / N - 0.5) * 2, r = Math.hypot(u, v), th = Math.atan2(v, u);
    const arm = Math.pow(0.5 + 0.5 * Math.cos(3 * th + 7 * r), 3);
    const win = smooth(0.06, 0.32, r) * smooth(1, 0.62, r);
    const n = fbm(n1, u * 4, v * 4, 4);
    im.a[y * N + x] = clamp((arm * (0.7 + 0.5 * n) + 0.12) * win);
  }
  im.a = blur(im.a, N, N, 2);
  return im;
}
// Gaussian glow that reaches zero long before the border: no visible disc edge, even stacked additively.
function softglow() {
  const N = 256, im = img(N);
  for (let y = 0; y < N; y++) for (let x = 0; x < N; x++) {
    const u = (x / N - 0.5) * 2, v = (y / N - 0.5) * 2, d2 = u * u + v * v;
    im.a[y * N + x] = 0.85 * Math.exp(-d2 * 5.5) + 0.15 * Math.exp(-d2 * 40);
  }
  return im;
}
function dust() {
  const N = 128, im = img(N), n1 = perlin(801);
  for (let y = 0; y < N; y++) for (let x = 0; x < N; x++) {
    const u = (x / N - 0.5) * 2, v = (y / N - 0.5) * 2, d = Math.hypot(u, v) * (0.85 + 0.3 * fbm(n1, u * 2, v * 2, 3));
    im.a[y * N + x] = Math.exp(-d * d * 5) * 0.95;
  }
  return im;
}

fs.mkdirSync(OUT, { recursive: true });
save('aura', sheet(2, 512, 16, (f, fr) => cloud(fr, 1000 + f * 17)));
save('wisp', sheet(4, 256, 8, (f, fr) => wisp(fr, f)));
save('flame', sheet(4, 256, 8, (f, fr) => flame(fr, f)));
save('arc', sheet(2, 512, 16, (f, fr) => arc(fr, 4000 + f * 31)));
save('mist', mist());
save('ray', ray());
save('shaft', shaft());
save('glitter', glitter());
save('swirl', swirl());
save('dust', dust());
save('softglow', softglow());
