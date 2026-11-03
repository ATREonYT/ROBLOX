--!strict
-- Getting dropped reads as a moment, not a hard cut: when your character dies the world drains of colour and
-- softens, the camera slowly pushes in (the "slow-mo" beat; Roblox can't slow time for one player), a low thud
-- plays, and the MTL_Dropped card counts down to the respawn (Players.RespawnTime). Kid-safe: no blood, no gore,
-- no killer name. Everything eases back when the new character spawns. Settings.ReducedMotion skips the push-in.
-- Recap: one line on how it happened (Services/GunDowned sets MTL_DeathCause: Finished / BledOut / Other), and a
-- RESPAWN button that brings you back early (after Guns.Downed.RespawnAfter s; the countdown still runs).
-- Numbers: Config/Movement.Dropped.
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Movement = require(ReplicatedStorage.MTL.Config.Movement)
local Guns = require(ReplicatedStorage.MTL.Config.Guns)
local Sfx = require(ReplicatedStorage.MTL.UI.Sfx)
local Build = require(ReplicatedStorage.MTL.UI.Build.Dropped)
local Net = require(ReplicatedStorage.MTL.Net)
local Theme = require(ReplicatedStorage.MTL.UI.Theme)
local UIState = require(script.Parent.UIState)
local ClientData = require(script.Parent.ClientData)

local D = Movement.Dropped
local player = Players.LocalPlayer

local DeathController = {}

local gui: ScreenGui
local grade: ColorCorrectionEffect
local blur: BlurEffect
local downGen = 0

local function reducedMotion(): boolean
	local d = ClientData.get()
	return d ~= nil and d.Settings ~= nil and d.Settings.ReducedMotion == true
end

local function tween(inst: Instance, seconds: number, props: { [string]: any }, style: Enum.EasingStyle?)
	local t = TweenService:Create(inst, TweenInfo.new(seconds, style or Enum.EasingStyle.Quad, Enum.EasingDirection.Out), props)
	t:Play()
	return t
end

local function respawnSeconds(): number
	local ok, t = pcall(function()
		return Players.RespawnTime
	end)
	return if ok and type(t) == "number" and t > 0 then t else 5
end

local RECAP = {
	Finished = "Someone finished you while you were down",
	BledOut = "You bled out",
	Other = "",
}

-- The recap line + RESPAWN button live under the card; made here if the reskinned card doesn't have them.
local function extras(card: CanvasGroup): (TextLabel, TextButton)
	local recap = card:FindFirstChild("Recap") :: TextLabel?
	local btn = card:FindFirstChild("Respawn") :: TextButton?
	if not recap or not btn then
		card.Size = UDim2.fromOffset(card.Size.X.Offset, 164)
	end
	if not recap then
		local l = Instance.new("TextLabel")
		l.Name = "Recap"
		l.BackgroundTransparency = 1
		l.Position = UDim2.fromOffset(0, 98)
		l.Size = UDim2.new(1, 0, 0, 18)
		l.FontFace = Theme.Fonts.Body
		l.TextColor3 = Theme.Colors.TextDim
		l.TextSize = 14
		l.Text = ""
		l.Parent = card
		recap = l
	end
	if not btn then
		local b = Instance.new("TextButton")
		b.Name = "Respawn"
		b.AnchorPoint = Vector2.new(0.5, 0)
		b.Position = UDim2.new(0.5, 0, 0, 122)
		b.Size = UDim2.fromOffset(150, 30)
		b.BackgroundColor3 = Theme.Colors.Text
		b.FontFace = Theme.Fonts.Bold
		b.Text = "RESPAWN"
		b.TextColor3 = Theme.Colors.Glass
		b.TextSize = 15
		b.AutoButtonColor = true
		local c = Instance.new("UICorner")
		c.CornerRadius = UDim.new(0, 8)
		c.Parent = b
		b.Activated:Connect(function()
			if b:GetAttribute("Ready") then
				b:SetAttribute("Ready", false)
				b.Text = "..."
				Net.get("GunAction"):FireServer({ type = "respawn" })
			end
		end)
		b.Parent = card
		btn = b
	end
	return recap :: TextLabel, btn :: TextButton
end

local function onDied()
	downGen += 1
	local gen = downGen
	local deadChar = player.Character
	UIState.push("Dropped", { hideWaypoints = true })
	Sfx.play("Dropped")
	tween(grade, D.FadeSeconds, { Saturation = D.Saturation, Contrast = D.Contrast, Brightness = D.Brightness })
	blur.Enabled = true
	tween(blur, D.FadeSeconds, { Size = D.Blur })
	local cam = Workspace.CurrentCamera
	if not reducedMotion() and cam.CameraType == Enum.CameraType.Custom then
		tween(cam, D.PushSeconds, { FieldOfView = math.max(30, cam.FieldOfView - D.PushFov) }, Enum.EasingStyle.Sine)
	end

	local card = gui:FindFirstChild("Card") :: CanvasGroup?
	local sub = card and card:FindFirstChild("Sub") :: TextLabel?
	local fill = card and card:FindFirstChild("Bar") and (card :: any).Bar:FindFirstChild("Fill") :: Frame?
	local total = respawnSeconds()
	gui.Enabled = true
	if card then
		local recap, btn = extras(card)
		recap.Text = ""
		btn.Visible = false
		btn:SetAttribute("Ready", false)
		task.delay(0.1, function() -- the cause attribute lands with the death
			if gen == downGen and deadChar then
				local cause = deadChar:GetAttribute("MTL_DeathCause")
				recap.Text = RECAP[if type(cause) == "string" then cause else "Other"] or ""
			end
		end)
		local wait = Guns.Downed.RespawnAfter
		if total > wait + 1 then
			task.delay(math.max(D.CardDelay, wait), function()
				if gen == downGen then
					btn.Text = "RESPAWN"
					btn.Visible = true
					btn:SetAttribute("Ready", true)
				end
			end)
		end
	end
	task.delay(D.CardDelay, function()
		if gen ~= downGen or not card then
			return
		end
		card.GroupTransparency = 1
		card.Position = UDim2.fromScale(0.5, 0.66)
		tween(card, 0.35, { GroupTransparency = 0, Position = UDim2.fromScale(0.5, 0.62) }, Enum.EasingStyle.Back)
		if fill then
			fill.Size = UDim2.fromScale(0, 1)
			tween(fill, math.max(0.1, total - D.CardDelay), { Size = UDim2.fromScale(1, 1) }, Enum.EasingStyle.Linear)
		end
		local left = math.ceil(total - D.CardDelay)
		while gen == downGen and left > 0 do
			if sub then
				sub.Text = "Back on your feet in " .. left
			end
			task.wait(1)
			left -= 1
		end
	end)
end

local function onSpawned()
	if not UIState.has("Dropped") then
		return
	end
	downGen += 1
	UIState.pop("Dropped")
	tween(grade, 0.6, { Saturation = 0, Contrast = 0, Brightness = 0 })
	local gen = downGen
	tween(blur, 0.4, { Size = 0 }).Completed:Connect(function()
		if gen == downGen then
			blur.Enabled = false -- a 0-size blur still costs a full-screen pass
		end
	end)
	local cam = Workspace.CurrentCamera
	if cam.CameraType == Enum.CameraType.Custom then
		tween(cam, 0.5, { FieldOfView = Guns.Tuning.BaseFov })
	end
	local card = gui:FindFirstChild("Card") :: CanvasGroup?
	if card then
		tween(card, 0.25, { GroupTransparency = 1 })
	end
	task.delay(0.3, function()
		if not UIState.has("Dropped") then
			gui.Enabled = false
		end
	end)
end

local function watch(char: Model)
	onSpawned()
	local hum = char:WaitForChild("Humanoid", 10) :: Humanoid?
	if hum then
		hum.Died:Connect(onDied)
	end
end

function DeathController.init()
	local pg = player:WaitForChild("PlayerGui")
	local existing = pg:FindFirstChild("MTL_Dropped")
	if existing and existing:IsA("ScreenGui") then
		gui = existing
	else
		gui = Build.build()
		gui.Parent = pg
	end
	gui.Enabled = false
	-- our own grade + blur (local, so it never fights the lighting thread's effects)
	grade = Instance.new("ColorCorrectionEffect")
	grade.Name = "MTL_DroppedGrade"
	grade.Parent = Lighting
	blur = Instance.new("BlurEffect")
	blur.Name = "MTL_DroppedBlur"
	blur.Size = 0
	blur.Enabled = false -- on only while you're dropped
	blur.Parent = Lighting
	player.CharacterAdded:Connect(watch)
	if player.Character then
		task.spawn(watch, player.Character)
	end
end

return DeathController
