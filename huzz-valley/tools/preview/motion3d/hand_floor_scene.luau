-- A catcher's long knife in hand, before and after the knife check (Oct 19): the pack's Walk at the moment the
-- knife hand is lowest, seen from the side. Left: the old fixed 150 degree grip (Crimson Requiem's tip goes into the
-- floor); right: KnifeLook.handC0 with the knife's reach (a long blade held more forward, tip off the floor).
-- KNIFE_KEY picks the knife (default CrimsonRequiem). From the repo root:
--   KNIFE_MESHES=<knife_meshes.py json> sh huzz-valley/tools/preview/motion3d/video.sh \
--     huzz-valley/tools/preview/motion3d/hand_floor_scene.luau /tmp/hand.mp4   (MOTION3D_KEEP=<dir> keeps the still)
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
local KEY = process.env.KNIFE_KEY or "CrimsonRequiem"
local baked = {}
for _, k in serde.decode("json", fs.readFile("huzz-valley/tools/knives/knives.json")) do baked[k.key] = k end
local k = baked[KEY]
local per = k.studs / k.length
local reach = (k.tip - k.grip) * per
local lib = roblox.Instance.new("Folder")
for _, inst in roblox.deserializeModel(fs.readFile("huzz-valley/src/ServerStorage/HuzzAnimations.rbxm")) do inst.Parent = lib end
local A = {}
for _, name in { "Idle", "Walk", "Run" } do A[name] = KFS.load(lib:FindFirstChild(name, true)) end

-- .glb axes (blade +Y, thickness Z) into the Handle's (blade +Y, thickness X), origin at the grip's middle.
local TURN = CFrame.fromMatrix(Vector3.zero, Vector3.new(0, 0, -1), Vector3.new(0, 1, 0), Vector3.new(1, 0, 0))
local function mesh(handleCF)
	local cf = handleCF * CFrame.new(0, -k.grip * per, 0) * TURN
	local c = { cf:GetComponents() }
	return { m = KEY, p = { c[1], c[2], c[3] }, r = { c[4], c[5], c[6], c[7], c[8], c[9], c[10], c[11], c[12] }, s = per }
end

local scene = Scene.new()
for i = -3, 3 do
	for j = -2, 2 do scene:addBox(CFrame.new(i * 4, 0.03, j * 4), Vector3.new(3.8, 0.06, 3.8), if (i + j) % 2 == 0 then "#c08a4a" else "#b07c40") end
end
local rigs = {
	{ rig = scene:addRig(Rig.r15("Before", { shirt = "#e0453a", pants = "#2b2f3a" })), x = -3.2, reach = nil, label = "BEFORE" },
	{ rig = scene:addRig(Rig.r15("After", { shirt = "#e0453a", pants = "#2b2f3a" })), x = 3.2, reach = reach, label = "AFTER" },
}
-- the walk at the moment the knife hand is lowest
local mix = Mix.new()
for _ = 1, 60 do Mix.step(mix, 1 / 30, { speed = 10, state = "ground", lengths = { Walk = A.Walk.length, Run = A.Run.length } }) end
local function pose(rig, t)
	for _, m in rig.motors do m.Transform = CFrame.identity end
	local total = 0
	for _, name in { "Idle", "Walk", "Run" } do
		local w = mix.weights[name]
		if w > 1e-4 then
			total += w
			KFS.apply(A[name], rig, t, w / total)
		end
	end
	Rig.fk(rig)
end
local probe = rigs[1].rig
probe.root.CFrame = CFrame.new(0, Rig.REST_HEIGHT, 0)
local bestT, bestY = 0, math.huge
for i = 0, 40 do
	pose(probe, i * 0.05)
	local y = (probe.parts.RightHand.CFrame * KnifeLook.handC0(Vector3.new(0, -0.15, 0)) * Vector3.new(0, reach, 0)).Y
	if y < bestY then bestT, bestY = i * 0.05, y end
end
local meshes, labels = {}, {}
for _, r in rigs do
	r.rig.root.CFrame = CFrame.new(r.x, Rig.REST_HEIGHT, 0) * CFrame.Angles(0, math.rad(-90), 0) -- (side on to the camera)
	pose(r.rig, bestT)
	local hand = r.rig.parts.RightHand.CFrame * KnifeLook.handC0(Vector3.new(0, -0.15, 0), r.reach)
	table.insert(meshes, mesh(hand))
	local tipY = (hand * Vector3.new(0, reach, 0)).Y
	table.insert(labels, { p = { r.x, 6.6, 0 }, text = r.label, h = 0.7, c = "#ffffff", o = "#1e1228" })
	table.insert(labels, { p = { r.x, 6.0, 0 }, text = string.format("tip %+.2f studs", tipY), h = 0.45, c = if tipY < 0 then "#ff6a6a" else "#7dffa0", o = "#1e1228" })
end
scene:frame(Vector3.new(0, 2.2, 14), Vector3.new(0, 2.2, 0), { meshes = meshes, labels = labels, fov = 44 })
scene:save(nil, 30, 1280, 640, { stills = { 0 }, meshFile = MESHES })
