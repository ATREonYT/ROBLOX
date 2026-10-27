-- city_play.luau (Oct 27 round 3: World 2 at World 1's size): World 2's whole track played through the REAL server
-- scripts on TheCity (play_run's setup, World 2's place: workspace HoodWorld = 2 before anything reads the economy).
-- Servers: StageService, WaveService, GoalService, TravelService. Clients: Stages, Waves.
--   spawn -> into Stage 1, its crew sent -> beat it, gate 2 opens -> the yellow pad pays World 2's Stage 1 Cash, home
--   -> then a run through every stage: each crew sent as you walk in, beaten, the next gate opened for the run, up to
--   gate 16 and the rooftop -> The CEO's crew (Stage 16) beaten -> the rooftop's pad pays Stage 16's Cash
--   -> the Stage 1 and Lobby trips.
-- Run (run_checks.sh does): lune run harness_play.luau <src> - "$(cat city_play.luau)"; prints "[play] N checks, M failed".
workspace:SetAttribute('HoodWorld', 2)
local RS = game.ReplicatedStorage
local Players = game:GetService('Players')
local Schema = require(game.ServerScriptService.HoodServer.ProfileSchema)
local Art = require(RS.Shared.SkinArt)
local PadRules = require(RS.Shared.PadRules)
local Balance = require(RS.Shared.Config.Balance)
_G.__screenSize = Vector2.new(1200, 617)
local V2 = require(game.ServerStorage.TheCity)
V2.Build()
local net = Instance.new('Folder'); net.Name = 'HoodNet'; net.Parent = RS
for _, n in { 'EquipSkin', 'ProfileUpdated', 'Notice', 'Rebirth', 'Cinematic', 'Shoot', 'BuyGun', 'EquipGun', 'WaveShot', 'WaveState', 'Goal', 'Travel', 'OpenShoeBox', 'ShoeAction', 'ShoeOpened', 'Revive' } do
	local e = Instance.new('RemoteEvent'); e.Name = n; e.Parent = net
end
local rf = Instance.new('RemoteFunction'); rf.Name = 'RequestSnapshot'; rf.Parent = net
RS:SetAttribute('FoundationReady', true)
local cam = Instance.new('Camera'); cam.Name = 'Camera'; cam.FieldOfView = 70; cam.CFrame = CFrame.new(2400, 20, 120)
pcall(function() cam.ViewportSize = Vector2.new(1200, 675) end)
cam.Parent = workspace; workspace.CurrentCamera = cam
pcall(function()
	local U = game:GetService('UserInputService')
	U.TouchEnabled, U.MouseEnabled, U.KeyboardEnabled, U.GamepadEnabled = false, true, true, false
end)
_G.__prompts = {}
local P = Players.LocalPlayer
if not P then P = Instance.new('Player'); P.Name = 'Tester'; P.Parent = Players; pcall(function() Players.LocalPlayer = P end) end
for _, c in { 'PlayerGui', 'Backpack' } do local x = Instance.new(c); x.Parent = P end
pcall(function() P.DisplayName = 'Tester' end)
local function makeCharacter()
	local char = Instance.new('Model'); char.Name = 'Tester'
	local root = Instance.new('Part'); root.Name = 'HumanoidRootPart'; root.Size = Vector3.new(2, 2, 1); root.Transparency = 1; root.Anchored = true
	root.CFrame = CFrame.new(0, 3, 0); pcall(function() root.Position = Vector3.new(0, 3, 0) end); root.Parent = char
	for seg, b in Art.Rig do
		local p = Instance.new('Part'); p.Name = seg; p.Size = b[1]; p.CFrame = CFrame.new(b[2]); pcall(function() p.Position = b[2] end); p.Anchored = true
		p.Parent = char
	end
	local hum = Instance.new('Humanoid'); hum.MaxHealth = 100; hum.Health = 100; hum.HipHeight = 2; hum.RigType = Enum.HumanoidRigType.R15; hum.WalkSpeed = 16; hum.Parent = char
	char.PrimaryPart = root
	char.Parent = workspace
	P.Character = char
	return char, root, hum
end
local char, root = makeCharacter()
local frameCF = CFrame.new(workspace.TheCity:GetAttribute('Origin') or Vector3.zero)
local function moveTo(cf)
	local delta = cf * root.CFrame:Inverse()
	for _, d in char:GetDescendants() do if d:IsA('BasePart') then d.CFrame = delta * d.CFrame; pcall(function() d.Position = d.CFrame.Position end) end end
end
local function standMap(x, z, yaw, floor) moveTo(frameCF * CFrame.new(x, (floor or 0) + 3, z) * CFrame.Angles(0, yaw or 0, 0)) end
local function mapPos() return frameCF:PointToObjectSpace(root.CFrame.Position) end

local data = Schema.new()
data.Goals = { Step = 1, Synced = true, Chain = require(RS.Shared.GoalRules).Chain }
data.Guns.Owned = { Pistol = true }
_G.__profile = { Data = data }
local fake = Instance.new('Folder'); fake.Name = 'FakeServer'; fake.Parent = game.ServerScriptService
local stub = Instance.new('ModuleScript'); stub.Name = 'DataService'; stub.Parent = fake
stub.Source = "return { get = function() return _G.__profile end, push = function() _G.__pushes = (_G.__pushes or 0) + 1 end }"
local HS = game.ServerScriptService.HoodServer
for _, name in { 'RateLimiter', 'Boosts', 'RebirthService', 'Runs' } do
	local m = Instance.new('ModuleScript'); m.Name = name; m.Source = HS[name].Source; m.Parent = fake
end
local nowhere = Instance.new('Part'); nowhere.Name = 'HarnessNowhere'; nowhere.Anchored = true; nowhere.Transparency = 1
nowhere.CFrame = CFrame.new(0, -20000, 0); pcall(function() nowhere.Position = Vector3.new(0, -20000, 0) end); nowhere.Parent = workspace
_G.__nowhere = nowhere
local function lunePatch(source) return (source:gsub('([%w_%.]+%.Adornee) = nil', '%1 = _G.__nowhere')) end
local function run(src, name, parent)
	local m = Instance.new('ModuleScript'); m.Name = name; m.Source = lunePatch(src.Source); m.Parent = parent
	task.spawn(function()
		local ok, err = pcall(require, m)
		if not ok then print('[play] ' .. name .. ' failed: ' .. tostring(err)) end
	end)
end
P:SetAttribute('ProfileReady', true)
for _, s in { 'StageService', 'WaveService', 'GoalService', 'TravelService' } do run(HS[s], s, fake) end
local HC = game.StarterPlayer.StarterPlayerScripts.HoodClient
for _, c in { 'Stages', 'Waves' } do run(HC[c], c .. 'CUT', HC) end

local CHECKS, FAILS = {}, {}
local function check(name, ok, detail)
	table.insert(CHECKS, (ok and 'ok   ' or 'FAIL ') .. name)
	print('[play] CHECK ' .. (ok and 'ok   ' or 'FAIL ') .. name .. (detail and (' (' .. tostring(detail) .. ')') or ''))
	if not ok then table.insert(FAILS, name) end
end
local seen = {}
local function syncInst(inst)
	local now = inst:GetAttributes()
	local last = seen[inst] or {}
	for k, v in now do if last[k] ~= v then __fireOn(inst, 'Attr_' .. k) end end
	for k in last do if now[k] == nil then __fireOn(inst, 'Attr_' .. k) end end
	seen[inst] = now
end
local function frame()
	__fireOn(game:GetService('RunService'), 'PreRender', 1 / 30)
	for _, fn in table.clone(_G.__bound) do fn(1 / 30) end
	__fireOn(game:GetService('RunService'), 'Heartbeat', 1 / 30)
	__stepTweens(1 / 30)
	task.wait(1 / 30)
	syncInst(P); syncInst(char)
end
local function wall(t)
	local t0 = os.clock()
	while os.clock() - t0 < t do frame() end
end
local function sent(name, kind, from)
	local list = {}
	for i = from or 1, #_G.__toClient do
		local m = _G.__toClient[i]
		if m[1] == name and (not kind or (type(m[2]) == 'table' and m[2].Kind == kind) or m[2] == kind) then table.insert(list, m[2]) end
	end
	return list
end
local function mark() return #_G.__toClient + 1 end
local function attr(n) return P:GetAttribute(n) end
local function state() return ('RunStage=%s RunCleared=%s Cash=%s WaveStage=%s WaveLeft=%s z=%.1f'):format(tostring(attr('RunStage')), tostring(attr('RunCleared')), tostring(data.Cash), tostring(attr('WaveStage')), tostring(attr('WaveLeft')), mapPos().Z) end

-- The map's pieces.
local gatesByStage, padsByStage = {}, {}
for _, m in workspace.TheCity:GetDescendants() do
	if m:HasTag('HoodStageGate') then gatesByStage[m:GetAttribute('Stage')] = m end
	if m:HasTag('HoodStagePad') then
		local s = m:GetAttribute('Stage')
		padsByStage[s] = padsByStage[s] or {}
		padsByStage[s][m:GetAttribute('Kind')] = m
	end
end
local function gateZ(n) return gatesByStage[n]:GetAttribute('LineZ') end
local function onPad(pad)
	local p = frameCF:PointToObjectSpace(pad.CFrame.Position)
	standMap(p.X, p.Z, 0, p.Y + pad.Size.Y / 2)
	__fireOn(pad, 'Touched', char:FindFirstChild('LeftFoot') or root)
end
local spawnZ = (workspace.TheCity:GetAttribute('LobbySpawn') or Vector3.new(0, 0, 45)).Z
local function at(z, tol) return math.abs(mapPos().Z - z) < (tol or 1.5) end
local lastZ = { [16] = gateZ(16) - 96 }
for i = 1, 15 do lastZ[i] = gateZ(i + 1) end

-- Walk into a stage (26 in; the rooftop 64), the crew comes; beat it (Power high: a shot each), the way the client fires.
local function enter(stage)
	local m = mark()
	standMap(0, gateZ(stage) - (stage == 16 and 64 or 26), 0) -- (where play_run fights; the rooftop crew waits further in, by the far parapet)
	wall(0.6)
	return #sent('WaveState', 'Wave', m) >= 1 and attr('WaveStage') == stage and (attr('WaveLeft') or 0) > 0
end
local function beat(stage)
	data.Rep = 1e14
	local before = #sent('WaveState', 'Cleared')
	for _ = 1, 6 do
		for i = 1, 6 do RS.HoodNet.WaveShot:FireServer(stage, i); wall(0.05) end
		wall(0.3)
		if #sent('WaveState', 'Cleared') > before then break end
	end
	wall(0.3)
	local msg = sent('WaveState', 'Cleared')[before + 1]
	return msg ~= nil, msg
end

-------------------------------------------------------------------------------------------- 1. Stage 1 and its pad
standMap(0, spawnZ, 0)
wall(1.2)
check('World 2: the map is TheCity, the economy World 2\'s', workspace:GetAttribute('HoodWorld') == 2 and Balance.World == 2 and Balance.PadCash[1] == Balance.Worlds[2].PadCash[1])
check('fresh run: RunStage 1, RunCleared 0', attr('RunStage') == 1 and attr('RunCleared') == 0, state())
check('the Stage 1 crew is sent as you walk in', enter(1), state())
local ok1, msg1 = beat(1)
check('the Stage 1 crew beaten opens gate 2', ok1 and msg1.Opens == 2 and attr('RunCleared') == 1, state())
local cash0 = data.Cash
onPad(padsByStage[1].Return)
wall(0.8)
check('the yellow pad pays World 2\'s Stage 1 Cash and takes you home', data.Cash - cash0 >= PadRules.reward(1, false) and PadRules.reward(1, false) >= Balance.Worlds[2].PadCash[1] and at(spawnZ, 3), (data.Cash - cash0) .. ' ' .. state())

-------------------------------------------------------------------------------------------- 2. the whole track
local fails = {}
for stage = 1, 16 do
	local inOk = enter(stage)
	local ok, msg = beat(stage)
	local opens = stage < 16 and (msg and msg.Opens == stage + 1) or (stage == 16 and ok)
	if not (inOk and ok and opens and attr('RunCleared') == stage) then table.insert(fails, stage .. ': ' .. state()) end
end
check('every stage 1-16: its crew sent as you walk in, beaten, the next gate opened for the run', #fails == 0, fails[1])
check('the rooftop: The CEO\'s crew (Stage 16) beaten, RunCleared 16', attr('RunCleared') == 16, state())
cash0 = data.Cash
onPad(padsByStage[16].Return)
wall(0.8)
check('the rooftop\'s yellow pad pays Stage 16\'s Cash', data.Cash - cash0 >= PadRules.reward(16, false), (data.Cash - cash0) .. ' ' .. state())

-------------------------------------------------------------------------------------------- 3. the trips
RS.HoodNet.Travel:FireServer('Stage1', 1)
wall(0.8)
check('the Stage 1 trip lands just inside the Stage 1 gate', at(gateZ(1) - 12, 3) and attr('RunStage') == 1, state())
RS.HoodNet.Travel:FireServer('Lobby', 1)
wall(0.8)
check('the Lobby trip: the spawn, the run over', at(spawnZ, 3) and attr('RunCleared') == 0, state())
print(('[play] %d checks, %d failed'):format(#CHECKS, #FAILS))
return { checks = #CHECKS, failed = FAILS }
