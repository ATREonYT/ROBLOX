import numpy as np, math, json, sys
from scipy.optimize import least_squares
sys.path.insert(0, "analysis"); from closecam import *
W, H = 2024, 796; f = (1734/2)/math.tan(math.radians(35))
PPX, PPY = (1512 - 574) - W/2, (867 - 146) - H/2          # crop of a 3024x1734 frame at (574,146), found by matching the HUD
XF = float(sys.argv[1]) if len(sys.argv) > 1 else 27.0; zp = 0.17
Lo = [(832,645),(829,660),(823,690),(815,735),(812,750),(807,780),(804,795)]
Ro = [(1126,645),(1129,660),(1133,690),(1141,735),(1144,750),(1149,780),(1151,795)]
Li = [(856,645),(854,660),(849,690),(842,735),(840,750),(835,780),(833,795)]
Ri = [(1106,645),(1109,660),(1113,690),(1120,735),(1122,750),(1126,780),(1128,795)]
FR = [(300,627),(500,630),(700,633),(1300,643),(1500,647),(1700,650),(1900,653)]
def res(p):
    r = []
    for pts, yy in ((Lo, 6), (Ro, -6), (Li, 5), (Ri, -5)):
        r += list(line_res(p, pts, (XF - 60, yy, zp), (XF + 60, yy, zp), f, W, H, PPX, PPY))
    r += list(line_res(p, FR, (XF, -60, 0), (XF, 60, 0), f, W, H, PPX, PPY))
    return np.array(r)
s = least_squares(res, [-10, 0, 20, 0, 25]); p = s.x
print("p", np.round(p, 3), "rms", round(float(np.sqrt(np.mean(s.fun**2))), 2))
json.dump({"p": list(p), "f": f, "W": W, "H": H, "ppx": PPX, "ppy": PPY}, open("analysis/cam_phone.json", "w"))
