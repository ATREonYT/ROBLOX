--!strict
-- Liberty OS "Bank" app, server half (registered by DeskService). Clean cash <-> bank account, plus the last money
-- moves this session so the player can see where their money comes from (the "statement").
--   state              -> { cash, bank, recent = {{ at, delta, reason }...}, today = { earned, spent } }
--   deposit { amount } -> moves clean cash into the bank
--   withdraw { amount }-> moves bank money back to cash
-- Moves are not income or spending: they go through EconomyService.transfer (no 2x, no "+$" pop, no Stats).
-- Wiring note: EconomyService.transfer(player, delta, reason) is added with this feature; the fallback below keeps
-- this working on an EconomyService without it.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local OS = require(ReplicatedStorage.MTL.Config.OS)
local DataService = require(script.Parent.DataService)
local EconomyService = require(script.Parent.EconomyService)

local BankService = {}

type Move = { at: number, delta: number, reason: string }
local recent: { [Player]: { Move } } = {}
local today: { [Player]: { earned: number, spent: number } } = {}
local moving: { [Player]: boolean } = {} -- our own transfers don't show up as income/spending

-- Plain-English names for the reasons services already pass to EconomyService (unknown ones show as-is).
local REASON: { [string]: string } = {
	CoinBuy = "CoinBay buy",
	CoinSell = "CoinBay sale",
	HomeUpgrade = "Home upgrade",
	PowerBill = "Power bill",
	BankDeposit = "Deposit",
	BankWithdraw = "Withdrawal",
}

local function log(p: Player, delta: number, reason: string)
	local list = recent[p]
	if not list then
		list = {}
		recent[p] = list
	end
	table.insert(list, 1, { at = os.time(), delta = delta, reason = REASON[reason] or reason })
	while #list > OS.Bank.Recent do
		table.remove(list)
	end
	if not moving[p] then
		local t = today[p] or { earned = 0, spent = 0 }
		today[p] = t
		if delta > 0 then
			t.earned += delta
		else
			t.spent -= delta
		end
	end
end

local function transfer(player: Player, delta: number, reason: string): boolean
	local E: any = EconomyService
	moving[player] = true
	local ok = false
	if E.transfer then
		ok = E.transfer(player, delta, reason)
	elseif delta < 0 then
		ok = EconomyService.spend(player, -delta, reason)
	else
		ok = EconomyService.addCash(player, delta, reason, false) > 0
	end
	moving[player] = nil
	return ok
end

local function state(player: Player): any
	local d = DataService.get(player)
	if not d then
		return { ok = false, err = "Still loading" }
	end
	return { ok = true, cash = d.Cash, bank = d.Bank or 0, recent = recent[player] or {}, today = today[player] or { earned = 0, spent = 0 } }
end

local function amountOf(args: any): number
	local n = if type(args) == "table" then tonumber(args.amount) else nil
	if not n or n ~= n then
		return 0
	end
	return math.floor(n)
end

function BankService.handle(player: Player, action: string, args: any): any
	local d = DataService.get(player)
	if not d then
		return { ok = false, err = "Still loading" }
	end
	if action == "state" then
		return state(player)
	elseif action == "deposit" then
		local n = amountOf(args)
		if n < OS.Bank.MinMove then
			return { ok = false, err = "Enter an amount" }
		end
		if d.Cash < n then
			return { ok = false, err = "You only have $" .. d.Cash .. " on you" }
		end
		if not transfer(player, -n, "BankDeposit") then
			return { ok = false, err = "Deposit failed" }
		end
		d.Bank = (d.Bank or 0) + n
		DataService.push(player)
		return state(player)
	elseif action == "withdraw" then
		local n = amountOf(args)
		if n < OS.Bank.MinMove then
			return { ok = false, err = "Enter an amount" }
		end
		if (d.Bank or 0) < n then
			return { ok = false, err = "Not enough in the bank" }
		end
		d.Bank -= n
		if not transfer(player, n, "BankWithdraw") then
			d.Bank += n
			return { ok = false, err = "Withdrawal failed" }
		end
		DataService.push(player)
		return state(player)
	end
	return { ok = false, err = "Unknown action" }
end

function BankService.init(_desk: any)
	EconomyService.CashChanged:Connect(function(p: Player, _new: number, delta: number, reason: string)
		if delta ~= 0 then
			log(p, delta, reason)
		end
	end)
	Players.PlayerRemoving:Connect(function(p)
		recent[p] = nil
		today[p] = nil
		moving[p] = nil
	end)
end

return BankService
