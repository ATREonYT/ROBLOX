-- Player HUD for +1 Hood Evolution, laid out like the reference simulator HUD:
--   top-left       Rebirths and Cash counters, a wide SHOP button, then REBIRTH / REWARDS / PVP / EVOLVE
--   top-centre     one hint line: how to train, your gun's Power multiplier and when you can evolve next
--   bottom-centre  your headshot and "<Power> POWER", over the LEVEL bar (level = your look's place in the
--                  ladder of looks; the bar fills toward the next look)
--   panels         SHOP (passes, boosts, guns), REBIRTH, REWARDS and EVOLVE, as UIKit modals
-- Authored in UIKit's 1280x720 design pixels; Kit.screen's UIScale fits it to any screen.
-- It only reads state: player attributes the server sets (LobbyService: Power, EquippedSkin, PowerRate,
-- TrainingStation, Cash, Rebirths; GunService: EquippedGun, GunMultiplier, OwnedGuns) and the profile
-- snapshot. The arrow over the next bag or the EVOLVE booth belongs to Lobby.client: the EVOLVE panel asks
-- it for directions through the local GuideEvolve attribute.
local Players = game:GetService('Players')
local RS = game:GetService('ReplicatedStorage')
local MarketplaceService = game:GetService('MarketplaceService')

local Shared = RS:WaitForChild('Shared')
local Kit = require(Shared.UIKit)
local Motion = require(Shared.UIMotion)
local Net = require(Shared.Net)
local ActiveMap = require(Shared.ActiveMap)
local Skins = require(Shared.Config.Skins)
local Balance = require(Shared.Config.Balance)
local Guns = require(Shared.Config.Guns)
local Products = require(Shared.Config.Products)

-- Modules other parts of the build add; the HUD works without them.
local function optional(...)
	local node = Shared
	for _, name in { ... } do
		node = node and node:FindFirstChild(name)
	end
	if not node then return nil end
	local ok, result = pcall(require, node)
	return ok and result or nil
end
local SkinArt = optional('SkinArt')
local GunRules = optional('GunRules')
local GunModels = optional('Models', 'GunModels')

local player = Players.LocalPlayer
local Color, Tone, short = Kit.Color, Kit.Tone, Kit.short
local px = UDim2.fromOffset

-- Same grouping LobbyService uses for overhead tags: every three looks share a colour.
local TIER_COLORS = { Color3.fromRGB(210, 218, 225), Color3.fromRGB(115, 207, 153), Color3.fromRGB(87, 170, 240), Color3.fromRGB(184, 125, 237), Color3.fromRGB(242, 182, 50) }
local function tierColor(skin) return TIER_COLORS[math.clamp(math.ceil(skin.Index / 3), 1, #TIER_COLORS)] end

---------------------------------------------------------------------------------------------- state
local snapshot = {} -- Cash and Rebirths from the profile snapshot, until the attributes arrive
local function num(name, fallback)
	local v = player:GetAttribute(name)
	return type(v) == 'number' and v or fallback
end
local function cashNow() return num('Cash', snapshot.Cash or 0) end
local function rebirthsNow() return num('Rebirths', snapshot.Rebirths or 0) end
local function skinNow() return Skins.ById[player:GetAttribute('EquippedSkin') or ''] or Skins.List[1] end
local function bestUnlocked(power)
	local best = Skins.List[1]
	for _, s in Skins.List do
		if power >= s.Required then best = s end
	end
	return best
end
local function rebirthNeed() return math.floor(Balance.RebirthBase * Balance.RebirthRequirementGrowth ^ rebirthsNow() + 0.5) end
local function gunMultiplier() return num('GunMultiplier', Guns.multiplier(player:GetAttribute('EquippedGun') or Guns.Starter)) end
local function mapHasStand()
	local map = ActiveMap.get()
	return map ~= nil and map.Root:GetAttribute('MorphStand') ~= false
end

---------------------------------------------------------------------------------------------- screen
local gui, root, fit = Kit.screen('HoodHUD', nil, 5)

-- A look's face (head and hat) in a ViewportFrame, like the reference's MOG button.
local function lookFace(skin, size, z)
	local vp = Kit.new('ViewportFrame', { Name = 'Face', BackgroundTransparency = 1, Size = px(size, size), ZIndex = z or 1 })
	vp:SetAttribute('PreviewImage', 'face:' .. skin.Id)
	local ok = SkinArt and pcall(function()
		SkinArt.mannequin(vp, CFrame.new(), skin, 1) -- faces -Z, head centred 4.76 studs up
		local cam = Kit.new('Camera', { FieldOfView = 32, Parent = vp })
		cam.CFrame = CFrame.lookAt(Vector3.new(-1.4, 5.4, -5.0), Vector3.new(0, 5.05, 0))
		vp.CurrentCamera = cam
		Kit.lightViewport(vp, cam.CFrame)
	end)
	if not ok then
		vp:Destroy()
		return Kit.icon3d('Evolve', size, { ZIndex = z })
	end
	return vp
end

-- A look's portrait (head to knees) for the EVOLVE panel; locked looks are a black silhouette.
local function lookPortrait(skin, w, h, locked)
	local vp = Kit.new('ViewportFrame', { Name = 'Portrait', BackgroundTransparency = 1, Size = px(w, h), ZIndex = 26 })
	vp:SetAttribute('PreviewImage', 'portrait:' .. skin.Id)
	if locked then
		vp.ImageColor3 = Color3.new(0, 0, 0)
		vp:SetAttribute('PreviewSilhouette', true)
	end
	if SkinArt then
		pcall(function()
			SkinArt.mannequin(vp, CFrame.new(), skin, 1)
			local cam = Kit.new('Camera', { FieldOfView = 30, Parent = vp })
			cam.CFrame = CFrame.lookAt(Vector3.new(-2.5, 4.7, -10.8), Vector3.new(0, 3.5, 0))
			vp.CurrentCamera = cam
			Kit.lightViewport(vp, cam.CFrame)
		end)
	end
	return vp
end

---------------------------------------------------------------------------------------------- top-left
-- Reference proportions: the column is as wide as the SHOP button; icons poke out of each button's top.
local LEFT, COLUMN, GAP, POP = 16, 224, 12, 14
local column = Kit.new('Frame', { Name = 'Actions', BackgroundTransparency = 1, Position = px(LEFT, 4), Size = px(COLUMN, 416), Parent = root })

local function counter(name, iconId, y)
	local row = Kit.new('Frame', { Name = name, BackgroundTransparency = 1, Position = px(0, y), Size = px(COLUMN, 44), Parent = column })
	local icon = Kit.icon3d(iconId, 52, { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, -4, 0.5, 0), ZIndex = 2 })
	icon.Parent = row
	local value = Kit.text({ Name = 'Value', Text = '0', TextSize = 34, Stroke = Color.ink, TextXAlignment = Enum.TextXAlignment.Left, Position = px(56, 2), Size = UDim2.new(1, -56, 1, 0), Parent = row })
	return value, icon
end
local rebirthCount, rebirthIcon = counter('Rebirths', 'Rebirth', 0)
local cashCount, cashIcon = counter('Cash', 'Cash', 46)

-- A raised Kit.button with a 3D icon popping out of its top edge and an outlined caption along the bottom.
local function actionButton(props)
	local holder, hit = Kit.button({ Name = props.Name, Tone = props.Tone, Width = props.Width, Height = props.Height, Radius = 10, Lip = 6, Position = props.Position })
	holder.Parent = column
	local icon = props.Icon
	icon.AnchorPoint = Vector2.new(0.5, 0)
	icon.Position = UDim2.new(0.5, 0, 0, -POP)
	icon.ZIndex = 3
	icon.Parent = holder.Body
	local caption = Kit.text({ Name = 'Caption', Text = props.Text, TextSize = props.TextSize or 20, Stroke = Color.ink, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -2), Size = UDim2.new(1, 8, 0, 24), ZIndex = 4, Parent = holder.Body })
	-- The part of the icon above the button takes taps too.
	hit.Position = px(0, -POP)
	hit.Size = UDim2.new(1, 0, 1, POP)
	Motion.button(holder, props.OnClick)
	return holder, icon, caption
end

-- Corner sticker on a button: "24%" on REBIRTH, "NEW!" on EVOLVE when a new look is ready.
local function badge(holder, name)
	local b = Kit.text({ Name = name, Text = '', TextSize = 24, Stroke = Color.ink, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 8, 0, 4), Size = px(70, 30), TextXAlignment = Enum.TextXAlignment.Right, Rotation = 8, ZIndex = 6, Parent = holder })
	return b
end

local SHOP_Y, SHOP_H = 104, 84
local GRID_W, GRID_H = (COLUMN - GAP) / 2, 100
local GRID_Y = SHOP_Y + SHOP_H + GAP + 2
local actions = {} -- filled with the button callbacks once the panels exist
local function call(name) return function() if actions[name] then actions[name]() end end end

local shopButton = actionButton({ Name = 'Shop', Tone = 'yellow', Width = COLUMN, Height = SHOP_H, Position = px(0, SHOP_Y), Text = 'SHOP', TextSize = 26, Icon = Kit.icon3d('Shop', 70), OnClick = call('Shop') })
Motion.shine(shopButton.Body, 4, UDim.new(0, 10))
local rebirthButton = actionButton({ Name = 'Rebirth', Tone = 'red', Width = GRID_W, Height = GRID_H, Position = px(0, GRID_Y), Text = 'REBIRTH', TextSize = 19, Icon = Kit.icon3d('Rebirth', 76), OnClick = call('Rebirth') })
actionButton({ Name = 'Rewards', Tone = 'cyan', Width = GRID_W, Height = GRID_H, Position = px(GRID_W + GAP, GRID_Y), Text = 'REWARDS', TextSize = 19, Icon = Kit.icon3d('Rewards', 76), OnClick = call('Rewards') })
actionButton({ Name = 'PVP', Tone = 'purple', Width = GRID_W, Height = GRID_H, Position = px(0, GRID_Y + GRID_H + GAP), Text = 'PVP', TextSize = 21, Icon = Kit.icon3d('PVP', 76), OnClick = call('PVP') })
local evolveFaceSkin = skinNow()
local evolveButton, evolveIcon = actionButton({ Name = 'Evolve', Tone = 'purple', Width = GRID_W, Height = GRID_H, Position = px(GRID_W + GAP, GRID_Y + GRID_H + GAP), Text = 'EVOLVE', TextSize = 19, Icon = lookFace(evolveFaceSkin, 78, 3), OnClick = call('Evolve') })
local rebirthBadge = badge(rebirthButton, 'Percent')
local evolveBadge = badge(evolveButton, 'Ready')
evolveBadge.Text = 'NEW!'
evolveBadge.TextColor3 = Tone.yellow.top
evolveBadge.Visible = false
-- A sticker wobbles while its button has something ready for you.
local wobbles = {}
local function wobble(sticker, on)
	if (wobbles[sticker] ~= nil) == on then return end
	if wobbles[sticker] then
		wobbles[sticker]:Cancel()
		wobbles[sticker] = nil
		sticker.Rotation = 8
	end
	if on then wobbles[sticker] = Motion.wobble(sticker, 10, 0.8) end
end
local function setEvolveReady(ready)
	evolveBadge.Visible = ready
	wobble(evolveBadge, ready)
end
local function setRebirthReady(ready)
	rebirthBadge.TextColor3 = ready and Tone.green.top or Color.white
	wobble(rebirthBadge, ready)
end
local headshotFace -- your look's face, standing in when Roblox has no avatar headshot for you
local function setEvolveFace(skin)
	if skin == evolveFaceSkin then return end
	evolveFaceSkin = skin
	local face = lookFace(skin, 78, 3)
	face.AnchorPoint, face.Position, face.Parent = evolveIcon.AnchorPoint, evolveIcon.Position, evolveIcon.Parent
	evolveIcon:Destroy()
	evolveIcon = face
	if headshotFace then
		local parent = headshotFace.Parent
		headshotFace:Destroy()
		headshotFace = lookFace(skin, 78, 2)
		headshotFace.Parent = parent
	end
end

---------------------------------------------------------------------------------------------- bottom-centre
local BAR_H = 44
local status = Kit.new('Frame', { Name = 'Status', BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -12), Size = px(560, 132), Parent = root })

local row = Kit.new('Frame', { Name = 'PowerRow', BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -BAR_H - 2), Size = UDim2.new(0, 640, 0, 80), Parent = status })
Kit.new('UIListLayout', { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center, VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder, Parent = row })
local headshotHolder = Kit.new('Frame', { Name = 'Headshot', BackgroundTransparency = 1, Size = px(78, 78), LayoutOrder = 1, Parent = row })
local headshot = Kit.new('ImageLabel', { Name = 'Image', BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Image = '', ScaleType = Enum.ScaleType.Fit, ZIndex = 2, Parent = headshotHolder })
local powerLabel = Kit.text({ Name = 'Power', Text = '...', TextSize = 48, Stroke = Color.ink, Size = px(0, 62), Parent = row })
powerLabel.AutomaticSize = Enum.AutomaticSize.X
powerLabel.LayoutOrder = 2
powerLabel:FindFirstChildOfClass('UIStroke').Thickness = 4.5
Kit.new('UIPadding', { PaddingLeft = UDim.new(0, 5), PaddingRight = UDim.new(0, 5), Parent = powerLabel })
Kit.gradient(Color.white, Kit.hex('FFF1A6'), 0.45).Parent = powerLabel

-- LEVEL bar: light track, yellow fill, "LEVEL n" left and "power/next" right, like the reference.
local bar = Kit.new('Frame', { Name = 'LevelBar', BackgroundColor3 = Color.white, BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.fromScale(0.5, 1), Size = UDim2.new(1, 0, 0, BAR_H), Parent = status })
Kit.corner(10).Parent = bar
Kit.stroke(Color.ink, 3.5, true).Parent = bar
Kit.gradient(Color.white, Kit.hex('C9CDD8'), 0.5).Parent = bar
local fill = Kit.new('Frame', { Name = 'Fill', BackgroundColor3 = Color.white, BorderSizePixel = 0, Size = UDim2.fromScale(0.1, 1), ZIndex = 2, Parent = bar })
Kit.corner(10).Parent = fill
local fillGradient = Kit.gradient(Tone.yellow.top, Tone.yellow.base, 0.55)
fillGradient.Parent = fill
local fillGloss = Kit.new('Frame', { Name = 'Gloss', BackgroundColor3 = Color.white, BackgroundTransparency = 0.55, BorderSizePixel = 0, Position = px(6, 4), Size = UDim2.new(1, -12, 0, 7), ZIndex = 3, Parent = fill })
Kit.corner(UDim.new(0.5, 0)).Parent = fillGloss
local levelLabel = Kit.text({ Name = 'Level', Text = 'LEVEL 1', TextSize = 30, Stroke = Color.ink, TextXAlignment = Enum.TextXAlignment.Left, Position = px(16, 2), Size = UDim2.new(0.6, -16, 1, 0), ZIndex = 4, Parent = bar })
local countLabel = Kit.text({ Name = 'Count', Text = '0/25', TextSize = 30, Stroke = Color.ink, TextXAlignment = Enum.TextXAlignment.Right, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -16, 0, 2), Size = UDim2.new(0.5, -16, 1, 0), ZIndex = 4, Parent = bar })

---------------------------------------------------------------------------------------------- top-centre
local hint = Kit.text({ Name = 'Hint', Text = '', TextSize = 30, Stroke = Color.ink, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 6), Size = px(820, 36), RichText = true, Parent = root })
hint.TextScaled = true
Kit.new('UITextSizeConstraint', { MaxTextSize = 30, MinTextSize = 12, Parent = hint })

-- Notices stack under the hint, newest on top, three at most.
local toastStack = Kit.new('Frame', { Name = 'Toasts', BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 50), Size = px(720, 160), ZIndex = 40, Parent = root })
Kit.new('UIListLayout', { Padding = UDim.new(0, 6), HorizontalAlignment = Enum.HorizontalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder, Parent = toastStack })
local toastCount = 0
local function toast(text, tone)
	text = tostring(text)
	toastCount += 1
	local width = math.clamp((utf8.len(text) or #text) * 12 + 56, 240, 700)
	local slot = Kit.new('Frame', { Name = 'Toast' .. toastCount, BackgroundTransparency = 1, Size = px(width, 44), LayoutOrder = -toastCount, Parent = toastStack })
	local t = Kit.toast({ Text = text, Tone = tone or 'green', Width = width })
	t.Parent = slot
	Motion.toast(t, 3)
	task.delay(3.5, function() slot:Destroy() end)
	local slots = {}
	for _, s in toastStack:GetChildren() do
		if s:IsA('Frame') then table.insert(slots, s) end
	end
	table.sort(slots, function(a, b) return a.LayoutOrder < b.LayoutOrder end)
	for i = 4, #slots do slots[i]:Destroy() end
end
-- Server notices are plain strings; pick a colour from what they say.
local function noticeTone(text)
	local lower = string.lower(text)
	if lower:find('evolved') or lower:find('equipped') or lower:find('bought') or lower:find('cleared') then return 'green' end
	if lower:find('reach') or lower:find('walk') or lower:find('need') or lower:find('first') or lower:find('find') then return 'yellow' end
	if lower:find('later build') or lower:find('soon') then return 'blue' end
	return 'purple'
end

---------------------------------------------------------------------------------------------- panels
local current -- the open panel
local function closePanel()
	local p = current
	if not p then return end
	current = nil
	Motion.close(p.Overlay, p.Panel)
end
local function makePanel(name, title, w, h, titleWidth)
	local panel, well, closeHit, overlay = Kit.modal(root, { Name = name, Title = title, Width = w, Height = h, TitleWidth = titleWidth })
	overlay.Visible = false
	-- Taps on the dimmed backdrop close the panel; taps on the panel itself stop there.
	local backdrop = Kit.new('TextButton', { Name = 'Backdrop', Text = '', AutoButtonColor = false, BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 20, Parent = overlay })
	backdrop.Activated:Connect(closePanel)
	Kit.new('TextButton', { Name = 'Sink', Text = '', AutoButtonColor = false, BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 21, Parent = panel })
	Motion.button(closeHit.Parent, closePanel)
	return { Overlay = overlay, Panel = panel, Well = well }
end
local function openPanel(p)
	if current == p then
		closePanel()
		return
	end
	if current then
		current.Overlay.Visible = false
		current = nil
	end
	current = p
	if p.Open then p.Open() end
	Motion.open(p.Overlay, p.Panel, 0.45)
end

-- Text and pills used inside panels.
local function body(parent, text, props)
	props = props or {}
	return Kit.text({
		Name = props.Name or 'Body', Text = text, FontFace = Kit.Font.body, TextSize = props.TextSize or 18, TextColor3 = props.Color or Color.ink,
		TextXAlignment = props.Align or Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, TextWrapped = true,
		Position = props.Position, Size = props.Size, AnchorPoint = props.AnchorPoint, ZIndex = props.ZIndex or 25, Parent = parent,
	})
end
local function pill(parent, text, tone, props)
	local t = Tone[tone]
	local p = Kit.new('Frame', { Name = props.Name or 'Pill', BackgroundColor3 = t and t.base or Color.asphalt, BorderSizePixel = 0, AnchorPoint = props.AnchorPoint or Vector2.zero, Position = props.Position, Size = props.Size, ZIndex = props.ZIndex or 26, Parent = parent })
	Kit.corner(UDim.new(0.5, 0)).Parent = p
	Kit.stroke(Color.ink, 2.5, true).Parent = p
	if t then Kit.gradient(t.top, t.base, 0.5).Parent = p end
	local label = Kit.text({ Name = 'Text', Text = text, TextSize = props.TextSize or 16, Stroke = t and t.stroke or Color.ink, ZIndex = (props.ZIndex or 26) + 1, Parent = p })
	return p, label
end
-- A coloured card for shop grids.
local function card(name, top, base, order)
	local c = Kit.new('Frame', { Name = name, BackgroundColor3 = Color.white, BorderSizePixel = 0, LayoutOrder = order, ZIndex = 25 })
	Kit.corner(Kit.Radius.m).Parent = c
	Kit.stroke(Color.ink, 3, true).Parent = c
	Kit.gradient(top, base, 0.62).Parent = c
	return c
end
-- Replace a panel's action button (Kit.button bakes its tone in, so state changes rebuild it).
local function actionIn(parent, old, props, onClick)
	if old then old:Destroy() end
	props.ZIndex = props.ZIndex or 27
	local holder = Kit.button(props)
	holder.Parent = parent
	if not props.Disabled then Motion.button(holder, onClick) end
	return holder
end

---------------------------------------------------------------- SHOP
local PASSES = {
	{ 'DoubleRep', 'x2 POWER', 'Double Power, forever', 'Power', 'yellow' },
	{ 'VIP', 'VIP', 'Gold tag + x1.5 Cash', 'Trophy', 'purple' },
	{ 'Lucky', 'LUCKY', 'Luckier crew rolls', 'Rewards', 'green' },
	{ 'TripleOpen', 'TRIPLE OPEN', 'Open 3 at once', 'Rewards', 'cyan' },
	{ 'ExtraCrewSlots', 'CREW SLOTS', '+2 crew slots', 'PVP', 'red' },
}
local minutes = math.floor((Products.BoostDurationSeconds or 900) / 60)
local BOOSTS = {
	{ 'RepBoost2x', 'x2 BOOST', minutes .. ' min of x2 Power', 'Power', 'yellow' },
	{ 'RepBoost3x', 'x3 BOOST', minutes .. ' min of x3 Power', 'Power', 'red' },
	{ 'SmallCash', 'CASH STACK', 'A stack of Cash', 'Cash', 'green' },
	{ 'LargeCash', 'CASH VAN', 'A whole van of Cash', 'Cash', 'green' },
	{ 'BlockParty', 'BLOCK PARTY', 'x2 Power for the server', 'Rewards', 'purple' },
}
local shop = makePanel('Shop', 'SHOP', 820, 470, 260)
local shopTab = 'Passes'
local shopTabs = Kit.new('Frame', { Name = 'Tabs', BackgroundTransparency = 1, Position = px(12, 10), Size = UDim2.new(1, -24, 0, 50), ZIndex = 24, Parent = shop.Well })
local shopNote = body(shop.Well, '', { Name = 'Note', Position = UDim2.new(0, 500, 0, 16), Size = UDim2.new(1, -512, 0, 44), TextSize = 16 })
local shopGrid = Kit.new('ScrollingFrame', {
	Name = 'Items', BackgroundTransparency = 1, BorderSizePixel = 0, Position = px(8, 64), Size = UDim2.new(1, -16, 1, -72), ZIndex = 24,
	ScrollBarThickness = 8, ScrollBarImageColor3 = Color.cardboardEdge, ScrollingDirection = Enum.ScrollingDirection.Y,
	AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(), Parent = shop.Well,
})
Kit.new('UIGridLayout', { CellSize = px(176, 160), CellPadding = px(12, 12), SortOrder = Enum.SortOrder.LayoutOrder, Parent = shopGrid })
Kit.new('UIPadding', { PaddingTop = UDim.new(0, 6), PaddingLeft = UDim.new(0, 8), Parent = shopGrid })

local function buyProduct(kind, id)
	local productId = Products[kind] and Products[kind][id] or 0
	if not Products.Enabled or productId == 0 then
		toast('The shop opens soon!', 'blue')
		return
	end
	if kind == 'Passes' then
		MarketplaceService:PromptGamePassPurchase(player, productId)
	else
		MarketplaceService:PromptProductPurchase(player, productId)
	end
end
local function productCard(kind, info, order)
	local tone = Tone[info[5]]
	local c = card(info[1], tone.top, tone.base, order)
	Kit.icon3d(info[4], 68, { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 4), ZIndex = 26 }).Parent = c
	Kit.text({ Name = 'Title', Text = info[2], TextSize = 21, Stroke = tone.stroke, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 72), Size = UDim2.new(1, -8, 0, 24), ZIndex = 26, Parent = c })
	body(c, info[3], { Name = 'Detail', TextSize = 15, Color = Color.white, Align = Enum.TextXAlignment.Center, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 97), Size = UDim2.new(1, -12, 0, 20), ZIndex = 26 })
	local live = Products.Enabled and (Products[kind][info[1]] or 0) ~= 0
	if live then
		actionIn(c, nil, { Name = 'Buy', Tone = 'green', Text = 'BUY', TextSize = 20, Width = 120, Height = 34, Lip = 4, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -6) }, function() buyProduct(kind, info[1]) end)
	else
		pill(c, 'COMING SOON', nil, { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -8), Size = UDim2.new(1, -24, 0, 28), TextSize = 15 })
	end
	return c
end
local function gunCard(gun, guns, cash)
	local light = gun.Color:Lerp(Color.white, 0.5)
	local c = card(gun.Id, light, gun.Color, gun.Tier)
	local art
	if GunModels and type(GunModels.build) == 'function' then
		local ok, model = pcall(GunModels.build, gun.Id, 1)
		if ok and typeof(model) == 'Instance' then
			-- Side-on, muzzle to the right, from the same side as the Blender renders when the module says.
			local view = typeof(GunModels.View) == 'Vector3' and GunModels.View or nil
			art = Kit.viewport(model, Vector2.new(150, 74), { Direction = view, Yaw = -70, Pitch = 12, ZIndex = 26 })
		end
	end
	art = art or Kit.icon3d('Gun', 74, { ZIndex = 26 })
	art:SetAttribute('PreviewImage', 'gun:' .. gun.Id)
	art.AnchorPoint = Vector2.new(0.5, 0)
	art.Position = UDim2.new(0.5, 0, 0, 2)
	art.Parent = c
	Kit.text({ Name = 'Title', Text = string.upper(gun.Name), TextSize = 18, Stroke = gun.Color:Lerp(Color.ink, 0.65), AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 76), Size = UDim2.new(1, -8, 0, 22), ZIndex = 26, Parent = c })
	Kit.text({ Name = 'Multiplier', Text = 'x' .. gun.Multiplier .. ' POWER', TextSize = 17, TextColor3 = Tone.yellow.top, Stroke = Color.ink, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 98), Size = UDim2.new(1, -8, 0, 20), ZIndex = 26, Parent = c })
	local state = GunRules and GunRules.state(guns, gun.Id) or ((player:GetAttribute('EquippedGun') or Guns.Starter) == gun.Id and 'Equipped' or 'Locked')
	local where = { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -8), Size = UDim2.new(1, -24, 0, 28), TextSize = 16 }
	if state == 'Equipped' then
		pill(c, 'EQUIPPED', 'green', where)
	elseif state == 'Owned' then
		pill(c, 'OWNED', 'blue', where)
	else
		local p, label = pill(c, gun.Cost <= 0 and 'FREE' or short(gun.Cost), nil, where)
		label.Position = px(12, 0)
		label.TextColor3 = cash >= gun.Cost and Tone.green.top or Color.white
		Kit.icon3d('Cash', 34, { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, -8, 0.5, 0), ZIndex = 28 }).Parent = p
	end
	return c
end
-- Gun cards hold live 3D models, so they are rebuilt only when what they show changes.
local function gunsKey()
	local cash, affordable = cashNow(), 0
	for _, gun in Guns.List do
		if cash >= gun.Cost then affordable += 1 end
	end
	return tostring(player:GetAttribute('OwnedGuns')) .. '|' .. tostring(player:GetAttribute('EquippedGun')) .. '|' .. affordable
end
local shownGuns
local function fillShop()
	for _, child in shopGrid:GetChildren() do
		if child:IsA('GuiObject') then child:Destroy() end
	end
	if shopTab == 'Guns' then
		shopNote.Text = 'Buy guns with Cash at the ARMORY next to spawn. Better gun = more Power per shot!'
		local guns = GunRules and GunRules.fromAttributes(player:GetAttribute('OwnedGuns'), player:GetAttribute('EquippedGun'))
		local cash = cashNow()
		for _, gun in Guns.List do gunCard(gun, guns, cash).Parent = shopGrid end
	else
		local list = shopTab == 'Boosts' and BOOSTS or PASSES
		shopNote.Text = shopTab == 'Boosts' and 'One-time boosts. Coming soon!' or 'Passes are yours forever. Coming soon!'
		for i, info in list do productCard(shopTab == 'Boosts' and 'DeveloperProducts' or 'Passes', info, i).Parent = shopGrid end
	end
end
local function fillShopTabs()
	for _, child in shopTabs:GetChildren() do child:Destroy() end
	for i, tab in { { 'Passes', 'PASSES', 'purple' }, { 'Boosts', 'BOOSTS', 'blue' }, { 'Guns', 'GUNS', 'red' } } do
		local active = shopTab == tab[1]
		local holder = Kit.button({ Name = tab[1], Tone = active and tab[3] or 'grey', Text = tab[2], TextSize = 22, Width = 150, Height = 48, Lip = 5, Position = px((i - 1) * 162, 0), ZIndex = 25 })
		holder.Parent = shopTabs
		Motion.button(holder, function()
			if shopTab == tab[1] then return end
			shopTab = tab[1]
			fillShopTabs()
			fillShop()
			shownGuns = gunsKey()
		end)
	end
end
shop.Open = function()
	fillShopTabs()
	fillShop()
	shownGuns = gunsKey()
end
shop.Update = function()
	if shopTab == 'Guns' and gunsKey() ~= shownGuns then
		shownGuns = gunsKey()
		fillShop()
	end
end

---------------------------------------------------------------- REBIRTH
local rebirth = makePanel('Rebirth', 'REBIRTH', 580, 390, 300)
Kit.icon3d('Rebirth', 150, { Position = px(18, 40), ZIndex = 25 }).Parent = rebirth.Well
local rebirthTitle = Kit.text({ Name = 'Title', Text = '', TextSize = 32, Stroke = Color.ink, TextXAlignment = Enum.TextXAlignment.Left, Position = px(184, 12), Size = px(350, 38), ZIndex = 25, Parent = rebirth.Well })
body(rebirth.Well, 'Start over with 0 Power and your first look, and keep a Power boost forever.', { Position = px(184, 54), Size = px(350, 48) })
local _, rebirthBoost = pill(rebirth.Well, '', 'yellow', { Name = 'Boost', Position = px(184, 110), Size = px(330, 34), TextSize = 19 })
local rebirthBar, rebirthFill, rebirthBarText = Kit.progress({ Name = 'Progress', Width = 330, Height = 30, Value = 0, Text = '', Position = px(184, 160) })
rebirthBar.ZIndex = 25
rebirthBar.Parent = rebirth.Well
local rebirthAction
local confirmUntil = 0
local function rebirthUpdate()
	local power, need, n = num('Power', 0), rebirthNeed(), rebirthsNow()
	local per = Balance.RebirthMultiplierPerLevel
	rebirthTitle.Text = 'REBIRTH #' .. (n + 1)
	rebirthBoost.Text = 'x' .. (1 + n * per) .. '  >  x' .. (1 + (n + 1) * per) .. ' POWER FOREVER'
	rebirthFill.Size = UDim2.fromScale(math.clamp(power / need, 0.06, 1), 1)
	rebirthBarText.Text = short(power) .. ' / ' .. short(need) .. ' POWER'
	local ready = power >= need
	local confirming = ready and os.clock() < confirmUntil
	local text = confirming and 'TAP TO CONFIRM' or (ready and 'REBIRTH!' or 'NEED ' .. short(need - power) .. ' MORE')
	local key = (ready and 'ready' or 'locked') .. (confirming and '+confirm' or '')
	if rebirthAction and rebirthAction:GetAttribute('Key') == key then
		rebirthAction.Body.Label.Text = text
		return
	end
	local where = { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -14), Width = 300, Height = 62, TextSize = 28 }
	where.Name = 'Action'
	where.Tone = confirming and 'red' or 'green'
	where.Disabled = not ready
	where.Text = text
	rebirthAction = actionIn(rebirth.Well, rebirthAction, where, function()
		if os.clock() < confirmUntil then
			confirmUntil = 0
			Net.get('Rebirth'):FireServer()
			closePanel()
		else
			confirmUntil = os.clock() + 4
			task.delay(4.1, function() if current == rebirth then rebirthUpdate() end end)
		end
		rebirthUpdate()
	end)
	rebirthAction:SetAttribute('Key', key)
end
rebirth.Open = function()
	confirmUntil = 0
	rebirthUpdate()
end
rebirth.Update = rebirthUpdate

---------------------------------------------------------------- REWARDS
local rewards = makePanel('Rewards', 'REWARDS', 640, 370, 300)
local days = Kit.new('Frame', { Name = 'Days', BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 14), Size = px(580, 112), ZIndex = 24, Parent = rewards.Well })
Kit.new('UIListLayout', { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder, Parent = days })
-- The day tiles hold 3D icons, so they are built the first time the panel opens.
rewards.Open = function()
	if days:FindFirstChild('Day1') then return end
	for day = 1, 7 do
		local big = day == 7
		local tone = big and Tone.purple or Tone.cyan
		local tile = card('Day' .. day, tone.top, tone.base, day)
		tile.Size = px(76, 108)
		tile.Parent = days
		Kit.text({ Name = 'Day', Text = 'DAY ' .. day, TextSize = 17, Stroke = tone.stroke, Position = px(0, 4), Size = UDim2.new(1, 0, 0, 20), ZIndex = 26, Parent = tile })
		Kit.icon3d(big and 'Rewards' or 'Cash', big and 62 or 52, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0, 62), ZIndex = 26 }).Parent = tile
		Kit.text({ Name = 'Lock', Text = '?', TextSize = 18, Stroke = Color.ink, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -2), Size = UDim2.new(1, 0, 0, 20), ZIndex = 26, Parent = tile })
	end
end
body(rewards.Well, 'Log in every day for bigger and bigger rewards. Daily rewards arrive in the next update!', { Align = Enum.TextXAlignment.Center, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 136), Size = px(520, 48) })
actionIn(rewards.Well, nil, { Name = 'Claim', Tone = 'green', Disabled = true, Text = 'COMING SOON', TextSize = 28, Width = 300, Height = 62, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -14) })

---------------------------------------------------------------- EVOLVE
-- Every look on one board: your look and the bar to the next one up top, then all 15 as cards (portrait, name,
-- +Power/sec, and EQUIPPED, EQUIP or the Power still needed; the next one to unlock is starred). EQUIP asks the
-- server (EquipSkin), which allows it at the look's own display or anywhere within LobbyRules.WardrobeRange of
-- the stand's WARDROBE. Away from it the board says where to go and its button asks Lobby.client for the arrow
-- (GuideEvolve); Lobby.client's WARDROBE prompt opens this panel through the local OpenEvolve attribute.
local LobbyRules = optional('LobbyRules')
local evolve = makePanel('Evolve', 'EVOLVE', 860, 500, 290)
local evolveFace
local evolveCurrent = Kit.text({ Name = 'Current', Text = '', TextSize = 24, Stroke = Color.ink, TextXAlignment = Enum.TextXAlignment.Left, Position = px(74, 4), Size = px(260, 28), ZIndex = 25, Parent = evolve.Well })
local evolveWhere = body(evolve.Well, '', { Name = 'Where', Position = px(74, 34), Size = px(270, 22), TextSize = 15 })
local evolveBar, evolveFill, evolveBarText = Kit.progress({ Name = 'Progress', Width = 290, Height = 30, Value = 0, Text = '', Position = px(346, 14) })
evolveBar.ZIndex = 25
evolveBar.Parent = evolve.Well
local evolveGrid = Kit.new('ScrollingFrame', {
	Name = 'Looks', BackgroundTransparency = 1, BorderSizePixel = 0, Position = px(8, 64), Size = UDim2.new(1, -16, 1, -70), ZIndex = 24,
	ScrollBarThickness = 8, ScrollBarImageColor3 = Color.cardboardEdge, ScrollingDirection = Enum.ScrollingDirection.Y,
	AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(), Parent = evolve.Well,
})
Kit.new('UIGridLayout', { CellSize = px(150, 170), CellPadding = px(10, 10), SortOrder = Enum.SortOrder.LayoutOrder, Parent = evolveGrid })
Kit.new('UIPadding', { PaddingTop = UDim.new(0, 6), PaddingLeft = UDim.new(0, 6), PaddingBottom = UDim.new(0, 6), Parent = evolveGrid })
local evolveAction
local shownBoard
-- true near the stand's WARDROBE, false away from it, nil on a map without one.
local function atWardrobe()
	local map = ActiveMap.get()
	local point = map and mapHasStand() and map.Lobby:FindFirstChild('WardrobePoint', true)
	if not point then return nil end
	local c = player.Character
	local r = c and c:FindFirstChild('HumanoidRootPart')
	return r ~= nil and (r.Position - point.Position).Magnitude <= (LobbyRules and LobbyRules.WardrobeRange or 30)
end
local function lookCard(skin, state, isNext)
	local color = tierColor(skin)
	local c = card(skin.Id, color:Lerp(Color.white, 0.6), color:Lerp(Color.white, 0.1), skin.Index)
	local vp = lookPortrait(skin, 140, 100, state == 'Locked')
	vp.AnchorPoint = Vector2.new(0.5, 0)
	vp.Position = UDim2.new(0.5, 0, 0, 2)
	vp.Parent = c
	Kit.text({ Name = 'Title', Text = string.upper(skin.Name), TextSize = 17, Stroke = color:Lerp(Color.ink, 0.7), AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 100), Size = UDim2.new(1, -8, 0, 20), ZIndex = 26, Parent = c })
	Kit.text({ Name = 'Gain', Text = '+' .. skin.Gain .. ' POWER/SEC', TextSize = 14, TextColor3 = Tone.yellow.top, Stroke = Color.ink, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 119), Size = UDim2.new(1, -8, 0, 16), ZIndex = 26, Parent = c })
	local where = { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -7), Size = UDim2.new(1, -20, 0, 26), TextSize = 15 }
	if state == 'Equipped' then
		pill(c, 'EQUIPPED', 'green', where)
	elseif state == 'Unlocked' then
		local holder = Kit.button({ Name = 'Equip', Tone = 'green', Text = 'EQUIP', TextSize = 18, Width = 124, Height = 32, Lip = 4, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -4), ZIndex = 27 })
		holder.Parent = c
		Motion.button(holder, function() Net.get('EquipSkin'):FireServer(skin.Id) end)
	else
		local _, label = pill(c, short(skin.Required) .. ' POWER', nil, where)
		label.TextColor3 = isNext and Tone.yellow.top or Color.white
	end
	if isNext then
		local star = Kit.text({ Name = 'Next', Text = 'NEXT!', TextSize = 20, TextColor3 = Tone.yellow.top, Stroke = Color.ink, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 6, 0, 6), Size = px(70, 26), TextXAlignment = Enum.TextXAlignment.Right, Rotation = 8, ZIndex = 28, Parent = c })
		Kit.stroke(Tone.yellow.top, 4, true).Parent = c
	end
	return c
end
local function guideToEvolve()
	-- Lobby.client owns the world arrow; this asks it to point at the WARDROBE, the EVOLVE booth or the next look.
	closePanel()
	local map = ActiveMap.get()
	local stand = mapHasStand()
	if not stand and not (map and map.Lobby:FindFirstChild('EvolvePoint', true)) then
		toast('This street has no EVOLVE booth yet.', 'yellow')
		return
	end
	player:SetAttribute('GuideEvolve', os.clock())
	toast(stand and 'Follow the arrow!' or 'Follow the arrow to the EVOLVE booth!', 'green')
end
local function evolveUpdate()
	local power, skin = num('Power', 0), skinNow()
	local best = bestUnlocked(power)
	local nextSkin = Skins.nextSkin and Skins.nextSkin(power) or Skins.List[best.Index + 1]
	local near = atWardrobe()
	local board = skin.Id .. '|' .. best.Id .. '|' .. tostring(near)
	if board ~= shownBoard then
		shownBoard = board
		if evolveFace then evolveFace:Destroy() end
		evolveFace = lookFace(skin, 60, 26)
		evolveFace.Position = px(6, 0)
		evolveFace.Parent = evolve.Well
		evolveCurrent.Text = string.upper(skin.Name) .. '  +' .. skin.Gain .. '/SEC'
		evolveCurrent.TextColor3 = tierColor(skin)
		for _, child in evolveGrid:GetChildren() do
			if child:IsA('GuiObject') then child:Destroy() end
		end
		for _, s in Skins.List do
			local state = s.Id == skin.Id and 'Equipped' or power >= s.Required and 'Unlocked' or 'Locked'
			lookCard(s, state, nextSkin ~= nil and s.Id == nextSkin.Id).Parent = evolveGrid
		end
	end
	evolveWhere.Text = near == true and 'At the WARDROBE: equip any look you have unlocked.'
		or near == false and 'Walk to the WARDROBE at the EVOLUTIONS stand to change looks.'
		or 'Unlock looks with Power, then evolve at the booth.'
	evolveFill.Size = UDim2.fromScale(nextSkin and math.clamp(power / nextSkin.Required, 0.06, 1) or 1, 1)
	evolveBarText.Text = nextSkin and (short(power) .. ' / ' .. short(nextSkin.Required) .. ' → ' .. string.upper(nextSkin.Name)) or 'FULLY EVOLVED!'
	local ready = best.Gain > skin.Gain
	local key = (near == true and 'here' or 'away') .. (ready and '+' or '-')
	if evolveAction and evolveAction:GetAttribute('Key') == key then return end
	evolveAction = actionIn(evolve.Well, evolveAction, {
		Name = 'Action', Tone = near == true and 'blue' or ready and 'green' or 'blue', TextSize = 20, Width = 180, Height = 46,
		Text = near == true and 'FIND NEXT LOOK' or ready and (mapHasStand() and 'GO EQUIP IT!' or 'GO TO THE BOOTH!') or 'SHOW ME',
		AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -10, 0, 8),
	}, guideToEvolve)
	evolveAction:SetAttribute('Key', key)
end
evolve.Open = function()
	shownBoard = nil
	evolveUpdate()
end
evolve.Update = evolveUpdate

actions.Shop = function() openPanel(shop) end
actions.Rebirth = function() openPanel(rebirth) end
actions.Rewards = function() openPanel(rewards) end
actions.Evolve = function() openPanel(evolve) end
player:GetAttributeChangedSignal('OpenEvolve'):Connect(function()
	if current ~= evolve then openPanel(evolve) end
end)
actions.PVP = function() toast('PVP ARENA COMING SOON! Keep training.', 'purple') end

---------------------------------------------------------------------------------------------- live values
local shown = Instance.new('NumberValue') -- the Power the HUD is showing; tweens up for the count-up
local function paintPower(v)
	powerLabel.Text = short(v) .. ' POWER'
	local skin = skinNow()
	local nextSkin = Skins.List[skin.Index + 1]
	if not nextSkin then
		countLabel.Text = 'MAX'
		fill.Size = UDim2.fromScale(1, 1)
		return
	end
	local ready = v >= nextSkin.Required
	countLabel.Text = ready and 'EVOLVE!' or short(v) .. '/' .. short(nextSkin.Required)
	fill.Size = UDim2.fromScale(math.clamp(v / nextSkin.Required, 0.04, 1), 1)
end
shown.Changed:Connect(paintPower)
local function setFillTone(tone)
	local t = Tone[tone]
	fillGradient.Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, t.top), ColorSequenceKeypoint.new(0.55, t.base), ColorSequenceKeypoint.new(1, t.base) })
end

-- A range's own colour for the hint (its label's "xN Power" colour, which the built lane carries as TextColor;
-- the station row's colour until the lane has streamed in).
local laneColor = {}
local function rangeColor(id, row)
	if laneColor[id] then return laneColor[id] end
	local map = ActiveMap.get()
	local lane = map and map.Lobby and map.Lobby:FindFirstChild('Training_' .. id, true)
	local c = lane and lane:GetAttribute('TextColor')
	if typeof(c) == 'Color3' then laneColor[id] = c return c end
	return row.Color or Color3.new(1, 1, 1)
end
local function hintText(power)
	local skin = skinNow()
	local best = bestUnlocked(power)
	if best.Index > skin.Index then
		return '<font color="#8CF06A">NEW LOOK UNLOCKED!</font>  Evolve into ' .. best.Name .. (mapHasStand() and ' at the WARDROBE' or ' at the EVOLVE booth')
	end
	local station = player:GetAttribute('TrainingStation') or ''
	local nextSkin = Skins.List[skin.Index + 1]
	local goal = nextSkin and ('Evolve at <font color="#8CF06A">' .. short(nextSkin.Required) .. '</font>') or ('Rebirth at <font color="#8CF06A">' .. short(rebirthNeed()) .. '</font>')
	local gun = '<font color="#FFE76A">x' .. gunMultiplier() .. ' Power</font>'
	if station:find('Locked:') then
		local gym = Skins.StationById[station:sub(8)]
		return '<font color="#FF8A8A">' .. (gym and gym.Name or 'This range') .. ' needs ' .. short(gym and gym.Required or 0) .. ' Power</font>  •  ' .. goal
	end
	if station == '' then
		-- A brand-new player (under the first look, never reborn) is told which lane to go to, in the yellow of
		-- Lobby.client's floor guide that leads there: the best lane they can use (the free one).
		local first = Skins.List[2]
		if first and power < first.Required and rebirthsNow() == 0 then
			local lane = Skins.Stations[1]
			for _, s in Skins.Stations do
				if power >= s.Required then lane = s end
			end
			return 'Go to the <font color="#FFE050">' .. string.upper(lane.Name) .. '</font> range and shoot! (x' .. lane.Multiplier .. ')'
		end
		return 'Step into a shooting range  •  ' .. gun .. '  •  ' .. goal
	end
	-- In a lane: the range's multiplier (in the lane's colour) and your gun's (white), side by side. A narrow hint
	-- (phones: under 700 design px) gets the short form, so the line stays big enough to read.
	local range = Skins.StationById[station]
	if range then
		local multipliers = '<font color="#' .. rangeColor(station, range):ToHex() .. '">Range x' .. range.Multiplier
			.. '</font>  •  <font color="#FFFFFF">Gun x' .. gunMultiplier() .. '</font>'
		if hint.Size.X.Offset < 700 then return 'Tap SHOOT  •  ' .. multipliers end
		return 'Click / tap to shoot  •  ' .. multipliers .. '  •  ' .. goal
	end
	return 'Click / tap to shoot  •  ' .. gun .. '  •  ' .. goal
end

local lastPower, lastIndex, lastCash, lastRebirths
local function refreshCounters()
	local cash, n = cashNow(), rebirthsNow()
	cashCount.Text = short(cash)
	rebirthCount.Text = short(n)
	if lastCash and cash > lastCash then Motion.pop(cashIcon, 0.3) end
	if lastRebirths and n > lastRebirths then Motion.pop(rebirthIcon, 0.3) end
	lastCash, lastRebirths = cash, n
end
local function refresh()
	local power = num('Power', nil)
	if power == nil then
		hint.Text = 'Getting your block ready...'
		return
	end
	local skin = skinNow()
	if lastIndex and skin.Index ~= lastIndex then
		Motion.pop(levelLabel, 0.35)
		Motion.pop(bar, 0.06)
	end
	lastIndex = skin.Index
	levelLabel.Text = 'LEVEL ' .. skin.Index
	local nextSkin = Skins.List[skin.Index + 1]
	setFillTone((nextSkin == nil or power >= nextSkin.Required) and 'green' or 'yellow')
	if lastPower == nil then
		shown.Value = power
	elseif power < lastPower then
		Motion.tween(shown, 0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, { Value = power }) -- also stops a running count-up
	elseif power > lastPower then
		Motion.tween(shown, 0.5, Enum.EasingStyle.Quart, Enum.EasingDirection.Out, { Value = power })
		Motion.pop(powerLabel, 0.07)
	end
	paintPower(shown.Value)
	lastPower = power
	local percent = math.clamp(math.floor(power / rebirthNeed() * 100), 0, 100)
	rebirthBadge.Text = percent .. '%'
	setRebirthReady(percent >= 100)
	setEvolveReady(bestUnlocked(power).Index > skin.Index)
	setEvolveFace(skin)
	hint.Text = hintText(power)
	if current and current.Update then current.Update() end
end
for _, key in { 'Power', 'EquippedSkin', 'TrainingStation', 'PowerRate', 'GunMultiplier', 'EquippedGun', 'OwnedGuns' } do
	player:GetAttributeChangedSignal(key):Connect(refresh)
end
for _, key in { 'Cash', 'Rebirths' } do
	player:GetAttributeChangedSignal(key):Connect(function()
		refreshCounters()
		refresh()
	end)
end

-- Avatar headshot; if Roblox can't give one (Studio test players), your look's face stands in.
task.spawn(function()
	local ok, image = pcall(function()
		return Players:GetUserThumbnailAsync(player.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size150x150)
	end)
	if ok and type(image) == 'string' and image ~= '' then
		headshot.Image = image
	else
		headshotFace = lookFace(skinNow(), 78, 2)
		headshotFace.Parent = headshotHolder
	end
end)

-- Notices from the server, the profile snapshot and its updates (Cash and Rebirths before the attributes land).
local function applyProfile(profile)
	if type(profile) ~= 'table' then return end
	snapshot.Cash = type(profile.Cash) == 'number' and profile.Cash or snapshot.Cash
	snapshot.Rebirths = type(profile.Rebirths) == 'number' and profile.Rebirths or snapshot.Rebirths
	refreshCounters()
	refresh()
end
-- Lobby props that aren't built yet (reward crates, the WORLD 2 portal) carry a ComingSoon prompt.
game:GetService('ProximityPromptService').PromptTriggered:Connect(function(prompt)
	if prompt:GetAttribute('ComingSoon') then toast((prompt.ObjectText ~= '' and prompt.ObjectText or 'This') .. ' is coming soon!', 'blue') end
end)
task.spawn(function()
	Net.get('Notice').OnClientEvent:Connect(function(message) toast(message, noticeTone(tostring(message))) end)
	Net.get('ProfileUpdated').OnClientEvent:Connect(applyProfile)
	for _ = 1, 10 do
		local ok, response = pcall(function() return Net.get('RequestSnapshot'):InvokeServer() end)
		if ok and type(response) == 'table' and response.Ready then
			applyProfile(response.Profile)
			break
		end
		task.wait(2)
	end
end)

---------------------------------------------------------------------------------------------- layout
-- Shoot.client's round SHOOT button (unscaled real pixels: 112 wide, 150 from the right edge) sits at the
-- bottom right while you train. On narrow screens the Power row and LEVEL bar slide left to stay clear of it.
-- On bigger screens the button column sits a little lower, like the reference, clear of Roblox's chat window;
-- phones keep it high, away from the thumbstick.
local SHOOT_RIGHT, SHOOT_SIZE = 150, 112
local function relayout()
	local abs = gui.AbsoluteSize
	if abs.X < 1 or abs.Y < 1 then return end
	fit(abs)
	local k = Kit.scaleFor(abs)
	local w, h = abs.X / k, abs.Y / k
	local phone = math.min(abs.X, abs.Y) <= 500
	column.Position = px(LEFT, phone and 4 or math.max(4, math.floor(h * 0.46 - 208)))
	local barWidth = phone and 480 or 560
	local shootLeft = (abs.X - SHOOT_RIGHT - SHOOT_SIZE) / k
	local x = math.min(w / 2, shootLeft - 12 - math.max(barWidth, 500) / 2)
	status.Position = UDim2.new(0, x, 1, -12)
	status.Size = px(barWidth, 132)
	hint.Size = px(math.max(360, math.min(900, w - 2 * (LEFT + COLUMN + 24))), 36)
end
gui:GetPropertyChangedSignal('AbsoluteSize'):Connect(relayout)
gui.Parent = player:WaitForChild('PlayerGui')
relayout()
refreshCounters()
refresh()
