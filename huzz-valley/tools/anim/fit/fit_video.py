"""
Fits every frame of a reference clip (r6fit), then saves the joints per frame.
  python3 fit_video.py <config name> <frames dir> <out.json>
Config: the clip's look (seg), the worn things that show front from back, a first camera guess and a first pose.
Steps: the camera's zoom and centre from a grid (each tried with fresh fits of a few frames); then every frame from
the one before, with each limb also offered a few stock poses (straight down, forward, up, out, back) so a limb that
swings fast isn't left behind; then the same backwards, keeping whichever fits each frame better.
"""
import json, sys, time, glob, itertools
from multiprocessing import Pool
import numpy as np
from r6fit import *
import seg

PI = math.pi

def arms(rc, ra, lc, la):  # shoulders: c swings forward / back (right +c forward, left -c), a- out (both)
    x = np.zeros(21); x[9], x[11], x[12], x[14] = ra, rc, la, lc; return x

CONFIGS = {
    "balenci": dict(
        W=150, H=140, seg=seg.balenci_catalog,
        # the dancer turns all the way round to its own left, steadily, once a loop: front at frames 1 and 97, its
        # right side at 25, its back at 49, its left side at 73 (seen by the backpack and the face)
        yaw=lambda i: 2 * PI * i / 96,
        cam=dict(f=205, cx=72, cy=50, pitch=0.15, dist=12),
        grid=dict(f=[205, 220, 235], cx=[76], cy=[46, 50]),
        init=np.zeros(21),
        body={"Torso.labels": [1, 1, 1, 1, 1, 4], "boxes": [
            {"part": "Torso", "at": (0, -0.1, 0.9), "size": (1.5, 1.7, 0.8), "label": 3},
            {"part": "Head", "at": (0, 0.55, 0), "size": (1.3, 0.45, 1.3), "label": 5},
            {"part": "Right Leg", "at": (0, -0.65, -0.05), "size": (1.08, 0.75, 1.2), "label": 2},
            {"part": "Left Leg", "at": (0, -0.65, -0.05), "size": (1.08, 0.75, 1.2), "label": 2}]},
    ),
    "sweet": dict(
        W=115, H=130, seg=seg.dark_preview,
        cam=dict(f=140, cx=57, cy=55, pitch=0.0, dist=12),
        grid=dict(f=[140, 150, 160], cx=[56], cy=[60, 64], pitch=[0.0]),
        init=arms(2.8, -0.25, -2.8, -0.25),
        body={"Torso.labels": 5, "Right Leg.labels": 5, "Left Leg.labels": 5, "Head.labels": [5, 5, 5, 5, 5, 1],
              "Right Arm.labels": [5, 5, 5, 1, 5, 5], "Left Arm.labels": [5, 5, 5, 1, 5, 5], "boxes": []},
    ),
}

# stock poses per limb group (index into x: group start), as (a, b, c)
STOCK = {
    9: [(0, 0, 0), (0, 0, PI / 2), (0, 0, PI), (0, 0, 2.6), (-PI / 2, 0, 0), (0, 0, -0.8), (0.9, 0, 0.9), (-1, 0, 2.2)],
    12: [(0, 0, 0), (0, 0, -PI / 2), (0, 0, -PI), (0, 0, -2.6), (PI / 2, 0, 0), (0, 0, 0.8), (-0.9, 0, -0.9), (1, 0, -2.2)],
    15: [(0, 0, 0), (0, 0, 0.7), (0, 0, -0.5), (-0.5, 0, 0), (0, 0, 1.3)],
    18: [(0, 0, 0), (0, 0, -0.7), (0, 0, 0.5), (0.5, 0, 0), (0, 0, -1.3)],
}

G = {}

def setup(name, frames_dir):
    C = CONFIGS[name]
    files = sorted(glob.glob(frames_dir + "/*.png"))
    G.update(C=C, files=files, seen=[C["seg"](f, C["W"], C["H"])[0] for f in files], body=Body(C["body"]))

def cam_of(p):
    return Camera(G["C"]["W"], G["C"]["H"], **p)

def first(args):
    i, p, iters, seed = args
    rng = np.random.default_rng(seed)
    cam = cam_of(p); best = None
    Y = G["C"].get("yaw")
    for yaw in ([Y(i)] if Y else np.linspace(-PI, PI, 8, endpoint=False)):
        x0 = G["C"]["init"].copy(); x0[3] = yaw
        x, c, _ = fit(G["seen"][i], G["body"], cam, x0, iters, rng, twist=20, yaw=Y(i) if Y else None)
        if best is None or c < best[1]:
            best = (x, c)
    return best

def stock(x, i, cam, cost):
    for g, poses in STOCK.items():
        for pose in poses:
            y = x.copy(); y[g:g + 3] = pose
            c = score(render(G["body"], solve(y), cam), G["seen"][i])
            if c < cost:
                x, cost = y, c
    return x, cost

def track(args):
    order, p, seed, prior_xs = args
    rng = np.random.default_rng(seed)
    cam = cam_of(p)
    Y = G["C"].get("yaw")
    xs, costs = {}, {}
    x = prev = None
    for n, i in enumerate(order):
        if x is None:
            prev = None
            x = prior_xs[i] if prior_xs and i in prior_xs else first((i, p, 600, seed))[0]
            x, c, _ = fit(G["seen"][i], G["body"], cam, x, 2000, rng, twist=20, yaw=Y(i) if Y else None)
        else:
            cands = [x + 0.6 * (x - prev), x] if prev is not None else [x]
            if Y:  # (each also turned to where the clip says the body faces now)
                for c0 in list(cands):
                    c0 = c0.copy(); c0[3] = Y(i); cands.append(c0)
            if prior_xs and i in prior_xs:
                cands.append(prior_xs[i])
            best = None
            for c0 in cands:
                c0 = c0.copy()
                c0, cc = stock(c0, i, cam, score(render(G["body"], solve(c0), cam), G["seen"][i]))
                y, cc, _ = fit(G["seen"][i], G["body"], cam, c0, 500, rng, prior=x, lam=2.0, twist=20, yaw=Y(i) if Y else None)
                if best is None or cc < best[1]:
                    best = (y, cc)
            prev = x
            x, c = best
        xs[i], costs[i] = x, c
        if n % 20 == 0:
            print(f"  {'forward' if order[0] == 0 else 'backward'} frame {i} cost {c:.0f}", flush=True)
    return xs, costs

def main():
    name, frames_dir, out = sys.argv[1], sys.argv[2], sys.argv[3]
    setup(name, frames_dir)
    C, n = G["C"], len(G["files"])
    keys = [0, n // 4, n // 2, 3 * n // 4]
    with Pool(4, initializer=setup, initargs=(name, frames_dir)) as pool:
        # 1. the camera: every grid point, each with fresh fits of the key frames
        grid = C["grid"]
        best = None
        names = list(grid)
        if len(sys.argv) > 4:  # (a camera found before: python3 fit_video.py ... '{"f": 150, ...}')
            grid = {k: [v] for k, v in json.loads(sys.argv[4]).items()}
            names = list(grid)
        for vals in itertools.product(*[grid[k] for k in names]):
            p = dict(C["cam"]); p.update(dict(zip(names, vals)))
            res = pool.map(first, [(i, p, 250, 7) for i in keys])
            cost = sum(r[1] for r in res)
            if best is None or cost < best[1]:
                best = (p, cost, {i: r[0] for i, r in zip(keys, res)})
            print("camera", {k: round(v, 3) for k, v in p.items() if k in names}, "cost", round(cost), flush=True)
        p, _, keyposes = best
        print("chosen", p, flush=True)
        # 2. forward from the start and backward from the end, at once
        fwd, bwd = pool.map(track, [(list(range(n)), p, 1, keyposes), (list(range(n - 1, -1, -1)), p, 2, keyposes)])
    xs, costs = [], []
    for i in range(n):
        a, b = fwd[1][i], bwd[1][i]
        xs.append(fwd[0][i] if a <= b else bwd[0][i]); costs.append(min(a, b))
    print(f"mean cost {np.mean(costs):.0f} (forward {np.mean(list(fwd[1].values())):.0f}, backward {np.mean(list(bwd[1].values())):.0f})")
    json.dump({"camera": p, "W": C["W"], "H": C["H"], "costs": costs, "frames": [list(map(float, v)) for v in xs]}, open(out, "w"))
    print("saved", out)

if __name__ == "__main__":
    main()
