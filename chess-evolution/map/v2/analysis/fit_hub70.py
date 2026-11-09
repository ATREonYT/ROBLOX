"""Hub camera refit at Roblox's vFOV 70 (proved by the lane close-up: free focal converges to 70.3) with the real path
width 12 (10 orange glyph studs + 1-stud brown edge each side, counted in terraceA_closeup)."""
import numpy as np, json, math, sys
from scipy.optimize import least_squares
src = open("analysis/fit_cam.py").read().split("# init from IPPE")[0].replace("5.5", "6.0")
exec(src)
exec(open("analysis/fit_cam2.py").read().split("p0 = ")[0].split("exec(open")[0])
L = lambda cx, cy: (1650 + cx/2.1667, cy/2.1667)
same_y = [((L(385,935),0.8),(L(740,1050),0.8)), ((L(540,790),0.8),(L(800,870),0.8)), ((L(380,660),0.5),(L(860,790),0.5))]
same_x = [((L(385,935),0.8),(L(540,790),0.8)), ((L(740,1050),0.8),(L(800,870),0.8)), ((L(385,935),0.8),(L(655,680),0.8)),
          ((L(95,905),0.5),(L(380,660),0.5))]
def res2(p):
    r = res(p)
    for (a, za), (b, zb) in same_y: r.append((ground(p, a, za)[1] - ground(p, b, zb)[1]) * 2)
    for (a, za), (b, zb) in same_x: r.append((ground(p, a, za)[0] - ground(p, b, zb)[0]) * 2)
    return r
F70 = (Hh/2) / math.tan(math.radians(35))
p0 = np.array(json.load(open("analysis/cam_hub_free.json"))["p"]); p0[3:6] *= 1.3
s = least_squares(lambda q: res2(np.r_[q, F70]), p0[:6]); p = np.r_[s.x, F70]
print("C", p[3:6].round(2), "rms", round(float(np.sqrt(np.mean(np.square(s.fun)))), 2), "max", round(float(np.abs(s.fun).max()), 1))
json.dump({"p": p.tolist(), "W": W, "H": Hh}, open("analysis/cam_hub70.json", "w"))
