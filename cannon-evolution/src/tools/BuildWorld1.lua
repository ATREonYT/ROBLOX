--[[
	BuildWorld1  (run once in Studio's Command Bar, Edit mode)

	Builds the training lanes (5 + 1 gamepass, GameConfig), like Stone Skipping's (Alex, Oct 31: one lane
	model cloned for every tier; the whole lane in the tier's colour, the floor the tier colour, a darker
	raised rim and a lighter centre track; no ropes or posts; plain low tiers, then glow, then sparkles and
	shine, the last one black with neon; side by side facing you). Every lane is the same rectangle: only
	its colours, effects and the tier's own cannon change. On the new map they stand on one open stud
	platform. Run BuildRebirthSigns (one label per lane) and BuildCartoonyMap (the studs) after it. It also places the Grand Cannon LaunchPoint and Launch Zone, and
	moves the SpawnLocation into the lobby.
	Safe to re-run: it deletes and rebuilds Workspace.TrainingStations.

	Cannon models: put the imported cannons in ReplicatedStorage > Cannons,
	named exactly as in GameConfig (Cannon01_Starter, ...). Any that are missing
	get a simple placeholder cannon so the station still works.
]]

local ServerStorage = game:GetService("ServerStorage")
local Config = require(game.ReplicatedStorage.GameConfig)

local SIDE = 1 -- -1 = stations on the -Z side of the lobby, 1 = +Z side (Alex, Oct 30: training on your left as you face the water, the cannonball stand on your right)
local CANNON_HEIGHT = 4.5 -- studs; a default character is ~5. Low and less than half the lane's inner width, so the lane reads as a pool (Oct 31 study)
local PAD_UP = 0.25 -- the stand pad's tiles stand this far over the lane floor, so the pad is its own thing; the cannon sits on them
local LANE_W = 11 -- the lane's width (full size): narrower than the gap math, so a wide stud walkway runs between lanes
local TARGET_Z = 26.4 -- stand point to target, the same on every lane (full size, before BOOTH_SCALE); long, so the pool is most of the lane (Oct 31)
local FLOOR_T = 0.8 -- the lane's floor stands this far over the platform; the rim another 0.8

-- Alex's new map (Workspace.CannonMap, Oct 30) or the old one
local newMap = workspace:FindFirstChild(Config.Map.Root)
local lobbyPos, lobbySize
if newMap then
	lobbyPos, lobbySize = Config.Map.LobbyCenter, Config.Map.LobbySize
else
	local lobbyCf
	lobbyCf, lobbySize = workspace.map1b.StoneSkipMap.Lobby:GetBoundingBox()
	lobbyPos = lobbyCf.Position
end

-- floor height under a point (the map only, nothing we build; on the new map only its ground, never a palm or rock)
local floorParams = RaycastParams.new()
floorParams.FilterType = Enum.RaycastFilterType.Include
floorParams.FilterDescendantsInstances = { newMap or workspace.map1b }
if newMap then
	local ground = {}
	for _, p in ipairs(newMap:GetDescendants()) do
		if p:IsA("BasePart") and Config.Map.IsGround(p.Name) then
			table.insert(ground, p)
		end
	end
	floorParams.FilterDescendantsInstances = ground
end
local function floorAt(x, z, fallback)
	local hit = workspace:Raycast(Vector3.new(x, 200, z), Vector3.new(0, -400, 0), floorParams)
	return hit and hit.Position.Y or fallback
end
local floorY = floorAt(lobbyPos.X, lobbyPos.Z, lobbyPos.Y - lobbySize.Y / 2)

-- Stations sit in a row along the lobby's long (X) axis, firing towards the side wall
local fireDir = Vector3.new(0, 0, SIDE)
local rowZ = lobbyPos.Z + SIDE * 21 -- stand points, set back so the booth fronts clear the spawn and launch zone
-- booths stand side by side like Alex's pictures, the row centred in the lobby
-- booths are built full size, then each station is scaled down to BOOTH_SCALE so the row fits the lobby (Alex, Oct 30)
local BOOTH_SCALE = 0.8
-- spaced out with a walkway between booths like the Stone Skipping pads (Alex, Oct 30): the row now
-- runs from near the water's edge to where it used to end, by the side building at the far end
local ROW_END = lobbyPos.X - 10 + 15 * BOOTH_SCALE * 3.5 + 7 * BOOTH_SCALE -- far edge of the old row
local ROW_START = lobbyPos.X - lobbySize.X / 2 + 6
local spacing = (ROW_END - ROW_START - 14 * BOOTH_SCALE) / (#Config.Stations - 1)
local startX = ROW_START + 7 * BOOTH_SCALE
-- where booth i stands: { stand point, firing direction }
local function slot(i)
	return Vector3.new(startX + (i - 1) * spacing, floorY, rowZ), fireDir
end

if newMap then
	-- New map: six booths (Alex, Oct 30: "make like 5 or 6 so we can fit them better into the lobby") side by
	-- side in one block on the north side of the plaza, like the training lanes in his reference game
	-- ("put them into one spot and make them fit nicely like in the references"), all firing north towards
	-- the palisade, with a 2.5-stud strip of ground between neighbours. Booth 1 is at the east end, nearest
	-- the dock; the VIP booth is the west one. The block's middle is in the map file's units (Config.Map.At
	-- moves it out with the map); checked against every rock, palm and fence by tools/map/plan_check.py.
	-- Alex, Oct 30: "make the trainings a bit bigger, bring them close to the lobby, just a little".
	BOOTH_SCALE = 0.9
	-- the stand points moved 4 studs towards the plaza (Oct 31) so the longer lanes end where they did
	local MIDDLE, PITCH = Config.Map.At(-61, 0, -18.9), 14 * BOOTH_SCALE + 2.5 -- the middle stand point; booth width + gap
	fireDir = Vector3.new(0, 0, -1)
	local function x(i)
		return MIDDLE.X - (i - (#Config.Stations + 1) / 2) * PITCH
	end
	-- one floor height for the whole block, so the booths line up: the highest ground under any of them
	local blockY = -math.huge
	for i = 1, #Config.Stations do
		for _, z in ipairs({ MIDDLE.Z + 5, MIDDLE.Z, MIDDLE.Z - 12, MIDDLE.Z - 22 }) do
			blockY = math.max(blockY, floorAt(x(i), z, floorY))
		end
	end
	-- one open stud platform under the whole row and the walk-up in front of it (like Stone Skipping's
	-- lanes); the lanes stand on its top
	local PLAT_TOP = blockY + 0.35
	local halfW = 14 * BOOTH_SCALE / 2 + 2.2
	local x0, x1 = x(#Config.Stations) - halfW, x(1) + halfW
	local zBack = MIDDLE.Z - (TARGET_Z + 3.2) * BOOTH_SCALE - 1.2 -- clear of the rocks by the palisade
	local zFront = Config.Map.At(0, 0, -12.5).Z -- where the plank links from the plaza arrive
	local oldPlat = workspace:FindFirstChild("LanePlatform")
	if oldPlat then
		oldPlat:Destroy()
	end
	local plat = Instance.new("Folder")
	plat.Name = "LanePlatform"
	-- cool light stone, like a stone dock: it sets off the warm gold and orange lanes, which vanished into sand
	-- (Oct 31 critic; the reference's walkways contrast with every lane the same way)
	for _, layer in ipairs({ { 0.7, PLAT_TOP - 0.12, Color3.fromRGB(128, 134, 150) }, { 0, PLAT_TOP, Color3.fromRGB(184, 190, 202) } }) do
		local grow, top, color = layer[1], layer[2], layer[3]
		local p = Instance.new("Part")
		p.Name = grow > 0 and "Edge" or "Top"
		p.Anchored = true
		p.Material = Enum.Material.SmoothPlastic
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		p.Color = color
		p.Size = Vector3.new(x1 - x0 + grow * 2, 1.2, math.abs(zFront - zBack) + grow * 2)
		p.CFrame = CFrame.new((x0 + x1) / 2, top - 0.6, (zFront + zBack) / 2)
		p.Parent = plat
	end
	plat.Parent = workspace
	slot = function(i)
		return Vector3.new(x(i), PLAT_TOP, MIDDLE.Z), fireDir
	end
end

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

-- the target: a bullseye raft floating flat on the far end of the lane's pool, tipped back towards the
-- cannon so you see it from the stand pad (Oct 31: nothing tall stands in the lane, like Stone Skipping's
-- pools). cf sits on the water; its front (LookVector) points up and back at the cannon.
local function makeTarget(cf)
	local m = Instance.new("Model")
	m.Name = "Target"
	local rings = {
		{ 5.2, Color3.fromRGB(235, 60, 60) },
		{ 3.8, Color3.new(1, 1, 1) },
		{ 2.4, Color3.fromRGB(235, 60, 60) },
		{ 1.0, Color3.fromRGB(255, 210, 60) },
	}
	for i, r in ipairs(rings) do
		local disc = part({
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.3, r[1], r[1]),
			Color = r[2],
			Material = Enum.Material.SmoothPlastic,
			CanCollide = false,
			CFrame = cf * CFrame.new(0, 0, -0.08 * i) * CFrame.Angles(0, math.rad(90), 0),
			Parent = m,
		})
		disc.Name = "Ring"
	end
	-- invisible aim point; its front faces the cannon
	part({ Name = "Center", Size = Vector3.one * 0.5, Transparency = 1, CanCollide = false, CFrame = cf * CFrame.new(0, 0, -0.5), Parent = m })
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

-- Lane looks (Alex, Oct 31, from Stone Skipping's lanes): one base colour per station Id (GameConfig);
-- the floor is the base, the rim a darker shade, the centre track a lighter tint. Effects grow with the
-- tier: 1-2 plain, 3 glows, 4 glows and shines, 5 also sparkles, the VIP lane is black with neon.
local function rgb(r, g, b)
	return Color3.fromRGB(r, g, b)
end
local WHITE = rgb(245, 245, 250)
local function dark(c, a)
	return c:Lerp(Color3.new(0, 0, 0), a or 0.3)
end
local TIERS = {
	-- Water: the pool's colour. Like Stone Skipping's, the water stays watery (light cyan to blue) and leans
	-- towards the lane's hue only where that still reads as water: cyan in the orange and gold lanes, mint in
	-- the green one, violet in the black VIP lane (Oct 31: tinted yellow or orange water read as murky)
	[1] = { Base = rgb(60, 112, 225), Water = rgb(95, 175, 250) }, -- Starter: blue
	[2] = { Base = rgb(70, 200, 225), Water = rgb(110, 215, 245) }, -- Steel: ice
	[3] = { Base = rgb(245, 135, 35), Water = rgb(85, 195, 240), Glow = true }, -- Heavy: orange
	[4] = { Base = rgb(245, 192, 40), Water = rgb(85, 195, 240), Glow = true, Shine = true }, -- Golden: gold
	[5] = { Base = rgb(80, 205, 70), Water = rgb(90, 220, 180), Glow = true, Shine = true, Sparkle = true }, -- Plasma: toxic green
	[6] = { Base = rgb(255, 60, 230), Water = rgb(120, 60, 175), Glow = true, Sparkle = true, Black = true }, -- Dragon (VIP): black and neon pink
}
local function tierLook(id)
	local t = TIERS[id] or TIERS[1]
	local look = {
		Floor = t.Base,
		Rim = dark(t.Base, 0.35),
		Track = t.Water or t.Base:Lerp(WHITE, 0.55), -- the pool's water
		Bed = dark(t.Base, 0.4), -- the pool's floor under the water: dark, so the pool looks deep
		Pad = dark(t.Base, 0.18),
		Accent = t.Base, -- the glow colour (neon already brightens it, so the tier's own hue), also the client's shot colour
		Glow = t.Glow,
		Shine = t.Shine,
		Sparkle = t.Sparkle,
		Lanterns = t.Shine or t.Black, -- glowing lantern posts on the far corners of the top tiers
	}
	if t.Black then
		look.Floor, look.Rim, look.Pad = rgb(30, 24, 40), rgb(16, 12, 24), rgb(22, 16, 32)
		look.Bed = rgb(14, 10, 22)
		look.Accent = t.Base
		look.Neon = true
	end
	return look
end

-- one lane, the same for every tier: built around the stand point (standCf at the platform's top),
-- x right, y up, z forward towards the target. Only `look` changes between lanes.
-- What makes Stone Skipping's lanes read well (Oct 31 study, Build Playbooks/Lesson - Tiered Training Lanes):
-- a long, low lane that is mostly a pool of light water, a tiled stand pad at the near end, a brick rim in
-- the tier colour, and nothing tall inside it. So: a chunky brick rim, a strip of lane floor, a recessed
-- pool with see-through water over a darker bed, and a tiled pad the cannon sits on.
local POOL_START = 9 -- where the pool begins, just past the cannon's nose (full size)
local function makeBooth(standCf, width, look)
	local m = Instance.new("Model")
	m.Name = "Booth"
	local W = width
	local front, back = -5, TARGET_Z + 3.2
	local L = back - front
	local mid = (front + back) / 2
	local RIM, RIM_H = 1.6, 0.8 -- the raised rim's width and height over the floor
	local inner = W / 2 - RIM -- half the width inside the rims
	local poolHalf = inner -- the water fills the lane from rim to rim (Oct 31 critic: it has to read as a pool)
	local z0, z1 = POOL_START, back - RIM - 0.9 -- the pool's near and far ends
	local BED_T = FLOOR_T - 0.4 -- the pool's floor; the deck round it stands at FLOOR_T
	local function at(x, y, z)
		return standCf * CFrame.new(x, y, -z)
	end
	local function blk(name, size, x, yTop, z, color, collide)
		return part({ Name = name, Size = size, CFrame = at(x, yTop - size.Y / 2, z), Color = color, Material = Enum.Material.SmoothPlastic, CanCollide = collide == true, Parent = m })
	end
	local function glow(name, size, x, yTop, z)
		local p = blk(name, size, x, yTop, z, look.Accent)
		p.Material = Enum.Material.Neon
		p.CastShadow = false
		return p
	end
	local function shade(c, f)
		return Color3.new(math.min(c.R * f, 1), math.min(c.G * f, 1), math.min(c.B * f, 1))
	end

	-- the base slab (its top is the pool's bed) and the deck round the pool, all in the tier colour
	blk("Floor", Vector3.new(W, BED_T, L), 0, BED_T, mid, look.Bed, true)
	local deck = FLOOR_T - BED_T
	blk("Deck", Vector3.new(inner * 2, deck, z0 - front), 0, FLOOR_T, (front + z0) / 2, look.Floor, true) -- the near end
	blk("Deck", Vector3.new(inner * 2, deck, back - RIM - z1), 0, FLOOR_T, (z1 + back - RIM) / 2, look.Floor, true) -- the far end
	-- the water: see-through over the darker bed, glossy; named Water so the stud pass leaves it smooth
	local water = blk("Water", Vector3.new(poolHalf * 2, 0.2, z1 - z0), 0, FLOOR_T - 0.1, (z0 + z1) / 2, look.Track)
	water.Transparency = 0.15 -- bright like Stone Skipping's water; Glass over the bed read grey
	water.Reflectance = look.Shine and 0.3 or 0.2
	water.CastShadow = false

	-- two lily pads with a pink flower floating in every pool, like the reference's pools (never on the target)
	for k, spot in ipairs({ { -0.55, 0.22 }, { 0.6, 0.5 } }) do
		local x, z = spot[1] * poolHalf, z0 + (z1 - z0) * spot[2]
		local lily = part({ Name = "LilyPad", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.12, k == 1 and 1.8 or 1.4, k == 1 and 1.8 or 1.4), Color = rgb(95, 190, 80), Material = Enum.Material.SmoothPlastic, CanCollide = false, CastShadow = false, CFrame = at(x, FLOOR_T - 0.04, z) * CFrame.Angles(0, 0, math.rad(90)), Parent = m })
		part({ Name = "LilyFlower", Shape = Enum.PartType.Ball, Size = Vector3.one * 0.55, Color = rgb(255, 150, 195), Material = Enum.Material.SmoothPlastic, CanCollide = false, CastShadow = false, CFrame = at(x + 0.2, FLOOR_T + 0.15, z), Parent = m })
		lily.Anchored = true
	end

	-- the rim: bricks about 4 studs long in two shades, so it reads as built from blocks
	local function brickRow(len, alongZ, x, zc)
		local n = math.max(1, math.floor(len / 4 + 0.5))
		local each = len / n
		for k = 1, n do
			local off = -len / 2 + each * (k - 0.5)
			local size = alongZ and Vector3.new(RIM, RIM_H + deck, each - 0.06) or Vector3.new(each - 0.06, RIM_H + deck, RIM)
			local px, pz = alongZ and x or x + off, alongZ and zc + off or zc
			blk("Rim", size, px, FLOOR_T + RIM_H, pz, shade(look.Rim, k % 2 == 0 and 1.12 or 1), true)
		end
	end
	for _, sx in ipairs({ -1, 1 }) do
		brickRow(L, true, sx * (W / 2 - RIM / 2), mid)
	end
	brickRow(W - RIM * 2, false, 0, back - RIM / 2)
	blk("Lip", Vector3.new(W, 0.06, 0.5), 0, FLOOR_T + 0.03, front + 0.25, look.Rim) -- the open front edge, flush

	-- the stand pad: square tiles with thin gaps, from behind the stand point to the pool, under the cannon
	local padW, pz0, pz1 = inner * 2 - 1, -3.6, z0 - 0.4
	local nx, nz = math.max(1, math.floor(padW / 2.2 + 0.5)), math.max(1, math.floor((pz1 - pz0) / 2.2 + 0.5))
	local tw, tl = padW / nx, (pz1 - pz0) / nz
	for ix = 1, nx do
		for iz = 1, nz do
			blk("Tile", Vector3.new(tw - 0.14, PAD_UP + 0.05, tl - 0.14), -padW / 2 + tw * (ix - 0.5), FLOOR_T + PAD_UP, pz0 + tl * (iz - 0.5), shade(look.Pad, (ix + iz) % 2 == 0 and 1.08 or 1))
		end
	end
	blk("StartPad", Vector3.new(padW + 0.4, PAD_UP - 0.02, pz1 - pz0 + 0.4), 0, FLOOR_T + PAD_UP - 0.04, (pz0 + pz1) / 2, dark(look.Pad, 0.3)) -- the dark lines between tiles
	-- white L marks on the pad's four corners, like the reference's start pads
	for _, sx in ipairs({ -1, 1 }) do
		for _, sz in ipairs({ -1, 1 }) do
			local cx, cz = sx * (padW / 2 - 0.35), (pz0 + pz1) / 2 + sz * ((pz1 - pz0) / 2 - 0.35)
			blk("PadMark", Vector3.new(0.3, 0.04, 1.5), cx, FLOOR_T + PAD_UP + 0.04, cz - sz * 0.6, WHITE)
			blk("PadMark", Vector3.new(1.5, 0.04, 0.3), cx - sx * 0.6, FLOOR_T + PAD_UP + 0.04, cz, WHITE)
		end
	end

	if look.Glow then
		-- a neon line along the top inner edge of the rim
		for _, sx in ipairs({ -1, 1 }) do
			glow("Edge", Vector3.new(0.3, 0.08, L - RIM), sx * (inner + 0.15), FLOOR_T + RIM_H + 0.04, mid - RIM / 2)
		end
		glow("Edge", Vector3.new(inner * 2, 0.08, 0.3), 0, FLOOR_T + RIM_H + 0.04, back - RIM + 0.15)
	end
	if look.Neon then
		-- the black lane: neon round the pool and the stand pad
		for _, sx in ipairs({ -1, 1 }) do
			glow("PoolLine", Vector3.new(0.25, 0.1, z1 - z0), sx * (poolHalf - 0.13), FLOOR_T - 0.04, (z0 + z1) / 2) -- along the rim, on the water
			glow("PadLine", Vector3.new(0.25, 0.14, pz1 - pz0), sx * (padW / 2 + 0.13), FLOOR_T + PAD_UP + 0.02, (pz0 + pz1) / 2)
		end
		glow("PoolLine", Vector3.new(poolHalf * 2 + 0.5, 0.1, 0.25), 0, FLOOR_T + 0.06, z1 + 0.13)
		glow("PadLine", Vector3.new(padW + 0.5, 0.14, 0.25), 0, FLOOR_T + PAD_UP + 0.02, pz0 - 0.13)
	end
	if look.Lanterns then
		-- lantern posts on the far corners: a post in the rim's shade and a glowing lamp in the tier colour
		for _, sx in ipairs({ -1, 1 }) do
			local x, z = sx * (W / 2 - RIM / 2), back - RIM / 2
			blk("LanternPost", Vector3.new(0.5, 2.4, 0.5), x, FLOOR_T + RIM_H + 2.4, z, dark(look.Rim, 0.2))
			local lamp = blk("Lantern", Vector3.new(0.9, 0.9, 0.9), x, FLOOR_T + RIM_H + 3.3, z, look.Accent)
			lamp.Material = Enum.Material.Neon
			lamp.CastShadow = false
			blk("LanternCap", Vector3.new(1.1, 0.25, 1.1), x, FLOOR_T + RIM_H + 3.55, z, dark(look.Rim, 0.2))
		end
	end
	if look.Sparkle then
		-- slow sparkles rising off the water (Roblox's own sparkle picture; a soft twinkle, never a flash)
		local e = Instance.new("ParticleEmitter")
		e.Name = "Sparkles"
		e.Color = ColorSequence.new(look.Accent:Lerp(WHITE, 0.4))
		e.LightEmission = 1
		e.Rate = 6
		e.Lifetime = NumberRange.new(1, 1.6)
		e.Speed = NumberRange.new(1, 2.2)
		e.SpreadAngle = Vector2.new(15, 15)
		e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.7), NumberSequenceKeypoint.new(1, 0) })
		e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) })
		e.EmissionDirection = Enum.NormalId.Top
		e.Parent = water
	end
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
local boothWidth = LANE_W

for i, info in ipairs(order) do
	local station = Instance.new("Model")
	station.Name = "Station_" .. info.Id
	station:SetAttribute("StationId", info.Id)

	local standPos, fireDir = slot(i)
	local laneBase = standPos.Y -- the platform's top; the lane's floor is FLOOR_T over it
	local baseCf = CFrame.lookAt(standPos, standPos + fireDir)
	standPos += Vector3.new(0, FLOOR_T, 0)
	-- built at full size around this point, scaled to BOOTH_SCALE below
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
	local look = tierLook(info.Id)
	local floorY = standPos.Y -- this lane's floor top
	-- the cannon sits low on the stand pad's tiles, its nose at the pool (no plinth: nothing tall in the lane)
	local cannonPos = standPos + fireDir * (POOL_START - 0.6 - size.Z / 2)
	-- imported cannons point their barrel along +Z, so face +Z at the target
	cannon:PivotTo(CFrame.lookAt(cannonPos, cannonPos - fireDir))
	local cf, sz = cannon:GetBoundingBox()
	cannon:PivotTo(cannon:GetPivot() + Vector3.new(0, floorY + PAD_UP - (cf.Position.Y - sz.Y / 2), 0))
	cannon.Parent = station

	local muzzlePos = cannonPos + fireDir * (size.Z / 2) + Vector3.new(0, floorY + PAD_UP + size.Y * 0.62 - cannonPos.Y, 0)
	part({ Name = "Muzzle", Size = Vector3.one * 0.5, Transparency = 1, CanCollide = false, CanTouch = false, CanQuery = false, CFrame = CFrame.lookAt(muzzlePos, muzzlePos + fireDir), Parent = station })

	-- the target floats on the far end of the pool, at the same spot on every lane, leaning back 25 degrees
	-- so it faces the cannon; its near edge rests on the water
	local TILT = math.rad(25)
	local targetPos = Vector3.new(standPos.X, floorY - 0.1 + 2.6 * math.sin(TILT) + 0.1, standPos.Z) + fireDir * (TARGET_Z - 2.6)
	local face = (Vector3.yAxis * math.cos(TILT) - fireDir * math.sin(TILT)).Unit
	local target = makeTarget(CFrame.lookAt(targetPos, targetPos + face))
	-- the same target on every lane: tier colour, white, tier colour and a gold bullseye (glowing on glow lanes)
	local rings = { look.Floor, WHITE, look.Floor, rgb(255, 215, 70) }
	local ring = 0
	for _, d in ipairs(target:GetChildren()) do
		if d.Name == "Ring" then
			ring += 1
			d.Color = rings[ring] or d.Color
			d.Material = (ring == #rings and (look.Glow or look.Neon)) and Enum.Material.Neon or Enum.Material.SmoothPlastic
		end
	end
	target.Parent = station
	makeBooth(baseCf, boothWidth, look).Parent = station

	-- the lane's glow colour, used by the client for its shots and hit effects
	station:SetAttribute("Accent", look.Accent)
	station.PrimaryPart = pad
	station:ScaleTo(BOOTH_SCALE)
	-- scaling pulls everything towards the pad: stand the lane back on the platform
	local floorPart = station.Booth:FindFirstChild("Floor")
	local bottom = floorPart.Position.Y - floorPart.Size.Y / 2
	station:PivotTo(station:GetPivot() - Vector3.new(0, bottom - laneBase, 0))
	station.Parent = folder
end
folder.Parent = workspace

-- Launch from the start of the water (Alex, Oct 30): your cannon stands at the lobby's
-- water edge, pointing down the long map, and the Launch Zone is right behind it so you
-- walk up to your cannon. LaunchPoint is where everyone's ball leaves from.
local dirL = Config.LAUNCH_DIRECTION.Unit
local edge = lobbyPos + dirL * (math.abs(dirL.X) * lobbySize.X / 2 + math.abs(dirL.Z) * lobbySize.Z / 2)
local trackZ = lobbyPos.Z -- the middle of the water strip
local cannonSpot = Vector3.new(edge.X, floorY, trackZ) - dirL * 8 -- your cannon's feet, nose at the water
if newMap then
	-- the end of the launch dock, nose over the river
	local d = Config.Map.DockEnd
	trackZ = d.Z
	cannonSpot = Vector3.new(d.X, floorAt(d.X, d.Z, d.Y), d.Z)
	floorY = cannonSpot.Y
end
local spotPart = workspace:FindFirstChild("MyCannonSpot") or part({ Name = "MyCannonSpot" })
spotPart.Size = Vector3.new(1, 0.2, 1)
spotPart.Transparency = 1
spotPart.CanCollide = false
spotPart.CanQuery = false
spotPart.CanTouch = false
spotPart.CFrame = CFrame.lookAt(cannonSpot, cannonSpot + dirL)
spotPart.Parent = workspace
local lp = workspace:FindFirstChild("LaunchPoint") or part({ Name = "LaunchPoint" })
lp.Size = Vector3.new(6, 1, 6)
lp.Transparency = 1
lp.CanCollide = false
lp.Position = cannonSpot + dirL * 8 + Vector3.new(0, 6, 0)
lp.Parent = workspace
local oldPrompt = lp:FindFirstChildOfClass("ProximityPrompt")
if oldPrompt then
	oldPrompt:Destroy()
end

-- Launch Zone: right behind your cannon; walk in and it fires you (like Stone Skipping's Throw Zone)
local old = workspace:FindFirstChild("LaunchZone")
if old then
	old:Destroy()
end
local zonePos = Vector3.new(cannonSpot.X, floorY + 0.1, trackZ) - dirL * (newMap and 11 or 17)
-- invisible now: no yellow floor (Alex, Oct 30); standing in it shows the LAUNCH button
local zone = part({
	Name = "LaunchZone",
	Size = newMap and Vector3.new(8, 0.2, 10 * Config.Map.Scale) or Vector3.new(16, 0.2, 26), -- new map: the dock is 11 wide in the file
	CFrame = CFrame.new(zonePos),
	Color = Color3.fromRGB(255, 200, 40),
	Transparency = 1,
	CanCollide = false,
	Parent = workspace,
})
local label = Instance.new("TextLabel")
label.BackgroundTransparency = 1
label.Size = UDim2.fromScale(1, 1)
label.Font = Enum.Font.FredokaOne
label.TextScaled = true
label.TextColor3 = Color3.new(1, 1, 1)
local stroke = Instance.new("UIStroke")
stroke.Thickness = 4
stroke.Color = Color3.fromRGB(60, 30, 90)
stroke.Parent = label
local board = Instance.new("BillboardGui")
board.Size = UDim2.fromOffset(220, 50)
board.StudsOffset = Vector3.new(0, 3, 0) -- under the cannon's name tag, not on top of it
board.LightInfluence = 0
board.MaxDistance = 250
board.Parent = zone
local boardText = label:Clone()
boardText.Rotation = 0
boardText.Text = "LAUNCH ZONE" -- stand here and the LAUNCH button pops up (LaunchButton.lua)
boardText.Parent = board

-- Spawn in the lobby, a short walk behind the Launch Zone, facing your cannon and the water
local spawn = workspace:FindFirstChildOfClass("SpawnLocation")
if spawn then
	local p = Vector3.new(zonePos.X, floorY + 0.5, trackZ) - dirL * 30
	if newMap then
		-- on the compass plaza, facing the dock
		local sp = Config.Map.Spawn
		p = Vector3.new(sp.X, floorAt(sp.X, sp.Z, sp.Y) + 0.5, sp.Z)
	end
	spawn.CFrame = CFrame.lookAt(p, p + dirL)
	spawn.Anchored = true
end

print("[BuildWorld1] Built " .. #Config.Stations .. " stations")
