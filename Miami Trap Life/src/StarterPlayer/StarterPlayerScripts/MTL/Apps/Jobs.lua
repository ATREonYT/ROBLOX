--!strict
-- Jobs app (Piece 2). Three blocks, top to bottom:
--   1. YOUR JOB   what you do, where, this shift's progress, one big button that's always the right next step
--                 (Route to work -> Clock in -> End shift)
--   2. 2x XP      pass / 30-minute boost (kid-safe: Roblox's own prompt shows the price, no timers, "Coming soon"
--                 while the ids are 0, a clear "owned" state). Shown from stage TheCall on, never on a first join.
--   3. FIND WORK  every job you can see at this story stage: pay per minute, XP per minute, how hands-on it is,
--                 distance, CHOOSE / Route. Locked jobs show the level they open at.
-- Story funnel screens (Piece 4), nothing else on screen while they're up:
--   ChooseJob  (stage 10) "STEP 1 OF 2 · Pick your job": 3 big cards (the Food Mart you robbed, the mechanic, the
--              restaurant): photo slot, one story line, pay/min, how hands-on, distance from home, one CHOOSE button.
--              CHOOSE -> a confirm screen ("Work at Westside Auto Repair?") -> chooseJob{job}.
--   FirstNight (stage 11) "You're hired" + "STEP 2 OF 2 · Get some sleep" + one button that puts the phone away.
-- Before ChooseJob the only job listed is the Food Mart (the story job).
-- Buttons: PhoneAction chooseJob{job} / gpsRoute{place} / buy{item}; JobAction clockIn / clockOut.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Jobs = require(ReplicatedStorage.MTL.Config.Jobs)
local Locations = require(ReplicatedStorage.MTL.Config.Locations)
local Property = require(ReplicatedStorage.MTL.Config.Property)
local Story = require(ReplicatedStorage.MTL.Config.Story)
local UserInputService = game:GetService("UserInputService")
local JobRules = require(ReplicatedStorage.MTL.Rules.JobRules)
local StoryRules = require(ReplicatedStorage.MTL.Rules.StoryRules)
local Motion = require(ReplicatedStorage.MTL.UI.Motion)

local App = { id = "Jobs", title = "Jobs" }

local player = Players.LocalPlayer

local function jobController(): any?
	local controllers = script.Parent.Parent:FindFirstChild("Controllers")
	local m = controllers and controllers:FindFirstChild("JobController")
	if not m then
		return nil
	end
	local ok, jc = pcall(require, m)
	return if ok then jc else nil
end

local function myRoot(): BasePart?
	local char = player.Character
	return char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
end

-- Where distances are measured from: you, or your front door while you're inside your home (rooms are far away).
local function origin(): Vector3?
	local homeId = player:GetAttribute("MTL_InHome")
	local h = type(homeId) == "string" and (Property.Homes :: any)[homeId]
	local loc = h and (Locations :: any)[h.location]
	if loc and loc.Door then
		return loc.Door
	end
	local r = myRoot()
	return r and r.Position
end

local function homeDoor(): Vector3?
	local h = (Property.Homes :: any)[Property.StarterHome]
	local loc = h and (Locations :: any)[h.location]
	return loc and loc.Door
end

local function distance(jobId: string, js: any): number?
	local from = origin()
	if not from then
		return nil
	end
	-- the server's site position is the truth (it may come from the map's JobSpot); config is the fallback
	local pos: Vector3? = nil
	if js and js.job == jobId and js.site then
		pos = js.site.pos
	else
		local def = Jobs.Defs[jobId]
		local loc = def and Locations[def.site] :: any
		pos = loc and (loc.Inside or loc.Door)
	end
	return if pos then (from - pos).Magnitude else nil
end

local function sitePos(jobId: string): Vector3?
	local def = Jobs.Defs[jobId]
	local loc = def and Locations[def.site] :: any
	return loc and (loc.Door or loc.Inside)
end

local function keyHint(): string
	if UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled then
		return "tap Sleep"
	elseif UserInputService.GamepadEnabled and not UserInputService.KeyboardEnabled then
		return "press X to Sleep"
	end
	return "press E to Sleep"
end

---------------------------------------------------------------- story funnel screens (Piece 4)

-- street look: one neutral band for every job until Alex's job photos (no per-job rainbow)
local JOB_COLORS = {
	Supermarket = Color3.fromRGB(38, 38, 42),
	Mechanic = Color3.fromRGB(38, 38, 42),
	Restaurant = Color3.fromRGB(38, 38, 42),
}

local function step(ctx: any, parent: Instance, text: string, order: number)
	ctx.UIKit.label(parent, text, { size = 11, bold = true, color = ctx.Theme.Colors.Gold, order = order, name = "Step" })
end

-- STEP 1 OF 2: three big cards, one CHOOSE each. `ctx.pick` = the job waiting for "Yes, I'll take it".
local function renderChoose(ctx: any, d: any, js: any, rerender: () -> ())
	ctx.clear()
	local UIKit, Theme, Format = ctx.UIKit, ctx.Theme, ctx.Format
	local C = Theme.Colors
	local level = d.Level or 1
	local pick = ctx.pick
	if pick and Jobs.Defs[pick] then
		-- confirm
		local def = Jobs.Defs[pick]
		UIKit.header(ctx.frame, "Jobs", function()
			ctx.pick = nil
			rerender()
		end)
		local list = UIKit.scroll(ctx.frame, 44, "Confirm")
		step(ctx, list, "STEP 1 OF 2  ·  PICK YOUR JOB", 1)
		UIKit.label(list, "Work at " .. def.title .. "?", { size = 20, bold = true, wrap = true, order = 2, name = "Question" })
		local card = UIKit.card(list, 3, "ConfirmCard")
		UIKit.stroke(0, C.Accent).Parent = card
		UIKit.label(card, def.role, { size = 17, bold = true, order = 1, name = "Role" })
		UIKit.label(card, def.blurb or "", { size = 13, dim = true, wrap = true, order = 2 })
		local cash, xp = JobRules.perMinute(pick, level)
		UIKit.label(card, string.format("~%s/min  ·  ~%d XP/min", Format.cash(cash), xp), { size = 13, color = C.Money or C.Accent, order = 3 })
		local boss = def.boss and Story.Contacts[def.boss]
		UIKit.label(card, "First shift: tomorrow morning." .. (if boss then (" Your boss: " .. boss.Name .. ".") else ""), { size = 13, wrap = true, order = 4 })
		local waiting = ctx.sent == pick
		local yes = UIKit.button(list, if waiting then "Signing you up..." else "Yes, I'll take it", {
			style = "primary",
			name = "Confirm",
			order = 5,
			height = 48,
			disabled = waiting,
			onClick = function()
				ctx.sent = pick
				ctx.action("chooseJob", { job = pick })
				rerender()
				task.delay(4, function()
					if ctx.sent == pick and ctx.frame.Parent then
						ctx.sent = nil -- the server said no (a toast explains); let them try again
						rerender()
					end
				end)
			end,
		})
		yes.Name = "Confirm"
		UIKit.button(list, "Back", {
			style = "secondary",
			name = "Back",
			order = 6,
			onClick = function()
				ctx.pick = nil
				ctx.sent = nil
				rerender()
			end,
		})
		UIKit.label(list, "You can switch jobs any time in this app.", { size = 12, dim = true, wrap = true, order = 7 })
		return
	end

	UIKit.header(ctx.frame, "Jobs")
	local list = UIKit.scroll(ctx.frame, 44, "Choose")
	step(ctx, list, "STEP 1 OF 2  ·  PICK YOUR JOB", 1)
	UIKit.label(list, "Pick your job", { size = 22, bold = true, order = 2, name = "Title" })
	UIKit.label(list, "Three places are hiring. You start tomorrow morning.", { size = 13, dim = true, wrap = true, order = 3 })
	local home = homeDoor()
	local cards = {}
	for i, id in Jobs.StarterJobs do
		local def = Jobs.Defs[id]
		if not def then
			continue
		end
		local card = UIKit.card(list, 10 + i, "Job_" .. id)
		-- photo band. TODO(Alex art): a job photo (ImageLabel "Photo"); until then a coloured band + the role
		local band = UIKit.new("Frame", {
			Name = "Band",
			LayoutOrder = 0,
			Size = UDim2.new(1, 0, 0, 56),
			BackgroundColor3 = JOB_COLORS[id] or C.Accent,
			ClipsDescendants = true,
			Parent = card,
		}, { UIKit.corner(Theme.CornerSmall) })
		UIKit.new("ImageLabel", { Name = "Photo", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Image = "rbxassetid://0", ScaleType = Enum.ScaleType.Crop, Parent = band })
		UIKit.new("TextLabel", {
			Name = "BandText",
			Position = UDim2.fromOffset(12, 0),
			Size = UDim2.new(1, -24, 1, 0),
			BackgroundTransparency = 1,
			FontFace = Theme.Fonts.Display,
			Text = string.upper(def.role),
			TextColor3 = C.Text,
			TextSize = 22,
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = band,
		})
		UIKit.label(card, def.title, { size = 16, bold = true, name = "Place", order = 1 })
		local hook = (Property.JobHooks :: any)[id]
		if hook then
			UIKit.label(card, hook, { size = 12, wrap = true, name = "Hook", order = 2 })
		end
		local cash = JobRules.perMinute(id, level)
		local site = sitePos(id)
		local distText = if home and site then ("  ·  " .. Format.distance((home - site).Magnitude) .. " from home") else ""
		UIKit.label(card, string.format("~%s/min  ·  %s", Format.cash(cash), JobRules.tierLabel(def.tier)) .. distText, { size = 12, color = C.Money or C.Accent, name = "Pay", order = 3 })
		local choose = UIKit.button(card, "CHOOSE", {
			style = "primary",
			name = "Choose",
			order = 10,
			height = 44,
			onClick = function()
				ctx.pick = id
				rerender()
			end,
		})
		choose.Name = "Choose"
		table.insert(cards, card)
	end
	-- the story asks for a choice: pulse the cards once, gently
	if not (d.Settings and d.Settings.ReducedMotion) and not ctx.pulsed then
		ctx.pulsed = true
		for i, card in cards do
			local s = UIKit.new("UIScale", { Parent = card })
			task.delay(0.2 + 0.15 * i, function()
				Motion.tween(s, Motion.Fast, { Scale = 1.03 }).Completed:Wait()
				Motion.tween(s, Motion.Normal, { Scale = 1 })
			end)
		end
	end
end

-- STEP 2 OF 2: hired, now sleep.
local function renderHired(ctx: any, d: any)
	ctx.clear()
	local UIKit, Theme = ctx.UIKit, ctx.Theme
	local C = Theme.Colors
	UIKit.header(ctx.frame, "Jobs")
	local list = UIKit.scroll(ctx.frame, 44, "Hired")
	local def = JobRules.def(d.Job and d.Job.Current or "")
	local badge = UIKit.new("TextLabel", {
		Name = "HiredBadge",
		LayoutOrder = 1,
		Size = UDim2.new(1, 0, 0, 64),
		BackgroundColor3 = C.Accent,
		FontFace = Theme.Fonts.Display,
		Text = "YOU'RE HIRED",
		TextColor3 = C.Text,
		TextSize = 24,
		Parent = list,
	}, { UIKit.corner(Theme.Corner) })
	badge.Name = "HiredBadge"
	if def then
		UIKit.label(list, def.role .. " at " .. def.title, { size = 17, bold = true, wrap = true, order = 2, name = "Job" })
		local boss = def.boss and Story.Contacts[def.boss]
		UIKit.label(list, "First shift: tomorrow morning." .. (if boss then (" " .. boss.Name .. " will text you when you wake up.") else ""), { size = 13, dim = true, wrap = true, order = 3 })
	end
	step(ctx, list, "STEP 2 OF 2  ·  GET SOME SLEEP", 4)
	UIKit.label(list, "Your bed is glowing. Walk over and " .. keyHint() .. ".", { size = 15, wrap = true, order = 5, name = "Next" })
	UIKit.button(list, "Put the phone away", {
		style = "primary",
		name = "Close",
		order = 6,
		height = 46,
		onClick = function()
			ctx.close()
		end,
	})
end

local function buttonRow(UIKit: any, parent: Instance, order: number): Frame
	return UIKit.new("Frame", {
		Name = "Buttons",
		LayoutOrder = order,
		Size = UDim2.new(1, 0, 0, 40),
		BackgroundTransparency = 1,
		Parent = parent,
	}, { UIKit.list(8, true) })
end

local function render(ctx: any, d: any, js: any)
	-- story funnel screens (Piece 4) take the whole app
	if d.Story.Stage == Jobs.ChooseFromStage then
		renderChoose(ctx, d, js, function()
			render(ctx, ctx.data() or d, js)
		end)
		return
	elseif d.Story.Stage == "FirstNight" then
		renderHired(ctx, d)
		return
	end
	ctx.clear()
	local UIKit, Theme, Format = ctx.UIKit, ctx.Theme, ctx.Format
	local C = Theme.Colors
	UIKit.header(ctx.frame, "Jobs")
	local list = UIKit.scroll(ctx.frame, 44, "Jobs")
	local stage = d.Story.Stage
	local level = d.Level or 1
	local current = d.Job and d.Job.Current or ""
	local choosing = stage == Jobs.ChooseFromStage
	local order = 0
	local function nextOrder(): number
		order += 1
		return order
	end
	local function jc(kind: string)
		local controller = jobController()
		if controller then
			controller.action(kind)
		end
	end

	---------------------------------------------------------------- 1. your job
	local mine = JobRules.def(current)
	if mine and not choosing then
		UIKit.section(list, "YOUR JOB", nextOrder())
		local card = UIKit.card(list, nextOrder(), "MyJob")
		UIKit.stroke(0, C.Accent).Parent = card
		-- TODO(Alex art): job photo / logo at the top of the card
		UIKit.label(card, mine.role, { size = 17, bold = true, name = "Role", order = 1 })
		UIKit.label(card, mine.title, { dim = true, name = "Place", order = 2 })
		local onShift = js ~= nil and js.onShift == true and js.job == current
		local dist = distance(current, js)
		local statusText
		if onShift and js.shift then
			statusText = if js.shift.complete then "Shift complete"
				else string.format("On shift  ·  %d / %d  ·  %s", js.shift.done, js.shift.total, Format.cash(js.shift.earned))
		else
			statusText = "Off the clock" .. (if dist then ("  ·  " .. Format.distance(dist) .. " away") else "")
		end
		UIKit.label(card, statusText, { size = 12, color = if onShift then C.Accent else C.TextDim, name = "Status", order = 3 })
		local storyShift = stage == "FirstShift"
		if storyShift then
			UIKit.label(card, "Mr. Patel's counting on you. Keep working your shift.", { size = 12, dim = true, wrap = true, order = 4 })
		end
		local buttons = buttonRow(UIKit, card, 10)
		local nearWork = (dist or math.huge) <= Jobs.Validation.ClockInRadius
		local primaryText: string, style: string, onClick: () -> ()
		if onShift then
			primaryText, style, onClick = "End shift", "secondary", function()
				jc("clockOut")
			end
		elseif nearWork then
			primaryText, style, onClick = "Clock in", "primary", function()
				jc("clockIn")
				ctx.close()
			end
		else
			primaryText, style, onClick = "Route to work", "primary", function()
				ctx.action("gpsRoute", { place = mine.place })
				ctx.close()
			end
		end
		local primary = UIKit.button(buttons, primaryText, { style = style, name = "Primary", onClick = onClick })
		primary.Size = UDim2.new(1, 0, 1, 0)
		buttons.Visible = not (storyShift and onShift) -- the story shift: nothing to press, just work
	end

	---------------------------------------------------------------- 2. 2x XP
	if StoryRules.reached(stage, "TheCall") then
		UIKit.section(list, "LEVEL UP FASTER", nextOrder())
		local card = UIKit.card(list, nextOrder(), "Boost")
		local ownsPass = player:GetAttribute("MTL_Pass_XP2x") == true
		local boostLeft = (d.Boosts and d.Boosts.XP2xSeconds) or 0
		if ownsPass then
			UIKit.label(card, "2x XP pass: owned", { bold = true, color = C.Accent, order = 1 })
			UIKit.label(card, "Every job gives double XP. Forever.", { size = 12, dim = true, wrap = true, order = 2 })
		else
			UIKit.label(card, "2x XP", { size = 17, bold = true, order = 1 })
			UIKit.label(card, "Double XP on every job. The pass is forever. The boost is 30 minutes of play time and stacks.", { size = 12, dim = true, wrap = true, order = 2 })
		end
		if boostLeft > 0 then
			UIKit.label(card, string.format("Boost on: %d min of play time left", math.ceil(boostLeft / 60)), { size = 12, color = C.AccentAlt, order = 3 })
		end
		local buttons = buttonRow(UIKit, card, 10)
		if not ownsPass then
			local pass = UIKit.button(buttons, "2x XP forever", {
				style = "primary",
				name = "BuyPass",
				onClick = function()
					ctx.action("buy", { item = "XP2x" })
				end,
			})
			pass.Size = UDim2.new(0.5, -4, 1, 0)
		end
		local boost = UIKit.button(buttons, "30 min boost", {
			style = "secondary",
			name = "BuyBoost",
			onClick = function()
				ctx.action("buy", { item = "XPBoost" })
			end,
		})
		boost.Size = if ownsPass then UDim2.new(1, 0, 1, 0) else UDim2.new(0.5, -4, 1, 0)
	end

	---------------------------------------------------------------- 3. find work
	local visible = JobRules.visibleJobs(stage)
	UIKit.section(list, if choosing then "PICK YOUR JOB" elseif #visible == 1 then "HIRING" else "FIND WORK", nextOrder())
	if choosing then
		UIKit.label(list, "Pick where you work. You can switch later in this app.", { wrap = true, order = nextOrder(), dim = true })
	elseif not StoryRules.reached(stage, Jobs.ChooseFromStage) then
		UIKit.label(list, "More jobs open up once you've got your own place.", { wrap = true, order = nextOrder(), dim = true, size = 12 })
	end
	local cards = {}
	local tier = 1
	for _, id in visible do
		local def = Jobs.Defs[id]
		local isMine = id == current
		if isMine and not choosing then
			continue -- already shown in YOUR JOB
		end
		if not choosing and def.tier ~= tier then
			tier = def.tier
			UIKit.label(list, if tier == 2 then "LEVEL 8+  ·  LAID BACK" else "LEVEL 15+  ·  AFK-FRIENDLY", { size = 11, bold = true, dim = true, order = nextOrder() })
		end
		local locked = level < def.level
		local card = UIKit.card(list, nextOrder(), "Job_" .. id)
		if isMine then
			UIKit.stroke(0, C.Accent).Parent = card
		end
		-- TODO(Alex art): job photo at the top of the card
		UIKit.label(card, def.role .. "  ·  " .. def.title, { size = 15, bold = true, name = "Title", order = 1 })
		UIKit.label(card, def.blurb or "", { size = 12, dim = true, wrap = true, name = "Blurb", order = 2 })
		local cash, xp = JobRules.perMinute(id, level)
		local info = string.format("~%s/min  ·  ~%d XP/min  ·  %s", Format.cash(cash), xp, JobRules.tierLabel(def.tier))
		UIKit.label(card, info, { size = 12, color = if locked then C.TextDim else (C.Money or C.Accent), name = "Pay", order = 3 })
		local dist = distance(id, js)
		if dist then
			UIKit.label(card, Format.distance(dist) .. " away", { size = 11, dim = true, name = "Distance", order = 4 })
		end
		local buttons = buttonRow(UIKit, card, 10)
		local canPick = JobRules.canChoose(id, level, stage)
		local chooseText = if isMine then "YOUR JOB" elseif locked then ("LEVEL " .. def.level) elseif not canPick then "SOON" else "CHOOSE"
		local choose = UIKit.button(buttons, chooseText, {
			style = "primary",
			disabled = isMine or locked or not canPick,
			name = "Choose",
			onClick = function()
				ctx.action("chooseJob", { job = id })
			end,
		})
		choose.Size = UDim2.new(0.62, -4, 1, 0)
		local route = UIKit.button(buttons, "Route", {
			style = "secondary",
			name = "Route",
			disabled = def.place == nil,
			onClick = function()
				ctx.action("gpsRoute", { place = def.place })
			end,
		})
		route.Size = UDim2.new(0.38, -4, 1, 0)
		table.insert(cards, card)
	end

	-- the story asks for a choice: pulse the cards once, gently
	if choosing and not (d.Settings and d.Settings.ReducedMotion) then
		for i, card in cards do
			local s = UIKit.new("UIScale", { Parent = card })
			task.delay(0.15 * i, function()
				Motion.tween(s, Motion.Fast, { Scale = 1.03 }).Completed:Wait()
				Motion.tween(s, Motion.Normal, { Scale = 1 })
			end)
		end
	end
end

function App.mount(frame: Frame, ctx: any)
	local lastKey = ""
	local controller = jobController()
	local function refresh()
		local d = ctx.data()
		if not d or not frame.Parent then
			return
		end
		local js = controller and controller.state()
		local shiftKey = if js and js.onShift and js.shift then (tostring(js.shift.done) .. "/" .. tostring(js.shift.complete)) else "off"
		local k = table.concat({
			tostring(d.Story.Stage),
			tostring(d.Level),
			tostring(d.Job and d.Job.Current),
			shiftKey,
			tostring(math.ceil(((d.Boosts and d.Boosts.XP2xSeconds) or 0) / 60)),
			tostring(player:GetAttribute("MTL_Pass_XP2x")),
		}, "|")
		if k ~= lastKey then
			lastKey = k
			render(ctx, d, js)
		end
	end
	ctx.onData(function()
		refresh()
	end)
	if controller and controller.Changed then
		ctx.track(controller.Changed:Connect(refresh))
	end
	ctx.track(player:GetAttributeChangedSignal("MTL_Pass_XP2x"):Connect(refresh))
end

return App
