"""Refit the hub_overview camera with the crossing, path edges, and lane features that must line up
(same-y pairs across the lane, same-x pairs along it). Focal length free."""
import numpy as np, json, math
from scipy.optimize import least_squares
exec(open("analysis/fit_cam.py").read().split("# init from IPPE")[0])
L = lambda cx, cy: (1650 + cx/2.1667, cy/2.1667)
same_y = [((L(385,935),0.8),(L(740,1050),0.8)), ((L(540,790),0.8),(L(800,870),0.8)), ((L(380,660),0.5),(L(860,790),0.5))]
same_x = [((L(385,935),0.8),(L(540,790),0.8)), ((L(740,1050),0.8),(L(800,870),0.8)), ((L(385,935),0.8),(L(655,680),0.8)),
          ((L(95,905),0.5),(L(380,660),0.5))]
def res2(p):
    r = res(p)
    for (a, za), (b, zb) in same_y: r.append((ground(p, a, za)[1] - ground(p, b, zb)[1]) * 2)
    for (a, za), (b, zb) in same_x: r.append((ground(p, a, za)[0] - ground(p, b, zb)[0]) * 2)
    return r
p0 = np.array(json.load(open("analysis/cam_hub_f1225.json"))["p"])
for fixf in (None, 1225.4):
    if fixf: s = least_squares(lambda q: res2(np.r_[q, fixf]), p0[:6]); p = np.r_[s.x, fixf]
    else: s = least_squares(res2, p0); p = s.x
    print("f", round(p[6]), "C", p[3:6].round(1), "rms", round(float(np.sqrt(np.mean(np.square(s.fun)))), 2), "max", round(float(np.abs(s.fun).max()), 1))
    if fixf is None: json.dump({"p": p.tolist()}, open("analysis/cam_hub_free.json", "w"))
