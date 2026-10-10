// The shoes (Shoe_<Id>): one parametric LOW chunky sneaker in side view (toe to the right), the game's own shoe shape,
// dressed from each shoe's definition in Shared/Models/ShoeModels.lua: the same colour keys (upper, ankle, heel, collar,
// tongue, tab, lace, eyelet, eyestay, toeBox, toe, sole, base, stripe, flash, tongueLabel, logo), the same material
// kinds (fabric, gloss, metal / chrome, gold, holo, gem, neon) and the same accents (wings, crown, flames, drips, splats,
// checker, sparkles, stars, bolts, zigzags, speckles, rainbow laces / stripe / band, heel strip, toe badge, "+1").
// Rarity reads like ShoeFX.tier: Common plain; Rare a glint; Epic a soft rarity-colour glow; Legendary a stronger glow;
// Mythic a bright edge glow; Secret a rainbow glow, an edge glow and a halo. Sparkles grow with the tier.
'use strict';

const K = require('../kit');

const rgb = (r, g, b) => K.rgb2hex(r, g, b);
const PAL = {
	white: rgb(244, 244, 247), snow: rgb(250, 250, 252), ink: rgb(28, 28, 36), silver: rgb(200, 206, 216), gold: rgb(255, 196, 52),
};
const RAINBOW = [rgb(255, 70, 90), rgb(255, 170, 40), rgb(255, 236, 70), rgb(80, 230, 120), rgb(60, 190, 255), rgb(170, 100, 255)];
// ShoeFX ladder colours (Common .. Secret)
const RARITY = [rgb(178, 186, 198), rgb(61, 155, 255), rgb(166, 77, 255), rgb(255, 150, 32), rgb(255, 59, 92), rgb(255, 236, 120)];
const ICE = rgb(90, 230, 255), PINKGLOW = rgb(255, 140, 220), CHROME = rgb(196, 204, 220), CHROME2 = rgb(158, 168, 188), NAVY = rgb(40, 44, 62);
const SUN = rgb(255, 120, 60), GOLDEN = rgb(255, 205, 60), ROYAL = rgb(80, 40, 160);

// ---------------------------------------------------------------- the 22 definitions (ported from ShoeModels.lua)
const DEFS = {
	FreshCanvas: { rarity: 1, upper: rgb(240, 240, 243), ankle: rgb(232, 233, 238), heel: rgb(222, 224, 230), collar: PAL.snow, tongue: rgb(236, 236, 240),
		upperKind: 'fabric', lace: PAL.snow, stripe: PAL.ink, logo: { color: rgb(222, 40, 48), glyph: 'plus1' }, tongueLabel: rgb(222, 40, 48) },
	RedRocket: { rarity: 2, upper: rgb(214, 38, 44), ankle: rgb(196, 30, 38), heel: rgb(30, 30, 38), collar: rgb(30, 30, 38), tongue: rgb(226, 52, 56), tab: rgb(30, 30, 38),
		base: rgb(30, 30, 38), stripe: PAL.ink, logo: { kind: 'bolt', color: rgb(255, 196, 40) }, tongueLabel: rgb(255, 196, 40) },
	Checkmate: { rarity: 3, upper: rgb(34, 34, 42), ankle: rgb(238, 238, 242), heel: rgb(30, 30, 38), collar: rgb(30, 30, 38), tongue: rgb(30, 30, 38), tab: rgb(222, 40, 48),
		toeBox: rgb(238, 238, 242), base: rgb(214, 36, 44), stripe: rgb(255, 96, 96), tongueLabel: rgb(222, 40, 48), eyestay: rgb(34, 34, 42),
		deco: [['checker', rgb(34, 34, 42)], ['bolt', rgb(232, 40, 48)], ['toeBadge', 'star', rgb(232, 40, 48)]] },
	ChromeKicks: { rarity: 4, upper: rgb(222, 228, 238), ankle: rgb(204, 212, 226), heel: rgb(30, 30, 38), collar: rgb(30, 30, 38), tongue: rgb(230, 234, 242), upperKind: 'metal',
		lace: rgb(240, 70, 90), eyelet: PAL.gold, sole: rgb(36, 36, 46), base: rgb(24, 24, 30), stripe: rgb(255, 70, 90), toe: rgb(36, 36, 46), tongueLabel: rgb(240, 70, 90),
		deco: [['sparkles', rgb(255, 120, 160), rgb(255, 170, 200)], ['heelStrip', rgb(255, 70, 90)]] },
	StreetAngel: { rarity: 5, upper: rgb(246, 246, 250), ankle: rgb(236, 238, 244), heel: rgb(255, 200, 70), collar: rgb(255, 200, 60), collarKind: 'gold', tongue: rgb(255, 204, 70),
		tongueKind: 'gold', toe: rgb(255, 204, 70), toeKind: 'gold', eyelet: PAL.gold, sole: rgb(250, 246, 236), base: rgb(240, 190, 60), stripe: rgb(255, 250, 230),
		tab: rgb(255, 200, 60), tongueLabel: PAL.snow, deco: [['wings', rgb(250, 250, 255), rgb(232, 236, 248), 'smooth', 1.15], ['heelStrip', rgb(255, 236, 160)]] },
	BlockRoyalty: { rarity: 6, upper: rgb(34, 30, 44), ankle: rgb(28, 26, 36), heel: rgb(222, 40, 48), collar: rgb(222, 44, 52), tongue: rgb(28, 26, 36), upperKind: 'gloss',
		lace: rgb(255, 210, 60), rainbowLaces: true, eyelet: PAL.gold, sole: rgb(232, 70, 40), base: rgb(200, 50, 30), rainbowStripe: true, toe: rgb(34, 30, 44), toeKind: 'gloss',
		tongueLabel: false, deco: [['rainbowBand', 0], ['crown', rgb(255, 200, 50), rgb(232, 40, 60)], ['toeBadge', 'star', rgb(255, 210, 60)]] },
	SprayTag: { rarity: 1, upper: rgb(232, 92, 164), ankle: rgb(220, 82, 152), heel: rgb(204, 70, 140), collar: PAL.snow, tongue: rgb(240, 110, 176),
		lace: rgb(255, 206, 50), stripe: PAL.ink, logo: { color: rgb(40, 196, 210), glyph: 'dot', glyphColor: PAL.snow }, tongueLabel: rgb(40, 196, 210) },
	DripTag: { rarity: 2, upper: rgb(42, 184, 204), ankle: rgb(34, 166, 188), heel: rgb(236, 96, 160), collar: rgb(236, 96, 160), tongue: rgb(52, 196, 214), tab: rgb(236, 96, 160),
		base: rgb(236, 96, 160), stripe: rgb(236, 96, 160), logo: { kind: 'zigzag', color: rgb(255, 206, 50) }, tongueLabel: rgb(255, 206, 50),
		deco: [['drips', rgb(236, 96, 160), 2, 0.8]] },
	PaintSplash: { rarity: 3, upper: rgb(36, 34, 46), ankle: rgb(30, 28, 40), heel: rgb(236, 96, 160), collar: rgb(36, 34, 46), tongue: rgb(36, 34, 46), tab: rgb(236, 96, 160),
		base: rgb(236, 96, 160), stripe: rgb(255, 120, 200), tongueLabel: rgb(120, 230, 90),
		deco: [['splats', [[0.5, 0.25, 0.26, rgb(236, 96, 160)], [0.32, -0.12, 0.2, rgb(120, 230, 90)], [0.55, -0.3, 0.12, rgb(70, 170, 255)], [0.22, 0.4, 0.12, rgb(255, 206, 50)], [0.18, 0.08, 0.08, rgb(236, 96, 160)]]],
			['toeBadge', 'star', rgb(236, 96, 160)], ['drips', rgb(236, 96, 160), 2, 0.7]] },
	NeonBomb: { rarity: 4, upper: rgb(236, 60, 150), ankle: rgb(220, 44, 136), heel: rgb(30, 28, 40), collar: rgb(30, 28, 40), tongue: rgb(244, 80, 164), upperKind: 'gloss',
		lace: rgb(120, 230, 255), sole: rgb(30, 28, 40), base: rgb(24, 22, 32), stripe: rgb(100, 230, 255), toe: rgb(30, 28, 40), tongueLabel: rgb(120, 230, 255),
		deco: [['sparkles', rgb(150, 240, 255), rgb(220, 250, 255)], ['drips', rgb(100, 230, 255), 2, 0.7, 'neon'], ['heelStrip', rgb(100, 230, 255)]] },
	WildStyle: { rarity: 5, upper: rgb(40, 44, 70), ankle: rgb(34, 38, 62), heel: rgb(236, 96, 160), collar: rgb(236, 96, 160), tongue: rgb(236, 96, 160), tab: rgb(236, 96, 160),
		sole: rgb(236, 96, 160), base: rgb(200, 70, 140), stripe: rgb(130, 255, 110), toe: rgb(120, 220, 90), tongueLabel: rgb(130, 255, 110),
		deco: [['splats', [[0.48, 0.2, 0.26, rgb(120, 220, 90)], [0.26, -0.2, 0.18, rgb(120, 220, 90)], [0.2, 0.42, 0.1, rgb(236, 96, 160)]]],
			['drips', rgb(130, 255, 110), 4, 1.1, 'neon'], ['toeBadge', 'star', rgb(130, 255, 110)]] },
	Masterpiece: { rarity: 6, upper: rgb(52, 34, 90), ankle: rgb(44, 28, 78), heel: rgb(255, 110, 190), collar: rgb(70, 46, 120), tongue: rgb(52, 34, 90), upperKind: 'gloss',
		rainbowLaces: true, sole: rgb(240, 90, 160), base: rgb(200, 60, 130), rainbowStripe: true, rainbowOffset: 2, toe: rgb(70, 46, 120), tongueLabel: rgb(255, 200, 60),
		deco: [['splats', [[0.5, 0.26, 0.24, RAINBOW[0]], [0.3, -0.05, 0.2, RAINBOW[3]], [0.55, -0.32, 0.13, RAINBOW[5]], [0.2, 0.36, 0.11, RAINBOW[2]]]],
			['drips', RAINBOW[4], 4, 1.1, 'neon', RAINBOW], ['toeBadge', 'sparkle', RAINBOW[1]]] },
	SilverStreak: { rarity: 2, upper: CHROME, ankle: CHROME2, upperKind: 'chrome', heel: NAVY, collar: NAVY, tongue: NAVY, tab: ICE, lace: rgb(236, 250, 255),
		eyelet: ICE, base: NAVY, stripe: ICE, stripeKind: 'neon', flash: ICE, flashKind: 'neon', toe: NAVY, logo: { kind: 'bolt', color: ICE }, tongueLabel: ICE },
	MidnightChrome: { rarity: 3, upper: rgb(34, 36, 56), ankle: rgb(28, 30, 48), heel: CHROME, heelKind: 'chrome', collar: rgb(28, 30, 48), tongue: rgb(34, 36, 56), upperKind: 'gloss',
		lace: ICE, toe: CHROME, toeKind: 'chrome', sole: CHROME2, soleKind: 'chrome', base: rgb(28, 30, 46), stripe: ICE, tab: ICE, flash: ICE, flashKind: 'neon', eyelet: CHROME,
		tongueLabel: ICE, deco: [['zigzag', ICE], ['toeBadge', 'sparkle', ICE]] },
	RainbowDrip: { rarity: 4, upper: rgb(248, 248, 252), ankle: rgb(238, 240, 246), heel: rgb(80, 200, 255), collar: rgb(255, 90, 160), tongue: rgb(248, 248, 252), upperKind: 'gloss',
		rainbowLaces: true, rainbowStripe: true, sole: PAL.snow, base: rgb(80, 200, 255), toe: rgb(80, 200, 255), flash: rgb(255, 90, 160), flashKind: 'neon', eyelet: CHROME,
		tongueLabel: rgb(255, 90, 160), deco: [['drips', rgb(255, 90, 160), 4, 1.1, 'gloss', RAINBOW],
			['speckles', [[0.42, 0.25, 0.07, RAINBOW[0]], [0.3, -0.05, 0.07, RAINBOW[2]], [0.22, 0.3, 0.06, RAINBOW[3]], [0.4, -0.35, 0.06, RAINBOW[4]]]], ['heelStrip', rgb(120, 220, 255)]] },
	Hologram: { rarity: 5, upper: rgb(186, 160, 255), ankle: rgb(255, 150, 222), toeBox: rgb(110, 226, 255), upperKind: 'holo', toeBoxKind: 'holo', ankleKind: 'holo',
		heel: rgb(110, 240, 200), heelKind: 'holo', collar: rgb(120, 230, 240), tongue: rgb(232, 240, 255), lace: rgb(255, 170, 230), laceKind: 'neon', sole: rgb(240, 244, 255),
		base: PINKGLOW, baseKind: 'neon', stripe: rgb(120, 230, 240), toe: rgb(214, 226, 250), toeKind: 'chrome', flash: rgb(120, 230, 240), flashKind: 'neon', eyelet: CHROME,
		tongueLabel: rgb(120, 230, 240), deco: [['wings', rgb(170, 240, 255), rgb(255, 170, 230), 'holo', 1.15], ['toeBadge', 'gem', rgb(120, 230, 240)]] },
	PlatinumWings: { rarity: 6, upper: CHROME, ankle: CHROME2, upperKind: 'chrome', heel: CHROME2, heelKind: 'chrome', collar: rgb(70, 80, 110), tongue: CHROME, tongueKind: 'chrome',
		rainbowLaces: true, eyelet: PAL.gold, sole: rgb(244, 246, 252), base: ICE, baseKind: 'neon', rainbowStripe: true, rainbowOffset: 3, toe: rgb(70, 80, 110), toeKind: 'gloss',
		flash: ICE, flashKind: 'neon', tongueLabel: false, deco: [['wings', rgb(252, 252, 255), CHROME2, 'chrome', 1.3], ['rainbowBand', 3], ['toeBadge', 'gem', ICE]] },
	GoldenHour: { rarity: 2, upper: rgb(255, 198, 56), ankle: rgb(244, 178, 40), heel: SUN, collar: PAL.snow, tongue: rgb(255, 208, 76), tab: SUN, upperKind: 'gold',
		base: SUN, stripe: SUN, stripeKind: 'neon', flash: SUN, flashKind: 'neon', eyelet: PAL.gold, logo: { kind: 'sparkle', color: SUN }, tongueLabel: SUN },
	Starlight: { rarity: 3, upper: rgb(28, 34, 90), ankle: rgb(24, 28, 76), heel: GOLDEN, heelKind: 'gold', collar: rgb(24, 28, 76), tongue: rgb(28, 34, 90), tab: GOLDEN, upperKind: 'gloss',
		lace: rgb(240, 240, 255), base: rgb(255, 200, 60), stripe: rgb(255, 224, 120), toe: GOLDEN, toeKind: 'gold', flash: GOLDEN, flashKind: 'gold', eyelet: PAL.gold,
		tongueLabel: rgb(255, 214, 80), deco: [['star', rgb(255, 214, 80)],
			['speckles', [[0.5, 0.35, 0.05, PAL.snow], [0.3, -0.2, 0.05, rgb(255, 236, 160)], [0.22, 0.32, 0.04, PAL.snow], [0.46, -0.36, 0.04, rgb(255, 236, 160)]]],
			['toeBadge', 'star', rgb(255, 236, 160)]] },
	SolarFlare: { rarity: 4, upper: rgb(255, 176, 40), ankle: rgb(255, 150, 30), heel: GOLDEN, heelKind: 'gold', collar: rgb(60, 30, 20), tongue: rgb(255, 190, 60), upperKind: 'gloss',
		lace: rgb(255, 240, 200), eyelet: PAL.gold, sole: rgb(60, 30, 20), base: rgb(255, 90, 40), stripe: rgb(255, 220, 90), toe: rgb(255, 90, 40), toeKind: 'gloss',
		flash: rgb(255, 90, 40), flashKind: 'neon', tongueLabel: rgb(255, 70, 40), deco: [['flames', rgb(255, 110, 40), rgb(255, 230, 90)], ['heelStrip', rgb(255, 230, 90)]] },
	AstroCrown: { rarity: 5, upper: ROYAL, ankle: rgb(66, 32, 140), heel: GOLDEN, heelKind: 'gold', collar: rgb(30, 20, 60), tongue: rgb(30, 20, 60), upperKind: 'gloss',
		lace: rgb(255, 214, 80), eyelet: PAL.gold, sole: rgb(30, 20, 60), base: rgb(255, 196, 50), stripe: rgb(190, 150, 255), toe: GOLDEN, toeKind: 'gold', flash: GOLDEN,
		flashKind: 'gold', tongueLabel: rgb(255, 214, 80),
		deco: [['crown', GOLDEN, rgb(120, 220, 255), true], ['wings', rgb(190, 150, 255), GOLDEN, 'gloss', 1.05], ['speckles', [[0.2, 0.25, 0.05, PAL.snow], [0.3, -0.3, 0.05, PAL.snow]]]] },
	TheGrail: { rarity: 6, upper: rgb(255, 202, 60), ankle: rgb(244, 182, 44), heel: rgb(170, 90, 255), heelKind: 'gem', collar: rgb(110, 50, 190), upperKind: 'gold',
		tongue: rgb(255, 208, 76), tongueKind: 'gold', rainbowLaces: true, sole: PAL.snow, base: rgb(170, 90, 255), baseKind: 'neon', rainbowStripe: true, rainbowOffset: 4,
		toe: rgb(170, 90, 255), toeKind: 'gem', flash: rgb(170, 90, 255), flashKind: 'neon', eyelet: PAL.gold, tongueLabel: false,
		deco: [['wings', rgb(255, 236, 170), GOLDEN, 'gold', 1.25], ['rainbowBand', 4], ['plusOne', rgb(170, 90, 255)], ['toeBadge', 'gem', rgb(170, 90, 255)]] },
};

// defaults, as ShoeModels' filled()
function filled(d0) {
	const d = { ...d0 };
	const r = d.rarity;
	d.sole = d.sole || PAL.white;
	d.toe = d.toe || d.sole;
	d.collar = d.collar || PAL.snow;
	d.lace = d.lace || PAL.snow;
	d.eyelet = d.eyelet || PAL.silver;
	d.stripe = d.stripe || PAL.ink;
	d.base = d.base || K.darker(d.sole, 0.2);
	d.toeBox = d.toeBox || d.upper;
	d.eyestay = d.eyestay || K.darker(d.upper, 0.12);
	d.tab = d.tab || (d.logo && r === 1 ? d.logo.color : d.heel);
	if (d.flash === undefined) d.flash = (r === 1 && (d.logo ? d.logo.color : K.darker(d.upper, 0.15))) || (d.base !== d.upper && d.base) || d.heel || K.darker(d.upper, 0.2);
	return d;
}

// ---------------------------------------------------------------- the sneaker
function sneaker(k, d, { U = 200 } = {}) {
	d = filled(d);
	const P = ([u, v]) => [256 + u * U, 256 + v * U];
	const S = (pts, t = 0.5) => K.smooth(pts.map((p) => (p[2] ? [...P(p), p[2]] : P(p))), true, t);
	const RP = (pts, r) => K.roundPoly(pts.map(P), r * U);
	const poly = (pts) => K.poly(pts.map(P));
	const r = d.rarity;
	const sil = [];
	let back = '', g = '', wings = '';

	// finishes: a part painted in a material kind
	const finish = (shape, col, kind, box) => {
		const [u0, v0, u1, v1] = box; // the part's rough box (u0, v0) - (u1, v1)
		let o = k.path(shape, col);
		const h = v1 - v0;
		if (kind === 'metal' || kind === 'chrome') {
			o += k.clip(shape, k.path(poly([[u0 - 1, v0 + h * 0.18], [u1 + 1, v0 + h * 0.1], [u1 + 1, v0 + h * 0.3], [u0 - 1, v0 + h * 0.38]]), '#ffffff', 'opacity="0.55"') +
				k.path(poly([[u0 - 1, v0 + h * 0.62], [u1 + 1, v0 + h * 0.56], [u1 + 1, v0 + h * 0.74], [u0 - 1, v0 + h * 0.8]]), K.darker(col, 0.3), 'opacity="0.6"'));
		} else if (kind === 'gold') {
			o += k.soft(shape, poly([[u0 - 1, v0 - 1], [u1 + 1, v0 - 1], [u1 + 1, v0 + h * 0.32], [u0 - 1, v0 + h * 0.4]]), K.lighter(col, 0.5), 0.05 * U, 0.8) +
				k.soft(shape, poly([[u0 - 1, v0 + h * 0.7], [u1 + 1, v0 + h * 0.66], [u1 + 1, v1 + 1], [u0 - 1, v1 + 1]]), K.mix(col, '#c8640a', 0.45), 0.05 * U, 0.8);
		} else if (kind === 'holo') {
			const gid = k.lin(...P([u0, v0]), ...P([u1, v1]), [[0, '#ff9fe8', 0.55], [0.5, '#9ff0ff', 0.45], [1, '#c9a6ff', 0.55]]);
			o += k.clip(shape, `<path d="${poly([[u0 - 1, v0 - 1], [u1 + 1, v0 - 1], [u1 + 1, v1 + 1], [u0 - 1, v1 + 1]])}" fill="${gid}"/>`) +
				k.clip(shape, k.path(poly([[u0 - 1, v0 + h * 0.2], [u1 + 1, v0 + h * 0.05], [u1 + 1, v0 + h * 0.18], [u0 - 1, v0 + h * 0.33]]), '#ffffff', 'opacity="0.45"'));
		} else if (kind === 'gloss') {
			o += k.clip(shape, k.path(poly([[u0 - 1, v0 + h * 0.12], [u1 + 1, v0 + h * 0.04], [u1 + 1, v0 + h * 0.14], [u0 - 1, v0 + h * 0.22]]), '#ffffff', 'opacity="0.35"'));
		} else if (kind === 'gem') {
			o += k.clip(shape, k.path(poly([[u0, v0], [(u0 + u1) / 2, v0], [u0, v1]]), K.lighter(col, 0.35)) + k.path(poly([[u1, v1], [(u0 + u1) / 2, v1], [u1, v0]]), K.darker(col, 0.2)));
		} else if (kind === 'neon') {
			o += k.soft(shape, poly([[u0 - 1, v0 + h * 0.3], [u1 + 1, v0 + h * 0.3], [u1 + 1, v0 + h * 0.7], [u0 - 1, v0 + h * 0.7]]), K.lighter(col, 0.6), 0.03 * U, 0.9);
		}
		return o;
	};
	const deco = (name) => (d.deco || []).filter((x) => x[0] === name);
	// the low chunky sneaker of the game's ShoeModels (SHOES2): a long low body with a big puffy dome toe, a thick
	// two-layer puffy sole, a padded pillow collar, a tall tongue sticking up behind fat X laces, a heel tab

	// --- behind the body: collar flames, the tongue, the heel tab
	for (const [, outer, core] of deco('flames')) {
		[[-0.9, -0.58, 0.42, -14], [-0.66, -0.66, 0.56, -5], [-0.42, -0.66, 0.48, 6], [-0.22, -0.62, 0.38, 14]].forEach(([u, v, h, tilt], i) => {
			const pts = [[u - 0.1, v + 0.06], [u - 0.07, v - h * 0.45], [u + 0.02, v - h], [u + 0.06, v - h * 0.5], [u + 0.1, v + 0.06]].map((p) => K.rotp(p, [u, v], tilt));
			const f = S(pts, 0.45);
			back += k.path(f, outer);
			if (i % 2 === 0) back += k.path(S(pts.map((p) => K.lerp(p, [u, v + 0.02], 0.45)), 0.45), core);
			sil.push(f);
		});
	}
	const tongue = S([[-0.2, -0.45], [-0.23, -0.98], [-0.1, -1.1], [0.06, -1.02], [0.1, -0.45]], 0.5);
	back += finish(tongue, d.tongue, d.tongueKind, [-0.23, -1.1, 0.1, -0.45]);
	if (d.tongueLabel) back += k.path(RP([[-0.17, -1.0], [0.01, -1.02], [0.02, -0.9], [-0.16, -0.88]], 0.02), d.tongueLabel);
	sil.push(tongue);
	const tab = RP([[-1.04, -0.72], [-0.92, -0.76], [-0.87, -0.52], [-0.99, -0.49]], 0.04);
	back += k.path(tab, d.tab);
	sil.push(tab);

	// --- the upper: a long low body
	const solT = 0.18 - 0.012 * (r - 1); // the foam's top: a thicker sole up the ladder
	const upper = S([[-0.94, solT + 0.1], [-0.99, -0.12], [-0.95, -0.42], [-0.8, -0.5], [-0.5, -0.52], [-0.25, -0.5], [-0.05, -0.54],
		[0.15, -0.5], [0.35, -0.4], [0.55, -0.3], [0.8, -0.2], [1.0, -0.05], [1.06, solT + 0.04], [1.0, solT + 0.12]], 0.5);
	g += finish(upper, d.upper, d.upperKind, [-0.99, -0.54, 1.06, solT]);
	g += k.soft(upper, poly([[-1.2, solT - 0.12], [1.2, solT - 0.14], [1.2, 0.5], [-1.2, 0.5]]), K.darker(d.upper, 0.14), 0.04 * U, 0.6);
	sil.push(upper);
	// the ankle panel behind the laces, the heel cap
	const anklePanel = poly([[-1.2, -1], [-0.16, -1], [-0.16, -0.26], [-0.4, -0.08], [-1.2, -0.08]]);
	g += k.clip(upper, finish(anklePanel, d.ankle || d.upper, d.ankleKind, [-1, -0.52, -0.16, -0.08]));
	for (const [, c2] of deco('checker')) {
		let ch = '';
		for (let i = 0; i < 7; i++) for (let j = 0; j < 4; j++) if ((i + j) % 2 === 0) ch += k.path(poly([[-1.0 + i * 0.12, -0.54 + j * 0.12], [-0.88 + i * 0.12, -0.54 + j * 0.12], [-0.88 + i * 0.12, -0.42 + j * 0.12], [-1.0 + i * 0.12, -0.42 + j * 0.12]]), c2);
		g += k.clip(upper, k.clip(anklePanel, ch));
	}
	const heelCap = S([[-1.2, 0.4], [-1.2, -0.6], [-0.88, -0.44], [-0.75, -0.2], [-0.73, 0.1], [-0.77, 0.4]], 0.5);
	g += k.clip(upper, finish(heelCap, d.heel, d.heelKind, [-1, -0.44, -0.73, solT]));
	for (const [, col] of deco('heelStrip')) g += k.clip(upper, k.path(RP([[-0.94, -0.42], [-0.86, -0.44], [-0.84, solT], [-0.92, solT]], 0.03), col));
	// the side flash
	const flash = RP([[-0.7, 0.02], [0.14, -0.2], [0.2, -0.08], [-0.64, 0.13]], 0.05);
	g += k.clip(upper, finish(flash, d.flash, d.flashKind, [-0.7, -0.2, 0.2, 0.13]));
	// quarter decos: splats, speckles, sparkles, star, bolt, zigzag, rainbow band, the logo
	const side = (h, z) => [-z / 0.62, solT - h * 1.05];
	for (const [, list] of deco('splats')) for (const [h, z, s, col] of list) {
		const c = side(h, z), R = s * 0.5;
		const blob = S([[c[0] - R, c[1]], [c[0] - R * 0.5, c[1] - R * 0.9], [c[0] + R * 0.4, c[1] - R], [c[0] + R, c[1] - R * 0.2], [c[0] + R * 0.7, c[1] + R * 0.8], [c[0] - R * 0.3, c[1] + R]], 0.6);
		g += k.clip(upper, k.path(blob, col) + k.path(K.circle(...P([c[0] + R * 1.2, c[1] - R * 0.9]), R * 0.25 * U), col));
	}
	for (const [, list] of deco('speckles')) for (const [h, z, s, col] of list) {
		const c = P(side(h, z)), R = s * 0.9 * U;
		g += k.clip(upper, `<path d="${K.poly([[c[0], c[1] - R], [c[0] + R, c[1]], [c[0], c[1] + R], [c[0] - R, c[1]]])}" fill="${col}"/>`);
	}
	for (const [, c1, c2] of deco('sparkles')) g += k.flare(...P([-0.52, -0.3]), 0.13 * U, 0.13 * U, 0, c1, 0.2) + k.flare(...P([-0.3, -0.1]), 0.08 * U, 0.08 * U, 0, c2, 0.2);
	for (const [, col] of deco('star')) g += starPath(P([-0.52, -0.28]), 0.13 * U, col);
	for (const [, col] of deco('bolt')) g += k.path(poly([[-0.44, -0.48], [-0.6, -0.22], [-0.5, -0.23], [-0.58, -0.02], [-0.38, -0.3], [-0.48, -0.29]]), col);
	for (const [, col] of deco('zigzag')) g += `<path d="M${[[-0.84, -0.24], [-0.7, -0.36], [-0.56, -0.22], [-0.42, -0.34], [-0.3, -0.2]].map((p) => P(p).join(' ')).join(' L')}" fill="none" stroke="${col}" stroke-width="${0.05 * U}" stroke-linecap="round" stroke-linejoin="round"/>`;
	for (const [, o] of deco('rainbowBand')) for (let i = 0; i < 6; i++) g += k.clip(upper, k.path(poly([[-1.2, -0.02 + i * 0.03], [-0.12, -0.16 + i * 0.03], [-0.12, -0.13 + i * 0.03], [-1.2, 0.01 + i * 0.03]]), RAINBOW[(i + o) % 6]));
	if (d.logo) {
		const c = P([-0.44, -0.24]), s = 0.11 * U, col = d.logo.color;
		if (d.logo.glyph === 'plus1') g += plusOne(c, s * 1.15, col);
		else if (d.logo.glyph === 'dot') g += k.path(K.circle(c[0], c[1], s), col) + k.path(K.circle(c[0], c[1], s * 0.4), d.logo.glyphColor || PAL.snow);
		else if (d.logo.kind === 'bolt') g += k.path(K.poly([[c[0] + s * 0.3, c[1] - s * 1.3], [c[0] - s * 0.7, c[1] + s * 0.1], [c[0], c[1] + s * 0.05], [c[0] - s * 0.4, c[1] + s * 1.3], [c[0] + s * 0.8, c[1] - s * 0.2], [c[0] + s * 0.05, c[1] - s * 0.15]]), col);
		else if (d.logo.kind === 'zigzag') g += `<path d="M${[[-1.4, 0.4], [-0.7, -0.4], [0, 0.4], [0.7, -0.4], [1.4, 0.4]].map(([a, b]) => [c[0] + a * s, c[1] + b * s].join(' ')).join(' L')}" fill="none" stroke="${col}" stroke-width="${s * 0.45}" stroke-linecap="round" stroke-linejoin="round"/>`;
		else if (d.logo.kind === 'sparkle') g += k.flare(c[0], c[1], s * 1.3, s * 1.3, 0, col, 0.2);
	}
	// drips hanging from the collar
	for (const [, col, n, long, kind, cols] of deco('drips')) {
		[[-0.62, 0.36], [-0.32, 0.5], [-0.84, 0.3], [0.2, 0.28]].slice(0, n || 3).forEach(([u, h], i) => {
			const top = u > -0.1 ? -0.44 + (u + 0.1) * 0.3 : -0.5;
			const len = h * (long || 1) * 0.7;
			const c = cols ? cols[i % cols.length] : col;
			const drip = RP([[u - 0.04, top - 0.1], [u + 0.04, top - 0.1], [u + 0.04, top + len], [u - 0.04, top + len]], 0.04);
			g += k.clip(upper, k.path(drip, c) + k.path(K.circle(...P([u, top + len]), 0.06 * U), c));
		});
	}

	// --- the big puffy dome toe and its rubber cap
	const dome = S([[0.16, solT + 0.1], [0.18, -0.14], [0.4, -0.37], [0.7, -0.38], [0.95, -0.22], [1.09, 0.0], [1.06, solT + 0.1]], 0.5);
	g += k.sep([dome], 0.016 * U) + finish(dome, d.toeBox, d.toeBoxKind || (d.toeBox === d.upper ? d.upperKind : undefined), [0.16, -0.38, 1.09, solT]);
	g += k.soft(dome, K.ellipse(...P([0.84, 0.12]), 0.36 * U, 0.18 * U), K.darker(d.toeBox, 0.15), 0.05 * U, 0.7);
	g += k.soft(dome, K.ellipse(...P([0.5, -0.26]), 0.24 * U, 0.08 * U), K.lighter(d.toeBox, 0.28), 0.04 * U, 0.8);
	sil.push(dome);
	const toeCap = S([[0.6, solT + 0.1], [0.66, -0.02], [0.88, -0.08], [1.07, 0.04], [1.12, solT + 0.1]], 0.5);
	g += k.clip(dome, finish(toeCap, d.toe, d.toeKind, [0.6, -0.05, 1.1, solT]));

	// --- the thick two-layer puffy sole: foam (sole) over the outsole (base), the stripe between
	const foam = S([[-1.03, solT + 0.02], [-0.7, solT - 0.03], [-0.35, solT - 0.01], [0.0, solT - 0.03], [0.35, solT - 0.01], [0.7, solT - 0.03], [1.04, solT],
		[1.12, 0.26], [1.06, 0.46], [-1.04, 0.46], [-1.1, 0.26]], 0.5);
	const outsole = S([[-1.0, 0.44], [1.04, 0.44], [1.06, 0.56], [0.92, 0.63], [-0.9, 0.63], [-1.02, 0.56]], 0.5);
	g += finish(outsole, d.base, d.baseKind, [-1.02, 0.44, 1.06, 0.63]);
	g += finish(foam, d.sole, d.soleKind, [-1.1, solT - 0.03, 1.12, 0.46]);
	g += k.soft(foam, poly([[-1.2, 0.36], [1.2, 0.36], [1.2, 0.6], [-1.2, 0.6]]), K.darker(d.sole, 0.12), 0.04 * U, 0.7);
	g += k.soft(foam, poly([[-1.2, solT - 0.1], [1.2, solT - 0.1], [1.2, solT + 0.07], [-1.2, solT + 0.07]]), K.lighter(d.sole, 0.5), 0.03 * U, 0.6);
	if (d.rainbowStripe) {
		const o = d.rainbowOffset || 0;
		for (let i = 0; i < 6; i++) g += k.clip(foam, k.path(poly([[-1.1 + i * 0.37, 0.4], [-0.73 + i * 0.37, 0.4], [-0.73 + i * 0.37, 0.46], [-1.1 + i * 0.37, 0.46]]), RAINBOW[(i + o) % 6]));
	} else g += k.clip(foam, finish(poly([[-1.2, 0.4], [1.2, 0.4], [1.2, 0.46], [-1.2, 0.46]]), d.stripe, d.stripeKind, [-1.1, 0.4, 1.1, 0.46]));
	sil.push(foam, outsole);

	// --- the laces: an eyestay band over the vamp, fat X laces, eyelets and a bow
	const stay = [[-0.12, -0.62], [0.14, -0.57], [0.48, -0.43], [0.46, -0.27], [0.14, -0.39], [-0.1, -0.45]];
	g += k.path(K.roundPoly(stay.map(P), 0.04 * U), d.eyestay);
	sil.push(K.roundPoly(stay.map(P), 0.04 * U));
	[[-0.01, -0.54], [0.17, -0.47], [0.35, -0.39]].forEach(([u, v], i) => {
		const col = d.rainbowLaces ? RAINBOW[(i + (d.rainbowOffset || 0)) % 6] : d.lace;
		const bar = (deg) => K.roundPoly([[-0.16, -0.05], [0.16, -0.05], [0.16, 0.05], [-0.16, 0.05]].map(([a, b]) => K.rotp(P([u + a, v + b]), P([u, v]), deg)), 0.05 * U); // fat X laces (the pairs' loudest detail)
		for (const deg of [-32, 48]) {
			const b0 = bar(deg);
			g += `<path d="${b0}" fill="${K.darker(col, 0.35)}" transform="translate(0 ${0.012 * U})"/>` + k.path(b0, col) + (d.laceKind === 'neon' ? k.soft(b0, b0, K.lighter(col, 0.6), 0.01 * U, 0.6) : '');
		}
		g += k.path(K.circle(...P([u - 0.11, v + 0.08]), 0.024 * U), d.eyelet) + k.path(K.circle(...P([u + 0.12, v + 0.03]), 0.024 * U), d.eyelet);
	});
	const bowCol = d.rainbowLaces ? RAINBOW[(d.rainbowOffset || 0) % 6] : d.lace;
	const bowL = K.ellipse(...P([-0.14, -0.66]), 0.1 * U, 0.055 * U, -28), bowR = K.ellipse(...P([0.02, -0.65]), 0.1 * U, 0.055 * U, 22);
	g += k.path(bowL, bowCol) + k.path(bowR, bowCol) + k.path(K.circle(...P([-0.06, -0.61]), 0.045 * U), K.darker(bowCol, 0.1));
	sil.push(bowL, bowR);

	// --- the padded pillow collar round the opening
	const collar = S([[-1.02, -0.38], [-0.98, -0.58], [-0.72, -0.67], [-0.42, -0.66], [-0.2, -0.61], [-0.14, -0.48], [-0.32, -0.48], [-0.62, -0.5], [-0.88, -0.41]], 0.5);
	g += finish(collar, d.collar, d.collarKind, [-1.02, -0.67, -0.14, -0.38]);
	g += k.soft(collar, K.ellipse(...P([-0.6, -0.62]), 0.36 * U, 0.04 * U), K.lighter(d.collar, 0.3), 0.025 * U, 0.8);
	sil.push(collar);

	// wings on the outer side of the ankle, fanning up and back
	for (const [, c1, c2, kind, size] of deco('wings')) {
		const sz = size || 1;
		const root = [-0.5, -0.3];
		const feathers = [[1.0, 14], [0.92, 34], [0.8, 54], [0.64, 74]];
		const fs = [];
		feathers.forEach(([len, ang], i) => {
			const a = ((180 - 8 - ang) * Math.PI) / 180;
			const L = len * 0.9 * sz, w = 0.15 * sz;
			const tip = [root[0] + Math.cos(a) * L, root[1] - Math.sin(a) * L];
			const n = [-Math.sin(a) * w, -Math.cos(a) * w];
			const f = S([[root[0] + n[0] * 0.5, root[1] + n[1] * 0.5], [(root[0] + tip[0]) / 2 + n[0], (root[1] + tip[1]) / 2 + n[1]], tip,
				[(root[0] + tip[0]) / 2 - n[0], (root[1] + tip[1]) / 2 - n[1]], [root[0] - n[0] * 0.5, root[1] - n[1] * 0.5]], 0.55);
			fs.push({ f, col: i % 2 ? c2 : c1, box: [Math.min(root[0], tip[0]), Math.min(root[1], tip[1]), Math.max(root[0], tip[0]), Math.max(root[1], tip[1])] });
		});
		const covert = K.ellipse(...P([root[0] - 0.02, root[1] + 0.02]), 0.13 * sz * U, 0.1 * sz * U, -30);
		fs.push({ f: covert, col: c2 || c1, box: [root[0] - 0.15, root[1] - 0.1, root[0] + 0.1, root[1] + 0.12] });
		for (const x of fs) { g += k.sep([x.f], 0.03 * U) + finish(x.f, x.col, kind, x.box); sil.push(x.f); }
	}

	// on the tongue / collar: a crown, a "+1"; the toe badge; white slivers
	let front = '';
	for (const [, col, gem, onCollar] of deco('crown')) {
		const c = onCollar ? [-0.6, -0.68] : [-0.08, -1.13], w = 0.36;
		const cr = K.roundPoly([[-0.5, 0.0], [-0.5, -0.55], [-0.27, -0.25], [0, -0.7], [0.27, -0.25], [0.5, -0.55], [0.5, 0.0]].map(([a, b]) => P([c[0] + a * w, c[1] + b * w])), 0.02 * U);
		front += k.sep([cr], 0.03 * U) + k.path(cr, col) + k.soft(cr, K.poly([[0, 0.0], [0.6, 0.0], [0.6, -0.8], [0.1, -0.8]].map(([a, b]) => P([c[0] + a * w, c[1] + b * w]))), K.darker(col, 0.15), 0.02 * U, 0.8);
		for (const [a, b] of [[-0.5, -0.55], [0, -0.7], [0.5, -0.55]]) front += k.path(K.circle(...P([c[0] + a * w, c[1] + b * w]), 0.035 * U), gem);
		front += k.path(K.circle(...P([c[0], c[1] - 0.12 * w]), 0.05 * U), gem);
		sil.push(cr);
	}
	for (const [, col] of deco('plusOne')) front += plusOne(P([-0.08, -0.8]), 0.07 * U, col);
	for (const [, kind, col] of deco('toeBadge')) {
		const c = P([0.78, -0.12]), s = 0.08 * U;
		if (kind === 'star') front += starPath(c, s * 1.15, col);
		else if (kind === 'sparkle') front += k.flare(c[0], c[1], s * 1.4, s * 1.4, 0, col, 0.2);
		else front += `<path d="${K.poly([[c[0], c[1] - s], [c[0] + s, c[1]], [c[0], c[1] + s], [c[0] - s, c[1]]])}" fill="${col}"/>` + k.path(K.poly([[c[0], c[1] - s], [c[0] + s, c[1]], [c[0], c[1]]]), K.lighter(col, 0.5));
	}
	front += k.streak([P([-0.94, -0.58]), P([-0.72, -0.66]), P([-0.46, -0.66])], 0.04 * U, { bias: 0.5, power: 0.6 });
	front += k.streak([P([0.4, -0.34]), P([0.68, -0.36]), P([0.94, -0.2])], 0.055 * U, { bias: 0.5, power: 0.6 });

	function starPath(c, R, col) {
		const pts = [];
		for (let i = 0; i < 10; i++) { const a = -Math.PI / 2 + (i * Math.PI) / 5, rr = i % 2 ? R * 0.45 : R; pts.push([c[0] + rr * Math.cos(a), c[1] + rr * Math.sin(a)]); }
		return `<path d="${K.poly(pts)}" fill="${col}" stroke="${col}" stroke-width="${R * 0.18}" stroke-linejoin="round"/>`;
	}
	function plusOne(c, s, col) {
		const plus = K.poly([[-1, -0.3], [-0.3, -0.3], [-0.3, -1], [0.3, -1], [0.3, -0.3], [1, -0.3], [1, 0.3], [0.3, 0.3], [0.3, 1], [-0.3, 1], [-0.3, 0.3], [-1, 0.3]].map(([a, b]) => [c[0] - s * 0.8 + a * s * 0.7, c[1] + b * s * 0.7]));
		const one = K.poly([[0.1, -1], [0.55, -1], [0.55, 1], [0.15, 1], [0.15, -0.45], [-0.1, -0.3], [-0.1, -0.7]].map(([a, b]) => [c[0] + s * 0.5 + a * s, c[1] + b * s]));
		return `<path d="${plus}" fill="${col}"/><path d="${one}" fill="${col}"/>`;
	}

	// --- the rarity ladder (ShoeFX.tier): glow, edge glow, halo, sparkles. The glows stay inside the canvas margin:
	// the picture is framed by the shoe alone (frameBy: 'shoe'), so every rarity draws the shoe at the same size.
	const out = { sil, body: back + g + front };
	const rc = RARITY[r - 1];
	let under = '';
	if (r >= 3) {
		const fill = r === 6 ? k.lin(...P([-1, 0]), ...P([1, 0]), RAINBOW.map((c, i) => [i / 5, c])) : rc;
		under += k.glow(sil, fill, [0, 0, 0, 0.15, 0.16, 0.17, 0.18][r] * U, [0, 0, 0, 0.04, 0.045, 0.05, 0.05][r] * U, [0, 0, 0, 0.6, 0.75, 0.85, 0.95][r]);
	}
	if (r >= 5) under += k.glow(sil, r === 6 ? '#ffffff' : K.lighter(rc, 0.5), 0.135 * U, 0.015 * U, 0.95);
	out.under = under;
	let over = '';
	if (r === 6) {
		// the Secret halo: a ring of rainbow dots round the top of the tongue (as on the worn shoes)
		const hc = [-0.08, -1.06];
		for (let i = 0; i < 12; i++) {
			const t = (i / 12) * Math.PI * 2;
			const p = P([hc[0] + Math.cos(t) * 0.32, hc[1] + Math.sin(t) * 0.075]);
			over += `<path d="${K.circle(p[0], p[1], 0.04 * U)}" fill="${k.NAVY}"/><path d="${K.circle(p[0], p[1], 0.026 * U)}" fill="${RAINBOW[i % 6]}"/>`;
		}
	}
	const sparkles = [[], [[-0.96, -0.82, 0.13]], [[-0.98, -0.84, 0.14], [1.0, -0.4, 0.1]], [[-1.0, -0.86, 0.15], [1.02, -0.42, 0.11], [0.36, -0.72, 0.09]],
		[[-1.0, -0.88, 0.16], [1.04, -0.44, 0.12], [0.38, -0.74, 0.1], [-1.12, 0.3, 0.09]], [[-1.0, -0.9, 0.17], [1.06, -0.46, 0.13], [0.38, -0.76, 0.1], [-1.12, 0.3, 0.1], [0.62, 0.7, 0.09]]][r - 1];
	for (const [u, v, s] of sparkles) over += k.flare(...P([u, v]), s * U, s * U, 0, '#ffffff', 0.17);
	out.over = over;
	return out;
}

module.exports = Object.entries(DEFS).map(([id, d]) => ({ name: 'Shoe_' + id, frameBy: 'shoe', draw: (k) => sneaker(k, d) }));
module.exports.DEFS = DEFS;
module.exports.RARITY = RARITY;
module.exports.sneaker = sneaker;
