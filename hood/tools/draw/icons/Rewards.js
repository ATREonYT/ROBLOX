// Rewards: a short wide pink gift box seen corner-on from a little above, with a clear lid (a slightly bigger box with
// a thick rim), wide yellow ribbon strips down the middle of each side and across the lid, and a big wide two-tone bow
// on top: light-yellow outer loops round dark-orange insides, a big yellow oval knot and two short wedge tails lying
// on the front faces. Big soft studs; thin white slivers on the lid's left edge and corner.
'use strict';

module.exports = {
	name: 'Rewards',
	draw(k, K) {
		const s = 172;
		const P = K.camera({ yaw: 45, pitch: 24, s, cx: 256, cy: 270 });
		const q = (pts) => K.poly(pts.map((p) => P(...p)));
		const A = 0.8; // half size of the box
		const y0 = -0.66, y1 = 0.2, L = 0.06, yl = 0.46; // box bottom / top, lid overhang, lid top
		const box = K.box3(-A, y0, -A, A, y1, A);
		const lid = K.box3(-A - L, y1 - 0.02, -A - L, A + L, yl, A + L);
		const rb = 0.3; // ribbon half width
		const faces = (bx, c) => Object.entries(bx).filter(([, fc]) => P.front(fc)).map(([n, fc]) => ({ n, fc, d: q(fc), fill: c[n] }));
		const strip = (n, ya, yb, e) => (n === 'front'
			? [[-rb, ya, A + e], [rb, ya, A + e], [rb, yb, A + e], [-rb, yb, A + e]]
			: [[-A - e, ya, -rb], [-A - e, ya, rb], [-A - e, yb, rb], [-A - e, yb, -rb]]);
		const studs = (f, rows, v0, col) => {
			const [w] = K.faceSize(f.fc);
			const cells = [];
			for (let j = 0; j < rows; j++) for (let i = 0; i < 4; i++) cells.push([0.08 + i * 0.42, v0 + j * 0.4]);
			return k.tiles(f.d, K.faceM(P, f.fc), cells.filter(([u]) => u < w - 0.2), { s: 0.32, r: 0.07, alpha: 0.13, bevel: 0.36, shadow: 0.24, shadowColor: col, blurSd: 0.006 });
		};

		let g = '';
		// box
		for (const f of faces(box, { left: '#ee4570', front: '#cf2554' })) {
			g += k.path(f.d, f.fill) + studs(f, 2, 0.24, '#5a0020');
			g += k.path(q(strip(f.n, y0, y1, 0.005)), f.n === 'front' ? '#f39c1f' : '#ffb92c');
		}
		// lid: thick rim faces, then the top
		for (const f of faces(lid, { left: '#f86890', front: '#e03a68', top: '#f78fb0' })) {
			g += k.path(f.d, f.fill);
			if (f.n !== 'top') g += k.path(q(strip(f.n, y1 - 0.02, yl, 0.005)), f.n === 'front' ? '#f8a823' : '#ffc436');
		}
		g += k.path(q([[-rb, yl, -A - L], [rb, yl, -A - L], [rb, yl, A + L], [-rb, yl, A + L]]), '#ffd24a');
		g += k.path(q([[-A - L, yl, -rb], [A + L, yl, -rb], [A + L, yl, rb], [-A - L, yl, rb]]), '#ffd24a');

		// the bow (drawn flat, by eye), centred over the lid's middle
		const c = P(0, yl, 0);
		const bs = 1.26 * s;
		const B = (u, v) => [c[0] + u * bs, c[1] + v * bs];
		const Sm = (pts, t = 0.5) => K.smooth(pts.map(([u, v]) => B(u, v)), true, t);
		const loopL = Sm([[-0.12, 0.0], [-0.44, 0.1], [-0.82, 0.04], [-0.98, -0.2], [-0.9, -0.5], [-0.62, -0.62], [-0.32, -0.46], [-0.14, -0.2]]);
		const loopLin = Sm([[-0.22, -0.06], [-0.46, 0.0], [-0.74, -0.06], [-0.8, -0.24], [-0.68, -0.42], [-0.44, -0.38], [-0.26, -0.2]]);
		const loopR = Sm([[0.12, 0.0], [0.44, 0.1], [0.82, 0.04], [0.98, -0.2], [0.9, -0.5], [0.62, -0.62], [0.32, -0.46], [0.14, -0.2]]);
		const loopRin = Sm([[0.22, -0.06], [0.46, 0.0], [0.74, -0.06], [0.8, -0.24], [0.68, -0.42], [0.44, -0.38], [0.26, -0.2]]);
		// short wedge tails lying on the two front faces
		const tailL = K.poly([B(-0.18, -0.02), B(0.0, 0.06), B(-0.16, 0.4), B(-0.27, 0.32), B(-0.4, 0.38)]);
		const tailR = K.poly([B(0.0, 0.06), B(0.18, -0.02), B(0.4, 0.36), B(0.27, 0.31), B(0.16, 0.4)]);
		const knot = K.ellipse(...B(0, -0.1), 0.26 * bs, 0.2 * bs);
		g += k.path(tailL, '#f0a022') + k.path(tailR, '#ffc72e');
		g += k.path(loopL, '#ffd65e') + k.path(loopLin, '#f9921c');
		g += k.soft(loopLin, Sm([[-0.3, 0.0], [-0.8, 0.0], [-0.8, -0.18], [-0.3, -0.2]]), '#e8790f', 5, 0.8);
		g += k.path(loopR, '#ffd65e') + k.path(loopRin, '#f9921c');
		g += k.soft(loopRin, Sm([[0.3, 0.0], [0.8, 0.0], [0.8, -0.18], [0.3, -0.2]]), '#e8790f', 5, 0.8);
		g += k.path(knot, '#ffe766');
		g += k.soft(knot, K.ellipse(...B(0.08, 0.0), 0.2 * bs, 0.1 * bs), '#ffcb3a', 5, 0.8);
		const bowTiles = (d, pts, sz = 0.2) => k.tiles(d, [1, 0, 0, 1, 0, 0], pts.map(([u, v]) => B(u - sz / 2, v - sz / 2)), { s: sz * bs, r: 0.045 * bs, alpha: 0.16, bevel: 0.4, shadow: 0.22, shadowColor: '#8a4200', blurSd: 1.2 });
		g += bowTiles(loopL, [[-0.86, -0.36], [-0.58, -0.5]]) + bowTiles(loopR, [[0.86, -0.36], [0.58, -0.5]]) + bowTiles(knot, [[0.0, -0.12]], 0.22);

		// thin white slivers: down the lid's left edge, along the lid's left top edge
		g += k.streak([P(-A - L, yl - 0.02, -A - L), P(-A - L, yl - 0.13, -A - L), P(-A - L, y1 + 0.02, -A - L)], 0.06 * s, { bias: 0.25, power: 0.55 });
		g += k.streak([P(-A - L, yl, -A + 0.3), P(-A - L, yl, -A - L), P(-A + 0.3, yl, -A - L)], 0.05 * s, { bias: 0.5, power: 0.6 });

		const sil = [...Object.values(box).map(q), ...Object.values(lid).map(q), loopL, loopR, knot, tailL, tailR];
		return { sil, body: g };
	},
};
