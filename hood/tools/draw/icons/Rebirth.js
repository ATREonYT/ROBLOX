// Rebirth: two thick C-arrows chasing round a big round see-through centre, red over the top (its head at 3 o'clock
// pointing down, the outer barb jutting out at the top right) and white under the bottom (its big wedge head jutting
// out at 9 o'clock). The ring is a thick slab seen from a little above: the walls that face the viewer (the red arch's
// outer wall along the top, the white head's thick top / left faces, the white inner wall curling into the hole) are
// chunky ribbed bands. Big soft studs; thin white slivers on the edges. RebirthSkip is the same ring with green.
'use strict';

function ring(k, K, colA, colB) {
	const U = 205;
	const C0 = [256, 256];
	const P = (p) => [C0[0] + p[0] * U, C0[1] + p[1] * U];
	const Ro = 0.86, Ri = 0.45;
	const o = [-0.04 * U, -0.24 * U]; // the slab's back face: up, a little to the left
	const rot = (p) => [-p[0], -p[1]];

	// the white arrow (bottom), in units; the red one is the same turned half round
	const tipW = [-0.99, -0.2], bW = [-0.15, 0.24], oW = [-0.88, 0.86];
	// the head's top edge (the red / white split) runs from the tip to the inner barb with a slight wobble
	const white = [tipW, [-0.76, -0.1], [-0.5, 0.05], [-0.32, 0.14], bW]
		.concat(K.arc([0, 0], Ri, 123, -16, 4))
		.concat(K.arc([0, 0], Ro, -16, 131, 3))
		.concat([oW, [-0.93, 0.27]]);
	const red = white.map(rot);
	red[2] = [0.74, 0.12]; red[3] = [0.5, -0.04]; // the red head's split wobbles the other way
	const W = white.map(P), R = red.map(P);
	const Wx = K.extrude(W, o), Rx = K.extrude(R, o);

	// chains of consecutive visible wall edges -> band polygons
	function chains(x, pts) {
		const out = [];
		let cur = null, last = -2;
		for (const w of x.walls) {
			if (w.i !== last + 1 || !cur) { cur = []; out.push(cur); }
			cur.push(w);
			last = w.i;
		}
		// join a chain that wraps round the end of the polygon
		if (out.length > 1 && out[0][0].i === 0 && out[out.length - 1].slice(-1)[0].i === pts.length - 1) {
			out[0] = out.pop().concat(out[0]);
		}
		return out;
	}
	function wallArt(x, pts, base, seg, pitch) {
		let g = '';
		for (const ch of chains(x, pts)) {
			const front = [ch[0].p].concat(ch.map((w) => w.q));
			const back = [ch[0].po].concat(ch.map((w) => w.qo));
			g += k.path(K.poly(front.concat(back.slice().reverse())), base);
			// segments: lighter quads along the chain
			const L = [0];
			for (let i = 1; i < front.length; i++) L.push(L[i - 1] + Math.hypot(front[i][0] - front[i - 1][0], front[i][1] - front[i - 1][1]));
			const total = L[L.length - 1];
			if (total < pitch * 0.6) continue;
			const at = (s, arr) => {
				let i = 1;
				while (i < L.length - 1 && L[i] < s) i++;
				const t = (s - L[i - 1]) / Math.max(1e-6, L[i] - L[i - 1]);
				return K.lerp(arr[i - 1], arr[i], Math.max(0, Math.min(1, t)));
			};
			const nseg = Math.max(1, Math.round(total / pitch));
			const step = total / nseg;
			for (let s = 0; s < nseg; s++) {
				const s0 = s * step + step * 0.16, s1 = (s + 1) * step - step * 0.16;
				const q = [];
				const n = 6;
				for (let j = 0; j <= n; j++) q.push(K.lerp(at(s0 + ((s1 - s0) * j) / n, front), at(s0 + ((s1 - s0) * j) / n, back), 0.16));
				for (let j = n; j >= 0; j--) q.push(K.lerp(at(s0 + ((s1 - s0) * j) / n, front), at(s0 + ((s1 - s0) * j) / n, back), 0.84));
				g += `<path d="${K.poly(q)}" fill="${seg}" ${k.blur(0.6)}/>`;
				// a light top edge on each rib
				const t = [];
				for (let j = 0; j <= n; j++) t.push(K.lerp(at(s0 + ((s1 - s0) * j) / n, front), at(s0 + ((s1 - s0) * j) / n, back), 0.82));
				for (let j = n; j >= 0; j--) t.push(K.lerp(at(s0 + ((s1 - s0) * j) / n, front), at(s0 + ((s1 - s0) * j) / n, back), 0.68));
				g += `<path d="${K.poly(t)}" fill="#ffffff" opacity="0.28" ${k.blur(0.6)}/>`;
			}
		}
		return g;
	}
	const faceTiles = (face, fill) => {
		const cells = [];
		for (let j = -5; j <= 5; j++) for (let i = -5; i <= 5; i++) cells.push([i * 0.32 * U, j * 0.32 * U]);
		return k.tiles(face, [1, 0, 0, 1, 256 - 0.12 * U, 256 - 0.1 * U], cells, { s: 0.25 * U, r: 0.06 * U, ...fill });
	};

	function arrow(x, pts, col) {
		const face = K.poly(pts);
		let g = wallArt(x, pts, col.wall, col.seg, 0.27 * U);
		g += k.path(face, col.face);
		// soft shading: a lighter top-left, a slightly darker lower right
		g += k.soft(face, K.circle(256 - 0.45 * U, 256 - 0.55 * U, 0.75 * U), col.lit, 22, 0.55);
		g += k.soft(face, K.circle(256 + 0.65 * U, 256 + 0.7 * U, 0.7 * U), col.shade, 26, 0.5);
		g += faceTiles(face, col.tiles);
		return g;
	}

	let b = '';
	b += arrow(Rx, R, colA);
	b += arrow(Wx, W, colB);
	// the red head lies over the white tail: redraw the right half of the red arrow on top
	b += k.clip(K.rect(256 + 0.12 * U, 0, 512, 512), arrow(Rx, R, colA));

	// highlights: thin white slivers on the edges (the red barb's outer edge, the white head's tip edge)
	b += k.streak([P([0.52, -0.84]), P([0.68, -0.79]), P([0.86, -0.72])], 0.05 * U, { bias: 0.75, power: 0.6 });
	b += k.streak([P([-1.0, -0.2]), P([-0.86, -0.13]), P([-0.7, -0.05])], 0.05 * U, { bias: 0.2, power: 0.6 });
	b += k.streak([P([-0.84, -0.32]), P([-0.7, -0.54]), P([-0.5, -0.7])], 0.03 * U, { bias: 0.5, power: 0.7, opacity: 0.75 });

	const sil = [K.poly(W), K.poly(Wx.back), K.poly(R), K.poly(Rx.back)];
	for (const x of [Wx, Rx]) for (const w of x.walls) sil.push(K.poly([w.p, w.q, w.qo, w.po]));
	// the see-through centre: a big round hole in a dark core (the inside of the tube); the barbs poke into the core
	const hc = P([0, -0.05]);
	const hole = K.circle(hc[0], hc[1], 0.19 * U);
	const mid = k.id('m');
	k.def(`<mask id="${mid}" maskUnits="userSpaceOnUse" x="0" y="0" width="512" height="512"><rect width="512" height="512" fill="#fff"/>` +
		`<path d="${K.poly(W)}" fill="#000"/><path d="${K.poly(R)}" fill="#000"/></mask>`);
	b += `<path d="${K.circle(hc[0], hc[1], 0.31 * U)}" fill="${k.NAVY}" mask="url(#${mid})"/>`;
	return { sil, body: b, holes: [{ d: hole, ink: 0 }] };
}

const RED = {
	face: '#f03458', wall: '#b80838', seg: '#ee5276', lit: '#f6587a', shade: '#e0284c',
	tiles: { alpha: 0.13, bevel: 0.32, shadow: 0.24, shadowColor: '#8a0428', blurSd: 1.2 },
};
const WHITE = {
	face: '#e8f7fd', wall: '#8fc4da', seg: '#c4e6f2', lit: '#ffffff', shade: '#d3ecf6',
	tiles: { alpha: 0.35, bevel: 0.5, shadow: 0.24, shadowColor: '#5b98b6', blurSd: 1.2 },
};
const GREEN = {
	face: '#46c84a', wall: '#1d8a28', seg: '#4ac24e', lit: '#66de68', shade: '#38b33c',
	tiles: { alpha: 0.13, bevel: 0.32, shadow: 0.24, shadowColor: '#0c5a18', blurSd: 1.2 },
};

module.exports = [
	{ name: 'Rebirth', draw: (k, K) => ring(k, K, RED, WHITE) },
	{ name: 'RebirthSkip', draw: (k, K) => ring(k, K, GREEN, WHITE) },
];
