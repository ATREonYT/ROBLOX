-- place_gates: the built place files keep every gate's Required Power exactly (Oct 27: Lune wrote whole numbers past
-- 2^31 as 32-bit integers, so World 2's gates 4-16 came out negative in HoodEvolution_World2.rbxl; Shared/BigAttr keeps
-- them as digits). Opens hood/places/HoodEvolution.rbxl (World 1) and HoodEvolution_World2.rbxl (World 2), finds the
-- gates (WallId HoodW<world>Stage<i>) and checks each Required against Config/Balance's StagePower for that world.
-- Run by run_checks.sh through harness_unit (it sets PLACES_DIR): "[places] N checks / 0 failed".
local roblox, fs = __roblox, __fs
local BigAttr = require(game.ReplicatedStorage.Shared.BigAttr)
local Balance = require(game.ReplicatedStorage.Shared.Config.Balance)
local n, failed = 0, {}
local function check(name, ok)
	n += 1
	if not ok then table.insert(failed, name); print('[places] FAIL ' .. name) end
end
for _, p in { { 1, 'HoodEvolution.rbxl' }, { 2, 'HoodEvolution_World2.rbxl' } } do
	local world, file = p[1], PLACES_DIR .. '/' .. p[2]
	local want = Balance.Worlds[world] and Balance.Worlds[world].StagePower or {}
	local okRead, place = pcall(function() return roblox.deserializePlace(fs.readFile(file)) end)
	check(p[2] .. ' opens', okRead)
	if okRead then
		local gates = {}
		for _, d in place:GetDescendants() do
			local id = d:GetAttribute('WallId')
			local i = type(id) == 'string' and tonumber(id:match('^HoodW' .. world .. 'Stage(%d+)$'))
			if i then gates[i] = d end
		end
		for i = 1, #want do
			local g = gates[i]
			local got = g and BigAttr.get(g, 'Required')
			check(('%s gate %d Required = %s (got %s)'):format(p[2], i, string.format('%.0f', want[i]), tostring(got)), type(got) == 'number' and got == want[i])
		end
	end
end
print(('[places] %d checks / %d failed'):format(n, #failed))
return { checks = n, failed = #failed }
