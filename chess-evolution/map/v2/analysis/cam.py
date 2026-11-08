"""Hub overview camera (Roblox vFOV 70, fitted to the path crossing and path edges). Helpers: project, ground."""
import numpy as np, cv2, json, math
W, Hh = 3014, 1716
P = np.array(json.load(open("analysis/cam_hub_free.json"))["p"])
def _cam():
    R, _ = cv2.Rodrigues(P[:3]); return R, P[3:6], P[6]
def project(X):
    R, C, f = _cam(); X = np.atleast_2d(np.asarray(X, float)); Xc = (R @ (X - C).T).T
    return np.c_[f*Xc[:, 0]/Xc[:, 2] + W/2, f*Xc[:, 1]/Xc[:, 2] + Hh/2]
def ground(u, v, z=0.0):
    R, C, f = _cam(); d = R.T @ np.array([(u - W/2)/f, (v - Hh/2)/f, 1.0]); t = (z - C[2])/d[2]; return C + t*d
def ray(u, v):
    R, C, f = _cam(); return C, R.T @ np.array([(u - W/2)/f, (v - Hh/2)/f, 1.0])
def on_plane(u, v, axis, value):
    C, d = ray(u, v); t = (value - C[axis])/d[axis]; return C + t*d
