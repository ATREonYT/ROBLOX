-- The girls' effects tier by tier, for one still row (owner picked "Small flames", Oct 18: Rare and Epic get small calm
-- wrapping tongues, Legendary and up clearly bigger). Common, Uncommon, Rare, Epic, Legendary, Mythic, each as your
-- companion standing idle, same body, same camera (as girl_vfx_scene's idle shots). Each shot 2.6 s; the still is
-- taken 2.2 s in. Uses Shared/AuraLook.girl and aura_sim (the same data and maths Gameplay/AuraFX builds).
-- MOTION3D_KEEP=<dir> sh video.sh girl_tiers_scene.luau out.mp4, then python3 tools/fx/girl_tiers_sheet.py <dir>
local roblox = require("@lune/roblox")
local CFrame, Vector3 = roblox.CFrame, roblox.Vector3
local Rig = require("./rig")
local Scene = require("./scene")
local Env = require("./env")
local Sim = require("./aura_sim")
local SHARED = "huzz-valley/src/ReplicatedStorage/Shared/"
local AuraLook = Env.load(SHARED .. "AuraLook.lua")
local Looks = Env.load(SHARED .. "Config/GirlLooks.lua")
local Companion = Env.load(SHARED .. "Config/GirlMotion.lua").Companion

local FPS, DT = 30, 1 / 30
local SHOWS = { -- girl, rarity, name for the caption (no Uncommon girls yet: Ryo's look stands in)
	{ "CAC_R6_Zero57334_E2B7CE", "Common", "Ryo" },
	{ "CAC_R6_Zero57334_E2B7CE", "Uncommon", "Ryo's look" },
	{ "CAC_R6_GoodwinDakota422_AA2072", "Rare", "" },
	{ "CAC_R6_Master_Cheif4444_BB5C2C", "Epic", "Anko" },
	{ "CAC_R6_Raptus578_E86CB0", "Legendary", "Yuno" },
	{ "CAC_R6_ixKatsu_358858", "Mythic", "Megumin" },
}
local EACH, STILL_AT = 2.6, 2.2

local function scaleRig(rig, k)
	for _, p in rig.parts do p.Size *= k end
	for _, m in rig.motors do
		m.C0 = CFrame.new(m.C0.Position * k) * m.C0.Rotation
		m.C1 = CFrame.new(m.C1.Position * k) * m.C1.Rotation
	end
	for _, d in rig.decor do
		d.offset = CFrame.new(d.offset.Position * k) * d.offset.Rotation
		d.Size *= k
	end
	Rig.fk(rig)
end
local function bounds(rig)
	local lo, hi = Vector3.new(math.huge, math.huge, math.huge), -Vector3.new(math.huge, math.huge, math.huge)
	for _, p in rig.parts do
		if not p.hidden then
			local c = rig.root.CFrame:PointToObjectSpace(p.CFrame.Position)
			lo, hi = lo:Min(c - p.Size / 2), hi:Max(c + p.Size / 2)
		end
	end
	return CFrame.new((lo + hi) / 2), hi - lo
end

local scene = Scene.new()
local girl = scene:addRig(Rig.r15("Girl", { shirt = "#f06aa8", pants = "#3b2f5c", skin = "#f8dccb", hair = "#b88cf0", eyes = "#3a2350" }))
do
	local _, size = bounds(girl)
	scaleRig(girl, Companion.Height / size.Y)
end
local centre, size = bounds(girl)
local rootHeight = -(centre.Position.Y - size.Y / 2)
girl.root.CFrame = Rig.lookAt(Vector3.new(0, rootHeight, 0), Vector3.new(0, rootHeight, -1))
Rig.fk(girl)
for x = -12, 12, 4 do
	for z = -12, 12, 4 do
		scene:addBox(CFrame.new(x + 1.6, 0.05, z + 1.6), Vector3.new(1.4, 0.1, 1.4), "#56606e")
	end
end

local systems = {}
local shown = 0
local stills = {}
local cam, look = Vector3.new(5, 1.8, -2), Vector3.new(0, 1.3, 0)
for f = 0, math.floor(EACH * #SHOWS * FPS) - 1 do
	local t = f * DT
	local i = math.min(#SHOWS, math.floor(t / EACH) + 1)
	if i ~= shown then
		shown = i
		systems = {} -- (a clean start each shot: nothing left over from the one before)
		local lk = AuraLook.lookFor(Looks, SHOWS[i][1], nil)
		local spec = AuraLook.build(lk, SHOWS[i][2], "Companion")
		spec.scale = Companion.Height / 5
		table.insert(systems, Sim.new(girl, spec, { AuraLook = AuraLook }))
		local b = AuraLook.budget(spec)
		print(string.format("%-9s emitters %d, particles alive ~%.0f, beams %d", SHOWS[i][2], b.emitters, b.live, b.beams))
	end
	local inShot = t - (i - 1) * EACH
	if math.abs(inShot - STILL_AT) < DT / 2 then table.insert(stills, f) end
	-- a slow idle breath, so she isn't a statue
	girl.root.CFrame = Rig.lookAt(Vector3.new(0, rootHeight + 0.03 * math.sin(t * 2.4), 0), Vector3.new(0, rootHeight, -1))
	Rig.fk(girl)
	local sprites, ribbons, lights = {}, {}, {}
	for _, s in systems do
		Sim.step(s, DT)
		Sim.draw(s, cam, sprites, ribbons, lights)
	end
	scene:frame(cam, look, { sprites = sprites, ribbons = ribbons, lights = lights,
		caption = SHOWS[i][2], bloom = { i = 0.55, size = 22, th = 1.5 } })
end
scene:save(nil, FPS, 1024, 576, { sky = "#8fa3ba", ground = "#3d4654", stills = stills })
