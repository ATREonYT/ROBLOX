-- The lobby's Aura stars (Gameplay/AuraStars), drawn the way the game draws them: a 4.2-stud billboard with a
-- halo, two turning orbit rings and the crystal, sparkles, and a glow on the floor; bobbing. A player walks up.
-- Purple, White (worth 3) and Rainbow (worth 10). sh video.sh aura_star_scene.luau out.mp4
local roblox = require("@lune/roblox")
local CFrame, Vector3 = roblox.CFrame, roblox.Vector3
local Rig = require("./rig")
local Scene = require("./scene")

local scene = Scene.new()
local player = scene:addRig(Rig.r15("Player", { shirt = "#f2f2f2", pants = "#2b3c66", hair = "#e8c99a" }))
local STARS = {
	{ at = Vector3.new(-5, 3.2, -8), color = { 175, 110, 255 } },
	{ at = Vector3.new(1, 3.2, -11), color = { 245, 245, 255 } },
	{ at = Vector3.new(6, 3.2, -7), rainbow = true },
}
local function hex(c) return string.format("#%02x%02x%02x", c[1], c[2], c[3]) end
local function hsv(h)
	local i = math.floor(h * 6); local f = h * 6 - i
	local p, q, t = 0.45, 1 - f * 0.55, 0.45 + f * 0.55
	local r, g, b
	i = i % 6
	if i == 0 then r, g, b = 1, t, p elseif i == 1 then r, g, b = q, 1, p elseif i == 2 then r, g, b = p, 1, t
	elseif i == 3 then r, g, b = p, q, 1 elseif i == 4 then r, g, b = t, p, 1 else r, g, b = 1, p, q end
	return { math.floor(r * 255), math.floor(g * 255), math.floor(b * 255) }
end
local floors = {}
for i, s in STARS do
	floors[i] = scene:addBox(CFrame.new(s.at.X, 0.03, s.at.Z), Vector3.new(3.4, 0.05, 3.4), hex(s.color or { 255, 255, 255 }))
end
local sparks = {}
local seed = 3
local function rnd() seed = (seed * 1103515245 + 12345) % 2147483648; return seed / 2147483648 end
local FPS, SECONDS = 30, 5
for f = 0, SECONDS * FPS - 1 do
	local t = f / FPS
	local z = 4 - math.min(t, 3) * 2.2
	player.root.CFrame = Rig.lookAt(Vector3.new(0, Rig.REST_HEIGHT, z), Vector3.new(0, Rig.REST_HEIGHT, z - 1))
	Rig.fk(player)
	local sprites = {}
	for i, s in STARS do
		local c = s.color or hsv((t * 0.12 + i * 0.1) % 1)
		local col = hex(c)
		floors[i].Color = col
		local p = s.at + Vector3.new(0, math.sin(t * 1.8 + i) * 0.28, 0)
		local P = { p.X, p.Y, p.Z }
		local size = 4.2
		table.insert(sprites, { p = P, s = size * 1.25, c = col, a = 0.4, t = "aura-star", r = 0, add = true })
		table.insert(sprites, { p = P, s = size * 1.15, c = col, a = 0.85, t = "aura-ring", r = (t * 28) % 360, add = true })
		table.insert(sprites, { p = P, s = size * (0.72 + math.sin(t * 2.6) * 0.03), c = col, a = 1, t = "aura-star", r = 0, add = false })
		table.insert(sprites, { p = P, s = size * 1.0, c = col, a = 0.65, t = "aura-ring", r = 35 - (t * 20) % 360, add = true })
		-- sparkles
		if rnd() < 0.25 then table.insert(sparks, { p = p, v = Vector3.new(rnd() - 0.5, rnd() - 0.3, rnd() - 0.5) * 2.4, age = 0, c = col }) end
	end
	local keep = {}
	for _, q in sparks do
		q.age += 1 / FPS
		if q.age < 1.2 then
			q.p += q.v / FPS
			table.insert(sprites, { p = { q.p.X, q.p.Y, q.p.Z }, s = 0.5 * (1 - q.age / 1.2), c = q.c, a = 1 - q.age / 1.2, t = "star", r = 0, add = true })
			table.insert(keep, q)
		end
	end
	sparks = keep
	scene:frame(Vector3.new(0, 6.5, 12), Vector3.new(0.5, 2.5, -7), { sprites = sprites })
end
scene:save(nil, FPS, 1280, 720, { sky = "#5d6aa8", ground = "#4f8a4a", grid = false })
