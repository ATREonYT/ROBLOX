-- play_run.luau (STAGES, brief 23): the run loop played through the REAL server and client scripts in one DataModel
-- (run with tools/harness_play.luau on work24_STAGES2/src; LOOP's play.luau setup). Servers: StageService, WaveService,
-- GoalService, TravelService. Clients: Stages, Waves, Goals, LabelFade, World.
--   spawn -> walk into Stage 1 -> try to slip past gate 2 (and deep past gate 5) -> step on a dim pad -> beat the Stage 1
--   crew -> gate 2 opens, pads light -> walk through gate 2 -> the magenta pad without the pass -> the yellow pad: +Cash,
--   lobby, run over, gates shut, goons fresh -> the goal line -> a 10x cash-out with the pass -> walking back ends a run
--   -> the World window's trips -> 'Furthest' refused -> a respawn ends a run -> a KO keeps it
--   -> (brief 24, STAGES2) leave a stage mid-fight and come back: its crew is whole, on its spots.
-- Every check is recorded (CHECK lines and the returned table); EXPORT = dir writes render13 scenes + GUI trees.
-- (brief 30, FIGHTS: copied from out24/STAGES2/tools and updated to the new design: the open gate's sign is the
-- reference's "STAGE N / Recommended / Power: X" with no state line (was "OPEN!" on a green badge); a KO is the revive
-- screen, and "No" puts you back at the stage start (was an instant respawn); no boss HP bar exists any more (was
-- hidden in Stage 1); the Revive remote is made with the others.)
local RS = game.ReplicatedStorage
local Players = game:GetService('Players')
local Schema = require(game.ServerScriptService.HoodServer.ProfileSchema)
local Art = require(RS.Shared.SkinArt)
local PadRules = require(RS.Shared.PadRules)
-- (the stage 1 pads' labels, from the rules, so a Cash change in Config/Balance never makes this run stale)
local PAD1, PAD10 = PadRules.text(PadRules.reward(1, false)), PadRules.text(PadRules.reward(1, true))
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
for _, s in { 'StageService', 'WaveService', 'GoalService', 'TravelService' } do run(HS[s], s, fake) end
local HC = game.StarterPlayer.StarterPlayerScripts.HoodClient
for _, c in { 'Stages', 'Waves', 'Goals', 'LabelFade', 'World' } do run(HC[c], c .. 'CUT', HC) end

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
local function sent(name, kind, from)
	local list = {}
	for i = from or 1, #_G.__toClient do
		local m = _G.__toClient[i]
		if m[1] == name and (not kind or (type(m[2]) == 'table' and m[2].Kind == kind) or m[2] == kind) then table.insert(list, m[2]) end
	end
	return list
end
local function mark() return #_G.__toClient + 1 end
local function look(eyeMap, atMap) cam.CFrame = CFrame.lookAt(frameCF:PointToWorldSpace(eyeMap), frameCF:PointToWorldSpace(atMap)) end
local function behind(dx, dz, back, up, pitch)
	return function()
		local p = mapPos()
		local d = Vector3.new(dx, 0, dz).Unit
		local eye = p - d * back + Vector3.new(0, up, 0)
		look(eye, eye + (d + Vector3.new(0, -math.tan(math.rad(pitch or 7)), 0)) * 30)
	end
end

-- The map's pieces.
local gatesByStage, padsByStage = {}, {}
for _, m in workspace.TheBlockV2:GetDescendants() do
	if m:HasTag('HoodStageGate') then gatesByStage[m:GetAttribute('Stage')] = m end
	if m:HasTag('HoodStagePad') then
		local s = m:GetAttribute('Stage')
		padsByStage[s] = padsByStage[s] or {}
		padsByStage[s][m:GetAttribute('Kind')] = m
	end
end
local function gateZ(n) return gatesByStage[n]:GetAttribute('LineZ') end
local function barrier(n) return gatesByStage[n]:FindFirstChild('Barrier', true) end
local function status(n) local s = gatesByStage[n]:FindFirstChild('GateSign', true); return s and s:FindFirstChild('Status') and s.Status.Text end
local function padMap(pad) return frameCF:PointToObjectSpace(pad.CFrame.Position) end
local function label(pad, line)
	local a = pad.Parent:FindFirstChild(pad.Name .. 'Label')
	local t = a and a.WorldLabel:FindFirstChild(line)
	return t and t.Text, t and t.Visible
end
local function onPad(pad)
	local p = padMap(pad)
	standMap(p.X, p.Z, 0, p.Y + pad.Size.Y / 2)
	__fireOn(pad, 'Touched', char:FindFirstChild('LeftFoot') or root)
end
local function feedback()
	local fb = P.PlayerGui:FindFirstChild('StageFeedback')
	local t = {}
	if fb then for _, d in fb:GetDescendants() do if d:IsA('TextLabel') and d.Text ~= '' then table.insert(t, d.Text) end end end
	return table.concat(t, ' / ')
end
local function notices(from) local t = {} for _, m in sent('Notice', nil, from) do table.insert(t, tostring(m)) end return table.concat(t, ' | ') end
local function at(z, tol) return math.abs(mapPos().Z - z) < (tol or 1.5) end
local SPAWN = V2.Lobby and V2.Lobby.Spawn
local spawnZ = (workspace.TheBlockV2:GetAttribute('LobbySpawn') or Vector3.new(0, 0, 55)).Z
local function attr(n) return P:GetAttribute(n) end

-- Shots for render13 (EXPORT): the parts around the camera, the camera, every ScreenGui.
local SHOTS = {}
local function shot(tag, radius)
	frame(0.7) -- (the labels' fades and the sign's growth catch up with the camera, as on a real screen)
	local entry = { tag = tag, guis = {} }
	table.insert(SHOTS, entry)
	if not EXPORT then return end
	local keep = {}
	local o, fwd = cam.CFrame.Position, cam.CFrame.LookVector
	for _, d in workspace:GetDescendants() do
		if d:IsA('BasePart') then
			local v = d.CFrame.Position - o
			if v.Magnitude < (radius or 200) and (v.Magnitude < 40 or v:Dot(fwd) > -10) then keep[d] = true end
		end
	end
	keep[root] = nil
	local ok, err = pcall(__exportParts, keep, EXPORT .. '/scene_' .. tag .. '.json', 3)
	if not ok then print('[play] export failed: ' .. tostring(err)) end
	for _, g in P.PlayerGui:GetChildren() do
		if g:IsA('ScreenGui') and g.Enabled and (g.Name == 'StageFeedback' or g.Name == 'HoodGoals' or g.Name == 'HoodWaves') then
			local okU = pcall(__exportUI, g, EXPORT .. '/' .. tag .. '_' .. g.Name .. '.json')
			if okU then table.insert(entry.guis, g.Name) end
		end
	end
	local c = cam.CFrame
	local lookAt = c.Position + c.LookVector * 30
	__fs.writeFile(EXPORT .. '/cam_' .. tag .. '.json', __serde.encode('json', { pos = { c.Position.X, c.Position.Y, c.Position.Z }, look = { lookAt.X, lookAt.Y, lookAt.Z } }))
end
local function state() return ('RunStage=%s RunCleared=%s Cash=%s CashOuts=%s WaveStage=%s WaveLeft=%s Goal="%s" z=%.1f'):format(tostring(attr('RunStage')), tostring(attr('RunCleared')), tostring(data.Cash), tostring(attr('CashOuts')), tostring(attr('WaveStage')), tostring(attr('WaveLeft')), tostring(attr('GoalText')), mapPos().Z) end
local function step(tag, note) log(('[%s] %s'):format(tag, note)); log('    ' .. state()); local fb = feedback(); if fb ~= '' then log('    feedback: ' .. fb) end end

-- Beat a stage's crew from in front of it (Power high: a shot each), the way the client fires.
local function beat(stage)
	local z = gateZ(stage)
	standMap(0, z - 26, 0)
	wall(0.6)
	data.Rep = 1e7
	local before = #sent('WaveState', 'Cleared')
	for round = 1, 6 do
		for i = 1, 6 do RS.HoodNet.WaveShot:FireServer(stage, i); wall(0.05) end
		wall(0.3)
		if #sent('WaveState', 'Cleared') > before then break end
	end
	wall(0.4)
	return #sent('WaveState', 'Cleared') > before
end

-------------------------------------------------------------------------------------------- 1. the lobby
local g1, g2 = gateZ(1), gateZ(2)
standMap(0, spawnZ, 0)
camFn = behind(0, -1, 12, 6, 7)
wall(1.6)
step('01_spawn', 'a fresh player on the spawn')
check('fresh run: RunStage 1, RunCleared 0, CashOuts 0', attr('RunStage') == 1 and attr('RunCleared') == 0 and attr('CashOuts') == 0, state())
check('gate 1 open for you, gate 2 shut', barrier(1).CanCollide == false and barrier(2).CanCollide == true, status(1) .. ' | ' .. status(2))
check('gate 2 reads "Defeat the crew first"', status(2) == 'Defeat the crew first', status(2))
local r1, t1 = padsByStage[1].Return, padsByStage[1].TenX
do
	local top = r1.Parent:FindFirstChild('ReturnPadTop')
	local base = top and top:GetAttribute('BaseColor')
	check('locked pads keep their own colour, a notch darker (no grey)', base and math.abs(top.Color.R - base.R * 0.85) < 0.01 and math.abs(top.Color.G - base.G * 0.85) < 0.01 and math.abs(top.Color.B - base.B * 0.85) < 0.01, top and tostring(top.Color))
end
check('stage 1 pads locked: "+<stage 1> Cash" / "+<10x> Cash" over "🔒 Clear the crew!"', label(r1, 'Title') == PAD1 and label(r1, 'Sub') == '🔒 Clear the crew!' and label(t1, 'Title') == PAD10 and label(t1, 'Sub') == '🔒 Clear the crew!', label(r1, 'Title') .. ' / ' .. label(r1, 'Sub'))
check('32 pads, two a stage', (function() local n = 0 for s = 1, 16 do if padsByStage[s] and padsByStage[s].Return and padsByStage[s].TenX then n += 2 end end return n end)() == 32)
shot('01_spawn', 330)

-------------------------------------------------------------------------------------------- 2. into Stage 1
local m = mark()
standMap(0, g1 - 12, 0)
wall(0.8)
step('02_stage1', 'walked through gate 1')
check('the Stage 1 crew is sent, 3 up', #sent('WaveState', 'Wave', m) >= 1 and attr('WaveStage') == 1 and attr('WaveLeft') == 3, attr('WaveLeft'))
camFn = function() look(Vector3.new(0, 8, g1 + 2), Vector3.new(0, 3, g2 + 4)) end -- (just through gate 1, down Stage 1)
shot('02b_stage_entry', 200)
camFn = behind(0, -1, 12, 6, 7)

-------------------------------------------------------------------------------------------- 3. slipping past gate 2
standMap(3, g2 - 6, 0)
wall(0.8)
step('03_slip', 'stood 6 studs past the shut gate 2')
check('the server puts you back in front of gate 2', at(g2 + 5), mapPos().Z)
standMap(0, gateZ(5) - 30, 0)
wall(0.8)
check('deep past a shut gate (Stage 5) is caught too', at(g2 + 5), mapPos().Z)
data.Rep = 1e7
standMap(0, gateZ(5) - 34, 0)
m = mark()
for i = 1, 4 do RS.HoodNet.WaveShot:FireServer(5, i) end
wall(0.4)
check('no shots count at a crew past a gate not open this run', #sent('WaveState', 'Hit', m) == 0 and attr('RunCleared') == 0, #sent('WaveState', 'Hit', m))
data.Rep = 0

-------------------------------------------------------------------------------------------- 4. a dim pad
m = mark()
local cash0 = data.Cash
onPad(r1)
wall(0.8)
step('04_dim_pad', 'stood on the yellow pad before the crew is down')
check('a dim pad pays nothing and keeps you here', data.Cash == cash0 and not at(spawnZ, 5), state())
check('it says why', string.find(notices(m), 'crew first', 1, true) ~= nil, notices(m))
-- the pads from the end of Stage 1, dim (a render)
local rp = padMap(r1)
camFn = function() look(Vector3.new(0, 7.5, g2 + 34), Vector3.new(0, 3, g2 - 4)) end
shot('04_pads_dim', 200)
camFn = function() look(Vector3.new(0, 6.2, g2 + 24), Vector3.new(0, 3.2, g2 + 2)) end
shot('04b_pads_close_dim', 160)

-------------------------------------------------------------------------------------------- 5. beat the crew: gate 2 opens
camFn = behind(0, -1, 12, 6, 7)
m = mark()
local cleared = beat(1)
step('05_cleared', 'beat the Stage 1 crew')
check('the crew is down (CLEAR!)', cleared and attr('WaveLeft') == 0)
local msg = sent('WaveState', 'Cleared', m)[1]
check('the clear opens gate 2 (Opens = 2), first ever, paying what ECON says (the pad is the big number)', msg and msg.Opens == 2 and msg.First == true and msg.Reward == require(RS.Shared.WaveRules).reward(1), msg and ('Opens=' .. tostring(msg.Opens) .. ' Reward=' .. tostring(msg.Reward)))
check('RunCleared 1, RunStage 2', attr('RunCleared') == 1 and attr('RunStage') == 2, state())
wall(0.5)
do
	local sign = gatesByStage[2]:FindFirstChild('GateSign', true)
	check('(brief 30) gate 2 open for you: no wall, the sign switched to "STAGE 2" (no state line)', barrier(2).CanCollide == false and sign.Title.Visible and sign.Title.Text == 'STAGE 2' and not sign.Status.Visible, sign.Title.Text .. ' / status ' .. tostring(sign.Status.Visible))
end
do -- (brief 30: "STAGE 2 OPEN!" is the line under the CLEAR! chip now, not a banner over the gate's sign)
	local chip = P.PlayerGui:FindFirstChild('HoodWaves') and P.PlayerGui.HoodWaves:FindFirstChild('WaveLeft', true)
	local line = chip and chip:FindFirstChild('Reward')
	check('the open moment: CLEAR! and "STAGE 2 OPEN!" under it, no banner over the sign', line ~= nil and line.Text == 'STAGE 2 OPEN!' and chip.Count.Text == 'CLEAR!' and string.find(feedback(), 'OPEN!', 1, true) == nil, (line and line.Text or '?') .. ' / ' .. feedback())
end
do
	local sign = gatesByStage[2]:FindFirstChild('GateSign', true)
	check('(brief 30) the open sign is the reference\'s: "STAGE 2" / "Recommended" / "Power: X"', sign.Title.Visible ~= false and sign.Sub.Visible ~= false and sign.Power.Visible ~= false and sign.Sub.Text == 'Recommended' and string.find(sign.Power.Text, '^Power: ') ~= nil, sign.Power.Text)
	check('(brief 29) and it is one fixed board in the gate plane: a SurfaceGui on the SignBoard, nothing to grow, fade or move', sign:IsA('SurfaceGui') and sign.Parent ~= nil and sign.Parent.Name == 'SignBoard', sign.ClassName)
	local _, subOn = label(r1, 'Sub')
	local _, tsubOn = label(t1, 'Sub')
	check('the pads keep their small line ("Return", "10x Cash") when the gate opens', subOn ~= false and tsubOn ~= false)
end
check('gate 3 still shut', barrier(3).CanCollide == true)
local big, small = label(r1, 'Title'), label(r1, 'Sub')
local tbig, tsmall = label(t1, 'Title'), label(t1, 'Sub')
local tprice, tpriceOn = label(t1, 'Price')
check('pads lit: "+<stage 1> Cash / Return" and "+<10x> Cash / 10x Cash" with the price', big == PAD1 and small == 'Return' and tbig == PAD10 and tsmall == '10x Cash' and tpriceOn and tprice == '\u{E002}' .. tostring(require(RS.Shared.Config.Products).ByKey.TenXCash.Price), table.concat({ big, small, tbig, tsmall, tostring(tprice) }, ' / '))
camFn = function() look(Vector3.new(0, 7.5, g2 + 34), Vector3.new(0, 3, g2 - 4)) end
shot('05_gate_open', 200)
camFn = function() look(Vector3.new(0, 6.2, g2 + 24), Vector3.new(0, 3.2, g2 + 2)) end
shot('05b_pads_close_lit', 160)
wall(1.6)
check('the goal line now points at the yellow pad', attr('GoalText') == 'Step on the yellow pad' and attr('GoalWhere') == 'by the gate: ' .. PAD1, tostring(attr('GoalText')) .. ' - ' .. tostring(attr('GoalWhere')))

-------------------------------------------------------------------------------------------- 6. through gate 2
camFn = behind(0, -1, 12, 6, 7)
standMap(0, g2 - 6, 0)
wall(0.8)
step('06_through', 'walked through the open gate 2')
check('nobody pulls you back now', at(g2 - 6), mapPos().Z)

-------------------------------------------------------------------------------------------- 7. the magenta pad without the pass
m = mark()
cash0 = data.Cash
onPad(t1)
wall(0.8)
step('07_tenx_nopass', 'stood on the magenta pad without the 10x Cash pass')
check('no pay, no trip', data.Cash == cash0 and not at(spawnZ, 5), state())
check('"coming soon" (id 0) or the pass prompt', string.find(notices(m), 'coming soon', 1, true) ~= nil or #_G.__prompts > 0, notices(m))
standMap(0, g2 + 20, 0)
wall(0.5)

-------------------------------------------------------------------------------------------- 8. the yellow pad: cash out
m = mark()
cash0 = data.Cash
onPad(r1)
wall(0.8)
step('08_cashout', 'stepped on the yellow pad')
local goalPaid = 0
for _, g in sent('Goal', 'Done', m) do goalPaid += g.Reward or 0 end -- (the "cash out" goal pays its own small reward meanwhile)
local paid = sent('Cinematic', 'CashOut', m)[1]
check('the stage 1 pad pays its Cash', paid and paid.Reward == PadRules.reward(1, false) and data.Cash - cash0 - goalPaid == PadRules.reward(1, false), (data.Cash - cash0) .. ' incl. goal ' .. goalPaid)
check('back on the lobby spawn', at(spawnZ, 2), mapPos().Z)
check('the run is over: RunCleared 0, RunStage 1, CashOuts 1', attr('RunCleared') == 0 and attr('RunStage') == 1 and attr('CashOuts') == 1, state())
check('the cash-out moment and the reset reach your client', #sent('Cinematic', 'CashOut', m) == 1 and #sent('WaveState', 'Reset', m) == 1)
check('(brief 29) no big "+<stage 1> Cash" pops on screen: the Cash just joins the balance', string.find(feedback(), PAD1, 1, true) == nil, feedback())
camFn = behind(0, -1, 12, 6, 7)
shot('08_cashout', 330)
local early = 0
for _, g in sent('Goal', 'Done', m) do if g.Text == 'Step on the yellow pad' then early += 1 end end
check('the cash-out goal waits: "+<stage 1> Cash" has the screen to itself first', early == 0, early)
wall(0.5)
check('gates shut again for you', barrier(2).CanCollide == true and status(2) == 'Defeat the crew first', status(2))
check('pads locked again', label(r1, 'Sub') == '🔒 Clear the crew!', label(r1, 'Sub'))
wall(1.8)
check('the goal moves on to buying a gun', attr('GoalText') == 'Buy a gun', attr('GoalText'))
check('BestCashOut 1 (the stage cashed out at)', attr('BestCashOut') == 1, attr('BestCashOut'))
cash0 = data.Cash
onPad(r1)
wall(0.6)
check('a pad pays once a run: standing on it again (new run, crew up) pays nothing', data.Cash == cash0, data.Cash - cash0)
standMap(0, spawnZ, 0)
wall(0.4)

-------------------------------------------------------------------------------------------- 9. the goons come back
m = mark()
standMap(0, g1 - 12, 0)
wall(0.8)
local wave = sent('WaveState', 'Wave', m)[1]
step('09_again', 'walked into Stage 1 again')
check('the Stage 1 crew is back, whole', wave and wave.Left == 3 and wave.HP[1] == wave.Max[1] and attr('WaveLeft') == 3, wave and wave.Left)

-------------------------------------------------------------------------------------------- 10. 10x with the pass
beat(1)
P:SetAttribute('Pass_TenXCash', true)
wall(0.3)
local tpr, tprOn = label(t1, 'Price')
check('owning the pass hides the price', not tprOn, tostring(tpr))
cash0 = data.Cash
m = mark()
onPad(t1)
wall(0.8)
step('10_tenx', 'stepped on the magenta pad with the pass')
check('the 10x pad pays and takes you home', data.Cash - cash0 == PadRules.reward(1, true) and at(spawnZ, 2), data.Cash - cash0)
local co = sent('Cinematic', 'CashOut', m)[1]
check('the moment says 10x', co and co.TenX == true and co.Reward == PadRules.reward(1, true))

-------------------------------------------------------------------------------------------- 11. walking back ends a run
beat(1)
check('cleared again: gate 2 open', attr('RunStage') == 2)
standMap(0, g1 + 12, 0)
wall(0.8)
step('11_walkback', 'walked back into the lobby')
check('the lobby ends the run', attr('RunCleared') == 0 and attr('RunStage') == 1, state())

-------------------------------------------------------------------------------------------- 12. the World window's trips
standMap(0, spawnZ, 0)
wall(0.3)
RS.HoodNet.Travel:FireServer('Stage1', 1)
wall(0.8)
step('12_trip_stage1', 'World 1 > Stage 1')
check('Stage 1 trip lands just inside the Stage 1 gate', at(g1 - 12, 2) and attr('RunStage') == 1, mapPos().Z)
beat(1)
wall(2.2) -- (the trip rate limit)
RS.HoodNet.Travel:FireServer('Lobby', 1)
wall(0.8)
check('Lobby trip: spawn, run over', at(spawnZ, 2) and attr('RunCleared') == 0, state())
wall(2.2)
local zBefore = mapPos().Z
RS.HoodNet.Travel:FireServer('Furthest', 1)
wall(0.6)
check('the retired Furthest trip goes nowhere', at(zBefore, 0.5), mapPos().Z)

-------------------------------------------------------------------------------------------- 13. a respawn ends a run
beat(1)
check('cleared again', attr('RunCleared') == 1)
__fireOn(P, 'CharacterAdded', char)
wall(0.4)
step('13_respawn', 'respawned')
check('a respawn ends the run', attr('RunCleared') == 0, state())

-------------------------------------------------------------------------------------------- 14. a KO keeps the run
beat(1)
standMap(0, g2 - 30, 0)
hum.Health = 1
m = mark()
local t0 = os.clock()
while #sent('WaveState', 'KO', m) == 0 and os.clock() - t0 < 14 do
	standMap(0, g2 - 30, 0)
	wall(0.2)
end
step('14_ko', 'knocked out in Stage 2')
do
	local ko = sent('WaveState', 'KO', m)[1]
	local zAt = mapPos().Z
	wall(0.6)
	local rv = P.PlayerGui:FindFirstChild('HoodWaves') and P.PlayerGui.HoodWaves:FindFirstChild('Revive', true)
	check('(brief 30) KO: you\'re down where you fell (not moved yet) and the revive screen counts down 10 s', ko ~= nil and ko.For == 10 and attr('Downed') == 2 and rv ~= nil and rv.Visible and rv.Title.Text == 'REVIVE?' and math.abs(mapPos().Z - zAt) < 1, (ko and tostring(ko.For) or 'no KO') .. ' ' .. tostring(rv and rv.Visible))
	-- "No" (free): back at the Stage 2 start
	RS.HoodNet.Revive:FireServer('No')
	wall(0.6)
end
check('KO + "No": back at the Stage 2 start, the run kept (gate 2 still open), the screen gone', #sent('WaveState', 'KO', m) == 1 and at(g2 - 4, 2) and attr('RunCleared') == 1 and attr('RunStage') == 2 and attr('Downed') == nil and not P.PlayerGui.HoodWaves:FindFirstChild('Revive', true).Visible, state())

-------------------------------------------------------------------------------------------- 15. the boss yard's pads (a picture)
local bossPad = padsByStage[16] and padsByStage[16].Return
check('the boss yard has its own pair of pads', bossPad ~= nil and padsByStage[16].TenX ~= nil)
if bossPad then
	local bp = padMap(bossPad)
	camFn = function() look(Vector3.new(0, 10, bp.Z + 40), Vector3.new(0, 2, bp.Z - 4)) end
	shot('15_boss_pads', 160)
end

-------------------------------------------------------------------------------------------- 16. leave a stage: its crew is whole again
-- (brief 24, STAGES2) Damage a crew, leave its stage, come back: full HP, everyone back on their spot. Three ways out:
-- back through its gate (Stage 2 -> Stage 1, the run goes on), into the lobby (the run ends too), and a side step that
-- stays in the stage (nothing resets).
local function rigs(stage)
	local list = {}
	local f = workspace:FindFirstChild('HoodGoons')
	for _, mdl in f and f:GetChildren() or {} do
		if mdl:GetAttribute('Stage') == stage and mdl:GetAttribute('Index') then list[mdl:GetAttribute('Index')] = mdl end
	end
	return list
end
local function rigAt(mdl) -- (the rig's head, map frame, flat)
	local head = mdl:FindFirstChild('Head', true)
	local p = frameCF:PointToObjectSpace(head and head.Position or mdl:GetPivot().Position)
	return Vector3.new(p.X, 0, p.Z)
end
local function tagFull(mdl)
	local tag = mdl:FindFirstChild('GoonTag', true) or mdl:FindFirstChild('StrongTag', true) -- (brief 30: a crew's strongest wears the bigger StrongTag)
	local fill = tag and tag:FindFirstChild('Fill', true)
	return fill ~= nil and math.abs(fill.Size.X.Scale - 1) < 1e-3, fill and fill.Size.X.Scale
end
local function lastWave(stage, from, restored)
	local found
	for _, w in sent('WaveState', 'Wave', from) do
		if w.Stage == stage and (restored == nil or (w.Restored == true) == restored) then found = w end
	end
	return found
end
local function lastMoves(stage, from)
	local found
	for _, w in sent('WaveState', 'Moves', from) do if w.Stage == stage then found = w.D end end
	return found
end
local function homes(info) local h = {} for i, e in info.Enemies do h[i] = Vector3.new(e.Home[1], 0, e.Home[2]) end return h end
local function allHome(d, h, tol)
	if not d then return false, 'no moves' end
	for i, home in h do
		local p = Vector3.new(d[3 * i - 2], 0, d[3 * i - 1])
		if (p - home).Magnitude > (tol or 0.05) or d[3 * i] ~= 0 then return false, ('goon %d at %.1f from home, state %s'):format(i, (p - home).Magnitude, tostring(d[3 * i])) end
	end
	return true, 'all idle on their spots'
end
local function whole(info)
	if not info then return false, 'no wave' end
	for i, mx in info.Max do if info.HP[i] ~= mx then return false, ('goon %d %s/%s'):format(i, tostring(info.HP[i]), tostring(mx)) end end
	return info.Left == #info.Max, ('Left %s of %d'):format(tostring(info.Left), #info.Max)
end
local function pill() -- (the "N LEFT" pill: shown?, its text)
	local g = P.PlayerGui:FindFirstChild('HoodWaves')
	local box = g and g:FindFirstChild('WaveLeft', true)
	local t = box and box:FindFirstChild('Count')
	return box ~= nil and box.Visible, t and t.Text
end
local function fire(stage, i, power)
	data.Rep = power
	RS.HoodNet.WaveShot:FireServer(stage, i)
	wall(0.08)
end
hum.MaxHealth, hum.Health = 1e6, 1e6 -- (no KO in the middle of this)
-- every crew's spots, as the server and your client work them out from the map's gates
local crewWorld
do
	local gm = {}
	for _, gmod in gatesByStage do table.insert(gm, gmod) end
	crewWorld = require(RS.Shared.EnemyRules).world(require(RS.Shared.StageRules).fromModels(gm))
end
local function homesOf(stage) local h = {} for i, e in crewWorld[stage] do h[i] = e.Home end return h end

-- 16a. back through its gate: hurt one goon, knock one out, step back into Stage 1
standMap(0, g2 + 10, 0) -- (out of Stage 2 after the KO, in Stage 1: a clean walk in)
wall(4.5)
camFn = behind(0, -1, 12, 6, 7)
local mIn = mark()
standMap(0, g2 - 20, 0)
wall(0.8)
local entered = lastWave(2, mIn)
check('16a walk into Stage 2 (run kept): its crew is sent, 4 up (brief 29: 3 + their boss)', entered ~= nil and attr('WaveStage') == 2 and attr('WaveLeft') == 4, state())
local home2 = homesOf(2)
local max1 = entered and entered.Max[1] or 0
local mHit = mark()
fire(2, 1, 50); fire(2, 1, 50); fire(2, 2, 1e9)
standMap(0, g2 - 6, 0) -- (back off to the gate: they come all the way after you)
wall(2.4)
local hits = sent('WaveState', 'Hit', mHit)
local hurt1, down2 = nil, false
for _, h in hits do if h.Index == 1 then hurt1 = h.HP end if h.Index == 2 and h.HP == 0 then down2 = true end end
check('16a damage a goon (two shots) and knock one out', hurt1 == max1 - 100 and down2 and attr('WaveLeft') == 3, ('goon 1 %s/%s, goon 2 down %s, left %s'):format(tostring(hurt1), tostring(max1), tostring(down2), tostring(attr('WaveLeft'))))
local d0 = lastMoves(2, mHit)
local chased = false
if d0 then for i, h in home2 do if i ~= 2 and (Vector3.new(d0[3 * i - 2], 0, d0[3 * i - 1]) - h).Magnitude > 3 then chased = true end end end
check('16a the crew is out of place, after you', chased)
local before = rigs(2)
local mOut = mark()
standMap(0, g2 + 10, 0) -- (back through gate 2, into Stage 1: its crew is down this run)
wall(0.6)
step('16a_left', 'stepped back through gate 2 into Stage 1')
local back = lastWave(2, mOut, true)
local okW, whyW = whole(back)
check('16a leaving Stage 2 makes its crew whole: a Restored wave, every HP full, 3 left', okW, whyW)
check('16a the run goes on: gate 2 still open, RunCleared 1, you are in Stage 1', attr('RunCleared') == 1 and attr('RunStage') == 2 and attr('WaveStage') == 1 and attr('WaveLeft') == 0, state())
do local on, txt = pill(); check('16a no stale "N LEFT" on screen once you are out', not on, tostring(on) .. ' ' .. tostring(txt)) end
if back then
	local d = back.D
	local p2 = Vector3.new(d[4], 0, d[5])
	check('16a the knocked-out goon is back on its spot at once', (p2 - home2[2]).Magnitude < 0.05 and d[6] == 0, ('%.2f from home, state %s'):format((p2 - home2[2]).Magnitude, tostring(d[6])))
	local walking = 0
	for i = 1, #home2 do if d[3 * i] == 5 then walking += 1 end end
	check('16a the others turn for home (Return)', walking >= 1 and (d[3] == 5 or d[3] == 0) and (d[9] == 5 or d[9] == 0), ('states %s %s %s'):format(tostring(d[3]), tostring(d[6]), tostring(d[9])))
end
camFn = function() look(Vector3.new(0, 15, g2 + 34), Vector3.new(0, 2, g2 - 30)) end -- (from Stage 1, through gate 2)
wall(0.1)
local nowRigs = rigs(2)
check('16a on your screen: the knocked-out goon pops back in (a rig again)', nowRigs[2] ~= nil and nowRigs[2] ~= before[2])
shot('16a_left_whole', 200)
wall(0.4)
local fullBars, barsWhy = true, {}
for i, mdl in rigs(2) do local ok, x = tagFull(mdl); if not ok then fullBars = false end; table.insert(barsWhy, i .. ':' .. tostring(x)) end
check('16a on your screen: every HP bar is full again', fullBars and #barsWhy == 4, table.concat(barsWhy, ' '))
wall(4)
local okH, whyH = allHome(lastMoves(2, mOut), home2)
check('16a they walk back to their spots and stand there', okH, whyH)
local near, nearWhy = true, {}
for i, mdl in rigs(2) do local dd = (rigAt(mdl) - home2[i]).Magnitude; if dd > 0.6 then near = false end; table.insert(nearWhy, ('%d:%.2f'):format(i, dd)) end
check('16a on your screen too: every goon drawn on its spot', near and #nearWhy == 4, table.concat(nearWhy, ' '))
shot('16a_home', 200)
local mBack = mark()
camFn = behind(0, -1, 12, 6, 7)
standMap(0, g2 - 20, 0)
wall(0.6)
local again = lastWave(2, mBack, false)
local okA, whyA = whole(again)
check('16a walk back in: the crew is whole (full HP, 4 left)', okA and attr('WaveLeft') == 4, whyA)
do
	local on, txt = pill()
	local bars, n = true, 0
	for _, mdl in rigs(2) do n += 1; if not tagFull(mdl) then bars = false end end
	check('16a ... on your screen: "4 LEFT" and four full HP bars, nothing stale', on and txt == '4 LEFT' and bars and n == 4, tostring(txt) .. ', bars full ' .. tostring(bars) .. ' x' .. n)
end
if again then
	local d = again.D
	local okS = true
	for i, h in home2 do if (Vector3.new(d[3 * i - 2], 0, d[3 * i - 1]) - h).Magnitude > 0.05 then okS = false end end
	check('16a ... and every goon starts from its spot', okS)
end
local mShot = mark()
fire(2, 1, 50)
wall(0.3)
local h1 = sent('WaveState', 'Hit', mShot)[1]
check('16a the first shot back counts from full HP: no damage carried over', h1 ~= nil and h1.HP == max1 - 50, h1 and (tostring(h1.HP) .. '/' .. tostring(max1)))

-- 16a'. a stumble back over the line is not leaving: within WaveRules.LeaveMargin of the gate the fight is only paused
local mStep = mark()
standMap(0, g2 + require(RS.Shared.WaveRules).LeaveMargin - 2.5, 0)
wall(0.6)
check("16a' a step back over gate 2's line (" .. (require(RS.Shared.WaveRules).LeaveMargin - 2.5) .. " studs): no reset, the goons just turn for home", lastWave(2, mStep, true) == nil and attr('WaveStage') == 1, state())
standMap(0, g2 - 20, 0)
wall(0.6)
local stepped = lastWave(2, mStep, false)
check("16a' ... and stepping back in, goon 1 still has its damage", stepped ~= nil and stepped.HP[1] == max1 - 50, stepped and tostring(stepped.HP[1]))

-- 16b. a side step that stays in the stage keeps the fight as it is (Stage 2 has no side street: the rule, faked here by
-- standing past the street's edge, |x| > HalfWidth + 2, between its gates)
local mSide = mark()
standMap(39.5, g2 - 20, 0)
wall(0.6)
check('16b off the street inside Stage 2: no reset (HP kept), the goons just head home', lastWave(2, mSide, true) == nil and attr('WaveStage') == 0, state())
standMap(0, g2 - 20, 0)
wall(0.6)
local kept = lastWave(2, mSide, false)
check('16b back on the street: goon 1 still at its damage', kept ~= nil and kept.HP[1] == max1 - 50, kept and tostring(kept.HP[1]))

-- 16c. into the lobby: the run ends, the Stage 1 crew walks home whole (no pop), and a new run finds it whole
standMap(0, spawnZ, 0)
wall(0.6)
local mS1 = mark()
standMap(0, g1 - 20, 0) -- (brief 30: was g1 - 12; the crew now idles in front of gate 2, so step in as far as 16a does)
wall(0.8)
local s1 = lastWave(1, mS1)
local home1 = homesOf(1)
local max11 = s1 and s1.Max[1] or 0
local mH1 = mark()
fire(1, 1, 10)
wall(1.2)
local hh = sent('WaveState', 'Hit', mH1)[1]
check('16c a new run: hurt a Stage 1 goon', hh ~= nil and hh.HP == max11 - 10, hh and tostring(hh.HP))
local rigs1 = rigs(1)
local mLob = mark()
standMap(0, g1 + 14, 0)
wall(0.6)
step('16c_lobby', 'walked back into the lobby mid-fight')
local resets = sent('WaveState', 'Reset', mLob)
local keep = resets[#resets] and resets[#resets].Keep
check('16c the lobby ends the run; the crew out after you is kept walking (Reset Keep = {1})', attr('RunCleared') == 0 and #resets >= 1 and type(keep) == 'table' and table.find(keep, 1) ~= nil, keep and table.concat(keep, ','))
local okL, whyL = whole(lastWave(1, mLob, true))
check('16c ... whole again (Restored: full HP)', okL, whyL)
local same = true
for i, mdl in rigs(1) do if rigs1[i] and rigs1[i] ~= mdl then same = false end end
check('16c on your screen they walk home (the same goons, not popped back)', same and next(rigs(1)) ~= nil)
wall(4)
local okH1, whyH1 = allHome(lastMoves(1, mLob), home1)
check('16c ... and stand on their spots', okH1, whyH1)
local mIn1 = mark()
standMap(0, g1 - 20, 0)
wall(0.6)
local okN, whyN = whole(lastWave(1, mIn1, false))
check('16c walk back in: full HP', okN, whyN)
hum.MaxHealth, hum.Health = 100, 100

-- 29. (brief 29, P2) the client side of a boss's big moves, fed to your screen as WaveService sends them: red telegraphs
-- go down, a thrown prop flies, a 'Blast' lands one and the rest go once their time is up; no boss here, no boss bar.
do
	local remote = game.ReplicatedStorage.HoodNet.WaveState
	local function teles()
		local n = 0
		for _, d in workspace.HoodGoons:GetDescendants() do if d.Name == 'BossTelegraph' then n += 1 end end
		return n
	end
	local h = homesOf(1)
	local a, b = h[1], h[2]
	-- (brief 30: the crew now idles in front of gate 2 till you come within 25 studs, and an idle goon's telegraph is
	-- called off; the server only sends one mid-fight, so walk up to them first)
	hum.MaxHealth, hum.Health = 1e6, 1e6
	standMap(0, a.Z + 12, 0)
	wall(1.0)
	remote:FireClient(P, { Kind = 'Tele', Stage = 1, Index = 1, Move = 'Stomp', Shape = 'Circle', O = { a.X, a.Z }, D = { 0, 1 }, R = 10, P = { { a.X, a.Z } }, T = 1.2, Phase = 1 })
	remote:FireClient(P, { Kind = 'Tele', Stage = 1, Index = 2, Move = 'Throw', Shape = 'Circle', O = { b.X, b.Z }, D = { 0, 1 }, R = 5.5, P = { { b.X, b.Z + 8 } }, T = 1.2, Flight = 0.75, Phase = 2 })
	remote:FireClient(P, { Kind = 'Tele', Stage = 1, Index = 3, Move = 'Blast', Shape = 'Cone', O = { b.X, b.Z }, D = { 0, 1 }, L = 20, A = math.rad(70), T = 1.2 })
	wall(0.6)
	check('29 three big moves: three red telegraphs on your screen', teles() == 3, tostring(teles()))
	local flying = false
	for _, d in workspace.HoodGoons:GetDescendants() do if d.Name == 'Dodgeball' or d.Name == 'MoneyBag' then flying = true end end
	check('29 ... the thrown one is in the air before it lands', flying)
	remote:FireClient(P, { Kind = 'Blast', Stage = 1, Index = 1, Move = 'Stomp', Landed = false, Damage = 0 })
	wall(0.5)
	check('29 the stomp lands: its telegraph goes, the others stay till theirs', teles() == 2, tostring(teles()))
	wall(1.4)
	check('29 ... and with no word from the server they go on time', teles() == 0, tostring(teles()))
	local bar = P.PlayerGui:FindFirstChild('HoodWaves') and P.PlayerGui.HoodWaves:FindFirstChild('BossBar', true)
	check('(brief 30) no boss HP bar on the fight screen at all', bar == nil)
end
hum.MaxHealth, hum.Health = 100, 100

print('[play] ' .. #CHECKS .. ' checks, ' .. #FAILS .. ' failed')
if EXPORT then __fs.writeFile(EXPORT .. '/manifest.json', __serde.encode('json', SHOTS)) end
return { checks = #CHECKS, failed = FAILS }
