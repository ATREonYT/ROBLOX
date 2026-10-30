-- Daily login rewards window (owner, Oct 24 06:12: "lets make daily rewards, ill send you some items we will put into
-- it"; 06:38: his Stormfang Chokuto "to be at day 7 of daily logins"). DAILY REWARDS: days 1-6 as small cards in two
-- rows, day 7 (his knife) tall on the right; claimed days dim with a tick, today's lit green, the rest waiting. Under
-- them one wide CLAIM button and, once today's is claimed, a real countdown to the next day (00:00 UTC).
-- What's next and whether it's ready: Shared/LoginRules.next(State.data.Login, server time), the same rules the server
-- checks the claim with (ActionService "ClaimLogin"). It opens by itself in the lobby once per visit while today's is
-- ready (never over a round or another window); the lobby's DAILY button opens it too.
local Players = game:GetService("Players")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local DailyLogin = require(Shared.Config.DailyLogin)
local Report = require(script.Parent.Parent.Report)
local LoginRules = require(Shared.LoginRules)
local DailyRules = require(Shared.DailyRules)
local CoinShop = require(Shared.Config.CoinShop)
local UI = script.Parent.Parent
local Theme = require(UI.Theme)
local Kit = require(UI.Kit)
local State = require(UI.State)
local Toast = require(UI.Toast)
local ModalManager = require(UI.ModalManager)
local Motion = require(UI.Motion)
local Effects = require(UI.Effects)

local new = Kit.new
local C, F = Theme.Colors, Theme.Fonts
local TODAY = Color3.fromHex("3FD24A")
local MYTHIC = Color3.fromHex("FF4FB8")

local DailyLoginScreen = {}

-- Is today's reward still to pop up this visit? (GroupReward holds its own popup back till this one's had its turn)
local waiting: () -> boolean = function() return false end
function DailyLoginScreen.waiting(): boolean return waiting() end

local W, H = 560, 392
local CARD = { X = 16, Y = 84, W = 112, H = 112, Gap = 10 }
local BIG = { X = 16 + 3 * (112 + 10), W = W - 16 - (16 + 3 * (112 + 10)) }
local ICON = { Coins = "CurrencyCoin", Aura = "AuraStar", Spins = "SpinWheel" }

local function now(): number
	local ok, t = pcall(function() return workspace:GetServerTimeNow() end)
	return if ok and type(t) == "number" then t else os.time()
end

local function line(props: { [string]: any }, stroke: number?): TextLabel
	props.TextWrapped = props.TextWrapped == true
	local l = Kit.text(props)
	new("UIStroke", { Name = "Outline", Color = C.TitleStroke, Thickness = stroke or 1.5, LineJoinMode = Enum.LineJoinMode.Round, Parent = l })
	return l
end

function DailyLoginScreen.build(parent: Instance)
	local player = Players.LocalPlayer
	local window = Kit.window({ Name = "DailyLogin", Title = "DAILY REWARDS", Icon = "GiftBenefit", Width = W, Height = H, TitleX = 56, TitleWidth = 220, Parent = parent, OnClose = function() ModalManager.close() end })
	local panel = window.Panel
	line({ Name = "About", Text = "A reward every day you play! Miss a day and you just carry on where you were.", FontFace = F.Body, TextSize = 14, TextColor3 = C.NoteText, Position = UDim2.fromOffset(CARD.X + 2, 56), Size = UDim2.fromOffset(W - 32, 20), ZIndex = 3, Parent = panel }, 1)

	local cards = {}
	for i, r in DailyLogin.Days do
		local big = i == #DailyLogin.Days
		local x = if big then BIG.X else CARD.X + ((i - 1) % 3) * (CARD.W + CARD.Gap)
		local y = if big then CARD.Y else CARD.Y + ((i - 1) // 3) * (CARD.H + CARD.Gap)
		local w, h = if big then BIG.W else CARD.W, if big then CARD.H * 2 + CARD.Gap else CARD.H
		local card = new("Frame", { Name = "Day" .. i, Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(w, h), BackgroundColor3 = C.Row, BackgroundTransparency = Theme.Transparency.Row, BorderSizePixel = 0, ZIndex = 2, Parent = panel }, { Kit.corner(8) })
		local rim = Kit.attach(Kit.stroke(if big then MYTHIC else C.RowBorder, 2), card) :: UIStroke -- (the saved one when there is one)
		line({ Name = "Day", Text = "DAY " .. i, FontFace = F.Heading, TextSize = if big then 20 else 15, TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.fromOffset(0, 5), Size = UDim2.new(1, 0, 0, 22), ZIndex = 4, Parent = card }, 1.6)
		local pic
		if r.Kind == "Knife" then
			local item = CoinShop.get(r.Id)
			pic = Kit.art(item and item.Art or "", { Name = "Picture", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.5, 0), Size = UDim2.fromOffset(w - 16, w - 16), ScaleType = Enum.ScaleType.Fit, ZIndex = 3, Parent = card })
			Kit.attach(Kit.corner(6), pic)
			Effects.rays(card, UDim2.new(0.5, 0, 0.5, 0), w, { color = MYTHIC, transparency = 0.6, seconds = 14, z = 2, name = "Rays" })
		else
			pic = Kit.icon(ICON[r.Kind] or "CurrencyCoin", { Name = "Picture", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0, 58), Size = UDim2.fromOffset(46, 46), ZIndex = 3, Parent = card })
		end
		line({ Name = "RewardName", Text = r.Name, FontFace = F.Name, TextSize = if big then 16 else 14, TextXAlignment = Enum.TextXAlignment.Center, AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 4, 1, if big then -30 else -6), Size = UDim2.new(1, -8, 0, 20), ZIndex = 4, Parent = card }, 1.5)
		if big then
			line({ Name = "Rarity", Text = "MYTHIC KNIFE", FontFace = F.Heading, TextSize = 13, TextColor3 = MYTHIC, TextXAlignment = Enum.TextXAlignment.Center, AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 4, 1, -10), Size = UDim2.new(1, -8, 0, 18), ZIndex = 4, Parent = card }, 1.2)
		end
		local tick = Kit.icon("CheckOwned", { Name = "Tick", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -5, 0, 5), Size = UDim2.fromOffset(22, 22), ZIndex = 5, Visible = false, Parent = card })
		cards[i] = { card = card, rim = rim, pic = pic, tick = tick, big = big }
	end

	local claim = Kit.button({ Name = "Claim", Text = "CLAIM", Style = "Action", FontFace = F.Button, TextSize = 22, Corner = 9, RimThickness = 2.5, Position = UDim2.fromOffset(CARD.X, H - 62), Size = UDim2.fromOffset(260, 48), ZIndex = 4, Parent = panel })
	local status = line({ Name = "Status", Text = "", FontFace = F.Heading, TextSize = 16, TextColor3 = C.Accent, TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.fromOffset(CARD.X + 270, H - 52), Size = UDim2.fromOffset(W - 32 - 270, 28), ZIndex = 4, Parent = panel }, 1.5)

	local pending = false
	local function refresh()
		local t = now()
		local login = State.data.Login or {}
		local index, ready = LoginRules.next(login, t)
		local count = tonumber(login.Count) or 0
		-- (a full week just claimed: all 7 ticked until tomorrow starts the next week)
		local weekDone = not ready and index == 1 and count > 0
		for i, c in cards do
			local claimed = weekDone or i < index
			local today = i == index and not weekDone
			c.tick.Visible = claimed
			c.card.BackgroundTransparency = if claimed then 0.55 else Theme.Transparency.Row
			c.pic.ImageTransparency = if claimed then 0.45 else 0
			c.rim.Color = if today and ready then TODAY elseif c.big then MYTHIC else C.RowBorder
			c.rim.Thickness = if today and ready then 3.5 else 2
		end
		if pending then
			claim.setText("..."); claim.setStyle("Selected"); claim.setEnabled(false)
		elseif ready then
			claim.setText("CLAIM DAY " .. index); claim.setStyle("Action"); claim.setEnabled(true)
		else
			claim.setText("CLAIMED"); claim.setStyle("Disabled"); claim.setEnabled(false)
		end
		status.Text = if ready then "Today: " .. DailyLogin.Days[index].Name else "NEXT IN " .. DailyRules.clock(LoginRules.wait(t))
	end

	claim.onClick(function()
		if pending then return end
		local index, ready = LoginRules.next(State.data.Login, now())
		if not ready then return end
		local r = DailyLogin.Days[index]
		local had = r.Kind == "Knife" and (State.data.Cosmetics or {})[r.Id] == true
		pending = true
		refresh()
		task.spawn(function()
			local ok, why = State.action("ClaimLogin")
			pending = false
			if ok then
				Toast.show(if had then `Day {index}: the {r.Name} is yours already, so +{r.Owned} coins!`
					elseif r.Kind == "Knife" then `Day {index}: the {r.Name} is yours! Wear it from your Inventory.`
					else `Day {index}: +{r.Name}!`)
				Motion.pop(cards[index].card)
			else
				Toast.show(why or "Couldn't claim that. Try again.")
			end
			refresh()
		end)
	end)

	local open = false
	local shown, due, timer = false, nil, false
	ModalManager.register("DailyLogin", {
		window = window,
		onOpen = function()
			open = true
			refresh()
			task.spawn(function()
				while open do
					task.wait(1)
					if open then Report.tick("DailyLogin", refresh) end
				end
			end)
		end,
		onClose = function()
			open = false
			-- (a round that pulled you in closed it before you looked: it comes back next time you're in the lobby)
			local role = player:GetAttribute("HuzzRole")
			if (role == "Runner" or role == "Catcher") and select(2, LoginRules.next(State.data.Login, now())) then
				shown = false
			end
		end,
		firstSelect = function() return claim.Instance end,
	})
	State.changed(function() if open then refresh() end end)
	refresh()

	-- By itself: once per visit, PopupAfter seconds after the save loaded, while today's is ready, in the lobby with
	-- nothing else open (else the next lobby moment or closed window looks again). A new player's How to Play comes
	-- first, then this right after it (owner, Oct 25: "pops up automatically when you join the game after the
	-- tutorial"), then the group reward (GroupReward waits while DailyLoginScreen.waiting()).
	waiting = function()
		return not shown and State.data.Loaded == true and select(2, LoginRules.next(State.data.Login, now())) == true
	end
	local function free(): boolean
		local role = player:GetAttribute("HuzzRole")
		return ModalManager.current() == nil and role ~= "Runner" and role ~= "Catcher"
	end
	local function maybeOpen()
		if shown or timer or not State.data.Loaded then return end
		if not select(2, LoginRules.next(State.data.Login, now())) then return end
		due = due or os.clock() + DailyLogin.PopupAfter
		timer = true
		task.delay(math.max(due - os.clock(), 0) + DailyLogin.AfterWindow, function()
			timer = false
			if shown or not select(2, LoginRules.next(State.data.Login, now())) then return end
			if free() then
				shown = true
				ModalManager.open("DailyLogin")
			end
		end)
	end
	State.changed(maybeOpen)
	ModalManager.changed(function() task.defer(maybeOpen) end)
	player:GetAttributeChangedSignal("HuzzRole"):Connect(maybeOpen)
	maybeOpen()
	return window.Holder
end

return DailyLoginScreen
