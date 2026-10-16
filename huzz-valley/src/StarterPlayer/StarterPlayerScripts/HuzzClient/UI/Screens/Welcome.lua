-- How to Play (owner: "make the onboarding for the game feel nice"): a kit window that opens by itself the first
-- time someone joins (once their save has loaded, in the lobby, nothing else open), and from the Menu any time.
-- Three cards slide up one after another: run across, save your friends, be the Hero. The controls sit along the
-- bottom next to a big LET'S GO. Closing it saves the TutorialDone setting, so it never pops up again on its own.
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local UI = script.Parent.Parent
local Theme = require(UI.Theme)
local Kit = require(UI.Kit)
local State = require(UI.State)
local ModalManager = require(UI.ModalManager)

local C = Theme.Colors
local F = Theme.Fonts
local new = Kit.new

local Welcome = {}

local W, H = 701, 320 -- every main window shares this size
local CARD = { X = { 18, 247, 476 }, Y = 60, W = 207, H = 176 }
local CARDS = {
	{ Icon = "Sneaker", Title = "RUN ACROSS", Text = "Reach the SAFE ZONE across the map without getting stabbed." },
	{ Icon = "Players", Title = "SAVE FRIENDS", Text = "Someone down? Stand next to them to pick them back up." },
	{ Icon = "CollectionBook", Title = "BE THE HERO", Text = "Picked? Go HERO and cross alone. Make it and she's yours." },
}

local function card(parent: Instance, i: number, def)
	local f = new("Frame", {
		Name = "Card" .. i, Position = UDim2.fromOffset(CARD.X[i], CARD.Y), Size = UDim2.fromOffset(CARD.W, CARD.H),
		BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, Parent = parent,
	}, { Kit.corner(5), Kit.stroke(C.RowBorder, 1) })
	new("UIGradient", { Name = "Fill", Rotation = 90, Color = ColorSequence.new(C.RowTop, C.RowBottom), Parent = f })
	-- the picture sits on the kit's lit blue backdrop (as the shop's cards)
	local back = new("Frame", { Name = "Backdrop", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 12), Size = UDim2.fromOffset(78, 78), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, Parent = f }, { Kit.corner(39) })
	new("UIGradient", { Name = "Glow", Rotation = 60, Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, Color3.fromHex("4F78EC")), ColorSequenceKeypoint.new(0.55, Color3.fromHex("3B47B8")), ColorSequenceKeypoint.new(1, Color3.fromHex("2A2475")) }), Parent = back })
	Kit.icon(def.Icon, { Name = "Icon", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(56, 56), Parent = back })
	-- the step number: a small gold square in the corner (the selected tab's gold)
	new("TextLabel", {
		Name = "Step", Text = tostring(i), FontFace = F.Number, TextSize = 16, TextColor3 = C.DarkText, BackgroundColor3 = C.SelectedTab,
		Position = UDim2.fromOffset(8, 8), Size = UDim2.fromOffset(26, 26), Parent = f,
	}, { Kit.corner(4), Kit.stroke(C.SelectedRim, 1) })
	Kit.name({ Name = "Title", Text = def.Title, TextSize = 19, TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.fromOffset(0, 98), Size = UDim2.new(1, 0, 0, 24), Parent = f })
	Kit.text({ Name = "Blurb", Text = def.Text, TextSize = 15, TextColor3 = C.SubText, TextXAlignment = Enum.TextXAlignment.Center, TextYAlignment = Enum.TextYAlignment.Top, Position = UDim2.fromOffset(10, 124), Size = UDim2.new(1, -20, 0, 50), Parent = f })
	return f
end

function Welcome.build(parent: Instance)
	local player = Players.LocalPlayer
	local window = Kit.window({ Name = "Welcome", Title = "HOW TO PLAY", Icon = "Players", Width = W, Height = H, TitleWidth = 230, Parent = parent, OnClose = function() ModalManager.close() end })
	local cards = {}
	for i, def in CARDS do
		cards[i] = card(window.Panel, i, def)
	end
	-- the controls, then LET'S GO
	local touch = UserInputService.TouchEnabled
	local function key(k: string) return `<font color="#FFFFFF"><b>{k}</b></font>` end
	Kit.text({
		Name = "Controls", RichText = true, TextSize = 16, TextColor3 = C.SubText, TextWrapped = false,
		Text = if touch then `{key("DASH")} button to dash   ·   {key("Q")} {key("E")} tiles for powers`
			else `{key("Space")} dash   ·   {key("Q")} {key("E")} powers   ·   {key("Click")} stab (catchers)   ·   {key("Alt")} mouse`,
		Position = UDim2.fromOffset(22, 252), Size = UDim2.fromOffset(470, 42), Parent = window.Panel,
	})
	local go = Kit.button({ Name = "Go", Text = "LET'S GO!", TextSize = 22, Position = UDim2.fromOffset(W - 22 - 176, 252), Size = UDim2.fromOffset(176, 44), Parent = window.Panel })
	go.onClick(function() ModalManager.close() end)

	ModalManager.register("Welcome", {
		window = window,
		onClose = function()
			if State.setting("TutorialDone") ~= true then
				task.spawn(State.setSetting, "TutorialDone", true)
			end
		end,
		firstSelect = function() return go.Instance end,
		items = function() return cards end,
	})

	-- First time here: open once the save has loaded, in the lobby, with nothing else open (if a round or a
	-- window is in the way, it waits for the lobby).
	local opened = false
	local function maybeOpen()
		if opened or not State.data.Loaded or State.setting("TutorialDone") == true then return end
		local role = player:GetAttribute("HuzzRole")
		if ModalManager.current() == nil and role ~= "Runner" and role ~= "Catcher" then
			opened = true
			task.delay(1.2, function()
				if ModalManager.current() == nil then ModalManager.open("Welcome") else opened = false end
			end)
		end
	end
	State.changed(maybeOpen)
	ModalManager.changed(function() task.defer(maybeOpen) end)
	player:GetAttributeChangedSignal("HuzzRole"):Connect(maybeOpen)
	maybeOpen()
	return window
end

return Welcome
