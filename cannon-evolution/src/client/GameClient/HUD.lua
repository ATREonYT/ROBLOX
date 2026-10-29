--[[
	HUD  (ModuleScript)
	Top bar (menu buttons, Power / Cash / Gems, Leaderboard, Settings),
	side buttons, training banner, active boost timers and badges.
]]

return function(ctx)
	local Kit, Config, State = ctx.Kit, ctx.Config, ctx.State
	local new = Kit.new

	local hud = new("Frame", { Name = "HUD", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 5, Parent = ctx.Root })

	-----------------------------------------------------------------------
	-- Top-left menu buttons
	-----------------------------------------------------------------------
	local left = new("Frame", { Name = "Menu", BackgroundTransparency = 1, Position = UDim2.fromOffset(12, 10), Size = UDim2.fromOffset(450, 84), Parent = hud })
	Kit.list(left, 10, true, Enum.HorizontalAlignment.Left)
	local badges = {}
	local menu = {
		{ "Shop", "Shop", "Shop" },
		{ "Rebirth", "Rebirth", "Rebirth" },
		{ "Rewards", "Rewards", "Rewards" },
		{ "Inventory", "Backpack", "Pets", "Pets" },
		{ "Worlds", "World", "Worlds" },
		{ "Missions", "Missions", "Missions" },
	}
	for i, m in ipairs(menu) do
		local btn = Kit.menuButton({ Text = m[1], Icon = m[2], Size = UDim2.fromOffset(64, 70), Order = i, Parent = left, OnClick = function()
			ctx.Toggle(m[3], m[4])
		end })
		badges[m[1]] = Kit.badge(btn)
	end
	-- Shop always has a rainbow "!" to draw the eye
	badges.Shop:Set("!")
	Kit.rainbowStroke(left.Shop.Badge, 2.5)

	-----------------------------------------------------------------------
	-- Currencies (top centre)
	-----------------------------------------------------------------------
	local currencies = new("Frame", { Name = "Currencies", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 133, 0, 14), Size = UDim2.fromOffset(600, 70), Parent = hud })
	Kit.list(currencies, 18, true)
	local amounts = {}
	local function currency(name, icon, order, onPlus)
		local holder = new("Frame", { Name = name, BackgroundTransparency = 1, Size = UDim2.fromOffset(185, 70), LayoutOrder = order, Parent = currencies })
		local pill = new("Frame", { BackgroundColor3 = Kit.Colors.BodyDark, BackgroundTransparency = 0.15, Position = UDim2.fromOffset(22, 6), Size = UDim2.fromOffset(160, 40), Parent = holder })
		Kit.corner(12, pill)
		Kit.stroke(3, nil, pill)
		local amount = Kit.text({ Text = "0", Size = 28, FrameSize = UDim2.new(1, -60, 1, 0), Position = UDim2.fromOffset(26, 0), ZIndex = 3, Parent = pill })
		Kit.icon(icon, { Size = UDim2.fromOffset(52, 52), Position = UDim2.fromOffset(0, 0), ZIndex = 4, Parent = holder })
		Kit.text({ Text = name, Size = 18, FrameSize = UDim2.fromOffset(160, 20), Position = UDim2.fromOffset(22, 48), ZIndex = 3, Parent = holder })
		local plus = Kit.button({ Text = "+", Color = "Green", Size = UDim2.fromOffset(34, 34), Position = UDim2.new(1, -4, 0, 3), Anchor = Vector2.new(1, 0), TextSize = 30, Radius = 8, ZIndex = 4, Parent = pill, OnClick = onPlus })
		Kit.shine(plus.Instance, 4)
		amounts[name] = amount
	end
	currency("Power", "Power", 1, function()
		ctx.Open("Shop", "Boosts")
	end)
	currency("Cash", "Cash", 2, function()
		ctx.Open("Shop", "Cash")
	end)
	currency("Gems", "Gem", 3, function()
		ctx.Open("Shop", "Gems")
	end)

	-----------------------------------------------------------------------
	-- Top-right: Leaderboard + Settings
	-----------------------------------------------------------------------
	local right = new("Frame", { Name = "Right", BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -12, 0, 10), Size = UDim2.fromOffset(170, 84), Parent = hud })
	Kit.list(right, 6, true, Enum.HorizontalAlignment.Right)
	Kit.menuButton({ Text = "Leaderboard", Icon = "Trophy", Order = 1, Parent = right, OnClick = function()
		ctx.Toggle("Leaderboard")
	end })
	Kit.menuButton({ Text = "Settings", Icon = "Settings", Order = 2, Parent = right, OnClick = function()
		ctx.Toggle("Settings")
	end })

	-----------------------------------------------------------------------
	-- Left side: Cannons, Eggs, Upgrades, Auto Launch (like the reference)
	-----------------------------------------------------------------------
	local side = new("Frame", { Name = "Side", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 12, 0.5, 20), Size = UDim2.fromOffset(190, 330), Parent = hud })
	local sideGrid = Kit.grid(side, UDim2.fromOffset(88, 88), 8)
	sideGrid.HorizontalAlignment = Enum.HorizontalAlignment.Left
	local function sideButton(text, icon, color, order, onClick)
		local card = Kit.card({ Button = true, Color = color, Order = order, Parent = side, ZIndex = 5 })
		Kit.movingPattern(card, { Lite = true, Texture = "StudTile", Speed = 12, ImageTransparency = 0.75, ZIndex = 5, Radius = 12 })
		local ic = Kit.icon(icon, { Size = UDim2.fromScale(0.72, 0.72), Position = UDim2.fromScale(0.5, 0.42), Anchor = Vector2.new(0.5, 0.5), ZIndex = 7, Parent = card })
		Kit.text({ Text = text, Size = 20, Scaled = true, MaxSize = 20, FrameSize = UDim2.new(1, -6, 0.3, 0), Position = UDim2.new(0.5, 0, 1, -2), Anchor = Vector2.new(0.5, 1), ZIndex = 8, Parent = card })
		local s = Kit.scale(card)
		card.MouseEnter:Connect(function()
			Kit.tween(s, 0.12, { Scale = 1.07 })
			Kit.tween(ic, 0.12, { Rotation = -8 })
		end)
		card.MouseLeave:Connect(function()
			Kit.tween(s, 0.12, { Scale = 1 })
			Kit.tween(ic, 0.12, { Rotation = 0 })
		end)
		card.Activated:Connect(function()
			Kit.playSound("Click")
			Kit.pop(card, 0.9)
			onClick()
		end)
		return card
	end
	sideButton("Cannons", "Evolve", Kit.Colors.Blue, 1, function()
		ctx.Toggle("Cannons")
	end)
	sideButton("Eggs", "StarterCrate", Kit.Colors.Purple, 2, function()
		ctx.Toggle("Pets", "Eggs")
	end)
	sideButton("Upgrades", "Arrow", Kit.Colors.Yellow, 3, function()
		ctx.Toggle("Upgrades")
	end)
	local autoCard = sideButton("Auto Launch", "Trophy", Kit.Colors.Gray, 4, function()
		ctx.Request("SetAutoLaunch", not State.AutoLaunch)
	end)
	local autoGrad = autoCard:FindFirstChildOfClass("UIGradient")

	-----------------------------------------------------------------------
	-- Bottom: training banner + boost timers
	-----------------------------------------------------------------------
	local trainingBar = new("Frame", { Name = "Training", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -20), Size = UDim2.fromOffset(460, 100), BackgroundColor3 = Color3.new(1, 1, 1), Visible = false, Parent = hud })
	Kit.corner(16, trainingBar)
	Kit.stroke(4, nil, trainingBar)
	Kit.gradient(Kit.Colors.Blue, Kit.Colors.BlueDark, trainingBar)
	Kit.movingPattern(trainingBar, { Texture = "Stripes", Speed = 30, ImageTransparency = 0.6, Radius = 16 })
	local trainingTitle = Kit.text({ Text = "", Size = 28, FrameSize = UDim2.new(1, -20, 0, 40), Position = UDim2.fromOffset(10, 4), ZIndex = 3, Parent = trainingBar })
	Kit.button({ Text = "Leave (Jump)", Color = "Red", Size = UDim2.fromOffset(210, 42), Position = UDim2.new(0.5, 0, 1, -8), Anchor = Vector2.new(0.5, 1), ZIndex = 3, Parent = trainingBar, OnClick = function()
		ctx.Request("StopTraining")
	end })

	function ctx.OnTrainingChanged(stationId)
		if stationId and State.Data then
			local info = Config.Stations[stationId]
			trainingTitle.Text = "Training at the " .. info.Name
			trainingBar.Visible = true
			Kit.pop(trainingBar)
		else
			trainingBar.Visible = false
		end
	end

	local boostRow = new("Frame", { Name = "Boosts", BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -14, 1, -14), Size = UDim2.fromOffset(400, 70), Parent = hud })
	Kit.list(boostRow, 8, true, Enum.HorizontalAlignment.Right)
	local boostCells = {}
	for i, b in ipairs({ { "Power", "PotionRed" }, { "Cash", "PotionGold" }, { "Luck", "Lucky" } }) do
		local cell = new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromOffset(70, 70), LayoutOrder = i, Visible = false, Parent = boostRow })
		Kit.icon(b[2], { Size = UDim2.fromScale(0.8, 0.8), Position = UDim2.fromScale(0.5, 0.4), Anchor = Vector2.new(0.5, 0.5), Parent = cell })
		local label = Kit.text({ Text = "", Size = 18, FrameSize = UDim2.new(1, 10, 0, 20), Position = UDim2.new(0.5, 0, 1, 0), Anchor = Vector2.new(0.5, 1), ZIndex = 3, Parent = cell })
		Kit.text({ Text = "2x", Size = 18, Color = Kit.Colors.Yellow, FrameSize = UDim2.fromOffset(30, 20), Position = UDim2.fromOffset(44, 0), ZIndex = 3, Parent = cell })
		boostCells[b[1]] = { Cell = cell, Label = label }
	end

	-----------------------------------------------------------------------
	-- Refresh
	-----------------------------------------------------------------------
	local shown = { Power = 0, Cash = 0, Gems = 0 }
	local function countUp(name, value)
		local from = shown[name]
		shown[name] = value
		if value > from then
			Kit.pop(amounts[name].Parent, 1.06)
		end
		amounts[name].Text = Config.Format(value)
	end

	local function claimableRewards(data)
		local n = 0
		if State.ServerTime() - data.Daily.LastClaim >= Config.DAILY_COOLDOWN then
			n += 1
		end
		local play = State.CurrentPlaytime()
		for i, r in ipairs(Config.PlaytimeRewards) do
			if not State.PlaytimeClaimed[i] and play >= r.Minutes * 60 then
				n += 1
			end
		end
		return n
	end

	local function claimableMissions(data)
		local n = 0
		local m = data.Missions
		local function stat(s)
			return s == "Distance" and data.BestDistance or (data.Stats[s] or 0)
		end
		for _, cat in ipairs({ "Daily", "Weekly" }) do
			for _, def in ipairs(Config.Missions[cat]) do
				local st = m[cat][def.Id]
				if st and not st.Claimed and stat(def.Stat) - st.Base >= def.Goal then
					n += 1
				end
			end
		end
		for _, def in ipairs(Config.Missions.Infinite) do
			local st = m.Infinite[def.Id]
			if st and stat(def.Stat) - st.Base >= math.floor(def.Goal * def.GoalGrowth ^ (st.Tier - 1)) then
				n += 1
			end
		end
		return n
	end

	local function refresh()
		local data = State.Data
		if not data then
			return
		end
		countUp("Power", data.Power)
		countUp("Cash", data.Cash)
		countUp("Gems", data.Gems)

		local powerCost, cashCost = Config.RebirthCost(data.Rebirths)
		local pct = math.floor(math.min(data.Power / powerCost, data.Cash / cashCost, 1) * 100)
		badges.Rebirth:Set(pct >= 100 and "!" or (pct > 0 and pct .. "%" or nil))

		local rewards = claimableRewards(data)
		badges.Rewards:Set(rewards > 0 and tostring(rewards) or nil)
		local missions = claimableMissions(data)
		badges.Missions:Set(missions > 0 and tostring(missions) or nil)

		for id, cell in pairs(boostCells) do
			local left = data.Boosts[id] or 0
			cell.Cell.Visible = left > 0
			cell.Label.Text = Config.FormatTime(left)
		end
		local on = State.AutoLaunch
		autoGrad.Color = on and ColorSequence.new(Kit.Colors.Green, Kit.Colors.GreenDark) or ColorSequence.new(Kit.Colors.Gray, Kit.Colors.GrayDark)
	end
	State.Changed:Connect(refresh)
	-- playtime badge ticks without server syncs
	task.spawn(function()
		while true do
			task.wait(5)
			refresh()
		end
	end)
end
