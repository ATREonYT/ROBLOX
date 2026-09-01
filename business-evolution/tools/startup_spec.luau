-- ═══════════════════════════════════════════════════════════════════════════
-- STARTUP SPEC — runs WorldService:Init() exactly as the server does on boot.
-- The map spec builds floor modules directly; this proves the thing that
-- ACTUALLY runs when you press Play produces a world.
-- ═══════════════════════════════════════════════════════════════════════════

local WorldService = __require("WorldService")
local Stages = __require("Stages")

local passed, failed = 0, 0
local function check(name, condition, detail)
	if condition then
		passed += 1
		print(("  PASS  %s"):format(name))
	else
		failed += 1
		print(("  FAIL  %s%s"):format(name, if detail then " — " .. detail else ""))
	end
end

print("═══ SERVER STARTUP (MapService:Init) ═══\n")

local ok, err = pcall(function()
	WorldService:Init()
end)
check("WorldService:Init() runs without error", ok, tostring(err))
if not ok then
	error("startup spec: the server would fail to boot", 0)
end

local mapFolder = workspace:FindFirstChild("BusinessEvolutionWorld")
check("workspace.BusinessEvolutionWorld exists", mapFolder ~= nil)
if not mapFolder then
	error("startup spec: no map folder in workspace", 0)
end

-- Hub plus every stage must have produced a populated folder.
local totalParts = 0
for _, stage in Stages.List do
	local folder = mapFolder:FindFirstChild(if stage.Number == 0 then "Hub" else stage.Id)
	local parts = 0
	if folder then
		for _, inst in folder:GetDescendants() do
			if inst:IsA("BasePart") then parts += 1 end
		end
	end
	totalParts += parts
	check(("%s built into workspace (%d parts)"):format(stage.DisplayName, parts),
		folder ~= nil and parts > 200,
		if folder == nil then "folder missing" else ("only %d parts"):format(parts))
end
check(("the whole world is in workspace (%d parts)"):format(totalParts), totalParts > 4000)

-- Manifests must be registered, or every gameplay service reads an empty world.
local manifestCount = 0
for _ in WorldService.allStages() do manifestCount += 1 end
check("all eight stage manifests registered", manifestCount == 8, ("got %d"):format(manifestCount))
check("hub manifest registered", WorldService.hub() ~= nil)

-- The spawn: without it players fall forever.
local spawn = mapFolder:FindFirstChild("MainSpawn")
check("a SpawnLocation exists", spawn ~= nil and spawn.ClassName == "SpawnLocation")

-- ── The passes: no gaps in the walkable road ───────────────────────────────
-- Before these existed you could walk east out of the hub and fall out of the
-- world, so this checks the ground is genuinely continuous.
local passes = mapFolder:FindFirstChild("Passes")
check("connecting passes were built", passes ~= nil)
if passes then
	local passParts = 0
	for _, inst in passes:GetDescendants() do
		if inst:IsA("BasePart") then passParts += 1 end
	end
	check(("passes have geometry (%d parts)"):format(passParts), passParts > 400)

	-- Walk the world west to east and confirm ground exists at every step.
	local spans = {}
	for _, inst in mapFolder:GetDescendants() do
		if inst:IsA("BasePart") and (inst.Name == "Ground" or inst.Name == "PassGround") then
			local halfX = inst.Size.X / 2
			table.insert(spans, { inst.CFrame.X - halfX, inst.CFrame.X + halfX })
		end
	end
	-- Sample between the real world edges, derived from config, so the range
	-- follows the map when footprints change.
	local westEdge, eastEdge = math.huge, -math.huge
	for _, stage in Stages.List do
		westEdge = math.min(westEdge, stage.Origin[1] - stage.Size[1] / 2)
		eastEdge = math.max(eastEdge, stage.Origin[1] + stage.Size[1] / 2)
	end
	local gaps = 0
	local firstGapAt = nil
	for x = westEdge + 5, eastEdge - 5, 10 do
		local covered = false
		for _, span in spans do
			if x >= span[1] - 0.5 and x <= span[2] + 0.5 then
				covered = true
				break
			end
		end
		if not covered then
			gaps += 1
			if firstGapAt == nil then firstGapAt = x end
		end
	end
	check("the road is continuous from hub to the last stage", gaps == 0,
		if firstGapAt then ("first hole in the ground at x=%d (%d sample points uncovered)"):format(firstGapAt, gaps) else "")
end

-- Every stage needs its barrier and both cash-out pads reachable in world.
local padsOk, barriersOk = true, true
for stageNumber, manifest in WorldService.allStages() do
	if manifest.BigPad == nil or manifest.ReturnPad == nil then padsOk = false end
	if manifest.Barrier == nil then barriersOk = false end
end
check("every stage has both cash-out pads", padsOk)
check("every stage has a barrier", barriersOk)

print("\n═══════════════════════════════════════")
if failed > 0 then
	error(("startup spec: %d of %d checks failed"):format(failed, passed + failed), 0)
else
	print(("%d passed, 0 failed — the server boots a full world"):format(passed))
end
