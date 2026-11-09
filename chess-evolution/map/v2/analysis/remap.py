"""Remap old-model ground positions (hub cam at vFOV 81, path 11) to the new world (hub cam at vFOV 70, path 12)
through the hub screenshot: old point -> pixel under the old camera -> ground plane under the new camera."""
import numpy as np, json, cv2, math
W, Hh = 3014, 1716
def _cam(p):
    R, _ = cv2.Rodrigues(np.array(p[:3])); return R, np.array(p[3:6]), p[6]
def proj(p, X):
    R, C, f = _cam(p); Xc = R @ (np.asarray(X, float) - C); return np.array([f*Xc[0]/Xc[2] + W/2, f*Xc[1]/Xc[2] + Hh/2])
def gnd(p, uv, z):
    R, C, f = _cam(p); d = R.T @ np.array([(uv[0]-W/2)/f, (uv[1]-Hh/2)/f, 1.0]); t = (z - C[2])/d[2]; return C + t*d
OLD = json.load(open("analysis/cam_hub_free.json"))["p"]; NEW = json.load(open("analysis/cam_hub70.json"))["p"]
def remap(x, y, z=0.0, znew=None):
    uv = proj(OLD, (x, y, z)); return gnd(NEW, uv, z if znew is None else znew)[:2], uv
if __name__ == "__main__":
    pts = {"crossing": (0,0), "lane_mouth_L": (-23,74), "lane_mouth_R": (23,74), "bay1": (0,130), "bay2": (0,186), "bay3": (0,242),
           "TA_front_c": (-32,6), "TA_front_y0": (-32,-46), "TA_front_y1": (-32,58), "TA_back": (-110,6),
           "TB_front_c": (25,0), "TB_y0": (25,-41), "TB_y1": (25,42), "TB_back": (63,0),
           "hub_XL": (-111,0), "hub_XR": (66,0), "path_end": (0,-70), "water_a": (-21.5,-71), "water_c": (-1.25,-79.25), "portal": (-15,27)}
    for k, (x, y) in pts.items():
        n, uv = remap(x, y); print(f"{k:14s} old ({x:7.2f},{y:7.2f}) -> new ({n[0]:7.2f},{n[1]:7.2f})  px {uv.round(0)}")
