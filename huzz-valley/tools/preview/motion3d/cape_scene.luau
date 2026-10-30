-- The owner's "floating black block" (Oct 20 screenshot design/owner-oct19/2010-floating-block.png: a dark navy slab
-- off the plaza edge next to his character) was the Midnight Outfit cape: HuzzServer/CosmeticsService welded it to the
-- torso at spawn, Roblox then swapped in the avatar's own torso, the weld died and the cape fell away loose. Same spot,
-- same camera, two stills: still_0 the old way (cape loose at the edge, nothing on his back), still_1 now (the cape is
-- made again on the new torso, with CosmeticsService's own size and hang). Plaza and body colours are stand-ins.
-- From the repo root: MOTION3D_KEEP=<dir> sh huzz-valley/tools/preview/motion3d/video.sh \
--   huzz-valley/tools/preview/motion3d/cape_scene.luau /tmp/cape.mp4
local roblox = require("@lune/roblox")
local CFrame, Vector3 = roblox.CFrame, roblox.Vector3
local Rig = require("./rig")
local Scene = require("./scene")

local CAPE, LINING = "#12142e", "#3b2f8a" -- CosmeticsService CAPE rgb(18,20,46); its see-through neon lining, darkened
local scene = Scene.new()
-- the plaza: a red rug on a sandy deck, its brick edge dropping away on the right
scene:addBox(CFrame.new(6.5, 3, 0), Vector3.new(16, 6, 20), "#d9a54a")
scene:addBox(CFrame.new(6, 6.02, 1), Vector3.new(9, 0.04, 10), "#7a2a3a")
local rig = scene:addRig(Rig.r15("Owner", { shirt = "#6b7080", pants = "#4a4e5a" })) -- (lighter than his black clothes so the dark cape reads)
rig.root.CFrame = CFrame.new(1.5, 6 + Rig.REST_HEIGHT, 1) * CFrame.Angles(0, math.rad(-125), 0) -- three-quarters from behind, the edge on his left
Rig.fk(rig)
local torso = rig.parts.UpperTorso
local size = Vector3.new(torso.Size.X * 0.95, torso.Size.Y * 1.75, 0.08)
local hang = CFrame.new(0, torso.Size.Y * 0.5 - size.Y * 0.5, torso.Size.Z * 0.5 + 0.12) * CFrame.Angles(math.rad(-8), 0, 0)
local cape = scene:addBox(CFrame.new(), size, CAPE)
local lining = scene:addBox(CFrame.new(), size - Vector3.new(0.12, 0.12, 0.04), LINING)
local function place(cf)
	cape.CFrame = cf
	lining.CFrame = cf * CFrame.new(0, 0, -0.05)
end
local cam, at = Vector3.new(-6, 12, -10), Vector3.new(3, 7, 0)
-- before: dropped where the old torso was swapped out, tipped against the plaza's edge
place(CFrame.new(-2.7, 4.7, -2) * CFrame.Angles(math.rad(10), math.rad(35), math.rad(-22)))
scene:frame(cam, at, { fov = 50, labels = { { p = { 1.5, 12.6, 1 }, text = "BEFORE: cape left loose", h = 0.5, c = "#ffffff", o = "#000000" } } })
-- now: the cape made again on the avatar's own torso
place(torso.CFrame * hang)
scene:frame(cam, at, { fov = 50, labels = { { p = { 1.5, 12.6, 1 }, text = "NOW: cape on his back", h = 0.5, c = "#ffffff", o = "#000000" } } })
scene:save(nil, 30, 900, 640, { stills = { 0, 1 }, sky = "#9cc8ec", ground = "#4f86c4", grid = false })
