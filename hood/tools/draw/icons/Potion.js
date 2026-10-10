// Potions: a star-shaped glass bottle (the top point is the neck) with a short wide squared neck and a big blocky
// gold cork. A thick light-cyan glass wall round a mid-cyan inside, the inner star's top point showing as pale ridges,
// coloured liquid in the lower star (a lighter surface band, a darker star base), ghosted tiles, a bold white glare
// down the left and a sharp white streak on the right arm.
'use strict';

const K0 = require('../kit');

// the bottle outline in units (u right, v down), centred near the star's middle
const OUT = [
	[-0.48, -0.64, 'c'], [-0.48, -0.19, 'c'], [-0.95, -0.15, 'c'], [-0.93, 0.15, 'c'], [-0.55, 0.42, 'c'], [-0.67, 0.9, 'c'],
	[-0.02, 0.68, 'c'], [0.63, 0.9, 'c'], [0.51, 0.42, 'c'], [0.89, 0.15, 'c'], [0.91, -0.15, 'c'], [0.44, -0.19, 'c'],
	[0.44, -0.64, 'c'],
];

function bottle(k, K, liq, { U = 205, C = [256 + 0.02 * 205, 256 - 0.04 * 205], rot = 0, shift = [0, 0], tag = '', neck = 0 } = {}) {
	const P0 = ([u, v]) => [C[0] + u * U + shift[0], C[1] + v * U + shift[1]];
	const P = (p) => (rot ? K.rotp(P0(p), [C[0] + shift[0], C[1] + 0.1 * U + shift[1]], rot) : P0(p));
	const RP = (pts, r) => K.roundPoly(pts.map(P), r * U);
	const poly = (pts) => K.poly(pts.map(P));

	// outer glass: rounded star + neck (neck > 0 lengthens the neck, for the bundle where the bottles are small)
	const OUTn = OUT.map(([u, v, c]) => (v < -0.6 ? [u, v - neck, c] : [u, v, c]));
	const glass = RP(OUTn, 0.06);
	// inner volume: the same star inset (the thick glass wall)
	const IN = [
		[-0.33, -0.52], [-0.33, -0.05], [-0.77, -0.02], [-0.76, 0.09], [-0.41, 0.35], [-0.5, 0.75], [-0.02, 0.55],
		[0.46, 0.75], [0.37, 0.35], [0.72, 0.09], [0.73, -0.02], [0.29, -0.05], [0.29, -0.52],
	];
	const INn = IN.map(([u, v]) => (v < -0.5 ? [u, v - neck] : [u, v]));
	const up = (pts) => pts.map(([u, v]) => [u, v - neck]);
	const inner = RP(INn, 0.05);
	// liquid: everything of the inner volume below the surface line (just above the arms), a lighter top band
	const liquidCut = poly([[-1.2, 0.13], [1.2, 0.11], [1.2, 1.3], [-1.2, 1.3]]);
	const surface = poly([[-1.2, 0.13], [1.2, 0.11], [1.2, 0.29], [-1.2, 0.31]]);
	// the big blocky cork: top face, front face, lower lip
	// a trapezoid cork, wider at the top, with an orange underside
	const corkTop = poly(up([[-0.4, -1.08], [0.36, -1.08], [0.34, -0.9], [-0.38, -0.9]]));
	const corkFront = poly(up([[-0.38, -0.9], [0.34, -0.9], [0.28, -0.68], [-0.32, -0.68]]));
	const corkLip = poly(up([[-0.33, -0.7], [0.29, -0.7], [0.26, -0.56], [-0.3, -0.56]]));
	const cork = RP(up([[-0.41, -1.09], [0.37, -1.09], [0.27, -0.56], [-0.31, -0.56]]), 0.035);
	// neck top face
	const neckTop = poly(up([[-0.5, -0.7], [0.46, -0.7], [0.46, -0.52], [-0.5, -0.52]]));

	let g = '';
	g += k.path(glass, liq.wall);
	// the thick glass wall in light and dark triangular facets (each wall quad split along its diagonal)
	for (let i = 0; i < OUTn.length; i++) {
		if (i === OUTn.length - 1) continue; // the neck's top edge sits under the cork
		const o0 = OUTn[i], o1 = OUTn[(i + 1) % OUTn.length], i0 = INn[i], i1 = INn[(i + 1) % INn.length];
		const ex = o1[0] - o0[0], ey = o1[1] - o0[1], l = Math.hypot(ex, ey) || 1;
		const n = [ey / l, -ex / l]; // outward normal (the outline runs clockwise on screen)
		const lit = -(n[0] * 0.55 + n[1] * 0.83);
		const colA = lit > 0 ? K.mix(liq.wall, '#ffffff', 0.55 * lit) : K.mix(liq.wall, liq.facetDark, -0.6 * lit);
		const colB = lit > 0 ? K.mix(liq.wall, '#ffffff', 0.3 * lit) : K.mix(liq.wall, liq.facetDark, -0.35 * lit);
		g += k.clip(glass, k.path(poly([o0, o1, i1]), colA) + k.path(poly([o0, i1, i0]), colB));
	}
	// the neck's top face, lighter
	g += k.clip(glass, k.path(neckTop, liq.neckTop));
	// inner volume
	g += k.path(inner, liq.air);
	g += k.soft(inner, K.ellipse(...P([0, -0.3]), 0.5 * U, 0.3 * U), liq.airLit, 18, 0.7);
	// the inner star's top point: two pale ridges running down from the neck
	g += k.clip(inner, `<g opacity="0.6">` +
		k.path(poly([[-0.1, -0.36], [0.06, -0.36], [-0.44, 0.3], [-0.62, 0.26]]), liq.ridge, k.blur(1.5)) +
		k.path(poly([[-0.1, -0.36], [0.06, -0.36], [0.58, 0.26], [0.4, 0.3]]), liq.ridge, k.blur(1.5)) + '</g>');
	// liquid
	g += k.clip(inner, k.path(liquidCut, liq.front) +
		k.soft(liquidCut, poly([[-0.02, 0.36], [0.5, 0.42], [0.6, 1.2], [-0.02, 0.6], [-0.62, 1.2], [-0.2, 0.5]]), liq.deep, 4, 0.9) +
		k.path(surface, liq.top) +
		k.soft(surface, K.ellipse(...P([-0.1, 0.2]), 0.6 * U, 0.06 * U), liq.topLit, 6, 0.7));
	// ghosted tiles over glass and liquid
	g += k.tiles(glass, [1, 0, 0, 1, 0, 0], [[-0.02, -0.36], [-0.68, 0.0], [-0.3, 0.0], [0.26, 0.0], [0.64, 0.0], [-0.02, 0.06], [-0.3, 0.42], [0.26, 0.42],
		[-0.48, 0.74], [0.44, 0.74], [-0.02, 0.36]].map(([u, v]) => P([u - 0.13, v - 0.13])), { s: 0.26 * U, r: 0.065 * U, ...liq.tiles });
	// a bold white glare down the left (neck and the left arm's top edge), a sharp streak on the right arm
	// highlights: one bold white glare down the neck's left, one sparkle on the right arm's tip
	g += k.clip(inner, k.streak([P([-0.26, -0.56 - neck]), P([-0.27, -0.36]), P([-0.3, -0.08]), P([-0.5, 0.0])], 0.1 * U, { bias: 0.35, power: 0.5, opacity: 0.9 }));
	g += k.streak([P([0.5, -0.17]), P([0.7, -0.16]), P([0.88, -0.13])], 0.05 * U, { bias: 0.7, power: 0.6 });
	// cork
	g += k.path(cork, liq.corkFront);
	g += k.clip(cork, k.path(corkTop, liq.corkTop) + k.path(corkFront, liq.corkFront) + k.path(corkLip, liq.corkLip) +
		k.soft(corkFront, poly(up([[0.12, -0.86], [0.4, -0.86], [0.4, -0.5], [0.12, -0.5]])), liq.corkShade, 4, 0.6));
	g += k.tiles(cork, [1, 0, 0, 1, 0, 0], up([[-0.15, -1.07], [-0.13, -0.87]]).map(P), { s: 0.2 * U, r: 0.045 * U, alpha: 0.22, bevel: 0.5, shadow: 0.2, shadowColor: '#7a3a00' });
	return { sil: [glass, cork], body: g };
}

const RED = {
	wall: '#bfe8fa', facetDark: '#78b9d8', neckTop: '#e4f7fe', air: '#7fdcf7', airLit: '#9fe6fa', ridge: '#c6ecfb',
	front: '#e9304f', deep: '#cc1d3d', top: '#f58ba3', topLit: '#fba9bb',
	corkTop: '#ffe25a', corkFront: '#ffc02a', corkLip: '#f8860c', corkShade: '#f4a018',
	tiles: { alpha: 0.18, bevel: 0.55, shadow: 0.2, shadowColor: '#1d5f80' },
};
const GOLD = { ...RED, front: '#ffc81a', deep: '#f29a08', top: '#ffe45a', topLit: '#fff09a' };
const BLUE = { ...RED, front: '#2a7ff2', deep: '#1656cc', top: '#6fb2fa', topLit: '#9ccafc' };

module.exports = [
	{ name: 'PotionRed', draw: (k, K) => bottle(k, K, RED) },
	{ name: 'PotionGold', draw: (k, K) => bottle(k, K, GOLD) },
	{
		// three star bottles grouped: gold back-left and blue back-right, tilted outward, the red one in front
		name: 'BoostBundle',
		draw(k, K) {
			const gold = k.place(bottle(k, K, GOLD, { neck: 0.22 }), 'translate(-175 -30) rotate(-24 256 256) scale(0.8) translate(64 64)');
			const blue = k.place(bottle(k, K, BLUE, { neck: 0.22 }), 'translate(175 -30) rotate(24 256 256) scale(0.8) translate(64 64)');
			const red = k.place(bottle(k, K, RED, { neck: 0.22 }), 'translate(0 70) scale(0.84) translate(48.8 48.8)');
			return k.group([gold, blue, red], 10);
		},
	},
];
module.exports.bottle = bottle;
module.exports.LIQ = { RED, GOLD, BLUE };
