--!strict
-- The promotion ceremony. For the local player: input freezes for a beat
-- (ContextActionService sink — the moment should not be clickable-through),
-- camera punch, white flash, PROMOTED! with the new title, confetti, fanfare.
-- For everyone else: a burst over their character plus a toast, because other
-- people's promotions are social proof, not a screen takeover.

local ContextActionService = game:GetService("ContextActionService")
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Trove = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("Trove"))
local Ranks = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("Ranks"))
local SoundController = require(script.Parent.Parent:WaitForChild("Controllers"):WaitForChild("SoundController"))
local CameraFx = require(script.Parent.Parent:WaitForChild("Controllers"):WaitForChild("CameraFx"))
local Theme = require(script.Parent:WaitForChild("Theme"))

local fxRemote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Fx") :: RemoteEvent

local FREEZE_ACTION = "BusinessEvolutionRankUpFreeze"
local FREEZE_SECONDS = 1.2
local CEREMONY_SECONDS = 2.3

type FxPayload = {
	Kind: string,
	UserId: number?,
	Rank: number?,
}

local RankUpFx = {}

local trove = Trove.new()
local overlay: Frame? = nil
local flashFrame: Frame? = nil
local centreScale: UIScale? = nil
local promotedScale: UIScale? = nil
local nameScale: UIScale? = nil
local blurbScale: UIScale? = nil
local nameLabel: TextLabel? = nil
local blurbLabel: TextLabel? = nil
local toastHolder: Frame? = nil
local toastScale: UIScale? = nil
local toastLabel: TextLabel? = nil
-- Generation counters let a second rank-up (or toast) cleanly restart the
-- animation instead of two delayed callbacks fighting over visibility.
local ceremonyGen = 0
local toastGen = 0
local freezeGen = 0

-- ── Input freeze ────────────────────────────────────────────────────────────

local function sinkInput(_actionName: string, _inputState: Enum.UserInputState, _input: InputObject): Enum.ContextActionResult
	return Enum.ContextActionResult.Sink
end

local function freezeInput(seconds: number)
	freezeGen += 1
	local gen = freezeGen
	-- Sink the earning inputs (clicks, taps, jump) at high priority; camera
	-- look-around stays free so the moment doesn't feel like a hang.
	ContextActionService:BindActionAtPriority(
		FREEZE_ACTION,
		sinkInput,
		false,
		Enum.ContextActionPriority.High.Value + 1,
		Enum.UserInputType.MouseButton1,
		Enum.UserInputType.MouseButton2,
		Enum.UserInputType.Touch,
		Enum.KeyCode.Space
	)
	task.delay(seconds, function()
		-- Only the newest freeze may unbind: overlapping rank-ups extend the
		-- freeze rather than releasing it early.
		if freezeGen == gen then
			ContextActionService:UnbindAction(FREEZE_ACTION)
		end
	end)
end

-- ── Local ceremony ──────────────────────────────────────────────────────────

local function playSelfCeremony(rankIndex: number)
	local root = overlay
	local flash = flashFrame
	local centre = centreScale
	local promoted = promotedScale
	local nameZoom = nameScale
	local blurbZoom = blurbScale
	local rankName = nameLabel
	local blurb = blurbLabel
	if not (root and flash and centre and promoted and nameZoom and blurbZoom and rankName and blurb) then
		return
	end
	local rankDef = Ranks.List[rankIndex]
	if not rankDef then
		return
	end

	ceremonyGen += 1
	local gen = ceremonyGen

	rankName.Text = rankDef.Name
	blurb.Text = rankDef.Blurb

	freezeInput(FREEZE_SECONDS)
	CameraFx.zoomPunch()
	SoundController.play("RankUp")

	root.Visible = true
	centre.Scale = 1
	promoted.Scale = 0
	nameZoom.Scale = 0
	blurbZoom.Scale = 0

	-- White flash: pure alpha fade, the one place Linear-adjacent easing rules
	-- don't apply (we still use Quad).
	flash.BackgroundTransparency = 0.1
	Theme.play(flash, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { BackgroundTransparency = 1 })

	Theme.play(promoted, Theme.ElasticInfo, { Scale = 1 })
	task.delay(0.15, function()
		if ceremonyGen == gen then
			Theme.play(nameZoom, Theme.EnterSlowInfo, { Scale = 1 })
		end
	end)
	task.delay(0.3, function()
		if ceremonyGen == gen then
			Theme.play(blurbZoom, Theme.EnterSlowInfo, { Scale = 1 })
		end
	end)

	Theme.confettiRain(root, 42)

	task.delay(CEREMONY_SECONDS, function()
		if ceremonyGen ~= gen then
			return
		end
		Theme.play(centre, TweenInfo.new(0.28, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Scale = 0 })
		task.delay(0.3, function()
			if ceremonyGen == gen then
				root.Visible = false
			end
		end)
	end)
end

-- ── Other players ───────────────────────────────────────────────────────────

local function showToast(text: string)
	local holder = toastHolder
	local scale = toastScale
	local label = toastLabel
	if not (holder and scale and label) then
		return
	end
	toastGen += 1
	local gen = toastGen

	label.Text = text
	holder.Visible = true
	scale.Scale = 0
	Theme.play(scale, Theme.EnterSlowInfo, { Scale = 1 })
	task.delay(2.4, function()
		if toastGen ~= gen then
			return
		end
		Theme.play(scale, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Scale = 0 })
		task.delay(0.27, function()
			if toastGen == gen then
				holder.Visible = false
			end
		end)
	end)
end

local function worldBurstAt(player: Player)
	local character = player.Character
	if not character then
		return
	end
	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if not (rootPart and rootPart:IsA("BasePart")) then
		return
	end

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "PromotionBurst"
	billboard.Adornee = rootPart
	billboard.Size = UDim2.fromScale(9, 9)
	billboard.StudsOffset = Vector3.new(0, 3.5, 0)
	billboard.AlwaysOnTop = true

	local star = Instance.new("TextLabel")
	star.BackgroundTransparency = 1
	star.Size = UDim2.fromScale(1, 1)
	star.Text = "🎉"
	star.TextScaled = true
	local starScale = Instance.new("UIScale")
	starScale.Scale = 0.15
	starScale.Parent = star
	star.Parent = billboard

	-- Small satellites flying out sell "burst" better than one static emoji.
	for index = 1, 4 do
		local spark = Instance.new("TextLabel")
		spark.BackgroundTransparency = 1
		spark.AnchorPoint = Vector2.new(0.5, 0.5)
		spark.Position = UDim2.fromScale(0.5, 0.5)
		spark.Size = UDim2.fromScale(0.3, 0.3)
		spark.Text = "✨"
		spark.TextScaled = true
		spark.Parent = billboard
		local angle = index * math.pi / 2 + 0.6
		Theme.play(spark, TweenInfo.new(0.8, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
			Position = UDim2.fromScale(0.5 + math.cos(angle) * 0.45, 0.5 + math.sin(angle) * 0.45),
			TextTransparency = 1,
		})
	end

	billboard.Parent = rootPart
	Theme.play(starScale, TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 })
	Theme.play(star, TweenInfo.new(1.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { TextTransparency = 1 })
	Debris:AddItem(billboard, 1.6)
end

local function onRankUp(userId: number, rankIndex: number)
	if userId == Players.LocalPlayer.UserId then
		playSelfCeremony(rankIndex)
		return
	end
	local player = Players:GetPlayerByUserId(userId)
	if not player then
		return -- already left; nothing to celebrate at
	end
	local rankDef = Ranks.List[rankIndex]
	local rankLabel = if rankDef then rankDef.Name else "a new rank"
	showToast(("%s was promoted to %s!"):format(player.DisplayName, rankLabel))
	worldBurstAt(player)
end

-- ── Building ────────────────────────────────────────────────────────────────

function RankUpFx:Init()
	local gui = Theme.screenGui("RankUpFx", 10, trove, true)

	local root = Instance.new("Frame")
	root.Name = "Ceremony"
	root.BackgroundTransparency = 1
	root.Size = UDim2.fromScale(1, 1)
	root.Visible = false
	root.Parent = gui
	overlay = root

	local flash = Instance.new("Frame")
	flash.Name = "Flash"
	flash.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	flash.BackgroundTransparency = 1
	flash.BorderSizePixel = 0
	flash.Size = UDim2.fromScale(1, 1)
	flash.ZIndex = 2
	flash.Parent = root
	flashFrame = flash

	local centre = Instance.new("Frame")
	centre.Name = "Centre"
	centre.BackgroundTransparency = 1
	centre.AnchorPoint = Vector2.new(0.5, 0.5)
	centre.Position = UDim2.fromScale(0.5, 0.4)
	centre.Size = UDim2.fromOffset(700, 260)
	centre.ZIndex = 3
	Theme.autoScale(centre, trove)
	local centreZoom = Instance.new("UIScale")
	centreZoom.Parent = centre
	centreScale = centreZoom
	centre.Parent = root

	local promoted = Theme.text({
		Text = "PROMOTED!",
		Parent = centre,
		Size = UDim2.new(1, 0, 0, 90),
		Font = Theme.DisplayFont,
		TextSize = 68,
		Color = Theme.Colors.Gold,
		StrokePx = 5,
		ZIndex = 3,
		Name = "Promoted",
	})
	local promotedZoom = Instance.new("UIScale")
	promotedZoom.Parent = promoted
	promotedScale = promotedZoom

	nameLabel = Theme.text({
		Text = "",
		Parent = centre,
		Size = UDim2.new(1, 0, 0, 56),
		Position = UDim2.new(0, 0, 0, 96),
		Font = Theme.DisplayFont,
		TextSize = 42,
		StrokePx = 4,
		ZIndex = 3,
		Name = "RankName",
	})
	local nameZoom = Instance.new("UIScale")
	nameZoom.Parent = nameLabel
	nameScale = nameZoom

	blurbLabel = Theme.text({
		Text = "",
		Parent = centre,
		Size = UDim2.new(1, -80, 0, 48),
		Position = UDim2.new(0, 40, 0, 160),
		TextSize = 18,
		Color = Theme.Colors.TextDim,
		Wrapped = true,
		StrokePx = 2,
		ZIndex = 3,
		Name = "Blurb",
	})
	local blurbZoom = Instance.new("UIScale")
	blurbZoom.Parent = blurbLabel
	blurbScale = blurbZoom

	-- Toast for other players' promotions, tucked under the HUD's top cluster.
	local holder = Instance.new("Frame")
	holder.Name = "PromotionToast"
	holder.BackgroundTransparency = 1
	holder.AnchorPoint = Vector2.new(0.5, 0)
	holder.Position = UDim2.new(0.5, 0, 0, 150)
	holder.Size = UDim2.fromOffset(460, 46)
	holder.Visible = false
	Theme.autoScale(holder, trove)
	local holderZoom = Instance.new("UIScale")
	holderZoom.Parent = holder
	toastScale = holderZoom

	local toastCard = Theme.card({
		Parent = holder,
		Size = UDim2.fromScale(1, 1),
		Name = "ToastCard",
	})
	local toastStroke = toastCard:FindFirstChildOfClass("UIStroke")
	if toastStroke then
		toastStroke.Color = Theme.Colors.Gold
	end
	toastLabel = Theme.text({
		Text = "",
		Parent = toastCard,
		Size = UDim2.new(1, -20, 1, 0),
		Position = UDim2.new(0, 10, 0, 0),
		Font = Theme.DisplayFont,
		TextSize = 17,
		Color = Theme.Colors.Gold,
		Name = "ToastText",
	})
	holder.Parent = gui
	toastHolder = holder
end

function RankUpFx:Start()
	trove:Connect(fxRemote.OnClientEvent, function(payload: FxPayload)
		-- Overtime is a personal unlock moment, not a ceremony — a toast is
		-- exactly the right size for it.
		if payload.Kind == "Overtime" then
			showToast("🕐 OVERTIME UNLOCKED — free auto-clicks from now on!")
			return
		end
		if payload.Kind ~= "RankUp" then
			return
		end
		local userId = payload.UserId
		local rankIndex = payload.Rank
		if userId == nil or rankIndex == nil then
			return -- malformed broadcast; ignoring beats erroring mid-ceremony
		end
		onRankUp(userId, rankIndex)
	end)
end

return RankUpFx
