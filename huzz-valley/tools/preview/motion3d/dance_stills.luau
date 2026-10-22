-- Films a plain white blocky body frozen in each dance's card pose (Config/DancePoses), one dance per frame, on a
-- green screen, for tools/icons/make_dance_stills.py to cut out into assets/art/dance-still-<id>.png.
-- Those stills are the Dances cards' stand-in picture while your own avatar's picture (UI/DancePose) can't be made
-- (no character yet, or the dance not published in the live game), tinted with the card's colour like the owner's
-- Oct 17 mockup, whose cards show white figures.
-- From the repo root: MOTION3D_KEEP=<dir> sh huzz-valley/tools/preview/motion3d/video.sh huzz-valley/tools/preview/motion3d/dance_stills.luau <dir>/stills.mp4
local fs = require("@lune/fs")
local roblox = require("@lune/roblox")
local CFrame, Vector3 = roblox.CFrame, roblox.Vector3
local Rig = require("./rig")
local Scene = require("./scene")
local KFS = require("./kfs")

local folder = roblox.deserializeModel(fs.readFile("huzz-valley/src/ServerStorage/HuzzAnimations.rbxm"))[1]
local poseAt = {}
for id, t in fs.readFile("huzz-valley/src/ReplicatedStorage/Shared/Config/DancePoses.lua"):gmatch("(%w+) = ([%d%.]+)") do
	poseAt[id] = tonumber(t)
end
local ids = {}
for id in poseAt do table.insert(ids, id) end
table.sort(ids)

local WHITE = "#f4f4f8"
local scene = Scene.new()
-- (R6 since Oct 22: the owner's R6 dances on a plain R6 body)
local rig = scene:addRig(Rig.r6("Still", { shirt = WHITE, pants = "#e6e6ee", skin = "#ffffff", hair = "#ffffff", eyes = "#ffffff" }))
for _, p in rig.parts do if p.Color == "#3b3b3b" then p.Color = "#e6e6ee" end end -- (white feet too)
rig.decor = {} -- (no face or hair: the mockup's figures are plain)
-- one frame per dance, in id order (A-Z, as the cutter expects), after one warm-up frame (the first frame drawn
-- comes out unposed)
local stills = {}
Rig.fk(rig)
scene:frame(Vector3.new(0, 3.4, -11), Vector3.new(0, 2.4, 0))
for i, id in ids do
	local seq = folder:FindFirstChild("Dance_" .. id)
	assert(seq, "no animation for dance " .. id)
	local anim = KFS.load(seq)
	rig.root.CFrame = Rig.lookAt(Vector3.new(0, 3, 0), Vector3.new(0, 3, -1))
	KFS.apply(anim, rig, poseAt[id])
	Rig.fk(rig)
	scene:frame(Vector3.new(0, 3.4, -11), Vector3.new(0, 2.4, 0))
	table.insert(stills, i)
end
scene:save(nil, 30, 320, 320, { sky = "#00ff00", ground = "#00ff00", grid = false, stills = stills })
