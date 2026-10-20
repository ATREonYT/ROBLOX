-- The ABILITIES window (owner, Oct 20 15:13: "Please then make the abilities be bought, add a few more abilities, but
-- make them well made"): pick which abilities you bring into a round and buy new ones with coins. Opened from the Menu
-- (MainMenu "Abilities"). Two tabs, RUNNER and CATCHER, each a grid of UI/AbilityCards (BUY / EQUIP, or Q and E for a
-- catcher); over them your loadout in one line per side; under them how much coins you have and that a change plays
-- from the next round (HuzzServer/PowerService reads the loadout when a round starts). Every buy and equip is the
-- server's call (ActionService "BuyAbility" / "EquipAbility", Shared/AbilityRules); this window only asks and shows.
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Powers = require(Shared.Config.Powers)
local AbilityRules = require(Shared.AbilityRules)
local UI = script.Parent.Parent
local Theme = require(UI.Theme)
local Kit = require(UI.Kit)
local State = require(UI.State)
local ModalManager = require(UI.ModalManager)
local AbilityCards = require(UI.AbilityCards)

local new = Kit.new
local C, F = Theme.Colors, Theme.Fonts

local Loadout = {}

local W, H = 660, 520
local PAD = 16
local LIST = { Y = 140, H = 520 - 140 - 46 }

local function line(props: { [string]: any }, stroke: number?): TextLabel
	props.TextWrapped = false
	local l = Kit.text(props)
	new("UIStroke", { Name = "Outline", Color = C.TitleStroke, Thickness = stroke or 1.5, LineJoinMode = Enum.LineJoinMode.Round, Parent = l })
	return l
end

local function nameOf(key: string): string
	if key == "Random" then return "RANDOM" end
	local d = Powers[key]
	return if d then string.upper(d.Name) else key
end

function Loadout.build(parent: Instance)
	local window = Kit.window({ Name = "Loadout", Title = "ABILITIES", Icon = "AbilityShield", Width = W, Height = H, TitleX = 56, TitleWidth = 150,
		Parent = parent, OnClose = function() ModalManager.close() end })
	local panel = window.Panel
	local runnerLine = line({ Name = "RunnerLoadout", Text = "", FontFace = F.Name, TextSize = 15, Position = UDim2.fromOffset(PAD + 2, 56),
		Size = UDim2.fromOffset(W - 2 * PAD, 20), ZIndex = 3, Parent = panel })
	local catcherLine = line({ Name = "CatcherLoadout", Text = "", FontFace = F.Name, TextSize = 15, Position = UDim2.fromOffset(PAD + 2, 78),
		Size = UDim2.fromOffset(W - 2 * PAD, 20), ZIndex = 3, Parent = panel })

	-- the cards scroll inside the window (a ScrollingFrame clips square and cuts the rows' outside rims: padded)
	local list = new("ScrollingFrame", { Name = "List", Position = UDim2.fromOffset(PAD - 4, LIST.Y), Size = UDim2.fromOffset(W - 2 * PAD + 8, LIST.H),
		BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 4, ScrollBarImageColor3 = C.RowBorder, CanvasSize = UDim2.new(),
		ScrollingDirection = Enum.ScrollingDirection.Y, ZIndex = 2, Parent = panel })
	Kit.attach(Kit.pad(4, 4, 4, 4), list)
	local gridW = W - 2 * PAD - 8
	local grids = {
		Runner = AbilityCards.build(list, { side = "Runner", width = gridW }),
		Catcher = AbilityCards.build(list, { side = "Catcher", width = gridW }),
	}
	local function show(side: string)
		for s, g in grids do g.frame.Visible = s == side end
		list.CanvasSize = UDim2.fromOffset(0, grids[side].height + 8)
		list.CanvasPosition = Vector2.zero
	end
	local tabs = Kit.tabs(panel, {
		{ Key = "Runner", Text = "RUNNER", X = PAD, Width = 140 },
		{ Key = "Catcher", Text = "CATCHER", X = PAD + 148, Width = 140 },
	}, 104, 30, show)

	local coins = line({ Name = "Coins", Text = "", FontFace = F.Number, TextSize = 15, TextColor3 = C.Accent, Position = UDim2.fromOffset(PAD + 26, H - 38),
		Size = UDim2.fromOffset(200, 22), ZIndex = 3, Parent = panel }, 1.2)
	Kit.icon("CurrencyCoin", { Name = "CoinIcon", Position = UDim2.fromOffset(PAD + 2, H - 38), Size = UDim2.fromOffset(22, 22), ZIndex = 3, Parent = panel })
	line({ Name = "Note", Text = "Changes play from the next round.", FontFace = F.Body, TextSize = 13, TextColor3 = C.NoteText,
		TextXAlignment = Enum.TextXAlignment.Right, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -PAD, 1, -38), Size = UDim2.fromOffset(320, 22),
		ZIndex = 3, Parent = panel }, 1)

	local function refresh()
		local data = State.data or {}
		local l = AbilityRules.loadout(data)
		runnerLine.Text = string.format("RUNNER   Q: %s   ·   E: SPEED BOOST (with the girl)", nameOf(l.Runner))
		catcherLine.Text = string.format("CATCHER   Q: %s   ·   E: %s", nameOf(l.CatcherQ), nameOf(l.CatcherE))
		coins.Text = tostring(if type(data.Coins) == "number" then data.Coins else 0)
	end
	tabs.select("Runner")
	show("Runner")

	local open = false
	ModalManager.register("Loadout", {
		window = window,
		onOpen = function(arg)
			open = true
			local side = if arg == "Catcher" then "Catcher" else "Runner"
			tabs.select(side)
			show(side)
			refresh()
			for _, g in grids do g.refresh() end
		end,
		onClose = function() open = false end,
		firstSelect = function() return tabs.buttons.Runner.Instance end,
	})
	State.changed(function() if open then refresh() end end)
	refresh()
	return window.Holder
end

return Loadout
