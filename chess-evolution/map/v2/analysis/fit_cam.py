"""Fit the hub_overview camera: crossing corners (11x11 studs) + points on the path edges (x or y = +-5.5).
Unknowns: rotation, position, focal length. Ground z = 0.15 (path top)."""
import numpy as np, cv2, math, json
from scipy.optimize import least_squares
W, Hh = 3014, 1716; Z = 0.15
corners_w = np.array([(-5.5, 5.5), (5.5, 5.5), (5.5, -5.5), (-5.5, -5.5)])
corners_p = np.array([(1540, 696), (1632, 746), (1580, 800), (1489, 750)], float)
lines = [  # (pixel, axis, value)
    ((1641.5, 590), 0, -5.5), ((1780, 590), 0, 5.5), ((1790, 459), 0, -5.5), ((1877, 490), 0, 5.5),
    ((1449, 778.5), 0, -5.5), ((1038.5, 1166), 0, -5.5), ((1486, 898.5), 0, 5.5), ((1158.5, 1249), 0, 5.5),
    ((1365, 610), 1, 5.5), ((1535, 692.5), 1, 5.5), ((1310, 655), 1, -5.5), ((1480, 747.5), 1, -5.5),
    ((1640, 745), 1, 5.5), ((1805, 835), 1, 5.5), ((1580, 805), 1, -5.5), ((1765, 900), 1, -5.5)]
def cam(p):
    rv, C, f = p[:3], p[3:6], p[6]
    R, _ = cv2.Rodrigues(rv); return R, C, f
def project(p, X):
    R, C, f = cam(p); Xc = (R @ (np.asarray(X, float) - C).T).T
    return np.c_[f * Xc[:, 0] / Xc[:, 2] + W/2, f * Xc[:, 1] / Xc[:, 2] + Hh/2]
def ground(p, uv, z=Z):
    R, C, f = cam(p); d = R.T @ np.array([(uv[0] - W/2) / f, (uv[1] - Hh/2) / f, 1.0])
    t = (z - C[2]) / d[2]; return C + t * d
def res(p):
    r = list((project(p, np.c_[corners_w, np.full(4, Z)]) - corners_p).ravel())
    for uv, ax, v in lines: r.append((ground(p, uv)[ax] - v) * 4)   # studs -> roughly px weight
    return r
# init from IPPE solution
f0 = (Hh/2) / math.tan(math.radians(35)); K = np.array([[f0, 0, W/2], [0, f0, Hh/2], [0, 0, 1]])
n, rv, tv, _ = cv2.solvePnPGeneric(np.c_[corners_w, np.zeros(4)], corners_p, K, None, flags=cv2.SOLVEPNP_IPPE)
best = None
for r, t in zip(rv, tv):
    R, _ = cv2.Rodrigues(r); C = (-R.T @ t).ravel()
    if C[1] < 0:
        best = np.r_[r.ravel(), C, f0]
sol = least_squares(res, best)
p = sol.x; R, C, f = cam(p)
print("C", C.round(2), "f", round(f, 1), "vfov", round(2*math.degrees(math.atan(Hh/2/f)), 1), "rms", round(float(np.sqrt(np.mean(np.square(sol.fun)))), 2))
print("front path end y:", ground(p, (1790, 459))[1].round(1), ground(p, (1877, 490))[1].round(1))
json.dump({"p": p.tolist(), "W": W, "H": Hh}, open("analysis/cam_hub.json", "w"))
