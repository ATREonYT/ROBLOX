-- ═══════════════════════════════════════════════════════════════════════════
-- MAP SPEC — actually builds all six floors against the mock Roblox API and
-- checks the geometry contract. This is the closest thing to pressing Play
-- that runs without Studio: it catches runtime errors, bad Kit calls, NaN
-- CFrames, floating props and broken manifests.
-- ═══════════════════════════════════════════════════════════════════════════

local Palettes = __require("Palettes")
local FloorsConfig = __require("Floors")
local RivalsConfig = __require("Rivals")
local Balance = __require("Balance")

local passed, failed = 0, 0
local failures = {}

local function check(name, condition, detail)
	if condition then
		passed += 1
	else
		failed += 1
		table.insert(failures, ("  FAIL  %s%s"):format(name, if detail then " — " .. detail else ""))
	end
end

local function isFinite(n)
	return type(n) == "number" and n == n and n ~= math.huge and n ~= -math.huge
end

local function cfIsSane(c)
	if type(c) ~= "table" or c.X == nil then return false end
	for _, v in { c.X, c.Y, c.Z, c.R00, c.R01, c.R02, c.R10, c.R11, c.R12, c.R20, c.R21, c.R22 } do
		if not isFinite(v) then return false end
	end
	return true
end

print("═══ BUILDING ALL SIX FLOORS ═══\n")

local EXPECTED_PACK = { [1] = 3, [2] = 3, [3] = 2, [4] = 2, [5] = 2, [6] = 2, [7] = 1 }
local totalParts = 0

for _, floorDef in FloorsConfig.List do
	local id = floorDef.Id
	local palette = Palettes.get(id)
	local origin = Vector3.new(floorDef.Origin[1], floorDef.Origin[2], floorDef.Origin[3])

	local container = Instance.new("Folder")
	container.Name = id

	local builder = __require(id)
	local ok, manifest = pcall(function()
		return builder.build(container, origin, palette)
	end)

	if not ok then
		failed += 1
		table.insert(failures, ("  FAIL  %s build() threw — %s"):format(id, tostring(manifest)))
		continue
	end

	-- ── What actually got built ────────────────────────────────────────────
	local descendants = container:GetDescendants()
	local parts, anchoredParts, badSize, badCf, sunk = 0, 0, 0, 0, 0
	for _, inst in descendants do
		if inst:IsA("BasePart") then
			parts += 1
			if inst.Anchored then anchoredParts += 1 end
			local size = inst.Size
			if size == nil or not (isFinite(size.X) and isFinite(size.Y) and isFinite(size.Z))
				or size.X <= 0 or size.Y <= 0 or size.Z <= 0 then
				badSize += 1
			end
			if not cfIsSane(inst.CFrame) then badCf += 1 end
		end
	end
	totalParts += parts

	print(("── %-12s %5d parts, %4d descendants"):format(id, parts, #descendants))

	check(id .. ": builds without error", true)
	check(id .. ": has geometry", parts > 400, ("only %d parts"):format(parts))
	check(id .. ": within part budget", parts <= 2800, ("%d parts exceeds 2800"):format(parts))
	check(id .. ": every part is anchored", anchoredParts == parts,
		("%d of %d parts unanchored — they would fall on spawn"):format(parts - anchoredParts, parts))
	check(id .. ": no zero/NaN part sizes", badSize == 0, ("%d bad sizes"):format(badSize))
	check(id .. ": no NaN CFrames", badCf == 0, ("%d bad CFrames"):format(badCf))

	-- ── Manifest contract ──────────────────────────────────────────────────
	check(id .. ": manifest returned", type(manifest) == "table")
	check(id .. ": Spawn is a sane CFrame", cfIsSane(manifest.Spawn))
	check(id .. ": spawn is above the floor", manifest.Spawn ~= nil and manifest.Spawn.Y >= origin.Y,
		"spawn below floor origin — players would fall through")

	-- Rival spots: exact pack layout, all reachable, all facing somewhere.
	local spots = manifest.RivalSpots or {}
	local packCounts = {}
	local spotsSane = true
	for _, spot in spots do
		packCounts[spot.DefIndex] = (packCounts[spot.DefIndex] or 0) + 1
		if not cfIsSane(spot.Cf) then spotsSane = false end
	end
	check(id .. ": 15 rival spots", #spots == 15, ("got %d"):format(#spots))
	check(id .. ": rival CFrames sane", spotsSane)
	local packOk = true
	for defIndex, want in EXPECTED_PACK do
		if (packCounts[defIndex] or 0) ~= want then packOk = false end
	end
	check(id .. ": rival pack layout 3/3/2/2/2/2/1", packOk,
		("got %s"):format(table.concat({
			tostring(packCounts[1] or 0), tostring(packCounts[2] or 0), tostring(packCounts[3] or 0),
			tostring(packCounts[4] or 0), tostring(packCounts[5] or 0), tostring(packCounts[6] or 0),
			tostring(packCounts[7] or 0),
		}, "/")))

	-- Every DefIndex must exist in the rival config for this floor.
	local defs = RivalsConfig.ByFloor[id]
	local defsExist = defs ~= nil
	if defsExist then
		for _, spot in spots do
			if defs[spot.DefIndex] == nil then defsExist = false end
		end
	end
	check(id .. ": every rival DefIndex exists in config", defsExist)

	-- Rivals must stand on the floor, not float or sink.
	local heightOk = true
	for _, spot in spots do
		local dy = spot.Cf.Y - origin.Y
		if dy < 0 or dy > 12 then heightOk = false end
	end
	check(id .. ": rivals stand at floor level", heightOk, "a rival spot is floating or below the deck")

	-- Training zones: 3 tiers, correct rates/gates, invisible and intangible.
	local zones = manifest.TrainingZones or {}
	check(id .. ": 3 training zones", #zones == 3, ("got %d"):format(#zones))
	local zonesOk, ratesOk = true, true
	for i, entry in zones do
		local zone = entry.Zone
		if zone == nil or not zone:IsA("BasePart") then
			zonesOk = false
		elseif zone.CanCollide ~= false or zone.Transparency ~= 1 or zone.CanQuery ~= false then
			zonesOk = false
		end
		-- Rates and gates must come from Balance, in tier order.
		if entry.Rate ~= Balance.TrainingTierRates[i] or entry.MinRank ~= Balance.TrainingTierMinRank[i] then
			ratesOk = false
		end
	end
	check(id .. ": zones are invisible + intangible", zonesOk)
	check(id .. ": zone rates/gates match Balance", ratesOk)

	-- Payday pads: five, segments 1-5, distinct parts.
	local pads = manifest.PaydayPads or {}
	check(id .. ": 5 payday pads", #pads == 5, ("got %d"):format(#pads))
	local seenSegments, padsOk = {}, true
	for _, entry in pads do
		if entry.Pad == nil or not entry.Pad:IsA("BasePart") then padsOk = false end
		if seenSegments[entry.Segment] then padsOk = false end
		seenSegments[entry.Segment] = true
	end
	local segmentsOk = true
	for k = 1, 5 do
		if not seenSegments[k] then segmentsOk = false end
	end
	check(id .. ": pads are parts, one per segment", padsOk)
	check(id .. ": pad segments are 1-5", segmentsOk)

	-- Prompts + boards: MapService attaches ProximityPrompts / SurfaceGuis to
	-- these, so a nil here is a crash at startup.
	local prompts = manifest.Prompts or {}
	local promptsOk = true
	for _, key in { "Shop", "Coffee", "Hr", "Elevator" } do
		local part = prompts[key]
		if part == nil or not part:IsA("BasePart") then promptsOk = false end
	end
	check(id .. ": all four prompt parts present", promptsOk)

	local boards = manifest.Boards or {}
	local boardsOk = boards.Eotm ~= nil and boards.Eotm:IsA("BasePart")
		and boards.Wins ~= nil and boards.Wins:IsA("BasePart")
	check(id .. ": both board parts present", boardsOk)

	-- Prompt/board parts must actually be inside this floor's folder, or
	-- MapService would decorate an orphan.
	local function isDescendant(target)
		local node = target
		while node ~= nil do
			if node == container then return true end
			node = node.Parent
		end
		return false
	end
	local parented = promptsOk and boardsOk
	if parented then
		for _, key in { "Shop", "Coffee", "Hr", "Elevator" } do
			if not isDescendant(prompts[key]) then parented = false end
		end
		if not isDescendant(boards.Eotm) or not isDescendant(boards.Wins) then parented = false end
	end
	check(id .. ": prompt/board parts live under the floor folder", parented)

	-- Everything must sit near this floor's origin: a stray world-coordinate
	-- would scatter geometry across the map.
	local strays = 0
	for _, inst in descendants do
		if inst:IsA("BasePart") and cfIsSane(inst.CFrame) then
			local dx = math.abs(inst.CFrame.X - origin.X)
			local dz = math.abs(inst.CFrame.Z - origin.Z)
			local dy = math.abs(inst.CFrame.Y - origin.Y)
			if dx > 700 or dz > 700 or dy > 700 then strays += 1 end
		end
	end
	check(id .. ": no geometry escapes the floor's bounds", strays == 0,
		("%d parts more than 700 studs from origin"):format(strays))
end

print(("\nTotal parts across all floors: %d"):format(totalParts))
check("whole map fits a mobile part budget", totalParts <= 16000, ("%d parts"):format(totalParts))

-- Tags the client's WorldFxController drives must actually get applied.
local tags = __mock.taggedInstances
print("\nCollectionService tags applied:")
for tag, list in tags do
	print(("  %-14s %d"):format(tag, #list))
end
check("GlowScreen tag applied", (tags.GlowScreen and #tags.GlowScreen or 0) > 0)
check("FlickerLight tag applied", (tags.FlickerLight and #tags.FlickerLight or 0) > 0)
check("IdleBob tag applied (payday pads)", (tags.IdleBob and #tags.IdleBob or 0) >= 30)
check("WaterShimmer tag applied", (tags.WaterShimmer and #tags.WaterShimmer or 0) > 0)
check("TickerSign tag applied", (tags.TickerSign and #tags.TickerSign or 0) > 0)

print("\n═══════════════════════════════════════")
if failed > 0 then
	print(("%d passed, %d FAILED\n"):format(passed, failed))
	for _, line in failures do print(line) end
	error(("map spec: %d checks failed"):format(failed), 0)
else
	print(("%d passed, 0 failed — all six floors build clean"):format(passed))
end
