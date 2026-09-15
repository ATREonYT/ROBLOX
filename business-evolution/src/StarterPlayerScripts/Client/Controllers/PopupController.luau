--!strict
-- Floating "+N 💼" / "+N 🏆" numbers. Driven entirely by server messages
-- (ClickResult and Fx) so a popup can never show income that didn't happen.
-- Labels are pooled: at 20 clicks/second creating and destroying instances
-- every click is measurable garbage on low-end phones.

local CollectionService = game:GetService("CollectionService")
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Trove = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("Trove"))
local Format = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Util"):WaitForChild("Format"))
local SoundController = require(script.Parent:WaitForChild("SoundController"))
local CameraFx = require(script.Parent:WaitForChild("CameraFx"))

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local clickResultRemote = remotes:WaitForChild("ClickResult") :: RemoteEvent
local fxRemote = remotes:WaitForChild("Fx") :: RemoteEvent

-- Timing: a quick pop-in, a beat, then rise and fade. Total life 0.5s, which
-- keeps it under the 0.6s ceiling every tween in this game obeys.
local IN_SECONDS = 0.1
local HOLD_SECONDS = 0.05
local OUT_SECONDS = 0.35
local JITTER_PIXELS = 20
local RISE_PIXELS = 50

local BASE_TEXT_SIZE = 32
local COLOR_NORMAL = Color3.fromRGB(255, 255, 255)
local COLOR_CRIT = Color3.fromRGB(255, 200, 0)
-- Big crits get brighter as well as bigger, per contract ("larger + brighter").
local COLOR_BIG_CRIT = Color3.fromRGB(255, 236, 90)
local COLOR_WINS = Color3.fromRGB(255, 196, 40) -- theme gold #FFC428

type ClickResultPayload = {
	Amount: number,
	Crit: "none" | "crit" | "big",
	Kind: "click" | "train" | "outwork",
	RivalId: string?,
}

type FxPayload = {
	Kind: string,
	UserId: number?,
	RivalId: string?,
	Position: { number }?,
	Rank: number?,
	Wins: number?,
}

type Popup = {
	Label: TextLabel,
	Stroke: UIStroke,
	Scale: UIScale,
}

local PopupController = {}

local trove = Trove.new()
local rng = Random.new()
local screenGui: ScreenGui? = nil
local freePopups: { Popup } = {}

local function makePopup(parent: ScreenGui): Popup
	local label = Instance.new("TextLabel")
	label.Name = "Popup"
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextSize = BASE_TEXT_SIZE
	label.TextWrapped = false
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.Size = UDim2.fromOffset(240, 60)
	label.Visible = false

	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(0, 0, 0)
	stroke.Thickness = 3.5
	stroke.LineJoinMode = Enum.LineJoinMode.Round
	stroke.Parent = label

	local scale = Instance.new("UIScale")
	scale.Parent = label

	label.Parent = parent
	return { Label = label, Stroke = stroke, Scale = scale }
end

local function acquirePopup(): Popup?
	local gui = screenGui
	if not gui then
		return nil -- Init hasn't run; nothing sane to attach to
	end
	local popup = table.remove(freePopups)
	if popup then
		return popup
	end
	return makePopup(gui)
end

-- WorldToViewportPoint is in viewport space (below the topbar) while our
-- ScreenGui ignores the inset, so shift by the inset to line the two up.
local function worldToScreen(worldPosition: Vector3): Vector2?
	local camera = workspace.CurrentCamera
	if not camera then
		return nil
	end
	local point, onScreen = camera:WorldToViewportPoint(worldPosition)
	if not onScreen then
		return nil -- a popup pinned to a point behind the camera looks broken
	end
	local inset = GuiService:GetGuiInset()
	return Vector2.new(point.X + inset.X, point.Y + inset.Y)
end

-- RivalRenderer tags its client-built models "RivalModel" with a "RivalId"
-- attribute; that is the only way to locate a rival's body on this side.
local function rivalTopPosition(rivalId: string): Vector3?
	for _, tagged in CollectionService:GetTagged("RivalModel") do
		if tagged:IsA("Model") and tagged:GetAttribute("RivalId") == rivalId then
			local cf, size = tagged:GetBoundingBox()
			return cf.Position + Vector3.new(0, size.Y / 2 + 1.5, 0)
		end
	end
	return nil
end

-- Batched training income has no cursor to anchor to, so it floats off the
-- local character's head instead.
local function characterScreenPosition(): Vector2?
	local character = Players.LocalPlayer.Character
	if not character then
		return nil
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		return worldToScreen(root.Position + Vector3.new(0, 3.5, 0))
	end
	return nil
end

local function showPopup(text: string, color: Color3, screenPosition: Vector2, sizeScale: number)
	local popup = acquirePopup()
	if not popup then
		return
	end
	-- Jitter keeps a click storm readable — perfectly stacked popups merge
	-- into one unreadable blob.
	local x = screenPosition.X + rng:NextNumber(-JITTER_PIXELS, JITTER_PIXELS)
	local y = screenPosition.Y + rng:NextNumber(-JITTER_PIXELS, JITTER_PIXELS)

	local label = popup.Label
	label.Text = text
	label.TextColor3 = color
	label.TextTransparency = 0
	label.Position = UDim2.fromOffset(x, y)
	popup.Stroke.Transparency = 0
	popup.Scale.Scale = 0
	label.Visible = true

	-- Entrance: Back overshoot (squash-and-stretch family), never Linear.
	TweenService:Create(
		popup.Scale,
		TweenInfo.new(IN_SECONDS, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{ Scale = sizeScale }
	):Play()

	-- Scheduled with task.delay instead of tween.Completed connections: these
	-- fire hundreds of times a minute and one-shot threads leave nothing to
	-- disconnect, while pushing that many dead connections into a Trove would
	-- itself be the leak.
	task.delay(IN_SECONDS + HOLD_SECONDS, function()
		local outInfo = TweenInfo.new(OUT_SECONDS, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		TweenService:Create(label, outInfo, {
			Position = UDim2.fromOffset(x, y - RISE_PIXELS),
			TextTransparency = 1,
		}):Play()
		TweenService:Create(popup.Stroke, outInfo, { Transparency = 1 }):Play()
		task.delay(OUT_SECONDS, function()
			-- Only fully-finished labels re-enter the pool, so a popup can
			-- never be stolen mid-animation.
			label.Visible = false
			table.insert(freePopups, popup)
		end)
	end)
end

local function onClickResult(payload: ClickResultPayload)
	local sizeScale = 1
	local color = COLOR_NORMAL
	if payload.Crit == "crit" then
		color = COLOR_CRIT
		sizeScale = 1.2
		SoundController.play("Crit")
	elseif payload.Crit == "big" then
		color = COLOR_BIG_CRIT
		sizeScale = 1.6
		SoundController.play("BigCrit")
		CameraFx.shake(0.5)
	end

	local screenPosition: Vector2? = nil
	if payload.Kind == "outwork" and payload.RivalId then
		local top = rivalTopPosition(payload.RivalId)
		if top then
			screenPosition = worldToScreen(top)
		end
	elseif payload.Kind == "train" then
		screenPosition = characterScreenPosition()
	end
	-- Plain clicks anchor to the cursor; the cursor also catches every
	-- fallback (rival off-screen, character missing) so income always shows.
	local anchor: Vector2 = screenPosition or UserInputService:GetMouseLocation()

	showPopup("+" .. Format.abbreviate(payload.Amount) .. " 💼", color, anchor, sizeScale)
end

local function onFx(payload: FxPayload)
	if payload.Kind ~= "RivalDefeated" and payload.Kind ~= "BossDefeated" then
		return
	end
	-- Wins popups are personal — everyone gets this Fx broadcast, but only
	-- the player who landed the defeat earned the number.
	if payload.UserId ~= Players.LocalPlayer.UserId then
		return
	end

	local worldPosition: Vector3? = nil
	local rawPosition = payload.Position
	if rawPosition and #rawPosition >= 3 then
		worldPosition = Vector3.new(rawPosition[1], rawPosition[2], rawPosition[3])
	elseif payload.RivalId then
		worldPosition = rivalTopPosition(payload.RivalId)
	end

	local screenPosition: Vector2? = nil
	if worldPosition then
		screenPosition = worldToScreen(worldPosition)
	end
	local anchor: Vector2 = screenPosition or UserInputService:GetMouseLocation()

	-- Defeat sounds and screen shake belong to RivalRenderer's defeat
	-- spectacle; doubling them here would stack the same effect twice.
	local sizeScale = if payload.Kind == "BossDefeated" then 1.6 else 1.3
	showPopup("+" .. Format.abbreviate(payload.Wins or 0) .. " 🏆", COLOR_WINS, anchor, sizeScale)
end

function PopupController:Init()
	local gui = Instance.new("ScreenGui")
	gui.Name = "Popups"
	gui.ResetOnSpawn = false
	-- Ignoring the inset makes gui coordinates equal GetMouseLocation
	-- coordinates, so cursor popups land exactly under the click.
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 100 -- income numbers float above every panel
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	trove:Add(gui)
	screenGui = gui
end

function PopupController:Start()
	trove:Connect(clickResultRemote.OnClientEvent, onClickResult)
	trove:Connect(fxRemote.OnClientEvent, onFx)
end

return PopupController
