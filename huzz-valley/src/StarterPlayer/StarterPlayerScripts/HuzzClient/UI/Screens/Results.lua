-- The winner page (owner, Oct 19: "winner page", his picture design/owner-oct19/pic-a-winner-page.png; the top half
-- of it, one to one in our kit's look: the JOURNEY / PREMIUM half below is a paid season pass we don't have).
-- After each game, once the win banners have played: "RUNNERS WIN" / "CATCHERS WIN" (or THE BOT WINS) with the tab's
-- line under it ("Most Catches"), "Next match · 12s" top left (the lobby's real NextRoundAt clock, hidden without
-- one), MVP / Survival / Catches tabs, the top 3 as cards (#2 left, #1 bigger in the middle, #3 right; ties are
-- "Joint #3" like his) with each player's Roblox avatar (Players:GetUserThumbnailAsync, guarded: a person icon
-- shows until it loads or when it can't), your "+XP" with where it came from ("Crossings +15 · Win +40"), the
-- coins and Aura you earned on the left, "Level Up!" and your girl line on the right, and your level bar
-- ("Lvl 3 ... 173/300 XP ... Lvl 4"). Gold is out (owner): his orange #1 rim, numbers and bar are our green.
-- The server sends the numbers in the Round remote's "Results" event (RoundService finishGame: board = everyone's
-- numbers, team, xp, coins...); the rankings are Shared/Standings, the XP parts Config/Progression.xpParts.
-- It opens in the lobby, never over another window; the close button shuts it.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local UI = script.Parent.Parent
local Theme = require(UI.Theme)
local Kit = require(UI.Kit)
local State = require(UI.State)
local ModalManager = require(UI.ModalManager)
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Net)
local RoundConfig = require(Shared.Config.Round)
local Progression = require(Shared.Config.Progression)
local Standings = require(Shared.Standings)

local C = Theme.Colors
local F = Theme.Fonts
local new = Kit.new

local Results = {}

local W, H, HEADER = 701, 334, 58
local SUB = Color3.fromRGB(255, 92, 120) -- his pink-red line under the title ("Most Catches")
local DELAY = 8.2 -- seconds after the game ends: the win banners and "her name IS YOURS" play first
-- the three cards, measured on his picture (scaled 0.649 to our 701 wide window): #2 left, #1 middle (bigger), #3 right
local CARDS = {
	[1] = { X = 241, Y = 90, W = 219, H = 142, Avatar = 112, Name = 17, Stat = 21 },
	[2] = { X = 38, Y = 96, W = 191, H = 130, Avatar = 100, Name = 15, Stat = 18 },
	[3] = { X = 472, Y = 96, W = 191, H = 130, Avatar = 100, Name = 15, Stat = 18 },
}
local TAB = { Y = 64, H = 24, X = { 174, 294, 414 }, W = 113 }

local rarityColor = {}
for _, r in RoundConfig.Rarities do
	rarityColor[r.Name] = r.Color
end
rarityColor.Secret = Color3.fromRGB(150, 110, 255) -- (near-black in the roller; violet reads on the dark window)

local function outlined(props: { [string]: any }, thickness: number?): TextLabel
	props.TextWrapped = false
	local l = Kit.text(props)
	new("UIStroke", { Name = "Outline", Color = C.TitleStroke, Thickness = thickness or 1.5, LineJoinMode = Enum.LineJoinMode.Round, Parent = l })
	return l
end

local window, title, sub, nextMatch, tabs, cards, empty, xpLine, xpParts, coinsLine, auraLine, levelUp, girlLine
local levelFrom, levelTo, levelFill, levelText
local last: { [string]: any } = {}
local shownTab = "MVP"
local thumbs: { [number]: string } = {}

-- One player's avatar on a card: the person icon until Roblox sends the picture.
local function avatar(card: any, userId: number?)
	card.Face.Image = ""
	card.Fallback.Visible = true
	if type(userId) ~= "number" then return end
	local want = userId
	card.Want = want
	local function show(url: string)
		if card.Want == want and url ~= "" then
			card.Face.Image = url
			card.Fallback.Visible = false
		end
	end
	if thumbs[userId] then show(thumbs[userId]); return end
	task.spawn(function()
		local ok, url = pcall(function()
			return Players:GetUserThumbnailAsync(userId, Enum.ThumbnailType.AvatarBust, Enum.ThumbnailSize.Size180x180)
		end)
		if ok and type(url) == "string" and url ~= "" then
			thumbs[userId] = url
			show(url)
		end
	end)
end

local function makeCard(parent: Instance, i: number)
	local d = CARDS[i]
	local f = new("Frame", {
		Name = "Place" .. i, Position = UDim2.fromOffset(d.X, d.Y), Size = UDim2.fromOffset(d.W, d.H),
		BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = Theme.Transparency.Row, BorderSizePixel = 0, ZIndex = 2, Parent = parent,
	}, { Kit.corner(6), Kit.stroke(if i == 1 then C.Accent else C.RowBorder, if i == 1 then 3 else 2) })
	new("UIGradient", { Name = "Fill", Rotation = 90, Color = ColorSequence.new(C.RowTop, C.RowBottom), Parent = f })
	local fallback = Kit.icon("Players", { Name = "Fallback", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, math.floor(d.Avatar * 0.22)), Size = UDim2.fromOffset(math.floor(d.Avatar * 0.6), math.floor(d.Avatar * 0.6)), ImageTransparency = 0.35, ZIndex = 3, Parent = f })
	local face = new("ImageLabel", { Name = "Avatar", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 2), Size = UDim2.fromOffset(d.Avatar, d.Avatar), BackgroundTransparency = 1, Image = "", ScaleType = Enum.ScaleType.Fit, ZIndex = 3, Parent = f })
	local place = outlined({ Name = "Rank", Text = "#" .. i, FontFace = F.Big, TextSize = if i == 1 then 18 else 16, TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.fromOffset(0, 4), Size = UDim2.new(1, 0, 0, 20), ZIndex = 5, Parent = f }, 1.6)
	local name = outlined({ Name = "PlayerName", Text = "", FontFace = F.Name, TextSize = d.Name, TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.new(0, 6, 1, -(d.Stat + d.Name + 10)), Size = UDim2.new(1, -12, 0, d.Name + 4), ZIndex = 5, Parent = f }, 1.6)
	local stat = outlined({ Name = "Stat", Text = "", FontFace = F.Big, TextSize = d.Stat, TextColor3 = C.Accent, TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.new(0, 6, 1, -(d.Stat + 7)), Size = UDim2.new(1, -12, 0, d.Stat + 4), ZIndex = 5, Parent = f }, 1.8)
	return { Instance = f, Face = face, Fallback = fallback, Rank = place, Name = name, Stat = stat, Size = d }
end

local function showTab(key: string)
	shownTab = key
	local t = Standings.tab(key)
	sub.Text = t.Sub
	if tabs then tabs.select(key) end
	local top = Standings.top(last.board or {}, key, 3)
	for i, c in cards do
		local r = top[i]
		c.Instance.Visible = r ~= nil
		if r then
			c.Rank.Text = Standings.placeText(r)
			c.Name.Text = tostring(r.entry.name or "")
			Kit.fitLine(c.Name, c.Size.W - 12, c.Size.Name, 11, true)
			c.Stat.Text = Standings.text(key, r.value)
			avatar(c, tonumber(r.entry.user))
		end
	end
	empty.Visible = #top == 0
	empty.Text = if key == "Catches" then "No catches this game" elseif key == "Survival" then "Nobody crossed this game" else "No points this game"
end

-- Your level bar from your saved XP (refreshed when the page opens: the save has the game's XP by then).
local function showLevel()
	local xp = tonumber(State.data.XP) or 0
	local level, into, per = Progression.level(xp)
	levelFrom.Text = `Lvl {level}`
	levelTo.Text = `Lvl {level + 1}`
	levelFill.Size = UDim2.fromScale(math.clamp(into / per, 0, 1), 1)
	levelFill.Visible = into > 0
	levelText.Text = `{into}/{per} XP`
end

local function showNextMatch()
	local at = workspace:GetAttribute("NextRoundAt")
	local left = if type(at) == "number" then math.ceil(at - workspace:GetServerTimeNow()) else nil
	nextMatch.Visible = left ~= nil and left > 0
	if nextMatch.Visible then nextMatch.Text = `Next match · {left}s` end
end

-- Puts one game's numbers on the page (also used by the preview).
function Results.fill(data: { [string]: any })
	if not window then return end
	last = data
	local outcome = data.outcome
	if outcome == "Bot" or data.bot then
		title.Text = "THE BOT WINS"
	elseif data.team == "Catchers" then
		title.Text = "CATCHERS WIN"
	elseif data.team == "Runners" then
		title.Text = "RUNNERS WIN"
	else
		title.Text = if outcome == "Win" then "YOU WIN!" else "GAME OVER"
	end
	showTab(Standings.defaultTab(data.team, outcome == "Bot" or data.bot == true))
	-- your XP and where it came from
	local gained = math.floor(tonumber(data.xp) or 0)
	xpLine.Text = `+{gained} XP`
	xpLine.Visible = gained > 0
	local parts = {}
	for _, p in Progression.xpParts(outcome == "Win", { Crossings = tonumber(data.crossed) or 0, Catches = tonumber(data.catches) or 0, Rescues = tonumber(data.rescues) or 0, HeroPaid = tonumber(data.heroPaid) or 0 }) do
		table.insert(parts, `{p.Name} +{p.XP}`)
	end
	xpParts.Text = table.concat(parts, "  ·  ")
	Kit.fitLine(xpParts, 330, 13, 10, true)
	-- what you earned
	coinsLine.Amount.Text = `+{math.floor(tonumber(data.coins) or 0)}`
	auraLine.Amount.Text = `+{math.floor(tonumber(data.aura) or 0)}`
	auraLine.Instance.Visible = (tonumber(data.aura) or 0) > 0
	levelUp.Visible = tonumber(data.level) ~= nil
	levelUp.Text = if tonumber(data.level) then `Level Up!` else ""
	-- the girl: yours, a spare copy, or who took her
	local girl = tostring(data.girl or "")
	if data.gotGirl and tonumber(data.dupeCoins) then
		girlLine.Text = `Spare {girl}: +{math.floor(data.dupeCoins)} coins, prestige her!`
		girlLine.TextColor3 = rarityColor[data.rarity] or C.Text
	elseif data.gotGirl then
		girlLine.Text = `{girl} is yours!`
		girlLine.TextColor3 = rarityColor[data.rarity] or C.Text
	elseif type(data.winnerName) == "string" and girl ~= "" then
		girlLine.Text = `{data.winnerName} takes {girl} home`
		girlLine.TextColor3 = C.SubText
	else
		girlLine.Text = if girl ~= "" then `Nobody won {girl}` else ""
		girlLine.TextColor3 = C.SubText
	end
	Kit.fitLine(girlLine, 196, 13, 10, true)
	showLevel()
end

function Results.build(parent: Instance)
	local player = Players.LocalPlayer
	window = Kit.window({ Name = "Results", Title = "", Icon = "RewardsTrophy", Width = W, Height = H, HeaderHeight = HEADER, TitleWidth = 0, StudsTo = 0, Flat = true, Parent = parent, OnClose = function() ModalManager.close() end })
	local panel = window.Panel
	-- header: next match (left), the title and its line (middle), close (right)
	nextMatch = outlined({ Name = "NextMatch", Text = "", FontFace = F.Big, TextSize = 15, Position = UDim2.fromOffset(66, 18), Size = UDim2.fromOffset(160, 24), ZIndex = 3, Visible = false, Parent = panel }, 1.5)
	title = outlined({ Name = "Outcome", Text = "RUNNERS WIN", FontFace = F.Big, TextSize = 27, TextXAlignment = Enum.TextXAlignment.Center, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 6), Size = UDim2.fromOffset(330, 30), ZIndex = 3, Parent = panel }, 2.2)
	sub = outlined({ Name = "Sub", Text = "Most Catches", FontFace = F.Big, TextSize = 14, TextColor3 = SUB, TextXAlignment = Enum.TextXAlignment.Center, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 36), Size = UDim2.fromOffset(240, 17), ZIndex = 3, Parent = panel }, 1.4)

	local defs = {}
	for i, t in Standings.Tabs do
		table.insert(defs, { Key = t.Key, Text = t.Text, X = TAB.X[i], Width = TAB.W })
	end
	tabs = Kit.tabs(panel, defs, TAB.Y, TAB.H, function(key) showTab(key) end, 13)

	cards = {}
	for i = 1, 3 do cards[i] = makeCard(panel, i) end
	empty = outlined({ Name = "Empty", Text = "", FontFace = F.Name, TextSize = 18, TextColor3 = C.SubText, TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.fromOffset(0, 150), Size = UDim2.new(1, 0, 0, 24), ZIndex = 3, Visible = false, Parent = panel })

	-- your game: earned (left), XP (middle), Level Up! and the girl (right)
	local function earned(name: string, icon: string, x: number)
		local f = new("Frame", { Name = name, BackgroundTransparency = 1, Position = UDim2.fromOffset(x, 242), Size = UDim2.fromOffset(86, 30), ZIndex = 3, Parent = panel })
		Kit.icon(icon, { Name = "Icon", AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 0, 0.5, 0), Size = UDim2.fromOffset(26, 26), ZIndex = 3, Parent = f })
		local amount = outlined({ Name = "Amount", Text = "+0", FontFace = F.Number, TextSize = 19, Position = UDim2.fromOffset(31, 0), Size = UDim2.fromOffset(56, 30), ZIndex = 3, Parent = f }, 1.6)
		return { Instance = f, Amount = amount }
	end
	coinsLine = earned("EarnedCoins", "CurrencyCoin", 24)
	auraLine = earned("EarnedAura", "AuraStar", 112)
	xpLine = outlined({ Name = "XPGain", Text = "+0 XP", FontFace = F.Big, TextSize = 22, TextColor3 = C.Accent, TextXAlignment = Enum.TextXAlignment.Center, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 238), Size = UDim2.fromOffset(200, 26), ZIndex = 3, Parent = panel }, 2)
	xpParts = outlined({ Name = "XPParts", Text = "", FontFace = F.Big, TextSize = 13, TextXAlignment = Enum.TextXAlignment.Center, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 264), Size = UDim2.fromOffset(330, 16), ZIndex = 3, Parent = panel }, 1.3)
	levelUp = outlined({ Name = "LevelUp", Text = "", FontFace = F.Big, TextSize = 16, TextColor3 = C.Accent, TextXAlignment = Enum.TextXAlignment.Right, Position = UDim2.fromOffset(W - 24 - 196, 240), Size = UDim2.fromOffset(196, 20), ZIndex = 3, Visible = false, Parent = panel }, 1.6)
	girlLine = outlined({ Name = "GirlLine", Text = "", FontFace = F.Big, TextSize = 13, TextXAlignment = Enum.TextXAlignment.Right, Position = UDim2.fromOffset(W - 24 - 196, 262), Size = UDim2.fromOffset(196, 18), ZIndex = 3, Parent = panel }, 1.3)

	-- the level band across the foot: Lvl 3 [bar 173/300 XP] Lvl 4
	local band = new("Frame", { Name = "LevelBand", Position = UDim2.fromOffset(4, 286), Size = UDim2.new(1, -8, 0, H - 4 - 286), BackgroundColor3 = C.TrackRim, BackgroundTransparency = 0.45, BorderSizePixel = 0, ZIndex = 2, Parent = panel }, { Kit.corner(3) })
	levelFrom = outlined({ Name = "From", Text = "Lvl 1", FontFace = F.Heading, TextSize = 16, TextXAlignment = Enum.TextXAlignment.Right, Position = UDim2.fromOffset(20, 12), Size = UDim2.fromOffset(60, 20), ZIndex = 3, Parent = band }, 1.5)
	local track = new("Frame", { Name = "Track", Position = UDim2.fromOffset(88, 14), Size = UDim2.fromOffset(519, 16), BackgroundColor3 = C.Row, BorderSizePixel = 0, ZIndex = 3, Parent = band }, { Kit.corner(8), Kit.stroke(C.TitleStroke, 2) })
	levelFill = new("Frame", { Name = "Fill", Size = UDim2.fromScale(0.5, 1), BackgroundColor3 = C.SelectedTab, BorderSizePixel = 0, ZIndex = 4, Parent = track }, { Kit.corner(8) })
	new("UIGradient", { Rotation = 90, Color = ColorSequence.new(C.SelectedTabTop, C.SelectedTab), Parent = levelFill })
	levelText = outlined({ Name = "Amount", Text = "", FontFace = F.Number, TextSize = 11, TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.fromScale(1, 1), ZIndex = 5, Parent = track }, 1.2)
	levelTo = outlined({ Name = "To", Text = "Lvl 2", FontFace = F.Heading, TextSize = 16, Position = UDim2.fromOffset(617, 12), Size = UDim2.fromOffset(60, 20), ZIndex = 3, Parent = band }, 1.5)

	local open = false
	ModalManager.register("Results", {
		window = window,
		onOpen = function()
			open = true
			showLevel()
			showNextMatch()
			task.spawn(function()
				while open do
					task.wait(0.5)
					if open then showNextMatch() end
				end
			end)
		end,
		onClose = function() open = false end,
		firstSelect = function() return tabs.buttons[shownTab] and tabs.buttons[shownTab].Instance end,
	})
	Results.fill({ outcome = "Win", team = "Runners", board = {} })

	-- After a game: fill it, then open it once the banners are done, the moment you're in the lobby with nothing
	-- else open (the map vote pops up right after a game; the results wait until you've voted and it tucks away).
	-- A new game starting first drops them.
	local waiting, readyAt = false, 0
	local function tryOpen()
		if not waiting or os.clock() < readyAt then return end
		local role = player:GetAttribute("HuzzRole")
		if role == "Runner" or role == "Catcher" then
			if os.clock() > readyAt + 2 then waiting = false end -- (already in the next game: too late for them)
			return
		end
		if ModalManager.current() == nil then
			waiting = false
			ModalManager.open("Results")
		end
	end
	Net.get("Round").OnClientEvent:Connect(function(kind, data)
		if kind ~= "Results" or type(data) ~= "table" then return end
		Results.fill(data)
		waiting, readyAt = true, os.clock() + DELAY
		task.delay(DELAY, tryOpen)
	end)
	ModalManager.changed(function() task.delay(0.3, tryOpen) end)
	task.spawn(function()
		while window.Holder.Parent do
			task.wait(1)
			tryOpen()
		end
	end)
	return window
end

return Results
