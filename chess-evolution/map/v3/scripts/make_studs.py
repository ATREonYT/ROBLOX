"""Stud textures for the v3 map, measured from the screenshots (container side, numpy + Pillow).
Each tile is 8 x 8 studs at 64 px per stud (512 px), the same tiling as the texture pack (planar UVs, 1 tile = 8 studs).
  baseplate : hub grass in terraceA_closeup: a thin groove grid at every stud, one raised square stud in each cell
  inout     : tree leaves and trunks (lane_view, terraceA_closeup pines): studs alternate raised / sunken in a checker
  inlet     : the orange path (terraceA_closeup under the HUD): groove grid with a sunken square in each cell
Writes <name>_shade.png (only the occlusion that light can't explain: sunken floors and grooves darker; x1.5 in the
shader) and <name>_normal.png (OpenGL tangent normal). The bevel light and shadow come from the scene's sun through the
normal map, so each view gets the same direction as its screenshot (terraceA_closeup looks toward the sun: dark tops)."""
import numpy as np, sys
from PIL import Image
P, N = 64, 8; S = P * N
def cell_masks():
    y, x = np.mgrid[0:S, 0:S] + 0.5
    cx, cy = x % P, y % P; ix, iy = (x // P).astype(int), (y // P).astype(int)
    return cx, cy, ix, iy
def square(cx, cy, half, ramp):
    d = np.maximum(np.abs(cx - P / 2), np.abs(cy - P / 2))          # square distance from the cell centre
    return np.clip((half - d) / ramp + 0.5, 0, 1)
def groove(cx, cy, w):
    e = np.minimum(np.minimum(cx, P - cx), np.minimum(cy, P - cy))
    return np.clip((w - e) / 1.0 + 0.5, 0, 1)
def heights(kind):
    cx, cy, ix, iy = cell_masks()
    if kind == "baseplate":
        return 1.0 * square(cx, cy, 15, 3.0) - 0.45 * groove(cx, cy, 1.5)
    if kind == "inlet":
        return -1.0 * square(cx, cy, 15, 3.0) - 0.45 * groove(cx, cy, 1.5)
    if kind == "inout":
        sgn = np.where((ix + iy) % 2 == 0, 1.0, -1.0)
        return sgn * square(cx, cy, 16, 3.0)
def bake(kind):
    h = heights(kind) * 6.0                                          # px of relief, sets the bevel steepness
    gy, gx = np.gradient(h)                                          # image rows run downward
    n = np.dstack([-gx, gy, np.ones_like(h)]); n /= np.linalg.norm(n, axis=2, keepdims=True)
    L = np.array([-0.55, 0.55, 0.63]); L /= np.linalg.norm(L)        # light from the top-left (texture up = +v)
    flat = L[2]
    lit = (n @ L) / flat                                             # 1.0 on flat faces
    sunk = np.clip(-heights(kind), 0, 1)                             # inside sunken studs and grooves: a bit darker
    # v06d: baseplate rim 0.30->0.40 and tops 0.06->0.16 (grass studs read too faint next to the screenshots)
    # v06c: the screenshots' studs read as crisp outlined squares even far away (Roblox bakes them into the decal),
    # so a direction-free dark rim on every bevel plus lighter raised tops and darker sunken floors is baked in
    raw = heights(kind); rim = np.clip(np.hypot(*np.gradient(raw)) * 2.5, 0, 1)
    up = np.clip(raw, 0, 1) * (raw > 0.95); down = np.clip(-raw, 0, 1) * (raw < -0.95)
    k = {"baseplate": (0.40, 0.16, 0.20), "inout": (0.30, 0.14, 0.34), "inlet": (0.30, 0.0, 0.06)}[kind]
    shade = np.clip(1.0 - k[0] * rim + k[1] * up - k[2] * down - 0.12 * sunk * (kind == "baseplate"), 0.35, 1.45)
    Image.fromarray((shade / 1.5 * 255).round().astype(np.uint8)).save(f"textures/{kind}_shade.png")
    nm = ((n * 0.5 + 0.5) * 255).round().astype(np.uint8)
    Image.fromarray(nm).save(f"textures/{kind}_normal.png")
    print(kind, "shade range", round(float(shade.min()), 2), round(float(shade.max()), 2))
for k in ("baseplate", "inout", "inlet"): bake(k)
