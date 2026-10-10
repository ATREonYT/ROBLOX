// Cash: a fat stack of green dollar bills seen 3/4 from above, a cream paper band round its middle, the top bill's
// oval "$" emblem, the layered bill edges on the sides, and a big gold "$" coin leaning on the front-left.
// Also exports the bill stack and the coin for the Store's cash packs.
'use strict';

// "$" in a unit box centred on (0, 0) (y down), as stroke paths
function dollar(k, m, color, w = 0.17) {
	return `<g transform="matrix(${m.map((x) => (Math.round(x * 1000) / 1000)).join(' ')})" fill="none" stroke="${color}" stroke-linecap="round" stroke-linejoin="round">` +
		`<path d="M0.27 -0.26 C0.18 -0.38 -0.3 -0.42 -0.29 -0.14 C-0.28 0.07 0.29 -0.03 0.29 0.18 C0.29 0.44 -0.2 0.42 -0.3 0.27" stroke-width="${w}"/>` +
		`<path d="M0 -0.5 L0 0.5" stroke-width="${w * 0.8}"/></g>`;
}

// a stack of bills: x along the bill, z across, y up. Returns { sil, g }.
function stack(k, K, P, { x0 = -1, x1 = 1, z0 = -0.5, z1 = 0.5, y0 = 0, y1 = 0.45, band = true, emblem = true } = {}) {
	const q = (pts) => K.poly(pts.map((p) => P(...p)));
	const bx = K.box3(x0, y0, z0, x1, y1, z1);
	const col = { top: '#58cf52', left: '#35a336', right: '#35a336', front: '#41b33f', back: '#41b33f' };
	let g = '';
	const vis = Object.entries(bx).filter(([, f]) => P.front(f));
	for (const [n, f] of vis) {
		const d = q(f);
		g += k.path(d, col[n] || '#46b844');
		if (n !== 'top') {
			// layered bill edges: light lines along the side
			const [w, h] = K.faceSize(f);
			let lines = '';
			const nl = Math.max(2, Math.round(h / 0.11));
			for (let i = 1; i < nl; i++) lines += `<path d="M0 ${(i * h) / nl} L${w} ${(i * h) / nl}" stroke="#8fe58a" stroke-width="0.035" fill="none"/>`;
			g += k.clip(d, `<g transform="matrix(${K.faceM(P, f).join(' ')})">${lines}</g>`);
		}
	}
	// the top bill: a darker inset border and the oval emblem with "$"
	const top = bx.top;
	const M = K.faceM(P, [top[1], top[2], top[3], top[0]]); // u along +x, v along +z... (p3 = top[0] corner)
	const W = x1 - x0, D = z1 - z0;
	let face = `<rect x="0.08" y="0.07" width="${W - 0.16}" height="${D - 0.14}" rx="0.05" fill="none" stroke="#3ea83c" stroke-width="0.045"/>`;
	const ex = W * 0.27;
	if (emblem) face += `<ellipse cx="${ex}" cy="${D / 2}" rx="${D * 0.34}" ry="${D * 0.3}" fill="#43b041"/>` +
		`<ellipse cx="${ex}" cy="${D / 2}" rx="${D * 0.25}" ry="${D * 0.21}" fill="#86e57e"/>` +
		`<ellipse cx="${W - ex}" cy="${D / 2}" rx="${D * 0.16}" ry="${D * 0.14}" fill="#43b041"/>`;
	g += `<g transform="matrix(${M.join(' ')})">${face}</g>`;
	if (emblem) {
		const c = [ex, D / 2];
		const m2 = [M[0] * 0.34, M[1] * 0.34, M[2] * 0.34, M[3] * 0.34, M[0] * c[0] + M[2] * c[1] + M[4], M[1] * c[0] + M[3] * c[1] + M[5]];
		g += dollar(k, m2, '#2e9a33', 0.2);
	}
	g += k.tiles(q(top), M, [[W * 0.62, 0.1], [W - 0.42, D - 0.42]], { s: 0.3, r: 0.07, alpha: 0.1, bevel: 0.35, shadow: 0.15, shadowColor: '#0a4a10', blurSd: 0.01 });
	// paper band round the middle
	let sil = Object.values(bx).map(q);
	if (band) {
		const bw = 0.17 * W / 2;
		const bb = K.box3(-bw + (x0 + x1) / 2, y0 - 0.005, z0 - 0.025, bw + (x0 + x1) / 2, y1 + 0.025, z1 + 0.025);
		const bc = { top: '#fbf0c4', front: '#e9d79a', back: '#e9d79a', left: '#f2e2a8', right: '#f2e2a8' };
		for (const [n, f] of Object.entries(bb)) if (P.front(f) && n !== 'bottom') g += k.path(q(f), bc[n]);
		sil = sil.concat(Object.values(bb).map(q));
	}
	return { sil, g };
}

// a gold coin standing up, facing (nx: turned about y by yaw degrees), centre (cx, cy, cz), radius r
function coin(k, K, P, { c = [0, 0, 0], r = 0.42, th = 0.1, yaw = -30, tilt = 0 } = {}) {
	const a = (yaw * Math.PI) / 180, t = (tilt * Math.PI) / 180;
	// face basis: u (right in the coin) and v (up), normal n toward the viewer-ish
	const u = [Math.cos(a), 0, -Math.sin(a)];
	const v = [Math.sin(a) * Math.sin(t), Math.cos(t), Math.cos(a) * Math.sin(t)];
	const n = [u[1] * v[2] - u[2] * v[1], u[2] * v[0] - u[0] * v[2], u[0] * v[1] - u[1] * v[0]];
	const ring = (off, rr) => {
		const pts = [];
		for (let i = 0; i < 48; i++) {
			const ang = (i / 48) * Math.PI * 2;
			pts.push(P(...[0, 1, 2].map((j) => c[j] + n[j] * off + (u[j] * Math.cos(ang) + v[j] * Math.sin(ang)) * rr)));
		}
		return pts;
	};
	const front = ring(th / 2, r), back = ring(-th / 2, r);
	// the edge: the hull of both rims
	const hull = (pts) => {
		const p = pts.slice().sort((A, B) => A[0] - B[0] || A[1] - B[1]);
		const cr = (o, A, B) => (A[0] - o[0]) * (B[1] - o[1]) - (A[1] - o[1]) * (B[0] - o[0]);
		const lo = [], up = [];
		for (const x of p) { while (lo.length >= 2 && cr(lo[lo.length - 2], lo[lo.length - 1], x) <= 0) lo.pop(); lo.push(x); }
		for (const x of p.reverse()) { while (up.length >= 2 && cr(up[up.length - 2], up[up.length - 1], x) <= 0) up.pop(); up.push(x); }
		return lo.slice(0, -1).concat(up.slice(0, -1));
	};
	const edge = K.poly(hull(front.concat(back)));
	const faceD = K.smooth(front, true, 0.5);
	const inner = K.smooth(ring(th / 2, r * 0.74), true, 0.5);
	let g = k.path(edge, '#e8920e');
	g += k.path(faceD, '#ffc824');
	g += k.path(inner, '#f5ad18');
	// the "$" on the face
	const o = P(...c.map((x, j) => x + n[j] * th / 2));
	const pu = P(...c.map((x, j) => x + n[j] * th / 2 + u[j]));
	const pv = P(...c.map((x, j) => x + n[j] * th / 2 - v[j]));
	const sc = r * 0.95;
	g += dollar(k, [(pu[0] - o[0]) * sc, (pu[1] - o[1]) * sc, (pv[0] - o[0]) * sc, (pv[1] - o[1]) * sc, o[0], o[1]], '#e08a0c', 0.2);
	return { sil: [edge, faceD], g, faceD, front };
}

module.exports = [
	{
		name: 'Cash',
		draw(k, K) {
			const P = K.camera({ yaw: 24, pitch: 38, s: 190, cx: 256, cy: 256 });
			const st = stack(k, K, P, { x0: -0.9, x1: 0.9, z0: -0.55, z1: 0.55, y0: -0.36, y1: 0.3 });
			const cn = coin(k, K, P, { c: [0.72, -0.06, 0.78], r: 0.5, th: 0.13, yaw: -18, tilt: -8 });
			let g = st.g + cn.g;
			// highlights: a sliver along the stack's top-left edge, a wedge on the coin's rim
			g += k.streak([P(-0.45, 0.3, -0.53), P(-0.88, 0.3, -0.53), P(-0.88, 0.3, -0.05)], 0.06 * 190, { bias: 0.5, power: 0.7 });
			// a white wedge on the coin's upper-left rim
			const a0 = cn.front;
			g += k.streak([a0[14], a0[17], a0[20], a0[23]], 0.05 * 190, { bias: 0.5, power: 0.6 });
			return { sil: st.sil.concat(cn.sil), body: g };
		},
	},
];
module.exports.stack = stack;
module.exports.coin = coin;
module.exports.dollar = dollar;
