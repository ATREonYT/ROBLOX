-- The fight's screen pieces, styled like the reference game's (the user's video, frames f_064-f_086): the "N LEFT"
-- counter at the top centre and the name + HP bar over each goon. Look only (brief 18, UI2); Waves.client (COMBAT) owns
-- when they show and what they say. Client only. Built with UIKit, so the HUD's font and outlines reach them.
--
--   local pill = FightUI.pill(parent)   -- parent: a Kit.screen Root (design px)
--   pill.set(left)                      -- "3 LEFT" (white), "1 LEFT" (red); pops when the number changes
--   pill.clear(rewardText?)             -- "CLEAR!" in green (+ an optional small line under it, e.g. "+120 Cash")
--   pill.hide()                         -- (brief 30: the reference's crisp white skull on both, our glossy Skull icon)
--   local tag = FightUI.tag(adornee, name, max, strong)   -- a BillboardGui on the goon's head part (parented to it);
--   tag.set(hp, max)                    -- the red bar and "40/40"; tag.Gui is the BillboardGui; tag.destroy()
--                                       -- (brief 30) strong: a crew's strongest, its name bigger over a bigger red bar
--                                       -- with the reference's brick (stud) texture (bible 2.4, V4 15.75 s)
--   local bar = FightUI.bossBar(parent) -- the World Boss's big HP bar at the top (only the World Boss: brief 30 took
--   bar.set(name, hp, max)              -- every bar, card and phase off the stage enemies)
--   bar.show(on)
--   local rv = FightUI.revive(parent, prices)  -- (brief 30) the reference's REVIVE? screen (V4 16.6 s): rv.show(seconds),
--                                       -- rv.set(secondsLeft), rv.hide(), rv.Choice(fn(key)) with key 'Revive' |
--                                       -- 'Revenge' | 'No', rv.note(key, text) (a line under a button: "Coming soon!")
--   local bt = FightUI.bossTimer(parent)       -- (brief 30) the reference's top line "Next GUNSHIP boss fight in: 2:52"
--                                       -- and its blue SKIP with the Robux mark (W 31.0 s): bt.set(name, seconds),
--                                       -- bt.show(on), bt.Skip(fn), bt.note(text)
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
	white = Kit.Color.white, last = hex('FF3B3B'), clear = hex('7CFF4F'), left = hex('E8405A'), -- (brief 30: the reference's last "1 LEFT" is hot pink #E8405A)
	hp = hex('E81E2A'), hpTop = hex('FF5A5A'), track = hex('4A0C14'),
}

-- (brief 29: the skull is gone, "the clear emoji is not good") Two flat drawn icons for the pill, `size` px: a bullseye
-- while goons are left (white and red rings, a black outline) and a green disc with a white tick for CLEAR!. Plain
-- frames and strokes, the same flat language as the HUD's glyphs.
local function disc(parent, name, size, color, z, ink)
	local f = Kit.new('Frame', { Name = name, BackgroundColor3 = color, BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = size, ZIndex = z, Parent = parent })
	Kit.corner(UDim.new(0.5, 0)).Parent = f
	if ink then Kit.stroke(BLACK, ink, true).Parent = f end
	return f
end
local function bullseye(size, z)
	local holder = Kit.new('Frame', { Name = 'Target', BackgroundTransparency = 1, Size = px(size, size), ZIndex = z })
	local ink = math.max(2, size * 0.07)
	disc(holder, 'Ring1', UDim2.fromScale(0.92, 0.92), hex('E8222E'), z, ink)
	disc(holder, 'Ring2', UDim2.fromScale(0.64, 0.64), Kit.Color.white, z + 1, nil)
	disc(holder, 'Ring3', UDim2.fromScale(0.38, 0.38), hex('E8222E'), z + 2, nil)
	disc(holder, 'Dot', UDim2.fromScale(0.14, 0.14), Kit.Color.white, z + 3, nil)
	return holder
end
local function tick(size, z)
	local holder = Kit.new('Frame', { Name = 'Tick', BackgroundTransparency = 1, Size = px(size, size), ZIndex = z })
	local disk = disc(holder, 'Disc', UDim2.fromScale(0.92, 0.92), hex('3FD13A'), z, math.max(2, size * 0.07))
	Kit.gradient(hex('8CFF5A'), hex('2DB52E'), 0.5).Parent = disk
	-- the tick: a short bar down to the right, a long bar up to the right, rounded, white with a dark edge
	for _, b in { { 0.38, 0.6, 0.2, 0.46, -45 }, { 0.6, 0.5, 0.2, 0.74, 45 } } do
		local bar = Kit.new('Frame', { Name = 'Bar', BackgroundColor3 = Kit.Color.white, BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(b[1], b[2]), Size = UDim2.fromScale(b[3] * 0.62, b[4] * 0.62), Rotation = b[5], ZIndex = z + 1, Parent = holder })
		Kit.corner(UDim.new(0.5, 0)).Parent = bar
	end
	return holder
end
FightUI.bullseye, FightUI.tick = bullseye, tick
-- (brief 30) The skull: the uploaded glossy Skull PNG (IconModels), the flat stand-in Kit draws while it can't load.
local function skull(size, z)
	local ok, holder = pcall(function()
		local h = Kit.icon3d and Kit.icon3d('Skull', size, { ZIndex = z }) or nil
		return h
	end)
	if ok and holder then
		holder.Name = 'Skull'
		return holder
	end
	local b = bullseye(size, z)
	b.Name = 'Skull'
	return b
end
FightUI.skull = skull

---------------------------------------------------------------------------------------------- "N LEFT"
-- A slate box 190 x 62 design px at the top centre (over Roblox's top bar band, like the video), a drawn bullseye and the
-- count in Gotham Black with a thick black stroke.
-- (PlayerGui's FightChip says the chip is up: the World Boss timer line, which shares the HUD's top centre, gives way)
local function chipShown(on)
	pcall(function()
		local pg = game:GetService('Players').LocalPlayer:FindFirstChildOfClass('PlayerGui')
		if pg and pg:GetAttribute('FightChip') ~= (on or nil) then pg:SetAttribute('FightChip', on or nil) end
	end)
end
FightUI.PillSize = Vector2.new(140, 36) -- (brief 30: the HUD's TopCentre.FightChipSlot, HudSpec's measure of the reference's chip)
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
	-- (brief 30, bible U7) the reference's crisp white skull on the chip, both while goons are left and on CLEAR!: our
	-- glossy chunky Skull icon (ART2's, the HUD's style; the brief-29 emoji is long gone), drawn bullseye as its stand-in
	local icon = skull(28, 7)
	icon.AnchorPoint = Vector2.new(0, 0.5)
	icon.Position = UDim2.new(0, 7, 0.5, 0)
	icon.Parent = box
	local doneIcon = skull(28, 7)
	doneIcon.Name = 'SkullClear'
	doneIcon.AnchorPoint = Vector2.new(0, 0.5)
	doneIcon.Position = UDim2.new(0, 7, 0.5, 0)
	doneIcon.Visible = false
	doneIcon.Parent = box
	local text = Kit.text({ Name = 'Count', Text = '3 LEFT', TextSize = 23, Stroke = BLACK, StrokeThickness = 3, TextXAlignment = Enum.TextXAlignment.Left, Position = px(40, -1), Size = UDim2.new(1, -44, 1, 0), ZIndex = 7, Parent = box })
	-- (under CLEAR!, the reference's light "Mission complete!" line; ours names the street)
	local sub = Kit.text({ Name = 'Reward', Text = '', TextSize = 19, Stroke = BLACK, StrokeThickness = 3, TextColor3 = hex('EDEFF5'), AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 1, 2), Size = px(300, 24), ZIndex = 7, Parent = box })
	local function pop()
		scale.Scale = 1.22
		TweenService:Create(scale, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	end
	local function show(t, color)
		local changed = text.Text ~= t or not box.Visible
		text.Text = t
		text.TextColor3 = color
		text.TextSize = Kit.fitSize(t, 23, w - 48, 12)
		box.Visible = true
		chipShown(true)
		if changed then pop() end
	end
	local api = { Gui = box }
	function api.set(left)
		sub.Text = ''
		icon.Visible, doneIcon.Visible = true, false
		left = math.max(0, math.floor(tonumber(left) or 0))
		-- (the reference: "2 LEFT" white (W 32.4 s), the last one "1 LEFT" in hot pink (V1 16.4 s))
		show(left .. ' LEFT', left == 1 and FightUI.Color.left or FightUI.Color.white)
	end
	function api.clear(rewardText)
		icon.Visible, doneIcon.Visible = false, true
		show('CLEAR!', FightUI.Color.clear)
		sub.Text = rewardText and tostring(rewardText) or 'Street cleared!'
	end
	function api.hide()
		box.Visible = false
		sub.Text = ''
		chipShown(false)
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
-- (brief 30) A crew's strongest: a bigger tag, its name bigger, and the bar's brick studs (StrongSize studs).
FightUI.StrongSize = Vector2.new(6.4, 2.1)
FightUI.Studs = 7 -- (studs across the strongest's bar: the reference's red brick)
function FightUI.tag(adornee, name, max, strong)
	max = math.max(1, tonumber(max) or 1)
	local gui = Instance.new('BillboardGui')
	gui.Name = strong and 'StrongTag' or 'GoonTag'
	gui.Size = strong and UDim2.fromScale(FightUI.StrongSize.X, FightUI.StrongSize.Y) or UDim2.fromScale(FightUI.TagSize.X, FightUI.TagSize.Y)
	gui:SetAttribute('Strong', strong == true)
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
	if strong then
		-- the brick: a row of square studs over the whole bar (fill and track alike), lit top, dark edge; the name bigger
		nameLabel.Size = UDim2.fromScale(1, 0.42)
		bar.Size = UDim2.fromScale(0.98, 0.56)
		for k = 1, FightUI.Studs do
			local w = 1 / FightUI.Studs
			local stud = Kit.new('Frame', { Name = 'Stud', AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale((k - 0.5) * w, 0.5), Size = UDim2.fromScale(w * 0.62, 0.62), BackgroundColor3 = Kit.Color.white, BackgroundTransparency = 0.82, BorderSizePixel = 0, ZIndex = 4, Parent = bar })
			Kit.corner(UDim.new(0.18, 0)).Parent = stud
			local st = Kit.new('UIStroke', { Color = BLACK, Thickness = 1.2, Transparency = 0.55, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = stud })
			local _ = st
		end
	end
	local hp = Kit.text({ Name = 'HP', Text = hpText(max, max), Stroke = BLACK, StrokeThickness = 2, Size = UDim2.fromScale(1, 1), ZIndex = 5, Parent = bar })
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

-- (brief 29) A boss's HP bar at the top centre, under the "N LEFT" counter.
FightUI.BossBarSize = Vector2.new(520, 66)
function FightUI.bossBar(parent)
	local size = FightUI.BossBarSize
	local holder = Kit.new('Frame', { Name = 'BossBar', AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 100), Size = px(size.X, size.Y), BackgroundTransparency = 1, Visible = false, Parent = parent })
	local name = Kit.text({ Name = 'BossName', Text = 'BOSS', TextSize = 30, Stroke = BLACK, StrokeThickness = 3.5, TextColor3 = hex('FFD21A'), Size = UDim2.new(1, 0, 0, 32), Parent = holder })
	local bar = Kit.new('Frame', { Name = 'Bar', AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.fromScale(0.5, 1), Size = UDim2.new(1, 0, 0, 30), BackgroundColor3 = FightUI.Color.track, BorderSizePixel = 0, ZIndex = 2, Parent = holder })
	Kit.corner(UDim.new(0, 8)).Parent = bar
	Kit.stroke(BLACK, 3.5, true).Parent = bar
	local fill = Kit.new('Frame', { Name = 'Fill', Size = UDim2.fromScale(1, 1), BackgroundColor3 = Kit.Color.white, BorderSizePixel = 0, ZIndex = 3, Parent = bar })
	Kit.corner(UDim.new(0, 8)).Parent = fill
	local grad = Kit.gradient(FightUI.Color.hpTop, FightUI.Color.hp, 0.45)
	grad.Parent = fill
	local half = Kit.new('Frame', { Name = 'Half', AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0), Size = UDim2.new(0, 3, 1, 0), BackgroundColor3 = Kit.Color.white, BackgroundTransparency = 0.25, BorderSizePixel = 0, ZIndex = 4, Parent = bar })
	-- (brief 29, P3b) a phase bar for World 1's final boss: a notch at each phase line (marks, fractions of its HP) and a
	-- pip per phase under the bar, lit up to the phase it's in
	local notches, pips = {}, {}
	for k = 1, 2 do
		notches[k] = Kit.new('Frame', { Name = 'PhaseNotch', AnchorPoint = Vector2.new(0.5, 0), Size = UDim2.new(0, 4, 1, 0), BackgroundColor3 = Kit.Color.white, BorderSizePixel = 0, ZIndex = 4, Visible = false, Parent = bar })
	end
	for k = 1, 3 do
		pips[k] = Kit.new('Frame', { Name = 'PhasePip', AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, (k - 2) * 26, 1, 6), Size = px(18, 8), BackgroundColor3 = hex('3A3F55'), BorderSizePixel = 0, Visible = false, ZIndex = 5, Parent = holder })
		Kit.corner(UDim.new(0, 4)).Parent = pips[k]
		Kit.stroke(BLACK, 2, true).Parent = pips[k]
	end
	local hp = Kit.text({ Name = 'HP', Text = '', TextSize = 22, Stroke = BLACK, StrokeThickness = 2.5, Size = UDim2.fromScale(1, 1), ZIndex = 5, Parent = bar })
	local phase = Kit.text({ Name = 'Phase', Text = 'PHASE 2!', TextSize = 20, Stroke = BLACK, StrokeThickness = 2.5, TextColor3 = hex('FF8A2A'), AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 6), Size = px(130, 24), TextXAlignment = Enum.TextXAlignment.Right, Visible = false, ZIndex = 5, Parent = holder })
	local api = { Gui = holder, Fill = fill }
	function api.set(text, value, max, stage, marks)
		local m = math.max(1, tonumber(max) or 1)
		local v = math.clamp(tonumber(value) or 0, 0, m)
		name.Text = string.upper(tostring(text or 'BOSS'))
		fill.Size = UDim2.fromScale(v / m, 1)
		fill.Visible = v > 0
		hp.Text = hpText(v, m)
		local angry = (stage or 1) >= 2
		phase.Visible = angry
		phase.Text = 'PHASE ' .. tostring(math.floor(stage or 1)) .. '!'
		local multi = type(marks) == 'table' and #marks > 1
		half.Visible = not multi
		for k, n in notches do
			n.Visible = multi and marks[k] ~= nil
			if n.Visible then n.Position = UDim2.fromScale(marks[k], 0) end
		end
		for k, pip in pips do
			pip.Visible = multi
			pip.BackgroundColor3 = (stage or 1) >= k and (k == 3 and hex('FF3A2A') or k == 2 and hex('FF8A2A') or hex('FFD21A')) or hex('3A3F55')
		end
		grad.Color = angry and ColorSequence.new(hex('FFB24A'), hex('FF5A1E')) or ColorSequence.new({ ColorSequenceKeypoint.new(0, FightUI.Color.hpTop), ColorSequenceKeypoint.new(0.45, FightUI.Color.hp), ColorSequenceKeypoint.new(1, FightUI.Color.hp) })
	end
	function api.show(on)
		if holder.Visible ~= on then holder.Visible = on end
	end
	return api
end

---------------------------------------------------------------------------------------------- the revive screen
-- (brief 30, bible 2.4 / F5) The reference's REVIVE? screen (ref_V4-16.6_revive_screen, V4 16.3-16.7 s), measured on the
-- game view: the world blurred behind it; "REVIVE?" red-orange (#E84828) heavy with a thick dark outline at 37 % H, about
-- 6-7 % H tall; the countdown "9.64" in gold under it at 51 % H; three buttons side by side at 64 % H, each about 16 % W x
-- 11 % H: "Revive!" green (#A8F838), "Revenge!" yellow (#F8D858), "No" red (#D82838), white words with a dark outline;
-- under the first two their small white lines "+ FULL HP" and "+ KILL ENEMIES" (ours: "+ KO ENEMIES", kid-safe). Ours
-- adds the honest bits the reference leaves to Roblox's prompt: each Robux button carries its price in the reference's
-- lime corner badge, and "No" says it's free. In design px (1280 x 720): centres x 423 / 639 / 858, y 459; 205 x 82.
-- (measured on ref_V4-16.6_revive_screen and ref_V4_charger_lane_revive_grid, as fractions of the whole view: REVIVE?
-- centred at 36 % H, the clock at 49.5 %, the three buttons 16.4 % W x 11.3 % H centred at 62 % H, 0.5 % W apart, the
-- row centred; the captions at 70 %. Here in design px / fractions of the GUI area under the 58 px top bar.)
FightUI.ReviveSize = Vector2.new(231, 89)
FightUI.ReviveX = { Revive = 461, Revenge = 699, No = 937 }
FightUI.ReviveY = { Title = 0.302, Clock = 0.447, Buttons = 0.585, Subs = 0.671 }
-- The reference's flat bright fills (sampled): lime-to-green, yellow-to-orange, red; each with a darker lip and stroke.
FightUI.ReviveTones = {
	Revive = { top = hex('B4FF3C'), base = hex('4FD82A'), lip = hex('199E16'), stroke = hex('0D2A08') },
	Revenge = { top = hex('FFEA6C'), base = hex('F7932F'), lip = hex('C46E12'), stroke = hex('4A2400') },
	No = { top = hex('EE3644'), base = hex('C8141E'), lip = hex('86080F'), stroke = hex('300004') },
}
FightUI.ReviveColors = { Revive = 'fightRevive', Revenge = 'fightRevenge', No = 'fightNo' }
for key, tone in FightUI.ReviveTones do
	if Kit.Tone and not Kit.Tone[FightUI.ReviveColors[key]] then Kit.Tone[FightUI.ReviveColors[key]] = tone end
end
function FightUI.revive(parent, prices)
	prices = prices or {}
	local holder = Kit.new('Frame', { Name = 'Revive', BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Visible = false, ZIndex = 30, Parent = parent })
	-- a soft dark wash so the words read over any street (the reference's blur does this; Lighting's BlurEffect blurs too)
	local wash = Kit.new('Frame', { Name = 'Wash', BackgroundColor3 = hex('0B0D18'), BackgroundTransparency = 0.86, BorderSizePixel = 0, Size = UDim2.fromScale(1, 1), ZIndex = 30, Parent = holder })
	local _ = wash
	local Y = FightUI.ReviveY
	local title = Kit.text({ Name = 'Title', Text = 'REVIVE?', TextSize = 62, Stroke = hex('3A0400'), StrokeThickness = 6, TextColor3 = hex('FFFFFF'), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, Y.Title), Size = UDim2.fromOffset(480, 74), ZIndex = 32, Parent = holder })
	-- (the reference's: a warm orange top over the red #E84828, sampled 236,139,62 -> 243,78,48 -> 209,64,35)
	Kit.gradient(hex('F08A40'), hex('E84828'), 0.45).Parent = title
	local titleScale = Kit.new('UIScale', { Parent = title })
	local clock = Kit.text({ Name = 'Clock', Text = '10.00', TextSize = 40, Stroke = hex('3A2400'), StrokeThickness = 4, TextColor3 = hex('FFFFFF'), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, Y.Clock), Size = UDim2.fromOffset(220, 46), ZIndex = 32, Parent = holder })
	Kit.gradient(hex('F8DC48'), hex('DCB43A'), 0.5).Parent = clock
	local api = { Gui = holder, Buttons = {}, Notes = {} }
	local choice = nil
	function api.Choice(fn) choice = fn end
	local specs = {
		{ Key = 'Revive', Text = 'Revive!', Sub = '+ FULL HP', X = FightUI.ReviveX.Revive },
		{ Key = 'Revenge', Text = 'Revenge!', Sub = '+ KO ENEMIES', X = FightUI.ReviveX.Revenge },
		{ Key = 'No', Text = 'No', Sub = '+ FREE RETRY', X = FightUI.ReviveX.No },
	}
	local W, H = FightUI.ReviveSize.X, FightUI.ReviveSize.Y
	for i, sp in specs do
		local b, hit = Kit.button({ Name = sp.Key, Text = sp.Text, Tone = FightUI.ReviveColors[sp.Key], Width = W, Height = H, TextSize = 50, Radius = 9, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0, sp.X, Y.Buttons, 0), ZIndex = 33 })
		b.Parent = holder
		api.Buttons[sp.Key] = b
		local sub = Kit.text({ Name = 'Sub', Text = sp.Sub, TextSize = 15, Stroke = BLACK, StrokeThickness = 2, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0, sp.X, Y.Subs, 0), Size = UDim2.fromOffset(W + 30, 18), ZIndex = 33, Parent = holder })
		api.Notes[sp.Key] = sub
		if prices[sp.Key] then
			-- the price in the reference's lime corner badge (the HUD's +20K cards): the Robux mark and the number
			local badge = Kit.only(prices[sp.Key], 20, { Only = false, ZIndex = 36, AnchorPoint = Vector2.new(1, 0.5), MarkColor = hex('7DF04E'), PriceColors = ColorSequence.new(hex('E6FF5A'), hex('6CF02A')) })
			badge.Name = 'Price'
			badge.Position = UDim2.new(1, 6, 0, 2)
			badge.Parent = b
		end
		local scale = Kit.new('UIScale', { Parent = b })
		api.Buttons[sp.Key .. 'Scale'] = scale
		if hit then
			pcall(function()
				hit.Activated:Connect(function()
					scale.Scale = 0.9
					TweenService:Create(scale, TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
					if choice then choice(sp.Key) end
				end)
			end)
		end
		api.Hits = api.Hits or {}
		api.Hits[sp.Key] = hit
		local _ = i
	end
	function api.press(key) if choice then choice(key) end end -- (the offline plays press a button)
	function api.note(key, text)
		local n = api.Notes[key]
		if n then n.Text = text end
	end
	function api.set(left)
		clock.Text = string.format('%.2f', math.max(0, tonumber(left) or 0))
	end
	function api.show(seconds)
		api.set(seconds or 10)
		holder.Visible = true
		api.note('Revive', '+ FULL HP')
		api.note('Revenge', '+ KO ENEMIES')
		-- (the reference's panels pop: 0.15 -> 1.05 -> 1, staggered a little)
		titleScale.Scale = 0.3
		TweenService:Create(titleScale, TweenInfo.new(0.28, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
		for k, key in { 'Revive', 'Revenge', 'No' } do
			local sc = api.Buttons[key .. 'Scale']
			sc.Scale = 0.2
			TweenService:Create(sc, TweenInfo.new(0.26, Enum.EasingStyle.Back, Enum.EasingDirection.Out, 0, false, 0.05 * k), { Scale = 1 }):Play()
		end
	end
	function api.hide()
		holder.Visible = false
	end
	return api
end

---------------------------------------------------------------------------------------------- the World Boss timer
-- (brief 30, bible 2.7 "Boss countdown") The reference's first top line (ref_W31.0_stage1_wave_idle_at_gate, W 0-31 s):
-- "Next GUNSHIP boss fight in: 2:52" in white heavy letters with a dark outline, the boss's name orange-yellow, one line
-- across x 30-60 % at y 2-5.5 % of the view (beside Roblox's top bar), then a blue rounded SKIP button with a Robux coin
-- (x 62-71 %). In design px: the line centred at x 577, y -21 (the top bar band), ~22 px letters; SKIP 111 x 41 at x 847.
FightUI.TimerY = -21
function FightUI.bossTimer(parent)
	-- (the HUD's TopCentre.BossTimerSlot is 470 x 38: the line on the left, SKIP on the right; FightUI.dock puts it there)
	local holder = Kit.new('Frame', { Name = 'BossTimer', BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0, FightUI.TimerY), Size = UDim2.fromOffset(470, 38), Visible = false, ZIndex = 6, Parent = parent })
	local line = Kit.text({ Name = 'Line', Text = '', RichText = true, TextSize = 22, Stroke = BLACK, StrokeThickness = 3, AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 0, 0.5, 0), Size = UDim2.fromOffset(356, 30), ZIndex = 7, Parent = holder })
	line.TextScaled = true
	Kit.new('UITextSizeConstraint', { MaxTextSize = 22, MinTextSize = 12, Parent = line })
	local skip, hit = Kit.button({ Name = 'Skip', Text = 'SKIP', Tone = 'blue', Width = 104, Height = 36, TextSize = 21, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0), ZIndex = 8 })
	skip.Parent = holder
	-- the Robux coin on the button's left, like the reference's
	local coin = Kit.robux(18, { Color = hex('E8F4FF'), AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 8, 0.5, -2), ZIndex = 12 })
	coin.Parent = skip
	local note = Kit.text({ Name = 'Note', Text = '', TextSize = 14, Stroke = BLACK, StrokeThickness = 2, TextColor3 = hex('9AD8FF'), AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 1, 2), Size = UDim2.fromOffset(160, 16), ZIndex = 8, Parent = holder })
	local api = { Gui = holder, Line = line, Skip = skip }
	local onSkip = nil
	function api.Skip(fn) onSkip = fn end
	if hit then pcall(function() hit.Activated:Connect(function() if onSkip then onSkip() end end) end) end
	api.Hit = hit
	local noteToken = 0
	function api.note(text)
		noteToken += 1
		local mine = noteToken
		note.Text = text or ''
		task.delay(2.5, function() if noteToken == mine then note.Text = '' end end)
	end
	local function clock(seconds)
		local s = math.max(0, math.ceil(seconds or 0))
		return string.format('%d:%02d', s // 60, s % 60)
	end
	function api.set(name, seconds)
		line.Text = 'Next <font color="#FFB020">' .. tostring(name or '') .. '</font> boss fight in: ' .. clock(seconds)
	end
	function api.show(on)
		if holder.Visible ~= on then holder.Visible = on end
	end
	return api
end

-- (brief 30) The HUD (HoodClient/HUD.client) keeps a slot for each of these at the top centre (HudSpec.TopCentre):
-- TopCentre.FightChipSlot for "N LEFT" / CLEAR!, TopCentre.BossTimerSlot for the World Boss line. dock(frame, slotName)
-- moves the frame into its slot once the HUD has built it (and back to `home` if the HUD goes away), centred at its
-- top; until then the frame stays where its own screen put it.
function FightUI.dock(frame, slotName, home)
	local Players = game:GetService('Players')
	local player = Players.LocalPlayer
	if not player or not frame then return end
	local homePos, homeAnchor = frame.Position, frame.AnchorPoint
	task.spawn(function()
		while frame.Parent ~= nil or home ~= nil do
			local pg = player:FindFirstChildOfClass('PlayerGui')
			local hud = pg and pg:FindFirstChild('HoodHUD')
			local slot = hud and hud:FindFirstChild(slotName, true)
			if slot and frame.Parent ~= slot then
				frame.Parent = slot
				frame.AnchorPoint = Vector2.new(0.5, 0)
				frame.Position = UDim2.fromScale(0.5, 0)
			elseif not slot and home and frame.Parent ~= home then
				frame.Parent = home
				frame.AnchorPoint, frame.Position = homeAnchor, homePos
			end
			task.wait(1)
		end
	end)
end

return FightUI
