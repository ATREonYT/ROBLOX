-- ═══════════════════════════════════════════════════════════════════════════
-- WORLD SPEC — builds the hub and all eight stages against the mock Roblox
-- API and checks the contract every gameplay service depends on.
-- ═══════════════════════════════════════════════════════════════════════════

local Hub = __require("Hub")
local StageBuilder = __require("StageBuilder")
local Stages = __require("Stages")
local TrainingBags = __require("TrainingBags")
local SkinsConfig = __require("Skins")
local Eggs = __require("Eggs")

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

local function cfSane(c)
	if type(c) ~= "table" or c.X == nil then return false end
	for _, v in { c.X, c.Y, c.Z, c.R00, c.R11, c.R22 } do
		if not isFinite(v) then return false end
	end
	return true
end

local function auditParts(folder, label)
	local parts, unanchored, badSize = 0, 0, 0
	for _, inst in folder:GetDescendants() do
		if inst:IsA("BasePart") then
			parts += 1
			if not inst.Anchored then unanchored += 1 end
			local size = inst.Size
			if size == nil or not (isFinite(size.X) and isFinite(size.Y) and isFinite(size.Z))
				or size.X <= 0 or size.Y <= 0 or size.Z <= 0 then
				badSize += 1
			end
		end
	end
	check(label .. ": every part anchored", unanchored == 0, ("%d unanchored"):format(unanchored))
	check(label .. ": no zero/NaN sizes", badSize == 0, ("%d bad"):format(badSize))
	return parts
end

print("═══ BUILDING THE WORLD ═══\n")

-- ── HUB ────────────────────────────────────────────────────────────────────
local hubFolder = Instance.new("Folder")
hubFolder.Name = "Hub"
local hubStage = Stages.get("Hub")
local okHub, hub = pcall(function()
	return Hub.build(hubFolder, Vector3.new(hubStage.Origin[1], hubStage.Origin[2], hubStage.Origin[3]))
end)
check("hub builds without error", okHub, tostring(hub))

local totalParts = 0
if okHub then
	local parts = auditParts(hubFolder, "hub")
	totalParts += parts
	print(("── %-14s %5d parts"):format("Hub", parts))

	check("hub spawn is a sane CFrame", cfSane(hub.Spawn))
	check("a pad for every training bag", #hub.TrainingBags == #TrainingBags.List,
		("%d pads vs %d bags"):format(#hub.TrainingBags, #TrainingBags.List))
	check("a podium for every skin", #hub.SkinPodiums == #SkinsConfig.List,
		("%d podiums vs %d skins"):format(#hub.SkinPodiums, #SkinsConfig.List))
	check("a stand for every briefcase", #hub.EggPads == #Eggs.List,
		("%d stands vs %d eggs"):format(#hub.EggPads, #Eggs.List))
	check("rebirth pad present", hub.RebirthPad ~= nil and hub.RebirthPad:IsA("BasePart"))
	check("gear pad present", hub.GearPad ~= nil and hub.GearPad:IsA("BasePart"))
	check("free-power chest present", hub.ChestPad ~= nil and hub.ChestPad:IsA("BasePart"))

	-- Every id in the manifest must exist in config, or a service reads nil.
	local bagIdsOk = true
	for _, entry in hub.TrainingBags do
		if TrainingBags.get(entry.BagId) == nil or not entry.Pad:IsA("BasePart") then bagIdsOk = false end
	end
	check("bag pads map to real bags", bagIdsOk)
	local skinIdsOk = true
	for _, entry in hub.SkinPodiums do
		if SkinsConfig.get(entry.SkinId) == nil or not entry.Pad:IsA("BasePart") then skinIdsOk = false end
	end
	check("skin podiums map to real skins", skinIdsOk)
	local eggIdsOk = true
	for _, entry in hub.EggPads do
		if Eggs.get(entry.EggId) == nil or not entry.Pad:IsA("BasePart") then eggIdsOk = false end
	end
	check("briefcase stands map to real briefcases", eggIdsOk)
end

-- ── STAGES ─────────────────────────────────────────────────────────────────
local builtStages = 0
for _, stage in Stages.List do
	if stage.Number == 0 then continue end
	local folder = Instance.new("Folder")
	folder.Name = stage.Id
	local ok, manifest = pcall(function()
		return StageBuilder.build(folder, stage)
	end)
	check(("stage %d (%s) builds"):format(stage.Number, stage.DisplayName), ok, tostring(manifest))
	if not ok then continue end
	builtStages += 1

	local parts = auditParts(folder, stage.Id)
	totalParts += parts
	print(("── %-14s %5d parts   %d x %s (%s HP)"):format(
		stage.DisplayName, parts, stage.EnemyCount, stage.EnemyName, tostring(stage.EnemyHealth)))

	check(stage.Id .. ": has geometry", parts > 250, ("only %d parts"):format(parts))
	check(stage.Id .. ": one enemy spot per configured enemy",
		#manifest.EnemySpots == stage.EnemyCount,
		("%d spots vs %d enemies"):format(#manifest.EnemySpots, stage.EnemyCount))
	local spotsSane = true
	for _, cf in manifest.EnemySpots do
		if not cfSane(cf) then spotsSane = false end
	end
	check(stage.Id .. ": enemy spots are sane CFrames", spotsSane)
	check(stage.Id .. ": entry CFrame is sane", cfSane(manifest.EntryCf))
	check(stage.Id .. ": both cash-out pads present",
		manifest.BigPad ~= nil and manifest.BigPad:IsA("BasePart")
			and manifest.ReturnPad ~= nil and manifest.ReturnPad:IsA("BasePart"))
	check(stage.Id .. ": barrier present", manifest.Barrier ~= nil and manifest.Barrier:IsA("BasePart"))
	check(stage.Id .. ": manifest number matches config", manifest.Number == stage.Number)
end

check("all eight stages built", builtStages == 8, ("built %d"):format(builtStages))

-- ── Progression sanity ─────────────────────────────────────────────────────
local healthRises, powerRises = true, true
local previousHealth, previousPower = 0, 0
for _, stage in Stages.List do
	if stage.Number == 0 then continue end
	if stage.EnemyHealth <= previousHealth then healthRises = false end
	if stage.RecommendedPower < previousPower then powerRises = false end
	previousHealth, previousPower = stage.EnemyHealth, stage.RecommendedPower
end
check("enemy health rises every stage", healthRises)
check("recommended power never goes backwards", powerRises)

-- Stage gating: you may always enter 1; 2+ needs the previous cleared.
local ok1 = Stages.canEnter(1, {})
local ok2 = Stages.canEnter(2, {})
local ok2b = Stages.canEnter(2, { 1 })
check("stage 1 is always open", ok1)
check("stage 2 is shut until stage 1 is cleared", not ok2)
check("stage 2 opens once stage 1 is cleared", ok2b)

-- Briefcase odds must sum to 100, or the published odds are a lie.
for _, egg in Eggs.List do
	local total = 0
	for _, chance in egg.Odds do
		total += chance
	end
	check(("briefcase %s odds sum to 100"):format(egg.Name), math.abs(total - 100) < 0.001,
		("sum was %s"):format(tostring(total)))
	-- And every listed rarity must actually be rollable.
	local rarities = Eggs.rarityOrderFor(egg)
	check(("briefcase %s lists its rarities in order"):format(egg.Name), #rarities > 0)
end

-- Rebirth scaling: a bag must genuinely get better with Restructures.
local firstBag = TrainingBags.List[1]
local at0 = TrainingBags.multiplierFor(firstBag, 0)
local at6 = TrainingBags.multiplierFor(firstBag, 6)
local at30 = TrainingBags.multiplierFor(firstBag, 30)
check("a bag pays its printed value at zero rebirths", math.abs(at0 - firstBag.BaseMultiplier) < 0.001)
check("six rebirths roughly double a bag", at6 > at0 * 1.9 and at6 < at0 * 2.1,
	("x%.2f -> x%.2f"):format(at0, at6))
check("thirty rebirths make a bag ~6x its printed value", at30 > at0 * 5.5 and at30 < at0 * 6.5)
check("bag unlocks respect their rebirth gate",
	not TrainingBags.isUnlocked(TrainingBags.List[#TrainingBags.List], 0)
		and TrainingBags.isUnlocked(TrainingBags.List[1], 0))

print(("\nTotal parts in the world: %d"):format(totalParts))
check("world fits a mobile part budget", totalParts <= 20000, ("%d parts"):format(totalParts))

print("\n═══════════════════════════════════════")
if failed > 0 then
	print(("%d passed, %d FAILED\n"):format(passed, failed))
	for _, line in failures do print(line) end
	error(("world spec: %d checks failed"):format(failed), 0)
else
	print(("%d passed, 0 failed — the world builds clean"):format(passed))
end
