--!strict
-- New Game Kit: Offers (vault note 21, money done the kid-safe way)
-- Install: ReplicatedStorage/Kit/Offers (ModuleScript). Pure logic: no prompts, no purchases.
--   Offers.Ladder(rungs)          -> bonus % labels computed from the real amounts, or an error
--                                    when a bigger pack is worse value (a trap players notice)
--   Offers.NetRobux(price, share) -> what a sale really earns (70%, regional prices lower it)
--   Offers.Bucket(userId, test)   -> a stable 0..99 bucket for A/B tests of timing and layout
--   Offers.CanShow(state, now)    -> may an UNASKED offer pop up now? (pacing rules in note 21 §4)
-- Purchases still go through Receipts (server, once per PurchaseId). Prices shown to players
-- come from GetProductInfoAsync, never from this file (regional pricing).
-- Status: covered by tests/Offers.spec.luau (offline).

local Offers = {}

export type Rung = { key: string, amount: number, price: number }

-- Pacing rules for offers the player did not ask for (note 21 §4). Asked-for shops are never limited.
Offers.Rules = {
	quietSeconds = 180, -- no unasked offer in the first 3 minutes of a player's first session
	gapSeconds = 8, -- never two pop-ups within 8 s (measured in LihFolk's reference project)
	perSessionNonPayer = 1, -- at most one unasked offer per session for someone who never bought
	perSessionPayer = 2,
	afterDecline = 600, -- after a "no thanks", wait 10 minutes before the next one
}

-- Checks a ladder of packs (smallest first) and returns { [key] = bonus % } computed from the numbers.
-- Errors when value per Robux does not rise, or when the top rung's extra bonus is bigger than the
-- step below it (that makes the middle packs look foolish).
function Offers.Ladder(rungs: { Rung }): { [string]: number }
	assert(#rungs > 0, "Offers.Ladder: empty ladder")
	local base = rungs[1].amount / rungs[1].price
	local labels = {}
	local previousValue, previousStep = 0, math.huge
	for i, rung in rungs do
		assert(rung.price > 0 and rung.amount > 0, `Offers.Ladder: {rung.key} needs a price and an amount`)
		local value = rung.amount / rung.price
		assert(i == 1 or value > previousValue, `Offers.Ladder: {rung.key} is worse value than the pack below it`)
		local bonus = math.floor((value / base - 1) * 100 + 0.5)
		if i > 2 then
			local step = bonus - labels[rungs[i - 1].key]
			assert(step <= previousStep, `Offers.Ladder: {rung.key} jumps more than the step below it`)
			previousStep = step
		elseif i == 2 then
			previousStep = bonus
		end
		labels[rung.key] = bonus
		previousValue = value
	end
	return labels
end

-- share: fraction of players paying the full price (the rest pay a regional price at `regional`).
function Offers.NetRobux(price: number, fullShare: number?, regional: number?): number
	local full = fullShare or 1
	local factor = full + (1 - full) * (regional or 1)
	return math.floor(0.7 * price * factor)
end

function Offers.Bucket(userId: number, test: string): number
	local h = 0
	for i = 1, #test do
		h = (h * 31 + string.byte(test, i)) % 2147483647
	end
	h = (h * 31 + userId) % 2147483647
	return h % 100
end

export type OfferState = {
	firstSession: boolean,
	sessionStart: number,
	isPayer: boolean,
	shownThisSession: number,
	lastShown: number?,
	lastDeclined: number?,
}

-- May an offer the player did not ask for appear right now? Returns (ok, reason).
function Offers.CanShow(state: OfferState, now: number): (boolean, string)
	local rules = Offers.Rules
	if state.firstSession and now - state.sessionStart < rules.quietSeconds then
		return false, "FirstMinutes"
	end
	if state.lastShown and now - state.lastShown < rules.gapSeconds then
		return false, "TooSoon"
	end
	if state.lastDeclined and now - state.lastDeclined < rules.afterDecline then
		return false, "JustDeclined"
	end
	local cap = if state.isPayer then rules.perSessionPayer else rules.perSessionNonPayer
	if state.shownThisSession >= cap then
		return false, "SessionCap"
	end
	return true, "Ok"
end

return Offers
