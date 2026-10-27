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
	-- (Oct 27, release check) a window's painted parts on screen (shown fills and words), and its real X pressed: after
	-- the close the screen must hold none of it. Prints [ui] <name> open: N painted / closed by its X: ok | STILL SHOWN.
	local function painted(g)
		if not g or not g.Enabled then return 0 end
		local n = 0
		for _, d in g:GetDescendants() do
			if d:IsA('GuiObject') and d.Visible then
				local up, shown = d.Parent, true
				while up and up ~= g do
					if (up:IsA('GuiObject') and not up.Visible) or (up:IsA('CanvasGroup') and up.GroupTransparency >= 0.99) then shown = false; break end
					up = up.Parent
				end
				local words = (d:IsA('TextLabel') or d:IsA('TextButton')) and d.Text ~= '' and d.TextTransparency < 0.99
				if shown and (d.BackgroundTransparency < 0.99 or words) then n += 1 end
			end
		end
		return n
	end
	local function closeByX(guiName, file)
		local g = P.PlayerGui:FindFirstChild(guiName)
		local open = painted(g)
		local x
		for _, d in (g and g:GetDescendants() or {}) do
			if (d.Name == 'Close' or d.Name == 'CloseButton') and d:IsA('GuiObject') and d.Visible then x = d; break end
		end
		local hit = x and (x:FindFirstChild('Hit', true) or (x:IsA('GuiButton') and x))
		if hit then __fireOn(hit, 'Activated'); sync() end
		wall(1)
		local left = painted(g)
		print(('[ui] %s open: %d painted / closed by its X: %s'):format(file, open, not hit and 'NO X FOUND' or (left == 0 and 'ok' or ('STILL SHOWN (' .. left .. ' painted)'))))
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
	closeByX('HoodStore', 'shop')
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
	closeByX('HoodPanels', 'rebirth')
	closeAll()
	-- Shoes (the inventory's Open with 'Shoes', like the HUD's square: the shoe screens draw in ArtWindows' HoodArt gui)
	openEvent('HoodInventory', 'Shoes')
	wall(1.4)
	dump('HoodArt', 'shoes')
	closeByX('HoodArt', 'shoes')
	closeAll()
	-- Worlds
	openEvent('HoodWorld')
	wall(1.2)
	dump('HoodWorld', 'worlds')
	closeByX('HoodWorld', 'worlds')
	closeAll()
	print('[ui] done')
end
