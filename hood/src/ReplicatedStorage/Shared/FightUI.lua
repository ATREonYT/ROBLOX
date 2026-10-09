-- The fight's screen pieces, styled like the reference game's (the user's video, frames f_064-f_086): the "N LEFT"
-- counter at the top centre and the name + HP bar over each goon. Look only (brief 18, UI2); Waves.client (COMBAT) owns
-- when they show and what they say. Client only. Built with UIKit, so the HUD's font and outlines reach them.
--
--   local pill = FightUI.pill(parent)   -- parent: a Kit.screen Root (design px)
--   pill.set(left)                      -- "3 LEFT" (white), "1 LEFT" (red); pops when the number changes
--   pill.clear(rewardText?)             -- "CLEAR!" in green (+ an optional small line under it, e.g. "+120 Cash")
--   pill.hide()
--   local tag = FightUI.tag(adornee, name, max)   -- a BillboardGui on the goon's head part (parented to it)
--   tag.set(hp, max)                    -- the red bar and "40/40"; tag.Gui is the BillboardGui; tag.destroy()
local TweenService = game:GetService('TweenService')
local RS = game:GetService('ReplicatedStorage')
local Kit = require(RS.Shared.UIKit)

local FightUI = {}
local px = UDim2.fromOffset
local hex = Kit.hex
local BLACK = Kit.Color.black

-- The reference's colours: the slate box, its light edge, white / red / green counts, the red HP bar.
FightUI.Color = {
	box = hex('2E3446'), boxTop = hex('3D4560'), edge = hex('5A6380'),
	white = Kit.Color.white, last = hex('FF3B3B'), clear = hex('7CFF4F'),
	hp = hex('E81E2A'), hpTop = hex('FF5A5A'), track = hex('4A0C14'),
}

-- A cartoon skull drawn with UI shapes (a round white head, a jaw, two dark eyes, a nose and teeth), `size` px.
local function skull(size, z)
	local holder = Kit.new('Frame', { Name = 'Skull', BackgroundTransparency = 1, Size = px(size, size), ZIndex = z })
	local head = Kit.new('Frame', { Name = 'Head', BackgroundColor3 = hex('F2F2F6'), BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0.02), Size = UDim2.fromScale(0.92, 0.74), ZIndex = z, Parent = holder })
	Kit.corner(UDim.new(0.48, 0)).Parent = head
	Kit.stroke(BLACK, math.max(1.5, size * 0.06), true).Parent = head
	Kit.gradient(Kit.Color.white, hex('C9CBD6'), 0.6).Parent = head
	local jaw = Kit.new('Frame', { Name = 'Jaw', BackgroundColor3 = hex('E4E5EC'), BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0.6), Size = UDim2.fromScale(0.56, 0.34), ZIndex = z - 1, Parent = holder })
	Kit.corner(UDim.new(0.25, 0)).Parent = jaw
	Kit.stroke(BLACK, math.max(1.5, size * 0.06), true).Parent = jaw
	for _, x in { 0.31, 0.69 } do
		local eye = Kit.new('Frame', { Name = 'Eye', BackgroundColor3 = hex('1A1A24'), BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(x, 0.42), Size = UDim2.fromScale(0.27, 0.27), ZIndex = z + 1, Parent = holder })
		Kit.corner(UDim.new(0.5, 0)).Parent = eye
	end
	local nose = Kit.new('Frame', { Name = 'Nose', BackgroundColor3 = hex('1A1A24'), BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.63), Size = UDim2.fromScale(0.1, 0.12), Rotation = 45, ZIndex = z + 1, Parent = holder })
	Kit.corner(2).Parent = nose
	for _, x in { 0.42, 0.58 } do
		Kit.new('Frame', { Name = 'Tooth', BackgroundColor3 = hex('6A6C78'), BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(x, 0.78), Size = UDim2.fromScale(0.04, 0.12), ZIndex = z + 1, Parent = holder })
	end
	return holder
end
FightUI.skull = skull

---------------------------------------------------------------------------------------------- "N LEFT"
-- A slate box 190 x 62 design px at the top centre (over Roblox's top bar band, like the video), a white skull and the
-- count in Gotham Black with a thick black stroke.
FightUI.PillSize = Vector2.new(190, 62)
function FightUI.pill(parent)
	local w, h = FightUI.PillSize.X, FightUI.PillSize.Y
	local box = Kit.new('Frame', { Name = 'WaveLeft', AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, -16), Size = px(w, h), BackgroundColor3 = Kit.Color.white, BorderSizePixel = 0, Visible = false, ZIndex = 5, Parent = parent })
	Kit.corner(7).Parent = box
	Kit.stroke(BLACK, 3, true).Parent = box
	Kit.gradient(FightUI.Color.boxTop, FightUI.Color.box, 0.55).Parent = box
	local rim = Kit.new('Frame', { Name = 'Rim', BackgroundTransparency = 1, Position = px(2, 2), Size = UDim2.new(1, -4, 1, -4), ZIndex = 5, Parent = box })
	Kit.corner(5).Parent = rim
	Kit.stroke(FightUI.Color.edge, 2, true, 0.3).Parent = rim
	local scale = Kit.new('UIScale', { Parent = box })
	-- (brief 19) ICONS' Skull render once uploaded; the frame skull until then
	local icon = Kit.iconImage('Skull') ~= '' and Kit.icon3d('Skull', 46, { ZIndex = 7 }) or skull(44, 7)
	icon.AnchorPoint = Vector2.new(0, 0.5)
	icon.Position = UDim2.new(0, 12, 0.5, 0)
	icon.Parent = box
	local text = Kit.text({ Name = 'Count', Text = '3 LEFT', TextSize = 34, Stroke = BLACK, StrokeThickness = 4, TextXAlignment = Enum.TextXAlignment.Left, Position = px(64, -1), Size = UDim2.new(1, -70, 1, 0), ZIndex = 7, Parent = box })
	local sub = Kit.text({ Name = 'Reward', Text = '', TextSize = 22, Stroke = BLACK, StrokeThickness = 3, TextColor3 = FightUI.Color.clear, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 1, 4), Size = px(320, 28), ZIndex = 7, Parent = box })
	local function pop()
		scale.Scale = 1.22
		TweenService:Create(scale, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	end
	local function show(t, color)
		local changed = text.Text ~= t or not box.Visible
		text.Text = t
		text.TextColor3 = color
		text.TextSize = Kit.fitSize(t, 34, w - 76, 16)
		box.Visible = true
		if changed then pop() end
	end
	local api = { Gui = box }
	function api.set(left)
		sub.Text = ''
		left = math.max(0, math.floor(tonumber(left) or 0))
		show(left .. ' LEFT', left == 1 and FightUI.Color.last or FightUI.Color.white)
	end
	function api.clear(rewardText)
		show('CLEAR!', FightUI.Color.clear)
		sub.Text = rewardText and tostring(rewardText) or ''
	end
	function api.hide()
		box.Visible = false
		sub.Text = ''
	end
	return api
end

---------------------------------------------------------------------------------------------- name + HP bar
-- Over each goon (the video's "Guard 2" over a red "120/120" bar): a billboard sized in studs, so it shrinks with
-- distance like the reference's; the name small and white, the bar flat red with a black outline and the HP centred.
FightUI.TagSize = Vector2.new(4.6, 1.55) -- studs
FightUI.TagOffset = Vector3.new(0, 2.6, 0)
local function hpText(hp, max)
	local short = Kit.short
	return short(math.max(0, math.ceil(hp))) .. '/' .. short(math.max(1, math.ceil(max)))
end
function FightUI.tag(adornee, name, max)
	max = math.max(1, tonumber(max) or 1)
	local gui = Instance.new('BillboardGui')
	gui.Name = 'GoonTag'
	gui.Size = UDim2.fromScale(FightUI.TagSize.X, FightUI.TagSize.Y)
	gui.StudsOffset = FightUI.TagOffset
	gui.LightInfluence = 0
	gui.MaxDistance = 140
	gui.AlwaysOnTop = false
	gui.ResetOnSpawn = false
	gui.Adornee = adornee
	local nameLabel = Kit.text({ Name = 'Name', Text = tostring(name or ''), Stroke = BLACK, StrokeThickness = 2, Size = UDim2.fromScale(1, 0.4), ZIndex = 2, Parent = gui })
	nameLabel.TextScaled = true
	local bar = Kit.new('Frame', { Name = 'Bar', AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.fromScale(0.5, 1), Size = UDim2.fromScale(0.96, 0.52), BackgroundColor3 = FightUI.Color.track, BorderSizePixel = 0, ZIndex = 2, Parent = gui })
	Kit.corner(UDim.new(0.12, 0)).Parent = bar
	Kit.stroke(BLACK, 2, true).Parent = bar
	local fill = Kit.new('Frame', { Name = 'Fill', Size = UDim2.fromScale(1, 1), BackgroundColor3 = Kit.Color.white, BorderSizePixel = 0, ZIndex = 3, Parent = bar })
	Kit.corner(UDim.new(0.12, 0)).Parent = fill
	Kit.gradient(FightUI.Color.hpTop, FightUI.Color.hp, 0.45).Parent = fill
	local hp = Kit.text({ Name = 'HP', Text = hpText(max, max), Stroke = BLACK, StrokeThickness = 2, Size = UDim2.fromScale(1, 1), ZIndex = 4, Parent = bar })
	hp.TextScaled = true
	Kit.new('UIPadding', { PaddingTop = UDim.new(0.12, 0), PaddingBottom = UDim.new(0.12, 0), Parent = hp })
	gui.Parent = adornee
	local api = { Gui = gui, Name = nameLabel, Fill = fill, HP = hp }
	function api.set(a, b, c)
		if a == api then a, b = b, c end -- (works as tag.set(hp, max) and tag:set(hp, max))
		local m = math.max(1, tonumber(b) or max)
		local v = math.clamp(tonumber(a) or 0, 0, m)
		fill.Size = UDim2.fromScale(v / m, 1)
		fill.Visible = v > 0
		hp.Text = hpText(v, m)
	end
	function api.destroy() gui:Destroy() end
	return api
end

return FightUI
