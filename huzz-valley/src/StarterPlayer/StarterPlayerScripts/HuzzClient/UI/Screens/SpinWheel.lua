-- Spin the Wheel (owner's reference: design/spin-wheel-reference.webp; "make it with our own wheel ... and make the
-- buttons in the same spots"). Opens from the wheel in the lobby (server: SpinService, SpinOpen remote) or the HUD's
-- SPIN button. Laid out at 1280 x 720 like the reference screen: the big wheel in the middle with the pointer at the
-- top, the free spin clock over it, Spin x5 / x10 on the left, the three spin packs on the right, and along the
-- bottom Spin! (N), the pity counter (where the reference had a "Daily Discount": we never fake discounts) and Close.
-- The (?) Odds button lists every slice with its exact chance.
-- The wheel is ours, built from real UI parts: 8 tinted slices (assets/art/spin-wedge.png), dividers, pegs, hub, pin.
-- The server picks every result (Shared/SpinRules.spin); the wheel only turns to the slice it was told: a fast start
-- and a long smooth ease-out (~4.6 s), the pin flicking with a tick at every slice edge, one glow on the prize, then
-- the reward card. No CanvasGroup (they lag), at most one flash per spin.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local MarketplaceService = game:GetService("MarketplaceService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Wheel = require(Shared.Config.SpinWheel)
local Products = require(Shared.Config.Products)
local CoinShop = require(Shared.Config.CoinShop)
local SpinRules = require(Shared.SpinRules)
local CrateRoll = require(Shared.CrateRoll)
local Format = require(Shared.Format)
local Net = require(Shared.Net)
local UI = script.Parent.Parent
local Theme = require(UI.Theme)
local Kit = require(UI.Kit)
local Effects = require(UI.Effects)
local Motion = require(UI.Motion)
local State = require(UI.State)
local Toast = require(UI.Toast)
local ModalManager = require(UI.ModalManager)
local Sfx = require(UI.Parent.Gameplay.Sfx)

local C = Theme.Colors
local F = Theme.Fonts
local new = Kit.new
local hex = Color3.fromHex

local SpinWheel = {}

local W, H = 1280, 720 -- the whole screen, reference px (fitted like a window)
local D = 478 -- the wheel's diameter
local R = D / 2
local CX, CY = 640, 344 -- the wheel's centre
local SPIN_TIME = 4.6
local TURNS = 5
local INK = C.TitleStroke -- the dark outline on every big word

-- Bright button looks for this screen (the reference's green, purple and grey), with the kit's bevel and shade.
local function look(fill: string, top: string, rim: string)
	local f = hex(fill)
	return { Idle = f, Hover = f:Lerp(Color3.new(1, 1, 1), 0.1), Pressed = f:Lerp(Color3.new(0, 0, 0), 0.1), Text = C.Text, Top = hex(top), Rim = hex(rim) }
end
Kit.Styles.SpinGreen = look("3CCF5C", "A2F7AE", "0E3F1A")
Kit.Styles.SpinPurple = look("A63DF5", "D7A3FF", "3B0A6A")
Kit.Styles.SpinGrey = look("8C95AA", "C9CEDB", "262C3E")
Kit.Styles.SpinBlue = look("2F7BFF", "93BEFF", "0A1F5A")

-- White words with a thick dark outline (the reference's chunky button text, in our Gotham).
local function words(props: { [string]: any }, thickness: number?): TextLabel
	props.BackgroundTransparency = 1
	props.TextColor3 = props.TextColor3 or C.Text
	props.FontFace = props.FontFace or F.Heading
	props.TextXAlignment = props.TextXAlignment or Enum.TextXAlignment.Center
	props.TextWrapped = false
	local l = new("TextLabel", props)
	new("UIStroke", { Name = "Outline", Color = INK, Thickness = thickness or 2, LineJoinMode = Enum.LineJoinMode.Round, Parent = l })
	return l
end

-- A screen button: big outlined words on one of the looks above.
local function button(parent: Instance, name: string, text: string, style: string, x: number, y: number, w: number, h: number, size: number?)
	local b = Kit.button({ Name = name, Text = text, Style = style, FontFace = F.Heading, TextSize = size or 26, Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(w, h), Corner = 8, RimThickness = 2.5, Parent = parent })
	local outline = b.Instance:FindFirstChild("Outline", true) :: UIStroke?
	if outline and not Kit.reused(outline) then
		outline.Color, outline.Thickness, outline.Transparency = INK, 3, 0
	end
	return b
end

-- Makes a part (and its stud texture) round. Set every time, even on a saved part: the place build's tool (Lune)
-- can't save a UICorner's radius, so a saved corner comes back as Roblox's default 8 px (a rounded square).
local function round(f: Instance)
	local corner = f:FindFirstChildOfClass("UICorner") or new("UICorner", { Parent = f })
	corner.CornerRadius = UDim.new(0.5, 0)
	local studs = f:FindFirstChild("StudPattern")
	local inner = studs and studs:FindFirstChildOfClass("UICorner")
	if inner then inner.CornerRadius = UDim.new(0.5, 0) end
end

-- A circle (UICorner at half size).
local function circle(props: { [string]: any }, d: number, children: { Instance }?)
	props.Size = UDim2.fromOffset(d, d)
	props.AnchorPoint = props.AnchorPoint or Vector2.new(0.5, 0.5)
	props.BorderSizePixel = 0
	local f = new("Frame", props, children)
	round(f)
	return f
end

-- The Spin Knife drawn from parts, in its own colours (as the Shop draws knives).
local function knife(box: Frame, s: number)
	local item = CoinShop.get("SpinKnife")
	local seq = if item then CoinShop.sequence(item) else ColorSequence.new(Color3.new(1, 1, 1))
	local u = Vector2.new(1, -1).Unit
	local function at(t: number) local p = Vector2.new(s / 2, s / 2) + u * (t * s); return UDim2.fromOffset(math.round(p.X), math.round(p.Y)) end
	local blade = new("Frame", { Name = "Blade", AnchorPoint = Vector2.new(0.5, 0.5), Position = at(0.13), Size = UDim2.fromOffset(math.round(s * 0.2), math.round(s * 0.6)), Rotation = 45, BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, ZIndex = 2, Parent = box },
		{ Kit.corner(math.round(s * 0.09)), Kit.stroke(INK, 2) })
	new("UIGradient", { Name = "Colours", Rotation = 90, Color = seq, Parent = blade })
	new("Frame", { Name = "Guard", AnchorPoint = Vector2.new(0.5, 0.5), Position = at(-0.2), Size = UDim2.fromOffset(math.round(s * 0.42), math.round(s * 0.09)), Rotation = 45, BackgroundColor3 = hex("FFE3F4"), BorderSizePixel = 0, ZIndex = 3, Parent = box },
		{ Kit.corner(3), Kit.stroke(INK, 2) })
	new("Frame", { Name = "Handle", AnchorPoint = Vector2.new(0.5, 0.5), Position = at(-0.33), Size = UDim2.fromOffset(math.round(s * 0.11), math.round(s * 0.22)), Rotation = 45, BackgroundColor3 = hex("2A2346"), BorderSizePixel = 0, ZIndex = 2, Parent = box },
		{ Kit.corner(3), Kit.stroke(INK, 1.5) })
	circle({ Name = "Pommel", Position = at(-0.46), BackgroundColor3 = hex("FF6FC0"), ZIndex = 3, Parent = box }, math.round(s * 0.13), { Kit.stroke(INK, 1.5) })
end

-- A prize's picture: coins stack up with the amount, Aura stars, the boost's coin and clock, the knife.
local function prizeArt(parent: Instance, item: any, s: number, pos: UDim2, name: string?)
	local box = new("Frame", { Name = name or "Art", AnchorPoint = Vector2.new(0.5, 0.5), Position = pos, Size = UDim2.fromOffset(s, s), BackgroundTransparency = 1, ZIndex = 3, Parent = parent })
	new("UIScale", { Name = "Pop", Parent = box })
	local function icon(n: string, key: string, size: number, x: number, y: number, z: number)
		Kit.icon(n, { Name = key, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(math.round(x), math.round(y)), Size = UDim2.fromOffset(math.round(size), math.round(size)), ZIndex = z, Parent = box })
	end
	if item.Kind == "Coins" then
		local n = if item.Amount >= 1000 then 4 elseif item.Amount >= 500 then 3 elseif item.Amount >= 250 then 2 else 1
		local spots = ({ { { 0.5, 0.5 } }, { { 0.38, 0.58 }, { 0.62, 0.42 } }, { { 0.3, 0.62 }, { 0.7, 0.62 }, { 0.5, 0.36 } }, { { 0.3, 0.66 }, { 0.7, 0.66 }, { 0.3, 0.36 }, { 0.7, 0.36 } } })[n]
		for i, p in spots do icon("CurrencyCoin", "Coin" .. i, s * (if n == 1 then 0.86 else 0.6), p[1] * s, p[2] * s, i) end
	elseif item.Kind == "Aura" then
		if item.Amount >= 60 then
			icon("AuraStar", "Star1", s * 0.7, s * 0.36, s * 0.6, 1)
			icon("AuraStar", "Star2", s * 0.7, s * 0.64, s * 0.4, 2)
		else
			icon("AuraStar", "Star1", s * 0.9, s * 0.5, s * 0.5, 1)
		end
	elseif item.Kind == "Boost" then
		icon("CurrencyCoin", "Coin1", s * 0.8, s * 0.44, s * 0.46, 1)
		icon("Stopwatch", "Clock", s * 0.48, s * 0.76, s * 0.74, 2)
	elseif item.Kind == "Knife" then
		knife(box, s)
	end
	return box
end

function SpinWheel.build(parent: Instance)
	local player = Players.LocalPlayer
	local holder = new("Frame", { Name = "SpinWheel", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(W, H), BackgroundTransparency = 1, Visible = false, ZIndex = 20, Parent = parent })
	new("UIScale", { Name = "FitScale", Parent = holder })
	local group = new("Frame", { Name = "Group", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Visible = false, Parent = holder })
	local openScale = new("UIScale", { Name = "OpenScale", Parent = group })

	-- Top: the free spin clock (real, from the save), and the x2 Coins time left when a boost is on.
	local top = new("Frame", { Name = "Top", Position = UDim2.fromOffset(240, 8), Size = UDim2.fromOffset(800, 84), BackgroundTransparency = 1, Parent = group })
	local title = words({ Name = "FreeSpin", Text = "Free Spin", TextSize = 46, Position = UDim2.fromOffset(0, 0), Size = UDim2.fromOffset(800, 54), ZIndex = 2, Parent = top }, 3)
	local boostLine = words({ Name = "Boost", Text = "", TextSize = 18, TextColor3 = C.Accent, Position = UDim2.fromOffset(0, 54), Size = UDim2.fromOffset(800, 22), Visible = false, Parent = top }, 1.5)

	-- The wheel.
	-- soft light turning behind the wheel (a sibling under the title and the wheel, so it never covers either)
	Effects.rays(group, UDim2.fromOffset(CX, CY), math.round(D * 1.75), { transparency = 0.45, seconds = 24, z = 0, name = "WheelRays" })
	local wheel = new("Frame", { Name = "Wheel", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(CX, CY), Size = UDim2.fromOffset(D, D), BackgroundTransparency = 1, Parent = group })
	new("UIScale", { Name = "Pop", Parent = wheel })
	circle({ Name = "Shadow", Position = UDim2.new(0.5, 0, 0.5, 8), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.6, ZIndex = 1, Parent = wheel }, D + 30)
	circle({ Name = "Outline", Position = UDim2.fromScale(0.5, 0.5), BackgroundColor3 = C.Frame, ZIndex = 2, Parent = wheel }, D + 26)
	local disc = new("Frame", { Name = "Disc", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(D, D), BackgroundTransparency = 1, ZIndex = 3, Parent = wheel })
	local slices = {}
	for i, item in Wheel.Items do
		local seg = new("Frame", { Name = "Slice" .. i, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(1, 1), Rotation = (i - 1) * 45, BackgroundTransparency = 1, ZIndex = 1, Parent = disc })
		local wedgeProps = { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.3854, 0.5), ScaleType = Enum.ScaleType.Stretch }
		local wedge = Kit.art("SpinWedge", { Name = "Wedge", AnchorPoint = wedgeProps.AnchorPoint, Position = wedgeProps.Position, Size = wedgeProps.Size, ScaleType = wedgeProps.ScaleType, ImageColor3 = Wheel.Colors[item.Color], ZIndex = 1, Parent = seg })
		local glow = Kit.art("SpinWedge", { Name = "Glow", AnchorPoint = wedgeProps.AnchorPoint, Position = wedgeProps.Position, Size = wedgeProps.Size, ScaleType = wedgeProps.ScaleType, ImageColor3 = Color3.new(1, 1, 1), ImageTransparency = 1, ZIndex = 2, Parent = seg })
		local art = prizeArt(seg, item, 78, UDim2.fromOffset(R, math.round(R - 0.66 * R)), "Prize")
		local big = words({ Name = "Big", Text = item.Big, TextSize = if #item.Big >= 4 then 27 else 32, Position = UDim2.fromOffset(R - 50, math.round(R - 0.43 * R) - 15), Size = UDim2.fromOffset(100, 30), ZIndex = 4, Parent = seg }, 2.2)
		words({ Name = "Small", Text = item.Small, TextSize = 13, FontFace = F.Name, Position = UDim2.fromOffset(R - 40, math.round(R - 0.43 * R) + 13), Size = UDim2.fromOffset(80, 16), ZIndex = 4, Parent = seg }, 1.4)
		slices[i] = { seg = seg, wedge = wedge, glow = glow, art = art, big = big }
	end
	-- dividers between the slices (full-width lines through the middle), and a peg at each edge
	for k = 1, 4 do
		new("Frame", { Name = "Divider" .. k, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(5, D), Rotation = 22.5 + (k - 1) * 45, BackgroundColor3 = C.Frame, BorderSizePixel = 0, ZIndex = 2, Parent = disc })
	end
	for k = 1, 8 do
		local a = math.rad(22.5 + (k - 1) * 45 - 90)
		circle({ Name = "Peg" .. k, Position = UDim2.fromOffset(math.round(R + math.cos(a) * (R - 13)), math.round(R + math.sin(a) * (R - 13))), BackgroundColor3 = Color3.new(1, 1, 1), ZIndex = 5, Parent = disc }, 12, { Kit.stroke(C.Frame, 2) })
	end
	-- the rim (a white ring over the slices' edges), the hub and the pin
	circle({ Name = "Rim", Position = UDim2.fromScale(0.5, 0.5), BackgroundTransparency = 1, ZIndex = 4, Parent = wheel }, D - 6, { new("UIStroke", { Name = "Ring", Color = Color3.new(1, 1, 1), Thickness = 8 }) })
	local hub = circle({ Name = "Hub", Position = UDim2.fromScale(0.5, 0.5), BackgroundColor3 = C.Panel, ZIndex = 5, Parent = wheel }, 96, { new("UIStroke", { Name = "Ring", Color = Color3.new(1, 1, 1), Thickness = 5 }) })
	Kit.studPattern(hub, 0.45)
	round(hub)
	circle({ Name = "Cap", Position = UDim2.fromScale(0.5, 0.5), BackgroundColor3 = Color3.new(1, 1, 1), ZIndex = 2, Parent = hub }, 30, { Kit.stroke(C.Frame, 3) })
	-- the pin hangs from the top of the rim; it turns about its round head (the pivot)
	local pin = new("Frame", { Name = "Pointer", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(R, -12), Size = UDim2.fromOffset(90, 90), BackgroundTransparency = 1, ZIndex = 6, Parent = wheel })
	new("Frame", { Name = "Tip", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(45, 70), Size = UDim2.fromOffset(40, 40), Rotation = 45, BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, ZIndex = 1, Parent = pin }, { Kit.corner(5), Kit.stroke(C.Frame, 4) })
	circle({ Name = "Head", Position = UDim2.fromOffset(45, 45), BackgroundColor3 = Color3.new(1, 1, 1), ZIndex = 2, Parent = pin }, 54, { Kit.stroke(C.Frame, 4) })
	circle({ Name = "Gem", Position = UDim2.fromOffset(45, 45), BackgroundColor3 = Wheel.Colors.Legendary, ZIndex = 3, Parent = pin }, 24, { Kit.stroke(C.Frame, 2) })

	-- (?) Odds, top left of the wheel, and its list
	local odds = button(group, "Odds", "?", "SpinBlue", 290, 178, 56, 56, 38)
	words({ Name = "OddsLabel", Text = "Odds", TextSize = 18, FontFace = F.Name, Position = UDim2.fromOffset(278, 236), Size = UDim2.fromOffset(80, 22), Parent = group }, 1.6)
	local oddsPanel = new("Frame", { Name = "OddsList", Position = UDim2.fromOffset(356, 150), Size = UDim2.fromOffset(330, 352), BackgroundColor3 = C.Panel, BackgroundTransparency = 0.08, BorderSizePixel = 0, Visible = false, ZIndex = 30, Parent = group }, { Kit.corner(8), new("UIStroke", { Name = "Frame", Color = C.Frame, Thickness = 4 }) })
	Kit.studPattern(oddsPanel, 0.3)
	words({ Name = "Heading", Text = "ODDS", TextSize = 24, Position = UDim2.fromOffset(16, 8), Size = UDim2.fromOffset(200, 30), TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 2, Parent = oddsPanel }, 2)
	local oddsClose = Kit.closeButton({ Position = UDim2.new(1, -8, 0, 8), AnchorPoint = Vector2.new(1, 0), Size = UDim2.fromOffset(28, 28), Parent = oddsPanel })
	local list = CrateRoll.odds(Wheel)
	table.sort(list, function(a, b) return a.chance > b.chance end)
	for i, o in list do
		local y = 44 + (i - 1) * 32
		local row = new("Frame", { Name = "Row" .. i, Position = UDim2.fromOffset(10, y), Size = UDim2.fromOffset(310, 30), BackgroundColor3 = C.Row, BackgroundTransparency = if i % 2 == 1 then 0.35 else 0.7, BorderSizePixel = 0, ZIndex = 2, Parent = oddsPanel }, { Kit.corner(5) })
		prizeArt(row, o.item, 26, UDim2.fromOffset(20, 15), "Art")
		words({ Name = "Name", Text = o.item.Name, TextSize = 15, FontFace = F.Name, TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.fromOffset(40, 0), Size = UDim2.fromOffset(140, 30), ZIndex = 3, Parent = row }, 1.2)
		words({ Name = "Rarity", Text = o.item.Rarity, TextSize = 13, FontFace = F.Name, TextColor3 = Wheel.RarityColors[o.item.Rarity] or C.Text, TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.fromOffset(178, 0), Size = UDim2.fromOffset(80, 30), ZIndex = 3, Parent = row }, 1.2)
		words({ Name = "Chance", Text = string.format("%g%%", math.floor(o.chance * 100 + 0.5) / 100), TextSize = 17, FontFace = F.Number, TextXAlignment = Enum.TextXAlignment.Right, Position = UDim2.fromOffset(240, 0), Size = UDim2.fromOffset(62, 30), ZIndex = 3, Parent = row }, 1.4)
	end
	Kit.text({ Name = "Pity", Text = `A Legendary is guaranteed within {Wheel.Pity.After} spins.`, FontFace = F.Body, TextSize = 14, TextColor3 = C.SubText, TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.fromOffset(10, 44 + #list * 32 + 2), Size = UDim2.fromOffset(310, 30), ZIndex = 2, Parent = oddsPanel })
	local function showOdds(on: boolean)
		oddsPanel.Visible = on
		if on then Motion.pop(oddsPanel) end
	end
	odds.onClick(function() showOdds(not oddsPanel.Visible) end)
	oddsClose.onClick(function() showOdds(false) end)

	-- Left: Spin x5 / Spin x10. Right: the spin packs (Robux).
	local left = new("Frame", { Name = "Left", Position = UDim2.fromOffset(24, 270), Size = UDim2.fromOffset(250, 130), BackgroundTransparency = 1, Parent = group })
	local multi = {}
	for i, n in Wheel.Multi do
		multi[n] = button(left, "SpinX" .. n, `Spin x{n}`, "SpinGreen", 0, (i - 1) * 70, 250, 58, 36)
	end
	local right = new("Frame", { Name = "Right", Position = UDim2.fromOffset(986, 270), Size = UDim2.fromOffset(270, 200), BackgroundTransparency = 1, Parent = group })
	local buys = {}
	for i, p in Products.Spins do
		local b = button(right, "Buy" .. p.Key, "", "SpinPurple", 0, (i - 1) * 70, 270, 58, 23)
		buys[p.Key] = { b = b, p = p }
	end

	-- Bottom: Spin! (N), the pity counter, Close.
	local bottom = new("Frame", { Name = "Bottom", Position = UDim2.fromOffset(200, 590), Size = UDim2.fromOffset(760, 100), BackgroundTransparency = 1, Parent = group })
	local spinBtn = button(bottom, "Spin", "Spin!", "SpinGreen", 8, 28, 270, 62, 40)
	words({ Name = "PityLabel", Text = "GUARANTEED LEGENDARY", TextSize = 17, FontFace = F.Heading, TextColor3 = hex("FFD1EC"), Position = UDim2.fromOffset(300, 0), Size = UDim2.fromOffset(280, 24), Parent = bottom }, 1.8)
	local pityBox = new("Frame", { Name = "Pity", Position = UDim2.fromOffset(300, 28), Size = UDim2.fromOffset(280, 62), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, Parent = bottom }, { Kit.corner(8), new("UIStroke", { Name = "Rim", Color = hex("3B0A6A"), Thickness = 2.5 }) })
	new("UIGradient", { Name = "Shade", Rotation = 90, Color = ColorSequence.new(hex("B85BFA"), hex("8A22E0")), Parent = pityBox })
	Kit.studPattern(pityBox, 0.22)
	local pityText = words({ Name = "Count", Text = "", TextSize = 26, Position = UDim2.fromOffset(0, 6), Size = UDim2.fromOffset(280, 34), ZIndex = 2, Parent = pityBox }, 2.2)
	local track = new("Frame", { Name = "Track", Position = UDim2.fromOffset(18, 44), Size = UDim2.fromOffset(244, 9), BackgroundColor3 = hex("3B0A6A"), BorderSizePixel = 0, ZIndex = 2, Parent = pityBox }, { Kit.corner(4) })
	local fill = new("Frame", { Name = "Fill", Size = UDim2.fromScale(0, 1), BackgroundColor3 = Wheel.Colors.Legendary, BorderSizePixel = 0, ZIndex = 2, Parent = track }, { Kit.corner(4) })
	local close = button(bottom, "Close", "Close", "SpinGrey", 602, 36, 150, 50, 30)
	close.onClick(function() ModalManager.close() end)

	-- The reward card (over the wheel): one prize big, or a multi-spin's prizes grouped.
	local card = new("Frame", { Name = "Reward", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(CX, CY), Size = UDim2.fromOffset(460, 330), BackgroundColor3 = C.Panel, BackgroundTransparency = 0.06, BorderSizePixel = 0, Visible = false, ZIndex = 40, Parent = group }, { Kit.corner(10), new("UIStroke", { Name = "Frame", Color = C.Frame, Thickness = 5 }) })
	Kit.studPattern(card, 0.3)
	local cardPop = new("UIScale", { Name = "Pop", Parent = card })
	local cardTitle = words({ Name = "Title", Text = "YOU WON!", FontFace = F.Big, TextSize = 40, Position = UDim2.fromOffset(0, 14), Size = UDim2.fromOffset(460, 48), ZIndex = 2, Parent = card }, 3)
	local one = new("Frame", { Name = "One", Position = UDim2.fromOffset(0, 64), Size = UDim2.fromOffset(460, 190), BackgroundTransparency = 1, ZIndex = 2, Parent = card })
	local oneArt = new("Frame", { Name = "ArtSpot", Position = UDim2.fromOffset(170, 0), Size = UDim2.fromOffset(120, 120), BackgroundTransparency = 1, ZIndex = 2, Parent = one })
	local oneName = words({ Name = "PrizeName", Text = "", TextSize = 32, Position = UDim2.fromOffset(0, 124), Size = UDim2.fromOffset(460, 38), ZIndex = 2, Parent = one }, 2.4)
	local oneRarity = words({ Name = "Rarity", Text = "", TextSize = 18, FontFace = F.Name, Position = UDim2.fromOffset(0, 162), Size = UDim2.fromOffset(460, 24), ZIndex = 2, Parent = one }, 1.5)
	local many = new("Frame", { Name = "Many", Position = UDim2.fromOffset(20, 70), Size = UDim2.fromOffset(420, 184), BackgroundTransparency = 1, Visible = false, ZIndex = 2, Parent = card })
	local manyRows = {}
	for i = 1, 8 do
		local col, rowN = (i - 1) // 4, (i - 1) % 4
		local row = new("Frame", { Name = "Row" .. i, Position = UDim2.fromOffset(col * 214, rowN * 46), Size = UDim2.fromOffset(206, 40), BackgroundColor3 = C.Row, BackgroundTransparency = 0.35, BorderSizePixel = 0, Visible = false, ZIndex = 2, Parent = many }, { Kit.corner(6) })
		local spot = new("Frame", { Name = "ArtSpot", Position = UDim2.fromOffset(4, 2), Size = UDim2.fromOffset(36, 36), BackgroundTransparency = 1, ZIndex = 3, Parent = row })
		local text = words({ Name = "Text", Text = "", TextSize = 16, FontFace = F.Name, TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.fromOffset(46, 0), Size = UDim2.fromOffset(156, 40), ZIndex = 3, Parent = row }, 1.4)
		manyRows[i] = { row = row, spot = spot, text = text }
	end
	local nice = button(card, "Nice", "Nice!", "SpinGreen", 150, 262, 160, 52, 28)

	-- What the save says now.
	local function now(): number return workspace:GetServerTimeNow() end
	local function counts(): (number, number) return SpinRules.available(State.data, now()) end

	local spinning = false
	local pending: { [string]: boolean } = {}

	local styled: { [any]: string } = {}
	local function styleOf(b, s: string) -- (only when it changes: refresh runs 4 times a second)
		if styled[b] ~= s then styled[b] = s; b.setStyle(s) end
	end
	local function refresh()
		local free, owned = counts()
		local total = free + owned
		spinBtn.setText(if spinning then "Spinning..." else `Spin! ({total})`)
		styleOf(spinBtn, if total > 0 or spinning then "SpinGreen" else "SpinGrey")
		for n, b in multi do styleOf(b, if total >= n then "SpinGreen" else "SpinGrey") end
		if free == 1 then
			title.Text = "FREE SPIN READY!"
			title.TextColor3 = C.Accent
		else
			title.Text = "Free Spin: " .. SpinRules.clock(SpinRules.freeIn(State.data, now()))
			title.TextColor3 = C.Text
		end
		local boostLeft = ((State.data.Boosts or {}).Coins or 0) - now()
		boostLine.Visible = boostLeft > 0
		boostLine.Text = if boostLeft > 0 then "x2 COINS FROM GAMES: " .. SpinRules.clock(boostLeft) else ""
		local left = SpinRules.pityLeft(State.data, Wheel.Pity.After)
		pityText.Text = if left <= 1 then "on your next spin!" else `in {left} spins`
		fill.Size = UDim2.fromScale(math.clamp((State.data.SpinPity or 0) / Wheel.Pity.After, 0, 1), 1)
		for _, e in buys do
			local p = e.p
			e.b.setText(if pending[p.Key] then "..." else `Buy {p.Name} {Format.RobuxMark} {p.Price}`)
		end
	end

	-- Buying spins: only Roblox's own prompt; the server grants them (ShopService). No ID yet = "coming soon".
	for _, e in buys do
		e.b.onClick(function()
			local p = e.p
			if pending[p.Key] then return end
			local status = Products.status(p)
			if status ~= "Ready" then
				Toast.show("Buying spins is coming soon.")
				if status == "NoId" then warn(`[Shop] {p.Key} has no Developer Product ID in Shared/Config/Products.lua`) end
				return
			end
			pending[p.Key] = true
			refresh()
			local ok = pcall(function() MarketplaceService:PromptProductPurchase(player, p.Id) end)
			if not ok then
				pending[p.Key] = nil
				Toast.show("The purchase couldn't open. Try again.")
			else
				task.delay(90, function() if pending[p.Key] then pending[p.Key] = nil; refresh() end end)
			end
			refresh()
		end)
	end
	MarketplaceService.PromptProductPurchaseFinished:Connect(function(userId, id)
		if userId ~= player.UserId then return end
		for _, p in Products.Spins do
			if p.Id == id then pending[p.Key] = nil end
		end
		refresh()
	end)

	-- The spin itself. The wheel's Rotation is the disc's; slice i sits at (i - 1) * 45 degrees from the top.
	local rotation = 0
	local pinKick = 0
	local conn: RBXScriptConnection? = nil
	local finishNow: (() -> ())? = nil
	local buttons = { spinBtn, odds, nice }
	for _, b in multi do table.insert(buttons, b) end
	local function setBusy(on: boolean)
		spinning = on
		for _, b in buttons do b.setEnabled(not on) end
		refresh()
	end

	local function hideCard()
		card.Visible = false
	end
	local function clearSpot(spot: Instance)
		for _, ch in spot:GetChildren() do ch:Destroy() end
	end
	local function showCard(rolls: { any })
		-- group the same prize: "100 Coins x3"
		local groups, order = {}, {}
		for _, r in rolls do
			local key = r.Text
			if not groups[key] then groups[key] = { roll = r, n = 0 }; table.insert(order, key) end
			groups[key].n += 1
		end
		table.sort(order, function(a, b)
			local ra, rb = CrateRoll.RANK[groups[a].roll.Rarity] or 0, CrateRoll.RANK[groups[b].roll.Rarity] or 0
			if ra ~= rb then return ra > rb end
			return groups[a].n > groups[b].n
		end)
		if #rolls == 1 then
			local r = rolls[1]
			local item = Wheel.Items[r.Slot]
			cardTitle.Text = if r.Rarity == "Legendary" then "LEGENDARY!" else "YOU WON!"
			one.Visible, many.Visible = true, false
			clearSpot(oneArt)
			prizeArt(oneArt, item, 120, UDim2.fromScale(0.5, 0.5), "Art")
			oneName.Text = r.Text
			oneRarity.Text = r.Rarity
			oneRarity.TextColor3 = Wheel.RarityColors[r.Rarity] or C.Text
		else
			cardTitle.Text = `YOU WON! (x{#rolls})`
			one.Visible, many.Visible = false, true
			for i, m in manyRows do
				local key = order[i]
				m.row.Visible = key ~= nil
				clearSpot(m.spot)
				if key then
					local g = groups[key]
					prizeArt(m.spot, Wheel.Items[g.roll.Slot], 34, UDim2.fromScale(0.5, 0.5), "Art")
					m.text.Text = if g.n > 1 then `{g.roll.Text} x{g.n}` else g.roll.Text
					m.text.TextColor3 = if g.roll.Rarity == "Legendary" or g.roll.Rarity == "Epic" then Wheel.RarityColors[g.roll.Rarity] else C.Text
				end
			end
		end
		card.Visible = true
		cardPop.Scale = if Motion.reduced then 1 else 0.6
		Motion.tween(cardPop, "pop", 0.35, { Scale = 1 }, Enum.EasingStyle.Back)
	end
	nice.onClick(hideCard)

	local function land(rolls: { any }, landAt: number, silent: boolean?)
		local r = rolls[landAt]
		local s = slices[r.Slot]
		local big = r.Rarity == "Legendary" or r.Rarity == "Epic"
		if not silent then
			Sfx.play(if big then "spin_big_win" else "spin_win")
			-- one glow on the prize slice (a single flash) and its picture pops
			s.glow.ImageTransparency = 1
			Motion.tween(s.glow, "glow", 0.16, { ImageTransparency = 0.4 })
			task.delay(0.2, function() Motion.tween(s.glow, "glow", 0.8, { ImageTransparency = 1 }, Enum.EasingStyle.Sine) end)
			local pop = s.art:FindFirstChild("Pop") :: UIScale?
			if pop and not Motion.reduced then
				pop.Scale = 1.35
				Motion.tween(pop, "pop", 0.6, { Scale = 1 }, Enum.EasingStyle.Back)
			end
			task.delay(0.55, function()
				if holder.Visible and ModalManager.current() == "SpinWheel" then showCard(rolls) end
			end)
		end
	end

	local lastRolls: { any }? = nil
	local function animateTo(rolls: { any }, landAt: number)
		lastRolls = rolls
		Motion.tween(disc, "turn", 0, { Rotation = rotation % 360 }) -- (stops the opening turn if it's still going)
		local slot = rolls[landAt].Slot
		local offset = (math.random() * 2 - 1) * 15 -- somewhere inside the slice, never on an edge
		local from = rotation
		local target = SpinRules.landRotation(from, slot, TURNS, offset)
		local started = os.clock()
		local lastEdge = SpinRules.edges(from)
		local lastTick = 0
		local done = false
		local function finish(silent: boolean?)
			if done then return end
			done = true
			if conn then conn:Disconnect(); conn = nil end
			finishNow = nil
			rotation = target % 360
			disc.Rotation = rotation
			pin.Rotation = 0
			setBusy(false)
			land(rolls, landAt, silent)
		end
		finishNow = function() finish(true) end
		conn = RunService.RenderStepped:Connect(function(dt)
			local t = math.clamp((os.clock() - started) / SPIN_TIME, 0, 1)
			local e = 1 - (1 - t) ^ 4 -- fast start, long smooth ease-out
			local rot = from + (target - from) * e
			disc.Rotation = rot % 360
			-- the pin: kicked back at each slice edge, then it springs home
			local edge = SpinRules.edges(rot)
			if edge ~= lastEdge then
				lastEdge = edge
				pinKick = 1
				local c = os.clock()
				if c - lastTick > 0.045 then -- (at full speed the edges pass faster than the ear wants ticks)
					lastTick = c
					Sfx.play("spin_tick")
				end
			end
			pinKick = math.max(0, pinKick - dt / 0.11)
			pin.Rotation = -24 * pinKick
			if t >= 1 then finish() end
		end)
	end

	local function spin(count: number)
		if spinning then return end
		local free, owned = counts()
		if free + owned < count then
			Sfx.play("ui_error")
			if free + owned == 0 then
				Toast.show("No spins left. Free spin in " .. SpinRules.clock(SpinRules.freeIn(State.data, now())) .. ".")
			else
				Toast.show(`Spin x{count} needs {count} spins. You have {free + owned}.`)
			end
			return
		end
		hideCard()
		showOdds(false)
		setBusy(true)
		local okCall, ok, result = pcall(function() return (Net.get("Spin") :: RemoteFunction):InvokeServer(count) end)
		if not okCall or not ok or type(result) ~= "table" or type(result.rolls) ~= "table" or #result.rolls == 0 then
			setBusy(false)
			Toast.show(if okCall and type(result) == "string" then result else "Couldn't spin. Try again.")
			return
		end
		local landAt = tonumber(result.land) or 1
		if not result.rolls[landAt] then landAt = 1 end
		animateTo(result.rolls, landAt)
	end
	spinBtn.onClick(function() spin(1) end)
	for n, b in multi do b.onClick(function() spin(n) end) end

	-- the clock ticks while the screen is open
	local openToken = 0
	local function tickLoop()
		openToken += 1
		local mine = openToken
		task.spawn(function()
			while mine == openToken and holder.Visible do
				refresh()
				task.wait(0.25)
			end
		end)
	end

	-- Opening: the window grows in (ModalManager); the side columns and the bottom row glide in and the wheel turns
	-- into place. Plain frames, no CanvasGroup.
	local homes = { [left] = left.Position, [right] = right.Position, [bottom] = bottom.Position, [top] = top.Position }
	local from = { [left] = UDim2.fromOffset(-90, 0), [right] = UDim2.fromOffset(90, 0), [bottom] = UDim2.fromOffset(0, 70), [top] = UDim2.fromOffset(0, -50) }
	local function onOpen()
		hideCard()
		showOdds(false)
		refresh()
		tickLoop()
		if Motion.reduced then return end
		for g, off in from do
			g.Position = homes[g] + off
			Motion.tween(g, "slide", 0.45, { Position = homes[g] }, Enum.EasingStyle.Quint)
		end
		if not spinning then
			disc.Rotation = rotation - 50
			Motion.tween(disc, "turn", 0.7, { Rotation = rotation }, Enum.EasingStyle.Quint)
		end
	end
	local function onClose()
		openToken += 1
		showOdds(false)
		local rolls = lastRolls
		if finishNow and rolls then
			-- closed mid-spin: the prizes are yours already; the wheel stops at once and a line says what they were
			finishNow()
			local r = rolls[SpinRules.best(rolls, CrateRoll.RANK)]
			Toast.show(if #rolls == 1 then `You won {r.Text}!` else `You won {#rolls} prizes! Best: {r.Text}`)
		end
		hideCard()
	end

	ModalManager.register("SpinWheel", {
		window = { Holder = holder, Group = group, OpenScale = openScale, Width = W, Height = H },
		onOpen = onOpen,
		onClose = onClose,
		noBlur = true, -- (the reference keeps the world in view behind the wheel)
		firstSelect = function() return spinBtn.Instance end,
	})
	State.changed(function() if holder.Visible then refresh() end end)

	-- The wheel in the lobby (SpinService) opens this screen. Not during a round or the Hero pick.
	local openRemote = Net.get("SpinOpen") :: RemoteEvent
	openRemote.OnClientEvent:Connect(function()
		local role = player:GetAttribute("HuzzRole")
		if role == "Runner" or role == "Catcher" or player:GetAttribute("HuzzChoosing") == true then return end
		if ModalManager.current() == "SpinWheel" then return end
		ModalManager.open("SpinWheel")
	end)
	refresh()
	return holder
end

-- For the HUD's SPIN button: true while a free spin is waiting.
function SpinWheel.freeReady(): boolean
	local free = SpinRules.available(State.data, workspace:GetServerTimeNow())
	return free == 1
end

return SpinWheel
