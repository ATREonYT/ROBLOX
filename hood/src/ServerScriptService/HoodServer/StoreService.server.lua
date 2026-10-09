-- The Store's server side (brief 17): who owns which game pass, and developer-product receipts. Everything comes from
-- Shared/Config/Products (ids the owner pastes in from create.roblox.com); with every id 0 this does nothing at all.
--   Passes: on join (and on PromptGamePassPurchaseFinished) each pass with an id is checked with
--     UserOwnsGamePassAsync (pcall, a few tries) and the player gets the attribute Pass_<Key> = true, then
--     PassesChecked = true once all came back. Gameplay reads those on the server (HoodServer/Boosts: Pass_DoubleRep,
--     Pass_DoubleCash; HoodServer/ShoeOpening and ShoeService: Pass_ExtraEquip, Pass_Lucky, Pass_TripleOpen); a client
--     can't fake them.
--   Products: MarketplaceService.ProcessReceipt -> HoodServer/StoreReceipts (the grants and the once-per-purchase
--     answer live there, so the unit tests run the same code): each purchase is granted exactly once; its id goes into
--     the profile's ProcessedReceipts in the same save as the grant, and Roblox hears PurchaseGranted only once that
--     save has gone through. Power and Cash packs, timed boosts and the Boost Bundle, Block Party, Skip Rebirth and the
--     Robux shoe boxes (1, 3 or 8 at once, through HoodServer/ShoeOpening).
--   Boost attributes (each second, every player): PowerBoost = the running timed boost x the party (1 when none);
--   BoostEnds = the os.time the running boost ends (0 when none); PartyEnds = the Block Party's end; BoostQueue =
--   'Level:Until,...' every boost still to run, in run order ('' when none; HoodServer/Boosts.queueString), for the
--   Inventory's Items tab. Timed boosts queue (HoodServer/Boosts): each level keeps its own time, the strongest first.
local Players = game:GetService('Players')
local RS = game:GetService('ReplicatedStorage')
local MarketplaceService = game:GetService('MarketplaceService')

local Data = require(script.Parent.DataService)
local Products = require(RS.Shared.Config.Products)
local Net = require(RS.Shared.Net)

local function optional(module)
	if not module then return nil end
	local ok, result = pcall(require, module)
	return ok and type(result) == 'table' and result or nil
end
local RebirthService = optional(script.Parent:FindFirstChild('RebirthService'))
local Boosts = require(script.Parent.Boosts)
local Receipts = require(script.Parent.StoreReceipts)

local function notice(player, text) Net.get('Notice'):FireClient(player, text) end

---------------------------------------------------------------------------------------------- passes
local function setPass(player, key)
	if player.Parent == Players and player:GetAttribute('Pass_' .. key) ~= true then player:SetAttribute('Pass_' .. key, true) end
end
-- (brief 22) PassesChecked = true once every pass with an id has been checked (at once when none has an id): until
-- then a missing Pass_* attribute may just be on its way, so ShoeOpening doesn't take a 4th pair off before the +1 Shoe
-- Slot check is back. A check that keeps failing leaves it unset (nothing is taken away on a network error).
local function checkPasses(player)
	local pending, failed = 0, false
	local function done()
		pending -= 1
		if pending == 0 and not failed and player.Parent == Players then player:SetAttribute('PassesChecked', true) end
	end
	for key in Products.Passes do
		local id = Products.idOf(key)
		if id ~= 0 then
			pending += 1
			task.spawn(function()
				for attempt = 1, 3 do
					local ok, owns = pcall(MarketplaceService.UserOwnsGamePassAsync, MarketplaceService, player.UserId, id)
					if ok then
						if owns then setPass(player, key) end
						done()
						return
					end
					task.wait(2 * attempt)
				end
				warn('[StoreService] Could not check pass ' .. key .. ' for ' .. player.Name)
				failed = true
				done()
			end)
		end
	end
	if pending == 0 and player.Parent == Players then player:SetAttribute('PassesChecked', true) end
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
local function publishBoost(player)
	local profile = Data.get(player)
	local passes = profile and profile.Data.Passes
	local boost = type(passes) == 'table' and passes.Boost or nil
	local now = os.time()
	local level, ends = Boosts.running(boost, now)
	local value = level * (party.Until > now and 2 or 1)
	if player:GetAttribute('PowerBoost') ~= value then player:SetAttribute('PowerBoost', value) end
	if player:GetAttribute('BoostEnds') ~= ends then player:SetAttribute('BoostEnds', ends) end
	if player:GetAttribute('PartyEnds') ~= party.Until then player:SetAttribute('PartyEnds', party.Until) end
	local queue = Boosts.queueString(boost, now)
	if player:GetAttribute('BoostQueue') ~= queue then player:SetAttribute('BoostQueue', queue) end
end

---------------------------------------------------------------------------------------------- receipts
local GRANTS = Receipts.grants({
	notice = notice,
	publish = publishBoost,
	party = party,
	everyone = function() return Players:GetPlayers() end,
	rebirth = function(player)
		assert(RebirthService and type(RebirthService.rebirth) == 'function', 'RebirthService missing')
		return RebirthService.rebirth(player, { Free = true })
	end,
})
local deps = {
	playerOf = function(userId) return Players:GetPlayerByUserId(userId) end,
	profileOf = Data.get,
	push = Data.push,
	grants = GRANTS,
}
MarketplaceService.ProcessReceipt = function(info)
	return Receipts.process(info, deps)
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
