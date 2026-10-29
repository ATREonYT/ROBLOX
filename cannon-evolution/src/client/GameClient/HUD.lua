--[[
	HUD  (ModuleScript)
	Stone Skipping layout: Shop and menu grid on the left, Rebirths / Cash /
	Gems bottom left, Power bar and Power packs bottom centre, Auto Launch on
	top, pass cards on the right, round buttons top right, training banner,
	boost timers and badges.
]]

return function(ctx)
	local Kit, Config, State = ctx.Kit, ctx.Config, ctx.State
	local new = Kit.new

	local hud = new("Frame", { Name = "HUD", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 5, Parent = ctx.Root })

	-----------------------------------------------------------------------
	-- Layout copied from Stone Skipping (references/stone-skipping-hud.png):
	-- Shop + a 2-wide grid of square buttons on the left, Rebirths / Cash /
	-- Gems stacked bottom left, Power bar + Power packs bottom centre,
	-- Auto Launch on top, pass cards on the right, small round buttons top right.
	-----------------------------------------------------------------------
	local badges = {}

	-- Left column (Effects hides "Side" during a launch, Tutorial finds "Menu")
	local side = new("Frame", { Name = "Side", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 14, 0.5, 10), Size = UDim2.fromOffset(188, 350), Parent = hud })
	local left = new("Frame", { Name = "Menu", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Parent = side })

	-- "ONLY [R$] 25" style price: a small Robux icon in front of the number
	local function robuxPrice(parent, text, size, color, props)
		local row = new("Frame", { Name = "Price", BackgroundTransparency = 1, AnchorPoint = props.Anchor or Vector2.new(0.5, 0), Position = props.Position, Size = UDim2.fromOffset(0, size + 4), AutomaticSize = Enum.AutomaticSize.X, ZIndex = 8, Parent = parent })
		local list = Kit.list(row, 3, true, Enum.HorizontalAlignment.Center)
		list.VerticalAlignment = Enum.VerticalAlignment.Center
		if props.Prefix then
			local pre = Kit.text({ Text = props.Prefix, Size = size, Color = color, Order = 1, ZIndex = 8, Parent = row })
			pre.AutomaticSize = Enum.AutomaticSize.X
			pre.Size = UDim2.new(0, 0, 1, 0)
		end
		Kit.icon("Robux", { Size = UDim2.fromOffset(size, size), Order = 2, ZIndex = 9, Parent = row })
		local label = Kit.text({ Text = text, Size = size, Color = color, Order = 3, ZIndex = 8, Parent = row })
		label.AutomaticSize = Enum.AutomaticSize.X
		label.Size = UDim2.new(0, 0, 1, 0)
		return label
	end

	local function pressable(btn, icon)
		local s = Kit.scale(btn)
		btn.MouseEnter:Connect(function()
			Kit.tween(s, 0.12, { Scale = 1.07 })
			if icon then
				Kit.tween(icon, 0.12, { Rotation = -8 })
			end
		end)
		btn.MouseLeave:Connect(function()
			Kit.tween(s, 0.12, { Scale = 1 })
			if icon then
				Kit.tween(icon, 0.12, { Rotation = 0 })
			end
		end)
	end

	local shopBtn = Kit.card({ Button = true, Name = "Shop", Color = Kit.Colors.Yellow, Color2 = Kit.Colors.YellowDark, Size = UDim2.fromOffset(180, 58), ZIndex = 5, StrokeSize = 4, Parent = left })
	Kit.movingPattern(shopBtn, { Lite = true, Texture = "StudTile", Speed = 0, ImageTransparency = 0.8, ZIndex = 5, Radius = 12 })
	local shopIcon = Kit.icon("Shop", { Size = UDim2.fromOffset(66, 66), Position = UDim2.new(0, -6, 0.5, 0), Anchor = Vector2.new(0, 0.5), Rotation = -8, ZIndex = 7, Parent = shopBtn })
	Kit.text({ Text = "Shop", Size = 34, StrokeSize = 3.5, AlignX = Enum.TextXAlignment.Left, FrameSize = UDim2.new(1, -70, 1, 0), Position = UDim2.fromOffset(66, -1), ZIndex = 8, Parent = shopBtn })
	pressable(shopBtn, shopIcon)
	shopBtn.Activated:Connect(function()
		Kit.playSound("Click")
		Kit.pop(shopBtn, 0.9)
		ctx.Toggle("Shop")
	end)
	badges.Shop = Kit.badge(shopBtn)

	local grid = {
		{ "Rebirth", "Rebirth", "Rebirth" },
		{ "Cannons", "Cannon", "Cannons" },
		{ "Eggs", "StarterCrate", "Pets", "Eggs" },
		{ "Upgrades", "Evolve", "Upgrades" },
		{ "Inventory", "Backpack", "Pets", "Pets" },
		{ "Worlds", "World", "Worlds" },
	}
	for i, m in ipairs(grid) do
		local col, row = (i - 1) % 2, math.floor((i - 1) / 2)
		local card = Kit.card({ Button = true, Name = m[1], Color = Color3.fromRGB(70, 78, 98), Color2 = Color3.fromRGB(38, 44, 60), Size = UDim2.fromOffset(86, 86), Position = UDim2.fromOffset(col * 94, 66 + row * 94), ZIndex = 5, StrokeSize = 4, Parent = left })
		local ic = Kit.icon(m[2], { Size = UDim2.fromScale(0.8, 0.8), Position = UDim2.fromScale(0.5, 0.4), Anchor = Vector2.new(0.5, 0.5), ZIndex = 7, Parent = card })
		Kit.text({ Text = m[1], Size = 21, Scaled = true, MaxSize = 21, FrameSize = UDim2.new(1, -4, 0.3, 0), Position = UDim2.new(0.5, 0, 1, -1), Anchor = Vector2.new(0.5, 1), ZIndex = 8, Parent = card })
		pressable(card, ic)
		card.Activated:Connect(function()
			Kit.playSound("Click")
			Kit.pop(card, 0.9)
			ctx.Toggle(m[3], m[4])
		end)
		badges[m[1]] = Kit.badge(card)
	end
	-- Shop always has a rainbow "!" to draw the eye
	badges.Shop:Set("!")
	Kit.rainbowStroke(shopBtn.Badge, 2.5)

	-----------------------------------------------------------------------
	-- Top right: small round buttons
	-----------------------------------------------------------------------
	local right = new("Frame", { Name = "Right", BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -14, 0, 12), Size = UDim2.fromOffset(280, 64), Parent = hud })
	Kit.list(right, 10, true, Enum.HorizontalAlignment.Right)
	local function roundButton(name, icon, order, onClick)
		local b = new("ImageButton", { Name = name, BackgroundColor3 = Color3.fromRGB(20, 24, 34), BackgroundTransparency = 0.1, Size = UDim2.fromOffset(60, 60), LayoutOrder = order, Parent = right })
		Kit.corner(30, b)
		Kit.stroke(3, nil, b)
		local ic = Kit.icon(icon, { Size = UDim2.fromScale(0.72, 0.72), Position = UDim2.fromScale(0.5, 0.5), Anchor = Vector2.new(0.5, 0.5), ZIndex = 3, Parent = b })
		pressable(b, ic)
		b.Activated:Connect(function()
			Kit.playSound("Click")
			Kit.pop(b, 0.85)
			onClick()
		end)
		return b
	end
	badges.Rewards = Kit.badge(roundButton("Rewards", "Rewards", 1, function()
		ctx.Toggle("Rewards")
	end))
	badges.Missions = Kit.badge(roundButton("Missions", "Missions", 2, function()
		ctx.Toggle("Missions")
	end))
	roundButton("Leaderboard", "Trophy", 3, function()
		ctx.Toggle("Leaderboard")
	end)
	roundButton("Settings", "Settings", 4, function()
		ctx.Toggle("Settings")
	end)

	-----------------------------------------------------------------------
	-- Top centre: Auto Launch (buys the pass, then works as an on/off switch)
	-----------------------------------------------------------------------
	local autoBtn = Kit.card({ Button = true, Name = "AutoLaunch", Color = Kit.Colors.Red, Color2 = Kit.Colors.RedDark, Size = UDim2.fromOffset(270, 76), Position = UDim2.new(0.5, 0, 0, 12), Anchor = Vector2.new(0.5, 0), ZIndex = 5, StrokeSize = 4, Parent = hud })
	Kit.movingPattern(autoBtn, { Lite = true, Texture = "StudTile", Speed = 0, ImageTransparency = 0.8, ZIndex = 5, Radius = 12 })
	local autoGrad = autoBtn:FindFirstChildOfClass("UIGradient")
	Kit.text({ Text = "AUTO LAUNCH", Size = 34, StrokeSize = 3.5, FrameSize = UDim2.new(1, 0, 0, 40), Position = UDim2.fromOffset(0, 4), ZIndex = 8, Parent = autoBtn })
	local autoSub = Kit.text({ Text = "", Size = 24, Color = Kit.Colors.Yellow, FrameSize = UDim2.new(1, 0, 0, 26), Position = UDim2.fromOffset(0, 44), ZIndex = 8, Parent = autoBtn })
	local autoPrice = robuxPrice(autoBtn, tostring(Config.Passes.AutoLaunch.Price), 24, Kit.Colors.Yellow, { Prefix = "ONLY", Position = UDim2.new(0.5, 0, 0, 42) })
	pressable(autoBtn)
	autoBtn.Activated:Connect(function()
		Kit.playSound("Click")
		Kit.pop(autoBtn, 0.92)
		ctx.Request("SetAutoLaunch", not State.AutoLaunch)
	end)

	-----------------------------------------------------------------------
	-- Right side: pass cards (hidden once owned)
	-----------------------------------------------------------------------
	local promos = new("Frame", { Name = "Promos", BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -14, 0.5, 30), Size = UDim2.fromOffset(200, 300), Parent = hud })
	Kit.list(promos, 10, false, Enum.HorizontalAlignment.Right)
	local promoCards = {}
	for i, key in ipairs({ "DoublePower", "DoubleCash" }) do
		local pass = Config.Passes[key]
		local card = Kit.card({ Button = true, Name = key, Color = Color3.fromRGB(190, 240, 70), Color2 = Color3.fromRGB(110, 190, 20), Size = UDim2.fromOffset(196, 96), Order = i, ZIndex = 5, StrokeSize = 4, Parent = promos })
		if key == "DoubleCash" then
			card:FindFirstChildOfClass("UIGradient").Color = ColorSequence.new(Color3.fromRGB(255, 230, 110), Color3.fromRGB(230, 170, 20))
		end
		Kit.movingPattern(card, { Lite = true, Texture = "StudTile", Speed = 0, ImageTransparency = 0.8, ZIndex = 5, Radius = 12 })
		Kit.icon(pass.Icon, { Size = UDim2.fromOffset(64, 64), Position = UDim2.new(0, -14, 0.5, 0), Anchor = Vector2.new(0, 0.5), Rotation = -12, ZIndex = 9, Parent = card })
		Kit.text({ Text = string.upper(pass.Name), Size = 30, StrokeSize = 3.5, Scaled = true, MaxSize = 30, FrameSize = UDim2.new(1, -54, 0, 38), Position = UDim2.fromOffset(48, 8), ZIndex = 8, Parent = card })
		robuxPrice(card, tostring(pass.Price), 24, Kit.Colors.Yellow, { Prefix = "ONLY", Position = UDim2.new(0.5, 24, 0, 54) })
		pressable(card)
		card.Activated:Connect(function()
			Kit.playSound("Click")
			Kit.pop(card, 0.92)
			ctx.Request("Purchase", "Pass", key)
		end)
		promoCards[key] = card
	end

	-----------------------------------------------------------------------
	-- Bottom left: Rebirths, Cash, Gems
	-----------------------------------------------------------------------
	local stack = new("Frame", { Name = "Currencies", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 18, 1, -14), Size = UDim2.fromOffset(260, 200), Parent = hud })
	local stackList = Kit.list(stack, 4, false, Enum.HorizontalAlignment.Left)
	stackList.VerticalAlignment = Enum.VerticalAlignment.Bottom
	local amounts = {}
	local function currency(name, icon, order, onPlus)
		local row = new("Frame", { Name = name, BackgroundTransparency = 1, Size = UDim2.fromOffset(260, 60), LayoutOrder = order, Parent = stack })
		Kit.icon(icon, { Size = UDim2.fromOffset(60, 60), ZIndex = 4, Parent = row })
		local amount = Kit.text({ Text = "0", Size = 46, StrokeSize = 4, AlignX = Enum.TextXAlignment.Left, FrameSize = UDim2.new(1, -110, 1, 0), Position = UDim2.fromOffset(68, 0), ZIndex = 3, Parent = row })
		amount.AutomaticSize = Enum.AutomaticSize.X
		amount.Size = UDim2.new(0, 0, 1, 0)
		if onPlus then
			local plus = Kit.button({ Text = "+", Color = "Green", Size = UDim2.fromOffset(32, 32), Position = UDim2.new(1, 8, 0.5, 0), Anchor = Vector2.new(0, 0.5), TextSize = 28, Radius = 8, ZIndex = 4, Parent = amount, OnClick = onPlus })
			Kit.shine(plus.Instance, 4)
		end
		amounts[name] = amount
	end
	currency("Rebirths", "Rebirth", 1)
	currency("Cash", "Cash", 2, function()
		ctx.Open("Shop", "Cash")
	end)
	currency("Gems", "Gem", 3, function()
		ctx.Open("Shop", "Gems")
	end)

	-----------------------------------------------------------------------
	-- Bottom centre: Power, multiplier, rebirth bar and Power packs
	-----------------------------------------------------------------------
	local bottom = new("Frame", { Name = "PowerBar", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -12), Size = UDim2.fromOffset(700, 178), Parent = hud })
	local powerIcon = Kit.icon("Power", { Size = UDim2.fromOffset(44, 44), Position = UDim2.fromOffset(0, 0), ZIndex = 4, Parent = bottom })
	powerIcon.Rotation = -10
	amounts.Power = Kit.text({ Text = "0 POWER", Size = 32, StrokeSize = 3.5, Color = Color3.fromRGB(255, 236, 120), AlignX = Enum.TextXAlignment.Left, FrameSize = UDim2.new(0.6, -48, 0, 40), Position = UDim2.fromOffset(48, 2), ZIndex = 3, Parent = bottom })
	local multText = Kit.text({ Text = "", Size = 32, StrokeSize = 3.5, Color = Color3.fromRGB(255, 236, 120), AlignX = Enum.TextXAlignment.Right, FrameSize = UDim2.new(0.4, 0, 0, 40), Position = UDim2.new(1, 0, 0, 2), Anchor = Vector2.new(1, 0), ZIndex = 3, Parent = bottom })

	local barBack = new("Frame", { Name = "Bar", BackgroundColor3 = Color3.fromRGB(225, 232, 245), Position = UDim2.fromOffset(0, 44), Size = UDim2.new(1, 0, 0, 58), ZIndex = 3, Parent = bottom })
	Kit.corner(12, barBack)
	Kit.stroke(4, nil, barBack)
	Kit.movingPattern(barBack, { Lite = true, Texture = "StudTile", Speed = 0, ImageTransparency = 0.85, ZIndex = 3, Radius = 12 })
	local barFill = new("Frame", { Name = "Fill", BackgroundColor3 = Color3.new(1, 1, 1), Size = UDim2.fromScale(0, 1), ZIndex = 4, Parent = barBack })
	Kit.corner(12, barFill)
	Kit.gradient(Color3.fromRGB(70, 170, 255), Color3.fromRGB(20, 90, 220), barFill)
	local barLeft = Kit.text({ Text = "", Size = 36, StrokeSize = 3.5, AlignX = Enum.TextXAlignment.Left, FrameSize = UDim2.new(0.5, -16, 1, 0), Position = UDim2.fromOffset(16, -1), ZIndex = 6, Parent = barBack })
	local barRight = Kit.text({ Text = "", Size = 30, StrokeSize = 3.5, AlignX = Enum.TextXAlignment.Right, FrameSize = UDim2.new(0.5, -16, 1, 0), Position = UDim2.new(1, -16, 0, -1), Anchor = Vector2.new(1, 0), ZIndex = 6, Parent = barBack })

	local packs = {}
	local packColors = {
		{ Kit.Colors.Yellow, Kit.Colors.YellowDark },
		{ Kit.Colors.Red, Kit.Colors.RedDark },
		{ Kit.Colors.Purple, Kit.Colors.PurpleDark },
	}
	for i, key in ipairs({ "PowerPack1", "PowerPack2", "PowerPack3" }) do
		local product = Config.Products[key]
		local card, grad = Kit.card({ Button = true, Name = key, Color = packColors[i][1], Color2 = packColors[i][2], Size = UDim2.new(1 / 3, -6, 0, 66), Position = UDim2.new((i - 1) / 3, (i - 1) * 3, 0, 110), ZIndex = 5, StrokeSize = 4, Parent = bottom })
		if i == 3 then
			Kit.rainbowFill(grad)
		end
		Kit.movingPattern(card, { Lite = true, Texture = "StudTile", Speed = 0, ImageTransparency = 0.8, ZIndex = 5, Radius = 12 })
		Kit.icon("Power", { Size = UDim2.fromOffset(54, 54), Position = UDim2.fromScale(0.5, 0.45), Anchor = Vector2.new(0.5, 0.5), Rotation = 20, ZIndex = 6, Parent = card })
		local label = Kit.text({ Text = "", Size = 40, StrokeSize = 4, FrameSize = UDim2.new(1, 0, 1, -8), ZIndex = 8, Parent = card })
		robuxPrice(card, tostring(product.Price), 20, Color3.fromRGB(130, 255, 130), { Position = UDim2.new(1, -6, 1, 8), Anchor = Vector2.new(1, 1) })
		pressable(card)
		card.Activated:Connect(function()
			Kit.playSound("Click")
			Kit.pop(card, 0.92)
			ctx.Request("Purchase", "Product", key)
		end)
		packs[key] = label
	end

	-----------------------------------------------------------------------
	-- Training banner (sits above the Power bar) + boost timers
	-----------------------------------------------------------------------
	local trainingBar = new("Frame", { Name = "Training", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -206), Size = UDim2.fromOffset(460, 100), BackgroundColor3 = Color3.new(1, 1, 1), Visible = false, Parent = hud })
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

	local boostRow = new("Frame", { Name = "Boosts", BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -14, 1, -14), Size = UDim2.fromOffset(240, 70), Parent = hud })
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
	local shown = { Power = 0, Cash = 0, Gems = 0, Rebirths = 0 }
	local function countUp(name, value, suffix)
		local from = shown[name]
		shown[name] = value
		if value > from then
			Kit.pop(amounts[name], 1.06)
		end
		amounts[name].Text = Config.Format(value) .. (suffix or "")
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
		countUp("Power", data.Power, " POWER")
		countUp("Cash", data.Cash)
		countUp("Gems", data.Gems)
		countUp("Rebirths", data.Rebirths)

		local powerCost, cashCost = Config.RebirthCost(data.Rebirths)
		local pct = math.floor(math.min(data.Power / powerCost, data.Cash / cashCost, 1) * 100)
		badges.Rebirth:Set(pct >= 100 and "!" or (pct > 0 and pct .. "%" or nil))

		-- bottom bar: progress towards the next rebirth's Power
		local alpha = math.clamp(data.Power / powerCost, 0, 1)
		barFill.Size = UDim2.fromScale(alpha, 1)
		barFill.Visible = alpha > 0.01
		barLeft.Text = "Rebirth " .. (data.Rebirths + 1)
		barRight.Text = Config.Format(data.Power) .. " / " .. Config.Format(powerCost)
		multText.Text = "x" .. (math.floor(Config.PowerMultiplier(data) * 10) / 10) .. " Multiplier"
		-- what each pack gives right now (the server grants at least this)
		local perMinute = Config.PowerPerMinute(data, false)
		for key, label in pairs(packs) do
			label.Text = "+" .. Config.Format(perMinute * Config.Products[key].Grant.PowerMinutes)
		end
		for key, card in pairs(promoCards) do
			card.Visible = State.Passes[key] ~= true
		end
		local owned = State.Passes.AutoLaunch == true
		autoSub.Text = owned and (State.AutoLaunch and "ON" or "OFF") or ""
		autoPrice.Parent.Visible = not owned

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
		autoGrad.Color = on and ColorSequence.new(Kit.Colors.Green, Kit.Colors.GreenDark) or ColorSequence.new(Kit.Colors.Red, Kit.Colors.RedDark)
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
