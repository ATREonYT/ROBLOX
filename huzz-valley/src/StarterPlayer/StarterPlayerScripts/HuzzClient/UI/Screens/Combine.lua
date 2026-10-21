-- The Combine window (owner, Oct 20 14:57: "make it so that you can take two of the same girl, and then it creates
-- the same skin, but first in silver, then gold, and then diamond. make it so that you need to have both of the types
-- to go up"). Opened by the prompt on his Combine machine (HuzzServer/CombineService, Gameplay/LobbyProps).
-- Oct 21 rework (owner: "right now it looks very ai made, the little joy seen text on the side and the not even slots
-- for the characters, make the ui for understandable ... having two girls on both sides of the ui, and then you get
-- the one in the middle, check out other combine references"): laid out like the fuse machines kids know from pet
-- games, in the Shop's look (UI/ShopStyle):
--   * the stage: her two copies stand in the two side slots (left and right, the grade on each), arrows point in, and
--     the girl you get stands big in the middle on a glow in her new grade's colour, her name under her
--     ("SILVER KURUMI"); with nothing picked every slot shows a big "?";
--   * the grade path under her: NORMAL x3 > SILVER x1 > GOLD x0 > DIAMOND (tap a grade to combine that one);
--   * the line saying what happens ("2 Normal Kurumi make 1 Silver Kurumi!") or why not, and the big COMBINE;
--   * YOUR GIRLS: a strip of cards along the bottom (her picture, name, copies, READY when two match), the ready ones
--     first; tap one to put her in the slots. No girls yet: the strip says how to get one.
-- Motion: the cards pop in on open (ModalManager, ShopStyle.popIn); picking a girl pops the slots; the middle glow and
-- a ready COMBINE breathe. Pressing COMBINE closes the window and the merge plays on the machine
-- (Gameplay/CombineMachine, about 4 s, tap anywhere to skip once the server said yes); her name and new grade come up
-- big at the burst ("GOLD YUI!"), then the window opens again on her. The rules are Shared/CombineRules.can, the same
-- the server checks.
-- Flat window: the pictures are ViewportFrames, which don't draw inside a CanvasGroup.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local CombineRules = require(Shared.CombineRules)
local CombineConfig = require(Shared.Config.Combine)
local Characters = require(Shared.Config.Characters)
local UI = script.Parent.Parent
local Theme = require(UI.Theme)
local Kit = require(UI.Kit)
local State = require(UI.State)
local Toast = require(UI.Toast)
local ModalManager = require(UI.ModalManager)
local Motion = require(UI.Motion)
local GirlPicture = require(UI.GirlPicture)
local ShopStyle = require(UI.ShopStyle)
local Effects = require(UI.Effects)
local CombineMachine = require(UI.Parent.Gameplay.CombineMachine)

local new = Kit.new
local C, F = Theme.Colors, Theme.Fonts

local CombineScreen = {}

local W, H = 720, 584
local STAGE = { X = 14, Y = 56, W = 692, H = 304 } -- the merge (its name "Merge" is what the checks look for)
local SLOT = { W = 116, H = 150, Y = 50, Edge = 34 } -- her two copies, left and right
local MID = { W = 156, H = 176, Y = 50 } -- the girl you get, in the middle
local PATH = { Y = 266, H = 30, W = 128, Arrow = 26 } -- NORMAL > SILVER > GOLD > DIAMOND
local STRIP = { X = 14, Y = 470, W = 692, H = 104, CardW = 128, CardH = 100, Gap = 8, Pic = 60 }
local STEPS = { "Normal", "Silver", "Gold" } -- the grades that can be combined (Diamond is the top)
local FONT = ShopStyle.FONT
local INK2 = Color3.fromHex("0F1A38") -- the dark of every inset box (pills, slots' floors, the girls' tray)

local function line(props: { [string]: any }, stroke: number?): TextLabel
	props.TextWrapped = props.TextWrapped or false
	local l = Kit.text(props)
	new("UIStroke", { Name = "Outline", Color = ShopStyle.INK, Thickness = stroke or 1.5, LineJoinMode = Enum.LineJoinMode.Round, Parent = l })
	return l
end
local chunky = ShopStyle.chunky

local function gradeColor(grade: string?): Color3
	local g = grade and CombineConfig.Grades[grade]
	return g and g.Badge or C.SubText
end

-- "GOLD YUI" (a Normal girl is just her name).
local function title(name: string, grade: string?): string
	local label = CombineRules.label(grade)
	return if label ~= "" then label .. " " .. string.upper(name) else string.upper(name)
end

-- Her copies in one short line: "Normal 3   Silver 1".
local function countsLine(counts: { [string]: number }): string
	local parts = {}
	for _, g in CombineRules.Grades do
		if (counts[g] or 0) > 0 then table.insert(parts, `{g} {counts[g]}`) end
	end
	return table.concat(parts, "   ")
end

function CombineScreen.build(parent: Instance)
	local window = Kit.window({ Name = "Combine", Title = "COMBINE", Icon = "CompanionEffects", Width = W, Height = H, TitleX = 20, TitleWidth = 170, Flat = true, Parent = parent, OnClose = function() ModalManager.close() end })
	local panel, header = window.Panel, window.Header
	local titleIcon = header:FindFirstChild("TitleIcon")
	if titleIcon and titleIcon:IsA("GuiObject") then titleIcon.Visible = false end
	for _, n in { "Title", "TitleShadow" } do
		local t = header:FindFirstChild(n)
		if t and t:IsA("TextLabel") then t.FontFace = FONT end
	end

	-- the stage: copy | > result < | copy
	local side = new("Frame", { Name = "Merge", Position = UDim2.fromOffset(STAGE.X, STAGE.Y), Size = UDim2.fromOffset(STAGE.W, STAGE.H), BackgroundColor3 = Color3.fromHex("1A2A52"), BackgroundTransparency = 0.08, BorderSizePixel = 0, ZIndex = 2, Parent = panel }, { Kit.corner(10), Kit.stroke(C.Frame, 3) })
	new("UIGradient", { Name = "Depth", Rotation = 90, Color = ColorSequence.new(Color3.fromHex("2A4276"), Color3.fromHex("1A2A52")), Parent = side })
	-- the rule, on a dark pill with a green rim
	local banner = new("Frame", { Name = "Banner", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 8), Size = UDim2.fromOffset(364, 30), BackgroundColor3 = INK2, BorderSizePixel = 0, ZIndex = 3, Parent = side }, { Kit.corner(15), Kit.stroke(C.Accent, 2) })
	chunky({ Name = "Heading", Text = "2 SAME GIRLS = 1 BETTER GIRL", FontFace = FONT, TextSize = 19, TextColor3 = C.Accent, Size = UDim2.fromScale(1, 1), ZIndex = 4, Parent = banner }, 2)
	local function slot(name: string, x: number, y: number, w: number, h: number, rim: number): Frame
		local f = new("Frame", { Name = name, Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(w, h), BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0, BorderSizePixel = 0, ClipsDescendants = false, ZIndex = 4, Parent = side }, { Kit.corner(12) })
		new("UIGradient", { Name = "Floor", Rotation = 90, Color = ColorSequence.new(Color3.fromHex("34508E"), INK2), Parent = f })
		local stroke = Kit.stroke(Color3.fromHex("6C7FB8"), rim)
		stroke.Name = "Rim" -- (named before attach, so the saved copy is reused)
		Kit.attach(stroke, f)
		chunky({ Name = "Unknown", Text = "?", FontFace = FONT, TextSize = math.floor(h * 0.42), TextColor3 = Color3.fromHex("8A9AD0"), Size = UDim2.fromScale(1, 1), ZIndex = 5, Parent = f }, 2)
		return f
	end
	local midX = math.floor((STAGE.W - MID.W) / 2)
	-- the middle's glow in the new grade's colour (behind her), breathing
	local glow = new("Frame", { Name = "Glow", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(midX + MID.W / 2, MID.Y + MID.H / 2), Size = UDim2.fromOffset(MID.W + 70, MID.H + 22), BackgroundColor3 = C.Accent, BackgroundTransparency = 0, BorderSizePixel = 0, ZIndex = 3, Parent = side }, { Kit.corner(30) })
	new("UIGradient", { Name = "Fade", Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0.45), NumberSequenceKeypoint.new(1, 1) }), Parent = glow })
	Effects.breathe(glow, { scale = 1.05, seconds = 1.1 })
	local inA = slot("InputA", SLOT.Edge, SLOT.Y, SLOT.W, SLOT.H, 3)
	local inB = slot("InputB", STAGE.W - SLOT.Edge - SLOT.W, SLOT.Y, SLOT.W, SLOT.H, 3)
	local out = slot("Result", midX, MID.Y, MID.W, MID.H, 4)
	for i, x in { SLOT.Edge, STAGE.W - SLOT.Edge - SLOT.W } do
		chunky({ Name = "Caption" .. i, Text = "COPY " .. i, FontFace = FONT, TextSize = 16, TextColor3 = Color3.fromHex("A9B8E8"), Position = UDim2.fromOffset(x, SLOT.Y + SLOT.H + 6), Size = UDim2.fromOffset(SLOT.W, 20), ZIndex = 4, Parent = side }, 1.5)
	end
	local arrowY = SLOT.Y + SLOT.H / 2 - 22
	local aGap = midX - (SLOT.Edge + SLOT.W)
	local function disc(name: string, mark: string, x: number): Frame
		local d = new("Frame", { Name = name, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(x, arrowY + 22), Size = UDim2.fromOffset(46, 46), BackgroundColor3 = C.SelectedTab, BorderSizePixel = 0, ZIndex = 4, Parent = side }, { Kit.corner(23), Kit.stroke(ShopStyle.INK, 3) })
		new("UIGradient", { Name = "Lit", Rotation = 90, Color = ColorSequence.new(C.SelectedTabTop, C.SelectedTab), Parent = d })
		chunky({ Name = "Mark", Text = mark, FontFace = FONT, TextSize = 30, Position = UDim2.fromOffset(0, -2), Size = UDim2.fromScale(1, 1), ZIndex = 5, Parent = d }, 2.5)
		return d
	end
	local arrowL = disc("ArrowIn", ">", SLOT.Edge + SLOT.W + math.floor(aGap / 2))
	local arrowR = disc("ArrowIn2", "<", midX + MID.W + math.floor(aGap / 2))
	Effects.breathe(arrowL, { scale = 1.12, seconds = 0.6 })
	Effects.breathe(arrowR, { scale = 1.12, seconds = 0.6 })
	local NAME_W = STAGE.W - 2 * (SLOT.Edge + SLOT.W) - 16 -- (between her two copies, so it never runs over them)
	local resultName = chunky({ Name = "ResultName", Text = "", FontFace = FONT, TextSize = 24, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, MID.Y + MID.H + 4), Size = UDim2.fromOffset(NAME_W, 28), ZIndex = 4, Parent = side }, 2)
	-- the grade path: NORMAL x3 > SILVER x1 > GOLD x0 > DIAMOND (the three you can combine are buttons)
	local pathW = 3 * PATH.W + 3 * PATH.Arrow + 110
	local px = math.floor((STAGE.W - pathW) / 2)
	local chips = {}
	local chipCounts = {}
	for i, g in STEPS do
		local b = ShopStyle.chunkyButton(Kit.button({ Name = "Grade" .. g, Text = string.upper(g), Style = "Tab", FontFace = FONT, TextSize = 15, Gap = 6, Corner = 6, RimThickness = 1.5, Position = UDim2.fromOffset(px, PATH.Y), Size = UDim2.fromOffset(PATH.W, PATH.H), ZIndex = 5, Parent = side }))
		chips[g] = b
		-- how many she has of this grade: a round dark bubble right after the word, centred with it in the chip's row
		-- (owner, Oct 21: "fix the x3 x1 ... make it be perfectly aligned")
		local row = b.Instance:FindFirstChild("Content")
		local bubble = new("Frame", { Name = "Count", Size = UDim2.fromOffset(22, 22), BackgroundColor3 = INK2, BackgroundTransparency = 0.15, BorderSizePixel = 0, LayoutOrder = 3, ZIndex = 6, Parent = row }, { Kit.corner(11) })
		chipCounts[g] = chunky({ Name = "N", Text = "0", FontFace = FONT, TextSize = 14, Size = UDim2.fromScale(1, 1), ZIndex = 7, Parent = bubble }, 1.5)
		px += PATH.W
		chunky({ Name = "Step" .. i, Text = ">", FontFace = FONT, TextSize = 20, TextColor3 = C.SubText, Position = UDim2.fromOffset(px, PATH.Y), Size = UDim2.fromOffset(PATH.Arrow, PATH.H), ZIndex = 5, Parent = side }, 1.5)
		px += PATH.Arrow
	end
	local top = chunky({ Name = "GradeDiamond", Text = "DIAMOND", FontFace = FONT, TextSize = 15, TextColor3 = gradeColor("Diamond"), BackgroundTransparency = 0, BackgroundColor3 = INK2, Position = UDim2.fromOffset(px, PATH.Y), Size = UDim2.fromOffset(110, PATH.H), ZIndex = 5, Parent = side }, 1.5)
	local topRim = Kit.stroke(gradeColor("Diamond"), 2)
	topRim.Name = "Rim"
	Kit.attach(topRim, top)
	Kit.attach(Kit.corner(6), top)
	-- what happens, and COMBINE
	local reason = line({ Name = "Reason", Text = "", FontFace = F.Body, TextSize = 16, TextColor3 = C.Text, TextXAlignment = Enum.TextXAlignment.Center, BackgroundTransparency = 0.1, BackgroundColor3 = INK2, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, STAGE.H + 4), Size = UDim2.fromOffset(STAGE.W - 120, 24), ZIndex = 3, Parent = side }, 1.2) -- (just under the stage)
	Kit.attach(Kit.corner(12), reason)
	local combine = ShopStyle.chunkyButton(Kit.button({ Name = "CombineButton", Text = "COMBINE", Style = "Disabled", FontFace = FONT, TextSize = 26, Corner = 6, RimThickness = 2, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, STAGE.H + 36), Size = UDim2.fromOffset(260, 44), ZIndex = 5, Parent = side }))
	local combineBreathe = Effects.breathe(combine.Instance, { scale = 1.04, seconds = 0.9 })
	combineBreathe.Name = "ReadyBreathe"

	-- YOUR GIRLS: the strip of cards
	new("Frame", { Name = "Tray", Position = UDim2.fromOffset(STRIP.X, STRIP.Y - 26), Size = UDim2.fromOffset(STRIP.W, STRIP.H + 30), BackgroundColor3 = INK2, BackgroundTransparency = 0.1, BorderSizePixel = 0, ZIndex = 1, Parent = panel }, { Kit.corner(10), Kit.stroke(C.Frame, 3) })
	chunky({ Name = "GirlsHeading", Text = "YOUR GIRLS", FontFace = FONT, TextSize = 16, TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.fromOffset(STRIP.X + 4, STRIP.Y - 22), Size = UDim2.fromOffset(200, 20), ZIndex = 3, Parent = panel }, 1.5)
	local list = new("ScrollingFrame", { Name = "Girls", Position = UDim2.fromOffset(STRIP.X, STRIP.Y), Size = UDim2.fromOffset(STRIP.W, STRIP.H), BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 4, ScrollBarImageColor3 = C.RowBorder, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.X, ScrollingDirection = Enum.ScrollingDirection.X, Selectable = false, ZIndex = 2, Parent = panel })
	new("UIPadding", { Name = "Pad", PaddingLeft = UDim.new(0, 4), PaddingRight = UDim.new(0, 4), PaddingTop = UDim.new(0, 2), PaddingBottom = UDim.new(0, 2), Parent = list })
	new("UIListLayout", { Name = "Layout", FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, STRIP.Gap), SortOrder = Enum.SortOrder.LayoutOrder, Parent = list })
	local empty = chunky({ Name = "Empty", Text = "No girls yet. Win a round to get one!", FontFace = FONT, TextSize = 20, TextColor3 = C.NoteText, Position = UDim2.fromOffset(STRIP.X, STRIP.Y + 30), Size = UDim2.fromOffset(STRIP.W, 40), Visible = false, ZIndex = 3, Parent = panel }, 1.5)

	-- the reveal over the game ("GOLD YUI!") and the tap-to-skip catcher (outside the window: the window is closed)
	local reveal = new("Frame", { Name = "CombineReveal", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0.14), Size = UDim2.fromOffset(520, 96), BackgroundTransparency = 1, Visible = false, ZIndex = 40, Parent = parent })
	local revealTitle = line({ Name = "Title", Text = "", FontFace = FONT, TextSize = 48, TextScaled = true, TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.new(1, 0, 0, 58), ZIndex = 41, Parent = reveal }, 3)
	new("UITextSizeConstraint", { Name = "Fit", MaxTextSize = 48, MinTextSize = 20, Parent = revealTitle })
	local revealLine = line({ Name = "Line", Text = "", FontFace = FONT, TextSize = 20, TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.fromOffset(0, 62), Size = UDim2.new(1, 0, 0, 24), ZIndex = 41, Parent = reveal }, 1.6)
	local skip = new("TextButton", { Name = "CombineSkip", Text = "", AutoButtonColor = false, BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Visible = false, ZIndex = 39, Selectable = false, Parent = parent })
	local skipHint = line({ Name = "Hint", Text = "TAP TO SKIP", FontFace = FONT, TextSize = 16, TextColor3 = C.SubText, TextXAlignment = Enum.TextXAlignment.Center, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -24), Size = UDim2.fromOffset(200, 20), Visible = false, ZIndex = 41, Parent = skip }, 1.2)

	local picked: string? = nil -- her id
	local pickedGrade: string? = nil
	local busy = false
	local open = false
	local rows = {}
	local drawn = { a = "", b = "", r = "" }

	local function picture(holder: Frame, keyName: string, key: string?, grade: string?)
		local want = (key or "") .. "|" .. (grade or "")
		if drawn[keyName] == want then return end
		drawn[keyName] = want
		for _, c in holder:GetChildren() do
			if c:IsA("ViewportFrame") or c.Name == "GradeBadge" then c:Destroy() end
		end
		local unknown = holder:FindFirstChild("Unknown")
		if unknown then unknown.Visible = key == nil end
		local rim = holder:FindFirstChild("Rim")
		if rim and rim:IsA("UIStroke") then rim.Color = if key then gradeColor(grade or "Normal") else Color3.fromHex("6C7FB8") end
		if not key then return end
		local vp = GirlPicture.draw(holder, key, true, true, grade)
		if vp then
			vp.ZIndex = 5
			vp.Parent = holder
		end
		Kit.badge({ Name = "GradeBadge", Text = string.upper(grade or "Normal"), Color = gradeColor(grade or "Normal"), TextColor = C.Frame, Height = 22, TextSize = 13, MinTextSize = 9, MaxWidth = holder.Size.X.Offset - 8, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -5), ZIndex = 6, Parent = holder })
		Motion.pop(holder)
	end

	local function syncGirls()
		local f = GirlPicture.folder()
		if f then Characters.addGirls(f) end
	end

	local refresh
	local function choose(id: string, grade: string?)
		picked, pickedGrade = id, grade
		refresh()
	end

	refresh = function()
		syncGirls()
		local all = CombineRules.choices(State.data, Characters.List)
		local byId = {}
		for _, c in all do byId[c.id] = c end
		if picked and not byId[picked] then picked = nil end
		if not picked and all[1] then picked, pickedGrade = all[1].id, nil end
		empty.Visible = #all == 0
		-- rows (made once per girl, reused)
		local seen = {}
		for i, c in all do
			seen[c.id] = true
			local r = rows[c.id]
			if not r then
				local row = new("TextButton", { Name = "Girl_" .. c.id, Text = "", AutoButtonColor = false, Size = UDim2.fromOffset(STRIP.CardW, STRIP.CardH), BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0, BorderSizePixel = 0, ZIndex = 3, Parent = list }, { Kit.corner(8) })
				new("UIGradient", { Name = "Floor", Rotation = 90, Color = ColorSequence.new(Color3.fromHex("34508E"), Color3.fromHex("1C2C5A")), Parent = row })
				local rim = Kit.stroke(C.Frame, 2)
				rim.Parent = row
				local pic = new("Frame", { Name = "Picture", Position = UDim2.fromOffset(4, 4), Size = UDim2.fromOffset(STRIP.CardW - 8, STRIP.Pic), BackgroundColor3 = C.Frame, BackgroundTransparency = 0.4, BorderSizePixel = 0, ClipsDescendants = true, ZIndex = 4, Parent = row }, { Kit.corner(6) })
				local name = chunky({ Name = "GirlName", Text = c.name, FontFace = FONT, TextSize = 15, Position = UDim2.fromOffset(4, STRIP.Pic + 5), Size = UDim2.fromOffset(STRIP.CardW - 8, 18), ZIndex = 4, Parent = row }, 1.5)
				local counts = line({ Name = "Copies", Text = "", FontFace = F.Body, TextSize = 11, TextColor3 = C.SubText, TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.fromOffset(2, STRIP.Pic + 23), Size = UDim2.fromOffset(STRIP.CardW - 4, 14), ZIndex = 4, Parent = row }, 1)
				local ready = Kit.badge({ Name = "Ready", Text = "READY", Color = C.Accent, TextColor = C.Frame, Height = 18, TextSize = 11, MinTextSize = 9, MaxWidth = 60, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -4, 0, 4), ZIndex = 6, Parent = row })
				r = { row = row, rim = rim, name = name, counts = counts, ready = ready, pic = pic, drawn = "" }
				rows[c.id] = r
				local id = c.id
				row.MouseButton1Click:Connect(function()
					if busy then return end
					choose(id, nil)
				end)
			end
			r.row.LayoutOrder = i
			r.row.Visible = true
			local best = c.best
			local want = c.model .. "|" .. tostring(best)
			if r.drawn ~= want then
				r.drawn = want
				for _, v in r.pic:GetChildren() do if v:IsA("ViewportFrame") then v:Destroy() end end
				local vp = GirlPicture.draw(r.pic, c.model, true, false, best)
				if vp then vp.ZIndex = 5; vp.Parent = r.pic end
			end
			Kit.fitLine(r.name, STRIP.CardW - 8, 15, 10, true)
			r.counts.Text = countsLine(c.counts)
			Kit.fitLine(r.counts, STRIP.CardW - 6, 11, 8, true)
			r.ready.Visible = c.ready ~= nil
			local on = c.id == picked
			r.rim.Color = if on then C.Accent else C.Frame
			r.rim.Thickness = if on then 3 else 2
		end
		for id, r in rows do
			if not seen[id] then r.row.Visible = false end
		end
		-- the merge side
		local c = picked and byId[picked]
		if not c then
			picture(inA, "a", nil, nil); picture(inB, "b", nil, nil); picture(out, "r", nil, nil)
			resultName.Text = "WIN GIRLS IN ROUNDS"
			resultName.TextColor3 = C.Text
			reason.Text = "Get 2 of the same girl to make her better!"
			combineBreathe.Parent = nil
			combine.setStyle("Disabled"); combine.setEnabled(false)
			for _, b in chips do b.setEnabled(false) end
			return
		end
		-- the grade: the one you picked, else the first you can combine, else her lowest
		local grade = pickedGrade or c.ready
		if not grade then
			for _, g in STEPS do if (c.counts[g] or 0) > 0 then grade = g break end end
		end
		grade = grade or "Normal"
		for g, b in chips do
			b.setText(string.upper(g))
			chipCounts[g].Text = tostring(c.counts[g] or 0)
			b.setStyle(if g == grade then "ShopGreen" else "Tab")
			b.setEnabled(not busy)
		end
		local up = CombineRules.next(grade)
		picture(inA, "a", c.model, grade)
		picture(inB, "b", c.model, grade)
		picture(out, "r", c.model, up)
		resultName.Text = if up then title(c.name, up) else title(c.name, grade)
		resultName.TextColor3 = if up then gradeColor(up) else C.Text
		Kit.fitLine(resultName, NAME_W, 24, 14, true)
		local ok, why = CombineRules.can(State.data, c.id, grade)
		if busy then
			reason.Text = "Combining..."
			combine.setText("..."); combine.setStyle("Disabled"); combine.setEnabled(false)
		elseif ok then
			reason.Text = `2 {grade} {c.name} make 1 {up} {c.name}!`
			combine.setText("COMBINE"); combine.setStyle("ShopGreen"); combine.setEnabled(true)
		else
			reason.Text = why or ""
			combine.setText("COMBINE"); combine.setStyle("Disabled"); combine.setEnabled(false)
		end
		Kit.fitLine(reason, STAGE.W - 140, 16, 11, true)
		combineBreathe.Parent = if ok and not busy then combine.Instance else nil
		glow.BackgroundColor3 = gradeColor(up or grade)
		pickedGrade = grade
	end

	for g, b in chips do
		b.onClick(function()
			if busy or not picked then return end
			choose(picked, g)
		end)
	end

	local function hideReveal()
		reveal.Visible = false
		skip.Visible = false
		skipHint.Visible = false
	end

	combine.onClick(function()
		if busy or not (picked and pickedGrade) then return end
		local id, grade = picked :: string, pickedGrade :: string
		if not CombineRules.can(State.data, id, grade) then return end
		local c = Characters.get(id)
		local up = CombineRules.next(grade)
		if not (c and up) then return end
		busy = true
		refresh()
		ModalManager.close()
		local finished = false
		local gaveUp = nil -- (the machine let go before the server answered: "slow", "round", "moved")
		local function done(reason: string?)
			if finished then return end
			finished = true
			busy = false
			gaveUp = reason
			if reason == "slow" then Toast.show("The machine is busy. Try again.") end
			task.delay(1.2, function()
				hideReveal()
				-- back to the window on her (unless something else opened meanwhile, or a round took you)
				if ModalManager.current() == nil and reason ~= "round" and reason ~= "moved" then
					picked, pickedGrade = id, nil
					ModalManager.open("Combine", id)
				end
			end)
			skip.Visible = false
			skipHint.Visible = false
			refresh()
		end
		local playing, playId = CombineMachine.play({
			key = c.Model, from = grade, to = up, mine = true,
			onReveal = function()
				revealTitle.Text = title(c.Name, up) .. "!"
				revealTitle.TextColor3 = gradeColor(up)
				revealLine.Text = "Two became one!"
				reveal.Visible = true
				Motion.pop(reveal)
			end,
			onDone = function(_, reason) done(reason) end,
		})
		if playing then
			skip.Visible = true
			task.delay(0.6, function() if not finished and skip.Visible then skipHint.Visible = true end end)
		end
		task.spawn(function()
			local ok, info = State.action("Combine", id, grade)
			if playing then CombineMachine.answer(ok, playId) end
			if gaveUp then
				-- (the machine let go first: the answer still counts, saved on the server)
				if ok then Toast.show(title(c.Name, up) .. " is yours!") end
			elseif not ok then
				Toast.show(if type(info) == "string" then info else "Couldn't combine. Try again.")
				if not playing then done() end
			elseif not playing then
				-- (the machine isn't on this screen: the result shows here only)
				revealTitle.Text = title(c.Name, up) .. "!"
				revealTitle.TextColor3 = gradeColor(up)
				revealLine.Text = "Two became one!"
				reveal.Visible = true
				Motion.pop(reveal)
				task.delay(1.2, done)
			end
		end)
	end)
	skip.MouseButton1Click:Connect(function() CombineMachine.skip() end)

	ModalManager.register("Combine", {
		window = window,
		-- arg = her id: open on her
		onOpen = function(arg)
			open = true
			if type(arg) == "string" then picked, pickedGrade = arg, nil end
			refresh()
		end,
		onClose = function() open = false end,
		firstSelect = function() return combine.Instance end,
	})
	State.changed(function() if open or busy then refresh() end end)
	refresh()
	return window.Holder
end

return CombineScreen
