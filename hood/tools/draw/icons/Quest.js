// Quest: a short fat rolled paper scroll lying on a diagonal (low left to high right). The left end is a large oval
// end cap showing the dark rolled-up spiral; the right part is the paper unrolling open (lighter, its edge curling, a
// few faint text lines on it). A narrow red ribbon right of centre with a short notched tail hanging low. The paper
// runs cream (top) to tan (underside). Big soft studs; a white crescent on the ribbon's edge.
'use strict';

module.exports = {
	name: 'Quest',
	draw(k, K) {
		const U = 205, C = [256, 256], ang = -33;
		// local frame: x along the roll (left end -> right end), y across it (down)
		const P = ([x, y]) => K.rotp([C[0] + x * U, C[1] + y * U], C, ang);
		const S = (pts, t = 0.5) => K.smooth(pts.map((p) => (p[2] ? [...P(p), p[2]] : P(p))), true, t);
		const poly = (pts) => K.poly(pts.map(P));
		const r = (x) => 0.43 + ((x + 0.56) / 1.16) * 0.07; // the roll's radius grows a little to the right
		const X0 = -0.56, X1 = 0.6;
		// body outline: top edge, the curling open right end, bottom edge
		const top = [], bot = [];
		for (let i = 0; i <= 12; i++) { const x = X0 + ((X1 - X0) * i) / 12; top.push([x, -r(x)]); bot.push([x, r(x)]); }
		const right = [[X1 + 0.06, -r(X1) + 0.06], [X1 + 0.0, -0.2], [X1 + 0.08, -0.04], [X1 + 0.02, 0.14], [X1 + 0.07, r(X1) - 0.06]];
		const body = K.poly(top.concat(right).concat(bot.reverse()).map(P));
		// the unrolled sheet: the lighter right part of the paper
		const sheet = K.poly([[0.3, -0.6], [1.2, -0.6], [1.2, 0.7], [0.3, 0.7]].map(P));
		const capE = (dx, dy, rx, ry) => K.ellipse(...P([X0 + dx, dy]), rx * U, ry * U, ang);
		const cap = capE(0, 0, 0.22, 0.44);
		// ribbon band, narrow, right of centre; its tail hangs low with a notched end
		const xb0 = 0.04, xb1 = 0.28;
		const band = S([[xb0, -r(xb0) - 0.04], [xb0 + 0.04, -0.1], [xb0 + 0.05, 0.1], [xb0, r(xb0) + 0.04], [xb1, r(xb1) + 0.04], [xb1 + 0.05, 0.1],
			[xb1 + 0.04, -0.1], [xb1, -r(xb1) - 0.04]], 0.3);
		const tA = P([0.08, 0.44]), tB = P([0.27, 0.45]);
		const tail = K.poly([tA, tB, [tB[0] + 0.04 * U, tB[1] + 0.24 * U], [tB[0] - 0.06 * U, tB[1] + 0.17 * U], [tA[0] - 0.02 * U, tA[1] + 0.26 * U]]);

		let g = '';
		// paper: cream top, tan underside
		g += k.path(body, '#f4b788');
		g += k.soft(body, poly([[X0 - 0.2, 0.08], [X1 + 0.3, 0.08], [X1 + 0.3, 0.7], [X0 - 0.2, 0.7]]), '#e3956a', 6, 0.9);
		g += k.soft(body, poly([[X0 - 0.2, -0.7], [X1 + 0.3, -0.7], [X1 + 0.3, -0.16], [X0 - 0.2, -0.14]]), '#fbd0a4', 6, 0.95);
		// the unrolled sheet, lighter, with faint text lines
		g += k.clip(body, k.path(sheet, '#fcd7ae', 'opacity="0.6"') +
			[[-0.22, 0.42, 0.95], [-0.04, 0.4, 0.88], [0.14, 0.42, 0.8]].map(([y, a, bx]) =>
				`<path d="${poly([[a, y - 0.022], [bx, y - 0.022], [bx, y + 0.022], [a, y + 0.022]])}" fill="#d9925f" opacity="0.55"/>`).join(''));
		// the curling right edge: a light lip
		g += k.clip(body, k.path(K.poly([...right.map(([x, y]) => [x - 0.07, y]), ...right.slice().reverse().map(([x, y]) => [x + 0.2, y])].map(P)), '#fff0dc'));
		// studs along the roll (left of the ribbon)
		const tc = [[-0.36, -0.24], [-0.36, 0.08], [-0.1, -0.26], [-0.1, 0.06]];
		const a = (ang * Math.PI) / 180;
		g += k.tiles(body, [Math.cos(a), Math.sin(a), -Math.sin(a), Math.cos(a), 0, 0],
			tc.map(([x, y]) => K.rotp(P([x, y]), [0, 0], -ang).map((v) => v - 0.1 * U)), { s: 0.2 * U, r: 0.05 * U, alpha: 0.2, bevel: 0.38, shadow: 0.22, shadowColor: '#7a3510', blurSd: 1.2 });
		// end cap: a large oval with the dark rolled-up spiral inside
		g += k.path(cap, '#d97a58');
		g += k.path(capE(0.012, 0.03, 0.16, 0.34), '#a9503a');
		g += `<path d="${K.smooth([[0.0, 0.0], [0.05, -0.06], [0.1, 0.02], [0.06, 0.12], [-0.06, 0.14], [-0.12, 0.02], [-0.08, -0.14], [0.06, -0.22], [0.13, -0.18]]
			.map(([dx, dy]) => P([X0 + 0.012 + dx * 0.55, 0.03 + dy])), false)}" fill="none" stroke="#7a3226" stroke-width="${0.035 * U}" stroke-linecap="round"/>`;
		// ribbon tail then band
		g += k.path(tail, '#d62a52');
		g += k.soft(tail, K.poly([tB, [tB[0] + 0.1 * U, tB[1]], [tB[0] + 0.1 * U, tB[1] + 0.5 * U], [tB[0] - 0.03 * U, tB[1] + 0.5 * U]]), '#b81c44', 3, 0.8);
		g += k.path(band, '#ea3360');
		g += k.soft(band, poly([[xb0 - 0.1, 0.05], [xb1 + 0.2, 0.05], [xb1 + 0.2, 0.6], [xb0 - 0.1, 0.6]]), '#c71f4a', 4, 0.85);
		g += k.soft(band, poly([[xb0 - 0.1, -0.6], [xb1 + 0.2, -0.6], [xb1 + 0.2, -0.18], [xb0 - 0.1, -0.18]]), '#f25c80', 5, 0.8);
		g += k.tiles(band, [1, 0, 0, 1, 0, 0], [P([0.16, -0.2]), P([0.17, 0.13])].map(([x, y]) => [x - 0.085 * U, y - 0.085 * U]), { s: 0.17 * U, r: 0.035 * U, alpha: 0.2, bevel: 0.4, shadow: 0.22, shadowColor: '#5a0018', blurSd: 1.2 });
		// a white crescent on the band's lower right edge, a sliver along the cap's top
		g += k.streak([P([xb1 + 0.05, -0.05]), P([xb1 + 0.04, 0.2]), P([xb1 - 0.03, r(xb1) + 0.03])], 0.075 * U, { bias: 0.7, power: 0.6 });
		g += k.streak([P([X0 - 0.12, -0.3]), P([X0 + 0.05, -0.42]), P([X0 + 0.3, -0.46])], 0.04 * U, { bias: 0.4, power: 0.7, opacity: 0.85 });
		return { sil: [body, cap, band, tail], body: g };
	},
};
