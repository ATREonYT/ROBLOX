// The 10 armory guns (Gun_<Id>), drawn flat in side view (muzzle to the right) from each in-game model's own parts and
// palette (hood/tools/blender/models/guns.py -> Shared/Models/GunModels.lua): the same blocks, positions, sizes and
// colours, drawn in the icon kit (one ink outline, soft shading, a lighter top band on every block, studs poking up from
// the top faces, a few soft embossed tiles on the big faces, white slivers). The tier ladder follows the models: gold and
// gems from 7, a glow from 8 (Minigun red, Blaster violet, Diamond cyan), sparkles on 7 and 10.
'use strict';

const K = require('../kit');

// BoxKit palette (hood/tools/blender/boxkit.py)
const C = {
	white: '#f2f3f5', black: '#202228', ink: '#121318', gun: '#3a3e48', gunlight: '#5c6370', steel: '#969ca6', steeldark: '#707680',
	chrome: '#ccd2da', rust: '#be622e', rustdark: '#8a4222', wood: '#b26838', woodlight: '#ce844a', wooddark: '#764224', brown: '#7c4c30',
	gold: '#ffc430', golddark: '#de961c', brass: '#e8b048', red: '#e83034', shell: '#d6282c', olive: '#627040', olivedark: '#48542e',
	yellow: '#ffd634', orange: '#ff8c28', green: '#4cd964', blue: '#409cff', purple: '#aa55ff', pink: '#ff5ac8', cyan: '#3ce6ff',
	cyandark: '#14aad2', violet: '#a056e2', violetneon: '#c46eff', diamond: '#78e6ff', diamonddeep: '#3caaf0',
};
const rad = (a) => (a * Math.PI) / 180;

// A drawing context in model units (DU): y up, z toward the back (the muzzle is at -z, drawn to the right).
function ctx(k, s) {
	const stack = [];
	const parts = [];
	// model (y, z) -> screen, through the group rotations (about x: y' = y cos a - z sin a, z' = y sin a + z cos a)
	const rotYZ = ([y, z], a, [oy, oz]) => {
		const dy = y - oy, dz = z - oz, c = Math.cos(rad(a)), sn = Math.sin(rad(a));
		return [oy + dy * c - dz * sn, oz + dy * sn + dz * c];
	};
	const toWorld = (p) => { for (let i = stack.length - 1; i >= 0; i--) p = rotYZ(p, stack[i].a, stack[i].o); return p; };
	const S = ([y, z]) => [256 - z * s, 256 - y * s];
	const W = (p) => S(toWorld(p));
	const G = {
		s,
		group(a, o, fn) { stack.push({ a, o }); fn(); stack.pop(); },
		// a box: centre (y, z), height h, length l; rot = its own rotation about x (degrees)
		box(y, z, h, l, col, { rot = 0, r = 0.1, top = true, studs = null, tiles = 0, sil = true, light = 0.3 } = {}) {
			const L = (yy, zz) => W(rotYZ([yy, zz], rot, [y, z]));
			const q = (pts) => K.roundPoly(pts.map(([yy, zz]) => L(yy, zz)), r * s);
			const y0 = y - h / 2, y1 = y + h / 2, z0 = z - l / 2, z1 = z + l / 2;
			const d = q([[y1, z1], [y1, z0], [y0, z0], [y0, z1]]);
			let g = k.path(d, col);
			if (top) {
				const tb = Math.min(0.32, h * 0.3);
				g += k.clip(d, k.path(K.poly([[y1 + 1, z1 + 1], [y1 + 1, z0 - 1], [y1 - tb, z0 - 1], [y1 - tb, z1 + 1]].map(([a, b]) => L(a, b))), K.lighter(col, light)));
			}
			// a soft darker band low on the face
			g += k.soft(d, K.poly([[y0 + h * 0.3, z1 + 1], [y0 + h * 0.3, z0 - 1], [y0 - 1, z0 - 1], [y0 - 1, z1 + 1]].map(([a, b]) => L(a, b))), K.darker(col, 0.14), 0.12 * s, 0.7);
			if (tiles) {
				const n = tiles, p = l / n, ts = Math.min(p * 0.7, h * 0.45);
				const cells = [];
				for (let i = 0; i < n; i++) cells.push(L(y - ts * 0.25, z0 + p * (i + 0.5)).map((v) => v - ts * s / 2));
				const lum = K.hex2rgb(col).reduce((a, b) => a + b, 0) / 765;
				if (lum >= 0.35) g += k.tiles(d, [1, 0, 0, 1, 0, 0], cells, { s: ts * s, r: ts * s * 0.22, alpha: lum < 0.35 ? 0.06 : 0.12, bevel: lum < 0.35 ? 0.2 : 0.34, shadow: 0.24, shadowColor: K.darker(col, 0.6), blurSd: 1.1 });
			}
			const sp = [];
			if (studs) for (const zz of studs) {
				const st = K.roundPoly([[y1 + 0.24, zz + 0.3], [y1 + 0.24, zz - 0.3], [y1 - 0.05, zz - 0.3], [y1 - 0.05, zz + 0.3]].map(([a, b]) => L(a, b)), 0.07 * s);
				g = k.path(st, K.lighter(col, light * 0.6)) + g;
				sp.push(st);
			}
			parts.push({ d: [d, ...sp], g, sil });
			return d;
		},
		// a cylinder along z (side view): centre (y, z), length l, diameter d; cap = draw the muzzle end face (+ bore)
		cyl(y, z, l, dm, col, { cap = false, bore = 0, rot = 0 } = {}) {
			const L = (yy, zz) => W(rotYZ([yy, zz], rot, [y, z]));
			const y0 = y - dm / 2, y1 = y + dm / 2, z0 = z - l / 2, z1 = z + l / 2;
			const d = K.roundPoly([[y1, z1], [y1, z0], [y0, z0], [y0, z1]].map(([a, b]) => L(a, b)), Math.min(0.08, dm * 0.2) * s);
			let g = k.path(d, col);
			g += k.clip(d, k.path(K.poly([[y + dm * 0.36, z1 + 1], [y + dm * 0.36, z0 - 1], [y + dm * 0.1, z0 - 1], [y + dm * 0.1, z1 + 1]].map(([a, b]) => L(a, b))), K.lighter(col, 0.35)));
			g += k.clip(d, k.path(K.poly([[y - dm * 0.22, z1 + 1], [y - dm * 0.22, z0 - 1], [y0 - 1, z0 - 1], [y0 - 1, z1 + 1]].map(([a, b]) => L(a, b))), K.darker(col, 0.16)));
			const ds = [d];
			if (cap) {
				const c = L(y, z0);
				const e = K.ellipse(c[0], c[1], dm * 0.2 * s, dm / 2 * s);
				g += k.path(e, K.lighter(col, 0.2));
				if (bore) g += k.path(K.ellipse(c[0] + dm * 0.02 * s, c[1], dm * 0.09 * s, bore / 2 * s), C.ink);
				ds.push(e);
			}
			parts.push({ d: ds, g, sil: true });
			return d;
		},
		// an octagonal prism along z (side view): the upper slope lighter, the side face, the lower slope darker
		oct(y, z, l, dm, col, { cap = false, bore = 0 } = {}) {
			const a = dm * 0.462, b = dm * 0.19;
			const y0 = y - a, y1 = y + a, z0 = z - l / 2, z1 = z + l / 2;
			const q = (pts) => K.poly(pts.map(([yy, zz]) => W([yy, zz])));
			const d = K.roundPoly([[y1, z1], [y1, z0], [y0, z0], [y0, z1]].map((p) => W(p)), 0.05 * s);
			let g = k.path(d, col) + k.path(q([[y1, z1], [y1, z0], [y + b, z0], [y + b, z1]]), K.lighter(col, 0.32)) +
				k.path(q([[y - b, z1], [y - b, z0], [y0, z0], [y0, z1]]), K.darker(col, 0.18));
			const ds = [d];
			if (cap) {
				const c = W([y, z0]);
				const pts = [];
				for (let i = 0; i < 8; i++) { const t = rad(22.5 + i * 45); pts.push([c[0] + Math.cos(t) * dm * 0.2 * s, c[1] + Math.sin(t) * dm * 0.5 * s]); }
				const e = K.poly(pts);
				g += k.path(e, K.lighter(col, 0.18));
				if (bore) g += k.path(K.ellipse(c[0], c[1], dm * 0.08 * s, bore / 2 * s), C.ink);
				ds.push(e);
			}
			parts.push({ d: ds, g, sil: true });
			return d;
		},
		// an octagon seen face-on (a drum magazine), centre (y, z), across-flats size dm
		octFace(y, z, dm, col) {
			const c = W([y, z]);
			const pts = [];
			for (let i = 0; i < 8; i++) { const t = rad(22.5 + i * 45); pts.push([c[0] + Math.cos(t) * dm * 0.54 * s, c[1] + Math.sin(t) * dm * 0.54 * s]); }
			const d = K.roundPoly(pts, 0.06 * s);
			parts.push({ d: [d], g: k.path(d, col) + k.soft(d, K.circle(c[0] + dm * 0.2 * s, c[1] + dm * 0.25 * s, dm * 0.4 * s), K.darker(col, 0.18), 0.12 * s, 0.8), sil: true });
			return d;
		},
		disc(y, z, dm, col) {
			const c = W([y, z]);
			const d = K.circle(c[0], c[1], dm / 2 * s);
			parts.push({ d: [d], g: k.path(d, col) + k.soft(d, K.circle(c[0] + dm * 0.2 * s, c[1] + dm * 0.2 * s, dm * 0.35 * s), K.darker(col, 0.2), 0.06 * s, 0.7), sil: true });
			return d;
		},
		// a gem: a square turned 45 degrees, with light and dark facets
		gem(y, z, size, col, { sil = true } = {}) {
			const c = W([y, z]), h = size / 2 * s * 1.15;
			const d = K.poly([[c[0], c[1] - h], [c[0] + h, c[1]], [c[0], c[1] + h], [c[0] - h, c[1]]]);
			const g = `<path d="${d}" fill="${C.ink}" stroke="${C.ink}" stroke-width="${0.09 * s}" stroke-linejoin="round"/>` + k.path(d, col) +
				k.path(K.poly([[c[0], c[1] - h], [c[0] + h, c[1]], [c[0], c[1]]]), K.lighter(col, 0.5)) +
				k.path(K.poly([[c[0], c[1] + h], [c[0] - h, c[1]], [c[0], c[1]]]), K.darker(col, 0.2));
			parts.push({ d: [d], g, sil });
			return d;
		},
		// a free polygon in model (y, z) points
		poly(pts, col, { r = 0.05, light = 0 } = {}) {
			const d = K.roundPoly(pts.map((p) => W(p)), r * s);
			parts.push({ d: [d], g: k.path(d, col), sil: true });
			return d;
		},
		// a trigger guard (the models' guard(): a bottom bar, a front post) and the trigger
		guard(zf, zb, yb, col, { post = 0.9, trigger = C.ink, tz = null } = {}) {
			const len = zb - zf;
			const t = tz !== null ? tz : zf + len * 0.55;
			G.box(yb + 0.55, t, 0.7, 0.3, trigger, { rot: -18, r: 0.08, top: false });
			G.box(yb + 0.16, (zf + zb) / 2 + 0.02, 0.32, len - 0.04, col, { r: 0.1, top: false });
			G.box(yb + 0.03 + (post - 0.03) / 2, zf + 0.16, post - 0.03, 0.32, col, { r: 0.08, top: false });
		},
		W, S,
		streak(pts, w, o) { return k.streak(pts.map((p) => W(p)), w * s, o); },
		finish({ glow = null, sparkles = [], slivers = [] } = {}) {
			const sil = parts.filter((p) => p.sil).flatMap((p) => p.d);
			let body = parts.map((p) => p.g).join('');
			for (const [pts, w, o] of slivers) body += G.streak(pts, w, o || { bias: 0.5, power: 0.6 });
			const out = { sil, body };
			if (glow) out.under = k.glow(sil, glow, 1.15 * s, 0.45 * s, 0.85);
			if (sparkles.length) out.over = sparkles.map(([y, z, r]) => { const c = W([y, z]); return k.flare(c[0], c[1], r * s, r * s, 0, '#ffffff', 0.17); }).join('');
			return out;
		},
	};
	return G;
}

const studsAt = (z0, z1, pitch = 1) => { const o = []; for (let z = z0; z <= z1 + 1e-6; z += pitch) o.push(z); return o; };

const GUNS = {
	Pistol(k) {
		const G = ctx(k, 60);
		G.group(-14, [0, 0], () => {
			G.box(0, 0, 3.4, 1.8, C.brown, { top: false, r: 0.14 });
			G.box(0.1, 0, 2.4, 1.15, C.wooddark, { top: false, sil: false, r: 0.12 });
			G.box(-1.85, 0, 0.4, 1.95, C.gun, { top: false });
		});
		G.guard(-3.1, -0.7, 0.45, C.steeldark);
		G.box(1.8, -1.6, 1.0, 5.6, C.steeldark, { top: false });
		G.box(3.15, 1.85, 0.7, 0.42, C.gun, { rot: 25, top: false });
		G.box(3.55, 1.3, 0.32, 0.35, C.ink, { top: false });
		G.box(3.55, -4.35, 0.32, 0.4, C.ink, { top: false });
		G.box(2.8, -1.6, 1.2, 6.4, C.steel, { studs: [-1.95, -0.65, 0.65, 1.95].map((z) => z - 1.6), tiles: 4 });
		for (const z of [0.55, 0.85, 1.15]) G.box(2.8, z, 0.8, 0.14, C.steeldark, { top: false, r: 0.04, sil: false });
		G.box(3.0, -0.9, 0.5, 1.1, C.ink, { top: false, r: 0.05, sil: false });
		G.box(2.75, -3.1, 0.62, 1.2, C.rust, { top: false, r: 0.06, sil: false });
		G.box(2.45, -2.3, 0.36, 0.6, C.rustdark, { top: false, r: 0.05, sil: false });
		G.box(1.7, -3.5, 0.42, 0.8, C.rust, { top: false, r: 0.05, sil: false });
		G.cyl(2.75, -5.0, 0.6, 0.72, C.gun, { cap: true, bore: 0.42 });
		return G.finish({ slivers: [[[[3.3, 1.2], [3.32, -0.5], [3.32, -2.6]], 0.08]] });
	},
	Revolver(k) {
		const G = ctx(k, 60);
		G.group(-22, [0, 0], () => {
			G.box(0, 0, 3.0, 1.55, C.wood, { top: false, r: 0.14 });
			G.box(0.05, 0, 2.2, 1.05, C.woodlight, { top: false, sil: false, r: 0.12 });
			G.disc(0.35, 0, 0.36, C.chrome);
			G.box(-1.62, 0.05, 0.35, 1.7, C.gun, { top: false });
		});
		G.guard(-2.05, -0.6, 0.15, C.green, { post: 0.8, trigger: C.chrome });
		G.box(3.3, 0.7, 0.9, 0.5, C.chrome, { rot: 32, top: false });
		G.box(2.0, -0.3, 2.2, 1.5, C.green, { top: false, tiles: 1 });
		G.box(0.82, -2.1, 0.5, 2.0, C.green, { top: false });
		G.box(2.1, -4.3, 0.6, 2.2, C.green, { top: false });
		G.cyl(2.8, -4.45, 2.7, 1.0, C.chrome, { cap: true, bore: 0.52 });
		G.box(3.4, -4.5, 0.34, 2.6, C.green, { top: false });
		G.poly([[3.57, -5.25], [4.0, -5.62], [3.57, -5.78]], C.ink);
		G.cyl(2.15, -2.1, 2.0, 2.3, C.chrome, { cap: true });
		G.box(2.15, -2.1, 0.36, 1.45, C.gunlight, { top: false, r: 0.08, sil: false });
		G.box(3.5, -2.3, 0.45, 3.0, C.green, { studs: [-3.3, -2.3, -1.3] });
		return G.finish({ slivers: [[[[3.66, -0.9], [3.68, -2.3], [3.66, -3.6]], 0.07]] });
	},
	Uzi(k) {
		const G = ctx(k, 54);
		G.group(-4, [0, 0], () => {
			G.box(-2.75, 0.1, 2.6, 1.15, C.gun, { top: false });
			G.box(-4.15, 0.12, 0.4, 1.45, C.blue, { top: false });
			G.box(0, 0, 3.0, 1.6, C.black, { top: false, r: 0.12 });
			G.box(0.1, 0, 2.1, 1.1, C.blue, { top: false, sil: false, r: 0.1 });
		});
		G.guard(-2.9, -0.75, 0.45, C.black, { post: 1.1 });
		G.box(1.7, 2.55, 0.6, 0.6, C.gun, { top: false });
		G.box(1.15, -3.8, 0.9, 2.6, C.gun, { top: false });
		G.box(3.95, 1.95, 0.65, 0.35, C.blue, { top: false });
		G.box(3.95, -4.85, 0.65, 0.35, C.blue, { top: false });
		G.box(4.0, -3.2, 0.55, 0.8, C.blue, { top: false });
		G.box(2.5, -1.4, 2.0, 7.6, C.gun, { tiles: 5, light: 0.2 });
		G.box(3.62, -1.3, 0.25, 6.4, C.black, { top: false, studs: [-4.0, -3.0, -0.9, 0.1, 1.1] });
		G.box(2.95, -1.4, 0.35, 5.6, C.blue, { top: false, r: 0.06, sil: false });
		G.box(2.3, -0.2, 0.6, 1.2, C.ink, { top: false, r: 0.05, sil: false });
		G.box(1.7, -1.45, 0.25, 6.4, C.gunlight, { top: false, r: 0.05 });
		G.oct(2.35, -5.45, 0.5, 1.25, C.gunlight);
		G.cyl(2.35, -5.9, 1.6, 0.85, C.gun, { cap: true, bore: 0.48 });
		return G.finish({ slivers: [[[[3.32, 1.9], [3.34, 0.0], [3.34, -2.4]], 0.07]] });
	},
	Shotgun(k) {
		const G = ctx(k, 36);
		G.group(9, [0, 0], () => {
			G.box(1.15, 4.1, 2.7, 2.6, C.wood, { top: false, r: 0.16 });
			G.box(1.55, 1.7, 1.5, 2.8, C.wood, { top: false });
			G.box(1.15, 5.55, 2.8, 0.36, C.purple, { top: false });
			G.box(1.2, 4.1, 0.42, 2.2, C.purple, { top: false, sil: false, r: 0.06 });
		});
		G.group(-18, [0, 0], () => {
			G.box(0, 0, 2.7, 1.5, C.wood, { top: false, r: 0.14 });
			G.box(-1.45, 0, 0.3, 1.62, C.purple, { top: false });
		});
		G.guard(-2.7, -0.75, 0.25, C.gun, { post: 0.75 });
		G.cyl(1.35, -7.2, 5.8, 1.0, C.gun);
		G.cyl(2.55, -8.0, 7.4, 1.05, C.gun);
		G.box(2.0, -2.0, 2.4, 4.6, C.purple, { studs: [-3.8, -2.8, -1.8, -0.8], tiles: 3 });
		G.box(2.8, -1.6, 0.5, 1.4, C.ink, { top: false, r: 0.05, sil: false });
		G.box(1.7, -2.3, 1.45, 3.2, C.gun, { top: false });
		for (const z of [-3.35, -2.65, -1.95, -1.25]) {
			G.box(1.85, z, 1.3, 0.58, C.shell, { top: false, r: 0.12 });
			G.box(1.05, z, 0.3, 0.6, C.brass, { top: false, r: 0.06 });
		}
		G.box(1.35, -7.2, 1.55, 3.4, C.wood, { top: true, r: 0.14 });
		for (const z of [-6.2, -7.2, -8.2]) G.box(1.35, z, 1.62, 0.22, C.wooddark, { top: false, r: 0.06 });
		G.box(1.95, -9.7, 2.15, 0.5, C.purple, { top: false });
		G.cyl(2.55, -11.55, 0.45, 1.2, C.gunlight, { cap: true, bore: 0.62 });
		G.box(3.12, -11.0, 0.3, 0.42, C.red, { top: false, r: 0.1 });
		return G.finish({ slivers: [[[[3.1, -0.3], [3.12, -1.9], [3.12, -3.8]], 0.12]] });
	},
	Tommy(k) {
		const G = ctx(k, 36);
		G.group(6, [0, 0], () => {
			G.box(1.15, 4.3, 2.5, 2.6, C.wood, { top: false, r: 0.16 });
			G.box(1.55, 2.1, 1.4, 2.4, C.wood, { top: false });
			G.box(1.15, 5.72, 2.6, 0.3, C.pink, { top: false });
		});
		G.group(-14, [0, 0], () => G.box(0, 0, 2.7, 1.5, C.wood, { top: false, r: 0.14 }));
		G.guard(-2.05, -0.7, 0.4, C.gun, { post: 0.7 });
		G.cyl(2.1, -8.4, 6.0, 0.8, C.gun);
		for (const z of [-5.8, -6.2, -6.6, -7.0, -7.4]) G.cyl(2.1, z, 0.2, 1.4, C.gunlight);
		G.box(1.45, -8.7, 0.6, 1.4, C.gun, { top: false });
		G.group(-10, [0.2, -8.7], () => {
			G.box(0.2, -8.7, 2.3, 1.25, C.wood, { top: false, r: 0.14 });
			G.box(-1.0, -8.7, 0.25, 1.35, C.pink, { top: false });
		});
		G.box(2.1, -11.2, 1.15, 1.3, C.pink);
		G.box(2.82, -11.3, 0.35, 0.3, C.ink, { top: false });
		G.box(3.18, 0.65, 0.5, 0.45, C.pink, { top: false });
		G.box(2.05, -2.2, 2.1, 6.4, C.gun, { studs: [-4.9, -3.9, -2.9, -1.9, -0.9, 0.1], light: 0.2, tiles: 4 });
		G.box(2.55, -2.6, 0.45, 0.55, C.chrome, { top: false });
		G.octFace(-0.15, -3.95, 3.4, C.gun);
		G.octFace(-0.15, -3.95, 1.7, C.pink);
		G.disc(-0.15, -3.95, 0.45, C.chrome);
		return G.finish({ slivers: [[[[3.0, 0.8], [3.02, -1.6], [3.02, -4.6]], 0.12]] });
	},
	AK(k) {
		const G = ctx(k, 32);
		G.group(10, [0, 0], () => {
			G.box(1.25, 4.4, 2.8, 2.4, C.wood, { top: false, r: 0.16 });
			G.box(1.75, 2.2, 1.55, 2.6, C.wood, { top: false });
			G.box(1.25, 5.72, 2.9, 0.3, C.gun, { top: false });
			G.box(1.3, 4.4, 0.55, 1.7, C.cyan, { top: false, sil: false, r: 0.06 });
		});
		G.group(-20, [0, 0], () => G.box(0, 0, 2.7, 1.45, C.wooddark, { top: false, r: 0.14 }));
		// the curved magazine: three cyan segments, each tipped further toward the muzzle
		let pos = [0.4, -2.55], ang = 10, h = 1.65, last = null;
		for (let i = 0; i < 3; i++) {
			G.box(pos[0], pos[1], h, 1.8 + 0.08 * i, C.cyan, { rot: ang, top: false, r: 0.1 });
			last = [pos, ang];
			const nxt = ang + 13;
			const d0 = [-Math.cos(rad(ang)), -Math.sin(rad(ang))], d1 = [-Math.cos(rad(nxt)), -Math.sin(rad(nxt))];
			pos = [pos[0] + (d0[0] + d1[0]) * h / 2 * 0.98, pos[1] + (d0[1] + d1[1]) * h / 2 * 0.98];
			ang = nxt;
		}
		{
			const [lp, la] = last, dn = [-Math.cos(rad(la)), -Math.sin(rad(la))];
			G.box(lp[0] + dn[0] * (h / 2 + 0.1), lp[1] + dn[1] * (h / 2 + 0.1), 0.3, 2.05, C.cyandark, { rot: la, top: false });
		}
		G.box(0.8, -1.1, 0.3, 1.3, C.gun, { top: false });
		G.box(1.0, -0.95, 0.65, 0.28, C.ink, { rot: -18, top: false });
		G.cyl(2.15, -8.9, 7.6, 0.78, C.gunlight);
		G.box(1.95, -6.8, 1.6, 3.4, C.wood, { top: false, r: 0.14 });
		G.box(1.95, -6.8, 0.22, 2.6, C.wooddark, { top: false, sil: false, r: 0.05 });
		G.box(3.2, -6.5, 0.9, 2.8, C.wood, { r: 0.14 });
		G.cyl(3.2, -8.75, 1.7, 0.62, C.gun);
		G.box(2.7, -9.75, 1.6, 0.65, C.gun, { top: false });
		G.box(3.6, -11.6, 0.65, 0.38, C.gun, { top: false });
		G.box(3.5, -11.6, 0.5, 0.18, C.cyan, { top: false });
		G.box(2.75, -11.6, 1.15, 0.65, C.gun, { top: false });
		G.cyl(2.15, -13.15, 1.1, 1.05, C.cyan, { cap: true, bore: 0.5 });
		G.box(2.0, -2.0, 2.1, 6.2, C.gun, { top: false, tiles: 4 });
		G.box(3.25, -4.5, 0.8, 0.9, C.gun, { top: false });
		G.box(3.3, -1.4, 0.5, 5.0, C.gunlight, { studs: [-3.4, -2.4, -1.4, -0.4, 0.6] });
		G.box(2.25, -1.3, 0.32, 1.7, C.gunlight, { top: false, sil: false, r: 0.05 });
		G.box(2.5, -0.5, 0.38, 0.55, C.chrome, { top: false });
		return G.finish({ slivers: [[[[3.5, 0.9], [3.52, -1.4], [3.52, -3.6]], 0.12]] });
	},
	Deagle(k) {
		const G = ctx(k, 46);
		G.group(-14, [0, 0], () => {
			G.box(0, 0, 3.4, 1.95, C.black, { top: false, r: 0.14 });
			G.disc(0.2, 0, 0.95, C.gold);
			G.gem(0.2, 0, 0.42, C.red, { sil: false });
			G.box(-1.85, 0, 0.36, 2.05, C.gold, { top: false });
		});
		G.guard(-3.4, -0.85, 0.35, C.gold, { post: 1.1 });
		G.box(3.55, 1.85, 0.75, 0.5, C.black, { rot: 25, top: false });
		G.box(3.95, 1.25, 0.35, 0.4, C.ink, { top: false });
		G.box(4.4, -7.6, 0.3, 0.45, C.ink, { top: false });
		G.box(1.9, -3.0, 1.45, 6.2, C.gold, { top: false, tiles: 4 });
		G.box(3.18, -5.6, 1.2, 4.8, C.gold, { top: false, light: 0.35 });
		G.box(4.05, -5.6, 0.55, 4.8, C.gold, { r: 0.14, light: 0.45 });
		G.box(3.2, -5.6, 0.25, 3.6, C.golddark, { top: false, r: 0.05, sil: false });
		G.box(3.0, -0.9, 1.6, 5.0, C.gold, { studs: [-2.9, -1.9, -0.9, 0.1, 1.1], light: 0.35 });
		for (const z of [0.25, 0.6, 0.95]) G.box(3.0, z, 1.05, 0.16, C.golddark, { top: false, r: 0.04, sil: false });
		G.gem(3.0, -1.8, 0.6, C.cyan, { sil: false });
		G.cyl(3.2, -8.04, 0.12, 1.1, C.gold, { cap: true, bore: 0.78 });
		return G.finish({ slivers: [[[[3.62, 1.1], [3.64, -0.9], [3.64, -2.9]], 0.1]], sparkles: [[4.6, 1.6, 0.45], [0.4, -3.6, 0.32]] });
	},
	Minigun(k) {
		const G = ctx(k, 36);
		G.group(-10, [0, 0], () => G.box(0, 0, 2.8, 1.6, C.black, { top: false, r: 0.14 }));
		G.guard(-2.3, -0.8, 0.45, C.gun, { post: 1.05 });
		G.group(-6, [0.5, -3.4], () => G.box(0.5, -3.4, 2.3, 1.2, C.black, { top: false, r: 0.14 }));
		for (const z of [-3.2, 0.3]) G.box(4.85, z, 1.2, 0.5, C.gun, { top: false });
		G.box(5.55, -1.45, 0.5, 4.1, C.black, { r: 0.12 });
		G.oct(2.9, 1.7, 1.0, 2.4, C.gun);
		// six barrels round the hub: the three on the far side first, then the near three
		const bar = (dy) => G.cyl(2.9 + dy, -8.5, 8.6, 0.6, C.chrome, { cap: true, bore: 0.34 });
		bar(0.69); bar(-0.69); bar(0.0);
		G.cyl(2.9, -7.6, 0.5, 2.3, C.gun);
		G.cyl(2.9, -11.6, 0.6, 2.35, C.gun);
		G.cyl(2.9, -12.1, 0.25, 2.45, C.red);
		G.cyl(2.9, -4.4, 0.8, 2.5, C.gun);
		G.box(2.9, -1.4, 2.8, 5.2, C.red, { studs: [-2.9, -1.9, -0.9, 0.1], light: 0.25, tiles: 3 });
		for (const y of [3.55, 2.25]) G.box(y, -1.4, 0.32, 4.4, C.orange, { top: false, r: 0.06, sil: false });
		// the ammo box on the near side, rounds feeding up into the chute
		G.box(2.6, -1.6, 0.5, 1.3, C.gun, { top: false });
		for (const z of [-2.4, -1.6, -0.8]) G.box(2.95, z, 0.75, 0.42, C.brass, { rot: 25, top: false, r: 0.12 });
		G.box(1.25, -1.6, 2.2, 2.8, C.olive, { top: false });
		G.box(2.45, -1.6, 0.3, 2.95, C.olivedark, { top: false });
		G.box(1.1, -1.6, 0.45, 2.6, C.yellow, { top: false, r: 0.05, sil: false });
		return G.finish({ glow: '#ff3a3a', slivers: [[[[4.15, 0.9], [4.17, -1.4], [4.17, -3.6]], 0.12]], sparkles: [[6.2, -3.4, 0.45]] });
	},
	Blaster(k) {
		const G = ctx(k, 42);
		G.group(-16, [0, 0], () => {
			G.box(0, 0, 2.8, 1.6, C.black, { top: false, r: 0.14 });
			G.box(0, 0.62, 2.2, 0.2, C.violetneon, { top: false, sil: false, r: 0.06 });
			G.box(-1.5, 0, 0.3, 1.72, C.violet, { top: false });
		});
		G.guard(-3.1, -0.8, 0.35, C.gun, { post: 1.1, trigger: C.violetneon });
		G.box(1.45, -6.1, 0.75, 3.2, C.violet, { top: false });
		G.box(2.6, 1.75, 2.0, 1.2, C.gun, { top: false });
		G.oct(2.6, -7.2, 5.0, 1.3, C.gun);
		for (const z of [-5.4, -6.4, -7.4, -8.4]) G.cyl(2.6, z, 0.38, 1.95, '#f0a6ff');
		G.oct(2.6, -10.0, 0.9, 1.9, C.white, { cap: true });
		G.poly([[3.7, -2.1], [5.4, -4.4], [3.7, -4.7]], C.violet, { r: 0.08 });
		G.box(2.6, -1.8, 2.4, 6.0, C.white, { studs: [-0.2, 0.8], light: 0.15, tiles: 4 });
		G.box(2.35, -2.0, 1.3, 4.2, C.violet, { top: false, r: 0.08 });
		G.box(3.3, -1.8, 0.24, 4.8, C.violetneon, { top: false, r: 0.05, sil: false });
		G.cyl(4.35, 0.5, 2.4, 1.25, '#e9a6ff');
		G.cyl(4.35, 0.5, 2.5, 0.6, C.violetneon);
		for (const z of [-0.75, 1.75]) G.cyl(4.35, z, 0.3, 1.45, C.gun);
		G.poly([[1.6, -3.3], [1.9, -3.3], [1.2, -5.0], [0.95, -5.0]], C.violet, { r: 0.06 });
		return G.finish({ glow: '#c46eff', slivers: [[[[3.66, 1.0], [3.68, -0.4], [3.66, -2.0]], 0.1]], sparkles: [[5.4, -4.5, 0.4], [1.0, -10.5, 0.32]] });
	},
	Diamond(k) {
		const G = ctx(k, 38);
		G.group(-14, [0, 0], () => {
			G.box(0, 0, 3.0, 1.7, C.gold, { top: false, r: 0.14 });
			G.gem(0.1, 0, 0.7, C.diamond, { sil: false });
			G.box(-1.65, 0, 0.35, 1.85, C.golddark, { top: false });
		});
		G.guard(-3.1, -0.85, 0.35, C.gold, { post: 1.4, trigger: C.cyan });
		G.group(-8, [1.0, -6.0], () => {
			G.box(1.0, -6.0, 2.4, 1.2, C.gold, { top: false, r: 0.14 });
			G.box(-0.3, -6.0, 0.3, 1.3, C.golddark, { top: false });
		});
		G.oct(3.2, 1.65, 0.6, 2.3, C.gold);
		// barrel: cut diamond blocks in two shades, a glowing core, gold rings, a flared gold muzzle
		for (const [z0, z1, col] of [[-3.3, -4.3, C.diamond], [-4.3, -7.3, C.diamonddeep], [-7.3, -10.2, C.diamond], [-10.2, -11.3, C.diamonddeep]]) G.oct(3.2, (z0 + z1) / 2, Math.abs(z1 - z0), 2.6, col);
		G.box(3.2, -7.5, 0.7, 7.4, '#b8f6ff', { top: false, r: 0.2, sil: false });
		for (const z of [-4.3, -7.3, -10.2]) G.oct(3.2, z, 0.55, 2.95, C.gold);
		G.oct(3.2, -11.75, 0.9, 3.5, C.gold, { cap: true, bore: 1.4 });
		// breech: a diamond block with a glowing core between studded gold bands
		G.box(3.2, -1.0, 2.8, 4.6, C.diamonddeep, { top: false });
		G.box(3.2, -1.0, 1.5, 3.8, '#a6f4ff', { top: false, r: 0.2, sil: false });
		for (const z of [-3.05, 1.05]) G.box(3.2, z, 3.0, 0.7, C.gold, { studs: [z] });
		G.box(4.75, -1.0, 0.35, 2.6, C.gold, { studs: [-2.0, -1.0, 0.0] });
		G.box(3.2, -1.0, 1.7, 1.7, C.gold, { top: false });
		G.gem(3.2, -1.0, 1.05, C.diamond);
		// crystal growths on top of the breech and the barrel
		const crystal = (y, z, w, h, a) => G.group(a, [y, z], () => G.box(y, z, h, w, C.diamond, { r: 0.08, light: 0.45 }));
		crystal(5.4, -1.7, 0.9, 1.6, -22);
		crystal(5.15, -0.2, 0.6, 1.1, 18);
		crystal(4.6, -8.7, 0.7, 1.3, -20);
		crystal(4.5, -5.9, 0.6, 1.0, 24);
		return G.finish({ glow: '#3ce6ff', slivers: [[[[4.4, 1.2], [4.45, 0.0], [4.4, -1.6]], 0.1]], sparkles: [[6.4, -1.8, 0.5], [5.4, -9.0, 0.36], [1.0, -11.6, 0.36]] });
	},
};

// the long guns are drawn tilted 30° muzzle-up (like their renders, a little steeper: they read taller in the strips)
const TILT = { Shotgun: -30, Tommy: -30, AK: -30 };
module.exports = Object.entries(GUNS).map(([id, fn]) => ({
	name: 'Gun_' + id,
	draw: (k) => (TILT[id] ? k.place(fn(k), `rotate(${TILT[id]} 256 256)`) : fn(k)),
}));
module.exports.GUNS = GUNS;
module.exports.ctx = ctx;
