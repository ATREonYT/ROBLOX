--[[
	The in-round screen, in the lobby kit's style (owner: "make it match the UI already made"), laid out like
	Huss Valley's:
	  - top centre, a small kit plate: a purple header with studs ("ROUND 2" and the clock) over a navy strip
	    (your role chip and the "in a row" pips: everyone across 3 rounds in a row wins);
	  - under it one message line (the latest thing that happened), white on a dark glass pill with a coloured
	    edge for its kind (green safe, red caught, gold Hero), and a small help line when there's something to do;
	  - top left the prize card (her picture, name, rarity, who has her);
	  - big moments (3-2-1-GO, SAFE, wins) in the middle, in the kit's heading face.
	Fonts are the kit's (Theme.Fonts): Montserrat Black headings, Montserrat Bold names and numbers, Roboto
	Condensed for lines. Faint outlines show every player's side: catchers red, runners blue, the Hero yellow,
	safe runners green. Laid out at 1280 x 720 and scaled.
]]
local M = {}

function M.start()
	local Players = game:GetService("Players")
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local RunService = game:GetService("RunService")
	local TweenService = game:GetService("TweenService")
	local Workspace = game:GetService("Workspace")

	local Shared = ReplicatedStorage:WaitForChild("Shared")
	local Net = require(Shared.Net)
	local Config = require(Shared.Config.Round)
	local UI = script.Parent.Parent.UI
	local Theme = require(UI.Theme)
	local Kit = require(UI.Kit)
	local Sfx = require(script.Parent.Sfx)
	local UIState = require(UI.State)
	-- The control tips (stab, powers, dash) show in a player's first two games only, then the line stays quiet.
	local function newPlayer()
		local stats = UIState.data.Stats or {}
		return (stats.Rounds or 0) < 2 -- (Stats.Rounds counts finished games)
	end

	local player = Players.LocalPlayer
	local RoundNet = Net.get("Round") :: RemoteEvent
	local State = RoundNet -- the round state is this remote's attributes

	local F, C = Theme.Fonts, Theme.Colors
	local INK = C.Frame -- outlines and shadows: the kit's frame navy
	local RED = Color3.fromRGB(255, 92, 110)
	local GOLD = Color3.fromRGB(255, 200, 70)
	local GREEN = Color3.fromRGB(96, 232, 140)
	local BLUE = Color3.fromRGB(104, 170, 255)
	local MUTED = C.SubText
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
	local function gradient(stops, rotation)
		local keys = {}
		for _, k in stops do
			table.insert(keys, ColorSequenceKeypoint.new(k[1], k[2]))
		end
		return make("UIGradient", { Rotation = rotation or 90, Color = ColorSequence.new(keys) })
	end
	-- Text with a thin dark outline. Fixed sizes: the whole HUD scales together.
	local function text(props, outline)
		props.BackgroundTransparency = 1
		props.TextColor3 = props.TextColor3 or WHITE
		props.TextWrapped = props.TextWrapped or false
		return make("TextLabel", props, { make("UIStroke", { Name = "Outline", Thickness = outline or 1.5, Color = INK, LineJoinMode = Enum.LineJoinMode.Round }) })
	end
	local function hexOf(c)
		return string.format("#%02X%02X%02X", math.round(c.R * 255), math.round(c.G * 255), math.round(c.B * 255))
	end
	-- A kit purple header bar (as the windows'): dark frame, glossy gradient, a light top line.
	local function header(props)
		local f = make("Frame", props, { corner(5), rim(2, C.Frame) })
		f.BackgroundColor3 = WHITE
		gradient(C.HeaderGradient).Parent = f
		make("Frame", { Name = "TopLine", Position = UDim2.fromOffset(3, 1), Size = UDim2.new(1, -6, 0, 1), BackgroundColor3 = C.HeaderTop, BorderSizePixel = 0, Parent = f })
		f.BackgroundTransparency = Theme.Transparency.Header
		Kit.studPattern(f, 0.45)
		return f
	end
	-- A kit navy panel.
	local function panel(props)
		local f = make("Frame", props, { corner(5), rim(2, C.Frame) })
		f.BackgroundColor3 = WHITE
		gradient({ { 0, C.RowTop }, { 1, C.Panel } }).Parent = f
		f.BackgroundTransparency = Theme.Transparency.Body
		Kit.studPattern(f, 0.3)
		return f
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

	-- Top centre: the round plate (header: ROUND 2 + clock; strip: role chip + streak), then the message line.
	local PLATE_W = 300
	local top = make("Frame", { Name = "Top", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromOffset(640, 6), Size = UDim2.fromOffset(700, 140), BackgroundTransparency = 1, Parent = root })
	local strip = panel({ Name = "Strip", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromOffset(350, 30), Size = UDim2.fromOffset(PLATE_W - 16, 34), Parent = top })
	local plate = header({ Name = "Plate", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromOffset(350, 0), Size = UDim2.fromOffset(PLATE_W, 38), Parent = top })
	Kit.studs(plate, 10, 56, 13)
	Kit.studs(plate, PLATE_W - 56, PLATE_W - 10, 13)
	local roundLabel = text({ Name = "Round", AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 64, 0.5, 0), Size = UDim2.fromOffset(110, 30), FontFace = F.Heading, TextSize = 21, TextXAlignment = Enum.TextXAlignment.Left, Text = "", Parent = plate }, 1.2)
	make("UIGradient", { Name = "Band", Rotation = 90, Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, WHITE), ColorSequenceKeypoint.new(0.5, C.TitleBand), ColorSequenceKeypoint.new(1, WHITE) }), Parent = roundLabel })
	roundLabel.Outline.Color = C.TitleStroke
	local clockBox = make("Frame", { Name = "Clock", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -62, 0.5, 0), Size = UDim2.fromOffset(66, 26), BackgroundColor3 = C.Pill, Parent = plate }, { corner(4), rim(1, C.PillRim) })
	local clock = text({ Name = "Time", Size = UDim2.fromScale(1, 1), FontFace = F.Number, TextSize = 18, Text = "", Parent = clockBox }, 0)
	clock.Outline.Enabled = false
	-- the strip: role chip on the left, IN A ROW + pips on the right
	local chip = make("Frame", { Name = "Role", AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 8, 0.5, 4), Size = UDim2.fromOffset(84, 20), BackgroundColor3 = BLUE, Parent = strip },
		{ corner(4), rim(1, INK, 0.2), gradient({ { 0, WHITE }, { 1, Color3.fromRGB(205, 205, 215) } }) })
	local chipText = text({ Name = "Word", Size = UDim2.fromScale(1, 1), FontFace = F.Button, TextSize = 15, Text = "", Parent = chip }, 1)
	local pips = make("Frame", { Name = "Streak", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -8, 0.5, 4), Size = UDim2.fromOffset(160, 20), BackgroundTransparency = 1, Parent = strip }, {
		make("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Right, VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	text({ Name = "Label", Size = UDim2.fromOffset(62, 20), FontFace = F.Button, TextSize = 13, TextColor3 = MUTED, Text = "IN A ROW", LayoutOrder = 0, Parent = pips }, 0).Outline.Enabled = false
	local pipDots = {}
	for i = 1, 5 do
		pipDots[i] = make("Frame", { Name = "Pip" .. i, Size = UDim2.fromOffset(18, 9), BackgroundColor3 = GOLD, LayoutOrder = i, Visible = false, Parent = pips }, { corner(3), rim(1, INK, 0.2) })
	end
	-- the message line: white words on a dark glass bar that fades out at both ends, a short coloured line
	-- under them for the kind of news (green safe, red caught, gold Hero)
	local msgPill = make("Frame", { Name = "Message", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromOffset(350, 72), Size = UDim2.fromOffset(560, 34), BackgroundColor3 = C.Frame, BackgroundTransparency = 0.15, BorderSizePixel = 0, Visible = false, Parent = top }, {
		make("UIGradient", { Name = "Fade", Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.22, 0.2), NumberSequenceKeypoint.new(0.78, 0.2), NumberSequenceKeypoint.new(1, 1) }) }),
	})
	local msgEdge = make("Frame", { Name = "Edge", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, 0), Size = UDim2.fromOffset(120, 3), BackgroundColor3 = WHITE, BorderSizePixel = 0, Parent = msgPill }, { corner(2) })
	local message = text({ Name = "Line", Size = UDim2.new(1, 0, 1, -2), FontFace = F.Name, TextSize = 19, RichText = true, TextTruncate = Enum.TextTruncate.AtEnd, Text = "", Parent = msgPill }, 1)
	local msgScale = make("UIScale", { Parent = msgPill })
	local help = text({ Name = "Help", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromOffset(350, 110), Size = UDim2.fromOffset(700, 22), FontFace = F.Button, TextSize = 16, TextColor3 = C.NoteText, RichText = true, Text = "", Parent = top }, 1.2)

	-- Prize card, top left: a small kit window (purple header with PRIZE and her rarity, navy body).
	local card = make("Frame", { Name = "Prize", Position = UDim2.fromOffset(20, 10), Size = UDim2.fromOffset(250, 92), BackgroundTransparency = 1, Visible = false, Parent = root })
	local cardBody = panel({ Name = "Body", Position = UDim2.fromOffset(0, 22), Size = UDim2.new(1, 0, 1, -22), Parent = card })
	local cardHead = header({ Name = "Head", Size = UDim2.new(1, 0, 0, 28), Parent = card })
	local prizeWord = text({ Name = "Title", Position = UDim2.fromOffset(10, 0), Size = UDim2.new(0, 70, 1, 0), FontFace = F.Heading, TextSize = 16, TextXAlignment = Enum.TextXAlignment.Left, Text = "PRIZE", Parent = cardHead }, 1)
	prizeWord.Outline.Color = C.TitleStroke
	local rarityChip = make("TextLabel", { Name = "Rarity", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -6, 0.5, 0), Size = UDim2.fromOffset(0, 18), AutomaticSize = Enum.AutomaticSize.X, BackgroundColor3 = GOLD, FontFace = F.Button, TextSize = 13, TextColor3 = INK, Text = "", Parent = cardHead },
		{ corner(4), rim(1, INK, 0.2), make("UIPadding", { PaddingLeft = UDim.new(0, 7), PaddingRight = UDim.new(0, 7) }) })
	local portrait = make("ViewportFrame", { Name = "Portrait", Position = UDim2.fromOffset(8, 12), Size = UDim2.fromOffset(52, 52), BackgroundColor3 = WHITE, Ambient = Color3.fromRGB(170, 170, 190), LightDirection = Vector3.new(-0.4, -1, -0.6), Parent = cardBody },
		{ corner(5), gradient({ { 0, Color3.fromHex("4F78EC") }, { 0.55, Color3.fromHex("3B47B8") }, { 1, Color3.fromHex("2A2475") } }, 60) })
	local portraitRim = rim(2, GOLD, 0)
	portraitRim.Parent = portrait
	local girlName = text({ Name = "GirlName", Position = UDim2.fromOffset(68, 12), Size = UDim2.new(1, -76, 0, 24), FontFace = F.Name, TextSize = 18, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, Parent = cardBody }, 1)
	local holder = text({ Name = "Holder", Position = UDim2.fromOffset(68, 38), Size = UDim2.new(1, -76, 0, 20), FontFace = F.Body, TextSize = 15, TextColor3 = MUTED, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, Parent = cardBody }, 0)
	holder.Outline.Enabled = false

	-- Big centre moments: the kit heading face (white with a lavender band, indigo outline) and a soft drop.
	local function bannerLabel(name, y, w, h, size, outline)
		local shadow = make("TextLabel", {
			Name = name .. "Shadow", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(640, y + 4), Size = UDim2.fromOffset(w, h),
			BackgroundTransparency = 1, FontFace = F.Heading, TextSize = size, TextWrapped = true, TextColor3 = C.TitleShadow, TextTransparency = 1, Text = "", Parent = root,
		})
		local label = text({
			Name = name, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(640, y), Size = UDim2.fromOffset(w, h),
			FontFace = F.Heading, TextSize = size, TextWrapped = true, Text = "", TextTransparency = 1, Parent = root,
		}, outline)
		label.Outline.Color = C.TitleShadow
		local shine = make("UIGradient", { Name = "Shine", Rotation = 90, Parent = label })
		local pop = make("UIScale", { Name = "Pop", Parent = label })
		local popShadow = make("UIScale", { Name = "Pop", Parent = shadow })
		return { label = label, stroke = label.Outline, shadow = shadow, shine = shine, size = size, pop = pop, popShadow = popShadow }
	end
	local banner = bannerLabel("Banner", 250, 900, 130, 56, 3.5)
	local small = bannerLabel("Small", 330, 760, 44, 26, 2)
	local flash = make("Frame", { Name = "Flash", Size = UDim2.fromScale(1, 1), BackgroundColor3 = RED, BackgroundTransparency = 1, ZIndex = 0, Parent = gui })

	gui.Parent = player:WaitForChild("PlayerGui")
	local cam = Workspace.CurrentCamera
	if cam then
		cam:GetPropertyChangedSignal("ViewportSize"):Connect(refit)
	end

	-- A big word: pops in from 1.3x on a springy ease, holds, then fades out (one at a time per slot).
	local function show(b, msg, color, hold, textSize)
		local label = b.label
		local c = color or WHITE
		label.Text, b.shadow.Text = msg, msg
		label.TextColor3 = WHITE
		-- white at the top, a light band, then the message colour at the foot (the kit title's banding, coloured)
		b.shine.Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, WHITE), ColorSequenceKeypoint.new(0.45, WHITE:Lerp(c, 0.35)), ColorSequenceKeypoint.new(1, c) })
		local size = textSize or b.size
		label.TextSize, b.shadow.TextSize = size, size
		label.TextTransparency, b.stroke.Transparency, b.shadow.TextTransparency = 0, 0, 0.35
		b.pop.Scale, b.popShadow.Scale = 1.3, 1.3
		local spring = TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
		TweenService:Create(b.pop, spring, { Scale = 1 }):Play()
		TweenService:Create(b.popShadow, spring, { Scale = 1 }):Play()
		local token = {}
		label:SetAttribute("Token", tostring(token))
		task.delay(hold or 2.6, function()
			if label:GetAttribute("Token") == tostring(token) then
				local info = TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
				TweenService:Create(label, info, { TextTransparency = 1 }):Play()
				TweenService:Create(b.stroke, info, { Transparency = 1 }):Play()
				TweenService:Create(b.shadow, info, { TextTransparency = 1 }):Play()
				TweenService:Create(b.pop, info, { Scale = 0.9 }):Play()
			end
		end)
	end

	-- The message line: the latest news stays (as in Huss Valley); it pops a little when it changes. The edge
	-- carries the colour so the words stay easy to read.
	local function setMessage(msg, color)
		msgPill.Visible = msg ~= ""
		message.Text = (string.gsub(msg, "[&<>]", { ["&"] = "&amp;", ["<"] = "&lt;", [">"] = "&gt;" })) -- (names are plain text)
		msgEdge.BackgroundColor3 = color or WHITE
		msgScale.Scale = 1.12
		TweenService:Create(msgScale, TweenInfo.new(0.3, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	end

	local function nameOf(id)
		local p = id and id ~= 0 and Players:GetPlayerByUserId(id)
		return p and p.DisplayName
	end

	-- Help lines for what you can do right now (short, one thing each).
	local keyboard = not game:GetService("UserInputService").TouchEnabled -- (touch: show the pad/button names)
	local function key(k, pad)
		return `<font color="#FFFFFF"><b>{if keyboard then k else pad}</b></font>`
	end
	local ROLE_COLOR = { RUNNER = BLUE, CATCHER = RED, HERO = GOLD, SAFE = GREEN, DOWN = Color3.fromRGB(255, 160, 90), CARRYING = Color3.fromRGB(255, 150, 200), WATCHING = MUTED }
	local TIMED = { HeroRun = true, Running = true, Picking = true }
	M.extraHelp = nil -- (Gameplay/Onboarding can put a first-game tip here)
	local lastCount
	local function refresh()
		local stage = State:GetAttribute("Stage") or "Waiting"
		local now = Workspace:GetServerTimeNow()
		local left = math.max(0, (State:GetAttribute("EndsAt") or 0) - now)
		local inGame = (State:GetAttribute("Round") or 0) > 0 and stage ~= "Waiting" and stage ~= "Voting" and stage ~= "Intermission" and stage ~= "Rolling"
		top.Visible = inGame
		if inGame then
			roundLabel.Text = `ROUND {State:GetAttribute("Round") or 0}`
			local myRole, myStatus = player:GetAttribute("HuzzRole"), player:GetAttribute("HuzzStatus")
			local holding = State:GetAttribute("HolderId") == player.UserId
			local word, line
			if myRole == "Catcher" then
				word = "CATCHER"
				line = if (stage == "Running" or stage == "HeroRun") and newPlayer() then `{key("Click", "R2")} to stab · {key("Q", "L1")} {key("E", "R1")} powers` else nil
			elseif myRole == "Runner" then
				if myStatus == "Downed" then
					word, line = "DOWN", "Hold on. A runner can pick you up."
				elseif myStatus == "Safe" then
					word, line = "SAFE", "You're across. Wait here."
				elseif player:GetAttribute("HuzzHero") then
					word, line = "HERO", if stage == "HeroRun" then "Solo run. Make it across!" else nil
				elseif holding then
					word, line = "CARRYING", "Get her across!"
				else
					word = "RUNNER"
					line = if stage == "HeroRun" then "Hero's run. Wait on the line."
						elseif stage == "Running" and newPlayer() then `Reach the <font color="#60E88C"><b>SAFE ZONE</b></font> · {key("Space", "A")} to dash`
						else nil
				end
			else
				word, line = "WATCHING", "You're in next game."
			end
			local c = ROLE_COLOR[word] or WHITE
			chipText.Text = word
			chip.Size = UDim2.fromOffset(#word * 9 + 18, 20)
			chip.BackgroundColor3 = c
			local dark = c.R * 0.3 + c.G * 0.59 + c.B * 0.11 > 0.62
			chipText.TextColor3 = if dark then INK else WHITE
			chipText.Outline.Enabled = not dark
			help.Text = M.extraHelp or line or ""
			if TIMED[stage] then
				local secs = math.ceil(left)
				clock.Text = string.format("%d:%02d", secs // 60, secs % 60)
				clock.TextColor3 = if secs <= 10 and stage == "Running" then Color3.fromRGB(255, 120, 130) else WHITE
			else
				clock.Text = "--:--"
				clock.TextColor3 = MUTED
			end
			-- in a row: gold bars for crossings done, dark ones still to go
			local goal = State:GetAttribute("Crossings") or Config.Crossings
			local streak = State:GetAttribute("Streak") or 0
			for i, dot in pipDots do
				dot.Visible = i <= goal
				dot.BackgroundColor3 = if i <= streak then GOLD else C.Frame
				dot.BackgroundTransparency = if i <= streak then 0 else 0.2
			end
		end

		if stage == "Countdown" then
			local count = math.ceil(left)
			if count ~= lastCount and count > 0 then
				show(banner, tostring(count), Color3.fromRGB(255, 226, 120), 0.8, 110)
				Sfx.play("countdown_tick", { pitch = 1 + (3 - math.min(count, 3)) * 0.06 })
			end
			lastCount = count
		elseif lastCount and stage == "Running" then
			lastCount = nil
			show(banner, "GO!", GREEN, 0.9, 120)
			Sfx.play("countdown_go")
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
		local x = if model then 68 else 12
		girlName.Position, holder.Position = UDim2.fromOffset(x, 12), UDim2.fromOffset(x, 38)
		girlName.Size, holder.Size = UDim2.new(1, -x - 8, 0, 24), UDim2.new(1, -x - 8, 0, 20)
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
		portraitRim.Color, rarityChip.BackgroundColor3 = color, color
		rarityChip.Text = string.upper(rarity)
		rarityChip.TextColor3 = if color.R * 0.3 + color.G * 0.59 + color.B * 0.11 > 0.55 then INK else WHITE
		girlName.Text = girl
		local who = nameOf(State:GetAttribute("HolderId"))
		holder.Text = if who then `{who} has her` else "Up for grabs"
		holder.TextColor3 = if who then GOLD else MUTED
		setPortrait(girl)
	end
	for _, name in { "GirlName", "GirlRarity", "HolderId" } do
		State:GetAttributeChangedSignal(name):Connect(refreshCard)
	end
	refreshCard()

	-- Your equipped girl reacts (owner: "make the anime girls feel more included"): her face and a speech bubble,
	-- bottom left, for a moment when something happens to you.
	local LINES = {
		Safe = { "Made it!", "Speedy!", "Ez!" },
		Rescued = { "Phew!", "Back up!", "Close one!" },
		Rescuer = { "Clutch!", "Nice save!", "Saved 'em!" },
		Caught = { "Ouch!", "Hang on!", "Help's coming!" },
		Got = { "Gotcha!", "Too slow!", "Got one!" },
		Hero = { "Go go go!", "You got this!", "Solo time!" },
		Win = { "GG!", "We did it!", "Let's go!" },
		Lose = { "GG!", "So close!", "Rematch!" },
	}
	local Looks = require(Shared.Config.GirlLooks)
	local bubbleCard = make("Frame", { Name = "Companion", Position = UDim2.fromOffset(24, 548), Size = UDim2.fromOffset(250, 72), BackgroundTransparency = 1, Visible = false, Parent = root })
	local face = make("ViewportFrame", { Name = "Face", Size = UDim2.fromOffset(64, 64), BackgroundColor3 = WHITE, Ambient = Color3.fromRGB(170, 170, 190), LightDirection = Vector3.new(-0.4, -1, -0.6), Parent = bubbleCard },
		{ corner(0.5), gradient({ { 0, Color3.fromHex("4F78EC") }, { 0.55, Color3.fromHex("3B47B8") }, { 1, Color3.fromHex("2A2475") } }, 60) })
	local faceRim = rim(3, GOLD, 0)
	faceRim.Parent = face
	local bubble = make("Frame", { Name = "Bubble", Position = UDim2.fromOffset(74, 12), Size = UDim2.fromOffset(0, 38), AutomaticSize = Enum.AutomaticSize.X, BackgroundColor3 = WHITE, Parent = bubbleCard },
		{ corner(10), rim(2, C.Frame, 0), make("UIPadding", { PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12) }) })
	local said = make("TextLabel", { Name = "Line", Size = UDim2.fromOffset(0, 38), AutomaticSize = Enum.AutomaticSize.X, BackgroundTransparency = 1, FontFace = F.Name, TextSize = 17, TextColor3 = C.DarkText, Text = "", Parent = bubble })
	local faceKey = nil
	local function sayLine(event)
		local key = player:GetAttribute("HuzzCompanion") or ""
		local girls = ReplicatedStorage:FindFirstChild("HuzzGirls")
		local model = girls and key ~= "" and girls:FindFirstChild(key)
		if not model then
			return
		end
		if faceKey ~= key then
			faceKey = key
			for _, ch in face:GetChildren() do
				if ch:IsA("Model") or ch:IsA("Camera") then ch:Destroy() end
			end
			local copy = model:Clone()
			copy.Parent = face
			local head = copy:FindFirstChild("Head", true)
			local camera = make("Camera", { FieldOfView = 30, Parent = face })
			face.CurrentCamera = camera
			if head and head:IsA("BasePart") then
				local at = head.CFrame.Position - Vector3.new(0, 0.2, 0)
				camera.CFrame = CFrame.lookAt(at + head.CFrame.LookVector * 4.2 + Vector3.new(0, 0.3, 0), at)
			end
			local look = Looks[model:GetAttribute("Id") or ""]
			faceRim.Color = if look then look.Colors[1] else (rarityColor[model:GetAttribute("Rarity") or ""] or GOLD)
		end
		local list = LINES[event]
		said.Text = list[math.random(#list)]
		bubbleCard.Visible = true
		bubbleCard.Position = UDim2.fromOffset(24, 562)
		TweenService:Create(bubbleCard, TweenInfo.new(0.3, Enum.EasingStyle.Back), { Position = UDim2.fromOffset(24, 548) }):Play()
		local token = {}
		bubbleCard:SetAttribute("Token", tostring(token))
		task.delay(2.6, function()
			if bubbleCard:GetAttribute("Token") == tostring(token) then
				bubbleCard.Visible = false
			end
		end)
	end
	State:GetAttributeChangedSignal("PickChoice"):Connect(function()
		local choice = State:GetAttribute("PickChoice")
		if choice == "Hero" or choice == "Chicken" then
			Sfx.play(if choice == "Hero" then "hero_chosen" else "chicken_chosen")
		end
		if State:GetAttribute("PickChoice") == "Hero" and State:GetAttribute("PickId") == player.UserId then
			sayLine("Hero")
		end
	end)

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

	-- Moments from the server
	RoundNet.OnClientEvent:Connect(function(kind, data)
		if kind == "Announce" then
			setMessage(data.text, data.color)
			if data.big then
				show(small, data.text, data.color, 2.8)
			end
		elseif kind == "Caught" then
			if data.runner == player.UserId then
				sayLine("Caught")
				flash.BackgroundTransparency = 0.6 -- (one flash, well under one a second)
				TweenService:Create(flash, TweenInfo.new(0.6), { BackgroundTransparency = 1 }):Play()
				show(banner, "YOU'RE DOWN", RED, 1.8, 60)
				Sfx.play("caught")
			elseif data.catcher == player.UserId then
				show(small, `Got {nameOf(data.runner) or "one"}!`, RED, 1.6)
				sayLine("Got")
				Sfx.play("stab", { pitch = 0.9 })
			end
		elseif kind == "Rescued" then
			if data.runner == player.UserId then
				show(banner, "BACK UP!", GREEN, 1.6, 64)
				sayLine("Rescued")
				Sfx.play("rescue")
			elseif data.by == player.UserId then
				show(small, `You saved {nameOf(data.runner) or "them"}!`, GREEN, 1.8)
				sayLine("Rescuer")
				Sfx.play("rescue")
			end
		elseif kind == "Safe" then
			show(banner, "SAFE!", GREEN, 1.4, 72)
			sayLine("Safe")
			Sfx.play("safe")
		elseif kind == "Bonus" then
			show(small, `+{data.coins} coins`, GOLD, 2.4)
			Sfx.play("coin")
		elseif kind == "Win" then
			local team = if data.team == "Runners" then "RUNNERS WIN" else "CATCHERS WIN"
			local teamColor = if data.team == "Runners" then BLUE else RED
			show(banner, team, teamColor, 3.2, 76)
			local mine = player:GetAttribute("HuzzRole")
			if mine == "Runner" or mine == "Catcher" then
				local won = (data.team == "Runners") == (mine == "Runner")
				sayLine(if won then "Win" else "Lose")
				Sfx.play(if won then "round_win" else "round_lose")
			end
			setMessage(team, teamColor)
			local color = rarityColor[data.rarity] or GOLD
			task.delay(3.4, function()
				if data.winner == player.UserId then
					show(banner, `{string.upper(data.girl)} IS YOURS`, color, 4, 60)
					show(small, "Find her in your Index", WHITE, 4)
					Sfx.play("reward")
				elseif data.name then
					show(banner, `{data.name} wins {data.girl}`, color, 4, 44)
				else
					show(banner, `Nobody wins {data.girl}`, MUTED, 4, 44)
				end
			end)
		end
	end)
end

return M
