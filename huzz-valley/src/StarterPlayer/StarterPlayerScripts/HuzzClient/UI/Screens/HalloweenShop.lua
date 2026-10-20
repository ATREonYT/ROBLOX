-- The Halloween shop (owner, Oct 19 17:41: "make a halloween shop when you press on one of the two crates. and then you
-- can buy the crates, or the best knifes for either aura or robux"). Opened by his two lobby stands, WITCH'S BREW and
-- SWEETS & TREATS (Config/LobbyProps Opens; design/owner-oct19/1840-halloween-crates.png). The Shop's window (701 x
-- 320, the same header, tabs and cards) in Halloween colours: a pumpkin-orange header over a dark purple body.
--   CRATES  the two stands' crates (Config/HalloweenShop.Crates): his own crate picture (owner, Oct 20 14:07: "make the
--           halloween shop have the images of the crates from the ones i sent you before"; his card cut to the crate,
--           UI/CrateArt.hisPicture, his 3D crate when it can't be drawn), the top prize's pity counter,
--           OPEN for its Aura price (Screens/CrateOpen plays it; a Robux key, once bought, is used first: USE KEY),
--           KEY for Robux, and every item's exact chance beside it.
--   KNIVES  the Legendary and Mythic of each set as their pictures: buy one for Aura (ActionService
--           "BuyHalloweenKnife": the server checks the price and takes it) or Robux. OWNED once it's yours.
-- Robux buttons show their price; while a product's Id is 0 (Config/Products.Halloween) tapping one only says it's
-- coming soon, never a purchase prompt. With an ID the server opens the prompt (ShopService.promptHalloween: never
-- for a knife you own). Robux purchases are granted only by the server (ShopService, Config/HalloweenShop.grant);
-- when a paid knife you already had became crate keys, the server's line (Player attribute HuzzShopNotice) shows here.
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Products = require(Shared.Config.Products)
local CoinShop = require(Shared.Config.CoinShop)
local Crates = require(Shared.Config.Crates)
local HalloweenShop = require(Shared.Config.HalloweenShop)
local CrateRoll = require(Shared.CrateRoll)
local Format = require(Shared.Format)
local UI = script.Parent.Parent
local CrateArt = require(UI.CrateArt)
local Theme = require(UI.Theme)
local Kit = require(UI.Kit)
local State = require(UI.State)
local Toast = require(UI.Toast)
local ModalManager = require(UI.ModalManager)
local Effects = require(UI.Effects)

local new = Kit.new
local C, F = Theme.Colors, Theme.Fonts

local HalloweenShopScreen = {}

local W, H = 701, 320 -- the Shop's size (every main window shares it)
local BODY = { X = 18, Y = 94, W = 668, H = 216 } -- the Shop's body box under its tab row
-- Halloween colours: pumpkin orange header (light to deep, like the kit's purple gloss), a dark plum body
local HEADER = { { 0, Color3.fromHex("FFAA4C") }, { 0.45, Color3.fromHex("F57A1F") }, { 1, Color3.fromHex("D2560E") } }
local HEADER_TOP = Color3.fromHex("FFD6A0")
local PANEL = Color3.fromHex("2A1646")
local CARD = { Top = Color3.fromHex("2A1240"), Bottom = Color3.fromHex("170A2A"), Rim = Color3.fromHex("6A3A9C") }
-- his crate pictures (Kit.art CrateCard*, his mockup's cards), cut to the crate above his BUY: { x, y, w, h, W, H } px
local PICTURE = { W = 103, H = 80,
	Beast = { Art = "CrateCardBeast", Crop = { 30, 25, 655, 510, 715, 702 } },
	Dojo = { Art = "CrateCardDojo", Crop = { 30, 25, 657, 510, 717, 702 } },
	Storm = { Art = "CrateCardStorm", Crop = { 30, 25, 642, 510, 702, 702 } },
}
local CRATE = { W = 132, OddsX = 138, RowW = 192, RowH = 34, RowGap = 2, SectionW = 330, Gap = 8 }
local KNIFE = { W = 161, Gap = 8, ArtH = 110 }

local function outlined(props: { [string]: any }, thickness: number?): TextLabel
	props.TextWrapped = false
	local l = Kit.text(props)
	new("UIStroke", { Name = "Outline", Color = C.TitleStroke, Thickness = thickness or 1.5, LineJoinMode = Enum.LineJoinMode.Round, Parent = l })
	return l
end

local function card(name: string, parent: Instance, pos: UDim2, size: UDim2, rim: Color3): Frame
	local c = new("Frame", { Name = name, Position = pos, Size = size, BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, Parent = parent }, { Kit.corner(6), Kit.stroke(rim, 2) })
	new("UIGradient", { Name = "Fill", Rotation = 90, Color = ColorSequence.new(CARD.Top, CARD.Bottom), Parent = c })
	return c
end

local priceLabels: { [string]: TextLabel } = {} -- [product key] = its Robux price (Roblox's live price once it has an ID)

-- A Robux price button: Roblox's Robux mark and the price, with an optional word before them ("KEY").
local function robuxButton(parent: Instance, p, word: string?, props: { [string]: any })
	local b = Kit.button({ Name = props.Name or "Robux", Text = word or "", Style = "Action", FontFace = F.Button, TextSize = props.TextSize or 15, Gap = 4, Corner = 5, Position = props.Position, Size = props.Size, ZIndex = 4, Parent = parent })
	local content = b.Instance:FindFirstChild("Content")
	local size = props.TextSize or 15
	Kit.text({ Name = "RobuxBadge", Text = Format.RobuxMark, FontFace = F.Number, TextSize = math.floor(size * 1.4), TextColor3 = C.RobuxBadge, TextXAlignment = Enum.TextXAlignment.Center, AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.new(0, 0, 1, 0), TextWrapped = false, LayoutOrder = 3, ZIndex = 4, Parent = content })
	priceLabels[p.Key] = Kit.text({ Name = "Price", Text = Format.commas(p.Price), FontFace = F.Number, TextSize = size + 1, TextXAlignment = Enum.TextXAlignment.Center, AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.new(0, 0, 1, 0), TextWrapped = false, LayoutOrder = 4, ZIndex = 4, Parent = content })
	return b
end

function HalloweenShopScreen.build(parent: Instance)
	local window = Kit.window({ Name = "HalloweenShop", Flat = true, Title = "HALLOWEEN SHOP", Icon = "ShopCart", Width = W, Height = H, TitleX = 63, TitleOffsetY = 3, TitleWidth = 286, StudsTo = 486, PanelColor = PANEL, Parent = parent, OnClose = function() ModalManager.close() end })
	local panel, header = window.Panel, window.Header
	-- the Halloween header: the kit's gloss in pumpkin orange
	local gloss = header:FindFirstChild("Gloss")
	if gloss and gloss:IsA("UIGradient") then
		local g = {}
		for _, k in HEADER do table.insert(g, ColorSequenceKeypoint.new(k[1], k[2])) end
		gloss.Color = ColorSequence.new(g)
	end
	local topLine = header:FindFirstChild("TopLine")
	if topLine and topLine:IsA("Frame") then topLine.BackgroundColor3 = HEADER_TOP end
	local aura = Kit.pill({ Name = "Aura", Icon = "AuraStar", Position = UDim2.fromOffset(493, 6), Width = 108, Parent = header })
	local auraIcon = aura.Instance:FindFirstChild("Icon")
	if auraIcon and auraIcon:IsA("ImageLabel") then auraIcon.ImageColor3 = Color3.new(1, 1, 1) end
	Kit.studs(header, 612, 650, 16)
	aura.plus.onClick(function() ModalManager.open("Shop", "Aura") end) -- (Shop > AURA, Oct 20 14:07)

	local pages = {
		Crates = new("Frame", { Name = "Crates", Position = UDim2.fromOffset(BODY.X, BODY.Y), Size = UDim2.fromOffset(BODY.W, BODY.H), BackgroundTransparency = 1, Parent = panel }),
		Knives = new("Frame", { Name = "Knives", Position = UDim2.fromOffset(BODY.X, BODY.Y), Size = UDim2.fromOffset(BODY.W, BODY.H), BackgroundTransparency = 1, Visible = false, Parent = panel }),
	}
	local refreshers: { () -> () } = {}
	local pending: { [string]: boolean } = {}

	-- Robux: only a product with its ID opens Roblox's prompt; Id 0 = "coming soon", never a purchase
	local function buyRobux(p)
		if pending[p.Key] then return end
		local status = Products.status(p)
		if status ~= "Ready" then
			Toast.show(`{p.Name} for Robux is coming soon.`)
			if status == "NoId" then warn(`[Shop] {p.Key} has no Developer Product ID in Shared/Config/Products.lua`) end
			return
		end
		pending[p.Key] = true
		-- the server opens Roblox's prompt, after checking it has its ID and the knife isn't yours already
		local ok, why = State.action("PromptHalloween", p.Key)
		if not ok then
			pending[p.Key] = nil
			Toast.show(why or "The purchase couldn't open. Try again.")
			return
		end
		task.delay(90, function() pending[p.Key] = nil end) -- (never stuck if Roblox doesn't report back)
	end
	-- a paid knife you turned out to own already became crate keys: the server says so here ("<n>|<line>")
	local me = Players.LocalPlayer
	if me then
		me:GetAttributeChangedSignal("HuzzShopNotice"):Connect(function()
			local line = string.match(tostring(me:GetAttribute("HuzzShopNotice") or ""), "^%d+|(.+)$")
			if line then Toast.show(line) end
		end)
	end
	MarketplaceService.PromptProductPurchaseFinished:Connect(function(userId, id)
		if Players.LocalPlayer and userId ~= Players.LocalPlayer.UserId then return end
		for _, p in Products.Halloween do
			if p.Id == id then pending[p.Key] = nil end
		end
	end)

	-- CRATES: one section per stand's crate, the card on the left and its odds beside it
	for i, entry in HalloweenShop.Crates do
		local crate = Crates.get(entry.Crate)
		local product = Products.get(entry.Robux)
		if not crate or not product then continue end
		local x = (i - 1) * (CRATE.SectionW + CRATE.Gap)
		local section = new("Frame", { Name = "Section" .. crate.Id, Position = UDim2.fromOffset(x, 0), Size = UDim2.fromOffset(CRATE.SectionW, BODY.H), BackgroundTransparency = 1, Parent = pages.Crates })
		local tint = Color3.fromHex((crate.Colors or { "B45CFF" })[1])
		local c = card(crate.Id, section, UDim2.fromOffset(0, 0), UDim2.fromOffset(CRATE.W, BODY.H), tint)
		-- his crate picture (the crate only, without his BUY: KEY and OPEN are below), never recoloured
		local look = Crates.get(entry.Picture or "")
		local pic = look and PICTURE[look.Id]
		if pic then
			CrateArt.hisPicture(c, pic.Art, { Name = "HisPicture", Position = UDim2.fromOffset((CRATE.W - PICTURE.W) // 2, 24), Size = UDim2.fromOffset(PICTURE.W, PICTURE.H), ZIndex = 2, Model = look, Crop = pic.Crop })
		else
			CrateArt.paint(CrateArt.crate(c, 76, UDim2.fromOffset(CRATE.W // 2, 66), "CratePicture"), crate)
		end
		-- (the stand's own words: WITCH'S BREW, SWEETS & TREATS)
		local title = outlined({ Name = "Name", Text = (string.gsub(string.upper(crate.Name), " CRATE$", "")), FontFace = F.Heading, TextSize = 15, TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.fromOffset(4, 6), Size = UDim2.new(1, -8, 0, 18), ZIndex = 3, Parent = c })
		Kit.fitLine(title, CRATE.W - 8, 15, 10, true)
		local top = crate.Pity and crate.Pity.Rarity or ""
		local pityLabel = outlined({ Name = "PityLabel", Text = `GUARANTEED {string.upper(top)}`, FontFace = F.Heading, TextSize = 10, TextColor3 = CrateArt.color(top), TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.fromOffset(6, 106), Size = UDim2.new(1, -12, 0, 12), ZIndex = 3, Parent = c }, 1.2)
		Kit.fitLine(pityLabel, CRATE.W - 12, 10, 8, true)
		local pityText = outlined({ Name = "Pity", Text = "", FontFace = F.Name, TextSize = 12, TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.fromOffset(0, 118), Size = UDim2.new(1, 0, 0, 15), ZIndex = 3, Parent = c }, 1.2)
		local track = new("Frame", { Name = "PityTrack", Position = UDim2.fromOffset(12, 136), Size = UDim2.fromOffset(CRATE.W - 24, 6), BackgroundColor3 = C.TrackRim, BorderSizePixel = 0, ZIndex = 3, Parent = c }, { Kit.corner(3) })
		local fill = new("Frame", { Name = "Fill", Size = UDim2.fromScale(0, 1), BackgroundColor3 = CrateArt.color(top), BorderSizePixel = 0, ZIndex = 3, Parent = track }, { Kit.corner(3) })
		local open = Kit.button({ Name = "Open", Text = `OPEN {crate.Price}`, Icon = "AuraStar", IconAfter = true, IconSize = 20, Gap = 5, TextSize = 16, FontFace = F.Heading, Style = "Selected", Corner = 5, Position = UDim2.fromOffset(7, 148), Size = UDim2.fromOffset(CRATE.W - 14, 30), ZIndex = 4, Parent = c })
		local openIcon = open.Instance:FindFirstChild("Icon", true) :: GuiObject?
		local key = robuxButton(c, product, "KEY", { Name = "BuyKey", Position = UDim2.fromOffset(7, 182), Size = UDim2.fromOffset(CRATE.W - 14, 28), TextSize = 14 })
		key.onClick(function() buyRobux(product) end)
		open.onClick(function()
			local keys = ((State.data.CrateKeys or {})[crate.Id]) or 0
			local have = State.data.Aura or 0
			if keys <= 0 and have < crate.Price then
				Toast.show(`You need {crate.Price - have} more Aura. Collect stars on the field!`)
				return
			end
			ModalManager.open("CrateOpen", crate.Id)
		end)
		table.insert(refreshers, function()
			local pity = (State.data.Pity or {})[crate.Id] or 0
			local left = CrateRoll.left(crate, pity)
			pityText.Text = if left == nil then "" elseif left <= 1 then "on your next open!" else `in {left} opens`
			fill.Size = UDim2.fromScale(if crate.Pity then math.clamp(pity / crate.Pity.After, 0, 1) else 0, 1)
			local keys = ((State.data.CrateKeys or {})[crate.Id]) or 0
			open.setText(if keys > 0 then `USE KEY ({keys})` else `OPEN {crate.Price}`)
			if openIcon then openIcon.Visible = keys <= 0 end
			open.setStyle(if keys > 0 or (State.data.Aura or 0) >= crate.Price then "Selected" else "Disabled")
		end)
		-- every item and its exact chance, rarest last
		for n, o in CrateRoll.odds(crate) do
			local it = o.item
			local row = new("Frame", { Name = "Odds" .. n, Position = UDim2.fromOffset(CRATE.OddsX, (n - 1) * (CRATE.RowH + CRATE.RowGap)), Size = UDim2.fromOffset(CRATE.RowW, CRATE.RowH), BackgroundColor3 = C.Row, BackgroundTransparency = Theme.Transparency.Row, BorderSizePixel = 0, Parent = section }, { Kit.corner(5) })
			new("Frame", { Name = "RarityBar", Size = UDim2.new(0, 4, 1, 0), BackgroundColor3 = CrateArt.color(it.Rarity), BorderSizePixel = 0, ZIndex = 2, Parent = row }, { Kit.corner(2) })
			CrateArt.picture(row, it, 36, 28, 4, UDim2.fromOffset(8, 3), 2)
			local nm = Kit.name({ Name = "Name", Text = it.Name, FontFace = F.Name, TextSize = 13, Position = UDim2.fromOffset(49, 2), Size = UDim2.fromOffset(98, 16), ZIndex = 3, Parent = row })
			Kit.fitLine(nm, 96, 13, 8, true)
			outlined({ Name = "Rarity", Text = string.upper(it.Rarity), FontFace = F.Heading, TextSize = 9, TextColor3 = CrateArt.color(it.Rarity), Position = UDim2.fromOffset(49, 18), Size = UDim2.fromOffset(98, 12), ZIndex = 3, Parent = row }, 1)
			Kit.text({ Name = "Chance", Text = string.format("%g%%", math.floor(o.chance * 10 + 0.5) / 10), FontFace = F.Number, TextSize = 13, TextXAlignment = Enum.TextXAlignment.Right, TextWrapped = false, Position = UDim2.fromOffset(148, 0), Size = UDim2.fromOffset(CRATE.RowW - 154, CRATE.RowH), ZIndex = 3, Parent = row })
		end
	end

	-- KNIVES: the best Halloween knives as his pictures, each for Aura or Robux
	for i, entry in HalloweenShop.Knives do
		local item = CoinShop.get(entry.Key)
		local product = Products.get(entry.Robux)
		if not item or not product then continue end
		local tint = CrateArt.color(item.Rarity or "Legendary")
		local c = card(item.Key, pages.Knives, UDim2.fromOffset((i - 1) * (KNIFE.W + KNIFE.Gap), 0), UDim2.fromOffset(KNIFE.W, BODY.H), tint)
		if item.Art then
			Kit.attach(Kit.corner(5), Kit.art(item.Art, { Name = "Picture", Position = UDim2.fromOffset(2, 2), Size = UDim2.fromOffset(KNIFE.W - 4, KNIFE.ArtH), ZIndex = 2, Parent = c }))
		end
		Effects.shine(c, { every = 5, delay = (i - 1) * 0.9, corner = 6, strength = 0.25, z = 9 })
		local nm = outlined({ Name = "Name", Text = item.Name, FontFace = F.Heading, TextSize = 15, TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.fromOffset(4, KNIFE.ArtH + 4), Size = UDim2.fromOffset(KNIFE.W - 8, 18), ZIndex = 3, Parent = c })
		Kit.fitLine(nm, KNIFE.W - 8, 15, 10, true)
		outlined({ Name = "Rarity", Text = `{string.upper(item.Rarity or "")} KNIFE`, FontFace = F.Heading, TextSize = 11, TextColor3 = tint, TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.fromOffset(4, KNIFE.ArtH + 22), Size = UDim2.fromOffset(KNIFE.W - 8, 13), ZIndex = 3, Parent = c }, 1.2)
		local buy = Kit.button({ Name = "BuyAura", Text = Format.commas(entry.Aura or 0), Icon = "AuraStar", IconAfter = true, IconSize = 20, Gap = 5, TextSize = 17, FontFace = F.Number, Style = "Selected", Corner = 5, Position = UDim2.fromOffset(7, 150), Size = UDim2.fromOffset(KNIFE.W - 14, 30), ZIndex = 4, Parent = c })
		local buyIcon = buy.Instance:FindFirstChild("Icon", true) :: GuiObject?
		local robux = robuxButton(c, product, nil, { Name = "BuyRobux", Position = UDim2.fromOffset(7, 184), Size = UDim2.fromOffset(KNIFE.W - 14, 26), TextSize = 14 })
		robux.onClick(function()
			if State.data.Cosmetics and State.data.Cosmetics[item.Key] then return end
			buyRobux(product)
		end)
		buy.onClick(function()
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
		table.insert(refreshers, function()
			local owned = State.data.Cosmetics ~= nil and State.data.Cosmetics[item.Key] == true
			robux.Instance.Visible = not owned
			if buyIcon then buyIcon.Visible = not owned end
			buy.setText(if owned then "OWNED" else Format.commas(entry.Aura or 0))
			buy.setFont(if owned then F.Button else F.Number)
			buy.setStyle(if not owned and (State.data.Aura or 0) >= (entry.Aura or 0) then "Selected" else "Disabled")
		end)
	end
	local note = outlined({ Name = "Note", Text = "Direct knives cost 3x their crate's average. Every chance is shown.", FontFace = F.Body, TextSize = 12, TextColor3 = C.NoteText, TextXAlignment = Enum.TextXAlignment.Right, Position = UDim2.fromOffset(290, 58), Size = UDim2.fromOffset(394, 18), ZIndex = 3, Parent = panel }, 1)

	-- Roblox's live Robux price for products that have their ID (the configured price shows until then)
	task.spawn(function()
		for _, p in Products.Halloween do
			if Products.status(p) == "Ready" and priceLabels[p.Key] then
				local okP, info = pcall(MarketplaceService.GetProductInfo, MarketplaceService, p.Id, Enum.InfoType.Product)
				if okP and info and type(info.PriceInRobux) == "number" then priceLabels[p.Key].Text = Format.commas(info.PriceInRobux) end
			end
		end
	end)

	local function refresh()
		aura.setAmount(Format.commas(State.data.Aura or 0))
		for _, f in refreshers do f() end
	end
	local tabs
	local function show(key: string)
		for k, page in pages do page.Visible = k == key end
		note.Text = if key == "Crates" then "Every chance is shown. A crate key opens it once." else "A knife here costs 3x its crate's average Aura."
	end
	tabs = Kit.tabs(panel, {
		{ Key = "Crates", Text = "CRATES", X = 16, Width = 131 },
		{ Key = "Knives", Text = "KNIVES", X = 151, Width = 131 },
	}, 52, 30, show)
	tabs.select("Crates")
	show("Crates")

	local isOpen = false
	ModalManager.register("HalloweenShop", {
		window = window,
		onOpen = function(tab)
			isOpen = true
			local k = if tab == "Knives" then "Knives" else (if tab == "Crates" then "Crates" else tabs.selected() or "Crates")
			tabs.select(k)
			show(k)
			refresh()
		end,
		onClose = function() isOpen = false end,
		firstSelect = function() return tabs.buttons.Crates.Instance end,
	})
	State.changed(function() if isOpen or window.Holder.Visible then refresh() end end)
	refresh()
	return window.Holder
end

return HalloweenShopScreen
