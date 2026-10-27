---------------------------------------------------------------------------------------------- armory
-- The ARMORY, LOBBY5 (BRIEF23: "the armory, we need to make it like in the superhero game. It looks way better
-- smaller"): ref_lobby.png's EVOLUTIONS 3 TIERS stand. Square pads in tight rows on three tiers, each gun floating in
-- profile over its own pad, a compact island (35 x 24 studs, was 61 x 33 plus a back block to the wall):
--   Island  a low studded apron (0.4) in the stand's pale tone inside a dark kerb, the walkway round it.
--   Tiers   three studded decks 3.2 apart (1.2, 4.4, 7.6; four 0.8 risers each), 6.5 deep, the whole width; guns 1-3 on
--           the front deck, 4-7 on the middle tier, 8-10 on the top tier, each row standing between the guns of the row
--           in front (so every gun and nameplate shows between the ones below it); a stair at each end climbs tier to
--           tier; a low backdrop with pilasters and corner posts closes the top tier.
--   Slot    the reference's white-framed square: a white rim round a studded mat in the state's soft tone, the 4-stud pad
--           on it (a dark plinth, a pale body with a state-coloured line, a light lip, the face: a dark rim, the glowing
--           state colour, a light core) and a plate on its front (LOCKED / BUY / OWNED / EQUIPPED). The gun floats over
--           it in profile (3-4 studs, CRITIC3 r1: "specks" at 1.4-3.1), tilted a little, bobbing; over the gun the
--           soldier stand's plate: one big "xN Power" and under it the price (red locked, yellow BUY) or the state.
-- Step onto a pad (its front half) for the Buy / Equip prompt. Neon only on the pad faces; saturated colour only on
-- the pads, the guns and their nameplates. State colours (GunRules.Colors; Armory.client repaints): pink locked,
-- blue owned, green equipped.
--
-- Contract (GunService and HoodClient/Armory): one Model GunSlot_<Id> per gun (a direct child of the Armory model)
-- with attributes GunId, Tier, Cost, Multiplier, holding
--   GunPoint_<Id>      invisible part on the pad's front half: prompt anchor and buy-distance point
--   StateTop           parts in the state colour (the pad face and its side line)
--   StateGlow          the face's light core, with the pad's PointLight under it
--   StateShade         the face's dark rim (the state's dark tone)
--   StateMat           the slot's studded mat round the pad (the state's soft tone)
--   StateStrip         the front plate, with SurfaceGui > TextLabel State; StateHaze (ParticleEmitter)
--   LabelAnchor        BillboardGui GunLabel > TextLabels Name, Multiplier, Price (Glyph attribute = icon text)
--   Display            Model tagged HoodMotion (Bob) with the gun inside, horizontal, in profile to the hall
-- The Armory model is tagged HoodArmory; each slot streams Atomic.
-- Local frame: origin at the centre of the island's front edge on the hall floor, front faces -Z (players stand at
-- -Z looking +Z); footprint x -Armory.ApronHalf..ApronHalf, z 0..Armory.Depth; the backdrop's top at Armory.Top
-- (nameplates float to about 11.5).
local Armory = {}

Armory.Apron = { y = 0.4, front = 2.0, side = 1.6, back = 1.0, kerb = 0.8 } -- the island round the stand
Armory.HalfWidth = 18.4 -- the stand's half width (the stairs' outer edges) (B31 PLAZA: the whole stand 1.15x, read from the spawn)
Armory.ApronHalf = Armory.HalfWidth + Armory.Apron.side
-- the tiers: each one's deck top and the z of its front wall (the first is the front deck, one riser over the apron)
Armory.Tiers = { { y = 1.2, z = 2.0 }, { y = 4.4, z = 9.5 }, { y = 7.6, z = 17.0 } }
Armory.TierDepth = 7.5
Armory.BackZ = 24.5 -- the top tier's back (the backdrop stands behind it)
Armory.BackT, Armory.BackH = 1.2, 3.4 -- the backdrop's thickness and its height over the top tier
Armory.Depth = Armory.BackZ + Armory.BackT + Armory.Apron.back
Armory.Top = Armory.Tiers[3].y + Armory.BackH
-- the rows, front to back: the tier each stands on and x of each gun in Spacing units from the viewer's left (+X) to
-- the right; each row stands between the guns of the row in front
Armory.Rows = {
	{ tier = 1, xs = { 1, 0, -1 } },
	{ tier = 2, xs = { 1.5, 0.5, -0.5, -1.5 } },
	{ tier = 3, xs = { 1, 0, -1 } },
}
Armory.Spacing = 7.6 -- the pitch along a row (a pad and a 1.4-stud gap between the mats)
Armory.RowInset = 4.25 -- a row's pad centre behind its tier's front wall (1.2 of free deck in front of the mats)
Armory.Pad = 4.6 -- the pad's side (square)
Armory.Mat, Armory.MatDepth = 6.0, 5.75 -- the slot's white-framed tile round the pad
Armory.MaxLength = 4.6
Armory.GunK = 3.0 -- display length = GunK x sqrt(natural length), +3% a tier, up to MaxLength (3-4 studs)
Armory.Tilt = 17 -- degrees the muzzle points up
Armory.Float = 0.8 -- the gun's lowest point over the pad
Armory.DisplayH = 3.45 -- the tallest a tilted gun may stand (taller ones are scaled down; nameplates sit over it)
Armory.Bob, Armory.BobPeriod = 0.18, 2.6
Armory.StairW = 3.0 -- the stairs at each end, x +-(HalfWidth - StairW .. HalfWidth)
Armory.StairRun = 1.0 -- tread depth
Armory.LabelW, Armory.LabelH = 6.0, 2.7 -- the nameplate's size (B31: the price line over a stud tall)
-- Tones, two or three per surface: a lit body, a darker band at the foot and under every cap, a light trim on
-- every top edge, in the hall floor's lavender family.
Armory.Tone = {
	-- (B34 fix round: warm greys and cream instead of the cold lavender, on the east quadrant's green field)
	deck = C(214, 204, 190), tread = C(222, 212, 198), trim = C(240, 232, 220), face = C(150, 132, 118),
	kick = C(118, 102, 92), riser = C(178, 164, 150), wall = C(176, 160, 146), band = C(136, 118, 104),
	pilaster = C(222, 212, 198), pad = C(228, 220, 208), padLip = C(244, 238, 228), plinth = C(130, 112, 100),
	apron = C(196, 188, 176), kerb = C(98, 86, 78), kerbTop = C(132, 116, 104),
	matRim = C(244, 246, 255),
}

-- Optional modules made by other builders (Shared.HoodVFX, Shared.Models.GunModels / IconModels): nil when
-- they are not there yet or fail to load.
function Armory.optional(name)
	local shared = ReplicatedStorage:FindFirstChild('Shared')
	local models = shared and shared:FindFirstChild('Models')
	local m = shared and (shared:FindFirstChild(name) or (models and models:FindFirstChild(name)))
	if not m then return nil end
	local ok, result = pcall(require, m)
	return ok and result or nil
end

-- The dark tone of a state (GunRules.Colors[state].Shade, or the plate colour darkened when an older GunRules has none).
function Armory.shade(look)
	return look.Shade or look.Strip:Lerp(C(0, 0, 0), 0.35)
end

-- Box of a model's visible parts in `frame` space: lo, hi corners.
function Armory.extents(model, frame)
	local lo, hi = V(math.huge, math.huge, math.huge), V(-math.huge, -math.huge, -math.huge)
	for _, p in model:GetDescendants() do
		if p:IsA('BasePart') and p.Transparency < 1 then
			local x, y, z, a, b, cc, d, e, f, g, h, i = frame:ToObjectSpace(p.CFrame):GetComponents()
			local s = p.Size
			local hx = (math.abs(a) * s.X + math.abs(b) * s.Y + math.abs(cc) * s.Z) / 2
			local hy = (math.abs(d) * s.X + math.abs(e) * s.Y + math.abs(f) * s.Z) / 2
			local hz = (math.abs(g) * s.X + math.abs(h) * s.Y + math.abs(i) * s.Z) / 2
			lo = V(math.min(lo.X, x - hx), math.min(lo.Y, y - hy), math.min(lo.Z, z - hz))
			hi = V(math.max(hi.X, x + hx), math.max(hi.Y, y + hy), math.max(hi.Z, z + hz))
		end
	end
	if lo.X == math.huge then return V(-0.5, -0.5, -0.5), V(0.5, 0.5, 0.5) end
	return lo, hi
end

-- A model's pivot without relying on GetPivot (works the same in Studio and the preview harness).
function Armory.pivotOf(model)
	local pp = model.PrimaryPart
	if pp then return pp.CFrame * pp.PivotOffset end
	local ok, pivot = pcall(function() return model.WorldPivot end)
	return ok and pivot or CFrame.new()
end
-- Moves every part so the model's pivot lands on `target`.
function Armory.place(model, target)
	local delta = target * Armory.pivotOf(model):Inverse()
	for _, p in model:GetDescendants() do
		if p:IsA('BasePart') then p.CFrame = delta * p.CFrame end
	end
	if not model.PrimaryPart then model.WorldPivot = target end
end

-- Stand-in gun while GunModels is missing: a chunky blocky gun in the contract's frame (grip at the origin,
-- muzzle toward -Z, up +Y; a pistol is about 1.6 long). Longer guns get a stock; the colour runs down a stripe.
function Armory.placeholder(gun, scale)
	local s = scale or 1
	local model = Instance.new('Model')
	model.Name = gun.Id
	local long = ({ Shotgun = 3.4, Tommy = 3.2, AK = 3.4, Minigun = 3.8, Blaster = 2.8, Diamond = 4 })[gun.Id]
	local len = long or (gun.Id == 'Uzi' and 2 or gun.Id == 'Deagle' and 1.9 or 1.6)
	local dark, metal = C(62, 66, 78), C(150, 156, 168)
	local function add(name, size, cf, color, material, shape)
		local p = Instance.new('Part')
		p.Name = name
		p.Anchored, p.CanCollide, p.CanTouch, p.CanQuery = true, false, false, false
		p.Size = size * s
		p.CFrame = CFrame.new(cf.Position * s) * cf.Rotation
		p.Color = color
		p.Material = material or M.SmoothPlastic
		if shape then p.Shape = shape end
		p.Parent = model
		return p
	end
	local front = -len + 0.35
	local grip = add('Grip', V(0.3, 0.75, 0.42), CFrame.new(0, -0.22, 0.12) * CFrame.Angles(math.rad(-14), 0, 0), long and C(132, 82, 48) or dark, long and M.Wood or M.SmoothPlastic)
	add('Body', V(0.34, 0.44, len), CFrame.new(0, 0.32, front / 2 + 0.3), dark)
	add('Stripe', V(0.36, 0.12, len * 0.7), CFrame.new(0, 0.38, front / 2 + 0.2), gun.Color, M.Neon)
	add('Barrel', V(0.34, 0.2, 0.2), CFrame.new(0, 0.3, front - 0.12) * CFrame.Angles(0, math.pi / 2, 0), metal, M.Metal, Enum.PartType.Cylinder)
	add('Guard', V(0.12, 0.22, 0.36), CFrame.new(0, -0.02, -0.22), dark)
	add('Sight', V(0.1, 0.1, 0.16), CFrame.new(0, 0.58, front + 0.12), metal, M.Metal)
	if long then
		add('Stock', V(0.3, 0.5, 0.9), CFrame.new(0, 0.18, 0.8), C(132, 82, 48), M.Wood)
		add('Mag', V(0.26, 0.6, 0.3), CFrame.new(0, -0.12, front / 2 + 0.2), dark)
	end
	model.PrimaryPart = grip
	grip.PivotOffset = grip.CFrame:Inverse() -- the model's pivot is the origin, as GunModels promises
	return model
end

-- The display gun: GunModels.build when it exists (else the stand-in), sized for its small pad (LOBBY5: the
-- superhero stand's small items). Small guns are scaled up more than big ones (display length ~ natural length^0.5),
-- so a pistol is about 2 studs and the long guns about 3, and each tier gets 3% more on top, up to MaxLength.
function Armory.gun(gun, shrink)
	local models = Armory.optional('GunModels')
	local function make(scale)
		if models and models.build then
			local ok, model = pcall(models.build, gun.Id, scale)
			if ok and model then return model end
		end
		return Armory.placeholder(gun, scale)
	end
	-- (B31 PLAZA) through ItemMeshes (GunStand_<Id>, the user's own gun designs when they land), the Part gun as the
	-- fallback: the mesh is fitted to the Part gun's display length, its pivot at its centre
	local IM = Armory.optional('ItemMeshes')
	if IM and IM.has and IM.place and IM.has('GunStand_' .. gun.Id) then
		local probe = make(1)
		local plo, phi = Armory.extents(probe, Armory.pivotOf(probe))
		probe:Destroy()
		local pl = math.max(phi.X - plo.X, phi.Y - plo.Y, phi.Z - plo.Z, 0.1)
		local len = math.min(Armory.MaxLength, Armory.GunK * pl ^ 0.5 * (1 + 0.03 * (gun.Tier - 1))) * (shrink or 1)
		local ok, m = pcall(IM.place, 'GunStand_' .. gun.Id, CFrame.new(), len, nil, function() return nil end, { center = true })
		if ok and m then
			m.Name = gun.Id
			pcall(function() m.WorldPivot = CFrame.new() end)
			for _, p in m:GetDescendants() do
				if p:IsA('BasePart') then p.Anchored, p.CanCollide, p.CanTouch, p.CanQuery = true, false, false, false end
			end
			return m
		end
	end
	local model = make(1)
	local lo, hi = Armory.extents(model, Armory.pivotOf(model))
	local size = hi - lo
	local longest = math.max(size.X, size.Y, size.Z, 0.1)
	local length = math.min(Armory.MaxLength, Armory.GunK * longest ^ 0.5 * (1 + 0.03 * (gun.Tier - 1))) * (shrink or 1)
	if math.abs(longest - length) > 0.05 then
		model:Destroy()
		model = make(length / longest)
	end
	for _, p in model:GetDescendants() do
		if p:IsA('BasePart') then p.Anchored, p.CanCollide, p.CanTouch, p.CanQuery = true, false, false, false end
	end
	return model
end

-- Effects that grow with tier (`part` is a box round the gun, which sizes them): a soft light for tiers 2-5, then
-- HoodVFX.item when the VFX module is there, otherwise a light, sparkles, rising glow and star glints for the last
-- two. All of it sized for the small stand: short lights, particles at most 1.1 studs.
function Armory.effects(part, tier, color)
	if tier < 2 then return end -- the free pistol stays plain, like the basic tool in the reference
	-- Tiers 2-5 get only a soft light: like the reference, effects are for the better items.
	if tier < 6 then
		light(part, color, 0.4 + tier * 0.08, 4 + tier * 0.3)
		return
	end
	local vfx = Armory.optional('HoodVFX')
	if vfx and vfx.item then
		local ok, made = pcall(vfx.item, part, tier, color)
		if ok then
			-- A shop display keeps only the small effects: no halo, rays, arcs or glitter (they white out the stand,
			-- worst with built-in textures), the rest capped at 1.1 studs and rising slowly so they stay under the
			-- nameplate.
			local kill = { ItemGlow = true, ItemRays = true, ItemArcs = true, ItemGlitter = true }
			for _, e in (type(made) == 'table' and made or {}) do
				if typeof(e) == 'Instance' and kill[e.Name] then
					e:Destroy()
				elseif typeof(e) == 'Instance' and e:IsA('ParticleEmitter') then
					pcall(function()
						local most = 0
						for _, kp in e.Size.Keypoints do most = math.max(most, kp.Value + kp.Envelope) end
						if most > 1.1 then
							local f, keys = 1.1 / most, {}
							for _, kp in e.Size.Keypoints do table.insert(keys, NumberSequenceKeypoint.new(kp.Time, kp.Value * f, kp.Envelope * f)) end
							e.Size = NumberSequence.new(keys)
						end
						if e.Name == 'ItemWisps' or e.Name == 'ItemFlames' or e.Name == 'ItemMotes' then
							e.Speed = NumberRange.new(e.Speed.Min * 0.5, e.Speed.Max * 0.5)
							e.Acceleration = e.Acceleration * 0.4
						end
					end)
				end
			end
			return
		end
	end
	light(part, color, 0.4 + tier * 0.08, 4 + tier * 0.3)
	local function emitter(name, texture, rate, life, speed, size, transparency)
		local e = Instance.new('ParticleEmitter')
		e.Name = name
		e.Texture = texture
		e.Rate = rate
		e.Lifetime = NumberRange.new(life[1], life[2])
		e.Speed = NumberRange.new(speed[1], speed[2])
		e.SpreadAngle = Vector2.new(180, 180)
		e.Size = size
		e.Transparency = transparency
		e.Color = ColorSequence.new(color:Lerp(P.white, 0.35), color)
		e.LightEmission = 1
		e.LightInfluence = 0
		e.RotSpeed = NumberRange.new(-90, 90)
		e.Rotation = NumberRange.new(0, 360)
		e.Parent = part
		return e
	end
	local fade = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(0.7, 0.4), NumberSequenceKeypoint.new(1, 1) })
	if tier >= 3 then
		emitter('Sparkles', 'rbxasset://textures/particles/sparkles_main.dds', 2 + tier, { 0.8, 1.5 }, { 0.3, 0.9 },
			NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.15 + tier * 0.02), NumberSequenceKeypoint.new(1, 0) }), fade)
	end
	if tier >= 6 then
		local glow = emitter('Glow', 'rbxasset://textures/particles/fire_main.dds', 2 + tier * 0.5, { 0.9, 1.6 }, { 0.4, 0.9 },
			NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.4 + tier * 0.04), NumberSequenceKeypoint.new(1, 0.1) }),
			NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.55), NumberSequenceKeypoint.new(1, 1) }))
		glow.EmissionDirection = Enum.NormalId.Top
		glow.SpreadAngle = Vector2.new(25, 25)
		glow.Acceleration = V(0, 1.0, 0)
	end
	if tier >= 9 then
		local star = emitter('Glints', 'rbxasset://textures/particles/sparkles_main.dds', 3, { 1.2, 2 }, { 0.2, 0.5 },
			NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.3, 0.7), NumberSequenceKeypoint.new(1, 0) }),
			NumberSequence.new(0.1))
		star:SetAttribute('PreviewTexture', 'star')
	end
end

-- The nameplate over a gun (LOBBY5 r2, CRITIC3: "one big +N Power line per pad, like the soldier stand's"): two
-- lines, the soldier game's stand plates (the gun's name is the prompt's, when you step on its pad):
--   Multiplier  big: "xN Power" with the Power icon
--   Price       the price with the Cash icon, or the state: EQUIPPED (green), OWNED (blue), BUY + price (yellow,
--               a locked gun you can afford), the price in red while it is locked (Armory.client repaints it)
-- Icons come from IconModels.Images when uploaded, else a text glyph kept in the label's Glyph attribute. 5.8 x 2.5
-- studs, its big line 1.5 tall, readable from the spine; HoodClient/LabelFade keeps it whole to 50 studs and fades it
-- out by 75 (FadeNear / FadeFar on the gui, over kind Gun's 38 / 62), so the whole ladder reads from the walkway like
-- the soldier stand and the far shelf is gone from the stages. (It sets MaxDistance itself: 80 is a fallback.)
function Armory.label(c, pos, gun, state, colors)
	local anchor = ghost(c:part('LabelAnchor', V(0.2, 0.2, 0.2), CFrame.new(pos), P.white))
	local g = Instance.new('BillboardGui')
	g.Name = 'GunLabel'
	g.Size = UDim2.fromScale(Armory.LabelW, Armory.LabelH)
	g.MaxDistance = 24
	-- (LOBBY5 r3, CRITIC3: the whole price ladder reads from the walkway, the back tiers too; B31 PLAZA, critic 3: up close
	-- only. Lobby round 2, the critic: "about 10 labels in one view, back rows over front rows": only the guns you stand by,
	-- whole to 16 studs from the camera, gone by 24, and a nearer plate hides one it covers, like ref_V2-02.0's 3 per view)
	g:SetAttribute('FadeNear', 16)
	g:SetAttribute('FadeFar', 24)
	g:SetAttribute('FadeGroup', 'Guns')
	g.LightInfluence = 0
	g.Parent = anchor
	local ink = C(24, 22, 40)
	local look = colors[state] or {}
	local icons = Armory.optional('IconModels')
	local images = icons and icons.Images or {}
	local function row(name, icon, glyph, text, color, y, h, stroke)
		local image = images[icon]
		local t = line(g, name, text, color, FONT.title, y, h, ink, stroke)
		if type(image) == 'string' and image ~= '' then
			local i = Instance.new('ImageLabel')
			i.Name = name == 'Price' and 'PriceIcon' or 'Icon'
			i.BackgroundTransparency = 1
			i.Image = image
			i.Position = UDim2.fromScale(0.1, y)
			i.Size = UDim2.fromScale(0.17, h)
			-- Icon on the left, the words left-aligned beside it.
			t.Position = UDim2.fromScale(0.28, y)
			t.Size = UDim2.fromScale(0.7, h)
			t.TextXAlignment = Enum.TextXAlignment.Left
			local a = Instance.new('UIAspectRatioConstraint')
			a.Parent = i
			i.Parent = g
			t:SetAttribute('Glyph', '')
		else
			t.Text = glyph .. ' ' .. text
			t:SetAttribute('Glyph', glyph)
		end
		return t
	end
	row('Multiplier', 'Power', '💪', 'x' .. gun.Multiplier .. ' Power', P.white, 0, 0.6, 3)
	local price = row('Price', 'Cash', '💵', gun.Cost == 0 and 'FREE' or compact(gun.Cost), look.Word or C(255, 228, 92), 0.62, 0.38, 2)
	if state == 'Equipped' or state == 'Owned' then price.Text = '' end -- (lobby round 2: the state word is the plate's)
	shadowAll(g)
	return anchor
end

-- One gun on its pad. (x, z) is the pad centre, y the deck it stands on.
function Armory.slot(c, gun, x, z, y, colors)
	local T = Armory.Tone
	local s, model = c:group('GunSlot_' .. gun.Id)
	-- Streams in as one piece, so a client that sees the slot also sees its point, labels and gun.
	pcall(function() model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic end)
	model:SetAttribute('GunId', gun.Id)
	model:SetAttribute('Tier', gun.Tier)
	model:SetAttribute('Cost', gun.Cost)
	model:SetAttribute('Multiplier', gun.Multiplier)
	local state = gun.Cost == 0 and 'Equipped' or 'Locked' -- a new player's view; the client repaints
	local look = colors[state]
	local deck = y
	-- The slot's tile (the reference's white-framed square): a raised white rim round a studded mat in the state's
	-- soft tone; the pad stands in it.
	local mw, md, rw = Armory.Mat / 2, Armory.MatDepth / 2, 0.32
	studs(s:box('StateMat', V(x - mw + rw, y, z - md + rw), V(x + mw - rw, y + 0.12, z + md - rw), look.Mat or look.Glow, M.Plastic))
	for _, e in { { V(x - mw, y, z - md), V(x + mw, y + 0.2, z - md + rw) }, { V(x - mw, y, z + md - rw), V(x + mw, y + 0.2, z + md) },
		{ V(x - mw, y, z - md + rw), V(x - mw + rw, y + 0.2, z + md - rw) }, { V(x + mw - rw, y, z - md + rw), V(x + mw, y + 0.2, z + md - rw) } } do
		s:box('MatRim', e[1], e[2], T.matRim, M.SmoothPlastic)
	end
	y += 0.12
	-- The pad, bottom up: a dark plinth, the pale body with a state-coloured line round it, a light lip, and the face: a
	-- dark rim, the glowing state colour, a light core carrying the pad's light. Neon only on the face.
	local h = Armory.Pad / 2
	s:box('PadPlinth', V(x - h - 0.1, y, z - h - 0.1), V(x + h + 0.1, y + 0.16, z + h + 0.1), T.plinth, M.SmoothPlastic)
	s:box('PadBase', V(x - h, y + 0.16, z - h), V(x + h, y + 0.5, z + h), T.pad, M.SmoothPlastic)
	decor(s:box('StateTop', V(x - h - 0.03, y + 0.27, z - h - 0.03), V(x + h + 0.03, y + 0.36, z + h + 0.03), look.Top, M.SmoothPlastic)).CastShadow = false
	s:box('PadLip', V(x - h + 0.04, y + 0.5, z - h + 0.04), V(x + h - 0.04, y + 0.56, z + h - 0.04), T.padLip, M.SmoothPlastic)
	local top = y + 0.56
	decor(s:box('StateShade', V(x - h + 0.22, top, z - h + 0.22), V(x + h - 0.22, top + 0.03, z + h - 0.22), Armory.shade(look), M.SmoothPlastic)).CastShadow = false
	decor(s:box('StateTop', V(x - h + 0.42, top, z - h + 0.42), V(x + h - 0.42, top + 0.06, z + h - 0.42), look.Top, M.Neon)).CastShadow = false
	local core = decor(s:box('StateGlow', V(x - 0.7, top, z - 0.7), V(x + 0.7, top + 0.08, z + 0.7), look.Glow, M.Neon))
	core.CastShadow = false
	-- the face's glow on the tile round the pad (Armory.client recolours it with the face): short and soft
	light(core, look.Top, 1.2, 6)
	top += 0.08
	-- Soft haze rising off the face in the state colour, the reference's faint light over each pad (the client recolours it).
	local hazeSource = ghost(s:part('StateHazeSource', V(h * 1.2, 0.2, h * 1.2), CFrame.new(x, top + 0.1, z), look.Glow))
	hazeSource.CastShadow = false
	local haze = Instance.new('ParticleEmitter')
	haze.Name = 'StateHaze'
	haze.Texture = 'rbxasset://textures/particles/smoke_main.dds'
	haze.Rate = 1.6
	haze.Lifetime = NumberRange.new(1.2, 1.8)
	haze.Speed = NumberRange.new(0.6, 1.0)
	haze.SpreadAngle = Vector2.new(6, 6)
	haze.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.1), NumberSequenceKeypoint.new(1, 1.5) })
	haze.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.25, 0.88), NumberSequenceKeypoint.new(1, 1) })
	haze.Color = ColorSequence.new(look.Top)
	haze.LightEmission = 1
	haze.LightInfluence = 0
	haze.Rotation = NumberRange.new(0, 360)
	haze.RotSpeed = NumberRange.new(-20, 20)
	haze.Parent = hazeSource
	-- The plate on the pad's front: a block on the plinth with a light cap and two bolts, the state word on it.
	local strip = s:box('StateStrip', V(x - 1.35, y + 0.04, z - h - 0.24), V(x + 1.35, y + 0.5, z - h + 0.02), look.Strip, M.SmoothPlastic)
	s:box('PlateCap', V(x - 1.42, y + 0.5, z - h - 0.28), V(x + 1.42, y + 0.58, z - h + 0.02), T.trim, M.SmoothPlastic)
	for _, sx in { -1, 1 } do
		decor(s:part('PlateBolt', V(0.06, 0.14, 0.14), CFrame.new(x + sx * 1.18, y + 0.27, z - h - 0.25) * CFrame.Angles(0, math.pi / 2, 0), T.trim, M.Metal, Enum.PartType.Cylinder))
	end
	local sg = surface(strip, Enum.NormalId.Front, 60)
	sg.Name = 'StateGui'
	sg.MaxDistance = 26 -- (lobby round 2: the state tag reads at the stand, not across the hall)
	line(sg, 'State', string.upper(state), P.white, FONT.title, 0.06, 0.88, look.Strip:Lerp(P.black, 0.45), 2)
	-- The gun floating over the pad in profile to the hall (muzzle to the viewer's right), tilted up a little,
	-- bobbing; never turning, so it is never seen end-on.
	local d, display = s:group('Display')
	local tilt = math.rad(Armory.Tilt)
	local function measure(m)
		local lo, hi = Armory.extents(m, Armory.pivotOf(m))
		return lo, hi, (hi.Y - lo.Y) * math.cos(tilt) + (hi.Z - lo.Z) * math.sin(tilt)
	end
	local g = Armory.gun(gun, 1)
	local lo, hi, tall = measure(g)
	if tall > Armory.DisplayH then
		-- a deep gun (an Uzi's long magazine) stands too tall tilted: a size smaller, under the nameplate
		g:Destroy()
		g = Armory.gun(gun, Armory.DisplayH / tall)
		lo, hi, tall = measure(g)
	end
	local mid = (lo + hi) / 2
	local length = math.max(hi.X - lo.X, hi.Y - lo.Y, hi.Z - lo.Z)
	local centre = V(x, top + Armory.Float + tall / 2, z + 0.15)
	local pose = CFrame.new(centre) * CFrame.Angles(0, 0, -tilt) * CFrame.Angles(0, math.pi / 2, 0)
	Armory.place(g, d:world(pose * CFrame.new(-mid)))
	g.Name = 'Gun'
	g.Parent = display
	display.WorldPivot = d:world(CFrame.new(centre))
	display:SetAttribute('Bob', Armory.Bob)
	display:SetAttribute('BobPeriod', Armory.BobPeriod)
	display:AddTag('HoodMotion')
	local fx = ghost(s:part('FxCore', V(length * 0.5, math.max(tall * 0.7, length * 0.25), length * 0.2), CFrame.new(centre), gun.Color))
	fx.CastShadow = false
	Armory.effects(fx, gun.Tier, gun.Color)
	-- (every label in a row at one height, over the tallest gun, like the reference's nameplates)
	Armory.label(s, V(x, top + Armory.Float + Armory.DisplayH + 0.3 + Armory.LabelH / 2, z), gun, state, colors)
	-- Where the prompt sits and the server measures buying distance from: on the pad's front half, so stepping onto
	-- the pad (in front of the floating gun) brings up Buy / Equip, like the soldier game's stand.
	local point = ghost(s:box('GunPoint_' .. gun.Id, V(x - 0.6, top + 0.2, z - 0.45 * h - 0.6), V(x + 0.6, top + 1.6, z - 0.45 * h + 0.6), P.white))
	point.CastShadow = false
	local _ = deck
	return model
end

-- A pilaster on a wall face at z = zf (facing -Z): a dark base, a light shaft, a light cap.
function Armory.pilaster(c, x, zf, y0, y1, w)
	local T = Armory.Tone
	w = w or 1.0
	c:box('Pilaster', V(x - w / 2, y0, zf - 0.35), V(x + w / 2, y1, zf), T.pilaster, M.SmoothPlastic)
	c:box('PilasterBase', V(x - w / 2 - 0.15, y0, zf - 0.5), V(x + w / 2 + 0.15, y0 + 0.5, zf), T.kick, M.SmoothPlastic)
	c:box('PilasterCap', V(x - w / 2 - 0.15, y1 - 0.35, zf - 0.5), V(x + w / 2 + 0.15, y1, zf), T.trim, M.SmoothPlastic)
end

-- The island and the stand: the apron in its kerb, the three tiers (studded bodies, a dark kick at each wall's foot, a
-- dark band under a light coping on its top edge), a stair at each end from tier to tier, the backdrop on the top
-- tier's back (studded, a dark kick, a dark band under a light coping, pilasters between the top row's guns, corner
-- posts at its ends). Every surface in two or three tones.
function Armory.base(c)
	local b = c:group('ArmoryBase')
	local T, Ap = Armory.Tone, Armory.Apron
	local X, AX, D, Ay, kw = Armory.HalfWidth, Armory.ApronHalf, Armory.Depth, Ap.y, Ap.kerb
	local tiers, BZ, SW = Armory.Tiers, Armory.BackZ, Armory.StairW
	-- the island: a studded apron inside a dark studded kerb (0.15 proud) with a pale top band, studded corner blocks
	studs(b:box('ArmoryApron', V(-AX + kw, 0, kw), V(AX - kw, Ay, D - kw), T.apron))
	local ky = Ay + 0.15
	for _, e in { { V(-AX, 0, 0), V(AX, ky, kw) }, { V(-AX, 0, D - kw), V(AX, ky, D) }, { V(-AX, 0, kw), V(-AX + kw, ky, D - kw) }, { V(AX - kw, 0, kw), V(AX, ky, D - kw) } } do
		studs(b:box('ApronKerb', e[1], e[2], T.kerb, M.Plastic), true)
		decor(b:box('ApronKerbTop', V(e[1].X + 0.12, ky, e[1].Z + 0.12), e[2] + V(-0.12, 0.03, -0.12), T.kerbTop, M.SmoothPlastic)).CastShadow = false
	end
	for _, cx in { -AX + 0.7, AX - 0.7 } do
		for _, cz in { 0.7, D - 0.7 } do
			studs(b:box('ApronCorner', V(cx - 0.9, 0, cz - 0.9), V(cx + 0.9, 0.8, cz + 0.9), T.kerb, M.Plastic), true)
			b:box('ApronCornerCap', V(cx - 1.0, 0.8, cz - 1.0), V(cx + 1.0, 0.95, cz + 1.0), T.trim, M.SmoothPlastic)
		end
	end
	-- the tiers: each a studded body from its front wall to the top tier's back under a studded top slab (two tones), a
	-- dark kick at its wall's foot, a dark band under a light coping on its front edge; the band and coping run round the
	-- ends too
	for k, t in tiers do
		local y0 = k == 1 and Ay or tiers[k - 1].y
		studs(b:box('ArmoryTier', V(-X, Ay, t.z), V(X, t.y - 0.12, BZ), T.wall, M.Plastic), true)
		studs(b:box('ArmoryTierTop', V(-X, t.y - 0.12, t.z), V(X, t.y, BZ), T.deck, M.Plastic))
		b:box('TierKick', V(-X - 0.04, y0, t.z - 0.12), V(X + 0.04, y0 + 0.3, t.z), T.kick, M.SmoothPlastic)
		b:box('TierBand', V(-X - 0.04, t.y - 0.62, t.z - 0.1), V(X + 0.04, t.y - 0.3, t.z), T.band, M.SmoothPlastic)
		b:box('TierCoping', V(-X - 0.08, t.y - 0.3, t.z - 0.3), V(X + 0.08, t.y + 0.02, t.z + 0.35), T.trim, M.SmoothPlastic)
		for _, sx in { -1, 1 } do
			local a, e = sx * X, sx * (X + 0.1)
			b:box('TierBand', V(math.min(a, e), t.y - 0.62, t.z), V(math.max(a, e), t.y - 0.3, BZ), T.band, M.SmoothPlastic)
			-- (one kick along each end's foot: the upper tiers stand on the same foot)
			if k == 1 then b:box('TierKick', V(math.min(a, e), Ay, t.z), V(math.max(a, e), Ay + 0.3, BZ), T.kick, M.SmoothPlastic) end
		end
	end
	-- the stairs at each end, from each tier up to the next (0.8 risers on 1.0 treads, ending at the next tier's front
	-- wall): a mid-tone riser body under a light studded tread, a light stringer cap along the outer edge
	for k = 2, #tiers do
		local lo, hi, zt = tiers[k - 1].y, tiers[k].y, tiers[k].z
		local n = math.ceil((hi - lo) / 0.81) - 1
		local rise, run = (hi - lo) / (n + 1), Armory.StairRun
		for _, sx in { -1, 1 } do
			local l, r = math.min(sx * (X - SW), sx * X), math.max(sx * (X - SW), sx * X)
			for j = 1, n do
				local z0 = zt - (n + 1 - j) * run
				local h = lo + j * rise
				b:box('ArmoryStair', V(l, lo, z0), V(r, h - 0.15, zt), T.riser, M.SmoothPlastic)
				studs(b:box('StairTread', V(l, h - 0.15, z0 - 0.05), V(r, h, z0 + run), T.tread, M.Plastic))
			end
		end
	end
	-- the backdrop on the top tier's back: studded both sides, a dark kick, a dark band and a light coping; pilasters
	-- between the top row's guns; corner posts from the apron to over the coping at its ends
	local y3 = tiers[#tiers].y
	local top = Armory.Top
	studs(b:box('ArmoryBack', V(-X, Ay, BZ), V(X, top, BZ + Armory.BackT), T.wall, M.Plastic), true)
	b:box('BackKick', V(-X, y3, BZ - 0.12), V(X, y3 + 0.4, BZ), T.kick, M.SmoothPlastic)
	b:box('BackBand', V(-X, top - 0.9, BZ - 0.12), V(X, top - 0.4, BZ), T.band, M.SmoothPlastic)
	b:box('BackCoping', V(-X - 0.2, top - 0.4, BZ - 0.4), V(X + 0.2, top, BZ + Armory.BackT + 0.2), T.trim, M.SmoothPlastic)
	local row = Armory.Rows[#Armory.Rows]
	for i = 1, #row.xs - 1 do
		Armory.pilaster(b, (row.xs[i] + row.xs[i + 1]) / 2 * Armory.Spacing, BZ, y3, top - 0.9)
	end
	for _, sx in { -1, 1 } do
		local xa, xb = sx * (X - 1.0), sx * (X + 0.25)
		local l, r = math.min(xa, xb), math.max(xa, xb)
		b:box('CornerPost', V(l, Ay, BZ - 0.8), V(r, top + 0.6, BZ + Armory.BackT + 0.25), T.pilaster, M.SmoothPlastic)
		b:box('CornerBase', V(l - 0.15, Ay, BZ - 0.95), V(r + 0.15, Ay + 0.7, BZ + Armory.BackT + 0.4), T.kick, M.SmoothPlastic)
		b:box('CornerCap', V(l - 0.15, top + 0.6, BZ - 0.95), V(r + 0.15, top + 0.9, BZ + Armory.BackT + 0.4), T.trim, M.SmoothPlastic)
	end
	-- a thin white neon line along the coping's front: the stand's outline from across the hall (the reference's lit edge)
	decor(b:box('BackNeon', V(-X + 1.0, top - 0.42, BZ - 0.44), V(X - 1.0, top - 0.3, BZ - 0.4), C(240, 246, 255), M.Neon)).CastShadow = false
	return b
end

-- Builds the whole armory in ctx's frame. opts.guns overrides the gun list (default Config.Guns.List).
function Armory.build(ctx, opts)
	opts = opts or {}
	local guns = opts.guns or require(ReplicatedStorage.Shared.Config.Guns).List
	local colors = require(ReplicatedStorage.Shared.GunRules).Colors
	local a, model = ctx:group('Armory')
	model:AddTag('HoodArmory')
	Armory.base(a)
	-- the guns in order, row by row from the front, each row from the viewer's left (gun 1 on the front row's left:
	-- their left is +X when they look toward +Z)
	local i = 0
	for _, row in Armory.Rows do
		local t = Armory.Tiers[row.tier]
		for _, u in row.xs do
			i += 1
			local gun = guns[i]
			if not gun then return model end
			Armory.slot(a, gun, u * Armory.Spacing, t.z + Armory.RowInset, t.y, colors)
		end
	end
	return model
end
