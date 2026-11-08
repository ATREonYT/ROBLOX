--!strict
-- +1 Chess Evolution: the chess items (this game's "phones" from the reference).
-- Every Chess Set has its own item: a small upright chess board with its own colours,
-- frame and ornament, and its own effect. The same item shows in three places:
--   ChessItems.Build(setId, scale)      the model (base at bottom centre, board face toward -Z)
--   ChessItems.AddFx(model, setId, k)   its effect; k = 1 in the gallery case, smaller on the player
--   ChessItems.Wear(character, setId)   (server) the item in the player's right hand plus a body aura
-- Effects use Roblox's built-in particle pictures. Alex's VFX pack textures (LihFolk Asset Pack)
-- replace them once uploaded: paste each uploaded id into ChessItems.PackIds (0 = use the built-in).
-- Rules (VFX-ITEMS.md): tie each effect to the set (its accent colour, a motif from its name),
-- grow with the tier, no flashes, Brightness/LightEmission kept low enough to read on a sunny map.

local ChessItems = {}

-- The held board is a Tool; the game has no other tools, so the client hides the hotbar
-- (otherwise a "ChessItem" slot shows and pressing 1 would put the board away).
if game:GetService("RunService"):IsClient() then
	task.spawn(function()
		for _ = 1, 10 do
			if pcall(function()
				game:GetService("StarterGui"):SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
			end) then
				break
			end
			task.wait(1)
		end
	end)
end

-- Alex's pack textures (assets/vfx-pack/*.png). 0 = not uploaded yet, the built-in picture is used.
ChessItems.PackIds = {
	glint_star4 = 0, -- 4-point star glint: Marble, Royal, Champion
	flip_petals_8x8 = 0, -- petal flipbook: Jade leaves
	spark_streak = 0, -- thin spark streak: Sapphire lightning
	crystal_facets = 0, -- faceted shard: Crystal
	glow_soft = 0, -- soft round glow: halos
	frost_ring = 0, -- ring: Crystal and Cosmic floor rings
}

local BUILTIN = {
	sparkles = "rbxasset://textures/particles/sparkles_main.dds",
	fire = "rbxasset://textures/particles/fire_main.dds",
	sparks = "rbxasset://textures/particles/fire_sparks_main.dds",
	smoke = "rbxasset://textures/particles/smoke_main.dds",
	glow = "rbxasset://textures/particles/forcefield_glow_main.dds",
	vortex = "rbxasset://textures/particles/forcefield_vortex_main.dds",
}

local function tex(pack: string?, fallback: string): string
	local id = pack and (ChessItems.PackIds :: any)[pack]
	if type(id) == "number" and id > 0 then
		return "rbxassetid://" .. id
	end
	return BUILTIN[fallback] or fallback
end

local WOOD, MARBLE, METAL, GLASS, NEON, PLASTIC, SLATE =
	Enum.Material.Wood, Enum.Material.Marble, Enum.Material.Metal, Enum.Material.Glass, Enum.Material.Neon, Enum.Material.SmoothPlastic, Enum.Material.Slate
local rgb = Color3.fromRGB

-- One look per set. light/dark = squares, frame = border, ornament = what makes it its own item.
ChessItems.Looks = {
	Wooden = { light = rgb(232, 196, 140), dark = rgb(150, 96, 48), sq = WOOD, frame = rgb(105, 64, 32), frameMat = WOOD, ornament = "none" },
	Marble = { light = rgb(245, 247, 250), dark = rgb(150, 160, 176), sq = MARBLE, frame = rgb(205, 212, 222), frameMat = METAL, ornament = "edge" },
	Jade = { light = rgb(160, 236, 180), dark = rgb(36, 140, 86), sq = MARBLE, frame = rgb(255, 200, 60), frameMat = METAL, ornament = "beads" },
	Ruby = { light = rgb(255, 150, 160), dark = rgb(130, 12, 36), sq = PLASTIC, frame = rgb(70, 20, 28), frameMat = METAL, ornament = "gems" },
	Sapphire = { light = rgb(160, 196, 255), dark = rgb(24, 56, 170), sq = PLASTIC, frame = rgb(210, 220, 235), frameMat = METAL, ornament = "bolts" },
	Gold = { light = rgb(255, 244, 200), dark = rgb(232, 168, 24), sq = METAL, frame = rgb(255, 196, 40), frameMat = METAL, ornament = "king" },
	Obsidian = { light = rgb(96, 44, 150), dark = rgb(18, 14, 28), sq = SLATE, frame = rgb(24, 20, 34), frameMat = SLATE, ornament = "shards" },
	Royal = { light = rgb(255, 176, 232), dark = rgb(120, 40, 180), sq = PLASTIC, frame = rgb(255, 200, 60), frameMat = METAL, ornament = "crown" },
	Crystal = { light = rgb(220, 248, 255), dark = rgb(110, 200, 245), sq = GLASS, frame = rgb(180, 236, 255), frameMat = GLASS, ornament = "spikes" },
	Cosmic = { light = rgb(76, 54, 170), dark = rgb(20, 16, 60), sq = PLASTIC, frame = rgb(36, 26, 96), frameMat = PLASTIC, ornament = "planet" },
	Champion = { light = rgb(255, 250, 230), dark = rgb(255, 186, 40), sq = METAL, frame = rgb(255, 210, 70), frameMat = METAL, ornament = "wings" },
}

local function part(parent: Instance, name: string, size: Vector3, cf: CFrame, color: Color3, mat: Enum.Material?, props: { [string]: any }?): BasePart
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = mat or PLASTIC
	p.Anchored = true
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	p.CastShadow = false
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

local function ball(parent: Instance, name: string, d: number, cf: CFrame, color: Color3, mat: Enum.Material?): BasePart
	local p = part(parent, name, Vector3.new(d, d, d), cf, color, mat)
	p.Shape = Enum.PartType.Ball
	return p
end

local function wedge(parent: Instance, name: string, size: Vector3, cf: CFrame, color: Color3, mat: Enum.Material?): BasePart
	local p = Instance.new("WedgePart")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = mat or PLASTIC
	p.Anchored, p.CanCollide, p.CanTouch, p.CanQuery, p.CastShadow = true, false, false, false, false
	p.Parent = parent
	return p
end

-- A spike pointing up from `at` (a wedge pair makes a diamond-ish point).
local function spike(parent: Instance, name: string, w: number, h: number, at: CFrame, color: Color3, mat: Enum.Material?)
	wedge(parent, name, Vector3.new(0.12 * w / 0.5, h, w / 2), at * CFrame.new(0, h / 2, -w / 4) * CFrame.Angles(0, math.pi, 0), color, mat)
	wedge(parent, name, Vector3.new(0.12 * w / 0.5, h, w / 2), at * CFrame.new(0, h / 2, w / 4), color, mat)
end

local function crown(parent: Instance, at: CFrame, s: number, color: Color3, gem: Color3)
	local band = part(parent, "CrownBand", Vector3.new(1.3 * s, 0.32 * s, 0.32 * s), at * CFrame.new(0, 0.16 * s, 0), color, METAL)
	local _ = band
	for i = -2, 2 do
		local h = (if i == 0 then 0.75 else 0.5) * s
		spike(parent, "CrownPoint", 0.3 * s, h, at * CFrame.new(i * 0.28 * s, 0.32 * s, 0), color, METAL)
		ball(parent, "CrownGem", 0.16 * s, at * CFrame.new(i * 0.28 * s, 0.32 * s + h + 0.02 * s, 0), gem, NEON)
	end
end

-- The board: W studs square, standing upright, tilted back 10 degrees, base at `at` (default the origin).
function ChessItems.Build(setId: string, scale: number?, at: CFrame?): Model
	local look = (ChessItems.Looks :: any)[setId] or ChessItems.Looks.Wooden
	local s = scale or 1
	local W = 3 * s
	local m = Instance.new("Model")
	m.Name = "ChessItem"
	m:SetAttribute("SetId", setId)
	local centre = (at or CFrame.identity) * CFrame.new(0, W / 2 + 0.25 * s, 0) * CFrame.Angles(math.rad(-10), 0, 0)
	local core = part(m, "Core", Vector3.new(0.2, 0.2, 0.2), centre, Color3.new(), nil, { Transparency = 1 })
	m.PrimaryPart = core
	local frameT = 0.28 * s
	local rim = (if look.ornament == "king" or look.ornament == "wings" then 0.36 else 0.24) * s
	part(m, "Frame", Vector3.new(W + rim * 2, W + rim * 2, frameT), centre, look.frame, look.frameMat)
	-- 4 x 4 squares on the front (-Z)
	local n, q = 4, W / 4
	for i = 0, n - 1 do
		for j = 0, n - 1 do
			local lightSq = (i + j) % 2 == 0
			local sq = part(m, "Square", Vector3.new(q, q, 0.08 * s), centre * CFrame.new((i - 1.5) * q, (j - 1.5) * q, -frameT / 2 - 0.04 * s), if lightSq then look.light else look.dark, look.sq)
			if look.sq == GLASS then
				sq.Transparency = if lightSq then 0.15 else 0.35
			end
			if look.ornament == "planet" and not lightSq and (i * 3 + j) % 5 == 1 then
				sq.Color = rgb(255, 255, 255)
				sq.Material = NEON -- a few "stars" in the night-sky board
			end
		end
	end
	local half = W / 2 + rim
	local o = look.ornament
	local accentNeon = (function()
		if o == "edge" then
			return rgb(80, 230, 255)
		elseif o == "shards" then
			return rgb(170, 90, 255)
		elseif o == "planet" then
			return rgb(150, 110, 255)
		end
		return nil
	end)()
	if accentNeon then
		-- thin neon strips around the frame's front face
		local t = 0.08 * s
		local z = -frameT / 2 - 0.02 * s
		part(m, "Edge", Vector3.new(W + rim * 2, t, t), centre * CFrame.new(0, half - t / 2, z), accentNeon, NEON)
		part(m, "Edge", Vector3.new(W + rim * 2, t, t), centre * CFrame.new(0, -half + t / 2, z), accentNeon, NEON)
		part(m, "Edge", Vector3.new(t, W + rim * 2, t), centre * CFrame.new(half - t / 2, 0, z), accentNeon, NEON)
		part(m, "Edge", Vector3.new(t, W + rim * 2, t), centre * CFrame.new(-half + t / 2, 0, z), accentNeon, NEON)
	end
	if o == "beads" or o == "gems" then
		local gem = if o == "beads" then rgb(90, 220, 140) else rgb(255, 40, 70)
		local d = (if o == "beads" then 0.5 else 0.6) * s
		for _, c in { { 1, 1 }, { -1, 1 }, { 1, -1 }, { -1, -1 } } do
			ball(m, "Gem", d, centre * CFrame.new(c[1] * half, c[2] * half, -0.05 * s), gem, if o == "gems" then NEON else MARBLE)
		end
		if o == "gems" then
			-- one big ruby on top
			local top = centre * CFrame.new(0, half + 0.3 * s, 0)
			part(m, "BigGem", Vector3.new(0.7, 0.7, 0.7) * s, top * CFrame.Angles(0, 0, math.rad(45)), rgb(255, 30, 60), NEON)
		end
	elseif o == "bolts" then
		for _, x in { -1, 1 } do
			local base = centre * CFrame.new(x * W * 0.3, half, 0) * CFrame.Angles(0, 0, x * math.rad(-12))
			spike(m, "Bolt", 0.4 * s, 1.1 * s, base, rgb(90, 170, 255), NEON)
		end
	elseif o == "king" then
		-- a little gold king standing on the top edge
		local top = centre * CFrame.new(0, half, 0)
		part(m, "KingFoot", Vector3.new(0.9, 0.2, 0.6) * s, top * CFrame.new(0, 0.1 * s, 0), look.frame, METAL)
		part(m, "KingBody", Vector3.new(0.5, 0.9, 0.4) * s, top * CFrame.new(0, 0.65 * s, 0), look.frame, METAL)
		ball(m, "KingHead", 0.55 * s, top * CFrame.new(0, 1.25 * s, 0), look.frame, METAL)
		part(m, "KingCross", Vector3.new(0.12, 0.5, 0.12) * s, top * CFrame.new(0, 1.7 * s, 0), rgb(255, 240, 160), NEON)
		part(m, "KingCross", Vector3.new(0.36, 0.12, 0.12) * s, top * CFrame.new(0, 1.75 * s, 0), rgb(255, 240, 160), NEON)
	elseif o == "shards" then
		for i, x in { -0.9, -0.3, 0.35, 0.95 } do
			local h = ({ 0.9, 1.4, 1.1, 0.7 })[i] * s
			spike(m, "Shard", 0.35 * s, h, centre * CFrame.new(x * W / 2, half, 0) * CFrame.Angles(0, 0, math.rad(-x * 15)), rgb(30, 22, 44), SLATE)
		end
	elseif o == "crown" or o == "wings" then
		crown(m, centre * CFrame.new(0, half, 0), 1.1 * s, rgb(255, 205, 60), if o == "crown" then rgb(255, 90, 210) else rgb(255, 80, 40))
		if o == "wings" then
			for _, x in { -1, 1 } do
				for k = 0, 2 do
					local w = part(m, "Wing", Vector3.new((1.5 - k * 0.35) * s, 0.42 * s, 0.14 * s),
						centre * CFrame.new(x * (half + (0.55 - k * 0.1) * s), (0.6 - k * 0.5) * s, 0.1 * s) * CFrame.Angles(0, 0, x * math.rad(25 + k * 12)),
						if k == 0 then rgb(255, 250, 235) else rgb(255, 220, 120), if k == 0 then PLASTIC else METAL)
					local _ = w
				end
			end
		end
	elseif o == "spikes" then
		for i = 0, 5 do
			local a = i / 6 * math.pi * 2 + math.pi / 6
			local r = half + 0.1 * s
			local h = (if i % 2 == 0 then 1.0 else 0.7) * s
			part(m, "Spike", Vector3.new(0.34 * s, h, 0.34 * s), centre * CFrame.new(math.cos(a) * r, math.sin(a) * r, 0) * CFrame.Angles(0, 0, a - math.pi / 2) * CFrame.new(0, h / 2, 0) * CFrame.Angles(0, math.rad(45), 0), rgb(160, 235, 255), GLASS, { Transparency = 0.2 })
		end
	elseif o == "planet" then
		-- a ring around the board like a planet's
		local ringCf = centre * CFrame.Angles(math.rad(70), 0, math.rad(20))
		for i = 0, 15 do
			local a = i / 16 * math.pi * 2
			local r = W * 0.82
			part(m, "Ring", Vector3.new(0.9 * s, 0.1 * s, 0.22 * s), ringCf * CFrame.new(math.cos(a) * r, 0, math.sin(a) * r) * CFrame.Angles(0, -a + math.pi / 2, 0), rgb(160, 120, 255), NEON, { Transparency = 0.15 })
		end
	end
	return m
end

---------------------------------------------------------------------------
-- Effects
---------------------------------------------------------------------------
local function ns(a: number, b: number?, c: number?): NumberSequence
	if b and c then
		return NumberSequence.new({ NumberSequenceKeypoint.new(0, a), NumberSequenceKeypoint.new(0.3, b), NumberSequenceKeypoint.new(1, c) })
	end
	return NumberSequence.new(a)
end

type Em = {
	tex: string, pack: string?, color: Color3, color2: Color3?, rate: number, size: number, life: number, speed: number,
	accel: Vector3?, spread: number?, rot: number?, emission: number?, alpha: number?, box: Vector3?, lockZ: boolean?, flip: boolean?,
}

local function emitter(att: Instance, name: string, e: Em, k: number): ParticleEmitter
	local p = Instance.new("ParticleEmitter")
	p.Name = name
	p.Texture = tex(e.pack, e.tex)
	p.Color = ColorSequence.new(e.color, e.color2 or e.color)
	p.LightEmission = e.emission or 0.7
	p.LightInfluence = 0
	p.Brightness = 2.5 -- Studio check (Nov 7): 1.5 read too faint on the sunny map; cap is 6
	p.Size = ns(0, e.size * k * 1.5, 0)
	p.Transparency = ns(e.alpha or 0.15, e.alpha or 0.15, 1)
	p.Lifetime = NumberRange.new(e.life * 0.75, e.life)
	p.Rate = e.rate * 1.4 * (0.4 + 0.6 * k)
	p.Speed = NumberRange.new(e.speed * 0.6 * k, e.speed * k)
	p.SpreadAngle = Vector2.new(e.spread or 180, e.spread or 180)
	p.Acceleration = (e.accel or Vector3.zero) * k
	p.Rotation = NumberRange.new(0, 360)
	p.RotSpeed = NumberRange.new(-(e.rot or 40), e.rot or 40)
	if e.box then
		p.Shape = Enum.ParticleEmitterShape.Box
	end
	if e.lockZ then
		p.LockedToPart = true
	end
	if e.flip and e.pack and (ChessItems.PackIds :: any)[e.pack] > 0 then
		p.FlipbookLayout = Enum.ParticleFlipbookLayout.Grid8x8
		p.FlipbookMode = Enum.ParticleFlipbookMode.OneShot
	end
	p.Parent = att
	return p
end

local WHITE = rgb(255, 255, 255)
-- Per set: emitters around the item. Grows with the tier: more layers, more particles.
ChessItems.Fx = {
	Wooden = {},
	Marble = { -- glints and a cool halo (marble shine)
		{ tex = "sparkles", pack = "glint_star4", color = rgb(200, 250, 255), color2 = WHITE, rate = 7, size = 0.7, life = 1.4, speed = 1 },
		{ tex = "glow", pack = "glow_soft", color = rgb(80, 230, 255), rate = 2, size = 3.4, life = 1.6, speed = 0, alpha = 0.7, rot = 10 },
	},
	Jade = { -- leaves drifting down and swirling (jade = leaf green)
		{ tex = "sparks", pack = "flip_petals_8x8", color = rgb(120, 255, 160), color2 = rgb(40, 180, 90), rate = 9, size = 0.6, life = 2.2, speed = 1.4, accel = Vector3.new(0, -0.8, 0), rot = 120, flip = true },
		{ tex = "sparkles", color = rgb(190, 255, 200), rate = 4, size = 0.5, life = 1.4, speed = 0.8 },
	},
	Ruby = { -- a red flame and rising embers
		{ tex = "fire", color = rgb(255, 60, 80), color2 = rgb(255, 150, 60), rate = 14, size = 1.6, life = 0.9, speed = 1.2, accel = Vector3.new(0, 3, 0), spread = 25, emission = 0.6, alpha = 0.35 },
		{ tex = "sparks", color = rgb(255, 120, 90), rate = 8, size = 0.35, life = 1.4, speed = 2.5, accel = Vector3.new(0, 2, 0), spread = 40 },
	},
	Sapphire = { -- fast blue sparks crackling off the bolts
		{ tex = "sparks", pack = "spark_streak", color = rgb(130, 200, 255), color2 = WHITE, rate = 18, size = 0.5, life = 0.45, speed = 6, emission = 0.9 },
		{ tex = "glow", pack = "glow_soft", color = rgb(60, 120, 255), rate = 2, size = 3.6, life = 1.2, speed = 0, alpha = 0.7 },
		{ tex = "sparkles", color = rgb(170, 210, 255), rate = 5, size = 0.6, life = 1.2, speed = 1 },
	},
	Gold = { -- gold dust that floats up, warm halo (orbiting coins are animated by the client)
		{ tex = "sparkles", pack = "glint_star4", color = rgb(255, 230, 120), color2 = rgb(255, 180, 40), rate = 12, size = 0.75, life = 1.8, speed = 1.2, accel = Vector3.new(0, 1, 0) },
		{ tex = "glow", pack = "glow_soft", color = rgb(255, 200, 60), rate = 2, size = 4, life = 1.6, speed = 0, alpha = 0.65 },
	},
	Obsidian = { -- a dark purple void: smoke rising, violet sparks
		{ tex = "smoke", color = rgb(70, 30, 120), color2 = rgb(20, 10, 40), rate = 10, size = 2.4, life = 1.8, speed = 0.8, accel = Vector3.new(0, 1.2, 0), emission = 0.1, alpha = 0.35 },
		{ tex = "sparks", color = rgb(190, 110, 255), rate = 9, size = 0.4, life = 1, speed = 2.5 },
		{ tex = "vortex", color = rgb(150, 70, 255), rate = 1.5, size = 4.2, life = 1.6, speed = 0, alpha = 0.55, rot = 90 },
	},
	Royal = { -- pink star glints around the crown and a royal halo
		{ tex = "sparkles", pack = "glint_star4", color = rgb(255, 150, 230), color2 = WHITE, rate = 14, size = 0.8, life = 1.6, speed = 1.4 },
		{ tex = "glow", pack = "glow_soft", color = rgb(200, 90, 255), rate = 2, size = 4.2, life = 1.6, speed = 0, alpha = 0.6 },
		{ tex = "sparks", color = rgb(255, 210, 90), rate = 6, size = 0.35, life = 1.2, speed = 2, accel = Vector3.new(0, 1.5, 0) },
	},
	Crystal = { -- ice shards and a frost ring
		{ tex = "sparkles", pack = "crystal_facets", color = rgb(200, 245, 255), color2 = rgb(120, 220, 255), rate = 14, size = 0.75, life = 1.6, speed = 1.5, rot = 160 },
		{ tex = "glow", pack = "frost_ring", color = rgb(140, 230, 255), rate = 1.5, size = 4.6, life = 1.8, speed = 0, alpha = 0.55, rot = 20 },
		{ tex = "sparks", color = WHITE, rate = 8, size = 0.3, life = 0.8, speed = 3 },
	},
	Cosmic = { -- a galaxy swirl with stars
		{ tex = "vortex", color = rgb(120, 80, 255), color2 = rgb(255, 120, 230), rate = 2.5, size = 5, life = 2, speed = 0, alpha = 0.45, rot = 120 },
		{ tex = "sparkles", pack = "glint_star4", color = WHITE, color2 = rgb(180, 200, 255), rate = 16, size = 0.6, life = 1.8, speed = 1.6 },
		{ tex = "smoke", color = rgb(70, 40, 170), color2 = rgb(200, 60, 200), rate = 6, size = 2.4, life = 2, speed = 0.6, emission = 0.4, alpha = 0.5 },
	},
	Champion = { -- golden flames, rays and confetti-like sparks
		{ tex = "fire", color = rgb(255, 200, 60), color2 = rgb(255, 110, 30), rate = 16, size = 1.8, life = 1, speed = 1.4, accel = Vector3.new(0, 3.5, 0), spread = 30, emission = 0.6, alpha = 0.35 },
		{ tex = "sparkles", pack = "glint_star4", color = rgb(255, 245, 190), rate = 14, size = 0.9, life = 1.6, speed = 1.6 },
		{ tex = "glow", pack = "glow_soft", color = rgb(255, 190, 60), rate = 2, size = 5, life = 1.6, speed = 0, alpha = 0.55 },
		{ tex = "sparks", color = rgb(255, 120, 60), rate = 10, size = 0.4, life = 1.4, speed = 3, accel = Vector3.new(0, 2, 0) },
	},
}

-- Accent light colour per set (Config also has set.accent; this keeps the module self-contained).
local LIGHT = {
	Marble = rgb(80, 230, 255), Jade = rgb(120, 255, 160), Ruby = rgb(255, 70, 90), Sapphire = rgb(90, 150, 255),
	Gold = rgb(255, 210, 80), Obsidian = rgb(160, 80, 255), Royal = rgb(255, 120, 230), Crystal = rgb(150, 235, 255),
	Cosmic = rgb(130, 90, 255), Champion = rgb(255, 190, 60),
}
ChessItems.Light = LIGHT

-- Adds the set's effect to an item model (from Build). k = size factor (1 = gallery).
-- Returns the attachment holding the emitters.
function ChessItems.AddFx(model: Model, setId: string, k: number?, withLight: boolean?): Attachment?
	local core = model.PrimaryPart
	local list = (ChessItems.Fx :: any)[setId]
	if not core or not list or #list == 0 then
		return nil
	end
	local f = k or 1
	local att = Instance.new("Attachment")
	att.Name = "ItemFx"
	att.Parent = core
	for i, e in list do
		emitter(att, "Fx" .. i, e, f)
	end
	if withLight ~= false and LIGHT[setId] then
		local l = Instance.new("PointLight")
		l.Name = "ItemLight"
		l.Color = LIGHT[setId]
		l.Range = 10 * f
		l.Brightness = 1.4
		l.Shadows = false
		l.Parent = core
	end
	return att
end

---------------------------------------------------------------------------
-- On the player (server): the item in the right hand and an aura on the body.
-- The aura grows with the tier: tiers 1-2 show only the item, 3-5 a light aura, 6+ a full aura.
---------------------------------------------------------------------------
local ORDER = { Wooden = 1, Marble = 2, Jade = 3, Ruby = 4, Sapphire = 5, Gold = 6, Obsidian = 7, Royal = 8, Crystal = 9, Cosmic = 10, Champion = 11 }

function ChessItems.Unwear(character: Model)
	local player = game:GetService("Players"):GetPlayerFromCharacter(character)
	local backpack = player and player:FindFirstChildOfClass("Backpack")
	local stray = backpack and backpack:FindFirstChild("ChessItem")
	if stray then
		stray:Destroy()
	end
	for _, name in { "ChessItem", "ChessAura" } do
		local old = character:FindFirstChild(name)
		while old do
			old:Destroy()
			old = character:FindFirstChild(name)
		end
	end
end

-- The held board is a Tool, so Roblox's own hold pose raises the right arm and the board is held up
-- in front (like the reference's phone) instead of hanging at the hip and clipping into the leg (Alex, Nov 8).
-- HOLD = where the board's centre sits, in the hand's frame while the arm is raised forward:
-- hand -Z is up and hand -Y points forward, so the board stands upright just above the fist,
-- its top leaning a little away, with its chess face toward the player (and camera) behind it.
local HOLD = CFrame.new(0, -0.35, -0.95) * CFrame.fromMatrix(Vector3.zero, Vector3.new(-1, 0, 0), Vector3.new(0, -0.26, -0.97), Vector3.new(0, -0.97, 0.26))
ChessItems.HOLD = HOLD

function ChessItems.Wear(character: Model, setId: string)
	ChessItems.Unwear(character)
	local hand = (character:FindFirstChild("RightHand") or character:FindFirstChild("Right Arm")) :: BasePart?
	local hrp = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not hand or not hrp or not humanoid then
		return
	end
	local tier = ORDER[setId] or 1
	-- the board, built around its centre part, which becomes the Tool's Handle
	local item = ChessItems.Build(setId, 0.42)
	local core = item.PrimaryPart :: BasePart
	local tool = Instance.new("Tool")
	tool.Name = "ChessItem"
	tool.CanBeDropped = false
	tool.ManualActivationOnly = true
	tool.RequiresHandle = true
	tool:SetAttribute("SetId", setId)
	core.Name = "Handle"
	for _, p in item:GetDescendants() do
		if p:IsA("BasePart") then
			p.Anchored = false
			p.Massless = true
			p.CanCollide = false
			p.CanTouch = false
			p.CanQuery = false
			if p ~= core then
				local w = Instance.new("WeldConstraint")
				w.Part0 = core
				w.Part1 = p
				w.Parent = p
			end
		end
	end
	for _, c in item:GetChildren() do
		c.Parent = tool
	end
	item:Destroy()
	-- Grip so that Handle = hand * gripAttachment * Grip:Inverse() = hand * HOLD
	local att = hand:FindFirstChild("RightGripAttachment") :: Attachment?
	local g = if att then att.CFrame else CFrame.new(0, -hand.Size.Y / 2, 0)
	tool.Grip = HOLD:Inverse() * g
	if tier >= 2 then
		ChessItems.AddFx({ PrimaryPart = core } :: any, setId, 0.32, false)
	end
	tool.Parent = character -- parented to the character = equipped (held)
	-- body aura (tier 3+): a flat ring part at the feet, the same effect rising around the body
	if tier >= 3 then
		local list = (ChessItems.Fx :: any)[setId]
		local ring = part(character, "ChessAura", Vector3.new(3.2, 0.2, 3.2), hrp.CFrame * CFrame.new(0, -2.6, 0), Color3.new(), nil, { Transparency = 1, Anchored = false, Massless = true })
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = hrp
		weld.Part1 = ring
		weld.Parent = ring
		local k = if tier >= 6 then 0.75 else 0.5
		for i, e in list do
			if i > (if tier >= 6 then 3 else 1) then
				break
			end
			local copy = table.clone(e)
			copy.rate = e.rate * (if tier >= 6 then 0.8 else 0.5)
			local p = emitter(ring, "Aura" .. i, copy, k) -- on the part: emits from its whole area
			p.Shape = Enum.ParticleEmitterShape.Box
			p.EmissionDirection = Enum.NormalId.Top
			p.SpreadAngle = Vector2.new(8, 8)
			p.Speed = NumberRange.new(1.5, 3)
		end
		if tier >= 6 then
			local l = Instance.new("PointLight")
			l.Name = "ChessAuraLight"
			l.Color = LIGHT[setId] or WHITE
			l.Range = 8
			l.Brightness = 1
			l.Parent = ring
		end
	end
	character:SetAttribute("ChessItem", setId)
end

return ChessItems
