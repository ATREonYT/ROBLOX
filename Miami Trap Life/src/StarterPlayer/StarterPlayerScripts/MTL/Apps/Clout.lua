--!nonstrict
-- CLOUT: the social app (Config/Social, Rules/SocialRules, server SocialService; design in vault
-- "Research/Social Media Hustle.md"). Runs in the phone and, wide, in the desk computer's browser
-- (the computer piece mounts this module with ctx.args.desktop = true; any frame wider than 520 px goes wide).
--
-- Tabs: Feed (real players in the server + NPC creators; like, follow) · Spots (where to shoot today, GPS) ·
-- ＋ Shoot (the phone becomes a viewfinder: live chips for spot / car / light / trend / collab, a framing meter,
-- shutter, caption, post) · Deals (brand offers from 1K) · Me (profile, posts, earnings, Creator Studio: courses,
-- 7-day income chart, bot shop). After posting, the result screen counts views, likes and followers up and says
-- why the post did well or badly.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Net = require(ReplicatedStorage.MTL.Net)
local Social = require(ReplicatedStorage.MTL.Config.Social)
local SocialRules = require(ReplicatedStorage.MTL.Rules.SocialRules)
local Vehicles = require(ReplicatedStorage.MTL.Config.Vehicles)
local CloutArt = require(ReplicatedStorage.MTL.UI.CloutArt)

local App = { id = Social.AppId, title = "Clout" }

local player = Players.LocalPlayer
local C = Color3.fromRGB

-- the app's own look (a real social app has its own brand inside the phone): near-black, white type, one pink.
local K = {
	Bg = C(8, 8, 10),
	Card = C(20, 20, 24),
	Card2 = C(30, 30, 36),
	Line = C(255, 255, 255),
	Text = C(245, 245, 247),
	Dim = C(150, 150, 160),
	Brand = C(255, 46, 99),
	Money = C(114, 214, 112),
	Gold = C(255, 196, 64),
	Blue = C(80, 170, 255),
	Head = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Heavy),
	Bold = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Bold),
	Body = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Medium),
}

---------------------------------------------------------------- shared state (lives while the game runs)
local S = {
	market = nil,
	nextDayAt = 0, -- os.clock() when the next Clout day starts
	feed = {},
	leaders = {},
	liked = {},
	followed = {},
	captures = {}, -- [postId] = contentId of the real screenshot (this session, this device)
	result = nil, -- last post result (the result screen)
	scout = nil,
	recording = nil,
	unlocked = false,
}
local listeners: { [any]: (string, any) -> () } = {}
local remoteAction: RemoteEvent? = nil
local connected = false

local function emit(kind: string, payload: any)
	for _, fn in listeners do
		task.spawn(fn, kind, payload)
	end
end

local function act(t: string, payload: any?)
	local p = payload or {}
	p.type = t
	if remoteAction then
		remoteAction:FireServer(p)
	end
end

local function onState(m: any)
	if type(m) ~= "table" then
		return
	end
	if m.type == "hello" then
		S.market = m.market
		S.nextDayAt = os.clock() + (m.nextDayIn or 0)
		S.feed = m.feed or {}
		S.leaders = m.leaders or {}
		S.liked = m.liked or {}
		S.unlocked = m.unlocked
	elseif m.type == "market" then
		S.market = m.market
		S.nextDayAt = os.clock() + (m.nextDayIn or 0)
	elseif m.type == "feedPost" then
		for _, p in S.feed do
			if p.id == m.post.id then
				return
			end
		end
		table.insert(S.feed, 1, m.post)
		while #S.feed > 60 do
			table.remove(S.feed)
		end
	elseif m.type == "feedLike" then
		for _, p in S.feed do
			if p.id == m.id then
				p.likes = m.likes
			end
		end
	elseif m.type == "leaders" then
		S.leaders = m.leaders or {}
	elseif m.type == "followed" then
		S.followed[m.userId] = true
	elseif m.type == "scout" then
		S.scout = m
	elseif m.type == "recording" then
		S.recording = if m.cancel then nil else m
		if S.recording then
			S.recording.readyAt = os.clock() + (m.seconds or 6)
		end
	elseif m.type == "launched" then
		S.recording = nil
	elseif m.type == "posted" then
		S.result = m
		S.result.startedAt = os.clock()
	end
	emit(m.type, m)
end

local function connect()
	if connected then
		return
	end
	connected = true
	task.spawn(function()
		local ok, ev = pcall(Net.get, "SocialState")
		if ok and ev then
			ev.OnClientEvent:Connect(onState)
		end
		local ok2, a = pcall(Net.get, "SocialAction")
		if ok2 and a then
			remoteAction = a
			act("sync")
		end
	end)
end

---------------------------------------------------------------- little UI kit (this app's look)

local function new(className: string, props: { [string]: any }, children: { Instance }?): any
	local inst = Instance.new(className)
	for k, v in props do
		if k ~= "Parent" then
			inst[k] = v
		end
	end
	for _, ch in children or {} do
		ch.Parent = inst
	end
	if props.Parent then
		inst.Parent = props.Parent
	end
	return inst
end

local function corner(r: number): UICorner
	return new("UICorner", { CornerRadius = UDim.new(0, r) })
end

local function pad(l: number, t: number?, r: number?, b: number?): UIPadding
	return new("UIPadding", {
		PaddingLeft = UDim.new(0, l),
		PaddingTop = UDim.new(0, t or l),
		PaddingRight = UDim.new(0, r or l),
		PaddingBottom = UDim.new(0, b or t or l),
	})
end

local function vlist(gap: number?): UIListLayout
	return new("UIListLayout", { Padding = UDim.new(0, gap or 0), SortOrder = Enum.SortOrder.LayoutOrder })
end

local function hlist(gap: number?, align: any?): UIListLayout
	return new("UIListLayout", {
		Padding = UDim.new(0, gap or 0),
		FillDirection = Enum.FillDirection.Horizontal,
		SortOrder = Enum.SortOrder.LayoutOrder,
		VerticalAlignment = align or Enum.VerticalAlignment.Center,
	})
end

local function text(parent: Instance, str: string, o: any?): TextLabel
	o = o or {}
	return new("TextLabel", {
		Name = o.name or "Text",
		LayoutOrder = o.order or 0,
		Size = o.sizeU or UDim2.new(1, 0, 0, 0),
		Position = o.pos or UDim2.new(),
		AnchorPoint = o.anchor or Vector2.new(),
		AutomaticSize = o.auto or Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		FontFace = if o.head then K.Head elseif o.bold then K.Bold else K.Body,
		Text = str,
		RichText = o.rich or false,
		TextSize = o.size or 13,
		TextColor3 = o.color or (if o.dim then K.Dim else K.Text),
		TextWrapped = o.wrap ~= false,
		TextXAlignment = o.align or Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Center,
		TextTransparency = o.alpha or 0,
		ZIndex = o.z or 2,
		Parent = parent,
	})
end

local function button(parent: Instance, str: string, o: any?): TextButton
	o = o or {}
	local style = o.style or "brand"
	local bg = if style == "brand" then K.Brand elseif style == "light" then K.Text elseif style == "money" then K.Money else K.Card2
	local fg = if style == "light" or style == "money" then C(10, 10, 12) else K.Text
	local b = new("TextButton", {
		Name = o.name or "Button",
		LayoutOrder = o.order or 0,
		Size = o.sizeU or UDim2.new(1, 0, 0, o.height or 38),
		Position = o.pos or UDim2.new(),
		AnchorPoint = o.anchor or Vector2.new(),
		BackgroundColor3 = bg,
		BackgroundTransparency = if o.disabled then 0.6 else 0,
		AutoButtonColor = false,
		FontFace = K.Bold,
		Text = str,
		TextSize = o.size or 14,
		TextColor3 = fg,
		TextTransparency = if o.disabled then 0.4 else 0,
		ZIndex = o.z or 3,
		Parent = parent,
	}, { corner(o.radius or 10) })
	if o.onClick and not o.disabled then
		b.Activated:Connect(o.onClick)
	end
	-- press feedback: a quick scale
	local scale = new("UIScale", { Parent = b })
	b.MouseButton1Down:Connect(function()
		TweenService:Create(scale, TweenInfo.new(0.08), { Scale = 0.96 }):Play()
	end)
	b.MouseButton1Up:Connect(function()
		TweenService:Create(scale, TweenInfo.new(0.16, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	end)
	b.MouseLeave:Connect(function()
		scale.Scale = 1
	end)
	return b
end

local function card(parent: Instance, order: number, name: string?, color: Color3?): Frame
	return new("Frame", {
		Name = name or "Card",
		LayoutOrder = order,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = color or K.Card,
		Parent = parent,
	}, { corner(12), pad(12), vlist(6) })
end

local function chip(parent: Instance, str: string, color: Color3?, order: number?, filled: boolean?): TextLabel
	local l = new("TextLabel", {
		Name = "Chip",
		LayoutOrder = order or 0,
		Size = UDim2.fromOffset(0, 22),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundColor3 = color or K.Card2,
		BackgroundTransparency = if filled == false then 1 else 0,
		FontFace = K.Bold,
		Text = str,
		TextSize = 11,
		TextColor3 = if filled == false then (color or K.Text) else K.Text,
		ZIndex = 4,
		Parent = parent,
	}, { corner(11), pad(9, 0, 9, 0) })
	if filled == false then
		new("UIStroke", { Color = color or K.Line, Transparency = 0.3, Thickness = 1, Parent = l })
	end
	return l
end

local function scroller(parent: Instance, top: number, bottom: number, name: string?): ScrollingFrame
	return new("ScrollingFrame", {
		Name = name or "Scroll",
		Position = UDim2.fromOffset(0, top),
		Size = UDim2.new(1, 0, 1, -(top + bottom)),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 2,
		ScrollBarImageColor3 = K.Line,
		ScrollBarImageTransparency = 0.6,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		Parent = parent,
	}, { pad(10, 8, 10, 14), vlist(10) })
end

local function ago(t: number?): string
	local s = os.time() - (t or os.time())
	if s < 60 then
		return "now"
	elseif s < 3600 then
		return math.floor(s / 60) .. "m"
	elseif s < 86400 then
		return math.floor(s / 3600) .. "h"
	end
	return math.floor(s / 86400) .. "d"
end

local function money(n: number): string
	local s = tostring(math.floor(n))
	local out = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return "$" .. (string.gsub(out, "^,", ""))
end

local function countdown(sec: number): string
	sec = math.max(0, math.floor(sec))
	return string.format("%d:%02d", sec // 60, sec % 60)
end

local function myAccount(d: any): any
	return (d and d.Social) or { Real = 0, Bots = 0, Posts = {}, Courses = {}, Deals = { Offers = {} }, Earned = {}, History = {}, Today = {} }
end

---------------------------------------------------------------- one post (feed card)

local function postCard(parent: Instance, order: number, post: any, ctx: any, compact: boolean?, viewport: boolean)
	local f = new("Frame", {
		Name = "Post_" .. tostring(post.id),
		LayoutOrder = order,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Parent = parent,
	}, { vlist(6) })
	-- header: avatar, handle, check, place
	local head = new("Frame", { Name = "Head", LayoutOrder = 1, Size = UDim2.new(1, 0, 0, 34), BackgroundTransparency = 1, Parent = f })
	CloutArt.avatar(head, post, 30, 3)
	local spot = Social.spot(post.spot)
	local who = text(head, "<b>" .. (post.handle or "?") .. "</b>" .. (if post.verified then '  <font color="#50AAFF">✔</font>' else "") .. (if post.npc then "" else '  <font color="#FF2E63">●</font>'), {
		rich = true,
		size = 13,
		pos = UDim2.fromOffset(40, 0),
		sizeU = UDim2.new(1, -110, 0, 18),
		auto = Enum.AutomaticSize.None,
	})
	local _ = who
	text(head, (if post.spot ~= "" then "📍 " .. spot.label else "") .. (if post.with and #post.with > 0 then "  · with " .. table.concat(post.with, ", ") else ""), {
		size = 11,
		dim = true,
		pos = UDim2.fromOffset(40, 17),
		sizeU = UDim2.new(1, -110, 0, 15),
		auto = Enum.AutomaticSize.None,
		wrap = false,
	})
	-- follow (real players only)
	if not post.npc and post.userId and post.userId ~= player.UserId then
		local followed = S.followed[post.userId]
		button(head, if followed then "Following" else "Follow", {
			style = if followed then "dark" else "brand",
			sizeU = UDim2.fromOffset(70, 26),
			pos = UDim2.new(1, -70, 0, 4),
			size = 12,
			radius = 8,
			disabled = followed,
			onClick = function()
				ctx.sfx("PhoneTap")
				act("follow", { userId = post.userId })
			end,
		})
	else
		text(head, ago(post.t), { size = 11, dim = true, pos = UDim2.new(1, -40, 0, 8), sizeU = UDim2.fromOffset(40, 16), auto = Enum.AutomaticSize.None, align = Enum.TextXAlignment.Right })
	end
	-- the picture (square)
	local pic = new("Frame", {
		Name = "Picture",
		LayoutOrder = 2,
		Size = UDim2.fromScale(1, 1),
		SizeConstraint = Enum.SizeConstraint.RelativeXX,
		BackgroundColor3 = K.Card,
		ClipsDescendants = true,
		Parent = f,
	}, { corner(14) })
	local art = CloutArt.draw(pic, post, { capture = S.captures[post.id], viewport = viewport })
	new("UICorner", { CornerRadius = UDim.new(0, 14), Parent = art })
	if post.outcome == "viral" then
		chip(pic, "🔥 VIRAL", K.Brand, 0).Position = UDim2.fromOffset(8, 8)
	end
	-- double-tap to like (like the real thing)
	local tap = new("TextButton", { Name = "Tap", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "", ZIndex = 30, Parent = pic })
	local lastTap = 0
	-- actions row
	local row = new("Frame", { Name = "Actions", LayoutOrder = 3, Size = UDim2.new(1, 0, 0, 24), BackgroundTransparency = 1, Parent = f }, { hlist(14) })
	local liked = S.liked[post.id]
	local heart = new("TextButton", {
		Name = "Like",
		LayoutOrder = 1,
		Size = UDim2.fromOffset(0, 24),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundTransparency = 1,
		FontFace = K.Bold,
		Text = (if liked then "❤️ " else "🤍 ") .. SocialRules.short(post.likes or 0),
		TextSize = 13,
		TextColor3 = K.Text,
		Parent = row,
	})
	local function like()
		if S.liked[post.id] or post.userId == player.UserId then
			return
		end
		S.liked[post.id] = true
		post.likes = (post.likes or 0) + 1
		heart.Text = "❤️ " .. SocialRules.short(post.likes)
		ctx.sfx("PhoneTap")
		act("like", { id = post.id })
		-- big heart pop on the picture
		local big = text(pic, "❤️", { size = 64, align = Enum.TextXAlignment.Center, sizeU = UDim2.fromScale(1, 1), auto = Enum.AutomaticSize.None, z = 31 })
		local sc = new("UIScale", { Scale = 0.4, Parent = big })
		TweenService:Create(sc, TweenInfo.new(0.25, Enum.EasingStyle.Back), { Scale = 1.2 }):Play()
		task.delay(0.45, function()
			TweenService:Create(big, TweenInfo.new(0.25), { TextTransparency = 1 }):Play()
			task.delay(0.3, function()
				big:Destroy()
			end)
		end)
	end
	heart.Activated:Connect(like)
	tap.Activated:Connect(function()
		if os.clock() - lastTap < 0.35 then
			like()
		end
		lastTap = os.clock()
	end)
	text(row, "💬 " .. SocialRules.short(post.commentCount or post.comments or 0), { order = 2, size = 13, bold = true, sizeU = UDim2.fromOffset(0, 24), auto = Enum.AutomaticSize.X, wrap = false })
	text(row, "👁 " .. SocialRules.short(post.views or 0), { order = 3, size = 13, bold = true, sizeU = UDim2.fromOffset(0, 24), auto = Enum.AutomaticSize.X, wrap = false, color = K.Dim })
	-- caption + comments
	text(f, "<b>" .. (post.handle or "") .. "</b>  " .. (post.caption or "") .. "  <font color=\"#9696A0\">" .. spot.tag .. "</font>", { order = 4, rich = true, size = 13 })
	if not compact and type(post.comments) == "table" then
		for i, cm in post.comments do
			if i > 2 then
				break
			end
			text(f, "<b>" .. cm.who .. "</b>  " .. cm.text, { order = 4 + i, rich = true, size = 12, color = K.Dim })
		end
	end
	return f
end

---------------------------------------------------------------- screens

local Screens = {}

local function header(ctx: any, title: string?, right: string?)
	local h = new("Frame", { Name = "TopBar", Size = UDim2.new(1, 0, 0, 44), BackgroundColor3 = K.Bg, ZIndex = 5, Parent = ctx.body })
	new("Frame", { Name = "Rule", Position = UDim2.new(0, 0, 1, -1), Size = UDim2.new(1, 0, 0, 1), BackgroundColor3 = K.Line, BackgroundTransparency = 0.92, BorderSizePixel = 0, ZIndex = 5, Parent = h })
	if title then
		text(h, title, { head = true, size = 18, pos = UDim2.fromOffset(12, 0), sizeU = UDim2.new(1, -24, 1, 0), auto = Enum.AutomaticSize.None, z = 6 })
	else
		-- the wordmark
		local w = text(h, "CLOUT", { head = true, size = 22, pos = UDim2.fromOffset(12, 0), sizeU = UDim2.new(0, 120, 1, 0), auto = Enum.AutomaticSize.None, z = 6 })
		new("UIGradient", { Color = ColorSequence.new(C(255, 46, 99), C(255, 150, 60)), Parent = w })
	end
	if right then
		text(h, right, { size = 11, bold = true, dim = true, pos = UDim2.new(1, -12, 0, 0), anchor = Vector2.new(1, 0), sizeU = UDim2.new(0, 180, 1, 0), auto = Enum.AutomaticSize.None, align = Enum.TextXAlignment.Right, z = 6, rich = true })
	end
	return h
end

-- "Today on Clout": trend, mood, the clock
local function todayCard(parent: Instance, order: number, ctx: any)
	local mk = S.market
	if not mk then
		return
	end
	local c = card(parent, order, "Today", K.Card)
	local top = new("Frame", { Name = "Row", LayoutOrder = 1, Size = UDim2.new(1, 0, 0, 18), BackgroundTransparency = 1, Parent = c })
	text(top, "TODAY ON CLOUT", { size = 11, bold = true, color = K.Brand, sizeU = UDim2.new(0.6, 0, 1, 0), auto = Enum.AutomaticSize.None })
	local clock = text(top, "", { size = 11, bold = true, dim = true, pos = UDim2.fromScale(1, 0), anchor = Vector2.new(1, 0), sizeU = UDim2.new(0.5, 0, 1, 0), auto = Enum.AutomaticSize.None, align = Enum.TextXAlignment.Right })
	local function tick()
		clock.Text = "new day in " .. countdown(S.nextDayAt - os.clock())
	end
	tick()
	task.spawn(function()
		while clock.Parent do
			task.wait(1)
			tick()
		end
	end)
	local spot = Social.spot(mk.trendSpot)
	text(c, "🔥 <b>" .. spot.tag .. "</b> is trending  ·  posts at " .. spot.label .. " get x" .. Social.Post.TrendSpot, { order = 2, rich = true, size = 13 })
	local fmt = Social.format(mk.trendFormat)
	text(c, "📈 Algorithm: <b>" .. tostring(mk.moodLabel) .. "</b> (" .. string.format("x%.2f", mk.mood) .. ")  ·  " .. (if fmt then fmt.label else "?") .. " posts are hot", { order = 3, rich = true, size = 12, dim = true })
	local up, down = {}, {}
	for _, t in Social.CourseTopics do
		local v = mk.demand and mk.demand[t.id] or 1
		if v >= 1.25 then
			table.insert(up, t.title)
		elseif v <= 0.7 then
			table.insert(down, t.title)
		end
	end
	if #up > 0 then
		text(c, "<font color=\"#72D670\">▲</font> Course buyers want: " .. table.concat(up, ", "), { order = 4, rich = true, size = 11, dim = true })
	end
	if #down > 0 then
		text(c, "<font color=\"#FF2E63\">▼</font> Nobody's buying: " .. table.concat(down, ", "), { order = 5, rich = true, size = 11, dim = true })
	end
end

function Screens.feed(ctx: any)
	header(ctx, nil, "")
	local list = scroller(ctx.body, 44, 0, "Feed")
	local order = 0
	local function o()
		order += 1
		return order
	end
	todayCard(list, o(), ctx)
	-- stories-style row: creators in this server
	if #S.leaders > 0 then
		local row = new("ScrollingFrame", {
			Name = "Creators",
			LayoutOrder = o(),
			Size = UDim2.new(1, 0, 0, 74),
			BackgroundTransparency = 1,
			ScrollBarThickness = 0,
			AutomaticCanvasSize = Enum.AutomaticSize.X,
			CanvasSize = UDim2.new(),
			ScrollingDirection = Enum.ScrollingDirection.X,
			Parent = list,
		}, { hlist(10, Enum.VerticalAlignment.Top) })
		for i, l in S.leaders do
			local cell = new("Frame", { LayoutOrder = i, Size = UDim2.fromOffset(58, 74), BackgroundTransparency = 1, Parent = row })
			local ring = new("Frame", { Size = UDim2.fromOffset(52, 52), Position = UDim2.fromOffset(3, 0), BackgroundColor3 = K.Brand, Parent = cell }, { corner(26) })
			new("UIGradient", { Color = ColorSequence.new(C(255, 46, 99), C(255, 170, 60)), Rotation = 45, Parent = ring })
			local av = CloutArt.avatar(ring, { userId = l.userId, handle = l.handle }, 46, 3)
			av.Position = UDim2.fromOffset(3, 3)
			text(cell, (if i == 1 then "👑 " else "") .. SocialRules.short(l.followers), { size = 10, bold = true, pos = UDim2.fromOffset(0, 54), sizeU = UDim2.new(1, 0, 0, 14), auto = Enum.AutomaticSize.None, align = Enum.TextXAlignment.Center, wrap = false })
		end
	end
	if #S.feed == 0 then
		text(list, "Nothing yet. Be the first to post in this server.", { order = o(), dim = true, size = 13, align = Enum.TextXAlignment.Center })
	end
	for i, p in S.feed do
		if i > 25 then
			break
		end
		postCard(list, o(), p, ctx, false, i <= 6)
	end
end

function Screens.spots(ctx: any)
	header(ctx, "Spots", "where to shoot")
	local list = scroller(ctx.body, 44, 0, "Spots")
	local d = ctx.data()
	local acc = myAccount(d)
	local mk = S.market
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	local here = root and root.Position
	local entries = {}
	for _, s in Social.Spots do
		local dist = if here then (Vector3.new(here.X, 0, here.Z) - Vector3.new(s.pos.X, 0, s.pos.Z)).Magnitude else 0
		table.insert(entries, { s = s, dist = dist })
	end
	table.sort(entries, function(a, b)
		local ta = mk and mk.trendSpot == a.s.id
		local tb = mk and mk.trendSpot == b.s.id
		if ta ~= tb then
			return ta
		end
		return a.s.score > b.s.score
	end)
	text(list, "Better spots and better light = more reach. A new spot each post beats posting the same place.", { order = 0, size = 12, dim = true })
	local today = acc.SpotsToday and acc.SpotsToday.ids or {}
	for i, e in entries do
		local s = e.s
		local c = card(list, i, "Spot_" .. s.id)
		local strip = new("Frame", { Name = "Thumb", LayoutOrder = 0, Size = UDim2.new(1, 0, 0, 70), BackgroundTransparency = 1, ClipsDescendants = true, Parent = c }, { corner(10) })
		local art = CloutArt.draw(strip, { spot = s.id, seed = i * 97, phase = "Evening" }, { viewport = false })
		new("UICorner", { CornerRadius = UDim.new(0, 10), Parent = art })
		local stars = string.rep("★", math.clamp(math.floor((s.score - 0.4) * 3.2 + 0.5), 1, 5))
		text(c, "<b>" .. s.label .. "</b>  <font color=\"#FFC440\">" .. stars .. "</font>", { order = 1, rich = true, size = 15 })
		local bits = { s.tag }
		for phase, m in s.light or {} do
			table.insert(bits, (if phase == "Evening" then "golden hour" else string.lower(phase)) .. " x" .. m)
		end
		if s.needsCar then
			table.insert(bits, "bring the car")
		end
		text(c, table.concat(bits, "  ·  "), { order = 2, size = 11, dim = true })
		local status = {}
		if mk and mk.trendSpot == s.id then
			table.insert(status, '<font color="#FF2E63">🔥 TRENDING x' .. Social.Post.TrendSpot .. "</font>")
		end
		if today[s.id] then
			table.insert(status, "✓ posted here today")
		elseif not (acc.SpotsEver and acc.SpotsEver[s.id]) then
			table.insert(status, '<font color="#72D670">new spot +' .. Social.Post.XPNewSpot .. " XP</font>")
		end
		if here then
			table.insert(status, math.floor(e.dist) .. " studs away")
		end
		text(c, table.concat(status, "  ·  "), { order = 3, size = 11, rich = true, bold = true })
		button(c, "Set GPS", {
			order = 4,
			style = "dark",
			height = 32,
			size = 13,
			onClick = function()
				ctx.sfx("PhoneTap")
				act("gps", { spot = s.id })
			end,
		})
	end
end

---------------------------------------------------------------- shoot

local shootConn: RBXScriptConnection? = nil

local function myCar(): Model?
	local folder = workspace:FindFirstChild(Vehicles.SpawnFolder or "MTL_SpawnedCars")
	if not folder then
		return nil
	end
	for _, m in folder:GetChildren() do
		if m:IsA("Model") and m:GetAttribute("MTL_Owner") == player.UserId then
			return m
		end
	end
	return nil
end

-- framing 0..1: the subject near a rule-of-thirds point and a good size in the frame
local function framingScore(format: string): (number, string)
	local cam = workspace.CurrentCamera
	if not cam then
		return 0.5, ""
	end
	local subject: Vector3? = nil
	local idealDist = 22
	if format == "CarFlex" then
		local car = myCar()
		if car then
			subject = car:GetPivot().Position
			idealDist = 26
		end
	end
	if not subject then
		local head = player.Character and player.Character:FindFirstChild("Head")
		if head and head:IsA("BasePart") then
			subject = head.Position
			idealDist = 12
		end
	end
	if not subject then
		return 0.5, ""
	end
	local v, on = cam:WorldToViewportPoint(subject)
	if not on then
		return 0.1, "Subject out of frame"
	end
	local vs = cam.ViewportSize
	local x, y = v.X / vs.X, v.Y / vs.Y
	local best = 1
	for _, tx in { 1 / 3, 0.5, 2 / 3 } do
		for _, ty in { 1 / 3, 0.5, 2 / 3 } do
			best = math.min(best, math.sqrt((x - tx) ^ 2 + (y - ty) ^ 2))
		end
	end
	local thirds = math.clamp(1 - best / 0.3, 0, 1)
	local dist = (cam.CFrame.Position - subject).Magnitude
	local size = math.clamp(1 - math.abs(dist - idealDist) / (idealDist * 1.2), 0, 1)
	local score = 0.6 * thirds + 0.4 * size
	local hint = if size < 0.4 then (if dist > idealDist then "Get closer" else "Back up a bit") elseif thirds < 0.4 then "Line it up on a grid point" else "Looks good"
	return score, hint
end

local function stopShoot(ctx: any)
	if shootConn then
		shootConn:Disconnect()
		shootConn = nil
	end
	ctx.Phone.setViewfinder(false)
end

function Screens.shoot(ctx: any)
	local d = ctx.data()
	local acc = myAccount(d)
	ctx.Phone.setViewfinder(true)
	ctx.body.BackgroundTransparency = 1
	local f = ctx.body
	-- thirds grid
	for i = 1, 2 do
		new("Frame", { Name = "GridV", Position = UDim2.fromScale(i / 3, 0), Size = UDim2.new(0, 1, 1, 0), BackgroundColor3 = K.Line, BackgroundTransparency = 0.7, BorderSizePixel = 0, Parent = f })
		new("Frame", { Name = "GridH", Position = UDim2.fromScale(0, i / 3), Size = UDim2.new(1, 0, 0, 1), BackgroundColor3 = K.Line, BackgroundTransparency = 0.7, BorderSizePixel = 0, Parent = f })
	end
	-- close
	button(f, "✕", { style = "dark", sizeU = UDim2.fromOffset(32, 32), pos = UDim2.fromOffset(8, 8), radius = 16, size = 14, onClick = function()
		stopShoot(ctx)
		ctx.go("feed")
	end })
	-- live chips (what the server sees)
	local chips = new("Frame", { Name = "Chips", Position = UDim2.fromOffset(48, 10), Size = UDim2.new(1, -56, 0, 60), BackgroundTransparency = 1, Parent = f }, {
		new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Wraps = true, Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	-- deal hint
	local dealLine = text(f, "", { size = 12, bold = true, pos = UDim2.new(0, 10, 1, -190), sizeU = UDim2.new(1, -20, 0, 18), auto = Enum.AutomaticSize.None, align = Enum.TextXAlignment.Center, color = K.Gold, z = 5 })
	-- framing meter
	local meter = new("Frame", { Name = "Framing", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -164), Size = UDim2.new(0.7, 0, 0, 4), BackgroundColor3 = C(0, 0, 0), BackgroundTransparency = 0.4, Parent = f }, { corner(2) })
	local fill = new("Frame", { Name = "Fill", Size = UDim2.fromScale(0.5, 1), BackgroundColor3 = K.Text, Parent = meter }, { corner(2) })
	local hint = text(f, "", { size = 11, bold = true, pos = UDim2.new(0, 10, 1, -160), sizeU = UDim2.new(1, -20, 0, 16), auto = Enum.AutomaticSize.None, align = Enum.TextXAlignment.Center, z = 5 })
	new("UIStroke", { Transparency = 0.5, Parent = hint })
	-- formats
	ctx.format = ctx.format or "CarFlex"
	local fmts = new("ScrollingFrame", { Name = "Formats", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -122), Size = UDim2.new(1, -10, 0, 30), BackgroundTransparency = 1, ScrollBarThickness = 0, AutomaticCanvasSize = Enum.AutomaticSize.X, CanvasSize = UDim2.new(), ScrollingDirection = Enum.ScrollingDirection.X, Parent = f }, { hlist(6) })
	local fmtButtons = {}
	for i, fm in Social.Formats do
		local b = new("TextButton", { Name = "Format_" .. fm.id, LayoutOrder = i, Size = UDim2.fromOffset(0, 26), AutomaticSize = Enum.AutomaticSize.X, BackgroundColor3 = C(0, 0, 0), BackgroundTransparency = 0.45, AutoButtonColor = false, FontFace = K.Bold, Text = fm.label, TextSize = 12, TextColor3 = K.Text, Parent = fmts }, { corner(13), pad(10, 0, 10, 0) })
		fmtButtons[fm.id] = b
		b.Activated:Connect(function()
			ctx.format = fm.id
			ctx.sfx("PhoneTap")
		end)
	end
	-- shutter
	local shutter = new("TextButton", { Name = "Shutter", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -30), Size = UDim2.fromOffset(74, 74), BackgroundColor3 = K.Text, AutoButtonColor = false, Text = "", Parent = f }, { corner(37), new("UIStroke", { Color = K.Brand, Thickness = 4 }) })
	local inner = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(58, 58), BackgroundColor3 = K.Text, Parent = shutter }, { corner(29) })
	local _ = inner
	local cooldownLabel = text(f, "", { size = 11, bold = true, pos = UDim2.new(0, 10, 1, -24), sizeU = UDim2.new(1, -20, 0, 16), auto = Enum.AutomaticSize.None, align = Enum.TextXAlignment.Center, color = K.Dim })

	local function refreshChips()
		for _, c in chips:GetChildren() do
			if c:IsA("TextLabel") then
				c:Destroy()
			end
		end
		local sc = S.scout
		if not sc then
			chip(chips, "Checking the spot...", C(0, 0, 0), 1)
			return
		end
		local spot = Social.spot(sc.spot)
		chip(chips, (if sc.spot ~= "" then "📍 " .. spot.label .. " x" .. spot.score else "📍 No photo spot here"), if sc.spot ~= "" then C(0, 0, 0) else K.Brand, 1)
		local light = spot.light and spot.light[sc.phase]
		if light then
			chip(chips, (if sc.phase == "Evening" then "🌇 Golden hour" elseif sc.phase == "Night" then "🌃 Night lights" else "☀️ Good light") .. " x" .. light, C(0, 0, 0), 2)
		end
		if sc.car then
			chip(chips, "🚗 Car in the shot", C(0, 0, 0), 3)
		elseif spot.needsCar then
			chip(chips, "🚗 Bring your car", K.Brand, 3)
		end
		if (sc.collab or 0) > 0 then
			chip(chips, "👥 Collab x" .. sc.collab, C(0, 0, 0), 4)
		end
		if S.market and S.market.trendSpot == sc.spot then
			chip(chips, "🔥 Trending", K.Brand, 5)
		end
		if acc.SpotsToday and acc.SpotsToday.ids and sc.spot ~= "" and not acc.SpotsToday.ids[sc.spot] then
			chip(chips, "✨ Fresh today", C(0, 0, 0), 6)
		end
		-- formats that can't work here dim out
		for id, b in fmtButtons do
			local fm = Social.format(id)
			local ok = true
			if fm.needsCar and not sc.car then
				ok = false
			elseif fm.needsCollab and (sc.collab or 0) == 0 then
				ok = false
			elseif fm.atDesk and not sc.desk then
				ok = false
			end
			b.TextTransparency = if ok then 0 else 0.55
			b.BackgroundColor3 = if ctx.format == id then K.Brand else C(0, 0, 0)
			b.BackgroundTransparency = if ctx.format == id then 0 else 0.45
		end
		local deal = acc.Deals and acc.Deals.Active
		if deal then
			local ds = Social.spot(deal.spot)
			local here = sc.spot == deal.spot and (not deal.car or sc.car ~= nil)
			dealLine.Text = if here then "💼 This post completes your " .. ((Social.brand(deal.brand) or {}).name or "brand") .. " deal (" .. money(deal.pay) .. ")" else "💼 Deal: post at " .. ds.label .. (if deal.car then " with your car" else "")
		else
			dealLine.Text = ""
		end
	end
	refreshChips()
	ctx.listen(function(kind)
		if kind == "scout" and f.Parent then
			refreshChips()
		end
	end)
	-- poll the server for what's in the shot; animate the framing meter
	local lastScout = 0
	shootConn = RunService.RenderStepped:Connect(function()
		if not f.Parent then
			return
		end
		if os.clock() - lastScout > 1.5 then
			lastScout = os.clock()
			act("scout")
		end
		local score, h = framingScore(ctx.format)
		ctx.framing = score
		fill.Size = UDim2.fromScale(math.clamp(score, 0.03, 1), 1)
		fill.BackgroundColor3 = if score > 0.7 then K.Money elseif score > 0.4 then K.Gold else K.Brand
		hint.Text = h
		local wait = (ctx.lastPostAt or 0) + Social.Post.Cooldown - os.clock()
		cooldownLabel.Text = if wait > 0 then ("Next post in " .. math.ceil(wait) .. " s") else ""
	end)
	ctx.track(shootConn)

	local busy = false
	shutter.Activated:Connect(function()
		if busy then
			return
		end
		local wait = (ctx.lastPostAt or 0) + Social.Post.Cooldown - os.clock()
		if wait > 0 then
			ctx.sfx("Error")
			return
		end
		busy = true
		ctx.sfx("PhoneShutter")
		local framing = ctx.framing or 0.5
		local captured: string? = nil
		local ok, cs = pcall(function()
			return game:GetService("CaptureService")
		end)
		if ok and cs then
			ctx.Phone.setCaptureHidden(true)
			RunService.RenderStepped:Wait()
			local done = false
			pcall(function()
				cs:CaptureScreenshot(function(id)
					captured = if id then tostring(id) else nil
					done = true
				end)
			end)
			local t0 = os.clock()
			while not done and os.clock() - t0 < 1.5 do
				task.wait()
			end
			ctx.Phone.setCaptureHidden(false)
		end
		-- flash
		local fl = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = C(255, 255, 255), BackgroundTransparency = 0.1, ZIndex = 50, Parent = f })
		TweenService:Create(fl, TweenInfo.new(0.4), { BackgroundTransparency = 1 }):Play()
		task.wait(0.25)
		busy = false
		stopShoot(ctx)
		ctx.pending = { framing = framing, capture = captured, format = ctx.format, scout = S.scout }
		ctx.go("caption")
	end)
end

function Screens.caption(ctx: any)
	local pend = ctx.pending
	if not pend then
		ctx.go("feed")
		return
	end
	local d = ctx.data()
	local acc = myAccount(d)
	header(ctx, "New post")
	local list = scroller(ctx.body, 44, 0, "Caption")
	local sc = pend.scout or {}
	local format = pend.format
	local fm = Social.format(format)
	-- the server falls back to a location post if the format can't work here: show that honestly
	if fm and ((fm.needsCar and not sc.car) or (fm.needsCollab and (sc.collab or 0) == 0) or (fm.atDesk and not sc.desk)) then
		format = "Spot"
	end
	local preview = new("Frame", { Name = "Preview", LayoutOrder = 1, Size = UDim2.new(1, 0, 1, 0), SizeConstraint = Enum.SizeConstraint.RelativeXX, BackgroundColor3 = K.Card, ClipsDescendants = true, Parent = list }, { corner(14) })
	local art = CloutArt.draw(preview, { spot = sc.spot or "", car = sc.car, userId = player.UserId, format = format, seed = 7, phase = sc.phase }, { capture = pend.capture })
	new("UICorner", { CornerRadius = UDim.new(0, 14), Parent = art })
	local deal = acc.Deals and acc.Deals.Active
	local dealHere = deal and sc.spot == deal.spot and (not deal.car or sc.car ~= nil)
	pend.deal = dealHere and true or false
	local captions = if pend.deal then Social.Captions.Sponsored else (Social.Captions[format] or Social.Captions.Spot)
	pend.caption = pend.caption or 1
	text(list, "PICK A CAPTION", { order = 2, size = 11, bold = true, color = K.Brand })
	local capButtons = {}
	for i, cap in captions do
		local b = new("TextButton", { Name = "Caption" .. i, LayoutOrder = 2 + i, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundColor3 = if pend.caption == i then K.Card2 else K.Card, AutoButtonColor = false, FontFace = K.Body, Text = cap, TextSize = 13, TextColor3 = K.Text, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, Parent = list }, { corner(10), pad(12, 10) })
		if pend.caption == i then
			new("UIStroke", { Color = K.Brand, Thickness = 1.5, Parent = b })
		end
		capButtons[i] = b
		b.Activated:Connect(function()
			pend.caption = i
			ctx.sfx("PhoneTap")
			ctx.go("caption")
		end)
	end
	if pend.deal and deal then
		text(list, "💼 Paid partnership with " .. ((Social.brand(deal.brand) or {}).name or "a brand") .. " · " .. money(deal.pay) .. " on posting", { order = 20, size = 12, bold = true, color = K.Gold })
	end
	button(list, "Share", { order = 30, height = 44, size = 16, onClick = function()
		ctx.sfx("PhoneSend")
		act("post", { format = format, caption = pend.caption, framing = pend.framing, deal = pend.deal })
		ctx.lastPostAt = os.clock()
		ctx.waitingResult = true
		ctx.go("posting")
	end })
	button(list, "Retake", { order = 31, style = "dark", height = 36, onClick = function()
		ctx.go("shoot")
	end })
end

function Screens.posting(ctx: any)
	header(ctx, "Posting...")
	text(ctx.body, "Uploading", { size = 16, bold = true, pos = UDim2.fromScale(0.5, 0.45), anchor = Vector2.new(0.5, 0.5), sizeU = UDim2.new(1, 0, 0, 20), auto = Enum.AutomaticSize.None, align = Enum.TextXAlignment.Center })
	local bar = new("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0.52), Size = UDim2.new(0.6, 0, 0, 4), BackgroundColor3 = K.Card2, Parent = ctx.body }, { corner(2) })
	local fill = new("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = K.Brand, Parent = bar }, { corner(2) })
	TweenService:Create(fill, TweenInfo.new(1.2, Enum.EasingStyle.Quad), { Size = UDim2.fromScale(0.9, 1) }):Play()
	ctx.listen(function(kind, m)
		if kind == "posted" and ctx.screen == "posting" then
			if ctx.pending and ctx.pending.capture then
				S.captures[m.post.id] = ctx.pending.capture
			end
			ctx.pending = nil
			task.wait(0.4)
			ctx.go("result")
		elseif kind == "postFail" and ctx.screen == "posting" then
			if not m.shown then ctx.toast(m.reason or "Couldn't post") end
			ctx.go("shoot")
		end
	end)
end

-- the payoff: numbers climb, outcome banner, why it did what it did
function Screens.result(ctx: any)
	local r = S.result
	if not r then
		ctx.go("feed")
		return
	end
	local res, post = r.result, r.post
	header(ctx, "Your post", "")
	local list = scroller(ctx.body, 44, 0, "Result")
	local pic = new("Frame", { Name = "Picture", LayoutOrder = 1, Size = UDim2.new(1, 0, 1, 0), SizeConstraint = Enum.SizeConstraint.RelativeXX, BackgroundColor3 = K.Card, ClipsDescendants = true, Parent = list }, { corner(14) })
	local art = CloutArt.draw(pic, post, { capture = S.captures[post.id] })
	new("UICorner", { CornerRadius = UDim.new(0, 14), Parent = art })
	-- outcome
	local outcomes = {
		viral = { "🔥 YOU WENT VIRAL", K.Brand, "x" .. tostring(res.luck) .. " reach. The algorithm picked you." },
		hot = { "📈 IT'S POPPING", K.Gold, "x" .. tostring(res.luck) .. " reach. People are sharing it." },
		flop = { "🥶 IT FLOPPED", K.Dim, "Bad timing. Not every post lands." },
		normal = { "POSTED", K.Text, "A solid post." },
	}
	local oc = outcomes[res.outcome] or outcomes.normal
	local band = new("Frame", { Name = "Outcome", LayoutOrder = 2, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundColor3 = if res.outcome == "viral" then K.Brand else K.Card, Parent = list }, { corner(12), pad(12), vlist(2) })
	local title = text(band, oc[1], { head = true, size = 20, color = if res.outcome == "viral" then K.Text else oc[2], order = 1 })
	text(band, oc[3], { size = 12, order = 2, color = if res.outcome == "viral" then K.Text else K.Dim })
	if res.outcome == "viral" then
		local sc = new("UIScale", { Scale = 0.6, Parent = title })
		TweenService:Create(sc, TweenInfo.new(0.5, Enum.EasingStyle.Elastic), { Scale = 1 }):Play()
	end
	-- counters
	local grid = new("Frame", { Name = "Counters", LayoutOrder = 3, Size = UDim2.new(1, 0, 0, 66), BackgroundTransparency = 1, Parent = list }, {
		new("UIGridLayout", { CellSize = UDim2.new(0.5, -4, 0, 30), CellPadding = UDim2.fromOffset(8, 6), SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	local counters = {}
	for i, k in { { "views", "👁 views", K.Text }, { "likes", "❤️ likes", K.Text }, { "gained", "➕ followers", K.Brand }, { "comments", "💬 comments", K.Text } } do
		local l = new("TextLabel", { LayoutOrder = i, BackgroundColor3 = K.Card, FontFace = K.Bold, Text = "0", TextSize = 14, TextColor3 = k[3], Parent = grid }, { corner(8) })
		counters[k[1]] = { label = l, target = res[k[1]] or 0, suffix = " " .. k[2] }
	end
	local t0 = r.startedAt or os.clock()
	local dur = math.max(8, math.min(res.rollout or 75, 40)) -- on screen: up to 40 s, mostly in the first seconds
	local function stepCounters()
		local t = math.clamp((os.clock() - t0) / dur, 0, 1)
		local e = 1 - (1 - t) ^ 3
		for _, c in counters do
			c.label.Text = SocialRules.short(math.floor(c.target * e)) .. c.suffix
		end
		return t >= 1
	end
	stepCounters()
	ctx.track(RunService.Heartbeat:Connect(function()
		if grid.Parent then
			stepCounters()
		end
	end))
	-- rewards
	local rw = card(list, 4, "Rewards")
	text(rw, "REWARDS", { size = 11, bold = true, color = K.Brand, order = 1 })
	text(rw, "+" .. (res.xp or 0) .. " XP" .. (if (res.fund or 0) > 0 then "   ·   Creator Fund +" .. money(res.fund) else ""), { size = 15, bold = true, color = K.Money, order = 2 })
	if (res.deal or 0) > 0 then
		text(rw, "💼 " .. ((Social.brand(res.brand) or {}).name or "Brand") .. " paid " .. money(res.deal), { size = 15, bold = true, color = K.Gold, order = 3 })
	end
	-- why
	local why = card(list, 5, "Why")
	text(why, "WHY IT DID THIS", { size = 11, bold = true, color = K.Brand, order = 1 })
	for i, p in res.parts or {} do
		local good = p.mult >= 1.001
		local bad = p.mult < 0.999
		text(why, (if good then '<font color="#72D670">▲</font> ' elseif bad then '<font color="#FF2E63">▼</font> ' else "· ") .. p.label .. '  <font color="#9696A0">x' .. string.format("%.2f", p.mult) .. "</font>", { rich = true, size = 12, order = 1 + i })
	end
	text(why, "Quality score: " .. tostring(res.quality), { size = 12, bold = true, order = 99, dim = true })
	button(list, "Back to feed", { order = 6, style = "dark", onClick = function()
		ctx.go("feed")
	end })
	button(list, "Shoot another", { order = 7, onClick = function()
		ctx.go("shoot")
	end })
end

function Screens.deals(ctx: any)
	header(ctx, "Deals", "brand partnerships")
	local list = scroller(ctx.body, 44, 0, "Deals")
	local acc = myAccount(ctx.data())
	local order = 0
	local function o()
		order += 1
		return order
	end
	if (acc.Real or 0) < Social.Unlock.DealsFollowers then
		local c = card(list, o())
		text(c, "Brands start messaging you at " .. SocialRules.short(Social.Unlock.DealsFollowers) .. " real followers.", { size = 14, bold = true })
		text(c, "You have " .. SocialRules.short(acc.Real or 0) .. ". Bought followers don't count: brands check.", { size = 12, dim = true })
		local bar = new("Frame", { LayoutOrder = 3, Size = UDim2.new(1, 0, 0, 6), BackgroundColor3 = K.Card2, Parent = c }, { corner(3) })
		new("Frame", { Size = UDim2.fromScale(math.clamp((acc.Real or 0) / Social.Unlock.DealsFollowers, 0.02, 1), 1), BackgroundColor3 = K.Brand, Parent = bar }, { corner(3) })
		return
	end
	local share = SocialRules.botShare(acc)
	if share > Social.Bots.DealPenaltyShare then
		local c = card(list, o(), "Warning", C(60, 20, 30))
		text(c, "⚠️ Brands noticed your fake followers (" .. math.floor(share * 100) .. "%). " .. (if share > Social.Bots.NoDealsShare then "Nobody will work with you." else "They pay half."), { size = 12, bold = true })
	end
	local deal = acc.Deals and acc.Deals.Active
	if deal then
		local b = Social.brand(deal.brand) or { name = deal.brand, blurb = "" }
		local s = Social.spot(deal.spot)
		local c = card(list, o(), "Active", K.Card2)
		text(c, "ACTIVE DEAL", { size = 11, bold = true, color = K.Gold })
		text(c, b.name, { size = 18, head = true })
		text(c, "Post at <b>" .. s.label .. "</b>" .. (if deal.car then " with your car in the shot" else "") .. ". You get <font color=\"#72D670\"><b>" .. money(deal.pay) .. "</b></font> when it goes up.", { size = 13, rich = true })
		button(c, "Set GPS to " .. s.label, { style = "light", height = 34, onClick = function()
			act("gps", { spot = s.id })
		end })
	end
	text(list, "OFFERS", { order = o(), size = 11, bold = true, color = K.Brand })
	local offers = (acc.Deals and acc.Deals.Offers) or {}
	if #offers == 0 then
		text(list, "No offers right now. New brands message you every day.", { order = o(), size = 12, dim = true })
	end
	for _, off in offers do
		local b = Social.brand(off.brand) or { name = off.brand, blurb = "" }
		local s = Social.spot(off.spot)
		local c = card(list, o(), "Offer")
		local top = new("Frame", { LayoutOrder = 1, Size = UDim2.new(1, 0, 0, 22), BackgroundTransparency = 1, Parent = c })
		text(top, b.name, { size = 16, head = true, sizeU = UDim2.new(0.65, 0, 1, 0), auto = Enum.AutomaticSize.None })
		text(top, money(off.pay), { size = 16, head = true, color = K.Money, pos = UDim2.fromScale(1, 0), anchor = Vector2.new(1, 0), sizeU = UDim2.new(0.35, 0, 1, 0), auto = Enum.AutomaticSize.None, align = Enum.TextXAlignment.Right })
		text(c, b.blurb, { size = 12, dim = true, order = 2 })
		text(c, "📍 " .. s.label .. (if off.car then "  ·  🚗 car in the shot" else ""), { size = 12, bold = true, order = 3 })
		local row = new("Frame", { LayoutOrder = 4, Size = UDim2.new(1, 0, 0, 34), BackgroundTransparency = 1, Parent = c })
		button(row, "Accept", { sizeU = UDim2.new(0.62, -4, 1, 0), disabled = deal ~= nil, onClick = function()
			ctx.sfx("PhoneTap")
			act("acceptDeal", { id = off.id })
		end })
		button(row, "Pass", { style = "dark", sizeU = UDim2.new(0.38, -4, 1, 0), pos = UDim2.new(0.62, 4, 0, 0), onClick = function()
			act("declineDeal", { id = off.id })
		end })
	end
end

-- a small bar chart (7 days of income)
local function chart(parent: Instance, order: number, history: { any }, today: any)
	local c = card(parent, order, "Chart")
	text(c, "INCOME · LAST 7 DAYS", { size = 11, bold = true, color = K.Brand, order = 1 })
	local days = {}
	for i = math.min(#history, 6), 1, -1 do
		table.insert(days, { label = "-" .. i .. "d", v = history[i].income or 0 })
	end
	table.insert(days, { label = "today", v = today.income or 0, now = true })
	local max = 1
	for _, d in days do
		max = math.max(max, d.v)
	end
	local area = new("Frame", { LayoutOrder = 2, Size = UDim2.new(1, 0, 0, 110), BackgroundTransparency = 1, Parent = c })
	local n = #days
	for i, d in days do
		local h = math.max(0.02, d.v / max)
		local x = (i - 1) / n
		local col = new("Frame", { Position = UDim2.new(x, 3, 0, 0), Size = UDim2.new(1 / n, -6, 1, -16), BackgroundTransparency = 1, Parent = area })
		local bar = new("Frame", { AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), Size = UDim2.fromScale(1, 0), BackgroundColor3 = if d.now then K.Brand else K.Card2, Parent = col }, { corner(4) })
		TweenService:Create(bar, TweenInfo.new(0.5, Enum.EasingStyle.Quint), { Size = UDim2.fromScale(1, h) }):Play()
		text(col, SocialRules.short(d.v), { size = 9, bold = true, dim = true, pos = UDim2.new(0, 0, 1 - h, -14), sizeU = UDim2.new(1, 0, 0, 12), auto = Enum.AutomaticSize.None, align = Enum.TextXAlignment.Center, wrap = false })
		text(area, d.label, { size = 9, dim = true, pos = UDim2.new(x, 0, 1, -12), sizeU = UDim2.new(1 / n, 0, 0, 12), auto = Enum.AutomaticSize.None, align = Enum.TextXAlignment.Center, wrap = false })
	end
end

function Screens.me(ctx: any)
	local d = ctx.data()
	local acc = myAccount(d)
	header(ctx, "@" .. (acc.Handle or string.lower(player.Name)), if SocialRules.verified(acc) then '<font color="#50AAFF">✔ verified</font>' else "")
	local list = scroller(ctx.body, 44, 0, "Me")
	-- profile head
	local head = new("Frame", { Name = "Profile", LayoutOrder = 1, Size = UDim2.new(1, 0, 0, 74), BackgroundTransparency = 1, Parent = list })
	local ring = new("Frame", { Size = UDim2.fromOffset(70, 70), BackgroundColor3 = K.Brand, Parent = head }, { corner(35) })
	new("UIGradient", { Color = ColorSequence.new(C(255, 46, 99), C(255, 170, 60)), Rotation = 45, Parent = ring })
	CloutArt.avatar(ring, { userId = player.UserId }, 64, 3).Position = UDim2.fromOffset(3, 3)
	local stats = new("Frame", { Position = UDim2.fromOffset(84, 6), Size = UDim2.new(1, -84, 0, 44), BackgroundTransparency = 1, Parent = head }, {
		new("UIGridLayout", { CellSize = UDim2.new(1 / 3, -4, 1, 0), CellPadding = UDim2.fromOffset(4, 0) }),
	})
	for _, st in { { SocialRules.short(acc.PostCount or 0), "posts" }, { SocialRules.short(SocialRules.total(acc)), "followers" }, { tostring(#(acc.Courses or {})), "courses" } } do
		local cell = new("Frame", { BackgroundTransparency = 1, Parent = stats })
		text(cell, st[1], { size = 17, head = true, align = Enum.TextXAlignment.Center, sizeU = UDim2.new(1, 0, 0, 22), auto = Enum.AutomaticSize.None })
		text(cell, st[2], { size = 11, dim = true, align = Enum.TextXAlignment.Center, pos = UDim2.fromOffset(0, 22), sizeU = UDim2.new(1, 0, 0, 14), auto = Enum.AutomaticSize.None })
	end
	text(head, SocialRules.tier(SocialRules.total(acc)).label, { size = 12, bold = true, color = K.Brand, pos = UDim2.fromOffset(84, 54), sizeU = UDim2.new(1, -84, 0, 16), auto = Enum.AutomaticSize.None })
	-- the honest numbers (only you see them)
	local share = SocialRules.botShare(acc)
	local info = card(list, 2, "Insights")
	text(info, "INSIGHTS (only you see this)", { size = 11, bold = true, color = K.Brand, order = 1 })
	text(info, "Real followers <b>" .. SocialRules.short(acc.Real or 0) .. "</b>   ·   Bots <b>" .. SocialRules.short(acc.Bots or 0) .. "</b>" .. (if share > 0 then " (" .. math.floor(share * 100) .. "%)" else ""), { size = 13, rich = true, order = 2 })
	local nextM = nil
	for _, m in Social.Milestones do
		if SocialRules.total(acc) < m.at then
			nextM = m
			break
		end
	end
	if nextM then
		text(info, "Next: " .. nextM.title .. " (+" .. nextM.xp .. " XP)", { size = 12, dim = true, order = 3 })
		local bar = new("Frame", { LayoutOrder = 4, Size = UDim2.new(1, 0, 0, 6), BackgroundColor3 = K.Card2, Parent = info }, { corner(3) })
		new("Frame", { Size = UDim2.fromScale(math.clamp(SocialRules.total(acc) / nextM.at, 0.02, 1), 1), BackgroundColor3 = K.Brand, Parent = bar }, { corner(3) })
	end
	local e = acc.Earned or {}
	text(info, "Earned on Clout: " .. money((e.Fund or 0) + (e.Deals or 0) + (e.Courses or 0)) .. "   (fund " .. money(e.Fund or 0) .. " · deals " .. money(e.Deals or 0) .. " · courses " .. money(e.Courses or 0) .. ")", { size = 11, dim = true, order = 5 })
	chart(list, 3, acc.History or {}, acc.Today or {})
	-- creator studio entry
	local studio = card(list, 4, "StudioEntry", K.Card2)
	text(studio, "🎓 CREATOR STUDIO", { size = 13, head = true, order = 1 })
	text(studio, "Sell courses to your followers. They sell every day: some days big, some days nothing.", { size = 12, dim = true, order = 2 })
	button(studio, "Open Creator Studio", { order = 3, height = 34, style = "light", onClick = function()
		ctx.go("studio")
	end })
	-- my posts grid
	text(list, "YOUR POSTS", { order = 5, size = 11, bold = true, color = K.Brand })
	local grid = new("Frame", { Name = "Grid", LayoutOrder = 6, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, Parent = list }, {
		new("UIGridLayout", { CellSize = UDim2.new(1 / 3, -3, 0, 92), CellPadding = UDim2.fromOffset(4, 4), SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	if #(acc.Posts or {}) == 0 then
		text(list, "No posts yet. Tap ＋ to shoot your first one.", { order = 7, size = 12, dim = true })
	end
	for i, p in acc.Posts or {} do
		local cell = new("Frame", { LayoutOrder = i, BackgroundColor3 = K.Card, ClipsDescendants = true, Parent = grid }, { corner(6) })
		local pp = table.clone(p)
		pp.userId = player.UserId
		CloutArt.draw(cell, pp, { capture = S.captures[p.id], viewport = false })
		text(cell, "👁 " .. SocialRules.short(p.views or 0), { size = 10, bold = true, pos = UDim2.new(0, 4, 1, -16), sizeU = UDim2.new(1, -8, 0, 14), auto = Enum.AutomaticSize.None, z = 20 })
		if p.outcome == "viral" then
			text(cell, "🔥", { size = 12, pos = UDim2.new(1, -18, 0, 2), sizeU = UDim2.fromOffset(16, 16), auto = Enum.AutomaticSize.None, z = 20 })
		end
	end
	-- server leaderboard
	if #S.leaders > 0 then
		local lb = card(list, 8, "Leaders")
		text(lb, "TOP CREATORS IN THIS SERVER", { size = 11, bold = true, color = K.Brand, order = 0 })
		for i, l in S.leaders do
			text(lb, i .. ".  <b>@" .. l.handle .. "</b>" .. (if l.verified then ' <font color="#50AAFF">✔</font>' else "") .. '  <font color="#9696A0">' .. SocialRules.short(l.followers) .. "</font>", { rich = true, size = 13, order = i })
		end
	end
end

function Screens.studio(ctx: any)
	local d = ctx.data()
	local acc = myAccount(d)
	header(ctx, "Creator Studio", "")
	local list = scroller(ctx.body, 44, 0, "Studio")
	local order = 0
	local function o()
		order += 1
		return order
	end
	button(list, "‹ Back", { order = o(), style = "dark", height = 30, size = 12, sizeU = UDim2.fromOffset(80, 30), onClick = function()
		ctx.go("me")
	end })
	local level = (d and d.Level) or 1
	local canCourses = (acc.Real or 0) >= Social.Unlock.CoursesFollowers and level >= Social.Unlock.CoursesLevel
	-- recording in progress
	local rec = S.recording
	if rec then
		local c = card(list, o(), "Recording", K.Card2)
		local t = Social.topic(rec.topic)
		text(c, "🔴 RECORDING · module " .. (rec.step + 1) .. " of " .. rec.of, { size = 12, bold = true, color = K.Brand })
		text(c, (t and t.title or "Course") .. " · $" .. rec.price, { size = 16, head = true })
		local bar = new("Frame", { LayoutOrder = 5, Size = UDim2.new(1, 0, 0, 8), BackgroundColor3 = K.Card, Parent = c }, { corner(4) })
		local fill = new("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = K.Brand, Parent = bar }, { corner(4) })
		local b = button(c, "Recording...", { order = 6, disabled = false, style = "dark" })
		local lines = { "\"Most people will never see this...\"", "\"Step one: stop being broke.\"", "\"I'm not supposed to tell you this.\"", "\"Rent the car. Shoot the pic. Return the car.\"", "\"Link in bio. Don't wait.\"" }
		local script = text(c, lines[1 + (rec.step % #lines)], { size = 12, dim = true, order = 4 })
		local _ = script
		local conn
		conn = RunService.Heartbeat:Connect(function()
			if not b.Parent then
				conn:Disconnect()
				return
			end
			local left = (rec.readyAt or 0) - os.clock()
			local p = 1 - math.clamp(left / (rec.seconds or 6), 0, 1)
			fill.Size = UDim2.fromScale(p, 1)
			if left <= 0 then
				b.Text = if rec.step + 1 >= rec.of then "Finish + launch" else "Next module"
				b.BackgroundColor3 = K.Brand
			else
				b.Text = "Recording... " .. math.ceil(left) .. " s"
			end
		end)
		ctx.track(conn)
		b.Activated:Connect(function()
			if (rec.readyAt or 0) - os.clock() <= 0 then
				ctx.sfx("PhoneTap")
				act("recordStep")
			end
		end)
		button(c, "Cancel (production cost is gone)", { order = 7, style = "dark", height = 28, size = 11, onClick = function()
			act("cancelRecording")
		end })
	end
	-- live courses
	text(list, "YOUR COURSES", { order = o(), size = 11, bold = true, color = K.Brand })
	local live = 0
	local mk = S.market
	for _, c in acc.Courses or {} do
		local t = Social.topic(c.topic)
		local cc = card(list, o(), "Course")
		local dem = mk and mk.demand and mk.demand[c.topic] or 1
		text(cc, (t and t.title or c.topic) .. "  ·  $" .. c.price .. (if c.retired then "  (retired)" else ""), { size = 14, bold = true })
		text(cc, "Sold <b>" .. SocialRules.short(c.sold or 0) .. "</b>  ·  made <font color=\"#72D670\"><b>" .. money(c.revenue or 0) .. "</b></font>" .. (if (c.refunds or 0) > 0 then "  ·  " .. c.refunds .. " refunds" else ""), { size = 12, rich = true })
		if not c.retired then
			live += 1
			local age = (mk and mk.day or 0) - (c.launchDay or 0)
			text(cc, "Demand today " .. (if dem >= 1.15 then '<font color="#72D670">▲ ' elseif dem <= 0.8 then '<font color="#FF2E63">▼ ' else "<font>") .. string.format("x%.2f", dem) .. "</font>  ·  hype " .. string.format("x%.2f", SocialRules.novelty(age)) .. " (day " .. (age + 1) .. ")", { size = 11, rich = true, dim = true })
			button(cc, "Retire", { style = "dark", height = 28, size = 11, onClick = function()
				act("retireCourse", { id = c.id })
			end })
		end
	end
	if #(acc.Courses or {}) == 0 then
		text(list, "No courses yet.", { order = o(), size = 12, dim = true })
	end
	-- make a course
	local mkc = card(list, o(), "NewCourse", K.Card2)
	text(mkc, "MAKE A COURSE", { size = 11, bold = true, color = K.Brand })
	if not canCourses then
		text(mkc, "Needs " .. SocialRules.short(Social.Unlock.CoursesFollowers) .. " real followers (you: " .. SocialRules.short(acc.Real or 0) .. ") and Level " .. Social.Unlock.CoursesLevel .. " (you: " .. level .. ").", { size = 12, dim = true })
	elseif not (ctx.desktop or (S.scout and S.scout.desk)) then
		text(mkc, "You record courses at your desk computer. Sit down at the PC in your flat (power on) and open clout.com.", { size = 12, dim = true })
		act("scout")
	elseif live >= Social.Courses.MaxLive then
		text(mkc, "You have " .. live .. " live courses. Retire one to make another.", { size = 12, dim = true })
	elseif not rec then
		ctx.newTopic = ctx.newTopic or Social.CourseTopics[1].id
		ctx.newPrice = ctx.newPrice or 97
		local topics = new("Frame", { LayoutOrder = 2, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, Parent = mkc }, { vlist(4) })
		for i, t in Social.CourseTopics do
			local on = ctx.newTopic == t.id
			local dem = mk and mk.demand and mk.demand[t.id] or 1
			local b = new("TextButton", { LayoutOrder = i, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundColor3 = if on then K.Brand else K.Card, AutoButtonColor = false, Text = "", Parent = topics }, { corner(8), pad(10, 6), vlist(1) })
			text(b, "<b>" .. t.title .. "</b>  " .. (if dem >= 1.15 then "▲" elseif dem <= 0.8 then "▼" else "") .. string.format(" x%.2f today", dem), { rich = true, size = 12, order = 1 })
			text(b, t.blurb, { size = 11, order = 2, color = if on then K.Text else K.Dim })
			b.Activated:Connect(function()
				ctx.newTopic = t.id
				ctx.go("studio")
			end)
		end
		local prices = new("Frame", { LayoutOrder = 3, Size = UDim2.new(1, 0, 0, 52), BackgroundTransparency = 1, Parent = mkc }, {
			new("UIGridLayout", { CellSize = UDim2.new(0.25, -4, 1, 0), CellPadding = UDim2.fromOffset(4, 0) }),
		})
		for _, p in Social.CoursePrices do
			local on = ctx.newPrice == p.price
			local b = new("TextButton", { BackgroundColor3 = if on then K.Text else K.Card, AutoButtonColor = false, Text = "", Parent = prices }, { corner(8) })
			text(b, "$" .. p.price, { size = 14, head = true, color = if on then C(10, 10, 12) else K.Text, align = Enum.TextXAlignment.Center, sizeU = UDim2.new(1, 0, 0, 22), pos = UDim2.fromOffset(0, 6), auto = Enum.AutomaticSize.None })
			text(b, p.label, { size = 9, color = if on then C(60, 60, 70) else K.Dim, align = Enum.TextXAlignment.Center, sizeU = UDim2.new(1, 0, 0, 14), pos = UDim2.fromOffset(0, 30), auto = Enum.AutomaticSize.None })
			b.Activated:Connect(function()
				ctx.newPrice = p.price
				ctx.go("studio")
			end)
		end
		local tier = Social.priceTier(ctx.newPrice)
		local est = SocialRules.courseBuyers(acc, { topic = ctx.newTopic, price = ctx.newPrice, launchDay = mk and mk.day or 0 }, { day = mk and mk.day or 0, demand = mk and mk.demand or {}, trust = SocialRules.trust(acc, acc.Trust), promo = true })
		text(mkc, "Launch day estimate: ~" .. string.format("%.1f", est) .. " sales (" .. money(est * SocialRules.net(ctx.newPrice)) .. ") if you keep posting. Pricier = fewer buyers. Hype fades after a few days.", { size = 11, dim = true, order = 4 })
		button(mkc, "Record it · production " .. money(tier and tier.cost or 0), { order = 5, onClick = function()
			ctx.sfx("PhoneTap")
			act("startCourse", { topic = ctx.newTopic, price = ctx.newPrice })
		end })
	end
	-- bot shop
	local bots = card(list, o(), "Bots")
	text(bots, "🤖 BUY FOLLOWERS", { size = 13, head = true, order = 1 })
	text(bots, "The number goes up. Real reach doesn't. Bots never buy courses, brands pay less above 30% bots, and Clout purges fake accounts some days.", { size = 11, dim = true, order = 2 })
	for i, p in Social.Bots.Packs do
		button(bots, "+" .. SocialRules.short(p.count) .. " followers · " .. money(p.price), { order = 2 + i, style = "dark", height = 32, size = 12, onClick = function()
			ctx.sfx("PhoneTap")
			act("buyBots", { pack = p.id })
		end })
	end
end

---------------------------------------------------------------- the frame: tab bar + screen host

local TABS = {
	{ id = "feed", label = "Feed", glyph = "⌂" },
	{ id = "spots", label = "Spots", glyph = "📍" },
	{ id = "shoot", label = "", glyph = "＋" },
	{ id = "deals", label = "Deals", glyph = "💼" },
	{ id = "me", label = "Me", glyph = "👤" },
}

local function locked(ctx: any)
	local f = ctx.frame
	new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = K.Bg, Parent = f })
	local w = text(f, "CLOUT", { head = true, size = 40, pos = UDim2.fromScale(0.5, 0.38), anchor = Vector2.new(0.5, 0.5), sizeU = UDim2.new(1, 0, 0, 48), auto = Enum.AutomaticSize.None, align = Enum.TextXAlignment.Center })
	new("UIGradient", { Color = ColorSequence.new(C(255, 46, 99), C(255, 150, 60)), Parent = w })
	text(f, "Get on your feet first. Clout opens once you're free to roam the city.", { size = 13, dim = true, pos = UDim2.fromScale(0.5, 0.5), anchor = Vector2.new(0.5, 0), sizeU = UDim2.new(0.8, 0, 0, 40), auto = Enum.AutomaticSize.None, align = Enum.TextXAlignment.Center })
end

function App.mount(frame: Frame, ctx: any)
	connect()
	ctx.desktop = (ctx.args and ctx.args.desktop) or frame.AbsoluteSize.X > 520
	local wide = ctx.desktop and frame.AbsoluteSize.X > 520
	local bg = new("Frame", { Name = "CloutBg", Size = UDim2.fromScale(1, 1), BackgroundColor3 = K.Bg, BorderSizePixel = 0, Parent = frame })
	local navW = if wide then 150 else 0
	local body = new("Frame", {
		Name = "Body",
		Position = UDim2.fromOffset(navW, 0),
		Size = UDim2.new(1, -navW, 1, if wide then 0 else -52),
		BackgroundColor3 = K.Bg,
		BorderSizePixel = 0,
		ClipsDescendants = true,
		Parent = frame,
	})
	if wide then
		-- the browser version: a centred column like the real site
		body.Size = UDim2.new(0, math.min(420, frame.AbsoluteSize.X - navW - 20), 1, 0)
		body.Position = UDim2.new(0, navW + 10, 0, 0)
	end
	ctx.body = body
	local tabBar = new("Frame", {
		Name = "Tabs",
		AnchorPoint = if wide then Vector2.new() else Vector2.new(0, 1),
		Position = if wide then UDim2.new() else UDim2.fromScale(0, 1),
		Size = if wide then UDim2.new(0, navW, 1, 0) else UDim2.new(1, 0, 0, 52),
		BackgroundColor3 = K.Bg,
		BorderSizePixel = 0,
		Parent = frame,
	}, { if wide then vlist(4) else hlist(0), pad(if wide then 10 else 4, if wide then 14 else 2) })
	new("Frame", { Name = "Rule", Position = if wide then UDim2.new(1, -1, 0, 0) else UDim2.new(), Size = if wide then UDim2.new(0, 1, 1, 0) else UDim2.new(1, 0, 0, 1), BackgroundColor3 = K.Line, BackgroundTransparency = 0.9, BorderSizePixel = 0, Parent = tabBar })
	if wide then
		local w = text(tabBar, "CLOUT", { head = true, size = 24, order = 0, sizeU = UDim2.new(1, 0, 0, 40), auto = Enum.AutomaticSize.None })
		new("UIGradient", { Color = ColorSequence.new(C(255, 46, 99), C(255, 150, 60)), Parent = w })
	end
	local tabButtons = {}
	for i, t in TABS do
		local b = new("TextButton", {
			Name = "Tab_" .. t.id,
			LayoutOrder = i,
			Size = if wide then UDim2.new(1, 0, 0, 36) else UDim2.new(0.2, 0, 1, 0),
			BackgroundTransparency = 1,
			AutoButtonColor = false,
			FontFace = K.Bold,
			Text = if wide then (t.glyph .. "  " .. (if t.label == "" then "New post" else t.label)) else t.glyph,
			TextXAlignment = if wide then Enum.TextXAlignment.Left else Enum.TextXAlignment.Center,
			TextSize = if wide then 14 else (if t.id == "shoot" then 22 else 18),
			TextColor3 = K.Dim,
			Parent = tabBar,
		}, { corner(10) })
		if t.id == "shoot" and not wide then
			-- the big middle button, like the real apps
			b.Text = ""
			local plus = new("TextLabel", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(44, 30), BackgroundColor3 = K.Text, FontFace = K.Head, Text = "+", TextSize = 22, TextColor3 = C(10, 10, 12), Parent = b }, { corner(9) })
			new("UIStroke", { Color = K.Brand, Thickness = 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = plus })
		end
		tabButtons[t.id] = b
		b.Activated:Connect(function()
			ctx.sfx("PhoneTap")
			if t.id == "shoot" and wide then
				ctx.toast("Shooting needs your phone. Go outside!")
				return
			end
			ctx.go(t.id)
		end)
	end
	local listenerKey = {}
	local screenListeners: { (string, any) -> () } = {}
	listeners[listenerKey] = function(kind, m)
		for _, fn in screenListeners do
			task.spawn(fn, kind, m)
		end
	end
	ctx.track({ Disconnect = function()
		listeners[listenerKey] = nil
	end })
	function ctx.listen(fn)
		table.insert(screenListeners, fn)
	end
	function ctx.toast(str: string)
		ctx.Phone.notify({ app = Social.AppId, title = "CLOUT", text = str })
	end
	function ctx.go(screen: string)
		if ctx.screen == "shoot" and screen ~= "shoot" then
			stopShoot(ctx)
		end
		ctx.screen = screen
		table.clear(screenListeners)
		for _, c in body:GetChildren() do
			c:Destroy()
		end
		body.BackgroundTransparency = 0
		bg.BackgroundTransparency = if screen == "shoot" then 1 else 0
		tabBar.Visible = screen ~= "shoot" or wide
		body.Size = if wide then body.Size elseif screen == "shoot" then UDim2.fromScale(1, 1) else UDim2.new(1, 0, 1, -52)
		for id, b in tabButtons do
			local on = id == screen or (id == "me" and screen == "studio") or (id == "shoot" and (screen == "caption" or screen == "result" or screen == "posting"))
			b.TextColor3 = if on then K.Text else K.Dim
			b.BackgroundColor3 = K.Card
			b.BackgroundTransparency = if on and wide then 0 else 1
		end
		local fn = Screens[screen] or Screens.feed
		local ok, err = pcall(fn, ctx)
		if not ok then
			warn("[MTL Clout] screen", screen, err)
		end
	end
	-- re-render on data changes for the screens that show the save (not mid-shoot / mid-post)
	local lastKey = ""
	ctx.onData(function(d)
		local acc = myAccount(d)
		local key = table.concat({ acc.Real or 0, acc.Bots or 0, acc.PostCount or 0, #(acc.Deals and acc.Deals.Offers or {}), tostring(acc.Deals and acc.Deals.Active and acc.Deals.Active.id), #(acc.Courses or {}), math.floor((acc.Today and acc.Today.income or 0) / 50) }, "|")
		if key ~= lastKey then
			lastKey = key
			if ctx.screen == "me" or ctx.screen == "deals" or ctx.screen == "studio" then
				ctx.go(ctx.screen)
			end
		end
	end)
	-- live updates from the server for the open screen
	local liveKey = {}
	listeners[liveKey] = function(kind, m)
		if not frame.Parent then
			return
		end
		if kind == "hello" or kind == "market" or kind == "leaders" then
			if ctx.screen == "feed" or ctx.screen == "spots" then
				ctx.go(ctx.screen)
			end
		elseif kind == "feedPost" and ctx.screen == "feed" and m.post and m.post.userId ~= player.UserId then
			ctx.go("feed")
		elseif kind == "followed" and ctx.screen == "feed" then
			ctx.go("feed")
		elseif (kind == "recording" or kind == "launched") and ctx.screen == "studio" then
			ctx.go("studio")
		elseif kind == "toast" then
			ctx.toast(m.text)
		elseif kind == "postFail" then
			if not m.shown then ctx.toast(m.reason or "Couldn't post") end
		end
	end
	ctx.track({ Disconnect = function()
		listeners[liveKey] = nil
	end })
	local d = ctx.data()
	local stageOk = S.unlocked or (d and d.Phone and d.Phone.Apps and d.Phone.Apps[Social.AppId])
	if not stageOk then
		locked(ctx)
		tabBar.Visible = false
		return
	end
	local start = (ctx.args and ctx.args.screen) or (if S.result and ctx.args and ctx.args.result then "result" else "feed")
	ctx.go(start)
	act("sync")
end

function App.unmount(ctx: any)
	stopShoot(ctx)
end

-- the save snapshot lets other modules (desk computer) ask for the same screens
App.Screens = Screens
App.state = S

return App
