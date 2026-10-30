-- UnboxWorld (brief 28c, REVEAL): the normal openings (Common to Mythic, Cash and Robux boxes, a single, the welcome
-- gift, Buy 3 and Buy 8, and a Secret's prelude) play IN THE WORLD, where the player stands: copy_spec v5 §11.5, the
-- "+1 Soldier Evolution" egg hatch at its own speed with our shoe box for the egg and the pair for the pet.
--   The player's camera is held as it was (no move, no shake, no grade, no blur). The real 3D box stands in front of it,
--   centred, 34 % of the screen's height, placed from the camera every frame at 6.5 studs (anything nearer, a wall or
--   the character, brings it closer, at the same size on screen, so it never reaches into the world).
--   0.10 it drops from the top of the screen (stretched) and lands at 0.35: a squash, a bounce, a puff, a 1.5x ghost of
--   the box; a low rock from then on (4 -> 8 deg, 2.5 -> 5 Hz); three hop-and-roll shakes on its bottom edge at 0.90 /
--   1.65 / 2.20 (12 / 18 / 24 deg, L-R-L), each with a 1.12x ghost, the lid jolting up, the seam's light growing in the
--   honest colour, the seal tape tearing further and a few twinkles; the squeeze 2.45-2.90 (0.85x, rocking hardest); the
--   pop at 2.95, (brief 30, the user: "smoothly with vfx and graphics like other games", no cut from the box to the
--   shoes) one continuous move: the chest's lid swings open on its hinge (Back Out to 112 deg in 0.32 s), a column of
--   the rarity's light rises out of it with motes streaming up, a ring, a sparkle shower and a soft wash; the pair rises
--   out of the open chest through the column, spinning down from a fast turn, 0 -> 1.1x at the top of its rise -> 1x as
--   it settles in the middle (0.72 s), while the chest sinks away under it, shrinking and fading (gone by +0.85 s). The
--   build-up carries it: the lid's crack opens further at each shake, light leaks out of it in rays (the seam's honest
--   colour) and a pool of light grows under the box (Shared/UnboxFX). The reveal: a soft glow behind the pair, about 20
--   rays in the rarity's colour that fade in, breathe and slowly turn (8 deg/s), 1-2 twinkles, confetti for Epic and
--   up; its name, the rarity and "1 in N", NEW! and "Tap anywhere to close!", scaling in as the pair tops out (no Power
--   number: the user). A tap (or 5.7 s after the reveal) flies the pair into the inventory button with a trail (0.5 s;
--   0.3 after a tap); the HUD comes back (opts.onClose).
--   Legendary / Mythic: the box looks like itself (the user: no rainbow box); a fourth, harder shake (pop 3.80), then
--   after the pop a bigger burst, a brighter wash, ring bursts, an extra spin (2 / 2.5 turns through the rise), bigger
--   rays; a Mythic harder and bigger again, with a second ring burst at its reveal. Buy 3 / Buy 8: a row (or two) dropping
--   staggered, shaking together, popping in rising rarity, each pair in its box's place. A Secret: the drop and two
--   shakes here, then the cue, the cut and the crazy cinematic (UnboxCinematic's chain).
-- UnboxCinematic installs its internals (UnboxWorld.install) and calls in wherever P.inworld is set.
local UnboxWorld = {}

local Shared = script.Parent
local Themes = require(Shared:WaitForChild('UnboxThemes'))
local Kit = require(Shared:WaitForChild('UnboxKit'))
local FX = require(Shared:WaitForChild('UnboxFX'))
local M, Make, Actor, Ring = Kit.M, Kit.Make, Kit.Actor, Kit.Ring
local seqOf, nseq = Kit.seq, Kit.nseq
local V3, CF, ANG = Vector3.new, CFrame.new, CFrame.Angles
local C3 = Color3.fromRGB
local NR = NumberRange.new
local WHITE = Color3.new(1, 1, 1)
local PI, RAD = math.pi, math.rad
local WARM = C3(255, 246, 216) -- (the reference's ray colour)

-- the cinematic's internals: Box, Look, BoxModels, ShoeModels, rarityColor, rarityRow, shoeDef, oneIn, label, fadeText,
-- frame, gradient, rainbowSeq
local X = {}
function UnboxWorld.install(x) X = x end

---------------------------------------------------------------------------------------------- the plan (pure)
-- The timeline of an opening in the world (fills the plan's beat tables; UnboxCinematic.plan calls it).
function UnboxWorld.plan(P)
	local n, best = P.n, P.best
	local Wd = Themes.World
	-- (a Legendary's or Mythic's single: a fourth shake and the pop at 3.80; 1 Legendary, 2 Mythic)
	P.wlux = (n == 1 and not P.prelude and P.rank >= 4 and P.rank <= 5) and (P.rank - 3) or nil
	local lux = P.wlux ~= nil
	P.cut, P.clear = 0, 0
	P.fall = Wd.Fall
	-- (a row drops left to right, 100 ms apart; two rows 70 ms apart, the back row first)
	local gap = n >= 5 and 0.07 or 0.1
	for i = 1, n do
		P.land[i] = Wd.Land + (i - 1) * gap
		P.appear[i] = P.land[i] - Wd.Fall
		P.fall0[i] = P.appear[i]
		P.hs[i] = 0.035
		P.trauma[i] = 0
		P.wobOff[i] = n == 1 and 0 or ((i - 1) % 4) * 0.035
	end
	-- the shakes: { time, roll (deg), hop (box heights), length (s) }
	P.wobSpec = {}
	for _, s in (P.wlux == 2 and Wd.ShakesMythic or lux and Wd.ShakesLux or Wd.Shakes) do table.insert(P.wobSpec, { s[1], s[2], s[3], s[4] }) end
	if P.prelude then
		-- a Secret's prelude: the drop and two shakes, then the cue at shake 2's peak (a 120 ms freeze, two wrong-way hops,
		-- a thin line of the theme's light at the seam) and the cut (the world's light falls to the deep-blue sky in
		-- 0.15 s, the camera tilts up 24 deg, the box lifts into a tear in the sky); the crazy sheet takes over at stop
		P.wobSpec = { P.wobSpec[1], P.wobSpec[2] }
		local s2 = P.wobSpec[2]
		P.freeze = { s2[1] + s2[4] * 0.5, s2[1] + s2[4] * 0.5 + 0.12 }
		P.hops = { P.freeze[2] + 0.03, P.freeze[2] + 0.15 }
		P.cue = P.freeze[1]
		P.cutAt = P.freeze[2] + 0.27
		P.lift = P.cutAt
		P.tear = P.cutAt + 0.15
		P.stop = P.cutAt + 0.55
	end
	local sq = lux and Wd.SqueezeLux or Wd.Squeeze
	P.squeeze = { sq[1], sq[2], sq[3] }
	-- the pops in rising rarity, the best last: a single at 2.95 (3.80); a row 0.3 s apart; two rows 0.17 s apart
	local p0 = P.prelude and P.stop + 5 or (lux and Wd.PopLux or Wd.Pop)
	for j, i in P.order do
		if n == 1 then P.pop[i] = p0
		elseif n <= 4 then P.pop[i] = p0 + (j - 1) * 0.3
		else P.pop[i] = p0 + (j - 1) * 0.17 end
		P.crouch[i] = P.squeeze[1]
		P.rise[i] = P.pop[i]
	end
	-- (brief 30) the pair rises out of the open chest, spinning, and settles in its box's place: Rise.len after its pop
	local R = Wd.Rise
	P.riseLen = R.len
	P.spinLen, P.spinTurns = R.len, 1
	-- (the extra spin: a Legendary's or Mythic's single, and a row's best when it is Legendary or better: 2 / 2.5 turns
	-- through the rise)
	if lux or (n > 1 and P.rank >= 4) then
		P.spinBest = { R.len, Wd.SpinLux[P.rank >= 5 and 3 or 2] }
	end
	for i = 1, n do
		P.accent[i] = P.pop[i] + R.len
	end
	local a = P.accent[best]
	P.reveal = a
	-- (the words glide in as the pair settles, the end of the one move; P.nameT is where the UI attaches (PityUI's tag);
	-- "Click anywhere to continue" (P.tap) 0.4 s later; no card (brief 30, the user); the Power reel ticks 0.6 s)
	P.banner = a - 0.05
	P.nameT, P.newT = P.banner, P.banner + 0.16
	P.count = { a, a + 0.6 }
	P.tap = P.banner + 0.4 -- (brief 30: "Click anywhere to continue" 0.4 s after the name)
	P.out = P.prelude and P.stop + 10 or a + Wd.Hold
	P.closeLen = Wd.Close[1]
	P.group = n > 1 and a - 0.2 or nil
	-- the wash at the best's pop (none in a row's other pops: one a second at most), the reference's soft white:
	-- Common-Epic peak 0.48 (never a white-out), Legendary and up 0.85; at its peak on the pop's frame, then a Quad Out
	-- over 0.45 s (>= 0.5 for under 0.1 s); none with Reduced Motion
	P.flashes, P.soft = {}, {}
	if not P.reduced and not P.prelude then
		if P.rank >= 4 then
			table.insert(P.flashes, { P.pop[best], Wd.Wash[2], Wd.Wash[3], 0 })
		else
			table.insert(P.soft, { P.pop[best], Wd.Wash[1], Wd.Wash[3], 0 })
		end
	end
	P.firstPop = P.pop[P.order[1]]
	P.lastLand = P.land[n]
end

-- The layout in rig units (the box at scale 1): each box's relative scale and its base's place; the job scales it all
-- to the screen (UnboxWorld.place).
local function rigLayout(n, fullH, W, D)
	local s, homes = 1, {}
	if n == 1 then
		homes[1] = V3(0, 0, 0)
	elseif n <= 4 then
		s = n == 2 and 0.8 or 0.7
		local sp = W * s * 1.42
		for i = 1, n do homes[i] = V3((i - (n + 1) / 2) * sp, 0, 0) end
	else
		-- two rows: the back row (dropping first) standing above the front one in the screen's plane, offset half a slot,
		-- so no box hides another
		s = 0.5
		local sp = W * s * 1.42
		local back = math.floor(n / 2)
		local front = n - back
		for j = 1, back do homes[j] = V3((j - (back + 1) / 2) * sp + sp * 0.25, fullH * s * 1.32, 0) end
		for j = 1, front do homes[back + j] = V3((j - (front + 1) / 2) * sp - sp * 0.25, 0, 0) end
	end
	return s, homes
end
function UnboxWorld.layout(P)
	local size = X.BoxModels and X.BoxModels.Size or { W = 4.4, D = 3.4, Body = 2.1, Top = 3.08 }
	local s, homes = rigLayout(P.n, size.Top or 3.08, size.W, size.D)
	P.boxScale, P.homes = s, homes
	P.shoeScale = s
	P.padR = 6
	P.boxW = size.W * s
end

---------------------------------------------------------------------------------------------- placing the rig
local function viewport(job)
	local cam = workspace.CurrentCamera
	local ok, v = pcall(function() return cam.ViewportSize end)
	if ok and typeof(v) == 'Vector2' and v.X > 1 and v.Y > 1 then return v end
	local ok2, a = pcall(function() return job.gui.AbsoluteSize end)
	if ok2 and typeof(a) == 'Vector2' and a.X > 1 and a.Y > 1 then return a end
	return Vector2.new(1280, 720)
end
local function extent(model)
	local mn, mx = V3(math.huge, math.huge, math.huge), V3(-math.huge, -math.huge, -math.huge)
	for _, p in model:GetDescendants() do
		if p:IsA('BasePart') and p.Transparency < 0.95 then
			local _, _, _, r00, r01, r02, r10, r11, r12, r20, r21, r22 = p.CFrame:GetComponents()
			local c, s = p.CFrame.Position, p.Size / 2
			local e = V3(math.abs(r00) * s.X + math.abs(r01) * s.Y + math.abs(r02) * s.Z, math.abs(r10) * s.X + math.abs(r11) * s.Y + math.abs(r12) * s.Z, math.abs(r20) * s.X + math.abs(r21) * s.Y + math.abs(r22) * s.Z)
			mn, mx = mn:Min(c - e), mx:Max(c + e)
		end
	end
	if mn.X > mx.X then return V3(0, 0, 0), V3(1, 1, 1) end
	return mn, mx
end
-- the box's and the best pair's real sizes at scale 1 (the box's topper included), from probes that are not kept
local function probes(P)
	local size = X.BoxModels and X.BoxModels.Size or { W = 4.4, D = 3.4, Body = 2.1, Top = 3.08 }
	local box = { H = size.Top or 3.08, W = size.W, D = size.D }
	if X.BoxModels and type(X.BoxModels.build) == 'function' then
		local ok, m = pcall(X.BoxModels.build, P.box, 1, CF())
		if ok and typeof(m) == 'Instance' then
			local mn, mx = extent(m)
			box.H = math.max(box.H, mx.Y - math.max(0, mn.Y))
			m:Destroy()
		end
	end
	local pair = { H = 0.9, W = 2.0 }
	local id = P.list[P.best] and P.list[P.best].Shoe
	if id and X.ShoeModels and type(X.ShoeModels.pair) == 'function' then
		local ok, m = pcall(X.ShoeModels.pair, id, 1)
		if ok and typeof(m) == 'Instance' then
			local mn, mx = extent(m)
			pair.H = math.max(0.3, mx.Y - mn.Y)
			pair.W = math.max(mx.X - mn.X, mx.Z - mn.Z)
			m:Destroy()
		end
	end
	return box, pair
end
-- How far ahead the view is clear over a patch of the screen (a, b: -1..1 x; c, d: -1..1 y): the nearest thing hit
-- by a grid of rays through it, as a depth along the view (the character counts unless the camera is in its head).
local function clearDepth(job, camCF, tx, ty, a, b, c, d, maxDepth)
	local okP, params = pcall(function()
		local p = RaycastParams.new()
		p.FilterType = Enum.RaycastFilterType.Exclude
		local skip = { job.folder }
		local plr = game:GetService('Players').LocalPlayer
		local ch = plr and plr.Character
		local head = ch and ch:FindFirstChild('Head')
		local firstPerson = false
		if head and head:IsA('BasePart') then
			firstPerson = (head.CFrame.Position - camCF.Position).Magnitude < 1.5
			pcall(function() firstPerson = firstPerson or head.LocalTransparencyModifier > 0.5 end)
		end
		if firstPerson then table.insert(skip, ch) end
		p.FilterDescendantsInstances = skip
		return p
	end)
	if not okP then return math.huge end
	local near = math.huge
	for iu = 0, 4 do
		for iv = 0, 3 do
			local dir = camCF:VectorToWorldSpace(V3(M.lerp(a, b, iu / 4) * tx, M.lerp(c, d, iv / 3) * ty, -1))
			local ok, hit = pcall(function() return workspace:Raycast(camCF.Position, dir * maxDepth, params) end)
			if ok and hit then near = math.min(near, hit.Distance / dir.Magnitude) end
		end
	end
	return near
end

-- A set of world points on the held camera's screen: their bounds in -1..1 (x right, y up).
local function project(view, pts)
	local x0, x1, y0, y1 = math.huge, -math.huge, math.huge, -math.huge
	for _, p in pts do
		local q = view.cf:PointToObjectSpace(p)
		local z = math.max(0.05, -q.Z)
		local sx, sy = q.X / (z * view.tx), q.Y / (z * view.ty)
		x0, x1, y0, y1 = math.min(x0, sx), math.max(x1, sx), math.min(y0, sy), math.max(y1, sy)
	end
	return x0, x1, y0, y1
end
UnboxWorld.project = project
local CORNERS = { { -1, 0, -1 }, { 1, 0, -1 }, { -1, 0, 1 }, { 1, 0, 1 }, { -1, 1, -1 }, { 1, 1, -1 }, { -1, 1, 1 }, { 1, 1, 1 } }
-- the frame O for the rig's centre on the screen's (0.5, v) at depth D: level, its +Z away from the camera, its top
-- tilted so the camera sees the lid from 12-32 deg above
local function frameAt(camCF, ty, v, D)
	local look = camCF.LookVector
	local f = V3(look.X, 0, look.Z)
	if f.Magnitude < 0.2 then f = V3(camCF.UpVector.X, 0, camCF.UpVector.Z) end
	f = f.Unit
	local up = V3(0, 1, 0)
	local R = CFrame.fromMatrix(Vector3.zero, up:Cross(f), up, f)
	local Pc = camCF.Position + camCF:VectorToWorldSpace(V3(0, v * ty, -1)) * D
	local dir = (Pc - camCF.Position).Unit
	local elev = math.deg(math.asin(math.clamp(-dir.Y, -1, 1)))
	local tilt = 0
	if elev < 12 then tilt = -(12 - elev) elseif elev > 32 then tilt = elev - 32 end
	return CF(Pc) * R * ANG(RAD(tilt), 0, 0)
end

-- Where the rig stands: from the held camera, the frame O and the scale k that put the box (its lid and topper
-- included, as the camera sees it) at 34 % of the screen's height and its middle 47 % down (a row's boxes smaller, all
-- of it inside 90 % of the width with the shakes' roll); measured by projecting the boxes' corners, so the perspective
-- at 6.5 studs is counted. Sets P.boxScale, P.homes, P.shoeScale (a first guess; UnboxWorld.fitPairs measures them).
function UnboxWorld.place(job)
	local P, Wd = job.P, Themes.World
	local n = P.n
	local cam = workspace.CurrentCamera
	local camCF = cam and cam.CFrame or CF(0, 5, 10)
	local fov = cam and cam.FieldOfView or 70
	local vp = viewport(job)
	local aspect = vp.X / vp.Y
	local ty = math.tan(RAD(fov / 2))
	local tx = ty * aspect
	local view = { cf = camCF, tx = tx, ty = ty, aspect = aspect, size = vp }
	local box1, pair1 = probes(P)
	local s0, homes0 = rigLayout(n, box1.H, box1.W, box1.D)
	local x0, x1, y0, y1 = math.huge, -math.huge, math.huge, -math.huge
	for _, h in homes0 do
		x0, x1 = math.min(x0, h.X), math.max(x1, h.X)
		y0, y1 = math.min(y0, h.Y), math.max(y1, h.Y + box1.H * s0)
	end
	local centre = V3((x0 + x1) / 2, (y0 + y1) / 2, 0)
	local target = n == 1 and Wd.At or Wd.RowAt
	local share = n == 1 and Wd.Box or (n <= 4 and 0.26 or 0.18)
	-- (a box rolled 24 deg on its edge reaches 0.46 W + 0.41 H out from its middle)
	local roll = (box1.W * 0.46 + box1.H * 0.41) / (box1.W * 0.5)
	local function pts(kk, oo, which)
		local list = {}
		for i, h in homes0 do
			if not which or which == i then
				local base = oo * CF((h - centre) * kk)
				local hw, hh, hd = box1.W * 0.5 * s0 * kk, box1.H * s0 * kk, box1.D * 0.5 * s0 * kk
				for _, c in CORNERS do table.insert(list, base * V3(c[1] * hw, c[2] * hh, c[3] * hd)) end
			end
		end
		return list
	end
	local one = n == 1 and 1 or P.best
	-- the size and the place at depth D (the boxes measured on the screen, a few rounds)
	local function solve(D)
		local v = 1 - 2 * target
		local k = share * 2 * D * ty / (box1.H * s0)
		for _ = 1, 4 do
			local O = frameAt(camCF, ty, v, D)
			local _, _, b0, b1 = project(view, pts(k, O, one))
			k *= share * 2 / math.max(1e-3, b1 - b0)
			local a0, a1, c0, c1 = project(view, pts(k, O))
			local wNow = (a1 - a0) + (roll - 1) * (box1.W * s0 * k) / (D * tx)
			if wNow > 1.8 then k *= 1.8 / wNow end
			if c1 - c0 > 1.6 then k *= 1.6 / (c1 - c0) end
			local _, _, d0, d1 = project(view, pts(k, O))
			v += (1 - 2 * target) - (d0 + d1) / 2
		end
		return k, v, frameAt(camCF, ty, v, D)
	end
	-- 6.5 studs out, unless the world is nearer anywhere over the rig's patch of the screen (with the shakes' reach and
	-- the lid's jump): then nearer, and smaller, so the same on the screen, never reaching into a wall
	local D = Wd.Dist
	local k, v, O = solve(D)
	for _ = 1, 3 do
		local a0, a1, c0, c1 = project(view, pts(k, O))
		local wx = (roll - 1) * (box1.W * s0 * k) / (D * tx)
		local depthHalf = box1.D * s0 * k * 0.5 * 1.3 + 0.15
		local near = clearDepth(job, camCF, tx, ty, a0 - wx, a1 + wx, c0, c1 + 0.15, D + depthHalf + 1)
		if near >= D + depthHalf then break end
		D = math.max(2, (near - 0.15) / (1 + (depthHalf - 0.15) / D))
		k, v, O = solve(D)
	end
	P.boxScale = s0 * k
	-- (O's origin is the rig's centre: the homes are relative to it)
	P.homes = {}
	for i, h in homes0 do P.homes[i] = (h - centre) * k end
	local Hvis, Wvis = 2 * D * ty, 2 * D * tx
	P.shoeScale = math.min(Wd.Pair * Hvis / pair1.H, 0.5 * Wvis / pair1.W) * (n == 1 and 1 or 0.6)
	job.k = k
	job.pairW = n == 1 and 0.5 * Wvis or box1.W * s0 * k * 1.2
	job.pairH = Wd.Pair * Hvis
	job.O = O
	job.park = job.O * CF(0, -400, 0)
	job.away = V3(0, 0, -1)
	job.camBase, job.fov = camCF, fov
	view.D, view.Hvis, view.Wvis = D, Hvis, Wvis
	job.view = view
	job.focus = CF(O.Position)
	-- the drop starts with the box's base just above the top of the screen
	job.fallH = Hvis * 0.5 * (1 - v) + box1.H * P.boxScale * 0.6 + 0.2 * k
end

-- Each pair's place (its box's middle) and its scale, measured on the screen like the boxes: a single's 26 % of the
-- height (its mean over a turn) and at most 55 % of the width at its widest; a row's 80 % of its box's height and 90 %
-- of the slot. Also the pair's own middle (it turns about it).
function UnboxWorld.fitPairs(job)
	local P, Wd = job.P, Themes.World
	job.slots, job.pairFit = {}, {}
	for i, box in job.boxes do
		job.slots[i] = P.homes[i] + V3(0, box.fullH * 0.5, 0)
		local pr = job.pairs[i]
		local mn, mx = V3(math.huge, math.huge, math.huge), V3(-math.huge, -math.huge, -math.huge)
		for idx, rel in pr.actor.rel do
			local _, _, _, r00, r01, r02, r10, r11, r12, r20, r21, r22 = rel:GetComponents()
			local c, s = rel.Position, pr.actor.size[idx] / 2
			local e = V3(math.abs(r00) * s.X + math.abs(r01) * s.Y + math.abs(r02) * s.Z, math.abs(r10) * s.X + math.abs(r11) * s.Y + math.abs(r12) * s.Z, math.abs(r20) * s.X + math.abs(r21) * s.Y + math.abs(r22) * s.Z)
			if pr.actor.trans[idx] < 0.95 then mn, mx = mn:Min(c - e), mx:Max(c + e) end
		end
		pr.mid = (mn + mx) / 2
		local half = (mx - mn) / 2
		local slotW = job:wp(job.slots[i])
		local hs, wmax, n0 = 0, 0, 0
		for yawDeg = -25, 155, 30 do
			local cf = CF(slotW) * box.home.Rotation * ANG(RAD(-8), 0, 0) * ANG(0, RAD(yawDeg), 0)
			local list = {}
			for _, c in CORNERS do table.insert(list, cf * V3(c[1] * half.X, (c[2] * 2 - 1) * half.Y, c[3] * half.Z)) end
			local a0, a1, b0, b1 = project(job.view, list)
			hs += (b1 - b0) / 2
			wmax = math.max(wmax, (a1 - a0) / 2)
			n0 += 1
		end
		hs /= n0
		local fit
		if P.n == 1 then
			fit = math.min(Wd.Pair / hs, 0.55 / wmax)
		else
			local bx0, bx1, by0, by1 = project(job.view, (function()
				local list = {}
				for _, c in CORNERS do table.insert(list, box.home * V3(c[1] * box.W * 0.5, c[2] * box.fullH, c[3] * box.D * 0.5)) end
				return list
			end)())
			fit = math.min(0.95 * (by1 - by0) / 2 / hs, 0.9 * (bx1 - bx0) / 2 * 1.25 / wmax)
		end
		job.pairFit[i] = fit
	end
end

---------------------------------------------------------------------------------------------- building
-- The rig's own pieces (no set): the effects anchor, the box's light, a volume round the rig; and the
-- fields the shared code reads.
function UnboxWorld.build(job)
	local P = job.P
	local c = job.folder
	local k = job.k or 1
	job.setKind, job.setParts = 'world', 0
	job.nightParts, job.lamps, job.speakers, job.signNeon, job.pillars, job.rays, job.orbiters = {}, {}, {}, {}, {}, {}, {}
	job.anchor = Make.part(c, 'FxAnchor', V3(0.2, 0.2, 0.2), job.O, WHITE, nil, { Transparency = 1 })
	job.boxGlow = Make.part(c, 'BoxLight', V3(0.2, 0.2, 0.2), job.park, WHITE, nil, { Transparency = 1 })
	job.boxLight = Make.light(job.boxGlow, WHITE, 0, 9 * k)
	local around = Make.part(c, 'Volume_around', V3(job.view.Wvis * 0.5, job.view.Hvis * 0.5, 0.5), job.O, WHITE, nil, { Transparency = 1 })
	job.volumes = { around = around, back = around, sky = around, floor = around }
	job.padRim = Make.part(c, 'PadRim', V3(0.1, 0.1, 0.1), job.park, WHITE, nil, { Transparency = 1 })
	job.padTop, job.deckY = job.O.Y, job.O.Y
end
-- Bits fall away under the rig (nothing to land on).
function UnboxWorld.floorAt(job)
	return function() return job.O.Y - 1e4 end
end

-- The seal: a strip of tape down the middle of the front, across the lid's seam (the box's name stays readable): two
-- halves, each a piece on the tub and a piece on the lid with a bridge over the seam, and a tab over the lid's top.
-- Built into the model before its actors are made, so it squashes and jolts with them; Box.new calls this.
local TAPE_W, TAPE_T = 0.86, 0.035
function UnboxWorld.seal(job, model, home, s)
	local P = job.P
	local size = X.BoxModels and X.BoxModels.Size or { W = 4.4, D = 3.4, Body = 2.1, Top = 3.08 }
	local body, top, D = size.Body, size.Top or 3.08, size.D
	local lid = model:FindFirstChild('Lid') or model
	local h, sat = P.theme.Color:ToHSV()
	-- (yellow tape, red on a yellow box)
	local col = (h > 0.09 and h < 0.19 and sat > 0.35) and C3(226, 52, 48) or C3(255, 214, 48)
	local zb, zl = -(D / 2 + TAPE_T / 2 + 0.01), -(D / 2 + 0.12 + TAPE_T / 2 + 0.01)
	local lowY0, lidY1 = body - 0.62, top - 0.06
	-- (brief 30) a chest says where its front faces are in the middle (its latch and panel), how low the tape starts
	-- and where the lid's top is: the tape lies on them, crossing the latch like a sticker
	local at = X.BoxModels and X.BoxModels.Seal and X.BoxModels.Seal[P.box]
	if type(at) == 'table' and at.Body and at.Lid then
		zb, zl = at.Body - TAPE_T / 2 - 0.01, at.Lid - TAPE_T / 2 - 0.01
		lowY0 = at.Low or lowY0
		top = at.Top or top
		lidY1 = top - 0.06
	end
	local pieces = {}
	for _, side in { -1, 1 } do
		local x = side * TAPE_W / 4
		local w = TAPE_W / 2 - 0.03
		local lower = Make.part(model, 'Seal', V3(w, body - lowY0, TAPE_T) * s, home * CF(V3(x, (lowY0 + body) / 2, zb) * s), col)
		local upper = Make.part(lid, 'Seal', V3(w, lidY1 - body - 0.03, TAPE_T) * s, home * CF(V3(x, (body + 0.03 + lidY1) / 2, zl) * s), col)
		local bridge = Make.part(model, 'Seal', V3(w, 0.2, TAPE_T) * s, home * CF(V3(x, body + 0.02, (zb + zl) / 2) * s) * ANG(RAD(-28), 0, 0), col)
		Make.part(lid, 'Seal', V3(w, TAPE_T, 0.6) * s, home * CF(V3(x, top + TAPE_T / 2, zl + TAPE_T / 2 + 0.31) * s), col)
		table.insert(pieces, { side = side, lower = lower, upper = upper, bridge = bridge, w = w * s })
	end
	return pieces
end
-- After the actors: each torn piece's rest pose in its actor and the outer corner it swings from (an upper piece from
-- its top outer corner, a lower one from its bottom outer corner, both in the front's plane, so the camera sees it).
function UnboxWorld.sealRig(box, pieces, home, hingeCF)
	local function find(actor, p)
		for idx, q in actor.parts do
			if q == p then return idx end
		end
		return nil
	end
	box.seal = {}
	for _, pc in pieces do
		local e = { side = pc.side }
		local lw, uw = pc.lower.Size, pc.upper.Size
		e.lower = { actor = box.body, idx = find(box.body, pc.lower), h = lw.Y, w = lw.X, edge = home:Inverse() * (pc.lower.CFrame * CF(pc.side * lw.X / 2, -lw.Y / 2, 0)), dir = -1 }
		e.upper = { actor = box.lid, idx = find(box.lid, pc.upper), h = uw.Y, w = uw.X, edge = hingeCF:Inverse() * (pc.upper.CFrame * CF(pc.side * uw.X / 2, uw.Y / 2, 0)), dir = 1 }
		e.bridge = pc.bridge
		e.bridgeIdx = find(box.body, pc.bridge)
		table.insert(box.seal, e)
	end
	box.sealStage = 0
end
-- The seal's stage k (0 whole .. 3 split): the screen-right half splits first; each torn flap swings out sideways from
-- its outer corner (deg: { upper, lower, bridge whole }).
local PEEL = {
	[0] = { R = { 0, 0, true }, L = { 0, 0, true } },
	[1] = { R = { 16, 0, false }, L = { 0, 0, true } },
	[2] = { R = { 34, 12, false }, L = { 12, 0, false } },
	[3] = { R = { 58, 26, false }, L = { 34, 14, false } },
}
local function setSeal(box, stage)
	if box.sealStage == stage or not box.seal then return end
	box.sealStage = stage
	local spec = PEEL[math.clamp(stage, 0, 3)]
	for _, e in box.seal do
		local sp = e.side < 0 and spec.R or spec.L
		for kk, piece in { e.upper, e.lower } do
			if piece.idx then
				local deg = kk == 1 and sp[1] or sp[2]
				-- (an upper flap hangs from its top outer corner: its bottom swings out, away from the middle; a lower one
				-- stands on its bottom outer corner: its top swings out)
				local rot = ANG(0, 0, RAD(deg) * e.side * piece.dir)
				piece.actor.rel[piece.idx] = piece.edge * rot * CF(-e.side * piece.w / 2, -piece.dir * piece.h / 2, 0)
				piece.actor.last = nil
			end
		end
		e.bridge.Transparency = sp[3] and 0 or 1
		-- (the actor's own record too, so the chest's fade at the pop keeps a torn bridge gone)
		if e.bridgeIdx then box.body.trans[e.bridgeIdx] = sp[3] and 0 or 1 end
	end
end

-- A ghost of the box (the reference's translucent shell): a copy of its visible parts, pale, posed with it and scaled
-- about its middle at each impact.
function UnboxWorld.ghost(job, box)
	local list = {}
	local folder = Instance.new('Folder')
	folder.Name = 'Ghost'
	for _, p in box.model:GetDescendants() do
		if p:IsA('BasePart') and p.Transparency < 0.9 and p.Name ~= 'RainbowAura' then
			local g = p:Clone()
			g:ClearAllChildren()
			g.Name = 'Ghost'
			g.Material = Enum.Material.SmoothPlastic
			g.Color = p.Color:Lerp(WHITE, 0.3)
			g.Transparency = 1
			g.CastShadow = false
			g.Parent = folder
			table.insert(list, g)
		end
	end
	folder.Parent = job.folder
	box.ghost = Actor.new(list, box.home)
	box.ghost:pose(job.park, 1)
	box.ghostOn = false
end

-- The effects (sized from the box, so they follow the rig's scale).
function UnboxWorld.effects(job)
	local P, th = job.P, job.P.theme
	local rcol = X.rarityColor(P.rank)
	local W0 = job.boxes[P.best].W
	local H0 = job.boxes[P.best].topY
	local fx = {}
	job.fx = fx
	-- (the pop's burst and ring grow with the rarity: Legendary x1.35, Mythic x1.65)
	local B = Themes.World.Burst[P.rank >= 5 and 3 or P.rank == 4 and 2 or 1]
	job.burst = B
	-- (brief 30: the rays and the glow in the rarity's colour, on the reference's warm white: a Common's stays warm white)
	local tint = P.rank <= 1 and WARM or WARM:Lerp(rcol, (P.rank >= 4 and P.rank <= 5) and 0.5 or 0.55)
	-- the landing: a ring of dust puffs round the base and a few sparkles
	fx.puff = job:emitter('LandPuff', 'smoke', seqOf({ C3(246, 242, 234), C3(220, 214, 204) }), {
		life = { 0.22, 0.3 }, speed = { W0 * 2, W0 * 3 }, drag = 6, accel = V3(0, H0 * 0.4, 0), spread = Vector2.new(10, 10), direction = Enum.NormalId.Front,
		lightInfluence = 0, emission = 0, size = nseq({ { 0, W0 * 0.14, W0 * 0.03 }, { 1, W0 * 0.42 } }),
		transparency = nseq({ { 0, 1 }, { 0.08, 0.25 }, { 0.6, 0.6 }, { 1, 1 } }), rotSpeed = NR(-60, 60), zoffset = 1,
	})
	fx.sparkle = job:emitter('Sparkle', 'spark', seqOf({ WHITE, th.Color:Lerp(WHITE, 0.5) }), {
		life = { 0.2, 0.3 }, speed = { W0 * 0.6, W0 * 1.4 }, drag = 3, spread = Vector2.new(60, 60), size = nseq({ { 0, 0 }, { 0.3, W0 * 0.07 }, { 1, 0 } }),
		transparency = nseq({ { 0, 0 }, { 1, 0.3 } }), brightness = 2, zoffset = 1,
	})
	-- the shakes' twinkles (small white 4-point stars on the box)
	fx.glint = job:emitter('Glint', 'spark', seqOf({ WHITE, WHITE }), {
		life = { 0.1, 0.15 }, speed = { 0, 0.01 }, size = nseq({ { 0, 0 }, { 0.4, W0 * 0.08 }, { 1, 0 } }), transparency = nseq({ { 0, 0 }, { 1, 0.2 } }), brightness = 2, zoffset = 2,
	})
	-- the pop: a burst of sparks in the rarity colour, a ring racing out to ~2.5 box widths, a hot glow
	fx.popBurst = job:emitter('PopBurst', 'spark', seqOf({ WHITE, rcol:Lerp(WHITE, 0.25) }), {
		life = { 0.35, 0.55 }, speed = { W0 * 3 * B, W0 * 5 * B }, drag = 4, spread = Vector2.new(180, 180), size = nseq({ { 0, W0 * 0.1 * math.sqrt(B) }, { 1, 0 } }),
		transparency = nseq({ { 0, 0 }, { 0.7, 0.2 }, { 1, 1 } }), brightness = 2, zoffset = 2,
	})
	fx.ringBurst = job:emitter('RingBurst', 'ring', seqOf({ WHITE:Lerp(rcol, 0.5), rcol }), {
		life = { 0.22, 0.22 }, speed = { 0.01, 0.01 }, spread = Vector2.zero, orientation = Enum.ParticleOrientation.VelocityPerpendicular,
		size = nseq({ { 0, W0 * 0.4 * B }, { 0.6, W0 * 1.2 * B }, { 1, W0 * 1.3 * B } }), transparency = nseq({ { 0, 0 }, { 0.6, 0.25 }, { 1, 1 } }), rotation = NR(0), rotSpeed = NR(0), emission = 1, zoffset = 2,
	})
	fx.popGlow = job:emitter('PopGlow', 'glow', seqOf({ WHITE, WHITE:Lerp(rcol, 0.5) }), {
		life = { 0.2, 0.2 }, speed = { 0.01, 0.01 }, spread = Vector2.zero, rotation = NR(0), rotSpeed = NR(0), emission = 1, lightInfluence = 0,
		size = nseq({ { 0, W0 * 0.7 * B }, { 1, W0 * 1.1 * B } }), transparency = nseq({ { 0, 0.2 }, { 0.4, 0.5 }, { 1, 1 } }), zoffset = 1,
	})
	-- the soft glow behind the pair through the reveal (warm white; a Legendary's or Mythic's in its tint)
	job.glowHost = Make.part(job.folder, 'BackGlow', V3(0.2, 0.2, 0.2), job.park, WHITE, nil, { Transparency = 1 })
	fx.backGlow = job:emitter('BackGlow', 'glow', seqOf({ tint:Lerp(WHITE, 0.4), tint }), {
		life = { 1.2, 1.2 }, speed = { 0, 0 }, rate = 2, rotSpeed = NR(0), rotation = NR(0), emission = 1, lightInfluence = 0,
		size = NumberSequence.new(W0), transparency = nseq({ { 0, 1 }, { 0.3, 0.62 }, { 0.7, 0.62 }, { 1, 1 } }), zoffset = -2,
	}, job.glowHost)
	fx.backGlow.LockedToPart = true
	-- the hold's twinkles round the pair (1-2 at a time) and the close's trail
	job.twinkleHost = Make.part(job.folder, 'TwinkleVolume', V3(1, 1, 0.3), job.park, WHITE, nil, { Transparency = 1 })
	fx.twinkle = job:emitter('Twinkle', 'spark', seqOf({ WHITE, WHITE }), {
		life = { 0.1, 0.14 }, speed = { 0, 0.01 }, rate = 7, size = nseq({ { 0, 0 }, { 0.4, W0 * 0.08 }, { 1, 0 } }), transparency = nseq({ { 0, 0 }, { 1, 0.3 } }), brightness = 2, zoffset = 2,
		shape = Enum.ParticleEmitterShape.Box,
	}, job.twinkleHost)
	job.trailHost = Make.part(job.folder, 'TrailHost', V3(0.2, 0.2, 0.2), job.park, WHITE, nil, { Transparency = 1 })
	fx.trail = job:emitter('Trail', 'spark', seqOf({ WHITE, rcol:Lerp(WHITE, 0.3) }), {
		life = { 0.22, 0.32 }, speed = { 0, W0 * 0.1 }, rate = 70, spread = Vector2.new(180, 180), size = nseq({ { 0, W0 * 0.12 }, { 1, 0 } }),
		transparency = nseq({ { 0, 0.1 }, { 1, 0.6 } }), brightness = 2, zoffset = 2,
	}, job.trailHost)
	-- Legendary / Mythic: the ring bursts at the pop (2 / 3 rings racing out in the rarity's colours, facing the camera;
	-- a Mythic's come again at its reveal)
	job.burstRings = {}
	if P.rank >= 4 and P.rank <= 5 then
		local cols = { rcol, rcol:Lerp(WHITE, 0.55), rcol:Lerp(C3(255, 240, 160), 0.4) }
		for kk = 1, (P.rank >= 5 and 3 or 2) do
			local r = Ring.new(job.anchor, 'BurstRing' .. kk, cols[kk], 0.05 * W0, 0.16 * W0, true, true)
			r:setColor(cols[kk], true)
			table.insert(job.burstRings, r)
		end
	end
	-- the rays behind the best pair (the reference's sunburst): about 20 narrow rays, invisible at the hub (behind the
	-- pair), strongest at 1.75 pair heights, gone by 2.3 (a Legendary's 1.3x, a Mythic's 1.55x); warm white, a
	-- Legendary's and Mythic's tinted with their colour
	local R = Themes.World.Rays
	job.rays = {}
	job.rayHub = Make.attach(job.anchor, 'RayHub')
	for kk = 1, R.n do
		local tip = Make.attach(job.anchor, 'RayTip' .. kk)
		local col = tint
		local b = Make.beam(job.anchor, job.rayHub, tip, seqOf({ col, col }), 0.05, 0.5, NumberSequence.new(1), 0.6, { Segments = 1, Tex = 'shaft' })
		b.Name = 'Ray' .. kk
		b.Enabled = false
		table.insert(job.rays, { tip = tip, beam = b, col = col, j = M.hash(kk, 41) })
	end
	job.ambient = {}
	-- (brief 30) the build-up's light and the burst's column, motes and shower (Shared/UnboxFX)
	FX.build(job, X)
end

-- The tear in the sky for a Secret's prelude: a jagged slit in the theme's colour (~8 % of the width) with a glow, where
-- the box flies, 8 deg above the frame's centre once the camera has tilted up 24 deg; 30 studs out, or in front of the
-- wall or ceiling that is nearer (indoors there is no sky to tear)
function UnboxWorld.tear(job)
	local P, th = job.P, job.P.theme
	local up = job.camBase * ANG(RAD(24), 0, 0)
	local dir = up:VectorToWorldSpace(V3(0, math.tan(RAD(8)), -1))
	local dist = 30
	local okP, params = pcall(function()
		local p = RaycastParams.new()
		p.FilterType = Enum.RaycastFilterType.Exclude
		p.FilterDescendantsInstances = { job.folder }
		return p
	end)
	if okP then
		local ok, hit = pcall(function() return workspace:Raycast(up.Position, dir * 30, params) end)
		if ok and hit then dist = math.max(5, hit.Distance / dir.Magnitude * 0.8) end
	end
	local pos = up * V3(0, math.tan(RAD(8)) * dist, -dist)
	local cf = CFrame.lookAt(pos, job.camBase.Position)
	local col = th.Color:Lerp(WHITE, 0.3)
	local unit = dist * 2 * math.tan(RAD(job.fov / 2)) * job.view.aspect * 0.08 / 3.8
	job.tearParts = {}
	local pts = { V3(-1.9, 0.1, 0), V3(-0.95, -0.28, 0), V3(0, 0.3, 0), V3(0.95, -0.22, 0), V3(1.9, 0.12, 0) }
	for kk = 1, #pts - 1 do
		local a, b = pts[kk] * unit, pts[kk + 1] * unit
		local seg = Make.part(job.folder, 'Tear', V3((b - a).Magnitude + 0.1 * unit, 0.16 * unit, 0.05), job.park, col, Enum.Material.Neon)
		table.insert(job.tearParts, { seg, CF((a + b) / 2) * CFrame.Angles(0, 0, math.atan2(b.Y - a.Y, b.X - a.X)) })
	end
	local glow = Make.part(job.folder, 'TearGlow', V3(0.2, 0.2, 0.2), job.park, WHITE, nil, { Transparency = 1 })
	table.insert(job.tearParts, { glow, CF(0, 0, 0.3) })
	job.tearGlow = job:emitter('TearGlow', 'glow', seqOf({ th.Color:Lerp(WHITE, 0.2), th.Color }), {
		life = { 30, 30 }, speed = { 0, 0 }, rotSpeed = NR(0), rotation = NR(0), size = NumberSequence.new(3 * unit),
		transparency = nseq({ { 0, 0.35 }, { 1, 0.35 } }), emission = 1, lightInfluence = 0, zoffset = -1,
	}, glow)
	job.tearGlow.LockedToPart = true
	job.tearCF = cf
	job.tearUnit = unit
end

---------------------------------------------------------------------------------------------- the beats
function UnboxWorld.beats(job)
	local P, fx = job.P, job.fx
	local camBack = job.camBase.LookVector * -1
	local function facing(pos) return CFrame.lookAt(pos, pos + camBack) end
	local big = function(i) return (not P.multi) or i == P.best or P.n <= 4 end
	for i, box in job.boxes do
		-- the landing: a ring of puffs round the base (8, 4 in a Buy 8), sparkles, the 1.5x ghost
		job:at(P.land[i], function()
			local base = box.home
			local np = P.n >= 5 and 4 or 8
			for kk = 0, np - 1 do
				local a = (kk + 0.5) / np * 2 * PI
				local dir = base:VectorToWorldSpace(V3(math.cos(a), 0, math.sin(a)))
				local o = base.Position + dir * (math.max(box.W, box.D) * 0.42) + base.UpVector * box.topY * 0.08
				job:emit(fx.puff, 1, CFrame.lookAt(o, o + dir))
			end
			job:emit(fx.sparkle, big(i) and 3 or 2, base * CF(0, box.topY * 0.2, -box.D * 0.4))
		end)
		-- the shakes: 1-3 twinkles on the box, sparkles from the seam
		for wi, w in P.wobSpec do
			local t0 = w[1] + P.wobOff[i]
			if t0 < P.pop[i] - 0.1 and (big(i) or wi == #P.wobSpec) then
				local nk = math.min(2, wi)
				for kk = 1, nk do
					job:at(t0 + 0.1 * kk - 0.05, function()
						local at = (box.cf or box.home) * CF((M.hash(wi, kk) - 0.5) * box.W * 0.9, box.topY * (0.35 + 0.6 * M.hash(kk, wi)), -box.D * 0.55)
						job:emit(fx.glint, 1, at)
					end)
				end
				job:at(t0 + w[4] * 0.5, function()
					job:emit(fx.sparkle, math.min(3, wi + (P.multi and 0 or 1)), (box.cf or box.home) * CF(0, box.seamY, -box.D * 0.45))
				end)
			end
		end
		if big(i) and not P.prelude then
			for kk = 1, 3 do
				job:at(P.squeeze[1] + 0.12 * kk, function()
					local at = (box.cf or box.home) * CF((M.hash(kk, 13) - 0.5) * box.W, box.topY * (0.3 + 0.6 * M.hash(13, kk)), -box.D * 0.55)
					job:emit(fx.glint, 1, at)
				end)
			end
		end
		-- the pop: the ring (every rarity, brief 30), and a Legendary's or Mythic's burst, glow and chunks (bigger again
		-- for a Mythic); UnboxFX adds the column, the motes, the shower and the glow puff
		job:at(P.pop[i], function()
			local mouth = (box.cf or box.home) * CF(0, box.seamY, 0)
			local lux = P.ranks[i] >= 4 and P.ranks[i] <= 5
			if big(i) then job:emit(fx.ringBurst, 1, facing(mouth.Position)) end
			if lux then
				job:emit(fx.popBurst, 12 * (i == P.best and job.burst or 1), mouth)
				if big(i) then job:emit(fx.popGlow, 1, facing(mouth.Position)) end
				-- (and a few chunks of the box's colours thrown out and away)
				local th = P.theme
				local H = box.topY
				job:spawn({ kind = 'cube', n = P.n >= 5 and 2 or 5, colors = { th.Color, th.Accent, th.Third }, t0 = P.pop[i], at = mouth, ring = box.W * 0.4, dir = box.home:VectorToWorldSpace(V3(0, 0, 1)), cone = 5,
					hz = { H * 1.2, H * 2.4 }, vz = { H * 2.2, H * 3.4 }, size = box.W * 0.08, grav = H * 9, bounce = 0, spinMin = 4, spinMax = 10, life = 0.8, away = job.away }, 'pop')
			end
		end, (not P.multi) or i == P.best)
	end
	FX.beats(job, X)
	-- the hold's twinkles and the close's trail
	job:at(P.accent[P.best], function() fx.twinkle.Enabled = true; job:recount() end)
	job:at(P.out, function() fx.twinkle.Enabled = false; fx.trail.Enabled = true; job:recount() end, true)
end

---------------------------------------------------------------------------------------------- motion
-- The rig's punch at each impact (the landing, each shake's landing, the pop): down 2 % of the screen's height and back
-- in 0.12 s (the camera never moves).
local function punch(job, i, t)
	local P = job.P
	if P.reduced then return 0 end
	local d = 0
	local amp = 0.02 * job.view.Hvis
	d += M.bump(t, P.land[i], 0.12)
	for _, w in P.wobSpec do d += 0.7 * M.bump(t, w[1] + P.wobOff[i] + w[4], 0.1) end
	d += 0.8 * M.bump(t, P.pop[i], 0.1)
	return -amp * math.min(1, d)
end
-- the low rock between the shakes: from the bounce to the squeeze, 4 -> 8 deg at 2.5 -> 5 Hz (its phase integrated)
local function rock(P, t, t0, t1)
	local R = Themes.World.Rock
	if t < t0 then return 0 end
	local T = math.max(0.1, t1 - t0)
	local tau = math.min(t, t1) - t0
	local f0, f1 = R[3], R[4]
	local phase = 2 * PI * (f0 * tau + (f1 - f0) * tau * tau / (2 * T)) + (t > t1 and 2 * PI * f1 * (t - t1) or 0)
	local amp = M.lerp(R[1], R[2], M.c01(tau / T)) * M.c01((t - t0) / 0.2)
	return RAD(amp) * math.sin(phase)
end
-- Box i at t (O space as built): hidden, dropping, landed, rocking, shaking, squeezing, popped; and its lid.
local function motion(job, i, t)
	local P, box = job.P, job.boxes[i]
	local Wd = Themes.World
	local home = box.home
	local H = box.topY
	local land, ap = P.land[i], P.appear[i]
	local red = P.reduced and 0.5 or 1
	if t < ap then return nil end
	if t < land then
		local u = (t - ap) / (land - ap)
		local sy = 1 + (Wd.Stretch - 1) * M.c01(u / 0.35)
		return home * CF(0, job.fallH * (1 - u * u), 0), 1 / math.sqrt(sy), sy, { open = 0 }
	end
	local tau = t - land
	-- the squash (one frame at 0.8, springing back) and the bounce (+6 % in 0.15 s)
	local sy = tau < P.hs[i] and Wd.Squash or 1 - (1 - Wd.Squash) * M.spring(tau - P.hs[i], 5, 0.45)
	local hop = H * Wd.Bounce[1] * red * M.bump(tau, 0.05, Wd.Bounce[2])
	local roll, yaw = 0, 0
	local pop = P.pop[i]
	local sq0 = P.squeeze[1]
	-- the rock, damped under each shake
	local damp = 1
	local lift, open = 0, 0
	for wi, w in P.wobSpec do
		local t0 = w[1] + P.wobOff[i]
		local q = t - t0
		if q > -0.06 and q < w[4] + 0.12 and t0 < pop - 0.05 then
			damp = math.min(damp, 1 - M.c01(1 - math.abs(q - w[4] * 0.5) / (w[4] * 0.5 + 0.06)))
			local amp = red * (P.multi and (0.85 + 0.3 * M.hash(i, wi + 5)) or 1)
			if q < 0 then
				-- (the crouch before it hops)
				sy *= 1 - 0.06 * math.sin((q + 0.06) / 0.06 * PI / 2)
			elseif q < w[4] then
				-- a hop with a roll L-R-L on the bottom edges (its middle swing the biggest)
				local u = q / w[4]
				local env = math.sqrt(math.sin(u * PI))
				local ph = P.multi and (M.hash(i, 9) > 0.5 and PI or 0) or 0
				roll += RAD(w[2]) * amp * env * math.sin(u * 3 * PI + ph)
				yaw += RAD(w[2] * 0.2) * amp * math.sin(u * PI) * math.sin(u * 2 * PI + ph)
				hop += w[3] * H * amp * math.sin(u * PI)
				sy *= 1 + 0.05 * math.sin(u * PI)
			else
				local v = (q - w[4]) / 0.12
				sy *= 1 - 0.1 * math.sin(v * PI) * red
			end
		end
		-- the lid jolts up as it hops and stays open a crack after, a little wider each shake (brief 30: the seam's light
		-- leaks out of it, UnboxFX)
		if q >= 0 and t < pop then
			local j = (Wd.Jolt[wi] or Wd.Jolt[#Wd.Jolt]) * H * (P.reduced and 0.6 or 1)
			lift = math.max(lift, j * M.bump(q, 0.02, 0.16) + j * 0.22)
			open = math.max(open, (2 + wi) * M.bump(q, 0.02, 0.16) + 2.2 * wi * M.smooth(M.c01(q / 0.16)))
		end
	end
	-- the low rock from the bounce until the squeeze, then at its hardest (10 deg, 6 Hz) through the squeeze
	roll += rock(P, t, land + 0.25, sq0) * damp * red
	if t >= sq0 and t < pop then
		local q = M.c01((t - sq0) / math.max(0.05, P.squeeze[2] - sq0))
		sy *= 1 - (1 - P.squeeze[3]) * q * q
		roll += RAD(10) * red * math.sin((t - sq0) * 2 * PI * 6) * M.c01((t - sq0) / 0.1)
		lift = math.max(lift, H * 0.03 + H * 0.02 * math.sin(t * 2 * PI * 9) * q)
		open = math.max(open, 2.2 * #P.wobSpec + 3 * q + (P.reduced and 0 or 1.5 * math.sin(t * 2 * PI * 9) * q))
	end
	local sx = 1 / math.sqrt(sy)
	local px = (roll > 0 and -1 or 1) * box.W * 0.5
	local cf = home * CF(0, hop, 0) * ANG(0, yaw, 0) * CF(px, 0, 0) * ANG(0, 0, roll) * CF(-px, 0, 0)
	return cf, sx, sy, { lift = lift, open = open }
end
function UnboxWorld.boxAt(job, i, t)
	local P, box = job.P, job.boxes[i]
	local hidden = { hidden = true, park = job.park }
	if P.prelude and P.freeze and t >= P.freeze[1] then
		-- the cue: held at the freeze's first pose, two straight-up hops, then the lift into the tear (only the Secret's
		-- box in a batch)
		local secretBox = (not P.multi) or i == (P.secretAt or P.best)
		if not box.held then
			local cf, sx, sy = motion(job, i, P.reduced and P.freeze[2] + 1 or P.freeze[1])
			box.held = { cf or box.home, sx or 1, sy or 1 }
		end
		local cf, sx, sy = box.held[1], box.held[2], box.held[3]
		if t >= P.freeze[2] then
			cf, sx, sy = box.home, 1, 1
			if not P.reduced then
				for _, h in P.hops do
					local q = (t - h) / 0.1
					if q >= 0 and q < 1 then cf = cf * CF(0, 0.12 * box.topY * math.sin(q * PI), 0) end
				end
			end
		end
		if secretBox and t >= P.lift and job.tearCF then
			local q = t - P.lift
			local s = 1 - M.c01((q - 0.2) / 0.25)
			if s <= 0.02 then return job.park, 1, 1, hidden end
			local from = box.home.Position
			local to = job.tearCF.Position
			local pos = from:Lerp(to, M.inn(M.c01(q / 0.45), 2))
			cf = box.home.Rotation + pos
			sx, sy = s, s
		end
		return cf, sx, sy, { open = 0 }
	end
	local cf, sx, sy, lid = motion(job, i, t)
	if not cf then return job.park, 1, 1, hidden end
	local up = box.home.UpVector
	cf = cf + up * punch(job, i, t)
	local pop = P.pop[i]
	if t >= pop then
		-- (brief 30) one move, no cut: the lid swings open on its hinge from the crack it had, like the user's open chests
		-- (Back Out to Swing[1] deg in Swing[2] s); the pair rises out of it (pairAt) while the open chest sinks away under
		-- it, Quad In from Rise.sinkFrom over Rise.sinkLen s, shrinking about its middle and fading (a row's sinks less
		-- and fades sooner, clear of the row below)
		local q = t - pop
		local Wd = Themes.World
		local R = Wd.Rise
		local sw = Wd.Swing or { 112, 0.32 }
		local row = P.multi
		local d = M.inn(M.c01((q - R.sinkFrom) / R.sinkLen), 2)
		if q >= R.sinkFrom + R.sinkLen then return job.park, 1, 1, { hidden = true, park = job.park } end
		local k = M.lerp(1, row and R.shrinkRow or R.shrink, d)
		cf = cf * CF(0, -box.fullH * (row and R.sinkRow or R.sink) * d + box.fullH * 0.5 * (1 - k), 0)
		sx, sy = sx * k, sy * k
		local fadeFrom = row and R.fadeFromRow or R.fadeFrom
		local fade = M.smooth(M.c01((q - fadeFrom) / (R.sinkFrom + R.sinkLen - fadeFrom)))
		local open0 = 2.2 * #P.wobSpec + 3
		local ang = open0 + (sw[1] - open0) * M.back(q / sw[2], P.reduced and 0 or 1.25)
		local hr = box.hingeRel
		local hp = hr.Position
		local lift = box.topY * 0.03 * (1 - M.c01(q / 0.1))
		local hinge = cf * CF(hp.X * sx, hp.Y * sy + lift, hp.Z * sx) * hr.Rotation
		return cf, sx, sy, { fly = hinge * ANG(RAD(ang), 0, 0), scale = 1, fade = fade }
	end
	-- (the lid: hinged at its back edge, lifted by the jolts)
	local hr = box.hingeRel
	local hp = hr.Position
	local hinge = cf * CF(hp.X * sx, hp.Y * sy + (lid.lift or 0), hp.Z * sx) * hr.Rotation
	return cf, sx, sy, { fly = hinge * ANG(RAD(lid.open or 0), 0, 0), scale = 1 }
end

-- The pair i (brief 30): rises out of its open chest through the column of light, from inside it (Rise.from box
-- heights under its final middle, 6 % of its size) up past the rim to the top of its rise (Rise.apex above, Out
-- Cubic), growing as it goes (small while it clears the rim, 1.1x at Rise.apexAt), then settles down into its place,
-- 1x (a sine ease) by Rise.len, while the chest sinks away under it; spinning down from a fast turn (1 turn through the rise; a Legendary's or Mythic's 2 / 2.5) into the steady 90
-- deg/s, which takes over without a jolt; bobbing 3 % at 0.5 Hz once settled. Reduced Motion: no spin, no overshoot.
-- At the close it flies into the inventory button, shrinking.
function UnboxWorld.pairAt(job, i, t)
	local P = job.P
	local pair, box = job.pairs[i], job.boxes[i]
	local Wd = Themes.World
	local R = Wd.Rise
	if t < P.rise[i] then return nil end
	local tr = t - P.rise[i]
	local fit = job.pairFit and job.pairFit[i] or 1
	local centre = job:wp(job.slots[i])
	local L = P.riseLen or R.len
	local apex, over = R.apex, R.over
	if P.reduced then apex, over = 0.08, 1 end
	local y, s
	if tr < R.apexAt then
		local u = tr / R.apexAt
		y = M.lerp(R.from, apex, M.out(u, 3))
		s = M.lerp(R.scale0, over, u ^ (R.grow or 1.25))
	else
		local u = M.sineInOut((tr - R.apexAt) / math.max(0.05, L - R.apexAt))
		y = apex * (1 - u)
		s = M.lerp(over, 1, u)
	end
	centre += box.home.UpVector * y * box.fullH
	-- the spin: n turns that slow to nothing by L (Out Cubic), plus the idle turn ramping in over the second half
	local turn = RAD(Wd.Idle[1])
	local spin = i == P.best and P.spinBest
	local turns = P.reduced and 0 or (spin and spin[2] or 1)
	local r0, r1 = L * 0.5, L
	local ramp = tr <= r0 and 0 or (tr < r1 and (tr - r0) ^ 2 / (2 * (r1 - r0)) or (r1 - r0) / 2 + (tr - r1))
	local yaw = RAD(-25) - 2 * PI * turns * (1 - M.out(tr / L, 3)) + turn * ramp
	local idle = math.max(0, tr - L)
	local ease = M.smooth(M.c01(idle / 0.4))
	centre += box.home.UpVector * math.sin(idle * 2 * PI * Wd.Idle[3]) * Wd.Idle[2] * job.pairH * ease
	-- (a row's best, Legendary or better, steps up 20 % as it lands)
	if P.multi and i == P.best and P.spinBest then s *= 1 + 0.2 * M.back(M.c01((t - P.accent[i] + 0.25) / 0.3), 1.6) end
	-- the close: along a short arc into the button, shrinking to 15 % (Quad In), a row's pairs 40 ms apart
	if t >= P.out then
		local stagger = P.multi and ((i - 1) * 0.04) or 0
		local len = job.closeLen or P.closeLen
		local q = M.c01((t - P.out - stagger) / math.max(0.1, len - (P.multi and 0.04 * (P.n - 1) or 0)))
		if q >= 1 then return nil end
		local to = job.closeAt or centre
		local e = q * q
		local arc = box.home.UpVector * job.view.Hvis * 0.12 * math.sin(q * PI)
		centre = centre:Lerp(to, e) + arc
		s *= M.lerp(1, 0.15, e)
		yaw += RAD(360) * e
	end
	local S = s * fit
	local rot = box.home.Rotation * ANG(RAD(-8), 0, 0) * ANG(0, yaw, 0)
	pair.pos = centre
	local mid = pair.mid or V3(0, pair.base + pair.height * 0.5, 0)
	return CF(centre) * rot * CF(-mid * S), S
end

---------------------------------------------------------------------------------------------- per frame
-- The seam's light (the only colour on the box before the pop): a faint white line from the first shake (brief 30),
-- then in the honest colour, one rarity a shake up to the true one (shake 2 Rare, 3 Epic, 4 Legendary, the squeeze the
-- true one), growing; the theme's own light in a Secret's cue; out at the pop (the column takes over).
local function seam(job, i, t)
	local P, box = job.P, job.boxes[i]
	local r = box.rank
	local show = 0
	for kk, w in P.wobSpec do
		if t >= w[1] + P.wobOff[i] then show = kk end
	end
	local a = 0
	if show >= 1 and t < P.pop[i] + 0.1 then
		a = show == 1 and 0.22 or math.min(1, 0.35 + 0.25 * (show - 2))
		if t >= P.squeeze[1] then a = 1 end
		if t >= P.pop[i] then a = 1 - (t - P.pop[i]) / 0.1 end
	end
	local step = math.min(r, math.max(1, show))
	if t >= P.squeeze[1] then step = r end
	local col = step <= 1 and WHITE or X.rarityColor(step)
	if P.cue and t >= P.cue then
		a, col = (P.lift and t >= P.lift + 0.1) and 0 or 0.55, P.theme.Color:Lerp(WHITE, 0.35)
	end
	box.teaseColor = col
	if a > 0.02 and box.cf then
		box.seam.CFrame = box.cf * CF(0, box.seamY + 0.02 * box.s, 0)
		box.seam.Transparency = M.lerp(0.7, 0, M.c01(a))
		if box.seam.Color ~= col then box.seam.Color = col end
	elseif box.seam.Transparency < 1 then
		box.seam.Transparency = 1
		box.seam.CFrame = job.park
	end
	return a
end
local function sealStage(P, i, t)
	local k = 0
	for kk, w in P.wobSpec do
		if t >= w[1] + P.wobOff[i] + w[4] * 0.4 then k = kk end
	end
	-- (a Legendary's four shakes: the tear starts on the second)
	if #P.wobSpec >= 4 then k = math.max(0, k - 1) end
	if t >= P.squeeze[1] then k = 3 end
	if P.prelude then k = math.min(k, 1) end
	return math.min(k, 3)
end
-- the ghost shell: 1.5x at the landing (fading in 0.15 s), 1.12x at each shake (35 % opacity, 0.2 s); none with
-- Reduced Motion
local function ghostAt(job, i, t)
	local P, box = job.P, job.boxes[i]
	local G = Themes.World.Ghost
	if not box.ghost or P.reduced then return end
	local a, g = 0, 1
	local q = t - P.land[i]
	if q >= 0 and q < 0.15 then a, g = 1 - q / 0.15, G[1] end
	for _, w in P.wobSpec do
		local qq = t - (w[1] + P.wobOff[i])
		if qq >= 0 and qq < G[4] and w[1] + P.wobOff[i] < P.pop[i] then a, g = 1 - qq / G[4], G[2] end
	end
	if a > 0.01 and box.cf then
		local hc = box.fullH * 0.5
		box.ghost:pose(box.cf * CF(0, -(g - 1) * hc, 0), g)
		local tr = 1 - G[3] * a
		for _, p in box.ghost.parts do
			if math.abs(p.Transparency - tr) > 1e-3 then p.Transparency = tr end
		end
		box.ghostOn = true
	elseif box.ghostOn then
		box.ghostOn = false
		for _, p in box.ghost.parts do p.Transparency = 1 end
		box.ghost:pose(job.park, 1)
	end
end

-- The close's target: the inventory button (opts.closeTarget: a function giving its centre in viewport pixels), else
-- the HUD's left column, carried to the rig's depth.
function UnboxWorld.closePoint(job)
	local view = job.view
	local px = nil
	if type(job.closeTarget) == 'function' then
		local ok, v = pcall(job.closeTarget)
		if ok and typeof(v) == 'Vector2' then px = v end
	end
	px = px or Vector2.new(view.size.X * 0.06, view.size.Y * 0.5)
	local u = px.X / view.size.X * 2 - 1
	local v = 1 - px.Y / view.size.Y * 2
	local cam = job.camBase
	return cam.Position + cam:VectorToWorldSpace(V3(u * view.tx, v * view.ty, -1)) * view.D
end

-- The held camera (a Secret's prelude tilts it up 24 deg at the cut, Quart Out 0.17 s).
function UnboxWorld.cam(job, t)
	local P = job.P
	local cf = job.camBase
	if P.prelude and P.cutAt and t >= P.cutAt then
		local q = 1 - (1 - M.c01((t - P.cutAt) / 0.17)) ^ 4
		cf = cf * ANG(RAD(24) * q, 0, 0)
	end
	return cf, job.fov
end

function UnboxWorld.frame(job, t)
	local P = job.P
	X.Look.apply(job, t)
	local cam = workspace.CurrentCamera
	if cam and t < P.done then
		local cf, fov = UnboxWorld.cam(job, t)
		if cam.CameraType ~= Enum.CameraType.Scriptable then cam.CameraType = Enum.CameraType.Scriptable end
		cam.CFrame = cf
		if cam.FieldOfView ~= fov then cam.FieldOfView = fov end
		pcall(function() cam.Focus = job.focus end)
		job.camCF = cf
	end
	if t >= P.out and not job.closeAt then
		job.closeAt = UnboxWorld.closePoint(job)
		-- (the HUD comes back as the pair flies into it)
		if job.onClose and not P.prelude then task.spawn(job.onClose, job) end
	end
	local bright = 0
	for i, box in job.boxes do
		local cf, sx, sy, lid = UnboxWorld.boxAt(job, i, t)
		X.Box.pose(box, cf, sx, sy, lid)
		box.visible = not lid.hidden
		-- (brief 30: the open chest fades as it sinks away; written only on change)
		local fade = lid.fade or 0
		if box.fadeA ~= fade and not lid.hidden then
			box.fadeA = fade
			box.body:fade(fade)
			box.lid:fade(fade)
		end
		bright = math.max(bright, seam(job, i, t))
		setSeal(box, sealStage(P, i, t))
		ghostAt(job, i, t)
		if box.rb and t >= P.appear[i] - 0.05 and t < P.pop[i] + 0.35 then X.Box.rainbow(box, t) end
		for _, e in { box.stars, box.aura } do
			local on = t >= P.appear[i] and t < P.pop[i]
			if e.Enabled ~= on then e.Enabled = on; job:recount() end
		end
		if box.mring then
			local on = t >= P.appear[i] and t < P.pop[i]
			local rc = (box.cf or box.home) * CF(0, box.topY * 0.42, 0) * ANG(RAD(-14), 0, RAD(8))
			box.mring:pose(rc, box.W * 0.82, on and 1 or 0, t * 2.4, 1)
		end
	end
	local recount = false
	for i, pair in job.pairs do
		local cf, s = UnboxWorld.pairAt(job, i, t)
		if cf then
			pair.actor:pose(cf, s)
			local on = t >= P.accent[i] - 0.3 and t < P.out
			if pair.fxOn ~= on then
				X.Pair.fx(pair, on)
				recount = true
				-- (its glow goes with it at the close, not left hanging where it was)
				if not on then
					for _, d in pair.fxList do
						if d:IsA('ParticleEmitter') then pcall(function() d:Clear() end) end
					end
				end
			end
		else
			pair.actor:pose(job.park, 0.3)
			if pair.fxOn then X.Pair.fx(pair, false); recount = true end
		end
	end
	if recount then job:recount() end
	job.bits:step(t)
	FX.frame(job, t)
	UnboxWorld.effectsAt(job, t, bright)
	for _, fn in job.updaters do fn(t) end
	UnboxWorld.wordsUpdate(job, t)
	job.peak = math.max(job.peak or 0, job:live(t))
end

function UnboxWorld.effectsAt(job, t, bright)
	local P = job.P
	local acf = job.anchor.CFrame:Inverse()
	local cam = job.camCF or job.camBase
	local bb = job.boxes[P.best]
	-- the box's light: the seam's colour as it charges, a burst at the pop
	local glow = 0
	for i = 1, P.n do glow = math.max(glow, M.bump(t, P.pop[i] - 0.02, 0.35)) end
	job.boxLight.Brightness = bright * 1.2 + glow * 2
	job.boxLight.Color = bb.teaseColor or WHITE
	job.boxGlow.CFrame = (bb.cf or bb.home) * CF(0, bb.seamY + 0.5 * bb.s, -bb.D * 0.7)
	-- Legendary / Mythic ring bursts: racing out from the box to ~2.6 box widths in 0.3 s, 70 ms apart
	for kk, r in job.burstRings or {} do
		local q = (t - P.pop[P.best] - (kk - 1) * 0.07) / 0.32
		if P.rank >= 5 and t >= P.accent[P.best] then q = (t - P.accent[P.best] - (kk - 1) * 0.09) / 0.4 end
		if q >= 0 and q <= 1 and cam then
			local c = (P.rank >= 5 and t >= P.accent[P.best] and job.pairs[P.best].pos) or (bb.home * CF(0, bb.fullH * 0.5, 0)).Position
			local rcf = CFrame.fromMatrix(c, cam.RightVector, -cam.LookVector)
			r:pose(rcf, M.lerp(bb.W * 0.4, bb.W * (2.4 + 0.3 * kk), M.out(q, 3)), (1 - q) ^ 1.3, 0, M.lerp(1.3, 0.5, q))
			r.off = false
		elseif not r.off then
			r.off = true
			r:pose(bb.home, 0, 0, 0)
		end
	end
	-- the rays behind the best pair, as the reference breathes them: from just after the wash, in over 1 s, held 0.5 s,
	-- then breathing between a core of ~0.3 and the peak (3 s), never gone while the pair shows; barely turning (4 deg/s)
	local pair = job.pairs[P.best]
	local R = Themes.World.Rays
	local a = 0
	if pair.pos and cam then
		local q = t - P.pop[P.best] - R.from
		if q >= 0 then
			local c = R.cycle
			if q < c[1] then a = M.smooth(q / c[1])
			elseif q < c[1] + c[2] then a = 1
			else
				local low = R.low / R.core
				a = M.lerp(low, 1, 0.5 + 0.5 * math.cos((q - c[1] - c[2]) * 2 * PI / R.period))
			end
		end
		a *= 1 - M.c01((t - P.out) / 0.15)
	end
	if a > 0.01 then
		local fit = job.pairFit and job.pairFit[P.best] or 1
		local ph = pair.height * fit * ((P.multi and P.spinBest) and 1.2 or 1)
		local size = (P.rank == 5 and R.mythic) or (P.rank == 4 and R.lux) or 1
		local reach = R.reach * ph * size * (0.92 + 0.08 * a)
		local c = pair.pos + (pair.pos - cam.Position).Unit * (pair.depth * fit * 0.6 + 0.05 * job.view.D)
		job.rayHub.CFrame = acf * CF(c)
		local peakAt = R.peak / R.reach
		local tr = nseq({ { 0, 1 }, { 0.32, 1 }, { peakAt, 1 - R.core * a }, { 1, 1 } })
		for kk, r in job.rays do
			local ang = (kk - 1) / #job.rays * 2 * PI + RAD(R.turn) * t + (r.j - 0.5) * 0.08
			r.tip.CFrame = acf * CF(c + (cam.RightVector * math.cos(ang) + cam.UpVector * math.sin(ang)) * reach * (0.9 + 0.2 * r.j))
			r.beam.Transparency = tr
			r.beam.Width0, r.beam.Width1 = 0.03 * ph * size, 0.46 * ph * size
			if not r.beam.Enabled then r.beam.Enabled = true end
		end
	else
		for _, r in job.rays do
			if r.beam.Enabled then r.beam.Enabled = false end
		end
	end
	-- the soft glow behind the pair, from the pop to the close
	if job.glowHost then
		local on = pair.pos ~= nil and cam ~= nil and t >= P.pop[P.best] + 0.2 and t < P.out
		if on then
			local fit = job.pairFit and job.pairFit[P.best] or 1
			job.glowHost.CFrame = CF(pair.pos + (pair.pos - cam.Position).Unit * (pair.depth * fit * 0.7 + 0.05 * job.view.D))
			if not job.glowSized then
				job.glowSized = true
				job.fx.backGlow.Size = NumberSequence.new(pair.height * fit * 1.9)
			end
		end
		if job.fx.backGlow.Enabled ~= on then
			job.fx.backGlow.Enabled = on
			if not on then pcall(function() job.fx.backGlow:Clear() end) end
			job:recount()
		end
	end
	-- the hold's twinkles ride a volume round the best pair; the trail follows it into the button
	if pair.pos then
		local fit = job.pairFit and job.pairFit[P.best] or 1
		job.twinkleHost.Size = V3(pair.width * fit * 1.3, pair.height * fit * 1.6, 0.2)
		job.twinkleHost.CFrame = CFrame.lookAt(pair.pos, pair.pos + (pair.pos - cam.Position))
		job.trailHost.CFrame = CF(pair.pos)
	end
	-- a Secret's prelude: the tear opens as the box lifts into it
	if job.tearParts then
		local open = P.tear and M.out(M.c01((t - P.tear) / 0.15), 3) or 0
		local pulse = 1 + 0.15 * math.sin(t * 3 * 2 * PI)
		if job.tearGlow then
			local on = open > 0.05
			if on and not job.tearGlowOn then job.tearGlowOn = true; job:emit(job.tearGlow, 1) end
			if not on and job.tearGlowOn then job.tearGlowOn = false; pcall(function() job.tearGlow:Clear() end) end
			if on then job.tearGlow.Size = NumberSequence.new(3 * job.tearUnit * open * pulse) end
		end
		for _, e in job.tearParts do
			local p = e[1]
			if open > 0.01 then
				p.CFrame = job.tearCF * CF(e[2].Position * V3(open, 1, 1)) * e[2].Rotation
				local sc = p.Name == 'TearGlow' and pulse or 1
				if not e.size then e.size = p.Size end
				p.Size = V3(e.size.X * open * sc, e.size.Y * sc, e.size.Z)
			elseif p.CFrame ~= job.park then
				p.CFrame = job.park
			end
		end
	end
end

---------------------------------------------------------------------------------------------- the words
-- The reference's two centred lines and ours: the name (Fonts.Title, cap 3.5 % of the height, 66 % down), the rarity and
-- "1 in N" in the rarity's colour (2.4 %, 71 %) with NEW!, "Tap anywhere to close!" (2.4 %, 77 %); no Power number (the
-- user). They scale in together under the wash (Back Out 0.35 s, 0.4 -> 1.08 -> 1) and shrink out in 0.1 s at the close.
-- A light vignette; the wash; a Buy 3 / Buy 8's tags under the pairs.
function UnboxWorld.words(job)
	local P = job.P
	local root = job.gui and (job.gui:FindFirstChild('Root') or job.gui)
	local stage = X.frame(root, 'Unboxed', { Size = UDim2.fromScale(1, 1), ZIndex = 1 })
	job.stageGui = stage
	local W = { scales = {} }
	job.words = W
	local rank = P.rank
	local rcol = X.rarityColor(rank)
	-- the light vignette: the four edges about 7 % darker (the corners about 13 %; the world's mean luma within -5 %)
	W.vig = {}
	for _, e in { { Vector2.zero, UDim2.fromOffset(-140, -140), UDim2.new(1, 280, 0.2, 140), 90 }, { Vector2.new(0, 1), UDim2.new(0, -140, 1, 140), UDim2.new(1, 280, 0.2, 140), -90 },
		{ Vector2.zero, UDim2.fromOffset(-140, -140), UDim2.new(0.14, 140, 1, 280), 0 }, { Vector2.new(1, 0), UDim2.new(1, 140, 0, -140), UDim2.new(0.14, 140, 1, 280), 180 } } do
		local f = X.frame(stage, 'Vignette', { AnchorPoint = e[1], Position = e[2], Size = e[3], BackgroundColor3 = C3(0, 0, 0), ZIndex = 2 })
		local g = Instance.new('UIGradient')
		g.Rotation = e[4]
		g.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.45, 0), NumberSequenceKeypoint.new(1, 1) })
		g.Parent = f
		table.insert(W.vig, f)
	end
	W.flash = X.frame(stage, 'Flash', { Position = UDim2.fromOffset(-140, -140), Size = UDim2.new(1, 280, 1, 280), ZIndex = 40 })
	W.flashColor = WHITE
	local btn = Instance.new('TextButton')
	btn.Name = 'Skip'
	btn.Text = ''
	btn.AutoButtonColor = false
	btn.BackgroundTransparency = 1
	btn.Size = UDim2.fromScale(1, 1)
	btn.ZIndex = 50
	btn.Parent = stage
	W.skip = btn
	pcall(function() table.insert(job.conns, btn.Activated:Connect(function() job:skip() end)) end)
	if P.prelude then return end
	local best = P.list[P.best]
	local sd = X.shoeDef(best.Shoe)
	-- (brief 30, the user: "make it smooth ... just show the shoe, and then say at the bottom, click anywhere to
	-- continue": no card; each line fades and slides up into place, staggered, and eases back out at the close)
	W.home = {}
	local function scaled(l)
		local sc = Instance.new('UIScale')
		sc.Scale = 1
		sc.Parent = l
		W.scales[l] = sc
		W.home[l] = l.Position
		X.fadeText(l, 0)
		return l
	end
	W.name = scaled(X.label(stage, { Name = 'Name', Text = sd and sd.Name or tostring(best.Shoe), TextSize = 36, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.66), Size = UDim2.new(1, 0, 0, 46), ZIndex = 32 }))
	local rname = string.upper(X.rarityRow(rank).Name or 'Common')
	local ct = X.oneIn(P.chance)
	local lineText = ct and (rname .. '  ·  ' .. ct) or rname
	W.line = scaled(X.label(stage, { Name = 'Rarity', Role = 'heading', Text = lineText, TextSize = 24, TextColor3 = rank <= 1 and C3(226, 230, 238) or rcol:Lerp(WHITE, 0.12), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.71), Size = UDim2.new(1, 0, 0, 32), ZIndex = 32 }))
	if best.New then
		local wordW = #lineText * 24 * 0.6
		pcall(function()
			local ts = game:GetService('TextService')
			local v = ts:GetTextSize(lineText, 24, Enum.Font.GothamBlack, Vector2.new(2000, 200))
			if v.X > 0 then wordW = v.X end
		end)
		W.new = scaled(X.label(stage, { Name = 'New', Role = 'heading', Text = 'NEW!', TextSize = 22, TextColor3 = C3(124, 255, 79), AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0.5, wordW * 0.5 + 12, 0.71, -2), Size = UDim2.fromOffset(80, 28), TextXAlignment = Enum.TextXAlignment.Left, Rotation = -8, ZIndex = 33 }))
	end
	W.tap = scaled(X.label(stage, { Name = 'Tap', Role = 'heading', Text = 'Click anywhere to continue', TextSize = 24, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.77), Size = UDim2.new(1, 0, 0, 32), ZIndex = 32 }))
	-- a row's tags under the other pairs (the rarity word, NEW!), sized from the slot
	W.tags = {}
	if P.multi then
		for i, pair in job.pairs do
			if i ~= P.best then
				local r = pair.rank
				local bb = Instance.new('BillboardGui')
				bb.Name = 'PairTag'
				local wv = job.pairW * 1.1
				bb.Size = UDim2.fromScale(wv, wv * 0.3)
				bb.AlwaysOnTop = true
				bb.LightInfluence = 0
				bb.Enabled = false
				local l = X.label(bb, { Name = 'Tag', Role = 'heading', Text = string.upper(X.rarityRow(r).Name or ''), TextSize = 24, StrokeThickness = 3, Size = UDim2.fromScale(1, 0.62), ZIndex = 2 })
				l.TextScaled = true
				X.fadeText(l, 1)
				if r <= 1 then X.gradient(l, { WHITE, C3(214, 220, 230) }, 90) else X.gradient(l, { WHITE, X.rarityColor(r) }, 90) end
				if pair.entry.New then
					local nw = X.label(bb, { Name = 'New', Role = 'heading', Text = 'NEW!', TextSize = 18, StrokeThickness = 2.5, TextColor3 = C3(124, 255, 79), Position = UDim2.fromScale(0, 0.6), Size = UDim2.fromScale(1, 0.4), ZIndex = 2 })
					nw.TextScaled = true
					X.fadeText(nw, 1)
				end
				local host = Make.part(job.folder, 'TagHost', V3(0.1, 0.1, 0.1), job.park, WHITE, nil, { Transparency = 1 })
				bb.Adornee = host
				bb.Parent = host
				W.tags[i] = { bb = bb, host = host }
			end
		end
	end
end
function UnboxWorld.wordsUpdate(job, t)
	local P, W = job.P, job.words
	if not W then return end
	-- the wash: a 1-frame rise, held one frame, Quad Out
	local fa = 0
	for _, list in { P.flashes, P.soft } do
		for _, f in list do
			local tau = t - f[1]
			if tau >= 0 and tau < f[3] then
				local a = tau < (f[4] or 0) and 1 or (1 - M.c01((tau - (f[4] or 0)) / (f[3] - (f[4] or 0)))) ^ 2
				fa = math.max(fa, f[2] * a)
			end
		end
	end
	if W.flash.BackgroundColor3 ~= W.flashColor then W.flash.BackgroundColor3 = W.flashColor end
	if fa >= 0.3 then require(Shared:WaitForChild('FlashGate')).note('unbox') end -- (the hits and gates wait a second after it)
	local ft = 1 - M.c01(fa)
	if W.flash.BackgroundTransparency ~= ft then W.flash.BackgroundTransparency = ft end
	-- the vignette: in with the HUD going (0.3 s), out with the close
	local va = M.c01(t / 0.3) * (1 - M.c01((t - P.out) / 0.3))
	for _, f in W.vig do
		local tr = 1 - 0.07 * va
		if math.abs(f.BackgroundTransparency - tr) > 1e-3 then f.BackgroundTransparency = tr end
	end
	if P.prelude or not W.name then return end
	-- each line: in over 0.35 s (Quint Out: it fades in and slides up 22 px into place, a touch of Back on its scale),
	-- staggered (the name, the rarity 0.08 s later, NEW! 0.16 s, the prompt 0.4 s after the name, which then breathes);
	-- out over 0.25 s at the close (fading, sliding down)
	local closeQ = M.c01((t - P.out) / 0.25)
	local function quint(u) u = M.c01(u) return 1 - (1 - u) ^ 5 end
	local function glide(l, at, breathe)
		if not l then return end
		local u = (t - at) / 0.35
		local a = quint(u) * (1 - quint(closeQ))
		local dy = 22 * (1 - quint(u)) + 14 * M.inn(closeQ, 2)
		local s = u <= 0 and 0.94 or (0.94 + 0.06 * M.back(u, 1.4))
		if breathe and u >= 1 and closeQ <= 0 then
			local b = 0.5 + 0.5 * math.sin((t - at - 0.35) * 2 * PI * 0.8)
			s *= 1 + 0.035 * b
			a *= 0.78 + 0.22 * b
		end
		local sc = W.scales[l]
		if sc and math.abs(sc.Scale - s) > 1e-4 then sc.Scale = s end
		local h = W.home[l]
		if h then
			local pos = UDim2.new(h.X.Scale, h.X.Offset, h.Y.Scale, h.Y.Offset + dy)
			if l.Position ~= pos then l.Position = pos end
		end
		X.fadeText(l, a)
	end
	glide(W.name, P.nameT)
	glide(W.line, P.nameT + 0.08)
	glide(W.tap, P.tap, true)
	if W.new then
		glide(W.new, P.newT)
		W.new.Rotation = -8
	end
	-- a row's tags: under each pair from its reveal
	for i, tg in W.tags or {} do
		local pair = job.pairs[i]
		local on = t >= P.accent[i] and t < P.out and pair.pos ~= nil
		if tg.bb.Enabled ~= on then tg.bb.Enabled = on end
		if on then
			local fit = job.pairFit and job.pairFit[i] or 1
			tg.host.CFrame = CF(pair.pos - job.boxes[i].home.UpVector * (pair.height * fit * 0.5 + job.pairW * 0.18))
			for _, l in tg.bb:GetChildren() do
				if l:IsA('TextLabel') then X.fadeText(l, M.c01((t - P.accent[i]) / 0.15)) end
			end
		end
	end
	job.stageGui:SetAttribute('T', t)
end

return UnboxWorld
