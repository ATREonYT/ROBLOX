"""Measures the calibration scene of render_light.mjs for each look: cast shadow / sun on a cream floor (like the
Oct 17 path) and on a dark slate floor (like the reference's floor), the number light_measure.py reads off the
owner's frames. The page puts an invisible roof high over each floor and reports where its shadow's middle and a
sunlit spot of the same floor land on screen (calib_<look>.json), so it works for any sun angle.
  The model's free number, K.amb (= K.env: how strong the ambient light is next to the sun), is picked so the Oct 17
  look gives the cast-shadow ratio measured on his Oct 17 recording (cream path: 0.25).
Usage: python3 -I calibrate.py <render dir> <looks.json>   (renders named calib_<look>.png / .json)
"""
import json
import os
import sys
import numpy as np
from PIL import Image


def lin(c):
    return np.where(c <= 0.04045, c / 12.92, ((c + 0.055) / 1.055) ** 2.4)


def Y(a, xy, r=6):
    x, y = xy
    L = lin(a[y - r:y + r, x - r:x + r].reshape(-1, 3))
    return float((0.2126 * L[:, 0] + 0.7152 * L[:, 1] + 0.0722 * L[:, 2]).mean())


def measure(path):
    a = np.asarray(Image.open(path).convert('RGB')).astype(float) / 255
    pr = json.load(open(path[:-4] + '.json'))
    out = {}
    for k in ('cream', 'slate'):
        out[k + ' cast'] = Y(a, pr[k + '_shadow']) / Y(a, pr[k + '_sun'])
        x, y = pr[k + '_sun']
        out[k + ' sun bright'] = float(a[y - 6:y + 6, x - 6:x + 6].mean())
    return out


if __name__ == '__main__':
    rdir, looks = sys.argv[1], json.load(open(sys.argv[2]))
    for name in looks:
        p = os.path.join(rdir, 'calib_' + name + '.png')
        if os.path.exists(p):
            print(f"{name:16s} " + '  '.join(f"{k} {v:.3f}" for k, v in measure(p).items()))
