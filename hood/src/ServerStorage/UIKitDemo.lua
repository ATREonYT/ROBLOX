-- Sample screens built with UIKit, to judge the look before wiring anything into the game.
-- Command Bar (edit mode):  require(game.ServerStorage.UIKitDemo).Show()      -- shows the HUD
--                           require(game.ServerStorage.UIKitDemo).Show('Shop') -- HUD + Drip Shop
--                           require(game.ServerStorage.UIKitDemo).Hide()
-- The screens go into CoreGui while editing, so they are never saved into the place or seen by players.
local Demo = {}

local ReplicatedStorage = game:GetService('ReplicatedStorage')

local function load()
	return require(ReplicatedStorage.Shared.UIKit), require(ReplicatedStorage.Shared.Config.Skins)
end

-- HUD: currencies top-left, actions left-middle, utilities right-middle, objective bottom-centre.
function Demo.hud(parent)
	local Kit, Skins = load()
	local gui, root = Kit.screen('HoodHUDPreview', parent, 10)
	local C, U = Kit.Color, UDim2

	-- Currencies.
	local top = Kit.new('Frame', { Name = 'Currencies', BackgroundTransparency = 1, Position = U.fromOffset(18, 10), Size = U.fromOffset(300, 140), Parent = root })
	Kit.new('UIListLayout', { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder, Parent = top })
	Kit.currency({ Name = 'Power', Icon = 'power', Text = Kit.short(12480), Width = 250, Height = 48, LayoutOrder = 1 }).Parent = top
	Kit.currency({ Name = 'Cash', Icon = 'cash', Text = Kit.short(3250), Width = 210, Height = 40, LayoutOrder = 2 }).Parent = top
	local rate = Kit.new('Frame', { Name = 'Rate', BackgroundColor3 = Kit.Tone.yellow.base, Size = U.fromOffset(150, 26), LayoutOrder = 3, Parent = top })
	Kit.corner(UDim.new(0.5, 0)).Parent = rate
	Kit.stroke(C.ink, 2.5, true).Parent = rate
	Kit.text({ Text = '+24/SEC  x6', FontFace = Kit.Font.number, TextSize = 16, Stroke = Kit.Tone.yellow.stroke, Parent = rate })

	-- Main actions: two columns, vertically centred on the left edge (clear of the thumbstick).
	local left = Kit.new('Frame', { Name = 'Actions', BackgroundTransparency = 1, Position = U.fromOffset(22, 176), Size = U.fromOffset(176, 300), Parent = root })
	Kit.new('UIGridLayout', { CellSize = U.fromOffset(76, 90), CellPadding = U.fromOffset(16, 8), SortOrder = Enum.SortOrder.LayoutOrder, Parent = left })
	local actions = {
		{ 'Shop', 'outfits', 'DRIP', 1 }, { 'Crew', 'crew', 'CREW' }, { 'Rebirth', 'rebirth', 'REBIRTH' },
		{ 'Daily', 'gift', 'DAILY', '!' }, { 'Codes', 'codes', 'CODES' }, { 'Train', 'train', 'GYM' },
	}
	for i, a in actions do
		local cell = Kit.new('Frame', { Name = a[1], BackgroundTransparency = 1, LayoutOrder = i, Parent = left })
		Kit.sideButton({ Name = 'Button', Icon = a[2], Text = a[3], Badge = a[4], Tilt = (i % 2 == 0) and 4 or -4 }).Parent = cell
	end

	-- Utilities on the right.
	local right = Kit.new('Frame', { Name = 'Utilities', BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 0.5), Position = U.new(1, -18, 0.5, -20), Size = U.fromOffset(64, 230), Parent = root })
	Kit.new('UIListLayout', { Padding = UDim.new(0, 14), SortOrder = Enum.SortOrder.LayoutOrder, Parent = right })
	for i, u in { { 'Boards', 'trophy' }, { 'Stages', 'stages' }, { 'Settings', 'settings' } } do
		Kit.sideButton({ Name = u[1], Icon = u[2], Size = 62, LayoutOrder = i }).Parent = right
	end

	-- Objective, bottom centre.
	local nextSkin = Skins.ById.Enforcer
	Kit.objective({ Icon = 'train', Text = 'Punch the HEAVY BAG to train x6', Progress = '1.2K / ' .. Kit.short(nextSkin.Required) .. '  >  ' .. string.upper(nextSkin.Name), Value = 0.8, Width = 440, AnchorPoint = Vector2.new(0.5, 1), Position = U.new(0.5, 0, 1, -16) }).Parent = root

	-- A toast, top centre.
	Kit.toast({ Text = 'STAGE 2 CLEARED!', Icon = 'stages', Tone = 'green', Width = 300, AnchorPoint = Vector2.new(0.5, 0), Position = U.new(0.5, 0, 0, 14) }).Parent = root
	return gui, root
end

-- Drip Shop: the 15 looks as rarity cards, the selected look in a detail column with the big action.
function Demo.shop(root, which)
	local Kit, Skins = load()
	local U = UDim2
	local panel, well = Kit.modal(root, { Name = 'DripShop', Title = 'DRIP SHOP', Width = 940, Height = 600, TitleWidth = 330 })
	panel.Size = U.new(0, 940, 1, -70)
	Kit.new('UISizeConstraint', { MaxSize = Vector2.new(940, 600), Parent = panel })
	panel.Parent.Shadow.Size = panel.Size
	Kit.new('UISizeConstraint', { MaxSize = Vector2.new(940, 600), Parent = panel.Parent.Shadow })

	local power = 1240
	local equipped = 'Lookout'
	local selected = Skins.ById[which or 'Crook']
	local grid = Kit.new('ScrollingFrame', {
		Name = 'Looks', BackgroundTransparency = 1, BorderSizePixel = 0, Position = U.fromOffset(12, 12), Size = U.new(1, -282, 1, -24),
		ScrollBarThickness = 8, ScrollBarImageColor3 = Kit.Color.cardboardEdge, AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = U.new(), ZIndex = 23, Parent = well,
	})
	Kit.new('UIGridLayout', { CellSize = U.fromOffset(112, 156), CellPadding = U.fromOffset(10, 10), SortOrder = Enum.SortOrder.LayoutOrder, Parent = grid })
	Kit.new('UIPadding', { PaddingTop = UDim.new(0, 8), PaddingLeft = UDim.new(0, 8), Parent = grid })
	for i, s in Skins.List do
		local tier = math.clamp(math.ceil(i / 3), 1, 5) + (i == #Skins.List and 1 or 0)
		local state = s.Id == equipped and 'equipped' or (power >= s.Required and 'owned') or (i > 8 and 'locked') or nil
		local card = Kit.card({
			Name = s.Id, Title = string.upper(s.Name), Rarity = tier, Price = s.Required == 0 and 'FREE' or Kit.short(s.Required),
			State = state, Requirement = Kit.short(s.Required) .. ' POWER', Preview = 'portrait:' .. s.Id, Selected = s == selected,
			Width = 112, Height = 156, LayoutOrder = i, ZIndex = 24,
		})
		card.Parent = grid
	end

	-- Detail column: big preview on top, stats stacked under it, the one big action pinned to the bottom.
	local detail = Kit.new('Frame', { Name = 'Detail', BackgroundColor3 = Kit.Color.cardboard, AnchorPoint = Vector2.new(1, 0), Position = U.new(1, -12, 0, 12), Size = U.new(0, 252, 1, -24), ZIndex = 23, Parent = well })
	Kit.corner(Kit.Radius.m).Parent = detail
	Kit.stroke(Kit.Color.ink, 3, true).Parent = detail
	local stack = Kit.new('Frame', { Name = 'Info', BackgroundTransparency = 1, Position = U.fromOffset(10, 10), Size = U.new(1, -20, 1, -100), ZIndex = 24, Parent = detail })
	Kit.new('UIListLayout', { Padding = UDim.new(0, 6), HorizontalAlignment = Enum.HorizontalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder, Parent = stack })
	local tier = Kit.Rarity[math.clamp(math.ceil(table.find(Skins.List, selected) / 3), 1, 5)]
	local stage = Kit.new('Frame', { Name = 'Stage', BackgroundColor3 = Kit.Color.white, Size = U.new(1, 0, 0.55, 0), LayoutOrder = 1, ZIndex = 24, Parent = stack })
	Kit.corner(Kit.Radius.m).Parent = stage
	Kit.stroke(Kit.Color.ink, 3, true).Parent = stage
	Kit.gradient(tier.color:Lerp(Kit.Color.white, 0.6), tier.color, 0.8).Parent = stage
	local art = Kit.new('ImageLabel', { Name = 'Art', BackgroundTransparency = 1, Size = U.fromScale(1, 1), ScaleType = Enum.ScaleType.Fit, ZIndex = 25, Parent = stage })
	art:SetAttribute('PreviewImage', 'portrait:' .. selected.Id)
	Kit.text({ Name = 'Name', Text = string.upper(selected.Name), TextSize = 30, Stroke = Kit.Color.ink, Size = U.new(1, 0, 0, 34), LayoutOrder = 2, ZIndex = 24, Parent = stack }).LayoutOrder = 2
	local stat = Kit.new('Frame', { Name = 'Stat', BackgroundColor3 = Kit.Color.asphalt, Size = U.fromOffset(200, 32), LayoutOrder = 3, ZIndex = 24, Parent = stack })
	Kit.corner(UDim.new(0.5, 0)).Parent = stat
	Kit.stroke(Kit.Color.ink, 2.5, true).Parent = stat
	Kit.icon('power', 40, { AnchorPoint = Vector2.new(0, 0.5), Position = U.new(0, -10, 0.5, 0), ZIndex = 25 }).Parent = stat
	Kit.text({ Text = '+' .. selected.Gain .. ' POWER / SEC', FontFace = Kit.Font.number, TextSize = 18, Stroke = Kit.Color.ink, Position = U.fromOffset(14, 0), ZIndex = 25, Parent = stat })
	local unlocked = power >= selected.Required
	if not unlocked then
		local need = Kit.text({ Name = 'Need', Text = 'Need ' .. Kit.short(selected.Required) .. ' Power', FontFace = Kit.Font.body, TextSize = 16, TextColor3 = Kit.Color.ink, Size = U.new(1, 0, 0, 20), ZIndex = 24, Parent = stack })
		need.LayoutOrder = 4
		local bar = Kit.progress({ Width = 228, Height = 20, Value = power / selected.Required, Text = Kit.short(power) .. ' / ' .. Kit.short(selected.Required), LayoutOrder = 5 })
		bar.ZIndex = 24
		bar.Parent = stack
	end
	local action = Kit.button({
		Name = 'Wear', Tone = 'green', Disabled = not unlocked, Text = unlocked and 'WEAR IT' or 'LOCKED', TextSize = 30, Width = 228, Height = 64,
		AnchorPoint = Vector2.new(0.5, 1), Position = U.new(0.5, 0, 1, -14), Icon = 'outfits', ZIndex = 25,
	})
	action.Parent = detail
	return panel
end

local current
function Demo.Show(which)
	Demo.Hide()
	local ok, coreGui = pcall(function() return game:GetService('CoreGui') end)
	local parent = ok and coreGui or game:GetService('StarterGui')
	local gui, root = Demo.hud(parent)
	if which == 'Shop' then Demo.shop(root) end
	current = gui
	return gui
end
function Demo.Hide()
	if current then current:Destroy() end
	current = nil
end

-- Offline preview entry: returns the ScreenGui without parenting it.
function Demo.Build(which, look)
	local gui, root = Demo.hud(nil)
	if which == 'Shop' then root.Toast.Visible = false; Demo.shop(root, look) end
	return gui
end

return Demo
