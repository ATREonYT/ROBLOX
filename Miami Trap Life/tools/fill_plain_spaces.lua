-- Fills the hood's plain spaces with hood detail. Everything added goes in a child Model "MTL_Fill" (lots) or
-- "MTL_Tags" (wall graffiti), so `Fill.clear()` removes it all.
--   * EmptyLot models: dirt and gravel patches, weeds, a junk car (full-detail SedanA, faded, on bricks
--     sometimes), tyres, a shopping cart, pallets, trash bags, a hand-painted sign
--   * big blank walls (no windows, at least 24 x 10 studs): a graffiti piece or tag, drawn with SurfaceGui
--     (no image assets, so it shows without asset permissions)
-- Everything checks the spot is clear first, so nothing overlaps.
local SS = game:GetService("ServerStorage")
local folders = { workspace.ViceBay.Buildings.Hood, workspace.ViceBay.Buildings.HoodWest, workspace.ViceBay.Buildings.HoodNorth }
local SEDAN = SS.VBAssets.SedanA
local C = Color3.fromRGB
local M = Enum.Material

local Fill = {}

function Fill.clear()
	for _, f in folders do
		for _, m in f:GetChildren() do
			for _, n in { "MTL_Fill", "MTL_Tags" } do
				local d = m:FindFirstChild(n)
				if d then d:Destroy() end
			end
		end
	end
end

local function clear(cf: CFrame, size: Vector3, ignore: { Instance }): boolean
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignore
	for _, h in workspace:GetPartBoundsInBox(cf, size, params) do
		if h.Transparency < 0.9 and h.CanCollide and h.Size.Y > 0.6 then
			local top = h.Position.Y + h.Size.Y / 2
			if top > cf.Position.Y - size.Y / 2 + 0.3 then
				return false
			end
		end
	end
	return true
end

local function lot(m: Model, rng: Random): number
	local fp = m:FindFirstChild("Footprint") :: BasePart?
	if not fp then return 0 end
	local g = Instance.new("Model")
	g.Name = "MTL_Fill"
	local n = 0
	local top = fp.Position.Y + fp.Size.Y / 2
	local F = CFrame.new(fp.Position.X, top, fp.Position.Z) * (fp.CFrame - fp.CFrame.Position)
	local hx, hz = fp.Size.X / 2 - 3, fp.Size.Z / 2 - 3
	local ignore = { g, workspace.Terrain, fp }
	local function P(name, size, cf, color, mat, opts)
		local p = Instance.new("Part")
		p.Name = name; p.Anchored = true; p.Size = size; p.CFrame = cf; p.Color = color; p.Material = mat
		p.TopSurface = Enum.SurfaceType.Smooth; p.BottomSurface = Enum.SurfaceType.Smooth
		if opts then for k, v in pairs(opts) do if k == "shape" then p.Shape = v else p[k] = v end end end
		p.Parent = g
		n += 1
		return p
	end
	local function spot(w, d, h)
		for _ = 1, 12 do
			local cf = F * CFrame.new(rng:NextNumber(-hx + w / 2, hx - w / 2), h / 2 + 0.05, rng:NextNumber(-hz + d / 2, hz - d / 2)) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0)
			if clear(cf, Vector3.new(w, h, d), ignore) then return cf * CFrame.new(0, -h / 2, 0) end
		end
		return nil
	end
	-- ground patches: dirt and gravel, flat, offset just above the lot (no z-fighting)
	for k = 1, rng:NextInteger(3, 5) do
		local w, d = rng:NextNumber(6, 14), rng:NextNumber(5, 12)
		local cf = F * CFrame.new(rng:NextNumber(-hx + w / 2, hx - w / 2), 0.03 + k * 0.012, rng:NextNumber(-hz + d / 2, hz - d / 2)) * CFrame.Angles(0, rng:NextNumber(0, math.pi), 0)
		local dirt = rng:NextNumber() < 0.6
		P("Patch", Vector3.new(w, 0.02, d), cf, if dirt then C(112, 92, 70) else C(132, 128, 120), if dirt then M.Ground else M.Pebble, { CanCollide = false, CastShadow = false })
	end
	-- weeds: small tufts of grass
	for _ = 1, rng:NextInteger(8, 14) do
		local cf = F * CFrame.new(rng:NextNumber(-hx, hx), 0, rng:NextNumber(-hz, hz))
		for j = 0, 2 do
			local h = rng:NextNumber(0.8, 1.8)
			local blade = Instance.new("WedgePart")
			blade.Name = "Weed"; blade.Anchored = true; blade.CanCollide = false; blade.CastShadow = false
			blade.Size = Vector3.new(0.1, h, 0.5); blade.Color = C(96 + rng:NextInteger(0, 30), 120 + rng:NextInteger(0, 20), 60); blade.Material = M.Grass
			blade.CFrame = cf * CFrame.Angles(0, j * 2.1, rng:NextNumber(-0.25, 0.25)) * CFrame.new(0, h / 2, 0)
			blade.Parent = g
			n += 1
		end
	end
	-- junk car (full detail sedan, faded paint, sometimes on bricks with no wheels showing)
	if rng:NextNumber() < 0.7 then
		local cf = spot(9, 18, 6)
		if cf then
			local car = SEDAN:Clone()
			car.Name = "JunkCar"
			for _, p in car:GetDescendants() do
				if p:IsA("BasePart") then p.Anchored = true; p.CanCollide = true end
				if p:IsA("Script") or p:IsA("LocalScript") then p:Destroy() end
			end
			local faded = ({ C(150, 120, 100), C(120, 130, 140), C(170, 160, 140), C(90, 100, 90), C(140, 80, 70) })[rng:NextInteger(1, 5)]
			for _, p in car:GetDescendants() do
				if p:IsA("BasePart") and p.Name == "Color" then p.Color = faded; p.Material = M.SmoothPlastic end
			end
			car:ScaleTo(0.9)
			local _, sz = car:GetBoundingBox()
			car:PivotTo(cf * CFrame.new(0, 0, 0))
			local cf2, sz2 = car:GetBoundingBox()
			car:PivotTo(car:GetPivot() + Vector3.new(0, top - (cf2.Y - sz2.Y / 2), 0))
			car.Parent = g
			n += 1
		end
	end
	-- tyre stack
	if rng:NextNumber() < 0.8 then
		local cf = spot(3, 3, 3)
		if cf then
			for k = 0, rng:NextInteger(1, 3) do
				P("Tyre", Vector3.new(0.9, 2.6, 2.6), cf * CFrame.new(rng:NextNumber(-0.2, 0.2), 0.45 + k * 0.9, rng:NextNumber(-0.2, 0.2)) * CFrame.Angles(0, 0, math.pi / 2), C(28, 28, 30), M.Rubber, { shape = Enum.PartType.Cylinder })
			end
		end
	end
	-- pallets
	for _ = 1, rng:NextInteger(1, 2) do
		local cf = spot(4, 4, 1)
		if cf then
			local tilt = if rng:NextNumber() < 0.4 then CFrame.Angles(math.rad(70), 0, 0) * CFrame.new(0, 1.8, 0) else CFrame.new()
			for k = -1, 1 do P("PalletSlat", Vector3.new(4, 0.15, 0.9), cf * tilt * CFrame.new(0, 0.6, k * 1.4), C(150, 120, 86), M.WoodPlanks) end
			for k = -1, 1 do P("PalletBlock", Vector3.new(0.6, 0.45, 3.8), cf * tilt * CFrame.new(k * 1.6, 0.25, 0), C(130, 104, 76), M.WoodPlanks) end
		end
	end
	-- shopping cart, tipped over sometimes
	if rng:NextNumber() < 0.5 then
		local cf = spot(3, 4, 3)
		if cf then
			local tip = if rng:NextNumber() < 0.5 then CFrame.Angles(0, 0, math.rad(80)) * CFrame.new(0.6, 0, 0) else CFrame.new()
			local base = cf * tip
			P("CartBasket", Vector3.new(2.2, 1.6, 3.2), base * CFrame.new(0, 2.2, 0), C(170, 172, 176), M.DiamondPlate, { Transparency = 0.3 })
			P("CartHandle", Vector3.new(2.4, 0.15, 0.15), base * CFrame.new(0, 3.1, 1.8), C(200, 40, 40), M.Plastic)
			P("CartFrame", Vector3.new(1.8, 0.15, 2.8), base * CFrame.new(0, 0.6, 0), C(150, 152, 156), M.Metal)
			for _, w in { { -0.8, -1.2 }, { 0.8, -1.2 }, { -0.8, 1.2 }, { 0.8, 1.2 } } do
				P("CartWheel", Vector3.new(0.2, 0.5, 0.5), base * CFrame.new(w[1], 0.25, w[2]), C(30, 30, 30), M.Rubber, { shape = Enum.PartType.Cylinder })
				P("CartLeg", Vector3.new(0.12, 1.4, 0.12), base * CFrame.new(w[1], 1.1, w[2]), C(150, 152, 156), M.Metal)
			end
		end
	end
	-- trash bags and a mattress against the fence
	for _ = 1, rng:NextInteger(2, 5) do
		local cf = spot(1.8, 1.8, 1.8)
		if cf then P("TrashBag", Vector3.new(1.7, 1.5, 1.7), cf * CFrame.new(0, 0.75, 0), C(18, 18, 20), M.Plastic, { shape = Enum.PartType.Ball }) end
	end
	if rng:NextNumber() < 0.4 then
		local cf = spot(4.5, 1, 6.5)
		if cf then P("Mattress", Vector3.new(4.2, 0.7, 6.2), cf * CFrame.new(0, 0.35, 0) * CFrame.Angles(0, 0, math.rad(rng:NextNumber(-6, 6))), C(206, 196, 170), M.Fabric) end
	end
	-- hand-painted sign on a post
	if not m:FindFirstChild("Sign") then
		local cf = F * CFrame.new(rng:NextNumber(-hx * 0.5, hx * 0.5), 0, -hz + 0.5)
		if clear(cf * CFrame.new(0, 3, 0), Vector3.new(4, 6, 1), ignore) then
			P("SignPost", Vector3.new(0.3, 5, 0.3), cf * CFrame.new(-1.6, 2.5, 0), C(100, 80, 60), M.Wood)
			P("SignPost", Vector3.new(0.3, 5, 0.3), cf * CFrame.new(1.6, 2.5, 0), C(100, 80, 60), M.Wood)
			local board = P("SignBoard", Vector3.new(4, 2, 0.2), cf * CFrame.new(0, 4.2, 0), C(226, 220, 204), M.WoodPlanks)
			local sg = Instance.new("SurfaceGui"); sg.Face = Enum.NormalId.Front; sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud; sg.PixelsPerStud = 40; sg.LightInfluence = 1; sg.Parent = board
			local t = Instance.new("TextLabel"); t.Size = UDim2.fromScale(1, 1); t.BackgroundTransparency = 1
			t.Text = ({ "NO TRESPASSING", "FOR SALE\n305-555-0199", "NO DUMPING", "PRIVATE PROPERTY", "LOT FOR SALE" })[rng:NextInteger(1, 5)]
			t.Font = Enum.Font.PermanentMarker; t.TextScaled = true; t.TextColor3 = C(170, 30, 30); t.Parent = sg
		end
	end
	g.Parent = m
	return n
end

local TAGS = { "305", "KLOW", "ZOE", "DADE", "OBEY", "NSIDE", "LIL HAITI", "BIG MIKE", "RIP TONE", "MIAMI", "OPA LOCKA", "R.I.P" }
local CollectionService = game:GetService("CollectionService")
-- job sites and walk-in interiors never get tags (their walls have an inside that players see)
local function isJobOrInterior(m: Model): boolean
	local n = m.Name:lower()
	if n:find("mall") or n:find("job") or n:find("interior") or n:find("store") or n:find("mart") then return true end
	if m:GetAttribute("MTL_JobSite") or m:GetAttribute("MTL_Interior") then return true end
	for _, d in m:GetDescendants() do
		if CollectionService:HasTag(d, "MTL_JobTask") or d.Name == "Interior" then return true end
	end
	return false
end

local function graffiti(m: Model, rng: Random): number
	if isJobOrInterior(m) then return 0 end
	-- find big flat side/back walls with no windows: raycast a grid against the wall; every ray must hit the same part
	local n = 0
	local tags = Instance.new("Model")
	tags.Name = "MTL_Tags"
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { m }
	local used = 0
	for _, p in m:GetDescendants() do
		if used >= 2 then break end
		if p:IsA("BasePart") and p.Transparency < 0.1 and p.Material ~= M.Glass and p.Parent ~= tags then
			local s = p.Size
			for _, face in { { Enum.NormalId.Front, s.X, s.Y, Vector3.new(0, 0, -1) }, { Enum.NormalId.Back, s.X, s.Y, Vector3.new(0, 0, 1) }, { Enum.NormalId.Left, s.Z, s.Y, Vector3.new(-1, 0, 0) }, { Enum.NormalId.Right, s.Z, s.Y, Vector3.new(1, 0, 0) } } do
				local fw, fh, ln = face[2], face[3], face[4]
				local wn = p.CFrame:VectorToWorldSpace(ln)
				if fw >= 24 and fh >= 10 and math.abs(wn.Y) < 0.1 and used < 2 then
					-- the art area: lower part of the wall, 60% wide, 6-8 tall, starting 1.5 above the base
					local aw, ah = math.min(fw * 0.6, 34), math.min(fh - 3, 8)
					local depth = (if math.abs(ln.Z) > 0 then s.Z else s.X) / 2
					local centre = p.CFrame * CFrame.new(ln * depth) * CFrame.new(0, -s.Y / 2 + 1.5 + ah / 2, 0)
					local ok = true
					for _, gx in { -0.45, 0, 0.45 } do
						for _, gy in { -0.4, 0, 0.4 } do
							local right = p.CFrame:VectorToWorldSpace(if math.abs(ln.Z) > 0 then Vector3.new(1, 0, 0) else Vector3.new(0, 0, 1))
							local o = centre.Position + right * aw * gx + Vector3.new(0, ah * gy, 0) + wn * 3
							local r = workspace:Raycast(o, -wn * 4, params)
							if not r or r.Instance ~= p then ok = false end
						end
					end
					-- and nothing of the map stands right in front of it (other building, fence)
					-- an outside face: looking out from it, no wall of the same building comes back within 40 studs
					if ok then
						local back = workspace:Raycast(centre.Position + wn * 0.3, wn * 40, params)
						if back and back.Instance.Size.Y > 4 and back.Instance.Transparency < 0.5 then ok = false end
					end
					if ok then
						local look = CFrame.lookAt(centre.Position + wn * 0.04, centre.Position + wn * 2)
						local front = clear(look * CFrame.new(0, 0, -1.6), Vector3.new(aw, ah, 3), { m, workspace.Terrain })
						if front then
							local sheet = Instance.new("Part")
							sheet.Name = "Graffiti"; sheet.Anchored = true; sheet.CanCollide = false; sheet.CanQuery = false; sheet.CanTouch = false; sheet.CastShadow = false
							sheet.Transparency = 1; sheet.Size = Vector3.new(aw, ah, 0.05); sheet.CFrame = look; sheet.Parent = tags
							local sg = Instance.new("SurfaceGui"); sg.Face = Enum.NormalId.Front; sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud; sg.PixelsPerStud = 16; sg.LightInfluence = 1; sg.Parent = sheet
							local piece = rng:NextNumber() < 0.45
							if piece then
								-- colourful "piece": gradient fill letters with thick outline
								local bg = Instance.new("Frame"); bg.Size = UDim2.fromScale(1, 1); bg.BackgroundTransparency = 1; bg.Parent = sg
								local t = Instance.new("TextLabel"); t.Size = UDim2.fromScale(1, 1); t.BackgroundTransparency = 1
								t.Text = TAGS[rng:NextInteger(1, #TAGS)]; t.Font = Enum.Font.PermanentMarker; t.TextScaled = true
								t.TextColor3 = C(255, 255, 255); t.TextStrokeTransparency = 0; t.TextStrokeColor3 = C(20, 14, 30); t.Rotation = rng:NextInteger(-4, 4); t.Parent = bg
								local h0 = rng:NextNumber()
								local gr = Instance.new("UIGradient")
								gr.Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, Color3.fromHSV(h0, 0.8, 1)), ColorSequenceKeypoint.new(1, Color3.fromHSV((h0 + 0.2) % 1, 0.85, 0.95)) })
								gr.Rotation = 90; gr.Parent = t
							else
								-- a few quick tags scattered
								for k = 1, rng:NextInteger(2, 4) do
									local t = Instance.new("TextLabel"); t.BackgroundTransparency = 1
									t.Size = UDim2.fromScale(rng:NextNumber(0.25, 0.4), rng:NextNumber(0.3, 0.5)); t.Position = UDim2.fromScale(rng:NextNumber(0, 0.65), rng:NextNumber(0, 0.5))
									t.Text = TAGS[rng:NextInteger(1, #TAGS)]; t.Font = if rng:NextNumber() < 0.5 then Enum.Font.PermanentMarker else Enum.Font.Kalam; t.TextScaled = true
									t.TextColor3 = ({ C(30, 30, 34), C(200, 40, 60), C(40, 90, 200), C(240, 240, 240), C(60, 160, 80) })[rng:NextInteger(1, 5)]
									t.Rotation = rng:NextInteger(-12, 12); t.Parent = sg
								end
							end
							used += 1
							n += 1
						end
					end
				end
			end
		end
	end
	if n > 0 then tags.Parent = m else tags:Destroy() end
	return n
end

function Fill.run(seed: number?): string
	local lots, lotParts, walls = 0, 0, 0
	local i = 0
	for _, f in folders do
		for _, m in f:GetChildren() do
			if m:IsA("Model") then
				i += 1
				local rng = Random.new((seed or 91) + i * 17)
				if m.Name == "EmptyLot" and not m:FindFirstChild("MTL_Fill") then
					lotParts += lot(m, rng)
					lots += 1
				elseif m.Name ~= "EmptyLot" and not m:FindFirstChild("MTL_Tags") and rng:NextNumber() < 0.55 then
					walls += graffiti(m, rng)
				end
				if i % 6 == 0 then task.wait() end
			end
		end
	end
	return ("filled %d empty lots (%d parts), %d graffiti walls"):format(lots, lotParts, walls)
end

return Fill
