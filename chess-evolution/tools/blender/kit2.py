# +1 Chess Evolution: chess-style treadmills v2 (Alex, Nov 7: "make the treadmills better, use blender, make it chess style").
# Same anchors, sizes and axes as kit.py v1 (Blender +Y = Roblox -Z = console end, Blender Z = Roblox Y, 1 unit = 1 stud).
# What makes them chess:
#   * the side rails are two ranks of a chessboard (8 ivory/dark squares each) with a tier-coloured neon strip under them;
#   * the console is a chess clock: sloped body, two round dials, two plunger buttons on top (the game IS speed chess);
#   * the uprights are two big pieces of the lane's own tier, standing on a podium with a neon base ring;
#   * paid tiers (5+) add captured pieces lying around the base and one floating piece that turns slowly.
# Run: python3 kit2.py [--render] [--export]   env: IDS=PawnMill,QueenDash  SHOT=row|single|pair  SAMPLES=32
import sys, os, math, json
import bpy, bmesh
from mathutils import Vector
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from rivals import reset, mat, setup_world, camera, render
from kit import (box, cyl, lathe, extrude, join, build_piece, smooth, tri_count, bounds, export_obj,
                 IVORY, GOLD, STEEL, BELT, TIER, NEON, DARK, PANEL)

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.abspath(os.path.join(HERE, "..", "..", "assets"))
MESH = os.path.join(OUT, "meshes_v2")
PREV = os.path.join(OUT, "previews")
os.makedirs(MESH, exist_ok=True)
os.makedirs(PREV, exist_ok=True)

IDS = ["PawnMill", "KnightSprint", "BishopRun", "RookRig", "QueenDash", "KingsEndgame", "CastleClimb", "GrandmasterGlide"]
SQUARE_DARK = (74, 80, 102)      # the dark board squares: lighter than the body so the checker reads
UPRIGHT = {"PawnMill": ["Pawn", "Pawn"], "KnightSprint": ["Knight", "Knight"], "BishopRun": ["Bishop", "Bishop"],
           "RookRig": ["Rook", "Rook"], "QueenDash": ["Queen", "Queen"], "KingsEndgame": ["King", "King"],
           "CastleClimb": ["Rook", "Rook"], "GrandmasterGlide": ["Queen", "King"]}
PIECE_H = {"Pawn": 3.6, "Knight": 4.15, "Bishop": 4.2, "Rook": 4.4, "Queen": 4.3, "King": 4.8}

PX, PY = 3.6, 5.3          # upright piece positions (x = +-PX), console end
CLOCK_Z = 4.95              # bottom of the chess clock (sits on the beam)


def checker_material(name, c1, c2, scale):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    b = nt.nodes["Principled BSDF"]
    ck = nt.nodes.new("ShaderNodeTexChecker")
    ck.inputs["Scale"].default_value = scale
    ck.inputs["Color1"].default_value = (*[(c / 255) ** 2.2 for c in c1], 1)
    ck.inputs["Color2"].default_value = (*[(c / 255) ** 2.2 for c in c2], 1)
    tc = nt.nodes.new("ShaderNodeTexCoord")
    nt.links.new(tc.outputs["Object"], ck.inputs["Vector"])
    nt.links.new(ck.outputs["Color"], b.inputs["Base Color"])
    b.inputs["Roughness"].default_value = 0.85
    return m


def chess_clock(R, tid, tier, neon):
    """Sloped clock body (front face toward the runner, -Y), two dials, two buttons."""
    y0, z0 = PY, CLOCK_Z
    W, D, Dt, H = 4.5, 2.1, 1.1, 2.3
    prof = [(y0 - D / 2, z0), (y0 + D / 2, z0), (y0 + D / 2, z0 + H), (y0 - D / 2 + (D - Dt), z0 + H)]
    body = extrude(prof, W, bev=0.14)
    R["Body"].append(body)
    R["Neon"].append(box((W + 0.08, D + 0.08, 0.16), (0, y0, z0 + 0.12), bev=0.0))            # glowing foot line
    slope = math.atan2(D - Dt, H)                                                               # face leans back
    for s in (-1, 1):
        zc = z0 + 1.2
        yf = y0 - D / 2 + (D - Dt) * ((zc - z0) / H) - 0.05
        rot = (90 - math.degrees(slope), 0, 0)
        ring = cyl(0.86, 0.14, (1.12 * s, yf - 0.02, zc), segs=28, bev=0.0)
        ring.rotation_euler = [math.radians(a) for a in rot]
        R["Neon"].append(ring)
        dial = cyl(0.72, 0.16, (1.12 * s, yf - 0.06, zc), segs=28, bev=0.03)
        dial.rotation_euler = [math.radians(a) for a in rot]
        R["Chess"].append(dial)
        # two hands (one at 12, one at 2 or 10) and a centre dot, dark
        for ang, ln in ((0, 0.55), (60 * s, 0.4)):
            hand = box((0.09, 0.06, ln), (0, 0, 0), bev=0.0)
            a = math.radians(ang)
            # local offset along the tilted face: up the face is (0, sin(slope), cos(slope))
            up = Vector((0, math.sin(slope), math.cos(slope)))
            side = Vector((1, 0, 0))
            dirv = up * math.cos(a) + side * math.sin(-a)
            c = Vector((1.12 * s, yf - 0.16, zc)) + dirv * (ln / 2)
            hand.location = c
            hand.rotation_euler = (-slope, math.radians(ang), 0)
            R["Body"].append(hand)
        dot = cyl(0.1, 0.1, (1.12 * s, yf - 0.17, zc), segs=10, bev=0.0)
        dot.rotation_euler = [math.radians(a) for a in rot]
        R["Body"].append(dot)
    # small glass screen strip under the dials (the game's Screen icon sits here)
    zs = z0 + 0.32
    ys = y0 - D / 2 + (D - Dt) * (0.32 / H) - 0.04
    scr = box((2.6, 0.08, 0.36), (0, ys, zs), (-math.degrees(slope), 0, 0), bev=0.0)
    R["Panel"].append(scr)
    # plunger buttons on top: the "pressed" one is the lane colour
    for s in (-1, 1):
        x = 1.12 * s
        R["Panel"].append(cyl(0.36, 0.34 if s < 0 else 0.6, (x, y0 + 0.25, z0 + H + (0.17 if s < 0 else 0.3)), segs=18, bev=0.04))
        R["Neon" if s < 0 else "Chess"].append(cyl(0.3, 0.16, (x, y0 + 0.25, z0 + H + (0.42 if s < 0 else 0.68)), segs=18, bev=0.04))
    return z0 + H


def treadmill(tid):
    tier = TIER[tid]
    neon = NEON[tid]
    cols = {"Body": DARK, "Panel": PANEL, "Square": SQUARE_DARK, "Chess": IVORY, "Neon": neon, "Belt": BELT,
            "Steel": STEEL, "Spill": (52, 54, 64), "Prop": GOLD if tid in ("QueenDash", "KingsEndgame", "GrandmasterGlide") else IVORY}
    R = {k: [] for k in cols}

    # ---- deck: dark plinth with a neon line all round ----
    R["Body"].append(box((8.2, 12.4, 0.5), (0, -0.1, 0.25), bev=0.12))
    R["Neon"].append(box((8.0, 12.2, 0.16), (0, -0.1, 0.56), bev=0.0))
    R["Body"].append(box((7.8, 11.9, 0.3), (0, -0.1, 0.78), bev=0.1))

    # ---- side rails = two ranks of a chessboard ----
    n, sq = 8, 1.36
    y_start = -0.1 - (n * sq) / 2 + sq / 2
    for s in (-1, 1):
        R["Body"].append(box((1.4, n * sq + 0.3, 0.6), (3.2 * s, -0.1, 1.15), bev=0.1))
        R["Neon"].append(box((0.14, n * sq, 0.2), (3.92 * s, -0.1, 1.1), bev=0.0))
        for i in range(n):
            light = (i + (0 if s < 0 else 1)) % 2 == 0
            R["Chess" if light else "Square"].append(box((1.26, sq - 0.08, 0.24), (3.2 * s, y_start + i * sq, 1.54), bev=0.05))
        # corner blocks at the back end (runner's entry), glowing inset
        R["Panel"].append(box((1.6, 1.4, 1.5), (3.25 * s, -5.85, 0.95), bev=0.12))
        R["Neon"].append(box((1.66, 0.8, 0.5), (3.25 * s, -5.85, 1.05), bev=0.0))

    # ---- belt, rollers, entry step with a little checker strip ----
    R["Belt"].append(box((5.0, 11.0, 0.4), (0, -0.2, 1.05), bev=0.04))
    for y in (-5.4, 4.6):
        R["Steel"].append(cyl(0.45, 5.0, (0, y, 1.0), axis="X", segs=16, bev=0.03))
    R["Body"].append(box((5.4, 1.1, 0.5), (0, -6.6, 0.25), bev=0.1))
    for i in range(6):
        R["Chess" if i % 2 == 0 else "Square"].append(box((0.84, 0.8, 0.1), (-2.1 + i * 0.84, -6.6, 0.53), bev=0.02))

    # ---- podium under the uprights ----
    R["Body"].append(box((10.6, 2.8, 0.9), (0, PY, 0.45), bev=0.15))
    R["Neon"].append(box((10.4, 2.6, 0.14), (0, PY, 0.95), bev=0.0))
    R["Panel"].append(box((10.2, 2.4, 0.25), (0, PY, 1.1), bev=0.08))

    # ---- uprights: two big pieces of this tier, neon ring at their feet ----
    top_target = 6.5 if tid != "CastleClimb" else 7.4
    for k, s in enumerate((-1, 1)):
        kind = UPRIGHT[tid][k]
        sc = min((top_target - 1.22) / PIECE_H[kind], 1.25)
        o = build_piece(kind, f"{tid}_{kind}{k}", sc)
        o.location = (PX * s, PY, 1.22)
        if kind == "Knight":
            o.rotation_euler = (0, 0, math.radians(180 if s > 0 else 0))   # horse profiles face out to the sides, mirrored
        R["Chess"].append(o)
        R["Neon"].append(cyl(1.42 * sc + 0.08, 0.14, (PX * s, PY, 1.3), segs=28, bev=0.0))

    # ---- beam between the pieces carries the clock; handlebars come off it ----
    R["Body"].append(box((6.6, 1.3, 0.7), (0, PY, 4.6), bev=0.12))
    R["Neon"].append(box((5.0, 0.12, 0.14), (0, PY - 0.66, 4.45), bev=0.0))
    for s in (-1, 1):
        R["Body"].append(box((0.5, 2.9, 0.5), (2.35 * s, PY - 1.9, 4.45), bev=0.1))
        R["Neon"].append(box((0.56, 0.6, 0.56), (2.35 * s, PY - 3.25, 4.45), bev=0.0))
    clock_top = chess_clock(R, tid, tier, neon)

    # ---- tier details on the clock (shape, not glow) ----
    if tid == "RookRig" or tid == "CastleClimb":
        for i in range(5):                                   # battlements along the beam
            R["Chess"].append(box((0.6, 1.0, 0.5), (-2.4 + i * 1.2, PY, 5.2), bev=0.05))
    if tid == "CastleClimb":                                 # pennants on the towers
        for s in (-1, 1):
            R["Steel"].append(cyl(0.06, 1.6, (PX * s, PY, 8.0), segs=8, bev=0.0))
            R["Neon"].append(extrude([(PY, 8.8), (PY, 8.2), (PY - 0.9 * 1, 8.5)], 0.08, bev=0.0))
            R["Neon"][-1].location.x = PX * s
    if tid == "BishopRun":                                   # diagonal "bishop lines" on the clock sides
        for s in (-1, 1):
            for j in range(3):
                R["Chess"].append(box((0.06, 0.22, 1.6), (2.27 * s, PY - 0.6 + j * 0.55, CLOCK_Z + 1.1), (40, 0, 0), bev=0.0))

    # ---- paid tiers: captured pieces lying around the base + one floating piece ----
    if tier >= 5:
        spill = [("Pawn", (-5.2, 2.2, 0.0), 0.42, 70, 0), ("Pawn", (5.1, -2.5, 0.0), 0.42, -110, 1), ("Rook", (5.4, 2.6, 0.0), 0.4, 20, 0),
                 ("Bishop", (-5.0, -3.8, 0.0), 0.4, -30, 1), ("Pawn", (-4.9, -6.5, 0.0), 0.38, 150, 0)]
        for kind, loc, sc, yaw, dark in spill:
            o = build_piece(kind, f"{tid}_spill", sc)
            # lie it on its side
            o.rotation_euler = (math.radians(90), 0, math.radians(yaw))
            o.location = (loc[0], loc[1], 1.28 * sc)
            R["Spill" if dark else "Chess"].append(o)
        for i, (x, y) in enumerate([(-5.4, 4.6), (5.6, 4.9), (-5.5, -0.6), (5.5, -5.6)]):
            R["Chess" if i % 2 else "Spill"].append(box((1.2, 1.2, 0.2), (x, y, 0.1), (0, 0, 15 * i), bev=0.04))
        prop_kind = {"QueenDash": "Queen", "KingsEndgame": "King", "CastleClimb": "Rook", "GrandmasterGlide": "King"}[tid]
        prop = build_piece(prop_kind, f"{tid}_Prop", 0.38)
        prop.location = (0, PY - 0.1, clock_top + 0.9)
        R["Prop"].append(prop)
        if tid == "GrandmasterGlide":                        # a gold crown ring orbits the king
            ring = lathe([(0.9, 0), (1.05, 0), (1.05, 0.22), (0.9, 0.22)], 28)
            ring.location = (0, PY - 0.1, clock_top + 1.5)
            R["Prop"].append(ring)

    out = {}
    for role, objs in R.items():
        if not objs:
            continue
        kind = {"Neon": "Neon", "Steel": "Metal", "Belt": "Fabric"}.get(role, "SmoothPlastic")
        o = join(objs, f"{tid}_{role}")
        smooth(o)
        o.data.materials.clear()
        o.data.materials.append(mat(cols[role], kind))
        out[role] = dict(obj=o, color=cols[role], material=kind)
        if role == "Prop":
            c = sum((o.matrix_world @ v.co for v in o.data.vertices), Vector()) / len(o.data.vertices)
            out[role]["spin"] = dict(centre_roblox=[round(c.x, 2), round(c.z, 2), round(-c.y, 2)], turnSeconds=8, axis="Y", bobStuds=0.3, bobSeconds=2)
    return out


def make_belt_png(path, c1=(34, 36, 44), c2=(54, 58, 72), px=256):
    """2x2 checker tile for the scrolling belt Texture (StudsPerTile 2.5 -> 1.25-stud squares)."""
    img = bpy.data.images.new("belt", px, px)
    h = px // 2
    data = []
    for y in range(px):
        for x in range(px):
            c = c1 if ((x // h) + (y // h)) % 2 == 0 else c2
            data += [c[0] / 255, c[1] / 255, c[2] / 255, 1]
    img.pixels = data
    img.filepath_raw = path
    img.file_format = "PNG"
    img.save()


if __name__ == "__main__":
    args = sys.argv
    reset()
    setup_world(samples=int(os.environ.get("SAMPLES", "32")))
    ids = os.environ.get("IDS", ",".join(IDS)).split(",")
    manifest = dict(version=2, units="studs", axes="Roblox: runner faces -Z, console at -Z end, origin = deck centre on the ground",
                    belt_texture="meshes_v2/BeltChecker.png (StudsPerTileU/V = 2.5)", treadmills={})
    built = {}
    for tid in ids:
        parts = treadmill(tid)
        built[tid] = parts
        objs = [p["obj"] for p in parts.values()]
        lo, hi = bounds(objs)
        manifest["treadmills"][tid] = dict(
            file=f"meshes_v2/{tid}.obj",
            parts={f"{tid}_{r}": dict(color=p["color"], material=p["material"], tris=tri_count(p["obj"]), **({"spin": p["spin"]} if "spin" in p else {})) for r, p in parts.items()},
            size=[round(hi.x - lo.x, 2), round(hi.z - lo.z, 2), round(hi.y - lo.y, 2)],
            tris=sum(tri_count(o) for o in objs))
        if "--export" in args:
            export_obj(objs, os.path.join(MESH, f"{tid}.obj"))
    if "--export" in args:
        make_belt_png(os.path.join(MESH, "BeltChecker.png"))
        with open(os.path.join(OUT, "meshes_v2.json"), "w") as f:
            json.dump(manifest, f, indent=1)
    print(json.dumps({k: (v["size"], v["tris"]) for k, v in manifest["treadmills"].items()}))
    if "--render" in args:
        belt_mat = checker_material("BeltChk", (34, 36, 44), (58, 62, 78), 2.2)
        for tid in ids:
            built[tid]["Belt"]["obj"].data.materials[0] = belt_mat
        n = len(ids)
        shot = os.environ.get("SHOT", "row")
        if n == 8:
            for i, tid in enumerate(ids):
                x, y, z = (i % 4 - 1.5) * 14, (0 if i < 4 else 19), (0 if i < 4 else 3)
                for p in built[tid].values():
                    p["obj"].location = (x, y, z)
            deck = box((58, 16, 3), (0, 19, 1.5), bev=0.3)
            deck.data.materials.append(mat((150, 156, 168)))
            camera((-18, -46, 25), (0, 8, 3), lens=34)
        elif shot == "pair":
            for i, tid in enumerate(ids):
                for p in built[tid].values():
                    p["obj"].location = ((i - (n - 1) / 2) * 13, 0, 0)
            camera((-17, -27, 13), (0, 0.5, 3.2), lens=36)
        else:
            camera((-13.5, -16, 9.5), (0.3, 0.8, 3.4), lens=33)
        render(os.path.join(PREV, os.environ.get("NAME", "treadmills_v2.png")))
