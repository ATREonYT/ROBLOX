"""Solve the hub_overview camera (Roblox vertical FOV 70) from the path crossing (11 x 11 studs, z = 0.15)."""
import numpy as np, cv2, json, math
W, Hh = 3014, 1716
f = (Hh / 2) / math.tan(math.radians(35))
K = np.array([[f, 0, W/2], [0, f, Hh/2], [0, 0, 1]], float)
obj = np.array([(-5.5, 5.5, 0), (5.5, 5.5, 0), (5.5, -5.5, 0), (-5.5, -5.5, 0)], float)
img = np.array([(1540, 696), (1632, 746), (1580, 800), (1489, 750)], float)
ok, rvec, tvec = cv2.solvePnP(obj, img, K, None, flags=cv2.SOLVEPNP_IPPE)
R, _ = cv2.Rodrigues(rvec); C = (-R.T @ tvec).ravel()
print("camera pos (world studs):", C.round(2))
fwd = R.T @ np.array([0, 0, 1.0]); print("forward:", fwd.round(3), "pitch deg", round(math.degrees(math.asin(-fwd[2])), 1))
rep, _ = cv2.projectPoints(obj, rvec, tvec, K, None); print("reproj err px", np.abs(rep.reshape(-1, 2) - img).max().round(2))
json.dump({"K": K.tolist(), "rvec": rvec.ravel().tolist(), "tvec": tvec.ravel().tolist(), "C": C.tolist(), "fwd": fwd.tolist()}, open("analysis/cam_hub.json", "w"))
