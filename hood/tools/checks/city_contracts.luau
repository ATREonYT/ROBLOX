-- city_contracts.luau: World 2's map (ServerStorage.TheCity, assembled by tools/map/city_assemble.sh) builds offline and
-- carries the same contracts as TheBlockV2: the root's HoodWorld = 2 / Active / Origin / LobbySpawn / LobbySpawnYaw,
-- and (Oct 27 round 3: World 1's size) the whole track: 15 avenue stages and the rooftop (Stage 16). Every gate 1-16
-- (Stage, WallId HoodW2Stage<i>, Required = Config/Balance.Worlds[2].StagePower[i], LineZ 64 apart, HalfWidth), the
-- HoodStagePad pair for every stage 1-16, one HoodFightPad per stage (16 the boss's), a crew for every stage
-- (EnemyRules.world from the gates, as WaveService builds it) standing on the floor in open air inside its stage, the
-- crews' hangouts on the 15 streets, the rooftop with the Champ Ring's lane, the lobby's Training_<Id> stations and slots.
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
local RS = game:GetService('ReplicatedStorage')
local Balance = require(RS.Shared.Config.Balance)
local W2 = Balance.Worlds and Balance.Worlds[2] and Balance.Worlds[2].StagePower or {}
local function tagged(tag) local r = {}; for _, d in root:GetDescendants() do if d:HasTag(tag) then table.insert(r, d) end end; return r end
check('HoodWorld = 2', root:GetAttribute('HoodWorld') == 2)
check('Active', root:GetAttribute('Active') == true)
check('Origin', typeof(root:GetAttribute('Origin')) == 'Vector3')
check('LobbySpawn', typeof(root:GetAttribute('LobbySpawn')) == 'Vector3')
check('LobbySpawnYaw', type(root:GetAttribute('LobbySpawnYaw')) == 'number')
check('parts built', type(built) == 'table' and (built.parts or 0) > 1000)
-- the gates: 1-15 open the avenue's stages, 16 the rooftop
local gates, models = {}, {}
for _, g in tagged('HoodStageGate') do gates[g:GetAttribute('Stage') or 0] = g; table.insert(models, g) end
local lastZ = nil
for i = 1, 16 do
	local g = gates[i]
	check('gate ' .. i, g ~= nil)
	if g then
		check('gate ' .. i .. ' WallId', g:GetAttribute('WallId') == 'HoodW2Stage' .. i)
		local req = g:GetAttribute('Required')
		check('gate ' .. i .. ' Required = World 2 StagePower', type(req) == 'number' and req > 0 and math.floor(req + 0.5) == W2[i])
		local z = g:GetAttribute('LineZ')
		check('gate ' .. i .. ' LineZ 64 north of the last', type(z) == 'number' and (lastZ == nil and z == 0 or lastZ ~= nil and math.abs(lastZ - z - 64) < 0.01))
		lastZ = type(z) == 'number' and z or lastZ
		check('gate ' .. i .. ' HalfWidth', type(g:GetAttribute('HalfWidth')) == 'number' and g:GetAttribute('HalfWidth') > 0)
		if i > 1 then check('Required grows at gate ' .. i, gates[i - 1] and req > (gates[i - 1]:GetAttribute('Required') or math.huge)) end
	end
end
check('gates 1-16 only', gates[17] == nil and #models == 16)
-- the pads (each gate's pair pays for the stage before it; the rooftop's pair for Stage 16) and the fight markers
local padStages = {}
for _, p in tagged('HoodStagePad') do
	check('stage pad is a part', p:IsA('BasePart'))
	padStages[p:GetAttribute('Stage') or 0] = (padStages[p:GetAttribute('Stage') or 0] or 0) + 1
end
for i = 1, 16 do check('stage pads for stage ' .. i, (padStages[i] or 0) >= 2) end
local fights = {}
for _, f in tagged('HoodFightPad') do fights[f:GetAttribute('Fight') or 0] = f end
for i = 1, 16 do check('fight pad ' .. i, fights[i] ~= nil) end
check('the map\'s fight list ends with the boss (16)', V2.Fights and #V2.Fights == 16 and V2.Fights[16].Boss == true)
-- the crews, as WaveService builds them from the gates: one for every stage, each goon on the floor in open air
-- (no collidable part round its middle, a floor under its feet), inside its stage's stretch
local EnemyRules = require(RS.Shared.EnemyRules)
local StageRules = require(RS.Shared.StageRules)
local world, arenas = EnemyRules.world(StageRules.fromModels(models))
local O = CFrame.new(root:GetAttribute('Origin') or Vector3.zero)
local solids = {}
for _, p in root:GetDescendants() do
	if p:IsA('BasePart') and p.CanCollide then table.insert(solids, p) end
end
local function inside(p, w)
	local l = p.CFrame:PointToObjectSpace(w)
	local h = p.Size / 2
	return math.abs(l.X) <= h.X and math.abs(l.Y) <= h.Y and math.abs(l.Z) <= h.Z
end
local function blockedAt(x, z, y)
	local w = O:PointToWorldSpace(Vector3.new(x, y, z))
	for _, p in solids do
		if p.Transparency < 1 and inside(p, w) then return p.Name end
	end
	return nil
end
local function floorAt(x, z)
	local w = O:PointToWorldSpace(Vector3.new(x, 0, z))
	for _, p in solids do
		if p.Transparency < 1 then
			local l = p.CFrame:PointToObjectSpace(w)
			local h = p.Size / 2
			if math.abs(l.X) <= h.X and math.abs(l.Z) <= h.Z and l.Y <= h.Y + 1.2 and l.Y >= h.Y - 1.2 then return true end
		end
	end
	return false
end
local bad = {}
for i = 1, 16 do
	local crew = world[i]
	check('a crew on stage ' .. i, crew ~= nil and #crew > 0)
	for k, e in crew or {} do
		local a = arenas[i]
		local inStage = a and e.Home.Z <= a.Z0 and e.Home.Z >= a.Z1 and math.abs(e.Home.X) <= a.X
		local hit = blockedAt(e.Home.X, e.Home.Z, 2.5) or blockedAt(e.Home.X, e.Home.Z, 4.5)
		if not inStage or hit or not floorAt(e.Home.X, e.Home.Z) then
			table.insert(bad, ('%d.%d %s(%.1f,%.1f)'):format(i, k, hit or (not inStage and 'out' or 'nofloor'), e.Home.X, e.Home.Z))
		end
	end
end
check('every goon stands in open air on the floor of its stage' .. (#bad > 0 and (' [' .. table.concat(bad, ' ') .. ']') or ''), #bad == 0)
local hangouts = root:FindFirstChild('Waves', true)
local nh = 0
if hangouts then for i = 1, 15 do if hangouts:FindFirstChild('Hangout' .. i) then nh += 1 end end end
check('the crews\' hangouts on the 15 streets', nh == 15)
for i = 1, 15 do check('stage ' .. i .. ' built', root:FindFirstChild('Stage' .. i, true) ~= nil) end
-- the rooftop (Stage 16): its group, the Champ Ring's lane on it, the CEO tower
local roof = root:FindFirstChild('Rooftop', true)
check('the rooftop (Stage 16)', roof ~= nil and roof:GetAttribute('Stage') == 16)
check('the Champ Ring\'s lane on the rooftop', roof ~= nil and roof:FindFirstChild('Training_Ring', true) ~= nil and roof:FindFirstChild('TrainingZone', true) ~= nil)
check('the CEO tower', roof ~= nil and roof:FindFirstChild('CEOTower', true) ~= nil)
-- the lobby
local training = 0
for _, d in root:GetDescendants() do if d:IsA('Model') and d.Name:sub(1, 9) == 'Training_' then training += 1 end end
check('Training stations (8+)', training >= 8)
local slots = V2.Lobby and V2.Lobby.Slots or {}
for _, s in { 'Spawn', 'NorthDoor', 'World1Portal', 'Leaderboard1', 'Leaderboard2', 'Leaderboard3' } do check('slot ' .. s, typeof(slots[s]) == 'CFrame') end
-- (round 3, the owner: "make the leaderboards not be behind each other") the boards in one straight row
local b1, b2, b3 = slots.Leaderboard1, slots.Leaderboard2, slots.Leaderboard3
check('the boards in one straight row, 12+ apart', b1 and b2 and b3 and math.abs(b1.Position.Z - b2.Position.Z) < 0.01 and math.abs(b2.Position.Z - b3.Position.Z) < 0.01
	and math.abs(b2.Position.X - b1.Position.X) >= 12 and math.abs(b3.Position.X - b2.Position.X) >= 12)
check('spawn location', root:FindFirstChildWhichIsA('SpawnLocation', true) ~= nil)
check('portal back to the hood', root:FindFirstChild('World1Portal', true) ~= nil and root:FindFirstChild('World1Portal', true):GetAttribute('TravelWorld') == 1)
check('shoe boxes', #tagged('HoodShoeBoxes') == 1)
print('[city] ' .. n .. ' checks / ' .. #failed .. ' failed' .. (#failed > 0 and (': ' .. table.concat(failed, ', ')) or ''))
return { checks = n, failed = failed, parts = built and built.parts, training = training }
