-- "Like the game" window (owner, Oct 23 19:44: "make the like the game present thing be able to press e on it and a
-- like the game pop up comes"): the LIKE THE GAME! gift in the lobby (Config/LobbyProps Like_Reward_Gift) opens it
-- from its prompt (E) or a click. A big thumbs up, how to like the game on its Roblox page, and OK.
-- No reward: Roblox can't tell a game who liked it, so nothing here pretends to check or pay.
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local UI = script.Parent.Parent
local Theme = require(UI.Theme)
local Kit = require(UI.Kit)
local ModalManager = require(UI.ModalManager)
local Effects = require(UI.Effects)

local new = Kit.new
local C, F = Theme.Colors, Theme.Fonts
local _ = Shared

local LikeGame = {}

local W, H = 440, 292

local function line(props: { [string]: any }, stroke: number?): TextLabel
	props.TextWrapped = props.TextWrapped == true
	local l = Kit.text(props)
	new("UIStroke", { Name = "Outline", Color = C.TitleStroke, Thickness = stroke or 1.5, LineJoinMode = Enum.LineJoinMode.Round, Parent = l })
	return l
end

function LikeGame.build(parent: Instance)
	local window = Kit.window({ Name = "LikeGame", Title = "LIKE THE GAME!", Icon = "GiftAction", Width = W, Height = H, TitleX = 56, TitleWidth = 260, StudsTo = 0, Parent = parent, OnClose = function() ModalManager.close() end })
	local panel = window.Panel
	-- the thumbs up, green, in a soft glow, bobbing gently
	local thumb = line({ Name = "Thumb", Text = "\u{1F44D}", FontFace = F.Heading, TextSize = 64, TextXAlignment = Enum.TextXAlignment.Center, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(W // 2, 47 + 48), Size = UDim2.fromOffset(90, 80), ZIndex = 4, Parent = panel }, 0)
	thumb:FindFirstChild("Outline"):Destroy()
	Effects.breathe(thumb, { scale = 1.08, seconds = 1.2 })
	line({ Name = "Ask", Text = "Having fun? Like the game!", FontFace = F.Heading, TextSize = 24, TextXAlignment = Enum.TextXAlignment.Center, TextColor3 = Color3.fromHex("8CF06A"), Position = UDim2.fromOffset(16, 47 + 92), Size = UDim2.fromOffset(W - 32, 30), ZIndex = 4, Parent = panel }, 2.5)
	line({ Name = "How", Text = "Press the thumbs up on the game's page on Roblox. It helps more players find Huzz Valley!", FontFace = F.Name, TextSize = 16, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.fromOffset(28, 47 + 124), Size = UDim2.fromOffset(W - 56, 40), ZIndex = 4, Parent = panel })
	local ok = Kit.button({ Name = "Ok", Text = "OK!", Style = "Action", FontFace = F.Button, TextSize = 22, Corner = 9, RimThickness = 2.5, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -14), Size = UDim2.fromOffset(180, 42), ZIndex = 5, Parent = panel })
	ok.onClick(function() ModalManager.close() end)
	ModalManager.register("LikeGame", {
		window = window,
		firstSelect = function() return ok.Instance end,
	})
	return window.Holder
end

return LikeGame
