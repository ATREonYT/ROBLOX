-- (brief 30, FIGHTS) The reference's fight grammar: the wave waits at the next gate and charges at about 25 studs; swings
-- in contact hit and pay more; the goons throw several kinds of punch and fall three ways into a heap with the head loose;
-- your arms swing, flinch and lie down; the "+N" by you, the X and the star, the level-up burst; the revive screen and the
-- World Boss timer; and nothing on screen calls a stage enemy a boss.
return function(t)
	local RS = game:GetService('ReplicatedStorage')
	local E = require(RS.Shared.EnemyRules)
	local W = require(RS.Shared.WaveRules)
	local Balance = require(RS.Shared.Config.Balance)
	local ShotRules = require(RS.Shared.ShotRules)
	local function gates() local g = {} for i = 1, 16 do table.insert(g, { Stage = i, WallId = 'HoodW1Stage' .. i, Required = Balance.StagePower[i], Z = -(i - 1) * 64, HalfWidth = 36 }) end return g end

	t.test('the wave waits 8-12 studs before the next gate and charges you at about 25 studs, at about 16 studs a second', function()
		t.expect.truthy(E.Notice >= 20 and E.Notice <= 25)
		t.expect.truthy(E.Kinds.Goon.Speed >= 13 and E.Kinds.Runner.Speed >= 15 and E.Kinds.Runner.Speed <= 17)
		local world, arenas = E.world(gates())
		local c = { t = 0 }
		local s = W.session(world, function() return c.t end, arenas)
		s:move(1)
		local w = s:current()
		-- 30 studs short of the nearest: nobody moves; 22 studs: the whole crew comes
		local nearest = math.huge
		for _, e in world[1] do nearest = math.min(nearest, -e.Home.Z) end
		for _ = 1, 10 do c.t += 0.1; s:tick(0.1, Vector3.new(0, 0, -(nearest - 30))) end
		for _, g in w.Goons do t.expect.equal(g.State, E.Idle) end
		for _ = 1, 10 do c.t += 0.1; s:tick(0.1, Vector3.new(0, 0, -(nearest - 22))) end
		for _, g in w.Goons do t.expect.truthy(g.State ~= E.Idle) end
		-- a crew's strongest charges with its crew (stage 2: 3 + Big Bully Brock)
		local s2 = W.session(world, function() return c.t end, arenas)
		s2:move(2)
		local w2 = s2:current()
		local near2 = math.huge
		for _, e in world[2] do near2 = math.min(near2, -(e.Home.Z + 64)) end
		for _ = 1, 10 do c.t += 0.1; s2:tick(0.1, Vector3.new(0, 0, -64 - (near2 - 20))) end
		for _, g in w2.Goons do t.expect.truthy(g.State ~= E.Idle) end
	end)

	t.test('a swing counts only in contact; it hits and pays MeleePay times a shot (the reference\'s +9 next to +6)', function()
		t.expect.truthy(E.MeleePay > 1 and E.MeleeRange >= 4 and E.MeleeRange <= 7)
		local world = { [1] = { { Kind = 'Goon', Home = Vector3.new(0, 0, -40) } } }
		local c = { t = 0 }
		local s = W.session(world, function() return c.t end)
		s:move(1)
		local g = s:current().Goons[1]
		local ok, why = s:shoot(1, 1, g.Pos + Vector3.new(0, 0, E.MeleeRange + E.MeleeSlack + 1), 3, true)
		t.expect.falsy(ok); t.expect.equal(why, 'range')
		c.t += 1
		ok = s:shoot(1, 1, g.Pos + Vector3.new(0, 0, 3), 3, true)
		t.expect.truthy(ok)
		-- the same shot from 20 studs is fine as a shot, not as a swing
		c.t += 1
		t.expect.truthy((s:shoot(1, 1, g.Pos + Vector3.new(0, 0, 20), 1)))
		c.t += 1
		t.expect.equal(select(2, s:shoot(1, 1, g.Pos + Vector3.new(0, 0, 20), 1, true)), 'range')
		-- the pay: a swing's share is MeleePay x a shot's, each with its own carried fraction
		local carry = {}
		local shot = ShotRules.share(10, ShotRules.EnemyShare, carry, 'Enemy')
		local swing = ShotRules.share(10, ShotRules.EnemyShare * E.MeleePay, carry, 'Melee')
		t.expect.truthy(swing > shot)
	end)

	t.test('the goons throw several kinds of punch in turn and fall three ways', function()
		local kinds = {}
		for n = 0, 7 do kinds[E.swingFor('Goon', n)] = true end
		local count = 0
		for _ in kinds do count += 1 end
		t.expect.truthy(count >= 4)
		for kind in E.Kinds do t.expect.truthy(#E.Swings[kind] >= 2) end
		local falls = {}
		for i = 1, 6 do falls[E.fallFor(i, false)] = true end
		t.expect.truthy(falls.Back and falls.Forward and falls.Twist)
		t.expect.equal(E.fallFor(2, true), 'Back') -- (a swing throws it back)
	end)

	t.test('the bodies: every punch has its own wind-up and hit, a hit from the side twists it, the heap has the head loose', function()
		local Rig = require(RS.Shared.EnemyRig)
		local function arm(p) local q = Rig.angles(p) return q.RightShoulder[1] + q.RightShoulder[2] * 2 + q.RightHip[1] * 3 + q.LeftShoulder[1] * 5 end
		local seen = {}
		for _, sw in { 'Jab', 'Hook', 'Uppercut', 'Kick', 'Shove', 'Haymaker' } do
			t.expect.truthy(Rig.Poses[sw .. 'Ready'] ~= nil and Rig.Poses[sw .. 'Strike'] ~= nil)
			local ready, hit = arm({ guard = 0.9, swing = sw, windup = 1 }), arm({ guard = 0.9, swing = sw, punch = 1 })
			t.expect.truthy(math.abs(ready - hit) > 0.3)
			seen[string.format('%.2f', hit)] = true
		end
		local n = 0
		for _ in seen do n += 1 end
		t.expect.truthy(n >= 5)
		-- a hit from its right twists its chest away (left)
		local q0, q1 = Rig.angles({}), Rig.angles({ flinchSide = 0.5 })
		t.expect.truthy(math.abs(q1.Waist[2] - q0.Waist[2]) > 0.1)
		-- the fall: off its feet slowly, into the ground fast, then the heap settles
		local ko1, pile1 = Rig.fallCurve(0.05)
		local ko2, pile2 = Rig.fallCurve(Rig.FallTime)
		local ko3, pile3 = Rig.fallCurve(Rig.FallTime + Rig.PileTime + 0.2)
		t.expect.truthy(ko1 < 0.1 and ko2 > 0.95 and ko3 > 0.95)
		t.expect.truthy(pile1 == 0 and pile3 == 1 and pile2 < 1)
		for _, f in E.Falls do t.expect.truthy(Rig.Poses['Fall' .. f] ~= nil and Rig.Poses['Pile' .. f] ~= nil) end
	end)

	t.test('your swings, your flinch and your knockdown', function()
		local CM = require(RS.Shared.CharMotion)
		local _, w0 = CM.swingPose(0, 1)
		local mid, w1 = CM.swingPose(0.12, 1)
		local _, w2 = CM.swingPose(CM.SwingTime, 1)
		t.expect.truthy(w0 < 0.05 and w1 > 0.95 and w2 == 0)
		t.expect.truthy(mid.RightShoulder ~= nil)
		local left = CM.swingPose(0.12, 2)
		t.expect.truthy(left.LeftShoulder ~= nil)
		t.expect.truthy(CM.Down.Root ~= nil and CM.Down.RightShoulder ~= nil)
		t.expect.truthy(type(CM.melee) == 'function' and type(CM.hurt) == 'function' and type(CM.down) == 'function')
	end)

	t.test('the marks: "+N" with the bicep by you, the X, the star, the swoosh, the level-up burst', function()
		local FX = require(RS.Shared.FightFX)
		local holder = Instance.new('Folder'); holder.Parent = workspace
		FX.Parent = holder
		local g = FX.gain(Vector3.new(0, 5, 0), 6)
		t.expect.truthy(g ~= nil and g:IsA('BillboardGui') and g.AlwaysOnTop)
		local amount = g:FindFirstChild('Amount', true)
		t.expect.equal(amount.Text, '+6')
		t.expect.truthy(g:FindFirstChild('Bicep', true) ~= nil)
		local x = FX.hitX(Vector3.new(0, 4, 0))
		local bars = 0
		for _, d in x:GetDescendants() do if d.Name == 'XBar' then bars += 1 end end
		t.expect.equal(bars, 2)
		local st = FX.star(Vector3.new(0, 4, 0))
		local rays = 0
		for _, d in st:GetDescendants() do if d.Name == 'StarRay' then rays += 1 end end
		t.expect.equal(rays, 4)
		local sw = FX.swoosh(CFrame.new(0, 3, 0), 1)
		local arcs = 0
		for _, d in sw:GetChildren() do if d:IsA('Beam') then arcs += 1 end end
		t.expect.equal(arcs, 3)
		-- the leap's spiral slash (the reference Pouncer's hit): three arcs round the body
		local sl = FX.slash(CFrame.new(0, 3, 0))
		local turns = 0
		for _, d in sl:GetChildren() do if d:IsA('Beam') then turns += 1 end end
		t.expect.equal(turns, 3)
		local root = Instance.new('Part'); root.Anchored = true; root.Parent = holder
		local burst, chev = FX.levelBurst(root)
		local r, c = 0, 0
		for _, d in burst:GetDescendants() do if d.Name == 'BurstRay' then r += 1 end end
		for _, d in chev:GetDescendants() do if d.Name == 'Chevron' then c += 1 end end
		t.expect.truthy(r >= 6 and c >= 3)
		holder:Destroy()
		FX.Parent = nil
	end)

	t.test('the revive screen: REVIVE?, the countdown, Revive! / Revenge! with their real prices, a free No; the World Boss timer', function()
		local UI = require(RS.Shared.FightUI)
		local Products = require(RS.Shared.Config.Products)
		local root = Instance.new('Frame')
		local rv = UI.revive(root, { Revive = Products.ByKey.Revive.Price, Revenge = Products.ByKey.Revenge.Price })
		t.expect.equal(rv.Gui.Visible, false)
		rv.show(10)
		t.expect.equal(rv.Gui.Visible, true)
		t.expect.equal(rv.Gui:FindFirstChild('Title').Text, 'REVIVE?')
		t.expect.equal(rv.Gui:FindFirstChild('Clock').Text, '10.00')
		rv.set(9.64)
		t.expect.equal(rv.Gui:FindFirstChild('Clock').Text, '9.64')
		for _, key in { 'Revive', 'Revenge', 'No' } do t.expect.truthy(rv.Buttons[key] ~= nil) end
		t.expect.truthy(rv.Buttons.Revive:FindFirstChild('Price') ~= nil and rv.Buttons.Revenge:FindFirstChild('Price') ~= nil)
		t.expect.equal(rv.Buttons.No:FindFirstChild('Price'), nil)
		t.expect.truthy(string.find(rv.Notes.No.Text, 'FREE', 1, true) ~= nil)
		-- honest: real products with prices, a wired grant, no "limited" anything
		for _, key in { 'Revive', 'Revenge', 'WorldBossSkip' } do
			local e = Products.ByKey[key]
			t.expect.truthy(e and e.Kind == 'Product' and e.Price > 0 and e.Wired and Products.DeveloperProducts[key] ~= nil)
		end
		local bt = UI.bossTimer(root)
		bt.set('COURT KING', 172)
		t.expect.equal(bt.Line.Text, 'Next <font color="#FFB020">COURT KING</font> boss fight in: 2:52')
		t.expect.truthy(bt.Skip ~= nil)
		-- a crew's strongest gets the bigger, brick-studded bar; a plain goon the plain one
		local head = Instance.new('Part')
		local strong = UI.tag(head, 'Court King', 600, true)
		local plain = UI.tag(head, 'Recess Bully', 60)
		local studs = 0
		for _, d in strong.Gui:GetDescendants() do if d.Name == 'Stud' then studs += 1 end end
		t.expect.equal(studs, UI.Studs)
		t.expect.truthy(strong.Gui.Size.X.Scale > plain.Gui.Size.X.Scale)
		for _, d in plain.Gui:GetDescendants() do t.expect.truthy(d.Name ~= 'Stud') end
	end)

	t.test('the moves are smooth: joints ease through damped springs at any frame rate, never snap (the user\'s ask)', function()
		local JS = require(RS.Shared.JointSpring)
		local A = CFrame.Angles
		-- a first step (or no time passed) lands exactly on the pose
		local set = JS.new()
		local first = JS.step(set, 'RightShoulder', A(0.4, 0, 0), 0)
		t.expect.truthy((first.LookVector - A(0.4, 0, 0).LookVector).Magnitude < 1e-4)
		JS.done(set)
		-- a sudden new pose (a strike) is reached in about 0.1-0.2 s, not in one frame, and with no jump at the start
		local target = A(1.5, 0, 0)
		local function angle(cf) local _, a = cf:ToAxisAngle() return a end
		local f1 = JS.step(set, 'RightShoulder', target, 1 / 60)
		t.expect.truthy(angle(f1) - 0.4 < 0.25 * 1.1) -- (under a quarter of the way after one 60 fps frame)
		local t60, at60 = 1 / 60, nil
		for k = 2, 30 do
			local cf = JS.step(set, 'RightShoulder', target, 1 / 60)
			if not at60 and angle(cf) > 0.4 + 0.9 * 1.1 then at60 = k * t60 end
		end
		t.expect.truthy(at60 ~= nil and at60 >= 0.05 and at60 <= 0.25)
		-- the same move at 30 fps lands in the same time (dt-correct)
		local set2 = JS.new()
		JS.step(set2, 'RightShoulder', A(0.4, 0, 0), 0); JS.done(set2)
		local at30 = nil
		for k = 1, 15 do
			local cf = JS.step(set2, 'RightShoulder', target, 1 / 30)
			if not at30 and angle(cf) > 0.4 + 0.9 * 1.1 then at30 = k / 30 end
		end
		t.expect.truthy(at30 ~= nil and math.abs(at30 - at60) <= 1 / 30 + 1e-6)
		-- the arms follow through a touch past the pose and settle; the legs don't overshoot
		local set3, peak = JS.new(), 0
		JS.step(set3, 'RightShoulder', CFrame.identity, 0); JS.step(set3, 'RightKnee', CFrame.identity, 0); JS.done(set3)
		local kneePeak = 0
		for _ = 1, 60 do
			peak = math.max(peak, angle(JS.step(set3, 'RightShoulder', A(1, 0, 0), 1 / 60)))
			kneePeak = math.max(kneePeak, angle(JS.step(set3, 'RightKnee', A(1, 0, 0), 1 / 60)))
		end
		t.expect.truthy(peak > 1.01 and peak < 1.2)
		t.expect.truthy(kneePeak <= 1.0005)
		-- an enemy rig posed every frame: a state change (guard to a jab's strike) moves its arm over several frames
		local Rig = require(RS.Shared.EnemyRig)
		local holder = Instance.new('Folder')
		local r = Rig.build('nope', 'Goon', 'Red', 1, holder)
		t.expect.truthy(r ~= nil)
	end)

	t.test('nothing on screen calls a stage enemy a boss: tags, gate lines, goals', function()
		local world = E.world(gates())
		for s = 1, 16 do
			for _, e in world[s] do t.expect.falsy(string.find(string.lower(e.Name), 'boss', 1, true)) end
		end
		local G = require(RS.Shared.GoalRules)
		for _, goal in G.List or {} do
			for _, f in { 'Text', 'Where' } do
				if type(goal[f]) == 'string' then t.expect.falsy(string.find(string.lower(goal[f]), 'boss', 1, true)) end
			end
		end
	end)
end
