-- windows.luau: the scenario shoot.sh runs after tools/checks/feel_base.luau's set-up (the real server and client scripts
-- for one player, the map built). It gives the player a little progress (Power toward the next rebirth, some Cash, a
-- rack of shoes from every rarity), opens each window the way the game does (the HUD's Rebirth square; the Open events
-- of the Store, the inventory and the World window), lets the open motion finish, and dumps that window's ScreenGui to
-- <UI_OUT>/<name>.json with dump.luau's __uiDump. UI_OUT: a global shoot.sh sets in front of the chunk.
do
	local Shoes = require(RS.Shared.Config.Shoes)
	local ok0 = waitFor(function() return P.PlayerGui:FindFirstChild('HoodHUD') ~= nil and P.PlayerGui:FindFirstChild('HoodStore') ~= nil end, 30)
	print('[ui] clients up: ' .. tostring(ok0))
	wall(1)
	-- progress: 4 rebirths (Skip Rebirth shows from 4), 45% of the way to the 5th, some Cash
	local R = 4
	local need = RebirthRules.need(R)
	data.Rebirths = R
	data.Rep = math.floor(need * 0.45)
	data.Cash = 25300
	P:SetAttribute('Rebirths', R)
	P:SetAttribute('RebirthNeed', need)
	P:SetAttribute('RebirthMultiplier', RebirthRules.multiplier(R))
	P:SetAttribute('RebirthNextMultiplier', RebirthRules.multiplier(R + 1))
	P:SetAttribute('Power', data.Rep)
	P:SetAttribute('Cash', data.Cash)
	-- a rack of shoes: two of each rarity (in id order), the first three on
	local byRank = {}
	local ids = {}
	for id in Shoes.ById do table.insert(ids, id) end
	table.sort(ids)
	for _, id in ids do
		local s = Shoes.ById[id]
		local r = s.Rank or 1
		byRank[r] = byRank[r] or {}
		if #byRank[r] < 2 then table.insert(byRank[r], id) end
	end
	data.Shoes = data.Shoes or {}
	data.Shoes.Owned = {}
	data.Shoes.Equipped = {}
	local k = 0
	for r = 1, 8 do
		for _, id in byRank[r] or {} do
			k += 1
			data.Shoes.Owned[id] = (k % 3) + 1
			if #data.Shoes.Equipped < 3 then table.insert(data.Shoes.Equipped, id) end
		end
	end
	local okS, errS = pcall(function() require(fake.ShoeOpening).sync(P, _G.__profile) end)
	if not okS then print('[ui] shoe sync failed: ' .. tostring(errS)) end
	sync()
	wall(0.6)
	local function closeAll()
		P.PlayerGui:SetAttribute('HoodWindow', '')
		sync()
		wall(0.8)
	end
	local function dump(guiName, file)
		local g = P.PlayerGui:FindFirstChild(guiName)
		if not g then print('[ui] no ' .. guiName); return end
		local ok, err = pcall(__uiDump, g, UI_OUT .. '/' .. file .. '.json')
		print('[ui] ' .. file .. ': ' .. (ok and 'dumped' or ('failed ' .. tostring(err))))
	end
	local function openEvent(guiName, ...)
		local g = P.PlayerGui:FindFirstChild(guiName)
		local e = g and g:FindFirstChild('Open')
		if not e then print('[ui] no Open on ' .. guiName); return end
		__fireOn(e, 'Event', ...)
		sync()
	end
	-- Shop
	openEvent('HoodStore')
	wall(4)
	dump('HoodStore', 'shop')
	closeAll()
	-- Rebirth (the HUD's square, like a tap)
	local hud = P.PlayerGui:FindFirstChild('HoodHUD')
	local rb = hud and hud:FindFirstChild('Rebirth', true)
	local hit = rb and (rb:FindFirstChild('Hit', true) or (rb:IsA('GuiButton') and rb))
	if hit then __fireOn(hit, 'Activated'); sync() else print('[ui] no Rebirth square') end
	wall(1.4)
	-- (the harness doesn't tick the count-up's NumberValue: a Power change makes the window show its final numbers)
	P:SetAttribute('Power', data.Rep + 1); sync(); wall(0.4)
	dump('HoodPanels', 'rebirth')
	closeAll()
	-- Shoes (the inventory's Open with 'Shoes', like the HUD's square: the shoe screens draw in ArtWindows' HoodArt gui)
	openEvent('HoodInventory', 'Shoes')
	wall(1.4)
	dump('HoodArt', 'shoes')
	closeAll()
	-- Worlds
	openEvent('HoodWorld')
	wall(1.2)
	dump('HoodWorld', 'worlds')
	closeAll()
	print('[ui] done')
end
