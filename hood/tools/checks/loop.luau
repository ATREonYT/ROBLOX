---------------------------------------------------------------------------------------------------------- LOOP: the core loop
-- (Oct 27, release: "make the core loop done well") Appended to feel_base.luau's set-up (everything above its "0. spawn"
-- line: the real servers and clients on a fresh save), like first30. A fresh player plays the loop the owner names:
-- train in a lane (every shot +Power with its feedback) -> Power opens the gates -> stages pay Cash -> buy the next gun ->
-- rebirth (Power to 0, the multiplier up) -> again, and at every point the goal line must say a next step that is
-- possible. Long stretches are fast-forwarded (FF) by writing the save, as feel_base does. Checks print
--   [loop] CHECK ok|FAIL <name> (<detail>)   and at the end   [loop] N checks / M failed
-- Run: run_checks.sh (core_loop), the same way as first30: head of feel_base.luau up to "0. spawn", then this file.
local GoalRules = require(RS.Shared.GoalRules)
local GunsCfg = require(RS.Shared.Config.Guns)
local BigAttr = require(RS.Shared.BigAttr)
local Juice = require(RS.Shared.Juice)
local FightFX = require(RS.Shared.FightFX)
local LOOPN, LOOPF = 0, {}
local function check(name, ok, detail)
	LOOPN += 1
	if not ok then table.insert(LOOPF, name) end
	print(('[loop] CHECK %s %s%s'):format(ok and 'ok  ' or 'FAIL', name, detail and (' (' .. tostring(detail) .. ')') or ''))
end
-- What the player sees of each shot: the client's effects (counted where they are made)
local fx = { tracer = 0, gain = 0, gains = {}, flashes = {} }
local FRAMES = 0 -- (frames the clients have run: their clock, 30 a second)
do
	local fl = Juice.flash
	Juice.flash = function(model, ...)
		fx.flashes[model] = fx.flashes[model] or {}
		table.insert(fx.flashes[model], FRAMES)
		return fl(model, ...)
	end
	local t = Juice.tracer
	Juice.tracer = function(...) fx.tracer += 1; return t(...) end
	local g = FightFX.gain
	FightFX.gain = function(at, amount, opts)
		fx.gain += 1
		table.insert(fx.gains, opts and opts.text or tostring(amount))
		return g(at, amount, opts)
	end
end
local function hudText(name)
	local hud = P.PlayerGui:FindFirstChild('HoodHUD')
	local row = hud and hud:FindFirstChild(name, true)
	local v = row and (row:IsA('TextLabel') and row or row:FindFirstChild('Value'))
	return v and v:IsA('TextLabel') and v.Text or nil
end
-- every number the HUD and the goal line show: never NaN, inf, negative or a wrapped 32-bit number
local function badNumbers()
	local bad = {}
	for _, gname in { 'HoodHUD', 'HoodGoals' } do
		local g = P.PlayerGui:FindFirstChild(gname)
		for _, d in g and g:GetDescendants() or {} do
			if (d:IsA('TextLabel') or d:IsA('TextButton')) and d.Text ~= '' then
				local t = d.Text:gsub('<[^>]+>', '')
				local low = t:lower()
				if low:find('nan') or low:find('inf') or t:find('%-%d') or t:find('2147483') or t:find('4294967') then table.insert(bad, d.Name .. '="' .. t .. '"') end
			end
		end
	end
	for _, a in { 'Power', 'Cash', 'RebirthNeed', 'RebirthMultiplier', 'ShotBase', 'ShotMultiplier', 'GoalReward' } do
		local v = P:GetAttribute(a)
		if type(v) == 'number' and (v ~= v or v < 0 or math.abs(v) == math.huge) then table.insert(bad, a .. '=' .. tostring(v)) end
	end
	return bad
end
-- The goal line as the player reads it, and whether that step is possible right now.
local function goalLine()
	local g = P.PlayerGui:FindFirstChild('HoodGoals')
	local tr = g and g:FindFirstChild('Goal', true)
	local parts = {}
	if tr then for _, d in tr:GetDescendants() do if d:IsA('TextLabel') and d.Text ~= '' and visibleChain(d) then table.insert(parts, strip(d.Text)) end end end
	return table.concat(parts, ' | '), P:GetAttribute('GoalText'), P:GetAttribute('GoalStep')
end
local function goalDoable()
	local step = P:GetAttribute('GoalStep')
	local g = type(step) == 'number' and GoalRules.at(step)
	if not g then return true, 'all done: ' .. tostring(P:GetAttribute('GoalWhere')) end
	local n = data.Rebirths
	if g.Need.Range then
		local st = Skins.Stations[g.Need.Range]
		if st and (st.Rebirths or 0) > n then
			-- a lane goal for a lane still locked: the line must say how to open it (rebirth), not just "Train at"
			local text = tostring(P:GetAttribute('GoalText'))
			return text:lower():find('rebirth') ~= nil, ('%s needs %d rebirths, you have %d; line "%s"'):format(st.Name, st.Rebirths, n, text)
		end
	end
	return true, tostring(P:GetAttribute('GoalText'))
end
local function settle(t) wall(t or 1.2) end
local SPL = workspace.TheBlockV2:GetAttribute('LobbySpawn') or Vector3.new(0, 0, 55)
local function home() standMap(SPL.X, SPL.Z, 0); camFn = follow(0, -1); frame(0.2) end
-- stand in a lane's shooter's box (as feel_base's BAY 1 walk ends)
local function inLane(id)
	local z = zoneOf(id)
	if not z then return false end
	local zp = frameCF:PointToObjectSpace(z.CFrame.Position)
	local ld = laneDir(z)
	standMap(zp.X, zp.Z, yawOf(ld.X, ld.Z), floorOf(z))
	camFn = follow(ld.X, ld.Z)
	return true, zp, ld
end
local function outOfLane(zp, ld) standMap(zp.X - ld.X * 12, zp.Z - ld.Z * 12, 0, 0) end

---------------------------------------------------------------------------------------------------------- 1. a fresh spawn
standMap(SPL.X, SPL.Z, workspace.TheBlockV2:GetAttribute('LobbySpawnYaw') or 0)
pcall(function() __fireOn(P, 'CharacterAdded', char) end)
camFn = follow(0, -1)
K = 0; resetClock()
-- (Oct 27, flow) a fresh save is greeted: the welcome is up, and any input ends it at once with the camera given back
do
local function hudOn() local h = P.PlayerGui:FindFirstChild('HoodHUD'); return h ~= nil and h.Enabled end
local hudDuring = 0
local welcomeUp = waitFor(function() if hudOn() then hudDuring += 1 end; return P.PlayerGui:FindFirstChild('HoodWelcome') ~= nil end, 4)
check('first join: the welcome is up', welcomeUp)
-- (Oct 27, flow r2) its camera glides inside the hall: no point of the glide inside a wall, a roof or a prop, and the kid
-- in plain sight from each (the harness has no raycast: points along each line are tested against the map's parts)
do
	local wg = P.PlayerGui:FindFirstChild('HoodWelcome')
	local A, B = wg and wg:GetAttribute('From'), wg and wg:GetAttribute('To')
	local kid = char.HumanoidRootPart.Position + Vector3.new(0, 2, 0)
	local blocked, where = 0, ''
	if typeof(A) == 'Vector3' and typeof(B) == 'Vector3' then
		local lo = Vector3.new(math.min(A.X, B.X, kid.X), math.min(A.Y, B.Y, kid.Y), math.min(A.Z, B.Z, kid.Z))
		local hi = Vector3.new(math.max(A.X, B.X, kid.X), math.max(A.Y, B.Y, kid.Y), math.max(A.Z, B.Z, kid.Z))
		local near = {}
		for _, b in workspace.TheBlockV2:GetDescendants() do
			if b:IsA('BasePart') and b.Transparency < 0.5 then
				local c, r = b.Position, b.Size.Magnitude / 2
				if c.X + r >= lo.X and c.X - r <= hi.X and c.Y + r >= lo.Y and c.Y - r <= hi.Y and c.Z + r >= lo.Z and c.Z - r <= hi.Z then table.insert(near, b) end
			end
		end
		local function inside(pt)
			for _, b in near do
				local l = b.CFrame:PointToObjectSpace(pt)
				local h = b.Size / 2
				if math.abs(l.X) < h.X and math.abs(l.Y) < h.Y and math.abs(l.Z) < h.Z then return b end
			end
			return nil
		end
		for i = 0, 16 do
			local eye = A:Lerp(B, i / 16)
			for j = 0, 11 do
				local pt = eye:Lerp(kid, j / 14) -- (to just short of the kid: the floor and the lane under it don't count)
				local b = inside(pt)
				if b then blocked += 1; if where == '' then where = ('%s at %d/16, %d/14 of the way'):format(b:GetFullName():sub(-60), i, j) end end
			end
		end
	end
	check('first join: the welcome glides inside the hall, the kid in sight all the way', typeof(A) == 'Vector3' and blocked == 0, ('from %s to %s, %d points in a part %s'):format(tostring(A), tostring(B), blocked, where))
end
frame(0.3)
if hudOn() then hudDuring += 1 end
-- (Oct 27, round 8) the welcome has the screen to itself: the HUD waits, then fades back in once it ends
check('first join: the HUD waits for the welcome', hudDuring == 0, hudDuring .. ' ticks on')
__fireOn(UIS, 'InputBegan', { UserInputType = Enum.UserInputType.Keyboard, KeyCode = Enum.KeyCode.W }, false)
local skipped, skipWall = waitFor(function() return P.PlayerGui:FindFirstChild('HoodWelcome') == nil end, 3)
check('first join: any input ends the welcome at once, camera given back', skipped and skipWall <= 1 and workspace.CurrentCamera.CameraType ~= Enum.CameraType.Scriptable, ('%.2f s wall, camera %s'):format(skipWall, tostring(workspace.CurrentCamera.CameraType)))
local back, backWall = waitFor(hudOn, 2)
check('first join: the HUD comes back after the welcome', back and backWall <= 1, ('%.2f s wall'):format(backWall))
end
-- (round 8) a calm first screen: the Shop, the counters and the Power bar; no Robux offer, no Shoes/Items/Skins/Rebirth
local function hudShown(part) return P.PlayerGui:GetAttribute('HudShown_' .. part) == true end
settle(1.5)
-- (Oct 27, flow: one voice) while the tutorial runs its hint says the step; the goal line waits
local function hintText()
	local hg = P.PlayerGui:FindFirstChild('HoodTutorialHint')
	local h = hg and hg:FindFirstChild('Hint', true)
	local tx = h and h.Visible and h:FindFirstChild('Text', true)
	return tx and strip(tx.Text) or ''
end
waitFor(function() return hintText() ~= '' end, 4)
local line0 = goalLine()
check('spawn: the tutorial says the step, the goal line waits', hintText() ~= '' and line0 == '', ('hint "%s", goal line "%s"'):format(hintText(), line0))
check('spawn: counters are clean numbers', #badNumbers() == 0, table.concat(badNumbers(), ', '))
do
	local on = {}
	for _, part in require(RS.Shared.HudReveal).All do if hudShown(part) then table.insert(on, part) end end
	check('spawn: a calm first screen (no Robux offer, no Shoes, Items, Skins or Rebirth yet)', #on == 0 and P.PlayerGui:GetAttribute('HudShown_Offers') == false, 'shown: ' .. table.concat(on, ','))
end

---------------------------------------------------------------------------------------------------------- 2. lane: every shot answers
local okL, zp, ld = inLane('Starter')
check('BAY 1 found', okL)
local t0, p0 = os.clock(), data.Rep
local stationAt = nil
waitFor(function() return P:GetAttribute('TrainingStation') == 'Starter' end, 2)
stationAt = os.clock() - t0
check('step on BAY 1: training within 1.5 s (the server looks every 0.25 s; harness wall time)', P:GetAttribute('TrainingStation') == 'Starter' and stationAt <= 1.5, ('%.2f s'):format(stationAt))
local tr0, g0 = fx.tracer, fx.gain
local ticks, hudTicks, lastP, lastHud = 0, 0, data.Rep, hudText('Power')
local firstShotAt
local tA = os.clock()
local simFrames = 0 -- (the clients run on frames of 1/30 s; the harness's frames take longer in wall time than that)
while os.clock() - tA < 5 do
	frame(1 / 30)
	simFrames += 1
	FRAMES += 1
	if data.Rep ~= lastP then ticks += 1; lastP = data.Rep; firstShotAt = firstShotAt or (os.clock() - tA) end
	local h = hudText('Power')
	if h ~= lastHud then hudTicks += 1; lastHud = h end
end
local secs = os.clock() - tA
local shots, gains = fx.tracer - tr0, fx.gain - g0
log(('BAY 1 for %.1f s: Power %d -> %d, %d server pays, %d shots shown, %d "+N" pops (%s), HUD Power changed %d times ("%s")'):format(secs, p0, data.Rep, ticks, shots, gains, table.concat(fx.gains, ' ', math.max(1, #fx.gains - 3)), hudTicks, tostring(lastHud)))
-- (the server pays on a 0.25 s clock: in Roblox the first pay lands within 0.25 s; the harness's slow frames stretch it)
check('lane: the first Power within 1.5 s of stepping on (harness wall time; 0.25 s in Roblox)', firstShotAt ~= nil and firstShotAt <= 1.5, firstShotAt and ('%.2f s'):format(firstShotAt) or 'none')
check('lane: Power climbs every second', ticks >= math.floor(secs) , ticks .. ' pays in ' .. ('%.1f'):format(secs) .. ' s')
local simSecs = simFrames / 30
check('lane: the gun fires ShotRules.AutoRate shots a second on screen', shots >= math.floor(simSecs * 2) - 1 and shots > 0, ('%d shots in %.1f s of frames'):format(shots, simSecs))
check('lane: every shot has its "+N"', gains >= shots and gains > 0, gains .. ' pops / ' .. shots .. ' shots')
check('lane: the HUD Power counter ticks with the shots', hudTicks >= math.floor(secs), hudTicks .. ' changes')
-- kid-safe: a white hit flash on any one target at most once a second (RULES.md)
local worstFlash, worstName = 0, ''
for model, list in fx.flashes do
	for i = 1, #list do
		local n = 0
		for j = i, #list do if list[j] - list[i] < 30 then n += 1 end end
		if n > worstFlash then worstFlash, worstName = n, model.Name end
	end
end
check('lane: a target flashes at most once a second', worstFlash <= 1, worstFlash .. ' in a second on ' .. worstName)
local popOk = true
for _, t in fx.gains do if not tostring(t):match('^%d') then popOk = false end end
check('lane: the "+N" pops read as numbers', popOk, fx.gains[1])

---------------------------------------------------------------------------------------------------------- 3. step off / on, flicker, locked lane
outOfLane(zp, ld)
local tOff = os.clock()
waitFor(function() return (P:GetAttribute('TrainingStation') or '') == '' end, 2)
local offAfter = os.clock() - tOff
local pOff = data.Rep
settle(1.5)
check('step off: training stops within 1.5 s (harness wall time)', (P:GetAttribute('TrainingStation') or '') == '' and offAfter <= 1.5, ('%.2f s'):format(offAfter))
check('step off: no Power off the lane', data.Rep == pOff, pOff .. ' -> ' .. data.Rep)
-- a kid hopping on and off the mat
for _ = 1, 6 do
	inLane('Starter'); frame(0.1)
	outOfLane(zp, ld); frame(0.1)
end
inLane('Starter')
local pF = data.Rep
waitFor(function() return data.Rep > pF end, 2)
check('flicker on/off x6 then on: still trains', data.Rep > pF and P:GetAttribute('TrainingStation') == 'Starter', tostring(P:GetAttribute('TrainingStation')))
outOfLane(zp, ld)
waitFor(function() return (P:GetAttribute('TrainingStation') or '') == '' end, 2)
check('flicker: off again cleanly', (P:GetAttribute('TrainingStation') or '') == '', tostring(P:GetAttribute('TrainingStation')))
-- a locked lane (BAY 2 at 0 rebirths): no Power, says why
local okT, zpT, ldT = inLane('Tape')
local pT = data.Rep
settle(1.5)
check('locked BAY 2: marked locked, pays nothing', okT and tostring(P:GetAttribute('TrainingStation')):find('^Locked') ~= nil and data.Rep == pT, tostring(P:GetAttribute('TrainingStation')) .. ' Power ' .. pT .. ' -> ' .. data.Rep)
check('locked BAY 2: says how many rebirths it needs', (P:GetAttribute('TrainingNeed') or 0) > 0, 'TrainingNeed=' .. tostring(P:GetAttribute('TrainingNeed')))
if okT then outOfLane(zpT, ldT) end
waitFor(function() return (P:GetAttribute('TrainingStation') or '') == '' end, 2)
check('locked BAY 2: off cleanly', (P:GetAttribute('TrainingStation') or '') == '', tostring(P:GetAttribute('TrainingStation')))

---------------------------------------------------------------------------------------------------------- 4. after buying a gun: the goal moves on
home()
data.Goals.Step = GoalRules.ById.Gun.Step
data.Cash = 500; P:SetAttribute('Cash', data.Cash)
settle(1.5)
local _, gtBuy = goalLine()
check('the gun goal is up', gtBuy == GoalRules.ById.Gun.Text, tostring(gtBuy))
-- (Oct 27, round 6) the lasting guide after the tutorial (HoodClient/GoalGuide): an arrow over the goal's place, the
-- ARMORY for "Buy a gun", seen from the spawn; gone while a window is open
data.Onboarding = type(data.Onboarding) == 'table' and data.Onboarding or {}
data.Onboarding.Done, data.Onboarding.Gift = true, true
waitFor(function() return P:GetAttribute('OnboardingStep') == 'Done' end, 4)
frame(0.3)
local guide = workspace:FindFirstChild('HoodGoalGuide')
local shaft = guide and guide:FindFirstChild('ArrowShaft')
local armory = game:GetService('CollectionService'):GetTagged('HoodArmory')[1]
local guideOn = shaft ~= nil and shaft.Transparency < 0.5
-- (the arrow stands at the ARMORY's edge nearest you: how far it is outside the ARMORY's footprint, in studs)
local guideD
if guideOn and armory then
	local bcf, bsize = armory:GetBoundingBox()
	local q = bcf:PointToObjectSpace(shaft.CFrame.Position)
	guideD = math.max(0, math.abs(q.X) - bsize.X / 2) + math.max(0, math.abs(q.Z) - bsize.Z / 2)
end
check('guide: after the tutorial an arrow stands at the ARMORY for "Buy a gun"', guideOn and guideD ~= nil and guideD < 2, ('step %s shown %s, %s studs outside the ARMORY'):format(tostring(P:GetAttribute('OnboardingStep')), tostring(guideOn), tostring(guideD and math.floor(guideD * 10) / 10)))
P.PlayerGui:SetAttribute('HoodWindow', 'Store'); frame(0.2)
check('guide: hidden while a window is open', shaft ~= nil and shaft.Transparency >= 0.99, shaft and tostring(shaft.Transparency) or 'no arrow')
P.PlayerGui:SetAttribute('HoodWindow', ''); frame(0.2)
local pt = workspace.TheBlockV2:FindFirstChild('GunPoint_Revolver', true)
if pt then
	local q = frameCF:PointToObjectSpace(pt.CFrame.Position)
	standMap(q.X, q.Z, 0, q.Y - 3)
end
frame(0.2)
RS.HoodNet.BuyGun:FireServer('Revolver')
settle(4.5) -- (GoalService holds a goal 2.2 s after a purchase so the purchase's own moment comes first)
local _, gtAfter, stAfter = goalLine()
check('buy the Revolver: owned and in hand', P:GetAttribute('EquippedGun') == 'Revolver', toolWhere())
check('after buying: the goal moved past "Buy a gun"', type(stAfter) == 'number' and stAfter > GoalRules.ById.Gun.Step, tostring(gtAfter))

---------------------------------------------------------------------------------------------------------- 5. rebirth: the payoff
home()
data.Goals.Step = GoalRules.ById.Rebirth1.Step
local need = RebirthRules.need(data.Rebirths)
ev('FF', 'Power to the rebirth'); data.Rep = need + 3; P:SetAttribute('Power', data.Rep)
settle(1.5)
local mBefore = P:GetAttribute('RebirthMultiplier')
local mNext = P:GetAttribute('RebirthNextMultiplier')
check('rebirth ready shows', P:GetAttribute('RebirthReady') == true, 'need ' .. tostring(P:GetAttribute('RebirthNeed')))
do
	-- (round 8) the Rebirth button comes when the first rebirth is ready, with its one-time NEW!; by now the tutorial is
	-- over, so its YOU'RE READY! has played and the Robux offers are in; the gun bought brought Skins
	local col = P.PlayerGui.HoodHUD:FindFirstChild('Actions', true)
	local rb = col and col:FindFirstChild('Rebirth')
	waitFor(function() return hudShown('Rebirth') and rb ~= nil and rb.Visible end, 3)
	check('the Rebirth button comes with the first rebirth ready, with NEW!', hudShown('Rebirth') and rb ~= nil and rb.Visible and rb:FindFirstChild('NewTag') ~= nil, ('shown %s, NEW! %s'):format(tostring(hudShown('Rebirth')), tostring(rb and rb:FindFirstChild('NewTag') ~= nil)))
	waitFor(function() return hudShown('Offers') end, 8)
	check('after YOU\'RE READY!: the Robux offers are in, and Skins (a second gun)', hudShown('Offers') and hudShown('PowerPacks') and hudShown('StarterPack') and hudShown('FriendBoost') and hudShown('Skins'), ('offers %s packs %s starter %s friend %s skins %s'):format(tostring(hudShown('Offers')), tostring(hudShown('PowerPacks')), tostring(hudShown('StarterPack')), tostring(hudShown('FriendBoost')), tostring(hudShown('Skins'))))
end
local mk = #_G.__toClient + 1
RS.HoodNet.Rebirth:FireServer()
local sawMoment = waitFor(function() local hud = P.PlayerGui:FindFirstChild('HoodHUD'); return hud ~= nil and hud:FindFirstChild('RebirthMoment', true) ~= nil end, 3)
local mom = P.PlayerGui.HoodHUD:FindFirstChild('RebirthMoment', true)
local momText = {}
if mom then for _, d in mom:GetDescendants() do if d:IsA('TextLabel') then table.insert(momText, strip(d.Text)) end end end
local cine
for i = mk, #_G.__toClient do local m = _G.__toClient[i]; if m[1] == 'Cinematic' and type(m[2]) == 'table' and m[2].Kind == 'Rebirth' then cine = m[2] end end
log(('rebirth: x%s -> x%s (next shown before: x%s); moment "%s"'):format(tostring(mBefore), tostring(cine and cine.Multiplier), tostring(mNext), table.concat(momText, ' / ')))
check('rebirth: Power back to 0, Rebirths +1', data.Rep == 0 and data.Rebirths == 1, ('Power %d Rebirths %d'):format(data.Rep, data.Rebirths))
check('rebirth: the multiplier went up', cine ~= nil and type(mBefore) == 'number' and cine.Multiplier > mBefore, tostring(mBefore) .. ' -> ' .. tostring(cine and cine.Multiplier))
check('rebirth: the moment shows on screen', sawMoment and #momText > 0, table.concat(momText, ' / '))
local mt = table.concat(momText, ' ')
-- (Oct 27, round 6: the moment is the payoff, "x1 > x2": the old multiplier, then the new one)
local function momPart(name) local l = mom and mom:FindFirstChild(name, true); return l and l:IsA('TextLabel') and strip(l.Text) or '' end
local fromTo = momPart('From') .. ' ' .. momPart('Arrow') .. ' ' .. momPart('To')
check('rebirth: the moment shows the old and the new multiplier ("x1 > x2")', fromTo == ('x' .. tostring(mBefore) .. ' > x' .. tostring(cine and cine.Multiplier)), fromTo)
check('rebirth: the moment names the new multiplier', mt:find('x' .. tostring(cine and cine.Multiplier)) ~= nil, mt)
check('rebirth: the counters are clean after', #badNumbers() == 0, table.concat(badNumbers(), ', '))
settle(1.5)
waitFor(function() return goalLine() ~= '' end, 10) -- (the rebirth goal's GOAL DONE moment holds the screen first)
local ok5, why5 = goalDoable()
local l5 = goalLine()
check('after the rebirth: the goal line says a doable step', l5 ~= '' and ok5, why5)
-- train again at once: the new multiplier pays
inLane('Starter')
local pR = data.Rep
waitFor(function() return data.Rep > pR end, 2)
check('after the rebirth: the lane pays again', data.Rep > pR, pR .. ' -> ' .. data.Rep)
outOfLane(zp, ld)
waitFor(function() return (P:GetAttribute('TrainingStation') or '') == '' end, 2)

---------------------------------------------------------------------------------------------------------- 6. the long middle: every lane goal while its lane is locked
for _, id in { 'Range2', 'Range3', 'Range4' } do
	local g = GoalRules.ById[id]
	local st = Skins.Stations[g.Need.Range]
	data.Goals.Step = g.Step
	data.Rebirths = math.max(0, (st.Rebirths or 0) - 1)
	data.Rep = 0
	ev('FF', id .. ' with ' .. data.Rebirths .. ' rebirths')
	pcall(function() require(fake.RebirthService).publish(P, data) end)
	settle(1.6)
	local ok6, why6 = goalDoable()
	check(id .. ' one rebirth short: the line says what to do', ok6, why6)
	-- once it opens: train there
	data.Rebirths = st.Rebirths
	pcall(function() require(fake.RebirthService).publish(P, data) end)
	settle(1.2)
	local okIn = inLane(st.Id)
	settle(2.2)
	check(id .. ' open: training there completes the goal', okIn and (data.Goals.Step > g.Step), ('%s step %d -> %d, station %s'):format(st.Name, g.Step, data.Goals.Step, tostring(P:GetAttribute('TrainingStation'))))
	home()
end

---------------------------------------------------------------------------------------------------------- 7. a maxed lane (BAY 4 at 9 rebirths: the next lane is at 15)
data.Rebirths = 9; data.Rep = 0
data.Goals.Step = GoalRules.ById.Range5.Step
pcall(function() require(fake.RebirthService).publish(P, data) end)
settle(1.6)
local ok7, why7 = goalDoable()
check('after World 1\'s crews, BAY 5 still locked: the line says what to do', ok7, why7)

---------------------------------------------------------------------------------------------------------- 8. after the boss and at the end of the chain
data.Goals.Step = #GoalRules.List + 1
settle(1.6)
local l8, t8 = goalLine()
check('all goals done: the line points somewhere (World 2)', (tostring(P:GetAttribute('GoalWhere')):find('World 2') ~= nil) and l8:find('World 2') ~= nil, l8)

---------------------------------------------------------------------------------------------------------- 9. big numbers on the counters
-- (fractional values: Lune stores a whole-number attribute as a 32-bit integer, Roblox as a double; see Shared/BigAttr)
for _, v in { 2 ^ 31 + 7.5, 4.2e9 + 0.5, 9.9e14 + 0.5 } do
	data.Rep = v; P:SetAttribute('Power', v)
	data.Cash = v; P:SetAttribute('Cash', v)
	pcall(function() require(fake.RebirthService).publish(P, data) end)
	local want = require(RS.Shared.UIKit).short(v)
	-- (the counter rolls up over 0.5 s; the harness's tweens don't fire Changed, so the HUD is asked to repaint after it)
	waitFor(function() __fireOn(P, 'Attr_FriendBoost'); return hudText('Power') == want end, 4)
	local bad = badNumbers()
	check(('counters at %.4g'):format(v), #bad == 0 and hudText('Power') == want, (hudText('Power') or '?') .. ' want ' .. want .. ' ' .. table.concat(bad, ', '))
end
-- a Power gain past the server's cap stays at the cap (never inf / NaN)
data.Rep = 1e15
inLane('Starter'); settle(1.2)
check('Power at the 1e15 cap stays a number', data.Rep == data.Rep and data.Rep <= 1e15, tostring(data.Rep))
home()

---------------------------------------------------------------------------------------------------------- 10. one voice at a time
-- (Oct 27, flow) A goal moment, a rank-up and a news notice all arrive in the same frame: they take turns (the moment
-- queue, Shared/MomentQueue), never two on screen, with a calm between; the level toast stays quiet meanwhile.
home(); settle(3)
;(function() -- (its own function: the script is at Luau's 200 locals)
local HudToasts = require(RS.Shared.HudToasts)
local seenUp, overlap, order, gaps = {}, {}, {}, {}
local lastName, lastEnd = nil, nil
RS.HoodNet.Goal:FireClient(P, { Kind = 'Done', Text = 'A test goal', Reward = 5, NextText = 'Reach Stage 3', NextReward = 25 })
RS.HoodNet.RankUp:FireClient(P, { From = 2, To = 3, Cash = 150 })
HudToasts.say('Got a test reward!', 'green')
local tq = os.clock()
waitFor(function()
	local G = P.PlayerGui
	local up = {}
	if G:FindFirstChild('HoodGoals') and G.HoodGoals:FindFirstChild('GoalDone', true) then table.insert(up, 'GoalDone') end
	if G:FindFirstChild('HoodProgress') and G.HoodProgress:FindFirstChild('RankUp', true) then table.insert(up, 'RankUp') end
	local st = G:FindFirstChild('HoodNotices') and G.HoodNotices:FindFirstChild('Toasts', true)
	if st then for _, c in st:GetChildren() do if c:IsA('Frame') then table.insert(up, 'Notice'); break end end end
	for _, u in up do seenUp[u] = true end
	if #up > 1 then table.insert(overlap, table.concat(up, '+')) end
	local m = G:GetAttribute('HoodMoment')
	m = (type(m) == 'string' and m ~= '') and m or nil
	if m ~= lastName then
		if lastName then lastEnd = os.clock() end
		if m then
			table.insert(order, m)
			if lastEnd and lastName == nil then table.insert(gaps, os.clock() - lastEnd) end
		end
		lastName = m
	end
	return seenUp.GoalDone and seenUp.RankUp and seenUp.Notice and m == nil and os.clock() - tq > 3
end, 30)
local least = math.huge
for _, g in gaps do least = math.min(least, g) end
check('one voice: the goal moment, the rank-up and the notice all show', seenUp.GoalDone and seenUp.RankUp and seenUp.Notice, table.concat(order, ' > '))
check('one voice: never two on screen at once', #overlap == 0, table.concat(overlap, ', '):sub(1, 160))
check('one voice: a calm of at least 1.5 s between them (harness frames)', #gaps >= 2 and least >= 1.4, ('%d gaps, the least %.2f s'):format(#gaps, least == math.huge and -1 or least))
end)()

---------------------------------------------------------------------------------------------------------- 11. at most one white flash a second
-- (Oct 27, flow round 2, kid-safe) A busy lane: you auto-fire in BAY 1 while two more players join and train beside
-- you, their hits drawn on the lane's other targets twice a second each. Every white flash on screen is counted (a
-- Highlight going on near-white, from any source) over 5 s of wall time: never two within a second; the hits in
-- between still answer, with the soft tint.
;(function()
	local Juice = require(RS.Shared.Juice)
	local others = {}
	for i = 2, 3 do
		pcall(function()
			local q = Instance.new('Player'); q.Name = 'Friend' .. i; q.Parent = game:GetService('Players')
			table.insert(others, q)
		end)
	end
	local okL = inLane('Starter')
	local targets = {}
	for _, m in workspace.TheBlockV2:GetDescendants() do
		if m:IsA('Model') and m:GetAttribute('Hit') ~= nil then table.insert(targets, m) end
		if #targets >= 6 then break end
	end
	local on, whites, softs, t0, lastFire = {}, {}, 0, os.clock(), 0
	local n = 0
	while os.clock() - t0 < 5 do
		frame(1 / 30)
		n += 1
		if os.clock() - lastFire >= 0.25 and #targets > 0 then -- (two friends, two hits a second each)
			lastFire = os.clock()
			pcall(Juice.flash, targets[(n % #targets) + 1])
		end
		for _, h in workspace:GetDescendants() do
			if h:IsA('Highlight') and h.Name == 'HitFlash' then
				local lit = h.Enabled and h.FillTransparency < 0.6
				local white = lit and h.FillColor.R > 0.95 and h.FillColor.G > 0.95 and h.FillColor.B > 0.95
				if white and not on[h] then table.insert(whites, os.clock()) end
				if lit and not white and not on[h] then softs += 1 end
				on[h] = lit or nil
				if h.Enabled and h.FillTransparency >= 0.6 and h:GetAttribute('White') == false and not on['s' .. tostring(h)] then softs += 1; on['s' .. tostring(h)] = true end
				if not h.Enabled then on['s' .. tostring(h)] = nil end
			end
		end
	end
	local closest = math.huge
	for i = 2, #whites do closest = math.min(closest, whites[i] - whites[i - 1]) end
	check('flashes: a busy lane with 3 players flashes white at most once a second', okL and #whites >= 2 and closest >= 0.95, ('%d white flashes in 5 s, the closest two %.2f s apart, %d soft hits, %d friends'):format(#whites, closest == math.huge and -1 or closest, softs, #others))
	check('flashes: the hits in between still answer (the soft tint)', softs >= 5, softs .. ' soft hits')
	for _, q in others do pcall(function() q:Destroy() end) end
	home()
end)()

print(('[loop] %d checks / %d failed%s'):format(LOOPN, #LOOPF, #LOOPF > 0 and (': ' .. table.concat(LOOPF, '; ')) or ''))
return { checks = LOOPN, failed = #LOOPF }
