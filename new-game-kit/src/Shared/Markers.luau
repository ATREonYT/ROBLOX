--!strict
-- New Game Kit: Markers (vault "Realistic City RP/01 HUD, World Icons and Interaction")
-- Install: ReplicatedStorage/Kit/Markers (ModuleScript). Pure maths for the world-icon layer.
--
-- The round icons floating over the bank, gas station, barber, gun store and job spots.
-- Two ways to draw them (the note explains when to use which):
--   A) a BillboardGui per place (AlwaysOnTop, MaxDistance): simplest, fine for < 40 icons
--   B) ONE ScreenGui layer that projects every icon with Camera:WorldToViewportPoint each frame:
--      lets icons stick to the screen edge with an arrow when off-screen (the active job, your car,
--      a 911 call), shrink with distance, fade when close, and never overlap the HUD.
-- This module is the maths for B; the client script owns the ImageLabels.
--
--   Markers.Size(distance)                         -> pixel size (big near, small far, clamped)
--   Markers.Alpha(distance)                        -> 0..1 transparency (fades out when you're on top of it)
--   Markers.Place(screenX, screenY, depth, view, edge) -> x, y, onScreen, arrowAngle
--   Markers.Pick(list, budget)                     -> the `budget` most important markers to draw
-- Status: covered by tests/Markers.spec.luau (offline).

local Markers = {}

Markers.Style = {
	nearSize = 46, -- px at nearDistance or closer (matches a 44-48 px tap target)
	farSize = 22, -- px at farDistance or further
	nearDistance = 30,
	farDistance = 600,
	fadeInside = 12, -- studs: you're standing at it, the prompt takes over
	fadeOver = 8, -- studs of fade
	maxDistance = 900, -- beyond this the icon is hidden (ambient places); tracked ones ignore it
	edgeMargin = 36, -- px from the screen edge for clamped (off-screen) icons
	budget = 24, -- max icons drawn per frame (phones)
}

function Markers.Size(distance: number): number
	local s = Markers.Style
	local k = math.clamp((distance - s.nearDistance) / (s.farDistance - s.nearDistance), 0, 1)
	-- ease-out so mid-distance icons stay readable
	k = 1 - (1 - k) * (1 - k)
	return math.floor(s.nearSize + (s.farSize - s.nearSize) * k + 0.5)
end

-- Returns ImageTransparency: 1 = hidden, 0 = solid.
function Markers.Alpha(distance: number, tracked: boolean?): number
	local s = Markers.Style
	if not tracked and distance > s.maxDistance then
		return 1
	end
	if distance <= s.fadeInside then
		return 1
	end
	if distance < s.fadeInside + s.fadeOver then
		return 1 - (distance - s.fadeInside) / s.fadeOver
	end
	return 0
end

export type View = { width: number, height: number, insetTop: number? }

-- screenX/screenY/depth come straight from Camera:WorldToViewportPoint (depth < 0 = behind the camera).
-- edge = true clamps off-screen icons to the border and returns the arrow angle in degrees
-- (0 = pointing right, 90 = down; set ImageLabel.Rotation to it). edge = false hides them.
function Markers.Place(screenX: number, screenY: number, depth: number, view: View, edge: boolean): (number, number, boolean, number?)
	local m = Markers.Style.edgeMargin
	local top = (view.insetTop or 0) + m
	local cx, cy = view.width / 2, view.height / 2
	local inside = depth > 0 and screenX >= m and screenX <= view.width - m and screenY >= top and screenY <= view.height - m
	if inside then
		return screenX, screenY, true, nil
	end
	if not edge then
		return screenX, screenY, false, nil
	end
	local dx, dy = screenX - cx, screenY - cy
	if depth <= 0 then
		-- behind the camera the projection is mirrored: flip it so the arrow points the right way
		dx, dy = -dx, -dy
	end
	if dx == 0 and dy == 0 then
		dy = 1
	end
	local halfW, halfH = cx - m, cy - top
	local scale = math.min(halfW / math.max(math.abs(dx), 1e-6), halfH / math.max(math.abs(dy), 1e-6))
	local x, y = cx + dx * scale, cy + dy * scale
	return x, y, false, math.deg(math.atan2(dy, dx))
end

export type Entry = { id: string, distance: number, priority: number, tracked: boolean? }

-- Keeps the most useful icons when there are too many: tracked first, then priority, then nearest.
function Markers.Pick(list: { Entry }, budget: number?): { Entry }
	local keep = {}
	for _, e in list do
		if e.tracked or e.distance <= Markers.Style.maxDistance then
			table.insert(keep, e)
		end
	end
	table.sort(keep, function(a, b)
		if (a.tracked == true) ~= (b.tracked == true) then
			return a.tracked == true
		end
		if a.priority ~= b.priority then
			return a.priority > b.priority
		end
		return a.distance < b.distance
	end)
	local n = budget or Markers.Style.budget
	while #keep > n do
		table.remove(keep)
	end
	return keep
end

return Markers
