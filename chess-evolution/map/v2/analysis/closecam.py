"""Close-up camera model: Roblox camera, fixed vertical FOV, roll 0 (yaw about z, pitch down). World: x,y ground, z up.
Params p = (cx, cy, cz, yaw_deg, pitch_deg). yaw = heading of the view direction measured from +x toward +y."""
import numpy as np, math
def basis(yaw, pitch):
    a, b = math.radians(yaw), math.radians(pitch)
    fwd = np.array([math.cos(b)*math.cos(a), math.cos(b)*math.sin(a), -math.sin(b)])
    right = np.array([math.sin(a), -math.cos(a), 0.0])        # fwd x up
    up = np.cross(right, fwd)
    return fwd, right, up
def project(p, X, f, W, H, ppx=0.0, ppy=0.0):
    C = np.array(p[:3]); fwd, right, up = basis(p[3], p[4])
    X = np.atleast_2d(np.asarray(X, float)) - C
    xc, yc, zc = X @ right, X @ up, X @ fwd
    return np.c_[W/2 + ppx + f*xc/zc, H/2 + ppy - f*yc/zc]
def ray(p, u, v, f, W, H, ppx=0.0, ppy=0.0):
    fwd, right, up = basis(p[3], p[4])
    d = fwd + right*(u - W/2 - ppx)/f - up*(v - H/2 - ppy)/f
    return np.array(p[:3]), d
def on_plane(p, u, v, axis, value, f, W, H, ppx=0.0, ppy=0.0):
    C, d = ray(p, u, v, f, W, H, ppx, ppy); t = (value - C[axis])/d[axis]; return C + t*d
def line_res(p, pts, A, B, f, W, H, ppx=0.0, ppy=0.0):
    """Pixel distance of observed pts to the projection of world line A-B."""
    a, b = project(p, [A, B], f, W, H, ppx, ppy); n = np.array([-(b-a)[1], (b-a)[0]]); n /= np.linalg.norm(n)
    return (np.asarray(pts, float) - a) @ n
def blender_rot(p):
    """Euler XYZ for a Blender camera (looks down its -Z, +Y up)."""
    fwd, right, up = basis(p[3], p[4]); R = np.c_[right, up, -fwd]
    import math as m
    sy = -R[2, 0]; ry = m.asin(max(-1, min(1, sy)))
    rx = m.atan2(R[2, 1], R[2, 2]); rz = m.atan2(R[1, 0], R[0, 0]); return (rx, ry, rz)
