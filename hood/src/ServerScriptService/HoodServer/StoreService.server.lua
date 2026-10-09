-- The Store's server side (brief 17): who owns which game pass, and developer-product receipts. Everything comes from
-- Shared/Config/Products (ids the owner pastes in from create.roblox.com); with every id 0 this does nothing at all.
--   Passes: on join (and on PromptGamePassPurchaseFinished) each pass with an id is checked with
--     UserOwnsGamePassAsync (pcall, a few tries) and the player gets the attribute Pass_<Key> = true. Gameplay reads
--     those on the server (HoodServer/Boosts: Pass_DoubleRep, Pass_DoubleCash); a client can't fake them.
--   Products: MarketplaceService.ProcessReceipt grants each purchase exactly once. The purchase id goes into the
--     profile's ProcessedReceipts together with the grant (same save), and the receipt is only answered PurchaseGranted
--     once a save holding it has gone through (ProfileStore's LastSavedData / OnAfterSave), so a server crash can't
--     lose a paid grant: Roblox asks again and the id check stops a double grant.
--     PowerPack1-3   + Products.powerAmount(key, RebirthRules.need(Rebirths)) Power
--     Small/Medium/LargeCash   + Products.cashAmount(key) Cash
--     RepBoost2x/3x  a personal timed boost (x2 / x3 Power for Products.BoostDurationSeconds; buying again adds time,
--                    the bigger level wins), kept in the profile (Passes.Boost) so it survives a rejoin
--     BlockParty     x2 Power for everyone in this server for the same time
--     SkipRebirth    RebirthService.rebirth(player, { Free = true })
--   PowerBoost: each second every player's attribute PowerBoost = personal boost x party (1 when none); BoostEnds = the
--   os.time() the personal boost ends (0 when none), for the HUD.
local Players = game:GetService('Players')
local RS = game:GetService('ReplicatedStorage')
local MarketplaceService = game:GetService('MarketplaceService')

local Data = require(script.Parent.DataService)
local Products = require(RS.Shared.Config.Products)
local Net = require(RS.Shared.Net)
local Format = require(RS.Shared.Format)

local function optional(module)
	if not module then return nil end
	local ok, result = pcall(require, module)
	return ok and type(result) == 'table' and result or nil
end
local RebirthRules = optional(RS.Shared:FindFirstChild('RebirthRules'))
local RebirthService = optional(script.Parent:FindFirstChild('RebirthService'))

local RECEIPTS_KEPT = 100 -- purchase ids remembered per profile
local SAVE_WAIT = 30 -- seconds to wait for the save that holds a grant before telling Roblox to ask again

local function notice(player, text) Net.get('Notice'):FireClient(player, text) end

---------------------------------------------------------------------------------------------- passes
local function setPass(player, key)
	if player.Parent == Players and player:GetAttribute('Pass_' .. key) ~= true then player:SetAttribute('Pass_' .. key, true) end
end
local function checkPasses(player)
	for key in Products.Passes do
		local id = Products.idOf(key)
		if id ~= 0 then
			task.spawn(function()
				for attempt = 1, 3 do
					local ok, owns = pcall(MarketplaceService.UserOwnsGamePassAsync, MarketplaceService, player.UserId, id)
					if ok then
						if owns then setPass(player, key) end
						return
					end
					task.wait(2 * attempt)
				end
				warn('[StoreService] Could not check pass ' .. key .. ' for ' .. player.Name)
			end)
		end
	end
end
MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, id, bought)
	if not bought then return end
	local key = Products.keyFor('Pass', id)
	if key then
		setPass(player, key)
		local entry = Products.ByKey[key]
		notice(player, 'Thanks! ' .. (entry and entry.Title or 'Your pass') .. ' is yours.')
	end
end)

---------------------------------------------------------------------------------------------- boosts
local party = { Until = 0 } -- the server-wide Block Party
local function boostOf(profile)
	local passes = profile and profile.Data.Passes
	local b = type(passes) == 'table' and passes.Boost
	if type(b) ~= 'table' or type(b.Level) ~= 'number' or type(b.Until) ~= 'number' then return 1, 0 end
	if b.Until <= os.time() then return 1, 0 end
	return math.clamp(b.Level, 1, 10), b.Until
end
local function publishBoost(player)
	local profile = Data.get(player)
	local level, ends = boostOf(profile)
	local value = level * (party.Until > os.time() and 2 or 1)
	if player:GetAttribute('PowerBoost') ~= value then player:SetAttribute('PowerBoost', value) end
	if player:GetAttribute('BoostEnds') ~= ends then player:SetAttribute('BoostEnds', ends) end
	if player:GetAttribute('PartyEnds') ~= party.Until then player:SetAttribute('PartyEnds', party.Until) end
end

---------------------------------------------------------------------------------------------- grants
-- Each grant changes only the profile (and attributes); it must not yield.
local GRANTS = {}
local function powerPack(player, profile, key)
	local n = profile.Data.Rebirths
	local need = RebirthRules and RebirthRules.need(n) or 2500
	local amount = Products.powerAmount(key, need)
	assert(amount > 0, 'no amount for ' .. key)
	profile.Data.Rep = math.min(1e12, profile.Data.Rep + amount)
	player:SetAttribute('Power', profile.Data.Rep)
	notice(player, 'Thanks! +' .. Format.compact(amount) .. ' Power')
end
local function cashPack(player, profile, key)
	local amount = Products.cashAmount(key)
	assert(amount > 0, 'no amount for ' .. key)
	profile.Data.Cash = math.min(1e12, profile.Data.Cash + amount)
	player:SetAttribute('Cash', profile.Data.Cash)
	notice(player, 'Thanks! +' .. Format.compact(amount) .. ' Cash')
end
local function timedBoost(level)
	return function(player, profile)
		local passes = profile.Data.Passes
		local _, ends = boostOf(profile)
		local now = os.time()
		local current = type(passes.Boost) == 'table' and passes.Boost.Until and passes.Boost.Until > now and passes.Boost.Level or 1
		passes.Boost = { Level = math.max(level, current), Until = math.max(now, ends) + (Products.BoostDurationSeconds or 900) }
		publishBoost(player)
		notice(player, 'Thanks! x' .. passes.Boost.Level .. ' Power for ' .. math.floor((passes.Boost.Until - now) / 60 + 0.5) .. ' minutes')
	end
end
GRANTS.PowerPack1, GRANTS.PowerPack2, GRANTS.PowerPack3 = powerPack, powerPack, powerPack
GRANTS.SmallCash, GRANTS.MediumCash, GRANTS.LargeCash = cashPack, cashPack, cashPack
GRANTS.RepBoost2x = timedBoost(2)
GRANTS.RepBoost3x = timedBoost(3)
GRANTS.BlockParty = function(player)
	party.Until = math.max(os.time(), party.Until) + (Products.BoostDurationSeconds or 900)
	for _, p in Players:GetPlayers() do
		publishBoost(p)
		notice(p, player.DisplayName .. ' started a Block Party! x2 Power for everyone!')
	end
end
GRANTS.SkipRebirth = function(player)
	assert(RebirthService and type(RebirthService.rebirth) == 'function', 'RebirthService missing')
	local ok, why = RebirthService.rebirth(player, { Free = true })
	assert(ok, 'rebirth refused: ' .. tostring(why))
end

---------------------------------------------------------------------------------------------- receipts
local function savedHas(profile, purchaseId)
	local saved = profile.LastSavedData
	local list = type(saved) == 'table' and saved.ProcessedReceipts
	return type(list) == 'table' and table.find(list, purchaseId) ~= nil
end
MarketplaceService.ProcessReceipt = function(info)
	local player = Players:GetPlayerByUserId(info.PlayerId)
	local profile = player and Data.get(player)
	if not profile then return Enum.ProductPurchaseDecision.NotProcessedYet end
	local key = Products.keyFor('Product', info.ProductId)
	local purchaseId = tostring(info.PurchaseId)
	local receipts = profile.Data.ProcessedReceipts
	if type(receipts) ~= 'table' then
		receipts = {}
		profile.Data.ProcessedReceipts = receipts
	end
	if not table.find(receipts, purchaseId) then
		local grant = key and GRANTS[key]
		if not grant then
			warn('[StoreService] No grant for product ' .. tostring(info.ProductId) .. ' (' .. tostring(key) .. ')')
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end
		local ok, err = pcall(grant, player, profile, key)
		if not ok then
			warn('[StoreService] Grant ' .. key .. ' failed: ' .. tostring(err))
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end
		table.insert(receipts, purchaseId)
		while #receipts > RECEIPTS_KEPT do table.remove(receipts, 1) end
		Data.push(player)
	end
	-- Answer only once a save holding this purchase id has gone through.
	if savedHas(profile, purchaseId) then return Enum.ProductPurchaseDecision.PurchaseGranted end
	local done = false
	local connection = profile.OnAfterSave and profile.OnAfterSave:Connect(function() done = savedHas(profile, purchaseId) end)
	pcall(function() profile:Save() end)
	local deadline = os.clock() + SAVE_WAIT
	while not done and profile:IsActive() and os.clock() < deadline do task.wait(0.2) end
	if connection then connection:Disconnect() end
	return (done or savedHas(profile, purchaseId)) and Enum.ProductPurchaseDecision.PurchaseGranted or Enum.ProductPurchaseDecision.NotProcessedYet
end

---------------------------------------------------------------------------------------------- players
local function joined(player)
	checkPasses(player)
	publishBoost(player)
end
Players.PlayerAdded:Connect(joined)
for _, p in Players:GetPlayers() do task.spawn(joined, p) end
task.spawn(function()
	while true do
		task.wait(1)
		for _, p in Players:GetPlayers() do publishBoost(p) end
	end
end)
