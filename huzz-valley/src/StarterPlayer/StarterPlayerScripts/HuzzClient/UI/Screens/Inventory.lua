-- Inventory (owner, Oct 21: "make the dances button the inventory button, which then will show you everything you
-- currently own from girls, to trails, to knifes, abilities etc. And will allow you to equip it"). The Shop sells;
-- this window holds what is yours and is where you wear it. It looks like the Shop (the same window, chunky words,
-- navy cards three... five to a row, coloured tabs down the right) so the two read as one family:
--   GIRLS      the girls you own: EQUIP makes her your companion in the lobby (ActionService "Equip" / "Unequip");
--   KNIVES     the knives you own, best first, with rarity chips: EQUIP / EQUIPPED ("Wear", slot Knife; the one the round gives you says EQUIPPED);
--   TRAILS, NAMES (name colours), TITLES, AURAS
--              what you own first (EQUIP / EQUIPPED: tap EQUIPPED to take it off), then the ones you can still earn,
--              dark with a lock and how to get them (Config/CoinShop Unlock); coin looks you don't own say where to
--              buy them (Shop > STYLE);
--   DANCES     the dances you own, each with your avatar in its pose (UI/DancePose): PLAY / STOP on you
--              (UI/DancePlayer), and ALL DANCES opens the Dances window (favourites for the G wheel);
--   ABILITIES  your round abilities: what you bring, EQUIP (runner) and Q / E (catcher), from UI/AbilityCards.
-- The window, its title bar and its tabs are real parts saved in StarterGui (the place build); the cards are made
-- each time a tab shows (what you own changes), marked RuntimeOnly so they're never saved. Opened from the lobby's
-- INVENTORY button and the Menu (ModalManager.open("Inventory", <tab or a CoinShop slot>)).
local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local CoinShop = require(Shared.Config.CoinShop)
local Characters = require(Shared.Config.Characters)
local Dances = require(Shared.Config.Dances)
local RoundConfig = require(Shared.Config.Round)
local CombineRules = require(Shared.CombineRules)
local KnifeLook = require(Shared.KnifeLook)
local UI = script.Parent.Parent
local Theme = require(UI.Theme)
local Kit = require(UI.Kit)
local State = require(UI.State)
local Toast = require(UI.Toast)
local ModalManager = require(UI.ModalManager)
local ShopStyle = require(UI.ShopStyle)
local Effects = require(UI.Effects)
local GirlPicture = require(UI.GirlPicture)
local DancePose = require(UI.DancePose)
local DancePlayer = require(UI.DancePlayer)

local C = Theme.Colors
local new = Kit.new
local hex = Color3.fromHex
local WHITE = Color3.new(1, 1, 1)
local chunky = ShopStyle.chunky
local chunkyButton = ShopStyle.chunkyButton
local FONT = ShopStyle.FONT
local INK = ShopStyle.INK

local Inventory = {}

-- the Shop's window and card sizes (Screens/Shop), so both windows match
local WIN = { W = 869, H = 550, Header = 77, TitleSize = 50 }
local TAB = { X = 877, W = 128, H = 43, Y = 83, Pitch = 49, TextSize = 26 }
local BODY = { X = 30, Y = 85, W = 825, H = WIN.H - 85 - 10 }
local PAD = 4
local CW = 795
local CARD = { W = 149, H = 224, Gap = 12, TitleY = 5, TitleH = 25, TitleSize = 20, PicY = 31, PicH = 120, LineY = 153, LineH = 15, LineSize = 12, ButtonX = 10, ButtonY = 174, ButtonH = 40 }
local TOP = { H = 46, TextSize = 26 } -- the line over the cards: what this tab is and how many you have
local CHIP = { H = 34, Gap = 8, Pad = 22, MinW = 56, TextSize = 17 }
local NAVY = { Top = hex("2A4276"), Bottom = hex("1A2A52"), Rim = C.Frame }
local LOCKED = { Top = hex("1C2438"), Bottom = hex("121828"), Rim = hex("3A4560") }

-- the tabs, top to bottom (Slot: the CoinShop slot it wears)
Inventory.TABS = {
	{ Key = "Girls", Text = "GIRLS", Fill = hex("E25FA8") },
	{ Key = "Knives", Text = "KNIVES", Fill = hex("8225D5"), Slot = "Knife" },
	{ Key = "Trails", Text = "TRAILS", Fill = hex("1EBABF"), Slot = "Trail" },
	{ Key = "Names", Text = "NAMES", Fill = hex("A45CF0"), Slot = "Tag" },
	{ Key = "Titles", Text = "TITLES", Fill = hex("D9449F"), Slot = "Title" },
	{ Key = "Auras", Text = "AURAS", Fill = hex("2A9FD8"), Slot = "Aura" },
	{ Key = "Dances", Text = "DANCES", Fill = hex("F08A3C") },
	{ Key = "Abilities", Text = "ABILITIES", Fill = hex("D7336F") },
}
local BY_SLOT = {}
for _, t in Inventory.TABS do
	if t.Slot then BY_SLOT[t.Slot] = t.Key end
	Kit.Styles["Inv" .. t.Key] = ShopStyle.look(t.Fill, t.Fill:Lerp(WHITE, 0.45), INK)
end

local rarityColor = {}
for _, r in RoundConfig.Rarities do rarityColor[r.Name] = r.Color end
rarityColor.Secret = Color3.fromRGB(150, 110, 255)
rarityColor.Exclusive = Color3.fromRGB(255, 170, 230)
local RARITY_ORDER = { "Exclusive", "Secret", "Mythic", "Legendary", "Epic", "Rare", "Uncommon", "Common" } -- (best first)
local function rank(r: string?): number
	return table.find(RARITY_ORDER, r or "Common") or #RARITY_ORDER
end

local function owns(key: string): boolean
	return State.data.Cosmetics ~= nil and State.data.Cosmetics[key] == true
end

-- a drawn picture for a look without one (as the Shop's): a trail streak, an aura ring, a title or "Aa" in its colours
local function swatch(parent: Instance, item: any, dark: boolean)
	local f = new("Frame", { Name = "Drawn", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(CARD.W // 2, CARD.PicY + CARD.PicH // 2), Size = UDim2.fromOffset(CARD.W - 16, 96), BackgroundTransparency = 1, ZIndex = 2, Parent = parent })
	local colours = item.Colors or { WHITE }
	if item.Slot == "Trail" then
		local streak = new("Frame", { Name = "Streak", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(1, -16, 0, 30), Rotation = -20, BackgroundColor3 = WHITE, BorderSizePixel = 0, ZIndex = 2, Parent = f }, { Kit.corner(15) })
		new("UIGradient", { Name = "Colours", Color = CoinShop.sequence(item), Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.85), NumberSequenceKeypoint.new(0.6, 0.15), NumberSequenceKeypoint.new(1, 0) }), Parent = streak })
	elseif item.Slot == "Aura" then
		local ring = new("Frame", { Name = "Ring", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(64, 64), BackgroundTransparency = 1, ZIndex = 2, Parent = f }, { Kit.corner(32) })
		new("UIStroke", { Name = "Glow", Color = WHITE, Thickness = 6, Parent = ring }, { new("UIGradient", { Name = "Colours", Rotation = 45, Color = CoinShop.sequence(item) }) })
		local core = new("Frame", { Name = "Core", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(28, 28), BackgroundColor3 = WHITE, BorderSizePixel = 0, ZIndex = 2, Parent = f }, { Kit.corner(14) })
		new("UIGradient", { Name = "Colours", Rotation = 90, Color = ColorSequence.new(WHITE, colours[1]), Parent = core })
	else
		-- a title: its words, in at most two lines that always fit the card (the old Shop cards spilled over, Oct 21)
		local isTitle = item.Slot == "Title"
		local word = chunky({ Name = "Word", Text = if isTitle then string.upper(item.Name) else "Aa", TextSize = if isTitle then 26 else 52,
			TextWrapped = isTitle, TextColor3 = colours[1], Position = UDim2.fromOffset(4, 0), Size = UDim2.new(1, -8, 1, 0), ZIndex = 2, Parent = f }, 2)
		if isTitle then
			if not Kit.fitBlock(word, CARD.W - 24, 2, 26, 11) then word.TextScaled = true end
			word.AnchorPoint, word.Position = Vector2.new(0.5, 0.5), UDim2.fromScale(0.5, 0.5) -- (in the middle)
		end
		if #colours > 2 then
			word.TextColor3 = WHITE
			new("UIGradient", { Name = "Colours", Color = CoinShop.sequence(item), Parent = word })
		end
	end
	if dark then
		for _, d in f:GetDescendants() do
			if d:IsA("GuiObject") then d.BackgroundTransparency = math.max(d.BackgroundTransparency, 0.65) end
			if d:IsA("TextLabel") then d.TextTransparency = 0.55 end
		end
	end
	return f
end

function Inventory.build(parent: Instance)
	local window = Kit.window({ Name = "Inventory", Flat = true, Title = "Inventory", Icon = "InventoryBackpack", Width = TAB.X + TAB.W, Height = WIN.H, HeaderHeight = WIN.Header, TitleX = 24, TitleSize = WIN.TitleSize, TitleWidth = 230, StudsTo = 760, CloseSize = Vector2.new(46, 46), Parent = parent, OnClose = function() ModalManager.close() end })
	local panel, header = window.Panel, window.Header
	panel.Size = UDim2.fromOffset(WIN.W, WIN.H) -- (the tabs stand outside the window, as the Shop's jump buttons)
	local titleIcon = header:FindFirstChild("TitleIcon")
	if titleIcon and titleIcon:IsA("GuiObject") then titleIcon.Visible = false end
	for _, n in { "Title", "TitleShadow" } do
		local t = header:FindFirstChild(n)
		if t and t:IsA("TextLabel") then t.FontFace = FONT; t.TextSize = WIN.TitleSize end
	end
	local page = new("ScrollingFrame", { Name = "Page", Position = UDim2.fromOffset(BODY.X, BODY.Y), Size = UDim2.fromOffset(BODY.W, BODY.H), BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 6, ScrollBarImageColor3 = hex("C8D0D8"), ScrollBarImageTransparency = 0.35, CanvasSize = UDim2.new(), ScrollingDirection = Enum.ScrollingDirection.Y, Parent = panel })
	Kit.attach(Kit.pad(PAD, PAD, PAD, PAD), page)

	-- The tabs down the right, one colour each; the open one wears a white rim.
	local current = "Girls"
	local tabs = {}
	local show: (string) -> ()
	for i, t in Inventory.TABS do
		local b = chunkyButton(Kit.button({ Name = t.Key .. "Tab", Text = t.Text, Style = "Inv" .. t.Key, FontFace = FONT, TextSize = TAB.TextSize, Corner = 3, Size = UDim2.fromOffset(TAB.W, TAB.H), LayoutOrder = i, Parent = panel }))
		Kit.place(b.Instance, UDim2.fromOffset(TAB.X, TAB.Y + (i - 1) * TAB.Pitch), UDim2.fromOffset(TAB.W, TAB.H))
		local label = b.Instance:FindFirstChild("Label", true)
		if label and label:IsA("TextLabel") then Kit.fitLine(label, TAB.W - 12, TAB.TextSize, 14) end
		b.onClick(function() show(t.Key) end)
		tabs[t.Key] = b
	end
	local function rims()
		for key, b in tabs do
			local rim = b.Instance:FindFirstChild("Rim")
			if rim and rim:IsA("UIStroke") then rim.Color, rim.Thickness = if key == current then WHITE else INK, if key == current then 3 else 2 end
		end
	end

	-- What a tab shows: made fresh each time (RuntimeOnly), placed top to bottom.
	local content: Frame? = nil
	local repaint: { () -> () } = {}
	local y = 0
	local function fresh()
		if content then content:Destroy() end
		table.clear(repaint)
		y = 0
		content = new("Frame", { Name = "Content", Size = UDim2.fromOffset(CW, 0), BackgroundTransparency = 1, Parent = page })
		;(content :: Frame):SetAttribute("RuntimeOnly", true)
		page.CanvasPosition = Vector2.zero
	end
	local function topLine(text: string, colour: Color3, button: { Text: string, Style: string, onClick: () -> () }?)
		local f = new("Frame", { Name = "Top", Position = UDim2.fromOffset(0, y), Size = UDim2.fromOffset(CW, TOP.H), BackgroundTransparency = 1, Parent = content })
		local bw = if button then 190 else 0
		local t = chunky({ Name = "Text", Text = text, TextSize = TOP.TextSize, TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.fromOffset(4, 0), Size = UDim2.fromOffset(CW - bw - 12, TOP.H), ZIndex = 2, Parent = f }, 2.5)
		new("UIGradient", { Name = "Colour", Rotation = 90, Color = ColorSequence.new(colour:Lerp(WHITE, 0.65), colour:Lerp(WHITE, 0.1)), Parent = t })
		Kit.fitLine(t, CW - bw - 12, TOP.TextSize, 14, true)
		if button then
			local b = chunkyButton(Kit.button({ Name = "Go", Text = button.Text, Style = button.Style, FontFace = FONT, TextSize = 18, Corner = 3, Position = UDim2.fromOffset(CW - bw, 4), Size = UDim2.fromOffset(bw, TOP.H - 8), ZIndex = 3, Parent = f }))
			b.onClick(button.onClick)
		end
		y += TOP.H + 6
	end
	local function note(text: string)
		local l = chunky({ Name = "Note", Text = text, TextSize = 20, TextColor3 = C.NoteText, TextWrapped = true, Position = UDim2.fromOffset(0, y), Size = UDim2.fromOffset(CW, 56), ZIndex = 2, Parent = content }, 2)
		Kit.fitBlock(l, CW - 20, 2, 20, 14)
		y += 62
	end
	local function grid(cards: { GuiObject })
		local cols = 5
		for i, c in cards do
			local col, r = (i - 1) % cols, (i - 1) // cols
			local rows = math.ceil(#cards / cols)
			local inRow = if r == rows - 1 then #cards - r * cols else cols
			local x0 = (CW - (inRow * CARD.W + (inRow - 1) * CARD.Gap)) // 2
			c.Position = UDim2.fromOffset(x0 + col * (CARD.W + CARD.Gap), y + r * (CARD.H + CARD.Gap))
		end
		local rows = math.ceil(#cards / cols)
		if rows > 0 then y += rows * (CARD.H + CARD.Gap) - CARD.Gap + 14 end
	end
	local function finish()
		if content then content.Size = UDim2.fromOffset(CW, y) end
		page.CanvasSize = UDim2.fromOffset(0, y + 2 * PAD + 8)
		ShopStyle.popIn(ShopStyle.cards(content))
	end
	-- one card: its title, a place for its picture, one line, and a button; returns the card and its button
	local function card(name: string, title: string, line: string, lineColour: Color3?, rim: Color3?, dark: boolean?)
		local lk = if dark then LOCKED else NAVY
		local c = new("Frame", { Name = name, Size = UDim2.fromOffset(CARD.W, CARD.H), BackgroundColor3 = WHITE, BackgroundTransparency = 0.08, BorderSizePixel = 0, Parent = content }, { Kit.corner(3), Kit.stroke(rim or lk.Rim, 2) })
		new("UIGradient", { Name = "Fill", Rotation = 90, Color = ColorSequence.new(lk.Top, lk.Bottom), Parent = c })
		Effects.lift(c)
		local t = chunky({ Name = "Title", Text = title, TextSize = CARD.TitleSize, TextColor3 = if dark then hex("9AA6BF") else WHITE, Position = UDim2.fromOffset(5, CARD.TitleY), Size = UDim2.fromOffset(CARD.W - 10, CARD.TitleH), ZIndex = 3, Parent = c }, 2)
		Kit.fitLine(t, CARD.W - 10, CARD.TitleSize, 10, true)
		local l = chunky({ Name = "Line", Text = line, TextSize = CARD.LineSize, TextColor3 = lineColour or hex("BFE8C8"), Position = UDim2.fromOffset(5, CARD.LineY), Size = UDim2.fromOffset(CARD.W - 10, CARD.LineH), ZIndex = 3, Parent = c }, 1.2)
		Kit.fitLine(l, CARD.W - 10, CARD.LineSize, 8, true)
		local b = chunkyButton(Kit.button({ Name = "Use", Text = "", TextSize = 20, FontFace = FONT, Style = "ShopGreen", Corner = 3, Position = UDim2.fromOffset(CARD.ButtonX, CARD.ButtonY), Size = UDim2.fromOffset(CARD.W - 2 * CARD.ButtonX, CARD.ButtonH), ZIndex = 4, Parent = c }))
		return c, b
	end
	local function lockOn(c: GuiObject)
		Kit.icon("Lock", { Name = "Lock", AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromOffset(CARD.W - 6, CARD.PicY + 2), Size = UDim2.fromOffset(26, 26), ZIndex = 4, Parent = c })
	end
	local busy = false
	local function act(verb: string, ...)
		if busy then return end
		busy = true
		local args = table.pack(...)
		task.spawn(function()
			local ok, why = State.action(verb, table.unpack(args, 1, args.n))
			busy = false
			if not ok then Toast.show(why or "Couldn't change that. Try again.") end
		end)
	end

	-- GIRLS --------------------------------------------------------------------------------------------------------
	local function girls()
		pcall(function() Characters.addGirls(GirlPicture.folder()) end)
		local list = {}
		for _, c in Characters.List do
			if not Characters.Retired[c.Id] and State.data.Characters and State.data.Characters[c.Id] ~= nil then table.insert(list, c) end
		end
		table.sort(list, function(a, b)
			local ra, rb = Characters.tierRank(a.Tier), Characters.tierRank(b.Tier)
			if ra ~= rb then return ra > rb end
			return a.Name < b.Name
		end)
		topLine(string.format("YOUR GIRLS  ·  %d", #list), hex("E25FA8"), { Text = "INDEX", Style = "InvGirls", onClick = function() ModalManager.open("Index") end })
		if #list == 0 then note("No girls yet. Win one in a round, or open the Index to see them all.") return end
		local cards = {}
		for _, g in list do
			local tierColour = Characters.TierColors[g.Tier] or WHITE
			local c, b = card("Girl" .. g.Id, g.Name, string.upper(g.Rarity or Characters.TierNames[g.Tier] or ""), tierColour, tierColour:Lerp(Color3.new(0, 0, 0), 0.35))
			local holder = new("Frame", { Name = "Picture", Position = UDim2.fromOffset(4, CARD.PicY), Size = UDim2.fromOffset(CARD.W - 8, CARD.PicH), BackgroundTransparency = 1, ClipsDescendants = true, ZIndex = 2, Parent = c })
			local grade = if g.Model then CombineRules.best(State.data, g.Id) else nil
			local vp = g.Model and GirlPicture.draw(holder, g.Model, true, false, grade)
			if vp then
				vp.Size, vp.ZIndex = UDim2.fromScale(1, 1), 2
			else
				Kit.art(g.Art or "CharLocked", { Name = "Art", Size = UDim2.fromScale(1, 1), ScaleType = Enum.ScaleType.Fit, ZIndex = 2, Parent = holder })
			end
			local function paint()
				local on = State.data.Equipped == g.Id
				b.setText(if on then "EQUIPPED" else "EQUIP")
				b.setStyle(if on then "Selected" else "ShopGreen")
				chunkyButton(b)
			end
			b.onClick(function()
				if State.data.Equipped == g.Id then act("Unequip") else act("Equip", g.Id) end
			end)
			table.insert(repaint, paint)
			paint()
			table.insert(cards, c)
		end
		grid(cards)
	end

	-- KNIVES, TRAILS, NAMES, TITLES, AURAS ---------------------------------------------------------------------------
	local knifeRarity = "All"
	local function looks(tab)
		local slot = tab.Slot
		local mine, locked, forSale = {}, {}, {}
		for _, item in CoinShop.Items do
			if item.Slot == slot then
				if owns(item.Key) then table.insert(mine, item)
				elseif item.Unlock then table.insert(locked, item)
				elseif slot ~= "Knife" and not item.NotForSale and (item.Price or 0) > 0 then table.insert(forSale, item) end
			end
		end
		local function best(a, b)
			if rank(a.Rarity) ~= rank(b.Rarity) then return rank(a.Rarity) < rank(b.Rarity) end
			return (a.Order or 0) < (b.Order or 0)
		end
		table.sort(mine, best)
		table.sort(locked, best)
		-- what's on now: a knife never picked is the one the round gives you (Shared/KnifeLook.pick), so one says EQUIPPED
		local function wornKey(): string?
			if slot == "Knife" then
				local k = KnifeLook.pick(State.data, CoinShop)
				return k and k.Key
			end
			return CoinShop.worn(State.data, slot)
		end
		local worn = wornKey()
		local wornItem = worn and CoinShop.get(worn)
		local slotName = CoinShop.SlotNames[slot] or string.upper(tab.Text)
		local head = string.format("YOUR %s  ·  %d", tab.Text, #mine)
		if wornItem then head ..= "   ·   EQUIPPED: " .. string.upper(wornItem.Name) end
		local go = if slot == "Knife" then { Text = "GET KNIVES", Style = "ShopOrange", onClick = function() ModalManager.open("Shop", "Crates") end }
			elseif #forSale > 0 then { Text = "BUY MORE", Style = "ShopOrange", onClick = function() ModalManager.open("Shop", "Style") end }
			else nil
		topLine(head, tab.Fill, go)
		-- knives: rarity chips (only the rarities you have), the list closes up
		if slot == "Knife" and #mine > 0 then
			local have = {}
			for _, item in mine do have[item.Rarity or "Common"] = true end
			local defs = { { Key = "All", Text = "ALL", Color = hex("D6DEE6") } }
			for i = #RARITY_ORDER, 1, -1 do
				local r = RARITY_ORDER[i]
				if have[r] then table.insert(defs, { Key = r, Text = string.upper(r), Color = rarityColor[r] or WHITE }) end
			end
			local row = new("Frame", { Name = "Chips", Position = UDim2.fromOffset(0, y), Size = UDim2.fromOffset(CW, CHIP.H), BackgroundTransparency = 1, Parent = content })
			local x = 0
			for _, d in defs do
				local w = math.max(CHIP.MinW, math.ceil(Kit.textWidth(d.Text, FONT, CHIP.TextSize)) + CHIP.Pad)
				if x + w > CW then break end
				local key = "InvChip" .. d.Key
				Kit.Styles[key] = Kit.Styles[key] or ShopStyle.look(d.Color:Lerp(Color3.new(0, 0, 0), 0.25), d.Color:Lerp(WHITE, 0.3), INK)
				local on = knifeRarity == d.Key
				local b = chunkyButton(Kit.button({ Name = "Chip" .. d.Key, Text = d.Text, Style = if on then key else "Tab", FontFace = FONT, TextSize = CHIP.TextSize, Corner = 3, Position = UDim2.fromOffset(x, 0), Size = UDim2.fromOffset(w, CHIP.H), ZIndex = 3, Parent = row }))
				local rim = b.Instance:FindFirstChild("Rim")
				if on and rim and rim:IsA("UIStroke") then rim.Color, rim.Thickness = WHITE, 3 end
				b.onClick(function() knifeRarity = d.Key; show("Knives") end)
				x += w + CHIP.Gap
			end
			y += CHIP.H + 10
		end
		local function lookCard(item, isMine: boolean)
			local tint = item.Rarity and rarityColor[item.Rarity]
			local line = if item.Rarity then string.upper(item.Rarity) .. " " .. slotName else slotName
			if not isMine then line = item.Unlock or (string.format("%d COINS IN THE SHOP", item.Price or 0)) end
			local c, b = card(item.Key, item.Name, string.upper(line), if isMine then (tint or hex("BFE8C8")) else hex("FFC27A"), tint and tint:Lerp(Color3.new(0, 0, 0), 0.35), not isMine)
			if item.Art then
				local art = Kit.art(item.Art :: string, { Name = "Picture", Position = UDim2.fromOffset(4, CARD.PicY), Size = UDim2.fromOffset(CARD.W - 8, CARD.PicH), ScaleType = Enum.ScaleType.Fit, ZIndex = 2, Parent = c })
				if not isMine then art.ImageColor3, art.ImageTransparency = hex("5A6480"), 0.25 end
			else
				swatch(c, item, not isMine)
			end
			if isMine then
				local function paint()
					local on = wornKey() == item.Key
					b.setText(if on then "EQUIPPED" else "EQUIP")
					b.setStyle(if on then "Selected" else "ShopGreen")
					chunkyButton(b)
				end
				b.onClick(function()
					local on = wornKey() == item.Key
					act("Wear", slot, if on then nil else item.Key)
				end)
				table.insert(repaint, paint)
				paint()
			else
				lockOn(c)
				b.setText(if item.Unlock then "EARN IT" else "GET IT")
				b.setStyle(if item.Unlock then "Disabled" else "ShopOrange") -- (GET IT opens the Shop: it looks tappable)
				chunkyButton(b)
				b.onClick(function()
					if item.Unlock then Toast.show(`{item.Name}: {item.Unlock}.`) else ModalManager.open("Shop", "Style") end
				end)
			end
			return c
		end
		local shownMine = {}
		for _, item in mine do
			if slot ~= "Knife" or knifeRarity == "All" or (item.Rarity or "Common") == knifeRarity then table.insert(shownMine, lookCard(item, true)) end
		end
		if #mine == 0 then
			note(if slot == "Knife" then "No knives yet. Open a crate in the Shop to get one!"
				elseif #forSale > 0 then "None yet. Buy one in the Shop (STYLE), or earn one below."
				else "None yet. Earn one below.")
		end
		grid(shownMine)
		if #locked > 0 or #forSale > 0 then
			local rest = {}
			for _, item in locked do table.insert(rest, lookCard(item, false)) end
			for _, item in forSale do table.insert(rest, lookCard(item, false)) end
			topLine(if #locked > 0 then "STILL TO GET" else "IN THE SHOP", hex("9AA6BF"))
			grid(rest)
		end
	end

	-- DANCES -------------------------------------------------------------------------------------------------------
	local function dances()
		local list = {}
		for _, d in Dances.List do
			if DancePlayer.owned(d.Id) then table.insert(list, d) end
		end
		table.sort(list, function(a, b) return a.Order < b.Order end)
		topLine(string.format("YOUR DANCES  ·  %d", #list), hex("F08A3C"), { Text = "ALL DANCES", Style = "InvDances", onClick = function() ModalManager.open("Dances") end })
		if #list == 0 then note("No dances yet. Buy them in the Shop (DANCES).") return end
		local cards = {}
		for _, d in list do
			local colour = Dances.Colors[d.Color] or WHITE
			local c, b = card("Dance" .. d.Id, d.Name, if d.Pack then "DANCE PACK" else "DANCE", colour:Lerp(WHITE, 0.3), colour:Lerp(Color3.new(0, 0, 0), 0.35))
			local still = Kit.art("DanceStill" .. d.Id, { Name = "Picture", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.fromOffset(CARD.W // 2, CARD.PicY + CARD.PicH), Size = UDim2.fromOffset(CARD.PicH, CARD.PicH), ScaleType = Enum.ScaleType.Fit, ZIndex = 2, Parent = c })
			pcall(DancePose.picture, c, d.Id, { Position = UDim2.fromOffset(4, CARD.PicY), Size = UDim2.fromOffset(CARD.W - 8, CARD.PicH), ZIndex = 3 }, false, nil, function()
				still.Visible = false -- (your avatar in the pose: the drawn stand-in steps aside)
			end)
			local function paint()
				local on = DancePlayer.current() == d.Id
				b.setText(if on then "STOP" else "PLAY")
				b.setStyle(if on then "Selected" else "ShopGreen")
				chunkyButton(b)
			end
			b.onClick(function()
				local ok, why = DancePlayer.toggle(d.Id)
				if not ok and why then Toast.show(why) end
				for _, f in repaint do f() end
			end)
			table.insert(repaint, paint)
			paint()
			table.insert(cards, c)
		end
		grid(cards)
	end

	-- ABILITIES ----------------------------------------------------------------------------------------------------
	local function abilities()
		topLine("YOUR ABILITIES", hex("D7336F"), { Text = "SHOP", Style = "InvAbilities", onClick = function() ModalManager.open("Shop", "Abilities") end })
		local slot = new("Frame", { Name = "AbilitiesSlot", Position = UDim2.fromOffset(0, y), Size = UDim2.fromOffset(CW, 0), BackgroundTransparency = 1, Parent = content })
		local okA, res = pcall(function() return require(UI.AbilityCards).build(slot, { both = true, mine = true }) end) -- (yours only: buying is the Shop's)
		if okA then
			y += (if type(res) == "number" then res else slot.Size.Y.Offset) + 10
		else
			warn("[HuzzUI] Inventory: ABILITIES couldn't be built:", res)
			note("Your abilities can't be shown right now.")
		end
	end

	local BUILD = { Girls = girls, Dances = dances, Abilities = abilities }
	function show(key: string)
		key = BY_SLOT[key] or key
		local tab
		for _, t in Inventory.TABS do if t.Key == key then tab = t end end
		if not tab then tab = Inventory.TABS[1] end
		current = tab.Key
		rims()
		fresh()
		local ok, err = pcall(function()
			if BUILD[tab.Key] then BUILD[tab.Key]() else looks(tab) end
		end)
		if not ok then
			warn("[HuzzUI] Inventory: " .. tab.Key .. " couldn't be shown:", err)
			note("This can't be shown right now.")
		end
		finish()
	end
	rims()

	local isOpen = false
	State.changed(function()
		if not isOpen then return end
		-- what you own changed (a new girl, a knife): place the tab again; else just repaint its buttons
		for _, f in repaint do f() end
	end)
	DancePlayer.changed(function() if isOpen then for _, f in repaint do f() end end end)
	-- a big change (something new is yours) while it's open: the tab again, keeping its place
	local lastCount = -1
	State.changed(function(data)
		if not isOpen then return end
		local n = 0
		for _ in data.Cosmetics or {} do n += 1 end
		for _ in data.Characters or {} do n += 1 end
		for _ in data.Dances or {} do n += 1 end
		if lastCount >= 0 and n ~= lastCount then
			local at = page.CanvasPosition
			show(current)
			page.CanvasPosition = at
		end
		lastCount = n
	end)

	ModalManager.register("Inventory", {
		window = window,
		-- open at a tab ("Girls", "Knives", "Trails", "Names", "Titles", "Auras", "Dances", "Abilities") or a CoinShop
		-- slot ("Trail", "Tag", ...)
		onOpen = function(where)
			isOpen = true
			lastCount = -1
			show(if type(where) == "string" then where else current)
		end,
		onClose = function()
			isOpen = false
			if content then content:Destroy(); content = nil end
		end,
		firstSelect = function() return tabs.Girls and tabs.Girls.Instance end,
	})
	return window
end

return Inventory
