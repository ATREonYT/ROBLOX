--[[
	Popups  (ModuleScript)
	Toast notifications, reward popups, the egg-hatch animation, offline
	earnings ("Welcome back") and "Before You Go!".
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = ReplicatedStorage:WaitForChild("Remotes")

return function(ctx)
	local Kit, Config, State = ctx.Kit, ctx.Config, ctx.State
	local new = Kit.new
	local Popups = {}

	local layer = new("Frame", {
		Name = "Popups",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 60,
		Parent = ctx.Root,
	})

	-----------------------------------------------------------------------
	-- Toasts (stack under the top bar)
	-----------------------------------------------------------------------
	local toasts = new("Frame", {
		Name = "Toasts",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 120),
		Size = UDim2.fromOffset(700, 300),
		ZIndex = 80,
		Parent = layer,
	})
	Kit.list(toasts, 4)

	function Popups.Notify(text, color)
		local label = Kit.text({
			Text = text,
			Size = 30,
			Color = color or Color3.new(1, 1, 1),
			FrameSize = UDim2.new(1, 0, 0, 38),
			ZIndex = 81,
			Parent = toasts,
		})
		-- in: pops up from small with an overshoot and a little tilt that settles; out: lifts and fades
		local s = Kit.scale(label)
		s.Scale = 0.4
		label.Rotation = -4
		Kit.tween(s, 0.3, { Scale = 1 }, Enum.EasingStyle.Back)
		Kit.tween(label, 0.4, { Rotation = 0 }, Enum.EasingStyle.Elastic)
		task.delay(2.6, function()
			Kit.tween(s, 0.3, { Scale = 0.85 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
			Kit.tween(label, 0.3, { TextTransparency = 1 })
			Kit.tween(label:FindFirstChildOfClass("UIStroke"), 0.3, { Transparency = 1 })
			task.wait(0.35)
			label:Destroy()
		end)
		if #toasts:GetChildren() > 6 then
			for _, c in ipairs(toasts:GetChildren()) do
				if c:IsA("TextLabel") then
					c:Destroy()
					break
				end
			end
		end
	end
	Remotes.Notify.OnClientEvent:Connect(Popups.Notify)

	-----------------------------------------------------------------------
	-- Modal helper (dark full-screen with a centred card)
	-----------------------------------------------------------------------
	local function modal(width, height)
		local shade = new("TextButton", {
			Text = "",
			AutoButtonColor = false,
			BackgroundColor3 = Color3.new(0, 0, 0),
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 1),
			ZIndex = 70,
			Parent = layer,
		})
		Kit.tween(shade, 0.25, { BackgroundTransparency = 0.45 })
		local holder = new("Frame", {
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(width, height),
			ZIndex = 71,
			Parent = shade,
		})
		local s = Kit.scale(holder)
		s.Scale = 0.5
		Kit.tween(s, 0.35, { Scale = 1 }, Enum.EasingStyle.Back)
		local function close()
			-- exit faster than the entrance, accelerating away, no overshoot (vault "UI Motion Language")
			Kit.tween(s, 0.14, { Scale = 0.6 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
			Kit.tween(shade, 0.2, { BackgroundTransparency = 1 })
			task.delay(0.2, function()
				shade:Destroy()
			end)
		end
		return shade, holder, close
	end

	local function okButton(parent, close, text)
		Kit.button({
			Text = text or "OK!",
			Color = "Green",
			Size = UDim2.fromOffset(240, 70),
			Position = UDim2.new(0.5, 0, 1, 0),
			Anchor = Vector2.new(0.5, 1),
			TextSize = 44,
			ZIndex = 75,
			Parent = parent,
			OnClick = close,
		})
	end

	-----------------------------------------------------------------------
	-- Reward popup ("You got...")
	-----------------------------------------------------------------------
	function Popups.Rewards(list, title)
		local _, holder, close = modal(640, 360)
		Kit.text({ Text = title or "You got!", Size = 60, Color = Kit.Colors.Yellow, FrameSize = UDim2.new(1, 0, 0, 70), ZIndex = 75, Parent = holder })
		local row = new("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 85), Size = UDim2.new(1, 0, 0, 180), ZIndex = 72, Parent = holder })
		Kit.list(row, 16, true)
		for i, item in ipairs(list) do
			local cell = new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromOffset(150, 180), LayoutOrder = i, ZIndex = 72, Parent = row })
			Kit.rays(cell, { Size = UDim2.fromOffset(220, 220), Position = UDim2.fromOffset(75, 70), Color = Kit.Colors.Yellow, ZIndex = 72 })
			local petModel = item.Pet and ReplicatedStorage:FindFirstChild("Pets") and ReplicatedStorage.Pets:FindFirstChild(item.Pet)
			if petModel then
				Kit.viewport(cell, petModel, { Size = UDim2.fromOffset(130, 130), Position = UDim2.fromOffset(75, 70), Spin = 40, ZIndex = 74 })
			else
				local icon = Kit.icon(item.Icon, { Size = UDim2.fromOffset(110, 110), Position = UDim2.fromOffset(75, 70), Anchor = Vector2.new(0.5, 0.5), ZIndex = 74, Parent = cell })
				Kit.bob(icon, 5, 2.5)
			end
			Kit.text({ Text = item.Text, Size = 24, Scaled = true, MaxSize = 26, FrameSize = UDim2.new(1, 20, 0, 40), Position = UDim2.new(0.5, 0, 1, 0), Anchor = Vector2.new(0.5, 1), ZIndex = 75, Parent = cell })
			-- each prize lands one after another (title first, prizes, then the button: vault "Reward Moments")
			local cs = Kit.scale(cell)
			cs.Scale = 0
			task.delay(0.15 + (i - 1) * 0.12, function()
				Kit.tween(cs, 0.35, { Scale = 1 }, Enum.EasingStyle.Back)
			end)
		end
		okButton(holder, close)
		Kit.playSound("Reward")
	end
	Remotes.Rewarded.OnClientEvent:Connect(function(list)
		Popups.Rewards(list)
	end)

	-----------------------------------------------------------------------
	-- "UNLOCKED!" celebration after buying a gamepass or cannon
	-----------------------------------------------------------------------
	function Popups.Unlocked(title, icon, line)
		local shade, holder, close = modal(620, 440)
		Kit.rays(holder, { Size = UDim2.fromOffset(560, 560), Position = UDim2.fromScale(0.5, 0.42), Color = Kit.Colors.Yellow, Transparency = 0.6, Speed = 35, ZIndex = 72 })
		Kit.rays(holder, { Size = UDim2.fromOffset(420, 420), Position = UDim2.fromScale(0.5, 0.42), Color = Color3.new(1, 1, 1), Transparency = 0.75, Speed = -20, ZIndex = 72 })
		local banner = Kit.text({ Text = "UNLOCKED!", Size = 72, StrokeSize = 5, Color = Kit.Colors.Yellow, FrameSize = UDim2.new(1, 0, 0, 80), ZIndex = 76, Parent = holder })
		new("UIGradient", { Color = ColorSequence.new(Color3.fromRGB(255, 245, 140), Color3.fromRGB(255, 170, 20)), Rotation = 90, Parent = banner })
		banner.Rotation = -4
		Kit.animate(banner, function(_, t)
			Kit.scale(banner).Scale = 1 + math.sin(t * 3) * 0.04
		end)
		local art = Kit.icon(icon or "Favorite", { Size = UDim2.fromOffset(170, 170), Position = UDim2.fromScale(0.5, 0.45), Anchor = Vector2.new(0.5, 0.5), ZIndex = 75, Parent = holder })
		local artScale = Kit.scale(art)
		artScale.Scale = 0
		Kit.tween(artScale, 0.55, { Scale = 1 }, Enum.EasingStyle.Back)
		task.delay(0.55, function()
			if art.Parent then
				Kit.bob(art, 6, 2)
			end
		end)
		Kit.sparkles(holder, 10, Kit.Colors.Yellow)
		Kit.text({ Text = title, Size = 44, Scaled = true, MaxSize = 46, FrameSize = UDim2.new(1, -40, 0, 50), Position = UDim2.new(0.5, 0, 1, -128), Anchor = Vector2.new(0.5, 1), ZIndex = 76, Parent = holder })
		if line and line ~= "" then
			Kit.text({ Text = line, Size = 26, Scaled = true, MaxSize = 26, Color = Color3.fromRGB(200, 255, 200), FrameSize = UDim2.new(1, -40, 0, 32), Position = UDim2.new(0.5, 0, 1, -92), Anchor = Vector2.new(0.5, 1), ZIndex = 76, Parent = holder })
		end
		okButton(holder, close, "AWESOME!")
		Kit.confetti(shade, 60)
		Kit.playSound("Reward")
	end
	Remotes.Unlocked.OnClientEvent:Connect(Popups.Unlocked)

	-----------------------------------------------------------------------
	-- Egg hatch animation
	-----------------------------------------------------------------------
	local hatching = false
	function Popups.Hatch(eggId, pets)
		if hatching then
			return
		end
		hatching = true
		local egg = Config.GetEgg(eggId)
		local count = #pets
		local cellW = count > 3 and 150 or 260
		local cols = math.min(count, 5)
		local rows = math.ceil(count / 5)
		local shade, holder, close = modal(cols * cellW + 40, rows * (cellW + 40) + 60)
		shade.Active = true
		local eggsFolder = ReplicatedStorage:FindFirstChild("Eggs")
		local eggModel = egg and eggsFolder and eggsFolder:FindFirstChild(egg.Model)
		local cells = {}
		for i = 1, count do
			local col = (i - 1) % 5
			local row = (i - 1) // 5
			local cell = new("Frame", {
				BackgroundTransparency = 1,
				Size = UDim2.fromOffset(cellW, cellW),
				Position = UDim2.fromOffset(20 + col * cellW, row * (cellW + 40)),
				ZIndex = 72,
				Parent = holder,
			})
			local eggView
			if eggModel then
				eggView = Kit.viewport(cell, eggModel, { Size = UDim2.fromScale(0.8, 0.8), ZIndex = 73 })
			else
				eggView = Kit.text({ Text = "🥚", Scaled = true, Stroke = false, FrameSize = UDim2.fromScale(0.7, 0.7), Position = UDim2.fromScale(0.5, 0.5), Anchor = Vector2.new(0.5, 0.5), ZIndex = 73, Parent = cell })
			end
			cells[i] = { Cell = cell, Egg = eggView }
		end
		-- shake harder and harder
		local t0 = os.clock()
		while os.clock() - t0 < 1.6 do
			local a = (os.clock() - t0) / 1.6
			for _, c in ipairs(cells) do
				c.Egg.Rotation = math.sin(os.clock() * (20 + a * 30)) * (6 + a * 18)
			end
			task.wait()
		end
		-- anticipation: the eggs swell for a beat, then burst (vault "Squash Stretch and Anticipation")
		for _, c in ipairs(cells) do
			c.Egg.Rotation = 0
			Kit.tween(Kit.scale(c.Egg), 0.12, { Scale = 1.25 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		end
		task.wait(0.12)
		-- flash
		local flash = new("Frame", { BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0, Size = UDim2.fromScale(1, 1), ZIndex = 90, Parent = shade })
		Kit.tween(flash, 0.5, { BackgroundTransparency = 1 })
		Kit.playSound("Hatch")
		task.delay(0.5, function()
			flash:Destroy()
		end)
		-- reveal pets
		local best = 0
		for i, key in ipairs(pets) do
			local c = cells[i]
			c.Egg:Destroy()
			local info = Config.Pets[key]
			local rarity = Config.Rarities[info.Rarity]
			best = math.max(best, rarity.Order)
			Kit.rays(c.Cell, { Size = UDim2.fromScale(1.5, 1.5), Color = rarity.Color, Transparency = 0.4, ZIndex = 72 })
			local petModel = ReplicatedStorage:FindFirstChild("Pets") and ReplicatedStorage.Pets:FindFirstChild(key)
			local view
			if petModel then
				view = Kit.viewport(c.Cell, petModel, { Size = UDim2.fromScale(0.85, 0.85), Spin = 50, ZIndex = 74 })
			else
				view = Kit.icon("Favorite", { Size = UDim2.fromScale(0.6, 0.6), Position = UDim2.fromScale(0.5, 0.5), Anchor = Vector2.new(0.5, 0.5), ZIndex = 74, Parent = c.Cell })
			end
			Kit.pop(view, 0.3)
			Kit.text({ Text = info.Name, Size = count > 3 and 22 or 34, FrameSize = UDim2.new(1, 20, 0, 34), Position = UDim2.new(0.5, 0, 1, -4), Anchor = Vector2.new(0.5, 0), ZIndex = 76, Parent = c.Cell })
			Kit.text({ Text = info.Rarity .. "  •  x" .. string.format("%.2f", 1 + info.Boost):gsub("%.?0+$", ""), Size = count > 3 and 16 or 22, Color = rarity.Color, FrameSize = UDim2.new(1, 20, 0, 24), Position = UDim2.new(0.5, 0, 1, 28), Anchor = Vector2.new(0.5, 0), ZIndex = 76, Parent = c.Cell })
		end
		if best >= Config.Rarities.Legendary.Order then
			Popups.Notify("🌟 WOW! A " .. (best >= 7 and "SECRET" or best >= 6 and "MYTHIC" or "LEGENDARY") .. " pet!", Kit.Colors.Yellow)
		end
		task.wait(2.2)
		close()
		hatching = false
	end
	Remotes.Hatched.OnClientEvent:Connect(Popups.Hatch)

	-----------------------------------------------------------------------
	-- Offline earnings + Before You Go
	-----------------------------------------------------------------------
	-- Big stat popups (Welcome Back, Before You Go) wait their turn so they never stack
	local statQueue, statBusy = {}, false
	local function nextStat()
		if statBusy or #statQueue == 0 then
			return
		end
		statBusy = true
		local job = table.remove(statQueue, 1)
		local title, titleColor, subtitle, columns = job[1], job[2], job[3], job[4]
		local _, holder, closeModal = modal(760, 540)
		local function close()
			closeModal()
			task.delay(0.25, function()
				statBusy = false
				nextStat()
			end)
		end
		-- toy card: hard shadow, navy body, yellow header strip, thick ink outline
		local shadow = new("Frame", {
			BackgroundColor3 = Kit.Colors.Outline,
			BackgroundTransparency = 0.35,
			Size = UDim2.new(1, 0, 1, -40),
			Position = UDim2.fromOffset(0, 48),
			ZIndex = 71,
			Parent = holder,
		})
		Kit.corner(22, shadow)
		local card = new("Frame", {
			BackgroundColor3 = Kit.Colors.Body,
			Size = UDim2.new(1, 0, 1, -40),
			Position = UDim2.fromOffset(0, 40),
			ZIndex = 72,
			Parent = holder,
		})
		Kit.corner(22, card)
		Kit.stroke(5, nil, card)
		Kit.gradient(Kit.Colors.Body, Kit.Colors.BodyDark, card)
		local header = new("Frame", {
			BackgroundColor3 = Color3.new(1, 1, 1),
			Size = UDim2.new(1, 0, 0, 96),
			ZIndex = 73,
			Parent = card,
		})
		Kit.corner(22, header)
		Kit.gradient(Kit.Colors.HeaderTop, Kit.Colors.HeaderBottom, header)
		Kit.text({ Text = title, Size = 68, StrokeSize = 5, Color = titleColor, FrameSize = UDim2.new(1, 0, 0, 96), Position = UDim2.fromOffset(0, -46), ZIndex = 76, Parent = card })
		Kit.text({ Text = subtitle, Size = 34, FrameSize = UDim2.new(1, 0, 0, 44), Position = UDim2.fromOffset(0, 46), ZIndex = 76, Parent = card })
		for i, col in ipairs(columns) do
			local x = #columns == 1 and 0.5 or (i == 1 and 0.27 or 0.73)
			Kit.text({ Text = col.Top, Size = 32, Color = Kit.Colors.Yellow, FrameSize = UDim2.fromOffset(340, 40), Position = UDim2.new(x, 0, 0, 112), Anchor = Vector2.new(0.5, 0), ZIndex = 75, Parent = card })
			Kit.rays(card, { Size = UDim2.fromOffset(220, 220), Position = UDim2.new(x, 0, 0, 236), Color = Kit.Colors.Yellow, Transparency = 0.7, ZIndex = 73 })
			local icon = Kit.icon(col.Icon, { Size = UDim2.fromOffset(130, 130), Position = UDim2.new(x, 0, 0, 236), Anchor = Vector2.new(0.5, 0.5), ZIndex = 74, Parent = card })
			Kit.bob(icon, 6, 2)
			Kit.text({ Text = col.Bottom, Size = 38, FrameSize = UDim2.fromOffset(340, 46), Position = UDim2.new(x, 0, 0, 310), Anchor = Vector2.new(0.5, 0), ZIndex = 75, Parent = card })
		end
		okButton(holder, close)
	end
	local function bigStatPopup(title, titleColor, subtitle, columns)
		table.insert(statQueue, { title, titleColor, subtitle, columns })
		nextStat()
	end

	Remotes.OfflineEarnings.OnClientEvent:Connect(function(power, seconds)
		bigStatPopup("Welcome Back!", Kit.Colors.Green, "You were away for " .. Config.FormatTime(seconds), {
			{ Top = "WHILE OFFLINE", Icon = "Muscle", Bottom = "+" .. Config.Format(power) .. " Power" },
		})
	end)

	local lastBeforeYouGo = 0
	function Popups.BeforeYouGo()
		if os.clock() - lastBeforeYouGo < 60 or not State.Data then
			return
		end
		lastBeforeYouGo = os.clock()
		local data = State.Data
		local offline = Config.PowerPerMinute(data, State.Passes.VIP) * 60 * Config.OFFLINE_MAX_HOURS * Config.OFFLINE_RATE
		local day = data.Daily.Streak % #Config.DailyRewards + 1
		local nextDaily = Config.DailyRewards[day]
		bigStatPopup("Before You Go!", Color3.fromRGB(255, 70, 70), "You earn Power while offline!", {
			{ Top = "IN " .. Config.OFFLINE_MAX_HOURS .. " HOURS", Icon = "Muscle", Bottom = "+" .. Config.Format(offline) .. " Power" },
			{ Top = "TOMORROW", Icon = nextDaily.Icon, Bottom = nextDaily.Text },
		})
	end

	-----------------------------------------------------------------------
	-- Launch result banner
	-----------------------------------------------------------------------
	Remotes.LaunchResult.OnClientEvent:Connect(function(distance, cash, gems, isBest)
		local text = Config.Format(distance) .. " m!  +$" .. Config.Format(cash)
		if gems > 0 then
			text ..= "  +" .. gems .. " Gems"
		end
		if isBest then
			text = "NEW BEST! " .. text
		end
		Popups.Notify(text, isBest and Kit.Colors.Yellow or Color3.new(1, 1, 1))
	end)

	return Popups
end
