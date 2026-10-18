// The overflow check (owner: "the rarities ... go out of the uis borders"; "check every detail"). Draws each
// exported screen with render.html and asks the page itself (the DOM) where every piece of text really lands:
//   - text wider than its own box (a one-line name running past its label; "..." truncation counts as fitting),
//     or wrapped text taller than its box;
//   - text (or a coloured chip such as a rarity badge) past the edge of its window, or off the screen;
//   - text spilling out of the panel, card or button it sits in (the nearest box with a fill);
//   - two pieces of text drawn over each other.
// Text scrolled out of a list (clipped by its ScrollingFrame) is skipped. The preview draws Montserrat for
// Gotham, which is a little wider, so a pass here is on the safe side.
// Usage: node overflow.js <manifest>   (lines "name width height file.json", written by overflow.sh)
// Prints "FAIL <screen>: <path> "<text>" <what>" lines and "overflow: N ok, M failed".
const { chromium } = require('playwright');
const fs = require('fs');
const path = require('path');

// Meant to hang over an edge or sit on top of something (checked by eye; keep each with its reason).
const ALLOW = [
  [/LobbyHud\.Right\.Spin\.FreeTag "FREE" spills \d+px out of Spin$/, 'the FREE sticker sits on the Spin button\'s corner'],
  [/PowerBar\.Card\d\.Key\.Text "[^"]*" sticks \d+px out of its window \(PowerBar\)$/, 'the key pills sit on the tiles\' top corners'],
  [/PowerBar\.Card\d\.Icon "[^"]*" overlaps PowerBar\.Card\d\.Count/, 'USED / the seconds print over the dimmed icon'],
];

(async () => {
  const lines = fs.readFileSync(process.argv[2], 'utf8').split('\n').filter(l => l.trim() !== '');
  const browser = await chromium.launch({ args: ['--allow-file-access-from-files'] });
  const page = await browser.newPage({ viewport: { width: 1600, height: 1000 } });
  await page.goto('file://' + path.resolve(__dirname, 'render.html'));
  let ok = 0, failed = 0;
  for (const line of lines) {
    const [name, W, H, file] = line.trim().split(/\s+/);
    if (!fs.existsSync(file)) { failed++; console.log(`FAIL ${name}: no export (${file})`); continue; }
    const tree = JSON.parse(fs.readFileSync(file, 'utf8'));
    await page.setViewportSize({ width: +W, height: +H });
    await page.evaluate(async ([t, w, h]) => { await window.renderUI(t, w, h, null); }, [tree, +W, +H]);
    const res = await page.evaluate(([W, H]) => {
      const stage = document.getElementById('stage');
      const TOL = 2; // px at the shot's scale (the shots are 2x: one Roblox pixel)
      const out = [], texts = [];
      const rectOf = el => el.getBoundingClientRect();
      const inter = (a, b) => ({ left: Math.max(a.left, b.left), top: Math.max(a.top, b.top), right: Math.min(a.right, b.right), bottom: Math.min(a.bottom, b.bottom) });
      const empty = r => r.right - r.left <= 0.5 || r.bottom - r.top <= 0.5;
      const pathOf = el => { const p = []; for (let e = el; e && e !== stage; e = e.parentElement) if (e.dataset && e.dataset.name) p.unshift(e.dataset.name); return p.join('.'); };
      const visible = el => { for (let e = el; e && e !== stage; e = e.parentElement) if (parseFloat(getComputedStyle(e).opacity) < 0.05) return false; return true; };
      for (const el of stage.querySelectorAll('[data-text="1"]')) {
        const span = el.querySelector(':scope > .t > span');
        if (!span || span.textContent.trim() === '' || parseFloat(el.dataset.tT) >= 0.95 || !visible(el)) continue;
        const box = rectOf(el);
        // where the glyphs are: the text's own range (a long word overflows its line box); a "..." text ends at its box
        let g;
        if (el.dataset.trunc) g = rectOf(span); else { const r = document.createRange(); r.selectNodeContents(span); g = r.getBoundingClientRect(); }
        if (g.width < 1) continue;
        // clipped by a scrolling list or a clipping frame: only the part inside counts; none = scrolled away
        let seen = { left: g.left, top: g.top, right: g.right, bottom: g.bottom };
        for (let e = el.parentElement; e && e !== stage; e = e.parentElement) if (e.dataset.clip) seen = inter(seen, rectOf(e));
        if (empty(seen)) continue;
        if (empty(inter(seen, { left: 0, top: 0, right: W, bottom: H }))) continue; // (slid off the screen on purpose: the HUD steps aside for a window)
        const fs = parseFloat(el.dataset.fs) || 14;
        const cl = box.left + parseFloat(el.dataset.padL || 0), cr = box.right - parseFloat(el.dataset.padR || 0);
        const text = span.textContent.replace(/\s+/g, ' ').trim().slice(0, 40);
        const who = `${pathOf(el)} "${text}"`;
        const fails = [];
        // turned text (the Spin wheel's slices): screen boxes of turned things are their bounding boxes, so compare
        // the unturned layout widths instead, and leave it out of the overlap test
        let turned = false;
        for (let e = el; e && e !== stage; e = e.parentElement) if (e.style.transform && e.style.transform !== 'none') turned = true;
        const over = turned ? (el.dataset.trunc ? 0 : (span.offsetWidth - (el.clientWidth - parseFloat(el.dataset.padL || 0) - parseFloat(el.dataset.padR || 0))) / 2)
          : Math.max(cl - g.left, g.right - cr);
        if (over > TOL) fails.push(`runs ${Math.round(over)}px past its own box`);
        if (el.dataset.wrap && g.height - box.height > 0.6 * fs) fails.push(`wraps ${Math.round(g.height - box.height)}px below its box`);
        // the window: the screen's top-level frame the text belongs to (a window, a HUD cluster)
        let top = el; while (top.parentElement && top.parentElement !== stage) top = top.parentElement;
        const chip = el.dataset.bg ? box : seen; // a coloured chip (badge) must stay inside too, not just its word
        if (top !== el) {
          const t = rectOf(top);
          const past = Math.max(t.left - chip.left, chip.right - t.right, t.top - chip.top, chip.bottom - t.bottom);
          if (past > TOL) fails.push(`sticks ${Math.round(past)}px out of its window (${top.dataset.name})`);
        }
        const off = Math.max(-chip.left, chip.right - W, -chip.top, chip.bottom - H);
        if (off > TOL) fails.push(`goes ${Math.round(off)}px off the screen`);
        // the panel / card / button it sits in (nearest box with a fill)
        for (let e = el.parentElement; e && e !== stage; e = e.parentElement) {
          if (!e.dataset.bg) continue;
          const p = rectOf(e);
          if (p.width < 2 || p.height < 2) break;
          if (empty(inter(p, seen))) break; // (placed beside it on purpose, e.g. the seconds next to a timer bar)
          const past = Math.max(p.left - seen.left, seen.right - p.right);
          if (past > TOL) fails.push(`spills ${Math.round(past)}px out of ${e.dataset.name}`);
          break;
        }
        // for the overlap test: where the letters are (the line box less its empty room above the caps and below)
        const lr = inter(seen, { left: cl - TOL, right: cr + TOL, top: -1e9, bottom: 1e9 });
        if (!turned) texts.push({ el, who, r: { left: lr.left, right: lr.right, top: lr.top + 0.22 * fs, bottom: lr.bottom - 0.12 * fs }, text, name: el.dataset.name });
        if (fails.length) out.push(`${who} ${fails.join('; ')}`); else out.push(null);
      }
      // two texts over each other (a drop shadow under its own label doesn't count)
      for (let i = 0; i < texts.length; i++) for (let j = i + 1; j < texts.length; j++) {
        const a = texts[i], b = texts[j];
        if (a.el.contains(b.el) || b.el.contains(a.el)) continue;
        // a drop shadow and its label (Kit.name / Kit.title; the harness doesn't copy text changes to the shadow)
        if (a.name === b.name + 'Shadow' || b.name === a.name + 'Shadow' || (a.text === b.text && a.name === b.name)) continue;
        const r = inter(a.r, b.r);
        if (empty(r)) continue;
        const area = (r.right - r.left) * (r.bottom - r.top);
        const small = Math.min((a.r.right - a.r.left) * (a.r.bottom - a.r.top), (b.r.right - b.r.left) * (b.r.bottom - b.r.top));
        if (area > 0.2 * small && (r.right - r.left) > 3 && (r.bottom - r.top) > 3) out.push(`${a.who} overlaps ${b.who}`);
      }
      return out;
    }, [+W, +H]);
    for (const r of res) {
      if (r === null || ALLOW.some(([re]) => re.test(r))) ok++; else { failed++; console.log(`FAIL ${name}: ${r}`); }
    }
  }
  await browser.close();
  console.log(`overflow: ${ok} ok, ${failed} failed`);
})();
