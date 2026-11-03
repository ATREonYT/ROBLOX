--!strict
-- The phone (Master Plan §3.6, §3.7). Bottom right, top ~15% peeking out and tilted. Hover lifts it, click/tap or
-- M (DPadUp on a gamepad) raises it with a spring; M, clicking the world, or dragging the top/bottom bar down lowers
-- it. When something arrives while it's down, it peeks higher with a banner ("phone moved = something for me").
-- Incoming calls raise it by themselves. Cutscenes hide it (UIState hidePhone).
--
-- API:
--   Phone.registerApp(appId, { title?, mount = fn(frame, ctx), unmount = fn(ctx)?, onEvent = fn(payload, ctx)? })
--   Phone.open(appId?, args?)  Phone.close()  Phone.home()  Phone.isOpen()  Phone.currentApp()
--   Phone.notify({ app?, title, text?, args? })        banner (tapping it opens `app` with `args`)
--   Phone.incomingCall({ caller, glyph?, onAnswer, onDecline })   local ring (server calls use the same screen)
--   Phone.fakeCall(name, message)                     "Calling..." -> "No answer" (contacts without a script)
--   Phone.Opened / Phone.Closed / Phone.ServerEvent (every PhoneEvent payload) : Signals
-- Apps live in StarterPlayerScripts/MTL/Apps (one ModuleScript each, returning { id = "...", mount = ..., ... });
-- they're loaded automatically. ctx (given to mount) is documented at makeContext below.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local Lighting = game:GetService("Lighting")

local Net = require(ReplicatedStorage.MTL.Net)
local Signal = require(ReplicatedStorage.MTL.Signal)
local Theme = require(ReplicatedStorage.MTL.UI.PhoneLook) :: any -- the phone's street look (falls through to Theme)
local Motion = require(ReplicatedStorage.MTL.UI.Motion)
local UIKit = require(ReplicatedStorage.MTL.UI.UIKit)
local Format = require(ReplicatedStorage.MTL.Format)
local PhoneConfig = require(ReplicatedStorage.MTL.Config.Phone)
local Story = require(ReplicatedStorage.MTL.Config.Story)
local PhoneRules = require(ReplicatedStorage.MTL.Rules.PhoneRules)
local Build = require(ReplicatedStorage.MTL.UI.Build.Phone)
local Avatars = require(ReplicatedStorage.MTL.UI.Avatars)
local Sfx = require(ReplicatedStorage.MTL.UI.Sfx)
local ClientData = require(script.Parent.ClientData)
local UIState = require(script.Parent.UIState)

local player = Players.LocalPlayer
local T = PhoneConfig.Tuning
local P = Theme.Phone

local Phone = {}
Phone.Opened = Signal.new()
Phone.Closed = Signal.new()
Phone.ServerEvent = Signal.new() -- (payload) every PhoneEvent, for apps that care (Settings: pathResult)

type AppSpec = { id: string, title: string?, mount: (Frame, any) -> (), unmount: ((any) -> ())?, onEvent: ((any, any) -> ())? }

local gui: any
local phoneFrame: any
local uiScale: UIScale
local apps: { [string]: AppSpec } = {}
local isOpen = false
local hovering = false
local hidden = false
local pingUntil = 0
local current: { id: string, frame: Frame, ctx: any }? = nil
local scale = 1
local rightInset = T.Margin

-- call state (client view)
type Call = { id: string?, contact: string?, name: string, glyph: string, state: string, openedByCall: boolean, onAnswer: (() -> ())?, onDecline: (() -> ())?, lines: { any }?, choices: { any }?, server: boolean }
local call: Call? = nil
local pendingCall: Call? = nil
-- An app the game asked to open while a cutscene/menu hid the phone: opened as soon as the phone is back.
local pendingOpen: { app: string, args: any }? = nil
-- When the phone last came up. World clicks right after that don't close it (clicking through the end of a cutscene put the phone away again).
local openedAt = -1e9
local OPEN_CLICK_GRACE = 1.0
local ringSound: any = nil
local callToken = 0

local notifyQueue: { any } = {}
local notifyBusy = false

---------------------------------------------------------------- helpers

local function settings(): any
	local d = ClientData.get()
	return (d and d.Settings) or {}
end

local function reducedMotion(): boolean
	return settings().ReducedMotion == true
end

-- Phone sounds go through UI/Sfx (ids in Theme.Sfx). Names used here: PhoneOpen, PhoneClose, PhoneTap, PhoneBack,
-- PhoneNotify, PhoneMessage, PhoneVibrate, PhoneRing (loop), PhoneCallEnd, PhoneShutter, PhoneType, PhoneSend, PhoneToggle.
local function sfx(name: string, opts: any?)
	Sfx.play(name, opts)
end

local function action(actionType: string, payload: { [string]: any }?)
	local p = payload or {}
	p.type = actionType
	Net.get("PhoneAction"):FireServer(p)
end

local function screen(): any
	return phoneFrame.Body.Screen
end

---------------------------------------------------------------- position / motion

local function viewport(): Vector2
	local cam = workspace.CurrentCamera
	return if cam then cam.ViewportSize else Vector2.new(1280, 720)
end

-- On touch screens the jump button sits bottom right: put the phone just left of it.
local function computeRightInset(): number
	local inset = T.Margin
	if UserInputService.TouchEnabled then
		local pg = player:FindFirstChild("PlayerGui")
		local touch = pg and pg:FindFirstChild("TouchGui")
		local frame = touch and touch:FindFirstChild("TouchControlFrame")
		local jump = frame and frame:FindFirstChild("JumpButton") :: GuiObject?
		if jump and jump.Visible then
			inset = math.max(inset, viewport().X - jump.AbsolutePosition.X + 10)
		end
	end
	return inset
end

local function layout()
	local vp = viewport()
	scale = math.clamp(vp.Y * T.HeightOfScreen / T.DesignSize.Y, T.MinScale, T.MaxScale)
	uiScale.Scale = scale
	rightInset = computeRightInset()
end

local function target(): (UDim2, number)
	local h = T.DesignSize.Y * scale
	if hidden then
		return UDim2.new(1, -rightInset, 1, h + 40), T.TiltDegrees
	elseif isOpen then
		return UDim2.new(1, -rightInset, 1, -T.OpenBottom), 0
	end
	local share = T.PeekShare
	if os.clock() < pingUntil then
		share = T.PingShare
	elseif hovering then
		share = T.HoverShare
	end
	return UDim2.new(1, -rightInset, 1, h * (1 - share)), T.TiltDegrees
end

-- The phone moves on a real spring (not a fixed tween), so a new target mid-move (hover, ping, open while it's
-- still lowering) just bends the motion instead of restarting it. Rotation follows the same spring.
local springY, springV, springRot, springRotV = 0, 0, 0, 0
local springTargetY, springTargetRot = 0, 0
local springConn: RBXScriptConnection? = nil

local function stepSpring(dt: number)
	dt = math.min(dt, 1 / 30)
	-- opening is a little bouncy, everything else settles without overshoot
	local freq = if isOpen then T.SpringOpenHz else T.SpringCloseHz
	local damp = if isOpen and not reducedMotion() then T.SpringOpenDamping else 1
	local w = 2 * math.pi * freq
	local function step(x: number, v: number, target: number): (number, number)
		local a = -w * w * (x - target) - 2 * damp * w * v
		v += a * dt
		x += v * dt
		return x, v
	end
	springY, springV = step(springY, springV, springTargetY)
	springRot, springRotV = step(springRot, springRotV, springTargetRot)
	phoneFrame.Position = UDim2.new(1, -rightInset, 1, springY)
	phoneFrame.Rotation = springRot
	if math.abs(springY - springTargetY) < 0.3 and math.abs(springV) < 2 and math.abs(springRot - springTargetRot) < 0.05 then
		springY, springV, springRot, springRotV = springTargetY, 0, springTargetRot, 0
		phoneFrame.Position = UDim2.new(1, -rightInset, 1, springY)
		phoneFrame.Rotation = springRot
		if springConn then
			springConn:Disconnect()
			springConn = nil
		end
	end
end

local function apply(instant: boolean?)
	local pos, rot = target()
	springTargetY, springTargetRot = pos.Y.Offset, rot
	if instant then
		springY, springV, springRot, springRotV = springTargetY, 0, springTargetRot, 0
		phoneFrame.Position = pos
		phoneFrame.Rotation = rot
		return
	end
	if not springConn then
		springConn = RunService.RenderStepped:Connect(function(dt)
			-- half-step twice per frame
			local half = dt / 2
			stepSpring(half)
			if springConn then
				stepSpring(half)
			end
		end)
	end
end

-- Rotated GUI doesn't clip, so a tilted (closed) phone shows the lock-screen look (clock + wallpaper) and the
-- open app is tucked away until the phone comes back up.
local function showContent()
	local s = screen()
	local appUp = isOpen and current ~= nil
	s.AppHost.Visible = appUp
	s.Home.Visible = not appUp
	s.Wallpaper.Visible = not appUp
end

local function refreshBadge()
	local d = ClientData.get()
	local badges = PhoneRules.badges(d and d.Phone)
	local total = 0
	for id, n in badges do
		total += n
		local icon = screen().Home:FindFirstChild("App_" .. id, true)
		if icon then
			UIKit.badge(icon.Icon, n)
		end
	end
	local b = phoneFrame.Badge
	b.Text = if total > 99 then "99+" else tostring(total)
	b.Visible = total > 0 and not isOpen and not hidden
	-- a small "M Phone" pill over the closed phone, so everyone knows how to bring it up
	local hint = phoneFrame:FindFirstChild("OpenHint") :: TextLabel?
	if not hint then
		local touchOnly = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
		hint = UIKit.new("TextLabel", {
			Name = "OpenHint",
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 0, -10),
			Size = UDim2.fromOffset(0, 26),
			AutomaticSize = Enum.AutomaticSize.X,
			BackgroundColor3 = Color3.fromRGB(24, 25, 29),
			BackgroundTransparency = 0.2,
			FontFace = Theme.Fonts.Bold,
			Text = if touchOnly then "Tap for phone" else "[M]  Phone",
			TextColor3 = Theme.Colors.Text,
			TextSize = 13,
			Parent = phoneFrame,
		}, { UIKit.corner(UDim.new(1, 0)), UIKit.padding(12, 0, 0) })
	end
	(hint :: TextLabel).Visible = not isOpen and not hidden
end

---------------------------------------------------------------- apps

function Phone.registerApp(appId: string, spec: any)
	spec.id = appId
	apps[appId] = spec
end

local function makeContext(appId: string, frame: Frame, args: any): any
	local conns: { any } = {}
	-- ctx: everything an app needs, nothing global.
	local ctx = {
		id = appId,
		frame = frame, -- the app's root (fills the screen between status bar and home bar)
		args = args or {}, -- what Phone.open(appId, args) was given (e.g. { contact = "Patel" })
		UIKit = UIKit,
		Theme = Theme,
		Motion = Motion,
		Format = Format,
		Rules = PhoneRules,
		Config = PhoneConfig,
		Story = Story,
		Phone = Phone,
		sfx = sfx, -- ctx.sfx("PhoneShutter")
		data = function()
			return ClientData.get()
		end,
		action = action, -- ctx.action("gpsRoute", { place = "FoodMart" })
		track = function(conn: any) -- connections here are cleaned up on unmount
			table.insert(conns, conn)
			return conn
		end,
		home = function()
			Phone.home()
		end,
		close = function()
			Phone.close()
		end,
	}
	-- ctx.onData(fn(data)) re-runs fn when the save snapshot changes (and once now)
	function ctx.onData(fn: (any) -> ())
		table.insert(conns, ClientData.Changed:Connect(function(new)
			if frame.Parent then
				fn(new)
			end
		end))
		local d = ClientData.get()
		if d then
			task.spawn(fn, d)
		end
	end
	-- ctx.clear(): empties the app frame (apps rebuild their own sub-screens)
	function ctx.clear()
		for _, c in frame:GetChildren() do
			c:Destroy()
		end
	end
	ctx._cleanup = function()
		for _, c in conns do
			if c and c.Disconnect then
				c:Disconnect()
			end
		end
		table.clear(conns)
	end
	return ctx
end

local function unmountCurrent()
	local cur = current
	if not cur then
		return
	end
	current = nil
	local spec = apps[cur.id]
	if spec and spec.unmount then
		pcall(spec.unmount, cur.ctx)
	end
	cur.ctx._cleanup()
	cur.frame:Destroy()
end

-- Smooth entrances: items settle in one after another (a small scale-up, staggered), 0.22 s Quint.
local ITEM_IN = TweenInfo.new(0.22, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
local STAGGER = 0.025

local function staggerIn(items: { GuiObject })
	if reducedMotion() then
		return
	end
	for i, item in items do
		local sc = item:FindFirstChildOfClass("UIScale") or UIKit.new("UIScale", { Parent = item })
		sc.Scale = 0.92
		task.delay((i - 1) * STAGGER, function()
			if sc.Parent then
				Motion.tween(sc, ITEM_IN, { Scale = 1 })
			end
		end)
	end
end

-- home icons, grid first then dock, in layout order
local function staggerHome()
	local items = {}
	for _, holder in { screen().Home:FindFirstChild("Grid"), screen().Home:FindFirstChild("Dock") } do
		if holder then
			local icons = {}
			for _, c in holder:GetChildren() do
				if c:IsA("GuiButton") and c.Visible then
					table.insert(icons, c)
				end
			end
			table.sort(icons, function(a, b)
				return a.LayoutOrder < b.LayoutOrder
			end)
			for _, c in icons do
				local sq = c:FindFirstChild("Icon")
				if sq and sq:IsA("GuiObject") then
					table.insert(items, sq)
				end
			end
		end
	end
	staggerIn(items)
end

-- an app's first list (rows, cards, bubbles) settles in after the app opens
local function staggerApp(frame: Instance)
	for _, sf in frame:GetDescendants() do
		if sf:IsA("ScrollingFrame") then
			local items = {}
			for _, c in sf:GetChildren() do
				if c:IsA("GuiObject") and c.Visible and #items < 12 then
					table.insert(items, c)
				end
			end
			table.sort(items, function(a, b)
				return a.LayoutOrder < b.LayoutOrder
			end)
			staggerIn(items)
			return
		end
	end
end

local function showHome()
	local wasApp = current ~= nil
	unmountCurrent()
	local s = screen()
	s.AppHost.Visible = false
	s.Home.Visible = true
	s.Wallpaper.Visible = true
	if wasApp and not reducedMotion() then
		local hs = s.Home:FindFirstChildOfClass("UIScale") or UIKit.new("UIScale", { Parent = s.Home })
		hs.Scale = 1.04
		Motion.tween(hs, Motion.AppIn, { Scale = 1 })
		staggerHome()
	end
end

local function mountApp(appId: string, args: any): boolean
	local spec = apps[appId]
	local d = ClientData.get()
	if not spec then
		warn("[MTL Phone] no app", appId)
		return false
	end
	if d and d.Phone and d.Phone.Apps and d.Phone.Apps[appId] == false then
		return false
	end
	unmountCurrent()
	local host = screen().AppHost
	local frame = UIKit.new("Frame", {
		Name = "App_" .. appId,
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Parent = host,
	})
	local s = UIKit.new("UIScale", { Scale = if reducedMotion() then 1 else 0.96, Parent = frame })
	if not reducedMotion() then
		frame.Position = UDim2.fromOffset(18, 0) -- slides in from the right a touch while it grows
	end
	local ctx = makeContext(appId, frame, args)
	current = { id = appId, frame = frame, ctx = ctx }
	host.Visible = true
	screen().Home.Visible = false
	screen().Wallpaper.Visible = false -- apps sit on the plain screen colour
	local ok, err = pcall(spec.mount, frame, ctx)
	if not ok then
		warn("[MTL Phone] app", appId, "failed:", err)
		UIKit.empty(frame, "This app crashed. Try again.")
	end
	Motion.tween(s, Motion.AppIn, { Scale = 1 })
	Motion.tween(frame, Motion.AppIn, { Position = UDim2.fromOffset(0, 0) })
	staggerApp(frame)
	return true
end

---------------------------------------------------------------- open / close

function Phone.isOpen(): boolean
	return isOpen
end

function Phone.currentApp(): string?
	return if current then current.id else nil
end

function Phone.open(appId: string?, args: any?)
	if hidden then
		if appId then
			pendingOpen = { app = appId, args = args }
		end
		return
	end
	pendingOpen = nil
	if appId then
		mountApp(appId, args)
	end
	if isOpen then
		return
	end
	isOpen = true
	openedAt = os.clock()
	phoneFrame.Body.Modal = true -- frees the mouse in first person / shift lock
	showContent()
	apply()
	if current == nil then
		staggerHome()
	end
	refreshBadge()
	sfx("PhoneOpen")
	Phone.Opened:Fire()
end

function Phone.close()
	if not isOpen then
		return
	end
	if call and call.state ~= "fake" then
		return -- finish or decline the call first (the call screen has the buttons)
	end
	isOpen = false
	hovering = false
	phoneFrame.Body.Modal = false
	apply()
	task.delay(0.2, function()
		if not isOpen then
			showContent()
		end
	end)
	refreshBadge()
	sfx("PhoneClose")
	Phone.Closed:Fire()
end

function Phone.toggle()
	if isOpen then
		Phone.close()
	else
		Phone.open()
	end
end

function Phone.home()
	showHome()
end

Phone.sfx = sfx

-- Camera app: see the world through the glass (screen + wallpaper go transparent; the bezel stays).
function Phone.setViewfinder(on: boolean)
	local s = screen()
	s.BackgroundTransparency = if on then 1 else 0
	s.Wallpaper.Visible = not on and current == nil
	-- the body behind the screen goes clear too (its edge stroke stays as the bezel)
	local body = phoneFrame:FindFirstChild("Body") :: GuiObject?
	if body then
		body.BackgroundTransparency = if on then 1 else 0
		for _, g in body:GetChildren() do
			if g:IsA("UIGradient") then
				g.Enabled = not on
			end
		end
		local rim = body:FindFirstChild("Rim")
		if rim and rim:IsA("GuiObject") then
			rim.Visible = not on
		end
	end
end

-- Camera app: hide the whole phone GUI for the frame a photo is taken (so it isn't in the picture).
function Phone.setCaptureHidden(on: boolean)
	gui.Enabled = not on
end

local function ping()
	if isOpen or hidden then
		return
	end
	pingUntil = os.clock() + T.PingSeconds
	apply()
	task.delay(T.PingSeconds + 0.05, function()
		if os.clock() >= pingUntil then
			apply()
		end
	end)
end

---------------------------------------------------------------- notifications

local function runNotifications()
	if notifyBusy then
		return
	end
	notifyBusy = true
	local banner = screen().Banner
	while #notifyQueue > 0 do
		local n = table.remove(notifyQueue, 1)
		local info = PhoneRules.appInfo(n.app)
		banner.Title.Text = n.title or ""
		banner.Body.Text = n.text or ""
		-- the app's drawn symbol (same as its home icon); otherwise the sender's initial
		local old = banner.Icon:FindFirstChild("Art")
		if old then
			old:Destroy()
		end
		banner.Icon.Text = ""
		local oldFace = banner.Icon:FindFirstChild("Face")
		if oldFace then
			oldFace:Destroy()
		end
		local who = (n :: any).contact or (n.args and n.args.contact)
		if type(who) == "string" then
			-- a text or call from someone: their face, like a real phone's notification
			Avatars.make(banner.Icon, who, 40, { Name = "Face", Size = UDim2.fromScale(1, 1), ZIndex = banner.Icon.ZIndex + 1 })
		elseif n.app and P.AppColors[n.app] then
			Build.drawIcon(n.app, banner.Icon, Theme.Colors.Text, banner.Icon.BackgroundColor3)
		else
			local t = n.title or (if info then info.title else nil) or "!"
			banner.Icon.Text = string.upper(string.sub(t, 1, 1))
		end
		banner:SetAttribute("App", n.app)
		banner:SetAttribute("Contact", n.args and n.args.contact or nil)
		-- Rotated GUI doesn't clip, so while the phone is down (tilted) the banner pops in place instead of
		-- sliding in from above the glass.
		local bscale = banner:FindFirstChildOfClass("UIScale") or UIKit.new("UIScale", { Parent = banner })
		local slide = isOpen
		banner.Position = if slide then UDim2.new(0.5, 0, 0, -80) else UDim2.new(0.5, 0, 0, 6)
		bscale.Scale = if slide then 1 else 0.85
		banner.Visible = true
		if n.app ~= "Messages" then
			sfx("PhoneNotify")
		end
		ping()
		local inInfo = if reducedMotion() then Motion.Normal else Motion.Spring
		Motion.tween(banner, inInfo, { Position = UDim2.new(0.5, 0, 0, 6) })
		Motion.tween(bscale, inInfo, { Scale = 1 })
		task.wait(T.NotificationSeconds)
		if isOpen then
			Motion.tween(banner, Motion.Normal, { Position = UDim2.new(0.5, 0, 0, -80) }).Completed:Wait()
		else
			Motion.tween(bscale, Motion.Fast, { Scale = 0.85 }).Completed:Wait()
		end
		bscale.Scale = 1
		banner.Visible = false
	end
	notifyBusy = false
end

-- force = true: show even though the target app is open (apps use it for "another thread" banners)
function Phone.notify(n: { app: string?, title: string, text: string?, args: any?, glyph: string?, force: boolean? })
	if not n.force and isOpen and current and current.id == n.app then
		local spec = apps[n.app]
		if spec and spec.onEvent then
			return -- the open app shows it itself
		end
	end
	table.insert(notifyQueue, n)
	task.spawn(runNotifications)
end

---------------------------------------------------------------- calls

local function callScreen(): any
	return screen().Call
end

-- the caller's face over the letter circle (contacts with a rig); the letter stays as the fallback
local function setCallFace(c: any)
	local av = callScreen().Avatar
	av.Text = c.glyph
	local old = av:FindFirstChild("Face")
	if old then
		old:Destroy()
	end
	if c.contact then
		Avatars.make(av, c.contact, 86, { Name = "Face", Size = UDim2.fromScale(1, 1), ZIndex = av.ZIndex + 1 })
	end
end

local function stopRing()
	if ringSound then
		ringSound:Stop()
		ringSound = nil
	end
end

local function showCallButtons(mode: string)
	local cs = callScreen()
	cs.Answer.Visible = mode == "ringing"
	cs.Decline.Visible = mode == "ringing"
	cs.HangUp.Visible = mode == "connected" or mode == "fake"
	cs.Skip.Visible = mode == "connected"
	cs.Caption.Visible = mode == "connected"
	cs.Choices.Visible = false
end

local function endCallUI(_outcome: string?)
	stopRing()
	sfx("PhoneCallEnd")
	callToken += 1
	local c = call
	call = nil
	local cs = callScreen()
	cs.Status.Text = "Call ended"
	showCallButtons("ended")
	task.delay(0.7, function()
		if call == nil then
			cs.Visible = false
			if c and c.openedByCall and isOpen and not current then
				Phone.close()
			end
		end
	end)
end

-- Shows the scripted lines one at a time (tap to advance, auto after a read-time), then the choices.
local function playLines(c: Call)
	callToken += 1
	local token = callToken
	local cs = callScreen()
	local lines = c.lines or {}
	local index = 0
	local skipAll = false
	local advance = Instance.new("BindableEvent")

	local tapConn = cs.Caption.Activated:Connect(function()
		advance:Fire()
	end)
	local skipConn = cs.Skip.Activated:Connect(function()
		skipAll = true
		advance:Fire()
	end)

	local function showChoices()
		cs.Caption.Visible = #lines > 0
		cs.Skip.Visible = false
		local choices = c.choices
		if not choices or #choices == 0 then
			-- nothing to answer: the call just ends
			if c.server then
				action("hangUp", { call = c.id })
			else
				endCallUI("answered")
			end
			return
		end
		cs.HangUp.Visible = false
		local box = cs.Choices
		for _, ch in box:GetChildren() do
			if ch:IsA("GuiButton") then
				ch:Destroy()
			end
		end
		for i, ch in choices do
			local b = UIKit.button(box, ch.text, {
				style = if i == 1 then "primary" else "secondary",
				order = i,
				onClick = function()
					if call == c then
						action("callChoice", { call = c.id, choice = ch.id })
					end
				end,
			})
			b.ZIndex = 12
		end
		box.Visible = true
	end

	task.spawn(function()
		while token == callToken and call == c do
			index += 1
			local line = lines[index]
			if not line or skipAll then
				break
			end
			cs.Caption.Who.Text = string.upper(line.who == c.contact and c.name or (Story.Contacts[line.who] and Story.Contacts[line.who].Name) or line.who or "")
			local label = cs.Caption.Line
			label.Text = line.text
			label.MaxVisibleGraphemes = if reducedMotion() then -1 else 0
			if not reducedMotion() then
				-- quick typewriter (tap shows the whole line)
				task.spawn(function()
					local n = utf8.len(line.text) or #line.text
					for g = 1, n do
						if label.MaxVisibleGraphemes == -1 or label.Text ~= line.text then
							return
						end
						label.MaxVisibleGraphemes = g
						task.wait(0.018)
					end
					label.MaxVisibleGraphemes = -1
				end)
			end
			local readTime = 1.6 + #line.text * 0.045
			local done = false
			local conn = advance.Event:Connect(function()
				if label.MaxVisibleGraphemes ~= -1 and not skipAll then
					label.MaxVisibleGraphemes = -1 -- first tap finishes the line
				else
					done = true
				end
			end)
			local start = os.clock()
			while not done and os.clock() - start < readTime and token == callToken and call == c do
				task.wait(0.05)
			end
			conn:Disconnect()
		end
		tapConn:Disconnect()
		skipConn:Disconnect()
		advance:Destroy()
		if token == callToken and call == c then
			showChoices()
		end
	end)
end

local function startRingUI(c: Call)
	local cs = callScreen()
	setCallFace(c)
	cs.Caller.Text = c.name
	cs.Status.Text = "Incoming call..."
	showCallButtons("ringing")
	cs.Visible = true
	stopRing()
	ringSound = Sfx.loop("PhoneRing")
	-- the phone buzzes while ringing
	if not reducedMotion() then
		local token = callToken
		task.spawn(function()
			local t0 = os.clock()
			while call == c and c.state == "ringing" and token == callToken do
				local t = os.clock() - t0
				local wiggle = if (t % 1.2) < 0.6 then math.sin(t * 60) * 1.6 else 0
				phoneFrame.Rotation = springRot + wiggle -- on top of the spring, so the two never fight
				RunService.RenderStepped:Wait()
			end
			if not hidden then
				phoneFrame.Rotation = springRot
			end
		end)
	end
end

local function beginCall(c: Call)
	if hidden then
		pendingCall = c -- shown when the cutscene/menu that hid the phone ends
		return
	end
	call = c
	c.openedByCall = not isOpen
	if current == nil then
		showHome()
	end
	startRingUI(c)
	Phone.open()
end

-- Local ring (server-driven calls use the same screen through PhoneEvent).
function Phone.incomingCall(opts: { caller: string, glyph: string?, onAnswer: (() -> ())?, onDecline: (() -> ())? })
	beginCall({
		id = nil,
		name = opts.caller,
		glyph = opts.glyph or string.sub(opts.caller, 1, 1),
		state = "ringing",
		openedByCall = false,
		onAnswer = opts.onAnswer,
		onDecline = opts.onDecline,
		server = false,
	})
end

-- Calling a contact who has no scripted call: "Calling..." then the no-answer line.
function Phone.fakeCall(name: string, message: string?)
	if call then
		return
	end
	local c: Call = { id = nil, name = name, glyph = string.sub(name, 1, 1), state = "fake", openedByCall = false, server = false }
	call = c
	callToken += 1
	local token = callToken
	local cs = callScreen()
	setCallFace(c)
	cs.Caller.Text = name
	cs.Status.Text = "Calling..."
	showCallButtons("fake")
	cs.Visible = true
	local conn
	conn = cs.HangUp.Activated:Connect(function()
		conn:Disconnect()
		if call == c then
			endCallUI("hungUp")
		end
	end)
	task.delay(2.6, function()
		if call == c and token == callToken then
			cs.Status.Text = message or PhoneConfig.NoAnswer.default
			task.wait(1.8)
			if call == c and token == callToken then
				conn:Disconnect()
				endCallUI("noAnswer")
			end
		end
	end)
end

local function onServerCall(msg: any)
	if msg.state == "ringing" then
		if call and call.server and call.id == msg.call then
			return -- already showing it
		end
		local name = msg.name or "Unknown"
		beginCall({
			id = msg.call,
			name = if msg.contact == "Unknown" then "Unknown number" else name,
			glyph = if msg.contact == "Unknown" then "?" else string.sub(name, 1, 1),
			state = "ringing",
			openedByCall = false,
			server = true,
			contact = msg.contact,
		} :: any)
	elseif msg.state == "connected" then
		local c: any = call
		if not (c and c.server and c.id == msg.call) then
			-- outgoing call-back (or a client that missed the ring): build the screen now
			local name = msg.name or "Unknown"
			c = {
				id = msg.call,
				name = if msg.contact == "Unknown" then "Unknown number" else name,
				glyph = if msg.contact == "Unknown" then "?" else string.sub(name, 1, 1),
				state = "connected",
				openedByCall = not isOpen,
				server = true,
				contact = msg.contact,
			}
			call = c
			if hidden then
				return
			end
			local cs = callScreen()
			setCallFace(c)
			cs.Caller.Text = c.name
			cs.Visible = true
			Phone.open()
		end
		stopRing()
		c.state = "connected"
		c.lines = msg.lines
		c.choices = msg.choices
		local cs = callScreen()
		cs.Status.Text = if msg.outgoing then "Connected" else "On call"
		showCallButtons("connected")
		local _, rot = target()
		phoneFrame.Rotation = rot
		playLines(c)
	elseif msg.state == "ended" then
		if pendingCall and pendingCall.id == msg.call then
			pendingCall = nil
		end
		if call and call.server and call.id == msg.call then
			endCallUI(msg.outcome)
		end
	end
end

---------------------------------------------------------------- input

local function hookInput()
	local body = phoneFrame.Body
	body.Activated:Connect(function()
		if not isOpen then
			Phone.open()
		end
	end)
	-- Hover lift. Not MouseEnter/Leave: Roblox fires MouseLeave when a GuiObject moves under a still cursor,
	-- so the lift would cancel itself. Instead test the mouse against where the closed phone sits on screen,
	-- with a bigger zone to stay hovered than to start (so the lift can never un-hover itself).
	UserInputService.InputChanged:Connect(function(input)
		if input.UserInputType ~= Enum.UserInputType.MouseMovement then
			return
		end
		local want = false
		if not isOpen and not hidden then
			local vp = viewport()
			local m = UserInputService:GetMouseLocation()
			local w, h = T.DesignSize.X * scale, T.DesignSize.Y * scale
			local right = vp.X - rightInset
			local share = if hovering then T.HoverShare else T.PeekShare
			local top = vp.Y - h * share - (if hovering then 12 else 4)
			want = m.X >= right - w - 8 and m.X <= right + 8 and m.Y >= top
		end
		if want ~= hovering then
			hovering = want
			apply()
		end
	end)

	local keys: { [Enum.KeyCode]: boolean } = {}
	for _, k in T.ToggleKeys do
		keys[k] = true
	end
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		if keys[input.KeyCode] then
			if UserInputService:GetFocusedTextBox() == nil then
				Phone.toggle()
			end
		elseif input.KeyCode == Enum.KeyCode.ButtonB and isOpen then
			Phone.close() -- gamepad: B puts the phone away
		elseif input.UserInputType == Enum.UserInputType.MouseButton1 and isOpen then
			if os.clock() - openedAt <= OPEN_CLICK_GRACE then
				openedAt = os.clock() -- still clicking through: keep ignoring until the clicks pause
			else
				Phone.close() -- clicked the world (clicks on GUI are "processed")
			end
		end
	end)

	-- drag the status bar or the home bar down to put the phone away; tap the home bar to go home
	local s = screen()
	local dragStart: Vector3? = nil
	local dragged = false
	local function beginDrag(input: InputObject)
		if not isOpen then
			return
		end
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragStart = input.Position
			dragged = false
		end
	end
	s.HomeBar.InputBegan:Connect(beginDrag)
	s.StatusBar.InputBegan:Connect(beginDrag)
	UserInputService.InputChanged:Connect(function(input)
		local start = dragStart
		if start and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			if input.Position.Y - start.Y > T.SwipeClosePixels then
				dragStart = nil
				dragged = true
				Phone.close()
			end
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragStart = nil
		end
	end)
	s.HomeBar.Activated:Connect(function()
		if not dragged and isOpen and not call then
			showHome()
		end
		dragged = false
	end)

	-- call buttons
	local cs = s.Call
	cs.Answer.Activated:Connect(function()
		local c = call
		if not c or c.state ~= "ringing" then
			return
		end
		stopRing()
		if c.server then
			action("answerCall", { call = c.id })
		else
			c.state = "connected"
			showCallButtons("connected")
			cs.Status.Text = "On call"
			if c.onAnswer then
				task.spawn(c.onAnswer)
			end
			playLines(c)
		end
	end)
	cs.Decline.Activated:Connect(function()
		local c = call
		if not c or c.state ~= "ringing" then
			return
		end
		if c.server then
			action("declineCall", { call = c.id })
			endCallUI("declined") -- feels instant; the server's "ended" is ignored once call is nil
		else
			if c.onDecline then
				task.spawn(c.onDecline)
			end
			endCallUI("declined")
		end
	end)
	cs.HangUp.Activated:Connect(function()
		local c = call
		if c and c.state == "connected" then
			if c.server then
				action("hangUp", { call = c.id })
			else
				endCallUI("hungUp")
			end
		end
	end)

	-- banner tap opens what it's about
	-- (InputEnded too: on the tilted phone Activated was seen to drop some clicks in play-test)
	local lastBannerTap = 0
	local function bannerTap()
		if os.clock() - lastBannerTap < 0.3 then
			return
		end
		lastBannerTap = os.clock()
		local app = s.Banner:GetAttribute("App")
		if type(app) == "string" and apps[app] then
			local contact = s.Banner:GetAttribute("Contact")
			Phone.open(app, if contact then { contact = contact } else nil)
		end
	end
	s.Banner.Activated:Connect(bannerTap)
	s.Banner.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			bannerTap()
		end
	end)

	-- home icons
	for _, app in PhoneConfig.Apps do
		local icon = s.Home:FindFirstChild("App_" .. app.id, true)
		if not icon then
			icon = Build.appIcon(app, 99)
			icon.Parent = s.Home.Grid
		end
		-- press feel: the tile sinks a little under your finger, springs back on release
		local sq = icon:FindFirstChild("Icon")
		if sq then
			local sc = sq:FindFirstChildOfClass("UIScale") or UIKit.new("UIScale", { Parent = sq })
			icon.MouseButton1Down:Connect(function()
				Motion.tween(sc, Motion.Fast, { Scale = 0.9 })
			end)
			icon.MouseButton1Up:Connect(function()
				Motion.tween(sc, Motion.Fast, { Scale = 1 })
			end)
			icon.MouseLeave:Connect(function()
				Motion.tween(sc, Motion.Fast, { Scale = 1 })
			end)
		end
		icon.Activated:Connect(function()
			if isOpen and not call then
				mountApp(app.id)
			elseif not isOpen then
				Phone.open(app.id)
			end
		end)
	end
end

local function refreshIcons(data: any)
	local installed = (data and data.Phone and data.Phone.Apps) or {}
	for _, app in PhoneConfig.Apps do
		local icon = screen().Home:FindFirstChild("App_" .. app.id, true)
		if icon then
			icon.Visible = apps[app.id] ~= nil and installed[app.id] ~= false
		end
	end
end

---------------------------------------------------------------- server events

local function onPhoneEvent(msg: any)
	if type(msg) ~= "table" or type(msg.type) ~= "string" then
		return
	end
	Phone.ServerEvent:Fire(msg)
	if current then
		local spec = apps[current.id]
		if spec and spec.onEvent then
			task.spawn(spec.onEvent, msg, current.ctx)
		end
	end
	if msg.type == "text" then
		if not msg.silent then
			sfx("PhoneMessage")
			if not isOpen then
				task.delay(0.15, sfx, "PhoneVibrate")
			end
			local inThread = isOpen and current and current.id == "Messages" and current.ctx.args.contact == msg.contact
			if not inThread then
				Phone.notify({ app = "Messages", title = msg.name or "Message", text = msg.text, args = { contact = msg.contact }, glyph = string.sub(msg.name or "?", 1, 1) })
			end
		end
	elseif msg.type == "call" then
		onServerCall(msg)
	elseif msg.type == "notify" then
		Phone.notify({ app = msg.app, title = msg.title, text = msg.text })
	elseif msg.type == "unlockApp" then
		Phone.notify({ app = msg.app, title = "New app", text = tostring(msg.title) .. " is on your phone" })
	elseif msg.type == "open" then
		Phone.open(msg.app)
	end
end

---------------------------------------------------------------- init

local function getGui()
	local pg = player:WaitForChild("PlayerGui")
	local existing = pg:FindFirstChild("MTL_Phone")
	if existing then
		return existing
	end
	local built = Build.build()
	built.Parent = pg
	return built
end

local function loadApps()
	local folder = script.Parent.Parent:FindFirstChild("Apps")
	if not folder then
		return
	end
	for _, m in folder:GetChildren() do
		if m:IsA("ModuleScript") then
			local ok, spec = pcall(require, m)
			if ok and type(spec) == "table" and type(spec.mount) == "function" then
				Phone.registerApp(spec.id or m.Name, spec)
			else
				warn("[MTL Phone] bad app module", m.Name, spec)
			end
		end
	end
end

function Phone.init()
	gui = getGui()
	phoneFrame = gui.Phone
	uiScale = phoneFrame:FindFirstChildOfClass("UIScale") or UIKit.new("UIScale", { Parent = phoneFrame })
	loadApps()
	layout()
	apply(true)
	hookInput()

	local cam = workspace.CurrentCamera
	if cam then
		cam:GetPropertyChangedSignal("ViewportSize"):Connect(function()
			layout()
			apply(true)
		end)
	end
	-- the touch jump button appears late on mobile; re-check the inset now and then
	task.spawn(function()
		while true do
			task.wait(2)
			local r = computeRightInset()
			if r ~= rightInset then
				rightInset = r
				apply()
			end
		end
	end)

	UIState.Changed:Connect(function(state)
		local h = state.hidePhone == true
		if h == hidden then
			return
		end
		hidden = h
		if h and isOpen then
			isOpen = false
			phoneFrame.Body.Modal = false
			showContent()
			Phone.Closed:Fire()
		end
		apply()
		refreshBadge()
		if not h and pendingCall then
			local c = pendingCall
			pendingCall = nil
			pendingOpen = nil
			task.delay(0.4, beginCall, c)
		elseif not h and pendingOpen then
			local o = pendingOpen
			task.delay(0.4, function()
				if pendingOpen == o and not hidden then
					Phone.open(o.app, o.args)
				end
			end)
		end
	end)

	ClientData.Changed:Connect(function(data)
		refreshIcons(data)
		refreshBadge()
		Sfx.setMuted(data and data.Settings and data.Settings.Sound == false or false)
	end)

	-- every button on the phone clicks; Back buttons and toggles get their own sound. A button that plays its
	-- own sound (e.g. the camera shutter) sets the attribute MTL_NoTapSound.
	local function hookButton(b: Instance)
		if not b:IsA("GuiButton") or b == phoneFrame:FindFirstChild("Body") then
			return
		end
		b.Activated:Connect(function()
			if b:GetAttribute("MTL_NoTapSound") then
				return
			end
			sfx(if b.Name == "Back" then "PhoneBack" elseif b.Name == "Toggle" then "PhoneToggle" else "PhoneTap")
		end)
	end
	for _, d in gui:GetDescendants() do
		hookButton(d)
	end
	gui.DescendantAdded:Connect(hookButton)
	Sfx.preload()
	if ClientData.get() then
		refreshIcons(ClientData.get())
		refreshBadge()
	end

	Net.get("PhoneEvent").OnClientEvent:Connect(onPhoneEvent)

	-- clock on the status bar and lock screen (game time)
	task.spawn(function()
		while true do
			local mins = Lighting:GetMinutesAfterMidnight()
			local text = PhoneRules.clock(mins)
			local s = screen()
			s.StatusBar.Time.Text = text
			s.Home.Clock.Text = (string.gsub(text, " [AP]M$", ""))
			local date = s.Home:FindFirstChild("Date")
			if date then
				date.Text = string.upper(os.date("%A, %B ") .. tostring(tonumber(os.date("%d"))))
			end
			task.wait(1)
		end
	end)

	print("[MTL Phone] ready,", (function()
		local n = 0
		for _ in apps do
			n += 1
		end
		return n
	end)(), "apps")
end

return Phone
