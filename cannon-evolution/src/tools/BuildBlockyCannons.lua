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

	All 25 cannons in GameConfig (ONLY below). Each original model is
	moved to ServerStorage > CannonsOriginal before its new one goes in, never deleted.
	Undo: run with UNDO = true to put the originals back.
	Run BuildWorld1 and BuildCartoonyMap afterwards so the booths pick them up.
]]

local UNDO = false
local ONLY = {
	-- the 8 training-station cannons (the golden slice Alex liked, Oct 30)
	"Cannon01_Starter", "Cannon02_Iron", "Cannon03_Steel", "Cannon04_Heavy",
	"Cannon06_Industrial", "Cannon05_Golden", "Cannon19_Dragon", "Cannon09_Plasma",
	-- the shop cannons
	"Cannon07_Twin", "Cannon08_Rotary", "Cannon21_Toy", "Cannon22_Candy", "Cannon11_Frost",
	"Cannon12_Inferno", "Cannon13_Toxic", "Cannon23_Pumpkin", "Cannon24_Pirate", "Cannon14_Thunder",
	"Cannon10_Reactor", "Cannon25_Shark", "Cannon26_Robot", "Cannon15_Quantum", "Cannon27_Rainbow",
	"Cannon30_Galaxy", "Cannon31_Hacker",
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
	-- the shop cannons (Oct 30 roll-out); Fx grows with the tier: Rare faint, Epic a motif, Legendary and Secret the most
	Cannon07_Twin = { Body = rgb(70, 80, 100), Barrel = rgb(150, 160, 175), Ring = rgb(230, 80, 60), Wheel = rgb(40, 45, 55), Hub = rgb(230, 80, 60), Shape = "twin", Rivets = true, Fx = "faint" },
	Cannon08_Rotary = { Body = rgb(55, 60, 70), Barrel = rgb(120, 125, 135), Ring = rgb(250, 160, 40), Wheel = rgb(35, 35, 40), Hub = rgb(250, 160, 40), Wheels = 4, Shape = "rotary", Fx = "smoke" },
	Cannon21_Toy = { Body = rgb(60, 140, 235), Barrel = rgb(235, 60, 60), Ring = rgb(250, 200, 40), Wheel = rgb(80, 200, 90), Hub = rgb(250, 250, 250), Deco = "toy", Fx = "confetti" },
	Cannon22_Candy = { Body = rgb(255, 150, 200), Barrel = rgb(255, 250, 250), Ring = rgb(235, 60, 120), Wheel = rgb(150, 90, 60), Hub = rgb(255, 220, 240), Stripes = { rgb(235, 60, 120), rgb(255, 250, 250) }, Fx = "faint" },
	Cannon11_Frost = { Body = rgb(80, 150, 220), Barrel = rgb(200, 235, 255), Ring = rgb(120, 200, 255), Wheel = rgb(60, 100, 160), Hub = rgb(230, 250, 255), Deco = "crystals", Fx = "frost" },
	Cannon12_Inferno = { Body = rgb(60, 25, 20), Barrel = rgb(200, 50, 30), Ring = rgb(255, 150, 40), Wheel = rgb(40, 20, 15), Hub = rgb(255, 150, 40), Deco = "flames", Neon = true, Fx = "fire" },
	Cannon13_Toxic = { Body = rgb(40, 45, 55), Barrel = rgb(90, 200, 60), Ring = rgb(130, 255, 90), Wheel = rgb(30, 35, 40), Hub = rgb(130, 255, 90), Hazard = true, Fx = "bubbles" },
	Cannon23_Pumpkin = { Body = rgb(70, 40, 100), Barrel = rgb(245, 130, 30), Ring = rgb(200, 90, 20), Wheel = rgb(40, 25, 60), Hub = rgb(90, 170, 50), Deco = "pumpkin", Fx = "spooky" },
	Cannon24_Pirate = { Body = rgb(120, 70, 40), Barrel = rgb(40, 40, 45), Ring = rgb(220, 180, 60), Wheel = rgb(90, 55, 30), Hub = rgb(220, 180, 60), Wheels = 4, Deco = "flag", Fx = "pirate" },
	Cannon14_Thunder = { Body = rgb(40, 50, 110), Barrel = rgb(60, 80, 170), Ring = rgb(255, 225, 60), Wheel = rgb(30, 35, 80), Hub = rgb(255, 225, 60), Deco = "bolt", Neon = true, Fx = "thunder" },
	Cannon10_Reactor = { Body = rgb(45, 55, 65), Barrel = rgb(190, 200, 210), Ring = rgb(90, 230, 255), Wheel = rgb(35, 40, 50), Hub = rgb(90, 230, 255), Wheels = 4, Deco = "core", Neon = true, Fx = "reactor" },
	Cannon25_Shark = { Body = rgb(60, 110, 160), Barrel = rgb(140, 160, 180), Ring = rgb(240, 245, 250), Wheel = rgb(40, 70, 110), Hub = rgb(240, 245, 250), Deco = "fin", Fx = "ocean" },
	Cannon26_Robot = { Body = rgb(150, 160, 175), Barrel = rgb(190, 200, 210), Ring = rgb(60, 140, 235), Wheel = rgb(70, 75, 85), Hub = rgb(60, 140, 235), Wheels = 4, Deco = "robot", Rivets = true, Fx = "robot" },
	Cannon15_Quantum = { Body = rgb(30, 20, 60), Barrel = rgb(90, 50, 170), Ring = rgb(90, 230, 255), Wheel = rgb(25, 15, 50), Hub = rgb(200, 110, 255), Deco = "core", Neon = true, Fx = "quantum" },
	Cannon27_Rainbow = { Body = rgb(250, 250, 255), Barrel = rgb(255, 255, 255), Ring = rgb(255, 70, 70), Wheel = rgb(120, 90, 200), Hub = rgb(255, 240, 60), Stripes = { rgb(255, 70, 70), rgb(255, 170, 40), rgb(255, 240, 60), rgb(80, 220, 90), rgb(70, 150, 255), rgb(190, 90, 255) }, Fx = "rainbow" },
	Cannon30_Galaxy = { Body = rgb(25, 15, 55), Barrel = rgb(45, 30, 100), Ring = rgb(190, 120, 255), Wheel = rgb(20, 10, 45), Hub = rgb(255, 120, 220), Deco = "stars", Neon = true, Fx = "galaxy" },
	Cannon31_Hacker = { Body = rgb(20, 22, 26), Barrel = rgb(35, 40, 45), Ring = rgb(80, 255, 100), Wheel = rgb(15, 15, 18), Hub = rgb(80, 255, 100), Wheels = 4, Deco = "code", Neon = true, Fx = "hacker" },
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

	-- square barrel(s), tilted up, with chunky rings, a wide muzzle and a breech knob
	local L = s.Length or 5
	local d = s.Bore or 1.5
	local b = CFrame.new(0, 3.3, 0.2) * CFrame.Angles(math.rad(-14), 0, 0) -- +Z tilts up
	local function stripeCols(i)
		if s.Hazard then
			return i % 2 == 0 and rgb(250, 200, 40) or rgb(30, 30, 36)
		elseif s.Stripes then
			return s.Stripes[(i - 1) % #s.Stripes + 1]
		end
		return s.Ring
	end
	local function barrelAt(ox, oy, bd, rings)
		local o = b * CFrame.new(ox, oy, 0)
		P("Barrel", Vector3.new(bd, bd, L), o * CFrame.new(0, 0, 0.6), s.Barrel)
		for i, z in ipairs(rings) do
			P("Ring", Vector3.new(bd + 0.3, bd + 0.3, 0.45), o * CFrame.new(0, 0, z), stripeCols(i), { Neon = glowRing })
		end
		if s.Hazard or s.Stripes then
			for i = 0, 3 do
				P("Stripe", Vector3.new(bd + 0.06, bd + 0.06, 0.3), o * CFrame.new(0, 0, -0.5 + i * 0.6 + 0.3), stripeCols(i + 2))
			end
		end
		local mz = P("MuzzleRing", Vector3.new(bd + 0.6, bd + 0.6, 0.8), o * CFrame.new(0, 0, L / 2 + 0.6), s.Ring, { Neon = glowRing })
		local bo = P("Bore", Vector3.new(bd - 0.4, bd - 0.4, 0.1), o * CFrame.new(0, 0, L / 2 + 1.0), rgb(15, 15, 18))
		return mz, bo
	end
	local muzzle, bore
	if s.Shape == "twin" then
		-- two barrels side by side, tied with a band
		muzzle, bore = barrelAt(-0.7, 0, 1.1, { -1.3, 0.6, 2.2 })
		barrelAt(0.7, 0, 1.1, { -1.3, 0.6, 2.2 })
		P("Band", Vector3.new(2.9, 0.5, 0.5), b * CFrame.new(0, 0, 1.4), s.Ring, { Neon = glowRing })
	elseif s.Shape == "rotary" then
		-- six thin barrels round a hub, held by two square collars
		for i = 0, 5 do
			local a = i * math.pi / 3
			local mz, bo = barrelAt(math.cos(a) * 0.62, math.sin(a) * 0.62, 0.5, {})
			mz.Size = Vector3.new(0.75, 0.75, 0.5)
			bo.Size = Vector3.new(0.3, 0.3, 0.1)
			if i == 0 then
				muzzle, bore = mz, bo
			end
		end
		for _, z in ipairs({ -1.2, 1.7 }) do
			P("Collar", Vector3.new(2.1, 2.1, 0.4), b * CFrame.new(0, 0, z), s.Ring, { Neon = glowRing })
		end
		P("Hub", Vector3.new(0.6, 0.6, L + 0.6), b * CFrame.new(0, 0, 0.6), dark(s.Barrel, 0.3))
	else
		muzzle, bore = barrelAt(0, 0, d, { -1.3, 0.6, 2.2 })
	end
	P("Breech", Vector3.new(d + 0.2, d + 0.2, 0.8), b * CFrame.new(0, 0, -L / 2 + 0.3), dark(s.Barrel, 0.15))
	P("Knob", Vector3.new(0.7, 0.7, 0.7), b * CFrame.new(0, 0, -L / 2 - 0.4), s.Ring)
	local function wedge(name, size, cf, color, neon)
		local w = Instance.new("WedgePart")
		w.Name = name
		w.Size = size
		w.CFrame = cf
		w.Color = color
		w.Material = neon and Enum.Material.Neon or Enum.Material.SmoothPlastic
		w.Anchored = true
		w.CanCollide = false
		w.Parent = m
		return w
	end
	local top = d / 2
	if s.Spikes then
		for i, z in ipairs({ -1, 0.2, 1.4 }) do
			wedge("Spike", Vector3.new(0.3, 0.8 - i * 0.1, 0.8), b * CFrame.new(0, top + 0.4 - i * 0.05, z), s.Ring, true)
		end
		for _, x in ipairs({ -1, 1 }) do
			P("Horn", Vector3.new(0.3, 1, 0.3), b * CFrame.new(x * 0.6, top + 0.4, -L / 2 + 0.2) * CFrame.Angles(math.rad(-30), 0, x * math.rad(-20)), rgb(245, 235, 210))
		end
	end
	-- the extra details that make each cannon its own
	local deco = s.Deco
	if deco == "fin" then
		wedge("Fin", Vector3.new(0.3, 1.4, 1.6), b * CFrame.new(0, top + 0.7, -0.4), s.Barrel)
		for _, x in ipairs({ -0.45, -0.15, 0.15, 0.45 }) do
			wedge("Tooth", Vector3.new(0.2, 0.3, 0.2), b * CFrame.new(x, top + 0.15, L / 2 + 1.05) * CFrame.Angles(math.pi, 0, 0), rgb(250, 250, 250))
		end
		for _, x in ipairs({ -1, 1 }) do
			P("Eye", Vector3.new(0.08, 0.3, 0.3), b * CFrame.new(x * (top + 0.04), 0.3, L / 2 - 0.3), rgb(20, 20, 25))
		end
	elseif deco == "robot" then
		for _, x in ipairs({ -1, 1 }) do
			P("Eye", Vector3.new(0.1, 0.35, 0.35), b * CFrame.new(x * (top + 0.05), 0.25, L / 2 - 0.4), rgb(80, 220, 255), { Neon = true })
		end
		P("Antenna", Vector3.new(0.12, 1.2, 0.12), b * CFrame.new(0, top + 0.6, -1.2), rgb(180, 185, 195))
		P("AntennaTip", Vector3.new(0.35, 0.35, 0.35), b * CFrame.new(0, top + 1.25, -1.2), rgb(255, 70, 70), { Neon = true })
	elseif deco == "pumpkin" then
		P("Stem", Vector3.new(0.35, 0.6, 0.35), b * CFrame.new(0, top + 0.3, -L / 2 + 0.6), rgb(70, 130, 40))
		P("Leaf", Vector3.new(0.6, 0.1, 0.4), b * CFrame.new(0.35, top + 0.1, -L / 2 + 0.6), rgb(90, 170, 50))
		for _, x in ipairs({ -1, 1 }) do
			wedge("Eye", Vector3.new(0.06, 0.35, 0.4), b * CFrame.new(x * (top + 0.03), 0.2, L / 2 - 0.5), rgb(255, 200, 60), true)
		end
	elseif deco == "flag" then
		P("Pole", Vector3.new(0.15, 3, 0.15), CFrame.new(0, 3.2, -2.9), rgb(110, 70, 40))
		P("Flag", Vector3.new(0.08, 1, 1.4), CFrame.new(0, 4.2, -2.2), rgb(25, 25, 30))
		P("Skull", Vector3.new(0.1, 0.4, 0.4), CFrame.new(0, 4.25, -2.1), rgb(245, 245, 245))
	elseif deco == "crystals" then
		for i, c in ipairs({ { -1.1, 2.6, -1.2 }, { 1.1, 2.6, -0.6 }, { 0, top + 0.4, -0.6 } }) do
			local w = wedge("Crystal", Vector3.new(0.4, 1 + i * 0.15, 0.6), i == 3 and b * CFrame.new(0, c[2], c[3]) or CFrame.new(c[1], c[2] + 0.6, c[3]), rgb(170, 230, 255))
			w.Material = Enum.Material.Glass
			w.Transparency = 0.25
		end
	elseif deco == "flames" then
		for _, x in ipairs({ -1, 1 }) do
			for i, z in ipairs({ -1.2, -0.4, 0.4 }) do
				wedge("Flame", Vector3.new(0.12, 0.6 + (i % 2) * 0.3, 0.5), CFrame.new(x * 1.33, 2.4 + (i % 2) * 0.15, z) * CFrame.Angles(0, math.pi, 0), i == 2 and rgb(255, 220, 60) or rgb(255, 120, 30), true)
			end
		end
	elseif deco == "stars" then
		for i, c in ipairs({ { 0.3, -1.6 }, { -0.4, -0.4 }, { 0.2, 0.8 }, { -0.3, 1.8 } }) do
			P("Star", Vector3.new(0.2, 0.2, 0.2), b * CFrame.new(c[1], top + 0.08, c[2]) * CFrame.Angles(0, math.rad(45), 0), rgb(255, 255, 255), { Neon = true })
		end
	elseif deco == "bolt" then
		for _, x in ipairs({ -1, 1 }) do
			for i, z in ipairs({ -1, -0.4, 0.2 }) do
				P("Bolt", Vector3.new(0.06, 0.18, 0.7), b * CFrame.new(x * (top + 0.03), (i % 2 == 0) and 0.15 or -0.15, z) * CFrame.Angles(math.rad(i % 2 == 0 and 35 or -35), 0, 0), rgb(255, 230, 60), { Neon = true })
			end
		end
	elseif deco == "code" then
		for _, x in ipairs({ -1, 1 }) do
			for i = 0, 3 do
				P("Code", Vector3.new(0.05, 0.1, 0.3 + (i % 3) * 0.25), b * CFrame.new(x * (top + 0.03), 0.4 - i * 0.25, -0.6 + (i % 2) * 0.4), rgb(80, 255, 100), { Neon = true })
			end
		end
	elseif deco == "core" then
		for _, x in ipairs({ -1, 1 }) do
			P("CoreWindow", Vector3.new(0.1, 0.6, 1.2), CFrame.new(x * 1.3, 2.6, -0.4), s.Ring, { Neon = true })
		end
	elseif deco == "toy" then
		for i, c in ipairs({ rgb(235, 60, 60), rgb(60, 140, 235), rgb(80, 200, 90) }) do
			P("Block", Vector3.new(0.5, 0.5, 0.5), CFrame.new(-0.8 + (i - 1) * 0.8, 2.3, -2.4), c)
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
		e.Color = o.Seq or ColorSequence.new(o.Color)
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
	elseif s.Fx == "faint" then
		-- Rare: one or two faint motes in the accent colour
		emit(body, { Texture = SMOKE, Color = s.Ring, Size = 0.3, Rate = 1.5, Life = 1.5, Speed = 0.3, Alpha = 0.3 })
	elseif s.Fx == "confetti" then
		emit(body, { Texture = SPARK, Seq = ColorSequence.new({ ColorSequenceKeypoint.new(0, rgb(235, 60, 60)), ColorSequenceKeypoint.new(0.5, rgb(60, 140, 235)), ColorSequenceKeypoint.new(1, rgb(250, 200, 40)) }), Size = 0.3, Rate = 2, Life = 1.2, Speed = 0.6 })
	elseif s.Fx == "frost" then
		emit(muzzle, { Texture = SMOKE, Color = rgb(210, 240, 255), Size = 0.6, EndSize = 1.2, Alpha = 0.4, Rate = 3, Life = 1.5, Speed = 0.4, Accel = Vector3.new(0, -1, 0), Drag = 1 })
		emit(body, { Texture = SPARK, Color = rgb(200, 235, 255), Size = 0.35, Rate = 2, Life = 1, Speed = 0.3 })
	elseif s.Fx == "fire" then
		emit(bore, { Texture = FIRE, Color = rgb(255, 130, 40), Size = 0.7, EndSize = 0.2, Rate = 5, Life = 0.6, Speed = 1.5, Spread = 15, Dir = out, Accel = Vector3.new(0, 3, 0) })
		emit(body, { Texture = FIRE, Color = rgb(255, 180, 60), Size = 0.2, Rate = 3, Life = 1, Speed = 1, Accel = Vector3.new(0, 4, 0) })
	elseif s.Fx == "bubbles" then
		emit(bore, { Texture = SMOKE, Color = rgb(130, 255, 90), Size = 0.4, Rate = 4, Life = 1.4, Speed = 0.8, Spread = 30, Dir = out, Accel = Vector3.new(0, 2, 0), Alpha = 0.2 })
		emit(muzzle, { Texture = SMOKE, Color = rgb(90, 220, 60), Size = 0.25, Rate = 2, Life = 0.8, Speed = 0, Accel = Vector3.new(0, -6, 0), Alpha = 0.2 })
	elseif s.Fx == "spooky" then
		emit(bore, { Texture = FIRE, Color = rgb(255, 150, 40), Size = 0.35, Rate = 3, Life = 1, Speed = 1, Spread = 20, Dir = out, Accel = Vector3.new(0, 3, 0) })
		emit(body, { Texture = SMOKE, Color = rgb(140, 70, 200), Size = 0.7, EndSize = 1.4, Alpha = 0.55, Rate = 2, Life = 1.8, Speed = 0.3 })
	elseif s.Fx == "pirate" then
		emit(bore, { Texture = SMOKE, Color = rgb(110, 110, 115), Light = 0, Size = 0.6, EndSize = 1.5, Alpha = 0.45, Rate = 3, Life = 1.6, Speed = 1.2, Spread = 15, Dir = out, Accel = Vector3.new(0, 1.5, 0), Drag = 1 })
		emit(body, { Texture = SPARK, Color = rgb(255, 215, 80), Size = 0.35, Rate = 2, Life = 1.2, Speed = 0.4 })
	elseif s.Fx == "thunder" then
		emit(muzzle, { Texture = SPARK, Color = rgb(255, 240, 120), Size = 0.6, Rate = 5, Life = 0.25, Speed = 3, Spread = 180 })
		emit(body, { Texture = SPARK, Color = rgb(120, 200, 255), Size = 0.4, Rate = 4, Life = 0.4, Speed = 2 })
		light(muzzle, rgb(255, 240, 150), 1.2)
	elseif s.Fx == "reactor" or s.Fx == "quantum" then
		local c1 = s.Fx == "reactor" and rgb(90, 230, 255) or rgb(200, 110, 255)
		bore.Material = Enum.Material.Neon
		bore.Color = c1
		local pull = emit(muzzle, { Texture = SMOKE, Color = c1, Size = 0.5, Rate = 5, Life = 0.7, Speed = 2, Alpha = 0.2 })
		pcall(function()
			pull.Shape = Enum.ParticleEmitterShape.Sphere
			pull.ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface
			pull.ShapeInOut = Enum.ParticleEmitterShapeInOut.Inward
		end)
		emit(body, { Texture = SPARK, Color = s.Fx == "quantum" and rgb(90, 230, 255) or c1, Size = 0.4, Rate = 5, Life = 1.2, Speed = 0.6 })
		light(muzzle, c1, 1.5)
	elseif s.Fx == "ocean" then
		emit(bore, { Texture = SMOKE, Color = rgb(170, 230, 255), Size = 0.3, Rate = 5, Life = 1.5, Speed = 1, Spread = 25, Dir = out, Accel = Vector3.new(0, 2.5, 0), Alpha = 0.2 })
		emit(muzzle, { Texture = SPARK, Color = rgb(220, 245, 255), Size = 0.6, Rate = 1.5, Life = 0.5, Speed = 0, Locked = true })
		light(muzzle, rgb(120, 200, 255), 1)
	elseif s.Fx == "robot" then
		emit(body, { Texture = SPARK, Color = rgb(255, 200, 80), Size = 0.3, Rate = 4, Life = 0.4, Speed = 3, Accel = Vector3.new(0, -8, 0) })
		emit(muzzle, { Texture = SPARK, Color = rgb(120, 220, 255), Size = 0.6, Rate = 1.5, Life = 0.5, Speed = 0, Locked = true })
		light(muzzle, rgb(120, 220, 255), 1.2)
	elseif s.Fx == "rainbow" then
		local seq = ColorSequence.new({
			ColorSequenceKeypoint.new(0, rgb(255, 70, 70)), ColorSequenceKeypoint.new(0.2, rgb(255, 170, 40)),
			ColorSequenceKeypoint.new(0.4, rgb(255, 240, 60)), ColorSequenceKeypoint.new(0.6, rgb(80, 220, 90)),
			ColorSequenceKeypoint.new(0.8, rgb(70, 150, 255)), ColorSequenceKeypoint.new(1, rgb(190, 90, 255)),
		})
		emit(body, { Texture = SPARK, Seq = seq, Size = 0.45, Rate = 6, Life = 1.4, Speed = 0.8 })
		emit(bore, { Texture = SMOKE, Seq = seq, Size = 0.5, EndSize = 1, Alpha = 0.3, Rate = 4, Life = 1, Speed = 1.5, Spread = 15, Dir = out })
		light(muzzle, rgb(255, 255, 255), 1.2)
	elseif s.Fx == "galaxy" then
		emit(body, { Texture = SPARK, Color = rgb(255, 255, 255), Size = 0.3, Rate = 6, Life = 1.6, Speed = 0.4 })
		emit(bore, { Texture = SMOKE, Seq = ColorSequence.new(rgb(120, 70, 255), rgb(255, 90, 200)), Size = 0.6, EndSize = 1.3, Alpha = 0.35, Rate = 4, Life = 1.4, Speed = 1.2, Spread = 15, Dir = out })
		light(muzzle, rgb(170, 110, 255), 1.5)
	elseif s.Fx == "hacker" then
		bore.Material = Enum.Material.Neon
		bore.Color = rgb(80, 255, 100)
		emit(body, { Texture = SPARK, Color = rgb(80, 255, 100), Size = 0.35, Rate = 6, Life = 1.4, Speed = 1.2, Spread = 10, Accel = Vector3.new(0, 1, 0) })
		emit(bore, { Texture = SMOKE, Color = rgb(60, 200, 80), Size = 0.5, EndSize = 1.1, Alpha = 0.4, Rate = 4, Life = 1, Speed = 1.5, Spread = 15, Dir = out })
		light(muzzle, rgb(80, 255, 100), 1.5)
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
