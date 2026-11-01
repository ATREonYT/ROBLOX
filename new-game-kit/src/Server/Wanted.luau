--!strict
-- New Game Kit: Wanted (vault "Realistic City RP/08 Crime, Police and Wanted Levels")
-- Install: ServerScriptService/Kit/Wanted (ModuleScript). Pure logic: no Instances, no remotes.
--
-- Heat, not a switch. Each crime the SERVER saw adds heat; heat makes stars (0-5); stars fade
-- when no officer has seen you for a while. Police see stars on the map; arrest needs stars.
--
--   local w = Wanted.new(pickedCrimeRole, now)
--   Wanted.Crime(w, "Robbery", now)           -> stars
--   Wanted.Seen(w, now)                       -- an officer had line of sight: the fade timer restarts
--   Wanted.Stars(w, now)                      -> stars after fading
--   Wanted.CanArrest(w, now, distance, copIsOnDuty) -> ok, reason
--   Wanted.Bounty(w, now)                     -> cash an officer earns for the arrest
--   Wanted.JailSeconds(w, now)                -> seconds (clamped by Roleplay.JailSeconds, 10-60 s)
--   Wanted.Clear(w)                           -- after jail, death or paying a fine
--
-- Opt-in only: only a player who picked a crime role can gain heat (Blueprint - Roleplay Town §5).
-- Status: covered by tests/Wanted.spec.luau (offline).

local Wanted = {}

Wanted.Crimes = {
	Trespass = 10,
	Speeding = 5,
	Assault = 25, -- knocking out a player who is not in a crime role
	Robbery = 45, -- a store register
	CarTheft = 30,
	BankJob = 100, -- straight to 5 stars
} :: { [string]: number }

Wanted.Rules = {
	heatPerStar = 20, -- 20 heat = 1 star ... 100 = 5 stars
	maxHeat = 100,
	fadeAfter = 45, -- seconds unseen before heat starts fading
	fadePerSecond = 1, -- 20 s per star once fading
	arrestRange = 8,
	bountyPerStar = 150,
	jailPerStar = 12, -- 1 star = 12 s ... 5 stars = 60 s
}

export type State = { heat: number, quietSince: number, settledAt: number, criminal: boolean }

function Wanted.new(isCriminalRole: boolean?, now: number?): State
	local t = now or 0
	return { heat = 0, quietSince = t, settledAt = t, criminal = isCriminalRole == true }
end

-- Applies fading up to `now`. Heat only fades after Rules.fadeAfter seconds of quiet
-- (no crime and no officer sighting), then at Rules.fadePerSecond.
local function settle(w: State, now: number)
	local from = math.max(w.quietSince + Wanted.Rules.fadeAfter, w.settledAt)
	if now > from and w.heat > 0 then
		w.heat = math.max(0, w.heat - (now - from) * Wanted.Rules.fadePerSecond)
	end
	w.settledAt = math.max(w.settledAt, now)
end

function Wanted.Stars(w: State, now: number): number
	settle(w, now)
	return math.clamp(math.ceil(w.heat / Wanted.Rules.heatPerStar - 1e-9), 0, 5)
end

function Wanted.Crime(w: State, kind: string, now: number): number
	if not w.criminal then
		return Wanted.Stars(w, now)
	end
	local heat = Wanted.Crimes[kind]
	if not heat then
		return Wanted.Stars(w, now)
	end
	settle(w, now)
	w.heat = math.min(Wanted.Rules.maxHeat, w.heat + heat)
	w.quietSince = now
	return Wanted.Stars(w, now)
end

function Wanted.Seen(w: State, now: number)
	settle(w, now)
	w.quietSince = now
end

function Wanted.CanArrest(w: State, now: number, distance: number, copIsOnDuty: boolean): (boolean, string)
	if not copIsOnDuty then
		return false, "NotPolice"
	end
	if Wanted.Stars(w, now) <= 0 then
		return false, "NotWanted"
	end
	if distance > Wanted.Rules.arrestRange then
		return false, "TooFar"
	end
	return true, "Ok"
end

function Wanted.Bounty(w: State, now: number): number
	return Wanted.Stars(w, now) * Wanted.Rules.bountyPerStar
end

function Wanted.JailSeconds(w: State, now: number): number
	return math.clamp(Wanted.Stars(w, now) * Wanted.Rules.jailPerStar, 10, 60)
end

function Wanted.Clear(w: State)
	w.heat = 0
end

return Wanted
