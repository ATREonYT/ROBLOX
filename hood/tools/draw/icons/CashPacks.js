// The Store's cash packs, DoubleCash and TenXCash: green bill stacks with paper bands, gold "$" coins and green money
// bags, piled like the reference's trophy packs (one outline round the pile, thin ink where a front piece overlaps a
// back one). The Large pack gets the ref's big white sparkles.
'use strict';

const { stack, coin, dollar } = require('./Cash');

// one bill stack, drawn round (256, 256); turn = yaw of the stack
function stackItem(k, K, { yaw = 24, pitch = 38, s = 190, len = 0.9, thick = 0.33, band = true } = {}) {
	const P = K.camera({ yaw, pitch, s, cx: 256, cy: 256 });
	const st = stack(k, K, P, { x0: -len, x1: len, z0: -0.55, z1: 0.55, y0: -thick, y1: thick * 0.8, band });
	let g = st.g;
	g += k.streak([P(-len * 0.45, thick * 0.8, -0.55), P(-len, thick * 0.8, -0.55), P(-len, thick * 0.8, -0.05)], 0.05 * s, { bias: 0.5, power: 0.7 });
	return { sil: st.sil, body: g };
}

// a gold coin lying flat (seen from above at the camera's pitch), centre (256, 256), radius r px
function flatCoin(k, K, { r = 90, squash = 0.6, th = 0.22 } = {}) {
	const cx = 256, cy = 256, ry = r * squash, t = r * th;
	const face = K.ellipse(cx, cy, r, ry);
	const edge = K.ellipse(cx, cy + t, r, ry);
	const side = `M${cx - r} ${cy} L${cx - r} ${cy + t} A${r} ${ry} 0 0 0 ${cx + r} ${cy + t} L${cx + r} ${cy} Z`;
	let g = k.path(edge, '#e0860c') + k.path(side, '#ec9612');
	// edge reeding: light ticks round the rim
	for (let i = 1; i < 12; i++) {
		const a = Math.PI * (i / 12);
		const x = cx - r * Math.cos(a), y = cy + ry * Math.sin(a);
		g += `<path d="M${x} ${y + t * 0.2} L${x} ${y + t * 0.8}" stroke="#f6b02a" stroke-width="${r * 0.05}" stroke-linecap="round"/>`;
	}
	g += k.path(face, '#ffc928');
	g += k.path(K.ellipse(cx, cy, r * 0.74, ry * 0.74), '#f6ae19');
	g += dollar(k, [r * 0.8, 0, 0, ry * 0.8, cx, cy], '#e08a0c', 0.2);
	g += k.streak([[cx - r * 0.86, cy - ry * 0.2], [cx - r * 0.6, cy - ry * 0.74], [cx - r * 0.1, cy - ry * 0.98]], r * 0.1, { bias: 0.5, power: 0.6 });
	return { sil: [face, edge, side], body: g };
}

// a standing coin (facing the viewer, turned a little), centre (256, 256)
function standCoin(k, K, { r = 0.5, yaw = -18, tilt = -8, s = 190 } = {}) {
	const P = K.camera({ yaw: 0, pitch: 20, s, cx: 256, cy: 256 });
	const cn = coin(k, K, P, { c: [0, 0, 0], r, th: 0.13, yaw, tilt });
	let g = cn.g;
	const a0 = cn.front;
	g += k.streak([a0[14], a0[17], a0[20], a0[23]], 0.05 * s, { bias: 0.5, power: 0.6 });
	return { sil: cn.sil, body: g };
}

// a green money bag with a gold tie and a big "$", centre (256, 256), about 2U wide
function moneyBag(k, K, { U = 180, over = false } = {}) {
	const C = [256, 256];
	const P = ([u, v]) => [C[0] + u * U, C[1] + v * U];
	const S = (pts, t = 0.5) => K.smooth(pts.map(P), true, t);
	const body = S([[0.0, -0.36], [0.42, -0.3], [0.78, 0.0], [0.9, 0.4], [0.76, 0.78], [0.36, 0.94], [-0.36, 0.94], [-0.76, 0.78], [-0.9, 0.4], [-0.78, 0.0], [-0.42, -0.3]], 0.55);
	const neck = S([[-0.26, -0.5], [0.26, -0.5], [0.2, -0.3], [-0.2, -0.3]], 0.3);
	const ruff = S([[-0.5, -0.86], [-0.3, -0.7], [-0.14, -0.9], [0.0, -0.72], [0.16, -0.92], [0.3, -0.7], [0.5, -0.86], [0.42, -0.6], [0.24, -0.46], [-0.24, -0.46], [-0.42, -0.6]], 0.45);
	const tie = K.roundPoly([P([-0.34, -0.56]), P([0.34, -0.56]), P([0.3, -0.4]), P([-0.3, -0.4])], 0.06 * U);
	let g = '';
	g += k.path(ruff, '#47bb45');
	g += k.soft(ruff, S([[-0.6, -0.6], [0.6, -0.6], [0.6, -0.4], [-0.6, -0.4]]), '#2f9a34', 4, 0.8);
	g += k.path(neck, '#3aa93c');
	g += k.path(body, '#4fc44b');
	g += k.soft(body, K.ellipse(...P([0.35, 0.75]), 0.8 * U, 0.45 * U), '#36a83a', 14, 0.85);
	g += k.soft(body, K.ellipse(...P([-0.38, 0.05]), 0.32 * U, 0.26 * U), '#74de68', 12, 0.8);
	// the "$" in a pale disc
	g += k.path(K.ellipse(...P([0.02, 0.4]), 0.4 * U, 0.38 * U), '#bdf2a6');
	g += dollar(k, [0.62 * U, 0, 0, 0.62 * U, ...P([0.02, 0.4])], '#2c9a35', 0.2);
	g += k.path(tie, '#ffc928') + k.soft(tie, K.rect(...P([-0.4, -0.47]), 0.8 * U, 0.1 * U), '#e8960e', 2, 0.8);
	g += k.streak([P([-0.36, -0.22]), P([-0.66, 0.02]), P([-0.8, 0.36])], 0.06 * U, { bias: 0.4, power: 0.6 });
	const sil = [body, neck, ruff, tie];
	if (over) {
		// a fan of bills spilling out of the open top
		const billAt = (rot, len, col) => {
			const c0 = P([0, -0.5]);
			const corners = [[-0.2, -0.05], [0.2, -0.05], [0.2, -len], [-0.2, -len]].map((p) => K.rotp(P(p.map((v, i) => v + (i ? -0.5 : 0))), c0, rot));
			const d = K.roundPoly(corners, 0.04 * U);
			const em = K.rotp(P([0, -0.5 - len * 0.62]), c0, rot);
			return { d, b: k.path(d, col) + k.path(K.ellipse(em[0], em[1], 0.1 * U, 0.12 * U, rot), '#3fae3e') +
				`<path d="${K.roundPoly([[-0.15, -0.1], [0.15, -0.1], [0.15, -len + 0.06], [-0.15, -len + 0.06]].map((p) => K.rotp(P(p.map((v, i) => v + (i ? -0.5 : 0))), c0, rot)), 0.03 * U)}" fill="none" stroke="#3ea83c" stroke-width="${0.025 * U}"/>` };
		};
		const fan = [billAt(-34, 0.66, '#53c94e'), billAt(30, 0.68, '#53c94e'), billAt(-8, 0.78, '#5fd35a'), billAt(14, 0.72, '#58cf52')];
		g = fan.map((x) => x.b).join('') + g;
		sil.push(...fan.map((x) => x.d));
	}
	return { sil, body: g };
}

// a chunky yellow lightning bolt, centre (256, 256)
function bolt(k, K, { U = 200 } = {}) {
	const P = ([u, v]) => [256 + u * U, 256 + v * U];
	const pts = [[0.12, -1.0], [-0.5, 0.12], [-0.06, 0.12], [-0.22, 1.0], [0.5, -0.18], [0.06, -0.18], [0.3, -1.0]];
	const d = K.roundPoly(pts.map(P), 0.03 * U);
	let g = k.path(d, '#ffd12a');
	g += k.soft(d, K.poly([[-0.1, 0.0], [0.6, -0.3], [0.6, 1.1], [-0.4, 1.1]].map(P)), '#f7a514', 5, 0.85);
	g += k.streak([P([0.24, -0.94]), P([0.0, -0.5]), P([-0.36, 0.06])], 0.06 * U, { bias: 0.5, power: 0.6 });
	return { sil: [d], body: g };
}

module.exports = [
	{
		name: 'CashTiny',
		draw(k, K) {
			const st = k.place(stackItem(k, K), 'translate(0 0)');
			const c1 = k.place(flatCoin(k, K, { r: 72 }), 'translate(120 110)');
			const c2 = k.place(standCoin(k, K, { r: 0.42 }), 'translate(-170 70)');
			return k.group([st, c1, c2], 9);
		},
	},
	{
		name: 'CashSmall',
		draw(k, K) {
			const a = k.place(stackItem(k, K, { yaw: 20 }), 'translate(-120 70) scale(0.82) translate(56 56)');
			const b = k.place(stackItem(k, K, { yaw: 28 }), 'translate(120 70) scale(0.82) translate(56 56)');
			const c = k.place(stackItem(k, K, { yaw: -18 }), 'translate(0 -50) scale(0.82) translate(56 56)');
			const c1 = k.place(flatCoin(k, K, { r: 62 }), 'translate(-190 175)');
			const c2 = k.place(flatCoin(k, K, { r: 58 }), 'translate(10 190)');
			const c3 = k.place(standCoin(k, K, { r: 0.4 }), 'translate(205 150)');
			return k.group([c, a, b, c1, c2, c3], 9);
		},
	},
	{
		name: 'CashMedium',
		draw(k, K) {
			const bag = k.place(moneyBag(k, K, { U: 150 }), 'translate(70 -90)');
			const a = k.place(stackItem(k, K, { yaw: 22 }), 'translate(-150 40) scale(0.78) translate(56 56)');
			const b = k.place(stackItem(k, K, { yaw: -14 }), 'translate(-30 120) scale(0.82) translate(46 46)');
			const c = k.place(stackItem(k, K, { yaw: 30 }), 'translate(170 110) scale(0.72) translate(72 72)');
			const c1 = k.place(flatCoin(k, K, { r: 60 }), 'translate(-215 185)');
			const c2 = k.place(standCoin(k, K, { r: 0.38 }), 'translate(225 0)');
			const c3 = k.place(flatCoin(k, K, { r: 52 }), 'translate(110 225)');
			return k.group([bag, a, c2, c, b, c1, c3], 9);
		},
	},
	{
		name: 'CashLarge',
		draw(k, K) {
			const bag1 = k.place(moneyBag(k, K, { U: 140 }), 'translate(-120 -110)');
			const bag2 = k.place(moneyBag(k, K, { U: 150 }), 'translate(130 -95)');
			const a = k.place(stackItem(k, K, { yaw: 22 }), 'translate(-170 70) scale(0.74) translate(66 66)');
			const b = k.place(stackItem(k, K, { yaw: -16 }), 'translate(0 120) scale(0.8) translate(52 52)');
			const c = k.place(stackItem(k, K, { yaw: 30 }), 'translate(190 90) scale(0.7) translate(76 76)');
			const c1 = k.place(flatCoin(k, K, { r: 56 }), 'translate(-230 200)');
			const c2 = k.place(flatCoin(k, K, { r: 52 }), 'translate(150 230)');
			const c3 = k.place(standCoin(k, K, { r: 0.36 }), 'translate(10 -20)');
			const g = k.group([bag1, bag2, c3, a, c, b, c1, c2], 9);
			// the ref's big white sparkles on the large pack
			g.over = k.flare(95, 320, 46, 46, 0, '#ffffff', 0.17) + k.flare(420, 255, 32, 32, 0, '#ffffff', 0.17) + k.flare(250, 125, 26, 26, 0, '#ffffff', 0.17);
			return g;
		},
	},
	{
		name: 'DoubleCash',
		draw(k, K) {
			const a = k.place(stackItem(k, K, { yaw: 22 }), 'translate(-70 60) scale(0.86) translate(36 36)');
			const b = k.place(stackItem(k, K, { yaw: 22 }), 'translate(-70 -70) scale(0.86) translate(36 36)');
			const bo = k.place(bolt(k, K, { U: 150 }), 'translate(150 10) rotate(12 256 256)');
			return k.group([a, b, bo], 10);
		},
	},
	{
		name: 'TenXCash',
		draw(k, K) {
			const bag = k.place(moneyBag(k, K, { U: 200, over: true }), 'translate(-20 10)');
			const st = k.place(stackItem(k, K, { yaw: 26 }), 'translate(150 175) scale(0.6) translate(170 170)');
			const cn = k.place(flatCoin(k, K, { r: 58 }), 'translate(-185 205)');
			return k.group([bag, st, cn], 9);
		},
	},
];
module.exports.moneyBag = moneyBag;
module.exports.bolt = bolt;
module.exports.flatCoin = flatCoin;
module.exports.stackItem = stackItem;
