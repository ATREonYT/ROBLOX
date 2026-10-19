-- Fixes the owner's 30 imported knives in assets/knives/HuzzKnives.rbxm to his .glb files, one to one (owner, Oct 19:
-- "the knifes dont even have their shapes, they all dont look good ... use the glb file to get them one to one").
-- His Studio setup's first run left most parts default grey Plastic (Studio had renamed them, so its colour step
-- missed them), some still wearing the import's little colour picture, and three knives (Crimson Tanto, Night Tanto,
-- Twin Fang) turned a quarter about the blade, the flat facing the wrong way; the file kept all of that.
-- This runs his own SetupKnives helper (src/ServerStorage/HuzzStudioTools/SetupKnives.lua) offline, exactly as his
-- Studio re-run would: each knife is lined up again from its own parts on the .glb's part centres and every part
-- takes its .glb colour, Neon for his glowing parts, SmoothPlastic for the rest. His meshes are not touched. Then
-- the import's leftover pictures go (Lune can't clear the old TextureID field the helper uses) and every part is
-- checked against tools/knives/knife_boxes.json (M.match, also used by tests/KnifeModels.spec).
-- lune run huzz-valley/tools/knives/colour_knives.luau [--write]   (repo root; without --write it only reports)
local fs = require("@lune/fs")
local process = require("@lune/process")
local roblox = require("@lune/roblox")
local serde = require("@lune/serde")
local Vector3, Color3, Enum, CFrame = roblox.Vector3, roblox.Color3, roblox.Enum, roblox.CFrame

local FILE = "huzz-valley/assets/knives/HuzzKnives.rbxm"
local WRITE = table.find(process.args, "--write") ~= nil
local M = {}

-- a part's box in the Handle's space: centre and half size
function M.boxOf(handle, p)
	local rel = handle.CFrame:ToObjectSpace(p.CFrame)
	local R, h = rel.Rotation, p.Size / 2
	local e = Vector3.new(
		math.abs(R.RightVector.X) * h.X + math.abs(R.UpVector.X) * h.Y + math.abs(R.LookVector.X) * h.Z,
		math.abs(R.RightVector.Y) * h.X + math.abs(R.UpVector.Y) * h.Y + math.abs(R.LookVector.Y) * h.Z,
		math.abs(R.RightVector.Z) * h.X + math.abs(R.UpVector.Z) * h.Y + math.abs(R.LookVector.Z) * h.Z)
	return rel.Position, e
end

-- each part of a model with its .glb part: { part, node, off (centre gap), size (half-size gap), gap (centre, a
-- vector) }, the quarter turn about the blade that fits best (0 to 3; the game wants 0 or 2: SetupKnives' frame is
-- the .glb half a turn round, and a quarter puts the blade's flat the wrong way) and the worst centre gap
function M.match(model, nodes)
	local handle = model:FindFirstChild("Handle")
	local best = nil
	for q = 0, 3 do
		local R = CFrame.Angles(0, q * math.pi / 2, 0)
		local odd = q % 2 == 1
		local list, total, worst = {}, 0, 0
		local function place(n)
			local c = R * Vector3.new((n.lo[1] + n.hi[1]) / 2, (n.lo[2] + n.hi[2]) / 2, (n.lo[3] + n.hi[3]) / 2)
			local ex, ey, ez = (n.hi[1] - n.lo[1]) / 2, (n.hi[2] - n.lo[2]) / 2, (n.hi[3] - n.lo[3]) / 2
			return c, if odd then Vector3.new(ez, ey, ex) else Vector3.new(ex, ey, ez)
		end
		for _, p in model:GetDescendants() do
			if p:IsA("BasePart") and p ~= handle then
				local c, e = M.boxOf(handle, p)
				local pick, score, off, size, gap = nil, math.huge, 0, 0, Vector3.zero
				for _, n in nodes do
					local nc, ne = place(n)
					local o, s = (nc - c).Magnitude, (ne - e).Magnitude
					if o + s < score then pick, score, off, size, gap = n, o + s, o, s, c - nc end
				end
				table.insert(list, { part = p, node = pick, off = off, size = size, gap = gap })
				total += score
				worst = math.max(worst, off)
			end
		end
		if not best or total < best.total - 1e-6 then best = { list = list, total = total, turn = q, worst = worst } end
	end
	return best.list, best.turn, best.worst
end

if process.args[1] == "--module" then return M end

local boxes = serde.decode("json", fs.readFile("huzz-valley/tools/knives/knife_boxes.json"))
local insts = roblox.deserializeModel(fs.readFile(FILE))
local folder = insts[1]
local before = {}
for _, model in folder:GetChildren() do
	before[model.Name] = {}
	for _, p in model:GetDescendants() do
		if p:IsA("BasePart") then before[model.Name][p] = { p.Color:ToHex(), p.Material } end
	end
end

-- his helper, as the Command Bar runs it, on a DataModel holding the file's HuzzKnives
local luau = require("@lune/luau")
local game = roblox.Instance.new("DataModel")
folder.Parent = game:GetService("ServerStorage")
local source = fs.readFile("huzz-valley/src/ServerStorage/HuzzStudioTools/SetupKnives.lua")
source = string.gsub(source, "if script == nil then run%(%) end[^\n]*\n", "")
-- (Lune keeps an Attachment's Position apart from its CFrame, and only CFrame is saved: the helper's Grip /
-- TrailBase / TrailTip go in by CFrame here, the same place)
local swaps
source, swaps = string.gsub(source, "a%.Position = Vector3%.new%(0, y, 0%)", "a.CFrame = CFrame.new(0, y, 0)")
assert(swaps == 1, "SetupKnives' attach() changed: update colour_knives.luau")
local run = luau.load(source, { debugName = "SetupKnives", environment = { game = game, Instance = roblox.Instance,
	Vector3 = Vector3, CFrame = CFrame, Color3 = Color3, Enum = Enum } })()
run()

local changed, bad = 0, 0
for _, model in folder:GetChildren() do
	local nodes = boxes[model.Name]
	if not (nodes and model:FindFirstChild("Handle")) then continue end
	local recoloured, textured, glow = 0, 0, 0
	for _, p in model:GetDescendants() do
		if p:IsA("MeshPart") then
			local okT, tc = pcall(function() return tostring(p.TextureContent) end)
			if okT and string.find(tc, "rbxasset") then
				textured += 1
				p.TextureContent = roblox.Content.none -- (the import's own colour picture: the colour is the part's now)
			end
		end
		local was = before[model.Name][p]
		if p:IsA("BasePart") and was and (was[1] ~= p.Color:ToHex() or was[2] ~= p.Material) then recoloured += 1 end
		if p:IsA("BasePart") and p.Material == Enum.Material.Neon then glow += 1 end
	end
	local list, turn, worst = M.match(model, nodes)
	local wrong = 0
	for _, m in list do
		if m.part.Color:ToHex():lower() ~= m.node.col or (m.part.Material == Enum.Material.Neon) ~= m.node.glow then wrong += 1 end
	end
	local ok = turn % 2 == 0 and worst < 0.12 and wrong == 0
	if not ok then bad += 1 end
	changed += recoloured
	print(string.format("%-16s %2d parts, %2d recoloured, %2d glowing, %2d import pictures dropped, worst part %.3f studs from its .glb spot%s",
		model.Name, #list, recoloured, glow, textured, worst, if ok then "" else string.format("  << NOT RIGHT (turn %d, %d colours)", turn, wrong)))
end
print(changed .. " parts recoloured, " .. bad .. " knives not right")
if WRITE and bad == 0 then
	folder.Parent = nil
	fs.writeFile(FILE, roblox.serializeModel(insts))
	print("wrote " .. FILE)
end
if bad > 0 then process.exit(1) end
