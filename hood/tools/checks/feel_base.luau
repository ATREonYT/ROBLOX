-- feel.luau (CRITIC3, BRIEF23): a brand-new young player's first session through the REAL server and client scripts in
-- one DataModel (tools/harness.luau on a private src). Every HoodServer *.server script (but Bootstrap and the unit-test
-- runner) runs against a stub DataService; every HoodClient *.client script (but StudioCheck) runs for the LocalPlayer.
-- Route: spawn -> BAY 1 (earn Power) -> Stage 1 (goons) -> the next gate -> the pads -> back in the lobby (is the run
-- reset?) -> a shoe box -> a rebirth. It logs what the player sees and two clocks:
--   K = the KID clock: walking at the character's WalkSpeed (distance / speed) + real waiting (wall seconds, which
--       is what the servers run on), i.e. how long a real kid spends;
--   wall = harness wall time (slower than real: the frames cost more in Lune).
-- With EXPORT=dir it writes render13 scenes + cameras + ScreenGui trees per step (tools/shots.py composites them) and
-- one big LOOK scene of the lobby + stages 1-3 AS THE CLIENT PAINTS THEM (lanes, labels, gates), look_scene.json.
-- Fast-forwards are logged as such (FF).
local RS = game.ReplicatedStorage
local Players = game:GetService('Players')
local CS = game:GetService('CollectionService')
local HS = game.ServerScriptService.HoodServer
local Schema = require(HS.ProfileSchema)
local Art = require(RS.Shared.SkinArt)
local WaveRules = require(RS.Shared.WaveRules)
local RebirthRules = require(RS.Shared.RebirthRules)
local Balance = require(RS.Shared.Config.Balance)
local Skins = require(RS.Shared.Config.Skins)
_G.__screenSize = Vector2.new(1200, 617)
_G.__fullSize = Vector2.new(1200, 675)
_G.__safeSize = Vector2.new(1200, 675)
local V2 = require(game.ServerStorage.TheBlockV2)
V2.Build()
-- (HOOK) Lune keeps a part's Position apart from its CFrame and has no default for it: the map's static parts get theirs
-- (GunService measures the buy distance with GunPoint.Position, as Roblox allows).
for _, d in workspace:GetDescendants() do if d:IsA('BasePart') then pcall(function() d.Position = d.CFrame.Position end) end end
pcall(function() WaveRules.RespawnDelay = 600 end)
local net = Instance.new('Folder'); net.Name = 'HoodNet'; net.Parent = RS
do -- every remote Net.lua defines (so new ones come along)
	local n = 0
	for name, cls in RS.Shared.Net.Source:gmatch("([%w_]+)%s*=%s*'(Remote%w+)'") do
		if not net:FindFirstChild(name) then local e = Instance.new(cls); e.Name = name; e.Parent = net; n += 1 end
	end
	if n == 0 then print('[feel] WARNING: no remotes parsed from Net.lua') end
end
RS:SetAttribute('FoundationReady', true)
local cam = Instance.new('Camera'); cam.Name = 'Camera'; cam.FieldOfView = 70; cam.CFrame = CFrame.new(2400, 20, 120)
pcall(function() cam.ViewportSize = Vector2.new(1200, 675) end)
cam.Parent = workspace; workspace.CurrentCamera = cam
pcall(function()
	local U = game:GetService('UserInputService')
	U.TouchEnabled, U.MouseEnabled, U.KeyboardEnabled, U.GamepadEnabled = false, true, true, false
end)
local P = Players.LocalPlayer
if not P then P = Instance.new('Player'); P.Name = 'Tester'; P.Parent = Players; pcall(function() Players.LocalPlayer = P end) end
for _, c in { 'PlayerGui', 'Backpack' } do if not P:FindFirstChild(c) then local x = Instance.new(c); x.Parent = P end end
pcall(function() P.DisplayName = 'Tester' end)

-- A blocky R15-sized avatar (5.5 studs): classic colours so it reads in the pictures.
local char = Instance.new('Model'); char.Name = 'Tester'
local root = Instance.new('Part'); root.Name = 'HumanoidRootPart'; root.Size = Vector3.new(2, 2, 1); root.Transparency = 1; root.Anchored = true
root.CFrame = CFrame.new(0, 3, 0); pcall(function() root.Position = Vector3.new(0, 3, 0) end); root.Parent = char
local SKIN, SHIRT, PANTS = Color3.fromRGB(245, 205, 48), Color3.fromRGB(13, 105, 172), Color3.fromRGB(75, 151, 75)
for seg, box in Art.Rig do
	local p = Instance.new('Part'); p.Name = seg; p.Size = box[1]; p.CFrame = CFrame.new(box[2]); pcall(function() p.Position = box[2] end); p.Anchored = true
	p.Material = Enum.Material.SmoothPlastic
	p.Color = SKIN
	if seg:find('Torso') then p.Color = SHIRT end
	if seg:find('Leg') or seg:find('Foot') then p.Color = PANTS end
	p.Parent = char
end
local hum = Instance.new('Humanoid'); hum.MaxHealth = 100; hum.Health = 100; hum.HipHeight = 2; hum.RigType = Enum.HumanoidRigType.R15; hum.WalkSpeed = 16; hum.MoveDirection = Vector3.new(); hum.Parent = char
char.PrimaryPart = root
char.Parent = workspace
P.Character = char
local frameCF = CFrame.new(workspace.TheBlockV2:GetAttribute('Origin') or Vector3.zero)
local function moveTo(cf)
	local delta = cf * root.CFrame:Inverse()
	for _, d in char:GetDescendants() do if d:IsA('BasePart') then d.CFrame = delta * d.CFrame; pcall(function() d.Position = d.CFrame.Position end) end end
end
local function yawOf(dx, dz) return math.atan2(-dx, -dz) end
local function standMap(x, z, yaw, floor) moveTo(frameCF * CFrame.new(x, (floor or 0) + 3, z) * CFrame.Angles(0, yaw or 0, 0)) end
local function mapPos() return frameCF:PointToObjectSpace(root.CFrame.Position) end
local function floorOf(part) return frameCF:PointToObjectSpace(part.CFrame.Position).Y - part.Size.Y / 2 end

local data = Schema.new()
_G.__profile = { Data = data }
local fake = Instance.new('Folder'); fake.Name = 'FakeServer'; fake.Parent = game.ServerScriptService
local stub = Instance.new('ModuleScript'); stub.Name = 'DataService'; stub.Parent = fake
stub.Source = [[
local RS = game:GetService('ReplicatedStorage')
local D = {}
function D.get() return _G.__profile end
function D.snapshot() local ok, S = pcall(require, script.Parent.ProfileSchema); if ok and S.public then return S.public(_G.__profile.Data) end return _G.__profile.Data end
function D.push(player) _G.__pushes = (_G.__pushes or 0) + 1; local f = RS:FindFirstChild('HoodNet'); local e = f and f:FindFirstChild('ProfileUpdated'); if e then e:FireClient(player, D.snapshot()) end end
function D.release() end
function D.setSetting(player, k, v) _G.__profile.Data.Settings = _G.__profile.Data.Settings or {}; _G.__profile.Data.Settings[k] = v; return true end
function D.start() end
return D
]]
-- every other HoodServer module rides along (script.Parent.X in the services resolves to these copies)
for _, m in HS:GetChildren() do
	if m:IsA('ModuleScript') and m.Name ~= 'DataService' and not m.Name:find('%.server$') and m.Name ~= 'Vendor' then
		local c = Instance.new('ModuleScript'); c.Name = m.Name; c.Source = m.Source; c.Parent = fake
	end
end
local nowhere = Instance.new('Part'); nowhere.Name = 'HarnessNowhere'; nowhere.Anchored = true; nowhere.Transparency = 1
nowhere.CFrame = CFrame.new(0, -20000, 0); pcall(function() nowhere.Position = Vector3.new(0, -20000, 0) end); nowhere.Parent = workspace
_G.__nowhere = nowhere
local function lunePatch(source) return (source:gsub('([%w_%.]+%.Adornee) = nil', '%1 = _G.__nowhere')) end
local FAILED = {}
local function run(src, name, parent)
	local m = Instance.new('ModuleScript'); m.Name = name; m.Source = lunePatch(src.Source); m.Parent = parent
	task.spawn(function()
		local ok, err = pcall(require, m)
		if not ok then table.insert(FAILED, name .. ': ' .. tostring(err):sub(1, 200)); print('[feel] ' .. name .. ' failed: ' .. tostring(err)) end
	end)
end
P:SetAttribute('ProfileReady', true)
pcall(function() require(fake.RebirthService).start() end)
local SERVERS = {}
for _, s in HS:GetChildren() do
	local n = s.Name
	if n:find('Service') and not n:find('Bootstrap') and not n:find('UnitTest') and (s:IsA('Script') or n:find('%.server')) then table.insert(SERVERS, s) end
end
table.sort(SERVERS, function(a, b) return a.Name < b.Name end)
local sn = {}
for _, s in SERVERS do table.insert(sn, s.Name); run(s, s.Name, fake) end
local HC = game.StarterPlayer.StarterPlayerScripts.HoodClient
local CLIENTS = {}
for _, c in HC:GetChildren() do
	if (c:IsA('LocalScript') or c.Name:find('%.client')) and not c.Name:find('StudioCheck') then table.insert(CLIENTS, c) end
end
table.sort(CLIENTS, function(a, b) return a.Name < b.Name end)
local cn = {}
for _, c in CLIENTS do table.insert(cn, c.Name); run(c, c.Name .. 'CUT', HC) end

local REP = {}
local function log(s) table.insert(REP, s); print('[feel] ' .. s) end
log('servers: ' .. table.concat(sn, ', '))
log('clients: ' .. table.concat(cn, ', '))
local seen = {}
local function syncInst(inst)
	local now = inst:GetAttributes()
	local last = seen[inst] or {}
	for k, v in now do if last[k] ~= v then __fireOn(inst, 'Attr_' .. k) end end
	for k in last do if now[k] == nil then __fireOn(inst, 'Attr_' .. k) end end
	seen[inst] = now
end
local function sync() syncInst(P); syncInst(P.PlayerGui); syncInst(char) end
local function attrs(list)
	local t = {}
	for _, a in list do local v = P:GetAttribute(a); if v ~= nil then table.insert(t, a .. '=' .. tostring(v)) end end
	return table.concat(t, ' ')
end
local camFn
-- (Touched pads: parts whose Touched/TouchEnded someone connected get a crude overlap test with the avatar's feet)
local touching = {}
local function touchStep()
	local foot = root.CFrame.Position - Vector3.new(0, 2.6, 0)
	for d in _G.__touchParts or {} do
		if d.Parent and d:IsA('BasePart') then
			local lp = d.CFrame:PointToObjectSpace(foot)
			local h = d.Size / 2 + Vector3.new(0.5, 1.2, 0.5)
			local inside = math.abs(lp.X) <= h.X and math.abs(lp.Y) <= h.Y and math.abs(lp.Z) <= h.Z
			local hitPart = char:FindFirstChild('LeftFoot') or root
			if inside and not touching[d] then touching[d] = true; __fireOn(d, 'Touched', hitPart)
			elseif not inside and touching[d] then touching[d] = nil; __fireOn(d, 'TouchEnded', hitPart) end
		end
	end
end
local touchTick = 0
-- the two clocks: K (kid seconds) advances with the wall clock while the kid waits, and by distance / WalkSpeed while
-- the kid walks; exports and logging do not count (lastClock is reset after them).
local K = 0
local W0 = os.clock()
local lastClock = os.clock()
local WALKING = false
local function resetClock() lastClock = os.clock() end
-- EVENT TRACKER (the first-30-seconds scorecard and the dead-time list): everything new the kid could see or hear.
local EV = {}
local evSeen = {}
local function ev(kind, text) table.insert(EV, { t = K, kind = kind, text = text }) end
local TRACK = { 'GoalStep', 'TrainingStation', 'WaveLeft', 'WaveStage', 'RunStage', 'RunCleared', 'StagesCleared', 'EquippedGun', 'Rebirths', 'GuidePhase', 'OnboardingStep', 'TrainingPass' }
local trk = { power = nil, cash = nil, attrs = {}, toClient = 0, sounds = 0, shots = 0, texts = {}, tool = nil, pos = nil, goonNear = false, popups = 0 }
local function shape(t) return (t:gsub('<[^>]+>', ''):gsub('%d[%d%.,]*[KMBkmb]?', '#')) end
local function scanTexts()
	local G = P.PlayerGui
	local now = {}
	for _, g in G:GetChildren() do
		if (g:IsA('ScreenGui') or g:IsA('BillboardGui')) and g.Enabled then
			for _, l in g:GetDescendants() do
				if (l:IsA('TextLabel') or l:IsA('TextButton')) and l.Text ~= '' and l.TextTransparency < 0.6 then
					local vis = true
					local x = l
					while x and x:IsA('GuiObject') do if not x.Visible then vis = false; break end; x = x.Parent end
					if vis then now[g.Name .. ':' .. shape(l.Text)] = l.Text end
				end
			end
		end
	end
	for k, t in now do
		if not trk.texts[k] then
			local plain = t:gsub('<[^>]+>', '')
			if plain:match('^%s*[%+%-]?[%d%.,]+[KMB]?%s*$') then trk.popups += 1 -- (counters and +N popups: counted, not listed)
			elseif not evSeen['txt:' .. k] then evSeen['txt:' .. k] = true; ev('text', k:match('^[^:]+') .. ': ' .. plain:sub(1, 70)) end
		end
	end
	trk.texts = now
end
local function track()
	if trk.power ~= data.Rep then
		if trk.power and data.Rep > trk.power then
			if not evSeen.power1 then evSeen.power1 = true; ev('power', ('Power %d -> %d (first gain)'):format(trk.power, data.Rep)) end
			for _, m in { 10, 100, 1000, 10000, 100000, 1000000 } do
				if trk.power < m and data.Rep >= m and not evSeen['pm' .. m] then evSeen['pm' .. m] = true; ev('power', ('Power reaches %d'):format(m)) end
			end
		elseif trk.power and data.Rep < trk.power then ev('power', ('Power %d -> %d'):format(trk.power, data.Rep)) end
		trk.power = data.Rep
	end
	if trk.cash ~= data.Cash then
		if trk.cash then ev('cash', ('Cash %d -> %d (%+d)'):format(trk.cash, data.Cash, data.Cash - trk.cash)) end
		trk.cash = data.Cash
	end
	for _, a in TRACK do
		local v = P:GetAttribute(a)
		if trk.attrs[a] ~= v then
			if trk.attrs[a] ~= nil or v ~= nil then ev('attr', a .. ' = ' .. tostring(v)) end
			trk.attrs[a] = v
		end
	end
	for i = trk.toClient + 1, #_G.__toClient do
		local m = _G.__toClient[i]
		local nm, x = m[1], m[2]
		if nm == 'WaveState' and type(x) == 'table' then
			if x.Kind ~= 'Moves' and x.Kind ~= 'Hit' and x.Kind ~= 'Punch' then ev('server', 'WaveState ' .. tostring(x.Kind) .. (x.Reward and (' reward ' .. tostring(x.Reward)) or '')) end
			if x.Kind == 'Hit' and not evSeen.hit then evSeen.hit = true; ev('server', 'first hit on a goon') end
			if x.Kind == 'Hit' and x.HP == 0 then ev('server', 'goon KO (Left ' .. tostring(x.Left) .. ')') end
			if x.Kind == 'Punch' and x.Landed and not evSeen.punch then evSeen.punch = true; ev('server', 'first punch lands on the kid') end
		elseif nm == 'Notice' then ev('server', 'Notice: ' .. tostring(x):sub(1, 70))
		elseif nm == 'Cinematic' and type(x) == 'table' then ev('server', 'Cinematic ' .. tostring(x.Kind) .. (x.Reward and (' +' .. tostring(x.Reward)) or ''))
		elseif nm == 'Goal' then ev('server', 'Goal message ' .. (type(x) == 'table' and tostring(x.Text or x.Kind or '') or tostring(x)):sub(1, 60))
		elseif nm ~= 'ProfileUpdated' and nm ~= 'WaveState' and nm ~= 'Shoot' and nm ~= 'WaveShot' then
			if not evSeen['rc:' .. nm] then evSeen['rc:' .. nm] = true; ev('server', 'remote ' .. nm) end
		end
	end
	trk.toClient = #_G.__toClient
	local snd = _G.__sounds or {}
	if #snd > trk.sounds then
		local names = {}
		for i = trk.sounds + 1, #snd do names[snd[i][1]] = true end
		for nmS in names do if not evSeen['snd:' .. nmS] then evSeen['snd:' .. nmS] = true; ev('sound', 'first sound ' .. nmS) end end
		trk.sounds = #snd
	end
	local sh = _G.__shots or {}
	for i = trk.shots + 1, #sh do
		if not evSeen['send:' .. tostring(sh[i][1])] then evSeen['send:' .. tostring(sh[i][1])] = true; ev('input', 'client sends ' .. tostring(sh[i][1])) end
	end
	trk.shots = #sh
	local tool = char:FindFirstChildOfClass('Tool')
	local tn = tool and tool.Name or 'none'
	if trk.tool ~= tn then ev('gun', 'in hand: ' .. tn); trk.tool = tn end
	local p = root.CFrame.Position
	if trk.pos and (p - trk.pos).Magnitude > 25 then ev('teleport', ('teleported %.0f studs'):format((p - trk.pos).Magnitude)) end
	trk.pos = p
	local near = false
	local f = workspace:FindFirstChild('HoodGoons')
	for _, m in f and f:GetChildren() or {} do
		local ok, cf = pcall(function() return m:GetPivot() end)
		if ok and (cf.Position - p).Magnitude < 45 then near = true end
	end
	if near and not trk.goonNear then ev('goon', 'goons in sight (< 45 studs)') end
	trk.goonNear = near
	local mz = frameCF:PointToObjectSpace(p).Z
	if mz < -0.5 and mz > -1100 then
		local n = math.floor(-mz / 64) + 1
		if not evSeen['gate' .. n] then evSeen['gate' .. n] = true; ev('gate', ('walked through gate %d (into Stage %d)'):format(n, n)) end
	end
	scanTexts()
end
local function frame(dt)
	local steps = math.max(1, math.floor(dt / (1 / 30) + 0.5))
	for _ = 1, steps do
		if camFn then camFn() end
		__fireOn(game:GetService('RunService'), 'PreRender', 1 / 30)
		for _, fn in table.clone(_G.__bound) do pcall(fn, 1 / 30) end
		__fireOn(game:GetService('RunService'), 'Heartbeat', 1 / 30)
		__fireOn(game:GetService('RunService'), 'Stepped', 0, 1 / 30)
		__stepTweens(1 / 30)
		touchTick += 1
		if touchTick % 3 == 0 then touchStep() end
		task.wait(1 / 30)
		sync()
		local now = os.clock()
		if not WALKING then K += now - lastClock end
		lastClock = now
		if touchTick % 3 == 0 then track() end
	end
end
local function wall(t)
	local t0 = os.clock()
	while os.clock() - t0 < t do frame(1 / 30) end
end
local function waitFor(cond, maxWall)
	local t0 = os.clock()
	while not cond() and os.clock() - t0 < (maxWall or 10) do frame(1 / 30) end
	return cond(), os.clock() - t0
end
local function walkSpeed() local s = hum.WalkSpeed; return (s and s > 0) and s or 16 end
local WALKED = 0
local function walk(x0, z0, x1, z1, floor)
	local d = Vector3.new(x1 - x0, 0, z1 - z0)
	local yaw = yawOf(d.X, d.Z)
	local n = math.max(1, math.floor(d.Magnitude / 1.6))
	local t0 = os.clock()
	WALKING = true
	local lastSet
	for k = 1, n do
		local a = k / n
		-- a server teleport (pad, KO, slip-back) moves the avatar away from where we last put it: stop walking there
		if lastSet and (root.CFrame.Position - lastSet).Magnitude > 6 then
			ev('teleport', 'moved by the game during a walk')
			WALKED += d.Magnitude * (k - 1) / n
			WALKING = false
			return os.clock() - t0, true
		end
		standMap(x0 + d.X * a, z0 + d.Z * a, yaw, floor)
		lastSet = root.CFrame.Position
		K += d.Magnitude / n / walkSpeed() -- (a real kid walks it at WalkSpeed; the harness's frames are slower)
		frame(1 / 10)
	end
	WALKING = false
	WALKED += d.Magnitude
	return os.clock() - t0
end
local function walkTo(x1, z1, floor) local p = mapPos(); return walk(p.X, p.Z, x1, z1, floor) end -- (returns wall time, movedByGame)
local function press(prompt) __fireOn(prompt, 'Triggered', P) end
local function sentKinds(kind, from)
	local n = 0
	for i = from or 1, #_G.__toClient do local m = _G.__toClient[i]; if m[1] == 'WaveState' and type(m[2]) == 'table' and m[2].Kind == kind then n += 1 end end
	return n
end
local function lastTo(name, kind)
	for i = #_G.__toClient, 1, -1 do
		local m = _G.__toClient[i]
		if m[1] == name and (not kind or (type(m[2]) == 'table' and m[2].Kind == kind)) then return m[2], i end
	end
	return nil
end
local function goons()
	local list = {}
	for _, f in { workspace:FindFirstChild('HoodGoons'), workspace:FindFirstChild('HoodGoons', true) } do
		for _, m in f and f:GetChildren() or {} do if m:IsA('Model') and not table.find(list, m) then table.insert(list, m) end end
	end
	return list
end
local function look(eyeMap, atMap) cam.CFrame = CFrame.lookAt(frameCF:PointToWorldSpace(eyeMap), frameCF:PointToWorldSpace(atMap)) end
local function behind(dx, dz, back, up, pitch)
	return function()
		local p = mapPos()
		local d = Vector3.new(dx, 0, dz).Unit
		local eye = p - d * back + Vector3.new(0, up, 0)
		local at = eye + (d + Vector3.new(0, -math.tan(math.rad(pitch or 7)), 0)) * 30
		look(eye, at)
	end
end
-- Roblox's default follow camera as the Studio frame ours_studio_spawn.png shows it (solved: 11.2 studs behind,
-- 4.5 over the root, 15 degrees down)
local function follow(dx, dz)
	return function()
		local p = mapPos()
		local d = Vector3.new(dx, 0, dz).Unit
		local eye = p - d * 11.2 + Vector3.new(0, 4.45, 0)
		look(eye, eye + (d + Vector3.new(0, -math.tan(math.rad(15)), 0)) * 30)
	end
end
local function shoulder()
	local p = mapPos()
	look(p + Vector3.new(3.5, 6.5, 10.5), p + Vector3.new(-0.5, 2.2, -12))
end

-- Shots
local SHOTS = {}
local function guiList()
	local list = {}
	for _, g in P.PlayerGui:GetChildren() do
		if g:IsA('ScreenGui') and g.Enabled then table.insert(list, g) end
	end
	table.sort(list, function(a, b) if a.DisplayOrder ~= b.DisplayOrder then return a.DisplayOrder < b.DisplayOrder end return a.Name < b.Name end)
	return list
end
local function placeGun()
	pcall(function()
		local tool = char:FindFirstChildOfClass('Tool')
		local hand = char:FindFirstChild('RightHand')
		local handle = tool and tool:FindFirstChild('Handle')
		if not handle or not hand then return end
		local want = hand.CFrame * CFrame.new(0, -0.2, -0.3) * CFrame.Angles(-math.pi / 2, 0, 0) * tool.Grip:Inverse()
		local delta = want * handle.CFrame:Inverse()
		for _, d in tool:GetDescendants() do if d:IsA('BasePart') then d.CFrame = delta * d.CFrame; pcall(function() d.Position = d.CFrame.Position end) end end
	end)
end
local function shot(tag, note, radius)
	if camFn then camFn() end
	placeGun()
	local entry = { tag = tag, note = note or '', guis = {} }
	table.insert(SHOTS, entry)
	if not EXPORT then return end
	local moved = {}
	for _, b in P.PlayerGui:GetChildren() do
		if b:IsA('BillboardGui') and b.Enabled then
			local ad = b.Adornee
			if ad and ad:IsA('BasePart') then table.insert(moved, b); b.Parent = ad end
		end
	end
	local keep = {}
	local o = cam.CFrame.Position
	local fwd = cam.CFrame.LookVector
	local r = radius or 160
	for _, d in workspace:GetDescendants() do
		if d:IsA('BasePart') then
			local v = d.CFrame.Position - o
			local m = v.Magnitude
			if (m < r and (m < 40 or v:Dot(fwd) > -10)) or math.max(d.Size.X, d.Size.Y, d.Size.Z) > 150 then keep[d] = true end
			if d.Name == 'GuideTrail' then keep[d] = true end
		end
	end
	keep[root] = nil
	local ok, err = pcall(__exportParts, keep, EXPORT .. '/scene_' .. tag .. '.json', 3)
	if not ok then print('[feel] export failed: ' .. tostring(err)) end
	for _, b in moved do b.Parent = P.PlayerGui end
	for _, g in guiList() do
		local okU, errU = pcall(__exportUI, g, EXPORT .. '/' .. tag .. '_' .. g.Name .. '.json')
		if okU then table.insert(entry.guis, g.Name) else print('[feel] ui export ' .. g.Name .. ' failed: ' .. tostring(errU)) end
	end
	local c = cam.CFrame
	local at = c.Position + c.LookVector * 30
	__fs.writeFile(EXPORT .. '/cam_' .. tag .. '.json', __serde.encode('json', { pos = { c.Position.X, c.Position.Y, c.Position.Z }, look = { at.X, at.Y, at.Z } }))
end
-- the LOOK export: the lobby + stages 1-3 as the client paints them now (no avatar), one file
local function lookExport(name)
	if not EXPORT then return end
	local keep = {}
	for _, d in workspace:GetDescendants() do
		if d:IsA('BasePart') and not d:IsDescendantOf(char) then
			local q = frameCF:PointToObjectSpace(d.CFrame.Position)
			if (math.abs(q.X) <= 140 and q.Z >= -200 and q.Z <= 200) or math.max(d.Size.X, d.Size.Y, d.Size.Z) > 150 then keep[d] = true end
		end
	end
	local moved = {}
	for _, b in P.PlayerGui:GetChildren() do
		if b:IsA('BillboardGui') and b.Enabled then
			local ad = b.Adornee
			if ad and ad:IsA('BasePart') then table.insert(moved, b); b.Parent = ad end
		end
	end
	local ok, err = pcall(__exportParts, keep, EXPORT .. '/' .. name .. '.json', 3)
	if not ok then print('[feel] look export failed: ' .. tostring(err)) end
	for _, b in moved do b.Parent = P.PlayerGui end
end

-- What the screen says (best effort over the current ScreenGuis: every visible text, compacted)
local function textOf(gui, name)
	local x = gui and gui:FindFirstChild(name, true)
	return x and (x:IsA('TextLabel') or x:IsA('TextButton')) and x.Text or nil
end
local function strip(s) return s and (s:gsub('<[^>]+>', '')) or nil end
local function visibleChain(g)
	local x = g
	while x and x:IsA('GuiObject') do
		if not x.Visible then return false end
		x = x.Parent
	end
	return true
end
local function screen()
	local G = P.PlayerGui
	local t = {}
	local hud = G:FindFirstChild('HoodHUD')
	if hud and hud.Enabled then
		local h = textOf(hud, 'Hint')
		if h and h ~= '' then table.insert(t, 'hint "' .. strip(h) .. '"') end
	end
	local goals = G:FindFirstChild('HoodGoals')
	if goals and goals.Enabled then
		local g = goals:FindFirstChild('Goal', true)
		if g and g:IsA('GuiObject') and g.Visible then
			local parts = {}
			for _, d in g:GetDescendants() do if (d:IsA('TextLabel')) and d.Text ~= '' and visibleChain(d) then table.insert(parts, strip(d.Text)) end end
			table.insert(t, 'goal "' .. table.concat(parts, ' | ') .. '"')
		end
		local m = goals:FindFirstChild('GoalDone', true)
		if m then
			local parts = {}
			for _, d in m:GetDescendants() do if d:IsA('TextLabel') and d.Text ~= '' then table.insert(parts, strip(d.Text)) end end
			table.insert(t, 'GOAL DONE "' .. table.concat(parts, ' | ') .. '"')
		end
	end
	local waves = G:FindFirstChild('HoodWaves')
	if waves then
		for _, d in waves:GetDescendants() do
			if d:IsA('TextLabel') and d.Text ~= '' and visibleChain(d) and d.TextTransparency < 0.9 then table.insert(t, 'waves "' .. strip(d.Text) .. '"') end
		end
	end
	local notices = G:FindFirstChild('HoodNotices')
	if notices then for _, d in notices:GetDescendants() do if d:IsA('TextLabel') and d.Text ~= '' and visibleChain(d) then table.insert(t, 'notice "' .. strip(d.Text) .. '"') end end end
	for _, gname in { 'StageFeedback', 'HoodStages' } do
		local fb = G:FindFirstChild(gname)
		if fb then for _, d in fb:GetDescendants() do if d:IsA('TextLabel') and d.Visible and d.Text ~= '' and d.TextTransparency < 0.9 then table.insert(t, 'stage "' .. strip(d.Text) .. '"') end end end
	end
	local mom = hud and hud:FindFirstChild('RebirthMoment', true)
	if mom then table.insert(t, 'rebirth moment') end
	local win = G:GetAttribute('HoodWindow')
	if win and win ~= '' then table.insert(t, 'window ' .. win) end
	return table.concat(t, ' | ')
end
local function toolWhere()
	local inChar = char:FindFirstChildOfClass('Tool')
	local inBp = P:FindFirstChild('Backpack') and P.Backpack:FindFirstChildOfClass('Tool')
	return inChar and ('in hand: ' .. inChar.Name) or inBp and ('in Backpack only: ' .. inBp.Name) or 'no gun Tool'
end
local function state()
	return attrs({ 'Power', 'Cash', 'Rebirths', 'TrainingStation', 'StagesCleared', 'RunStage', 'RunCleared', 'WaveCleared', 'WaveStage', 'WaveLeft', 'GoalStep', 'GuidePhase', 'EquippedGun' })
		.. ' hp=' .. math.floor(hum.Health) .. ' gun=' .. toolWhere()
end
local function step(tag, note, radius)
	local p = mapPos()
	log(('[%s] K=%.1fs wall=%.1fs at (%.0f,%.0f) %s'):format(tag, K, os.clock() - W0, p.X, p.Z, note or ''))
	log('    state: ' .. state())
	log('    screen: ' .. screen())
	shot(tag, note, radius)
	resetClock()
end
local MARK = {}
local function mark(name, extra) MARK[name] = K; log(('  >> %s at K=%.1fs %s'):format(name, K, extra or '')) end
local ISSUES = {}
local function issue(s) table.insert(ISSUES, s); log('  !! ' .. s) end
local UIS = game:GetService('UserInputService')
local MOUSE = { UserInputType = Enum.UserInputType.MouseButton1, KeyCode = Enum.KeyCode.Unknown, Position = Vector3.new(600, 300, 0) } -- (HOOK: a real InputObject has Position)
local function hold(on) if on then __fireOn(UIS, 'InputBegan', MOUSE, false) else __fireOn(UIS, 'InputEnded', MOUSE) end end
local pressTick = 0
local function keepPressing() pressTick += 1; if pressTick % 6 == 0 then hold(true) end end
local function goalsDone() local n = 0; for _, m in _G.__toClient do if m[1] == 'Goal' then n += 1 end end; return n end
local function momentShown() local g = P.PlayerGui:FindFirstChild('HoodGoals'); return g ~= nil and g:FindFirstChild('GoalDone', true) ~= nil end
local function waitMoment(maxWall, after) local ok = waitFor(momentShown, maxWall or 8); if ok then wall(after or 1.4) end; return ok end
local function zoneOf(id) local m = workspace.TheBlockV2:FindFirstChild('Training_' .. id, true); return m and m:FindFirstChild('TrainingZone', true) end
local function laneDir(zone)
	local m = zone:FindFirstAncestorWhichIsA('Model')
	while m and not m.Name:find('^Training_') do m = m.Parent and m.Parent:IsA('Model') and m.Parent or nil end
	local zq = frameCF:PointToObjectSpace(zone.CFrame.Position)
	for _, d in (m or zone.Parent):GetDescendants() do
		if d:IsA('Model') and d:GetAttribute('Main') and typeof(d:GetAttribute('Aim')) == 'Vector3' then
			local a = frameCF:PointToObjectSpace(d:GetAttribute('Aim'))
			return Vector3.new(a.X - zq.X, 0, a.Z - zq.Z).Unit
		end
	end
	return Vector3.new(-1, 0, 0)
end
local function billboardTexts(part)
	local t = {}
	for _, d in part:GetDescendants() do
		if d:IsA('BillboardGui') or d:IsA('SurfaceGui') then
			local bits = {}
			for _, l in d:GetDescendants() do if (l:IsA('TextLabel') or l:IsA('TextButton')) and l.Text ~= '' then table.insert(bits, strip(l.Text) .. (l.TextTransparency > 0.5 and '(faded)' or '')) end end
			if #bits > 0 then table.insert(t, (d.Enabled and '' or '[off] ') .. table.concat(bits, ' / ')) end
		end
	end
	return table.concat(t, ' || ')
end
local function fontsOf(part)
	local f = {}
	for _, l in part:GetDescendants() do
		if l:IsA('TextLabel') and l.Text ~= '' then
			local ok, ff = pcall(function() return l.FontFace and l.FontFace.Family end)
			local name = (ok and ff) or tostring(l.Font)
			name = tostring(name):match('([%w]+)%.json') or tostring(name)
			f[name] = true
		end
	end
	local out = {}
	for k in f do table.insert(out, k) end
	return table.concat(out, ',')
end
local function tagged(tag) local r = {}; for _, d in CS:GetTagged(tag) do if d:IsDescendantOf(workspace) then table.insert(r, d) end end; return r end
local function gateModel(n) for _, g in tagged('HoodStageGate') do if g:GetAttribute('Stage') == n then return g end end end
-- Is gate n passable right now? Walk from 4 studs before its line to 6 past, wait, see if the server put us back.
local function gatePass(n)
	local g = gateModel(n)
	if not g then return nil, 'no gate model' end
	local z = g:GetAttribute('LineZ') or frameCF:PointToObjectSpace(g:GetPivot().Position).Z
	standMap(0, z + 4, 0); frame(0.3)
	walk(0, z + 4, 0, z - 6)
	waitFor(function() return false end, 0.9)
	local p = mapPos()
	return p.Z < z - 2, ('line z %.1f, ended at z %.1f'):format(z, p.Z)
end
local function inLobby() local p = mapPos(); return p.Z > 4 and p.Z < 125 and math.abs(p.X) < 80 end

-- every gate model, its sign, and the client's gate state
local function gateReport(n)
	local g = gateModel(n)
	if not g then return 'gate ' .. n .. ': none' end
	local txt = billboardTexts(g)
	local blocks = 0
	for _, d in g:GetDescendants() do if d:IsA('BasePart') and d.CanCollide and d.Transparency < 0.5 and d.Name:lower():find('bar') then blocks += 1 end end
	return ('gate %d: attrs Required=%s Open=%s | solid bars %d | text: %s'):format(n, tostring(g:GetAttribute('Required')), tostring(g:GetAttribute('Open')), blocks, txt:sub(1, 240))
end
-- the pads in stage n (the strip in front of gate n+1)
local function padsOf(n)
	local g = gateModel(n + 1)
	local zEnd = g and (g:GetAttribute('LineZ') or frameCF:PointToObjectSpace(g:GetPivot().Position).Z) or -(n * 64)
	local found = {}
	for _, d in workspace.TheBlockV2:GetDescendants() do
		if d:IsA('BasePart') and (d.Name:match('Pad$') or d.Name:match('Pad_%w+$')) and not d.Name:match('Base$') then
			local q = frameCF:PointToObjectSpace(d.CFrame.Position)
			if q.Z < zEnd + 30 and q.Z > zEnd - 2 and math.abs(q.X) < 40 then table.insert(found, d) end
		end
	end
	table.sort(found, function(a, b) return frameCF:PointToObjectSpace(a.CFrame.Position).X < frameCF:PointToObjectSpace(b.CFrame.Position).X end)
	return found, zEnd
end
-- the parts that belong to a pad: within 4 studs of its centre (x/z), not the gate
local function padParts(pad)
	local c = frameCF:PointToObjectSpace(pad.CFrame.Position)
	local r = {}
	for _, d in workspace.TheBlockV2:GetDescendants() do
		if d:IsA('BasePart') then
			local q = frameCF:PointToObjectSpace(d.CFrame.Position)
			if math.abs(q.X - c.X) <= math.max(4, pad.Size.X / 2 + 1) and math.abs(q.Z - c.Z) <= math.max(4, pad.Size.Z / 2 + 1) and q.Y < 16 then table.insert(r, d) end
		end
	end
	return r
end
local function padTexts(pad)
	local t = {}
	for _, d in padParts(pad) do local x = billboardTexts(d); if x ~= '' then table.insert(t, x) end end
	return table.concat(t, ' || ')
end
local function padFonts(pad)
	local t = {}
	for _, d in padParts(pad) do local x = fontsOf(d); if x ~= '' then t[x] = true end end
	local o = {}; for k in t do table.insert(o, k) end
	return table.concat(o, ',')
end
local function padInfo(pad)
	local q = frameCF:PointToObjectSpace(pad.CFrame.Position)
	local prompt
	for _, d in padParts(pad) do prompt = prompt or d:FindFirstChildWhichIsA('ProximityPrompt', true) end
	return ('%s at (%.1f, %.1f) size %.0fx%.0f colour %d,%d,%d prompt=%s | labels: %s | fonts: %s'):format(pad.Name, q.X, q.Z, pad.Size.X, pad.Size.Z,
		math.floor(pad.Color.R * 255), math.floor(pad.Color.G * 255), math.floor(pad.Color.B * 255), prompt and (prompt.ActionText .. '/' .. tostring(prompt:GetAttribute('Target'))) or 'none', padTexts(pad):sub(1, 300), padFonts(pad))
end

---------------------------------------------------------------------------------------------------------- 0. spawn
local SP = workspace.TheBlockV2:GetAttribute('LobbySpawn') or Vector3.new(0, 0, 55)
standMap(SP.X, SP.Z, workspace.TheBlockV2:GetAttribute('LobbySpawnYaw') or 0)
pcall(function() __fireOn(P, 'CharacterAdded', char) end)
camFn = follow(0, -1)
K = 0; resetClock(); EV = {}
ev('spawn', 'spawned (fresh save)')
frame(0.3)
log('core GUI after the clients started: ' .. (function() local t = {}; for k, v in _G.__coreGui or {} do table.insert(t, k .. '=' .. tostring(v)) end; return #t > 0 and table.concat(t, ' ') or 'untouched (the Roblox hotbar shows)' end)())
log('gun at spawn (0.3 s): ' .. toolWhere())
-- a kid's first input: click / hold the mouse right away (does anything answer?)
local CLICK_AT = K
ev('input', 'kid clicks (holds 1 s) on the spawn')
hold(true)
wall(1.0)
hold(false)
wall(0.3)
step('01_spawn', 'fresh player on the spawn after a first click, the default camera', 330)
lookExport('look_scene')
resetClock()
if (_G.__coreGui or {}).Backpack ~= false then issue('HOTBAR: the Roblox Backpack hotbar is still enabled (BRIEF23: SetCoreGuiEnabled(Backpack, false))') end
if not char:FindFirstChildOfClass('Tool') then issue('GUN: no gun in hand at spawn (' .. toolWhere() .. '); BRIEF23 wants it always equipped') end

---------------------------------------------------------------------------------------------------------- 1. BAY 1
local bay1
for _, s in Skins.Stations do if (s.Rebirths or 0) == 0 and not s.Pass and not s.RobuxPrice then bay1 = s; break end end
local z1 = bay1 and zoneOf(bay1.Id)
if not z1 then issue('BAY 1: no TrainingZone for the first free station'); end
local zp = z1 and frameCF:PointToObjectSpace(z1.CFrame.Position) or Vector3.new(-37, 0, 42)
local ld = z1 and laneDir(z1) or Vector3.new(-1, 0, 0)
log(('BAY 1 = %s (%s) zone at (%.1f, %.1f), shoots toward (%.2f, %.2f); %.0f studs from the spawn'):format(bay1 and bay1.Id or '?', bay1 and bay1.Name or '?', zp.X, zp.Z, ld.X, ld.Z, (Vector3.new(zp.X, 0, zp.Z) - Vector3.new(SP.X, 0, SP.Z)).Magnitude))
-- along the floor: first across to the lane's mouth, then in (a kid follows the arrow/trail)
local mouth = Vector3.new(zp.X - ld.X * 9, 0, zp.Z - ld.Z * 9)
walkTo(mouth.X, SP.Z)
camFn = follow(ld.X, ld.Z)
frame(0.2)
step('02_walk_to_bay1', 'on the way to BAY 1', 220)
walkTo(mouth.X, mouth.Z)
walkTo(zp.X, zp.Z, floorOf(z1 or root) )
standMap(zp.X, zp.Z, yawOf(ld.X, ld.Z), z1 and floorOf(z1) or 0)
camFn = follow(ld.X, ld.Z)
local p0 = data.Rep
mark('in_bay1')
local ok10 = waitFor(function() return data.Rep > p0 end, 6)
mark('first_power', ('(Power %d -> %d)'):format(p0, data.Rep))
step('03_bay1_autoshoot', ('in BAY 1, no input: Power %d -> %d'):format(p0, data.Rep), 160)
local tR, pR = K, data.Rep
waitFor(function() return data.Rep >= 10 end, 12)
mark('power10', ('Power %d'):format(data.Rep))
waitMoment(6, 1.2)
step('04_first_goal', 'the first goal moment (or none)', 160)
-- train to the first gate's recommended Power (as the goal line would tell a kid)
local g1 = gateModel(1)
local need1 = (g1 and g1:GetAttribute('Required')) or (Balance.StagePower and Balance.StagePower[1]) or 10
local need2 = (gateModel(2) and gateModel(2):GetAttribute('Required')) or (Balance.StagePower and Balance.StagePower[2]) or 60
waitFor(function() return data.Rep >= math.max(need1, 15) end, 20)
local rate = (data.Rep - pR) / math.max(0.1, K - tR)
log(('BAY 1 earn rate %.1f Power/s (K); recommended Stage 1 %s, Stage 2 %s'):format(rate, tostring(need1), tostring(need2)))
mark('trained_for_stage1', ('Power %d'):format(data.Rep))
step('05_lane_trained', 'trained for Stage 1: what does the screen tell me to do next?', 160)

---------------------------------------------------------------------------------------------------------- 2. Stage 1
walkTo(mouth.X, mouth.Z)
walkTo(0, SP.Z - 6)
camFn = follow(0, -1)
walkTo(0, 22)
step('06_to_the_door', 'walking up the spine to the Stage 1 door', 330)
local cash0 = data.Cash
walkTo(0, 2)
log(gateReport(1))
walkTo(0, -6)
mark('stage1_entered', ('Cash %d -> %d'):format(cash0, data.Cash))
camFn = shoulder
wall(0.8)
step('07_stage1_enter', ('walked into Stage 1: Cash %d -> %d'):format(cash0, data.Cash), 140)
log(gateReport(2))
hum.MaxHealth = 100000; hum.Health = 100000 -- (pictures: a deep pool so the fight goes on while frames export; real damage is logged)
local dmg0 = sentKinds('Punch')
for k = 1, 6 do standMap(0, -6 - k * 1.5, 0); frame(0.1) end
wall(0.6)
step('08_goons', 'a few steps in: the crew', 140)
log(('goons in the world: %d'):format(#goons()))
hold(true)
local koSeen = false
local tFight = K
waitFor(function()
	keepPressing()
	for _, m in goons() do if m:FindFirstChild('GoonStars', true) or m:GetAttribute('KO') then koSeen = true end end
	if not koSeen then koSeen = sentKinds('Hit') > 0 and (lastTo('WaveState', 'Hit') or {}).HP == 0 end
	return koSeen
end, 12)
mark('first_ko', koSeen and '' or '(NO KO seen in 12 s)')
step('09_first_ko', 'holding the trigger: the first KO', 120)
waitFor(function() keepPressing(); return (P:GetAttribute('WaveLeft') or 1) == 0 end, 25)
hold(false)
mark('stage1_cleared', ('WaveLeft=%s, punches taken %d'):format(tostring(P:GetAttribute('WaveLeft')), sentKinds('Punch') - dmg0))
log(('fight: first KO %.1fs after entering, cleared %.1fs after entering'):format((MARK.first_ko or 0) - (MARK.stage1_entered or 0), (MARK.stage1_cleared or 0) - (MARK.stage1_entered or 0)))
frame(0.3)
step('10_clear', 'the last goon drops', 120)
hum.MaxHealth = 100; hum.Health = 100
wall(1.5)
step('11_after_clear', 'a moment after the clear: does the gate open, what next?', 140)
log(gateReport(2))

---------------------------------------------------------------------------------------------------------- 3. the pads before gate 2
local pads, zEnd = padsOf(1)
log(('pads in Stage 1 (gate 2 at z %.1f): %d'):format(zEnd, #pads))
for _, pd in pads do log('  pad ' .. padInfo(pd)) end
local padAt = {}
for _, pd in pads do
	local nm = pd.Name:lower()
	local c = pd.Color
	if nm:find('lobby') or nm:find('return') or nm:find('yellow') or (c.R > 0.8 and c.G > 0.7 and c.B < 0.4) then padAt.ret = padAt.ret or pd end
	if nm:find('furthest') or nm:find('10x') or nm:find('ten') or nm:find('pink') or nm:find('magenta') or (c.R > 0.8 and c.B > 0.6 and c.G < 0.6) then padAt.pass = padAt.pass or pd end
end
-- look at them from the stage (labels: do they fade/pop with distance?)
local here = mapPos()
walkTo(0, zEnd + 22)
camFn = follow(0, -1)
frame(0.3)
step('12_pads_far', 'the two pads ahead (far)', 140)
local function labelAlpha(pad)
	local a = {}
	for _, d in padParts(pad) do for _, l in d:GetDescendants() do if l:IsA('TextLabel') and l.Text ~= '' then table.insert(a, ('%.2f'):format(l.TextTransparency)) end end end
	return table.concat(a, ',')
end
local farA = {}
for k, pd in padAt do farA[k] = labelAlpha(pd) end
walkTo(0, zEnd + 12)
frame(0.5)
step('13_pads_near', 'the two pads (near)', 140)
for k, pd in padAt do log(('  label transparency %s pad: far %s -> near %s'):format(k, farA[k], labelAlpha(pd))) end
-- the gate past the pads: open after the clear?
local okPass, why = gatePass(2)
log(('gate 2 passable after clearing Stage 1: %s (%s)'):format(tostring(okPass), tostring(why)))
if okPass == false then issue('GATE: gate 2 stays shut after Stage 1\'s goons are cleared (' .. tostring(why) .. ')') end
standMap(0, zEnd + 10, 0); frame(0.3)
-- the magenta 10x pad first (no pass): should prompt the purchase (or say Coming soon) and NOT teleport
local function stepOn(pd, label)
	local q = frameCF:PointToObjectSpace(pd.CFrame.Position)
	local top = q.Y + pd.Size.Y / 2
	local before = { cash = data.Cash, prompts = #(_G.__prompts or {}), notices = #_G.__toClient }
	local _, moved = walkTo(q.X, q.Z + 6)
	if not moved then _, moved = walk(q.X, q.Z + 6, q.X, q.Z, top) end
	if not moved then standMap(q.X, q.Z, 0, top) end
	local tp = waitFor(function() return inLobby() end, 2.5)
	local how = 'stepped on'
	if not tp then
		local pr
		for _, d in padParts(pd) do pr = pr or d:FindFirstChildWhichIsA('ProximityPrompt', true) end
		if pr then
			issue(('PAD: %s needs a button press (ProximityPrompt "%s"); BRIEF23: stepping on it is enough'):format(label, pr.ActionText))
			press(pr); how = 'pressed its prompt'
			tp = waitFor(function() return inLobby() end, 2)
		end
	end
	local msgs = {}
	for i = before.notices + 1, #_G.__toClient do
		local m = _G.__toClient[i]
		if m[1] == 'Notice' then table.insert(msgs, tostring(m[2])) end
		if m[1] == 'Cinematic' and type(m[2]) == 'table' then table.insert(msgs, 'Cinematic ' .. tostring(m[2].Kind) .. ' ' .. tostring(m[2].Reward or '')) end
	end
	local prompts = {}
	for i = before.prompts + 1, #(_G.__prompts or {}) do table.insert(prompts, _G.__prompts[i][1] .. ' ' .. tostring(_G.__prompts[i][2])) end
	log(('%s pad (%s): teleported=%s Cash %d -> %d | purchase prompts: %s | messages: %s'):format(label, how, tostring(tp), before.cash, data.Cash,
		#prompts > 0 and table.concat(prompts, ', ') or 'none', #msgs > 0 and table.concat(msgs, ' ; ') or 'none'))
	return tp, data.Cash - before.cash
end
if padAt.pass then
	camFn = follow(0, -1)
	local tp, gain = stepOn(padAt.pass, '10x (magenta, no pass)')
	step('14_pass_pad', 'on the 10x pad without the pass', 140)
	if tp then issue('PAD: the 10x pad teleported a player who does not own the pass') end
	if tp then walkTo(0, 2); walkTo(0, zEnd + 10) end
else
	issue('PAD: no magenta 10x pad found in Stage 1')
end
local cashBeforeRet = data.Cash
local runBefore = attrs({ 'RunStage', 'RunCleared' })
if padAt.ret then
	if not inLobby() then
		local tp, gain = stepOn(padAt.ret, 'Return (yellow)')
		if tp then mark('back_in_lobby', ('via the yellow pad, +%d Cash'):format(gain)) else
			issue('PAD: the yellow Return pad did not take the player to the lobby (walked back)')
			walkTo(0, 2); walkTo(0, 30); mark('back_in_lobby', 'on foot')
		end
	end
else
	issue('PAD: no yellow Return pad found in Stage 1')
end
camFn = follow(0, -1)
wall(1.0)
step('15_back_in_lobby', ('back in the lobby: Cash %d -> %d; run before %s'):format(cashBeforeRet, data.Cash, runBefore), 300)
log('run after the return: ' .. attrs({ 'RunStage', 'RunCleared', 'StagesCleared', 'WaveCleared' }))

---------------------------------------------------------------------------------------------------------- 4a. HOOK's welcome gift (if any)
do
	local at = P:GetAttribute('OnboardingGiftAt')
	log('onboarding: step=' .. tostring(P:GetAttribute('OnboardingStep')) .. ' quiet=' .. tostring(P:GetAttribute('OnboardingQuiet')) .. ' giftAt=' .. tostring(at))
	if typeof(at) == 'Vector3' then
		local q = frameCF:PointToObjectSpace(at)
		walkTo(q.X, q.Z + 4)
		walkTo(q.X, q.Z)
		mark('gift_reached')
		wall(3.0)
		step('15b_gift', 'walked into the welcome gift', 140)
		wall(2.0)
	end
end

---------------------------------------------------------------------------------------------------------- 4b. the first gun
do
	local Guns = require(RS.Shared.Config.Guns)
	local nextGun = Guns.List[2]
	local gp = nextGun and workspace.TheBlockV2:FindFirstChild('GunPoint_' .. nextGun.Id, true)
	if gp then
		pcall(function() gp.Position = gp.CFrame.Position end)
		local gq = frameCF:PointToObjectSpace(gp.CFrame.Position)
		local price = nextGun.Price or nextGun.Cost or 0
		walkTo(gq.X - 7, gq.Z)
		standMap(gq.X, gq.Z, yawOf(1, 0), floorOf(gp))
		camFn = follow(1, 0)
		wall(0.5)
		mark('at_first_gun', ('Cash %d, %s costs %s'):format(data.Cash, nextGun.Name, tostring(price)))
		step('16a_armory', ('on the %s pad with %d Cash (price %s)'):format(nextGun.Name, data.Cash, tostring(price)), 140)
		local pr = gp:FindFirstChildWhichIsA('ProximityPrompt', true)
		local c0 = data.Cash
		if data.Cash >= price then
			if pr then press(pr) else issue('ARMORY: no prompt on the ' .. nextGun.Name .. ' pad') end
			wall(0.8)
			log(('bought %s: Cash %d -> %d, EquippedGun=%s; gun %s'):format(nextGun.Name, c0, data.Cash, tostring(P:GetAttribute('EquippedGun')), toolWhere()))
			mark('first_gun')
			waitMoment(5, 1.0)
			step('16b_gun_bought', 'bought the next gun', 140)
		else
			issue(('ARMORY: back in the lobby with %d Cash, the next gun (%s) costs %d'):format(data.Cash, nextGun.Name, price))
		end
	else
		issue('ARMORY: no GunPoint for the second gun')
	end
end

---------------------------------------------------------------------------------------------------------- 5. a shoe box
local Shoes = require(RS.Shared.Config.Shoes)
local boxes = {}
for _, d in workspace.TheBlockV2:GetDescendants() do if d:IsA('BasePart') and d.Name:match('^BoxPoint_') then table.insert(boxes, d) end end
local function boxPrice(id)
	for _, list in { Shoes.Boxes or {}, Shoes.BoxList or {} } do
		for k, b in list do
			if type(b) == 'table' and (b.Id == id or k == id) then return b.Price or b.Cost, b.Currency or (b.Robux and 'Robux') or 'Cash', b end
		end
	end
	return nil
end
table.sort(boxes, function(a, b) return (boxPrice(a.Name:sub(10)) or 1e18) < (boxPrice(b.Name:sub(10)) or 1e18) end)
for _, bp in boxes do
	local id = bp.Name:sub(10)
	local price, cur = boxPrice(id)
	local m = bp.Parent
	local sz = '?'
	pcall(function()
		local cf, size = m:GetBoundingBox()
		local base = floorOf(bp)
		sz = ('model %s %.1f x %.1f x %.1f (top %.1f over its point\'s floor)'):format(m.Name, size.X, size.Y, size.Z, frameCF:PointToObjectSpace(cf.Position).Y + size.Y / 2 - base)
	end)
	log(('box %s price %s %s | %s | labels: %s'):format(id, tostring(price), tostring(cur), sz, billboardTexts(m):sub(1, 200)))
end
local cheap
for _, bp in boxes do local pr, cur = boxPrice(bp.Name:sub(10)); if cur ~= 'Robux' then cheap = bp; break end end
cheap = cheap or boxes[1]
if cheap then
	local bq = frameCF:PointToObjectSpace(cheap.CFrame.Position)
	local blook = frameCF:VectorToObjectSpace(cheap.CFrame.LookVector)
	local price = boxPrice(cheap.Name:sub(10)) or 0
	walkTo(bq.X, bq.Z - 8)
	standMap(bq.X, bq.Z - 4, yawOf(0, 1), 0)
	camFn = follow(0, 1)
	wall(0.6)
	mark('at_first_box', ('Cash %d, box price %s'):format(data.Cash, tostring(price)))
	step('16_box', ('at the %s box with %d Cash (price %s)'):format(cheap.Name:sub(10), data.Cash, tostring(price)), 140)
	if data.Cash < price then
		local need = price - data.Cash
		issue(('BOX: a new player reaches the first box with %d Cash, the cheapest box costs %d (FF: +%d Cash)'):format(data.Cash, price, need))
		ev('FF', 'fast-forward +' .. need .. ' Cash'); data.Cash += need; P:SetAttribute('Cash', data.Cash)
	end
	local prompt = cheap:FindFirstChildWhichIsA('ProximityPrompt', true) or (cheap.Parent and cheap.Parent:FindFirstChildWhichIsA('ProximityPrompt', true))
	standMap(bq.X, bq.Z, yawOf(-blook.X, -blook.Z), floorOf(cheap))
	frame(0.2)
	local c0 = data.Cash
	if prompt then press(prompt) else issue('BOX: no prompt on the cheapest box') end
	frame(0.3)
	local opened = lastTo('ShoeOpened') or lastTo('BoxOpened')
	log(('opened %s: %s | Cash %d -> %d'):format(cheap.Name:sub(10), opened and (tostring(opened.Shoe or opened.Id) .. ' ' .. tostring(opened.Rarity)) or 'nothing sent', c0, data.Cash))
	mark('first_box_opened')
	wall(2.3)
	step('17_unboxing', 'the unboxing moment', 120)
	waitMoment(8, 1.2)
	step('18_after_box', 'after the unboxing', 140)
end

---------------------------------------------------------------------------------------------------------- 4. the run resets?
-- (servers that keep cleared waves down for RespawnDelay: put it back to the game's own value for this check)
pcall(function() WaveRules.RespawnDelay = 0 end)
standMap(0, 8, 0); frame(0.2)
walkTo(0, -6)
wall(1.2)
local back = #goons()
local left = P:GetAttribute('WaveLeft')
log(('Stage 1 again after the lobby: goons %d, WaveLeft=%s; %s'):format(back, tostring(left), gateReport(2)))
local okPass2, why2 = gatePass(2)
log(('gate 2 passable on the new run before fighting: %s (%s)'):format(tostring(okPass2), tostring(why2)))
if okPass2 then issue('RUN: gate 2 is still open on a new run (BRIEF23: going back to the lobby ends the run)') end
if (left or 0) == 0 and back == 0 then issue('RUN: Stage 1\'s goons did not come back after the lobby trip') end
pcall(function() WaveRules.RespawnDelay = 600 end)
-- back to the lobby (World window trip or walking back)
walkTo(0, 2); walkTo(0, 30)
wall(0.8)

---------------------------------------------------------------------------------------------------------- 6. rebirth (FF)
standMap(SP.X, SP.Z, 0)
camFn = follow(0, -1)
local needR = RebirthRules.need(0)
log(('FF: Power %d -> %d (rebirth 1 needs %d); at BAY 1\'s rate that is %.0f s of shooting'):format(data.Rep, needR + 5, needR, (needR - data.Rep) / math.max(rate, 0.01)))
ev('FF', 'fast-forward Power to the rebirth')
data.Rep = needR + 5
P:SetAttribute('Power', data.Rep)
wall(1.2)
step('19_rebirth_ready', 'FF to rebirth Power', 220)
local hud = P.PlayerGui:FindFirstChild('HoodHUD')
local rb = hud and (hud:FindFirstChild('Rebirth', true))
local hit = rb and (rb:FindFirstChild('Hit', true) or (rb:IsA('GuiButton') and rb))
if hit then __fireOn(hit, 'Activated'); sync(); frame(0.6) else issue('REBIRTH: no Rebirth button found on the HUD') end
step('20_rebirth_window', 'the Rebirth window', 120)
local r0 = data.Rebirths
for _ = 1, 3 do
	if data.Rebirths > r0 then break end
	local panels = P.PlayerGui:FindFirstChild('HoodPanels')
	local overlay = panels and panels:FindFirstChild('RebirthOverlay', true)
	local action = overlay and overlay:FindFirstChild('Action', true)
	local actionHit = action and (action:FindFirstChild('Hit', true) or (action:IsA('GuiButton') and action))
	if not actionHit then break end
	__fireOn(actionHit, 'Activated'); sync(); frame(0.4)
end
wall(1.0)
mark('rebirthed', ('Rebirths %d -> %d, Power %d'):format(r0, data.Rebirths, data.Rep))
step('21_rebirth_moment', ('rebirthed: Rebirths=%d Power=%d'):format(data.Rebirths, data.Rep), 220)
log('gun after the rebirth: ' .. toolWhere())
wall(2.5)
step('22_after_rebirth', 'after the rebirth: what next?', 220)

---------------------------------------------------------------------------------------------------------- 7. a Robux lane (ECON / LOBBY5)
do
	local vip
	for _, st in Skins.Stations do if st.Pass then vip = st; break end end
	local z = vip and zoneOf(vip.Id)
	if z then
		local q = frameCF:PointToObjectSpace(z.CFrame.Position)
		local dir = laneDir(z)
		local pr0, n0, rep0 = #(_G.__prompts or {}), #_G.__toClient, data.Rep
		walkTo(q.X - dir.X * 9, q.Z - dir.Z * 9)
		standMap(q.X, q.Z, yawOf(dir.X, dir.Z), floorOf(z))
		camFn = follow(dir.X, dir.Z)
		wall(2.5)
		local msgs, prompts = {}, {}
		for i = n0 + 1, #_G.__toClient do if _G.__toClient[i][1] == 'Notice' then table.insert(msgs, tostring(_G.__toClient[i][2])) end end
		for i = pr0 + 1, #(_G.__prompts or {}) do table.insert(prompts, _G.__prompts[i][1] .. ' ' .. tostring(_G.__prompts[i][2])) end
		log(('%s (%s, x%s, %s Robux) without the pass: TrainingStation=%s TrainingPass=%s, Power %d -> %d, prompts: %s, notices: %s, hint: %s'):format(vip.Name, vip.Id, tostring(vip.Multiplier), tostring(vip.RobuxPrice),
			tostring(P:GetAttribute('TrainingStation')), tostring(P:GetAttribute('TrainingPass')), rep0, data.Rep, #prompts > 0 and table.concat(prompts, ', ') or 'none', #msgs > 0 and table.concat(msgs, ' ; ') or 'none', screen()))
		step('23_robux_lane', vip.Name .. ' without its pass', 160)
		if data.Rep > rep0 then issue('ROBUX LANE: ' .. vip.Name .. ' paid Power without its pass') end
		-- now the pass arrives (StoreService sets Pass_<Key>)
		_G.__owned = _G.__owned or {}
		P:SetAttribute('Pass_' .. vip.Pass, true)
		ev('FF', 'pass ' .. vip.Pass .. ' granted')
		wall(1.0)
		local r1, t1 = data.Rep, os.clock()
		wall(3.0)
		local rate1 = (data.Rep - r1) / (os.clock() - t1)
		log(('%s with the pass: %.0f Power/s (BAY 1 was %.1f/s at rebirth 0; now %d rebirths) TrainingStation=%s'):format(vip.Name, rate1, rate, data.Rebirths, tostring(P:GetAttribute('TrainingStation'))))
		step('24_robux_lane_owned', vip.Name .. ' with its pass', 160)
	else
		issue('ROBUX LANE: no lane with a Pass found')
	end
end

---------------------------------------------------------------------------------------------------------- the first 30 seconds
local function firstOf(pred, after)
	for _, e in EV do if e.t >= (after or 0) and pred(e) then return e end end
	return nil
end
local function fmt(e) return e and ('%5.1fs  %s'):format(e.t, e.text) or '  ---   never' end
local SC = {}
local function sc(label, e, limit)
	local verdict = e and (e.t <= limit and 'ok' or 'LATE') or 'MISSING'
	table.insert(SC, ('%-34s %-60s [%s, kid limit %ds]'):format(label, fmt(e):sub(1, 60), verdict, limit))
end
local resp = firstOf(function(e) return (e.kind == 'input' and e.text:find('sends')) or e.kind == 'sound' or e.kind == 'power' or e.kind == 'gun' and e.text ~= 'in hand: none' end, CLICK_AT)
if resp and resp.t > CLICK_AT + 1.5 then resp = { t = resp.t, text = 'the click did nothing; first reaction later: ' .. resp.text } end
sc('1. first response to input (click)', resp, 1)
sc('2. first reward (Cash / GOAL DONE)', firstOf(function(e) return (e.kind == 'cash' and e.text:find('%(%+')) or (e.kind == 'text' and e.text:upper():find('GOAL DONE')) end), 10)
sc('3. first big number going up', firstOf(function(e) return e.kind == 'power' end), 5)
sc('4. first upgrade (gun / shoes / rebirth)', firstOf(function(e) return e.t > 1 and ((e.kind == 'attr' and (e.text:find('^EquippedGun') or e.text:find('^Rebirths'))) or (e.kind == 'text' and (e.text:find('EQUIPPED') or e.text:find('%% Power')))) end), 30)
sc('5. first goon in sight', firstOf(function(e) return e.kind == 'goon' end), 20)
sc('6. first gate walked through', firstOf(function(e) return e.kind == 'gate' end), 20)
sc('7. first Cash pad', firstOf(function(e) return (e.kind == 'server' and e.text:find('CashOut')) end), 30)
local gaps = {}
local prev = 0
local function interesting(e) return e.kind ~= 'attr' or not e.text:find('^WaveStage') end
for _, e in EV do
	if interesting(e) then
		if e.kind == 'FF' then prev = e.t end
		if e.t - prev > 5 and e.kind ~= 'FF' then table.insert(gaps, ('%5.1fs -> %5.1fs  (%.1f s with nothing new; next: %s)'):format(prev, e.t, e.t - prev, e.text:sub(1, 60))) end
		prev = e.t
	end
end
if K - prev > 5 then table.insert(gaps, ('%5.1fs -> end (%.1f s)'):format(prev, K - prev)) end
log('FIRST 30 SECONDS (K = kid seconds from the spawn; a fresh save):')
for _, l in SC do log('  ' .. l) end
log('  events in the first 30 s: ' .. (function() local n = 0; for _, e in EV do if e.t <= 30 then n += 1 end end; return n end)() .. ', +N popups/counter changes seen ' .. trk.popups)
log('DEAD TIME (gaps > 5 s with nothing new; walking counts as nothing new):')
for _, g in gaps do log('  ' .. g) end
log('EVENTS (first 90 s):')
for _, e in EV do if e.t <= 90 then log(('  %5.1f %-8s %s'):format(e.t, e.kind, e.text)) end end
if EXPORT or REPORT_DIR then __fs.writeFile((EXPORT or REPORT_DIR) .. '/events.json', __serde.encode('json', EV)) end

---------------------------------------------------------------------------------------------------------- report
local sounds = 0
for _, d in game:GetDescendants() do if d:IsA('Sound') then sounds += 1 end end
log(('walked %.0f studs in all (%.0f s at WalkSpeed %d)'):format(WALKED, WALKED / walkSpeed(), walkSpeed()))
log('TIMELINE (K, kid seconds): ' .. (function()
	local t = {}
	for _, k in { 'in_bay1', 'first_power', 'power10', 'trained_for_stage1', 'stage1_entered', 'first_ko', 'stage1_cleared', 'back_in_lobby', 'at_first_gun', 'first_gun', 'at_first_box', 'first_box_opened', 'rebirthed' } do
		if MARK[k] then table.insert(t, ('%s %.1f'):format(k, MARK[k])) end
	end
	return table.concat(t, ' | ')
end)())
log('script failures: ' .. (#FAILED > 0 and table.concat(FAILED, ' ;; ') or 'none'))
log('ISSUES: ' .. #ISSUES)
for i, s in ISSUES do log(('  %d. %s'):format(i, s)) end
log('final state: ' .. state())
if EXPORT then __fs.writeFile(EXPORT .. '/manifest.json', __serde.encode('json', SHOTS)) end
__fs.writeFile((EXPORT or REPORT_DIR) .. '/feel_report.txt', table.concat(REP, '\n') .. '\n')
return { lines = #REP, shots = #SHOTS, issues = #ISSUES }
