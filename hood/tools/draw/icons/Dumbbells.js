// The Store's power packs and DoublePower: chunky red dumbbells (a grey bar between two stacks of round red plates
// with soft studs on their faces), seen 3/4 from above; one, two, a small rack and a big glowing pile (with the ref's
// big white sparkles). DoublePower is the golden flexed arm with a lightning bolt.
'use strict';

const { arm } = require('./Power');
const { bolt } = require('./CashPacks');

// a cylinder between centres a and b (world), radius r: { sil, g } with its visible end cap shaded `face`
function cyl(k, K, P, a, b, r, cols, { studs = 0 } = {}) {
	const ax = [b[0] - a[0], b[1] - a[1], b[2] - a[2]];
	const L = Math.hypot(...ax);
	const n = ax.map((x) => x / L);
	// a basis (u, v) across the axis
	const up = Math.abs(n[1]) < 0.9 ? [0, 1, 0] : [1, 0, 0];
	let u = [n[1] * up[2] - n[2] * up[1], n[2] * up[0] - n[0] * up[2], n[0] * up[1] - n[1] * up[0]];
	const lu = Math.hypot(...u); u = u.map((x) => x / lu);
	const v = [n[1] * u[2] - n[2] * u[1], n[2] * u[0] - n[0] * u[2], n[0] * u[1] - n[1] * u[0]];
	const ring = (c, rr) => {
		const pts = [];
		for (let i = 0; i < 48; i++) {
			const t = (i / 48) * Math.PI * 2;
			pts.push(P(...[0, 1, 2].map((j) => c[j] + (u[j] * Math.cos(t) + v[j] * Math.sin(t)) * rr)));
		}
		return pts;
	};
	const ra = ring(a, r), rb = ring(b, r);
	const p = ra.concat(rb).sort((A, B) => A[0] - B[0] || A[1] - B[1]);
	const cr = (o, A, B) => (A[0] - o[0]) * (B[1] - o[1]) - (A[1] - o[1]) * (B[0] - o[0]);
	const lo = [], hi = [];
	for (const x of p) { while (lo.length >= 2 && cr(lo[lo.length - 2], lo[lo.length - 1], x) <= 0) lo.pop(); lo.push(x); }
	for (const x of p.reverse()) { while (hi.length >= 2 && cr(hi[hi.length - 2], hi[hi.length - 1], x) <= 0) hi.pop(); hi.push(x); }
	const hull = K.poly(lo.slice(0, -1).concat(hi.slice(0, -1)));
	// the visible end: the one whose outward normal faces the eye
	const endB = P.faces(n);
	const cap = endB ? b : a;
	const capD = K.smooth(endB ? rb : ra, true, 0.5);
	let g = k.path(hull, cols.side);
	// a lighter band along the top of the side
	g += k.soft(hull, K.poly([P(...a.map((x, j) => x + v[j] * r * 1.6 + u[j] * 0)), P(...b.map((x, j) => x + v[j] * r * 1.6)), P(...b.map((x, j) => x + v[j] * r * 0.4)), P(...a.map((x, j) => x + v[j] * r * 0.4))]), cols.sideLit, 3, 0.7);
	g += k.path(capD, cols.face);
	if (cols.inner) g += k.path(K.smooth(ring(cap, r * 0.62), true, 0.5), cols.inner);
	if (cols.hole) g += k.path(K.smooth(ring(cap, r * 0.2), true, 0.5), cols.hole);
	if (studs) {
		// soft studs round the face
		const sp = [];
		for (let i = 0; i < studs; i++) {
			const t = (i / studs) * Math.PI * 2 + 0.4;
			sp.push(P(...[0, 1, 2].map((j) => cap[j] + (u[j] * Math.cos(t) + v[j] * Math.sin(t)) * r * 0.8)));
		}
		const sz = r * 0.32 * (P(1, 0, 0)[0] - P(0, 0, 0)[0] ? 1 : 1);
		const px = Math.hypot(P(...u)[0] - P(0, 0, 0)[0], P(...u)[1] - P(0, 0, 0)[1]) * sz;
		g += k.tiles(capD, [1, 0, 0, 1, 0, 0], sp.map(([x, y]) => [x - px / 2, y - px / 2]), { s: px, r: px * 0.25, ...cols.tiles });
	}
	return { sil: [hull], g, capD, endB };
}

// one dumbbell along x, centred at the origin, drawn with camera P; returns { sil, body }
function dumbbell(k, K, P, cols = RED) {
	const bar = cyl(k, K, P, [-0.95, 0, 0], [0.95, 0, 0], 0.1, BAR);
	const plates = [
		[-0.82, -0.62, 0.5], [-0.62, -0.42, 0.6], [0.42, 0.62, 0.6], [0.62, 0.82, 0.5],
	].map(([x0, x1, r]) => ({ x0, x1, r }));
	const caps = [[-1.0, -0.82, 0.16], [0.82, 1.0, 0.16]];
	// draw back to front by depth along x
	const near = P.depth(1, 0, 0) > P.depth(-1, 0, 0) ? 1 : -1;
	const parts = [];
	for (const p of plates) parts.push({ x: (p.x0 + p.x1) / 2, f: () => cyl(k, K, P, [p.x0, 0, 0], [p.x1, 0, 0], p.r, cols, { studs: p.r > 0.55 ? 6 : 0 }) });
	for (const c of caps) parts.push({ x: (c[0] + c[1]) / 2, f: () => cyl(k, K, P, [c[0], 0, 0], [c[1], 0, 0], c[2], BAR) });
	parts.push({ x: 0, f: () => bar, depth: -1 });
	parts.sort((A, B) => A.x * near - B.x * near);
	let g = '';
	const sil = [];
	// the bar sits in the middle: draw the far half first, then the bar, then the near half
	for (const pt of parts) { const r = pt.f(); g += r.g; sil.push(...r.sil); }
	return { sil, body: g };
}

const RED = { side: '#c8262f', sideLit: '#de3a40', face: '#ef4048', inner: '#e0313a', hole: '#7a1018', tiles: { alpha: 0.16, bevel: 0.4, shadow: 0.22, shadowColor: '#5a0010', blurSd: 1.0 } };
const BAR = { side: '#8e9aab', sideLit: '#c3ccd8', face: '#b4bfcc' };

function one(k, K, { yaw = 28, pitch = 30, s = 190, cx = 256, cy = 256 } = {}) {
	const P = K.camera({ yaw, pitch, s, cx, cy });
	const d = dumbbell(k, K, P);
	// a white sliver along the near plate's top edge
	const tip = P(0.62, 0.6, 0);
	d.body += k.streak([P(0.42, 0.55, -0.25), P(0.42, 0.6, 0), P(0.42, 0.5, 0.3)], 0.045 * s, { bias: 0.5, power: 0.6 });
	return d;
}

module.exports = [
	{ name: 'PowerTiny', draw: (k, K) => one(k, K) },
	{
		name: 'PowerSmall',
		draw(k, K) {
			const a = k.place(one(k, K, { yaw: 24 }), 'translate(0 -70) scale(0.86) translate(36 36)');
			const b = k.place(one(k, K, { yaw: 34 }), 'translate(20 90) scale(0.86) translate(36 36)');
			return k.group([a, b], 9);
		},
	},
	{
		name: 'PowerMedium',
		draw(k, K) {
			// a small rack: a low frame with two rails running left to right, three dumbbells lying across them
			const P = K.camera({ yaw: 22, pitch: 30, s: 150, cx: 256, cy: 256 });
			const q = (pts) => K.poly(pts.map((p) => P(...p)));
			const rcol = { top: '#e4eaf1', front: '#bcc7d4', left: '#a6b2c1', right: '#a6b2c1', back: '#bcc7d4', side: '#a6b2c1' };
			const boxes = [];
			for (const x of [-1.45, 1.3]) for (const z of [-0.62, 0.48]) boxes.push(K.box3(x, -0.85, z, x + 0.15, 0.0, z + 0.14));
			boxes.push(K.box3(-1.55, 0.0, -0.66, 1.55, 0.14, -0.46), K.box3(-1.55, 0.0, 0.44, 1.55, 0.14, 0.64));
			boxes.push(K.box3(-1.55, -0.97, -0.7, -1.2, -0.85, 0.7), K.box3(1.2, -0.97, -0.7, 1.55, -0.85, 0.7));
			// paint boxes back to front
			boxes.sort((A, B) => P.depth(...A.top[0]) - P.depth(...B.top[0]));
			let g = '';
			const sil = [];
			for (const bx of boxes) {
				g += Object.entries(bx).filter(([, f]) => P.front(f)).map(([n, f]) => k.path(q(f), rcol[n] || rcol.side)).join('');
				// a white highlight edge along each piece's top-front edge
				const tf = bx.top;
				g += `<path d="M${P(...tf[1]).join(' ')} L${P(...tf[2]).join(' ')}" stroke="#ffffff" stroke-width="3" stroke-linecap="round" opacity="0.9"/>`;
				sil.push(...Object.values(bx).map(q));
			}
			const items = [];
			for (const x of [-0.95, 0.0, 0.95]) {
				const f = 0.62; // dumbbells scaled down to fit the rack, lying along z
				const Pr = (xx, yy, zz) => P(x + zz * f, 0.14 + 0.52 * f + yy * f, xx * f);
				Pr.depth = (xx, yy, zz) => P.depth(x + zz * f, 0.14 + 0.52 * f + yy * f, xx * f);
				Pr.faces = (n) => P.faces([n[2], n[1], n[0]]);
				items.push(dumbbell(k, K, Pr));
			}
			items.sort(() => 0);
			return k.group([{ sil, body: g }, ...items], 8);
		},
	},
	{
		name: 'PowerLarge',
		draw(k, K) {
			// a tidy heap like the ref's Large trophy pile: dumbbells stacked 3-2-1, all parallel, bars clear
			const rows = [[[-230, 110], [0, 110], [230, 110]], [[-115, -5], [115, -5]], [[0, -120]]];
			const items = [];
			for (let r = rows.length - 1; r >= 0; r--) for (const [x, y] of rows[r]) items.push(k.place(one(k, K, { yaw: 12, pitch: 24 }), `translate(${x} ${y}) scale(0.56) translate(201 201)`));
			const g = k.group(items, 8);
			// one soft glow in the middle of the heap, and the ref's big white sparkles over it
			const glow = k.rad(256, 215, 150, [[0, '#fff6c0', 0.55], [0.55, '#fff6c0', 0.22], [1, '#fff6c0', 0]]);
			g.body += `<path d="${K.circle(256, 215, 150)}" fill="${glow}"/>`;
			g.over = k.flare(130, 180, 44, 44, 0, '#ffffff', 0.17) + k.flare(395, 290, 32, 32, 0, '#ffffff', 0.17);
			return g;
		},
	},
	{
		name: 'DoublePower',
		draw(k, K) {
			const a = k.place(arm(k, K, { light: '#ffd43c', dark: '#e8920c', mid: '#f4ac18', deep: '#d8800a' }), 'translate(-40 20) scale(0.92) translate(20 20)');
			const bo = k.place(bolt(k, K, { U: 140 }), 'translate(165 -110) rotate(14 256 256)');
			return k.group([a, bo], 10);
		},
	},
];
module.exports.dumbbell = dumbbell;
