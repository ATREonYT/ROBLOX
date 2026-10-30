--[[
	BuildBlockyCannons  (run in Studio's Command Bar, Edit mode)

	Blocky, studded cannons built from parts, to match the studded booths (Alex, Oct 30:
	"make better cannons", "make it blocky"). Each cannon has a square barrel with chunky
	rings, a carriage with stepped cheeks, octagon wheels made of two squares, and its own
	colours and extras: wood planks (Starter), rivets (Iron), vents (Steel), thick bands
	(Heavy), hazard stripes, pipe and beacon (Industrial), gems and a crown (Golden), teeth,
	eyes, horns, spikes and wings (Dragon), glowing core slots and fins (Plasma). Barrels get
	blocky shading strips, bolted rings, a stepped muzzle and breech.

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
	Cannon01_Starter = { Body = rgb(150, 95, 55), Barrel = rgb(95, 100, 112), Ring = rgb(240, 190, 50), Wheel = rgb(110, 70, 40), Hub = rgb(240, 190, 50), Kind = "wood" },
	Cannon02_Iron = { Body = rgb(75, 75, 88), Barrel = rgb(55, 58, 68), Ring = rgb(160, 160, 172), Wheel = rgb(40, 40, 46), Hub = rgb(160, 160, 172), Rivets = true },
	Cannon03_Steel = { Body = rgb(55, 95, 160), Barrel = rgb(190, 200, 215), Ring = rgb(80, 150, 230), Wheel = rgb(45, 60, 85), Hub = rgb(225, 235, 245), Rivets = true, Kind = "vents" },
	Cannon04_Heavy = { Body = rgb(45, 45, 55), Barrel = rgb(32, 32, 38), Ring = rgb(250, 195, 40), Wheel = rgb(35, 35, 40), Hub = rgb(250, 195, 40), Wheels = 4, Bore = 1.85, Kind = "heavy" },
	Cannon06_Industrial = { Body = rgb(60, 60, 72), Barrel = rgb(250, 200, 40), Ring = rgb(30, 30, 36), Wheel = rgb(35, 35, 40), Hub = rgb(250, 200, 40), Wheels = 4, Kind = "hazard", Rivets = true },
	Cannon05_Golden = { Body = rgb(160, 30, 40), Barrel = rgb(255, 200, 45), Ring = rgb(255, 240, 185), Wheel = rgb(120, 25, 30), Hub = rgb(255, 200, 45), Gems = true, Crown = true, Sparkle = rgb(255, 215, 80) },
	Cannon19_Dragon = { Body = rgb(60, 25, 120), Barrel = rgb(120, 50, 200), Ring = rgb(255, 80, 220), Wheel = rgb(40, 20, 80), Hub = rgb(255, 80, 220), Neon = true, Spikes = true, Kind = "dragon", Sparkle = rgb(255, 120, 235) },
	Cannon09_Plasma = { Body = rgb(28, 38, 50), Barrel = rgb(45, 60, 78), Ring = rgb(110, 255, 90), Wheel = rgb(25, 30, 40), Hub = rgb(110, 255, 90), Wheels = 4, Kind = "tech", Sparkle = rgb(140, 255, 120) },
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
	local function dark(c, a)
		return c:Lerp(Color3.new(0, 0, 0), a or 0.25)
	end
	local function light(c, a)
		return c:Lerp(Color3.new(1, 1, 1), a or 0.25)
	end
	local function P(pname, size, cf, color, neon)
		local p = Instance.new("Part")
		p.Name = pname
		p.Size = size
		p.CFrame = cf
		p.Color = color
		p.Material = neon and Enum.Material.Neon or Enum.Material.SmoothPlastic
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		p.Anchored = true
		p.CanCollide = false
		p.CastShadow = not neon
		p.Parent = m
		return p
	end
	local function W(pname, size, cf, color, neon)
		local w = Instance.new("WedgePart")
		w.Name = pname
		w.Size = size
		w.CFrame = cf
		w.Color = color
		w.Material = neon and Enum.Material.Neon or Enum.Material.SmoothPlastic
		w.Anchored = true
		w.CanCollide = false
		w.Parent = m
		return w
	end
	local glow = s.Neon

	---------------------------------------------------------------- carriage
	-- base plate, body block and a trim line
	local body = P("Body", Vector3.new(2.4, 1, 3.6), CFrame.new(0, 1.55, -0.3), s.Body)
	P("BodyTop", Vector3.new(2.6, 0.25, 3.8), CFrame.new(0, 2.15, -0.3), dark(s.Body, 0.3))
	P("FrontPlate", Vector3.new(2, 0.8, 0.3), CFrame.new(0, 1.55, 1.6), dark(s.Body, 0.2))
	-- stepped trail down to the ground behind
	P("Trail", Vector3.new(1.8, 0.8, 1.2), CFrame.new(0, 1.2, -2.6), s.Body)
	P("Trail", Vector3.new(1.4, 0.6, 1.1), CFrame.new(0, 0.6, -3.4), dark(s.Body, 0.2))
	P("TrailCap", Vector3.new(1.5, 0.15, 1.2), CFrame.new(0, 0.95, -3.4), s.Ring)
	for _, x in ipairs({ -1, 1 }) do
		-- side cheeks: a stepped silhouette that rises towards the barrel
		P("Cheek", Vector3.new(0.4, 0.8, 3.2), CFrame.new(x * 1.1, 2.55, -0.4), s.Body)
		P("Cheek", Vector3.new(0.4, 0.7, 2.2), CFrame.new(x * 1.1, 3.3, 0), s.Body)
		P("Cheek", Vector3.new(0.4, 0.6, 1.2), CFrame.new(x * 1.1, 3.95, 0.3), s.Body)
		P("CheekEdge", Vector3.new(0.44, 0.14, 3.2), CFrame.new(x * 1.1, 2.18, -0.4), dark(s.Body, 0.35))
		P("Trunnion", Vector3.new(0.3, 0.7, 0.7), CFrame.new(x * 1.38, 3.6, 0.3), s.Ring)
		P("TrunnionCap", Vector3.new(0.2, 0.35, 0.35), CFrame.new(x * 1.58, 3.6, 0.3), light(s.Ring, 0.3))
		if s.Kind == "wood" then
			for _, y in ipairs({ 2.35, 2.75 }) do
				P("Plank", Vector3.new(0.42, 0.06, 3.2), CFrame.new(x * 1.1, y, -0.4), dark(s.Body, 0.3))
			end
			P("Band", Vector3.new(0.46, 1.9, 0.25), CFrame.new(x * 1.1, 2.9, 0.9), s.Ring)
		end
		if s.Rivets then
			for _, z in ipairs({ -1.6, -0.6, 0.4, 1 }) do
				P("Rivet", Vector3.new(0.12, 0.22, 0.22), CFrame.new(x * 1.33, 2.55, z), light(s.Ring, 0.15))
			end
		end
		if s.Gems then
			P("Gem", Vector3.new(0.12, 0.55, 0.55), CFrame.new(x * 1.33, 2.65, -0.6) * CFrame.Angles(math.rad(45), 0, 0), x < 0 and Color3.fromRGB(60, 140, 255) or Color3.fromRGB(235, 50, 60), true)
			P("GemFrame", Vector3.new(0.1, 0.8, 0.8), CFrame.new(x * 1.31, 2.65, -0.6) * CFrame.Angles(math.rad(45), 0, 0), s.Ring)
		end
		if s.Kind == "dragon" then
			-- little wings on the carriage
			W("Wing", Vector3.new(0.15, 1.2, 1.6), CFrame.new(x * 1.45, 3.2, -1.4) * CFrame.Angles(0, 0, x * math.rad(-25)) * CFrame.Angles(0, math.pi, 0), s.Ring, glow)
		end
		if s.Kind == "tech" then
			P("Fin", Vector3.new(0.6, 0.12, 1.4), CFrame.new(x * 1.45, 2.2, -1.2), s.Ring, glow)
		end
	end

	---------------------------------------------------------------- wheels
	-- octagon tyre (two squares), coloured rim, a spoke cross and a hub cap
	local axles = (s.Wheels == 4) and { 0.9, -1.6 } or { 0.5 }
	for _, z in ipairs(axles) do
		P("Axle", Vector3.new(3.6, 0.35, 0.35), CFrame.new(0, 1.15, z), dark(s.Wheel, 0.3))
		for _, x in ipairs({ -1, 1 }) do
			local c = CFrame.new(x * 1.65, 1.15, z)
			P("Tyre", Vector3.new(0.7, 1.75, 1.75), c, s.Wheel)
			P("Tyre", Vector3.new(0.7, 1.75, 1.75), c * CFrame.Angles(math.rad(45), 0, 0), s.Wheel)
			P("Rim", Vector3.new(0.76, 1.25, 1.25), c, s.Hub)
			P("Rim", Vector3.new(0.76, 1.25, 1.25), c * CFrame.Angles(math.rad(45), 0, 0), s.Hub)
			P("RimIn", Vector3.new(0.8, 0.85, 0.85), c * CFrame.Angles(math.rad(22.5), 0, 0), dark(s.Wheel, 0.2))
			P("Spoke", Vector3.new(0.84, 1.1, 0.2), c * CFrame.Angles(math.rad(45), 0, 0), s.Hub)
			P("Spoke", Vector3.new(0.84, 0.2, 1.1), c * CFrame.Angles(math.rad(45), 0, 0), s.Hub)
			P("HubCap", Vector3.new(0.95, 0.4, 0.4), c, light(s.Hub, 0.2), glow)
		end
	end

	---------------------------------------------------------------- barrel
	local L = s.Length or 4.6
	local d = s.Bore or 1.6
	local b = CFrame.new(0, 3.6, 0.3) * CFrame.Angles(math.rad(-14), 0, 0) -- +Z tilts up
	local function at(x, y, z)
		return b * CFrame.new(x, y, z)
	end
	P("Barrel", Vector3.new(d, d, L), at(0, 0, 0.5), s.Barrel)
	-- blocky shading: a light strip along the top, a dark one underneath, dark corner edges
	P("Shine", Vector3.new(d * 0.5, 0.06, L - 0.4), at(-d * 0.1, d / 2 + 0.02, 0.5), light(s.Barrel, 0.3))
	P("Shade", Vector3.new(d * 0.9, 0.06, L - 0.2), at(0, -d / 2 - 0.02, 0.5), dark(s.Barrel, 0.3))
	for _, cx in ipairs({ -1, 1 }) do
		for _, cy in ipairs({ -1, 1 }) do
			P("Edge", Vector3.new(0.16, 0.16, L), at(cx * d / 2, cy * d / 2, 0.5), dark(s.Barrel, cy < 0 and 0.35 or 0.15))
		end
	end
	-- rings with a bolt on each side
	local rings = s.Rings or { -1.1, 0.5, 2.0 }
	for i, z in ipairs(rings) do
		local col = s.Ring
		if s.Kind == "hazard" then
			col = i % 2 == 0 and Color3.fromRGB(250, 200, 40) or Color3.fromRGB(30, 30, 36)
		end
		local w = s.Kind == "heavy" and 0.65 or 0.4
		P("Ring", Vector3.new(d + 0.3, d + 0.3, w), at(0, 0, z), col, glow)
		for _, side in ipairs({ -1, 1 }) do
			P("Bolt", Vector3.new(0.08, 0.22, 0.22), at(side * (d / 2 + 0.19), 0, z), light(col, 0.35))
		end
	end
	if s.Kind == "hazard" then
		for i = 0, 3 do
			P("Stripe", Vector3.new(d + 0.04, d + 0.04, 0.28), at(0, 0, -0.35 + i * 0.55 + 0.27), Color3.fromRGB(30, 30, 36))
		end
		-- pipe along the side and a warning light on top
		P("Pipe", Vector3.new(0.3, 0.3, L - 1), at(d / 2 + 0.25, -0.2, 0.3), Color3.fromRGB(120, 125, 135))
		P("Beacon", Vector3.new(0.4, 0.3, 0.4), at(0, d / 2 + 0.3, -0.4), Color3.fromRGB(255, 140, 30), true)
	end
	if s.Kind == "vents" then
		for _, side in ipairs({ -1, 1 }) do
			for i = 0, 2 do
				P("Vent", Vector3.new(0.06, d * 0.5, 0.18), at(side * (d / 2 + 0.02), 0, -0.3 + i * 0.35), dark(s.Barrel, 0.6))
			end
			P("Stripe", Vector3.new(0.06, 0.2, L - 1.6), at(side * (d / 2 + 0.02), d * 0.3, 1.4), s.Ring)
		end
	end
	if s.Kind == "tech" then
		-- glowing core slots down both sides
		for _, side in ipairs({ -1, 1 }) do
			P("Core", Vector3.new(0.08, d * 0.35, L - 1.4), at(side * (d / 2 + 0.03), 0, 0.6), s.Ring, true)
		end
		P("Core", Vector3.new(d * 0.35, 0.08, L - 1.4), at(0, d / 2 + 0.03, 0.6), s.Ring, true)
	end
	if s.Crown then
		P("Crown", Vector3.new(0.9, 0.25, 0.6), at(0, d / 2 + 0.15, -0.3), s.Ring)
		for _, cx in ipairs({ -0.35, 0, 0.35 }) do
			P("Crown", Vector3.new(0.18, cx == 0 and 0.45 or 0.32, 0.18), at(cx, d / 2 + 0.45, -0.3), s.Ring)
		end
		P("CrownGem", Vector3.new(0.2, 0.2, 0.08), at(0, d / 2 + 0.3, -0.02), Color3.fromRGB(235, 50, 60), true)
	end
	-- stepped muzzle flare and a recessed bore
	P("MuzzleBase", Vector3.new(d + 0.45, d + 0.45, 0.45), at(0, 0, L / 2 + 0.5), dark(s.Ring, 0.1), glow)
	local muzzle = P("MuzzleRing", Vector3.new(d + 0.8, d + 0.8, 0.4), at(0, 0, L / 2 + 0.9), s.Ring, glow)
	P("MuzzleLip", Vector3.new(d + 0.9, 0.12, 0.42), at(0, (d + 0.8) / 2, L / 2 + 0.9), light(s.Ring, 0.3))
	local boreGlow = glow or s.Kind == "tech"
	local bore = P("Bore", Vector3.new(d - 0.35, d - 0.35, 0.12), at(0, 0, L / 2 + 1.06), boreGlow and s.Ring or Color3.fromRGB(15, 15, 18), boreGlow)
	P("BoreRim", Vector3.new(d - 0.15, d - 0.15, 0.06), at(0, 0, L / 2 + 1.1), dark(s.Ring, 0.45))
	bore.Parent = m
	if s.Kind == "dragon" then
		-- jaw teeth around the muzzle and two eyes
		for _, cx in ipairs({ -0.55, -0.18, 0.18, 0.55 }) do
			W("Tooth", Vector3.new(0.22, 0.35, 0.2), at(cx, d / 2 + 0.25, L / 2 + 1.05) * CFrame.Angles(math.pi, 0, 0), Color3.fromRGB(250, 245, 230))
			W("Tooth", Vector3.new(0.22, 0.35, 0.2), at(cx, -d / 2 - 0.25, L / 2 + 1.05), Color3.fromRGB(250, 245, 230))
		end
		for _, side in ipairs({ -1, 1 }) do
			P("Eye", Vector3.new(0.08, 0.35, 0.45), at(side * (d / 2 + 0.04), 0.35, L / 2 - 0.4), Color3.fromRGB(255, 230, 60), true)
			P("Pupil", Vector3.new(0.1, 0.3, 0.12), at(side * (d / 2 + 0.06), 0.35, L / 2 - 0.35), Color3.fromRGB(20, 10, 30))
		end
	end
	-- stepped breech and knob
	P("Breech", Vector3.new(d + 0.2, d + 0.2, 0.6), at(0, 0, -L / 2 + 0.4), dark(s.Barrel, 0.15))
	P("Breech", Vector3.new(d - 0.2, d - 0.2, 0.4), at(0, 0, -L / 2 - 0.05), dark(s.Barrel, 0.25))
	P("Knob", Vector3.new(0.6, 0.6, 0.5), at(0, 0, -L / 2 - 0.45), s.Ring)
	P("Knob", Vector3.new(0.35, 0.35, 0.3), at(0, 0, -L / 2 - 0.8), light(s.Ring, 0.25))
	if s.Spikes then
		for i, z in ipairs({ -1.2, -0.1, 1 }) do
			W("Spike", Vector3.new(0.3, 0.75 - i * 0.1, 0.8), at(0, d / 2 + 0.38 - i * 0.05, z), s.Ring, true)
		end
		for _, x in ipairs({ -1, 1 }) do
			P("Horn", Vector3.new(0.3, 0.9, 0.3), at(x * 0.55, d / 2 + 0.35, -L / 2 + 0.2) * CFrame.Angles(math.rad(-30), 0, x * math.rad(-20)), Color3.fromRGB(245, 235, 210))
			P("Horn", Vector3.new(0.2, 0.45, 0.2), at(x * 0.72, d / 2 + 0.85, -L / 2 - 0.05) * CFrame.Angles(math.rad(-55), 0, x * math.rad(-30)), Color3.fromRGB(245, 235, 210))
		end
	end
	if glow then
		local l = Instance.new("PointLight")
		l.Color = s.Ring
		l.Brightness = 1.5
		l.Range = 8
		l.Parent = muzzle
	end
	if s.Sparkle then
		local fx = Instance.new("ParticleEmitter")
		fx.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		fx.Color = ColorSequence.new(s.Sparkle)
		fx.LightEmission = 1
		fx.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 0) })
		fx.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(1, 1) })
		fx.Lifetime = NumberRange.new(1, 1.6)
		fx.Rate = 5
		fx.Speed = NumberRange.new(0.5, 1.2)
		fx.SpreadAngle = Vector2.new(180, 180)
		fx.Parent = body
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
