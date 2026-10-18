-- Progression (design/pages/04 Rewards, 05 Quests): REWARDS / QUESTS tabs in the header of one stationary window,
-- with the same level bar along the bottom of both. Everything comes from the server's saved state: claims are
-- requests the server checks (ProgressService), and progress only moves when gameplay reports real events.
-- No timers or resets: quests are permanent, as configured. Bonus cosmetics can't be earned yet, so they show locked.
-- Layout numbers are reference px, window-relative.
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Progression = require(Shared.Config.Progression)
local UI = script.Parent.Parent
local Theme = require(UI.Theme)
local Kit = require(UI.Kit)
local State = require(UI.State)
local Toast = require(UI.Toast)
local ModalManager = require(UI.ModalManager)
local Motion = require(UI.Motion)

local new = Kit.new
local hex = Color3.fromHex
local C = Theme.Colors

local ProgressionScreen = {}

local W, H = 701, 320 -- every main window shares this size
local BODY_X, BODY_W = 13, 676

-- Measured from references 04 and 05.
local COL = {
	Section = hex("152B40"), SectionRim = hex("223F5C"),
	Card = hex("2E4565"), CardBottom = hex("2B4061"), CardRim = hex("4A6A92"),
	Bonus = hex("314A6A"), BonusBottom = hex("2D4465"),
	Claimed = hex("354B73"), ClaimedRim = hex("23365A"), LockedBox = hex("1B2E4C"), LockedRim = hex("13233D"),
	Gold = hex("FBC94F"), GoldRim = hex("B88A2C"), Pale = hex("98A4C3"), PaleRim = hex("66728F"), NodeText = hex("1A2342"),
	TrackEmpty = hex("8EA0C2"), SegEmpty = hex("456185"), SegFill = hex("FCD15F"),
	Bar = hex("182D44"), BarRim = hex("24405F"), Yellow = hex("FCE94A"),
	Quest = hex("1E3B5A"), QuestRim = hex("2F5E86"), IconCell = hex("1B3754"), XpCell = hex("163049"),
	CountBox = hex("162B44"), QuestEmpty = hex("2A496D"), Done = hex("7D82DC"), DoneClaimed = hex("556585"),
}

-- A rounded panel with a 1 px rim (and an optional top-to-bottom gradient).
local function panel(parent: Instance, name: string, x: number, y: number, w: number, h: number, color: Color3, rim: Color3, bottom: Color3?)
	local f = new("Frame", { Name = name, Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(w, h), BackgroundColor3 = if bottom then Color3.new(1, 1, 1) else color, BorderSizePixel = 0, Parent = parent }, { Kit.corner(4), Kit.stroke(rim, 1) })
	if bottom then new("UIGradient", { Rotation = 90, Color = ColorSequence.new(color, bottom), Parent = f }) end
	return f
end

-- A small label box with an optional icon (CLAIMED, Locked). Tappable when onClick is given.
local function chip(parent: Instance, props: { [string]: any })
	local f = new("TextButton", { Name = props.Name, Text = "", AutoButtonColor = false, Position = props.Position, Size = props.Size, AnchorPoint = props.AnchorPoint or Vector2.zero, BackgroundColor3 = props.Color, BorderSizePixel = 0, Parent = parent }, { Kit.corner(3), Kit.stroke(props.Rim, 1) })
	local row = new("Frame", { Name = "Content", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Parent = f }, { Kit.list(Enum.FillDirection.Horizontal, props.Gap or 6, Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Center) })
	if props.Icon then
		Kit.icon(props.Icon, { Name = "Icon", Size = UDim2.fromOffset(props.IconSize.X, props.IconSize.Y), LayoutOrder = 1, Parent = row })
	end
	Kit.text({ Name = "Label", Text = props.Text, FontFace = props.Font or Theme.Fonts.Body, TextSize = props.TextSize or 14, TextXAlignment = Enum.TextXAlignment.Center, AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.new(0, 0, 1, 0), TextWrapped = false, LayoutOrder = 2, Parent = row })
	if props.OnClick then f.Activated:Connect(props.OnClick) end
	return f
end

-- A bar of n segments (the level and quest bars). Returns the frame and set(fraction 0-1); a segment can be part
-- filled, so the bar shows true progress.
local function segBar(parent: Instance, name: string, x: number, y: number, w: number, h: number, n: number, gap: number, fill: Color3, empty: Color3)
	local f = new("Frame", { Name = name, Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(w, h), BackgroundTransparency = 1, Parent = parent })
	local fills = {}
	for i = 1, n do
		local x0 = math.round((i - 1) * (w + gap) / n)
		local x1 = math.round(i * (w + gap) / n) - gap
		local seg = new("Frame", { Name = "Seg" .. i, Position = UDim2.fromOffset(x0, 0), Size = UDim2.fromOffset(x1 - x0, h), BackgroundColor3 = empty, BorderSizePixel = 0, Parent = f }, { Kit.corner(2) })
		fills[i] = new("Frame", { Name = "Fill", Size = UDim2.fromScale(0, 1), BackgroundColor3 = fill, BorderSizePixel = 0, Parent = seg }, { Kit.corner(2) })
	end
	local function set(frac: number)
		for i, fl in fills do
			local v = math.clamp(frac * n - (i - 1), 0, 1)
			fl.Size = UDim2.fromScale(v, 1)
			fl.Visible = v > 0
		end
	end
	return f, set
end

-- A pointy-top hexagon (the milestone nodes): three rotated bars make the shape, drawn twice for the rim.
local function hexagon(parent: Instance, name: string, cx: number, cy: number)
	local f = new("Frame", { Name = name, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(cx, cy), Size = UDim2.fromOffset(31, 36), BackgroundTransparency = 1, ZIndex = 2, Parent = parent })
	local parts = { rim = {}, fill = {} }
	for layer, size in { rim = Vector2.new(31, 18), fill = Vector2.new(27, 16) } do
		for _, rot in { 0, 60, 120 } do
			table.insert(parts[layer], new("Frame", { Name = layer, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(size.X, size.Y), Rotation = rot, BorderSizePixel = 0, ZIndex = if layer == "rim" then 2 else 3, Parent = f }))
		end
	end
	local label = Kit.text({ Name = "Level", Text = name, FontFace = Theme.Fonts.Heading, TextSize = 18, TextColor3 = COL.NodeText, TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.fromScale(1, 1), Position = UDim2.fromOffset(0, 1), TextWrapped = false, ZIndex = 4, Parent = f })
	return function(reached: boolean)
		for _, p in parts.rim do p.BackgroundColor3 = if reached then COL.GoldRim else COL.PaleRim end
		for _, p in parts.fill do p.BackgroundColor3 = if reached then COL.Gold else COL.Pale end
		label.TextColor3 = COL.NodeText
	end
end

local function sectionLabel(parent: Instance, text: string, y: number)
	return Kit.name({ Name = "Label", Text = text, FontFace = Theme.Fonts.Heading, TextSize = 15, Position = UDim2.fromOffset(12, y), Size = UDim2.fromOffset(300, 18), Parent = parent })
end

-- Reward pictures: the coin and gem rewards use the kit's stacks from page 04; the rest use their configured art.
local function rewardArt(r): string
	if r.Kind == "Coins" then return "RewardCoins" end
	if r.Kind == "Aura" then return "RewardGems" end -- (the kit's gem picture stands in for Aura)
	return r.Art
end

local function claim(verb: string, arg: any, done: string)
	task.spawn(function()
		local ok, why = State.action(verb, arg)
		if ok then Toast.show(done) else Toast.show(why or "Couldn't claim that. Try again.") end
	end)
end

-- REWARDS ---------------------------------------------------------------------------------------------------------
local CARD_W, CARD_GAP = 155, 13

local function buildRewards(page: Frame, refreshers: { () -> () })
	local free = panel(page, "FreeRewards", BODY_X, 51, BODY_W, 132, COL.Section, COL.SectionRim)
	sectionLabel(free, "FREE REWARDS", 6)
	local nodes = {}
	for i, r in Progression.Rewards do
		local x = 12 + (i - 1) * (CARD_W + CARD_GAP)
		local card = panel(free, "Reward" .. r.Level, x, 27, CARD_W, 66, COL.Card, COL.CardRim, COL.CardBottom)
		local pic = Kit.art(rewardArt(r), { Name = "Picture", Position = UDim2.fromOffset(1, 1), Size = UDim2.fromOffset(72, 64), Parent = card })
		Kit.attach(Kit.corner(3), pic)
		Kit.name({ Name = "Name", Text = r.Name, TextSize = 13, TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.fromOffset(71, 6), Size = UDim2.fromOffset(CARD_W - 73, 22), Parent = card })
		local holder = new("Frame", { Name = "State", BackgroundTransparency = 1, Position = UDim2.fromOffset(76, 33), Size = UDim2.fromOffset(CARD_W - 82, 25), Parent = card })
		local shown = ""
		table.insert(refreshers, function()
			local level = Progression.level(State.data.XP or 0)
			local claimed = State.data.Claimed[tostring(r.Level)] == true
			local kind = if claimed then "Claimed" elseif r.Unavailable or level < r.Level then "Locked" else "Claim"
			if kind == shown then return end
			shown = kind
			for _, ch in holder:GetChildren() do ch:Destroy() end
			local full = UDim2.fromScale(1, 1)
			if kind == "Claimed" then
				chip(holder, { Name = "Claimed", Text = "CLAIMED", Font = Theme.Fonts.Button, TextSize = 13, Icon = "CheckOwned", IconSize = Vector2.new(15, 16), Size = full, Color = COL.Claimed, Rim = COL.ClaimedRim })
			elseif kind == "Locked" then
				chip(holder, { Name = "Locked", Text = "Locked", TextSize = 14, Icon = "Lock", IconSize = Vector2.new(15, 18), Size = full, Color = COL.LockedBox, Rim = COL.LockedRim, OnClick = function()
					Toast.show(if r.Unavailable then r.Name .. " is coming soon." else "Reach Level " .. r.Level .. " to claim " .. r.Name .. ".")
				end })
			else
				local b = Kit.button({ Name = "Claim", Text = "CLAIM", Style = "Action", TextSize = 18, Corner = 3, Size = full, Parent = holder })
				b.onClick(function()
					b.setEnabled(false)
					b.setText("...")
					claim("ClaimReward", r.Level, "Claimed " .. r.Name .. "!")
				end)
				Motion.pop(holder)
			end
		end)
		nodes[i] = x + math.floor(CARD_W / 2)
	end

	-- Milestone line: levels reached on the track (a different measure from the XP bar below).
	local cy = 113
	local first, last = nodes[1] - 60, nodes[#nodes] + 60
	local stops = { first }
	for _, nx in nodes do table.insert(stops, nx) end
	table.insert(stops, last)
	local pieces = {}
	for i = 1, #stops - 1 do
		local a, b = stops[i] + (if i > 1 then 18 else 0), stops[i + 1] - (if i < #stops - 1 then 18 else 0)
		local n = math.max(1, math.round((b - a) / 27))
		local _, set = segBar(free, "Track" .. i, a, cy - 5, b - a, 10, n, 3, COL.Gold, COL.TrackEmpty)
		pieces[i] = set
	end
	local hexes = {}
	for i, r in Progression.Rewards do hexes[i] = hexagon(free, tostring(r.Level), nodes[i], cy) end
	table.insert(refreshers, function()
		local level = Progression.level(State.data.XP or 0)
		for i, set in pieces do set(if level >= i then 1 else 0) end -- piece i ends at node i
		for i, r in Progression.Rewards do hexes[i](level >= r.Level) end
	end)

	-- Bonus cosmetics: shown like the reference, but nothing grants them yet, so they stay locked. Hidden while the
	-- list is empty.
	if #Progression.Bonus == 0 then return end
	local bonus = panel(page, "BonusCosmetics", BODY_X, 188, BODY_W, 91, COL.Section, COL.SectionRim)
	sectionLabel(bonus, "BONUS COSMETICS", 5)
	for i, b in Progression.Bonus do
		local x = 12 + (i - 1) * (CARD_W + CARD_GAP)
		local card = panel(bonus, "Bonus" .. i, x, 25, CARD_W, 60, COL.Bonus, COL.CardRim, COL.BonusBottom)
		Kit.art(b.Art, { Name = "Picture", ScaleType = Enum.ScaleType.Fit, Position = UDim2.fromOffset(1, 1), Size = UDim2.fromOffset(92, 58), Parent = card })
		Kit.icon("Lock", { Name = "Lock", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromOffset(124, 8), Size = UDim2.fromOffset(16, 19), Parent = card })
		chip(card, { Name = "Locked", Text = "Locked", TextSize = 14, Position = UDim2.fromOffset(96, 32), Size = UDim2.fromOffset(55, 19), Color = COL.LockedBox, Rim = COL.LockedRim, OnClick = function()
			Toast.show(b.Name .. " can't be earned yet.")
		end })
	end
end

-- QUESTS ----------------------------------------------------------------------------------------------------------
local QW, QH = 333, 109

-- One quest card at (x, y): icon, name, its reward, the progress bar and CLAIM / CLAIMED, XP on the right.
local function questCard(page: Instance, q, x: number, y: number, refreshers: { () -> () })
	do
		local card = panel(page, q.Id, x, y, QW, QH, COL.Quest, COL.QuestRim)
		new("Frame", { Name = "IconCell", Position = UDim2.fromOffset(1, 1), Size = UDim2.new(0, 64, 1, -2), BackgroundColor3 = COL.IconCell, BorderSizePixel = 0, Parent = card }, { Kit.corner(3) })
		Kit.icon(q.Icon, { Name = "Icon", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0, 33, 0.5, 0), Size = UDim2.fromOffset(46, 46), Parent = card })
		local xpCell = new("Frame", { Name = "XpCell", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -1, 0, 1), Size = UDim2.new(0, 60, 1, -2), BackgroundColor3 = COL.XpCell, BorderSizePixel = 0, Parent = card }, { Kit.corner(3) })
		Kit.icon("XpBadge", { Name = "Badge", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 20), Size = UDim2.fromOffset(31, 37), Parent = xpCell })
		Kit.text({ Name = "Amount", Text = tostring(q.XP), FontFace = Theme.Fonts.Number, TextSize = 18, TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.fromOffset(0, 60), Size = UDim2.new(1, 0, 0, 24), TextWrapped = false, Parent = xpCell })
		local tx = 76
		local textW = QW - tx - 70
		Kit.name({ Name = "Name", Text = q.Name, TextSize = 16, Position = UDim2.fromOffset(tx, 16), Size = UDim2.fromOffset(textW, 24), Parent = card })
		Kit.text({ Name = "Blurb", Text = "Reward: " .. Progression.rewardText(q), TextSize = 14, TextColor3 = C.Accent, Position = UDim2.fromOffset(tx, 41), Size = UDim2.fromOffset(textW, 20), TextWrapped = false, Parent = card })
		local barY, barH = 69, 17
		local barW = textW - 50
		local bar, set = segBar(card, "Progress", tx, barY, barW, barH, 5, 3, COL.SegFill, COL.QuestEmpty)
		local count = Kit.text({ Name = "Count", Text = "", FontFace = Theme.Fonts.Number, TextSize = 14, TextXAlignment = Enum.TextXAlignment.Center, BackgroundTransparency = 0, BackgroundColor3 = COL.CountBox, Position = UDim2.fromOffset(tx + barW + 5, barY - 1), Size = UDim2.fromOffset(textW - barW - 5, barH + 2), TextWrapped = false, Parent = card })
		Kit.attach(Kit.corner(3), count)
		-- finished: one solid bar with the count inside, next to CLAIM (or CLAIMED once claimed)
		local doneW = textW - 84
		local done = Kit.text({ Name = "DoneBar", Text = "", FontFace = Theme.Fonts.Number, TextSize = 14, TextXAlignment = Enum.TextXAlignment.Center, BackgroundTransparency = 0, BackgroundColor3 = COL.Done, Position = UDim2.fromOffset(tx, barY - 1), Size = UDim2.fromOffset(doneW, barH + 2), TextWrapped = false, Visible = false, Parent = card })
		Kit.attach(Kit.corner(3), done)
		local holder = new("Frame", { Name = "State", BackgroundTransparency = 1, Position = UDim2.fromOffset(tx + doneW + 6, barY + math.floor(barH / 2) - 16), Size = UDim2.fromOffset(textW - doneW - 6, 32), Parent = card })
		local shown = ""
		table.insert(refreshers, function()
			local have = State.data.Stats[q.Stat] or 0
			local shownCount = math.min(have, q.Target)
			local text = string.format("%d / %d", shownCount, q.Target)
			local claimed = State.data.QuestsClaimed[q.Id] == true
			local finished = have >= q.Target
			local kind = if claimed then "Claimed" elseif finished then "Claim" else "Progress"
			set(shownCount / q.Target)
			count.Text, done.Text = text, text
			if kind == shown then return end
			shown = kind
			bar.Visible = kind == "Progress"
			count.Visible = kind == "Progress"
			done.Visible = kind ~= "Progress"
			done.BackgroundColor3 = if claimed then COL.DoneClaimed else COL.Done
			for _, ch in holder:GetChildren() do ch:Destroy() end
			if kind == "Claim" then
				local b = Kit.button({ Name = "Claim", Text = "CLAIM", Style = "Action", TextSize = 21, Corner = 3, Size = UDim2.fromScale(1, 1), Parent = holder })
				b.onClick(function()
					b.setEnabled(false)
					b.setText("...")
					claim("ClaimQuest", q.Id, `+{Progression.rewardText(q)} and {q.XP} XP!`)
				end)
				Motion.pop(holder)
			elseif kind == "Claimed" then
				chip(holder, { Name = "Claimed", Text = "CLAIMED", Font = Theme.Fonts.Button, TextSize = 14, Icon = "CheckOwned", IconSize = Vector2.new(15, 16), Gap = 4, Size = UDim2.fromScale(1, 1), Color = COL.Claimed, Rim = COL.ClaimedRim })
			end
		end)
	end
end

-- Quests (owner: lore quests): the chapter you're on, its two quests, and its story underneath. Chapters open one
-- after another (the server checks the same); when they're all done the last one stays, with a note.
local function buildQuests(page: Frame, refreshers: { () -> () })
	local strip = panel(page, "Chapter", BODY_X, 50, BODY_W, 26, COL.Section, COL.SectionRim)
	local chapterTitle = Kit.name({ Name = "Title", Text = "", TextSize = 15, Position = UDim2.fromOffset(10, 1), Size = UDim2.new(1, -120, 1, -2), Parent = strip })
	local chapterNo = Kit.text({ Name = "Number", Text = "", FontFace = Theme.Fonts.Number, TextSize = 13, TextColor3 = C.SubText, TextXAlignment = Enum.TextXAlignment.Right, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -10, 0, 4), Size = UDim2.fromOffset(100, 18), TextWrapped = false, Parent = strip })
	local cards = new("Frame", { Name = "Cards", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Parent = page })
	local loreY = 80 + QH + 7
	local lore = panel(page, "Lore", BODY_X, loreY, BODY_W, 279 - loreY, COL.Section, COL.SectionRim)
	Kit.text({ Name = "Heading", Text = "THE STORY", FontFace = Theme.Fonts.Heading, TextSize = 13, TextColor3 = C.Accent, Position = UDim2.fromOffset(12, 7), Size = UDim2.fromOffset(200, 16), TextWrapped = false, Parent = lore })
	local loreText = Kit.text({ Name = "Text", Text = "", FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Medium, Enum.FontStyle.Italic), TextSize = 15, LineHeight = 1.05, TextColor3 = C.Text, TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top, Position = UDim2.fromOffset(12, 26), Size = UDim2.new(1, -24, 1, -50), Parent = lore })
	local nextLine = Kit.text({ Name = "Next", Text = "", TextSize = 13, TextColor3 = C.SubText, AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 12, 1, -6), Size = UDim2.new(1, -24, 0, 16), TextWrapped = false, Parent = lore })
	local built, cardRefreshers = nil, {}
	table.insert(refreshers, function()
		local current = Progression.shownChapter(State.data.QuestsClaimed, State.data.Stats)
		local shown = math.min(current, #Progression.Chapters)
		if built ~= shown then
			built = shown
			cardRefreshers = {}
			for _, ch in cards:GetChildren() do ch:Destroy() end
			local chapter = Progression.Chapters[shown]
			for i, q in chapter.Quests do
				questCard(cards, q, BODY_X + (i - 1) * (QW + BODY_W - 2 * QW), 80, cardRefreshers)
			end
			chapterTitle.Text = `CHAPTER {shown}: {string.upper(chapter.Title)}`
		end
		loreText.Text = Progression.Chapters[shown].Lore
		nextLine.Text = if current > #Progression.Chapters then "The story so far is complete: more chapters are coming."
			elseif shown < #Progression.Chapters and Progression.currentChapter(State.data.QuestsClaimed) <= shown then `Claim a quest to open chapter {shown + 1}: {Progression.Chapters[shown + 1].Title}.`
			else "Claim both quests to finish this chapter."
		chapterNo.Text = string.format("%d / %d", shown, #Progression.Chapters)
		for _, f in cardRefreshers do f() end
	end)
end

-- The level bar shared by both tabs: LEVEL n · xp / 300 XP, a 10-part bar, and the next reward.
local function buildLevelBar(parent: Instance, refreshers: { () -> () })
	local bar = panel(parent, "LevelBar", BODY_X, 284, BODY_W, 29, COL.Bar, COL.BarRim)
	local textRow = new("Frame", { Name = "Level", BackgroundTransparency = 1, Position = UDim2.fromOffset(10, 0), Size = UDim2.fromOffset(170, 29), Parent = bar }, { Kit.list(Enum.FillDirection.Horizontal, 3, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center) })
	local function part(name: string, order: number, font: Font, size: number, color: Color3)
		return Kit.text({ Name = name, Text = "", FontFace = font, TextSize = size, TextColor3 = color, AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.new(0, 0, 1, 0), TextWrapped = false, LayoutOrder = order, Parent = textRow })
	end
	local levelText = part("LevelText", 1, Theme.Fonts.Heading, 15, C.Text)
	part("Dot", 2, Theme.Fonts.Number, 14, COL.Yellow).Text = "·"
	local xpText = part("Xp", 3, Theme.Fonts.Number, 14, COL.Yellow)
	local ofText = part("Of", 4, Theme.Fonts.Number, 14, C.Text)
	local _, setXp = segBar(bar, "XpBar", 194, 8, 230, 13, 10, 3, COL.SegFill, COL.SegEmpty)
	Kit.name({ Name = "NextLabel", Text = "Next Reward:", TextSize = 12, Position = UDim2.fromOffset(436, 0), Size = UDim2.fromOffset(90, 29), Parent = bar })
	local nextArt = new("Frame", { Name = "NextArt", BackgroundTransparency = 1, Position = UDim2.fromOffset(530, 1), Size = UDim2.fromOffset(30, 27), Parent = bar })
	local nextName = Kit.name({ Name = "NextName", Text = "", TextSize = 13, TextXAlignment = Enum.TextXAlignment.Right, Position = UDim2.fromOffset(562, 0), Size = UDim2.fromOffset(90, 29), Parent = bar })
	local nextLock = Kit.icon("Lock", { Name = "NextLock", Position = UDim2.fromOffset(657, 6), Size = UDim2.fromOffset(13, 16), Parent = bar })
	local artName = nil
	table.insert(refreshers, function()
		local level, xpIn, xpNeeded = Progression.level(State.data.XP or 0)
		levelText.Text = "LEVEL " .. level
		xpText.Text = tostring(xpIn)
		ofText.Text = "/ " .. xpNeeded .. " XP"
		setXp(xpIn / xpNeeded)
		local nextReward = nil
		for _, r in Progression.Rewards do
			if r.Level > level then nextReward = r break end
		end
		nextName.Text = if nextReward then nextReward.Name else "All reached!"
		nextLock.Visible = nextReward ~= nil
		local want = nextReward and rewardArt(nextReward)
		if want ~= artName then
			artName = want
			for _, ch in nextArt:GetChildren() do ch:Destroy() end
			if want then
				local pic = Kit.art(want, { Name = "Picture", Size = UDim2.fromScale(1, 1), Parent = nextArt })
				Kit.attach(Kit.corner(3), pic)
			end
		end
	end)
end

function ProgressionScreen.build(parent: Instance)
	local window = Kit.window({ Name = "Progression", Title = "PROGRESSION", Icon = "RewardsTrophy", Width = W, Height = H, TitleX = 60, TitleOffsetY = 2, TitleSize = 24, TitleWidth = 184, StudsTo = 276, Parent = parent, OnClose = function() ModalManager.close() end })
	local header = window.Header
	Kit.studs(header, 577, 648, 15)
	local refreshers: { () -> () } = {}
	local pages = {}
	for name, build in { Rewards = buildRewards, Quests = buildQuests } do
		local page = new("Frame", { Name = name, Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Visible = false, Parent = window.Panel })
		build(page, refreshers)
		pages[name] = page
	end
	buildLevelBar(window.Panel, refreshers)

	local function items(key: string)
		local list = {}
		for _, ch in pages[key]:GetChildren() do if ch:IsA("GuiObject") then table.insert(list, ch) end end
		table.sort(list, function(a, b)
			local pa, pb = a:GetAttribute("HomePosition") or a.Position, b:GetAttribute("HomePosition") or b.Position
			return pa.Y.Offset * 10000 + pa.X.Offset < pb.Y.Offset * 10000 + pb.X.Offset
		end)
		return list
	end
	-- the title icon follows the tab, as in the references (trophy on Rewards, clipboard on Quests)
	local function setIcon(key: string)
		local old = header:FindFirstChild("TitleIcon") :: ImageLabel?
		local want = if key == "Quests" then "QuestsClipboard" else "RewardsTrophy"
		if not old or old:GetAttribute("Icon") == want then return end
		local props = { Name = "TitleIcon", AnchorPoint = old.AnchorPoint, Position = old.Position, Size = old.Size, Parent = header }
		old:Destroy()
		Kit.icon(want, props)
	end
	local tabs
	local function show(key: string)
		for name, page in pages do page.Visible = name == key end
		setIcon(key)
		Motion.stagger(items(key))
	end
	-- header coords (the header starts 4 px inside the window): tabs centred in its 43 px height
	tabs = Kit.tabs(header, {
		{ Key = "Rewards", Text = "REWARDS", X = 283, Width = 142 },
		{ Key = "Quests", Text = "QUESTS", X = 429, Width = 138 },
	}, 6, 31, show, 17, "HeaderTab")

	local function refresh() for _, f in refreshers do f() end end
	State.changed(refresh)
	refresh()

	ModalManager.register("Progression", {
		window = window,
		onOpen = function(arg)
			local key = if arg == "Quests" or arg == "Rewards" then arg else tabs.selected() or "Rewards"
			if tabs.selected() ~= key then
				tabs.select(key)
				for name, page in pages do page.Visible = name == key end
				setIcon(key)
			end
		end,
		firstSelect = function() return tabs.buttons.Rewards.Instance end,
		items = function() return items(tabs.selected() or "Rewards") end,
	})
	tabs.select("Rewards")
	pages.Rewards.Visible = true
	return window
end

return ProgressionScreen
