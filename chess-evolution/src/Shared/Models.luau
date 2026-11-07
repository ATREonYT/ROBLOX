--!strict
-- +1 Chess Evolution: original chunky models built from parts (no uploads needed).
-- Chess pieces (Pawn, Knight, Bishop, Rook, Queen, King) and the six treadmills.
-- Every treadmill has the same anchors: Deck (zone), Align (where the runner stands),
-- Console, Screen, LabelAnchor, Belt/Slats, FX (attachment). Runner faces the model's -Z.

local Models = {}

local IVORY = Color3.fromRGB(246, 238, 220)
local CHARCOAL = Color3.fromRGB(46, 48, 56)
local GOLD = Color3.fromRGB(255, 200, 50)
local BELT = Color3.fromRGB(34, 36, 44)
local STEEL = Color3.fromRGB(150, 156, 168)
Models.IVORY, Models.CHARCOAL, Models.GOLD = IVORY, CHARCOAL, GOLD

local VERTICAL = CFrame.Angles(0, 0, math.pi / 2) -- cylinder axis X -> Y

local function part(parent: Instance, name: string, size: Vector3, cf: CFrame, color: Color3, props: { [string]: any }?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Anchored = true
	p.Material = Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if props then
		for k, v in props do
			(p :: any)[k] = v
		end
	end
	p.Parent = parent
	return p
end
Models.Part = part

local function cyl(parent: Instance, name: string, diameter: number, height: number, cf: CFrame, color: Color3, props: { [string]: any }?): Part
	local p = part(parent, name, Vector3.new(height, diameter, diameter), cf * VERTICAL, color, props)
	p.Shape = Enum.PartType.Cylinder
	return p
end
Models.Cyl = cyl

local function ball(parent: Instance, name: string, diameter: number, cf: CFrame, color: Color3, props: { [string]: any }?): Part
	local p = part(parent, name, Vector3.new(diameter, diameter, diameter), cf, color, props)
	p.Shape = Enum.PartType.Ball
	return p
end
Models.Ball = ball

local function wedge(parent: Instance, name: string, size: Vector3, cf: CFrame, color: Color3): WedgePart
	local p = Instance.new("WedgePart")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Anchored = true
	p.Material = Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

---------------------------------------------------------------------------
-- Chess pieces. Built standing on `base` (bottom centre), facing -Z, `s` = scale (1 = ~5 studs tall).
---------------------------------------------------------------------------
function Models.Piece(kind: string, color: Color3, s: number, base: CFrame, opts: { [string]: any }?): Model
	local o = opts or {}
	local model = Instance.new("Model")
	model.Name = kind
	local trim = o.trim or color
	local material = o.material or Enum.Material.SmoothPlastic
	local function at(y: number): CFrame
		return base * CFrame.new(0, y * s, 0)
	end
	local props = { Material = material, CanCollide = o.collide == true, CastShadow = true }
	local trimProps = { Material = Enum.Material.SmoothPlastic, CanCollide = false }
	-- shared foot: wide disc + trim ring
	local foot = cyl(model, "Foot", 3.2 * s, 0.6 * s, at(0.3), color, props)
	cyl(model, "FootTrim", 3.4 * s, 0.22 * s, at(0.62), trim, trimProps)
	cyl(model, "Waist", 2.5 * s, 0.4 * s, at(0.9), color, props)
	model.PrimaryPart = foot

	if kind == "Pawn" then
		cyl(model, "Body", 1.7 * s, 1.6 * s, at(1.85), color, props)
		cyl(model, "BodyTop", 1.3 * s, 0.6 * s, at(2.9), color, props)
		cyl(model, "Collar", 2.1 * s, 0.32 * s, at(3.25), trim, trimProps)
		ball(model, "Head", 1.9 * s, at(4.15), color, props)
	elseif kind == "Rook" then
		cyl(model, "Body", 2.1 * s, 2.6 * s, at(2.4), color, props)
		cyl(model, "Collar", 2.5 * s, 0.3 * s, at(3.8), trim, trimProps)
		cyl(model, "Top", 2.7 * s, 0.9 * s, at(4.4), color, props)
		for i = 0, 3 do
			local a = i * math.pi / 2 + math.pi / 4
			part(model, "Merlon", Vector3.new(0.8, 0.8, 0.8) * s, at(5.2) * CFrame.Angles(0, a, 0) * CFrame.new(0, 0, -1.0 * s), color, props)
		end
	elseif kind == "Bishop" then
		cyl(model, "Body", 1.6 * s, 2.2 * s, at(2.2), color, props)
		cyl(model, "Collar", 2.1 * s, 0.3 * s, at(3.4), trim, trimProps)
		ball(model, "Mitre", 2.0 * s, at(4.35), color, props)
		cyl(model, "MitreTop", 1.4 * s, 0.9 * s, at(5.0), color, props)
		part(model, "Slit", Vector3.new(0.25, 1.2, 1.6) * s, at(4.6) * CFrame.Angles(0, 0, math.rad(35)) * CFrame.new(0, 0, -0.35 * s), trim, trimProps)
		ball(model, "Finial", 0.7 * s, at(5.7), trim, trimProps)
	elseif kind == "Queen" then
		cyl(model, "Body", 1.7 * s, 2.6 * s, at(2.4), color, props)
		cyl(model, "Collar", 2.2 * s, 0.3 * s, at(3.8), trim, trimProps)
		cyl(model, "Cup", 2.3 * s, 1.0 * s, at(4.4), color, props)
		for i = 0, 7 do
			ball(model, "Point", 0.55 * s, at(5.05) * CFrame.Angles(0, i * math.pi / 4, 0) * CFrame.new(0, 0, -1.05 * s), trim, trimProps)
		end
		ball(model, "Crown", 1.1 * s, at(5.3), color, props)
		ball(model, "Jewel", 0.6 * s, at(6.0), trim, trimProps)
	elseif kind == "King" then
		cyl(model, "Body", 1.8 * s, 2.8 * s, at(2.5), color, props)
		cyl(model, "Collar", 2.3 * s, 0.3 * s, at(4.0), trim, trimProps)
		cyl(model, "Cup", 2.2 * s, 1.0 * s, at(4.6), color, props)
		part(model, "CrossV", Vector3.new(0.6, 1.7, 0.6) * s, at(5.95), trim, trimProps)
		part(model, "CrossH", Vector3.new(1.5, 0.55, 0.6) * s, at(6.1), trim, trimProps)
	elseif kind == "Knight" then
		-- chunky horse head: neck block leaning forward, muzzle, ears, mane fins
		part(model, "Chest", Vector3.new(2.0, 1.6, 2.2) * s, at(1.85), color, props)
		part(model, "Neck", Vector3.new(1.8, 2.4, 1.6) * s, at(3.1) * CFrame.new(0, 0, 0.2 * s) * CFrame.Angles(math.rad(-14), 0, 0), color, props)
		part(model, "Head", Vector3.new(1.7, 1.3, 2.6) * s, at(4.2) * CFrame.new(0, 0, -0.6 * s) * CFrame.Angles(math.rad(-18), 0, 0), color, props)
		part(model, "Muzzle", Vector3.new(1.4, 1.0, 1.0) * s, at(3.8) * CFrame.new(0, 0, -1.75 * s) * CFrame.Angles(math.rad(-18), 0, 0), color, props)
		wedge(model, "EarL", Vector3.new(0.4, 0.8, 0.6) * s, at(5.05) * CFrame.new(-0.5 * s, 0, 0.3 * s), trim)
		wedge(model, "EarR", Vector3.new(0.4, 0.8, 0.6) * s, at(5.05) * CFrame.new(0.5 * s, 0, 0.3 * s), trim)
		for i = 0, 2 do
			part(model, "Mane", Vector3.new(0.5, 0.7, 0.7) * s, at(3.2 + i * 0.6) * CFrame.new(0, 0, (1.1 - i * 0.15) * s), trim, trimProps)
		end
		part(model, "EyeL", Vector3.new(0.12, 0.3, 0.3) * s, at(4.45) * CFrame.new(-0.86 * s, 0, -0.9 * s), CHARCOAL, trimProps)
		part(model, "EyeR", Vector3.new(0.12, 0.3, 0.3) * s, at(4.45) * CFrame.new(0.86 * s, 0, -0.9 * s), CHARCOAL, trimProps)
	end
	return model
end

---------------------------------------------------------------------------
-- Treadmills. `cf` = deck centre on the floor, runner faces cf.LookVector.
---------------------------------------------------------------------------
local THEMES = {
	PawnMill = { chassis = Color3.fromRGB(80, 200, 90), rail = IVORY, console = Color3.fromRGB(150, 100, 60), consoleMat = Enum.Material.Wood, screen = Color3.fromRGB(120, 255, 140) },
	KnightSprint = { chassis = Color3.fromRGB(40, 90, 230), rail = Color3.fromRGB(230, 236, 250), console = Color3.fromRGB(28, 50, 140), screen = Color3.fromRGB(80, 230, 255) },
	BishopRun = { chassis = Color3.fromRGB(130, 60, 160), rail = IVORY, console = Color3.fromRGB(90, 40, 120), screen = Color3.fromRGB(200, 120, 255) },
	RookRig = { chassis = Color3.fromRGB(220, 50, 50), rail = CHARCOAL, console = CHARCOAL, screen = Color3.fromRGB(255, 90, 70) },
	QueenDash = { chassis = IVORY, rail = GOLD, console = Color3.fromRGB(240, 220, 170), screen = Color3.fromRGB(255, 220, 90) },
	KingsEndgame = { chassis = CHARCOAL, rail = GOLD, console = Color3.fromRGB(30, 30, 36), screen = Color3.fromRGB(255, 200, 60) },
}
THEMES.CastleClimb = { chassis = Color3.fromRGB(40, 180, 200), rail = IVORY, console = Color3.fromRGB(30, 110, 130), screen = Color3.fromRGB(120, 255, 240) }
THEMES.GrandmasterGlide = { chassis = Color3.fromRGB(30, 26, 50), rail = Color3.fromRGB(170, 90, 255), console = Color3.fromRGB(20, 18, 34), screen = Color3.fromRGB(190, 120, 255) }
Models.TreadmillThemes = THEMES

function Models.Treadmill(id: string, cf: CFrame): Model
	local th = THEMES[id]
	local m = Instance.new("Model")
	m.Name = id
	local function at(x: number, y: number, z: number): CFrame
		return cf * CFrame.new(x, y, z)
	end
	local solid = { Material = Enum.Material.Plastic, TopSurface = Enum.SurfaceType.Studs }
	-- chassis (low entry at the back, +Z)
	local base = part(m, "Chassis", Vector3.new(8, 1.2, 12), at(0, 0.6, 0), th.chassis, solid)
	m.PrimaryPart = base
	part(m, "Belt", Vector3.new(5.2, 0.3, 10.4), at(0, 1.35, 0), BELT, { Material = Enum.Material.Fabric })
	local slats = Instance.new("Folder")
	slats.Name = "Slats"
	slats.Parent = m
	for i = 0, 9 do
		local z = -5 + i * 1.04 + 0.52
		part(slats, "Slat", Vector3.new(5.0, 0.08, 0.32), at(0, 1.53, z), Color3.fromRGB(70, 74, 86), { CanCollide = false, CastShadow = false, Material = Enum.Material.SmoothPlastic })
	end
	-- recessed rollers
	for _, z in { -5.4, 5.4 } do
		local r = part(m, "Roller", Vector3.new(5.6, 1.3, 1.3), at(0, 1.05, z), STEEL, { Material = Enum.Material.Metal })
		r.Shape = Enum.PartType.Cylinder
	end
	-- side skirts
	for _, x in { -3.3, 3.3 } do
		part(m, "Skirt", Vector3.new(1.4, 1.8, 11.6), at(x, 1.5, 0.2), th.chassis, solid)
	end
	-- chunky rails on posts
	for _, x in { -3.3, 3.3 } do
		part(m, "Rail", Vector3.new(0.9, 0.9, 7.2), at(x, 5.0, -1.4), th.rail, { Material = Enum.Material.SmoothPlastic })
		part(m, "Post", Vector3.new(0.8, 2.8, 0.8), at(x, 3.4, 1.9), th.rail)
	end
	-- front console
	local consoleProps = { Material = th.consoleMat or Enum.Material.SmoothPlastic }
	part(m, "ConsolePost", Vector3.new(1.4, 4.4, 1.0), at(0, 3.4, -5.6), th.console, consoleProps)
	local console = part(m, "Console", Vector3.new(6.6, 1.8, 1.6), at(0, 5.6, -5.4) * CFrame.Angles(math.rad(25), 0, 0), th.console, consoleProps)
	local screen = part(m, "Screen", Vector3.new(4.6, 1.1, 0.2), console.CFrame * CFrame.new(0, 0.1, -0.75), th.screen, { Material = Enum.Material.Neon, CanCollide = false, Transparency = 0.35 })
	local light = Instance.new("PointLight")
	light.Name = "ConsoleLight"
	light.Color = th.screen
	light.Range = 8
	light.Brightness = 0.4
	light.Parent = screen

	-- tier silhouettes
	if id == "PawnMill" then
		for _, x in { -3.3, 3.3 } do
			for _, z in { -5.0, 2.2 } do
				local pawn = Models.Piece("Pawn", IVORY, 0.42, at(x, 4.5, z))
				pawn.Name = "PawnPost"
				pawn.Parent = m
			end
		end
	elseif id == "KnightSprint" then
		for _, x in { -3.6, 3.6 } do
			local knight = Models.Piece("Knight", Color3.fromRGB(230, 236, 250), 0.75, at(x, 1.2, -5.2) * CFrame.Angles(0, if x < 0 then math.rad(-20) else math.rad(20), 0), { trim = Color3.fromRGB(40, 90, 230) })
			knight.Name = "KnightSupport"
			knight.Parent = m
		end
		for i = 0, 2 do
			for _, x in { -4.4, 4.4 } do
				part(m, "StepPlate", Vector3.new(0.8, 1.0 + i * 0.9, 3.4), at(x, 1.2 + (1.0 + i * 0.9) / 2, 3.6 - i * 3.4), th.chassis, solid)
			end
		end
	elseif id == "BishopRun" then
		for _, x in { -3.3, 3.3 } do
			for _, z in { -5.0, 2.2 } do
				local b = Models.Piece("Bishop", IVORY, 0.38, at(x, 4.5, z), { trim = th.chassis })
				b.Name = "MitreFinial"
				b.Parent = m
			end
			for k = 0, 3 do
				part(m, "Inlay", Vector3.new(0.2, 0.3, 1.6), at(x * 1.22, 1.6, -3.6 + k * 2.4) * CFrame.Angles(math.rad(40), 0, 0), IVORY, { CanCollide = false })
			end
		end
	elseif id == "RookRig" then
		for _, x in { -4.3, 4.3 } do
			for _, z in { -5.2, 4.8 } do
				local tower = Models.Piece("Rook", CHARCOAL, 0.7, at(x, 1.2, z), { trim = th.chassis })
				tower.Name = "Tower"
				tower.Parent = m
			end
		end
		part(m, "Crossbar", Vector3.new(9.6, 1.4, 1.4), at(0, 7.4, -5.2), CHARCOAL)
	elseif id == "QueenDash" then
		for i = 0, 6 do
			local a = (i - 3) * 0.32
			part(m, "CrownSpike", Vector3.new(0.6, 1.6, 0.6), console.CFrame * CFrame.new(math.sin(a) * 3.0, 1.4, 0) * CFrame.Angles(0, 0, -a * 0.5), GOLD)
			ball(m, "Jewel", 0.55, console.CFrame * CFrame.new(math.sin(a) * 3.0, 2.3, 0), if i % 2 == 0 then Color3.fromRGB(255, 80, 160) else Color3.fromRGB(80, 220, 255), { Material = Enum.Material.Neon })
		end
	elseif id == "KingsEndgame" then
		for i = 0, 2 do
			for _, x in { -4.6, 4.6 } do
				part(m, "StepSupport", Vector3.new(1.2, 1.2 + i * 1.4, 1.6), at(x, (1.2 + i * 1.4) / 2, -4.8 + i * 1.8), GOLD)
			end
		end
		part(m, "CrossV", Vector3.new(0.8, 3.0, 0.8), console.CFrame * CFrame.new(0, 2.4, 0.2), GOLD)
		part(m, "CrossH", Vector3.new(2.4, 0.8, 0.8), console.CFrame * CFrame.new(0, 2.9, 0.2), GOLD)
	end

	-- anchors (invisible)
	local hidden = { Transparency = 1, CanCollide = false, CanQuery = false, CanTouch = false, CastShadow = false }
	part(m, "Deck", Vector3.new(7, 6, 12), at(0, 3, 0), Color3.new(0, 1, 0), hidden)
	part(m, "Align", Vector3.new(1, 1, 1), at(0, 1.5, 0.6), Color3.new(1, 0, 0), hidden)
	local labelAnchor = part(m, "LabelAnchor", Vector3.new(1, 1, 1), at(0, 10.5, -5), Color3.new(0, 0, 1), hidden)
	local fx = Instance.new("Attachment")
	fx.Name = "FX"
	fx.Position = Vector3.new(0, 0.4, 0)
	fx.Parent = m:FindFirstChild("Belt")
	local consoleFx = Instance.new("Attachment")
	consoleFx.Name = "FX"
	consoleFx.Parent = screen
	local _ = labelAnchor
	m:SetAttribute("StationId", id)
	return m
end

return Models
