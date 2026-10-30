--[[
	BuildWorld1  (run once in Studio's Command Bar, Edit mode)

	Builds the World 1 training stations (7 + 1 gamepass) along the left side of the lobby,
	each in a blocky booth copied from the two booth pictures Alex sent (Oct 30): stepped
	floor, white start mat, hazard stripe, X-braced counter, themed back wall (wooden stall,
	pixel steps, truss gantry or gold crown), lane props and effects, neon on the top tiers,
	and a small "+N Power" label. Run BuildRebirthSigns and BuildCartoonyMap after it.
	the Grand Cannon LaunchPoint and Launch Zone, and moves the SpawnLocation into the lobby.
	Safe to re-run: it deletes and rebuilds Workspace.TrainingStations.

	Cannon models: put the imported cannons in ReplicatedStorage > Cannons,
	named exactly as in GameConfig (Cannon01_Starter, ...). Any that are missing
	get a simple placeholder cannon so the station still works.
]]

local ServerStorage = game:GetService("ServerStorage")
local Config = require(game.ReplicatedStorage.GameConfig)

local SIDE = -1 -- -1 = stations on the -Z side of the lobby, 1 = +Z side
local CANNON_HEIGHT = 5 -- studs; a default character is ~5
local TARGET_DISTANCE = 12 -- muzzle to target

local map = workspace.map1b.StoneSkipMap
local lobbyCf, lobbySize = map.Lobby:GetBoundingBox()
local lobbyPos = lobbyCf.Position

-- floor height of the lobby
local hit = workspace:Raycast(lobbyPos + Vector3.new(0, 200, 0), Vector3.new(0, -400, 0))
local floorY = hit and hit.Position.Y or lobbyPos.Y - lobbySize.Y / 2

-- Stations sit in a row along the lobby's long (X) axis, firing towards the side wall
local fireDir = Vector3.new(0, 0, SIDE)
local rowZ = lobbyPos.Z + SIDE * 8 -- stand points, just off the centre path
local spacing = (lobbySize.X - 40) / (#Config.Stations - 1)
local startX = lobbyPos.X - (lobbySize.X - 40) / 2

local old = workspace:FindFirstChild("TrainingStations")
if old then
	old:Destroy()
end
local folder = Instance.new("Folder")
folder.Name = "TrainingStations"

local function part(props)
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for k, v in pairs(props) do
		p[k] = v
	end
	return p
end

local function placeholderCannon()
	local m = Instance.new("Model")
	local base = part({ Size = Vector3.new(4, 1.5, 5), Color = Color3.fromRGB(120, 80, 50), Material = Enum.Material.Wood, Parent = m })
	base.Name = "Base"
	local barrel = part({
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(6, 2.4, 2.4),
		Color = Color3.fromRGB(60, 60, 70),
		Material = Enum.Material.Metal,
		CFrame = CFrame.new(0, 2, 0.5) * CFrame.Angles(0, math.rad(90), 0) * CFrame.Angles(0, 0, math.rad(12)),
		Parent = m,
	})
	barrel.Name = "Barrel"
	m.PrimaryPart = base
	return m
end

local function makeTarget(cf)
	local m = Instance.new("Model")
	m.Name = "Target"
	local rings = {
		{ 6, Color3.fromRGB(235, 60, 60) },
		{ 4.4, Color3.new(1, 1, 1) },
		{ 2.8, Color3.fromRGB(235, 60, 60) },
		{ 1.2, Color3.fromRGB(255, 210, 60) },
	}
	for i, r in ipairs(rings) do
		local disc = part({
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.4, r[1], r[1]),
			Color = r[2],
			Material = i == #rings and Enum.Material.Neon or Enum.Material.SmoothPlastic, -- glowing bullseye
			CanCollide = false,
			CFrame = cf * CFrame.new(0, 0, -0.1 * i) * CFrame.Angles(0, math.rad(90), 0),
			Parent = m,
		})
		disc.Name = "Ring"
	end
	-- invisible aim point; its front faces the cannon
	part({ Name = "Center", Size = Vector3.one * 0.5, Transparency = 1, CanCollide = false, CFrame = cf * CFrame.new(0, 0, -0.5), Parent = m })
	for _, x in ipairs({ -1.6, 1.6 }) do
		part({
			Size = Vector3.new(0.5, cf.Position.Y - floorY, 0.5),
			Color = Color3.fromRGB(110, 75, 45),
			Material = Enum.Material.Wood,
			CFrame = cf * CFrame.new(x, -(cf.Position.Y - floorY) / 2, 0.5),
			Parent = m,
		}).Name = "Leg"
	end
	m.PrimaryPart = m.Center
	return m
end

local function makeSign(cf, info)
	local sign = part({ Size = Vector3.new(1, 1, 1), Transparency = 1, CanCollide = false, CFrame = cf, Name = "Sign" })
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromScale(10, 4)
	bb.MaxDistance = 120
	bb.Parent = sign
	local function line(text, y, h, color)
		local t = Instance.new("TextLabel")
		t.BackgroundTransparency = 1
		t.Size = UDim2.fromScale(1, h)
		t.Position = UDim2.fromScale(0, y)
		t.Font = Enum.Font.FredokaOne
		t.TextScaled = true
		t.Text = text
		t.TextColor3 = color
		local s = Instance.new("UIStroke")
		s.Thickness = 3
		s.Parent = t
		t.Parent = bb
	end
	line(info.Name, 0, 0.4, Color3.new(1, 1, 1))
	line("+" .. Config.Format(info.Gain) .. " Power per shot", 0.4, 0.32, Color3.fromRGB(255, 215, 70))
	local req
	if info.Pass then
		req = "VIP GAMEPASS"
	elseif info.Rebirths > 0 then
		req = "Requires " .. info.Rebirths .. " Rebirths"
	else
		req = "FREE"
	end
	line(req, 0.72, 0.28, info.Pass and Color3.fromRGB(255, 200, 60) or Color3.fromRGB(140, 255, 150))
	return sign
end

-- Booth looks, one per station Id, copied from Alex's two booth pictures (Oct 30):
-- the low tiers are matte (left picture), the high tiers glow with neon edges (right picture).
-- Style: "stall" wooden fair stall, "stepped" pixel-stepped back wall, "truss" metal
-- gantry, "crown" gold frame with a crown. Props: the extras in each lane.
local function rgb(r, g, b)
	return Color3.fromRGB(r, g, b)
end
local THEMES = {
	[1] = { Rim = rgb(35, 70, 170), Floor = rgb(65, 115, 215), Counter = rgb(150, 75, 45), Frame = rgb(120, 60, 35), Panel = rgb(165, 90, 55), Style = "stall", Props = "fair" },
	[2] = { Rim = rgb(25, 30, 95), Floor = rgb(225, 45, 50), Counter = rgb(25, 30, 95), Frame = rgb(25, 30, 95), Panel = rgb(30, 38, 110), Style = "stepped", Props = "targets", Edge = rgb(255, 60, 70) },
	[3] = { Rim = rgb(110, 190, 240), Floor = rgb(170, 225, 250), Counter = rgb(60, 140, 220), Frame = rgb(225, 240, 255), Panel = rgb(140, 210, 245), Style = "truss", Props = "ice", Neon = rgb(80, 190, 255), Rings = { rgb(255, 255, 255), rgb(80, 170, 240), rgb(255, 255, 255), rgb(80, 170, 240) } },
	[4] = { Rim = rgb(235, 120, 20), Floor = rgb(250, 165, 40), Counter = rgb(240, 150, 40), Frame = rgb(240, 130, 25), Panel = rgb(70, 30, 20), Style = "truss", Props = "stage", Edge = rgb(255, 150, 40) },
	[5] = { Rim = rgb(215, 45, 200), Floor = rgb(240, 85, 220), Counter = rgb(110, 40, 190), Frame = rgb(225, 60, 210), Panel = rgb(95, 35, 175), Style = "truss", Props = "balloons" },
	[6] = { Rim = rgb(235, 185, 25), Floor = rgb(255, 215, 60), Counter = rgb(240, 190, 40), Frame = rgb(250, 205, 45), Panel = rgb(90, 25, 25), Style = "crown", Props = "gold", Neon = rgb(255, 245, 210), Rings = { rgb(255, 200, 40), rgb(255, 225, 110), rgb(220, 40, 40), rgb(255, 200, 40) } },
	[7] = { Rim = rgb(85, 30, 200), Floor = rgb(40, 20, 105), Counter = rgb(85, 30, 200), Frame = rgb(70, 25, 170), Panel = rgb(35, 15, 90), Style = "stepped", Props = "neon", Neon = rgb(255, 60, 230), Rings = { rgb(255, 60, 230), rgb(45, 15, 95), rgb(255, 60, 230), rgb(45, 15, 95) } },
	[8] = { Rim = rgb(70, 215, 60), Floor = rgb(30, 110, 45), Counter = rgb(60, 190, 55), Frame = rgb(70, 215, 60), Panel = rgb(15, 60, 30), Style = "truss", Props = "toxic", Neon = rgb(110, 255, 90), Rings = { rgb(110, 255, 90), rgb(20, 70, 35), rgb(110, 255, 90), rgb(255, 255, 255) } },
}
local function dark(c, a)
	return c:Lerp(Color3.new(0, 0, 0), a or 0.3)
end
local WHITE = rgb(245, 245, 250)

-- the booth around one station. at(x, y, z): x right, y up from the floor, z forward
-- from the stand point towards the target.
local function makeBooth(standCf, width, targetZ, theme, info)
	local m = Instance.new("Model")
	m.Name = "Booth"
	local W = width
	local front, back = -6, targetZ + 1.8
	local L = back - front
	local function at(x, y, z)
		return standCf * CFrame.new(x, y, -z)
	end
	local function blk(name, size, x, y, z, color, collide)
		return part({ Name = name, Size = size, CFrame = at(x, y, z), Color = color, Material = Enum.Material.SmoothPlastic, CanCollide = collide == true, Parent = m })
	end
	local function glow(name, size, x, y, z, color)
		local p = blk(name, size, x, y, z, color)
		p.Material = Enum.Material.Neon
		p.CastShadow = false
		return p
	end
	-- a thin bar between two booth points
	local function bar(x0, y0, z0, x1, y1, z1, t, color, name)
		local a, b = at(x0, y0, z0).Position, at(x1, y1, z1).Position
		return part({ Name = name or "Bar", Size = Vector3.new(t, t, (b - a).Magnitude + t), CFrame = CFrame.lookAt((a + b) / 2, b), Color = color, Material = Enum.Material.SmoothPlastic, CanCollide = false, Parent = m })
	end
	local function round(name, d, len, x, y, z, color, upright)
		local p = blk(name, Vector3.new(len, d, d), x, y, z, color)
		p.Shape = Enum.PartType.Cylinder
		p.CFrame = p.CFrame * (upright and CFrame.Angles(0, 0, math.rad(90)) or CFrame.Angles(0, math.rad(90), 0))
		return p
	end
	local function ball(name, d, x, y, z, color)
		local p = blk(name, Vector3.one * d, x, y, z, color)
		p.Shape = Enum.PartType.Ball
		return p
	end
	local function sparkles(parent, color, rate, size, texture, speed)
		local fx = Instance.new("ParticleEmitter")
		fx.Texture = texture or "rbxasset://textures/particles/sparkles_main.dds"
		fx.Color = ColorSequence.new(color)
		fx.LightEmission = 1
		fx.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, size), NumberSequenceKeypoint.new(1, 0) })
		fx.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(1, 1) })
		fx.Lifetime = NumberRange.new(1.5, 2.5)
		fx.Rate = rate
		fx.Speed = NumberRange.new(speed or 1, (speed or 1) * 2)
		fx.SpreadAngle = Vector2.new(180, 180)
		fx.Parent = parent
		return fx
	end

	-- floor: chunky stepped corners, a rim and the coloured floor on top
	blk("Rim", Vector3.new(W, 0.6, L - 2), 0, 0.3, (front + back) / 2, theme.Rim, true)
	blk("Rim", Vector3.new(W - 2, 0.6, L), 0, 0.3, (front + back) / 2, theme.Rim, true)
	blk("Floor", Vector3.new(W - 1.6, 0.7, L - 3.6), 0, 0.35, (front + back) / 2, theme.Floor, true)
	blk("Floor", Vector3.new(W - 3.6, 0.7, L - 1.6), 0, 0.35, (front + back) / 2, theme.Floor, true)
	if theme.Neon or theme.Edge then
		-- glowing outline around the rim (front edge only for the matte tiers)
		local c = theme.Neon or theme.Edge
		glow("Edge", Vector3.new(W - 2, 0.2, 0.3), 0, 0.62, front + 0.15, c)
		if theme.Neon then
			for _, s in ipairs({ -1, 1 }) do
				glow("Edge", Vector3.new(0.3, 0.2, L - 2), s * (W / 2 - 0.15), 0.62, (front + back) / 2, c)
			end
		end
	end

	-- start mat: white outline and the two marks
	local matW, z0, z1 = W - 4.4, front + 1.6, 0.6
	for _, s in ipairs({ -1, 1 }) do
		blk("Mat", Vector3.new(0.25, 0.08, z1 - z0), s * matW / 2, 0.74, (z0 + z1) / 2, WHITE)
		blk("Mat", Vector3.new(matW + 0.25, 0.08, 0.25), 0, 0.74, s == -1 and z0 or z1, WHITE)
		blk("Mark", Vector3.new(0.45, 0.08, 1.4), s * 0.45, 0.74, -0.5, WHITE)
	end
	-- black and yellow hazard stripe
	blk("Hazard", Vector3.new(W - 3.6, 0.1, 0.5), 0, 0.75, 1.0, rgb(25, 25, 30))
	for x = -(W - 4.6) / 2, (W - 4.6) / 2, 1 do
		blk("Hazard", Vector3.new(0.45, 0.12, 0.5), x, 0.76, 1.0, rgb(250, 200, 30))
	end

	-- counter with an X-braced front and two little props on top
	local cw = W - 3.6
	blk("Counter", Vector3.new(cw, 1.8, 0.9), 0, 1.6, 1.75, theme.Counter, true)
	blk("CounterTop", Vector3.new(cw + 0.3, 0.3, 1.2), 0, 2.65, 1.75, dark(theme.Counter, 0.2), true)
	local segs = 3
	for i = 0, segs - 1 do
		local xa = -cw / 2 + i * cw / segs + 0.2
		local xb = xa + cw / segs - 0.4
		bar(xa, 0.9, 1.28, xb, 2.3, 1.28, 0.2, dark(theme.Counter, 0.45), "Brace")
		bar(xa, 2.3, 1.28, xb, 0.9, 1.28, 0.2, dark(theme.Counter, 0.45), "Brace")
	end
	blk("AmmoBox", Vector3.new(1, 0.55, 0.6), -cw / 2 + 1, 3.08, 1.75, rgb(70, 110, 50))
	blk("AmmoLid", Vector3.new(1.02, 0.12, 0.62), -cw / 2 + 1, 3.3, 1.75, rgb(240, 190, 40))
	blk("Grip", Vector3.new(1.2, 0.25, 0.3), cw / 2 - 1, 2.93, 1.75, rgb(245, 200, 40))
	for _, s in ipairs({ -1, 1 }) do
		round("Grip", 0.5, 0.5, cw / 2 - 1 + s * 0.55, 3.05, 1.75, rgb(30, 30, 35), true)
	end

	-- back wall
	local H = 10
	local pz = back - 0.6
	if theme.Style == "stall" then
		-- wooden fair stall: planks, posts, bunting
		for i = 0, math.floor(W - 2) - 1 do
			blk("Plank", Vector3.new(1, H - 1.5, 0.4), -(W - 2) / 2 + 0.5 + i, (H - 1.5) / 2 + 0.6, pz, i % 2 == 0 and theme.Panel or dark(theme.Panel, 0.12), true)
		end
		for _, s in ipairs({ -1, 1 }) do
			blk("Post", Vector3.new(0.8, H + 0.6, 0.8), s * (W / 2 - 0.9), (H + 0.6) / 2 + 0.6, pz - 0.2, theme.Frame, true)
		end
		blk("Rope", Vector3.new(W - 1.6, 0.12, 0.12), 0, H + 0.3, pz - 0.5, rgb(240, 230, 210))
		local flagCols = { rgb(235, 60, 60), rgb(250, 200, 40), rgb(60, 140, 235), rgb(80, 200, 90) }
		for i = 0, math.floor(W - 3) - 1 do
			local f = blk("Flag", Vector3.new(0.7, 0.7, 0.1), -(W - 3) / 2 + 0.5 + i, H - 0.1, pz - 0.5, flagCols[i % 4 + 1])
			f.CFrame = f.CFrame * CFrame.Angles(0, 0, math.rad(45))
		end
		-- side shelves with cans and bottles
		for _, s in ipairs({ -1, 1 }) do
			local sx = s * (W / 2 - 2.6)
			blk("Shelf", Vector3.new(3, 0.3, 1.2), sx, 3.2, pz - 1, dark(theme.Panel, 0.25), true)
			round("Can", 0.7, 0.9, sx - 0.8, 3.8, pz - 1, rgb(60, 180, 90), true)
			round("Can", 0.7, 0.9, sx, 3.8, pz - 1, rgb(235, 60, 60), true)
			round("Can", 0.7, 0.9, sx + 0.8, 3.8, pz - 1, rgb(60, 140, 235), true)
			round("Can", 0.7, 0.9, sx - 0.4, 4.7, pz - 1, rgb(250, 200, 40), true)
			round("Can", 0.7, 0.9, sx + 0.4, 4.7, pz - 1, rgb(235, 60, 60), true)
		end
	else
		-- framed panel behind the target
		blk("BackPanel", Vector3.new(W - 2.4, H - 1, 0.4), 0, (H - 1) / 2 + 0.6, pz, theme.Panel, true)
		for _, s in ipairs({ -1, 1 }) do
			blk("Pillar", Vector3.new(1.2, H + 0.6, 1.2), s * (W / 2 - 0.9), (H + 0.6) / 2 + 0.6, pz, theme.Frame, true)
		end
		blk("TopBeam", Vector3.new(W - 0.6, 1.2, 1.2), 0, H + 0.6, pz, theme.Frame, true)
		if theme.Neon then
			-- neon lines down the pillars and along the beam, like the right-hand picture
			for _, s in ipairs({ -1, 1 }) do
				glow("Neon", Vector3.new(0.25, H, 0.25), s * (W / 2 - 1.6), H / 2 + 0.6, pz - 0.65, theme.Neon)
			end
			glow("Neon", Vector3.new(W - 3, 0.25, 0.25), 0, H - 0.1, pz - 0.65, theme.Neon)
		end
	end
	if theme.Style == "stepped" then
		-- pixel steps on top of the wall
		local y = H + 1.2
		for i, w in ipairs({ W - 2.4, W - 5, W - 7.6 }) do
			blk("Step", Vector3.new(w, 1, 1), 0, y + (i - 1), pz, theme.Frame, true)
		end
	elseif theme.Style == "truss" then
		-- metal truss gantry over the back of the lane
		local fz = back - 6.5
		local t = 0.22
		local c = theme.Frame
		for _, s in ipairs({ -1, 1 }) do
			local x = s * (W / 2 - 0.9)
			for _, zz in ipairs({ fz }) do
				for _, dx in ipairs({ -0.4, 0.4 }) do
					bar(x + dx, 0.7, zz, x + dx, H + 1.2, zz, t, c, "Truss")
				end
				for y = 0.7, H, 1.6 do
					bar(x - 0.4, y, zz, x + 0.4, y + 1.6, zz, t, c, "Truss")
				end
			end
			-- top side beam back to the wall, with zig-zag braces
			bar(x, H + 1.2, fz, x, H + 1.2, pz, t * 1.4, c, "Truss")
			bar(x, H + 0.4, fz, x, H + 0.4, pz, t, c, "Truss")
			local n = math.max(2, math.floor((pz - fz) / 1.6))
			for i = 0, n - 1 do
				local za = fz + i * (pz - fz) / n
				local zb = za + (pz - fz) / n
				bar(x, i % 2 == 0 and H + 0.4 or H + 1.2, za, x, i % 2 == 0 and H + 1.2 or H + 0.4, zb, t, c, "Truss")
			end
		end
		-- front cross beam
		bar(-(W / 2 - 0.9), H + 1.2, fz, W / 2 - 0.9, H + 1.2, fz, t * 1.4, c, "Truss")
		bar(-(W / 2 - 0.9), H + 0.4, fz, W / 2 - 0.9, H + 0.4, fz, t, c, "Truss")
		local n = math.floor((W - 1.8) / 1.6)
		for i = 0, n - 1 do
			local xa = -(W / 2 - 0.9) + i * (W - 1.8) / n
			local xb = xa + (W - 1.8) / n
			bar(xa, i % 2 == 0 and H + 0.4 or H + 1.2, fz, xb, i % 2 == 0 and H + 1.2 or H + 0.4, fz, t, c, "Truss")
		end
	elseif theme.Style == "crown" then
		-- gold crown on top of the frame, with a blue and a red gem
		local y = H + 1.6
		blk("Crown", Vector3.new(4.2, 1, 1), 0, y, pz, rgb(255, 205, 40))
		for i, x in ipairs({ -1.7, -0.6, 0.6, 1.7 }) do
			blk("Crown", Vector3.new(0.7, i % 3 == 1 and 1.2 or 1.6, 0.7), x, y + 0.9, pz, rgb(255, 205, 40))
		end
		blk("Gem", Vector3.new(0.5, 0.5, 0.2), -0.8, y, pz - 0.55, rgb(60, 140, 255))
		blk("Gem", Vector3.new(0.5, 0.5, 0.2), 0.8, y, pz - 0.55, rgb(235, 50, 60))
	end

	-- lane props
	local laneZ = (2.6 + pz) / 2
	if theme.Props == "fair" then
		local tire = round("Tire", 1.8, 0.8, -(W / 2 - 2.3), 1.1, 3.6, rgb(30, 30, 35), true)
		tire.CFrame = at(-(W / 2 - 2.3), 1.1, 3.6) * CFrame.Angles(0, 0, math.rad(90))
		blk("Crate", Vector3.new(1.4, 0.9, 1), W / 2 - 2.3, 1.15, 3.8, rgb(200, 140, 70))
		for i, c in ipairs({ rgb(235, 60, 60), rgb(60, 140, 235), rgb(80, 200, 90) }) do
			round("Bottle", 0.35, 1, W / 2 - 2.8 + i * 0.35, 2.1, 3.8, c, true)
		end
	elseif theme.Props == "targets" then
		for _, s in ipairs({ -1, 1 }) do
			local x = s * (W / 2 - 2.4)
			blk("Stand", Vector3.new(0.25, 2.6, 0.25), x, 2, pz - 1.2, rgb(30, 30, 40))
			round("SmallTarget", 2, 0.25, x, 3.6, pz - 1.3, rgb(235, 55, 60))
			round("SmallTarget", 1.3, 0.27, x, 3.6, pz - 1.3, WHITE)
			round("SmallTarget", 0.6, 0.29, x, 3.6, pz - 1.3, rgb(235, 55, 60))
		end
		blk("Badge", Vector3.new(1.2, 1.2, 0.2), 0, H + 0.6, pz - 0.7, WHITE)
	elseif theme.Props == "ice" then
		local glass = { { -2.6, 3.4 }, { 2.4, 4.8 }, { -1.8, 6.2 }, { 2.9, 2.9 } }
		for _, g in ipairs(glass) do
			local p = blk("Ice", Vector3.new(1.3, 1.3, 1.3), g[1], 1.35, g[2], rgb(200, 240, 255))
			p.Material = Enum.Material.Glass
			p.Transparency = 0.35
		end
		sparkles(blk("Fx", Vector3.new(W - 3, 0.2, 4), 0, 1, laneZ, WHITE), rgb(200, 240, 255), 3, 0.5).Parent.Transparency = 1
	elseif theme.Props == "stage" then
		local sun = round("Sun", 4, 0.3, 0, 7.6, pz - 0.4, rgb(255, 210, 40))
		sun.Material = Enum.Material.Neon
		for _, s in ipairs({ -1, 1 }) do
			for _, y in ipairs({ 4.2, 7.4 }) do
				blk("Speaker", Vector3.new(1.6, 1.6, 0.8), s * (W / 2 - 2.4), y, pz - 0.6, rgb(30, 25, 25))
				round("Cone", 1, 0.2, s * (W / 2 - 2.4), y, pz - 1.05, rgb(255, 200, 40))
			end
			local x = s * (W / 2 - 2.6)
			round("Barrel", 1.5, 1.8, x, 1.6, 4.2, rgb(200, 40, 35), true)
			round("Lid", 1.55, 0.15, x, 2.55, 4.2, rgb(255, 210, 120), true)
			local smoke = sparkles(blk("Fx", Vector3.new(1, 0.2, 1), x, 2.7, 4.2, WHITE), rgb(255, 160, 60), 6, 2.2, "rbxasset://textures/particles/smoke_main.dds", 1.5)
			smoke.Parent.Transparency = 1
			smoke.LightEmission = 0.3
			smoke.SpreadAngle = Vector2.new(15, 15)
			smoke.EmissionDirection = Enum.NormalId.Top
			smoke.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 1) })
		end
	elseif theme.Props == "balloons" then
		local cols = { rgb(90, 190, 255), rgb(255, 120, 220), rgb(255, 220, 80) }
		for i, b in ipairs({ { -2.6, 5.4, 6.8 }, { 2.7, 6.2, 7.6 }, { -3, 4.2, 6.6 } }) do
			local x, y, z = b[1], b[3], pz - 1 - i * 0.5
			ball("Balloon", 1.4, x, y, z, cols[i]).Material = Enum.Material.Glass
			bar(x, y - 0.7, z, x * 0.8, 0.8, z - 1.5, 0.08, WHITE, "String")
			blk("Weight", Vector3.new(0.5, 0.4, 0.5), x * 0.8, 0.9, z - 1.5, rgb(250, 200, 40))
		end
		for _, st in ipairs({ { -2, 8 }, { 2.4, 4.5 }, { 0.6, 9 } }) do
			local p = blk("Star", Vector3.new(0.5, 0.5, 0.15), st[1], st[2], pz - 0.3, WHITE)
			p.Material = Enum.Material.Neon
			p.CFrame = p.CFrame * CFrame.Angles(0, 0, math.rad(45))
		end
		sparkles(blk("Fx", Vector3.new(W - 3, 0.2, 4), 0, 1, laneZ, WHITE), rgb(255, 170, 240), 3, 0.5).Parent.Transparency = 1
	elseif theme.Props == "gold" then
		-- red laser lines on the dark panel and a gold sparkle shower
		for _, s in ipairs({ -1, 1 }) do
			local a = bar(s * 1.2, 1, pz - 0.3, s * (W / 2 - 1.8), H - 1, pz - 0.3, 0.12, rgb(255, 40, 40), "Laser")
			a.Material = Enum.Material.Neon
			blk("GoldPile", Vector3.new(1.6, 0.6, 1.6), s * (W / 2 - 2.6), 1, laneZ, rgb(255, 205, 40))
			blk("GoldPile", Vector3.new(1, 0.5, 1), s * (W / 2 - 2.6), 1.55, laneZ, rgb(255, 225, 90))
		end
		local fx = sparkles(blk("Fx", Vector3.new(W - 3, 0.2, 5), 0, H - 1, laneZ, WHITE), rgb(255, 215, 80), 10, 0.7)
		fx.Parent.Transparency = 1
		fx.EmissionDirection = Enum.NormalId.Bottom
		fx.Acceleration = Vector3.new(0, -3, 0)
	elseif theme.Props == "neon" then
		for _, s in ipairs({ -1, 1 }) do
			glow("NeonBox", Vector3.new(1.4, 1.4, 0.3), s * (W / 2 - 2.6), 2.8, pz - 0.5, theme.Neon)
			blk("NeonBoxIn", Vector3.new(0.8, 0.8, 0.3), s * (W / 2 - 2.6), 2.8, pz - 0.6, theme.Panel)
			blk("Leg", Vector3.new(0.3, 2, 0.3), s * (W / 2 - 2.6), 1.6, pz - 1.6, rgb(20, 10, 40))
		end
		sparkles(blk("Fx", Vector3.new(W - 3, 0.2, 4), 0, 1, laneZ, WHITE), theme.Neon, 3, 0.5).Parent.Transparency = 1
	elseif theme.Props == "toxic" then
		for i, o in ipairs({ { -2.8, 3.6, 1.6 }, { 2.6, 5.2, 1.2 }, { -2.2, 7.4, 1 }, { 2.9, 2.6, 0.8 } }) do
			local b = ball("Orb", o[3], o[1], 0.7 + o[3] / 2, o[2], theme.Neon)
			b.Material = Enum.Material.Neon
		end
		for _, s in ipairs({ -1, 1 }) do
			round("Tank", 1.2, 3.4, s * (W / 2 - 2.2), 2.4, pz - 1.2, rgb(20, 40, 90), true)
			local cap = round("TankGlow", 1.25, 0.4, s * (W / 2 - 2.2), 4.2, pz - 1.2, theme.Neon, true)
			cap.Material = Enum.Material.Neon
		end
		local sign = blk("Warning", Vector3.new(1.6, 1.6, 0.15), W / 2 - 2, H - 1.5, pz - 0.4, rgb(250, 205, 30))
		sign.CFrame = sign.CFrame * CFrame.Angles(0, 0, math.rad(45))
		local sg = Instance.new("SurfaceGui")
		sg.Face = Enum.NormalId.Back
		sg.Parent = sign
		local tl = Instance.new("TextLabel")
		tl.BackgroundTransparency = 1
		tl.Size = UDim2.fromScale(1, 1)
		tl.Rotation = -45
		tl.Text = "!"
		tl.Font = Enum.Font.FredokaOne
		tl.TextScaled = true
		tl.TextColor3 = rgb(25, 25, 30)
		tl.Parent = sg
		local fx = sparkles(blk("Fx", Vector3.new(W - 3, 0.2, 5), 0, 1, laneZ, WHITE), theme.Neon, 6, 0.6)
		fx.Parent.Transparency = 1
		fx.EmissionDirection = Enum.NormalId.Top
		fx.SpreadAngle = Vector2.new(20, 20)
	end

	-- small black "+N Power" label over the booth, like the pictures
	local tag = blk("Tag", Vector3.new(0.5, 0.5, 0.5), 0, H + 4.2, pz, WHITE)
	tag.Transparency = 1
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromScale(5, 1.2)
	bb.MaxDistance = 150
	bb.Parent = tag
	local pill = Instance.new("TextLabel")
	pill.Size = UDim2.fromScale(1, 1)
	pill.BackgroundColor3 = rgb(15, 15, 20)
	pill.BackgroundTransparency = 0.1
	pill.Font = Enum.Font.FredokaOne
	pill.TextScaled = true
	pill.TextColor3 = theme.Neon or theme.Edge or WHITE
	pill.Text = "+" .. Config.Format(info.Gain) .. " Power"
	pill.Parent = bb
	local cr = Instance.new("UICorner")
	cr.CornerRadius = UDim.new(0.5, 0)
	cr.Parent = pill
	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0.15, 0)
	pad.PaddingBottom = UDim.new(0.15, 0)
	pad.Parent = pill
	for _, d in ipairs(m:GetDescendants()) do
		if d:IsA("BasePart") then
			d.Anchored = true
		end
	end
	return m
end

local templates = game.ReplicatedStorage:FindFirstChild("Cannons")

-- row order: by rebirths needed, the VIP booth last
local order = table.clone(Config.Stations)
table.sort(order, function(a, b)
	local ka = a.Pass and math.huge or a.Rebirths
	local kb = b.Pass and math.huge or b.Rebirths
	return ka < kb
end)
local boothWidth = math.min(13, spacing - 4)

for i, info in ipairs(order) do
	local station = Instance.new("Model")
	station.Name = "Station_" .. info.Id
	station:SetAttribute("StationId", info.Id)

	local standPos = Vector3.new(startX + (i - 1) * spacing, floorY, rowZ)
	local standCf = CFrame.lookAt(standPos, standPos + fireDir)

	local pad = part({
		Name = "Pad",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.4, 7, 7),
		Transparency = 1, -- the booth's start mat shows where to stand
		CanCollide = false,
		CFrame = CFrame.new(standPos + Vector3.new(0, 0.2, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Parent = station,
	})
	part({ Name = "StandPoint", Size = Vector3.new(1, 0.2, 1), Transparency = 1, CanCollide = false, CanTouch = false, CFrame = standCf, Parent = station })

	-- Cannon, scaled to CANNON_HEIGHT and facing the target
	local cannon
	local template = templates and templates:FindFirstChild(info.Model)
	if template then
		cannon = template:Clone()
	else
		cannon = placeholderCannon()
		warn("[BuildWorld1] Missing " .. info.Model .. " in ReplicatedStorage.Cannons, using placeholder")
	end
	cannon.Name = "Cannon"
	for _, d in ipairs(cannon:GetDescendants()) do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
		end
	end
	local _, size = cannon:GetBoundingBox()
	cannon:ScaleTo(cannon:GetScale() * CANNON_HEIGHT / size.Y)
	_, size = cannon:GetBoundingBox()
	local cannonPos = standPos + fireDir * (2.5 + size.Z / 2)
	-- imported cannons point their barrel along +Z, so face +Z at the target
	cannon:PivotTo(CFrame.lookAt(cannonPos, cannonPos - fireDir))
	local cf, sz = cannon:GetBoundingBox()
	cannon:PivotTo(cannon:GetPivot() + Vector3.new(0, floorY - (cf.Position.Y - sz.Y / 2), 0))
	cannon.Parent = station

	local muzzlePos = cannonPos + fireDir * (size.Z / 2) + Vector3.new(0, floorY + size.Y * 0.62 - cannonPos.Y, 0)
	part({ Name = "Muzzle", Size = Vector3.one * 0.5, Transparency = 1, CanCollide = false, CanTouch = false, CanQuery = false, CFrame = CFrame.lookAt(muzzlePos, muzzlePos + fireDir), Parent = station })

	local targetPos = muzzlePos + fireDir * TARGET_DISTANCE
	local target = makeTarget(CFrame.lookAt(targetPos, targetPos - fireDir))
	-- the booth's back wall holds the target now, so no legs; themed ring colours
	local theme = THEMES[info.Id] or THEMES[1]
	local ring = 0
	for _, d in ipairs(target:GetChildren()) do
		if d.Name == "Leg" then
			d:Destroy()
		elseif d.Name == "Ring" and theme.Rings then
			ring += 1
			d.Color = theme.Rings[ring] or d.Color
			if theme.Neon and ring % 2 == 1 then
				d.Material = Enum.Material.Neon
			end
		end
	end
	target.Parent = station
	local targetZ = (targetPos - standPos):Dot(fireDir)
	makeBooth(CFrame.lookAt(Vector3.new(standPos.X, floorY, standPos.Z), Vector3.new(standPos.X, floorY, standPos.Z) + fireDir), boothWidth, targetZ, THEMES[info.Id] or THEMES[1], info).Parent = station

	station.PrimaryPart = pad
	station.Parent = folder
end
folder.Parent = workspace

-- Grand Cannon launch point
local grand = map.Grand_Cannon
local gcf, gsize = grand:GetBoundingBox()
local lp = workspace:FindFirstChild("LaunchPoint") or part({ Name = "LaunchPoint" })
lp.Size = Vector3.new(6, 1, 6)
lp.Transparency = 1
lp.CanCollide = false
lp.Position = gcf.Position + Vector3.new(0, gsize.Y / 2 + 4, 0)
lp.Parent = workspace
local oldPrompt = lp:FindFirstChildOfClass("ProximityPrompt")
if oldPrompt then
	oldPrompt:Destroy()
end

-- Launch Zone: walk in and the Grand Cannon fires you (like Stone Skipping's Throw Zone)
local old = workspace:FindFirstChild("LaunchZone")
if old then
	old:Destroy()
end
local zonePos = Vector3.new(gcf.Position.X - gsize.X / 2 - 14, floorY + 0.1, gcf.Position.Z)
local zone = part({
	Name = "LaunchZone",
	Size = Vector3.new(16, 0.2, 26),
	CFrame = CFrame.new(zonePos),
	Color = Color3.fromRGB(255, 200, 40),
	Material = Enum.Material.Neon,
	Transparency = 0.15,
	CanCollide = false,
	Parent = workspace,
})
local surface = Instance.new("SurfaceGui")
surface.Face = Enum.NormalId.Top
surface.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
surface.PixelsPerStud = 30
surface.LightInfluence = 0
surface.Parent = zone
local label = Instance.new("TextLabel")
label.BackgroundTransparency = 1
label.Size = UDim2.fromScale(1, 1)
label.Rotation = 90
label.Font = Enum.Font.FredokaOne
label.Text = "LAUNCH ZONE"
label.TextScaled = true
label.TextColor3 = Color3.new(1, 1, 1)
label.Parent = surface
local stroke = Instance.new("UIStroke")
stroke.Thickness = 6
stroke.Color = Color3.fromRGB(120, 60, 0)
stroke.Parent = label
local board = Instance.new("BillboardGui")
board.Size = UDim2.fromOffset(260, 70)
board.StudsOffset = Vector3.new(0, 9, 0)
board.LightInfluence = 0
board.MaxDistance = 250
board.Parent = zone
local boardText = label:Clone()
boardText.Rotation = 0
boardText.Text = "WALK IN TO LAUNCH!"
boardText.TextColor3 = Color3.fromRGB(255, 230, 90)
boardText.Parent = board
local sparkle = Instance.new("ParticleEmitter")
sparkle.Texture = "rbxasset://textures/particles/sparkles_main.dds"
sparkle.Color = ColorSequence.new(Color3.fromRGB(255, 230, 90))
sparkle.Rate = 12
sparkle.Speed = NumberRange.new(3, 6)
sparkle.Lifetime = NumberRange.new(1, 1.6)
sparkle.EmissionDirection = Enum.NormalId.Top
sparkle.Size = NumberSequence.new(0.8, 0)
sparkle.Parent = zone

-- Spawn in the lobby, on the centre path, facing the Grand Cannon
local spawn = workspace:FindFirstChildOfClass("SpawnLocation")
if spawn then
	local p = Vector3.new(lobbyPos.X - lobbySize.X * 0.3, floorY + 0.5, lobbyPos.Z)
	spawn.CFrame = CFrame.lookAt(p, p + Vector3.new(1, 0, 0))
	spawn.Anchored = true
end

print("[BuildWorld1] Built " .. #Config.Stations .. " stations")
