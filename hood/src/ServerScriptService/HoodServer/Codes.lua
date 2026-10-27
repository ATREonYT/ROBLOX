-- The Store's codes (brief 27, video A's "Codes" box): the list and the rules. Server only on purpose: it lives in
-- HoodServer, not in ReplicatedStorage, so a code nobody has announced yet can't be read from the client.
-- HoodServer/CodesService answers the Store's REDEEM through the RedeemCode remote with Codes.redeem; the unit tests
-- (UnitTest/Cases/Codes_Test) run the same functions.
--
-- WHAT THE OWNER EDITS: Codes.List. Each code gives ONE small gift, once per player, saved in the profile (Codes =
-- { [CODE] = os.time it was used }):
--   Code     capital letters and digits only (players can type it in any case, with spaces: "hood launch" works)
--   Cash     Cash to add                                                       } one of the two
--   Boost    a timed Power boost level (2 = 2x Power) for Minutes minutes     }
--   Ends     optional os.time after which the code no longer works ("This code has ended")
--   Off      optional true: switched off for now (it answers like an unknown code)
-- Keep the gifts small (Codes.MaxCash, Codes.MaxMinutes: a unit test checks them) so codes never beat buying or playing.
local Codes = {}

Codes.List = {
	{ Code = 'HOODLAUNCH', Cash = 500 },
	{ Code = 'SNEAKERHEAD', Boost = 2, Minutes = 10 },
	{ Code = 'BLOCKPARTY', Cash = 1000 },
	{ Code = 'FRESHKICKS', Boost = 2, Minutes = 15 },
}
Codes.MaxLength = 20 -- characters a typed code may have (spaces included) before it is refused without a lookup
Codes.MaxCash = 2000
Codes.MaxMinutes = 30
Codes.Kept = 200 -- codes remembered per profile at most (old entries go first)
Codes.Burst, Codes.PerSecond = 4, 0.5 -- the rate limit: 4 tries, then one every 2 s

-- Kid-safe answers, all in one place.
Codes.Text = {
	empty = 'Type a code first!',
	unknown = "That code doesn't work. Check the spelling!",
	used = 'You already used this code!',
	ended = 'This code has ended. Watch for new ones!',
	slow = 'Slow down a little, then try again.',
	loading = 'Still loading, try again in a moment.',
	busy = 'Codes are resting. Try again soon!',
}

-- The code as stored: trimmed, spaces and dashes taken out, capital letters. nil for anything that can't be a code
-- (not text, too long, other characters).
function Codes.normalize(text)
	if type(text) ~= 'string' or #text == 0 or #text > Codes.MaxLength then return nil end
	local s = string.upper((string.gsub(text, '[%s%-_]', '')))
	if s == '' or not string.match(s, '^[A-Z0-9]+$') then return nil end
	return s
end

Codes.ByCode = {}
for _, e in Codes.List do Codes.ByCode[e.Code] = e end

-- What a code gives, in words ("+500 Cash", "2x Power for 10 minutes").
function Codes.rewardText(e)
	if type(e.Cash) == 'number' then return '+' .. tostring(e.Cash) .. ' Cash' end
	return tostring(e.Boost) .. 'x Power for ' .. tostring(e.Minutes) .. ' minutes'
end

-- The profile's used codes, cleaned: a table of CODE -> os.time (numbers), at most Codes.Kept (the oldest dropped).
function Codes.sanitize(used)
	local out = {}
	if type(used) ~= 'table' then return out end
	local list = {}
	for k, v in used do
		if type(k) == 'string' and #k <= 32 and string.match(k, '^[A-Z0-9]+$') and type(v) == 'number' and v == v and v >= 0 and v < 1e11 then
			table.insert(list, { k, v })
		end
	end
	table.sort(list, function(a, b) return a[2] > b[2] end)
	for i = 1, math.min(#list, Codes.Kept) do out[list[i][1]] = list[i][2] end
	return out
end

-- Redeems `text` on profile data (`data.Codes`, `data.Cash`, `data.Passes.Boost`) at os.time `now`. Checks everything
-- before anything changes; a code works once per profile. addBoost(boost, level, seconds, now) -> the new Boost table
-- (HoodServer/Boosts.add). Returns ok, the answer to show, and what changed ({ Cash = n } or { Boost = level, Seconds }).
function Codes.redeem(data, text, now, addBoost)
	local code = Codes.normalize(text)
	if type(text) ~= 'string' or string.match(text, '^%s*$') then return false, Codes.Text.empty end
	local e = code and Codes.ByCode[code]
	if not e or e.Off then return false, Codes.Text.unknown end
	if type(e.Ends) == 'number' and now > e.Ends then return false, Codes.Text.ended end
	data.Codes = Codes.sanitize(data.Codes)
	if data.Codes[code] then return false, Codes.Text.used end
	local change
	if type(e.Cash) == 'number' then
		local cash = tonumber(data.Cash) or 0
		data.Cash = math.min(1e12, cash + e.Cash)
		change = { Cash = e.Cash }
	else
		local seconds = math.floor(e.Minutes * 60)
		local passes = type(data.Passes) == 'table' and data.Passes or {}
		local boost = addBoost(passes.Boost, e.Boost, seconds, now) -- (pure: asserts before any change)
		passes.Boost = boost
		data.Passes = passes
		change = { Boost = e.Boost, Seconds = seconds }
	end
	data.Codes[code] = now
	return true, 'Code redeemed! ' .. Codes.rewardText(e), change
end

return Codes
