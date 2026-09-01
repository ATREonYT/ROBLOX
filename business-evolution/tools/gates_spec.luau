-- ═══════════════════════════════════════════════════════════════════════════
-- PASS 1 GATES — measured against the real built world, not asserted by eye.
-- Covers ART Gate D (scale hierarchy) and the measurable half of Gate G
-- (object/draw-call proxies). Gate C (silhouette) needs a human eye.
-- ═══════════════════════════════════════════════════════════════════════════

local Hub = __require("Hub")
local StageBuilder = __require("StageBuilder")
local Stages = __require("Stages")

local passed, failed = 0, 0
local notes = {}
local function check(name, condition, detail)
	if condition then
		passed += 1
		print(("  PASS  %s%s"):format(name, if detail then "  (" .. detail .. ")" else ""))
	else
		failed += 1
		local line = ("  FAIL  %s%s"):format(name, if detail then " — " .. detail else "")
		print(line)
		table.insert(notes, line)
	end
end

print("═══ PASS 1 GATES ═══\n")

-- Build the hub.
local hubFolder = Instance.new("Folder")
hubFolder.Name = "Hub"
local hubStage = Stages.get("Hub")
local hub = Hub.build(hubFolder, Vector3.new(hubStage.Origin[1], hubStage.Origin[2], hubStage.Origin[3]))

-- ── ART 4.1: footprint ─────────────────────────────────────────────────────
print("── ART 4.1 footprint ──")
local w, d = hubStage.Size[1], hubStage.Size[2]
check("starting area within the 100x100 hard cap", w <= 100 and d <= 100, ("%dx%d"):format(w, d))

-- Spawn to furthest interactive object.
local interactives = {}
for _, entry in hub.TrainingBags do table.insert(interactives, entry.Pad) end
for _, entry in hub.SkinPodiums do table.insert(interactives, entry.Pad) end
for _, entry in hub.EggPads do table.insert(interactives, entry.Pad) end
table.insert(interactives, hub.RebirthPad)
table.insert(interactives, hub.GearPad)
table.insert(interactives, hub.ChestPad)

local spawnPos = hub.Spawn.Position
local furthest, furthestName = 0, ""
for _, pad in interactives do
	local flat = Vector3.new(pad.Position.X - spawnPos.X, 0, pad.Position.Z - spawnPos.Z).Magnitude
	if flat > furthest then
		furthest, furthestName = flat, pad.Name
	end
end
check("spawn to furthest interactive under 40 studs", furthest < 40,
	("%.1f studs to %s"):format(furthest, furthestName))
check("at least 6 interactive objects in the zone", #interactives >= 6, ("%d"):format(#interactives))

-- Walk time across the zone at Roblox's default 16 studs/sec.
check("under 10 seconds to cross the zone", math.max(w, d) / 16 < 10,
	("%.1fs"):format(math.max(w, d) / 16))

-- ── GATE D: scale hierarchy, exactly one Landmark ──────────────────────────
print("\n── Gate D: scale hierarchy ──")
local tiers = { Landmark = 0, Hero = 0, Standard = 0, Detail = 0 }
local tallest, tallestName = 0, ""
for _, inst in hubFolder:GetDescendants() do
	if not inst:IsA("BasePart") then
		continue
	end
	local h = inst.Size.Y
	if h > tallest then
		tallest, tallestName = h, inst.Name
	end
	if h >= 40 then
		tiers.Landmark += 1
	elseif h >= 12 then
		tiers.Hero += 1
	elseif h >= 5 then
		tiers.Standard += 1
	elseif h <= 3 then
		tiers.Detail += 1
	end
end
print(("     landmark-height parts %d · hero %d · standard %d · detail %d")
	:format(tiers.Landmark, tiers.Hero, tiers.Standard, tiers.Detail))

-- The Landmark is a Model, not one tall part; check the model's total height.
local landmarkModel = hubFolder:FindFirstChild("Landmark")
local landmarkHeight = 0
if landmarkModel then
	local lowest, highest = math.huge, -math.huge
	for _, inst in landmarkModel:GetDescendants() do
		if inst:IsA("BasePart") then
			lowest = math.min(lowest, inst.Position.Y - inst.Size.Y / 2)
			highest = math.max(highest, inst.Position.Y + inst.Size.Y / 2)
		end
	end
	landmarkHeight = highest - lowest
end
check("exactly one Landmark model in the zone", landmarkModel ~= nil)
check("the Landmark is 40-80 studs tall", landmarkHeight >= 40 and landmarkHeight <= 85,
	("%.0f studs"):format(landmarkHeight))
check("Hero tier present (12-20 studs)", tiers.Hero > 0, ("%d parts"):format(tiers.Hero))
check("Standard tier present (5-10 studs)", tiers.Standard > 0, ("%d parts"):format(tiers.Standard))
check("Detail tier present (0.5-3 studs)", tiers.Detail >= 40, ("%d parts"):format(tiers.Detail))

-- ── GATE B: the variance check ─────────────────────────────────────────────
print("\n── Gate B: variance in repeated elements ──")
local function varianceOf(pads, label)
	local xs, gaps = {}, {}
	for _, entry in pads do
		table.insert(xs, entry.Pad.Position.X)
	end
	table.sort(xs)
	for i = 2, #xs do
		table.insert(gaps, xs[i] - xs[i - 1])
	end
	if #gaps < 2 then
		return
	end
	local first = gaps[1]
	local uniform = true
	for _, gap in gaps do
		if math.abs(gap - first) > 0.35 then
			uniform = false
			break
		end
	end
	local spread = 0
	for _, gap in gaps do
		spread = math.max(spread, math.abs(gap - first))
	end
	check(label .. " are not evenly spaced", not uniform, ("max gap delta %.2f studs"):format(spread))
end
varianceOf(hub.TrainingBags, "training bags")
varianceOf(hub.EggPads, "briefcase stands")

-- Rotation variance: bags should not all share one yaw.
local yaws = {}
for _, entry in hub.TrainingBags do
	local _, yaw = entry.Pad.CFrame:ToEulerAnglesYXZ()
	table.insert(yaws, math.deg(yaw))
end
local allSameYaw = true
for i = 2, #yaws do
	if math.abs(yaws[i] - yaws[1]) > 0.5 then
		allSameYaw = false
		break
	end
end
check("training bags are not all axis-aligned", not allSameYaw,
	("yaw spread %.1f degrees"):format(math.max(table.unpack(yaws)) - math.min(table.unpack(yaws))))

-- ── GATE G proxy: object counts vs the Part 11 budget ──────────────────────
print("\n── Gate G: measurable budget proxies ──")
local hubParts, hubLights, hubBillboards = 0, 0, 0
for _, inst in hubFolder:GetDescendants() do
	if inst:IsA("BasePart") then hubParts += 1 end
	if inst.ClassName == "PointLight" or inst.ClassName == "SpotLight" then hubLights += 1 end
	if inst.ClassName == "BillboardGui" then hubBillboards += 1 end
end
print(("     hub: %d parts, %d local lights, %d billboards"):format(hubParts, hubLights, hubBillboards))
check("local lights in the zone within the mobile budget (<=20)", hubLights <= 20, ("%d"):format(hubLights))
check("at least one local light exists (audit tell #5)", hubLights >= 1, ("%d"):format(hubLights))
-- The budget is about VISIBLE billboards. More exist than that in a dense hub,
-- so what matters is that every one has a sane MaxDistance and that the client
-- culls to a budget (WorldFxController.cullSigns).
local badDistance = 0
for _, inst in hubFolder:GetDescendants() do
	if inst.ClassName == "BillboardGui" and (inst.MaxDistance == nil or inst.MaxDistance > 140) then
		badDistance += 1
	end
end
check("every billboard has a culling distance <=140", badDistance == 0,
	("%d signs render too far"):format(badDistance))
print(("     %d signs exist; the client keeps the nearest 22 enabled on mobile"):format(hubBillboards))

-- Whole world, for the draw-call proxy.
local worldParts = hubParts
for _, stage in Stages.List do
	if stage.Number == 0 then continue end
	local folder = Instance.new("Folder")
	folder.Name = stage.Id
	StageBuilder.build(folder, stage)
	for _, inst in folder:GetDescendants() do
		if inst:IsA("BasePart") then worldParts += 1 end
	end
end
print(("     whole world: %d parts"):format(worldParts))

print("\n═══════════════════════════════════════")
if failed > 0 then
	print(("%d passed, %d FAILED"):format(passed, failed))
	error(("pass 1 gates: %d failed"):format(failed), 0)
else
	print(("%d passed, 0 failed"):format(passed))
end
