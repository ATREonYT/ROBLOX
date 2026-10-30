--!strict
-- Offline test entry point. Runs with the plain Luau CLI (no Roblox APIs):
--
--   cd business-evolution && luau tests/run.luau
--
-- Specs only require the pure Config/Util modules, because those are the only
-- modules that never touch `game` — everything service-shaped needs a real
-- DataModel and is exercised in Studio instead.

type Case = { name: string, run: () -> () }
type Spec = { name: string, cases: { Case } }

local configSpec = require("./config_spec") :: Spec
local pacingSim = require("./pacing_sim") :: Spec

local specs: { Spec } = { configSpec, pacingSim }

local passed = 0
local failed = 0
local failures: { string } = {}

for _, spec in specs do
	print(("== %s =="):format(spec.name))
	for _, case in spec.cases do
		-- pcall so one broken case never hides the results of the rest. The
		-- cast widens the return type so the error slot type-checks.
		local ok, err = pcall(case.run :: () -> any)
		if ok then
			passed += 1
			print(("  PASS  %s"):format(case.name))
		else
			failed += 1
			local label = ("%s / %s"):format(spec.name, case.name)
			table.insert(failures, label)
			print(("  FAIL  %s"):format(case.name))
			print(("        %s"):format(tostring(err)))
		end
	end
end

print("")
print(("%d passed, %d failed"):format(passed, failed))

if failed > 0 then
	-- error() makes the CLI exit non-zero so CI can gate on this script.
	error(("test failures: %s"):format(table.concat(failures, "; ")), 0)
end
