# +1 Chess Evolution hub map v2 — Blender build (map only).
# Run in Blender:  exec(open(".../build_map_v2.py").read()); build(); render_all()
# 1 unit = 1 stud. Spawn at origin, lane along +Y, Terrace A at -X, Terrace B at +X, water behind spawn.
# Rerunnable: build() starts a fresh file and saves ChessMap_v2.blend next to this script.
import bpy, bmesh, math, random, os
from mathutils import Vector

HERE = "/Users/Alex/ROBLOX/chess-evolution/map/v2/"


# ---------------------------------------------------------------- sizes (studs) ---
# v5: every number below is measured from ref/hub_overview.png through the solved camera
# (analysis/cam_hub_free.json) unless it says "close-up" or "inferred".
MARK = "v6f-even-layout"
EVEN = True   # Alex (Nov 8): "make this even" -> hub mirrored about the main path
SX0, SX1, SY = 30, 87, 48             # even: both stands span |x| 30..87, y -48..48
PATH_W, PATH_EDGE = 11, 1.0              # 9 orange + a 1-stud brown edge each side
SPAWN_HALF = 2.25                        # 4.5-stud pad
HUB_XL, HUB_XR = -90, 90                 # even: same width both sides (reference was -111..66)
HUB_YB, HUB_YF, HUB_YF_R = -74, 74, 74   # water bank, front wall (same both sides of the lane)
BACK_Y = -130                            # far bank behind the water (inferred: off screen)
# water: a channel running at 45 degrees down-left from the end of the main path (bank points solved on hub_overview)
WATER_POLY = [(HUB_XL, -92), (HUB_XR, -92), (HUB_XR, -74), (HUB_XL, -74)]   # even: straight channel across the back
PATH_Y0 = -72                            # main path stops 1 stud short of the water
LANE_XL, LANE_XR, LANE_Y0 = -23, 23, 74  # lane 46 wide, starts at the front wall
BAY_PITCH, BAYS = 56, 14
LANE_Y1 = LANE_Y0 + BAY_PITCH * BAYS     # 858
WALL_T, LEDGE, WALL_H1, WALL_H2 = 4, 10, 11.5, 21   # two-step wall: lower face, grass ledge, upper face to the top land
LEDGE_R, LEDGE_FR = LEDGE, LEDGE               # the ledge is wider behind Terrace B (20) and on the block right of the lane (14)
WALL_D = 2 * WALL_T + LEDGE              # wall depth from face to the upper land
SEG = 8

COL = {  # sRGB hex, measured from lit faces in the screenshots (Nov 8 sample pass)
    "grass": "3FE80A", "grass_cap": "52F218", "path": "FF9410", "spawn": "A9B6BA",
    "wall_face": "CC4A20", "wall_band": "7E2A12", "wall_skirt": "8E9CA1",
    "stone": "ABBCC1", "stone_dark": "8E9EA4", "stone_low": "9EAFB4",
    "lane": "B9C8CB", "kerb": "98A7AB", "lime": "6CFF15", "red": "FF1B3B", "charcoal": "363B44",
    "yellow": "FFCC12", "magenta": "F01EF5", "water": "3CCBFA", "water_bed": "1E6FC4",
    "rock": "8A969B", "rail": "A8501E", "trunk": "D5531F", "birch": "ECE7DA",
    "leaf": "3EE80A", "leaf2": "2ECB04", "bush": "4CF012", "sprig": "38D608",
    "portal_shell": "3A2FF0", "portal_inner": "FF3FD3",
}
COL.update({"path_edge": "A04A1C", "spawn": "C8D8F0", "pad_green": "3EE07A", "pad_cyan": "2FD9F0",
            "pad_red": "FF2B3B", "pad_black": "24222C"})
# gate colours read from lane_view (stage 2 green, 3 blue, 4 magenta, 5 yellow, 6 and 7 orange, 8 red ...)
STAGE_COL = ["B0B6BE", "50C846", "326EEB", "E63CC8", "FAC828", "F58228", "F0602A",
             "E13237", "9646E6", "28C8D2", "8CE646", "5A78FF", "FFAA3C", "BE5AFF"]

def lin(h):
    h = h.lstrip("#"); c = [int(h[i:i+2], 16) / 255 for i in (0, 2, 4)]
    return tuple(x / 12.92 if x <= 0.04045 else ((x + 0.055) / 1.055) ** 2.4 for x in c)

# ---------------------------------------------------------------- materials ---
def stud_image():
    """One square stud per tile, as in the screenshots: flat plate, a raised square lit from the top-left,
    dark edge on its top and left, light edge on its bottom and right. Used as colour multiplier and bump."""
    name = "StudTileSquare"
    if name in bpy.data.images: return bpy.data.images[name]
    n = 64; img = bpy.data.images.new(name, n, n, alpha=False)
    px = []
    for j in range(n):
        for i in range(n):
            x, y = (i + 0.5) / n - 0.5, (j + 0.5) / n - 0.5     # y up in image space
            v = 1.0                                         # flat plate
            a = 0.22; e = 0.045                             # stud half size, edge width
            if abs(x) < a and abs(y) < a:
                v = 1.03
                if y > a - e or x < -a + e: v = 0.70       # top / left edge: shadow line
                elif y < -a + e or x > a - e: v = 1.12     # bottom / right edge: highlight
            if abs(x) > 0.485 or abs(y) > 0.485: v = 0.95  # faint plate seam
            px += [v, v, v, 1.0]
    img.pixels = px; img.pack()
    return img

# per-material tile variation seen in the screenshots: grass checker, cobbled stone tiles, soft lane and wall tiles
VAR = {"grass": ("checker", 4, 0.07), "grass_cap": ("checker", 4, 0.06), "leaf": ("noise", 2, 0.06),
       "leaf2": ("noise", 2, 0.06), "bush": ("noise", 2, 0.05),
       "stone": ("noise", 2, 0.07), "stone_dark": ("noise", 2, 0.07), "stone_low": ("noise", 2, 0.07),
       "lane": ("noise", 4, 0.035), "kerb": ("noise", 2, 0.04), "path": ("noise", 2, 0.04),
       "wall_face": ("noise", 2, 0.045), "trunk": ("noise", 1, 0.05), "rock": ("noise", 1, 0.08)}

def stud_image_mixed():
    """Tree close-up: square studs, about a third of them sunk in (dark hole, light lower lip) instead of raised."""
    name = "StudTileMixed"
    if name in bpy.data.images: return bpy.data.images[name]
    g, n = 8, 32; N = g * n; rnd = random.Random(5)
    sunk = [[rnd.random() < 0.38 for _ in range(g)] for _ in range(g)]
    img = bpy.data.images.new(name, N, N, alpha=False); px = []
    for J in range(N):
        for I in range(N):
            gi, gj = I // n, J // n
            x, y = ((I % n) + 0.5) / n - 0.5, ((J % n) + 0.5) / n - 0.5
            v = 1.0; a = 0.24; e = 0.06
            if abs(x) < a and abs(y) < a:
                if sunk[gj][gi]:
                    v = 0.80                                    # hole floor in soft shadow
                    if y < -a + e or x > a - e: v = 0.92       # lit inner lip
                    if y > a - e or x < -a + e: v = 0.68       # shadow under the top edge
                else:
                    v = 1.03
                    if y > a - e or x < -a + e: v = 0.72
                    elif y < -a + e or x > a - e: v = 1.12
            if abs(x) > 0.485 or abs(y) > 0.485: v = 0.95
            px += [v, v, v, 1.0]
    img.pixels = px; img.pack()
    return img

MIXED = {"leaf", "leaf2", "bush", "trunk", "birch", "sprig"}

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
        tex = N.new("ShaderNodeTexImage"); tex.projection = 'BOX'; tex.projection_blend = 0.0
        tex.interpolation = 'Linear'
        if key in MIXED:                                        # 8x8-stud sheet of raised and sunken studs
            tex.image = stud_image_mixed(); sc8 = N.new("ShaderNodeVectorMath"); sc8.operation = 'SCALE'
            sc8.inputs["Scale"].default_value = 1 / 8; L.new(geo.outputs["Position"], sc8.inputs[0]); L.new(sc8.outputs[0], tex.inputs["Vector"])
        else:
            tex.image = stud_image()
            L.new(geo.outputs["Position"], tex.inputs["Vector"])   # world grid: studs line up across every block
        mix = N.new("ShaderNodeMix"); mix.data_type = 'RGBA'; mix.blend_type = 'MULTIPLY'
        mix.inputs["Factor"].default_value = 1.0
        mix.inputs[6].default_value = rgb
        L.new(tex.outputs["Color"], mix.inputs[7]); col_out = mix.outputs[2]
        if key in VAR:
            kind, cell, amp = VAR[key]
            if kind == "checker":
                add = N.new("ShaderNodeVectorMath"); add.operation = 'ADD'; add.inputs[1].default_value = (0.01, 0.01, 1.0)
                L.new(geo.outputs["Position"], add.inputs[0])
                chk = N.new("ShaderNodeTexChecker"); chk.inputs["Scale"].default_value = 0.5 / cell
                chk.inputs["Color1"].default_value = (1 + amp,) * 3 + (1,); chk.inputs["Color2"].default_value = (1 - amp,) * 3 + (1,)
                L.new(add.outputs[0], chk.inputs["Vector"]); var_out = chk.outputs["Color"]
            else:
                snap = N.new("ShaderNodeVectorMath"); snap.operation = 'SNAP'; snap.inputs[1].default_value = (cell, cell, cell)
                L.new(geo.outputs["Position"], snap.inputs[0])
                wn = N.new("ShaderNodeTexWhiteNoise"); wn.noise_dimensions = '3D'; L.new(snap.outputs[0], wn.inputs["Vector"])
                mr = N.new("ShaderNodeMapRange"); mr.inputs[3].default_value = 1 - amp; mr.inputs[4].default_value = 1 + amp
                L.new(wn.outputs["Value"], mr.inputs[0]); var_out = mr.outputs[0]
            mix2 = N.new("ShaderNodeMix"); mix2.data_type = 'RGBA'; mix2.blend_type = 'MULTIPLY'; mix2.inputs["Factor"].default_value = 1.0
            L.new(col_out, mix2.inputs[6]); L.new(var_out, mix2.inputs[7]); col_out = mix2.outputs[2]
        ao = N.new("ShaderNodeAmbientOcclusion"); ao.inputs["Distance"].default_value = 2.5; ao.samples = 8
        aomr = N.new("ShaderNodeMapRange"); aomr.inputs[3].default_value = 0.62; aomr.inputs[4].default_value = 1.0
        L.new(ao.outputs["AO"], aomr.inputs[0])
        mix3 = N.new("ShaderNodeMix"); mix3.data_type = 'RGBA'; mix3.blend_type = 'MULTIPLY'; mix3.inputs["Factor"].default_value = 1.0
        L.new(col_out, mix3.inputs[6]); L.new(aomr.outputs[0], mix3.inputs[7]); col_out = mix3.outputs[2]
        L.new(col_out, b.inputs["Base Color"])
        bump = N.new("ShaderNodeBump"); bump.inputs["Strength"].default_value = 0.6; bump.inputs["Distance"].default_value = 0.05
        L.new(tex.outputs["Color"], bump.inputs["Height"]); L.new(bump.outputs["Normal"], b.inputs["Normal"])
    else:
        b.inputs["Base Color"].default_value = rgb
    if alpha < 1:
        b.inputs["Alpha"].default_value = alpha
        try: m.surface_render_method = 'BLENDED'
        except Exception: m.blend_method = 'BLEND'
    if key.startswith("wall_"): emit = max(emit, 0.12)   # screenshot walls stay bright orange even in shadow
    if emit:
        b.inputs["Emission Color"].default_value = rgb; b.inputs["Emission Strength"].default_value = emit
    # section fill: inside faces (seen only when a camera cuts through a block) render flat dark grey
    out = N["Material Output"]
    if alpha < 1:                                   # see-through panes: no section fill, or their back faces read dark
        m.diffuse_color = (*rgb[:3], alpha); MATS[k] = m; return m
    geo2 = N.new("ShaderNodeNewGeometry"); fill = N.new("ShaderNodeEmission")
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


# ---------------------------------------------------------------- terrain (walls as a height field) ---
def walk_rects():
    """Everything the player walks on at ground level. The two-step walls wrap around this outline."""
    L = LEDGE   # rect x0, x1, y0, y1, ledge widths for the -x, +x, -y, +y sides
    return [(HUB_XL, HUB_XR, BACK_Y, HUB_YF, (L, L, L, L)),          # hub, water channel and far bank
            (LANE_XL, LANE_XR, HUB_YF - 1, LANE_Y1, (L, L, L, L))]   # lane

def terrain_mesh(c):
    """Two-step walls from a 1-stud height field: within WALL_T of the walk area -> lower face (12.5),
    then the 3-stud ledge (also 12.5), beyond that the upper land (21). Square distance, so outer corners wrap
    and inner corners fill, exactly like stacked Roblox parts. One clean mesh, no hidden faces."""
    rects = walk_rects(); M = 50
    X0 = min(r[0] for r in rects) - M; X1 = max(r[1] for r in rects) + M
    Y0 = min(r[2] for r in rects) - M; Y1 = max(r[3] for r in rects) + M
    nx, ny = X1 - X0, Y1 - Y0
    def level(cx, cy):
        n = 1e9
        for (a, b, e, f, (lx0, lx1, ly0, ly1)) in rects:
            dx = max(a - cx, 0, cx - b); dy = max(e - cy, 0, cy - f)
            if dx == 0 and dy == 0: return 0
            wx = WALL_T + (lx0 if cx < a else lx1); wy = WALL_T + (ly0 if cy < e else ly1)
            n = min(n, max(dx / wx, dy / wy))
        return 1 if n <= 1 else 2
    H = [[level(X0 + i + 0.5, Y0 + j + 0.5) for i in range(nx)] for j in range(ny)]
    hz = (0.0, WALL_H1, WALL_H2)
    bm = bmesh.new(); MF, MC, MG = 0, 1, 2      # material slots: face, cap band, grass top
    def quad(p, slot):
        vs = [bm.verts.new(v) for v in p]; f = bm.faces.new(vs); f.material_index = slot
    # tops: merge row runs
    for j in range(ny):
        i = 0
        while i < nx:
            h = H[j][i]; k = i
            while k < nx and H[j][k] == h: k += 1
            if h > 0:
                z = hz[h]; quad([(X0+i, Y0+j, z), (X0+k, Y0+j, z), (X0+k, Y0+j+1, z), (X0+i, Y0+j+1, z)], MG)
            i = k
    def side(p0, p1, zlo, zhi, outward):
        """vertical face from p0 to p1 (counter-clockwise seen from outside), split into face + 0.6 cap band"""
        zc = zhi - 0.6
        for (a, b, s) in ((zlo, zc, MF), (zc, zhi, MC)):
            quad([(p1[0], p1[1], a), (p0[0], p0[1], a), (p0[0], p0[1], b), (p1[0], p1[1], b)], s)   # normal faces the low side
    # x-boundaries (between column i-1 and i), merged along y
    for i in range(1, nx):
        j = 0
        while j < ny:
            a, b = H[j][i-1], H[j][i]
            if a == b: j += 1; continue
            k = j
            while k < ny and H[k][i-1] == a and H[k][i] == b: k += 1
            x = X0 + i
            if b > a: side((x, Y0+j), (x, Y0+k), hz[a], hz[b], -1)      # high side at +x, face looks -x
            else:     side((x, Y0+k), (x, Y0+j), hz[b], hz[a], +1)
            j = k
    for j in range(1, ny):
        i = 0
        while i < nx:
            a, b = H[j-1][i], H[j][i]
            if a == b: i += 1; continue
            k = i
            while k < nx and H[j-1][k] == a and H[j][k] == b: k += 1
            y = Y0 + j
            if b > a: side((X0+k, y), (X0+i, y), hz[a], hz[b], -1)      # high side at +y, face looks -y
            else:     side((X0+i, y), (X0+k, y), hz[b], hz[a], +1)
            i = k
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=0.001)
    bmesh.ops.dissolve_limit(bm, angle_limit=0.01, verts=bm.verts, edges=bm.edges, delimit={'MATERIAL'})
    me = bpy.data.meshes.new("Terrain"); bm.to_mesh(me); bm.free()
    for k in ("wall_face", "grass_cap", "grass"): me.materials.append(mat(k))
    ob = bpy.data.objects.new("Walls_Terrain", me); c.objects.link(ob)
    return ob

# ---------------------------------------------------------------- reusable modules ---
def module_bay():
    """One stage bay at its own origin (bay start y=0, lane centre x=0), facing +Y. Measured on hub_overview
    and lane_view: big red mat right of centre, two dark plates on its right, yellow then magenta pad on the left,
    a grey curb / lime strip / grey curb divider at the far end."""
    c = coll("Module_StageBay", coll("MODULES"))
    h = (LANE_XR - LANE_XL) / 2; P = BAY_PITCH
    box(c, "Floor", -h, h, 0, P, -1, 0.3, mat("lane"))
    box(c, "KerbL", -h, -h + 1.5, 0, P, 0.3, 0.8, mat("kerb"))
    box(c, "KerbR", h - 1.5, h, 0, P, 0.3, 0.8, mat("kerb"))
    box(c, "RedMat", -4, 18, 9, 39, 0.3, 0.6, mat("red"))
    box(c, "Plate1", 12.5, 16.5, 12, 16, 0.6, 0.85, mat("charcoal"))
    box(c, "Plate2", 12.5, 16.5, 18, 22, 0.6, 0.85, mat("charcoal"))
    box(c, "PadYellow", -20, -11, 6.5, 14, 0.3, 0.7, mat("yellow"))
    box(c, "PadMagenta", -20, -11, 34, 41.5, 0.3, 0.7, mat("magenta"))
    box(c, "CurbA", -h + 1.5, h - 1.5, 52, 53, 0.3, 0.8, mat("kerb"))
    box(c, "Lime", -h + 1.5, h - 1.5, 53, 55, 0.3, 0.55, mat("lime"))
    box(c, "CurbB", -h + 1.5, h - 1.5, 55, 56, 0.3, 0.8, mat("kerb"))
    return c

def stage_gate(c, stage, y):
    """Stage gate over a divider (lane_view): two studded posts, a top bar, a see-through coloured pane."""
    col = STAGE_COL[(stage - 1) % len(STAGE_COL)]; COL.setdefault(col, col)
    m = mat(col); pane = mat(col, studs=False, alpha=0.32, emit=0.25, rough=0.2)
    h = (LANE_XR - LANE_XL) / 2 - 1.5; t = 2.0; Hh = 24
    g = _merge(c, f"Stage{stage:02d}_Gate", [(-h, -h + t, y - 1, y + 1, 0.8, Hh), (h - t, h, y - 1, y + 1, 0.8, Hh),
                                              (-h, h, y - 1, y + 1, Hh - 2, Hh)], m)
    box(c, f"Stage{stage:02d}_Pane", -h + t, h - t, y - 0.15, y + 0.15, 0.8, Hh - 2, pane)
    return g

def _merge(c, name, boxes, m):
    v, f = [], []
    for (x0, x1, y0, y1, z0, z1) in boxes:
        o = len(v)
        v += [(x0,y0,z0),(x1,y0,z0),(x1,y1,z0),(x0,y1,z0),(x0,y0,z1),(x1,y0,z1),(x1,y1,z1),(x0,y1,z1)]
        f += [tuple(o + k for k in q) for q in ((0,3,2,1),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7))]
    return _obj(c, name, v, f, m)

def module_trees():
    """Three reusable trees at their own origins, sized like the screenshots (lane_view, close-ups): a tall stepped
    pine of square slabs, a big offset-cube tree on a leaning trunk with root planks, and a pale-trunk tree."""
    root = coll("MODULES"); T, L1, L2 = mat("trunk"), mat("leaf"), mat("leaf2")
    t1 = coll("Tree_Stepped", root)
    box(t1, "Trunk", -1.5, 1.5, -1.5, 1.5, 0, 9, T)
    for x0, x1, y0, y1 in ((1, 5, -0.8, 0.8), (-5, -1, -0.8, 0.8), (-0.8, 0.8, 1, 5), (-0.8, 0.8, -5, -1)):
        box(t1, "Root", x0, x1, y0, y1, 0, 0.7, T)
    for k, (w, z) in enumerate(((17, 7), (14, 10.5), (11, 14), (8, 17.5), (5, 21), (2.5, 24))):
        box(t1, f"Canopy{k}", -w/2, w/2, -w/2, w/2, z, z + 3, L1 if k % 2 == 0 else L2)
    t2 = coll("Tree_OffsetBox", root); lean = 1.6
    v = [(-1.5,-1.5,0),(1.5,-1.5,0),(1.5,1.5,0),(-1.5,1.5,0),(-1.5+lean,-1.5,11),(1.5+lean,-1.5,11),(1.5+lean,1.5,11),(-1.5+lean,1.5,11)]
    _obj(t2, "Trunk", v, [(0,3,2,1),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)], T)
    for nm, (x0, x1, y0, y1) in (("RootE", (1, 5.5, -1, 0.6)), ("RootW", (-5, -1, -0.4, 1.2)),
                                 ("RootN", (-0.8, 0.8, 1, 5)), ("RootS", (-0.4, 1.2, -5.5, -1))):
        box(t2, nm, x0, x1, y0, y1, 0, 0.7, T)
    box(t2, "Branch", 3, 6, -1, 1, 8, 10, T)
    box(t2, "Canopy0", -6, 7, -6, 6, 9, 17, L1); box(t2, "Canopy1", -8, 0, -4, 5, 14, 21, L2)
    box(t2, "Canopy2", 2, 9, -3, 4, 16, 20, L2); box(t2, "Canopy3", -3, 4, -3, 3, 20, 24, L1)
    t3 = coll("Tree_PaleTrunk", root)
    box(t3, "Trunk", -1.2, 1.2, -1.2, 1.2, 0, 15, mat("birch"))
    box(t3, "Canopy0", -6, 6, -6, 6, 12, 18, L2); box(t3, "Canopy1", -4, 4, -4, 4, 18, 22, L1)
    box(t3, "Canopy2", -2, 2, -2, 2, 22, 24, L2)
    return [t1, t2, t3]

# ---------------------------------------------------------------- the map ---
def prism(c, name, pts, z0, z1, m):
    """Upright prism over a convex polygon (any winding)."""
    area = sum(pts[i][0] * pts[i-1][1] - pts[i-1][0] * pts[i][1] for i in range(len(pts)))
    if area > 0: pts = pts[::-1]                      # make it clockwise seen from above
    n = len(pts); v = [(x, y, z0) for x, y in pts] + [(x, y, z1) for x, y in pts]
    f = [tuple(range(n)), tuple(range(2 * n - 1, n - 1, -1))]
    f += [(i, (i + 1) % n + 0, (i + 1) % n + n, i + n)[::-1] for i in range(n)]
    return _obj(c, name, v, f, m)

def carve(ob, cutter):
    """Boolean-subtract cutter from ob and bake the result into ob's mesh."""
    md = ob.modifiers.new("Carve", 'BOOLEAN'); md.operation = 'DIFFERENCE'; md.object = cutter; md.solver = 'EXACT'
    dg = bpy.context.evaluated_depsgraph_get(); dg.update()
    me = bpy.data.meshes.new_from_object(ob.evaluated_get(dg))
    ob.modifiers.remove(md); old = ob.data; ob.data = me; bpy.data.meshes.remove(old)
    bpy.data.objects.remove(cutter)

def build_hub():
    c = coll("Hub"); G = mat("grass")
    wy0, wy1 = WATER_POLY[0][1], WATER_POLY[2][1]          # straight channel: grass in three slabs, banks are grass
    box(c, "HubGrass", HUB_XL, HUB_XR, wy1, HUB_YF, -4, 0, G)
    box(c, "FarBank", HUB_XL, HUB_XR, BACK_Y, wy0, -4, 0, G)
    box(c, "ChannelFloor", HUB_XL, HUB_XR, wy0, wy1, -4.6, -4.4, G)
    # orange paths with a 1-stud brown edge, flush with the grass
    hw = PATH_W / 2; e = PATH_EDGE; P, E = mat("path"), mat("path_edge")
    box(c, "PathMainEdge", -hw, hw, PATH_Y0, HUB_YF, -0.2, 0.14, E)
    box(c, "PathMain", -hw + e, hw - e, PATH_Y0, HUB_YF, -0.2, 0.16, P)
    box(c, "PathCrossEdge", -SX0, SX0, -hw, hw, -0.2, 0.14, E)
    box(c, "PathCross", -SX0, SX0, -hw + e, hw - e, -0.2, 0.16, P)
    box(c, "PathCrossing", -hw + e, hw - e, -hw, hw, -0.2, 0.161, P)      # no edge across the crossing
    box(c, "Spawn", -SPAWN_HALF, SPAWN_HALF, -SPAWN_HALF, SPAWN_HALF, 0.16, 0.4, mat("spawn"))
    col_box("HubFloor", HUB_XL, HUB_XR, BACK_Y, HUB_YF, -4, 0.15)

def build_terrace_a():
    """Treadmill stand on the left, rebuilt from terraceA_closeup + hub_overview (Alex, Nov 8: "same as the reference").
    One flat stone floor 1.5 above the grass with a chamfered edge on the three open sides and a dark kerb at the wall.
    Back row against the wall: four machine spots on the floor. Middle row: three sunken pits with sloped ends
    (empty, the wide one the two red treadmills stand in, empty), with the yellow and blue spots on the floor at
    either end. Front: an open apron where the cross path arrives. Ref footprint x -110..-32, y -46..58, scaled to the
    even footprint |x| 30..87, y -48..48 (x * 0.73, y * 0.92). Machines themselves are not built (map only)."""
    c = coll("Terrace_A"); S, SD, SL = mat("stone"), mat("stone_dark"), mat("stone_low")
    x0, x1, y0, y1 = -SX1, -SX0, -SY, SY; F, PIT, CH = 1.5, 0.1, 2.0     # floor top, pit floor, chamfer width
    px0, px1 = -61, -42                                                   # pit row (ref x -74..-48)
    pits = [(-33, -17), (-12.5, 20.5), (23.5, 35.5)]                      # ref y -30..-12, -8..28, 31..44
    box(c, "BackKerb", x0, x0 + 1.2, y0 + CH, y1 - CH, 0, F + 0.3, SD)   # dark kerb along the wall
    box(c, "FloorBack", x0 + 1.2, px0, y0 + CH, y1 - CH, 0, F, S)
    box(c, "FloorFront", px1, x1 - CH, y0 + CH, y1 - CH, 0, F, S)
    ys = [y0 + CH] + [v for p in pits for v in p] + [y1 - CH]
    for k in range(0, len(ys), 2):                                        # floor between and beyond the pits
        box(c, "PitRowFloor", px0, px1, ys[k], ys[k + 1], 0, F, S)
    for k, (a, b) in enumerate(pits):
        box(c, f"Pit{k+1}Floor", px0, px1, a, b, PIT - 0.5, PIT, SL)
        wedge(c, f"Pit{k+1}SlopeA", px0, px1, a, a + 3, PIT, F, SD, "-y")  # sloped ends, as in the close-up
        wedge(c, f"Pit{k+1}SlopeB", px0, px1, b - 3, b, PIT, F, SD, "+y")
        box(c, f"Pit{k+1}LipBack", px0 - 0.6, px0, a, b, 0, F + 0.15, SD)  # thin dark lip on the long sides
        box(c, f"Pit{k+1}LipFront", px1, px1 + 0.6, a, b, 0, F + 0.15, SD)
    wedge(c, "ChamferFront", x1 - CH, x1, y0 + CH, y1 - CH, 0, F, SL, "-x")  # chamfered outer edge
    wedge(c, "ChamferEndA", x0, x1 - CH, y0, y0 + CH, 0, F, SL, "+y")
    wedge(c, "ChamferEndB", x0, x1 - CH, y1 - CH, y1, 0, F, SL, "-y")
    box(c, "Skirt", x0, x1 + 0.8, y0 - 0.8, y1 + 0.8, 0, 0.4, SD)           # darker step around the base
    col_box("TerraceA_Floor", x0, x1, y0, y1, 0, F)

def build_terrace_b():
    """Phone stand on the right (terraceB_closeup design, even footprint |x| 30..87, y -48..48): low front rim,
    a sunken trough with five coloured pads and sloped ends, a raised rear shelf with six dark display pads."""
    c = coll("Terrace_B"); S, SD, SL = mat("stone"), mat("stone_dark"), mat("stone_low")
    x0, x1, y0, y1 = SX0, SX1, -SY + 7, SY - 7; RIM, SHELF, FL = 2.0, 5.0, 0.6   # close-up: the display shelf stands well above the trough
    tx0, tx1, ty0, ty1 = x0 + 4, x0 + 22, -28, 28
    box(c, "FrontRim", x0, tx0, y0, y1, 0, RIM, S)
    box(c, "Back", tx1, x1, y0, y1, 0, RIM, SL)
    box(c, "RearShelf", tx1 + 3, x1, y0, y1, RIM, SHELF, S)
    box(c, "TroughFloor", tx0, tx1, ty0, ty1, 0, FL, SL)
    wedge(c, "TroughRamp", tx0, tx1, ty0 - 6, ty0, FL, RIM, SD, "-y")
    wedge(c, "TroughRamp", tx0, tx1, ty1, ty1 + 6, FL, RIM, SD, "+y")
    box(c, "TroughEnd", tx0, tx1, y0, ty0 - 6, 0, RIM, S); box(c, "TroughEnd", tx0, tx1, ty1 + 6, y1, 0, RIM, S)
    wedge(c, "EndSlope", x0, x1, -SY, y0, 0, RIM, SD, "+y")
    wedge(c, "EndSlope", x0, x1, y1, SY, 0, RIM, SD, "-y")
    tc = (tx0 + tx1) / 2
    for k, key in enumerate(("pad_green", "pad_cyan", "pad_red", "pad_black", "pad_black")):
        cy = 22 - 11 * k
        box(c, f"TroughPad{k+1}", tc - 4, tc + 4, cy - 4, cy + 4, FL, FL + 0.25, mat(key))
    sc = (tx1 + 3 + x1) / 2
    for k in range(6):
        cy = 32.5 - 13 * k
        box(c, f"ShelfPad{k+1}", sc - 4.5, sc + 4.5, cy - 4.5, cy + 4.5, SHELF, SHELF + 0.25, mat("pad_black"))
    col_box("TerraceB_Rim", x0, x1, y0, y1, 0, RIM); col_box("TerraceB_Shelf", tx1 + 3, x1, y0, y1, 0, SHELF)

def beam(c, name, p0, p1, z0, z1, w, m):
    """Straight beam between two ground points (any angle), w wide."""
    dx, dy = p1[0] - p0[0], p1[1] - p0[1]; L = math.hypot(dx, dy)
    ob = box(c, name, 0, L, -w / 2, w / 2, z0, z1, m)
    ob.location = (p0[0], p0[1], 0); ob.rotation_euler = (0, 0, math.atan2(dy, dx))
    return ob

def build_water():
    """45-degree channel at the end of the main path (hub_overview): grey stepped rock in it, two short wooden rails."""
    c = coll("Water")
    prism(c, "Bed", WATER_POLY, -4.5, -4, mat("water_bed", studs=False))
    prism(c, "WaterSurface", WATER_POLY, -4, -1.2, mat("water", studs=False, alpha=0.8, emit=0.15, rough=0.1))
    cx, cy = -22, -84
    for k, (w, d, z) in enumerate(((11, 8, 0.4), (8, 6, 1.6), (5, 4, 2.8), (2.5, 2, 3.8))):
        box(c, f"Rock{k}", cx - w/2 + k * 0.8, cx + w/2 + k * 0.8, cy - d/2, cy + d/2, -4, z, mat("rock"))
    R = mat("rail")
    for nm, p0, p1 in (("RailL", (-20, -73.2), (-8, -73.2)), ("RailR", (8, -73.2), (20, -73.2))):   # even: one each side of the path
        beam(c, nm, p0, p1, 1.8, 2.3, 0.4, R)
        for t in (0, 0.5, 1):
            x, y = p0[0] + t * (p1[0] - p0[0]), p0[1] + t * (p1[1] - p0[1])
            box(c, nm + "Post", x - 0.4, x + 0.4, y - 0.4, y + 0.4, -3, 2.6, R)
    col_box("WaterBed", HUB_XL, HUB_XR, -92, -74, -4, -1.5)

def build_portal():
    """World 2 portal: stepped block arch at (-15, 27) on the grass left of the main path, turned 45 degrees
    toward the spawn (Alex). Shell only, no effects."""
    c = coll("Portal"); m, inner = mat("portal_shell"), mat("portal_inner", studs=False, emit=0.6)
    cx, cy = -15, 27
    box(c, "Base", cx - 2.5, cx + 2.5, cy - 7, cy + 7, 0, 0.8, m)
    box(c, "PillarL", cx - 1.5, cx + 1.5, cy - 5.5, cy - 3.5, 0.8, 9, m)
    box(c, "PillarR", cx - 1.5, cx + 1.5, cy + 3.5, cy + 5.5, 0.8, 9, m)
    box(c, "StepL", cx - 1.5, cx + 1.5, cy - 4.5, cy - 2.5, 9, 10.5, m)
    box(c, "StepR", cx - 1.5, cx + 1.5, cy + 2.5, cy + 4.5, 9, 10.5, m)
    box(c, "ArchTop", cx - 1.5, cx + 1.5, cy - 3, cy + 3, 10.5, 12, m)
    box(c, "Inner", cx - 0.3, cx + 0.3, cy - 3.5, cy + 3.5, 0.8, 10.5, inner)
    obs = list(c.objects) + [col_box("Portal", cx - 1.5, cx + 1.5, cy - 5.5, cy + 5.5, 0, 12)]
    from mathutils import Matrix
    turn = Matrix.Translation((cx, cy, 0)) @ Matrix.Rotation(math.radians(-45), 4, 'Z') @ Matrix.Translation((-cx, -cy, 0))
    for ob in obs: ob.matrix_world = turn @ ob.matrix_world

def build_lane(bay):
    c = coll("Lane"); g = coll("Stage_Frames"); xc = (LANE_XL + LANE_XR) / 2
    for i in range(BAYS):
        y = LANE_Y0 + i * BAY_PITCH
        instance(c, bay, f"Bay{i+1:02d}", (xc, y, 0))
        if i < BAYS - 1: stage_gate(g, i + 2, y + 54)       # gate into stage i+2 over each divider; none at the entrance
    col_box("LaneFloor", LANE_XL, LANE_XR, LANE_Y0, LANE_Y1, -1, 0.3)

def build_walls():
    c = coll("Walls"); terrain_mesh(c)
    D = WALL_D
    for nm, a, b, cc, d in (("HubL", HUB_XL - D, HUB_XL, BACK_Y, HUB_YF), ("HubR", HUB_XR, HUB_XR + D, BACK_Y, HUB_YF_R),
                            ("FrontL", HUB_XL, LANE_XL, HUB_YF, HUB_YF + D), ("FrontR", LANE_XR, HUB_XR, HUB_YF_R, HUB_YF_R + D),
                            ("LaneL", LANE_XL - D, LANE_XL, HUB_YF, LANE_Y1), ("LaneR", LANE_XR, LANE_XR + D, HUB_YF_R, LANE_Y1),
                            ("LaneEnd", LANE_XL, LANE_XR, LANE_Y1, LANE_Y1 + D), ("Back", HUB_XL, HUB_XR, BACK_Y - D, BACK_Y)):
        col_box(nm, a, b, cc, d, 0, WALL_H2)

def build_foliage(trees):
    c = coll("Foliage"); rnd = random.Random(8); Z = WALL_H2
    def rows(ledge):                                  # two tree rows on the upper land, as in lane_view
        D = 2 * WALL_T + ledge; return D + 7, D + 21
    spots = []
    r1, r2 = rows(LEDGE)
    for y in range(BACK_Y + 8, HUB_YF + 30, 15):  spots += [(HUB_XL - r1, y, Z), (HUB_XL - r2, y + 7, Z)]
    for x in range(HUB_XL - 10, LANE_XL - r1 + 1, 15): spots += [(x, HUB_YF + r1, Z), (x + 7, HUB_YF + r2, Z)]
    for y in range(HUB_YF + r2 + 10, LANE_Y1, 17):
        spots += [(LANE_XL - r1, y, Z), (LANE_XR + r1, y + 8, Z), (LANE_XL - r2, y + 8, Z), (LANE_XR + r2, y, Z)]
    for y in range(BACK_Y + 8, HUB_YF + 30, 15): spots += [(HUB_XR + r1, y, Z), (HUB_XR + r2, y + 7, Z)]
    for x in range(LANE_XR + r1, HUB_XR + 11, 15):   spots += [(x, HUB_YF + r1, Z), (x + 7, HUB_YF + r2, Z)]
    for x in range(HUB_XL + 8, HUB_XR, 16):          # far bank behind the water
        spots += [(x, -100, 0), (x + 8, -116, 0)]
    # on the hub floor: the pine left of the lane mouth (hub_overview); behind the stands (Alex): rear corners
    spots += [(-36, 64, 0), (36, 64, 0), (-80, -54, 0), (-80, 54, 0), (80, -54, 0), (80, 54, 0)]   # pines at the lane mouth; trees behind both stands' back corners
    for k, (x, y, z) in enumerate(spots):
        t = trees[0] if (abs(x), y, z) == (36, 64, 0) else (trees[k % 2] if k % 7 else trees[2])   # lane_view: mostly stepped pines and box trees, few pale trunks
        j = 0 if z < Z else 1
        instance(c, t, f"Tree{k:03d}", (x + j * rnd.uniform(-1.5, 1.5), y + j * rnd.uniform(-2, 2), z),
                 rnd.choice((0, 90, 180, 270)), rnd.uniform(0.85, 1.05))
    B, Sp, R = mat("bush"), mat("sprig"), mat("rock")
    for (x, y) in ((14, -28), (-14, -28), (16, -55), (-16, -55), (16, 30), (-16, 30), (60, 64), (-60, 64)):   # low two-tier bushes
        w = rnd.uniform(5, 7)
        box(c, "Bush", x - w/2, x + w/2, y - w/2.5, y + w/2.5, 0, w * 0.55, B)
        box(c, "BushTop", x - w/4, x + w/4, y - w/5, y + w/5, w * 0.55, w * 0.85, B)
    for k in range(40):                                 # grass sprigs on the hub grass
        x = rnd.uniform(-28, 28); y = rnd.uniform(-70, 70)
        if abs(x) < 7 or abs(y) < 7: continue
        box(c, "Sprig", x - 0.3, x + 0.3, y - 0.3, y + 0.3, 0, rnd.uniform(1.0, 2.0), Sp)
    for (x, y, w) in ((-22, -40, 2.5), (22, -40, 2.5), (-45, -62, 2.5), (45, -62, 2.5)):
        box(c, "RockBlock", x - w/2, x + w/2, y - w/2, y + w/2, 0, w * 0.7, R)

# ---------------------------------------------------------------- scene, light, cameras ---
def setup_scene():
    sc = bpy.context.scene
    sc.render.engine = 'BLENDER_EEVEE_NEXT' if 'BLENDER_EEVEE_NEXT' in [e.identifier for e in bpy.types.RenderSettings.bl_rna.properties['engine'].enum_items] else 'BLENDER_EEVEE'
    sc.view_settings.view_transform = 'Standard'; sc.view_settings.exposure = 0.0
    try: sc.eevee.taa_render_samples = 24
    except Exception: pass
    w = bpy.data.worlds.new("Daylight"); sc.world = w; w.use_nodes = True
    bg = w.node_tree.nodes["Background"]; bg.inputs[0].default_value = (*lin("EEF2F6"), 1); bg.inputs[1].default_value = 0.5
    WN = w.node_tree.nodes; WL = w.node_tree.links
    sky = WN.new("ShaderNodeBackground"); sky.inputs[0].default_value = (*lin("9CCBFF"), 1); sky.inputs[1].default_value = 1.0
    lp = WN.new("ShaderNodeLightPath"); mx = WN.new("ShaderNodeMixShader")
    WL.new(lp.outputs["Is Camera Ray"], mx.inputs[0]); WL.new(bg.outputs[0], mx.inputs[1]); WL.new(sky.outputs[0], mx.inputs[2])
    WL.new(mx.outputs[0], WN["World Output"].inputs["Surface"])
    sun = bpy.data.objects.new("Sun", bpy.data.lights.new("Sun", 'SUN'))
    sun.data.energy = 2.5; sun.data.angle = math.radians(3); sun.data.color = (1.0, 0.97, 0.9)
    sun.rotation_euler = (math.radians(38), math.radians(8), math.radians(-30))
    coll("CAMERAS").objects.link(sun)


def camera(name, loc, look, lens_vfov=70, ortho=None, clip_start=0.1, rot=None):
    cd = bpy.data.cameras.new(name)
    if ortho: cd.type = 'ORTHO'; cd.ortho_scale = ortho
    else: cd.sensor_fit = 'VERTICAL'; cd.angle = math.radians(lens_vfov)
    cd.clip_start = clip_start; cd.clip_end = 4000
    ob = bpy.data.objects.new(name, cd); coll("CAMERAS").objects.link(ob)
    ob.location = loc
    if rot: ob.rotation_euler = tuple(math.radians(a) for a in rot)
    else: ob.rotation_euler = (Vector(look) - Vector(loc)).to_track_quat('-Z', 'Y').to_euler()
    if name == "CAM_Overhead": ob.rotation_euler = (0, 0, math.radians(90))   # straight down, +Y to the right
    return ob

CAMS = {
    # name: (location, look-at or None, vfov, ortho scale, clip start, euler XYZ degrees or None, render size)
    # CAM_HubRef is the camera solved from ref/hub_overview.png (analysis/fit_cam2.py): same spot, angle and lens
    "CAM_HubRef":      ((35.139, -66.478, 69.952), None, 81.187, None, 0.1, (40.403, -3.067, 34.819), (1507, 858)),
    "CAM_Overhead":    ((-20, 380, 600), (-20, 380, 0), None, 1100, 0.1, None, (2160, 680)),
    "CAM_LaneHigh":    ((0, 50, 42), (0, 250, 0), 70, None, 0.1, None, (1500, 868)),
    "CAM_LaneEye":     ((2.5, 80, 5.2), (0, 400, 4), 70, None, 0.1, None, (1500, 860)),
    "CAM_LaneSection": ((0, 100, 14), (0, 200, 14), None, 110, 1.0, None, (1500, 860)),
    "CAM_TerraceA":    ((-17, 0, 10), (-70, 0, 0), 70, None, 0.1, None, (1500, 860)),
    "CAM_TerraceB":    ((14, 0, 12), (60, 0, 1.5), 62, None, 0.1, None, (1500, 590)),
}

def build():
    bpy.ops.wm.read_homefile(use_empty=True)
    COLLS.clear(); MATS.clear()
    setup_scene()
    bay, trees = module_bay(), module_trees()
    bpy.context.view_layer.layer_collection.children["MODULES"].exclude = True
    build_hub(); build_terrace_a(); build_terrace_b(); build_water(); build_portal()
    build_lane(bay); build_walls(); build_foliage(trees)
    col = bpy.data.collections["COLLISION"]
    for ob in bpy.data.objects:
        if ob.type == 'MESH' and ob.name not in col.objects and "Water" not in ob.name:
            bv = ob.modifiers.new("Bevel", 'BEVEL'); bv.width = 0.18; bv.segments = 3
            bv.limit_method = 'ANGLE'; bv.use_clamp_overlap = True; bv.harden_normals = True
            for p in ob.data.polygons: p.use_smooth = True
    for n, (loc, look, vf, orth, cs, rot, _) in CAMS.items(): camera(n, loc, look, vf or 70, orth, cs, rot)
    bpy.context.scene.camera = bpy.data.objects["CAM_HubRef"]
    bpy.ops.wm.save_as_mainfile(filepath=HERE + "ChessMap_v2.blend")
    return len(bpy.data.objects)

def render(cam, out, w=1500, h=860):
    sc = bpy.context.scene; sc.camera = bpy.data.objects[cam]
    sc.render.resolution_x, sc.render.resolution_y = w, h
    sc.render.filepath = out; bpy.ops.render.render(write_still=True)

def render_all(tag="r1", only=None):
    os.makedirs(HERE + "review", exist_ok=True)
    for cam, spec in CAMS.items():
        if only and cam not in only: continue
        render(cam, f"{HERE}review/{tag}_{cam}.png", *spec[6])
