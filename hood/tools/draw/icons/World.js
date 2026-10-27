// World: a flat globe. Pale-blue sea disc lit from the upper left, a saturated azure band round the lower right,
// big fat green continents (the Americas on the left, Europe / Africa on the right), darker where they cross the band.
'use strict';

module.exports = {
	name: 'World',
	draw(k, K) {
		const R = 199, C = [256, 256];
		const P = (u, v) => [C[0] + u * R, C[1] + v * R];
		const S = (pts) => K.smooth(pts.map(([u, v, c]) => (c ? [...P(u, v), c] : P(u, v))), true, 0.62);
		const disc = K.circle(C[0], C[1], R);
		const inner = K.circle(C[0] - 0.19 * R, C[1] - 0.2 * R, 0.83 * R);

		// chunky rounded lobes; a round stroke of the land colour (below) fattens every tip a little
		const lands = [
			// North America (top left): its bottom runs down-left to the gulf's round tip, where it meets the arm below
			S([[-1.2, -1.2], [-0.46, -1.2], [-0.42, -1.0], [-0.34, -0.9], [-0.26, -0.8], [-0.21, -0.68], [-0.23, -0.58],
				[-0.32, -0.51], [-0.45, -0.48], [-0.57, -0.45], [-0.67, -0.4], [-0.75, -0.33], [-0.82, -0.24], [-1.2, -0.16]]),
			// Central + South America: the arm along the gulf, a notch, a big round shoulder, a short round tail
			S([[-1.2, -0.42], [-0.88, -0.4], [-0.76, -0.31], [-0.64, -0.25], [-0.47, -0.2], [-0.35, -0.15], [-0.26, -0.1], [-0.2, -0.06], [-0.13, -0.12], [-0.04, -0.15],
				[0.08, -0.1], [0.16, 0.0], [0.13, 0.12], [0.02, 0.19], [-0.06, 0.3], [-0.09, 0.44], [-0.13, 0.58], [-0.15, 0.72],
				[-0.22, 0.8], [-0.3, 0.74], [-0.31, 0.6], [-0.38, 0.44], [-0.47, 0.28], [-0.56, 0.16], [-0.66, 0.0], [-0.78, -0.12],
				[-0.92, -0.2], [-1.2, -0.2]]),
			// Greenland
			S([[-0.2, -1.12], [0.04, -1.12], [0.03, -0.9], [-0.04, -0.8], [-0.13, -0.82], [-0.18, -0.94]]),
			// Europe
			S([[0.13, -1.06], [0.13, -0.84], [0.2, -0.74], [0.3, -0.71], [0.42, -0.75], [0.54, -0.8], [0.6, -0.97]]),
			// Africa, hugging the right rim
			S([[0.36, -0.33], [0.58, -0.37], [0.85, -0.37], [1.2, -0.4], [1.2, 0.7], [0.8, 0.6], [0.74, 0.46], [0.7, 0.3],
				[0.66, 0.12], [0.55, 0.04], [0.4, -0.04], [0.32, -0.16], [0.31, -0.3]]),
		];
		const landG = lands.map((d) => `<path d="${d}"/>`).join('');

		let body = '';
		body += k.path(disc, '#3ab4f8');
		body += k.clip(disc, `<path d="${inner}" fill="#94dbfa" ${k.blur(1.2)}/>`);
		// land: dark green over the band, light green over the pale disc
		const fat = `stroke-width="${0.035 * R}" stroke-linejoin="round"`;
		body += k.clip(disc, `<g fill="#47b837" stroke="#47b837" ${fat}>${landG}</g>`);
		body += k.clip(disc, k.clip(inner, `<g fill="#64d468" stroke="#64d468" ${fat}>${landG}</g>`));
		return { sil: [disc], body };
	},
};
