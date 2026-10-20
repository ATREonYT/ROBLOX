--[[
	Builds a knife skin's effects on its model (owner, Oct 20: "make the vfx for some swords way better and more
	detailed, make them better for more high end ones"; "check out the references provided from Huss valley ... Make
	them fit and logically connected to the skin of the sword"). The numbers are Shared/KnifeLook.vfx (Huss Valley's
	restraint: a few motes in the gem's colour, the theme's motif, a glint on the gem); the method is VFX-ITEMS.md.

	KnifeFx.add(model, skin, where)  where = "hand", "back" (worn) or "stand" (the lobby stands' big copy). Returns
	                                 the theme name, or nil when the skin has none (Common, Uncommon, no theme).
	KnifeFx.clear(model)             takes our effects off again.
	What it makes, all named KnifeFx* so they can be found and taken off:
	  KnifeFxArea   an invisible, massless box over the blade's parts (welded to the Handle): the "blade" emitters'
	                volume, the burst and the light sit on it (one box, so a knife cut into many wedges still emits
	                from the whole blade, never from one sliver);
	  KnifeFxShell  (void only) a bigger invisible ball round the blade the motes are pulled in from;
	  KnifeFxGem    an Attachment in the knife's biggest glowing (Neon) part that isn't the blade, else at the guard
	                (TrailBase): the glint and the halo come off the skin's gem, where Huss Valley's sparkle;
	  KnifeFx_<role> one ParticleEmitter per role (motes, motif, glint, haze), Roblox's own built-in pictures only;
	  KnifeBurst    Rate 0: Gameplay/Actions throws half of the model's Burst attribute on a slash, Gameplay/AvatarStands
	                all of it on a stand's move (a few sparkles in its colour, no flash);
	  KnifeFxLight  one soft PointLight (top tier, not worn), no shadows, never changing.
	The model's Scale attribute (KnifeService.scale: a stand's copy) scales the particle sizes. Pure Instance.new: the
	server builds it (everyone sees the same, nothing runs every frame) and the offline films build the same.
]]
local KnifeLook = require(script.Parent.KnifeLook)

local KnifeFx = {}

local function invisiblePart(name: string, size: Vector3): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.Transparency = 1
	p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow, p.Massless = false, false, false, false, true
	p.Anchored = false
	return p
end

local function isBlade(part: BasePart): boolean
	return string.find(string.lower(part.Name), "blade", 1, true) ~= nil
end

-- The blade's box in the Handle's space: over the parts named blade (his "blade_<n>", "glow_blade_<n>", the
-- stand-ins' "Blade<n>"), else over every visible part but the Handle.
local function bladeBox(model: Model, handle: BasePart): (CFrame?, Vector3?)
	local lo, hi = nil, nil
	local function add(d: BasePart)
		local r = handle.CFrame:ToObjectSpace(d.CFrame)
		local h = d.Size / 2
		local e = Vector3.new(
			math.abs(r.RightVector.X) * h.X + math.abs(r.UpVector.X) * h.Y + math.abs(r.LookVector.X) * h.Z,
			math.abs(r.RightVector.Y) * h.X + math.abs(r.UpVector.Y) * h.Y + math.abs(r.LookVector.Y) * h.Z,
			math.abs(r.RightVector.Z) * h.X + math.abs(r.UpVector.Z) * h.Y + math.abs(r.LookVector.Z) * h.Z)
		local c = r.Position
		lo = if lo then lo:Min(c - e) else c - e
		hi = if hi then hi:Max(c + e) else c + e
	end
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and d ~= handle and isBlade(d) and not string.find(d.Name, "^KnifeFx") then add(d) end
	end
	if not lo then
		for _, d in model:GetDescendants() do
			if d:IsA("BasePart") and d ~= handle and d.Transparency < 1 and not string.find(d.Name, "^KnifeFx") then add(d) end
		end
	end
	if not lo then return nil, nil end
	return CFrame.new((lo + hi) / 2), (hi - lo):Max(Vector3.one * 0.05)
end

-- The skin's gem: its biggest glowing part that isn't the blade itself (his gems, guards and cores are Neon).
local function gemOf(model: Model, area: BasePart): BasePart?
	local best, size = nil, 0
	local limit = area.Size.X * area.Size.Y * area.Size.Z * 0.5
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and d ~= area and d.Material == Enum.Material.Neon and d.Transparency < 1 and not isBlade(d) then
			local v = d.Size.X * d.Size.Y * d.Size.Z
			if v > size and v < limit then best, size = d, v end
		end
	end
	return best
end

local function weldTo(handle: BasePart, part: BasePart, at: CFrame)
	part.CFrame = handle.CFrame * at
	local w = Instance.new("Weld")
	w.Name = "KnifeFxWeld"
	w.Part0, w.Part1, w.C0 = handle, part, at
	w.Parent = part
end

function KnifeFx.clear(model: Model)
	for _, d in model:GetDescendants() do
		if string.find(d.Name, "^KnifeFx") or d.Name == "KnifeBurst" then d:Destroy() end
	end
	model:SetAttribute("Fx", nil)
	model:SetAttribute("Burst", nil)
end

local function seq(points: { { number } }): NumberSequence
	local list = {}
	for _, p in points do table.insert(list, NumberSequenceKeypoint.new(p[1], p[2])) end
	return NumberSequence.new(list)
end

local function emitter(spec, k: number): ParticleEmitter
	local e = Instance.new("ParticleEmitter")
	e.Name = "KnifeFx_" .. spec.role
	e.Texture = spec.tex
	e.Rate = spec.rate
	e.Lifetime = NumberRange.new(spec.life[1], spec.life[2])
	e.Speed = NumberRange.new(spec.speed[1] * k, spec.speed[2] * k)
	e.SpreadAngle = Vector2.new(180, 180)
	e.Color = ColorSequence.new(spec.col[1], spec.col[2])
	e.LightEmission = if spec.dark then 0 else (spec.glow or 1)
	e.LightInfluence = if spec.dark then 1 else 0
	local size = spec.size * k
	e.Size = if spec.shrink then seq({ { 0, size }, { 1, 0 } })
		elseif spec.grow then seq({ { 0, 0 }, { 0.25, size }, { 1, size * 0.4 } })
		else seq({ { 0, size * 0.7 }, { 0.15, size }, { 1, size * 0.6 } })
	local solid = 1 - (spec.alpha or 0.9)
	e.Transparency = if spec.grow then seq({ { 0, 1 }, { 0.25, solid }, { 0.7, solid }, { 1, 1 } })
		else seq({ { 0, solid }, { 0.7, solid + (1 - solid) * 0.3 }, { 1, 1 } })
	local a = spec.accel or { 0, 0, 0 }
	e.Acceleration = Vector3.new((spec.sideways or 0) + a[1], a[2], a[3]) * k
	e.Drag = spec.drag or 0.5
	e.Rotation = NumberRange.new(0, 360)
	e.RotSpeed = NumberRange.new(-(spec.spin or 0), spec.spin or 0)
	e.LockedToPart = spec.lock == true
	if spec.squash then e.Squash = NumberSequence.new(spec.squash) end
	if spec.role == "glint" then e.ZOffset = 0.3 end
	return e
end

function KnifeFx.add(model: Model, skin, where: string): string?
	KnifeFx.clear(model)
	local fx = KnifeLook.vfx(skin, where)
	if not fx then return nil end
	local handle = model:FindFirstChild("Handle", true)
	if not (handle and handle:IsA("BasePart")) then return nil end
	local at, size = bladeBox(model, handle)
	if not at then return nil end
	local area = invisiblePart("KnifeFxArea", size)
	weldTo(handle, area, at)
	area.Parent = handle.Parent
	local k = model:GetAttribute("Scale")
	k = if type(k) == "number" and k > 0 then k else 1
	-- the gem (else the guard, else the blade) and the tip
	local gemAt: Instance = area
	local gem = gemOf(model, area)
	if gem then
		local a = Instance.new("Attachment")
		a.Name = "KnifeFxGem"
		a.Parent = gem
		gemAt = a
	else
		local base = model:FindFirstChild("TrailBase", true)
		if base and base:IsA("Attachment") then gemAt = base end
	end
	local tip = model:FindFirstChild("TrailTip", true)
	local tipAt: Instance = if tip and tip:IsA("Attachment") then tip else area
	local shell: BasePart? = nil
	for _, spec in fx.emit do
		local e = emitter(spec, k)
		local parent: Instance = area
		if spec.at == "gem" then parent = gemAt elseif spec.at == "tip" then parent = tipAt end
		if spec.inward then
			if not shell then
				local s = invisiblePart("KnifeFxShell", size + Vector3.new(1.2, 0.6, 1.2) * k)
				weldTo(handle, s, at)
				s.Parent = handle.Parent
				shell = s
			end
			parent = shell :: BasePart
			pcall(function()
				e.Shape = Enum.ParticleEmitterShape.Sphere
				e.ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface
				e.ShapeInOut = Enum.ParticleEmitterShapeInOut.Inward
			end)
		elseif parent == area then
			pcall(function()
				e.Shape = Enum.ParticleEmitterShape.Box
				e.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
			end)
		end
		e.Parent = parent
	end
	if fx.burst > 0 then
		local b = emitter({ role = "burst", tex = KnifeLook.VFX.TEX.Sparkle, col = { fx.colour:Lerp(Color3.new(1, 1, 1), 0.6), fx.colour },
			rate = 0, life = { 0.3, 0.5 }, speed = { 3, 6 }, size = 0.3, drag = 5, alpha = 1 }, k)
		b.Name = "KnifeBurst"
		pcall(function()
			b.Shape = Enum.ParticleEmitterShape.Box
			b.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
		end)
		b.Parent = area
		model:SetAttribute("Burst", fx.burst)
	end
	if fx.light then
		local l = Instance.new("PointLight")
		l.Name = "KnifeFxLight"
		l.Color, l.Brightness, l.Range, l.Shadows = fx.light.Color, fx.light.Brightness, fx.light.Range * math.sqrt(k), false
		l.Parent = area
	end
	model:SetAttribute("Fx", fx.theme)
	return fx.theme
end

return KnifeFx
