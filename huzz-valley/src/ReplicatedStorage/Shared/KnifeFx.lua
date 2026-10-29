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
	  KnifeFxGem    an Attachment in the knife's gem (gemOf: his guard_gem, else a gem, else his biggest glowing part
	                that isn't the blade or one of his baked aura bits), at the centre of the whole gem when it's cut
	                in slices (gemCluster), else at the guard (TrailBase): the glint and the orb come off the skin's
	                gem, where Huss Valley's sparkle; the model's FxGem attribute names the part it took;
	  KnifeFxGlow   (Epic and up, when the knife has a gem) a solid Neon ball on the whole gem, its size, in
	                the effect colour (Transparency 0.08 top tier, 0.15 Epic), never changing, the PointLight its
	                bloom: his gem glows like Huss Valley's (no gem, no ball; KnifeDress leaves it showing);
	  KnifeFx_<role> one ParticleEmitter per role (motes, motif, orb, glint, haze), Roblox's own built-in pictures only;
	                the glint's Rate is 0: Gameplay/KnifeFxRange emits one every GlintEvery seconds (the model's
	                attribute, KnifeLook.VFX.GLINT_EVERY), a fixed timer, never twice within 1 s;
	  KnifeBurst    Rate 0, in hand only: Gameplay/Actions throws half of the model's Burst attribute on a slash (a few
	                sparkles in its colour, no flash); a stand's or a worn knife has none (no spark showers);
	  KnifeFxLight  one soft PointLight (top tier, not worn; half strength in hand), no shadows, never changing, on
	                KnifeFxLightAt a quarter of the blade out from its middle (away from the hand: at the guard it
	                washed the forearm in its colour).
	Ball motes (Epic and up): not parts made here (moving parts would replicate every frame) but attributes on the
	model, Motes (how many), MoteColor, MoteSize (about 5% of the knife), MoteDrift, MoteSeed, and the tag
	"HuzzKnifeMotes" (also on a knife with a glint); each screen's Gameplay/KnifeFxRange makes and moves the balls
	(Shared/KnifeMotes) and times the glints.
	The model's Scale attribute (KnifeService.scale: a stand's copy) scales the particle sizes. Pure Instance.new: the
	server builds it (everyone sees the same, nothing runs every frame) and the offline films build the same.
]]
local KnifeLook = require(script.Parent.KnifeLook)

local KnifeFx = {}
KnifeFx.TAG = "HuzzKnifeMotes" -- (models whose ball motes each screen draws: Gameplay/KnifeFxRange)

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

-- The skin's gem: his parts named "guard_gem" first, then any "gem" (the pommel's), then "core" / "orb" / "jewel",
-- else his biggest glowing (Neon) part that isn't the blade or one of his own baked effect bits (aura_ring,
-- aura_shard, spark, rune, wing_glow: VoidFang's floating shards are not a gem). nil when there is none.
local NOT_GEM = { "aura", "spark", "rune", "ring", "shard", "wing", "glow" }
local function gemOf(model: Model, area: BasePart): BasePart?
	local best, score = nil, -1
	local limit = area.Size.X * area.Size.Y * area.Size.Z * 0.5
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and d ~= area and d.Material == Enum.Material.Neon and d.Transparency < 1 and not isBlade(d)
			and not string.find(d.Name, "^KnifeFx") then
			local n = string.lower(d.Name)
			local v = d.Size.X * d.Size.Y * d.Size.Z
			local rank = if string.find(n, "guard_gem", 1, true) then 3
				elseif string.find(n, "gem", 1, true) then 2
				elseif string.find(n, "core", 1, true) or string.find(n, "orb", 1, true) or string.find(n, "jewel", 1, true) then 1
				else 0
			if rank == 0 then
				for _, w in NOT_GEM do
					if string.find(n, w, 1, true) then rank = -1 break end
				end
			end
			local sc = if rank >= 0 and v < limit then rank * 1000 + math.min(v, 999) else -1
			if sc > score then best, score = d, sc end
		end
	end
	return best
end

-- His gem cut into slices (the stand-ins: the Seraph's cyan gem is two halves, Part151 and Part152): its centre and
-- size are the box over every glowing slice of the same colour joined to the picked one (within a small gap), in the
-- gem part's own space. One part on its own is just itself. (Oct 20 critic: the orb sat below and left of the
-- Seraph's ring, on one half of the gem.)
local function gemCluster(model: Model, gem: BasePart): (Vector3, number)
	local list, seen = { gem }, { [gem] = true }
	local gap = math.max(gem.Size.X, gem.Size.Y, gem.Size.Z) * 0.6 + 0.04
	local i = 1
	while i <= #list and #list < 40 do
		local a = list[i]
		for _, d in model:GetDescendants() do
			if d:IsA("BasePart") and not seen[d] and d.Material == Enum.Material.Neon and d.Transparency < 1 and not isBlade(d)
				and not string.find(d.Name, "^KnifeFx") and d.Color == gem.Color
				and (d.CFrame.Position - a.CFrame.Position).Magnitude <= gap then
				seen[d] = true
				table.insert(list, d)
			end
		end
		i += 1
	end
	local lo, hi = nil, nil
	for _, d in list do
		local r = gem.CFrame:ToObjectSpace(d.CFrame)
		local h = d.Size / 2
		local e = Vector3.new(
			math.abs(r.RightVector.X) * h.X + math.abs(r.UpVector.X) * h.Y + math.abs(r.LookVector.X) * h.Z,
			math.abs(r.RightVector.Y) * h.X + math.abs(r.UpVector.Y) * h.Y + math.abs(r.LookVector.Y) * h.Z,
			math.abs(r.RightVector.Z) * h.X + math.abs(r.UpVector.Z) * h.Y + math.abs(r.LookVector.Z) * h.Z)
		lo = if lo then lo:Min(r.Position - e) else r.Position - e
		hi = if hi then hi:Max(r.Position + e) else r.Position + e
	end
	local ext = hi - lo
	return (lo + hi) / 2, math.max(ext.X, ext.Y, ext.Z)
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
	for _, name in { "Fx", "Burst", "Motes", "MoteColor", "MoteSize", "MoteDrift", "MoteSeed", "GlintEvery", "FxGem" } do
		model:SetAttribute(name, nil)
	end
	pcall(function() model:RemoveTag(KnifeFx.TAG) end)
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
	local gemMid, gemSize = Vector3.zero, 0
	if gem then
		gemMid, gemSize = gemCluster(model, gem)
		local a = Instance.new("Attachment")
		a.Name = "KnifeFxGem"
		a.Position = gemMid -- (the whole gem's centre, not one slice's)
		a.Parent = gem
		gemAt = a
		model:SetAttribute("FxGem", gem.Name) -- (which part it took: the specs log it)
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
	if fx.glow and gem then
		-- (his gem's own size, a solid glowing ball like MELON5MAN's; kept between 0.1 and 0.35 studs: at 1.15x the
		-- Seraph's read as a flat disc over the guard)
		local d = math.clamp(gemSize, 0.1 * k, 0.35 * k)
		local g = invisiblePart("KnifeFxGlow", Vector3.new(d, d, d))
		g.Shape = Enum.PartType.Ball
		g.Material = Enum.Material.Neon
		g.Color = fx.glow.Color
		g.Transparency = fx.glow.Transparency
		g.CFrame = gem.CFrame * CFrame.new(gemMid)
		local w = Instance.new("Weld")
		w.Name = "KnifeFxWeld"
		w.Part0, w.Part1, w.C0 = gem, g, CFrame.new(gemMid)
		w.Parent = g
		g.Parent = handle.Parent
	end
	if fx.light then
		local l = Instance.new("PointLight")
		l.Name = "KnifeFxLight"
		l.Color, l.Brightness, l.Range, l.Shadows = fx.light.Color, fx.light.Brightness, fx.light.Range * math.sqrt(k), false
		-- (on the blade's far half, away from the hand: at the guard it washed the forearm in its colour)
		local la = Instance.new("Attachment")
		la.Name = "KnifeFxLightAt"
		la.Position = Vector3.new(0, size.Y * 0.25, 0)
		la.Parent = area
		l.Parent = la
	end
	local glintEvery = nil
	for _, spec in fx.emit do
		if spec.every then glintEvery = spec.every end
	end
	if glintEvery then model:SetAttribute("GlintEvery", glintEvery) end
	if fx.balls > 0 or glintEvery then pcall(function() model:AddTag(KnifeFx.TAG) end) end
	if fx.balls > 0 then
		model:SetAttribute("Motes", fx.balls)
		model:SetAttribute("MoteColor", fx.colour)
		-- (small glowing dots like Huss Valley's: 5% of the knife, never past 0.2 studs, the stands' copies scaled)
		model:SetAttribute("MoteSize", math.clamp(size.Y * 0.075, 0.08 * k, 0.2 * k))
		model:SetAttribute("MoteDrift", fx.drift * k)
		model:SetAttribute("MoteSeed", (#(skin.Key or "") * 7.7 + size.Y * 3.1) % 10)
	end
	model:SetAttribute("Fx", fx.theme)
	return fx.theme
end

return KnifeFx
