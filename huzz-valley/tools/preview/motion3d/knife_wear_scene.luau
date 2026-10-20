-- The knife you wear (owner, Oct 18: "be shown on the back of the character"; Oct 19: "make the knifes when equipped
-- be worn either on the back of the character or on the side ... make the location based on what knife/sword it
-- is"), placed exactly as HuzzServer/KnifeService places it: the shop table's Wear (Config/CoinShop) and
-- Shared/KnifeLook's wornC0, measured from the owner's real models (his 30 in assets/knives/HuzzKnives.rbxm, the
-- stand-ins cut from his pass and Halloween .glb: Shared/KnifeShapes), drawn with his meshes.
-- Six bodies: three long blades on the back (R15 Abyss Eclipse, R6 Pumpkin King Katana, R15 Grand Witch Scythe: a
-- two-handed pole, worn head up) and three short knives at the right hip (R15 Rusty Shiv, R6 Scout Dagger, R15 Blood
-- Moon Tanto, the longest dagger). Two stills: from behind (still_0) and from the front, a little from their right where the hip knives hang (still_1).
-- python3 -I tools/knives/knife_meshes.py /tmp/knives.json   (from huzz-valley/), then from the repo root:
-- KNIFE_MESHES=/tmp/knives.json MOTION3D_KEEP=<dir> sh huzz-valley/tools/preview/motion3d/video.sh \
--   huzz-valley/tools/preview/motion3d/knife_wear_scene.luau /tmp/x.mp4
-- then python3 -I huzz-valley/tools/preview/motion3d/knife_wear_sheet.py <dir> (docs/previews/knife-on-back.jpg).
-- KNIFE_SET=solid (no KNIFE_MESHES needed): the plain-part stand-ins as every screen draws them when it can't show his
-- mesh (Shared/KnifeStandIns: wedge pairs, coloured layers 0.02 studs proud of the blade each side), worn by 11 bodies (the 5
-- pass knives and 6 Halloween ones, among them the four that hit the 200-part cap), each seen from about 3 studs
-- square on and from a second angle (still 2i-2, 2i-1), to look for seams between wedges and layers fighting the
-- blade; python3 -I huzz-valley/tools/preview/motion3d/knife_solid_sheet.py <dir> makes docs/previews/knife-solid-worn.jpg.
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
local CoinShop = Env.load(SHARED .. "Config/CoinShop.lua")
local Stand = Env.load(SHARED .. "KnifeStandIns.lua")

local SOLID = process.env.KNIFE_SET == "solid"
local MESHES = process.env.KNIFE_MESHES or (if SOLID then nil else error("set KNIFE_MESHES (python3 -I tools/knives/knife_meshes.py <file>)"))
local baked = {}
for _, k in serde.decode("json", fs.readFile("huzz-valley/tools/knives/knives.json")) do baked[k.key] = k end
local models = {}
for _, m in roblox.deserializeModel(fs.readFile("huzz-valley/assets/knives/HuzzKnives.rbxm"))[1]:GetChildren() do models[m.Name] = m end
-- the knife's measure as the game takes it: his model, else the stand-in cut from his .glb
local function shapeOf(key)
	local parts = {}
	local m = models[key]
	if m then
		local h = m:FindFirstChild("Handle")
		for _, d in m:GetDescendants() do
			if d:IsA("BasePart") then table.insert(parts, { name = d.Name, cf = h.CFrame:ToObjectSpace(d.CFrame), size = d.Size }) end
		end
	else
		for _, r in Stand[key].parts do
			table.insert(parts, { name = r[1], cf = CFrame.new(r[5], r[6], r[7]) * CFrame.Angles(math.rad(r[11] or 0), 0, 0), size = Vector3.new(r[2], r[3], r[4]) })
		end
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
if SOLID then
	local KEYS = { "CrimsonRequiem", "HollowEclipse", "CelestialSeraph", "DragonsMaw", "FrostboundOath", -- the pass knives
		"CandyReaper", "ThornKarambit", "ToadstoolSickle", "GrandWitchScythe", "TaffyKarambit", "CupcakeCleaver" }
	local GAPX = 8
	local cams = {}
	for i, key in KEYS do
		local x = (i - (#KEYS + 1) / 2) * GAPX
		local rig = scene:addRig(Rig.r15("Body" .. i, { shirt = "#3a6fd8", pants = "#2b2f3a" }))
		rig.root.CFrame = CFrame.new(x, Rig.REST_HEIGHT, 0)
		local mix = Mix.new()
		Mix.step(mix, 1, { speed = 0, state = "ground", lengths = { Walk = 1, Run = 1 } })
		KFS.apply(Idle, rig, 0.5 + i * 0.4, 1)
		Rig.fk(rig)
		local shape = shapeOf(key)
		local wear = KnifeLook.wearOf(CoinShop.get(key).Wear, shape)
		local torso = rig.parts[KnifeLook.mountPart(wear, false)]
		local handleCF = torso.CFrame * KnifeLook.wornC0(wear, torso.Name, torso.Size, shape)
		local n = 0
		for _, r in Stand[key].parts do
			if r[1] ~= "Handle" then
				n += 1
				local box = scene:addBox(handleCF * CFrame.new(r[5], r[6], r[7]) * CFrame.Angles(math.rad(r[11] or 0), 0, 0),
					Vector3.new(r[2], r[3], r[4]), "#" .. r[8])
				box.Neon = if r[9] == "Neon" then true else nil
				box.Shape = if r[12] == "W" then "wedge" else nil
			end
		end
		local mid = handleCF * Vector3.new(0, (shape.length or 2) * 0.3, 0)
		if wear == "Back" then -- (flat on the back: square on, then from up over the left shoulder)
			table.insert(cams, { mid + Vector3.new(0.6, 0.4, 2.9), mid })
			table.insert(cams, { mid + Vector3.new(-1.6, 1.7, 1.9), mid })
		else -- (at the right hip: from behind and to the right, then from the front right, under the arm)
			table.insert(cams, { mid + Vector3.new(1.4, 0.3, 2.6), mid })
			table.insert(cams, { mid + Vector3.new(2.5, -0.7, -1.4), mid })
		end
		print(string.format("%s: %s on %s, %d parts, %.2f studs", key, wear, torso.Name, n, shape.length))
	end
	local stills = {}
	for f, c in cams do
		scene:frame(c[1], c[2], { fov = 70 })
		table.insert(stills, f - 1)
	end
	scene:save(nil, 30, 960, 720, { stills = stills })
	return
end
for i = -6, 6 do
	for j = -3, 3 do scene:addBox(CFrame.new(i * 4, 0.03, j * 4), Vector3.new(0.4, 0.06, 0.4), "#b9a06a") end
end
local SET = {
	{ kind = "R15", key = "AbyssEclipse", shirt = "#3a6fd8", pants = "#2b2f3a" },
	{ kind = "R6", key = "PumpkinKingKatana", shirt = "#e0e0e6", pants = "#3b2a5a" },
	{ kind = "R15", key = "GrandWitchScythe", shirt = "#7a3a8a", pants = "#20242c" },
	{ kind = "R15", key = "RustyShiv", shirt = "#3a7a3a", pants = "#20242c" },
	{ kind = "R6", key = "ScoutDagger", shirt = "#d86a3a", pants = "#2b2f3a" },
	{ kind = "R15", key = "BloodMoonTanto", shirt = "#c8c8d0", pants = "#3a2a2a" },
}
local GAP = 3.9
local meshes, lights, labels = {}, {}, {}
for i, s in SET do
	local x = (i - (#SET + 1) / 2) * GAP
	local rig = scene:addRig(if s.kind == "R15" then Rig.r15("Body" .. i, { shirt = s.shirt, pants = s.pants }) else Rig.r6("Body" .. i, { shirt = s.shirt, pants = s.pants }))
	rig.root.CFrame = CFrame.new(x, if s.kind == "R15" then Rig.REST_HEIGHT else 3, 0)
	if s.kind == "R15" then
		local mix = Mix.new()
		Mix.step(mix, 1, { speed = 0, state = "ground", lengths = { Walk = 1, Run = 1 } })
		KFS.apply(Idle, rig, 0.5 + i * 0.4, 1)
	end
	Rig.fk(rig)
	local shape = shapeOf(s.key)
	local item = CoinShop.get(s.key)
	local wear = KnifeLook.wearOf(item.Wear, shape)
	local torso = rig.parts[KnifeLook.mountPart(wear, s.kind == "R6")]
	local handleCF = torso.CFrame * KnifeLook.wornC0(wear, torso.Name, torso.Size, shape) -- (Grip = the Handle's centre)
	local m, mid = knifeAt(s.key, handleCF)
	table.insert(meshes, m)
	local fx, k = KnifeLook.fx(baked[s.key].rarity), baked[s.key]
	if fx.back and fx.glow and k.glow then -- (Legendary and up keep their glow while worn; render.mjs reads about twice Studio's)
		table.insert(lights, { p = { mid.X, mid.Y, mid.Z }, c = "#" .. k.glow, b = fx.glow.brightness * 0.5, r = fx.glow.range })
	end
	local where = if wear == "Back" then "BACK" else "HIP"
	table.insert(labels, { p = { x, 7.05, 0 }, text = `{item.Name}`, h = 0.36, c = "#ffffff", o = "#000000" })
	table.insert(labels, { p = { x, 6.6, 0 }, text = `{s.kind} · {where} · {string.format("%.2f", shape.length)} studs`, h = 0.28, c = if wear == "Back" then "#9fe3ff" else "#ffd27a", o = "#000000" })
	print(string.format("%s %s: %s on %s (%.2f studs)", s.kind, s.key, wear, torso.Name, shape.length))
end
local look = { meshes = meshes, lights = lights, labels = labels, fov = 40 }
scene:frame(Vector3.new(0, 4.4, 23), Vector3.new(0, 3.6, 0), look) -- from behind
scene:frame(Vector3.new(9, 4.4, -21), Vector3.new(0, 3.6, 0), look) -- from the front, a little from their right (the hip knives' side)
scene:save(nil, 30, 1800, 760, { stills = { 0, 1 }, meshFile = MESHES })
