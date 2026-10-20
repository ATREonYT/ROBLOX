-- The owner's 3D knife crates offline (owner, Oct 20: "make these crates for the opening of the normal knifes ... and
-- make the opening animations look appropriate"): his crate parts from his place, moved exactly as UI/Crate3D moves
-- them (Shared/CrateMotion: the same split, hinge, shake, lid and knife maths, the same camera), and his knife as his
-- own .glb mesh (tools/knives/knife_meshes.py).
-- STAND-IN LOOK: his crate meshes can't be fetched offline (cloud), so each of his MeshParts is drawn as a box (or a
-- ball for bells, gems, eyes...) of its real size and place, coloured by its name after his crate shop mockup. The
-- motion and the framing are the game's; the look is only Studio's to judge.
--   MODE=film (default): one crate opening, 30 fps (CRATE=Beast, ITEM=<a Config/CoinShop key in it>, default its
--     first Epic), the rarity light behind it as the opening screen draws it; stills every few beats for a strip.
--   MODE=cards: the three crates as Shop > CRATES frames them (UI/Crate3D "Card": as he built them, the Storm Vault
--     and the Beast Chest open as on his mockup), one still each, 428 x 300 (twice the card's 214 x 150 picture), on the card's navy.
-- From the repo root: KNIFE_MESHES=<knives.json> MOTION3D_KEEP=<dir> [MODE=cards] sh huzz-valley/tools/preview/motion3d/video.sh \
--   huzz-valley/tools/preview/motion3d/crate_open_scene.luau <out.mp4>
local fs = require("@lune/fs")
local process = require("@lune/process")
local roblox = require("@lune/roblox")
local serde = require("@lune/serde")
local CFrame, Vector3 = roblox.CFrame, roblox.Vector3
local Scene = require("./scene")
local Env = require("./env")
local CrateMotion = require("../../../src/ReplicatedStorage/Shared/CrateMotion")
local Crates = Env.load("huzz-valley/src/ReplicatedStorage/Shared/Config/Crates.lua")
local CoinShop = Env.load("huzz-valley/src/ReplicatedStorage/Shared/Config/CoinShop.lua")
local SpinWheel = Env.load("huzz-valley/src/ReplicatedStorage/Shared/Config/SpinWheel.lua")
local Round = Env.load("huzz-valley/src/ReplicatedStorage/Shared/Config/Round.lua")
local CrateModels = Env.load("huzz-valley/src/ReplicatedStorage/Shared/CrateModels.lua")

local MODE = process.env.MODE or "film"
local game = roblox.deserializePlace(fs.readFile(Env.root .. "/huzz-valley/places/HUSSANIME.rbxl"))
local holder = game:GetService("Workspace").scrates.Standard_Crates
local meshes = process.env.KNIFE_MESHES and serde.decode("json", fs.readFile(process.env.KNIFE_MESHES)) or {}

local function hex(c) return string.format("#%02x%02x%02x", math.floor(c.R * 255 + 0.5), math.floor(c.G * 255 + 0.5), math.floor(c.B * 255 + 0.5)) end
local function lerpHex(a, b, u)
	local function ch(h, i) return tonumber(string.sub(h, i, i + 1), 16) end
	local out = "#"
	for i = 2, 6, 2 do out ..= string.format("%02x", math.floor(ch(a, i) + (ch(b, i) - ch(a, i)) * u + 0.5)) end
	return out
end
-- rarity colours as the game's (UI/CrateArt.color: the Spin wheel's, else Config/Round's)
local function rarityHex(r)
	local c = SpinWheel.RarityColors[r]
	if not c then for _, x in Round.Rarities do if x.Name == r then c = x.Color end end end
	return c and hex(c) or "#ffffff"
end

-- his parts' colours by name, after his mockup (red and gold shrine; dark blue tech vault; purple bone mimic)
local PALETTE = {
	dojo_set = { { "glow", "#ffcf6a" }, { "roof_upper_trim", "#e3a93c" }, { "roof_lower_trim", "#e3a93c" }, { "roof", "#262a4a" },
		{ "eave_tip", "#e3a93c" }, { "ridge", "#e3a93c" }, { "gold", "#e3a93c" }, { "nail", "#e3a93c" }, { "bracket", "#e3a93c" },
		{ "bell", "#f0c048" }, { "emblem", "#e3a93c" }, { "shuriken", "#c9ced8" }, { "lattice", "#f2dca4" }, { "post", "#4a2420" },
		{ "beam", "#4a2420" }, { "plinth", "#3b2a2a" }, { "step", "#3b2a2a" }, { "lantern", "#b0232e" }, { "sakura", "#ffb6d3" },
		{ "rope", "#efe6cf" }, { "shide", "#ffffff" }, { "kunai_blade", "#c9ced8" }, { "kunai", "#3a2a2a" }, { "string", "#efe6cf" },
		{ "", "#c8323c" } },
	storm_set = { { "glow", "#5fd8ff" }, { "crystal_rock", "#34405e" }, { "lid", "#2c4790" }, { "vault_body", "#22366e" },
		{ "front_panel", "#2e4a96" }, { "side_panel", "#27407f" }, { "foot", "#8b97b0" }, { "bolt", "#a8b4c8" }, { "corner_guard", "#7c8aa6" },
		{ "rim", "#59688a" }, { "band", "#59688a" }, { "emblem", "#c9d2e4" }, { "piston", "#8e9ab2" }, { "hinge", "#6c7a98" },
		{ "gem_bezel", "#c9d2e4" }, { "clamp", "#6c7a98" }, { "vent", "#1a2850" }, { "", "#2b4383" } },
	beast_set = { { "glow", "#ff63d0" }, { "chest_lid", "#6b34a3" }, { "chest_body", "#4d2380" }, { "lid", "#e6dac6" },
		{ "bone", "#e6dac6" }, { "vertebra", "#e6dac6" }, { "claw", "#efe6d6" }, { "horn", "#e9dfcd" }, { "tooth", "#f5efe3" },
		{ "fang", "#f5efe3" }, { "spike", "#e6dac6" }, { "band", "#3a1868" }, { "paw", "#42206c" }, { "tongue", "#e2558a" },
		{ "eye_socket", "#220c38" }, { "eyelid", "#42206c" }, { "pupil", "#120818" }, { "brow", "#e6dac6" }, { "chain", "#8c8aa2" },
		{ "handle", "#a597ba" }, { "", "#5a2a8a" } },
}
local BALL = { "bell", "lantern", "gem", "jewel", "orb", "eye", "iris", "pupil", "knot", "bolt", "rivet", "nail", "sparkle", "petal", "hub" }
local function lookOf(setName, name)
	local base = string.lower(string.gsub(string.gsub(name, "_Node$", ""), "_%d+$", ""))
	local col = "#888888"
	for _, row in PALETTE[setName] or {} do
		if row[1] == "" or string.find(base, row[1], 1, true) then col = row[2]; break end
	end
	local shape = nil
	for _, w in BALL do if string.find(base, w, 1, true) then shape = "ball" end end
	return col, shape, string.find(base, "glow", 1, true) ~= nil
end

local function box(m)
	local lo, hi = Vector3.new(math.huge, math.huge, math.huge), Vector3.new(-math.huge, -math.huge, -math.huge)
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") then
			local p, h = d.CFrame.Position, d.Size / 2
			lo = Vector3.new(math.min(lo.X, p.X - h.X), math.min(lo.Y, p.Y - h.Y), math.min(lo.Z, p.Z - h.Z))
			hi = Vector3.new(math.max(hi.X, p.X + h.X), math.max(hi.Y, p.Y + h.Y), math.max(hi.Z, p.Z + h.Z))
		end
	end
	return (lo + hi) / 2, hi - lo
end

-- one of his crates, set up as UI/Crate3D sets it up (its middle at the origin of its frame, bottom at y = 0)
local function makeCrate(scene, crate, at)
	local set = holder:FindFirstChild(crate.Model.Set)
	local model = set:FindFirstChild(crate.Model.Crate)
	local centre, size = box(model)
	local parts, rows = {}, {}
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			local off = CFrame.new(-centre) * d.CFrame
			local col, shape, glow = lookOf(crate.Model.Set, d.Name)
			local b = scene:addBox(off, d.Size, col)
			b.Shape, b.Neon = shape, glow or nil
			table.insert(parts, { box = b, off = off, glow = glow, col = col })
			table.insert(rows, { name = d.Name, y = off.Position.Y, z = off.Position.Z, sy = d.Size.Y, sz = d.Size.Z, group = CrateModels.groupOf(d, model) })
		end
	end
	local opens, hy, hz = CrateMotion.split(rows, crate.Model.Body)
	local swings = {}
	for _, i in opens do swings[i] = true end
	local hinge = CFrame.new(0, hy, hz)
	local built = math.rad(crate.Model.Built or 0)
	-- (stand-in only) a lid he built tilted open fills its part's box only as a tilted slab: draw it as that slab (depth
	-- L, thickness w solved from the box's height and depth at his Built angle), not as a solid block
	if built > 0 then
		local sn, cs = math.sin(built), math.cos(built)
		for i in swings do
			local p = parts[i]
			local H, D = p.box.Size.Y, p.box.Size.Z
			local L = (H * sn - D * cs) / (sn * sn - cs * cs)
			local w = (D * sn - H * cs) / (sn * sn - cs * cs)
			if L > 0.05 and w > 0.02 then
				p.box.Size = Vector3.new(p.box.Size.X, w, L)
				p.off = CFrame.new(p.off.Position) * CFrame.Angles(built, 0, 0)
			end
		end
	end
	local c = { parts = parts, swings = swings, hinge = hinge, size = size, h = size.Y, at = at, set = set }
	function c.place(root, angle, mix, rarity)
		local swing = hinge * CFrame.Angles(angle - built, 0, 0) * hinge:Inverse()
		for i, p in parts do
			p.box.CFrame = at * root * (if swings[i] then swing * p.off else p.off)
			if p.glow and rarity then p.box.Color = lerpHex(p.col, rarity, mix) end
		end
	end
	return c
end

-- the camera UI/Crate3D uses (FOV 30, in front, a little above)
local function aim(c, view, grow)
	local reach = math.max(c.size.X, c.size.Y, c.size.Z)
	local down = if view == "Card" then math.rad(24) else math.rad(14)
	local look = if view == "Card" then Vector3.new(0, c.h * 0.48, 0) else Vector3.new(0, c.h * 0.95, 0)
	local dist = (reach * (if view == "Card" then 0.57 else 1.02)) / math.tan(math.rad(15)) / grow
	local pos = look + Vector3.new(0, math.sin(down) * dist, -math.cos(down) * dist)
	return c.at * pos, c.at * look
end

local scene = Scene.new()
if MODE == "cards" then
	local ids = { "Dojo", "Storm", "Beast" }
	local list = {}
	for i, id in ids do
		local crate = Crates.get(id)
		local c = makeCrate(scene, crate, CFrame.new((i - 1) * 40, 0, 0))
		c.place(CFrame.new(0, c.h / 2, 0), math.rad(crate.Model.Built or 0)) -- (as he built it)
		list[i] = c
	end
	for i, c in list do
		local pos, look = aim(c, "Card", 1)
		scene:frame(pos, look, { fov = 30, caption = "" })
		local _ = i
	end
	scene:save(nil, 30, 428, 300, { sky = "#1e2852", ground = "#1e2852", grid = false, stills = { 0, 1, 2 } })
	return
end

-- the film
local crate = Crates.get(process.env.CRATE or "Beast")
assert(crate and crate.Model, "a crate with his model")
local item
for _, it in crate.Items do
	if (process.env.ITEM and it.Id == process.env.ITEM) or (not process.env.ITEM and not item and it.Rarity == "Epic") then item = it end
end
item = item or crate.Items[#crate.Items]
local rarity = rarityHex(item.Rarity)
local knifeShop = CoinShop.get(item.Id)
local knifeColor = knifeShop and knifeShop.Colors and knifeShop.Colors[1]
local c = makeCrate(scene, crate, CFrame.new())
-- his knife: the .glb mesh (its own units are his little knife's studs), made show size as UI/Crate3D does
local mesh = meshes[item.Id]
local mlo, mhi = Vector3.new(math.huge, math.huge, math.huge), Vector3.new(-math.huge, -math.huge, -math.huge)
for _, part in mesh or {} do
	local pos = part.pos
	for i = 1, #pos, 3 do
		local v = Vector3.new(pos[i], pos[i + 1], pos[i + 2])
		mlo = Vector3.new(math.min(mlo.X, v.X), math.min(mlo.Y, v.Y), math.min(mlo.Z, v.Z))
		mhi = Vector3.new(math.max(mhi.X, v.X), math.max(mhi.Y, v.Y), math.max(mhi.Z, v.Z))
	end
end
local mmid, mh = (mlo + mhi) / 2, math.max(mhi.Y - mlo.Y, 0.05)
local kBase = (c.h * 0.78) / mh
local knifeBoxes = {}
if not mesh then -- (no mesh file: his little knife's parts as boxes)
	local km = CrateModels.knife(c.set, CoinShop.get(item.Id))
	local kc = box(km)
	for _, d in km:GetDescendants() do
		if d:IsA("BasePart") then
			local b = scene:addBox(CFrame.new(), d.Size, "#d8dce6")
			table.insert(knifeBoxes, { box = b, off = CFrame.new(-kc) * d.CFrame, size = d.Size })
		end
	end
	local _, ks = box(km)
	kBase = (c.h * 0.78) / ks.Y
end

local T = CrateMotion.T
local FPS = 30
local t0, t1 = -0.3, T.Reveal + 1.6
local stills, n = {}, 0
local marks = { 0.3, 1.0, 1.7, 2.0, 2.25, 2.45, 2.7, 3.0, 3.35, 4.2 }
for f = 0, math.floor((t1 - t0) * FPS) do
	local t = t0 + f / FPS
	local s = CrateMotion.shake(t)
	local root = CFrame.new(0, s.lift * c.h, 0) * CFrame.Angles(s.tilt, 0, s.roll) * CFrame.new(0, c.h / 2, 0)
	local bright, mix = CrateMotion.glow(math.max(t, 0))
	c.place(root, CrateMotion.lid(t), mix, rarity)
	local kp = CrateMotion.knife(t)
	local scale = kBase * kp.scale
	local at = CFrame.new(0, c.h * (0.35 + 0.95 * kp.up), -c.size.Z * 0.05) * CFrame.Angles(0, kp.spin, 0) * CFrame.Angles(0, 0, kp.tilt)
	local extra = { fov = 30, meshes = {}, sprites = {} }
	if kp.seen and mesh then
		local cf = at * CFrame.new(-mmid * scale)
		local x, y, z, r00, r01, r02, r10, r11, r12, r20, r21, r22 = cf:GetComponents()
		table.insert(extra.meshes, { m = item.Id, p = { x, y, z }, r = { r00, r01, r02, r10, r11, r12, r20, r21, r22 }, s = scale })
	end
	for _, kb in knifeBoxes do
		kb.box.Hidden = not kp.seen
		kb.box.Size = kb.size * scale
		kb.box.CFrame = at * (CFrame.new(kb.off.Position * scale) * kb.off.Rotation)
	end
	-- the opening screen's light behind it (UI CrateRays: green while it builds up, the rarity colour once open), kept
	-- inside the frame
	local lift, lightA, pale = CrateMotion.backlight(t, knifeColor)
	local glowCol = lerpHex(lerpHex("#5be07a", rarity, mix), "#ffffff", pale)
	table.insert(extra.sprites, { p = { 0, c.h * 1.05, c.size.Z * 1.6 }, s = c.h * (1.15 + 0.35 * bright), c = glowCol, a = 0.12 + 0.24 * bright, t = "@disc", add = true })
	-- and the soft light right behind the knife (UI KnifeLight, Shared/CrateMotion.backlight: nearly white for a black blade)
	if lightA < 1 then
		table.insert(extra.sprites, { p = { 0, c.h * 1.3, c.size.Z * 0.9 }, s = c.h * 1.6, c = lerpHex(rarity, "#ffffff", lift), a = 1 - lightA, t = "glow", add = true })
	end
	local phase = if t < T.Build then "builds up" elseif t < T.Rise then "opens" elseif t < T.Reveal then "the knife rises" else "reveal: " .. item.Name .. " (" .. item.Rarity .. ")"
	extra.caption = string.format("%s  t=%.2fs  %s  (his crate parts as stand-in boxes; his knife's .glb)", crate.Name, math.max(t, 0), phase)
	local s2 = CrateMotion.shake(t)
	local pos, look = aim(c, "Open", s2.grow)
	if process.env.SIDE then -- (SIDE=1: from the right, to see the top swing on its hinge rather than lift)
		pos = look + Vector3.new((pos - look).Magnitude, c.h * 0.15, 0)
	end
	scene:frame(pos, look, extra)
	for _, mk in marks do
		if math.abs(t - mk) < 0.5 / FPS then table.insert(stills, n) end
	end
	n += 1
end
scene:save(nil, FPS, 1280, 720, { sky = "#141b40", ground = "#141b40", grid = false, stills = stills, meshFile = process.env.KNIFE_MESHES })
print("stills at " .. table.concat(marks, ", ") .. " s")
