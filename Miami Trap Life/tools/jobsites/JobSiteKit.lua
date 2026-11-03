-- Shared helpers for the job-site interiors (Food Mart, Burger Shack, Westside Auto, the Level 8+/15+ sites).
-- Low-poly realistic, same look as the new hood shops: plain boxes, real materials, colour does the work.
-- Lives in Studio as ServerStorage.MTL_Tools.JobSiteKit (edit-time only, never runs in game).
local SS = game:GetService("ServerStorage")

local K = {}
local C = Color3.fromRGB
local M = Enum.Material
K.C, K.M = C, M

-- Where replaced pieces go (never deleted): ServerStorage.MTL_ReplacedJobSites.<site>, attribute MTL_OriginalParent.
function K.stash(site: string, inst: Instance)
	local root = SS:FindFirstChild("MTL_ReplacedJobSites") or Instance.new("Folder")
	root.Name = "MTL_ReplacedJobSites"
	root.Parent = SS
	local f = root:FindFirstChild(site) or Instance.new("Folder")
	f.Name = site
	f.Parent = root
	if inst.Parent ~= f then
		if inst.Parent then
			inst:SetAttribute("MTL_OriginalParent", inst.Parent:GetFullName())
		end
		inst.Parent = f
	end
end

-- builder bound to one Model. b.P(name, size, cf, color, material, opts). opts.parent = sub-model.
function K.builder(model: Model)
	local b = { model = model, n = 0 }
	function b.P(name, size, cf, color, mat, opts)
		local p = Instance.new("Part")
		p.Name = name
		p.Anchored = true
		p.Size = size
		p.CFrame = cf
		p.Color = color or C(200, 200, 200)
		p.Material = mat or M.SmoothPlastic
		-- lighting rule (Nov 2): no surface brighter than ~200 grey (220 was still too bright in Play), or interiors wash out white. Neon stays as-is.
		if p.Material ~= M.Neon then
			local c = p.Color
			local mx = math.max(c.R, c.G, c.B)
			if mx > 200 / 255 then
				local k = (196 / 255) / mx
				p.Color = Color3.new(c.R * k, c.G * k, c.B * k * 0.97)
			end
		end
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		local parent = model
		if opts then
			for k, v in opts do
				if k == "shape" then
					p.Shape = v
				elseif k == "parent" then
					parent = v
				elseif k == "deco" then
					if v then
						p.CanCollide, p.CanQuery, p.CanTouch = false, false, false
					end
				else
					(p :: any)[k] = v
				end
			end
		end
		p.Parent = parent
		b.n += 1
		return p
	end
	function b.group(name: string, parent: Instance?): Model
		local g = Instance.new("Model")
		g.Name = name
		g.Parent = parent or model
		return g
	end
	return b
end

-- Text on one face of a part. lit = true keeps it bright at night (signs), otherwise it takes the room's light.
function K.sign(part: BasePart, face: Enum.NormalId, text: string, bg: Color3?, fg: Color3?, opts: { [string]: any }?)
	opts = opts or {}
	local g = Instance.new("SurfaceGui")
	g.Face = face
	g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	g.PixelsPerStud = opts.pps or 50
	g.LightInfluence = if opts.lit then 0 else 1
	g.Brightness = opts.brightness or 1
	g.Parent = part
	local f = Instance.new("TextLabel")
	f.Size = UDim2.fromScale(1, 1)
	f.BackgroundColor3 = bg or C(255, 255, 255)
	f.BackgroundTransparency = if bg then 0 else 1
	f.BorderSizePixel = 0
	f.Text = text
	f.TextColor3 = fg or C(20, 20, 20)
	f.TextScaled = true
	f.Font = opts.font or Enum.Font.GothamBlack
	f.RichText = true
	f.Parent = g
	local pad = Instance.new("UIPadding")
	local px = UDim.new(opts.pad or 0.08, 0)
	pad.PaddingLeft, pad.PaddingRight, pad.PaddingTop, pad.PaddingBottom = px, px, px, px
	pad.Parent = f
	return g
end

-- A grid of frames on a face (CCTV monitor, ceiling tiles, pegboard...).
function K.grid(part: BasePart, face: Enum.NormalId, cols: number, rows: number, color: Color3, line: Color3, lit: boolean?)
	local g = Instance.new("SurfaceGui")
	g.Face = face
	g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	g.PixelsPerStud = 20
	g.LightInfluence = if lit then 0 else 1
	g.Parent = part
	local bgf = Instance.new("Frame")
	bgf.Size = UDim2.fromScale(1, 1)
	bgf.BackgroundColor3 = line
	bgf.BorderSizePixel = 0
	bgf.Parent = g
	local layout = Instance.new("UIGridLayout")
	layout.CellPadding = UDim2.fromOffset(2, 2)
	layout.CellSize = UDim2.new(1 / cols, -2, 1 / rows, -2)
	layout.Parent = bgf
	for _ = 1, cols * rows do
		local c = Instance.new("Frame")
		c.BackgroundColor3 = color
		c.BorderSizePixel = 0
		c.Parent = bgf
	end
	return g
end

-- Checkerboard on a face (diner floors). One part, one SurfaceGui.
function K.checker(part: BasePart, face: Enum.NormalId, cols: number, rows: number, c1: Color3, c2: Color3)
	local g = Instance.new("SurfaceGui")
	g.Face = face
	g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	g.PixelsPerStud = 10
	g.LightInfluence = 1
	g.Parent = part
	for r = 0, rows - 1 do
		for c = 0, cols - 1 do
			local f = Instance.new("Frame")
			f.BorderSizePixel = 0
			f.BackgroundColor3 = if (r + c) % 2 == 0 then c1 else c2
			f.Position = UDim2.fromScale(c / cols, r / rows)
			f.Size = UDim2.fromScale(1 / cols + 0.001, 1 / rows + 0.001)
			f.Parent = g
		end
	end
	return g
end

-- Raycast rules (JobFX.floor casts straight down from station+6): CanQuery=false only sticks on NON-colliding parts,
-- so objects that sit under a station are made non-colliding (deco) and get these invisible walls around their
-- edge for collision instead. The ray down the middle never touches them.
function K.blockers(b, parent: Instance, cf: CFrame, size: Vector3)
	local t = 0.3
	local h = size.Y
	for _, s in { -1, 1 } do
		b.P("Blocker", Vector3.new(size.X, h, t), cf * CFrame.new(0, h / 2, s * (size.Z / 2 - t / 2)), C(0, 0, 0), M.SmoothPlastic, { parent = parent, Transparency = 1 })
		b.P("Blocker", Vector3.new(t, h, size.Z - 2 * t), cf * CFrame.new(s * (size.X / 2 - t / 2), h / 2, 0), C(0, 0, 0), M.SmoothPlastic, { parent = parent, Transparency = 1 })
	end
end

-- The map's invisible lot "Footprint" parts are 4 studs tall and catch every downward ray (job FX floated ~4 studs
-- up). Turn querying off on the ones under a job site.
function K.quietFootprints(center: Vector3, radius: number)
	local n = 0
	for _, d in workspace.ViceBay:GetDescendants() do
		if d:IsA("BasePart") and d.Name == "Footprint" and not d.CanCollide then
			local p = d.Position
			if (Vector3.new(p.X, 0, p.Z) - Vector3.new(center.X, 0, center.Z)).Magnitude < radius then
				d.CanQuery = false
				n += 1
			end
		end
	end
	return n
end

-- Modern PBR surfaces (Nov 2): MaterialService.MTL_Interior holds the picked variants (see vault Research/Interior
-- Textures.md). A variant only renders when the part's Material equals its BaseMaterial, so dressPart sets both.
function K.dressPart(p: BasePart, variant: string, dropGuis: boolean?)
	local MS = game:GetService("MaterialService")
	local folder = MS:FindFirstChild("MTL_Interior")
	local v = folder and folder:FindFirstChild(variant)
	if not v then
		return false
	end
	p.Material = v.BaseMaterial
	p.MaterialVariant = variant
	-- the texture maps are darker than flat colour, so these tints sit above the ~196 flat-colour cap on purpose
	local tint = K.Tints[variant]
	if tint then
		p.Color = tint
	end
	if dropGuis then
		for _, ch in p:GetChildren() do
			if ch:IsA("SurfaceGui") then
				ch:Destroy()
			end
		end
	end
	return true
end

K.Tints = {
	MTL_VCTTile = C(232, 228, 216),
	MTL_WallTile = C(236, 236, 230),
	MTL_Drywall = C(236, 232, 222),
	MTL_CeilingTile = C(232, 232, 228),
	MTL_DinerCheck = C(240, 240, 236),
	MTL_MallTile = C(226, 224, 218),
	MTL_Concrete = C(200, 198, 192),
}

-- map = { PartName = "MTL_Variant" | { "MTL_Variant", dropGuis } }, applied to every descendant with that name
function K.dress(model: Instance, map)
	local n = 0
	for _, d in model:GetDescendants() do
		local e = d:IsA("BasePart") and map[d.Name]
		if e then
			local name, drop = if type(e) == "table" then e[1] else e, if type(e) == "table" then e[2] else false
			if K.dressPart(d, name, drop) then
				n += 1
			end
		end
	end
	return n
end

---------------------------------------------------------------- products

-- Brand-ish colour pairs: {body, label}
K.Snacks = {
	{ C(214, 40, 36), C(250, 214, 60) }, { C(250, 196, 30), C(200, 30, 30) }, { C(36, 90, 190), C(240, 240, 240) },
	{ C(40, 150, 70), C(250, 240, 220) }, { C(240, 120, 30), C(60, 30, 20) }, { C(120, 50, 150), C(250, 220, 80) },
	{ C(30, 30, 34), C(230, 60, 60) }, { C(230, 230, 226), C(30, 100, 200) },
}
K.Grocery = {
	{ C(196, 40, 40), C(245, 240, 230) }, { C(240, 236, 220), C(40, 120, 60) }, { C(250, 210, 80), C(150, 40, 30) },
	{ C(60, 110, 180), C(250, 250, 250) }, { C(150, 90, 50), C(240, 220, 180) }, { C(200, 200, 196), C(200, 40, 40) },
	{ C(46, 120, 74), C(250, 220, 90) },
}
K.Household = {
	{ C(240, 240, 244), C(40, 110, 200) }, { C(80, 170, 220), C(255, 255, 255) }, { C(250, 140, 170), C(255, 255, 255) },
	{ C(250, 220, 60), C(30, 30, 30) }, { C(110, 200, 120), C(255, 255, 255) }, { C(230, 90, 40), C(250, 250, 250) },
}
K.Drinks = {
	{ C(200, 20, 30), C(240, 240, 240) }, { C(20, 60, 140), C(230, 230, 230) }, { C(40, 160, 60), C(250, 250, 240) },
	{ C(250, 140, 20), C(255, 255, 255) }, { C(120, 200, 230), C(255, 255, 255) }, { C(60, 30, 20), C(230, 190, 90) },
	{ C(240, 200, 30), C(40, 40, 40) }, { C(160, 40, 160), C(255, 255, 255) },
}

-- Fills one shelf. `base` = CFrame on the shelf top at its centre; local X runs along the shelf, LookVector (-Z)
-- faces the customer. Products are 1 part each (+ a label band on some), small gaps, a few holes.
function K.fillShelf(b, base: CFrame, length: number, depth: number, maxH: number, rng: Random, palette, parent)
	local x = -length / 2 + 0.08
	local stop = length / 2 - 0.08
	while x < stop do
		local kind = rng:NextNumber()
		local w, h, d
		if kind < 0.35 then -- boxes
			w, h, d = rng:NextNumber(0.75, 1.25), maxH * rng:NextNumber(0.8, 1), depth * rng:NextNumber(0.75, 0.95)
		elseif kind < 0.65 then -- bags / pouches
			w, h, d = rng:NextNumber(0.9, 1.3), maxH * rng:NextNumber(0.65, 0.85), depth * rng:NextNumber(0.5, 0.7)
		else -- cans / jars / bottles (a row read as one block)
			w, h, d = rng:NextNumber(0.5, 0.8), maxH * rng:NextNumber(0.45, 0.75), depth * 0.9
		end
		if x + w > stop then
			break
		end
		if rng:NextNumber() < 0.06 then
			x += w * 0.8 -- a gap: sold-out spot
			continue
		end
		local pal = palette[rng:NextInteger(1, #palette)]
		local facings = rng:NextInteger(1, 3)
		for _ = 1, facings do
			if x + w > stop then
				break
			end
			local cf = base * CFrame.new(x + w / 2, h / 2, -depth / 2 + d / 2)
			if kind >= 0.35 and kind < 0.65 then
				cf *= CFrame.Angles(math.rad(rng:NextNumber(-8, 4)), 0, 0)
			end
			b.P("Product", Vector3.new(w, h, d), cf, pal[1], M.SmoothPlastic, { parent = parent, deco = true })
			if w > 0.7 and rng:NextNumber() < 0.45 then
				b.P("Label", Vector3.new(w * 0.86, h * 0.3, 0.04), base * CFrame.new(x + w / 2, h * 0.55, -depth / 2 - 0.01), pal[2], M.SmoothPlastic, { parent = parent, deco = true })
			end
			x += w + 0.06
		end
	end
end

return K
