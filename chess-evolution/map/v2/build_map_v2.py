# +1 Chess Evolution hub map v2 — Blender build (map only).
# Run in Blender:  exec(open(".../build_map_v2.py").read()); build(); render_all()
# 1 unit = 1 stud. Spawn at origin, lane along +Y, Terrace A at -X, Terrace B at +X, water behind spawn.
# Rerunnable: build() starts a fresh file and saves ChessMap_v2.blend next to this script.
import bpy, bmesh, math, random, os
from mathutils import Vector

HERE = "/Users/Alex/ROBLOX/chess-evolution/map/v2/"

# ---------------------------------------------------------------- sizes (studs) ---
PATH_W = 12                 # main and cross path width (ref: ~2.4 avatar heights)
HUB_X, HUB_Y0, HUB_Y1 = 64, -60, 60      # hub interior: X -64..64, Y -60..60
LANE_HALF, LANE_Y0 = 14, 60              # lane interior X -14..14 (ref: lane ~1.5x wall height)
BAY_PITCH, BAYS = 40, 14
LANE_Y1 = LANE_Y0 + BAY_PITCH * BAYS     # 620
WALL_H, SHELF_D, WALL2_H = 18, 10, 30    # wall, grass shelf depth, second step height
SEG = 8                                   # wall section length
WATER = (-24, 8, -76, -60)               # recess x0, x1, y0, y1

COL = {  # sRGB hex, tuned to the screenshots' lit colours
    "grass": "6BEF3C", "grass_cap": "7AF54A", "path": "EE8C2E", "spawn": "A9B2B6",
    "wall_face": "F06A2C", "wall_band": "8A3A22", "wall_skirt": "8F999E",
    "stone": "B3BDC1", "stone_dark": "97A2A7", "stone_low": "A6B0B4",
    "lane": "B8BFC3", "kerb": "A1A9AD", "lime": "7DF03A", "red": "E8333A", "charcoal": "3A3E46",
    "yellow": "F6C928", "magenta": "E23AE6", "water": "56D3F7", "water_bed": "2E7FC4",
    "rock": "8C9297", "rail": "9C5A2C", "trunk": "C9612C", "birch": "ECE7DA",
    "leaf": "62DF38", "leaf2": "4ECB2E", "bush": "7AE64A", "sprig": "58D232",
    "portal_shell": "4A3FE0", "portal_inner": "FF4FD3",
}
STAGE_COL = ["B0B6BE", "50C846", "326EEB", "E63CC8", "FAC828", "F58228", "E13237",
             "9646E6", "28C8D2", "8CE646", "5A78FF", "FFAA3C", "BE5AFF", "FFD750"]

def lin(h):
    h = h.lstrip("#"); c = [int(h[i:i+2], 16) / 255 for i in (0, 2, 4)]
    return tuple(x / 12.92 if x <= 0.04045 else ((x + 0.055) / 1.055) ** 2.4 for x in c)

# ---------------------------------------------------------------- materials ---
def stud_image():
    """One stud per tile, used as a colour multiplier and a bump: the shared stud grid."""
    name = "StudTile"
    if name in bpy.data.images: return bpy.data.images[name]
    n = 64; img = bpy.data.images.new(name, n, n, alpha=False)
    px = []
    for j in range(n):
        for i in range(n):
            x, y = (i + 0.5) / n - 0.5, (j + 0.5) / n - 0.5
            r = math.hypot(x, y)
            v = 0.93                                    # flat plate
            if r < 0.30: v = 1.0 + 0.10 * (y + x)       # stud top, lit from top-left
            elif r < 0.34: v = 0.74                     # stud rim shadow
            if abs(x) > 0.47 or abs(y) > 0.47: v = 0.86  # faint tile seam
            px += [v, v, v, 1.0]
    img.pixels = px; img.pack()
    return img

MATS = {}
def mat(key, studs=True, alpha=1.0, emit=0.0, rough=0.55):
    k = (key, studs, alpha)
    if k in MATS: return MATS[k]
    hexc = COL.get(key, key)
    m = bpy.data.materials.new(f"M_{key}{'' if studs else '_flat'}")
    m.use_nodes = True; nt = m.node_tree; N = nt.nodes; L = nt.links
    b = N["Principled BSDF"]; rgb = (*lin(hexc), 1)
    b.inputs["Roughness"].default_value = rough
    if studs:
        geo = N.new("ShaderNodeNewGeometry")
        tex = N.new("ShaderNodeTexImage"); tex.image = stud_image(); tex.projection = 'BOX'; tex.projection_blend = 0.0
        tex.interpolation = 'Linear'
        L.new(geo.outputs["Position"], tex.inputs["Vector"])   # world grid: studs line up across every block
        mix = N.new("ShaderNodeMix"); mix.data_type = 'RGBA'; mix.blend_type = 'MULTIPLY'
        mix.inputs["Factor"].default_value = 1.0
        mix.inputs[6].default_value = rgb
        L.new(tex.outputs["Color"], mix.inputs[7]); L.new(mix.outputs[2], b.inputs["Base Color"])
        bump = N.new("ShaderNodeBump"); bump.inputs["Strength"].default_value = 0.35; bump.inputs["Distance"].default_value = 0.05
        L.new(tex.outputs["Color"], bump.inputs["Height"]); L.new(bump.outputs["Normal"], b.inputs["Normal"])
    else:
        b.inputs["Base Color"].default_value = rgb
    if alpha < 1:
        b.inputs["Alpha"].default_value = alpha
        try: m.surface_render_method = 'BLENDED'
        except Exception: m.blend_method = 'BLEND'
    if key.startswith("wall_"): emit = max(emit, 0.3)   # screenshot walls stay bright orange even in shadow
    if emit:
        b.inputs["Emission Color"].default_value = rgb; b.inputs["Emission Strength"].default_value = emit
    # section fill: inside faces (seen only when a camera cuts through a block) render flat dark grey
    out = N["Material Output"]; geo2 = N.new("ShaderNodeNewGeometry"); fill = N.new("ShaderNodeEmission")
    fill.inputs["Color"].default_value = (*lin("4A4F57"), 1); ms = N.new("ShaderNodeMixShader")
    L.new(geo2.outputs["Backfacing"], ms.inputs[0]); L.new(b.outputs[0], ms.inputs[1]); L.new(fill.outputs[0], ms.inputs[2])
    L.new(ms.outputs[0], out.inputs["Surface"])
    m.diffuse_color = (*rgb[:3], alpha)
    MATS[k] = m
    return m

# ---------------------------------------------------------------- geometry helpers ---
COLLS = {}
def coll(name, parent=None, hide=False):
    if name in COLLS: return COLLS[name]
    c = bpy.data.collections.new(name)
    (parent or bpy.context.scene.collection).children.link(c)
    if hide: c.hide_render = True; c.hide_viewport = True
    COLLS[name] = c
    return c

def _obj(c, name, verts, faces, m):
    me = bpy.data.meshes.new(name); me.from_pydata(verts, [], faces); me.update()
    ob = bpy.data.objects.new(name, me); ob.data.materials.append(m); c.objects.link(ob)
    return ob

def box(c, name, x0, x1, y0, y1, z0, z1, m):
    v = [(x0,y0,z0),(x1,y0,z0),(x1,y1,z0),(x0,y1,z0),(x0,y0,z1),(x1,y0,z1),(x1,y1,z1),(x0,y1,z1)]
    f = [(0,3,2,1),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)]
    return _obj(c, name, v, f, m)

def wedge(c, name, x0, x1, y0, y1, z0, z1, m, high):
    """Ramp block: top slopes from z1 on the `high` side ('+x','-x','+y','-y') to z0 on the other."""
    def top(x, y):
        return {"+x": x == x1, "-x": x == x0, "+y": y == y1, "-y": y == y0}[high]
    pts = [(x0,y0),(x1,y0),(x1,y1),(x0,y1)]
    v = [(x, y, z0) for x, y in pts]
    for x, y in pts:
        v.append((x, y, z1 if top(x, y) else z0 + 0.001))
    f = [(0,3,2,1),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)]
    return _obj(c, name, v, f, m)

def col_box(name, x0, x1, y0, y1, z0, z1):
    return box(coll("COLLISION", hide=True), "COL_" + name, x0, x1, y0, y1, z0, z1, mat("stone", studs=False))

def instance(c, src, name, loc, rot_z=0.0, scale=1.0):
    ob = bpy.data.objects.new(name, None); ob.instance_type = 'COLLECTION'; ob.instance_collection = src
    ob.location = loc; ob.rotation_euler = (0, 0, math.radians(rot_z)); ob.scale = (scale,) * 3
    ob.empty_display_size = 2; c.objects.link(ob)
    return ob

# ---------------------------------------------------------------- reusable modules ---
def module_wall():
    """Straight wall section at its own origin: runs +X from 0..SEG, face at y=0 looking -Y, land toward +Y.
    Grey skirt, dark-rust base band, orange studded face, thin green cap, a 10-stud grass shelf, second step."""
    c = coll("Module_Wall", coll("MODULES"))
    L = SEG; T = 6                                     # wall thickness
    box(c, "Skirt", 0, L, -0.6, 0, 0, 1.0, mat("wall_skirt"))
    box(c, "Band", 0, L, -0.3, 0, 1.0, 2.6, mat("wall_band"))
    box(c, "Face", 0, L, 0, T, 0, WALL_H - 0.6, mat("wall_face"))
    box(c, "Cap", 0, L, -0.4, T, WALL_H - 0.6, WALL_H, mat("grass_cap"))
    box(c, "ShelfFill", 0, L, T, T + SHELF_D, 0, WALL_H - 0.6, mat("wall_face"))
    box(c, "Shelf", 0, L, T, T + SHELF_D, WALL_H - 0.6, WALL_H, mat("grass"))
    y2 = T + SHELF_D
    box(c, "Band2", 0, L, y2 - 0.3, y2, WALL_H, WALL_H + 1.4, mat("wall_band"))
    box(c, "Face2", 0, L, y2, y2 + T, WALL_H, WALL2_H - 0.6, mat("wall_face"))
    box(c, "Cap2", 0, L, y2 - 0.4, y2 + T + 8, WALL2_H - 0.6, WALL2_H, mat("grass_cap"))
    box(c, "Fill2", 0, L, y2 + T, y2 + T + 8, 0, WALL2_H - 0.6, mat("wall_face"))
    return c

def module_bay():
    """One stage bay at its own origin (module start at y=0, lane centre x=0), facing +Y."""
    c = coll("Module_StageBay", coll("MODULES"))
    h = LANE_HALF
    box(c, "Floor", -h, h, 0, BAY_PITCH, -1, 0.3, mat("lane"))
    box(c, "KerbL", -h, -h + 1.5, 0, BAY_PITCH, 0.3, 0.8, mat("kerb"))
    box(c, "KerbR", h - 1.5, h, 0, BAY_PITCH, 0.3, 0.8, mat("kerb"))
    box(c, "Divider", -h + 1.5, h - 1.5, 0, 1.2, 0.3, 0.45, mat("lime"))       # thin lime strip at the boundary
    box(c, "RedMat", 0.5, 12.5, 11, 27, 0.3, 0.6, mat("red"))                    # right of centre
    box(c, "Plate1", 9.5, 12.0, 14, 16.5, 0.6, 0.85, mat("charcoal"))           # two plates on its right side
    box(c, "Plate2", 9.5, 12.0, 19, 21.5, 0.6, 0.85, mat("charcoal"))
    box(c, "PadYellow", -11.5, -6.5, 13, 17, 0.3, 0.7, mat("yellow"))            # yellow, then magenta
    box(c, "PadMagenta", -11.5, -6.5, 21, 25, 0.3, 0.7, mat("magenta"))
    return c

def stage_frame(c, i, y):
    """Square coloured frame at a bay boundary: posts tight to the sides, thin crossbar. Separate object per stage."""
    m = mat(STAGE_COL[i], studs=False, rough=0.4)
    h = LANE_HALF - 1.5; t = 0.9; H = 15
    boxes = [(-h, -h + t, y, y + t, 0.8, H), (h - t, h, y, y + t, 0.8, H), (-h, h, y, y + t, H - 0.7, H)]
    v, f = [], []
    for (x0, x1, y0, y1, z0, z1) in boxes:          # one mesh per frame
        o = len(v)
        v += [(x0,y0,z0),(x1,y0,z0),(x1,y1,z0),(x0,y1,z0),(x0,y0,z1),(x1,y0,z1),(x1,y1,z1),(x0,y1,z1)]
        f += [tuple(o + k for k in q) for q in ((0,3,2,1),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7))]
    return _obj(c, f"Stage{i+1:02d}_Frame", v, f, m)

def module_trees():
    """Three reusable trees at their own origins: stepped canopy, offset boxes, pale trunk."""
    root = coll("MODULES")
    t1 = coll("Tree_Stepped", root)
    box(t1, "Trunk", -1, 1, -1, 1, 0, 7, mat("trunk"))
    for dx, dy in ((1.5, 0), (-1.5, 0), (0, 1.5), (0, -1.5)):              # root flares
        box(t1, "Root", -1 + dx, 1 + dx, -1 + dy, 1 + dy, 0, 0.8, mat("trunk"))
    for k, (w, z) in enumerate(((11, 6), (8, 9), (5, 12), (2.5, 15))):
        box(t1, f"Canopy{k}", -w/2, w/2, -w/2, w/2, z, z + 3, mat("leaf"))
    t2 = coll("Tree_OffsetBox", root)
    box(t2, "Trunk", -1, 1, -1, 1, 0, 9, mat("trunk"))
    box(t2, "Canopy0", -4, 6, -4, 5, 7, 13, mat("leaf"))
    box(t2, "Canopy1", -6, 1, -3, 4, 11, 16, mat("leaf2"))
    box(t2, "Canopy2", -1, 4, -2, 3, 15, 18, mat("leaf"))
    t3 = coll("Tree_PaleTrunk", root)
    box(t3, "Trunk", -0.8, 0.8, -0.8, 0.8, 0, 12, mat("birch"))
    box(t3, "Canopy0", -4, 4, -4, 4, 9, 14, mat("leaf2"))
    box(t3, "Canopy1", -2.5, 2.5, -2.5, 2.5, 14, 17, mat("leaf"))
    return [t1, t2, t3]

# ---------------------------------------------------------------- the map ---
def build_hub():
    c = coll("Hub")
    box(c, "HubGrass", -HUB_X, HUB_X, HUB_Y0, HUB_Y1, -1, 0, mat("grass"))
    # orange cross path, flush (0.15 proud): main path from the water recess straight into the lane
    box(c, "PathMain", -PATH_W/2, PATH_W/2, HUB_Y0, HUB_Y1, 0, 0.15, mat("path"))
    box(c, "PathCross", -24, 24, -PATH_W/2, PATH_W/2, 0, 0.15, mat("path"))
    box(c, "Spawn", -4, 4, -4, 4, 0.15, 0.4, mat("spawn"))
    col_box("HubFloor", -HUB_X, HUB_X, HUB_Y0, HUB_Y1, -1, 0.15)

def build_terrace_a():
    """Ref terraceA_closeup: wide lower apron, raised rear shelf against the left wall, two broad inset ramps."""
    c = coll("Terrace_A"); S, SD, SL = mat("stone"), mat("stone_dark"), mat("stone_low")
    y0, y1 = -34, 34
    box(c, "ShelfBack", -64, -56, y0, y1, 0, 5, S)
    for a, b in ((y0, -18), (-8, 8), (18, y1)):
        box(c, "ShelfFront", -56, -48, a, b, 0, 5, S)
    for a, b in ((-18, -8), (8, 18)):
        wedge(c, "InsetRamp", -56, -48, a, b, 1.2, 5, SD, "-x")       # rises toward the shelf
    box(c, "Apron", -48, -26, y0, y1, 0, 1.2, SL)
    box(c, "Lip", -26, -24, y0, y1, 0, 0.6, SD)
    wedge(c, "EndSlope", -48, -24, y0 - 4, y0, 0, 1.2, SD, "+y")
    wedge(c, "EndSlope", -48, -24, y1, y1 + 4, 0, 1.2, SD, "-y")
    col_box("TerraceA_Shelf", -64, -48, y0, y1, 0, 5); col_box("TerraceA_Apron", -48, -24, y0, y1, 0, 1.2)

def build_terrace_b():
    """Ref terraceB_closeup: long raised rear shelf, rim, wide lower central floor sunk ~2.5 with two end ramps,
    big sloped outer ends, a step down to the grass at the front."""
    c = coll("Terrace_B"); S, SD, SL = mat("stone"), mat("stone_dark"), mat("stone_low")
    y0, y1 = -32, 32; RIM, SHELF, FLOOR = 3.0, 4.2, 0.5
    box(c, "RearShelf", 50, 64, y0, y1, 0, SHELF, S)
    box(c, "RimFront", 26, 30, y0, y1, 0, RIM, S)
    box(c, "RimBack", 46, 50, y0, y1, 0, RIM, S)
    box(c, "RimEnd", 30, 46, y0, -26, 0, RIM, S); box(c, "RimEnd", 30, 46, 26, y1, 0, RIM, S)
    box(c, "CentralFloor", 30, 46, -20, 20, 0, FLOOR, SL)
    wedge(c, "EndRamp", 30, 46, -26, -20, FLOOR, RIM, SD, "-y")
    wedge(c, "EndRamp", 30, 46, 20, 26, FLOOR, RIM, SD, "+y")
    box(c, "Step", 24, 26, y0, y1, 0, 1.5, SD)
    wedge(c, "EndSlope", 24, 64, y0 - 7, y0, 0, RIM, SD, "+y")
    wedge(c, "EndSlope", 24, 64, y1, y1 + 7, 0, RIM, SD, "-y")
    col_box("TerraceB_Shelf", 50, 64, y0, y1, 0, SHELF); col_box("TerraceB_Floor", 24, 50, y0, y1, 0, FLOOR)

def build_water():
    c = coll("Water"); x0, x1, y0, y1 = WATER
    box(c, "Bed", x0, x1, y0, y1 + 0.5, -3.5, -3, mat("water_bed", studs=False))
    box(c, "WaterSurface", x0, x1, y0, y1 + 0.5, -3, -0.5, mat("water", studs=False, alpha=0.8, emit=0.15, rough=0.1))
    for (cx, cy, s) in ((-14, -70, 1.0), (1, -67, 0.6)):                  # grey stepped rocks
        for k, (w, z) in enumerate(((8, 0.6), (6, 1.8), (4, 3.0), (2, 4.0))):
            w *= s
            box(c, f"Rock{k}", cx - w/2, cx + w/2, cy - w/2, cy + w/2, -3, z * s + 0.2, mat("rock"))
    for xa, xb in ((-22, -9), (9, 7.5)):                                    # short brown rails at the edge
        if xa > xb: continue
        box(c, "Rail", xa, xb, -59.8, -59.4, 1.8, 2.3, mat("rail"))
        for x in (xa, (xa + xb) / 2, xb):
            box(c, "RailPost", x - 0.4, x + 0.4, -60, -59.2, 0, 2.6, mat("rail"))
    for x in (-7, 7):
        box(c, "PathPost", x - 0.4, x + 0.4, -60, -59.2, 0, 2.6, mat("rail"))
    col_box("WaterEdge", x0, x1, y0, y1, -3, 0)   # simple floor so nobody falls through

def build_portal():
    """Blue-violet portal shell on the left grass near the lane mouth, facing the path (+X). Shell only."""
    c = coll("Portal"); m, inner = mat("portal_shell"), mat("portal_inner", studs=False, emit=0.6)
    cx, cy = -17, 48
    box(c, "Base", cx - 2, cx + 2, cy - 6, cy + 6, 0, 0.6, m)
    box(c, "PillarL", cx - 1.5, cx + 1.5, cy - 5, cy - 3.5, 0.6, 8.5, m)
    box(c, "PillarR", cx - 1.5, cx + 1.5, cy + 3.5, cy + 5, 0.6, 8.5, m)
    box(c, "ArchL", cx - 1.5, cx + 1.5, cy - 4.5, cy - 2.5, 8.5, 10, m)
    box(c, "ArchR", cx - 1.5, cx + 1.5, cy + 2.5, cy + 4.5, 8.5, 10, m)
    box(c, "ArchTop", cx - 1.5, cx + 1.5, cy - 3, cy + 3, 10, 11.3, m)
    box(c, "Inner", cx - 0.3, cx + 0.3, cy - 3.5, cy + 3.5, 0.6, 10, inner)
    col_box("Portal", cx - 1.5, cx + 1.5, cy - 5, cy + 5, 0, 11.3)

def build_lane(bay):
    c = coll("Lane"); f = coll("Stage_Frames")
    for i in range(BAYS):
        y = LANE_Y0 + i * BAY_PITCH
        instance(c, bay, f"Bay{i+1:02d}", (0, y, 0))
        stage_frame(f, i, y + 1.2)
    col_box("LaneFloor", -LANE_HALF, LANE_HALF, LANE_Y0, LANE_Y1, -1, 0.3)

def build_walls(wall):
    c = coll("Walls"); n = [0]
    def run(x, y, rot, count):
        dx, dy = round(math.cos(math.radians(rot))), round(math.sin(math.radians(rot)))
        for k in range(count):
            n[0] += 1; instance(c, wall, f"Wall{n[0]:03d}", (x + dx * SEG * k, y + dy * SEG * k, 0), rot)
    x0, x1, y0, y1 = WATER
    # rot 90 faces +X and runs +Y; -90 faces -X and runs -Y; 0 faces -Y and runs +X; 180 faces +Y and runs -X
    run(-HUB_X, HUB_Y0, 90, (HUB_Y1 - HUB_Y0) // SEG)             # left hub wall
    run(HUB_X, HUB_Y1, -90, (HUB_Y1 - HUB_Y0) // SEG)             # right hub wall
    kf = -(-(HUB_X - LANE_HALF) // SEG)                            # sections needed, rounded up
    run(-LANE_HALF - kf * SEG, HUB_Y1, 0, kf)                     # front wall, left of the lane mouth
    run(LANE_HALF, HUB_Y1, 0, kf)                                 # front wall, right of the lane mouth
    run(x0, HUB_Y0, 180, (x0 + HUB_X) // SEG)                     # rear wall, left of the water
    run(HUB_X, HUB_Y0, 180, (HUB_X - x1) // SEG)                  # rear wall, right of the water
    run(x0, y0, 90, (y1 - y0) // SEG)                             # water recess sides and back
    run(x1, y1, -90, (y1 - y0) // SEG)
    run(x1, y0, 180, (x1 - x0) // SEG)
    run(-LANE_HALF, LANE_Y0, 90, (LANE_Y1 - LANE_Y0) // SEG)      # lane walls
    run(LANE_HALF, LANE_Y1, -90, (LANE_Y1 - LANE_Y0) // SEG)
    run(-LANE_HALF - 2, LANE_Y1, 0, -(-(2 * LANE_HALF + 4) // SEG))  # lane end
    # flat upper land beyond the second step
    D = 6 + SHELF_D + 6 + 8
    G, F = mat("grass"), mat("wall_face")
    for (a, b, cc, d) in ((-260, -HUB_X - D, -160, LANE_Y1 + 80), (HUB_X + D, 260, -160, LANE_Y1 + 80),
                          (-HUB_X - D, -LANE_HALF - D, HUB_Y1 + D, LANE_Y1 + 80), (LANE_HALF + D, HUB_X + D, HUB_Y1 + D, LANE_Y1 + 80),
                          (-HUB_X - D, HUB_X + D, -160, HUB_Y0 - D), (-HUB_X - D, -HUB_X, HUB_Y0 - D, HUB_Y0), (HUB_X, HUB_X + D, HUB_Y0 - D, HUB_Y0), (-HUB_X - D, -HUB_X, HUB_Y1, HUB_Y1 + D), (HUB_X, HUB_X + D, HUB_Y1, HUB_Y1 + D), (-LANE_HALF - D, LANE_HALF + D, LANE_Y1 + D, LANE_Y1 + 80)):
        box(c, "Land", a, b, cc, d, 0, WALL2_H - 0.6, F)
        box(c, "LandTop", a, b, cc, d, WALL2_H - 0.6, WALL2_H, G)
    for nm, a, b, cc, d in (("WallL", -HUB_X - 6, -HUB_X, HUB_Y0, HUB_Y1), ("WallR", HUB_X, HUB_X + 6, HUB_Y0, HUB_Y1),
                            ("LaneL", -LANE_HALF - 6, -LANE_HALF, LANE_Y0, LANE_Y1), ("LaneR", LANE_HALF, LANE_HALF + 6, LANE_Y0, LANE_Y1)):
        col_box(nm, a, b, cc, d, 0, WALL_H)

def build_foliage(trees):
    c = coll("Foliage"); rnd = random.Random(8)
    D1 = 6 + SHELF_D / 2            # shelf centre line, measured from a wall face
    spots = []
    for y in range(HUB_Y0 + 6, HUB_Y1, 16):  spots += [(-HUB_X - D1, y, WALL_H), (HUB_X + D1, y, WALL_H)]
    for x in range(-HUB_X + 6, -LANE_HALF - 4, 16): spots.append((x, HUB_Y1 + D1, WALL_H))
    for x in range(LANE_HALF + 8, HUB_X, 16):       spots.append((x, HUB_Y1 + D1, WALL_H))
    for x in range(-HUB_X + 6, HUB_X, 16):
        if not (WATER[0] - 4 < x < WATER[1] + 4): spots.append((x, HUB_Y0 - D1, WALL_H))
    for y in range(LANE_Y0 + 8, LANE_Y1, 18):       spots += [(-LANE_HALF - D1, y, WALL_H), (LANE_HALF + D1, y, WALL_H)]
    for y in range(HUB_Y0 - 20, LANE_Y1, 26):       # second row on the upper land
        spots += [(-HUB_X - 34 if y < HUB_Y1 + 20 else -LANE_HALF - 34, y + 9, WALL2_H),
                  (HUB_X + 34 if y < HUB_Y1 + 20 else LANE_HALF + 34, y, WALL2_H)]
    # a few inside the four grass pockets, clear of paths and terraces
    spots += [(-14, -48, 0), (16, -50, 0), (-20, 22, 0), (19, 46, 0)]
    for k, (x, y, z) in enumerate(spots):
        t = trees[k % 3] if k % 7 else trees[2]
        instance(c, t, f"Tree{k:03d}", (x + rnd.uniform(-1.5, 1.5), y + rnd.uniform(-2, 2), z),
                 rnd.choice((0, 90, 180, 270)), rnd.uniform(0.85, 1.15))
    B, S, R = mat("bush"), mat("sprig"), mat("rock")
    for (x, y) in ((-12, -30), (14, -26), (-15, 16), (15, 20), (-21, -50), (21, -44), (14, 52)):
        w = rnd.uniform(3, 5); box(c, "Bush", x - w/2, x + w/2, y - w/3, y + w/3, 0, w * 0.55, B)
    for k in range(26):                         # grass sprigs in the pockets
        x = rnd.choice((-1, 1)) * rnd.uniform(9, 22); y = rnd.uniform(-55, 55)
        if abs(y) < 9 or (abs(x) > 22 and abs(y) < 40): continue
        box(c, "Sprig", x - 0.25, x + 0.25, y - 0.25, y + 0.25, 0, rnd.uniform(1.0, 1.8), S)
    for (x, y, w) in ((-18, -40, 2.5), (20, 34, 2), (-60, 44, 3), (58, -48, 2.5)):
        box(c, "RockBlock", x - w/2, x + w/2, y - w/2, y + w/2, 0, w * 0.7, R)

# ---------------------------------------------------------------- scene, light, cameras ---
def setup_scene():
    sc = bpy.context.scene
    sc.render.engine = 'BLENDER_EEVEE_NEXT' if 'BLENDER_EEVEE_NEXT' in [e.identifier for e in bpy.types.RenderSettings.bl_rna.properties['engine'].enum_items] else 'BLENDER_EEVEE'
    sc.view_settings.view_transform = 'Standard'; sc.view_settings.exposure = 0.0
    try: sc.eevee.taa_render_samples = 24
    except Exception: pass
    w = bpy.data.worlds.new("Daylight"); sc.world = w; w.use_nodes = True
    bg = w.node_tree.nodes["Background"]; bg.inputs[0].default_value = (*lin("9CCBFF"), 1); bg.inputs[1].default_value = 1.15
    sun = bpy.data.objects.new("Sun", bpy.data.lights.new("Sun", 'SUN'))
    sun.data.energy = 3.0; sun.data.angle = math.radians(3); sun.data.color = (1.0, 0.97, 0.9)
    sun.rotation_euler = (math.radians(38), math.radians(8), math.radians(-30))
    coll("CAMERAS").objects.link(sun)

def camera(name, loc, look, lens_vfov=70, ortho=None, clip_start=0.1):
    cd = bpy.data.cameras.new(name)
    if ortho: cd.type = 'ORTHO'; cd.ortho_scale = ortho
    else: cd.sensor_fit = 'VERTICAL'; cd.angle = math.radians(lens_vfov)
    cd.clip_start = clip_start; cd.clip_end = 4000
    ob = bpy.data.objects.new(name, cd); coll("CAMERAS").objects.link(ob)
    ob.location = loc; ob.rotation_euler = (Vector(look) - Vector(loc)).to_track_quat('-Z', 'Y').to_euler()
    if name == "CAM_Overhead": ob.rotation_euler = (0, 0, math.radians(90))   # straight down, +Y to the right
    return ob

CAMS = {
    # name: (location, look-at, vfov, ortho scale, clip start)
    "CAM_Overhead":    ((0, 272, 400), (0, 272, 0), None, 720, 0.1),   # lane runs left to right
    "CAM_ThreeQuarter":((52, -64, 72), (-10, 12, 0), 70, None, 0.1),     # ref hub_overview framing
    "CAM_LaneHigh":    ((0, 44, 36), (0, 160, 0), 70, None, 0.1),        # ref lane_view framing
    "CAM_LaneEye":     ((2.5, 66, 5.2), (0, 400, 4), 70, None, 0.1),     # avatar eye height
    "CAM_LaneSection": ((0, 99, 16), (0, 200, 16), None, 100, 1.0),       # orthographic cut through bay 1
    "CAM_TerraceA":    ((-6, 0, 13), (-46, 0, 2.5), 70, None, 0.1),      # ref terraceA_closeup framing
    "CAM_TerraceB":    ((6, 0, 15), (44, 0, 1.5), 70, None, 0.1),        # ref terraceB_closeup framing
}

def build():
    bpy.ops.wm.read_homefile(use_empty=True)
    COLLS.clear(); MATS.clear()
    setup_scene()
    wall, bay, trees = module_wall(), module_bay(), module_trees()
    # modules sit at their own origins; excluded from the view layer so only their instances show
    bpy.context.view_layer.layer_collection.children["MODULES"].exclude = True
    build_hub(); build_terrace_a(); build_terrace_b(); build_water(); build_portal()
    build_lane(bay); build_walls(wall); build_foliage(trees)
    for n, (loc, look, vf, orth, cs) in CAMS.items(): camera(n, loc, look, vf or 70, orth, cs)
    bpy.context.scene.camera = bpy.data.objects["CAM_ThreeQuarter"]
    bpy.ops.wm.save_as_mainfile(filepath=HERE + "ChessMap_v2.blend")
    return len(bpy.data.objects)

def render(cam, out, w=1500, h=860):
    sc = bpy.context.scene; sc.camera = bpy.data.objects[cam]
    sc.render.resolution_x, sc.render.resolution_y = w, h
    sc.render.filepath = out; bpy.ops.render.render(write_still=True)

def render_all(tag="r1"):
    os.makedirs(HERE + "review", exist_ok=True)
    for cam in CAMS:
        render(cam, f"{HERE}review/{tag}_{cam}.png", *((2160, 680) if cam == "CAM_Overhead" else (1500, 860)))
