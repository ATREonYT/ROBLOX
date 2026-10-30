"""Measures the light in a game frame, patch by patch (owner Oct 19: "even, nice, cartoony lighting over the map").

For each named box: mean colour, brightness (0..1, sRGB mean of the channels), saturation (HSV, 0..1) and the
linear-light luminance; then the ratios that tell the look apart: lit face / shaded face of the same material (how
dark the shadow side is), cast shadow / sun on the same floor, and how blue the shade is (blue minus red in shade).
Writes a copy of the frame with the boxes drawn, so a person can check each box sits on what its name says.
Usage: python3 -I light_measure.py <frame.png> <boxes.json> <out.jpg>
  boxes.json: {"name": [left, top, right, bottom], ...} in the frame's pixels; pairs are named "<thing>_lit" /
  "<thing>_shade" (and "floor_sun" / "floor_shadow").
"""
import json
import sys
import colorsys
import numpy as np
from PIL import Image, ImageDraw


def lin(c):
    return np.where(c <= 0.04045, c / 12.92, ((c + 0.055) / 1.055) ** 2.4)


def stats(a):
    m = a.reshape(-1, 3).mean(0)
    h, s, v = colorsys.rgb_to_hsv(*m)
    L = lin(a.reshape(-1, 3))
    Y = (0.2126 * L[:, 0] + 0.7152 * L[:, 1] + 0.0722 * L[:, 2]).mean()
    return dict(rgb=[round(float(x) * 255) for x in m], bright=round(float(m.mean()), 3), sat=round(float(s), 3), Y=float(Y))


def measure(frame, boxes):
    img = Image.open(frame).convert('RGB')
    a = np.asarray(img).astype(float) / 255
    out = {}
    for name, (l, t, r, b) in boxes.items():
        out[name] = stats(a[t:b, l:r])
    ratios = {}
    for name in out:
        if name.endswith('_lit'):
            base = name[:-4]
            if base + '_shade' in out:
                ratios[base + ' shade/lit'] = round(out[base + '_shade']['Y'] / max(out[name]['Y'], 1e-6), 3)
                sh = out[base + '_shade']['rgb']
                ratios[base + ' shade blue-red'] = sh[2] - sh[0]
    if 'floor_sun' in out and 'floor_shadow' in out:
        ratios['cast shadow/sun'] = round(out['floor_shadow']['Y'] / max(out['floor_sun']['Y'], 1e-6), 3)
    return img, out, ratios


def main(frame, boxes_path, out_path):
    boxes = json.load(open(boxes_path))
    img, out, ratios = measure(frame, boxes)
    d = ImageDraw.Draw(img)
    for name, (l, t, r, b) in boxes.items():
        d.rectangle([l, t, r, b], outline=(255, 0, 255), width=4)
        d.text((l + 4, t + 4), name, fill=(255, 255, 255))
    img.save(out_path, quality=85)
    for name, s in out.items():
        print(f"{name:16s} rgb {s['rgb']}  bright {s['bright']}  sat {s['sat']}  Y {s['Y']:.3f}")
    for k, v in ratios.items():
        print(f"{k:28s} {v}")


if __name__ == '__main__':
    main(*sys.argv[1:4])
