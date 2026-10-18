-- Choose a Map (design/pages/15): two map cards with the owner's picture of each map (else a live view of it), the vote count, and a VOTE button
-- (your choice turns gold: YOUR VOTE, gold rim). The timer is the server's real vote deadline. It opens by itself
-- when the server starts a vote (Round remote Stage = "Voting") and closes when the vote ends; closing it early
-- keeps your vote. One vote per player; voting again moves it (MapVoteService on the server).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Net)
local Config = require(Shared.Config.Round)
local UI = script.Parent.Parent
local Theme = require(UI.Theme)
local Kit = require(UI.Kit)
local ModalManager = require(UI.ModalManager)

local C = Theme.Colors
local new = Kit.new
local hex = Color3.fromHex

local MapVote = {}

local W, H = 701, 320 -- every main window shares this size
-- Measured on page 15 (668 x 289 window), scaled to 701 x 320.
local CARD = { X = { 24, 358 }, Y = 58, W = 319, H = 252, Name = 160, Votes = 187, BtnY = 203, BtnH = 39, BtnInset = 25 }
local COL = {
	Rim = hex("3F7CDB"), RimSelected = Theme.Colors.Accent, Card = hex("1C2440"), Shade = hex("161E36"),
	Pill = hex("1B2A57"), PillRim = hex("0E1A44"),
}

-- Same as the server: "Zone A" = ZoneA, and the name shown is the folder name without "_Map".
local function key(name: string): string return (string.gsub(name, "[%s_%-]", "")):lower() end
local function displayName(name: string): string
	return Config.Map.Names[name] or (name:gsub("_?[Mm][Aa][Pp]$", ""):gsub("_", " "))
end

-- A live picture of the map: its stored copy in a ViewportFrame, seen from above one side of the field.
local function showMap(viewport: ViewportFrame, name: string)
	for _, c in viewport:GetChildren() do
		if c:GetAttribute("RuntimeOnly") then c:Destroy() end
	end
	local source = ReplicatedStorage:FindFirstChild("HuzzMaps") and ReplicatedStorage.HuzzMaps:FindFirstChild(name)
	if not source then return end
	local copy = source:Clone()
	copy:SetAttribute("RuntimeOnly", true)
	for _, d in copy:GetDescendants() do
		if d:IsA("LuaSourceContainer") then d:Destroy() end -- a picture only: nothing in it may run on this screen
	end
	local a, b, mid
	for _, c in copy:GetChildren() do
		local k = key(c.Name)
		if k == "zonea" then a = c elseif k == "zoneb" then b = c elseif k == "middle" then mid = c end
	end
	Kit.attach(copy, viewport)
	if not (a and b and mid) then return end
	local centre = mid.Position
	local run = (b.Position - a.Position) * Vector3.new(1, 0, 1)
	local half = run.Magnitude / 2
	local across = run.Unit:Cross(Vector3.yAxis)
	local cam = new("Camera", { Name = "MapCamera", FieldOfView = 50, Parent = viewport })
	cam:SetAttribute("RuntimeOnly", true)
	cam.CFrame = CFrame.lookAt(centre + across * half * 0.95 + Vector3.yAxis * half * 0.55, centre + Vector3.yAxis * 4)
	viewport.CurrentCamera = cam
end

local function card(parent: Instance, i: number, onVote: () -> ())
	local f = new("Frame", {
		Name = "Card" .. i, Position = UDim2.fromOffset(CARD.X[i], CARD.Y), Size = UDim2.fromOffset(CARD.W, CARD.H),
		BackgroundColor3 = COL.Card, BorderSizePixel = 0, ClipsDescendants = false, Parent = parent,
	}, { Kit.corner(7) })
	local rim = Kit.stroke(COL.Rim, 2)
	rim.Name = "Rim" -- named before attaching, so the saved StarterGui copy is found and reused
	rim = Kit.attach(rim, f) :: UIStroke
	-- The picture fills the card; its lower part fades to navy so the text reads (as on the page).
	local view = new("ViewportFrame", {
		Name = "Picture", Size = UDim2.fromScale(1, 1), BackgroundColor3 = hex("6FA8E8"), BorderSizePixel = 0,
		Ambient = Color3.fromRGB(170, 170, 185), LightColor = Color3.fromRGB(255, 248, 235), LightDirection = Vector3.new(-1, -2, -0.6),
		Parent = f,
	}, { Kit.corner(7) })
	-- The owner's picture of the map (Config.Map.Pictures) covers the live view when the map has one.
	local photo = Kit.art("MapBase", { Name = "Photo", Size = UDim2.fromScale(1, 1), Visible = false, Parent = f })
	Kit.attach(Kit.corner(7), photo)
	local shade = new("Frame", { Name = "Shade", Size = UDim2.fromScale(1, 1), BackgroundColor3 = COL.Shade, BorderSizePixel = 0, ZIndex = 2, Parent = f }, { Kit.corner(7) })
	new("UIGradient", {
		Name = "Fade", Rotation = 90,
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.45, 1), NumberSequenceKeypoint.new(0.62, 0.25), NumberSequenceKeypoint.new(1, 0.08) }),
		Parent = shade,
	})
	local name = Kit.title({
		Name = "MapName", Text = "", TextSize = 24, TextXAlignment = Enum.TextXAlignment.Center,
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0, CARD.Name), Size = UDim2.new(1, -20, 0, 28), ZIndex = 3, Parent = f,
	})
	local votes = Kit.name({
		Name = "Votes", Text = "", TextSize = 18, TextXAlignment = Enum.TextXAlignment.Center,
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0, CARD.Votes), Size = UDim2.new(1, -20, 0, 22), ZIndex = 3, Parent = f,
	})
	local btn = Kit.button({
		Name = "Vote", Text = "VOTE", Style = "Action", TextSize = 20, ZIndex = 3,
		Position = UDim2.fromOffset(CARD.BtnInset, CARD.BtnY), Size = UDim2.fromOffset(CARD.W - 2 * CARD.BtnInset, CARD.BtnH), Parent = f, OnClick = onVote,
	})
	return { frame = f, rim = rim, view = view, photo = photo, name = name, votes = votes, button = btn, shown = nil }
end

function MapVote.build(parent: Instance)
	local window = Kit.window({
		Name = "MapVote", Title = "CHOOSE A MAP", Icon = "Map", Width = W, Height = H, TitleSize = 24, TitleX = 63,
		TitleWidth = 196, StudsTo = W - 236, Parent = parent, OnClose = function() ModalManager.close() end,
	})
	local round = Net.get("Round") :: RemoteEvent
	local vote = Net.get("Vote") :: RemoteEvent
	local player = Players.LocalPlayer

	-- "VOTING ENDS IN 8s": a navy pill in the header, left of the close square.
	local pill = new("Frame", {
		Name = "Timer", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -46, 0.5, 0), Size = UDim2.fromOffset(170, 30),
		BackgroundColor3 = COL.Pill, BorderSizePixel = 0, Parent = window.Header,
	}, { Kit.corner(6) })
	Kit.attach(Kit.stroke(COL.PillRim, 1.5), pill)
	local timer = Kit.text({
		Name = "Text", Text = "", FontFace = Theme.Fonts.Button, TextSize = 17, TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.fromScale(1, 1), Parent = pill,
	})

	local cards = {}
	local names = { "", "" }
	for i = 1, 2 do
		cards[i] = card(window.Body.Parent :: Instance, i, function()
			if names[i] ~= "" then
				vote:FireServer(names[i])
				-- (owner: after voting the vote tucks into the NEXT MAP panel at the top left, Screens/NextMap)
				task.delay(0.45, function()
					if ModalManager.current() == "MapVote" then ModalManager.close() end
				end)
			end
		end)
	end

	local tick: () -> ()
	local function refresh()
		if tick then tick() end
		local mine = player:GetAttribute("HuzzVote")
		names = { round:GetAttribute("VoteA") or "", round:GetAttribute("VoteB") or "" }
		local counts = { round:GetAttribute("VoteCountA") or 0, round:GetAttribute("VoteCountB") or 0 }
		for i, c in cards do
			local n = names[i]
			c.name.Text = string.upper(displayName(n))
			c.votes.Text = if counts[i] == 1 then "1 vote" else `{counts[i]} votes`
			local chosen = mine ~= nil and mine == n
			c.button.setStyle(if chosen then "Selected" else "Action")
			c.button.setText(if chosen then "YOUR VOTE" else "VOTE")
			c.rim.Color = if chosen then COL.RimSelected else COL.Rim
			c.rim.Thickness = if chosen then 3 else 2
			if c.shown ~= n and n ~= "" then
				c.shown = n
				local pic = Config.Map.Pictures and Config.Map.Pictures[n]
				c.photo.Visible = pic ~= nil
				c.view.Visible = pic == nil
				if pic then Kit.setArt(c.photo, pic) else showMap(c.view, n) end
			end
		end
	end
	for _, attr in { "VoteA", "VoteB", "VoteCountA", "VoteCountB" } do
		round:GetAttributeChangedSignal(attr):Connect(refresh)
	end
	player:GetAttributeChangedSignal("HuzzVote"):Connect(refresh)

	-- The real deadline, counted down.
	function tick()
		local left = math.max(0, math.ceil((round:GetAttribute("EndsAt") or 0) - Workspace:GetServerTimeNow()))
		timer.Text = `VOTING ENDS IN {left}s`
	end
	RunService.Heartbeat:Connect(function()
		if window.Holder.Visible then tick() end
	end)

	-- Opens when a vote starts, closes when it ends.
	-- (a kid in the Shop or watching the Spin Wheel isn't thrown out of it: the vote opens once that window shuts;
	-- the NEXT MAP panel takes votes meanwhile)
	local pending = false
	local function onStage()
		if round:GetAttribute("Stage") == "Voting" then
			refresh()
			local open = ModalManager.current()
			if open == nil or open == "MapVote" then
				ModalManager.open("MapVote")
			else
				pending = true
			end
		else
			pending = false
			if ModalManager.current() == "MapVote" then ModalManager.close() end
		end
	end
	ModalManager.changed(function()
		if pending and ModalManager.current() == nil and round:GetAttribute("Stage") == "Voting" then
			pending = false
			refresh()
			ModalManager.open("MapVote")
		end
	end)
	round:GetAttributeChangedSignal("Stage"):Connect(onStage)

	ModalManager.register("MapVote", {
		window = window,
		noBlur = true, -- it opens by itself for everyone; keep the world sharp behind it (owner: too blurry)
		onOpen = refresh,
		firstSelect = function() return cards[1].button.Instance end,
		items = function() return { cards[1].frame, cards[2].frame } end,
	})
	refresh()
	task.defer(onStage)
	return window
end

return MapVote
