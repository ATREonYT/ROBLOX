--!strict
-- The quick tutorial (brief 29, P4). The user: "make it very quick, just the pure basics so people keep the retention, no
-- cutscenes or intros, straight to the point (a white box over what the player needs to press, that smoothly moves to the next
-- thing) ... make it actual white arrows showing you where to go, for the tutorial first and then remove them ... point in a
-- straight line exactly towards the next goal". Pure rules for HoodClient/Tutorial; HoodServer/OnboardingService still decides
-- the step (Shared/OnboardingRules, the player attribute OnboardingStep), so nothing about saves or the first-30 route moves.
--   Three basics, four screens: BAY 1 (walk in, the gun shoots by itself), the gate and the Stage 1 crew (walk through, hold to
--   shoot), the cash pad (step on it), and the welcome gift that waits by the spawn after it. Gun and Run (the first gun,
--   back out) are the goal chain's job (the goal tracker says them), so the tutorial ends there: no white box, no arrows, and
--   the old yellow trails are gone for good (HoodClient/Lobby's floor guide and Onboarding's trail no longer draw).
--   Text: "<Key>" marks the key word, drawn yellow; it types in at TypeRate characters a second (the reference's ~24).
local TutorialRules = {}

TutorialRules.TypeRate = 24
TutorialRules.Total = 3 -- the basics (BAY 1, the crew, the cash); the gift is part of "the cash"
TutorialRules.Steps = {
	Train = { Part = 1, Text = 'Walk into <BAY 1> and it shoots!', Target = 'lane' },
	Door = { Part = 2, Text = 'Go through the <gate>!', Target = 'door' },
	Fight = { Part = 2, Text = '<Hold click> to shoot the crew!', Target = 'goon', Touch = '<Hold SHOOT> to shoot the crew!' },
	Cash = { Part = 3, Text = 'Step on the <yellow pad>!', Target = 'pad' },
	Gift = { Part = 3, Text = 'Grab your <free gift>!', Target = 'gift' },
}

-- The tutorial step for an OnboardingStep, or nil when the tutorial is not on (Gun, Run, Done, nothing).
function TutorialRules.step(onboardingStep: any)
	if type(onboardingStep) ~= 'string' then return nil end
	return TutorialRules.Steps[onboardingStep]
end

-- Cut the text into { { Text, Key } } pieces at the <...> marks.
function TutorialRules.pieces(text: string): { { Text: string, Key: boolean } }
	local out = {}
	local rest = text
	while #rest > 0 do
		local a, b = string.find(rest, '<[^>]*>')
		if not a then
			table.insert(out, { Text = rest, Key = false })
			break
		end
		if a > 1 then table.insert(out, { Text = string.sub(rest, 1, a - 1), Key = false }) end
		table.insert(out, { Text = string.sub(rest, a + 1, b - 1), Key = true })
		rest = string.sub(rest, b + 1)
	end
	return out
end

-- The text as RichText, the first `chars` characters of it (the typewriter); key words in `keyColor` ('#FFD21F').
function TutorialRules.rich(text: string, chars: number?, keyColor: string?): string
	local color = keyColor or '#FFD21F'
	local left = chars or math.huge
	local out = {}
	for _, piece in TutorialRules.pieces(text) do
		if left <= 0 then break end
		local shown = piece.Text
		local n = utf8.len(shown) or #shown
		if n > left then
			local at = utf8.offset(shown, left + 1)
			shown = string.sub(shown, 1, (at or (#shown + 1)) - 1)
		end
		left -= n
		table.insert(out, piece.Key and ('<font color="' .. color .. '">' .. shown .. '</font>') or shown)
	end
	return table.concat(out)
end

-- Characters the typewriter has typed after `seconds`.
function TutorialRules.typed(seconds: any): number
	if type(seconds) ~= 'number' or seconds ~= seconds then return 0 end
	return math.max(0, math.floor(seconds * TutorialRules.TypeRate))
end

-- The ground arrows: points on the STRAIGHT line from `from` to `to` (flat, at from's height), `spacing` studs apart, the
-- first `lead` studs from `from` and the last `stop` studs short of the target, at most `max`. `phase` (0..1) slides them
-- toward the target so they flow. Every arrow points along the same unit direction: exactly at the goal.
-- Returns the points and that direction (a zero direction and no points when you're there).
function TutorialRules.arrows(from: Vector3, to: Vector3, phase: number?, spacing: number?, max: number?, lead: number?, stop: number?)
	local flat = Vector3.new(to.X - from.X, 0, to.Z - from.Z)
	local length = flat.Magnitude
	local stopAt = stop or 3
	if length < stopAt + 1 then return {}, Vector3.zero end
	local dir = flat / length
	local gap = spacing or 4
	local points = {}
	local start = (lead or 3) + (phase or 0) % 1 * gap
	local d = start
	while d <= length - stopAt and #points < (max or 9) do
		table.insert(points, Vector3.new(from.X + dir.X * d, from.Y, from.Z + dir.Z * d))
		d += gap
	end
	return points, dir
end

-- The white box's centre for a target's screen spot: on screen it sits on the target; otherwise it rests on the screen's
-- edge, toward where the target is (so it still points the way). Returns x, y (pixels) and whether it is on the edge.
function TutorialRules.boxAt(x: number, y: number, onScreen: boolean, vw: number, vh: number, margin: number?): (number, number, boolean)
	local m = margin or 60
	if onScreen and x >= m and x <= vw - m and y >= m and y <= vh - m then return x, y, false end
	local cx, cy = vw / 2, vh / 2
	local dx, dy = x - cx, y - cy
	if dx == 0 and dy == 0 then dy = 1 end
	local k = math.min((cx - m) / math.max(math.abs(dx), 1e-6), (cy - m) / math.max(math.abs(dy), 1e-6))
	return cx + dx * k, cy + dy * k, true
end

return TutorialRules
