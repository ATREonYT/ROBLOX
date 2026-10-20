-- Robux purchases. The client only opens Roblox's purchase prompt (the Halloween shop's prompt is opened here, after
-- checking: promptHalloween); everything is granted here.
--   Game passes: ownership is checked with Roblox on join and after each prompt closes (never trusted from the client);
--   an owned pass also gives its exclusive knives (Config/CoinShop Pass), here and nowhere else.
--   Developer products: ProcessReceipt grants once per PurchaseId and answers PurchaseGranted only after the
--   grant is saved, so a server crash can't lose a paid item or grant it twice.
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Products = require(ReplicatedStorage.Shared.Config.Products)
local CoinShop = require(ReplicatedStorage.Shared.Config.CoinShop)
local HalloweenShop = require(ReplicatedStorage.Shared.Config.HalloweenShop)
local Net = require(ReplicatedStorage.Shared.Net)
local DataService = require(script.Parent.DataService)

local ShopService = {}

local RECEIPT_MEMORY = 100
local noticeCount = 0 -- (HuzzShopNotice: a fresh number each time)

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

-- What a developer product gives. Returns false only for a kind we can't grant (never answered "granted"), and for
-- the Halloween shop a line to tell the player when a paid knife became keys.
-- Every product is granted even when taken off sale since: OnSale only stops new prompts (Products.status, the
-- shop screens, HalloweenShop.canPrompt), and a purchase already paid for must always give something (bug hunt,
-- Oct 20: a coin pack or spins switched off after a kid paid used to wait unanswered forever). A product that gives
-- nothing yet never has a prompt, so it can't arrive here.
local function grant(data, product): (boolean, string?)
	if product.Kind == "CrateKey" or product.Kind == "Knife" then
		-- the Halloween shop (Config/HalloweenShop.grant): a crate key; or the knife, worn; or, for a knife already
		-- yours (a stale page, another server), its crate's keys worth its price, so Robux never buys nothing
		local ok, _, note = HalloweenShop.grant(data, product)
		return ok, note
	end
	if product.Kind == "Coins" then
		data.Coins += product.Amount or 0
		return true
	elseif product.Kind == "Cosmetic" then
		data.Cosmetics = data.Cosmetics or {}
		data.Wear = data.Wear or {}
		data.Cosmetics[product.Key] = true
		if product.Slot then data.Wear[product.Slot] = product.Key end -- (a new buy is worn straight away)
		return true
	elseif product.Kind == "Spins" then -- Spin the Wheel spins (SpinService)
		data.Spins = (data.Spins or 0) + (product.Amount or 0)
		return true
	end
	return false
end

-- The Halloween shop's Robux buttons ask here (ActionService "PromptHalloween"), never prompt from the client: the
-- server checks the product has its ID and that a knife isn't yours already (Config/HalloweenShop.canPrompt), then
-- opens Roblox's prompt itself. A receipt that still arrives for an owned knife gives keys instead (grant above).
function ShopService.promptHalloween(player: Player, key: any): (boolean, string?)
	local product = type(key) == "string" and Products.get(key)
	local profile = DataService.get(player)
	if not product or not profile or not profile.Data then return false, "That isn't sold here." end
	local ok, why = HalloweenShop.canPrompt(profile.Data, product)
	if not ok then return false, why end
	if not pcall(function() MarketplaceService:PromptProductPurchase(player, product.Id) end) then
		return false, "The purchase couldn't open. Try again."
	end
	return true
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
		local ok, note = false, nil
		DataService.update(player, function(data)
			ok, note = grant(data, product)
			if ok then
				table.insert(data.Receipts, info.PurchaseId)
				while #data.Receipts > RECEIPT_MEMORY do table.remove(data.Receipts, 1) end
			end
		end)
		if not ok then return Enum.ProductPurchaseDecision.NotProcessedYet end
		-- tell the player when a paid knife became keys (Screens/HalloweenShop shows it as a toast). A player
		-- attribute, so no new remote: "<n>|<line>", n new each time so the same line twice still shows twice
		if note then
			noticeCount += 1
			player:SetAttribute("HuzzShopNotice", `{noticeCount}|{note}`)
		end
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

ShopService._processReceipt = processReceipt -- (for the offline check, tools/preview/check_bughunt.luau)

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
