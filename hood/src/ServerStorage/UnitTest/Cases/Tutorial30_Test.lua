-- Brief 30, TUTORIAL: the quick tutorial's rules (Shared/TutorialRules): the step machine (the world steps, the one boxed
-- lesson), the hint's text, the box's geometry (padding, corners, the GUI inset, the resting rect, the dim's hole) and
-- its lock-on timing, and the straight white arrows.
return function(t)
	local RS = game:GetService('ReplicatedStorage')
	local Tut = require(RS.Shared.TutorialRules)
	local O = require(RS.Shared.OnboardingRules)
	local V2 = Vector2.new
	local E = 2e-3 -- (Vector2 and Vector3 hold 32-bit floats, as in Roblox)
	local function near2(a, b, e) t.expect.near(a.X, b.X, math.max(e or 0, E)); t.expect.near(a.Y, b.Y, math.max(e or 0, E)) end

	t.test('the world steps: the pure basics, one per onboarding step, then nothing', function()
		for _, name in Tut.Order do
			local s = Tut.step(name)
			t.expect.truthy(s ~= nil); t.expect.truthy(type(s.Text) == 'string' and s.Text ~= '')
			t.expect.truthy(O.Index[name] ~= nil) -- (every one is a step the server reports)
			local _, n = Tut.plain(s.Text)
			t.expect.truthy(n <= 32) -- (one short line: typed in a second at most)
		end
		for i = 2, #Tut.Order do t.expect.truthy(O.Index[Tut.Order[i - 1]] < O.Index[Tut.Order[i]]) end
		for _, name in { 'Gun', 'Run', 'Done', 'Nope' } do t.expect.equal(Tut.step(name), nil) end
		t.expect.equal(Tut.step(nil), nil); t.expect.equal(Tut.step(5), nil)
		-- the hint and the arrows' target for where you are
		local text, target = Tut.worldHint('Train', false, false)
		t.expect.equal(text, 'Walk into <BAY 1>!'); t.expect.equal(target, 'Lane')
		text, target = Tut.worldHint('Train', true, false) -- (in BAY 1: it shoots by itself, no arrows)
		t.expect.equal(text, Tut.Steps.Train.InLane); t.expect.equal(target, nil)
		t.expect.equal(select(2, Tut.worldHint('Door')), 'Gate'); t.expect.equal(select(2, Tut.worldHint('Cash')), 'Pad'); t.expect.equal(select(2, Tut.worldHint('Gift')), 'Gift')
		text, target = Tut.worldHint('Fight', false, true)
		t.expect.equal(text, Tut.Steps.Fight.Touch); t.expect.equal(target, nil) -- (a fight: no arrows)
		t.expect.equal(Tut.worldHint('Fight', false, false), Tut.Steps.Fight.Text)
		t.expect.equal(Tut.worldHint('Done'), nil)
	end)

	t.test('the one boxed lesson: the first rebirth, two clicks, each waiting for you, never during anything else', function()
		local base = { Rebirths = 0, RebirthReady = true, WorldStep = 'Done', Window = '' }
		local function with(over) local s = table.clone(base); for k, v in over do s[k] = v end; return s end
		t.expect.equal(Tut.lessonStep(base), 'Open')
		t.expect.equal(Tut.Lesson.Open.Box, 'Hud'); t.expect.equal(Tut.Lesson.Press.Box, 'Window'); t.expect.equal(Tut.Lesson.After.Box, nil)
		t.expect.equal(Tut.Lesson.Open.Badge, '1'); t.expect.equal(Tut.Lesson.Press.Badge, nil) -- (the badge on the first button only)
		t.expect.equal(Tut.lessonStep(with({ Window = 'Rebirth' })), 'Press')
		t.expect.equal(Tut.lessonStep(with({ Window = 'Store' })), nil) -- (another window: it waits)
		t.expect.equal(Tut.lessonStep(with({ RebirthReady = false })), nil)
		t.expect.equal(Tut.lessonStep(with({ Busy = true })), nil)
		t.expect.equal(Tut.lessonStep(with({ GaveUp = true })), nil)
		t.expect.equal(Tut.lessonStep(with({ WorldStep = 'Train' })), nil) -- (the world tutorial goes first)
		t.expect.equal(Tut.lessonStep(with({ WorldStep = 'Run' })), 'Open')
		t.expect.equal(Tut.lessonStep(with({ Rebirths = 1, AfterLeft = 2 })), 'After')
		t.expect.equal(Tut.lessonStep(with({ Rebirths = 1, AfterLeft = 0 })), nil) -- (then it is over for good)
		t.expect.equal(Tut.lessonStep(with({ Rebirths = 3, RebirthReady = true })), nil)
		t.expect.equal(Tut.lessonStep(nil), nil); t.expect.equal(Tut.lessonStep('x'), nil)
		t.expect.equal(Tut.plain(Tut.Lesson.After.Text), 'Now go train again!')
	end)

	t.test('the hint: the key word yellow, typed at 32 characters a second, one line', function()
		t.expect.equal(Tut.rich('Walk into <BAY 1>!'), 'Walk into <font color="#FFD21F">BAY 1</font>!')
		t.expect.equal(Tut.rich('Go <gate>!', 5, '#FFD21F'), 'Go <font color="#FFD21F">ga</font>')
		t.expect.equal(Tut.rich('Go <gate>!', 0), '')
		t.expect.equal(Tut.typed(0.5), 16) -- ("Click ABILITIES!": 16 characters in about half a second)
		t.expect.equal(Tut.typed(1), 32); t.expect.equal(Tut.typed(-3), 0); t.expect.equal(Tut.typed(0 / 0), 0); t.expect.equal(Tut.typed('1'), 0)
		local plain, n = Tut.plain('Click <ABILITIES>!'); t.expect.equal(plain, 'Click ABILITIES!'); t.expect.equal(n, 16)
		local ps = Tut.pieces('a <b> c'); t.expect.equal(#ps, 3); t.expect.truthy(ps[2].Key); t.expect.falsy(ps[1].Key)
		-- one line: the size shrinks until the words fit the box
		local fit = function(s, size) return #s * size * 0.6 end
		t.expect.equal(Tut.hintSize('Go!', fit), Tut.Hint.TextSize)
		local long = string.rep('W', 40)
		local size = Tut.hintSize(long, fit)
		t.expect.truthy(size < Tut.Hint.TextSize and size >= Tut.Hint.MinText)
		-- the reference's share of the screen on a 1280 x 720 screen (UIKit's scale is 1 there for a full-screen GUI)
		t.expect.near(Tut.Hint.W / 1280, 0.319, 0.005); t.expect.near(Tut.Hint.H / 720, 0.131, 0.005); t.expect.near(Tut.Hint.Y, 0.632, 1e-9)
	end)

	t.test('the box: pinpoint, one even whole-pixel gap of about 7 %, the target\'s own corners plus the gap', function()
		-- a 71 px HUD tile with a 5 px corner (8 px outer with its 3 px stroke): a 5 px gap all round, radius 8 + 5
		local p, s, r, pad = Tut.boxRect(V2(85.4, 74.6), V2(71, 71), 720, nil, 8)
		t.expect.equal(pad, 5)
		near2(p, V2(85 - 5, 75 - 5)); near2(s, V2(71 + 10, 71 + 10))
		t.expect.equal(r, 13)
		-- even: the same gap on all four sides, whole pixels
		local x0, y0 = math.floor(85.4 + 0.5), math.floor(74.6 + 0.5)
		t.expect.equal(x0 - p.X, pad); t.expect.equal(y0 - p.Y, pad)
		t.expect.equal((p.X + s.X) - math.floor(85.4 + 71 + 0.5), pad); t.expect.equal((p.Y + s.Y) - math.floor(74.6 + 71 + 0.5), pad)
		t.expect.equal(p.X, math.floor(p.X)); t.expect.equal(s.Y, math.floor(s.Y))
		-- 6-8 % of the target: a 300 x 80 button gets 6 px; a small one keeps 4; a huge one a modest gap
		t.expect.equal(Tut.padFor(V2(300, 80), 720), 6)
		t.expect.equal(Tut.padFor(V2(30, 30), 720), Tut.Box.PadMin)
		t.expect.equal(Tut.padFor(V2(900, 900), 720), math.floor(720 * Tut.Box.PadMax + 0.5))
		-- a tight gutter shrinks the gap evenly, never under the minimum
		t.expect.equal(Tut.padFor(V2(71, 71), 720, 3.6), Tut.Box.PadMin)
		t.expect.equal(Tut.padFor(V2(200, 200), 720, 10.7), 10)
		-- a square target: the box's corners are the gap's own arc; never rounder than half the box
		local _, s2, r2 = Tut.boxRect(V2(0, 0), V2(300, 80), 720, nil, 0); t.expect.equal(r2, 6); t.expect.equal(s2.Y, 92)
		local _, _, r3 = Tut.boxRect(V2(0, 0), V2(20, 20), 720, nil, 50); t.expect.equal(r3, 14)
		t.expect.equal(Tut.lineFor(582), 3); t.expect.equal(Tut.lineFor(720), 4); t.expect.equal(Tut.lineFor(390), 2); t.expect.equal(Tut.lineFor(2160), 6)
		t.expect.equal(Tut.lineFor(nil), 4)
		-- what the target draws: the union of its parts, the words placed by their alignment, clipping
		local up, us = Tut.union({ { V2(10, 10), V2(20, 20) }, { V2(25, 0), V2(10, 12) } })
		near2(up, V2(10, 0)); near2(us, V2(25, 30))
		t.expect.equal(Tut.union({}), nil)
		local tp = Tut.textRect(V2(0, 0), V2(100, 40), V2(60, 20), nil, nil); near2(tp, V2(20, 10))
		tp = Tut.textRect(V2(0, 0), V2(100, 40), V2(60, 20), 'Left', 'Bottom'); near2(tp, V2(0, 20))
		tp = Tut.textRect(V2(0, 0), V2(100, 40), V2(60, 20), 'Right', 'Top'); near2(tp, V2(40, 0))
		local cp, cs = Tut.clip(V2(0, 0), V2(50, 50), V2(20, 10), V2(100, 100)); near2(cp, V2(20, 10)); near2(cs, V2(30, 40))
		t.expect.equal(Tut.clip(V2(0, 0), V2(5, 5), V2(10, 10), V2(5, 5)), nil)
		-- scaled about its centre
		local sp, ss = Tut.scaled(V2(10, 20), V2(100, 50), 1.45)
		near2(sp + ss / 2, V2(60, 45)); near2(ss, V2(145, 72.5))
		-- the badge sits on the target's top-right corner, 28 % of it
		local c, d = Tut.badgeFor(V2(100, 100), V2(60, 60))
		t.expect.near(d, 60 * 0.28, E); t.expect.truthy(math.abs(c.X - 160) <= 2 and math.abs(c.Y - 100) <= 2)
		t.expect.equal(select(2, Tut.badgeFor(V2(0, 0), V2(20, 20))), Tut.Box.BadgeMin)
	end)

	t.test('the box locks on: 1.45x and faint, to 1.0x solid in 0.13 s, the dim in 0.2 s, then perfectly still', function()
		local s0, a0, d0 = Tut.lockOn(0)
		t.expect.near(s0, Tut.Box.LockScale, 1e-9); t.expect.near(a0, Tut.Box.LockAlpha, 1e-9); t.expect.near(d0, 0, 1e-9)
		local sm = Tut.lockOn(0.065) -- (the reference's middle frame: about 1.1x)
		t.expect.truthy(sm > 1.05 and sm < 1.16)
		local s1, a1, d1 = Tut.lockOn(Tut.Box.LockTime)
		t.expect.near(s1, 1, 1e-9); t.expect.near(a1, 1, 1e-9); t.expect.truthy(d1 > 0.8 and d1 < 1)
		local s2, a2, d2 = Tut.lockOn(Tut.Box.MaskTime)
		t.expect.near(s2, 1, 1e-9); t.expect.near(a2, 1, 1e-9); t.expect.near(d2, 1, 1e-9)
		for _, late in { 0.5, 3, 600 } do
			local s, a, d = Tut.lockOn(late)
			t.expect.equal(s, 1); t.expect.equal(a, 1); t.expect.equal(d, 1) -- (no breathing, no drift)
		end
		local last = math.huge
		for i = 0, 13 do local s = Tut.lockOn(i / 100); t.expect.truthy(s <= last + 1e-12); last = s end -- (only ever shrinks)
		local sn = Tut.lockOn(0 / 0); t.expect.equal(sn, 1)
		t.expect.truthy(Tut.Box.LockTime <= 0.15 and Tut.Box.MaskTime <= 0.25)
	end)

	t.test('the box finds the target exactly: the GUI inset, the resting rect, holding still', function()
		-- a button 100 px from the left of a ScreenGui that sits under a 58 px top bar, drawn in one that ignores it
		near2(Tut.toOverlay(V2(100, 50), V2(0, 58), Vector2.zero), V2(100, 108))
		near2(Tut.toOverlay(V2(100, 50), V2(0, 58), V2(0, 58)), V2(100, 50)) -- (same inset: no change)
		near2(Tut.toOverlay(V2(100, 50), V2(44, 58), V2(0, 0)), V2(144, 108)) -- (a phone's notch too)
		-- a window springing open (0.8 about its centre) with the button inside: the rest rect is where it will settle
		local panel = { Pos = V2(120, 110), Size = V2(160, 80), Anchor = V2(0.5, 0.5), Scale = 0.8 }
		local button = { Pos = V2(160, 126), Size = V2(32, 16), Anchor = V2(0, 0), Scale = 1 }
		local p, s = Tut.restRect({ panel, button })
		near2(p, V2(150, 120)); near2(s, V2(40, 20))
		-- the mouse over the button (its own 1.05 pop about its anchor) moves nothing
		local hovered = { Pos = V2(200, 300), Size = V2(81 * 1.05, 81 * 1.05), Anchor = V2(0, 0), Scale = 1.05 }
		p, s = Tut.restRect({ hovered }); near2(p, V2(200, 300)); near2(s, V2(81, 81))
		local centred = { Pos = V2(100 - 0.03 * 50, 100 - 0.03 * 50), Size = V2(103, 103), Anchor = V2(0.5, 0.5), Scale = 1.03 }
		p, s = Tut.restRect({ centred }); near2(p, V2(100, 100)); near2(s, V2(100, 100))
		-- both at once: a hovered button in a springing window
		local P = V2(200, 150)
		local function pop(x, about, k) return about + (x - about) * k end
		local restB, sizeB = V2(150, 120), V2(40, 20)
		local hoverB = 1.05 -- (about the button's top-left anchor)
		local b1 = pop(restB, P, 0.8) -- (the panel's spring moves its anchor and its size)
		local both = { Pos = b1, Size = sizeB * 0.8 * hoverB, Anchor = V2(0, 0), Scale = hoverB }
		p, s = Tut.restRect({ panel, both }); near2(p, restB); near2(s, sizeB)
		t.expect.equal(Tut.restRect({}), nil)
		-- holding still
		t.expect.truthy(Tut.same(V2(1, 1), V2(10, 10), V2(1.5, 1), V2(10, 10.5)))
		t.expect.falsy(Tut.same(V2(1, 1), V2(10, 10), V2(3, 1), V2(10, 10)))
		t.expect.falsy(Tut.same(nil, V2(1, 1), V2(1, 1), V2(1, 1)))
		t.expect.truthy(Tut.same(V2(1, 1), V2(10, 10), V2(4, 1), V2(10, 10), 4))
	end)

	t.test('the dim: a mask with a rounded hole, covering everything else exactly once', function()
		local screen = V2(1280, 662)
		local hp, hs = V2(20, 150), V2(100, 110)
		local rects = Tut.maskRects(hp, hs, screen, 1000)
		t.expect.equal(#rects, 4)
		local area = 0
		for _, r in rects do
			area += r[2].X * r[2].Y
			-- none reaches into the hole
			local ox = math.max(0, math.min(r[1].X + r[2].X, hp.X + hs.X) - math.max(r[1].X, hp.X))
			local oy = math.max(0, math.min(r[1].Y + r[2].Y, hp.Y + hs.Y) - math.max(r[1].Y, hp.Y))
			t.expect.equal(ox * oy, 0)
		end
		t.expect.near(area + hs.X * hs.Y, (screen.X + 2000) * (screen.Y + 2000), 1e-3) -- (everything else, no overlaps)
		-- the rounded corners: the part of each r x r corner square outside the quarter circle, row by row
		local rows = Tut.cornerRows(10)
		t.expect.equal(#rows, 10)
		t.expect.near(rows[1], 10 - math.sqrt(100 - 9.5 * 9.5), 1e-9)
		for i = 2, #rows do t.expect.truthy(rows[i] <= rows[i - 1]) end
		t.expect.truthy(rows[10] < 0.02)
		t.expect.equal(#Tut.cornerRows(0), 0); t.expect.equal(#Tut.cornerRows(0 / 0), 0)
		t.expect.near(Tut.Box.Dim, 0.41, 1e-9) -- (59 % darker: the reference's world 127 -> 55, its Skins 83 -> 32)
	end)

	t.test('the white arrows: a straight line exactly at the target, fixed to it, none when you are there', function()
		local A = Tut.Arrows
		local from, to = Vector3.new(0, 5, 0), Vector3.new(30, 9, -40)
		local list, dir = Tut.arrows(from, to)
		t.expect.truthy(#list >= A.Count - 1 and #list <= A.Count + 1)
		local flat = Vector3.new(to.X, 0, to.Z).Unit
		t.expect.near(dir.X, flat.X, E); t.expect.near(dir.Z, flat.Z, E); t.expect.near(dir.Y, 0, E)
		for i, a in list do
			local p = a.At
			t.expect.near(p.Y, 5, E) -- (at your feet's height: the client lays it on the floor)
			t.expect.near(p.X * flat.Z - p.Z * flat.X, 0, 5e-3) -- (on the line: no curve)
			local ahead = Vector3.new(p.X, 0, p.Z).Magnitude
			t.expect.truthy(ahead >= A.Lead - E and ahead <= A.Lead + A.Count * A.Spacing + E)
			t.expect.truthy(Vector3.new(to.X - p.X, 0, to.Z - p.Z).Magnitude >= A.Stop - E)
			t.expect.truthy(a.Alpha > 0 and a.Alpha <= 1)
			if i > 1 then t.expect.near((p - list[i - 1].At).Magnitude, A.Spacing, E) end
		end
		-- fixed to the target: walk 2 studs straight at it and the arrows that are still ahead have not moved
		local step = from + flat * 2
		local list2 = Tut.arrows(step, to)
		local same = 0
		for _, a in list2 do
			for _, b in list do
				if (Vector3.new(a.At.X, 0, a.At.Z) - Vector3.new(b.At.X, 0, b.At.Z)).Magnitude < 0.01 then same += 1 end
			end
		end
		t.expect.truthy(same >= A.Count - 2)
		-- the last arrow before the target stops Stop short of it, and it is solid
		local close = Tut.arrows(Vector3.new(0, 0, 0), Vector3.new(0, 0, -12))
		t.expect.truthy(#close >= 1)
		local lastA = close[#close]
		t.expect.near(Vector3.new(lastA.At.X, 0, lastA.At.Z - -12).Magnitude, A.Stop, E)
		-- there: no arrows at all
		local none, zero = Tut.arrows(from, Vector3.new(3, 5, 4))
		t.expect.equal(#none, 0); t.expect.equal(zero.Magnitude, 0)
		local none2 = Tut.arrows(from, from); t.expect.equal(#none2, 0)
		-- they fade in at the far end of the window (no popping in)
		local far = Tut.arrows(Vector3.new(0, 0, 0), Vector3.new(0, 0, -200))
		t.expect.truthy(far[#far].Alpha < 1 or far[#far].Ahead <= A.Lead + A.Count * A.Spacing - A.Fade)
	end)

	t.test('one straight leg at a time: the target if you can walk straight to it, else the hub first, no flicking', function()
		local target, hub = Vector3.new(0, 0, 0), Vector3.new(0, 0, 55)
		local you = Vector3.new(-22, 0, 42)
		local open = function() return true end
		t.expect.equal(Tut.pickLeg(you, { target, hub }, open), target)
		local blocked = function(p) return p ~= target end -- (a lane's bench between you and the gate)
		t.expect.equal(Tut.pickLeg(you, { target, hub }, blocked), hub)
		t.expect.equal(Tut.pickLeg(you, { target, hub }, function() return false end), target) -- (nothing clear: the target)
		-- at the hub (within Hide + 2): go on to the target even if the line is not clear yet
		t.expect.equal(Tut.pickLeg(Vector3.new(1, 0, 50), { target, hub }, blocked, hub), target)
		-- on the way to the hub it stays the hub while the target is not in reach
		t.expect.equal(Tut.pickLeg(Vector3.new(-12, 0, 48), { target, hub }, blocked, hub), hub)
		-- the moment the target is in a straight line's reach: the target
		t.expect.equal(Tut.pickLeg(Vector3.new(-12, 0, 48), { target, hub }, open, hub), target)
		t.expect.equal(Tut.pickLeg(you, {}, open), nil)
		-- a waypoint behind you is never a leg (nearly at BAY 1, a lamp post in the line: walk on, never back to the hub)
		local bay = Vector3.new(-22.7, 0, 42.1)
		local nearBay = Vector3.new(-17, 0, 46)
		t.expect.equal(Tut.pickLeg(nearBay, { bay, hub }, function(p) return p ~= bay end), bay)
		t.expect.equal(Tut.pickLeg(nearBay, { bay, hub }, function(p) return p ~= bay end, hub), bay)
	end)

	t.test('Stage 1 gate: straight at its opening, via the hall doorway when the wall is in the way', function()
		-- the gate's line at z 0, the doorway 6.9 in front of it, 21.5 either side of the middle
		local aim = Tut.gateAim(Vector3.new(-10, 0, 40), 0, 0, 6.9, 21.5)
		t.expect.near(aim.Z, 0, E) -- (the line passes through the doorway: straight at the gate)
		aim = Tut.gateAim(Vector3.new(-80, 0, 9), 0, 0, 6.9, 21.5)
		t.expect.near(aim.Z, 6.9, E); t.expect.near(aim.X, 0, E) -- (it would cut the wall: the doorway's middle first)
		aim = Tut.gateAim(Vector3.new(-30, 0, 5), 0, 0, 6.9, 21.5)
		t.expect.near(aim.Z, 0, E) -- (through the doorway already)
		aim = Tut.gateAim(Vector3.new(-4, 0, 12), 0, 0, 6.9, 3)
		t.expect.near(aim.Z, 0, E) -- (at the doorway: the next leg, straight at the gate)
		aim = Tut.gateAim(Vector3.new(-80, 0, 9), 2, -64, nil, nil)
		t.expect.near(aim.X, 2, E); t.expect.near(aim.Z, -64, E) -- (no doorway: the gate)
	end)
end
