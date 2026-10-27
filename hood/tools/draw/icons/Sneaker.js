// Sneaker: a chunky red and white high-top, side view, toe to the right. A thick white sole with a grey tread band,
// a white toe cap, the red upper with subtle tiles, a darker heel counter, the dark collar opening, a tall tongue,
// three white lace bars down the front and a dark heel tab. White slivers on the collar and the toe cap.
// Also used (recoloured) for ExtraEquip.
'use strict';

function shoe(k, K, c) {
	const U = 205, C = [256, 256];
	const P = ([u, v, cc]) => (cc ? [C[0] + u * U, C[1] + v * U, cc] : [C[0] + u * U, C[1] + v * U]);
	const S = (pts, t = 0.5) => K.smooth(pts.map(P), true, t);
	const RP = (pts, r) => K.roundPoly(pts.map(P), r * U);

	const upper = S([
		[-0.9, 0.36], [-0.95, 0.0], [-0.92, -0.42], [-0.84, -0.74], [-0.7, -0.84], [-0.46, -0.8], [-0.26, -0.78], [-0.18, -0.82],
		[0.12, -0.84], [0.16, -0.66], [0.26, -0.44], [0.46, -0.22], [0.72, -0.08], [0.9, 0.06], [0.98, 0.24], [0.96, 0.38],
	], 0.5);
	const sole = RP([[-1.0, 0.28], [0.99, 0.28], [1.01, 0.6], [-0.98, 0.6]], 0.12);
	const tread = RP([[-1.0, 0.49], [1.0, 0.49], [1.0, 0.6], [-0.98, 0.6]], 0.08);
	const toe = S([[0.34, 0.32], [0.4, 0.08], [0.56, -0.08], [0.76, -0.08], [0.92, 0.04], [0.99, 0.22], [0.98, 0.32]], 0.5);
	const heel = S([[-0.96, 0.3], [-0.95, -0.05], [-0.86, -0.3], [-0.62, -0.2], [-0.56, 0.05], [-0.6, 0.3]], 0.5);
	const tongue = RP([[-0.16, -0.98], [0.1, -1.0], [0.16, -0.7], [-0.12, -0.66]], 0.09);
	const collar = K.ellipse(...P([-0.46, -0.8]), 0.28 * U, 0.075 * U, 3);
	// lace bars: short white bars across the front edge (perpendicular to it)
	const lace = (t) => {
		const a = K.lerp([0.16, -0.62], [0.5, -0.2], t);
		const d = [0.42, 0.34], n = [-0.34 / 0.54, 0.42 / 0.54]; // along the edge, across it (down-left)
		const L = 0.24, W = 0.05;
		const p0 = [a[0] - n[0] * 0.02, a[1] - n[1] * 0.02], p1 = [a[0] + n[0] * L, a[1] + n[1] * L];
		const e = [d[0] / 0.54 * W, d[1] / 0.54 * W];
		return RP([[p0[0] - e[0], p0[1] - e[1]], [p0[0] + e[0], p0[1] + e[1]], [p1[0] + e[0], p1[1] + e[1]], [p1[0] - e[0], p1[1] - e[1]]], 0.045);
	};
	const tab = RP([[-0.99, -0.62], [-0.86, -0.66], [-0.82, -0.2], [-0.97, -0.18]], 0.06);

	let g = '';
	g += k.path(tongue, c.tongue);
	g += k.soft(tongue, RP([[-0.3, -0.75], [0.3, -0.75], [0.3, -0.5], [-0.3, -0.5]], 0.0), c.upperDark, 4, 0.8);
	g += k.path(upper, c.upper);
	g += k.soft(upper, S([[-1.2, 0.0], [1.2, 0.0], [1.2, 0.5], [-1.2, 0.5]]), c.upperDark, 10, 0.55);
	g += k.tiles(upper, [1, 0, 0, 1, 0, 0], [[-0.72, -0.62], [-0.44, -0.6], [-0.16, -0.58], [-0.76, -0.32], [-0.48, -0.32], [-0.2, -0.3], [0.06, -0.26], [-0.62, -0.06], [-0.34, -0.06], [-0.06, -0.04], [0.22, -0.02]]
		.map(([u, v]) => P([u, v])), { s: 0.22 * U, r: 0.05 * U, ...c.tiles });
	g += k.path(heel, c.heel);
	g += k.path(collar, c.collar);
	g += k.path(toe, c.white);
	g += k.soft(toe, K.ellipse(...P([0.75, 0.3]), 0.3 * U, 0.1 * U), c.whiteShade, 5, 0.8);
	for (const t of [0.12, 0.47, 0.82]) g += k.path(lace(t), c.white);
	g += k.clip(upper, k.path(tab, c.heel));
	// sole
	g += k.path(sole, c.white) + k.path(tread, c.tread);
	// a thin grey hint where the toe cap meets the sole
	g += k.line([P([0.36, 0.3]), P([0.7, 0.3]), P([0.97, 0.3])], c.whiteShade, 0.025 * U);
	g += k.soft(sole, RP([[-1.1, 0.38], [1.1, 0.38], [1.1, 0.5], [-1.1, 0.5]], 0), c.whiteShade, 3, 0.7);

	// highlights: one fat crescent on the collar's back, one sparkle on the toe cap
	g += k.streak([P([-0.62, -0.84]), P([-0.83, -0.72]), P([-0.9, -0.44])], 0.07 * U, { bias: 0.4, power: 0.7 });
	g += k.streak([P([0.52, -0.02]), P([0.7, -0.08]), P([0.88, -0.02])], 0.05 * U, { bias: 0.4, power: 0.6 });
	return { sil: [upper, sole, tongue, tab], body: g };
}

function starPath(k, c, r, color) {
	const pts = [];
	for (let i = 0; i < 10; i++) {
		const a = -Math.PI / 2 + (i * Math.PI) / 5, rr = i % 2 ? r * 0.45 : r;
		pts.push([c[0] + rr * Math.cos(a), c[1] + rr * Math.sin(a)]);
	}
	return `<path d="M${pts.map((p) => p.map((x) => x.toFixed(2)).join(' ')).join(' L')} Z" fill="${color}" stroke="${color}" stroke-width="${(r * 0.18).toFixed(2)}" stroke-linejoin="round"/>`;
}

const RED = {
	upper: '#e8343e', upperDark: '#c92430', heel: '#c8242f', tongue: '#ef4b52', collar: '#7d1019',
	white: '#f5f7fb', whiteShade: '#d5dce6', tread: '#a9b4c2', star: '#e8343e',
	tiles: { alpha: 0.13, bevel: 0.38, shadow: 0.2, shadowColor: '#5a0010' },
};
const BLUE = {
	upper: '#2f8cf0', upperDark: '#1f6fd0', heel: '#1f6bcc', tongue: '#45a0f5', collar: '#0d3577',
	white: '#f5f7fb', whiteShade: '#d5dce6', tread: '#a9b4c2', star: '#2f8cf0',
	tiles: { alpha: 0.13, bevel: 0.38, shadow: 0.2, shadowColor: '#082a60' },
};

module.exports = [{ name: 'Sneaker', draw: (k, K) => shoe(k, K, RED) }];
module.exports.shoe = shoe;
module.exports.COLORS = { RED, BLUE };
module.exports.starPath = starPath;
