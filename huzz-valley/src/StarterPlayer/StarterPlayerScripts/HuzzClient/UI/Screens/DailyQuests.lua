-- Daily quests window (owner, Oct 19, his picture design/owner-oct19/pic-d-quests.png: "add easy quests as in this
-- photo and make new ones everyday then recycle them"). The picture's layout in our kit's look: QUESTS, "RESETS IN
-- 9h 28m" (a real countdown to 00:00 UTC), the line under it, then three rows: each quest's name, its reward at the
-- top right, "0 / 2" and a bar, and a button (IN PROGRESS grey, CLAIM green, CLAIMED dim); the first row is the
-- 2-hour spin quest with "NEW IN 1h 28m" (as in his picture), then the two daily quests. Footer: "Daily quests reset at 00:00 UTC." The picture's Robux "Refresh"
-- and "Auto Complete" buttons are left out (kid-safe: no paying to skip); STORY QUESTS opens the story chapters.
-- Which quests and their progress: Shared/DailyRules.view(State.data.Daily, server time), the same rules the server
-- checks a claim with (ActionService "ClaimDaily"). Accent colours: green and the Spin wheel's purple, no gold.
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local DailyRules = require(Shared.DailyRules)
local Report = require(script.Parent.Parent.Report)
local DailyQuests = require(Shared.Config.DailyQuests)
local UI = script.Parent.Parent
local Theme = require(UI.Theme)
local Kit = require(UI.Kit)
local State = require(UI.State)
local Toast = require(UI.Toast)
local ModalManager = require(UI.ModalManager)
local Motion = require(UI.Motion)

local new = Kit.new
local C, F = Theme.Colors, Theme.Fonts
local REWARD = Color3.fromHex("C3A6FF") -- the picture's purple reward words (lighter for our navy rows)
local NEW_IN = Color3.fromHex("B57BFF")

local DailyQuestsScreen = {}

local W, H = 520, 452
local ROW = { X = 16, Y = 110, W = 520 - 32, H = 88, Gap = 8 }
local ICON = { Coins = "CurrencyCoin", Aura = "AuraStar", Spin = "SpinWheel" }

local function now(): number
	local ok, t = pcall(function() return workspace:GetServerTimeNow() end)
	return if ok and type(t) == "number" then t else os.time()
end

local function line(props: { [string]: any }, stroke: number?): TextLabel
	props.TextWrapped = false
	local l = Kit.text(props)
	new("UIStroke", { Name = "Outline", Color = C.TitleStroke, Thickness = stroke or 1.5, LineJoinMode = Enum.LineJoinMode.Round, Parent = l })
	return l
end

function DailyQuestsScreen.build(parent: Instance)
	local window = Kit.window({ Name = "DailyQuests", Title = "QUESTS", Icon = "QuestsClipboard", Width = W, Height = H, TitleX = 56, TitleWidth = 104, Parent = parent, OnClose = function() ModalManager.close() end })
	local panel = window.Panel
	local resets = line({ Name = "Resets", Text = "", FontFace = F.Heading, TextSize = 18, TextColor3 = C.Accent, Position = UDim2.fromOffset(ROW.X + 2, 56), Size = UDim2.fromOffset(ROW.W, 24), ZIndex = 3, Parent = panel }, 1.6)
	line({ Name = "About", Text = "Two daily quests, plus a spin quest that changes every 2 hours.", FontFace = F.Body, TextSize = 14, TextColor3 = C.NoteText, Position = UDim2.fromOffset(ROW.X + 2, 80), Size = UDim2.fromOffset(ROW.W, 20), ZIndex = 3, Parent = panel }, 1)

	local rows = {}
	for i = 1, #DailyRules.Keys do
		local y = ROW.Y + (i - 1) * (ROW.H + ROW.Gap)
		local row = new("Frame", { Name = "Quest" .. i, Position = UDim2.fromOffset(ROW.X, y), Size = UDim2.fromOffset(ROW.W, ROW.H), BackgroundColor3 = C.Row, BackgroundTransparency = Theme.Transparency.Row, BorderSizePixel = 0, ZIndex = 2, Parent = panel }, { Kit.corner(7), Kit.stroke(C.RowBorder, 2) })
		local name = line({ Name = "QuestName", Text = "", FontFace = F.Name, TextSize = 17, Position = UDim2.fromOffset(14, 10), Size = UDim2.fromOffset(300, 22), ZIndex = 3, Parent = row })
		local rewardIcon = Kit.icon("CurrencyCoin", { Name = "RewardIcon", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -116, 0, 21), Size = UDim2.fromOffset(22, 22), ZIndex = 3, Parent = row })
		local reward = line({ Name = "Reward", Text = "", FontFace = F.Heading, TextSize = 16, TextColor3 = REWARD, TextXAlignment = Enum.TextXAlignment.Right, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -14, 0, 10), Size = UDim2.fromOffset(100, 22), ZIndex = 3, Parent = row })
		local count = line({ Name = "Count", Text = "", FontFace = F.Number, TextSize = 15, TextColor3 = C.SubText, Position = UDim2.fromOffset(14, 38), Size = UDim2.fromOffset(110, 20), ZIndex = 3, Parent = row }, 1)
		local newIn = line({ Name = "NewIn", Text = "", FontFace = F.Heading, TextSize = 14, TextColor3 = NEW_IN, TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.fromOffset(120, 38), Size = UDim2.fromOffset(190, 20), ZIndex = 3, Visible = false, Parent = row }, 1.2)
		local track = new("Frame", { Name = "Track", Position = UDim2.fromOffset(14, 64), Size = UDim2.fromOffset(ROW.W - 14 - 176, 9), BackgroundColor3 = C.TrackRim, BorderSizePixel = 0, ZIndex = 3, Parent = row }, { Kit.corner(5), Kit.stroke(C.RowBorder, 1) })
		local fill = new("Frame", { Name = "Fill", Size = UDim2.fromScale(0, 1), BackgroundColor3 = C.Accent, BorderSizePixel = 0, ZIndex = 4, Parent = track }, { Kit.corner(5) })
		local button = Kit.button({ Name = "Claim", Text = "IN PROGRESS", Style = "Slate", FontFace = F.Button, TextSize = 15, Corner = 7, RimThickness = 2, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -12, 0, 38), Size = UDim2.fromOffset(150, 40), ZIndex = 4, Parent = row })
		rows[i] = { row = row, name = name, reward = reward, rewardIcon = rewardIcon, count = count, newIn = newIn, fill = fill, button = button, key = DailyRules.Keys[i] }
	end
	line({ Name = "Footer", Text = "Daily quests reset at 00:00 UTC.", FontFace = F.Body, TextSize = 13, TextColor3 = C.NoteText, Position = UDim2.fromOffset(ROW.X + 2, H - 38), Size = UDim2.fromOffset(300, 20), ZIndex = 3, Parent = panel }, 1)
	local story = Kit.button({ Name = "Story", Text = "STORY QUESTS", Style = "Tab", FontFace = F.Button, TextSize = 13, Corner = 6, RimThickness = 1.5, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -ROW.X, 1, -44), Size = UDim2.fromOffset(136, 30), ZIndex = 3, Parent = panel })
	story.onClick(function() ModalManager.open("Progression", "Quests") end)

	local pending: { [string]: boolean } = {} -- (a claim on its way: the button waits)
	local function refresh()
		local t = now()
		resets.Text = "RESETS IN " .. DailyRules.clock(DailyRules.resetIn(t))
		for i, v in DailyRules.view(State.data.Daily, t) do
			local r = rows[i]
			if not r then continue end
			local q = v.quest
			r.name.Text = q.Name
			Kit.fitLine(r.name, 300, 17, 12, true)
			r.reward.Text = DailyQuests.rewardText(q.Reward)
			Kit.setIcon(r.rewardIcon, ICON[q.Reward.Kind] or "CurrencyCoin")
			r.rewardIcon.Position = UDim2.new(1, -14 - math.ceil(Kit.textWidth(r.reward.Text, F.Heading, 16)) - 4, 0, 21)
			r.count.Text = `{v.have} / {q.Target}`
			r.fill.Size = UDim2.fromScale(math.clamp(v.have / q.Target, 0, 1), 1)
			r.newIn.Visible = v.key == "S"
			if v.key == "S" then r.newIn.Text = "NEW IN " .. DailyRules.clock(DailyRules.slotIn(t)) end
			local ready = v.have >= q.Target
			if v.done then
				r.button.setText("CLAIMED"); r.button.setStyle("Disabled"); r.button.setEnabled(false)
			elseif pending[v.key] then
				r.button.setText("..."); r.button.setStyle("Selected"); r.button.setEnabled(false)
			elseif ready then
				r.button.setText("CLAIM"); r.button.setStyle("Selected"); r.button.setEnabled(true)
			else
				r.button.setText("IN PROGRESS"); r.button.setStyle("Slate"); r.button.setEnabled(false)
			end
		end
	end
	for _, r in rows do
		r.button.onClick(function()
			if pending[r.key] then return end
			local v = DailyRules.view(State.data.Daily, now())
			local mine
			for _, x in v do if x.key == r.key then mine = x end end
			if not mine or mine.done or mine.have < mine.quest.Target then return end
			pending[r.key] = true
			refresh()
			task.spawn(function()
				local ok, why = State.action("ClaimDaily", r.key)
				pending[r.key] = nil
				if ok then
					Toast.show(DailyQuests.rewardText(mine.quest.Reward) .. "!")
					Motion.pop(r.row)
				else
					Toast.show(why or "Couldn't claim that. Try again.")
				end
				refresh()
			end)
		end)
	end

	local open = false
	ModalManager.register("DailyQuests", {
		window = window,
		onOpen = function()
			open = true
			refresh()
			task.spawn(function()
				while open do
					task.wait(1)
					if open then Report.tick("DailyQuests", refresh) end
				end
			end)
		end,
		onClose = function() open = false end,
		firstSelect = function() return rows[1].button.Instance end,
	})
	State.changed(function() if open then refresh() end end)
	refresh()
	return window.Holder
end

return DailyQuestsScreen
