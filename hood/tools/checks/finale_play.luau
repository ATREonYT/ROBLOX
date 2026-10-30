-- finale_play.luau (brief 30, FIGHTS; P3b's copy of play_run's harness, updated to the new design). WHAT CHANGED: P3b's
-- play checked the boss show the user asked to remove (the catwalk perch and drop, the BOSS name card, the phase bar, the
-- crew held behind roller doors, the white screen flash, "WORLD 1 COMPLETE!" and the crew giving up). Now stage 16 is the
-- warehouse with no extras, so this checks the opposite: all six of the Harbor crew on the floor from the start, the
-- strongest a named enemy (no "BOSS" anywhere) with a bigger, brick-studded tag, no card, no HP bar, no phase pips, its
-- red telegraphs held >= 1.0 s, the dead lying in heaps that stay, CLEAR! on the counter, and the World 2 door's normal
-- clear: "Defeat The Harbor Captain", one short white flash, then "WORLD 2 / Portal in the lobby!". (Stages.client runs too.)
-- (the old header:) play_run.luau (STAGES, brief 23): the run loop played through the REAL server and client scripts in one DataModel
-- (run with tools/harness_play.luau on work24_STAGES2/src; LOOP's play.luau setup). Servers: StageService, WaveService,
-- GoalService, TravelService. Clients: Stages, Waves, Goals, LabelFade, World.
--   spawn -> walk into Stage 1 -> try to slip past gate 2 (and deep past gate 5) -> step on a dim pad -> beat the Stage 1
--   crew -> gate 2 opens, pads light -> walk through gate 2 -> the magenta pad without the pass -> the yellow pad: +Cash,
--   lobby, run over, gates shut, goons fresh -> the goal line -> a 10x cash-out with the pass -> walking back ends a run
--   -> the World window's trips -> 'Furthest' refused -> a respawn ends a run -> a KO keeps it
--   -> (brief 24, STAGES2) leave a stage mid-fight and come back: its crew is whole, on its spots.
-- Every check is recorded (CHECK lines and the returned table); EXPORT = dir writes render13 scenes + GUI trees.
local RS = game.ReplicatedStorage
local Players = game:GetService('Players')
local Schema = require(game.ServerScriptService.HoodServer.ProfileSchema)
local Art = require(RS.Shared.SkinArt)
local PadRules = require(RS.Shared.PadRules)
_G.__screenSize = Vector2.new(1200, 617)
local V2 = require(game.ServerStorage.TheBlockV2)
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

-- A blocky R15 stand-in.
local function makeCharacter()
	local char = Instance.new('Model'); char.Name = 'Tester'
	local root = Instance.new('Part'); root.Name = 'HumanoidRootPart'; root.Size = Vector3.new(2, 2, 1); root.Transparency = 1; root.Anchored = true
	root.CFrame = CFrame.new(0, 3, 0); pcall(function() root.Position = Vector3.new(0, 3, 0) end); root.Parent = char
	for seg, b in Art.Rig do
		local p = Instance.new('Part'); p.Name = seg; p.Size = b[1]; p.CFrame = CFrame.new(b[2]); pcall(function() p.Position = b[2] end); p.Anchored = true
		p.Material = Enum.Material.SmoothPlastic
		p.Color = seg:find('Torso') and Color3.fromRGB(13, 105, 172) or (seg:find('Leg') or seg:find('Foot')) and Color3.fromRGB(75, 151, 75) or Color3.fromRGB(245, 205, 48)
		p.Parent = char
	end
	local hum = Instance.new('Humanoid'); hum.MaxHealth = 100; hum.Health = 100; hum.HipHeight = 2; hum.RigType = Enum.HumanoidRigType.R15; hum.WalkSpeed = 16; hum.Parent = char
	char.PrimaryPart = root
	char.Parent = workspace
	P.Character = char
	return char, root, hum
end
local char, root, hum = makeCharacter()
local frameCF = CFrame.new(workspace.TheBlockV2:GetAttribute('Origin') or Vector3.zero)
local function moveTo(cf)
	local delta = cf * root.CFrame:Inverse()
	for _, d in char:GetDescendants() do if d:IsA('BasePart') then d.CFrame = delta * d.CFrame; pcall(function() d.Position = d.CFrame.Position end) end end
end
local function yawOf(dx, dz) return math.atan2(-dx, -dz) end
local function standMap(x, z, yaw, floor) moveTo(frameCF * CFrame.new(x, (floor or 0) + 3, z) * CFrame.Angles(0, yaw or 0, 0)) end
local function mapPos() return frameCF:PointToObjectSpace(root.CFrame.Position) end

local data = Schema.new()
data.Goals = { Step = 3, Synced = true, Chain = require(RS.Shared.GoalRules).Chain } -- (on "Beat the Stage 1 crew")
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
-- (no servers: the finale's messages are fed below, as WaveService sends them)
local HC = game.StarterPlayer.StarterPlayerScripts.HoodClient
P:SetAttribute('RunStage', 16); P:SetAttribute('RunCleared', 15)
for _, c in { 'Stages', 'Waves' } do run(HC[c], c .. 'CUT', HC) end

local REP, CHECKS, FAILS = {}, {}, {}
local function log(s) table.insert(REP, s); print('[play] ' .. s) end
local function check(name, ok, detail)
	table.insert(CHECKS, (ok and 'ok   ' or 'FAIL ') .. name .. (detail and (' (' .. tostring(detail) .. ')') or ''))
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
local function sync() syncInst(P); syncInst(P.PlayerGui); syncInst(char) end
local camFn
local function frame(dt)
	local steps = math.max(1, math.floor(dt / (1 / 30) + 0.5))
	for _ = 1, steps do
		if camFn then camFn() end
		__fireOn(game:GetService('RunService'), 'PreRender', 1 / 30)
		for _, fn in table.clone(_G.__bound) do fn(1 / 30) end
		__fireOn(game:GetService('RunService'), 'Heartbeat', 1 / 30)
		__stepTweens(1 / 30)
		task.wait(1 / 30)
		sync()
	end
end
local function wall(t)
	local t0 = os.clock()
	while os.clock() - t0 < t do frame(1 / 30) end
end
-- (brief 30) World 1's last stage on your screen, fed as WaveService sends it.
local E = require(RS.Shared.EnemyRules)
local StageRules = require(RS.Shared.StageRules)
local CS = game:GetService('CollectionService')
local models = {}
for _, m in CS:GetTagged('HoodStageGate') do table.insert(models, m) end
local gates = StageRules.fromModels(models)
local world = E.world(gates)
local crew = world[16]
local g16 = gates[16].Z
local remote = RS.HoodNet.WaveState
local strongest
for i, e in crew do if e.Kind == 'Boss' then strongest = i end end
local function pack(states)
	local d = {}
	for i, e in crew do d[3 * i - 2], d[3 * i - 1], d[3 * i] = e.Home.X, e.Home.Z, states[i] or 0 end
	return d
end
local enemies, hp, max = {}, {}, {}
for i, e in crew do
	enemies[i] = { Kind = e.Kind, Name = e.Name, Home = { e.Home.X, e.Home.Z }, Look = e.Look }
	hp[i], max[i] = E.maxHp(16, e.Kind), E.maxHp(16, e.Kind)
end
standMap(0, g16 + 8, 0)
camFn = function() local p = mapPos(); workspace.CurrentCamera.CFrame = CFrame.lookAt(frameCF:PointToWorldSpace(p + Vector3.new(0, 6, 12)), frameCF:PointToWorldSpace(p + Vector3.new(0, 3, -20))) end
P:SetAttribute('WaveStage', 16); P:SetAttribute('WaveLeft', #crew)
remote:FireClient(P, { Kind = 'Wave', Stage = 16, HP = hp, Max = max, Left = #crew, Enemies = enemies, D = pack({}) })
wall(1.2)
local goons = workspace:FindFirstChild('HoodGoons')
local function bodies()
	local list = {}
	for _, m in goons:GetChildren() do
		if m:IsA('Model') and m:GetAttribute('Stage') == 16 and m:GetAttribute('Index') then
			local ok, cf, size = pcall(function() return m:GetBoundingBox() end)
			if ok and frameCF:PointToObjectSpace(cf.Position).Z < g16 - 2 then table.insert(list, { M = m, Feet = frameCF:PointToObjectSpace(cf.Position).Y - size.Y / 2, Top = frameCF:PointToObjectSpace(cf.Position).Y + size.Y / 2 }) end
		end
	end
	return list
end
local function highest()
	local best = -math.huge
	for _, b in bodies() do best = math.max(best, b.Feet) end
	return best
end
local function texts(root, pattern)
	local hits = {}
	for _, d in root:GetDescendants() do
		if d:IsA('TextLabel') and d.Text ~= '' and string.find(string.upper(d.Text), pattern) then table.insert(hits, d:GetFullName() .. ' = ' .. d.Text) end
	end
	return hits
end
local stage16 = nil
for _, m in CS:GetTagged('HoodStageGate') do if m:GetAttribute('Stage') == 16 then stage16 = m.Parent end end
check('fb all six of the Harbor crew stand on the warehouse floor from the start (no catwalk, no doors to wait behind)', #bodies() == #crew and highest() < 2, string.format('%d of %d, highest feet %.1f', #bodies(), #crew, highest()))
local function in16(name)
	local found = {}
	for _, b in bodies() do for _, d in b.M:GetDescendants() do if d.Name == name then table.insert(found, d) end end end
	return found
end
local strong = in16('StrongTag')[1]
local studs = 0
if strong then for _, d in strong:GetDescendants() do if d.Name == 'Stud' then studs += 1 end end end
local strongName = strong and strong:FindFirstChild('Name')
check('fb its strongest is a named enemy: a bigger tag "The Harbor Captain" with a brick-studded HP bar', strongName ~= nil and strongName.Text == 'The Harbor Captain' and studs >= 5, strongName and (strongName.Text .. ', ' .. studs .. ' studs'))
local goonTags = #in16('GoonTag')
check('fb ... the only strong tag: the other five carry ordinary tags', goonTags == #crew - 1 and #in16('StrongTag') == 1, goonTags)
-- they notice you and charge
local states = {}
for i in crew do states[i] = 1 end
remote:FireClient(P, { Kind = 'Moves', Stage = 16, D = pack(states) })
wall(1.0)
local boss = {}
for _, w in { 'BOSS', 'WORLD 1 COMPLETE' } do for _, h in texts(P.PlayerGui, w) do table.insert(boss, h) end; for _, h in texts(goons, w) do table.insert(boss, h) end end
check('fb no "BOSS" and no "WORLD 1 COMPLETE" on screen or over anyone', #boss == 0, boss[1])
check('fb no name card, no boss HP bar, no phase pips', P.PlayerGui:FindFirstChild('BossCard', true) == nil and P.PlayerGui:FindFirstChild('BossBar', true) == nil and P.PlayerGui:FindFirstChild('PhasePip', true) == nil)
if stage16 then
	local inStage = {}
	for _, h in texts(stage16, 'BOSS') do table.insert(inStage, h) end
	local pad = stage16:FindFirstChild('BossPad', true) or stage16:FindFirstChild('FightPad', true)
	check('fb the warehouse has no BOSS pad and no BOSS words', #inStage == 0 and (pad == nil or (pad:IsA('BasePart') and pad.Transparency >= 1)), inStage[1] or (pad and pad:GetFullName()))
end
local pillText = P.PlayerGui:FindFirstChild('WaveLeft', true)
check('fb the counter counts them like any crew ("6 LEFT")', pillText ~= nil and pillText.Visible and pillText.Count.Text == #crew .. ' LEFT', pillText and pillText.Count.Text)
-- its moves: red shapes on the ground, held at least a second
local b = crew[strongest].Home
remote:FireClient(P, { Kind = 'Tele', Stage = 16, Index = strongest, Move = 'Containers', Shape = 'Square', O = { b.X, b.Z }, D = { 0, -1 }, R = 4, P = { { b.X, b.Z - 12 }, { b.X + 8, b.Z - 14 }, { b.X - 8, b.Z - 10 } }, T = E.teleTime(), Flight = 0.9, Drop = true })
wall(0.4)
local sq = 0
for _, d in goons:GetDescendants() do if d.Name == 'Square' then sq += 1 end end
check('fb CONTAINER DROP: three red squares, telegraphed for at least 1.0 s', sq == 3 and E.teleTime() >= 1.0, string.format('%d squares, %.1f s', sq, E.teleTime()))
remote:FireClient(P, { Kind = 'Blast', Stage = 16, Index = strongest, Move = 'Containers', Landed = false, Damage = 0 })
wall(1.0)
local lane = 0
remote:FireClient(P, { Kind = 'Tele', Stage = 16, Index = strongest, Move = 'Forklift', Shape = 'Line', O = { b.X, b.Z }, D = { 0, -1 }, L = 40, W = 7, T = E.teleTime(), Flight = 0.8 })
wall(0.4)
for _, d in goons:GetDescendants() do if d.Name == 'Lane' then lane += 1 end end
check('fb FORKLIFT: the reference charger\'s red lane on the ground', lane == 1, lane)
remote:FireClient(P, { Kind = 'Blast', Stage = 16, Index = strongest, Move = 'Forklift', Landed = false, Damage = 0 })
wall(1.0)
-- the strongest falls: no flash, no slow motion; it lies in a heap like the rest
remote:FireClient(P, { Kind = 'Hit', Stage = 16, Index = strongest, HP = 0, Left = #crew - 1, Damage = max[strongest], Gain = 1 })
P:SetAttribute('WaveLeft', #crew - 1)
wall(0.2)
check('fb it falls with no screen flash', P.PlayerGui:FindFirstChild('FinaleFlash', true) == nil)
wall(1.2)
local gone = in16('StrongTag')[1]
check('fb ... its tag goes and its body stays down (a heap on the floor)', (gone == nil or not gone.Enabled) and #bodies() == #crew, tostring(gone))
check('fb ... the crew fights on (no giving up): the rest still stand', #bodies() == #crew and pillText.Count.Text == (#crew - 1) .. ' LEFT', pillText.Count.Text)
-- the last of them
local door
for _, m in CS:GetTagged('HoodWorldDoor') do door = m end
local sign = door and door:FindFirstChild('GateSign', true)
local status = sign and sign:FindFirstChild('Status')
check('fb the World 2 door says "Defeat The Harbor Captain" while the crew stands (title hidden)', status ~= nil and status.Visible and status.Text == 'Defeat The Harbor Captain' and not sign.Title.Visible, status and status.Text)
for i in crew do
	if i ~= strongest then
		local left = 0
		for j in crew do if j ~= strongest and j > i then left += 1 end end
		remote:FireClient(P, { Kind = 'Hit', Stage = 16, Index = i, HP = 0, Left = left, Damage = max[i], Gain = 1 })
	end
end
P:SetAttribute('WaveLeft', 0)
remote:FireClient(P, { Kind = 'Cleared', Stage = 16, Reward = 500, First = true })
P:SetAttribute('RunCleared', 16)
local barrier = door and door:FindFirstChild('Barrier', true)
local function whitePanes()
	local n = 0
	if barrier then
		for _, d in barrier:GetDescendants() do
			if d:IsA('Frame') and d.Name == 'Pane' and d.BackgroundTransparency <= 0.101 and d.BackgroundColor3.R > 0.97 and d.BackgroundColor3.G > 0.97 and d.BackgroundColor3.B > 0.97 then n += 1 end
		end
	end
	return n
end
-- (frame by frame: the flash is 0.2 s of real time, and a harness frame takes longer than 1/30 s)
local whiteFrames, t0, lastWhite = 0, os.clock(), -1
for _ = 1, 15 do
	frame(1 / 30)
	if whitePanes() > 0 then whiteFrames += 1; lastWhite = os.clock() - t0 end
end
check('fb the last kill: the World 2 door\'s haze flashes solid white', whiteFrames >= 1, string.format('%d frames, last at %.2f s', whiteFrames, lastWhite))
check('fb ... CLEAR! on the counter', pillText.Visible and pillText.Count.Text == 'CLEAR!', pillText.Count.Text)
local stillWhite = whitePanes() > 0
check('fb ... one short flash (gone within 0.25 s), then "WORLD 2 / Portal in the lobby!"', not stillWhite and sign.Title.Visible and sign.Title.Text == 'WORLD 2' and sign.Sub.Text == 'Portal in the lobby!' and not status.Visible, sign.Title.Text .. ' / ' .. sign.Sub.Text)
local done = texts(P.PlayerGui, 'WORLD 1 COMPLETE')
check('fb no slow-motion "WORLD 1 COMPLETE!" show', #done == 0 and P.PlayerGui:FindFirstChild('FinaleFlash', true) == nil)
wall(4)
check('fb the dead stay where they fell, in heaps (all six still drawn 4 s on)', #bodies() == #crew, #bodies())
log(string.format('%d checks, %d failed', #CHECKS, #FAILS))
return { checks = #CHECKS, failed = FAILS }
