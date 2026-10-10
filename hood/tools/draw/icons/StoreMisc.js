// More Store pictures: VIP (a gold crown with a red gem), Lucky (a four-leaf clover), ProBay / GoldBay (a bullseye
// target on a stand; the gold one with a small crown), BlockParty (a party popper with confetti), TripleOpen (three
// stacked shoe boxes), ExtraEquip (a blue sneaker with a green plus badge) and AutoFight (an SMG inside a green
// circular arrow). Same kit: one ink outline, soft shading, soft studs on hard surfaces, white slivers on edges.
'use strict';

const { shoe, COLORS } = require('./Sneaker');

const P2 = (U, C = [256, 256]) => ([u, v]) => [C[0] + u * U, C[1] + v * U];

// ---------------------------------------------------------------- crown
function crown(k, K, { U = 200, C = [256, 256], gem = true } = {}) {
	const P = P2(U, C);
	const S = (pts, t = 0.5) => K.smooth(pts.map(P), true, t);
	// the band: a curved front strip (we see the crown a little from above, so the top edge arcs)
	const band = S([[-0.86, 0.12], [-0.45, 0.24], [0.0, 0.28], [0.45, 0.24], [0.86, 0.12], [0.84, 0.62], [0.42, 0.74], [0.0, 0.78], [-0.42, 0.74], [-0.84, 0.62]], 0.45);
	// the back rim (inside of the crown) showing above the band
	const back = S([[-0.84, 0.14], [-0.4, -0.06], [0.0, -0.1], [0.4, -0.06], [0.84, 0.14], [0.4, 0.22], [0.0, 0.26], [-0.4, 0.22]], 0.5);
	// five points rising from the band, ball tips
	const pts = [[-0.86, -0.62], [-0.44, -0.44], [0.0, -0.78], [0.44, -0.44], [0.86, -0.62]];
	const spikes = K.roundPoly([[-0.9, 0.2], ...[[-0.86, -0.56], [-0.62, 0.0], [-0.44, -0.38], [-0.22, 0.04], [0.0, -0.72], [0.22, 0.04], [0.44, -0.38], [0.62, 0.0], [0.86, -0.56]], [0.9, 0.2], [0.0, 0.32]].map(P), 0.05 * U);
	const balls = pts.map((p) => K.circle(...P(p), 0.11 * U));
	let g = '';
	g += k.path(back, '#c97a08');
	g += k.path(spikes, '#ffc92a');
	g += k.soft(spikes, S([[0.1, -0.9], [1.0, -0.9], [1.0, 0.3], [0.1, 0.3]]), '#f4a516', 8, 0.6);
	g += k.soft(spikes, S([[-1, 0.0], [1, 0.0], [1, 0.3], [-1, 0.3]]), '#e8960e', 4, 0.7);
	for (const b of balls) g += k.path(b, '#ffe066');
	g += k.path(band, '#ffc626');
	g += k.soft(band, S([[-1.0, 0.5], [1.0, 0.5], [1.0, 0.9], [-1.0, 0.9]]), '#eb9a12', 6, 0.8);
	g += k.tiles(band, [1, 0, 0, 1, 0, 0], [[-0.68, 0.3], [-0.42, 0.36], [0.24, 0.36], [0.5, 0.3]].map(P), { s: 0.2 * U, r: 0.05 * U, alpha: 0.18, bevel: 0.4, shadow: 0.22, shadowColor: '#8a4a00', blurSd: 1.1 });
	if (gem) {
		const gemD = K.roundPoly([[0.0, 0.26], [0.17, 0.4], [0.12, 0.62], [-0.12, 0.62], [-0.17, 0.4]].map(P), 0.03 * U);
		g += k.path(gemD, '#e8253e');
		g += k.path(K.poly([[0.0, 0.26], [0.17, 0.4], [0.0, 0.46], [-0.17, 0.4]].map(P)), '#ff6b7c');
		g += k.path(K.poly([[0.0, 0.46], [0.12, 0.62], [-0.12, 0.62]].map(P)), '#b8142c');
		for (const x of [-0.56, 0.56]) g += k.path(K.circle(...P([x, 0.47]), 0.07 * U), '#3aa0f0');
	}
	g += k.streak([P([-0.84, 0.18]), P([-0.86, 0.36]), P([-0.84, 0.56])], 0.05 * U, { bias: 0.3, power: 0.6 });
	g += k.streak([P([-0.06, -0.62]), P([-0.13, -0.34]), P([-0.2, -0.06])], 0.04 * U, { bias: 0.3, power: 0.6 });
	return { sil: [spikes, band, back, ...balls], body: g };
}

// ---------------------------------------------------------------- clover
function clover(k, K) {
	const U = 200, P = P2(U);
	const heart = (rot) => {
		const pts = [[0, 0.02], [-0.3, -0.2], [-0.5, -0.48], [-0.44, -0.78], [-0.2, -0.86], [0, -0.68], [0.2, -0.86], [0.44, -0.78], [0.5, -0.48], [0.3, -0.2]];
		return K.smooth(pts.map((p) => K.rotp(P([p[0] * 0.9, p[1] * 0.9]), P([0, 0]), rot)), true, 0.5);
	};
	const leaves = [-45, 45, 135, 225].map(heart);
	const stem = K.smooth([[0.04, 0.06], [0.14, 0.5], [0.3, 0.92], [0.2, 0.96], [0.02, 0.56], [-0.06, 0.1]].map(P), true, 0.5);
	let g = k.path(stem, '#2f9a33');
	const cols = [['#5fd05a', '#46b843'], ['#64d45e', '#4cbc48'], ['#4cbc48', '#37a338'], ['#56c851', '#3fb03e']];
	leaves.forEach((d, i) => {
		g += k.path(d, cols[i][0]);
		g += k.soft(d, K.circle(...P([0, 0]), 0.3 * U), cols[i][1], 8, 0.9);
	});
	// veins: a lighter line down the middle of each leaf
	[-45, 45, 135, 225].forEach((rot) => {
		g += `<path d="M${P([0, 0]).join(' ')} L${K.rotp(P([0, -0.58]), P([0, 0]), rot).join(' ')}" stroke="#8ee886" stroke-width="${0.035 * U}" stroke-linecap="round" opacity="0.8"/>`;
	});
	g += k.path(K.circle(...P([0, 0]), 0.09 * U), '#3faf3d');
	g += k.streak([K.rotp(P([-0.42, -0.5]), P([0, 0]), -45), K.rotp(P([-0.38, -0.76]), P([0, 0]), -45), K.rotp(P([-0.12, -0.8]), P([0, 0]), -45)], 0.05 * U, { bias: 0.5, power: 0.6 });
	return { sil: [...leaves, stem], body: g };
}

// ---------------------------------------------------------------- target on a stand
function target(k, K, { gold = false } = {}) {
	const U = 200, P = P2(U, [256, 236]);
	// the easel: two front legs and a back leg
	const leg = (a, b, w) => K.roundPoly([[a[0] - w, a[1]], [a[0] + w, a[1]], [b[0] + w, b[1]], [b[0] - w, b[1]]].map(P), 0.03 * U);
	const legs = [leg([0.0, 0.2], [0.18, 1.08], 0.06), leg([-0.2, 0.3], [-0.55, 1.12], 0.07), leg([0.2, 0.3], [0.55, 1.12], 0.07)];
	const legCols = ['#8a5328', '#b06a32', '#a3622e'];
	// the board: a thick disc, tilted back a little (an ellipse face plus its edge)
	const rx = 0.82, ry = 0.78, th = 0.12;
	const edge = K.ellipse(...P([0.05, 0.03 + th / 2]), rx * U, ry * U);
	const face = K.ellipse(...P([0, 0]), rx * U, ry * U);
	const ringsGreen = ['#2fae3b', '#ffffff', '#2fae3b', '#ffffff', '#e8343e'];
	const ringsGold = ['#f2a614', '#ffe680', '#f2a614', '#ffe680', '#e8343e'];
	const rings = gold ? ringsGold : ringsGreen;
	let g = legs.map((d, i) => k.path(d, legCols[i])).join('');
	g += k.path(edge, gold ? '#c27a08' : '#1f8a2e');
	g += k.path(face, rings[0]);
	(gold ? [0.66, 0.33] : [0.8, 0.6, 0.4, 0.2]).forEach((f, i) => { g += k.path(K.ellipse(...P([0, 0]), rx * U * f, ry * U * f), gold ? ['#ffe680', '#e8343e'][i] : rings[i + 1]); });
	g += k.soft(face, K.ellipse(...P([0.5, 0.5]), 0.8 * U, 0.6 * U), '#000000', 18, 0.12);
	g += k.tiles(face, [1, 0, 0, 1, 0, 0], [[-0.62, -0.1], [0.48, -0.1], [-0.1, -0.7], [-0.1, 0.5]].map(P), { s: 0.14 * U, r: 0.035 * U, alpha: 0.14, bevel: 0.35, shadow: 0.2, shadowColor: '#103010', blurSd: 1.1 });
	g += k.streak([P([-0.42, -0.62]), P([-0.7, -0.38]), P([-0.8, -0.06])], 0.06 * U, { bias: 0.5, power: 0.6 });
	const sil = [...legs, edge, face];
	if (gold) {
		const cr = k.place(crown(k, K, { U: 128, C: [256, 256], gem: true }), `translate(${P([0, -1.02])[0] - 256} ${P([0, -1.02])[1] - 256})`);
		return { sil: sil.concat(cr.sil), body: g + k.sep(cr.sil, 8) + cr.body };
	}
	return { sil, body: g };
}

// ---------------------------------------------------------------- party popper
function popper(k, K) {
	const U = 200, P = P2(U);
	// the cone: wide mouth at the top right, tip at the bottom left
	const cone = K.roundPoly([[-0.86, 0.94], [-0.18, -0.3], [0.2, -0.04], [0.5, 0.36]].map(P), 0.07 * U);
	const mouth = K.ellipse(...P([0.16, 0.03]), 0.43 * U, 0.15 * U, 40);
	let g = k.path(cone, '#9b4ce0');
	g += k.clip(cone, [0.12, 0.36, 0.6, 0.84].map((t) => {
		const a = K.lerp([-0.86, 0.94], [-0.18, -0.3], t), b = K.lerp([-0.86, 0.94], [0.5, 0.36], t);
		return `<path d="M${P(a).join(' ')} L${P(b).join(' ')}" stroke="#ffd23a" stroke-width="${0.11 * U}"/>`;
	}).join(''));
	g += k.soft(cone, K.poly([[-1, 1], [0.5, 0.25], [0.6, 0.5], [-0.8, 1.2]].map(P)), '#6a2aa8', 8, 0.7);
	g += k.path(mouth, '#5a1f94');
	const sil = [cone];
	// curly streamers (filled ribbons, so they carry the outline)
	const ribbon = (pts, w, col) => {
		const c = K.sampleCurve(pts.map(P), 30);
		const L = [], R = [];
		for (let i = 0; i < c.length; i++) {
			const p = c[Math.max(0, i - 1)], q = c[Math.min(c.length - 1, i + 1)];
			let nx = -(q[1] - p[1]), ny = q[0] - p[0];
			const l = Math.hypot(nx, ny) || 1; nx /= l; ny /= l;
			L.push([c[i][0] + nx * w * U / 2, c[i][1] + ny * w * U / 2]); R.push([c[i][0] - nx * w * U / 2, c[i][1] - ny * w * U / 2]);
		}
		const d = K.poly(L.concat(R.reverse()));
		sil.push(d);
		return k.path(d, col);
	};
	g = ribbon([[0.18, -0.06], [0.34, -0.36], [0.22, -0.6], [0.4, -0.86]], 0.08, '#ffd23a') + ribbon([[0.3, 0.06], [0.62, -0.04], [0.7, -0.32], [0.98, -0.36]], 0.08, '#3ac0ff') + g;
	// confetti bits bursting out
	const bits = [[0.58, -0.54, '#ff4f6d', 20], [0.8, -0.1, '#5fd05a', -15], [0.0, -0.66, '#ff8a2a', 35], [0.74, -0.8, '#5fd05a', 10],
		[0.98, -0.5, '#ff4f6d', -30], [0.02, -0.98, '#3ac0ff', 40], [0.44, -1.0, '#ffd23a', -20]];
	for (const [u, v, col, rot] of bits) {
		const d = K.roundPoly([[-0.13, -0.095], [0.13, -0.095], [0.13, 0.095], [-0.13, 0.095]].map(([a, b]) => K.rotp(P([u + a, v + b]), P([u, v]), rot)), 0.03 * U);
		g += k.path(d, col);
		sil.push(d);
	}
	g += k.streak([P([-0.6, 0.5]), P([-0.36, 0.12]), P([-0.12, -0.14])], 0.05 * U, { bias: 0.5, power: 0.6 });
	return { sil, body: g };
}

// ---------------------------------------------------------------- shoe box (3D)
function shoeBox(k, K, P, { x = 0, y = 0, z = 0, w = 0.8, d = 0.52, h = 0.52, body = '#ff9a2a', bodyDark = '#e8781c', lid = '#ff6a3a', lidDark = '#d84a24', lidTop = '#ff8656' } = {}) {
	const q = (pts) => K.poly(pts.map((p) => P(...p)));
	const bx = K.box3(x - w, y, z - d, x + w, y + h, z + d);
	const lb = K.box3(x - w - 0.05, y + h - 0.14, z - d - 0.05, x + w + 0.05, y + h + 0.04, z + d + 0.05);
	let g = '';
	const sil = [];
	for (const [n, f] of Object.entries(bx)) if (P.front(f) && n !== 'top') g += k.path(q(f), n === 'front' ? body : bodyDark);
	for (const [n, f] of Object.entries(lb)) if (P.front(f)) g += k.path(q(f), n === 'top' ? lidTop : n === 'front' ? lid : lidDark);
	// a white swoosh-free stripe label on the front
	const fr = bx.front;
	g += k.tiles(q(fr), K.faceM(P, fr), [[0.18, 0.1], [w * 2 - 0.44, 0.1]], { s: 0.24, r: 0.05, alpha: 0.18, bevel: 0.4, shadow: 0.2, shadowColor: '#7a3000', blurSd: 0.006 });
	sil.push(...Object.values(bx).map(q), ...Object.values(lb).map(q));
	return { sil, g };
}

// ---------------------------------------------------------------- circular arrow + SMG
function smg(k, K, { U = 120, C = [256, 256] } = {}) {
	const P = P2(U, C);
	const RP = (pts, r) => K.roundPoly(pts.map(P), r * U);
	const body = RP([[-0.9, -0.3], [0.7, -0.3], [0.7, 0.12], [-0.9, 0.12]], 0.08);
	const barrel = RP([[0.66, -0.2], [1.1, -0.2], [1.1, -0.02], [0.66, -0.02]], 0.04);
	const mag = RP([[0.06, 0.08], [0.32, 0.08], [0.4, 0.9], [0.14, 0.92]], 0.06);
	const grip = RP([[-0.5, 0.06], [-0.2, 0.06], [-0.3, 0.7], [-0.6, 0.7]], 0.08);
	const stock = RP([[-1.3, -0.22], [-0.86, -0.22], [-0.86, 0.06], [-1.3, 0.24]], 0.06);
	let g = k.path(stock, '#9aa6b6') + k.path(mag, '#8592a4') + k.path(grip, '#a8612e') + k.path(barrel, '#a3afbf') + k.path(body, '#c9d2dd');
	g += k.path(RP([[-0.86, -0.3], [0.66, -0.3], [0.66, -0.18], [-0.86, -0.18]], 0.04), '#eef2f6');
	g += k.soft(body, RP([[-1, 0.0], [0.8, 0.0], [0.8, 0.2], [-1, 0.2]], 0), '#a3afbf', 3, 0.8);
	g += k.streak([P([-0.2, -0.27]), P([-0.6, -0.27]), P([-0.86, -0.22])], 0.06 * U, { bias: 0.5, power: 0.6 });
	return { sil: [stock, mag, grip, barrel, body], body: g };
}
function circleArrow(k, K) {
	const U = 205, P = P2(U);
	const Ro = 0.95, Ri = 0.68;
	const pts = K.arc([0, 0], Ro, -60, 230, 4).concat([[Math.cos((230 * Math.PI) / 180) * 1.12, Math.sin((230 * Math.PI) / 180) * 1.12]])
		.concat([[Math.cos((262 * Math.PI) / 180) * 0.82, Math.sin((262 * Math.PI) / 180) * 0.82]])
		.concat([[Math.cos((230 * Math.PI) / 180) * 0.5, Math.sin((230 * Math.PI) / 180) * 0.5]])
		.concat(K.arc([0, 0], Ri, 230, -60, 4));
	const d = K.poly(pts.map(P));
	let g = k.path(d, '#46c84a');
	g += k.soft(d, K.circle(...P([0.5, 0.6]), 0.9 * U), '#2fa636', 20, 0.7);
	g += k.tiles(d, [1, 0, 0, 1, 0, 0], [[-0.9, 0.0], [-0.7, 0.55], [-0.15, 0.82], [0.45, 0.72], [0.82, 0.2], [0.75, -0.42]].map(([u, v]) => P([u - 0.08, v - 0.08])), { s: 0.18 * U, r: 0.04 * U, alpha: 0.14, bevel: 0.35, shadow: 0.24, shadowColor: '#0c5a18', blurSd: 1.1 });
	g += k.streak([P([-0.92, 0.3]), P([-0.95, 0.0]), P([-0.86, -0.38])], 0.05 * U, { bias: 0.5, power: 0.6 });
	return { sil: [d], body: g };
}

module.exports = [
	{ name: 'VIP', draw: (k, K) => crown(k, K) },
	{ name: 'Lucky', draw: (k, K) => clover(k, K) },
	{ name: 'ProBay', draw: (k, K) => target(k, K) },
	{ name: 'GoldBay', draw: (k, K) => target(k, K, { gold: true }) },
	{ name: 'BlockParty', draw: (k, K) => popper(k, K) },
	{
		name: 'TripleOpen',
		draw(k, K) {
			// three chunky shoe boxes in the Box_ style, stacked 2 + 1
			const { box, SHOEBOX, sneakerPrint } = require('./Extras');
			const P = K.camera({ yaw: 26, pitch: 22, s: 120, cx: 256, cy: 256 });
			const red = { ...SHOEBOX, body: '#f4f6f9', bodySide: '#d4dbe5', lid: '#e8343e', lidSide: '#c0202c', lidTop: '#f4525a',
				studs: { alpha: 0.4, bevel: 0.36, shadow: 0.24, shadowColor: '#7a8aa0' }, decor: sneakerPrint('#e8343e', '#8a1018') };
			const blue = { ...SHOEBOX, body: '#3aa0f0', bodySide: '#2a7fd0', lid: '#ffffff', lidSide: '#d5dce6', lidTop: '#f2f5f9',
				studs: { alpha: 0.14, bevel: 0.36, shadow: 0.24, shadowColor: '#0a2a6a' }, lidStuds: { alpha: 0.4, bevel: 0.36, shadow: 0.24, shadowColor: '#7a8aa0' }, decor: sneakerPrint('#ffffff', '#1f5fb0') };
			const dims = { W: 0.9, D: 0.62, H: 0.98, lh: 0.28 };
			const a = box(k, K, SHOEBOX, 'all', { P, at: [-1.0, -0.56, 0], ...dims });
			const b = box(k, K, blue, 'all', { P, at: [1.0, -0.56, 0], ...dims });
			const c = box(k, K, red, 'all', { P, at: [0.0, 0.5, 0.05], ...dims });
			return k.group([a, b, c], 8);
		},
	},
	{
		name: 'ExtraEquip',
		draw(k, K) {
			const sh = k.place(shoe(k, K, COLORS.BLUE), 'translate(-20 30) scale(0.9) translate(28 28)');
			const U = 70, c = [420, 130];
			const badge = K.circle(c[0], c[1], U);
			const plus = K.roundPoly([[-0.18, -0.62], [0.18, -0.62], [0.18, -0.18], [0.62, -0.18], [0.62, 0.18], [0.18, 0.18], [0.18, 0.62], [-0.18, 0.62], [-0.18, 0.18], [-0.62, 0.18], [-0.62, -0.18], [-0.18, -0.18]].map(([u, v]) => [c[0] + u * U, c[1] + v * U]), 0.08 * U);
			const bd = { sil: [badge], body: k.path(badge, '#3fc248') + k.soft(badge, K.circle(c[0] + 30, c[1] + 40, U), '#2a9a34', 10, 0.8) + k.path(plus, '#ffffff') +
				k.streak([[c[0] - 0.6 * U, c[1] - 0.5 * U], [c[0] - 0.2 * U, c[1] - 0.85 * U], [c[0] + 0.2 * U, c[1] - 0.88 * U]], 0.1 * U, { bias: 0.5, power: 0.6 }) };
			return k.group([sh, bd], 9);
		},
	},
	{
		name: 'AutoFight',
		draw(k, K) {
			const ring = circleArrow(k, K);
			const gun = k.place(smg(k, K, { U: 165 }), 'translate(10 6) rotate(-14 256 256)');
			return k.group([ring, gun], 9);
		},
	},
];
module.exports.crown = crown;
