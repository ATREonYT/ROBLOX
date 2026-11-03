--!strict
-- Adaptive graphics tier for this client (Config/Quality). Roblox doesn't let a game change the player's own
-- Graphics Quality, so this picks a tier for the game's own extras and keeps adjusting it to the frame rate:
--   * start: the player's Graphics Quality setting (or the device: phone/tablet capped at Med, consoles Med)
--   * runtime: a 5 s rolling FPS average; under 40 for 5 s = one tier down, over 57 for 30 s = one tier up
--     (at most once per 2 minutes, never above the device cap). Ignored for 10 s after a spawn and in cutscenes.
--   * manual: Phone > Settings > Graphics (Auto / Low / Med / High) pins a tier; Auto goes back to adapting
-- Output: player attribute MTL_QualityTier ("Low" | "Med" | "High") and QualityController.Changed(tier, look).
-- API:
--   QualityController.tier() -> "Low" | "Med" | "High"
--   QualityController.look() -> the tier's row in Config/Quality.Tiers
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Quality = require(ReplicatedStorage.MTL.Config.Quality)
local Signal = require(ReplicatedStorage.MTL.Signal)
local ClientData = require(script.Parent.ClientData)
local Cutscene = require(script.Parent.CutsceneController)

local player = Players.LocalPlayer
local QualityController = {}
QualityController.Changed = Signal.new() -- (tier, look)

local RANK = { Low = 1, Med = 2, High = 3 }

local current = "Med"
local autoTier = "Med" -- what the FPS watch wants
local cap = "High" -- device ceiling for Auto
local manual: string? = nil -- a pinned tier from Settings

local function fromLevel(level: number): string
	if level <= Quality.FromLevel.Low then
		return "Low"
	elseif level <= Quality.FromLevel.Med then
		return "Med"
	end
	return "High"
end

local function minTier(a: string, b: string): string
	return if RANK[a] <= RANK[b] then a else b
end

-- the device's ceiling and the tier to start at
local function startTier(): (string, string)
	local touchOnly = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
	local padOnly = UserInputService.GamepadEnabled and not UserInputService.KeyboardEnabled and not UserInputService.TouchEnabled
	local view = workspace.CurrentCamera.ViewportSize
	local short = math.min(view.X, view.Y)
	local deviceCap = "High"
	if touchOnly or short < 500 then
		deviceCap = if short < Quality.Mobile.SmallScreen then Quality.Mobile.SmallCap else Quality.Mobile.Cap
	elseif padOnly then
		deviceCap = Quality.Console
	end

	local tier: string? = nil
	local okSaved, saved = pcall(function()
		return UserSettings().GameSettings.SavedQualityLevel
	end)
	if okSaved and saved and saved.Value > 0 then
		tier = fromLevel(saved.Value) -- QualityLevel1..10
	else
		-- Automatic: Roblox's own current render level (1-21) when the client may read it
		local okRender, level = pcall(function()
			return (settings() :: any).Rendering.QualityLevel.Value
		end)
		if okRender and type(level) == "number" and level > 0 then
			tier = fromLevel(math.ceil(level / 2.1))
		end
	end
	if not tier then
		tier = if deviceCap == "High" then Quality.Desktop else deviceCap
	end
	return minTier(tier, deviceCap), deviceCap
end

local function set(tier: string)
	if tier == current and player:GetAttribute("MTL_QualityTier") == tier then
		return
	end
	current = tier
	player:SetAttribute("MTL_QualityTier", tier)
	QualityController.Changed:Fire(tier, Quality.Tiers[tier])
	print("[MTL Quality] tier", tier, if manual then "(manual)" else "(auto)")
end

local function readManual()
	local d = ClientData.get()
	local choice = d and d.Settings and Quality.Choices[d.Settings.Graphics or 0]
	manual = if choice and choice ~= "Auto" then choice else nil
	set(manual or autoTier)
end

function QualityController.tier(): string
	return current
end

function QualityController.look(): any
	return Quality.Tiers[current]
end

function QualityController.init()
	autoTier, cap = startTier()
	current = ""
	readManual()
	ClientData.Changed:Connect(readManual)

	local F = Quality.Fps
	-- one-second buckets of frame time, rolling over F.Window seconds
	local buckets: { { frames: number, time: number } } = {}
	local bucket = { frames = 0, time = 0 }
	local graceUntil = os.clock() + F.Grace
	local downFor, upFor = 0, 0
	local lastUp = -math.huge

	local function reset()
		table.clear(buckets)
		bucket = { frames = 0, time = 0 }
		downFor, upFor = 0, 0
	end
	player.CharacterAdded:Connect(function()
		graceUntil = os.clock() + F.Grace
		reset()
	end)

	RunService.Heartbeat:Connect(function(dt)
		if os.clock() < graceUntil or Cutscene.isPlaying() then
			reset()
			return
		end
		bucket.frames += 1
		bucket.time += dt
		if bucket.time < 1 then
			return
		end
		table.insert(buckets, bucket)
		if #buckets > F.Window then
			table.remove(buckets, 1)
		end
		bucket = { frames = 0, time = 0 }
		if #buckets < F.Window then
			return
		end
		local frames, time = 0, 0
		for _, b in buckets do
			frames += b.frames
			time += b.time
		end
		local fps = frames / time
		-- one bucket is one second of watching
		downFor = if fps < F.DownBelow then downFor + 1 else 0
		upFor = if fps > F.UpAbove then upFor + 1 else 0
		if downFor >= F.DownFor and RANK[autoTier] > 1 then
			autoTier = Quality.Order[RANK[autoTier] - 1]
			reset()
		elseif upFor >= F.UpFor and RANK[autoTier] < RANK[cap] and os.clock() - lastUp >= F.UpCooldown then
			autoTier = Quality.Order[RANK[autoTier] + 1]
			lastUp = os.clock()
			reset()
		else
			return
		end
		if not manual then
			set(autoTier)
		end
	end)
end

return QualityController
