-- NEXT MAP (owner's call, Huss Valley's own panel): once you've voted (or closed the vote window), the vote tucks
-- into this small panel at the top left so you can keep shopping: both maps side by side with their votes, your
-- pick outlined green, the time left, and an arrow that opens the full vote again. When the vote ends the winner
-- turns green ("NEXT MAP") and the other says "Voting ended", for a few seconds into the girl roll.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Net = require(Shared.Net)
local Config = require(Shared.Config.Round)
local UI = script.Parent.Parent
local Theme = require(UI.Theme)
local Kit = require(UI.Kit)
local Scale = require(UI.Scale)
local Motion = require(UI.Motion)
local ModalManager = require(UI.ModalManager)

local C = Theme.Colors
local F = Theme.Fonts
local new = Kit.new

local NextMap = {}

local W, H = 330, 122
local TILE = { W = 155, H = 56, Y = 34, Gap = 10 }
local PAGE_H = 347 -- the HUD reference height (as LobbyHud)
local SHOW_AFTER = 6 -- seconds the result stays up once the vote ends

local function displayName(name: string): string
	return Config.Map.Names[name] or (name:gsub("_?[Mm][Aa][Pp]$", ""):gsub("_", " "))
end

local function tile(parent: Instance, i: number)
	local f = new("Frame", {
		Name = "Map" .. i, Position = UDim2.fromOffset((i - 1) * (TILE.W + TILE.Gap), TILE.Y), Size = UDim2.fromOffset(TILE.W, TILE.H),
		BackgroundColor3 = C.Panel, BackgroundTransparency = 0.2, BorderSizePixel = 0, Parent = parent,
	}, { Kit.corner(8) })
	Kit.studPattern(f, 0.25)
	-- The owner's map picture behind the text (Config.Map.Pictures), darker on the left where the words sit.
	local photo = Kit.art("MapBase", { Name = "Photo", Size = UDim2.fromScale(1, 1), Visible = false, Parent = f })
	Kit.attach(Kit.corner(8), photo)
	local veil = new("Frame", { Name = "Veil", Size = UDim2.fromScale(1, 1), BackgroundColor3 = C.Panel, BorderSizePixel = 0, Visible = false, Parent = f }, { Kit.corner(8) })
	new("UIGradient", { Name = "Fade", Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(0.55, 0.7), NumberSequenceKeypoint.new(1, 0.95) }), Parent = veil })
	local rim = Kit.stroke(C.Frame, 2)
	rim.Name = "Rim"
	rim = Kit.attach(rim, f) :: UIStroke
	local name = Kit.name({ Name = "MapName", Text = "", TextSize = 15, ZIndex = 2, Position = UDim2.fromOffset(10, 6), Size = UDim2.new(1, -16, 0, 20), TextTruncate = Enum.TextTruncate.AtEnd, Parent = f })
	local sub = Kit.text({ Name = "Status", Text = "", FontFace = F.Body, TextSize = 14, TextColor3 = C.SubText, ZIndex = 2, Position = UDim2.fromOffset(10, 30), Size = UDim2.new(1, -16, 0, 18), TextWrapped = false, Parent = f })
	return { frame = f, rim = rim, name = name, sub = sub, photo = photo, veil = veil }
end

function NextMap.build(parent: Instance)
	local player = Players.LocalPlayer
	local round = Net.get("Round") :: RemoteEvent
	local panel = new("Frame", { Name = "NextMap", Position = UDim2.fromOffset(14, 10), Size = UDim2.fromOffset(W, H), BackgroundTransparency = 1, Visible = false, Parent = parent })
	Scale.bind(new("UIScale", { Name = "FitScale", Parent = panel }), function() return Scale.hud(PAGE_H) end)
	Kit.title({ Name = "Title", Text = "NEXT MAP", TextSize = 20, Position = UDim2.fromOffset(2, 0), Size = UDim2.fromOffset(200, 28), Parent = panel })
	local open = Kit.button({ Name = "Open", Text = "", Style = "Tab", Icon = "ArrowNext", IconSize = 18, Position = UDim2.fromOffset(W - 38, 0), Size = UDim2.fromOffset(38, 28), Corner = 6, Parent = panel })
	local arrow = open.Instance:FindFirstChild("Icon", true)
	if arrow and arrow:IsA("GuiObject") then arrow.Rotation = -45 end -- (points up and out: "open it again")
	local tiles = { tile(panel, 1), tile(panel, 2) }
	local foot = Kit.text({ Name = "Foot", Text = "", FontFace = F.Body, TextSize = 14, Position = UDim2.fromOffset(2, TILE.Y + TILE.H + 6), Size = UDim2.fromOffset(W, 18), TextWrapped = false, Parent = panel })
	new("UIStroke", { Name = "Outline", Color = C.Frame, Thickness = 1.2, Parent = foot }) -- (around the letters, not a box)

	open.onClick(function() ModalManager.open("MapVote") end)

	local endedAt = nil
	local wasShown = false
	local function refresh()
		local stage = round:GetAttribute("Stage")
		local a, b = round:GetAttribute("VoteA") or "", round:GetAttribute("VoteB") or ""
		local winner = round:GetAttribute("VoteWinner")
		local voting = stage == "Voting"
		if voting then
			endedAt = nil
		elseif winner and winner ~= "" and endedAt == nil then
			endedAt = os.clock()
		end
		local showResult = not voting and endedAt ~= nil and os.clock() - endedAt < SHOW_AFTER
		local show = a ~= "" and ((voting and ModalManager.current() ~= "MapVote") or showResult)
		panel.Visible = show
		if show and not wasShown then Motion.pop(panel) end
		wasShown = show
		if not show then return end
		local mine = player:GetAttribute("HuzzVote")
		local counts = { round:GetAttribute("VoteCountA") or 0, round:GetAttribute("VoteCountB") or 0 }
		for i, name in { a, b } do
			local t = tiles[i]
			t.name.Text = string.upper(displayName(name))
			local pic = Config.Map.Pictures and Config.Map.Pictures[name]
			t.photo.Visible = pic ~= nil
			t.veil.Visible = pic ~= nil
			if pic then Kit.setArt(t.photo, pic) end
			local won = showResult and winner == name
			local picked = voting and mine == name
			if voting then
				local votes = if counts[i] == 1 then "1 vote" else `{counts[i]} votes`
				t.sub.Text = if picked then `YOUR VOTE · {votes}` else votes
			else
				t.sub.Text = if won then "NEXT MAP" else "Voting ended"
			end
			t.sub.TextColor3 = if won or picked then C.Accent else C.SubText
			t.rim.Color = if won or picked then C.Accent else C.Frame
			t.rim.Thickness = if won or picked then 2.5 else 2
			t.frame.BackgroundTransparency = if showResult and not won then 0.45 else 0.2
		end
		open.Instance.Visible = voting
		if voting then
			local left = math.max(0, math.ceil((round:GetAttribute("EndsAt") or 0) - Workspace:GetServerTimeNow()))
			foot.Text = if mine then `Voting ends in {left}s` else `Pick a map · {left}s`
		else
			foot.Text = "Get ready!"
		end
	end
	RunService.Heartbeat:Connect(refresh)
	NextMap.refresh = refresh -- (the offline preview calls it)
	refresh()
	return panel
end

return NextMap
