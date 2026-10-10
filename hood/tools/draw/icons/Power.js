// Power: the flexed orange arm. A slim forearm rising on the left with the fist folded into its top (pointing
// right), a notch, a big round bicep low on the right, a long bumpy underside. Two tones: light top-left, darker
// orange strip down the left edge, the underside, a shade under the fist and the knuckle bump. A thin white arc.
'use strict';

function arm(k, K, { light = '#feb222', dark = '#fb8c22', mid = '#fb9a25', deep = '#f77a1f' } = {}) {
	const U = 220, C = [256 - 0.025 * U, 256 - 0.015 * U];
	const P = ([u, v, c]) => (c ? [C[0] + u * U, C[1] + v * U, c] : [C[0] + u * U, C[1] + v * U]);
	const S = (pts, t = 0.5) => K.smooth(pts.map(P), true, t);
	const O = (pts) => K.smooth(pts.map(P), false, 0.5);

	const outline = S([
		[-0.62, 0.9], [-0.82, 0.8], [-0.91, 0.58], [-0.89, 0.3], [-0.81, 0.04], [-0.73, -0.24], [-0.67, -0.48], [-0.64, -0.66],
		[-0.55, -0.79], [-0.37, -0.85], [-0.15, -0.84], [0.04, -0.78], [0.17, -0.69], [0.23, -0.58], [0.235, -0.48], [0.2, -0.42],
		[0.245, -0.34], [0.215, -0.27], [0.12, -0.235], [0.04, -0.2], [0.01, -0.13], [0.04, -0.06], [0.14, -0.06], [0.28, -0.14],
		[0.44, -0.2], [0.62, -0.21], [0.79, -0.13], [0.91, 0.04], [0.95, 0.26], [0.91, 0.47], [0.8, 0.62], [0.62, 0.7], [0.47, 0.705],
		[0.36, 0.79], [0.18, 0.865], [-0.01, 0.875], [-0.15, 0.83], [-0.28, 0.88], [-0.45, 0.905],
	], 0.5);

	let b = '';
	b += k.path(outline, light);
	// soft shade shapes
	b += k.soft(outline, [
		// the left edge of the forearm
		S([[-1.2, 1.2], [-1.2, -1.2], [-0.45, -1.2], [-0.45, -0.8], [-0.47, -0.55], [-0.52, -0.3], [-0.58, -0.02], [-0.65, 0.3], [-0.67, 0.6], [-0.58, 1.2]]),
	], dark, 2.2);
	b += k.soft(outline, [
		// the underside: mid tone below a wavy line
		S([[-1.2, 0.6], [-0.7, 0.6], [-0.45, 0.64], [-0.2, 0.6], [0.05, 0.66], [0.3, 0.62], [0.5, 0.52], [0.75, 0.46], [1.2, 0.36], [1.2, 1.4], [-1.2, 1.4]]),
	], mid, 3);
	b += k.soft(outline, [
		// the bottom rim of each bump, a bit darker again
		S([[-1.2, 0.76], [-0.6, 0.8], [-0.3, 0.84], [-0.16, 0.74], [0.05, 0.8], [0.3, 0.74], [0.46, 0.6], [0.7, 0.58], [1.2, 0.5], [1.2, 1.4], [-1.2, 1.4]]),
	], dark, 3, 0.75);
	b += k.soft(outline, [
		// the crook: a small shade wedge where the bicep meets the forearm
		S([[0.0, -0.14], [0.12, -0.08], [0.26, -0.06], [0.2, 0.04], [0.04, 0.1], [-0.06, 0.04]]),
	], deep, 1.6, 0.95);
	b += k.soft(outline, [
		// under the fist: a soft darker band that sets the fist off from the forearm
		S([[-0.62, -0.42], [-0.3, -0.34], [0.02, -0.22], [0.1, -0.12], [-0.1, -0.1], [-0.4, -0.2], [-0.64, -0.3]]),
	], mid, 5, 0.85);
	b += k.soft(outline, [
		// the knuckle bump on the fist's front, as a shade
		S([[0.08, -0.6], [0.2, -0.62], [0.28, -0.46], [0.26, -0.3], [0.14, -0.26], [0.06, -0.4]]),
	], deep, 3.5, 0.75);

	// thin white arc on the fist's top-left; the spark merged into the crook as a small white wedge
	b += k.streak([P([-0.24, -0.8]), P([-0.42, -0.75]), P([-0.53, -0.62]), P([-0.57, -0.46])], 0.05 * U, { bias: 0.4, power: 0.6 });
	b += k.streak([P([0.24, -0.04]), P([0.38, -0.12]), P([0.52, -0.15])], 0.045 * U, { bias: 0.25, power: 0.55 });
	return { sil: [outline], body: b };
}

module.exports = [
	{ name: 'Power', draw: (k, K) => arm(k, K) },
];
module.exports.arm = arm;
