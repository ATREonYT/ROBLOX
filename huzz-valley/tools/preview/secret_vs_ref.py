# Side by side: the filmed Secret cutscene (motion3d/secret_scene.luau stills) next to the owner's Oct 17 reference
# (design/vfx/ref3), one row per beat, both cropped to the reference's viewport shape (Studio's 3D view, 897x434).
# Usage (from huzz-valley/): python3 tools/preview/secret_vs_ref.py <stills dir> <out.jpg>
#   stills: MOTION3D_KEEP=<dir> sh tools/preview/motion3d/video.sh tools/preview/motion3d/secret_scene.luau out.mp4
import glob, os, re, subprocess, sys, tempfile
from PIL import Image, ImageDraw, ImageFont

STILLS, OUT = sys.argv[1], sys.argv[2]
REF = 'design/vfx/ref3/vfx-reference-oct17.mp4'
VIEW = (8, 88, 905, 522)  # the reference's 3D view inside the Studio window
# (beat, reference second, our cutscene second) -- ours are secret_scene's STILL_AT times; docs/secret-beats.md.
# Since Oct 19 ours is 10 s (the reference ~14 s), so the pairs are the same beat, not the same second.
BEATS = [
    ('night, the orb', 0.4, 0.3),
    ('starburst / first light threads', 0.5, 0.7),
    ('first beam strikes', 1.0, 1.15),
    ('ladder beam + slashes', 1.6, 1.6),
    ('twin beams', 2.05, 1.95),
    ('eyes / ring of beams', 2.45, 2.45),
    ('eyes / beams converging', 2.7, 3.1),
    ('impact frame', 2.9, 3.46),
    ('impact: rays + sparkles, she appears', 2.8, 3.6),
    ('calm wide shot on her', 3.6, 4.1),
    ('ref: slashes round her / ours: her name', 4.95, 4.75),
    ('speed streaks, pushing in', 8.0, 5.6),
    ('face close-up', 9.65, 6.2),
    ('red streak lines', 10.5, 6.55),
    ('butterflies, flare grows', 11.8, 7.2),
    ('the burst', 12.3, 7.65),
    ('pink cloud', 12.7, 7.95),
    ('back to night / she rises at dawn', 13.6, 8.8),
]
W = 640
H = round(W * (VIEW[3] - VIEW[1]) / (VIEW[2] - VIEW[0]))
PRE = 1.0  # secret_scene films 1 s before the cutscene
stills = {int(re.findall(r'(\d+)', os.path.basename(p))[0]): p for p in glob.glob(os.path.join(STILLS, 'still_*.png'))}
font = ImageFont.load_default(size=20) if hasattr(ImageFont, 'load_default') else None
sheet = Image.new('RGB', (W * 2 + 30, 50 + len(BEATS) * (H + 34)), (18, 14, 28))
d = ImageDraw.Draw(sheet)
d.text((10, 14), 'OURS (game code, filmed offline)', fill=(255, 255, 255), font=font)
d.text((W + 30, 14), "REFERENCE (owner's Oct 17 video)", fill=(255, 255, 255), font=font)
tmp = tempfile.mkdtemp()
for i, (label, rt, ot) in enumerate(BEATS):
    y = 50 + i * (H + 34)
    f = round((ot + PRE) * 30)
    ours = Image.open(stills[min(stills, key=lambda k: abs(k - f))]).convert('RGB')
    ch = round(ours.width * H / W)
    top = (ours.height - ch) // 2
    ours = ours.crop((0, top, ours.width, top + ch)).resize((W, H), Image.LANCZOS)
    rp = os.path.join(tmp, f'r{i}.png')
    subprocess.run(['ffmpeg', '-loglevel', 'error', '-y', '-ss', str(rt), '-i', REF, '-frames:v', '1', rp], check=True)
    ref = Image.open(rp).convert('RGB').crop(VIEW).resize((W, H), Image.LANCZOS)
    d.text((10, y + 4), f'{label}  (ours {ot:.2f} s / ref {rt:.2f} s)', fill=(220, 210, 255), font=font)
    sheet.paste(ours, (0, y + 30))
    sheet.paste(ref, (W + 30, y + 30))
sheet.save(OUT, quality=88)
print('->', OUT)
