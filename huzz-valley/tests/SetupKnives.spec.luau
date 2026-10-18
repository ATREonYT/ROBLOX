-- lune run tests/SetupKnives.spec.luau   (from huzz-valley/)
-- The owner's Studio knife setup (ServerStorage/HuzzStudioTools/SetupKnives = tools/knives/setup_knives.lua) on a
-- fake import of All_Knives.glb: Studio may turn and scale an import any way, so the parts here sit at the baked
-- centres under a random turn, size and spot. Every knife must come out in ServerStorage/HuzzKnives/<key>: Handle +Y
-- along the blade, X the blade's thin way, Grip / TrailBase / TrailTip in place, pommel to tip its length in studs,
-- glowing parts Neon in their colour, every part welded to the Handle, and the import tidied away.
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

local passed, failed = 0, 0
local function check(name, cond)
	if cond then passed += 1 else failed += 1; print("FAIL " .. name) end
end

local game = Instance.new("DataModel")
local Workspace, ServerStorage = game:GetService("Workspace"), game:GetService("ServerStorage")
local source = fs.readFile(ROOT .. "src/ServerStorage/HuzzStudioTools/SetupKnives.lua")
check("the shipped script and the Command Bar copy are the same code", (string.gsub(source, "return run%s*$", "run()")) == (string.gsub(fs.readFile(ROOT .. "tools/knives/setup_knives.lua"), "run%(%)%s*$", "run()")))
source = string.gsub(source, "return run%s*$", "return run, KNIVES")
local lines = {}
local env = { game = game, Instance = Instance, Vector3 = Vector3, CFrame = CFrame, Color3 = Color3, Enum = Enum,
	print = function(s) table.insert(lines, s) end, warn = function(s) table.insert(lines, "WARN " .. tostring(s)) end }
local run, KNIVES = luau.load(source, { debugName = "SetupKnives", environment = env })()
check("30 knives baked in", #KNIVES == 30)

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
check("Done: 30 of 30", table.find(lines, "[HuzzKnife] Done: 30 of 30 knives are in ServerStorage > HuzzKnives.") ~= nil)
check("the import is tidied away", all.Parent == nil)
local tagged = 0
for _, l in lines do if string.sub(l, 1, 11) == "[HuzzKnife]" then tagged += 1 end end
check("one [HuzzKnife] line per knife (+ the summary)", tagged >= 31)
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
		local neon, glows, welded, parts = 0, 0, 0, 0
		for _, n in k.nodes do
			local p = model:FindFirstChild(n[1])
			if p then
				parts += 1
				if n[6] == 1 then
					glows += 1
					if p.Material == Enum.Material.Neon and p.Color:ToHex():lower() == n[5] then neon += 1 end
				end
				local w = p:FindFirstChildOfClass("WeldConstraint")
				if w and w.Part0 == handle then welded += 1 end
			end
		end
		check(key .. ": every part kept", parts == #k.nodes)
		check(key .. ": glowing parts Neon in their colour", neon == glows)
		check(key .. ": every part welded to the Handle", welded == parts)
		check(key .. ": attributes", model:GetAttribute("Rarity") == k.rarity and model:GetAttribute("Skin") == key)
	end
end

-- running it again with nothing new imported keeps them
lines = {}
env.print = function(s) table.insert(lines, s) end
local ok2 = pcall(run)
check("a second run keeps all 30", ok2 and #holder:GetChildren() == 30)

print(`SetupKnives: {passed} ok, {failed} failed`)
if failed > 0 then error("SetupKnives spec failed") end
