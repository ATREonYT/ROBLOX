--!strict
-- New Game Kit: Wallet (vault "Realistic City RP/02 Economy, Jobs, Stores and Inventory")
-- Install: ServerScriptService/Kit/Wallet (ModuleScript). Pure logic: no Instances, no remotes.
--
-- City money in two pockets, the way every realistic RP game splits it:
--   cash  = in your pocket: shown big on the HUD, spent at counters, part of it drops when you're knocked out
--   bank  = safe: paychecks land here, card payments come from here, never drops
--
--   local w = Wallet.new(profile.Data.Wallet)   -- wraps the saved table { cash, bank, ledger }
--   Wallet.Earn(w, 120, "Paycheck", now)        -> ok, reason   (into the bank, capped per reason)
--   Wallet.Pay(w, 450, "card", "Dealer", now)   -> ok, reason   ("cash", "card" or "any": cash first)
--   Wallet.Deposit(w, 500, now) / Wallet.Withdraw(w, 500, now)  (only at an ATM or bank: the caller checks the place)
--   Wallet.Transfer(a, b, 200, now)             -> ok, reason   (phone bank app; daily cap stops alt-account funnels)
--   Wallet.KnockoutDrop(w, now)                 -> amount dropped from CASH only (a pickup in the world)
--
-- Rules every function follows (vault Sector Brief "Saving, Economy and Monetization"):
--   * amounts are whole, positive, finite and below Rules.maxTransaction, or the call is refused
--   * no balance ever goes below 0 or above Rules.maxBalance
--   * every change appends one ledger line (last Rules.ledgerSize kept) so support can answer "where did my money go?"
--   * the CLIENT never sends an amount it wants to receive. It asks for an action; the server prices it.
-- Status: covered by tests/Wallet.spec.luau (offline).

local Wallet = {}

Wallet.Rules = {
	maxTransaction = 10_000_000,
	maxBalance = 1_000_000_000_000, -- well inside the 2^53 safe-integer range
	ledgerSize = 50,
	knockoutDropPercent = 0.10, -- 10% of pocket cash drops when knocked out...
	knockoutDropMax = 5_000, -- ...but never more than this (keeps rage-quits rare)
	transferDailyCap = 50_000, -- phone transfers per player per 24 h
	-- per-reason earning caps per rolling hour: a bug or exploit in one job can't print money
	earnCapsPerHour = {
		Paycheck = 20_000,
		Job = 40_000,
		Pickup = 50_000,
		Refund = 1_000_000,
	} :: { [string]: number },
}

export type Line = { t: number, kind: string, amount: number, pocket: string, note: string? }
export type Data = {
	cash: number,
	bank: number,
	ledger: { Line }?,
	earned: { [string]: { start: number, total: number } }?,
	sent: { start: number, total: number }?,
}

local function validAmount(amount: any): (boolean, string)
	if type(amount) ~= "number" or amount ~= amount or amount == math.huge or amount == -math.huge then
		return false, "BadAmount"
	end
	if amount <= 0 or amount % 1 ~= 0 then
		return false, "BadAmount"
	end
	if amount > Wallet.Rules.maxTransaction then
		return false, "TooBig"
	end
	return true, "Ok"
end

local function log(w: Data, now: number, kind: string, amount: number, pocket: string, note: string?)
	local ledger = w.ledger
	if not ledger then
		ledger = {}
		w.ledger = ledger
	end
	local list = ledger :: { Line }
	table.insert(list, { t = now, kind = kind, amount = amount, pocket = pocket, note = note })
	while #list > Wallet.Rules.ledgerSize do
		table.remove(list, 1)
	end
end

-- Wraps (and repairs) a saved wallet table. Missing or corrupt numbers become 0.
function Wallet.new(saved: any): Data
	local w = if type(saved) == "table" then saved else {}
	for _, key in { "cash", "bank" } do
		local v = w[key]
		if type(v) ~= "number" or v ~= v or v < 0 or v == math.huge then
			w[key] = 0
		else
			w[key] = math.floor(v)
		end
	end
	return w :: Data
end

function Wallet.Total(w: Data): number
	return w.cash + w.bank
end

-- Earn into a pocket ("bank" by default), within the per-reason hourly cap.
function Wallet.Earn(w: Data, amount: number, reason: string, now: number, pocket: string?): (boolean, string)
	local ok, why = validAmount(amount)
	if not ok then
		return false, why
	end
	local cap = Wallet.Rules.earnCapsPerHour[reason]
	if cap == nil then
		return false, "UnknownReason" -- every faucet must be named in Rules, so it is visible and capped
	end
	local earned: { [string]: { start: number, total: number } } = w.earned or {}
	w.earned = earned
	local book = earned[reason]
	if not book or now - book.start >= 3600 then
		book = { start = now, total = 0 }
		earned[reason] = book
	end
	if book.total + amount > cap then
		return false, "CapReached"
	end
	local into = pocket or "bank"
	if into ~= "bank" and into ~= "cash" then
		return false, "BadPocket"
	end
	local current = if into == "bank" then w.bank else w.cash
	if current + amount > Wallet.Rules.maxBalance then
		return false, "Full"
	end
	book.total += amount
	if into == "bank" then
		w.bank += amount
	else
		w.cash += amount
	end
	log(w, now, reason, amount, into)
	return true, "Ok"
end

-- Pay at a counter. method: "cash", "card" (bank) or "any" (cash first, then card).
function Wallet.Pay(w: Data, amount: number, method: string, note: string?, now: number?): (boolean, string)
	local ok, why = validAmount(amount)
	if not ok then
		return false, why
	end
	local t = now or 0
	if method == "cash" then
		if w.cash < amount then
			return false, "NotEnoughCash"
		end
		w.cash -= amount
		log(w, t, "Pay", -amount, "cash", note)
	elseif method == "card" then
		if w.bank < amount then
			return false, "NotEnoughBank"
		end
		w.bank -= amount
		log(w, t, "Pay", -amount, "bank", note)
	elseif method == "any" then
		if w.cash + w.bank < amount then
			return false, "NotEnough"
		end
		local fromCash = math.min(w.cash, amount)
		local fromBank = amount - fromCash
		w.cash -= fromCash
		w.bank -= fromBank
		if fromCash > 0 then
			log(w, t, "Pay", -fromCash, "cash", note)
		end
		if fromBank > 0 then
			log(w, t, "Pay", -fromBank, "bank", note)
		end
	else
		return false, "BadMethod"
	end
	return true, "Ok"
end

function Wallet.Deposit(w: Data, amount: number, now: number): (boolean, string)
	local ok, why = validAmount(amount)
	if not ok then
		return false, why
	end
	if w.cash < amount then
		return false, "NotEnoughCash"
	end
	if w.bank + amount > Wallet.Rules.maxBalance then
		return false, "Full"
	end
	w.cash -= amount
	w.bank += amount
	log(w, now, "Deposit", amount, "bank")
	return true, "Ok"
end

function Wallet.Withdraw(w: Data, amount: number, now: number): (boolean, string)
	local ok, why = validAmount(amount)
	if not ok then
		return false, why
	end
	if w.bank < amount then
		return false, "NotEnoughBank"
	end
	if w.cash + amount > Wallet.Rules.maxBalance then
		return false, "Full"
	end
	w.bank -= amount
	w.cash += amount
	log(w, now, "Withdraw", amount, "cash")
	return true, "Ok"
end

-- Bank-to-bank between two LOADED players on the same server (cross-server needs a
-- MessagingService handshake and an idempotent receipt; see note 10). Daily cap per sender.
function Wallet.Transfer(from: Data, to: Data, amount: number, now: number): (boolean, string)
	if from == to then
		return false, "Self"
	end
	local ok, why = validAmount(amount)
	if not ok then
		return false, why
	end
	local sent = from.sent
	if not sent or now - sent.start >= 86400 then
		sent = { start = now, total = 0 }
		from.sent = sent
	end
	local s = sent :: { start: number, total: number }
	if s.total + amount > Wallet.Rules.transferDailyCap then
		return false, "DailyCap"
	end
	if from.bank < amount then
		return false, "NotEnoughBank"
	end
	if to.bank + amount > Wallet.Rules.maxBalance then
		return false, "Full"
	end
	from.bank -= amount
	to.bank += amount
	s.total += amount
	log(from, now, "TransferOut", -amount, "bank")
	log(to, now, "TransferIn", amount, "bank")
	return true, "Ok"
end

-- When a player is knocked out: part of the pocket cash drops (the caller spawns a pickup
-- that anyone can grab for Rules-limited time). Bank money never drops.
function Wallet.KnockoutDrop(w: Data, now: number): number
	local drop = math.floor(w.cash * Wallet.Rules.knockoutDropPercent)
	drop = math.min(drop, Wallet.Rules.knockoutDropMax)
	if drop <= 0 then
		return 0
	end
	w.cash -= drop
	log(w, now, "KnockoutDrop", -drop, "cash")
	return drop
end

return Wallet
