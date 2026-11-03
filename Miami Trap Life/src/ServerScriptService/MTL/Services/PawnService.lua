--!strict
-- Liberty Pawn & Thrift (Quality pass, Benchmark Gap List 2.8). See Config/Live.Pawn.
-- A walk-up counter at the thrift store on North Ave. Today it buys the goods you carried home from house licks
-- (the crime loop keeps them as a dollar value, CrimeService.fenceValue): Marcus pays 100% in DIRTY cash at the
-- Cash 4 Gold back door; the pawn pays 60% in CLEAN cash, no questions, no heat. Your call.
-- New loot types register themselves with PawnService.register(id, def) and show up as rows in the sell card.
--
-- Net PawnAction (C->S): {type="open"} -> LiveState {type="pawn", rows=...} | {type="sell", id} -> sells that row.
-- The server re-reads every value when you sell, so the client's numbers are only for showing.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Live = require(ReplicatedStorage.MTL.Config.Live)
local Net = require(ReplicatedStorage.MTL.Net)
local EconomyService = require(script.Parent.EconomyService)
local Notify = require(script.Parent.Notify)

local P = Live.Pawn
local PawnService = {}

export type Sellable = {
	title: string,
	blurb: string,
	value: (Player) -> number, -- what the pawn pays right now (0 = nothing to sell)
	take: (Player) -> number, -- removes the goods, returns what the pawn pays for them
	elsewhere: ((Player) -> string?)?, -- the other offer, for comparison ("Marcus pays $500 dirty")
}

local order: { string } = {}
local defs: { [string]: Sellable } = {}
local lastSell: { [Player]: number } = {}

local function log(...)
	print("[MTL Pawn]", ...)
end

function PawnService.register(id: string, def: Sellable)
	if not defs[id] then
		table.insert(order, id)
	end
	defs[id] = def
end

local function crime(): any?
	local m = script.Parent:FindFirstChild("CrimeService")
	if not m then
		return nil
	end
	local ok, svc = pcall(require, m)
	return if ok then svc else nil
end

local function rows(player: Player): { any }
	local out = {}
	for _, id in order do
		local d = defs[id]
		local ok, v = pcall(d.value, player)
		local other = nil
		if d.elsewhere then
			local ok2, s = pcall(d.elsewhere, player)
			other = if ok2 then s else nil
		end
		table.insert(out, { id = id, title = d.title, blurb = d.blurb, pays = if ok and type(v) == "number" then math.floor(v) else 0, other = other })
	end
	return out
end

local function near(player: Player): boolean
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	return hrp ~= nil and (hrp.Position - P.at).Magnitude < 16
end

local function send(player: Player)
	Net.get("LiveState"):FireClient(player, { type = "pawn", title = P.title, rows = rows(player) })
end

local function onAction(player: Player, payload: any)
	if type(payload) ~= "table" then
		return
	end
	if payload.type == "open" then
		if near(player) then
			send(player)
		end
	elseif payload.type == "sell" and type(payload.id) == "string" then
		local t = os.clock()
		if t - (lastSell[player] or 0) < P.sellCooldown or not near(player) then
			return
		end
		lastSell[player] = t
		local d = defs[payload.id]
		if not d then
			return
		end
		local ok, paid = pcall(d.take, player)
		if not ok or type(paid) ~= "number" or paid <= 0 then
			Notify.refuse(player, "Nothing to sell: bring goods from a house lick")
			send(player)
			return
		end
		paid = math.floor(paid)
		EconomyService.addCash(player, paid, "Pawn:" .. payload.id, false, P.at + Vector3.new(0, 4, 0))
		Notify.toast(player, "Sold to " .. P.title .. ": +$" .. paid, Color3.fromRGB(64, 220, 160))
		log(player.Name, "sold", payload.id, paid)
		send(player)
	end
end

local function buildCounter()
	local f = workspace:FindFirstChild("MTL_Live")
	if not f then
		f = Instance.new("Folder")
		f.Name = "MTL_Live"
		f.Parent = workspace
	end
	if f:FindFirstChild("PawnCounter") then
		return
	end
	local anchor = Instance.new("Part")
	anchor.Name = "PawnCounter"
	anchor.Size = Vector3.new(4, 5, 1)
	anchor.CFrame = CFrame.new(P.at + Vector3.new(0, 2.5, 0))
	anchor.Transparency = 1
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.Parent = f
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "Pawn"
	prompt.ActionText = "Sell"
	prompt.ObjectText = P.title
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 9
	prompt.RequiresLineOfSight = false
	prompt.Parent = anchor
	prompt.Triggered:Connect(function(player)
		send(player)
	end)
end

function PawnService.init()
	-- house-lick goods (the crime loop's fence value)
	PawnService.register("Goods", {
		title = "Lick goods",
		blurb = "TVs, speakers, jewelry boxes from house licks",
		value = function(player)
			local c = crime()
			return if c and c.fenceValue then (c.fenceValue(player) or 0) * P.goodsRate else 0
		end,
		take = function(player)
			local c = crime()
			if not (c and c.takeFence) then
				return 0
			end
			return (c.takeFence(player) or 0) * P.goodsRate
		end,
		elsewhere = function(player)
			local c = crime()
			local v = if c and c.fenceValue then c.fenceValue(player) or 0 else 0
			return if v > 0 then "Marcus pays $" .. math.floor(v) .. " dirty" else nil
		end,
	})
	buildCounter()
	Net.get("PawnAction").OnServerEvent:Connect(function(player, payload)
		local ok, err = pcall(onAction, player, payload)
		if not ok then
			warn("[MTL Pawn] action failed:", err)
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		lastSell[player] = nil
	end)
end

return PawnService
