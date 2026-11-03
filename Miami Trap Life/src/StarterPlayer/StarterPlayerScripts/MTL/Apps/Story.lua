--!strict
-- Story app: where you are in the story. A chapter card on top (chapter number, title, how far through it you
-- are, what to do now + a GPS button when the objective has a place), then the chapter's missions (done / NOW /
-- locked), every chapter, and the cast with their faces (tap someone to open your texts with them).
--
-- Data: the story thread publishes the player attribute MTL_Story as JSON (it owns the content; this app only
-- draws it). Every field is optional:
--   {
--     "chapter": 1, "chapterTitle": "Welcome to Liberty",
--     "chapters": [ { "n": 1, "title": "...", "state": "done" | "active" | "locked" } ],
--     "missions": [ { "id": "...", "title": "...", "state": "done" | "active" | "locked", "giver": "Dre", "blurb": "..." } ],
--     "objective": "Rob Liberty Food Mart"   or   { "text": "...", "place": "FoodMart" }   (place = Config/Phone.Places id)
--     "cast": [ { "id": "Dre", "name": "Dre", "role": "Liberty Lows" } ]   (id = Config/Story.Contacts id, for the face)
--   }
-- Until that attribute exists, the app reads the save's Story.Stage against Config/Story so it still works.
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Story = require(ReplicatedStorage.MTL.Config.Story)
local Avatars = require(ReplicatedStorage.MTL.UI.Avatars)

local App = { id = "Story", title = "Story" }

-- the onboarding stages, as missions, when MTL_Story isn't published yet
local STAGE_TITLES = {
	Arrive = "Arrive in Liberty",
	FirstShift = "First shift at the Food Mart",
	TheCall = "The call",
	GangMeet = "Meet the crew",
	GangIntro = "The Liberty Lows",
	FirstMission = "The Food Mart job",
	MissionDone = "Get paid",
	FindAPlace = "Find a place",
	MoveIn = "Move in",
	ChooseJob = "Pick a job",
	FirstNight = "First night",
	CommuteToWork = "Back to work",
	FreePlay = "Your life now",
}
local NOT_CAST = { You = true, Unknown = true }

local function decode(): any?
	local raw = Players.LocalPlayer:GetAttribute("MTL_Story")
	if type(raw) ~= "string" or raw == "" then
		return nil
	end
	local ok, t = pcall(HttpService.JSONDecode, HttpService, raw)
	return if ok and type(t) == "table" then t else nil
end

-- the same shape as MTL_Story, built from the save when the attribute is missing
local function fallback(d: any): any
	local stage = (d and d.Story and d.Story.Stage) or Story.Stages[1]
	local at = table.find(Story.Stages, stage) or 1
	local missions = {}
	for i, s in Story.Stages do
		table.insert(missions, {
			id = s,
			title = STAGE_TITLES[s] or s,
			state = if i < at then "done" elseif i == at then "active" else "locked",
		})
	end
	local cast = {}
	for _, id in { "Dre", "Smoke", "Nina", "Patel", "Kev", "Rico", "Tasha" } do
		local c = (Story.Contacts :: any)[id]
		if c then
			table.insert(cast, { id = id, name = c.Name, role = c.Subtitle })
		end
	end
	return {
		chapter = 1,
		chapterTitle = "Welcome to Liberty",
		chapters = { { n = 1, title = "Welcome to Liberty", state = if stage == "FreePlay" then "done" else "active" } },
		missions = missions,
		objective = (Story.Objectives :: any)[stage],
		cast = cast,
	}
end

local function render(ctx: any, s: any)
	ctx.clear()
	local UIKit, Theme = ctx.UIKit, ctx.Theme
	local C, P = Theme.Colors, Theme.Phone
	UIKit.header(ctx.frame, "Story")
	local list = UIKit.scroll(ctx.frame, 44, "Chapters")
	local order = 0
	local function nextOrder(): number
		order += 1
		return order
	end
	local missions = if type(s.missions) == "table" then s.missions else {}
	local done, total = 0, 0
	for _, m in missions do
		if type(m) == "table" then
			total += 1
			if m.state == "done" then
				done += 1
			end
		end
	end

	-- the chapter card
	local hero = UIKit.card(list, nextOrder(), "Chapter")
	local tint = (P.AppColors and P.AppColors.Story) or C.Accent
	UIKit.label(hero, "CHAPTER " .. tostring(s.chapter or 1), { size = 11, bold = true, color = tint, name = "Number", order = 1 })
	UIKit.label(hero, tostring(s.chapterTitle or ""), { size = 22, bold = true, wrap = true, name = "Title", order = 2 })
	if total > 0 then
		local bar = UIKit.new("Frame", {
			Name = "Progress",
			LayoutOrder = 3,
			Size = UDim2.new(1, 0, 0, 6),
			BackgroundColor3 = P.CardHover,
			Parent = hero,
		}, { UIKit.corner(UDim.new(1, 0)) })
		UIKit.new("Frame", {
			Name = "Fill",
			Size = UDim2.new(done / total, 0, 1, 0),
			BackgroundColor3 = tint,
			Parent = bar,
		}, { UIKit.corner(UDim.new(1, 0)) })
		UIKit.label(hero, string.format("%d of %d done", done, total), { size = 11, dim = true, name = "Count", order = 4 })
	end
	local obj = s.objective
	local objText = if type(obj) == "table" then obj.text else obj
	local objPlace = if type(obj) == "table" then obj.place else nil
	if type(objText) == "string" and objText ~= "" then
		UIKit.label(hero, "NOW", { size = 11, bold = true, color = C.Accent, name = "NowLabel", order = 5 })
		UIKit.label(hero, objText, { size = 15, bold = true, wrap = true, name = "Objective", order = 6 })
		if type(objPlace) == "string" and objPlace ~= "" then
			UIKit.button(hero, "Set GPS", {
				style = "primary",
				name = "GPS",
				height = 36,
				order = 7,
				onClick = function()
					ctx.sfx("PhoneTap")
					ctx.action("gpsRoute", { place = objPlace })
				end,
			})
		end
	end

	-- missions
	if total > 0 then
		UIKit.section(list, "MISSIONS", nextOrder())
		for _, m in missions do
			if type(m) ~= "table" then
				continue
			end
			local state = m.state or "locked"
			local row = UIKit.card(list, nextOrder(), "Mission_" .. tostring(m.id or order))
			if state == "locked" then
				row.BackgroundTransparency = 0.4
			end
			local line = UIKit.new("Frame", {
				Name = "Line",
				LayoutOrder = 1,
				Size = UDim2.new(1, 0, 0, 22),
				AutomaticSize = Enum.AutomaticSize.Y,
				BackgroundTransparency = 1,
				Parent = row,
			})
			-- status dot: green tick, blue NOW ring, grey lock
			local dot = UIKit.new("Frame", {
				Name = "Dot",
				Position = UDim2.fromOffset(0, 2),
				Size = UDim2.fromOffset(18, 18),
				BackgroundColor3 = if state == "done" then (C.Money or C.Accent) elseif state == "active" then C.Accent else P.CardHover,
				BackgroundTransparency = if state == "active" then 1 else 0,
				Parent = line,
			}, { UIKit.corner(UDim.new(1, 0)) })
			if state == "active" then
				UIKit.stroke(0, C.Accent).Parent = dot
				UIKit.new("Frame", {
					AnchorPoint = Vector2.new(0.5, 0.5),
					Position = UDim2.fromScale(0.5, 0.5),
					Size = UDim2.fromOffset(8, 8),
					BackgroundColor3 = C.Accent,
					Parent = dot,
				}, { UIKit.corner(UDim.new(1, 0)) })
			elseif state == "done" then
				-- a drawn tick (two bars), so it never depends on a font having the glyph
				UIKit.new("Frame", {
					AnchorPoint = Vector2.new(0.5, 0.5),
					Position = UDim2.fromOffset(6.5, 10.5),
					Size = UDim2.fromOffset(6, 2),
					Rotation = 45,
					BackgroundColor3 = Color3.new(1, 1, 1),
					BorderSizePixel = 0,
					Parent = dot,
				})
				UIKit.new("Frame", {
					AnchorPoint = Vector2.new(0.5, 0.5),
					Position = UDim2.fromOffset(11, 8.5),
					Size = UDim2.fromOffset(10, 2),
					Rotation = -50,
					BackgroundColor3 = Color3.new(1, 1, 1),
					BorderSizePixel = 0,
					Parent = dot,
				})
			end
			local title = UIKit.label(line, tostring(m.title or m.id or ""), {
				size = 14,
				bold = state ~= "locked",
				wrap = true,
				color = if state == "locked" then C.TextDim else C.Text,
				name = "Title",
			})
			title.Position = UDim2.fromOffset(28, 0)
			title.Size = UDim2.new(1, if state == "active" then -76 else -28, 0, 0)
			if state == "active" then
				local pill = UIKit.new("TextLabel", {
					Name = "Now",
					AnchorPoint = Vector2.new(1, 0),
					Position = UDim2.new(1, 0, 0, 1),
					Size = UDim2.fromOffset(42, 20),
					BackgroundColor3 = C.Accent,
					FontFace = Theme.Fonts.Bold,
					Text = "NOW",
					TextColor3 = Color3.new(1, 1, 1),
					TextSize = 11,
					Parent = line,
				}, { UIKit.corner(UDim.new(1, 0)) })
				pill.ZIndex = title.ZIndex
			end
			if state ~= "locked" and type(m.blurb) == "string" and m.blurb ~= "" then
				local b = UIKit.label(row, m.blurb, { size = 12, dim = true, wrap = true, name = "Blurb", order = 2 })
				local pad = Instance.new("UIPadding")
				pad.PaddingLeft = UDim.new(0, 28)
				pad.Parent = b
			end
			if state ~= "locked" and type(m.giver) == "string" and (Story.Contacts :: any)[m.giver] then
				local g = UIKit.label(row, "From " .. Avatars.displayName(m.giver), { size = 11, dim = true, name = "Giver", order = 3 })
				local pad = Instance.new("UIPadding")
				pad.PaddingLeft = UDim.new(0, 28)
				pad.Parent = g
			end
		end
	end

	-- chapters (only worth a list once there's more than one)
	local chapters = if type(s.chapters) == "table" then s.chapters else {}
	if #chapters > 1 then
		UIKit.section(list, "CHAPTERS", nextOrder())
		for _, ch in chapters do
			if type(ch) ~= "table" then
				continue
			end
			local locked = ch.state == "locked"
			local card = UIKit.card(list, nextOrder(), "Ch_" .. tostring(ch.n))
			if locked then
				card.BackgroundTransparency = 0.4
			end
			UIKit.label(card, "CHAPTER " .. tostring(ch.n or "") .. (if ch.state == "done" then "  ·  DONE" elseif ch.state == "active" then "  ·  NOW" else ""), {
				size = 10,
				bold = true,
				color = if ch.state == "active" then C.Accent else C.TextDim,
				name = "Num",
				order = 1,
			})
			UIKit.label(card, if locked then "???" else tostring(ch.title or ""), { size = 15, bold = true, color = if locked then C.TextDim else C.Text, name = "Title", order = 2 })
		end
	end

	-- cast
	local cast = if type(s.cast) == "table" then s.cast else {}
	local people = {}
	for _, c in cast do
		if type(c) == "table" and type(c.id) == "string" and not NOT_CAST[c.id] then
			table.insert(people, c)
		end
	end
	if #people > 0 then
		UIKit.section(list, "CAST", nextOrder())
		local grid = UIKit.new("Frame", {
			Name = "Cast",
			LayoutOrder = nextOrder(),
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			Parent = list,
		})
		local layout = Instance.new("UIGridLayout")
		layout.CellSize = UDim2.new(1 / 3, -6, 0, 104)
		layout.CellPadding = UDim2.fromOffset(8, 8)
		layout.SortOrder = Enum.SortOrder.LayoutOrder
		layout.Parent = grid
		for i, c in people do
			local cell = UIKit.new("TextButton", {
				Name = "Person_" .. c.id,
				LayoutOrder = i,
				BackgroundColor3 = P.Card,
				AutoButtonColor = false,
				Text = "",
				Parent = grid,
			}, { UIKit.corner(UDim.new(0, 12)) })
			Avatars.make(cell, c.id, 52, {
				AnchorPoint = Vector2.new(0.5, 0),
				Position = UDim2.new(0.5, 0, 0, 10),
			})
			UIKit.new("TextLabel", {
				Name = "Name",
				Position = UDim2.fromOffset(4, 66),
				Size = UDim2.new(1, -8, 0, 16),
				BackgroundTransparency = 1,
				FontFace = Theme.Fonts.Bold,
				Text = tostring(c.name or Avatars.displayName(c.id)),
				TextColor3 = C.Text,
				TextSize = 13,
				TextTruncate = Enum.TextTruncate.AtEnd,
				Parent = cell,
			})
			UIKit.new("TextLabel", {
				Name = "Role",
				Position = UDim2.fromOffset(4, 82),
				Size = UDim2.new(1, -8, 0, 14),
				BackgroundTransparency = 1,
				FontFace = Theme.Fonts.Body or Theme.Fonts.Bold,
				Text = tostring(c.role or ""),
				TextColor3 = C.TextDim,
				TextSize = 10,
				TextTruncate = Enum.TextTruncate.AtEnd,
				Parent = cell,
			})
			UIKit.feedback(cell, P.Card)
			cell.Activated:Connect(function()
				ctx.sfx("PhoneTap")
				ctx.Phone.open("Messages", { contact = c.id })
			end)
		end
	end
end

function App.mount(frame: Frame, ctx: any)
	local last = ""
	local function refresh()
		if not frame.Parent then
			return
		end
		local d = ctx.data()
		local s = decode() or fallback(d)
		local ok, key = pcall(HttpService.JSONEncode, HttpService, s)
		key = if ok then key else tostring(os.clock())
		if key ~= last then
			last = key
			render(ctx, s)
		end
	end
	ctx.onData(function()
		refresh()
	end)
	ctx.track(Players.LocalPlayer:GetAttributeChangedSignal("MTL_Story"):Connect(refresh))
	refresh()
end

return App
