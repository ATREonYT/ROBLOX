-- The Combine window (owner, Oct 20 14:57: "make it so that you can take two of the same girl, and then it creates
-- the same skin, but first in silver, then gold, and then diamond. make it so that you need to have both of the types
-- to go up"). Opened by the prompt on his Combine machine (HuzzServer/CombineService, Gameplay/LobbyProps).
-- Small and tidy, in the kit's look: on the left your girls (the ones ready to combine first, each with her copies
-- by grade); on the right the merge: her two copies + = the result (pictures in their grade, UI/GirlPicture), the
-- grade to combine (NORMAL / SILVER / GOLD with how many you have), the result's name ("GOLD YUI") and the COMBINE
-- button: green when you have two, grey with a short reason when not (Shared/CombineRules.can: the same rules the
-- server checks). Pressing it closes the window and the merge plays on the machine (Gameplay/CombineMachine, about
-- 4 s, tap anywhere to skip once the server said yes); her name and new grade come up big at the burst
-- ("GOLD YUI!"), then the window opens again on her.
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
local CombineMachine = require(UI.Parent.Gameplay.CombineMachine)

local new = Kit.new
local C, F = Theme.Colors, Theme.Fonts

local CombineScreen = {}

local W, H = 600, 430
local LIST = { X = 14, Y = 58, W = 214, H = 358, Row = 50, Gap = 6 }
local SIDE = { X = 240, W = 600 - 240 - 14 }
local PIC = { W = 86, H = 116, Big = 108, BigH = 142, Y = 64, Sign = 22 }
local STEPS = { "Normal", "Silver", "Gold" } -- the grades that can be combined (Diamond is the top)

local function line(props: { [string]: any }, stroke: number?): TextLabel
	props.TextWrapped = props.TextWrapped or false
	local l = Kit.text(props)
	new("UIStroke", { Name = "Outline", Color = C.TitleStroke, Thickness = stroke or 1.5, LineJoinMode = Enum.LineJoinMode.Round, Parent = l })
	return l
end

local function gradeColor(grade: string?): Color3
	local g = grade and CombineConfig.Grades[grade]
	return g and g.Badge or C.SubText
end

-- "GOLD YUI" (a Normal girl is just her name).
local function title(name: string, grade: string?): string
	local label = CombineRules.label(grade)
	return if label ~= "" then label .. " " .. string.upper(name) else string.upper(name)
end

-- Her copies in one short line: "Normal 3  Silver 1".
local function countsLine(counts: { [string]: number }): string
	local parts = {}
	for _, g in CombineRules.Grades do
		if (counts[g] or 0) > 0 then table.insert(parts, `{g} {counts[g]}`) end
	end
	return table.concat(parts, "   ")
end

function CombineScreen.build(parent: Instance)
	local window = Kit.window({ Name = "Combine", Title = "COMBINE", Icon = "CompanionEffects", Width = W, Height = H, TitleX = 56, TitleWidth = 130, Flat = true, Parent = parent, OnClose = function() ModalManager.close() end })
	local panel = window.Panel

	-- the girls
	local list = new("ScrollingFrame", { Name = "Girls", Position = UDim2.fromOffset(LIST.X, LIST.Y), Size = UDim2.fromOffset(LIST.W, LIST.H), BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 4, ScrollBarImageColor3 = C.RowBorder, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollingDirection = Enum.ScrollingDirection.Y, Selectable = false, ZIndex = 2, Parent = panel })
	-- (padding: a ScrollingFrame clips its rows' outside rims)
	new("UIPadding", { Name = "Pad", PaddingLeft = UDim.new(0, 3), PaddingRight = UDim.new(0, 8), PaddingTop = UDim.new(0, 3), PaddingBottom = UDim.new(0, 3), Parent = list })
	new("UIListLayout", { Name = "Layout", Padding = UDim.new(0, LIST.Gap), SortOrder = Enum.SortOrder.LayoutOrder, Parent = list })
	local empty = line({ Name = "Empty", Text = "Win girls in rounds. Two of the same girl make one better!", TextWrapped = true, FontFace = F.Body, TextSize = 15, TextColor3 = C.NoteText, TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.fromOffset(LIST.X, LIST.Y + 40), Size = UDim2.fromOffset(LIST.W, 80), Visible = false, ZIndex = 3, Parent = panel }, 1)

	-- the merge: copy + copy = result
	local side = new("Frame", { Name = "Merge", Position = UDim2.fromOffset(SIDE.X, LIST.Y), Size = UDim2.fromOffset(SIDE.W, LIST.H), BackgroundColor3 = C.Row, BackgroundTransparency = Theme.Transparency.Row, BorderSizePixel = 0, ZIndex = 2, Parent = panel }, { Kit.corner(7), Kit.stroke(C.RowBorder, 2) })
	line({ Name = "Heading", Text = "TWO OF HER MAKE ONE BETTER", FontFace = F.Heading, TextSize = 15, TextColor3 = C.Accent, TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.fromOffset(0, 10), Size = UDim2.fromOffset(SIDE.W, 22), ZIndex = 3, Parent = side }, 1.4)
	local function box(name: string, x: number, w: number, h: number): Frame
		return new("Frame", { Name = name, Position = UDim2.fromOffset(x, PIC.Y - 26 + (PIC.BigH - h)), Size = UDim2.fromOffset(w, h), BackgroundColor3 = C.Frame, BackgroundTransparency = 0.35, BorderSizePixel = 0, ClipsDescendants = false, ZIndex = 3, Parent = side }, { Kit.corner(8), Kit.stroke(C.RowBorder, 2) })
	end
	local gapW = math.floor((SIDE.W - 2 * PIC.W - PIC.Big - 2 * PIC.Sign) / 2)
	local x1 = gapW
	local x2 = x1 + PIC.W + PIC.Sign
	local x3 = x2 + PIC.W + PIC.Sign
	local inA, inB, out = box("InputA", x1, PIC.W, PIC.H), box("InputB", x2, PIC.W, PIC.H), box("Result", x3, PIC.Big, PIC.BigH)
	local signY = PIC.Y - 26 + PIC.BigH - PIC.H / 2 - 14
	line({ Name = "Plus", Text = "+", FontFace = F.Heading, TextSize = 28, TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.fromOffset(x1 + PIC.W, signY), Size = UDim2.fromOffset(PIC.Sign, 28), ZIndex = 3, Parent = side }, 2)
	line({ Name = "Equals", Text = "=", FontFace = F.Heading, TextSize = 28, TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.fromOffset(x2 + PIC.W, signY), Size = UDim2.fromOffset(PIC.Sign, 28), ZIndex = 3, Parent = side }, 2)
	local resultName = line({ Name = "ResultName", Text = "", FontFace = F.Heading, TextSize = 22, TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.fromOffset(0, PIC.Y - 26 + PIC.BigH + 10), Size = UDim2.fromOffset(SIDE.W, 28), ZIndex = 3, Parent = side }, 2)
	-- which grade to combine
	local chipY = PIC.Y - 26 + PIC.BigH + 46
	local chipW = math.floor((SIDE.W - 24 - 2 * 8) / 3)
	local chips = {}
	for i, g in STEPS do
		local b = Kit.button({ Name = "Grade" .. g, Text = string.upper(g), Style = "Tab", FontFace = F.Button, TextSize = 13, Corner = 6, RimThickness = 1.5, Position = UDim2.fromOffset(12 + (i - 1) * (chipW + 8), chipY), Size = UDim2.fromOffset(chipW, 30), ZIndex = 4, Parent = side })
		chips[g] = b
	end
	local reason = line({ Name = "Reason", Text = "", FontFace = F.Body, TextSize = 14, TextColor3 = C.NoteText, TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.fromOffset(0, chipY + 38), Size = UDim2.fromOffset(SIDE.W, 20), ZIndex = 3, Parent = side }, 1)
	local combine = Kit.button({ Name = "CombineButton", Text = "COMBINE", Style = "Disabled", FontFace = F.Button, TextSize = 18, Corner = 7, RimThickness = 2, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -12), Size = UDim2.fromOffset(200, 44), ZIndex = 4, Parent = side })

	-- the reveal over the game ("GOLD YUI!") and the tap-to-skip catcher (outside the window: the window is closed)
	local reveal = new("Frame", { Name = "CombineReveal", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0.14), Size = UDim2.fromOffset(520, 96), BackgroundTransparency = 1, Visible = false, ZIndex = 40, Parent = parent })
	local revealTitle = line({ Name = "Title", Text = "", FontFace = F.Big, TextSize = 44, TextScaled = true, TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.new(1, 0, 0, 58), ZIndex = 41, Parent = reveal }, 3)
	new("UITextSizeConstraint", { Name = "Fit", MaxTextSize = 44, MinTextSize = 20, Parent = revealTitle })
	local revealLine = line({ Name = "Line", Text = "", FontFace = F.Name, TextSize = 18, TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.fromOffset(0, 62), Size = UDim2.new(1, 0, 0, 24), ZIndex = 41, Parent = reveal }, 1.6)
	local skip = new("TextButton", { Name = "CombineSkip", Text = "", AutoButtonColor = false, BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Visible = false, ZIndex = 39, Selectable = false, Parent = parent })
	local skipHint = line({ Name = "Hint", Text = "TAP TO SKIP", FontFace = F.Name, TextSize = 14, TextColor3 = C.SubText, TextXAlignment = Enum.TextXAlignment.Center, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -24), Size = UDim2.fromOffset(200, 20), Visible = false, ZIndex = 41, Parent = skip }, 1.2)

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
		if not key then return end
		local vp = GirlPicture.draw(holder, key, true, true, grade)
		if vp then
			vp.ZIndex = 3
			vp.Parent = holder
		end
		if CombineRules.label(grade) ~= "" then
			Kit.badge({ Name = "GradeBadge", Text = CombineRules.label(grade), Color = gradeColor(grade), TextColor = C.Frame, Height = 20, TextSize = 12, MinTextSize = 9, MaxWidth = holder.Size.X.Offset - 8, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -4), ZIndex = 5, Parent = holder })
		end
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
				local row = new("TextButton", { Name = "Girl_" .. c.id, Text = "", AutoButtonColor = false, Size = UDim2.new(1, 0, 0, LIST.Row), BackgroundColor3 = C.Row, BackgroundTransparency = Theme.Transparency.Row, BorderSizePixel = 0, ZIndex = 3, Parent = list }, { Kit.corner(7) })
				local rim = Kit.stroke(C.RowBorder, 2)
				rim.Parent = row
				local name = line({ Name = "GirlName", Text = c.name, FontFace = F.Name, TextSize = 15, Position = UDim2.fromOffset(10, 6), Size = UDim2.fromOffset(LIST.W - 90, 20), ZIndex = 4, Parent = row })
				local counts = line({ Name = "Copies", Text = "", FontFace = F.Body, TextSize = 12, TextColor3 = C.SubText, Position = UDim2.fromOffset(10, 27), Size = UDim2.fromOffset(LIST.W - 24, 16), ZIndex = 4, Parent = row }, 1)
				local ready = Kit.badge({ Name = "Ready", Text = "READY", Color = C.Accent, TextColor = C.Frame, Height = 18, TextSize = 11, MinTextSize = 9, MaxWidth = 60, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -8, 0, 6), ZIndex = 4, Parent = row })
				r = { row = row, rim = rim, name = name, counts = counts, ready = ready }
				rows[c.id] = r
				local id = c.id
				row.MouseButton1Click:Connect(function()
					if busy then return end
					choose(id, nil)
				end)
			end
			r.row.LayoutOrder = i
			r.row.Visible = true
			Kit.fitLine(r.name, LIST.W - 90, 15, 11, true)
			r.counts.Text = countsLine(c.counts)
			r.ready.Visible = c.ready ~= nil
			local on = c.id == picked
			r.rim.Color = if on then C.Accent else C.RowBorder
			r.rim.Thickness = if on then 3 else 2
		end
		for id, r in rows do
			if not seen[id] then r.row.Visible = false end
		end
		-- the merge side
		local c = picked and byId[picked]
		if not c then
			picture(inA, "a", nil, nil); picture(inB, "b", nil, nil); picture(out, "r", nil, nil)
			resultName.Text = ""
			reason.Text = "No girls yet."
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
			b.setText(`{string.upper(g)} x{c.counts[g] or 0}`)
			b.setStyle(if g == grade then "Action" else "Tab")
			b.setEnabled(not busy)
		end
		local up = CombineRules.next(grade)
		picture(inA, "a", c.model, grade)
		picture(inB, "b", c.model, grade)
		picture(out, "r", c.model, up)
		resultName.Text = if up then title(c.name, up) else title(c.name, grade)
		resultName.TextColor3 = if up then gradeColor(up) else C.Text
		Kit.fitLine(resultName, SIDE.W - 20, 22, 14, true)
		local ok, why = CombineRules.can(State.data, c.id, grade)
		if busy then
			reason.Text = "Combining..."
			combine.setText("..."); combine.setStyle("Disabled"); combine.setEnabled(false)
		elseif ok then
			reason.Text = `2 {grade} {c.name} make 1 {up} {c.name}.`
			combine.setText("COMBINE"); combine.setStyle("Selected"); combine.setEnabled(true)
		else
			reason.Text = why or ""
			combine.setText("COMBINE"); combine.setStyle("Disabled"); combine.setEnabled(false)
		end
		Kit.fitLine(reason, SIDE.W - 20, 14, 10, true)
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
		local function done()
			if finished then return end
			finished = true
			busy = false
			task.delay(1.2, function()
				hideReveal()
				-- back to the window on her (unless something else opened meanwhile)
				if ModalManager.current() == nil then
					picked, pickedGrade = id, nil
					ModalManager.open("Combine", id)
				end
			end)
			skip.Visible = false
			skipHint.Visible = false
			refresh()
		end
		local playing = CombineMachine.play({
			key = c.Model, from = grade, to = up, mine = true,
			onReveal = function()
				revealTitle.Text = title(c.Name, up) .. "!"
				revealTitle.TextColor3 = gradeColor(up)
				revealLine.Text = "Two became one!"
				reveal.Visible = true
				Motion.pop(reveal)
			end,
			onDone = function() done() end,
		})
		if playing then
			skip.Visible = true
			task.delay(0.6, function() if not finished and skip.Visible then skipHint.Visible = true end end)
		end
		task.spawn(function()
			local ok, info = State.action("Combine", id, grade)
			if playing then CombineMachine.answer(ok) end
			if not ok then
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
