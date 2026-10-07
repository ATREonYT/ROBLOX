-- Treadmills train SPEED, the classic treadmill stat. Stand on the belt of a treadmill you have unlocked and
-- every second it adds its Multiplier to your Speed (TreadmillService). Speed makes you walk faster:
-- walkSpeed(speed) climbs quickly at first and flattens out toward a cap, so the first minute on the free Jog
-- treadmill already feels quicker, and long sessions on Sprint still pay a little.
--
-- Unlocks use Power (the profile's Rep), on the same steps as the training bags in Config/Skins: Run opens
-- with the Street bag (150) and Sprint with the Speed bag (1000).
local C = Color3.fromRGB

local Treadmills = {}

-- Ladder order = tier. Color is the tier colour (the +Speed pops, the HUD hint); Label is the near-white,
-- tier-tinted "x1 Speed" over the machine (the colour lerped 45% toward white). The machines' own colours
-- live with the map builder.
Treadmills.List = {
	{ Id = 'Jog', Name = 'Jog', Required = 0, Multiplier = 1, Tier = 1, Color = C(110, 235, 255), Label = C(180, 244, 255) },
	{ Id = 'Run', Name = 'Run', Required = 150, Multiplier = 3, Tier = 2, Color = C(255, 190, 70), Label = C(255, 222, 160) },
	{ Id = 'Sprint', Name = 'Sprint', Required = 1000, Multiplier = 10, Tier = 3, Color = C(235, 120, 255), Label = C(245, 190, 255) },
}
Treadmills.ById = {}
for _, t in Treadmills.List do Treadmills.ById[t.Id] = t end

-- Speed -> Humanoid.WalkSpeed: Base + (Max - Base) * ln(1 + s / Knee) / ln(1 + Full / Knee), held at Max from
-- Full Speed on. With these numbers: 1 minute of Jog (60) = 20.7, 5 minutes (300) = 25.3, 1K = 29.2,
-- 10K = 36.9, 25K = 40 (about 40 minutes on Sprint).
Treadmills.WalkSpeed = { Base = 16, Max = 40, Knee = 20, Full = 25000 }

-- Speed is a plain count; anything that isn't a finite number >= 0 counts as 0.
local function clean(speed)
	if type(speed) ~= 'number' or speed ~= speed or speed < 0 then return 0 end
	return speed
end

-- The WalkSpeed a player with `speed` Speed gets, rounded to 0.1.
function Treadmills.walkSpeed(speed)
	local w = Treadmills.WalkSpeed
	local s = math.min(clean(speed), w.Full)
	local k = math.log(1 + s / w.Knee) / math.log(1 + w.Full / w.Knee)
	return math.floor((w.Base + (w.Max - w.Base) * k) * 10 + 0.5) / 10
end

-- Whether `power` opens treadmill `id`.
function Treadmills.unlocked(power, id)
	local t = Treadmills.ById[id]
	return t ~= nil and type(power) == 'number' and power >= t.Required
end

-- Speed paid per second on treadmill `id` (0 for an unknown id).
function Treadmills.gain(id)
	local t = Treadmills.ById[id]
	return t and t.Multiplier or 0
end

-- The belt's look, shared by the map builder and Treadmill.client (which scrolls it): zebra stripes with bold
-- V's, like the reference. Dark slats Depth studs deep run across a light belt Spacing studs apart; white
-- chevrons (V's pointing back, the way the belt runs) are painted across the slats, one every Period studs (a
-- whole number of slats, so every V is the same), arms Stroke studs thick (measured along the belt) spreading
-- Slope studs sideways per stud. The light gaps merge with the white pieces into solid V's. Scroll is the
-- belt speed per tier, in studs per second.
Treadmills.Pattern = { Spacing = 0.36, Depth = 0.22, Period = 3.6, Slope = 1.2, Stroke = 1.6, HalfWidth = 2.6 }
Treadmills.Scroll = { 3, 5, 8 }

-- The right-hand white piece on a slat at belt coordinate s (studs along the belt, + toward the console):
-- its centre x and width, or nil when that slat has no white there. The left piece mirrors it.
function Treadmills.chevron(s, pattern)
	pattern = pattern or Treadmills.Pattern
	local phase = s % pattern.Period
	local k, hw = pattern.Slope, pattern.HalfWidth
	local a, b = math.max(0, k * (phase - pattern.Stroke)), math.min(k * phase, hw)
	if b - a < 0.08 then return nil end
	return (a + b) / 2, b - a
end

-- The floating label (a BillboardGui with Chip, Cost, Detail and Speed): one line, "x1 Speed", once the
-- treadmill is yours, like the reference; the price chip and "Locked" over it only while it is locked. The gui
-- hangs above its anchor (the anchor marks the label's bottom edge), so switching never moves the bottom.
-- Used by the map builder and Treadmill.client.
Treadmills.LabelSize = { Width = 4.8, Open = 1.3, Locked = 2.76 }
function Treadmills.layoutLabel(gui, locked)
	local s = Treadmills.LabelSize
	local h = locked and s.Locked or s.Open
	gui.Size = UDim2.fromScale(s.Width, h)
	gui.StudsOffset = Vector3.new(0, h / 2, 0)
	for _, name in { 'Chip', 'Cost', 'Detail' } do
		local item = gui:FindFirstChild(name)
		if item then item.Visible = locked end
	end
	local speed = gui:FindFirstChild('Speed')
	if speed then
		speed.Position = UDim2.fromScale(0, locked and 0.52 or 0)
		speed.Size = UDim2.fromScale(1, locked and 0.46 or 1)
	end
end

return Treadmills
