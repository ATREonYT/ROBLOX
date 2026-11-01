--[[
	BuildWorld1  (run once in Studio's Command Bar, Edit mode)

	Builds the training lanes (5 + 1 gamepass, GameConfig), like Stone Skipping's (Alex, Oct 31: one lane
	model cloned for every tier; the whole lane in the tier's colour, the floor the tier colour, a darker
	raised rim and a lighter centre track; no ropes or posts; plain low tiers, then glow, then sparkles and
	shine, the last one black with neon; side by side facing you). Every lane is the same rectangle: only
	its colours, effects and the tier's own cannon change. On the new map they stand on one open stud
	platform. Run BuildRebirthSigns (one label per lane) and BuildCartoonyMap (the studs) after it. It also places the Grand Cannon LaunchPoint and Launch Zone, and
	moves the SpawnLocation into the lobby.
	Alex, Oct 31: "make it seem more buyable ... we want to make money". So the lanes grew with the 2x map,
	every cannon stands on a display turntable (a glowing ring on the glow tiers), the gamepass lane is the
	showcase, the fanciest of all (a rainbow brick rim on gold round a black lane, rainbow sparkles, lanterns on all four
	corners, its Robux price on its label; Alex: "we dont do the VIP thing around here", so no VIP sign), and a
	"2x POWER" board stands by the first lane (Workspace.TrainingShop; its prompt opens the same purchase
	as the Shop, "Coming soon!" while the pass id is 0).
	Safe to re-run: it deletes and rebuilds Workspace.TrainingStations and Workspace.TrainingShop.

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
	-- Oct 31: the map grew to 2x and the lanes looked like toys on it, so they grew too (0.9 to 1.25), and
	-- the block moved 6 file units east so the bigger VIP lane clears the west palisade.
	BOOTH_SCALE = 1.25
	-- the stand points moved 4 studs towards the plaza (Oct 31) so the longer lanes end where they did
	local MIDDLE, PITCH = Config.Map.At(-55, 0, -18.9), 14 * BOOTH_SCALE + 2.5 -- the middle stand point; booth width + gap
	fireDir = Vector3.new(0, 0, -1)
	local function x(i)
		return MIDDLE.X - (i - (#Config.Stations + 1) / 2) * PITCH
	end
	-- one floor height for the whole block, so the booths line up: the highest ground under any of them
	local blockY = -math.huge
	for i = 1, #Config.Stations do
		for _, z in ipairs({ MIDDLE.Z + 6, MIDDLE.Z, MIDDLE.Z - 12, MIDDLE.Z - 24, MIDDLE.Z - 36 }) do
			blockY = math.max(blockY, floorAt(x(i), z, floorY))
		end
	end
	-- the lanes stand straight on the island's ground (Alex, Oct 31: "removing the grey blocks which they are
	-- on"); each lane has its own footing in its colours down into the ground, so none floats where the
	-- ground dips. An earlier version built a stud platform (LanePlatform) under the row; it is removed.
	local PLAT_TOP = blockY + 0.1
	local oldPlat = workspace:FindFirstChild("LanePlatform")
	if oldPlat then
		oldPlat:Destroy()
	end
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
		req = "GAMEPASS"
	elseif info.Rebirths > 0 then
		req = "Requires " .. info.Rebirths .. " Rebirths"
	else
		req = "FREE"
	end
	line(req, 0.72, 0.28, info.Pass and Color3.fromRGB(255, 200, 60) or Color3.fromRGB(140, 255, 150))
	return sign
end

-- Lane looks (Alex, Oct 31: "I really like these designs ... this is the style I am aiming at ... I want them to
-- look like they have life, but also not too crazy ... especially the gamepass ones will look better than the
-- plain ones"; his treadmill reference sheets, Build Playbooks/23 Training Lane Style Guide). Our own build in
-- that style, not a copy: every lane is a chunky dark voxel body with neon along its edges, glowing corner
-- blocks, a moving belt where the pool was and a console at the far end facing the stand pad, in ONE colour per
-- lane plus white. Free lanes stay clean and simple (the colour tells them apart). The gamepass lane also gets a
-- theme: a shape on its console, ground spill round its base, one moving prop and its own floating bits, so it
-- wins by shape and life, not by being brighter. The motion (belt, the neon's slow breathing, the turning prop)
-- is LaneMotion's, one client script for every lane. Nothing ever flashes.
local function rgb(r, g, b)
	return Color3.fromRGB(r, g, b)
end
local WHITE = rgb(245, 245, 250)
local function dark(c, a)
	return c:Lerp(Color3.new(0, 0, 0), a or 0.3)
end
local BODY = rgb(30, 34, 45) -- the dark body every lane shares
local STUDS = "rbxassetid://18878365966" -- the classic stud picture already in the game (BuildCartoonyMap's)
local TIERS = {
	[1] = { Neon = rgb(60, 150, 255) }, -- Starter: blue
	[2] = { Neon = rgb(90, 230, 255) }, -- Steel: ice
	[3] = { Neon = rgb(255, 140, 40) }, -- Heavy: orange
	[4] = { Neon = rgb(255, 205, 60) }, -- Golden: gold
	[5] = { Neon = rgb(80, 240, 110), Motes = true }, -- Plasma: green, with a few slow sparkles over its belt
	-- Dragon (the gamepass lane): the Void theme, purple and pink-white like its purple and pink cannon: a dark
	-- portal with a turning spiral on its console, dark rubble with star specks, rising purple motes. It still
	-- stands 1.2 studs higher on two steps. No VIP wording anywhere ("we dont do the VIP thing").
	[6] = { Neon = rgb(160, 80, 255), Second = rgb(255, 205, 250), Theme = "Void", Raise = 1.2 },
}
local function tierLook(id)
	local t = TIERS[id] or TIERS[1]
	local body = t.Theme and rgb(28, 23, 40) or BODY -- a themed lane's body leans a little to its colour
	return {
		Accent = t.Neon, -- every neon part; also the client's shot colour for this lane
		Tube = dark(t.Neon, 0.12), -- the long neon tubes, a touch deeper so they stay coloured instead of white-hot
		Second = t.Second or WHITE, -- the "plus white": corner lights, handle ends, the portal's heart
		Body = body,
		Rim = body:Lerp(WHITE, 0.05),
		Frame = t.Theme and rgb(86, 68, 124) or rgb(150, 156, 170), -- the light-grey caps, corner frames and posts
		Footing = dark(body, 0.3),
		Deck = dark(body, 0.2), -- near-black, so the neon carries the colour
		Pad = body:Lerp(WHITE, 0.07),
		PadAlt = body:Lerp(t.Neon, 0.07),
		Belt = rgb(15, 17, 23),
		Floor = t.Neon, -- the target's coloured rings
		Glow = true,
		Theme = t.Theme,
		Motes = t.Motes,
		Raise = t.Raise,
		Premium = t.Theme ~= nil,
		Breathe = t.Theme and 2.5 or 3, -- seconds for one slow glow cycle
	}
end

-- one lane, the same build for every tier: built around the stand point (standCf at the platform's top),
-- x right, y up, z forward towards the target. Only `look` (and the gamepass theme) changes between lanes.
-- The layout is still Stone Skipping's (Build Playbooks/Lesson - Tiered Training Lanes): long and low, a tiled
-- stand pad at the near end, a rim, the target at the far end, nothing tall between the cannon and the target.
local POOL_START = 9 -- where the belt begins, just past the cannon's nose (full size; the pool's old start)
local function makeBooth(standCf, width, look, info)
	local m = Instance.new("Model")
	m.Name = "Booth"
	m:SetAttribute("BreathePeriod", look.Breathe)
	local W = width
	local front, back = -5, TARGET_Z + 3.2
	local L = back - front
	local mid = (front + back) / 2
	local RIM, RIM_H = 1.6, 1.3 -- the rails' width and height over the floor: chunky, like the treadmills' sides
	local inner = W / 2 - RIM -- half the width inside the rims
	local z0, z1 = POOL_START, back - RIM - 0.9 -- the belt's near and far ends
	local BED_T = FLOOR_T - 0.4
	local deck = FLOOR_T - BED_T
	local function at(x, y, z)
		return standCf * CFrame.new(x, y, -z)
	end
	local function blk(name, size, x, yTop, z, color, collide)
		return part({ Name = name, Size = size, CFrame = at(x, yTop - size.Y / 2, z), Color = color, Material = Enum.Material.SmoothPlastic, CanCollide = collide == true, Parent = m })
	end
	-- a neon piece: never collides or blocks clicks, and LaneMotion lets it breathe slowly
	local function glow(name, size, x, yTop, z, color)
		local p = blk(name, size, x, yTop, z, color or look.Accent)
		p.Material = Enum.Material.Neon
		p.CastShadow = false
		p.CanQuery = false
		p.CanTouch = false
		p:SetAttribute("Breathe", true)
		return p
	end
	local function shade(c, f)
		return Color3.new(math.min(c.R * f, 1), math.min(c.G * f, 1), math.min(c.B * f, 1))
	end
	local function deco(p) -- decoration: no collisions, clicks or touches
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		return p
	end

	-- the footing: the lane's own dark base reaching down into the ground, with a step at the open front
	blk("Footing", Vector3.new(W, 3, L + 1.4), 0, 0, mid - 0.7, look.Footing, true)
	local raise = look.Raise or 0 -- a raised lane: the ground is this far under its base, so two steps lead up
	blk("Step", Vector3.new(W - RIM * 2, FLOOR_T / 2 + raise, 1.2), 0, FLOOR_T / 2, front - 0.6, look.Frame, true)
	glow("StepLight", Vector3.new(W - RIM * 2, 0.08, 0.14), 0, FLOOR_T / 2 + 0.02, front - 1.13)
	if raise > 0 then
		blk("Step", Vector3.new(W - RIM * 2 + 1, raise / 2 + 1, 1.4), 0, -raise / 2, front - 1.9, look.Frame, true)
		glow("StepLight", Vector3.new(W - RIM * 2 + 1, 0.08, 0.14), 0, -raise / 2 + 0.02, front - 2.53)
		blk("Footing", Vector3.new(W + 1.2, raise + 1, L + 2), 0, -0.05, mid - 0.7, look.Footing, true)
	end

	-- the base slab and the decks at both ends
	blk("Floor", Vector3.new(W, BED_T, L), 0, BED_T, mid, dark(look.Body, 0.25), true)
	blk("Deck", Vector3.new(inner * 2, deck, z0 - front), 0, FLOOR_T, (front + z0) / 2, look.Deck, true) -- the near end
	blk("Deck", Vector3.new(inner * 2, deck, back - RIM - z1), 0, FLOOR_T, (z1 + back - RIM) / 2, look.Deck, true) -- the far end
	-- the belt (where the pool was): dark, with the game's stud picture faintly in the lane colour on top, which
	-- LaneMotion scrolls towards the target, so the lane reads as a running treadmill; rollers at both ends
	local belt = blk("Belt", Vector3.new(inner * 2, deck - 0.06, z1 - z0), 0, FLOOR_T - 0.06, (z0 + z1) / 2, look.Belt, true)
	belt:SetAttribute("BeltSpeed", look.Premium and 2.5 or 2)
	local tex = Instance.new("Texture")
	tex.Name = "BeltStuds"
	tex.Texture = STUDS
	tex.Face = Enum.NormalId.Top
	tex.StudsPerTileU = 2
	tex.StudsPerTileV = 2
	tex.Color3 = look.Accent
	tex.Transparency = 0.55
	tex.Parent = belt
	for _, z in ipairs({ z0, z1 }) do
		deco(part({ Name = "Roller", Shape = Enum.PartType.Cylinder, Size = Vector3.new(inner * 2 - 0.1, 0.8, 0.8), Color = look.Rim, Material = Enum.Material.SmoothPlastic, CFrame = at(0, FLOOR_T - 0.36, z), Parent = m }))
	end
	for _, sx in ipairs({ -1, 1 }) do
		glow("BeltLine", Vector3.new(0.2, 0.08, z1 - z0), sx * (inner - 0.1), FLOOR_T + 0.02, (z0 + z1) / 2)
	end

	-- the rails: chunky dark bricks about 4 studs long in two shades, so they read as built from blocks, the
	-- nearest brick of each side a light-grey cap; along each side's outer face a thick neon tube set into a dark
	-- groove, broken at every brick, and a long tube down the inner face next to the belt
	local function brickRow(len, alongZ, x, zc, sx)
		local n = math.max(1, math.floor(len / 4 + 0.5))
		local each = len / n
		for k = 1, n do
			local off = -len / 2 + each * (k - 0.5)
			local size = alongZ and Vector3.new(RIM, RIM_H + deck, each - 0.06) or Vector3.new(each - 0.06, RIM_H + deck, RIM)
			local px, pz = alongZ and x or x + off, alongZ and zc + off or zc
			local color = (alongZ and k == 1) and look.Frame or (k % 2 == 0 and shade(look.Rim, 1.18) or look.Rim)
			blk("Rim", size, px, FLOOR_T + RIM_H, pz, color, true)
			if alongZ and k > 1 then
				local ox = x + sx * (RIM / 2)
				deco(blk("Groove", Vector3.new(0.12, 0.62, each - 0.4), ox + sx * 0.04, FLOOR_T + 0.86, pz, dark(look.Body, 0.6)))
				glow("Tube", Vector3.new(0.2, 0.36, each - 0.7), ox + sx * 0.08, FLOOR_T + 0.73, pz, look.Tube)
			end
		end
	end
	for _, sx in ipairs({ -1, 1 }) do
		brickRow(L, true, sx * (W / 2 - RIM / 2), mid, sx)
		glow("Edge", Vector3.new(0.2, 0.3, back - RIM - front - 4), sx * (inner - 0.07), FLOOR_T + RIM_H - 0.12, (front + 2 + back - RIM - 2) / 2, look.Tube)
	end
	brickRow(W - RIM * 2, false, 0, back - RIM / 2)
	blk("Lip", Vector3.new(W, 0.06, 0.5), 0, FLOOR_T + 0.03, front + 0.25, look.Rim) -- the open front edge, flush
	-- big corner cubes at all four corners: a light-grey frame round a glowing panel on each open face and the top
	local CB = 2.4
	local cTop = FLOOR_T + RIM_H + 0.7
	local cBot = -raise
	local cH = cTop - cBot
	for _, sx in ipairs({ -1, 1 }) do
		for _, sz in ipairs({ -1, 1 }) do
			local cx, cz = sx * (W / 2 - CB / 2 + 0.25), sz < 0 and front + CB / 2 or back - CB / 2 + 0.25
			blk("Corner", Vector3.new(CB, cH, CB), cx, cTop, cz, look.Frame, true)
			local light = look.Accent:Lerp(look.Second, 0.15)
			local pH, pW = cH - 0.7, CB - 0.6
			glow("CornerLight", Vector3.new(0.08, pH, pW), cx + sx * (CB / 2 + 0.03), cTop - 0.35, cz, light)
			glow("CornerLight", Vector3.new(pW, pH, 0.08), cx, cTop - 0.35, cz + sz * (CB / 2 + 0.03), light)
			glow("CornerLight", Vector3.new(pW, 0.06, pW), cx, cTop + 0.03, cz, light)
		end
	end

	-- the stand pad: square tiles with thin gaps, from behind the stand point to the belt, under the cannon
	local padW, pz0, pz1 = inner * 2 - 1, -3.6, z0 - 0.4
	local nx, nz = math.max(1, math.floor(padW / 2.2 + 0.5)), math.max(1, math.floor((pz1 - pz0) / 2.2 + 0.5))
	local tw, tl = padW / nx, (pz1 - pz0) / nz
	for ix = 1, nx do
		for iz = 1, nz do
			local even = (ix + iz) % 2 == 0
			blk("Tile", Vector3.new(tw - 0.14, PAD_UP + 0.05, tl - 0.14), -padW / 2 + tw * (ix - 0.5), FLOOR_T + PAD_UP, pz0 + tl * (iz - 0.5), even and look.PadAlt or look.Pad)
		end
	end
	blk("StartPad", Vector3.new(padW + 0.4, PAD_UP - 0.02, pz1 - pz0 + 0.4), 0, FLOOR_T + PAD_UP - 0.04, (pz0 + pz1) / 2, dark(look.Pad, 0.4)) -- the dark lines between tiles
	for _, sx in ipairs({ -1, 1 }) do
		for _, sz in ipairs({ -1, 1 }) do
			local cx, cz = sx * (padW / 2 - 0.35), (pz0 + pz1) / 2 + sz * ((pz1 - pz0) / 2 - 0.35)
			blk("PadMark", Vector3.new(0.3, 0.04, 1.5), cx, FLOOR_T + PAD_UP + 0.04, cz - sz * 0.6, WHITE)
			blk("PadMark", Vector3.new(1.5, 0.04, 0.3), cx - sx * 0.6, FLOOR_T + PAD_UP + 0.04, cz, WHITE)
		end
		glow("PadLine", Vector3.new(0.2, 0.1, pz1 - pz0 + 0.4), sx * (padW / 2 + 0.3), FLOOR_T + PAD_UP, (pz0 + pz1) / 2)
	end
	glow("PadLine", Vector3.new(padW + 0.8, 0.1, 0.2), 0, FLOOR_T + PAD_UP, pz0 - 0.3)

	-- the console at the far end, facing the stand pad like the treadmills' (low, so the lane's label floats
	-- clear above it): a dark hood across the lane, then the screen, or on the gamepass lane its theme's shape
	local cz = back - 1.3
	local hoodTop = FLOOR_T + 2 -- kept low whatever the rails do, so the lane's label floats clear above
	blk("ConsoleBase", Vector3.new(W - CB * 2 + 0.4, 2, 2.6), 0, hoodTop, cz, look.Body, true)
	glow("ConsoleEdge", Vector3.new(W - CB * 2, 0.16, 0.16), 0, hoodTop - 0.02, cz - 1.33, look.Tube)
	local lamp -- the console's light (the client swells it a little on a hit, at most once a second)
	if not look.Theme then
		-- the screen: the lane's power per shot, in its colour, framed in neon, on a dark box with two posts
		-- whose handle ends glow white
		blk("ConsoleBox", Vector3.new(7, 3.6, 1.0), 0, hoodTop + 3.6, cz + 0.3, look.Body, true)
		local sz = cz + 0.3 - 0.54
		local screen = blk("ConsoleScreen", Vector3.new(6, 2.6, 0.08), 0, hoodTop + 3.2, sz, rgb(8, 10, 18))
		deco(screen)
		local gui = Instance.new("SurfaceGui")
		gui.Face = Enum.NormalId.Back -- the side facing the stand pad
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 40
		gui.LightInfluence = 0
		gui.Parent = screen
		local function line(text, y, h)
			local t = Instance.new("TextLabel")
			t.BackgroundTransparency = 1
			t.Position = UDim2.fromScale(0.06, y)
			t.Size = UDim2.fromScale(0.88, h)
			t.Font = Enum.Font.FredokaOne
			t.TextScaled = true
			t.Text = text
			t.TextColor3 = look.Accent:Lerp(WHITE, 0.25)
			local s = Instance.new("UIStroke")
			s.Thickness = 2
			s.Color = dark(look.Accent, 0.6)
			s.Parent = t
			t.Parent = gui
		end
		line("+" .. Config.Format(info.Gain), 0.08, 0.6)
		line("POWER", 0.66, 0.26)
		for _, y in ipairs({ hoodTop + 3.42, hoodTop + 0.72 }) do
			glow("ScreenFrame", Vector3.new(6.3, 0.14, 0.14), 0, y, sz - 0.04)
		end
		for _, sx in ipairs({ -1, 1 }) do
			glow("ScreenFrame", Vector3.new(0.14, 2.84, 0.14), sx * 3.08, hoodTop + 3.42, sz - 0.04)
			local px = sx * 3.9
			blk("ConsolePost", Vector3.new(0.8, 4.4, 0.8), px, hoodTop + 4.4, cz + 0.3, look.Frame, true)
			deco(blk("ConsoleArm", Vector3.new(0.5, 0.5, 2.4), px, hoodTop + 4.1, cz - 1.1, look.Frame))
			glow("ArmLight", Vector3.new(0.56, 0.56, 0.3), px, hoodTop + 4.13, cz - 2.4, look.Second)
		end
		lamp = glow("Glow", Vector3.new(6, 0.16, 0.12), 0, hoodTop + 0.5, sz - 0.04)
	elseif look.Theme == "Void" then
		-- a dark portal of blocks standing on the hood, a dark hole inside it and a glowing spiral that turns
		-- slowly (one turn every 9 seconds), with a pink-white heart; the spiral, its dashes and the heart are in
		-- the Spin model, which LaneMotion turns round the Axis part
		local R = 3.1
		local cy = hoodTop + 0.45 + R
		local centre = at(0, cy, cz + 0.2)
		local N = 18
		for k = 1, N do
			local a = (k - 0.5) / N * math.pi * 2
			part({ Name = "PortalRing", Size = Vector3.new(0.95, 2 * math.pi * R / N * 1.1, 1.2), Color = k % 2 == 0 and look.Rim or shade(look.Rim, 1.6), Material = Enum.Material.SmoothPlastic,
				CanCollide = false, CFrame = centre * CFrame.Angles(0, 0, a) * CFrame.new(R, 0, 0), Parent = m })
			-- a thin neon line round the outside and the inside of the ring, so its shape reads from afar
			for _, rr in ipairs({ R + 0.5, R - 0.5 }) do
				glow("PortalEdge", Vector3.new(0.14, 2 * math.pi * rr / N * 1.05, 0.14), 0, 0, 0).CFrame = centre * CFrame.Angles(0, 0, a) * CFrame.new(rr, 0, 0.62)
			end
		end
		deco(part({ Name = "PortalHole", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.2, (R - 0.3) * 2, (R - 0.3) * 2), Color = rgb(12, 6, 24), Material = Enum.Material.SmoothPlastic,
			CFrame = centre * CFrame.new(0, 0, -0.3) * CFrame.Angles(0, math.rad(90), 0), Parent = m })) -- behind the spiral (local +Z faces the pad)
		deco(blk("PortalFoot", Vector3.new(2.6, 0.7, 1.4), 0, hoodTop + 0.6, cz + 0.2, look.Rim))
		local spin = Instance.new("Model")
		spin.Name = "Spin"
		spin:SetAttribute("SpinPeriod", 9)
		local axis = part({ Name = "Axis", Size = Vector3.one * 0.2, Transparency = 1, CanCollide = false, CanQuery = false, CanTouch = false, CFrame = centre, Parent = spin })
		axis:SetAttribute("Axis", true)
		local function spinGlow(name, size, cf, color)
			local p = part({ Name = name, Size = size, Color = color, Material = Enum.Material.Neon, CastShadow = false, CanCollide = false, CanQuery = false, CanTouch = false, CFrame = cf, Parent = spin })
			p:SetAttribute("Breathe", true)
			return p
		end
		for k = 1, 12 do -- dashes just inside the ring
			local a = k / 12 * math.pi * 2
			spinGlow("PortalDash", Vector3.new(0.28, 0.95, 0.3), centre * CFrame.Angles(0, 0, a) * CFrame.new(R - 0.85, 0, 0.1), look.Accent)
		end
		local STEPS = 26
		for k = 1, STEPS do -- the spiral, pink-white at the heart to purple at the edge
			local t = k / STEPS
			local a = t * math.pi * 3.4
			local r = 0.55 + (R - 1.45) * t
			local s = 0.5 - 0.2 * t
			spinGlow("Spiral", Vector3.new(s, s, 0.25), centre * CFrame.Angles(0, 0, a) * CFrame.new(r, 0, 0.05), look.Second:Lerp(look.Accent, t))
		end
		spinGlow("Heart", Vector3.new(0.9, 0.9, 0.4), centre * CFrame.new(0, 0, 0.2) * CFrame.Angles(0, 0, math.rad(45)), look.Second)
		for _, a0 in ipairs({ 0.35, 0.35 + math.pi }) do -- two short arcs just outside the ring, orbiting with the spiral
			for k = 0, 5 do
				local a = a0 + k * 0.17
				spinGlow("Orbit", Vector3.new(0.3, 0.42, 0.3), centre * CFrame.Angles(0, 0, a) * CFrame.new(R + 1.05, 0, 0.3), look.Accent:Lerp(look.Second, k / 6))
			end
		end
		spin.Parent = m
		-- still crystal shards floating round the portal's sides and foot (pink-white and purple voxels on end)
		for k, a in ipairs({ -0.15, -0.55, -1.0, math.pi + 0.15, math.pi + 0.55, math.pi + 1.0, 0.75, math.pi - 0.75 }) do
			local r = R + 1.6 + (k % 3) * 0.35
			local s = k % 2 == 0 and 0.36 or 0.5
			local shard = glow("Shard", Vector3.new(s, s * 1.6, s), 0, 0, 0, k % 2 == 0 and look.Second or look.Accent)
			shard.CFrame = centre * CFrame.Angles(0, 0, a) * CFrame.new(r, 0, 0.4) * CFrame.Angles(0, 0.6, -a + 0.4)
			shard:SetAttribute("Breathe", nil)
		end
		lamp = part({ Name = "Glow", Size = Vector3.one * 0.3, Transparency = 1, CanCollide = false, CanQuery = false, CanTouch = false, CFrame = centre * CFrame.new(0, 0, 0.8), Parent = m })
		-- the ground spill: dark rubble round the far end and the open west side (the gamepass lane is the row's
		-- west end; the walkway to the next lane stays clear), some with tiny glowing star specks
		local rng = Random.new(66)
		local function rubble(x, z, s, h)
			local top = -raise + h
			local r = deco(blk("Rubble", Vector3.new(s, h + raise + 2.4, s * rng:NextNumber(0.8, 1.2)), x, top, z, look.Body:Lerp(Color3.new(0, 0, 0), rng:NextNumber(0, 0.35))))
			r.CFrame = r.CFrame * CFrame.Angles(0, rng:NextNumber(-0.5, 0.5), 0)
			if s > 1.4 and rng:NextNumber() < 0.5 then -- a smaller block on top, so it reads as a heap
				local s2 = s * rng:NextNumber(0.45, 0.65)
				local h2 = s2 * rng:NextNumber(0.6, 1)
				deco(blk("Rubble", Vector3.new(s2, h2, s2), x + rng:NextNumber(-0.3, 0.3), top + h2, z + rng:NextNumber(-0.3, 0.3), look.Body:Lerp(look.Accent, 0.08))).CFrame *= CFrame.Angles(0, rng:NextNumber(0, 1.5), 0)
				top += h2
			end
			if rng:NextNumber() < 0.8 then
				for _ = 1, rng:NextInteger(1, 3) do
					local speck = glow("Speck", Vector3.one * 0.24, x + rng:NextNumber(-s / 3, s / 3), top + 0.1, z + rng:NextNumber(-s / 3, s / 3), rng:NextNumber() < 0.5 and look.Accent or look.Second)
					speck:SetAttribute("Breathe", nil) -- specks stay still
				end
			end
		end
		for k = 1, 20 do -- two rows along the west side, taller towards the far end
			local outer = k % 2 == 0
			rubble(-(W / 2 + (outer and rng:NextNumber(2.4, 3.8) or rng:NextNumber(0.7, 2))), front + 1 + (L - 1) * (k - 0.5) / 20 + rng:NextNumber(-0.7, 0.7), rng:NextNumber(1.1, 2.3), rng:NextNumber(0.4, (k > 12 and 2.8 or 1.5) * (outer and 0.6 or 1)))
		end
		for k = 1, 12 do -- behind the far end, in front of and behind each other
			rubble(-W / 2 - 2 + (W + 3.5) * (k - 0.5) / 12 + rng:NextNumber(-0.4, 0.4), back + (k % 2 == 0 and rng:NextNumber(2.4, 3.6) or rng:NextNumber(0.6, 1.8)), rng:NextNumber(1.1, 2.4), rng:NextNumber(0.8, 3))
		end
		for k = 1, 5 do -- low ones round the near-west corner
			rubble(-(W / 2 + rng:NextNumber(0.5, 2.6)), front + 0.5 - rng:NextNumber(0, 2.6), rng:NextNumber(0.9, 1.6), rng:NextNumber(0.3, 0.8))
		end
		for k = 1, 7 do -- a low, narrow strip along the east side's far half (the walkway beside it stays clear)
			rubble(W / 2 + rng:NextNumber(0.5, 1.2), mid + 1 + (back - mid) * (k - 0.5) / 7, rng:NextNumber(0.8, 1.3), rng:NextNumber(0.3, 0.8))
		end
		-- tiny star specks on the decks and along the rail tops (still, never blinking)
		for k = 1, 22 do
			local x, y, z
			if k <= 8 then -- the far deck and the near deck's edges round the pad
				x, z = rng:NextNumber(-inner + 0.3, inner - 0.3), k <= 4 and rng:NextNumber(z1 + 0.2, back - RIM - 0.2) or front + rng:NextNumber(0.2, 1.2)
				y = FLOOR_T + 0.06
			else -- the rail tops
				x, z = (k % 2 == 0 and 1 or -1) * (W / 2 - rng:NextNumber(0.3, RIM - 0.3)), rng:NextNumber(front + 2.6, back - 2.6)
				y = FLOOR_T + RIM_H + 0.06
			end
			local star = glow("Star", Vector3.one * rng:NextNumber(0.14, 0.22), x, y, z, rng:NextNumber() < 0.6 and look.Second or look.Accent)
			star:SetAttribute("Breathe", nil)
		end
		-- slow purple and pink motes rising off the rubble (about 10 at a time)
		for _, spot in ipairs({ { -(W / 2 + 1.8), mid + 4, 2.6, L * 0.55 }, { -0.5, back + 1.9, W + 2, 2.4 } }) do
			local src = deco(blk("MoteSource", Vector3.new(spot[3], 0.2, spot[4]), spot[1], -raise + 0.6, spot[2], look.Body))
			src.Transparency = 1
			local e = Instance.new("ParticleEmitter")
			e.Name = "Motes"
			e.Color = ColorSequence.new(look.Accent, look.Second)
			e.LightEmission = 1
			e.Rate = 2
			e.Lifetime = NumberRange.new(2, 3)
			e.Speed = NumberRange.new(0.6, 1.4)
			e.SpreadAngle = Vector2.new(20, 20)
			e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.45), NumberSequenceKeypoint.new(1, 0) })
			e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.15), NumberSequenceKeypoint.new(1, 1) })
			e.EmissionDirection = Enum.NormalId.Top
			e.Parent = src
		end
	end
	if lamp then
		local light = Instance.new("PointLight")
		light.Color = look.Accent
		light.Brightness = look.Premium and 1 or 0.5
		light.Range = look.Premium and 9 or 6
		light.Shadows = false
		light.Parent = lamp
	end
	if look.Motes then
		-- a few slow sparkles over the belt (Roblox's own sparkle picture; a soft twinkle, never a flash)
		local e = Instance.new("ParticleEmitter")
		e.Name = "Sparkles"
		e.Color = ColorSequence.new(look.Accent:Lerp(WHITE, 0.4))
		e.LightEmission = 1
		e.Rate = 2
		e.Lifetime = NumberRange.new(1.2, 1.8)
		e.Speed = NumberRange.new(0.8, 1.6)
		e.SpreadAngle = Vector2.new(15, 15)
		e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 0) })
		e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) })
		e.EmissionDirection = Enum.NormalId.Top
		e.Parent = belt
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

	local look = tierLook(info.Id)
	local standPos, fireDir = slot(i)
	standPos += Vector3.new(0, (look.Raise or 0) * BOOTH_SCALE, 0) -- the gamepass lane stands higher
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
	part({ Name = "StandPoint", Size = Vector3.new(1, 0.2, 1), Transparency = 1, CanCollide = false, CanTouch = false, CFrame = standCf + Vector3.new(0, PAD_UP, 0), Parent = station }) -- on the pad's tiles

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
	local floorY = standPos.Y -- this lane's floor top
	-- the cannon sits low on the stand pad, its nose at the pool (no plinth: nothing tall in the lane), on a
	-- display turntable like a prize on show (Oct 31: "make the cannon look better"): a thin disc in the
	-- lane's dark shade over a ring in the tier colour, glowing on the glow tiers, with a soft light
	local cannonPos = standPos + fireDir * (POOL_START - 0.6 - size.Z / 2)
	local DISC = 0.35
	local discD = math.min(size.Z + 0.4, 7.4)
	local discPos = Vector3.new(cannonPos.X, floorY + PAD_UP, cannonPos.Z)
	local ringPart = part({ Name = "DisplayRing", Shape = Enum.PartType.Cylinder, Size = Vector3.new(DISC - 0.1, discD + 0.7, discD + 0.7), Color = look.Accent,
		Material = (look.Glow or look.Neon) and Enum.Material.Neon or Enum.Material.SmoothPlastic, CastShadow = false, CanCollide = false,
		CFrame = CFrame.new(discPos + Vector3.new(0, (DISC - 0.1) / 2, 0)) * CFrame.Angles(0, 0, math.rad(90)), Parent = station })
	part({ Name = "DisplayDisc", Shape = Enum.PartType.Cylinder, Size = Vector3.new(DISC, discD, discD), Color = look.Premium and rgb(62, 34, 128) or dark(look.Rim, 0.15), -- the gamepass disc is dark violet so its pink cannon pops (Oct 31)
		Material = Enum.Material.SmoothPlastic, CanCollide = false,
		CFrame = CFrame.new(discPos + Vector3.new(0, DISC / 2 + 0.01, 0)) * CFrame.Angles(0, 0, math.rad(90)), Parent = station })
	if look.Glow then
		local light = Instance.new("PointLight")
		-- the gamepass lane gets a bright white light, so its pink cannon isn't tinted gold (Oct 31)
		light.Color = look.Premium and rgb(255, 246, 236) or look.Accent
		light.Brightness = look.Premium and 0.9 or 0.7
		light.Range = look.Premium and 8 or 7
		light.Shadows = false
		light.Parent = ringPart
	end
	-- imported cannons point their barrel along +Z, so face +Z at the target
	cannon:PivotTo(CFrame.lookAt(cannonPos, cannonPos - fireDir))
	local cf, sz = cannon:GetBoundingBox()
	cannon:PivotTo(cannon:GetPivot() + Vector3.new(0, floorY + PAD_UP + DISC - (cf.Position.Y - sz.Y / 2), 0))
	cannon.Parent = station

	local muzzlePos = cannonPos + fireDir * (size.Z / 2) + Vector3.new(0, floorY + PAD_UP + DISC + size.Y * 0.62 - cannonPos.Y, 0)
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
	makeBooth(baseCf, boothWidth, look, info).Parent = station

	-- the lane's glow colour, used by the client for its shots and hit effects
	station:SetAttribute("Accent", look.Accent)
	station.PrimaryPart = pad
	station:ScaleTo(BOOTH_SCALE)
	-- scaling pulls everything towards the pad: stand the lane back on the platform
	local floorPart = station.Booth:FindFirstChild("Floor")
	local bottom = floorPart.CFrame.Position.Y - floorPart.Size.Y / 2 -- (CFrame.Position: the offline preview has no .Position)
	station:PivotTo(station:GetPivot() - Vector3.new(0, bottom - laneBase, 0))
	station.Parent = folder
end
folder.Parent = workspace

-- The "2x POWER" board by the first lane (Oct 31: "make it seem more buyable"), like Stone Skipping's
-- "+2x SKILL ONLY R$" cards next to its lanes: a pirate signboard on two posts with the 2x Power pass, its
-- Robux price from GameConfig, and a prompt. GameServer hooks every ProximityPrompt whose part has a BuyPass
-- attribute to the Shop's purchase (owned: "You already own this!", no pass id yet: "Coming soon!").
local oldShop = workspace:FindFirstChild("TrainingShop")
if oldShop then
	oldShop:Destroy()
end
local first = newMap and folder:FindFirstChild("Station_" .. order[1].Id)
local pass = Config.Passes.DoublePower
if first and pass then
	local shop = Instance.new("Model")
	shop.Name = "TrainingShop"
	local cf, size = first.Booth:GetBoundingBox()
	-- beside the first lane's stand pad (clear of the lookout tower behind it), turned 30 degrees from facing the
	-- plaza towards that pad, so you read it from the plaza and while you train
	-- Oct 31 critic: beside the pad it hid behind the lookout tower, so it stands forward, level with the lane
	-- fronts, facing the spawn, and bigger
	local bx, bz = cf.Position.X + size.X / 2 + 8, first.StandPoint.Position.Z + 9
	local base = Vector3.new(bx, floorAt(bx, bz, cf.Position.Y - size.Y / 2), bz)
	local spawnAt = Config.Map.Spawn
	local faceCf = CFrame.lookAt(base, Vector3.new(spawnAt.X, base.Y, spawnAt.Z))
	local WOOD, BRASS = rgb(105, 68, 38), rgb(225, 175, 70)
	local BW, BH, LIFT = 13, 8, 2.4 -- the board's width and height, and how high its bottom is
	for _, sx in ipairs({ -1, 1 }) do
		part({ Name = "Post", Size = Vector3.new(0.8, LIFT + BH + 0.6, 0.8), Color = WOOD, Material = Enum.Material.SmoothPlastic,
			CFrame = faceCf * CFrame.new(sx * (BW / 2 - 0.6), (LIFT + BH + 0.6) / 2 - 0.3, 0.5), Parent = shop })
		part({ Name = "PostCap", Size = Vector3.new(1.1, 0.4, 1.1), Color = BRASS, Material = Enum.Material.SmoothPlastic,
			CFrame = faceCf * CFrame.new(sx * (BW / 2 - 0.6), LIFT + BH + 0.5, 0.5), Parent = shop })
	end
	part({ Name = "Frame", Size = Vector3.new(BW + 0.6, BH + 0.6, 0.5), Color = BRASS, Material = Enum.Material.SmoothPlastic,
		CFrame = faceCf * CFrame.new(0, LIFT + BH / 2, 0.15), Parent = shop })
	local board = part({ Name = "Board", Size = Vector3.new(BW, BH, 0.6), Color = rgb(120, 205, 60), Material = Enum.Material.SmoothPlastic,
		CFrame = faceCf * CFrame.new(0, LIFT + BH / 2, -0.05), Parent = shop })
	board:SetAttribute("BuyPass", "DoublePower")
	local okIcons, Icons = pcall(require, game.ReplicatedStorage:FindFirstChild("Icons"))
	local function icon(name)
		return okIcons and Icons and Icons[name] or ""
	end
	local gui = Instance.new("SurfaceGui")
	gui.Name = "Gui"
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 50
	gui.LightInfluence = 0
	gui.Parent = board
	local function text(str, color, pos, sz, stroke)
		local t = Instance.new("TextLabel")
		t.BackgroundTransparency = 1
		t.Font = Enum.Font.FredokaOne
		t.TextScaled = true
		t.Text = str
		t.TextColor3 = color
		t.Position = pos
		t.Size = sz
		t.Parent = gui
		local st = Instance.new("UIStroke")
		st.Thickness = stroke
		st.Color = rgb(30, 60, 10)
		st.Parent = t
		return t
	end
	local bolt = Instance.new("ImageLabel")
	bolt.BackgroundTransparency = 1
	bolt.Image = icon("DoublePower")
	bolt.ScaleType = Enum.ScaleType.Fit
	bolt.Position = UDim2.fromScale(0.03, 0.04)
	bolt.Size = UDim2.fromScale(0.3, 0.6)
	bolt.Parent = gui
	text("2x POWER", Color3.new(1, 1, 1), UDim2.fromScale(0.32, 0.08), UDim2.fromScale(0.65, 0.42), 8)
	text("on every shot", rgb(235, 255, 215), UDim2.fromScale(0.32, 0.5), UDim2.fromScale(0.65, 0.17), 4)
	text("ONLY", rgb(255, 225, 60), UDim2.fromScale(0.12, 0.7), UDim2.fromScale(0.3, 0.24), 6)
	local robux = Instance.new("ImageLabel")
	robux.BackgroundTransparency = 1
	robux.Image = icon("Robux")
	robux.ScaleType = Enum.ScaleType.Fit
	robux.Position = UDim2.fromScale(0.44, 0.7)
	robux.Size = UDim2.fromScale(0.13, 0.24)
	robux.Parent = gui
	text(tostring(pass.Price), rgb(255, 225, 60), UDim2.fromScale(0.58, 0.7), UDim2.fromScale(0.3, 0.24), 6)
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Buy"
	prompt.ObjectText = pass.Name
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 14
	prompt.RequiresLineOfSight = false
	prompt.Parent = board
	shop.Parent = workspace
end

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
board.MaxDistance = 250 -- seen from the plaza again: Alex deleted the LAUNCH! arch (Oct 31), so this label shows the way
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
-- The spawn's compass floor flickered (Alex, Oct 31: "make the spawn not flicker"): the map draws it as two
-- halves that are the same size in the same place, each with a sliver of the other's planks, so the two
-- fight to be seen. Lifting one half 0.05 studs lets it always win. Once only (attribute BaseY).
if newMap then
	local half = newMap:FindFirstChild("Plaza_Compass_Spawn_001_2", true)
	if half and half:IsA("BasePart") then
		local baseY = half:GetAttribute("BaseY") or half.Position.Y
		half:SetAttribute("BaseY", baseY)
		half.CFrame = half.CFrame + Vector3.new(0, baseY + 0.05 - half.Position.Y, 0)
	end
end

print("[BuildWorld1] Built " .. #Config.Stations .. " stations")
