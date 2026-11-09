"""Back-project picked pixels through a locked close-up camera onto a horizontal plane. usage: measure.py cam.json z name:u,v ..."""
import sys, json, numpy as np
sys.path.insert(0, "analysis"); from closecam import on_plane
C = json.load(open(sys.argv[1])); z = float(sys.argv[2])
for a in sys.argv[3:]:
    n, uv = a.split(":"); u, v = map(float, uv.split(","))
    X = on_plane(C["p"], u, v, 2, z, C["f"], C["W"], C["H"], C.get("ppx", 0), C.get("ppy", 0)); print(f"{n:10s} {X[0]:8.2f} {X[1]:8.2f}")
