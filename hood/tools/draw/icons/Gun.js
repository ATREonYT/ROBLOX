// Gun: a chunky grey cartoon pistol, side view, muzzle to the right, seen a touch from above (a lighter top face on the
// slide). Rear and front sights, three grip lines on the slide's back, the frame and trigger guard (a real hole), a
// trigger, and a brown grip angled down-left with subtle tiles. White slivers on the slide's top-left and the muzzle edge.
'use strict';

function pistol(k, K, c) {
	const U = 205, C = [256, 256];
	const P = ([u, v]) => [C[0] + u * U, C[1] + v * U];
	const RP = (pts, r) => K.roundPoly(pts.map(P), r * U);
	const S = (pts, t = 0.5) => K.smooth(pts.map(P), true, t);

	const slide = RP([[-0.98, -0.5], [0.98, -0.5], [0.98, -0.02], [-0.98, -0.02]], 0.1);
	const slideTop = RP([[-0.94, -0.5], [0.94, -0.5], [0.94, -0.38], [-0.94, -0.38]], 0.06);
	const rear = RP([[-0.9, -0.62], [-0.7, -0.62], [-0.7, -0.46], [-0.9, -0.46]], 0.04);
	const front = RP([[0.72, -0.6], [0.86, -0.6], [0.86, -0.46], [0.72, -0.46]], 0.04);
	const frame = RP([[-0.86, -0.06], [0.72, -0.06], [0.72, 0.14], [-0.2, 0.14], [-0.86, 0.14]], 0.06);
	const grip = RP([[-0.88, -0.04], [-0.32, -0.04], [-0.4, 0.3], [-0.52, 0.88], [-0.98, 0.88], [-0.98, 0.3]], 0.12);
	const guardOuter = S([[-0.34, 0.08], [0.18, 0.08], [0.26, 0.24], [0.16, 0.44], [-0.1, 0.48], [-0.32, 0.4]]);
	const guardInner = S([[-0.26, 0.14], [0.1, 0.14], [0.14, 0.26], [0.06, 0.36], [-0.12, 0.38], [-0.26, 0.32]]);
	const trigger = S([[-0.06, 0.12], [0.02, 0.12], [0.0, 0.26], [-0.06, 0.32], [-0.08, 0.24]]);
	const muzzle = K.ellipse(...P([0.93, -0.26]), 0.035 * U, 0.1 * U);

	let g = '';
	g += k.path(grip, c.grip);
	g += k.soft(grip, RP([[-0.5, 0.0], [0.0, 0.0], [-0.3, 1.0], [-0.6, 1.0]], 0), c.gripDark, 8, 0.8);
	g += k.tiles(grip, [1, 0, 0, 1, 0, 0], [[-0.86, 0.12], [-0.6, 0.12], [-0.88, 0.42], [-0.66, 0.42], [-0.88, 0.68]].map(P),
		{ s: 0.2 * U, r: 0.045 * U, alpha: 0.14, bevel: 0.4, shadow: 0.22, shadowColor: '#3a1500' });
	g += `<path d="${guardOuter} ${guardInner}" fill="${c.frame}" fill-rule="evenodd"/>`;
	g += k.path(trigger, c.frameDark);
	g += k.path(frame, c.frame);
	g += k.path(rear, c.slideDark) + k.path(front, c.slideDark);
	g += k.path(slide, c.slide);
	g += k.path(slideTop, c.slideTop);
	g += k.soft(slide, RP([[-1.1, -0.18], [1.1, -0.18], [1.1, 0.1], [-1.1, 0.1]], 0), c.slideDark, 5, 0.6);
	g += k.tiles(slide, [1, 0, 0, 1, 0, 0], [[-0.3, -0.34], [-0.02, -0.34], [0.26, -0.34], [0.54, -0.34]].map(P),
		{ s: 0.22 * U, r: 0.05 * U, alpha: 0.14, bevel: 0.45, shadow: 0.2, shadowColor: '#2a3442' });
	for (const x of [-0.78, -0.68, -0.58]) g += k.path(RP([[x, -0.34], [x + 0.045, -0.34], [x + 0.045, -0.1], [x, -0.1]], 0.02), c.slideDark);
	g += k.path(muzzle, c.hole);
	// highlights: a sliver along the slide's top-left, a sliver down the muzzle edge
	g += k.streak([P([-0.4, -0.45]), P([-0.7, -0.45]), P([-0.92, -0.42]), P([-0.95, -0.25])], 0.065 * U, { bias: 0.55, power: 0.7 });
	g += k.streak([P([0.92, -0.44]), P([0.95, -0.3]), P([0.94, -0.12])], 0.04 * U, { bias: 0.3, power: 0.6 });
	return { sil: [slide, rear, front, frame, grip, '!' + guardOuter + ' ' + guardInner], body: g };
}

const GREY = {
	slide: '#a9b3c2', slideTop: '#cdd5e0', slideDark: '#8590a2', frame: '#7f8a9c', frameDark: '#5f6a7c', hole: '#2a3040',
	grip: '#a8612e', gripDark: '#8c4c22',
};

module.exports = [{ name: 'Gun', draw: (k, K) => pistol(k, K, GREY) }];
module.exports.pistol = pistol;
