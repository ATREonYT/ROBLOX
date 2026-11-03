--!strict
-- Cash pill, level + health rings, objective line, toasts, reward pops, level-up banner.
-- (The icon menu is MenuController, the hotbar HotbarController, world markers MapMarkers.)
-- Uses PlayerGui.MTL_HUD (cloned from StarterGui, where Alex can reskin it); builds one only if it's missing.
--   HUD.objective(text)  HUD.toast(text, color?)  HUD.banner(title, sub?, color?)
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local Net = require(ReplicatedStorage.MTL.Net)
local Theme = require(ReplicatedStorage.MTL.UI.Theme)
local Sfx = require(ReplicatedStorage.MTL.UI.Sfx)
local Motion = require(ReplicatedStorage.MTL.UI.Motion)
local Format = require(ReplicatedStorage.MTL.Format)
local LevelRules = require(ReplicatedStorage.MTL.Rules.LevelRules)
local Build = require(ReplicatedStorage.MTL.UI.Build.HUD)
local ClientData = require(script.Parent.ClientData)
local UIState = require(script.Parent.UIState)

local player = Players.LocalPlayer
local HUD = {}

local gui: any
local shownCash = 0
local shownLevel = 0
local shownProgress = 0
local objectiveText = ""
local bannerQueue: { { title: string, sub: string?, color: Color3?, key: string? } } = {}
local bannerBusy = false
local lastLevelSound = 0 -- one level-up ding per burst, not one per level
local MAX_TOASTS = 4

local function sound(id: string?, volume: number?)
	if not id or id == "" or id == "rbxassetid://0" then
		return
	end
	Sfx.playId(id, { volume = volume or 0.5 })
end

local function getGui()
	local pg = player:WaitForChild("PlayerGui")
	local existing = pg:FindFirstChild("MTL_HUD")
	if existing then
		return existing
	end
	local built = Build.build()
	built.Parent = pg
	return built
end

-- tweens a number and calls fn(value) every frame (ring fills)
local ringTween: Tween? = nil
local function tweenValue(from: number, to: number, duration: number, fn: (number) -> ())
	if ringTween then
		ringTween:Cancel()
	end
	local v = Instance.new("NumberValue")
	v.Value = from
	v.Changed:Connect(fn)
	local t = Motion.tween(v, TweenInfo.new(duration, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), { Value = to })
	ringTween = t
	t.Completed:Once(function(state)
		if state == Enum.PlaybackState.Completed then
			fn(to)
		end
		v:Destroy()
	end)
end

local function setLevel(level: number, xp: number)
	local ring = gui.Top.Status.Level
	local p = LevelRules.progress(level, xp)
	if level ~= shownLevel and shownLevel ~= 0 then
		-- fill to the end, snap to 0, fill to the new progress
		tweenValue(shownProgress, 1, 0.25, function(v)
			Build.setRing(ring, v)
		end)
		task.wait(0.3)
		shownProgress = 0
	end
	local from = shownProgress
	shownProgress = p
	tweenValue(from, p, 0.5, function(v)
		Build.setRing(ring, v)
	end)
	shownLevel = level
	ring.Center.Num.Text = tostring(level)
	local xpBox = gui.Top.Status.XP
	xpBox.Title.Text = "LEVEL " .. level
	local need = LevelRules.need(level)
	xpBox.Text.Text = if need == math.huge then "MAX" else string.format("%s / %s XP", Format.short(xp), Format.short(need))
end

local function bump(frame: GuiObject)
	local scale = frame:FindFirstChild("Bump") or Instance.new("UIScale")
	scale.Name = "Bump"
	scale.Parent = frame
	scale.Scale = 1.08
	Motion.tween(scale, Motion.Spring, { Scale = 1 })
end

local function render(data: any)
	if not data then
		return
	end
	local cashLabel = gui.Top.Cash.Amount
	if data.Cash ~= shownCash then
		local first = shownCash == 0
		Motion.count(cashLabel, shownCash, data.Cash, if first then 0.01 else 0.6, Format.cash)
		if not first and data.Cash > shownCash then
			bump(gui.Top.Cash)
		end
		shownCash = data.Cash
	end
	setLevel(data.Level, data.XP)

	local b = data.Boosts or {}
	local parts = {}
	if player:GetAttribute("MTL_Pass_Cash2x") or (b.Cash2xSeconds or 0) > 0 then
		table.insert(parts, "2x CASH")
	end
	if player:GetAttribute("MTL_Pass_XP2x") or (b.XP2xSeconds or 0) > 0 then
		table.insert(parts, "2x XP")
	end
	gui.Top.Status.Boosts.Text = table.concat(parts, "  ")
end

-- health ring follows the character
local function watchHealth(char: Model)
	local hum = char:WaitForChild("Humanoid", 10) :: Humanoid?
	if not hum then
		return
	end
	local ring = gui.Top.Status.Health
	local H = Theme.HUD
	local function update()
		local p = if hum.MaxHealth > 0 then hum.Health / hum.MaxHealth else 0
		Build.setRing(ring, p, if p < 0.35 then H.HealthLow else H.Health)
	end
	update()
	hum.HealthChanged:Connect(update)
	hum:GetPropertyChangedSignal("MaxHealth"):Connect(update)
end

-- smaller screens get a smaller HUD (phones), never bigger than designed
local function fitScale()
	local cam = workspace.CurrentCamera
	local function apply()
		local v = cam.ViewportSize
		local s = math.clamp(math.min(v.X / 1280, v.Y / 760), 0.62, 1)
		for _, name in { "Top", "Menu", "Hotbar" } do
			local f = gui:FindFirstChild(name)
			local sc = f and f:FindFirstChild("Scale")
			if sc then
				sc.Scale = s
			end
		end
	end
	apply()
	cam:GetPropertyChangedSignal("ViewportSize"):Connect(apply)
end

function HUD.objective(text: string)
	if text == objectiveText then
		return
	end
	objectiveText = text
	local frame = gui.Objective
	local label = frame.Text
	if text == "" then
		frame.Visible = false
		return
	end
	-- old line out (fade), new line in (drop from above)
	if frame.Visible then
		Motion.tween(label, Motion.Fast, { TextTransparency = 1 }).Completed:Wait()
	end
	label.Text = text
	frame.Position = UDim2.new(0.5, 0, 0, 54)
	label.TextTransparency = 1
	frame.Visible = true
	Motion.tween(frame, TweenInfo.new(0.3, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), { Position = UDim2.new(0.5, 0, 0, 64) })
	Motion.tween(label, Motion.Normal, { TextTransparency = 0 })
end

function HUD.toast(text: string, color: Color3?)
	local list = gui.Toasts
	local rows = {}
	for _, c in list:GetChildren() do
		if c:IsA("GuiObject") then
			table.insert(rows, c)
		end
	end
	if #rows >= MAX_TOASTS then
		table.sort(rows, function(a, b)
			return a.LayoutOrder < b.LayoutOrder
		end)
		rows[1]:Destroy()
	end
	local row = Build.toast(text, color)
	row.LayoutOrder = math.floor(os.clock() * 1000) % 2e9
	row.BackgroundTransparency = 1
	row.Text.TextTransparency = 1
	row.Parent = list
	Sfx.play("Toast")
	local pop = row:FindFirstChild("Pop") :: UIScale?
	if pop then
		pop.Scale = 0.92
		Motion.tween(pop, Motion.Normal, { Scale = 1 })
	end
	Motion.tween(row, Motion.Normal, { BackgroundTransparency = Theme.HUD.InkTransparency })
	Motion.tween(row.Text, Motion.Normal, { TextTransparency = 0 })
	task.delay(4, function()
		if row.Parent then
			Motion.tween(row, Motion.Slow, { BackgroundTransparency = 1 })
			Motion.tween(row.Text, Motion.Slow, { TextTransparency = 1 }).Completed:Wait()
			row:Destroy()
		end
	end)
end

-- "Why can't I?": a red-edged toast with a short head-shake and the Error sound. The same reason twice in a
-- row (mashing a prompt) just shakes the existing toast again instead of stacking copies.
local lastRefuse: { text: string, row: Frame?, at: number } = { text = "", row = nil, at = 0 }
function HUD.refuse(text: string)
	local now = os.clock()
	local row = lastRefuse.row
	if not (text == lastRefuse.text and row and row.Parent and now - lastRefuse.at < 4) then
		HUD.toast(text, Theme.HUD.Danger)
		-- the newest row in the list is the one just made
		local newest: Frame? = nil
		for _, c in gui.Toasts:GetChildren() do
			if c:IsA("Frame") and (not newest or c.LayoutOrder > newest.LayoutOrder) then
				newest = c
			end
		end
		row = newest
	end
	lastRefuse = { text = text, row = row, at = now }
	pcall(function()
		require(ReplicatedStorage.MTL.UI.Sfx).play("Error")
	end)
	if row then
		local r = row :: Frame
		task.spawn(function()
			for _, x in { 8, -7, 5, -3, 0 } do
				r.Rotation = x * 0.25
				task.wait(0.035)
			end
		end)
	end
end

local function runBanners()
	if bannerBusy then
		return
	end
	bannerBusy = true
	while #bannerQueue > 0 do
		local item = table.remove(bannerQueue, 1) :: any
		local banner = gui.Banner
		banner.Title.Text = item.title
		banner.Title.TextColor3 = item.color or Theme.Colors.Gold
		banner.Sub.Text = item.sub or ""
		banner.Title.TextTransparency = 1
		banner.Sub.TextTransparency = 1
		-- a full-width band opens from a line, the title lands on it
		banner.Size = UDim2.new(1, 0, 0, 4)
		local rib = banner:FindFirstChild("Ribbon")
		if rib then
			rib.BackgroundTransparency = 0.3
		end
		banner.Visible = true
		Motion.tween(banner, TweenInfo.new(0.28, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), { Size = UDim2.new(1, 0, 0, 120) })
		Motion.tween(banner.Title, Motion.Fast, { TextTransparency = 0 })
		Motion.tween(banner.Sub, Motion.Normal, { TextTransparency = 0 })
		task.wait(2.2)
		Motion.tween(banner.Title, Motion.Normal, { TextTransparency = 1 })
		local rib = banner:FindFirstChild("Ribbon")
		if rib then
			Motion.tween(rib, Motion.Normal, { BackgroundTransparency = 1 })
		end
		Motion.tween(banner.Sub, Motion.Normal, { TextTransparency = 1 }).Completed:Wait()
		banner.Visible = false
		task.wait(0.2)
	end
	bannerBusy = false
end

-- key: a newer banner with the same key replaces any still waiting (a big XP jump shows only the latest level;
-- the skipped levels' unlock lines become toasts so nothing is lost)
function HUD.banner(title: string, sub: string?, color: Color3?, key: string?)
	if key then
		for i = #bannerQueue, 1, -1 do
			local q = bannerQueue[i]
			if q.key == key then
				table.remove(bannerQueue, i)
				if q.sub and q.sub ~= "" then
					HUD.toast(q.sub, q.color)
				end
			end
		end
	end
	table.insert(bannerQueue, { title = title, sub = sub, color = color, key = key })
	task.spawn(runBanners)
end

local function pop(text: string, color: Color3, delay: number)
	task.delay(delay, function()
		local label = Build.pop(text, color)
		label.Parent = gui.Pops
		label.TextTransparency = 1
		Motion.tween(label, Motion.Fast, { TextTransparency = 0 })
		Motion.tween(label, Motion.Slow, { Position = UDim2.new(1, 0, 0, -10) })
		task.wait(0.9)
		Motion.tween(label, Motion.Normal, { TextTransparency = 1 })
		task.wait(0.3)
		label:Destroy()
	end)
end

function HUD.init()
	gui = getGui()

	ClientData.Changed:Connect(function(data)
		task.spawn(render, data)
	end)
	if ClientData.get() then
		render(ClientData.get())
	end

	UIState.Changed:Connect(function(state)
		gui.Enabled = not state.hideHUD
	end)

	fitScale()
	if player.Character then
		task.spawn(watchHealth, player.Character)
	end
	player.CharacterAdded:Connect(watchHealth)

	local saved = player:GetAttribute("MTL_Objective")
	if type(saved) == "string" then
		task.spawn(HUD.objective, saved)
	end

	Net.get("Notify").OnClientEvent:Connect(function(msg)
		if type(msg) ~= "table" or type(msg.text) ~= "string" then
			return
		end
		if msg.kind == "objective" then
			task.spawn(HUD.objective, msg.text)
		elseif msg.kind == "refuse" then
			HUD.refuse(msg.text)
		elseif msg.kind == "banner" then
			HUD.banner(msg.text, msg.sub, msg.color)
		else
			HUD.toast(msg.text, msg.color)
		end
	end)

	Net.get("Reward").OnClientEvent:Connect(function(r)
		if type(r) ~= "table" then
			return
		end
		if r.cash then
			pop("+" .. Format.cash(r.cash), Theme.HUD.Money, 0)
		end
		if r.xp then
			pop("+" .. r.xp .. " XP", Theme.HUD.Paper, 0.12)
		end
	end)

	Net.get("LevelUp").OnClientEvent:Connect(function(info)
		if type(info) ~= "table" then
			return
		end
		local unlocks = info.unlocks or {}
		HUD.banner("LEVEL " .. tostring(info.level), unlocks[1], Theme.HUD.Gold, "level")
		if os.clock() - lastLevelSound > 1.5 then
			lastLevelSound = os.clock()
			Sfx.play("LevelUp") -- short "ding-up" (Theme.Sfx.LevelUp), not a music sting
		end
		for i = 2, #unlocks do
			HUD.toast(unlocks[i], Theme.Colors.Gold)
		end
	end)
end

return HUD
