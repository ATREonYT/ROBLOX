--!strict
-- +1 Chess Evolution: the Studio-only badge preview (and the offline picture of it).
-- Build(config) -> a ScreenGui "ChessBadgePreview" with every badge, its name, its glyph and
-- when the live game shows it ("Preview only" when no live fight can trigger it yet).
-- Scenarios(config, Battle, Badges) -> printable lines for the five test fights.
-- Run it from Studio's Command Bar with tools/studio/BadgePreview.lua (edit mode, no Play needed).

local BadgeArt = require(script.Parent:WaitForChild("BadgeArt"))

local BadgePreview = {}

local INK = Color3.fromRGB(28, 26, 40)
local WHITE = Color3.new(1, 1, 1)
local FONT = Font.fromEnum(Enum.Font.FredokaOne)

local function new(className: string, props: { [string]: any }, parent: Instance?): any
	local inst = Instance.new(className)
	for k, v in props do
		(inst :: any)[k] = v
	end
	if parent then
		inst.Parent = parent
	end
	return inst
end

local function text(parent: Instance, name: string, props: { [string]: any }, strokeT: number?): TextLabel
	local t = new("TextLabel", { Name = name, BackgroundTransparency = 1, FontFace = FONT, TextColor3 = WHITE, TextSize = 20, Text = "" }, nil)
	for k, v in props do
		(t :: any)[k] = v
	end
	new("UIStroke", { Thickness = strokeT or 2, Color = INK, Name = "Outline" }, t)
	t.Parent = parent
	return t
end

function BadgePreview.Build(config: any): ScreenGui
	local gui = new("ScreenGui", { Name = "ChessBadgePreview", ResetOnSpawn = false, DisplayOrder = 50, ZIndexBehavior = Enum.ZIndexBehavior.Sibling })
	local panel = new("Frame", {
		Name = "Panel",
		BackgroundColor3 = Color3.fromRGB(44, 46, 66),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(1100, 560),
	}, gui)
	new("UICorner", { CornerRadius = UDim.new(0, 18) }, panel)
	new("UIStroke", { Thickness = 4, Color = INK }, panel)
	text(panel, "Title", { Text = "Battle badges · Studio preview", TextSize = 34, Size = UDim2.new(1, 0, 0, 52), Position = UDim2.fromOffset(0, 8) }, 3)
	local grid = new("Frame", { Name = "Grid", BackgroundTransparency = 1, Position = UDim2.fromOffset(20, 66), Size = UDim2.new(1, -40, 1, -86) }, panel)
	new("UIGridLayout", { CellSize = UDim2.fromOffset(250, 150), CellPadding = UDim2.fromOffset(16, 14), SortOrder = Enum.SortOrder.LayoutOrder, HorizontalAlignment = Enum.HorizontalAlignment.Center }, grid)
	for i, key in BadgeArt.Order do
		local look = config.BadgeLook[key]
		local cell = new("Frame", { Name = key, BackgroundColor3 = Color3.fromRGB(30, 32, 48), LayoutOrder = i }, grid)
		new("UICorner", { CornerRadius = UDim.new(0, 14) }, cell)
		new("UIStroke", { Thickness = 3, Color = INK }, cell)
		local disc = new("Frame", { Name = "Disc", AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 14, 0, 50), Size = UDim2.fromOffset(72, 72), ZIndex = 2 }, cell)
		BadgeArt.Paint(disc, key, look)
		text(cell, "Label", { Text = look.label, TextSize = 28, TextColor3 = look.color:Lerp(WHITE, 0.35), TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.fromOffset(96, 14), Size = UDim2.new(1, -104, 0, 32) }, 3)
		text(cell, "Glyph", { Text = if look.shape == "circle" then look.glyph else "", TextSize = 22, TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.fromOffset(96, 48), Size = UDim2.new(1, -104, 0, 24) }, 2)
		local live = BadgeArt.Live[key]
		text(cell, "When", {
			Text = live or "Preview only: no live fight uses it yet",
			TextSize = 16,
			TextWrapped = true,
			TextColor3 = if live then Color3.fromRGB(205, 210, 230) else Color3.fromRGB(255, 200, 120),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Top,
			Position = UDim2.fromOffset(14, 96),
			Size = UDim2.new(1, -28, 0, 44),
		}, 1.5)
	end
	return gui
end

-- The five fights from the brief, through the real meter and evaluator.
function BadgePreview.Scenarios(config: any, Battle: any, Badges: any): { string }
	local lines = {}
	local function path(points: { { number } }): { { number } }
		local samples, t, i = {}, 0, 1
		while t <= points[#points][1] + 1e-9 do
			while points[i + 1] and t > points[i + 1][1] do
				i += 1
			end
			local a, b = points[i], points[i + 1] or points[i]
			local f = if b[1] > a[1] then (t - a[1]) / (b[1] - a[1]) else 0
			table.insert(samples, { t, a[2] + (b[2] - a[2]) * f })
			t += 0.1
		end
		return samples
	end
	local function show(name: string, log: { { any } }, outcome: string)
		local keys = {}
		for _, e in log do
			table.insert(keys, `{e[2]} @{string.format("%.1f", e[1])}s`)
		end
		table.insert(lines, `[ChessBadges] {name} ({outcome}): {if #keys > 0 then table.concat(keys, ", ") else "no badges"}`)
	end
	local fight = config.Stages.Stage1.fight
	local win, winSamples = Battle.Simulate(fight, 2.5, 0.1)
	show("normal win, 2.5 taps/s", Badges.Run(config.Badges, fight.grace, winSamples, win.outcome), win.outcome)
	local idle, idleSamples = Battle.Simulate(fight, 0, 0.1)
	show("no-input loss", Badges.Run(config.Badges, fight.grace, idleSamples, idle.outcome), idle.outcome)
	local cfg = config.Badges
	show("short pause and recovery", Badges.Run(cfg, 1, path({ { 0, 50 }, { 3, 50 }, { 5, 37 }, { 6, 37 }, { 7, 52 }, { 10, 70 }, { 13, 100 } }), "win"), "win")
	show("deep comeback win", Badges.Run(cfg, 1, path({ { 0, 50 }, { 2, 48 }, { 6, 18 }, { 7.5, 18 }, { 10, 62 }, { 11, 66 }, { 13, 100 } }), "win"), "win")
	show("failed recovery", Badges.Run(cfg, 1, path({ { 0, 50 }, { 2, 46 }, { 5, 30 }, { 7, 47 }, { 9, 30 }, { 11, 8 }, { 12, 6 }, { 13, 0 } }), "lose"), "lose")
	return lines
end

return BadgePreview
