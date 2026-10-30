-- Daily login rewards (Config/DailyLogin): pure rules, so tests/LoginRules.spec.luau can check them. The save keeps
-- Login = { Count = rewards claimed so far, Last = the day number of the last claim }.
local DailyLogin = require(script.Parent.Config.DailyLogin)

local LoginRules = {}

function LoginRules.day(now: number): number
	return now // DailyLogin.DayLength
end

-- Which of the 7 days is next (1..7), and whether it can be claimed today.
function LoginRules.next(login: any, now: number): (number, boolean)
	local count = (type(login) == "table" and tonumber(login.Count)) or 0
	local last = type(login) == "table" and tonumber(login.Last)
	return count % #DailyLogin.Days + 1, last ~= LoginRules.day(now)
end

-- Seconds until the next day starts (the window's "next reward in").
function LoginRules.wait(now: number): number
	return DailyLogin.DayLength - now % DailyLogin.DayLength
end

-- Claims today's reward into `data` (changes it; a knife already in data.Cosmetics gives its Owned coins). Returns the day's
-- reward and what was given ("Knife" or the coins/Aura/spins kind; "Coins" for an owned knife), or nil and why.
function LoginRules.claim(data: any, now: number): (any, string?)
	data.Login = data.Login or {}
	local index, ready = LoginRules.next(data.Login, now)
	if not ready then return nil, "Come back tomorrow for the next reward." end
	local r = DailyLogin.Days[index]
	data.Cosmetics = data.Cosmetics or {}
	local given = r.Kind
	if r.Kind == "Coins" then data.Coins = (data.Coins or 0) + r.Amount
	elseif r.Kind == "Aura" then data.Aura = (data.Aura or 0) + r.Amount
	elseif r.Kind == "Spins" then data.Spins = (data.Spins or 0) + r.Amount
	elseif r.Kind == "Knife" then
		if data.Cosmetics[r.Id] then
			data.Coins = (data.Coins or 0) + (r.Owned or 0)
			given = "Coins"
		else
			data.Cosmetics[r.Id] = true
		end
	else
		return nil, "That reward can't be given yet."
	end
	data.Login.Count = (tonumber(data.Login.Count) or 0) + 1
	data.Login.Last = LoginRules.day(now)
	return r, given
end

return LoginRules
