-- (brief 22, UI4) The inventory's and the World window's pure rules: Shared/InventoryKit (search, stacking, the Index,
-- the boost queue, passes, guns, worlds) and StageRules.travelTarget (where the LOBBY / FURTHEST pads and the World
-- window's trips send you).
return function(t)
	local RS = game.ReplicatedStorage
	local IK = require(RS.Shared.InventoryKit)
	local Shoes = require(RS.Shared.Config.Shoes)
	local ShoeRules = require(RS.Shared.ShoeRules)
	local Products = require(RS.Shared.Config.Products)
	local Guns = require(RS.Shared.Config.Guns)
	local StageRules = require(RS.Shared.StageRules)
	local e = t.expect

	t.test('search: every word of the query, any case, plain text; blank matches all', function()
		e.truthy(IK.matches('Red Rocket', 'rock'))
		e.truthy(IK.matches('Red Rocket', '  RED  '))
		e.truthy(IK.matches('Red Rocket', 'rocket red'))
		e.falsy(IK.matches('Red Rocket', 'red canvas'))
		e.truthy(IK.matches('Red Rocket', ''))
		e.truthy(IK.matches('Red Rocket', '   '))
		e.truthy(IK.matches('Red Rocket', nil))
		e.falsy(IK.matches('Red Rocket', '%a'))
		e.truthy(IK.matches('+1 Infinity', '+1'))
		e.truthy(IK.matches("King's Crown", "king's"))
		e.falsy(IK.matches(nil, 'x'))
	end)

	t.test('tabs: the four tabs in order, and any spelling the HUD might pass', function()
		local ids = {}
		for _, tab in IK.Tabs do table.insert(ids, tab.Id) end
		e.equal(table.concat(ids, ','), 'Guns,Shoes,Items,Boxes')
		e.equal(IK.tabId('Shoes'), 'Shoes')
		e.equal(IK.tabId('your shoes'), 'Shoes')
		e.equal(IK.tabId(' GUNS '), 'Guns')
		e.equal(IK.tabId('Items'), 'Items')
		e.equal(IK.tabId('Boxes'), 'Boxes')
		e.equal(IK.tabId('Rebirth'), nil)
		e.equal(IK.tabId(42), nil)
	end)

	t.test('stack: one entry per shoe with pairs not on, duplicates counted, best first', function()
		local rack = ShoeRules.fromAttributes('RedRocket:1,Checkmate:4,NeonBomb:3,MidnightChrome:2,GoldenHour:1', 'GoldenHour,MidnightChrome,NeonBomb', 0)
		local list = IK.stack(rack)
		local ids = {}
		for _, x in list do table.insert(ids, x.Id .. 'x' .. x.Copies) end
		-- GoldenHour's only pair is on, so it shows only in the Equipped row
		e.equal(table.concat(ids, ','), 'MidnightChromex1,NeonBombx2,Checkmatex4,RedRocketx1')
		e.equal(list[2].On, 1)
		e.equal(list[2].Total, 3)
		e.equal(#IK.stack(ShoeRules.new()), 0)
	end)

	t.test('search over the stack keeps the order and filters by shoe name', function()
		local rack = ShoeRules.fromAttributes('RedRocket:2,Checkmate:4,FreshCanvas:1', '', 0)
		local hits = IK.search(IK.stack(rack), 'rock')
		local ids = {}
		for _, x in hits do table.insert(ids, x.Id) end
		e.equal(table.concat(ids, ','), 'RedRocket')
		e.equal(#IK.search(IK.stack(rack), ''), 3)
		e.equal(#IK.search(IK.stack(rack), 'zzz'), 0)
	end)

	t.test('index: every World 1 shoe box by box in dais order, owned or not, with the counts', function()
		local rack = ShoeRules.fromAttributes('RedRocket:2,GoldenHour:1', '', 0)
		local idx = IK.index(1, rack)
		local boxes = {}
		for _, row in idx.Boxes do table.insert(boxes, row.Box.Id .. ' ' .. row.Owned .. '/' .. row.Total) end
		e.equal(table.concat(boxes, ', '), 'Street 1/6, Graffiti 0/6, Exclusive 0/5, Grail 1/5')
		e.equal(idx.Total, 22)
		e.equal(idx.Owned, 2)
		e.equal(idx.Boxes[1].Shoes[2].Id, 'RedRocket')
		e.truthy(idx.Boxes[1].Shoes[2].Owned)
		e.equal(idx.Boxes[1].Shoes[2].Copies, 2)
		e.falsy(idx.Boxes[1].Shoes[1].Owned)
		-- every shoe once, and only World 1's
		local seen = {}
		for _, row in idx.Boxes do for _, s in row.Shoes do e.falsy(seen[s.Id]); seen[s.Id] = true; e.equal(Shoes.ById[s.Id].World, 1) end end
		e.equal(IK.index(1, nil).Owned, 0)
	end)

	t.test('boosts: the running one first, the queued ones after it with their own time, the party last', function()
		local now = 1000
		local list = IK.boosts('3:1600,2:2500', now, 1300)
		e.equal(#list, 3)
		e.equal(list[1].Level, 3); e.equal(list[1].Left, 600); e.truthy(list[1].Running)
		e.equal(list[2].Level, 2); e.equal(list[2].Left, 900); e.falsy(list[2].Running)
		e.truthy(list[3].Party); e.equal(list[3].Left, 300)
		-- finished or malformed entries are skipped; none at all is an empty list
		e.equal(#IK.boosts('3:900,junk,2:1500', now, 0), 1)
		e.equal(IK.boosts('3:900,junk,2:1500', now, 0)[1].Left, 500)
		e.equal(#IK.boosts('', now, nil), 0)
		e.equal(#IK.boosts(nil, now, 999), 0)
	end)

	t.test('time text: m:ss under an hour, h:mm:ss over, never negative', function()
		e.equal(IK.timeText(547), '9:07')
		e.equal(IK.timeText(59), '0:59')
		e.equal(IK.timeText(3723), '1:02:03')
		e.equal(IK.timeText(-5), '0:00')
		e.equal(IK.timeText(nil), '0:00')
	end)

	t.test('passes: every Store pass once, the ones you own first', function()
		local list = IK.passes({ Pass_VIP = true, Pass_Lucky = false })
		local n = 0
		for _, entry in Products.Catalog do if entry.Kind == 'Pass' then n += 1 end end
		e.equal(#list, n)
		e.equal(list[1].Entry.Key, 'VIP')
		e.truthy(list[1].Owned)
		for i = 2, #list do e.falsy(list[i].Owned) end
		local list2 = IK.passes(function(k) return k == 'Pass_DoubleRep' end)
		e.equal(list2[1].Entry.Key, 'DoubleRep')
	end)

	t.test('guns: the whole ladder with Equipped / Owned / Locked; the starter is always yours', function()
		local list = IK.guns('Pistol,Revolver,Uzi', 'Revolver')
		e.equal(#list, #Guns.List)
		e.equal(list[1].State, 'Owned')
		e.equal(list[2].State, 'Equipped')
		e.equal(list[3].State, 'Owned')
		e.equal(list[4].State, 'Locked')
		-- junk in, the starter equipped
		local junk = IK.guns('Nope,,', 'Diamond')
		e.equal(junk[1].State, 'Equipped')
		e.equal(junk[10].State, 'Locked')
	end)

	t.test('worlds: World 1 has the Lobby and your furthest stage, worlds 2-5 are coming', function()
		local w = IK.worlds(3)
		e.equal(#w, 5)
		e.truthy(w[1].Open)
		e.equal(w[1].Trips[1].Target, 'Lobby')
		e.truthy(w[1].Trips[1].Open)
		e.equal(w[1].Trips[2].Target, 'Furthest')
		e.equal(w[1].Trips[2].Text, 'Stage 3')
		e.truthy(w[1].Trips[2].Open)
		for i = 2, 5 do e.falsy(w[i].Open); e.equal(#w[i].Trips, 0) end
		local fresh = IK.worlds(nil)
		e.falsy(fresh[1].Trips[2].Open)
		e.equal(fresh[1].Trips[2].Text, 'Stage 1')
	end)

	t.test('splat colours: the rarity colour, Common the warm beige, Secret flagged for the rainbow', function()
		local common = IK.rarityColor('FreshCanvas')
		e.equal(common, IK.SplatColor.Common)
		local rare, secret = IK.rarityColor('RedRocket')
		e.equal(rare, Shoes.RarityById[Shoes.ById.RedRocket.Rarity].Color)
		e.falsy(secret)
		local box = Shoes.BoxById.Street
		local _, rainbow = IK.rarityColor(box.Shoes[#box.Shoes])
		e.truthy(rainbow)
		-- an unknown id falls back to Common, never errors
		e.equal(IK.rarityColor('NoSuchShoe'), IK.SplatColor.Common)
	end)

	t.test('fit: the composition fits PC and phone screens, and labels stay readable on phones', function()
		for _, size in { Vector2.new(1280, 720), Vector2.new(844, 390), Vector2.new(1920, 1080) } do
			local s, rootW, rootH = IK.scaleFor(size)
			e.truthy(s > 0)
			e.truthy(IK.Layout.Fit.W * s <= rootW)
			e.truthy(IK.Layout.Fit.H * s <= rootH)
		end
		-- readable: never under the design size; on a small scale grows to the dp floor (cap ~0.7 em)
		e.equal(IK.readable({ Scale = 1 }, 17, 10), 17)
		e.equal(IK.readable({ Scale = 0.5 }, 17, 10), 29)
		e.equal(IK.readable(nil, 17, 10), 17)
	end)

	t.test('player list: hidden while any window is open, back when the last closes; UIKit.HidePlayerList leaves it alone', function()
		local Kit = require(RS.Shared.UIKit)
		local calls = {}
		local realSet, realHide = IK.setPlayerList, Kit.HidePlayerList
		IK.setPlayerList = function(shown) table.insert(calls, shown) end
		local ok, err = pcall(function()
			Kit.HidePlayerList = false
			IK.coverPlayerList('Inventory', true)
			IK.coverPlayerList('World', true)
			IK.coverPlayerList('Inventory', false)
			e.equal(calls[#calls], false) -- the World window is still open
			IK.coverPlayerList('World', false)
			e.equal(calls[#calls], true)
			-- HidePlayerList on: the HUD hid it for good; the windows never touch it
			table.clear(calls)
			Kit.HidePlayerList = true
			IK.coverPlayerList('Inventory', true)
			IK.coverPlayerList('Inventory', false)
			e.equal(#calls, 0)
		end)
		IK.setPlayerList, Kit.HidePlayerList = realSet, realHide
		IK.coverPlayerList('Inventory', false)
		IK.coverPlayerList('World', false)
		if not ok then error(err, 0) end
	end)

	t.test('travel: Lobby always, Furthest only past a cleared gate (the furthest), nothing else', function()
		local gates = { { Stage = 1, WallId = 'W1', Z = -20 }, { Stage = 2, WallId = 'W2', Z = -56 }, { Stage = 3, WallId = 'W3', Z = -92 } }
		e.equal(StageRules.travelTarget(gates, {}, 'Lobby'), 'Lobby')
		local none, why = StageRules.travelTarget(gates, {}, 'Furthest')
		e.equal(none, nil); e.equal(why, 'locked')
		e.equal(StageRules.travelTarget(gates, { W1 = true, W2 = true }, 'Furthest').Stage, 2)
		-- the furthest cleared, whatever the order they were cleared in
		e.equal(StageRules.travelTarget(gates, { W3 = true, W1 = true }, 'Furthest').Stage, 3)
		local bad, why2 = StageRules.travelTarget(gates, { W1 = true }, 'Stage9')
		e.equal(bad, nil); e.equal(why2, 'unknown')
		e.equal(select(2, StageRules.travelTarget(gates, nil, 'Furthest')), 'locked')
	end)
end
