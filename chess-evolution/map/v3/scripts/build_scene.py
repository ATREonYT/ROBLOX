# +1 Chess Evolution hub map, v3 recreation (Alex's brief of Nov 9: phases 0-5), grown from build_reference_fix.py.
# Run in Blender 5.x:  ns={}; exec(open(".../v3/scripts/build_scene.py").read(), ns); ns["build"](ver="v01")
# Saves v3/scene_vNN.blend (never the source ChessMap_Reference_Fix.blend). Collections: Hub, Treadmill, Phone, Lane, Shared.
# Hard edges everywhere: no bevels, flat shading (brief: blocky Roblox look).
# 1 unit = 1 stud. Spawn at origin, lane along +Y, treadmill stand at -X, phone stand at +X, water behind spawn.
# Saves ChessMap_Reference_Fix.blend next to this script with the texture pack images packed.
#
# World scale (Nov 9 measurement pass, analysis/fit_*.py):
#   * the path is 12 studs wide: 10 orange stud glyphs + a 1-stud brown edge each side (counted in terraceA_closeup);
#   * the lane is 48 studs wall to wall (stud count on lane_view's floor) and its bays repeat every 48;
#   * every close-up camera solves with Roblox's 70 degree vertical FOV (the lane fit converges to 70.3 with focal free),
#     so the hub camera was refitted at 70 degrees too (analysis/fit_hub70.py). The v7 map used 81 degrees and an
#     11-stud path, which made it about 9% too small and stretched along the view.
import bpy, bmesh, math, random, os, json
from mathutils import Vector, Matrix

HERE = "/Users/Alex/ROBLOX/chess-evolution/map/v2/"
PACK = HERE + "texture_pack/"
MARK = "v3k"
V3 = "/Users/Alex/ROBLOX/chess-evolution/map/v3/"
CLAY = False                                # blockout pass: every surface flat grey

# ---------------------------------------------------------------- sizes (studs) ---
PATH_HW, PATH_EDGE = 6, 1                   # 12 wide: 10 orange + 1 brown each side
SPAWN_HALF = 2.5
HUB_XL, HUB_XR = -115, 74                   # wall faces behind the treadmill stand / behind the phone stand
HUB_YF, HUB_YF_R = 76, 79                   # front wall left of the lane / right of the lane (lane_view: the right
                                            # block rises straight to the top land, its front face at y 79)
BACK_Y = -240                               # far bank beyond the water (off screen, inferred)
CROSS_X0, CROSS_X1 = -34, 27                # cross path from the treadmill stand front to the phone stand front
# water traced from hub_overview's cyan through the solved camera: near bank ~30 degrees, far bank ~40 degrees
WATER_POLY = [(-24, -81), (-10, -81), (-2, -89), (-2, -92), (-117, -188), (-117, -135), (-44, -93), (-29, -91)]
PATH_Y0 = -80                               # main path stops 1 stud short of the water
TA = (-114, -34, -56, 60)                   # treadmill stand x0, x1, y0, y1
TB = (27, 73, -52, 50)                      # phone stand x0, x1, y0, y1
LANE_HW, LANE_Y0 = 24, 76                   # lane 48 wide, starts at the front wall
BAY_P, BAYS = 48, 15                        # two starter bays, then a gate into stages 2..14 every 48
LANE_Y1 = LANE_Y0 + BAY_P * BAYS
WALL_T, LEDGE, WALL_H1, WALL_H2 = 4, 9, 24.6, 38.6   # red faces to 22 and 36 (lane_view), each topped by a
LIP = 2.6                                        # 2.6-stud green lip (terraceA_closeup: green band 22.2..24.8)
LEDGE_R, LEDGE_FR, LEDGE_LANE_R = 22, 15, 3      # wider ledge behind the phone stand / right block; narrow strip right of the lane

# texture pack material per role (texture_pack/Material_Map.json)
ROLE = {"grass": "Grass_Lime", "grass_top": "Grass_Top", "grass_bright": "Grass_Bright", "grass_cap": "Grass_Cap", "path": "Path_Orange",
        "path_edge": "Path_Edge_Brown", "wall_face": "Dirt_Wall_Orange", "wall_shade": "Dirt_Wall_Shade",
        "wall_band": "Dirt_Wall_Shade", "wall_skirt": "Paving_Riser", "paving": "Paving_Grey", "paving_light": "Paving_Light",
        "bay": "Paving_Bay_Grey", "riser": "Paving_Riser", "trim": "Paving_Dark_Trim", "lane": "Paving_Grey",
        "pad_mint": "Display_Mint", "pad_cyan": "Display_Cyan", "pad_red": "Display_Red", "pad_black": "Display_Black",
        "stage_red": "Stage_Pad_Red", "marker": "Stage_Marker", "tile_magenta": "Stage_Tile_Magenta",
        "tile_yellow": "Stage_Tile_Yellow", "divider": "Stage_Divider_Lime", "leaf": "Leaves_Lime", "leaf_sun": "Leaves_Sunny",
        "leaf_dark": "Leaves_Green", "shrub": "Shrub_Lime", "bark": "Bark_Orange", "bark_pale": "Bark_Pale",
        "water": "Water_Cyan", "stone": "Stone_Shore", "portal_shell": "Portal_Blue", "portal_core": "Portal_Magenta",
        "rail": "Path_Edge_Brown"}
# gate frame per stage; stages 2 and 3 are unlocked (hidden) in lane_view, so its first gate is stage 4, magenta
STAGE_GATE = {2: "Gate_Lime", 3: "Gate_Cyan", 4: "Gate_Pink", 5: "Gate_Yellow", 6: "Gate_Orange", 7: "Gate_Purple",
              8: "Gate_Blue", 9: "Gate_Lime", 10: "Gate_Cyan", 11: "Gate_Pink", 12: "Gate_Yellow", 13: "Gate_Orange", 14: "Gate_Purple"}
# rendered-colour trims per pack material (multiplier on the texture, tuned against Alex's sample patches in pass 3)
TINT = {"Path_Orange": (0.8, 0.56, 0.15), "Paving_Light": (0.85, 0.94, 0.96),
        # Phase 2 (v02): grass and walls trimmed to the close-ups' class means (scripts/colour_stats.py on v01):
        # grass screenshots ~(45,228,12) vs render (57,221,24); walls (197,65,35) vs (197,75,42)
        "Grass_Lime": (0.09, 0.83, 0.04), "Grass_Cap": (0.09, 0.85, 0.04), "Grass_Bright": (0.12, 0.85, 0.04),
        "Dirt_Wall_Orange": (1.0, 0.73, 0.67),
        "Leaves_Lime": (0.3, 0.8, 0.2),
        "Leaves_Sunny": (0.35, 0.85, 0.2), "Leaves_Green": (0.4, 0.85, 0.3), "Shrub_Lime": (0.4, 0.85, 0.25), "Stage_Pad_Red": (1.35, 0.3, 0.75),
        "Stage_Tile_Yellow": (1.3, 0.8, 0.37), "Water_Cyan": (3.6, 1.25, 1.2),
        "Paving_Grey": (1.0, 1.06, 1.05)}

def lin(h):
    h = h.lstrip("#"); c = [int(h[i:i+2], 16) / 255 for i in (0, 2, 4)]
    return tuple(x / 12.92 if x <= 0.04045 else ((x + 0.055) / 1.055) ** 2.4 for x in c)

# ---------------------------------------------------------------- texture pack materials ---
PACKMAP = {}
def _packmap():
    if not PACKMAP:
        for e in json.load(open(PACK + "Material_Map.json")): PACKMAP[e["material"]] = e
    return PACKMAP

def _img(rel, noncolor=False):
    name = os.path.basename(rel)
    img = bpy.data.images.get(name) or bpy.data.images.load(PACK + rel)
    img.colorspace_settings.name = 'Non-Color' if noncolor else 'sRGB'
    return img

# Stud surfaces (v06, Alex Nov 9: "baseplate texture with studs inside of it, in and out studs on the trees"),
# measured in the screenshots: grass = baseplate (groove grid, one raised stud per 1-stud cell), leaves and trunks =
# raised and sunken studs in a checker, path = groove grid with a sunken stud per cell. Textures from
# scripts/make_studs.py; the bevel light comes from the sun through the normal map. Base colours are flat and tuned to
# the screenshots' lit tops (compare/notes.md, v06).
TEX = V3 + "textures/"
# name: (stud kind, base colour, gain on the linear colour). v06b trims from v06a samples at the same spots:
#   hub grass ref (21,233,1) vs (56,238,26); pine lit side (71,245,0) vs (58,196,13); trunk (215,80,30) vs (173,73,30);
#   bank tops are a brighter yellow-lime than the hub floor in lane_view: (104,255,12)
STUD = {"Grass_Lime": ("baseplate", "0AD600", 1.0), "Grass_Cap": ("baseplate", "0AD600", 1.0),
        "Grass_Bright": ("baseplate", "0AD600", 1.0), "Grass_Top": ("baseplate", "5CF004", 1.0),
        "Leaves_Lime": ("inout", "38FF00", 1.05), "Leaves_Sunny": ("inout", "44FF00", 1.1), "Leaves_Green": ("inout", "30EC00", 1.0),
        "Shrub_Lime": ("inout", "40F000", 1.05), "Bark_Orange": ("inout", "F04A1A", 1.0), "Path_Orange": ("inlet", "E8800A", 1.0)}
STUD_NORMAL = 2.0
STUD_HL = (0.6, 0.35, 0.0)   # v06d: lime highlight on raised stud tops
def _stud_img(f):
    img = bpy.data.images.get(f) or bpy.data.images.load(TEX + f)
    img.colorspace_settings.name = 'Non-Color'; return img

MATS = {}
def pmat(name, alpha=1.0, emit=0.0):
    """Pack material: colour tile through the UVs (1 repeat per 8 studs, set per face), normal map at 0.32."""
    key = (name, alpha, emit, CLAY)
    if key in MATS: return MATS[key]
    e = _packmap().get(name, {}); m = bpy.data.materials.new(f"Map_{name}" + ("_Panel" if alpha < 1 else ""))
    m.use_nodes = True; nt = m.node_tree; N, L = nt.nodes, nt.links; b = N["Principled BSDF"]
    b.inputs["Roughness"].default_value = e.get("roughness", 0.8)
    try: b.inputs["Specular IOR Level"].default_value = 0.08
    except KeyError: pass
    rgb = lin(e.get("approx_srgb", "#A0A0A0"))
    if CLAY:
        b.inputs["Base Color"].default_value = (0.42, 0.42, 0.42, 1)
    elif name in STUD:
        kind, hexcol, gain = STUD[name]
        sh = N.new("ShaderNodeTexImage"); sh.image = _stud_img(f"{kind}_shade.png")
        mx = N.new("ShaderNodeMix"); mx.data_type = 'RGBA'; mx.blend_type = 'MULTIPLY'; mx.inputs["Factor"].default_value = 1.0
        mx.inputs[6].default_value = (*[c * gain for c in lin(hexcol)], 1); L.new(sh.outputs["Color"], mx.inputs[7])
        sc = N.new("ShaderNodeVectorMath"); sc.operation = 'SCALE'; sc.inputs["Scale"].default_value = 1.5
        # lit stud tops pick up a lime highlight (screenshot stud edges raise red, not only green): + max(S-1,0)*STUD_HL
        hs = N.new("ShaderNodeVectorMath"); hs.operation = 'MULTIPLY_ADD'; L.new(sh.outputs["Color"], hs.inputs[0])
        hs.inputs[1].default_value = (1.5, 1.5, 1.5); hs.inputs[2].default_value = (-1.0, -1.0, -1.0)
        hm = N.new("ShaderNodeVectorMath"); hm.operation = 'MAXIMUM'; L.new(hs.outputs[0], hm.inputs[0]); hm.inputs[1].default_value = (0, 0, 0)
        hc = N.new("ShaderNodeVectorMath"); hc.operation = 'MULTIPLY_ADD'; L.new(hm.outputs[0], hc.inputs[0])
        hc.inputs[1].default_value = STUD_HL; L.new(mx.outputs[2], sc.inputs[0]); L.new(sc.outputs[0], hc.inputs[2])
        L.new(hc.outputs[0], b.inputs["Base Color"])
        ni = N.new("ShaderNodeTexImage"); ni.image = _stud_img(f"{kind}_normal.png")
        nm = N.new("ShaderNodeNormalMap"); nm.inputs["Strength"].default_value = STUD_NORMAL
        L.new(ni.outputs["Color"], nm.inputs["Color"]); L.new(nm.outputs["Normal"], b.inputs["Normal"])
        rgb = lin(hexcol)
    else:
        tex = N.new("ShaderNodeTexImage"); tex.image = _img(e["color"]); tex.interpolation = 'Linear'
        col = tex.outputs["Color"]
        t = TINT.get(name)
        if t:
            mx = N.new("ShaderNodeMix"); mx.data_type = 'RGBA'; mx.blend_type = 'MULTIPLY'; mx.inputs["Factor"].default_value = 1.0
            mx.inputs[7].default_value = (*t, 1); L.new(col, mx.inputs[6]); col = mx.outputs[2]
        L.new(col, b.inputs["Base Color"])
        if e.get("normal"):
            nimg = N.new("ShaderNodeTexImage"); nimg.image = _img(e["normal"], True)
            nm = N.new("ShaderNodeNormalMap"); nm.inputs["Strength"].default_value = 0.32
            L.new(nimg.outputs["Color"], nm.inputs["Color"]); L.new(nm.outputs["Normal"], b.inputs["Normal"])
        if emit:
            b.inputs["Emission Color"].default_value = (*rgb, 1); b.inputs["Emission Strength"].default_value = emit
    if alpha < 1:
        b.inputs["Base Color"].default_value = (*rgb, 1)
        if not CLAY:
            for l in list(L):
                if l.to_socket == b.inputs["Base Color"]: L.remove(l)
        b.inputs["Alpha"].default_value = alpha
        try: m.surface_render_method = 'BLENDED'
        except Exception: m.blend_method = 'BLEND'
    m.diffuse_color = (*rgb, alpha)
    MATS[key] = m
    return m

def mat(role, **kw):
    return pmat(ROLE.get(role, role), **kw)

# ---------------------------------------------------------------- geometry helpers ---
COLLS = {}
AREAS = ("Hub", "Treadmill", "Phone", "Lane", "Shared")
RENAME = {"Terrace_A": "Treadmill", "Terrace_B": "Phone"}
PARENT = {"Water": "Hub", "Portal": "Hub", "Stage_Frames": "Lane", "Stage_Frames_Unlocked": "Lane", "Walls": "Shared",
          "Foliage": "Shared", "CAMERAS": "Shared", "COLLISION": "Shared", "Machines": "Treadmill", "Props_Treadmill": "Treadmill",
          "Props_Phone": "Phone", "Props_Hub": "Hub", "Props_Lane": "Lane", "Trees": "Shared", "Library": "Shared"}
def coll(name, parent=None, hide=False):
    name = RENAME.get(name, name)
    if name in COLLS: return COLLS[name]
    if parent is None and name in PARENT: parent = coll(PARENT[name])
    c = bpy.data.collections.new(name); (parent or bpy.context.scene.collection).children.link(c)
    if hide: c.hide_render = True; c.hide_viewport = True
    COLLS[name] = c
    return c

def _obj(c, name, verts, faces, m, mats=None):
    me = bpy.data.meshes.new(name); me.from_pydata(verts, [], faces); me.update()
    ob = bpy.data.objects.new(name, me)
    for mm in (mats or [m]): ob.data.materials.append(mm)
    c.objects.link(ob)
    return ob

BOXF = [(0,3,2,1),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)]
def box(c, name, x0, x1, y0, y1, z0, z1, m, side=None):
    """Axis box. `side`: optional second material for the four vertical faces (top and bottom keep m)."""
    v = [(x0,y0,z0),(x1,y0,z0),(x1,y1,z0),(x0,y1,z0),(x0,y0,z1),(x1,y0,z1),(x1,y1,z1),(x0,y1,z1)]
    ob = _obj(c, name, v, BOXF, m, [m, side] if side else None)
    if side:
        for k, p in enumerate(ob.data.polygons): p.material_index = 0 if k < 2 else 1
    return ob

def wedge(c, name, x0, x1, y0, y1, z0, z1, m, high, taper=0.0):
    """Ramp block: top slopes from z1 on the `high` side ('+x','-x','+y','-y') to z0 on the other.
    taper (x-ramps only): the low end is narrower by `taper` studs on each side (tapered ramps)."""
    def top(x, y): return {"+x": x == x1, "-x": x == x0, "+y": y == y1, "-y": y == y0}[high]
    pts = [(x0,y0),(x1,y0),(x1,y1),(x0,y1)]
    def tp(x, y):
        if taper and high in ("+x", "-x") and not top(x, y): return (x, y + (taper if y == y0 else -taper))
        return (x, y)
    v = [(*tp(x, y), z0) for x, y in pts] + [(*tp(x, y), z1 if top(x, y) else z0 + 0.001) for x, y in pts]
    return _obj(c, name, v, BOXF, m)

def prism(c, name, pts, z0, z1, m):
    area = sum(pts[i][0] * pts[i-1][1] - pts[i-1][0] * pts[i][1] for i in range(len(pts)))
    if area < 0: pts = pts[::-1]
    n = len(pts); v = [(x, y, z0) for x, y in pts] + [(x, y, z1) for x, y in pts]
    f = [tuple(range(n)), tuple(range(2 * n - 1, n - 1, -1))] + [(i, (i + 1) % n, (i + 1) % n + n, i + n)[::-1] for i in range(n)]
    return _obj(c, name, v, f, m)

def _merge(c, name, boxes, m):
    v, f = [], []
    for (x0, x1, y0, y1, z0, z1) in boxes:
        o = len(v); v += [(x0,y0,z0),(x1,y0,z0),(x1,y1,z0),(x0,y1,z0),(x0,y0,z1),(x1,y0,z1),(x1,y1,z1),(x0,y1,z1)]
        f += [tuple(o + k for k in q) for q in BOXF]
    return _obj(c, name, v, f, m)

def col_box(name, x0, x1, y0, y1, z0, z1):
    return box(coll("COLLISION", hide=True), "COL_" + name, x0, x1, y0, y1, z0, z1, mat("paving"))

def carve(ob, cutter):
    md = ob.modifiers.new("Carve", 'BOOLEAN'); md.operation = 'DIFFERENCE'; md.object = cutter; md.solver = 'EXACT'
    dg = bpy.context.evaluated_depsgraph_get(); dg.update()
    me = bpy.data.meshes.new_from_object(ob.evaluated_get(dg))
    ob.modifiers.remove(md); old = ob.data; ob.data = me; bpy.data.meshes.remove(old); bpy.data.objects.remove(cutter)

def turn(obs, cx, cy, deg):
    T = Matrix.Translation((cx, cy, 0)) @ Matrix.Rotation(math.radians(deg), 4, 'Z') @ Matrix.Translation((-cx, -cy, 0))
    for ob in obs: ob.matrix_world = T @ ob.matrix_world

def planar_uvs(ob, studs=8.0, world=True):
    """One tile per `studs` studs; each face projects on the plane of its dominant axis, so the stud grid keeps one phase
    across touching pieces (world coordinates) and walls get their own upright UVs."""
    me = ob.data
    if not me.uv_layers: me.uv_layers.new(name="UVMap")
    uv = me.uv_layers.active.data; M = ob.matrix_world if world else Matrix()
    water = any(s.material and "Water" in s.material.name for s in ob.material_slots)
    s = 24.0 if water else studs
    for p in me.polygons:
        n = (M.to_3x3() @ p.normal); ax = max(range(3), key=lambda i: abs(n[i]))
        for li in p.loop_indices:
            co = M @ me.vertices[me.loops[li].vertex_index].co
            if ax == 2: u, v = co.x, co.y
            elif ax == 0: u, v = co.y * (1 if n[0] > 0 else -1), co.z
            else: u, v = co.x * (-1 if n[1] > 0 else 1), co.z
            uv[li].uv = (u / s, v / s)

# ---------------------------------------------------------------- terrain (stepped banks as a height field) ---
def walk_rects():
    """Everything walked on at ground level, with the ledge width on each side (-x, +x, -y, +y)."""
    L = LEDGE
    return [(HUB_XL, HUB_XR, BACK_Y, HUB_YF, (L, LEDGE_R, L, L)),
            (LANE_HW, HUB_XR, HUB_YF, HUB_YF_R, (L, LEDGE_R, L, None)),        # None: straight up to the top land
            (-LANE_HW, LANE_HW, HUB_YF - 1, LANE_Y1, (L, LEDGE_LANE_R, L, L))]

def terrain_mesh(c):
    rects = walk_rects(); M = 60
    X0 = min(r[0] for r in rects) - M; X1 = max(r[1] for r in rects) + M
    Y0 = min(r[2] for r in rects) - M; Y1 = max(r[3] for r in rects) + M
    nx, ny = X1 - X0, Y1 - Y0
    def level(cx, cy):
        n = 1e9
        for (a, b, e, f, (lx0, lx1, ly0, ly1)) in rects:
            dx = max(a - cx, 0, cx - b); dy = max(e - cy, 0, cy - f)
            if dx == 0 and dy == 0: return 0
            lx = lx0 if cx < a else lx1; ly = ly0 if cy < e else ly1
            wx = 1e-3 if lx is None else WALL_T + lx; wy = 1e-3 if ly is None else WALL_T + ly
            n = min(n, max(dx / wx, dy / wy))
        return 1 if n <= 1 else 2
    H = [[level(X0 + i + 0.5, Y0 + j + 0.5) for i in range(nx)] for j in range(ny)]
    hz = (0.0, WALL_H1, WALL_H2)
    bm = bmesh.new(); MF, MC, MG, MS, MB = 0, 1, 2, 3, 4
    def quad(p, slot):
        f = bm.faces.new([bm.verts.new(v) for v in p]); f.material_index = slot
    for j in range(ny):
        i = 0
        while i < nx:
            h = H[j][i]; k = i
            while k < nx and H[j][k] == h: k += 1
            if h > 0:
                z = hz[h]; quad([(X0+i, Y0+j, z), (X0+k, Y0+j, z), (X0+k, Y0+j+1, z), (X0+i, Y0+j+1, z)], MG)
            i = k
    def side(p0, p1, zlo, zhi):
        zc = zhi - LIP     # banks: grey skirt 0..2.5, dark band 2.5..5.5, orange studded face, 2.6 green lip
        parts = ((zlo, 2.5, MS), (2.5, 5.5, MB), (5.5, zc, MF), (zc, zhi, MC)) if zlo == 0 else ((zlo, zlo + 1.0, MB), (zlo + 1.0, zc, MF), (zc, zhi, MC))
        for (a, b, s) in parts:
            quad([(p1[0], p1[1], a), (p0[0], p0[1], a), (p0[0], p0[1], b), (p1[0], p1[1], b)], s)
    for i in range(1, nx):
        j = 0
        while j < ny:
            a, b = H[j][i-1], H[j][i]
            if a == b: j += 1; continue
            k = j
            while k < ny and H[k][i-1] == a and H[k][i] == b: k += 1
            x = X0 + i
            if b > a: side((x, Y0+j), (x, Y0+k), hz[a], hz[b])
            else:     side((x, Y0+k), (x, Y0+j), hz[b], hz[a])
            j = k
    for j in range(1, ny):
        i = 0
        while i < nx:
            a, b = H[j-1][i], H[j][i]
            if a == b: i += 1; continue
            k = i
            while k < nx and H[j-1][k] == a and H[j][k] == b: k += 1
            y = Y0 + j
            if b > a: side((X0+k, y), (X0+i, y), hz[a], hz[b])
            else:     side((X0+i, y), (X0+k, y), hz[b], hz[a])
            i = k
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=0.001)
    bmesh.ops.dissolve_limit(bm, angle_limit=0.01, verts=bm.verts, edges=bm.edges, delimit={'MATERIAL'})
    me = bpy.data.meshes.new("Terrain"); bm.to_mesh(me); bm.free()
    for k in ("wall_face", "grass_cap", "grass_top", "wall_skirt", "wall_band"): me.materials.append(mat(k))
    ob = bpy.data.objects.new("Walls_Terrain", me); c.objects.link(ob)
    return ob

# ---------------------------------------------------------------- the map ---
def build_hub():
    c = coll("Hub"); G = mat("grass")
    g1 = box(c, "HubGrass", HUB_XL, HUB_XR, BACK_Y, HUB_YF, -4, 0, G)
    box(c, "HubGrassRight", LANE_HW, HUB_XR, HUB_YF, HUB_YF_R, -4, 0, G)
    carve(g1, prism(c, "WaterCut", WATER_POLY, -1.5, 2, G))
    hw, e = PATH_HW, PATH_EDGE; P, E = mat("path"), mat("path_edge")
    box(c, "PathMainEdgeL", -hw, -hw + e, PATH_Y0, HUB_YF, -0.2, 0.12, E)
    box(c, "PathMainEdgeR", hw - e, hw, PATH_Y0, HUB_YF, -0.2, 0.12, E)
    box(c, "PathMainEdgeEnd", -hw, hw, PATH_Y0, PATH_Y0 + e, -0.2, 0.12, E)
    box(c, "PathMain", -hw + e, hw - e, PATH_Y0 + e, HUB_YF, -0.2, 0.14, P)
    for nm, a, b in (("A", CROSS_X0, -hw), ("B", hw, CROSS_X1)):
        box(c, f"PathCross{nm}EdgeL", a, b, -hw, -hw + e, -0.2, 0.12, E)
        box(c, f"PathCross{nm}EdgeR", a, b, hw - e, hw, -0.2, 0.12, E)
        box(c, f"PathCross{nm}", a, b, -hw + e, hw - e, -0.2, 0.14, P)
    box(c, "Spawn", -SPAWN_HALF, SPAWN_HALF, -SPAWN_HALF, SPAWN_HALF, 0.14, 0.4, mat("paving_light"))
    col_box("HubFloor", HUB_XL, HUB_XR, BACK_Y, HUB_YF, -4, 0.14)

def build_terrace_a():
    """Treadmill stand (terraceA_closeup + hub_overview): the path ends flush at a thin grey front edge; one continuous
    studded lower deck; a straight raised rear shelf with a darker riser; two broad tapered ramps between the centre and
    the outer positions; dark machine footprints (2 in the centre, 1 at each end). Machines are not built."""
    c = coll("Terrace_A"); S, SL, R, T = mat("paving"), mat("paving_light"), mat("riser"), mat("trim")
    x0, x1, y0, y1 = TA; F, SH, CH = 1.0, 2.6, 3
    xs, xr = -88, -66                                    # shelf riser, foot of the ramps (terraceA_closeup)
    box(c, "RearShelf", x0, xs, y0 + CH, y1 - CH, 0, SH, SL, R)
    box(c, "LowerDeck", xs, x1 - 0.6, y0 + CH, y1 - CH, 0, F, S)
    box(c, "FrontEdge", x1 - 0.6, x1, y0 + CH, y1 - CH, 0, F, SL, T)
    for k, yc in enumerate((-29, 29)):
        wedge(c, f"Ramp{k+1}", xs, xr, yc - 8, yc + 8, F, SH, R, "-x", taper=1.5)
    for k, yc in enumerate((-42, -7.5, 7.5, 42)):
        box(c, f"Footprint{k+1}", -67, -56, yc - 5.5, yc + 5.5, F, F + 0.25, mat("pad_black"))
    wedge(c, "EndSlopeA", x0, x1, y0, y0 + CH, 0, F, R, "+y"); wedge(c, "EndSlopeB", x0, x1, y1 - CH, y1, 0, F, R, "-y")
    wedge(c, "ShelfEndA", x0, xs, y0 + CH, y0 + CH + 2, F, SH, R, "+y"); wedge(c, "ShelfEndB", x0, xs, y1 - CH - 2, y1 - CH, F, SH, R, "-y")
    col_box("TerraceA_Shelf", x0, xs, y0, y1, 0, SH); col_box("TerraceA_Deck", xs, x1, y0, y1, 0, F)

def build_terrace_b():
    """Phone stand (terraceB_closeup): front apron, lower pocket floor with 5 pads (mint, cyan, red, black, black),
    dark rear riser, upper shelf with 6 dark plinths in one line, sloped cheeks into the side paving wings."""
    c = coll("Terrace_B"); S, SL, R, B = mat("paving"), mat("paving_light"), mat("riser"), mat("bay")
    X0, X1, Y0, Y1 = TB; RIM, SHELF, FL = 1.2, 5.0, 0.4
    ax1, rx = X0 + 4, 47                                  # apron depth, rear riser x
    py0, py1, wy = -26, 26, 7                             # pocket ends, cheek length
    box(c, "Apron", X0, ax1, Y0 + 6, Y1 - 6, 0, RIM, SL, R)
    box(c, "PocketFloor", ax1, rx, py0, py1, 0, FL, B)
    wedge(c, "CheekL", ax1, rx, py0 - wy, py0, FL, RIM, R, "-y"); wedge(c, "CheekR", ax1, rx, py1, py1 + wy, FL, RIM, R, "+y")
    box(c, "WingL", ax1, rx, Y0 + 6, py0 - wy, 0, RIM, S); box(c, "WingR", ax1, rx, py1 + wy, Y1 - 6, 0, RIM, S)
    box(c, "Shelf", rx, X1, Y0 + 6, Y1 - 6, 0, SHELF, SL, R)
    wedge(c, "EndSlopeL", X0, X1, Y0, Y0 + 6, 0, RIM, R, "+y"); wedge(c, "EndSlopeR", X0, X1, Y1 - 6, Y1, 0, RIM, R, "-y")
    for k, key in enumerate(("pad_mint", "pad_cyan", "pad_red", "pad_black", "pad_black")):
        yc = 20 - 10 * k
        box(c, f"PadShim{k+1}", 34.5, 41.5, yc - 3.75, yc + 3.75, FL, FL + 0.15, mat("trim"))
        box(c, f"Pad{k+1}", 34.75, 41.25, yc - 3.5, yc + 3.5, FL + 0.15, FL + 0.45, mat(key))
    for k in range(6):
        yc = 32.5 - 13 * k
        box(c, f"Plinth{k+1}", 57, 64, yc - 4.5, yc + 4.5, SHELF, SHELF + 0.6, mat("pad_black"))
    col_box("TerraceB_Apron", X0, rx, Y0, Y1, 0, RIM); col_box("TerraceB_Shelf", rx, X1, Y0, Y1, 0, SHELF)

def beam(c, name, p0, p1, z0, z1, w, m):
    dx, dy = p1[0] - p0[0], p1[1] - p0[1]; L = math.hypot(dx, dy)
    ob = box(c, name, 0, L, -w / 2, w / 2, z0, z1, m)
    ob.location = (p0[0], p0[1], 0); ob.rotation_euler = (0, 0, math.atan2(dy, dx))
    return ob

def build_water():
    c = coll("Water")
    prism(c, "Bed", WATER_POLY, -4.5, -4, mat("stone"))
    prism(c, "WaterSurface", WATER_POLY, -4, -1.2, mat("water", emit=0.25))
    cx, cy = -19, -92                                  # irregular compact grey stone feature of staggered blocks
    for k, (dx, dy, w, d, z) in enumerate(((0, 0, 11, 8, 0.4), (1.5, -1, 8, 6, 1.6), (-1, 1.5, 6, 5, 2.8), (2, 0.5, 4, 3, 3.8),
                                           (-4, -3, 4, 3, 1.0), (4.5, 3, 3, 3, 0.8))):
        box(c, f"Stone{k}", cx + dx - w/2, cx + dx + w/2, cy + dy - d/2, cy + dy + d/2, -4, z, mat("stone"))
    R = mat("rail")
    for nm, p0, p1 in (("RailBank", (-28.5, -89.5), (-24.5, -81.5)), ("RailEnd", (-7.3, -81.1), (-2.7, -86.9))):
        beam(c, nm, p0, p1, 1.8, 2.3, 0.4, R)
        for t in (0, 0.5, 1):
            x, y = p0[0] + t * (p1[0] - p0[0]), p0[1] + t * (p1[1] - p0[1])
            box(c, nm + "Post", x - 0.4, x + 0.4, y - 0.4, y + 0.4, -3, 2.6, R)
    col_box("WaterBed", HUB_XL, -1, -210, -81, -4, -1.5)

def build_portal():
    """World 2 portal on the grass wedge by the lane branch (hub_overview's pale upright is the same portal as the
    blue-framed magenta opening in the treadmill close-up's right foreground: it projects there). Turned 45 degrees."""
    c = coll("Portal"); m, core = mat("portal_shell"), mat("portal_core", emit=0.6)
    cx, cy = -16, 28.5
    parts = [box(c, "Base", cx - 2.5, cx + 2.5, cy - 7.5, cy + 7.5, 0, 0.8, m),
             box(c, "PillarL", cx - 1.5, cx + 1.5, cy - 6, cy - 4, 0.8, 10, m), box(c, "PillarR", cx - 1.5, cx + 1.5, cy + 4, cy + 6, 0.8, 10, m),
             box(c, "StepL", cx - 1.5, cx + 1.5, cy - 5, cy - 3, 10, 11.5, m), box(c, "StepR", cx - 1.5, cx + 1.5, cy + 3, cy + 5, 10, 11.5, m),
             box(c, "ArchTop", cx - 1.5, cx + 1.5, cy - 3.5, cy + 3.5, 11.5, 13, m),
             box(c, "Core", cx - 0.3, cx + 0.3, cy - 4, cy + 4, 0.8, 11.5, core),
             col_box("Portal", cx - 1.5, cx + 1.5, cy - 6, cy + 6, 0, 13)]
    turn(parts, cx, cy, -45)

def build_lane():
    """15 bays of 48 (two starter bays, then stages 2..14), measured on lane_view through its solved camera: red mat
    26x24 right of centre with 2 dark markers by its right edge, yellow tile nearer and magenta tile farther on the left,
    thin lime dividers between grey curbs, dark edging along both wall seams."""
    c = coll("Lane"); g = coll("Stage_Frames"); u = coll("Stage_Frames_Unlocked")
    h = LANE_HW; W = mat("lane")
    box(c, "LaneFloor", -h, h, LANE_Y0 - 1, LANE_Y1, -1, 0, W)
    box(c, "EdgeL", -h, -h + 1.5, LANE_Y0 - 1, LANE_Y1, 0, 0.4, mat("trim")); box(c, "EdgeR", h - 1.5, h, LANE_Y0 - 1, LANE_Y1, 0, 0.4, mat("trim"))
    for i in range(BAYS):
        y = LANE_Y0 + i * BAY_P; n = f"Bay{i+1:02d}_"
        if i > 0:
            box(c, n + "CurbA", -h + 1.5, h - 1.5, y - 2, y - 1, 0, 0.5, mat("trim"))
            box(c, n + "Divider", -h + 1.5, h - 1.5, y - 1, y + 1, 0, 0.3, mat("divider"))
            box(c, n + "CurbB", -h + 1.5, h - 1.5, y + 1, y + 2, 0, 0.5, mat("trim"))
        box(c, n + "RedMat", -6, 20, y + 11, y + 35, 0, 0.5, mat("stage_red"))
        box(c, n + "Marker1", 12, 16, y + 15.5, y + 20.5, 0.5, 0.8, mat("marker"))
        box(c, n + "Marker2", 12, 16, y + 25, y + 30, 0.5, 0.8, mat("marker"))
        for nm, a, b, key in (("Yellow", 8, 19, "tile_yellow"), ("Magenta", 27, 38, "tile_magenta")):
            box(c, n + nm + "Shim", -22.2, -13.8, y + a - 0.2, y + b + 0.2, 0, 0.2, mat("pad_black"))
            box(c, n + nm, -22, -14, y + a, y + b, 0.2, 0.6, mat(key))
    for s in range(2, 15):
        stage_gate(u if s < 4 else g, s, LANE_Y0 + s * BAY_P)
    col_box("LaneFloor", -h, h, LANE_Y0, LANE_Y1, -1, 0)

def stage_gate(c, stage, y):
    """Slender posts at the walls, a thin top beam with short end extensions, a tinted pane at 16% (lane_view: 50 wide, 24 high)."""
    name = STAGE_GATE[stage]; m = pmat(name); pane = pmat(name, alpha=0.16, emit=0.2)
    h, t, Hh = LANE_HW, 1.0, 24
    g = _merge(c, f"Stage{stage:02d}_Gate", [(-h, -h + t, y - 0.5, y + 0.5, 0, Hh), (h - t, h, y - 0.5, y + 0.5, 0, Hh),
                                              (-h - 1, h + 1, y - 0.5, y + 0.5, Hh - 1, Hh)], m)
    box(c, f"Stage{stage:02d}_Pane", -h + t, h - t, y - 0.1, y + 0.1, 0, Hh - 1, pane)
    return g

def build_walls():
    c = coll("Walls"); terrain_mesh(c); D = 2 * WALL_T + LEDGE
    for nm, a, b, cc, d in (("HubL", HUB_XL - D, HUB_XL, BACK_Y, HUB_YF), ("HubR", HUB_XR, HUB_XR + D, BACK_Y, HUB_YF_R),
                            ("FrontL", HUB_XL, -LANE_HW, HUB_YF, HUB_YF + D), ("FrontR", LANE_HW, HUB_XR, HUB_YF_R, HUB_YF_R + D),
                            ("LaneL", -LANE_HW - D, -LANE_HW, HUB_YF, LANE_Y1), ("LaneR", LANE_HW, LANE_HW + D, HUB_YF_R, LANE_Y1),
                            ("LaneEnd", -LANE_HW, LANE_HW, LANE_Y1, LANE_Y1 + D), ("Back", HUB_XL, HUB_XR, BACK_Y - D, BACK_Y)):
        col_box(nm, a, b, cc, d, 0, WALL_H2)

# ---------------------------------------------------------------- trees and shrubs ---
def tree_stepped(c, name, x, y, z, s=1.0, pale=False):
    """Stepped conifer: square tiers with thin gaps, squat trunk with squared feet (lane_view, terraceA_closeup)."""
    T = mat("bark_pale" if pale else "bark"); parts = []
    tw = 1.5 * s
    parts.append(box(c, name + "_Trunk", x - tw, x + tw, y - tw, y + tw, z, z + 9 * s, T))
    for (a, b, cc, d) in ((tw, tw + 3 * s, -0.8 * s, 0.8 * s), (-tw - 3 * s, -tw, -0.8 * s, 0.8 * s),
                          (-0.8 * s, 0.8 * s, tw, tw + 3 * s), (-0.8 * s, 0.8 * s, -tw - 3 * s, -tw)):
        parts.append(box(c, name + "_Foot", x + a, x + b, y + cc, y + d, z, z + 0.8, T))
    for k, (w, zz) in enumerate(((18, 7), (15, 10.6), (12, 14.2), (9, 17.8), (6, 21.4), (3, 25))):
        w *= s; zz *= s
        parts.append(box(c, name + f"_Tier{k}", x - w/2, x + w/2, y - w/2, y + w/2, z + zz, z + zz + 3.2 * s,
                         mat("leaf" if k % 2 == 0 else "leaf_dark")))
    return parts

def tree_cube(c, name, x, y, z, s=1.0):
    """Big cube-canopy tree: orange trunk with squared feet, offset block canopy (lane_view near-right tree)."""
    T = mat("bark"); L1, L2 = mat("leaf"), mat("leaf_sun"); tw = 2.0 * s
    box(c, name + "_Trunk", x - tw, x + tw, y - tw, y + tw, z, z + 14 * s, T)
    for (a, b, cc, d) in ((tw, tw + 4 * s, -1.2 * s, 1.2 * s), (-tw - 4 * s, -tw, -1.2 * s, 1.2 * s),
                          (-1.2 * s, 1.2 * s, tw, tw + 4 * s), (-1.2 * s, 1.2 * s, -tw - 4 * s, -tw)):
        box(c, name + "_Foot", x + a, x + b, y + cc, y + d, z, z + 1.0 * s, T)
    box(c, name + "_Canopy0", x - 9 * s, x + 9 * s, y - 9 * s, y + 9 * s, z + 12 * s, z + 22 * s, L1)
    box(c, name + "_Canopy1", x - 11 * s, x + 2 * s, y - 6 * s, y + 7 * s, z + 18 * s, z + 27 * s, L2)
    box(c, name + "_Canopy2", x + 1 * s, x + 10 * s, y - 4 * s, y + 6 * s, z + 20 * s, z + 26 * s, L2)

# Phase 3 (v03): each tree type is built once in Shared > Library (excluded from the view layer) and placed as
# collection instances, so every repeat is a linked copy of one prototype.
PROTOS = {}
def proto(kind):
    if kind in PROTOS: return PROTOS[kind]
    c = bpy.data.collections.new("Proto_" + kind); coll("Library").children.link(c)
    if kind == "stepped": tree_stepped(c, "TreeStepped", 0, 0, 0, 1.0)
    elif kind == "stepped_pale": tree_stepped(c, "TreeSteppedPale", 0, 0, 0, 1.0, pale=True)
    elif kind == "cube": tree_cube(c, "TreeCube", 0, 0, 0, 1.0)
    else: PROTO_BUILDERS[kind](c)
    PROTOS[kind] = c
    return c
PROTO_BUILDERS = {}

def inst(c, name, kind, x, y, z, s=1.0, rot=0.0):
    e = bpy.data.objects.new(name, None); e.instance_type = 'COLLECTION'; e.instance_collection = proto(kind)
    e.location = (x, y, z); e.scale = (s, s, s); e.rotation_euler = (0, 0, math.radians(rot)); c.objects.link(e)
    return e

# ---------------------------------------------------------------- Phase 4: Alex's studded treadmills ---
# Appended unchanged from ChessTreadmills/studded/<Name>/<Name>.blend (colliders, cameras and preview lights left out).
# Each machine is one prototype in Shared > Library and is placed as an instance; the two red centre machines are two
# instances of the same RookRig. Root = floor centre, entry facing -Y, so +90 degrees turns the entry toward the path (+x).
MACH_DIR = "/Users/Alex/ROBLOX/ChessTreadmills/studded/"
def _machine_builder(name):
    def b(c):
        with bpy.data.libraries.load(f"{MACH_DIR}{name}/{name}.blend", link=False) as (src, dst):
            dst.collections = [name]
        mc = dst.collections[0]
        for o in list(mc.all_objects):
            if o.name.startswith(("COL_", "Cam_", "Preview_")): bpy.data.objects.remove(o, do_unlink=True)
            else: o["keep_uv"] = True
        c.children.link(mc)
    return b
# terraceA_closeup, matched by colour to the machines (machine centres back-projected with cam_tread):
#   front row on the four footprints: yellow, red, red, blue; rear shelf: dark-red (x8), black-gold (x999),
#   white-gold (x99), purple (x12)
# v04c: front row 5 studs nearer the path and rear row 3 further back (front edges vs terraceA_closeup at ~9 px/stud)
MACHINES = [("KingsEndgame", -56.5, -42, 1.0), ("RookRig", -56.5, -7.5, 1.0), ("RookRig", -56.5, 7.5, 1.0),
            ("KnightSprint", -56.5, 42, 1.0), ("QueenDash", -104, -35, 2.6), ("CosmicGrandmaster", -104, -11.5, 2.6),
            ("RoyalCastle", -104, 11.5, 2.6), ("BishopRun", -104, 35, 2.6)]
# The game's stations read about 1.4x the size of Alex's 9-12 stud models (terraceA_closeup: the red pair spans
# ~13.4 studs across at the footprints, the rear purple ~16), so the instances are scaled, not remodelled.
MACH_S = 1.4
def build_machines():
    c = coll("Machines")
    for k, (name, x, y, z) in enumerate(MACHINES):
        PROTO_BUILDERS.setdefault(name, _machine_builder(name))
        inst(c, f"Machine{k+1}_{name}", name, x, y, z, MACH_S, 90)

# ---------------------------------------------------------------- Phase 4: blocky props (compare/props.md) ---
def emat(name, hexcol, strength=2.5, alpha=1.0):
    """Glowing prop material (bloom picks it up); colours sampled from the screenshots."""
    key = ("emit", name)
    if key in MATS: return MATS[key]
    m = bpy.data.materials.new("Glow_" + name); m.use_nodes = True; b = m.node_tree.nodes["Principled BSDF"]
    c = lin(hexcol); b.inputs["Base Color"].default_value = (*c, 1); b.inputs["Roughness"].default_value = 0.4
    b.inputs["Emission Color"].default_value = (*c, 1); b.inputs["Emission Strength"].default_value = strength
    if alpha < 1:
        b.inputs["Alpha"].default_value = alpha
        try: m.surface_render_method = 'BLENDED'
        except Exception: m.blend_method = 'BLEND'
    m.diffuse_color = (*c, alpha); MATS[key] = m
    return m

def smat(name, hexcol, rough=0.6):
    key = ("solid", name)
    if key in MATS: return MATS[key]
    m = bpy.data.materials.new("Prop_" + name); m.use_nodes = True; b = m.node_tree.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value = (*lin(hexcol), 1); b.inputs["Roughness"].default_value = rough
    m.diffuse_color = (*lin(hexcol), 1); MATS[key] = m
    return m

MESHES = {}
def shared_mesh(key, boxes):
    """One mesh per prop shape; every copy is a linked duplicate (same mesh data, its own object-level material)."""
    if key not in MESHES:
        tmp = _merge(coll("Library"), "tmp", boxes, None); me = tmp.data; me.name = "PR_" + key
        bpy.data.objects.remove(tmp); MESHES[key] = me
    return MESHES[key]

def place(c, name, key, boxes, m, x, y, z, rot=0.0, s=1.0):
    me = shared_mesh(key, boxes); ob = bpy.data.objects.new(name, me); c.objects.link(ob)
    if not me.materials: me.materials.append(m)
    ob.material_slots[0].link = 'OBJECT'; ob.material_slots[0].material = m
    ob.location = (x, y, z); ob.rotation_euler = (0, 0, math.radians(rot)); ob.scale = (s, s, s)
    return ob

GEM = [(-0.6, 0.6, -0.6, 0.6, 0, 0.6), (-0.8, 0.8, -0.8, 0.8, 0.6, 3.0), (-0.55, 0.55, -0.55, 0.55, 3.0, 4.0),
       (-0.25, 0.25, -0.25, 0.25, 4.0, 4.7)]                                   # blocky crystal, 4.7 tall
PHONE = [(-1.4, 1.4, -0.3, 0.3, 0.6, 5.0), (-0.9, 0.9, -0.5, 0.5, 0, 0.6)]      # upright phone slab on a foot
PHONE_SCREEN = [(-1.1, 1.1, -0.36, -0.3, 1.0, 4.6)]
LOCK = [(-0.75, 0.75, -0.3, 0.3, 0, 1.2), (-0.6, -0.35, -0.15, 0.15, 1.2, 2.0), (0.35, 0.6, -0.15, 0.15, 1.2, 2.0),
        (-0.6, 0.6, -0.15, 0.15, 2.0, 2.25)]
def build_props():
    # Phone stand (terraceB_closeup): screen left is +y. Gems over the six rear plinths, phones on the five pads,
    # padlocks over every locked item.
    c = coll("Props_Phone"); RIM, SHELF = 1.2, 5.0
    gems = ("22E3C2", "C9ECFF", "FF2448", "9CE635", "FFC93A", "5A35FF")
    for k, h in enumerate(gems):
        y = 32.5 - 13 * k
        place(c, f"Gem{k+1}", "gem", GEM, emat(f"Gem{k+1}", h, 3.0), 60.5, y, SHELF + 0.8, 45, 1.4)
        place(c, f"GemLock{k+1}", "lock", LOCK, smat("LockGold", "FFB81C", 0.35), 60.5, y, SHELF + 9.5, -90, 1.2)
    for k, h in enumerate(("FFB020", "E9EEF5", "FFA41C", "E9EEF5", "FFC63A")):
        y = 20 - 10 * k
        place(c, f"Phone{k+1}", "phone", PHONE, emat(f"Phone{k+1}", h, 1.6), 38, y, 0.85, -90)
        place(c, f"PhoneScreen{k+1}", "phone_screen", PHONE_SCREEN, emat("Screen", "FFF6D8", 4.0), 38, y, 0.85, -90)
    for k in (3, 4):
        place(c, f"PadLock{k+1}", "lock", LOCK, smat("LockGold", "FFB81C", 0.35), 44.5, 20 - 10 * k, 6.0, -90, 1.2)
    # Hub (hub_overview): Hologram Phone pad on the grass, the yellow-rimmed spawn marker by the lane mouth,
    # "1 Like = 1 Sub" painted on the front face of the block right of the lane.
    c = coll("Props_Hub")
    hx, hy = -18, -45
    _merge(c, "HoloPadFrame", [(hx - 3.5, hx + 3.5, hy - 3.5, hy - 2.8, 0, 0.6), (hx - 3.5, hx + 3.5, hy + 2.8, hy + 3.5, 0, 0.6),
                               (hx - 3.5, hx - 2.8, hy - 2.8, hy + 2.8, 0, 0.6), (hx + 2.8, hx + 3.5, hy - 2.8, hy + 2.8, 0, 0.6)],
           emat("HoloFrame", "8C3CFF", 1.2))
    box(c, "HoloPadFloor", hx - 2.8, hx + 2.8, hy - 2.8, hy + 2.8, 0, 0.3, smat("HoloFloor", "B583FF"))
    place(c, "HoloPhone", "phone", PHONE, emat("Holo", "7FF3FF", 2.0, 0.55), hx, hy, 0.3, 45)
    mx, my = 18, 50.5
    _merge(c, "MarkerRim", [(mx - 2, mx + 2, my - 2, my - 1.5, 0, 0.25), (mx - 2, mx + 2, my + 1.5, my + 2, 0, 0.25),
                            (mx - 2, mx - 1.5, my - 1.5, my + 1.5, 0, 0.25), (mx + 1.5, mx + 2, my - 1.5, my + 1.5, 0, 0.25)],
           emat("MarkerYellow", "FFD21E", 0.8))
    box(c, "MarkerFloor", mx - 1.5, mx + 1.5, my - 1.5, my + 1.5, 0, 0.2, smat("MarkerDark", "1E1E28"))
    for line, z in (("1 Like = 1", 16.0), ("Sub", 9.2)):
        cu = bpy.data.curves.new("SignText", 'FONT'); cu.body = line; cu.size = 5.4; cu.extrude = 0.15
        cu.align_x = 'CENTER'; cu.align_y = 'CENTER'
        t = bpy.data.objects.new("SignText", cu); c.objects.link(t)
        t.location = (36, HUB_YF_R - 0.2, z); t.rotation_euler = (math.radians(90), 0, 0)
        cu.materials.append(smat("SignWhite", "FFFFFF", 0.5))
        dg = bpy.context.evaluated_depsgraph_get(); me = bpy.data.meshes.new_from_object(t.evaluated_get(dg))
        o = bpy.data.objects.new("Sign_" + line.replace(" ", "").replace("=", "Eq"), me); o.matrix_world = t.matrix_world
        c.objects.link(o); bpy.data.objects.remove(t); bpy.data.curves.remove(cu)
        o["keep_uv"] = True

def build_foliage():
    c = coll("Foliage"); rnd = random.Random(8); Z = WALL_H2; k = 0
    D = 2 * WALL_T + LEDGE
    def plant(x, y, z, big=False):
        nonlocal k; k += 1; r = rnd.random()
        s = rnd.choice((0.8, 1.0, 1.2)) * (1.3 if big else 1.0)
        if r < 0.55: inst(c, f"Tree{k:03d}", "stepped_pale" if rnd.random() < 0.12 else "stepped", x, y, z, s, rnd.choice((0, 90)))
        else: inst(c, f"Tree{k:03d}", "cube", x, y, z, s * 0.85, rnd.choice((0, 90, 180, 270)))
    for y in range(BACK_Y + 10, HUB_YF + 30, 18): plant(HUB_XL - D - 9, y, Z); plant(HUB_XL - D - 26, y + 9, Z)
    for x in range(HUB_XL - 10, -LANE_HW - D - 8, 18): plant(x, HUB_YF + D + 9, Z); plant(x + 9, HUB_YF + D + 26, Z)
    for y in range(HUB_YF + D + 20, LANE_Y1, 20):
        plant(-LANE_HW - D - 9, y, Z); plant(-LANE_HW - D - 27, y + 10, Z)
        plant(LANE_HW + 2 * WALL_T + LEDGE_LANE_R + 9, y + 10, Z); plant(LANE_HW + 2 * WALL_T + LEDGE_LANE_R + 27, y, Z)
    for y in range(BACK_Y + 10, HUB_YF_R + 30, 18): plant(HUB_XR + 2 * WALL_T + LEDGE_R + 9, y, Z); plant(HUB_XR + 2 * WALL_T + LEDGE_R + 26, y + 9, Z)
    for y in range(-40, HUB_YF_R, 24): plant(HUB_XR + WALL_T + LEDGE_R / 2, y, WALL_H1)
    for t in range(0, 130, 17):
        plant(-6 - t * 0.7, -104 - t * 0.7, 0); plant(8 - t * 0.7, -112 - t * 0.7, 0)
    inst(c, "Tree_LaneMouthPine", "stepped", -37, 66, 0, 1.0)                     # hub: pine left of the lane mouth
    # hub_overview: two stepped trees at the treadmill stand's water end (bases back-projected to (-74,-65) and (-24,-67));
    # the first is also the big tiered tree at the left of terraceA_closeup (projects to x 458, trunk seen at ~470)
    inst(c, "Tree_TAWater1", "stepped", -74, -65, 0, 1.2); inst(c, "Tree_TAWater2", "stepped", -24, -68, 0, 1.1, 90)
    # terraceB_closeup: the two big trunks back-project to (55.7, -51.5) and (55.8, 50.5)
    inst(c, "Tree_PhoneL", "cube", 57, -53.5, 0, 1.35); inst(c, "Tree_PhoneR", "cube", 57, 52.5, 0, 1.35, 180)
    inst(c, "Tree_LaneAnchor", "cube", 46, 91, WALL_H2, 1.45)                      # big right-foreground tree in lane_view
    B, R = mat("shrub"), mat("stone")
    for (x, y) in ((13.5, -31.5), (-30, 16), (18.5, -63.4), (-47, -66.9), (44.5, 59.1), (-60.4, 66.7), (14.8, 42.3)):
        w = rnd.uniform(5.5, 7.5)
        box(c, "Shrub", x - w/2, x + w/2, y - w/2.5, y + w/2.5, 0, w * 0.5, B)
        box(c, "ShrubTop", x - w/4, x + w/4, y - w/5, y + w/5, w * 0.5, w * 0.8, B)
    for j in range(40):
        x = rnd.uniform(-32, 24); y = rnd.uniform(-76, 72)
        if abs(x) < 8 or abs(y) < 8: continue
        box(c, "Tuft", x - 0.3, x + 0.3, y - 0.3, y + 0.3, 0, rnd.uniform(1.0, 2.0), mat("grass_cap"))

# ---------------------------------------------------------------- scene, light, cameras ---
# Phase 5 lighting (v05): Standard view transform, sky sampled from terraceA_closeup/lane_view (64,185,254)
SKY, AMBIENT, SUN_E, SUN_TILT, EXPOSURE = "3FB6FF", 1.0, 3.1, 24, -0.5   # v06d: less fill, more sun: v06c side faces read G 210 vs screenshot 171-189;   # v06b read ~18/255 bright at -0.25   # v05a read ~15/255 bright at 0.0
def setup_scene():
    sc = bpy.context.scene
    ids = [e.identifier for e in bpy.types.RenderSettings.bl_rna.properties['engine'].enum_items]
    sc.render.engine = 'BLENDER_EEVEE_NEXT' if 'BLENDER_EEVEE_NEXT' in ids else 'BLENDER_EEVEE'
    sc.view_settings.view_transform = 'Standard'; sc.view_settings.exposure = 0.0
    try: sc.eevee.taa_render_samples = 24
    except Exception: pass
    w = bpy.data.worlds.new("Daylight"); sc.world = w; w.use_nodes = True
    bg = w.node_tree.nodes["Background"]; bg.inputs[0].default_value = (*lin("EEF2F6"), 1); bg.inputs[1].default_value = AMBIENT
    WN = w.node_tree.nodes; WL = w.node_tree.links
    sky = WN.new("ShaderNodeBackground"); sky.inputs[0].default_value = (*lin(SKY), 1); sky.inputs[1].default_value = 1.0
    lp = WN.new("ShaderNodeLightPath"); mx = WN.new("ShaderNodeMixShader")
    WL.new(lp.outputs["Is Camera Ray"], mx.inputs[0]); WL.new(bg.outputs[0], mx.inputs[1]); WL.new(sky.outputs[0], mx.inputs[2])
    WL.new(mx.outputs[0], WN["World Output"].inputs["Surface"])
    sun = bpy.data.objects.new("Sun", bpy.data.lights.new("Sun", 'SUN'))
    sun.data.energy = SUN_E; sun.data.angle = math.radians(6); sun.data.color = (1.0, 0.97, 0.9)   # soft shadow edges
    # screenshots: faces looking +x lit, faces looking -x in shade; the lane floor is fully lit between 24.6-high banks,
    # so the sun is high (63 degrees): a 49 degree sun shaded half the lane floor (lane stone 28/255 too dark in v01-v04)
    sun.rotation_euler = (math.radians(12), math.radians(SUN_TILT), 0)
    sc.view_settings.exposure = EXPOSURE
    try:   # bloom on the glowing props (Blender 5 compositor node group)
        ng = bpy.data.node_groups.new("Bloom", "CompositorNodeTree")
        ng.interface.new_socket("Image", in_out="OUTPUT", socket_type="NodeSocketColor")
        rl = ng.nodes.new("CompositorNodeRLayers"); gl = ng.nodes.new("CompositorNodeGlare"); on = ng.nodes.new("NodeGroupOutput")
        gl.inputs["Type"].default_value = "Bloom"; gl.inputs["Threshold"].default_value = 1.0
        gl.inputs["Strength"].default_value = 0.8; gl.inputs["Size"].default_value = 0.55
        ng.links.new(rl.outputs["Image"], gl.inputs["Image"]); ng.links.new(gl.outputs["Image"], on.inputs[0])
        sc.compositing_node_group = ng; sc.render.use_compositing = True
    except Exception as ex:
        print("bloom not set up:", ex)
    coll("CAMERAS").objects.link(sun)

# Locked cameras, solved from the screenshots (analysis/fit_hub70.py, fit_tread.py, fit_phone.py, fit_lane.py).
# name: (location, euler XYZ degrees, vertical FOV, render size, reference crop box in the render or None)
CAMS = {
    "CAM_Hub":      ((47.504, -88.334, 92.453), (42.058, -3.169, 34.827), 70, (3014, 1716), None),
    "CAM_Treadmill": ((2.57, -0.635, 22.181), (63.1578, 0.0, 87.669), 70, (3024, 1734), None),
    # the phone screenshot is a 2024x796 crop of a 3024x1734 frame at (574,146) (found by matching the HUD), so this
    # camera renders the whole frame at half size and the comparison crops it
    # renders the 2024x796 screenshot box directly: 70 deg frame narrowed to 35.638 and shifted (in frame heights)
    "CAM_Phone":    ((-16.035, 0.401, 27.308), (53.7473, 0.0, -88.235), 35.638, (2024, 796), (0.09296, 0.40578)),
    "CAM_Lane":     ((16.497, 47.898, 62.509), (63.1349, 0.0, 9.0106), 70, (3016, 1742), None),
    "CAM_Overhead": ((-20, 330, 700), (0, 0, 90), None, (2160, 680), None),
}

def camera(name, loc, rot, vfov, shift=None):
    cd = bpy.data.cameras.new(name)
    if shift: cd.shift_x, cd.shift_y = shift
    if vfov: cd.sensor_fit = 'VERTICAL'; cd.angle = math.radians(vfov)
    else: cd.type = 'ORTHO'; cd.ortho_scale = 1150
    cd.clip_start = 0.5; cd.clip_end = 4000
    ob = bpy.data.objects.new(name, cd); coll("CAMERAS").objects.link(ob)
    ob.location = loc; ob.rotation_euler = tuple(math.radians(a) for a in rot)
    return ob

def build(clay=False, ver="v01"):
    global CLAY
    CLAY = clay
    bpy.ops.wm.read_homefile(use_empty=True)
    COLLS.clear(); MATS.clear(); PACKMAP.clear(); PROTOS.clear(); MESHES.clear()
    for a in AREAS: coll(a)
    setup_scene()
    build_hub(); build_terrace_a(); build_terrace_b(); build_water(); build_portal()
    build_lane(); build_walls(); build_foliage(); build_machines(); build_props()
    col = bpy.data.collections["COLLISION"]
    for ob in bpy.data.objects:
        if ob.type != 'MESH': continue
        if ob.get("keep_uv"): continue                          # Alex's machines keep their own UVs and shading
        planar_uvs(ob)
        for p in ob.data.polygons: p.use_smooth = False          # hard edges, no bevels
    for n, (loc, rot, vf, size, shift) in CAMS.items(): camera(n, loc, rot, vf, shift)
    if "Library" in COLLS:
        bpy.context.view_layer.layer_collection.children["Shared"].children["Library"].exclude = True
    for img in bpy.data.images:
        if img.source == 'FILE' and not img.packed_file: img.pack()
    bpy.context.scene.camera = bpy.data.objects["CAM_Hub"]
    out = V3 + f"scene_{ver}" + ("_clay" if clay else "") + ".blend"
    assert "Reference_Fix" not in out
    bpy.ops.wm.save_as_mainfile(filepath=out)
    return len(bpy.data.objects)

def render_all(tag, only=None):
    """Phase comparison: renders every view at the screenshot's size and writes v3/compare/<view>_<tag>.png."""
    ns = {}; exec(open(V3 + "scripts/compare.py").read(), ns); return ns["compare"](tag, only)

# ---------------------------------------------------------------- export and checks ---
def export_fbx():
    """One FBX per map collection (Roblox: -Z forward, Y up, transforms baked), plus the textures beside them."""
    import io, contextlib
    os.makedirs(V3 + "export", exist_ok=True)
    win = bpy.context.window_manager.windows[0]; vl = bpy.context.view_layer; out = []
    for c in bpy.data.collections:
        if c.name in ("CAMERAS", "COLLISION") or not c.objects: continue
        obs = [o for o in c.objects if o.type == 'MESH']
        if not obs: continue
        with bpy.context.temp_override(window=win, selected_objects=obs, view_layer=vl, active_object=obs[0]):
            with contextlib.redirect_stdout(io.StringIO()):
                bpy.ops.export_scene.fbx(filepath=f"{V3}export/{c.name}.fbx", use_selection=True, axis_forward='-Z', axis_up='Y',
                                         bake_space_transform=True, apply_scale_options='FBX_SCALE_ALL', path_mode='COPY', embed_textures=False)
        out.append(c.name)
    return out

def verify(ver="v01"):
    """Reopen the saved file: every image packed and loaded, every material present; routes join without gaps."""
    bpy.ops.wm.open_mainfile(filepath=V3 + f"scene_{ver}.blend")
    imgs = [i for i in bpy.data.images if i.source == 'FILE']
    unpacked = [i.name for i in imgs if not i.packed_file]
    bad = [i.name for i in imgs if not i.has_data and not (i.pixels and len(i.pixels))]
    mats = sorted(m.name for m in bpy.data.materials if m.users)
    def bb(n):
        o = bpy.data.objects[n]; cs = [o.matrix_world @ Vector(c) for c in o.bound_box]
        return min(c.x for c in cs), max(c.x for c in cs), min(c.y for c in cs), max(c.y for c in cs)
    ca, cb, pm = bb("PathCrossA"), bb("PathCrossB"), bb("PathMain")
    ta, tb, lane = bb("LowerDeck"), bb("Apron"), bb("LaneFloor")
    routes = {"path->treadmill stand gap": round(ca[0] - ta[1], 2), "path->phone stand gap": round(tb[0] - cb[1], 2),
              "main path->lane gap": round(lane[2] - pm[3], 2), "lane length": round(lane[3] - lane[2], 1)}
    return {"images": len(imgs), "unpacked": unpacked, "unreadable": bad, "materials": len(mats), "routes": routes}
