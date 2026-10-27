-- live_shoes.luau (SHOES2, brief 24; run with HOOK's tools/harness.luau on a src copy that has TheBlockV2 assembled):
-- the REAL ShoeService (server) and Shoes.client (client) in one DataModel with a stub DataService, on a blocky R15
-- character. Checks: equipping the best pairs wears the top one on the feet with its rarity effects and makes the
-- other two follow with theirs; the followers move with the player (render step); a box opened through its real
-- prompt plays the reveal; a re-equip swaps the worn pair and its effects cleanly.
local RS = game.ReplicatedStorage
local Players = game:GetService('Players')
local Schema = require(game.ServerScriptService.HoodServer.ProfileSchema)
local Shoes = require(RS.Shared.Config.Shoes)
local FX = require(RS.Shared.ShoeFX)
local V2 = require(game.ServerStorage.TheBlockV2)
V2.Build()
local net = RS:FindFirstChild('HoodNet') or Instance.new('Folder'); net.Name = 'HoodNet'; net.Parent = RS
for _, n in { 'OpenShoeBox', 'ShoeAction', 'ShoeOpened', 'UnboxDone', 'Notice', 'ProfileUpdated', 'Goal', 'Cinematic', 'WaveState', 'WaveShot', 'Shoot', 'EquipSkin', 'BuyGun', 'EquipGun', 'Rebirth', 'SetSettings' } do
	if not net:FindFirstChild(n) then local e = Instance.new('RemoteEvent'); e.Name = n; e.Parent = net end
end
if not net:FindFirstChild('RequestSnapshot') then local rf = Instance.new('RemoteFunction'); rf.Name = 'RequestSnapshot'; rf.Parent = net end
RS:SetAttribute('FoundationReady', true)
if not workspace.CurrentCamera then local cam = Instance.new('Camera'); cam.Name = 'Camera'; cam.FieldOfView = 70; cam.Parent = workspace; workspace.CurrentCamera = cam end

local P = Players.LocalPlayer
if not P then P = Instance.new('Player'); P.Name = 'Tester'; P.Parent = Players; pcall(function() Players.LocalPlayer = P end) end
for _, c in { 'PlayerGui', 'Backpack' } do if not P:FindFirstChild(c) then local x = Instance.new(c); x.Parent = P end end
P.UserId = 4242

-- a blocky R15 body (named parts, feet on the ground at the hall's spawn)
local V = Vector3.new
local char = Instance.new('Model'); char.Name = 'Tester'
local base = CFrame.new(0, 0, 55)
local rows = { { 'HumanoidRootPart', V(2, 2, 1), V(0, 3, 0) }, { 'LowerTorso', V(2, 0.4, 1), V(0, 2.2, 0) }, { 'UpperTorso', V(2, 1.6, 1), V(0, 3.2, 0) },
	{ 'Head', V(1.2, 1.2, 1.2), V(0, 4.6, 0) },
	{ 'LeftUpperLeg', V(1, 1.217, 1), V(-0.5, 1.3915, 0) }, { 'LeftLowerLeg', V(1, 1.193, 1), V(-0.5, 0.8965, 0) }, { 'LeftFoot', V(1, 0.3, 1), V(-0.5, 0.15, 0) },
	{ 'RightUpperLeg', V(1, 1.217, 1), V(0.5, 1.3915, 0) }, { 'RightLowerLeg', V(1, 1.193, 1), V(0.5, 0.8965, 0) }, { 'RightFoot', V(1, 0.3, 1), V(0.5, 0.15, 0) } }
local root
for _, r in rows do
	local p = Instance.new('Part'); p.Name = r[1]; p.Size = r[2]; p.CFrame = base * CFrame.new(r[3]); p.Anchored = true; p.Parent = char
	if r[1] == 'HumanoidRootPart' then root = p; p.Transparency = 1 end
end
local hum = Instance.new('Humanoid'); hum.Health = 100; hum.MaxHealth = 100; hum.Parent = char
pcall(function() hum.RigType = Enum.HumanoidRigType.R15 end)
char.PrimaryPart = root; char.Parent = workspace
P.Character = char
local function moveBy(off)
	for _, p in char:GetChildren() do if p:IsA('BasePart') then p.CFrame = CFrame.new(off) * p.CFrame end end
end

local function deep(t) if type(t) ~= 'table' then return t end local c = {} for k, v in t do c[k] = deep(v) end return c end
local data = Schema.new()
data.Cash = 5000
data.Shoes.Owned = { FreshCanvas = 1, ChromeKicks = 1, StreetAngel = 1, BlockRoyalty = 1, RedRocket = 1 }
local prof = { Data = data, Active = true }
prof.OnAfterSave = { Connect = function() return { Disconnect = function() end } end }
function prof:Save() self.LastSavedData = deep(self.Data) end
function prof:IsActive() return true end
_G.__profile = prof
local fake = Instance.new('Folder'); fake.Name = 'FakeServer'; fake.Parent = game.ServerScriptService
local stub = Instance.new('ModuleScript'); stub.Name = 'DataService'; stub.Parent = fake
stub.Source = "return { get = function(player) return _G.__profile end, push = function() end }"
for _, name in { 'RateLimiter', 'ShoeOpening' } do
	local m = Instance.new('ModuleScript'); m.Name = name; m.Source = game.ServerScriptService.HoodServer[name].Source; m.Parent = fake
end
local function run(src, name, parent)
	local m = Instance.new('ModuleScript'); m.Name = name; m.Source = src.Source; m.Parent = parent
	task.spawn(function()
		local ok, err = pcall(require, m)
		if not ok then print('[live] ' .. name .. ' failed: ' .. tostring(err)) end
	end)
end
P:SetAttribute('Cash', data.Cash)
P:SetAttribute('ProfileReady', true)
local HS = game.ServerScriptService.HoodServer
run(HS.ShoeService, 'ShoeService', fake)
local HC = game.StarterPlayer.StarterPlayerScripts.HoodClient
run(HC.Shoes, 'ShoesCUT', HC)

local REP = {}
local function log(s) table.insert(REP, s); print('[live] ' .. s) end
local function frame(dt)
	local steps = math.max(1, math.floor(dt / (1 / 30)))
	for _ = 1, steps do
		__fireOn(game:GetService('RunService'), 'PreRender', 1 / 30)
		for _, fn in table.clone(_G.__bound) do pcall(fn, 1 / 30) end
		__fireOn(game:GetService('RunService'), 'Heartbeat', 1 / 30)
		__stepTweens(1 / 30)
		task.wait(1 / 30)
	end
end
local function fire()
	for _, a in { 'ShoeWorn', 'ShoesEquipped', 'ShoesOwned' } do __fireOn(P, 'Attr_' .. a) end
end
local function count(container, class)
	local n = 0
	if container then for _, d in container:GetDescendants() do if d:IsA(class) then n += 1 end end end
	return n
end
local function holders(container)
	local n = 0
	if container then for _, d in container:GetDescendants() do if d:IsA('BasePart') and d.Name == 'ShoeFX' and d.Transparency >= 1 then n += 1 end end end
	return n
end
frame(0.5)

-- 1. Equip best: the Secret pair is worn, the next two follow.
RS.HoodNet.ShoeAction:FireServer('EquipBest')
frame(0.2); fire(); frame(0.5)
local worn = char:FindFirstChild('HoodShoes')
log(('equip best: ShoeWorn=%s ShoesEquipped=%s'):format(tostring(P:GetAttribute('ShoeWorn')), tostring(P:GetAttribute('ShoesEquipped'))))
log(('worn pair on the feet: %s (%s), parts=%d, ShoeFX holders=%d, emitters=%d, trails=%d, lights=%d, live particles=%.1f'):format(
	tostring(worn and worn:GetAttribute('ShoeId')), worn and Shoes.ById[worn:GetAttribute('ShoeId')].Rarity or '-', worn and (count(worn, 'BasePart') - holders(worn)) or 0,
	holders(worn), count(worn, 'ParticleEmitter'), count(worn, 'Trail'), count(worn, 'PointLight'), worn and FX.live(worn) or 0))
local welded = 0
if worn then for _, d in worn:GetDescendants() do if d:IsA('BasePart') and (d:FindFirstChildOfClass('Weld') or d:FindFirstChildOfClass('WeldConstraint')) then welded += 1 end end end
log('  every worn part welded to the body: ' .. tostring(worn ~= nil and welded == count(worn, 'BasePart')))
local folder = workspace:FindFirstChild('HoodShoeFollowers')
local fol = folder and folder:GetChildren() or {}
for _, m in fol do
	log(('follower %s: %s (%s), ShoeFX holders=%d, emitters=%d, trails=%d, lights=%d, live particles=%.1f'):format(m.Name, tostring(m:GetAttribute('ShoeId')),
		Shoes.ById[m:GetAttribute('ShoeId')] and Shoes.ById[m:GetAttribute('ShoeId')].Rarity or '?', holders(m), count(m, 'ParticleEmitter'), count(m, 'Trail'), count(m, 'PointLight'), FX.live(m)))
end
-- 2. The followers follow: walk 12 studs and step frames.
local before = {}
for i, m in fol do before[i] = m.PrimaryPart and m.PrimaryPart.CFrame.Position end
for _ = 1, 12 do moveBy(V(0, 0, -1)); frame(1 / 15) end
frame(0.6)
for i, m in fol do
	local p = m.PrimaryPart and m.PrimaryPart.CFrame.Position
	log(('  follower %d moved %.1f studs; now %.1f studs behind the player'):format(i, before[i] and p and (p - before[i]).Magnitude or -1, p and (p - root.CFrame.Position).Magnitude or -1))
	local fxPart
	for _, d in m:GetDescendants() do if d.Name == 'ShoeFX' and d:IsA('BasePart') then fxPart = d end end
	local w = fxPart and fxPart:FindFirstChildOfClass('Weld')
	log(('  its ShoeFX is welded to the follower root (moves with it in the engine): %s'):format(tostring(w ~= nil and w.Part0 == m.PrimaryPart and not fxPart.Anchored)))
end
-- 3. A box through its real prompt: the reveal plays.
local point = workspace:FindFirstChild('BoxPoint_Street', true)
if point then
	local p = point.CFrame.Position
	local off = (p + point.CFrame.LookVector * Vector3.new(3, 0, 3)) - root.CFrame.Position
	moveBy(V(off.X, 0, off.Z)); frame(0.6)
	local pr = point:FindFirstChild('ShoePrompt', true)
	local n0 = #_G.__toClient
	do
		local c = workspace.CurrentCamera
		log('  REVEAL before: camera=' .. (c and (c.CameraType.Name .. ' fov ' .. string.format('%.1f', c.FieldOfView)) or 'none') .. ' camera children=' .. tostring(c and #c:GetChildren() or 0) .. ' ClockTime=' .. tostring(game.Lighting.ClockTime))
	end
	if pr then __fireOn(pr, 'Triggered', P) else RS.HoodNet.OpenShoeBox:FireServer('Street') end
	frame(0.4)
	local opened
	for i = n0 + 1, #_G.__toClient do if _G.__toClient[i][1] == 'ShoeOpened' then opened = _G.__toClient[i][2] end end
	log(('box opened via %s: %s (%s); Unboxing flag=%s; reveal UI=%s'):format(pr and 'its prompt' or 'the remote', tostring(opened and opened.Shoe), tostring(opened and opened.Rarity),
		tostring(P.PlayerGui:GetAttribute('Unboxing')), tostring(P.PlayerGui:FindFirstChild('HoodUnboxing') ~= nil or (workspace.CurrentCamera and workspace.CurrentCamera:FindFirstChild('HoodUnboxing') ~= nil))))
	local cam = workspace.CurrentCamera
	local function camState() return cam and (cam.CameraType.Name .. ' fov ' .. string.format('%.1f', cam.FieldOfView)) or 'no camera' end
	log('  REVEAL during: stage=' .. tostring(workspace:FindFirstChild('HoodUnboxStage') ~= nil) .. ' camera=' .. camState()
		.. ' words=' .. tostring(P.PlayerGui.HoodUnboxing:FindFirstChild('Unboxed', true) ~= nil) .. ' ClockTime=' .. tostring(game.Lighting.ClockTime))
	-- (Oct 27: the HUD goes off for the cinematic once it has slid aside, CinematicHide; the harness fires attribute
	-- signals only when asked)
	local function hudOn() local h = P.PlayerGui:FindFirstChild('HoodHUD'); return h and tostring(h.Enabled) or 'no HUD in this run' end
	__fireOn(P.PlayerGui, 'Attr_UnboxingCalm'); frame(0.3)
	log('  HUD during the reveal: calm=' .. tostring(P.PlayerGui:GetAttribute('UnboxingCalm')) .. ' HoodHUD on=' .. tostring(hudOn()))
	local beforeFx = cam and #cam:GetChildren() or 0
	frame(12)
	__fireOn(P.PlayerGui, 'Attr_UnboxingCalm'); __fireOn(P.PlayerGui, 'Attr_Unboxing'); frame(0.3)
	log('  HUD after the reveal: calm=' .. tostring(P.PlayerGui:GetAttribute('UnboxingCalm')) .. ' HoodHUD on=' .. tostring(hudOn())) -- (28c: the opening in the world holds until a tap, auto-closing by 9.4 s)
	log('  reveal finished: Unboxing=' .. tostring(P.PlayerGui:GetAttribute('Unboxing')))
	log('  REVEAL after: stage=' .. tostring(workspace:FindFirstChild('HoodUnboxStage') ~= nil) .. ' camera=' .. camState() .. ' camera effects left=' .. tostring(cam and #cam:GetChildren() or 0)
		.. ' words left=' .. tostring(P.PlayerGui.HoodUnboxing:FindFirstChild('Unboxed', true) ~= nil) .. ' ClockTime=' .. tostring(game.Lighting.ClockTime))
else
	log('no BoxPoint_Street on this map')
end
-- 4. Re-equip: take the Secret pair off; the Mythic one is worn now, with its own effects; nothing left over.
RS.HoodNet.ShoeAction:FireServer('Unequip', 'BlockRoyalty')
frame(0.2); fire(); frame(0.5)
local shoes = {}
for _, c in char:GetChildren() do if c.Name == 'HoodShoes' then table.insert(shoes, c) end end
worn = shoes[1]
log(('unequip the Secret: ShoeWorn=%s; HoodShoes models=%d; worn %s, ShoeFX holders=%d, emitters=%d, halos=%d'):format(tostring(P:GetAttribute('ShoeWorn')), #shoes,
	tostring(worn and worn:GetAttribute('ShoeId')), holders(worn), count(worn, 'ParticleEmitter'), worn and #(function() local t = {} for _, d in worn:GetDescendants() do if d.Name == 'Halo' and d:IsA('ParticleEmitter') then table.insert(t, d) end end return t end)() or 0))
fol = folder and folder:GetChildren() or {}
log('followers now: ' .. #fol)
return REP
