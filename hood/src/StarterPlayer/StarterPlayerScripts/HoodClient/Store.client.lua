-- The Store window, rebuilt 1:1 from the user's Exclusive Shop reference (brief 30), as flat 2D UI: a thick studded yellow
-- header bar ("EXCLUSIVE SHOP", a blue "Gift A Player" button with a gift, a red X) over a dark scrolling body whose
-- sections have white italic outlined titles, top to bottom:
--   FEATURED         the week's pack (one of Products.FeaturedKeys: a painted card, three item tiles with blue value chips,
--                    a big price button) and the Server Boost card (Block Party: "1x > 2x", "+15 minutes", an Info tab).
--                    The countdown on the pack is REAL: Products.featuredAt rotates it weekly by the clock, the same for
--                    everyone, and the card really changes to the next pack when it reaches 0. No timer anywhere else.
--   GAMEPASSES       the coloured 2-column grid: a big icon, an outlined title, a 2-line description, OWNED or the price
--   CASH PACKS       3 columns of lime cards, the biggest as the tall "MEGA PACK" card with a "BEST DEAL" ribbon; the amount
--                    is live (it scales with your best stage). A struck-through price only where Products has a real one.
--   POWER PACKS, BOOSTS   the same card language
--   BOXES            one card per Robux shoe box: the real 3D box and its shoes (3D only where a real item is shown)
--   COMMUNITY CODES  the code box (HoodServer/CodesService)
-- Gift A Player (header button): pick a player in this server, then buy a Cash Pack or a box: the buy buttons turn blue,
-- the chosen target is sent to the server right before the prompt (GiftTarget) and the server grants it to them. Passes,
-- boosts and Power packs are never gifted. Items come from Config/Products (only Wired rows show); a tap on a price prompts
-- Roblox's purchase only when the item is live (Products.canBuy), otherwise "coming soon". With an id the card asks Roblox
-- for the live price. The HUD opens it through the BindableEvent HoodStore.Open (optionally a section id, a catalog key or
-- 'Codes' to scroll to); PlayerGui's HoodWindow attribute keeps one window open at a time.
local Players = game:GetService('Players')
local RS = game:GetService('ReplicatedStorage')
local MarketplaceService = game:GetService('MarketplaceService')

local Shared = RS:WaitForChild('Shared')
local Kit = require(Shared.UIKit)
local Motion = require(Shared.UIMotion)
local Products = require(Shared.Config.Products)
local Balance = require(Shared.Config.Balance)

local function optional(...)
	local node = Shared
	for _, name in { ... } do
		node = node and node:FindFirstChild(name)
	end
	if not node then return nil end
	local ok, result = pcall(require, node)
	return ok and type(result) == 'table' and result or nil
end
local RebirthRules = optional('RebirthRules')
local ShoeRules = optional('ShoeRules')
local Shoes = optional('Config', 'Shoes')
local Net = optional('Net')
-- (brief 22) Roblox's player list (top right, under the topbar) would sit over the window's X: hidden while the Store is
-- open, through UI4's shared switch so the inventory, World and HUD windows agree (UIKit.HidePlayerList: hidden for good)
local InventoryKit = optional('InventoryKit')
local function coverPlayerList(on)
	if InventoryKit and type(InventoryKit.coverPlayerList) == 'function' then InventoryKit.coverPlayerList('Store', on) end
end

local player = Players.LocalPlayer
local playerGui = player:WaitForChild('PlayerGui')
local Color, short, hex = Kit.Color, Kit.short, Kit.hex
local BLACK = Color.black
local px = UDim2.fromOffset
local iconOr = Kit.iconOr -- (the first id IconModels knows: an uploaded PNG or a flat stand-in row)

local NAME = 'Store'
local gui, root, fit = Kit.screen('HoodStore', nil, 8)
local openEvent = Instance.new('BindableEvent')
openEvent.Name = 'Open'
openEvent.Parent = gui

---------------------------------------------------------------------------------------------- data
local function num(name, fallback)
	local v = player:GetAttribute(name)
	return type(v) == 'number' and v == v and v or fallback
end
-- The Power your next rebirth needs (the server's attribute, else the shared rule): power packs are sized from it.
local function rebirthNeed()
	local v = num('RebirthNeed', nil)
	if v and v > 0 then return v end
	local n = num('Rebirths', 0)
	if RebirthRules and type(RebirthRules.need) == 'function' then
		local ok, r = pcall(RebirthRules.need, n)
		if ok and type(r) == 'number' then return r end
	end
	return math.floor((Balance.RebirthBase or 2500) * (Balance.RebirthRequirementGrowth or 2.3) ^ n + 0.5)
end
local function owns(entry) return entry.Kind == 'Pass' and player:GetAttribute('Pass_' .. entry.Key) == true end

-- Outlined display text: a black stroke ~12% of the size, like every label of the reference.
local function label(props)
	props.Stroke = props.Stroke or BLACK
	props.StrokeThickness = props.StrokeThickness or math.max(2, (props.TextSize or 20) * 0.12)
	return Kit.text(props)
end
local function gradient(t, top, bottom)
	Kit.new('UIGradient', { Rotation = 90, Color = ColorSequence.new(top, bottom), Parent = t })
	return t
end

---------------------------------------------------------------------------------------------- window
local WIN = { W = 800, Head = 66, Body = 468, Pad = 12 }
local LIST_W = WIN.W - 2 * WIN.Pad
-- Tones that are not in Kit.Tone: the reference's lime cards and price buttons, the OWNED button, the gift's blue.
local LIME = { top = hex('DEF52A'), base = hex('5ED614'), lip = hex('3FA00A'), stroke = hex('1B4A00'), rim = hex('C8F55E') }
local LIMEBTN = { top = hex('E8F94A'), base = hex('9CDD22'), lip = hex('7CB814'), stroke = hex('24510A'), rim = hex('F2FC9A') }
local HEADER = { top = hex('FFE24A'), base = hex('F4B814'), lip = hex('D49A00'), stroke = hex('5A3C08'), rim = hex('FFF39A') } -- (the reference's bar: light yellow at the top, orange-yellow at the bottom)
local OWNEDBTN = { top = hex('FFF45A'), base = hex('E8C812'), lip = hex('C8A000'), stroke = hex('4A3600'), rim = hex('FFFAA8') }

-- A little drawn gift (a red box, a gold ribbon and bow), centred at `pos`.
local function giftGlyph(parent, size, z, pos)
	local g = Kit.new('Frame', { Name = 'GiftGlyph', BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = pos, Size = px(size, size), ZIndex = z, Parent = parent })
	local function part(name, x, y, w, h, color, edge, rot)
		local f = Kit.new('Frame', { Name = name, BackgroundColor3 = color, BorderSizePixel = 0, Position = px(x, y), Size = px(w, h), Rotation = rot or 0, ZIndex = z, Parent = g })
		Kit.corner(3).Parent = f
		Kit.stroke(edge, 2, true).Parent = f
		return f
	end
	part('Box', size * 0.1, size * 0.42, size * 0.8, size * 0.5, hex('E8303A'), hex('4A0B16'))
	part('Lid', size * 0.04, size * 0.28, size * 0.92, size * 0.2, hex('FF5A5A'), hex('4A0B16'))
	part('Ribbon', size * 0.43, size * 0.28, size * 0.14, size * 0.64, hex('FFD83A'), hex('5A3A00'))
	part('BowL', size * 0.22, size * 0.06, size * 0.26, size * 0.2, hex('FFD83A'), hex('5A3A00'), -20)
	part('BowR', size * 0.52, size * 0.06, size * 0.26, size * 0.2, hex('FFD83A'), hex('5A3A00'), 20)
	return g
end

local function buildWindow()
	local w, head, bodyH, pad = WIN.W, WIN.Head, WIN.Body, WIN.Pad
	local overlay = Kit.new('Frame', { Name = NAME .. 'Overlay', BackgroundTransparency = 1, BorderSizePixel = 0, Size = UDim2.fromScale(1, 1), ZIndex = 20, Parent = root })
	local fitter = Kit.new('Frame', { Name = 'Fit', BackgroundTransparency = 1, BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = px(w, head + bodyH), ZIndex = 21, Parent = overlay })
	Kit.new('UIScale', { Name = 'FitScale', Parent = fitter })
	local panel = Kit.new('Frame', { Name = NAME, BackgroundTransparency = 1, BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(1, 1), ZIndex = 21, Parent = fitter })
	-- the body: a dark slate at 85%, the black line round it, a light line inside (the header sits over its top)
	local frame = Kit.new('Frame', { Name = 'Frame', BackgroundTransparency = 0.12, BackgroundColor3 = hex('322D3E'), BorderSizePixel = 0, Position = px(0, head - 12), Size = px(w, bodyH + 12), ZIndex = 21, Parent = panel })
	Kit.corner(14).Parent = frame
	Kit.stroke(BLACK, 3, true).Parent = frame
	local rim = Kit.new('Frame', { Name = 'Rim', BackgroundTransparency = 1, BorderSizePixel = 0, Position = px(4, 4), Size = UDim2.new(1, -8, 1, -8), ZIndex = 21, Parent = frame })
	Kit.corner(10).Parent = rim
	Kit.stroke(hex('DCE0EC'), 3, true, 0.55).Parent = rim
	local list = Kit.new('ScrollingFrame', {
		Name = 'Items', BackgroundTransparency = 1, BorderSizePixel = 0, Position = px(pad, head + 4), Size = px(w - 2 * pad, bodyH - pad - 4), ZIndex = 24,
		ScrollBarThickness = WIN.Pad - 5, ScrollBarImageColor3 = Color.white, ScrollBarImageTransparency = 1, ScrollingDirection = Enum.ScrollingDirection.Y,
		VerticalScrollBarInset = Enum.ScrollBarInset.None, AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(), Parent = panel,
	})
	local trackH = bodyH - pad - 24
	local track = Kit.new('Frame', { Name = 'ScrollTrack', BackgroundTransparency = 0.6, BackgroundColor3 = BLACK, BorderSizePixel = 0, AnchorPoint = Vector2.new(1, 0), Position = px(w - pad + 2, head + 12), Size = px(7, trackH), ZIndex = 30, Parent = panel })
	Kit.corner(UDim.new(0.5, 0)).Parent = track
	local thumb = Kit.new('Frame', { Name = 'Thumb', BackgroundTransparency = 0.08, BackgroundColor3 = hex('E8ECF4'), BorderSizePixel = 0, Size = UDim2.new(1, 0, 0, 40), ZIndex = 31, Parent = track })
	Kit.corner(UDim.new(0.5, 0)).Parent = thumb
	local contentH = bodyH
	local function placeThumb()
		local view = list.Size.Y.Offset
		local th = math.clamp(trackH * view / math.max(view, contentH), 36, trackH)
		local f = math.clamp(list.CanvasPosition.Y / math.max(1, contentH - view), 0, 1)
		thumb.Size = UDim2.new(1, 0, 0, th)
		thumb.Position = px(0, math.floor(f * (trackH - th) + 0.5))
		track.Visible = contentH > view + 1
	end
	list:GetPropertyChangedSignal('CanvasPosition'):Connect(placeThumb)
	-- the header bar: yellow, studded, thick black line; the title, the blue Gift A Player button, the red X
	local header = Kit.block({ Name = 'Header', Tone = HEADER, Width = w, Height = head, Studs = 26, StudSparse = true, StudShade = 0.45, Outline = 3.5, RimWidth = 3, Radius = 8, Position = px(0, 0), ZIndex = 26 })
	header.Parent = panel
	local titleText = 'EXCLUSIVE SHOP'
	local title = label({ Name = 'Title', Text = titleText, TextSize = 38, StrokeThickness = 4.5, TextXAlignment = Enum.TextXAlignment.Left, AnchorPoint = Vector2.new(0, 0.5), Position = px(22, head / 2 - 1), Size = px(330, 48), ZIndex = 34, Parent = panel })
	local xs = 52
	local close = Kit.blockButton({ Name = 'Close', Tone = 'cardRed', Width = xs, Height = xs, Text = 'X', TextSize = 34, Studs = false, Outline = 3.5, RimWidth = 3, Radius = 4, AnchorPoint = Vector2.new(1, 0.5), Position = px(w - 12, head / 2 - 1), ZIndex = 32 })
	close.Parent = panel
	local gw, gh = 200, 46
	local gift = Kit.blockButton({ Name = 'GiftButton', Tone = 'cardBlue', Width = gw, Height = gh, Studs = false, Outline = 3, RimWidth = 2, Radius = 7, AnchorPoint = Vector2.new(1, 0.5), Position = px(w - 12 - xs - 14, head / 2 - 1), ZIndex = 32 })
	gift.Parent = panel
	label({ Name = 'Text', Text = 'Gift A Player', TextSize = 20, Stroke = hex('0B2A55'), Position = px(60, 0), Size = UDim2.new(1, -64, 1, -1), ZIndex = 36, Parent = gift.Body })
	-- (the AI picture Gift.png when it is uploaded, else the drawn glyph)
	if Kit.iconImage('Gift') ~= '' then
		Kit.icon3d('Gift', 62, { ZIndex = 36, AnchorPoint = Vector2.new(0.5, 0.5), Position = px(24, gh / 2 - 6) }).Parent = gift.Body
	else
		giftGlyph(gift.Body, 54, 36, px(24, gh / 2 - 6))
	end
	panel:SetAttribute('DesignW', w)
	panel:SetAttribute('DesignH', head + bodyH)
	return {
		Overlay = overlay, Fit = fitter, Panel = panel, Frame = frame, List = list, ListW = w - 2 * pad, CloseButton = close, GiftButton = gift, Title = title, Top = head,
		SetContent = function(height) contentH = height; placeThumb() end,
		SetBar = function(width) track.Size = px(width, trackH); list.ScrollBarThickness = width end,
	}
end
local Win = buildWindow()
local overlay, panel, list = Win.Overlay, Win.Panel, Win.List
overlay.Visible = false
local isOpen = false
local built, giftTarget, closePicker
---------------------------------------------------------------------------------------------- motion
-- Tasteful motion (the references' pops and stagger-ins), all TweenService and one shared Heartbeat: the window pops in
-- (0.9 > 1.03 > 1), a section's cards and title stagger in, the hero price buttons breathe (scale only, 3%), a slow soft
-- shine sweeps the Featured and BEST DEAL cards every few seconds, a new OWNED stamp pops. Nothing flashes.
local RunService = game:GetService('RunService')
local TweenService = game:GetService('TweenService')
local entrance, headers, breathers, shines, popOwned = {}, {}, {}, {}, {}
local curSection -- (the section build() is filling: cards register themselves for the stagger-in)
local breathConn
local function startBreath()
	if breathConn then return end
	local ok, conn = pcall(function()
		return RunService.Heartbeat:Connect(function()
			local k = 1 + 0.03 * (0.5 + 0.5 * math.sin(os.clock() * 2.4))
			for i = #breathers, 1, -1 do
				local s = breathers[i]
				if s.Parent then s.Scale = k else table.remove(breathers, i) end
			end
		end)
	end)
	if ok then breathConn = conn end
end
local function stopBreath()
	if breathConn then breathConn:Disconnect() end
	breathConn = nil
end
-- A soft diagonal band the shared loop (startTicker) sweeps across `body` every few seconds.
local function addShine(body)
	body.ClipsDescendants = true
	local band = Kit.new('Frame', { Name = 'Shine', BackgroundColor3 = Color.white, BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(-0.3, 0, 0.5, 0), Size = UDim2.new(0.14, 0, 2, 0), Rotation = 18, ZIndex = 58, Parent = body })
	Kit.new('UIGradient', { Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0.74), NumberSequenceKeypoint.new(1, 1) }), Parent = band })
	table.insert(shines, band)
end
-- The section a Store.Open(at) target belongs to ('Featured' by default).
local function sectionOf(at)
	if type(at) ~= 'string' then return 'Featured' end
	local e = Products.ByKey[at]
	if e then return e.Key == 'BlockParty' and 'Featured' or e.Section end
	return at
end
-- The stagger-in: the section's title slides in from the left, its cards rise and pop one after another.
local function animateIn(sectionId)
	local head = headers[sectionId]
	local text = head and head:FindFirstChild('Text')
	if text then
		local home = text.Position
		local stroke = text:FindFirstChildOfClass('UIStroke')
		text.Position = home - UDim2.fromOffset(80, 0)
		text.TextTransparency = 1
		if stroke then stroke.Transparency = 1 end
		Motion.tween(text, 0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out, { Position = home, TextTransparency = 0 })
		if stroke then Motion.tween(stroke, 0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, { Transparency = 0 }) end
	end
	local delay = 0.06
	for _, e in entrance do
		local c = e.Holder
		if e.Section == sectionId and c.Parent then
			if not e.Center then
				e.Center = c.Position + UDim2.fromOffset(c.Size.X.Offset / 2, c.Size.Y.Offset / 2)
				c.AnchorPoint = Vector2.new(0.5, 0.5)
			end
			c.Position = e.Center + UDim2.fromOffset(0, 28)
			local s = Motion.scaleOf(c)
			s.Scale = 0.01 -- (nothing to see until its turn: a TweenInfo delay, which also runs under the offline renderer's clock)
			TweenService:Create(c, TweenInfo.new(0.34, Enum.EasingStyle.Back, Enum.EasingDirection.Out, 0, false, delay), { Position = e.Center }):Play()
			TweenService:Create(s, TweenInfo.new(0.34, Enum.EasingStyle.Back, Enum.EasingDirection.Out, 0, false, delay), { Scale = 1 }):Play()
			delay = math.min(delay + 0.07, 0.6)
		end
	end
end
local function close()
	if not isOpen then return end
	isOpen = false
	stopBreath()
	if closePicker then closePicker() end
	coverPlayerList(false)
	Motion.blur(NAME, false)
	Motion.close(overlay, panel)
	if playerGui:GetAttribute('HoodWindow') == NAME then playerGui:SetAttribute('HoodWindow', '') end
end
local backdrop = Kit.new('TextButton', { Name = 'Backdrop', Text = '', AutoButtonColor = false, BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 20, Parent = overlay })
backdrop.Activated:Connect(close)
Kit.new('TextButton', { Name = 'Sink', Text = '', AutoButtonColor = false, BackgroundTransparency = 1, Position = px(0, Win.Top), Size = UDim2.new(1, 0, 1, -Win.Top), ZIndex = 21, Parent = panel })
Motion.button(Win.CloseButton, close)
playerGui:GetAttributeChangedSignal('HoodWindow'):Connect(function()
	if isOpen and playerGui:GetAttribute('HoodWindow') ~= NAME then close() end
end)
Kit.new('UIListLayout', { Padding = UDim.new(0, 0), SortOrder = Enum.SortOrder.LayoutOrder, HorizontalAlignment = Enum.HorizontalAlignment.Center, Parent = list })
Kit.new('UIPadding', { PaddingTop = UDim.new(0, 2), PaddingBottom = UDim.new(0, 16), Parent = list })

-- "Coming soon!" and friends: a big outlined line across the middle of the window for a moment.
local noticeHolder = Kit.new('Frame', { Name = 'Notice', BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.5, Win.Top / 2), Size = px(WIN.W - 40, 60), ZIndex = 60, Parent = panel })
local NOTICE = { green = hex('7CFF4F'), red = hex('FF6B6B'), blue = hex('5AE0FF') }
local noticeCount = 0
local function notice(text, tone)
	noticeCount += 1
	local mine = noticeCount
	for _, c in noticeHolder:GetChildren() do c:Destroy() end
	local b = Kit.new('Frame', { Name = 'Box', BackgroundColor3 = hex('0E1020'), BackgroundTransparency = 0.25, BorderSizePixel = 0, Size = UDim2.fromScale(1, 1), ZIndex = 61, Parent = noticeHolder })
	Kit.new('UIGradient', { Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.18, 0), NumberSequenceKeypoint.new(0.82, 0), NumberSequenceKeypoint.new(1, 1) }), Parent = b })
	label({ Name = 'Text', Text = text, TextSize = Kit.fitSize(text, 36, WIN.W - 80, 18), StrokeThickness = 5, TextColor3 = NOTICE[tone or 'blue'] or NOTICE.blue, Size = UDim2.fromScale(1, 1), ZIndex = 65, Parent = b })
	Motion.toast(b, 2.4)
	task.delay(2.9, function() if mine == noticeCount then for _, c in noticeHolder:GetChildren() do c:Destroy() end end end)
end

-- The server's clock (the same for everyone), else the device's: the Featured rotation and its countdown read it.
local function nowSec()
	local ok, t = pcall(function() return workspace:GetServerTimeNow() end)
	return (ok and type(t) == 'number' and t > 1e9) and math.floor(t) or os.time()
end
local function fmtLeft(s)
	s = math.max(0, math.floor(s))
	local d, h, m = s // 86400, (s % 86400) // 3600, (s % 3600) // 60
	if d > 0 then return string.format('%dd %dh %dm', d, h, m) end
	return string.format('%dh %02dm %02ds', h, m, s % 60)
end

---------------------------------------------------------------------------------------------- gifting + buying
-- Gift A Player: giftTarget = { UserId, Name, At } while a receiver is chosen (55 s: the server keeps a choice 60 s).
local GIFT_FRESH = 55
local rebuild -- (build, below)
local function giftActive()
	if giftTarget and (os.clock() - giftTarget.At > GIFT_FRESH or not Players:GetPlayerByUserId(giftTarget.UserId)) then giftTarget = nil end
	return giftTarget
end
local giftRemote
task.spawn(function()
	if not Net then return end
	local ok, r = pcall(Net.get, 'GiftTarget')
	if ok then giftRemote = r end
end)

local function buy(key)
	local entry = Products.ByKey[key]
	if not entry then return end
	if owns(entry) then
		notice('You own ' .. entry.Title .. '!', 'green')
		return
	end
	if not Products.canBuy(key) then
		notice(entry.Title .. ' is coming soon!', 'blue')
		return
	end
	-- (the weekly pack turned over while the window was open: show the new one instead of selling the old)
	if entry.Section == 'Featured' and Products.featuredAt(nowSec()) ~= key then
		notice('The Weekly Deal just changed!', 'blue')
		if built then rebuild() end
		return
	end
	local id = Products.idOf(key)
	-- a gift-able item: tell the server who gets it (or 0: nobody, clearing an old choice) BEFORE the prompt
	local gift = nil
	if Products.giftable(key) then
		gift = giftActive()
		if giftRemote then pcall(function() giftRemote:FireServer(gift and gift.UserId or 0, key) end) end
	end
	local ok = pcall(function()
		if entry.Kind == 'Pass' then
			MarketplaceService:PromptGamePassPurchase(player, id)
		else
			MarketplaceService:PromptProductPurchase(player, id)
		end
	end)
	if not ok then notice('The Store is busy, try again!', 'red') return end
	if gift then
		notice('Buying for ' .. gift.Name .. '!', 'green')
		giftTarget = nil -- (one gift a choice: the next purchase is yours again)
		task.delay(1, function() if isOpen and built then rebuild() end end)
	end
end

---------------------------------------------------------------------------------------------- art
-- Price buttons, live prices and owned passes. tone: the button's colour (the lime Robux button by default; blue while
-- gifting a gift-able item; the box bundles' rainbow and yellow).
local priceLabels = {} -- [key] = { label, ... }
-- opts: Was (a bundle's real one-by-one price: struck through inside the button, left of the price), TextSize.
local STRUCK = hex('DCDCE6') -- (light grey with a dark edge: readable on every button colour; the red strike over it)
local function priceButton(parent, entry, w, h, pos, anchor, z, tone, opts)
	opts = opts or {}
	if owns(entry) then
		local chip = Kit.block({ Name = 'Owned', Tone = OWNEDBTN, Width = w, Height = h, Studs = false, Outline = 3, RimWidth = 2, Radius = 6, OutlineColor = OWNEDBTN.stroke, Position = pos, AnchorPoint = anchor, ZIndex = z })
		label({ Name = 'Text', Text = 'OWNED', TextSize = math.floor(h * 0.5), Stroke = hex('3A3A24'), StrokeThickness = math.max(2.5, h * 0.075), Size = UDim2.fromScale(1, 1), ZIndex = z + 4, Parent = chip.Body })
		chip.Parent = parent
		-- (a pass just bought: the stamp pops in)
		if popOwned[entry.Key] then
			popOwned[entry.Key] = nil
			local sc = Motion.scaleOf(chip)
			sc.Scale = 1.6
			Motion.tween(sc, 0.42, Enum.EasingStyle.Back, Enum.EasingDirection.Out, { Scale = 1 })
		end
		return chip
	end
	tone = tone or ((Products.giftable(entry.Key) and giftActive()) and 'cardBlue') or LIMEBTN
	local holder, _, l = Kit.robuxButton({ Name = 'Buy', Tone = tone, Price = entry.Price, TextSize = opts.TextSize, Width = w, Height = h, Position = pos, AnchorPoint = anchor, Outline = 3, RimWidth = 2, Radius = 6, ZIndex = z })
	holder.Parent = parent
	if opts.Breathe then
		local bs = Kit.new('UIScale', { Name = 'Breathe', Parent = holder })
		table.insert(breathers, bs)
	end
	local row = holder.Body:FindFirstChild('Price')
	if opts.Was and row then
		local size = opts.WasSize or 22 -- (>= 14 dp on a phone, ~20 px on a PC)
		local text = tostring(opts.Was)
		local tw = Kit.textWidth(text, size)
		local total = tw + 6 + row.Size.X.Offset
		row.AnchorPoint = Vector2.new(0, 0.5)
		row.Position = UDim2.new(0.5, -total / 2 + tw + 6, 0.5, 0)
		local was = label({ Name = 'Was', Text = text, TextSize = size, TextColor3 = STRUCK, StrokeThickness = 2, AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0.5, -total / 2, 0.5, 0), Size = px(tw, size + 4), ZIndex = z + 5, Parent = holder.Body })
		local line = Kit.new('Frame', { Name = 'Strike', BackgroundColor3 = hex('FF2A2A'), BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(1, 4, 0, 2), Rotation = -10, ZIndex = z + 6, Parent = was })
		Kit.stroke(hex('3A0000'), 1, true, 0, Enum.LineJoinMode.Miter).Parent = line
	end
	priceLabels[entry.Key] = priceLabels[entry.Key] or {}
	table.insert(priceLabels[entry.Key], l)
	Motion.button(holder, function() buy(entry.Key) end)
	return holder
end
local livePrices = {}
local function fetchPrices()
	for _, entry in Products.Catalog do
		local id = Products.idOf(entry.Key)
		if id ~= 0 and livePrices[entry.Key] == nil then
			livePrices[entry.Key] = false
			task.spawn(function()
				local ok, info = pcall(function()
					return MarketplaceService:GetProductInfo(id, entry.Kind == 'Pass' and Enum.InfoType.GamePass or Enum.InfoType.Product)
				end)
				local price = ok and type(info) == 'table' and info.PriceInRobux
				if type(price) == 'number' then
					livePrices[entry.Key] = price
					for _, l in priceLabels[entry.Key] or {} do
						if l.Parent then l.Text = tostring(price) end
					end
				end
			end)
		end
	end
end
-- "SAVE n%" (brief 27, the lead): a bundle's real saving, Products.savings (from Count x the single price, or the sum of
-- the parts), never typed in. A yellow tag, white letters with a dark edge, 0.45 x a price button's height.
local function saveBadge(parent, key, pos, anchor, z)
	local _, pct = Products.savings(key)
	if not pct then return nil end
	local text = 'SAVE ' .. pct .. '%'
	local size = 22 -- (>= 12 dp on a phone)
	local b = Kit.new('Frame', { Name = 'Save', BackgroundColor3 = Color.white, BorderSizePixel = 0, AnchorPoint = anchor, Position = pos, Size = px(Kit.textWidth(text, size) + 8, 30), ZIndex = z, Parent = parent })
	Kit.corner(7).Parent = b
	Kit.stroke(hex('3A2400'), 2.5, true).Parent = b
	Kit.new('UIGradient', { Rotation = 90, Color = ColorSequence.new(hex('FFE04A'), hex('FFA61A')), Parent = b })
	label({ Name = 'Text', Text = text, TextSize = size, Stroke = hex('3A2400'), StrokeThickness = 2, Size = UDim2.fromScale(1, 1), ZIndex = z + 1, Parent = b })
	return b
end
-- Odds as people read them: "62%", "9.5%", "0.45%", "0.5%" (no trailing zeros).
local function pctText(chance)
	local t = string.format('%.2f', tonumber(chance) or 0)
	t = string.gsub(t, '0+$', '')
	t = string.gsub(t, '%.$', '')
	return t .. '%'
end

---------------------------------------------------------------------------------------------- cards
-- The reference's cards: a saturated fill with a faint stud pattern and a thin dark outline, big art over the edge, titles
-- white with a dark edge in the card's own colour, the lime price button at the bottom.
local LW = Win.ListW -- the list's content width
local MARGIN, GAP = 12, 8
local CW = LW - 2 * MARGIN -- a full-width card
local THIRD = math.floor((CW - 2 * GAP) / 3)
local HALF = math.floor((CW - GAP) / 2)
local BTN_H = 58 -- (>= 36 px on a phone's screen)
local function card(entry, tone, w, h, x, y, parent)
	local c = Kit.block({ Name = entry.Key or 'Card', Tone = tone, Width = w, Height = h, Position = px(x, y), Outline = 3, Radius = 5, RimWidth = 2, Studs = 26, StudSparse = true, StudShade = 0.55, ZIndex = 25 })
	c.Parent = parent
	if curSection and curSection ~= 'Box' then table.insert(entrance, { Holder = c, Section = curSection }) end
	return c
end
local function title(parent, text, size, tone, props)
	props = props or {}
	local t = label({ Name = props.Name or 'Title', Text = text, TextSize = Kit.fitSize(text, size, props.Width or 300, props.Min or 14), Stroke = Kit.toneOf(tone).stroke or BLACK, StrokeThickness = math.max(3, size * 0.11),
		TextXAlignment = props.Align or Enum.TextXAlignment.Center, AnchorPoint = props.Anchor or Vector2.new(0.5, 0), Position = props.Position, Size = px(props.Width or 300, size + 8), ZIndex = props.ZIndex or 31, Parent = parent })
	return t
end
-- Every picture slot asks for its own key (icon:<Name>), so a picture dropped in under that name is used at once; until it is
-- uploaded the nearest existing picture stands in.
local ICON_FALLBACK = { CashBig = 'CashMedium', CashMega = 'CashLarge', PowerBig = 'PowerMedium', PowerMega = 'PowerLarge', Speed2x = 'Arrow', AutoOpen = 'TripleOpen', ServerBoost = 'BlockParty' }
local function iconId(entry, fallback)
	local id = (entry.Art or ''):match('^icon:(.+)$') or fallback or 'Shop'
	if id == 'Power' then id = iconOr('Muscle', 'Power') end
	return iconOr(id, ICON_FALLBACK[id] or fallback or 'Shop')
end

local sections = {} -- [section id, catalog key or box id] = the Frame to scroll to
local function sectionTitle(text, order)
	local f = Kit.new('Frame', { Name = 'Title_' .. text, BackgroundTransparency = 1, Size = px(LW, 50), LayoutOrder = order, ZIndex = 24 })
	label({ Name = 'Text', Text = string.upper(text), TextSize = 32, StrokeThickness = 4.5, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.5, 2), Size = UDim2.new(1, 0, 0, 44), ZIndex = 25, Parent = f })
	return f
end
-- Exclusive: one card per Robux box (video A's egg card). The 3D box, the whole model, fills the card's left part and
-- stands up to BOX_POP px over its top edge (the first one into the section title's room, the next over the gap and the
-- card above's bottom border, as video A's egg does); the shoes (real 3D pairs, one shared viewport, centred on their
-- rarity splats) with their true chances; the x8 / x3 / x1 buttons, biggest first, each bundle with its real
-- one-by-one price struck through inside the button and its "SAVE n%".
local BOX_H, BOX_POP, BOX_GAP = 290, 28, 14
local BOX_FOOT = 11 -- (px kept clear under the box: it stands on its card, not on the card's bottom border)
local BUNDLE_TONE = { [8] = 'rainbow', [3] = 'gold' } -- (x1: the green Robux button)
local function boxTone(first)
	return first.Tone == 'cardPurple' and 'storeMagenta' or 'storeBlue'
end
local function chanceColor(shoe)
	local r = Shoes and Shoes.RarityById and shoe and Shoes.RarityById[shoe.Rarity]
	return r and r.Color or Color.white
end
-- A splat centred under an item (its cloud ~1.15x the item: the texture's cloud is ~72% of its square, centred at 0.52 /
-- 0.46 of it).
local function itemSplat(parent, cx, cy, itemW, color, kind, rot, z, on)
	local size = math.floor(itemW * 1.15 / 0.72 + 0.5)
	local sp = Kit.splat(size, color, { Kind = kind, On = on, AnchorPoint = Vector2.new(0.5, 0.5), Position = px(cx - 0.02 * size, cy + 0.04 * size), Rotation = rot or 0, ZIndex = z })
	sp.Parent = parent
	return sp
end
-- over: the box cards' top layer (their buttons, counts and SAVE badges), drawn over every box card, so a box standing
-- over the card above (its halo, its wings) always stays under that card's buttons.
local function boxCard(rows, y, parent, over)
	local first = rows[1]
	local boxId = first.Box or (first.Art or ''):match('^box:(.+)$') or ''
	local box = Shoes and Shoes.BoxById and Shoes.BoxById[boxId]
	local tone = boxTone(first)
	local c = card({ Key = 'Box_' .. boxId }, tone, CW, BOX_H, MARGIN, y, parent)
	local z = 28
	local left = math.floor(CW * 0.38) -- (the box's side of the card)
	-- the real box, the WHOLE model (topper and sparkles too) framed to fill the card's left part and BOX_POP over it,
	-- BOX_FOOT clear of its bottom: nothing is cut. Its camera looks down a little more (24 degrees) and nearly flat-on
	-- (FOV 14), so a halo on top reads as a ring, not a bar.
	local art = Kit.model3d('box', boxId, Vector2.new(left, BOX_H + BOX_POP - BOX_FOOT), { ZIndex = z, Whole = true, Fill = 0.99, MaxReach = 0.99, Overflow = 1, Pitch = 24, Fov = 14, Priority = 5, PreviewKind = 'boxhero' })
	art.Position = px(-3, -BOX_POP - 3)
	art.Parent = c.Body
	local artHit = Kit.new('TextButton', { Name = 'ArtHit', Text = '', AutoButtonColor = false, BackgroundTransparency = 1, Size = px(left, BOX_H), ZIndex = 34, Parent = c.Body })
	Kit.model3dHover(art, artHit)
	artHit.Activated:Connect(function()
		Kit.model3dActive(art, 'tap', true)
		task.delay(2, function() Kit.model3dActive(art, 'tap', false) end)
	end)
	local right = CW - left - 14
	local t = title(c.Body, (box and box.Name) or first.Title, 40, tone, { Position = px(left + right / 2, 2), Width = right })
	if tone == 'storeMagenta' then gradient(t, hex('FFF6B0'), hex('F8CF4A')) end
	-- the odds row: every shoe of the box, rarest last, with its chance
	if box and type(box.Shoes) == 'table' then
		local n = #box.Shoes
		local pitch = right / n
		local cell = math.min(100, math.floor(pitch) + 6)
		local items = {}
		for _, sid in box.Shoes do
			local shoe = Shoes.ById and Shoes.ById[sid]
			table.insert(items, { Id = sid, Rarity = shoe and shoe.Rarity })
		end
		local cy = 102
		local tagsShown = 0 -- (how many of the row's name tags show: the title hides while any does)
		local models = Kit.model3dRow('shoe', items, cell, pitch, { ZIndex = z + 1, Position = px(left + pitch / 2 - cell / 2, cy - cell / 2), Priority = 4 })
		models.Parent = c.Body
		for i, sid in box.Shoes do
			local shoe = Shoes.ById and Shoes.ById[sid]
			local secret = shoe and shoe.Rank == #(Shoes.Rarities or {})
			local cx = left + (i - 0.5) * pitch
			itemSplat(c.Body, cx, cy, cell * Kit.Studio.shoe.Fill, chanceColor(shoe):Lerp(Kit.toneOf(tone).base, 0.15), secret and 'rainbow' or nil, (i * 37) % 360, z, Kit.toneOf(tone).base)
			local hit = Kit.new('TextButton', { Name = 'Hit_' .. sid, Text = '', AutoButtonColor = false, BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = px(cx, cy + 12), Size = px(pitch, cell + 24), ZIndex = 34, Parent = c.Body })
			Kit.model3dItemHover(models, i, hit)
			local chance = type(box.Chances) == 'table' and box.Chances[i]
			if chance then
				local cl = label({ Name = 'Chance' .. i, Text = pctText(chance), TextSize = 22, StrokeThickness = 3.5, TextColor3 = secret and Color.white or chanceColor(shoe):Lerp(Color.white, 0.25), AnchorPoint = Vector2.new(0.5, 0.5), Position = px(cx, 152), Size = px(pitch + 10, 28), ZIndex = z + 3, Parent = c.Body })
				if secret then Kit.new('UIGradient', { Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, hex('FF5A7A')), ColorSequenceKeypoint.new(0.35, hex('FFE24A')), ColorSequenceKeypoint.new(0.65, hex('5AE07A')), ColorSequenceKeypoint.new(1, hex('5AB8FF')) }), Parent = cl }) end
			end
			-- the name, while the pointer is on it (brief 28: over the box's title, which steps aside meanwhile, so the two
			-- never overlap)
			local tag = label({ Name = 'NameTag', Text = shoe and shoe.Name or sid, TextSize = 18, StrokeThickness = 2.5, AnchorPoint = Vector2.new(0.5, 1), Position = px(cx, 44), Size = px(160, 22), ZIndex = 40, Parent = c.Body })
			tag.Visible = false
			local function show(on)
				if tag.Visible == on then return end
				tag.Visible = on
				tagsShown = math.max(0, tagsShown + (on and 1 or -1))
				t.Visible = tagsShown == 0
			end
			hit.MouseEnter:Connect(function() show(true) end)
			hit.MouseLeave:Connect(function() show(false) end)
			hit.Activated:Connect(function()
				show(true)
				Kit.model3dItemActive(models, i, 'tap', true)
				task.delay(1.6, function()
					if tag.Parent then show(false) end
					Kit.model3dItemActive(models, i, 'tap', false)
				end)
			end)
		end
	end
	-- the buttons: x8 | x3 | x1 (rainbow, yellow, green); over each, its count and (a bundle) "SAVE n%"; inside a bundle's
	-- button, its real one-by-one price struck through
	table.sort(rows, function(a, b) return (a.Count or 1) > (b.Count or 1) end)
	local gap = 8
	-- (the single box's button is narrower: the bundles' get room for their count, SAVE badge and struck price)
	local single = #rows > 1 and 96 or nil
	local bundles = #rows - (single and 1 or 0)
	local bw = math.floor((right - (#rows - 1) * gap - (single or 0)) / math.max(1, bundles))
	local by = BOX_H - BTN_H - 10
	-- (on the top layer, at this card's body's place in it)
	local layer = over or c.Body
	local ox, oy = 0, 0
	if over then ox, oy = MARGIN + c.Body.Position.X.Offset, y + c.Body.Position.Y.Offset end
	local x = left
	for _, r in ipairs(rows) do
		local count = r.Count or 1
		local w = (count == 1 and single) or bw
		local whole = Products.savings(r.Key)
		priceButton(layer, r, w, BTN_H, px(ox + x, oy + by), Vector2.zero, z + 2, BUNDLE_TONE[count], { Was = whole, TextSize = 28 })
		label({ Name = 'Count' .. count, Text = 'x' .. count, TextSize = 24, StrokeThickness = 3.5, TextXAlignment = Enum.TextXAlignment.Left, AnchorPoint = Vector2.new(0, 0.5), Position = px(ox + x, oy + by - 17), Size = px(50, 30), ZIndex = z + 6, Parent = layer })
		saveBadge(layer, r.Key, px(ox + x + w, oy + by - 17), Vector2.new(1, 0.5), z + 6)
		sections[r.Key] = c
		x += w + gap
	end
	return c
end

-- The small purple "Info" tab (the reference's, on the card's top-left) and its short description popover.
local function infoTab(c, text, x, y, z, right)
	local pop
	local tab = Kit.blockButton({ Name = 'Info', Tone = 'purple', Width = 56, Height = 22, Text = 'Info', TextSize = 15, Studs = false, Outline = 2.5, RimWidth = 2, Radius = 5, Position = px(x, y), ZIndex = z })
	tab.Parent = c.Body
	local shown = 0
	Motion.button(tab, function()
		if pop and pop.Parent then pop:Destroy() pop = nil return end
		pop = Kit.block({ Name = 'InfoPopover', Tone = 'dark', Width = 232, Height = 82, Studs = false, Outline = 3, RimWidth = 2, Radius = 8, Position = px(right and (x + 56 - 232) or x, y + 28), ZIndex = z + 20 })
		pop.Parent = c.Body
		label({ Name = 'Text', Text = text, FontFace = Kit.Font.body, TextSize = 16, Stroke = hex('0E1020'), StrokeThickness = 2, TextWrapped = true, Size = UDim2.new(1, -16, 1, -8), Position = px(8, 4), ZIndex = z + 26, Parent = pop.Body })
		Motion.pop(pop, 0.12)
		shown += 1
		local mine = shown
		task.delay(4.5, function() if pop and pop.Parent and mine == shown then pop:Destroy() pop = nil end end)
	end)
	return tab
end

-- A pass card (the reference's pass grid): a BIG glossy icon at the left that overflows the card, the heavily outlined title,
-- a 2-line white outlined description, the purple Info tab, and OWNED (yellow) or the price at the bottom right.
local HALF_H = 156
local PASS_TONES = { 'cardRed', 'cardGold', 'cardBlue', 'cardGreen', 'cardPurple' }
local function passCard(entry, x, y, parent, tone, opts)
	opts = opts or {}
	local c = card(entry, tone, HALF, HALF_H, x, y, parent)
	local z = 28
	local art = Kit.icon3d(iconId(entry), 178, { ZIndex = z, AnchorPoint = Vector2.new(0.5, 0.5), Position = px(76, HALF_H / 2 - 2) })
	art.Parent = c.Body
	local ax, aw = 146, HALF - 146 - 12
	local ink = Kit.toneOf(tone).stroke
	local t = title(c.Body, entry.Title, 32, tone, { Position = px(ax + aw / 2, 8), Width = aw })
	t.UIStroke.Thickness = math.max(4, t.TextSize * 0.17)
	label({ Name = 'Desc', Text = entry.Detail or entry.Sub or '', FontFace = Kit.Font.body, TextSize = (#(entry.Detail or entry.Sub or '') > 34) and 16 or 19, StrokeThickness = 3, Stroke = ink, TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top,
		AnchorPoint = Vector2.new(0.5, 0), Position = px(ax + aw / 2, 46), Size = px(aw, 50), ZIndex = z + 2, Parent = c.Body })
	priceButton(c.Body, entry, math.min(aw, 190), 42, px(ax + aw / 2, HALF_H - 10), Vector2.new(0.5, 1), z + 2, nil, opts.Was and { Was = opts.Was, TextSize = 24 } or nil)
	infoTab(c, (entry.Info or entry.Detail or '') .. (entry.Kind == 'Pass' and ' Yours forever!' or ''), 8, 6, z + 4)
	return c
end

-- Packs (Cash, Power): the amount is the big gold number (live: it follows your best stage / your next rebirth).
local packLabels = {} -- [key] = TextLabel
local function amountText(entry)
	-- (brief 29, P5) Power packs give the larger of the rebirth-based amount and a share of the Power you hold; Cash packs
	-- scale with your best stage. The same Products functions the server grants with.
	if entry.Section == 'Power' then return '+' .. short(Products.powerAmount(entry.Key, rebirthNeed(), num('Power', 0))) end
	return short(Products.cashAmount(entry.Key, num('StagesCleared', 1)))
end
local PACK_H = 170
local PACK_TONE = { Cash = LIME, Power = Kit.Tone.packOrange }
local GOLD_TOP, GOLD_BOTTOM = hex('FFF08A'), hex('FFAA1E')
local function packCard(entry, x, y, w, h, parent, mode)
	local section = entry.Section
	local tone = PACK_TONE[section]
	local c = card(entry, tone, w, h, x, y, parent)
	local z = 28
	local tall, wide = mode == 'tall', mode == 'wide'
	title(c.Body, tall and 'MEGA PACK' or entry.Title, tall and 32 or 26, tone, { Align = Enum.TextXAlignment.Left, Anchor = Vector2.zero, Position = px(10, 6), Width = w - 20 })
	local size = tall and 250 or (wide and 200 or 160)
	local art = Kit.icon3d(iconId(entry, section == 'Power' and 'Muscle' or 'Cash'), size, { ZIndex = z, AnchorPoint = Vector2.new(0.5, 0.5),
		Position = tall and px(w / 2, h - 140) or (wide and px(98, h / 2 - 2) or px(66, h / 2 - 6)) })
	art.Parent = c.Body
	local sz = tall and 58 or (wide and 56 or 40)
	local amount = label({ Name = 'Amount', Text = amountText(entry), TextSize = Kit.fitSize(amountText(entry), sz, tall and w - 20 or (w - 100), 20), TextColor3 = Color.white, Stroke = hex('5A2E00'), StrokeThickness = math.max(3.5, sz * 0.13),
		TextXAlignment = tall and Enum.TextXAlignment.Center or Enum.TextXAlignment.Right, AnchorPoint = tall and Vector2.new(0.5, 0) or Vector2.new(1, 0.5),
		Position = tall and px(w / 2, 100) or px(w - 12, wide and 66 or 70), Size = px(tall and w - 20 or (w - 100), sz + 8), ZIndex = z + 3, Parent = c.Body })
	Kit.new('UIGradient', { Rotation = 90, Color = ColorSequence.new(GOLD_TOP, GOLD_BOTTOM), Parent = amount })
	packLabels[entry.Key] = amount
	if section == 'Power' then
		label({ Name = 'Unit', Text = 'POWER', TextSize = 18, StrokeThickness = 3, Stroke = tone.stroke, TextXAlignment = tall and Enum.TextXAlignment.Center or Enum.TextXAlignment.Right, AnchorPoint = tall and Vector2.new(0.5, 0) or Vector2.new(1, 0.5),
			Position = tall and px(w / 2, 88 + sz + 6) or px(w - 14, (wide and 66 or 70) + sz * 0.5 + 8), Size = px(120, 22), ZIndex = z + 3, Parent = c.Body })
	end
	if tall then
		-- the "BEST DEAL" ribbon: it really is the most Cash / Power per Robux of the four (the packs' own prices)
		-- the reference's angled ribbon: a red-orange band with notched tails, "BEST VALUE" (BEST DEAL only beside a real was-price)
		local word = entry.WasPrice and 'BEST DEAL' or 'BEST VALUE'
		local rib = Kit.new('Frame', { Name = 'Ribbon', BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = px(w / 2, 62), Size = px(w - 6, 40), Rotation = -7, ZIndex = z + 5, Parent = c.Body })
		for _, side in { -1, 1 } do
			local tail = Kit.new('Frame', { Name = 'Tail', BackgroundColor3 = hex('A82A10'), BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(side < 0 and 0 or 1, side < 0 and 4 or -4, 0.5, 6), Size = px(26, 26), Rotation = 45, ZIndex = z + 4, Parent = rib })
			Kit.stroke(hex('3A0A00'), 2.5, true).Parent = tail
		end
		local band = Kit.new('Frame', { Name = 'Band', BackgroundColor3 = Color.white, BorderSizePixel = 0, Size = UDim2.new(1, -16, 0, 32), Position = px(8, 4), ZIndex = z + 5, Parent = rib })
		Kit.corner(3).Parent = band
		Kit.stroke(hex('3A0A00'), 3, true).Parent = band
		Kit.new('UIGradient', { Rotation = 90, Color = ColorSequence.new(hex('FF7A52'), hex('E02A1A')), Parent = band })
		label({ Name = 'Text', Text = word, TextSize = 22, Stroke = hex('5A0A00'), StrokeThickness = 3, Size = UDim2.fromScale(1, 1), ZIndex = z + 8, Parent = band })
		addShine(c.Body)
	end
	local whole = entry.WasPrice -- (a struck-through price only where Products has a real one: the reference's red price over the button)
	local bw = tall and w - 24 or (wide and 240 or w - 26)
	local bh = tall and 50 or 42
	if whole then
		local wl = label({ Name = 'Was', Text = tostring(whole), TextSize = 22, TextColor3 = hex('FF5A5A'), Stroke = hex('4A0000'), StrokeThickness = 2.5, TextXAlignment = Enum.TextXAlignment.Right, AnchorPoint = Vector2.new(1, 1),
			Position = px(w - 18, h - 10 - bh - 4), Size = px(120, 26), ZIndex = z + 5, Parent = c.Body })
		Kit.robux(18, { Color = hex('FF5A5A'), Inner = hex('FF5A5A'), Core = hex('4A0000'), Edge = hex('4A0000'), AnchorPoint = Vector2.new(1, 0.5), Position = px(w - 18 - Kit.textWidth(tostring(whole), 22) - 4, h - 10 - bh - 17), ZIndex = z + 5 }).Parent = c.Body
		local line = Kit.new('Frame', { Name = 'Strike', BackgroundColor3 = hex('FF2A2A'), BorderSizePixel = 0, AnchorPoint = Vector2.new(1, 0.5), Position = px(w - 16, h - 10 - bh - 17), Size = px(Kit.textWidth(tostring(whole), 22) + 30, 3), Rotation = -6, ZIndex = z + 6, Parent = c.Body })
		Kit.stroke(hex('3A0000'), 1, true).Parent = line
	end
	priceButton(c.Body, entry, bw, bh, px(w / 2, h - 10), Vector2.new(0.5, 1), z + 5, nil, { TextSize = tall and 30 or nil, Breathe = tall })
	return c
end
-- The pack grid, the reference's 3 columns: two normal cards and the tall MEGA card (spanning 2 rows) on the right, again two
-- normals under the first two, and the fifth across the full width; any other count falls back to small cards, 3 to a row.
local function packGrid(items, y, block)
	local xs = { MARGIN, MARGIN + THIRD + GAP, MARGIN + 2 * (THIRD + GAP) }
	if #items == 6 then
		sections[items[1].Key] = packCard(items[1], xs[1], y, THIRD, PACK_H, block, 'small')
		sections[items[2].Key] = packCard(items[2], xs[2], y, THIRD, PACK_H, block, 'small')
		sections[items[3].Key] = packCard(items[3], xs[1], y + PACK_H + GAP, THIRD, PACK_H, block, 'small')
		sections[items[4].Key] = packCard(items[4], xs[2], y + PACK_H + GAP, THIRD, PACK_H, block, 'small')
		sections[items[6].Key] = packCard(items[6], xs[3], y, THIRD, 2 * PACK_H + GAP, block, 'tall')
		sections[items[5].Key] = packCard(items[5], xs[1], y + 2 * (PACK_H + GAP), CW, PACK_H - 8, block, 'wide')
		return 3 * PACK_H - 8 + 2 * GAP
	end
	local rows = 0
	for i, entry in items do
		local col, row = (i - 1) % 3, (i - 1) // 3
		sections[entry.Key] = packCard(entry, xs[col + 1], y + row * (PACK_H + GAP), THIRD, PACK_H, block, 'small')
		rows = row + 1
	end
	return rows * PACK_H + (rows - 1) * GAP
end

-- FEATURED: the week's pack (painted card, three item tiles with blue value chips, a big price button, the real countdown)
-- and the Server Boost card.
local FEAT_H, SERVER_H = 196, 150
local CREAM = hex('FFF6C8') -- (the reference's Server Luck lettering is cream, not white, with a mid-green edge)
local LETTER_EDGE = hex('3F7A10')
local CHIP_BLUE = { top = hex('3E86E8'), base = hex('1F58BC'), lip = hex('1A4AA0'), stroke = hex('08205C'), rim = hex('86BCF6') }
local THEMES = {
	FeaturedPack1 = { Id = 'Street', Sky = { hex('2E1A6E'), hex('FF8A3C') }, Ink = hex('2A0B4E'), Sub = hex('FFE27A') },
	FeaturedPack2 = { Id = 'Grail', Sky = { hex('72B8FF'), hex('FFF4D6') }, Ink = hex('1F3F8A'), Sub = hex('FFD34A') },
	FeaturedPack3 = { Id = 'Sneaker', Sky = { hex('7EC4FF'), hex('E4F2FF') }, Ink = hex('0E3A7A'), Sub = hex('FFE27A') },
}
local function blob(parent, x, y, w, h, color, tr, round)
	local f = Kit.new('Frame', { BackgroundColor3 = color, BackgroundTransparency = tr or 0, BorderSizePixel = 0, Position = px(x, y), Size = px(w, h), ZIndex = 26, Parent = parent })
	if round then Kit.corner(UDim.new(0.5, 0)).Parent = f end
	return f
end
-- The painting behind the pack: flat shapes only (clouds, gates, towers, coins) on the theme's sky gradient.
local function paintTheme(body, theme, w, h)
	body.ClipsDescendants = true
	local white, gold = Color.white, hex('F6C84A')
	if theme == 'Grail' then
		Kit.sunburst(300, { ZIndex = 26, Alpha = 0.3, AnchorPoint = Vector2.new(0.5, 0.5), Position = px(w * 0.5, h * 0.55) }).Parent = body
		for _, p in { { 10, h - 52, 150, 56 }, { 70, h - 70, 110, 62 }, { w * 0.4, h - 40, 170, 50 }, { w * 0.58, h - 62, 120, 60 }, { w - 190, h - 48, 160, 54 } } do blob(body, p[1], p[2], p[3], p[4], white, 0.05, true) end
		blob(body, w * 0.18, 18, 120, 120, hex('FFF6D0'), 0.55, true)
		blob(body, w * 0.62, 6, 160, 160, hex('FFF6D0'), 0.6, true)
	elseif theme == 'Street' then
		blob(body, w * 0.86, 22, 46, 46, hex('FFF2C0'), 0, true)
		for i, p in { { 0, 90 }, { 70, 60 }, { 140, 100 }, { 220, 74 }, { 300, 112 }, { 380, 66 }, { 450, 96 }, { 540, 70 } } do
			blob(body, p[1], h - p[2], 62, p[2], hex('1E1040'), 0.1)
			for r = 0, 2 do blob(body, p[1] + 12, h - p[2] + 12 + r * 18, 8, 8, hex('FFD84A'), i % 2 == 0 and 0.2 or 0.6) end
		end
	else
		-- Sneaker: a bright shop wall, two shelves of colourful shoe boxes
		for r = 0, 1 do
			blob(body, 0, h - 62 - r * 70, w, 8, hex('B07A44'))
			for k = 0, 11 do
				local col = ({ hex('E8303A'), hex('2A86E6'), hex('FF9A1F'), hex('43C24A'), hex('A64DFF'), hex('FFE04A') })[(k + r * 2) % 6 + 1]
				blob(body, 12 + k * 64 + (r % 2) * 30, h - 100 - r * 70, 46, 38, col)
				blob(body, 8 + k * 64 + (r % 2) * 30, h - 108 - r * 70, 54, 10, hex('FFFFFF'), 0.35)
			end
		end
	end
end
local countdownLabel, partyLine, shownFeatured
local function tile(parent, cx, cy, icon, chip, z)
	-- (the reference sits each item on a soft glow circle)
	blob(parent, cx - 54, cy - 54, 108, 108, Color.white, 0.82, true).ZIndex = z - 2
	blob(parent, cx - 38, cy - 38, 76, 76, Color.white, 0.7, true).ZIndex = z - 1
	Kit.icon3d(icon, 76, { ZIndex = z, AnchorPoint = Vector2.new(0.5, 0.5), Position = px(cx, cy) }).Parent = parent
	local cw = math.max(76, Kit.textWidth(chip, 18) + 18)
	local ch = Kit.block({ Name = 'Chip', Tone = CHIP_BLUE, Width = cw, Height = 28, Studs = false, Outline = 2.5, RimWidth = 2, Radius = 6, OutlineColor = hex('08205C'), Position = px(cx, cy + 50), AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = z + 1 })
	label({ Name = 'Text', Text = chip, TextSize = 19, Stroke = hex('08205C'), Size = UDim2.fromScale(1, 1), ZIndex = z + 6, Parent = ch.Body })
	ch.Parent = parent
end
local function featuredCard(key, y, parent)
	local entry = Products.ByKey[key]
	local th = THEMES[key] or THEMES.FeaturedPack1
	local tone = { top = th.Sky[1], base = th.Sky[2], lip = th.Sky[2], stroke = th.Ink, rim = Color.white }
	local c = Kit.block({ Name = key, Tone = tone, Width = CW, Height = FEAT_H, Position = px(MARGIN, y), Outline = 3, Radius = 5, RimWidth = 2, Studs = false, ZIndex = 25 })
	c.Parent = parent
	table.insert(entrance, { Holder = c, Section = 'Featured' })
	-- the picture FeaturedBg_<Theme> (an AI picture or the Blender render, once uploaded), else the flat painting
	local bgId = 'FeaturedBg_' .. th.Id
	if Kit.iconImage(bgId) ~= '' then
		c.Body.ClipsDescendants = true
		local bg = Kit.new('ImageLabel', { Name = 'Background', BackgroundTransparency = 1, Image = Kit.iconImage(bgId), ScaleType = Enum.ScaleType.Crop, Size = UDim2.fromScale(1, 1), ZIndex = 26, Parent = c.Body })
		bg:SetAttribute('PreviewImage', 'icon3d:' .. bgId)
		Kit.corner(4).Parent = bg
	else
		paintTheme(c.Body, th.Id, CW - 6, FEAT_H - 6)
	end
	local z = 30
	local t = title(c.Body, entry.Title, 38, tone, { Align = Enum.TextXAlignment.Left, Anchor = Vector2.zero, Position = px(16, 8), Width = 280 })
	t.Size = px(Kit.textWidth(entry.Title, t.TextSize) + 6, 46)
	-- the red pill: it is honest, the pack really changes every week
	local pill = Kit.block({ Name = 'Pill', Tone = 'cardRed', Width = 138, Height = 30, Studs = false, Outline = 2.5, RimWidth = 2, Radius = 15, Position = px(16 + t.Size.X.Offset + 10, 18), ZIndex = z })
	pill.Parent = c.Body
	label({ Name = 'Text', Text = 'Weekly Deal!', TextSize = 17, Stroke = Kit.Tone.cardRed.stroke, Size = UDim2.fromScale(1, 1), ZIndex = z + 5, Parent = pill.Body })
	label({ Name = 'Sub', Text = entry.Sub or '', TextSize = 22, TextColor3 = th.Sub, Stroke = th.Ink, StrokeThickness = 3, TextXAlignment = Enum.TextXAlignment.Left, Position = px(18, 56), Size = px(320, 28), ZIndex = z, Parent = c.Body })
	-- the three parts: Cash (live: it scales with your best stage), the boost, the box
	local stage = num('StagesCleared', 1)
	local parts = {
		{ iconOr('CashMedium', 'Cash'), '+' .. short(Products.cashAmount(key, stage)) },
		{ iconOr(entry.Boost == 3 and 'PotionGold' or 'PotionRed', 'Power'), entry.Boost .. 'x Power' },
		{ iconOr('Box_' .. entry.Box, 'ShoeBox'), 'x' .. (entry.Count or 1) .. ' Box' },
	}
	for i, p in parts do tile(c.Body, 124 + (i - 1) * 138, 124, p[1], p[2], z) end
	-- the countdown to the next pack: this is real (Products.featuredAt)
	local _, left = Products.featuredAt(nowSec())
	-- (the reference's chip: a translucent grey pill, a green clock, white outlined numbers)
	local chip = Kit.new('Frame', { Name = 'Countdown', BackgroundColor3 = hex('5A5A68'), BackgroundTransparency = 0.35, BorderSizePixel = 0, AnchorPoint = Vector2.new(1, 0), Position = px(CW - 14, 10), Size = px(196, 32), ZIndex = z, Parent = c.Body })
	Kit.corner(16).Parent = chip
	local clock = Kit.new('Frame', { Name = 'Clock', BackgroundColor3 = hex('58D24A'), BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 0.5), Position = px(20, 16), Size = px(22, 22), ZIndex = z + 1, Parent = chip })
	Kit.corner(UDim.new(0.5, 0)).Parent = clock
	Kit.stroke(hex('1B4A00'), 2, true).Parent = clock
	Kit.new('Frame', { Name = 'HandA', BackgroundColor3 = Color.white, BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 1), Position = px(11, 11), Size = px(3, 8), ZIndex = z + 2, Parent = clock })
	Kit.new('Frame', { Name = 'HandB', BackgroundColor3 = Color.white, BorderSizePixel = 0, AnchorPoint = Vector2.new(0, 0.5), Position = px(11, 11), Size = px(7, 3), ZIndex = z + 2, Parent = clock })
	countdownLabel = label({ Name = 'Time', Text = fmtLeft(left), TextSize = 19, StrokeThickness = 3, Stroke = hex('1E1E26'), TextXAlignment = Enum.TextXAlignment.Right, Position = px(-12, 0), Size = UDim2.new(1, 0, 1, 0), ZIndex = z + 1, Parent = chip })
	addShine(c.Body)
	priceButton(c.Body, entry, 200, 76, px(CW - 14, FEAT_H - 20), Vector2.new(1, 1), z + 2, nil, { TextSize = 40, Breathe = true })
	shownFeatured = key
	return c
end
local function serverCard(entry, y, parent)
	local c = card(entry, LIME, CW, SERVER_H, MARGIN, y, parent)
	local z = 28
	addShine(c.Body)
	Kit.icon3d(iconOr('ServerBoost', iconId(entry)), 172, { ZIndex = z, AnchorPoint = Vector2.new(0.5, 0.5), Position = px(88, SERVER_H / 2) }).Parent = c.Body
	local mid = 372
	local st = title(c.Body, 'Server Boost', 46, LIME, { Position = px(mid, 2), Width = 330 })
	st.TextColor3 = CREAM
	st.UIStroke.Color = LETTER_EDGE
	-- "1x > 2x": the whole server's Power really doubles
	local row = Kit.new('Frame', { Name = 'Multi', BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0), Position = px(mid, 54), Size = px(240, 44), ZIndex = z + 2, Parent = c.Body })
	label({ Name = 'From', Text = '1x', TextColor3 = CREAM, TextSize = 44, StrokeThickness = 4.5, Stroke = LETTER_EDGE, Position = px(0, 0), Size = px(80, 44), ZIndex = z + 3, Parent = row })
	local arrow = Kit.new('Frame', { Name = 'Arrow', BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = px(120, 22), Size = px(40, 30), ZIndex = z + 3, Parent = row })
	local function bar(name, x, y, w, rot)
		local f = Kit.new('Frame', { Name = name, BackgroundColor3 = CREAM, BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 0.5), Position = px(x, y), Size = px(w, 7), Rotation = rot, ZIndex = z + 3, Parent = arrow })
		Kit.corner(3).Parent = f
		Kit.stroke(LETTER_EDGE, 2, true).Parent = f
	end
	bar('Shaft', 17, 15, 32, 0)
	bar('HeadA', 29, 9.5, 18, 42)
	bar('HeadB', 29, 20.5, 18, -42)
	local to = label({ Name = 'To', Text = '2x', TextSize = 48, StrokeThickness = 4.5, Stroke = LETTER_EDGE, Position = px(160, 0), Size = px(80, 44), ZIndex = z + 3, Parent = row })
	Kit.new('UIGradient', { Rotation = 90, Color = ColorSequence.new(GOLD_TOP, GOLD_BOTTOM), Parent = to })
	partyLine = label({ Name = 'Minutes', Text = '+15 minutes', TextColor3 = CREAM, TextSize = 28, StrokeThickness = 3.5, Stroke = LETTER_EDGE, Position = px(mid - 160, 102), Size = px(320, 32), ZIndex = z + 2, Parent = c.Body })
	priceButton(c.Body, entry, 184, 64, px(CW - 16, SERVER_H / 2 + 6), Vector2.new(1, 0.5), z + 2, nil, { TextSize = 34, Breathe = true })
	-- the purple Info tab on the card's top edge, with its short description
	infoTab(c, 'Everyone in this server gets x2 Power for 15 minutes. Buy again to add 15 more minutes!', CW - 70, 2, z + 3, true)
	return c
end
-- Community Codes (the reference's bottom section): a purple card with a darker header bar, the code field, the lime REDEEM
-- button and a "Like the game for new codes!" line; the server's answer (HoodServer/CodesService) shows on that line.
local CODES_H = 176
local codeBox, codeLine, redeemBusy
local CODE_HINT = 'Like the game for new codes!'
local CODE_HINT_COLOR = hex('FFF6C8')
local function codesCard(y, parent)
	local c = card({ Key = 'Codes' }, 'cardPurple', CW, CODES_H, MARGIN, y, parent)
	local z = 28
	local bar = Kit.new('Frame', { Name = 'HeaderBar', BackgroundColor3 = hex('5A1E9A'), BackgroundTransparency = 0.15, BorderSizePixel = 0, Size = UDim2.new(1, 0, 0, 40), ZIndex = z, Parent = c.Body })
	Kit.stroke(hex('2A0B4E'), 2, true).Parent = bar
	label({ Name = 'Text', Text = 'ENTER A CODE', TextSize = 24, Stroke = hex('2A0B4E'), StrokeThickness = 3.5, Size = UDim2.fromScale(1, 1), ZIndex = z + 1, Parent = bar })
	-- the field: cream, thick dark outline; "Enter code" is a label of its own that hides while you type
	local fw = CW - 24 - 214 - 24
	local field = Kit.new('Frame', { Name = 'Field', BackgroundColor3 = hex('FFF6D8'), BorderSizePixel = 0, Position = px(18, 58), Size = px(fw, 56), ZIndex = z, Parent = c.Body })
	Kit.corner(8).Parent = field
	Kit.stroke(hex('2A0B4E'), 3, true).Parent = field
	Kit.new('UIGradient', { Rotation = 90, Color = ColorSequence.new(hex('FFFFFF'), hex('E4D8F0')), Parent = field })
	local placeholder = label({ Name = 'Placeholder', Text = 'Enter code', TextSize = 28, TextColor3 = hex('9A86B8'), Stroke = hex('FFFFFF'), StrokeThickness = 0, Size = UDim2.fromScale(1, 1), ZIndex = z + 1, Parent = field })
	codeBox = Kit.new('TextBox', {
		Name = 'Input', BackgroundTransparency = 1, Text = '', PlaceholderText = '', ClearTextOnFocus = false,
		FontFace = Kit.Font.display, TextSize = 28, TextColor3 = hex('3A1A6A'), Size = UDim2.new(1, -24, 1, 0), Position = px(12, 0), ZIndex = z + 2, Parent = field,
	})
	local function focused()
		local ok, f = pcall(function() return codeBox:IsFocused() end)
		return ok and f == true
	end
	local function typed() placeholder.Visible = codeBox.Text == '' and not focused() end
	codeBox:GetPropertyChangedSignal('Text'):Connect(typed)
	codeBox.Focused:Connect(function() placeholder.Visible = false end)
	codeBox.FocusLost:Connect(typed)
	local redeem = Kit.blockButton({ Name = 'Redeem', Tone = LIMEBTN, OutlineColor = LIMEBTN.stroke, Width = 214, Height = 56, Text = 'REDEEM', TextSize = 30, Studs = false, Outline = 3, RimWidth = 2, Radius = 6, AnchorPoint = Vector2.new(1, 0), Position = px(CW - 18, 58), ZIndex = z })
	redeem.Parent = c.Body
	codeLine = label({ Name = 'Line', Text = CODE_HINT, TextSize = 21, StrokeThickness = 3, TextColor3 = CODE_HINT_COLOR, Stroke = hex('2A0B4E'), Position = px(0, 126), Size = px(CW - 6, 34), ZIndex = z + 1, Parent = c.Body })
	local saying = 0
	local function say(text, color)
		saying += 1
		local mine = saying
		codeLine.Text = text
		codeLine.TextColor3 = color
		Motion.pop(codeLine, 0.12)
		task.delay(4, function()
			if mine == saying and codeLine.Parent then
				codeLine.Text = CODE_HINT
				codeLine.TextColor3 = CODE_HINT_COLOR
			end
		end)
	end
	local function submit()
		local text = string.gsub(codeBox.Text or '', '^%s+', '')
		text = string.gsub(text, '%s+$', '')
		if text == '' then
			say('Type a code first!', hex('FFB4B4'))
			return
		end
		if redeemBusy then return end
		redeemBusy = true
		say('Checking...', hex('C8F6FF'))
		task.spawn(function()
			local ok, answer = pcall(function()
				local remote = Net and Net.get('RedeemCode')
				assert(remote, 'no remote')
				return remote:InvokeServer(text)
			end)
			redeemBusy = false
			if ok and type(answer) == 'table' and type(answer.Text) == 'string' then
				say(answer.Text, answer.Ok and hex('9CFF6A') or hex('FFB4B4'))
				if answer.Ok then
					codeBox.Text = ''
					placeholder.Visible = not focused()
				end
			else
				say('Codes are resting. Try again soon!', hex('FFB4B4'))
			end
		end)
	end
	Motion.button(redeem, submit)
	codeBox.FocusLost:Connect(function(enter) if enter then submit() end end)
	return c
end

-- The gift banner over the list while a receiver is chosen.
local function giftBanner(order)
	local g = giftActive()
	if not g then return end
	local f = Kit.new('Frame', { Name = 'GiftBanner', BackgroundTransparency = 1, Size = px(LW, 54), LayoutOrder = order, ZIndex = 24, Parent = list })
	local b = Kit.block({ Name = 'Banner', Tone = 'cardBlue', Width = CW, Height = 44, Studs = false, Outline = 3, RimWidth = 2, Radius = 8, Position = px(MARGIN, 4), ZIndex = 25 })
	b.Parent = f
	giftGlyph(b.Body, 34, 30, px(26, 18))
	local text = 'Gifting to ' .. g.Name .. ': pick a Cash Pack or a Box!'
	label({ Name = 'Text', Text = text, TextSize = Kit.fitSize(text, 22, CW - 190, 12), Stroke = hex('0B2A55'), TextXAlignment = Enum.TextXAlignment.Left, Position = px(52, 0), Size = px(CW - 190, 34), ZIndex = 30, Parent = b.Body })
	local cancel = Kit.blockButton({ Name = 'Cancel', Tone = 'rose', Width = 104, Height = 32, Text = 'Cancel', TextSize = 20, Studs = false, Outline = 2.5, RimWidth = 2, Radius = 6, AnchorPoint = Vector2.new(1, 0.5), Position = px(MARGIN + CW - 10, 26), ZIndex = 30 })
	cancel.Parent = f
	Motion.button(cancel, function() giftTarget = nil; rebuild() end)
end

local function build()
	built = true
	table.clear(priceLabels)
	table.clear(packLabels)
	table.clear(sections)
	countdownLabel, partyLine, shownFeatured = nil, nil, nil
	table.clear(entrance)
	table.clear(headers)
	table.clear(breathers)
	table.clear(shines)
	for _, child in list:GetChildren() do
		if child:IsA('GuiObject') then child:Destroy() end
	end
	local order = 1
	giftBanner(order)
	for _, section in Products.Sections do
		local items = {}
		for _, entry in Products.Catalog do
			-- (brief 22, lead) only what can really be bought: a row shows once its effect is Wired
			if entry.Section == section.Id and entry.Wired == true then table.insert(items, entry) end
		end
		if section.Id == 'Featured' then
			-- only the week's pack (Products.featuredAt), then the Server Boost (Block Party)
			items = {}
			local pack = Products.ByKey[(Products.featuredAt(nowSec()))]
			if pack and pack.Wired == true then table.insert(items, pack) end
			local party = Products.ByKey.BlockParty
			if party and party.Wired == true then table.insert(items, party) end
		elseif section.Id == 'Boost' then
			for i = #items, 1, -1 do if items[i].Key == 'BlockParty' then table.remove(items, i) end end -- (its card is in Featured)
		end
		if #items == 0 then continue end
		order += 1
		local head = sectionTitle(section.Title, order)
		head.Parent = list
		sections[section.Id] = head
		headers[section.Id] = head
		curSection = section.Id
		order += 1
		local block = Kit.new('Frame', { Name = section.Id, BackgroundTransparency = 1, LayoutOrder = order, ZIndex = 24, Parent = list })
		local y = 0
		if section.Id == 'Featured' then
			for _, entry in items do
				if entry.Section == 'Featured' then
					sections[entry.Key] = featuredCard(entry.Key, y, block)
					y += FEAT_H + GAP
				else
					sections[entry.Key] = serverCard(entry, y, block)
					y += SERVER_H + GAP
				end
			end
		elseif section.Id == 'Box' then
			-- one card a box, its bundles as buttons, in catalog order (room above each for the box standing out of it)
			local byBox, boxes = {}, {}
			for _, entry in items do
				local id = entry.Box or (entry.Art or ''):match('^box:(.+)$') or entry.Key
				if not byBox[id] then byBox[id] = {}; table.insert(boxes, id) end
				table.insert(byBox[id], entry)
			end
			local over = Kit.new('Frame', { Name = 'BoxButtons', BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 26 + #boxes, Parent = block })
			for k, id in boxes do
				sections[id] = boxCard(byBox[id], y, block, over)
				sections[id].ZIndex += k -- (each card over the one before: its box stands over that card's bottom edge)
				y += BOX_H + BOX_GAP
			end
		elseif section.Id == 'Cash' or section.Id == 'Power' then
			y += packGrid(items, y, block) + GAP
		else
			-- Gamepasses and Boosts: the coloured 2-column grid (a lone last card sits at the left, as in the reference)
			for i, entry in items do
				local col = (i - 1) % 2
				local tone = PASS_TONES[((i - 1 + (section.Id == 'Boost' and 2 or 0)) % #PASS_TONES) + 1]
				sections[entry.Key] = passCard(entry, MARGIN + col * (HALF + GAP), y, block, tone, { Was = (Products.savings(entry.Key)) })
				if col == 1 or i == #items then y += HALF_H + GAP end
			end
		end
		block.Size = px(LW, y + 6)
	end
	-- Community codes, last
	order += 1
	curSection = 'Codes'
	local head = sectionTitle('Community Codes', order)
	head.Parent = list
	sections.Codes = head
	headers.Codes = head
	order += 1
	local block = Kit.new('Frame', { Name = 'CodesBlock', BackgroundTransparency = 1, LayoutOrder = order, Size = px(LW, CODES_H + 8), ZIndex = 24, Parent = list })
	codesCard(0, block)
	-- the drawn scroll bar: the list's content height (its padding and blocks)
	local total = 18
	for _, child in list:GetChildren() do
		if child:IsA('GuiObject') then total += child.Size.Y.Offset end
	end
	Win.SetContent(total)
	fetchPrices()
end
rebuild = build
local function paintPacks()
	for key, l in packLabels do
		local entry = Products.ByKey[key]
		if l and l.Parent and entry then l.Text = amountText(entry) end
	end
end
for _, key in { 'RebirthNeed', 'Rebirths', 'Power', 'StagesCleared' } do
	player:GetAttributeChangedSignal(key):Connect(function() if isOpen then paintPacks() end end)
end
-- A pass bought (or found owned) while the Store exists: rebuild so its card says Owned.
for _, entry in Products.Catalog do
	if entry.Kind == 'Pass' then
		player:GetAttributeChangedSignal('Pass_' .. entry.Key):Connect(function() popOwned[entry.Key] = true; built = false; if isOpen then build() end end)
	end
end

local function scrollTo(at)
	local target = at and sections[at]
	if not target then
		list.CanvasPosition = Vector2.zero
		return
	end
	task.defer(function()
		local y = target.AbsolutePosition.Y - list.AbsolutePosition.Y + list.CanvasPosition.Y - 8
		list.CanvasPosition = Vector2.new(0, math.max(0, y))
	end)
end
---------------------------------------------------------------------------------------------- Gift A Player + the clock
local pickerFrame
closePicker = function()
	if pickerFrame then pickerFrame:Destroy() end
	pickerFrame = nil
end
local function chooseTarget(p)
	giftTarget = { UserId = p.UserId, Name = p.DisplayName, At = os.clock() }
	closePicker()
	build()
	scrollTo('Cash')
	notice('Pick a Cash Pack or a Box for ' .. p.DisplayName .. '!', 'green')
end
-- A small list of the other players in this server (a headshot and a name each); a tap picks one.
local function openPicker()
	closePicker()
	local others = {}
	for _, p in Players:GetPlayers() do
		if p ~= player then table.insert(others, p) end
	end
	table.sort(others, function(a, b) return string.lower(a.DisplayName) < string.lower(b.DisplayName) end)
	local RH, rows = 52, math.min(math.max(#others, 1), 5)
	local PW, PH = 380, 112 + rows * (RH + 6)
	local f = Kit.new('Frame', { Name = 'GiftPicker', BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 70, Parent = panel })
	pickerFrame = f
	local dim = Kit.new('TextButton', { Name = 'Dim', Text = '', AutoButtonColor = false, BackgroundColor3 = BLACK, BackgroundTransparency = 0.45, BorderSizePixel = 0, Size = UDim2.fromScale(1, 1), ZIndex = 70, Parent = f })
	dim.Activated:Connect(closePicker)
	local box = Kit.block({ Name = 'Box', Tone = 'cardBlue', Width = PW, Height = PH, Studs = false, Outline = 3, RimWidth = 2, Radius = 12, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.5, Win.Top / 2), ZIndex = 71 })
	box.Parent = f
	giftGlyph(box.Body, 44, 75, px(40, 34))
	label({ Name = 'Title', Text = 'Gift A Player', TextSize = 30, Stroke = hex('0B2A55'), TextXAlignment = Enum.TextXAlignment.Left, Position = px(72, 10), Size = px(PW - 150, 36), ZIndex = 75, Parent = box.Body })
	label({ Name = 'Hint', Text = 'Who gets your Cash Pack or Box?', FontFace = Kit.Font.body, TextSize = 16, Stroke = hex('0B2A55'), TextXAlignment = Enum.TextXAlignment.Left, Position = px(72, 44), Size = px(PW - 90, 20), ZIndex = 75, Parent = box.Body })
	local xb = Kit.blockButton({ Name = 'X', Tone = 'rose', Width = 36, Height = 36, Text = 'X', TextSize = 22, Studs = false, Outline = 2.5, RimWidth = 2, Radius = 5, AnchorPoint = Vector2.new(1, 0), Position = px(PW - 10, 10), ZIndex = 75 })
	xb.Parent = box
	Motion.button(xb, closePicker)
	local scroll = Kit.new('ScrollingFrame', { Name = 'Players', BackgroundTransparency = 1, BorderSizePixel = 0, Position = px(14, 82), Size = px(PW - 28, rows * (RH + 6)), CanvasSize = px(0, math.max(1, #others) * (RH + 6)), ScrollBarThickness = 5, ZIndex = 73, Parent = box })
	Kit.new('UIListLayout', { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder, Parent = scroll })
	if #others == 0 then
		label({ Name = 'None', Text = 'No one else is here yet. Invite a friend!', FontFace = Kit.Font.body, TextSize = 18, Stroke = hex('0B2A55'), TextWrapped = true, Size = px(PW - 28, RH), ZIndex = 75, Parent = scroll })
		return
	end
	for i, p in others do
		local row = Kit.new('TextButton', { Name = 'Player_' .. p.UserId, Text = '', AutoButtonColor = false, BackgroundColor3 = hex('163A78'), BorderSizePixel = 0, Size = px(PW - 28, RH), LayoutOrder = i, ZIndex = 74, Parent = scroll })
		Kit.corner(8).Parent = row
		Kit.stroke(hex('0B2A55'), 2, true).Parent = row
		local face = Kit.new('ImageLabel', { Name = 'Face', BackgroundColor3 = hex('7CCBFF'), Image = 'rbxthumb://type=AvatarHeadShot&id=' .. p.UserId .. '&w=150&h=150', Position = px(6, 5), Size = px(RH - 10, RH - 10), ZIndex = 75, Parent = row })
		Kit.corner(UDim.new(0.5, 0)).Parent = face
		label({ Name = 'Name', Text = p.DisplayName, TextSize = Kit.fitSize(p.DisplayName, 24, PW - 28 - RH - 90, 12), Stroke = hex('0B2A55'), TextXAlignment = Enum.TextXAlignment.Left, Position = px(RH + 4, 0), Size = px(PW - 28 - RH - 90, RH), ZIndex = 75, Parent = row })
		local pick = Kit.block({ Name = 'Pick', Tone = LIMEBTN, Width = 74, Height = 34, Studs = false, Outline = 2.5, RimWidth = 2, Radius = 6, OutlineColor = LIMEBTN.stroke, AnchorPoint = Vector2.new(1, 0.5), Position = px(PW - 28 - 8, RH / 2), ZIndex = 75 })
		pick.Parent = row
		label({ Name = 'Text', Text = 'GIFT', TextSize = 20, Stroke = LIMEBTN.stroke, Size = UDim2.fromScale(1, 1), ZIndex = 80, Parent = pick.Body })
		row.Activated:Connect(function() chooseTarget(p) end)
	end
end
Motion.button(Win.GiftButton, openPicker)
Players.PlayerRemoving:Connect(function(p)
	if giftTarget and p.UserId == giftTarget.UserId then
		giftTarget = nil
		if isOpen then
			notice(p.DisplayName .. ' left, so the gift is cancelled.', 'red')
			build()
		end
	end
end)

-- Once a second while the window is open: the Featured countdown, the Server Boost's "active" line, and the rotation itself:
-- the moment the countdown ends the card is rebuilt with the next pack (what the countdown promises is what happens).
local tickToken = 0
local function startTicker()
	tickToken += 1
	local mine = tickToken
	task.spawn(function()
		while isOpen and mine == tickToken do
			local now = nowSec()
			if shownFeatured and Products.featuredAt(now) ~= shownFeatured then
				build()
			elseif shownFeatured and countdownLabel and countdownLabel.Parent then
				countdownLabel.Text = fmtLeft(select(2, Products.featuredAt(now)))
			end
			if partyLine and partyLine.Parent then
				local left = num('PartyEnds', 0) - now
				partyLine.Text = left > 0 and string.format('ACTIVE: %d:%02d left', left // 60, left % 60) or '+15 minutes'
			end
			if giftTarget and not giftActive() then
				build()
				notice('The gift was cancelled.', 'blue')
			end
			task.wait(1)
		end
	end)
	-- the shine sweep: one soft diagonal band over each registered card, one after another, every few seconds
	task.spawn(function()
		task.wait(1.4)
		while isOpen and mine == tickToken do
			for i, band in shines do
				task.delay((i - 1) * 0.8, function()
					if band.Parent and isOpen then
						band.Position = UDim2.new(-0.3, 0, 0.5, 0)
						Motion.tween(band, 0.9, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, { Position = UDim2.new(1.3, 0, 0.5, 0) })
					end
				end)
			end
			task.wait(5)
		end
	end)
end
local function open(at)
	if isOpen then
		scrollTo(at)
		return
	end
	isOpen = true
	coverPlayerList(true)
	playerGui:SetAttribute('HoodWindow', NAME)
	if not built then build() end
	paintPacks()
	startTicker()
	Motion.blur(NAME, true)
	Motion.open(overlay, panel, 1)
	-- the window pop: 0.9 > 1.03 > 1 (Back-like), then the first section's title and cards stagger in
	local ps = Motion.scaleOf(panel)
	ps.Scale = 0.9
	local pop = Motion.tween(ps, 0.17, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, { Scale = 1.03 })
	pop.Completed:Once(function(state)
		if state == Enum.PlaybackState.Completed then Motion.tween(ps, 0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut, { Scale = 1 }) end
	end)
	startBreath()
	animateIn(sectionOf(at))
	scrollTo(at)
end
openEvent.Event:Connect(open)

---------------------------------------------------------------------------------------------- layout
-- The window keeps its design size where it fits (~56% of a PC screen's width, like video A's) and shrinks onto smaller
-- screens (Kit.fitWindow, the floating title included). Phones (the camera's short side <= 500) get the whole safe
-- screen, the topbar row included, so the window is as big as it can be; its X stays well under Roblox's top bar.
local fitter = panel.Parent
local function shortSide(abs)
	local ok, vs = pcall(function() return workspace.CurrentCamera.ViewportSize end)
	if ok and typeof(vs) == 'Vector2' and vs.X > 1 and vs.Y > 1 then return math.min(vs.X, vs.Y) end
	return math.min(abs.X, abs.Y)
end
local function relayout()
	local abs = gui.AbsoluteSize
	if abs.X < 1 or abs.Y < 1 then return end
	local phone = shortSide(abs) <= 500
	local insets = phone and Enum.ScreenInsets.DeviceSafeInsets or Enum.ScreenInsets.CoreUISafeInsets
	if gui.ScreenInsets ~= insets then
		gui.ScreenInsets = insets
		abs = gui.AbsoluteSize -- (Roblox may update it a frame later; its change runs relayout again)
	end
	fit(abs)
	Kit.fitWindow(panel, abs)
	Win.SetBar(phone and 12 or 7) -- (~8 dp on a phone, ~6 px on a PC)
	if phone then
		-- (a little smaller, at the right and a little low: the title clears Roblox's buttons at the top left and the X
		-- stays under the top bar's row)
		local s = fitter:FindFirstChild('FitScale')
		if s then s.Scale *= 0.96 end
		fitter.AnchorPoint = Vector2.new(1, 0.5)
		fitter.Position = UDim2.new(1, -16, 0.5, 10)
	else
		fitter.AnchorPoint = Vector2.new(0.5, 0.5)
		fitter.Position = UDim2.new(0.5, 0, 0.5, 2)
	end
end
gui:GetPropertyChangedSignal('AbsoluteSize'):Connect(relayout)
gui.Parent = playerGui
relayout()
