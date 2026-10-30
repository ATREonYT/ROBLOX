-- Dumps every part of one lobby (seen from above) to JSON for tools/world/lobby_plan.py, which draws the top-down
-- plan with the leaderboards, avatar stands and his props labelled (docs/previews/new-lobby-layout.jpg).
-- Run from the repo root:
--   lune run huzz-valley/tools/world/lobby_dump.luau <place.rbxl> <out.json> [centreX centreZ radius]
-- Without a centre it uses the first lobby floor Shared/LobbyLayout finds.
local fs = require("@lune/fs")
local process = require("@lune/process")
local roblox = require("@lune/roblox")
local serde = require("@lune/serde")

local Layout = require("../../src/ReplicatedStorage/Shared/LobbyLayout")

local placeFile, outFile = process.args[1], process.args[2]
local game = roblox.deserializePlace(fs.readFile(placeFile))
local ws = game:GetService("Workspace")

local cx, cz, radius = tonumber(process.args[3]), tonumber(process.args[4]), tonumber(process.args[5]) or 125
local floors = Layout.floors(ws)
local floor = floors[1]
if not cx and floor then
	cx, cz = floor.CFrame.Position.X, floor.CFrame.Position.Z
end
assert(cx and cz, "no lobby floor found: pass a centre")

local function kindOf(d)
	local p = d
	while p and p ~= ws do
		if p.Name == "HuzzLeaderboards" then return "board" end
		if p.Name == "HuzzAvatarStands" then return "stand" end
		if p.Name == "HuzzLobbyProps" then return "prop" end
		if p.Name == "HauntedHouse" then return "house" end
		if p.Name == "SpinWheel" then return "wheel" end
		if p.Name == "Podium" then return "podium" end
		if p.Name == "Billboard" then return "billboard" end
		if p.Name == "fence" then return "fence" end
		if p.Name == "Konata" or p.Name == "Alya" or p.Name == "Yuno" or p.Name == "Mai" then return "girl" end
		p = p.Parent
	end
	return "part"
end

local parts = {}
for _, d in ws:GetDescendants() do
	if d:IsA("BasePart") and d.ClassName ~= "Terrain" then
		local cf, s = d.CFrame, d.Size
		local p = cf.Position
		if math.abs(p.X - cx) < radius + 40 and math.abs(p.Z - cz) < radius + 40 then
			local corners = {}
			for _, c in { { -1, -1 }, { 1, -1 }, { 1, 1 }, { -1, 1 } } do
				-- the footprint: the box's extent along each of its axes, flattened onto the ground
				local w = cf.RightVector * (c[1] * s.X / 2) + cf.LookVector * (c[2] * s.Z / 2)
				if math.abs(cf.UpVector.Y) < 0.5 then -- (lying on its side: its Y size is flat on the ground)
					w = cf.UpVector * (c[1] * s.Y / 2) + (if math.abs(cf.RightVector.Y) < 0.5 then cf.RightVector * (c[2] * s.X / 2) else cf.LookVector * (c[2] * s.Z / 2))
				end
				table.insert(corners, { p.X + w.X, p.Z + w.Z })
			end
			local top = p.Y + math.abs(cf.UpVector.Y) * s.Y / 2 + math.abs(cf.RightVector.Y) * s.X / 2 + math.abs(cf.LookVector.Y) * s.Z / 2
			local col = d.Color
			table.insert(parts, {
				c = corners, top = top, rgb = { math.floor(col.R * 255), math.floor(col.G * 255), math.floor(col.B * 255) },
				t = d.Transparency, kind = kindOf(d), name = d.Name,
			})
		end
	end
end

-- labels: boards (Stat), stands (Pass, Knife) and his props on the pads (Title)
local labels = {}
for _, d in ws:GetDescendants() do
	local p
	if d:IsA("BasePart") then p = d.CFrame.Position end
	if d:IsA("Model") then
		local part = d.PrimaryPart or d:FindFirstChildWhichIsA("BasePart", true)
		p = part and part.CFrame.Position
	end
	if p and math.abs(p.X - cx) < radius + 40 and math.abs(p.Z - cz) < radius + 40 then
		if d:GetAttribute("Stat") and d.Parent and d.Parent.Name == "HuzzLeaderboards" then
			local look = (d.PrimaryPart or d:FindFirstChildWhichIsA("BasePart", true)).CFrame.LookVector
			table.insert(labels, { kind = "board", x = p.X, z = p.Z, text = tostring(d:GetAttribute("Stat")), lx = look.X, lz = look.Z })
		elseif d:GetAttribute("Knife") and d.Parent and d.Parent.Name == "HuzzAvatarStands" then
			local look = d.CFrame.LookVector
			table.insert(labels, { kind = "stand", x = p.X, z = p.Z, text = tostring(d:GetAttribute("Knife")), pass = tostring(d:GetAttribute("Pass")), lx = look.X, lz = look.Z })
		elseif d.Name == "LobbyProp" and d:GetAttribute("Prop") then
			local pad = d:FindFirstChild("Pad")
			local q = pad and pad.CFrame.Position or p
			local c = d:GetAttribute("Color")
			table.insert(labels, { kind = "prop", x = q.X, z = q.Z, text = tostring(d:GetAttribute("Title")), prop = tostring(d:GetAttribute("Prop")),
				rgb = c and { math.floor(c.R * 255), math.floor(c.G * 255), math.floor(c.B * 255) } or { 255, 255, 255 } })
		elseif d:IsA("SpawnLocation") then
			table.insert(labels, { kind = "spawn", x = p.X, z = p.Z, text = "spawn" })
		end
	end
end

fs.writeFile(outFile, serde.encode("json", { cx = cx, cz = cz, radius = radius, parts = parts, labels = labels }))
print(string.format("lobby dump: %d parts, %d labels round (%.0f, %.0f) -> %s", #parts, #labels, cx, cz, outFile))
