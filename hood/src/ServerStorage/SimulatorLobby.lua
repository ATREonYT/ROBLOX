-- The Block lobby: a hood courtyard with the Drip Shop (all 15 looks) and the Block Boxing Club (training bays).
-- Edit-time builder; nothing here runs during play. From the Studio Command Bar:
--   require(game.ServerStorage.SimulatorLobby).Build()
-- The old lobby is moved into ServerStorage first, and one Ctrl+Z undoes the whole build.
local Lobby = {}

local ReplicatedStorage = game:GetService('ReplicatedStorage')
local V, C = Vector3.new, Color3.fromRGB
local M = Enum.Material

local P = {
	brick = C(158, 80, 60), brickDark = C(116, 58, 46), brickTan = C(192, 148, 106), coping = C(218, 210, 192),
	concrete = C(184, 181, 172), sidewalk = C(206, 202, 192), curb = C(226, 222, 210), asphalt = C(60, 62, 66),
	paint = C(242, 236, 216), iron = C(40, 44, 48), steel = C(92, 102, 110), chain = C(168, 174, 178),
	wood = C(130, 92, 60), woodDark = C(88, 62, 44), rubber = C(48, 50, 54), leather = C(122, 74, 46),
	yellow = C(252, 198, 50), teal = C(44, 196, 196), magenta = C(228, 66, 148), orange = C(246, 126, 44),
	lime = C(150, 208, 72), white = C(246, 244, 236), black = C(26, 26, 30), red = C(214, 52, 58), blue = C(52, 104, 214),
	gold = C(236, 186, 52), shopFloor = C(96, 70, 54),
}

---------------------------------------------------------------------------------------------- build context
-- A context places parts in its own local frame: world CFrame = map frame * ctx.cf * local CFrame.
local Ctx = {}
Ctx.__index = Ctx
local function newCtx(parent, map, cf)
	return setmetatable({ parent = parent, map = map, cf = cf }, Ctx)
end
function Lobby.context(parent, map, cf)
	return newCtx(parent, map or CFrame.new(), cf or CFrame.new())
end
function Ctx:at(cf)
	return newCtx(self.parent, self.map, self.cf * cf)
end
function Ctx:into(parent)
	return newCtx(parent, self.map, self.cf)
end
function Ctx:group(name, class)
	local g = Instance.new(class or 'Model')
	g.Name = name
	g.Parent = self.parent
	return newCtx(g, self.map, self.cf), g
end
function Ctx:world(cf)
	return self.map * self.cf * cf
end
function Ctx:part(name, size, cf, color, material, shape)
	local p = Instance.new('Part')
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = self.map * self.cf * cf
	p.Color = color
	p.Material = material or M.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if shape then p.Shape = shape end
	p.Parent = self.parent
	return p
end
-- Axis-aligned box between two corners: neighbours that share a coordinate meet with no gap.
function Ctx:box(name, a, b, color, material)
	local lo = V(math.min(a.X, b.X), math.min(a.Y, b.Y), math.min(a.Z, b.Z))
	local hi = V(math.max(a.X, b.X), math.max(a.Y, b.Y), math.max(a.Z, b.Z))
	return self:part(name, hi - lo, CFrame.new((lo + hi) / 2), color, material)
end
-- Upright cylinder whose base is centred on pos.
function Ctx:post(name, radius, height, pos, color, material)
	return self:part(name, V(height, radius * 2, radius * 2), CFrame.new(pos + V(0, height / 2, 0)) * CFrame.Angles(0, 0, math.pi / 2), color, material or M.Metal, Enum.PartType.Cylinder)
end
-- Cylinder lying along the X axis of cf.
function Ctx:rod(name, radius, length, cf, color, material)
	return self:part(name, V(length, radius * 2, radius * 2), cf, color, material or M.Metal, Enum.PartType.Cylinder)
end
-- Square bar running from a to b.
function Ctx:bar(name, a, b, width, color, material)
	local dir = b - a
	local up = math.abs(dir.Unit.Y) > 0.99 and V(1, 0, 0) or V(0, 1, 0)
	return self:part(name, V(width, width, dir.Magnitude), CFrame.lookAt((a + b) / 2, b, up), color, material or M.Metal)
end
-- Ellipsoid of any proportions.
function Ctx:blob(name, size, pos, color, material)
	local p = self:part(name, size, CFrame.new(pos), color, material)
	local mesh = Instance.new('SpecialMesh')
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = p
	return p
end
function Ctx:wedge(name, size, cf, color, material)
	local p = Instance.new('WedgePart')
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = self.map * self.cf * cf
	p.Color = color
	p.Material = material or M.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = self.parent
	return p
end

local function ghost(p)
	p.Transparency = 1
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	return p
end
local function light(p, color, brightness, range)
	local l = Instance.new('PointLight')
	l.Color = color
	l.Brightness = brightness
	l.Range = range
	l.Shadows = false
	l.Parent = p
	return l
end
local function text(gui, name, value, color, font, y, h, stroke)
	local t = Instance.new('TextLabel')
	t.Name = name
	t.BackgroundTransparency = 1
	t.Position = UDim2.fromScale(0.04, y)
	t.Size = UDim2.fromScale(0.92, h)
	t.Font = font
	t.Text = value
	t.TextColor3 = color
	t.TextScaled = true
	t.TextWrapped = true
	t.TextStrokeColor3 = stroke or P.black
	t.TextStrokeTransparency = stroke and 0 or 1
	t.Parent = gui
	return t
end
local function surface(p, face, lightInfluence)
	local g = Instance.new('SurfaceGui')
	g.Name = 'Signage'
	g.Face = face or Enum.NormalId.Front
	g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	g.PixelsPerStud = 40
	g.LightInfluence = lightInfluence or 0.25
	g.Parent = p
	return g
end
-- Title + detail sign; the client rewrites Detail with live lock status.
local function signText(p, title, detail, titleColor, face)
	local g = surface(p, face, 0)
	text(g, 'Title', title, titleColor, Enum.Font.GothamBlack, 0.06, 0.5, P.black)
	text(g, 'Detail', detail, P.white, Enum.Font.GothamBold, 0.6, 0.32, P.black)
	return g
end
local function worldLabel(ctx, pos, w, h, title, detail, titleColor)
	local a = ghost(ctx:part('LabelAnchor', V(0.2, 0.2, 0.2), CFrame.new(pos), P.white))
	local g = Instance.new('BillboardGui')
	g.Name = 'WorldLabel'
	g.Size = UDim2.fromScale(w, h)
	g.MaxDistance = 80
	g.LightInfluence = 0
	g.Parent = a
	text(g, 'Title', title, titleColor, Enum.Font.GothamBlack, 0, 0.52, P.black)
	text(g, 'Detail', detail, P.white, Enum.Font.GothamBold, 0.54, 0.42, P.black)
	return a
end
local function compact(n)
	if n >= 1e6 then return (string.format('%.1fM', n / 1e6):gsub('%.0M', 'M')) end
	if n >= 1000 then return (string.format('%.1fK', n / 1000):gsub('%.0K', 'K')) end
	return tostring(n)
end

---------------------------------------------------------------------------------------------- shared pieces
-- Brick wall with stone coping and pilasters every `bay` studs, from a to b along local X (thickness along Z).
local function brickWall(ctx, name, x0, x1, z0, z1, height, color, pilasterEvery)
	local w = ctx:box(name, V(x0, 0, z0), V(x1, height, z1), color or P.brick, M.Brick)
	ctx:box(name .. 'Coping', V(x0 - 0.3, height, z0 - 0.3), V(x1 + 0.3, height + 0.5, z1 + 0.3), P.coping, M.Concrete)
	if pilasterEvery then
		local count = math.max(1, math.floor((x1 - x0) / pilasterEvery + 0.5))
		for i = 0, count do
			local x = x0 + (x1 - x0) * i / count
			ctx:box(name .. 'Pilaster', V(x - 0.7, 0, z0 - 0.35), V(x + 0.7, height, z1 + 0.35), P.brickDark, M.Brick)
			ctx:box(name .. 'PilasterCap', V(x - 0.95, height, z0 - 0.6), V(x + 0.95, height + 0.8, z1 + 0.6), P.coping, M.Concrete)
		end
	end
	return w
end
-- Chain-link panel between two posts along local X: rails, sparse diagonal wire and the posts themselves.
local function chainLink(ctx, x0, x1, z, y0, height, withPosts)
	local g = ctx:group('ChainLink')
	if withPosts ~= false then
		for _, x in { x0, x1 } do g:post('FencePost', 0.22, height + 0.3, V(x, y0, z), P.steel) end
	end
	g:rod('TopRail', 0.12, x1 - x0, CFrame.new((x0 + x1) / 2, y0 + height, z), P.steel)
	g:rod('BottomRail', 0.1, x1 - x0, CFrame.new((x0 + x1) / 2, y0 + 0.25, z), P.steel)
	local mesh = g:box('Mesh', V(x0, y0 + 0.25, z - 0.03), V(x1, y0 + height, z + 0.03), P.chain, M.DiamondPlate)
	mesh.Transparency = 0.55
	mesh.CastShadow = false
	local step = 1.6
	local n = math.max(1, math.floor((x1 - x0) / step))
	for i = 0, n - 1 do
		local a = x0 + (x1 - x0) * i / n
		local b = x0 + (x1 - x0) * (i + 1) / n
		g:bar('Wire', V(a, y0 + 0.3, z), V(b, y0 + height - 0.05, z), 0.06, P.chain).CastShadow = false
		g:bar('Wire', V(b, y0 + 0.3, z), V(a, y0 + height - 0.05, z), 0.06, P.chain).CastShadow = false
	end
	return g
end

---------------------------------------------------------------------------------------------- the Drip Shop
-- Local frame: origin at the front-centre of the shop floor, -Z faces the plaza, rows climb toward +Z.
local SHOP = { cols = 5, spacing = 6, rowDepth = 7, rise = 2.4, halfWidth = 18, depth = 21, height = 19, scale = 0.86 }
Lobby.Shop = SHOP

function Lobby.buildShop(ctx, morphsFolder, skins, art)
	local shop = ctx:group('DripShop')
	local hw, depth, height = SHOP.halfWidth, SHOP.depth, SHOP.height
	-- Floor, two tiers, and yellow safety nosing on every edge players step up onto.
	shop:box('ShopFloor', V(-hw, -0.2, 0), V(hw, 0.05, 7), P.shopFloor, M.WoodPlanks)
	for row = 1, 2 do
		local top, front = row * SHOP.rise, row * SHOP.rowDepth
		shop:box('Tier' .. row, V(-hw, top - SHOP.rise, front), V(hw, top, depth), row == 1 and P.concrete or C(200, 196, 186), M.Concrete)
		shop:box('TierFloor' .. row, V(-hw, top, front), V(hw, top + 0.05, depth), P.shopFloor, M.WoodPlanks)
		shop:box('Nosing' .. row, V(-hw, top - 0.15, front - 0.12), V(hw, top + 0.08, front + 0.5), P.yellow, M.SmoothPlastic)
	end
	-- Side stairs: three 0.8-stud steps up to each tier, beside the outer columns.
	for _, side in { -1, 1 } do
		for row = 1, 2 do
			local front, base = row * SHOP.rowDepth, (row - 1) * SHOP.rise
			local a, b = side * (hw - 3.4), side * hw
			for step = 1, 2 do
				local z0 = front - (3 - step) * 1.6
				shop:box('Step', V(a, base + (row == 1 and 0.05 or 0), z0), V(b, base + step * 0.8, z0 + 1.6), C(196, 192, 182), M.Concrete)
				shop:box('StepNosing', V(a - side * 0.03, base + step * 0.8 - 0.15, z0 - 0.03), V(b + side * 0.03, base + step * 0.8 + 0.06, z0 + 0.4), P.yellow, M.SmoothPlastic)
			end
		end
	end
	-- Shell: brick side walls and back wall, flat roof, front header with the shop sign.
	brickWall(shop:at(CFrame.new(0, 0, depth + 0.5)), 'BackWall', -hw - 1, hw + 1, -0.5, 0.5, height, P.brick)
	for _, side in { -1, 1 } do
		local wall = shop:at(CFrame.new(side * (hw + 0.5), 0, depth / 2) * CFrame.Angles(0, math.pi / 2, 0))
		brickWall(wall, 'SideWall', -depth / 2 - 1, depth / 2 + 1, -0.5, 0.5, height, P.brick)
		shop:box('FrontPier', V(side * hw - side * 0.4, 0, -1.2), V(side * (hw + 1.4), height, 0.4), P.brickDark, M.Brick)
	end
	shop:box('Roof', V(-hw - 1.4, height, -1.2), V(hw + 1.4, height + 0.8, depth + 1.4), P.coping, M.Concrete)
	local header = shop:box('Header', V(-hw + 0.4, height - 3.6, -1.1), V(hw - 0.4, height, 0.2), P.black, M.SmoothPlastic)
	local hg = surface(header, Enum.NormalId.Front, 0)
	text(hg, 'Name', 'DRIP SHOP', P.yellow, Enum.Font.LuckiestGuy, 0.05, 0.62, C(120, 40, 20))
	text(hg, 'Tag', '15 LOOKS  •  WALK UP + PRESS E', P.white, Enum.Font.GothamBold, 0.7, 0.24)
	-- Striped awning over the walkway.
	local awning = shop:at(CFrame.new(0, height - 4.1, -2.5) * CFrame.Angles(math.rad(-24), 0, 0))
	for i = 0, 11 do
		local x0 = -hw + i * (2 * hw / 12)
		awning:box('AwningStripe', V(x0, -0.1, -1.6), V(x0 + 2 * hw / 12, 0.1, 1.6), i % 2 == 0 and P.red or P.white, M.Fabric)
	end
	awning:box('AwningValance', V(-hw, -0.8, -1.75), V(hw, 0.1, -1.55), P.red, M.Fabric)
	-- Warm strip lights under the roof.
	for _, z in { 3.5, 10.5, 17.5 } do
		local strip = shop:box('LightStrip', V(-hw + 2, height - 0.35, z - 0.25), V(hw - 2, height - 0.05, z + 0.25), C(255, 236, 196), M.Neon)
		light(strip, C(255, 220, 170), 1.2, 16)
	end
	-- Three rows of five looks, cheapest at the front. Columns ascend left to right as seen from the plaza.
	local morphs = shop:into(morphsFolder)
	local rowAccent = { C(120, 220, 236), C(196, 110, 236), P.gold }
	for row = 0, 2 do
		local floor, z = row * SHOP.rise, row * SHOP.rowDepth + 5
		for col = 1, SHOP.cols do
			local s = skins.List[row * SHOP.cols + col]
			local x = (SHOP.cols + 1) / 2 * SHOP.spacing - col * SHOP.spacing
			local stand = morphs:group('Skin_' .. s.Id)
			stand:box('Plinth', V(x - 2.2, floor, z - 1.8), V(x + 2.2, floor + 0.5, z + 1.8), C(232, 228, 218), M.SmoothPlastic)
			stand:box('PlinthTrim', V(x - 2.25, floor + 0.12, z - 1.85), V(x + 2.25, floor + 0.3, z + 1.85), rowAccent[row + 1], M.SmoothPlastic)
			stand:box('UnlockPad', V(x - 1.8, floor + 0.5, z - 1.4), V(x + 1.8, floor + 0.58, z + 1.4), rowAccent[row + 1], M.Neon)
			art.mannequin(stand.parent, stand:world(CFrame.new(x, floor + 0.58, z)), s, SHOP.scale)
			local labelY = floor + 0.58 + 5.6 * SHOP.scale + 1.1
			worldLabel(stand, V(x, labelY, z), 5.4, 1.8, s.Name, (s.Required == 0 and 'FREE' or compact(s.Required)) .. ' • +' .. s.Gain .. '/sec', P.yellow)
			ghost(stand:box('Interact', V(x - 1, floor + 0.05, z - 4.5), V(x + 1, floor + 0.15, z - 2.5), P.white))
		end
	end
	return shop
end

---------------------------------------------------------------------------------------------- the Block Boxing Club
-- Bay frame: origin at the centre of the training mat on the gym floor, -Z faces the aisle,
-- the bag hangs from an arm over the back half of the mat.
local BAY = { width = 11, depth = 11, armY = 10.6, hangZ = 1.4 }
Lobby.Bay = BAY

local function chain(ctx, top, bottom, color)
	local n = math.max(1, math.floor((top - bottom) / 0.45))
	for i = 0, n - 1 do
		local y = top - (i + 0.5) * (top - bottom) / n
		ctx:part('ChainLink', V(0.14, (top - bottom) / n * 0.95, i % 2 == 0 and 0.32 or 0.14), CFrame.new(0, y, BAY.hangZ), color or P.steel, M.Metal)
	end
end
local function hangingBag(ctx, radius, height, bottom, color, material, bands, bandColor)
	local top = bottom + height
	ctx:post('Bag', radius, height, V(0, bottom, BAY.hangZ), color, material or M.Leather)
	ctx:post('BagCap', radius * 0.82, 0.35, V(0, top, BAY.hangZ), P.black, M.Leather)
	ctx:post('BagBase', radius * 0.92, 0.2, V(0, bottom - 0.2, BAY.hangZ), P.black, M.Leather)
	for _, y in bands or {} do ctx:post('BagBand', radius + 0.04, 0.32, V(0, bottom + y * height - 0.16, BAY.hangZ), bandColor or P.white, M.Fabric) end
	-- Four straps up to a swivel ring, then chain to the arm.
	local ring = top + 1.4
	for _, d in { V(1, 0, 0), V(-1, 0, 0), V(0, 0, 1), V(0, 0, -1) } do
		ctx:bar('Strap', V(0, top + 0.3, BAY.hangZ) + d * radius * 0.7, V(0, ring, BAY.hangZ), 0.09, P.iron)
	end
	ctx:post('Swivel', 0.22, 0.3, V(0, ring - 0.15, BAY.hangZ), P.chain)
	chain(ctx, BAY.armY - 0.3, ring + 0.15)
end

-- Each gear builds into `swing` (parts that sway while someone trains) and `fixed`.
local GEAR = {}
Lobby.Gear = GEAR
function GEAR.TireBag(swing, fixed)
	for i = 0, 2 do
		local y = 3.0 + i * 1.08
		swing:post('Tire', 1.35, 1.0, V(0, y, BAY.hangZ), C(34, 34, 36), M.Rubber)
		swing:post('TireTread', 1.38, 0.5, V(0, y + 0.25, BAY.hangZ), C(52, 52, 54), M.Rubber)
		swing:post('TireHole', 0.62, 1.04, V(0, y - 0.02, BAY.hangZ), C(18, 18, 20), M.Rubber)
	end
	swing:post('DuctTape', 1.4, 0.34, V(0, 3.9, BAY.hangZ), C(176, 180, 184), M.Fabric)
	for k = 0, 2 do
		local a = k * math.pi * 2 / 3
		swing:bar('Rope', V(math.cos(a) * 0.95, 6.25, BAY.hangZ + math.sin(a) * 0.95), V(0, 7.6, BAY.hangZ), 0.12, C(176, 140, 92), M.Fabric)
	end
	swing:post('RopeKnot', 0.22, 0.3, V(0, 7.5, BAY.hangZ), C(150, 120, 80), M.Fabric)
	chain(swing, BAY.armY - 0.3, 7.8, C(150, 120, 80))
end
function GEAR.TapeBag(swing)
	hangingBag(swing, 1.25, 4.4, 2.4, C(140, 88, 52), M.Leather, { 0.18, 0.5, 0.82 }, C(184, 188, 192))
end
function GEAR.StreetBag(swing)
	hangingBag(swing, 1.3, 4.6, 2.2, C(44, 74, 150), M.Leather, { 0.22, 0.78 }, P.white)
end
function GEAR.HeavyBag(swing)
	hangingBag(swing, 1.55, 5.2, 1.7, P.red, M.Leather, { 0.12, 0.88 }, P.black)
end
function GEAR.SpeedBag(swing, fixed)
	-- Rebound platform on a drop rod from the arm, teardrop bag beneath it.
	fixed:post('DropRod', 0.18, BAY.armY - 6.3, V(0, 6.3, BAY.hangZ), P.iron)
	fixed:post('Platform', 2.1, 0.4, V(0, 5.9, BAY.hangZ), P.woodDark, M.Wood)
	fixed:post('PlatformRim', 2.16, 0.12, V(0, 5.9, BAY.hangZ), P.orange, M.SmoothPlastic)
	swing:post('Swivel', 0.16, 0.25, V(0, 5.65, BAY.hangZ), P.chain)
	swing:blob('SpeedBag', V(0.95, 1.4, 0.95), V(0, 4.85, BAY.hangZ), P.orange, M.Leather)
	swing:blob('SpeedBagNeck', V(0.45, 0.5, 0.45), V(0, 5.45, BAY.hangZ), P.orange, M.Leather)
end
function GEAR.DoubleEndBag(swing, fixed)
	swing:blob('DoubleEndBag', V(1.6, 2.0, 1.6), V(0, 4.4, BAY.hangZ), C(150, 70, 210), M.Leather)
	swing:post('BagSeam', 0.82, 0.14, V(0, 4.33, BAY.hangZ), P.white, M.Fabric)
	swing:bar('UpperCord', V(0, 5.35, BAY.hangZ), V(0, BAY.armY - 0.3, BAY.hangZ), 0.1, P.black, M.Fabric)
	swing:bar('LowerCord', V(0, 3.45, BAY.hangZ), V(0, 0.55, BAY.hangZ), 0.1, P.black, M.Fabric)
	fixed:post('FloorAnchor', 0.45, 0.3, V(0, 0.25, BAY.hangZ), P.iron)
end
function GEAR.ProBag(swing)
	hangingBag(swing, 1.15, 6.4, 1.2, C(34, 170, 170), M.Leather, { 0.1, 0.5, 0.9 }, P.black)
end
function GEAR.GoldBag(swing, fixed)
	hangingBag(swing, 1.5, 5.2, 1.8, P.gold, M.Foil, { 0.14, 0.5, 0.86 }, P.black)
	for _, p in swing.parent:GetChildren() do
		if p:IsA('BasePart') and p.Name == 'Bag' then p.Reflectance = 0.15 end
	end
end

-- One training bay: mat (TrainingZone), gear, and the station sign on the canopy fascia.
local function buildBay(ctx, station, signFront)
	local bay = ctx:group('Training_' .. station.Id)
	local hw, hd = BAY.width / 2, BAY.depth / 2
	local pad = bay:box('TrainingZone', V(-hw + 0.55, 0, -hd + 0.55), V(hw - 0.55, 0.25, hd - 0.55), station.Color, M.Rubber)
	pad:SetAttribute('StationId', station.Id)
	for _, edge in { { V(-hw + 0.5, 0, -hd + 0.5), V(hw - 0.5, 0.3, -hd + 0.9) }, { V(-hw + 0.5, 0, hd - 0.9), V(hw - 0.5, 0.3, hd - 0.5) },
		{ V(-hw + 0.5, 0, -hd + 0.5), V(-hw + 0.9, 0.3, hd - 0.5) }, { V(hw - 0.9, 0, -hd + 0.5), V(hw - 0.5, 0.3, hd - 0.5) } } do
		bay:box('PadEdging', edge[1], edge[2], P.white, M.SmoothPlastic)
	end
	local equipment = bay:group('Equipment')
	local swing = equipment:group('Swing')
	-- The client sways everything in Swing about this point (local X axis) while the bay is in use.
	ghost(equipment:part('Hinge', V(0.2, 0.2, 0.2), CFrame.new(0, BAY.armY - 0.3, BAY.hangZ), P.white))
	GEAR[station.Gear](swing, equipment)
	local sign = bay:box('Sign', V(-hw + 0.8, signFront.Y, signFront.Z - 0.3), V(hw - 0.8, signFront.Y + 2.4, signFront.Z), P.black, M.SmoothPlastic)
	signText(sign, 'x' .. station.Multiplier .. ' POWER', station.Required == 0 and 'FREE • TRAIN HERE' or compact(station.Required) .. ' POWER NEEDED', station.Color)
	return bay
end

-- A row of bays sharing one steel gantry (posts at every bay boundary, header beam, bag arms, canopy).
-- Row frame: bays sit along local X at the given offsets, -Z faces the aisle.
local function buildRow(ctx, stations, offsets, backWall)
	local row = ctx:group('BayRow')
	local hw, hd = BAY.width / 2, BAY.depth / 2
	local x0, x1 = math.huge, -math.huge
	for _, x in offsets do x0 = math.min(x0, x - hw); x1 = math.max(x1, x + hw) end
	local backZ = hd + 0.6
	for i = 0, #offsets do
		local x = x0 + i * BAY.width
		row:box('GantryPost', V(x - 0.45, 0, backZ - 0.45), V(x + 0.45, 12.4, backZ + 0.45), P.iron, M.Metal)
		row:box('PostFoot', V(x - 0.8, 0, backZ - 0.8), V(x + 0.8, 0.35, backZ + 0.8), P.steel, M.Metal)
	end
	row:box('Header', V(x0 - 0.45, BAY.armY, backZ - 0.45), V(x1 + 0.45, BAY.armY + 1, backZ + 0.45), P.iron, M.Metal)
	-- Canopy: corrugated roof on cantilever beams, fascia carries the station signs.
	for i = 0, #offsets do
		local x = x0 + i * BAY.width
		row:bar('CanopyBeam', V(x, 12.4, backZ + 0.45), V(x, 12.4, -hd + 1.2), 0.5, P.iron)
		row:bar('CanopyBrace', V(x, 9.6, backZ), V(x, 12.15, -hd + 4), 0.3, P.iron)
	end
	for i = 0, math.floor((x1 - x0) / 1.1) - 1 do
		local a = x0 - 0.45 + i * 1.1
		row:box('RoofRib', V(a, 12.8, -hd + 0.75), V(a + 0.55, 13.0, backZ + 0.85), C(150, 158, 164), M.Metal)
	end
	row:box('Roof', V(x0 - 0.45, 12.65, -hd + 0.6), V(x1 + 0.45, 12.8, backZ + 0.9), C(128, 136, 142), M.Metal)
	row:box('Fascia', V(x0 - 0.5, 11.9, -hd + 0.3), V(x1 + 0.5, 13.2, -hd + 0.7), P.iron, M.Metal)
	for i, x in offsets do
		row:bar('BagArm', V(x, BAY.armY + 0.5, backZ), V(x, BAY.armY + 0.5, BAY.hangZ - 0.6), 0.55, P.iron)
		row:box('ArmPlate', V(x - 0.5, BAY.armY + 0.05, BAY.hangZ - 0.5), V(x + 0.5, BAY.armY + 0.25, BAY.hangZ + 0.5), P.steel, M.Metal)
		buildBay(row:at(CFrame.new(x, 0, 0)), stations[i], V(0, 9.5, -hd + 0.3))
		local lamp = row:box('BayLamp', V(x - 1.2, 12.3, -0.4), V(x + 1.2, 12.65, 0.4), C(255, 244, 214), M.Neon)
		light(lamp, C(255, 236, 200), 0.9, 14)
	end
	if backWall == 'brick' then
		brickWall(row:at(CFrame.new(0, 0, backZ + 1.05)), 'BackWall', x0 - 0.45, x1 + 0.45, -0.6, 0.6, 14, P.brick, BAY.width)
	else
		-- Knee wall with chain-link above, so the plaza can see inside.
		row:box('KneeWall', V(x0 - 0.45, 0, backZ + 0.45), V(x1 + 0.45, 2.6, backZ + 1.65), P.brick, M.Brick)
		row:box('KneeCoping', V(x0 - 0.6, 2.6, backZ + 0.3), V(x1 + 0.6, 3, backZ + 1.8), P.coping, M.Concrete)
		for i = 0, #offsets - 1 do
			chainLink(row, x0 + i * BAY.width + 0.45, x0 + (i + 1) * BAY.width - 0.45, backZ + 1.05, 3, 6.8, false)
		end
	end
	return row
end

-- The champion's ring: 18x18 on a 2.4-stud platform, ropes walk-through so players can climb in from the steps.
local RING = { size = 18, height = 2.4 }
Lobby.Ring = RING
function Lobby.buildRing(ctx, trainingFolder, station)
	local ring = ctx:into(trainingFolder):group('Training_' .. station.Id)
	local h, s = RING.height, RING.size / 2
	ring:box('Platform', V(-s, 0, -s), V(s, h - 0.25, s), P.black, M.SmoothPlastic)
	for _, side in { -1, 1 } do
		for _, axis in { 'x', 'z' } do
			local a = axis == 'x' and V(-s - 0.05, 0.15, side * s - 0.05 * side) or V(side * s - 0.05 * side, 0.15, -s - 0.05)
			local b = axis == 'x' and V(s + 0.05, h - 0.4, side * (s + 0.05)) or V(side * (s + 0.05), h - 0.4, s + 0.05)
			local skirt = ring:box('Skirt', a, b, P.red, M.Fabric)
			local g = surface(skirt, axis == 'x' and (side > 0 and Enum.NormalId.Back or Enum.NormalId.Front) or (side > 0 and Enum.NormalId.Right or Enum.NormalId.Left), 0.2)
			text(g, 'Brand', 'THE BLOCK', P.white, Enum.Font.LuckiestGuy, 0.1, 0.8)
		end
	end
	local pad = ring:box('TrainingZone', V(-s, h - 0.25, -s), V(s, h, s), C(232, 230, 222), M.Fabric)
	pad:SetAttribute('StationId', station.Id)
	ring:box('CanvasLogo', V(-4, h, -4), V(4, h + 0.02, 4), station.Color, M.Fabric)
	local equipment = ring:group('Equipment')
	local corners = { { -1, -1, P.red }, { 1, 1, P.blue }, { -1, 1, P.white }, { 1, -1, P.white } }
	for _, c in corners do
		local x, z = c[1] * (s - 0.6), c[2] * (s - 0.6)
		equipment:post('CornerPost', 0.4, 4.8, V(x, h, z), P.steel)
		equipment:box('CornerPad', V(x - 0.6, h + 0.9, z - 0.6), V(x + 0.6, h + 4.3, z + 0.6), c[3], M.Fabric)
	end
	local ropeColor = { P.red, P.white, P.blue }
	for level = 1, 3 do
		local y = h + 0.9 + level * 1.15
		for _, e in { { V(-1, 0, -1), V(1, 0, -1) }, { V(1, 0, -1), V(1, 0, 1) }, { V(1, 0, 1), V(-1, 0, 1) }, { V(-1, 0, 1), V(-1, 0, -1) } } do
			local a, b = e[1] * (s - 0.6) + V(0, y, 0), e[2] * (s - 0.6) + V(0, y, 0)
			local rope = equipment:bar('Rope', a, b, 0.24, ropeColor[level], M.Fabric)
			rope.CanCollide = false
		end
	end
	-- Steps up to the apron on the -Z side, off to one side so the skirt lettering stays readable.
	for i = 1, 2 do
		ring:box('RingStep', V(s - 6.5, 0, -s - (3 - i) * 0.9), V(s - 2, i * 0.8, -s - (2 - i) * 0.9), P.steel, M.DiamondPlate)
	end
	-- Light rig: four truss towers and a square frame with spotlights over the canvas.
	for _, c in corners do
		local x, z = c[1] * (s + 1.6), c[2] * (s + 1.6)
		equipment:box('TrussTower', V(x - 0.5, 0, z - 0.5), V(x + 0.5, 16, z + 0.5), P.iron, M.Metal)
	end
	for _, e in { { V(-1, 0, -1), V(1, 0, -1) }, { V(1, 0, -1), V(1, 0, 1) }, { V(1, 0, 1), V(-1, 0, 1) }, { V(-1, 0, 1), V(-1, 0, -1) } } do
		equipment:bar('TrussBeam', e[1] * (s + 1.6) + V(0, 15.5, 0), e[2] * (s + 1.6) + V(0, 15.5, 0), 0.9, P.iron)
	end
	for _, x in { -(s - 2), s - 2 } do
		equipment:bar('LampBeam', V(x, 15.5, -s - 1.6), V(x, 15.5, s + 1.6), 0.6, P.iron)
	end
	for _, c in corners do
		local lamp = equipment:box('RingLamp', V(c[1] * (s - 2) - 0.7, 14.75, c[2] * (s - 2) - 0.7), V(c[1] * (s - 2) + 0.7, 15.2, c[2] * (s - 2) + 0.7), C(255, 250, 230), M.Neon)
		light(lamp, C(255, 246, 226), 1.4, 20)
	end
	local sign = ring:box('Sign', V(-7, 15.95, -s - 1.95), V(7, 18.95, -s - 1.6), P.black, M.SmoothPlastic)
	signText(sign, 'CHAMP RING  x' .. station.Multiplier, compact(station.Required) .. ' POWER NEEDED', station.Color)
	ring.parent:SetAttribute('StationId', station.Id)
	return ring
end

-- Gym frame: origin at the centre of the aisle at the entrance arch, the aisle runs toward -Z.
local GYM = { aisle = 9, wallHeight = 14 }
Lobby.Gym = GYM
GYM.rowX = GYM.aisle / 2 + BAY.depth / 2
GYM.halfWidth = GYM.rowX + BAY.depth / 2 + 0.6 + 1.65
GYM.length = 4 * BAY.width + 3

function Lobby.buildGym(ctx, trainingFolder, stations)
	local gym = ctx:group('BoxingClub')
	local training = gym:into(trainingFolder)
	local hw, len = GYM.halfWidth, GYM.length
	-- Rubber floor over the whole club (under the walls too), yellow aisle lines.
	gym:box('GymFloor', V(-hw + 0.3, -0.2, -len), V(hw - 0.3, 0.1, 2.4), P.rubber, M.Rubber)
	for _, x in { -GYM.aisle / 2 + 0.4, GYM.aisle / 2 - 0.4 } do
		gym:box('AisleLine', V(x - 0.15, 0.1, -len + 0.6), V(x + 0.15, 0.13, -0.6), P.yellow, M.SmoothPlastic)
	end
	-- Bays alternate sides walking in, cheapest at the entrance, in config order.
	local left, right = {}, {}
	for i = 1, 8 do table.insert(i % 2 == 1 and left or right, stations[i]) end
	local offsets = {}
	for k = 1, 4 do offsets[k] = (k - 2.5) * BAY.width end
	local mid = -2 * BAY.width
	-- The -X row faces +X (rotated -90 degrees), so its local +X runs toward the entrance: first bay is the last offset.
	buildRow(training:at(CFrame.new(-GYM.rowX, 0, mid) * CFrame.Angles(0, -math.pi / 2, 0)), { left[4], left[3], left[2], left[1] }, offsets, 'brick')
	buildRow(training:at(CFrame.new(GYM.rowX, 0, mid) * CFrame.Angles(0, math.pi / 2, 0)), right, offsets, 'fence')
	-- Far wall with the club banner, short returns closing the corners behind the last bays.
	local wallX = hw - 0.6
	brickWall(gym:at(CFrame.new(0, 0, -len - 0.6)), 'FarWall', -hw, hw, -0.6, 0.6, GYM.wallHeight, P.brick, BAY.width)
	for _, side in { -1, 1 } do
		gym:box('CornerReturn', V(side * wallX - 0.6, 0, -len), V(side * wallX + 0.6, GYM.wallHeight, -4 * BAY.width - 0.45), P.brick, M.Brick)
		gym:box('CornerReturnCap', V(side * wallX - 0.9, GYM.wallHeight, -len), V(side * wallX + 0.9, GYM.wallHeight + 0.5, -4 * BAY.width - 0.45), P.coping, M.Concrete)
	end
	local banner = gym:box('Banner', V(-9, 4.5, -len + 0.4), V(9, 10.5, -len + 0.65), P.black, M.Fabric)
	local bg = surface(banner, Enum.NormalId.Back, 0.1)
	text(bg, 'Club', 'BLOCK BOXING CLUB', P.yellow, Enum.Font.LuckiestGuy, 0.08, 0.56, C(120, 40, 20))
	text(bg, 'Motto', 'EVERY ROUND COUNTS', P.white, Enum.Font.GothamBlack, 0.68, 0.24)
	-- Entrance arch, flush with the row walls.
	gym:box('ArchPierLeft', V(-hw - 0.3, 0, 0.45), V(-hw + 2.4, 17, 2.6), P.brickDark, M.Brick)
	gym:box('ArchPierRight', V(hw - 2.4, 0, 0.45), V(hw + 0.3, 17, 2.6), P.brickDark, M.Brick)
	local arch = gym:box('ArchSign', V(-hw + 2.4, 13.4, 0.8), V(hw - 2.4, 17, 2.1), P.black, M.SmoothPlastic)
	local ag = surface(arch, Enum.NormalId.Back, 0)
	text(ag, 'Club', 'BLOCK BOXING CLUB', P.yellow, Enum.Font.LuckiestGuy, 0.08, 0.6, C(120, 40, 20))
	text(ag, 'Tag', 'STAND ON A MAT TO TRAIN • BIGGER BAG = MORE POWER', P.white, Enum.Font.GothamBold, 0.7, 0.24)
	gym:box('ArchCap', V(-hw - 0.6, 17, 0.15), V(hw + 0.6, 17.7, 2.7), P.coping, M.Concrete)
	return gym
end

---------------------------------------------------------------------------------------------- courtyard
-- Rowhouse facade along local X; the face is at z = 0, the building mass extends toward +Z, the courtyard is at -Z.
local function rowhouse(ctx, name, x0, x1, stories, color, stoop)
	local b = ctx:group(name)
	local h = 7 + stories * 8
	b:box('Mass', V(x0, 0, 0), V(x1, h, 12), color, M.Brick)
	b:box('BaseCourse', V(x0, 0, -0.3), V(x1, 1.4, 0), P.coping, M.Concrete)
	b:box('Cornice', V(x0 - 0.2, h, -1), V(x1 + 0.2, h + 1, 0.4), P.coping, M.Concrete)
	b:box('CorniceCap', V(x0 - 0.4, h + 1, -1.3), V(x1 + 0.4, h + 1.4, 0.4), P.coping, M.Concrete)
	local bays = math.max(1, math.floor((x1 - x0) / 6))
	local w = (x1 - x0) / bays
	for s = 1, stories do
		local y = 7 + (s - 1) * 8
		b:box('StoryBand', V(x0, y - 0.3, -0.25), V(x1, y + 0.2, 0), P.coping, M.Concrete)
		for i = 1, bays do
			local x = x0 + (i - 0.5) * w
			b:box('Window', V(x - 1.4, y + 1.4, -0.05), V(x + 1.4, y + 6, 0.02), (i + s) % 3 == 0 and C(232, 196, 120) or C(54, 74, 86), M.Glass)
			b:box('Sill', V(x - 1.8, y + 1.0, -0.6), V(x + 1.8, y + 1.4, 0), P.coping, M.Concrete)
			b:box('Lintel', V(x - 1.8, y + 6, -0.4), V(x + 1.8, y + 6.6, 0), P.coping, M.Concrete)
			b:box('Mullion', V(x - 0.1, y + 1.4, -0.12), V(x + 0.1, y + 6, 0), C(220, 214, 200), M.SmoothPlastic)
		end
	end
	if stoop then
		local x = (x0 + x1) / 2
		b:box('Door', V(x - 1.8, 2.4, -0.1), V(x + 1.8, 9.2, 0.05), C(60, 44, 34), M.Wood)
		b:box('DoorFrame', V(x - 2.4, 9.2, -0.5), V(x + 2.4, 10, 0), P.coping, M.Concrete)
		for i = 1, 3 do
			b:box('StoopStep', V(x - 3, 0, -(4 - i) * 1.3), V(x + 3, i * 0.8, 0), C(196, 188, 172), M.Concrete)
		end
		for _, side in { -1, 1 } do
			b:bar('StoopRail', V(x + side * 3.1, 2.4, -3.9), V(x + side * 3.1, 4.6, -0.2), 0.16, P.iron)
			b:post('RailNewel', 0.18, 3.1, V(x + side * 3.1, 0, -3.9), P.iron)
		end
	end
	return b
end

local function lamp(ctx, pos)
	local m = ctx:group('StreetLamp')
	m:post('Base', 0.55, 0.8, pos, P.iron)
	m:post('Pole', 0.2, 13, pos, P.iron)
	m:bar('Arm', pos + V(0, 12.6, 0), pos + V(0, 12.6, -2.2), 0.22, P.iron)
	local globe = m:blob('Lantern', V(1.4, 1.6, 1.4), pos + V(0, 12, -2.2), C(255, 226, 170), M.Neon)
	light(globe, C(255, 214, 160), 1, 22)
	return m
end
local function planterTree(ctx, pos, seed)
	local t = ctx:group('PlanterTree')
	t:box('Planter', pos + V(-2.5, 0, -2.5), pos + V(2.5, 1.6, 2.5), P.brickDark, M.Brick)
	t:box('PlanterCap', pos + V(-2.8, 1.6, -2.8), pos + V(2.8, 1.9, 2.8), P.coping, M.Concrete)
	t:box('Soil', pos + V(-2.2, 1.6, -2.2), pos + V(2.2, 1.75, 2.2), C(84, 64, 46), M.Ground)
	t:post('Trunk', 0.45, 7, pos + V(0, 1.6, 0), C(104, 78, 52), M.Wood)
	for i = 0, 3 do
		local a = (seed + i) * 1.7
		local off = V(math.cos(a) * 1.6, 7.6 + (i % 2) * 1.4, math.sin(a) * 1.6)
		t:blob('Leaves', V(5.2, 4.2, 5.2), pos + off, C(76 + i * 8, 136 + i * 6, 62), M.Grass).CanCollide = false
	end
	return t
end
-- Park bench at pos; sitters look along `facing`.
local function bench(ctx, pos, facing)
	local b = ctx:at(CFrame.lookAt(pos, pos + facing)):group('Bench')
	for _, x in { -2.6, 2.6 } do b:box('BenchLeg', V(x - 0.2, 0, -0.8), V(x + 0.2, 1.6, 0.8), P.iron, M.Metal) end
	for i = -1, 1 do b:box('Slat', V(-3.2, 1.5, i * 0.55 - 0.22), V(3.2, 1.75, i * 0.55 + 0.22), P.wood, M.WoodPlanks) end
	for i = 0, 1 do b:box('BackSlat', V(-3.2, 2.2 + i * 0.6, 0.75), V(3.2, 2.6 + i * 0.6, 0.95), P.wood, M.WoodPlanks) end
	b:box('BackPost', V(-2.8, 1.6, 0.8), V(-2.6, 3.4, 1.0), P.iron, M.Metal)
	b:box('BackPost', V(2.6, 1.6, 0.8), V(2.8, 3.4, 1.0), P.iron, M.Metal)
	return b
end
-- Sagging festoon wire between two points with warm bulbs; optional sneakers slung over the middle.
local function stringLights(ctx, a, b, sag, sneakers)
	local g = ctx:group('StringLights')
	local n = 14
	local function at(t) return a:Lerp(b, t) - V(0, sag * 4 * t * (1 - t), 0) end
	local colors = { C(255, 214, 120), C(255, 120, 90), C(120, 220, 255), C(255, 236, 170) }
	for i = 0, n - 1 do
		g:bar('Wire', at(i / n), at((i + 1) / n), 0.06, P.iron).CastShadow = false
		if i > 0 then
			local bulb = g:blob('Bulb', V(0.42, 0.55, 0.42), at(i / n) - V(0, 0.35, 0), colors[i % #colors + 1], M.Neon)
			bulb.CanCollide = false
			bulb.CastShadow = false
		end
	end
	if sneakers then
		local mid = at(0.5)
		for k, side in { -1, 1 } do
			local hang = mid + V(side * 0.45, -1.4 - k * 0.2, 0)
			g:bar('Lace', mid, hang + V(0, 0.4, 0), 0.05, P.white, M.Fabric).CanCollide = false
			local shoe = g:at(CFrame.new(hang) * CFrame.Angles(math.rad(70), 0, math.rad(side * 8)))
			shoe:box('Sneaker', V(-0.35, -0.3, -0.75), V(0.35, 0.3, 0.75), P.white, M.Leather).CanCollide = false
			shoe:box('Sole', V(-0.37, -0.42, -0.77), V(0.37, -0.28, 0.77), P.red, M.Rubber).CanCollide = false
			shoe:box('Swoosh', V(-0.37, -0.1, -0.4), V(0.37, 0.05, 0.3), P.red, M.SmoothPlastic).CanCollide = false
		end
	end
	return g
end
local function foodTruck(ctx, cf)
	local t = ctx:at(cf):group('FoodTruck')
	-- Local frame: truck runs along X, serving hatch faces -Z.
	t:box('Body', V(-8, 1.4, -3.2), V(4, 9, 3.2), C(250, 206, 64), M.Metal)
	t:box('Cab', V(4, 1.4, -3.1), V(8.4, 7, 3.1), C(250, 206, 64), M.Metal)
	t:box('Windshield', V(8.4, 4.4, -2.6), V(8.5, 6.6, 2.6), C(60, 84, 96), M.Glass)
	t:box('Hatch', V(-6.5, 4.2, -3.25), V(2.5, 7.4, -3.15), C(40, 34, 30), M.SmoothPlastic)
	t:box('Counter', V(-6.8, 3.9, -4.4), V(2.8, 4.2, -3.2), P.steel, M.Metal)
	local flap = t:box('HatchFlap', V(-6.8, 7.4, -5.4), V(2.8, 7.6, -3.2), C(230, 70, 60), M.Metal)
	flap.CFrame = flap.CFrame * CFrame.Angles(math.rad(-12), 0, 0)
	local sign = t:box('Menu', V(-6, 7.9, -3.3), V(2, 8.9, -3.2), P.black, M.SmoothPlastic)
	local sg = surface(sign, Enum.NormalId.Front, 0)
	text(sg, 'Name', 'BLOCK EATS • CHOPPED CHEESE', P.yellow, Enum.Font.LuckiestGuy, 0.05, 0.9)
	for _, x in { -5.5, 5.6 } do
		for _, z in { -3.2, 3.2 } do
			t:rod('Wheel', 1.2, 0.9, CFrame.new(x, 1.2, z) * CFrame.Angles(0, math.pi / 2, 0), C(30, 30, 32), M.Rubber)
			t:rod('Hub', 0.55, 0.94, CFrame.new(x, 1.2, z) * CFrame.Angles(0, math.pi / 2, 0), P.chain, M.Metal)
		end
	end
	t:box('Bumper', V(8.4, 1.2, -3), V(8.8, 2, 3), P.chain, M.Metal)
	return t
end
local function picnicTable(ctx, pos)
	local t = ctx:at(CFrame.new(pos)):group('PicnicTable')
	t:box('Top', V(-3, 2.6, -1.4), V(3, 2.9, 1.4), P.wood, M.WoodPlanks)
	for _, z in { -2.4, 2.4 } do t:box('Seat', V(-3, 1.4, z - 0.6), V(3, 1.65, z + 0.6), P.wood, M.WoodPlanks) end
	for _, x in { -2.2, 2.2 } do
		t:box('Frame', V(x - 0.2, 0, -2.8), V(x + 0.2, 1.4, 2.8), P.iron, M.Metal)
		t:box('Leg', V(x - 0.2, 1.4, -0.3), V(x + 0.2, 2.6, 0.3), P.iron, M.Metal)
	end
	return t
end
local function dumpster(ctx, cf)
	local d = ctx:at(cf):group('Dumpster')
	d:box('Bin', V(-3.5, 0.4, -2), V(3.5, 4.4, 2), C(46, 112, 74), M.Metal)
	d:box('Lid', V(-3.6, 4.4, -2.1), V(3.6, 4.7, 2.1), C(34, 34, 36), M.Rubber)
	for _, x in { -3, 3 } do d:box('Skid', V(x - 0.3, 0, -2), V(x + 0.3, 0.4, 2), P.iron, M.Metal) end
	for i, o in { V(4.5, 0, -1), V(4.9, 0, 0.8), V(-4.6, 0, 0.4) } do d:blob('TrashBag', V(1.6, 1.5 + i * 0.1, 1.5), o + V(0, 0.75, 0), C(30, 30, 34), M.Fabric) end
	return d
end
local function kiosk(ctx, cf)
	local k = ctx:at(cf):group('CornerKiosk')
	-- Local frame: counter faces -Z.
	k:box('Booth', V(-6, 0, -3), V(6, 9, 4), P.brickTan, M.Brick)
	k:box('Opening', V(-5, 3.2, -3.05), V(5, 7.4, -2.6), C(40, 34, 30), M.SmoothPlastic)
	k:box('Counter', V(-5.2, 3, -3.8), V(5.2, 3.3, -2.6), P.coping, M.Concrete)
	k:box('Roof', V(-6.4, 9, -3.4), V(6.4, 9.6, 4.4), P.coping, M.Concrete)
	for i = 0, 7 do
		local x0 = -6 + i * 1.5
		local stripe = k:box('Awning', V(x0, 7.6, -5.4), V(x0 + 1.5, 7.8, -3), i % 2 == 0 and C(46, 140, 90) or P.white, M.Fabric)
		stripe.CFrame = stripe.CFrame * CFrame.Angles(math.rad(-14), 0, 0)
	end
	local sign = k:box('Sign', V(-6, 9.6, -3.4), V(6, 11.6, -3.1), C(46, 140, 90), M.SmoothPlastic)
	local sg = surface(sign, Enum.NormalId.Front, 0)
	text(sg, 'Name', 'SUNNY SIDE BODEGA', P.white, Enum.Font.LuckiestGuy, 0.08, 0.84)
	for i, c in { P.red, P.yellow, P.lime, P.orange } do k:blob('Fruit', V(0.8, 0.8, 0.8), V(-3 + i * 1.2, 3.7, -3.3), c, M.SmoothPlastic) end
	return k
end

local function graffiti(ctx, name, a, b, value, color, bg, face)
	local panel = ctx:box(name, a, b, bg or P.brick, M.Brick)
	if not bg then panel.Transparency = 1 end
	local g = surface(panel, face, 0.15)
	text(g, 'Tag', value, color, Enum.Font.PermanentMarker, 0.05, 0.9, P.black)
	return panel
end


-- Lobby layout in map-local studs (the TheBlock frame); y is measured from the courtyard floor.
-- The courtyard is walled on all sides; -Z leads out through the Stage 1 gate onto the avenue.
local LAYOUT = {
	x0 = -75, x1 = 75, z0 = 27, z1 = 122, floorY = 1.6, wall = 1.2,
	plazaHalf = 16,
	spawn = V(0, 0, 108),
	ring = V(0, 0, 58),
	gym = V(-26.8, 0, 84),
	shop = V(52.8, 0, 74),
	courtX = 30,
	-- Every group directly under TheBlock (or TheBlock.Environment) is checked, except the map's infrastructure.
	-- A piece is backed up when any of its parts stands 1.5+ studs inside the walls and rises above the new floor;
	-- old ground surfaces stay hidden under the raised floor.
	protectedGroups = { Ground = true, ElevatedRail = true, LayoutMarkers = true, Obstacles = true, Environment = true },
	keep = { JuniperTrain = true, WalkthroughBounds = true, BlockArrival = true },
}
Lobby.Layout = LAYOUT

local function perimeterWall(ctx, name, a, b, height)
	local w = ctx:box(name, a, b, P.brick, M.Brick)
	ctx:box(name .. 'Coping', V(math.min(a.X, b.X) - 0.3, height, math.min(a.Z, b.Z) - 0.3), V(math.max(a.X, b.X) + 0.3, height + 0.5, math.max(a.Z, b.Z) + 0.3), P.coping, M.Concrete)
	return w
end

local function buildCourtyard(ctx, boards)
	local L = LAYOUT
	local yard = ctx:group('Courtyard')
	local wx0, wx1, wz0 = L.x0 + L.wall, L.x1 - L.wall, L.z0 + L.wall
	-- One paver slab under everything; inlays sit on top with their own heights, so no faces are coplanar.
	yard:box('Pavers', V(L.x0, -1.2, L.z0), V(L.x1, 0, L.z1), P.sidewalk, M.Pavement)
	yard:box('PlazaAsphalt', V(-L.plazaHalf, 0, wz0), V(L.plazaHalf, 0.05, 98), P.asphalt, M.Asphalt)
	for z = wz0 + 2, 90, 7 do
		if math.abs(z + 1.75 - L.ring.Z) > 13 then yard:box('LaneDash', V(-0.2, 0.05, z), V(0.2, 0.08, z + 3.5), P.yellow, M.SmoothPlastic) end
	end
	for x = -L.plazaHalf + 1.5, L.plazaHalf - 1.5, 3 do yard:box('Crosswalk', V(x - 0.8, 0.05, 91.5), V(x + 0.8, 0.08, 96.5), P.paint, M.SmoothPlastic) end
	for _, side in { -1, 1 } do
		yard:box('PlazaEdge', V(side * L.plazaHalf - 0.25, 0, wz0), V(side * L.plazaHalf + 0.25, 0.12, 98), P.curb, M.Concrete)
	end
	-- Spawn medallion.
	local function disc(name, d, y, color)
		return yard:part(name, V(0.1, d, d), CFrame.new(L.spawn + V(0, y, 0)) * CFrame.Angles(0, 0, math.pi / 2), color, M.SmoothPlastic, Enum.PartType.Cylinder)
	end
	disc('SpawnMedallion', 16, 0.05, P.coping).Material = M.Concrete
	disc('SpawnRing', 12.5, 0.07, P.yellow)
	disc('SpawnCentre', 10.5, 0.09, P.black)

	-- Back: five rowhouses shoulder to shoulder (facades on z1, masses behind it).
	local back = yard:at(CFrame.new(0, 0, L.z1))
	local houses = { { -75, -45, 3, P.brickTan, false }, { -45, -17, 4, P.brick, true }, { -17, 17, 4, P.brickDark, false }, { 17, 45, 3, P.brick, true }, { 45, 75, 4, P.brickTan, false } }
	for i, h in houses do rowhouse(back, 'Rowhouse' .. i, h[1], h[2], h[3], h[4], h[5]) end
	local mural = back:box('WelcomeMural', V(-15, 1.6, -0.15), V(15, 6.6, 0), P.teal, M.SmoothPlastic)
	local mg = surface(mural, Enum.NormalId.Front, 0.1)
	text(mg, 'Tag', 'WELCOME TO THE BLOCK', P.yellow, Enum.Font.PermanentMarker, 0.08, 0.84, C(40, 30, 80))

	-- Sides: perimeter brick walls, interrupted where the gym's far wall and the shop's back wall take over.
	local gymSpan = GYM.halfWidth
	perimeterWall(yard, 'WestWall', V(L.x0, 0, wz0), V(wx0, 14, L.gym.Z - gymSpan), 14)
	perimeterWall(yard, 'WestWall', V(L.x0, 0, L.gym.Z + gymSpan), V(wx0, 14, L.z1), 14)
	local shopSpan = SHOP.halfWidth + 1
	perimeterWall(yard, 'EastWall', V(wx1, 0, wz0), V(L.x1, 14, L.shop.Z - shopSpan), 14)
	perimeterWall(yard, 'EastWall', V(wx1, 0, L.shop.Z + shopSpan), V(L.x1, 14, L.z1), 14)

	-- Front: knee wall with iron railings, the Stage 1 gate in the middle.
	for _, side in { -1, 1 } do
		local a, b = side * (L.plazaHalf + 2.4), side * L.x1
		local lo, hi = math.min(a, b), math.max(a, b)
		yard:box('FrontKneeWall', V(lo, 0, L.z0), V(hi, 3, wz0), P.brick, M.Brick)
		yard:box('FrontKneeCoping', V(lo, 3, L.z0 - 0.2), V(hi, 3.4, wz0 + 0.2), P.coping, M.Concrete)
		local rail = yard:group('FrontRailing')
		local n = math.floor((hi - lo) / 2.5)
		for i = 0, n do rail:box('Picket', V(lo + (hi - lo) * i / n - 0.1, 3.4, L.z0 + 0.5), V(lo + (hi - lo) * i / n + 0.1, 8.2, L.z0 + 0.7), P.iron, M.Metal) end
		rail:box('RailTop', V(lo, 8.2, L.z0 + 0.4), V(hi, 8.5, L.z0 + 0.8), P.iron, M.Metal)
		rail:box('RailMid', V(lo, 5.6, L.z0 + 0.45), V(hi, 5.8, L.z0 + 0.75), P.iron, M.Metal)
		yard:box('GatePier', V(side * L.plazaHalf - (side > 0 and 0 or 2.4), 0, L.z0 - 0.4), V(side * L.plazaHalf + (side > 0 and 2.4 or 0), 19, wz0 + 0.4), P.brickDark, M.Brick)
		yard:box('GatePierCap', V(side * L.plazaHalf - (side > 0 and 0.3 or 2.7), 19, L.z0 - 0.7), V(side * L.plazaHalf + (side > 0 and 2.7 or 0.3), 19.8, wz0 + 0.7), P.coping, M.Concrete)
	end
	local gate = yard:box('GateSign', V(-L.plazaHalf, 15, L.z0 + 0.1), V(L.plazaHalf, 19, wz0 - 0.1), P.black, M.SmoothPlastic)
	local inner = surface(gate, Enum.NormalId.Back, 0)
	text(inner, 'Title', 'STAGE 1  →', P.yellow, Enum.Font.LuckiestGuy, 0.06, 0.6, C(120, 40, 20))
	text(inner, 'Detail', 'LEAVE THE BLOCK • BREAK THE WALLS', P.white, Enum.Font.GothamBold, 0.7, 0.24)
	local outer = surface(gate, Enum.NormalId.Front, 0)
	text(outer, 'Title', 'THE BLOCK', P.yellow, Enum.Font.LuckiestGuy, 0.06, 0.6, C(120, 40, 20))
	text(outer, 'Detail', 'TRAIN • DRIP • COME UP', P.white, Enum.Font.GothamBold, 0.7, 0.24)
	-- Three steps down to the avenue (asphalt sits a floorY below the courtyard).
	for i = 1, 3 do
		local top = -L.floorY * i / 4
		yard:box('GateStep', V(-L.plazaHalf, -L.floorY - 0.4, L.z0 - i * 1.4), V(L.plazaHalf, top, L.z0 - (i - 1) * 1.4), P.curb, M.Concrete)
	end

	-- Court in the front-east corner: asphalt, lines, a hoop on the east wall, chain-link toward the plaza.
	local court = yard:group('Court')
	local cx0, cz0, cz1 = L.courtX, wz0, L.shop.Z - shopSpan - 1.2
	court:box('CourtAsphalt', V(cx0, 0, cz0), V(wx1, 0.06, cz1), C(70, 92, 120), M.Asphalt)
	local function line(a, b) court:box('CourtLine', a + V(0, 0.06, 0), b + V(0, 0.09, 0), P.paint, M.SmoothPlastic) end
	line(V(cx0 + 1, 0, cz0 + 1), V(cx0 + 1.3, 0, cz1 - 1))
	line(V(cx0 + 1, 0, cz0 + 1), V(wx1 - 1, 0, cz0 + 1.3))
	line(V(cx0 + 1, 0, cz1 - 1.3), V(wx1 - 1, 0, cz1 - 1))
	local mz = (cz0 + cz1) / 2
	court:box('KeyPaint', V(wx1 - 13, 0.06, mz - 5), V(wx1, 0.08, mz + 5), C(214, 96, 52), M.SmoothPlastic)
	line(V(wx1 - 13.3, 0, mz - 5), V(wx1 - 13, 0, mz + 5))
	-- Three-point arc around the hoop, with straight runs back to the baseline.
	local hoop, r = V(wx1 - 4.6, 0.075, mz), 11
	for i = 0, 15 do
		local a, b = math.pi / 2 + i * math.pi / 16, math.pi / 2 + (i + 1) * math.pi / 16
		court:bar('ThreePoint', hoop + V(math.cos(a), 0, math.sin(a)) * r, hoop + V(math.cos(b), 0, math.sin(b)) * r, 0.25, P.paint, M.SmoothPlastic)
	end
	for _, side in { -1, 1 } do line(V(hoop.X, 0, mz + side * r - 0.125), V(wx1 - 1, 0, mz + side * r + 0.125)) end
	court:box('HoopPole', V(wx1 - 1.6, 0, mz - 0.4), V(wx1 - 0.8, 12, mz + 0.4), P.iron, M.Metal)
	court:bar('HoopArm', V(wx1 - 1.2, 11.2, mz), V(wx1 - 3, 11.2, mz), 0.4, P.iron)
	court:box('Backboard', V(wx1 - 3.3, 9.6, mz - 3), V(wx1 - 3, 13, mz + 3), P.white, M.SmoothPlastic)
	court:box('BoardSquare', V(wx1 - 3.36, 10.2, mz - 1), V(wx1 - 3.3, 11.6, mz + 1), P.red, M.SmoothPlastic)
	for i = 0, 11 do
		local a, b = i * math.pi / 6, (i + 1) * math.pi / 6
		local c = V(wx1 - 4.6, 10.4, mz)
		court:bar('Rim', c + V(math.cos(a), 0, math.sin(a)) * 1.1, c + V(math.cos(b), 0, math.sin(b)) * 1.1, 0.12, P.orange)
		court:bar('Net', c + V(math.cos(a), 0, math.sin(a)) * 1.1, c + V(math.cos(a), -2.4, math.sin(a)) * 0.7 + V(0, 0, 0), 0.05, P.white, M.Fabric).CanCollide = false
	end
	-- Chain-link along the plaza side of the court, open in the middle.
	local fenceLine = court:at(CFrame.new(cx0, 0, 0) * CFrame.Angles(0, -math.pi / 2, 0))
	for _, seg in { { cz0, mz - 5 }, { mz + 5, cz1 } } do chainLink(fenceLine, seg[1], seg[2], 0, 0, 8) end

	-- Leaderboard on the west wall, facing the plaza.
	local lb = ctx:into(boards)
	local frame = lb:box('BoardFrame', V(wx0, 2.2, 37), V(wx0 + 0.6, 15.8, 57), P.iron, M.Metal)
	local screen = lb:box('ServerLeaderboard', V(wx0 + 0.6, 2.8, 37.6), V(wx0 + 0.8, 13.2, 56.4), C(24, 30, 52), M.SmoothPlastic)
	local sg = surface(screen, Enum.NormalId.Right, 0)
	local t = text(sg, 'TextLabel', 'BLOCK LEADERS\nTHIS SERVER\nBe the first to train!', P.white, Enum.Font.GothamBlack, 0.05, 0.9, P.black)
	t.TextYAlignment = Enum.TextYAlignment.Top
	local header = lb:box('BoardHeader', V(wx0 + 0.6, 13.4, 37.6), V(wx0 + 0.9, 15.6, 56.4), P.yellow, M.SmoothPlastic)
	local hg = surface(header, Enum.NormalId.Right, 0)
	text(hg, 'Title', 'TOP POWER ON THE BLOCK', P.black, Enum.Font.LuckiestGuy, 0.08, 0.84)
	return yard
end

local function buildDecor(ctx)
	local L = LAYOUT
	local d = ctx:group('StreetLife')
	for _, p in { V(-19, 0, 36), V(19, 0, 36), V(-19, 0, 78), V(19, 0, 78), V(-11, 0, 114), V(11, 0, 114) } do lamp(d, p) end
	for i, p in { V(-30, 0, 112), V(30, 0, 112), V(-30, 0, 34), V(-62, 0, 112), V(62, 0, 104) } do planterTree(d, p, i) end
	bench(d, V(-24, 0, 106), V(1, 0, 0))
	bench(d, V(24, 0, 106), V(-1, 0, 0))
	-- Hydrant, crates and a boombox by the spawn: the block's front porch.
	local hydrant = d:group('FireHydrant')
	hydrant:post('Body', 0.6, 2.2, V(-6, 0, 100), P.red, M.Metal)
	hydrant:blob('Cap', V(1.3, 0.8, 1.3), V(-6, 2.3, 100), P.red, M.Metal)
	hydrant:rod('Outlets', 0.32, 1.8, CFrame.new(-6, 1.4, 100), P.red)
	local crates = d:group('MilkCrates')
	for i, c in { { 6, 100, 0, P.blue }, { 7.8, 100.4, 0, P.red }, { 6.8, 100.2, 1.4, P.yellow } } do
		crates:box('Crate', V(c[1] - 0.8, c[3], c[2] - 0.8), V(c[1] + 0.8, c[3] + 1.4, c[2] + 0.8), c[4], M.SmoothPlastic)
	end
	local boombox = d:group('Boombox')
	boombox:box('Body', V(6.1, 2.8, 99.6), V(7.9, 3.8, 100.6), P.black, M.SmoothPlastic)
	for _, x in { 6.5, 7.5 } do boombox:part('Speaker', V(0.1, 0.8, 0.8), CFrame.new(x, 3.3, 99.58) * CFrame.Angles(0, math.pi / 2, 0), C(70, 70, 76), M.SmoothPlastic, Enum.PartType.Cylinder) end
	boombox:box('Handle', V(6.3, 3.8, 100.0), V(7.7, 4.05, 100.2), P.steel, M.Metal)
	-- Festoon lights across the plaza, sneakers slung over the first wire.
	stringLights(d, V(-19, 12.4, 78), V(19, 12.4, 78), 2.2, true)
	stringLights(d, V(-19, 12.4, 36), V(19, 12.4, 36), 2.2, false)
	-- Front-west corner: food truck and picnic tables by the leaderboard.
	foodTruck(d, CFrame.new(-46, 0, 34) * CFrame.Angles(0, math.pi, 0))
	picnicTable(d, V(-50, 0, 47))
	picnicTable(d, V(-36, 0, 52))
	dumpster(d, CFrame.new(-62, 0, 112))
	kiosk(d, CFrame.new(57, 0, 112))
	bench(d, V(36, 0, 66), V(1, 0, 0))
	bench(d, V(36, 0, 82), V(1, 0, 0))
	-- Graffiti on the perimeter walls and the shop's flank.
	graffiti(d, 'Tag', V(L.x0 + L.wall, 3, 92 + 12), V(L.x0 + L.wall + 0.05, 9, 92 + 26), 'COME UP', P.magenta, nil, Enum.NormalId.Right)
	graffiti(d, 'Tag', V(L.x1 - L.wall - 0.05, 3, 96), V(L.x1 - L.wall, 9, 104), 'JUNIPER', P.teal, nil, Enum.NormalId.Left)
	graffiti(d, 'Tag', V(57, 3, L.shop.Z - SHOP.halfWidth - 1.05), V(71, 12, L.shop.Z - SHOP.halfWidth - 1), 'DRIP', P.yellow, nil, Enum.NormalId.Front)
	return d
end

-- True when any part of inst stands inside the courtyard walls and rises above the new floor.
local function intrudes(f, inst)
	local L = LAYOUT
	local list = inst:IsA('BasePart') and { inst } or inst:GetDescendants()
	for _, p in list do
		if p:IsA('BasePart') then
			local x, y, z, a, b, c, d, e, g, h, i, j = f:ToObjectSpace(p.CFrame):GetComponents()
			local s = p.Size
			local ex = (math.abs(a) * s.X + math.abs(b) * s.Y + math.abs(c) * s.Z) / 2
			local ey = (math.abs(d) * s.X + math.abs(e) * s.Y + math.abs(g) * s.Z) / 2
			local ez = (math.abs(h) * s.X + math.abs(i) * s.Y + math.abs(j) * s.Z) / 2
			if x + ex > L.x0 + 1.5 and x - ex < L.x1 - 1.5 and z + ez > L.z0 + 1.5 and z - ez < L.z1 - 1.5 and y + ey > L.floorY + 0.3 then return true end
		end
	end
	return false
end

-- Old pieces inside the courtyard go to a backup folder first, so nothing overlaps (Ctrl+Z or the backup restores them).
local function backupOld(root, f, backup)
	local L = LAYOUT
	local moved = {}
	local old = root:FindFirstChild('SimulatorLobby')
	if old then old.Parent = backup; table.insert(moved, 'SimulatorLobby') end
	local groups = {}
	local env = root:FindFirstChild('Environment')
	for _, parent in { root, env } do
		for _, g in parent and parent:GetChildren() or {} do
			if (g:IsA('Model') or g:IsA('Folder')) and not L.protectedGroups[g.Name] then table.insert(groups, g) end
		end
	end
	for _, group in groups do
		for _, child in group:GetChildren() do
			if (child:IsA('Model') or child:IsA('BasePart')) and not L.keep[child.Name] and intrudes(f, child) then
				child.Parent = backup
				table.insert(moved, group.Name .. '/' .. child.Name)
			end
		end
	end
	return moved
end

function Lobby.Build()
	local root = assert(workspace:FindFirstChild('TheBlock'), 'TheBlock is missing from Workspace')
	local skins = require(ReplicatedStorage.Shared.Config.Skins)
	local art = require(ReplicatedStorage.Shared.SkinArt)
	local yawValue = root:FindFirstChild('MapYawValue')
	local yaw = root:GetAttribute('MapYaw') or (yawValue and yawValue.Value) or 0
	local f = CFrame.Angles(0, yaw, 0)
	local ss = game:GetService('ServerStorage')
	local backup = Instance.new('Folder')
	backup.Name = 'BeforeHoodLobby_' .. os.date('!%Y%m%d_%H%M%S')
	backup.Parent = ss
	local moved = backupOld(root, f, backup)

	local lobby = Instance.new('Model')
	lobby.Name = 'SimulatorLobby'
	lobby.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
	lobby:SetAttribute('BuildVersion', 'HoodLobby 1')
	local function folder(name)
		local x = Instance.new('Folder')
		x.Name = name
		x.Parent = lobby
		return x
	end
	local morphs, training, boards = folder('Morphs'), folder('Training'), folder('Leaderboards')
	local ctx = newCtx(lobby, f, CFrame.new(0, LAYOUT.floorY, 0))
	buildCourtyard(ctx, boards)
	Lobby.buildGym(ctx:at(CFrame.new(LAYOUT.gym) * CFrame.Angles(0, math.pi / 2, 0)), training, skins.Stations)
	Lobby.buildShop(ctx:at(CFrame.new(LAYOUT.shop) * CFrame.Angles(0, math.pi / 2, 0)), morphs, skins, art)
	for _, s in skins.Stations do
		if s.Gear == 'Ring' then Lobby.buildRing(ctx:at(CFrame.new(LAYOUT.ring) * CFrame.Angles(0, math.pi, 0)), training, s) end
	end
	buildDecor(ctx)
	lobby.Parent = root

	-- Players arrive on the medallion, facing the gate.
	local spawn = root:FindFirstChild('BlockArrival')
	if spawn and spawn:IsA('BasePart') then
		spawn.Size = V(8, 0.2, 8)
		spawn.CFrame = f * CFrame.new(LAYOUT.spawn + V(0, LAYOUT.floorY + 0.15, 0))
		spawn.Transparency = 1
	end
	local count = 0
	for _, d in lobby:GetDescendants() do if d:IsA('BasePart') then count += 1 end end
	game:GetService('ChangeHistoryService'):SetWaypoint('Hood lobby built')
	local tally, order = {}, {}
	for _, name in moved do
		if not tally[name] then table.insert(order, name) end
		tally[name] = (tally[name] or 0) + 1
	end
	for i, name in order do order[i] = tally[name] > 1 and (name .. ' x' .. tally[name]) or name end
	print(string.format('[HoodLobby] Built %d parts. Moved to ServerStorage.%s: %s', count, backup.Name, #order > 0 and table.concat(order, ', ') or 'nothing'))
	return { parts = count, backup = backup.Name, moved = moved }
end

return Lobby
