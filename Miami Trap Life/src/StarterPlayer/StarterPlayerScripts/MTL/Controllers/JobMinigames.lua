--!strict
-- The three reusable task minigames (helper for JobController, not booted on its own). Research: "Jobs, Leveling
-- and RP Game Feel" (short, readable at a glance, physical feedback, reward at the end).
--   hold     : hold the button while the bar fills. Let go early and it drains (and the score drops a bit).
--   timing   : press when the needle is in the green. Each hit moves the zone and speeds the needle up a touch.
--   sequence : tap the items in the order on the ticket (number keys 1-6 work too).
-- Works with mouse (click/hold the big button), keyboard (E / Space, 1-6), touch (the big button) and gamepad
-- (A / X / R2 to act, B to back out; D-pad/stick to move between sequence buttons).
--   Minigames.run(gui, info, fx, onDone(score), onCancel) -> { cancel = fn }
local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Theme = require(ReplicatedStorage.MTL.UI.Theme)
local Motion = require(ReplicatedStorage.MTL.UI.Motion)
local JobRules = require(ReplicatedStorage.MTL.Rules.JobRules)
local JobFX = require(script.Parent.JobFX)

local C = Theme.Colors
local J = Theme.Job

local ACTION_KEYS = {
	[Enum.KeyCode.E] = true,
	[Enum.KeyCode.Space] = true,
	[Enum.KeyCode.ButtonA] = true,
	[Enum.KeyCode.ButtonX] = true,
	[Enum.KeyCode.ButtonR2] = true,
}
local CANCEL_KEYS = { [Enum.KeyCode.ButtonB] = true, [Enum.KeyCode.Backspace] = true }
local NUMBER_KEYS = { Enum.KeyCode.One, Enum.KeyCode.Two, Enum.KeyCode.Three, Enum.KeyCode.Four, Enum.KeyCode.Five, Enum.KeyCode.Six, Enum.KeyCode.Seven, Enum.KeyCode.Eight }

local Minigames = {}

local function keyHint(): string
	if UserInputService.GamepadEnabled and not UserInputService.KeyboardEnabled then
		return "[A]"
	elseif UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled then
		return ""
	end
	return "[E]"
end

-- tiny "punch": the panel pops a little bigger and settles
local function punch(scale: UIScale?, amount: number?)
	if not scale then
		return
	end
	scale.Scale = 1 + (amount or 0.04)
	Motion.tween(scale, Motion.Fast, { Scale = 1 })
end

local function shake(frame: GuiObject)
	local base = frame.Position
	task.spawn(function()
		for i, dx in { -8, 7, -5, 3, 0 } do
			frame.Position = base + UDim2.fromOffset(dx, 0)
			task.wait(0.03)
			if i == 5 then
				frame.Position = base
			end
		end
	end)
end

function Minigames.run(gui: any, info: any, fx: JobFX.FX, onDone: (number) -> (), onCancel: () -> ())
	local mg = gui.Minigame
	local scale = mg:FindFirstChild("Scale") :: UIScale?
	local action: TextButton = mg.ActionButton
	local conns: { RBXScriptConnection } = {}
	local finished = false
	local basePos = mg.Position

	mg.Hold.Visible = info.kind == "hold"
	mg.Timing.Visible = info.kind == "timing"
	mg.Sequence.Visible = info.kind == "sequence"
	mg.Title.Text = info.verb or string.upper(info.prompt or "")
	action.Visible = info.kind ~= "sequence"
	mg.Visible = true
	mg.Position = basePos + UDim2.fromOffset(0, 30)
	Motion.tween(mg, Motion.Spring, { Position = basePos })

	local function cleanup()
		for _, c in conns do
			c:Disconnect()
		end
		table.clear(conns)
		mg.Visible = false
		mg.Position = basePos
		if GuiService.SelectedObject and GuiService.SelectedObject:IsDescendantOf(mg) then
			GuiService.SelectedObject = nil
		end
	end

	local function finish(score: number)
		if finished then
			return
		end
		finished = true
		fx.finish()
		JobFX.sound(J.Sounds.Done, 0.6)
		punch(scale, 0.08)
		task.delay(0.18, function()
			cleanup()
			onDone(score)
		end)
	end

	local function cancel()
		if finished then
			return
		end
		finished = true
		cleanup()
		onCancel()
	end

	-- input plumbing shared by hold + timing
	local pressedFns: { () -> () } = {}
	local releasedFns: { () -> () } = {}
	local function onPress(fn: () -> ())
		table.insert(pressedFns, fn)
	end
	local function onRelease(fn: () -> ())
		table.insert(releasedFns, fn)
	end
	local function press()
		for _, fn in pressedFns do
			fn()
		end
	end
	local function release()
		for _, fn in releasedFns do
			fn()
		end
	end
	table.insert(conns, action.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			press()
		end
	end))
	table.insert(conns, action.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			release()
		end
	end))
	table.insert(conns, UserInputService.InputBegan:Connect(function(input, processed)
		if CANCEL_KEYS[input.KeyCode] then
			cancel()
		elseif ACTION_KEYS[input.KeyCode] and info.kind ~= "sequence" and not processed then
			press()
		end
	end))
	table.insert(conns, UserInputService.InputEnded:Connect(function(input)
		if ACTION_KEYS[input.KeyCode] then
			release()
		end
	end))
	table.insert(conns, mg.Close.Activated:Connect(cancel))

	if info.kind == "hold" then
		local seconds = math.max(0.5, info.seconds or 3)
		local fill = mg.Hold.Bar.Fill
		local pct = mg.Hold.Percent
		local p, holding, releases, started = 0, false, 0, false
		action.Text = (("HOLD  " .. keyHint()):gsub("%s+$", ""))
		pct.Text = "Hold to start"
		-- the prompt's own E press is usually still held: start right away
		holding = UserInputService:IsKeyDown(Enum.KeyCode.E)
		onPress(function()
			holding = true
		end)
		onRelease(function()
			if holding and started and p > 0.04 and p < 1 then
				releases += 1
				pct.Text = "Keep holding!"
				fill.BackgroundColor3 = J.Miss
				Motion.tween(fill, Motion.Normal, { BackgroundColor3 = C.Accent })
			end
			holding = false
		end)
		local tickAt = 0
		table.insert(conns, RunService.RenderStepped:Connect(function(dt)
			if finished then
				return
			end
			if holding then
				started = true
				p = math.min(1, p + dt / seconds)
				tickAt += dt
				if tickAt > 0.45 then -- little rhythmic click while you work
					tickAt = 0
					JobFX.sound(if info.fx == "Spill" then J.Sounds.Mop else J.Sounds.Prompt, 0.2, 0.9 + p * 0.4)
				end
				pct.Text = string.format("%d%%", math.floor(p * 100))
			elseif started then
				p = math.max(0, p - dt / seconds * 0.6) -- drains when you let go
			end
			fill.Size = UDim2.fromScale(p, 1)
			fx.progress(p, holding)
			if p >= 1 then
				finish(JobRules.scoreHold(releases))
			end
		end))
	elseif info.kind == "timing" then
		local need = info.hits or 3
		local zoneW = math.clamp(info.zone or 0.22, 0.08, 0.6)
		local speed = info.speed or 1
		local track = mg.Timing.Track
		local zone = track.Zone
		local needle = track.Needle
		local pips = mg.Timing.Pips
		for _, c in pips:GetChildren() do
			if c:IsA("GuiObject") then
				c:Destroy()
			end
		end
		for i = 1, need do
			local pip = Instance.new("Frame")
			pip.Name = "Pip" .. i
			pip.Size = UDim2.fromOffset(14, 14)
			pip.BackgroundColor3 = J.Track
			pip.BorderSizePixel = 0
			local corner = Instance.new("UICorner")
			corner.CornerRadius = UDim.new(1, 0)
			corner.Parent = pip
			pip.Parent = pips
		end
		local hits, misses, t, cooldown = 0, 0, math.random() * 2, 0
		local center = 0.5
		local function placeZone()
			center = 0.15 + math.random() * 0.7
			zone.Size = UDim2.fromScale(zoneW, 1)
			Motion.tween(zone, Motion.Fast, { Position = UDim2.fromScale(center, 0) })
		end
		placeZone()
		action.Text = ((string.upper(info.verb or "PRESS") .. "  " .. keyHint()):gsub("%s+$", ""))
		local function needleX(): number
			local phase = (t * speed) % 2 -- ping-pong 0..1..0
			return if phase <= 1 then phase else 2 - phase
		end
		onPress(function()
			if finished or cooldown > 0 then
				return
			end
			cooldown = 0.18
			local x = needleX()
			if math.abs(x - center) <= zoneW / 2 + 0.015 then
				hits += 1
				local pip = pips:FindFirstChild("Pip" .. hits)
				if pip then
					pip.BackgroundColor3 = J.Hit
				end
				zone.BackgroundColor3 = Color3.new(1, 1, 1)
				Motion.tween(zone, Motion.Normal, { BackgroundColor3 = J.Zone })
				JobFX.sound(J.Sounds.Hit, 0.4, 1 + hits * 0.08)
				fx.hit()
				punch(scale, 0.05)
				if hits >= need then
					finish(JobRules.scoreTiming(hits, misses))
					return
				end
				speed *= 1.08
				placeZone()
			else
				misses += 1
				needle.BackgroundColor3 = J.Miss
				Motion.tween(needle, Motion.Normal, { BackgroundColor3 = J.Needle })
				JobFX.sound(J.Sounds.Miss, 0.4)
				shake(mg)
			end
		end)
		table.insert(conns, RunService.RenderStepped:Connect(function(dt)
			if finished then
				return
			end
			t += dt
			cooldown = math.max(0, cooldown - dt)
			needle.Position = UDim2.fromScale(needleX(), 0.5)
		end))
	elseif info.kind == "sequence" then
		local items: { string } = info.items or {}
		local buttonsList: { string } = info.buttons or items
		local ticket = mg.Sequence.Ticket
		local grid = mg.Sequence.Buttons
		for _, c in ticket:GetChildren() do
			if c:IsA("GuiObject") then
				c:Destroy()
			end
		end
		for _, c in grid:GetChildren() do
			if c:IsA("GuiObject") then
				c:Destroy()
			end
		end
		local chips: { TextLabel } = {}
		for i, name in items do
			local chip = Instance.new("TextLabel")
			chip.Name = "Item" .. i
			chip.AutomaticSize = Enum.AutomaticSize.X
			chip.Size = UDim2.fromOffset(0, 24)
			chip.BackgroundColor3 = Color3.fromRGB(230, 222, 200)
			chip.TextColor3 = Color3.fromRGB(40, 36, 30)
			chip.FontFace = Theme.Fonts.Bold
			chip.TextSize = 13
			chip.Text = string.format("  %d. %s  ", i, name)
			local corner = Instance.new("UICorner")
			corner.CornerRadius = UDim.new(0, 4)
			corner.Parent = chip
			chip.Parent = ticket
			table.insert(chips, chip)
		end
		local nextIndex, mistakes = 1, 0
		local buttons: { TextButton } = {}
		local function tap(name: string, btn: TextButton)
			if finished then
				return
			end
			if name == items[nextIndex] then
				local chip = chips[nextIndex]
				chip.BackgroundColor3 = J.Hit
				chip.Text = "  ✓ " .. name .. "  "
				btn.BackgroundTransparency = 0.7
				btn.Active = false
				btn.AutoButtonColor = false
				JobFX.sound(J.Sounds.Hit, 0.4, 1 + nextIndex * 0.08)
				fx.hit()
				punch(scale, 0.04)
				nextIndex += 1
				if nextIndex > #items then
					finish(JobRules.scoreSequence(mistakes))
				end
			elseif btn.Active then
				mistakes += 1
				btn.BackgroundColor3 = J.Miss
				Motion.tween(btn, Motion.Normal, { BackgroundColor3 = Theme.Phone.Card })
				JobFX.sound(J.Sounds.Miss, 0.4)
				shake(mg)
			end
		end
		for i, name in buttonsList do
			local btn = Instance.new("TextButton")
			btn.Name = "Choice" .. i
			btn.LayoutOrder = i
			btn.BackgroundColor3 = Theme.Phone.Card
			btn.TextColor3 = C.Text
			btn.FontFace = Theme.Fonts.Bold
			btn.TextSize = 13
			btn.TextWrapped = true
			btn.Text = if UserInputService.KeyboardEnabled and i <= #NUMBER_KEYS then (i .. "  " .. name) else name
			btn.Selectable = true
			local corner = Instance.new("UICorner")
			corner.CornerRadius = Theme.CornerSmall
			corner.Parent = btn
			btn.Parent = grid
			table.insert(conns, btn.Activated:Connect(function()
				tap(name, btn)
			end))
			table.insert(buttons, btn)
		end
		table.insert(conns, UserInputService.InputBegan:Connect(function(input, processed)
			if processed then
				return
			end
			local idx = table.find(NUMBER_KEYS, input.KeyCode)
			if idx and buttons[idx] then
				tap(buttonsList[idx], buttons[idx])
			end
		end))
		if UserInputService.GamepadEnabled and buttons[1] then
			GuiService.SelectedObject = buttons[1]
		end
	end

	return { cancel = cancel }
end

return Minigames
