-- Developer-product receipts: what each product grants, and the once-per-purchase answer to Roblox (brief 17; a
-- ModuleScript since brief 22, so StoreService and the unit tests run the very same code). StoreService sets
-- MarketplaceService.ProcessReceipt to StoreReceipts.process with the real players, profiles and side effects.
--
-- Grants (Products.Catalog decides which key gets which; each one changes only the profile and attributes, checks
-- everything that could fail BEFORE the profile changes, and never yields):
--   Power rows      + Products.powerAmount(key, RebirthRules.need(Rebirths)) Power
--   Cash rows       + Products.cashAmount(key) Cash
--   Boost rows      timed Power boosts (Products.boostLevels: one for RepBoost2x / RepBoost3x, three for the Boost
--                   Bundle), each Products.BoostDurationSeconds, queued by HoodServer/Boosts (every level keeps its
--                   own time, the strongest runs first), kept in the profile (Passes.Boost) so they survive a rejoin
--   BlockParty      x2 Power for everyone in this server for the same time
--   SkipRebirth     RebirthService.rebirth(player, { Free = true })
--   Box rows        (brief 21/22) opens that Robux shoe box Count times (Products.boxOpen) through
--                   HoodServer/ShoeOpening.openMany: the same roll, save and unboxing as a Cash box, ONE ShoeOpened
--                   with all the pairs; no distance, world or rack check (it was paid)
-- Once per purchase: the purchase id goes into the profile's ProcessedReceipts together with the grant (same save),
-- and the receipt is only answered PurchaseGranted once a save holding it has gone through (ProfileStore's
-- LastSavedData / OnAfterSave). A player who isn't here: NotProcessedYet (Roblox asks again on their next join). One
-- who leaves mid-save: the release save keeps the grant and the id, so the retry answers PurchaseGranted without a
-- second grant. A grant that fails changes nothing and answers NotProcessedYet.
local RS = game:GetService('ReplicatedStorage')
local Products = require(RS.Shared.Config.Products)
local Format = require(RS.Shared.Format)
local Boosts = require(script.Parent.Boosts)

local function optional(module)
	if not module then return nil end
	local ok, result = pcall(require, module)
	return ok and type(result) == 'table' and result or nil
end
local RebirthRules = optional(RS.Shared:FindFirstChild('RebirthRules'))
local Shoes = optional(RS.Shared.Config:FindFirstChild('Shoes'))
local ShoeRules = optional(RS.Shared:FindFirstChild('ShoeRules'))
local ShoeOpening = optional(script.Parent:FindFirstChild('ShoeOpening'))

local StoreReceipts = {}
StoreReceipts.Kept = 100 -- purchase ids remembered per profile
StoreReceipts.SaveWait = 30 -- seconds to wait for the save that holds a grant before telling Roblox to ask again

-- The grant for every developer product, from the catalog: { [key] = function(player, profile, key) }.
-- ctx holds the server's side effects (all optional, so the tests can stand in for them):
--   notice(player, text)   a Notice line to that player
--   publish(player)        re-set the player's boost attributes (StoreService.publishBoost)
--   party                  { Until = os.time } the server-wide Block Party
--   everyone()             the players a Block Party tells
--   rebirth(player)        -> ok, why (RebirthService.rebirth(player, { Free = true }))
--   now()                  the time (os.time)
function StoreReceipts.grants(ctx)
	ctx = type(ctx) == 'table' and ctx or {}
	-- (a message can't fail a grant: it comes after the profile has changed)
	local function notice(player, text) if ctx.notice then pcall(ctx.notice, player, text) end end
	local function publish(player) if ctx.publish then pcall(ctx.publish, player) end end
	local function now() return ctx.now and ctx.now() or os.time() end
	local function setAttribute(player, name, value) pcall(player.SetAttribute, player, name, value) end

	local function powerPack(player, profile, key)
		local need = RebirthRules and RebirthRules.need(profile.Data.Rebirths) or 2500
		local amount = Products.powerAmount(key, need)
		assert(amount > 0, 'no amount for ' .. key)
		profile.Data.Rep = math.min(1e12, profile.Data.Rep + amount)
		setAttribute(player, 'Power', profile.Data.Rep)
		notice(player, 'Thanks! +' .. Format.compact(amount) .. ' Power')
	end
	local function cashPack(player, profile, key)
		local amount = Products.cashAmount(key)
		assert(amount > 0, 'no amount for ' .. key)
		profile.Data.Cash = math.min(1e12, profile.Data.Cash + amount)
		setAttribute(player, 'Cash', profile.Data.Cash)
		notice(player, 'Thanks! +' .. Format.compact(amount) .. ' Cash')
	end
	local function timedBoosts(player, profile, key)
		local levels = Products.boostLevels(key)
		assert(#levels > 0, 'no boost for ' .. key)
		local seconds = Products.BoostDurationSeconds or 900
		local t = now()
		local passes = type(profile.Data.Passes) == 'table' and profile.Data.Passes or {}
		local boost = passes.Boost
		for _, level in levels do boost = Boosts.add(boost, level, seconds, t) end -- (pure: asserts before any change)
		passes.Boost = boost
		profile.Data.Passes = passes
		publish(player)
		local minutes = math.floor(#levels * seconds / 60 + 0.5)
		local running = Boosts.running(boost, t)
		if #levels > 1 then
			local order = {}
			for _, s in Boosts.queue(boost, t) do table.insert(order, s.Level .. 'x') end
			notice(player, 'Thanks! +' .. minutes .. ' min of Power boosts: ' .. table.concat(order, ', then '))
		elseif running > levels[1] then
			notice(player, 'Thanks! +' .. minutes .. ' min of ' .. levels[1] .. 'x Power, after your ' .. running .. 'x')
		else
			notice(player, 'Thanks! +' .. minutes .. ' min of ' .. levels[1] .. 'x Power')
		end
	end
	local function shoeBox(player, profile, key)
		assert(Shoes and ShoeRules and ShoeOpening, 'Shoes / ShoeRules / ShoeOpening missing')
		local boxId, count = Products.boxOpen(key)
		local box = boxId and Shoes.BoxById[boxId]
		assert(box and box.Robux and ShoeRules.canGrant(box.Robux) == box, 'no shoe box for ' .. tostring(key))
		ShoeOpening.openMany(player, profile, box.Id, count, { Product = key })
		-- (the pairs are in the profile now: nothing after this may fail the grant, or Roblox's retry would give more)
		if count > 1 then
			notice(player, 'Thanks! Your ' .. count .. ' ' .. box.Name .. 'es are open!')
		else
			notice(player, 'Thanks! Your ' .. box.Name .. ' is open!')
		end
	end

	local grants = {}
	for _, entry in Products.Catalog do
		if entry.Kind == 'Product' then
			if entry.Section == 'Power' then
				grants[entry.Key] = powerPack
			elseif entry.Section == 'Cash' then
				grants[entry.Key] = cashPack
			elseif entry.Section == 'Box' then
				grants[entry.Key] = shoeBox
			elseif type(entry.Boost) == 'number' or type(entry.Bundle) == 'table' then
				grants[entry.Key] = timedBoosts
			end
		end
	end
	grants.BlockParty = function(player)
		local party = ctx.party or { Until = 0 }
		party.Until = math.max(now(), party.Until) + (Products.BoostDurationSeconds or 900)
		for _, p in (ctx.everyone and ctx.everyone() or { player }) do
			publish(p)
			notice(p, player.DisplayName .. ' started a Block Party! x2 Power for everyone!')
		end
	end
	grants.SkipRebirth = function(player)
		assert(ctx.rebirth, 'RebirthService missing')
		local ok, why = ctx.rebirth(player)
		assert(ok, 'rebirth refused: ' .. tostring(why))
	end
	return grants
end

-- Is purchase `purchaseId` in the profile's last good save?
function StoreReceipts.saved(profile, purchaseId)
	local saved = profile.LastSavedData
	local list = type(saved) == 'table' and saved.ProcessedReceipts
	return type(list) == 'table' and table.find(list, purchaseId) ~= nil
end

-- Grants purchase `purchaseId` of `key` once. true and 'granted' (now) or 'had' (an earlier call did), or false and
-- why ('nogrant': no grant for that key; else the grant's error: nothing was recorded).
function StoreReceipts.apply(grants, player, profile, key, purchaseId)
	local receipts = profile.Data.ProcessedReceipts
	if type(receipts) ~= 'table' then
		receipts = {}
		profile.Data.ProcessedReceipts = receipts
	end
	if table.find(receipts, purchaseId) then return true, 'had' end
	local grant = key and grants[key]
	if not grant then return false, 'nogrant' end
	local ok, err = pcall(grant, player, profile, key)
	if not ok then return false, tostring(err) end
	table.insert(receipts, purchaseId)
	while #receipts > StoreReceipts.Kept do table.remove(receipts, 1) end
	return true, 'granted'
end

-- Saves and waits (up to `wait` seconds, default SaveWait, while the profile is active) for a save that holds
-- `purchaseId`. true when one went through.
function StoreReceipts.confirm(profile, purchaseId, wait)
	if StoreReceipts.saved(profile, purchaseId) then return true end
	local done = false
	local connection = profile.OnAfterSave and profile.OnAfterSave:Connect(function() done = StoreReceipts.saved(profile, purchaseId) end)
	pcall(function() profile:Save() end)
	local deadline = os.clock() + (wait or StoreReceipts.SaveWait)
	while not done and profile:IsActive() and os.clock() < deadline do task.wait(0.2) end
	if connection then connection:Disconnect() end
	return done or StoreReceipts.saved(profile, purchaseId)
end

-- ProcessReceipt: the decision for Roblox. deps: playerOf(userId) -> player?, profileOf(player) -> profile?,
-- push(player) (Data.push), grants (StoreReceipts.grants(ctx)), wait (seconds, optional).
function StoreReceipts.process(info, deps)
	local player = deps.playerOf(info.PlayerId)
	local profile = player and deps.profileOf(player)
	if not profile then return Enum.ProductPurchaseDecision.NotProcessedYet end
	local key = Products.keyFor('Product', info.ProductId)
	local purchaseId = tostring(info.PurchaseId)
	local ok, why = StoreReceipts.apply(deps.grants, player, profile, key, purchaseId)
	if not ok then
		if why == 'nogrant' then
			warn('[StoreService] No grant for product ' .. tostring(info.ProductId) .. ' (' .. tostring(key) .. ')')
		else
			warn('[StoreService] Grant ' .. tostring(key) .. ' failed: ' .. why)
		end
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	if why == 'granted' and deps.push then deps.push(player) end
	-- Answer only once a save holding this purchase id has gone through.
	if StoreReceipts.confirm(profile, purchaseId, deps.wait) then return Enum.ProductPurchaseDecision.PurchaseGranted end
	return Enum.ProductPurchaseDecision.NotProcessedYet
end

return StoreReceipts
