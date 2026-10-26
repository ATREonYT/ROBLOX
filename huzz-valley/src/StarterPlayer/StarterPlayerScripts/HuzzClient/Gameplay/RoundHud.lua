--[[
	The in-round screen, laid out like Huss Valley's top of screen (docs/feel-study.md gaps 1, 2, 10; owner: "make
	it feel like the references ... more smooth"). Text only at the top, no panels:
	  - "ROUND 2 · 4 RUNNERS LEFT" small (a practice game with one runner: "1 OF 3 IN A ROW") (green round, white streak), in Roblox's top-bar row (IgnoreGuiInset);
	  - under it THE MESSAGE LINE: the latest news, big (fits a box 40% of the screen wide, text 14 to 27),
	    white with a dark outline, swapped instantly. Its words take the news colour (green safe / saved, red
	    caught, white news, the girl's rarity colour) while Theme.MessageColour is true (the one switch; false =
	    always white). Outside a game it still shows for a few seconds ("Map: Halloween", "C.C. is up for grabs!"),
	    lower down so it clears the lobby's NEXT ROUND plate;
	  - under that "Runner · 0:21" small, and a help line only in the player's very first round. The whole cluster
	    ends at 8.6% of the screen (HV 8.8%).
	  - someone only watching a game sees none of these top lines (the lobby's SERVER LUCK sign is there instead);
	  - top left the prize card (her picture, name, who has her), never while people run.
	  - Centre words only for the big moments (3-2-1, GO!, SAFE!, YOU'RE DOWN / OUT, BACK UP!, the win), 27% from
	    the top so they never print on your own character or name tag. Everything else is the message line.
	  - 3-2-1-GO is drawn every frame from the server's EndsAt (no tweens to fight): each number pops in from 1.4x
	    over 0.15 s, holds, then shrinks and fades before the next; GO! is bigger and green, from the count's end
	    (server time). One pop a second. Only the last 3 seconds count: after a CHICKEN pick (or no answer) the
	    server adds a short lead while the camera swings back behind you, and nothing draws until the camera is
	    back (owner: "the numbers just dont appear well"); HERO / CHICKEN words over heads step aside meanwhile.
	Your own name tag (made by HuzzServer/NameTagService) is faded, as in Huss Valley, and hidden while the round's
	camera shots play (HuzzCinematic / HuzzChoosing; a HERO / CHICKEN word over your head stays, alone) and from the
	Hero run to the round's end (HeroRun, Countdown, Running, RoundOver: it sat where the centre words print).
	Thin team outlines (Highlight, no fill, outline 0.55 see-through): catchers red, runners dark blue, the Hero
	yellow, safe runners green. Laid out at 1280 x 720 and scaled. Gotham only, no gold.
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
	local Scale = require(UI.Scale)
	local Sfx = require(script.Parent.Sfx)
	local UIState = require(UI.State)
	-- The help line (tips, "Wait here"...) shows only in a player's very first round, then the line stays quiet
	-- (feel study: HV's top cluster is 8.8% of the screen; the help line pushed ours past that).
	local function firstRound(state)
		local stats = UIState.data.Stats or {}
		return (stats.Rounds or 0) == 0 and (state:GetAttribute("Round") or 0) <= 1 -- (Stats.Rounds counts finished games)
	end

	local player = Players.LocalPlayer
	local RoundNet = Net.get("Round") :: RemoteEvent
	local State = RoundNet -- the round state is this remote's attributes

	local F, C = Theme.Fonts, Theme.Colors
	local INK = C.Frame -- outlines and shadows: the kit's frame navy
	local RED = Color3.fromRGB(255, 92, 110)
	local GOLD = C.Accent -- (owner: no gold; the one accent is Huss Valley green)
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
	-- Text with a dark outline. Fixed sizes: the whole HUD scales together.
	local function text(props, outline)
		props.BackgroundTransparency = 1
		props.TextColor3 = props.TextColor3 or WHITE
		props.TextWrapped = props.TextWrapped or false
		return make("TextLabel", props, { make("UIStroke", { Name = "Outline", Thickness = outline or 1.5, Color = INK, LineJoinMode = Enum.LineJoinMode.Round }) })
	end
	local function luma(c)
		return c.R * 0.3 + c.G * 0.59 + c.B * 0.11
	end
	-- A kit purple header bar (as the windows'): dark frame, glossy gradient, a light top line.
	local Kit = require(UI.Kit)
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

	-- IgnoreGuiInset: the round line sits in Roblox's own top-bar row (centred; Roblox's buttons are at the sides),
	-- so the whole top cluster fits in HV's 9% of the screen.
	local gui = make("ScreenGui", { Name = "HuzzRoundHud", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 5 })
	-- Roblox's top bar height in pixels (0 offline): the prize card and the lobby message keep clear of it.
	local function insetY(): number
		local ok, inset = pcall(function() return game:GetService("GuiService"):GetGuiInset() end)
		return if ok and typeof(inset) == "Vector2" then inset.Y else 0
	end
	-- Everything is laid out for a 1280 x 720 screen and scaled to yours (from the top centre).
	local root = make("Frame", { Name = "Root", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0), Size = UDim2.fromOffset(1280, 720), BackgroundTransparency = 1, Parent = gui })
	local fit = make("UIScale", { Name = "Fit", Parent = root })
	local function refit()
		local cam = Workspace.CurrentCamera
		local size = cam and cam.ViewportSize or Vector2.new(1280, 720)
		local preview = Workspace:GetAttribute("UIPreviewScale") -- (the offline preview: its pages are 768 wide)
		fit.Scale = if type(preview) == "number" then preview * 768 / 1280 else math.clamp(math.min(size.X / 1280, size.Y / 720), math.min(0.55, size.X / 1280), 1.6) -- (narrow phones: never wider than the screen)
	end
	refit()

	-- Top centre, text only (Huss Valley: "ROUND 01" small, the news big, "Safe · 0:21" small; 8.8% of the screen).
	-- Heights in this 720-tall layout (from the very top of the screen): round line 5-20 (in Roblox's top-bar row,
	-- centre y ~13), message 20-48 (40% wide), role line 48-62 (8.6%), help 63-77 (first round only).
	local MSG_W, MSG_H, MSG_MAX, MSG_MIN = 512, 28, 27, 14
	local top = make("Frame", { Name = "Top", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromOffset(640, 0), Size = UDim2.fromOffset(700, 80), BackgroundTransparency = 1, Parent = root })
	local roundLabel = text({ Name = "Round", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromOffset(350, 5), Size = UDim2.fromOffset(600, 15), FontFace = F.Heading, TextSize = 14, TextColor3 = C.Accent, RichText = true, Text = "", Parent = top }, 1.5)
	local roleLine = text({ Name = "Role", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromOffset(350, 48), Size = UDim2.fromOffset(600, 14), FontFace = F.Name, TextSize = 14, RichText = true, Text = "", Parent = top }, 1.5)
	local help = text({ Name = "Help", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromOffset(350, 63), Size = UDim2.fromOffset(700, 14), FontFace = F.Body, TextSize = 13, TextColor3 = C.NoteText, RichText = true, Text = "", Parent = top }, 1.2)
	-- The message line sits in root (not in Top) so it can show outside a game too, lower down there.
	local MSG_Y_GAME = 20
	local message = text({
		Name = "Message", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromOffset(640, MSG_Y_GAME), Size = UDim2.fromOffset(MSG_W, MSG_H),
		FontFace = F.Heading, TextSize = MSG_MAX, TextScaled = true, Text = "", Visible = false, Parent = root,
	}, 3)
	message.Outline.Transparency = 0.05
	make("UITextSizeConstraint", { MaxTextSize = MSG_MAX, MinTextSize = MSG_MIN, Parent = message })

	-- Prize card, top left: a small kit window (purple header with PRIZE and her rarity, navy body).
	local CARD_Y = 10 -- (under Roblox's top bar: refit adds its height, the HUD ignores the inset)
	local card = make("Frame", { Name = "Prize", Position = UDim2.fromOffset(20, CARD_Y), Size = UDim2.fromOffset(250, 92), BackgroundTransparency = 1, Visible = false, Parent = root })
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

	-- Big centre moments, 27% from the top (y 194 of 720): Gotham Heavy Italic, one solid colour, thick dark
	-- outline and a soft drop (Huss Valley). "Small" is the line under a big word (+25 coins, Find her in your Index).
	local BANNER_Y = 194
	local function bannerLabel(name, y, w, h, size, outline)
		local shadow = make("TextLabel", {
			Name = name .. "Shadow", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(640, y + 4), Size = UDim2.fromOffset(w, h),
			BackgroundTransparency = 1, FontFace = F.Big, TextSize = size, TextWrapped = true, TextColor3 = C.TitleShadow, TextTransparency = 1, Text = "", Parent = root,
		})
		local label = text({
			Name = name, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(640, y), Size = UDim2.fromOffset(w, h),
			FontFace = F.Big, TextSize = size, TextWrapped = true, Text = "", TextTransparency = 1, Parent = root,
		}, outline)
		label.Outline.Color = C.TitleShadow
		label.Outline.Transparency = 1
		local pop = make("UIScale", { Name = "Pop", Parent = label })
		local popShadow = make("UIScale", { Name = "Pop", Parent = shadow })
		return { label = label, stroke = label.Outline, shadow = shadow, size = size, pop = pop, popShadow = popShadow, tweens = {} }
	end
	local banner = bannerLabel("Banner", BANNER_Y, 900, 130, 56, 3.5)
	local small = bannerLabel("Small", BANNER_Y + 62, 760, 40, 24, 2)
	local count = bannerLabel("Count", BANNER_Y, 600, 150, 104, 4) -- (3-2-1-GO, drawn every frame)

	gui.Parent = player:WaitForChild("PlayerGui")
	-- A full window (the Shop...) hides the round's words and banners until it closes (owner's screenshot: "Map:
	-- Halloween" was written over the Shop).
	local ModalManager = require(script.Parent.Parent.UI.ModalManager)
	ModalManager.changed(function(now)
		gui.Enabled = now == nil or ModalManager.isSide(now)
	end)
	local function placeCard()
		card.Position = UDim2.fromOffset(20, CARD_Y + math.ceil(insetY() / math.max(fit.Scale, 0.01)))
	end
	placeCard()
	local cam = Workspace.CurrentCamera
	if cam then
		cam:GetPropertyChangedSignal("ViewportSize"):Connect(function()
			refit()
			placeCard()
		end)
	end

	-- A big word: pops in from 1.4x (0.18 s, Back out), holds, then shrinks and fades (0.3 s). A new word cancels
	-- the old word's tweens first, so a fade still running can't eat the new one.
	local function play(b, target, info, goal)
		local t = TweenService:Create(target, info, goal)
		table.insert(b.tweens, t)
		t:Play()
	end
	local function show(b, msg, color, hold, textSize)
		for _, t in b.tweens do
			t:Cancel()
		end
		table.clear(b.tweens)
		local label = b.label
		label.Text, b.shadow.Text = msg, msg
		label.TextColor3 = color or WHITE
		local size = textSize or b.size
		label.TextSize, b.shadow.TextSize = size, size
		label.TextTransparency, b.stroke.Transparency, b.shadow.TextTransparency = 0, 0, 0.35
		b.pop.Scale, b.popShadow.Scale = 1.4, 1.4
		local spring = TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
		play(b, b.pop, spring, { Scale = 1 })
		play(b, b.popShadow, spring, { Scale = 1 })
		local token = {}
		b.token = token
		task.delay(hold or 2.6, function()
			if b.token == token then
				local info = TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
				play(b, label, info, { TextTransparency = 1 })
				play(b, b.stroke, info, { Transparency = 1 })
				play(b, b.shadow, info, { TextTransparency = 1 })
				play(b, b.pop, info, { Scale = 0.85 })
				play(b, b.popShadow, info, { Scale = 0.85 })
			end
		end)
	end

	-- 3-2-1-GO, drawn from a phase (0 = the number just came, 1 = the next one is due). No tweens: it follows the
	-- server clock every frame, so it never stutters or drifts, and someone joining mid-count sees the right number.
	local function backOut(x)
		local c1 = 1.70158
		local c3 = c1 + 1
		return 1 + c3 * (x - 1) ^ 3 + c1 * (x - 1) ^ 2
	end
	local function drawCount(word, color, size, scale, transparency)
		local b = count
		if b.label.Text ~= word then
			b.label.Text, b.shadow.Text = word, word
		end
		b.label.TextColor3 = color
		b.label.TextSize, b.shadow.TextSize = size, size
		b.pop.Scale, b.popShadow.Scale = scale, scale
		b.label.TextTransparency, b.stroke.Transparency = transparency, transparency
		b.shadow.TextTransparency = 0.35 + 0.65 * transparency
	end
	local function hideCount()
		if count.label.TextTransparency < 1 then
			drawCount(count.label.Text, count.label.TextColor3, count.label.TextSize, 1, 1)
		end
	end
	-- a number: pop 1.4 -> 1 in 0.15 s (fading in, never a hard flash), hold, shrink to 0.85 and fade 0.72-0.94
	local function numberAt(t)
		if t < 0.15 then
			local x = t / 0.15
			return 1.4 - 0.4 * backOut(x), 1 - x
		elseif t < 0.72 then
			return 1, 0
		elseif t < 0.94 then
			local x = (t - 0.72) / 0.22
			return 1 - 0.15 * x * x, x * x
		end
		return 0.85, 1
	end
	-- GO!: bigger pop (1.6 -> 1 in 0.18 s), holds to 0.8 s, then grows a little as it fades (0.3 s)
	local function goAt(t)
		if t < 0.18 then
			local x = t / 0.18
			return 1.6 - 0.6 * backOut(x), 1 - x
		elseif t < 0.8 then
			return 1, 0
		elseif t < 1.1 then
			local x = (t - 0.8) / 0.3
			return 1 + 0.15 * x, x * x
		end
		return 1.15, 1
	end

	-- The message line: the latest news stays in a game (as in Huss Valley) and swaps instantly; outside a game it
	-- shows for a few seconds. The words take the news colour while Theme.MessageColour is on.
	local function messageColour(c)
		if not Theme.MessageColour or typeof(c) ~= "Color3" then
			return WHITE
		end
		if luma(c) < 0.38 then -- (a dark rarity colour on a dark outline would vanish: lift it)
			c = c:Lerp(WHITE, 0.45)
		end
		return c
	end
	-- Roblox fits the words to the box itself (TextScaled, 14 to 27); TextSize is set to about the same, for the
	-- offline preview, which draws TextSize.
	local function fitSize(msg)
		local w = 0
		for ch in string.gmatch(msg, utf8.charpattern) do
			w += if ch == " " then 0.3 elseif string.match(ch, "%u") then 0.74 elseif string.match(ch, "%d") then 0.66
				elseif string.match(ch, "%l") then 0.6 else 0.36
		end
		return math.clamp(math.floor(MSG_W / math.max(w, 1)), MSG_MIN, MSG_MAX)
	end
	local messageAt = 0
	local function setMessage(msg, color)
		message.Text = msg
		message.TextSize = fitSize(msg)
		message.TextColor3 = messageColour(color)
		messageAt = os.clock()
	end
	M.setMessage = setMessage -- (the offline preview)

	local function nameOf(id)
		local p = id and id ~= 0 and Players:GetPlayerByUserId(id)
		return p and p.DisplayName
	end

	-- Help lines for what you can do right now (short, one thing each).
	-- each control by its name on what you play with (UI/Device: a key, the controller's own button, or the button
	-- on a touch screen; owner, Oct 21: no PC words on a phone, iPad or PlayStation)
	local Device = require(UI.Device)
	local function key(action)
		return `<font color="#FFFFFF"><b>{Device.word(action) or ""}</b></font>`
	end
	local TIMED = { HeroRun = true, Running = true, Picking = true }
	local LOBBY_MESSAGE_TIME = 5
	M.extraHelp = nil -- (Gameplay/Onboarding can put a first-game tip here)
	local lastCount, goAt0, countEnd, popFrom
	local COUNT_FROM = Config.CountdownTime -- (3: a lead before it shows nothing)
	local function refresh()
		local stage = State:GetAttribute("Stage") or "Waiting"
		local now = Workspace:GetServerTimeNow()
		local left = math.max(0, (State:GetAttribute("EndsAt") or 0) - now)
		local inGame = (State:GetAttribute("Round") or 0) > 0 and stage ~= "Waiting" and stage ~= "Voting" and stage ~= "Intermission" and stage ~= "Rolling"
		-- Watching (not a runner or catcher in this game): the round's lines at the top step aside, so the lobby's
		-- SERVER LUCK sign shows clearly instead (owner, Oct 26 09:40: "when you arent in the round, make the server luck
		-- be seen and remove the last runners and things like that ... so they are more likely to boost it").
		local role = player:GetAttribute("HuzzRole")
		local watching = inGame and role ~= "Runner" and role ~= "Catcher"
		top.Visible = inGame and not watching
		-- the message: under the round line in a game; outside one, below the lobby's NEXT ROUND plate for a while
		local lobbyY = math.ceil((insetY() + 64 * Scale.hud(347)) / math.max(fit.Scale, 0.01)) + 6 -- (the plate is under the top bar)
		message.Position = UDim2.fromOffset(640, if inGame then MSG_Y_GAME else lobbyY)
		if not inGame and message.Text ~= "" and os.clock() - messageAt >= LOBBY_MESSAGE_TIME then
			message.Text = "" -- (so the next game doesn't open on the last game's news)
		end
		message.Visible = message.Text ~= "" and not watching
		if inGame then
			local goal = State:GetAttribute("Crossings") or Config.Crossings
			local streak = State:GetAttribute("Streak") or 0
			local left = State:GetAttribute("RunnersLeft") or 0
			roundLabel.Text = if State:GetAttribute("LastStanding")
				then `ROUND {State:GetAttribute("Round") or 0}<font color="#FFFFFF">  ·  {left} RUNNERS LEFT</font>`
				else `ROUND {State:GetAttribute("Round") or 0}<font color="#FFFFFF">  ·  {streak} OF {goal} IN A ROW</font>`
			local myRole, myStatus = player:GetAttribute("HuzzRole"), player:GetAttribute("HuzzStatus")
			local holding = State:GetAttribute("HolderId") == player.UserId
			local word, line
			if myRole == "Catcher" then
				word = "Catcher"
				line = if (stage == "Running" or stage == "HeroRun") then if Device.kind() == "touch" then `Tap {key("Stab")} to stab · tap {key("Abilities")}` else `{key("Stab")} to stab · {key("Abilities")} powers` else nil
			elseif myRole == "Runner" then
				if myStatus == "Downed" and player:GetAttribute("HuzzOut") then
					word, line = "Out", "You join the catchers next round"
				elseif myStatus == "Downed" then
					word, line = "Down", "Hold on. A runner can pick you up."
				elseif myStatus == "Safe" then
					word, line = "Safe", "You're across. Wait here."
				elseif player:GetAttribute("HuzzHero") then
					word, line = "Hero", if stage == "HeroRun" then "Solo run. Make it across!" else nil
				elseif holding then
					word, line = "Carrying", "Get her across!"
				else
					word = "Runner"
					line = if stage == "HeroRun" then "Hero's run. Wait on the line."
						elseif stage == "Running" then `Reach the <font color="#60E88C"><b>SAFE ZONE</b></font> · {if Device.kind() == "touch" then "tap " else ""}{key("Dash")} to dash`
						else nil
				end
			else
				word, line = "Watching", "You're in next game."
			end
			help.Text = if firstRound(State) then M.extraHelp or line or "" else ""
			if TIMED[stage] then
				local secs = math.ceil(left)
				local clock = string.format("%d:%02d", secs // 60, secs % 60)
				if secs <= 10 and stage == "Running" then
					clock = `<font color="#FF7882">{clock}</font>` -- (the last 10 seconds; no blinking)
				end
				roleLine.Text = `{word}  ·  {clock}`
			else
				roleLine.Text = word
			end
		end

		-- 3-2-1-GO. Straight after a camera shot (a CHICKEN pick, or no answer) the server's Countdown starts with a
		-- short lead while the camera swings back behind you (RoundService); nothing shows in it, so 3, 2 and 1
		-- each get a full second once the camera is back, and GO! lands on the server's start (the count's own
		-- EndsAt, the same moment on every screen). Nothing is drawn while the round camera is still in its shot.
		if stage == "Countdown" then
			countEnd = State:GetAttribute("EndsAt") or now
			local n = math.ceil(left)
			if n >= 1 and n <= COUNT_FROM and player:GetAttribute("HuzzCinematic") ~= true then
				if n ~= lastCount then
					Sfx.play("countdown_tick", { pitch = 1 + (3 - math.min(n, 3)) * 0.06 })
					popFrom = now
				end
				-- hold and fade follow the server's clock; the pop-in starts when this screen first draws the
				-- number, so with lag (or a late camera) "3" still pops in fully instead of arriving half faded
				local scale, transparency = numberAt(1 - (left - (n - 1)))
				local phase, sincePop = 1 - (left - (n - 1)), now - (popFrom or now)
				if sincePop < 0.15 and phase < 0.72 then -- (one first seen while fading just fades)
					local popScale, popFade = numberAt(sincePop)
					scale, transparency = popScale, math.max(popFade, transparency)
				end
				drawCount(tostring(n), WHITE, 104, scale, transparency)
				lastCount = n
			else
				hideCount()
			end
			goAt0 = nil
		elseif countEnd and stage == "Running" then
			goAt0 = math.min(countEnd, now)
			countEnd, lastCount = nil, nil
			Sfx.play("countdown_go")
		elseif stage ~= "Running" then
			countEnd, lastCount = nil, nil
		end
		if goAt0 and stage ~= "Countdown" then
			local t = now - goAt0
			if t < 1.1 then
				local scale, transparency = goAt(t)
				drawCount("GO!", GREEN, 124, scale, transparency)
			else
				goAt0 = nil
				hideCount()
			end
		elseif stage ~= "Countdown" then
			hideCount()
		end
	end
	-- Every frame, protected: if anything in it fails, the clock at the top still ticks (it's put right from the
	-- server's EndsAt below), and Output says what failed once a minute on a [HuzzUI] line (owner, Oct 25 16:07: "the
	-- timer at the top during the game" was stuck on the same numbers; the cause still needs his Output).
	local Report = require(UI.Report)
	RunService.RenderStepped:Connect(function()
		if Report.tick("RoundHud", refresh) then return end
		pcall(function()
			local stage = State:GetAttribute("Stage") or "Waiting"
			if not TIMED[stage] then return end
			local secs = math.ceil(math.max(0, (State:GetAttribute("EndsAt") or 0) - Workspace:GetServerTimeNow()))
			local clock = string.format("%d:%02d", secs // 60, secs % 60)
			local word = string.match(roleLine.Text, "^(.-)  ·  ") or roleLine.Text
			roleLine.Text = `{word}  ·  {clock}`
		end)
	end)
	M.refresh = refresh -- (the offline preview calls it)

	-- Your own name tag: faded as in Huss Valley, gone while the round's camera shots play (the pick shot put it
	-- 6% tall right under the top lines), and gone from the Hero run to the round's end. Others' tags stay as made.
	local OWN_TAG_FADE = 0.35
	local OWN_TAG_HIDDEN = { HeroRun = true, Countdown = true, Running = true, RoundOver = true }
	local ownTag
	local function styleOwnTag(tag)
		for _, name in { "Title", "PlayerName", "Sub" } do -- (not the HERO / CHICKEN word: that one stays bold)
			local line = tag:FindFirstChild(name)
			if line and line:IsA("TextLabel") then
				line.TextTransparency = OWN_TAG_FADE
				local outline = line:FindFirstChildOfClass("UIStroke")
				if outline then
					outline.Transparency = 0.55
				end
			end
		end
	end
	-- The big HERO / CHICKEN word over the picked runner's head has had its moment (the Chosen shot): it steps aside
	-- for 3-2-1 and GO! (on the line it sat right behind the numbers), then comes back. Local only.
	local quietWords: { [Instance]: boolean } = {} -- (a plain table: weak tables keyed by parts drop entries at random)
	local function quietTagWords()
		local quiet = State:GetAttribute("Stage") == "Countdown" or goAt0 ~= nil
		if quiet then
			for _, p in Players:GetPlayers() do
				local h = p.Character and p.Character:FindFirstChild("Head")
				local word = h and h:FindFirstChild("HuzzTag") and h.HuzzTag:FindFirstChild("Badge")
				if word and word:IsA("GuiObject") and word.Visible then
					word.Visible = false
					quietWords[word] = true
				end
			end
		elseif next(quietWords) then
			for word in quietWords do
				if word.Parent and word:IsA("TextLabel") then
					word.Visible = word.Text ~= "" -- (as NameTagService shows it)
				end
			end
			table.clear(quietWords)
		end
	end
	local function tagStep()
		quietTagWords()
		local character = player.Character
		local head = character and character:FindFirstChild("Head")
		local tag = head and head:FindFirstChild("HuzzTag")
		if not tag then
			ownTag = nil
			return
		end
		if tag ~= ownTag then
			ownTag = tag
			styleOwnTag(tag)
			tag.DescendantAdded:Connect(function()
				task.defer(styleOwnTag, tag)
			end)
		end
		local camera = Workspace.CurrentCamera
		local shot = player:GetAttribute("HuzzCinematic") == true or player:GetAttribute("HuzzChoosing") == true
			or (camera ~= nil and camera.CameraType == Enum.CameraType.Scriptable)
		-- from the Hero run to the round's end your own tag is gone: the round camera puts it 23-40% from the top,
		-- right where 3-2-1, SAFE! and YOU'RE DOWN print
		local clear = not OWN_TAG_HIDDEN[State:GetAttribute("Stage") or ""]
		-- in a shot your tag goes, except a HERO / CHICKEN word over your head (the push-in shows it), alone
		local badge = tag:FindFirstChild("Badge")
		local wordOnly = shot and badge ~= nil and badge.Visible
		for _, name in { "Title", "PlayerName", "Sub" } do
			local line = tag:FindFirstChild(name)
			if line then
				line.Visible = not wordOnly
			end
		end
		tag.Enabled = wordOnly or (not shot and clear)
	end
	RunService.RenderStepped:Connect(tagStep)
	M.tagStep = tagStep -- (the offline check calls it)

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
	-- The prize card shows before the run and between rounds, and steps aside while people run (owner: "make the
	-- screen look less full when playing ... a bit too much ui and can overwhelm the player").
	local RUNNING = { Running = true, HeroRun = true, Countdown = true }
	local function cardShown(): boolean
		return (State:GetAttribute("GirlName") or "") ~= "" and not RUNNING[State:GetAttribute("Stage") or ""]
	end
	State:GetAttributeChangedSignal("Stage"):Connect(function() card.Visible = cardShown() end)
	local function refreshCard()
		local girl = State:GetAttribute("GirlName") or ""
		card.Visible = cardShown()
		local rarity = State:GetAttribute("GirlRarity") or ""
		local color = rarityColor[rarity] or GOLD
		portraitRim.Color, rarityChip.BackgroundColor3 = color, color
		rarityChip.Text = string.upper(rarity)
		rarityChip.TextColor3 = if luma(color) > 0.55 then INK else WHITE
		girlName.Text = girl
		local who = nameOf(State:GetAttribute("HolderId"))
		holder.Text = if who then `{who} has her` else "Up for grabs"
		holder.TextColor3 = if who then WHITE else MUTED
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
		Out = { "Oh no!", "So close!", "Next time!" }, -- (caught on the last chance: nobody's coming)
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

	-- Outlines (Huss Valley: thin, see-through, no fill): red round catchers, dark blue round runners still out,
	-- yellow round the Hero, green round runners safe across the line, red round runners lying down (HV keeps a red
	-- outline on the caught; knife pass 2, was none).
	-- The catch (Shared/KnifeLook.CATCH.Fill, HV's hit read): the caught runner's outline fills red for 2 frames, then
	-- a red tint fading out by 0.42 s, on everyone's screen. The solid frames only when Gameplay/Burst.flashOk allows
	-- (at most one flash a second on a screen); otherwise just the tint.
	local OUTLINE_RED = Color3.fromRGB(235, 50, 60)
	local OUTLINE_BLUE = Color3.fromRGB(35, 95, 225)
	local OUTLINE_GREEN = Color3.fromRGB(60, 210, 110)
	local OUTLINE_YELLOW = Color3.fromRGB(255, 214, 70)
	local OUTLINE_SEE_THROUGH = 0.55 -- (feel-study gap 11; was 0.35)
	local highlights = {}
	local function refreshHighlight(p)
		local character = p.Character
		local r, st = p:GetAttribute("HuzzRole"), p:GetAttribute("HuzzStatus")
		local color = if r == "Catcher" then OUTLINE_RED
			elseif r == "Runner" and st == "Safe" then OUTLINE_GREEN
			elseif r == "Runner" and st == "Active" and p:GetAttribute("HuzzHero") then OUTLINE_YELLOW
			elseif r == "Runner" and st == "Active" then OUTLINE_BLUE
			elseif r == "Runner" and st == "Downed" then OUTLINE_RED
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
				Name = "HuzzOutline", FillTransparency = 1, OutlineTransparency = OUTLINE_SEE_THROUGH,
				DepthMode = Enum.HighlightDepthMode.Occluded, Parent = character,
			})
			highlights[p] = h
		end
		h.OutlineColor = color
		if not h:GetAttribute("HuzzHitAt") then h.FillColor = color end
	end
	local KnifeLook = require(Shared.KnifeLook)
	local Burst = require(script.Parent.Burst)
	local HIT_RED = Color3.fromRGB(255, 40, 40)
	local fills = {} -- Player -> { at, solid }
	local function hitFill(p)
		refreshHighlight(p) -- (the outline may not exist yet if the status hasn't arrived)
		local h = highlights[p]
		if not h then return end
		fills[p] = { at = os.clock(), solid = Burst.flashOk() }
		h:SetAttribute("HuzzHitAt", os.clock())
	end
	RunService.RenderStepped:Connect(function()
		local now = os.clock()
		for p, f in fills do
			local h = highlights[p]
			local tr = KnifeLook.catchFill(now - f.at, f.solid)
			if not (h and h.Parent) or tr >= 1 then
				if h and h.Parent then
					h.FillTransparency = 1
					h:SetAttribute("HuzzHitAt", nil)
					h.FillColor = h.OutlineColor
				end
				fills[p] = nil
			else
				h.FillColor = HIT_RED
				h.FillTransparency = tr
			end
		end
	end)
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

	-- Moments from the server. News goes to the message line; only your own big moments get centre words.
	RoundNet.OnClientEvent:Connect(function(kind, data)
		if kind == "Announce" then
			setMessage(data.text, data.color)
		elseif kind == "Caught" then
			local caught = type(data.runner) == "number" and Players:GetPlayerByUserId(data.runner)
			if caught then hitFill(caught) end
			if data.runner == player.UserId then
				sayLine(if data.final then "Out" else "Caught")
				-- (the red screen tint is Gameplay/Juice's: one effect, not two)
				-- second chance used up: say so plainly (owner: "after that if he gets caught its over")
				show(banner, if data.final then "YOU'RE OUT" else "YOU'RE DOWN", RED, 1.8, 60)
				if data.final then setMessage("No second chance: you join the catchers next round", RED) end
				Sfx.play("caught")
				Sfx.play("knock_down")
			elseif data.catcher == player.UserId then
				sayLine("Got") -- (the message line already says "<you> got <them>" for everyone)
				Sfx.play("stab", { pitch = 0.9 })
			end
		elseif kind == "Rescued" then
			if data.runner == player.UserId then
				show(banner, "BACK UP!", GREEN, 1.6, 64)
				setMessage("Second chance! Get caught again and you're out", GREEN)
				sayLine("Rescued")
				Sfx.play("revive")
			elseif data.by == player.UserId then
				sayLine("Rescuer")
				Sfx.play("rescue")
			end
		elseif kind == "Safe" then
			show(banner, "SAFE!", GREEN, 1.4, 72)
			sayLine("Safe")
			Sfx.play("safe")
		elseif kind == "First" then
			-- First across this round (Huss Valley: the name flies in big with FIRST over it)
			if data.id == player.UserId then
				show(banner, "FIRST!", GREEN, 1.8, 76) -- (comes right after SAFE! and takes its slot)
				Sfx.play("reward")
			else
				setMessage(`{data.name or "Someone"} is FIRST!`, GREEN)
			end
		elseif kind == "Bonus" then
			local text = `+{data.coins} coins` .. (if (data.aura or 0) > 0 then `  +{data.aura} Aura` else "")
			if data.late then
				-- (the game's pay: the results screen shows it after the win banners; only the coin sound here)
			else
				show(small, text, WHITE, 2.4) -- (the Hero bonus, under SAFE!)
			end
			task.delay(if data.late then 7.6 else 0, Sfx.play, "coin")
		elseif kind == "Win" then
			-- (the Practice Bot downing everyone is its win, never a player's)
			local team = if data.bot then "THE BOT WINS" elseif data.team == "Runners" then "RUNNERS WIN" else "CATCHERS WIN"
			local teamColor = if data.team == "Runners" then BLUE else RED
			show(banner, team, teamColor, 3.2, 76)
			local mine = player:GetAttribute("HuzzRole")
			if mine == "Runner" or mine == "Catcher" then
				local won = not data.bot and (data.team == "Runners") == (mine == "Runner")
				sayLine(if won then "Win" else "Lose")
				Sfx.play(if won then "round_win" else "round_lose")
			end
			setMessage(team, teamColor)
			local color = rarityColor[data.rarity] or GOLD
			task.delay(3.4, function()
				if data.winner == player.UserId then
					show(banner, `{string.upper(data.girl)} IS YOURS`, color, 4, 60)
					show(small, if data.lastCatch then "You caught the last runner!" else "Find her in your Index", WHITE, 4)
					Sfx.play("reward")
				elseif data.name and data.lastCatch then
					setMessage(`{data.name} caught the last runner and wins {data.girl}`, color)
				elseif data.name then
					setMessage(`{data.name} wins {data.girl}`, color)
				else
					setMessage(`Nobody wins {data.girl}`, WHITE)
				end
			end)
		end
	end)
end

return M
