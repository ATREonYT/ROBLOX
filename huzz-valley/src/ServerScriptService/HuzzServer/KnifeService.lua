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
	return KnifeLook.sane(shapeOf(model), model:GetAttribute("Studs") or (skin and skin.Studs))
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
	local model = build()
	if skin then paint(model, skin) end
	return model, false
end
KnifeService.template = template

-- The biggest blade part (effects sit on it): ours is "Blade", the owner's are "blade_<n>".
local function bladeOf(model)
	local best, size = nil, -1
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and string.sub(string.lower(d.Name), 1, 5) == "blade" then
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

-- The skin's effects (Shared/KnifeLook): where = "hand" or "back".
local function addFx(model, skin, where)
	local look = KnifeLook.fx(skin and skin.Rarity)
	local colour = KnifeLook.colour(skin)
	if not colour or (where == "back" and not look.back) then
		return
	end
	local blade = bladeOf(model)
	if not blade then return end
	if look.sheen then -- a small glint on the blade now and then
		local e = emitter("KnifeSheen", blade, colour:Lerp(WHITE, 0.6), {
			Rate = look.sheen, Lifetime = NumberRange.new(0.3, 0.4), Speed = NumberRange.new(0), LockedToPart = true,
			Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.4, 0.35), NumberSequenceKeypoint.new(1, 0) }),
			Transparency = NumberSequence.new(0.15), Rotation = NumberRange.new(0, 90), ZOffset = 0.3,
		})
		FxTexture.flipbook(e, "Twinkle", "Random")
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
	motor.C0 = KnifeLook.handC0(at) -- Handle +Y (the blade) -> the hand's down-and-forward
	motor.C1 = gripOf(handle) -- (the fist on the model's Grip, not the Handle's centre)
	motor.Parent = handle
	-- The slash: a short smear round the blade, switched on by each client during a stab (Gameplay/Actions).
	local base, tip = model:FindFirstChild("TrailBase", true), model:FindFirstChild("TrailTip", true)
	if base and tip then
		local T = KnifeLook.TRAIL
		local look = KnifeLook.fx(skin and skin.Rarity)
		local colour = KnifeLook.colour(skin)
		local tinted = look.trailTint and colour ~= nil
		local trail = Instance.new("Trail")
		trail.Name = "SlashTrail"
		trail.Attachment0, trail.Attachment1 = base, tip
		trail.Lifetime = T.Lifetime
		trail.MinLength = 0
		trail.FaceCamera = false
		trail.LightEmission = if tinted then T.LightEmission else 0.3
		trail.Color = if tinted then ColorSequence.new(colour :: Color3, WHITE) else ColorSequence.new(WHITE)
		local tr = if tinted then T.Tinted else T.Plain
		trail.Transparency = NumberSequence.new(tr[1], tr[2])
		trail.Enabled = false
		trail.Parent = handle
	end
	model.Parent = character
end

-- A loose copy of a skin's knife with its in-hand effects, for showing off (the lobby avatar stands:
-- HuzzServer/AvatarStandService puts it in ReplicatedStorage, each screen welds it into the stand copy's hand by
-- its Handle's Grip attachment). Nothing anchored, nothing collides.
function KnifeService.display(skin)
	local model = template(skin)
	local handle = model:FindFirstChild("Handle", true)
	if not handle then
		model:Destroy()
		return nil
	end
	loose(model)
	addFx(model, skin, "hand")
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
