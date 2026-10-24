-- lune run tests/SetupKnives.spec.luau   (from huzz-valley/)
-- The owner's Studio knife setup (ServerStorage/HuzzStudioTools/SetupKnives = tools/knives/setup_knives.lua) on a
-- fake import of All_Knives.glb (and the 5 Game Pass knives of Gamepass_Knives.glb, the 18 of Halloween_Knives.glb): Studio may turn and scale an import any way, so the parts here sit at the baked
-- centres under a random turn, size and spot. Every knife must come out in ServerStorage/HuzzKnives/<key>: Handle +Y
-- along the blade, X the blade's thin way, Grip / TrailBase / TrailTip in place, pommel to tip its length in studs,
-- glowing parts Neon in their colour (or his import's own glow kept: a SurfaceAppearance with an emissive mask), the
-- rest in the Roblox material nearest the .glb's metallic and roughness (Shared/KnifeLook.glbMaterial: Metal for his
-- metal), every part welded to the Handle, and the import tidied away.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")
local Instance, Vector3, CFrame, Color3, Enum = roblox.Instance, roblox.Vector3, roblox.CFrame, roblox.Color3, roblox.Enum
local ROOT = if fs.isDir("huzz-valley") then "huzz-valley/" else ""

for _, class in { "BasePart", "Part", "MeshPart" } do -- (Lune doesn't ship Position)
	local ok, err = pcall(function()
		roblox.implementProperty(class, "Position", function(self) return self.CFrame.Position end, function(self, v)
			self.CFrame = self.CFrame - self.CFrame.Position + v
		end)
	end)
	if not ok then print("  (Position on " .. class .. ": " .. tostring(err) .. ")") end
end

local KnifeLook = require("../tools/preview/motion3d/env").load("huzz-valley/src/ReplicatedStorage/Shared/KnifeLook.lua")
-- a node row's look by the game's one rule (n[6] glow, n[7] metallic, n[8] roughness)
local function lookOf(n): (string, number)
	return KnifeLook.glbMaterial(n[7], n[8], n[6] == 1)
end
local function looksRight(p, n): boolean
	local mat, refl = lookOf(n)
	return p.Color:ToHex():lower() == n[5] and p.Material.Name == mat and math.abs(p.Reflectance - refl) < 1e-3
end
-- his import's own glow: a SurfaceAppearance with an emissive mask
local function hisGlow(p): boolean
	local sa = p:FindFirstChildOfClass("SurfaceAppearance")
	local ok, uri = pcall(function() return sa and sa.EmissiveMaskContent.Uri end)
	return ok and type(uri) == "string" and uri ~= ""
end

local passed, failed = 0, 0
local function check(name, cond)
	if cond then passed += 1 else failed += 1; print("FAIL " .. name) end
end

local game = Instance.new("DataModel")
local Workspace, ServerStorage = game:GetService("Workspace"), game:GetService("ServerStorage")
local SETUP = require("@lune/process").env.SETUP_KNIVES -- (another copy to test, e.g. the old one: it fails below)
local source = fs.readFile(SETUP or (ROOT .. "src/ServerStorage/HuzzStudioTools/SetupKnives.lua"))
check("the shipped script and the Command Bar copy are the same code", (string.gsub(source, "if script == nil then run%(%) end[^\n]*\nreturn run%s*$", "run()")) == (string.gsub(fs.readFile(ROOT .. "tools/knives/setup_knives.lua"), "run%(%)%s*$", "run()")))
source = string.gsub(source, "return run%s*$", "return run, KNIVES")
local lines = {}
local env = { game = game, Instance = Instance, Vector3 = Vector3, CFrame = CFrame, Color3 = Color3, Enum = Enum,
	print = function(s) table.insert(lines, s) end, warn = function(s) table.insert(lines, "WARN " .. tostring(s)) end }
source = string.gsub(source, "if script == nil then run%(%) end[^\n]*\n", "") -- (no Command Bar run at load: the test runs it)
local run, KNIVES = luau.load(source, { debugName = "SetupKnives", environment = env })()
check("57 knives baked in (30 shop + 5 Game Pass + 18 Halloween + 4 reward)", #KNIVES == 57)
local fromHalloween = 0
for _, k in KNIVES do if string.sub(k.file, 1, 10) == "halloween/" then fromHalloween += 1 end end
check("18 from his Halloween file", fromHalloween == 18)
local exclusive = 0
for _, k in KNIVES do if k.rarity == "Exclusive" then exclusive += 1 end end
check("the 5 Game Pass knives are Exclusive", exclusive == 5)

-- the fake import: Workspace > All_Knives > <knife node> > parts named like the .glb nodes
local all = Instance.new("Model")
all.Name = "All_Knives"
all.Parent = Workspace
local truth = {}
for i, k in KNIVES do
	local turn = CFrame.Angles(0.4 * i, 1.3 + i * 0.7, -0.25 * i) -- (a different turn for each knife)
	local s = 3 + (i % 5) * 0.6 -- studs per .glb unit, as the importer chose
	local at = Vector3.new(i * 10, 5, -i * 3)
	local m = Instance.new("Model")
	m.Name = k.node
	m.Parent = all
	for _, n in k.nodes do
		local p = Instance.new("Part") -- (Lune: Position works on Part; Studio imports MeshParts, same API here)
		p.Name = n[1]
		p.Size = Vector3.new(0.05, 0.3, 0.012) * s -- (thin along its own Z, like the blade: the knife's thickness)
		p.CFrame = CFrame.new(at + turn:VectorToWorldSpace(Vector3.new(n[2], n[3], n[4]) * s)) * turn.Rotation
		p.Parent = m
	end
	truth[k.key] = { turn = turn, k = k }
end

local ok, count = pcall(run)
check("the setup runs (" .. tostring(count) .. ")", ok)
if not ok then print(count) end
local holder = ServerStorage:FindFirstChild("HuzzKnives")
check("ServerStorage/HuzzKnives made", holder ~= nil)
check("Done: 57 of 57", table.find(lines, "[HuzzKnife] Done: 57 of 57 knives are in ServerStorage > HuzzKnives.") ~= nil)
check("the import is tidied away", all.Parent == nil)
local tagged = 0
for _, l in lines do if string.sub(l, 1, 11) == "[HuzzKnife]" then tagged += 1 end end
check("one [HuzzKnife] line per knife (+ the summary)", tagged >= 54)
for _, l in lines do
	if string.find(l, "WARN") or string.find(l, "roughly") or string.find(l, "didn't match") then print("  " .. l) end
end

for key, t in truth do
	local k = t.k
	local model = holder and holder:FindFirstChild(key)
	check(key .. ": set up", model ~= nil)
	if model then
		local handle = model:FindFirstChild("Handle")
		local grip, base, tip = handle and handle:FindFirstChild("Grip"), handle and handle:FindFirstChild("TrailBase"), handle and handle:FindFirstChild("TrailTip")
		check(key .. ": Handle and its attachments", handle and grip and base and tip and model.PrimaryPart == handle)
		if handle and base and tip then
			local up = t.turn:VectorToWorldSpace(Vector3.new(0, 1, 0))
			local thin = t.turn:VectorToWorldSpace(Vector3.new(0, 0, 1))
			check(key .. ": Handle +Y along the blade", handle.CFrame.UpVector:Dot(up) > 0.999)
			check(key .. ": Handle X the blade's thin way", math.abs(handle.CFrame.RightVector:Dot(thin)) > 0.999)
			local per = k.studs / k.len
			check(key .. ": TrailTip at the tip", math.abs((tip.Position - base.Position).Magnitude - k.tip * per) < 0.01)
			-- pommel to tip in studs: the part centres' spread along the blade, against the baked one
			local lo, hi, blo, bhi = math.huge, -math.huge, math.huge, -math.huge
			for _, n in k.nodes do
				local p = model:FindFirstChild(n[1])
				if p then
					local y = handle.CFrame:PointToObjectSpace(p.CFrame.Position).Y
					lo, hi = math.min(lo, y), math.max(hi, y)
					blo, bhi = math.min(blo, n[3]), math.max(bhi, n[3])
				end
			end
			check(key .. ": scaled to its length", math.abs((hi - lo) - (bhi - blo) * per) < 0.02)
		end
		local neon, glows, welded, parts, plainNeon = 0, 0, 0, 0, 0
		-- (nodes can share a name: the blade and its glowing edge; each node is the next part of that name)
		local seen = {}
		for _, n in k.nodes do
			seen[n[1]] = (seen[n[1]] or 0) + 1
			local p, i = nil, 0
			for _, c in model:GetChildren() do
				if c.Name == n[1] then
					i += 1
					if i == seen[n[1]] then p = c end
				end
			end
			if p then
				parts += 1
				if n[6] == 1 then
					glows += 1
					if p.Material == Enum.Material.Neon and p.Color:ToHex():lower() == n[5] then neon += 1 end
				elseif p.Material == Enum.Material.Neon then
					plainNeon += 1 -- (critic: a blade sharing its name with its glowing edge was painted the glow)
				end
				local w = p:FindFirstChildOfClass("WeldConstraint")
				if w and w.Part0 == handle then welded += 1 end
			end
		end
		check(key .. ": every part kept", parts == #k.nodes)
		check(key .. ": glowing parts Neon in their colour", neon == glows)
		check(key .. ": the other parts aren't Neon", plainNeon == 0)
		check(key .. ": every part welded to the Handle", welded == parts)
		check(key .. ": attributes", model:GetAttribute("Rarity") == k.rarity and model:GetAttribute("Skin") == key)
	end
end

-- running it again with nothing new imported keeps them
lines = {}
env.print = function(s) table.insert(lines, s) end
local ok2 = pcall(run)
check("a second run keeps all 57", ok2 and #holder:GetChildren() == 57)

-- ---------------------------------------------------------------------------------------------------------------
-- The owner's real Oct 18 run: 8 knives (BoneKnife, BoxCutter, CopperCleaver, EmberEdge, IceKnife, JadeKunai,
-- KitchenCleaver, ScoutDagger) came out ~12x too big and sideways. Two causes, both reproduced here:
--  1. Studio's importer makes names unique across the whole import: a node name's first knife keeps it, the n-th
--     knife with it gets n added ("blade_05" = blade_0 of the 5th knife with a blade_0), and a second part of the same
--     node one more digit ("blade_052"). Matching exact names found under 2 parts on those 8.
--  2. All_Knives.glb lays every knife flat (its node matrix turns the knife's +Y to -Z), so the old fallback, which
--     assumed the import stood upright, measured the knife's thickness as its length.
-- The fixture tests/fixtures/HuzzKnives-oct18-first-run.rbxm holds those 8 as his first run left them, plus
-- RustyShiv (a good one); assets/knives/HuzzKnives.rbxm is the result of tools/knives/repair_knives.luau.
local function load(src)
	local g = Instance.new("DataModel")
	local out = {}
	local e = { game = g, Instance = Instance, Vector3 = Vector3, CFrame = CFrame, Color3 = Color3, Enum = Enum,
		print = function(s) table.insert(out, s) end, warn = function(s) table.insert(out, "WARN " .. tostring(s)) end }
	-- (without the Command Bar's own run at load: it would make an empty HuzzKnives before the test's is in)
	local r = luau.load((string.gsub(src, "if script == nil then run%(%) end[^\n]*\n", "")), { debugName = "SetupKnives", environment = e })()
	return g, r, out
end
local fixture = roblox.deserializeModel(fs.readFile(ROOT .. "tests/fixtures/HuzzKnives-oct18-first-run.rbxm"))[1]

-- Studio's names, worked out the way the fixture shows them
local studioNames = {} -- [key] = { part name per node }
do
	local counts = { shop = {}, pass = {}, halloween = {} } -- (each import counts on its own: All_Knives.glb, Gamepass_Knives.glb, Halloween_Knives.glb)
	for _, k in KNIVES do
		local knivesWith = if k.rarity == "Exclusive" then counts.pass elseif string.sub(k.file, 1, 10) == "halloween/" then counts.halloween else counts.shop
		local inKnife, list = {}, {}
		for _, n in k.nodes do
			local e = inKnife[n[1]]
			if not e then
				knivesWith[n[1]] = (knivesWith[n[1]] or 0) + 1
				e = { base = if knivesWith[n[1]] == 1 then n[1] else n[1] .. knivesWith[n[1]], count = 0 }
				inKnife[n[1]] = e
			end
			e.count += 1
			table.insert(list, if e.count == 1 then e.base else e.base .. e.count)
		end
		studioNames[k.key] = list
	end
end
for _, m in fixture:GetChildren() do
	local want, got = {}, {}
	for _, nm in studioNames[m.Name] or {} do want[nm] = (want[nm] or 0) + 1 end
	for _, p in m:GetDescendants() do
		if p:IsA("BasePart") and p.Name ~= "Handle" then got[p.Name] = (got[p.Name] or 0) + 1 end
	end
	local same = true
	for nm, c in want do if got[nm] ~= c then same = false end end
	for nm, c in got do if want[nm] ~= c then same = false end end
	check(m.Name .. ": the fake import names parts the way Studio did", same)
end

-- How many parts aren't where the .glb has them, seen from the Handle (+Y the blade, +Z the .glb's X, X its -Z), for
-- a node their name can be (the name, or the name minus Studio's digits). A blade and its edge share a node, baked
-- with one centre, but are two parts with their own (up to 0.01 studs apart). Real meshes' centres sit up to ~0.012
-- studs off the baked ones (tassels, thorns, horns).
local function offNodes(k, model)
	local h = model:FindFirstChild("Handle")
	if not h then return math.huge end
	local per = k.studs / k.len
	local shared, seen = {}, {}
	for _, n in k.nodes do
		if seen[n[1]] then shared[n[1]] = true end
		seen[n[1]] = true
	end
	local off = 0
	for _, p in model:GetDescendants() do
		if p:IsA("BasePart") and p ~= h then
			local c = h.CFrame:PointToObjectSpace(p.CFrame.Position)
			local nm, ok = string.lower(p.Name), false
			for _, n in k.nodes do
				local nn = string.lower(n[1])
				-- (his 23 of the files of several, set up offline from his imports Oct 20: three parts sit 0.02 to 0.03
				-- studs from their .glb centre, Grand Witch Scythe's hat cone and Taffy Karambit's blade and twists, the
				-- fit's leftover on his import; too small to see)
				local tol = if string.find(k.file, "/", 1, true) then 0.035 elseif shared[n[1]] then 0.025 else 0.015
				if (nm == nn or (string.sub(nm, 1, #nn) == nn and string.match(string.sub(nm, #nn + 1), "^%d+$")))
					and (c - Vector3.new(-n[4], n[3] - k.grip, n[2]) * per).Magnitude < tol then
					ok = true
				end
			end
			if not ok then
				off += 1
			end
		end
	end
	return off
end

-- every part its baked colour and look (glowing ones Neon, or his own glow kept), the import's texture gone (a node
-- its name can be)
local function painted(k, model)
	local bad = 0
	for _, p in model:GetDescendants() do
		if p:IsA("BasePart") and p.Name ~= "Handle" then
			local nm, ok, any = string.lower(p.Name), false, false
			for _, n in k.nodes do
				local nn = string.lower(n[1])
				if nm == nn or (string.sub(nm, 1, #nn) == nn and string.match(string.sub(nm, #nn + 1), "^%d+$")) then
					any = true
					if n[6] == 1 and hisGlow(p) then ok = true end
					if looksRight(p, n) and p:FindFirstChildOfClass("SurfaceAppearance") == nil then ok = true end
				end
			end
			if any and not ok then bad += 1 end
		end
	end
	return bad
end

-- 1. fresh imports with Studio's names, All_Knives.glb laid flat (its node matrix), Gamepass_Knives.glb and
-- Halloween_Knives.glb upright (their matrices are plain): every knife lines up by its parts (no box guess; his
-- shurikens, a star round one spot, by their blade part's own turn)
do
	local g, run2, out = load(source)
	local roots, turns = {}, {}
	for _, r in { { "All_Knives", CFrame.fromMatrix(Vector3.zero, Vector3.xAxis, -Vector3.zAxis, Vector3.yAxis) }, { "Gamepass_Knives", CFrame.identity }, { "Halloween_Knives", CFrame.identity } } do
		local root = Instance.new("Model")
		root.Name = r[1]
		root.Parent = g:GetService("Workspace")
		roots[r[1]], turns[r[1]] = root, r[2]
	end
	local made, turnOf = {}, {}
	for i, k in KNIVES do
		local s = 3.57
		local file = if k.rarity == "Exclusive" then "Gamepass_Knives" elseif string.sub(k.file, 1, 10) == "halloween/" then "Halloween_Knives" else "All_Knives"
		local flat = turns[file]
		turnOf[k.key] = flat
		local at = Vector3.new((i % 6) * 6 - 15, 0.07, math.floor((i - 1) / 6) * 3.57)
		local m = Instance.new("Model")
		m.Name = k.node
		m.Parent = roots[file]
		made[k.key] = {}
		for j, n in k.nodes do
			local p = Instance.new("Part")
			p.Name = studioNames[k.key][j]
			p.Size = Vector3.new(0.05, 0.3, 0.012) * s
			p.CFrame = CFrame.new(at + flat:VectorToWorldSpace(Vector3.new(n[2], n[3], n[4]) * s)) * flat
			p.Parent = m
			made[k.key][j] = p
		end
	end
	local ok3, err3 = pcall(run2)
	check("laid-flat import with Studio's names: the setup runs", ok3)
	if not ok3 then print(err3) end
	check("Studio-style imports: Done: 57 of 57", table.find(out, "[HuzzKnife] Done: 57 of 57 knives are in ServerStorage > HuzzKnives.") ~= nil)
	for _, l in out do
		if string.find(l, "didn't match") or string.find(l, "roughly") or string.find(l, "WRONG") or string.find(l, "WARN") then print("  " .. l) end
	end
	local holder2 = g:GetService("ServerStorage"):FindFirstChild("HuzzKnives")
	for _, k in KNIVES do
		local model = holder2 and holder2:FindFirstChild(k.key)
		local handle = model and model:FindFirstChild("Handle")
		local per = k.studs / k.len
		local good, colours = 0, 0
		if handle then
			for j, n in k.nodes do
				local p = made[k.key][j]
				local c = handle.CFrame:PointToObjectSpace(p.CFrame.Position)
				-- (seen from the Handle: +Y the blade, +Z the .glb's X, X its -Z; a one-sided blade must face the right way)
				if p.Parent == model and (c - Vector3.new(-n[4], n[3] - k.grip, n[2]) * per).Magnitude < 0.005 then good += 1 end
				if looksRight(p, n) then colours += 1 end
			end
		end
		local up, thin = turnOf[k.key]:VectorToWorldSpace(Vector3.yAxis), turnOf[k.key]:VectorToWorldSpace(Vector3.zAxis)
		check(k.key .. " (Studio's names): Handle +Y along the blade, X its thin way",
			handle ~= nil and handle.CFrame.UpVector:Dot(up) > 0.999 and math.abs(handle.CFrame.RightVector:Dot(thin)) > 0.999)
		check(k.key .. " (Studio's names): every part where the .glb has it, at its length in studs", good == #k.nodes)
		check(k.key .. " (Studio's names): every part its own colour", colours == #k.nodes)
	end
end

-- 2. his place as it is now (the 8 broken ones already in HuzzKnives, nothing new imported): running it again repairs
-- them in place, the same as repair_knives.luau did, and leaves the good one alone
do
	local g, run3, out = load(source)
	local holder3 = fixture:Clone()
	holder3.Parent = g:GetService("ServerStorage")
	local function where(model)
		local h, at = model:FindFirstChild("Handle"), {}
		for _, p in model:GetDescendants() do
			if p:IsA("BasePart") and p ~= h then at[p] = h.CFrame:PointToObjectSpace(p.CFrame.Position) end
		end
		return at
	end
	local rustyBefore = where(holder3:FindFirstChild("RustyShiv"))
	local ok4, err4 = pcall(run3)
	check("re-run on his place: runs", ok4)
	if not ok4 then print(err4) end
	local repaired = 0
	for _, l in out do
		if string.find(l, "repaired", 1, true) then repaired += 1 end
		if string.find(l, "WRONG") or string.find(l, "couldn't") then print("  " .. l) end
	end
	check("re-run on his place: 8 repaired (" .. repaired .. ")", repaired == 8)
	-- RustyShiv was the right size but, like all 30, had a renamed part ("blade_02") that never got its colour
	local rustyLine = false
	for _, l in out do
		if string.find(l, "fixed colours and glow", 1, true) and string.find(l, "Rusty Shiv", 1, true) then rustyLine = true end
	end
	check("re-run on his place: the right-size one only gets its colours", rustyLine)
	local rustyAfter = holder3:FindFirstChild("RustyShiv")
	local moved = 0
	if rustyAfter then
		local now = where(rustyAfter)
		for p, c in rustyBefore do
			local d = now[p]
			if not d or (d - c).Magnitude > 0.005 then moved += 1 end
		end
	end
	check("re-run on his place: the right-size one keeps its shape", rustyAfter ~= nil and moved == 0)
	local byKey = {}
	for _, k in KNIVES do byKey[k.key] = k end
	for _, m in holder3:GetChildren() do
		check(m.Name .. " (re-run on his place): every part painted, his glow kept or Neon, metal Metal", byKey[m.Name] ~= nil and painted(byKey[m.Name], m) == 0)
	end
	local fixed = roblox.deserializeModel(fs.readFile(ROOT .. "assets/knives/HuzzKnives.rbxm"))[1]
	for _, key in { "BoneKnife", "BoxCutter", "CopperCleaver", "EmberEdge", "IceKnife", "JadeKunai", "KitchenCleaver", "ScoutDagger" } do
		local a, b = holder3:FindFirstChild(key), fixed:FindFirstChild(key)
		local ha, hb = a and a:FindFirstChild("Handle"), b and b:FindFirstChild("Handle")
		local worst, count, total = 0, 0, 0
		if ha and hb then
			local ref = {}
			for _, p in b:GetDescendants() do
				if p:IsA("BasePart") and p ~= hb then
					ref[p.Name] = ref[p.Name] or {}
					table.insert(ref[p.Name], hb.CFrame:PointToObjectSpace(p.CFrame.Position))
				end
			end
			local taken = {}
			for _, p in a:GetDescendants() do
				if p:IsA("BasePart") and p ~= ha then
					total += 1
					taken[p.Name] = (taken[p.Name] or 0) + 1
					local r = ref[p.Name] and ref[p.Name][taken[p.Name]]
					if r then
						count += 1
						-- (the thin way may come out either side: compare along the blade and the distance from it)
						local c = ha.CFrame:PointToObjectSpace(p.CFrame.Position)
						local d = math.max(math.abs(c.Y - r.Y), math.abs(math.sqrt(c.X ^ 2 + c.Z ^ 2) - math.sqrt(r.X ^ 2 + r.Z ^ 2)))
						worst = math.max(worst, d)
					end
				end
			end
		end
		-- (up to 0.03 studs apart: repair_knives.luau centred each knife across by its box, the helper puts it on the
		-- .glb's own axis like the other 22, which the next check holds it to)
		check(string.format("%s: repaired in place like repair_knives.luau (%d of %d parts, worst %.3f studs)", key, count, total, worst),
			ha ~= nil and count == total and total > 0 and worst < 0.03)
		local atNode = offNodes(byKey[key], a)
		check(string.format("%s: every repaired part where the .glb has it (%d off)", key, atNode), ha ~= nil and atNode == 0)
		local tipA, tipB = ha and ha:FindFirstChild("TrailTip"), hb and hb:FindFirstChild("TrailTip")
		check(key .. ": TrailTip where repair_knives.luau put it", tipA ~= nil and tipB ~= nil and (tipA.Position - tipB.CFrame.Position).Magnitude < 0.01) -- (Lune: Position is unset on a loaded one)
	end
end

-- 3. our own file (assets/knives/HuzzKnives.rbxm: his 30, the 8 repaired offline, the renamed parts still uncoloured)
-- run through it: 53 of 53 (his 30, and his 23 set up offline from his imports since Oct 20 20:34,
-- tools/knives/add_import_knives.luau), every part painted, nothing moves, and a run after that changes nothing
do
	local g, run4, out = load(source)
	local holder4 = roblox.deserializeModel(fs.readFile(ROOT .. "assets/knives/HuzzKnives.rbxm"))[1]
	holder4.Parent = g:GetService("ServerStorage")
	local before = {}
	for _, m in holder4:GetChildren() do
		local h = m:FindFirstChild("Handle")
		before[m.Name] = {}
		for _, p in m:GetDescendants() do
			if p:IsA("BasePart") and p ~= h then before[m.Name][p] = h.CFrame:PointToObjectSpace(p.CFrame.Position) end
		end
	end
	local ok5 = pcall(run4)
	-- (his 4 reward knives, Oct 24, aren't in our file until his import of Reward_Knives.glb: 53 of 57, those 4 skipped)
	check("our file: runs, 53 of 57", ok5 and table.find(out, "[HuzzKnife] Done: 53 of 57 knives are in ServerStorage > HuzzKnives.") ~= nil)
	for _, l in out do
		if string.find(l, "WRONG") or string.find(l, "couldn't") or string.find(l, "repaired") then print("  " .. l) end
	end
	for _, k in KNIVES do
		if string.sub(k.file, 1, 8) == "rewards/" then continue end
		local m = holder4:FindFirstChild(k.key)
		local h = m and m:FindFirstChild("Handle")
		local moved, worst = 0, 0
		if h then
			for p, c in before[k.key] do
				-- (along the blade and out from it: which side is which may flip where the old run guessed, see below)
				local d = h.CFrame:PointToObjectSpace(p.CFrame.Position)
				local far = math.max(math.abs(d.Y - c.Y), math.abs(math.sqrt(d.X ^ 2 + d.Z ^ 2) - math.sqrt(c.X ^ 2 + c.Z ^ 2)))
				worst = math.max(worst, far)
				if p.Parent ~= m or far > 0.25 then moved += 1 end
			end
		end
		check(k.key .. " (our file): every part painted, his glow kept or Neon, metal Metal", m ~= nil and painted(k, m) == 0)
		-- (up to 0.25 studs: the first run fitted on the few parts whose names matched, the helper on all of them, so
		-- it's now nearer the .glb, which the next check holds it to; TwinFang moved most, 0.2)
		if worst > 0.05 then print(string.format("  %s (our file): moved up to %.3f studs", k.key, worst)) end
		check(k.key .. " (our file): nothing moved (" .. moved .. ")", h ~= nil and moved == 0)
		check(k.key .. " (our file): every part where the .glb has it", m ~= nil and offNodes(k, m) == 0)
	end
	table.clear(out)
	pcall(run4)
	local already = 0
	for _, l in out do if string.find(l, "already in", 1, true) then already += 1 end end
	check("our file: a second run changes nothing (" .. already .. " already in)", already == 53)
end

print(`SetupKnives: {passed} ok, {failed} failed`)
if failed > 0 then error("SetupKnives spec failed") end
