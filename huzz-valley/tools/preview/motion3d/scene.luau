-- Collects rigs and loose boxes, snapshots them once per frame, and saves the frames JSON that render.mjs draws.
local fs = require("@lune/fs")
local serde = require("@lune/serde")
local process = require("@lune/process")
local Rig = require("./rig")

local Scene = {}
Scene.__index = Scene

function Scene.new()
	return setmetatable({ rigs = {}, boxes = {}, frames = {} }, Scene)
end

function Scene:addRig(rig)
	table.insert(self.rigs, rig)
	return rig
end

-- A loose box (ground props, a target marker...). Move it later by setting box.CFrame.
function Scene:addBox(cframe, size, color)
	local box = { CFrame = cframe, Size = size, Color = color or "#a0a0a0" }
	table.insert(self.boxes, box)
	return box
end

local function r4(x) return math.floor(x * 10000 + 0.5) / 10000 end

-- b (optional): the box's look extras, as render.mjs reads them: Shape "ball", Neon, Alpha (opacity), Add, Emit (white fill)
local function snap(out, cf, size, color, b)
	local x, y, z, r00, r01, r02, r10, r11, r12, r20, r21, r22 = cf:GetComponents()
	table.insert(out, {
		p = { r4(x), r4(y), r4(z) },
		r = { r4(r00), r4(r01), r4(r02), r4(r10), r4(r11), r4(r12), r4(r20), r4(r21), r4(r22) },
		s = { r4(size.X), r4(size.Y), r4(size.Z) },
		c = color,
		sh = b and b.Shape or nil, n = b and b.Neon or nil, a = b and b.Alpha and r4(b.Alpha) or nil,
		add = b and b.Add or nil, e = b and b.Emit and r4(b.Emit) or nil,
	})
end

-- Snapshots every box as it is now. Run Rig.fk first.
-- extra (optional): { sprites, ribbons, lights, caption, fov, grades, overlay, env, bloom, labels, meshes } as render.mjs describes.
-- A rig's `look` table (Emit...) and a box's Shape/Neon/Alpha/Add/Emit/Hidden fields are passed on too.
function Scene:frame(cameraPos, lookAt, extra)
	local boxes = {}
	for _, rig in self.rigs do
		for _, b in Rig.boxes(rig) do snap(boxes, b.CFrame, b.Size, b.Color, rig.look) end
	end
	for _, b in self.boxes do
		if not b.Hidden then snap(boxes, b.CFrame, b.Size, b.Color, b) end
	end
	table.insert(self.frames, {
		camera = { pos = { r4(cameraPos.X), r4(cameraPos.Y), r4(cameraPos.Z) }, look = { r4(lookAt.X), r4(lookAt.Y), r4(lookAt.Z) } },
		boxes = boxes,
		sprites = extra and extra.sprites or nil,
		ribbons = extra and extra.ribbons or nil,
		lights = extra and extra.lights or nil,
		caption = extra and extra.caption or nil,
		fov = extra and extra.fov or nil,
		grades = extra and extra.grades or nil,
		overlay = extra and extra.overlay or nil,
		env = extra and extra.env or nil,
		bloom = extra and extra.bloom or nil,
		labels = extra and extra.labels or nil,
		meshes = extra and extra.meshes or nil,
	})
end

-- path defaults to $MOTION3D_DIR/frames.json (set by video.sh), else ./frames.json.
-- look (optional): { sky = "#hex", ground = "#hex", grid = false, dim = 0-1 (daylight), stills = { 0-based frame numbers },
--   meshFile = path of a triangle-mesh JSON (render.mjs: the owner's knives) }
function Scene:save(path, fps, w, h, look)
	path = path or ((process.env.MOTION3D_DIR or ".") .. "/frames.json")
	look = look or {}
	fs.writeFile(path, serde.encode("json", { fps = fps or 30, width = w or 1280, height = h or 720, frames = self.frames, sky = look.sky, ground = look.ground, grid = look.grid, dim = look.dim, stills = look.stills, meshFile = look.meshFile }))
	print(`frames: {#self.frames} -> {path}`)
end

return Scene
