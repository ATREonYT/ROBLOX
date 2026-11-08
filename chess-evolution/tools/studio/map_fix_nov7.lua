--[[
	+1 Chess Evolution: in-place fix of the live Workspace.Map (Alex, Nov 7, 18:24).
	Run in Edit mode (Command Bar or Studio MCP). It only moves and reshapes parts; every
	gameplay part (Spawn, Stations/<id>/Deck, Stages/<id>/Zone, PlayerSpot, Tiles,
	PlayerPieceSpot, RivalSpot, Gate/Barrier, PadGlow) keeps its name and folder.
	A checkpoint copy is made first in ServerStorage. Output lines start with [MapFix].
	Measurements come from the long reference recording (frames 0:08-0:12, hub overview,
	stage approach); see design/compare/ for the side-by-side pictures.
]]
local ss = game:GetService("ServerStorage")
local map = workspace:FindFirstChild("Map")
assert(map, "[MapFix] Workspace.Map not found")
if not ss:FindFirstChild("Checkpoint_preMapFixNov7") then
	local cp = Instance.new("Folder")
	cp.Name = "Checkpoint_preMapFixNov7"
	map:Clone().Parent = cp
	cp.Parent = ss
end

local GREY = Color3.fromRGB(168, 178, 182)
local DARK = Color3.fromRGB(34, 38, 50)
local STUDS = "rbxassetid://18878365966"
local log = {}
local function say(s)
	table.insert(log, s)
end

local function studs(p: BasePart)
	for _, face in { Enum.NormalId.Top, Enum.NormalId.Front, Enum.NormalId.Back, Enum.NormalId.Left, Enum.NormalId.Right } do
		local t = Instance.new("Texture")
		t.Name = "Studs"
		t.Texture = STUDS
		t.Face = face
		t.StudsPerTileU = 2
		t.StudsPerTileV = 2
		t.Parent = p
	end
end
local function block(parent, name, size, cf, color, material)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Anchored = true
	p.Material = material or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end
local function wedge(parent, name, size, cf, color)
	local w = Instance.new("WedgePart")
	w.Name = name
	w.Size = size
	w.CFrame = cf
	w.Color = color
	w.Anchored = true
	w.Material = Enum.Material.SmoothPlastic
	w.Parent = parent
	studs(w)
	return w
end

-- 1. Heights: taller lane banks than hub walls (stage approach: wall ~17 studs over the lane
--    floor; hub wall behind the terrace ~11 over the rear tier). Things standing on a raised
--    cliff (trees, fences) ride up with it.
local function riders(cliff: BasePart, topY: number): { Instance }
	local list = {}
	local half = cliff.Size / 2
	local seen = {}
	for _, d in map:GetDescendants() do
		if d:IsA("BasePart") and d ~= cliff and not d:IsDescendantOf(map.Stages) and not d:IsDescendantOf(map.Stations) then
			local bottom = d.Position.Y - d.Size.Y / 2
			local rel = d.Position - cliff.Position
			if math.abs(rel.X) <= half.X + 0.5 and math.abs(rel.Z) <= half.Z + 0.5 and bottom >= topY - 1.6 and bottom <= topY + 6 then
				local root = d
				while root.Parent and root.Parent ~= map and not root.Parent:IsA("Folder") do
					root = root.Parent
				end
				if not seen[root] then
					seen[root] = true
					table.insert(list, root)
				end
			end
		end
	end
	return list
end
local function raiseCliff(cliff: BasePart, newTop: number)
	local top = cliff.Position.Y + cliff.Size.Y / 2
	local delta = newTop - top
	if math.abs(delta) < 0.05 then
		return
	end
	local ride = riders(cliff, top)
	local bottom = top - cliff.Size.Y
	cliff.Size = Vector3.new(cliff.Size.X, newTop - bottom, cliff.Size.Z)
	cliff.CFrame = cliff.CFrame + Vector3.new(0, delta / 2, 0)
	for _, r in ride do
		if r:IsA("Model") then
			r:PivotTo(r:GetPivot() + Vector3.new(0, delta, 0))
		elseif r:IsA("BasePart") then
			r.CFrame = r.CFrame + Vector3.new(0, delta, 0)
		end
	end
	say(string.format("cliff at (%d,%d) top %.1f -> %.1f, %d riders", cliff.Position.X, cliff.Position.Z, top, newTop, #ride))
end
for _, c in map:GetDescendants() do
	if c:IsA("BasePart") and c.Name == "Cliff" then
		local p, s = c.Position, c.Size
		local laneBank = s.Z > 400 -- the long banks along the stage lane
		local mouth = math.abs(p.Z + 52) < 2 -- the two wall caps at the lane mouth
		local outer = s.Y > 20
		if laneBank or mouth then
			raiseCliff(c, if outer then 32 else 18)
		elseif outer then
			raiseCliff(c, 28)
		else
			raiseCliff(c, 15)
		end
	end
end

-- 2. Stage gates and mats (reference 0:10 and the Stage 1 approach)
local GATE_H = 19 -- top of the frame over the lane floor (frame height/width ~0.54)
for _, stage in map.Stages:GetChildren() do
	local gate = stage:FindFirstChild("Gate")
	local pad = stage:FindFirstChild("Pad")
	if gate and gate:FindFirstChild("Beam") then
		local beam = gate.Beam
		local floorY = 1
		local z = beam.Position.Z
		for _, leg in { gate:FindFirstChild("LegL"), gate:FindFirstChild("LegR") } do
			if leg then
				leg.Size = Vector3.new(3, GATE_H - floorY - 3, 3)
				leg.CFrame = CFrame.new(leg.Position.X, floorY + leg.Size.Y / 2, z)
			end
		end
		beam.Size = Vector3.new(36, 3, 3)
		beam.CFrame = CFrame.new(0, GATE_H - 1.5, z)
		-- thick inner trim in a second colour, like the reference frames
		local trim = if stage.Name == "Stage1" then Color3.fromRGB(96, 214, 52) else beam.Color:Lerp(Color3.new(1, 1, 1), 0.45)
		for _, inner in gate:GetChildren() do
			if inner.Name == "Inner" and inner:IsA("BasePart") then
				inner.Color = trim
				inner.Material = Enum.Material.SmoothPlastic
				if inner.Size.X > 10 then -- top bar
					inner.Size = Vector3.new(30, 1.4, 3.2)
					inner.CFrame = CFrame.new(0, GATE_H - 3 - 0.7, z)
				else
					inner.Size = Vector3.new(1.4, GATE_H - floorY - 3, 3.2)
					inner.CFrame = CFrame.new((if inner.Position.X < 0 then -1 else 1) * 14.3, floorY + inner.Size.Y / 2, z)
				end
			end
		end
		local barrier = gate:FindFirstChild("Barrier")
		if barrier then
			barrier.Size = Vector3.new(27.2, GATE_H - floorY - 4.4, 0.3)
			barrier.CFrame = CFrame.new(0, floorY + barrier.Size.Y / 2, z)
			-- big centred stage text (about 40% of the opening's width)
			for _, sg in barrier:GetChildren() do
				if sg:IsA("SurfaceGui") then
					sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
					sg.PixelsPerStud = 24
					sg.LightInfluence = 0
					local t = sg:FindFirstChildOfClass("TextLabel")
					if t then
						t.Size = UDim2.fromScale(0.62, 0.3)
						t.Position = UDim2.fromScale(0.19, 0.16)
						t.TextScaled = true
						t.FontFace = Font.fromEnum(Enum.Font.FredokaOne)
						t.TextColor3 = Color3.new(1, 1, 1)
						local st = t:FindFirstChildOfClass("UIStroke")
						if st then
							st.Thickness = 5
							st.Color = Color3.fromRGB(28, 26, 40)
						end
					end
				end
			end
		end
		local tag = gate:FindFirstChild("TagAnchor")
		local bb = tag and tag:FindFirstChildOfClass("BillboardGui")
		if bb then
			bb.Enabled = false -- the reference shows the name on the frame, not above it
		end
	end
	-- no checker graphics on the mats (the tiles stay as invisible markers for the code)
	local tiles = stage:FindFirstChild("Tiles")
	if tiles then
		for _, t in tiles:GetChildren() do
			if t:IsA("BasePart") then
				t.Transparency = 1
				t.CanCollide = false
			end
		end
	end
	local rivalPiece = stage:FindFirstChild("Rival")
	if rivalPiece then
		for _, p in rivalPiece:GetDescendants() do
			if p:IsA("BasePart") then
				p.Transparency = 1
				p.CanCollide = false
			end
		end
	end
	stage:SetAttribute("NoBoard", true)
	-- two dark standing plates on the right half of the red mat, facing each other along the lane
	if pad then
		local plates = {}
		for _, c in stage:GetChildren() do
			if c.Name == "StandPlate" or c.Name == "RivalPlate" then
				table.insert(plates, c)
			end
		end
		table.sort(plates, function(a, b)
			return a.Position.Z > b.Position.Z
		end)
		local px = pad.Position.X + pad.Size.X * 0.22
		local top = pad.Position.Y + pad.Size.Y / 2
		local zs = { pad.Position.Z + pad.Size.Z * 0.28, pad.Position.Z - pad.Size.Z * 0.28 }
		for i, plate in plates do
			if i <= 2 then
				plate.Name = if i == 1 then "StandPlate" else "RivalPlate"
				plate.Color = DARK
				plate.Size = Vector3.new(4.4, 0.4, 4.4)
				plate.CFrame = CFrame.new(px, top + 0.2, zs[i])
			end
		end
		local spot = stage:FindFirstChild("PlayerSpot")
		if spot and plates[1] then
			spot.CFrame = CFrame.lookAt(plates[1].Position + Vector3.new(0, 0.7, 0), plates[2] and (plates[2].Position + Vector3.new(0, 0.7, 0)) or (plates[1].Position + Vector3.new(0, 0.7, -1)))
		end
	end
end
say("stages: gates " .. GATE_H .. " tall, checker hidden, plates on the mat")

-- 3. Terrace: ramps from the front floor up to the rear tier between front machines 1-2 and 3-4
local terrace = map:FindFirstChild("Terrace")
if terrace and terrace:FindFirstChild("RearTier") and not terrace:FindFirstChild("BayRamp") then
	local tier = terrace.RearTier
	local tierTop = tier.Position.Y + tier.Size.Y / 2
	local floorTop = terrace.Floor.Position.Y + terrace.Floor.Size.Y / 2
	local rise = tierTop - floorTop
	local edgeX = tier.Position.X + tier.Size.X / 2
	local len = 7
	for _, z in { -18, 18 } do
		-- high end against the tier (-X), low end toward the path (+X)
		wedge(terrace, "BayRamp", Vector3.new(8, rise, len), CFrame.new(edgeX + len / 2, floorTop + rise / 2, z) * CFrame.Angles(0, math.rad(-90), 0), GREY)
	end
	say("terrace: 2 bay ramps added")
end

-- 4. Portal: a tall arch beside the path, off the route to Stage 1, facing the junction
local portal = map:FindFirstChild("Portal")
if portal and not portal:FindFirstChild("ArchV2") then
	local sign = portal:FindFirstChild("SignAnchor")
	for _, c in portal:GetChildren() do
		if c ~= sign then
			c:Destroy()
		end
	end
	local base = CFrame.lookAt(Vector3.new(-14, 0, -17), Vector3.new(-6, 0, 2))
	local blue = Color3.fromRGB(40, 60, 230)
	local m = Instance.new("Model")
	m.Name = "ArchV2"
	local function at(x, y, z)
		return base * CFrame.new(x, y, z)
	end
	-- two posts, rounded top from blocks, pink neon fill
	for _, x in { -3.4, 3.4 } do
		studs(block(m, "Post", Vector3.new(2, 8, 3), at(x, 4, 0), blue))
	end
	for i = 0, 6 do
		local a = math.rad(180 - i * 30)
		studs(block(m, "Arch", Vector3.new(2.2, 2.2, 3), at(math.cos(a) * 3.4, 8 + math.sin(a) * 3.4, 0) * CFrame.Angles(0, 0, a), blue))
	end
	block(m, "Fill", Vector3.new(4.8, 7.8, 0.4), at(0, 3.9, 0), Color3.fromRGB(255, 60, 220), Enum.Material.Neon)
	local fillTop = Instance.new("Part")
	fillTop.Name = "FillTop"
	fillTop.Shape = Enum.PartType.Cylinder
	fillTop.Size = Vector3.new(0.4, 4.8, 4.8)
	fillTop.CFrame = at(0, 8, 0) * CFrame.Angles(0, math.rad(90), 0)
	fillTop.Color = Color3.fromRGB(255, 60, 220)
	fillTop.Material = Enum.Material.Neon
	fillTop.Anchored = true
	fillTop.Parent = m
	studs(block(m, "Base", Vector3.new(9, 1, 4), at(0, 0.5, 0), blue))
	m.Parent = portal
	if sign then
		sign.CFrame = at(0, 13.6, 0)
	end
	say("portal: rebuilt 9 x 12 arch at (-14, -17), facing the junction")
end

-- 5. No light spill on the mats: the ready glow rim stays, the big neon underlay goes thin
for _, stage in map.Stages:GetChildren() do
	local glow = stage:FindFirstChild("PadGlow")
	local pad = stage:FindFirstChild("Pad")
	if glow and pad then
		glow.Size = Vector3.new(pad.Size.X + 0.8, 0.2, pad.Size.Z + 0.8)
	end
end

print("[MapFix] " .. table.concat(log, "\n[MapFix] "))
return table.concat(log, "\n")
