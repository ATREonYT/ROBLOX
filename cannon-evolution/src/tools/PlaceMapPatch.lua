--[[
	PlaceMapPatch: paste into the Command Bar once, right after Import 3D of map/MapPatch.glb. Safe to run again.

	Roblox caps a MeshPart at 2048 studs a side. Two volcano pieces of CannonMap.glb were 3,028 studs long
	(their big ground slabs run the whole stage), so Import 3D squashed them and the volcano stage got
	holes (Alex, Oct 30: "why is there some parts of the map missing?"). Two Aurora Peaks pieces are 1,760
	long and two Igloo Camp pieces 1,364, which go over the cap once the map is built bigger
	(Config.Map.Scale: 1.3 on Oct 30, 2 on Oct 31). tools/map/make_patch.py cut all six into pieces that
	fit at 2x (the props stay one piece, the long ground slabs become two or four); this puts those pieces
	exactly where the old ones belong, at the map's current size, with the old ones' look and collisions,
	and removes the old ones. pack_map.py now cuts long pieces itself, so a fresh pack doesn't need this.
]]

local Config = require(game.ReplicatedStorage.GameConfig)

local TAG = "[MapPatch]"

-- from make_patch.py: where each new piece goes, in the file's units
local PLAZA = { centre = Vector3.new(-60.0000, 2.1350, 0.0000), width = 18.7000 }
local PIECES = { -- new piece = { replaces, centre, size }
	["12_Aurora_Peaks_03"] = { "12_Aurora_Peaks_03", Vector3.new(6215.8410, 36.9158, 0.0000), Vector3.new(248.3179, 81.8315, 256.0000) }, -- 10910 triangles
	["12_Aurora_Peaks_03_base1"] = { "12_Aurora_Peaks_03", Vector3.new(6096.0005, 11.1500, 8.0000), Vector3.new(880.0010, 14.3000, 113.6000) }, -- 36 triangles
	["12_Aurora_Peaks_03_base2"] = { "12_Aurora_Peaks_03", Vector3.new(6976.0005, 7.1500, 0.0000), Vector3.new(879.9990, 6.3000, 97.6000) }, -- 16 triangles
	["12_Aurora_Peaks_06"] = { "12_Aurora_Peaks_06", Vector3.new(6882.0000, 36.9360, 0.0000), Vector3.new(260.0000, 81.8720, 256.0000) }, -- 10890 triangles
	["12_Aurora_Peaks_06_base1"] = { "12_Aurora_Peaks_06", Vector3.new(6096.0005, 7.1500, 0.0000), Vector3.new(880.0010, 6.3000, 97.6000) }, -- 16 triangles
	["12_Aurora_Peaks_06_base2"] = { "12_Aurora_Peaks_06", Vector3.new(6976.0005, 15.1500, 0.0000), Vector3.new(879.9990, 22.3000, 161.6000) }, -- 56 triangles
	["14_Volcano_Core_06"] = { "14_Volcano_Core_06", Vector3.new(10779.0981, 36.4841, 0.4960), Vector3.new(222.1963, 80.9683, 256.9919) }, -- 11552 triangles
	["14_Volcano_Core_06_base1"] = { "14_Volcano_Core_06", Vector3.new(10142.3401, 3.9250, -0.0000), Vector3.new(757.1256, 8.7500, 97.6000) }, -- 48 triangles
	["14_Volcano_Core_06_base2"] = { "14_Volcano_Core_06", Vector3.new(10899.4656, 10.9250, 0.0000), Vector3.new(757.1255, 22.7500, 161.6000) }, -- 56 triangles
	["14_Volcano_Core_06_base3"] = { "14_Volcano_Core_06", Vector3.new(11656.5912, 3.9250, -0.0000), Vector3.new(757.1255, 8.7500, 97.6000) }, -- 48 triangles
	["14_Volcano_Core_06_base4"] = { "14_Volcano_Core_06", Vector3.new(12413.7147, 3.9250, -0.0000), Vector3.new(757.1215, 8.7500, 97.6000) }, -- 24 triangles
	["14_Volcano_Core_11"] = { "14_Volcano_Core_11", Vector3.new(11732.0000, 36.4405, -0.0000), Vector3.new(232.0000, 80.8809, 256.0000) }, -- 11560 triangles
	["14_Volcano_Core_11_base1"] = { "14_Volcano_Core_11", Vector3.new(10142.3401, 3.9250, -0.0000), Vector3.new(757.1256, 8.7500, 97.6000) }, -- 24 triangles
	["14_Volcano_Core_11_base2"] = { "14_Volcano_Core_11", Vector3.new(10899.4656, 3.9250, -0.0000), Vector3.new(757.1255, 8.7500, 97.6000) }, -- 48 triangles
	["14_Volcano_Core_11_base3"] = { "14_Volcano_Core_11", Vector3.new(11656.5912, 3.9250, -0.0000), Vector3.new(757.1255, 8.7500, 97.6000) }, -- 48 triangles
	["14_Volcano_Core_11_base4"] = { "14_Volcano_Core_11", Vector3.new(12413.7147, 3.9250, -0.0000), Vector3.new(757.1215, 8.7500, 97.6000) }, -- 48 triangles
	["11_Igloo_Camp_05"] = { "11_Igloo_Camp_05", Vector3.new(4758.0000, 28.9788, -0.2032), Vector3.new(140.0000, 65.9576, 256.4065) }, -- 11172 triangles
	["11_Igloo_Camp_05_base1"] = { "11_Igloo_Camp_05", Vector3.new(4613.0005, 2.1500, 0.0000), Vector3.new(682.0010, 0.3000, 65.6000) }, -- 16 triangles
	["11_Igloo_Camp_05_base2"] = { "11_Igloo_Camp_05", Vector3.new(5295.0005, 2.1500, 0.0000), Vector3.new(681.9990, 0.3000, 65.6000) }, -- 8 triangles
	["11_Igloo_Camp_09"] = { "11_Igloo_Camp_09", Vector3.new(5170.0000, 34.4361, -0.2337), Vector3.new(148.0000, 76.8723, 256.4675) }, -- 11172 triangles
	["11_Igloo_Camp_09_base1"] = { "11_Igloo_Camp_09", Vector3.new(4613.0005, 2.1500, 0.0000), Vector3.new(682.0010, 0.3000, 65.6000) }, -- 8 triangles
	["11_Igloo_Camp_09_base2"] = { "11_Igloo_Camp_09", Vector3.new(5295.0005, 2.1500, 0.0000), Vector3.new(681.9990, 0.3000, 65.6000) }, -- 16 triangles
}

local map = workspace:FindFirstChild(Config.Map.Root)
if not map then
	error(TAG .. " no CannonMap in Workspace: run BuildCannonMap first")
end
local stages = map:FindFirstChild(Config.Map.Stages)

-- the imported patch: any other model holding the new pieces
local patch, found = nil, {}
for _, c in ipairs(workspace:GetChildren()) do
	if c ~= map and c:IsA("Model") then
		for _, d in ipairs(c:GetDescendants()) do
			if d:IsA("MeshPart") and PIECES[d.Name] then
				patch = c
				found[d.Name] = d
			end
		end
	end
	if patch then
		break
	end
end
if not patch then
	local done = map:FindFirstChild("14_Volcano_Core_06_base1", true)
	print(TAG, done and "already done: the long pieces are in place" or "no patch in Workspace: Import 3D map/MapPatch.glb first")
	return
end

-- the map's scale and spot, from the compass plaza like BuildCannonMap
local lo, hi = Vector3.one * math.huge, -Vector3.one * math.huge
for _, d in ipairs(map:GetDescendants()) do
	if d:IsA("BasePart") and string.find(d.Name, "^Plaza_Compass_Spawn") then
		lo = lo:Min(d.Position - d.Size / 2)
		hi = hi:Max(d.Position + d.Size / 2)
	end
end
local s = (hi.X - lo.X) / PLAZA.width
local offset = (lo + hi) / 2 - PLAZA.centre * s

-- Import 3D turns a file round (it turned the map 180 degrees); two far-apart pieces show by how much
local function heading(v)
	return math.atan2(-v.Z, v.X)
end
local a, b = found["14_Volcano_Core_06_base1"], found["14_Volcano_Core_06_base4"]
local yaw = 0
if a and b then
	local fileWay = PIECES[b.Name][2] - PIECES[a.Name][2]
	yaw = math.round((heading(b.Position - a.Position) - heading(fileWay)) / (math.pi / 2)) * (math.pi / 2)
end
if math.abs(math.sin(yaw)) > 0.5 then
	error(TAG .. " the patch came in turned sideways; delete it and import it again")
end
local unturn = CFrame.Angles(0, -yaw, 0)

-- keep the old pieces' look and collisions, then take them out (only those whose new pieces came in)
local looks = {}
for name, info in pairs(PIECES) do
	local old = found[name] and map:FindFirstChild(info[1], true)
	if old and old:IsA("MeshPart") and not looks[info[1]] then
		looks[info[1]] = {
			Anchored = old.Anchored, CanCollide = old.CanCollide, CanTouch = old.CanTouch, CanQuery = old.CanQuery,
			CastShadow = old.CastShadow, Material = old.Material, Color = old.Color, TextureID = old.TextureID,
			RenderFidelity = old.RenderFidelity, CollisionFidelity = old.CollisionFidelity,
		}
		local node = old.Parent
		old:Destroy()
		if node and node:IsA("Model") and node ~= stages and #node:GetChildren() == 0 then
			node:Destroy()
		end
	end
end

local placed = 0
for name, part in pairs(found) do
	local info = PIECES[name]
	local look = looks[info[1]] or {}
	part.Size = info[3] * s
	part.CFrame = CFrame.new(info[2] * s + offset) * unturn * part.CFrame.Rotation
	for prop, value in pairs(look) do
		if prop == "TextureID" and value == "" then
			continue
		end
		pcall(function()
			part[prop] = value
		end)
	end
	part.Anchored = true
	local node = Instance.new("Model")
	node.Name = name .. "_Node"
	part.Parent = node
	node.Parent = stages or map
	placed += 1
end
patch:Destroy()
print(TAG, ("put %d map pieces in place (scale %.4f, turned %d degrees): the holes are filled"):format(placed, s, math.deg(-yaw)))
