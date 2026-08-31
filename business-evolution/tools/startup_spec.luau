-- ═══════════════════════════════════════════════════════════════════════════
-- STARTUP SPEC — runs MapService:Init() exactly as the server does on boot.
-- The map spec builds floor modules directly; this proves the thing that
-- ACTUALLY runs when you press Play produces a world.
-- ═══════════════════════════════════════════════════════════════════════════

local MapService = __require("MapService")
local FloorsConfig = __require("Floors")

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
	MapService:Init()
end)
check("MapService:Init() runs without error", ok, tostring(err))
if not ok then
	error("startup spec: the server would fail to boot", 0)
end

local mapFolder = workspace:FindFirstChild("BusinessEvolutionMap")
check("workspace.BusinessEvolutionMap exists", mapFolder ~= nil)
if not mapFolder then
	error("startup spec: no map folder in workspace", 0)
end

-- Every configured floor must have produced a populated folder.
local totalParts = 0
for _, floorDef in FloorsConfig.List do
	local folder = mapFolder:FindFirstChild(floorDef.Id)
	local parts = 0
	if folder then
		for _, inst in folder:GetDescendants() do
			if inst:IsA("BasePart") then parts += 1 end
		end
	end
	totalParts += parts
	check(("floor %s built into workspace (%d parts)"):format(floorDef.Id, parts),
		folder ~= nil and parts > 400,
		if folder == nil then "folder missing — MapService skipped it" else ("only %d parts"):format(parts))
end
check(("the whole tower is in workspace (%d parts)"):format(totalParts), totalParts > 8000)

-- Manifests must be registered, or every gameplay service reads an empty world.
local manifests = MapService.allManifests()
local manifestCount = 0
for _ in manifests do manifestCount += 1 end
check("all six manifests registered", manifestCount == 6, ("got %d"):format(manifestCount))

-- The spawn: without it players fall forever.
local spawn = mapFolder:FindFirstChild("MainSpawn")
check("a SpawnLocation exists", spawn ~= nil and spawn.ClassName == "SpawnLocation")

-- Prompts: the Hud opens every panel off these names.
local promptNames = {}
for _, inst in mapFolder:GetDescendants() do
	if inst.ClassName == "ProximityPrompt" then
		promptNames[inst.Name] = (promptNames[inst.Name] or 0) + 1
	end
end
for _, wanted in { "OpenShop", "OpenCoffee", "OpenHr", "OpenElevator" } do
	check(("%s prompt attached on all six floors"):format(wanted),
		promptNames[wanted] == 6, ("found %d"):format(promptNames[wanted] or 0))
end

print("\n═══════════════════════════════════════")
if failed > 0 then
	error(("startup spec: %d of %d checks failed"):format(failed, passed + failed), 0)
else
	print(("%d passed, 0 failed — the server boots a full world"):format(passed))
end
