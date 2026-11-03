-- [MTL HoodLife] Storytelling dressing for the hood (Edit mode, Command Bar / MCP). Idempotent: every run deletes and
-- rebuilds Workspace.MTL_HoodLife, and touches nothing else in the map (other threads own buildings, textures, streets,
-- graffiti, lot props). Positions it needs come from ReplicatedStorage.MTL.Config.AmbientMap (install the scripts
-- first). It also copies the map's SedanA into ReplicatedStorage.MTL_AmbientCars for the client traffic.
--   * personality shop signs 0.03 studs in front of the 53 shops' own Sign parts (neighbours never repeat), OPEN
--     neon, WE ACCEPT EBT, hours, NO LOITERING (people loiter under it: Lean spots are right there)
--   * the church marquee, the R.I.P. LIL DRE memorial wall (candles, teddy bears, flowers, balloons), the WELCOME TO
--     LIBERTY HEIGHTS sunset mural, kids' handprints. Murals are SurfaceGui art with an `ArtSlot` ImageLabel for
--     Alex's decal (Image empty until then).
--   * power lines strung on the utility poles, sneakers on one, laundry between buildings, flyers on poles
--   * vignettes (each adds NPC spots): domino table under a tree, car on blocks with the hood up + mechanic, BBQ +
--     cooler + folding chairs, milk-crate hoop, yard sale, shopping carts, BEWARE OF DOG fence with a dog
-- Spots for the new vignettes are POSTed to the survey receiver (tools/survey/dress.json, port 34874) so
-- tools/build_ambient_map.py can add them to AmbientMap. Decor rules: anchored, CanCollide/CanTouch/CanQuery false,
-- CastShadow false on small things, 0.03 studs off surfaces, no pure colours, whites at most ~225.
local H = game:GetService("HttpService")
local RS = game:GetService("ReplicatedStorage")
local SS = game:GetService("ServerStorage")
local CS = game:GetService("CollectionService")

local SPAWN = Vector3.new(-1432, 3, -368)
local VB = workspace.ViceBay
local C = Color3.fromRGB
local M = Enum.Material
local rng = Random.new(1977)

local Map = require(RS.MTL.Config.AmbientMap)

local old = workspace:FindFirstChild("MTL_HoodLife")
if old then
	old:Destroy()
end
local root = Instance.new("Folder")
root.Name = "MTL_HoodLife"
local report = {}
local spots = {} -- { kind, x, y, z, yawDeg, n?, pose? }
local parts, lights = 0, 0
local claimed = {} -- { pos, r } vignette areas already used

-- sun-faded palette (Playbook): nothing pure, whites capped
local PAL = {
	salmon = C(222, 160, 140), mint = C(160, 200, 175), sky = C(140, 175, 200), cream = C(222, 214, 192),
	dirty = C(205, 200, 190), white = C(225, 220, 205), ink = C(28, 26, 30), red = C(178, 44, 46),
	gold = C(214, 170, 62), green = C(46, 120, 74), blue = C(40, 74, 140), purple = C(104, 62, 140),
	pink = C(220, 120, 150), orange = C(222, 120, 50), brown = C(110, 76, 50), wood = C(142, 104, 70),
	metal = C(120, 122, 126), dark = C(46, 46, 50),
}

---------------------------------------------------------------- helpers

local function group(name: string, parent: Instance?): Model
	local m = Instance.new("Model")
	m.Name = name
	m.Parent = parent or root
	return m
end

local function P(parent: Instance, name: string, size: Vector3, cf: CFrame, color: Color3, mat: Enum.Material?, opts: any?): BasePart
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = mat or M.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.CastShadow = size.Magnitude > 6
	if opts then
		for k, v in opts do
			(p :: any)[k] = v
		end
	end
	p.Parent = parent
	parts += 1
	return p
end

local function spot(kind: string, cf: CFrame, n: number?, pose: string?)
	local look = cf.LookVector
	local yaw = math.deg(math.atan2(-look.X, -look.Z))
	table.insert(spots, { kind, math.floor(cf.X * 10 + 0.5) / 10, math.floor(cf.Y * 100 + 0.5) / 100, math.floor(cf.Z * 10 + 0.5) / 10, math.floor(yaw * 10 + 0.5) / 10, n or 0, pose or "" }) -- 0 / "" = none (JSON has no nil holes)
end

local mapIgnore = { root, workspace.Terrain }
local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude
rayParams.RespectCanCollide = true

local PLANT_NAMES = { Plant = true, Tree = true, Palm = true, Bush = true, Shrub = true, Flowers = true }
local function ground(pos: Vector3): number
	-- skip tree canopies and plants (their leaves are solid, props used to float on them)
	local skip = table.clone(mapIgnore)
	local origin = pos + Vector3.new(0, 30, 0)
	for _ = 1, 8 do
		rayParams.FilterDescendantsInstances = skip
		local hit = workspace:Raycast(origin, Vector3.new(0, -80, 0), rayParams)
		if not hit then
			return pos.Y
		end
		local model = hit.Instance:FindFirstAncestorWhichIsA("Model")
		if model and PLANT_NAMES[model.Name] then
			table.insert(skip, model or hit.Instance)
		else
			return hit.Position.Y
		end
	end
	return pos.Y
end

-- nothing standing in this box more than half a stud above its floor? Grass, ground, invisible volumes don't count,
-- and a tree's canopy high overhead doesn't either (a vignette can sit under a tree, not through its trunk)
local SOFT = { [M.Grass] = true, [M.LeafyGrass] = true, [M.Ground] = true, [M.Mud] = true, [M.Sand] = true }
local PLANTY = { Plant = true, Tree = true, Palm = true, Bush = true, Shrub = true, Flowers = true }
local function clear(cf: CFrame, size: Vector3): boolean
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = mapIgnore
	local floor = cf.Position.Y - size.Y / 2
	for _, h in workspace:GetPartBoundsInBox(cf, size, params) do
		if h.Transparency < 0.9 and h.Name ~= "Footprint" and not SOFT[h.Material] then
			if h.Position.Y + h.Size.Y / 2 > floor + 0.5 then
				local model = h:FindFirstAncestorWhichIsA("Model")
				local canopy = model ~= nil and PLANTY[model.Name] == true and h.Position.Y - h.Size.Y / 2 > floor + 5
				if not canopy then
					return false
				end
			end
		end
	end
	return true
end

-- vignette = true also enforces the spread rule: never more than 2 vignettes within 80 studs
local function free(pos: Vector3, r: number, vignette: boolean?): boolean
	local near = 0
	for _, c in claimed do
		if (c.pos - pos).Magnitude < c.r + r then
			return false
		end
		if vignette and c.vignette and (c.pos - pos).Magnitude < 80 then
			near += 1
		end
	end
	return near < 2
end

local function claim(pos: Vector3, r: number, vignette: boolean?)
	table.insert(claimed, { pos = pos, r = r, vignette = vignette == true })
end

-- a mural canvas: a fixed-size SurfaceGui that ignores scene light (the PixelsPerStud + lit version rendered blank
-- white on the memorial fence in Edit captures). `pxPerStud` sets the canvas resolution.
local function canvas(part: BasePart, pxPerStud: number): SurfaceGui
	local g = Instance.new("SurfaceGui")
	g.Face = Enum.NormalId.Front
	g.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
	g.CanvasSize = Vector2.new(math.floor(part.Size.X * pxPerStud), math.floor(part.Size.Y * pxPerStud))
	g.LightInfluence = 0
	g.Brightness = 1
	g.AlwaysOnTop = false
	g.ClipsDescendants = true
	g.MaxDistance = 300
	g.Parent = part
	return g
end

-- a SurfaceGui on the Front face of `part`
local function gui(part: BasePart, ppS: number?): SurfaceGui
	local g = Instance.new("SurfaceGui")
	g.Face = Enum.NormalId.Front
	g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	g.PixelsPerStud = ppS or 40
	g.LightInfluence = 1
	g.MaxDistance = 260
	g.Parent = part
	return g
end

local function text(parent: Instance, t: string, props: any): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Size = UDim2.fromScale(1, 1)
	l.Text = t
	l.TextScaled = true
	l.Font = Enum.Font.GothamBlack
	l.TextColor3 = PAL.white
	for k, v in props or {} do
		(l :: any)[k] = v
	end
	l.Parent = parent
	return l
end

local function frame(parent: Instance, props: any): Frame
	local f = Instance.new("Frame")
	f.BorderSizePixel = 0
	for k, v in props do
		(f :: any)[k] = v
	end
	f.Parent = parent
	return f
end

local function round(f: Instance, px: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, px)
	c.Parent = f
end

local function stroke(l: Instance, color: Color3, th: number)
	local s = Instance.new("UIStroke")
	s.Color = color
	s.Thickness = th
	s.Parent = l
end

-- a flat panel on a wall: centre point on the wall surface, outward normal n, width w, height h
local function panel(parent: Instance, name: string, at: Vector3, n: Vector3, w: number, h: number, color: Color3, mat: Enum.Material?): BasePart
	local cf = CFrame.lookAt(at + n * 0.055, at + n * 2) -- 0.03 off the wall + half the 0.05 thickness
	return P(parent, name, Vector3.new(w, h, 0.05), cf, color, mat, { CastShadow = false })
end

local function addLight(part: BasePart, color: Color3, range: number, brightness: number)
	if lights >= 6 then
		return -- budget: at most 6 new real lights
	end
	lights += 1
	local l = Instance.new("PointLight")
	l.Color = color
	l.Range = range
	l.Brightness = brightness
	l.Shadows = false
	l.Parent = part
end

-- a horizontal wall hit from outside: from `from` toward `dir`, only on `model`
local function wallHit(model: Instance, from: Vector3, dir: Vector3): RaycastResult?
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { model }
	return workspace:Raycast(from, dir, params)
end

---------------------------------------------------------------- 1. shop signs

local NAMES = {
	-- the 10 from the spec first, nearest spawn
	{ "MAMA DEE'S", "SOUL FOOD", PAL.cream, PAL.red, Enum.Font.Bangers },
	{ "LIBERTY WINGS & FISH", "FRIED FRESH DAILY", PAL.gold, PAL.ink, Enum.Font.GothamBlack },
	{ "CASH 4 GOLD", "WE BUY - WE SELL - WE PAWN", PAL.ink, PAL.gold, Enum.Font.Michroma },
	{ "LIBERTY LAUNDROMAT", "OPEN 24 HR - WASH & FOLD", PAL.sky, PAL.white, Enum.Font.GothamBold },
	{ "CHECK CASHING", "MONEY ORDERS - BILL PAY", PAL.green, PAL.white, Enum.Font.Oswald },
	{ "MS. ROSA'S BOTANICA", "VELAS - HIERBAS - FE", PAL.purple, PAL.white, Enum.Font.Fondamento },
	{ "TONY'S TIRES & RIMS", "NEW & USED - FLAT FIX $10", PAL.dark, PAL.orange, Enum.Font.Bangers },
	{ "LIBERTY WIRELESS", "PREPAID - NO CREDIT CHECK", PAL.blue, PAL.white, Enum.Font.GothamBlack },
	{ "ISLAND JERK & PATTIES", "OXTAIL - CURRY GOAT - PATTIES", PAL.green, PAL.gold, Enum.Font.Bangers },
	{ "KINGDOM BEAUTY SUPPLY", "WIGS - BRAIDING HAIR - NAILS", PAL.pink, PAL.ink, Enum.Font.GothamBold },
	-- the rest of the block
	{ "FRESH CUTZ", "BARBER SHOP - WALK-INS", PAL.white, PAL.red, Enum.Font.Bangers },
	{ "BRAIDS BY KEISHA", "KNOTLESS - BOX - CORNROWS", PAL.salmon, PAL.ink, Enum.Font.Fondamento },
	{ "LIBERTY LIQUOR & LOTTO", "COLD BEER - LOTTO - ICE", PAL.red, PAL.gold, Enum.Font.Oswald },
	{ "DOLLAR DREAM", "EVERYTHING $1.25 & UP", PAL.gold, PAL.blue, Enum.Font.GothamBlack },
	{ "PHONE FIX 305", "SCREENS - BATTERIES - UNLOCK", PAL.dark, PAL.sky, Enum.Font.Michroma },
	{ "TROPICAL DISCOUNT", "GROCERY - MEAT - PRODUCE", PAL.mint, PAL.red, Enum.Font.GothamBlack },
	{ "QUICK TAX & NOTARY", "REFUNDS FAST - SE HABLA ESPANOL", PAL.blue, PAL.gold, Enum.Font.GothamBold },
	{ "SUNSHINE CHINESE", "TAKE OUT - WINGS - FRIED RICE", PAL.red, PAL.gold, Enum.Font.Bangers },
	{ "KICKS & THREADS", "SNEAKERS - TEES - FITTEDS", PAL.ink, PAL.white, Enum.Font.Michroma },
	{ "LA PLACITA CAFE", "CAFECITO - PASTELITOS", PAL.cream, PAL.brown, Enum.Font.Fondamento },
	{ "SAMMY'S MEAT MARKET", "CHOICE CUTS - FAMILY PACKS", PAL.white, PAL.red, Enum.Font.Oswald },
	{ "ROYAL NAILS & SPA", "FULL SET $35", PAL.pink, PAL.white, Enum.Font.GothamBold },
	{ "BAIL BONDS 24/7", "CALL ANYTIME", PAL.gold, PAL.ink, Enum.Font.GothamBlack },
	{ "UNCLE RAY'S BBQ", "RIBS - TIPS - SAUSAGE", PAL.brown, PAL.gold, Enum.Font.Bangers },
	{ "HOT 'N' READY PIZZA", "$6 LARGE - TO GO", PAL.orange, PAL.white, Enum.Font.GothamBlack },
	{ "GOD'S GRACE THRIFT", "CLOTHES - FURNITURE - BOOKS", PAL.mint, PAL.ink, Enum.Font.Fondamento },
	{ "PAPI'S TACOS", "AL PASTOR - BIRRIA", PAL.green, PAL.white, Enum.Font.Bangers },
	{ "STAR CARIBBEAN BAKERY", "HARDO BREAD - BUN & CHEESE", PAL.cream, PAL.green, Enum.Font.GothamBold },
	{ "SOLE SURVIVOR", "SNEAKER CLEANING & RESTORE", PAL.sky, PAL.ink, Enum.Font.Michroma },
	{ "MAMI'S BOUTIQUE", "DRESSES - SHOES - BAGS", PAL.salmon, PAL.white, Enum.Font.Fondamento },
}
local HOURS = { "MON-SAT 7AM-11PM", "OPEN 7 DAYS 6AM-12AM", "MON-FRI 9-7  SAT 10-4", "OPEN TIL 2AM", "24 HOURS" }

local function signFace(sign: BasePart): (Vector3, Vector3, number, number)
	local g = sign:FindFirstChildOfClass("SurfaceGui")
	local face = if g then g.Face else Enum.NormalId.Front
	local nLocal = Vector3.fromNormalId(face)
	local n = sign.CFrame:VectorToWorldSpace(nLocal)
	local half = (sign.Size * nLocal).Magnitude / 2
	local centre = sign.Position + n * half
	-- face dimensions: the two local axes perpendicular to the normal (height = the more vertical one)
	local dims = {}
	for _, ax in { Vector3.xAxis, Vector3.yAxis, Vector3.zAxis } do
		if math.abs(ax:Dot(nLocal)) < 0.5 then
			table.insert(dims, { len = (sign.Size * ax).Magnitude, up = math.abs(sign.CFrame:VectorToWorldSpace(ax).Y) })
		end
	end
	table.sort(dims, function(a, b)
		return a.up < b.up
	end)
	return centre, n, dims[1].len, dims[2].len
end

local function personalitySign(shop: Model, def: any, idx: number)
	local sign = shop:FindFirstChild("Sign") :: BasePart
	local centre, n, w, h = signFace(sign)
	local g = group("Sign_" .. def[1], root)
	local board = panel(g, "Board", centre, n, w, h, def[3], M.SmoothPlastic)
	local sg = gui(board, 40)
	sg.LightInfluence = 0.6
	local pad = frame(sg, { BackgroundTransparency = 1, Size = UDim2.fromScale(0.94, 0.9), Position = UDim2.fromScale(0.03, 0.05) })
	local main = text(pad, def[1], { Size = UDim2.fromScale(1, 0.68), Font = def[5], TextColor3 = def[4] })
	stroke(main, def[3]:Lerp(PAL.ink, 0.6), 2)
	text(pad, def[2], { Size = UDim2.fromScale(1, 0.28), Position = UDim2.fromScale(0, 0.7), Font = Enum.Font.GothamBold, TextColor3 = def[4] })
	-- below the sign: OPEN neon / EBT / hours / NO LOITERING, stuck on the real facade (raycast onto the shop)
	local right = n:Cross(Vector3.yAxis).Unit
	local function onWall(name: string, u: number, dy: number, pw: number, ph: number): BasePart?
		local probe = centre + right * u + Vector3.new(0, dy, 0)
		local hit = wallHit(shop, probe + n * 3, -n * 8)
		if not hit or hit.Instance == sign or math.abs(hit.Normal.Y) > 0.3 then
			return nil
		end
		return panel(g, name, hit.Position, hit.Normal, pw, ph, PAL.dark)
	end
	local open = if idx % 2 == 1 then onWall("Open", w * 0.28, -h / 2 - 3.2, 3.2, 1.3) else nil
	if open then
		open.Material = M.Neon
		open.Color = C(255, 60, 120)
		open.Transparency = 0.05
		CS:AddTag(open, "MTL_Flicker") -- AmbientWindows flickers it now and then
		local og = gui(open, 40)
		og.LightInfluence = 0
		text(og, "OPEN", { TextColor3 = C(255, 236, 244), Font = Enum.Font.GothamBlack })
		if idx <= 3 then
			addLight(open, C(255, 80, 130), 10, 1)
		end
	end
	local ebt = if idx % 3 ~= 0 then onWall("EBT", -w * 0.3, -h / 2 - 3.6, 2.2, 1.4) else nil
	if ebt then
		ebt.Color = PAL.white
		local eg = gui(ebt, 50)
		text(eg, "WE ACCEPT\nEBT", { TextColor3 = PAL.blue, Font = Enum.Font.GothamBlack })
	end
	local hrs = onWall("Hours", -w * 0.12, -h / 2 - 5.2, 1.6, 1.1)
	if hrs then
		hrs.Color = PAL.white
		text(gui(hrs, 60), HOURS[(idx % #HOURS) + 1], { TextColor3 = PAL.ink, Font = Enum.Font.GothamBold })
	end
	if idx % 4 == 1 then
		local nl = onWall("NoLoitering", -w * 0.42, -h / 2 - 2.6, 2.6, 1.3)
		if nl then
			nl.Color = PAL.white
			text(gui(nl, 50), "NO LOITERING", { TextColor3 = PAL.red, Font = Enum.Font.GothamBlack })
			-- ...and somebody loitering right under it
			local feet = Vector3.new(nl.Position.X, ground(nl.Position), nl.Position.Z) + n * 1.6
			spot("Lean", CFrame.lookAt(feet, feet + n), nil, "Lean")
		end
	end
end

local function signs(): number
	local shops = {}
	for _, fname in { "Hood", "HoodWest" } do
		local f = VB.Buildings:FindFirstChild(fname)
		for _, m in (if f then f:GetChildren() else {}) do
			if m:IsA("Model") and m.Name == "Shops" and m:FindFirstChild("Sign") and m:FindFirstChild("Sign"):IsA("BasePart") then
				table.insert(shops, m)
			end
		end
	end
	table.sort(shops, function(a, b)
		return (a:GetPivot().Position - SPAWN).Magnitude < (b:GetPivot().Position - SPAWN).Magnitude
	end)
	local given: { { pos: Vector3, name: string } } = {}
	local next = 1
	for i, shop in shops do
		local pos = shop:GetPivot().Position
		-- next name not used by any shop within 160 studs
		local def = nil
		for k = 0, #NAMES - 1 do
			local cand = NAMES[((next - 1 + k) % #NAMES) + 1]
			local ok = true
			for _, g in given do
				if g.name == cand[1] and (g.pos - pos).Magnitude < 160 then
					ok = false
					break
				end
			end
			if ok then
				def = cand
				next = ((next - 1 + k + 1) % #NAMES) + 1
				break
			end
		end
		def = def or NAMES[(i % #NAMES) + 1]
		table.insert(given, { pos = pos, name = def[1] })
		personalitySign(shop, def, i)
		if i % 6 == 0 then
			task.wait()
		end
	end
	return #shops
end

---------------------------------------------------------------- 2. walls: find a blank wall on a building

-- a blank stretch of wall (no glass, one plane) on `model`, facing roughly `side`, w x h at height y0
local function blankWall(model: Model, centre: Vector3, side: Vector3, w: number, h: number, y0: number): (Vector3?, Vector3?)
	local right = side:Cross(Vector3.yAxis).Unit
	local hits = {}
	local bad = 0
	local midHit: RaycastResult? = nil
	for _, u in { -w / 2, 0, w / 2 } do
		for _, v in { y0, y0 + h / 2, y0 + h } do
			local from = centre + side * 60 + right * u + Vector3.new(0, v - centre.Y, 0)
			local hit = wallHit(model, from, -side * 120)
			if not hit or hit.Material == M.Glass or (hit.Instance :: BasePart).Transparency > 0.3 or hit.Normal:Dot(side) < 0.9 then
				bad += 1
			else
				table.insert(hits, hit)
				if u == 0 and v == y0 + h / 2 then
					midHit = hit
				end
			end
		end
	end
	if bad > 1 or not midHit then
		return nil
	end
	local d0 = (midHit.Position - centre):Dot(side)
	local off = 0
	for _, hit in hits do
		if math.abs((hit.Position - centre):Dot(side) - d0) > 0.6 then
			off += 1
		end
	end
	if off > 1 then
		return nil
	end
	local hits5 = midHit
	local mid = hits5.Position
	-- someone else's art nearby? (graffiti tags, murals, decor)
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	local others = {}
	for _, k in { "MTL_Tags", "MTL_Decor" } do
		local f = model:FindFirstChild(k)
		if f then
			table.insert(others, f)
		end
	end
	for _, d in model:GetChildren() do
		if d.Name == "Mural" then
			table.insert(others, d)
		end
	end
	if #others > 0 then
		params.FilterDescendantsInstances = others
		if #workspace:GetPartBoundsInBox(CFrame.lookAt(mid + side * 0.8, mid + side * 2), Vector3.new(w + 1, h + 1, 1.6), params) > 0 then
			return nil
		end
	end
	return mid, hits5.Normal
end

local function homesNearSpawn(types: { [string]: boolean }): { Model }
	local out = {}
	for _, fname in { "Hood", "HoodWest" } do
		local f = VB.Buildings:FindFirstChild(fname)
		for _, m in (if f then f:GetChildren() else {}) do
			if m:IsA("Model") and types[m.Name] then
				table.insert(out, m)
			end
		end
	end
	table.sort(out, function(a, b)
		return (a:GetPivot().Position - SPAWN).Magnitude < (b:GetPivot().Position - SPAWN).Magnitude
	end)
	return out
end

local function findWall(w: number, h: number, types: { [string]: boolean }, skip: number?, near: Vector3?, within: number?): (Model?, Vector3?, Vector3?)
	local seen = 0
	local list = homesNearSpawn(types)
	if near then
		table.sort(list, function(a, b)
			return (a:GetPivot().Position - near).Magnitude < (b:GetPivot().Position - near).Magnitude
		end)
	end
	for _, m in list do
		local fp = m:FindFirstChild("Footprint") :: BasePart?
		local frameCF = if fp then fp.CFrame else m:GetPivot()
		local centre = frameCF.Position
		if near and within and (centre - near).Magnitude > within then
			break -- sorted by distance: everything after is further
		end
		local gy = ground(centre)
		for _, side in { frameCF.RightVector, -frameCF.RightVector, -frameCF.LookVector, frameCF.LookVector } do
			side = Vector3.new(side.X, 0, side.Z).Unit
			local at, n = blankWall(m, centre, side, w, h, gy + 1.5)
			if at and n and free(at, w / 2) then
				seen += 1
				if seen > (skip or 0) then
					claim(at, w / 2)
					return m, at, n
				end
			end
		end
	end
	return nil
end

---------------------------------------------------------------- 3. murals

local place: (r: number, prefer: Vector3?, avoid: Vector3?) -> CFrame? -- defined with the vignettes below

-- a freestanding painted board on two posts (for when no wall qualifies). `at` = ground point, facing the street.
-- Returns the board's front-face centre and normal, ready for panel().
local function freestanding(g: Model, at: CFrame, w: number, h: number, color: Color3): (Vector3, Vector3)
	local lift = 1.4
	for _, x in { -w / 2 + 0.4, w / 2 - 0.4 } do
		P(g, "Post", Vector3.new(0.7, h + lift + 0.4, 0.7), at * CFrame.new(x, (h + lift + 0.4) / 2, 0.4), C(96, 76, 56), M.Wood)
	end
	local board = P(g, "Board", Vector3.new(w, h, 0.4), at * CFrame.new(0, lift + h / 2, 0), color, M.WoodPlanks)
	local front = board.CFrame * CFrame.new(0, 0, -0.2)
	return front.Position, board.CFrame.LookVector
end

local function memorial(): string
	-- near the corner where people gather (the Corner spot closest to spawn); 16x10, else 12x8
	local busy = Vector3.new(-1442, 3, -340) -- between the Food Mart door and spawn
	local gather = SPAWN
	local best = 1e9
	for _, s in Map.Spots do
		if s[1] == "Corner" then
			local p = Vector3.new(s[2], s[3], s[4])
			if (p - busy).Magnitude < best then
				best, gather = (p - busy).Magnitude, p
			end
		end
	end
	local types = { Apartments = true, MidRise = true, Shops = true, House = true, AutoShop = true, AbandonedHouse = true }
	local MW, MH = 16, 10
	local m, at, n = findWall(MW, MH, types, nil, gather, 60)
	if not m then
		MW, MH = 12, 8
		m, at, n = findWall(MW, MH, types, nil, gather, 60)
	end
	local g = group("Memorial_LilDre")
	local host = if m then m.Name else "a memorial fence"
	if not m then
		-- no wall within 60 studs of the corner: a freestanding memorial fence right there
		local site = place(7, gather)
		if not site then
			g:Destroy()
			return "memorial: no wall, no room for a fence"
		end
		MW, MH = 12, 7
		at, n = freestanding(g, site, MW, MH, C(110, 84, 60))
	end
	assert(at and n)
	local wall = panel(g, "Mural", at, n, MW, MH, PAL.dirty)
	local sg = canvas(wall, 30)
	local bg = frame(sg, { Size = UDim2.fromScale(1, 1), BackgroundColor3 = C(36, 30, 60) })
	local grad = Instance.new("UIGradient")
	grad.Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, C(40, 34, 90)), ColorSequenceKeypoint.new(0.6, C(150, 60, 110)), ColorSequenceKeypoint.new(1, C(222, 140, 90)) })
	grad.Rotation = 90
	grad.Parent = bg
	-- portrait frame + Alex's art slot
	local portrait = frame(bg, { Size = UDim2.fromScale(0.28, 0.5), Position = UDim2.fromScale(0.36, 0.08), BackgroundColor3 = C(214, 170, 62) })
	round(portrait, 18)
	local inner = frame(portrait, { Size = UDim2.new(1, -16, 1, -16), Position = UDim2.fromOffset(8, 8), BackgroundColor3 = C(70, 50, 44) })
	round(inner, 14)
	text(inner, "DRE", { Font = Enum.Font.Bangers, TextColor3 = PAL.cream, Size = UDim2.fromScale(1, 0.4), Position = UDim2.fromScale(0, 0.3) })
	local art = Instance.new("ImageLabel")
	art.Name = "ArtSlot" -- TODO(Alex art): paste a decal id into Image to replace the painted placeholder
	art.BackgroundTransparency = 1
	art.Size = UDim2.fromScale(1, 1)
	art.Image = ""
	art.Parent = inner
	local rip = text(bg, "R.I.P. LIL DRE", { Font = Enum.Font.Bangers, TextColor3 = PAL.white, Size = UDim2.fromScale(0.9, 0.18), Position = UDim2.fromScale(0.05, 0.6) })
	stroke(rip, C(30, 20, 40), 3)
	text(bg, "2004 - 2023", { Font = Enum.Font.GothamBlack, TextColor3 = C(214, 170, 62), Size = UDim2.fromScale(0.5, 0.08), Position = UDim2.fromScale(0.25, 0.79) })
	text(bg, "FOREVER LIBERTY", { Font = Enum.Font.Fondamento, TextColor3 = PAL.cream, Size = UDim2.fromScale(0.8, 0.1), Position = UDim2.fromScale(0.1, 0.88) })
	for i, x in { 0.06, 0.82 } do
		local wing = text(bg, "☆", { TextColor3 = C(214, 170, 62), Size = UDim2.fromScale(0.12, 0.2), Position = UDim2.fromScale(x, 0.2) })
		wing.Rotation = if i == 1 then -12 else 12
	end
	-- the ground shrine: candles, teddy bears, flowers, balloons
	local right = n:Cross(Vector3.yAxis).Unit
	local gy = ground(at + n * 2)
	local base = Vector3.new(at.X, gy, at.Z)
	local flameHost: BasePart? = nil
	for i = 1, 9 do
		local p = base + n * rng:NextNumber(0.6, 1.6) + right * rng:NextNumber(-5, 5)
		local hgt = rng:NextNumber(0.6, 1.1)
		P(g, "Candle", Vector3.new(0.35, hgt, 0.35), CFrame.new(p + Vector3.new(0, hgt / 2, 0)), if i % 3 == 0 then C(170, 40, 50) else C(214, 200, 170), M.SmoothPlastic, { Shape = Enum.PartType.Cylinder, CFrame = CFrame.new(p + Vector3.new(0, hgt / 2, 0)) * CFrame.Angles(0, 0, math.rad(90)) })
		local flame = P(g, "Flame", Vector3.new(0.14, 0.24, 0.14), CFrame.new(p + Vector3.new(0, hgt + 0.12, 0)), C(255, 190, 90), M.Neon)
		flameHost = flameHost or flame
	end
	if flameHost then
		addLight(flameHost, C(255, 170, 90), 9, 1)
	end
	for _, u in { -3.4, 2.6 } do
		-- teddy bears
		local p = base + n * 1.1 + right * u
		local col = if u < 0 then C(150, 110, 80) else C(200, 170, 140)
		P(g, "Bear", Vector3.new(0.9, 0.9, 0.7), CFrame.new(p + Vector3.new(0, 0.45, 0)), col, M.Fabric)
		P(g, "BearHead", Vector3.new(0.65, 0.65, 0.65), CFrame.new(p + Vector3.new(0, 1.15, 0)), col, M.Fabric, { Shape = Enum.PartType.Ball })
		for _, e in { -0.25, 0.25 } do
			P(g, "Ear", Vector3.new(0.25, 0.25, 0.25), CFrame.new(p + Vector3.new(0, 1.45, 0) + right * e), col, M.Fabric, { Shape = Enum.PartType.Ball })
		end
	end
	for i = 1, 6 do
		local p = base + n * rng:NextNumber(0.3, 0.9) + right * rng:NextNumber(-6, 6)
		P(g, "Stem", Vector3.new(0.08, 1.2, 0.08), CFrame.new(p + Vector3.new(0, 0.6, 0)) * CFrame.Angles(math.rad(rng:NextNumber(-15, 15)), 0, 0), C(60, 110, 60))
		P(g, "Flower", Vector3.new(0.35, 0.35, 0.35), CFrame.new(p + Vector3.new(0, 1.25, 0)), ({ C(220, 60, 80), C(240, 220, 120), C(230, 230, 222), C(200, 120, 200) })[(i % 4) + 1], M.SmoothPlastic, { Shape = Enum.PartType.Ball })
	end
	for i = 1, 5 do
		local p = base + n * 0.8 + right * (-4 + i * 1.6) + Vector3.new(0, rng:NextNumber(6.5, 8.5), 0)
		local b = P(g, "Balloon", Vector3.new(1.3, 1.5, 1.3), CFrame.new(p), ({ C(214, 170, 62), C(220, 220, 210), C(160, 60, 160), C(40, 74, 170) })[(i % 4) + 1], M.SmoothPlastic, { Reflectance = 0.15 })
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Parent = b
		local stringLen = p.Y - gy - 1
		local s = P(g, "String", Vector3.new(0.04, stringLen, 0.04), CFrame.new(p.X, gy + 1 + stringLen / 2, p.Z), C(200, 200, 200))
		for _, x in { b, s } do
			x:SetAttribute("Sway", "Flag")
			x:SetAttribute("Hinge", Vector3.new(p.X, gy + 1, p.Z))
			x:SetAttribute("Axis", right)
			CS:AddTag(x, "MTL_Sway")
		end
	end
	local feet = base + n * 4
	spot("Vignette:Memorial", CFrame.lookAt(feet, feet - n), nil, "None")
	return "memorial on " .. host
end

local function welcomeMural(): string
	local types = { Apartments = true, MidRise = true, Shops = true, AutoShop = true, Church = true, House = true, AbandonedHouse = true }
	local WW, WH = 22, 10
	-- players should see it in their first minute: walls within 150 studs of spawn only
	local m, at, n = findWall(WW, WH, types, nil, SPAWN, 150)
	for _, size in { { 16, 10 }, { 14, 8 } } do
		if m then
			break
		end
		WW, WH = size[1], size[2]
		m, at, n = findWall(WW, WH, types, nil, SPAWN, 150)
	end
	local g = group("Mural_WelcomeLiberty")
	local host = if m then m.Name else "a freestanding billboard"
	if not m then
		-- no wall: a painted billboard on a lot edge / the park entrance near spawn
		local site = place(11, SPAWN)
		if not site then
			g:Destroy()
			return "welcome: no wall, no room for a billboard"
		end
		WW, WH = 20, 9
		at, n = freestanding(g, site, WW, WH, C(150, 120, 90))
	end
	assert(at and n)
	local wall = panel(g, "Mural", at, n, WW, WH, PAL.salmon)
	local sg = canvas(wall, 24)
	local sky = frame(sg, { Size = UDim2.fromScale(1, 1), BackgroundColor3 = C(222, 120, 80) })
	local grad = Instance.new("UIGradient")
	grad.Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, C(60, 40, 110)), ColorSequenceKeypoint.new(0.45, C(200, 80, 120)), ColorSequenceKeypoint.new(0.8, C(234, 150, 80)), ColorSequenceKeypoint.new(1, C(236, 196, 110)) })
	grad.Rotation = 90
	grad.Parent = sky
	local sun = frame(sky, { Size = UDim2.fromScale(0.26, 0.55), Position = UDim2.fromScale(0.37, 0.42), BackgroundColor3 = C(240, 200, 110) })
	round(sun, 999)
	local sea = frame(sky, { Size = UDim2.fromScale(1, 0.24), Position = UDim2.fromScale(0, 0.76), BackgroundColor3 = C(50, 80, 130) })
	local sg2 = Instance.new("UIGradient")
	sg2.Color = ColorSequence.new(C(80, 110, 150), C(30, 50, 90))
	sg2.Rotation = 90
	sg2.Parent = sea
	-- palm silhouettes: trunk + fronds
	for _, x in { 0.08, 0.86 } do
		local trunk = frame(sky, { Size = UDim2.fromScale(0.025, 0.62), Position = UDim2.fromScale(x, 0.36), BackgroundColor3 = C(30, 20, 40) })
		trunk.Rotation = if x < 0.5 then 6 else -6
		for k = 0, 4 do
			local frond = frame(sky, { Size = UDim2.fromScale(0.12, 0.035), Position = UDim2.fromScale(x - 0.05, 0.33), BackgroundColor3 = C(30, 20, 40), AnchorPoint = Vector2.new(0.5, 0.5) })
			frond.Rotation = -60 + k * 30
			round(frond, 20)
		end
	end
	local title = text(sky, "WELCOME TO", { Font = Enum.Font.Fondamento, TextColor3 = PAL.cream, Size = UDim2.fromScale(0.5, 0.14), Position = UDim2.fromScale(0.25, 0.06) })
	stroke(title, C(60, 30, 60), 2)
	local big = text(sky, "LIBERTY HEIGHTS", { Font = Enum.Font.Bangers, TextColor3 = C(240, 214, 120), Size = UDim2.fromScale(0.9, 0.26), Position = UDim2.fromScale(0.05, 0.18) })
	stroke(big, C(70, 20, 60), 4)
	local art = Instance.new("ImageLabel")
	art.Name = "ArtSlot" -- TODO(Alex art): a decal id here replaces the painted mural
	art.BackgroundTransparency = 1
	art.Size = UDim2.fromScale(1, 1)
	art.Image = ""
	art.Parent = sky
	return "welcome mural on " .. host
end

local function handprints(): string
	local m, at, n = findWall(10, 3, { House = true, Apartments = true, Church = true, Shops = true }, 1)
	if not m or not at or not n then
		return "handprints: no wall"
	end
	local g = group("Mural_Handprints")
	local wall = panel(g, "Mural", at, n, 10, 3, PAL.cream)
	local sg = canvas(wall, 40)
	local bg = frame(sg, { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 })
	local cols = { C(200, 60, 70), C(60, 120, 200), C(240, 190, 60), C(70, 160, 90), C(160, 80, 180), C(230, 120, 60) }
	for i = 1, 26 do
		local c = cols[rng:NextInteger(1, #cols)]
		local x, y = rng:NextNumber(0.02, 0.92), rng:NextNumber(0.05, 0.6)
		local palm = frame(bg, { Size = UDim2.fromScale(0.05, 0.22), Position = UDim2.fromScale(x, y + 0.12), BackgroundColor3 = c })
		round(palm, 10)
		palm.Rotation = rng:NextNumber(-25, 25)
		for f = 0, 3 do
			local finger = frame(palm, { Size = UDim2.fromScale(0.2, 0.55), Position = UDim2.fromScale(0.04 + f * 0.25, -0.45), BackgroundColor3 = c })
			round(finger, 8)
		end
	end
	text(bg, "LIBERTY KIDS 2026 ♥", { Font = Enum.Font.Fondamento, TextColor3 = C(60, 40, 60), Size = UDim2.fromScale(0.6, 0.2), Position = UDim2.fromScale(0.2, 0.78) })
	return "handprints on " .. m.Name
end

---------------------------------------------------------------- 4. church marquee

local function marquee(): string
	local churches = homesNearSpawn({ Church = true })
	local ch = churches[1]
	if not ch then
		return "marquee: no church"
	end
	local fp = ch:FindFirstChild("Footprint") :: BasePart?
	local frameCF = if fp then fp.CFrame else ch:GetPivot()
	local f = Vector3.new(frameCF.LookVector.X, 0, frameCF.LookVector.Z).Unit -- lot front faces the street (local -Z)
	local depth = if fp then fp.Size.Z / 2 else 20
	-- try spots along the front edge, inside the lot, clear of everything
	for _, inset in { 3, 5, 7, 9 } do
		for _, u in { 0, -10, 10, -16, 16 } do
			local right = f:Cross(Vector3.yAxis).Unit
			local p = frameCF.Position + f * (depth - inset) + right * u
			local gy = ground(p)
			local box = CFrame.new(p.X, gy + 4.5, p.Z)
			if clear(box, Vector3.new(11, 8, 3)) and free(p, 7) then
				claim(p, 7)
				local g = group("ChurchMarquee")
				local look = CFrame.lookAt(Vector3.new(p.X, gy, p.Z), Vector3.new(p.X, gy, p.Z) + f)
				for _, x in { -4.6, 4.6 } do
					P(g, "Post", Vector3.new(0.6, 6.5, 0.6), look * CFrame.new(x, 3.25, 0), PAL.dirty, M.Brick)
				end
				P(g, "Base", Vector3.new(10.6, 1, 1.4), look * CFrame.new(0, 0.5, 0), PAL.dirty, M.Brick)
				local board = P(g, "Board", Vector3.new(9.6, 4.6, 0.4), look * CFrame.new(0, 4.6, 0), C(32, 30, 34))
				local front = P(g, "Face", Vector3.new(9.2, 4.2, 0.05), look * CFrame.new(0, 4.6, -0.23), PAL.white, M.SmoothPlastic, { CastShadow = false })
				local sg = gui(front, 40)
				local top = frame(sg, { Size = UDim2.fromScale(1, 0.26), BackgroundColor3 = C(110, 40, 50) })
				text(top, "KINGDOM OF FAITH CHURCH", { Font = Enum.Font.Fondamento, TextColor3 = C(236, 210, 140), Size = UDim2.fromScale(0.96, 0.8), Position = UDim2.fromScale(0.02, 0.1) })
				text(sg, "SIN IS LIKE A BAD TAN.", { Font = Enum.Font.Arcade, TextColor3 = C(28, 26, 30), Size = UDim2.fromScale(0.94, 0.22), Position = UDim2.fromScale(0.03, 0.33) })
				text(sg, "COME GET THIS SHADE", { Font = Enum.Font.Arcade, TextColor3 = C(28, 26, 30), Size = UDim2.fromScale(0.94, 0.22), Position = UDim2.fromScale(0.03, 0.58) })
				text(sg, "SUN 10AM  WED 7PM  ALL WELCOME", { Font = Enum.Font.GothamBold, TextColor3 = C(110, 40, 50), Size = UDim2.fromScale(0.9, 0.12), Position = UDim2.fromScale(0.05, 0.85) })
				addLight(board, C(255, 236, 200), 10, 0.8)
				-- church ladies chatting by the sign
				local right2 = f:Cross(Vector3.yAxis).Unit
				local a = Vector3.new(p.X, gy, p.Z) + f * 3 + right2 * 6
				local b = a + right2 * 2.4
				spot("Vignette:Church", CFrame.lookAt(a, b), nil, "None")
				spot("Vignette:Church", CFrame.lookAt(b, a), nil, "None")
				return "marquee at church"
			end
		end
	end
	return "marquee: no room"
end

---------------------------------------------------------------- 5. wires, sneakers, flyers

local function wires(): string
	local g = group("PowerLines")
	local n = 0
	for i, s in Map.Spans or {} do
		local a, b = Vector3.new(s[1], s[2], s[3]), Vector3.new(s[4], s[5], s[6])
		local dir = (b - a)
		local side = Vector3.new(-dir.Z, 0, dir.X).Unit
		for k = -1, 1 do
			local off = side * (k * 3)
			local prev = a + off
			local segs = 6
			for j = 1, segs do
				local t = j / segs
				local sag = 4 * 1.2 * t * (1 - t) -- 1.2 studs at mid-span
				local pnt = a:Lerp(b, t) + off - Vector3.new(0, sag, 0)
				local len = (pnt - prev).Magnitude
				P(g, "Wire", Vector3.new(0.08, 0.08, len), CFrame.lookAt((prev + pnt) / 2, pnt), C(24, 24, 26), M.SmoothPlastic, { CastShadow = false })
				prev = pnt
			end
		end
		n += 1
		if i == 2 then
			-- sneakers on a power line: two shoes hanging by their laces off the middle strand
			local mid = a:Lerp(b, 0.45) - Vector3.new(0, 4 * 1.2 * 0.45 * 0.55, 0)
			for _, sx in { -0.5, 0.5 } do
				local top = mid + side * sx
				P(g, "Lace", Vector3.new(0.05, 1.6, 0.05), CFrame.new(top - Vector3.new(0, 0.8, 0)), PAL.white, M.Fabric, { CastShadow = false })
				local shoe = P(g, "Sneaker", Vector3.new(0.6, 0.55, 1.3), CFrame.new(top - Vector3.new(0, 1.9, 0)) * CFrame.Angles(math.rad(70), 0, 0), C(222, 218, 210), M.SmoothPlastic, { CastShadow = false })
				P(g, "Sole", Vector3.new(0.62, 0.15, 1.32), shoe.CFrame * CFrame.new(0, -0.3, 0), C(170, 40, 46), M.SmoothPlastic, { CastShadow = false })
				for _, x in { shoe } do
					x:SetAttribute("Sway", "Flag")
					x:SetAttribute("Hinge", top)
					CS:AddTag(x, "MTL_Sway")
				end
			end
		end
		if i % 8 == 0 then
			task.wait()
		end
	end
	return n .. " power-line spans"
end

local FLYERS = {
	{ "LOST DOG", "BROWNIE\nlittle brown pit mix\nCALL 305-555-0142", C(225, 220, 205), C(170, 40, 46) },
	{ "BLOCK PARTY", "SAT 2PM\nLIBERTY PARK\nDJ - FOOD - BOUNCE HOUSE", C(240, 200, 90), C(40, 40, 120) },
	{ "WE BUY HOUSES", "CASH FAST\nANY CONDITION\n305-555-0199", C(225, 220, 205), C(30, 90, 50) },
	{ "BRAIDS $60", "KNOTLESS - BOX\nCALL KEISHA\n305-555-0177", C(230, 160, 190), C(60, 30, 60) },
	{ "PRAYER NIGHT", "KINGDOM OF FAITH\nWED 7PM", C(200, 220, 240), C(40, 60, 120) },
	{ "TUTORING", "MATH - READING\n$15/HR  ASK 4 MS. JONES", C(200, 230, 200), C(40, 70, 40) },
}

local function flyers(): string
	-- the utility poles nearest spawn: a flyer or two at eye level on the side facing the sidewalk
	local poles = {}
	for _, m in VB.Roads:GetChildren() do
		local pv = m:GetPivot().Position
		if (pv - SPAWN).Magnitude < 700 then
			for _, c in m:GetChildren() do
				if c.Name == "UtilityPole" and c:IsA("BasePart") then
					table.insert(poles, c)
				end
			end
		end
	end
	table.sort(poles, function(a, b)
		return (a.Position - SPAWN).Magnitude < (b.Position - SPAWN).Magnitude
	end)
	local g = group("Flyers")
	local n = 0
	for i, pole in poles do
		if i > 18 then
			break
		end
		local gy = ground(pole.Position)
		local r = math.min(pole.Size.Y, pole.Size.Z) / 2
		for k = 1, (if i % 3 == 0 then 2 else 1) do
			local def = FLYERS[((i + k) % #FLYERS) + 1]
			local ang = math.rad(rng:NextNumber(0, 360))
			local nrm = Vector3.new(math.cos(ang), 0, math.sin(ang))
			local at = Vector3.new(pole.Position.X, gy + 5.2 + k * 1.6, pole.Position.Z) + nrm * r
			local paper = panel(g, "Flyer", at, nrm, 1.1, 1.45, def[3])
			paper.CFrame *= CFrame.Angles(0, 0, math.rad(rng:NextNumber(-6, 6)))
			local sg = gui(paper, 90)
			text(sg, def[1], { Font = Enum.Font.GothamBlack, TextColor3 = def[4], Size = UDim2.fromScale(0.92, 0.26), Position = UDim2.fromScale(0.04, 0.04) })
			text(sg, def[2], { Font = Enum.Font.GothamMedium, TextColor3 = C(30, 30, 34), Size = UDim2.fromScale(0.9, 0.6), Position = UDim2.fromScale(0.05, 0.34) })
			n += 1
		end
	end
	return n .. " flyers"
end

---------------------------------------------------------------- 6. laundry

local CLOTHES = { C(222, 160, 140), C(160, 200, 175), C(140, 175, 200), C(222, 214, 192), C(205, 200, 190), C(178, 44, 46), C(214, 170, 62), C(70, 74, 120) }

local function laundry(): string
	local g = group("Laundry")
	local lines = 0
	for _, m in homesNearSpawn({ Apartments = true, MidRise = true, House = true }) do
		if lines >= 6 then
			break
		end
		local fp = m:FindFirstChild("Footprint") :: BasePart?
		local frameCF = if fp then fp.CFrame else m:GetPivot()
		local gy = ground(frameCF.Position)
		for _, side in { frameCF.RightVector, -frameCF.RightVector } do
			if lines >= 6 then
				break
			end
			side = Vector3.new(side.X, 0, side.Z).Unit
			-- from our own wall out to a neighbour's wall 8-26 studs away, at second-floor height
			local h = gy + 11
			local mine = wallHit(m, frameCF.Position + side * 80 + Vector3.new(0, h - frameCF.Y, 0), -side * 160)
			if mine then
				local params = RaycastParams.new()
				params.FilterType = Enum.RaycastFilterType.Exclude
				params.FilterDescendantsInstances = { m, root }
				local other = workspace:Raycast(mine.Position + side * 0.2, side * 26, params)
				if other and (other.Position - mine.Position).Magnitude > 8 and other.Normal:Dot(-side) > 0.9
					and other.Instance:FindFirstAncestorWhichIsA("Model") and free(mine.Position, 2) then
					local a, b = mine.Position + side * 0.1, other.Position - side * 0.1
					claim((a + b) / 2, 3)
					local len = (b - a).Magnitude
					P(g, "Line", Vector3.new(0.06, 0.06, len), CFrame.lookAt((a + b) / 2 - Vector3.new(0, 0.5, 0), b - Vector3.new(0, 0.5, 0)), C(210, 206, 196), M.SmoothPlastic, { CastShadow = false })
					local dir = (b - a).Unit
					local t = 1.8
					while t < len - 1.8 do
						local w = rng:NextNumber(1.2, 2.2)
						local hh = rng:NextNumber(1.4, 2.6)
						local top = a + dir * (t + w / 2) - Vector3.new(0, 0.5 + 0.35 * math.sin(math.pi * (t / len)), 0)
						local cloth = P(g, "Cloth", Vector3.new(w, hh, 0.08), CFrame.lookAt(top - Vector3.new(0, hh / 2, 0), top - Vector3.new(0, hh / 2, 0) + side) * CFrame.Angles(0, math.rad(90), 0), CLOTHES[rng:NextInteger(1, #CLOTHES)], M.Fabric, { CastShadow = false })
						cloth:SetAttribute("Sway", "Laundry")
						cloth:SetAttribute("Hinge", top)
						cloth:SetAttribute("Axis", dir)
						CS:AddTag(cloth, "MTL_Sway")
						t += w + rng:NextNumber(0.4, 1.4)
					end
					lines += 1
				end
			end
		end
	end
	return lines .. " laundry lines"
end

---------------------------------------------------------------- 7. vignettes

-- yard / lot candidates near spawn: house front yards (between the facade and the lot's front edge) + Liberty Park
local function sites(r: number): { CFrame }
	local out = {}
	for _, m in homesNearSpawn({ House = true, Apartments = true, AbandonedHouse = true, MidRise = true }) do
		local fp = m:FindFirstChild("Footprint") :: BasePart?
		if fp then
			local f = Vector3.new(fp.CFrame.LookVector.X, 0, fp.CFrame.LookVector.Z).Unit
			local right = f:Cross(Vector3.yAxis).Unit
			local edge = fp.Position + f * (fp.Size.Z / 2)
			-- front yard: between the facade and the lot's street edge
			local hit = wallHit(m, edge + Vector3.new(0, 4, 0), -f * fp.Size.Z)
			if hit then
				local yard = (edge - hit.Position):Dot(f)
				if yard > 2 * r + 1 then
					for _, u in { fp.Size.X / 4, -fp.Size.X / 4, 0 } do
						local p = hit.Position + f * (yard / 2) + right * u
						table.insert(out, CFrame.lookAt(Vector3.new(p.X, 0, p.Z), Vector3.new(p.X, 0, p.Z) + f))
					end
				end
			end
			-- side yards / the lot beside the house: between the side wall and the lot edge
			for _, sgn in { -1, 1 } do
				local sideEdge = fp.Position + right * sgn * (fp.Size.X / 2)
				local sh = wallHit(m, sideEdge + Vector3.new(0, 4, 0), -right * sgn * fp.Size.X)
				if sh then
					local gap = (sideEdge - sh.Position):Dot(right * sgn)
					if gap > 2 * r + 1 then
						local p = sh.Position + right * sgn * (gap / 2) + f * 4
						table.insert(out, CFrame.lookAt(Vector3.new(p.X, 0, p.Z), Vector3.new(p.X, 0, p.Z) + f))
					end
				end
			end
		end
	end
	-- the park: a ring round its centre and one round its edge
	for _, rad in { 16, 30 } do
		for k = 0, 11 do
			local a = k * math.pi / 6
			local p = Vector3.new(-1580 + math.cos(a) * rad, 0, -200 + math.sin(a) * rad)
			table.insert(out, CFrame.lookAt(p, p + Vector3.new(-math.cos(a), 0, -math.sin(a))))
		end
	end
	-- the alleys behind the shop rows: 8 studs off the alley centre line (the clearance test throws out bad ones)
	for _, z in Map.Zones do
		if z[1] == "Alley" then
			local p = Vector3.new(z[2], 0, z[4])
			for _, off in { Vector3.new(0, 0, 8), Vector3.new(0, 0, -8), Vector3.new(8, 0, 0), Vector3.new(-8, 0, 0) } do
				table.insert(out, CFrame.lookAt(p + off, p))
			end
		end
	end
	-- sidewalk corners (the Corner spots) near Food Mart and spawn
	for _, sp in Map.Spots do
		if sp[1] == "Corner" then
			table.insert(out, CFrame.new(sp[2], 0, sp[4]) * CFrame.Angles(0, math.rad(sp[5]), 0))
		end
	end
	return out
end

place = function(r: number, prefer: Vector3?, avoid: Vector3?): CFrame?
	local list = sites(r)
	if avoid then
		local keep = {}
		for _, cf in list do
			if (cf.Position - Vector3.new(avoid.X, 0, avoid.Z)).Magnitude > 70 then
				table.insert(keep, cf)
			end
		end
		list = keep
	end
	if prefer then
		table.sort(list, function(a, b)
			return (a.Position - prefer).Magnitude < (b.Position - prefer).Magnitude
		end)
	end
	for _, cf in list do
		local p = cf.Position
		local gy = ground(Vector3.new(p.X, 10, p.Z))
		local at = CFrame.new(p.X, gy, p.Z) * cf.Rotation
		if free(at.Position, r, true) and clear(at * CFrame.new(0, 3.2, 0), Vector3.new(2 * r, 6, 2 * r)) then
			claim(at.Position, r, true)
			return at
		end
	end
	return nil
end

local function chair(g: Model, cf: CFrame, color: Color3)
	-- folding chair: seat top 1.5 over the ground (the sit pose drops the hips there)
	P(g, "Seat", Vector3.new(1.6, 0.15, 1.5), cf * CFrame.new(0, 1.45, 0), color)
	P(g, "Back", Vector3.new(1.6, 1.4, 0.12), cf * CFrame.new(0, 2.2, 0.72), color)
	for _, x in { -0.7, 0.7 } do
		P(g, "Leg", Vector3.new(0.1, 1.45, 0.1), cf * CFrame.new(x, 0.72, -0.6) * CFrame.Angles(math.rad(-12), 0, 0), PAL.metal, M.Metal)
		P(g, "Leg", Vector3.new(0.1, 1.45, 0.1), cf * CFrame.new(x, 0.72, 0.6) * CFrame.Angles(math.rad(12), 0, 0), PAL.metal, M.Metal)
	end
end

local function domino(): string
	local at = place(6, SPAWN + Vector3.new(-30, 0, -120))
	if not at then
		return "domino: no room"
	end
	local g = group("Vignette_Domino")
	-- a shade tree over the table
	P(g, "Trunk", Vector3.new(1.4, 12, 1.4), at * CFrame.new(5, 6, 3), C(96, 70, 48), M.Wood)
	for _, o in { Vector3.new(5, 13, 3), Vector3.new(3, 12, 1), Vector3.new(7, 12.5, 4), Vector3.new(4.5, 14, 5) } do
		P(g, "Leaves", Vector3.new(7, 5, 7), at * CFrame.new(o) * CFrame.Angles(0, rng:NextNumber(0, 3), 0), C(70, 110, 60), M.Grass, { Shape = Enum.PartType.Ball, CastShadow = true })
	end
	P(g, "Top", Vector3.new(3.4, 0.2, 3.4), at * CFrame.new(0, 2.6, 0), C(40, 90, 60), M.Fabric)
	P(g, "Leg", Vector3.new(0.4, 2.5, 0.4), at * CFrame.new(0, 1.25, 0), PAL.dark, M.Metal)
	for i = 1, 14 do
		P(g, "Domino", Vector3.new(0.22, 0.06, 0.44), at * CFrame.new(rng:NextNumber(-1, 1), 2.73, rng:NextNumber(-1, 1)) * CFrame.Angles(0, rng:NextNumber(0, 3), 0), PAL.white, M.SmoothPlastic, { CastShadow = false })
	end
	P(g, "Cup", Vector3.new(0.3, 0.4, 0.3), at * CFrame.new(1.4, 2.9, 1.3), C(170, 40, 46), M.SmoothPlastic, { CastShadow = false })
	for k = 0, 3 do
		local a = k * math.pi / 2
		local seat = at * CFrame.Angles(0, a, 0) * CFrame.new(0, 0, 2.6)
		chair(g, seat, if k % 2 == 0 then C(200, 170, 120) else C(70, 90, 130))
		-- the old head sits facing the table
		spot("Vignette:Domino", seat * CFrame.Angles(0, 0, 0), nil, "SitType")
	end
	return "domino table"
end

local function blocksCar(): string
	local sedan = SS:FindFirstChild("VBAssets") and SS.VBAssets:FindFirstChild("SedanA")
	if not sedan then
		return "car on blocks: no SedanA"
	end
	local at = place(8, SPAWN + Vector3.new(150, 0, 60))
	if not at then
		return "car on blocks: no room"
	end
	local g = group("Vignette_CarOnBlocks")
	local car = sedan:Clone()
	-- the SedanA's front is +Z: face it toward the street with 0.9 studs of cinder block under it
	local cf, size = car:GetBoundingBox()
	local pivotToBottom = car:GetPivot():ToObjectSpace(cf * CFrame.new(0, -size.Y / 2, 0))
	car:PivotTo(at * CFrame.Angles(0, math.pi, 0) * CFrame.new(0, 0.9, 0) * pivotToBottom:Inverse())
	local paint = C(110, 30, 34)
	for _, d in car:GetDescendants() do
		if d:IsA("BaseScript") or d:IsA("Seat") or d:IsA("VehicleSeat") then
			d:Destroy()
		elseif d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
			d.CanTouch = false
			d.CanQuery = false
			if d.Name == "Color" then
				d.Color = paint:Lerp(C(150, 140, 130), 0.35) -- sun-faded
				d.Material = M.SmoothPlastic
			elseif d.Name == "Tire" or d.Name == "Rim" then
				d.Transparency = 1 -- wheels off, it's on blocks
			end
		end
	end
	car.Parent = g
	local front = at.LookVector
	for _, x in { -3.2, 3.2 } do
		for _, z in { -6.5, 6.5 } do
			P(g, "Block", Vector3.new(1.2, 0.9, 1.6), at * CFrame.new(x, 0.45, z), C(150, 148, 142), M.Concrete)
		end
	end
	-- the hood, propped open over the engine
	P(g, "Hood", Vector3.new(6.6, 0.15, 5.2), at * CFrame.new(0, 5.6, -8.6) * CFrame.Angles(math.rad(62), 0, 0), paint:Lerp(C(150, 140, 130), 0.35))
	P(g, "Prop", Vector3.new(0.08, 2.4, 0.08), at * CFrame.new(1.8, 4.6, -7.6), PAL.metal, M.Metal, { CastShadow = false })
	-- tyres stacked, toolbox, jack
	for k = 0, 1 do
		P(g, "Tyre", Vector3.new(0.9, 2.5, 2.5), at * CFrame.new(-5.5, 0.45 + k * 0.92, 2) * CFrame.Angles(0, 0, math.rad(90)), C(26, 26, 28), M.Rubber, { Shape = Enum.PartType.Cylinder })
	end
	P(g, "Toolbox", Vector3.new(1.8, 0.9, 0.8), at * CFrame.new(3.8, 0.45, -9.5), C(170, 40, 46), M.Metal)
	P(g, "Jack", Vector3.new(0.8, 0.5, 2), at * CFrame.new(-4.2, 0.25, -9), C(214, 170, 62), M.Metal)
	-- the mechanic bent over the engine
	local stand = at * CFrame.new(0, 0, -11.2)
	spot("Vignette:Mechanic", CFrame.lookAt(stand.Position, stand.Position + front * -1), nil, "Lean")
	return "car on blocks"
end

local function bbq(): string
	local at = place(6, SPAWN + Vector3.new(-180, 0, -60))
	if not at then
		return "bbq: no room"
	end
	local g = group("Vignette_BBQ")
	local grill = at * CFrame.new(0, 0, -1.5)
	P(g, "Drum", Vector3.new(3, 1.4, 1.4), grill * CFrame.new(0, 2.6, 0) * CFrame.Angles(0, 0, math.rad(90)), C(30, 30, 32), M.Metal, { Shape = Enum.PartType.Cylinder })
	local lid = P(g, "Lid", Vector3.new(3, 0.1, 1.4), grill * CFrame.new(0, 3.4, 0.9) * CFrame.Angles(math.rad(70), 0, 0), C(30, 30, 32), M.Metal)
	for _, x in { -1.2, 1.2 } do
		P(g, "Leg", Vector3.new(0.15, 2, 0.15), grill * CFrame.new(x, 1, 0), C(30, 30, 32), M.Metal)
	end
	local coals = P(g, "Coals", Vector3.new(2.6, 0.1, 1), grill * CFrame.new(0, 3.2, 0), C(255, 110, 40), M.Neon, { CastShadow = false })
	local smoke = Instance.new("ParticleEmitter")
	smoke.Texture = "rbxasset://textures/particles/smoke_main.dds"
	smoke.Rate = 6
	smoke.Lifetime = NumberRange.new(3, 4.5) -- rate x lifetime ~ 25 (budget ~200)
	smoke.Speed = NumberRange.new(2, 3.5)
	smoke.SpreadAngle = Vector2.new(12, 12)
	smoke.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.8), NumberSequenceKeypoint.new(1, 4.5) })
	smoke.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.55), NumberSequenceKeypoint.new(1, 1) })
	smoke.Color = ColorSequence.new(C(200, 196, 190))
	smoke.Acceleration = Vector3.new(1.2, 0.6, 0)
	smoke.LightInfluence = 1
	smoke.Parent = coals
	addLight(coals, C(255, 130, 60), 8, 0.8)
	-- cooler + folding chairs
	local cooler = P(g, "Cooler", Vector3.new(2.2, 1.3, 1.3), at * CFrame.new(3.4, 0.65, 0.5), C(40, 90, 170))
	P(g, "CoolerLid", Vector3.new(2.25, 0.25, 1.35), cooler.CFrame * CFrame.new(0, 0.75, 0), C(225, 220, 205))
	local c1 = at * CFrame.new(-3, 0, 2.6) * CFrame.Angles(0, math.rad(200), 0)
	local c2 = at * CFrame.new(2.6, 0, 3.4) * CFrame.Angles(0, math.rad(160), 0)
	chair(g, c1, C(200, 60, 60))
	chair(g, c2, C(60, 140, 120))
	spot("Vignette:BBQ", c1, nil, "Sit")
	spot("Vignette:BBQ", c2, nil, "SitPhone")
	-- the grill master, flipping
	local stand = at * CFrame.new(0, 0, 0.4)
	spot("Vignette:BBQ", CFrame.lookAt(stand.Position, grill.Position), nil, "None")
	spot("Grill", grill, nil, nil)
	return "bbq"
end

local function hoop(): string
	-- a driveway / side lot (the park already has a real court)
	local at = place(6, SPAWN + Vector3.new(-90, 0, 140), Vector3.new(-1580, 0, -200))
	if not at then
		return "hoop: no room"
	end
	local g = group("Vignette_CrateHoop")
	local post = at * CFrame.new(0, 0, -6)
	P(g, "Post", Vector3.new(0.7, 11, 0.7), post * CFrame.new(0, 5.5, 0), C(96, 76, 56), M.Wood)
	P(g, "Board", Vector3.new(3.6, 2.6, 0.25), post * CFrame.new(0, 10.6, 0.5), C(200, 196, 186), M.WoodPlanks)
	-- the milk crate with its bottom knocked out
	local crate = post * CFrame.new(0, 9.6, 1.6)
	for _, x in { -0.75, 0.75 } do
		P(g, "Crate", Vector3.new(0.1, 1.1, 1.5), crate * CFrame.new(x, 0, 0), C(200, 60, 50), M.Plastic, { CastShadow = false })
	end
	for _, z in { -0.75, 0.75 } do
		P(g, "Crate", Vector3.new(1.5, 1.1, 0.1), crate * CFrame.new(0, 0, z), C(200, 60, 50), M.Plastic, { CastShadow = false })
	end
	P(g, "Ball", Vector3.new(1.2, 1.2, 1.2), at * CFrame.new(1.4, 0.6, -2), C(200, 100, 40), M.Rubber, { Shape = Enum.PartType.Ball })
	-- painted free-throw line
	P(g, "Line", Vector3.new(4, 0.05, 0.3), at * CFrame.new(0, 0.03, -0.5), C(214, 210, 196), M.SmoothPlastic, { CastShadow = false })
	spot("Vignette:Hoop", CFrame.lookAt((at * CFrame.new(-1.5, 0, 0)).Position, post.Position), nil, "None")
	spot("Vignette:Hoop", CFrame.lookAt((at * CFrame.new(2.5, 0, 1)).Position, post.Position), nil, "None")
	spot("Vignette:Hoop", CFrame.lookAt((at * CFrame.new(5.5, 0, -3)).Position, (at * CFrame.new(0, 0, -1)).Position), nil, "Cross")
	spot("Ball", post, nil, nil)
	return "milk-crate hoop"
end

local function yardSale(): string
	local at = place(5, SPAWN + Vector3.new(60, 0, 200))
	if not at then
		return "yard sale: no room"
	end
	local g = group("Vignette_YardSale")
	P(g, "Table", Vector3.new(6, 0.2, 2.4), at * CFrame.new(0, 2.5, 0), C(200, 196, 186), M.Plastic)
	for _, x in { -2.6, 2.6 } do
		P(g, "Leg", Vector3.new(0.15, 2.4, 2), at * CFrame.new(x, 1.2, 0), PAL.metal, M.Metal)
	end
	local stuff = { C(170, 40, 46), C(40, 74, 140), C(214, 170, 62), C(160, 200, 175), C(110, 76, 50), C(60, 60, 64) }
	for i = 1, 9 do
		local s = Vector3.new(rng:NextNumber(0.4, 1), rng:NextNumber(0.2, 0.9), rng:NextNumber(0.4, 0.9))
		P(g, "Item", s, at * CFrame.new(-2.6 + i * 0.55, 2.6 + s.Y / 2, rng:NextNumber(-0.6, 0.6)) * CFrame.Angles(0, rng:NextNumber(0, 3), 0), stuff[(i % #stuff) + 1], M.SmoothPlastic, { CastShadow = false })
	end
	local sign = P(g, "Sign", Vector3.new(3, 1.6, 0.1), at * CFrame.new(-4.2, 1.6, -0.6) * CFrame.Angles(math.rad(-15), 0, 0), C(222, 214, 192), M.Cardboard)
	text(gui(sign, 60), "YARD SALE\n$1 - $5", { Font = Enum.Font.PermanentMarker, TextColor3 = C(170, 40, 46) })
	local seat = at * CFrame.new(0, 0, 2.6) * CFrame.Angles(0, math.pi, 0)
	chair(g, seat * CFrame.Angles(0, math.pi, 0), C(200, 196, 186))
	spot("Vignette:YardSale", seat * CFrame.Angles(0, math.pi, 0), nil, "SitPhone")
	local shopper = at * CFrame.new(1.5, 0, -2.4)
	spot("Vignette:YardSale", CFrame.lookAt(shopper.Position, at.Position), nil, "None")
	return "yard sale"
end

local function dogFence(): string
	local at = place(5, SPAWN + Vector3.new(-120, 0, 180))
	if not at then
		return "dog fence: no room"
	end
	local g = group("Vignette_BewareOfDog")
	-- chain-link fence section along the yard's street side
	local fence = at * CFrame.new(0, 0, -4)
	for _, x in { -5, 0, 5 } do
		P(g, "Post", Vector3.new(0.25, 4.6, 0.25), fence * CFrame.new(x, 2.3, 0), PAL.metal, M.Metal)
	end
	P(g, "Rail", Vector3.new(10.2, 0.15, 0.15), fence * CFrame.new(0, 4.5, 0), PAL.metal, M.Metal, { CastShadow = false })
	P(g, "Mesh", Vector3.new(10, 4.2, 0.05), fence * CFrame.new(0, 2.25, 0), C(150, 152, 156), M.DiamondPlate, { Transparency = 0.55, CastShadow = false })
	local sign = P(g, "Sign", Vector3.new(2.2, 1.2, 0.06), fence * CFrame.new(1.6, 3, -0.08), C(214, 170, 62), M.Metal, { CastShadow = false })
	text(gui(sign, 60), "BEWARE\nOF DOG", { Font = Enum.Font.GothamBlack, TextColor3 = C(28, 26, 30) })
	-- the dog: a stocky brown pit, sitting guard, tail wagging (sway)
	local d = at * CFrame.new(-1.5, 0, -1.5) * CFrame.Angles(0, math.pi, 0)
	local fur = C(122, 84, 56)
	P(g, "Body", Vector3.new(1.3, 1.3, 2.4), d * CFrame.new(0, 1.35, 0.2) * CFrame.Angles(math.rad(-20), 0, 0), fur, M.SmoothPlastic)
	P(g, "Head", Vector3.new(1.1, 1, 1.1), d * CFrame.new(0, 2.4, -0.9), fur)
	P(g, "Snout", Vector3.new(0.7, 0.5, 0.6), d * CFrame.new(0, 2.2, -1.65), fur:Lerp(C(40, 30, 26), 0.4))
	P(g, "Nose", Vector3.new(0.25, 0.2, 0.1), d * CFrame.new(0, 2.35, -1.96), C(26, 22, 22), M.SmoothPlastic, { CastShadow = false })
	for _, x in { -0.4, 0.4 } do
		P(g, "Ear", Vector3.new(0.3, 0.4, 0.15), d * CFrame.new(x, 3, -0.9) * CFrame.Angles(0, 0, math.rad(x * 40)), fur:Lerp(C(40, 30, 26), 0.3), M.SmoothPlastic, { CastShadow = false })
		P(g, "Leg", Vector3.new(0.35, 1.2, 0.35), d * CFrame.new(x, 0.6, -0.6), fur)
		P(g, "Haunch", Vector3.new(0.5, 0.6, 0.9), d * CFrame.new(x * 1.3, 0.3, 0.9), fur)
	end
	P(g, "Collar", Vector3.new(1.15, 0.2, 1.15), d * CFrame.new(0, 1.95, -0.85), C(170, 40, 46), M.SmoothPlastic, { CastShadow = false })
	local tailBase = (d * CFrame.new(0, 1, 1.4)).Position
	local tail = P(g, "Tail", Vector3.new(0.18, 0.18, 1), d * CFrame.new(0, 1.15, 1.85) * CFrame.Angles(math.rad(25), 0, 0), fur, M.SmoothPlastic, { CastShadow = false })
	tail:SetAttribute("Sway", "Flag")
	tail:SetAttribute("Hinge", tailBase)
	tail:SetAttribute("Axis", Vector3.yAxis)
	CS:AddTag(tail, "MTL_Sway")
	spot("Dog", d, nil, nil)
	return "beware of dog"
end

local function carts(): string
	local g = group("ShoppingCarts")
	local n = 0
	local spotsFor = { Vector3.new(-1428, 3, -326), Vector3.new(-1458, 3, -334), Vector3.new(-1300, 3, -553) }
	for i, p in spotsFor do
		local gy = ground(p)
		local base = CFrame.new(p.X, gy, p.Z) * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0)
		if i == 3 then
			base *= CFrame.new(0, 1.2, 0) * CFrame.Angles(0, 0, math.rad(90)) -- one tipped over in the alley
		end
		if clear(base * CFrame.new(0, 2.2, 0), Vector3.new(2.4, 3, 3.6)) or i == 3 then
			local steel = C(150, 152, 156)
			P(g, "Basket", Vector3.new(2, 1.6, 3), base * CFrame.new(0, 2.6, 0), steel, M.DiamondPlate, { Transparency = 0.45, CastShadow = false })
			P(g, "Handle", Vector3.new(2.1, 0.15, 0.15), base * CFrame.new(0, 3.5, 1.7), C(170, 40, 46), M.Plastic, { CastShadow = false })
			P(g, "Frame", Vector3.new(1.8, 0.12, 3), base * CFrame.new(0, 0.9, 0), steel, M.Metal, { CastShadow = false })
			for _, x in { -0.8, 0.8 } do
				for _, z in { -1.3, 1.3 } do
					P(g, "Caster", Vector3.new(0.3, 0.5, 0.5), base * CFrame.new(x, 0.25, z) * CFrame.Angles(0, 0, math.rad(90)), C(30, 30, 32), M.Rubber, { Shape = Enum.PartType.Cylinder, CastShadow = false })
				end
			end
			n += 1
		end
	end
	return n .. " shopping carts"
end

---------------------------------------------------------------- 8. traffic car template

local function carTemplate(): string
	local sedan = SS:FindFirstChild("VBAssets") and SS.VBAssets:FindFirstChild("SedanA")
	if not sedan then
		return "no SedanA template"
	end
	local lib = RS:FindFirstChild("MTL_AmbientCars")
	if lib then
		lib:Destroy()
	end
	local f = Instance.new("Folder")
	f.Name = "MTL_AmbientCars"
	local c = sedan:Clone()
	for _, d in c:GetDescendants() do
		if d:IsA("BaseScript") then
			d:Destroy()
		end
	end
	c.Name = "SedanA"
	c.Parent = f
	f.Parent = RS
	return "car template copied"
end

---------------------------------------------------------------- run

local steps = {
	{ "signs", function()
		return signs() .. " shop signs"
	end },
	{ "marquee", marquee },
	{ "memorial", memorial },
	{ "welcome", welcomeMural },
	{ "handprints", handprints },
	{ "wires", wires },
	{ "flyers", flyers },
	{ "laundry", laundry },
	{ "domino", domino },
	{ "blocksCar", blocksCar },
	{ "bbq", bbq },
	{ "hoop", hoop },
	{ "yardSale", yardSale },
	{ "dogFence", dogFence },
	{ "carts", carts },
	{ "carTemplate", carTemplate },
}
root.Parent = workspace -- parented first: each step adds a small subtree, never one huge insert
for _, s in steps do
	local ok, res = pcall(s[2])
	table.insert(report, s[1] .. ": " .. (if ok then tostring(res) else "FAILED " .. tostring(res)))
	task.wait()
end
root:SetAttribute("Parts", parts)
root:SetAttribute("Lights", lights)

-- send the vignette spots to the survey receiver (tools/survey/dress.json -> build_ambient_map.py)
local was = H.HttpEnabled
H.HttpEnabled = true
local okPost = pcall(function()
	H:PostAsync("http://127.0.0.1:34874/dress", H:JSONEncode({ spots = spots }))
end)
H.HttpEnabled = was
table.insert(report, ("%d parts, %d new lights, %d spots (%s)"):format(parts, lights, #spots, if okPost then "posted" else "NOT posted"))
print("[MTL HoodLife] " .. table.concat(report, " | "))
return table.concat(report, "\n")
