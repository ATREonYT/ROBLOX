--!strict
-- Game passes (checked with Roblox, cached as player attributes MTL_Pass_<Name>), purchase prompts, and the ONE
-- ProcessReceipt for developer products (boosts). Kid-safe rules: grant only here on the server, grant once per
-- PurchaseId, answer PurchaseGranted only after the grant is SAVED, never sell an id of 0 ("Coming soon").
--   MonetizationService.owns(player, passName) -> bool
--   MonetizationService.prompt(player, passOrProductName)   (the phone's "buy" action calls this; whitelisted names)
--   MonetizationService.PassChanged: Signal(player, passName, owned)
--   MonetizationService.ProductGranted: Signal(player, productName)
-- Products (Config/Monetization.Products): XPBoost / CashBoost = 2x for Economy.BoostSecondsPerPurchase of PLAY
-- time, stacking (EconomyService counts it down and applies it). StarterPack pass: its cash is granted once per save.
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Monetization = require(ReplicatedStorage.MTL.Config.Monetization)
local Economy = require(ReplicatedStorage.MTL.Config.Economy)
local Signal = require(ReplicatedStorage.MTL.Signal)
local Notify = require(script.Parent.Notify)
local DataService = require(script.Parent.DataService)

local MonetizationService = {}
MonetizationService.PassChanged = Signal.new() -- (player, passName, owned)
MonetizationService.ProductGranted = Signal.new() -- (player, productName)

local MAX_PURCHASE_IDS = 200 -- receipts kept per save (Roblox only retries recent ones)

local function attr(name: string): string
	return "MTL_Pass_" .. name
end

function MonetizationService.owns(player: Player, passName: string): boolean
	return player:GetAttribute(attr(passName)) == true
end

local function check(player: Player, passName: string, id: number)
	if id == 0 then
		player:SetAttribute(attr(passName), false)
		return
	end
	local ok, owned = pcall(MarketplaceService.UserOwnsGamePassAsync, MarketplaceService, player.UserId, id)
	if ok then
		local was = player:GetAttribute(attr(passName)) == true
		player:SetAttribute(attr(passName), owned == true)
		if was ~= (owned == true) then
			MonetizationService.PassChanged:Fire(player, passName, owned == true)
		end
	else
		warn("[MTL Monetization] pass check failed", passName, owned)
	end
end

-- Opens the Roblox purchase prompt. Id 0 = not set up yet -> "coming soon", never a prompt.
function MonetizationService.prompt(player: Player, name: string)
	local passId = Monetization.Passes[name]
	if passId ~= nil then
		if passId == 0 then
			Notify.toast(player, "Coming soon")
			return
		end
		if MonetizationService.owns(player, name) then
			Notify.toast(player, "You already own this")
			return
		end
		MarketplaceService:PromptGamePassPurchase(player, passId)
		return
	end
	local productId = Monetization.Products[name]
	if productId ~= nil then
		if productId == 0 then
			Notify.toast(player, "Coming soon")
			return
		end
		MarketplaceService:PromptProductPurchase(player, productId)
		return
	end
	warn("[MTL Monetization] unknown pass/product", name)
end

---------------------------------------------------------------- developer products

-- What each product does. Return true when granted. Runs at most once per PurchaseId.
local productGrants: { [string]: (Player, any) -> boolean } = {
	XPBoost = function(player, data)
		data.Boosts.XP2xSeconds += Economy.BoostSecondsPerPurchase
		Notify.banner(player, "2x XP", math.floor(Economy.BoostSecondsPerPurchase / 60) .. " minutes of play time added")
		return true
	end,
	CashBoost = function(player, data)
		data.Boosts.Cash2xSeconds += Economy.BoostSecondsPerPurchase
		Notify.banner(player, "2x CASH", math.floor(Economy.BoostSecondsPerPurchase / 60) .. " minutes of play time added")
		return true
	end,
}

local function trimPurchases(purchases: { [string]: number })
	local list = {}
	for id, t in purchases do
		table.insert(list, { id = id, t = if type(t) == "number" then t else 0 })
	end
	if #list <= MAX_PURCHASE_IDS then
		return
	end
	table.sort(list, function(a, b)
		return a.t < b.t
	end)
	for i = 1, #list - MAX_PURCHASE_IDS do
		purchases[list[i].id] = nil
	end
end

local function isSaved(profile: any, purchaseId: string): boolean
	local saved = profile.LastSavedData
	return saved ~= nil and saved.Purchases ~= nil and saved.Purchases[purchaseId] ~= nil
end

local function processReceipt(receipt: any): Enum.ProductPurchaseDecision
	local player = Players:GetPlayerByUserId(receipt.PlayerId)
	if not player then
		return Enum.ProductPurchaseDecision.NotProcessedYet -- Roblox retries next time they join
	end
	local profile = DataService.profile(player)
	while not profile and player.Parent == Players do
		task.wait(0.5)
		profile = DataService.profile(player)
	end
	if not profile or not profile:IsActive() then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local name: string? = nil
	for n, id in Monetization.Products do
		if id ~= 0 and id == receipt.ProductId then
			name = n
		end
	end
	local grant = name and productGrants[name]
	if not grant then
		warn("[MTL Monetization] receipt for an unknown product", receipt.ProductId)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local purchaseId = tostring(receipt.PurchaseId)
	local data = profile.Data
	if data.Purchases[purchaseId] == nil then
		local ok, result = pcall(grant, player, data)
		if not ok or result ~= true then
			warn("[MTL Monetization] grant failed", name, result)
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end
		data.Purchases[purchaseId] = os.time()
		trimPurchases(data.Purchases)
		DataService.push(player)
		MonetizationService.ProductGranted:Fire(player, name)
		print("[MTL Monetization]", player.Name, "bought", name)
	end
	-- answer "granted" only once the save that holds this PurchaseId is written
	if isSaved(profile, purchaseId) then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end
	while profile:IsActive() do
		local before = profile.LastSavedData
		profile:Save()
		if profile.LastSavedData == before then
			profile.OnAfterSave:Wait()
		end
		if isSaved(profile, purchaseId) then
			return Enum.ProductPurchaseDecision.PurchaseGranted
		end
		if profile:IsActive() then
			task.wait(10)
		end
	end
	return Enum.ProductPurchaseDecision.NotProcessedYet
end

-- StarterPack pass: its cash lands once per save (the pass itself is never saved, only "already given").
local function grantStarterPack(player: Player)
	local data = DataService.get(player)
	if not data or data.Purchases["Pass:StarterPack"] or not MonetizationService.owns(player, "StarterPack") then
		return
	end
	data.Purchases["Pass:StarterPack"] = os.time()
	data.Cash = math.min(data.Cash + (Monetization.StarterPack.Cash or 0), Economy.MaxCash)
	local ls = player:FindFirstChild("leaderstats")
	local cash = ls and ls:FindFirstChild("Cash") :: IntValue?
	if cash then
		cash.Value = data.Cash
	end
	DataService.push(player)
	Notify.banner(player, "STARTER PACK", "+$" .. tostring(Monetization.StarterPack.Cash))
end

function MonetizationService.init()
	local byId: { [number]: string } = {}
	for name, id in Monetization.Passes do
		if id ~= 0 then
			byId[id] = name
		end
	end

	local function onJoin(player: Player)
		for name, id in Monetization.Passes do
			task.spawn(check, player, name, id)
		end
	end
	Players.PlayerAdded:Connect(onJoin)
	for _, p in Players:GetPlayers() do
		onJoin(p)
	end

	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
		local name = byId[passId]
		if name and purchased then
			check(player, name, passId) -- re-check with Roblox, never trust the event alone
		end
	end)

	MarketplaceService.ProcessReceipt = processReceipt -- the ONLY ProcessReceipt in the place

	MonetizationService.PassChanged:Connect(function(player, name, owned)
		if name == "StarterPack" and owned then
			grantStarterPack(player)
		end
	end)
	DataService.Ready:Connect(function(player)
		-- ownership may have been checked before the save loaded
		task.delay(3, grantStarterPack, player)
	end)

	-- Phone/UI "buy" buttons: PhoneAction { type = "buy", item = "XP2x" | "XPBoost" | ... }
	-- Required lazily: PhoneService boots after this service.
	task.defer(function()
		local PhoneService = require(script.Parent.PhoneService) :: any
		PhoneService.onAction("buy", function(player, payload)
			local item = payload.item
			if type(item) == "string" and (Monetization.Passes[item] ~= nil or Monetization.Products[item] ~= nil) then
				MonetizationService.prompt(player, item)
			end
		end)
	end)
end

return MonetizationService
