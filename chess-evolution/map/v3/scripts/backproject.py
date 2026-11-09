"""Back-project full-res hub screenshot pixels to a horizontal plane with the fitted hub camera.
usage: backproject.py z u,v [u,v ...]   (pixels in the 3014x1716 screenshot)"""
import sys, json, math, numpy as np
sys.argv, args = sys.argv[:1], sys.argv[1:]
exec(open("scripts/fit_hub_masks.py").read().split('q0 = ')[0])
q = json.load(open("compare/hub_fit.json"))["q"]
z = float(args[0]); C, R = np.array(q[:3]), rot(q[3:6])
for a in args[1:]:
    u, v = [float(t) / 2 for t in a.split(",")]
    d = R @ np.array([(u - W / 2) / F, -(v - H / 2) / F, -1.0]); t = (z - C[2]) / d[2]; X = C + t * d
    print(a, "->", round(X[0], 1), round(X[1], 1))
