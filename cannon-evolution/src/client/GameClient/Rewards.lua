--[[
	Rewards panel: 7-day Daily Rewards streak and Playtime gifts with timers.
]]

return function(ctx)
	local Kit, Config, State = ctx.Kit, ctx.Config, ctx.State
	local new = Kit.new

	local panel = Kit.panel({ Title = "Rewards", Icon = "Rewards", Size = UDim2.fromOffset(860, 500) })
	local body = panel.Body
	local content = new("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 52), Size = UDim2.new(1, 0, 1, -52), ZIndex = 22, Parent = body })

	local current = "Daily Rewards"
	local tick = nil -- per-second updater for the open tab

	-- Which day is next and whether it can be claimed now
	local function dailyState(data)
		local daily = data.Daily
		local now = State.ServerTime()
		local streak = daily.Streak
		if daily.LastClaim > 0 and now - daily.LastClaim > Config.DAILY_STREAK_RESET then
			streak = 0
		end
		local wait = Config.DAILY_COOLDOWN - (now - daily.LastClaim)
		return streak % #Config.DailyRewards + 1, wait <= 0, wait, streak
	end

	local function buildDaily()
		Kit.clear(content)
		local data = State.Data
		local nextDay, ready, _, streak = dailyState(data)
		local doneInCycle = streak % #Config.DailyRewards -- days already claimed this week
		local row = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 250), ZIndex = 23, Parent = content })
		Kit.list(row, 8, true)
		for i, r in ipairs(Config.DailyRewards) do
			local claimed = i <= doneInCycle
			local isNext = i == nextDay
			local big = i == #Config.DailyRewards
			local color = big and Kit.Colors.Purple or (isNext and Kit.Colors.Yellow or Kit.Colors.Card)
			local card = Kit.card({ Color = color, Size = UDim2.fromOffset(big and 150 or 100, 240), Order = i, Parent = row, ZIndex = 24 })
			if isNext and ready then
				Kit.movingPattern(card, { Lite = true, Texture = "Stripes", Speed = 30, ImageTransparency = 0.6, ZIndex = 24 })
				Kit.rainbowStroke(card, 3)
				Kit.shine(card, 2.5)
			elseif big then
				Kit.movingPattern(card, { Lite = true, Texture = "StudTile", Speed = 14, ImageTransparency = 0.75, ZIndex = 24 })
				Kit.sparkles(card, 4)
			end
			Kit.text({ Text = "Day " .. i, Size = 24, FrameSize = UDim2.new(1, 0, 0, 30), Position = UDim2.fromOffset(0, 6), ZIndex = 27, Parent = card })
			local icon = Kit.icon(r.Icon, { Size = UDim2.fromOffset(big and 100 or 70, big and 100 or 70), Position = UDim2.new(0.5, 0, 0, 100), Anchor = Vector2.new(0.5, 0.5), ZIndex = 26, Parent = card })
			if isNext then
				Kit.bob(icon, 4, 2.5)
			end
			Kit.text({ Text = r.Text, Size = 20, Scaled = true, MaxSize = 20, FrameSize = UDim2.new(1, -8, 0, 24), Position = UDim2.new(0.5, 0, 0, 160), Anchor = Vector2.new(0.5, 0), ZIndex = 27, Parent = card })
			if claimed then
				local shade = new("Frame", { BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.45, Size = UDim2.fromScale(1, 1), ZIndex = 30, Parent = card })
				Kit.corner(12, shade)
				Kit.text({ Text = "✔", Size = 60, Color = Kit.Colors.Green, ZIndex = 31, Parent = shade })
			end
		end
		local btn = Kit.button({ Text = "", Color = "Green", TextSize = 32, Size = UDim2.fromOffset(320, 66), Position = UDim2.new(0.5, 0, 1, -16), Anchor = Vector2.new(0.5, 1), ZIndex = 27, Parent = content, OnClick = function()
			ctx.Request("ClaimDaily")
		end })
		Kit.shine(btn.Instance, 3)
		Kit.text({ Text = "Come back every day for bigger rewards! Streak: " .. streak, Size = 20, FrameSize = UDim2.new(1, 0, 0, 24), Position = UDim2.new(0, 0, 1, -96), ZIndex = 26, Parent = content })
		tick = function()
			local _, ok, wait = dailyState(State.Data)
			if ok then
				btn:SetText("Claim Day " .. nextDay .. "!")
				btn:SetColor("Green")
			else
				btn:SetText("Next in " .. Config.FormatTime(wait))
				btn:SetColor("Gray")
			end
		end
	end

	local function buildPlaytime()
		Kit.clear(content)
		local grid = new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 23, Parent = content })
		Kit.grid(grid, UDim2.fromOffset(190, 170), 12)
		local items = {}
		for i, r in ipairs(Config.PlaytimeRewards) do
			local card = Kit.card({ Button = true, Color = Kit.Colors.Card, Order = i, Parent = grid, ZIndex = 24 })
			local icon = Kit.icon(r.Icon, { Size = UDim2.fromOffset(70, 70), Position = UDim2.new(0.5, 0, 0, 52), Anchor = Vector2.new(0.5, 0.5), ZIndex = 26, Parent = card })
			Kit.text({ Text = r.Text, Size = 22, FrameSize = UDim2.new(1, 0, 0, 26), Position = UDim2.fromOffset(0, 92), ZIndex = 27, Parent = card })
			local status = Kit.card({ Color = Kit.Colors.Gray, Size = UDim2.new(1, -16, 0, 34), Position = UDim2.new(0.5, 0, 1, -8), Anchor = Vector2.new(0.5, 1), Radius = 8, ZIndex = 26, Parent = card })
			local label = Kit.text({ Text = "", Size = 22, ZIndex = 28, Parent = status })
			card.Activated:Connect(function()
				Kit.playSound("Click")
				ctx.Request("ClaimPlaytime", i)
			end)
			items[i] = { Card = card, Status = status, Label = label, Icon = icon, Ready = false }
		end
		tick = function()
			local play = State.CurrentPlaytime()
			for i, r in ipairs(Config.PlaytimeRewards) do
				local it = items[i]
				local grad = it.Status:FindFirstChildOfClass("UIGradient")
				if State.PlaytimeClaimed[i] then
					it.Label.Text = "Claimed ✔"
					grad.Color = ColorSequence.new(Kit.Colors.Gray, Kit.Colors.GrayDark)
				elseif play >= r.Minutes * 60 then
					it.Label.Text = "CLAIM!"
					grad.Color = ColorSequence.new(Kit.Colors.Green, Kit.Colors.GreenDark)
					if not it.Ready then
						it.Ready = true
						Kit.bob(it.Icon, 4, 3)
						Kit.shine(it.Card, 2)
					end
				else
					it.Label.Text = Config.FormatTime(r.Minutes * 60 - play)
					grad.Color = ColorSequence.new(Kit.Colors.Blue, Kit.Colors.BlueDark)
				end
			end
		end
	end

	local acc = 0
	Kit.animate(content, function(dt)
		acc += dt
		if acc < 0.25 or not panel.Frame.Visible or not tick or not State.Data then
			return
		end
		acc = 0
		tick()
	end)

	local function build()
		if not State.Data then
			return
		end
		if current == "Daily Rewards" then
			buildDaily()
		else
			buildPlaytime()
		end
		tick()
	end

	local tabs = Kit.tabs({ Names = { "Daily Rewards", "Playtime" }, Parent = body, OnSelect = function(name)
		current = name
		build()
	end })

	local lastKey = ""
	return {
		Frame = panel.Frame,
		OnOpen = function(tab)
			tabs:Select(tab or current)
		end,
		Refresh = function()
			-- rebuild the daily row after a claim; playtime updates in tick()
			local data = State.Data
			if not data then
				return
			end
			local key = data.Daily.Streak .. ":" .. data.Daily.LastClaim
			if key ~= lastKey then
				lastKey = key
				if current == "Daily Rewards" then
					build()
				end
			end
		end,
	}
end
