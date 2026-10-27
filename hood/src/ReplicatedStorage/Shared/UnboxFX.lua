-- UnboxFX (brief 30, the user: "make the opening animation better, add some vfx to it, make it more smooth ... smoothly
-- with vfx and graphics like other games"): the in-world opening's light and particles that carry the box into the
-- shoes as one continuous move. UnboxWorld builds the rig and moves the box and the pair; this adds, per box:
--   the drop      a flat shockwave ring where it lands (with UnboxWorld's dust puff, sparkles and 1.5x ghost);
--   the build-up  rays of light leaking from the lid's crack, longer at each shake, in the seam's honest colour (white,
--                 then one rarity a shake up to the true one); a soft pool of light under the box that grows with them;
--   the burst     a column of the rarity's light rising out of the open chest (a hot core and a soft sheath, beams), motes
--                 streaming up it, a sparkle shower thrown up and falling outward, the ring, a soft glow puff;
--   the reveal    confetti from the top of the view in two side bands (Epic and up; Legendary and Mythic more).
-- Everything fades in and out (no element pops), sized from the box so it follows the rig's scale. Bursts go through
-- job:emit (the opening's particle cap); one continuous emitter a box (the light pool, ~2 live). Reduced Motion: no
-- flicker, half the sparks and motes, no confetti.
-- Budget (a single, Mythic): pool 2 live + shower 30 + motes 16 + ring 1 + glow 1 + land ring 1; 7 leak beams and
-- 2 column beams a box (a Buy 3's 4 + 2, a Buy 8's 2 + 2).
local UnboxFX = {}

local Shared = script.Parent
local Themes = require(Shared:WaitForChild('UnboxThemes'))
local Kit = require(Shared:WaitForChild('UnboxKit'))
local M, Make = Kit.M, Kit.Make
local seqOf, nseq = Kit.seq, Kit.nseq
local V3, CF = Vector3.new, CFrame.new
local NR = NumberRange.new
local WHITE = Color3.new(1, 1, 1)

local function F() return Themes.World.FX end

-- the leak's level at t: 0 none, 1-3 after each shake, 4 through the squeeze; 0 again from the pop
function UnboxFX.level(P, i, t)
	if t >= P.pop[i] then return 0 end
	local k = 0
	for kk, w in P.wobSpec do
		if t >= w[1] + P.wobOff[i] + w[4] * 0.3 then k = math.min(3, kk) end
	end
	if not P.prelude and t >= P.squeeze[1] then k = 4 end
	return k
end

function UnboxFX.build(job, X)
	local P = job.P
	local fx = job.fx
	local Fx = F()
	local nLeak = P.n == 1 and Fx.Leak.n or (P.n <= 4 and 4 or 2)
	for _, box in job.boxes do
		local W = box.W
		-- the leak: thin rays fanning out of the crack's front edge
		box.leaks = {}
		for j = 1, nLeak do
			local a0 = Make.attach(job.anchor, 'LeakA' .. box.i .. '_' .. j)
			local a1 = Make.attach(job.anchor, 'LeakB' .. box.i .. '_' .. j)
			local b = Make.beam(job.anchor, a0, a1, WHITE, 0.03 * W, Fx.Leak.width * W, NumberSequence.new(1), 1, { Segments = 1, Tex = 'shaft' })
			b.Name = 'Leak'
			b.Enabled = false
			local u = nLeak == 1 and 0 or (j - 1) / (nLeak - 1) * 2 - 1
			table.insert(box.leaks, { a0 = a0, a1 = a1, beam = b, u = u, h = M.hash(box.i * 7 + j, 3) })
		end
		-- the pool of light under the box (one flat glow, locked to a host that rides the box's base)
		box.poolHost = Make.part(job.folder, 'LightPool', V3(0.2, 0.2, 0.2), job.park, WHITE, nil, { Transparency = 1 })
		box.pool = job:emitter('LightPool', 'glow', seqOf({ WHITE, WHITE }), {
			life = { 0.55, 0.55 }, speed = { 0.01, 0.01 }, spread = Vector2.zero, rate = 4, direction = Enum.NormalId.Top,
			orientation = Enum.ParticleOrientation.VelocityPerpendicular, rotation = NR(0, 360), rotSpeed = NR(-20, 20),
			emission = 1, lightInfluence = 0, size = NumberSequence.new(W), transparency = nseq({ { 0, 1 }, { 0.3, 0.7 }, { 0.7, 0.7 }, { 1, 1 } }), zoffset = -0.5,
		}, box.poolHost)
		box.pool.LockedToPart = true
		box.poolLevel = -1
		-- the column of light out of the open chest: a hot core in a soft sheath (beams facing the camera)
		local rc = X.rarityColor(box.rank)
		local cA = Make.attach(job.anchor, 'ColumnA' .. box.i)
		local cB = Make.attach(job.anchor, 'ColumnB' .. box.i)
		local soft = Make.beam(job.anchor, cA, cB, seqOf({ rc, rc:Lerp(WHITE, 0.3) }), W * Fx.Column.soft, W * Fx.Column.soft * 0.8, NumberSequence.new(1), 1, { Segments = 1, Tex = 'shaft' })
		local core = Make.beam(job.anchor, cA, cB, seqOf({ rc:Lerp(WHITE, 0.65), WHITE }), W * Fx.Column.core, W * Fx.Column.core * 0.6, NumberSequence.new(1), 1, { Segments = 1, Tex = 'shaft' })
		soft.Name, core.Name = 'ColumnSoft', 'ColumnCore'
		soft.Enabled, core.Enabled = false, false
		box.column = { a = cA, b = cB, soft = soft, core = core, alpha = -1 }
	end
	local W0 = job.boxes[P.best].W
	local H0 = job.boxes[P.best].fullH
	local rcol = X.rarityColor(P.rank)
	-- the landing's shockwave: a flat ring racing out round the base
	fx.landRing = job:emitter('LandRing', 'ring', seqOf({ WHITE, P.theme.Color:Lerp(WHITE, 0.5) }), {
		life = { 0.32, 0.32 }, speed = { 0.01, 0.01 }, spread = Vector2.zero, direction = Enum.NormalId.Top,
		orientation = Enum.ParticleOrientation.VelocityPerpendicular, rotation = NR(0, 360), rotSpeed = NR(0),
		size = nseq({ { 0, W0 * 0.45 }, { 0.5, W0 * 1.25 }, { 1, W0 * 1.5 } }), transparency = nseq({ { 0, 0.25 }, { 0.6, 0.55 }, { 1, 1 } }),
		emission = 1, lightInfluence = 0, zoffset = 0.5,
	})
	-- the burst: sparkles thrown up out of the chest that fall outward (a shower), and motes streaming up the column
	fx.shower = job:emitter('Shower', 'spark', seqOf({ WHITE, rcol:Lerp(WHITE, 0.2) }), {
		life = { 0.6, 0.95 }, speed = { H0 * 1.6, H0 * 3.0 }, drag = 1.6, accel = V3(0, -H0 * 4.5, 0), spread = Vector2.new(55, 55),
		direction = Enum.NormalId.Top, size = nseq({ { 0, W0 * 0.1, W0 * 0.035 }, { 0.75, W0 * 0.075 }, { 1, 0 } }),
		transparency = nseq({ { 0, 0 }, { 0.7, 0.15 }, { 1, 1 } }), brightness = 2, emission = 1, lightInfluence = 0, rotSpeed = NR(-180, 180), zoffset = 1.5,
	})
	fx.motes = job:emitter('ColumnMotes', 'spark', seqOf({ WHITE, rcol:Lerp(WHITE, 0.35) }), {
		life = { 0.45, 0.75 }, speed = { H0 * 1.4, H0 * 2.6 }, drag = 0.6, spread = Vector2.new(7, 7), direction = Enum.NormalId.Top,
		size = nseq({ { 0, 0 }, { 0.2, W0 * 0.06, W0 * 0.02 }, { 1, 0 } }), transparency = nseq({ { 0, 0.1 }, { 0.8, 0.3 }, { 1, 1 } }),
		brightness = 2, emission = 1, lightInfluence = 0, rotSpeed = NR(-90, 90), zoffset = 0.5,
	})
	-- a soft glow puff at the mouth as the lid swings (the column's foot)
	fx.mouthGlow = job:emitter('MouthGlow', 'glow', seqOf({ WHITE, rcol:Lerp(WHITE, 0.4) }), {
		life = { 0.45, 0.45 }, speed = { 0.01, 0.01 }, spread = Vector2.zero, rotation = NR(0), rotSpeed = NR(0), emission = 1, lightInfluence = 0,
		size = nseq({ { 0, W0 * 0.5 }, { 0.35, W0 * 1.25 }, { 1, W0 * 1.45 } }), transparency = nseq({ { 0, 0.35 }, { 0.4, 0.55 }, { 1, 1 } }), zoffset = -1,
	})
end

-- the timed bursts
function UnboxFX.beats(job, X)
	local P, fx = job.P, job.fx
	local Fx = F()
	local red = P.reduced and 0.5 or 1
	for i, box in job.boxes do
		local big = (not P.multi) or P.n <= 4 or i == P.best
		job:at(P.land[i], function() job:emit(fx.landRing, 1, box.home * CF(0, box.fullH * 0.02, 0)) end)
		if not P.prelude then
			job:at(P.pop[i] + 0.02, function()
				local mouth = (box.cf or box.home) * CF(0, box.seamY, 0)
				job:emit(fx.mouthGlow, 1, CFrame.lookAt(mouth.Position, mouth.Position - job.camBase.LookVector))
				local n = (Fx.Shower[box.rank] or 12) * red * (big and 1 or 0.4)
				job:emit(fx.shower, n, mouth)
			end)
			-- the motes stream up the column in four puffs
			for k, dt in Fx.Motes do
				job:at(P.pop[i] + dt, function()
					local base = (box.mouthCF or box.home * CF(0, box.seamY, 0))
					job:emit(fx.motes, (P.rank >= 4 and 5 or 4) * red * (big and 1 or 0.5) * (k == 1 and 1.5 or 1), base * CF(0, -box.seamY * 0.25, 0))
				end)
			end
		end
	end
	-- confetti from the top of the view at the best's reveal, in two side bands clear of the pair and its words
	local nConf = (not P.reduced and not P.prelude) and (Fx.Confetti[P.rank] or 0) or 0
	if nConf > 0 then
		job:at(P.accent[P.best] - 0.12, function()
			local cam, view = job.camBase, job.view
			local D, halfH, halfW = view.D, view.Hvis * 0.5, view.Wvis * 0.5
			local th = P.theme
			local rc = X.rarityColor(P.rank)
			local cols = { rc, rc:Lerp(WHITE, 0.4), th.Color, th.Accent, WHITE }
			local sz = job.boxes[P.best].W * 0.075
			for _, b in { { -0.78, 0.6 }, { -0.58, 0.4 }, { 0.58, 0.4 }, { 0.78, 0.6 } } do
				for _, kind in { 'rect', 'strip' } do
					job:spawn({ kind = kind, n = nConf * b[2] / 4, colors = cols, t0 = job.t + (kind == 'strip' and 0.05 or 0),
						at = CF(cam * V3(b[1] * halfW, halfH * 1.08, -D)), speed = { halfH * 0.15, halfH * 0.45 }, size = sz,
						rain = halfW * 0.09, spread = 0.7, grav = halfH * 2.2, life = 2.6, dragMin = 0.5, dragMax = 0.8 }, 'confetti')
				end
			end
		end)
	end
end

-- per frame: the leaks, the pool under each box, the columns
function UnboxFX.frame(job, t)
	local P = job.P
	local Fx = F()
	local acf = job.anchor.CFrame:Inverse()
	local cam = job.camCF or job.camBase
	for i, box in job.boxes do
		local cf = box.cf
		local live = cf and box.visible
		if live then box.mouthCF = cf * CF(0, box.seamY, 0) end
		-- the leak rays and the pool: their level, written on change
		local lvl = live and UnboxFX.level(P, i, t) or 0
		local col = box.teaseColor or WHITE
		if lvl ~= box.poolLevel or (lvl > 0 and col ~= box.poolColor) then
			box.poolLevel, box.poolColor = lvl, col
			local on = lvl > 0
			if on then
				box.pool.Size = NumberSequence.new(box.W * Fx.Pool.size[lvl])
				box.pool.Color = seqOf({ col:Lerp(WHITE, 0.45), col })
				local a = Fx.Pool.alpha[lvl]
				box.pool.Transparency = nseq({ { 0, 1 }, { 0.3, a }, { 0.7, a }, { 1, 1 } })
			end
			if box.pool.Enabled ~= on then box.pool.Enabled = on; job:recount() end
			for _, l in box.leaks do l.beam.Color = ColorSequence.new(col) end
		end
		if live then box.poolHost.CFrame = cf * CF(0, box.fullH * 0.01, 0) end
		local reach = lvl > 0 and Fx.Leak.len[lvl] or 0
		for j, l in box.leaks do
			if reach > 0 then
				-- (from the crack's front edge, fanning up and out toward the camera; a slow shimmer in length)
				local x = l.u * box.W * 0.42
				local p0 = cf * V3(x, box.seamY + 0.01 * box.s, -box.D * 0.5)
				local dir = cf:VectorToWorldSpace(V3(l.u * 0.75, 1, -0.45)).Unit
				local shimmer = P.reduced and 1 or (0.85 + 0.15 * math.sin(t * (7 + 5 * l.h) + j * 1.7))
				local len = reach * box.fullH * (0.7 + 0.45 * l.h) * shimmer
				l.a0.CFrame = acf * CF(p0)
				l.a1.CFrame = acf * CF(p0 + dir * len)
				local a = M.c01(0.35 + 0.18 * lvl)
				local q = math.floor(a * 20 + 0.5) / 20
				if l.q ~= q then
					l.q = q
					l.beam.Transparency = nseq({ { 0, 1 - 0.8 * q }, { 0.5, 1 - 0.45 * q }, { 1, 1 } })
				end
				local w1 = Fx.Leak.width * box.W * (0.6 + 0.15 * lvl)
				if math.abs(l.beam.Width1 - w1) > 1e-3 then l.beam.Width1 = w1 end
				if not l.beam.Enabled then l.beam.Enabled = true end
			elseif l.beam.Enabled then
				l.beam.Enabled = false
			end
		end
		-- the column: rising out of the open chest from the pop (Quart Out), held, then fading as the pair settles
		local c = box.column
		local q = t - P.pop[i]
		local C = Fx.Column
		local alpha, h = 0, 0
		if not P.prelude and q >= 0 and q < C.hold + C.fade then
			alpha = M.c01(q / 0.06) * (1 - M.smooth(M.c01((q - C.hold) / C.fade)))
			h = C.height * box.fullH * M.out(q / C.rise, 4)
		end
		if alpha > 0.01 and h > 0.02 and box.mouthCF and cam then
			local base = box.mouthCF * CF(0, -box.seamY * 0.35, box.D * 0.1)
			local up = box.home.UpVector
			c.a.CFrame = acf * CF(base.Position)
			c.b.CFrame = acf * CF(base.Position + up * h)
			local qa = math.floor(alpha * 20 + 0.5) / 20
			if c.alpha ~= qa then
				c.alpha = qa
				c.soft.Transparency = nseq({ { 0, 1 - 0.55 * qa }, { 0.55, 1 - 0.3 * qa }, { 1, 1 } })
				c.core.Transparency = nseq({ { 0, 1 - 0.85 * qa }, { 0.5, 1 - 0.5 * qa }, { 1, 1 } })
			end
			-- (it narrows as it fades, so it draws back into the pair's glow instead of switching off)
			local wk = 0.55 + 0.45 * alpha
			c.soft.Width0, c.soft.Width1 = box.W * C.soft * wk, box.W * C.soft * 0.8 * wk
			c.core.Width0, c.core.Width1 = box.W * C.core * wk, box.W * C.core * 0.6 * wk
			if not c.soft.Enabled then c.soft.Enabled, c.core.Enabled = true, true end
		elseif c.soft.Enabled then
			c.soft.Enabled, c.core.Enabled = false, false
		end
	end
end

return UnboxFX
