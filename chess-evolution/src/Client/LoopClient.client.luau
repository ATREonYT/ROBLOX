--!strict
-- +1 Chess Evolution: the loop panels (Promote, Shop, Daily, Gifts, Codes), and the HUD shortcuts that open them.
-- It reuses StarterGui.ChessLoop (built by Kit/LoopHud) and only builds one if that is missing.
-- The server owns every number; this script shows State and sends requests.
-- Feel numbers: press scale 0.9 then back over 0.28 s Back (note 14 §4); the panel opens
-- 0.85 -> 1 over 0.22 s Back and closes faster (note 30 §3); it closes only with X (note 09).
-- Errors go to Output on [ChessLoop] lines.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local Kit = ReplicatedStorage:WaitForChild("Kit")
local Net = require(Kit:WaitForChild("Net"))
local Format = require(Kit:WaitForChild("Format"))
local Config = require(ReplicatedStorage:WaitForChild("ChessConfig")) :: any

local function log(msg: string)
	print(`[ChessLoop] {msg}`)
end

local playerGui = player:WaitForChild("PlayerGui")
local gui = playerGui:WaitForChild("ChessLoop", 5) :: ScreenGui?
if not gui then
	local ok, built = pcall(function()
		return require(Kit:WaitForChild("LoopHud")).Build(Config)
	end)
	if not ok then
		warn(`[ChessLoop] could not build the panels: {built}`)
		return
	end
	gui = built
	built.Parent = playerGui
	log("built the panels from code (no saved ChessLoop in StarterGui)")
end
local G = gui :: any
local rail = G.LoopRail
local panel = G.Panel
local dim = G.Dim

local S: any = { loaded = false }
local helloAt = os.clock()

local function fmt(n: number): string
	local ok, s = pcall(Format.Short, n)
	return if ok and s then s else tostring(math.floor(n))
end

---------------------------------------------------------------------------
-- Feel helpers
---------------------------------------------------------------------------
local BACK = TweenInfo.new(0.28, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local function press(b: GuiObject, fn: () -> ())
	local scale = b:FindFirstChild("Press") :: UIScale?
	(b :: any).Activated:Connect(function()
		if scale then
			scale.Scale = 0.9
			TweenService:Create(scale, BACK, { Scale = 1 }):Play()
		end
		local ok, err = pcall(fn)
		if not ok then
			warn(`[ChessLoop] {b.Name}: {err}`)
		end
	end)
	b.MouseEnter:Connect(function()
		if scale and scale.Scale == 1 then
			TweenService:Create(scale, TweenInfo.new(0.3, Enum.EasingStyle.Back), { Scale = 1.06 }):Play()
		end
	end)
	b.MouseLeave:Connect(function()
		if scale then
			TweenService:Create(scale, TweenInfo.new(0.3, Enum.EasingStyle.Sine), { Scale = 1 }):Play()
		end
	end)
end

local function setText(b: Instance, t: string)
	local l = b:FindFirstChild("Label") :: TextLabel?
	if l then
		l.Text = t
	end
end

local statusAt = 0
local function status(t: string, color: Color3?)
	panel.Status.Text = t
	panel.Status.TextColor3 = color or Color3.new(1, 1, 1)
	statusAt = os.clock()
end

local WHY = {
	NeedPower = "Train more Power first",
	NeedWins = "Win more duels first",
	Busy = "Finish your duel first",
	Claimed = "Already claimed",
	NotYet = "Not ready yet",
	BadCode = "That code doesn't work",
	Used = "You already used that code",
	ComingSoon = "Coming soon",
	Owned = "You own this",
	NeedPass = "Needs the Auto Train pass",
	TooFast = "One moment...",
	NotLoaded = "Loading...",
}
local function why(r: any): string
	return WHY[r and r.code or ""] or "Try again"
end

---------------------------------------------------------------------------
-- Panel: one at a time, close only with X
---------------------------------------------------------------------------
local Hud = require(Kit:WaitForChild("HudBuilder")) :: any
local TITLES = { Promote = "Promote", Shop = "Shop", Daily = "Daily", Gifts = "Rewards", Codes = "Codes" }
local COLORS = { Promote = "pink", Shop = "red", Daily = "lemon", Gifts = "go", Codes = "purple" }
local ICONS = { Promote = "promote", Shop = "crown", Daily = "calendar", Gifts = "gift", Codes = "crown" }
local PAGE_HEIGHT = { Promote = 490, Codes = 410 } -- the rest use the full 560
local camera = workspace.CurrentCamera
local UserInputService = game:GetService("UserInputService")
local function fit()
	-- same scale as ChessHUD, so the two left grids stay lined up
	local vp = camera.ViewportSize
	local touch = UserInputService.TouchEnabled and not UserInputService.MouseEnabled
	local s = if touch then math.clamp(math.min(vp.X / 1250, vp.Y / 700), 0.5, 1) else math.clamp(math.min(vp.X / 1500, vp.Y / 860), 0.5, 1.15)
	G.Scale.Scale = s
end
camera:GetPropertyChangedSignal("ViewportSize"):Connect(fit)
fit()
local openPage: string? = nil
local refresh: () -> ()

local function show(name: string)
	for _, p in panel:GetChildren() do
		if p:IsA("Frame") and TITLES[p.Name] then
			p.Visible = p.Name == name
		end
	end
	panel.Title.Text = TITLES[name]
	Hud.Paint(panel.Header, COLORS[name])
	panel.HeaderIcon.Image = Hud.Icons[ICONS[name]] or ""
	panel.CodesTab.Visible = name == "Shop"
	panel.Size = UDim2.fromOffset(760, PAGE_HEIGHT[name] or 560)
	panel.Status.Text = ""
	openPage = name
	dim.Visible = true
	panel.Visible = true
	panel.Pop.Scale = 0.85
	TweenService:Create(panel.Pop, TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	refresh()
end

local function hide()
	openPage = nil
	local t = TweenService:Create(panel.Pop, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Scale = 0.85 })
	t:Play()
	task.delay(0.12, function()
		if not openPage then
			panel.Visible = false
			dim.Visible = false
		end
	end)
end
press(panel.Close, hide)

-- the main HUD may open its own panels: if ChessHUD shows one, ours closes (one panel at a time)
press(rail.PromoteBtn, function()
	show("Promote")
end)
press(rail.ShopBtn, function()
	show("Shop")
end)
press(rail.DailyBtn, function()
	show("Daily")
end)
press(rail.GiftBtn, function()
	show("Gifts")
end)
press(panel.CodesTab, function()
	show("Codes")
end)

---------------------------------------------------------------------------
-- HUD shortcuts (built in ChessHUD): each one opens the page that does the job
---------------------------------------------------------------------------
local hud = playerGui:WaitForChild("ChessHUD", 8) :: any
local function shortcut(holder: Instance?, page: string)
	if not holder then
		return
	end
	local b = holder:FindFirstChild("Face") :: GuiButton?
	if b then
		(b :: any).Activated:Connect(function()
			local scale = holder:FindFirstChild("Press") :: UIScale?
			if scale then
				scale.Scale = 0.9
				TweenService:Create(scale, BACK, { Scale = 1 }):Play()
			end
			local ok, err = pcall(show, page)
			if not ok then
				warn(`[ChessLoop] {holder.Name}: {err}`)
			end
		end)
	end
end
if hud then
	shortcut(hud.Wheel, "Gifts")
	shortcut(hud.RightOffers.FreeGift, "Gifts")
	shortcut(hud.Bottom.Clicker.FreeClicker, "Gifts")
	shortcut(hud.Bottom.Clicker.OpClicker, "Shop")
	shortcut(hud.RightOffers.Offer1, "Shop")
	shortcut(hud.RightOffers.Offer2, "Shop")
	shortcut(hud.Bottom.Buy.Pack1, "Shop")
	shortcut(hud.Bottom.Buy.Pack2, "Shop")
	shortcut(hud.Bottom.Buy.Pack3, "Shop")
	shortcut(hud.Bottom.Buy.PackMore, "Shop")
	shortcut(hud.TopBar.AutoWins, "Shop")
	-- Auto Train: the switch when owned, the Shop when not
	local autoFace = hud.TopBar.AutoTrain:FindFirstChild("Face") :: GuiButton
	;(autoFace :: any).Activated:Connect(function()
		if S.Passes and S.Passes.AutoTrain then
			local r = Net.Request("SetAuto", not S.Auto)
			if not r.ok then
				warn(`[ChessLoop] SetAuto: {r.code}`)
			end
		else
			show("Shop")
		end
	end)
	-- Invite Friends: Roblox's own invite window
	local inviteFace = hud.Invite:FindFirstChild("Face") :: GuiButton
	;(inviteFace :: any).Activated:Connect(function()
		local ok, err = pcall(function()
			game:GetService("SocialService"):PromptGameInvite(player)
		end)
		if not ok then
			warn(`[ChessLoop] invite: {err}`)
		end
	end)
end
press(panel.Promote.Skip, function()
	status("Coming soon", Color3.fromRGB(255, 210, 60))
end)

---------------------------------------------------------------------------
-- Actions
---------------------------------------------------------------------------
local function bigMoment(textValue: string)
	-- the HUD thread's FeelKit draws the large moment when it is installed (note 06 §2 size L)
	local ok = pcall(function()
		local FeelKit = require(Kit:FindFirstChild("FeelKit") :: ModuleScript) :: any
		local hud = playerGui:FindFirstChild("ChessHUD")
		FeelKit.Moment(hud or gui, "L", textValue)
	end)
	if not ok then
		log(textValue)
	end
end

press(panel.Promote.Go, function()
	local r = Net.Request("Promote")
	if r.ok then
		hide()
		bigMoment(`PROMOTED! +{math.floor(Config.Promotion.powerBonus * 100 * (r.data and r.data.promotions or 1))}% POWER`)
		log(`promoted to {r.data and r.data.promotions}`)
	else
		status(why(r), Color3.fromRGB(255, 120, 120))
	end
end)

press(panel.Daily.Claim, function()
	local r = Net.Request("ClaimDaily")
	if r.ok then
		status(`+{r.data.wins} Wins!`, Color3.fromRGB(255, 210, 60))
	else
		status(why(r), Color3.fromRGB(255, 120, 120))
	end
end)

for i in Config.Playtime do
	local tile = panel.Gifts.Grid:FindFirstChild("Gift" .. i)
	if tile then
		press(tile, function()
			local r = Net.Request("ClaimGift", i)
			if r.ok then
				status(`+{r.data.wins} Wins!`, Color3.fromRGB(255, 210, 60))
			else
				status(why(r), Color3.fromRGB(255, 120, 120))
			end
		end)
	end
end

press(panel.Codes.Redeem, function()
	local code = panel.Codes.Box.Text
	if code == "" then
		return
	end
	local r = Net.Request("Redeem", string.sub(code, 1, 24))
	if r.ok then
		status(`{r.data.text}!`, Color3.fromRGB(255, 210, 60))
		panel.Codes.Box.Text = ""
	else
		status(why(r), Color3.fromRGB(255, 120, 120))
	end
end)

for key in Config.Passes do
	local card = panel.Shop.List:FindFirstChild(key)
	if card then
		press(card.Buy, function()
			if key == "AutoTrain" and S.Passes and S.Passes.AutoTrain then
				local r = Net.Request("SetAuto", not S.Auto)
				if not r.ok then
					status(why(r), Color3.fromRGB(255, 120, 120))
				end
				return
			end
			local r = Net.Request("BuyPass", key)
			if not r.ok then
				status(why(r), Color3.fromRGB(255, 210, 60))
			end
		end)
	end
end

---------------------------------------------------------------------------
-- Showing State
---------------------------------------------------------------------------
local function age(): number
	return (S.SessionAge or 0) + (os.clock() - helloAt)
end

refresh = function()
	if not S.loaded then
		return
	end
	local n = S.Promotions or 0
	local pp, pw = S.PromoPower or 1, S.PromoWins or 1
	local progress = math.clamp(math.min(S.Power / pp, S.Wins / pw), 0, 1)
	local ready = S.Power >= pp and S.Wins >= pw
	rail.PromoteBtn.Track.Fill.Size = UDim2.fromScale(progress, 1)
	rail.PromoteBtn.Track.Pct.Text = if ready then "READY!" else `{math.floor(progress * 100)}%`
	-- the +N and the countdowns on the HUD
	local nextGift: number? = nil
	for i, g in Config.Playtime do
		if not (S.GiftsClaimed and S.GiftsClaimed[i]) then
			nextGift = math.max(0, g.min * 60 - age())
			break
		end
	end
	if hud then
		local words = if not nextGift then "Done" elseif nextGift <= 0 then "Ready!" else string.format("%d:%02d", nextGift // 60, nextGift % 60)
		hud.Wheel.Face.Timer.Text = words
		hud.Bottom.Clicker.FreeClicker.Face.Timer.Text = words
		local passes = Config.Passes
		local function priceText(key: string): string
			if S.Passes and S.Passes[key] then
				return "Owned"
			end
			return `Only {Hud.Robux} {passes[key].price}`
		end
		hud.RightOffers.Offer1.Price.Text = priceText("DoublePower")
		hud.RightOffers.Offer2.Price.Text = priceText("DoubleWins")
		local on = S.Auto == true
		hud.TopBar.AutoTrain.State.Text = if on then "ON" else "OFF"
		hud.TopBar.AutoTrain.State.TextColor3 = if on then Hud.Colors.priceGreen else Color3.fromRGB(255, 50, 60)
	end

	-- dots: something to claim (shown, never blinking)
	rail.DailyBtn.Dot.Visible = S.DailyReady == true
	local giftReady = false
	for i, g in Config.Playtime do
		if not (S.GiftsClaimed and S.GiftsClaimed[i]) and age() >= g.min * 60 then
			giftReady = true
		end
	end
	rail.GiftBtn.Dot.Visible = giftReady

	if openPage == "Promote" then
		local p = panel.Promote
		local pb, wb = Config.Promotion.powerBonus * 100, Config.Promotion.winsBonus * 100
		p.Before.Text = `+{math.floor(pb * n)}% Power`
		p.After.Text = `+{math.floor(pb * (n + 1))}% Power`
		p.WinsBefore.Text = `+{math.floor(wb * n)}% Wins`
		p.WinsAfter.Text = `+{math.floor(wb * (n + 1))}% Wins`
		p.Bar.Fill.Size = UDim2.fromScale(math.max(progress, 0.01), 1)
		p.Bar.Label.Text = `{fmt(S.Power)}/{fmt(pp)} Power · {fmt(S.Wins)}/{fmt(pw)} Wins`
		p.Go.BackgroundColor3 = if ready then Color3.fromRGB(110, 240, 40) else Color3.fromRGB(110, 116, 132)
	elseif openPage == "Daily" then
		for i in Config.Daily do
			local t = panel.Daily.Grid:FindFirstChild("Day" .. i)
			if t then
				local current = i == S.DailyTile
				local claimed = (S.DailyTile and i < S.DailyTile) or (current and not S.DailyReady)
				local locked = S.DailyTile and i > S.DailyTile
				t.BackgroundColor3 = if current and S.DailyReady then Color3.fromRGB(255, 190, 30) elseif claimed then Color3.fromRGB(44, 150, 70) else Color3.fromRGB(30, 30, 34)
				t.Check.Visible = claimed == true
				t.Lock.Visible = locked == true
				t.Art.Visible = not claimed and not locked
				t.Amount.Text = `+{math.floor(Config.Daily[i] * (1 + Config.Promotion.winsBonus * n))} Wins`
			end
		end
		setText(panel.Daily.Claim, if S.DailyReady then "CLAIM" else "COME BACK TOMORROW")
		panel.Daily.Claim.BackgroundColor3 = if S.DailyReady then Color3.fromRGB(70, 225, 50) else Color3.fromRGB(110, 116, 132)
		panel.Daily.Claim.Size = if S.DailyReady then UDim2.fromOffset(200, 54) else UDim2.fromOffset(300, 54)
		panel.Daily.Claim.Position = UDim2.new(0.5, if S.DailyReady then -100 else -150, 1, -54)
	elseif openPage == "Gifts" then
		for i, g in Config.Playtime do
			local t = panel.Gifts.Grid:FindFirstChild("Gift" .. i)
			if t then
				local claimed = S.GiftsClaimed and S.GiftsClaimed[i]
				local left = math.max(0, g.min * 60 - age())
				t.When.Text = if claimed then "Claimed" elseif left <= 0 then "CLAIM" else string.format("%d:%02d", left // 60, left % 60)
				t.BackgroundColor3 = if claimed then Color3.fromRGB(40, 40, 56) elseif left <= 0 then Color3.fromRGB(240, 60, 150) else Color3.fromRGB(30, 30, 34)
			end
		end
	elseif openPage == "Shop" then
		for key, pass in Config.Passes do
			local card = panel.Shop.List:FindFirstChild(key)
			if card then
				local owned = S.Passes and S.Passes[key]
				local label = if owned and key == "AutoTrain" then (if S.Auto then "AUTO: ON" else "AUTO: OFF")
					elseif owned then "Owned"
					elseif pass.id == 0 then "Coming soon"
					else "BUY"
				setText(card.Buy, label)
				card.Buy.BackgroundColor3 = if owned then Color3.fromRGB(40, 160, 210) elseif pass.id == 0 then Color3.fromRGB(110, 116, 132) else Color3.fromRGB(70, 225, 50)
			end
		end
	end
	if openPage == "Shop" then
		for _, pack in Config.PowerPacks or {} do
			local card = panel.Shop.List:FindFirstChild(pack.key)
			if card and pack.id == 0 then
				setText(card.Buy, "Coming soon")
				card.Buy.BackgroundColor3 = Color3.fromRGB(110, 116, 132)
			end
		end
	end
	if os.clock() - statusAt > 2.5 then
		panel.Status.Text = ""
	end
end

-- Ready glow: the Promote button's outline breathes white once per 2 s when ready (no flashes)
local promoteStroke = rail.PromoteBtn:FindFirstChildOfClass("UIStroke") :: UIStroke
RunService.Heartbeat:Connect(function()
	if not S.loaded then
		return
	end
	local ready = S.Power >= (S.PromoPower or math.huge) and S.Wins >= (S.PromoWins or math.huge)
	if ready or rail.PromoteBtn:GetAttribute("Spotlight") then
		local k = 0.5 + 0.5 * math.sin(os.clock() * math.pi)
		promoteStroke.Color = Color3.new(1, 1, 1):Lerp(Color3.fromRGB(28, 26, 40), 1 - k)
		promoteStroke.Thickness = 3 + 1.5 * k
	else
		promoteStroke.Color = Color3.fromRGB(28, 26, 40)
		promoteStroke.Thickness = 3
	end
end)

local function apply(state: any)
	if type(state) ~= "table" then
		return
	end
	S = state
	if state.SessionAge then
		helloAt = os.clock()
	end
	refresh()
end
Net.On("State", apply)
task.spawn(function()
	local r = Net.Request("Hello")
	if r.ok then
		apply(r.data)
	end
end)
task.spawn(function()
	while true do
		task.wait(1)
		pcall(refresh) -- timers on the Gifts page and the gift dot
	end
end)
log("ready")
