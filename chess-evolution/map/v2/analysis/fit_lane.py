import numpy as np, math, json, sys
from scipy.optimize import least_squares
sys.path.insert(0, "analysis"); from closecam import *
W, H = 3016, 1742; f = (H/2)/math.tan(math.radians(35))
HW = float(sys.argv[1]) if len(sys.argv) > 1 else 24.0
L = [(1414,720),(1387,760),(1362,800),(1340,840),(1282,920),(1256,960),(1230,1000),(1205,1040),(1177,1080)]
Rr = [(1746,720),(1748,760),(1750,800),(1749,840),(1758,920),(1756,960),(1755,1000),(1759,1040),(1759,1080),(1762,1120)]
D = [[(1450,1133.5),(1600,1148.5),(1700,1159.5)], [(1450,859),(1600,870.5),(1700,877)], [(1450,713),(1600,721),(1700,726)]]
def res(q):
    p, P = q[:5], q[5]; r = []
    r += list(line_res(p, L, (-HW, -100, 0), (-HW, 400, 0), f, W, H))
    r += list(line_res(p, Rr, (HW, -100, 0), (HW, 400, 0), f, W, H))
    for k, pts in enumerate(D):
        y = k * P; r += list(line_res(p, pts, (-60, y, 0), (60, y, 0), f, W, H))
    return np.array(r)
s = least_squares(res, [15, -40, 30, 95, 35, 56])
q = s.x; print("p", np.round(q[:5], 3), "pitch P", round(q[5], 2), "rms", round(float(np.sqrt(np.mean(s.fun**2))), 2))
p = q[:5]
# floor stud period check at row 1080: width px vs width studs
a = on_plane(p, 1177, 1080, 2, 0, f, W, H); b = on_plane(p, 1759, 1080, 2, 0, f, W, H); print("row1080 world", np.round(a,2), np.round(b,2))
for name, uv in {"pad_c1":(1464,909),"pad_c2":(1711,930),"pad_c3":(1711,1079),"pad_c4":(1413,1048),"div_L":(1166,1100),"div_R":(1762,1156),
                 "gate4_base":(1613,627),"pad_mid":(1608,791),"pad_far":(1639,673)}.items():
    print(name, np.round(on_plane(p, *uv, 2, 0.0, f, W, H)[:2], 2))
json.dump({"p": list(p), "P": q[5], "f": f, "W": W, "H": H}, open("analysis/cam_lane.json", "w"))
