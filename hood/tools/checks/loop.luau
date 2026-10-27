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
settle(1.5)
local line0 = goalLine()
check('spawn: the goal line shows a step', line0 ~= '', line0)
check('spawn: counters are clean numbers', #badNumbers() == 0, table.concat(badNumbers(), ', '))

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
-- (the Rebirth window counts x1 up to x2 before you press; the moment after names the new one. Logged, not failed:
-- HUD.client is the UI's file)
log(('NOTE rebirth moment names the new multiplier%s: "%s"'):format(mt:find('x' .. tostring(mBefore) .. ' ', 1, true) and ' and the old' or ' only', mt))
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

print(('[loop] %d checks / %d failed%s'):format(LOOPN, #LOOPF, #LOOPF > 0 and (': ' .. table.concat(LOOPF, '; ')) or ''))
return { checks = LOOPN, failed = #LOOPF }
