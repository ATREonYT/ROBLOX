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

local function snap(out, cf, size, color)
	local x, y, z, r00, r01, r02, r10, r11, r12, r20, r21, r22 = cf:GetComponents()
	table.insert(out, {
		p = { r4(x), r4(y), r4(z) },
		r = { r4(r00), r4(r01), r4(r02), r4(r10), r4(r11), r4(r12), r4(r20), r4(r21), r4(r22) },
		s = { r4(size.X), r4(size.Y), r4(size.Z) },
		c = color,
	})
end

-- Snapshots every box as it is now. Run Rig.fk first.
-- extra (optional): { sprites = {...}, ribbons = {...}, lights = {...}, caption = "text" } as render.mjs describes.
function Scene:frame(cameraPos, lookAt, extra)
	local boxes = {}
	for _, rig in self.rigs do
		for _, b in Rig.boxes(rig) do snap(boxes, b.CFrame, b.Size, b.Color) end
	end
	for _, b in self.boxes do snap(boxes, b.CFrame, b.Size, b.Color) end
	table.insert(self.frames, {
		camera = { pos = { r4(cameraPos.X), r4(cameraPos.Y), r4(cameraPos.Z) }, look = { r4(lookAt.X), r4(lookAt.Y), r4(lookAt.Z) } },
		boxes = boxes,
		sprites = extra and extra.sprites or nil,
		ribbons = extra and extra.ribbons or nil,
		lights = extra and extra.lights or nil,
		caption = extra and extra.caption or nil,
	})
end

-- path defaults to $MOTION3D_DIR/frames.json (set by video.sh), else ./frames.json.
-- look (optional): { sky = "#hex", ground = "#hex", grid = false, dim = 0-1 (daylight), stills = { 0-based frame numbers } }
function Scene:save(path, fps, w, h, look)
	path = path or ((process.env.MOTION3D_DIR or ".") .. "/frames.json")
	look = look or {}
	fs.writeFile(path, serde.encode("json", { fps = fps or 30, width = w or 1280, height = h or 720, frames = self.frames, sky = look.sky, ground = look.ground, grid = look.grid, dim = look.dim, stills = look.stills }))
	print(`frames: {#self.frames} -> {path}`)
end

return Scene
