--[[
	Round HUD, laid out like Huss Valley's: at the top centre "ROUND 01", one big message line (the latest
	thing that happened: "Messi reached safety!" in green, "Sabtwinl was caught by Danilo!" in red...),
	and under it your role and the time left ("RUNNER · 0:23"), plus the "in a row" pips (everyone across
	3 rounds in a row wins). Big moments (3-2-1-GO, wins) also show in the middle of the screen. The prize
	card (top left) shows the girl, her rarity and who has her. Faint outlines show every player's side:
	catchers red, runners blue, the Hero yellow, safe runners green.
	Fonts: Luckiest Guy for big words, Fredoka One for lines. Laid out at 1280 x 720 and scaled.
]]
local M = {}

function M.start()
	local Players = game:GetService("Players")
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local RunService = game:GetService("RunService")
	local TweenService = game:GetService("TweenService")
	local TextService = game:GetService("TextService")
	local Workspace = game:GetService("Workspace")

	local Shared = ReplicatedStorage:WaitForChild("Shared")
	local Net = require(Shared.Net)
	local Config = require(Shared.Config.Round)

	local player = Players.LocalPlayer
	local RoundNet = Net.get("Round") :: RemoteEvent
	local State = RoundNet -- the round state is this remote's attributes

	local DISPLAY = Font.new("rbxasset://fonts/families/LuckiestGuy.json") -- (Theme.Fonts.Display)
	local ROUND = Font.new("rbxasset://fonts/families/FredokaOne.json") -- (Theme.Fonts.Round)
	local INK = Color3.fromRGB(16, 14, 38) -- outlines and shadows
	local GLASS = Color3.fromRGB(20, 22, 52)
	local RED = Color3.fromRGB(255, 96, 96)
	local GOLD = Color3.fromRGB(255, 205, 80)
	local GREEN = Color3.fromRGB(110, 236, 140)
	local BLUE = Color3.fromRGB(110, 184, 255)
	local MUTED = Color3.fromRGB(196, 200, 226)
	local WHITE = Color3.new(1, 1, 1)

	local rarityColor = {}
	for _, r in Config.Rarities do
		rarityColor[r.Name] = r.Color
	end
	rarityColor.Secret = Color3.fromRGB(150, 110, 255) -- (near-black in the roller; violet reads on the dark card)

	local function make(class, props, children)
		local item = Instance.new(class)
		for k, v in props do
			item[k] = v
		end
		for _, child in children or {} do
			child.Parent = item
		end
		return item
	end
	local function corner(r)
		return make("UICorner", { CornerRadius = if r >= 1 then UDim.new(0, r) else UDim.new(r, 0) })
	end
	local function rim(t, color, transparency)
		return make("UIStroke", { Thickness = t, Color = color or INK, Transparency = transparency or 0, ApplyStrokeMode = Enum.ApplyStrokeMode.Border })
	end
	local function gradient(top, bottom)
		return make("UIGradient", { Rotation = 90, Color = ColorSequence.new(top, bottom) })
	end
	-- Text with a dark outline (and an optional top-to-bottom shine). Fixed sizes: the whole HUD scales together.
	local function text(props, outline, shine)
		props.BackgroundTransparency = 1
		props.TextColor3 = props.TextColor3 or WHITE
		props.TextWrapped = props.TextWrapped or false
		local kids = { make("UIStroke", { Name = "Outline", Thickness = outline or 2, Color = INK, LineJoinMode = Enum.LineJoinMode.Round }) }
		if shine then
			table.insert(kids, make("UIGradient", { Name = "Shine", Rotation = 90, Color = ColorSequence.new(WHITE, shine) }))
		end
		return make("TextLabel", props, kids)
	end

	local gui = make("ScreenGui", { Name = "HuzzRoundHud", ResetOnSpawn = false, IgnoreGuiInset = false, DisplayOrder = 5 })
	-- Everything is laid out for a 1280 x 720 screen and scaled to yours (from the top centre).
	local root = make("Frame", { Name = "Root", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0), Size = UDim2.fromOffset(1280, 720), BackgroundTransparency = 1, Parent = gui })
	local fit = make("UIScale", { Name = "Fit", Parent = root })
	local function refit()
		local cam = Workspace.CurrentCamera
		local size = cam and cam.ViewportSize or Vector2.new(1280, 720)
		local preview = Workspace:GetAttribute("UIPreviewScale") -- (the offline preview: its pages are 768 wide)
		fit.Scale = if type(preview) == "number" then preview * 768 / 1280 else math.clamp(math.min(size.X / 1280, size.Y / 720), 0.55, 1.6)
	end
	refit()

	-- Top centre: ROUND 01, the message line, your role and time, the streak.
	local top = make("Frame", { Name = "Top", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromOffset(640, 4), Size = UDim2.fromOffset(1000, 120), BackgroundTransparency = 1, Parent = root })
	local roundLabel = text({ Name = "Round", Position = UDim2.fromOffset(0, 0), Size = UDim2.new(1, 0, 0, 18), FontFace = ROUND, TextSize = 15, TextColor3 = MUTED, Text = "" }, 1.5)
	roundLabel.Parent = top
	local message = text({ Name = "Message", Position = UDim2.fromOffset(0, 18), Size = UDim2.new(1, 0, 0, 34), FontFace = DISPLAY, TextSize = 26, Text = "" }, 2.5)
	message.Parent = top
	local sub = text({ Name = "Sub", Position = UDim2.fromOffset(0, 54), Size = UDim2.new(1, 0, 0, 18), FontFace = ROUND, TextSize = 15, TextColor3 = MUTED, RichText = true, Text = "" }, 1.2)
	sub.Parent = top
	local pips = make("Frame", { Name = "Streak", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromOffset(500, 75), Size = UDim2.fromOffset(160, 16), BackgroundTransparency = 1, Parent = top }, {
		make("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center, VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	local pipLabel = text({ Name = "Label", Size = UDim2.fromOffset(78, 18), FontFace = ROUND, TextSize = 13, TextColor3 = MUTED, Text = "IN A ROW", LayoutOrder = 0 }, 1.2)
	pipLabel.Parent = pips
	local pipDots = {}
	for i = 1, 5 do
		pipDots[i] = make("Frame", { Name = "Pip" .. i, Size = UDim2.fromOffset(12, 12), BackgroundColor3 = GOLD, LayoutOrder = i, Visible = false, Parent = pips }, { corner(0.5), rim(1.5, INK, 0.1) })
	end

	-- Prize card, top left: her picture, her name and rarity, and who has her.
	local card = make("Frame", {
		Name = "Prize", Position = UDim2.fromOffset(176, 10), Size = UDim2.fromOffset(250, 76), BackgroundColor3 = WHITE, Visible = false, Parent = root, -- (right of the lobby's side buttons)
	}, { corner(14), gradient(Color3.fromRGB(40, 38, 92), GLASS) })
	local cardRim = rim(2.5, GOLD, 0.15)
	cardRim.Parent = card
	local glow = make("Frame", { Name = "Glow", Size = UDim2.fromScale(1, 1), BackgroundColor3 = GOLD, Parent = card }, {
		corner(14), make("UIGradient", { Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(0.45, 1), NumberSequenceKeypoint.new(1, 1) }) }),
	})
	local portrait = make("ViewportFrame", { Name = "Portrait", Position = UDim2.fromOffset(7, 7), Size = UDim2.fromOffset(62, 62), BackgroundColor3 = Color3.fromRGB(26, 24, 60), Ambient = Color3.fromRGB(170, 170, 190), LightDirection = Vector3.new(-0.4, -1, -0.6), Parent = card }, { corner(12) })
	local portraitRim = rim(2, GOLD, 0.2)
	portraitRim.Parent = portrait
	local rarityChip = make("TextLabel", { Name = "Rarity", Position = UDim2.fromOffset(80, 7), Size = UDim2.fromOffset(0, 18), AutomaticSize = Enum.AutomaticSize.X, BackgroundColor3 = GOLD, FontFace = DISPLAY, TextSize = 13, TextColor3 = INK, Text = "", Parent = card },
		{ corner(0.5), make("UIPadding", { PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8), PaddingTop = UDim.new(0, 2) }) })
	local girlName = text({ Name = "GirlName", Position = UDim2.fromOffset(80, 27), Size = UDim2.new(1, -88, 0, 24), FontFace = DISPLAY, TextSize = 22, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, Parent = card }, 2.5, Color3.fromRGB(255, 226, 150))
	local holder = text({ Name = "Holder", Position = UDim2.fromOffset(80, 52), Size = UDim2.new(1, -88, 0, 18), FontFace = ROUND, TextSize = 14, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, Parent = card }, 1.5)

	-- Big centre messages: a chunky shining word with a soft drop shadow.
	local function bannerLabel(name, y, w, h, size, outline)
		local shadow = make("TextLabel", {
			Name = name .. "Shadow", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(640, y + 4), Size = UDim2.fromOffset(w, h),
			BackgroundTransparency = 1, FontFace = DISPLAY, TextSize = size, TextWrapped = true, TextColor3 = INK, TextTransparency = 1, Text = "", Parent = root,
		})
		local label = text({
			Name = name, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(640, y), Size = UDim2.fromOffset(w, h),
			FontFace = DISPLAY, TextSize = size, TextWrapped = true, Text = "", TextTransparency = 1, Parent = root,
		}, outline)
		local shine = make("UIGradient", { Name = "Shine", Rotation = 90, Parent = label })
		return { label = label, stroke = label:FindFirstChild("Outline"), shadow = shadow, shine = shine, size = size }
	end
	local banner = bannerLabel("Banner", 250, 900, 130, 52, 4)
	local small = bannerLabel("Small", 330, 700, 44, 28, 2.5)
	local flash = make("Frame", { Name = "Flash", Size = UDim2.fromScale(1, 1), BackgroundColor3 = RED, BackgroundTransparency = 1, ZIndex = 0, Parent = gui })

	gui.Parent = player:WaitForChild("PlayerGui")
	local cam = Workspace.CurrentCamera
	if cam then
		cam:GetPropertyChangedSignal("ViewportSize"):Connect(refit)
	end

	local function show(b, msg, color, hold, textSize)
		local label = b.label
		local c = color or WHITE
		label.Text, b.shadow.Text = msg, msg
		label.TextColor3 = WHITE
		-- white at the top shading into the message colour
		b.shine.Color = ColorSequence.new(WHITE:Lerp(c, 0.25), c)
		local size = textSize or b.size
		label.TextTransparency, b.stroke.Transparency, b.shadow.TextTransparency = 0, 0, 0.55
		label.TextSize, b.shadow.TextSize = math.round(size * 1.25), math.round(size * 1.25)
		TweenService:Create(label, TweenInfo.new(0.3, Enum.EasingStyle.Back), { TextSize = size }):Play()
		TweenService:Create(b.shadow, TweenInfo.new(0.3, Enum.EasingStyle.Back), { TextSize = size }):Play()
		local token = {}
		label:SetAttribute("Token", tostring(token))
		task.delay(hold or 2.6, function()
			if label:GetAttribute("Token") == tostring(token) then
				local info = TweenInfo.new(0.4)
				TweenService:Create(label, info, { TextTransparency = 1 }):Play()
				TweenService:Create(b.stroke, info, { Transparency = 1 }):Play()
				TweenService:Create(b.shadow, info, { TextTransparency = 1 }):Play()
			end
		end)
	end

	-- The top message line: the latest message stays (as in Huss Valley), popping in when it changes.
	local function setMessage(msg, color)
		message.Text = msg
		message.TextColor3 = color or WHITE
		message.TextSize = 31
		TweenService:Create(message, TweenInfo.new(0.28, Enum.EasingStyle.Back), { TextSize = 26 }):Play()
	end

	local function nameOf(id)
		local p = id and id ~= 0 and Players:GetPlayerByUserId(id)
		return p and p.DisplayName
	end

	local ROLE_COLOR = { RUNNER = BLUE, CATCHER = RED, HERO = GOLD, SAFE = GREEN, DOWN = Color3.fromRGB(255, 160, 90), CARRYING = Color3.fromRGB(255, 150, 200), WATCHING = MUTED }
	local TIMED = { HeroRun = true, Running = true, Picking = true }
	local lastCount
	local function refresh()
		local stage = State:GetAttribute("Stage") or "Waiting"
		local now = Workspace:GetServerTimeNow()
		local left = math.max(0, (State:GetAttribute("EndsAt") or 0) - now)
		local inGame = (State:GetAttribute("Round") or 0) > 0 and stage ~= "Waiting" and stage ~= "Voting" and stage ~= "Intermission" and stage ~= "Rolling"
		top.Visible = inGame
		if inGame then
			roundLabel.Text = string.format("ROUND %02d", State:GetAttribute("Round") or 0)
			local myRole, myStatus = player:GetAttribute("HuzzRole"), player:GetAttribute("HuzzStatus")
			local holding = State:GetAttribute("HolderId") == player.UserId
			local word, line
			if myRole == "Catcher" then
				word = "CATCHER"
				line = if holding then "she's following you" else nil
			elseif myRole == "Runner" then
				if myStatus == "Downed" then
					word, line = "DOWN", "a runner can rescue you"
				elseif myStatus == "Safe" then
					word, line = "SAFE", "you made it"
				elseif player:GetAttribute("HuzzHero") then
					word, line = "HERO", "cross alone"
				elseif holding then
					word, line = "CARRYING", "get her across"
				else
					word = "RUNNER"
				end
			else
				word, line = "WATCHING", "you're in the next game"
			end
			local c = ROLE_COLOR[word] or WHITE
			local parts = { string.format('<font color="#%02X%02X%02X">%s</font>', math.round(c.R * 255), math.round(c.G * 255), math.round(c.B * 255), word) }
			if line then table.insert(parts, line) end
			if TIMED[stage] then
				local secs = math.ceil(left)
				table.insert(parts, string.format("%d:%02d", secs // 60, secs % 60))
			end
			sub.Text = table.concat(parts, "  ·  ")
			-- in a row: filled pips for crossings done, hollow for the ones still to go
			local goal = State:GetAttribute("Crossings") or Config.Crossings
			local streak = State:GetAttribute("Streak") or 0
			for i, dot in pipDots do
				dot.Visible = i <= goal
				dot.BackgroundColor3 = if i <= streak then GOLD else INK
				dot.BackgroundTransparency = if i <= streak then 0 else 0.35
			end
		end

		if stage == "Countdown" then
			local count = math.ceil(left)
			if count ~= lastCount and count > 0 then
				show(banner, tostring(count), Color3.fromRGB(255, 226, 120), 0.8, 104)
			end
			lastCount = count
		elseif lastCount and stage == "Running" then
			lastCount = nil
			show(banner, "GO!", GREEN, 0.9, 110)
		end
	end
	RunService.RenderStepped:Connect(refresh)
	M.refresh = refresh -- (the offline preview calls it)

	-- Prize card
	local girls = ReplicatedStorage:FindFirstChild("HuzzGirls")
	local shownModel = false -- (false = not drawn yet)
	local function setPortrait(name)
		girls = girls or ReplicatedStorage:FindFirstChild("HuzzGirls")
		local model
		for _, m in if girls then girls:GetChildren() else {} do
			if m:GetAttribute("Name") == name then
				model = m
				break
			end
		end
		if model == shownModel then
			return
		end
		shownModel = model
		for _, ch in portrait:GetChildren() do
			if ch:IsA("Model") or ch:IsA("Camera") then
				ch:Destroy()
			end
		end
		portrait.Visible = model ~= nil
		local x = if model then 80 else 16
		rarityChip.Position = UDim2.fromOffset(x, 7)
		girlName.Position, holder.Position = UDim2.fromOffset(x, 27), UDim2.fromOffset(x, 52)
		girlName.Size, holder.Size = UDim2.new(1, -x - 8, 0, 24), UDim2.new(1, -x - 8, 0, 18)
		if not model then
			return
		end
		local copy = model:Clone()
		copy.Parent = portrait
		local head = copy:FindFirstChild("Head", true)
		local camera = make("Camera", { FieldOfView = 30, Parent = portrait })
		portrait.CurrentCamera = camera
		if head and head:IsA("BasePart") then
			local at = head.CFrame.Position - Vector3.new(0, 0.3, 0)
			local look = head.CFrame.LookVector
			camera.CFrame = CFrame.lookAt(at + look * 5 + Vector3.new(0, 0.4, 0), at)
		end
	end
	local function refreshCard()
		local girl = State:GetAttribute("GirlName") or ""
		card.Visible = girl ~= ""
		local rarity = State:GetAttribute("GirlRarity") or ""
		local color = rarityColor[rarity] or GOLD
		cardRim.Color, portraitRim.Color, glow.BackgroundColor3, rarityChip.BackgroundColor3 = color, color, color, color
		rarityChip.Text = string.upper(rarity)
		rarityChip.TextColor3 = if color.R * 0.3 + color.G * 0.59 + color.B * 0.11 > 0.55 then INK else WHITE
		girlName.Text = girl
		local who = nameOf(State:GetAttribute("HolderId"))
		holder.Text = if who then `With {who}` else "A Hero who makes it wins her"
		holder.TextColor3 = if who then GOLD else MUTED
		setPortrait(girl)
	end
	for _, name in { "GirlName", "GirlRarity", "HolderId" } do
		State:GetAttributeChangedSignal(name):Connect(refreshCard)
	end
	refreshCard()

	-- Outlines (as in the reference): a faint red line round catchers, blue round runners still out,
	-- yellow round the Hero, green round runners safe across the line. Downed runners lose theirs.
	local OUTLINE_RED = Color3.fromRGB(255, 64, 64)
	local OUTLINE_BLUE = Color3.fromRGB(64, 150, 255)
	local OUTLINE_GREEN = Color3.fromRGB(70, 230, 120)
	local OUTLINE_YELLOW = Color3.fromRGB(255, 214, 70)
	local highlights = {}
	local function refreshHighlight(p)
		local character = p.Character
		local r, st = p:GetAttribute("HuzzRole"), p:GetAttribute("HuzzStatus")
		local color = if r == "Catcher" then OUTLINE_RED
			elseif r == "Runner" and st == "Safe" then OUTLINE_GREEN
			elseif r == "Runner" and st == "Active" and p:GetAttribute("HuzzHero") then OUTLINE_YELLOW
			elseif r == "Runner" and st == "Active" then OUTLINE_BLUE
			else nil
		local h = highlights[p]
		if not character or not color then
			if h then
				h:Destroy()
				highlights[p] = nil
			end
			return
		end
		if not h or h.Parent ~= character then
			if h then
				h:Destroy()
			end
			h = make("Highlight", {
				Name = "HuzzOutline", FillTransparency = 1, OutlineTransparency = 0.35,
				DepthMode = Enum.HighlightDepthMode.Occluded, Parent = character,
			})
			highlights[p] = h
		end
		h.OutlineColor, h.FillColor = color, color
	end
	local function watch(p)
		for _, attr in { "HuzzRole", "HuzzStatus", "HuzzHero" } do
			p:GetAttributeChangedSignal(attr):Connect(function()
				refreshHighlight(p)
			end)
		end
		p.CharacterAdded:Connect(function()
			task.defer(refreshHighlight, p)
		end)
		refreshHighlight(p)
	end
	for _, p in Players:GetPlayers() do
		watch(p)
	end
	Players.PlayerAdded:Connect(watch)
	Players.PlayerRemoving:Connect(function(p)
		if highlights[p] then
			highlights[p]:Destroy()
			highlights[p] = nil
		end
	end)

	-- Small sounds from Roblox's own library (no uploaded IDs; swap in your own any time).
	local function sound(id, volume, pitch)
		local s = make("Sound", { SoundId = id, Volume = volume, PlaybackSpeed = pitch or 1, Parent = gui })
		s:Play()
		s.Ended:Once(function()
			s:Destroy()
		end)
	end

	-- Moments from the server
	RoundNet.OnClientEvent:Connect(function(kind, data)
		if kind == "Announce" then
			setMessage(data.text, data.color)
			if data.big then
				show(small, data.text, data.color, 2.8)
			end
		elseif kind == "Caught" then
			if data.runner == player.UserId then
				flash.BackgroundTransparency = 0.6 -- (one flash, well under one a second)
				TweenService:Create(flash, TweenInfo.new(0.6), { BackgroundTransparency = 1 }):Play()
				show(banner, "YOU'RE DOWN!", RED, 1.8, 60)
				sound("rbxasset://sounds/uuhhh.mp3", 0.5)
			elseif data.catcher == player.UserId then
				show(small, `You got {nameOf(data.runner) or "a runner"}!`, RED, 1.6)
			end
		elseif kind == "Rescued" then
			if data.runner == player.UserId then
				show(banner, "RESCUED!", GREEN, 1.6, 64)
			elseif data.by == player.UserId then
				show(small, `You rescued {nameOf(data.runner) or "a runner"}!`, GREEN, 1.8)
			end
		elseif kind == "Safe" then
			show(banner, "SAFE!", GREEN, 1.4, 72)
			sound("rbxasset://sounds/electronicpingshort.wav", 0.4, 1.3)
		elseif kind == "Bonus" then
			show(small, `+{data.coins} coins!`, GOLD, 2.4)
		elseif kind == "Win" then
			local team = if data.team == "Runners" then "RUNNERS WIN!" else "CATCHERS WIN!"
			local teamColor = if data.team == "Runners" then BLUE else RED
			show(banner, team, teamColor, 3.2, 76)
			setMessage(team, teamColor)
			local color = rarityColor[data.rarity] or GOLD
			task.delay(3.4, function()
				if data.winner == player.UserId then
					show(banner, `YOU WON {string.upper(data.girl)}!`, color, 4, 64)
					show(small, "She's in your Index now", WHITE, 4)
				elseif data.name then
					show(banner, `{data.name} takes {data.girl} home!`, color, 4)
				else
					show(banner, `Nobody won {data.girl} this time`, MUTED, 4)
				end
			end)
		end
	end)
end

return M
