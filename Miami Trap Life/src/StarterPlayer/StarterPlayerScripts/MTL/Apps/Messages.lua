--!strict
-- Messages, laid out like a current phone's messenger (iMessage / Google Messages):
--   LIST    big "Messages" title, a search field that filters, one row per conversation: the contact's face,
--           name, time ("9:41 PM" / "Yesterday" / "Mon"), a two-line preview, a blue dot when unread
--   THREAD  pushes in from the right. Header: back chevron (with the unread count of other threads), the contact's
--           face + name + who they are. Grouped bubbles with real curved tails, time separators, Delivered -> Read,
--           animated typing dots, a pill compose field with a round send button, and reply suggestions above it.
-- Texts come from the save snapshot (data.Phone.Texts); opening a thread marks it read (server action readThread).
-- Messages with a link show a button under the bubble (e.g. "Set route"). Faces: UI/Avatars (cutscene rigs).
-- Open straight into a thread: Phone.open("Messages", { contact = "Patel" }).
-- Sending: the player picks a suggestion (Config/Phone.QuickReplies). It types into the field, then Send posts it
-- (server action "quickReply" checks the index). The contact may answer after a "typing" pause.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextService = game:GetService("TextService")
local TweenService = game:GetService("TweenService")

local Avatars = require(ReplicatedStorage.MTL.UI.Avatars)

local App = { id = "Messages", title = "Messages" }

local BUBBLE_MAX = 206
local TEXT_SIZE = 15
local GROUP_GAP = 2 -- between bubbles from the same person
local BLOCK_GAP = 10 -- when the sender changes
local TIME_GAP = 15 * 60 -- show a time separator after this much silence
local COMPOSE_H = 50
local CHIPS_H = 40
local HEADER_H = 74
local PUSH = TweenInfo.new(0.32, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
local FADE = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local POP = TweenInfo.new(0.26, Enum.EasingStyle.Back, Enum.EasingDirection.Out)

local sizeCache: { [string]: Vector2 } = {}

local function name(ctx: any, id: string): string
	if id == "Unknown" then
		return "Unknown number"
	end
	local c = ctx.Story.Contacts[id]
	return if c then c.Name else id
end

local function subtitle(ctx: any, id: string): string
	if id == "Unknown" then
		return "No caller ID"
	end
	local c = ctx.Story.Contacts[id]
	return if c and c.Subtitle then c.Subtitle else "Mobile"
end

local function clock(t: number): string
	local s = os.date("%I:%M %p", t)
	return (string.gsub(s, "^0", ""))
end

local function sameDay(a: number, b: number): boolean
	local x, y = os.date("*t", a), os.date("*t", b)
	return x.year == y.year and x.yday == y.yday
end

-- list time: "9:41 PM" today, "Yesterday", weekday this week, else "10/28/26"
local function listTime(t: number): string
	local now = os.time()
	if t <= 0 then
		return ""
	end
	if sameDay(t, now) then
		return clock(t)
	elseif sameDay(t, now - 86400) then
		return "Yesterday"
	elseif now - t < 6 * 86400 then
		return os.date("%A", t)
	end
	return (string.gsub(os.date("%m/%d/%y", t), "^0", ""))
end

-- separator: "Today 9:41 PM" with the day part bold (rich text)
local function dayLabel(t: number): string
	local now = os.time()
	local day = if sameDay(t, now) then "Today" elseif sameDay(t, now - 86400) then "Yesterday" else os.date("%a, %b %d", t)
	return "<b>" .. day .. "</b> " .. clock(t)
end

local function textSize(ctx: any, text: string): Vector2
	local cached = sizeCache[text]
	if cached then
		return cached
	end
	local ok, bounds = pcall(function()
		local params = Instance.new("GetTextBoundsParams")
		params.Text = text
		params.Font = ctx.Theme.Fonts.Body
		params.Size = TEXT_SIZE
		params.Width = BUBBLE_MAX - 28
		return TextService:GetTextBoundsAsync(params)
	end)
	local v = if ok and bounds then bounds else Vector2.new(math.min(BUBBLE_MAX - 28, #text * 8), TEXT_SIZE + 4)
	sizeCache[text] = v
	return v
end

-- a crisp chevron from two thin bars ("<" when dir = -1, ">" when 1)
local function chevron(ctx: any, parent: Instance, dir: number, color: Color3, size: number, props: { [string]: any }?): Frame
	local UIKit = ctx.UIKit
	local holder = UIKit.new("Frame", {
		Name = "Chevron",
		Size = UDim2.fromOffset(size, size),
		BackgroundTransparency = 1,
		Parent = parent,
	})
	for k, v in props or {} do
		(holder :: any)[k] = v
	end
	local len = math.floor(size * 0.62)
	for i, rot in { 45, -45 } do
		UIKit.new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, 0, 0.5, (if i == 1 then -1 else 1) * math.floor(len * 0.35)),
			Size = UDim2.fromOffset(len, 3),
			Rotation = rot * dir,
			BackgroundColor3 = color,
			BorderSizePixel = 0,
			ZIndex = holder.ZIndex,
			Parent = holder,
		}, { UIKit.corner(UDim.new(1, 0)) })
	end
	return holder
end

-- the screen stack inside the app: push slides the new screen in from the right, pop slides it back out
local function newScreen(ctx: any, screenName: string): Frame
	return ctx.UIKit.new("Frame", {
		Name = screenName,
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = ctx.Theme.Phone.Screen,
		BorderSizePixel = 0,
		ClipsDescendants = true,
		Parent = ctx.frame,
	})
end

local function transition(ctx: any, incoming: Frame, forward: boolean)
	local old = ctx.screen :: Frame?
	ctx.screen = incoming
	if not old or not old.Parent then
		return
	end
	if ctx.Phone.reducedMotion and ctx.Phone.reducedMotion() then
		old:Destroy()
		return
	end
	if forward then
		incoming.Position = UDim2.fromScale(1, 0)
		incoming.ZIndex = old.ZIndex + 1
		TweenService:Create(incoming, PUSH, { Position = UDim2.fromScale(0, 0) }):Play()
		TweenService:Create(old, PUSH, { Position = UDim2.fromScale(-0.3, 0) }):Play()
	else
		old.ZIndex = incoming.ZIndex + 1
		incoming.Position = UDim2.fromScale(-0.3, 0)
		TweenService:Create(incoming, PUSH, { Position = UDim2.fromScale(0, 0) }):Play()
		TweenService:Create(old, PUSH, { Position = UDim2.fromScale(1, 0) }):Play()
	end
	task.delay(PUSH.Time + 0.02, function()
		if old.Parent then
			old:Destroy()
		end
	end)
end

local showList: (ctx: any, back: boolean?) -> ()

---------------------------------------------------------------- conversation

local function bubble(ctx: any, parent: Instance, msg: any, order: number, contact: string, index: number, tail: boolean, gapAfter: number): Frame
	local UIKit, Theme = ctx.UIKit, ctx.Theme
	local P = Theme.Phone
	local me = msg.me == true
	local holder = UIKit.new("Frame", {
		Name = "Message",
		LayoutOrder = order,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Parent = parent,
	}, {
		UIKit.new("UIListLayout", {
			HorizontalAlignment = if me then Enum.HorizontalAlignment.Right else Enum.HorizontalAlignment.Left,
			Padding = UDim.new(0, 4),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
		UIKit.new("UIPadding", {
			PaddingLeft = UDim.new(0, 14),
			PaddingRight = UDim.new(0, 14),
			PaddingBottom = UDim.new(0, gapAfter),
		}),
	})
	local ts = textSize(ctx, msg.text)
	-- generous slack: the phone is drawn scaled, and scaled text renders a little wider than measured
	local w = math.min(BUBBLE_MAX, math.ceil(ts.X * 1.08) + 30)
	local color = if me then P.BubbleMe else P.Bubble
	local b = UIKit.new("Frame", {
		Name = "Bubble",
		LayoutOrder = 1,
		Size = UDim2.fromOffset(w, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = color,
		ZIndex = 2,
		Parent = holder,
	}, { UIKit.corner(UDim.new(0, 18)), UIKit.padding(13, 8) })
	UIKit.new("TextLabel", {
		Name = "Text",
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		FontFace = Theme.Fonts.Body,
		Text = msg.text,
		TextColor3 = if me then P.BubbleMeText else Theme.Colors.Text,
		TextSize = TEXT_SIZE,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 5,
		Parent = b,
	})
	if tail then
		-- the curved tail: a round nub of the bubble's colour, with a background-coloured circle biting its top
		-- (ignores the bubble's padding: the pieces sit outside the padded area via negative offsets)
		local box = UIKit.new("Frame", {
			Name = "Tail",
			AnchorPoint = if me then Vector2.new(0, 1) else Vector2.new(1, 1),
			Position = if me then UDim2.new(1, 13 - 9, 1, 8) else UDim2.new(0, -13 + 9, 1, 8),
			Size = UDim2.fromOffset(20, 20),
			BackgroundTransparency = 1,
			ZIndex = 1,
			Parent = b,
		})
		UIKit.new("Frame", {
			Name = "Nub",
			Position = if me then UDim2.fromOffset(-2, 0) else UDim2.fromOffset(2, 0),
			Size = UDim2.fromOffset(20, 20),
			BackgroundColor3 = color,
			BorderSizePixel = 0,
			ZIndex = 1,
			Parent = box,
		}, { UIKit.corner(UDim.new(0, 6)) })
		UIKit.new("Frame", {
			Name = "Bite",
			Position = if me then UDim2.fromOffset(9, -6) else UDim2.fromOffset(-9, -6),
			Size = UDim2.fromOffset(20, 20),
			BackgroundColor3 = P.Screen,
			BorderSizePixel = 0,
			ZIndex = 3,
			Parent = box,
		}, { UIKit.corner(UDim.new(1, 0)) })
	end
	if type(msg.link) == "table" then
		local label = if msg.link.kind == "waypoint" then "Set route: " .. (msg.link.label or "location") else "Open"
		local btn = UIKit.new("TextButton", {
			Name = "Link",
			LayoutOrder = 2,
			Size = UDim2.fromOffset(BUBBLE_MAX, 36),
			BackgroundColor3 = P.Card,
			AutoButtonColor = false,
			FontFace = Theme.Fonts.Bold,
			Text = label,
			TextColor3 = Theme.Colors.Accent,
			TextSize = 13,
			Parent = holder,
		}, { UIKit.corner(UDim.new(0, 14)), UIKit.stroke(0.86) })
		UIKit.feedback(btn, P.Card, P.CardHover)
		btn.Activated:Connect(function()
			ctx.action("openLink", { contact = contact, index = index })
		end)
	end
	return holder
end

local function separator(ctx: any, parent: Instance, text: string, order: number)
	ctx.UIKit.new("TextLabel", {
		Name = "Time",
		LayoutOrder = order,
		Size = UDim2.new(1, 0, 0, 30),
		BackgroundTransparency = 1,
		FontFace = ctx.Theme.Fonts.Body,
		RichText = true,
		Text = text,
		TextColor3 = ctx.Theme.Colors.TextDim,
		TextSize = 11,
		Parent = parent,
	})
end

-- the round blue send button with a drawn up-arrow
local function sendButton(ctx: any, parent: Instance): (TextButton, (boolean) -> ())
	local UIKit, Theme = ctx.UIKit, ctx.Theme
	local P, C = Theme.Phone, Theme.Colors
	local btn = UIKit.new("TextButton", {
		Name = "Send",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -6, 0.5, 0),
		Size = UDim2.fromOffset(30, 30),
		BackgroundColor3 = P.CardHover,
		AutoButtonColor = false,
		Text = "",
		ZIndex = 3,
		Parent = parent,
	}, { UIKit.corner(UDim.new(1, 0)) })
	btn:SetAttribute("MTL_NoTapSound", true)
	local function bar(x: number, y: number, w: number, h: number, rot: number)
		UIKit.new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, x, 0.5, y),
			Size = UDim2.fromOffset(w, h),
			Rotation = rot,
			BackgroundColor3 = Color3.new(1, 1, 1),
			BorderSizePixel = 0,
			ZIndex = 4,
			Parent = btn,
		}, { UIKit.corner(UDim.new(1, 0)) })
	end
	bar(0, 1, 3, 14, 0) -- stem
	bar(-3, -3, 3, 10, 45) -- head
	bar(3, -3, 3, 10, -45)
	local function set(ready: boolean)
		TweenService:Create(btn, FADE, { BackgroundColor3 = if ready then P.BubbleMe else P.CardHover }):Play()
		btn.Active = ready
	end
	set(false)
	return btn, set
end

local function showThread(ctx: any, contact: string)
	ctx.args.contact = contact
	local UIKit, Theme = ctx.UIKit, ctx.Theme
	local P, C = Theme.Phone, Theme.Colors
	local token = {}
	ctx.threadToken = token
	local scr = newScreen(ctx, "Thread_" .. contact)

	-- header: < (n)   [face] name  >   who they are
	local header = UIKit.new("Frame", {
		Name = "Header",
		Size = UDim2.new(1, 0, 0, HEADER_H),
		BackgroundColor3 = P.Frame,
		BackgroundTransparency = 0.04,
		ZIndex = 10,
		Parent = scr,
	})
	UIKit.new("Frame", {
		Name = "Line",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0, 1),
		BackgroundColor3 = P.Line,
		BackgroundTransparency = 0.9,
		BorderSizePixel = 0,
		ZIndex = 10,
		Parent = header,
	})
	local back = UIKit.new("TextButton", {
		Name = "Back",
		Position = UDim2.fromOffset(4, 14),
		Size = UDim2.fromOffset(64, 40),
		BackgroundTransparency = 1,
		Text = "",
		ZIndex = 11,
		Parent = header,
	})
	chevron(ctx, back, -1, C.Accent, 20, { Position = UDim2.fromOffset(4, 10), ZIndex = 11 })
	local backCount = UIKit.new("TextLabel", {
		Name = "Count",
		Position = UDim2.fromOffset(24, 0),
		Size = UDim2.new(1, -24, 1, 0),
		BackgroundTransparency = 1,
		FontFace = Theme.Fonts.Body,
		Text = "",
		TextColor3 = C.Accent,
		TextSize = 15,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 11,
		Parent = back,
	})
	back.Activated:Connect(function()
		ctx.args.contact = nil
		showList(ctx, true)
	end)
	Avatars.make(header, contact, 38, { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 8), ZIndex = 11 })
	UIKit.new("TextLabel", {
		Name = "Name",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 49),
		Size = UDim2.new(1, -120, 0, 14),
		BackgroundTransparency = 1,
		FontFace = Theme.Fonts.Bold,
		Text = name(ctx, contact),
		TextColor3 = C.Text,
		TextSize = 12,
		TextTruncate = Enum.TextTruncate.AtEnd,
		ZIndex = 11,
		Parent = header,
	})
	UIKit.new("TextLabel", {
		Name = "Sub",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 61),
		Size = UDim2.new(1, -120, 0, 11),
		BackgroundTransparency = 1,
		FontFace = Theme.Fonts.Body,
		Text = subtitle(ctx, contact),
		TextColor3 = C.TextDim,
		TextSize = 9,
		TextTruncate = Enum.TextTruncate.AtEnd,
		ZIndex = 11,
		Parent = header,
	})

	-- conversation
	local list = UIKit.new("ScrollingFrame", {
		Name = "Thread",
		Position = UDim2.fromOffset(0, HEADER_H),
		Size = UDim2.new(1, 0, 1, -HEADER_H - COMPOSE_H - CHIPS_H),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		ScrollBarThickness = 3,
		ScrollBarImageTransparency = 0.7,
		ElasticBehavior = Enum.ElasticBehavior.Always,
		Parent = scr,
	}, {
		UIKit.new("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder }),
		UIKit.new("UIPadding", { PaddingTop = UDim.new(0, 8), PaddingBottom = UDim.new(0, 12) }),
	})
	local first = true
	local function toBottom()
		task.defer(function()
			if not list.Parent then
				return
			end
			local y = math.max(0, list.AbsoluteCanvasSize.Y - list.AbsoluteWindowSize.Y)
			if first then
				first = false
				list.CanvasPosition = Vector2.new(0, y)
			else
				TweenService:Create(list, PUSH, { CanvasPosition = Vector2.new(0, y) }):Play()
			end
		end)
	end

	-- reply suggestions (what the player can say), like a keyboard's suggestion strip
	local chips = UIKit.new("ScrollingFrame", {
		Name = "Replies",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 0, 1, -COMPOSE_H),
		Size = UDim2.new(1, 0, 0, CHIPS_H),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.X,
		ScrollingDirection = Enum.ScrollingDirection.X,
		ScrollBarThickness = 0,
		Parent = scr,
	}, {
		UIKit.new("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 6),
		}),
		UIKit.new("UIPadding", { PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12) }),
	})

	-- compose bar: ( Text Message          (^) )
	local bar = UIKit.new("Frame", {
		Name = "Compose",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0, COMPOSE_H),
		BackgroundColor3 = P.Frame,
		BackgroundTransparency = 0.04,
		Parent = scr,
	})
	local pill = UIKit.new("Frame", {
		Name = "Pill",
		Position = UDim2.fromOffset(12, 7),
		Size = UDim2.new(1, -24, 0, 36),
		BackgroundColor3 = P.Screen,
		Parent = bar,
	}, { UIKit.corner(UDim.new(1, 0)), UIKit.stroke(0.8) })
	local field = UIKit.new("TextLabel", {
		Name = "Field",
		Position = UDim2.fromOffset(14, 0),
		Size = UDim2.new(1, -54, 1, 0),
		BackgroundTransparency = 1,
		FontFace = Theme.Fonts.Body,
		Text = "Text Message",
		TextColor3 = C.TextDim,
		TextSize = 15,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Parent = pill,
	})
	local send, setReady = sendButton(ctx, pill)

	local draft: number? = nil -- index into QuickReplies typed into the field
	local typingDraft = false
	local lastSent = -1e9
	local function setDraft(i: number?, partial: string?)
		draft = i
		local ready = i ~= nil and not typingDraft
		if i then
			field.Text = (partial or ctx.Config.QuickReplies[i]) .. (if typingDraft then "|" else "")
			field.TextColor3 = C.Text
		else
			field.Text = "Text Message"
			field.TextColor3 = C.TextDim
		end
		setReady(ready)
	end
	for i, text in ctx.Config.QuickReplies do
		local chip = UIKit.new("TextButton", {
			Name = "Reply",
			LayoutOrder = i,
			Size = UDim2.fromOffset(0, 30),
			AutomaticSize = Enum.AutomaticSize.X,
			BackgroundColor3 = P.Card,
			AutoButtonColor = false,
			FontFace = Theme.Fonts.Body,
			Text = text,
			TextColor3 = C.Text,
			TextSize = 13,
			Parent = chips,
		}, { UIKit.corner(UDim.new(1, 0)), UIKit.padding(14, 0, 0), UIKit.stroke(0.84) })
		UIKit.feedback(chip, P.Card, P.CardHover)
		chip:SetAttribute("MTL_NoTapSound", true)
		chip.Activated:Connect(function()
			if typingDraft then
				return
			end
			-- types it into the field a few letters at a time (key taps), then Send lights up
			typingDraft = true
			task.spawn(function()
				local n = #text
				local step = math.max(1, n // 6)
				local k = 0
				while k < n do
					if ctx.threadToken ~= token then
						return
					end
					k = math.min(n, k + step)
					setDraft(i, string.sub(text, 1, k))
					ctx.sfx("PhoneType")
					task.wait(0.045 + math.random() * 0.03)
				end
				typingDraft = false
				setDraft(i)
			end)
		end)
	end
	send.Activated:Connect(function()
		if not draft or typingDraft or os.clock() - lastSent < ctx.Config.ReplyCooldown then
			return
		end
		lastSent = os.clock()
		local i = draft
		ctx.sfx("PhoneSend")
		ctx.action("quickReply", { contact = contact, index = i })
		setDraft(nil)
	end)

	-- typing dots (animated) when the contact is about to answer
	local typing: Frame? = nil
	local typingToken = {}
	local function showTyping(on: boolean)
		typingToken = {}
		if typing then
			typing:Destroy()
			typing = nil
		end
		if not on or not list.Parent then
			return
		end
		local mine = typingToken
		local holder = UIKit.new("Frame", {
			Name = "Typing",
			LayoutOrder = 1000000,
			Size = UDim2.new(1, 0, 0, 44),
			BackgroundTransparency = 1,
			Parent = list,
		}, { UIKit.new("UIPadding", { PaddingLeft = UDim.new(0, 14) }) })
		typing = holder
		local b = UIKit.new("Frame", {
			Name = "Bubble",
			Position = UDim2.fromOffset(0, 6),
			Size = UDim2.fromOffset(62, 34),
			BackgroundColor3 = P.Bubble,
			Parent = holder,
		}, { UIKit.corner(UDim.new(1, 0)) })
		UIKit.new("Frame", {
			Name = "Dot1",
			Position = UDim2.fromOffset(-4, 24),
			Size = UDim2.fromOffset(11, 11),
			BackgroundColor3 = P.Bubble,
			BorderSizePixel = 0,
			Parent = b,
		}, { UIKit.corner(UDim.new(1, 0)) })
		UIKit.new("Frame", {
			Name = "Dot2",
			Position = UDim2.fromOffset(-9, 32),
			Size = UDim2.fromOffset(5, 5),
			BackgroundColor3 = P.Bubble,
			BorderSizePixel = 0,
			Parent = b,
		}, { UIKit.corner(UDim.new(1, 0)) })
		local dots = {}
		for d = 1, 3 do
			dots[d] = UIKit.new("Frame", {
				Name = "Dot",
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.new(0, 16 + (d - 1) * 15, 0.5, 0),
				Size = UDim2.fromOffset(8, 8),
				BackgroundColor3 = C.TextDim,
				BorderSizePixel = 0,
				Parent = b,
			}, { UIKit.corner(UDim.new(1, 0)) })
		end
		local s = UIKit.new("UIScale", { Scale = 0.6, Parent = b })
		TweenService:Create(s, POP, { Scale = 1 }):Play()
		task.spawn(function()
			local t0 = os.clock()
			while typingToken == mine and holder.Parent do
				local t = os.clock() - t0
				for d, dot in dots do
					local k = math.max(0, math.sin(t * 6.5 - d * 0.9))
					dot.BackgroundTransparency = 0.55 - k * 0.55
					dot.Position = UDim2.new(0, 16 + (d - 1) * 15, 0.5, -k * 2.5)
				end
				task.wait()
			end
		end)
		toBottom()
	end
	ctx.showTyping = function(c: string)
		if c == contact and ctx.threadToken == token then
			showTyping(true)
			task.delay(5, function()
				if ctx.threadToken == token then
					showTyping(false)
				end
			end)
		end
	end

	local shown = -1
	local receiptToken = {}
	local function render(d: any)
		if ctx.threadToken ~= token or not scr.Parent then
			return
		end
		-- other threads' unread count on the back button, like a real phone
		local others = 0
		for id, n in (d.Phone.Unread or {}) do
			if id ~= contact then
				others += n
			end
		end
		backCount.Text = if others > 0 then tostring(others) else ""

		local thread = d.Phone.Texts and d.Phone.Texts[contact] or {}
		if #thread == shown then
			return -- nothing new in this conversation
		end
		local grew = shown >= 0 and #thread > shown
		shown = #thread
		-- the contact's reply replaces the dots; my own new message must not wipe them (they arrive right after)
		local keepTyping = typing ~= nil and thread[#thread] ~= nil and thread[#thread].me == true
		if not keepTyping then
			showTyping(false)
		elseif typing then
			typing.Parent = nil
		end
		for _, c in list:GetChildren() do
			if c:IsA("GuiObject") then
				c:Destroy()
			end
		end
		if #thread == 0 then
			UIKit.empty(list, "No messages yet.")
		end
		local order = 0
		local lastHolder: Frame? = nil
		receiptToken = {}
		for i, msg in thread do
			local prev, nextMsg = thread[i - 1], thread[i + 1]
			local t = msg.t or 0
			if not prev or (t - (prev.t or 0)) >= TIME_GAP then
				order += 1
				separator(ctx, list, if t > 0 then dayLabel(t) else "", order)
			end
			local sameNext = nextMsg ~= nil and (nextMsg.me == true) == (msg.me == true) and ((nextMsg.t or 0) - t) < TIME_GAP
			order += 1
			lastHolder = bubble(ctx, list, msg, order, contact, i, not sameNext, if sameNext then GROUP_GAP else BLOCK_GAP)
			if msg.me and i == #thread then
				order += 1
				local receipt = UIKit.new("TextLabel", {
					Name = "Receipt",
					LayoutOrder = order,
					Size = UDim2.new(1, -16, 0, 14),
					BackgroundTransparency = 1,
					FontFace = Theme.Fonts.Body,
					RichText = true,
					Text = "Delivered",
					TextColor3 = C.TextDim,
					TextSize = 10,
					TextXAlignment = Enum.TextXAlignment.Right,
					Parent = list,
				})
				-- Delivered, then Read a moment later (they've seen it)
				local mine = receiptToken
				local function toRead()
					if receiptToken == mine and receipt.Parent then
						receipt.Text = "<b>Read</b> " .. clock(math.max(t, os.time() - 1))
					end
				end
				local age = os.time() - t
				if age >= 3 then
					toRead()
				else
					task.delay(2.2, toRead)
				end
			end
		end
		if keepTyping and typing then
			typing.Parent = list
		end
		-- the newest bubble pops in from its sender's side
		if grew and lastHolder then
			local bb = lastHolder:FindFirstChild("Bubble") :: GuiObject?
			if bb then
				local s = UIKit.new("UIScale", { Scale = 0.8, Parent = bb })
				TweenService:Create(s, POP, { Scale = 1 }):Play()
			end
		end
		toBottom()
		if d.Phone.Unread and (d.Phone.Unread[contact] or 0) > 0 then
			ctx.action("readThread", { contact = contact })
		end
	end
	transition(ctx, scr, ctx.screen ~= nil)
	ctx.onData(render)
end

---------------------------------------------------------------- conversation list

function showList(ctx: any, back: boolean?)
	ctx.showTyping = nil
	local UIKit, Theme = ctx.UIKit, ctx.Theme
	local P, C = Theme.Phone, Theme.Colors
	local token = {}
	ctx.threadToken = token
	local scr = newScreen(ctx, "List")

	UIKit.new("TextLabel", {
		Name = "Title",
		Position = UDim2.fromOffset(16, 6),
		Size = UDim2.new(1, -32, 0, 40),
		BackgroundTransparency = 1,
		FontFace = Theme.Fonts.Display,
		Text = "Messages",
		TextColor3 = C.Text,
		TextSize = 30,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = scr,
	})
	-- search: filters by name and message text as you type
	local search = UIKit.new("Frame", {
		Name = "Search",
		Position = UDim2.fromOffset(14, 50),
		Size = UDim2.new(1, -28, 0, 34),
		BackgroundColor3 = P.Card,
		Parent = scr,
	}, { UIKit.corner(UDim.new(0, 10)) })
	-- magnifier: a ring and a handle
	UIKit.new("Frame", {
		Name = "Lens",
		Position = UDim2.fromOffset(11, 9),
		Size = UDim2.fromOffset(12, 12),
		BackgroundTransparency = 1,
		Parent = search,
	}, { UIKit.corner(UDim.new(1, 0)), UIKit.new("UIStroke", { Color = C.TextDim, Thickness = 2 }) })
	UIKit.new("Frame", {
		Name = "Handle",
		Position = UDim2.fromOffset(20, 21),
		Size = UDim2.fromOffset(6, 2),
		Rotation = 45,
		BackgroundColor3 = C.TextDim,
		BorderSizePixel = 0,
		Parent = search,
	})
	local box = UIKit.new("TextBox", {
		Name = "Box",
		Position = UDim2.fromOffset(32, 0),
		Size = UDim2.new(1, -40, 1, 0),
		BackgroundTransparency = 1,
		ClearTextOnFocus = false,
		FontFace = Theme.Fonts.Body,
		PlaceholderText = "Search",
		PlaceholderColor3 = C.TextDim,
		Text = "",
		TextColor3 = C.Text,
		TextSize = 15,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = search,
	})

	local list = UIKit.new("ScrollingFrame", {
		Name = "Threads",
		Position = UDim2.fromOffset(0, 92),
		Size = UDim2.new(1, 0, 1, -92),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 3,
		ScrollBarImageTransparency = 0.7,
		ElasticBehavior = Enum.ElasticBehavior.Always,
		Parent = scr,
	}, { UIKit.new("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder }) })

	local lastData: any = nil
	local lastKey = ""
	local function render(d: any, force: boolean?)
		if ctx.threadToken ~= token or not scr.Parent then
			return
		end
		lastData = d
		local threads = ctx.Rules.threads(d.Phone)
		local query = string.lower(box.Text)
		-- rebuild only when something visible changed (no flicker on unrelated saves)
		local parts = { query }
		for _, th in threads do
			table.insert(parts, th.contact .. ":" .. tostring(th.t) .. ":" .. th.unread .. ":" .. tostring(#(d.Phone.Texts[th.contact] or {})))
		end
		local key = table.concat(parts, "|")
		if key == lastKey and not force then
			return
		end
		lastKey = key
		for _, c in list:GetChildren() do
			if c:IsA("GuiObject") then
				c:Destroy()
			end
		end
		if #threads == 0 then
			UIKit.empty(list, "No messages yet. People text you as the story moves on.")
			return
		end
		local shownRows = 0
		for i, th in threads do
			local who = name(ctx, th.contact)
			local preview = (if th.last.me then "You: " else "") .. th.last.text
			if query ~= "" and not string.find(string.lower(who .. " " .. preview), query, 1, true) then
				continue
			end
			shownRows += 1
			local unread = th.unread > 0
			local row = UIKit.new("TextButton", {
				Name = "Thread_" .. th.contact,
				LayoutOrder = i,
				Size = UDim2.new(1, 0, 0, 76),
				BackgroundColor3 = P.CardHover,
				BackgroundTransparency = 1,
				AutoButtonColor = false,
				Text = "",
				Parent = list,
			})
			row.MouseEnter:Connect(function()
				TweenService:Create(row, FADE, { BackgroundTransparency = 0.55 }):Play()
			end)
			row.MouseLeave:Connect(function()
				TweenService:Create(row, FADE, { BackgroundTransparency = 1 }):Play()
			end)
			if unread then
				UIKit.new("Frame", {
					Name = "Unread",
					AnchorPoint = Vector2.new(0.5, 0.5),
					Position = UDim2.new(0, 9, 0.5, 0),
					Size = UDim2.fromOffset(9, 9),
					BackgroundColor3 = C.Accent,
					BorderSizePixel = 0,
					Parent = row,
				}, { UIKit.corner(UDim.new(1, 0)) })
			end
			Avatars.make(row, th.contact, 50, { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 18, 0.5, 0) })
			UIKit.new("TextLabel", {
				Name = "Name",
				Position = UDim2.fromOffset(80, 13),
				Size = UDim2.new(1, -150, 0, 19),
				BackgroundTransparency = 1,
				FontFace = Theme.Fonts.Bold,
				Text = who,
				TextColor3 = C.Text,
				TextSize = 15,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextTruncate = Enum.TextTruncate.AtEnd,
				Parent = row,
			})
			UIKit.new("TextLabel", {
				Name = "When",
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.new(1, -28, 0, 14),
				Size = UDim2.fromOffset(80, 16),
				BackgroundTransparency = 1,
				FontFace = Theme.Fonts.Body,
				Text = listTime(th.t),
				TextColor3 = C.TextDim,
				TextSize = 12,
				TextXAlignment = Enum.TextXAlignment.Right,
				Parent = row,
			})
			chevron(ctx, row, 1, C.TextDim, 12, { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -12, 0, 16) })
			UIKit.new("TextLabel", {
				Name = "Preview",
				Position = UDim2.fromOffset(80, 33),
				Size = UDim2.new(1, -104, 0, 34),
				BackgroundTransparency = 1,
				FontFace = Theme.Fonts.Body,
				Text = preview,
				TextColor3 = if unread then C.Text else C.TextDim,
				TextSize = 13,
				TextWrapped = true,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextYAlignment = Enum.TextYAlignment.Top,
				TextTruncate = Enum.TextTruncate.AtEnd,
				Parent = row,
			})
			UIKit.new("Frame", {
				Name = "Line",
				AnchorPoint = Vector2.new(0, 1),
				Position = UDim2.new(0, 80, 1, 0),
				Size = UDim2.new(1, -80, 0, 1),
				BackgroundColor3 = P.Line,
				BackgroundTransparency = 0.92,
				BorderSizePixel = 0,
				Parent = row,
			})
			row.Activated:Connect(function()
				showThread(ctx, th.contact)
			end)
		end
		if shownRows == 0 then
			UIKit.empty(list, "No results for \"" .. box.Text .. "\"")
		end
	end
	box:GetPropertyChangedSignal("Text"):Connect(function()
		if lastData then
			render(lastData)
		end
	end)
	transition(ctx, scr, false)
	if not back then
		-- first open: no slide
		scr.Position = UDim2.fromScale(0, 0)
	end
	ctx.onData(render)
end

function App.mount(_frame: Frame, ctx: any)
	ctx.screen = nil
	if ctx.args.contact then
		showThread(ctx, ctx.args.contact)
	else
		showList(ctx)
	end
end

-- a text arriving while Messages is open: the list/thread re-renders from the snapshot; only banner if it's
-- for another thread
function App.onEvent(msg: any, ctx: any)
	if msg.type == "typing" and ctx.showTyping and ctx.args.contact == msg.contact then
		ctx.showTyping(msg.contact)
		return
	end
	-- only while the phone is up (when it's down the controller already shows the linked banner); tapping it
	-- jumps to that thread
	if msg.type == "text" and not msg.silent and ctx.Phone.isOpen() and ctx.args.contact ~= msg.contact then
		ctx.Phone.notify({
			app = "Messages",
			title = msg.name or "Message",
			text = msg.text,
			args = { contact = msg.contact },
			contact = msg.contact,
			glyph = string.sub(msg.name or "?", 1, 1),
			force = true,
		})
	end
end

return App
