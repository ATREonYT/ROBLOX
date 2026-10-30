--[[
	BuildCartoonyMap  (run in Studio's Command Bar, Edit mode)

	Stone Skipping look (Alex, Oct 30): classic round studs on every blocky
	surface of the map, the training booths and the cannons. Trees, leaves,
	water and see-through parts are left alone.

	Every texture it adds is named "CartoonStuds". A run first removes only
	those, so it is safe to run again. Nothing else on a part is touched
	(an earlier version deleted the map's own "Studs" textures, Oct 30).
	Undo: run it with UNDO = true.

	SCOPE: "lobby" studs only the lobby, booths and cannons (the golden slice);
	"all" does the whole map.
]]

local UNDO = false
local SCOPE = "lobby"

-- "Classic stud texture", already in this game's inventory (found with Studio's asset search)
local STUDS = "rbxassetid://18878365966"
local NAME = "CartoonStuds"
local TILE = 2 -- studs per stud
local SIDES = { Enum.NormalId.Top, Enum.NormalId.Front, Enum.NormalId.Back, Enum.NormalId.Left, Enum.NormalId.Right }

local map = workspace.map1b.StoneSkipMap
local roots = {}
if SCOPE == "all" then
	table.insert(roots, map)
else
	table.insert(roots, map.Lobby)
end
for _, n in ipairs({ "TrainingStations", "EggStands", "AreaBorders", "LaunchZone" }) do
	if workspace:FindFirstChild(n) then
		table.insert(roots, workspace[n])
	end
end
local cannonRoots = { game.ReplicatedStorage:FindFirstChild("Cannons") }

local function skip(p)
	local n = p:GetFullName():lower()
	return n:find("ocean") or n:find("water") or n:find("river") or n:find("tree") or n:find("leaf")
		or n:find("leaves") or n:find("bush") or n:find("flower") or n:find("grass_tuft")
end

local function clear(p)
	for _, t in ipairs(p:GetChildren()) do
		if t:IsA("Texture") and t.Name == NAME then
			t:Destroy()
		end
	end
end

local function stud(p, transparency)
	local s = p.Size
	for _, face in ipairs(SIDES) do
		-- the face's two lengths
		local a, b
		if face == Enum.NormalId.Top then
			a, b = s.X, s.Z
		elseif face == Enum.NormalId.Front or face == Enum.NormalId.Back then
			a, b = s.X, s.Y
		else
			a, b = s.Z, s.Y
		end
		if a >= 1.5 and b >= 1.5 then
			local t = Instance.new("Texture")
			t.Name = NAME
			t.Texture = STUDS
			t.Face = face
			t.StudsPerTileU = TILE
			t.StudsPerTileV = TILE
			t.Transparency = transparency
			t.Parent = p
		end
	end
end

local added = 0
local function run(root, transparency)
	for i, p in ipairs(root:GetDescendants()) do
		if p:IsA("BasePart") then
			clear(p)
			if not UNDO and p.Transparency < 0.5 and not skip(p) then
				-- cannons placed in the booths get the softer cannon studs too
				stud(p, p:FindFirstAncestor("Cannon") and 0.45 or transparency)
				added += 1
			end
		end
		if i % 1000 == 0 then
			task.wait()
		end
	end
end

for _, r in ipairs(roots) do
	run(r, 0)
end
for _, r in ipairs(cannonRoots) do
	run(r, 0.45) -- softer on the cannons so their own colours and details stay
end
print("[BuildCartoonyMap] " .. (UNDO and "removed studs" or ("studded " .. added .. " parts")) .. " (" .. SCOPE .. ")")
