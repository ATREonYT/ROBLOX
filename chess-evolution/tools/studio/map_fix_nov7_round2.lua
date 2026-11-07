-- +1 Chess Evolution: map fix, round 2 (Nov 7). Run in the Command Bar after map_fix_nov7.lua.
-- Records the edits made live in Studio while matching the long screen recording.
-- Safe to run twice: each move is guarded by an attribute on Workspace.Map.
local Map = workspace:WaitForChild("Map")
local Lighting = game:GetService("Lighting")
local function log(s) print("[MapFix2] " .. s) end

local function shift(inst, o)
	if inst:IsA("BasePart") then inst.CFrame = inst.CFrame + o end
	for _, d in ipairs(inst:GetDescendants()) do
		if d:IsA("BasePart") then d.CFrame = d.CFrame + o end
	end
	for _, d in ipairs(inst:GetDescendants()) do
		if d:IsA("Model") then pcall(function() d.WorldPivot = d.WorldPivot + o end) end
	end
end

-- 1. Lighting, tuned with the vault's note 10 numbers
Lighting.ClockTime = 14
Lighting.OutdoorAmbient = Color3.fromRGB(150, 140, 190)
Lighting.Ambient = Color3.fromRGB(110, 105, 140)
local cc = Lighting:FindFirstChildOfClass("ColorCorrectionEffect")
if cc then cc.Saturation = 0.15; cc.Contrast = 0.05 end
local bloom = Lighting:FindFirstChildOfClass("BloomEffect")
if bloom then bloom.Threshold = 0.95; bloom.Intensity = 0.4; bloom.Size = 18 end
local atm = Lighting:FindFirstChildOfClass("Atmosphere")
if atm then atm.Density = 0.32; atm.Haze = 0.6 end
log("lighting set")

-- 2. Stage text centred on every gate
for _, st in ipairs(Map.Stages:GetChildren()) do
	local b = st:FindFirstChild("Barrier", true)
	local sg = b and b:FindFirstChildOfClass("SurfaceGui")
	local lbl = sg and sg:FindFirstChildWhichIsA("TextLabel")
	if lbl then lbl.AnchorPoint = Vector2.new(0.5, 0); lbl.Position = UDim2.fromScale(0.5, 0.14); lbl.Size = UDim2.fromScale(0.6, 0.3) end
end

-- 3. Lane: darker stone floor and a kerb on both sides (reference colour, measured)
local Lane = Map.Lane
for _, p in ipairs(Lane:GetChildren()) do
	if p.Name == "Floor" then p.Color = Color3.fromRGB(135, 143, 152) end
end
if not Lane:FindFirstChild("Kerb") then
	local f = Lane.Floor
	for _, sx in ipairs({ -1, 1 }) do
		local k = Instance.new("Part")
		k.Name = "Kerb"; k.Anchored = true; k.CastShadow = false
		k.Size = Vector3.new(2.2, 1.4, f.Size.Z)
		k.Position = Vector3.new(sx * (f.Size.X / 2 - 1.1), f.Position.Y + f.Size.Y / 2 + 0.7, f.Position.Z)
		k.TopSurface = Enum.SurfaceType.Studs
		k.Parent = Lane
	end
end
for _, p in ipairs(Lane:GetChildren()) do
	if p.Name == "Kerb" then p.Color = Color3.fromRGB(108, 116, 124) end
end

-- 4. Terrace: reference stone grey, back row on a short step (rise 3.5 over the floor)
local T = Map.Terrace
local grey = Color3.fromRGB(132, 140, 146)
for _, p in ipairs(T:GetDescendants()) do
	if p:IsA("BasePart") and (p.Name == "Floor" or p.Name == "RearTier" or p.Name == "Ramp" or p.Name == "BayRamp") then p.Color = grey end
end
local tier = T:FindFirstChild("RearTier")
if tier then
	local dy = 4.5 - (tier.Position.Y + tier.Size.Y / 2)
	if math.abs(dy) > 0.05 then
		for _, p in ipairs(T:GetDescendants()) do
			if p:IsA("BasePart") and (p.Name == "RearTier" or p.Name == "Ramp" or p.Name == "BayRamp" or p.Name == "RearTrim") then
				p.Size = p.Size + Vector3.new(0, dy, 0); p.CFrame = p.CFrame + Vector3.new(0, dy / 2, 0)
			end
		end
		for _, s in ipairs(Map.Stations:GetChildren()) do
			local d = s:FindFirstChild("Deck", true)
			if d and d.Position.X < -45 then shift(s, Vector3.new(0, dy, 0)) end
		end
		log(("rear tier moved %.1f"):format(dy))
	end
end

-- 5. Gallery: starts at the crossroads and runs toward the spawn (reference hub shot)
if not Map:GetAttribute("GalleryMovedNov7") then
	local off = Vector3.new(-5, 0, 14)
	shift(Map.Gallery, off); shift(Map.SetDisplays, off)
	local G = Map.Ground
	local pc = G.PathCross
	local xmin = pc.Position.X - pc.Size.X / 2
	pc.Size = Vector3.new(19 - xmin, pc.Size.Y, pc.Size.Z)
	pc.Position = Vector3.new((19 + xmin) / 2, pc.Position.Y, pc.Position.Z)
	for _, e in ipairs(G:GetChildren()) do
		if e.Name == "PathEdge" and e.Position.X > 10 and math.abs(e.Position.Z) < 8 then
			e.Size = Vector3.new(12.5, e.Size.Y, e.Size.Z); e.Position = Vector3.new(12.75, e.Position.Y, e.Position.Z)
		end
	end
	Map:SetAttribute("GalleryMovedNov7", true)
	log("gallery moved")
end

-- 6. Grass a touch lighter, three more trees inside the hub
Map.Ground.Grass.Color = Color3.fromRGB(108, 228, 60)
local Trees = Map.Scenery.Trees
if not Trees:FindFirstChild("HubTree1") then
	local src
	for _, t in ipairs(Trees:GetChildren()) do
		if t:IsA("Model") and t.Name == "Tree" then
			local cf = t:GetBoundingBox()
			if math.abs(cf.Position.X + 34) < 3 and math.abs(cf.Position.Z + 41) < 3 then src = t break end
		end
	end
	if src then
		local y = src:GetPivot().Position.Y
		for i, s in ipairs({ Vector3.new(-18, 0, 34), Vector3.new(38, 0, -34), Vector3.new(-16, 0, -30) }) do
			local c = src:Clone(); c.Name = "HubTree" .. i
			c:PivotTo(CFrame.new(s.X, y, s.Z) * CFrame.Angles(0, math.rad(90 * i), 0)); c.Parent = Trees
		end
		log("hub trees added")
	end
end
log("done")
