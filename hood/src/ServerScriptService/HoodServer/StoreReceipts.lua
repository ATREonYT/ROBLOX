-- Developer-product receipts: what each product grants, and the once-per-purchase answer to Roblox (brief 17; a
-- ModuleScript since brief 22, so StoreService and the unit tests run the very same code). StoreService sets
-- MarketplaceService.ProcessReceipt to StoreReceipts.process with the real players, profiles and side effects.
--
-- Grants (Products.Catalog decides which key gets which; each one changes only the profile and attributes, checks
-- everything that could fail BEFORE the profile changes, and never yields):
--   Power rows      + Products.powerAmount(key, RebirthRules.need(Rebirths), current Power) Power: the larger of the
--                   rebirth-based amount and a share of the Power you hold (brief 29, P5)
--   Cash rows       + Products.cashAmount(key, best stage) Cash: scales with the best stage you reached (brief 29, P5)
--   OfflineX2       (brief 29, P5) 2x Offline Earnings: HoodServer/Retention.offlineDouble
--   RestoreStreak   (brief 29, P5) keeps the daily streak after a missed day (Retention.restoreStreak). If there is
--                   nothing to restore any more (the buyer claimed in another tab, or midnight passed), the buyer gets
--                   the next daily reward's worth instead (Retention.give), never nothing for Robux
--   Boost rows      timed Power boosts (Products.boostLevels: one for RepBoost2x / RepBoost3x, three for the Boost
--                   Bundle), each Products.BoostDurationSeconds, queued by HoodServer/Boosts (every level keeps its
--                   own time, the strongest runs first), kept in the profile (Passes.Boost) so they survive a rejoin
--   BlockParty      x2 Power for everyone in this server for the same time
--   SkipRebirth     RebirthService.rebirth(player, { Free = true })
--   Featured rows   (brief 30) the weekly pack: Cash (Products.cashAmount, scales with the best stage) + a timed Power boost
--                   + Count of a Robux box, in ONE grant; everything that can fail runs before the profile changes
--   Box rows        (brief 21/22) opens that Robux shoe box Count times (Products.boxOpen) through
--                   HoodServer/ShoeOpening.openMany: the same roll, save and unboxing as a Cash box, ONE ShoeOpened
--                   with all the pairs; no distance, world or rack check (it was paid)
-- Gifts (brief 30, "Gift A Player"): the Cash Packs and the Robux boxes (Products.giftable) can be bought for another player
-- in the server. The buyer's client sends the target right before the purchase prompt (StoreReceipts.setGift, fresh for
-- GiftFresh seconds); at the receipt, if that player is still here with a profile, the grant goes to THEM (both players are
-- told), else it goes to the buyer with a clear notice. The receipt id is always the BUYER's (their profile's
-- ProcessedReceipts), so a retry can never grant twice; a gift that cannot be delivered or fails is granted to the buyer on
-- the spot, never lost and never left at NotProcessedYet. A Cash gift is worth what the buyer's card showed (their best
-- stage scales it), not the receiver's.
-- Once per purchase: the purchase id goes into the profile's ProcessedReceipts together with the grant (same save),
-- and the receipt is only answered PurchaseGranted once a save holding it has gone through (ProfileStore's
-- LastSavedData / OnAfterSave). A player who isn't here: NotProcessedYet (Roblox asks again on their next join). One
-- who leaves mid-save: the release save keeps the grant and the id, so the retry answers PurchaseGranted without a
-- second grant. A grant that fails changes nothing and answers NotProcessedYet.
local RS = game:GetService('ReplicatedStorage')
local Products = require(RS.Shared.Config.Products)
local Format = require(RS.Shared.Format)
local Boosts = require(script.Parent.Boosts)
local Retention = require(script.Parent.Retention)

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
StoreReceipts.GiftFresh = 60 -- seconds a chosen gift target stays valid

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

	-- (brief 30) the words a receiver hears: "Thanks! +5K Cash" for yourself, "Ann gifted you +5K Cash!" for a gift
	local function thanks(player, opts, text)
		if opts and opts.From then
			notice(player, tostring(opts.From.DisplayName or opts.From.Name or 'Someone') .. ' gifted you ' .. text .. '!')
		else
			notice(player, 'Thanks! ' .. text)
		end
	end
	local function powerPack(player, profile, key)
		local need = RebirthRules and RebirthRules.need(profile.Data.Rebirths) or 2500
		local amount = Products.powerAmount(key, need, profile.Data.Rep)
		assert(amount > 0, 'no amount for ' .. key)
		profile.Data.Rep = math.min(1e12, profile.Data.Rep + amount)
		setAttribute(player, 'Power', profile.Data.Rep)
		notice(player, 'Thanks! +' .. Format.compact(amount) .. ' Power')
	end
	local function cashPack(player, profile, key, opts)
		-- (a gift is worth what the BUYER's card showed: their best stage)
		local amount = Products.cashAmount(key, Retention.bestStage((opts and opts.BuyerProfile or profile).Data))
		assert(amount > 0, 'no amount for ' .. key)
		profile.Data.Cash = math.min(1e12, profile.Data.Cash + amount)
		setAttribute(player, 'Cash', profile.Data.Cash)
		thanks(player, opts, '+' .. Format.compact(amount) .. ' Cash')
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
	local function offlineX2(player, profile, key)
		local amount = Retention.offlineDouble(profile)
		setAttribute(player, 'Power', profile.Data.Rep)
		notice(player, 'Thanks! 2x Offline: +' .. Format.compact(amount) .. ' Power')
	end
	local function restoreStreak(player, profile, key)
		local ok = Retention.restoreStreak(profile, now())
		if ok then
			notice(player, 'Thanks! Your daily streak is safe. Claim your next day!')
			return
		end
		local RetentionRules = require(RS.Shared.RetentionRules)
		local st = RetentionRules.status(profile.Data, now())
		local need = RebirthRules and RebirthRules.need(profile.Data.Rebirths) or 2500
		local reward = RetentionRules.reward(st.Day, need, Retention.bestStage(profile.Data))
		assert(reward, 'no reward')
		Retention.give(profile, reward, now())
		setAttribute(player, 'Cash', profile.Data.Cash)
		setAttribute(player, 'Power', profile.Data.Rep)
		notice(player, 'Your streak was already safe, so here is a reward instead: ' .. table.concat(RetentionRules.lines(reward, Format.compact), ' + '))
	end
	local function shoeBox(player, profile, key, opts)
		assert(Shoes and ShoeRules and ShoeOpening, 'Shoes / ShoeRules / ShoeOpening missing')
		local boxId, count = Products.boxOpen(key)
		local box = boxId and Shoes.BoxById[boxId]
		assert(box and box.Robux and ShoeRules.canGrant(box.Robux) == box, 'no shoe box for ' .. tostring(key))
		ShoeOpening.openMany(player, profile, box.Id, count, { Product = key })
		-- (the pairs are in the profile now: nothing after this may fail the grant, or Roblox's retry would give more)
		if opts and opts.From then
			thanks(player, opts, (count > 1 and (count .. ' ' .. box.Name .. 'es') or ('a ' .. box.Name)) .. ', already open')
		elseif count > 1 then
			notice(player, 'Thanks! Your ' .. count .. ' ' .. box.Name .. 'es are open!')
		else
			notice(player, 'Thanks! Your ' .. box.Name .. ' is open!')
		end
	end
	-- (brief 30) the weekly Featured pack: Cash + a timed boost + a box. Everything that can throw (the boost queue's asserts,
	-- the box's checks and roll) runs BEFORE the Cash and the boost are written; the box is last of the risky ones, and
	-- once it has opened only plain assignments follow, so Roblox's retry can never give a part twice.
	local function featuredPack(player, profile, key)
		local entry = Products.ByKey[key]
		assert(entry and Shoes and ShoeRules and ShoeOpening, 'Shoes / ShoeRules / ShoeOpening missing')
		local levels = Products.boostLevels(key)
		assert(#levels > 0, 'no boost for ' .. key)
		local amount = Products.cashAmount(key, Retention.bestStage(profile.Data))
		assert(amount > 0, 'no amount for ' .. key)
		local boxId, count = Products.boxOpen(key)
		local box = boxId and Shoes.BoxById[boxId]
		assert(box and box.Robux and ShoeRules.canGrant(box.Robux) == box, 'no shoe box for ' .. tostring(key))
		local seconds = Products.BoostDurationSeconds or 900
		local t = now()
		local passes = type(profile.Data.Passes) == 'table' and profile.Data.Passes or {}
		local boost = passes.Boost
		for _, level in levels do boost = Boosts.add(boost, level, seconds, t) end -- (pure)
		ShoeOpening.openMany(player, profile, box.Id, count, { Product = key })
		profile.Data.Cash = math.min(1e12, profile.Data.Cash + amount)
		setAttribute(player, 'Cash', profile.Data.Cash)
		passes.Boost = boost
		profile.Data.Passes = passes
		publish(player)
		notice(player, 'Thanks! ' .. entry.Title .. ': +' .. Format.compact(amount) .. ' Cash, ' .. levels[1] .. 'x Power for ' .. math.floor(seconds / 60 + 0.5) .. ' min and your ' .. box.Name .. '!')
	end

	local grants = {}
	for _, entry in Products.Catalog do
		if entry.Kind == 'Product' then
			if entry.Section == 'Featured' then
				grants[entry.Key] = featuredPack
			elseif entry.Section == 'Power' then
				grants[entry.Key] = powerPack
			elseif entry.Section == 'Cash' then
				grants[entry.Key] = cashPack
			elseif entry.Section == 'Box' then
				grants[entry.Key] = shoeBox
			elseif type(entry.Offline) == 'number' then
				grants[entry.Key] = offlineX2
			elseif entry.Section == 'Streak' then
				grants[entry.Key] = restoreStreak
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
-- why ('nogrant': no grant for that key; else the grant's error: nothing was recorded). gift = { Player, Profile }: the
-- grant goes to that player (told "<buyer> gifted you ..."), the receipt id stays in the BUYER's profile.
function StoreReceipts.apply(grants, player, profile, key, purchaseId, gift)
	local receipts = profile.Data.ProcessedReceipts
	if type(receipts) ~= 'table' then
		receipts = {}
		profile.Data.ProcessedReceipts = receipts
	end
	if table.find(receipts, purchaseId) then return true, 'had' end
	local grant = key and grants[key]
	if not grant then return false, 'nogrant' end
	local ok, err
	if gift then
		ok, err = pcall(grant, gift.Player, gift.Profile, key, { From = player, BuyerProfile = profile })
	else
		ok, err = pcall(grant, player, profile, key)
	end
	if not ok then return false, tostring(err) end
	table.insert(receipts, purchaseId)
	while #receipts > StoreReceipts.Kept do table.remove(receipts, 1) end
	return true, 'granted'
end

-- (brief 30) The chosen gift targets: gifts[buyerUserId] = { Id, Key, At }. setGift stores one (or clears it: targetId nil
-- or 0), refusing what cannot be gifted; giftFor reads it back at the receipt: the target player and profile when the
-- choice is for this product, fresh (GiftFresh) and the player is still here with a loaded profile, else nil and why
-- ('none', 'otherkey', 'stale', 'gone', 'noprofile').
function StoreReceipts.setGift(gifts, buyerId, targetId, key, now)
	if type(buyerId) ~= 'number' then return false, 'badbuyer' end
	if targetId == nil or targetId == 0 then
		gifts[buyerId] = nil
		return true, 'cleared'
	end
	if type(targetId) ~= 'number' or targetId ~= targetId or targetId == buyerId then return false, 'badtarget' end
	if type(key) ~= 'string' or not Products.giftable(key) then return false, 'notgiftable' end
	gifts[buyerId] = { Id = targetId, Key = key, At = now }
	return true, 'set'
end
function StoreReceipts.giftFor(gifts, buyerId, key, now, playerOf, profileOf)
	local g = gifts[buyerId]
	if not g then return nil, 'none' end
	if g.Key ~= key then return nil, 'otherkey' end
	if now - g.At > StoreReceipts.GiftFresh or now < g.At - 5 then return nil, 'stale' end
	local target = playerOf(g.Id)
	if not target then return nil, 'gone' end
	local profile = profileOf(target)
	if not profile then return nil, 'noprofile' end
	return target, profile
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
-- push(player) (Data.push), grants (StoreReceipts.grants(ctx)), wait (seconds, optional); brief 30: gifts (the table
-- setGift fills), now() (os.time), notice(player, text).
function StoreReceipts.process(info, deps)
	local player = deps.playerOf(info.PlayerId)
	local profile = player and deps.profileOf(player)
	if not profile then return Enum.ProductPurchaseDecision.NotProcessedYet end
	local key = Products.keyFor('Product', info.ProductId)
	local purchaseId = tostring(info.PurchaseId)
	local function tell(p, text) if deps.notice and p then pcall(deps.notice, p, text) end end
	-- (brief 30) where does a gift-able purchase go? To the chosen player if they are still here, else to the buyer.
	local gift, giftWhy, targetName
	if deps.gifts and key and Products.giftable(key) and deps.gifts[player.UserId] then
		local now = deps.now and deps.now() or os.time()
		local target, tprofile
		target, tprofile = StoreReceipts.giftFor(deps.gifts, player.UserId, key, now, deps.playerOf, deps.profileOf)
		giftWhy = tprofile
		if target then
			gift = { Player = target, Profile = tprofile }
			targetName = tostring(target.DisplayName or target.Name or 'them')
			giftWhy = nil
		end
	end
	local ok, why = StoreReceipts.apply(deps.grants, player, profile, key, purchaseId, gift)
	if not ok and gift then
		-- the receiver's grant failed (nothing was written): the buyer gets it instead, never nothing for Robux
		warn('[StoreService] Gift ' .. tostring(key) .. ' failed: ' .. why)
		gift = nil
		giftWhy = 'failed'
		ok, why = StoreReceipts.apply(deps.grants, player, profile, key, purchaseId, nil)
	end
	if not ok then
		if why == 'nogrant' then
			warn('[StoreService] No grant for product ' .. tostring(info.ProductId) .. ' (' .. tostring(key) .. ')')
		else
			warn('[StoreService] Grant ' .. tostring(key) .. ' failed: ' .. why)
		end
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	if why == 'granted' then
		if deps.gifts and key and Products.giftable(key) and deps.gifts[player.UserId] then deps.gifts[player.UserId] = nil end
		if gift then
			tell(player, 'Your gift is on its way to ' .. targetName .. '!')
		elseif giftWhy == 'gone' or giftWhy == 'noprofile' then
			tell(player, 'That player left the server, so it is yours instead!')
		elseif giftWhy == 'stale' then
			tell(player, 'The gift took too long to pick, so it is yours instead!')
		elseif giftWhy == 'failed' then
			tell(player, 'The gift could not be delivered, so it is yours instead!')
		end
		if deps.push then
			deps.push(player)
			if gift then deps.push(gift.Player) end
		end
	end
	-- Answer only once a save holding this purchase id has gone through. The receiver's profile is saved too (best effort,
	-- no wait: a slow or leaving receiver never holds the buyer's receipt hostage; ProfileStore saves it anyway).
	local saved = StoreReceipts.confirm(profile, purchaseId, deps.wait)
	if gift and saved and gift.Profile ~= profile and gift.Profile.Save then pcall(function() gift.Profile:Save() end) end
	if saved then return Enum.ProductPurchaseDecision.PurchaseGranted end
	return Enum.ProductPurchaseDecision.NotProcessedYet
end

return StoreReceipts
