-- The field's Aura stars (Gameplay/AuraStars), drawn the way the game draws them: a billboard with the owner's star
-- (purple as drawn, others tinted from the white copy), a soft halo, sparkles, a floor glow; bobbing. All six
-- colours in a row, common to rare (Config/AuraStars: Blue 1, Green 2, Purple 3, Pink 5, White 10, Rainbow 25),
-- each 14% bigger than the one before. sh video.sh aura_star_scene.luau out.mp4
local roblox = require("@lune/roblox")
local CFrame, Vector3 = roblox.CFrame, roblox.Vector3
local Rig = require("./rig")
local Scene = require("./scene")

local scene = Scene.new()
local player = scene:addRig(Rig.r15("Player", { shirt = "#f2f2f2", pants = "#2b3c66", hair = "#e8c99a" }))
local STARS = {
	{ at = Vector3.new(-15, 3.2, -12), color = { 90, 160, 255 }, tier = 0 },
	{ at = Vector3.new(-9, 3.2, -12), color = { 100, 240, 130 }, tier = 1 },
	{ at = Vector3.new(-3, 3.2, -12), color = { 175, 110, 255 }, tier = 2, asDrawn = true },
	{ at = Vector3.new(3.5, 3.2, -12), color = { 255, 120, 210 }, tier = 3 },
	{ at = Vector3.new(10.5, 3.2, -12), color = { 245, 245, 255 }, tier = 4 },
	{ at = Vector3.new(18, 3.2, -12), rainbow = true, tier = 5 },
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
	local w = 3.4 + s.tier * 0.5
	floors[i] = scene:addBox(CFrame.new(s.at.X, 0.03, s.at.Z), Vector3.new(w, 0.05, w), hex(s.color or { 255, 255, 255 }))
end
local sparks = {}
local seed = 3
local function rnd() seed = (seed * 1103515245 + 12345) % 2147483648; return seed / 2147483648 end
local FPS, SECONDS = 30, 5
for f = 0, SECONDS * FPS - 1 do
	local t = f / FPS
	local z = 4 - math.min(t, 3) * 2.2
	player.root.CFrame = Rig.lookAt(Vector3.new(-17, Rig.REST_HEIGHT, z - 2), Vector3.new(-17, Rig.REST_HEIGHT, z - 3))
	Rig.fk(player)
	local sprites = {}
	for i, s in STARS do
		local c = s.color or hsv((t * 0.12 + i * 0.1) % 1)
		local col = hex(c)
		floors[i].Color = col
		local p = s.at + Vector3.new(0, math.sin(t * 1.8 + i) * 0.28, 0)
		local P = { p.X, p.Y, p.Z }
		local size = 4.2 * (1 + s.tier * 0.14)
		table.insert(sprites, { p = P, s = size * 1.3, c = col, a = 0.22, t = "aura-star-white", r = 0, add = true })
		table.insert(sprites, { p = P, s = size * (1 + math.sin(t * 2.6) * 0.03), c = if s.asDrawn then "#ffffff" else col, a = 1, t = if s.asDrawn then "aura-star" else "aura-star-white", r = math.sin(t * 0.9) * 6, add = false })
		-- sparkles
		if rnd() < 0.15 + s.tier * 0.08 then table.insert(sparks, { p = p, v = Vector3.new(rnd() - 0.5, rnd() - 0.3, rnd() - 0.5) * 2.4, age = 0, c = col }) end
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
	scene:frame(Vector3.new(1.5, 7, 16), Vector3.new(1.5, 3, -10), { sprites = sprites })
end
scene:save(nil, FPS, 1280, 720, { sky = "#7fb6ff", ground = "#3fae4a", grid = false })
