--[[
	BuildCartoonyMap  (run in Studio's Command Bar, Edit mode)

	Gives the map the studded "new Roblox game" look Alex asked for (Oct 30):
	every flat surface you can stand on (grass, sand, paths, plaza, docks,
	islands) gets the same square stud texture the UI uses, tinted to its own
	colour so it reads as soft studs, not a grid. Walls, trees, rocks and
	water are left alone. See .claude/skills/roblox-cartoony-building.

	Safe to run again: it removes its own "Studs" textures first.
	Undo: run it with UNDO = true.
]]

local UNDO = false

local Icons = require(game.ReplicatedStorage.Icons)
local STUDS = Icons.StudTile
local root = workspace.map1b.StoneSkipMap

local function skip(p)
	local n = p:GetFullName():lower()
	return n:find("ocean") or n:find("water") or n:find("river") or n:find("tree") or n:find("leaf")
		or n:find("rock") or n:find("cliff") or n:find("wall") or n:find("tower") or n:find("roof")
		or n:find("ship") or n:find("barrel") or n:find("crate") or n:find("cannon")
end

local added, removed = 0, 0
for _, p in ipairs(root:GetDescendants()) do
	if p:IsA("BasePart") then
		for _, t in ipairs(p:GetChildren()) do
			if t:IsA("Texture") and t.Name == "Studs" then
				t:Destroy()
				removed += 1
			end
		end
		local s = p.Size
		-- flat and big enough to walk on
		local flat = s.Y < math.min(s.X, s.Z) * 0.35 and s.X * s.Z >= 64
		if not UNDO and flat and not skip(p) and p.Transparency < 0.5 then
			local t = Instance.new("Texture")
			t.Name = "Studs"
			t.Texture = STUDS
			t.Face = Enum.NormalId.Top
			t.StudsPerTileU = 4
			t.StudsPerTileV = 4
			t.Transparency = 0.8
			t.Parent = p
			added += 1
		end
	end
end
print("[BuildCartoonyMap] studs added to " .. added .. " surfaces, removed " .. removed)
