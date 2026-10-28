-- (Oct 28) The floating guide arrow's pure rules (Shared/GuideArrow): the eased bob and pulse, its growth with the
-- distance, its parts' layout, keeping clear of walls and ceilings, and the screen-edge pointer.
return function(t)
	local RS = game:GetService('ReplicatedStorage')
	local GA = require(RS.Shared.GuideArrow)
	local V = Vector3.new

	t.test('the arrow floats: a soft bob and a gentle pulse, none with ReducedMotion', function()
		local lo, hi, plo, phi = math.huge, -math.huge, math.huge, -math.huge
		for i = 0, 140 do
			local b, p = GA.motion(i / 100, false)
			lo, hi, plo, phi = math.min(lo, b), math.max(hi, b), math.min(plo, p), math.max(phi, p)
		end
		t.expect.near(hi, GA.Bob.Amp, 0.02); t.expect.near(lo, -GA.Bob.Amp, 0.02)
		t.expect.truthy(GA.Bob.Amp >= 0.3 and GA.Bob.Amp <= 0.8 and GA.Bob.Period >= 1 and GA.Bob.Period <= 2) -- (calm, not jittery)
		t.expect.truthy(phi - 1 <= 0.08 and 1 - plo <= 0.08 and phi > 1.03) -- (gentle: a few % either way)
		local b, p = GA.motion(0.37, true)
		t.expect.equal(b, 0); t.expect.equal(p, 1)
		local b2, p2 = GA.motion(0 / 0, false)
		t.expect.equal(b2, 0); t.expect.equal(p2, 1)
	end)

	t.test('it grows with the distance, so it reads across the hall', function()
		t.expect.equal(GA.scaleFor(0), GA.Grow.From); t.expect.equal(GA.scaleFor(GA.Grow.Near), GA.Grow.From)
		t.expect.equal(GA.scaleFor(500), GA.Grow.To)
		t.expect.truthy(GA.scaleFor(40) > 1 and GA.scaleFor(40) < GA.scaleFor(60))
		t.expect.equal(GA.scaleFor(nil), GA.Grow.From)
	end)

	t.test('the parts: the tip at the bottom, the ink plate behind and around the body, all scaled together', function()
		local L = GA.layout(1)
		for _, name in { 'ArrowShaft', 'ArrowHeadL', 'ArrowHeadR', 'ArrowCap', 'ArrowLip', 'ArrowShine', 'ArrowBackShaft', 'ArrowBackL', 'ArrowBackR' } do
			t.expect.truthy(L[name] ~= nil)
		end
		local S = GA.Size
		-- the head halves meet at the centre line, the tip at y = 0
		t.expect.near(L.ArrowHeadL.Pos.X + L.ArrowHeadL.Size.Z / 2, 0, 1e-6)
		t.expect.near(L.ArrowHeadL.Pos.Y - L.ArrowHeadL.Size.Y / 2, 0, 1e-6)
		-- the ink plate: behind the body, bigger than it (the outline shows all round), its tip under the body's
		t.expect.truthy(L.ArrowBackShaft.Pos.Z < -S.Depth / 2 + 1e-6)
		t.expect.truthy(L.ArrowBackShaft.Size.X > L.ArrowShaft.Size.X + 0.3 and L.ArrowBackL.Size.Z > L.ArrowHeadL.Size.Z)
		t.expect.truthy(L.ArrowBackL.Pos.Y - L.ArrowBackL.Size.Y / 2 < -0.3)
		-- chunky: as deep as a stud, the whole thing over 4 studs tall
		t.expect.truthy(S.Depth >= 0.8 and GA.height(1) >= 4)
		-- the shine sits on the front face
		t.expect.truthy(L.ArrowShine.Pos.Z > S.Depth / 2)
		local L2 = GA.layout(2)
		t.expect.near(L2.ArrowShaft.Pos.Y, 2 * L.ArrowShaft.Pos.Y, 1e-6); t.expect.near(L2.ArrowShaft.Size.X, 2 * L.ArrowShaft.Size.X, 1e-6)
	end)

	t.test('it keeps clear of ceilings and walls, and never sits on the floor', function()
		local at = V(10, 0, 10)
		-- nothing around: Up studs over the target
		local free = GA.clear(at, 1, V(0, 0, 1), function() return nil end)
		t.expect.near(free.Y, GA.Up, 1e-6); t.expect.near(free.X, 10, 1e-6)
		-- no rays at all (the offline harness): the same
		t.expect.near(GA.clear(at, 1, V(0, 0, 1), nil).Y, GA.Up, 1e-6)
		-- a low ceiling 8 studs up: the arrow's top stays Clear.Ceiling under it
		local low = GA.clear(at, 1, V(0, 0, 1), function(_, dir) if dir.Y > 0 then return 7.5 end return nil end)
		t.expect.truthy(low.Y + GA.height(1) <= 8 - GA.Clear.Ceiling + 1e-6)
		-- a ceiling right on top of it: never lower than Clear.Lowest
		local squashed = GA.clear(at, 1, V(0, 0, 1), function(_, dir) if dir.Y > 0 then return 1 end return nil end)
		t.expect.near(squashed.Y, GA.Clear.Lowest, 1e-6)
		-- a wall 1 stud to the arrow's own right: pushed away from it
		local right = V(0, 1, 0):Cross(V(0, 0, 1)).Unit
		local pushed = GA.clear(at, 1, V(0, 0, 1), function(_, dir)
			if dir.Y == 0 and dir.Unit:Dot(right) > 0.9 then return 1 end
			return nil
		end)
		local need = GA.Size.HeadW + GA.Clear.Wall
		t.expect.near((pushed - free):Dot(right), -(need - 1), 1e-6)
	end)

	t.test('the screen point of a world point, like the camera\'s own (in front, to the side, behind)', function()
		local view = Vector2.new(1280, 720)
		local cam = CFrame.lookAt(V(0, 0, 0), V(0, 0, -1))
		local c = GA.project(cam, 70, view, V(0, 0, -10))
		t.expect.near(c.X, 640, 1e-3); t.expect.near(c.Y, 360, 1e-3); t.expect.near(c.Z, 10, 1e-3)
		local f = 360 / math.tan(math.rad(35))
		local r = GA.project(cam, 70, view, V(2, 1, -10)) -- (right and up: x grows, y shrinks)
		t.expect.near(r.X, 640 + 0.2 * f, 1e-3); t.expect.near(r.Y, 360 - 0.1 * f, 1e-3)
		local b = GA.project(cam, 70, view, V(2, 0, 10)) -- (behind: depth negative, mirrored)
		t.expect.truthy(b.Z < 0 and b.X < 640)
		t.expect.equal(GA.project(nil, 70, view, V(0, 0, 0)), nil)
	end)

	t.test('the edge pointer: none while the arrow is on screen, else on the edge toward it', function()
		local view = Vector2.new(1280, 720)
		t.expect.equal(GA.edge(V(640, 300, 20), view), nil)
		local bx, by = 1280 * GA.Edge.Box.X, 720 * GA.Edge.Box.Y
		local r = GA.edge(V(2000, 360, 20), view) -- (far off to the right)
		t.expect.near(r.X, 640 + bx, 0.5); t.expect.near(r.Y, 360, 0.5); t.expect.near(r.Angle, 0, 0.5)
		local l = GA.edge(V(-500, 360, 20), view)
		t.expect.near(l.X, 640 - bx, 0.5); t.expect.near(math.abs(l.Angle), 180, 0.5)
		local up = GA.edge(V(640, -900, 20), view)
		t.expect.near(up.Y, 360 - by, 0.5); t.expect.near(up.Angle, -90, 0.5)
		-- clear of the HUD: never in the outer columns or at the very foot
		t.expect.truthy(640 - bx >= 150 and 360 + by <= 600)
		-- behind you: it points down and round (never at the middle of the screen)
		local b = GA.edge(V(640, 360, -5), view)
		t.expect.truthy(b ~= nil and b.Y > 360 and b.Angle > 0)
		local b2 = GA.edge(V(300, 360, -5), view) -- (behind and to the left on the mirrored projection: turn right)
		t.expect.truthy(b2.X > 640)
		-- inside the view's frame: always
		for _, sp in { V(5000, 4000, 3), V(-5000, -4000, 3), V(100, 9000, -3) } do
			local e = GA.edge(sp, view)
			t.expect.truthy(e.X >= 640 - bx - 0.5 and e.X <= 640 + bx + 0.5 and e.Y >= 360 - by - 0.5 and e.Y <= 360 + by + 0.5)
		end
		t.expect.equal(GA.edge(nil, view), nil)
	end)
	t.test('the edge pointer slides off the HUD buttons, toward the centre', function()
		local view = Vector2.new(1280, 720)
		-- (the Shop button's box on a computer, and the pointer where the round 9 still put it)
		local shop = { x0 = 16, y0 = 159, x1 = 232, y1 = 233 }
		local x, y = GA.clearOf(175, 195, 40, { shop }, view)
		t.expect.truthy(x - 40 >= shop.x1 or y - 40 >= shop.y1 or y + 40 <= shop.y0)
		t.expect.truthy(x > 175 and x < 640) -- (inward, along the line to the centre)
		local x2, y2 = GA.clearOf(175, 195, 40, {}, view)
		t.expect.equal(x2, 175); t.expect.equal(y2, 195) -- (no HUD: its own spot)
		local x3, y3 = GA.clearOf(175, 195, 40, { { x0 = 300, y0 = 300, x1 = 400, y1 = 400 } }, view)
		t.expect.equal(x3, 175); t.expect.equal(y3, 195) -- (a button elsewhere: its own spot)
	end)
end
