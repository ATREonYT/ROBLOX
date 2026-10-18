-- Repairs knives in assets/knives/HuzzKnives.rbxm that came out of the Studio setup the wrong size and the wrong
-- way round (Oct 18 file: 8 of 30, all with every part on the knife's axis, about 12 times too big and lying along
-- the Handle's X). The meshes are not touched: only where each part sits and how big it is.
-- For each model that fails Shared/KnifeLook.sane, it finds the knife's axis (the way the parts' centres spread),
-- matches each part to the baked .glb node it came from (tools/knives: names in the setup data), fits how far along
-- the axis each part is against the node's height in the .glb, and rebuilds the model in the setup's frame: Handle at
-- the grip's middle, +Y to the tip, X the blade's thin way, pommel to tip its Studs length, the Grip / TrailBase /
-- TrailTip attachments where the setup puts them. Then it checks every part sits where its .glb node says.
-- lune run huzz-valley/tools/knives/repair_knives.luau [--write]   (repo root; without --write it only reports)
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local process = require("@lune/process")
local roblox = require("@lune/roblox")
local CFrame, Vector3 = roblox.CFrame, roblox.Vector3
local Env = require("../preview/motion3d/env")
local KnifeLook = Env.load("huzz-valley/src/ReplicatedStorage/Shared/KnifeLook.lua")

local FILE = "huzz-valley/assets/knives/HuzzKnives.rbxm"
local WRITE = table.find(process.args, "--write") ~= nil

-- the setup's baked data (every knife's nodes with their .glb centres)
local source = fs.readFile("huzz-valley/src/ServerStorage/HuzzStudioTools/SetupKnives.lua")
source = string.gsub(source, "return run%s*$", "return KNIVES")
source = string.gsub(source, "if script == nil then run%(%) end[^\n]*\n", "")
local KNIVES = luau.load(source, { debugName = "SetupKnives", environment = { game = roblox.Instance.new("DataModel"), Instance = roblox.Instance, Vector3 = Vector3, CFrame = CFrame, Color3 = roblox.Color3, Enum = roblox.Enum } })()
local byKey = {}
for _, k in KNIVES do byKey[k.key] = k end

local insts = roblox.deserializeModel(fs.readFile(FILE))
local folder = insts[1]

local function partsOf(model, handle)
	local out = {}
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then table.insert(out, { name = d.Name, cf = handle.CFrame:ToObjectSpace(d.CFrame), size = d.Size, part = d }) end
	end
	return out
end

-- the baked node a part came from: the longest node name the part's name starts with
local function nodeOf(k, name)
	local best = nil
	for _, n in k.nodes do
		if string.sub(name, 1, #n[1]) == n[1] and (best == nil or #n[1] > #best[1]) then best = n end
	end
	return best
end

local AXES = { Vector3.xAxis, Vector3.yAxis, Vector3.zAxis }
local fixed, bad = 0, 0
for _, model in folder:GetChildren() do
	local handle = model:FindFirstChild("Handle")
	local k = byKey[model.Name]
	if not (handle and k) then continue end
	local parts = partsOf(model, handle)
	if KnifeLook.sane(KnifeLook.shape(parts), model:GetAttribute("Studs")) then continue end
	-- the axis: where the part centres spread the most
	local axis, spread = nil, -1
	for _, a in AXES do
		local lo, hi = math.huge, -math.huge
		for _, p in parts do
			if p.part ~= handle then
				local v = p.cf.Position:Dot(a)
				lo, hi = math.min(lo, v), math.max(hi, v)
			end
		end
		if hi - lo > spread then axis, spread = a, hi - lo end
	end
	-- along = a + b * (the node's .glb height): least squares over every matched part
	local n, sy, sv, syy, syv = 0, 0, 0, 0, 0
	for _, p in parts do
		local node = p.part ~= handle and nodeOf(k, p.name)
		if node then
			local y, v = node[3], p.cf.Position:Dot(axis)
			n += 1; sy += y; sv += v; syy += y * y; syv += y * v
		end
	end
	local b = (n * syv - sy * sv) / (n * syy - sy * sy)
	local a = (sv - b * sy) / n
	local per = k.studs / k.len -- studs per .glb unit in the game
	local f = per / math.abs(b)
	local Y = axis * (if b > 0 then 1 else -1)
	-- the thin way: the biggest blade part's thinnest side across the axis
	local blade, vol = nil, -1
	for _, p in parts do
		local s = p.size
		if string.sub(string.lower(p.name), 1, 6) == "blade_" and s.X * s.Y * s.Z > vol then blade, vol = p, s.X * s.Y * s.Z end
	end
	local X, best = nil, math.huge
	for _, ax in { { blade.cf.RightVector, blade.size.X }, { blade.cf.UpVector, blade.size.Y }, { blade.cf.LookVector, blade.size.Z } } do
		if math.abs(ax[1]:Dot(Y)) < 0.3 and ax[2] < best then best, X = ax[2], ax[1] end
	end
	X = (X - Y * X:Dot(Y)).Unit
	-- the grip's middle: on the axis at the .glb's grip height, centred across it
	local mid = Vector3.zero
	for _, p in parts do if p.part ~= handle then mid += p.cf.Position end end
	mid /= (#parts - 1)
	local origin = mid - axis * mid:Dot(axis) + axis * (a + b * k.grip)
	local frame = CFrame.fromMatrix(origin, X, Y) -- the new Handle, in the old Handle's space
	local worst = 0
	for _, p in parts do
		if p.part ~= handle then
			local rel = frame:ToObjectSpace(p.cf)
			p.part.CFrame = handle.CFrame * (CFrame.new(rel.Position * f) * rel.Rotation)
			p.part.Size = p.size * f
			local node = nodeOf(k, p.name)
			if node then
				local want = (node[3] - k.grip) * per
				worst = math.max(worst, math.abs(rel.Position.Y * f - want))
			end
		end
	end
	for _, at in handle:GetChildren() do
		if at:IsA("Attachment") then
			local y = if at.Name == "TrailBase" then (0 - k.grip) * per elseif at.Name == "TrailTip" then (k.tip - k.grip) * per else 0
			at.CFrame = CFrame.new(0, y, 0)
		end
	end
	local after = KnifeLook.shape(partsOf(model, handle))
	local ok = KnifeLook.sane(after, model:GetAttribute("Studs")) and worst < 0.05
	print(string.format("%-16s %s: scale x%.4f, length %.2f (wants %.2f), worst part off its .glb spot %.3f studs", model.Name,
		if ok then "fixed" else "NOT FIXED", f, after.length, model:GetAttribute("Studs"), worst))
	if ok then fixed += 1 else bad += 1 end
end
print(`{fixed} fixed, {bad} could not be fixed`)
if WRITE and fixed > 0 and bad == 0 then
	fs.writeFile(FILE, roblox.serializeModel(insts))
	print("wrote " .. FILE)
end
if bad > 0 then process.exit(1) end
