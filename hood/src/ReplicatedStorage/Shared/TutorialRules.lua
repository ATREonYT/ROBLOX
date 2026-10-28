-- The quick tutorial's rules (brief 30, TUTORIAL; drawn by HoodClient/Tutorial). Pure functions, unit-tested in
-- UnitTest/Cases/Tutorial30_Test. The user: "make it very quick, just the pure basics ... no cutscenes or intros ... a white
-- box over what the user needs to press ... actual white arrows showing you where to go, for the tutorial first and then
-- remove them ... point in a straight line exactly towards the next goal"; brief 30: "box is misplaced everywhere, it
-- doesnt look tidy, it just jumps around ... make the arrows points more presicely".
-- Every number below is measured on the soldier game's tutorial (the reference bible, section 2.8; frames in
-- brief/B30/frames and brief/B30/work/tutA..C, V4 at 15 fps):
--   * The WHITE BOX only ever frames a UI element (a HUD button, a window's button), never a 3D point. Its line is white,
--     about 3 px at 960 x 582 (0.52 % of the screen's height), its inner edge about 14 % of the target's shorter side
--     out from the target (the Items button: 60 px, 9 px gap; ref_V4_tutorial_box_crops.jpg), corners about 12 % of the
--     box. It LOCKS ON: it appears at about 1.45x and faint, and shrinks to 1.0x as it brightens in 0.13 s (V4 1.67 ->
--     1.73 -> 1.80 s on the Abilities tab, 3.40 -> 3.47 s on the Grenade tile), then sits still: no drift, no breathing.
--   * The DIM: a dark mask with a HOLE where the box is (the world 127 -> 55 luma, the neighbouring Skins button
--     83 -> 32: about 59 % darker; the target unchanged). The hole follows the box while it locks on (at 3.40 s the
--     ring inside the big faint box is still bright), and the mask fades in over about 0.2 s (1.67 s 0 %, 1.73 s about
--     half, 1.87 s full).
--   * The cyan "1" on the Items button and on the Abilities tab is the GAME's new-item badge, not part of the box: it
--     slides away with the Items button at 1.6 s while the box stays (ref_V4-01.6_tut1_press_dim_lift.jpg) and stays on
--     the tab after the box has left (tutB f_051..f_055). We draw the same badge on the first boxed button of a lesson
--     (the one that opens the window), centred on its top-right corner, 28 % of its size, and not on the last one
--     (the Grenade tile has none).
--   * The HINT: a dark rounded box at the bottom centre, 31.9 % of the screen wide and 13.1 % high, centred at 63.2 %
--     of its height (306 x 76 px at 960 x 582, a 2 px light-grey edge and a 1 px black ring), one line of bold white
--     text with the key word yellow #FFD21F, typed in at 32 characters a second ("Click ABILITIES!" 16 characters in
--     0.45 s); it starts in the same frame as the box.
-- The WORLD steps (BAY 1, the gate, the fight, the cash pad, the gift) have no box and no dim, like the reference's
-- "Now go try it out!": the hint, plus the user's straight white ground arrows, which point exactly at the target's
-- centre on the floor, lie on the straight line from the player to it, and are gone once the tutorial is over.
local TutorialRules = {}

TutorialRules.TypeRate = 32 -- characters a second
TutorialRules.KeyColor = '#FFD21F'

---------------------------------------------------------------------------------------------- the steps
-- The world steps, one per server OnboardingStep (HoodServer/OnboardingService decides; Shared/OnboardingRules). Gun, Run
-- and Done have none: the goal chain carries on alone and every arrow is gone for good.
--   Text     the hint ("<...>" marks the key word, drawn yellow); Touch replaces it on a touch screen
--   Target   what the arrows point at: 'Lane' (BAY 1's shooter's box), 'Gate' (the middle of Stage 1's gate opening),
--            'Pad' (the yellow pad of the stage just cleared), 'Gift' (the welcome present); nil: no arrows
--   InLane   the text while you stand in BAY 1 (it shoots by itself; no arrows)
TutorialRules.Steps = {
	Train = { Text = 'Walk into <BAY 1>!', InLane = '<BAY 1> shoots for you!', Target = 'Lane' },
	Door = { Text = 'Go to <STAGE 1>!', Target = 'Gate' },
	Fight = { Text = '<Hold click> to shoot the crew!', Touch = '<Hold SHOOT> to shoot the crew!' },
	Cash = { Text = 'Step on the <yellow pad>!', Target = 'Pad' },
	Gift = { Text = 'Grab your <free gift>!', Target = 'Gift' },
}
TutorialRules.Order = { 'Train', 'Door', 'Fight', 'Cash', 'Gift' }

-- (Oct 27, flow: the owner's "no flow"; the audit found hints that said where to walk and never why) Three short WHY
-- lines, each at a calm moment, and each true to how the game works: Power is the damage of every shot, so it beats the
-- crews (a gate opens when its crew is beaten); Cash buys the ARMORY's guns and the shoe boxes; a rebirth keeps your
-- Cash, guns and shoes and its multiplier stays for good (the rebirth moment says "x2 Power forever!").
--   In BAY 1 the "it shoots for you" line boxes the HUD's Power count (the white box, no dim), so you watch it climb to
--   the gate's Power, and the Power line follows it while you are still there. Back home with your first Cash (the Gun step, which has no arrows of
--   ours: the goal guide's gold arrow points at the ARMORY), the Cash line, then where to spend it.
TutorialRules.Why = {
	Power = { Text = 'More <POWER> beats tougher crews!', Box = 'Power', Why = true },
	Cash = { Text = '<CASH> buys guns and shoe boxes!', Why = true },
	Keep = { Text = 'You keep your <Cash>, guns and shoes!', Why = true },
}
-- Lines for the steps after the arrows (no target: HoodClient/GoalGuide's arrow shows the way there).
TutorialRules.Talk = {
	Gun = { TutorialRules.Why.Cash, { Text = 'Get a <gun> at the ARMORY!' } },
	Run = { { Text = 'Now go <further> down the street!' } },
}
-- A WHY line stays up this long once typed (a plain line: HintHold) before the next one may take its place.
TutorialRules.ReadHold = 2.2

-- (Oct 28, the owner: "there isn't a well done core loop") THE LOOP, always in view over the tutorial's card: five
-- chips, TRAIN > SHOOT > EARN > BUY > REBIRTH, the one you are on lit gold and the ones done green, so the first
-- minutes read as one loop you go round, not a list of errands. Each tutorial step maps onto it; the rebirth lesson
-- (the first time the Rebirth bar fills) is its last chip.
TutorialRules.Loop = { 'TRAIN', 'SHOOT', 'EARN', 'BUY', 'REBIRTH' }
local LOOP_OF = { Train = 1, Door = 2, Fight = 2, Cash = 3, Gift = 3, Gun = 4 }
-- The loop's state for the server's OnboardingStep and the rebirth lesson's step (TutorialRules.lessonStep): the chip
-- you are on (nil: none lit) and how many are done; nil, nil when the loop isn't shown (the tutorial is over and no
-- lesson runs, or nothing is known yet).
function TutorialRules.loopAt(onboardingStep, lessonStep)
	if lessonStep == 'After' then return nil, 5 end
	if lessonStep == 'Open' or lessonStep == 'Press' then return 5, 4 end
	local i = type(onboardingStep) == 'string' and LOOP_OF[onboardingStep] or nil
	if i then return i, i - 1 end
	if onboardingStep == 'Run' then return nil, 4 end -- (bought: the first four done; REBIRTH comes when its bar fills)
	return nil, nil
end
-- The celebration words, one per finished step, in turn (never the same twice running): short, loud and kind.
TutorialRules.Cheers = { 'NICE!', 'GREAT!', 'AWESOME!', 'YOU GOT IT!', 'AMAZING!' }
function TutorialRules.cheer(n)
	local list = TutorialRules.Cheers
	n = (type(n) == 'number' and n >= 1) and math.floor(n) or 1
	return list[(n - 1) % #list + 1]
end
-- Seconds a step's celebration may wait for a busy screen (the unboxing, the new gun's moment) before it is dropped.
TutorialRules.CheerWait = 8

-- The lines for where you are, in order (each { Text, Box?, Why? }; the last one stays), and the arrows' target. The
-- first line is worldHint's; BAY 1 adds the Power line; Gun and Run talk without arrows.
function TutorialRules.lines(onboardingStep, inLane, touch)
	local text, target = TutorialRules.worldHint(onboardingStep, inLane, touch)
	if text then
		local list = { { Text = text } }
		if onboardingStep == 'Train' and inLane then list = { TutorialRules.LaneLine, TutorialRules.Why.Power } end
		return list, target
	end
	local talk = type(onboardingStep) == 'string' and TutorialRules.Talk[onboardingStep] or nil
	if talk then return talk, nil end
	return {}, nil
end
-- BAY 1's first line points at the Power count already (the kid can reach the gate's Power in a few seconds there).
TutorialRules.LaneLine = { Text = TutorialRules.Steps.Train.InLane, Box = 'Power' }
-- The line (from Why / Talk / Steps) a text belongs to, for its box and its hold; nil for none.
function TutorialRules.lineOf(text)
	if type(text) ~= 'string' then return nil end
	for _, l in TutorialRules.Why do if l.Text == text then return l end end
	if text == TutorialRules.LaneLine.Text then return TutorialRules.LaneLine end
	return nil
end

-- (brief 32, FEEL) A hint is never cut off mid-word: a new line waits until the one on screen has been typed out and read
-- for HintHold seconds (filmed: "BAY 1 shoots for you!" was replaced by "Go to STAGE 1!" before it finished typing).
TutorialRules.HintHold = 0.9
-- Seconds the line on screen (`text`, shown since `since`) still holds at `now` (0: a new line may take its place).
function TutorialRules.holdLeft(text, since, now)
	if type(text) ~= 'string' or type(since) ~= 'number' or type(now) ~= 'number' then return 0 end
	local _, n = TutorialRules.plain(text)
	local l = TutorialRules.lineOf(text)
	local hold = (l and l.Why) and TutorialRules.ReadHold or TutorialRules.HintHold -- (Oct 27, flow: a why line is read)
	return math.max(0, since + n / TutorialRules.TypeRate + hold - now)
end
-- (brief 32, FEEL) The fight's line ("Hold click to shoot the crew!") leaves once you have got it: the first goon of the
-- crew falls, or FightHintFor seconds pass. The reference shows no hint in a fight at all (W 30-34 s): the box in the
-- middle of the screen sat over the crew and over you while you fought.
TutorialRules.FightHintFor = 3
-- Still show the fight's line? seconds: since the Fight step began; leftAtStart / leftNow: the crew standing then and now.
function TutorialRules.fightHintOn(seconds, leftAtStart, leftNow)
	if type(seconds) ~= 'number' or seconds ~= seconds or seconds >= TutorialRules.FightHintFor then return false end
	if type(leftAtStart) == 'number' and type(leftNow) == 'number' and leftNow < leftAtStart then return false end
	return true
end

-- The world step for an OnboardingStep, or nil (Gun, Run, Done, junk).
function TutorialRules.step(onboardingStep)
	if type(onboardingStep) ~= 'string' then return nil end
	return TutorialRules.Steps[onboardingStep]
end

-- The hint for a world step: the text for where you are (in BAY 1, on a touch screen) and the arrows' target (nil: none).
function TutorialRules.worldHint(onboardingStep, inLane, touch)
	local s = TutorialRules.step(onboardingStep)
	if not s then return nil, nil end
	if inLane and s.InLane then return s.InLane, nil end
	return (touch and s.Touch) or s.Text, s.Target
end

-- The ONE UI lesson, boxed: the first rebirth. Chosen with the reference's logic: its boxed tutorial starts the moment the
-- game hands you something new that only works once you click through the UI (the Grenade: open Items, the Abilities
-- tab, equip it), and waits for each click. Ours: the first time the Rebirth bar is full, the rebirth is the new thing
-- and it only happens through two clicks (the HUD's Rebirth button, then the window's Rebirth button). Shoes after the
-- first box would teach nothing: the welcome pairs go straight onto your feet (ShoeOpening: Equipped).
--   Box      'Hud' = HoodHUD's Rebirth button, 'Window' = the Rebirth window's Rebirth button
--   Badge    the new-thing badge on the box's target (the reference's cyan "1"; the first button only)
TutorialRules.Lesson = {
	Open = { Text = 'Open <REBIRTH>!', Box = 'Hud', Badge = '1' },
	Press = { Text = 'Click <REBIRTH>!', Touch = 'Tap <REBIRTH>!', Box = 'Window' },
	-- (the reference's "Now go try it out!": no box, it stays a moment, under the HUD's own "Rebirth 1! 2x Power forever!",
	-- so it says what to do next rather than the multiplier again)
	After = { Text = 'Now go <train> again!', Before = 'Keep' }, -- (Oct 27, flow: first what you keep, TutorialRules.Why.Keep)
}
TutorialRules.LessonGiveUp = 15 -- seconds a lesson step may wait unanswered on screen before it leaves for this visit
TutorialRules.AfterSeconds = 6.4 -- how long the after-lines stay: the Keep line read, then "Now go train again!" about 3 s

-- The lesson's step for a state (missing = 0 / false / ''):
--   Rebirths, RebirthReady     the rebirth attributes
--   WorldStep                  the OnboardingStep (the world tutorial goes first: no lesson while it runs)
--   Window                     PlayerGui.HoodWindow ('' = none)
--   Busy                       something owns the screen (a fight, the unboxing, a popup card, the rank-up)
--   GaveUp                     the lesson left for this visit (ignored for LessonGiveUp seconds)
--   AfterLeft                  seconds the last line still has (it runs once the first rebirth is done)
-- Returns 'Open' | 'Press' | 'After' | nil.
function TutorialRules.lessonStep(s)
	s = type(s) == 'table' and s or {}
	local n = type(s.Rebirths) == 'number' and s.Rebirths or 0
	if n >= 1 then
		return (type(s.AfterLeft) == 'number' and s.AfterLeft > 0) and 'After' or nil
	end
	if s.RebirthReady ~= true or s.GaveUp == true or s.Busy == true then return nil end
	if TutorialRules.step(s.WorldStep) then return nil end
	local w = type(s.Window) == 'string' and s.Window or ''
	if w == 'Rebirth' then return 'Press' end
	if w ~= '' then return nil end
	return 'Open'
end

---------------------------------------------------------------------------------------------- the hint's text
-- Cut the text into { { Text, Key } } pieces at the <...> marks.
function TutorialRules.pieces(text)
	local out = {}
	local rest = type(text) == 'string' and text or ''
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

-- The text without its marks, and its length in characters.
function TutorialRules.plain(text)
	local t = {}
	for _, p in TutorialRules.pieces(text) do table.insert(t, p.Text) end
	local s = table.concat(t)
	return s, utf8.len(s) or #s
end

-- The text as RichText, the first `chars` characters of it (the typewriter); key words in `keyColor` (#FFD21F).
function TutorialRules.rich(text, chars, keyColor)
	local color = keyColor or TutorialRules.KeyColor
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
function TutorialRules.typed(seconds)
	if type(seconds) ~= 'number' or seconds ~= seconds then return 0 end
	return math.max(0, math.floor(seconds * TutorialRules.TypeRate + 1e-9))
end

---------------------------------------------------------------------------------------------- the box
TutorialRules.Box = {
	-- The box hugs what the target DRAWS (its fill and strokes, its picture, its words, a pill hanging off it; never an
	-- invisible hit area or padding frame), with one even gap on all four sides, in whole pixels:
	Pad = 0.07, -- the gap from the target's drawn edge to the line's inner edge, a share of the target's shorter side
	PadMin = 4, -- (px)
	PadMax = 0.035, -- (a share of the screen's height: a huge target keeps a modest gap)
	IconInset = 0.06, -- our 3D icons' pictures (UIKit's Icon3D_ frames) keep this much clear margin on each side
	Line = 0.0052, -- the line's thickness, a share of the screen's height (3 px at 582)
	LineMin = 2, LineMax = 6, -- (px)
	LockScale = 1.45, -- the box appears this much bigger ...
	LockTime = 0.13, -- ... and shrinks to 1.0 in this long (Quad out), while its line goes from LockAlpha to solid
	LockAlpha = 0.35, -- (the line's opacity in the first frame)
	MaskTime = 0.2, -- the dim fades in over this long (Quad out)
	Dim = 0.41, -- the mask's BackgroundTransparency at full dim (59 % darker)
	Badge = 0.28, -- the new-thing badge's size, a share of the target's shorter side
	BadgeMin = 14, BadgeMax = 30, -- (px)
	Settle = 2, -- frames a target's resting place must hold still before the box locks on to it
	Still = 0.75, -- px: closer than this is the same place (no new lock-on, no jump)
}

-- The line's thickness (px) for a screen `height` px tall.
function TutorialRules.lineFor(height)
	local B = TutorialRules.Box
	local h = (type(height) == 'number' and height == height and height > 0) and height or 720
	return math.clamp(math.floor(h * B.Line + 0.5), B.LineMin, B.LineMax)
end

-- The even gap (whole px) around a target `size` (Vector2 px) on a screen `height` px tall. maxPad (px, optional): the
-- most it may be, so the line stays in the gutter to the next button; never under PadMin.
function TutorialRules.padFor(size, height, maxPad)
	local B = TutorialRules.Box
	local h = (type(height) == 'number' and height > 0) and height or 720
	local short = math.max(0, math.min(size.X, size.Y))
	local pad = math.clamp(math.floor(short * B.Pad + 0.5), B.PadMin, math.max(B.PadMin, math.floor(h * B.PadMax + 0.5)))
	if type(maxPad) == 'number' and maxPad == maxPad then pad = math.max(B.PadMin, math.min(pad, math.floor(maxPad))) end
	return pad
end

-- The box around a target's drawn bounds (pos, size: Vector2 px, top-left and size) on a screen `height` px tall: the
-- line's inner edge (pos, size, in whole px: the target's edges are rounded first, so the gap is the same on all four
-- sides), its corner radius (the target's own outer radius `radius` plus the gap: the line runs parallel to the target's
-- corners) and the gap. maxPad: see padFor.
function TutorialRules.boxRect(pos, size, height, maxPad, radius)
	local pad = TutorialRules.padFor(size, height, maxPad)
	local x0, y0 = math.floor(pos.X + 0.5), math.floor(pos.Y + 0.5)
	local x1, y1 = math.floor(pos.X + size.X + 0.5), math.floor(pos.Y + size.Y + 0.5)
	local p = Vector2.new(x0 - pad, y0 - pad)
	local s = Vector2.new(x1 - x0 + 2 * pad, y1 - y0 + 2 * pad)
	local r = math.max(0, (type(radius) == 'number' and radius == radius) and radius or 0) + pad
	return p, s, math.min(math.floor(r + 0.5), math.floor(math.min(s.X, s.Y) / 2)), pad
end

-- The smallest rect holding every rect in `rects` ({ { pos, size } }), or nil for none.
function TutorialRules.union(rects)
	local x0, y0, x1, y1
	for _, r in rects or {} do
		local p, s = r[1], r[2]
		if p and s and s.X >= 0 and s.Y >= 0 then
			x0 = x0 and math.min(x0, p.X) or p.X
			y0 = y0 and math.min(y0, p.Y) or p.Y
			x1 = x1 and math.max(x1, p.X + s.X) or p.X + s.X
			y1 = y1 and math.max(y1, p.Y + s.Y) or p.Y + s.Y
		end
	end
	if not x0 then return nil, nil end
	return Vector2.new(x0, y0), Vector2.new(x1 - x0, y1 - y0)
end

-- Where a label's words sit: a `textSize` (Vector2 px: the text's bounds) block placed in the label's rect (pos, size)
-- by its alignments ('Left' | 'Center' | 'Right', 'Top' | 'Center' | 'Bottom').
function TutorialRules.textRect(pos, size, textSize, xAlign, yAlign)
	local x = xAlign == 'Left' and pos.X or xAlign == 'Right' and (pos.X + size.X - textSize.X) or (pos.X + (size.X - textSize.X) / 2)
	local y = yAlign == 'Top' and pos.Y or yAlign == 'Bottom' and (pos.Y + size.Y - textSize.Y) or (pos.Y + (size.Y - textSize.Y) / 2)
	return Vector2.new(x, y), textSize
end

-- A rect cut to another (a clipping frame's): nil when nothing is left.
function TutorialRules.clip(pos, size, cpos, csize)
	local x0, y0 = math.max(pos.X, cpos.X), math.max(pos.Y, cpos.Y)
	local x1, y1 = math.min(pos.X + size.X, cpos.X + csize.X), math.min(pos.Y + size.Y, cpos.Y + csize.Y)
	if x1 <= x0 or y1 <= y0 then return nil, nil end
	return Vector2.new(x0, y0), Vector2.new(x1 - x0, y1 - y0)
end

-- The most padding that keeps a `line` px line clear of the target's neighbours: rects { { pos, size } } of the other
-- buttons around it. Only a neighbour beside it (sharing rows) or above / below it (sharing columns) counts. nil: no
-- neighbour limits it.
function TutorialRules.gutterPad(pos, size, neighbours, line)
	local best
	local x0, y0, x1, y1 = pos.X, pos.Y, pos.X + size.X, pos.Y + size.Y
	for _, n in neighbours or {} do
		local a0, b0 = n[1].X, n[1].Y
		local a1, b1 = a0 + n[2].X, b0 + n[2].Y
		local gap
		if b1 > y0 and b0 < y1 then
			if a0 >= x1 then gap = a0 - x1 elseif a1 <= x0 then gap = x0 - a1 end
		elseif a1 > x0 and a0 < x1 then
			if b0 >= y1 then gap = b0 - y1 elseif b1 <= y0 then gap = y0 - b1 end
		end
		if gap and gap >= 0 and (not best or gap < best) then best = gap end
	end
	return best and (best - (line or 0)) or nil
end

-- A rect scaled by k about its centre.
function TutorialRules.scaled(pos, size, k)
	local c = pos + size / 2
	local s = size * k
	return c - s / 2, s
end

-- The lock-on at `t` seconds after the box first shows: its scale (LockScale -> 1), its line's opacity (LockAlpha -> 1)
-- and the dim's share (0 -> 1, over MaskTime). t < 0 is the first frame; past the times it sits still at 1, 1, 1.
function TutorialRules.lockOn(t)
	local B = TutorialRules.Box
	local a = math.clamp((type(t) == 'number' and t == t) and t / B.LockTime or 1, 0, 1)
	local m = math.clamp((type(t) == 'number' and t == t) and t / B.MaskTime or 1, 0, 1)
	local ease = 1 - (1 - a) ^ 2
	return 1 + (B.LockScale - 1) * (1 - ease), B.LockAlpha + (1 - B.LockAlpha) * a, 1 - (1 - m) ^ 2
end

-- Two rects the same (within Still px)?
function TutorialRules.same(p1, s1, p2, s2, tol)
	if not (p1 and s1 and p2 and s2) then return false end
	local e = tol or TutorialRules.Box.Still
	return math.abs(p1.X - p2.X) <= e and math.abs(p1.Y - p2.Y) <= e and math.abs(s1.X - s2.X) <= e and math.abs(s1.Y - s2.Y) <= e
end

-- Converts an AbsolutePosition from one ScreenGui's space to another's: each ScreenGui measures from its own top-left,
-- which sits `inset` px (a Vector2: the top bar, the notch) into the screen. srcInset / dstInset: the source's and the
-- overlay's (Vector2.zero for a ScreenGui that ignores the GUI inset).
function TutorialRules.toOverlay(absPos, srcInset, dstInset)
	return absPos + (srcInset or Vector2.zero) - (dstInset or Vector2.zero)
end

-- A target's RESTING rect: its AbsolutePosition/AbsoluteSize with the press-and-hover pops (UIMotion's MotionScale on it
-- or on a window around it, e.g. the 0.8 -> 1 spring of a window opening) taken out, so a button that swells under the
-- mouse or a window still springing open does not move the box. chain: from the OUTERMOST scaled ancestor down to the
-- target, { Pos, Size (Vector2, absolute), Anchor (Vector2), Scale (its MotionScale, 1 = none) }; the target is the last.
-- Each scale grows its object about its AnchorPoint (as Roblox's UIScale does), so the rects are unwound from the outside in.
function TutorialRules.restRect(chain)
	local a, b = 1, Vector2.zero -- the unwinding so far: x -> x * a + b
	for _, n in chain do
		local s = (type(n.Scale) == 'number' and n.Scale > 1e-3) and n.Scale or 1
		if s ~= 1 then
			local anchorAbs = n.Pos + n.Size * n.Anchor
			local q = anchorAbs * a + b -- (where that anchor rests once the outer pops are out)
			-- x -> q + (x * a + b - q) / s
			a, b = a / s, q + (b - q) / s
		end
	end
	local t = chain[#chain]
	if not t then return nil, nil end
	return t.Pos * a + b, t.Size * a
end

-- The dim around a hole (pos, size: the box's inner edge) on a screen: four rects { pos, size } (top, bottom, left,
-- right) that cover everything else, reaching `reach` px past the screen's edges (the top bar, a notch) and never
-- overlapping. The hole's rounded corners are filled by cornerRows.
function TutorialRules.maskRects(pos, size, screen, reach)
	local r = reach or 4000
	local x0, y0, x1, y1 = pos.X, pos.Y, pos.X + size.X, pos.Y + size.Y
	local L, T, R, Bt = -r, -r, screen.X + r, screen.Y + r
	return {
		{ Vector2.new(L, T), Vector2.new(R - L, math.max(0, y0 - T)) }, -- top
		{ Vector2.new(L, y1), Vector2.new(R - L, math.max(0, Bt - y1)) }, -- bottom
		{ Vector2.new(L, y0), Vector2.new(math.max(0, x0 - L), size.Y) }, -- left
		{ Vector2.new(x1, y0), Vector2.new(math.max(0, R - x1), size.Y) }, -- right
	}
end

-- One rounded corner of radius r px: for each 1-px row from the corner's outer edge inward, how far the dim reaches in
-- from the side (the part of the r x r corner square outside the quarter circle).
function TutorialRules.cornerRows(r)
	local rows = {}
	local n = math.max(0, math.ceil((type(r) == 'number' and r == r) and r or 0))
	for i = 0, n - 1 do
		local dy = r - (i + 0.5)
		local w = r - math.sqrt(math.max(0, r * r - dy * dy))
		rows[i + 1] = math.max(0, w)
	end
	return rows
end

-- The new-thing badge for a target (pos, size): its centre (on the target's top-right corner) and its diameter.
function TutorialRules.badgeFor(pos, size)
	local B = TutorialRules.Box
	local short = math.min(size.X, size.Y)
	local d = math.clamp(short * B.Badge, B.BadgeMin, B.BadgeMax)
	return Vector2.new(pos.X + size.X - short * 0.02, pos.Y + short * 0.02), d
end

---------------------------------------------------------------------------------------------- the hint box
-- Sizes on the UIKit design canvas of a full-screen ScreenGui (UIKit's scale is 1 on a 1280 x 720 screen, so there it is
-- the reference's share of the screen; phones get UIKit's usual 1.3x).
TutorialRules.Hint = {
	W = 408, H = 94, -- 31.9 % x 13.1 % of a 1280 x 720 screen
	Y = 0.632, -- its centre, a share of the whole screen's height
	TextSize = 25, -- (the reference's 20 px at 582 high: 3.4 %)
	MinText = 14,
	Corner = 9,
	Edge = 2, -- the light-grey edge (#737480), with a 1 px black ring outside it
	Fill = '14161F', FillT = 0.1, -- (over the world it shows as about #1B1E27)
	DockH = 54, DockPad = 26, DockGap = 8, -- (docked over a window's button: compact, just over the box)
	FadeIn = 0.13,
	FadeOut = 0.2,
	-- (Oct 27, flow r2: the critic's stills caught half-typed pills, "G", "Now go f") a new line shows whole at once: its
	-- words fade in and the pill grows from PopFrom to full size over Pop seconds (no typewriter)
	Pop = 0.3, PopFrom = 0.62,
	-- (Oct 28, the owner: "match the UI more ... more cartoony") the card is the mockup windows' navy card (Kit.Skin: a
	-- top-lit navy face, a thick ink outline, a light rim and a soft drop) and pops in with a small overshoot (Back out)
	-- from PopFrom; the words are TextStyle's white with its thick outline
	Card = true, Outline = 4, Rim = 2, Drop = 5, CardCorner = 14,
	-- (brief 32, FEEL) The WORLD steps' line (walk to BAY 1, the gate, the pad, the gift; no box): the compact strip, a little
	-- lower. Filmed with the follow camera, the full box at 63 % sat on your own character (the reference's sits on its
	-- soldier's legs, V4 7.0 s): here it clears your body and stays above the Power and Level row.
	WorldY = 0.705,
}

-- The text size that keeps `text` on one line in the hint (`fit` measures it: function(text, size) -> width px).
function TutorialRules.hintSize(text, fit)
	local H = TutorialRules.Hint
	local plain = TutorialRules.plain(text)
	local size = H.TextSize
	local room = H.W - 40
	if type(fit) == 'function' then
		while size > H.MinText and fit(plain, size) > room do size -= 1 end
	end
	return size
end

---------------------------------------------------------------------------------------------- the white arrows
TutorialRules.Arrows = {
	-- (the bible suggested 5-7 arrows 3 studs apart; filmed behind the player with Roblox's follow camera that whole chain
	-- sits behind the avatar and under the hint: the floor 3-30 studs ahead of you is hidden by your own body. So the
	-- chain runs on toward the target, up to Count arrows, and the far ones, where you are going, show over your head.)
	Count = 12, -- arrows at most (48 studs of them)
	Spacing = 4, -- studs between arrows
	Lead = 3, -- the first one this far ahead of you
	Stop = 3, -- the last one this far short of the target
	Hide = 6, -- none once you are this close (flat studs)
	Fade = 1.5, -- studs over which an arrow fades out at your feet ...
	FadeFar = 4, -- ... and in at the far end of the chain
	Length = 2.6, HeadLength = 1.15, HeadWidth = 2.0, ShaftWidth = 0.72, -- (studs)
	Smooth = 0.08, -- seconds: the line follows you this softly (no jitter, no lag you can see)
}

-- The arrows from `from` to `to` (Vector3s; only X and Z count): the straight line from you to the target, every arrow
-- pointing exactly along it. They are fixed to the target (at Stop, Stop + Spacing, ... from it), so walking straight at
-- the target leaves them still on the floor: you walk over them; only the ones between Lead and Lead + Count x Spacing
-- ahead of you show, fading in at the far end of that window and out at your feet. Returns { { At = Vector3 (at from's height),
-- Alpha = 0..1 } } nearest first, and the unit direction (zero when there are none: you are there).
function TutorialRules.arrows(from, to, opts)
	local A = TutorialRules.Arrows
	opts = opts or {}
	local count, spacing, lead = opts.Count or A.Count, opts.Spacing or A.Spacing, opts.Lead or A.Lead
	local stop, hide, fade, fadeFar = opts.Stop or A.Stop, opts.Hide or A.Hide, opts.Fade or A.Fade, opts.FadeFar or A.FadeFar
	local flat = Vector3.new(to.X - from.X, 0, to.Z - from.Z)
	local length = flat.Magnitude
	if length <= hide or length < 1e-6 then return {}, Vector3.zero end
	local dir = flat / length
	local far = lead + count * spacing -- (the window's far end, studs ahead of you)
	local out = {}
	-- the arrow k sits Stop + k x Spacing short of the target, i.e. at s = length - Stop - k x Spacing ahead of you
	local kMin = math.max(0, math.ceil((length - stop - far) / spacing - 1e-9))
	for k = kMin, kMin + count + 1 do
		local s = length - stop - k * spacing
		if s < lead - 1e-9 then break end
		if s <= far + 1e-9 then
			local alpha = math.min(1, (s - lead) / fade, (far - s) / fadeFar)
			alpha = math.clamp(alpha, 0, 1)
			if alpha > 0.02 then
				table.insert(out, { At = Vector3.new(from.X + dir.X * s, from.Y, from.Z + dir.Z * s), Alpha = alpha, Ahead = s })
			end
		end
	end
	table.sort(out, function(p, q) return p.Ahead < q.Ahead end)
	return out, dir
end

-- Where the arrows aim for Stage 1's gate: its opening's middle, or, while the straight line to it would cross the hall's
-- wall beside the doorway it is seen through, the doorway's middle first (one straight leg, then the next, from
-- TutorialRules.Arrows.Hide + 2 studs before the doorway on, so the arrows never go out between the legs). All in the
-- map's frame (X across, Z along; the gate's line at gateZ, the doorway at doorZ with half-width doorHalf).
function TutorialRules.gateAim(you, gateX, gateZ, doorZ, doorHalf)
	if type(doorZ) ~= 'number' or type(doorHalf) ~= 'number' or you.Z <= doorZ + 0.5 then
		return Vector3.new(gateX, 0, gateZ)
	end
	if Vector3.new(you.X - gateX, 0, you.Z - doorZ).Magnitude <= TutorialRules.Arrows.Hide + 2 then
		return Vector3.new(gateX, 0, gateZ)
	end
	local dz = gateZ - you.Z
	local at = math.abs(dz) > 1e-6 and (doorZ - you.Z) / dz or 0
	local x = you.X + (gateX - you.X) * at
	if math.abs(x - gateX) <= doorHalf - 2.5 then return Vector3.new(gateX, 0, gateZ) end
	return Vector3.new(gateX, 0, doorZ)
end

-- One straight leg at a time: the arrows point at the first of `candidates` (points, best first: the target, then a
-- waypoint such as the lobby's spawn, the hub every walk of the plaza goes through) that you can walk to in a straight
-- line (clear(point) -> true when nothing solid stands between you and it). A waypoint only counts while the target is
-- more than Near studs away (closer, you just walk round a post), it is not yet reached (within `reached` studs) and the
-- way through it is at most Detour times the straight one; the caller leaves out a waypoint already passed. If nothing
-- is clear, the target. `current`: the leg chosen last time, kept while the target is still not in a straight line's
-- reach, so the arrows do not flick between legs.
TutorialRules.Legs = { Near = 14, Detour = 1.8 }
function TutorialRules.pickLeg(you, candidates, clear, current, reached)
	local r = reached or (TutorialRules.Arrows.Hide + 2)
	local function dist(a, b) return Vector3.new(a.X - b.X, 0, a.Z - b.Z).Magnitude end
	local target = candidates[1]
	if not target then return nil end
	if clear(target) then return target end
	local dt = dist(you, target)
	local L = TutorialRules.Legs
	local function usable(c) return dt > L.Near and dist(you, c) > r and dist(you, c) + dist(c, target) <= L.Detour * dt end
	if current and current ~= target and table.find(candidates, current) and usable(current) and clear(current) then return current end
	for i = 2, #candidates do
		local c = candidates[i]
		if usable(c) and clear(c) then return c end
	end
	return target
end

return TutorialRules
