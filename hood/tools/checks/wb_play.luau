-- play_run.luau (STAGES, brief 23): the run loop played through the REAL server and client scripts in one DataModel
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
for _, n in { 'EquipSkin', 'ProfileUpdated', 'Notice', 'Rebirth', 'Cinematic', 'Shoot', 'BuyGun', 'EquipGun', 'WaveShot', 'WaveState', 'Goal', 'Travel', 'OpenShoeBox', 'ShoeAction', 'ShoeOpened', 'WorldBoss', 'WorldBossShot', 'WorldBossJoin' } do
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
local WB = require(RS.Shared.WorldBossRules); WB.Interval, WB.Warn, WB.FightTime = 24, 12, 40
for _, s in { 'StageService', 'WaveService', 'WorldBossService' } do run(HS[s], s, fake) end
local HC = game.StarterPlayer.StarterPlayerScripts.HoodClient
for _, c in { 'Waves', 'WorldBoss' } do run(HC[c], c .. 'CUT', HC) end

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
-- (brief 29, P3b) The World Boss, played through WorldBossService + HoodClient/WorldBoss (+ Waves' gun): the countdown and
-- board, the invite, JOIN to the pier, the giant lands, its red telegraphs, everyone's shots, the split. OUTDIR: a scene.
local Net = RS:WaitForChild('HoodNet')
local function attr(n) return RS:GetAttribute(n) end
wall(1.5)
local ph0 = attr('WorldBossPhase')
check('wb the countdown runs (phase and end time on ReplicatedStorage)', ph0 == 'Wait' or ph0 == 'Invite', ph0)
local board
for _, m in game:GetService('CollectionService'):GetTagged('HoodWorldBossBoard') do board = m end
local function boardText(name) local l = board and board:FindFirstChild(name, true) return l and l.Text or '' end
check('wb the board counts down', boardText('Time'):match('^NEXT IN %d+:%d%d') ~= nil or boardText('Time'):match('^FIGHT') ~= nil, boardText('Time'))
-- wait for the invite
local t0 = os.clock()
while attr('WorldBossPhase') ~= 'Invite' and os.clock() - t0 < 30 do wall(0.5) end
wall(0.6)
local inv = P.PlayerGui:FindFirstChild('HoodWorldBoss', true) and P.PlayerGui:FindFirstChild('Invite', true)
check('wb the invite shows with JOIN before it lands', inv ~= nil and inv.Visible == true and attr('WorldBossPhase') == 'Invite', attr('WorldBossPhase'))
Net.WorldBossJoin:FireServer()
wall(0.6)
local mp = mapPos()
check('wb JOIN puts you on the pier', math.abs(mp.Z - WB.Arena.Z) < WB.Arena.Half + 4 and math.abs(mp.X) < WB.Arena.Half + 4, string.format('%.0f, %.0f', mp.X, mp.Z))
while attr('WorldBossPhase') ~= 'Fight' and os.clock() - t0 < 60 do wall(0.5) end
wall(1.0)
check('wb it lands: the fight is on, you are in it', attr('WorldBossPhase') == 'Fight' and P:GetAttribute('WorldBossFight') == true, attr('WorldBossPhase'))
local wf = workspace:FindFirstChild('HoodWorldBoss')
local rig = wf and wf:FindFirstChildWhichIsA('Model')
check('wb the giant is drawn on the pier', rig ~= nil, rig and rig.Name)
local hp0, max0 = attr('WorldBossHp'), attr('WorldBossMax')
check('wb its HP is set by who is there', type(max0) == 'number' and max0 >= WB.MinHp, max0)
-- walk up to it and wait for a big move's red telegraph
standMap(WB.Home[1] + 4, WB.Home[2] + 12, 0)
local tele = nil
local t1 = os.clock()
while not tele and os.clock() - t1 < 12 do
	wall(0.2)
	tele = wf and wf:FindFirstChild('BossTelegraph', true)
end
check('wb its big moves show in red first', tele ~= nil)
if OUTDIR and tele then
	local keep = {}
	local cam = (frameCF * CFrame.new(-16, 16, WB.Arena.Z + 30)).Position
	for _, d in workspace:GetDescendants() do
		if d:IsA('BasePart') and (d.CFrame.Position - cam).Magnitude < 130 then keep[d] = true end
	end
	__exportParts(keep, OUTDIR .. '/scene_wb_fight.json', 3)
	local look = (frameCF * CFrame.new(-2, 12, WB.Arena.Z - 12)).Position
	__fs.writeFile(OUTDIR .. '/cam_wb_fight.json', __serde.encode('json', { pos = { cam.X, cam.Y, cam.Z }, look = { look.X, look.Y, look.Z } }))
	__fs.writeFile(OUTDIR .. '/manifest.json', __serde.encode('json', { 'wb_fight' }))
end
-- everyone's shots (here: you, strong): it goes down and pays by share
data.Rep = math.floor((max0 or 1000) / 6) + 1
P:SetAttribute('Power', data.Rep)
local cash0 = data.Cash
local reward = nil
local conn = Net.WorldBoss.OnClientEvent:Connect(function(m) if m.Kind == 'Reward' then reward = m end end)
for _ = 1, 40 do
	if reward then break end
	standMap(WB.Home[1] + 4, WB.Home[2] + 12, 0)
	Net.WorldBossShot:FireServer()
	wall(0.25)
end
wall(0.5)
check('wb your shots take it down', attr('WorldBossPhase') ~= 'Fight' or (attr('WorldBossHp') or 1) <= 0, attr('WorldBossHp'))
check('wb the pool is split by damage share (you dealt it all)', reward ~= nil and reward.Share == 1 and data.Cash > cash0, reward and reward.Cash)
conn:Disconnect()
log(string.format('%d checks, %d failed', #CHECKS, #FAILS))
return { checks = #CHECKS, failed = FAILS }
