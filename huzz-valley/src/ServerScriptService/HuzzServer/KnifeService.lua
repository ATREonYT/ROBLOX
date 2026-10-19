--[[
	Catchers hold a knife in their right hand (as in the reference); everyone else wears theirs, always: lobby,
	runner, waiting (owner: "the catchers run with a knife, and everyone even the runners have a knife mounted on
	their backs"; Oct 18: "make the knifes please be equipped when you have them, like be shown on the back of the
	character"; "or even for the katanas you can make it be on the side of the person"). Worn = diagonal across the
	back, or at the left hip for long slim blades (Shared/KnifeLook.wearOf). It's the knife skin you wear
	(Shared/KnifeLook.pick: the one picked in the shop, else your first owned knife, else the default knife).
	ONE knife per body: KnifeService.give (hand) and giveBack (worn) each remove the other first, so drawing it moves
	it from the back to the hand and the round's end puts it back. It's a model welded on by the server (everyone
	sees it), not a Tool, so there's nothing to equip or drop and no backpack. HuzzClient/Gameplay/Actions plays the
	stab and lights the blade's trail. RoundService.syncPlayer calls give/giveBack on every change and on spawn;
	Bootstrap's DataService.onChanged swaps the skin the moment you pick another in the shop.

	The owner's own knives (Oct 18, 30 models in design/knives/Knives): once he has imported them and run the setup
	(tools/knives/setup_knives.lua, also ServerStorage/HuzzStudioTools/SetupKnives), each skin is a Model in
	ServerStorage/HuzzKnives/<skin key> with an invisible part "Handle" (+Y to the tip, X the blade's thin way) and
	Attachments "Grip" (where the fist closes), "TrailBase" (guard) and "TrailTip" (tip). It's used as it is: already
	at its length, its glowing parts already Neon. Until then (or for a skin with no model) the game draws its own
	knife below, painted in the skin's colours (Config/CoinShop Colors, Neon guard in its Glow colour), so nothing
	ever looks broken. A Model named "HuzzKnife" (in HuzzKnives, or ServerStorage as before) replaces the default.
	The five Game Pass knives get a better stand-in (owner, Oct 19: "right now its very small and you dont even
	notice it"): their card's shape from plain parts at their real length (Shared/KnifeShapes, buildRecipe).

	Oct 19 too: the lobby stands' copy (display) is scaled up to KnifeLook.STAND.Length (scale: by hand, no ScaleTo)
	and a Game Pass knife carries its element (KnifeLook.ELEMENTS: petals, moon glints, feathers, fire, frost) in
	place of Mythic's plain sparkles and embers, a burst emitter for big moments (KnifeBurst: the stands' spins, the
	catcher's slash) and, on a stand, a star glint at the tip; its slash trail takes the element's colours.
	Round 2 ("in the reference the knife is the first thing you see"): its slash starts halfway up the blade
	(StandTrailBase). In hand a long blade is held more forward (KnifeLook.handC0 with its reach) so its tip never
	goes into the floor. (The stand copy was also widened and wore a see-through Neon GlowShell, and every knife from
	Uncommon up had a white sheen glint: all three hid his model, owner Oct 19: "they dont look as good as in the glb
	file". Gone: every knife, worn, held or on a stand, is his model as it is, only scaled evenly.)

	Effects by rarity (owner: "make it fit it, and dont make it overly crazy"): Shared/KnifeLook. In hand always;
	on the back only Legendary and Mythic. Built here once per knife (replicated), nothing runs every frame.
	Where it sits: Shared/KnifeLook (hand: today's grip, offset by the model's Grip; worn: backC0 / sideC0, also on
	the model's Grip). A model in HuzzKnives whose size doesn't match its length (8 of the owner's Oct 18 file came
	out of the setup about 10 times too big and lying sideways) is not used: that skin shows our own knife in its
	colours instead, with one warning in Output, until the model is fixed.
]]
local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local KnifeLook = require(ReplicatedStorage.Shared.KnifeLook)
local FxTexture = require(ReplicatedStorage.Shared.FxTexture)
local KnifeShapes = require(ReplicatedStorage.Shared.KnifeShapes)

local KnifeService = {}
local NAME = "HuzzKnife"
local WHITE = Color3.new(1, 1, 1)

local function part(class, props)
	local p = Instance.new(class)
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.Massless = false, false, false, false, true
	p.CastShadow = false
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	for k, v in props do
		p[k] = v
	end
	return p
end

local function weld(a, b)
	local w = Instance.new("WeldConstraint")
	w.Part0, w.Part1 = a, b
	w.Parent = b
end

-- A dagger: dark grip with a pommel, a steel guard, a slim blade with a pointed tip.
local function build()
	local model = Instance.new("Model")
	local dark, steel = Color3.fromRGB(32, 30, 38), Color3.fromRGB(205, 212, 224)
	local handle = part("Part", { Name = "Handle", Size = Vector3.new(0.22, 0.75, 0.26), Color = dark, Material = Enum.Material.SmoothPlastic, Parent = model })
	local function add(class, props, offset)
		local p = part(class, props)
		p.CFrame = handle.CFrame * offset
		p.Parent = model
		weld(handle, p)
		return p
	end
	add("Part", { Name = "Pommel", Size = Vector3.new(0.26, 0.12, 0.3), Color = steel, Material = Enum.Material.Metal }, CFrame.new(0, -0.42, 0))
	add("Part", { Name = "Guard", Size = Vector3.new(0.24, 0.1, 0.62), Color = steel, Material = Enum.Material.Metal }, CFrame.new(0, 0.42, 0))
	local blade = add("Part", { Name = "Blade", Size = Vector3.new(0.07, 1.05, 0.3), Color = steel, Material = Enum.Material.Metal, Reflectance = 0.15 }, CFrame.new(0, 0.995, 0.02))
	-- WedgePart: its tall edge is at +Z, so the point sits over the blade's back (a dagger tip).
	add("WedgePart", { Name = "Tip", Size = Vector3.new(0.07, 0.42, 0.3), Color = steel, Material = Enum.Material.Metal, Reflectance = 0.15 }, CFrame.new(0, 1.73, 0.02))
	local base = Instance.new("Attachment")
	base.Name = "TrailBase"
	base.Position = Vector3.new(0, -0.4, 0)
	base.Parent = blade
	local tip = Instance.new("Attachment")
	tip.Name = "TrailTip"
	tip.Position = Vector3.new(0, 0.85, 0)
	tip.Parent = blade
	model.PrimaryPart = handle
	return model
end

-- A Game Pass knife's stand-in from plain parts (Shared/KnifeShapes: cut from his .glb, at its real length), used
-- until the owner's own model is in ServerStorage/HuzzKnives, and on screens that can't draw his model.
local MATERIAL = { Metal = Enum.Material.Metal, Neon = Enum.Material.Neon, Plastic = Enum.Material.Plastic,
	SmoothPlastic = Enum.Material.SmoothPlastic, Glass = Enum.Material.Glass, Fabric = Enum.Material.Fabric }
local function buildRecipe(recipe)
	local model = Instance.new("Model")
	local handle
	local made = {}
	for _, r in recipe.parts do
		local class = if r.kind == "Wedge" then "WedgePart" else "Part"
		local p = part(class, {
			Name = r.name, Size = Vector3.new(r.size[1], r.size[2], r.size[3]), Color = recipe.palette[r.paint] or WHITE,
			Material = MATERIAL[r.mat] or Enum.Material.SmoothPlastic,
		})
		if r.kind == "Cylinder" then p.Shape = Enum.PartType.Cylinder end
		p.Reflectance = r.refl or (if r.mat == "Metal" then 0.12 else 0)
		if r.mat == "Glass" then p.Transparency = 0.12 end
		if r.hidden then p.Transparency = 1 end
		local rot = r.rot or { 0, 0, 0 }
		p.CFrame = CFrame.new(r.at[1], r.at[2], r.at[3]) * CFrame.Angles(math.rad(rot[1]), math.rad(rot[2]), math.rad(rot[3]))
		p.Parent = model
		made[r.name] = p
		if r.name == "Handle" then handle = p end
	end
	for _, p in made do
		if p ~= handle then weld(handle, p) end
	end
	local blade = made.Blade or handle
	local by = blade.CFrame.Position.Y
	local base = Instance.new("Attachment")
	base.Name = "TrailBase"
	base.CFrame = CFrame.new(0, recipe.trail[1] - by, 0)
	base.Parent = blade
	local tip = Instance.new("Attachment")
	tip.Name = "TrailTip"
	tip.CFrame = CFrame.new(0, recipe.trail[2] - by, 0)
	tip.Parent = blade
	model.PrimaryPart = handle
	return model
end
KnifeService.buildRecipe = buildRecipe

-- Scales a knife model by f about its Handle (the lobby stands show their knife big: Shared/KnifeLook.STAND).
-- By hand, not Model:ScaleTo: every part's size and its offset from the Handle, attachments, welds' C0/C1, meshes
-- and lights. (An earlier try with ScaleTo lost the stand knife offline: the test harness has no ScaleTo, so the
-- stand's mount failed and three lobby checks broke. This runs the same everywhere.)
-- f: a number (the same every way), or a Vector3 of factors along the Handle's own axes (X thickness, Y length, Z
-- width: the stands' broader-than-life blades). Each part keeps its turn; its size grows by how much its own axes
-- stretch (exact for parts lined up with the Handle, close for tilted ones).
function KnifeService.scale(model, f: number | Vector3)
	local handle = model:FindFirstChild("Handle", true)
	local fv = if typeof(f) == "Vector3" then f else Vector3.new(f, f, f)
	if not (handle and handle:IsA("BasePart")) or (fv - Vector3.new(1, 1, 1)).Magnitude < 1e-3 then return model end
	local h = handle.CFrame
	local function stretch(rot: CFrame, v: Vector3): Vector3 -- a vector in a part's space, stretched in the Handle's
		return rot:VectorToObjectSpace(rot:VectorToWorldSpace(v) * fv)
	end
	local function axes(rot: CFrame): Vector3 -- how much a part's own X, Y, Z grow
		return Vector3.new((rot.RightVector * fv).Magnitude, (rot.UpVector * fv).Magnitude, (rot.LookVector * fv).Magnitude)
	end
	local rels = {}
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then rels[d] = h:ToObjectSpace(d.CFrame).Rotation end
	end
	local constraints = {}
	for _, d in model:GetDescendants() do
		if d:IsA("WeldConstraint") then -- (re-enabled after: it keeps the new offsets; pcall: Lune has no Enabled)
			local ok, on = pcall(function() return d.Enabled end)
			if not ok or on then
				pcall(function() d.Enabled = false end)
				table.insert(constraints, d)
			end
		end
	end
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			local rel = h:ToObjectSpace(d.CFrame)
			d.Size = d.Size * axes(rel.Rotation)
			d.CFrame = h * (CFrame.new(rel.Position * fv) * rel.Rotation)
		elseif d:IsA("Attachment") then
			local c = d.CFrame
			local rot = d.Parent and rels[d.Parent] or CFrame.identity
			d.CFrame = CFrame.new(stretch(rot, c.Position)) * c.Rotation
		elseif d:IsA("JointInstance") then
			local r0 = d.Part0 and rels[d.Part0] or CFrame.identity
			local r1 = d.Part1 and rels[d.Part1] or CFrame.identity
			d.C0 = CFrame.new(stretch(r0, d.C0.Position)) * d.C0.Rotation
			d.C1 = CFrame.new(stretch(r1, d.C1.Position)) * d.C1.Rotation
		elseif d:IsA("SpecialMesh") then
			local a = d.Parent and rels[d.Parent] and axes(rels[d.Parent]) or fv
			d.Scale = d.Scale * a
			d.Offset = d.Offset * a
		elseif d:IsA("PointLight") or d:IsA("SpotLight") then
			d.Range = math.min(d.Range * fv.Y, 16)
		end
	end
	for _, c in constraints do pcall(function() c.Enabled = true end) end
	local was = model:GetAttribute("Scale") or 1
	model:SetAttribute("Scale", was * fv.Y)
	local before = model:GetAttribute("Stretch") -- (every way: Gameplay/KnifeDress sizes a pass knife's .glb model by it)
	model:SetAttribute("Stretch", (if typeof(before) == "Vector3" then before else Vector3.new(was, was, was)) * fv)
	return model
end

-- The game's own knife in a skin's colours: blade in its blade colour, guard and pommel in its guard colour, and a
-- glowing (Neon) guard when the skin's model has glowing parts.
local function paint(model, skin)
	local blade, accent = skin.Colors[1], skin.Colors[#skin.Colors]
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			if d.Name == "Blade" or d.Name == "Tip" then
				d.Color = blade
			elseif d.Name == "Guard" then
				if skin.Glow then
					d.Color, d.Material = skin.Glow, Enum.Material.Neon
				else
					d.Color = accent
				end
			elseif d.Name == "Pommel" then
				d.Color = accent
			end
		end
	end
end

-- A knife model's size (Shared/KnifeLook.shape): every part in its Handle's space.
local function shapeOf(model)
	local handle = model:FindFirstChild("Handle", true)
	if not (handle and handle:IsA("BasePart")) then return nil end
	local parts = {}
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			table.insert(parts, { name = d.Name, cf = handle.CFrame:ToObjectSpace(d.CFrame), size = d.Size })
		end
	end
	return KnifeLook.shape(parts)
end
KnifeService.shapeOf = shapeOf

-- True when a model is about its listed length (Studs attribute, else the shop's Studs) and shaped like a knife
-- (Shared/KnifeLook.sane): a setup that went wrong can leave one 10 times too big and lying sideways.
local warned = {}
local function fits(model, skin)
	return KnifeLook.sane(shapeOf(model), model:GetAttribute("Studs") or (skin and skin.Studs), model:GetAttribute("Wide") or (skin and skin.Wide))
end
KnifeService.fits = fits

-- The knife for a skin: the owner's model when it's been set up (true), else ours (false).
local function template(skin)
	local folder = ServerStorage:FindFirstChild("HuzzKnives")
	local own = skin and folder and folder:FindFirstChild(skin.Key)
	if own and own:IsA("Model") and own:FindFirstChild("Handle", true) then
		if fits(own, skin) then
			return own:Clone(), true
		elseif not warned[skin.Key] then
			warned[skin.Key] = true
			warn(`[HuzzKnife] {skin.Key} in ServerStorage > HuzzKnives is the wrong size (run the knife setup again for it); showing the plain knife in its colours`)
		end
	end
	local custom = (folder and folder:FindFirstChild(NAME)) or ServerStorage:FindFirstChild(NAME)
	if custom and custom:IsA("Model") and custom:FindFirstChild("Handle", true) then
		return custom:Clone(), true
	end
	local recipe = skin and KnifeShapes.get(skin.Key)
	if recipe then
		-- each screen dresses it as the owner's own .glb model (Gameplay/KnifeDress, ServerStorage/HuzzKnifeGlb); the plain
		-- parts stay where that can't run
		local model = buildRecipe(recipe)
		model:SetAttribute("Glb", skin.Key)
		pcall(function() model:AddTag("GlbKnife") end)
		return model, false
	end
	local model = build()
	if skin then paint(model, skin) end
	return model, false
end
KnifeService.template = template

-- The biggest blade part (effects sit on it): ours is "Blade", the owner's are "blade_<n>" (his Halloween reapers and
-- most of the others glow: "glow_blade_<n>").
local function bladeOf(model)
	local best, size = nil, -1
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and string.find(string.lower(d.Name), "blade", 1, true) then
			local v = d.Size.X * d.Size.Y * d.Size.Z
			if v > size then best, size = d, v end
		end
	end
	return best or model.PrimaryPart or model:FindFirstChild("Handle", true)
end

local function emitter(name, parent, colour, props)
	local e = Instance.new("ParticleEmitter")
	e.Name = name
	e.LightEmission = 1
	e.LightInfluence = 0
	e.Color = ColorSequence.new(colour:Lerp(WHITE, 0.35), colour)
	for k, v in props do
		e[k] = v
	end
	e.Parent = parent
	return e
end

-- A Game Pass knife's element (Shared/KnifeLook.ELEMENTS): its steady emitters on the blade ("stand": the lobby's
-- full rate; "hand": half; "back": a third) and a "KnifeBurst" emitter that throws a handful out on a big moment
-- (a stand's spin, a catcher's slash: Emit only, Rate 0).
local function addElement(model, blade, el, where)
	local tipAt = model:FindFirstChild("TrailTip", true)
	local scale = model:GetAttribute("Scale") or 1
	for i, spec in el.emit do
		if spec.standOnly and where ~= "stand" then continue end
		local rate = KnifeLook.elementRate(spec, where)
		local parent = if spec.tip and tipAt then tipAt else blade
		local size = spec.size * (if where == "stand" then math.max(1, scale * 0.85) else 1)
		local e = emitter("KnifeElement" .. i, parent, spec.colours[1], {
			Rate = rate, Lifetime = NumberRange.new(spec.life[1], spec.life[2]), Speed = NumberRange.new(spec.speed[1], spec.speed[2]),
			SpreadAngle = Vector2.new(180, 180), Drag = 1.5, LockedToPart = spec.lock == true,
			Acceleration = if spec.accel then Vector3.new(spec.accel[1], spec.accel[2], spec.accel[3]) else Vector3.zero,
			RotSpeed = NumberRange.new(-(spec.spin or 0), spec.spin or 0), Rotation = NumberRange.new(0, 360),
			Size = if spec.grow then NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.35, size), NumberSequenceKeypoint.new(1, 0) })
				elseif spec.shrink then NumberSequence.new(size, 0)
				else NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.15, size), NumberSequenceKeypoint.new(1, size * 0.6) }),
			Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.15, if spec.faint then 0.55 else 0.1),
				NumberSequenceKeypoint.new(1, 1) }),
		})
		e.Color = ColorSequence.new(spec.colours[1], spec.colours[2])
		if spec.box and parent == blade then
			pcall(function() e.Shape = Enum.ParticleEmitterShape.Box; e.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume end)
		end
		e.Texture = FxTexture.get(spec.texture)
	end
	if where ~= "back" then -- the burst: the first emitter's look, flung out fast, Emit only
		local spec = el.emit[1]
		local e = emitter("KnifeBurst", blade, spec.colours[1], {
			Rate = 0, Lifetime = NumberRange.new(0.7, 1.2), Speed = NumberRange.new(4, 8), SpreadAngle = Vector2.new(180, 180), Drag = 4,
			Acceleration = Vector3.new(0, -1, 0), RotSpeed = NumberRange.new(-180, 180), Rotation = NumberRange.new(0, 360),
			Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, spec.size * 1.2), NumberSequenceKeypoint.new(1, 0) }),
			Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1) }),
		})
		e.Color = ColorSequence.new(spec.colours[1], spec.colours[2])
		pcall(function() e.Shape = Enum.ParticleEmitterShape.Box; e.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume end)
		e.Texture = FxTexture.get(spec.texture)
		model:SetAttribute("Burst", el.burst)
	end
	model:SetAttribute("Element", el.name)
end

-- The skin's effects (Shared/KnifeLook): where = "hand", "back" or "stand" (the lobby showcase: a hand's effects,
-- the element at its full rate and a star glint at the tip now and then).
local function addFx(model, skin, where)
	local look = KnifeLook.fx(skin and skin.Rarity)
	local el = KnifeLook.element(skin and skin.Key)
	local colour = if el then el.light else KnifeLook.colour(skin)
	if not colour or (where == "back" and not look.back) then
		return
	end
	local blade = bladeOf(model)
	if not blade then return end
	if el then
		addElement(model, blade, el, where)
		look = table.clone(look)
		look.sparkles, look.embers = nil, nil -- (the element replaces them: calm, not doubled)
		if where == "stand" then
			look.glow = { range = 4, brightness = 0.6 } -- (soft, kept on the knife: the Oct 19 lighting has no light pools; its Neon and particles carry it)
			local tipAt = model:FindFirstChild("TrailTip", true)
			if tipAt then -- the reference's star glint on the tip: one every 2 to 3 s, soft, never a flash
				local e = emitter("KnifeTipGlint", tipAt, el.light:Lerp(WHITE, 0.7), {
					Rate = 0.4, Lifetime = NumberRange.new(0.45, 0.55), Speed = NumberRange.new(0), LockedToPart = true,
					Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.4, 1.1), NumberSequenceKeypoint.new(1, 0) }),
					Transparency = NumberSequence.new(0.1), Rotation = NumberRange.new(0, 45), RotSpeed = NumberRange.new(60), ZOffset = 0.5,
				})
				e.Texture = FxTexture.get("StarFlare")
			end
		end
	end
	if look.glow then -- a soft light round the blade (no shadows, never flashing)
		local l = Instance.new("PointLight")
		l.Name = "KnifeGlow"
		l.Color, l.Range, l.Brightness, l.Shadows = colour, look.glow.range, look.glow.brightness, false
		l.Parent = blade
	end
	if look.sparkles then -- a few small sparkles drifting off the blade
		local e = emitter("KnifeSparkles", blade, colour, {
			Rate = math.min(look.sparkles, KnifeLook.MAX_SPARKLES), Lifetime = NumberRange.new(0.5, 0.8), Speed = NumberRange.new(0.2, 0.6),
			SpreadAngle = Vector2.new(180, 180), Drag = 2,
			Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.2, 0.16), NumberSequenceKeypoint.new(1, 0) }),
			Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(1, 0.6) }),
		})
		FxTexture.flipbook(e, "Twinkle", "Random")
	end
	if look.embers then -- Mythic: a few embers rising off the blade in its colour
		local e = emitter("KnifeEmbers", blade, colour, {
			Rate = look.embers, Lifetime = NumberRange.new(1, 1.4), Speed = NumberRange.new(0.1, 0.3),
			SpreadAngle = Vector2.new(30, 30), Acceleration = Vector3.new(0, 1.2, 0), Drag = 1,
			Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.12), NumberSequenceKeypoint.new(1, 0) }),
			Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) }),
			EmissionDirection = Enum.NormalId.Top,
		})
		e.Texture = FxTexture.get("Spark")
	end
end

-- Where the hand / back holds the knife, in the Handle's space: its Grip attachment, else the Handle's centre.
local function gripOf(handle)
	local grip = handle:FindFirstChild("Grip")
	return if grip and grip:IsA("Attachment") then grip.CFrame else CFrame.identity
end

-- Studs from the grip to the tip (KnifeLook.handC0 holds a long blade more forward, so it never sinks into the
-- floor): the TrailTip attachment when there is one, else the far end of the measured shape.
local function reachOf(model, handle)
	local grip = gripOf(handle).Position
	local tip = model:FindFirstChild("TrailTip", true)
	local holder = tip and tip.Parent
	if tip and tip:IsA("Attachment") and holder and holder:IsA("BasePart") then
		local at = handle.CFrame:PointToObjectSpace(holder.CFrame * tip.CFrame.Position)
		return at.Y - grip.Y
	end
	local shape = shapeOf(model)
	return if shape then shape.length * 0.8 else nil
end
KnifeService.reachOf = reachOf

local function loose(model)
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored, d.CanCollide, d.CanQuery, d.CanTouch, d.Massless = false, false, false, false, true
		end
	end
end

function KnifeService.has(character)
	return character ~= nil and character:FindFirstChild(NAME) ~= nil
end

local BACK = "HuzzBackKnife"
local function skinOf(skin) return if skin then skin.Key else "" end

-- True while a worn / held knife is still fixed to this body (a body part swapped out by an avatar reload leaves its
-- weld pointing at a part that's gone: then it's built again).
local function attached(model, character, mountName)
	local handle = model:FindFirstChild("Handle", true)
	local mount = handle and handle:FindFirstChild(mountName)
	local p0 = mount and (mount :: any).Part0
	return p0 ~= nil and p0.Parent == character
end

-- Back or Side for this knife: set on the model or the shop item (Wear), else by its shape (Shared/KnifeLook).
local function wearOf(model, skin, shape)
	return KnifeLook.wearOf(model:GetAttribute("Wear") or (skin and skin.Wear), shape or shapeOf(model))
end
KnifeService.wearOf = wearOf

-- Your knife worn on your body, in your skin: diagonal across the back, or at the left hip for long slim blades
-- (replaced when the skin changes). Takes a knife out of your hand first: one knife per body.
function KnifeService.giveBack(character, skin)
	if not character then return end
	local old = character:FindFirstChild(BACK)
	if old and old:GetAttribute("Skin") == skinOf(skin) and attached(old, character, "BackMount") then
		KnifeService.take(character)
		return
	end
	if old then old:Destroy() end
	KnifeService.take(character)
	local r6 = character:FindFirstChild("UpperTorso") == nil and character:FindFirstChild("Torso") ~= nil
	local model = template(skin)
	local shape = shapeOf(model)
	local wear = wearOf(model, skin, shape)
	local torso = character:FindFirstChild(KnifeLook.mountPart(wear, r6))
	local handle = model:FindFirstChild("Handle", true)
	if not (torso and torso:IsA("BasePart") and handle) then model:Destroy() return end
	model.Name = BACK
	model:SetAttribute("Skin", skinOf(skin))
	model:SetAttribute("WornAt", wear)
	loose(model)
	for _, d in model:GetDescendants() do
		if d:IsA("Trail") or d:IsA("ParticleEmitter") or d:IsA("Light") then d:Destroy() end
	end
	addFx(model, skin, "back")
	local mount = Instance.new("Weld")
	mount.Name = "BackMount"
	mount.Part0 = torso
	mount.Part1 = handle
	mount.C0 = KnifeLook.wornC0(wear, torso.Name, torso.Size, shape)
	mount.C1 = gripOf(handle)
	mount.Parent = handle
	model.Parent = character
end

function KnifeService.takeBack(character)
	local knife = character and character:FindFirstChild(BACK)
	if knife then knife:Destroy() end
end

-- Into the right hand, blade pointing down and a little forward (the slash sweeps it out).
-- skin (optional): a Config/CoinShop Knife item: its model (or ours in its colours), its effects, and the slash
-- trail in its colour (Epic and up) or a faint white smear. Takes the worn knife off first: one knife per body.
function KnifeService.give(character, skin)
	if not character then
		return
	end
	KnifeService.takeBack(character)
	local held = character:FindFirstChild(NAME)
	if held and (held:GetAttribute("Skin") or "") == skinOf(skin) and attached(held, character, "KnifeGrip") then
		return
	end
	if held then held:Destroy() end
	local hand = character:FindFirstChild("RightHand") or character:FindFirstChild("Right Arm")
	if not hand then
		return
	end
	local model = template(skin)
	model.Name = NAME
	model:SetAttribute("Skin", skinOf(skin)) -- (always: a custom knife with a skin isn't rebuilt every sync)
	local handle = model:FindFirstChild("Handle", true)
	if not handle then model:Destroy() return end
	loose(model)
	addFx(model, skin, "hand")
	local grip = hand:FindFirstChild("RightGripAttachment")
	local at = if grip then grip.Position else Vector3.new(0, -hand.Size.Y / 2 + 0.1, 0)
	local motor = Instance.new("Motor6D") -- a Motor6D (not a Weld) so it moves with the hand on every client at once
	motor.Name = "KnifeGrip"
	motor.Part0 = hand
	motor.Part1 = handle
	motor.C0 = KnifeLook.handC0(at, reachOf(model, handle)) -- Handle +Y (the blade) -> the hand's down-and-forward (more forward for a long blade)
	motor.C1 = gripOf(handle) -- (the fist on the model's Grip, not the Handle's centre)
	motor.Parent = handle
	-- The slash: a short smear round the blade, switched on by each client during a stab (Gameplay/Actions).
	local base, tip = model:FindFirstChild("TrailBase", true), model:FindFirstChild("TrailTip", true)
	if base and tip then
		local T = KnifeLook.TRAIL
		local look = KnifeLook.fx(skin and skin.Rarity)
		local colour = KnifeLook.colour(skin)
		local el = KnifeLook.element(skin and skin.Key)
		local tinted = look.trailTint and colour ~= nil
		local trail = Instance.new("Trail")
		trail.Name = "SlashTrail"
		trail.Attachment0, trail.Attachment1 = base, tip
		trail.Lifetime = if el then T.ElementLifetime else T.Lifetime
		trail.MinLength = 0
		trail.FaceCamera = false
		trail.LightEmission = if tinted then T.LightEmission else 0.3
		trail.Color = if el then ColorSequence.new(el.trail[1], el.trail[2])
			elseif tinted then ColorSequence.new(colour :: Color3, WHITE) else ColorSequence.new(WHITE)
		local tr = if tinted then T.Tinted else T.Plain
		trail.Transparency = NumberSequence.new(tr[1], tr[2])
		pcall(function() trail.WidthScale = NumberSequence.new(1, 0.35) end) -- (a crescent: full at the blade, thin at the end)
		trail.Enabled = false
		trail.Parent = handle
		-- the catcher's slash arc (Gameplay/Actions) in this colour, Epic and up
		if tinted then model:SetAttribute("SlashColor", if el then el.trail[1] else colour) end
	end
	model.Parent = character
end

-- A loose copy of a skin's knife with its in-hand effects, for showing off (the lobby avatar stands:
-- HuzzServer/AvatarStandService puts it in ReplicatedStorage, each screen welds it into the stand copy's hand by
-- its Handle's Grip attachment). Nothing anchored, nothing collides.
-- Big: scaled up to KnifeLook.STAND.Length (owner, Oct 19: "right now its very small and you dont even notice it"),
-- evenly, so it stays his model's shape (no widening, no glow shell over it: owner, Oct 19, "they dont look as good as
-- in the glb file").
function KnifeService.display(skin)
	local model = template(skin)
	local handle = model:FindFirstChild("Handle", true)
	if not handle then
		model:Destroy()
		return nil
	end
	loose(model)
	for _, d in model:GetDescendants() do -- (a model that came with its own effects gets ours, sized for the stand)
		if d:IsA("Trail") or d:IsA("ParticleEmitter") or d:IsA("Light") then d:Destroy() end
	end
	local shape = shapeOf(model)
	KnifeService.scale(model, KnifeLook.standScale(shape and shape.length))
	-- the stands' slash runs from halfway up the blade to the tip (a crescent, not a whole sheet)
	local base, tip = model:FindFirstChild("TrailBase", true), model:FindFirstChild("TrailTip", true)
	if base and tip and base:IsA("Attachment") and tip:IsA("Attachment") and tip.Parent and tip.Parent:IsA("BasePart") then
		local bw = (base.Parent :: BasePart).CFrame * base.CFrame.Position
		local tw = (tip.Parent :: BasePart).CFrame * tip.CFrame.Position
		local mid = Instance.new("Attachment")
		mid.Name = "StandTrailBase"
		mid.CFrame = CFrame.new((tip.Parent :: BasePart).CFrame:PointToObjectSpace(bw:Lerp(tw, 0.45)))
		mid.Parent = tip.Parent
	end
	addFx(model, skin, "stand")
	model:SetAttribute("Skin", skinOf(skin))
	model.PrimaryPart = handle
	return model
end

function KnifeService.take(character)
	local knife = character and character:FindFirstChild(NAME)
	if knife then
		knife:Destroy()
	end
end

return KnifeService
