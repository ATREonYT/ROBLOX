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
untilStep('Door', 12)
mark('step_door', ('Power %d'):format(data.Rep))
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
