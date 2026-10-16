--[[
	Round HUD: stage and timer, your role, the girl up for grabs and who holds
	her, big announcements, and faint outlines on everyone in the game: catchers red,
	runners blue (as in the reference).
	Built in code for now; it moves into the owner's UI kit with the Match HUD page.
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

	local player = Players.LocalPlayer
	local RoundNet = Net.get("Round") :: RemoteEvent
	local State = RoundNet -- the round state is this remote's attributes

	local HEAVY = Font.new("rbxasset://fonts/families/Montserrat.json", Enum.FontWeight.Heavy)
	local BOLD = Font.new("rbxasset://fonts/families/Montserrat.json", Enum.FontWeight.Bold)
	local CONDENSED = Font.new("rbxasset://fonts/families/RobotoCondensed.json", Enum.FontWeight.Bold)
	local PURPLE = Color3.fromRGB(108, 72, 214)
	local NAVY = Color3.fromRGB(32, 36, 74)
	local OUTLINE = Color3.fromRGB(20, 18, 40)
	local RED = Color3.fromRGB(255, 90, 90)
	local GOLD = Color3.fromRGB(255, 205, 80)

	local rarityColor = {}
	for _, r in Config.Rarities do
		rarityColor[r.Name] = r.Color
	end

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
		return make("UICorner", { CornerRadius = UDim.new(0, r) })
	end

	local function stroke(t, color)
		return make("UIStroke", { Thickness = t, Color = color or OUTLINE, ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual })
	end

	local function text(props)
		props.BackgroundTransparency = 1
		props.TextColor3 = props.TextColor3 or Color3.new(1, 1, 1)
		props.TextScaled = true
		return make("TextLabel", props, { stroke(1.5) })
	end

	local gui = make("ScreenGui", { Name = "HuzzRoundHud", ResetOnSpawn = false, IgnoreGuiInset = false, DisplayOrder = 5 })

	-- Status pill: stage + timer
	local pill = make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 72), Size = UDim2.fromOffset(300, 44),
		BackgroundColor3 = PURPLE, Parent = gui,
	}, { corner(12), stroke(2) })
	local status = text({ Size = UDim2.new(1, -20, 1, -10), Position = UDim2.fromOffset(10, 5), FontFace = HEAVY, Text = "", Parent = pill })

	-- Your role under it
	local role = text({
		AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 122), Size = UDim2.fromOffset(520, 28),
		FontFace = CONDENSED, Text = "", Parent = gui,
	})

	-- Prize card, top left
	local card = make("Frame", {
		Position = UDim2.fromOffset(12, 8), Size = UDim2.fromOffset(230, 74), BackgroundColor3 = NAVY, Visible = false, Parent = gui,
	}, { corner(10), stroke(2) })
	local stripe = make("Frame", { Size = UDim2.new(0, 8, 1, 0), BorderSizePixel = 0, Parent = card }, { corner(10) })
	text({ Position = UDim2.fromOffset(18, 6), Size = UDim2.fromOffset(120, 14), FontFace = CONDENSED, Text = "UP FOR GRABS", TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = Color3.fromRGB(190, 196, 255), Parent = card })
	local girlName = text({ Position = UDim2.fromOffset(18, 20), Size = UDim2.new(1, -26, 0, 24), FontFace = HEAVY, TextXAlignment = Enum.TextXAlignment.Left, Parent = card })
	local holder = text({ Position = UDim2.fromOffset(18, 48), Size = UDim2.new(1, -26, 0, 18), FontFace = BOLD, TextXAlignment = Enum.TextXAlignment.Left, Parent = card })

	-- Big centre message
	local banner = text({
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.3), Size = UDim2.fromOffset(760, 54),
		FontFace = HEAVY, Text = "", TextTransparency = 1, Parent = gui,
	})
	local bannerStroke = banner:FindFirstChildOfClass("UIStroke")
	local small = text({
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.38), Size = UDim2.fromOffset(500, 34),
		FontFace = HEAVY, Text = "", TextTransparency = 1, Parent = gui,
	})
	local smallStroke = small:FindFirstChildOfClass("UIStroke")
	local flash = make("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = RED, BackgroundTransparency = 1, ZIndex = 0, Parent = gui })

	gui.Parent = player:WaitForChild("PlayerGui")

	local baseSize = {}
	local function show(label, labelStroke, message, color, hold)
		baseSize[label] = baseSize[label] or label.Size
		label.Text = message
		label.TextColor3 = color or Color3.new(1, 1, 1)
		label.TextTransparency, labelStroke.Transparency = 0, 0
		label.Size = baseSize[label] + UDim2.fromOffset(0, 12)
		TweenService:Create(label, TweenInfo.new(0.25, Enum.EasingStyle.Back), { Size = baseSize[label] }):Play()
		local token = {}
		label:SetAttribute("Token", tostring(token))
		task.delay(hold or 2.6, function()
			if label:GetAttribute("Token") == tostring(token) then
				TweenService:Create(label, TweenInfo.new(0.4), { TextTransparency = 1 }):Play()
				TweenService:Create(labelStroke, TweenInfo.new(0.4), { Transparency = 1 }):Play()
			end
		end)
	end

	local function nameOf(id)
		local p = id and id ~= 0 and Players:GetPlayerByUserId(id)
		return p and p.DisplayName
	end

	-- Stage, timer and role text, refreshed every frame
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
	RunService.RenderStepped:Connect(function()
		local stage = State:GetAttribute("Stage") or "Waiting"
		local left = math.max(0, (State:GetAttribute("EndsAt") or 0) - Workspace:GetServerTimeNow())
		local label = string.format(STAGE_TEXT[stage] or stage, State:GetAttribute("Round") or 0)
		if stage == "Running" or stage == "Intermission" then
			local secs = math.ceil(left)
			label ..= string.format("  %d:%02d", secs // 60, secs % 60)
		end
		status.Text = label
		pill.Visible = stage ~= "Intermission" and stage ~= "Voting" and stage ~= "Rolling" -- the Lobby HUD, the vote window and the roller show those

		if stage == "Countdown" then
			local count = math.ceil(left)
			if count ~= lastCount and count > 0 then
				show(banner, bannerStroke, tostring(count), Color3.new(1, 1, 1), 0.8)
			end
			lastCount = count
		elseif lastCount and stage == "Running" then
			lastCount = nil
			show(banner, bannerStroke, "GO!", Color3.fromRGB(110, 230, 150), 0.8)
		end

		local myRole, myStatus = player:GetAttribute("HuzzRole"), player:GetAttribute("HuzzStatus")
		local holding = State:GetAttribute("HolderId") == player.UserId
		local girl = State:GetAttribute("GirlName") or ""
		if myRole == "Catcher" then
			local stab = Config.TagMode == "Stab"
			role.Text = if holding then `{girl} is following you! Keep {if stab then "stabbing" else "tagging"} runners`
				else `CATCHER — {if stab then "stab" else "tag"} the runners!`
			role.TextColor3 = RED
		elseif myRole == "Runner" then
			if myStatus == "Safe" then
				role.Text, role.TextColor3 = "SAFE! You run again next round", Color3.fromRGB(110, 230, 150)
			elseif myStatus == "Caught" then
				role.Text, role.TextColor3 = "CAUGHT! You'll get up as a catcher next round", Color3.fromRGB(200, 200, 210)
			elseif holding and State:GetAttribute("Phase") == "Final" then
				role.Text, role.TextColor3 = `FINAL ROUND — cross with {girl} to win her!`, GOLD
			elseif holding then
				role.Text, role.TextColor3 = `Carry {girl} across — first one across keeps her!`, GOLD
			else
				local free = (State:GetAttribute("HolderId") or 0) == 0
				role.Text = if girl == "" then "RUNNER — reach the other side!"
					elseif Config.Pickup == "Grab" and free then `RUNNER — grab {girl} in the middle, then reach the other side!`
					else `RUNNER — first one across gets {girl}!`
				role.TextColor3 = Color3.new(1, 1, 1)
			end
		else
			role.Text = if stage == "Waiting" or stage == "Intermission" or stage == "Voting" or stage == "Loading" or stage == "Rolling" then "" else "Watching — you'll play in the next game"
			role.TextColor3 = Color3.fromRGB(200, 200, 210)
		end
	end)

	-- Prize card
	local function refreshCard()
		local girl = State:GetAttribute("GirlName") or ""
		card.Visible = girl ~= ""
		local color = rarityColor[State:GetAttribute("GirlRarity")] or Color3.new(1, 1, 1)
		stripe.BackgroundColor3 = color
		girlName.Text = girl
		local who = nameOf(State:GetAttribute("HolderId"))
		holder.Text = if who then "Held by " .. who elseif Config.GirlSpot == "Sky" then "First one across gets her!"
			elseif Config.GirlSpot == "Middle" then "Waiting in the middle" else "Waiting across the field"
		holder.TextColor3 = if who then GOLD else Color3.fromRGB(190, 196, 255)
	end
	for _, name in { "GirlName", "GirlRarity", "HolderId" } do
		State:GetAttributeChangedSignal(name):Connect(refreshCard)
	end
	refreshCard()

	-- Outlines (as in the reference): a faint red line round catchers and a faint blue one round
	-- runners still in the round. Caught runners lying on the floor lose theirs.
	local OUTLINE_RED = Color3.fromRGB(255, 64, 64)
	local OUTLINE_BLUE = Color3.fromRGB(64, 150, 255)
	local highlights = {}
	local function refreshHighlight(p)
		local character = p.Character
		local r, st = p:GetAttribute("HuzzRole"), p:GetAttribute("HuzzStatus")
		local color = if r == "Catcher" then OUTLINE_RED elseif r == "Runner" and st ~= "Caught" then OUTLINE_BLUE else nil
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
		for _, attr in { "HuzzRole", "HuzzStatus" } do
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
				show(banner, bannerStroke, data.text, data.color)
			else
				show(small, smallStroke, data.text, data.color)
			end
		elseif kind == "Caught" then
			if data.runner == player.UserId then
				flash.BackgroundTransparency = 0.55
				TweenService:Create(flash, TweenInfo.new(0.6), { BackgroundTransparency = 1 }):Play()
				show(small, smallStroke, if nameOf(data.catcher) then `Tagged by {nameOf(data.catcher)}!` else "Caught!", RED)
			elseif data.catcher == player.UserId then
				show(small, smallStroke, `You tagged {nameOf(data.runner) or "a runner"}!`, RED)
			end
		elseif kind == "Win" then
			local color = rarityColor[data.rarity] or GOLD
			if data.winner == player.UserId then
				show(banner, bannerStroke, `YOU WON {string.upper(data.girl)}!`, color, 5)
				show(small, smallStroke, "Added to your inventory and index", Color3.new(1, 1, 1), 5)
			elseif data.name then
				show(banner, bannerStroke, `{data.name} wins {data.girl}!`, color, 5)
			else
				show(banner, bannerStroke, `Nobody won {data.girl} this time`, Color3.fromRGB(200, 200, 210), 5)
			end
		end
	end)
end

return M
