-- Shop: ONE window with ONE scrolling page, after the owner's reference video (Oct 20 14:25, "also make our ui shop
-- and in general make it like that, based of this"; 14:31 "make the shop more logical, make it not so spread out as it
-- is, make it all logically connected an all close to eachother, like other games";
-- design/owner-oct20/1425-shop-reference.mp4 and its frames 1425-shop-ref-*.jpg). What it copies from the video:
--   * a studded title bar with a big chunky white "Shop" (Roblox's FredokaOne, the closest built-in font); one long page
--     split into sections with big coloured headers;
--   * a column of bright jump buttons on the right (one colour each) that scroll the page to their section; the one
--     for the section on screen gets a white rim;
--   * a featured banner at the top (his Halloween Crate: a real thing we sell; no countdown, no "one-time offer");
--   * cards three to a row: a bold title, a big picture, one short line and a small one, a price button.
-- Sizes are the video's (1280 x 704) times 0.8 in our window px: the window 869 x 550, cards 251 x 338, 14 px apart,
-- headers 95 px, jump buttons 128 x 43 every 49 px (docs/notes/ui.md, "Shop").
-- Owner, Oct 20 20:34 ("make the ui for the shop colour match our ui. But keep the layout"; "make a halloween style ui
-- look, also animate the ui more"): our kit's colours (the purple studded title bar, the see-through navy body and
-- navy cards, the kit's green and purple buttons) with Halloween trim (an orange line under the title bar, pumpkin
-- and bats, orange rims on the Halloween cards, warm embers on the featured crate). Motion: the cards pop in one after
-- another when the Shop opens, the crates rock gently, the featured crate shines (every 6 s: never more than one
-- flash a second) and its OPEN button breathes, cards lift under the mouse, buttons squish when pressed (Kit), and a
-- crate's or a dance's panel slides in from the right. Reduced Motion stops all of it (Effects.setCalm, Motion.reduced).
-- Sections, in this order:
--   HALLOWEEN  his three Halloween crates (Candy, Witch, Halloween: coins or Aura, his 20:34 picture) and the best
--              Halloween knives straight away for Aura or Robux;
--   CRATES     his Dojo / Storm / Beast crates (Aura, or a Robux key);
--   DANCES     the Dance Pack, then every dance you can buy, one by one, for coins (ActionService "BuyDance"); each
--              card shows your own avatar dancing it (owner, Oct 21; UI/DancePose.live, the cards in view only);
--   STYLE      the trails and name colours sold for coins, each kind under its own header, with type chips;
--   ABILITIES, PASSES, AURA, COINS.
-- The Shop only sells (owner, Oct 21: "make this logical, and not everything mixed together"): what you own you wear
-- from the Inventory (Screens/Inventory: your girls, knives, trails, name colours, titles, auras, dances and
-- abilities), which also shows the looks you earn and how. The Robux looks (outfits, poses) are gone.
-- Every crate shows on the same backdrop (owner: "make all of the crate pictures have the same background so they all
-- look the same, but just the crate is different": his crates cut out by tools/crates/cut_crates.py). The page shows
-- no odds (owner: "remove all of the chances of the knifes, only show it when you click on a crate, then on the side it
-- pops up"): tapping a crate slides its panel in with every item's chance, the pity counter and the only buttons that
-- spend anything, so the odds are always in view when you pay (kid-safe: never hidden odds). Tapping a dance slides
-- its panel in with a preview (your avatar dancing it where its animation can play, else its picture) and BUY.
-- The Halloween stands, the Aura and Coin "+" buttons and the crate opening's BACK open this window at their section
-- or crate (ModalManager.open("Shop", <section or crate id>); a crate also opens its panel). No gift buttons (we have
-- no gifting), no codes (we have no codes system).
-- FILTERS (owner, Oct 20 15:13: "add filters within the ui so people can find trails, titles, knifes easier"): under
-- the STYLE header type chips (ALL, TRAILS, NAME COLOURS; what you own and the knives' rarity chips are in the
-- Inventory now). A tap changes what shows at once; the grid closes up (no gaps); the choice stays for the
-- session.
-- ABILITIES: a slot for the bought abilities, built by UI/AbilityCards (build(parent)) when that module exists; until
-- then the section and its jump button stay hidden.
-- Rules kept: Robux buttons only open Roblox's prompt, and only for a product with its ID (Id 0 = "coming soon",
-- never a purchase); the server grants (ShopService, ActionService); every chance shows; pity shows; whole pixels.
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Products = require(Shared.Config.Products)
local CoinShop = require(Shared.Config.CoinShop)
local RoundConfig = require(Shared.Config.Round)
local Format = require(Shared.Format)
local Crates = require(Shared.Config.Crates)
local HalloweenShop = require(Shared.Config.HalloweenShop)
local CrateRoll = require(Shared.CrateRoll)
local KnifeLook = require(Shared.KnifeLook)
local Dances = require(Shared.Config.Dances)
local UI = script.Parent.Parent
local CrateArt = require(UI.CrateArt)
local Theme = require(UI.Theme)
local Kit = require(UI.Kit)
local State = require(UI.State)
local Toast = require(UI.Toast)
local ModalManager = require(UI.ModalManager)
local Motion = require(UI.Motion)
local Effects = require(UI.Effects)
local CoinFx = require(UI.CoinFx)
local ShopStyle = require(UI.ShopStyle)
local DancePose = require(UI.DancePose)
local LookPicture = require(UI.LookPicture)

local C = Theme.Colors
local new = Kit.new
local hex = Color3.fromHex
local WHITE = Color3.new(1, 1, 1)

local Shop = {}

-- the video's chunky rounded letters (titles, headers, jump buttons, prices) and its dark outline (UI/ShopStyle:
-- every menu uses them now)
local SHOP_FONT = ShopStyle.FONT
local INK = ShopStyle.INK

-- Window (px), measured on the video at 0.8 (see the header)
local WIN = { W = 869, H = 550, Header = 77, Close = 73, TitleSize = 50 }
local JUMP = { X = 877, W = 128, H = 43, Y = 83, Pitch = 49, TextSize = 30 }
local TOTAL_W = JUMP.X + JUMP.W -- the window and its jump column
local PAD = 4 -- room round the cards inside the page, so their rims aren't clipped
local BODY = { X = 30, Y = 85, W = 825, H = WIN.H - 85 - 10 }
local CW = 795 -- the page's content width (the video's 994 x 0.8)
local BIG = { W = 251, H = 338, Gap = 14, TitleY = 8, TitleH = 42, TitleSize = 37, PicY = 52, PicH = 152,
	LineY = 207, LineH = 22, LineSize = 18, SmallY = 233, SmallH = 16, SmallSize = 13, ButtonX = 24, ButtonY = 262, ButtonH = 54, ButtonText = 28 }
local SMALL = { W = 149, H = 224, Gap = 12, TitleY = 5, TitleH = 25, TitleSize = 20, PicY = 31, PicH = 120,
	LineY = 153, LineH = 15, LineSize = 12, ButtonX = 10, ButtonY = 174, ButtonH = 40 }
local HEAD = { H = 95, TextSize = 58 } -- a section header: the gap between two rows of cards, the word in its middle
local SUB = { H = 50, TextSize = 28 } -- a smaller header inside a section (a rarity, EVERY CHANCE)
local BANNER = { H = 224 }
local CARD_T = 0.08 -- (our cards: nearly solid over the see-through body)
local SIDE = { W = 520, Pad = 14, ButtonH = 54 } -- a crate's or a dance's panel, sliding in over the page's right side

-- our kit's colours (UI/Theme): navy cards with a dark rim; the Halloween cards in deep purple with an orange rim
local NAVY = { Top = hex("2A4276"), Bottom = hex("1A2A52"), Rim = C.Frame }
local SPOOKY = { Top = hex("45207A"), Bottom = hex("1E0E3A"), Rim = hex("FF7A1E") }
local ORANGE = hex("FF7A1E")
local CANDY = hex("FFB36B")

-- the sections, top to bottom, each with its jump button's colour and its cards' colour
local SECTIONS = {
	{ Key = "Halloween", Text = "HALLOWEEN", Fill = hex("E8661A"), Top = hex("FFB36B"), Look = SPOOKY },
	{ Key = "Crates", Text = "CRATES", Fill = hex("7C5CF6"), Top = hex("C4B4FF"), Look = NAVY },
	{ Key = "Dances", Text = "DANCES", Fill = hex("D9449F"), Top = hex("F69AD4"), Look = NAVY },
	{ Key = "Style", Text = "STYLE", Fill = hex("277ADD"), Top = hex("74B0F2"), Look = NAVY },
	{ Key = "Abilities", Text = "ABILITIES", Fill = hex("D7336F"), Top = hex("F682AE"), Look = NAVY }, -- (shown once UI/AbilityCards exists)
	{ Key = "Passes", Text = "PASSES", Fill = hex("257AD9"), Top = hex("6FB2F5"), Look = NAVY },
	{ Key = "Aura", Text = "AURA", Fill = hex("1EBABF"), Top = hex("7FE6E9"), Look = NAVY },
	{ Key = "Coins", Text = "COINS", Fill = hex("43D416"), Top = hex("8CEB63"), Look = NAVY },
}
-- what older callers ask for ("Items" was the coin shop tab)
-- (owner, Oct 21: the knives you own and the looks you earn moved to the Inventory; knives come from the crates)
local ALIAS = { Items = "Style", Cosmetics = "Style", Knives = "Crates" }

-- Our kit's buttons: green to buy (Theme's SelectedTab green), purple for Robux (Theme's Action), teal-blue for Aura;
-- one colour per jump button. White chunky text, dark rim.
local look = ShopStyle.look
-- (ShopGreen, ShopPurple, ShopAura, ShopOrange: UI/ShopStyle)
for _, sec in SECTIONS do Kit.Styles["Jump" .. sec.Key] = look(sec.Fill, sec.Top, INK) end

local pending: { [string]: boolean } = {}
local livePrice: { [string]: number } = {}
local priceLabels: { [string]: TextLabel } = {} -- the Halloween products' Robux prices (live once they have an ID)
local refreshButtons: { () -> () } = {}

local function priceOf(p) return livePrice[p.Key] or p.Price end

-- White chunky words with the video's dark outline; a button's label in that look (chunky, a solid dark outline,
-- clearly studded).
local chunky = ShopStyle.chunky
local chunkyButton = ShopStyle.chunkyButton

-- FILTERS: what each filter row last picked, kept for the session (the Shop is built once per session)
local FILTER = {
	Style = { Type = "All", Rarity = "All", Own = "All", Search = "" },
}
local TYPES = { { Key = "Trail", Text = "TRAILS" }, { Key = "Title", Text = "TITLES" }, { Key = "Tag", Text = "NAME COLOURS" }, { Key = "Aura", Text = "AURAS" } }
local TYPE_COLOUR = { All = hex("D6DEE6"), Trail = hex("1EBABF"), Title = hex("E25FA8"), Tag = hex("A45CF0"), Aura = hex("5AA8F5") }
local CHIP = { H = 40, Gap = 8, Pad = 26, MinW = 64, TextSize = 19, RowGap = 8 } -- touch-sized chips
-- a chip's two looks in its colour: dark with coloured words, or filled (and a white rim, set where it's picked)
local function chipStyle(key: string, col: Color3): (string, string)
	local off, on = "Chip" .. key, "ChipOn" .. key
	if not Kit.Styles[off] then
		local black = Color3.new(0, 0, 0)
		local dark = col:Lerp(black, 0.66)
		Kit.Styles[off] = { Idle = dark, Hover = dark:Lerp(WHITE, 0.08), Pressed = dark:Lerp(black, 0.15), Text = col:Lerp(WHITE, 0.4), Top = col:Lerp(black, 0.35), Rim = col:Lerp(black, 0.1) }
		Kit.Styles[on] = { Idle = col, Hover = col:Lerp(WHITE, 0.1), Pressed = col:Lerp(black, 0.1), Text = WHITE, Top = col:Lerp(WHITE, 0.35), Rim = INK }
	end
	return off, on
end

-- One price button's look for a product right now: text, style, icon, and whether the Robux mark shows.
local function buttonState(p): (string, string, string?, boolean)
	if State.owns(p.Key) and p.Slot then -- a cosmetic you own: put it on or take it off here
		if CoinShop.worn(State.data, p.Slot) == p.Key then return "WEARING", "Selected", nil, false end
		return "WEAR", "Tab", nil, false
	end
	if State.owns(p.Key) then return "OWNED", "Disabled", "CheckEquipped", false end
	if pending[p.Key] then return "...", "Disabled", nil, false end
	return Format.commas(priceOf(p)), "ShopGreen", nil, true
end

local function buy(p)
	if State.owns(p.Key) and p.Slot then
		local worn = CoinShop.worn(State.data, p.Slot) == p.Key
		local ok, why = State.action("Wear", p.Slot, if worn then nil else p.Key)
		if not ok then Toast.show(why or "Couldn't change that.") end
		return
	end
	if State.owns(p.Key) or pending[p.Key] then return end
	local status = Products.status(p)
	if status == "Soon" then
		Toast.show(p.Name .. " is coming soon.") -- shown with its price, but never sold until it gives something
		return
	elseif status == "NoId" then
		Toast.show(p.Name .. " is coming soon.") -- (no ID yet: never a purchase prompt)
		warn(string.format("[Shop] %s has no %s ID in Shared/Config/Products.lua", p.Key, p.Kind == "Pass" and "Game Pass" or "Developer Product"))
		return
	end
	pending[p.Key] = true
	for _, f in refreshButtons do f() end
	local player = Players.LocalPlayer
	local ok = pcall(function()
		if p.Kind == "Pass" or p.GamePass then
			MarketplaceService:PromptGamePassPurchase(player, p.Id)
		else
			MarketplaceService:PromptProductPurchase(player, p.Id)
		end
	end)
	if not ok then
		pending[p.Key] = nil
		Toast.show("The purchase couldn't open. Try again.")
	else
		task.delay(90, function() -- never leave a button stuck if Roblox doesn't report back
			if pending[p.Key] then pending[p.Key] = nil; for _, f in refreshButtons do f() end end
		end)
	end
	for _, f in refreshButtons do f() end
end

local function onPromptClosed(id: number, isPass: boolean)
	for _, list in { Products.Passes, Products.Cosmetics, Products.Coins, Products.Aura, Products.Halloween, Products.Crates } do
		for _, p in list do
			if p.Id == id and (p.Kind == "Pass" or p.GamePass == true) == isPass then pending[p.Key] = nil end
		end
	end
	for _, f in refreshButtons do f() end
end

-- The green price button (Robux mark + price; OWNED, WEAR / WEARING, "..."), kept in sync with ownership.
local function buyButton(parent: Instance, p, props)
	local b = chunkyButton(Kit.button({ Name = "Buy", Parent = parent, Position = props.Position, Size = props.Size, AnchorPoint = props.AnchorPoint, TextSize = props.TextSize or BIG.ButtonText, IconAfter = true, IconSize = props.IconSize or 22, Gap = 6, Corner = 3, ZIndex = 4, Style = "ShopGreen" }))
	local textSize = props.TextSize or BIG.ButtonText
	local badge = Kit.text({ Name = "RobuxBadge", Text = Format.RobuxMark, FontFace = Theme.Fonts.Number, TextSize = math.floor(textSize * 1.25), TextColor3 = WHITE, TextXAlignment = Enum.TextXAlignment.Center, AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.new(0, 0, 1, 0), TextWrapped = false, LayoutOrder = 1, ZIndex = 4, Parent = b.Instance:FindFirstChild("Content") })
	new("UIStroke", { Name = "Outline", Color = INK, Thickness = 1.5, Parent = badge })
	local icon: ImageLabel? = nil
	local function refresh()
		if not b.Instance.Parent then return end
		local text, style, iconName, priced = buttonState(p)
		if priced and (p.Price or 0) <= 0 and not livePrice[p.Key] then text = "BUY" end -- (a pass whose price he sets on Roblox)
		badge.Visible = priced
		b.setText(text)
		b.setStyle(style)
		chunkyButton(b)
		if iconName and not icon then
			icon = Kit.icon(iconName, { Name = "Icon", Size = UDim2.fromOffset(props.IconSize or 22, props.IconSize or 22), LayoutOrder = 3, ZIndex = 4, Parent = b.Instance:FindFirstChild("Content") })
		elseif not iconName and icon then
			icon:Destroy()
			icon = nil
		end
	end
	b.onClick(function() buy(p) end)
	table.insert(refreshButtons, refresh)
	refresh()
	return b
end

-- A purple Robux button with a word before the price ("KEY"), for the Halloween products and the crate keys.
local function robuxButton(parent: Instance, p, word: string?, props: { [string]: any })
	local b = chunkyButton(Kit.button({ Name = props.Name or "Robux", Text = word or "", Style = "ShopPurple", FontFace = SHOP_FONT, TextSize = props.TextSize or 20, Gap = 4, Corner = 3, Position = props.Position, Size = props.Size, ZIndex = 4, Parent = parent }))
	local content = b.Instance:FindFirstChild("Content")
	local size = props.TextSize or 20
	local badge = Kit.text({ Name = "RobuxBadge", Text = Format.RobuxMark, FontFace = Theme.Fonts.Number, TextSize = math.floor(size * 1.2), TextColor3 = WHITE, TextXAlignment = Enum.TextXAlignment.Center, AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.new(0, 0, 1, 0), TextWrapped = false, LayoutOrder = 3, ZIndex = 4, Parent = content })
	new("UIStroke", { Name = "Outline", Color = INK, Thickness = 1.5, Parent = badge })
	local price = Kit.text({ Name = "Price", Text = Format.commas(p.Price), FontFace = SHOP_FONT, TextSize = size, TextXAlignment = Enum.TextXAlignment.Center, AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.new(0, 0, 1, 0), TextWrapped = false, LayoutOrder = 4, ZIndex = 4, Parent = content })
	new("UIStroke", { Name = "Outline", Color = INK, Thickness = 2, LineJoinMode = Enum.LineJoinMode.Round, Parent = price })
	priceLabels[p.Key] = price
	return b
end

-- Crates -------------------------------------------------------------------------------------------------------------

local function canOpenHere(): boolean
	local player = Players.LocalPlayer
	local role = player:GetAttribute("HuzzRole")
	if role == "Runner" or role == "Catcher" or player:GetAttribute("HuzzChoosing") == true or player:GetAttribute("HuzzCinematic") == true then
		Toast.show("Open crates in the lobby.")
		return false
	end
	return true
end

-- A Robux product sold through the server's own prompt (crate keys: "PromptCrateKey"; the Halloween crate keys and
-- knives: "PromptHalloween"). Id 0 = "coming soon", never a purchase.
local function promptVia(verb: string, p)
	if pending[p.Key] then return end
	local status = Products.status(p)
	if status ~= "Ready" then
		Toast.show(`{p.Name} for Robux is coming soon.`)
		if status == "NoId" then warn(`[Shop] {p.Key} has no Developer Product ID in Shared/Config/Products.lua`) end
		return
	end
	pending[p.Key] = true
	local ok, why = State.action(verb, p.Key) -- (the server checks it again and opens Roblox's prompt)
	if not ok then
		pending[p.Key] = nil
		Toast.show(why or "The purchase couldn't open. Try again.")
		return
	end
	task.delay(90, function() pending[p.Key] = nil end) -- (never stuck if Roblox doesn't report back)
end

-- every item of a crate and its exact chance, rarest last, in `cols` columns of `rowW` px from (x, y) in `parent`
local ODDS = { RowH = 29, RowGap = 1, ColGap = 9 }
local function oddsRows(parent: Instance, crate, x: number, y: number, cols: number, rowW: number, z: number?): number
	local z0 = z or 1
	local odds = CrateRoll.odds(crate)
	local rows = math.ceil(#odds / cols)
	for i, o in odds do
		local col, r = (i - 1) // rows, (i - 1) % rows
		local it = o.item
		local row = new("Frame", { Name = "Odds" .. i, Position = UDim2.fromOffset(x + col * (rowW + ODDS.ColGap), y + r * (ODDS.RowH + ODDS.RowGap)), Size = UDim2.fromOffset(rowW, ODDS.RowH), BackgroundColor3 = C.MenuPanel, BackgroundTransparency = 0.2, BorderSizePixel = 0, ZIndex = z0, Parent = parent }, { Kit.corner(3) })
		new("Frame", { Name = "RarityBar", Size = UDim2.new(0, 4, 1, 0), BackgroundColor3 = CrateArt.color(it.Rarity), BorderSizePixel = 0, ZIndex = z0 + 1, Parent = row }, { Kit.corner(2) })
		CrateArt.picture(row, it, 40, 25, 4, UDim2.fromOffset(8, 2), z0 + 1)
		local nameW = rowW - 118
		local nm = Kit.name({ Name = "Name", Text = it.Name, FontFace = Theme.Fonts.Name, TextSize = 13, Position = UDim2.fromOffset(54, 1), Size = UDim2.fromOffset(nameW, 15), ZIndex = z0 + 2, Parent = row })
		Kit.fitLine(nm, nameW, 13, 10, true)
		local rr = Kit.text({ Name = "Rarity", Text = string.upper(it.Rarity), FontFace = Theme.Fonts.Heading, TextSize = 9, TextColor3 = CrateArt.color(it.Rarity), TextWrapped = false, Position = UDim2.fromOffset(54, 16), Size = UDim2.fromOffset(nameW, 11), ZIndex = z0 + 2, Parent = row })
		new("UIStroke", { Name = "Outline", Color = C.TitleStroke, Thickness = 1, Parent = rr })
		Kit.text({ Name = "Chance", Text = string.format("%g%%", math.floor(o.chance * 10 + 0.5) / 10), FontFace = Theme.Fonts.Number, TextSize = 15, TextXAlignment = Enum.TextXAlignment.Right, TextWrapped = false, Position = UDim2.fromOffset(rowW - 62, 0), Size = UDim2.fromOffset(54, ODDS.RowH), ZIndex = z0 + 2, Parent = row })
	end
	return rows * (ODDS.RowH + ODDS.RowGap) - ODDS.RowGap
end

-- The one backdrop every crate stands on (owner, Oct 20 20:34: "make all of the crate pictures have the same background
-- so they all look the same, but just the crate is different"): a deep purple stage with a warm orange glow behind
-- the crate, a soft shadow it stands on and a thin orange rim. Drawn with frames (nothing to upload).
local function backdrop(parent: Instance, name: string, x: number, y: number, w: number, h: number, z: number, glow: Color3?): Frame
	local f = new("Frame", { Name = name, Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(w, h), BackgroundColor3 = WHITE, BorderSizePixel = 0, ZIndex = z, Parent = parent }, { Kit.corner(6), Kit.stroke(ORANGE, 1.5, 0.45) })
	new("UIGradient", { Name = "Fill", Rotation = 90, Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, hex("2B1352")), ColorSequenceKeypoint.new(0.6, hex("3D1A6B")), ColorSequenceKeypoint.new(1, hex("150829")) }), Parent = f })
	local g = math.min(w, h)
	local halo = new("Frame", { Name = "Glow", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(w // 2, math.round(h * 0.52)), Size = UDim2.fromOffset(math.round(g * 1.1), math.round(g * 0.9)), BackgroundColor3 = glow or hex("FF8A2A"), BorderSizePixel = 0, ZIndex = z, Parent = f }, { Kit.corner(math.round(g * 0.45)) })
	new("UIGradient", { Name = "Soft", Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0.55), NumberSequenceKeypoint.new(1, 1) }), Parent = halo })
	new("Frame", { Name = "Floor", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(w // 2, h - math.max(8, h // 10)), Size = UDim2.fromOffset(math.round(g * 0.8), math.max(6, g // 10)), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.55, BorderSizePixel = 0, ZIndex = z, Parent = f }, { Kit.corner(math.max(3, g // 20)) })
	return f
end

-- his crate, cut out of his picture, standing on the backdrop (rocking gently)
local function cratePicture(bd: Frame, crate, z: number, rock: boolean?): ImageLabel
	local w, h = bd.Size.X.Offset, bd.Size.Y.Offset
	local side = math.min(w - 8, h - 6)
	local pic = Kit.art(crate.Picture or "CrateCardCutDojo", { Name = "Crate", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.fromOffset(w // 2, h - 2), Size = UDim2.fromOffset(side, side), ScaleType = Enum.ScaleType.Fit, ZIndex = z, Parent = bd })
	if rock then Effects.rock(pic, { degrees = 2.5, seconds = 1.6 }) end
	return pic
end

-- its Robux key: Shop keys go through "PromptCrateKey", the Halloween stands' through "PromptHalloween"
local function keyOf(crate): (any, string?)
	for _, e in HalloweenShop.Crates do
		if e.Crate == crate.Id then return Products.get(e.Robux), "PromptHalloween" end
	end
	local p = Products.crateKey(crate.Id)
	return p, if p then "PromptCrateKey" else nil
end

local function isHalloween(crate): boolean
	return crate.Home ~= nil or crate.Id == "Halloween"
end

-- the Halloween crates in his picture's order (Candy, Witch, Halloween), then his three knife crates
local HALLOWEEN_ORDER = { "Sweets", "Witch", "Halloween" }

-- Coin shop items (small cards) -----------------------------------------------------------------------------------------

local rarityColor = {}
for _, r in RoundConfig.Rarities do rarityColor[r.Name] = r.Color end
rarityColor.Secret = Color3.fromRGB(150, 110, 255) -- (near-black in the roller; violet reads on the dark window)
rarityColor.Exclusive = Color3.fromRGB(255, 170, 230) -- the Game Pass knives, once owned
local RARITY_ORDER = { "Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic", "Secret", "Divine", "Exclusive" }

-- a drawn picture for a coin item without one (titles, name colours, knives; trails and auras: UI/LookPicture)
local function swatch(parent: Instance, item: CoinShop.Item, size: number)
	local f = new("Frame", { Name = "Drawn", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(SMALL.W // 2, SMALL.PicY + SMALL.PicH // 2), Size = UDim2.fromOffset(size, size), BackgroundTransparency = 1, ZIndex = 2, Parent = parent })
	if item.Slot == "Trail" then
		local streak = new("Frame", { Name = "Streak", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(1, -12, 0, 30), Rotation = -20, BackgroundColor3 = WHITE, BorderSizePixel = 0, ZIndex = 2, Parent = f }, { Kit.corner(15) })
		new("UIGradient", { Name = "Colours", Color = CoinShop.sequence(item), Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.85), NumberSequenceKeypoint.new(0.6, 0.15), NumberSequenceKeypoint.new(1, 0) }), Parent = streak })
	elseif item.Slot == "Aura" then
		local ring = new("Frame", { Name = "Ring", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(64, 64), BackgroundTransparency = 1, ZIndex = 2, Parent = f }, { Kit.corner(32) })
		new("UIStroke", { Name = "Glow", Color = WHITE, Thickness = 6, Parent = ring }, { new("UIGradient", { Name = "Colours", Rotation = 45, Color = CoinShop.sequence(item) }) })
		local core = new("Frame", { Name = "Core", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(28, 28), BackgroundColor3 = WHITE, BorderSizePixel = 0, ZIndex = 2, Parent = f }, { Kit.corner(14) })
		new("UIGradient", { Name = "Colours", Rotation = 90, Color = ColorSequence.new(WHITE, item.Colors[1]), Parent = core })
	elseif item.Slot == "Title" or item.Slot == "Tag" then
		local word = chunky({ Name = "Word", Text = if item.Slot == "Title" then string.upper(item.Name) else "Aa", TextScaled = item.Slot == "Title", TextWrapped = item.Slot == "Title", TextSize = 40, TextColor3 = item.Colors[1], Position = UDim2.fromOffset(4, 0), Size = UDim2.new(1, -8, 1, 0), ZIndex = 2, Parent = f })
		if #item.Colors > 2 then
			word.TextColor3 = WHITE
			new("UIGradient", { Name = "Colours", Color = CoinShop.sequence(item), Parent = word })
		end
	else
		local knife = new("Frame", { Name = "Knife", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(22, 84), Rotation = 35, BackgroundTransparency = 1, ZIndex = 2, Parent = f })
		new("Frame", { Name = "Blade", Size = UDim2.fromOffset(22, 48), BackgroundColor3 = item.Colors[1], BorderSizePixel = 0, ZIndex = 2, Parent = knife }, { Kit.corner(11) })
		new("Frame", { Name = "Guard", Position = UDim2.fromOffset(-8, 48), Size = UDim2.fromOffset(38, 8), BackgroundColor3 = item.Colors[#item.Colors], BorderSizePixel = 0, ZIndex = 2, Parent = knife }, { Kit.corner(3) })
		new("Frame", { Name = "Handle", Position = UDim2.fromOffset(5, 56), Size = UDim2.fromOffset(12, 28), BackgroundColor3 = C.Ink, BorderSizePixel = 0, ZIndex = 2, Parent = knife }, { Kit.corner(4) })
	end
	return f
end

-- Aura packs: his Aura star (the kit's AuraStar, as drawn): one, two or three for the bigger packs
local function auraStars(parent: Instance, i: number)
	local spots = ({ { { 0.5, 0.5, 112 } }, { { 0.42, 0.52, 104 }, { 0.72, 0.42, 64 } }, { { 0.5, 0.54, 104 }, { 0.22, 0.42, 62 }, { 0.78, 0.42, 62 } } })[i] or { { 0.5, 0.5, 112 } }
	for k, sp in spots do
		local star = Kit.icon("AuraStar", { Name = "Star" .. k, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(math.round(BIG.W * sp[1]), BIG.PicY + math.round(BIG.PicH * sp[2])), Size = UDim2.fromOffset(sp[3], sp[3]), ZIndex = if k == 1 then 3 else 2, Parent = parent })
		if star:IsA("ImageLabel") then star.ImageColor3 = WHITE end -- (his star as drawn)
	end
end

function Shop.build(parent: Instance)
	-- Flat (no CanvasGroup): the 3D crates that stand in for his pictures (ViewportFrames) must show.
	local window = Kit.window({ Name = "Shop", Flat = true, Title = "Shop", Icon = "ShopCart", Width = TOTAL_W, Height = WIN.H, HeaderHeight = WIN.Header, TitleX = 24, TitleSize = WIN.TitleSize, TitleWidth = 120, StudsTo = 300, CloseSize = Vector2.new(46, 46), Parent = parent, OnClose = function() ModalManager.close() end })
	local panel, header = window.Panel, window.Header
	panel.Size = UDim2.fromOffset(WIN.W, WIN.H) -- (the jump column stands outside the window, as in the video)
	-- our kit's window as it comes (owner, Oct 20 20:34: "make the ui for the shop colour match our ui"): the purple
	-- studded title bar, the see-through navy studded body; the title in the video's chunky letters
	local titleIcon = header:FindFirstChild("TitleIcon")
	if titleIcon and titleIcon:IsA("GuiObject") then titleIcon.Visible = false end
	for _, n in { "Title", "TitleShadow" } do
		local t = header:FindFirstChild(n)
		if t and t:IsA("TextLabel") then t.FontFace = SHOP_FONT; t.TextSize = WIN.TitleSize end
	end
	-- Halloween trim: an orange line under the title bar, a pumpkin and two bats beside the title
	new("Frame", { Name = "HalloweenTrim", Position = UDim2.new(0, 0, 1, -3), Size = UDim2.new(1, 0, 0, 3), BackgroundColor3 = ORANGE, BorderSizePixel = 0, ZIndex = 3, Parent = header })
	for k, e in { { "Pumpkin", "\u{1F383}", 318, 14, 40 }, { "Bat1", "\u{1F987}", 372, 8, 24 }, { "Bat2", "\u{1F987}", 410, 34, 18 } } do
		local l = Kit.text({ Name = e[1], Text = e[2], TextSize = e[5], TextXAlignment = Enum.TextXAlignment.Center, TextWrapped = false, Position = UDim2.fromOffset(e[3], e[4]), Size = UDim2.fromOffset(e[5] + 8, e[5] + 6), ZIndex = 4, Parent = header })
		if k > 1 then Effects.rock(l, { degrees = 6, seconds = 1.1 + k * 0.2 }) end
	end
	-- your coins and Aura, small in the title bar (the video shows its money outside the window; ours sits under it)
	local coins = Kit.pill({ Name = "Coins", Icon = "CurrencyCoin", Position = UDim2.fromOffset(520, 21), Width = 121, Parent = header })
	local gems = Kit.pill({ Name = "Aura", Icon = "AuraStar", Position = UDim2.fromOffset(651, 21), Width = 108, Parent = header })
	local gemIcon = gems.Instance:FindFirstChild("Icon")
	if gemIcon and gemIcon:IsA("ImageLabel") then gemIcon.ImageColor3 = WHITE end -- (the owner's Aura star, as drawn)

	-- the one page
	local body = new("ScrollingFrame", { Name = "Products", Position = UDim2.fromOffset(BODY.X, BODY.Y), Size = UDim2.fromOffset(BODY.W, BODY.H), BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 6, ScrollBarImageColor3 = hex("C8D0D8"), ScrollBarImageTransparency = 0.35, CanvasSize = UDim2.new(), ScrollingDirection = Enum.ScrollingDirection.Y, Parent = panel })
	Kit.attach(Kit.pad(PAD, PAD, PAD, PAD), body)

	-- The page's flow, top to bottom; layout() places everything and keeps each section's top.
	local flow: { any } = {}
	local sectionY: { [string]: number } = {}
	local function block(el: GuiObject, h: number, x: number?, after: number?, group: { GuiObject }?)
		table.insert(flow, { kind = "block", el = el, h = h, x = x or 0, after = after or 0, group = group })
	end
	local function grid(cards: { GuiObject }, cols: number, w: number, h: number, gap: number, after: number?)
		table.insert(flow, { kind = "grid", cards = cards, cols = cols, w = w, h = h, gap = gap, after = after or 0 })
	end
	local function mark(key: string) table.insert(flow, { kind = "mark", key = key }) end
	local function layout()
		local y = 0
		for _, e in flow do
			if e.kind == "mark" then
				sectionY[e.key] = y
			elseif e.kind == "block" then
				if e.group then -- (a header over a group of cards: only while one of them shows)
					local any = false
					for _, c in e.group do if c.Visible then any = true; break end end
					e.el.Visible = any
				end
				if e.el.Visible then
					e.el.Position = UDim2.fromOffset(e.x, y)
					y += e.h + e.after
				end
			else
				local shown = {}
				for _, c in e.cards do if c.Visible then table.insert(shown, c) end end
				local rows = math.ceil(#shown / e.cols)
				for i, c in shown do
					local col, r = (i - 1) % e.cols, (i - 1) // e.cols
					local inRow = if r == rows - 1 then #shown - r * e.cols else e.cols
					local rowW = inRow * e.w + (inRow - 1) * e.gap
					local x0 = (CW - rowW) // 2 -- (a short last row sits in the middle)
					c.Position = UDim2.fromOffset(x0 + col * (e.w + e.gap), y + r * (e.h + e.gap))
				end
				if rows > 0 then y += rows * (e.h + e.gap) - e.gap + e.after end
			end
		end
		body.CanvasSize = UDim2.fromOffset(0, y + 2 * PAD + 8)
	end

	local popList: { { card: GuiObject, scale: UIScale } } = {} -- every card, for the pop-in when the Shop opens
	local function card(name: string, w: number, h: number, lk): Frame
		local c = new("Frame", { Name = name, Size = UDim2.fromOffset(w, h), BackgroundColor3 = WHITE, BackgroundTransparency = CARD_T, BorderSizePixel = 0, Parent = body }, { Kit.corner(3), Kit.stroke(lk.Rim, 2) })
		new("UIGradient", { Name = "Fill", Rotation = 90, Color = ColorSequence.new(lk.Top, lk.Bottom), Parent = c })
		table.insert(popList, { card = c, scale = Effects.lift(c) }) -- (lifts a little under the mouse)
		return c
	end
	-- the video's card: a bold title, a big picture, one short line and a small one, the buttons at the foot
	local function bigCard(name: string, lk, title: string, w: number?): Frame
		local cw = w or BIG.W
		local c = card(name, cw, BIG.H, lk)
		local t = chunky({ Name = "Title", Text = title, TextSize = BIG.TitleSize, Position = UDim2.fromOffset(8, BIG.TitleY), Size = UDim2.fromOffset(cw - 16, BIG.TitleH), ZIndex = 3, Parent = c }, 3)
		Kit.fitLine(t, cw - 16, BIG.TitleSize, 16, true)
		return c
	end
	local function lines(c: Frame, l1: string, l2: string, color1: Color3?, names: { string }?): (TextLabel, TextLabel)
		local cw = c.Size.X.Offset
		local a = chunky({ Name = names and names[1] or "Line", Text = l1, TextSize = BIG.LineSize, TextColor3 = color1 or WHITE, Position = UDim2.fromOffset(8, BIG.LineY), Size = UDim2.fromOffset(cw - 16, BIG.LineH), ZIndex = 3, Parent = c }, 1.5)
		Kit.fitLine(a, cw - 16, BIG.LineSize, 11, true)
		local b = chunky({ Name = names and names[2] or "Small", Text = l2, TextSize = BIG.SmallSize, Position = UDim2.fromOffset(8, BIG.SmallY), Size = UDim2.fromOffset(cw - 16, BIG.SmallH), ZIndex = 3, Parent = c }, 1.2)
		Kit.fitLine(b, cw - 16, BIG.SmallSize, 9, true)
		return a, b
	end
	local function blurbLines(p): (string, string)
		local a, b = string.match(p.Blurb or "", "^(.-)\n(.*)$")
		return a or (p.Blurb or ""), string.upper(b or "")
	end
	local function picture(c: Frame, art: string)
		local cw = c.Size.X.Offset
		return Kit.art(art, { Name = "Picture", Position = UDim2.fromOffset(12, BIG.PicY), Size = UDim2.fromOffset(cw - 24, BIG.PicH), ScaleType = Enum.ScaleType.Fit, ZIndex = 2, Parent = c })
	end
	local function priceRow(c: Frame, p)
		return buyButton(c, p, { Position = UDim2.fromOffset(BIG.ButtonX, BIG.ButtonY), Size = UDim2.fromOffset(BIG.W - 2 * BIG.ButtonX, BIG.ButtonH) })
	end
	local function head(s): Frame
		local f = new("Frame", { Name = "Head" .. s.Key, Size = UDim2.fromOffset(CW, HEAD.H), BackgroundTransparency = 1, Parent = body })
		local t = chunky({ Name = "Title", Text = s.Text, TextSize = HEAD.TextSize, TextColor3 = WHITE, Size = UDim2.fromScale(1, 1), ZIndex = 2, Parent = f }, 3)
		new("UIGradient", { Name = "Colour", Rotation = 90, Color = ColorSequence.new(s.Fill:Lerp(WHITE, 0.72), s.Fill:Lerp(WHITE, 0.15)), Parent = t })
		return f
	end
	local function subHead(name: string, text: string, color: Color3): TextLabel
		local t = chunky({ Name = name, Text = text, TextSize = SUB.TextSize, TextColor3 = WHITE, Size = UDim2.fromOffset(CW, SUB.H), ZIndex = 2, Parent = body }, 2.5)
		new("UIGradient", { Name = "Colour", Rotation = 90, Color = ColorSequence.new(color:Lerp(WHITE, 0.6), color), Parent = t })
		return t
	end
	local bySection = {}
	for _, s in SECTIONS do bySection[s.Key] = s end
	local cardsOf: { [string]: GuiObject } = {} -- crate id -> its card (the stands and BACK scroll to it)

	-- FILTERS: every card a filter row can hide, with what it is (section, rarity, type, name, owned?)
	type Entry = { card: GuiObject, sec: string, rarity: string?, slot: string?, name: string, owned: () -> boolean, base: () -> boolean }
	local filterable: { Entry } = {}
	local empties: { [string]: GuiObject } = {} -- section -> its "nothing matches" line
	local chipsOf: { [string]: { [string]: { [string]: any } } } = {} -- "<section><row>" -> chip key -> chip
	local function passes(e: Entry): boolean
		local f = FILTER[e.sec]
		if not f then return true end
		if f.Rarity ~= "All" and e.rarity ~= f.Rarity then return false end
		if f.Type and f.Type ~= "All" and e.slot ~= f.Type then return false end
		if f.Own ~= "All" and (f.Own == "Owned") ~= e.owned() then return false end
		local q = string.lower(string.match(f.Search or "", "^%s*(.-)%s*$") or "")
		if q ~= "" and not string.find(string.lower(e.name), q, 1, true) then return false end
		return true
	end
	-- shows and hides the cards (the page is placed again by the caller); true if anything changed
	local function applyFilters(): boolean
		local changed = false
		local any: { [string]: boolean } = {}
		for _, e in filterable do
			local v = e.base() and passes(e)
			if e.card.Visible ~= v then e.card.Visible = v; changed = true end
			if v then any[e.sec] = true end
		end
		for sec, line in empties do
			local v = not any[sec]
			if line.Visible ~= v then line.Visible = v; changed = true end
		end
		return changed
	end
	local layoutRef: { fn: (() -> ())? } = {}
	-- one chip row: left to right, sized to their words (smaller words if the row must, never past maxW)
	local function chipRow(parent: GuiObject, name: string, defs: { any }, x0: number, y: number, maxW: number, onPick: (string) -> ())
		local size = CHIP.TextSize
		local function measure(sz: number): ({ number }, number)
			local ws, total = {}, 0
			for i, d in defs do
				ws[i] = math.max(CHIP.MinW, math.ceil(Kit.textWidth(d.Text, SHOP_FONT, sz)) + CHIP.Pad)
				total += ws[i] + (if i > 1 then CHIP.Gap else 0)
			end
			return ws, total
		end
		local ws, total = measure(size)
		while total > maxW and size > 14 do size -= 1; ws, total = measure(size) end
		if total > maxW then for i in ws do ws[i] = (maxW - (#defs - 1) * CHIP.Gap) // #defs end end
		local chips = {}
		local x = x0
		for i, d in defs do
			local off, on = chipStyle(name .. d.Key, d.Color)
			local b = chunkyButton(Kit.button({ Name = name .. d.Key, Text = d.Text, Style = off, FontFace = SHOP_FONT, TextSize = size, Corner = 3, Size = UDim2.fromOffset(ws[i], CHIP.H), ZIndex = 3, Parent = parent }))
			Kit.place(b.Instance, UDim2.fromOffset(x, y), UDim2.fromOffset(ws[i], CHIP.H)) -- (placed every time: a saved row may differ)
			b.onClick(function() onPick(d.Key) end)
			chips[d.Key] = { button = b, off = off, on = on }
			x += ws[i] + CHIP.Gap
		end
		return chips, x - CHIP.Gap - x0
	end
	local function showChips(chips, picked: string)
		for key, ch in chips do
			local sel = key == picked
			ch.button.setStyle(if sel then ch.on else ch.off)
			chunkyButton(ch.button)
			local rim = ch.button.Instance:FindFirstChild("Rim")
			if rim and rim:IsA("UIStroke") then rim.Color, rim.Thickness = if sel then WHITE else Kit.Styles[ch.off].Rim, if sel then 3 else 1.5 end
			ch.button.Instance:SetAttribute("Picked", sel)
		end
	end
	local function refreshChips(sec: string)
		local f = FILTER[sec]
		for row, chips in chipsOf do
			if string.sub(row, 1, #sec) == sec then
				local what = string.sub(row, #sec + 1)
				showChips(chips, if what == "Own" then f.Own else if what == "Type" then f.Type else f.Rarity)
			end
		end
	end
	local function pick(sec: string, what: string, key: string)
		local f = FILTER[sec]
		if what == "Own" then f.Own = if f.Own == key then "All" else key -- (OWNED / NOT OWNED: tap again for all)
		else f[what] = key end
		refreshChips(sec)
		if applyFilters() and layoutRef.fn then layoutRef.fn() end
	end
	-- the rarities present among some cards, in order, as chips (ALL first)
	local function rarityDefs(list: { any }, allText: string): { any }
		local have = {}
		for _, it in list do if it.Rarity then have[it.Rarity] = true end end
		local defs = { { Key = "All", Text = allText, Color = TYPE_COLOUR.All } }
		for _, r in RARITY_ORDER do
			if have[r] and r ~= "Exclusive" then table.insert(defs, { Key = r, Text = string.upper(r), Color = rarityColor[r] or WHITE }) end
		end
		return defs
	end
	-- the search box (a long list: knives)
	local function searchBox(parent: GuiObject, sec: string, x: number, y: number, w: number, hint: string)
		local f = new("Frame", { Name = "Search", Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(w, CHIP.H), BackgroundColor3 = C.MenuPanel, BorderSizePixel = 0, ZIndex = 3, Parent = parent }, { Kit.corner(3), Kit.stroke(C.Divider, 2) })
		local icon = Kit.icon("Search", { Name = "Icon", Position = UDim2.fromOffset(12, 10), Size = UDim2.fromOffset(19, 20), ZIndex = 4, Parent = f })
		if icon:IsA("ImageLabel") then icon.ImageColor3 = C.SubText end
		local ph = chunky({ Name = "Hint", Text = hint, TextSize = 18, TextColor3 = C.SubText, TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.fromOffset(40, 0), Size = UDim2.fromOffset(w - 80, CHIP.H), ZIndex = 4, Parent = f }, 1)
		Kit.fitLine(ph, w - 80, 18, 12, true)
		local box: TextBox = new("TextBox", { Name = "Box", Text = FILTER[sec].Search or "", PlaceholderText = "", ClearTextOnFocus = false, BackgroundTransparency = 1, FontFace = SHOP_FONT, TextSize = 19, TextColor3 = WHITE, TextXAlignment = Enum.TextXAlignment.Left, TextWrapped = false, ClipsDescendants = true, Position = UDim2.fromOffset(40, 0), Size = UDim2.fromOffset(w - 80, CHIP.H), ZIndex = 5, Parent = f })
		local clear = chunkyButton(Kit.button({ Name = "Clear", Text = "X", Style = (chipStyle("Clear", TYPE_COLOUR.All)), FontFace = SHOP_FONT, TextSize = 18, Corner = 3, Size = UDim2.fromOffset(30, 30), ZIndex = 5, Parent = f }))
		Kit.place(clear.Instance, UDim2.fromOffset(w - 36, 5), UDim2.fromOffset(30, 30))
		local function show()
			ph.Visible = box.Text == ""
			clear.Instance.Visible = box.Text ~= ""
		end
		clear.onClick(function() box.Text = "" end)
		box:GetPropertyChangedSignal("Text"):Connect(function()
			if #box.Text > 24 then box.Text = string.sub(box.Text, 1, 24); return end
			show()
			if FILTER[sec].Search ~= box.Text then
				FILTER[sec].Search = box.Text
				if applyFilters() and layoutRef.fn then layoutRef.fn() end
			end
		end)
		show()
		return f
	end
	-- a section's "nothing matches" line (only while every card is filtered out)
	local function emptyLine(sec: string, text: string): TextLabel
		local l = chunky({ Name = "Nothing" .. sec, Text = text, TextSize = 22, TextColor3 = C.NoteText, Size = UDim2.fromOffset(CW, 60), Visible = false, ZIndex = 2, Parent = body }, 2)
		Kit.fitLine(l, CW - 20, 22, 14, true)
		empties[sec] = l
		return l
	end

	-- THE SIDE PANEL -----------------------------------------------------------------------------------------------------
	-- Tapping a crate or a dance slides its panel in from the right, over the page (owner, Oct 20 20:34: "only show it
	-- when you click on a crate, then on the side it pops up"). A crate's panel holds its every item and chance, the
	-- pity counter and the buttons that spend (so the odds are in view whenever you pay); a dance's panel holds a
	-- preview and BUY. Tap the dark page beside it, or its X, to close it. Everything is built once (and saved with
	-- the UI): one view per crate and one dance view, shown as needed.
	local scrollTo: (string, boolean?) -> ()
	local dancersInViewRef = { fn = function() end }
	local side = new("Frame", { Name = "Side", Position = UDim2.fromOffset(BODY.X, BODY.Y), Size = UDim2.fromOffset(BODY.W, BODY.H), BackgroundTransparency = 1, ClipsDescendants = true, Visible = false, ZIndex = 30, Parent = panel })
	local shade = new("TextButton", { Name = "Shade", Text = "", AutoButtonColor = false, Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 30, Parent = side })
	local SHUT_X, OPEN_X = BODY.W + 4, BODY.W - SIDE.W
	local sp = new("Frame", { Name = "Panel", Position = UDim2.fromOffset(SHUT_X, 0), Size = UDim2.fromOffset(SIDE.W, BODY.H), BackgroundColor3 = WHITE, BackgroundTransparency = 0, BorderSizePixel = 0, ZIndex = 31, Parent = side }, { Kit.corner(6), Kit.stroke(ORANGE, 2) })
	new("UIGradient", { Name = "Fill", Rotation = 90, Color = ColorSequence.new(hex("23366A"), hex("141F45")), Parent = sp })
	local sideTitle = chunky({ Name = "Title", Text = "", TextSize = 30, TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.fromOffset(SIDE.Pad, 8), Size = UDim2.fromOffset(SIDE.W - 2 * SIDE.Pad - 56, 42), ZIndex = 33, Parent = sp }, 2.5)
	local sideClose = Kit.button({ Name = "Close", Text = "X", Style = "Close", FontFace = SHOP_FONT, TextSize = 26, Corner = 4, Position = UDim2.fromOffset(SIDE.W - SIDE.Pad - 42, 8), Size = UDim2.fromOffset(42, 42), ZIndex = 34, Parent = sp })
	chunkyButton(sideClose)
	local sideOpen = false
	local showing: any = nil -- the crate or dance in the panel
	local sideRefresh: { () -> () } = {}
	local function closeSide(instant: boolean?)
		if not sideOpen then return end
		sideOpen, showing = false, nil
		if instant or Motion.reduced then
			sp.Position, shade.BackgroundTransparency, side.Visible = UDim2.fromOffset(SHUT_X, 0), 1, false
			return
		end
		Motion.tween(sp, "slide", 0.22, { Position = UDim2.fromOffset(SHUT_X, 0) }, Enum.EasingStyle.Quad)
		Motion.tween(shade, "fade", 0.22, { BackgroundTransparency = 1 }, Enum.EasingStyle.Quad)
		task.delay(0.24, function() if not sideOpen then side.Visible = false end end)
	end
	local function slideIn()
		side.Visible = true
		for _, f in sideRefresh do f() end
		if sideOpen then return end
		sideOpen = true
		if Motion.reduced then
			sp.Position, shade.BackgroundTransparency = UDim2.fromOffset(OPEN_X, 0), 0.45
			return
		end
		sp.Position, shade.BackgroundTransparency = UDim2.fromOffset(SHUT_X, 0), 1
		Motion.tween(sp, "slide", 0.38, { Position = UDim2.fromOffset(OPEN_X, 0) }, Enum.EasingStyle.Quint)
		Motion.tween(shade, "fade", 0.3, { BackgroundTransparency = 0.45 }, Enum.EasingStyle.Quad)
	end
	shade.Activated:Connect(function() closeSide() end)
	sideClose.onClick(function() closeSide() end)
	table.insert(refreshButtons, function() for _, f in sideRefresh do f() end end)

	-- a crate's view: his crate on the backdrop, the pity counter, every chance (scrolls when long), the buttons
	local crateViews: { [string]: Frame } = {}
	local CV = { PicY = 58, PicW = 150, PicH = 132, InfoX = SIDE.Pad + 150 + 14, OddsY = 222, ButtonY = BODY.H - SIDE.Pad - SIDE.ButtonH }
	local function payWith(crate, coins: boolean)
		if not canOpenHere() then return end
		local keys = (State.data.CrateKeys or {})[crate.Id] or 0
		if keys <= 0 then
			local have = if coins then State.data.Coins or 0 else State.data.Aura or 0
			local price = if coins then crate.CoinPrice or 0 else crate.Price
			if have < price then
				Toast.show(if coins then `You need {Format.commas(price - have)} more coins.` else `You need {price - have} more Aura. Collect stars on the field!`)
				return
			end
		end
		ModalManager.open("CrateOpen", crate.Id .. (if coins and keys <= 0 then "|Coins" else ""))
	end
	local function crateView(crate)
		local v = new("Frame", { Name = "Crate" .. crate.Id, Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Visible = false, ZIndex = 32, Parent = sp })
		cratePicture(backdrop(v, "Backdrop", SIDE.Pad, CV.PicY, CV.PicW, CV.PicH, 32), crate, 33, true)
		local infoW = SIDE.W - CV.InfoX - SIDE.Pad
		local top = crate.Pity and crate.Pity.Rarity or ""
		local pityTop = chunky({ Name = "PityLabel", Text = if top ~= "" then `GUARANTEED {string.upper(top)}` else "", TextSize = 22, TextColor3 = CrateArt.color(top ~= "" and top or "Common"), TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.fromOffset(CV.InfoX, CV.PicY + 4), Size = UDim2.fromOffset(infoW, 28), ZIndex = 33, Parent = v }, 2)
		Kit.fitLine(pityTop, infoW, 22, 14, true)
		local pity = chunky({ Name = "Pity", Text = "", TextSize = 20, TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.fromOffset(CV.InfoX, CV.PicY + 34), Size = UDim2.fromOffset(infoW, 26), ZIndex = 33, Parent = v }, 1.5)
		local keysLine = chunky({ Name = "Keys", Text = "", TextSize = 18, TextColor3 = CANDY, TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.fromOffset(CV.InfoX, CV.PicY + 64), Size = UDim2.fromOffset(infoW, 24), ZIndex = 33, Parent = v }, 1.5)
		local note = chunky({ Name = "Note", Text = "Each open gives one item with these chances.", TextSize = 15, TextColor3 = C.NoteText, TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.fromOffset(CV.InfoX, CV.PicY + 98), Size = UDim2.fromOffset(infoW, 22), ZIndex = 33, Parent = v }, 1)
		Kit.fitLine(note, infoW, 15, 10, true)
		local oh = chunky({ Name = "OddsHead", Text = "EVERY CHANCE", TextSize = 20, TextColor3 = CANDY, TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.fromOffset(SIDE.Pad, CV.OddsY - 26), Size = UDim2.fromOffset(240, 24), ZIndex = 33, Parent = v }, 2)
		oh.TextColor3 = CANDY
		local listH = CV.ButtonY - 10 - CV.OddsY
		local list = new("ScrollingFrame", { Name = "Odds", Position = UDim2.fromOffset(SIDE.Pad, CV.OddsY), Size = UDim2.fromOffset(SIDE.W - 2 * SIDE.Pad, listH), BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 6, ScrollBarImageColor3 = hex("C8D0D8"), ScrollBarImageTransparency = 0.35, CanvasSize = UDim2.new(), ScrollingDirection = Enum.ScrollingDirection.Y, ZIndex = 33, Parent = v })
		local rowW = (SIDE.W - 2 * SIDE.Pad - 10 - ODDS.ColGap) // 2
		local h = oddsRows(list, crate, 0, 0, 2, rowW, 33)
		list.CanvasSize = UDim2.fromOffset(0, h)
		-- the buttons: coins and Aura (his Halloween crates), or OPEN for Aura; a Robux KEY where it has one
		local keyP, verb = keyOf(crate)
		local W = SIDE.W - 2 * SIDE.Pad
		local gap = 8
		local n = (if crate.CoinPrice then 2 else 1) + (if keyP then 1 else 0)
		local keyW = if keyP then (if n == 3 then 140 else 180) else 0
		local payW = if crate.CoinPrice then (W - keyW - (n - 1) * gap) // 2 else W - keyW - (n - 1) * gap
		local x = SIDE.Pad
		local coinB: any = nil
		if crate.CoinPrice then
			coinB = chunkyButton(Kit.button({ Name = "PayCoins", Text = Format.commas(crate.CoinPrice), Icon = "CurrencyCoin", IconAfter = true, IconSize = 26, Gap = 6, TextSize = 26, FontFace = SHOP_FONT, Style = "ShopGreen", Corner = 4, Position = UDim2.fromOffset(x, CV.ButtonY), Size = UDim2.fromOffset(payW, SIDE.ButtonH), ZIndex = 34, Parent = v }))
			coinB.onClick(function() payWith(crate, true) end)
			x += payW + gap
		end
		local auraB = chunkyButton(Kit.button({ Name = "Open", Text = "", Icon = "AuraStar", IconAfter = true, IconSize = 26, Gap = 6, TextSize = 26, FontFace = SHOP_FONT, Style = if crate.CoinPrice then "ShopAura" else "ShopGreen", Corner = 4, Position = UDim2.fromOffset(x, CV.ButtonY), Size = UDim2.fromOffset(payW, SIDE.ButtonH), ZIndex = 34, Parent = v }))
		auraB.onClick(function() payWith(crate, false) end)
		local auraIcon = auraB.Instance:FindFirstChild("Icon", true) :: GuiObject?
		local coinIcon = coinB and coinB.Instance:FindFirstChild("Icon", true) :: GuiObject?
		x += payW + gap
		if keyP and verb then
			robuxButton(v, keyP, "KEY", { Name = "BuyKey", Position = UDim2.fromOffset(x, CV.ButtonY), Size = UDim2.fromOffset(keyW, SIDE.ButtonH), TextSize = 22 }).onClick(function() promptVia(verb, keyP) end)
		end
		Effects.breathe(auraB.Instance, { scale = 1.04, seconds = 0.9 })
		table.insert(sideRefresh, function()
			local left = CrateRoll.left(crate, (State.data.Pity or {})[crate.Id] or 0)
			pity.Text = if left == nil then "" elseif left <= 1 then "ON YOUR NEXT OPEN!" else `IN {left} OPENS OR SOONER`
			Kit.fitLine(pity, infoW, 20, 13, true)
			pityTop.Visible = left ~= nil
			local keys = (State.data.CrateKeys or {})[crate.Id] or 0
			keysLine.Text = if keys > 0 then `YOU HAVE {keys} KEY{if keys == 1 then "" else "S"}` else ""
			-- a key opens it first (the server uses one before any coins or Aura): one USE KEY button then
			if coinB then
				coinB.setText(if keys > 0 then `USE KEY ({keys})` else Format.commas(crate.CoinPrice))
				if coinIcon then coinIcon.Visible = keys <= 0 end
				coinB.setStyle(if keys > 0 or (State.data.Coins or 0) >= crate.CoinPrice then "ShopGreen" else "Disabled")
				chunkyButton(coinB)
				auraB.Instance.Visible = keys <= 0
			end
			auraB.setText(if keys > 0 and not coinB then `USE KEY ({keys})` elseif coinB then tostring(crate.Price) else `OPEN {crate.Price}`)
			if auraIcon then auraIcon.Visible = keys <= 0 or coinB ~= nil end
			auraB.setStyle(if keys <= 0 and (State.data.Aura or 0) < crate.Price then "Disabled" elseif coinB then "ShopAura" else "ShopGreen")
			chunkyButton(auraB)
		end)
		crateViews[crate.Id] = v
		return v
	end

	-- the dance view: a preview (your avatar dancing it where its animation can play here, else its picture), its line,
	-- and BUY
	local DV = { ArtY = 58, ArtH = 250 }
	local dv = new("Frame", { Name = "DanceView", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Visible = false, ZIndex = 32, Parent = sp })
	local dBack = backdrop(dv, "Backdrop", SIDE.Pad, DV.ArtY, SIDE.W - 2 * SIDE.Pad, DV.ArtH, 32, hex("E56CFF"))
	local dStill = Kit.art("DanceStillUntouchable", { Name = "Still", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.fromOffset(dBack.Size.X.Offset // 2, DV.ArtH - 6), Size = UDim2.fromOffset(220, 220), ScaleType = Enum.ScaleType.Fit, ZIndex = 33, Parent = dBack })
	Effects.rock(dStill, { degrees = 5, seconds = 0.5 }) -- (a little dance to the beat while no animation plays)
	local stage = new("ViewportFrame", { Name = "Stage", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Ambient = Color3.fromRGB(225, 225, 232), LightColor = Color3.fromRGB(255, 252, 245), LightDirection = Vector3.new(0.35, -0.75, 0.55), Visible = false, ZIndex = 34, Parent = dBack }, { Kit.corner(6) })
	local dBlurb = chunky({ Name = "Blurb", Text = "", TextSize = 20, TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.fromOffset(SIDE.Pad, DV.ArtY + DV.ArtH + 10), Size = UDim2.fromOffset(SIDE.W - 2 * SIDE.Pad, 26), ZIndex = 33, Parent = dv }, 1.5)
	local dNote = chunky({ Name = "Note", Text = "", TextSize = 15, TextColor3 = C.NoteText, TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.fromOffset(SIDE.Pad, DV.ArtY + DV.ArtH + 40), Size = UDim2.fromOffset(SIDE.W - 2 * SIDE.Pad, 22), ZIndex = 33, Parent = dv }, 1)
	local dBuy = chunkyButton(Kit.button({ Name = "Buy", Text = "", Icon = "CurrencyCoin", IconAfter = true, IconSize = 28, Gap = 8, TextSize = 28, FontFace = SHOP_FONT, Style = "ShopGreen", Corner = 4, Position = UDim2.fromOffset(SIDE.Pad, CV.ButtonY), Size = UDim2.fromOffset(SIDE.W - 2 * SIDE.Pad, SIDE.ButtonH), ZIndex = 34, Parent = dv }))
	local dBuyIcon = dBuy.Instance:FindFirstChild("Icon", true) :: GuiObject?
	Effects.breathe(dBuy.Instance, { scale = 1.03, seconds = 0.9 })
	local function ownsDance(d): boolean
		return (State.data.Dances or {})[d.Id] == true or (d.Pack == true and State.owns("DancePack"))
	end
	local function buyDance(d)
		if ownsDance(d) then
			Toast.show(`{d.Name} is yours! Dance it from the Dances menu.`)
			return
		end
		if pending["Dance" .. d.Id] then return end
		local have = State.data.Coins or 0
		if have < (d.Coins or 0) then
			Toast.show(`You need {Format.commas((d.Coins or 0) - have)} more coins.`)
			return
		end
		pending["Dance" .. d.Id] = true
		local ok, why = State.action("BuyDance", d.Id)
		pending["Dance" .. d.Id] = nil
		Toast.show(if ok then `You got {d.Name}! Dance it from the Dances menu.` else (why or "Couldn't buy that. Try again."))
	end
	dBuy.onClick(function() if showing and showing.Coins then buyDance(showing) end end)
	-- your avatar doing the dance (owner, Oct 22 19:09: "make all of the character placeholders your character not the
	-- ai made one"): UI/DancePose.live, as on the dance cards, so it works for every dance (it used to need a published
	-- animation, which none has yet, so the drawn stand-in showed). The stand-in shows until your avatar is ready.
	-- (Stage, the old track's ViewportFrame, stays in the saved UI, unused and hidden.)
	local function dropDancer()
		local old = dBack:FindFirstChild("Dancer")
		if old then old:Destroy() end
	end
	local function showDancer(d)
		stage.Visible = false
		dropDancer()
		dStill.Visible = true
		local player = Players.LocalPlayer
		if not (player and player.Character) then return end
		local w = dBack.Size.X.Offset
		local ok, live = pcall(DancePose.live, dBack, d.Id, { Position = UDim2.fromOffset(4, 4), Size = UDim2.fromOffset(w - 8, DV.ArtH - 8), ZIndex = 33 }, function()
			if showing == d then dStill.Visible = false end
		end)
		if ok then live.setOn(true) else warn("[HuzzUI] Shop: the dance panel can't dance:", live) end
	end
	table.insert(sideRefresh, function()
		if not dv.Visible or not showing then return end
		local d = showing
		local owned = ownsDance(d)
		dBuy.setText(if owned then "YOURS!" else `BUY {Format.commas(d.Coins or 0)}`)
		if dBuyIcon then dBuyIcon.Visible = not owned end
		dBuy.setStyle(if owned then "Selected" elseif (State.data.Coins or 0) >= (d.Coins or 0) then "ShopGreen" else "Disabled")
		chunkyButton(dBuy)
	end)

	local function openCrateSide(crate)
		if not crateViews[crate.Id] then return end
		showing = crate
		sideTitle.Text = string.upper(crate.Name)
		Kit.fitLine(sideTitle, SIDE.W - 2 * SIDE.Pad - 56, 30, 18, true)
		for id, v in crateViews do v.Visible = id == crate.Id end
		dv.Visible = false
		dropDancer()
		slideIn()
	end
	local function openDanceSide(d)
		showing = d
		sideTitle.Text = string.upper(d.Name)
		Kit.fitLine(sideTitle, SIDE.W - 2 * SIDE.Pad - 56, 30, 18, true)
		for _, v in crateViews do v.Visible = false end
		dv.Visible = true
		Kit.setArt(dStill, "DanceStill" .. d.Id)
		showDancer(d) -- (a preview before you buy: your avatar dances it)
		dBlurb.Text = d.Blurb
		Kit.fitLine(dBlurb, SIDE.W - 2 * SIDE.Pad, 20, 12, true)
		dNote.Text = if d.Pack then "Also comes with the Dance Pack." elseif d.Id == "Untouchable" then "Also on the reward track at Level 3." else "Only sold here."
		slideIn()
	end

	-- a crate's card on the page: its name, his crate on the shared backdrop, the pity line and its price, OPEN (the
	-- panel: the odds and the buttons that pay). The whole card opens the panel too.
	local function crateCard(crate, lk): Frame
		local c = bigCard("Card" .. crate.Id, lk, crate.Name)
		cardsOf[crate.Id] = c
		cratePicture(backdrop(c, "Backdrop", 12, BIG.PicY, BIG.W - 24, BIG.PicH, 2), crate, 3, true)
		local top = crate.Pity and crate.Pity.Rarity or ""
		local pity, price = lines(c, "", if crate.CoinPrice then `{Format.commas(crate.CoinPrice)} COINS OR {crate.Price} AURA` else `{crate.Price} AURA PER OPEN`, CrateArt.color(top ~= "" and top or "Common"), { "Pity", "Price" })
		price.TextColor3 = if crate.CoinPrice then hex("FFE27A") else hex("CDE7FF")
		local tap = new("TextButton", { Name = "Tap", Text = "", AutoButtonColor = false, BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 3, Parent = c })
		tap.Activated:Connect(function() openCrateSide(crate) end)
		local open = chunkyButton(Kit.button({ Name = "Open", Text = "OPEN", TextSize = BIG.ButtonText, FontFace = SHOP_FONT, Style = if isHalloween(crate) then "ShopOrange" else "ShopGreen", Corner = 3, Position = UDim2.fromOffset(BIG.ButtonX, BIG.ButtonY), Size = UDim2.fromOffset(BIG.W - 2 * BIG.ButtonX, BIG.ButtonH), ZIndex = 4, Parent = c }))
		open.onClick(function() openCrateSide(crate) end)
		table.insert(refreshButtons, function()
			local left = CrateRoll.left(crate, (State.data.Pity or {})[crate.Id] or 0)
			pity.Text = if left == nil or top == "" then "" elseif left <= 1 then `{string.upper(top)} ON YOUR NEXT OPEN!` else `{string.upper(top)} IN {left} OPENS`
			Kit.fitLine(pity, BIG.W - 16, BIG.LineSize, 11, true)
			local keys = (State.data.CrateKeys or {})[crate.Id] or 0
			open.setText(if keys > 0 then `OPEN ({keys} KEY{if keys == 1 then "" else "S"})` else "OPEN")
			chunkyButton(open)
		end)
		crateView(crate)
		return c
	end

	-- HALLOWEEN -----------------------------------------------------------------------------------------------------------
	-- Owner, Oct 20 20:34: "keep the halloween knifes, and put them on the top of the shop ui". First the featured banner
	-- (his Halloween Crate: a real crate we sell, no timer, nothing scarce), then his three Halloween crates, then the
	-- best Halloween knives straight away for Aura or Robux.
	mark("Halloween")
	local featured = Crates.get("Halloween")
	if featured then
		local f = new("Frame", { Name = "Featured", Size = UDim2.fromOffset(CW, BANNER.H), BackgroundColor3 = WHITE, BackgroundTransparency = 0.04, BorderSizePixel = 0, Parent = body }, { Kit.corner(4), Kit.stroke(ORANGE, 3) })
		new("UIGradient", { Name = "Fill", Rotation = 90, Color = ColorSequence.new(hex("4C1F86"), hex("1E0B3A")), Parent = f })
		new("Frame", { Name = "Rim", Position = UDim2.fromOffset(3, 3), Size = UDim2.new(1, -6, 1, -6), BackgroundTransparency = 1, Parent = f }, { Kit.corner(3), Kit.stroke(hex("B07CFF"), 1.5, 0.4) })
		local t = chunky({ Name = "Title", Text = string.upper(featured.Name), TextSize = 46, TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.fromOffset(28, 26), Size = UDim2.fromOffset(360, 52), ZIndex = 3, Parent = f }, 3)
		Kit.fitLine(t, 360, 46, 26, true)
		new("UIGradient", { Name = "Colour", Rotation = 90, Color = ColorSequence.new(hex("FFE0A8"), ORANGE), Parent = t })
		local top = string.upper(featured.Pity and featured.Pity.Rarity or "")
		local pityLine = chunky({ Name = "Pity", Text = "", TextSize = 24, TextColor3 = CrateArt.color(featured.Pity and featured.Pity.Rarity or "Legendary"), TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.fromOffset(30, 88), Size = UDim2.fromOffset(350, 30), ZIndex = 3, Parent = f }, 2)
		local line = chunky({ Name = "Line", Text = `{#featured.Items} spooky knives. {Format.commas(featured.CoinPrice or 0)} coins or {featured.Price} Aura.`, TextSize = 18, TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.fromOffset(30, 128), Size = UDim2.fromOffset(350, 24), ZIndex = 3, Parent = f }, 1.5)
		Kit.fitLine(line, 350, 18, 12, true)
		chunky({ Name = "Hint", Text = "Tap to see every knife and its chance.", TextSize = 15, TextColor3 = CANDY, TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.fromOffset(30, 158), Size = UDim2.fromOffset(350, 22), ZIndex = 3, Parent = f }, 1.2)
		local bd = backdrop(f, "Backdrop", 392, 14, 216, BANNER.H - 28, 2)
		cratePicture(bd, featured, 3, true)
		Effects.motes(f, { colour = hex("FFA040"), shape = "dot", count = 8, area = Rect.new(402, 40, 598, BANNER.H - 30), z = 4, seed = 31 })
		local tap = new("TextButton", { Name = "Tap", Text = "", AutoButtonColor = false, BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 4, Parent = f })
		tap.Activated:Connect(function() openCrateSide(featured) end)
		local open = chunkyButton(Kit.button({ Name = "Open", Text = "OPEN", TextSize = 34, FontFace = SHOP_FONT, Style = "ShopOrange", Corner = 4, Position = UDim2.fromOffset(CW - 22 - 150, (BANNER.H - 88) // 2), Size = UDim2.fromOffset(150, 88), ZIndex = 5, Parent = f }))
		open.onClick(function() openCrateSide(featured) end)
		Effects.breathe(open.Instance, { scale = 1.05, seconds = 0.8 })
		Effects.shine(f, { every = 6, corner = 4, strength = 0.22, z = 6 })
		table.insert(refreshButtons, function()
			local left = CrateRoll.left(featured, (State.data.Pity or {})[featured.Id] or 0)
			pityLine.Text = if left == nil then "" elseif left <= 1 then `{top} ON YOUR NEXT OPEN!` else `{top} IN {left} OPENS!`
			Kit.fitLine(pityLine, 350, 24, 16, true)
		end)
		block(f, BANNER.H, 0, 0)
	end
	block(head(bySection.Halloween), HEAD.H)
	local hwCrateCards = {}
	for _, id in HALLOWEEN_ORDER do
		local crate = Crates.get(id)
		if crate then table.insert(hwCrateCards, crateCard(crate, SPOOKY)) end
	end
	grid(hwCrateCards, 3, BIG.W, BIG.H, BIG.Gap, 6)
	-- the best Halloween knives, straight away for Aura or Robux (ActionService "BuyHalloweenKnife", ShopService)
	local hwCards = {}
	local hwCols = math.min(4, math.max(1, #HalloweenShop.Knives))
	local hwW = if hwCols > 3 then (CW - (hwCols - 1) * 12) // hwCols else BIG.W
	local hwGap = if hwCols > 3 then 12 else BIG.Gap
	for _, entry in HalloweenShop.Knives do
		local item = CoinShop.get(entry.Key)
		local product = Products.get(entry.Robux)
		if not item or not product then continue end
		local tint = CrateArt.color(item.Rarity or "Legendary")
		local c = bigCard("Halloween" .. item.Key, SPOOKY, item.Name, hwW)
		backdrop(c, "Backdrop", 10, BIG.PicY, hwW - 20, BIG.PicH, 2, tint)
		if item.Art then
			local pic = picture(c, item.Art)
			pic.ZIndex = 3
			Effects.rock(pic, { degrees = 3, seconds = 1.8 })
		end
		lines(c, `{string.upper(item.Rarity or "")} KNIFE`, "HALLOWEEN, YOURS RIGHT AWAY", tint)
		local bx = 12 -- (the narrower card keeps both buttons inside)
		local robux = robuxButton(c, product, nil, { Name = "BuyRobux", Position = UDim2.fromOffset(bx, BIG.ButtonY), Size = UDim2.fromOffset(72, BIG.ButtonH), TextSize = 19 })
		local buyA = chunkyButton(Kit.button({ Name = "BuyAura", Text = Format.commas(entry.Aura or 0), Icon = "AuraStar", IconAfter = true, IconSize = 20, Gap = 3, TextSize = 21, FontFace = SHOP_FONT, Style = "ShopGreen", Corner = 3, Position = UDim2.fromOffset(bx + 78, BIG.ButtonY), Size = UDim2.fromOffset(hwW - 2 * bx - 78, BIG.ButtonH), ZIndex = 4, Parent = c }))
		local buyIcon = buyA.Instance:FindFirstChild("Icon", true) :: GuiObject?
		robux.onClick(function()
			if State.data.Cosmetics and State.data.Cosmetics[item.Key] then return end
			promptVia("PromptHalloween", product)
		end)
		buyA.onClick(function()
			if pending[item.Key] then return end
			if State.data.Cosmetics and State.data.Cosmetics[item.Key] then return end
			local have = State.data.Aura or 0
			if have < (entry.Aura or 0) then
				Toast.show(`You need {Format.commas((entry.Aura or 0) - have)} more Aura.`)
				return
			end
			pending[item.Key] = true
			local ok, why = State.action("BuyHalloweenKnife", item.Key)
			pending[item.Key] = nil
			Toast.show(if ok then `You got {item.Name}! You're holding it now.` else (why or "Couldn't buy that. Try again."))
		end)
		table.insert(refreshButtons, function()
			local owned = State.data.Cosmetics ~= nil and State.data.Cosmetics[item.Key] == true
			robux.Instance.Visible = not owned
			if buyIcon then buyIcon.Visible = not owned end
			buyA.setText(if owned then "OWNED" else Format.commas(entry.Aura or 0))
			buyA.setStyle(if not owned and (State.data.Aura or 0) >= (entry.Aura or 0) then "ShopGreen" else "Disabled")
			chunkyButton(buyA)
		end)
		table.insert(hwCards, c)
	end
	if #hwCards > 0 then
		block(subHead("HeadHalloweenKnives", "HALLOWEEN KNIVES", ORANGE), SUB.H, 0, 0)
		local note = chunky({ Name = "Note", Text = "A knife here costs 3x its crate's average Aura.", TextSize = 15, TextColor3 = C.NoteText, Size = UDim2.fromOffset(CW, 20), ZIndex = 2, Parent = body }, 1.2)
		block(note, 20, 0, 8)
		grid(hwCards, hwCols, hwW, BIG.H, hwGap, 6)
	end

	-- CRATES ------------------------------------------------------------------------------------------------------------
	mark("Crates")
	block(head(bySection.Crates), HEAD.H)
	mark("Crates@") -- (a jump lands here: its cards, the header just above)
	local crateCards = {}
	for _, crate in Crates.List do
		if not isHalloween(crate) then table.insert(crateCards, crateCard(crate, NAVY)) end
	end
	grid(crateCards, 3, BIG.W, BIG.H, BIG.Gap, 6)
	-- (a crate this page doesn't list still gets a panel, so its odds can always show)
	for _, crate in Crates.List do
		if not crateViews[crate.Id] then crateView(crate) end
	end

	-- a wide pass banner like the video's GAMEPASSES rows (its big picture, the title, what you get)
	local function passBanner(p)
		local accent = p.Accent or C.Action
		local f = card(p.Key, CW, BANNER.H, NAVY)
		local rim = f:FindFirstChildOfClass("UIStroke")
		if rim then rim.Color = INK end
		local artF = new("Frame", { Name = "Art", Position = UDim2.fromOffset(12, 12), Size = UDim2.fromOffset(220, BANNER.H - 24), BackgroundTransparency = 1, ZIndex = 2, Parent = f })
		Kit.attach(Kit.corner(3), Kit.art(p.Art, { Name = "Picture", Size = UDim2.fromScale(1, 1), ScaleType = Enum.ScaleType.Crop, ZIndex = 2, Parent = artF }))
		local t = chunky({ Name = "Title", Text = string.upper(p.Name), TextSize = 46, TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.fromOffset(252, 18), Size = UDim2.fromOffset(340, 54), ZIndex = 3, Parent = f }, 3)
		Kit.fitLine(t, 340, 46, 24, true)
		new("UIGradient", { Name = "Colour", Rotation = 90, Color = ColorSequence.new(WHITE, accent:Lerp(WHITE, 0.35)), Parent = t })
		for j, bf in p.Benefits or {} do
			local by = 82 + (j - 1) * 40
			Kit.icon(bf.Icon, { Name = "BenefitIcon" .. j, Position = UDim2.fromOffset(254, by), Size = UDim2.fromOffset(32, 32), ZIndex = 3, Parent = f })
			local bt = chunky({ Name = "Benefit" .. j, Text = bf.Text, TextSize = 20, TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.fromOffset(294, by), Size = UDim2.fromOffset(300, 32), ZIndex = 3, Parent = f }, 1.5)
			Kit.fitLine(bt, 300, 20, 12, true)
		end
		buyButton(f, p, { Position = UDim2.fromOffset(CW - 20 - 160, (BANNER.H - 92) // 2), Size = UDim2.fromOffset(160, 92), TextSize = 36, IconSize = 30 })
		block(f, BANNER.H, 0, BIG.Gap)
		return f
	end

	-- DANCES ------------------------------------------------------------------------------------------------------------
	-- Owner, Oct 20 20:34: "make a seperate section for dances, so that the dances you get by buying them individually,
	-- or in the dances section keep them there and make them be able to be bought there". The Dance Pack first, then
	-- every dance with a coin price (Config/Dances Coins). Tap one for its preview; BUY (ActionService "BuyDance").
	mark("Dances")
	block(head(bySection.Dances), HEAD.H)
	mark("Dances@") -- (a jump lands here: its cards, the header just above)
	local pack = Products.get("DancePack")
	if pack then passBanner(pack) end
	local danceList = {}
	for _, d in Dances.List do if d.Coins then table.insert(danceList, d) end end
	table.sort(danceList, function(a, b) return if a.Coins ~= b.Coins then a.Coins < b.Coins else a.Order < b.Order end)
	local danceCards = {}
	local dancers: { { card: GuiObject, live: any } } = {}
	for i, d in danceList do
		local c = card("Dance" .. d.Id, SMALL.W, SMALL.H, NAVY)
		local colour = Dances.Colors[d.Color] or WHITE
		local rim = c:FindFirstChildOfClass("UIStroke")
		if rim then rim.Color = colour:Lerp(Color3.new(0, 0, 0), 0.35) end
		local t = chunky({ Name = "Title", Text = d.Name, TextSize = SMALL.TitleSize, Position = UDim2.fromOffset(5, SMALL.TitleY), Size = UDim2.fromOffset(SMALL.W - 10, SMALL.TitleH), ZIndex = 3, Parent = c }, 2)
		Kit.fitLine(t, SMALL.W - 10, SMALL.TitleSize, 10, true)
		local glowF = new("Frame", { Name = "Glow", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(SMALL.W // 2, SMALL.PicY + SMALL.PicH // 2), Size = UDim2.fromOffset(112, 112), BackgroundColor3 = colour, BorderSizePixel = 0, ZIndex = 2, Parent = c }, { Kit.corner(56) })
		new("UIGradient", { Name = "Soft", Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0.5), NumberSequenceKeypoint.new(1, 1) }), Parent = glowF })
		-- your own avatar dancing it (owner, Oct 21: "make it your character dancing the dance": UI/DancePose.live);
		-- the white stand-in figure shows until it can (no character yet, or its moves are still on the way)
		local pic = Kit.art("DanceStill" .. d.Id, { Name = "Picture", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.fromOffset(SMALL.W // 2, SMALL.PicY + SMALL.PicH), Size = UDim2.fromOffset(SMALL.PicH, SMALL.PicH), ScaleType = Enum.ScaleType.Fit, ZIndex = 3, Parent = c })
		Effects.rock(pic, { degrees = 4, seconds = 0.45 + (i % 3) * 0.08 })
		local okL, live = pcall(DancePose.live, c, d.Id, { Position = UDim2.fromOffset(4, SMALL.PicY - 4), Size = UDim2.fromOffset(SMALL.W - 8, SMALL.PicH + 4), ZIndex = 3 }, function()
			pic.Visible = false
		end)
		if okL then table.insert(dancers, { card = c, live = live }) else warn("[HuzzUI] Shop: a dance card can't dance:", live) end
		local line = chunky({ Name = "Kind", Text = if d.Pack then "DANCE PACK DANCE" else "DANCE", TextSize = SMALL.LineSize, TextColor3 = colour:Lerp(WHITE, 0.3), Position = UDim2.fromOffset(5, SMALL.LineY), Size = UDim2.fromOffset(SMALL.W - 10, SMALL.LineH), ZIndex = 3, Parent = c }, 1.2)
		Kit.fitLine(line, SMALL.W - 10, SMALL.LineSize, 8, true)
		local tap = new("TextButton", { Name = "Tap", Text = "", AutoButtonColor = false, BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 3, Parent = c })
		tap.Activated:Connect(function() openDanceSide(d) end)
		local b = chunkyButton(Kit.button({ Name = "Buy", Text = "", Icon = "CurrencyCoin", IconSize = 24, Gap = 6, TextSize = 20, FontFace = SHOP_FONT, Style = "ShopGreen", Corner = 3, Position = UDim2.fromOffset(SMALL.ButtonX, SMALL.ButtonY), Size = UDim2.fromOffset(SMALL.W - 2 * SMALL.ButtonX, SMALL.ButtonH), ZIndex = 4, Parent = c }))
		local icon = b.Instance:FindFirstChild("Icon", true) :: GuiObject?
		b.onClick(function() buyDance(d) end)
		table.insert(refreshButtons, function()
			local owned = ownsDance(d)
			if icon then icon.Visible = not owned end
			b.setText(if owned then "OWNED" else Format.commas(d.Coins or 0))
			b.setStyle(if owned then "Selected" elseif (State.data.Coins or 0) >= (d.Coins or 0) then "ShopGreen" else "Disabled")
			chunkyButton(b)
		end)
		table.insert(danceCards, c)
		if not cardsOf[d.Id] then cardsOf[d.Id] = c end -- (Dances' PLAY on a locked dance jumps here)
	end
	grid(danceCards, 5, SMALL.W, SMALL.H, SMALL.Gap, 6)

	-- STYLE -------------------------------------------------------------------------------------------------------------
	-- Looks you buy with coins: trails and name colours (owner, Oct 21: "make this logical, and not everything mixed
	-- together"). The Shop only sells: what you own you wear from the Inventory (an owned card says OWNED and opens it
	-- there), and the looks you earn (titles, the girls' auras and trails) and your knives live there too. The Robux
	-- looks (outfits, poses) are gone (owner: "i think we can remove the outfit and stuff like that").
	mark("Style")
	block(head(bySection.Style), HEAD.H)
	mark("Style@") -- (a jump lands here: its cards, the header just above)
	local function itemCard(item, lk, sec: string): Frame
		local c = card(item.Key, SMALL.W, SMALL.H, lk)
		local tint = item.Rarity and rarityColor[item.Rarity]
		if tint then
			local rim = c:FindFirstChildOfClass("UIStroke")
			if rim then rim.Color = tint:Lerp(Color3.new(0, 0, 0), 0.35) end
		end
		local t = chunky({ Name = "Title", Text = item.Name, TextSize = SMALL.TitleSize, Position = UDim2.fromOffset(5, SMALL.TitleY), Size = UDim2.fromOffset(SMALL.W - 10, SMALL.TitleH), ZIndex = 3, Parent = c }, 2)
		Kit.fitLine(t, SMALL.W - 10, SMALL.TitleSize, 10, true)
		if LookPicture.is(item) then -- (your own avatar in the trail or aura: owner, Oct 26 10:47)
			LookPicture.draw(c, item, { Position = UDim2.fromOffset(4, SMALL.PicY), Size = UDim2.fromOffset(SMALL.W - 8, SMALL.PicH), ZIndex = 2 })
		elseif item.Art then
			Kit.art(item.Art :: string, { Name = "Picture", Position = UDim2.fromOffset(4, SMALL.PicY), Size = UDim2.fromOffset(SMALL.W - 8, SMALL.PicH), ScaleType = Enum.ScaleType.Fit, ZIndex = 2, Parent = c })
		else
			swatch(c, item, 96)
		end
		local slotText = CoinShop.SlotNames[item.Slot]
		if item.Rarity then slotText = string.upper(item.Rarity) .. " " .. slotText end
		local line = chunky({ Name = "Slot", Text = slotText, TextSize = SMALL.LineSize, TextColor3 = tint or hex("BFE8C8"), Position = UDim2.fromOffset(5, SMALL.LineY), Size = UDim2.fromOffset(SMALL.W - 10, SMALL.LineH), ZIndex = 3, Parent = c }, 1.2)
		Kit.fitLine(line, SMALL.W - 10, SMALL.LineSize, 8, true)
		local b = chunkyButton(Kit.button({ Name = "Buy", Text = "", Icon = "CurrencyCoin", IconSize = 24, Gap = 6, TextSize = 20, FontFace = SHOP_FONT, Style = "ShopGreen", Corner = 3, Position = UDim2.fromOffset(SMALL.ButtonX, SMALL.ButtonY), Size = UDim2.fromOffset(SMALL.W - 2 * SMALL.ButtonX, SMALL.ButtonH), ZIndex = 4, Parent = c }))
		local icon = b.Instance:FindFirstChild("Icon", true) :: GuiObject?
		local function owns() return State.data.Cosmetics ~= nil and State.data.Cosmetics[item.Key] == true end
		local function refresh()
			local owned = owns()
			if icon then icon.Visible = not owned end
			if owned then
				b.setText("OWNED")
				b.setStyle("Slate") -- (grey, never the buy green: it opens your Inventory)
			else
				b.setText(Format.commas(item.Price))
				b.setStyle(if (State.data.Coins or 0) >= item.Price then "ShopGreen" else "Disabled")
			end
			chunkyButton(b)
		end
		b.onClick(function()
			if owns() then
				ModalManager.open("Inventory", item.Slot) -- (wear it there)
				return
			end
			local ok, why = State.action("BuyWithCoins", item.Key)
			Toast.show(if ok then `{item.Name} is yours! Equip it from your Inventory.` else (why or "Couldn't buy that."))
		end)
		table.insert(refreshButtons, refresh)
		refresh()
		table.insert(filterable, { card = c, sec = sec, rarity = item.Rarity, slot = item.Slot, name = item.Name, owned = owns,
			base = function() return true end })
		return c
	end
	local sorted = {}
	for _, item in CoinShop.Items do table.insert(sorted, item) end
	table.sort(sorted, function(a, b) return a.Order < b.Order end)
	-- only what's sold for coins (never a knife, a prize or a look you earn)
	local styleItems = {}
	for _, item in sorted do
		if item.Slot ~= "Knife" and not item.Unlock and not item.Earn and not item.NotForSale and (item.Price or 0) > 0 then table.insert(styleItems, item) end
	end
	-- the filter row: type chips (only the kinds sold here; what you own lives in the Inventory, so no OWNED chips)
	do
		local row = new("Frame", { Name = "StyleFilters", Size = UDim2.fromOffset(CW, CHIP.H), BackgroundTransparency = 1, Parent = body })
		local typeDefs = { { Key = "All", Text = "ALL", Color = TYPE_COLOUR.All } }
		for _, t in TYPES do
			local sold = false
			for _, item in styleItems do if item.Slot == t.Key then sold = true; break end end
			if sold then table.insert(typeDefs, { Key = t.Key, Text = t.Text, Color = TYPE_COLOUR[t.Key] }) end
		end
		chipsOf.StyleType = chipRow(row, "StyleType", typeDefs, 0, 0, CW, function(k) pick("Style", "Type", k) end)
		refreshChips("Style")
		block(row, row.Size.Y.Offset, 0, 10)
	end
	-- one row group per kind, under its own small header (critic, Oct 21: a name colour sat in the trails' row)
	for _, t in TYPES do
		local looks = {}
		for _, item in styleItems do if item.Slot == t.Key then table.insert(looks, itemCard(item, NAVY, "Style")) end end
		if #looks > 0 then
			block(subHead("HeadStyle" .. t.Key, t.Text, TYPE_COLOUR[t.Key]), SUB.H, 0, 0, looks)
			grid(looks, 5, SMALL.W, SMALL.H, SMALL.Gap, 12)
		end
	end
	block(emptyLine("Style", "Nothing matches. Tap ALL to see every look."), 60, 0, 0)

	-- ABILITIES ---------------------------------------------------------------------------------------------------------
	-- Bought abilities (owner, Oct 20 15:13: "make the abilities be bought"), built by UI/AbilityCards: build(slot)
	-- fills a 795 px wide frame and returns its height (or sizes the frame). Until that module exists, or if it
	-- fails, the section and its jump button stay hidden (the page is placed without it).
	mark("Abilities")
	local abHead = head(bySection.Abilities)
	local abSlot = new("Frame", { Name = "AbilitiesSlot", Size = UDim2.fromOffset(CW, 0), BackgroundTransparency = 1, Parent = body })
	local abH = 0
	local abModule = UI:FindFirstChild("AbilityCards")
	if abModule and abModule:IsA("ModuleScript") then
		local ok, res = pcall(function() return (require(abModule) :: any).build(abSlot) end)
		if ok then
			abH = if type(res) == "number" then res else abSlot.Size.Y.Offset
			if abH <= 0 then
				for _, ch in abSlot:GetChildren() do
					if ch:IsA("GuiObject") then abH = math.max(abH, ch.Position.Y.Offset + ch.Size.Y.Offset) end
				end
			end
		else
			warn("[HuzzUI] Shop: ABILITIES couldn't be built:", res)
		end
	end
	local hasAbilities = abH > 0
	abHead.Visible, abSlot.Visible = hasAbilities, hasAbilities
	abSlot.Size = UDim2.fromOffset(CW, math.max(0, math.round(abH)))
	block(abHead, HEAD.H)
	mark("Abilities@")
	block(abSlot, abSlot.Size.Y.Offset, 0, 0)

	-- PASSES ------------------------------------------------------------------------------------------------------------
	mark("Passes")
	block(head(bySection.Passes), HEAD.H)
	mark("Passes@") -- (a jump lands here: its cards, the header just above)
	-- the Starter Pack first (Config/Products Gives), then the knife passes, then VIP
	for _, p in Products.Passes do
		if p.Gives then passBanner(p) end
	end
	local passCards = {}
	for i, p in Products.knifePasses() do
		local c = bigCard(p.Key, NAVY, p.Name)
		local pic = picture(c, p.Art)
		local a, b2 = blurbLines(p)
		lines(c, a, b2, (p.Card and p.Card.Name) or WHITE)
		priceRow(c, p)
		-- alive (owner, Oct 19: "better knife animations ... in the gamepass sections"): its element's colour glowing
		-- softly over the knife, a few of its petals / sparks / embers / ice bits floating up, a small lift under the mouse
		local el = KnifeLook.element(p.Knife)
		if el then
			local px, py, pw, ph = pic.Position.X.Offset, pic.Position.Y.Offset, pic.Size.X.Offset, pic.Size.Y.Offset
			local shape = if el.name == "Petals" or el.name == "Feathers" then "petal" elseif el.name == "Frost" then "diamond" else "dot"
			Effects.pulse(c, { colour = el.light, position = UDim2.fromOffset(px, py), size = UDim2.fromOffset(pw, ph), corner = 4, z = 2 })
			Effects.motes(c, { colour = el.emit[1].colours[1], shape = shape, count = 7,
				area = Rect.new(px + 20, py + 10, px + pw - 20, py + ph - 4), z = 3, seed = i })
		end
		table.insert(passCards, c)
	end
	if #passCards > 0 then grid(passCards, 3, BIG.W, BIG.H, BIG.Gap, BIG.Gap) end
	-- VIP: a wide banner like the video's GAMEPASSES rows (the Dance Pack's is in DANCES)
	for _, p in Products.Passes do
		if not p.Knife and not p.Gives and p.Key ~= "DancePack" then passBanner(p) end
	end

	-- AURA --------------------------------------------------------------------------------------------------------------
	mark("Aura")
	block(head(bySection.Aura), HEAD.H)
	mark("Aura@") -- (a jump lands here: its cards, the header just above)
	local auraCards = {}
	for i, p in Products.Aura do
		local c = bigCard(p.Key, NAVY, p.Name)
		auraStars(c, i)
		local a, b2 = blurbLines(p)
		lines(c, a, b2, hex("E6D2FF"))
		priceRow(c, p)
		table.insert(auraCards, c)
	end
	grid(auraCards, 3, BIG.W, BIG.H, BIG.Gap, 0)

	local GOLD = hex("FFC93C")
	-- COINS -------------------------------------------------------------------------------------------------------------
	mark("Coins")
	block(head(bySection.Coins), HEAD.H)
	mark("Coins@") -- (a jump lands here: its cards, the header just above)
	local coinCards = {}
	for i, p in Products.Coins do
		local c = bigCard(p.Key, NAVY, p.Name)
		local pic = picture(c, p.Art)
		-- gold (owner, Oct 21: "for the coins add some gold animations"): a warm gold glow breathing over the coins,
		-- gold sparkles rising, the coins rocking, and a slow shine across the card (one sweep every 5 s, staggered)
		local px, py, pw, ph = pic.Position.X.Offset, pic.Position.Y.Offset, pic.Size.X.Offset, pic.Size.Y.Offset
		Effects.pulse(c, { colour = GOLD, position = UDim2.fromOffset(px, py), size = UDim2.fromOffset(pw, ph), corner = 4, z = 2 })
		Effects.motes(c, { colour = hex("FFE27A"), shape = "diamond", count = 6 + i, area = Rect.new(px + 20, py + 10, px + pw - 20, py + ph - 4), z = 3, seed = 40 + i })
		Effects.rock(pic, { degrees = 3, seconds = 1.4 + i * 0.15 })
		Effects.shine(c, { every = 5, delay = i * 0.7, corner = 8, strength = 0.2, z = 8 })
		local a, b2 = blurbLines(p)
		lines(c, a, b2, hex("FFE27A"))
		priceRow(c, p)
		table.insert(coinCards, c)
	end
	grid(coinCards, 3, BIG.W, BIG.H, BIG.Gap, 0)

	layoutRef.fn = layout
	applyFilters()
	layout()

	-- The jump buttons: one per section, scrolling the page there; the one on screen wears a white rim.
	local jumps = {}
	local current: string? = nil
	-- Where the page is scrolled to, in the page's own units (layout's). Roblox measures CanvasPosition in screen
	-- pixels or in the page's units depending on the window's scale (owner, Oct 23 20:21: "fix ui buttons not bring
	-- you to the right places in the shop"): `ratio` (page units per CanvasPosition unit) is measured on screen from
	-- a card's real place the first time the page is scrolled, and every jump and check uses it.
	local ratio: number? = nil
	local function measureRatio(): number?
		local cp = body.CanvasPosition.Y
		if cp < 20 then return nil end
		local ok, r = pcall(function()
			local scale = body.AbsoluteSize.Y / BODY.H
			if scale <= 0 then return nil end
			for _, c in body:GetChildren() do
				local pop = c:FindFirstChildOfClass("UIScale") -- (a card popping in is drawn smaller than its place)
				if c:IsA("GuiObject") and c.Visible and c.Position.Y.Scale == 0 and not (pop and pop.Scale ~= 1) then
					local seen = (c.AbsolutePosition.Y - body.AbsolutePosition.Y) / scale -- (page units below the window's top)
					return (PAD + c.Position.Y.Offset - seen) / cp
				end
			end
			return nil
		end)
		if ok and r and r > 0.2 and r < 5 then return r end
		return nil
	end
	local function scrolledY(): number return body.CanvasPosition.Y * (ratio or 1) end
	local function highlight()
		local y = scrolledY() + 60
		local now = SECTIONS[1].Key
		for _, s in SECTIONS do
			if sectionY[s.Key] and sectionY[s.Key] <= y then now = s.Key end
		end
		if now == current then return end
		current = now
		for key, b in jumps do
			local rim = b.Instance:FindFirstChild("Rim")
			if rim and rim:IsA("UIStroke") then rim.Color, rim.Thickness = if key == now then WHITE else INK, if key == now then 3 else 2 end
		end
	end
	function scrollTo(key: string, animate: boolean?)
		key = ALIAS[key] or key
		-- (owner, Oct 21 17:17: "when you press crates, make it show the crates straight away, not the text, so the
		-- user doesnt have to scroll down": a jump lands on the section's cards, its big header scrolled just above)
		local y = sectionY[key .. "@"] or sectionY[key]
		if y == nil and cardsOf[key] then y = (cardsOf[key] :: GuiObject).Position.Y.Offset - 8 end -- (a crate: its card)
		if y == nil then return end
		local okW, win = pcall(function() return body.AbsoluteWindowSize end) -- (scaled px; unknown offline)
		local scale = 1
		local okA, abs = pcall(function() return body.AbsoluteSize end)
		if okA and abs and abs.Y > 0 then scale = abs.Y / BODY.H end
		local viewH = if okW and win and win.Y > 0 then win.Y / scale else BODY.H
		local maxY = math.max(0, body.CanvasSize.Y.Offset - math.floor(viewH))
		local want = math.clamp(y + PAD, 0, maxY) -- (the page's padding sits above its content)
		local function go(tween: boolean)
			local target = Vector2.new(0, math.floor(want / (ratio or 1) + 0.5))
			if tween then Motion.tween(body, "scroll", 0.35, { CanvasPosition = target }, Enum.EasingStyle.Quad) else body.CanvasPosition = target end
		end
		go(animate == true)
		task.defer(highlight)
		if animate then task.delay(0.4, highlight) end
		-- the first time, check where it really landed and put it right (the window's scale is only known on screen)
		if ratio == nil then
			task.delay(if animate then 0.45 else 0.05, function()
				local r = measureRatio()
				if r and math.abs(r - 1) > 0.02 then
					ratio = r
					go(false)
					highlight()
					dancersInViewRef.fn()
				elseif r then
					ratio = r
				end
			end)
		end
	end
	local slot = 0
	for i, s in SECTIONS do
		local shows = s.Key ~= "Abilities" or hasAbilities
		local b = chunkyButton(Kit.button({ Name = s.Key .. "Tab", Text = s.Text, Style = "Jump" .. s.Key, FontFace = SHOP_FONT, TextSize = JUMP.TextSize, Corner = 3, Size = UDim2.fromOffset(JUMP.W, JUMP.H), LayoutOrder = i, Parent = panel }))
		b.Instance.Visible = shows
		if shows then
			Kit.place(b.Instance, UDim2.fromOffset(JUMP.X, JUMP.Y + slot * JUMP.Pitch), UDim2.fromOffset(JUMP.W, JUMP.H))
			slot += 1
		end
		local label = b.Instance:FindFirstChild("Label", true)
		if label and label:IsA("TextLabel") then
			Kit.fitLine(label, JUMP.W - 12, JUMP.TextSize, 16)
			local o = label:FindFirstChild("Outline")
			if o and o:IsA("UIStroke") then o.Thickness = 2.5 end
		end
		b.onClick(function() scrollTo(s.Key, true) end)
		jumps[s.Key] = b
	end
	body:GetPropertyChangedSignal("CanvasPosition"):Connect(highlight)
	highlight()
	coins.plus.onClick(function() scrollTo("Coins", true) end)
	local setCoins = CoinFx.attach(coins)
	gems.plus.onClick(function() scrollTo("Aura", true) end)

	-- A reward you've just earned (Config/CoinShop Earn): say so once, and where to find it.
	local known: { [string]: boolean }? = nil
	State.changed(function(data)
		if data.Loaded then
			local first = known == nil
			known = known or {}
			local names = {}
			for _, item in CoinShop.Items do
				if item.Earn and data.Cosmetics[item.Key] and not (known :: any)[item.Key] then
					(known :: any)[item.Key] = true
					table.insert(names, item.Name)
				end
			end
			if not first and #names > 0 then
				local list = if #names == 1 then names[1] else table.concat(names, ", ", 1, #names - 1) .. " and " .. names[#names]
				Toast.show(`You unlocked {list}! Wear {if #names == 1 then "it" else "them"} from your Inventory.`)
			end
		end
		setCoins(State.shown("Coins"))
		gems.setAmount(Format.commas(data.Aura or 0))
		for _, f in refreshButtons do f() end
		-- (a prize you now own adds its card, a buy moves one past OWNED / NOT OWNED: place the page again)
		if applyFilters() then layout() end
	end)
	setCoins(State.shown("Coins"))
	gems.setAmount(Format.commas(State.data.Aura or 0))
	for _, f in refreshButtons do f() end

	-- a paid knife you turned out to own already became crate keys: the server says so here ("<n>|<line>")
	local me = Players.LocalPlayer
	if me then
		me:GetAttributeChangedSignal("HuzzShopNotice"):Connect(function()
			local line = string.match(tostring(me:GetAttribute("HuzzShopNotice") or ""), "^%d+|(.+)$")
			if line then Toast.show(line) end
		end)
	end
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, id) if player == Players.LocalPlayer then onPromptClosed(id, true) end end)
	MarketplaceService.PromptProductPurchaseFinished:Connect(function(userId, id) if Players.LocalPlayer and userId == Players.LocalPlayer.UserId then onPromptClosed(id, false) end end)

	-- Live Robux prices for items that are set up (the configured price shows until then).
	task.spawn(function()
		for _, list in { Products.Passes, Products.Coins, Products.Aura, Products.Halloween, Products.Crates } do
			for _, p in list do
				if Products.status(p) == "Ready" then
					local ok, info = pcall(MarketplaceService.GetProductInfo, MarketplaceService, p.Id, (p.Kind == "Pass" or p.GamePass) and Enum.InfoType.GamePass or Enum.InfoType.Product)
					if ok and info and type(info.PriceInRobux) == "number" then
						livePrice[p.Key] = info.PriceInRobux
						if priceLabels[p.Key] then priceLabels[p.Key].Text = Format.commas(info.PriceInRobux) end
					end
				end
			end
		end
		for _, f in refreshButtons do f() end
	end)

	-- The cards in view pop in one after another (Motion.stagger's rhythm; Reduced Motion: they just show).
	local function popIn()
		if Motion.reduced then return end
		local top = scrolledY() - 40
		local k = 0
		for _, e in popList do
			local c = e.card
			if c.Visible and c.Parent == body and c.Position.Y.Offset + c.Size.Y.Offset > top and c.Position.Y.Offset < top + BODY.H + 40 then
				e.scale.Scale = 0.8
				task.delay(k * Theme.Motion.Stagger, function()
					if e.scale.Parent then Motion.tween(e.scale, "press", 0.32, { Scale = 1 }, Enum.EasingStyle.Back) end
				end)
				k += 1
			end
		end
	end
	-- the dance cards in view dance while the Shop is open (UI/DancePose.live: only a few cards at a time)
	local shopOpen = false
	local function dancersInView()
		local top = scrolledY()
		for _, e in dancers do
			local c = e.card
			local y = c.Position.Y.Offset
			e.live.setOn(shopOpen and c.Visible and y + c.Size.Y.Offset > top and y < top + BODY.H)
		end
	end
	dancersInViewRef.fn = dancersInView
	body:GetPropertyChangedSignal("CanvasPosition"):Connect(dancersInView)
	ModalManager.register("Shop", {
		window = window,
		-- open at a section ("Halloween", "Crates", "Dances", "Style", "Abilities", "Passes", "Aura", "Coins") or a
		-- crate ("Witch", "Beast": its card, and its panel slides in)
		onOpen = function(where)
			closeSide(true)
			if type(where) == "string" then scrollTo(where, false) end
			popIn()
			shopOpen = true
			dancersInView()
			local crate = type(where) == "string" and Crates.get(where)
			if crate then task.delay(if Motion.reduced then 0 else 0.15, function() openCrateSide(crate) end) end
		end,
		onClose = function()
			closeSide(true)
			shopOpen = false
			dancersInView()
		end,
		firstSelect = function() return jumps.Halloween and jumps.Halloween.Instance end,
	})
	return window
end

return Shop
