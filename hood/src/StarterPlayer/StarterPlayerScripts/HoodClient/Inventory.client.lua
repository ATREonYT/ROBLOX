-- The inventory window (brief 22, UI4): a 1:1 copy of the user's reference inventory (ref22_pets_window) with our
-- things in its slots. The HUD's Shoes, Guns and Items squares open it on their tab (PlayerGui.HoodInventory.Open,
-- a BindableEvent: Open:Fire('Guns' | 'Shoes' | 'Items' | 'Boxes'); the tab it already shows closes it).
--   header   cyan studded, the backpack overflowing at the left, the tab's name, a "Search..." box (filters every tab
--            by name), the red X
--   tabs     down the left side: Guns, Your Shoes, Items, Boxes (the open one brighter and bigger)
--   Shoes    "Equipped n/3": the pairs you have on over their rarity splats with their bonus, and a black "+1" splat
--            (tap it to buy the +1 Shoe Slot pass; gone once you own it); then every pair you own, duplicates stacked
--            ("x2"), best first. Tap a pair to put it on, tap one above to take it off.
--            Under the window: Index (every World 1 shoe: yours in colour, the rest as black silhouettes) and the bar:
--            the red X = recycle mode (tap a spare pair twice to recycle it for Cash), the star = equip your best
--   Guns     the gun you use, then every gun of the ladder (yours in colour, the rest dark with their price); tap one
--            of yours to hold it (GunService's EquipGun works anywhere for a gun you own, brief 23); guns are bought
--            at the ARMORY
--   Items    your timed boosts (the running one and the queued ones, with the time left) and the game passes (yours in
--            colour; tap another to see it in the Store)
--   Boxes    World 1's four shoe boxes, each with its shoes and their chances, and how to get it
-- It only asks the servers (ShoeService's ShoeAction remote) and reads player attributes: ShoesOwned / ShoesEquipped
-- (ShoeService), OwnedGuns / EquippedGun (GunService), Pass_<Key>, BoostQueue, PowerBoost, BoostEnds, PartyEnds
-- (StoreService). Sets PlayerGui `ShoesNew` (pairs unboxed since you last looked: the HUD's red "!") and `HoodWindow`
-- = 'Inventory' while open (one window at a time). Look and rules: Shared/InventoryKit.
local Players = game:GetService('Players')
local RS = game:GetService('ReplicatedStorage')
local MarketplaceService = game:GetService('MarketplaceService')

local Shared = RS:WaitForChild('Shared')
local Kit = require(Shared.UIKit)
local Motion = require(Shared.UIMotion)
local Net = require(Shared.Net)
local Format = require(Shared.Format)
local Shoes = require(Shared.Config.Shoes)
local ShoeRules = require(Shared.ShoeRules)
local Products = require(Shared.Config.Products)
local Guns = require(Shared.Config.Guns)
local IK = require(Shared.InventoryKit)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild('PlayerGui')
local L = IK.Layout
local S = L.Slot
local px = UDim2.fromOffset
local hex = Kit.hex
local label = IK.label
local blank = IK.blank

local gui, root, fitRoot = Kit.screen('HoodInventory', nil, 8) -- (8: over the goal line, like the Store's window)
IK.fullScreen(gui)
local openEvent = Instance.new('BindableEvent')
openEvent.Name = 'Open'
openEvent.Parent = gui

local W = IK.frame(root, { Name = 'Inventory', Title = 'Shoes' })
W.Overlay.Visible = false
-- taps beside the window close it; taps on it stop there
local backdrop = Kit.new('TextButton', { Name = 'Backdrop', Text = '', AutoButtonColor = false, BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 20, Parent = W.Overlay })
Kit.new('TextButton', { Name = 'Sink', Text = '', AutoButtonColor = false, BackgroundTransparency = 1, Position = px(L.Fit.X, 0), Size = px(L.W, L.H), ZIndex = 21, Parent = W.Pop })

local state = { Tab = 'Shoes', Index = false, Delete = false, Query = '' }
local isOpen = false

---------------------------------------------------------------------------------------------- small helpers
local function myRack()
	return ShoeRules.fromAttributes(player:GetAttribute('ShoesOwned'), player:GetAttribute('ShoesEquipped'), player:GetAttribute('ShoesOpened'))
end
local function shoeName(id) local s = Shoes.ById[id]; return s and s.Name or tostring(id) end
-- Pairs that can be on at once: ShoeService's ShoesMax (4 with the +1 Shoe Slot pass), else the rule's 3.
local function maxEquipped()
	local m = player:GetAttribute('ShoesMax')
	return type(m) == 'number' and m >= 1 and m <= 8 and math.floor(m) or ShoeRules.MaxEquipped
end
-- A box's odds for this player (a Lucky owner's are better: ShoeRules.chances(boxId, lucky) once SHOP2 has it).
local function chancesOf(box)
	local lucky = player:GetAttribute('Pass_Lucky') == true
	local ok, list = pcall(ShoeRules.chances, box.Id, lucky)
	local out = {}
	if ok and type(list) == 'table' and #list == #box.Shoes then
		for i, e in list do out[i] = type(e) == 'table' and e.Chance or box.Chances[i] end
		return out
	end
	return box.Chances
end

-- A short line in the gap between the Index button and the bar (answers: "coming soon", "take it off first"...).
local sayLabel = label({ Name = 'Say', Text = '', TextSize = 24, StrokeThickness = 3, TextColor3 = hex('5AE0FF'), AnchorPoint = Vector2.new(0.5, 0.5), Position = px(L.Fit.X + (L.Index.W + L.Bar.X) / 2, L.Index.Y + 32), Size = px(L.Bar.X - L.Index.W - 16, 60), ZIndex = 40, Parent = W.Pop })
sayLabel.TextWrapped = true
local saying = 0
local function say(text, color)
	saying += 1
	local mine = saying
	sayLabel.Text = text
	sayLabel.TextColor3 = color or hex('5AE0FF')
	Motion.pop(sayLabel, 0.12)
	task.delay(3, function() if mine == saying then sayLabel.Text = '' end end)
end

local function buyPass(key)
	local entry = Products.ByKey[key]
	if not Products.canBuy(key) then
		say('Coming soon!')
		return
	end
	pcall(function()
		if entry.Kind == 'Pass' then
			MarketplaceService:PromptGamePassPurchase(player, Products.idOf(key))
		else
			MarketplaceService:PromptProductPurchase(player, Products.idOf(key))
		end
	end)
end
local function openStore(at)
	local storeGui = playerGui:FindFirstChild('HoodStore')
	local open = storeGui and storeGui:FindFirstChild('Open')
	if open and open:IsA('BindableEvent') then open:Fire(at) else say('Loading...') end
end

-- Icons hold live models, so each is kept (per place it shows in) and moved into the rebuilt page.
local iconCache = {}
local function cached(key, make)
	local h = iconCache[key]
	if not h then
		h = make()
		h:SetAttribute('CacheKey', key)
		iconCache[key] = h
	end
	return h
end

---------------------------------------------------------------------------------------------- the page
local page -- the tab's content, rebuilt when what it shows changes
local function newPage()
	if page then
		for _, d in page:GetDescendants() do
			if d:GetAttribute('CacheKey') then d.Parent = nil end
		end
		page:Destroy()
	end
	page = blank({ Name = 'Page', Size = px(L.W, L.H), ZIndex = 24, Parent = W.Content })
	return page
end
-- The x of slot i of n in a row centred in the window.
local function rowX(i, n) return L.W / 2 + (i - (n + 1) / 2) * L.Pitch end
-- (the row above uses the grid's columns: four, from the first; a shorter row fills them from the left)
local function rowSlot(props, i, n)
	n = math.max(n, ShoeRules.MaxEquipped + 1)
	props.Position = px(rowX(i, n) - S.W / 2, L.RowY - S.CY)
	props.Jitter = props.Jitter or i + 2
	props.ZIndex = props.ZIndex or 26
	local holder, hit = IK.slot(props)
	holder.Parent = page
	return holder, hit
end
-- The grid under the second line: a scrolling grid, left-aligned under the Equipped row's first column.
local function grid(top, firstX, centre, pitch)
	local y = top or L.GridY
	local left = L.Outline + 6
	local g = Kit.new('ScrollingFrame', {
		Name = 'Grid', BackgroundTransparency = 1, BorderSizePixel = 0, Position = px(L.Outline + 6, y), Size = px(L.W - 2 * (L.Outline + 6), L.H - y - L.Outline - 4), ZIndex = 25,
		ScrollBarThickness = 6, ScrollBarImageColor3 = Color3.new(1, 1, 1), ScrollingDirection = Enum.ScrollingDirection.Y,
		AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(), Parent = page,
	})
	-- (UICRITIC2 r1: the grid starts under the Equipped row's first column, left-aligned like a list)
	Kit.new('UIGridLayout', { CellSize = px(S.W, S.H), CellPadding = px((pitch or L.Pitch) - S.W, 4), SortOrder = Enum.SortOrder.LayoutOrder, HorizontalAlignment = Enum.HorizontalAlignment.Left, Parent = g })
	Kit.new('UIPadding', { PaddingTop = UDim.new(0, math.max(0, (centre or 402) - S.CY - y)), PaddingBottom = UDim.new(0, 8), PaddingLeft = UDim.new(0, math.max(0, (firstX or rowX(1, ShoeRules.MaxEquipped + 1)) - S.W / 2 - left)), Parent = g })
	return g
end
local function emptyLine(text, y)
	local t = label({ Name = 'Empty', Text = text, TextSize = 26, StrokeThickness = 3, AnchorPoint = Vector2.new(0.5, 0.5), Position = px(L.W / 2, y), Size = px(L.W - 80, 70), ZIndex = 27, Parent = page })
	t.TextWrapped = true
	return t
end
-- A name tag over a slot while the pointer is on it (or for a moment after a tap): the reference shows no names.
local function nameTag(holder, hit, text, color)
	local tag = label({ Name = 'NameTag', Text = text, TextSize = 18, StrokeThickness = 2.5, TextColor3 = color or Color3.new(1, 1, 1), AnchorPoint = Vector2.new(0.5, 1), Position = px(S.W / 2, S.CY - 50), Size = px(S.W + 40, 22), ZIndex = 40, Parent = holder })
	tag.Visible = false
	hit.MouseEnter:Connect(function() tag.Visible = true end)
	hit.MouseLeave:Connect(function() tag.Visible = false end)
	return function()
		tag.Visible = true
		task.delay(1.6, function() if tag.Parent then tag.Visible = false end end)
	end
end
local function press(holder)
	if holder.Parent then Motion.pop(holder, 0.08) end
end

---------------------------------------------------------------------------------------------- Your Shoes
local stickers = {} -- pairs marked NEW! while this look at your shoes lasts
local newIds = {} -- pairs unboxed since you last looked
local confirm = { Id = nil, Until = 0 }
local refresh -- (forward)

local function shoeSlot(id, props)
	local color, rainbow = IK.rarityColor(id)
	props.Color = color
	props.Kind = rainbow and 'rainbow' or nil
	return props
end

local function paintShoes()
	newPage()
	local rack = myRack()
	local on = ShoeRules.equippedList(rack)
	local max = maxEquipped()
	local plusShown = player:GetAttribute('Pass_ExtraEquip') ~= true
	IK.titleLine(page, 'Equipped  ' .. #on .. '/' .. max, L.TitleY, { ZIndex = 26 })
	local n = max + (plusShown and 1 or 0)
	local matchedOn = 0
	for i = 1, max do
		local id = on[i]
		if id then
			-- (a search dims the pairs on that don't match it, UICRITIC2 r1 #5)
			local match = IK.matches(shoeName(id), state.Query)
			if match then matchedOn += 1 end
			local holder, hit = rowSlot(shoeSlot(id, {
				Name = 'On' .. i, Value = ShoeRules.bonusText(Shoes.bonus(id)), Dim = not match,
				Icon = cached('on' .. i .. ':' .. id, function() return IK.shoeIcon(id, S.Icon, { ZIndex = 27 }) end),
			}), i, n)
			IK.dim(holder, not match)
			local show = nameTag(holder, hit, shoeName(id))
			hit.Activated:Connect(function()
				show()
				press(holder)
				if state.Delete then
					say("It's on!")
					return
				end
				Net.get('ShoeAction'):FireServer('Unequip', id)
			end)
		else
			local holder, hit = rowSlot({ Name = 'Free' .. i, Color = hex('8A94A8'), Dim = true, Text = '', ZIndex = 26 }, i, n)
			hit.Activated:Connect(function() press(holder) end)
		end
	end
	-- the reference's black "+3" splat: more slots to buy (the +1 Shoe Slot pass), until you have it
	if plusShown then
		local plus, plusHit = rowSlot({ Name = 'Plus', Kind = 'black', Text = '+1', TextSize = L.ValueSize, SplatRotation = 12, SplatSize = 156 }, n, n)
		plusHit.Activated:Connect(function()
			press(plus)
			buyPass('ExtraEquip')
		end)
	end
	IK.divider(page, { Name = 'Line2', Fade = 'both', Position = px(L.Outline + 6, L.Line2Y), Size = px(L.W - 2 * (L.Outline + 6), 7), ZIndex = 25 })
	local all = IK.stack(rack)
	local list = IK.search(all, state.Query)
	local g = grid()
	if ShoeRules.count(rack) == 0 then
		emptyLine('No shoes yet!', 410)
	elseif #list == 0 and matchedOn == 0 and state.Query ~= '' then
		emptyLine('No match', 410)
	end
	for order, e in list do
		local id = e.Id
		local canRecycle = ShoeRules.canRecycle(rack, id)
		local value = ShoeRules.bonusText(Shoes.bonus(id))
		local valueColor
		if state.Delete then
			if confirm.Id == id and os.clock() < confirm.Until then
				value, valueColor = 'Sure?', hex('FF5A5A')
			elseif canRecycle then
				value, valueColor = '+' .. Format.compact(ShoeRules.refund(id)), hex('7CFF4F')
			else
				value, valueColor = 'On', hex('B8C0CC')
			end
		end
		local holder, hit = IK.slot(shoeSlot(id, {
			Name = id, LayoutOrder = order, Value = value, ValueColor = valueColor, Badge = 'x' .. e.Copies, ZIndex = 26,
			Icon = cached('grid:' .. id, function() return IK.shoeIcon(id, S.Icon, { ZIndex = 27 }) end),
		}))
		holder.Parent = g
		if stickers[id] then
			label({ Name = 'New', Text = 'NEW!', TextSize = 20, TextColor3 = hex('7CFF4F'), AnchorPoint = Vector2.new(0.5, 0.5), Position = px(30, 18), Size = px(60, 24), Rotation = -10, ZIndex = 35, Parent = holder })
		end
		if state.Delete and canRecycle then
			-- the reference's red X block, small, on every pair you could recycle
			local x = label({ Name = 'Recycle', Text = 'X', TextSize = 22, TextColor3 = hex('FF2A3A'), AnchorPoint = Vector2.new(0.5, 0.5), Position = px(26, 22), Size = px(30, 30), ZIndex = 35, Parent = holder })
			x.Rotation = -8
		end
		local show = nameTag(holder, hit, shoeName(id))
		hit.Activated:Connect(function()
			show()
			press(holder)
			if state.Delete then
				if not canRecycle then
					say("It's on!")
				elseif confirm.Id == id and os.clock() < confirm.Until then
					confirm.Id = nil
					Net.get('ShoeAction'):FireServer('Recycle', id)
				else
					confirm.Id, confirm.Until = id, os.clock() + 3
					say('Again: +' .. Format.compact(ShoeRules.refund(id)) .. ' Cash', hex('FF8A8A'))
					task.delay(3.05, function() if isOpen then refresh(true) end end)
					refresh(true)
				end
				return
			end
			local ok, why = ShoeRules.canEquip(rack, id, maxEquipped())
			if ok then
				Net.get('ShoeAction'):FireServer('Equip', id)
			elseif why == 'full' then
				say('Slots full!')
			elseif why == 'all' then
				Net.get('ShoeAction'):FireServer('Unequip', id)
			end
		end)
	end
end

---------------------------------------------------------------------------------------------- Index
local function paintIndex()
	newPage()
	local rack = myRack()
	local idx = IK.index(Shoes.ActiveWorld, rack)
	local top = L.BodyTop + L.Outline + 2
	local list = Kit.new('ScrollingFrame', {
		Name = 'IndexList', BackgroundTransparency = 1, BorderSizePixel = 0, Position = px(L.Outline + 6, top), Size = px(L.W - 2 * (L.Outline + 6), L.H - top - L.Outline - 4), ZIndex = 25,
		ScrollBarThickness = 6, ScrollBarImageColor3 = Color3.new(1, 1, 1), ScrollingDirection = Enum.ScrollingDirection.Y,
		AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(), Parent = page,
	})
	Kit.new('UIListLayout', { Padding = UDim.new(0, 0), SortOrder = Enum.SortOrder.LayoutOrder, Parent = list })
	local innerW = L.W - 2 * (L.Outline + 6)
	for order, row in idx.Boxes do
		local shown = {}
		for _, s in row.Shoes do
			if IK.matches(shoeName(s.Id), state.Query) or IK.matches(row.Box.Name, state.Query) then table.insert(shown, s) end
		end
		if #shown > 0 then
			local section = blank({ Name = row.Box.Id, Size = px(innerW, 214), LayoutOrder = order, ZIndex = 25, Parent = list })
			IK.titleLine(section, row.Box.Name .. '  ' .. row.Owned .. '/' .. row.Total, 30, { Width = innerW, ZIndex = 26, TextSize = 26, LineInset = 4 })
			for i, s in shown do
				local id = s.Id
				local color, rainbow = IK.rarityColor(id)
				local holder, hit = IK.slot({
					Name = id, Color = s.Owned and color or hex('596273'), Kind = s.Owned and rainbow and 'rainbow' or nil, Dim = not s.Owned,
					Value = s.Owned and ShoeRules.bonusText(Shoes.bonus(id)) or '???', ValueColor = not s.Owned and hex('B8C0CC') or nil, ValueSize = 30,
					Badge = s.Copies > 0 and ('x' .. s.Copies) or nil, BadgeSize = 28, ZIndex = 26,
					Icon = cached('idx:' .. id .. (s.Owned and '' or ':dark'), function() return IK.shoeIcon(id, S.Icon - 6, { ZIndex = 27, Locked = not s.Owned }) end),
					Position = px(innerW / 2 + (i - (#shown + 1) / 2) * L.Pitch - S.W / 2, 50),
				})
				holder.Parent = section
				local show = nameTag(holder, hit, s.Owned and shoeName(id) or '???')
				hit.Activated:Connect(function()
					show()
					press(holder)
					if not s.Owned then say(row.Box.Name .. '  ' .. ShoeRules.chanceText(ShoeRules.chanceOf(id, player:GetAttribute('Pass_Lucky') == true))) end
				end)
			end
		end
	end
	if #list:GetChildren() <= 1 then emptyLine('No match', 300) end
end

---------------------------------------------------------------------------------------------- Guns
local function paintGuns()
	newPage()
	local all = IK.guns(player:GetAttribute('OwnedGuns'), player:GetAttribute('EquippedGun'))
	local using
	for _, e in all do if e.State == 'Equipped' then using = e.Gun end end
	IK.titleLine(page, 'Equipped  1/1', L.TitleY, { ZIndex = 26 })
	if using then
		local holder, hit = rowSlot({ Name = 'Using', Color = using.Color, Value = 'x' .. using.Multiplier, Icon = cached('gunOn:' .. using.Id, function() return IK.gunIcon(using.Id, S.Icon, { ZIndex = 27 }) end) }, 1, 2)
		local show = nameTag(holder, hit, using.Name)
		hit.Activated:Connect(function() show(); press(holder) end)
	end
	local plus, plusHit = rowSlot({ Name = 'Armory', Kind = 'black', Text = '+', TextSize = 44, SplatRotation = 12 }, 2, 2)
	plusHit.Activated:Connect(function()
		press(plus)
		say('At the ARMORY')
	end)
	IK.divider(page, { Name = 'Line2', Fade = 'both', Position = px(L.Outline + 6, L.Line2Y), Size = px(L.W - 2 * (L.Outline + 6), 7), ZIndex = 25 })
	local g = grid()
	local cash = player:GetAttribute('Cash')
	cash = type(cash) == 'number' and cash or 0
	local any = false
	for order, e in all do
		local gun = e.Gun
		if IK.matches(gun.Name, state.Query) then
			any = true
			local owned = e.State ~= 'Locked'
			local holder, hit = IK.slot({
				Name = gun.Id, LayoutOrder = order, Color = owned and gun.Color or hex('596273'), Dim = not owned, ZIndex = 26,
				Value = owned and ('x' .. gun.Multiplier) or Kit.short(gun.Cost), ValueColor = (not owned) and (cash >= gun.Cost and hex('7CFF4F') or hex('FFD21A')) or nil,
				Icon = cached('gun:' .. gun.Id .. (owned and '' or ':dark'), function() return IK.gunIcon(gun.Id, S.Icon, { ZIndex = 27, Locked = not owned }) end),
			})
			holder.Parent = g
			if not owned then
				Kit.icon3d('Cash', 30, { AnchorPoint = Vector2.new(1, 0.5), Position = px(S.W / 2 - Kit.textWidth(Kit.short(gun.Cost), L.ValueSize) / 2 + 4, S.CY + 52), ZIndex = 30, Outline = false }).Parent = holder
			end
			local show = nameTag(holder, hit, gun.Name)
			hit.Activated:Connect(function()
				show()
				press(holder)
				if e.State == 'Owned' then
					Net.get('EquipGun'):FireServer(gun.Id) -- (the server says "Equipped ...!"; the gun goes into your hand)
				elseif e.State == 'Locked' then
					say('At the ARMORY')
				end
			end)
		end
	end
	if not any then emptyLine('No match', 410) end
end

---------------------------------------------------------------------------------------------- Items
local boostLabels = {} -- the time-left badges, ticked every second while Items is open
local function boostList()
	local now = os.time()
	local list = IK.boosts(player:GetAttribute('BoostQueue'), now, player:GetAttribute('PartyEnds'))
	-- (before SHOP2's queue: the one running boost)
	if player:GetAttribute('BoostQueue') == nil then
		local ends, level = player:GetAttribute('BoostEnds'), player:GetAttribute('PowerBoost')
		if type(ends) == 'number' and ends > now and type(level) == 'number' and level > 1 then table.insert(list, 1, { Level = level, Left = ends - now, Running = true }) end
	end
	return list
end
local function artIcon(art, size, locked, key)
	local kind, id = string.match(type(art) == 'string' and art or '', '^(%w+):(.+)$')
	return cached(key, function()
		if kind == 'gun' then return IK.gunIcon(id, size, { ZIndex = 27, Locked = locked }) end
		if kind == 'shoe' then return IK.shoeIcon(id, size, { ZIndex = 27, Locked = locked }) end
		if kind == 'box' or kind == 'boxes' then return IK.boxIcon(id, size, { ZIndex = 27, Locked = locked }) end
		return IK.icon({ id or 'Rewards', 'Rewards' }, size, { ZIndex = 27, Locked = locked })
	end)
end
local function paintItems()
	newPage()
	table.clear(boostLabels)
	local boosts = boostList()
	IK.titleLine(page, 'Boosts  ' .. #boosts, L.TitleY, { ZIndex = 26 })
	-- each boost a potion on its splat, "x3" in the corner like a stack and the time left under it (the running one
	-- counting down in green); no boost, no empty slot: just the black "+" (the Store's boosts)
	local shown = math.min(3, #boosts)
	local n = shown + 1
	for i = 1, shown do
		local b = boosts[i]
		local potion = b.Party and { 'Rewards' } or (b.Level >= 3 and { 'PotionGold', 'PowerPack3', 'Power' } or { 'PotionRed', 'DoublePower', 'Power' })
		local holder, hit = rowSlot({
			Name = 'Boost' .. i, Color = b.Party and hex('B26CFF') or b.Level >= 3 and hex('FFC21A') or hex('FF4A4A'),
			Value = IK.timeText(b.Left), ValueColor = b.Running and hex('7CFF4F') or hex('D8E0EA'), Badge = 'x' .. b.Level,
			Icon = cached('boost' .. i .. ':' .. table.concat(potion, ','), function() return IK.icon(potion, S.Icon - 8, { ZIndex = 27 }) end),
		}, i, n)
		local value = holder:FindFirstChild('Value')
		if value then table.insert(boostLabels, { Label = value, Index = i }) end
		local show = nameTag(holder, hit, b.Party and 'Block Party' or (b.Running and 'Running now' or 'Up next'))
		hit.Activated:Connect(function() show(); press(holder) end)
	end
	local plus, plusHit = rowSlot({ Name = 'MoreBoosts', Kind = 'black', Text = '+', TextSize = 44, SplatRotation = 12 }, n, n)
	plusHit.Activated:Connect(function()
		press(plus)
		openStore('Boost')
	end)
	IK.divider(page, { Name = 'Line2', Fade = 'both', Position = px(L.Outline + 6, L.Line2Y), Size = px(L.W - 2 * (L.Outline + 6), 7), ZIndex = 25 })
	-- the passes under their own title, "Gamepasses  n/6" between fading lines like "Equipped  3/3"
	local passes = IK.passes(function(k) return player:GetAttribute(k) end)
	local owned = 0
	for _, p in passes do if p.Owned then owned += 1 end end
	IK.titleLine(page, 'Gamepasses  ' .. owned .. '/' .. #passes, L.PassTitleY, { Name = 'PassTitle', ZIndex = 26 })
	-- (all of them in one row: a tighter pitch, the names fitted to it)
	local pitch = math.min(L.Pitch, math.floor((L.W - 2 * (L.Outline + 6) - S.W) / math.max(1, #passes - 1)) - 1)
	local g = grid(L.PassTitleY + 18, L.W / 2 - (math.min(#passes, 7) - 1) / 2 * pitch, L.PassRowY, pitch)
	local captionFloor = IK.readable(W, 14, 10)
	local any = false
	for order, p in passes do
		local entry = p.Entry
		if IK.matches(entry.Title, state.Query) then
			any = true
			local tone = Kit.Tone[entry.Tone] or Kit.Tone.gold
			local holder, hit = IK.slot({
				Name = entry.Key, LayoutOrder = order, Color = tone.base, Splat = p.Owned, ZIndex = 26, -- (the ones you don't own: bare silhouettes, as the Index's)
				Value = entry.Title, ValueSize = 24, ValueWidth = pitch - 6, ValueColor = not p.Owned and hex('B8C0CC') or nil,
				Badge = p.Owned and 'Yours' or nil, BadgeColor = hex('7CFF4F'), BadgeSize = 20,
				Icon = artIcon(entry.Art, S.Icon - 10, not p.Owned, 'pass:' .. entry.Key .. (p.Owned and '' or ':dark')),
			})
			-- (on a phone the fitted name would be under the 10 dp floor: it keeps that size on two lines instead)
			local name = holder:FindFirstChild('Value')
			if name and name.TextSize < captionFloor then
				name.TextSize, name.TextWrapped = captionFloor, true
				name.Size = px(pitch - 4, captionFloor * 2 + 4)
				name.Position = px(S.W / 2, S.CY + 46 + captionFloor / 2)
			end
			holder.Parent = g
			local show = nameTag(holder, hit, p.Owned and 'Yours!' or 'In the Store')
			hit.Activated:Connect(function()
				show()
				press(holder)
				if not p.Owned then openStore(entry.Key) end
			end)
		end
	end
	if not any then emptyLine('No match', 410) end
end
local function tickBoosts()
	if not (isOpen and state.Tab == 'Items' and not state.Index) or #boostLabels == 0 then return end
	local list = boostList()
	for _, b in boostLabels do
		local e = list[b.Index]
		if e and b.Label.Parent then b.Label.Text = IK.timeText(e.Left) end
	end
end

---------------------------------------------------------------------------------------------- Boxes
local function boxTone(box)
	local c = box.Color
	return { top = c:Lerp(Color3.new(1, 1, 1), 0.32), base = c:Lerp(Color3.new(0, 0, 0), 0.08), lip = c:Lerp(Color3.new(0, 0, 0), 0.32), stroke = c:Lerp(Color3.new(0, 0, 0), 0.7), rim = c:Lerp(Color3.new(1, 1, 1), 0.55), rot = 90 }
end
local function paintBoxes()
	newPage()
	local rack = myRack()
	local top = L.BodyTop + L.Outline + 2
	local list = Kit.new('ScrollingFrame', {
		Name = 'BoxList', BackgroundTransparency = 1, BorderSizePixel = 0, Position = px(L.Outline + 6, top), Size = px(L.W - 2 * (L.Outline + 6), L.H - top - L.Outline - 4), ZIndex = 25,
		ScrollBarThickness = 6, ScrollBarImageColor3 = Color3.new(1, 1, 1), ScrollingDirection = Enum.ScrollingDirection.Y,
		AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(), Parent = page,
	})
	Kit.new('UIListLayout', { Padding = UDim.new(0, 18), SortOrder = Enum.SortOrder.LayoutOrder, HorizontalAlignment = Enum.HorizontalAlignment.Center, Parent = list })
	Kit.new('UIPadding', { PaddingTop = UDim.new(0, 26), PaddingBottom = UDim.new(0, 14), Parent = list })
	local CARD_W, CARD_H = 880, 176
	local any = false
	for order, box in Shoes.boxesForWorld(Shoes.ActiveWorld) do
		local match = IK.matches(box.Name, state.Query)
		for _, id in box.Shoes do match = match or IK.matches(shoeName(id), state.Query) end
		if match then
			any = true
			local card = IK.block({ Name = box.Id, Tone = boxTone(box), Width = CARD_W, Height = CARD_H, Outline = 4.5, RimWidth = 3, StudShade = 0.6, ZIndex = 26 })
			card.LayoutOrder = order
			card.Parent = list
			local body = card.Body
			cached('boxart:' .. box.Id, function() return IK.boxIcon(box.Id, 150, { ZIndex = 30 }) end).Parent = body
			local art = body:FindFirstChild('Box_' .. box.Id)
			art.AnchorPoint = Vector2.new(0, 0.5)
			art.Position = px(-6, CARD_H / 2 + 6)
			label({ Name = 'Title', Text = box.Name, TextSize = 34, StrokeThickness = 4.5, TextXAlignment = Enum.TextXAlignment.Left, Position = px(150, 4), Size = px(400, 44), ZIndex = 31, Parent = body })
			-- the price: green Robux button (a Robux box) or the Cash price (a Cash box: open it on the dais)
			if box.Robux then
				local buy, buyHit = Kit.robuxButton({ Name = 'Buy', Price = box.RobuxPrice, Width = 150, Height = 46, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -12, 0, 8), ZIndex = 31 })
				buy.Parent = body
				Motion.button(buy, function()
					if Products.canBuy(box.Robux) then
						pcall(function() MarketplaceService:PromptProductPurchase(player, Products.idOf(box.Robux)) end)
					else
						say('Coming soon!')
					end
				end)
			else
				local chip = blank({ Name = 'Price', AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -14, 0, 6), Size = px(170, 48), ZIndex = 31, Parent = body })
				Kit.icon3d('Cash', 46, { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 0, 0.5, 0), ZIndex = 32, Outline = false }).Parent = chip
				local t = label({ Name = 'Text', Text = Format.compact(box.Price), TextSize = 32, StrokeThickness = 4, TextXAlignment = Enum.TextXAlignment.Left, Position = px(50, 0), Size = px(120, 48), ZIndex = 32, Parent = chip })
				Kit.new('UIGradient', { Rotation = 90, Color = ColorSequence.new(hex('F0FF8A'), hex('3CCB3C')), Parent = t })
			end
			-- its shoes over their splats with their chances (an unowned Secret stays a "???" silhouette)
			local n = #box.Shoes
			local chances = chancesOf(box)
			for i, id in box.Shoes do
				local shoe = Shoes.ById[id]
				local owned = ShoeRules.copies(rack, id) > 0
				local hidden = shoe.Rank == #Shoes.Rarities and not owned
				local color, rainbow = IK.rarityColor(id)
				local cell = blank({ Name = id, Size = px(104, 120), Position = px(150 + (i - 1) * 118 + (6 - n) * 59, 50), ZIndex = 30, Parent = body })
				-- (the splat's cloud ~1.2x the shoe, centred on it a little low; see InventoryKit.slot)
				IK.splat(112, color, { Kind = rainbow and 'rainbow' or nil, AnchorPoint = Vector2.new(0.5, 0.5), Position = px(50, 54), ZIndex = 30, Rotation = i * 37 % 40 - 20 }).Parent = cell
				local ic = cached('boxshoe:' .. id .. (hidden and ':dark' or ''), function() return IK.shoeIcon(id, 76, { ZIndex = 31, Locked = hidden, Outline = true }) end)
				ic.AnchorPoint = Vector2.new(0.5, 0.5)
				ic.Position = px(52, 46)
				ic.Parent = cell
				label({ Name = 'Chance', Text = ShoeRules.chanceText(chances[i] or 0), TextSize = 24, StrokeThickness = 3, AnchorPoint = Vector2.new(0.5, 0.5), Position = px(52, 98), Size = px(110, 28), ZIndex = 33, Parent = cell })
				local hit = Kit.new('TextButton', { Name = 'Hit', Text = '', AutoButtonColor = false, BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 36, Parent = cell })
				local tag = label({ Name = 'NameTag', Text = hidden and '???' or shoe.Name, TextSize = 16, StrokeThickness = 2.5, AnchorPoint = Vector2.new(0.5, 1), Position = px(52, 4), Size = px(150, 20), ZIndex = 40, Parent = cell })
				tag.Visible = false
				hit.MouseEnter:Connect(function() tag.Visible = true end)
				hit.MouseLeave:Connect(function() tag.Visible = false end)
				hit.Activated:Connect(function()
					tag.Visible = true
					task.delay(1.6, function() if tag.Parent then tag.Visible = false end end)
				end)
			end
			local cardHit = Kit.new('TextButton', { Name = 'CardHit', Text = '', AutoButtonColor = false, BackgroundTransparency = 1, Size = px(150, CARD_H), ZIndex = 35, Parent = card })
			cardHit.Activated:Connect(function()
				press(card)
				if box.Robux then
					if Products.canBuy(box.Robux) then
						pcall(function() MarketplaceService:PromptProductPurchase(player, Products.idOf(box.Robux)) end)
					else
						say('Coming soon!')
					end
				else
					say('At the back of the hall')
				end
			end)
		end
	end
	if not any then emptyLine('No match', 300) end
end

---------------------------------------------------------------------------------------------- tabs, header, bar
local tabButtons = {}
local tabsKey
local selectTab -- (forward)
local function paintTabs()
	-- (the slabs bake their tone in and hold icons: rebuilt only when the open tab changes)
	local labelSize = IK.readable(W, 17, 10)
	local key = state.Tab .. '|' .. tostring(state.Index) .. '|' .. labelSize
	if key == tabsKey and #tabButtons > 0 then return end
	tabsKey = key
	for _, t in tabButtons do t:Destroy() end
	table.clear(tabButtons)
	local y = L.TabTop
	for i, tab in IK.Tabs do
		local on = tab.Id == state.Tab and not state.Index
		local icon = tab.Id == 'Guns' and { 'Gun' } or tab.Id == 'Shoes' and { 'ShoePile', 'Sneaker' } or tab.Id == 'Items' and { 'Backpack', 'Rewards' } or { 'ShoeBox', 'Rewards' }
		local holder = IK.tab({ Name = 'Tab_' .. tab.Id, On = on, Text = tab.Label, Short = tab.Short, Icon = icon, LabelSize = on and labelSize + 2 or labelSize, Position = px(L.Fit.X + 4, y), ZIndex = 21 })
		holder.LayoutOrder = i
		holder.Parent = W.Tabs
		Motion.button(holder, function() selectTab(tab.Id) end)
		table.insert(tabButtons, holder)
		y += (on and L.TabOnH or L.TabH) + L.TabGap
	end
end

-- The bar under the window: the red X (recycle mode) and the star (equip best), on Your Shoes.
local barButtons = {}
local function barButton(name, ids, x, onClick)
	local B = L.Bar
	local holder = blank({ Name = name, AnchorPoint = Vector2.new(0.5, 0.5), Position = px(x, B.H / 2), Size = px(B.IconSize, B.IconSize), ZIndex = 30, Parent = W.Bar })
	local icon = IK.icon(ids, B.IconSize, { ZIndex = 31 })
	icon.Parent = holder
	local hit = Kit.new('TextButton', { Name = 'Hit', Text = '', AutoButtonColor = false, BackgroundTransparency = 1, Position = px(-6, -6), Size = UDim2.new(1, 12, 1, 12), ZIndex = 34, Parent = holder })
	hit.Activated:Connect(function()
		Motion.pop(holder, 0.18)
		onClick()
	end)
	barButtons[name] = holder
	return holder
end
-- (the fallbacks until ICONS' Delete / Favorite renders exist: a red X block and a gold star drawn with frames)
local function drawnX(parent, size)
	for i, rot in { 45, -45 } do
		local f = blank({ Name = 'Bar' .. i, BackgroundTransparency = 0, BackgroundColor3 = Color3.new(1, 1, 1), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = px(size * 0.92, size * 0.34), Rotation = rot, ZIndex = 31, Parent = parent })
		Kit.new('UIGradient', { Rotation = 90 - rot, Color = ColorSequence.new(hex('FF6A8A'), hex('D8123A')), Parent = f })
		Kit.stroke(Kit.Color.black, 3, true, 0, Enum.LineJoinMode.Miter).Parent = f
		Kit.corner(3).Parent = f
	end
end
local function drawnStar(parent, size)
	local t = label({ Name = 'Star', Text = '★', TextSize = math.floor(size * 1.05), StrokeThickness = 3, TextColor3 = hex('FFD21A'), Size = UDim2.fromScale(1.2, 1.2), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.52), ZIndex = 31, Parent = parent })
	Kit.new('UIGradient', { Rotation = 90, Color = ColorSequence.new(hex('FFE860'), hex('FF9A10')), Parent = t })
end
do
	local B = L.Bar
	local function make(name, id, x, draw, onClick)
		if Kit.hasIcon(id) then return barButton(name, { id }, x, onClick) end
		local holder = blank({ Name = name, AnchorPoint = Vector2.new(0.5, 0.5), Position = px(x, B.H / 2), Size = px(B.IconSize, B.IconSize), ZIndex = 30, Parent = W.Bar })
		draw(holder, B.IconSize)
		local hit = Kit.new('TextButton', { Name = 'Hit', Text = '', AutoButtonColor = false, BackgroundTransparency = 1, Position = px(-6, -6), Size = UDim2.new(1, 12, 1, 12), ZIndex = 34, Parent = holder })
		hit.Activated:Connect(function()
			Motion.pop(holder, 0.18)
			onClick()
		end)
		barButtons[name] = holder
		return holder
	end
	make('Delete', 'Delete', B.W / 2 - B.Gap / 2, drawnX, function()
		state.Delete = not state.Delete
		confirm.Id = nil
		saying += 1
		sayLabel.Text = ''
		refresh(true)
	end)
	make('Favorite', 'Favorite', B.W / 2 + B.Gap / 2, drawnStar, function()
		local rack = myRack()
		local best, now = ShoeRules.best(rack, maxEquipped()), ShoeRules.equippedList(rack)
		local same = #best == #now
		for i, id in best do if now[i] ~= id then same = false end end
		if #best == 0 then
			say('No shoes yet!')
		elseif same then
			say('Best pairs on!')
		else
			state.Delete = false
			Net.get('ShoeAction'):FireServer('EquipBest')
		end
	end)
end

local function paintChrome()
	local title = state.Index and 'Index' or (IK.Tabs[1].Title)
	for _, tab in IK.Tabs do
		if tab.Id == state.Tab and not state.Index then title = tab.Title end
	end
	W.Title.Text = title
	W.Bar.Visible = state.Tab == 'Shoes' and not state.Index
	local idxLabel = W.Index.Body:FindFirstChild('Label')
	if idxLabel then idxLabel.Text = state.Index and 'Back' or 'Index' end
	-- recycle mode: the red X block is lit (a bright glow behind it, bigger, tilted) while it's on; no words
	local del = barButtons.Delete
	if del then
		local s = Motion.scaleOf(del)
		s.Scale = state.Delete and 1.2 or 1
		del.Rotation = state.Delete and -10 or 0
		local glow = del:FindFirstChild('Glow')
		if state.Delete and not glow then
			glow = blank({ Name = 'Glow', BackgroundTransparency = 0.35, BackgroundColor3 = hex('FFE24A'), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(1.25, 1.25), ZIndex = 29, Parent = del })
			Kit.corner(UDim.new(0.5, 0)).Parent = glow
			Kit.stroke(Kit.Color.black, 3, true).Parent = glow
		elseif not state.Delete and glow then
			glow:Destroy()
		end
	end
	paintTabs()
end

local shownKey
local function keyNow()
	if state.Index then return 'index|' .. tostring(player:GetAttribute('ShoesOwned')) .. '|' .. state.Query end
	if state.Tab == 'Shoes' then
		local fresh = {}
		for id in stickers do table.insert(fresh, id) end
		table.sort(fresh)
		return 'shoes|' .. tostring(player:GetAttribute('ShoesMax')) .. tostring(player:GetAttribute('Pass_ExtraEquip')) .. '|' .. tostring(player:GetAttribute('ShoesOwned')) .. '|' .. tostring(player:GetAttribute('ShoesEquipped')) .. '|' .. state.Query .. '|' .. tostring(state.Delete) .. '|' .. tostring(confirm.Id) .. '|' .. table.concat(fresh, ',')
	end
	if state.Tab == 'Guns' then
		local cash = player:GetAttribute('Cash')
		local affordable = 0
		for _, gun in Guns.List do if type(cash) == 'number' and cash >= gun.Cost then affordable += 1 end end
		return 'guns|' .. tostring(player:GetAttribute('OwnedGuns')) .. '|' .. tostring(player:GetAttribute('EquippedGun')) .. '|' .. affordable .. '|' .. state.Query
	end
	if state.Tab == 'Items' then
		local owned = {}
		for key in Products.Passes do if player:GetAttribute('Pass_' .. key) == true then table.insert(owned, key) end end
		table.sort(owned)
		local boosts = {}
		for _, b in boostList() do table.insert(boosts, b.Level .. (b.Party and 'p' or '')) end
		return 'items|' .. table.concat(owned, ',') .. '|' .. table.concat(boosts, ',') .. '|' .. state.Query
	end
	return 'boxes|' .. tostring(player:GetAttribute('ShoesOwned')) .. '|' .. tostring(player:GetAttribute('Pass_Lucky')) .. '|' .. state.Query
end
refresh = function(force)
	if not isOpen then return end
	local key = keyNow()
	if force or key ~= shownKey then
		shownKey = key
		if state.Index then
			paintIndex()
		elseif state.Tab == 'Guns' then
			paintGuns()
		elseif state.Tab == 'Items' then
			paintItems()
		elseif state.Tab == 'Boxes' then
			paintBoxes()
		else
			paintShoes()
		end
	end
	paintChrome()
end

local function lookAtShoes()
	-- (opening Your Shoes marks what you unboxed as seen: NEW! on those pairs this time, the HUD's "!" goes)
	for id in newIds do stickers[id] = true end
	table.clear(newIds)
	playerGui:SetAttribute('ShoesNew', 0)
end
selectTab = function(id)
	local was = state.Tab
	state.Tab = id
	state.Index = false
	if id ~= 'Shoes' then state.Delete = false end
	if id == 'Shoes' and was ~= 'Shoes' then lookAtShoes() end
	refresh(true)
end

---------------------------------------------------------------------------------------------- open / close
local function close()
	if not isOpen then return end
	isOpen = false
	state.Delete = false
	confirm.Id = nil
	table.clear(stickers)
	Motion.blur('Inventory', false)
	IK.coverPlayerList('Inventory', false)
	Motion.close(W.Overlay, W.Pop)
	if playerGui:GetAttribute('HoodWindow') == 'Inventory' then playerGui:SetAttribute('HoodWindow', '') end
end
local function open(tab)
	local id = IK.tabId(tab) or (tab == nil and state.Tab) or 'Shoes'
	local wantIndex = type(tab) == 'string' and string.lower(tab) == 'index'
	if isOpen and id == state.Tab and state.Index == wantIndex then
		close()
		return
	end
	state.Tab = id
	state.Index = wantIndex
	if not isOpen then
		isOpen = true
		state.Query = ''
		if W.Search then W.Search.Text = '' end
		if W.Placeholder then W.Placeholder.Visible = true end
		playerGui:SetAttribute('HoodWindow', 'Inventory')
		Motion.blur('Inventory', true)
		IK.coverPlayerList('Inventory', true)
		Motion.open(W.Overlay, W.Pop, 1)
	end
	if id == 'Shoes' then lookAtShoes() end
	refresh(true)
end
openEvent.Event:Connect(open)
playerGui:GetAttributeChangedSignal('HoodWindow'):Connect(function()
	if isOpen and playerGui:GetAttribute('HoodWindow') ~= 'Inventory' then close() end
end)
backdrop.Activated:Connect(close)
Motion.button(W.CloseButton, close)
Motion.button(W.Index, function()
	if state.Index then
		state.Index = false
	else
		state.Index = true
		state.Delete = false
	end
	refresh(true)
end)

-- Search: filters the tab you're on as you type.
if W.Search then
	local function typed()
		local text = W.Search.Text
		W.Placeholder.Visible = text == ''
		if text ~= state.Query then
			state.Query = text
			refresh()
		end
	end
	W.Search:GetPropertyChangedSignal('Text'):Connect(typed)
	W.Search.Focused:Connect(function() W.Placeholder.Visible = false end)
	W.Search.FocusLost:Connect(typed)
end

---------------------------------------------------------------------------------------------- wiring
Net.get('ShoeOpened').OnClientEvent:Connect(function(info)
	if type(info) ~= 'table' then return end
	local list = type(info.Shoes) == 'table' and info.Shoes or { info }
	local count = 0
	for _, e in list do
		if type(e) == 'table' and Shoes.ById[e.Shoe] then newIds[e.Shoe] = true end
	end
	for _ in newIds do count += 1 end
	playerGui:SetAttribute('ShoesNew', count)
end)
local watched = { 'ShoesOwned', 'ShoesEquipped', 'ShoesMax', 'OwnedGuns', 'EquippedGun', 'Cash', 'BoostQueue', 'PowerBoost', 'BoostEnds', 'PartyEnds' }
for key in Products.Passes do table.insert(watched, 'Pass_' .. key) end
for _, key in watched do
	player:GetAttributeChangedSignal(key):Connect(function()
		if isOpen then refresh() end
	end)
end
task.spawn(function()
	while true do
		task.wait(1)
		local ok, err = pcall(tickBoosts)
		if not ok then warn('[Inventory] ' .. tostring(err)) end
	end
end)

local function relayout()
	local abs = gui.AbsoluteSize
	if abs.X < 1 or abs.Y < 1 then return end
	fitRoot(abs)
	IK.fit(W, abs)
	paintTabs()
end
gui:GetPropertyChangedSignal('AbsoluteSize'):Connect(relayout)
gui.Parent = playerGui
relayout()
playerGui:SetAttribute('ShoesNew', 0)
paintTabs()
