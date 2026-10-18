-- Robux purchases. The client only opens Roblox's purchase prompt; everything is granted here.
--   Game passes: ownership is checked with Roblox on join and after each prompt closes (never trusted from the client);
--   an owned pass also gives its exclusive knives (Config/CoinShop Pass), here and nowhere else.
--   Developer products: ProcessReceipt grants once per PurchaseId and answers PurchaseGranted only after the
--   grant is saved, so a server crash can't lose a paid item or grant it twice.
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Products = require(ReplicatedStorage.Shared.Config.Products)
local CoinShop = require(ReplicatedStorage.Shared.Config.CoinShop)
local Net = require(ReplicatedStorage.Shared.Net)
local DataService = require(script.Parent.DataService)

local ShopService = {}

local RECEIPT_MEMORY = 100

-- `boughtId`: a pass Roblox just told us this player bought (PromptGamePassPurchaseFinished comes from Roblox, not
-- the client). Roblox's ownership check can still say "not owned" right after an in-game purchase, so it counts as
-- owned straight away. A check that errors keeps what we knew before, instead of taking the pass away.
local function refreshPasses(player: Player, boughtId: number?)
	local before = DataService.getExtra(player, "Passes") or {}
	local owned = {}
	for _, p in Products.Passes do
		if p.Id ~= 0 then
			local ok, has = pcall(MarketplaceService.UserOwnsGamePassAsync, MarketplaceService, player.UserId, p.Id)
			if (ok and has) or p.Id == boughtId or (not ok and before[p.Key]) then owned[p.Key] = true end
		end
	end
	if not player.Parent then return end -- (left while Roblox answered: don't bring their entry back)
	player:SetAttribute("VIP", owned.VIP == true) -- read by the chat tag (client) and the name tag
	DataService.setExtra(player, "Passes", owned)
	-- the pass's exclusive knives (Config/CoinShop Pass): given once Roblox says you own the pass, worn if your knife
	-- slot is empty (never over one you picked, nor a slot you emptied on purpose)
	local profile = DataService.get(player)
	local new = profile and profile.Data and CoinShop.passGrants(profile.Data.Cosmetics or {}, owned) or {}
	if #new > 0 then
		DataService.update(player, function(d)
			d.Cosmetics = d.Cosmetics or {}
			d.Wear = d.Wear or {}
			for _, key in new do
				local item = CoinShop.get(key)
				if item and item.Pass and owned[item.Pass] then
					d.Cosmetics[key] = true
					if CoinShop.worn(d, item.Slot) == nil and d.Wear[item.Slot] ~= "" then d.Wear[item.Slot] = key end
				end
			end
		end)
	end
	pcall(function() require(script.Parent.NameTagService).restyle(player) end)
end

function ShopService.ownsPass(player: Player, key: string): boolean
	local passes = DataService.getExtra(player, "Passes")
	return passes ~= nil and passes[key] == true
end

-- What a developer product gives. Returns false if the product is unknown or not on sale (never grant those).
local function grant(data, product): boolean
	if not product.OnSale then return false end
	if product.Kind == "Coins" then
		data.Coins += product.Amount or 0
		return true
	elseif product.Kind == "Cosmetic" then
		data.Cosmetics[product.Key] = true
		if product.Slot then data.Wear[product.Slot] = product.Key end -- (a new buy is worn straight away)
		return true
	elseif product.Kind == "Spins" then -- Spin the Wheel spins (SpinService)
		data.Spins = (data.Spins or 0) + (product.Amount or 0)
		return true
	end
	return false
end

local function processReceipt(info)
	local player = Players:GetPlayerByUserId(info.PlayerId)
	if not player then return Enum.ProductPurchaseDecision.NotProcessedYet end
	local profile = DataService.waitFor(player, 15)
	if not profile or not profile:IsActive() then return Enum.ProductPurchaseDecision.NotProcessedYet end
	local product = Products.byProductId(info.ProductId)
	if not product then
		warn("[Shop] receipt for an unknown product id", info.ProductId)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local receipts = profile.Data.Receipts
	if not table.find(receipts, info.PurchaseId) then
		local ok = false
		DataService.update(player, function(data)
			ok = grant(data, product)
			if ok then
				table.insert(data.Receipts, info.PurchaseId)
				while #data.Receipts > RECEIPT_MEMORY do table.remove(data.Receipts, 1) end
			end
		end)
		if not ok then return Enum.ProductPurchaseDecision.NotProcessedYet end
	end
	-- Only answer "granted" once the receipt is in a completed save.
	local function saved() return table.find(profile.LastSavedData.Receipts or {}, info.PurchaseId) ~= nil end
	if not saved() then
		profile:Save()
		local deadline = os.clock() + 20
		while not saved() and profile:IsActive() and os.clock() < deadline do
			task.wait(0.25) -- poll, so the deadline holds even if no further save happens
		end
	end
	return if saved() then Enum.ProductPurchaseDecision.PurchaseGranted else Enum.ProductPurchaseDecision.NotProcessedYet
end

function ShopService.start()
	MarketplaceService.ProcessReceipt = processReceipt
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
		if purchased then refreshPasses(player, passId) end
	end)
	local function onJoin(player: Player)
		if DataService.waitFor(player, 60) then refreshPasses(player) end
	end
	Players.PlayerAdded:Connect(onJoin)
	for _, p in Players:GetPlayers() do task.spawn(onJoin, p) end

	-- Coin purchases (no coin-priced items exist yet; this keeps the rule in one place for when they do).
	(Net.get("BuyWithCoins") :: RemoteFunction).OnServerInvoke = function(player, key)
		if type(key) ~= "string" then return false, "Unknown item." end
		local product = Products.get(key) :: any
		if not product or type(product.CoinPrice) ~= "number" or not product.OnSale then return false, "That item can't be bought with coins." end
		local result, message = false, "Not enough coins."
		DataService.update(player, function(data)
			if product.Kind == "Cosmetic" and data.Cosmetics[product.Key] then message = "You already own this."; return end
			if data.Coins < product.CoinPrice then return end
			data.Coins -= product.CoinPrice
			if product.Kind == "Cosmetic" then
				data.Cosmetics[product.Key] = true
				if product.Slot then data.Wear[product.Slot] = product.Key end
			end
			result, message = true, nil
		end)
		return result, message
	end
end

return ShopService
