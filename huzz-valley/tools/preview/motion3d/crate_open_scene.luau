-- The owner's 3D knife crates offline (owner, Oct 20: "make these crates for the opening of the normal knifes ... and
-- make the opening animations look appropriate"; 15:13: "make the case opening animation way, way better ... remove so
-- much glow from the crates, and then make it feel premium"): his crate parts from his place, moved exactly as
-- UI/Crate3D moves them (Shared/CrateMotion: the same split, hinge, hops, lid, knife path, camera and push-in), his
-- knife as his own .glb mesh (tools/knives/knife_meshes.py) without its aura ring (hidden in the game too), and the
-- screen as UI/Screens/CrateOpen draws it at 1280 x 720: the dark Backdrop and the rarity Pool behind the 3D, the
-- contact shadow, the odds chips while it builds up, then the name's punch, the rarity tag, NEW!, the buttons.
-- STAND-IN LOOK: his crate meshes can't be fetched offline (cloud), so each of his MeshParts is drawn as a box (or a
-- ball for bells, gems, eyes...) of its real size and place, coloured by its name after his crate shop mockup; his
-- glow parts are drawn lit (their glow is turned down in the game), not as Neon. The crate falling into shadow is
-- drawn by darkening its colours (the game dims its ViewportFrame's light). The motion, framing and screen are the
-- game's; the look of his crate is only Studio's to judge.
-- One crate opening, 30 fps (CRATE=Beast, ITEM=<a Config/CoinShop key in it>, default its first Legendary). SIDE=1
-- films it from the right (to see the top swing on its hinge).
-- From the repo root: KNIFE_MESHES=<knives.json> MOTION3D_KEEP=<dir> [SIDE=1] sh huzz-valley/tools/preview/motion3d/video.sh \
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
local CrateRoll = Env.load("huzz-valley/src/ReplicatedStorage/Shared/CrateRoll.lua")

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
	return col, shape
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
local function makeCrate(scene, crate)
	local set = holder:FindFirstChild(crate.Model.Set)
	local model = set:FindFirstChild(crate.Model.Crate)
	local centre, size = box(model)
	local parts, rows = {}, {}
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			local off = CFrame.new(-centre) * d.CFrame
			local col, shape = lookOf(crate.Model.Set, d.Name)
			local b = scene:addBox(off, d.Size, col)
			b.Shape = shape
			table.insert(parts, { box = b, off = off, col = col })
			table.insert(rows, { name = d.Name, y = off.Position.Y, z = off.Position.Z, sy = d.Size.Y, sz = d.Size.Z, group = CrateModels.groupOf(d, model) })
		end
	end
	local opens, hy, hz = CrateMotion.split(rows, crate.Model.Body)
	local swings = {}
	for _, i in opens do swings[i] = true end
	local front = math.huge
	for _, r in rows do
		if string.gsub(string.gsub(r.name, "_Node$", ""), "_%d+$", "") == crate.Model.Body then front = math.min(front, r.z - r.sz / 2) end
	end
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
	local c = { parts = parts, hy = hy, front = front, size = size, h = size.Y, set = set }
	-- dark: how far it has fallen into shadow (0 .. 1), drawn as darker colours
	function c.place(root, angle, dark)
		local swing = hinge * CFrame.Angles(angle - built, 0, 0) * hinge:Inverse()
		for i, p in parts do
			p.box.CFrame = root * (if swings[i] then swing * p.off else p.off)
			p.box.Color = lerpHex(p.col, "#000000", dark)
		end
	end
	return c
end

local scene = Scene.new()

-- the film
local crate = Crates.get(process.env.CRATE or "Beast")
assert(crate and crate.Model, "a crate with his model")
local item
for _, it in crate.Items do
	if (process.env.ITEM and it.Id == process.env.ITEM) or (not process.env.ITEM and not item and it.Rarity == "Legendary") then item = it end
end
item = item or crate.Items[#crate.Items]
local rarity = rarityHex(item.Rarity)
local knifeShop = CoinShop.get(item.Id)
local knifeColor = knifeShop and knifeShop.Colors and knifeShop.Colors[1]
local c = makeCrate(scene, crate)
local h = c.h
local K = CrateMotion.Knife
-- his knife: the .glb mesh (its own units are his little knife's studs), made show size as UI/Crate3D does
local mesh = meshes[item.Id]
assert(mesh, "his knife's mesh (KNIFE_MESHES)")
local mlo, mhi = Vector3.new(math.huge, math.huge, math.huge), Vector3.new(-math.huge, -math.huge, -math.huge)
for _, part in mesh do
	if not CrateMotion.isAura(part.node or "") then
		local pos = part.pos
		for i = 1, #pos, 3 do
			local v = Vector3.new(pos[i], pos[i + 1], pos[i + 2])
			mlo = Vector3.new(math.min(mlo.X, v.X), math.min(mlo.Y, v.Y), math.min(mlo.Z, v.Z))
			mhi = Vector3.new(math.max(mhi.X, v.X), math.max(mhi.Y, v.Y), math.max(mhi.Z, v.Z))
		end
	end
end
local mmid = (mlo + mhi) / 2
local kLen, kW, kDeep = math.max(mhi.Y - mlo.Y, 0.05), math.max(mhi.X - mlo.X, 0.01), math.max(mhi.Z - mlo.Z, 0.02)
local kBase = (h * K.Len) / kLen
-- the one light from inside (UI/Crate3D "Spill")
local spillBox = scene:addBox(CFrame.new(), Vector3.new(c.size.X * 0.8, h * 0.02, c.size.Z * 0.7), lerpHex(rarity, "#ffffff", 0.5))
spillBox.Neon = true

local T = CrateMotion.T
local FPS, W, H, CX = 30, 1280, 720, 640
local BACKDROP = "#0a0e22"
local odds = {}
do
	local sum, order = {}, {}
	for _, o in CrateRoll.odds(crate) do
		local r = o.item.Rarity
		if not sum[r] then sum[r] = 0; table.insert(order, r) end
		sum[r] += o.chance
	end
	table.sort(order, function(a, b) return (CrateRoll.RANK[a] or 0) < (CrateRoll.RANK[b] or 0) end)
	for _, r in order do table.insert(odds, { r = r, p = math.floor(sum[r] * 10 + 0.5) / 10 }) end
end
local function text(list, s, x, y, w, hh, col, a, o, ow, size, italic)
	table.insert(list, { text = s, x = x, y = y, w = w, h = hh, c = col, a = a, o = o, ow = ow, max = size, italic = italic, weight = 900 })
end
local t0, t1 = -0.3, T.Reveal + 1.5
local stills, n = {}, 0
local marks = { 0.5, 1.4, 1.95, 2.35, 2.55, 2.8, 3.05, 3.3, 3.6, 4.6 }
for f = 0, math.floor((t1 - t0) * FPS) do
	local t = t0 + f / FPS
	local tc = math.max(t, 0)
	local s = CrateMotion.shake(tc)
	local root = CFrame.new(0, s.lift * h, 0) * CFrame.Angles(s.tilt, 0, s.roll) * CFrame.new(0, h / 2, 0)
	c.place(root, CrateMotion.lid(tc), CrateMotion.Dim * CrateMotion.dim(tc))
	local sp = CrateMotion.spill(tc)
	spillBox.Hidden = sp <= 0
	spillBox.Alpha = 0.9 * sp
	spillBox.CFrame = root * CFrame.new(0, c.hy - h * 0.025, 0)
	local push = CrateMotion.push(tc)
	local lookY, eyeY, eyeZ = CrateMotion.camera(h, push)
	local pos, look = Vector3.new(0, eyeY, eyeZ), Vector3.new(0, lookY, 0)
	local extra = { fov = CrateMotion.Camera.Fov, meshes = {}, overlay = { texts = {}, rects = {} }, under = { bg = BACKDROP, rects = {} } }
	-- behind: the rarity Pool (16 faint layers, fading in as the lid opens) and the contact shadow
	local tint = CrateMotion.tint(tc)
	if tint > 0 then
		for i = 1, 16 do
			local k = 1 - (i - 1) / 16
			local w2, h2 = math.round(260 + 1240 * k), math.round(220 + 680 * k)
			table.insert(extra.under.rects, { x = CX - w2 / 2, y = 190 - h2 / 2, w = w2, h = h2, c = lerpHex(rarity, BACKDROP, 0.4), a = 0.06 * tint * CrateMotion.poolStrength(item.Rarity), round = true })
		end
	end
	local sx, sy = CrateMotion.project(lookY, eyeY, eyeZ, 0, 0, 0, W / H)
	local ex = CrateMotion.project(lookY, eyeY, eyeZ, c.size.X * 0.5, 0, 0, W / H)
	local sw = math.abs(ex - sx) * 2 * (1 - 1.5 * math.max(s.lift, 0)) * W
	for _, k in { 1, 0.78, 0.56 } do
		local w2, h2 = sw * k * 1.05, sw * k * 0.16
		table.insert(extra.under.rects, { x = sx * W - w2 / 2, y = sy * H - h2 / 2, w = w2, h = h2, c = "#000000", a = 0.22 * (1 - 3 * math.max(s.lift, 0)), round = true })
	end
	-- the knife and its light rim (UI/Crate3D: the rim is each part a hair bigger, flat light colour, just behind it)
	local kp = CrateMotion.knife(tc)
	if kp.seen then
		local ky, kz = CrateMotion.knifeSpot(kp)
		local scale = kBase * kp.scale
		local at = CFrame.new(0, h * ky, -c.size.Z * kz) * CFrame.Angles(0, 0, kp.tilt) * CFrame.Angles(0, kp.spin, 0)
		local cf = at * CFrame.new(-mmid * scale)
		local function entry(cfr, sc, more)
			local x, y, z, r00, r01, r02, r10, r11, r12, r20, r21, r22 = cfr:GetComponents()
			local e = { m = item.Id, p = { x, y, z }, r = { r00, r01, r02, r10, r11, r12, r20, r21, r22 }, s = sc, skip = "aura_" }
			for key, v in more or {} do e[key] = v end
			table.insert(extra.meshes, e)
		end
		local rim = CrateMotion.rim(tc)
		if rim > 0 then
			local wPx = CrateMotion.rimWidth(knifeColor) * kLen
			local g = Vector3.new(1 + 2 * wPx / kW, 1 + 2 * wPx / kLen, 1)
			local fwd = (look - pos).Unit
			local back = fwd * (kDeep * scale * 0.6 + h * 0.01)
			local cfh = CFrame.new(back) * at * CFrame.new(-Vector3.new(mmid.X * g.X, mmid.Y * g.Y, mmid.Z) * scale)
			entry(cfh, { scale * g.X, scale * g.Y, scale }, { flat = { c = lerpHex(rarity, "#ffffff", CrateMotion.RimWhite), a = rim } })
		end
		entry(cf, scale)
	end
	-- the screen's words (UI/Screens/CrateOpen at 1280 x 720)
	local tx = extra.overlay.texts
	local rects = extra.overlay.rects
	local ta0 = CrateMotion.title(tc) -- (the crate's name gives the top of the screen to the knife)
	if ta0 > 0 then text(tx, string.upper(crate.Name), 240, 40, 800, 52, "#ffffff", ta0, "#0b0f24", 3, 44, false) end
	if t < T.Reveal then
		-- the odds by rarity while it builds up, the pity line, TAP TO SKIP
		local cw, gap = 172, 12
		local x0 = math.round(CX - (#odds * cw + (#odds - 1) * gap) / 2)
		for i, o in odds do
			local x = x0 + (i - 1) * (cw + gap)
			table.insert(rects, { x = x, y = 536, w = cw, h = 34, c = "#141f48", a = 0.75, rr = 17, s = rarityHex(o.r), sw = 2 })
			table.insert(rects, { x = x + 10, y = 546, w = 14, h = 14, c = rarityHex(o.r), a = 1, rr = 7 })
			text(tx, string.format("%s %g%%", string.upper(o.r), o.p), x + 30, 536, 136, 34, "#ffffff", 1, "#0b0f24", 1.5, 15, false)
		end
		text(tx, "Legendary guaranteed in 40 opens", 240, 584, 800, 24, "#b3c1ee", 1, "#0b0f24", 1.5, 17, false)
		text(tx, "TAP TO SKIP", 440, 640, 400, 24, "#b3c1ee", 1, "#0b0f24", 1.5, 18, false)
	else
		local ns, na = CrateMotion.punch(t, T.Reveal)
		local ts, ta = CrateMotion.punch(t, T.Reveal + 0.1)
		text(tx, item.Name, CX - 400 * ns, 432 + 29 - 29 * ns, 800 * ns, 58 * ns, "#ffffff", na, "#0b0f24", 3.5 * ns, 50 * ns, true)
		if ta > 0 then
			local tw, th = (44 + 14 * #item.Rarity) * ts, 34 * ts
			table.insert(rects, { x = CX - tw / 2, y = 512 - th / 2, w = tw, h = th, c = rarity, a = ta, rr = 17 * ts, s = "#0b0f24", sw = 2.5 })
			text(tx, string.upper(item.Rarity), CX - tw / 2, 512 - th / 2, tw, th, "#ffffff", ta, "#0b0f24", 2, 20 * ts, false)
		end
		local su = math.clamp((t - T.Reveal - 0.3) / 0.25, 0, 1)
		if su > 0 then
			local k = 0.9 + 0.1 * CrateMotion.easeOut(su, 3)
			text(tx, "NEW!", CX - 400 * k, 552 - 19 * k, 800 * k, 38 * k, "#5be07a", su, "#0b0f24", 2.5, 34 * k, true)
			text(tx, "Wear it from Shop > Items", 240, 572 + 8, 800, 24, "#b3c1ee", su, "#0b0f24", 1.5, 18, false)
		end
		local bu = math.clamp((t - T.Reveal - 0.45) / 0.3, 0, 1)
		if bu > 0 then
			local y = 600 + math.round(40 * (1 - CrateMotion.easeOut(bu, 3))) + 14
			table.insert(rects, { x = 240 + 130, y = y, w = 330, h = 60, c = "#38c95a", a = bu, rr = 8, s = "#0e3f1a", sw = 2.5 })
			text(tx, "OPEN AGAIN 100", 240 + 130, y, 330, 60, "#ffffff", bu, "#0b0f24", 2, 26, false)
			table.insert(rects, { x = 240 + 480, y = y, w = 190, h = 60, c = "#52628e", a = bu, rr = 8, s = "#0b0f24", sw = 2.5 })
			text(tx, "CLAIM", 240 + 480, y, 190, 60, "#ffffff", bu, "#0b0f24", 2, 26, false)
			text(tx, "Legendary guaranteed in 40 opens", 240, y + 72, 800, 22, "#ffffff", bu, "#0b0f24", 1.5, 17, false)
		end
	end
	local phase = if t < T.Crack then "three hops" elseif t < T.Open then "the latch pops" elseif t < T.Rise + T.RiseLen then "the lid flies open, the knife comes out"
		else item.Name .. " (" .. item.Rarity .. ")"
	extra.caption = string.format("%s  t=%.2fs  %s  (his crate parts as stand-in boxes; his knife's .glb)", crate.Name, tc, phase)
	if process.env.SIDE then -- (SIDE=1: from the right, to see the top swing on its hinge rather than lift)
		pos = look + Vector3.new((pos - look).Magnitude, h * 0.15, 0)
	end
	scene:frame(pos, look, extra)
	if f == 0 or math.abs(t - (T.Rise + T.RiseLen)) < 0.5 / FPS then
		-- where things land on the screen (pixels), to check the framing
		local _, top = CrateMotion.project(lookY, eyeY, eyeZ, 0, h, 0, W / H)
		local msg = string.format("t=%.2f crate bottom y=%d top y=%d", tc, math.round(sy * H), math.round(top * H))
		if kp.seen then
			local ky, kz = CrateMotion.knifeSpot(kp)
			local at = CFrame.new(0, h * ky, -c.size.Z * kz) * CFrame.Angles(0, 0, kp.tilt)
			local a, b = at * Vector3.new(0, kLen * kBase * kp.scale / 2, 0), at * Vector3.new(0, -kLen * kBase * kp.scale / 2, 0)
			local ax, ay = CrateMotion.project(lookY, eyeY, eyeZ, a.X, a.Y, a.Z, W / H)
			local bx, by = CrateMotion.project(lookY, eyeY, eyeZ, b.X, b.Y, b.Z, W / H)
			msg ..= string.format("; knife tip (%d,%d) end (%d,%d), %d px long", math.round(ax * W), math.round(ay * H), math.round(bx * W), math.round(by * H), math.round(math.sqrt(((ax - bx) * W) ^ 2 + ((ay - by) * H) ^ 2)))
		end
		print(msg)
	end
	for _, mk in marks do
		if math.abs(t - mk) < 0.5 / FPS then table.insert(stills, n) end
	end
	n += 1
end
scene:save(nil, FPS, W, H, { sky = BACKDROP, ground = BACKDROP, grid = false, stills = stills, meshFile = process.env.KNIFE_MESHES, underlay = true })
print("stills at " .. table.concat(marks, ", ") .. " s")
