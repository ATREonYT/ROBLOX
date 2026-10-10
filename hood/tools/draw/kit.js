// kit.js: the style kit for the drawn UI icons (brief 26).
//
// Every icon is a vector drawing in a 512 x 512 working space. An icon module returns
//   { sil: [pathD, ...], body: '<svg markup>' }
// where `sil` is the silhouette (the union of these paths gets the thick navy outline) and `body` is the coloured
// drawing on top. build.js frames it (longest side = 0.879 of the canvas, outline included) and renders the PNG.
//
// The style, as measured on the reference icons:
//  - one thick even navy outline round the silhouette (OUTLINE_PX on the 512 canvas, about 5.8% of the object);
//  - soft gentle shading: bright saturated colours, shadow side only 15-20% darker, soft-edged shade shapes;
//  - thin sharp white streak glints on the top-left edges and the tips;
//  - subtle raised rounded square tiles on hard surfaces (semi-transparent white with a soft bevel), big and sparse.

'use strict';

const NAVY = '#07071a'; // near-black with a hint of navy (the refs' outlines measure #000000 to #020433)
const OUTLINE_PX = 25; // visible outline band on the final 512 canvas

// ---------------------------------------------------------------- colour helpers
function hex2rgb(h) {
	h = h.replace('#', '');
	if (h.length === 3) h = h.split('').map((c) => c + c).join('');
	return [0, 2, 4].map((i) => parseInt(h.slice(i, i + 2), 16));
}
function rgb2hex(r, g, b) {
	return '#' + [r, g, b].map((v) => Math.max(0, Math.min(255, Math.round(v))).toString(16).padStart(2, '0')).join('');
}
// mix(a, b, t): t = 0 gives a, 1 gives b
function mix(a, b, t) {
	const A = hex2rgb(a), B = hex2rgb(b);
	return rgb2hex(A[0] + (B[0] - A[0]) * t, A[1] + (B[1] - A[1]) * t, A[2] + (B[2] - A[2]) * t);
}
const darker = (c, t) => mix(c, '#000000', t);
const lighter = (c, t) => mix(c, '#ffffff', t);

// ---------------------------------------------------------------- geometry helpers
const f = (n) => (Math.round(n * 100) / 100).toString();
const pt = (p) => f(p[0]) + ' ' + f(p[1]);

function poly(pts, closed = true) {
	return 'M' + pts.map(pt).join(' L') + (closed ? ' Z' : '');
}

// Catmull-Rom spline through the points, as cubic Beziers. `t` is the tension (0.5 = classic).
// A point given as [x, y, 'c'] is a sharp corner (the curve does not round it).
function smooth(pts, closed = true, t = 0.5) {
	const n = pts.length;
	const P = (i) => (closed ? pts[(i + n) % n] : pts[Math.max(0, Math.min(n - 1, i))]);
	let d = 'M' + pt(pts[0]);
	const segs = closed ? n : n - 1;
	for (let i = 0; i < segs; i++) {
		const p0 = P(i - 1), p1 = P(i), p2 = P(i + 1), p3 = P(i + 2);
		const k1 = p1[2] === 'c' ? 0 : t / 3, k2 = p2[2] === 'c' ? 0 : t / 3;
		const c1 = [p1[0] + (p2[0] - p0[0]) * k1, p1[1] + (p2[1] - p0[1]) * k1];
		const c2 = [p2[0] - (p3[0] - p1[0]) * k2, p2[1] - (p3[1] - p1[1]) * k2];
		d += ' C' + pt(c1) + ' ' + pt(c2) + ' ' + pt(p2);
	}
	return d + (closed ? ' Z' : '');
}

// Polygon with rounded corners. r is a number or an array (one radius per corner).
function roundPoly(pts, r) {
	const n = pts.length;
	let d = '';
	for (let i = 0; i < n; i++) {
		const p0 = pts[(i - 1 + n) % n], p1 = pts[i], p2 = pts[(i + 1) % n];
		const rr = Array.isArray(r) ? r[i] : r;
		const v1 = [p0[0] - p1[0], p0[1] - p1[1]], v2 = [p2[0] - p1[0], p2[1] - p1[1]];
		const l1 = Math.hypot(...v1), l2 = Math.hypot(...v2);
		const k = Math.min(rr, l1 / 2, l2 / 2);
		const a = [p1[0] + (v1[0] / l1) * k, p1[1] + (v1[1] / l1) * k];
		const b = [p1[0] + (v2[0] / l2) * k, p1[1] + (v2[1] / l2) * k];
		d += (i === 0 ? 'M' : ' L') + pt(a) + ' Q' + pt(p1) + ' ' + pt(b);
	}
	return d + ' Z';
}

function circle(cx, cy, r) {
	return `M${f(cx - r)} ${f(cy)} A${f(r)} ${f(r)} 0 1 0 ${f(cx + r)} ${f(cy)} A${f(r)} ${f(r)} 0 1 0 ${f(cx - r)} ${f(cy)} Z`;
}
function ellipse(cx, cy, rx, ry, rot = 0) {
	const pts = [];
	for (let i = 0; i < 48; i++) {
		const a = (i / 48) * Math.PI * 2;
		pts.push(rotp([cx + rx * Math.cos(a), cy + ry * Math.sin(a)], [cx, cy], rot));
	}
	return smooth(pts, true, 0.5);
}
function rect(x, y, w, h, r = 0) {
	return roundPoly([[x, y], [x + w, y], [x + w, y + h], [x, y + h]], r);
}
function rotp(p, c, deg) {
	const a = (deg * Math.PI) / 180, s = Math.sin(a), co = Math.cos(a);
	const x = p[0] - c[0], y = p[1] - c[1];
	return [c[0] + x * co - y * s, c[1] + x * s + y * co];
}
const lerp = (a, b, t) => [a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t];

// Sample a Catmull-Rom curve through pts (open) into n points.
function sampleCurve(pts, n) {
	const out = [];
	const m = pts.length;
	const P = (i) => pts[Math.max(0, Math.min(m - 1, i))];
	for (let s = 0; s <= n; s++) {
		const u = (s / n) * (m - 1);
		const i = Math.min(m - 2, Math.floor(u));
		const t = u - i;
		const p0 = P(i - 1), p1 = P(i), p2 = P(i + 1), p3 = P(i + 2);
		const t2 = t * t, t3 = t2 * t;
		const c = (a, b, c2, d) => 0.5 * (2 * b + (-a + c2) * t + (2 * a - 5 * b + 4 * c2 - d) * t2 + (-a + 3 * b - 3 * c2 + d) * t3);
		out.push([c(p0[0], p1[0], p2[0], p3[0]), c(p0[1], p1[1], p2[1], p3[1])]);
	}
	return out;
}

// a silhouette piece: a path string ('!' prefix = keep holes) or { d, t } with an SVG transform
function silPath(x, rule) {
	if (typeof x === 'string') return x[0] === '!' ? `<path d="${x.slice(1)}" ${rule}="evenodd"/>` : `<path d="${x}"/>`;
	const d = x.d[0] === '!' ? x.d.slice(1) : x.d;
	return `<path d="${d}"${x.t ? ` transform="${x.t}"` : ''}${x.d[0] === '!' ? ` ${rule}="evenodd"` : ''}/>`;
}

// ---------------------------------------------------------------- the icon builder
class Kit {
	constructor(name) {
		this.name = name;
		this.n = 0;
		this.defs = [];
		this.NAVY = NAVY;
	}
	id(p = 'k') {
		return `${this.name}_${p}${++this.n}`;
	}
	def(s) {
		this.defs.push(s);
	}

	// <g clip-path> around `content`, clipped to the path d (or several paths)
	clip(d, content, extra = '') {
		const id = this.id('c');
		const ds = Array.isArray(d) ? d : [d];
		this.def(`<clipPath id="${id}">${ds.map((x) => `<path d="${x}"/>`).join('')}</clipPath>`);
		return `<g clip-path="url(#${id})"${extra}>${content}</g>`;
	}
	// a Gaussian blur filter of standard deviation sd (cached)
	blur(sd) {
		const id = `${this.name}_blur${String(sd).replace('.', 'p')}`;
		if (!this.defs.some((x) => x.includes(`id="${id}"`)))
			this.def(`<filter id="${id}" x="-60%" y="-60%" width="220%" height="220%" color-interpolation-filters="sRGB"><feGaussianBlur stdDeviation="${sd}"/></filter>`);
		return `filter="url(#${id})"`;
	}
	// linear gradient in user space: stops = [[offset, colour, opacity?], ...]
	lin(x1, y1, x2, y2, stops) {
		const id = this.id('g');
		this.def(`<linearGradient id="${id}" gradientUnits="userSpaceOnUse" x1="${f(x1)}" y1="${f(y1)}" x2="${f(x2)}" y2="${f(y2)}">` +
			stops.map((s) => `<stop offset="${s[0]}" stop-color="${s[1]}" stop-opacity="${s[2] === undefined ? 1 : s[2]}"/>`).join('') +
			'</linearGradient>');
		return `url(#${id})`;
	}
	rad(cx, cy, r, stops, fx, fy) {
		const id = this.id('g');
		this.def(`<radialGradient id="${id}" gradientUnits="userSpaceOnUse" cx="${f(cx)}" cy="${f(cy)}" r="${f(r)}"` +
			(fx !== undefined ? ` fx="${f(fx)}" fy="${f(fy)}"` : '') + '>' +
			stops.map((s) => `<stop offset="${s[0]}" stop-color="${s[1]}" stop-opacity="${s[2] === undefined ? 1 : s[2]}"/>`).join('') +
			'</radialGradient>');
		return `url(#${id})`;
	}

	path(d, fill, extra = '') {
		return `<path d="${d}" fill="${fill}"${extra ? ' ' + extra : ''}/>`;
	}
	// A soft shade: shape(s) d filled with colour, blurred by sd, kept inside clipD.
	soft(clipD, d, fill, sd, opacity = 1) {
		const ds = Array.isArray(d) ? d : [d];
		return this.clip(clipD, `<g ${this.blur(sd)} opacity="${opacity}">${ds.map((x) => `<path d="${x}" fill="${fill}"/>`).join('')}</g>`);
	}
	// A thin darker contour hint along an open curve.
	line(pts, color, w, extra = '') {
		return `<path d="${smooth(pts, false)}" fill="none" stroke="${color}" stroke-width="${f(w)}" stroke-linecap="round" stroke-linejoin="round"${extra ? ' ' + extra : ''}/>`;
	}

	// A crisp tapered white streak along a curve through pts. w = widest width. `bias` moves the widest point
	// (0.5 = middle, <0.5 toward the start). `side` = 0 centres the width on the curve, 1 / -1 grows it to one side.
	streak(pts, w, { color = '#ffffff', bias = 0.45, side = 0, opacity = 1, n = 40, power = 0.8 } = {}) {
		const c = sampleCurve(pts, n);
		const L = [], R = [];
		for (let i = 0; i <= n; i++) {
			const t = i / n;
			// width profile: rises to w at `bias`, falls to 0 at both ends
			const u = t < bias ? t / bias : (1 - t) / (1 - bias);
			const ww = w * Math.pow(Math.sin((u * Math.PI) / 2), power);
			const a = c[Math.max(0, i - 1)], b = c[Math.min(n, i + 1)];
			let nx = -(b[1] - a[1]), ny = b[0] - a[0];
			const l = Math.hypot(nx, ny) || 1;
			nx /= l; ny /= l;
			const lo = side === 0 ? -ww / 2 : side > 0 ? 0 : -ww;
			const hi = side === 0 ? ww / 2 : side > 0 ? ww : 0;
			L.push([c[i][0] + nx * hi, c[i][1] + ny * hi]);
			R.push([c[i][0] + nx * lo, c[i][1] + ny * lo]);
		}
		return `<path d="${poly(L.concat(R.reverse()))}" fill="${color}" opacity="${opacity}"/>`;
	}
	// A four-pointed glint star at (x, y), arms of length r (rx, ry), rotated rot degrees.
	flare(x, y, rx, ry = rx, rot = 0, color = '#ffffff', waist = 0.18) {
		const pts = [];
		for (let i = 0; i < 8; i++) {
			const a = (i * Math.PI) / 4;
			const big = i % 2 === 0;
			const rr = big ? 1 : waist;
			pts.push(rotp([x + Math.sin(a) * rr * (big ? rx : (rx + ry) / 2), y - Math.cos(a) * rr * (big ? ry : (rx + ry) / 2)], [x, y], rot));
		}
		// concave sides: quadratic curves through the waist points
		let d = 'M' + pt(pts[0]);
		for (let i = 0; i < 8; i += 2) d += ' Q' + pt(pts[i + 1]) + ' ' + pt(pts[(i + 2) % 8]);
		return `<path d="${d} Z" fill="${color}"/>`;
	}

	// Raised studs (the refs' "Roblox bricks"): soft-embossed rounded squares, a touch lighter than the surface, with a
	// gentle light top edge and a soft darker bottom edge. m = affine [a, b, c, d, e, f] from tile space (u, v) to the
	// drawing; cells = [[u, v], ...] are the studs' top-left corners in tile space; s = size, r = corner radius (tile
	// space). alpha = body lightness (white opacity), bevel = top highlight, shadow = bottom edge. clipD keeps them on
	// their face.
	tiles(clipD, m, cells, { s = 40, r = 8, alpha = 0.16, bevel = 0.5, shadow = 0.16, shadowColor = '#000030', blurSd = 0.9, edge = 0.1, body } = {}) {
		const gid = this.id('tb');
		const lite = body || '#ffffff';
		this.def(`<linearGradient id="${gid}" x1="0" y1="0" x2="0.25" y2="1">` +
			`<stop offset="0" stop-color="#fff" stop-opacity="${Math.min(1, alpha + bevel)}"/>` +
			`<stop offset="${Math.max(0.12, edge * 1.8)}" stop-color="${lite}" stop-opacity="${alpha}"/>` +
			`<stop offset="${1 - Math.max(0.14, edge * 2)}" stop-color="${lite}" stop-opacity="${alpha}"/>` +
			`<stop offset="1" stop-color="${shadowColor}" stop-opacity="${shadow}"/></linearGradient>`);
		let g = '';
		const inset = s * 0.03;
		for (const [u, v] of cells) {
			g += `<rect x="${f(u + inset)}" y="${f(v + inset)}" width="${f(s - 2 * inset)}" height="${f(s - 2 * inset)}" rx="${f(r)}" fill="url(#${gid})"/>`;
		}
		const inner = `<g transform="matrix(${m.map(f).join(' ')})" ${blurSd ? this.blur(blurSd) : ''}>${g}</g>`;
		return clipD ? this.clip(clipD, inner) : inner;
	}
	// grid helper: cells from (u0, v0), nu x nv tiles, pitch p
	grid(u0, v0, nu, nv, p, skip = () => false) {
		const out = [];
		for (let j = 0; j < nv; j++) for (let i = 0; i < nu; i++) if (!skip(i, j)) out.push([u0 + i * p, v0 + j * p]);
		return out;
	}

	// Place a sub-drawing { sil, body } under an SVG transform (e.g. 'translate(..) rotate(..) scale(..)'): its
	// silhouette pieces carry the transform, so the one outline still wraps the whole group.
	place(d, t) {
		return {
			sil: d.sil.map((x) => (typeof x === 'string' ? { d: x, t } : { ...x, t: t + ' ' + (x.t || '') })),
			body: `<g transform="${t}">${d.body}</g>`,
		};
	}
	// A dark separating edge drawn just before an item that sits in front of others in a pile (the refs keep a thin
	// ink line where a front object overlaps a back one). w = line width in working units.
	sep(sil, w) {
		return `<g fill="${NAVY}" stroke="${NAVY}" stroke-width="${f(w)}" stroke-linejoin="round">${sil.map((x) => silPath(x, 'fill-rule')).join('')}</g>`;
	}
	// Combine several placed drawings, back to front; `seps` = separator width for each item after the first (0 = none).
	group(items, sepW = 0) {
		let body = '';
		items.forEach((it, i) => { if (i && sepW) body += this.sep(it.sil, sepW); body += it.body; });
		return { sil: items.flatMap((it) => it.sil), body };
	}

	// Build the final SVG for given framing: view = [x, y, size] square in working space; ow = outline band in
	// working units; px = output size.
	svg(drawing, view, ow, px = 512) {
		// a silhouette path starting with '!' keeps its holes (fill-rule evenodd), e.g. a trigger guard
		const silG = drawing.sil.map((x) => silPath(x, 'fill-rule')).join('');
		// the outline: an even band, plus a copy nudged down-right so it runs a little heavier on the bottom-right
		// (the refs' ink is hand-made, not uniform)
		const og = (dx, dy, w) => `<g transform="translate(${f(dx)} ${f(dy)})" fill="${NAVY}" stroke="${NAVY}" stroke-width="${f(w * 2)}" stroke-linejoin="round" stroke-linecap="round">${silG}</g>`;
		let inner = og(0, 0, ow * 0.94) + og(ow * 0.1, ow * 0.2, ow * 0.94) +
			// the drawing stays inside the silhouette (a glint never pokes out over the outline)
			`<clipPath id="${this.name}_silclip">${drawing.sil.map((x) => silPath(x, 'clip-rule')).join('')}</clipPath>` +
			`<g clip-path="url(#${this.name}_silclip)">${drawing.body}</g>`;
		// see-through holes (the rebirth ring's centre): an ink rim round each, then cut clean through
		if (drawing.holes && drawing.holes.length) {
			const hs = drawing.holes.map((h) => (typeof h === 'string' ? { d: h } : h));
			inner += hs.map((h) => `<path d="${h.d}" fill="${NAVY}" stroke="${NAVY}" stroke-width="${f((h.ink === undefined ? ow : h.ink) * 2)}" stroke-linejoin="round"/>`).join('');
			const mid = `${this.name}_holes`;
			const m = `<mask id="${mid}" maskUnits="userSpaceOnUse" x="${f(view[0])}" y="${f(view[1])}" width="${f(view[2])}" height="${f(view[3])}">` +
				`<rect x="${f(view[0])}" y="${f(view[1])}" width="${f(view[2])}" height="${f(view[3])}" fill="#fff"/>` +
				hs.map((h) => `<path d="${h.d}" fill="#000"/>`).join('') + '</mask>';
			inner = m + `<g mask="url(#${mid})">${inner}</g>`;
		}
		return `<svg xmlns="http://www.w3.org/2000/svg" width="${px}" height="${px}" viewBox="${view.map(f).join(' ')}">` +
			`<defs>${this.defs.join('')}</defs>${inner}</svg>`;
	}
}

// Camera for boxy objects: yaw turns the object about the vertical axis, pitch tilts it toward the viewer (positive =
// seen from above). Returns P(x, y, z) -> [sx, sy] with y up in the world, scale s, centre (cx, cy). persp = the eye's
// distance in object units for a perspective view (near parts bigger), 0 = orthographic.
function camera({ yaw = 30, pitch = 25, s = 1, cx = 256, cy = 256, persp = 0 } = {}) {
	const ya = (yaw * Math.PI) / 180, pa = (pitch * Math.PI) / 180;
	const rot = (x, y, z) => {
		const x1 = x * Math.cos(ya) + z * Math.sin(ya);
		const z1 = -x * Math.sin(ya) + z * Math.cos(ya);
		return [x1, y * Math.cos(pa) - z1 * Math.sin(pa), y * Math.sin(pa) + z1 * Math.cos(pa)]; // right, up, toward the eye
	};
	const P = (x, y, z) => {
		const [x1, y1, zc] = rot(x, y, z);
		const k = persp ? persp / (persp - zc) : 1;
		return [cx + x1 * s * k, cy - y1 * s * k];
	};
	P.depth = (x, y, z) => rot(x, y, z)[2]; // bigger = nearer the eye
	P.faces = (n) => rot(...n)[2] > 1e-6; // does a face with world normal n face the eye?
	// a 3D polygon's visibility from its own winding (counter-clockwise seen from outside = front)
	P.front = (pts) => {
		const [a, b, c] = pts;
		const u = [b[0] - a[0], b[1] - a[1], b[2] - a[2]], v = [c[0] - a[0], c[1] - a[1], c[2] - a[2]];
		return P.faces([u[1] * v[2] - u[2] * v[1], u[2] * v[0] - u[0] * v[2], u[0] * v[1] - u[1] * v[0]]);
	};
	return P;
}

// An axis-aligned box from (x0, y0, z0) to (x1, y1, z1): its six faces, each wound counter-clockwise from outside,
// keyed by the outward direction.
function box3(x0, y0, z0, x1, y1, z1) {
	return {
		top: [[x0, y1, z0], [x0, y1, z1], [x1, y1, z1], [x1, y1, z0]],
		bottom: [[x0, y0, z0], [x1, y0, z0], [x1, y0, z1], [x0, y0, z1]],
		front: [[x0, y0, z1], [x1, y0, z1], [x1, y1, z1], [x0, y1, z1]],
		back: [[x1, y0, z0], [x0, y0, z0], [x0, y1, z0], [x1, y1, z0]],
		left: [[x0, y0, z0], [x0, y0, z1], [x0, y1, z1], [x0, y1, z0]],
		right: [[x1, y0, z1], [x1, y0, z0], [x1, y1, z0], [x1, y1, z1]],
	};
}

// tile-space matrix for a 3D quad face [p0, p1, p2, p3] in world units: u along p3 -> p2, v along p3 -> p0
function faceM(P, f) {
	const o = P(...f[3]), eu = P(...f[2]), ev = P(...f[0]);
	const L = (p, q) => Math.hypot(p[0] - q[0], p[1] - q[1], p[2] - q[2]);
	const lu = L(f[3], f[2]), lv = L(f[3], f[0]);
	return [(eu[0] - o[0]) / lu, (eu[1] - o[1]) / lu, (ev[0] - o[0]) / lv, (ev[1] - o[1]) / lv, o[0], o[1]];
}
// size of a face in world units: [width along p3 -> p2, height along p3 -> p0]
function faceSize(f) {
	const L = (p, q) => Math.hypot(p[0] - q[0], p[1] - q[1], p[2] - q[2]);
	return [L(f[3], f[2]), L(f[3], f[0])];
}

module.exports = {
	NAVY, OUTLINE_PX, Kit, camera, box3, faceM, faceSize, silPath,
	mix, darker, lighter, hex2rgb, rgb2hex,
	f, pt, poly, smooth, roundPoly, circle, ellipse, rect, rotp, lerp, sampleCurve,
};

// ---------------------------------------------------------------- 2.5D extrusion
// The face polygon pts (screen coords) pushed back by the offset o = [ox, oy]: the walls that face the viewer are the
// edges whose outward normal points along o. Returns { back, walls: [[p0, p1, p1o, p0o, t0, t1, edgeIndex]...] }.
function extrude(pts, o) {
	const n = pts.length;
	// orientation: positive area = clockwise on screen (y down)
	let A = 0;
	for (let i = 0; i < n; i++) { const p = pts[i], q = pts[(i + 1) % n]; A += p[0] * q[1] - q[0] * p[1]; }
	const cw = A > 0;
	const walls = [];
	for (let i = 0; i < n; i++) {
		const p = pts[i], q = pts[(i + 1) % n];
		const dx = q[0] - p[0], dy = q[1] - p[1];
		// outward normal
		let nx = cw ? dy : -dy, ny = cw ? -dx : dx;
		const l = Math.hypot(nx, ny) || 1; nx /= l; ny /= l;
		const vis = nx * o[0] + ny * o[1];
		if (vis > 1e-6) walls.push({ i, p, q, po: [p[0] + o[0], p[1] + o[1]], qo: [q[0] + o[0], q[1] + o[1]], vis, n: [nx, ny] });
	}
	return { back: pts.map((p) => [p[0] + o[0], p[1] + o[1]]), walls };
}
// Arc points from angle a0 to a1 (degrees, screen: 0 = right, 90 = down), radius r about c.
function arc(c, r, a0, a1, step = 3) {
	const n = Math.max(2, Math.ceil(Math.abs(a1 - a0) / step));
	const out = [];
	for (let i = 0; i <= n; i++) {
		const a = ((a0 + ((a1 - a0) * i) / n) * Math.PI) / 180;
		out.push([c[0] + r * Math.cos(a), c[1] + r * Math.sin(a)]);
	}
	return out;
}
module.exports.extrude = extrude;
module.exports.arc = arc;
