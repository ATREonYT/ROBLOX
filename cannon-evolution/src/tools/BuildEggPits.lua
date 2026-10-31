--[[
	BuildEggPits (Oct 31): the egg area's dug pits. Alex: "make them be like eggs in the ground ... like dug a bit
	into the ground, and the ground around it, and also make some space for a robux egg in the middle".

	Builds workspace.EggPits round the eggs WHERE THEY STAND NOW: it reads workspace.EggStands, so Alex's own
	placement is kept. The egg models, their names and the click-to-open code are not touched, except that each
	egg is sunk EGG_SINK studs into its hole (once: attribute SunkBy). Run it after BuildLobbyExtras.

	Each pit: a ring of dirt banks with a grass top that slopes back down to the lawn, dark soil in the hole,
	patches of loose earth and clods round it. Where two pits are close they share one bank (one ridge, never two
	walls inside each other). The Robux egg's spot (FEATURED_AT, the middle of Alex's half circle) is a wider
	hole with a gold rim, a soft steady light, slow sparkles and a COMING SOON board: nothing is sold there until
	a Robux egg exists (house rule). It is kept out of EggStands, so tapping it never opens an egg menu.
	Flat pieces never share a height with a neighbour (no flicker). Safe to run again.
]]
local Config = require(game.ReplicatedStorage.GameConfig)
local TAG = "[EggPits]"
local EGG_SINK = 0.8
local FEATURED_AT = Vector2.new(-178, 1.8)
local HOLE, FEATURED_HOLE = 3.0, 3.8 -- inside of the bank, from the middle (the eggs are about 5.5 wide)
local BANK_T, SLOPE_L = 1.3, 2.2
local DIRT, SOIL, LOOSE = Color3.fromRGB(139, 94, 57), Color3.fromRGB(84, 56, 36), Color3.fromRGB(170, 122, 78)
local GRASS, GOLD = Color3.fromRGB(104, 196, 72), Color3.fromRGB(255, 200, 60)

local map = workspace:FindFirstChild(Config.Map.Root)
local stands = workspace:FindFirstChild("EggStands")
if not (map and stands) then
	warn(TAG, "needs the new map and workspace.EggStands; nothing built")
	return
end
local floorParams = RaycastParams.new()
floorParams.FilterType = Enum.RaycastFilterType.Include
floorParams.FilterDescendantsInstances = { map }
local function floorHit(x, z)
	return workspace:Raycast(Vector3.new(x, 200, z), Vector3.new(0, -400, 0), floorParams)
end
local function floorAt(x, z)
	local h = floorHit(x, z)
	return h and h.Position.Y or 4.1
end

local old = workspace:FindFirstChild("EggPits")
if old then
	old:Destroy()
end
local folder = Instance.new("Folder")
folder.Name = "EggPits"
local rng = Random.new(7)

local function bit(cls, props, parent)
	local q = Instance.new(cls)
	q.Anchored = true
	q.CanTouch = false
	q.TopSurface = Enum.SurfaceType.Smooth
	q.BottomSurface = Enum.SurfaceType.Smooth
	q.Material = Enum.Material.SmoothPlastic
	for k, v in pairs(props) do
		q[k] = v
	end
	q.Parent = parent
	return q
end
local function disc(name, centre, topY, radius, thick, color, parent)
	return bit("Part", { Name = name, Shape = Enum.PartType.Cylinder, Size = Vector3.new(thick, radius * 2, radius * 2), Color = color, CanCollide = false, CanQuery = false,
		CFrame = CFrame.new(centre.X, topY - thick / 2, centre.Z) * CFrame.Angles(0, 0, math.rad(90)) }, parent)
end

-- the pits: the Robux spot first, so where it meets an egg's pit the shared bank is its gold one
local pits = { { name = "FeaturedPit", at = FEATURED_AT, hole = FEATURED_HOLE, featured = true } }
local eggs = stands:GetChildren()
table.sort(eggs, function(a, b)
	return a.Name < b.Name
end)
for _, stand in ipairs(eggs) do
	if stand:IsA("Model") and stand:GetAttribute("EggId") then
		local done = stand:GetAttribute("SunkBy") or 0
		if done ~= EGG_SINK then
			stand:PivotTo(stand:GetPivot() - Vector3.new(0, EGG_SINK - done, 0))
			stand:SetAttribute("SunkBy", EGG_SINK)
		end
		local p = stand:GetPivot().Position
		table.insert(pits, { name = stand.Name:gsub("Egg$", "") .. "Pit", at = Vector2.new(p.X, p.Z), hole = HOLE })
	end
end
for _, pit in ipairs(pits) do
	pit.r = pit.hole + BANK_T / 2 -- the middle of the bank
	pit.outer = pit.hole + BANK_T + SLOPE_L -- where the grass slope meets the lawn
end
local function flat(v)
	return Vector2.new(v.X, v.Z)
end
-- is this spot (x, z) inside another pit's ring, out to `extra` past its bank's middle?
local function inOther(me, at, extra)
	for j, other in ipairs(pits) do
		if j ~= me and (at - other.at).Magnitude < other.r + extra then
			return j
		end
	end
end

local banks, patches = 0, 0
for k, pit in ipairs(pits) do
	local model = Instance.new("Model")
	model.Name = pit.name
	local g = floorAt(pit.at.X, pit.at.Y)
	local centre = Vector3.new(pit.at.X, g, pit.at.Y)
	-- dark soil in the hole (pits never overlap in the middle, so each can sit at the same height)
	disc("Soil", centre, g + 0.18, pit.hole + 0.5, 0.16, SOIL, model)
	-- banks: dirt leaning out a little, a grass (or gold) top, and a grass slope down to the lawn
	local n = pit.featured and 15 or 12 -- a multiple of 3, so neighbouring tops never share a height
	local width = 2 * math.pi * pit.r / n * 1.14
	local slopeW = 2 * math.pi * (pit.r + BANK_T / 2 + SLOPE_L / 2) / n * 1.15
	for i = 1, n do
		local a = (i - 0.5) / n * math.pi * 2
		local out = Vector3.new(math.cos(a), 0, math.sin(a))
		local base = centre + out * pit.r
		local other = inOther(k, flat(base), BANK_T + 0.4)
		if not (other and other < k) then -- an earlier pit's bank already stands here
			local h = (pit.featured and 1.9 or 1.6) + (i % 3) * 0.12
			local face = CFrame.lookAt(base, base + out) -- -Z points away from the hole
			local dirt = pit.featured and (i % 2 == 0 and GOLD or DIRT) or DIRT:Lerp(LOOSE, rng:NextNumber(0, 0.25))
			bit("Part", { Name = "Bank", Size = Vector3.new(width, h, BANK_T), Color = dirt,
				CFrame = face * CFrame.new(0, h / 2 - 0.1, 0) * CFrame.Angles(math.rad(-10), 0, 0) }, model)
			bit("Part", { Name = "Top", Size = Vector3.new(width * 1.02, 0.35, 1.6), Color = pit.featured and GOLD or GRASS,
				CFrame = face * CFrame.new(0, h - 0.05, -0.25) }, model)
			banks += 1
			-- the slope only where it can't run into the next pit
			local mid = flat(centre + out * (pit.r + BANK_T / 2 + SLOPE_L / 2))
			local tip = flat(centre + out * pit.outer)
			if not inOther(k, mid, BANK_T / 2 + 0.3) and not inOther(k, tip, BANK_T / 2 + 0.3) then
				bit("WedgePart", { Name = "Slope", Size = Vector3.new(slopeW, h - 0.1, SLOPE_L), Color = GRASS,
					CFrame = face * CFrame.new(0, (h - 0.1) / 2, -(BANK_T / 2 + SLOPE_L / 2)) }, model)
			end
		end
	end
	-- loose earth just past the slopes, only on open lawn (not on a path, never inside another pit)
	local turn = rng:NextNumber(0, math.pi * 2)
	for i = 1, 6 do
		local a = turn + i / 6 * math.pi * 2
		local rad = rng:NextNumber(1.1, 1.6)
		local at = pit.at + Vector2.new(math.cos(a), math.sin(a)) * (pit.outer + 0.4)
		local hit = floorHit(at.X, at.Y)
		if hit and hit.Instance.Name:match("^Island") and not inOther(k, at, BANK_T / 2 + SLOPE_L + rad + 0.3) then
			patches += 1
			disc("LooseEarth", Vector3.new(at.X, 0, at.Y), hit.Position.Y + 0.06 + (patches % 4) * 0.03, rad, 0.1, LOOSE, model)
		end
		-- a clod thrown out of the hole
		local s = rng:NextNumber(0.5, 1)
		local ca = a + rng:NextNumber(-0.4, 0.4)
		local cat = pit.at + Vector2.new(math.cos(ca), math.sin(ca)) * (pit.outer + rng:NextNumber(0.2, 1.4))
		if not inOther(k, cat, BANK_T / 2 + SLOPE_L + 0.5) then
			bit("Part", { Name = "Clod", Size = Vector3.new(s, s * 0.7, s), Color = DIRT:Lerp(SOIL, rng:NextNumber(0, 0.5)), CanCollide = false, CanQuery = false,
				CFrame = CFrame.new(cat.X, floorAt(cat.X, cat.Y) + s * 0.25, cat.Y) * CFrame.Angles(rng:NextNumber(-0.4, 0.4), rng:NextNumber(0, 6.28), rng:NextNumber(-0.4, 0.4)) }, model)
		end
	end
	if pit.featured then
		model:SetAttribute("FeaturedEggSpot", true)
		local glow = disc("Glow", centre, g + 0.26, pit.hole - 0.3, 0.06, GOLD, model)
		glow.Material = Enum.Material.Neon
		glow.Transparency = 0.5
		local light = Instance.new("PointLight")
		light.Color = GOLD
		light.Range = 14
		light.Brightness = 1.6
		light.Shadows = false
		light.Parent = glow
		local sparkle = Instance.new("ParticleEmitter") -- slow and steady, never a flash
		sparkle.Color = ColorSequence.new(Color3.fromRGB(255, 225, 120))
		sparkle.LightEmission = 1
		sparkle.Rate = 3
		sparkle.Lifetime = NumberRange.new(1.5, 2.5)
		sparkle.Speed = NumberRange.new(1, 2)
		sparkle.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 0) })
		sparkle.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) })
		sparkle.Parent = glow
		-- a wooden board behind the hole, facing the plaza (east)
		local back = centre - Vector3.new(pit.outer + 1, 0, 0)
		for _, side in ipairs({ -1, 1 }) do
			bit("Part", { Name = "Post", Size = Vector3.new(0.5, 5, 0.5), Color = Color3.fromRGB(102, 66, 38), CanCollide = false, CanQuery = false,
				CFrame = CFrame.new(back + Vector3.new(0, 2.4, side * 2.6)) }, model)
		end
		local boardPos = back + Vector3.new(0, 4, 0)
		local board = bit("Part", { Name = "Board", Size = Vector3.new(6, 1.8, 0.3), Color = Color3.fromRGB(196, 140, 80), CanCollide = false, CanQuery = false,
			CFrame = CFrame.lookAt(boardPos, boardPos + Vector3.new(1, 0, 0)) }, model)
		local gui = Instance.new("SurfaceGui")
		gui.Face = Enum.NormalId.Front
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 30
		gui.LightInfluence = 0.3
		gui.Parent = board
		local t = Instance.new("TextLabel")
		t.BackgroundTransparency = 1
		t.Size = UDim2.fromScale(0.9, 0.8)
		t.Position = UDim2.fromScale(0.05, 0.1)
		t.Font = Enum.Font.FredokaOne
		t.TextScaled = true
		t.Text = "COMING SOON"
		t.TextColor3 = Color3.new(1, 1, 1)
		t.Parent = gui
		local stroke = Instance.new("UIStroke")
		stroke.Thickness = 3
		stroke.Color = Color3.fromRGB(30, 20, 40)
		stroke.Parent = t
	end
	model.Parent = folder
end
folder.Parent = workspace
print(TAG, ("%d pits (%d eggs sunk %.1f studs, 1 Robux egg spot), %d bank pieces, %d loose earth patches"):format(#pits, #pits - 1, EGG_SINK, banks, patches))
