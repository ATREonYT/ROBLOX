-- ═══════════════════════════════════════════════════════════════════════════
-- BOOT SPEC — runs the ENTIRE server startup: every service's Init() then
-- Start(), in the exact order Main.server.luau uses. This is the test that
-- answers "does pressing Play produce a world?", because a single service
-- erroring in Init kills the script and leaves the map unbuilt.
-- ═══════════════════════════════════════════════════════════════════════════

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

print("═══ FULL SERVER BOOT ═══\n")

-- Exactly the list and order from Main.server.luau.
local SERVICE_NAMES = {
	"DataService",
	"MapService",
	"ProductivityService",
	"ShopService",
	"RestructureService",
	"MonetizationService",
	"RankService",
	"FloorService",
	"AppearanceService",
	"RivalService",
	"InternService",
	"LeaderboardService",
}

-- Requiring each module is itself a failure point: a syntax or top-level
-- error here takes the whole server down before anything runs.
local services = {}
local allRequired = true
for _, name in SERVICE_NAMES do
	local ok, mod = pcall(__require, name)
	check(("require %s"):format(name), ok, tostring(mod))
	if ok then
		table.insert(services, { Name = name, Module = mod })
	else
		allRequired = false
	end
end

local Net = __require("Net")
local okNet = pcall(function() Net.Start() end)
check("Net.Start()", okNet)

-- Phase 1: Init
for _, entry in services do
	if entry.Module.Init then
		local ok, err = pcall(function() entry.Module:Init() end)
		check(("%s:Init()"):format(entry.Name), ok, tostring(err))
	end
end

-- Phase 2: Start
for _, entry in services do
	if entry.Module.Start then
		local ok, err = pcall(function() entry.Module:Start() end)
		check(("%s:Start()"):format(entry.Name), ok, tostring(err))
	end
end

-- The payoff: after a full boot there must be a world.
local mapFolder = workspace:FindFirstChild("BusinessEvolutionMap")
check("workspace.BusinessEvolutionMap exists after full boot", mapFolder ~= nil)

local parts = 0
if mapFolder then
	for _, inst in mapFolder:GetDescendants() do
		if inst:IsA("BasePart") then parts += 1 end
	end
end
check(("the tower is in workspace (%d parts)"):format(parts), parts > 8000,
	("only %d parts — the map did not build"):format(parts))

local MapService = __require("MapService")
local count = 0
for _ in MapService.allManifests() do count += 1 end
check("all six floors registered", count == 6, ("got %d"):format(count))

check("every service module loaded", allRequired)

print("\n═══════════════════════════════════════")
if failed > 0 then
	error(("boot spec: %d of %d checks failed"):format(failed, passed + failed), 0)
else
	print(("%d passed, 0 failed — the server boots the full game"):format(passed))
end
