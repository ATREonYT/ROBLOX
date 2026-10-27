-- city_contracts.luau: World 2's map (ServerStorage.TheCity, assembled by tools/map/city_assemble.sh) builds offline and
-- carries the same contracts as TheBlockV2: the root's HoodWorld = 2 / Active / Origin / LobbySpawn / LobbySpawnYaw,
-- the HoodStageGate models of the slice's stages (Stage, WallId HoodW2Stage<i>, Required, LineZ, HalfWidth), the
-- HoodStagePad parts on gates 2-3, one HoodFightPad per stage, the lobby's Training_<Id> stations and slots.
-- Run (run_checks.sh does): lune run harness_unit.luau <src> - "$(cat city_contracts.luau)"
-- Prints "[city] N checks / M failed" and returns the failures.
local V2 = require(game.ServerStorage.TheCity)
local built = V2.Build()
local root = workspace:FindFirstChild('TheCity')
local n, failed = 0, {}
local function check(name, ok)
	n += 1
	if not ok then table.insert(failed, name) end
end
check('root TheCity in Workspace', root ~= nil)
if not root then
	print('[city] ' .. n .. ' checks / ' .. #failed .. ' failed')
	return { failed = failed }
end
local function tagged(tag) local r = {}; for _, d in root:GetDescendants() do if d:HasTag(tag) then table.insert(r, d) end end; return r end
check('HoodWorld = 2', root:GetAttribute('HoodWorld') == 2)
check('Active', root:GetAttribute('Active') == true)
check('Origin', typeof(root:GetAttribute('Origin')) == 'Vector3')
check('LobbySpawn', typeof(root:GetAttribute('LobbySpawn')) == 'Vector3')
check('LobbySpawnYaw', type(root:GetAttribute('LobbySpawnYaw')) == 'number')
check('parts built', type(built) == 'table' and (built.parts or 0) > 1000)
-- the gates
local gates = {}
for _, g in tagged('HoodStageGate') do gates[g:GetAttribute('Stage') or 0] = g end
local lastZ = math.huge
for i = 1, 3 do
	local g = gates[i]
	check('gate ' .. i, g ~= nil)
	if g then
		check('gate ' .. i .. ' WallId', g:GetAttribute('WallId') == 'HoodW2Stage' .. i)
		local req = g:GetAttribute('Required')
		check('gate ' .. i .. ' Required', type(req) == 'number' and req > 0)
		local z = g:GetAttribute('LineZ')
		check('gate ' .. i .. ' LineZ north of the last', type(z) == 'number' and z < lastZ)
		lastZ = type(z) == 'number' and z or lastZ
		check('gate ' .. i .. ' HalfWidth', type(g:GetAttribute('HalfWidth')) == 'number' and g:GetAttribute('HalfWidth') > 0)
	end
end
check('gates 1-3 only', gates[4] == nil)
check('Required grows', gates[1] and gates[2] and gates[2]:GetAttribute('Required') > gates[1]:GetAttribute('Required'))
-- the pads on the gates (each pays for the stage before it) and the fight markers
local padStages = {}
for _, p in tagged('HoodStagePad') do
	check('stage pad is a part', p:IsA('BasePart'))
	padStages[p:GetAttribute('Stage') or 0] = (padStages[p:GetAttribute('Stage') or 0] or 0) + 1
end
check('stage pads for stage 1', (padStages[1] or 0) >= 2)
check('stage pads for stage 2', (padStages[2] or 0) >= 2)
local fights = {}
for _, f in tagged('HoodFightPad') do fights[f:GetAttribute('Fight') or 0] = f end
check('fight pad 1', fights[1] ~= nil)
check('fight pad 2', fights[2] ~= nil)
-- the lobby
local training = 0
for _, d in root:GetDescendants() do if d:IsA('Model') and d.Name:sub(1, 9) == 'Training_' then training += 1 end end
check('Training stations (8+)', training >= 8)
local slots = V2.Lobby and V2.Lobby.Slots or {}
for _, s in { 'Spawn', 'NorthDoor', 'World1Portal', 'Leaderboard1', 'Leaderboard2', 'Leaderboard3' } do check('slot ' .. s, typeof(slots[s]) == 'CFrame') end
check('spawn location', root:FindFirstChildWhichIsA('SpawnLocation', true) ~= nil)
check('portal back to the hood', root:FindFirstChild('World1Portal', true) ~= nil and root:FindFirstChild('World1Portal', true):GetAttribute('TravelWorld') == 1)
check('shoe boxes', #tagged('HoodShoeBoxes') == 1)
print('[city] ' .. n .. ' checks / ' .. #failed .. ' failed' .. (#failed > 0 and (': ' .. table.concat(failed, ', ')) or ''))
return { checks = n, failed = failed, parts = built and built.parts, training = training }
