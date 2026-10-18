-- The knife you wear (owner, Oct 18: "be shown on the back of the character"; "or even for the katanas you can
-- make it be on the side of the person"), placed exactly as HuzzServer/KnifeService places it: Shared/KnifeLook's
-- wearOf / wornC0 measured from the owner's real models (assets/knives/HuzzKnives.rbxm), drawn with his meshes.
-- One still from behind, three-quarter: a blocky R15 with a short Common (Rusty Shiv) on the back, a blocky R6 with
-- the long Mythic (Abyss Eclipse) on the back, and an R15 with Celestial Edge (the one long slim blade) at the hip.
-- python3 -I tools/knives/knife_meshes.py /tmp/knives.json   (from huzz-valley/), then from the repo root:
-- KNIFE_MESHES=/tmp/knives.json MOTION3D_KEEP=<dir> sh huzz-valley/tools/preview/motion3d/video.sh \
--   huzz-valley/tools/preview/motion3d/knife_wear_scene.luau /tmp/x.mp4   (the picture is <dir>/still_0.png)
local fs = require("@lune/fs")
local serde = require("@lune/serde")
local process = require("@lune/process")
local roblox = require("@lune/roblox")
local CFrame, Vector3 = roblox.CFrame, roblox.Vector3
local Rig = require("./rig")
local Scene = require("./scene")
local KFS = require("./kfs")
local Env = require("./env")
local SHARED = "huzz-valley/src/ReplicatedStorage/Shared/"
local Mix = Env.load(SHARED .. "LocomotionMix.lua")
local KnifeLook = Env.load(SHARED .. "KnifeLook.lua")

local MESHES = process.env.KNIFE_MESHES or error("set KNIFE_MESHES (python3 -I tools/knives/knife_meshes.py <file>)")
local baked = {}
for _, k in serde.decode("json", fs.readFile("huzz-valley/tools/knives/knives.json")) do baked[k.key] = k end
local models = {}
for _, m in roblox.deserializeModel(fs.readFile("huzz-valley/assets/knives/HuzzKnives.rbxm"))[1]:GetChildren() do models[m.Name] = m end
local function shapeOf(key)
	local m = models[key]
	local h = m:FindFirstChild("Handle")
	local parts = {}
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") then table.insert(parts, { name = d.Name, cf = h.CFrame:ToObjectSpace(d.CFrame), size = d.Size }) end
	end
	return KnifeLook.shape(parts)
end

local lib = roblox.Instance.new("Folder")
for _, inst in roblox.deserializeModel(fs.readFile("huzz-valley/src/ServerStorage/HuzzAnimations.rbxm")) do inst.Parent = lib end
local Idle = KFS.load(lib:FindFirstChild("Idle", true))

-- .glb axes (blade +Y, thickness Z) into the Handle's (blade +Y, thickness X), origin at the grip's middle.
local TURN = CFrame.fromMatrix(Vector3.zero, Vector3.new(0, 0, -1), Vector3.new(0, 1, 0), Vector3.new(1, 0, 0))
local function knifeAt(key, handleCF)
	local k = baked[key]
	local per = k.studs / k.length
	local cf = handleCF * CFrame.new(0, -k.grip * per, 0) * TURN
	local c = { cf:GetComponents() }
	return { m = key, p = { c[1], c[2], c[3] }, r = { c[4], c[5], c[6], c[7], c[8], c[9], c[10], c[11], c[12] }, s = per },
		handleCF * Vector3.new(0, (k.tip - k.grip) * per * 0.5, 0)
end

local scene = Scene.new()
for i = -4, 4 do
	for j = -3, 3 do scene:addBox(CFrame.new(i * 4, 0.03, j * 4), Vector3.new(0.4, 0.06, 0.4), "#b9a06a") end
end
local SET = {
	{ kind = "R15", key = "RustyShiv", x = -4.6, shirt = "#3a6fd8", pants = "#2b2f3a", label = "R15 · Rusty Shiv · Common" },
	{ kind = "R6", key = "AbyssEclipse", x = 0, shirt = "#e0e0e6", pants = "#3b2a5a", label = "R6 · Abyss Eclipse · Mythic" },
	{ kind = "R15", key = "SpinKnife", x = 4.8, turn = 75, shirt = "#3a7a3a", pants = "#20242c", label = "R15 · Celestial Edge · at the hip" },
}
local meshes, lights, labels = {}, {}, {}
for i, s in SET do
	local rig = scene:addRig(if s.kind == "R15" then Rig.r15("Body" .. i, { shirt = s.shirt, pants = s.pants }) else Rig.r6("Body" .. i, { shirt = s.shirt, pants = s.pants }))
	-- (the hip one turns to face left, so its left side, where the sword hangs, faces the camera)
	rig.root.CFrame = CFrame.new(s.x, if s.kind == "R15" then Rig.REST_HEIGHT else 3, 0) * CFrame.Angles(0, math.rad(s.turn or 0), 0)
	if s.kind == "R15" then
		local mix = Mix.new()
		Mix.step(mix, 1, { speed = 0, state = "ground", lengths = { Walk = 1, Run = 1 } })
		KFS.apply(Idle, rig, 0.5 + i * 0.4, 1)
	end
	Rig.fk(rig)
	local shape = shapeOf(s.key)
	local wear = KnifeLook.wearOf(models[s.key]:GetAttribute("Wear"), shape)
	local torso = rig.parts[KnifeLook.mountPart(wear, s.kind == "R6")]
	local handleCF = torso.CFrame * KnifeLook.wornC0(wear, torso.Name, torso.Size, shape) -- (Grip = the Handle's centre)
	local m, mid = knifeAt(s.key, handleCF)
	table.insert(meshes, m)
	local fx, k = KnifeLook.fx(baked[s.key].rarity), baked[s.key]
	if fx.back and fx.glow and k.glow then -- (Legendary and up keep their glow while worn; render.mjs reads about twice Studio's)
		table.insert(lights, { p = { mid.X, mid.Y, mid.Z }, c = "#" .. k.glow, b = fx.glow.brightness * 0.5, r = fx.glow.range })
	end
	table.insert(labels, s.label)
	print(string.format("%s %s: %s on %s", s.kind, s.key, wear, torso.Name))
end
local caption = "Left to right: " .. table.concat(labels, "   |   ")
scene:frame(Vector3.new(-3.2, 4.4, 12.5), Vector3.new(0.4, 2.4, 0), { meshes = meshes, lights = lights, caption = caption, fov = 46 })
scene:save(nil, 30, 1600, 900, { stills = { 0 }, meshFile = MESHES })
