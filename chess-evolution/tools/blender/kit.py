# +1 Chess Evolution: chess pieces + chess treadmills, modelled in Blender (bpy).
# Blender units = studs. Blender +Y = Roblox -Z (runner faces the console at +Y), Blender Z = Roblox Y.
# Run: python3 kit.py [--render] [--export]
import sys, os, math, json
import bpy, bmesh
from mathutils import Vector, Matrix
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from rivals import reset, mat, setup_world, camera, render

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.abspath(os.path.join(HERE, "..", "..", "assets"))
MESH = os.path.join(OUT, "meshes")
PREV = os.path.join(OUT, "previews")
os.makedirs(MESH, exist_ok=True)

IVORY, CHAR, GOLD, BELT, STEEL = (246, 238, 220), (46, 48, 56), (255, 200, 50), (34, 36, 44), (150, 156, 168)
THEMES = {
    "PawnMill": dict(chassis=(80, 200, 90), rail=IVORY, console=(150, 100, 60), screen=(120, 255, 140), trim=IVORY),
    "KnightSprint": dict(chassis=(40, 90, 230), rail=(230, 236, 250), console=(28, 50, 140), screen=(80, 230, 255), trim=(230, 236, 250)),
    "BishopRun": dict(chassis=(130, 60, 160), rail=IVORY, console=(90, 40, 120), screen=(200, 120, 255), trim=IVORY),
    "RookRig": dict(chassis=(220, 50, 50), rail=CHAR, console=CHAR, screen=(255, 90, 70), trim=CHAR),
    "QueenDash": dict(chassis=IVORY, rail=GOLD, console=(240, 220, 170), screen=(255, 220, 90), trim=GOLD),
    "KingsEndgame": dict(chassis=CHAR, rail=GOLD, console=(30, 30, 36), screen=(255, 200, 60), trim=GOLD),
    "CastleClimb": dict(chassis=(40, 180, 200), rail=IVORY, console=(30, 110, 130), screen=(120, 255, 240), trim=IVORY),
    "GrandmasterGlide": dict(chassis=(30, 26, 50), rail=(170, 90, 255), console=(20, 18, 34), screen=(190, 120, 255), trim=GOLD),
}
ROLE_KIND = {"Screen": "Neon", "Steel": "Metal", "Belt": "Fabric"}

# ---------------- geometry helpers ----------------
def _obj(name, bm):
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    o = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(o)
    return o

def bevel(o, w=0.12, seg=2):
    if w <= 0:
        return o
    m = o.modifiers.new("Bevel", "BEVEL")
    m.width, m.segments, m.limit_method = w, seg, "ANGLE"
    m.harden_normals = False
    return o

def box(size, loc, rot=(0, 0, 0), bev=0.12):
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1)
    bmesh.ops.scale(bm, vec=Vector(size), verts=bm.verts)
    o = _obj("box", bm)
    o.rotation_euler = [math.radians(a) for a in rot]
    o.location = loc
    return bevel(o, min(bev, min(size) * 0.3))

def cyl(r, depth, loc, axis="Z", segs=20, bev=0.06, r2=None):
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, segments=segs, radius1=r, radius2=r if r2 is None else r2, depth=depth)
    o = _obj("cyl", bm)
    if axis == "X":
        o.rotation_euler = (0, math.radians(90), 0)
    elif axis == "Y":
        o.rotation_euler = (math.radians(90), 0, 0)
    o.location = loc
    return bevel(o, bev)

def lathe(profile, segs=20):
    """profile: list of (radius, z) from bottom to top; closed with caps on the axis."""
    bm = bmesh.new()
    rings = []
    for r, z in profile:
        ring = []
        for i in range(segs):
            a = 2 * math.pi * i / segs
            ring.append(bm.verts.new((max(r, 0.0001) * math.cos(a), max(r, 0.0001) * math.sin(a), z)))
        rings.append(ring)
    for a, b in zip(rings, rings[1:]):
        for i in range(segs):
            j = (i + 1) % segs
            bm.faces.new((a[i], a[j], b[j], b[i]))
    bm.faces.new(list(reversed(rings[0])))
    bm.faces.new(rings[-1])
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=0.0005)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return _obj("lathe", bm)

def arc(cx, cz, rad, a0, a1, n=6):
    return [(cx + rad * math.cos(math.radians(a0 + (a1 - a0) * i / n)), cz + rad * math.sin(math.radians(a0 + (a1 - a0) * i / n))) for i in range(n + 1)]

def extrude(points, thick, bev=0.08):
    """points: 2D outline (y, z), extruded along X, centred."""
    bm = bmesh.new()
    vs = [bm.verts.new((-thick / 2, y, z)) for y, z in points]
    f = bm.faces.new(vs)
    r = bmesh.ops.extrude_face_region(bm, geom=[f])
    nv = [e for e in r["geom"] if isinstance(e, bmesh.types.BMVert)]
    bmesh.ops.translate(bm, vec=(thick, 0, 0), verts=nv)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    o = _obj("ext", bm)
    return bevel(o, bev)

def join(objs, name):
    for o in objs:
        for m in list(o.modifiers):
            with bpy.context.temp_override(object=o):
                bpy.ops.object.modifier_apply(modifier=m.name)
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    if len(objs) > 1:
        bpy.ops.object.join()
    o = bpy.context.view_layer.objects.active
    o.name = name
    o.data.name = name
    return o

def place(o, loc=(0, 0, 0), rot=(0, 0, 0), scale=1.0):
    o.location = Vector(o.location) + Vector(loc) if False else loc
    o.rotation_euler = [math.radians(a) for a in rot]
    o.scale = (scale, scale, scale)
    return o

# ---------------- chess pieces (height ~4 studs at scale 1, base on z=0) ----------------
def piece_pawn():
    p = [(0.0, 0), (1.25, 0), (1.25, 0.32), (1.05, 0.45), (0.95, 0.62), (0.7, 0.75), (0.5, 1.6), (0.82, 1.72), (0.82, 1.9), (0.42, 2.0)]
    p += [(r, z) for r, z in arc(0, 2.75, 0.85, -62, 90, 8)]
    return [lathe(p)]

def piece_rook():
    p = [(0, 0), (1.35, 0), (1.35, 0.35), (1.12, 0.5), (1.0, 0.7), (0.78, 0.85), (0.72, 2.6), (1.08, 2.75), (1.08, 3.6), (0, 3.6)]
    parts = [lathe(p, 24)]
    for i in range(4):  # merlons
        a = math.radians(45 + 90 * i)
        parts.append(box((0.62, 0.62, 0.55), (0.78 * math.cos(a), 0.78 * math.sin(a), 3.85), (0, 0, 45 + 90 * i), 0.08))
    return parts

def piece_bishop():
    p = [(0, 0), (1.25, 0), (1.25, 0.32), (1.02, 0.46), (0.92, 0.62), (0.62, 0.78), (0.42, 2.0), (0.78, 2.1), (0.78, 2.26), (0.42, 2.34)]
    p += arc(0, 3.05, 0.72, -80, 60, 7) + [(0.12, 3.85), (0.001, 3.9)]
    parts = [lathe(p)]
    parts.append(cyl(0.2, 0.2, (0, 0, 4.0), segs=12, bev=0.04))
    parts.append(lathe([(0, 3.98)] + arc(0, 4.15, 0.2, -90, 90, 6)))
    return parts

def bishop_cut(o):
    """split-mitre slit: boolean a slanted slab out of the bishop head."""
    cutter = box((0.26, 3.0, 1.6), (0.32, 0, 3.55), (0, 40, 0), 0)
    m = o.modifiers.new("Mitre", "BOOLEAN")
    m.operation, m.object = "DIFFERENCE", cutter
    with bpy.context.temp_override(object=o):
        bpy.ops.object.modifier_apply(modifier=m.name)
    bpy.data.objects.remove(cutter)
    return o

def piece_queen():
    p = [(0, 0), (1.35, 0), (1.35, 0.35), (1.1, 0.5), (1.0, 0.68), (0.68, 0.85), (0.44, 2.5), (0.88, 2.62), (0.88, 2.78), (0.5, 2.88), (0.72, 3.5), (0.85, 3.7), (0.6, 3.72), (0.001, 3.8)]
    parts = [lathe(p, 24)]
    for i in range(8):  # crown points with jewel balls
        a = math.radians(22.5 + 45 * i)
        parts.append(box((0.26, 0.26, 0.4), (0.76 * math.cos(a), 0.76 * math.sin(a), 3.86), (0, 0, 45 * i), 0.05))
        parts.append(lathe(arc(0, 0, 0.17, -90, 90, 5), 10))
        parts[-1].location = (0.76 * math.cos(a), 0.76 * math.sin(a), 4.13)
    parts.append(lathe([(0, 3.7)] + arc(0, 4.05, 0.32, -90, 90, 6)))
    return parts

def piece_king():
    p = [(0, 0), (1.4, 0), (1.4, 0.36), (1.12, 0.52), (1.02, 0.7), (0.72, 0.88), (0.48, 2.6), (0.92, 2.72), (0.92, 2.9), (0.52, 3.0), (0.8, 3.6), (0.8, 3.8), (0.001, 3.84)]
    parts = [lathe(p, 24)]
    parts.append(box((0.34, 0.34, 1.0), (0, 0, 4.3), bev=0.06))
    parts.append(box((1.0, 0.34, 0.34), (0, 0, 4.42), bev=0.06))
    return parts

KNIGHT = [(-1.0, 0.0), (1.05, 0.0), (1.05, 0.5), (0.75, 0.75), (0.95, 1.6), (1.15, 2.6), (1.0, 3.3), (0.6, 3.75), (0.35, 4.15), (0.2, 3.85),
          (-0.15, 3.95), (-0.65, 3.7), (-1.25, 3.1), (-1.55, 2.75), (-1.45, 2.35), (-1.0, 2.35), (-0.55, 2.5), (-0.6, 1.8), (-0.85, 1.2), (-0.75, 0.75), (-1.0, 0.5)]
def piece_knight():
    # side silhouette (horse faces -y = forward when placed with rot 0 -> we face +Y: mirror)
    pts = [(-y, z) for y, z in KNIGHT]
    pts = list(reversed(pts))
    head = extrude([(y, z) for y, z in pts if z >= 0.74 or True], 1.25, bev=0.14)
    base = lathe([(0, 0), (1.3, 0), (1.3, 0.34), (1.05, 0.5), (0.95, 0.75), (0.001, 0.8)], 20)
    mane = extrude([(0.95, 1.6), (1.15, 2.6), (1.0, 3.3), (0.6, 3.75), (0.85, 3.5), (1.35, 2.7), (1.25, 1.7)], 0.7, bev=0.06)
    eyes = [box((1.32, 0.22, 0.22), (0, -0.75, 3.15), bev=0.03)]
    return [head, base], [mane], eyes

def build_piece(kind, name, scale=1.0):
    if kind == "Knight":
        main, accent, eyes = piece_knight()
        o = join(main + accent, name)
        bpy.data.objects.remove(eyes[0])
        o.data.transform(Matrix.Rotation(math.radians(90), 4, "Z"))  # show the horse profile to the front (-Y)
    else:
        o = join({"Pawn": piece_pawn, "Rook": piece_rook, "Bishop": piece_bishop, "Queen": piece_queen, "King": piece_king}[kind](), name)
        if kind == "Bishop":
            bishop_cut(o)
    o.scale = (scale, scale, scale)
    bpy.context.view_layer.objects.active = o
    bpy.ops.object.select_all(action="DESELECT")
    o.select_set(True)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    smooth(o)
    return o

def smooth(o, angle=40):
    for poly in o.data.polygons:
        poly.use_smooth = True
    try:
        o.data.set_sharp_from_angle(angle=math.radians(angle))
    except Exception as e:
        print("sharp", e)

# ---------------- treadmills ----------------
# Vault rules used here (Build Playbooks 23 + Lesson - Tiered Training Lanes + 09 Owner Taste Rules):
#  * one shape cloned for every tier; the whole lane is the tier colour, the rim a darker shade, a dark belt;
#  * one main colour plus white: rails and the chess silhouette are white/ivory;
#  * higher tiers look fancier by shape and life, not brightness: tiers 1-2 plain, 3-4 add neon edge strips
#    and glowing corner blocks, 5+ add a ground "spill" and one moving prop, the last tier is black with neon lines;
#  * no floating orbs, no skulls, nothing tall in the lane, low part counts.
TIER = {"PawnMill": 1, "KnightSprint": 2, "BishopRun": 3, "RookRig": 4, "QueenDash": 5, "KingsEndgame": 6, "CastleClimb": 7, "GrandmasterGlide": 8}

def shade(c, k):
    return tuple(max(0, min(255, int(v * k))) for v in c)
def tint(c, k):
    return tuple(int(v + (255 - v) * k) for v in c)

DARK, PANEL = (30, 34, 45), (52, 58, 74)
# one colour per lane (plus white); eight clearly different hues so tiers read from across the map
NEON = {"PawnMill": (70, 230, 110), "KnightSprint": (60, 130, 255), "BishopRun": (235, 90, 220), "RookRig": (255, 60, 50),
        "QueenDash": (255, 205, 70), "KingsEndgame": (255, 130, 30), "CastleClimb": (50, 235, 190), "GrandmasterGlide": (150, 80, 255)}

def treadmill(tid):
    th = THEMES[tid]
    tier = TIER[tid]
    neon = NEON[tid]
    cols = {"Body": DARK, "Panel": PANEL, "Chess": IVORY, "Neon": neon, "Belt": BELT, "Steel": STEEL,
            "Spill": DARK, "Prop": GOLD if tid in ("QueenDash", "KingsEndgame", "GrandmasterGlide") else IVORY}
    roles = {k: [] for k in cols}
    R = roles
    # ---- the shared shape (treadmill_reference_sheet_1): low dark voxel deck, neon side strips, glowing corner
    #      blocks, slim uprights to a tall console with a glowing screen and short handlebars ----
    R["Body"].append(box((8, 12, 0.8), (0, 0, 0.4), bev=0.12))                        # deck
    for s in (-1, 1):
        R["Body"].append(box((1.2, 11.0, 1.2), (3.4 * s, 0, 1.0), bev=0.12))          # side rails along the belt
        R["Neon"].append(box((0.2, 9.6, 0.25), (4.02 * s, 0, 1.05), bev=0.0))         # long neon strip on the outside face
        R["Neon"].append(box((0.22, 9.6, 0.2), (3.85 * s, 0, 1.62), bev=0.0))          # thin neon line on the outer top edge
        for i in range(6):                                                              # studs on the rail tops
            R["Body"].append(cyl(0.2, 0.18, (3.3 * s, -4.2 + i * 1.7, 1.68), segs=10, bev=0.0))
        for y in (-5.5, 5.5):                                                           # glowing corner blocks
            R["Panel"].append(box((1.5, 1.5, 1.7), (3.55 * s, y, 0.95), bev=0.12))
            R["Neon"].append(box((1.56, 0.9, 1.0), (3.55 * s, y, 0.95), bev=0.0))
    R["Belt"].append(box((5.4, 11.0, 0.5), (0, 0, 1.0), bev=0.04))
    for y in (-5.3, 5.3):
        R["Steel"].append(cyl(0.55, 5.4, (0, y, 0.95), axis="X", segs=16, bev=0.04))   # recessed rollers
    R["Body"].append(box((5.4, 1.0, 0.4), (0, -6.3, 0.2), (10, 0, 0), bev=0.1))      # low entry lip
    # console head: tall, at the front (+Y), tilted toward the runner, glowing screen with a chess icon
    head = box((6.2, 1.2, 2.4), (0, 5.4, 6.6), (-14, 0, 0), bev=0.15)
    R["Body"].append(head)
    R["Panel"].append(box((4.6, 0.16, 1.6), (0, 4.75, 6.65), (-14, 0, 0), bev=0.0))  # dark glass screen (the game's SurfaceGui icon sits on it)
    for dx in (-0.55, 0.0, 0.55):
        R["Neon"].append(box((0.32, 0.12, 0.32), (dx, 4.66, 6.65), (-14, 0, 45), bev=0.0))  # three small glowing screen marks
    R["Panel"].append(box((6.4, 1.4, 0.3), (0, 5.4, 7.9), (-14, 0, 0), bev=0.08))    # console lid
    for s in (-1, 1):
        R["Neon"].append(box((0.25, 0.3, 0.3), (2.9 * s, 4.6, 5.6), bev=0.0))        # console side lights

    def uprights(color_role="Steel"):
        for s in (-1, 1):
            R[color_role].append(box((0.7, 0.7, 5.6), (2.9 * s, 5.4, 3.9), (-8, 0, 0), bev=0.1))
    def handlebars():
        for s in (-1, 1):
            R["Body"].append(box((0.6, 3.2, 0.6), (2.9 * s, 3.6, 4.9), bev=0.12))
            R["Neon"].append(box((0.64, 0.5, 0.64), (2.9 * s, 2.1, 4.9), bev=0.0))   # neon grip ends

    def put(kind, loc, scale, role="Chess", rot=(0, 0, 0)):
        o = build_piece(kind, f"{tid}_{kind}", scale)
        o.location = loc
        o.rotation_euler = [math.radians(a) for a in rot]
        R[role].append(o)
        return o

    # ---- each tier's chess signature, in white, built into the frame (readable with particles off) ----
    if tid == "PawnMill":          # pawns are the upright caps and the handlebar ends
        uprights(); handlebars()
        for s in (-1, 1):
            put("Pawn", (2.9 * s, 2.1, 5.2), 0.3)
            put("Pawn", (3.55 * s, -5.5, 1.8), 0.3)
    elif tid == "KnightSprint":    # two knights hold up the console, stepped side plates
        handlebars()
        for s in (-1, 1):
            put("Knight", (2.9 * s, 5.6, 0.8), 1.15, rot=(0, 0, 180 if s > 0 else 0))
            for i in range(3):
                R["Panel"].append(box((0.4, 3.0 - i * 0.8, 0.5), (4.2 * s, -1.5 + i * 0.4, 0.5 + i * 0.5), bev=0.08))
    elif tid == "BishopRun":       # mitre finials on the console, diagonal inlay on the rails
        uprights(); handlebars()
        for s in (-1, 1):
            put("Bishop", (2.9 * s, 5.4, 8.0), 0.42)
            for i in range(5):
                R["Chess"].append(box((0.16, 0.3, 1.0), (4.05 * s, -4.0 + i * 2.0, 1.0), (40, 0, 0), bev=0.0))
    elif tid == "RookRig":         # crenellated towers are the uprights, heavy crossbar on top
        handlebars()
        for s in (-1, 1):
            put("Rook", (2.9 * s, 5.5, 0.8), 1.45)
        R["Panel"].append(box((7.4, 1.2, 1.0), (0, 5.4, 8.4), bev=0.15))
    elif tid == "QueenDash":       # crown-shaped console with jewel tips
        uprights("Chess"); handlebars()
        for i in range(5):
            x = -2.4 + i * 1.2
            h = 1.1 if i % 2 == 0 else 0.7
            R["Chess"].append(box((0.5, 0.5, h), (x, 5.55, 8.0 + h / 2), (-14, 0, 45), bev=0.05))
            R["Neon"].append(box((0.36, 0.36, 0.36), (x, 5.6, 8.25 + h), (45, 0, 45), bev=0.0))
    elif tid == "KingsEndgame":    # stepped supports and a cross over the console
        handlebars()
        for s in (-1, 1):
            for i in range(4):
                R["Chess" if i % 2 else "Panel"].append(box((1.5 - i * 0.25, 1.5 - i * 0.25, 1.5), (2.9 * s, 5.4, 1.5 + i * 1.5), bev=0.1))
    elif tid == "CastleClimb":     # a castle gate frames the console
        handlebars()
        for s in (-1, 1):
            R["Panel"].append(box((1.4, 1.4, 7.6), (3.4 * s, 5.4, 4.6), bev=0.12))
            for k in (-1, 1):
                R["Chess"].append(box((0.55, 0.55, 0.6), (3.4 * s + 0.4 * k, 5.4, 8.7), bev=0.05))
        R["Panel"].append(box((8.2, 1.4, 0.8), (0, 5.4, 8.3), bev=0.12))
        for i in range(4):
            R["Chess"].append(box((0.6, 0.6, 0.6), (-1.8 + i * 1.2, 5.4, 9.0), bev=0.05))
    elif tid == "GrandmasterGlide":  # the king and queen are the uprights
        handlebars()
        put("Queen", (-2.9, 5.6, 0.8), 1.5)
        put("King", (2.9, 5.6, 0.8), 1.5)

    # ---- tiers 5+: a ground spill of checker cubes around the base (1-3 studs tall) ----
    if tier >= 5:
        spots = [(-4.9, 5.2, 1.4), (-5.2, 3.6, 0.9), (-4.6, -5.6, 1.0), (4.9, 5.4, 1.6), (5.3, 3.8, 1.0), (4.7, -5.4, 1.2), (-5.6, -3.8, 0.7), (5.6, -3.6, 0.8)]
        for i, (x, y, h) in enumerate(spots):
            R["Spill"].append(box((h, h, h), (x, y, h / 2), (0, 0, 12 * (i % 3)), bev=0.1))
            R["Neon" if i % 2 == 0 else "Chess"].append(box((0.22, 0.22, 0.22), (x + h * 0.3, y - h * 0.51, h * 0.7), bev=0.0))
    # ---- tiers 5+: one moving prop, a separate object the game turns slowly (1 turn per 6-10 s) ----
    if tier >= 5:
        if tid == "QueenDash":
            crown = lathe([(0.0, 0), (0.95, 0), (0.95, 0.2), (0.75, 0.35), (0.85, 0.75), (0.001, 0.8)], 20)
            parts = [crown]
            for i in range(6):
                a = math.radians(60 * i)
                parts.append(box((0.24, 0.24, 0.45), (0.8 * math.cos(a), 0.8 * math.sin(a), 0.95), (0, 0, 60 * i), 0.05))
            prop = join(parts, f"{tid}_Prop")
            prop.location = (0, 5.5, 9.9)
        elif tid == "KingsEndgame":
            prop = join([box((0.55, 0.55, 2.0), (0, 0, 0), bev=0.1), box((1.7, 0.55, 0.55), (0, 0, 0.4), bev=0.1)], f"{tid}_Prop")
            prop.location = (0, 5.4, 9.6)
        elif tid == "CastleClimb":
            prop = build_piece("Rook", f"{tid}_Prop", 0.4)
            prop.location = (0, 5.4, 9.4)
        else:
            prop = build_piece("King", f"{tid}_Prop", 0.42)
            prop.location = (0, 5.4, 8.4)
        R["Prop"].append(prop)

    out = {}
    for role, objs in roles.items():
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
            out[role]["spin"] = dict(centre_roblox=[round(c.x, 2), round(c.z, 2), round(-c.y, 2)], turnSeconds=8, axis="Y")
    return out

def tri_count(o):
    return sum(len(p.vertices) - 2 for p in o.data.polygons)

def bounds(objs):
    lo = Vector((1e9,) * 3); hi = Vector((-1e9,) * 3)
    for o in objs:
        for v in o.data.vertices:
            w = o.matrix_world @ v.co
            lo = Vector(map(min, lo, w)); hi = Vector(map(max, hi, w))
    return lo, hi

def export_obj(objs, path):
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.wm.obj_export(filepath=path, export_selected_objects=True, forward_axis="NEGATIVE_Z", up_axis="Y",
                          export_materials=True, export_uv=True, export_normals=True, apply_modifiers=True)

if __name__ == "__main__":
    args = sys.argv
    reset()
    setup_world(samples=int(os.environ.get("SAMPLES", "32")))
    manifest = dict(units="studs", axes="Roblox: runner faces -Z, console at -Z end, origin = deck centre on the ground",
                    treadmills={}, pieces={})
    ids = os.environ.get("IDS", ",".join(THEMES)).split(",")
    built = {}
    for i, tid in enumerate(ids):
        parts = treadmill(tid)
        built[tid] = parts
        objs = [p["obj"] for p in parts.values()]
        lo, hi = bounds(objs)
        manifest["treadmills"][tid] = dict(
            file=f"meshes/{tid}.obj",
            parts={f"{tid}_{r}": dict(color=p["color"], material=p["material"], tris=tri_count(p["obj"]), **({"spin": p["spin"]} if "spin" in p else {})) for r, p in parts.items()},
            size=[round(hi.x - lo.x, 2), round(hi.z - lo.z, 2), round(hi.y - lo.y, 2)])
        if "--export" in args:
            export_obj(objs, os.path.join(MESH, f"{tid}.obj"))
    if "--pieces" in args:
        for k, kind in enumerate(["Pawn", "Knight", "Bishop", "Rook", "Queen", "King"]):
            o = build_piece(kind, f"Piece_{kind}")
            lo, hi = bounds([o])
            manifest["pieces"][kind] = dict(file=f"meshes/Piece_{kind}.obj", tris=tri_count(o), size=[round(hi.x - lo.x, 2), round(hi.z - lo.z, 2), round(hi.y - lo.y, 2)])
            if "--export" in args:
                export_obj([o], os.path.join(MESH, f"Piece_{kind}.obj"))
            o.location = (-8.5 + k * 3.4, -14, 0); o.rotation_euler = (0, 0, math.radians(-15))
            o.data.materials.append(mat((246, 238, 220) if k % 2 == 0 else (60, 62, 72)))
    if "--export" in args:
        with open(os.path.join(OUT, "meshes.json"), "w") as f:
            json.dump(manifest, f, indent=1)
    print(json.dumps({k: v["size"] for k, v in manifest["treadmills"].items()}))
    print(json.dumps({k: {kk: vv["tris"] for kk, vv in v["parts"].items()} for k, v in manifest["treadmills"].items()}))
    if "--render" in args:
        n = len(ids)
        two_rows = n == 8
        for i, tid in enumerate(ids):
            if two_rows:  # the terrace: starter row in front, aspirational row raised behind
                x, y, z = (i % 4 - 1.5) * 11, (0 if i < 4 else 17), (0 if i < 4 else 3)
            else:
                x, y, z = (i - (n - 1) / 2) * 11, 0, 0
            for p in built[tid].values():
                p["obj"].location = (x, y, z)
        if two_rows:
            deck = box((46, 14, 3), (0, 17, 1.5), bev=0.3)
            deck.data.materials.append(mat((150, 156, 168)))
        if os.environ.get("GROUND") == "dark":
            g = bpy.data.objects.get("Ground")
            g.data.materials.clear(); g.data.materials.append(mat((44, 52, 70)))
            bpy.context.scene.world.node_tree.nodes["Background"].inputs[0].default_value = (0.05, 0.08, 0.16, 1)
        shot = os.environ.get("SHOT", "row")
        if shot == "row" and two_rows:
            camera((-14, -38, 22), (0, 8, 2), lens=34)
        elif shot == "row":
            camera((-0.0 + (n - 1) * 1.5, -26 - n * 3.2, 15 + n), (0, 0, 2.5), lens=38)
        elif shot == "single":
            camera((-13.5, -15, 9.5), (0.5, 1.0, 3.0), lens=35)
        elif shot == "pieces":
            camera((0, -38, 9), (0, -14, 2.2), lens=45)
        render(os.path.join(PREV, os.environ.get("NAME", "treadmills.png")))
