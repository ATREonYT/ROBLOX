// Brief 30 (HUD): the pictures of the soldier game's HUD extras, drawn in the kit's style (one thick navy outline, soft
// shading, white slivers, big soft studs), each matched to its crop in ref_W03.0_spawn_cross_west.jpg:
//   SpinWheel     the top-left wheel: a gold rim round eight rainbow wedges, a yellow hub, white sparkles
//   PlaytimeGift  the Playtime Rewards gift: a purple box with a big gold bow (the Rewards gift, recoloured like the ref's)
//   StarterCrate  the Starter Pack: a studded cardboard crate, a blue potion in front of it, a gold cup beside it
//   Missions      the Missions scroll: an unrolled parchment, its top and bottom curled, red lines written on it
//   SkinsPistol   the Skins square's pistol: the Gun drawing in the ref's dark green and black
//   Rank          the rank row's badge: a silver ring with a gold chevron (our rank emblem; the ref's is a grey ring)
'use strict';

const { pistol } = require('./Gun');
const { bottle, LIQ } = require('./Potion');

const P2 = (U, C = [256, 256]) => ([u, v]) => [C[0] + u * U, C[1] + v * U];

// ---------------------------------------------------------------- SpinWheel
function wheel(k, K, { hub = true, sparkle = true } = {}) {
	const U = 230, C = [256, 256], P = P2(U, C);
	const rim = K.circle(...C, 0.98 * U);
	const rimIn = K.circle(...C, 0.8 * U);
	const disc = K.circle(...C, 0.76 * U);
	// eight wedges, red at the top going clockwise (the ref's order: red, orange, yellow, green, cyan, blue, purple, magenta)
	const COLS = ['#ff2238', '#ff8a10', '#ffd814', '#30c42a', '#12c0ec', '#2258ee', '#8a34ec', '#ec2cc0'];
	let g = '';
	g += k.path(rim, '#f8b81a');
	g += k.soft(rim, K.circle(...P([0.35, 0.4]), 0.9 * U), '#e48a08', 18, 0.9);
	g += k.soft(rim, K.circle(...P([-0.4, -0.45]), 0.6 * U), '#ffe46a', 18, 0.9);
	// studs round the rim (big, sparse, like the ref's bulbs read at HUD size)
	for (let i = 0; i < 16; i++) {
		const a = (i / 16) * Math.PI * 2 + Math.PI / 16;
		const c = [C[0] + Math.cos(a) * 0.89 * U, C[1] + Math.sin(a) * 0.89 * U];
		g += k.tiles(rim, [1, 0, 0, 1, 0, 0], [[c[0] - 0.05 * U, c[1] - 0.05 * U]], { s: 0.1 * U, r: 0.05 * U, alpha: 0.28, bevel: 0.5, shadow: 0.2, shadowColor: '#7a3a00', blurSd: 0.8 });
	}
	g += k.path(rimIn, '#c86a06');
	for (let i = 0; i < 8; i++) {
		const a0 = -90 - 22.5 + i * 45, a1 = a0 + 45;
		const pts = [C, ...K.arc(C, 0.76 * U, a0, a1, 3)];
		const wedge = K.poly(pts);
		g += k.clip(disc, k.path(wedge, COLS[i]));
		// a lighter band toward the rim, darker toward the hub: the ref's soft radial shading
		const mid = ((a0 + a1) / 2) * Math.PI / 180;
		g += k.clip(wedge, k.path(K.circle(C[0] + Math.cos(mid) * 0.6 * U, C[1] + Math.sin(mid) * 0.6 * U, 0.2 * U), K.mix(COLS[i], '#ffffff', 0.16), k.blur(10)));
	}
	// thin pale separators between the wedges
	for (let i = 0; i < 8; i++) {
		const a = ((-90 - 22.5 + i * 45) * Math.PI) / 180;
		g += `<path d="M${K.pt(C)} L${K.pt([C[0] + Math.cos(a) * 0.76 * U, C[1] + Math.sin(a) * 0.76 * U])}" stroke="#ffffff" stroke-opacity="0.55" stroke-width="${0.025 * U}"/>`;
	}
	g += k.soft(disc, K.circle(...P([0.3, 0.35]), 0.7 * U), '#000033', 22, 0.1);
	if (hub) {
		const hubO = K.circle(...C, 0.2 * U);
		g += `<path d="${hubO}" fill="${k.NAVY}" stroke="${k.NAVY}" stroke-width="${0.06 * U}"/>`;
		g += k.path(hubO, '#ffd226');
		g += k.soft(hubO, K.circle(...P([0.06, 0.07]), 0.16 * U), '#f29a0a', 6, 0.9);
		g += k.path(K.circle(...P([-0.06, -0.07]), 0.07 * U), '#fff3a0');
	}
	// slivers on the rim's top-left
	g += k.streak(K.arc(C, 0.9 * U, 196, 248, 6), 0.06 * U, { bias: 0.45, power: 0.6 });
	const over = sparkle ? k.flare(...P([-0.7, -0.66]), 0.16 * U, 0.16 * U, 0) + k.flare(...P([0.72, 0.62]), 0.11 * U, 0.11 * U, 0) : '';
	return { sil: [rim], body: g, over };
}

// ---------------------------------------------------------------- PlaytimeGift (the Rewards gift, purple and gold)
function gift(k, K) {
	const s = 172;
	const P = K.camera({ yaw: 45, pitch: 24, s, cx: 256, cy: 270 });
	const q = (pts) => K.poly(pts.map((p) => P(...p)));
	const A = 0.8;
	const y0 = -0.66, y1 = 0.2, L = 0.06, yl = 0.46;
	const box = K.box3(-A, y0, -A, A, y1, A);
	const lid = K.box3(-A - L, y1 - 0.02, -A - L, A + L, yl, A + L);
	const rb = 0.3;
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
	for (const f of faces(box, { left: '#9a3ef2', front: '#7422d0' })) {
		g += k.path(f.d, f.fill) + studs(f, 2, 0.24, '#26004a');
		g += k.path(q(strip(f.n, y0, y1, 0.005)), f.n === 'front' ? '#f39c1f' : '#ffb92c');
	}
	for (const f of faces(lid, { left: '#ac5cfa', front: '#8a34e4', top: '#c084ff' })) {
		g += k.path(f.d, f.fill);
		if (f.n !== 'top') g += k.path(q(strip(f.n, y1 - 0.02, yl, 0.005)), f.n === 'front' ? '#f8a823' : '#ffc436');
	}
	g += k.path(q([[-rb, yl, -A - L], [rb, yl, -A - L], [rb, yl, A + L], [-rb, yl, A + L]]), '#ffd24a');
	g += k.path(q([[-A - L, yl, -rb], [A + L, yl, -rb], [A + L, yl, rb], [-A - L, yl, rb]]), '#ffd24a');
	const c = P(0, yl, 0);
	const bs = 1.26 * s;
	const B = (u, v) => [c[0] + u * bs, c[1] + v * bs];
	const Sm = (pts, t = 0.5) => K.smooth(pts.map(([u, v]) => B(u, v)), true, t);
	const loopL = Sm([[-0.12, 0.0], [-0.44, 0.1], [-0.82, 0.04], [-0.98, -0.2], [-0.9, -0.5], [-0.62, -0.62], [-0.32, -0.46], [-0.14, -0.2]]);
	const loopLin = Sm([[-0.22, -0.06], [-0.46, 0.0], [-0.74, -0.06], [-0.8, -0.24], [-0.68, -0.42], [-0.44, -0.38], [-0.26, -0.2]]);
	const loopR = Sm([[0.12, 0.0], [0.44, 0.1], [0.82, 0.04], [0.98, -0.2], [0.9, -0.5], [0.62, -0.62], [0.32, -0.46], [0.14, -0.2]]);
	const loopRin = Sm([[0.22, -0.06], [0.46, 0.0], [0.74, -0.06], [0.8, -0.24], [0.68, -0.42], [0.44, -0.38], [0.26, -0.2]]);
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
	g += k.streak([P(-A - L, yl - 0.02, -A - L), P(-A - L, yl - 0.13, -A - L), P(-A - L, y1 + 0.02, -A - L)], 0.06 * s, { bias: 0.25, power: 0.55 });
	g += k.streak([P(-A - L, yl, -A + 0.3), P(-A - L, yl, -A - L), P(-A + 0.3, yl, -A - L)], 0.05 * s, { bias: 0.5, power: 0.6 });
	const sil = [...Object.values(box).map(q), ...Object.values(lid).map(q), loopL, loopR, knot, tailL, tailR];
	return { sil, body: g };
}

// ---------------------------------------------------------------- StarterCrate
// a cardboard crate seen corner-on from above, studded, with tape across its top
function crate(k, K) {
	const s = 150;
	const P = K.camera({ yaw: 36, pitch: 26, s, cx: 256, cy: 262 });
	const q = (pts) => K.poly(pts.map((p) => P(...p)));
	const A = 0.85, H = 0.82;
	const bx = K.box3(-A, -H, -A, A, H, A);
	const col = { top: '#e8b47c', left: '#d08c52', front: '#b56e38', right: '#b56e38' };
	let g = '';
	const sil = [];
	for (const [n, f] of Object.entries(bx)) {
		if (!P.front(f)) continue;
		const d = q(f);
		sil.push(d);
		g += k.path(d, col[n] || '#c07a40');
		const [w, h] = K.faceSize(f);
		const cells = [];
		for (let j = 0; j < 4; j++) for (let i = 0; i < 4; i++) cells.push([0.06 + i * w / 4, 0.06 + j * h / 4]);
		g += k.tiles(d, K.faceM(P, f), cells, { s: w / 4 - 0.12, r: 0.06, alpha: 0.12, bevel: 0.32, shadow: 0.26, shadowColor: '#4a2000', blurSd: 0.006 });
	}
	// the tape across the lid and down the front
	g += k.path(q([[-0.18, H, -A], [0.18, H, -A], [0.18, H, A], [-0.18, H, A]]), '#f6d8a8');
	g += k.path(q([[-0.18, H, A], [0.18, H, A], [0.18, H - 0.5, A], [-0.18, H - 0.5, A]]), '#e2bc84');
	g += k.streak([P(-A, H - 0.05, -A + 0.2), P(-A, H, -A), P(-A + 0.4, H, -A)], 0.05 * s, { bias: 0.5, power: 0.6 });
	g += k.streak([P(-A, H - 0.1, A), P(-A, 0.1, A), P(-A, -0.5, A)], 0.045 * s, { bias: 0.3, power: 0.6, opacity: 0.8 });
	return { sil, body: g };
}
function starter(k, K) {
	const Extras = require('./Extras');
	const cup = Extras.find((e) => e.name === 'Trophy').draw(k, K);
	const box = k.place(crate(k, K), 'translate(10 -10)');
	const potion = k.place(bottle(k, K, LIQ.BLUE, { neck: 0.18 }), 'translate(-120 70) rotate(-10 256 256) scale(0.52) translate(236 236)');
	const trophy = k.place(cup, 'translate(150 80) rotate(8 256 256) scale(0.5) translate(256 256)');
	return k.group([box, trophy, potion], 10);
}

// ---------------------------------------------------------------- Missions (an unrolled parchment scroll)
function scroll(k, K) {
	const U = 210, C = [256, 256], ang = -14;
	const P = ([u, v]) => K.rotp([C[0] + u * U, C[1] + v * U], C, ang);
	const S = (pts, t = 0.5) => K.smooth(pts.map(P), true, t);
	// the sheet: a slightly wavy rectangle between the two rolls
	const sheet = S([[-0.6, -0.62, 'c'], [-0.1, -0.66], [0.62, -0.6, 'c'], [0.58, 0.0], [0.64, 0.62, 'c'], [0.1, 0.66], [-0.6, 0.6, 'c'], [-0.56, 0.0]], 0.4);
	// the top roll (curled toward the viewer) and the bottom roll
	const rollT = S([[-0.74, -0.86], [0.7, -0.84], [0.82, -0.72], [0.74, -0.58], [-0.72, -0.6], [-0.84, -0.72]], 0.5);
	const rollB = S([[-0.7, 0.58], [0.76, 0.6], [0.88, 0.72], [0.8, 0.86], [-0.68, 0.84], [-0.8, 0.72]], 0.5);
	const endT = K.ellipse(...P([-0.8, -0.72]), 0.1 * U, 0.15 * U, ang);
	const endB = K.ellipse(...P([0.84, 0.72]), 0.1 * U, 0.15 * U, ang);
	let g = '';
	g += k.path(sheet, '#f6d7a6');
	g += k.soft(sheet, S([[0.1, -0.7], [0.8, -0.7], [0.8, 0.7], [0.2, 0.7]]), '#e8b67c', 18, 0.8);
	g += k.soft(sheet, S([[-0.7, -0.7], [-0.2, -0.7], [-0.3, 0.7], [-0.7, 0.7]]), '#fff0d4', 16, 0.7);
	// the red written lines (the ref's red ink)
	for (const [y, a, b] of [[-0.36, -0.42, 0.4], [-0.16, -0.42, 0.34], [0.04, -0.42, 0.42], [0.24, -0.42, 0.22]]) {
		g += `<path d="${K.poly([P([a, y - 0.035]), P([b, y - 0.035]), P([b, y + 0.035]), P([a, y + 0.035])])}" fill="#d83a3a" opacity="0.85"/>`;
	}
	// a red tick box at each line's start, the first one ticked
	g += k.tiles(sheet, [1, 0, 0, 1, 0, 0], [P([-0.3, 0.38]), P([0.06, 0.38])].map(([x, y]) => [x - 0.07 * U, y - 0.07 * U]), { s: 0.14 * U, r: 0.03 * U, alpha: 0.18, bevel: 0.4, shadow: 0.2, shadowColor: '#6a3000', blurSd: 1.1 });
	g += k.path(rollT, '#f2c48c');
	g += k.soft(rollT, S([[-0.8, -0.7], [0.8, -0.7], [0.8, -0.55], [-0.8, -0.55]]), '#d9945a', 5, 0.9);
	g += k.path(rollB, '#f2c48c');
	g += k.soft(rollB, S([[-0.8, 0.74], [0.9, 0.74], [0.9, 0.9], [-0.8, 0.9]]), '#d9945a', 5, 0.9);
	g += k.path(endT, '#c97a48') + k.path(K.ellipse(...P([-0.8, -0.72]), 0.05 * U, 0.08 * U, ang), '#8a4426');
	g += k.path(endB, '#c97a48') + k.path(K.ellipse(...P([0.84, 0.72]), 0.05 * U, 0.08 * U, ang), '#8a4426');
	g += k.streak([P([-0.6, -0.8]), P([0.0, -0.84]), P([0.5, -0.82])], 0.05 * U, { bias: 0.35, power: 0.6 });
	g += k.streak([P([-0.52, -0.5]), P([-0.56, -0.1]), P([-0.52, 0.4])], 0.04 * U, { bias: 0.3, power: 0.6, opacity: 0.8 });
	return { sil: [sheet, rollT, rollB, endT, endB], body: g };
}

// ---------------------------------------------------------------- Rank (a silver ring, a gold chevron)
function rank(k, K) {
	const U = 215, C = [256, 256], P = P2(U, C);
	const ring = K.circle(...C, 0.95 * U);
	const hole = K.circle(...C, 0.6 * U);
	let g = '';
	g += k.path(`${ring} ${hole}`, '#c4ccd8', 'fill-rule="evenodd"');
	g += k.soft(`${ring} ${hole}`, K.circle(...P([0.4, 0.45]), 0.8 * U), '#8a94a6', 16, 0.9);
	g += k.soft(`${ring} ${hole}`, K.circle(...P([-0.45, -0.45]), 0.5 * U), '#ffffff', 16, 0.6);
	for (let i = 0; i < 10; i++) {
		const a = (i / 10) * Math.PI * 2;
		const c = [C[0] + Math.cos(a) * 0.78 * U, C[1] + Math.sin(a) * 0.78 * U];
		g += k.tiles(`${ring} ${hole}`, [1, 0, 0, 1, 0, 0], [[c[0] - 0.1 * U, c[1] - 0.1 * U]], { s: 0.2 * U, r: 0.05 * U, alpha: 0.18, bevel: 0.4, shadow: 0.24, shadowColor: '#2a3040', blurSd: 1.0 });
	}
	g += k.path(hole, '#2a3248');
	// the gold chevron (^) in the middle
	const chev = K.roundPoly([P([-0.42, 0.16]), P([0.0, -0.24]), P([0.42, 0.16]), P([0.42, 0.38]), P([0.0, -0.02]), P([-0.42, 0.38])], 0.04 * U);
	g += `<path d="${chev}" fill="${k.NAVY}" stroke="${k.NAVY}" stroke-width="${0.08 * U}" stroke-linejoin="round"/>`;
	g += k.path(chev, '#ffc928');
	g += k.soft(chev, K.circle(...P([0.2, 0.3]), 0.3 * U), '#f29a0a', 6, 0.8);
	g += k.streak(K.arc(C, 0.86 * U, 190, 250, 6), 0.06 * U, { bias: 0.45, power: 0.6 });
	return { sil: [ring], holes: [], body: g };
}

const GREEN = {
	slide: '#3f6a3a', slideTop: '#5e8a52', slideDark: '#2c4a2a', frame: '#242c26', frameDark: '#151a16', hole: '#0c100c',
	grip: '#2a322c', gripDark: '#1a201c',
};

module.exports = [
	{ name: 'SpinWheel', draw: (k, K) => wheel(k, K) },
	{ name: 'SpinWheelDisc', draw: (k, K) => wheel(k, K, { hub: false, sparkle: false }) },
	{ name: 'PlaytimeGift', draw: (k, K) => gift(k, K) },
	{ name: 'StarterCrate', draw: (k, K) => starter(k, K) },
	{ name: 'Missions', draw: (k, K) => scroll(k, K) },
	{ name: 'SkinsPistol', draw: (k, K) => pistol(k, K, GREEN) },
	{ name: 'Rank', draw: (k, K) => rank(k, K) },
];
