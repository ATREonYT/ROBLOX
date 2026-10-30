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
	-- Big moments (rewards, UNLOCKED!, egg hatches) take turns: one that
	-- arrives while another is showing waits until that one is closed
	-----------------------------------------------------------------------
	local bigQueue, bigBusy = {}, false
	local function pumpBig()
		if bigBusy or #bigQueue == 0 then
			return
		end
		bigBusy = true
		local job = table.remove(bigQueue, 1)
		task.spawn(function()
			local released = false
			local function done()
				if not released then
					released = true
					task.delay(0.2, function()
						bigBusy = false
						pumpBig()
					end)
				end
			end
			local ok, err = pcall(job, done)
			if not ok then
				warn("Popup failed: " .. tostring(err))
				done()
			end
		end)
	end
	local function queueBig(job)
		table.insert(bigQueue, job)
		pumpBig()
	end

	-----------------------------------------------------------------------
	-- Reward popup ("You got...")
	-----------------------------------------------------------------------
	local function showRewards(done, list, title)
		local _, holder, closeModal = modal(640, 360)
		local function close()
			closeModal()
			done()
		end
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
	function Popups.Rewards(list, title)
		queueBig(function(done)
			showRewards(done, list, title)
		end)
	end
	Remotes.Rewarded.OnClientEvent:Connect(function(list)
		Popups.Rewards(list)
	end)

	-----------------------------------------------------------------------
	-- "UNLOCKED!" celebration after buying a gamepass or cannon
	-----------------------------------------------------------------------
	local function showUnlocked(done, title, icon, line)
		local shade, holder, closeModal = modal(620, 440)
		local function close()
			closeModal()
			done()
		end
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
		Kit.playSound("Unlock")
	end
	function Popups.Unlocked(title, icon, line)
		queueBig(function(done)
			showUnlocked(done, title, icon, line)
		end)
	end
	Remotes.Unlocked.OnClientEvent:Connect(Popups.Unlocked)

	-----------------------------------------------------------------------
	-- Egg hatch animation (vault "Reward Moments and Celebrations" +
	-- "Squash Stretch and Anticipation"): eggs drop in, three knocks that
	-- grow (wobble, squash, a crack each), a glow that only warms up when
	-- the pet inside really is rare (the server picked it before we play
	-- anything), a swell, the burst, pets pop out one after another. Rare
	-- pets add sparkles; Legendary and up dim the screen further and get a
	-- banner with confetti. Tap to skip once the pets are out. Hatches that
	-- arrive mid-animation wait their turn (queueBig) instead of being dropped.
	-----------------------------------------------------------------------
	local RARITY_WORD = { [5] = "LEGENDARY!", [6] = "MYTHIC!", [7] = "SECRET!" }

	local function shards(parent, color, count)
		for _ = 1, count do
			local bit = new("Frame", {
				BackgroundColor3 = math.random() < 0.35 and Color3.new(1, 1, 1) or color,
				BorderSizePixel = 0,
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.fromOffset(math.random(10, 18), math.random(12, 22)),
				Rotation = math.random(0, 360),
				ZIndex = 77,
				Parent = parent,
			})
			Kit.corner(4, bit)
			Kit.stroke(2, nil, bit)
			local a = math.random() * math.pi * 2
			local d = math.random(70, 140)
			local t = 0.45 + math.random() * 0.2
			Kit.tween(bit, t, { Position = UDim2.new(0.5, math.cos(a) * d, 0.5, math.sin(a) * d + 30), Rotation = bit.Rotation + math.random(-200, 200) }, Enum.EasingStyle.Quad)
			Kit.tween(bit, t, { BackgroundTransparency = 1 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
			task.delay(t + 0.05, function()
				bit:Destroy()
			end)
		end
	end

	local function playHatch(eggId, pets)
		local egg = Config.GetEgg(eggId)
		local count = #pets
		local cols = count <= 3 and count or (count <= 8 and 4 or 5)
		local rows = math.ceil(count / cols)
		local cellW = count == 1 and 300 or (count <= 3 and 230 or (count <= 8 and 170 or 150))
		local gap = 14
		local rowH = cellW + 60
		local width = cols * cellW + (cols - 1) * gap
		local shade, holder, close = modal(width, rows * rowH + 70)
		shade.Active = true
		local eggsFolder = ReplicatedStorage:FindFirstChild("Eggs")
		local eggModel = egg and eggsFolder and eggsFolder:FindFirstChild(egg.Model)
		local petsFolder = ReplicatedStorage:FindFirstChild("Pets")

		-- the best pet decides the size of the moment
		local best = 1
		for _, key in ipairs(pets) do
			local info = Config.Pets[key]
			best = math.max(best, info and Config.Rarities[info.Rarity].Order or 1)
		end

		local cells = {}
		for i, key in ipairs(pets) do
			local col = (i - 1) % cols
			local row = (i - 1) // cols
			-- centre a short last row
			local inRow = math.min(cols, count - row * cols)
			local x = col * (cellW + gap) + (cols - inRow) * (cellW + gap) / 2
			local cell = new("Frame", {
				BackgroundTransparency = 1,
				Size = UDim2.fromOffset(cellW, cellW),
				Position = UDim2.fromOffset(x, 60 + row * rowH),
				ZIndex = 72,
				Parent = holder,
			})
			local info = Config.Pets[key]
			local rarity = info and Config.Rarities[info.Rarity] or Config.Rarities.Common
			-- glow behind the egg: the honest tell
			local glow = new("Frame", {
				BackgroundColor3 = Color3.new(1, 1, 1),
				BackgroundTransparency = 1,
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.fromScale(0.75, 0.75),
				ZIndex = 72,
				Parent = cell,
			})
			Kit.corner(999, glow)
			-- the egg sits in its own frame so it can squash and stretch
			local body = new("Frame", {
				BackgroundTransparency = 1,
				AnchorPoint = Vector2.new(0.5, 1),
				Position = UDim2.fromScale(0.5, 0.92),
				Size = UDim2.fromScale(0.8, 0.84),
				ZIndex = 73,
				Parent = cell,
			})
			if eggModel then
				Kit.viewport(body, eggModel, { Size = UDim2.fromScale(1, 1), ZIndex = 73 })
			else
				Kit.text({ Text = "🥚", Scaled = true, Stroke = false, FrameSize = UDim2.fromScale(1, 1), Position = UDim2.fromScale(0.5, 0.5), Anchor = Vector2.new(0.5, 0.5), ZIndex = 73, Parent = body })
			end
			-- three cracks, one per knock
			local cracks = {}
			for k = 1, 3 do
				local crack = new("Frame", {
					BackgroundColor3 = Color3.new(1, 1, 1),
					BorderSizePixel = 0,
					AnchorPoint = Vector2.new(0.5, 0.5),
					Position = UDim2.fromScale(0.5 + (k - 2) * 0.1, 0.42 + (k % 2) * 0.1),
					Size = UDim2.new(0, 4, 0.12 + k * 0.04, 0),
					Rotation = ({ -35, 25, -10 })[k],
					BackgroundTransparency = 1,
					ZIndex = 74,
					Parent = body,
				})
				Kit.stroke(1.5, nil, crack)
				crack:FindFirstChildOfClass("UIStroke").Transparency = 1
				cracks[k] = crack
			end
			local s = Kit.scale(body)
			s.Scale = 0
			cells[i] = { Cell = cell, Body = body, Scale = s, Glow = glow, Cracks = cracks, Key = key, Info = info, Rarity = rarity }
		end

		-- 1. drop in
		for i, c in ipairs(cells) do
			task.delay((i - 1) * 0.04, function()
				Kit.tween(c.Scale, 0.3, { Scale = 1 }, Enum.EasingStyle.Back)
			end)
		end
		task.wait(0.3 + count * 0.04)

		-- 2. three knocks, each bigger; the glow warms only as far as the real result
		local tellColors = { Color3.new(1, 1, 1), Config.Rarities.Rare.Color }
		local function knock(k)
			Kit.playSound("Tab")
			local amp = ({ 10, 16, 24 })[k]
			for _, c in ipairs(cells) do
				-- squash on the hit, then stretch back
				c.Body.Size = UDim2.fromScale(0.9, 0.74)
				Kit.tween(c.Body, 0.22, { Size = UDim2.fromScale(0.8, 0.84) }, Enum.EasingStyle.Back)
				local crack = c.Cracks[k]
				crack.BackgroundTransparency = 0
				crack:FindFirstChildOfClass("UIStroke").Transparency = 0
				local order = c.Rarity.Order
				local color
				if k == 1 then
					color = tellColors[1]
				elseif k == 2 then
					color = order >= Config.Rarities.Rare.Order and tellColors[2] or tellColors[1]
				else
					color = order >= Config.Rarities.Epic.Order and c.Rarity.Color or (order >= Config.Rarities.Rare.Order and tellColors[2] or tellColors[1])
				end
				Kit.tween(c.Glow, 0.15, { BackgroundColor3 = color, BackgroundTransparency = 0.75 - k * 0.12 })
			end
			local t0 = os.clock()
			while os.clock() - t0 < 0.3 do
				local a = (os.clock() - t0) / 0.3
				for i, c in ipairs(cells) do
					c.Body.Rotation = math.sin(a * math.pi * 4 + i) * amp * (1 - a)
				end
				task.wait()
			end
			for _, c in ipairs(cells) do
				c.Body.Rotation = 0
			end
		end
		for k = 1, 3 do
			knock(k)
			task.wait(k < 3 and 0.18 or 0.1)
		end

		-- 3. swell, then burst (top tiers dim the screen first: that channel is kept for them)
		if best >= Config.Rarities.Legendary.Order then
			Kit.tween(shade, 0.25, { BackgroundTransparency = 0.15 })
		end
		for _, c in ipairs(cells) do
			Kit.tween(c.Scale, 0.14, { Scale = 1.25 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
			Kit.tween(c.Body, 0.14, { Size = UDim2.fromScale(0.74, 0.92) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		end
		task.wait(0.14)
		-- one flash only (kid-safe: at most one a second), softer unless it's a big one
		local flash = new("Frame", { BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = best >= Config.Rarities.Legendary.Order and 0 or 0.4, Size = UDim2.fromScale(1, 1), ZIndex = 90, Parent = shade })
		Kit.tween(flash, 0.45, { BackgroundTransparency = 1 })
		task.delay(0.45, function()
			flash:Destroy()
		end)
		Kit.playSound("Hatch")

		-- 4. pets pop out, one after another
		local eggColor = Color3.fromRGB(255, 240, 200)
		for i, c in ipairs(cells) do
			task.delay((i - 1) * 0.07, function()
				c.Body:Destroy()
				shards(c.Cell, eggColor, count > 3 and 6 or 10)
				local rarity, info = c.Rarity, c.Info
				Kit.tween(c.Glow, 0.3, { BackgroundColor3 = rarity.Color, BackgroundTransparency = 0.5 })
				Kit.rays(c.Cell, { Size = UDim2.fromScale(1.45, 1.45), Color = rarity.Color, Transparency = 0.35, Speed = rarity.Order >= 5 and 60 or 30, ZIndex = 72 })
				local petModel = petsFolder and petsFolder:FindFirstChild(c.Key)
				local view
				if petModel then
					-- facing the camera (no spin), so every pet in a big grid reads at a glance
					view = Kit.viewport(c.Cell, petModel, { Size = UDim2.fromScale(0.9, 0.9), ZIndex = 75 })
				else
					view = Kit.icon("Favorite", { Size = UDim2.fromScale(0.6, 0.6), Position = UDim2.fromScale(0.5, 0.5), Anchor = Vector2.new(0.5, 0.5), ZIndex = 75, Parent = c.Cell })
				end
				-- appears big, springs back (Elastic wobble for the top tiers)
				local vs = Kit.scale(view)
				vs.Scale = 1.35
				Kit.tween(vs, rarity.Order >= 5 and 0.6 or 0.35, { Scale = 1 }, rarity.Order >= 5 and Enum.EasingStyle.Elastic or Enum.EasingStyle.Back)
				if rarity.Order >= Config.Rarities.Rare.Order then
					Kit.sparkles(c.Cell, math.min(rarity.Order, 6), rarity.Color:Lerp(Color3.new(1, 1, 1), 0.4))
				end
				-- name and rarity slide up into place
				local small = count > 3
				local name = Kit.text({ Text = info and info.Name or c.Key, Size = small and 24 or 34, Scaled = true, MaxSize = small and 24 or 34, FrameSize = UDim2.new(1, 16, 0, small and 28 or 38), Position = UDim2.new(0.5, 0, 1, 14), Anchor = Vector2.new(0.5, 0), ZIndex = 78, Parent = c.Cell })
				local boost = info and ("  •  x" .. string.format("%.2f", 1 + info.Boost):gsub("%.?0+$", "")) or ""
				local tag = Kit.text({ Text = (info and info.Rarity or "") .. boost, Size = small and 17 or 22, Color = rarity.Order == 7 and Color3.new(1, 1, 1) or rarity.Color, FrameSize = UDim2.new(1, 16, 0, 24), Position = UDim2.new(0.5, 0, 1, (small and 30 or 40) + 14), Anchor = Vector2.new(0.5, 0), ZIndex = 78, Parent = c.Cell })
				if rarity.Order >= 6 then
					Kit.rainbowFill(new("UIGradient", { Parent = tag }))
				end
				for _, label in ipairs({ name, tag }) do
					local goal = label.Position - UDim2.fromOffset(0, 14)
					local stroke = label:FindFirstChildOfClass("UIStroke")
					label.TextTransparency = 1
					Kit.tween(label, 0.25, { Position = goal, TextTransparency = 0 }, Enum.EasingStyle.Back)
					if stroke then
						stroke.Transparency = 1
						Kit.tween(stroke, 0.25, { Transparency = 0 })
					end
				end
			end)
		end
		Kit.playSound("Coin")

		-- 5. the big moment: banner + confetti for Legendary and up
		local hold = count > 3 and 2.2 or 1.8
		if best >= Config.Rarities.Legendary.Order then
			hold = 3.4
			task.delay(0.25, function()
				local banner = Kit.text({ Text = RARITY_WORD[math.min(best, 7)], Size = 72, StrokeSize = 5, Color = Kit.Colors.Yellow, FrameSize = UDim2.new(1, 200, 0, 80), Position = UDim2.new(0.5, 0, 0, -40), Anchor = Vector2.new(0.5, 0), ZIndex = 80, Parent = holder })
				local g = new("UIGradient", { Rotation = 90, Parent = banner })
				if best >= 6 then
					Kit.rainbowFill(g)
				else
					g.Color = ColorSequence.new(Color3.fromRGB(255, 245, 140), Color3.fromRGB(255, 170, 20))
				end
				banner.Rotation = -4
				local bs = Kit.scale(banner)
				bs.Scale = 0
				Kit.tween(bs, 0.4, { Scale = 1 }, Enum.EasingStyle.Back)
				task.delay(0.4, function()
					Kit.animate(banner, function(_, t)
						bs.Scale = 1 + math.sin(t * 3) * 0.04
					end)
				end)
				Kit.confetti(shade, 70)
				Kit.playSound("Reward")
			end)
		end

		-- 6. settle: tap to skip once everything is out, otherwise close on its own
		local revealedAt = os.clock() + count * 0.07 + 0.35
		local hint = Kit.text({ Text = "Tap to continue", Size = 22, Stroke = false, Color = Color3.fromRGB(220, 220, 230), FrameSize = UDim2.new(1, 0, 0, 26), Position = UDim2.new(0.5, 0, 1, 34), Anchor = Vector2.new(0.5, 0), ZIndex = 78, Parent = holder })
		hint.TextTransparency = 1
		task.delay(revealedAt - os.clock() + 0.3, function()
			if hint.Parent then
				Kit.tween(hint, 0.3, { TextTransparency = 0.2 })
			end
		end)
		local done = Instance.new("BindableEvent")
		local finished = false
		local function finish()
			if not finished then
				finished = true
				done:Fire()
			end
		end
		shade.Activated:Connect(function()
			if os.clock() > revealedAt + 0.3 then
				finish()
			end
		end)
		task.delay(revealedAt - os.clock() + hold, finish)
		if not finished then
			done.Event:Wait()
		end
		done:Destroy()
		close()
		task.wait(0.2)
	end

	function Popups.Hatch(eggId, pets)
		queueBig(function(done)
			local ok, err = pcall(playHatch, eggId, pets)
			if not ok then
				warn("Hatch animation failed: " .. tostring(err))
			end
			done()
		end)
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
