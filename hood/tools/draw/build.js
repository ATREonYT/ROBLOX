#!/usr/bin/env node
// build.js: draw the UI icons (brief 26). Each icon module in ./icons draws one or more icons as SVG with the kit;
// this script frames each drawing (the longest side, outline included, = 0.879 of the canvas, centred), writes the
// self-contained SVG source to hood/art/draw/<Name>.svg and renders the PNG with alpha in headless Chromium.
//
//   node hood/tools/draw/build.js --out <dir> [Name ...]     # PNGs to <dir> (default: every icon)
//   node hood/tools/draw/build.js --final [Name ...]          # PNGs to hood/art/icons3d/<Name>.png
//   options: --size 512 (PNG size), --nosvg (do not write hood/art/draw), --list
'use strict';

const fs = require('fs');
const path = require('path');
const { chromium } = require('playwright');
const K = require('./kit');

const HERE = __dirname;
const HOOD = path.resolve(HERE, '..', '..');
const SVG_DIR = path.join(HOOD, 'art', 'draw');
const FINAL_DIR = path.join(HOOD, 'art', 'icons3d');
const FRAME = 0.879; // longest side of the drawn picture, outline included, as a fraction of the canvas

function loadIcons() {
	const all = {};
	for (const f of fs.readdirSync(path.join(HERE, 'icons')).sort()) {
		if (!f.endsWith('.js')) continue;
		let m = require(path.join(HERE, 'icons', f));
		if (!Array.isArray(m)) m = [m];
		for (const ic of m) all[ic.name] = ic;
	}
	return all;
}

// the drawn picture's box (alpha > 10%) in output px, from the SVG rendered on a canvas in the page
async function alphaBox(page, svg, size) {
	return page.evaluate(async ([src, n]) => {
		const img = new Image();
		img.src = 'data:image/svg+xml;charset=utf-8,' + encodeURIComponent(src);
		await img.decode();
		const c = document.createElement('canvas');
		c.width = c.height = n;
		const x = c.getContext('2d');
		x.drawImage(img, 0, 0, n, n);
		const d = x.getImageData(0, 0, n, n).data;
		let x0 = n, y0 = n, x1 = -1, y1 = -1;
		for (let y = 0; y < n; y++) for (let i = 0; i < n; i++) if (d[(y * n + i) * 4 + 3] > 25) {
			if (i < x0) x0 = i; if (i > x1) x1 = i; if (y < y0) y0 = y; if (y > y1) y1 = y;
		}
		return [x0, y0, x1 + 1, y1 + 1];
	}, [svg, size]);
}

async function main() {
	const argv = process.argv.slice(2);
	let out = null, size = 512, writeSvg = true;
	const names = [];
	for (let i = 0; i < argv.length; i++) {
		const a = argv[i];
		if (a === '--out') out = argv[++i];
		else if (a === '--final') out = FINAL_DIR;
		else if (a === '--size') size = +argv[++i];
		else if (a === '--nosvg') writeSvg = false;
		else if (a === '--list') { console.log(Object.keys(loadIcons()).join('\n')); return; }
		else names.push(a);
	}
	if (!out) throw new Error('give --out <dir> or --final');
	fs.mkdirSync(out, { recursive: true });
	if (writeSvg) fs.mkdirSync(SVG_DIR, { recursive: true });
	const icons = loadIcons();
	const todo = names.length ? names : Object.keys(icons);

	const browser = await chromium.launch();
	const page = await browser.newPage({ viewport: { width: size, height: size }, deviceScaleFactor: 1 });
	const frames = {};
	async function frameOf(name, given) {
		if (frames[name]) return frames[name];
		let k, drawing;
		if (given) ({ k, drawing } = given);
		else { k = new K.Kit(name); drawing = icons[name].draw(k, K); }
		// 1. the silhouette's fill box in working units
		const silSvg = `<svg xmlns="http://www.w3.org/2000/svg" width="512" height="512" viewBox="0 0 512 512"><g id="s">${drawing.sil.map((x) => K.silPath(x, 'fill-rule')).join('')}</g></svg>`;
		await page.setContent(`<html><body style="margin:0">${silSvg}</body></html>`);
		const bb = await page.evaluate(() => { const b = document.getElementById('s').getBBox(); return [b.x, b.y, b.width, b.height]; });
		// 2. framing: longest side + 2 outline bands = FRAME * size, first from the box, then corrected twice from the
		// rendered picture's real alpha box (getBBox is loose for rotated pieces; the outline is heavier bottom-right)
		const ow = K.OUTLINE_PX * (size / 512);
		let s = (FRAME * size - 2 * ow) / Math.max(bb[2], bb[3]);
		let cx = bb[0] + bb[2] / 2, cy = bb[1] + bb[3] / 2;
		for (let pass = 0; pass < 2; pass++) {
			const vs = size / s;
			// frameBy 'shoe': measure the object alone (its rarity glow and sparkles fall in the margin)
			const meas = icons[name] && icons[name].frameBy === 'shoe' ? { ...drawing, under: '', over: '' } : drawing;
			const ab = await alphaBox(page, k.svg(meas, [cx - vs / 2, cy - vs / 2, vs, vs], ow / s, size), size);
			const longest = Math.max(ab[2] - ab[0], ab[3] - ab[1]);
			cx += ((ab[0] + ab[2]) / 2 - size / 2) / s; cy += ((ab[1] + ab[3]) / 2 - size / 2) / s;
			s *= (FRAME * size - 2 * ow) / (longest - 2 * ow);
		}
		const vs = size / s;
		frames[name] = { view: [cx - vs / 2, cy - vs / 2, vs, vs], s };
		return frames[name];
	}
	for (const name of todo) {
		const ic = icons[name];
		if (!ic) { console.error('no icon', name); continue; }
		const k = new K.Kit(name);
		const drawing = ic.draw(k, K);
		const ow = K.OUTLINE_PX * (size / 512); // outline band in output px
		// a piece (a box's lid or body) uses its whole picture's exact framing
		const fr = await frameOf(ic.frameAs || name, ic.frameAs ? null : { k, drawing });
		const svg = k.svg(drawing, fr.view, ow / fr.s, size);
		if (writeSvg) fs.writeFileSync(path.join(SVG_DIR, name + '.svg'), svg);
		// 3. render
		await page.setContent(`<html><body style="margin:0;background:transparent">${svg}</body></html>`);
		await page.screenshot({ path: path.join(out, name + '.png'), omitBackground: true, clip: { x: 0, y: 0, width: size, height: size } });
		const fb = await alphaBox(page, svg, size);
		console.log(`${name}: ${((fb[2] - fb[0]) / (fb[3] - fb[1])).toFixed(3)} w:h, box ${fb.join(',')}`);
	}
	await browser.close();
}

main().catch((e) => { console.error(e); process.exit(1); });
