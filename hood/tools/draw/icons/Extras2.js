// More of the game's pictures, in the same kit: Robux (the white rounded hexagon with a ring and a square, as on the
// refs' price buttons), Search (a chunky magnifying glass), Shield (a blue heater shield), Skull (a cartoon skull),
// PVP (a red boxing glove) and ShoePile (a small heap of three sneakers).
'use strict';

const { shoe, COLORS } = require('./Sneaker');

const P2 = (U, C = [256, 256]) => ([u, v]) => [C[0] + u * U, C[1] + v * U];

function hexPts(P, r, rot = 0) {
	const out = [];
	for (let i = 0; i < 6; i++) {
		const a = ((rot + 90 + i * 60) * Math.PI) / 180;
		out.push(P([Math.cos(a) * r, Math.sin(a) * r]));
	}
	return out;
}

// ---------------------------------------------------------------- Robux
function robux(k, K) {
	const U = 215, P = P2(U);
	const outer = K.roundPts(hexPts(P, 0.98), 0.2 * U, 5);
	const sl = k.slab(outer, [-0.02 * U, -0.07 * U], { face: '#ffffff', wall: '#c9d3df', rib: '#dfe6ee', pitch: 40 });
	let g = sl.body;
	g += k.soft(sl.face, K.circle(...P([0.5, 0.6]), 0.7 * U), '#dfe5ee', 18, 0.9);
	const ring = K.roundPoly(hexPts(P, 0.62), 0.12 * U), ringIn = K.roundPoly(hexPts(P, 0.45), 0.08 * U);
	g += `<path d="${ring} ${ringIn}" fill="${k.NAVY}" fill-rule="evenodd"/>`;
	g += k.path(K.roundPoly([P([-0.13, -0.13]), P([0.13, -0.13]), P([0.13, 0.13]), P([-0.13, 0.13])], 0.02 * U), k.NAVY);
	g += k.streak([P([-0.8, 0.1]), P([-0.84, -0.3]), P([-0.56, -0.66])], 0.05 * U, { bias: 0.5, power: 0.6, color: '#ffffff' });
	return { sil: sl.sil, body: g };
}

// ---------------------------------------------------------------- Search
function search(k, K) {
	const U = 210, P = P2(U, [270, 236]);
	const c = P([0.12, -0.14]);
	const ro = 0.62 * U, ri = 0.42 * U;
	const ringD = `${K.circle(c[0], c[1], ro)} ${K.circle(c[0], c[1], ri)}`;
	const lens = K.circle(c[0], c[1], ri + 2);
	// the handle: a chunky rounded bar down-left, with a collar
	const hp = (u, v) => K.rotp(P([u, v]), c, 45);
	const handle = K.roundPoly([hp(-0.13, 0.62), hp(0.13, 0.62), hp(0.15, 1.5), hp(-0.15, 1.5)], 0.12 * U);
	const collar = K.roundPoly([hp(-0.18, 0.56), hp(0.18, 0.56), hp(0.18, 0.76), hp(-0.18, 0.76)], 0.05 * U);
	let g = '';
	g += k.path(handle, '#f39a1e') + k.soft(handle, K.poly([hp(0.02, 0.6), hp(0.3, 0.6), hp(0.3, 1.6), hp(0.02, 1.6)]), '#d97a0c', 4, 0.8);
	g += k.tiles(handle, [1, 0, 0, 1, 0, 0], [hp(-0.08, 0.86), hp(-0.08, 1.12)].map(([x, y]) => [x - 0.08 * U, y - 0.08 * U]), { s: 0.16 * U, r: 0.035 * U, alpha: 0.18, bevel: 0.4, shadow: 0.22, shadowColor: '#7a3a00', blurSd: 1.1 });
	g += k.path(collar, '#8d98a8');
	// the ring (shaded down-right), then the glass on top of its inside
	const ringOut = K.circle(c[0], c[1], ro);
	g += k.path(ringOut, '#b4bfcc');
	g += k.clip(ringOut, `<path d="${K.circle(c[0] + 0.16 * U, c[1] + 0.18 * U, ro)}" fill="#8592a4" ${k.blur(10)}/>`);
	g += k.tiles(ringOut, [1, 0, 0, 1, 0, 0], [0, 60, 120, 180, 240, 300].map((a) => {
		const t = (a * Math.PI) / 180, r = (ro + ri) / 2;
		return [c[0] + Math.cos(t) * r - 0.075 * U, c[1] + Math.sin(t) * r - 0.075 * U];
	}), { s: 0.15 * U, r: 0.035 * U, alpha: 0.2, bevel: 0.45, shadow: 0.22, shadowColor: '#3a4656', blurSd: 1.1 });
	g += k.path(K.circle(c[0], c[1], ri + 6), '#6f7c90');
	g += k.path(lens, '#9fdcf7');
	g += k.soft(lens, K.circle(c[0] + 0.2 * U, c[1] + 0.2 * U, 0.35 * U), '#6cc2ea', 12, 0.8);
	g += k.clip(lens, k.streak([P([-0.18, -0.08]), P([-0.12, -0.32]), P([0.06, -0.44])], 0.08 * U, { bias: 0.5, power: 0.6 }));
	g += k.streak([P([-0.44, 0.06]), P([-0.46, -0.3]), P([-0.24, -0.6])], 0.05 * U, { bias: 0.5, power: 0.6 });
	return { sil: [K.circle(c[0], c[1], ro), handle, collar], body: g };
}

// ---------------------------------------------------------------- Shield
function shield(k, K) {
	const U = 215, P = P2(U);
	const S = (pts) => K.smooth(pts.map(P), true, 0.5);
	const outPts = [[-0.84, -0.84, 'c'], [0.0, -0.94], [0.84, -0.84, 'c'], [0.82, -0.1], [0.62, 0.42], [0.0, 0.96, 'c'], [-0.62, 0.42], [-0.82, -0.1]];
	const out = K.smooth(outPts.map(([u, v, c]) => (c ? [...P([u, v]), c] : P([u, v]))), true, 0.5);
	const inn = K.smooth([[-0.64, -0.66, 'c'], [0.0, -0.74], [0.64, -0.66, 'c'], [0.62, -0.1], [0.46, 0.3], [0.0, 0.72, 'c'], [-0.46, 0.3], [-0.62, -0.1]]
		.map(([u, v, c]) => (c ? [...P([u, v]), c] : P([u, v]))), true, 0.5);
	let g = k.path(out, '#c9d3df');
	g += k.soft(out, K.circle(...P([0.6, 0.6]), 0.8 * U), '#9aa8b8', 16, 0.8);
	g += k.tiles(out, [1, 0, 0, 1, 0, 0], [[-0.74, -0.78], [-0.1, -0.86], [0.56, -0.78], [-0.76, -0.2], [0.6, -0.2]].map(([u, v]) => P([u + 0.0, v])), { s: 0.12 * U, r: 0.03 * U, alpha: 0.3, bevel: 0.45, shadow: 0.24, shadowColor: '#3a4656', blurSd: 1.1 });
	g += k.path(inn, '#2f78e8');
	// a lighter left half, like a heraldic split
	g += k.clip(inn, k.path(K.poly([P([-1, -1]), P([0, -1]), P([0, 1]), P([-1, 1])]), '#4a98f6'));
	g += k.soft(inn, K.circle(...P([0.5, 0.6]), 0.6 * U), '#1f5cc8', 14, 0.6);
	g += k.tiles(inn, [1, 0, 0, 1, 0, 0], [[-0.46, -0.5], [0.12, -0.5], [-0.46, 0.0], [0.12, 0.0], [-0.17, 0.36]].map(P), { s: 0.24 * U, r: 0.055 * U, alpha: 0.14, bevel: 0.38, shadow: 0.24, shadowColor: '#0a2a6a', blurSd: 1.1 });
	g += k.streak([P([-0.84, 0.0]), P([-0.84, -0.6]), P([-0.5, -0.86])], 0.05 * U, { bias: 0.6, power: 0.6 });
	return { sil: [out], body: g };
}

// ---------------------------------------------------------------- Skull
function skull(k, K) {
	const U = 205, P = P2(U, [256, 250]);
	const S = (pts, t = 0.5) => K.smooth(pts.map(P), true, t);
	const head = S([[0.0, -0.96], [0.62, -0.8], [0.92, -0.32], [0.86, 0.16], [0.6, 0.42], [0.5, 0.62], [-0.5, 0.62], [-0.6, 0.42], [-0.86, 0.16], [-0.92, -0.32], [-0.62, -0.8]], 0.5);
	const jaw = K.roundPoly([[-0.46, 0.5], [0.46, 0.5], [0.4, 0.94], [-0.4, 0.94]].map(P), 0.12 * U);
	const eye = (sx) => S([[sx * 0.14, -0.12], [sx * 0.3, -0.34], [sx * 0.56, -0.32], [sx * 0.66, -0.08], [sx * 0.56, 0.16], [sx * 0.3, 0.2], [sx * 0.16, 0.06]]);
	const nose = K.roundPoly([[0.0, 0.18], [0.11, 0.36], [-0.11, 0.36]].map(P), 0.03 * U);
	let g = k.path(jaw, '#e9edf2');
	g += k.soft(jaw, K.poly([[0, 0.4], [0.6, 0.4], [0.6, 1], [0, 1]].map(P)), '#c4ccd8', 6, 0.7);
	// teeth gaps
	for (const x of [-0.2, 0.0, 0.2]) g += k.path(K.roundPoly([[x - 0.022, 0.62], [x + 0.022, 0.62], [x + 0.022, 0.92], [x - 0.022, 0.92]].map(P), 0.01 * U), k.NAVY);
	g += k.path(head, '#f6f8fb');
	g += k.soft(head, K.ellipse(...P([0.5, 0.3]), 0.6 * U, 0.6 * U), '#d3d9e3', 18, 0.9);
	g += k.path(eye(-1), '#2a2440') + k.path(eye(1), '#2a2440');
	g += k.path(K.circle(...P([-0.34, -0.14]), 0.07 * U), '#ffffff') + k.path(K.circle(...P([0.46, -0.14]), 0.07 * U), '#ffffff');
	g += k.path(nose, '#2a2440');
	g += k.streak([P([-0.6, -0.4]), P([-0.5, -0.7]), P([-0.2, -0.88])], 0.06 * U, { bias: 0.5, power: 0.6 });
	return { sil: [head, jaw], body: g };
}

// ---------------------------------------------------------------- PVP boxing glove
function glove(k, K) {
	const U = 205, P = P2(U, [256, 256]);
	const S = (pts, t = 0.5) => K.smooth(pts.map(P), true, t);
	// an upright glove seen from the thumb side: the big round mitt, the thumb curled across its front, a white cuff
	const mitt = S([[-0.62, 0.32], [-0.74, -0.16], [-0.62, -0.62], [-0.24, -0.92], [0.24, -0.92], [0.6, -0.66], [0.72, -0.2], [0.66, 0.2], [0.5, 0.4], [-0.3, 0.44]]);
	const thumb = S([[0.06, 0.38], [0.04, 0.06], [0.16, -0.24], [0.4, -0.36], [0.62, -0.24], [0.66, 0.02], [0.58, 0.32], [0.36, 0.44]]);
	const cuff = K.roundPoly([[-0.6, 0.34], [0.58, 0.34], [0.52, 0.96], [-0.54, 0.96]].map(P), 0.1 * U);
	const trim = K.roundPoly([[-0.6, 0.34], [0.58, 0.34], [0.57, 0.46], [-0.59, 0.46]].map(P), 0.04 * U);
	let g = k.path(cuff, '#f3f5f9') + k.soft(cuff, K.poly([[0.1, 0.4], [0.7, 0.4], [0.7, 1.1], [0.1, 1.1]].map(P)), '#cdd5df', 8, 0.8);
	for (const v of [0.62, 0.8]) g += `<path d="M${P([-0.34, v]).join(' ')} L${P([0.3, v]).join(' ')}" stroke="#c4ccd8" stroke-width="${0.05 * U}" stroke-linecap="round"/>`;
	g += k.path(trim, '#c8202c');
	g += k.path(mitt, '#ec2f3c');
	g += k.soft(mitt, K.ellipse(...P([0.5, 0.2]), 0.5 * U, 0.5 * U), '#c41f2c', 14, 0.85);
	g += k.soft(mitt, K.ellipse(...P([-0.2, -0.6]), 0.45 * U, 0.25 * U), '#ff5a64', 14, 0.8);
	g += k.tiles(mitt, [1, 0, 0, 1, 0, 0], [[-0.5, -0.5], [-0.18, -0.66], [0.16, -0.66], [-0.52, -0.16], [-0.2, -0.3]].map(P), { s: 0.2 * U, r: 0.05 * U, alpha: 0.14, bevel: 0.38, shadow: 0.24, shadowColor: '#6a0010', blurSd: 1.1 });
	// the thumb sits in front: a thin ink line round it, then the thumb
	g += k.sep([thumb], 0.035 * U);
	g += k.path(thumb, '#f2414d');
	g += k.soft(thumb, K.ellipse(...P([0.52, 0.3]), 0.22 * U, 0.18 * U), '#d82a38', 8, 0.6);
	g += k.streak([P([0.14, 0.0]), P([0.22, -0.2]), P([0.38, -0.3])], 0.04 * U, { bias: 0.5, power: 0.6, opacity: 0.9 });
	g += k.streak([P([-0.66, -0.1]), P([-0.6, -0.56]), P([-0.26, -0.86])], 0.06 * U, { bias: 0.5, power: 0.6 });
	return { sil: [mitt, thumb, cuff], body: g };
}

module.exports = [
	{ name: 'Robux', draw: (k, K) => robux(k, K) },
	{ name: 'Search', draw: (k, K) => search(k, K) },
	{ name: 'Shield', draw: (k, K) => shield(k, K) },
	{ name: 'Skull', draw: (k, K) => skull(k, K) },
	{ name: 'PVP', draw: (k, K) => glove(k, K) },
	{
		name: 'ShoePile',
		draw(k, K) {
			const GREEN = { ...COLORS.RED, upper: '#3fbf4a', upperDark: '#2a9a36', heel: '#2a9a36', tongue: '#56cc5c', collar: '#145a1a', star: '#3fbf4a', tiles: { alpha: 0.13, bevel: 0.38, shadow: 0.2, shadowColor: '#0c4a14' } };
			const a = k.place(shoe(k, K, COLORS.BLUE), 'translate(-110 -95) rotate(-10 256 256) scale(0.7) translate(110 110)');
			const b = k.place(shoe(k, K, GREEN), 'translate(120 -60) rotate(12 256 256) scale(0.7) translate(110 110)');
			const c = k.place(shoe(k, K, COLORS.RED), 'translate(0 95) scale(0.78) translate(72 72)');
			return k.group([a, b, c], 9);
		},
	},
];
