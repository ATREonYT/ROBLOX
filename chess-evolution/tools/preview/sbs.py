import sys
from PIL import Image, ImageDraw
ref, ours, out = sys.argv[1:4]
r = Image.open(ref).convert('RGB'); o = Image.open(ours).convert('RGB')
H = 560
def fit(im):  # crop to 16:9 then resize
    w, h = im.size; tw = int(h * 16 / 9)
    if tw <= w: im = im.crop(((w - tw)//2, 0, (w - tw)//2 + tw, h))
    else:
        th = int(w * 9 / 16); im = im.crop((0, (h - th)//2, w, (h - th)//2 + th))
    return im.resize((int(H * 16 / 9), H))
r, o = fit(r), fit(o)
c = Image.new('RGB', (r.width * 2 + 12, H + 34), 'white')
c.paste(r, (0, 34)); c.paste(o, (r.width + 12, 34))
d = ImageDraw.Draw(c); d.text((10, 10), "REFERENCE", fill='black'); d.text((r.width + 22, 10), "OURS (live Studio)", fill='black')
c.save(out, quality=85)
