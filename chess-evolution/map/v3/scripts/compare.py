# Phase 0 comparison loop for the v3 recreation (runs inside Blender 5.x, numpy only, no PIL needed).
#   exec(open(".../v3/scripts/compare.py").read()); compare("v00")
# For each camera it renders the open scene at the screenshot's exact resolution and writes
#   compare/<name>_vNN.png  = screenshot | render | 50% overlay (half size, left to right)
#   compare/renders/<name>_vNN.png = the full-size render
# and appends the mean colour difference per view to compare/metrics.json. It never saves the .blend.
import bpy, numpy as np, os, math, json

V3 = "/Users/Alex/ROBLOX/chess-evolution/map/v3/"
F70 = (1734 / 2) / math.tan(math.radians(35))      # Roblox 70 degree vertical FOV, in pixels of a 1734-high frame
# name: camera, screenshot, exact size, phone crop (the phone screenshot is a 2024x796 crop of a 3024x1734 frame at (574,146))
VIEWS = {
    "hub":       ("CAM_Hub", "refs/hub.png", (3014, 1716), None),
    "treadmill": ("CAM_Treadmill", "refs/treadmill.png", (3024, 1734), None),
    "phone":     ("CAM_Phone", "refs/phone.png", (2024, 796), (574, 146, 3024, 1734)),
    "lane":      ("CAM_Lane", "refs/lane.png", (3016, 1742), None),
}

def _set_cam(cam, size, crop):
    cd = bpy.data.objects[cam].data
    cd.sensor_fit = 'VERTICAL'; cd.shift_x = cd.shift_y = 0.0
    if crop:
        x0, y0, FW, FH = crop; w, h = size
        cd.angle = 2 * math.atan((h / 2) / F70)
        cd.shift_x = (x0 + w / 2 - FW / 2) / h       # with VERTICAL sensor fit Blender measures shift in frame
        cd.shift_y = (FH / 2 - (y0 + h / 2)) / h       # heights (checked: 0.59/255 mean difference vs the cropped full frame)
    else:
        cd.angle = math.radians(70)

def render_view(name, tag, samples=None):
    cam, ref, size, crop = VIEWS[name]
    sc = bpy.context.scene; sc.camera = bpy.data.objects[cam]; _set_cam(cam, size, crop)
    u = bpy.data.collections.get("Stage_Frames_Unlocked")
    if u: u.hide_render = (cam == "CAM_Lane")        # lane_view was taken after stages 2 and 3 were unlocked
    sc.render.resolution_x, sc.render.resolution_y = size; sc.render.resolution_percentage = 100
    sc.render.image_settings.file_format = 'PNG'; sc.render.image_settings.color_mode = 'RGB'
    if samples:
        try: sc.eevee.taa_render_samples = samples
        except Exception: pass
    os.makedirs(V3 + "compare/renders", exist_ok=True)
    out = f"{V3}compare/renders/{name}_{tag}.png"; sc.render.filepath = out
    bpy.ops.render.render(write_still=True)
    return out

def _load(path):
    im = bpy.data.images.load(path, check_existing=False)
    w, h = im.size; a = np.empty(w * h * 4, np.float32); im.pixels.foreach_get(a)
    bpy.data.images.remove(im)
    return a.reshape(h, w, 4)[:, :, :3]               # bottom row first, same for every image here

def _half(a):
    h, w = a.shape[0] // 2 * 2, a.shape[1] // 2 * 2
    a = a[:h, :w]; return a.reshape(h // 2, 2, w // 2, 2, 3).mean(axis=(1, 3))

def _save(a, path):
    h, w = a.shape[:2]; rgba = np.ones((h, w, 4), np.float32); rgba[:, :, :3] = np.clip(a, 0, 1)
    im = bpy.data.images.new("cmp_tmp", w, h, alpha=False); im.pixels.foreach_set(rgba.ravel())
    im.filepath_raw = path; im.file_format = 'PNG'; im.save(); bpy.data.images.remove(im)

def sheet(name, tag):
    cam, ref, size, crop = VIEWS[name]
    R = _half(_load(V3 + ref)); r = _half(_load(f"{V3}compare/renders/{name}_{tag}.png"))
    o = 0.5 * R + 0.5 * r; gap = np.ones((R.shape[0], 16, 3), np.float32)
    _save(np.concatenate([R, gap, r, gap, o], axis=1), f"{V3}compare/{name}_{tag}.png")
    return round(float(np.abs(R - r).mean() * 255), 1)

def compare(tag, only=None, samples=None):
    res = {}
    for name in VIEWS:
        if only and name not in only: continue
        render_view(name, tag, samples); res[name] = sheet(name, tag)
    mp = V3 + "compare/metrics.json"
    try: m = json.load(open(mp))
    except Exception: m = {}
    m.setdefault(tag, {}).update(res); json.dump(m, open(mp, "w"), indent=1)
    return res
