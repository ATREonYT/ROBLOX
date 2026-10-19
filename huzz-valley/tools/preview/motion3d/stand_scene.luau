-- The lobby stands' sword showcase (Shared/StandShowcase, the game's own code; owner: "showcase the swords that the
-- gamepass includes ... the swinging animation, make it look good though"): a blocky R15 copy with Hollow Eclipse
-- (VIP) and a blocky R6 copy with Dragon's Maw (Dance Pack), the owner's own meshes, each knife held as
-- Gameplay/AvatarStands holds it (KnifeLook.handC0 at the grip, turned in the fist by the showcase's grip angle),
-- the slash trail drawn from the blade's guard-to-tip sweep over StandShowcase.TRAIL_LIFETIME, the knife's glow as a
-- soft light, the stand's glow disc. Front three-quarter view from where a player stands, 10 s at 30 fps.
-- python3 -I tools/knives/knife_meshes.py /tmp/knives.json   (from huzz-valley/), then from the repo root:
-- KNIFE_MESHES=/tmp/knives.json sh huzz-valley/tools/preview/motion3d/video.sh \
--   huzz-valley/tools/preview/motion3d/stand_scene.luau huzz-valley/docs/previews/stand-showcase.mp4
local fs = require("@lune/fs")
local serde = require("@lune/serde")
local process = require("@lune/process")
local roblox = require("@lune/roblox")
local CFrame, Vector3 = roblox.CFrame, roblox.Vector3
local Rig = require("./rig")
local Scene = require("./scene")
local Env = require("./env")
local SHARED = "huzz-valley/src/ReplicatedStorage/Shared/"
local Show = Env.load(SHARED .. "StandShowcase.lua")
local KnifeLook = Env.load(SHARED .. "KnifeLook.lua")

local MESHES = process.env.KNIFE_MESHES or error("set KNIFE_MESHES (python3 -I tools/knives/knife_meshes.py <file>)")
local baked = {}
for _, k in serde.decode("json", fs.readFile("huzz-valley/tools/knives/knives.json")) do baked[k.key] = k end

-- .glb axes (blade +Y, thickness Z) into the Handle's (blade +Y, thickness X), origin at the grip's middle.
local TURN = CFrame.fromMatrix(Vector3.zero, Vector3.new(0, 0, -1), Vector3.new(0, 1, 0), Vector3.new(1, 0, 0))

local scene = Scene.new()
for i = -5, 5 do
	for j = -4, 4 do scene:addBox(CFrame.new(i * 4, 0.03, j * 4), Vector3.new(0.4, 0.06, 0.4), "#7d6a8a") end
end
local SET = {
	{ kind = "R15", key = "HollowEclipse", x = -4.2, seed = 5, accent = "#b48cff", shirt = "#2b2f3a", pants = "#1d1f27", label = "R15 · Hollow Eclipse (VIP)" },
	{ kind = "R6", key = "DragonsMaw", x = 4.2, seed = 10, accent = "#ff8a3d", shirt = "#c8423a", pants = "#2b2f3a", label = "R6 · Dragon's Maw (Dance Pack)" },
}
for _, s in SET do
	s.rig = scene:addRig(if s.kind == "R15" then Rig.r15(s.key, { shirt = s.shirt, pants = s.pants }) else Rig.r6(s.key, { shirt = s.shirt, pants = s.pants }))
	s.rig.root.CFrame = CFrame.new(s.x, if s.kind == "R15" then Rig.REST_HEIGHT else 3, 0) * CFrame.Angles(0, math.rad(if s.x < 0 then -8 else 8), 0)
	s.rec = Show.new(s.rig, s.seed)
	s.k = baked[s.key]
	s.per = s.k.studs / s.k.length
	s.history = {}
end

-- The Handle's frame now (as AvatarStands welds it: the grip point, the showcase's turn in the fist, handC0's angle).
local function handleOf(s, pose)
	local hand = s.rig.parts.RightHand or s.rig.parts["Right Arm"]
	local gripAt = Vector3.new(0, -hand.Size.Y / 2 + 0.1, 0)
	return hand.CFrame * CFrame.new(gripAt) * Show.knifeTurn(pose, KnifeLook.handC0(gripAt).Rotation)
end

local FPS, SECONDS, SUB = 30, 10, 4
local LIFE = Show.TRAIL_LIFETIME
local T = KnifeLook.TRAIL
for f = 0, SECONDS * FPS - 1 do
	local t = f / FPS
	local meshes, lights, sprites, ribbons, moves = {}, {}, {}, {}, {}
	for _, s in SET do
		-- sub-steps for the trail's sweep (a Trail samples every frame at Studio's 60 fps and more)
		local pose
		for k = SUB - 1, 0, -1 do
			local tt = t - k / (FPS * SUB)
			pose = Show.step(s.rec, tt)
			Rig.fk(s.rig)
			local h = handleOf(s, pose)
			if pose.trail then
				table.insert(s.history, { t = tt, base = h * Vector3.new(0, -s.k.grip * s.per, 0), tip = h * Vector3.new(0, (s.k.tip - s.k.grip) * s.per, 0) })
			end
		end
		local h = handleOf(s, pose)
		local cf = h * CFrame.new(0, -s.k.grip * s.per, 0) * TURN
		local c = { cf:GetComponents() }
		table.insert(meshes, { m = s.key, p = { c[1], c[2], c[3] }, r = { c[4], c[5], c[6], c[7], c[8], c[9], c[10], c[11], c[12] }, s = s.per })
		-- the knife's glow (Exclusive = Mythic's ladder: range 4, brightness 1; render.mjs reads about twice Studio's)
		local fx = KnifeLook.fx(s.k.rarity)
		local mid = h * Vector3.new(0, (s.k.tip - s.k.grip) * s.per * 0.5, 0)
		if fx.glow and s.k.glow then table.insert(lights, { p = { mid.X, mid.Y, mid.Z }, c = "#" .. s.k.glow, b = fx.glow.brightness * 0.5, r = fx.glow.range }) end
		-- the stand's glow disc under the feet
		table.insert(sprites, { p = { s.x, 0.08, 0 }, s = 4, c = s.accent, a = 0.45, t = "@disc", flat = true, add = true })
		-- the slash trail: the blade's sweep over the last LIFE seconds, as strips at five points along the blade
		local keep = {}
		for _, e in s.history do if t - e.t <= LIFE then table.insert(keep, e) end end
		s.history = keep
		if #keep >= 2 then
			local colour = "#" .. (s.k.glow or "ffffff")
			for i = 1, 5 do
				local u = (i - 0.5) / 5
				local pts, w, a, cs = {}, {}, {}, {}
				for n = #keep, 1, -1 do
					local e = keep[n]
					local p = e.base:Lerp(e.tip, u)
					local age = (t - e.t) / LIFE
					table.insert(pts, { p.X, p.Y, p.Z })
					table.insert(w, (e.tip - e.base).Magnitude / 5 * 1.15)
					table.insert(a, 0.75 * (1 - T.Tinted[1]) * (1 - age) * (0.35 + 0.65 * u))
					table.insert(cs, if age < 0.35 then colour else "#ffffff")
				end
				table.insert(ribbons, { pts = pts, w = w, a = a, c = colour, cs = cs, add = true })
			end
		end
		table.insert(moves, s.label .. (if pose.move then "  · " .. pose.move else "  · ready"))
	end
	scene:frame(Vector3.new(-5.5, 5.4, -15.5), Vector3.new(0.3, 3.0, 0), { meshes = meshes, lights = lights, sprites = sprites, ribbons = ribbons,
		caption = moves[2] .. "     |     " .. moves[1], fov = 50 }) -- (caption left to right as on screen)
end
scene:save(nil, FPS, 1280, 720, { meshFile = MESHES, stills = { 45, 80, 140 } })
