local SS = game:GetService("ServerStorage")
local Map = workspace:WaitForChild("Map")
local STUDS = "rbxassetid://18878365966"
local log = {}
local function say(s) table.insert(log, s) print("[HubMap] " .. s) end

-- 1. backup once (the whole Map, before anything moves)
if not SS:FindFirstChild("MapBackup_Nov8_Layout") then
	local b = Map:Clone(); b.Name = "MapBackup_Nov8_Layout"; b.Parent = SS
	say("backup saved to ServerStorage.MapBackup_Nov8_Layout")
end

-- 2. take out the old hub shell (kept in the backup)
for _, n in ipairs({"Ground", "Terrace"}) do local f = Map:FindFirstChild(n) if f then f:Destroy() end end
local gal = Map:FindFirstChild("Gallery")
if gal then for _, c in ipairs(gal:GetChildren()) do if c.Name ~= "ShopZone" then c:Destroy() end end end
local sc = Map:FindFirstChild("Scenery")
if sc then
	local r = sc:FindFirstChild("River") if r then r:Destroy() end
	local banks = sc:FindFirstChild("Banks")
	if banks then for _, c in ipairs(banks:GetChildren()) do
		if c:IsA("BasePart") and c.Position.Z > -100 then c:Destroy() end -- hub banks only; lane banks stay
	end end
end
local old = Map:FindFirstChild("Hub") if old then old:Destroy() end

-- 3. build the new hub from the layout
local hub = Instance.new("Folder"); hub.Name = "Hub"
local folders = {}
local function hex(h) return Color3.fromHex(h) end
for _, d in ipairs(P) do
	local f = folders[d.g]
	if not f then f = Instance.new("Folder"); f.Name = d.g; f.Parent = hub; folders[d.g] = f end
	local p = Instance.new(d.low and "WedgePart" or "Part")
	p.Name = d.n; p.Anchored = true
	local pos = Vector3.new(d.p[1], d.p[2], d.p[3])
	if d.low then
		-- a WedgePart is high at local +Z and low at local -Z, so look toward the low side
		local dir = ({["+x"] = Vector3.xAxis, ["-x"] = -Vector3.xAxis, ["+z"] = Vector3.zAxis, ["-z"] = -Vector3.zAxis})[d.low]
		local across = (dir.X ~= 0) and d.s[3] or d.s[1]
		local along = (dir.X ~= 0) and d.s[1] or d.s[3]
		p.Size = Vector3.new(across, d.s[2], along)
		p.CFrame = CFrame.lookAt(pos, pos + dir)
	else
		p.Size = Vector3.new(d.s[1], d.s[2], d.s[3]); p.Position = pos
	end
	p.Color = hex(d.c); p.Transparency = d.t; p.CanCollide = d.cc
	p.Material = Enum.Material[d.m] or Enum.Material.Plastic
	p.TopSurface = Enum.SurfaceType.Smooth; p.BottomSurface = Enum.SurfaceType.Smooth
	if p.Material == Enum.Material.Plastic and d.t == 0 and not d.low then
		local faces = {Enum.NormalId.Top}
		if d.g == "Walls" or d.n == "BackTier" or d.n == "RearTier" or d.n == "Platform" then faces = {Enum.NormalId.Top, Enum.NormalId.Front, Enum.NormalId.Back, Enum.NormalId.Left, Enum.NormalId.Right} end
		for _, face in ipairs(faces) do
			local t = Instance.new("Texture"); t.Name = "Studs"; t.Texture = STUDS; t.Face = face
			t.StudsPerTileU = 2; t.StudsPerTileV = 2; t.Parent = p
		end
	end
	p.Parent = f
end
hub.Parent = Map
say(("built Map.Hub with %d parts"):format(#P))

-- 4. move the existing game models onto the new pads
local function moveModel(m, spec)
	local pv = m:GetPivot()
	local bb = m:GetBoundingBox() -- targets are footprint centres, so shift by the centre, keep the pivot's height
	-- spec[2] is a height change, remembered so running this twice does not stack it
	local dy = (spec[2] or 0) - (m:GetAttribute("HubDY") or 0)
	m:SetAttribute("HubDY", spec[2] or 0)
	local pos = pv.Position + Vector3.new(spec[1] - bb.X, dy, spec[3] - bb.Z)
	local cf = CFrame.new(pos) * (pv - pv.Position)
	if spec[4] == "faceZ" and not m:GetAttribute("HubFacedZ") then
		cf = cf * CFrame.Angles(0, math.rad(90), 0); m:SetAttribute("HubFacedZ", true)
	end
	m:PivotTo(cf)
end
for folderPath, list in pairs(MOVES) do
	local f = Map
	for seg in folderPath:gmatch("[^%.]+") do f = f and f:FindFirstChild(seg) end
	if f then for key, spec in pairs(list) do
		local name, ax, az = key:match("^(.-)@(%-?%d+),(%-?%d+)$")
		local target
		if name then -- pick the child with that name nearest the old X,Z
			local best = 1e9
			for _, c in ipairs(f:GetChildren()) do if c.Name == name then
				local p = c:IsA("Model") and c:GetPivot().Position or c.Position
				local dd = (Vector2.new(p.X, p.Z) - Vector2.new(tonumber(ax), tonumber(az))).Magnitude
				if dd < best and dd < 6 then best = dd; target = c end
			end end
		else target = f:FindFirstChild(key) end
		if target then
			if target:IsA("Model") then moveModel(target, spec)
			else target.Position = Vector3.new(spec[1], target.Position.Y, spec[3]) end
		else say("not found: " .. folderPath .. "." .. key) end
	end end
end
local shop = gal and gal:FindFirstChild("ShopZone")
if shop then shop.Position = Vector3.new(SHOP.pos[1], SHOP.pos[2], SHOP.pos[3]); shop.Size = Vector3.new(SHOP.size[1], SHOP.size[2], SHOP.size[3]) end

-- 5. lane floor in the same stone grey
local lane = Map:FindFirstChild("Lane")
if lane then for _, c in ipairs(lane:GetChildren()) do
	if c.Name == "Floor" then c.Color = hex(RECOLOR.stone) elseif c.Name == "Kerb" then c.Color = hex(RECOLOR.stone_dark) end
end end
say("done")
return table.concat(log, "\n")
