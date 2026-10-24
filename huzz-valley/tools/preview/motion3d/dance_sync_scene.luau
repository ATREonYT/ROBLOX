-- Synced dancing (owner, Oct 19: "make synced dancing"), the game's own rule (Gameplay/DanceSync.timeAt): a dance's
-- beat is when the first dancer near you started it; whoever starts the same dance near them (or presses F, "DANCE
-- TOGETHER") takes that beat, and every screen shows each dancer at (now - beat), so they move as one. Your girl
-- dances on the same beat (Gameplay/CompanionDance: Shared/KeyframeSampler + Shared/DanceRetarget).
--   0.5 s  the first player starts "Floss" (her girl dances with her)
--   2.1 s  a second player joins in, 3.3 s a third
-- Left: NOT SYNCED (each dance from its own start, as a screen showed it when a track simply started on arrival).
-- Right: SYNCED (one beat). The dances are the owner's own (ServerStorage/HuzzAnimations.rbxm).
-- sh video.sh dance_sync_scene.luau out.mp4      Film: docs/previews/dance-sync.mp4.
local fs = require("@lune/fs")
local process = require("@lune/process")
local roblox = require("@lune/roblox")
local CFrame, Vector3 = roblox.CFrame, roblox.Vector3
local Rig = require("./rig")
local Scene = require("./scene")
local KFS = require("./kfs")
local Env = require("./env")
local SHARED = "huzz-valley/src/ReplicatedStorage/Shared/"
local Sampler = Env.load(SHARED .. "KeyframeSampler.lua")
local Retarget = Env.load(SHARED .. "DanceRetarget.lua")
local FollowMotion = Env.load(SHARED .. "FollowMotion.lua")
local Companion = Env.load(SHARED .. "Config/GirlMotion.lua").Companion
local DanceSync = Env.load("huzz-valley/src/StarterPlayer/StarterPlayerScripts/HuzzClient/Gameplay/DanceSync.lua")

local lib = roblox.Instance.new("Folder")
for _, inst in roblox.deserializeModel(fs.readFile("huzz-valley/src/ServerStorage/HuzzAnimations.rbxm")) do inst.Parent = lib end
local idle = KFS.load(lib:FindFirstChild("Idle", true))
local floss = KFS.load(lib:FindFirstChild("Dance_Floss", true))

local scene = Scene.new()
for i = -6, 6 do
	for j = -8, 8 do
		scene:addBox(CFrame.new(j * 4, 0.03, i * 4), Vector3.new(0.4, 0.06, 0.4), "#b9a06a")
	end
end
local HEIGHT = Companion.Height
local R15_HEIGHT = 5.2
local SHIRTS = { "#e0457b", "#3a5bd0", "#2fb37a" }
local STARTS = { 0.5, 2.1, 3.3 }
local lanes = { { name = "NOT SYNCED", x = -7.8, synced = false }, { name = "SYNCED", x = 7.8, synced = true } }
for _, lane in lanes do
	lane.dancers = {}
	for i = 1, 3 do
		local rig = scene:addRig(Rig.r15(lane.name .. i, { shirt = SHIRTS[i], pants = "#22232c" }))
		local x = lane.x + (i - 2) * 3.6
		rig.root.CFrame = Rig.lookAt(Vector3.new(x, Rig.REST_HEIGHT, 0), Vector3.new(x, Rig.REST_HEIGHT, 1))
		table.insert(lane.dancers, { rig = rig, start = STARTS[i], w = 0 })
	end
	lane.girl = scene:addRig(Rig.r6(lane.name .. "Girl"))
	Rig.scale(lane.girl, HEIGHT / 5.25)
	local lead = lane.dancers[1].rig
	lane.walk = FollowMotion.new({ root = lane.girl.root, motors = lane.girl.motors, rootHeight = 3 * HEIGHT / 5.25, seed = 7, config = Companion })
	lane.walk.beside = true
	lane.girl.root.CFrame = lead.root.CFrame * CFrame.new(-2, -Rig.REST_HEIGHT + 3 * HEIGHT / 5.25, 1.2)
	lane.gw = 0
end

local FPS, DT, SECONDS = 30, 1 / 30, 8
for f = 0, SECONDS * FPS - 1 do
	local now = f * DT
	local labels = {}
	for _, lane in lanes do
		local beat = lane.dancers[1].start -- (the first dancer's start: the beat everyone near takes)
		for i, d in lane.dancers do
			local rig = d.rig
			KFS.apply(idle, rig, now)
			if now >= d.start then
				d.w = math.min(1, d.w + DT / 0.25)
				local t = if lane.synced then DanceSync.timeAt(now, beat, floss.length) else (now - d.start) % floss.length
				KFS.apply(floss, rig, t, d.w)
			end
			Rig.fk(rig)
			if now >= d.start - 0.4 and now < d.start + 1.2 and i > 1 then
				table.insert(labels, { p = { rig.root.CFrame.Position.X, 7.4, 0 }, text = "joins in", h = 0.55, c = "#ffffff", o = "#000000" })
			end
		end
		-- her girl: on the leader's beat (as Gameplay/CompanionDance)
		local lead = lane.dancers[1]
		FollowMotion.step(lane.walk, DT, now, lead.rig.root.CFrame, function() return 0 end, lead.rig.parts.Head.CFrame.Position)
		if now >= lead.start then
			lane.gw = math.min(1, lane.gw + DT / 0.3)
			local w = lane.gw * lane.gw * (3 - 2 * lane.gw)
			Retarget.apply(lane.walk.joints, Sampler.sample(floss, (now - lead.start) % floss.length), w, HEIGHT / R15_HEIGHT)
		end
		Rig.fk(lane.girl)
		table.insert(labels, { p = { lane.x, 8.6, 0 }, text = lane.name, h = 0.9, c = if lane.synced then "#7dffa0" else "#ffffff", o = "#000000" })
	end
	if not process.env.EVERY or f % tonumber(process.env.EVERY) == 0 then
		scene:frame(Vector3.new(0, 4.6, 16.5), Vector3.new(0, 3.2, 0), { labels = labels, caption = "Three players do Floss, starting at different times: one beat on the right" })
	end
end
scene:save(nil, FPS, 1280, 720)
