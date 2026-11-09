"""Phase 1: refit CAM_Hub (f fixed at Roblox's 70 deg) so the projected path cross and stand tops overlap the
screenshot's orange-path and grey-stone masks. Container side (numpy, Pillow, scipy).
usage: fit_hub_masks.py [layout overrides as json]  -> prints the camera and IoUs, writes compare/hub_fit.jpg"""
import sys, json, math, numpy as np
from PIL import Image, ImageDraw
from scipy.optimize import minimize
W, H = 1507, 858; F = (H / 2) / math.tan(math.radians(35))
A = np.asarray(Image.open("refs/hub.png").convert("RGB").resize((W, H))).astype(float)
r, g, b = A[..., 0], A[..., 1], A[..., 2]; mx = A.max(-1) + 1
PATH = (r > 170) & (g / mx > 0.5) & (g / mx < 0.72) & (b / mx < 0.35)
GREY = (abs(r - g) < 22) & (abs(g - b) < 26) & (r > 110) & (r < 235)
ROI = np.zeros((H, W), bool); ROI[120:720, 240:1230] = True            # stands + cross, inside the HUD
ROI[640:, 380:1100] = False                                            # level bar and buttons
PATH &= ROI; GREY &= ROI
L = dict(TA=(-114, -34, -56, 60, 1.0), TB=(27, 73, -52, 50, 1.2), PY0=-79, PY1=76, CX0=-34, CX1=27, HW=5)
if len(sys.argv) > 1: L.update(json.loads(sys.argv[1]))

def rot(e):
    x, y, z = [math.radians(v) for v in e]
    Rx = np.array([[1, 0, 0], [0, math.cos(x), -math.sin(x)], [0, math.sin(x), math.cos(x)]])
    Ry = np.array([[math.cos(y), 0, math.sin(y)], [0, 1, 0], [-math.sin(y), 0, math.cos(y)]])
    Rz = np.array([[math.cos(z), -math.sin(z), 0], [math.sin(z), math.cos(z), 0], [0, 0, 1]])
    return Rz @ Ry @ Rx
def proj(q, P):
    C, R = np.array(q[:3]), rot(q[3:6]); Xc = (np.asarray(P, float) - C) @ R
    return np.c_[W / 2 + F * Xc[:, 0] / -Xc[:, 2], H / 2 - F * Xc[:, 1] / -Xc[:, 2]]
def rect(x0, x1, y0, y1, z): return [(x0, y0, z), (x1, y0, z), (x1, y1, z), (x0, y1, z)]
def raster(q, polys):
    im = Image.new("1", (W, H)); d = ImageDraw.Draw(im)
    for p in polys: d.polygon([tuple(v) for v in proj(q, p)], fill=1)
    return np.asarray(im)
def polys(L):
    hw = L["HW"]; ta, tb = L["TA"], L["TB"]
    path = [rect(-hw, hw, L["PY0"], L["PY1"], 0.14), rect(L["CX0"], L["CX1"], -hw, hw, 0.14)]
    grey = [rect(ta[0], ta[1], ta[2], ta[3], ta[4]), rect(tb[0], tb[1], tb[2], tb[3], tb[4])]
    return path, grey
def iou(m, ref): return (m & ref).sum() / max((m | ref).sum(), 1)
def score(q, L, wg=0.5):
    pp, gg = polys(L); mp = raster(q, pp) & ROI; mg = raster(q, gg) & ROI
    return iou(mp, PATH), iou(mg, GREY | (mg & ~GREY & ~PATH & dark())) if False else iou(mg, GREY)
_D = None
def dark(): return np.zeros((H, W), bool)
q0 = np.array([47.295, -88.11, 92.066, 41.9075, -3.1402, 34.4564])
if __name__ == "__main__":
    wg = float(L.get("WG", 0.5))
    f = lambda q: -(score(q, L)[0] + wg * score(q, L)[1])
    print("start", [round(v, 3) for v in score(q0, L)])
    s = minimize(f, q0, method="Nelder-Mead", options=dict(xatol=1e-3, fatol=1e-5, maxiter=3000, initial_simplex=None))
    q = s.x; print("cam", [round(v, 3) for v in q], "iou path/grey", [round(v, 3) for v in score(q, L)])
    out = (A * 0.6).astype(np.uint8); pp, gg = polys(L)
    im = Image.fromarray(out); d = ImageDraw.Draw(im)
    for p in pp: d.polygon([tuple(v) for v in proj(q, p)], outline=(0, 255, 255))
    for p in gg: d.polygon([tuple(v) for v in proj(q, p)], outline=(255, 255, 0))
    im.save("compare/hub_fit.jpg", quality=88); json.dump({"q": list(q), "L": L}, open("compare/hub_fit.json", "w"))
