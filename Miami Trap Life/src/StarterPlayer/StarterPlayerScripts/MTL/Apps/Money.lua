--!strict
-- Money app: "how do I make money?". Top: what you're holding (cash, bank, dirty cash and heat when the crime
-- loop gives you some). Filter tabs: All / Jobs / Crime / Hustles. One card per way to earn (Config/Earn):
-- what it pays, roughly per minute, the risk, the cooldown ("Ready" or a live countdown), what you still need
-- (level, lifestyle, an item), and a Set GPS button (server action earnRoute). Best pay first, locked ones last.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Earn = require(ReplicatedStorage.MTL.Config.Earn)
local StoryRules = require(ReplicatedStorage.MTL.Rules.StoryRules)

local App = { id = "Money", title = "Money" }

local FILTERS = { { "All", nil }, { "Jobs", "Job" }, { "Crime", "Crime" }, { "Hustles", "Hustle" } }

local function money(n: number): string
	local s = tostring(math.floor(n))
	local out = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return "$" .. (string.gsub(out, "^,", ""))
end

local function countdown(sec: number): string
	sec = math.max(0, math.ceil(sec))
	if sec >= 3600 then
		return string.format("%dh %02dm", sec // 3600, (sec % 3600) // 60)
	end
	return string.format("%d:%02d", sec // 60, sec % 60)
end

-- what's still missing for this method, or nil when it's open
local function missing(m: any, d: any): string?
	local r = m.requires or {}
	if r.level and (d.Level or 1) < r.level then
		return "Level " .. r.level .. " needed"
	end
	if r.path and d.Path ~= r.path then
		return if r.path == "Criminal" then "Criminal lifestyle only" else (r.path .. " lifestyle only")
	end
	if r.stage and d.Story and not StoryRules.reached(d.Story.Stage, r.stage) then
		return "Opens later in the story"
	end
	if r.item and not (d.Inventory and d.Inventory.Items and d.Inventory.Items[r.item]) then
		return "Needs " .. (r.itemLabel or r.item)
	end
	return nil
end

local function render(ctx: any, d: any, state: any)
	ctx.clear()
	local UIKit, Theme = ctx.UIKit, ctx.Theme
	local C, P = Theme.Colors, Theme.Phone
	UIKit.header(ctx.frame, "Money")
	local list = UIKit.scroll(ctx.frame, 44, "Methods")
	local order = 0
	local function nextOrder(): number
		order += 1
		return order
	end

	-- wallet
	local wallet = UIKit.card(list, nextOrder(), "Wallet")
	UIKit.label(wallet, "CASH", { size = 11, dim = true, bold = true, name = "CashLabel", order = 1 })
	UIKit.label(wallet, money(d.Cash or 0), { size = 30, bold = true, color = C.Money, name = "Cash", order = 2 })
	local bits = { "Bank " .. money(d.Bank or 0) }
	local dirty = Players.LocalPlayer:GetAttribute("MTL_Dirty")
	if type(dirty) == "number" and dirty > 0 then
		table.insert(bits, "<font color=\"#E64848\">Dirty " .. money(dirty) .. "</font>")
	end
	local heat = Players.LocalPlayer:GetAttribute("MTL_Heat")
	if type(heat) == "number" and heat > 0 then
		table.insert(bits, "<font color=\"#F0C048\">" .. string.rep("*", heat) .. " heat</font>")
	end
	local sub = UIKit.label(wallet, table.concat(bits, "   ·   "), { size = 12, dim = true, name = "Sub", order = 3 })
	sub.RichText = true

	-- filter tabs
	local tabs = UIKit.new("Frame", {
		Name = "Filters",
		LayoutOrder = nextOrder(),
		Size = UDim2.new(1, 0, 0, 32),
		BackgroundColor3 = P.Card,
		Parent = list,
	}, { UIKit.corner(UDim.new(0, 9)), UIKit.list(0, true), UIKit.padding(3) })
	for i, f in FILTERS do
		local on = state.filter == f[2]
		local b = UIKit.new("TextButton", {
			Name = "Tab_" .. f[1],
			LayoutOrder = i,
			Size = UDim2.new(1 / #FILTERS, 0, 1, 0),
			BackgroundColor3 = P.CardHover,
			BackgroundTransparency = if on then 0 else 1,
			AutoButtonColor = false,
			FontFace = Theme.Fonts.Bold,
			Text = f[1],
			TextColor3 = if on then C.Text else C.TextDim,
			TextSize = 12,
			Parent = tabs,
		}, { UIKit.corner(UDim.new(0, 7)) })
		b.Activated:Connect(function()
			state.filter = f[2]
			render(ctx, ctx.data() or d, state)
		end)
	end

	-- methods: open ones by pay, then locked ones
	local entries = {}
	for _, m in Earn.all() do
		if state.filter == nil or m.kind == state.filter then
			table.insert(entries, { m = m, lock = missing(m, d) })
		end
	end
	table.sort(entries, function(a, b)
		if (a.lock == nil) ~= (b.lock == nil) then
			return a.lock == nil
		end
		return (a.m.perMinute or 0) > (b.m.perMinute or 0)
	end)
	if #entries == 0 then
		UIKit.empty(list, if state.filter == "Crime" then "Nothing here yet. Crew work shows up as the story moves on." else "Nothing here yet.", nextOrder())
	end
	local ready = (d.Earn and d.Earn.Ready) or {}
	state.timers = {}
	for _, e in entries do
		local m = e.m
		local card = UIKit.card(list, nextOrder(), "Method_" .. m.id)
		if e.lock then
			card.BackgroundTransparency = 0.35
		end
		local kindColor = if m.kind == "Crime" then C.Danger elseif m.kind == "Hustle" then C.Gold else C.Accent
		local top = UIKit.label(card, string.upper(m.kind or "") .. (if m.risk then ("  ·  " .. m.risk) else ""), { size = 10, bold = true, color = kindColor, name = "Kind", order = 1 })
		top.TextTransparency = if e.lock then 0.3 else 0
		UIKit.label(card, m.title, { size = 16, bold = true, wrap = true, color = if e.lock then C.TextDim else C.Text, name = "Title", order = 2 })
		if m.blurb and m.blurb ~= "" then
			UIKit.label(card, m.blurb, { size = 12, dim = true, wrap = true, name = "Blurb", order = 3 })
		end
		UIKit.label(card, m.pay or "", { size = 15, bold = true, color = if e.lock then C.TextDim else C.Money, name = "Pay", order = 4 })
		local status = UIKit.label(card, "", { size = 12, bold = true, name = "Status", order = 5 })
		if e.lock then
			status.Text = e.lock
			status.TextColor3 = C.TextDim
		else
			local at = tonumber(ready[m.id])
			if at and at > os.time() then
				status.TextColor3 = C.Gold
				table.insert(state.timers, { label = status, at = at })
				status.Text = "Ready in " .. countdown(at - os.time())
			else
				status.TextColor3 = C.Money
				status.Text = if m.cooldown and m.cooldown > 0 then ("Ready  ·  cooldown " .. countdown(m.cooldown)) else "Ready"
			end
		end
		if m.location or m.position then
			UIKit.button(card, "Set GPS", {
				style = if e.lock then "secondary" else "primary",
				name = "GPS",
				height = 34,
				order = 10,
				onClick = function()
					ctx.action("earnRoute", { id = m.id })
				end,
			})
		end
	end
end

function App.mount(frame: Frame, ctx: any)
	local state = { filter = nil, timers = {} }
	local last = ""
	local function refresh(d: any, force: boolean?)
		if not d or not frame.Parent then
			return
		end
		local readyBits = {}
		for id, t in (d.Earn and d.Earn.Ready) or {} do
			table.insert(readyBits, id .. "=" .. tostring(t))
		end
		table.sort(readyBits)
		local key = table.concat({
			tostring(d.Cash),
			tostring(d.Bank),
			tostring(d.Level),
			tostring(d.Path),
			tostring(d.Story and d.Story.Stage),
			table.concat(readyBits, ","),
			tostring(Players.LocalPlayer:GetAttribute("MTL_Dirty")),
			tostring(Players.LocalPlayer:GetAttribute("MTL_Heat")),
		}, "|")
		if key ~= last or force then
			last = key
			render(ctx, d, state)
		end
	end
	ctx.onData(refresh)
	for _, attr in { "MTL_Dirty", "MTL_Heat" } do
		ctx.track(Players.LocalPlayer:GetAttributeChangedSignal(attr):Connect(function()
			refresh(ctx.data())
		end))
	end
	-- live countdowns (one tick a second)
	local acc = 0
	ctx.track(RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc < 1 then
			return
		end
		acc = 0
		local now = os.time()
		local done = false
		for _, t in state.timers do
			if t.label.Parent then
				if t.at <= now then
					done = true
				else
					t.label.Text = "Ready in " .. countdown(t.at - now)
				end
			end
		end
		if done then
			refresh(ctx.data(), true)
		end
	end))
end

return App
