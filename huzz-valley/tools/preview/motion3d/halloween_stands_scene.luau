-- One still of the Halloween stands (WITCH'S BREW, SWEETS & TREATS and FREE SPIN beside them) in a built place, from
-- about the angle of the owner's design/owner-oct19/1840-halloween-crates.png (from the plaza, a little above, looking
-- out over the pads to the water). For the Oct 20 "make the halloween shop objects bigger so they stand out more"
-- before / after: render the place before and after the change, then put the two stills side by side.
-- His parts near the pads as plain boxes (no textures), the stand-ins in their colours (Neon parts unlit), and each
-- prop's title as camera-facing text the size the BillboardGui gives it.
-- PLACE=<a .rbxl> MOTION3D_KEEP=<dir> sh video.sh halloween_stands_scene.luau <out.mp4>   (still: <dir>/still_0.png)
local fs = require("@lune/fs")
local process = require("@lune/process")
local roblox = require("@lune/roblox")
local CFrame, Vector3 = roblox.CFrame, roblox.Vector3
local Scene = require("./scene")
local Env = require("./env")
local Layout = Env.load("huzz-valley/src/ReplicatedStorage/Shared/LobbyLayout.lua")

local placeFile = process.env.PLACE or (Env.root .. "/huzz-valley/places/HuzzValley-yours.rbxl")
local game = roblox.deserializePlace(fs.readFile(placeFile))
local ws = game:GetService("Workspace")
local floor = Layout.main(ws)
local fc = floor.CFrame

local function hex(c)
	return string.format("#%02x%02x%02x", math.floor(c.R * 255 + 0.5), math.floor(c.G * 255 + 0.5), math.floor(c.B * 255 + 0.5))
end

-- the three-pad side: the middle of its props, in the floor's frame
local props = {}
local folder = ws:FindFirstChild("HuzzLobbyProps")
assert(folder, "no Workspace > HuzzLobbyProps in " .. placeFile)
for _, lp in folder:GetChildren() do
	local key = lp:GetAttribute("Prop")
	if key == "Witch_Brew_Cauldron" or key == "Sweets_Treats_Coffin" or key == "Pumpkin_Patch_Chest" then
		table.insert(props, lp)
	end
end
assert(#props == 3, "the three Halloween-side props")
local mid = Vector3.new(0, 0, 0)
for _, lp in props do mid += lp.Pad.CFrame.Position / 3 end
-- the camera's anchor: FREE SPIN's pad (it never moves), so before and after are framed the same
local local0
for _, lp in props do
	if lp:GetAttribute("Prop") == "Pumpkin_Patch_Chest" then local0 = fc:PointToObjectSpace(lp.Pad.CFrame.Position) + Vector3.new(0, 0, 7) end
end

local scene = Scene.new()
local n = 0
for _, d in ws:GetDescendants() do
	if d:IsA("BasePart") and d.ClassName ~= "Terrain" and d ~= floor and d.Transparency < 0.9 then
		local p = d.CFrame.Position
		if (p - mid).Magnitude <= d.Size.Magnitude / 2 + 46 then
			local shape
			local ok, s = pcall(function() return d.Shape end)
			if ok and tostring(s) == "Enum.PartType.Cylinder" then shape = "cyl" elseif ok and tostring(s) == "Enum.PartType.Ball" then shape = "ball" end
			if not shape and d:FindFirstChildOfClass("SpecialMesh") then shape = "ball" end
			local box = scene:addBox(d.CFrame, d.Size, hex(d.Color))
			box.Shape = shape
			box.Neon = tostring(d.Material) == "Enum.Material.Neon" or nil
			box.Alpha = d.Transparency > 0.05 and (1 - d.Transparency) or nil
			n += 1
		end
	end
end
scene:addBox(fc, floor.Size, "#c88a3c") -- (his orange studded plaza, as one plain colour)
print(n .. " parts near the Halloween stands")

-- the titles: each line of the BillboardGui's Title (and the small line under it) where Roblox draws it
local labels = {}
for _, lp in props do
	local pad = lp.Pad
	local bb = pad:FindFirstChild("PropTitle")
	if bb then
		local at = pad.CFrame.Position + bb.StudsOffsetWorldSpace
		local bbH = bb.Size.Y.Scale
		local title, line = bb:FindFirstChild("Title"), bb:FindFirstChild("Line")
		local lines = string.split(title.Text, "\n")
		local titleH = title.Size.Y.Scale * bbH
		local top = at.Y + bbH / 2
		for i, txt in lines do
			local h = titleH / #lines
			table.insert(labels, { p = { at.X, top - h * (i - 0.5), at.Z }, text = txt, h = h * 0.82, c = hex(title.TextColor3), o = "#160e22" })
		end
		if line and line.Text ~= "" then
			local h = line.Size.Y.Scale * bbH
			table.insert(labels, { p = { at.X, top - titleH - h / 2, at.Z }, text = line.Text, h = h * 0.8, c = "#ffffff", o = "#160e22" })
		elseif lp:GetAttribute("Line") == "FreeSpin" then
			local h = line.Size.Y.Scale * bbH
			table.insert(labels, { p = { at.X, top - titleH - h / 2, at.Z }, text = "FREE SPIN READY!", h = h * 0.8, c = "#ffffff", o = "#160e22" })
		end
	end
end

-- the camera: in the plaza, in front of the middle of the row and a little towards WITCH'S BREW, eyes about a
-- player's camera height over the floor, looking out over the pads (the reference's angle)
local top = Layout.facts(floor).top
local eye = fc:PointToWorldSpace(Vector3.new(local0.X - 26, 0, local0.Z + 4))
local look = fc:PointToWorldSpace(Vector3.new(local0.X + 2, 0, local0.Z + 4))
eye = Vector3.new(eye.X, top + 12, eye.Z)
look = Vector3.new(look.X, top + 4.5, look.Z)
scene:frame(eye, look, { labels = labels, fov = 70 })
scene:save(nil, 30, 1280, 720, { sky = "#5a8fe0", ground = "#3f74d8", grid = false, stills = { 0 } })
