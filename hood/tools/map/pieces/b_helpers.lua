---------------------------------------------------------------------------------------------- build context
local Ctx = {}
Ctx.__index = Ctx
local function newCtx(parent, cf) return setmetatable({ parent = parent, cf = cf }, Ctx) end
function Ctx:at(cf) return newCtx(self.parent, self.cf * cf) end
function Ctx:into(parent) return newCtx(parent, self.cf) end
function Ctx:group(name, class)
	local g = Instance.new(class or 'Model')
	g.Name = name
	g.Parent = self.parent
	return newCtx(g, self.cf), g
end
function Ctx:world(cf) return V2.Origin * self.cf * cf end
local function smooth(p)
	for _, face in { 'TopSurface', 'BottomSurface', 'FrontSurface', 'BackSurface', 'LeftSurface', 'RightSurface' } do p[face] = S.Smooth end
end
function Ctx:part(name, size, cf, color, material, shape)
	local p = Instance.new('Part')
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = V2.Origin * self.cf * cf
	p.Color = color
	p.Material = material or M.SmoothPlastic
	smooth(p)
	if shape then p.Shape = shape end
	p.Parent = self.parent
	return p
end
-- Axis-aligned box between two corners (in this context's frame).
function Ctx:box(name, a, b, color, material)
	local lo = V(math.min(a.X, b.X), math.min(a.Y, b.Y), math.min(a.Z, b.Z))
	local hi = V(math.max(a.X, b.X), math.max(a.Y, b.Y), math.max(a.Z, b.Z))
	return self:part(name, hi - lo, CFrame.new((lo + hi) / 2), color, material)
end
-- Upright cylinder standing on pos.
function Ctx:post(name, radius, height, pos, color, material)
	return self:part(name, V(height, radius * 2, radius * 2), CFrame.new(pos + V(0, height / 2, 0)) * CFrame.Angles(0, 0, math.pi / 2), color, material or M.Metal, Enum.PartType.Cylinder)
end
-- Cylinder lying along the X axis of cf.
function Ctx:rod(name, radius, length, cf, color, material)
	return self:part(name, V(length, radius * 2, radius * 2), cf, color, material or M.Metal, Enum.PartType.Cylinder)
end
-- Square bar from a to b.
function Ctx:bar(name, a, b, width, color, material)
	local dir = b - a
	local up = math.abs(dir.Unit.Y) > 0.99 and V(1, 0, 0) or V(0, 1, 0)
	return self:part(name, V(width, width, dir.Magnitude), CFrame.lookAt((a + b) / 2, b, up), color, material or M.Metal)
end
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
	p.CFrame = V2.Origin * self.cf * cf
	p.Color = color
	p.Material = material or M.SmoothPlastic
	smooth(p)
	p.Parent = self.parent
	return p
end

-- Classic Roblox studs on the top (and optionally the sides) of a part.
local function studs(p, sides)
	p.Material = M.Plastic
	p.TopSurface = S.Studs
	if sides then
		p.FrontSurface, p.BackSurface, p.LeftSurface, p.RightSurface = S.Studs, S.Studs, S.Studs, S.Studs
	end
	return p
end
local function decor(p)
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	return p
end
local function ghost(p)
	decor(p).Transparency = 1
	return p
end
local function light(p, color, brightness, range)
	local l = Instance.new('PointLight')
	l.Color, l.Brightness, l.Range, l.Shadows = color, brightness, range, false
	l.Parent = p
	return l
end

---------------------------------------------------------------------------------------------- text
-- (brief 28) Every sign is set in the references' Montserrat (Shared/Fonts: its Black for names, numbers and signs; was
-- FredokaOne, LuckiestGuy, Gotham Black and PermanentMarker). The keys stay for the builders and HoodProps.
local FONT = (function()
	local F = require(game:GetService('ReplicatedStorage').Shared.Fonts)
	return { title = F.Title, loud = F.Title, body = F.Title, tag = F.Title, number = F.Number, small = F.Body }
end)()
local function surface(p, face, ppS)
	local g = Instance.new('SurfaceGui')
	g.Name = 'Signage'
	g.Face = face or Enum.NormalId.Front
	g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	g.PixelsPerStud = ppS or 40
	g.LightInfluence = 0
	g.Parent = p
	return g
end
-- One line of text in a band of the gui (y and h are 0-1), with a clean outline. font: a Font (FONT's), or an Enum.Font
-- (the gate's pixel "Power: X" line).
local function line(gui, name, value, color, font, y, h, outline, thickness)
	local t = Instance.new('TextLabel')
	t.Name = name
	t.BackgroundTransparency = 1
	t.Position = UDim2.fromScale(0.04, y)
	t.Size = UDim2.fromScale(0.92, h)
	if typeof(font) == 'EnumItem' then t.Font = font else t.FontFace = font or FONT.title end
	t.Text = value
	t.TextColor3 = color
	t.TextScaled = true
	t.TextWrapped = true
	t.TextStrokeTransparency = 1
	if outline then
		local s = Instance.new('UIStroke')
		s.Color = outline
		s.Thickness = thickness or 2
		s.LineJoinMode = Enum.LineJoinMode.Round
		s.Parent = t
	end
	t.Parent = gui
	return t
end
-- (B31, rule 27: "make the text font way better") The references' drop shadow under floating words: a near-black twin of
-- each TextLabel, 0.09 x 0.12 studs down-right and under it (ZIndex), its outline the same ink. gw, gh: the BillboardGui's
-- size in studs (its Size is fromScale in studs). HoodClient/LabelFade keeps a twin's text, place and visibility on its
-- label's, whatever writes them (attribute ShadowOf = the label's name). Billboards only, never the stage gates' signs.
local SHADOW_INK = Color3.fromRGB(11, 11, 20)
-- (ROBUX, brief 31) Robux prices in the world: RobuxText.fmt(n) = the Robux sign (U+E002) and the number with commas.
local RobuxText = (function()
	local ok, m = pcall(function() return require(ReplicatedStorage.Shared.RobuxText) end)
	if ok and type(m) == 'table' and m.fmt then return m end
	local mark = utf8.char(0xE002)
	return { Mark = mark, fmt = function(n) return mark .. tostring(n or '') end, commas = function(n) return tostring(n or '') end }
end)()
local function dropShadow(label, gw, gh)
	if not label.Parent or label:GetAttribute('ShadowOf') or label.Parent:FindFirstChild(label.Name .. 'Shadow') then return nil end
	local sh = label:Clone()
	for _, k in sh:GetChildren() do if k:IsA('UIGradient') then k:Destroy() end end
	sh.Name = label.Name .. 'Shadow'
	sh.TextColor3 = SHADOW_INK
	sh.TextTransparency = 0.15
	local dx, dy = 0.09 / math.max(gw, 0.5), 0.12 / math.max(gh, 0.5)
	sh.Position = label.Position + UDim2.fromScale(dx, dy)
	sh:SetAttribute('ShadowOf', label.Name)
	sh:SetAttribute('ShadowDX', dx)
	sh:SetAttribute('ShadowDY', dy)
	label.ZIndex, sh.ZIndex = 2, 1
	local parent = label.Parent
	label.Parent = nil
	sh.Parent = parent
	label.Parent = parent
	return sh
end
local function shadowAll(gui)
	if not (gui and gui:IsA('BillboardGui')) then return gui end
	local w, h = gui.Size.X.Scale, gui.Size.Y.Scale
	for _, t in gui:GetChildren() do
		if t:IsA('TextLabel') and not t:GetAttribute('ShadowOf') then dropShadow(t, w, h) end
	end
	return gui
end
local function billboard(ctx, pos, w, h, rows)
	local a = ghost(ctx:part('LabelAnchor', V(0.2, 0.2, 0.2), CFrame.new(pos), P.white))
	local g = Instance.new('BillboardGui')
	g.Name = 'WorldLabel'
	g.Size = UDim2.fromScale(w, h)
	g.MaxDistance = 90
	g.LightInfluence = 0
	g.Parent = a
	for _, r in rows do line(g, r[1], r[2], r[3], r[4], r[5], r[6], P.black, 2) end
	shadowAll(g)
	return a
end
local function compact(n)
	if n >= 1e6 then return (string.format('%.1fM', n / 1e6):gsub('%.0M', 'M')) end
	if n >= 1000 then return (string.format('%.1fK', n / 1000):gsub('%.0K', 'K')) end
	return tostring(n)
end

