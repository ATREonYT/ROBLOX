-- The owner's 3D knife crates (Oct 20: "here is the new one with updated crates, make these crates for the opening of
-- the normal knifes ... and make all of the knifes earned either through crates/bought/ or robux. and make the opening
-- animations look appropriate"), on his own place (places/HUSSANIME.rbxl):
--   1. each knife crate in Config/Crates names a set and crate he built (Workspace > scrates > Standard_Crates), and
--      holds exactly the ten knives he laid out in front of that crate (matched by his knife model names);
--   2. Shared/CrateMotion.split opens each crate sensibly (a top that swings, the body and the light inside stay, the
--      hinge at the back of the body's top) and his knife models are there for the reveal;
--   3. every knife in Config/CoinShop can be got through a crate, coins or Robux (a Game Pass or a product);
--   4. the opening's motion: it builds up, the top opens and stays open, the knife rises and ends facing you, nothing
--      moves when motion is reduced.
-- lune run tests/CrateModels.spec.luau   (from huzz-valley/)
local fs = require("@lune/fs")
local process = require("@lune/process")
local roblox = require("@lune/roblox")
local Env = require("../tools/preview/motion3d/env")
local Vector3 = roblox.Vector3
local CrateMotion = require("../src/ReplicatedStorage/Shared/CrateMotion")
local Crates = Env.load("huzz-valley/src/ReplicatedStorage/Shared/Config/Crates.lua")
local CoinShop = Env.load("huzz-valley/src/ReplicatedStorage/Shared/Config/CoinShop.lua")
local Products = Env.load("huzz-valley/src/ReplicatedStorage/Shared/Config/Products.lua")
local Halloween = Env.load("huzz-valley/src/ReplicatedStorage/Shared/Config/HalloweenShop.lua")
local CrateModels = Env.load("huzz-valley/src/ReplicatedStorage/Shared/CrateModels.lua")

local passed, failed = 0, 0
local function check(name, ok)
	if ok then passed += 1 else failed += 1; print("FAIL " .. name) end
end
local show = process.env.PRINT == "1"

-- his knife model's name in a crate set ("05_Common_Plain_Tanto" -> "Plain_Tanto")
local function setName(item)
	return item.Model and string.match(item.Model, "^%d+_%a+_(.+)$")
end

-- the middle of a model's parts (his crates are built square to the world: their own frame is the world's, moved)
local function middle(m)
	local lo, hi = Vector3.new(math.huge, math.huge, math.huge), Vector3.new(-math.huge, -math.huge, -math.huge)
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") then
			local p, h = d.CFrame.Position, d.Size / 2
			lo = Vector3.new(math.min(lo.X, p.X - h.X), math.min(lo.Y, p.Y - h.Y), math.min(lo.Z, p.Z - h.Z))
			hi = Vector3.new(math.max(hi.X, p.X + h.X), math.max(hi.Y, p.Y + h.Y), math.max(hi.Z, p.Z + h.Z))
		end
	end
	return roblox.CFrame.new((lo + hi) / 2)
end

-- 1. his crates and their knives
local game = roblox.deserializePlace(fs.readFile("places/HUSSANIME.rbxl"))
local holder = game:GetService("Workspace"):FindFirstChild("scrates")
holder = holder and holder:FindFirstChild("Standard_Crates")
check("his crates: Workspace > scrates > Standard_Crates", holder ~= nil)
local knifeCrates = {}
for _, c in Crates.List do
	if c.Model then table.insert(knifeCrates, c) end
end
check("three knife crates with his models (" .. #knifeCrates .. ")", #knifeCrates == 3)
local inCrates = {}
for _, c in knifeCrates do
	local set = holder and holder:FindFirstChild(c.Model.Set)
	local crate = set and set:FindFirstChild(c.Model.Crate)
	check(c.Id .. ": his set " .. c.Model.Set .. " and crate " .. c.Model.Crate, crate ~= nil and crate:IsA("Model"))
	if set and crate then
		local knives = {}
		for _, m in set:GetChildren() do
			if m ~= crate and m:IsA("Model") then knives[m.Name] = true end
		end
		local n, matched = 0, 0
		for _ in knives do n += 1 end
		for _, it in c.Items do
			local shop = CoinShop.get(it.Id)
			local name = shop and setName(shop)
			if name and knives[name] then matched += 1 end
			if show then print(string.format("  %s: %s (%s, %s) -> %s", c.Id, it.Id, it.Name, it.Rarity, tostring(name))) end
		end
		check(`{c.Id}: the {n} knives beside his crate are its {#c.Items} items ({matched} matched)`, n == 10 and #c.Items == 10 and matched == 10)
		-- 2. it opens: split on his parts in the crate's own frame (front to -Z, as he built all three)
		local rows, parts = {}, {}
		local pivot = middle(crate)
		for _, d in crate:GetDescendants() do
			if d:IsA("BasePart") then
				local l = pivot:PointToObjectSpace(d.CFrame.Position)
				table.insert(rows, { name = d.Name, y = l.Y, z = l.Z, sy = d.Size.Y, sz = d.Size.Z, group = CrateModels.groupOf(d, crate) })
				table.insert(parts, d)
			end
		end
		local opens, hy, hz = CrateMotion.split(rows, c.Model.Body)
		local names, insideMoves, bodyMoves = {}, false, false
		for _, i in opens do
			local base = string.gsub(rows[i].name, "_%d+$", "")
			names[base] = (names[base] or 0) + 1
			if string.sub(base, 1, 11) == "glow_inside" then insideMoves = true end
			if base == c.Model.Body then bodyMoves = true end
		end
		local list = {}
		for k, v in names do table.insert(list, k .. (if v > 1 then "x" .. v else "")) end
		table.sort(list)
		if show then print(string.format("  %s opens %d of %d parts (hinge y %.2f z %.2f): %s", c.Id, #opens, #rows, hy, hz, table.concat(list, ", "))) end
		check(`{c.Id}: a top that opens ({#opens} of {#rows} parts)`, #opens >= 5 and #opens < #rows * 0.8)
		check(c.Id .. ": its body and the light inside stay", not insideMoves and not bodyMoves)
		-- shut (his Built angle back): the front of the top comes down onto the body, not into it
		local built = math.rad(c.Model.Built or 0)
		local frontI, frontZ = nil, math.huge
		for _, i in opens do if rows[i].z < frontZ then frontI, frontZ = i, rows[i].z end end
		if frontI then
			local r = rows[frontI]
			local dy, dz = r.y - hy, r.z - hz
			local sy = dy * math.cos(-built) - dz * math.sin(-built) -- (rotated about the hinge, as UI/Crate3D does)
			if show then print(string.format("  %s shut: its front part %s sits %.2f over the body's top (built %.2f)", c.Id, r.name, sy, dy)) end
			check(string.format("%s: shut, the front of its top rests on the body (%.2f studs over it)", c.Id, sy), sy > -0.12 and sy < 0.3)
		end
		-- the front: the knives he laid out sit in front of the crate, on its -Z side
		local front = 0
		for _, m in set:GetChildren() do
			if m ~= crate and m:IsA("Model") then
				if pivot:PointToObjectSpace(middle(m).Position).Z < 0 then front += 1 end
			end
		end
		check(c.Id .. ": his knives lie on its front (-Z) side", front == 10)
		local lidded = names.lid or names.vault_lid or names.chest_lid or names.roof_upper or names.roof_lower
		check(c.Id .. ": the part he named lid (or the roof) is in the top", lidded ~= nil)
		-- his model takes Studio's MeshParts as they are (nothing to redraw): every part is a MeshPart or plain part
		local meshParts = 0
		for _, p in parts do if p:IsA("MeshPart") then meshParts += 1 end end
		check(c.Id .. ": his MeshParts as he imported them", meshParts == #parts)
	end
	for _, it in c.Items do inCrates[it.Id] = true end
	-- every rarer tier is rarer (kid-fair odds: an Epic never likelier than a Rare)
	local tier, total = {}, 0
	for _, it in c.Items do tier[it.Rarity] = (tier[it.Rarity] or 0) + it.Weight; total += it.Weight end
	local order, prev, fair, line = { "Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic" }, math.huge, true, {}
	for _, r in order do
		if tier[r] then
			if tier[r] > prev + 1e-9 then fair = false end
			prev = tier[r]
			table.insert(line, string.format("%s %.1f%%", string.sub(r, 1, 1), tier[r] / total * 100))
		end
	end
	check(`{c.Id}: each rarer tier is rarer ({table.concat(line, " / ")})`, fair)
end
for _, c in Crates.List do
	for _, it in c.Items do
		if it.Kind == "Cosmetic" then inCrates[it.Id] = true end
	end
end

-- 3. every knife can be got: a crate, coins, Aura (the Halloween shop) or Robux (a Game Pass or a product)
local passes, robuxKnife = {}, {}
for _, list in { Products.Passes or {}, Products.List or {}, Products.Halloween or {}, Products.Items or {} } do
	for _, p in list do
		if p.Key then passes[p.Key] = p end
		if p.Kind == "Knife" and p.Knife then robuxKnife[p.Knife] = true end
	end
end
local auraKnife = {}
for _, k in Halloween.Knives do auraKnife[k.Key] = true end
local knives, without = 0, {}
for _, it in CoinShop.Items do
	if it.Slot == "Knife" then
		knives += 1
		local coins = (it.Price or 0) > 0 and not it.NotForSale and not it.Unlock and not it.Earn
		local pass = it.Pass ~= nil and passes[it.Pass] ~= nil
		local ways = {}
		if inCrates[it.Key] then table.insert(ways, "crate") end
		if coins then table.insert(ways, "coins") end
		if auraKnife[it.Key] then table.insert(ways, "Aura") end
		if pass then table.insert(ways, "Game Pass") end
		if robuxKnife[it.Key] then table.insert(ways, "Robux") end
		if it.Unlock then table.insert(ways, "quest") end
		if show then print(string.format("  %-20s %-10s %s", it.Key, it.Rarity or "", table.concat(ways, ", "))) end
		local got = inCrates[it.Key] or coins or auraKnife[it.Key] or pass or robuxKnife[it.Key]
		check(it.Key .. ": can be got through a crate, coins, Aura or Robux", got)
		if not got then table.insert(without, it.Key) end
	end
end
check(`all {knives} knives can be got ({#without} can't: {table.concat(without, ", ")})`, #without == 0 and knives >= 53)
-- the Robux ones stay honest: every pass or product a knife needs has Id 0 until the owner makes it (never invented)
for _, it in CoinShop.Items do
	if it.Slot == "Knife" and it.Pass and passes[it.Pass] then
		local id = passes[it.Pass].Id
		check(it.Key .. ": its pass is a real number or 0 (none invented here)", type(id) == "number")
	end
end

-- 4. the motion
local T = CrateMotion.T
local early, late = 0, 0
for t = 0.05, 0.6, 0.05 do early = math.max(early, math.abs(CrateMotion.shake(t).roll)) end
for t = 1.5, 2.05, 0.05 do late = math.max(late, math.abs(CrateMotion.shake(t).roll)) end
check(string.format("it builds up: rocks harder near the end (%.1f deg -> %.1f deg)", math.deg(early), math.deg(late)), late > early * 2.5)
check("it never rocks over 15 degrees", late < math.rad(15))
local gaps = {}
for i = 2, #CrateMotion.Ticks do table.insert(gaps, CrateMotion.Ticks[i] - CrateMotion.Ticks[i - 1]) end
local closer = true
for i = 2, #gaps do if gaps[i] > gaps[i - 1] + 1e-6 then closer = false end end
check("the knocks come closer and closer", closer and CrateMotion.Ticks[#CrateMotion.Ticks] < T.Build)
check("shut until it cracks", CrateMotion.lid(T.Crack - 0.01) == 0)
local peak = 0
for t = T.Open, T.Open + T.OpenLen, 0.02 do peak = math.max(peak, CrateMotion.lid(t)) end
check(string.format("it opens past its rest and settles (peak %.0f deg, rest %.0f deg)", math.deg(peak), math.deg(CrateMotion.lid(T.Reveal))),
	peak > CrateMotion.lid(T.Reveal) and math.abs(CrateMotion.lid(T.Reveal) - CrateMotion.LidOpen) < 1e-6)
check("still once open", CrateMotion.shake(T.Open + T.OpenLen + 0.01).roll == 0)
check("no knife before it opens", not CrateMotion.knife(T.Rise - 0.01).seen and T.Rise > T.Open)
local endK = CrateMotion.knife(T.Rise + T.RiseLen)
check("the knife ends up at its show spot, full size", math.abs(endK.up - 1) < 1e-6 and math.abs(endK.scale - 1) < 1e-6)
check("the knife ends facing you (whole turns)", math.abs(endK.spin - 2 * math.pi * CrateMotion.Turns) < 1e-6)
check("the reveal comes once the knife has risen", T.Reveal >= T.Rise + T.RiseLen - 0.05)
local calmMoves = false
for t = 0, T.Reveal, 0.05 do
	local s = CrateMotion.shake(t, true)
	if s.roll ~= 0 or s.tilt ~= 0 or s.lift ~= 0 then calmMoves = true end
end
check("reduced motion: the crate never shakes", not calmMoves)
local a, b = CrateMotion.glow(0.1)
local c2, d2 = CrateMotion.glow(T.Crack + 0.3)
check("the light inside takes the rarity colour as it cracks open", b == 0 and d2 > 0.999 and c2 > a)

print(string.format("CrateModels: %d passed, %d failed", passed, failed))
if failed > 0 then process.exit(1) end
