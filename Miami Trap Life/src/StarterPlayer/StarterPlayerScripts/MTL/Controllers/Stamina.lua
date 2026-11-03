--!strict
-- Stamina (Quality pass, Benchmark Gap List 1.4). Sprinting costs breath: a full bar lasts about 7 seconds of
-- running, then you're winded and drop to a walk until the bar is back over a quarter. It refills after you stop
-- sprinting for a moment. Walking, crouching and standing all refill it.
--
-- The bar: a slim pill above the hotbar that only shows while it isn't full (fades out a second after it fills).
-- It turns amber under a quarter and red-pulses while winded. Winded also gives your chest a heave for a few
-- seconds (local only; nobody else needs to see you breathe).
--
-- Hook: MovementController.sprintGate (one line in canSprint) asks Stamina.canSprint() every frame.
-- Client only: running speed is already the client's call (MovementController is the only WalkSpeed writer).
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Theme = require(game:GetService("ReplicatedStorage").MTL.UI.Theme)
local UIState = require(script.Parent.UIState)
local MovementController = require(script.Parent.MovementController)

local Stamina = {}

local MAX = 100
local DRAIN = 14 -- per second while sprinting (about 7 s from full)
local REGEN = 22 -- per second once refilling
local REGEN_DELAY = 1.0 -- seconds after you stop sprinting before it refills
local WINDED_REGEN_DELAY = 1.6 -- a bit longer when you ran it dry
local UNLOCK = 25 -- winded until the bar is back over this
local LOW = 25
local HEAVE_SECONDS = 3.5

local player = Players.LocalPlayer
local value = MAX
local winded = false
local sinceSprint = 99
local heaveLeft = 0

local gui: ScreenGui? = nil
local back: Frame? = nil
local fill: Frame? = nil
local shownAlpha = 0
local fullFor = 99

function Stamina.get(): number
	return value
end

function Stamina.isWinded(): boolean
	return winded
end

function Stamina.canSprint(): boolean
	return not winded and value > 0
end

-- Give stamina back (a drink, a level perk...). Clamped.
function Stamina.add(n: number)
	value = math.clamp(value + n, 0, MAX)
	if winded and value >= UNLOCK then
		winded = false
	end
end

---------------------------------------------------------------- the bar
local function build()
	local pg = player:WaitForChild("PlayerGui")
	local g = Instance.new("ScreenGui")
	g.Name = "MTL_Stamina"
	g.ResetOnSpawn = false
	g.IgnoreGuiInset = false
	g.DisplayOrder = 4
	local b = Instance.new("Frame")
	b.Name = "Back"
	b.AnchorPoint = Vector2.new(0.5, 1)
	b.Position = UDim2.new(0.5, 0, 1, -96)
	b.Size = UDim2.fromOffset(190, 7)
	b.BackgroundColor3 = Theme.Colors.Glass
	b.BackgroundTransparency = 1
	b.BorderSizePixel = 0
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(1, 0)
	c.Parent = b
	local s = Instance.new("UIStroke")
	s.Color = Theme.Colors.Shadow
	s.Thickness = 1.5
	s.Transparency = 1
	s.Parent = b
	local f = Instance.new("Frame")
	f.Name = "Fill"
	f.Size = UDim2.fromScale(1, 1)
	f.BackgroundColor3 = Theme.Colors.AccentAlt
	f.BackgroundTransparency = 1
	f.BorderSizePixel = 0
	local fc = Instance.new("UICorner")
	fc.CornerRadius = UDim.new(1, 0)
	fc.Parent = f
	local grad = Instance.new("UIGradient")
	grad.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 0.15) })
	grad.Parent = f
	f.Parent = b
	b.Parent = g
	g.Parent = pg
	gui, back, fill = g, b, f
end

-- sit just above the hotbar wherever it ends up (it moves for touch / gun buttons)
local function place()
	if not back then
		return
	end
	local hud = player.PlayerGui:FindFirstChild("MTL_HUD")
	local bar = hud and hud:FindFirstChild("Hotbar") :: GuiObject?
	if bar and bar.Visible and bar.AbsoluteSize.Y > 0 and gui then
		-- same inset rule as the HUD, so both measure from the same corner
		gui.IgnoreGuiInset = (hud :: ScreenGui).IgnoreGuiInset
		local top = bar.AbsolutePosition.Y
		local cx = bar.AbsolutePosition.X + bar.AbsoluteSize.X / 2
		back.Position = UDim2.fromOffset(math.floor(cx + 0.5), math.floor(top - 8 + 0.5))
		back.AnchorPoint = Vector2.new(0.5, 1)
	end
end

local function draw(dt: number, t: number)
	if not (back and fill) then
		return
	end
	local frac = value / MAX
	fullFor = if frac >= 0.999 then fullFor + dt else 0
	local want = if fullFor < 1.0 and not UIState.get().hideHUD then 1 else 0
	shownAlpha += (want - shownAlpha) * (1 - math.exp(-dt * (if want > shownAlpha then 14 else 5)))
	local a = shownAlpha
	fill.Size = UDim2.fromScale(math.max(frac, 0.001), 1)
	local col = Theme.Colors.AccentAlt
	if winded then
		local p = (math.sin(t * 9) + 1) / 2
		col = Theme.Colors.Danger:Lerp(Color3.new(1, 1, 1), p * 0.25)
	elseif frac < LOW / MAX then
		col = Theme.Colors.Gold
	end
	fill.BackgroundColor3 = col
	fill.BackgroundTransparency = 1 - a
	back.BackgroundTransparency = 1 - a * (1 - Theme.Colors.GlassTransparency)
	local st = back:FindFirstChildOfClass("UIStroke")
	if st then
		st.Transparency = 1 - a * 0.6
	end
end

---------------------------------------------------------------- winded chest heave (local character)
local waist: any = nil
local function findWaist(char: Model)
	waist = nil
	for _, d in char:GetDescendants() do
		if (d:IsA("Motor6D") or d.ClassName == "AnimationConstraint") and d.Name == "Waist" then
			waist = d
		end
	end
end

function Stamina.init()
	build()
	MovementController.sprintGate = Stamina.canSprint
	player.CharacterAdded:Connect(function(c)
		value, winded, heaveLeft = MAX, false, 0
		task.defer(findWaist, c)
	end)
	if player.Character then
		task.defer(findWaist, player.Character)
	end

	RunService.RenderStepped:Connect(function(dt)
		local t = os.clock()
		if MovementController.isSprinting() then
			sinceSprint = 0
			value = math.max(0, value - DRAIN * dt)
			if value <= 0 and not winded then
				winded = true
				heaveLeft = HEAVE_SECONDS
			end
		else
			sinceSprint += dt
			if sinceSprint >= (if winded then WINDED_REGEN_DELAY else REGEN_DELAY) then
				value = math.min(MAX, value + REGEN * dt)
			end
			if winded and value >= UNLOCK then
				winded = false
			end
		end
		place()
		draw(dt, t)
	end)

	-- the heave rides on top of whatever the animation did this frame
	RunService.PreSimulation:Connect(function(dt)
		if heaveLeft <= 0 or not waist or not waist.Parent then
			return
		end
		heaveLeft = math.max(0, heaveLeft - dt)
		local fade = math.min(1, heaveLeft / 1.0)
		local p = math.sin(os.clock() * 7) -- ~1.1 breaths a second
		waist.Transform = waist.Transform * CFrame.Angles(math.rad(-4 - 3 * p) * fade, 0, 0)
	end)
end

return Stamina
