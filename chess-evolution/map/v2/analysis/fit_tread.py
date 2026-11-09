import numpy as np, math, json, sys
from scipy.optimize import least_squares
sys.path.insert(0, "analysis"); from closecam import *
W, H = 3024, 1734; f = (H/2)/math.tan(math.radians(35))
XF = float(sys.argv[1]) if len(sys.argv) > 1 else -35.0
zp = 0.17
L6 = [(1315,950),(1306,1000),(1296,1050),(1286,1100),(1276,1150),(1266,1200),(1256,1250),(1246,1300)]
R6 = [(1656,950),(1669,1000),(1684,1050),(1697,1100),(1712,1150),(1726,1200),(1740,1250),(1754,1300)]
L5 = [(1341,950),(1333,1000),(1325,1050),(1317,1100),(1309,1150),(1301,1200),(1293,1250),(1284,1300)]
R5 = [(1636,950),(1648,1000),(1661,1050),(1673,1100),(1686,1150),(1699,1200),(1711,1250),(1724,1300)]
FR = [(700,979),(800,977),(900,974),(1000,972),(1100,972),(1200,968),(1800,957),(1900,953),(2200,946),(2300,945),(2400,943)]
def res(p):
    r = []
    for pts, yy in ((L6,-6),(R6,6),(L5,-5),(R5,5)):
        r += list(line_res(p, pts, (XF-60, yy, zp), (XF+60, yy, zp), f, W, H))
    r += list(line_res(p, FR, (XF, -60, 0), (XF, 60, 0), f, W, H))
    return np.array(r)
p0 = [0, 0, 14, 180, 27]
s = least_squares(res, p0)
p = s.x; print("p", np.round(p, 3), "rms", round(float(np.sqrt(np.mean(s.fun**2))), 2), "f", round(f, 1))
# stud rows along the path: predicted image rows for x = XF+k (k studs toward the camera) at y=0
for k in range(0, 14, 2):
    print(k, np.round(project(p, [(XF + k, 0, zp)], f, W, H)[0], 1))
json.dump({"p": list(p), "f": f, "W": W, "H": H}, open("analysis/cam_tread.json", "w"))
