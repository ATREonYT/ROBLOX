// Backpack: a puffy orange-red school backpack, tilted about 11° and turned a little to the right. A lighter domed flap
// over the top with a clear darker hem, two thick dark clasp straps hanging from the flap with light buckles, the front
// panel below, the darker left side panel with a shoulder strap running down it, a flat pill-shaped side pocket low on
// the left, and a dark-red carry loop standing up at the top left. Big soft studs; thin white slivers on the flap's
// top-left corner and the front's bottom-left edge.
'use strict';

function pack(k, K, c) {
	const U = 206, C = [256, 256];
	const P = ([u, v, cc]) => (cc ? [C[0] + u * U, C[1] + v * U, cc] : [C[0] + u * U, C[1] + v * U]);
	const S = (pts, t = 0.5) => K.smooth(pts.map(P), true, t);
	const RP = (pts, r) => K.roundPoly(pts.map(P), r * U);
	// studs centred on the given (u, v) points, turned rot degrees
	const tile = (face, cells, rot = 0, s = 0.25) => {
		const a = (rot * Math.PI) / 180, h = (s * U) / 2;
		const cs = cells.map(([u, v]) => K.rotp(P([u, v]), [0, 0], -rot)).map(([x, y]) => [x - h, y - h]);
		return k.tiles(face, [Math.cos(a), Math.sin(a), -Math.sin(a), Math.cos(a), 0, 0], cs, { s: s * U, r: 0.065 * U, ...c.tiles });
	};

	// the carry loop: a thick arch standing up from the top-left of the flap
	const loopOut = S([[-0.74, -0.5], [-0.82, -0.78], [-0.7, -1.02], [-0.44, -1.1], [-0.2, -1.0], [-0.12, -0.76], [-0.2, -0.62]], 0.5);
	const loopIn = S([[-0.58, -0.62], [-0.62, -0.82], [-0.52, -0.94], [-0.38, -0.95], [-0.3, -0.84], [-0.32, -0.7]], 0.5);
	// the bag: side panel + front
	const bag = S([
		[-0.72, -0.4], [-0.58, -0.56], [-0.4, -0.7], [-0.05, -0.8], [0.3, -0.8], [0.62, -0.76], [0.84, -0.62], [0.93, -0.36],
		[0.94, 0.1], [0.92, 0.5], [0.84, 0.76], [0.6, 0.88], [0.2, 0.92], [-0.22, 0.92], [-0.52, 0.88], [-0.74, 0.74], [-0.84, 0.46],
		[-0.84, 0.15], [-0.8, -0.15],
	], 0.5);
	// front panel (right of the front-left edge)
	const front = S([
		[-0.32, -0.2], [0.3, -0.3], [0.94, -0.3], [0.94, 0.1], [0.92, 0.5], [0.84, 0.76], [0.6, 0.88], [0.2, 0.92], [-0.27, 0.92, 'c'],
		[-0.28, 0.5], [-0.3, 0.1],
	], 0.5);
	// the flap: a tall dome from the sharp top-left corner over the top, down past the middle
	const flapPts = [
		[-0.6, -0.54, 'c'], [-0.42, -0.7], [-0.18, -0.8], [0.1, -0.83], [0.45, -0.81], [0.72, -0.7], [0.88, -0.5], [0.94, -0.2],
		[0.95, 0.08], [0.62, 0.12], [0.25, 0.16], [-0.08, 0.18], [-0.26, 0.15], [-0.33, -0.02], [-0.42, -0.25], [-0.51, -0.42],
	];
	const flap = S(flapPts, 0.5);
	// the hem: a darker band along the flap's lower edge
	const hem = S([[-0.36, -0.04], [-0.08, 0.06], [0.25, 0.04], [0.62, 0.0], [0.97, -0.04], [0.97, 0.1], [0.62, 0.14], [0.25, 0.18],
		[-0.08, 0.2], [-0.27, 0.17]], 0.4);
	// the shoulder strap down the side panel
	const shoulder = S([[-0.6, -0.5], [-0.48, -0.44], [-0.5, -0.1], [-0.56, 0.3], [-0.64, 0.32], [-0.62, -0.1]], 0.5);
	// a flat pill-shaped side pocket low on the left
	const pocket = RP([[-0.98, 0.36], [-0.4, 0.4], [-0.4, 0.72], [-0.98, 0.68]], 0.16);
	const pocketTop = RP([[-0.98, 0.36], [-0.4, 0.4], [-0.4, 0.5], [-0.98, 0.47]], 0.05);
	// two thick clasp straps hanging from the flap, with buckles
	const strap = (x) => RP([[x, -0.12], [x + 0.21, -0.12], [x + 0.21, 0.5], [x, 0.5]], 0.105);
	const buckle = (x) => RP([[x - 0.02, 0.3], [x + 0.23, 0.3], [x + 0.23, 0.44], [x - 0.02, 0.44]], 0.04);
	const buckleIn = (x) => RP([[x + 0.05, 0.335], [x + 0.16, 0.335], [x + 0.16, 0.405], [x + 0.05, 0.405]], 0.02);

	let b = '';
	b += k.path(loopOut, c.loop);
	b += k.path(loopIn, c.loopDark);
	b += k.path(bag, c.side);
	b += k.soft(bag, K.ellipse(C[0] - 0.8 * U, C[1] + 0.3 * U, 0.3 * U, 0.8 * U), c.sideDark, 10, 0.7);
	b += tile(bag, [[-0.62, -0.18], [-0.66, 0.12]], 12, 0.21);
	b += k.path(shoulder, c.loop);
	b += k.path(front, c.front);
	b += k.soft(front, K.ellipse(C[0] + 0.35 * U, C[1] + 1.05 * U, 1.0 * U, 0.35 * U), c.frontDark, 14, 0.8);
	b += tile(front, [[-0.1, 0.42], [0.36, 0.42], [0.82, 0.4], [-0.02, 0.73], [0.3, 0.72], [0.62, 0.7]], -4, 0.25);
	// pocket
	b += k.path(pocket, c.pocket);
	b += k.soft(pocket, RP([[-1.1, 0.6], [-0.3, 0.6], [-0.3, 0.8], [-1.1, 0.8]], 0), c.frontDark, 4, 0.7);
	b += k.path(pocketTop, c.pocketTop);
	// flap + hem
	b += k.path(flap, c.flap);
	b += k.soft(flap, K.ellipse(C[0] + 0.0 * U, C[1] - 0.7 * U, 0.8 * U, 0.3 * U), c.flapLit, 16, 0.9);
	b += tile(flap, [[-0.24, -0.56], [0.12, -0.62], [0.5, -0.6], [-0.14, -0.26], [0.26, -0.3], [0.84, -0.3]], -5, 0.26);
	b += k.clip(flap, k.path(hem, c.hem));
	// straps and buckles
	for (const x of [0.06, 0.52]) {
		b += k.path(strap(x), c.strap);
		b += k.soft(strap(x), K.rect(C[0] + (x - 0.01) * U, C[1] - 0.16 * U, 0.08 * U, 0.7 * U), c.strapLit, 3, 0.6);
		b += k.path(buckle(x), c.buckle) + k.path(buckleIn(x), c.strap);
	}

	// thin white slivers: the flap's top-left corner (a sharp "<"), the front's bottom-left edge, a tick on the loop
	b += k.streak([P([-0.2, -0.79]), P([-0.4, -0.7]), P([-0.6, -0.54]), P([-0.5, -0.42])], 0.06 * U, { bias: 0.66, power: 0.55 });
	b += k.streak([P([-0.29, 0.5]), P([-0.28, 0.72]), P([-0.27, 0.9]), P([-0.1, 0.92])], 0.045 * U, { bias: 0.7, power: 0.55 });
	b += k.streak([P([-0.74, -0.86]), P([-0.62, -1.02]), P([-0.44, -1.06])], 0.035 * U, { bias: 0.5, power: 0.7, opacity: 0.8 });
	const drawing = { sil: [bag, loopOut, pocket], body: b };
	// tilt the whole pack about 11° (its top leans left, like the ref)
	return k.place(drawing, `rotate(-11 ${C[0]} ${C[1]})`);
}

const RED = {
	loop: '#ae2410', loopDark: '#6e1206', side: '#d4472a', sideDark: '#c43b22', front: '#ec6244', frontDark: '#da5236',
	pocket: '#f27354', pocketTop: '#fd8a6b', hem: '#c63a1f', flap: '#fc8466', flapLit: '#ff9878',
	strap: '#9e1f0c', strapLit: '#b8301a', buckle: '#f6d77a',
	tiles: { alpha: 0.13, bevel: 0.34, shadow: 0.24, shadowColor: '#7a1206', blurSd: 1.2 },
};

module.exports = [{ name: 'Backpack', draw: (k, K) => pack(k, K, RED) }];
module.exports.pack = pack;
