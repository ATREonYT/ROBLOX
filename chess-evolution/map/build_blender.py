# Builds the hub map in Blender from hub_layout.json (1 Blender unit = 1 stud).
# Roblox (x, y, z) -> Blender (x, -z, y). Run inside Blender: exec(open(path).read()); build(json_path, blend_out)
import bpy, json, math

def _hex(h):
    h = h.lstrip("#"); return tuple(int(h[i:i+2], 16)/255 for i in (0, 2, 4))

def _srgb_to_lin(c):
    return c/12.92 if c <= 0.04045 else ((c+0.055)/1.055)**2.4

def build(json_path, blend_out):
    data = json.load(open(json_path))
    ref = data["ref_colors"]
    bpy.ops.wm.read_homefile(use_empty=True)
    sc = bpy.context.scene
    sc.unit_settings.system = 'NONE'
    mats = {}
    def mat(key, alpha=1.0):
        hexcol = ref.get(key, key)
        if (hexcol, alpha) in mats: return mats[(hexcol, alpha)]
        m = bpy.data.materials.new("M_" + key)
        m.use_nodes = True
        b = m.node_tree.nodes["Principled BSDF"]
        rgb = _hex(hexcol)
        b.inputs["Base Color"].default_value = (*[_srgb_to_lin(c) for c in rgb], 1)
        b.inputs["Roughness"].default_value = 0.8
        if alpha < 1:
            b.inputs["Alpha"].default_value = alpha
        m.diffuse_color = (*[_srgb_to_lin(c) for c in rgb], alpha)
        mats[(hexcol, alpha)] = m
        return m
    cols = {}
    for p in data["parts"]:
        g = p["group"]
        if g not in cols:
            cols[g] = bpy.data.collections.new(g); sc.collection.children.link(cols[g])
        x, y, z = p["pos"]; sx, sy, sz = p["size"]
        me = bpy.data.meshes.new(p["name"])
        import bmesh
        bm = bmesh.new(); bmesh.ops.create_cube(bm, size=1.0); bm.to_mesh(me); bm.free()
        ob = bpy.data.objects.new(p["name"], me)
        ob.location = (x, -z, y); ob.scale = (sx, sz, sy)
        ob.data.materials.append(mat(p["color"], 1 - p.get("transparency", 0)))
        cols[g].objects.link(ob)
    # sun + sky like a bright Roblox day
    sun = bpy.data.objects.new("Sun", bpy.data.lights.new("Sun", 'SUN'))
    sun.data.energy = 3.2; sun.rotation_euler = (math.radians(40), math.radians(15), math.radians(-35))
    sc.collection.objects.link(sun)
    w = bpy.data.worlds.new("Sky"); sc.world = w; w.use_nodes = True
    w.node_tree.nodes["Background"].inputs[0].default_value = (0.55, 0.75, 1.0, 1)
    w.node_tree.nodes["Background"].inputs[1].default_value = 1.2
    cam = bpy.data.objects.new("RefCam", bpy.data.cameras.new("RefCam"))
    sc.collection.objects.link(cam); sc.camera = cam
    sc.render.resolution_x, sc.render.resolution_y = 1507, 858   # reference aspect, half size
    try: sc.view_settings.view_transform = 'Standard'
    except Exception: pass
    bpy.ops.wm.save_as_mainfile(filepath=blend_out)
    return len(data["parts"])

def aim(cam_rbx, look_rbx, vfov_deg=70):
    """Place RefCam like a Roblox camera at cam_rbx looking at look_rbx (Roblox coords)."""
    from mathutils import Vector
    sc = bpy.context.scene; cam = sc.camera
    c = Vector((cam_rbx[0], -cam_rbx[2], cam_rbx[1])); l = Vector((look_rbx[0], -look_rbx[2], look_rbx[1]))
    cam.location = c
    cam.rotation_euler = (l - c).to_track_quat('-Z', 'Y').to_euler()
    cam.data.sensor_fit = 'VERTICAL'; cam.data.angle = math.radians(vfov_deg)
    cam.data.clip_end = 3000
