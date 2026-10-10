// The small extras: Delete (a pink-red X of rounded blocks), Favorite (a gold star), XP (a blue shield badge), Trophy (a
// gold cup), Arrow (a big green arrow pointing up), ShoeBox (an orange shoe box with a sneaker picture on the side) and
// the four shoe boxes (Box_Street, Box_Graffiti, Box_Exclusive, Box_Grail), each also split into BoxLid_<id> and
// BoxBase_<id> in the same framing for the box-opening animation. Flat shapes are chunky slabs: a darker ribbed side
// wall, big soft studs on the face, thin white slivers on the edges.
'use strict';

const K0 = require('../kit');
const { starPath } = require('./Sneaker');

const P2 = (U, C = [256, 256]) => ([u, v]) => [C[0] + u * U, C[1] + v * U];
const rotAll = (pts, c, deg) => pts.map((p) => K0.rotp(p, c, deg));

// studs on a face, on a grid of pitch p (px) turned rot degrees about c, clipped to the face
function faceStuds(k, K, faceD, c, { p = 56, s = 40, rot = 0, n = 5, ...st } = {}) {
	const a = (rot * Math.PI) / 180;
	const cells = [];
	for (let j = -n; j <= n; j++) for (let i = -n; i <= n; i++) cells.push([i * p - s / 2, j * p - s / 2]);
	return k.tiles(faceD, [Math.cos(a), Math.sin(a), -Math.sin(a), Math.cos(a), c[0], c[1]], cells, { s, r: s * 0.24, blurSd: 1.1, ...st });
}

// ---------------------------------------------------------------- Delete
function deleteX(k, K) {
	const U = 200, P = P2(U);
	const w = 0.27, L = 0.86;
	const bar = (deg) => rotAll([[-L, -w], [L, -w], [L, w], [-L, w]].map(P), [256, 256], deg);
	// the X outline: union of two bars, as one polygon (12 corners)
	const c = 256, r2 = Math.SQRT2;
	const q = (u, v) => P([u, v]);
	const d = w * r2; // half-gap where the bars cross
	const pts = rotAll([q(0, -d), q(L - w, -L - w + 0.0).map((x) => x), ], [256, 256], 0);
	// build by hand: arms along the diagonals; t = arm half width
	const t = w, e = L;
	const X = [[0, -t * r2], [e - t, -e - t + t * 0], [e + t, -e + t], [t * r2, 0], [e + t, e - t], [e - t, e + t], [0, t * r2], [-e + t, e + t], [-e - t, e - t], [-t * r2, 0], [-e - t, -e + t], [-e + t, -e - t]]
		.map(([u, v]) => P([u * 0.72, v * 0.72]));
	const face = K.roundPts(X, 0.07 * U, 4);
	const sl = k.slab(face, [-0.03 * U, -0.13 * U], { face: '#f6466e', wall: '#c21d4a', rib: '#e0386a', pitch: 44 });
	let g = sl.body;
	g += k.soft(sl.face, K.circle(...P([0.55, 0.6]), 0.7 * U), '#dc2c58', 18, 0.7);
	g += faceStuds(k, K, sl.face, [256, 256], { p: 0.27 * U, s: 0.19 * U, rot: 45, alpha: 0.14, bevel: 0.36, shadow: 0.24, shadowColor: '#6a0020' });
	g += k.streak([P([-0.72, -0.5]), P([-0.62, -0.62]), P([-0.48, -0.74])], 0.05 * U, { bias: 0.5, power: 0.6 });
	g += k.streak([P([0.3, -0.6]), P([0.46, -0.74]), P([0.58, -0.8])], 0.04 * U, { bias: 0.5, power: 0.6, opacity: 0.85 });
	return { sil: sl.sil, body: g };
}

// ---------------------------------------------------------------- Favorite
function star(k, K, { U = 215, col = { face: '#ffc928', wall: '#e08a0c', rib: '#f2a618', shade: '#f6a91a', lit: '#ffe066' } } = {}) {
	const P = P2(U, [256, 262]);
	const pts = [];
	for (let i = 0; i < 10; i++) {
		const a = -Math.PI / 2 + (i * Math.PI) / 5, rr = i % 2 ? 0.48 : 1.0;
		pts.push(P([rr * Math.cos(a) * 0.98, rr * Math.sin(a) * 0.94]));
	}
	const face = K.roundPts(pts, 0.1 * U, 4);
	const sl = k.slab(face, [-0.03 * U, -0.12 * U], { face: col.face, wall: col.wall, rib: col.rib, pitch: 42 });
	let g = sl.body;
	g += k.soft(sl.face, K.circle(...P([0.5, 0.55]), 0.7 * U), col.shade, 18, 0.8);
	g += k.soft(sl.face, K.circle(...P([-0.35, -0.3]), 0.4 * U), col.lit, 18, 0.7);
	g += faceStuds(k, K, sl.face, P([0, 0.02]), { p: 0.27 * U, s: 0.2 * U, alpha: 0.16, bevel: 0.38, shadow: 0.24, shadowColor: '#8a4a00' });
	g += k.streak([P([-0.08, -0.84]), P([-0.2, -0.56]), P([-0.36, -0.4])], 0.05 * U, { bias: 0.4, power: 0.6 });
	g += k.streak([P([-0.92, -0.26]), P([-0.7, -0.26]), P([-0.5, -0.24])], 0.04 * U, { bias: 0.5, power: 0.6, opacity: 0.85 });
	return { sil: sl.sil, body: g };
}

// ---------------------------------------------------------------- XP shield
function shield(k, K) {
	const U = 215, P = P2(U);
	const out = rotAll([[-0.8, -0.86], [0.8, -0.86], [0.8, 0.28], [0.0, 0.92], [-0.8, 0.28]].map(P), [256, 256], -8);
	const face = K.roundPts(out, 0.12 * U, 4);
	const sl = k.slab(face, [-0.03 * U, -0.1 * U], { face: '#46a8f4', wall: '#2a78d0', rib: '#3a90e4', pitch: 46 });
	let g = sl.body;
	const inner = K.roundPoly(rotAll([[-0.62, -0.68], [0.62, -0.68], [0.62, 0.18], [0.0, 0.7], [-0.62, 0.18]].map(P), [256, 256], -8), 0.08 * U);
	g += k.path(inner, '#1336a8');
	g += k.soft(inner, K.circle(...P([0.5, 0.5]), 0.6 * U), '#0c2888', 12, 0.8);
	// a lighter pentagon panel inside, like the ref's
	const panel = K.roundPoly(rotAll([[-0.5, -0.36], [0.5, -0.36], [0.5, 0.1], [0.0, 0.46], [-0.5, 0.1]].map(P), [256, 256], -8), 0.05 * U);
	g += k.path(panel, '#2a5fd8');
	// the letters "XP" as chunky white block shapes with the ink outline, tilted with the badge
	const L = (pts) => K.roundPoly(rotAll(pts.map(P), [256, 256], -8), 0.035 * U);
	const t = 0.1, cx = -0.27, cy = -0.12, e = 0.22;
	const X = L([[cx, cy - t * 1.1], [cx + e - t * 0.4, cy - e - t * 0.2], [cx + e + t * 0.5, cy - e + t * 0.7], [cx + t * 1.1, cy],
		[cx + e + t * 0.5, cy + e - t * 0.7], [cx + e - t * 0.4, cy + e + t * 0.2], [cx, cy + t * 1.1], [cx - e + t * 0.4, cy + e + t * 0.2],
		[cx - e - t * 0.5, cy + e - t * 0.7], [cx - t * 1.1, cy], [cx - e - t * 0.5, cy - e + t * 0.7], [cx - e + t * 0.4, cy - e - t * 0.2]]);
	const px = 0.08, py = cy - 0.27;
	const Pout = L([[px, py], [px + 0.3, py], [px + 0.44, py + 0.08], [px + 0.46, py + 0.2], [px + 0.42, py + 0.3], [px + 0.3, py + 0.36], [px + 0.15, py + 0.36],
		[px + 0.15, py + 0.54], [px, py + 0.54]]);
	const Pin = L([[px + 0.15, py + 0.12], [px + 0.27, py + 0.12], [px + 0.31, py + 0.18], [px + 0.27, py + 0.24], [px + 0.15, py + 0.24]]);
	const letters = `<path d="${X}"/><path d="${Pout} ${Pin}" fill-rule="evenodd"/>`;
	g += `<g fill="${k.NAVY}" stroke="${k.NAVY}" stroke-width="${0.075 * U}" stroke-linejoin="round">${letters}</g>`;
	g += `<g fill="#ffffff">${letters}</g>`;
	g += k.soft(`${X} ${Pout}`, K.poly(rotAll([[-0.6, 0.0], [0.7, 0.0], [0.7, 0.4], [-0.6, 0.4]].map(P), [256, 256], -8)), '#cfe0f4', 3, 0.8);
	g += k.streak([P([-0.78, -0.4]), P([-0.8, -0.72]), P([-0.56, -0.86])], 0.05 * U, { bias: 0.6, power: 0.6 });
	return { sil: sl.sil, body: g };
}

// ---------------------------------------------------------------- Trophy
function trophy(k, K) {
	const U = 205, P = P2(U);
	const S = (pts, t = 0.5) => K.smooth(pts.map(P), true, t);
	const cup = S([[-0.62, -0.62], [0.62, -0.62], [0.58, -0.1], [0.36, 0.24], [0.12, 0.36], [-0.12, 0.36], [-0.36, 0.24], [-0.58, -0.1]], 0.5);
	const rimO = K.ellipse(...P([0, -0.62]), 0.66 * U, 0.2 * U);
	const rimI = K.ellipse(...P([0, -0.6]), 0.5 * U, 0.13 * U);
	const handle = (sx) => {
		const o = S([[sx * 0.52, -0.52], [sx * 0.88, -0.6], [sx * 1.04, -0.36], [sx * 0.9, -0.02], [sx * 0.44, 0.16], [sx * 0.4, 0.0], [sx * 0.7, -0.12], [sx * 0.8, -0.32], [sx * 0.72, -0.4], [sx * 0.54, -0.34]], 0.5);
		return o;
	};
	const hL = handle(-1), hR = handle(1);
	const stem = K.roundPoly([[-0.12, 0.3], [0.12, 0.3], [0.16, 0.62], [-0.16, 0.62]].map(P), 0.04 * U);
	const base1 = K.roundPoly([[-0.4, 0.6], [0.4, 0.6], [0.44, 0.76], [-0.44, 0.76]].map(P), 0.05 * U);
	const base2 = K.roundPoly([[-0.56, 0.74], [0.56, 0.74], [0.56, 0.94], [-0.56, 0.94]].map(P), 0.07 * U);
	let g = '';
	g += k.path(hL, '#f0a514') + k.path(hR, '#e8960e');
	g += k.path(base2, '#f2a516') + k.path(K.roundPoly([[-0.56, 0.74], [0.56, 0.74], [0.56, 0.8], [-0.56, 0.8]].map(P), 0.02 * U), '#ffd451');
	g += k.path(base1, '#ffc928') + k.path(stem, '#f6b01e');
	g += k.path(cup, '#ffc928');
	g += k.soft(cup, K.ellipse(...P([0.42, 0.1]), 0.36 * U, 0.5 * U), '#f3a316', 10, 0.8);
	g += k.soft(cup, K.ellipse(...P([-0.32, -0.3]), 0.2 * U, 0.3 * U), '#ffe370', 10, 0.8);
	g += faceStuds(k, K, cup, P([0, -0.22]), { p: 0.27 * U, s: 0.2 * U, n: 3, alpha: 0.16, bevel: 0.38, shadow: 0.24, shadowColor: '#8a4a00' });
	g += k.tiles(base2, [1, 0, 0, 1, 0, 0], [[-0.46, 0.79], [-0.2, 0.79], [0.06, 0.79], [0.32, 0.79]].map(P), { s: 0.15 * U, r: 0.03 * U, alpha: 0.16, bevel: 0.38, shadow: 0.24, shadowColor: '#8a4a00', blurSd: 1.1 });
	g += k.path(rimO, '#ffd94e');
	g += k.path(rimI, '#e8452c');
	g += k.soft(rimI, K.ellipse(...P([0, -0.66]), 0.5 * U, 0.08 * U), '#b8281a', 4, 0.8);
	g += k.streak([P([-0.52, -0.52]), P([-0.5, -0.24]), P([-0.36, 0.06])], 0.05 * U, { bias: 0.3, power: 0.6 });
	return { sil: [hL, hR, cup, rimO, stem, base1, base2], body: g };
}

// ---------------------------------------------------------------- Arrow
function arrow(k, K) {
	const U = 205, P = P2(U, [256, 266]);
	const pts = rotAll([[0.0, -0.98], [0.94, -0.04], [0.44, -0.04], [0.44, 0.84], [-0.44, 0.84], [-0.44, -0.04], [-0.94, -0.04]].map(P), [256, 266], 42);
	const face = K.roundPts(pts, 0.08 * U, 4);
	const sl = k.slab(face, [-0.21 * U, 0.13 * U], { face: '#4fcf4f', wall: '#5fd25c', rib: '#7ee07a', pitch: 44, lightDir: [0.9, -0.3] });
	let g = sl.body;
	g += k.soft(sl.face, K.circle(...P([0.5, 0.6]), 0.6 * U), '#3cb63f', 16, 0.8);
	g += faceStuds(k, K, sl.face, P([0, 0]), { p: 0.26 * U, s: 0.19 * U, rot: 42, alpha: 0.15, bevel: 0.38, shadow: 0.24, shadowColor: '#0c5a18' });
	// white slivers along the head's left edge and down the side face's outer edge
	const tip = pts[0], lw = pts[6];
	g += k.streak([K.lerp(tip, lw, 0.05), K.lerp(tip, lw, 0.5), K.lerp(tip, lw, 0.92)], 0.05 * U, { bias: 0.4, power: 0.6 });
	const o = [-0.21 * U, 0.13 * U], b0 = [pts[4][0] + o[0], pts[4][1] + o[1]], b1 = [pts[5][0] + o[0], pts[5][1] + o[1]];
	g += k.streak([K.lerp(b1, b0, 0.1), K.lerp(b1, b0, 0.5), K.lerp(b1, b0, 0.9)], 0.04 * U, { bias: 0.5, power: 0.6, opacity: 0.9 });
	return { sil: sl.sil, body: g };
}

// ---------------------------------------------------------------- shoe boxes
// A shoe box seen 3/4 from above: body + lid (a slightly bigger, shallow box). part = 'all' | 'lid' | 'base'.
function box(k, K, c, part = 'all', { P = null, at = [0, 0, 0], W = 1.05, D = 0.7, H = 1.12, lh = 0.3, lo = 0.06 } = {}) {
	P = P || K.camera({ yaw: 28, pitch: 22, s: 165, cx: 256, cy: 256 });
	const q = (pts) => K.poly(pts.map((p) => P(...p)));
	const [ax, ay, az] = at;
	const body = K.box3(ax - W, ay - H / 2, az - D, ax + W, ay + H / 2 - lh * 0.5, az + D);
	const lid = K.box3(ax - W - lo, ay + H / 2 - lh, az - D - lo, ax + W + lo, ay + H / 2 + 0.02, az + D + lo);
	const faces = (bx) => Object.entries(bx).filter(([, f]) => P.front(f));
	let gb = '', gl = '';
	const silB = [], silL = [];
	for (const [n, f] of faces(body)) {
		const d = q(f);
		if (n === 'top') {
			// the open top (only seen when the lid is off): a rim round a dark inside
			const rimW = 0.09, t = f[0][1];
			const inner = [[ax - W + rimW, t, az - D + rimW], [ax - W + rimW, t, az + D - rimW], [ax + W - rimW, t, az + D - rimW], [ax + W - rimW, t, az - D + rimW]];
			gb += k.path(d, c.body) + k.path(q(inner), c.inside || '#3a2a4a');
			gb += k.soft(q(inner), q([[ax - W, t, az - D], [ax + W, t, az - D], [ax + W, t, az - D + 0.5], [ax - W, t, az - D + 0.5]]), '#000000', 4, 0.35);
			continue;
		}
		gb += k.path(d, n === 'front' ? c.body : c.bodySide);
		if (n === 'front') {
			const [fw, fh] = K.faceSize(f);
			gb += k.tiles(d, K.faceM(P, f), [[0.12, 0.12], [fw - 0.4, 0.12], [0.12, fh - 0.4], [fw - 0.4, fh - 0.4]], { s: 0.26, r: 0.06, ...c.studs, blurSd: 0.006 });
			if (c.decor) gb += c.decor(k, K, P, f, d);
		} else {
			const [fw, fh] = K.faceSize(f);
			gb += k.tiles(d, K.faceM(P, f), [[0.12, 0.12], [fw - 0.4, 0.12], [0.12, fh - 0.4], [fw - 0.4, fh - 0.4]], { s: 0.26, r: 0.06, ...c.studs, blurSd: 0.006 });
		}
	}
	silB.push(...Object.values(body).map(q));
	for (const [n, f] of faces(lid)) {
		const d = q(f);
		gl += k.path(d, n === 'top' ? c.lidTop : n === 'front' ? c.lid : c.lidSide);
		if (n === 'top') {
			const [fw, fh] = K.faceSize(f);
			const cells = [];
			for (let j = 0; j < 2; j++) for (let i = 0; i < 4; i++) cells.push([0.16 + i * ((fw - 0.72) / 3), 0.16 + j * ((fh - 0.72) / 1)]);
			gl += k.tiles(d, K.faceM(P, f), cells, { s: 0.4, r: 0.09, ...c.lidStuds, blurSd: 0.006 });
			if (c.lidDecor) gl += c.lidDecor(k, K, P, f, d);
		}
	}
	silL.push(...Object.values(lid).map(q));
	// slivers: the lid's left top edge, the body's front-left vertical edge
	gl += k.streak([P(ax - W - lo, ay + H / 2 + 0.02, az + D - 0.3), P(ax - W - lo, ay + H / 2 + 0.02, az - D - lo), P(ax - W + 0.4, ay + H / 2 + 0.02, az - D - lo)], 0.05 * 165, { bias: 0.5, power: 0.6 });
	gb += k.streak([P(ax - W, ay + H / 2 - lh, az + D), P(ax - W, ay - 0.05, az + D), P(ax - W, ay - H / 2 + 0.1, az + D)], 0.045 * 165, { bias: 0.15, power: 0.6 });
	if (part === 'lid') return { sil: silL, body: gl };
	if (part === 'base') return { sil: silB, body: gb };
	return { sil: silB.concat(silL), body: gb + k.sep(silL, 0) + gl };
}

const STUDS_DARK = { alpha: 0.14, bevel: 0.36, shadow: 0.24 };
const BOXES = {
	Street: { inside: '#8a96a8', body: '#f4f6f9', bodySide: '#d4dbe5', lid: '#e8343e', lidSide: '#c0202c', lidTop: '#f4525a',
		studs: { ...STUDS_DARK, alpha: 0.4, shadowColor: '#7a8aa0' }, lidStuds: { ...STUDS_DARK, shadowColor: '#6a0010' },
		decor: (...a) => sneakerPrint('#e8343e', '#8a1018')(...a) },
	Graffiti: { inside: '#18181f', body: '#3c3c4e', bodySide: '#2c2c3c', lid: '#ff4fa8', lidSide: '#d8308a', lidTop: '#ff74bc',
		studs: { ...STUDS_DARK, alpha: 0.1, shadowColor: '#000000' }, lidStuds: { ...STUDS_DARK, shadowColor: '#6a0040' },
		decor(k, K, P, f, d) {
			// paint splashes on the front
			const M = K.faceM(P, f);
			const blob = (u, v, r, col) => `<g transform="matrix(${M.join(' ')})"><path d="${K.smooth([[u - r, v], [u - r * 0.4, v - r * 0.8], [u + r * 0.5, v - r * 0.9], [u + r, v - r * 0.1], [u + r * 0.6, v + r * 0.8], [u - r * 0.3, v + r * 0.9]], true, 0.6)}" fill="${col}"/></g>`;
			return k.clip(d, blob(0.26, 0.34, 0.2, '#3ad0ff') + blob(1.86, 0.3, 0.17, '#ffe03a') + blob(1.88, 0.76, 0.18, '#7cf05a') + blob(0.24, 0.8, 0.15, '#ff4fa8')) +
				sneakerPrint('#ffffff', '#ff4fa8')(k, K, P, f, d);
		} },
	Exclusive: { inside: '#7a8aa4', body: '#f4f6f9', bodySide: '#d4dbe5', lid: '#2f86f0', lidSide: '#1f66c8', lidTop: '#4aa0f8',
		decor: (...a) => sneakerPrint('#2f86f0', '#1a4a9a')(...a),
		studs: { ...STUDS_DARK, alpha: 0.4, shadowColor: '#7a8aa0' }, lidStuds: { ...STUDS_DARK, shadowColor: '#0a2a6a' },
		lidDecor(k, K, P, f, d) {
			// a diamond gem on the lid
			const c = P(0, 0.6, 0.2);
			const s = 74;
			const gem = K.poly([[c[0] - s, c[1] - s * 0.5], [c[0] - s * 0.5, c[1] - s], [c[0] + s * 0.5, c[1] - s], [c[0] + s, c[1] - s * 0.5], [c[0], c[1] + s * 0.9]]);
			return `<path d="${gem}" fill="${k.NAVY}" stroke="${k.NAVY}" stroke-width="14" stroke-linejoin="round"/>` + k.path(gem, '#7ee8ff') +
				k.path(K.poly([[c[0] - s, c[1] - s * 0.5], [c[0] + s, c[1] - s * 0.5], [c[0], c[1] + s * 0.9]]), '#3cc6f0') +
				k.path(K.poly([[c[0] - s * 0.5, c[1] - s], [c[0] + s * 0.5, c[1] - s], [c[0] + s * 0.25, c[1] - s * 0.5], [c[0] - s * 0.25, c[1] - s * 0.5]]), '#d6fbff') +
				k.streak([[c[0] - s * 0.78, c[1] - s * 0.42], [c[0] - s * 0.42, c[1] - s * 0.1], [c[0] - s * 0.12, c[1] + s * 0.5]], s * 0.12, { bias: 0.4, power: 0.6 });
		} },
	Grail: { inside: '#44207a', body: '#9d58f0', bodySide: '#7c3ed4', lid: '#ffc928', lidSide: '#e8960e', lidTop: '#ffd94e',
		studs: { ...STUDS_DARK, shadowColor: '#2a0a5a' }, lidStuds: { ...STUDS_DARK, shadowColor: '#8a4a00' },
		decor: (...a) => sneakerPrint('#ffd23a', '#b07a10')(...a) },
};
// gold feathered wings on the Grail box's sides: three feather scallops each, swept up and out
function wings(k, K) {
	const wing = (sx) => {
		const c = [256 + sx * 186, 268];
		const W = (u, v) => [c[0] + sx * u * 130, c[1] + v * 130];
		// the root at the box, the top edge sweeping up and out, three rounded feathers along the lower edge
		const pts = [W(0, -0.22), W(0.3, -0.5), W(0.66, -0.8), W(0.86, -0.78), W(0.8, -0.56), W(0.9, -0.5), W(0.84, -0.3),
			W(0.66, -0.24), W(0.72, -0.08), W(0.5, 0.02), W(0.44, 0.08), W(0.2, 0.14), W(0, 0.16)];
		const d = K.smooth(pts, true, 0.45);
		// feather divisions: darker lines from the root toward each scallop notch
		const lines = [[W(0.2, -0.06), W(0.62, -0.26)], [W(0.18, 0.04), W(0.44, 0.0)], [W(0.24, -0.2), W(0.78, -0.54)]]
			.map(([a, b]) => `<path d="M${a.join(' ')} L${b.join(' ')}" stroke="#e8960e" stroke-width="7" stroke-linecap="round"/>`).join('');
		const body = k.path(d, '#ffd23a') + k.soft(d, K.circle(c[0] + sx * 60, c[1] + 30, 50), '#f2a818', 8, 0.8) + lines +
			k.streak([W(0.28, -0.44), W(0.56, -0.7), W(0.82, -0.8)], 9, { bias: 0.5, power: 0.6 });
		return { d, body };
	};
	return [wing(-1), wing(1)];
}

// a sneaker picture printed on a box's front face (a high-top silhouette with a sole line)
function sneakerPrint(color = '#ffffff', sole = '#ffd2a8', scale = 0.62, edge = null) {
	return (k2, K2, P, f, d) => {
		const M = K2.faceM(P, f);
		const [fw, fh] = K2.faceSize(f);
		// centred in the part of the front the lid does not cover (the lid hangs over its top ~0.15)
		const sx = fw / 2, sy = (0.15 + fh) / 2 + 0.14 * scale, sc = scale;
		const T = (pts) => pts.map(([u, v]) => [sx + u * sc, sy + v * sc]);
		// a high-top in profile, toe to the right: heel, collar dip, tongue, laces sloping down to a round toe
		const shoeD = K2.smooth(T([[-0.88, 0.3, 'c'], [-0.9, -0.2], [-0.84, -0.6, 'c'], [-0.62, -0.5], [-0.44, -0.68, 'c'], [-0.3, -0.5],
			[0.1, -0.24], [0.6, -0.1], [0.9, 0.04], [0.98, 0.3, 'c']]), true, 0.5);
		const soleD = K2.roundPoly(T([[-0.94, 0.18], [1.0, 0.18], [1.0, 0.4], [-0.94, 0.4]]), 0.04);
		const stroke = edge ? ` stroke="${edge}" stroke-width="0.05" stroke-linejoin="round"` : '';
		return `<g transform="matrix(${M.join(' ')})"><path d="${shoeD}" fill="${color}"${stroke}/><path d="${soleD}" fill="${sole}"${stroke}/></g>`;
	};
}
const SHOEBOX = { inside: '#a8480e', body: '#ff9a2a', bodySide: '#e8781c', lid: '#ff6a3a', lidSide: '#d84a24', lidTop: '#ff8656',
	studs: { ...STUDS_DARK, shadowColor: '#7a3000' }, lidStuds: { ...STUDS_DARK, shadowColor: '#7a2000' }, decor: sneakerPrint('#ffffff', '#c85a14') };
function shoeBoxIcon(k, K) {
	return box(k, K, SHOEBOX);
}

const out = [
	{ name: 'Delete', draw: (k, K) => deleteX(k, K) },
	{ name: 'Favorite', draw: (k, K) => star(k, K) },
	{ name: 'XP', draw: (k, K) => shield(k, K) },
	{ name: 'Trophy', draw: (k, K) => trophy(k, K) },
	{ name: 'Arrow', draw: (k, K) => arrow(k, K) },
	{ name: 'Evolve', draw: (k, K) => arrow(k, K) }, // the Rebirth window's arrow (the same picture)
	{ name: 'ShoeBox', draw: (k, K) => shoeBoxIcon(k, K) },
];
for (const [id, c] of Object.entries(BOXES)) {
	const withWings = (k, K, part) => {
		const b = box(k, K, c, part);
		if (id !== 'Grail' || part === 'lid') return b;
		const w = wings(k, K);
		return { sil: b.sil.concat(w.map((x) => x.d)), body: w.map((x) => x.body).join('') + b.body };
	};
	out.push({ name: 'Box_' + id, draw: (k, K) => withWings(k, K, 'all') });
	out.push({ name: 'BoxLid_' + id, frameAs: 'Box_' + id, draw: (k, K) => withWings(k, K, 'lid') });
	out.push({ name: 'BoxBase_' + id, frameAs: 'Box_' + id, draw: (k, K) => withWings(k, K, 'base') });
}
module.exports = out;
module.exports.star = star;
module.exports.trophy = trophy;
module.exports.box = box;
module.exports.sneakerPrint = sneakerPrint;
module.exports.SHOEBOX = SHOEBOX;
module.exports.BOXES = BOXES;
