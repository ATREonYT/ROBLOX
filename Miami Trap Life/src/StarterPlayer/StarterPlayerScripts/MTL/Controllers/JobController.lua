--!strict
-- The job on your screen (Piece 2): the job panel, the marker + glow on the station you need, the prompt there,
-- the minigames, the shift / check-in cards, the PERFECT flourish, reward fly-ups and the level-up ring.
-- Everything it shows comes from the server's JobState; it reports with JobAction and never decides pay.
--   JobController.state() -> last JobState (or nil)      JobController.Changed: Signal(state)
--   JobController.action(type, payload?)                  e.g. JobController.action("clockIn")
-- Funnel (Research "Onboarding Funnels and Wayfinding"): ONE thing to do at a time, always marked in the world
-- (glow + floating marker, breadcrumbs when it's far) and written on the panel, with a coach line the first times.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local GuiService = game:GetService("GuiService")

local Net = require(ReplicatedStorage.MTL.Net)
local Signal = require(ReplicatedStorage.MTL.Signal)
local Theme = require(ReplicatedStorage.MTL.UI.Theme)
local Motion = require(ReplicatedStorage.MTL.UI.Motion)
local Format = require(ReplicatedStorage.MTL.Format)
local Build = require(ReplicatedStorage.MTL.UI.Build.Job)
local UIState = require(script.Parent.UIState)
local Wayfinder = require(script.Parent.WayfindingController)
local JobFX = require(script.Parent.JobFX)
local Juice = require(script.Parent.Juice)
local Minigames = require(script.Parent.JobMinigames)

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera
local C = Theme.Colors
local J = Theme.Job

local JobController = {}
JobController.Changed = Signal.new()

local MARKER_ID = "Job" -- Wayfinder id for the current station
local CLOCK_MARKER_ID = "JobClock"
local SHOW_CLOCK_WITHIN = 140 -- studs from the site: show the "Clock in" marker
local BREADCRUMBS_FROM = 60 -- studs: breadcrumbs on the job marker only when it's this far

local gui: any
local state: any = nil
local stateAt = 0 -- os.clock() when `state` arrived (for countdowns)
local stepKey = "" -- "taskId:step" currently dressed in the world
local stepFx: JobFX.FX? = nil
local cleanupStep: { () -> () } = {}
local postRingOff: (() -> ())? = nil
local postKey = ""
local running: any = nil -- active minigame handle
local anchor: Part
local prompt: ProximityPrompt
local clockAnchor: Part
local clockPrompt: ProximityPrompt
local cardMode = ""
local clockMarker = false -- the "Clock in" Wayfinder marker is up

function JobController.state(): any
	return state
end

function JobController.action(kind: string, payload: { [string]: any }?)
	local p = payload or {}
	p.type = kind
	Net.get("JobAction"):FireServer(p)
end

local function root(): BasePart?
	local char = player.Character
	return char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function flatDist(a: Vector3, b: Vector3): number
	local d = a - b
	return Vector2.new(d.X, d.Z).Magnitude
end

---------------------------------------------------------------- world anchors + prompts (local parts)

local function makeAnchor(name: string): (Part, ProximityPrompt)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch = true, false, false, false
	p.Transparency = 1
	p.Size = Vector3.new(1, 1, 1)
	p.Position = Vector3.new(0, -500, 0)
	p.Parent = workspace
	local pp = Instance.new("ProximityPrompt")
	pp.KeyboardKeyCode = Enum.KeyCode.E
	pp.GamepadKeyCode = Enum.KeyCode.ButtonX
	pp.HoldDuration = 0
	pp.RequiresLineOfSight = false
	pp.Enabled = false
	pp.Parent = p
	return p, pp
end

local function placeAnchor(part: Part, pos: Vector3)
	part.Position = Vector3.new(pos.X, JobFX.floor(pos) + 2.5, pos.Z)
end

---------------------------------------------------------------- panel

local function setVisible(obj: GuiObject, on: boolean)
	if obj.Visible ~= on then
		obj.Visible = on
	end
end

local function render()
	local panel = gui.Panel
	local body = panel.Body
	if not state or not state.job then
		setVisible(panel, false)
		return
	end
	local r = root()
	local nearSite = r ~= nil and flatDist(r.Position, state.site.pos) <= SHOW_CLOCK_WITHIN
	setVisible(panel, (state.onShift or nearSite) and not UIState.get().hideHUD)
	body.JobTitle.Text = string.upper(state.role .. "  ·  " .. state.title)
	local accentColor = if state.onShift then C.Accent else C.TextDim
	local age = os.clock() - stateAt

	local taskText, steps, status, hint = "", "", "", ""
	local statusColor = C.Gold
	local actionText: string? = nil
	if not state.onShift then
		taskText = if nearSite then "Clock in at the time clock" else ("Head to " .. state.title)
		steps = ""
		actionText = if nearSite then "Clock in" else nil
	else
		local shift = state.shift
		if shift.complete then
			taskText = "Shift complete"
		elseif state.task then
			local t = state.task
			taskText = t.text
			steps = if t.steps > 1 then string.format("Step %d of %d", t.step, t.steps) else ""
			hint = t.hint or ""
		elseif state.waiting then
			local left = math.max(0, math.ceil(state.waiting - age))
			taskText = "Waiting for the next customer"
			status = if left > 0 then ("Next one in about " .. left .. "s") else "Any second now..."
			statusColor = C.TextDim
		elseif state.post then
			local p = state.post
			if p.paused then
				taskText = "Radio's buzzing. Check in"
				status = "Pay is paused until you check in"
			elseif p.onPost then
				taskText = "On post. Stay in the zone"
				status = string.format("Paid every %ds  ·  about %s/min", p.payEvery or 30, Format.cash(p.perMinute or 0))
				statusColor = C.Accent
			else
				taskText = "Get back to your post"
				status = "Stand inside the green ring to get paid"
			end
		end
		if state.leaving then
			local left = math.max(0, math.ceil(state.leaving - age))
			status = "You're leaving work! Shift ends in " .. left .. "s"
			statusColor = C.Danger
			accentColor = C.Danger
		end
		body.Progress.Fill.Size = UDim2.fromScale(math.clamp(shift.done / math.max(1, shift.total), 0, 1), 1)
		body.ProgressText.Text = string.format("Shift %d / %d  ·  %s earned", shift.done, shift.total, Format.cash(shift.earned))
		actionText = if state.storyJob then nil else "End shift"
	end
	setVisible(body.Progress, state.onShift == true)
	setVisible(body.ProgressText, state.onShift == true)
	body.Task.Text = taskText
	body.Steps.Text = steps
	setVisible(body.Steps, steps ~= "")
	body.Status.Text = status
	body.Status.TextColor3 = statusColor
	setVisible(body.Status, status ~= "")
	body.Hint.Text = hint
	setVisible(body.Hint, hint ~= "")
	panel.Accent.BackgroundColor3 = accentColor
	body.Action.Text = actionText or ""
	setVisible(body.Action, actionText ~= nil)
end

---------------------------------------------------------------- cards (shift complete / check in)

local AUTO_NEXT_SECONDS = 4 -- the story shift's "Next shift" presses itself after this
local autoGen = 0

local function showCard(mode: string)
	local card = gui.Card
	if mode == cardMode then
		return
	end
	cardMode = mode
	if mode == "" then
		card.Visible = false
		return
	end
	if mode == "shift" then
		card.Title.Text = "SHIFT COMPLETE"
		card.Body.Text = string.format("You made %s this shift. Run another one?", Format.cash(state.shift.earned))
		card.Primary.Text = "Next shift"
		card.Secondary.Text = "Clock out"
		card.Secondary.Visible = not state.storyJob -- the story shift keeps going
		if state.storyJob then
			-- no dead stop in the first session: the story shift rolls on by itself (play-test 2026-11-02)
			autoGen += 1
			local gen = autoGen
			task.spawn(function()
				for left = AUTO_NEXT_SECONDS, 1, -1 do
					if gen ~= autoGen or cardMode ~= "shift" then
						return
					end
					card.Primary.Text = "Next shift (" .. left .. ")"
					task.wait(1)
				end
				if gen == autoGen and cardMode == "shift" then
					JobController.action("nextShift")
					showCard("")
				end
			end)
		end
	elseif mode == "checkIn" then
		card.Title.Text = "STILL ON POST?"
		card.Body.Text = "The radio's buzzing. Check in to keep getting paid."
		card.Primary.Text = "Check in"
		card.Secondary.Visible = false
	end
	card.Visible = true
	local scale = card:FindFirstChild("Scale") :: UIScale?
	if scale then
		scale.Scale = 0.85
		Motion.tween(scale, Motion.Spring, { Scale = 1 })
	end
	if GuiService.SelectedObject == nil and game:GetService("UserInputService").GamepadEnabled then
		GuiService.SelectedObject = card.Primary
	end
	JobFX.sound(J.Sounds.Whoosh, 0.35)
end

---------------------------------------------------------------- the current step in the world

local function clearStep()
	for _, fn in cleanupStep do
		fn()
	end
	table.clear(cleanupStep)
	if stepFx then
		stepFx.destroy()
		stepFx = nil
	end
	prompt.Enabled = false
	Wayfinder.clear(MARKER_ID)
	stepKey = ""
end

local function faceStation(pos: Vector3)
	local r = root()
	if not r then
		return
	end
	local flat = Vector3.new(pos.X, r.Position.Y, pos.Z)
	if (flat - r.Position).Magnitude > 0.5 then
		r.CFrame = CFrame.lookAt(r.Position, flat)
	end
end

local function startMinigame(t: any)
	if running then
		return
	end
	local taskId, step = t.id, t.step
	JobController.action("begin", { task = taskId, step = step })
	faceStation(t.station.pos)
	UIState.push("JobTask", { lockControls = true })
	prompt.Enabled = false
	local fx = stepFx or JobFX.forStep(nil, t.station.pos)
	running = Minigames.run(gui, t, fx, function(score)
		running = nil
		UIState.pop("JobTask")
		JobController.action("step", { task = taskId, step = step, score = score })
	end, function()
		running = nil
		UIState.pop("JobTask")
		JobController.action("cancel") -- the server takes the tool out of your hand
		if state and state.task and state.task.id == taskId then
			prompt.Enabled = true
		end
	end)
end

local function onPrompt()
	if not state or not state.task or running then
		return
	end
	local t = state.task
	if t.kind == "hold" or t.kind == "timing" or t.kind == "sequence" then
		startMinigame(t)
	else
		JobFX.sound(J.Sounds.Prompt, 0.5)
		if t.fx == "Slam" then
			JobFX.sound(J.Sounds.Slam, 0.6)
		end
		prompt.Enabled = false -- until the server answers
		JobController.action("step", { task = t.id, step = t.step })
		task.delay(1.5, function()
			-- server said no (too far / out of sync): it re-sent the state; make sure the prompt is back
			if state and state.task and state.task.id == t.id and state.task.step == t.step and not running then
				prompt.Enabled = true
			end
		end)
	end
end

local function dressStep()
	local t = state and state.onShift and state.task
	local key = if t then (t.id .. ":" .. t.step) else ""
	if key == stepKey then
		-- same step re-sent (the server refused a press: too far / too fast): offer the prompt again
		if t and not running then
			prompt.Enabled = true
		end
		return
	end
	if running then
		running.cancel()
	end
	clearStep()
	if not t then
		return
	end
	stepKey = key
	local pos = t.station.pos
	local radius = t.station.radius
	-- marker + glow + prompt
	local r = root()
	local far = t.far or (r ~= nil and flatDist(r.Position, pos) > BREADCRUMBS_FROM)
	Wayfinder.set(MARKER_ID, pos, { label = t.prompt, radius = radius, breadcrumbs = far })
	table.insert(cleanupStep, JobFX.beacon(pos, radius))
	placeAnchor(anchor, pos)
	prompt.ActionText = t.prompt
	prompt.ObjectText = t.title
	prompt.MaxActivationDistance = radius + 4
	prompt.Enabled = true
	-- the physical bit of the task
	if t.fx == "Bag" then
		table.insert(cleanupStep, JobFX.bag(pos))
	elseif t.fx then
		stepFx = JobFX.forStep(t.fx, pos)
	end
end

local function dressPost()
	local key = ""
	if state and state.onShift and state.post then
		local s = state.post.station
		key = string.format("%d,%d,%d", math.floor(s.pos.X), math.floor(s.pos.Z), math.floor(s.radius))
	end
	if key == postKey then
		return
	end
	postKey = key
	if postRingOff then
		postRingOff()
		postRingOff = nil
		Wayfinder.clear(MARKER_ID)
	end
	if key ~= "" then
		local s = state.post.station
		postRingOff = JobFX.postRing(s.pos, s.radius)
		Wayfinder.set(MARKER_ID, s.pos, { label = "Your post", radius = s.radius, breadcrumbs = false })
	end
end

local function dressClock()
	local show = state and state.job and not state.onShift and not state.storyJob
	if show then
		placeAnchor(clockAnchor, state.clock.pos)
		clockPrompt.ActionText = "Clock in"
		clockPrompt.ObjectText = state.title
		clockPrompt.MaxActivationDistance = state.clock.radius + 4
		clockPrompt.Enabled = true
	else
		clockPrompt.Enabled = false
		Wayfinder.clear(CLOCK_MARKER_ID)
		clockMarker = false
	end
end

---------------------------------------------------------------- results

local function flash(text: string, color: Color3, sub: string?)
	local f = gui.Flash
	f.Text = if sub then (text .. "\n" .. sub) else text
	f.TextColor3 = color
	f.TextTransparency = 0
	-- the outline is a UIStroke with its own transparency: fade it too, or a hollow "PERFECT!" stays on screen
	local stroke = f:FindFirstChildOfClass("UIStroke")
	if stroke then
		stroke.Transparency = 0.4 -- UI/Build/Job.lua default
	end
	f.Size = UDim2.fromOffset(300, 34)
	Motion.tween(f, Motion.Spring, { Size = UDim2.fromOffset(400, 40) })
	task.delay(0.9, function()
		Motion.tween(f, Motion.Slow, { TextTransparency = 1 })
		if stroke then
			Motion.tween(stroke, Motion.Slow, { Transparency = 1 })
		end
	end)
end

local function onResult(res: any)
	if typeof(res.at) == "Vector3" then
		JobFX.burst(res.at, if res.label == "PERFECT" then J.Perfect else J.Hit)
	end
	if res.label == "PERFECT" then
		Juice.hit("Perfect")
		flash("PERFECT!", J.Perfect, if res.perfectBonus then "+25% tip" else nil)
	elseif res.label == "SLOPPY" then
		flash("SLOPPY", J.Miss, "-20%")
	end
end

-- "+$8" flies from the world spot to the cash counter, "+22 XP" to the level bar
local function flyUp(text: string, color: Color3, from: Vector3, targetName: string, delay: number)
	task.delay(delay, function()
		local vp, onScreen = camera:WorldToViewportPoint(from + Vector3.new(0, 2, 0))
		if not onScreen then
			return
		end
		local inset = GuiService:GetGuiInset()
		local start = Vector2.new(vp.X, vp.Y) - inset
		local hud = player.PlayerGui:FindFirstChild("MTL_HUD")
		local target = hud and hud:FindFirstChild("Stats") and hud.Stats:FindFirstChild(targetName)
		local label = Instance.new("TextLabel")
		label.AnchorPoint = Vector2.new(0.5, 0.5)
		label.BackgroundTransparency = 1
		label.Size = UDim2.fromOffset(120, 30)
		label.Position = UDim2.fromOffset(start.X, start.Y)
		label.FontFace = Theme.Fonts.Display
		label.TextSize = 24
		label.TextColor3 = color
		label.Text = text
		local stroke = Instance.new("UIStroke")
		stroke.Thickness = 2
		stroke.Transparency = 0.3
		stroke.Parent = label
		label.Parent = gui.Fly
		Motion.tween(label, Motion.Spring, { Position = UDim2.fromOffset(start.X, start.Y - 40) }).Completed:Wait()
		task.wait(0.15)
		if target then
			local tp = target.AbsolutePosition + target.AbsoluteSize / 2
			local tw = Motion.tween(label, TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Position = UDim2.fromOffset(tp.X, tp.Y), TextSize = 14 })
			tw.Completed:Wait()
		else
			Motion.tween(label, Motion.Slow, { TextTransparency = 1 }).Completed:Wait()
		end
		label:Destroy()
	end)
end

---------------------------------------------------------------- state in

local function onState(st: any)
	local old = state
	state = st
	stateAt = os.clock()
	if not st or not st.job then
		clearStep()
		dressPost()
		dressClock()
		JobFX.setStatic("", nil)
		showCard("")
		render()
		JobController.Changed:Fire(st)
		return
	end
	JobFX.setStatic(st.job, st.props)
	dressStep()
	dressPost()
	dressClock()
	if st.onShift and st.shift and st.shift.complete then
		showCard("shift")
	elseif st.onShift and st.post and st.post.checkIn then
		showCard("checkIn")
	else
		showCard("")
	end
	if st.result then
		onResult(st.result)
	end
	if old and old.onShift and not st.onShift then
		JobFX.clearDynamic()
	end
	render()
	JobController.Changed:Fire(st)
end

function JobController.init()
	local pg = player:WaitForChild("PlayerGui")
	gui = pg:FindFirstChild("MTL_Job")
	if not gui then
		gui = Build.build()
		gui.Parent = pg
	end
	JobFX.init()
	anchor, prompt = makeAnchor("MTL_JobAnchor")
	clockAnchor, clockPrompt = makeAnchor("MTL_JobClockAnchor")
	prompt.Triggered:Connect(onPrompt)
	clockPrompt.Triggered:Connect(function()
		JobFX.sound(J.Sounds.Prompt, 0.5)
		JobController.action("clockIn")
	end)

	gui.Panel.Body.Action.Activated:Connect(function()
		if not state then
			return
		end
		JobController.action(if state.onShift then "clockOut" else "clockIn")
	end)
	gui.Card.Primary.Activated:Connect(function()
		if cardMode == "shift" then
			JobController.action("nextShift")
		elseif cardMode == "checkIn" and state and state.post then
			JobController.action("checkIn", { token = state.post.checkIn })
		end
		showCard("")
	end)
	gui.Card.Secondary.Activated:Connect(function()
		if cardMode == "shift" then
			JobController.action("clockOut")
		end
		showCard("")
	end)

	Net.get("JobState").OnClientEvent:Connect(function(st)
		if type(st) == "table" then
			onState(st)
		end
	end)
	Net.get("Reward").OnClientEvent:Connect(function(r)
		if type(r) ~= "table" or typeof(r.at) ~= "Vector3" then
			return
		end
		if r.cash then
			flyUp("+" .. Format.cash(r.cash), C.Accent, r.at, "Cash", 0)
		end
		if r.xp then
			flyUp("+" .. tostring(r.xp) .. " XP", C.AccentAlt, r.at, "Level", 0.12)
		end
	end)
	Net.get("LevelUp").OnClientEvent:Connect(function()
		JobFX.levelUp(player.Character)
	end)
	UIState.Changed:Connect(function(st)
		gui.Enabled = not st.hideHUD
		render()
	end)

	-- countdowns, panel visibility near the site, the clock-in marker
	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc < 0.25 then
			return
		end
		acc = 0
		if state and state.job and not state.onShift and not state.storyJob then
			local r = root()
			local near = r ~= nil and flatDist(r.Position, state.site.pos) <= SHOW_CLOCK_WITHIN
			if near and not clockMarker then
				Wayfinder.set(CLOCK_MARKER_ID, state.clock.pos, { label = "Clock in", radius = state.clock.radius, breadcrumbs = false })
				clockMarker = true
			elseif not near and clockMarker then
				Wayfinder.clear(CLOCK_MARKER_ID)
				clockMarker = false
			end
		elseif clockMarker then
			Wayfinder.clear(CLOCK_MARKER_ID)
			clockMarker = false
		end
		render()
	end)

	-- respawn: anchors live in workspace (not the character), but re-ask the server for the truth
	player.CharacterAdded:Connect(function()
		if running then
			running.cancel()
		end
		stepKey = ""
		task.delay(1, function()
			JobController.action("sync")
		end)
	end)
end

return JobController
