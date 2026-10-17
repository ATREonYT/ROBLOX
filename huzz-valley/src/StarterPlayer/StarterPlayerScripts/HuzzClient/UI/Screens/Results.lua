-- Results (owner: "make it the best you can"; the match results screen on our open list): after each game, once the
-- win banners have played, a kit window shows how your game went: YOU WIN / YOU LOST / THE BOT WINS, who got the
-- girl, four cards (crossed, caught, saved, hero runs) and what you earned. The server sends the numbers in the Round
-- remote's "Results" event (RoundService finishGame: this game only). It opens in the lobby, never over another
-- window, and NICE! or the close button shuts it. The texts here are placeholders until a game fills them.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local UI = script.Parent.Parent
local Theme = require(UI.Theme)
local Kit = require(UI.Kit)
local ModalManager = require(UI.ModalManager)
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Net)
local RoundConfig = require(Shared.Config.Round)

local C = Theme.Colors
local F = Theme.Fonts
local new = Kit.new

local Results = {}

local W, H = 701, 320 -- every main window shares this size
local RED = Color3.fromRGB(255, 92, 104)
local DELAY = 8.2 -- seconds after the game ends: the win banners and "her name IS YOURS" play first
local CARD = { X = { 25, 191, 357, 523 }, Y = 120, W = 152, H = 100 } -- (the panel starts under the header: y 0 is the window top)
local CARDS = {
	{ Key = "crossed", Icon = "Sneaker", Label = "CROSSED" },
	{ Key = "catches", Icon = "TagFist", Label = "CAUGHT" },
	{ Key = "rescues", Icon = "Players", Label = "SAVED" },
	{ Key = "heroes", Icon = "TierCrown", Label = "HERO RUNS" },
}

local rarityColor = {}
for _, r in RoundConfig.Rarities do
	rarityColor[r.Name] = r.Color
end
rarityColor.Secret = Color3.fromRGB(150, 110, 255) -- (near-black in the roller; violet reads on the dark window)

local function card(parent: Instance, i: number, def)
	local f = new("Frame", {
		Name = "Card" .. i, Position = UDim2.fromOffset(CARD.X[i], CARD.Y), Size = UDim2.fromOffset(CARD.W, CARD.H),
		BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, Parent = parent,
	}, { Kit.corner(5), Kit.stroke(C.RowBorder, 1) })
	new("UIGradient", { Name = "Fill", Rotation = 90, Color = ColorSequence.new(C.RowTop, C.RowBottom), Parent = f })
	Kit.icon(def.Icon, { Name = "Icon", Position = UDim2.fromOffset(12, 10), Size = UDim2.fromOffset(38, 38), Parent = f })
	Kit.name({ Name = "Count", Text = "0", TextSize = 34, FontFace = F.Number, TextXAlignment = Enum.TextXAlignment.Right, Position = UDim2.fromOffset(58, 8), Size = UDim2.fromOffset(CARD.W - 72, 42), Parent = f })
	Kit.name({ Name = "Label", Text = def.Label, TextSize = 17, TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.fromOffset(0, 62), Size = UDim2.new(1, 0, 0, 26), Parent = f })
	return f
end

-- An earned amount: the coin or Aura picture with "+35" beside it.
local function earned(parent: Instance, name: string, icon: string, x: number)
	local f = new("Frame", { Name = name, BackgroundTransparency = 1, Position = UDim2.fromOffset(x, 240), Size = UDim2.fromOffset(150, 44), Parent = parent })
	Kit.icon(icon, { Name = "Icon", Position = UDim2.fromOffset(0, 2), Size = UDim2.fromOffset(40, 40), Parent = f })
	Kit.name({ Name = "Amount", Text = "+0", TextSize = 28, FontFace = F.Number, Position = UDim2.fromOffset(48, 0), Size = UDim2.fromOffset(100, 44), Parent = f })
	return f
end

local window, title, line, cards, coins, aura

-- Puts one game's numbers on the window (also used by the preview).
function Results.fill(data: { [string]: any })
	if not window then return end
	local outcome = data.outcome
	title.Text = if outcome == "Win" then "YOU WIN!" elseif outcome == "Bot" then "THE BOT WINS" else "YOU LOST"
	title.TextColor3 = if outcome == "Win" then C.Accent else RED
	local girl = tostring(data.girl or "")
	if data.gotGirl then
		line.Text = `{girl} is yours! Find her in your Index`
		line.TextColor3 = rarityColor[data.rarity] or C.Text
	elseif outcome == "Bot" then
		line.Text = "Nobody gets her this time. Use the huss to dodge!"
		line.TextColor3 = C.SubText
	else
		line.Text = if outcome == "Win" then `Your team won {girl}` else "So close! Try again next game"
		line.TextColor3 = C.SubText
	end
	for i, def in CARDS do
		cards[i].Count.Text = tostring(math.floor(tonumber(data[def.Key]) or 0))
	end
	coins.Amount.Text = `+{math.floor(tonumber(data.coins) or 0)}`
	aura.Amount.Text = `+{math.floor(tonumber(data.aura) or 0)}`
	aura.Visible = (tonumber(data.aura) or 0) > 0
end

function Results.build(parent: Instance)
	local player = Players.LocalPlayer
	window = Kit.window({ Name = "Results", Title = "GAME OVER", Icon = "RewardsTrophy", Width = W, Height = H, TitleWidth = 220, Parent = parent, OnClose = function() ModalManager.close() end })
	local panel = window.Panel
	title = Kit.name({ Name = "Outcome", Text = "YOU WIN!", TextSize = 34, FontFace = F.Big, TextColor3 = C.Accent, TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.fromOffset(0, 52), Size = UDim2.new(1, 0, 0, 38), Parent = panel })
	line = Kit.name({ Name = "Line", Text = "Your team won", TextSize = 18, TextColor3 = C.SubText, TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.fromOffset(20, 90), Size = UDim2.new(1, -40, 0, 24), Parent = panel })
	cards = {}
	for i, def in CARDS do
		cards[i] = card(panel, i, def)
	end
	coins = earned(panel, "Coins", "CurrencyCoin", 25)
	aura = earned(panel, "Aura", "AuraStar", 175)
	local ok = Kit.button({ Name = "Nice", Text = "NICE!", TextSize = 22, Position = UDim2.fromOffset(W - 25 - 176, 240), Size = UDim2.fromOffset(176, 44), Parent = panel })
	ok.onClick(function() ModalManager.close() end)

	ModalManager.register("Results", {
		window = window,
		firstSelect = function() return ok.Instance end,
		items = function() return cards end,
	})

	-- After a game: fill it, then open it once the banners are done (only if nothing else is open by then).
	local seq = 0
	Net.get("Round").OnClientEvent:Connect(function(kind, data)
		if kind ~= "Results" or type(data) ~= "table" then return end
		seq += 1
		local mine = seq
		Results.fill(data)
		task.delay(DELAY, function()
			for _ = 1, 12 do -- (back in the lobby first: wait up to 6 s more for it)
				if mine ~= seq then return end
				local role = player:GetAttribute("HuzzRole")
				if role ~= "Runner" and role ~= "Catcher" then
					if ModalManager.current() == nil then ModalManager.open("Results") end
					return
				end
				task.wait(0.5)
			end
		end)
	end)
	return window
end

return Results
