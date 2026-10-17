# Side by side: the filmed Secret cutscene (motion3d/secret_scene.luau stills) next to the owner's Oct 17 reference
# (design/vfx/ref3), one row per beat, both cropped to the reference's viewport shape (Studio's 3D view, 897x434).
# Usage (from huzz-valley/): python3 tools/preview/secret_vs_ref.py <stills dir> <out.jpg>
#   stills: MOTION3D_KEEP=<dir> sh tools/preview/motion3d/video.sh tools/preview/motion3d/secret_scene.luau out.mp4
import glob, os, re, subprocess, sys, tempfile
from PIL import Image, ImageDraw, ImageFont

STILLS, OUT = sys.argv[1], sys.argv[2]
REF = 'design/vfx/ref3/vfx-reference-oct17.mp4'
VIEW = (8, 88, 905, 522)  # the reference's 3D view inside the Studio window
# (beat, reference second, our cutscene second) -- ours are secret_scene's STILL_AT times
BEATS = [
    ('first beam of light', 1.25, 1.0),
    ('twin beams + slashes', 1.75, 1.85),
    ('eyes open between the beams', 2.75, 2.5),
    ('impact: radial manga lines', 6.75, 2.74),
    ('burst', 12.25, 2.85),
    ('shards round her', 11.25, 3.2),
    ('hero shot, butterflies', 9.75, 3.6),
    ('aftermath', 13.75, 6.0),
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
