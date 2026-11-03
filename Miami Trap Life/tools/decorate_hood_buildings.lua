-- Adds Larp-style street detail to the hood's existing buildings (Apartments, MidRise, House, AutoShop,
-- AbandonedHouse, Church) without touching their own parts. Everything it adds goes in a child Model named
-- "MTL_Decor", so `Decorate.clear()` removes it all.
--   * wall AC condensers (rust side panel + rust drip), placed only where a raycast hits solid wall (never glass)
--   * downpipes at the front corners
--   * grime decal sheets on every facade (rain streaks + base dirt; shows once the image is shared)
--   * roof clutter: HVAC box, vents, satellite dish, water tank on tall buildings, a peeling billboard sometimes
--   * a dumpster + trash bags beside apartments, midrises and auto shops
-- Usage (ModuleScript): local D = require(...); D.run(seed) / D.clear()
local hoodFolders = { workspace.ViceBay.Buildings.Hood, workspace.ViceBay.Buildings.HoodWest, workspace.ViceBay.Buildings.HoodNorth }
local GRIME = "rbxassetid://100588449546910"
local PEEL = "rbxassetid://132669183333957"
local C = Color3.fromRGB
local M = Enum.Material
local STEEL = C(38, 38, 40)

local TYPES = { Apartments = true, MidRise = true, House = true, AutoShop = true, AbandonedHouse = true, Church = true, Shops = true }

local Decorate = {}

local function bounds(m: Model)
	-- body bounds in the footprint's frame (ignoring fences, plants, cars, earlier decor)
	local fp = m:FindFirstChild("Footprint") :: BasePart?
	local frame = if fp then fp.CFrame else m:GetPivot()
	frame = CFrame.new(frame.Position) * (frame - frame.Position)
	local mn, mx = Vector3.new(1e9, 1e9, 1e9), Vector3.new(-1e9, -1e9, -1e9)
	for _, p in m:GetChildren() do
		if p:IsA("BasePart") and p.Name ~= "Footprint" and p.Transparency < 0.9 and p.Size.Y > 3 then
			local s = p.Size / 2
			for _, x in { -1, 1 } do for _, y in { -1, 1 } do for _, z in { -1, 1 } do
				local w = frame:PointToObjectSpace((p.CFrame * CFrame.new(x * s.X, y * s.Y, z * s.Z)).Position)
				mn = mn:Min(w); mx = mx:Max(w)
			end end end
		end
	end
	return frame, mn, mx
end

function Decorate.clear()
	for _, f in hoodFolders do
		for _, m in f:GetChildren() do
			local d = m:FindFirstChild("MTL_Decor")
			if d then d:Destroy() end
		end
	end
end

local function decorate(m: Model, rng: Random): number
	local frame, mn, mx = bounds(m)
	if mn.X > 1e8 then return 0 end
	local W, H, D = mx.X - mn.X, mx.Y - mn.Y, mx.Z - mn.Z
	if W < 8 or H < 6 or D < 8 then return 0 end
	local decor = Instance.new("Model")
	decor.Name = "MTL_Decor"
	local n = 0
	local function P(name, size, cf, color, mat, opts)
		local p = Instance.new("Part")
		p.Name = name; p.Anchored = true; p.Size = size; p.CFrame = cf; p.Color = color; p.Material = mat or M.SmoothPlastic
		p.TopSurface = Enum.SurfaceType.Smooth; p.BottomSurface = Enum.SurfaceType.Smooth
		if opts then for k, v in pairs(opts) do if k == "shape" then p.Shape = v else p[k] = v end end end
		p.Parent = decor
		n += 1
		return p
	end
	local function noCol(p) p.CanCollide = false; p.CanQuery = false; p.CanTouch = false; return p end

	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Include
	rayParams.FilterDescendantsInstances = { m }

	-- facades: front (-Z), back (+Z), left (-X), right (+X) in the footprint frame
	local facades = {
		{ name = "Front", n = Vector3.new(0, 0, -1), u = Vector3.new(1, 0, 0), w = W, c = Vector3.new((mn.X + mx.X) / 2, 0, mn.Z) },
		{ name = "Back", n = Vector3.new(0, 0, 1), u = Vector3.new(-1, 0, 0), w = W, c = Vector3.new((mn.X + mx.X) / 2, 0, mx.Z) },
		{ name = "Left", n = Vector3.new(-1, 0, 0), u = Vector3.new(0, 0, -1), w = D, c = Vector3.new(mn.X, 0, (mn.Z + mx.Z) / 2) },
		{ name = "Right", n = Vector3.new(1, 0, 0), u = Vector3.new(0, 0, 1), w = D, c = Vector3.new(mx.X, 0, (mn.Z + mx.Z) / 2) },
	}
	-- y is the height above the building's base
	local function solidWallAt(f, along: number, y: number): (Vector3?, Vector3?)
		local origin = frame:PointToWorldSpace(f.c + f.u * along + Vector3.new(0, mn.Y + y, 0) + f.n * 6)
		local dir = frame:VectorToWorldSpace(-f.n) * 8
		local r = workspace:Raycast(origin, dir, rayParams)
		if not r then return nil end
		local hp = r.Instance
		if hp.Material == M.Glass or hp.Transparency > 0.3 or hp.Size.Y < 4 then return nil end
		if r.Normal:Dot(frame:VectorToWorldSpace(f.n)) < 0.95 then return nil end
		return r.Position, r.Normal
	end


	local isHouse = m.Name == "House" or m.Name == "AbandonedHouse" or m.Name == "Church"
	local bottom = mn.Y

	-- grime sheets on all four facades
	for _, f in facades do
		if m.Name == "Shops" and f.name == "Front" then continue end -- shops carry their own front grime
		local cf = CFrame.lookAt(frame:PointToWorldSpace(f.c + Vector3.new(0, bottom + H / 2, 0) + f.n * 0.07), frame:PointToWorldSpace(f.c + Vector3.new(0, bottom + H / 2, 0) + f.n * 2))
		local g = noCol(P("Grime", Vector3.new(f.w - 0.2, H - 0.4, 0.05), cf, C(0, 0, 0), M.SmoothPlastic, { Transparency = 1, CastShadow = false }))
		local d = Instance.new("Decal"); d.Texture = GRIME; d.Face = Enum.NormalId.Front; d.Transparency = if isHouse then 0.5 else 0.35; d.Parent = g
	end

	-- AC condensers on solid wall spots, one per floor band on front and sides
	local floors = math.max(1, math.floor((H - 2) / 10))
	local acCount = 0
	for _, f in facades do
		local perFace = if f.name == "Front" then (if m.Name == "Shops" then 0 else math.min(4, floors + 1)) elseif f.name == "Back" then (if m.Name == "Shops" then 1 else 0) else math.min(2, floors)
		if isHouse then perFace = if f.name == "Front" then 0 else (if rng:NextNumber() < 0.5 then 1 else 0) end
		for k = 1, perFace do
			for _try = 1, 6 do
				local along = rng:NextNumber(-f.w / 2 + 3, f.w / 2 - 3)
				local y = if isHouse then rng:NextNumber(3.5, math.min(H - 3, 6)) else 4 + 10 * rng:NextInteger(0, floors - 1) + rng:NextNumber(4, 6.5)
				if y > H - 3 then continue end
				local pos, nrm = solidWallAt(f, along, y)
				if pos then
					local out = nrm :: Vector3
					local base = CFrame.lookAt(pos + out * 0.7, pos + out * 2)
					P("ACBody", Vector3.new(3, 2.3, 1.3), base, C(206, 204, 196), M.Metal)
					P("ACRust", Vector3.new(0.9, 2.3, 0.05), base * CFrame.new(1.05, 0, -0.67), C(122, 74, 44), M.CorrodedMetal)
					P("ACFan", Vector3.new(0.08, 1.85, 1.85), base * CFrame.new(-0.35, 0, -0.67) * CFrame.Angles(0, math.pi / 2, 0), C(42, 42, 44), M.Metal, { shape = Enum.PartType.Cylinder })
					P("ACBracket", Vector3.new(0.15, 0.15, 1.4), base * CFrame.new(-1.1, -1.25, 0), STEEL, M.Metal)
					P("ACBracket", Vector3.new(0.15, 0.15, 1.4), base * CFrame.new(1.1, -1.25, 0), STEEL, M.Metal)
					noCol(P("ACDrip", Vector3.new(1.2, 2.2, 0.04), CFrame.lookAt(pos + out * 0.03 + Vector3.new(0, -2.4, 0), pos + out * 2 + Vector3.new(0, -2.4, 0)), C(150, 96, 60), M.CorrodedMetal, { Transparency = 0.3, CastShadow = false }))
					acCount += 1
					break
				end
			end
		end
	end

	-- downpipes at the two front corners
	if m.Name ~= "Shops" and (not isHouse or rng:NextNumber() < 0.5) then
		for _, side in { -1, 1 } do
			local along = side * (W / 2 - 0.8)
			local pos = frame:PointToWorldSpace(Vector3.new((mn.X + mx.X) / 2 + along, bottom + H / 2 - 0.5, mn.Z - 0.35))
			P("Downpipe", Vector3.new(0.45, H - 1.5, 0.45), CFrame.new(pos) * (frame - frame.Position), C(140, 136, 130), M.Metal)
		end
	end

	-- roof clutter (flat roofs only: apartments, midrise, auto shop)
	if not isHouse then
		local roofY = mx.Y
		local function onRoof(x, z) return frame * CFrame.new((mn.X + mx.X) / 2 + x, roofY, (mn.Z + mx.Z) / 2 + z) end
		local hx, hz = rng:NextNumber(-W / 4, W / 4), rng:NextNumber(-D / 5, D / 4)
		P("RoofHVAC", Vector3.new(6, 3, 4.5), onRoof(hx, hz) * CFrame.new(0, 1.5, 0), C(196, 196, 190), M.Metal)
		P("RoofHVACFan", Vector3.new(0.3, 2.4, 2.4), onRoof(hx - 1.3, hz) * CFrame.new(0, 3.1, 0) * CFrame.Angles(0, 0, math.pi / 2), C(50, 50, 52), M.Metal, { shape = Enum.PartType.Cylinder })
		for k = 1, rng:NextInteger(2, 4) do
			P("RoofVent", Vector3.new(1.8, 0.6, 0.6), onRoof(rng:NextNumber(-W / 3, W / 3), rng:NextNumber(-D / 3, D / 3)) * CFrame.new(0, 0.9, 0) * CFrame.Angles(0, 0, math.pi / 2), C(150, 150, 150), M.Metal, { shape = Enum.PartType.Cylinder })
		end
		if rng:NextNumber() < 0.6 then
			local dx, dz = rng:NextNumber(-W / 3, W / 3), -D / 2 + 3
			P("DishPole", Vector3.new(0.25, 2.2, 0.25), onRoof(dx, dz) * CFrame.new(0, 1.1, 0), STEEL, M.Metal)
			P("Dish", Vector3.new(0.35, 2.4, 2.4), onRoof(dx, dz) * CFrame.new(0, 2.4, -0.2) * CFrame.Angles(0, math.rad(rng:NextNumber(60, 120)), math.rad(20)), C(220, 220, 216), M.SmoothPlastic, { shape = Enum.PartType.Cylinder })
		end
		if H > 30 and rng:NextNumber() < 0.7 then
			-- wooden water tank on steel legs
			local tx, tz = rng:NextNumber(-W / 4, W / 4), rng:NextNumber(0, D / 4)
			for _, l in { { -1.6, -1.6 }, { 1.6, -1.6 }, { -1.6, 1.6 }, { 1.6, 1.6 } } do
				P("TankLeg", Vector3.new(0.4, 5, 0.4), onRoof(tx + l[1], tz + l[2]) * CFrame.new(0, 2.5, 0), STEEL, M.Metal)
			end
			P("Tank", Vector3.new(6, 5, 5), onRoof(tx, tz) * CFrame.new(0, 7.5, 0) * CFrame.Angles(0, 0, math.pi / 2), C(110, 82, 60), M.WoodPlanks, { shape = Enum.PartType.Cylinder })
			P("TankCap", Vector3.new(1.4, 5.4, 5.4), onRoof(tx, tz) * CFrame.new(0, 10.6, 0) * CFrame.Angles(0, 0, math.pi / 2), C(70, 66, 62), M.Metal, { shape = Enum.PartType.Cylinder })
		end
		if rng:NextNumber() < 0.3 then
			-- peeling billboard facing the street
			local bw = math.min(W * 0.7, 26)
			local bz = (mn.Z + mx.Z) / 2 + D * 0.15
			for _, dx in { -bw / 2 + 2, bw / 2 - 2 } do
				P("BillPost", Vector3.new(0.8, 12, 0.8), frame * CFrame.new((mn.X + mx.X) / 2 + dx, roofY + 6, bz + 1), C(100, 66, 44), M.CorrodedMetal)
			end
			local b = P("Billboard", Vector3.new(bw, 10, 0.4), frame * CFrame.new((mn.X + mx.X) / 2, roofY + 12, bz) * CFrame.Angles(0, math.pi, 0), C(240, 238, 232), M.SmoothPlastic)
			local d = Instance.new("Decal"); d.Texture = PEEL; d.Face = Enum.NormalId.Back; d.Parent = b
		end
	end

	-- dumpster + trash beside bigger buildings
	if not isHouse then
		local side = if rng:NextNumber() < 0.5 then -1 else 1
		local dcf = frame * CFrame.new(if side < 0 then mn.X - 3.5 else mx.X + 3.5, bottom, (mn.Z + mx.Z) / 2 + rng:NextNumber(-D / 4, D / 4)) * CFrame.Angles(0, math.pi / 2, 0)
		-- only if the spot is clear
		local params = OverlapParams.new(); params.FilterType = Enum.RaycastFilterType.Exclude; params.FilterDescendantsInstances = { decor, workspace.Terrain }
		local blocked = workspace:GetPartBoundsInBox(dcf * CFrame.new(0, 2.6, 0), Vector3.new(6, 4, 3.6), params)
		local solid = 0
		for _, b in blocked do if b.Transparency < 0.9 and b.CanCollide and (b.Position.Y + b.Size.Y / 2) > bottom + 0.6 then solid += 1 end end
		if solid == 0 then
			P("Dumpster", Vector3.new(6, 4, 3.6), dcf * CFrame.new(0, 2.2, 0), C(40, 90, 50), M.CorrodedMetal)
			P("DumpsterLid", Vector3.new(6.1, 0.2, 3.8), dcf * CFrame.new(0, 4.35, -0.1) * CFrame.Angles(math.rad(-6), 0, 0), C(30, 30, 30), M.Plastic)
			for k = 1, rng:NextInteger(1, 3) do
				P("TrashBag", Vector3.new(1.7, 1.7, 1.7), dcf * CFrame.new(rng:NextNumber(-3, 3), 0.85, rng:NextNumber(2.4, 3.4)), C(18, 18, 20), M.Plastic, { shape = Enum.PartType.Ball })
			end
		end
	end

	decor.Parent = m
	return n
end

function Decorate.run(seed: number?): string
	local total, count = 0, 0
	local i = 0
	for _, f in hoodFolders do
		for _, m in f:GetChildren() do
			if m:IsA("Model") and TYPES[m.Name] and not m:FindFirstChild("MTL_Decor") then
				i += 1
				total += decorate(m, Random.new((seed or 77) + i * 13))
				count += 1
				if count % 6 == 0 then task.wait() end
			end
		end
	end
	return ("decorated %d buildings, %d parts"):format(count, total)
end

return Decorate
