--[[
	Round HUD: the timer pill, your role badge (gold HERO, cream CHICKEN, red CATCHER...), the girl
	up for grabs (her picture, rarity and who has her), big announcements, and faint outlines on
	everyone in the game: catchers red, runners blue (as in the reference).
	Fonts: Luckiest Guy for big words, Fredoka One for lines. Laid out at 1280 x 720 and scaled.
	Built in code for now; it moves into the owner's UI kit with the Match HUD page.
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
	local RED = Color3.fromRGB(255, 84, 96)
	local GOLD = Color3.fromRGB(255, 205, 80)
	local GREEN = Color3.fromRGB(96, 232, 140)
	local MUTED = Color3.fromRGB(196, 200, 226)

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
		props.TextColor3 = props.TextColor3 or Color3.new(1, 1, 1)
		props.TextWrapped = props.TextWrapped or false
		local kids = { make("UIStroke", { Name = "Outline", Thickness = outline or 2, Color = INK, LineJoinMode = Enum.LineJoinMode.Round }) }
		if shine then
			table.insert(kids, make("UIGradient", { Name = "Shine", Rotation = 90, Color = ColorSequence.new(Color3.new(1, 1, 1), shine) }))
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

	-- Timer pill, top centre: a dark glass capsule, the stage on the left, the clock big on the right.
	local pill = make("Frame", {
		Name = "Timer", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromOffset(640, 62), Size = UDim2.fromOffset(250, 54),
		BackgroundColor3 = Color3.new(1, 1, 1), Parent = root,
	}, { corner(0.5), gradient(Color3.fromRGB(46, 42, 104), GLASS), rim(2.5, Color3.fromRGB(150, 136, 255), 0.25) })
	make("Frame", { Name = "Gloss", Position = UDim2.fromOffset(18, 3), Size = UDim2.new(1, -36, 0, 6), BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.8, Parent = pill }, { corner(0.5) })
	local stageText = text({ Name = "Stage", Position = UDim2.fromOffset(22, 0), Size = UDim2.new(0, 110, 1, 0), FontFace = ROUND, TextSize = 19, TextColor3 = MUTED, TextXAlignment = Enum.TextXAlignment.Left, Parent = pill }, 1.5)
	local clock = text({ Name = "Clock", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -20, 0, 3), Size = UDim2.new(0, 110, 1, 0), FontFace = DISPLAY, TextSize = 36, TextXAlignment = Enum.TextXAlignment.Right, Parent = pill }, 2.5, Color3.fromRGB(214, 206, 255))
	local divider = make("Frame", { Name = "Divider", Position = UDim2.new(0.5, 0, 0.5, 0), AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(2, 26), BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.8, BorderSizePixel = 0, Parent = pill })

	-- Role badge under it: a coloured tag with your role in big letters, and one short line beside it.
	local ROLE_LOOK = {
		Catcher = { Color3.fromRGB(255, 92, 104), Color3.fromRGB(196, 26, 56), Color3.new(1, 1, 1) },
		Hero = { Color3.fromRGB(255, 226, 120), Color3.fromRGB(240, 162, 30), Color3.fromRGB(74, 40, 0) },
		Chicken = { Color3.fromRGB(255, 249, 236), Color3.fromRGB(240, 222, 190), Color3.fromRGB(122, 64, 18) },
		Runner = { Color3.fromRGB(110, 184, 255), Color3.fromRGB(40, 112, 230), Color3.new(1, 1, 1) },
		Carrying = { Color3.fromRGB(255, 150, 200), Color3.fromRGB(226, 66, 140), Color3.new(1, 1, 1) },
		Safe = { Color3.fromRGB(130, 240, 160), Color3.fromRGB(34, 172, 92), Color3.fromRGB(8, 60, 30) },
		Caught = { Color3.fromRGB(176, 182, 204), Color3.fromRGB(110, 116, 142), Color3.new(1, 1, 1) },
		Watching = { Color3.fromRGB(176, 182, 204), Color3.fromRGB(110, 116, 142), Color3.new(1, 1, 1) },
	}
	local roleRow = make("Frame", {
		Name = "Role", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromOffset(640, 126), Size = UDim2.fromOffset(0, 38),
		AutomaticSize = Enum.AutomaticSize.X, BackgroundColor3 = GLASS, BackgroundTransparency = 0.25, Parent = root,
	}, { corner(0.5), rim(2, INK, 0.3), make("UIPadding", { PaddingLeft = UDim.new(0, 4), PaddingRight = UDim.new(0, 18) }),
		make("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0, 12), SortOrder = Enum.SortOrder.LayoutOrder }) })
	local tag = make("Frame", { Name = "Tag", Size = UDim2.fromOffset(0, 30), AutomaticSize = Enum.AutomaticSize.X, BackgroundColor3 = Color3.new(1, 1, 1), LayoutOrder = 1, Parent = roleRow },
		{ corner(0.5), make("UIPadding", { PaddingLeft = UDim.new(0, 14), PaddingRight = UDim.new(0, 14) }) })
	local tagFill = make("UIGradient", { Rotation = 90, Parent = tag })
	local tagRim = make("UIStroke", { Thickness = 2, Color = INK, Transparency = 0.2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = tag })
	local roleWord = make("TextLabel", { Name = "Word", Size = UDim2.fromOffset(0, 30), AutomaticSize = Enum.AutomaticSize.X, BackgroundTransparency = 1, FontFace = DISPLAY, TextSize = 24, Text = "", Parent = tag })
	-- (widths measured as well as automatic, so the row is right from the first frame)
	local function widthOf(str, font, size)
		local ok, v = pcall(function()
			local params = Instance.new("GetTextBoundsParams")
			params.Text, params.Font, params.Size, params.Width = str, font, size, 2000
			return TextService:GetTextBoundsAsync(params).X
		end)
		-- (offline there's no TextService: a rough width per font)
		return math.ceil(if ok and type(v) == "number" then v else #str * size * (if font == DISPLAY then 0.62 else 0.47))
	end
	local roleLine = text({ Name = "Line", Size = UDim2.fromOffset(0, 30), AutomaticSize = Enum.AutomaticSize.X, FontFace = ROUND, TextSize = 19, Text = "", LayoutOrder = 2, Parent = roleRow }, 1.5)

	-- Prize card, top left: her picture, her name and rarity, and who has her.
	local card = make("Frame", {
		Name = "Prize", Position = UDim2.fromOffset(176, 10), Size = UDim2.fromOffset(276, 84), BackgroundColor3 = Color3.new(1, 1, 1), Visible = false, Parent = root, -- (right of the lobby's side buttons)
	}, { corner(14), gradient(Color3.fromRGB(40, 38, 92), GLASS) })
	local cardRim = rim(2.5, GOLD, 0.15)
	cardRim.Parent = card
	local glow = make("Frame", { Name = "Glow", Size = UDim2.fromScale(1, 1), BackgroundColor3 = GOLD, Parent = card }, {
		corner(14), make("UIGradient", { Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(0.45, 1), NumberSequenceKeypoint.new(1, 1) }) }),
	})
	local portrait = make("ViewportFrame", { Name = "Portrait", Position = UDim2.fromOffset(8, 8), Size = UDim2.fromOffset(68, 68), BackgroundColor3 = Color3.fromRGB(26, 24, 60), Ambient = Color3.fromRGB(170, 170, 190), LightDirection = Vector3.new(-0.4, -1, -0.6), Parent = card }, { corner(12) })
	local portraitRim = rim(2, GOLD, 0.2)
	portraitRim.Parent = portrait
	local rarityChip = make("TextLabel", { Name = "Rarity", Position = UDim2.fromOffset(88, 8), Size = UDim2.fromOffset(0, 20), AutomaticSize = Enum.AutomaticSize.X, BackgroundColor3 = GOLD, FontFace = DISPLAY, TextSize = 15, TextColor3 = INK, Text = "", Parent = card },
		{ corner(0.5), make("UIPadding", { PaddingLeft = UDim.new(0, 9), PaddingRight = UDim.new(0, 9), PaddingTop = UDim.new(0, 2) }) })
	local girlName = text({ Name = "GirlName", Position = UDim2.fromOffset(88, 30), Size = UDim2.new(1, -96, 0, 28), FontFace = DISPLAY, TextSize = 25, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, Parent = card }, 2.5, Color3.fromRGB(255, 226, 150))
	local holder = text({ Name = "Holder", Position = UDim2.fromOffset(88, 58), Size = UDim2.new(1, -96, 0, 20), FontFace = ROUND, TextSize = 15, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, Parent = card }, 1.5)

	-- Big centre messages: a chunky shining word with a soft drop shadow, and a smaller line under it.
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
	local banner = bannerLabel("Banner", 232, 860, 120, 50, 4)
	local small = bannerLabel("Small", 300, 640, 40, 26, 2.5)
	local flash = make("Frame", { Name = "Flash", Size = UDim2.fromScale(1, 1), BackgroundColor3 = RED, BackgroundTransparency = 1, ZIndex = 0, Parent = gui })

	gui.Parent = player:WaitForChild("PlayerGui")
	local cam = Workspace.CurrentCamera
	if cam then
		cam:GetPropertyChangedSignal("ViewportSize"):Connect(refit)
	end

	local function show(b, message, color, hold, textSize)
		local label = b.label
		local c = color or Color3.new(1, 1, 1)
		label.Text, b.shadow.Text = message, message
		label.TextColor3 = Color3.new(1, 1, 1)
		-- white at the top shading into the message colour
		b.shine.Color = ColorSequence.new(Color3.new(1, 1, 1):Lerp(c, 0.25), c)
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

	local function nameOf(id)
		local p = id and id ~= 0 and Players:GetPlayerByUserId(id)
		return p and p.DisplayName
	end

	-- Stage, timer and role, refreshed every frame
	local STAGE_TEXT = {
		Waiting = "WAITING FOR PLAYERS",
		Intermission = "NEXT GAME",
		Voting = "VOTE FOR A MAP",
		Rolling = "ROLLING A GIRL",
		Loading = "GET READY",
		Countdown = "GET READY",
		Running = "ROUND %d",
		RoundOver = "ROUND OVER",
		GameOver = "GAME OVER",
	}
	local lastCount
	local shownRole
	local function refresh()
		local stage = State:GetAttribute("Stage") or "Waiting"
		local left = math.max(0, (State:GetAttribute("EndsAt") or 0) - Workspace:GetServerTimeNow())
		local label = string.format(STAGE_TEXT[stage] or stage, State:GetAttribute("Round") or 0)
		local timed = stage == "Running"
		if timed then
			local secs = math.ceil(left)
			stageText.Text = label
			clock.Text = string.format("%d:%02d", secs // 60, secs % 60)
			-- the last 10 seconds turn red
			clock.TextColor3 = if secs <= 10 then Color3.fromRGB(255, 120, 120) else Color3.new(1, 1, 1)
		else
			stageText.Text = ""
			clock.Text = label
			clock.TextColor3 = Color3.new(1, 1, 1)
		end
		stageText.Visible, divider.Visible = timed, timed
		clock.AnchorPoint = if timed then Vector2.new(1, 0) else Vector2.new(0.5, 0)
		clock.Position = if timed then UDim2.new(1, -20, 0, 3) else UDim2.new(0.5, 0, 0, 3)
		clock.TextSize = if timed then 36 else 26
		clock.TextXAlignment = if timed then Enum.TextXAlignment.Right else Enum.TextXAlignment.Center
		clock.Size = if timed then UDim2.new(0, 110, 1, 0) else UDim2.new(1, -24, 1, 0)
		pill.Size = UDim2.fromOffset(if timed then 250 else math.max(250, #label * 17 + 60), 54)
		pill.Visible = stage ~= "Intermission" and stage ~= "Voting" and stage ~= "Rolling" -- the Lobby HUD, the vote window and the roller show those

		if stage == "Countdown" then
			local count = math.ceil(left)
			if count ~= lastCount and count > 0 then
				show(banner, tostring(count), Color3.fromRGB(255, 226, 120), 0.8, 96)
			end
			lastCount = count
		elseif lastCount and stage == "Running" then
			lastCount = nil
			show(banner, "GO!", GREEN, 0.8, 96)
		end

		local myRole, myStatus = player:GetAttribute("HuzzRole"), player:GetAttribute("HuzzStatus")
		local holding = State:GetAttribute("HolderId") == player.UserId
		local girl = State:GetAttribute("GirlName") or ""
		local look, word, line
		if myRole == "Catcher" then
			local stab = Config.TagMode == "Stab"
			look, word = "Catcher", "CATCHER"
			line = if holding then `{girl} is with you. Stop them all!` else (if stab then "Stab the runners!" else "Tag the runners!")
		elseif myRole == "Runner" then
			if myStatus == "Safe" then
				look, word, line = "Safe", "SAFE", "You made it! Run again next round"
			elseif myStatus == "Caught" then
				look, word, line = "Caught", "CAUGHT", "Next round you're a catcher"
			elseif holding and State:GetAttribute("Phase") == "Final" then
				look, word, line = "Carrying", "FINAL RUN", `Cross with {girl} to win her!`
			elseif holding then
				look, word, line = "Carrying", "CARRYING", `Get {girl} across!`
			else
				local free = (State:GetAttribute("HolderId") or 0) == 0
				local isHero = player:GetAttribute("HuzzHero") == true
				if girl == "" then
					look, word, line = "Runner", "RUNNER", "Reach the other side!"
				elseif Config.Heroes and isHero then
					look, word, line = "Hero", "HERO", `First Hero across wins {girl}!`
				elseif Config.Heroes then
					look, word, line = "Chicken", "CHICKEN", "Just make it across!"
				elseif Config.Pickup == "Grab" and free then
					look, word, line = "Runner", "RUNNER", `Grab {girl}, then run!`
				else
					look, word, line = "Runner", "RUNNER", `First across wins {girl}!`
				end
			end
		elseif not (stage == "Waiting" or stage == "Intermission" or stage == "Voting" or stage == "Loading" or stage == "Rolling") then
			look, word, line = "Watching", "WATCHING", "You're in the next game"
		end
		roleRow.Visible = look ~= nil
		if look then
			if line ~= roleLine.Text then
				roleLine.Text = line
				shownRole = nil
			end
			if look .. word ~= shownRole then
				shownRole = look .. word
				local wordW, lineW = widthOf(word, DISPLAY, 24), widthOf(line, ROUND, 19)
				roleWord.Size, tag.Size = UDim2.fromOffset(wordW, 30), UDim2.fromOffset(wordW + 28, 30)
				roleLine.Size = UDim2.fromOffset(lineW, 30)
				roleRow.Size = UDim2.fromOffset(4 + wordW + 28 + 12 + lineW + 18, 38)
				local l = ROLE_LOOK[look]
				tagFill.Color = ColorSequence.new(l[1], l[2])
				roleWord.Text, roleWord.TextColor3 = word, l[3]
				tagRim.Color = l[2]:Lerp(INK, 0.6)
			end
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
		local x = if model then 88 else 18
		rarityChip.Position = UDim2.fromOffset(x, 8)
		girlName.Position, holder.Position = UDim2.fromOffset(x, 30), UDim2.fromOffset(x, 58)
		girlName.Size, holder.Size = UDim2.new(1, -x - 8, 0, 28), UDim2.new(1, -x - 8, 0, 20)
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
		rarityChip.TextColor3 = if color.R * 0.3 + color.G * 0.59 + color.B * 0.11 > 0.55 then INK else Color3.new(1, 1, 1)
		girlName.Text = girl
		local who = nameOf(State:GetAttribute("HolderId"))
		holder.Text = if who then `Held by {who}` elseif Config.GirlSpot == "Sky" then "First one across wins her!"
			elseif Config.GirlSpot == "Middle" then "Waiting in the middle" else "Waiting across the field"
		holder.TextColor3 = if who then GOLD else MUTED
		setPortrait(girl)
	end
	for _, name in { "GirlName", "GirlRarity", "HolderId" } do
		State:GetAttributeChangedSignal(name):Connect(refreshCard)
	end
	refreshCard()

	-- Outlines (as in the reference): a faint red line round catchers, blue round runners still out,
	-- yellow round Heroes, green round runners safe across the line. Caught runners lying on the floor lose theirs.
	local OUTLINE_RED = Color3.fromRGB(255, 64, 64)
	local OUTLINE_BLUE = Color3.fromRGB(64, 150, 255)
	local OUTLINE_GREEN = Color3.fromRGB(70, 230, 120) -- made it to the safe zone (owner's call)
	local OUTLINE_YELLOW = Color3.fromRGB(255, 214, 70) -- a Hero this round (owner's call)
	local highlights = {}
	local function refreshHighlight(p)
		local character = p.Character
		local r, st = p:GetAttribute("HuzzRole"), p:GetAttribute("HuzzStatus")
		local color = if r == "Catcher" then OUTLINE_RED
			elseif r == "Runner" and st == "Safe" then OUTLINE_GREEN
			elseif r == "Runner" and st == "Active" and p:GetAttribute("HuzzHero") then OUTLINE_YELLOW
			elseif r == "Runner" and st ~= "Caught" then OUTLINE_BLUE
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

	-- Moments from the server
	RoundNet.OnClientEvent:Connect(function(kind, data)
		if kind == "Announce" then
			if data.big then
				show(banner, data.text, data.color)
			else
				show(small, data.text, data.color)
			end
		elseif kind == "Caught" then
			if data.runner == player.UserId then
				flash.BackgroundTransparency = 0.55
				TweenService:Create(flash, TweenInfo.new(0.6), { BackgroundTransparency = 1 }):Play()
				show(small, if nameOf(data.catcher) then `Caught by {nameOf(data.catcher)}!` else "Caught!", RED)
			elseif data.catcher == player.UserId then
				show(small, `You got {nameOf(data.runner) or "a runner"}!`, RED)
			end
		elseif kind == "Win" then
			local color = rarityColor[data.rarity] or GOLD
			if data.winner == player.UserId then
				show(banner, `YOU WON {string.upper(data.girl)}!`, color, 5, 64)
				show(small, "She's in your Index now", Color3.new(1, 1, 1), 5)
			elseif data.name then
				show(banner, `{data.name} wins {data.girl}!`, color, 5)
			else
				show(banner, `Nobody won {data.girl} this time`, MUTED, 5)
			end
		end
	end)
end

return M
