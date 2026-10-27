---------------------------------------------------------------------------------------------------------- HOOK: the guided first session
-- (HOOK, brief 23) Everything above is CRITIC3's feel.luau set-up, frozen (real servers + real clients on a fresh
-- save, the K kid clock, the event tracker). From here a new player FOLLOWS THE GUIDANCE the way a kid would: wherever
-- OnboardingStep and its target point, straight there at WalkSpeed, no detours, then logs the HOOK timeline.
local Rules = require(RS.Shared.OnboardingRules)
local GunsCfg = require(RS.Shared.Config.Guns)
local J = require(RS.Shared.Juice)
-- What the kid sees that the event tracker can't read from the PlayerGui: the shot effects, the "+N" pops, bursts.
local fxSeen = {}
for _, name in { 'tracer', 'muzzle', 'popNumber', 'burst', 'combo', 'shards', 'kick' } do
	local orig = J[name]
	if type(orig) == 'function' then
		J[name] = function(...)
			local args = { ... }
			if name == 'popNumber' or name == 'combo' then
				local txt = tostring(args[2] or args[3] or '')
				if not fxSeen[name] then fxSeen[name] = true; ev('fx', name .. ' "' .. txt:sub(1, 20) .. '" (first)') end
			elseif not fxSeen[name] then
				fxSeen[name] = true
				ev('fx', name .. ' (first)')
			end
			fxSeen.count = (fxSeen.count or 0) + 1
			return orig(...)
		end
	end
end
-- HOOK's own pieces: the callout word, the arrow's word, the present, OnboardingStep.
local hk = { word = nil, arrow = nil, gift = false, step = nil }
-- (Oct 27, flow) What the flow round promises, watched every tick: one moment at a time with a calm between, the goal
-- line quiet during the tutorial, one guide at a time, no level toast in the first minute.
local FL = { moments = {}, cur = nil, curAt = nil, lastEnd = nil, gaps = {}, overlap = {}, goalLineInTut = 0, guides2 = 0,
	levelToastEarly = 0, goalDoneInTut = 0, ready = false, crew = false, reveal = nil, powerBox = false, start = nil,
	doneAt = nil, readyAt = nil, readyLead = nil, offersEarly = 0, revealEarly = {}, revealWant = {}, newSeen = {} }
-- (Oct 27, round 8) the calm first screen: what Shared/HudReveal asks for, from the player's own attributes (sticky)
local HudRevealF = require(RS.Shared.HudReveal)
local CHEAPEST_BOX = (function()
	local best = math.huge
	for _, b in require(RS.Shared.Config.Shoes).Boxes do if type(b.Price) == 'number' and (b.World or 1) == 1 and b.Price < best then best = b.Price end end
	return best
end)()
local function revealTrack()
	local G = P.PlayerGui
	local guns = P:GetAttribute('OwnedGuns')
	local shoes = P:GetAttribute('ShoesOwned')
	local want = HudRevealF.wants({
		TutorialDone = P:GetAttribute('OnboardingStep') == 'Done' and G:GetAttribute('TutorialReady') == true,
		Cash = P:GetAttribute('Cash') or 0, CheapestBox = CHEAPEST_BOX,
		Shoes = (type(shoes) == 'string' and shoes ~= '') and 1 or 0, Boxes = P:GetAttribute('BoxesOpened') or 0, Unboxing = G:GetAttribute('Unboxing') == true,
		Guns = type(guns) == 'string' and guns ~= '' and select(2, guns:gsub(',', ',')) + 1 or 0,
		Power = P:GetAttribute('Power') or 0, RebirthNeed = P:GetAttribute('RebirthNeed') or 0, RebirthReady = P:GetAttribute('RebirthReady') == true, Rebirths = P:GetAttribute('Rebirths') or 0,
	})
	for _, part in HudRevealF.All do
		if want[part] then FL.revealWant[part] = true end
		-- (a part may come up to a beat after its reason: the HUD looks once a second at the latest; never before it)
		if G:GetAttribute('HudShown_' .. part) == true and not FL.revealWant[part] then FL.revealEarly[part] = (FL.revealEarly[part] or 0) + 1 end
	end
	if G:GetAttribute('HudShown_Offers') == true and not FL.ready then FL.offersEarly += 1 end
	local col = G:FindFirstChild('HoodHUD') and G.HoodHUD:FindFirstChild('Actions', true)
	if col then
		for _, b in col:GetChildren() do
			if b:GetAttribute('New') == true and b:FindFirstChild('NewTag') then FL.newSeen[b.Name] = true end
		end
	end
end
local function shownGui(g)
	if not g or (g:IsA('ScreenGui') and not g.Enabled) then return false end
	return true
end
local function visibleChainF(d)
	local x = d
	while x and x:IsA('GuiObject') do if not x.Visible then return false end; x = x.Parent end
	return true
end
local function flowTrack()
	local G = P.PlayerGui
	local now = K
	-- the moment queue's own word for what is on screen
	local m = G:GetAttribute('HoodMoment')
	m = (type(m) == 'string' and m ~= '') and m or nil
	if not FL.doneAt and P:GetAttribute('OnboardingStep') == 'Done' then FL.doneAt = now end
	pcall(revealTrack)
	if m ~= FL.cur then
		if FL.cur then FL.lastEnd = now; ev('moment', 'moment ends: ' .. FL.cur) end
		if m then
			if FL.lastEnd and FL.cur == nil then table.insert(FL.gaps, { now - FL.lastEnd, m }) end
			table.insert(FL.moments, { m, now })
			ev('moment', 'moment: ' .. m)
		end
		FL.cur = m
	end
	-- the popups themselves: never two at once
	local up = {}
	local goals = G:FindFirstChild('HoodGoals')
	local gd = goals and goals:FindFirstChild('GoalDone', true)
	if gd then
		local title = gd:FindFirstChild('Title')
		local tt = title and title.Text or ''
		table.insert(up, 'GoalDone:' .. tt)
		if tt == "YOU'RE READY!" then
			FL.ready = true
			FL.readyAt = FL.readyAt or K
			local lead = gd:FindFirstChild('Lead')
			FL.readyLead = FL.readyLead or (lead and lead.Text)
		end
		if tt == 'GOAL DONE!' and P:GetAttribute('OnboardingStep') ~= 'Done' then FL.goalDoneInTut += 1 end
	end
	if G:FindFirstChild('HoodGunReveal') then
		table.insert(up, 'GunReveal')
		local t = {}
		for _, d in G.HoodGunReveal:GetDescendants() do if d:IsA('TextLabel') and not d.Name:find('Shadow') then table.insert(t, d.Text) end end
		FL.reveal = FL.reveal or table.concat(t, ' | ')
		local hg = G:FindFirstChild('HoodTutorialHint')
		local h = hg and hg:FindFirstChild('Hint', true)
		if h and h.Visible and visibleChainF(h) then FL.hintOverReveal = (FL.hintOverReveal or 0) + 1 end
	end
	local prog = G:FindFirstChild('HoodProgress')
	if prog and prog:FindFirstChild('RankUp', true) then table.insert(up, 'RankUp') end
	local hud = G:FindFirstChild('HoodHUD')
	if hud and hud:FindFirstChild('RebirthMoment', true) then table.insert(up, 'Rebirth') end
	local waves = G:FindFirstChild('HoodWaves')
	if waves and waves:FindFirstChild('CrewIncoming', true) then table.insert(up, 'Crew'); FL.crew = true end
	if G:FindFirstChild('HoodWelcome') then table.insert(up, 'Welcome') end
	if #up > 1 then table.insert(FL.overlap, ('%.1f %s'):format(now, table.concat(up, '+'))) end
	-- the goal line while the tutorial runs
	local tr = goals and goals:FindFirstChild('Goal', true)
	if tr and tr:IsA('GuiObject') and visibleChainF(tr) and goals.Enabled and P:GetAttribute('OnboardingStep') ~= 'Done' then FL.goalLineInTut += 1 end
	-- one guide at a time: the tutorial's arrows, the goal guide's arrow, the lobby's "TRAIN HERE" pointer
	local gs = {}
	if G:GetAttribute('HoodGuide') == 'Tutorial' then table.insert(gs, 'Tutorial') end
	local gg = workspace:FindFirstChild('HoodGoalGuide')
	local shaft = gg and gg:FindFirstChild('ArrowShaft')
	if shaft and shaft.Transparency < 0.5 then table.insert(gs, 'GoalGuide') end
	local nd = G:FindFirstChild('NextDestination')
	if nd and nd.Adornee ~= nil and nd.Enabled ~= false then table.insert(gs, 'Lobby') end
	if #gs > 1 then FL.guides2 += 1; FL.guidePair = FL.guidePair or ('%.1f %s %s (lobby pointer on %s)'):format(now, table.concat(gs, '+'), tostring(P:GetAttribute('OnboardingStep')), nd and nd.Adornee and nd.Adornee.Name or '-') end
	-- level toasts in the first minute (of the visit: the harness clock from the start of the clients)
	local lt = prog and prog:FindFirstChild('LevelToast', true)
	if lt and lt.Visible and os.clock() - W0 < 60 then FL.levelToastEarly += 1 end
	-- BAY 1's Power box
	local foc = G:FindFirstChild('HoodTutorial')
	-- (the harness lays out no HUD, so the box itself can't lock on here: the tutorial's own word for what it points at)
	if foc and (foc:GetAttribute('Boxed') == 'Line' or foc:GetAttribute('Want') == 'Power') then FL.powerBox = true end
end
local function hookTrack()
	local g = P.PlayerGui:FindFirstChild('HoodOnboarding')
	local c = g and g:FindFirstChild('Callout', true)
	local w = c and c:GetAttribute('Word')
	if w ~= hk.word then
		if w then ev('callout', 'callout "' .. w .. '"' .. (c:GetAttribute('Why') == 'hint' and ' (timed hint)' or '')) end
		hk.word = w
	end
	local f = workspace:FindFirstChild('HoodOnboardingLocal')
	local a = f and f:FindFirstChild('GuideArrowAnchor')
	local bb = a and a:FindFirstChild('WorldLabel')
	local aw = bb and bb.Enabled and bb:FindFirstChild('Title') and bb.Title.Text or nil
	if aw ~= hk.arrow then
		if aw then ev('guide', 'arrow + trail "' .. aw .. '"') end
		hk.arrow = aw
	end
	local gm = f and f:FindFirstChild('WelcomeGift') ~= nil
	if gm ~= hk.gift then
		ev('gift', gm and 'the present appears' or 'the present opens')
		hk.gift = gm
	end
	local s = P:GetAttribute('OnboardingStep')
	if s ~= hk.step then hk.step = s end
	flowTrack()
end
local trackOrig = track
track = function() trackOrig(); hookTrack() end
-- (frame() calls the upvalue `track`: rebind it through a wrapper the frame loop sees)

local function stepNow() return P:GetAttribute('OnboardingStep') end
-- A picture (only with EXPORT): waits up to 4 s for the callout `word` to be on screen first.
local function calloutWord()
	local g = P.PlayerGui:FindFirstChild('HoodOnboarding')
	local c = g and g:FindFirstChild('Callout', true)
	return c and c:GetAttribute('Word')
end
local function snap(tag, note, word)
	if not EXPORT then return end
	if word then waitFor(function() return calloutWord() == word end, 4); wall(0.35) end
	-- (render13 skips fully transparent parts and their billboards; Roblox draws a billboard on one: the renders show
	-- the invisible anchors' labels the way Roblox does)
	local lifted = {}
	for _, d in workspace:GetDescendants() do
		if d:IsA('BasePart') and d.Transparency >= 1 and d:FindFirstChildWhichIsA('BillboardGui') then table.insert(lifted, d); d.Transparency = 0.995 end
	end
	for _, b in P.PlayerGui:GetChildren() do
		if b:IsA('BillboardGui') and b.Enabled and b.Adornee and b.Adornee:IsA('BasePart') and b.Adornee.Transparency >= 1 then table.insert(lifted, b.Adornee); b.Adornee.Transparency = 0.995 end
	end
	step(tag, note, 220)
	for _, d in lifted do pcall(function() d.Transparency = 1 end) end
end
local function untilStep(want, maxWall)
	return waitFor(function() hookTrack(); local s = stepNow(); return type(want) == 'table' and table.find(want, s) ~= nil or s == want end, maxWall or 8)
end
local function mapOf(world) return frameCF:PointToObjectSpace(world) end
-- Walk, but stop the moment the server moves you (a pad's trip home): returns true if you were taken somewhere.
local function walkStop(x0, z0, x1, z1, floor)
	local d = Vector3.new(x1 - x0, 0, z1 - z0)
	local yaw = yawOf(d.X, d.Z)
	local n = math.max(1, math.floor(d.Magnitude / 1.0))
	WALKING = true
	for k = 1, n do
		local a = k / n
		local want = Vector3.new(x0 + d.X * a, 0, z0 + d.Z * a)
		standMap(want.X, want.Z, yaw, floor)
		K += d.Magnitude / n / walkSpeed()
		frame(1 / 10)
		local at = mapPos()
		if Vector3.new(at.X - want.X, 0, at.Z - want.Z).Magnitude > 8 then WALKING = false return true end
	end
	WALKING = false
	for _ = 1, 8 do
		frame(1 / 10)
		local at = mapPos()
		if Vector3.new(at.X - x1, 0, at.Z - z1).Magnitude > 8 then return true end
	end
	return false
end
-- Walk to a world point along the floor (straight, as the trail draws it), at the floor height of the target.
local function walkWorld(world, floorY)
	local q = mapOf(world)
	walkTo(q.X, q.Z, floorY)
end

---------------------------------------------------------------------------------------------------------- 0. spawn
local SP = workspace.TheBlockV2:GetAttribute('LobbySpawn') or Vector3.new(0, 0, 55)
standMap(SP.X, SP.Z, workspace.TheBlockV2:GetAttribute('LobbySpawnYaw') or 0)
pcall(function() __fireOn(P, 'CharacterAdded', char) end)
camFn = follow(0, -1)
K = 0; resetClock(); EV = {}
ev('spawn', 'spawned (fresh save)')
frame(0.2)
-- (Oct 27, flow) the first-join welcome: hands off, it plays out by itself and gives the camera back; the kid clock
-- (K) then starts again from 0 at the moment the kid has control
local WEL = { seen = false, text = '', k = nil, camBack = nil, hintDuring = false, hudOn = 0, otherOn = 0, hudBack = nil }
local function hudOnNow()
	local h = P.PlayerGui:FindFirstChild('HoodHUD')
	return h ~= nil and h.Enabled
end
WEL.seen = waitFor(function()
	if hudOnNow() then WEL.hudOn += 1 end -- (round 8: not even before the welcome comes up)
	return P.PlayerGui:FindFirstChild('HoodWelcome') ~= nil
end, 4)
if WEL.seen then
	local seenText, frames = {}, 0
	waitFor(function()
		frames += 1 -- (game time: one harness frame is 1/30 s, however slow the machine runs it)
		local g = P.PlayerGui:FindFirstChild('HoodWelcome')
		if g then
			for _, d in g:GetDescendants() do
				if d:IsA('TextLabel') and d.Text ~= '' and not d.Name:find('Shadow') and not seenText[d.Text] then seenText[d.Text] = true; WEL.text ..= (WEL.text == '' and '' or ' ') .. d.Text end
			end
		end
		local hg = P.PlayerGui:FindFirstChild('HoodTutorialHint')
		local h = hg and hg:FindFirstChild('Hint', true)
		if h and h.Visible then WEL.hintDuring = true end
		if g and hudOnNow() then WEL.hudOn += 1 end
		local goals = P.PlayerGui:FindFirstChild('HoodGoals')
		if g and goals and goals.Enabled then WEL.otherOn += 1 end
		return g == nil
	end, 30)
	WEL.k = frames / 30
	WEL.camBack = workspace.CurrentCamera.CameraType ~= Enum.CameraType.Scriptable
	local backFrames = 0
	if waitFor(function() backFrames += 1; return hudOnNow() end, 3) then WEL.hudBack = backFrames / 30 end
end
log(('[welcome] seen=%s for %.1f s (game time) text="%s" camera back=%s hint during it=%s HUD on during it %d ticks, back after %s s'):format(tostring(WEL.seen), WEL.k or -1, WEL.text, tostring(WEL.camBack), tostring(WEL.hintDuring), WEL.hudOn, tostring(WEL.hudBack)))
-- (the moment tracker's times move with the kid clock's new 0)
if FL.lastEnd then FL.lastEnd -= K end
for _, mo in FL.moments do mo[2] -= K end
K = 0; resetClock(); EV = {}
ev('spawn', 'control after the welcome')
local CLICK_AT = K
ev('input', 'kid clicks (holds 0.3 s) on the spawn')
hold(true); wall(0.3); hold(false)
wall(0.4)
log(('[0 spawn] K=%.1f step=%s gun=%s screen: %s'):format(K, tostring(stepNow()), toolWhere(), screen()))
untilStep('Train', 4)
mark('step_train', tostring(stepNow()))
snap('h01_spawn', 'the spawn: TRAIN! and the trail to BAY 1', 'TRAIN!')

---------------------------------------------------------------------------------------------------------- 1. BAY 1 (LOBBY5's guide)
local z1 = zoneOf('Starter')
local zp = z1 and frameCF:PointToObjectSpace(z1.CFrame.Position) or Vector3.new(-25.5, 0, 42)
local ld = z1 and laneDir(z1) or Vector3.new(0, 0, -1)
local mouth = Vector3.new(zp.X - ld.X * 9, 0, zp.Z - ld.Z * 9)
camFn = follow(ld.X, ld.Z)
walkTo(mouth.X, SP.Z)
walkTo(mouth.X, mouth.Z)
walkTo(zp.X, zp.Z, z1 and floorOf(z1) or 0)
standMap(zp.X, zp.Z, yawOf(ld.X, ld.Z), z1 and floorOf(z1) or 0)
mark('in_bay1')
local p0 = data.Rep
waitFor(function() return data.Rep > p0 end, 6)
mark('first_power', ('Power %d -> %d'):format(p0, data.Rep))
untilStep('Door', 14)
mark('step_door', ('Power %d'):format(data.Rep))
local POWER_AT_DOOR = data.Rep
wall(1.2) -- (a kid watches the numbers a beat, hears "GO!")
log(('[1 bay1] K=%.1f step=%s screen: %s'):format(K, tostring(stepNow()), screen()))

---------------------------------------------------------------------------------------------------------- 2. Stage 1 (the trail to the door)
walkTo(mouth.X, mouth.Z)
camFn = follow(0, -1)
walkTo(0, SP.Z - 14)
walkTo(0, 4)
walkTo(0, -6)
mark('stage1_entered')
untilStep('Fight', 3)
camFn = shoulder
snap('h01b_fight', 'into Stage 1: FIGHT! (lower, flies to the crew)', 'FIGHT!')
camFn = follow(0, -1)
-- toward the crew, holding the trigger (the goons notice you as you walk in)
hold(true)
local cleared = false
for k = 1, 16 do
	walkTo(0, -6 - k * 1.5)
	if (P:GetAttribute('WaveLeft') or 1) == 0 and P:GetAttribute('WaveStage') == 1 then break end
end
mark('at_crew')
cleared = waitFor(function() keepPressing(); return (P:GetAttribute('WaveLeft') or 1) == 0 and (P:GetAttribute('RunCleared') or 0) >= 1 end, 25)
hold(false)
mark('stage1_cleared', cleared and '' or '(NOT cleared in 25 s)')
untilStep('Cash', 4)
mark('step_cash', tostring(stepNow()))
wall(0.6)
camFn = follow(0.25, -1)
snap('h02_cash', 'the crew is down: CASH! and the trail to the yellow pad', 'CASH!')
if EXPORT then
	wall(1.8); camFn = behind(0.3, -1, 14, 9, 22); snap('h02b_arrow', 'a beat later: the arrow over the yellow pad, the trail')
	local pp
	for _, p in tagged('HoodStagePad') do if p:GetAttribute('Kind') == 'Return' and p:GetAttribute('Stage') == 1 then pp = mapOf(p.CFrame.Position) end end
	if pp then camFn = function() look(Vector3.new(pp.X - 3, 6, pp.Z + 16), Vector3.new(pp.X, 4.5, pp.Z)) end; snap('h02c_near', 'near the yellow pad: its label, the V over it (no clash)') end
	camFn = follow(0, -1)
end
log(('[2 clear] K=%.1f step=%s screen: %s'):format(K, tostring(stepNow()), screen()))

---------------------------------------------------------------------------------------------------------- 3. the yellow pad (HOOK's trail)
local padPos
for _, p in tagged('HoodStagePad') do
	if p:GetAttribute('Kind') == 'Return' and p:GetAttribute('Stage') == (P:GetAttribute('RunCleared') or 1) then padPos = p end
end
if padPos then
	local q = mapOf(padPos.CFrame.Position)
	local top = q.Y + padPos.Size.Y / 2
	local at = mapPos()
	-- (the server takes you home the moment you stand on it: stop walking then)
	local _ = walkStop(at.X, at.Z, q.X, q.Z + 12) or walkStop(q.X, q.Z + 12, q.X, q.Z, top)
	local home = waitFor(function() return inLobby() end, 4)
	mark('cash_pad', home and ('home, Cash ' .. data.Cash) or '(no teleport)')
else
	issue('no yellow pad for the stage just cleared')
end
local GIFT_ON = require(game.ReplicatedStorage.Shared.Config.Features).WelcomeGift == true -- (Oct 27: off for now)
untilStep(GIFT_ON and 'Gift' or { 'Gun', 'Run' }, 4)
mark('step_gift', tostring(stepNow()))
wall(0.8)
camFn = follow(0.35, -1)
snap('h03_gift', 'home: the welcome present', 'GIFT!')
log(('[3 home] K=%.1f step=%s giftAt=%s screen: %s'):format(K, tostring(stepNow()), tostring(P:GetAttribute('OnboardingGiftAt')), screen()))

---------------------------------------------------------------------------------------------------------- 4. the welcome present
local giftAt = P:GetAttribute('OnboardingGiftAt')
if typeof(giftAt) == 'Vector3' then
	local q = mapOf(giftAt)
	walkTo(q.X, q.Z + 1.5)
	waitFor(function() return P.PlayerGui:GetAttribute('Unboxing') == true or (data.Shoes and data.Shoes.Opened or 0) > 0 end, 3)
	mark('gift_opened', ('shoes opened %d, equipped %s'):format(data.Shoes and data.Shoes.Opened or 0, tostring(P:GetAttribute('ShoesEquipped'))))
	waitFor(function() return P.PlayerGui:GetAttribute('Unboxing') ~= true end, 9)
	mark('unboxing_over')
elseif GIFT_ON then
	issue('no gift spot published on the Gift step')
end
untilStep({ 'Gun', 'Run' }, 4)
mark('step_after_gift', tostring(stepNow()))
camFn = follow(1, -0.15)
snap('h04_gun', 'after the unboxing: GUN! and the trail to the ARMORY', 'GUN!')
if EXPORT then wall(1.8); camFn = behind(1, -0.15, 14, 9, 20); snap('h04b_arrow', 'a beat later: the arrow over the Revolver pad, the trail') end

---------------------------------------------------------------------------------------------------------- 5. the first gun (HOOK's trail to the ARMORY)
if stepNow() == 'Gun' then
	local id = Rules.nextGun(GunsCfg.List, data.Guns.Owned)
	local slot = id and workspace.TheBlockV2:FindFirstChild('GunSlot_' .. id, true)
	local mat = slot and (slot:FindFirstChild('StateMat', true) or slot:FindFirstChildWhichIsA('BasePart', true))
	if mat then
		local q = mapOf(mat.CFrame.Position)
		walkTo(q.X - 6, q.Z)
		walk(q.X - 6, q.Z, q.X, q.Z, q.Y + mat.Size.Y / 2)
		standMap(q.X, q.Z, yawOf(1, 0), q.Y + mat.Size.Y / 2)
		wall(0.5)
		local prompt
		for _, d in workspace.TheBlockV2:GetDescendants() do
			if d:IsA('ProximityPrompt') and d.Name == 'GunPrompt' and d.Parent and d.Parent.Name == 'GunPoint_' .. id then prompt = d end
		end
		local n0 = #_G.__toClient
		if prompt then press(prompt) else issue('no buy prompt on ' .. id) end
		wall(0.6)
		for i = n0 + 1, #_G.__toClient do if _G.__toClient[i][1] == 'Notice' then log('  armory notice: ' .. tostring(_G.__toClient[i][2])) end end
		waitFor(function() return data.Guns.Owned[id] == true end, 3)
		mark('first_gun', ('%s owned=%s equipped=%s Cash %d'):format(id, tostring(data.Guns.Owned[id]), tostring(data.Guns.Equipped), data.Cash))
		camFn = follow(1, 0)
		snap('h05_x2', 'bought: x2 POWER!', Rules.gunWord(GunsCfg.ById[id].Multiplier))
		wall(0.8)
	else
		issue('no ARMORY pad for ' .. tostring(id))
	end
end
untilStep('Run', 4)
mark('step_run', tostring(stepNow()))
camFn = follow(-0.5, -1)
snap('h06_run', 'GO! back to Stage 1', 'GO!')
camFn = follow(0, -1)

---------------------------------------------------------------------------------------------------------- 6. run 2 (HOOK's trail to the door)
local here = mapOf(root.CFrame.Position)
walkTo(math.min(here.X, 20), 40)
walkTo(0, 30)
walkTo(0, 4)
walkTo(0, -6)
mark('run2_entered', tostring(stepNow()))
untilStep('Done', 3)
mark('step_done', tostring(stepNow()))
hold(true)
for k = 1, 16 do
	walkTo(0, -6 - k * 1.5)
	if (P:GetAttribute('WaveLeft') or 1) == 0 and P:GetAttribute('WaveStage') == 1 then break end
end
local t2 = K
waitFor(function() keepPressing(); return (P:GetAttribute('WaveLeft') or 1) == 0 and (P:GetAttribute('RunCleared') or 0) >= 1 end, 25)
hold(false)
mark('run2_cleared', ('fight %.1f s'):format(K - t2))
wall(2)

---------------------------------------------------------------------------------------------------------- the flow checks (Oct 27)
waitFor(function() return FL.ready end, 12) -- (round 8: YOU'RE READY! within ~3 s of the tutorial's end, fight or not)
wall(1)
waitFor(function() keepPressing(); return P.PlayerGui:GetAttribute('HudShown_Offers') == true end, 12) -- (the offers come after it)
pcall(revealTrack)
local FLN, FLF = 0, {}
local function fcheck(name, ok, detail)
	FLN += 1
	if not ok then table.insert(FLF, name) end
	log(('[flow] CHECK %s %s%s'):format(ok and 'ok  ' or 'FAIL', name, detail and (' (' .. tostring(detail) .. ')') or ''))
end
local GoalRulesF = require(RS.Shared.GoalRules)
fcheck('welcome: shown on the first join, with the name', WEL.seen and WEL.text:find('WELCOME TO THE BLOCK') ~= nil and WEL.text:upper():find(string.upper(P.DisplayName ~= '' and P.DisplayName or P.Name), 1, true) ~= nil, WEL.text)
fcheck('welcome: 3-4 s, then the camera is the kid\'s again', WEL.k ~= nil and WEL.k >= 2.8 and WEL.k <= 5 and WEL.camBack == true, ('%.1f s, camera back %s'):format(WEL.k or -1, tostring(WEL.camBack)))
fcheck('welcome: the tutorial waits for it', not WEL.hintDuring)
fcheck('BAY 1: the kid trains to Stage 1\'s Power before the door step', POWER_AT_DOOR ~= nil and POWER_AT_DOOR >= GoalRulesF.FirstPower, ('Power %s at the door step, needs %d'):format(tostring(POWER_AT_DOOR), GoalRulesF.FirstPower))
fcheck('BAY 1: the first goal speaks Power', GoalRulesF.List[1].Text:find('Power') ~= nil, GoalRulesF.List[1].Text)
fcheck('BAY 1: the Power count gets its box', FL.powerBox)
fcheck('tutorial: its goals complete quietly (no GOAL DONE while it runs)', FL.goalDoneInTut == 0, FL.goalDoneInTut .. ' ticks')
fcheck('tutorial: the goal line waits while it runs', FL.goalLineInTut == 0, FL.goalLineInTut .. ' ticks')
fcheck('tutorial: ends on one YOU\'RE READY! moment', FL.ready)
fcheck('YOU\'RE READY!: within 3 s of the tutorial\'s end, saying what\'s next', FL.readyAt ~= nil and FL.doneAt ~= nil and FL.readyAt - FL.doneAt <= 3.5 and FL.readyLead == GoalRulesF.readyLine(1),
	('%s s after Done, "%s"'):format(FL.readyAt and FL.doneAt and ('%.1f'):format(FL.readyAt - FL.doneAt) or '?', tostring(FL.readyLead)))
fcheck('welcome: the whole HUD waits for it, then comes back at once', WEL.hudOn == 0 and WEL.otherOn == 0 and WEL.hudBack ~= nil and WEL.hudBack <= 1, ('HUD on %d ticks, goal screen on %d ticks, back after %s s'):format(WEL.hudOn, WEL.otherOn, tostring(WEL.hudBack)))
do
	local early, missing, shown = {}, {}, {}
	for part, n in FL.revealEarly do table.insert(early, part .. ' ' .. n) end
	for _, part in HudRevealF.All do
		local on = P.PlayerGui:GetAttribute('HudShown_' .. part) == true
		if on then table.insert(shown, part) end
		if FL.revealWant[part] and not on then table.insert(missing, part) end
	end
	local news = {}
	for name in FL.newSeen do table.insert(news, name) end
	table.sort(news)
	fcheck('calm first screen: no Robux offer until YOU\'RE READY!, then they slide in', FL.offersEarly == 0 and P.PlayerGui:GetAttribute('HudShown_Offers') == true, ('%d ticks early; shown now: %s'):format(FL.offersEarly, table.concat(shown, ',')))
	fcheck('calm first screen: each button comes when it first matters, with its NEW!', #early == 0 and #missing == 0 and FL.newSeen.Shoes == true, ('early: %s; missing: %s; NEW! on: %s'):format(table.concat(early, ','), table.concat(missing, ','), table.concat(news, ',')))
end
fcheck('Stage 1: CREW INCOMING!', FL.crew)
fcheck('first gun: its own moment (NEW GUN!, the name, x2 POWER PER SHOT)', FL.reveal ~= nil and FL.reveal:find('NEW GUN') ~= nil and FL.reveal:upper():find('X2 POWER PER SHOT', 1, true) ~= nil and (FL.hintOverReveal or 0) <= 3, tostring(FL.reveal) .. ('; the hint over it %d ticks (its 0.3 s fade at most)'):format(FL.hintOverReveal or 0))
fcheck('one voice: never two popups at once', #FL.overlap == 0, table.concat(FL.overlap, ', '):sub(1, 200))
local worst = math.huge
for _, g in FL.gaps do worst = math.min(worst, g[1]) end
fcheck('one voice: a calm of at least 1.5 s between two moments', worst >= 1.4, (#FL.gaps == 0 and 'no two moments' or ('%.2f s at the least, %d gaps'):format(worst, #FL.gaps)))
fcheck('one guide at a time', FL.guides2 == 0, FL.guides2 .. ' ticks with two, first ' .. tostring(FL.guidePair))
fcheck('no level toast in the first minute', FL.levelToastEarly == 0, FL.levelToastEarly .. ' ticks')
log(('[flow] %d checks / %d failed'):format(FLN, #FLF))
log('[flow] moments: ' .. (function() local t = {}; for _, mm in FL.moments do table.insert(t, ('%s %.1f'):format(mm[1], mm[2])) end; return table.concat(t, ' | ') end)())

---------------------------------------------------------------------------------------------------------- the HOOK timeline
local function firstOf(pred, after)
	for _, e in EV do if e.t >= (after or 0) and pred(e) then return e end end
	return nil
end
local function fmt(e) return e and ('%5.1fs  %s'):format(e.t, e.text) or '  ---   never' end
local SC = {}
local function sc(label, e, limit)
	local verdict = e and (e.t <= limit and 'ok' or 'LATE') or 'MISSING'
	table.insert(SC, ('%-38s %-64s [%s, target %ds]'):format(label, fmt(e):sub(1, 64), verdict, limit))
end
local resp = firstOf(function(e) return e.t >= CLICK_AT and ((e.kind == 'input' and e.text:find('sends')) or e.kind == 'fx' or e.kind == 'sound' or (e.kind == 'gun' and e.text ~= 'in hand: none')) end, CLICK_AT)
sc('1. first response to input (click)', resp and { t = resp.t - CLICK_AT, text = resp.text .. (' (%.2f s after the click)'):format(resp.t - CLICK_AT) } or nil, 1)
sc('2. first reward (Cash / GOAL DONE / gift)', firstOf(function(e) return (e.kind == 'cash' and e.text:find('%(%+')) or (e.kind == 'text' and e.text:upper():find('GOAL DONE')) end), 10)
sc('3. first visible Power number', firstOf(function(e) return (e.kind == 'fx' and (e.text:find('popNumber') or e.text:find('combo'))) or e.kind == 'power' end), 5)
sc('4. first upgrade (shoes / gun)', firstOf(function(e) return e.kind == 'gift' and e.text:find('opens') or (e.kind == 'attr' and e.text:find('^EquippedGun') and e.t > 2) end), 30)
sc('5. first goon in sight', firstOf(function(e) return e.kind == 'goon' end), 20)
sc('6. first gate walked through', firstOf(function(e) return e.kind == 'gate' end), 20)
sc('7. first Cash pad', firstOf(function(e) return e.kind == 'server' and e.text:find('CashOut') end), 30)
sc('8. first fight over (crew down)', firstOf(function(e) return e.kind == 'server' and e.text:find('WaveState Cleared') end), 90)
-- Boredom: gaps of more than 5 s with nothing new (walking alone is nothing new; the running Power counter isn't new
-- either, only its milestones are).
local gaps, prev = {}, 0
local REWARDS = 0
for _, e in EV do
	if e.kind ~= 'attr' or not e.text:find('^WaveStage') then
		if e.t - prev > 5 then table.insert(gaps, ('%5.1fs -> %5.1fs  (%.1f s with nothing new; next: %s)'):format(prev, e.t, e.t - prev, e.text:sub(1, 60))) end
		prev = e.t
	end
end
-- Reward rhythm in the first 30 s: the moments a kid would call a reward (Cash, a goal, Power milestones, a KO, a gate
-- opening, a pad, the gift, a gun) per 5-s window.
local function rewardish(e)
	return (e.kind == 'cash' and e.text:find('%(%+')) or (e.kind == 'text' and e.text:upper():find('GOAL DONE')) or (e.kind == 'power')
		or (e.kind == 'server' and (e.text:find('KO') or e.text:find('Cinematic') or e.text:find('Cleared'))) or e.kind == 'gift' or e.kind == 'gate'
		or (e.kind == 'attr' and e.text:find('^EquippedGun')) or e.kind == 'callout' or (e.kind == 'fx' and e.text:find('popNumber'))
		or (e.kind == 'text' and e.text:find('^HoodUnboxing'))
end
local windows = {}
for w = 0, 5 do windows[w] = {} end
for _, e in EV do
	if e.t < 30 and rewardish(e) then
		local w = math.floor(e.t / 5)
		table.insert(windows[w], e.text:sub(1, 26))
		REWARDS += 1
	end
end
log('HOOK TIMELINE (K = kid seconds from the spawn; a fresh save; the kid follows the guidance):')
for _, l in SC do log('  ' .. l) end
log('  milestones: ' .. (function()
	local t = {}
	for _, k in { 'step_train', 'in_bay1', 'first_power', 'step_door', 'stage1_entered', 'at_crew', 'stage1_cleared', 'step_cash', 'cash_pad', 'step_gift', 'gift_opened', 'unboxing_over', 'step_after_gift', 'first_gun', 'step_run', 'run2_entered', 'step_done', 'run2_cleared' } do
		if MARK[k] then table.insert(t, ('%s %.1f'):format(k, MARK[k])) end
	end
	return table.concat(t, ' | ')
end)())
log('REWARD RHYTHM, first 30 s (per 5-s window):')
for w = 0, 5 do log(('  %2d-%2ds  %d  %s'):format(w * 5, w * 5 + 5, #windows[w], table.concat(windows[w], ' ; '))) end
log('BORED? (gaps > 5 s with nothing new):' .. (#gaps == 0 and ' none' or ''))
for _, g in gaps do log('  ' .. g) end
log(('purchase prompts during the run: %d'):format(#(_G.__prompts or {})))
for _, p in _G.__prompts or {} do log('  prompt ' .. tostring(p[1]) .. ' ' .. tostring(p[2])) end
log('EVENTS (whole run):')
for _, e in EV do log(('  %5.1f %-8s %s'):format(e.t, e.kind, e.text)) end
log('script failures: ' .. (#FAILED > 0 and table.concat(FAILED, ' ;; ') or 'none'))
log('ISSUES: ' .. #ISSUES)
for i, s in ISSUES do log(('  %d. %s'):format(i, s)) end
log('final state: ' .. state() .. ' Onboarding=' .. __serde.encode('json', data.Onboarding))
__fs.writeFile(REPORT_DIR .. '/first30_report.txt', table.concat(REP, '\n') .. '\n')
if EXPORT then __fs.writeFile(EXPORT .. '/manifest.json', __serde.encode('json', SHOTS)) end
return { lines = #REP, issues = #ISSUES }
