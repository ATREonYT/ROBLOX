# Contact sheet of the Secret cutscene film, one frame per camera beat with a label (docs/previews/secret-camera.jpg).
# python3 secret_camera_sheet.py <film.mp4> <out.jpg> [times,comma,separated] ["label|label|..."]
# Times are the cutscene's seconds (the film starts 1 s before it).
import subprocess, sys, os, tempfile
from PIL import Image, ImageDraw, ImageFont
film, out = sys.argv[1], sys.argv[2]
TIMES = [float(x) for x in (sys.argv[3].split(',') if len(sys.argv) > 3 else
    '0.2,0.95,1.7,2.45,3.1,3.6,4.1,4.75,5.6,6.2,6.6,7.2,7.7,8.4,9.2,9.8'.split(','))]
LABELS = dict(zip(TIMES, sys.argv[4].split('|'))) if len(sys.argv) > 4 else {}
PRE = 1.0
W, H = 384, 216
cols = 4
rows = (len(TIMES) + cols - 1) // cols
sheet = Image.new('RGB', (cols * W, rows * (H + 22)), (12, 12, 16))
d = ImageDraw.Draw(sheet)
try:
    font = ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf', 15)
except Exception:
    font = ImageFont.load_default()
tmp = tempfile.mkdtemp()
for i, t in enumerate(TIMES):
    p = os.path.join(tmp, f'{i}.png')
    subprocess.run(['ffmpeg', '-loglevel', 'error', '-y', '-ss', f'{t + PRE:.3f}', '-i', film, '-frames:v', '1', p], check=True)
    im = Image.open(p).convert('RGB').resize((W, H), Image.LANCZOS)
    x, y = (i % cols) * W, (i // cols) * (H + 22)
    sheet.paste(im, (x, y + 22))
    d.text((x + 6, y + 3), f'{t:.1f} s  {LABELS.get(t, "")}', fill=(235, 235, 245), font=font)
sheet.save(out, quality=72)
print(out, os.path.getsize(out) // 1024, 'KB')
