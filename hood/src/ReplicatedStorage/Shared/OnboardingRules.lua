-- The first-session guidance (HOOK, brief 23: "hooked in 30 seconds"). Pure rules, shared by HoodServer/
-- OnboardingService (which decides and saves) and HoodClient/Onboarding (which shows), unit-tested in
-- UnitTest/Cases/Onboarding_Test. The design is brief/out23/HOOK/first30.md.
--
-- The steps a new player walks through, one at a time (player attribute OnboardingStep):
--   Train  in the lobby, under Stage 1's Power: to BAY 1 (LOBBY5's floor guide draws this one)
--   Door   trained: out through the Stage 1 door (LOBBY5's guide again)
--   Fight  in a stage while its crew stands
--   Cash   the crew is down: step on the yellow pad (+Cash, home)
--   Gift   back in the lobby after beating a crew: the welcome present (2 pairs from the Street box, once ever)
--   Gun    the gift is open and a first gun is affordable: the ARMORY pad
--   Run    back out to Stage 1 with the new gear
--   Done   run 2 has begun (or a rebirth, or a returning player who was already past the opening): the goal chain
--          carries on alone
-- Saved, inside the profile's existing Onboarding table (no schema change: ProfileSchema keeps it as a table):
--   Gift = true once the welcome present was given; Done = true once the guidance is over; Seconds = seconds played
--   while onboarding (for the quiet window), capped at MaxSeconds.
-- The quiet window: for a new player's first QuietSeconds of play nothing opens a purchase prompt by itself
-- (OnboardingQuiet = true; StageService's 10x pad and LobbyService's Robux lanes check it). Purchases the player
-- starts (a Store card, an E on a Robux box) are theirs to make.
local OnboardingRules = {}

OnboardingRules.QuietSeconds = 300 -- no automatic purchase prompts for a new player's first 5 minutes of play
OnboardingRules.MaxSeconds = 3600 -- (Seconds stops counting here)
OnboardingRules.GiftBox = 'Street' -- the welcome present: pairs from this Cash box, at its normal odds (ECON agreed)
OnboardingRules.GiftCount = 2 -- (2: one pair on the feet and one follower)
OnboardingRules.GiftOffset = Vector3.new(6, 0, -7) -- where the present waits, in the map frame from the lobby spawn
OnboardingRules.GiftRange = 4.5 -- studs (flat) from the present to your root that open it
OnboardingRules.GiftHeight = 7 -- and at most this far above or below it
OnboardingRules.StuckSeconds = 6 -- the timed hint: this long without getting closer to the target
OnboardingRules.StuckGain = 1 -- (studs closer that count as progress)
OnboardingRules.StuckRepeats = 2 -- (the hint shows at most this often per step: a nudge, never nagging)

OnboardingRules.Steps = { 'Train', 'Door', 'Fight', 'Cash', 'Gift', 'Gun', 'Run', 'Done' }
OnboardingRules.Index = {}
for i, s in OnboardingRules.Steps do OnboardingRules.Index[s] = i end

-- The one word each step says (the callout and the arrow over its target); no step needs reading more than this.
OnboardingRules.Words = { Train = 'TRAIN!', Door = 'GO!', Fight = 'FIGHT!', Cash = 'CASH!', Gift = 'GIFT!', Gun = 'GUN!', Run = 'GO!' }
-- The steps whose trail and arrow are the client's own (Train and Door are LOBBY5's floor guide; a fight needs none).
OnboardingRules.Guided = { Cash = true, Gift = true, Gun = true, Run = true }

local function num(v) return type(v) == 'number' and v == v and v or 0 end

-- The step for a state. Fields (missing = 0 / false):
--   Done, Gift      the saved flags
--   Rebirths        a rebirth ends the guidance
--   Power, Need     your Power and Stage 1's (the gate's Required; 10 when unknown)
--   Beaten          the best stage whose crew you ever beat (WaveCleared; StagesCleared on a map without crews)
--   WaveStage       the stage you are in (0 = the lobby), WaveLeft its goons still standing, RunCleared beaten this run
--   Guns, Cash, GunCost   guns owned, Cash, the cheapest gun you don't own yet (nil: none)
function OnboardingRules.step(s)
	s = type(s) == 'table' and s or {}
	if s.Done == true or num(s.Rebirths) > 0 then return 'Done' end
	local beaten = num(s.Beaten) >= 1
	if num(s.WaveStage) > 0 then
		if beaten and s.Gift == true then return 'Done' end -- (run 2 is on: the guidance has done its job)
		if num(s.WaveLeft) > 0 then return 'Fight' end
		if num(s.RunCleared) >= 1 then return 'Cash' end
		return 'Fight'
	end
	if not beaten then
		local need = num(s.Need) > 0 and num(s.Need) or 10
		return num(s.Power) < need and 'Train' or 'Door'
	end
	if s.Gift ~= true then return 'Gift' end
	local cost = s.GunCost
	if num(s.Guns) < 2 and type(cost) == 'number' and num(s.Cash) >= cost then return 'Gun' end
	return 'Run'
end

-- A returning player seen for the first time by this system: already past the opening (reborn, two crews beaten or
-- two gates passed, a second gun or a box opened) gets no guidance, no gift and no quiet window.
function OnboardingRules.veteran(s)
	s = type(s) == 'table' and s or {}
	return num(s.Rebirths) > 0 or num(s.Beaten) >= 2 or num(s.Stages) >= 2 or num(s.Guns) >= 2 or num(s.Boxes) >= 1
end

-- The saved table made safe: Gift and Done true or nil, Seconds a number in [0, MaxSeconds]; other keys (LobbyService's
-- Trained, RebirthService's Rebirthed) are kept as they are. Returns the same table (a new one for junk).
function OnboardingRules.sanitize(t)
	if type(t) ~= 'table' then t = {} end
	t.Gift = t.Gift == true or nil
	t.Done = t.Done == true or nil
	local secs = t.Seconds
	if type(secs) ~= 'number' or secs ~= secs then secs = 0 end
	t.Seconds = math.clamp(secs, 0, OnboardingRules.MaxSeconds)
	return t
end

-- Adds play time (seconds, >= 0) to the saved table, capped.
function OnboardingRules.tick(t, dt)
	dt = type(dt) == 'number' and dt == dt and math.max(0, dt) or 0
	t.Seconds = math.min(OnboardingRules.MaxSeconds, (t.Seconds or 0) + dt)
	return t.Seconds
end

-- Is the quiet window on for this saved table? (A veteran's is closed when first seen: Seconds = QuietSeconds.)
function OnboardingRules.quietFor(t)
	return type(t) == 'table' and num(t.Seconds) < OnboardingRules.QuietSeconds
end
-- For the other services: true while this player's automatic purchase prompts must wait (the attribute the server
-- keeps). Anything without the attribute is not quiet.
function OnboardingRules.quiet(player)
	local ok, v = pcall(function() return player:GetAttribute('OnboardingQuiet') end)
	return ok and v == true
end

-- Where the present waits: the lobby spawn (world position of the floor under it) plus GiftOffset in the map frame.
function OnboardingRules.giftSpot(spawn, frame)
	local offset = OnboardingRules.GiftOffset
	if typeof(frame) == 'CFrame' then offset = frame:VectorToWorldSpace(offset) end
	return spawn + offset
end
-- Close enough to open it (flat distance and height).
function OnboardingRules.atGift(position, gift)
	if typeof(position) ~= 'Vector3' or typeof(gift) ~= 'Vector3' then return false end
	local d = position - gift
	return Vector3.new(d.X, 0, d.Z).Magnitude <= OnboardingRules.GiftRange and math.abs(d.Y) <= OnboardingRules.GiftHeight
end

-- The cheapest gun with a price that you don't own yet: id, cost (nil when you own them all). `list` is
-- Config/Guns.List, `owned` a set { [id] = true }.
function OnboardingRules.nextGun(list, owned)
	owned = type(owned) == 'table' and owned or {}
	local best
	for _, g in type(list) == 'table' and list or {} do
		if type(g) == 'table' and num(g.Cost) > 0 and owned[g.Id] ~= true and (not best or g.Cost < best.Cost) then best = g end
	end
	if best then return best.Id, best.Cost end
	return nil, nil
end
-- 'Pistol,Revolver' (GunService's OwnedGuns attribute) -> { Pistol = true, Revolver = true }
function OnboardingRules.ownedSet(s)
	local set = {}
	if type(s) == 'string' then
		for id in s:gmatch('[^,%s]+') do set[id] = true end
	elseif type(s) == 'table' then
		for k, v in s do
			if v == true then set[k] = true elseif type(v) == 'string' then set[v] = true end
		end
	end
	return set
end

-- The callout when a better gun is in your hand: 'x2 POWER!'.
function OnboardingRules.gunWord(multiplier)
	local m = num(multiplier)
	if m <= 1 then return 'NEW GUN!' end
	return 'x' .. (m % 1 == 0 and string.format('%d', m) or string.format('%.1f', m)) .. ' POWER!'
end

-- The timed hint (for the stuck only): track = { Best, Since } per target. Call with the flat distance to the target
-- and the clock; returns true once the distance has not shrunk by StuckGain for StuckSeconds (and restarts the wait,
-- so the hint repeats at most every StuckSeconds).
function OnboardingRules.stuck(track, distance, now)
	if type(track) ~= 'table' or type(distance) ~= 'number' or type(now) ~= 'number' then return false end
	if track.Best == nil or distance < track.Best - OnboardingRules.StuckGain then
		track.Best, track.Since = distance, now
		return false
	end
	if now - (track.Since or now) >= OnboardingRules.StuckSeconds then
		track.Since = now
		return true
	end
	return false
end

-- Does a step change deserve a callout? Forward steps only, plus every new fight (a kid who runs on into Stage 2
-- hears "FIGHT!" again); Done says nothing.
function OnboardingRules.announce(from, to)
	if to == nil or to == from or to == 'Done' or not OnboardingRules.Words[to] then return nil end
	if to == 'Fight' then return OnboardingRules.Words.Fight end
	local a, b = OnboardingRules.Index[from or ''] or 0, OnboardingRules.Index[to] or 0
	if b <= a then return nil end
	return OnboardingRules.Words[to]
end

return OnboardingRules
