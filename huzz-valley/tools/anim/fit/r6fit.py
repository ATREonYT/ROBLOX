"""
Fits an R6 body to a dance video, frame by frame (owner, Oct 22 15:30: "make it one to one, use the references, and
perfectly recreate them"). Analysis by synthesis: the six R6 blocks (Roblox's real R6 joint frames, as
tools/preview/motion3d/rig.luau), plus a few worn things that tell front from back (a shirt on the front, a backpack,
shoes, a hat), are drawn from a camera with a z-buffer into a small label picture, and each frame's 21 numbers (the
RootJoint's move and turn, then Neck, shoulders and hips) are searched so the drawing matches the video's colours,
starting from the frame before. numpy only.

The result is each joint's Motor6D.Transform per frame (what an Animator writes), saved as JSON for
tools/anim/build_video_dances.luau to turn into a looping KeyframeSequence.
"""
import json, math, sys
import numpy as np

# ---- CFrames as 4x4 matrices -------------------------------------------------------------------------------------
def cf(x, y, z, *r):
    m = np.eye(4)
    m[:3, 3] = (x, y, z)
    if r:
        m[:3, :3] = np.array(r, float).reshape(3, 3)
    return m

def rx(a):
    c, s = math.cos(a), math.sin(a); m = np.eye(4); m[1, 1] = c; m[1, 2] = -s; m[2, 1] = s; m[2, 2] = c; return m
def ry(a):
    c, s = math.cos(a), math.sin(a); m = np.eye(4); m[0, 0] = c; m[0, 2] = s; m[2, 0] = -s; m[2, 2] = c; return m
def rz(a):
    c, s = math.cos(a), math.sin(a); m = np.eye(4); m[0, 0] = c; m[0, 1] = -s; m[1, 0] = s; m[1, 1] = c; return m
def angles(a, b, c):  # CFrame.Angles(a, b, c) = Rx * Ry * Rz
    return rx(a) @ ry(b) @ rz(c)
def inv(m):
    r = np.eye(4); r[:3, :3] = m[:3, :3].T; r[:3, 3] = -m[:3, :3].T @ m[:3, 3]; return r

# Roblox's R6 joints (rig.luau): name -> (Part0, Part1, C0, C1)
JOINTS = {
    "RootJoint": ("HumanoidRootPart", "Torso", cf(0, 0, 0, -1, 0, 0, 0, 0, 1, 0, 1, 0), cf(0, 0, 0, -1, 0, 0, 0, 0, 1, 0, 1, 0)),
    "Neck": ("Torso", "Head", cf(0, 1, 0, -1, 0, 0, 0, 0, 1, 0, 1, 0), cf(0, -0.5, 0, -1, 0, 0, 0, 0, 1, 0, 1, 0)),
    "Right Shoulder": ("Torso", "Right Arm", cf(1, 0.5, 0, 0, 0, 1, 0, 1, 0, -1, 0, 0), cf(-0.5, 0.5, 0, 0, 0, 1, 0, 1, 0, -1, 0, 0)),
    "Left Shoulder": ("Torso", "Left Arm", cf(-1, 0.5, 0, 0, 0, -1, 0, 1, 0, 1, 0, 0), cf(0.5, 0.5, 0, 0, 0, -1, 0, 1, 0, 1, 0, 0)),
    "Right Hip": ("Torso", "Right Leg", cf(1, -1, 0, 0, 0, 1, 0, 1, 0, -1, 0, 0), cf(0.5, 1, 0, 0, 0, 1, 0, 1, 0, -1, 0, 0)),
    "Left Hip": ("Torso", "Left Leg", cf(-1, -1, 0, 0, 0, -1, 0, 1, 0, 1, 0, 0), cf(-0.5, 1, 0, 0, 0, -1, 0, 1, 0, 1, 0, 0)),
}
LIMBS = ["Neck", "Right Shoulder", "Left Shoulder", "Right Hip", "Left Hip"]
SIZES = {"Torso": (2, 2, 1), "Head": (1.2, 1.2, 1.2), "Right Arm": (1, 2, 1), "Left Arm": (1, 2, 1),
         "Right Leg": (1, 2, 1), "Left Leg": (1, 2, 1)}

# labels drawn / seen: 0 nothing, 1 skin/body, 2 shoe, 3 backpack, 4 shirt front, 5 other (hat, hair, prints)
NL = 6

def transforms(x):
    """x (21) -> {joint: Transform 4x4}. Root: move, then turn about up (joint z), then lean."""
    t = {"RootJoint": cf(x[0], x[1], x[2]) @ rz(x[3]) @ ry(x[4]) @ rx(x[5])}
    for i, j in enumerate(LIMBS):
        a, b, c = x[6 + 3 * i: 9 + 3 * i]
        t[j] = angles(a, b, c)
    return t

def solve(x, root=None):
    root = cf(0, 3, 0) if root is None else root
    world = {"HumanoidRootPart": root}
    T = transforms(x)
    for j in ["RootJoint"] + LIMBS:
        p0, p1, c0, c1 = JOINTS[j]
        world[p1] = world[p0] @ c0 @ T[j] @ inv(c1)
    return world

class Body:
    """The blocks to draw: (part, offset, size, label per face [+x,-x,+y,-y,+z,-z] or one label)."""
    def __init__(self, extras):
        self.boxes = []
        for p, s in SIZES.items():
            self.boxes.append((p, np.eye(4), s, extras.get(p + ".labels", 1)))
        for e in extras.get("boxes", []):
            self.boxes.append((e["part"], cf(*e["at"]), e["size"], e["label"]))

FACES = [  # (axis, sign) -> 4 corner sign patterns
    (0, 1), (0, -1), (1, 1), (1, -1), (2, 1), (2, -1)]

def corners(sign_axis, sign, half):
    a = sign_axis
    o = [i for i in range(3) if i != a]
    pts = []
    for s1, s2 in ((-1, -1), (1, -1), (1, 1), (-1, 1)):
        p = [0.0, 0.0, 0.0]
        p[a] = sign * half[a]; p[o[0]] = s1 * half[o[0]]; p[o[1]] = s2 * half[o[1]]
        pts.append(p)
    return np.array(pts)

class Camera:
    def __init__(self, W, H, f, cx, cy, pitch, dist, target=(0, 3, 0), yaw=0.0):
        self.W, self.H, self.f, self.cx, self.cy = W, H, f, cx, cy
        fwd = np.array([math.sin(yaw) * math.cos(pitch), -math.sin(pitch), math.cos(yaw) * math.cos(pitch)])
        self.pos = np.array(target, float) - dist * fwd
        right = np.cross(fwd, [0, 1, 0]); right /= np.linalg.norm(right)
        up = np.cross(right, fwd)
        self.R = np.stack([right, up, fwd])
        ys, xs = np.mgrid[0:H, 0:W]
        self.px = xs + 0.5; self.py = ys + 0.5

    def project(self, P):
        c = (P - self.pos) @ self.R.T
        z = np.maximum(c[:, 2], 1e-3)
        return np.stack([self.cx + self.f * c[:, 0] / z, self.cy - self.f * c[:, 1] / z], 1), z

def render(body, world, cam):
    lab = np.zeros((cam.H, cam.W), np.int8)
    zb = np.full((cam.H, cam.W), np.inf)
    for part, off, size, labels in body.boxes:
        m = world[part] @ off
        half = np.array(size, float) / 2
        for fi, (a, s) in enumerate(FACES):
            n = m[:3, :3][:, a] * s
            ctr = m[:3, 3] + n * half[a]
            if np.dot(n, cam.pos - ctr) <= 0:
                continue
            P = (m[:3, :3] @ corners(a, s, half).T).T + m[:3, 3]
            uv, z = cam.project(P)
            x0 = max(int(uv[:, 0].min()), 0); x1 = min(int(uv[:, 0].max()) + 1, cam.W)
            y0 = max(int(uv[:, 1].min()), 0); y1 = min(int(uv[:, 1].max()) + 1, cam.H)
            if x0 >= x1 or y0 >= y1:
                continue
            X = cam.px[y0:y1, x0:x1]; Y = cam.py[y0:y1, x0:x1]
            inside = None
            area = 0.0
            for k in range(4):
                (ax, ay), (bx, by) = uv[k], uv[(k + 1) % 4]
                area += ax * by - bx * ay
            for k in range(4):
                (ax, ay), (bx, by) = uv[k], uv[(k + 1) % 4]
                e = (bx - ax) * (Y - ay) - (by - ay) * (X - ax)
                e = e * np.sign(area)
                inside = e >= 0 if inside is None else inside & (e >= 0)
            if not inside.any():
                continue
            # 1/z is affine on the screen: fit it on three corners
            A = np.array([[uv[0, 0], uv[0, 1], 1], [uv[1, 0], uv[1, 1], 1], [uv[2, 0], uv[2, 1], 1]])
            try:
                co = np.linalg.solve(A, 1 / z[:3])
            except np.linalg.LinAlgError:
                continue
            iz = co[0] * X + co[1] * Y + co[2]
            depth = 1 / np.maximum(iz, 1e-6)
            sub = zb[y0:y1, x0:x1]
            win = inside & (depth < sub)
            sub[win] = depth[win]
            L = labels if isinstance(labels, int) else labels[fi]
            lab[y0:y1, x0:x1][win] = L
    return lab

# cost[rendered][seen]
COST = np.array([
    [0, 1, 1, 1, 1, 1],
    [1, 0, .6, .6, .6, .3],
    [1, .5, 0, .6, .6, .1],
    [1, .6, .6, 0, .6, .3],
    [1, .5, .6, .6, 0, .1],
    [1, .4, .2, .6, .5, 0],
])

def score(lab, seen):
    return COST[lab, seen].sum()

GROUPS = [(0, 3, 0.15), (3, 6, 0.12)] + [(6 + 3 * i, 9 + 3 * i, 0.2) for i in range(5)]

def fit(seen, body, cam, x0, iters, rng, prior=None, lam=0.0, twist=0.0, sig=None):
    def total(x):
        c = score(render(body, solve(x), cam), seen)
        if prior is not None:
            c += lam * float(np.sum((x - prior) ** 2))
        if twist:  # (a limb's turn about its own length hardly shows on a square block: keep it small)
            c += twist * sum(x[7 + 3 * i] ** 2 for i in range(1, 5))
        return c
    x = np.array(x0, float); best = total(x)
    sig = list(sig) if sig else [g[2] for g in GROUPS]
    for _ in range(iters):
        gi = rng.integers(len(GROUPS)) if rng.random() < 0.85 else -1
        y = x.copy()
        if gi < 0:
            y += rng.normal(0, 0.03, len(x))
        else:
            a, b, _s = GROUPS[gi]
            if rng.random() < 0.5:
                y[rng.integers(a, b)] += rng.normal(0, sig[gi])
            else:
                y[a:b] += rng.normal(0, sig[gi], b - a)
        c = total(y)
        if c < best:
            x, best = y, c
            if gi >= 0: sig[gi] = min(sig[gi] * 1.3, 0.8)
        elif gi >= 0:
            sig[gi] = max(sig[gi] * 0.97, 0.01)
    return x, best, sig
