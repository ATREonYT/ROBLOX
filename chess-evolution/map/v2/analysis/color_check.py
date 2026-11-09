"""Alex's colour targets (sheet pixel boxes -> target sRGB). Samples the reference and the render at the same place
(median of the box) and prints the error. usage: color_check.py <render_dir> <tag>"""
import sys, os, numpy as np
from PIL import Image
sys.path.insert(0, "analysis"); from sheet_anchors import to_full, CROPS, FULLW
VIEWCAM = {"hub": ("Hub", None, (1507, 858)), "tread": ("Treadmill", None, (1512, 867)), "phone": ("Phone", (287, 73, 1299, 471), None),
           "lane": ("Lane", None, (1508, 871))}
T = [("tread approach", "tread", (298, 577, 311, 590), "F1840E"), ("tread paving", "tread", (328, 528, 342, 539), "ACBDBE"),
     ("phone apron", "phone", (131, 896, 145, 904), "B4C3C6"), ("phone rear dirt", "phone", (118, 767, 131, 779), "AB441C"),
     ("lane left face", "lane", (134, 1194, 151, 1211), "D85529"), ("lane right grass", "lane", (456, 1194, 466, 1205), "5FFC0E"),
     ("lane floor", "lane", (273, 1204, 289, 1210), "B1C4C2"), ("lane red pad", "lane", (315, 1174, 328, 1191), "FF1933"),
     ("lane yellow tile", "lane", (265, 1185, 273, 1191), "F4C61C"), ("hub water", "hub", (107, 276, 118, 286), "74F5FD")]
def med(im, box): return np.median(np.asarray(im.crop(tuple(map(int, box)))).reshape(-1, 3), 0)
d, tag = sys.argv[1], sys.argv[2]; rows = []
for name, v, (x0, y0, x1, y1), hexc in T:
    a, b = to_full(v, x0, y0), to_full(v, x1, y1); ref = Image.open(CROPS[v][1]).convert("RGB")
    cam, crop, _ = VIEWCAM[v]; r = Image.open(os.path.join(d, f"{tag}_CAM_{cam}.png")).convert("RGB")
    if crop: r = r.crop(crop)
    s = r.width / ref.width; box = (a[0] * s, a[1] * s, max(b[0] * s, a[0] * s + 2), max(b[1] * s, a[1] * s + 2))
    want = np.array([int(hexc[i:i+2], 16) for i in (0, 2, 4)]); got = med(r, box); refc = med(ref, (*a, *b))
    err = float(np.abs(got - want).max()); rows.append((name, want, refc, got, err))
    print(f"{name:18s} target #{hexc}  ref {'#%02X%02X%02X' % tuple(map(int, refc))}  render {'#%02X%02X%02X' % tuple(map(int, got))}  max-channel error {err:.0f}")
