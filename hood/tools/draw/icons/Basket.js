// Basket: a chunky shopping basket seen a little from above and turned a little onto its front-left corner. A thick
// light rim slab round a big well (the far inner walls show: the back one lit, the right one in shade), a body that
// tapers to a narrower flat base, and a wide flat grey-blue handle bar spanning left to right over the opening, its
// posts outside the side walls. One short fat crescent on the left rim corner, one sparkle on the front rim corner.
// BasketRed is the red store-window one, with subtle tiles on its walls.
'use strict';

function basket(k, K, c, o = {}) {
	const { yaw = 33, pitch = 33, a = 0.86, b = 0.92, w = 0.2, t = 0.17, h = 0.86, a2 = 0.68, b2 = 0.72, H = 0.62, hw = 0.13, th = 0.13, tiles = false, wicker = false, postIn = false, sparkle = true, axis = 'x' } = o;
	const P = K.camera({ yaw, pitch, s: 200, cx: 256, cy: 256 });
	const q = (pts) => K.poly(pts.map((p) => P(...p)));
	const quad = (y, aa, bb) => [[-aa, y, -bb], [aa, y, -bb], [aa, y, bb], [-aa, y, bb]]; // back-left, back-right, front-right, front-left
	const oT = quad(0, a, b), iT = quad(0, a - w, b - w), oL = quad(-t, a, b);
	const bT = quad(-t, a - 0.02, b - 0.02), bB = quad(-h, a2, b2);
	const fl = quad(-h + 0.12, a2 - w * 0.9, b2 - w * 0.9); // the floor inside

	// outer faces of a ring of 4 corners top (T) / bottom (B), wound outward
	const sides = (T, B) => ({
		left: [B[0], B[3], T[3], T[0]], front: [B[3], B[2], T[2], T[3]], right: [B[2], B[1], T[1], T[2]], back: [B[1], B[0], T[0], T[1]],
	});
	const body = sides(bT, bB), rim = sides(oT, oL);
	// inner wall faces of the well, wound to face inward
	const well = { back: [fl[0], fl[1], iT[1], iT[0]], right: [fl[1], fl[2], iT[2], iT[1]], front: [fl[2], fl[3], iT[3], iT[2]], left: [fl[3], fl[0], iT[0], iT[3]] };

	// handle boxes
	// axis 'x': the handle spans left to right (posts at the side walls); 'z': front to back (posts at the front and
	// back walls), so it runs from the near-left up to the far-right on screen
	const ext = axis === 'x' ? a : b;
	const xo = postIn ? ext - w / 2 - th / 2 : ext + 0.01, y0p = postIn ? 0 : -t;
	const bx = (u0, y0_, u1, y1_) => (axis === 'x' ? K.box3(u0, y0_, -hw, u1, y1_, hw) : K.box3(-hw, y0_, u0, hw, y1_, u1));
	const postR = bx(xo, y0p, xo + th, H);
	const postL = bx(-xo - th, y0p, -xo, H);
	const bar = bx(-xo - th, H, xo + th, H + th);
	const boxFaces = (bx, col) => Object.entries(bx).filter(([, f]) => P.front(f)).map(([n, f]) => k.path(q(f), col[n] || col.side)).join('');
	const hcol = axis === 'x' ? { top: c.handleTop, front: c.handle, left: c.handleSide, right: c.handleSide, side: c.handleSide }
		: { top: c.handleTop, right: c.handle, front: c.handleSide, back: c.handleSide, left: c.handle, side: c.handleSide };

	const faceCol = { left: c.left, front: c.right, right: c.left, back: c.right, ...(c.faceCol || {}) };
	const rimCol = { left: c.rimSideL, front: c.rimSideR, right: c.rimSideL, back: c.rimSideR, ...(c.rimCol || {}) };
	let g = '';
	const far = axis === 'x' ? postR : postL, near = axis === 'x' ? postL : postR;
	if (!postIn) g += boxFaces(far, hcol);
	for (const n of ['left', 'front', 'right', 'back']) if (P.front(body[n])) {
		const d = q(body[n]);
		g += k.path(d, faceCol[n]);
		// a darker band just under the rim slab
		g += k.soft(d, q(sides(quad(-t + 0.03, 2, 2), quad(-t - 0.14, 2, 2))[n]), n === 'left' ? c.leftDark : c.rightDark, 4, 0.75);
		if (tiles && !wicker) g += k.tiles(d, K.faceM(P, body[n]), k.grid(0.07, t + 0.07, 4, 3, 0.42), { s: 0.33, r: 0.07, ...c.tiles, blurSd: 0.006 });
		if (wicker) {
			// a dense wicker grid of small squares down the body
			const [fw, fh] = K.faceSize(body[n]);
			const pw = 0.17, nw = Math.floor((fw - 0.02) / pw), nv = Math.ceil(fh / pw);
			g += k.tiles(d, K.faceM(P, body[n]), k.grid((fw - nw * pw + 0.03) / 2, 0.03, nw, nv, pw), { s: 0.135, r: 0.03, ...c.wicker, blurSd: 0.004 });
		}
	}
	for (const n of ['left', 'front', 'right', 'back']) if (P.front(rim[n])) {
		g += k.path(q(rim[n]), rimCol[n]);
		if (wicker) {
			// the thick rim band carries the big studs
			const [fw, fh] = K.faceSize(rim[n]);
			const pw = 0.27, nb = Math.floor((fw - 0.02) / pw);
			g += k.tiles(q(rim[n]), K.faceM(P, rim[n]), k.grid((fw - nb * pw + 0.05) / 2, (fh - 0.2) / 2, nb, 1, pw), { s: 0.2, r: 0.05, ...c.tiles, blurSd: 0.006 });
		}
	}
	// the well: floor, then the inner walls that face the eye, clipped to the opening
	const opening = q(iT);
	let inside = k.path(q(fl), c.floor);
	for (const n of ['back', 'right', 'front', 'left']) if (P.front(well[n])) inside += k.path(q(well[n]), n === 'right' ? c.inRight : c.inBack);
	inside += k.soft(opening, q(quad(-h + 0.12, a2, b2)), c.inShade, 10, 0.5);
	if (tiles) for (const n of ['back', 'right']) if (P.front(well[n])) inside += k.tiles(q(well[n]), K.faceM(P, well[n]), k.grid(0.08, 0.06, 4, 2, 0.4), { s: 0.31, r: 0.07, ...c.tiles, blurSd: 0.006 });
	g += k.clip(opening, inside);
	// the rim top: a thick light frame round the opening, its far half a touch darker
	const frame = `${q(oT)} ${q(iT.slice().reverse())}`;
	g += `<path d="${frame}" fill="${c.rim}" fill-rule="evenodd"/>`;
	g += k.clip(frame, k.path(q([oT[0], oT[1], oT[2], iT[2], iT[1], iT[0]]), c.rimFar), ' clip-rule="evenodd"');
	// handle bar and the posts
	if (postIn) g += boxFaces(far, hcol);
	g += boxFaces(bar, hcol) + boxFaces(near, hcol);
	if (tiles) {
		const tf = bar.top;
		const [bw, bl] = K.faceSize(tf);
		const nst = Math.floor(bl / 0.27);
		g += k.tiles(q(tf), K.faceM(P, tf), k.grid(bw * 0.12, (bl - nst * 0.27 + 0.05) / 2, 1, nst, 0.27), { s: bw * 0.76, r: 0.04, ...c.handleTiles, blurSd: 0.006 });
	}

	// highlights: white wedges on the rim corners (the leftmost one and the one nearest the eye), a sliver down the
	// near vertical edge; the HUD one also has the ref's sparkle on the near rim corner
	const order = [0, 1, 2, 3].sort((i, j) => P.depth(...oT[j]) - P.depth(...oT[i]));
	const ni = order[0];
	const li = [0, 1, 2, 3].sort((i, j) => P(...oT[i])[0] - P(...oT[j])[0])[0];
	const wedgeAt = (i, len, wd) => {
		const c0 = oT[i], cp = oT[(i + 3) % 4], cn = oT[(i + 1) % 4];
		const toward = (p, q, d) => { const L = Math.hypot(q[0] - p[0], q[2] - p[2]); return [p[0] + ((q[0] - p[0]) / L) * d, 0, p[2] + ((q[2] - p[2]) / L) * d]; };
		return k.streak([P(...toward(c0, cp, len)), P(...c0), P(...toward(c0, cn, len))], wd * 200, { bias: 0.5, power: 0.6 });
	};
	g += wedgeAt(li, 0.36, 0.06);
	g += wedgeAt(ni, 0.3, 0.055);
	const nb = bT[ni], nbb = bB[ni];
	g += k.streak([P(...oT[ni]), P(nb[0], -t - 0.05, nb[2]), P(...K.lerp([nb[0], nb[2]], [nbb[0], nbb[2]], 0.45).flatMap((v, j) => (j === 0 ? [v, -t - (h - t) * 0.45] : [v])))], 0.045 * 200, { bias: 0.15, power: 0.55 });
	const fc = P(...oT[ni]);
	if (sparkle) g += k.flare(fc[0], fc[1] + 4, 0.2 * 200, 0.2 * 200, 0, '#ffffff', 0.16);

	const sil = [q(oT), ...Object.values(rim).map(q), ...Object.values(body).map(q),
		...[postL, postR, bar].flatMap((bx) => Object.values(bx).map(q))];
	return { sil, body: g };
}

const ORANGE = {
	// the big front face light orange, the side facet darker; a pale-yellow rim band
	faceCol: { front: '#ffa628', right: '#fb8a22' }, rimCol: { front: '#ffc93c', right: '#fdb630' },
	rim: '#ffde5c', rimFar: '#ffd04a', rimSideL: '#ffad2a', rimSideR: '#ff9a25',
	left: '#ffa526', leftDark: '#fb8f22', right: '#ff9323', rightDark: '#f77c1f',
	inBack: '#ff9a2a', inRight: '#fb7b24', floor: '#f7751f', inShade: '#f06b1c',
	handle: '#7ea7bf', handleTop: '#aacadb', handleSide: '#6890a9',
	tiles: { alpha: 0.13, bevel: 0.35, shadow: 0.15, shadowColor: '#8a3a00' },
};
const RED = {
	rim: '#ff7d9a', rimFar: '#f86a8a', rimSideL: '#f0507a', rimSideR: '#e2406a',
	left: '#ec3d63', leftDark: '#d42d55', right: '#d72b53', rightDark: '#be1f47',
	inBack: '#e2355b', inRight: '#c4244a', floor: '#b31f43', inShade: '#a01a3b',
	handle: '#b4c3d1', handleTop: '#dbe4ec', handleSide: '#97a8b8',
	tiles: { alpha: 0.2, bevel: 0.45, shadow: 0.2, shadowColor: '#5a0018' },
	handleTiles: { alpha: 0.12, bevel: 0.5, shadow: 0.3, shadowColor: '#5d7080' },
	wicker: { alpha: 0.16, bevel: 0.25, shadow: 0.25, shadowColor: '#5a0018' },
};

module.exports = [
	{ name: 'Basket', draw: (k, K) => basket(k, K, ORANGE, { yaw: -34, pitch: 30, a: 0.84, b: 0.96, w: 0.21, t: 0.22, h: 1.3, a2: 0.56, b2: 0.66, H: 0.5, hw: 0.08, th: 0.1, axis: 'z' }) },
	{ name: 'BasketRed', draw: (k, K) => basket(k, K, RED, { tiles: true, wicker: true, sparkle: false, yaw: 32, pitch: 30, a: 1.02, b: 0.8, w: 0.25, t: 0.28, h: 0.9, a2: 0.88, b2: 0.68, H: 0.62, hw: 0.15, th: 0.17, postIn: true }) },
];
