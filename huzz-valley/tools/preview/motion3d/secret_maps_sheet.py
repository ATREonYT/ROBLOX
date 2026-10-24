# Before | after sheet of the Secret cutscene camera on each map, from secret_maps_scene.luau's film (1 fps, frames in
# pairs: map 1 before, map 1 after, map 2 before...). python3 secret_maps_sheet.py <film.mp4> <out.jpg> "Map A|Map B|..."
import subprocess, sys, os, tempfile
from PIL import Image, ImageDraw, ImageFont
film, out = sys.argv[1], sys.argv[2]
names = sys.argv[3].split('|')
W, H = 640, 360
sheet = Image.new('RGB', (2 * W, len(names) * (H + 26) + 26), (12, 12, 16))
d = ImageDraw.Draw(sheet)
try:
    font = ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf', 16)
except Exception:
    font = ImageFont.load_default()
d.text((8, 4), 'BEFORE: looked from the lobby, an invisible box snapped it in', fill=(255, 150, 150), font=font)
d.text((W + 8, 4), 'AFTER: the clearest side, planned once', fill=(150, 255, 170), font=font)
tmp = tempfile.mkdtemp()
for i in range(2 * len(names)):
    p = os.path.join(tmp, f'{i}.png')
    subprocess.run(['ffmpeg', '-loglevel', 'error', '-y', '-i', film, '-vf', f'select=eq(n\\,{i})', '-vsync', '0', '-frames:v', '1', p], check=True)
    im = Image.open(p).convert('RGB').resize((W, H), Image.LANCZOS)
    x, y = (i % 2) * W, 26 + (i // 2) * (H + 26)
    sheet.paste(im, (x, y + 26))
    d.text((x + 8, y + 5), names[i // 2] + ('  before' if i % 2 == 0 else '  after'), fill=(235, 235, 245), font=font)
sheet.save(out, quality=78)
print(out, os.path.getsize(out) // 1024, 'KB')
