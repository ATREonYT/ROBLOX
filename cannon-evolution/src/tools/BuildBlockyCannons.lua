--[[
	BuildBlockyCannons  (run in Studio's Command Bar, Edit mode)

	Blocky, studded cannons built from parts, to match the studded booths (Alex, Oct 30:
	"make better cannons", "make it blocky"). Each cannon has a square barrel with chunky
	rings, a carriage with stepped cheeks, octagon wheels made of two squares, and its own
	colours and extras (rivets, gems, spikes, neon rings), and effects that grow with the
	tier: Steel glints, Heavy smoke, Industrial sparks, Golden gold sparkles, Dragon embers,
	Plasma energy pulled into the muzzle. Alex picked this first version over a more
	detailed one (Oct 30): keep the shapes simple, add effects.

	The barrel points along +Z, like the imported cannons, so the booths and the
	player's cannon place them the same way. The muzzle hole is named "Bore".

	Golden slice: only the 8 training-station cannons (ONLY below). Each original model is
	moved to ServerStorage > CannonsOriginal before its new one goes in, never deleted.
	Undo: run with UNDO = true to put the originals back.
	Run BuildWorld1 and BuildCartoonyMap afterwards so the booths pick them up.
]]

local UNDO = false
local ONLY = {
	"Cannon01_Starter", "Cannon02_Iron", "Cannon03_Steel", "Cannon04_Heavy",
	"Cannon06_Industrial", "Cannon05_Golden", "Cannon19_Dragon", "Cannon09_Plasma",
}

local function rgb(r, g, b)
	return Color3.fromRGB(r, g, b)
end
-- Body: carriage, Barrel, Ring: barrel rings and trim, Wheel, Hub, Neon: glowing rings
local STYLES = {
	Cannon01_Starter = { Body = rgb(150, 95, 55), Barrel = rgb(95, 100, 112), Ring = rgb(240, 190, 50), Wheel = rgb(110, 70, 40), Hub = rgb(240, 190, 50) },
	Cannon02_Iron = { Body = rgb(75, 75, 88), Barrel = rgb(55, 58, 68), Ring = rgb(160, 160, 172), Wheel = rgb(40, 40, 46), Hub = rgb(160, 160, 172), Rivets = true },
	Cannon03_Steel = { Body = rgb(55, 95, 160), Barrel = rgb(190, 200, 215), Ring = rgb(80, 150, 230), Wheel = rgb(45, 60, 85), Hub = rgb(225, 235, 245), Rivets = true, Fx = "glint" },
	Cannon04_Heavy = { Body = rgb(45, 45, 55), Barrel = rgb(32, 32, 38), Ring = rgb(250, 195, 40), Wheel = rgb(35, 35, 40), Hub = rgb(250, 195, 40), Wheels = 4, Bore = 1.8, Fx = "smoke" },
	Cannon06_Industrial = { Body = rgb(60, 60, 72), Barrel = rgb(250, 200, 40), Ring = rgb(30, 30, 36), Wheel = rgb(35, 35, 40), Hub = rgb(250, 200, 40), Wheels = 4, Hazard = true, Rivets = true, Fx = "sparks" },
	Cannon05_Golden = { Body = rgb(160, 30, 40), Barrel = rgb(255, 200, 45), Ring = rgb(255, 240, 185), Wheel = rgb(120, 25, 30), Hub = rgb(255, 200, 45), Gems = true, Fx = "gold" },
	Cannon19_Dragon = { Body = rgb(60, 25, 120), Barrel = rgb(120, 50, 200), Ring = rgb(255, 80, 220), Wheel = rgb(40, 20, 80), Hub = rgb(255, 80, 220), Neon = true, Spikes = true, Fx = "dragon" },
	Cannon09_Plasma = { Body = rgb(28, 38, 50), Barrel = rgb(45, 60, 78), Ring = rgb(110, 255, 90), Wheel = rgb(25, 30, 40), Hub = rgb(110, 255, 90), Neon = true, Wheels = 4, Fx = "plasma" },
}

local RS = game.ReplicatedStorage
local SS = game:GetService("ServerStorage")
local folder = RS:FindFirstChild("Cannons")
local backup = SS:FindFirstChild("CannonsOriginal") or Instance.new("Folder")
backup.Name = "CannonsOriginal"
backup.Parent = SS

local function make(name, s)
	local m = Instance.new("Model")
	m.Name = name
	m:SetAttribute("Blocky", true)
	local function P(pname, size, cf, color, opts)
		local p = Instance.new("Part")
		p.Name = pname
		p.Size = size
		p.CFrame = cf
		p.Color = color
		p.Material = opts and opts.Neon and Enum.Material.Neon or Enum.Material.SmoothPlastic
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		p.Anchored = true
		p.CanCollide = false
		if opts and opts.Shape then
			p.Shape = opts.Shape
		end
		p.Parent = m
		return p
	end
	local function dark(c, a)
		return c:Lerp(Color3.new(0, 0, 0), a or 0.25)
	end
	local glowRing = s.Neon

	-- carriage
	local body = P("Body", Vector3.new(2.6, 1, 3.8), CFrame.new(0, 1.5, -0.3), s.Body)
	P("BodyTrim", Vector3.new(2.8, 0.3, 4), CFrame.new(0, 2.05, -0.3), dark(s.Body, 0.3))
	-- stepped trail down to the ground behind
	P("Trail", Vector3.new(1.8, 0.8, 1.2), CFrame.new(0, 1.2, -2.7), s.Body)
	P("Trail", Vector3.new(1.4, 0.6, 1.1), CFrame.new(0, 0.6, -3.5), dark(s.Body, 0.2))
	for _, x in ipairs({ -1, 1 }) do
		-- stepped cheeks holding the barrel
		P("Cheek", Vector3.new(0.45, 1.3, 2.6), CFrame.new(x * 1.05, 2.8, 0), s.Body)
		P("Cheek", Vector3.new(0.45, 0.6, 1.4), CFrame.new(x * 1.05, 3.75, 0.2), s.Body)
		P("Trunnion", Vector3.new(0.3, 0.6, 0.6), CFrame.new(x * 1.35, 3.3, 0.2), s.Ring)
		if s.Rivets then
			for _, z in ipairs({ -0.9, 0, 0.9 }) do
				P("Rivet", Vector3.new(0.12, 0.25, 0.25), CFrame.new(x * 1.33, 2.4, z), dark(s.Ring, 0.1))
			end
		end
		if s.Gems then
			P("Gem", Vector3.new(0.12, 0.5, 0.5), CFrame.new(x * 1.33, 2.6, -0.4) * CFrame.Angles(math.rad(45), 0, 0), x < 0 and rgb(60, 140, 255) or rgb(235, 50, 60), { Neon = true })
		end
	end

	-- octagon wheels: two squares turned 45 degrees, with a hub
	local axles = (s.Wheels == 4) and { 0.9, -1.6 } or { 0.6 }
	for _, z in ipairs(axles) do
		P("Axle", Vector3.new(3.4, 0.35, 0.35), CFrame.new(0, 1.1, z), dark(s.Wheel, 0.2))
		for _, x in ipairs({ -1, 1 }) do
			local c = CFrame.new(x * 1.6, 1.1, z)
			P("Wheel", Vector3.new(0.6, 1.6, 1.6), c, s.Wheel)
			P("Wheel", Vector3.new(0.6, 1.6, 1.6), c * CFrame.Angles(math.rad(45), 0, 0), s.Wheel)
			P("Rim", Vector3.new(0.66, 1.1, 1.1), c * CFrame.Angles(math.rad(22.5), 0, 0), dark(s.Wheel, 0.35))
			P("Hub", Vector3.new(0.75, 0.55, 0.55), c, s.Hub, { Neon = glowRing })
		end
	end

	-- square barrel, tilted up, with chunky rings, a wide muzzle and a breech knob
	local L = 5
	local d = s.Bore or 1.5
	local b = CFrame.new(0, 3.3, 0.2) * CFrame.Angles(math.rad(-14), 0, 0) -- +Z tilts up
	P("Barrel", Vector3.new(d, d, L), b * CFrame.new(0, 0, 0.6), s.Barrel)
	local rings = { -1.3, 0.6, 2.2 }
	for i, z in ipairs(rings) do
		local col = s.Ring
		if s.Hazard then
			col = i % 2 == 0 and rgb(250, 200, 40) or rgb(30, 30, 36)
		end
		P("Ring", Vector3.new(d + 0.3, d + 0.3, 0.45), b * CFrame.new(0, 0, z), col, { Neon = glowRing })
	end
	if s.Hazard then
		for i = 0, 3 do
			P("Stripe", Vector3.new(d + 0.06, d + 0.06, 0.3), b * CFrame.new(0, 0, -0.5 + i * 0.6 + 0.3), rgb(30, 30, 36))
		end
	end
	local muzzle = P("MuzzleRing", Vector3.new(d + 0.6, d + 0.6, 0.8), b * CFrame.new(0, 0, L / 2 + 0.6), s.Ring, { Neon = glowRing })
	local bore = P("Bore", Vector3.new(d - 0.4, d - 0.4, 0.1), b * CFrame.new(0, 0, L / 2 + 1.0), rgb(15, 15, 18))
	P("Breech", Vector3.new(d + 0.2, d + 0.2, 0.8), b * CFrame.new(0, 0, -L / 2 + 0.3), dark(s.Barrel, 0.15))
	P("Knob", Vector3.new(0.7, 0.7, 0.7), b * CFrame.new(0, 0, -L / 2 - 0.4), s.Ring)
	if s.Spikes then
		for i, z in ipairs({ -1, 0.2, 1.4 }) do
			local w = Instance.new("WedgePart")
			w.Name = "Spike"
			w.Size = Vector3.new(0.3, 0.8 - i * 0.1, 0.8)
			w.CFrame = b * CFrame.new(0, d / 2 + 0.4 - i * 0.05, z)
			w.Color = s.Ring
			w.Material = Enum.Material.Neon
			w.Anchored = true
			w.CanCollide = false
			w.Parent = m
		end
		for _, x in ipairs({ -1, 1 }) do
			local horn = P("Horn", Vector3.new(0.3, 1, 0.3), b * CFrame.new(x * 0.6, d / 2 + 0.4, -L / 2 + 0.2) * CFrame.Angles(math.rad(-30), 0, x * math.rad(-20)), rgb(245, 235, 210))
			horn.Name = "Horn"
		end
	end
	-- effects, more as the tiers go up (VFX-ITEMS.md ladder): Starter and Iron plain,
	-- Steel a glint, Heavy smoke, Industrial sparks, Golden gold sparkles, Dragon embers,
	-- Plasma energy pulled into the muzzle. Built-in pictures only, under 16 particles a second.
	local SPARK = "rbxasset://textures/particles/sparkles_main.dds"
	local FIRE = "rbxasset://textures/particles/fire_main.dds"
	local SMOKE = "rbxasset://textures/particles/smoke_main.dds"
	local function emit(parent, o)
		local e = Instance.new("ParticleEmitter")
		e.Name = o.Name or "Fx"
		e.Texture = o.Texture
		e.Color = ColorSequence.new(o.Color)
		e.LightEmission = o.Light or 1
		e.LightInfluence = o.Light == 0 and 1 or 0
		e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, o.Size), NumberSequenceKeypoint.new(1, o.EndSize or 0) })
		e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, o.Alpha or 0.1), NumberSequenceKeypoint.new(1, 1) })
		e.Lifetime = NumberRange.new(o.Life or 1, (o.Life or 1) * 1.5)
		e.Rate = o.Rate
		e.Speed = NumberRange.new(o.Speed or 0.5, (o.Speed or 0.5) * 2)
		e.SpreadAngle = Vector2.new(o.Spread or 180, o.Spread or 180)
		e.Acceleration = o.Accel or Vector3.zero
		e.EmissionDirection = o.Dir or Enum.NormalId.Top
		e.LockedToPart = o.Locked == true
		e.Drag = o.Drag or 0
		e.Parent = parent
		return e
	end
	local function light(parent, color, brightness)
		local l = Instance.new("PointLight")
		l.Color = color
		l.Brightness = brightness or 1
		l.Range = 7
		l.Parent = parent
	end
	local out = Enum.NormalId.Back -- the muzzle's open end faces the part's Back
	if s.Fx == "glint" then
		emit(muzzle, { Texture = SPARK, Color = rgb(200, 230, 255), Size = 0.6, Rate = 1.5, Life = 0.6, Speed = 0, Locked = true })
	elseif s.Fx == "smoke" then
		emit(bore, { Texture = SMOKE, Color = rgb(95, 95, 100), Light = 0, Size = 0.6, EndSize = 1.6, Alpha = 0.45, Rate = 3, Life = 1.6, Speed = 1.2, Spread = 15, Dir = out, Accel = Vector3.new(0, 1.5, 0), Drag = 1 })
	elseif s.Fx == "sparks" then
		emit(bore, { Texture = FIRE, Color = rgb(255, 160, 40), Size = 0.25, Rate = 4, Life = 0.6, Speed = 3, Spread = 35, Dir = out, Accel = Vector3.new(0, -8, 0) })
		emit(bore, { Texture = SMOKE, Color = rgb(140, 140, 145), Light = 0, Size = 0.5, EndSize = 1.2, Alpha = 0.6, Rate = 2, Life = 1.4, Speed = 1, Spread = 15, Dir = out, Accel = Vector3.new(0, 1.5, 0), Drag = 1 })
	elseif s.Fx == "gold" then
		emit(body, { Texture = SPARK, Color = rgb(255, 215, 80), Size = 0.4, Rate = 5, Life = 1.2, Speed = 0.6 })
		emit(muzzle, { Texture = SPARK, Color = rgb(255, 245, 200), Size = 0.9, Rate = 1.5, Life = 0.5, Speed = 0, Locked = true })
		emit(bore, { Texture = SMOKE, Color = rgb(255, 210, 90), Size = 0.5, EndSize = 0.9, Alpha = 0.5, Rate = 2, Life = 1, Speed = 0.8, Spread = 20, Dir = out })
		light(muzzle, rgb(255, 215, 120), 1)
	elseif s.Fx == "dragon" then
		emit(bore, { Texture = FIRE, Color = rgb(255, 110, 200), Size = 0.45, Rate = 5, Life = 0.9, Speed = 1.5, Spread = 20, Dir = out, Accel = Vector3.new(0, 3, 0) })
		emit(bore, { Texture = SMOKE, Color = rgb(150, 60, 200), Size = 0.6, EndSize = 1.4, Alpha = 0.5, Rate = 2, Life = 1.4, Speed = 1, Spread = 15, Dir = out, Accel = Vector3.new(0, 1.5, 0), Drag = 1 })
		emit(body, { Texture = SPARK, Color = rgb(255, 140, 240), Size = 0.4, Rate = 3, Life = 1.2, Speed = 0.6 })
		light(muzzle, s.Ring, 1.5)
	elseif s.Fx == "plasma" then
		-- green energy drawn into the muzzle, sparkles round the cannon, a glowing bore
		bore.Material = Enum.Material.Neon
		bore.Color = s.Ring
		local pull = emit(muzzle, { Texture = SMOKE, Color = rgb(140, 255, 120), Size = 0.5, Rate = 5, Life = 0.7, Speed = 2, Alpha = 0.2 })
		pcall(function()
			pull.Shape = Enum.ParticleEmitterShape.Sphere
			pull.ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface
			pull.ShapeInOut = Enum.ParticleEmitterShapeInOut.Inward
		end)
		emit(body, { Texture = SPARK, Color = rgb(140, 255, 120), Size = 0.4, Rate = 4, Life = 1.2, Speed = 0.6 })
		light(muzzle, s.Ring, 1.5)
	end
	m.PrimaryPart = body
	return m
end

local n = 0
for _, name in ipairs(ONLY) do
	local cur = folder:FindFirstChild(name)
	local orig = backup:FindFirstChild(name)
	if UNDO then
		if orig then
			if cur then
				cur:Destroy()
			end
			orig.Parent = folder
			n += 1
		end
	elseif STYLES[name] then
		if cur and not orig and not cur:GetAttribute("Blocky") then
			cur.Parent = backup -- keep Alex's original
		elseif cur then
			cur:Destroy()
		end
		make(name, STYLES[name]).Parent = folder
		n += 1
	end
end
print("[BuildBlockyCannons] " .. (UNDO and "restored " or "built ") .. n .. " cannons")
