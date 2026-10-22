-- Lobby HUD (design/pages/13): left column (Index, Shop, Dances, Menu; the owner swapped Tiers for Shop) centred on the left edge, coin and gem
-- Right column (Oct 19): INVITE (Roblox's invite prompt; friend rewards, Config/Friends), SPIN, QUESTS (the daily
-- quests, Screens/DailyQuests, with a green "!" while one can be claimed). A "+10% COINS" tag by the coin pill while a
-- friend plays in your server (owner: "a 10% coin boost when a friend is in"; the server sets HuzzFriendBoost).
-- balances bottom-left (in the top bar row on phones), settings in the top bar row at the right, and the next-round countdown top-centre. Hidden while a window is open.
-- The countdown only shows when the round system sets Workspace attribute "NextRoundAt" (server time, seconds);
-- there is no round system yet, so it stays hidden rather than showing a made-up timer.
local GuiService = game:GetService("GuiService")
local UserInputService = game:GetService("UserInputService")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Format = require(Shared.Format)
local SpinRules = require(Shared.SpinRules)
local DailyRules = require(Shared.DailyRules)
local Friends = require(Shared.Config.Friends)
local Net = require(Shared.Net)
local UI = script.Parent.Parent
local Theme = require(UI.Theme)
local Kit = require(UI.Kit)
local State = require(UI.State)
local Scale = require(UI.Scale)
local Toast = require(UI.Toast)
local ModalManager = require(UI.ModalManager)
local Motion = require(UI.Motion)
local Effects = require(UI.Effects)
local ShopStyle = require(UI.ShopStyle)
local CoinFx = require(UI.CoinFx)
local MainMenu = require(script.Parent.MainMenu)

local C = Theme.Colors
local new = Kit.new

local LobbyHud = {}
local PAGE_H = 347

local function group(parent: Instance, name: string, anchor: Vector2, pos: UDim2, size: Vector2, fixed: number?)
	local f = new("Frame", { Name = name, AnchorPoint = anchor, Position = pos, Size = UDim2.fromOffset(size.X, size.Y), BackgroundTransparency = 1, Parent = parent })
	Scale.bind(new("UIScale", { Parent = f }), function() return if fixed then Scale.points(fixed) else Scale.hud(PAGE_H) end)
	return f
end

-- Roblox's top bar sits above the UI's area. Its buttons are 44 px tall and 12 px in from the edge, so the gear
-- (and the balances on phones) line up with them in the same row, at the same margin from the right edge.
local TOPBAR_BUTTON, TOPBAR_MARGIN = 44, 12
local function topbarY(): number
	local ok, inset = pcall(function() return GuiService:GetGuiInset() end)
	local h = if ok and inset then inset.Y else 0
	return if h >= TOPBAR_BUTTON then -h + math.floor((h - TOPBAR_BUTTON) / 2) else TOPBAR_MARGIN
end

-- A square HUD button, bright (owner, Oct 21: "more vibrant and colorful so kids play it and like it", his side-menu
-- reference design/owner-oct21/1200-side-menu-ref.png): each button its own bright colour, lit at the top and a
-- little deeper at the foot, a thick dark outline, a thin light ring inside it, the studs showing through, a big icon
-- and the chunky white word with a dark outline along the bottom. 66 x 57 as before (the layout is unchanged).
local VIBRANT = ShopStyle.VIVID
local function squareButton(parent: Instance, name: string, icon: string, y: number, onClick: () -> ())
	local colour = VIBRANT[name] or C.HudMid
	local b = Kit.button({ Name = name, Style = "Hud", Text = "", Position = UDim2.fromOffset(25, y), Size = UDim2.fromOffset(66, 57), Corner = 8, RimThickness = 3, Parent = parent })
	b.Instance:FindFirstChild("Content"):Destroy()
	b.Instance.BackgroundColor3 = Kit.Styles.Hud.Idle
	b.Instance.BackgroundTransparency = 0
	local rim = b.Instance:FindFirstChild("Rim")
	if rim and rim:IsA("UIStroke") then rim.Color, rim.Thickness = ShopStyle.INK, 3 end
	new("UIGradient", { Rotation = 90, Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, colour:Lerp(Color3.new(1, 1, 1), 0.3)), ColorSequenceKeypoint.new(0.55, colour), ColorSequenceKeypoint.new(1, colour:Lerp(Color3.new(0, 0, 0), 0.2)) }), Parent = b.Instance })
	local studs = b.Instance:FindFirstChild("StudPattern")
	if studs and studs:IsA("ImageLabel") then studs.ImageTransparency = 0.6 end
	-- the pale ring just inside the outline (the reference's light bevel)
	new("Frame", { Name = "Ring", Position = UDim2.fromOffset(2, 2), Size = UDim2.new(1, -4, 1, -4), BackgroundTransparency = 1, ZIndex = b.Instance.ZIndex, Parent = b.Instance },
		{ Kit.corner(6), Kit.stroke(colour:Lerp(Color3.new(1, 1, 1), 0.6), 2.5, 0) })
	-- a big icon, centred above the word
	Kit.icon(icon, { Name = "Icon", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0, 22), Size = UDim2.fromOffset(40, 40), ZIndex = b.Instance.ZIndex + 1, Parent = b.Instance })
	-- the word: chunky white with a thick dark outline, sitting on the bottom edge
	ShopStyle.chunky({ Name = "Label", Text = name, TextSize = 16, TextColor3 = Color3.new(1, 1, 1), AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -2), Size = UDim2.new(1, 0, 0, 18), ZIndex = b.Instance.ZIndex + 2, Parent = b.Instance }, 2.5)
	b.onClick(onClick)
	return b
end

-- A HUD button that is one of his own whole tiles (owner, Oct 22, his backpack tile for the Inventory: "icon this ...
-- and add the inventory word, but make it fit inside of the icon"): his picture as it is (assets/icons, packed), the
-- button's own look taken off, and the word in the chunky white letters shrunk to fit inside his tile's light rim.
-- 70 x 67: his tile's dark outline is inside the picture, the others' 3 px rims stand outside their 66 x 57, so this
-- reads the same width.
local function tileButton(parent: Instance, name: string, picture: string, y: number, onClick: () -> ())
	local b = Kit.button({ Name = name, Style = "Hud", Text = "", Position = UDim2.fromOffset(23, y), Size = UDim2.fromOffset(70, 67), Corner = 8, Parent = parent })
	for _, x in b.Instance:GetChildren() do
		if x.Name == "Content" or x.Name == "StudPattern" or x.Name == "TopLine" or x.Name == "Ring" or x:IsA("UIStroke") or x:IsA("UIGradient") then x:Destroy() end
	end
	b.Instance.BackgroundTransparency = 1
	Kit.icon(picture, { Name = "Icon", Size = UDim2.fromScale(1, 1), ZIndex = b.Instance.ZIndex + 1, Parent = b.Instance })
	-- (a thinner 1.5 outline: at 10 with a 2 outline the letters broke up, owner Oct 22 "it's cut off right now in
	-- bits". Roblox sizes it itself, TextScaled up to 12 inside a box 56 wide within his blue face: the offline width
	-- guess ran narrower than Roblox's real letters, and the word was cut at the sides, owner Oct 22)
	local label = ShopStyle.chunky({ Name = "Label", Text = name, TextSize = 12, TextScaled = true, TextTruncate = Enum.TextTruncate.None, TextColor3 = Color3.new(1, 1, 1), AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -6), Size = UDim2.fromOffset(56, 13), ZIndex = b.Instance.ZIndex + 2, Parent = b.Instance }, 1.5)
	new("UITextSizeConstraint", { MaxTextSize = 12, MinTextSize = 8, Parent = label })
	b.onClick(onClick)
	return b
end

function LobbyHud.build(parent: Instance)
	local root = new("Frame", { Name = "LobbyHud", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = parent })

	-- The side buttons span y 32-290; a 322-tall group puts them exactly in the middle of the left edge.
	local left = group(root, "Left", Vector2.new(0, 0.5), UDim2.fromScale(0, 0.5), Vector2.new(100, 322))
	squareButton(left, "Index", "CollectionBook", 32, function() MainMenu.go("Index") end)
	local shop = squareButton(left, "Shop", "ShopCart", 98, function() MainMenu.go("Shop") end)
	Effects.shine(shop.Instance, { every = 4, corner = 5, z = 4 }) -- (a glint like the reference's shop button) -- (Tiers stays in the Menu; the Index filters by tier)
	-- INVENTORY where DANCES was (owner, Oct 21: "make the dances button the inventory button"): everything you own,
	-- to equip (Screens/Inventory; its DANCES tab plays yours and opens the Dances window)
	-- (his backpack tile, Oct 22: a little bigger than the others' faces, so it starts 5 higher: 159-226, Menu at 233)
	tileButton(left, "Inventory", "InventoryBackpack", 159, function() MainMenu.go("Inventory") end)
	local menu = squareButton(left, "Menu", "MainMenuLines", 233, function() ModalManager.toggle("Menu") end)
	menu.Instance.Icon.Size = UDim2.fromOffset(34, 34) -- the lines icon reads bigger than the others
	-- Right edge: SPIN opens the Spin the Wheel (Screens/SpinWheel); a green FREE tag while a free spin waits.
	local right = group(root, "Right", Vector2.new(1, 0.5), UDim2.fromScale(1, 0.5), Vector2.new(100, 322))
	local spin = squareButton(right, "Spin", "SpinWheel", 132, function() ModalManager.open("SpinWheel") end)
	if not Kit.reused(spin.Instance) then -- (mirrors the left column)
		spin.Instance.Position = UDim2.fromOffset(100 - 25 - 33, spin.Instance.Position.Y.Offset)
	end
	local freeTag = Kit.text({ Name = "FreeTag", Text = "FREE", FontFace = Theme.Fonts.Button, TextSize = 12, TextXAlignment = Enum.TextXAlignment.Center, TextColor3 = C.DarkText, BackgroundTransparency = 0, BackgroundColor3 = C.SelectedTab, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(4, 4), Size = UDim2.fromOffset(38, 17), ZIndex = 3, Visible = false, Parent = spin.Instance })
	Kit.attach(Kit.corner(4), freeTag)
	-- While a free spin waits: green rays turn behind the button, the wheel icon spins and the FREE tag breathes.
	-- (the rays sit beside the button, under it, so they glow round its edge instead of covering its face)
	local spinIcon = spin.Instance:FindFirstChild("Icon") :: GuiObject
	spin.Instance.ZIndex = 2
	local at = spin.Instance.Position
	local rays = Effects.rays(right, UDim2.fromOffset(at.X.Offset + 33, at.Y.Offset + 28), 104, { color = C.Accent, transparency = 0.3, seconds = 10, z = 1, name = "SpinRays" })
	Effects.spin(spinIcon, 6, function() return freeTag.Visible end)
	Effects.breathe(freeTag)
	-- QUESTS under SPIN (owner, Oct 19: "add easy quests as in this photo"), a green "!" while one can be claimed
	local quests = squareButton(right, "Quests", "QuestsClipboard", 198, function() ModalManager.open("DailyQuests") end)
	if not Kit.reused(quests.Instance) then quests.Instance.Position = UDim2.fromOffset(100 - 25 - 33, quests.Instance.Position.Y.Offset) end
	local questTag = Kit.text({ Name = "ReadyTag", Text = "!", FontFace = Theme.Fonts.Button, TextSize = 14, TextXAlignment = Enum.TextXAlignment.Center, TextColor3 = C.DarkText, BackgroundTransparency = 0, BackgroundColor3 = C.SelectedTab, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(4, 4), Size = UDim2.fromOffset(20, 20), ZIndex = 3, Visible = false, Parent = quests.Instance })
	Kit.attach(Kit.corner(10), questTag)
	-- INVITE over SPIN (owner, Oct 19: "make friend rewards, add a friend knife (for inviting them)"): Roblox's own
	-- invite prompt (SocialService, guarded: it isn't there offline or on every device)
	local invite = squareButton(right, "Invite", "Players", 66, function()
		local SocialService = game:GetService("SocialService")
		local me = game:GetService("Players").LocalPlayer
		local ok, can = pcall(function() return SocialService:CanSendGameInviteAsync(me) end)
		if ok and can then
			pcall(function() SocialService:PromptGameInvite(me) end)
			Toast.show(Friends.InviteHint)
		else
			Toast.show("Invites can't open here (Studio or this device). " .. Friends.InviteHint)
		end
	end)
	-- the friend rewards say so when they happen (HuzzServer/FriendService sets these attributes)
	do
		local me = game:GetService("Players").LocalPlayer
		me:GetAttributeChangedSignal("HuzzFriendBoost"):Connect(function()
			if me:GetAttribute("HuzzFriendBoost") == true then Toast.show(Friends.BoostToast) end
		end)
		me:GetAttributeChangedSignal("HuzzFriendGift"):Connect(function()
			local gift = me:GetAttribute("HuzzFriendGift")
			if gift == "Knife" then Toast.show(Friends.KnifeToast) elseif gift == "Coins" then Toast.show(Friends.CoinsToast) end
		end)
	end
	if not Kit.reused(invite.Instance) then invite.Instance.Position = UDim2.fromOffset(100 - 25 - 33, invite.Instance.Position.Y.Offset) end
	task.spawn(function()
		while root.Parent do
			freeTag.Visible = State.data.Loaded == true and SpinRules.available(State.data, workspace:GetServerTimeNow()) == 1
			rays.Visible = freeTag.Visible
			questTag.Visible = State.data.Loaded == true and DailyRules.ready(State.data.Daily, workspace:GetServerTimeNow()) > 0
			task.wait(1)
		end
	end)
	local hint = Kit.text({ Name = "KeyHint", Text = "", FontFace = Theme.Fonts.Button, TextSize = 11, TextXAlignment = Enum.TextXAlignment.Center, TextColor3 = C.DarkText, BackgroundTransparency = 0, BackgroundColor3 = C.SelectedTab, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(1, -2, 0, 4), Size = UDim2.fromOffset(16, 16), ZIndex = 3, Parent = menu.Instance })
	Kit.attach(Kit.corner(3), hint)

	local barY = topbarY()
	-- Balances sit bottom-left like the reference; on phones that is where the thumbstick goes, so there they move up
	-- into the top bar row, left of the gear.
	local touch = UserInputService.TouchEnabled
	local bottom = if touch
		then group(root, "Balances", Vector2.new(1, 0), UDim2.new(1, -(TOPBAR_MARGIN + 52 + 8) + 8, 0, barY + TOPBAR_BUTTON / 2 - 16 - 7), Vector2.new(300, 50), 1)
		else group(root, "Balances", Vector2.new(0, 1), UDim2.fromScale(0, 1), Vector2.new(300, 50))
	local coins = Kit.pill({ Name = "Coins", Icon = "CurrencyCoin", Position = UDim2.fromOffset(23, 7), Width = 131, Height = 32, TextSize = 14, PlusStyle = "HudPlus", Split = true, Parent = bottom })
	local gems = Kit.pill({ Name = "Aura", Icon = "AuraStar", -- (the owner's Aura star, as drawn)
		 Position = UDim2.fromOffset(161, 7), Width = 131, Height = 32, TextSize = 14, PlusStyle = "HudPlus", Split = true, Parent = bottom })
	-- While a Spin the Wheel "x2 Coins" lasts: a small green tag by the coin pill with the time left (counted down from
	-- the saved end time of a boost the player really won; never shown otherwise).
	local boost = new("Frame", {
		Name = "Boost", Position = UDim2.fromOffset(23, if touch then 43 else -18), Size = UDim2.fromOffset(131, 22),
		BackgroundColor3 = C.SelectedTab, BorderSizePixel = 0, Visible = false, Parent = bottom,
	}, { Kit.corner(5), Kit.stroke(C.SelectedRim, 1.5) })
	local boostText = Kit.text({ Name = "Label", Text = "x2 COINS", FontFace = Theme.Fonts.Number, TextSize = 13, TextXAlignment = Enum.TextXAlignment.Center, TextWrapped = false, Size = UDim2.fromScale(1, 1), Parent = boost })
	-- While a friend plays in this server: "+10% COINS" (the server adds it to every coin payout; Config/Friends)
	local friendTag = new("Frame", {
		Name = "FriendBoost", Position = UDim2.fromOffset(23, if touch then 43 else -18), Size = UDim2.fromOffset(131, 22),
		BackgroundColor3 = C.Banner, BorderSizePixel = 0, Visible = false, Parent = bottom,
	}, { Kit.corner(5), Kit.stroke(C.BannerRim, 1.5) })
	Kit.text({ Name = "Label", Text = Friends.BoostTag, FontFace = Theme.Fonts.Number, TextSize = 13, TextXAlignment = Enum.TextXAlignment.Center, TextWrapped = false, Size = UDim2.fromScale(1, 1), Parent = friendTag })
	local gemIcon = gems.Instance:FindFirstChild("Icon")
	if gemIcon and gemIcon:IsA("ImageLabel") then gemIcon.ImageColor3 = Color3.new(1, 1, 1) end
	coins.plus.onClick(function() ModalManager.open("Shop", "Coins") end)
	local setCoins = CoinFx.attach(coins)
	gems.plus.onClick(function() ModalManager.open("Shop", "Aura") end) -- (Shop > AURA: owner, Oct 20 14:07 "make a buy section for aura")

	local topRight = group(root, "TopRight", Vector2.new(1, 0), UDim2.new(1, -TOPBAR_MARGIN, 0, barY), Vector2.new(52, TOPBAR_BUTTON), 1)
	-- These follow Roblox's top bar on this device, so they are set here even when the saved StarterGui part is used.
	topRight.Position = UDim2.new(1, -TOPBAR_MARGIN, 0, barY)
	if touch then
		bottom.AnchorPoint = Vector2.new(1, 0)
		bottom.Position = UDim2.new(1, -(TOPBAR_MARGIN + 52 + 8) + 8, 0, barY + TOPBAR_BUTTON / 2 - 16 - 7)
	end
	local gear = Kit.button({ Name = "Settings", Style = "Hud", Text = "", Position = UDim2.fromOffset(0, 0), Size = UDim2.fromOffset(52, TOPBAR_BUTTON), Corner = 8, Icon = "SettingsGear", IconSize = 30, RimThickness = 1.5, Parent = topRight })
	gear.Instance.BackgroundColor3 = Kit.Styles.Hud.Idle
	new("UIGradient", { Rotation = 90, Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, C.HudTop), ColorSequenceKeypoint.new(0.5, C.HudMid), ColorSequenceKeypoint.new(1, C.HudBottom) }), Parent = gear.Instance })
	gear.onClick(function() ModalManager.toggle("Settings") end)

	local top = group(root, "Round", Vector2.new(0.5, 0), UDim2.fromScale(0.5, 0), Vector2.new(261, 70))
	-- Reference 13: a purple bar with a darker seam low down, a dark rim, two studs at each end, "NEXT ROUND" small
	-- and the clock bigger.
	local banner = new("Frame", { Name = "NextRound", Position = UDim2.fromOffset(3, 24), Size = UDim2.fromOffset(255, 36), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, Visible = false, Parent = top }, { Kit.corner(6), Kit.stroke(C.BannerRim, 2) })
	Kit.studPattern(banner, 0.4)
	new("UIGradient", { Rotation = 90, Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, C.Banner), ColorSequenceKeypoint.new(0.72, C.Banner), ColorSequenceKeypoint.new(0.75, C.BannerSeam), ColorSequenceKeypoint.new(1, C.BannerSeam) }), Parent = banner })
	Kit.studs(banner, 10, 40, 12)
	Kit.studs(banner, 222, 249, 12)
	local row = new("Frame", { Name = "Text", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Parent = banner }, { Kit.list(Enum.FillDirection.Horizontal, 10, Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Center) })
	Kit.text({ Name = "Label", Text = "NEXT ROUND", FontFace = Theme.Fonts.Button, TextSize = 17, AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.new(0, 0, 1, 0), TextWrapped = false, LayoutOrder = 1, Parent = row })
	local bannerText = Kit.text({ Name = "Clock", Text = "", FontFace = Theme.Fonts.Number, TextSize = 25, AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.new(0, 0, 1, 0), TextWrapped = false, LayoutOrder = 2, Parent = row })

	task.spawn(function()
		while root.Parent do
			local at = workspace:GetAttribute("NextRoundAt")
			if type(at) == "number" then
				banner.Visible = true
				bannerText.Text = Format.clock(at - workspace:GetServerTimeNow())
			else
				banner.Visible = false
			end
			local left = ((State.data.Boosts or {}).Coins or 0) - workspace:GetServerTimeNow()
			boost.Visible = left > 0
			if left > 0 then boostText.Text = "x2 COINS  " .. Format.clock(left) end
			-- the friend tag stacks over the x2 tag when both show
			friendTag.Visible = game:GetService("Players").LocalPlayer:GetAttribute("HuzzFriendBoost") == true
			local step = if touch then 26 else -24
			friendTag.Position = UDim2.fromOffset(23, (if touch then 43 else -18) + (if boost.Visible then step else 0))
			task.wait(0.25)
		end
	end)

	local function sync(data)
		setCoins(State.shown("Coins")) -- (held during a crate opening until the prize shows; gold when it goes up: CoinFx)
		gems.setAmount(Format.commas(data.Aura or 0))
		local showHints = State.setting("ShowKeyHints") == true
		hint.Visible = showHints
		hint.Text = tostring(State.setting("MenuKey"))
	end
	State.changed(sync)
	sync(State.data)
	-- While a window is open the HUD slides off to its edges, and slides back when it closes.
	local away = {
		[left] = UDim2.fromOffset(-400, 0), [right] = UDim2.fromOffset(400, 0), [bottom] = UDim2.fromOffset(0, if touch then -200 else 200),
		[topRight] = UDim2.fromOffset(400, 0), [top] = UDim2.fromOffset(0, -250),
	}
	local home = {}
	for g in away do home[g] = g.Position end
	-- A full window moves the whole HUD away; the Menu side panel only replaces the side buttons.
	-- In a round the side buttons and the coin pills slide away too (owner: the in-game screen felt cluttered;
	-- Huss Valley shows only the round), and slide back in the lobby.
	local player = game:GetService("Players").LocalPlayer
	local current = nil
	local function inRound()
		local role = player:GetAttribute("HuzzRole")
		return role == "Runner" or role == "Catcher"
	end
	-- While people actually run, the gear steps aside too, so only the round shows (owner: "a bit too much ui and can
	-- overwhelm the player"). The Menu key still opens everything.
	local roundNet = Net.get("Round")
	local function running()
		local stage = roundNet:GetAttribute("Stage")
		-- (phones and tablets keep the gear: they have no Menu key)
		return inRound() and (stage == "Running" or stage == "HeroRun") and not game:GetService("UserInputService").TouchEnabled
	end
	local function place()
		local side = ModalManager.isSide(current)
		local playing = inRound()
		local busy = running()
		pcall(function() -- (Roblox's player list steps aside too while running; there are no tools, so no backpack)
			local StarterGui = game:GetService("StarterGui")
			StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, not busy)
			StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
		end)
		for g, off in away do
			local hide = (current ~= nil and (not side or g == left)) or (playing and (g == left or g == right or g == bottom)) or (busy and g == topRight)
			Motion.tween(g, "hud", Theme.Motion.Hud, { Position = hide and home[g] + off or home[g] }, hide and Enum.EasingStyle.Quad or Enum.EasingStyle.Quint)
		end
	end
	ModalManager.changed(function(now)
		current = now
		place()
	end)
	player:GetAttributeChangedSignal("HuzzRole"):Connect(place)
	roundNet:GetAttributeChangedSignal("Stage"):Connect(place)
	place()
	return root
end

return LobbyHud
