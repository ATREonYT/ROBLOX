# Build the 1v1 rivals, duel table and battle animations in Blender, render previews, export JSON for Lune.
# Run: python3 rivals.py [--render]   (uses the bpy module; Roblox axes are converted: rbx(x,y,z) = blender(x,-z... see to_b)
import sys, os, json, math
import bpy
from mathutils import Vector, Quaternion, Euler, Matrix
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import rig

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.abspath(os.path.join(HERE, "..", "..", "assets"))
PREV = os.path.join(OUT, "previews")
os.makedirs(PREV, exist_ok=True)
FPS = 30

M = Matrix(((1, 0, 0), (0, 0, -1), (0, 1, 0)))  # rbx -> blender: (x, y, z) -> (x, -z, y)
def to_b(v):
    return Vector((v[0], -v[2], v[1]))
def rot_b(deg):  # rbx CFrame.Angles(x,y,z) -> blender matrix
    r = Euler([math.radians(a) for a in deg], "ZYX").to_matrix()
    return M @ r @ M.transposed()
def q_to_r(qb):  # blender quaternion -> rbx quaternion (w,x,y,z)
    return (qb.w, qb.x, qb.z, -qb.y)
def q_from_r(deg):  # rbx euler degrees -> blender quaternion
    return rot_b(deg).to_quaternion()

def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)

MATS = {}
def mat(color, kind="SmoothPlastic"):
    key = (tuple(color), kind)
    if key in MATS:
        return MATS[key]
    m = bpy.data.materials.new(f"C_{color[0]}_{color[1]}_{color[2]}_{kind}")
    m.use_nodes = True
    b = m.node_tree.nodes["Principled BSDF"]
    lin = [((c / 255) ** 2.2) for c in color]
    b.inputs["Base Color"].default_value = (*lin, 1)
    b.inputs["Roughness"].default_value = {"Metal": 0.35, "Glass": 0.05, "Neon": 0.5, "Fabric": 0.9, "Wood": 0.7}.get(kind, 0.55)
    if kind == "Metal":
        b.inputs["Metallic"].default_value = 0.8
    if kind == "Neon":
        b.inputs["Emission Color"].default_value = (*lin, 1)
        b.inputs["Emission Strength"].default_value = 1.1
    if kind == "Glass":
        b.inputs["Alpha"].default_value = 0.55
    MATS[key] = m
    return m

def box(name, size_r, center_b, color, kind="SmoothPlastic", shape="Block", parent=None, local_offset=None, rotm=None):
    sx, sy, sz = size_r[0], size_r[2], size_r[1]  # blender extents
    if shape == "Cylinder":  # rbx cylinder: axis along part X
        bpy.ops.mesh.primitive_cylinder_add(vertices=20, radius=0.5, depth=1)
        o = bpy.context.object
        o.data.transform(Matrix.Rotation(math.radians(90), 4, "Y"))
        o.data.transform(Matrix.Diagonal((sx, sy, sz, 1)))
    elif shape == "Ball":
        bpy.ops.mesh.primitive_uv_sphere_add(segments=16, ring_count=8, radius=0.5)
        o = bpy.context.object
        o.data.transform(Matrix.Diagonal((sx, sy, sz, 1)))
    else:
        bpy.ops.mesh.primitive_cube_add(size=1)
        o = bpy.context.object
        o.data.transform(Matrix.Diagonal((sx, sy, sz, 1)))
    if rotm is not None:
        o.data.transform(rotm.to_4x4())
    if local_offset is not None:
        o.data.transform(Matrix.Translation(local_offset))
    o.name = name
    o.data.materials.append(mat(color, kind))
    if parent is not None:
        o.parent = parent
    o.location = center_b
    return o

def build_rival(r, origin_b):
    s = r["scale"]
    cols = rig.limb_colors(r["outfit"])
    objs = {}
    for name in rig.ORDER:
        size, center, parent, motor, joint = rig.LIMBS[name]
        size = [v * s for v in size]
        center = Vector(center) * s
        if parent is None:
            o = box(f"{r['id']}_{name}", size, origin_b + to_b(center), cols[name])
            o.hide_render = True
            o.display_type = "WIRE"
        else:
            jw = Vector(joint) * s
            pj = Vector((0, 0, 0)) if rig.LIMBS[parent][2] is None else Vector(rig.LIMBS[parent][4]) * s
            o = box(f"{r['id']}_{name}", size, to_b(jw - pj), cols[name], parent=objs[parent], local_offset=to_b(center - jw))
        o.rotation_mode = "QUATERNION"
        objs[name] = o
    for a in r["extras"]:
        lim = a["limb"]
        j = Vector((0, 0, 0)) if lim == "HumanoidRootPart" else Vector(rig.LIMBS[lim][4]) * s
        pos = Vector(a["pos"]) * s
        box(f"{r['id']}_{a['name']}", [v * s for v in a["size"]], to_b(pos - j), a["color"], a["mat"], a["shape"],
            parent=objs[lim], rotm=rot_b(a["rot"]))
    return objs

# ---------------- animations (degrees about Roblox axes) ----------------
READY = {"UpperTorso": (-10, 0, 0), "Head": (-15, 0, 0),
         "RightUpperArm": (40, 0, 8), "RightLowerArm": (50, 0, 0),
         "LeftUpperArm": (40, 0, -8), "LeftLowerArm": (50, 0, 0),
         "LeftUpperLeg": (8, 0, 0), "LeftLowerLeg": (-10, 0, 0), "RightUpperLeg": (8, 0, 0), "RightLowerLeg": (-10, 0, 0)}
def P(base=READY, root=(0, 0, 0), **kw):
    d = dict(base)
    for k, v in kw.items():
        d[k] = v
    return (d, root)

def arm(side, sh, el, out=0, wr=0, twist=0):
    o = out if side == "Right" else -out
    return {f"{side}UpperArm": (sh, twist, o), f"{side}LowerArm": (el, 0, 0), f"{side}Hand": (wr, 0, 0)}
def merge(*ds):
    out = dict(READY)
    for d in ds:
        out.update(d)
    return out

# Vault timing (Build Playbooks 16, 17 sec.103-106, 19): five poses per strike (idle, anticipation, contact,
# follow-through, recovery); the contact lands in 1-2 frames; the head lags the arms ("twinning");
# holds drift instead of freezing; stance loops (Idle, Tap) move only the arms, torso and head so legs stay free.
UPPER = ["UpperTorso", "Head", "LeftUpperArm", "LeftLowerArm", "LeftHand", "RightUpperArm", "RightLowerArm", "RightHand"]
ANT = dict(sh=122, el=48, out=14, wr=30)      # anticipation: hand high, wrist cocked
CON = dict(sh=34, el=58, out=6, wr=-12)       # contact on the clock
FOL = dict(sh=27, el=63, out=6, wr=-26)       # follow-through: a touch past contact
REC = dict(sh=48, el=54, out=8, wr=0)         # recovery
RISE = dict(sh=78, el=46, out=12, wr=12)      # on its way up
def tap(r, l, torso, head):
    return P(merge(arm("Right", **r), arm("Left", **l), {"UpperTorso": torso, "Head": head}))
ANIMS = {
    "Idle": dict(loop=True, priority="Idle", limbs=UPPER, keys=[
        (0.0, P(), "Sine"),
        (1.0, P(merge({"UpperTorso": (-7, 4, 0), "Head": (-12, 6, 0)}, arm("Right", 44, 48, out=8), arm("Left", 38, 52, out=8))), "Sine"),
        (2.0, P(), "Sine")]),
    "Tap": dict(loop=True, priority="Action", limbs=UPPER, keys=[
        (0.000, tap(ANT, REC, (-12, -6, 0), (-19, 3, 0)), "Cubic-In"),     # right hand cocked
        (0.100, tap(CON, RISE, (-16, -9, 0), (-20, 0, 0)), "Linear"),      # right contact (head still catching up)
        (0.133, tap(FOL, RISE, (-17, -9, 0), (-22, -5, 0)), "Cubic-Out"),  # follow-through, 1 frame later
        (0.200, tap(REC, ANT, (-12, 6, 0), (-19, -3, 0)), "Cubic-In"),     # left hand cocked
        (0.300, tap(RISE, CON, (-16, 9, 0), (-20, 0, 0)), "Linear"),       # left contact
        (0.333, tap(RISE, FOL, (-17, 9, 0), (-22, 5, 0)), "Cubic-Out"),    # follow-through
        (0.400, tap(ANT, REC, (-12, -6, 0), (-19, 3, 0)), "Cubic-In")]),   # = first key, seamless loop
    "Victory": dict(loop=False, priority="Action", keys=[
        (0.0, P(), "Cubic"),
        (0.15, P(merge({"UpperTorso": (-15, 0, 0), "LeftUpperLeg": (40, 0, 0), "LeftLowerLeg": (-60, 0, 0), "RightUpperLeg": (40, 0, 0), "RightLowerLeg": (-60, 0, 0),
                        "LeftFoot": (20, 0, 0), "RightFoot": (20, 0, 0)}, arm("Right", 0, 30, out=20), arm("Left", 0, 30, out=20)), root=(0, -0.45, 0)), "Cubic"),
        (0.38, P(merge({"UpperTorso": (8, 0, 0), "Head": (15, 0, 0), "LeftUpperLeg": (15, 0, 0), "LeftLowerLeg": (-35, 0, 0), "RightUpperLeg": (-5, 0, 0)},
                       arm("Right", 165, 0, out=28), arm("Left", 165, 0, out=28)), root=(0, 1.1, 0)), "Cubic"),
        (0.62, P(merge({"UpperTorso": (-5, 0, 0), "LeftUpperLeg": (25, 0, 0), "LeftLowerLeg": (-40, 0, 0), "RightUpperLeg": (25, 0, 0), "RightLowerLeg": (-40, 0, 0)},
                       arm("Right", 150, 10, out=25), arm("Left", 150, 10, out=25)), root=(0, -0.25, 0)), "Cubic"),
        (0.85, P(merge({"Head": (10, 0, 0)}, arm("Right", 170, 0, out=10), arm("Left", 20, 90, out=40, twist=-30))), "Cubic"),
        (1.05, P(merge({"Head": (5, 0, 0)}, arm("Right", 140, 70, out=10), arm("Left", 20, 90, out=40, twist=-30))), "Cubic"),
        (1.25, P(merge({"Head": (12, 0, 0)}, arm("Right", 175, 0, out=10), arm("Left", 20, 90, out=40, twist=-30)), root=(0, 0.1, 0)), "Cubic"),
        (1.5, P(merge({"Head": (10, 0, 0)}, arm("Right", 170, 0, out=10), arm("Left", 20, 90, out=40, twist=-30))), "Cubic")]),
    "Defeat": dict(loop=False, priority="Action", keys=[
        (0.0, P(), "Cubic"),
        (0.25, P(merge({"UpperTorso": (14, 0, 0), "Head": (18, 0, 0)}, arm("Right", 30, 20, out=45), arm("Left", 30, 20, out=45)), root=(0, 0, 0.3)), "Cubic"),
        (0.8, P(merge({"UpperTorso": (-32, 0, 0), "Head": (-18, 0, 0), "LeftUpperLeg": (20, 0, 0), "LeftLowerLeg": (-30, 0, 0), "RightUpperLeg": (20, 0, 0), "RightLowerLeg": (-30, 0, 0)},
                      arm("Right", 5, 5, out=4), arm("Left", 5, 5, out=4)), root=(0, -0.25, 0)), "Cubic"),
        (1.25, P(merge({"UpperTorso": (-25, 0, 0), "Head": (-16, 0, 0), "LeftUpperLeg": (20, 0, 0), "LeftLowerLeg": (-30, 0, 0), "RightUpperLeg": (20, 0, 0), "RightLowerLeg": (-30, 0, 0)},
                       arm("Right", 150, 115, out=35), arm("Left", 150, 115, out=35)), root=(0, -0.25, 0)), "Cubic"),
        (1.6, P(merge({"UpperTorso": (-28, 0, 0), "Head": (-20, 6, 0), "LeftUpperLeg": (20, 0, 0), "LeftLowerLeg": (-30, 0, 0), "RightUpperLeg": (20, 0, 0), "RightLowerLeg": (-30, 0, 0)},
                      arm("Right", 150, 115, out=35), arm("Left", 150, 115, out=35)), root=(0, -0.25, 0)), "Cubic")]),
}

def key_anim(objs, name, start_frame=1, scale=1.0):
    a = ANIMS[name]
    rest_lt = objs["LowerTorso"].location.copy()
    for t, (pose, root), _ease in a["keys"]:
        f = start_frame + round(t * FPS)
        for limb in rig.ORDER[1:]:
            o = objs[limb]
            o.rotation_quaternion = q_from_r(pose.get(limb, (0, 0, 0)))
            o.keyframe_insert("rotation_quaternion", frame=f)
        objs["LowerTorso"].location = rest_lt + to_b(Vector(root) * scale)
        objs["LowerTorso"].keyframe_insert("location", frame=f)
    objs["LowerTorso"].location = rest_lt

def export_anim(objs, name):
    """Read the keyed Blender rig back out as Roblox Pose data (Motor6D.Transform per Part1)."""
    a = ANIMS[name]
    sc = bpy.context.scene
    rest_lt = to_b(Vector(rig.LIMBS["LowerTorso"][4]))
    frames = []
    for t, _p, ease in a["keys"]:
        sc.frame_set(1 + round(t * FPS))
        poses = {}
        for limb in a.get("limbs", rig.ORDER[1:]):
            o = objs[limb]
            q = q_to_r(o.matrix_basis.to_quaternion())
            pos = (0, 0, 0)
            if limb == "LowerTorso":
                d = o.matrix_basis.translation - rest_lt
                pos = (round(d.x, 4), round(d.z, 4), round(-d.y, 4))
            poses[limb] = dict(q=[round(v, 5) for v in q], p=pos)
        frames.append(dict(t=t, ease=ease, poses=poses))
    return dict(name=name, loop=a["loop"], priority=a["priority"], frames=frames)

def export_json(path, anim_rig):
    data = dict(limbs={}, rivals=[], duel=rig.DUEL, anchors=rig.ANCHORS, anims=[], hipHeight=rig.HIP_HEIGHT)
    for name in rig.ORDER:
        size, center, parent, motor, joint = rig.LIMBS[name]
        data["limbs"][name] = dict(size=size, center=center, parent=parent, motor=motor, joint=joint)
    data["order"] = rig.ORDER
    for r in rig.RIVALS:
        data["rivals"].append(dict(id=r["id"], display=r["display"], stage=r["stage"], scale=r["scale"],
                                   colors=rig.limb_colors(r["outfit"]), extras=r["extras"]))
    for n in ANIMS:
        data["anims"].append(export_anim(anim_rig, n))
    with open(path, "w") as f:
        json.dump(data, f, indent=1)

# ---------------- scene + renders ----------------
def setup_world(res=(1600, 900), samples=48):
    sc = bpy.context.scene
    sc.render.engine = "CYCLES"
    sc.cycles.samples = samples
    sc.cycles.device = "CPU"
    try:
        sc.cycles.use_denoising = True
    except Exception:
        pass
    sc.render.resolution_x, sc.render.resolution_y = res
    sc.render.fps = FPS
    sc.view_settings.view_transform = "Standard"
    w = bpy.data.worlds.new("Sky")
    w.use_nodes = True
    w.node_tree.nodes["Background"].inputs[0].default_value = (0.45, 0.68, 1.0, 1)
    w.node_tree.nodes["Background"].inputs[1].default_value = 0.9
    sc.world = w
    sun = bpy.data.objects.new("Sun", bpy.data.lights.new("Sun", "SUN"))
    sun.data.energy = 3.2
    sun.data.angle = math.radians(8)
    sun.rotation_euler = (math.radians(50), math.radians(10), math.radians(35))
    sc.collection.objects.link(sun)
    g = box("Ground", (200, 1, 200), Vector((0, 0, -0.5)), (96, 214, 74))
    return sc

def camera(loc, target, lens=40):
    cam = bpy.data.objects.new("Cam", bpy.data.cameras.new("Cam"))
    cam.data.lens = lens
    bpy.context.scene.collection.objects.link(cam)
    cam.location = loc
    d = Vector(target) - Vector(loc)
    cam.rotation_euler = d.to_track_quat("-Z", "Y").to_euler()
    bpy.context.scene.camera = cam
    return cam

def render(path, frame=1):
    sc = bpy.context.scene
    sc.frame_set(frame)
    sc.render.filepath = path
    bpy.ops.render.render(write_still=True)

def build_duel(origin_b, yaw=0):
    root = bpy.data.objects.new("Duel", None)
    bpy.context.scene.collection.objects.link(root)
    root.location = origin_b
    root.rotation_euler = (0, 0, math.radians(yaw))
    for p in rig.DUEL:
        box("Duel_" + p["name"], p["size"], to_b(p["pos"]), p["color"], p["mat"], p["shape"], parent=root, rotm=rot_b(p["rot"]))
    return root

if __name__ == "__main__":
    do_render = "--render" in sys.argv
    reset()
    setup_world(samples=int(os.environ.get("SAMPLES", "40")))
    # line-up: rivals stand along X, facing the camera (blender +Y = roblox -Z)
    rigs = {}
    n = len(rig.RIVALS)
    for i, r in enumerate(rig.RIVALS):
        x = -(i - (n - 1) / 2) * 4.8
        rigs[r["id"]] = build_rival(r, Vector((x, 0, 3 * r["scale"])))
    export_rig = rigs["PawnPete"]
    for nme in ANIMS:
        pass
    # key every anim on the export rig at frame 1 one at a time and read back
    data_anims = []
    sc = bpy.context.scene
    for nme in ANIMS:
        for o in export_rig.values():
            o.animation_data_clear()
        key_anim(export_rig, nme)
        data_anims.append(export_anim(export_rig, nme))
    for o in export_rig.values():
        o.animation_data_clear()
    export_json(os.path.join(OUT, "rivals.json"), export_rig) if False else None
    data = dict(order=rig.ORDER, limbs={k: dict(size=v[0], center=v[1], parent=v[2], motor=v[3], joint=v[4]) for k, v in rig.LIMBS.items()},
                rivals=[dict(id=r["id"], display=r["display"], stage=r["stage"], scale=r["scale"], colors=rig.limb_colors(r["outfit"]), extras=r["extras"]) for r in rig.RIVALS],
                duel=rig.DUEL, anchors=rig.ANCHORS, anims=data_anims, hipHeight=rig.HIP_HEIGHT)
    with open(os.path.join(OUT, "rivals.json"), "w") as f:
        json.dump(data, f, indent=1)
    print("wrote rivals.json")
    if do_render:
        which = os.environ.get("SHOT", "lineup")
        if which == "lineup":
            for r in rig.RIVALS:
                key_anim(rigs[r["id"]], "Idle")
            camera((0, 40, 9), (0, 0, 3.4), lens=40)
            render(os.path.join(PREV, "rivals_lineup.png"), 1)
        elif which == "duel":
            for o in bpy.data.objects:
                if any(o.name.startswith(r["id"]) for r in rig.RIVALS) and not o.name.startswith(("PawnPete", "GrandmasterOrion")):
                    o.hide_render = True
            build_duel(Vector((0, 20, 0)))
            pp, go = rigs["PawnPete"], rigs["GrandmasterOrion"]
            # player side (rbx -Z => blender +Y side of the table is rbx -Z?) put Pete at blender y=20+4.2 facing -Y, Orion at y=20-4.2 facing +Y
            hrp_p, hrp_o = pp["HumanoidRootPart"], go["HumanoidRootPart"]
            hrp_p.location = Vector((0, 20 - 4.4, 3.0))                      # SeatA (player side)
            hrp_o.location = Vector((0, 20 + 4.6, 3.0 * 1.3)); hrp_o.rotation_quaternion = Quaternion((0, 0, 1), math.radians(180))  # SeatB
            key_anim(pp, "Tap"); key_anim(go, "Tap", start_frame=-4, scale=1.3)
            camera((-17, 20 - 14, 10), (0.5, 20, 3.6), lens=40)
            render(os.path.join(PREV, "duel_tap.png"), int(os.environ.get("FRAME", "3")))
        elif which.startswith("anim:"):
            nme = which.split(":")[1]
            for o in bpy.data.objects:
                if any(o.name.startswith(r["id"]) for r in rig.RIVALS) and not o.name.startswith("KnightNadia"):
                    o.hide_render = True
            k = rigs["KnightNadia"]
            k["HumanoidRootPart"].location = Vector((0, 0, 3))
            key_anim(k, nme)
            camera((9, 11, 5.5), (0, 0, 3.2), lens=45)
            frames = [1 + round(t * FPS) for t, _p, _e in ANIMS[nme]["keys"]]
            sc.render.resolution_x, sc.render.resolution_y = 480, 600
            for i, fr in enumerate(frames):
                render(os.path.join(PREV, f"_anim_{nme}_{i}.png"), fr)
