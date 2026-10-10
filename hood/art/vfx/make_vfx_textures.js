// Hood particle/beam textures, drawn on a canvas in headless Chromium.
// Run: node make_vfx_textures.js   (needs playwright; writes <name>.png next to this file)
// All textures are white on transparent so ParticleEmitter.Color / Beam.Color tint them in game.
const path = require('path');
const { chromium } = require(process.env.PLAYWRIGHT_PATH || 'playwright');
const SIZE = 256;
const draw = {
  // Soft round glow with a hot core: the base layer of every aura and burst.
  glow: `const g=c.createRadialGradient(128,128,0,128,128,128);
    g.addColorStop(0,'rgba(255,255,255,1)');g.addColorStop(0.18,'rgba(255,255,255,0.85)');
    g.addColorStop(0.45,'rgba(255,255,255,0.32)');g.addColorStop(1,'rgba(255,255,255,0)');
    c.fillStyle=g;c.fillRect(0,0,256,256);`,
  // Four-point twinkle: thin cross flares over a small core.
  sparkle: `c.translate(128,128);
    for(const [len,w] of [[124,10],[70,6]]){ for(let i=0;i<4;i++){ c.save(); c.rotate(i*Math.PI/2 + (len<100?Math.PI/4:0));
      const g=c.createLinearGradient(0,0,len,0); g.addColorStop(0,'rgba(255,255,255,1)'); g.addColorStop(1,'rgba(255,255,255,0)');
      c.fillStyle=g; c.beginPath(); c.moveTo(0,-w); c.lineTo(len,0); c.lineTo(0,w); c.closePath(); c.fill(); c.restore(); } }
    const r=c.createRadialGradient(0,0,0,0,0,40); r.addColorStop(0,'rgba(255,255,255,1)'); r.addColorStop(1,'rgba(255,255,255,0)');
    c.fillStyle=r; c.beginPath(); c.arc(0,0,40,0,7); c.fill();`,
  // Chunky cartoon star with a darker inner line so it still reads when tinted.
  star: `c.translate(128,134); c.beginPath();
    for(let i=0;i<10;i++){ const a=-Math.PI/2+i*Math.PI/5, r=i%2?50:112; c.lineTo(Math.cos(a)*r,Math.sin(a)*r); }
    c.closePath(); c.lineJoin='round'; c.fillStyle='#fff'; c.fill();
    c.beginPath(); for(let i=0;i<10;i++){ const a=-Math.PI/2+i*Math.PI/5, r=i%2?34:80; c.lineTo(Math.cos(a)*r,Math.sin(a)*r); }
    c.closePath(); c.fillStyle='rgba(255,255,255,0.75)'; c.fill();`,
  // Soft ring for shockwaves (grow Size, fade Transparency).
  ring: `const g=c.createRadialGradient(128,128,70,128,128,124);
    g.addColorStop(0,'rgba(255,255,255,0)');g.addColorStop(0.45,'rgba(255,255,255,1)');g.addColorStop(0.7,'rgba(255,255,255,0.55)');g.addColorStop(1,'rgba(255,255,255,0)');
    c.fillStyle=g;c.fillRect(0,0,256,256);`,
  // Cartoon smoke puff: overlapping soft lobes with a lit top.
  smoke: `const lobes=[[128,140,70],[86,128,46],[170,124,50],[112,92,44],[150,96,40],[128,168,52]];
    for(const [x,y,r] of lobes){ const g=c.createRadialGradient(x,y-r*0.2,0,x,y,r); g.addColorStop(0,'rgba(255,255,255,0.95)'); g.addColorStop(0.7,'rgba(255,255,255,0.75)'); g.addColorStop(1,'rgba(255,255,255,0)');
      c.fillStyle=g; c.beginPath(); c.arc(x,y,r,0,7); c.fill(); }`,
  // Long soft streak for fast sparks (use with Orientation VelocityParallel).
  streak: `const g=c.createLinearGradient(0,0,256,0); g.addColorStop(0,'rgba(255,255,255,0)'); g.addColorStop(0.65,'rgba(255,255,255,1)'); g.addColorStop(1,'rgba(255,255,255,0)');
    c.fillStyle=g; c.beginPath(); c.ellipse(128,128,124,16,0,0,7); c.fill();
    const h=c.createLinearGradient(0,0,256,0); h.addColorStop(0.4,'rgba(255,255,255,0)'); h.addColorStop(0.75,'rgba(255,255,255,1)'); h.addColorStop(1,'rgba(255,255,255,0)');
    c.fillStyle=h; c.beginPath(); c.ellipse(150,128,90,6,0,0,7); c.fill();`,
  // Debris shard for wall breaks.
  shard: `c.translate(128,128); c.rotate(0.3); c.beginPath(); c.moveTo(-30,-100); c.lineTo(70,-40); c.lineTo(40,96); c.lineTo(-60,60); c.closePath();
    c.fillStyle='#fff'; c.fill(); c.beginPath(); c.moveTo(-30,-100); c.lineTo(70,-40); c.lineTo(10,0); c.closePath(); c.fillStyle='rgba(255,255,255,0.7)'; c.fill();`,
  // Confetti chip.
  confetti: `c.translate(128,128); c.rotate(0.2); c.fillStyle='#fff'; c.beginPath(); c.roundRect(-90,-46,180,92,14); c.fill();
    c.fillStyle='rgba(255,255,255,0.7)'; c.fillRect(-90,8,180,38);`,
  // Comic "POW" starburst for punch impacts.
  pow: `c.translate(128,128); c.beginPath(); const n=14;
    for(let i=0;i<n*2;i++){ const a=i*Math.PI/n, r=i%2?62:(118 - (i%4===0?16:0)); c.lineTo(Math.cos(a)*r,Math.sin(a)*r); }
    c.closePath(); c.fillStyle='#fff'; c.fill();
    c.beginPath(); for(let i=0;i<n*2;i++){ const a=i*Math.PI/n+0.1, r=i%2?40:76; c.lineTo(Math.cos(a)*r,Math.sin(a)*r); } c.closePath();
    c.fillStyle='rgba(255,255,255,0.6)'; c.fill();`,
  // Jagged lightning for beams (runs along the texture's length, left to right).
  lightning: `c.lineCap='round'; c.lineJoin='round'; let y=128; const pts=[[0,128]];
    for(let x=24;x<=256;x+=24){ y=128+(Math.sin(x*12.9898)*43758.5453%1)*70-35; pts.push([x,y]); }
    for(const [w,a] of [[34,0.25],[16,0.6],[6,1]]){ c.strokeStyle='rgba(255,255,255,'+a+')'; c.lineWidth=w; c.beginPath(); pts.forEach((p,i)=>i?c.lineTo(...p):c.moveTo(...p)); c.stroke(); }`,
  // Soft energy band for aura beams (bright centre line, soft edges, faint streaks).
  energy: `const g=c.createLinearGradient(0,0,0,256); g.addColorStop(0,'rgba(255,255,255,0)'); g.addColorStop(0.35,'rgba(255,255,255,0.5)'); g.addColorStop(0.5,'rgba(255,255,255,1)'); g.addColorStop(0.65,'rgba(255,255,255,0.5)'); g.addColorStop(1,'rgba(255,255,255,0)');
    c.fillStyle=g; c.fillRect(0,0,256,256);
    for(let i=0;i<9;i++){ const yy=60+i*16; c.fillStyle='rgba(255,255,255,0.35)'; c.fillRect((i*53)%200,yy,70,3); }`,
};
(async () => {
  const browser = await chromium.launch(process.env.CHROME ? { executablePath: process.env.CHROME } : {});
  const page = await browser.newPage({ viewport: { width: SIZE, height: SIZE } });
  for (const [name, code] of Object.entries(draw)) {
    await page.setContent(`<canvas id=c width=${SIZE} height=${SIZE}></canvas>`);
    const url = await page.evaluate(code => { const cv = document.getElementById('c'); const c = cv.getContext('2d'); new Function('c', code)(c); return cv.toDataURL('image/png'); }, code);
    require('fs').writeFileSync(path.join(__dirname, name + '.png'), Buffer.from(url.split(',')[1], 'base64'));
  }
  await browser.close();
  console.log('wrote', Object.keys(draw).join(', '));
})().catch(e => { console.error(e); process.exit(1); });
