-- UnboxCinematic (brief 27, REVEAL): the box opening as a world-space cinematic, client-side. The REAL 3D box
-- (Models/BoxModels, with its separable Lid) drops onto "The Drop Pad", a hood rooftop built far from the map
-- (Shared/UnboxKit), slams, wobbles and pops; the REAL 3D pair (Models/ShoeModels, with its ShoeFX rarity effects) rises
-- out of it. The camera is taken (Scriptable; CFrame, FieldOfView and Focus every frame); Lighting, the Atmosphere, the
-- Sky's stars and our own ColorCorrection, Bloom and Blur (under the camera) are driven per frame. EVERYTHING is put back
-- exactly afterwards (camera type, subject, CFrame, FOV and Focus, the controls, every Lighting value) and every
-- instance is destroyed. Timings follow ANIMLAB's beat sheets (brief/out27/unbox_beats.md), recipes its cookbook.
--
--   UnboxCinematic.play(info, opts) -> job    plays one ShoeOpened (ShoeService's payload: Box, Shoe, Rarity, New, Count,
--                                             Equipped, Shoes, Buy, Best, Product; Better from Shoes.client)
--       opts.tier     'normal' | 'premium' | 'gift' (default UnboxCinematic.tierFor(info, player))
--       opts.reduced  Reduced Motion: the normal sheet, no shake, punch, hit-stop or white flash
--       opts.gui      the ScreenGui for the words, the flash and the tap-to-skip (default: one in PlayerGui)
--       opts.onDone   called once, after everything is restored;   opts.manual  no render-step binding (job:step(dt))
--     job:step(dt), job:skip() (a tap: to the reveal, then to the end), job:finish(), job.T, job.Plan, job.Done
--   UnboxCinematic.plan(info, opts?) -> plan  the timeline only (pure): every beat in seconds, flashes, totals
--   UnboxCinematic.tierFor(info, player?)     'premium' for a Robux box, 'gift' for the onboarding welcome gift, else
--                                             'normal'; Reduced Motion plays premium as normal
--   UnboxCinematic.active() -> boolean
--
-- The sheets (s): NORMAL Common 4.75 (the box hangs 0.30, lands 0.75, wobbles 1.35/1.75/2.08, pops 2.50, the pair is up
--   by 3.1, "tap to continue" 3.7, auto-continue 4.4 + the rarity's hold); the welcome gift (2 pairs) 4.75 whatever the
--   rarity; PREMIUM Rare 8.55 .. Secret 9.95 (night at once, a comet from 0.45, SLAM 1.25, rings and a 2 s charge, the
--   dark beat 3.9, ONE white flash 4.25 (0.22 s) under which the stage relights, the lid blasts, the pair rises in
--   silhouette and is lit at 5.05); Buy 3 / Buy 8: staggered slams, opens in ascending rarity (best last), the best steps
--   forward. Honest tease: the seam glow climbs one rarity per wobble and stops at the true one.
-- Kid-safe: at most one white flash a second, each <= 0.25 s (a Secret's second one >= 1 s later); flicker only on small
--   lamp heads. Budgets: live particles <= 80 normal / 300 premium (every Emit counted, the ambient rates and the pairs'
--   ShoeFX too; bursts scaled down on phones and low graphics); <= 3 PointLights; ~200 stage parts; <= 180 bits.
local UnboxCinematic = {}

local RunService = game:GetService('RunService')
local Lighting = game:GetService('Lighting')
local Players = game:GetService('Players')

local Shared = script.Parent
local Themes = require(Shared:WaitForChild('UnboxThemes'))
local Kit = require(Shared:WaitForChild('UnboxKit'))
local function optional(...)
	local node = Shared
	for _, name in { ... } do
		node = node and node:FindFirstChild(name)
	end
	if not node then return nil end
	local ok, result = pcall(require, node)
	return ok and type(result) == 'table' and result or nil
end
local BoxModels = optional('Models', 'BoxModels')
local ShoeModels = optional('Models', 'ShoeModels')
local ShoeFX = optional('ShoeFX')
local ShoesCfg = optional('Config', 'Shoes')
local UIKit = optional('UIKit')

local M, Make, Actor, Bits, Ring, PartRing = Kit.M, Kit.Make, Kit.Actor, Kit.Bits, Kit.Ring, Kit.PartRing
local seqOf, nseq, bulk = Kit.seq, Kit.nseq, Kit.bulk
local V3, CF, ANG = Vector3.new, CFrame.new, CFrame.Angles
local C3 = Color3.fromRGB
local NR = NumberRange.new
local WHITE = Color3.new(1, 1, 1)
local BLACK = Color3.new(0, 0, 0)
local PI = math.pi
local RAD = math.rad

UnboxCinematic.StageAt = CF(-2600, 250, -2600) -- far from the map (World 1 is round x 2400) and above it; client-only
UnboxCinematic.Caps = { normal = 80, gift = 80, premium = 300 }
UnboxCinematic.MaxSeconds = 10
UnboxCinematic.FlashMax = 0.25
UnboxCinematic.G = 1.33 -- the stage's scale over ANIMLAB's studs (our boxes are built at ~1.6)
UnboxCinematic.BitCaps = { slam = 36, pop = 36, confetti = 70, reveal = 30 }
UnboxCinematic.HeroYaw = { normal = math.rad(15), premium = math.rad(-20) } -- (a 3/4 from the left; a low 3/4 from the right)
UnboxCinematic.Gather = 0.74
UnboxCinematic.LightAlbedo = 165 -- (a pair brighter than this (mean luma, 0-255) gets the soft hero light)
UnboxCinematic.DarkAlbedo = 100 -- (a pair darker than this gets a rarity glow behind it and a rim light) -- (a Buy 3's pairs close up to this share of the boxes' spacing as they rise)

---------------------------------------------------------------------------------------------- data
local function shoeDef(id) return ShoesCfg and ShoesCfg.ById and ShoesCfg.ById[id] end
local function boxDef(id) return ShoesCfg and ShoesCfg.BoxById and ShoesCfg.BoxById[id] end
local function rankOf(id)
	local s = shoeDef(id)
	return s and s.Rank or 1
end
local function rarityRow(rank)
	local rows = ShoesCfg and ShoesCfg.Rarities
	return rows and rows[rank] or { Id = 'Common', Name = 'Common', Color = C3(178, 186, 198) }
end
local function rarityColor(rank)
	if ShoeFX and type(ShoeFX.tier) == 'function' then
		local ok, row = pcall(ShoeFX.tier, rank)
		if ok and type(row) == 'table' and typeof(row.Color) == 'Color3' then return row.Color end
	end
	return rarityRow(rank).Color
end
local function rainbowSeq(offset)
	local list = {}
	local R = Themes.Rainbow
	for i = 1, #R do list[i] = R[(i - 1 + (offset or 0)) % #R + 1] end
	table.insert(list, list[1])
	return seqOf(list)
end
UnboxCinematic.rarityColor = rarityColor

-- The pairs of an opening and the best one (a Buy 3 / Buy 8 sends Shoes; a single open only the top level).
function UnboxCinematic.entries(info)
	local list = {}
	if type(info.Shoes) == 'table' then
		for _, e in info.Shoes do
			if type(e) == 'table' and shoeDef(e.Shoe) then table.insert(list, e) end
		end
	end
	if #list <= 1 then
		return { { Shoe = info.Shoe, Rarity = info.Rarity, New = info.New, Count = info.Count, Equipped = info.Equipped, Better = info.Better } }, 1
	end
	return list, math.clamp(math.floor(tonumber(info.Best) or 1), 1, #list)
end
function UnboxCinematic.isGift(info, player)
	if type(info) ~= 'table' or info.Product ~= nil then return false end
	local step = player and player:GetAttribute('OnboardingStep')
	return tonumber(info.Buy) == 2 or (step == 'Gift' and info.Box == 'Street')
end
local function reducedFor(player)
	return player ~= nil and (player:GetAttribute('ReduceMotion') == true or player:GetAttribute('ReducedMotion') == true)
end
function UnboxCinematic.tierFor(info, player)
	player = player or Players.LocalPlayer
	if UnboxCinematic.isGift(info, player) then return 'gift' end
	local box = boxDef(info.Box)
	local robux = (box and box.Robux) or (not box and Themes.Premium[info.Box or ''])
	if robux and not reducedFor(player) then return 'premium' end
	return 'normal'
end

---------------------------------------------------------------------------------------------- the plan (pure)
local EXTRA_N = { 0, 0.1, 0.4, 0.8, 1.2, 1.8 } -- normal auto-continue past 4.4 s, by rank
local EXTRA_P = { 0, 0, 0.3, 0.7, 1.1, 1.4 } -- premium past 8.2 s
local G = UnboxCinematic.G

-- Layouts (stage space; y = the surface the box stands on): homes, box scale, pad radius, the Buy 8's riser.
local function layout(P)
	local n = P.n
	if n == 1 then
		P.boxScale = P.premium and 1.75 or 1.6
		P.homes = { V3(0, 0.22, 0) }
		P.padR = 6.7
	elseif n == 2 then
		P.boxScale = 1.35
		P.homes = { V3(-4.7, 0.22, 0), V3(4.7, 0.22, 0) }
		P.padR = 9.4
	elseif n <= 4 then
		P.boxScale = P.premium and 1.5 or 1.45
		local sp = P.premium and 9.6 or 8.65
		P.homes = {}
		for i = 1, n do P.homes[i] = V3((i - (n + 1) / 2) * sp, 0.22, (i % 2 == 0) and -0.6 or 0.5) end
		P.padR = sp * (n - 1) / 2 + 6
	else
		-- two rows of four: the back row raised on a riser, the rows offset half a slot; drops back L->R, then front
		P.boxScale = 1.2
		local sp = 6.65
		P.homes = {}
		local back, front = math.floor(n / 2), n - math.floor(n / 2)
		for j = 1, back do P.homes[j] = V3((j - (back + 1) / 2) * sp + 1.66, 1.6, 5.2) end
		for j = 1, front do P.homes[back + j] = V3((j - (front + 1) / 2) * sp - 1.66, 0.22, -1.6) end
		P.padR = 14
		P.riser = { w = sp * back + 6, h = 1.6, d = 5.6, z = 5.2 }
	end
	P.boxW = 4.4 * P.boxScale
	P.shoeScale = n >= 5 and 1.4 or n == 2 and 1.5 or n >= 2 and 1.65 or 2.35
end

function UnboxCinematic.plan(info, opts)
	opts = opts or {}
	local list, best = UnboxCinematic.entries(info)
	local n = #list
	local tier = opts.tier or UnboxCinematic.tierFor(info, opts.player)
	if opts.reduced and tier == 'premium' then tier = 'normal' end
	local P = { tier = tier, n = n, best = best, list = list, box = info.Box, theme = Themes.get(info.Box), G = G }
	P.premium, P.gift, P.multi = tier == 'premium', tier == 'gift', n > 1
	P.reduced = opts.reduced == true
	P.k = Themes.strength(info.Box, P.premium and 'premium' or 'normal')
	P.themeTier = Themes.tierOf(info.Box)
	P.deluxe = (not P.premium) and P.theme.Deluxe or nil
	P.ranks = {}
	for i, e in list do P.ranks[i] = rankOf(e.Shoe) end
	P.rank = P.ranks[best]
	local rr = P.gift and math.min(P.rank, 4) or P.rank -- (the gift's extras stop at the Legendary row)
	P.R = Themes.Rarity[rr] or Themes.Rarity[1]
	-- the opens in ascending rarity, ties left to right, the best last (it changes no outcome)
	local order = {}
	for i = 1, n do
		if i ~= best then table.insert(order, i) end
	end
	table.sort(order, function(a, b) if P.ranks[a] ~= P.ranks[b] then return P.ranks[a] < P.ranks[b] end return a < b end)
	table.insert(order, best)
	P.order = order
	layout(P)
	P.appear, P.fall0, P.land, P.hs, P.pop, P.crouch, P.rise, P.accent, P.trauma, P.wobOff = {}, {}, {}, {}, {}, {}, {}, {}, {}, {}
	if P.premium then UnboxCinematic._premium(P) else UnboxCinematic._normal(P) end
	P.done = P.out + (P.gift and 0.2 or 0.35) -- (the welcome gift is back in the world by 4.6 s)
	if P.done > UnboxCinematic.MaxSeconds - 0.05 then
		P.out = UnboxCinematic.MaxSeconds - 0.4
		P.done = P.out + 0.35
	end
	P.total = P.done
	P.skipTo = P.multi and P.group or P.accent[best]
	return P
end

function UnboxCinematic._normal(P)
	local n, best = P.n, P.best
	P.cut, P.clear = 0.12, 0.30
	P.fallH = 8 -- (the box hangs at the top of the frame, then drops)
	P.fall = n >= 5 and 0.30 or 0.33
	if n == 1 then
		P.appear[1], P.fall0[1], P.land[1] = 0.30, 0.42, 0.75
	elseif n <= 4 then
		local gap = n == 2 and 0.12 or 0.18
		for i = 1, n do P.appear[i], P.fall0[i], P.land[i] = 0.30 + (i - 1) * gap, 0.42 + (i - 1) * gap, 0.75 + (i - 1) * gap end
	else
		for i = 1, n do
			P.fall0[i] = 0.35 + 0.11 * (i - 1)
			P.appear[i] = P.fall0[i] - 0.1
			P.land[i] = P.fall0[i] + P.fall
		end
	end
	for i = 1, n do
		P.hs[i] = P.reduced and 0 or 0.05
		P.trauma[i] = n == 1 and 0.45 or n == 2 and 0.4 or n <= 4 and ({ 0.35, 0.4, 0.5 })[math.min(i, 3)] or 0.15
		P.wobOff[i] = n <= 4 and (i - 1) * 0.06 or ((i - 1) % 4) * 0.04
	end
	-- wobbles: time (s), roll (deg), hop (studs); the gaps shrink, the angles grow
	if n <= 2 then
		P.wobSpec = { { 1.35, 6, 0.25 }, { 1.75, 10, 0.45 }, { 2.08, 15, 0.7 } }
	elseif n <= 4 then
		P.wobSpec = { { 1.45, 8, 0.35 }, { 1.85, 12, 0.5 } }
	else
		P.wobSpec = { { 1.65, 8, 0.3 }, { 1.95, 12, 0.45 } }
	end
	-- the pops: a single at 2.5; the gift's lower pair first; a Buy 3 2.2/2.5/2.8 ascending; a Buy 8 the lowest at 2.25
	-- then a ripple 80 ms apart, the best last
	for j, i in P.order do
		if n == 1 then P.pop[i] = 2.5
		elseif n == 2 then P.pop[i] = j == 1 and 2.45 or 2.6
		elseif n <= 4 then P.pop[i] = 2.2 + (j - 1) * 0.3
		else P.pop[i] = j == 1 and 2.25 or 2.65 + (j - 2) * 0.08 end
		P.crouch[i] = P.pop[i] - (n >= 5 and 0.1 or n >= 3 and 0.12 or 0.15)
		P.rise[i] = P.pop[i] + 0.05
	end
	P.riseLen = n == 1 and 0.55 or n >= 5 and 0.6 or 0.45
	P.riseH = (n == 1 and 3.0 or n >= 5 and 2.2 or 2.6) * G
	P.spinLen, P.spinTurns = n == 1 and 0.85 or 0.7, n == 1 and 1.25 or 1
	-- the reveal accent (the pair settles, the rarity's channels fire) and the words
	if n == 1 then
		P.accent[best] = 3.1
		if P.R.SlowMo then P.slowmo = { 2.95, 3.55 }; P.accent[best] = 3.55 end
		P.banner = P.accent[best] - 0.1
	else
		P.accent[best] = n == 2 and 3.15 or n <= 4 and 3.25 or 3.45
		P.group = P.accent[best] - 0.25
		for j, i in P.order do
			if i ~= best then P.accent[i] = P.accent[best] + 0.05 + j * 0.06 end
		end
		P.banner = P.accent[best] + (n == 2 and -0.05 or 0.15)
	end
	P.newT, P.nameT = P.banner + 0.15, P.banner + 0.15
	P.count = { P.banner + 0.2, P.banner + 0.6 }
	P.tap = P.banner + 0.7
	if P.gift or n == 2 then P.out = 4.4
	elseif n == 1 then P.out = 4.4 + EXTRA_N[P.rank]
	elseif n <= 4 then P.out = 5.0 + EXTRA_N[P.rank]
	else P.out = 5.4 + EXTRA_N[P.rank] / 2 end
	-- flashes: a soft one (not white) at the best's pop for Rare and up; a Secret's full flash at its accent (>= 1 s later)
	P.flashes, P.soft = {}, {}
	local lastPop = P.pop[best]
	-- (a soft pop glow, tinted with the rarity and never white-out: it reads on a night stage without a jump in luma)
	if P.R.MiniFlash and not P.reduced then table.insert(P.soft, { lastPop, 0.2, 0.15 }) end
	if P.R.Flash2 and not P.reduced and not P.gift then table.insert(P.flashes, { math.max(P.accent[best], lastPop + 1.05), 0.9, 0.22 }) end
	P.firstPop = P.pop[P.order[1]]
	P.lastLand = P.land[n]
end

function UnboxCinematic._premium(P)
	local n, best = P.n, P.best
	P.cut, P.clear = 0, 0
	P.fallH = 34 * G
	P.fall = 0.45
	-- the comet comes in from high up, behind and to the left (in the low wide shot's frame), straight down onto the pad
	P.cometFrom = V3(-24 * G, 30 * G, 14 * G)
	P.telegraph = { 0.3, 0.65 }
	if n == 1 then
		P.appear[1], P.fall0[1], P.land[1] = 0.45, 0.8, 1.25
		P.hs[1], P.trauma[1] = 0.1, 1.0
	elseif n <= 4 then
		for i = 1, n do
			P.appear[i] = 0.45 + (i - 1) * 0.1
			P.fall0[i] = 0.8 + (i - 1) * 0.18
			P.land[i] = P.fall0[i] + P.fall
			P.hs[i] = i == n and 0.1 or 0.06
			P.trauma[i] = ({ 0.6, 0.75, 1.0 })[math.min(i, 3)]
		end
	else
		for i = 1, n do
			P.appear[i] = 0.4 + (i - 1) * 0.05
			P.land[i] = 1.05 + 0.1 * (i - 1)
			P.fall0[i] = P.land[i] - P.fall
			P.hs[i] = i == n and 0.1 or 0
			P.trauma[i] = i == n and 0.8 or 0.18
		end
	end
	for i = 1, n do
		if P.reduced then P.hs[i] = 0 end
		P.wobOff[i] = n == 1 and 0 or n <= 4 and (i - 1) * 0.05 or ((i - 1) % 4) * 0.03
	end
	if n == 1 then
		P.charge, P.ringsIn = { 1.9, 3.9 }, { 1.9, 2.05, 2.2 }
		P.wobSpec = { { 2.15, 5, 0.2 }, { 2.65, 8, 0.35 }, { 3.07, 11, 0.5 }, { 3.4, 14, 0.65 }, { 3.66, 17, 0.8 } }
	elseif n <= 4 then
		P.charge, P.ringsIn = { 2.0, 3.7 }, { 2.0, 2.15, 2.3 }
		P.wobSpec = { { 2.15, 5, 0.2 }, { 2.6, 8, 0.35 }, { 2.98, 11, 0.5 }, { 3.27, 14, 0.65 }, { 3.48, 17, 0.8 } }
	else
		P.charge, P.ringsIn = { 2.1, 3.5 }, { 2.1, 2.25, 2.4 }
		P.wobSpec = { { 2.3, 6, 0.25 }, { 2.75, 10, 0.4 }, { 3.11, 13, 0.55 }, { 3.39, 16, 0.7 } }
	end
	P.motes = P.charge[1] + 0.3
	P.buildPillar = P.charge[1] + 0.5
	P.dip = { P.charge[2], P.charge[2] + 0.35 }
	P.flash = P.dip[2]
	P.lid = {}
	for i = 1, n do P.lid[i] = 0 end
	for j, i in P.order do P.lid[i] = P.flash + 0.07 + (j - 1) * (n >= 5 and 0.04 or 0.06) end
	for i = 1, n do
		P.pop[i] = P.lid[i]
		P.crouch[i] = P.dip[1]
		P.rise[i] = P.lid[i] + 0.08
	end
	P.riseLen = n == 1 and 0.9 or n <= 4 and 0.8 or 0.75
	P.riseH = (n == 1 and 4.5 or n <= 4 and 3.4 or 2.6) * G
	P.spinLen, P.spinTurns = P.riseLen, n == 1 and 2 or 1.5
	-- the reveal accents: a single at 5.05 (a Secret: the false calm, then 5.65); a multi in ascending rarity
	if n == 1 then
		P.accent[best] = P.flash + 0.8
		if P.R.SlowMo then P.slowmo = { P.flash + 0.65, P.flash + 1.25 }; P.accent[best] = P.flash + 1.4 end
	else
		local a0, gap = (n <= 4 and P.flash + 0.9 or P.flash + 0.85), (n <= 4 and 0.3 or 0.1)
		for j, i in P.order do P.accent[i] = a0 + (j - 1) * gap end
		if P.R.SlowMo then P.slowmo = { P.accent[best] - 0.5, P.accent[best] + 0.1 }; P.accent[best] += 0.15 end
		P.group = P.accent[best]
	end
	local a = P.accent[best]
	P.pillarOut = { a + 0.25, a + 0.85 }
	P.confetti = a
	P.banner = a + 0.45
	P.newT, P.nameT = P.banner + 0.18, P.banner + 0.2
	-- (the hold pays off a second time: at accent + 1.0 the bonus flies into the Power chip and counts up, then a stamp)
	P.count = { a + 1.0, a + 1.6 }
	P.tap = P.banner + 0.75
	if n == 1 then P.out = 8.2 + EXTRA_P[P.rank]
	elseif n <= 4 then P.out = math.min(9.6, 8.8 + EXTRA_P[P.rank] / 2)
	else P.out = math.min(9.6, 9.0 + EXTRA_P[P.rank] / 2) end
	P.flashes, P.soft = {}, {}
	if not P.reduced then
		table.insert(P.flashes, { P.flash, 0.9, 0.22 })
		if P.R.Flash2 then table.insert(P.flashes, { math.max(a, P.flash + 1.05), 0.75, 0.2 }) end
	else
		table.insert(P.soft, { P.flash, 0.4, 0.3 })
	end
	P.firstPop = P.pop[1]
	P.lastLand = P.land[n]
end

---------------------------------------------------------------------------------------------- the job
local Job = {}
Job.__index = Job
local current = nil
function UnboxCinematic.active() return current ~= nil and not current.Done end

function Job:w(v) return self.O * CF(v) end
function Job:wp(v) return (self.O * CF(v)).Position end
-- one-shots at t0 (played once when the clock passes; a skip plays only the essential ones it jumped over)
function Job:at(t0, fn, essential) table.insert(self.events, { t0, fn, essential }) end
-- per-frame updaters (theme signatures)
function Job:onFrame(fn) table.insert(self.updaters, fn) end

-- Particle budget: every Emit (n alive for the emitter's longest life), the enabled rates, the pairs' ShoeFX. An Emit
-- that would pass the cap is trimmed; on phones and low graphics bursts are scaled first (Emit ignores quality).
function Job:bursts(t)
	local n = 0
	for i = #self.emits, 1, -1 do
		local e = self.emits[i]
		if t >= e[1] + e[3] then table.remove(self.emits, i) else n += e[2] end
	end
	return n
end
function Job:live(t) return (self.contLive or 0) + self:bursts(t) end
function Job:emit(e, n, at)
	if not e or n <= 0 then return 0 end
	n = math.max(1, math.floor(n * self.vfxScale + 0.5)) -- (a single ring or backdrop stays one on low graphics)
	-- (the continuous layers' whole share stays reserved, so switching one on later never passes the cap)
	local room = self.cap - math.max(self.contLive or 0, self.contMax or 0) - self:bursts(self.t)
	n = math.min(n, math.floor(room))
	if n <= 0 then return 0 end
	if at and e.Parent and e.Parent:IsA('Attachment') then e.Parent.CFrame = self.anchor.CFrame:ToObjectSpace(at) end
	if not pcall(function() e:Emit(n) end) then return 0 end
	table.insert(self.emits, { self.t, n, e.Lifetime.Max })
	self.peak = math.max(self.peak or 0, self:live(self.t))
	return n
end
-- An emitter on its own attachment on the stage anchor (bursts), or on a host part (volumes, shells).
function Job:emitter(name, tex, color, o, host)
	local e = Make.emitter(host or Make.attach(self.anchor, name), name, tex, color, o)
	table.insert(self.emitterList, e)
	return e
end
function Job:spawn(spec, cat) self.bits:spawn(spec, cat, UnboxCinematic.BitCaps[cat] or 20) end

---------------------------------------------------------------------------------------------- particle presets (cookbook §8)
local Preset = {}
local function quartKeys(R)
	local s = 2.2 * R
	return nseq({ { 0, 0.05 * s }, { 0.1, 0.34 * s }, { 0.2, 0.59 * s }, { 0.35, 0.82 * s }, { 0.5, 0.94 * s }, { 0.7, 0.99 * s }, { 1, s } })
end
function Preset.shock(job, name, R, life, color)
	return job:emitter(name, 'ring', seqOf({ WHITE, color }), {
		life = { life, life }, speed = { 0.01, 0.01 }, spread = Vector2.zero, orientation = Enum.ParticleOrientation.VelocityPerpendicular,
		size = quartKeys(R), transparency = nseq({ { 0, 0.05 }, { 0.55, 0.35 }, { 1, 1 } }), rotation = NR(0, 360), rotSpeed = NR(0),
	})
end
function Preset.core(job, name, size, color)
	return job:emitter(name, 'glow', seqOf({ WHITE, color or WHITE }), {
		life = { 0.12, 0.12 }, speed = { 0, 0 }, size = nseq({ { 0, 0 }, { 0.25, size }, { 1, size * 0.8 } }),
		transparency = nseq({ { 0, 0 }, { 0.5, 0.3 }, { 1, 1 } }), zoffset = 2, rotSpeed = NR(0),
	})
end
-- (P5: a horizontal fan of concrete-grey puffs, lit but not glowing; born a stud up so the floor never eats them)
function Preset.dust(job, name, color, premium)
	local grey = C3(150, 150, 160)
	return job:emitter(name, 'smoke', seqOf({ grey:Lerp(color, 0.15), grey }), {
		life = { 0.6, 1.0 }, speed = premium and { 16 * G, 24 * G } or { 9 * G, 13 * G }, drag = 5, accel = V3(0, 2, 0),
		spread = Vector2.new(0, 180), direction = Enum.NormalId.Front, lightInfluence = 0.5, emission = 0,
		size = nseq({ { 0, 1.4 * G, 0.3 }, { 1, 4.6 * G } }), transparency = nseq({ { 0, 1 }, { 0.08, 0.15 }, { 0.6, 0.45 }, { 1, 1 } }),
		rotSpeed = NR(-60, 60), zoffset = 0,
	})
end
function Preset.sparks(job, name, color)
	return job:emitter(name, 'spark', seqOf({ WHITE, color }), {
		life = { 0.18, 0.4 }, speed = { 30, 48 }, spread = Vector2.new(60, 60), drag = 8, accel = V3(0, -30, 0),
		orientation = Enum.ParticleOrientation.VelocityParallel, squash = NumberSequence.new(1.4),
		size = nseq({ { 0, 0.6 }, { 1, 0 } }), transparency = nseq({ { 0, 0 }, { 0.7, 0.2 }, { 1, 1 } }), rotSpeed = NR(0),
	})
end
function Preset.burst(job, name, color, speed, size)
	return job:emitter(name, 'spark', typeof(color) == 'ColorSequence' and color or seqOf({ WHITE, color }), {
		life = { 0.6, 1.0 }, speed = speed or { 25, 40 }, spread = Vector2.new(35, 35), drag = 3, accel = V3(0, -25, 0),
		size = nseq({ { 0, size or 0.7, 0.2 }, { 1, 0 } }), transparency = nseq({ { 0, 0 }, { 0.7, 0.15 }, { 1, 1 } }), brightness = 1.6, zoffset = 1,
	})
end

---------------------------------------------------------------------------------------------- boxes and pairs
-- The axis-aligned bounds of the visible parts, in `rel`'s space (min, max).
local function bounds(parts, rel)
	local mn, mx = V3(math.huge, math.huge, math.huge), V3(-math.huge, -math.huge, -math.huge)
	for _, p in parts do
		if p:IsA('BasePart') and p.Transparency < 0.95 then
			local _, _, _, r00, r01, r02, r10, r11, r12, r20, r21, r22 = p.CFrame:GetComponents()
			local c = rel:PointToObjectSpace(p.CFrame.Position)
			local s = p.Size / 2
			local e = V3(math.abs(r00) * s.X + math.abs(r01) * s.Y + math.abs(r02) * s.Z, math.abs(r10) * s.X + math.abs(r11) * s.Y + math.abs(r12) * s.Z, math.abs(r20) * s.X + math.abs(r21) * s.Y + math.abs(r22) * s.Z)
			mn, mx = mn:Min(c - e), mx:Max(c + e)
		end
	end
	if mn.X > mx.X then return V3(-1, 0, -1), V3(1, 2, 1) end
	return mn, mx
end
local function stubBox(boxId, scale, at)
	local th = Themes.get(boxId)
	local m = Instance.new('Model')
	m.Name = boxId .. 'Box'
	local root = Make.part(m, 'Root', V3(1, 0.2, 1) * scale, at, WHITE, nil, { Transparency = 1 })
	m.PrimaryPart = root
	Make.part(m, 'Body', V3(4.4, 2.1, 3.4) * scale, at * CF(0, 1.05 * scale, 0), th.Accent)
	local lid = Instance.new('Model')
	lid.Name = 'Lid'
	lid.Parent = m
	local hinge = Make.part(lid, 'Hinge', V3(0.4, 0.1, 0.1) * scale, at * CF(0, 2.1 * scale, 1.7 * scale), WHITE, nil, { Transparency = 1 })
	lid.PrimaryPart = hinge
	Make.part(lid, 'LidBody', V3(4.6, 0.9, 3.6) * scale, at * CF(0, 2.55 * scale, 0), th.Color)
	m:SetAttribute('Scale', scale)
	return m
end
local Box = {}
function Box.mouth(self) return (self.cf or self.home) * CF(0, self.seamY + 0.3, 0) end
function Box.new(job, i)
	local P = job.P
	local s = P.boxScale
	local home = job:w(P.homes[i]) * ANG(0, RAD((M.hash(i, 31) - 0.5) * (P.multi and 14 or 0)), 0)
	local model
	if BoxModels and type(BoxModels.build) == 'function' then
		local ok, m = pcall(BoxModels.build, P.box, s, home)
		if ok and typeof(m) == 'Instance' then model = m end
	end
	model = model or stubBox(P.box, s, home)
	model.Name = 'UnboxBox' .. i
	local lid = model:FindFirstChild('Lid')
	local hinge = lid and lid.PrimaryPart
	local body, lidParts = {}, {}
	for _, d in model:GetDescendants() do
		if d:IsA('BasePart') then
			if lid and d:IsDescendantOf(lid) then table.insert(lidParts, d) else table.insert(body, d) end
		end
	end
	local size = BoxModels and BoxModels.Size or { W = 4.4, D = 3.4, Body = 2.1, Top = 3.08 }
	local self = { i = i, model = model, home = home, s = s, rank = P.ranks[i], mouth = Box.mouth }
	self.body = Actor.new(body, home)
	self.hingeRel = hinge and home:ToObjectSpace(hinge.CFrame) or CF(0, 2.1 * s, 1.7 * s)
	self.lid = Actor.new(lidParts, hinge and hinge.CFrame or home * self.hingeRel)
	self.seamY = size.Body * s
	self.topY = (size.Top or 3.08) * s
	self.W, self.D = size.W * s, size.D * s
	local _, bmax = bounds(model:GetDescendants(), home)
	self.fullH = math.max(self.topY, bmax.Y)
	-- the light leaking from the seam as it charges: a glowing slab under the lid
	self.seam = Make.part(job.folder, 'Seam', V3(self.W * 0.98, 0.16 * s, self.D * 0.98), job.park, WHITE, Enum.Material.Neon, { Transparency = 1 })
	-- the contact shadow (it grows on the pad while the box falls)
	self.shadow = Make.disc(job.folder, 'Shadow', 0.04, 1, job.park, C3(10, 10, 16), Enum.Material.SmoothPlastic, { Transparency = 1 })
	model.Parent = job.folder
	return self
end
-- Pose the box: cf at its base centre, sx/sy squash, the lid hinged (open 0..1), thrown (fly, scale) or hidden.
function Box.pose(self, cf, sx, sy, lid)
	self.body:pose(cf, sx, sy, sx)
	local hr = self.hingeRel
	local hp = hr.Position
	local hinge = cf * CF(hp.X * sx, hp.Y * sy, hp.Z * sx) * hr.Rotation
	if lid.hidden then
		self.lid:pose(lid.park, 1, 1, 1)
	elseif lid.fly then
		local ls = lid.scale or 1
		self.lid:pose(lid.fly, sx * ls, sy * ls, sx * ls)
	else
		self.lid:pose(hinge * ANG(RAD(110) * (lid.open or 0), 0, 0), sx, sy, sx)
	end
	self.cf = cf
end

local Pair = {}
function Pair.new(job, i, entry)
	local P = job.P
	local scale = P.shoeScale
	local model
	if ShoeModels and type(ShoeModels.pair) == 'function' then
		local ok, m = pcall(ShoeModels.pair, entry.Shoe, scale)
		if ok and typeof(m) == 'Instance' then model = m end
	end
	if not model then
		model = Instance.new('Model')
		local root = Make.part(model, 'Root', V3(0.2, 0.2, 0.2), CFrame.identity, WHITE, nil, { Transparency = 1 })
		model.PrimaryPart = root
		local sd = shoeDef(entry.Shoe)
		for _, sx in { -1, 1 } do
			Make.part(model, 'Shoe', V3(1.1, 0.7, 1.6) * scale, CF(sx * 0.62 * scale, 0.35 * scale, 0), sd and sd.Colors.Main or WHITE)
			Make.part(model, 'Sole', V3(1.16, 0.2, 1.7) * scale, CF(sx * 0.62 * scale, 0.1 * scale, 0), sd and sd.Colors.Sole or WHITE)
		end
	end
	model.Name = 'UnboxPair' .. i
	local rank = rankOf(entry.Shoe)
	-- (framed on the pair itself, before its rarity effects add their pieces) and its albedo: the mean luma (0-255) of its
	-- visible parts, by surface
	local mn, mx = bounds(model:GetDescendants(), CFrame.identity)
	local lsum, wsum, bright = 0, 0, 0
	for _, d in model:GetDescendants() do
		if d:IsA('BasePart') and d.Transparency < 0.95 then
			local z = d.Size
			local w = z.X * z.Y + z.Y * z.Z + z.X * z.Z
			local c = d.Color
			local l = (0.299 * c.R + 0.587 * c.G + 0.114 * c.B) * 255
			lsum += l * w
			wsum += w
			if l > 200 then bright += w end
		end
	end
	local albedo = wsum > 0 and lsum / wsum or 128
	local brightShare = wsum > 0 and bright / wsum or 0
	-- ShoeFX: the single's pair, or a multi's best (the others get a tag and the rarity glow)
	if ((not P.multi) or i == P.best) and ShoeModels and type(ShoeModels.fx) == 'function' and rank >= 2 then
		pcall(ShoeModels.fx, model, rank, { context = 'display', id = entry.Shoe })
		-- (in the hero shot the cinematic's own backdrop, rays and light carry the glow: ShoeFX's big additive layers
		-- (glow, shafts, ground, ring) at half strength and its light at 60 %, so the pair's laces and panels never clip)
		for _, d in model:GetDescendants() do
			if d:IsA('ParticleEmitter') and d.LightEmission >= 0.3 then
				local big = 0
				for _, k in d.Size.Keypoints do big = math.max(big, k.Value) end
				if big >= 3 then
					local ks = {}
					for _, k in d.Transparency.Keypoints do table.insert(ks, NumberSequenceKeypoint.new(k.Time, 1 - (1 - k.Value) * 0.5, k.Envelope * 0.5)) end
					d.Transparency = NumberSequence.new(ks)
				end
			elseif d:IsA('PointLight') then
				d.Brightness *= 0.6
			end
		end
	end
	local list = {}
	local self = { i = i, model = model, entry = entry, rank = rank, scale = scale, fxList = {}, fxOn = true }
	for _, d in model:GetDescendants() do
		if d:IsA('BasePart') then table.insert(list, d) end
		if d:IsA('ParticleEmitter') or d:IsA('Trail') or d:IsA('Light') then table.insert(self.fxList, d) end
	end
	self.actor = Actor.new(list, CFrame.identity)
	self.height = math.max(0.5, mx.Y - mn.Y)
	self.width = math.max(mx.X - mn.X, mx.Z - mn.Z)
	self.depth = math.min(mx.X - mn.X, mx.Z - mn.Z)
	self.base = mn.Y
	self.albedo = albedo
	self.brightShare = brightShare
	Pair.fx(self, false)
	model.Parent = job.folder
	self.actor:pose(job.park, 0.3)
	return self
end
function Pair.fx(self, on)
	if self.fxOn == on then return end
	self.fxOn = on
	for _, d in self.fxList do
		if d.Enabled ~= on then d.Enabled = on end
	end
end
function Pair.live(self)
	if not self.fxOn then return 0 end
	local n = 0
	for _, d in self.fxList do
		if d:IsA('ParticleEmitter') and d.Enabled then n += d.Rate * (d.Lifetime.Min + d.Lifetime.Max) / 2 end
	end
	return n
end

---------------------------------------------------------------------------------------------- the look (Lighting)
-- Ours: a ColorCorrection, a Bloom and a Blur under the camera (they compose with the place's and are just destroyed).
-- Edited after a snapshot and restored exactly: Lighting (incl. ClockTime), the Atmosphere, the Sky's stars, SunRays.
local LIGHT_PROPS = { 'ClockTime', 'Brightness', 'Ambient', 'OutdoorAmbient', 'ColorShift_Top', 'EnvironmentDiffuseScale', 'EnvironmentSpecularScale', 'ExposureCompensation', 'GeographicLatitude' }
local ATM_PROPS = { 'Density', 'Offset', 'Color', 'Decay', 'Haze', 'Glare' }
UnboxCinematic.LightProps, UnboxCinematic.AtmProps = LIGHT_PROPS, ATM_PROPS
local Look = {}
function Look.save(job)
	local s = { light = {}, atm = nil, sky = nil, rays = nil }
	for _, k in LIGHT_PROPS do
		local ok, v = pcall(function() return (Lighting :: any)[k] end)
		if ok then s.light[k] = v end
	end
	local atm = Lighting:FindFirstChildOfClass('Atmosphere')
	if not atm then
		atm = Instance.new('Atmosphere')
		atm.Name = 'HoodUnboxAtmosphere'
		atm.Density = 0
		atm.Parent = Lighting
		job.ownAtm = atm
	end
	s.atm = { inst = atm, v = {} }
	for _, k in ATM_PROPS do s.atm.v[k] = (atm :: any)[k] end
	local sky = Lighting:FindFirstChildOfClass('Sky')
	if sky then s.sky = { inst = sky, StarCount = sky.StarCount, CelestialBodiesShown = sky.CelestialBodiesShown } end
	local rays = Lighting:FindFirstChildOfClass('SunRaysEffect')
	if rays then s.rays = { inst = rays, Intensity = rays.Intensity, Spread = rays.Spread } end
	-- the place's own blooms (the hold eases them down so a light pair never clips; restored exactly)
	s.blooms = {}
	for _, b in Lighting:GetChildren() do
		if b:IsA('BloomEffect') then table.insert(s.blooms, { inst = b, Intensity = b.Intensity, Threshold = b.Threshold }) end
	end
	job.saved = s
	local parent = workspace.CurrentCamera or Lighting
	job.grade = Instance.new('ColorCorrectionEffect')
	job.grade.Name = 'HoodUnboxGrade'
	job.grade.Parent = parent
	job.bloom = Instance.new('BloomEffect')
	job.bloom.Name = 'HoodUnboxBloom'
	job.bloom.Intensity, job.bloom.Size, job.bloom.Threshold = 0, 24, 2
	job.bloom.Parent = parent
	job.blur = Instance.new('BlurEffect')
	job.blur.Name = 'HoodUnboxBlur'
	job.blur.Size = 0
	job.blur.Parent = parent
end
function Look.restore(job)
	local s = job.saved
	if not s then return end
	for k, v in s.light do pcall(function() (Lighting :: any)[k] = v end) end
	if s.atm and s.atm.inst.Parent and s.atm.inst ~= job.ownAtm then
		for k, v in s.atm.v do (s.atm.inst :: any)[k] = v end
	end
	if s.sky and s.sky.inst.Parent then
		s.sky.inst.StarCount = s.sky.StarCount
		s.sky.inst.CelestialBodiesShown = s.sky.CelestialBodiesShown
	end
	if s.rays and s.rays.inst.Parent then
		s.rays.inst.Intensity = s.rays.Intensity
		s.rays.inst.Spread = s.rays.Spread
	end
	for _, b in s.blooms or {} do
		if b.inst.Parent then
			b.inst.Intensity = b.Intensity
			b.inst.Threshold = b.Threshold
		end
	end
	for _, x in { job.grade, job.bloom, job.blur, job.ownAtm } do
		if x then x:Destroy() end
	end
	job.grade, job.bloom, job.blur, job.ownAtm = nil, nil, nil, nil
	job.saved = nil
end
-- The looks of this opening (each names only what it changes; the rest is the world's as saved) and their keyframes.
function Look.build(job)
	local P, th = job.P, job.P.theme
	local s = job.saved
	local world = { gB = 0, gC = 0, gS = 0, gT = WHITE, bI = 0, bS = 24, bT = 2, stars = s.sky and s.sky.StarCount or 0, rays = s.rays and s.rays.Intensity or 0 }
	for _, k in LIGHT_PROPS do world[k] = s.light[k] end
	for k, v in s.atm.v do world['a' .. k] = v end
	local function from(base, o)
		local L = table.clone(base)
		for k, v in o do L[k] = v end
		return L
	end
	local looks = { world = world }
	-- cash boxes: the day with a touch more contrast; the deluxe tiers tint it (Galaxy goes to night, Gold to golden hour)
	looks.day = from(world, { gC = 0.06, gS = 0.08 })
	local d = P.deluxe
	if d then
		looks.day = from(looks.day, { gT = d.tint, aColor = d.atm, aDecay = d.decay, aHaze = d.haze, aDensity = 0.3 })
		if d.night then
			looks.day = from(looks.day, { ClockTime = d.clock, Ambient = d.ambient, OutdoorAmbient = d.ambient, Brightness = 0.35, EnvironmentDiffuseScale = 0.05, stars = d.stars, bI = 0.8, bS = 28, bT = 0.95, gB = -0.04, gC = 0.14 })
		elseif d.clock then
			looks.day = from(looks.day, { ClockTime = d.clock, Ambient = C3(196, 178, 160), OutdoorAmbient = C3(200, 182, 164), Brightness = 0.55 })
		end
	end
	-- premium: NightTakeover (at the cut), Dip (before the flash), StageLit (under the flash)
	local nt, lt = th.Night or {}, th.Lit or {}
	local navy = (nt.ambient or th.Deep:Lerp(C3(90, 100, 150), 0.6)):Lerp(C3(150, 160, 200), 0.3)
	looks.night = from(world, {
		ClockTime = 0, Brightness = 0.6, Ambient = navy, OutdoorAmbient = navy, EnvironmentDiffuseScale = 0.05,
		aDensity = 0.28, aOffset = 0.25, aHaze = 1.4, aGlare = 0, aColor = nt.atm or th.Deep:Lerp(th.Color, 0.4), aDecay = nt.decay or th.Deep,
		stars = 3000, gB = 0.04, gC = 0.16, gS = 0.1, gT = C3(210, 220, 255), bI = 0.8, bS = 30, bT = 0.95,
	})
	looks.nightIn = from(looks.night, { gB = 0, gC = 0, gS = 0, gT = WHITE })
	looks.dip = from(looks.night, { gB = -0.45, gC = 0.35, gS = -0.7, gT = C3(200, 200, 220), bI = 1.2, bS = 36, bT = 0.9, Brightness = 0.3 })
	local lit = lt.ambient or th.Relit:Lerp(WHITE, 0.55)
	looks.lit = from(world, {
		ClockTime = lt.clock or 0, Brightness = 1.0, Ambient = lit, OutdoorAmbient = lit, EnvironmentDiffuseScale = 0.2,
		aDensity = 0.22, aOffset = 0.25, aHaze = 1.0, aGlare = 0.3, aColor = lt.atm or th.Relit, aDecay = lt.decay or th.Color,
		stars = lt.clock and 0 or 3000, gB = lt.dawn and 0.06 or 0.13, gC = lt.dawn and 0.2 or 0.15, gS = 0.25, gT = lt.tint or WHITE:Lerp(th.Relit, 0.08),
		bI = lt.dawn and 0.4 or 0.45, bS = lt.dawn and 30 or 26, bT = lt.dawn and 0.97 or 1.0, rays = lt.dawn and 0.12 or 0,
	})
	looks.exit = from(world, { gB = 0.1 })
	local keys = {}
	local function key(t, look, blur, ease) table.insert(keys, { t, look, blur or 0, ease or 'smooth' }) end
	if P.premium then
		key(0, looks.nightIn, 0)
		key(0.6, looks.night, 0, 'sineOut')
		key(P.dip[1], looks.night, 0)
		key(P.dip[2] - 0.01, looks.dip, 0, 'quadIn')
		key(P.flash + 0.02, looks.lit, 0, 'step')
	else
		local start = looks.day
		key(0, world, 0)
		key(P.cut - 0.001, world, 18, 'quadIn')
		if d and d.night then
			-- Galaxy: night falls while the box hangs and falls (15.5 -> 24 over 0.9 s: dusk, then the stars)
			local dusk = from(start, { ClockTime = 15.5, stars = 0, Ambient = world.Ambient, OutdoorAmbient = world.OutdoorAmbient, Brightness = world.Brightness, bI = 0 })
			key(P.cut, dusk, 18, 'step')
			key(P.clear, dusk, 0, 'quadOut')
			key(P.appear[1] - 0.05, dusk, 0)
			key(P.appear[1] + 0.85, start, 0, 'sineInOut')
		else
			key(P.cut, start, 18, 'step')
			key(P.clear, start, 0, 'quadOut')
		end
	end
	local hold = keys[#keys][2]
	key(P.out, hold, 0)
	key(P.out + 0.15, looks.exit, 20, 'quadIn')
	key(P.out + 0.151, looks.exit, 20, 'step')
	key(P.done, world, 0, 'quadOut')
	job.looks, job.lookKeys = looks, keys
	job.snapAt = P.out + 0.15
end
local EASE = {
	smooth = M.smooth, sineOut = function(u) return math.sin(u * PI / 2) end, quadIn = function(u) return u * u end,
	quadOut = function(u) return 1 - (1 - u) * (1 - u) end, sineInOut = M.sineInOut, step = function() return 1 end,
}
local function mix(a, b, u)
	if type(a) == 'number' then return a + (b - a) * u end
	if typeof(a) == 'Color3' then return a:Lerp(b, u) end
	return u < 0.5 and a or b
end
function Look.apply(job, t)
	local keys = job.lookKeys
	local i = 1
	while i < #keys and keys[i + 1][1] <= t do i += 1 end
	local a, b = keys[i], keys[math.min(i + 1, #keys)]
	local u = 1
	if b[1] > a[1] and t < b[1] then u = (EASE[b[4]] or M.smooth)(M.c01((t - a[1]) / (b[1] - a[1]))) end
	if t >= keys[#keys][1] then a, b, u = keys[#keys], keys[#keys], 1 end
	local A, B = a[2], b[2]
	local L = {}
	for k, v in A do L[k] = mix(v, B[k] ~= nil and B[k] or v, u) end
	L.blur = M.lerp(a[3], b[3], u)
	local P = job.P
	-- the slam's brightness pulse (one 80 ms bump, not a flash); a skip's blur-cut; the Secret's false calm (the world
	-- greys); its aurora once the pair is lit
	L.gB += job.pulse or 0
	if job.skipAt then L.blur = math.max(L.blur, 16 * M.bump(t, job.skipAt, 0.24)) end
	if P.slowmo and t >= P.slowmo[1] - 0.15 and t < P.accent[P.best] then
		local q = M.c01((t - (P.slowmo[1] - 0.15)) / 0.15)
		L.gS = M.lerp(L.gS, -0.8, q)
		L.gB = M.lerp(L.gB, -0.1, q)
	end
	-- the hold (from just before the reveal): bloom down and its threshold up, the grade eased back down after the flash;
	-- a light pair also gets the key and the fill down (key x0.65, fill x0.7), so it never clips to flat white
	local hq = M.c01((t - (P.accent[P.best] - 0.3)) / 0.5) * (1 - M.c01((t - P.out) / 0.15))
	if hq > 0 then
		local lp = job.lightPair
		L.bI *= M.lerp(1, lp and 0.3 or 0.6, hq)
		L.bT = math.min(2.5, L.bT + (lp and 0.45 or 0.25) * hq)
		L.pbK = M.lerp(1, lp and 0.35 or 0.7, hq)
		L.pbT = (lp and 0.45 or 0.2) * hq
		L.gB -= (lp and 0.09 or 0.04) * hq
		if lp then
			L.Brightness *= M.lerp(1, 0.8, hq)
			L.Ambient = L.Ambient:Lerp(BLACK, 0.15 * hq)
			L.OutdoorAmbient = L.OutdoorAmbient:Lerp(BLACK, 0.15 * hq)
			L.gC = M.lerp(L.gC, L.gC + 0.05, hq)
		end
	end
	if P.rank >= 6 and not P.gift and t > P.accent[P.best] and t < P.out then
		L.aColor = L.aColor:Lerp(M.hsv(t * 0.8, 0), 0.5)
	elseif P.premium and P.theme.Id == 'Exclusive' and t > P.flash and t < P.out then
		-- Exclusive: a cyan / magenta aurora in the night sky after the relight
		L.aColor = L.aColor:Lerp(C3(90, 230, 255):Lerp(C3(255, 130, 230), 0.5 + 0.5 * math.sin(t * 0.8)), 0.45)
	end
	job.cur = L
	local s = job.saved
	if not s then return end
	local function set(inst, prop, v)
		if v == nil or not inst then return end
		local ok, old = pcall(function() return (inst :: any)[prop] end)
		if not ok then return end
		if type(v) == 'number' and math.abs(old - v) < 1e-4 then return end
		if typeof(v) == 'Color3' and old == v then return end
		pcall(function() (inst :: any)[prop] = v end)
	end
	for _, k in LIGHT_PROPS do set(Lighting, k, L[k]) end
	for _, k in ATM_PROPS do set(s.atm.inst, k, L['a' .. k]) end
	if s.sky then set(s.sky.inst, 'StarCount', math.floor(L.stars + 0.5)) end
	if s.rays then set(s.rays.inst, 'Intensity', L.rays) end
	for _, b in s.blooms do
		set(b.inst, 'Intensity', b.Intensity * (L.pbK or 1))
		set(b.inst, 'Threshold', b.Threshold + (L.pbT or 0))
	end
	set(job.grade, 'Brightness', L.gB)
	set(job.grade, 'Contrast', L.gC)
	set(job.grade, 'Saturation', L.gS)
	set(job.grade, 'TintColor', L.gT)
	set(job.bloom, 'Intensity', L.bI)
	set(job.bloom, 'Size', L.bS)
	set(job.bloom, 'Threshold', L.bT)
	set(job.blur, 'Size', L.blur)
end

---------------------------------------------------------------------------------------------- the camera
-- Shots (stage space: eye, target, FOV) eased together, handheld drift (rotation noise), trauma shake (events add
-- trauma that decays linearly; shake = trauma^2 x noise, rotation more than translation; caps: roll <= 4 deg, pitch
-- <= 3), directional kicks, FOV punches, Focus on the pad every frame (the stage's lights render around the focus).
local Cam = {}
local SHAKE = {
	land = { 2.5, 1.2, 4.0, 0.25, 2.5, 18 }, slam = { 2.5, 1.2, 4.0, 0.35, 1.5, 16 }, blast = { 2.5, 1.2, 4.0, 0.3, 1.8, 16 },
	pop = { 2.5, 1.2, 4.0, 0.15, 3, 20 }, reveal = { 2.5, 1.2, 4.0, 0.2, 2, 16 },
}
-- The hero distance: the pair fills ~40 % of the screen's height and <= 70 % of a 16:9 width (it turns, so its widest
-- side counts), plus half its depth.
local function heroDist(pair, fov)
	local t = math.tan(RAD(fov / 2))
	local dv = pair.height / (2 * 0.4 * t)
	local dh = pair.width / (2 * 0.7 * t * 16 / 9)
	return math.max(dv, dh) + pair.depth * 0.5
end
function Cam.build(job)
	local P = job.P
	local keys = {}
	local function shot(t, eye, at, fov, ease) table.insert(keys, { t, eye, at, fov, ease or 'cubic' }) end
	local n = P.n
	local b1 = job.boxes[P.best]
	local pb = job.pairs[P.best]
	local h = pb.height
	-- a hero eye at `yaw` (positive: the camera on the stage's +X side, the screen's left), `dist` from the pair's axis
	local function heroEye(yaw, dist, y) return V3(math.sin(yaw) * dist, y, -math.cos(yaw) * dist) end
	local hoverY = P.homes[P.best].Y + b1.seamY + P.riseH + pb.base + h * 0.5
	job.hoverY = hoverY
	if n == 1 and not P.premium then
		-- the box (with its topper) fills ~55 % of the height once down; the frame first leans up so the hang is in it, then
		-- follows the drop down
		local d0 = math.max(16, b1.fullH / (0.55 * 2 * math.tan(RAD(30))) + b1.D * 0.5)
		local eyeY = 3.3
		local mid = P.homes[1].Y + b1.fullH * 0.48
		local hangTop = P.homes[1].Y + P.fallH + b1.fullH + 0.9
		local lookY0 = math.max(mid, eyeY + d0 * math.tan(math.atan((hangTop - eyeY) / d0) - RAD(30)))
		shot(0, V3(0, eyeY, -d0), V3(0, lookY0 + 0.6, 0), 60)
		shot(P.fall0[1], V3(0, eyeY, -d0), V3(0, lookY0, 0), 60, 'sine')
		shot(P.land[1], V3(0, eyeY, -d0), V3(0, mid + 0.3, 0), 60, 'quadIn')
		shot(1.3, V3(0, eyeY, -d0), V3(0, mid, 0), 60)
		shot(2.4, V3(-1.2, eyeY + 0.2, -d0 * 0.875), V3(0, mid - 0.2, 0), 60, 'sine')
		shot(P.rise[1] + 0.1, V3(-1.2, eyeY + 0.2, -d0 * 0.875), V3(0, mid, 0), 60)
		-- N1 -> H: one 700 ms Cubic InOut dolly with ~25 deg of yaw, to a 3/4 view from the left
		local hd = heroDist(pb, 50)
		local aim = V3(0, hoverY - 0.08 * h, 0)
		shot(P.rise[1] + 0.8, heroEye(UnboxCinematic.HeroYaw.normal, hd, hoverY + 0.1 * h), aim, 50)
		shot(P.out, heroEye(UnboxCinematic.HeroYaw.normal - RAD(4), hd * 1.01, hoverY + 0.1 * h), aim, 50, 'sine')
		job.heroYaw = UnboxCinematic.HeroYaw.normal
		job.heroShot = { heroEye(job.heroYaw, hd, hoverY + 0.1 * h), aim, 50 }
	elseif n == 1 then
		-- P1 low wide (the sky fills the top), up toward the comet, down with the slam; P2 the charge (push-in and
		-- orbit); the dark beat creeps in; H the hero
		local d0 = math.max(24, b1.fullH * 2.2)
		local up = function(deg) return V3(0, 4.7 + d0 * math.tan(RAD(deg)), 0) end
		shot(0, V3(0, 4.7, -d0), up(12), 62)
		shot(P.appear[1], V3(0, 4.7, -d0), up(12), 62)
		shot(P.fall0[1], V3(0, 4.7, -d0), up(17), 62, 'sine')
		shot(P.land[1], V3(0, 4.7, -d0), V3(0, 4.2, 0), 66, 'quadIn')
		shot(1.5, V3(0, 4.7, -d0), V3(0, 3.6, 0), 60)
		-- the charge: the box (and its rings) fill ~60 % of the height, pushing in and orbiting
		local c = V3(0, 0.22 + b1.fullH * 0.45, 0)
		local D = b1.fullH / (0.6 * 2 * math.tan(RAD(29))) + b1.D * 0.5
		local function orbit(dist, deg, upY)
			local a = RAD(deg)
			return V3(math.sin(a) * dist, c.Y + upY, -math.cos(a) * dist)
		end
		shot(1.9, orbit(D * 1.2, 25, 1.6), c + V3(0, 0.3, 0), 58)
		shot(P.dip[1], orbit(D, 40, 1.4), c + V3(0, 0.3, 0), 58, 'sine')
		shot(P.dip[2], orbit(D * 0.95, 41, 1.3), c + V3(0, 0.3, 0), 54, 'quadIn')
		-- under the flash: a cut to a low 3/4 from the right; the pair rises in silhouette into the hero framing, then the
		-- camera keeps orbiting at 6 deg/s through the hold
		shot(P.flash + 0.03, orbit(D * 0.95, 41, 1.3), c + V3(0, 0.3, 0), 54)
		shot(P.flash + 0.031, heroEye(RAD(-34), D * 0.9, c.Y + 0.2), c + V3(0, 1.4, 0), 56)
		local hd = heroDist(pb, 50)
		local t1 = P.rise[1] + 1.2
		local yaw0 = UnboxCinematic.HeroYaw.premium
		local aim = V3(0, hoverY - 0.06 * h, 0)
		shot(t1, heroEye(yaw0, hd, hoverY - 0.1 * h), aim, 50)
		shot(P.out, heroEye(yaw0 + RAD(6) * (P.out - t1), hd * 1.01, hoverY - 0.1 * h), aim, 50, 'lin')
		job.heroYaw = yaw0
		job.heroShot = { heroEye(yaw0, hd, hoverY - 0.1 * h), aim, 50 }
	else
		-- a row: framed by width (the row fills ~80 % of the screen) and by the tallest box; leaning up first so the hanging
		-- boxes are in the frame; the group shot after the opens frames the pairs (~85 % of the width)
		local minX, maxX = math.huge, -math.huge
		for _, p in P.homes do minX, maxX = math.min(minX, p.X), math.max(maxX, p.X) end
		local fullH, pairW, top = 0, 0, 0
		for i, b in job.boxes do
			fullH = math.max(fullH, b.fullH)
			pairW = math.max(pairW, job.pairs[i].width)
			top = math.max(top, P.homes[i].Y)
		end
		local rowW = (maxX - minX) + P.boxW
		local fov = P.premium and 62 or 60
		local tv = math.tan(RAD(fov / 2))
		local d = math.max(rowW / 0.8 / (2 * tv * 16 / 9), (fullH + top) / 0.55 / (2 * tv)) + (n >= 5 and 3 or 1.5)
		local midY = 0.22 + (fullH + top) * 0.45
		local eyeY = midY + (n >= 5 and 2.6 or 1)
		local look = V3(0, midY, n >= 5 and 1.8 or 0)
		local hangTop = top + P.fallH + fullH + 0.9
		local lookY0 = math.max(midY, eyeY + d * math.tan(math.atan((hangTop - eyeY) / d) - RAD(fov / 2)))
		if P.premium then
			shot(0, V3(0, 4.7, -d * 1.25), look + V3(0, 9, 0), 64)
			shot(P.land[1] - 0.2, V3(0, 4.7, -d * 1.25), look + V3(0, 4, 0), 64, 'sine')
			shot(P.lastLand + 0.25, V3(0, eyeY, -d * 1.1), look, 62)
			shot(P.charge[1], V3(-3, eyeY + 1, -d), look, 60)
			shot(P.dip[1], V3(3, eyeY + 0.6, -d * 0.92), look, 60, 'sine')
			shot(P.dip[2], V3(3, eyeY + 0.6, -d * 0.9), look, 56, 'quadIn')
		else
			shot(0, V3(0, eyeY, -d), V3(look.X, lookY0 + 0.5, look.Z), fov)
			shot(P.fall0[1], V3(0, eyeY, -d), V3(look.X, lookY0, look.Z), fov, 'sine')
			shot(P.lastLand + 0.15, V3(0, eyeY, -d), look, fov, 'sine')
			shot(P.group - 0.35, V3(-1, eyeY - 0.3, -d * 0.95), look, fov, 'sine')
		end
		if n >= 5 and job.lineY then
			-- a Buy 8: the whole line-up (back row, the best front and centre between two) fills ~85 % of the width, in
			-- the middle band of the frame (the banner above it, the name and the chip below it)
			local yF, yB, ph = job.lineY[1], job.lineY[2], job.lineY[3]
			local gf = 52
			local gt = math.tan(RAD(gf / 2))
			local gd = job.lineW / 0.85 / (2 * gt * 16 / 9)
			local tgt = V3(0, yF + (yB - yF + ph + 1.2) * 0.5, 0.4)
			local eye = V3(0.5, tgt.Y + gd * 0.14, tgt.Z - gd)
			shot(P.group + 0.25, eye, tgt, gf)
			shot(P.out, V3(-0.4, tgt.Y + gd * 0.14, tgt.Z - gd * 1.02), tgt, gf, 'sine')
			job.heroShot = { eye, tgt, gf }
		else
			-- the group: the pairs' row at their hover height, the best (stepping forward) at the centre
			local hy, cnt = 0, 0
			for i, pr in job.pairs do
				hy += P.homes[i].Y + job.boxes[i].seamY + P.riseH + pr.base + pr.height * 0.5
				cnt += 1
			end
			hy /= cnt
			local gf = 52
			local gt = math.tan(RAD(gf / 2))
			local pRow = (maxX - minX) * UnboxCinematic.Gather + pairW * 1.1
			local tgt = V3(0, hy, -0.5)
			if n == 2 and job.slots then
				pRow = 6 + pairW * 1.7
				tgt = V3(-0.4, hy, -0.2)
			end
			local gd = pRow / 0.85 / (2 * gt * 16 / 9) + 1.5
			local eye = V3(0.5, hy + gd * 0.12, -gd)
			shot(P.group + 0.25, eye, tgt, gf)
			shot(P.out, V3(-0.6, hy + gd * 0.12, -gd * 1.02), tgt, gf, 'sine')
			job.heroShot = { eye, tgt, gf }
		end
	end
	table.sort(keys, function(a, b) return a[1] < b[1] end)
	job.camKeys = keys
	job.shakes, job.punches, job.kicks = job.shakes or {}, job.punches or {}, job.kicks or {}
	job.focus = job:w(V3(0, 2, 0))
end
function Cam.shake(job, t0, preset, add)
	if job.P.reduced then return end
	table.insert(job.shakes, { t0, add, SHAKE[preset] or SHAKE.land })
end
function Cam.punch(job, t0, deg, attack, f, z)
	if job.P.reduced then return end
	table.insert(job.punches, { t0, deg, attack or 0.06, f or 2.5, z or 0.55 })
end
function Cam.kick(job, t0, pitch, dy)
	if job.P.reduced then return end
	table.insert(job.kicks, { t0, pitch, dy })
end
local CAMEASE = { cubic = M.inout, sine = M.sineInOut, quadIn = function(u) return M.c01(u) ^ 2 end, lin = M.c01 }
function Cam.at(job, t)
	local P = job.P
	local keys = job.camKeys
	local i = 1
	while i < #keys and keys[i + 1][1] <= t do i += 1 end
	local a, b = keys[i], keys[math.min(i + 1, #keys)]
	local u = 1
	if b[1] > a[1] then u = (CAMEASE[b[5]] or M.inout)((t - a[1]) / (b[1] - a[1])) end
	if t >= keys[#keys][1] then a, b, u = keys[#keys], keys[#keys], 1 end
	local eye, at = a[2]:Lerp(b[2], u), a[3]:Lerp(b[3], u)
	local fov = M.lerp(a[4], b[4], u)
	local cf = CFrame.lookAt(job:wp(eye), job:wp(at))
	-- handheld drift (rotation only), doubled during a premium charge
	local hh = (P.premium and t > P.charge[1] and t < P.dip[2]) and 2 or 1
	local pitch = M.noise(1.1, t * 0.3 * hh) * 0.15 * hh
	local yaw = M.noise(2.3, t * 0.3 * hh) * 0.15 * hh
	local roll = M.noise(3.7, t * 0.3 * hh) * 0.1 * hh
	local ox, oy = 0, 0
	local T = 0
	local preset = SHAKE.land
	for _, s in job.shakes do
		local tau = t - s[1]
		if tau >= 0 then
			local v = s[2] - s[3][5] * tau
			if v > 0 then
				T += v
				if v > 0.1 then preset = s[3] end
			end
		end
	end
	-- the charge's rumble: a held trauma 0.2 -> 0.45 (the only sustained shake)
	if P.premium and not P.reduced and t > P.charge[1] and t < P.flash then
		local q = M.c01((t - P.charge[1]) / (P.charge[2] - P.charge[1]))
		T = math.max(T, (t > P.dip[1] and 0.6 or M.lerp(0.2, 0.45, q)) * 0.55)
	end
	T = math.min(1, T)
	local s = T * T
	if s > 0 then
		local sp = preset[6]
		pitch += preset[1] * s * M.noise(11.3, t * sp)
		yaw += preset[2] * s * M.noise(12.7, t * sp)
		roll += preset[3] * s * M.noise(13.9, t * sp)
		ox += preset[4] * s * M.noise(14.1, t * sp)
		oy += preset[4] * s * M.noise(15.5, t * sp)
	end
	for _, k in job.kicks do
		local tau = t - k[1]
		if tau >= 0 and tau < 0.6 then
			local sp = M.spring(tau, 6, 0.45)
			pitch += k[2] * sp
			oy += k[3] * sp
		end
	end
	pitch, roll = math.clamp(pitch, -3, 3), math.clamp(roll, -4, 4)
	cf = cf * CF(ox, oy, 0) * CFrame.fromEulerAnglesYXZ(RAD(pitch), RAD(yaw), RAD(roll))
	for _, p in job.punches do
		local tau = t - p[1]
		if tau >= 0 and tau < 1.2 then
			if tau < p[3] then fov += p[2] * M.out(tau / p[3], 2) else fov += p[2] * M.spring(tau - p[3], p[4], p[5]) end
		end
	end
	-- a Secret single: a dolly-zoom through the false calm (FOV x0.7 while the camera backs off to keep the pair's size)
	if P.rank >= 6 and P.n == 1 and P.slowmo and not P.reduced then
		local q = M.sineInOut((t - P.slowmo[1]) / 0.6) * (1 - M.c01((t - P.accent[P.best]) / 0.4))
		if q > 0 then
			local f0 = fov
			fov = M.lerp(f0, f0 * 0.7, q)
			local k = math.tan(RAD(f0 / 2)) / math.tan(RAD(fov / 2))
			local target = job:wp(V3(0, job.hoverY, 0))
			cf = cf + (cf.Position - target) * (k - 1)
		end
	end
	return cf, math.clamp(fov, 30, 80)
end

---------------------------------------------------------------------------------------------- the words (GUI)
local Words = {}
local function font(name)
	if UIKit and UIKit.Font and UIKit.Font[name] then return UIKit.Font[name] end
	return Font.new('rbxasset://fonts/families/FredokaOne.json')
end
local function label(parent, props)
	local t = Instance.new('TextLabel')
	t.BackgroundTransparency = 1
	t.BorderSizePixel = 0
	t.TextScaled = false
	t.TextTransparency = 1
	t.TextColor3 = WHITE
	t.FontFace = props.FontFace or font('reveal')
	for k, v in props do
		if k ~= 'Stroke' and k ~= 'StrokeThickness' and k ~= 'FontFace' then (t :: any)[k] = v end
	end
	local s = Instance.new('UIStroke')
	s.Color = props.Stroke or C3(20, 16, 30)
	s.Thickness = props.StrokeThickness or 4
	s.LineJoinMode = Enum.LineJoinMode.Round
	s.Transparency = 1
	s.Parent = t
	t.Parent = parent
	return t
end
local function fadeText(l, a)
	local tr = 1 - M.c01(a)
	if l.TextTransparency ~= tr then
		l.TextTransparency = tr
		local s = l:FindFirstChildOfClass('UIStroke')
		if s then s.Transparency = tr end
	end
end
local function gradient(parent, colors, rot)
	local g = Instance.new('UIGradient')
	g.Color = typeof(colors) == 'ColorSequence' and colors or seqOf(colors)
	g.Rotation = rot or 90
	g.Parent = parent
	return g
end
local function frame(parent, name, props)
	local f = Instance.new('Frame')
	f.Name = name
	f.BorderSizePixel = 0
	f.BackgroundColor3 = WHITE
	f.BackgroundTransparency = 1
	for k, v in props or {} do (f :: any)[k] = v end
	f.Parent = parent
	return f
end
local function band(parent, name, top)
	local f = frame(parent, name, {
		BackgroundColor3 = C3(8, 8, 16), AnchorPoint = Vector2.new(0, top and 0 or 1),
		Position = top and UDim2.fromOffset(-140, -140) or UDim2.new(0, -140, 1, 140), Size = UDim2.new(1, 280, 0, top and 320 or 340), ZIndex = 20,
	})
	local g = Instance.new('UIGradient')
	g.Rotation = top and 90 or -90
	g.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.45, 0.3), NumberSequenceKeypoint.new(1, 1) })
	g.Parent = f
	return f
end
function Words.build(job)
	local P = job.P
	local root = job.gui and (job.gui:FindFirstChild('Root') or job.gui)
	local stage = frame(root, 'Unboxed', { Size = UDim2.fromScale(1, 1), ZIndex = 1 })
	job.stageGui = stage
	local W = { y0 = {} }
	job.words = W
	local best = P.list[P.best]
	local sd = shoeDef(best.Shoe)
	local rank = P.rank
	local rcol = rarityColor(rank)
	W.flash = frame(stage, 'Flash', { Position = UDim2.fromOffset(-140, -140), Size = UDim2.new(1, 280, 1, 280), ZIndex = 40 })
	W.softColor = rcol:Lerp(WHITE, 0.45)
	W.bandTop, W.bandBot = band(stage, 'BandTop', true), band(stage, 'BandBot', false)
	-- the edge glow (Mythic and up): bands fading in from the four edges
	W.edges = {}
	if P.R.Edge then
		for _, e in { { Vector2.zero, UDim2.fromOffset(-140, -140), UDim2.new(1, 280, 0.24, 140), 90 }, { Vector2.new(0, 1), UDim2.new(0, -140, 1, 140), UDim2.new(1, 280, 0.24, 140), -90 },
			{ Vector2.zero, UDim2.fromOffset(-140, -140), UDim2.new(0.14, 140, 1, 280), 0 }, { Vector2.new(1, 0), UDim2.new(1, 140, 0, -140), UDim2.new(0.14, 140, 1, 280), 180 } } do
			local f = frame(stage, 'Edge', { AnchorPoint = e[1], Position = e[2], Size = e[3], ZIndex = 2 })
			local g = Instance.new('UIGradient')
			g.Rotation = e[4]
			g.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.5, 0.65), NumberSequenceKeypoint.new(1, 1) })
			g.Parent = f
			table.insert(W.edges, f)
		end
	end
	-- the banner: the rarity word slams in, its size growing with the rarity, in its colour with a dark stroke
	local rname = string.upper(rarityRow(rank).Name or 'Common')
	local big = 72 + rank * 5
	W.rarity = label(stage, { Name = 'Rarity', Text = rname .. '!', TextSize = big, StrokeThickness = 7, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0, 80), Size = UDim2.new(1, 0, 0, big + 16), ZIndex = 32 })
	W.rarityScale = Instance.new('UIScale')
	W.rarityScale.Scale = 1.6
	W.rarityScale.Parent = W.rarity
	if rank >= 6 then
		W.rarityGrad = gradient(W.rarity, rainbowSeq(0), 0)
	elseif rank == 1 then
		gradient(W.rarity, { WHITE, C3(214, 220, 230) }, 90)
	elseif P.box == 'Exclusive' then
		gradient(W.rarity, { C3(150, 240, 255), WHITE:Lerp(rcol, 0.3), C3(255, 150, 230) }, 0)
	else
		gradient(W.rarity, { WHITE:Lerp(rcol, 0.35), rcol, rcol:Lerp(BLACK, 0.12) }, 90)
	end
	local below = 80 + big * 0.6
	if P.multi then
		local box = boxDef(P.box)
		W.sub = label(stage, { Name = 'Count', Text = P.gift and 'Welcome gift!' or ((box and box.Name or 'Box') .. '  x' .. P.n), TextSize = 30, StrokeThickness = 4, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0, below + 8), Size = UDim2.new(1, 0, 0, 36), ZIndex = 32 })
		gradient(W.sub, { C3(255, 242, 122), C3(255, 168, 26) }, 90)
	end
	-- (the gift's best pair stands centre-left: its name and chip sit under it)
	local nameX = P.n == 2 and 0.28 or 0.5
	W.name = label(stage, { Name = 'Name', Text = sd and sd.Name or tostring(best.Shoe), TextSize = P.multi and 46 or 58, StrokeThickness = 6, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(nameX, 0, 1, P.multi and -64 or -74), Size = UDim2.new(1, 0, 0, 64), ZIndex = 32 })
	W.bonusValue = sd and sd.Bonus or 0
	W.bonus = label(stage, { Name = 'Bonus', Text = '+0% Power', TextSize = P.multi and 32 or 38, StrokeThickness = 5, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(nameX, 0, 1, P.multi and -26 or -30), Size = UDim2.new(1, 0, 0, 44), ZIndex = 32 })
	W.bonusScale = Instance.new('UIScale')
	W.bonusScale.Parent = W.bonus
	-- the Power chip: the bonus drops into it from the name's line, then counts up (a tick a step)
	W.chip = frame(stage, 'PowerChip', { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(nameX, 0, 1, P.multi and -20 or -24), Size = UDim2.fromOffset(310, 56), BackgroundColor3 = C3(18, 16, 30), ZIndex = 31 })
	local cc = Instance.new('UICorner')
	cc.CornerRadius = UDim.new(0.5, 0)
	cc.Parent = W.chip
	W.chipStroke = Instance.new('UIStroke')
	W.chipStroke.Color = rank >= 6 and C3(255, 236, 120) or rcol:Lerp(WHITE, 0.2)
	W.chipStroke.Thickness = 3
	W.chipStroke.Transparency = 1
	W.chipStroke.Parent = W.chip
	W.chipScale = Instance.new('UIScale')
	W.chipScale.Parent = W.chip
	if rank >= 6 then gradient(W.bonus, rainbowSeq(2), 0) else gradient(W.bonus, { WHITE, rcol:Lerp(WHITE, 0.3) }, 90) end
	local note
	if best.Equipped then note = 'EQUIPPED!' elseif best.Better then note = 'BETTER! Put it on in Shoes' elseif not P.multi and (best.Count or 1) > 1 then note = 'You have x' .. tostring(best.Count) end
	if note then
		W.note = label(stage, { Name = 'Note', Text = note, TextSize = 36, StrokeThickness = 4.5, TextColor3 = (best.Equipped or best.Better) and C3(124, 255, 79) or WHITE, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0, below + (P.multi and 50 or 18)), Size = UDim2.new(1, 0, 0, 42), ZIndex = 32 })
	end
	if best.New then
		W.new = label(stage, { Name = 'New', Text = 'NEW!', TextSize = 44, StrokeThickness = 5, TextColor3 = C3(124, 255, 79), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, math.max(220, (#rname + 1) * big * 0.31 + 95), 0, 62), Size = UDim2.fromOffset(170, 56), Rotation = -12, ZIndex = 33 })
	end
	W.tap = label(stage, { Name = 'Tap', Text = 'Tap to skip', TextSize = 22, StrokeThickness = 3, TextColor3 = C3(230, 230, 240), FontFace = font('body'), AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -24, 1, -14), Size = UDim2.fromOffset(260, 30), TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 34 })
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
	-- a multi-open's tags under the other pairs (rarity word, NEW!) ride the pairs as billboards
	W.tags = {}
	if P.multi then
		for i, pair in job.pairs do
			if i ~= P.best then
				local r = pair.rank
				local bb = Instance.new('BillboardGui')
				bb.Name = 'PairTag'
				bb.Size = UDim2.fromScale(P.n >= 5 and math.min(4.6, (job.lineSp or 5) * 0.92) or 5.4, P.n >= 5 and 1.3 or 1.7)
				-- just under the soles (the pair's root is at its base); a Buy 8's back row: over the heads, clear of the
				-- front row
				local over = job.backRow and job.backRow[i]
				bb.StudsOffsetWorldSpace = over and V3(0, pair.base + pair.height + 0.75, 0) or V3(0, pair.base - (P.n >= 5 and 0.9 or 1.3), 0)
				bb.AlwaysOnTop = true
				bb.LightInfluence = 0
				bb.Enabled = false
				local l = label(bb, { Name = 'Tag', Text = string.upper(rarityRow(r).Name or ''), TextSize = 24, StrokeThickness = 3, Size = UDim2.fromScale(1, 0.62), ZIndex = 2 })
				l.TextScaled = true
				fadeText(l, 1)
				if r >= 6 then gradient(l, rainbowSeq(0), 0) else gradient(l, { WHITE, rarityColor(r) }, 90) end
				if pair.entry.New then
					local nw = label(bb, { Name = 'New', Text = 'NEW!', TextSize = 18, StrokeThickness = 2.5, TextColor3 = C3(124, 255, 79), Position = UDim2.fromScale(0, 0.6), Size = UDim2.fromScale(1, 0.4), ZIndex = 2 })
					nw.TextScaled = true
					fadeText(nw, 1)
				end
				local root = pair.model.PrimaryPart or pair.actor.parts[1]
				bb.Adornee = root
				bb.Parent = root
				W.tags[i] = bb
			end
		end
	end
end
function Words.update(job, t)
	local P, W = job.P, job.words
	if not W then return end
	-- white flashes (<= 0.22 s: a 30 ms attack, a 40 ms hold, a Quad Out decay) and the soft ones
	local fa = 0
	local soft = false
	for li, list in { P.flashes, P.soft } do
		for _, f in list do
			local tau, dur = t - f[1], f[3]
			if tau >= 0 and tau < dur then
				local a
				-- (a 0.6 attack, a 30 ms peak, a fast Cubic decay: only the peak frame and one more read as full white)
				if tau < 0.03 then a = 0.6 * tau / 0.03 elseif tau < 0.06 then a = 1 else a = 1 - M.out((tau - 0.06) / (dur - 0.06), 3) end
				if f[2] * a > fa then
					fa = f[2] * a
					soft = li == 2
				end
			end
		end
	end
	local fc = soft and (W.softColor or WHITE) or WHITE
	if W.flash.BackgroundColor3 ~= fc then W.flash.BackgroundColor3 = fc end
	local ft = 1 - M.c01(fa)
	if W.flash.BackgroundTransparency ~= ft then W.flash.BackgroundTransparency = ft end
	local outA = 1 - M.c01((t - P.out) / 0.15)
	-- the banner: scale 1.6 -> 1 (Back Out 220 ms) with an 80 ms fade-in; Legendary and up pulse once
	local s = M.lerp(1.6, 1, M.back((t - P.banner) / 0.22, 2.0))
	if P.rank >= 4 then s *= 1 + 0.06 * M.bump(t, P.banner + 0.5, 0.25) end
	W.rarityScale.Scale = s
	fadeText(W.rarity, M.c01((t - P.banner) / 0.08) * outA)
	if W.rarityGrad then W.rarityGrad.Offset = Vector2.new((t * 0.5) % 1 - 0.5, 0) end
	local bandA = M.c01((t - P.banner + 0.1) / 0.25) * outA * 0.62
	if math.abs(W.bandTop.BackgroundTransparency - (1 - bandA)) > 1e-3 then
		W.bandTop.BackgroundTransparency = 1 - bandA
		W.bandBot.BackgroundTransparency = 1 - bandA
	end
	if W.sub then fadeText(W.sub, M.c01((t - P.banner - 0.08) / 0.18) * outA) end
	local function line(l, at, dy)
		if not l then return end
		local q = M.c01((t - at) / 0.2)
		fadeText(l, q * outA)
		W.y0[l] = W.y0[l] or l.Position.Y.Offset
		local y = W.y0[l] + (dy or 12) * (1 - M.out(q, 4))
		if l.Position.Y.Offset ~= y then l.Position = UDim2.new(l.Position.X.Scale, l.Position.X.Offset, l.Position.Y.Scale, y) end
	end
	line(W.name, P.nameT)
	-- the chip pops (Back Out 250 ms) as the bonus drops into it from the name's line
	local cT = P.count[1] - 0.15
	local cq = M.c01((t - cT) / 0.25)
	W.chipScale.Scale = cq > 0 and M.back(cq, 1.8) or 0.01
	local chipT = 1 - 0.8 * cq * outA
	if math.abs(W.chip.BackgroundTransparency - chipT) > 1e-3 then
		W.chip.BackgroundTransparency = chipT
		W.chipStroke.Transparency = 1 - cq * outA
	end
	line(W.bonus, cT, -46)
	line(W.note, P.nameT + 0.1)
	-- the bonus counts up (Quart Out), a little tick each step
	-- (it counts from the moment it shows: never a "+0%" sitting there)
	local q = M.c01((t - P.count[1] + 0.15) / (P.count[2] - P.count[1] + 0.15))
	local v = math.floor(W.bonusValue * M.out(q, 4) + 0.5)
	local str = '+' .. tostring(v) .. '% Power'
	if W.bonus.Text ~= str then
		W.bonus.Text = str
		W.tickAt = t
	end
	W.bonusScale.Scale = 1 + 0.06 * (1 - M.c01((t - (W.tickAt or -1)) / 0.08))
	if W.new then
		local nu = (t - P.newT) / 0.26
		fadeText(W.new, M.c01(nu * 4) * outA)
		local ns = M.back(nu, 2.4)
		W.new.Size = UDim2.fromOffset(170 * ns, 56 * ns)
		W.new.Rotation = -12 + math.sin(math.max(0, t - P.newT) * 5) * 4
	end
	-- the hint: "Tap to skip" while it builds, "Tap to continue" once it can end
	local reveal = t >= P.tap
	local tapText = reveal and 'Tap to continue' or 'Tap to skip'
	if W.tap.Text ~= tapText then W.tap.Text = tapText end
	local ta
	if reveal then ta = M.c01((t - P.tap) / 0.3) * (0.6 + 0.3 * math.sin((t - P.tap) * 2 * PI)) else ta = (t > 0.8 and t < P.banner - 0.2) and 0.45 or 0 end
	fadeText(W.tap, ta * outA)
	for i, e in W.edges do
		local pulse = M.bump(t, P.accent[P.best], 0.5) + M.bump(t, P.accent[P.best] + 1, 0.5)
		e.BackgroundTransparency = 1 - (0.25 + 0.15 * pulse) * M.c01((t - P.accent[P.best]) / 0.2) * outA
		e.BackgroundColor3 = P.rank >= 6 and M.hsv(t, i * 2) or rarityColor(P.rank)
	end
	for i, bb in W.tags do
		local on = t >= (P.accent[i] or P.group) and t < P.out + 0.1
		if bb.Enabled ~= on then bb.Enabled = on end
		if on then
			for _, l in bb:GetChildren() do
				if l:IsA('TextLabel') then fadeText(l, M.c01((t - P.accent[i]) / 0.15) * outA) end
			end
		end
	end
	job.stageGui:SetAttribute('T', t)
end

---------------------------------------------------------------------------------------------- the build
local Build = {}
-- An emitter from a theme recipe (UnboxThemes: { tex, rate, colors, life, size, speed, grav, emission, transparency,
-- rods, bubbles, nebula }) on `host`, its rate scaled by k.
function Build.recipe(job, name, a, host, k)
	local s0, s1 = a.size[1], a.size[2]
	local o = { life = a.life, speed = a.speed, spread = Vector2.new(60, 60), accel = V3(0, -(a.grav or 0), 0), drag = 0.5, emission = a.emission or 0.6, rate = a.rate * (k or 1) }
	if a.tex == 'spark' then
		o.size = nseq({ { 0, 0 }, { 0.3, s1, s1 * 0.3 }, { 0.75, s0 }, { 1, 0 } })
		o.transparency = nseq({ { 0, 1 }, { 0.2, 0.05 }, { 0.8, 0.2 }, { 1, 1 } })
		o.brightness = 1.5
		if a.rods then o.squash = NumberSequence.new(2.5); o.rotSpeed = NR(-300, 300); o.emission = 0; o.lightInfluence = 0.4 end
	elseif a.tex == 'ring' then
		o.size = nseq({ { 0, s0 }, { 1, s1 } })
		o.transparency = nseq({ { 0, 1 }, { 0.15, 0.2 }, { 0.85, 0.3 }, { 1, 1 } })
		o.rotSpeed = NR(0)
	elseif a.tex == 'smoke' then
		o.size = nseq({ { 0, s0 * 0.6 }, { 1, s1 } })
		local t0 = a.transparency or 0.5
		o.transparency = nseq({ { 0, 1 }, { 0.3, t0 }, { 0.7, M.lerp(t0, 1, 0.3) }, { 1, 1 } })
		if a.nebula then
			o.orientation = Enum.ParticleOrientation.VelocityPerpendicular
			o.rotSpeed = NR(50, 70)
			o.direction = Enum.NormalId.Top
			o.spread = Vector2.zero
		end
	else
		o.size = nseq({ { 0, s0 * 0.5 }, { 0.4, s0 }, { 1, s1 } })
		local t0 = a.transparency or 0.4
		o.transparency = nseq({ { 0, 1 }, { 0.25, t0 }, { 0.7, M.lerp(t0, 1, 0.3) }, { 1, 1 } })
	end
	return job:emitter(name, a.tex, seqOf(a.colors), o, host)
end
function Build.effects(job)
	local P, th = job.P, job.P.theme
	local rcol = rarityColor(P.rank)
	local fx = {}
	job.fx = fx
	fx.core = Preset.core(job, 'Core', (P.premium and 12 or 6) * G * 0.75, th.Color:Lerp(WHITE, 0.5))
	fx.shock = Preset.shock(job, 'Shock', (P.premium and 14 or 7) * G * (P.multi and 0.75 or 1), P.premium and 0.45 or 0.35, th.Color:Lerp(WHITE, 0.4))
	fx.shock2 = P.premium and Preset.shock(job, 'Shock2', 11 * G * (P.multi and 0.75 or 1), 0.45, th.Color) or nil
	fx.dust = Preset.dust(job, 'Dust', th.Color:Lerp(C3(200, 200, 200), 0.7), P.premium)
	-- (normal landings: one concrete puff per direction, born just outside the box's base and pushed outward, drawn a
	-- little toward the camera so the box never hides the near ones)
	fx.puffRing = job:emitter('LandPuff', 'smoke', seqOf({ C3(190, 185, 180), C3(170, 166, 162) }), {
		life = { 0.6, 0.85 }, speed = { 10, 14 }, drag = 5, accel = V3(0, 1.5, 0), spread = Vector2.new(8, 8), direction = Enum.NormalId.Front,
		lightInfluence = 0, emission = 0, size = nseq({ { 0, 1.5 * G * 0.8, 0.2 }, { 1, 4.5 * G * 0.8 } }),
		transparency = nseq({ { 0, 1 }, { 0.05, 0.2 }, { 0.6, 0.55 }, { 1, 1 } }), rotSpeed = NR(-50, 50), zoffset = 1,
	})
	-- landings: a thin, even ring edge racing out over the pad (a beam circle, not a glow disc); premium on top of its
	-- floor glow, out to 14 studs
	job.slamRings = {}
	for i = 1, P.n do
		if i == P.n or P.n <= 4 or i % 2 == 1 then job.slamRings[i] = Ring.new(job.anchor, 'SlamRing' .. i, th.Color:Lerp(WHITE, 0.55), P.premium and 0.3 or 0.22, P.premium and 0.9 or 0.7, true) end
	end
	fx.sparks = Preset.sparks(job, 'Sparks', th.Color:Lerp(WHITE, 0.5))
	fx.popBurst = Preset.burst(job, 'PopBurst', P.R.SlowMo and rainbowSeq(0) or seqOf({ WHITE, rcol }), { 25, 40 }, 0.7)
	fx.puff = job:emitter('SeamPuff', 'smoke', seqOf({ WHITE, th.Color:Lerp(WHITE, 0.6) }), {
		life = { 0.4, 0.7 }, speed = { 3, 6 }, drag = 4, spread = Vector2.new(70, 70), emission = 0, lightInfluence = 0.6,
		size = nseq({ { 0, 0.6 }, { 1, 2.2 } }), transparency = nseq({ { 0, 1 }, { 0.1, 0.35 }, { 1, 1 } }), rotSpeed = NR(-60, 60),
	})
	fx.accentSparks = Preset.burst(job, 'AccentSparks', P.R.SlowMo and rainbowSeq(1) or seqOf({ WHITE, rcol }), { 8, 16 }, 0.6)
	fx.accentRing = Preset.shock(job, 'AccentRing', math.max(4, P.R.Ring) * G * 0.6, 0.4, rcol)
	fx.accentRing2 = P.R.Double and Preset.shock(job, 'AccentRing2', (P.R.Ring + 4) * G * 0.6, 0.45, rcol) or nil
	fx.stamp = P.premium and Preset.shock(job, 'Stamp', 6 * G * 0.6, 0.3, th.Color:Lerp(WHITE, 0.3)) or nil
	fx.drift = job:emitter('Drift', 'spark', seqOf({ WHITE, rcol:Lerp(WHITE, 0.4) }), {
		life = { 1.2, 1.8 }, speed = { 0.5, 1.2 }, drag = 1, size = nseq({ { 0, 0 }, { 0.5, 0.5, 0.15 }, { 1, 0 } }),
		transparency = nseq({ { 0, 0.2 }, { 1, 1 } }), rate = P.premium and 6 or 4, brightness = 1.5,
	}, job.volumes.around)
	fx.glint = job:emitter('Glint', 'spark', seqOf({ WHITE, th.Color:Lerp(WHITE, 0.5) }), {
		life = { 0.35, 0.35 }, speed = { 0, 0.01 }, size = nseq({ { 0, 0 }, { 0.4, 2.6 }, { 1, 0 } }), transparency = nseq({ { 0, 0 }, { 1, 0.2 } }), brightness = 2, zoffset = 1,
	})
	if P.premium then
		fx.telegraph = Preset.shock(job, 'Telegraph', P.multi and 5 * G or 6 * G, 0.5, th.Color)
		fx.crackle = job:emitter('Crackle', 'spark', seqOf({ WHITE, WHITE }), {
			life = { 0.1, 0.2 }, speed = { 0, 0.01 }, size = nseq({ { 0, 2.8, 0.3 }, { 1, 2.4 } }), transparency = nseq({ { 0, 0 }, { 1, 1 } }), brightness = 2.5,
		})
		local bb = job.boxes[P.best]
		local shell = Make.part(job.folder, 'ChargeShell', V3(1, 1, 1) * 1.6 * P.boxW * (P.multi and 0.6 or 1), bb.home * CF(0, bb.seamY * 0.7, 0), WHITE, nil, { Transparency = 1 })
		fx.motes = job:emitter('Motes', 'spark', seqOf({ WHITE, th.Accent }), {
			life = { 0.4, 0.6 }, speed = { 6 * G, 10 * G }, spread = Vector2.zero, shape = Enum.ParticleEmitterShape.Sphere,
			shapeStyle = Enum.ParticleEmitterShapeStyle.Surface, shapeInOut = Enum.ParticleEmitterShapeInOut.Inward,
			orientation = Enum.ParticleOrientation.VelocityParallel, squash = NumberSequence.new(1),
			size = nseq({ { 0, 0.15 }, { 0.5, 0.45 }, { 1, 0 } }), transparency = nseq({ { 0, 1 }, { 0.3, 0 }, { 1, 1 } }), rate = 45, rotSpeed = NR(0),
		}, shell)
		fx.lidBurst = Preset.burst(job, 'LidBurst', seqOf({ WHITE, th.Color }), { 25, 40 }, 0.75)
		fx.pillarMotes = job:emitter('PillarMotes', 'spark', seqOf({ WHITE, th.Relit }), {
			life = { 1, 1.4 }, speed = { 6, 10 }, spread = Vector2.new(8, 8), drag = 0.5, size = nseq({ { 0, 0.3 }, { 1, 0 } }), transparency = nseq({ { 0, 1 }, { 0.2, 0 }, { 1, 1 } }), rate = 25,
		})
		-- the comets: a glowing head with a tapered tail (a diamond glint for the Exclusive)
		job.comets = {}
		for i, box in job.boxes do
			local head = Make.ball(job.folder, 'CometHead', 2.2, job.park, th.Color:Lerp(WHITE, 0.55), Enum.Material.Neon)
			local a0, a1 = Make.attach(job.anchor, 'CometA' .. i), Make.attach(job.anchor, 'CometB' .. i)
			local tail = Make.beam(job.anchor, a0, a1, seqOf({ WHITE, th.Color }), 3.4, 0.1, nseq({ { 0, 0.05 }, { 0.5, 0.4 }, { 1, 1 } }), 1, { Segments = 6 })
			tail.Enabled = false
			local c = { head = head, a0 = a0, a1 = a1, tail = tail }
			if job.diamond then
				c.f = { Make.attach(job.anchor, 'FlareA' .. i), Make.attach(job.anchor, 'FlareB' .. i), Make.attach(job.anchor, 'FlareC' .. i), Make.attach(job.anchor, 'FlareD' .. i) }
				c.fb = { Make.beam(job.anchor, c.f[1], c.f[2], seqOf({ C3(190, 240, 255), WHITE, C3(190, 240, 255) }), 0.6, 0.6, nseq({ { 0, 1 }, { 0.5, 0 }, { 1, 1 } }), 1, { Segments = 4 }),
					Make.beam(job.anchor, c.f[3], c.f[4], seqOf({ C3(255, 170, 235), WHITE, C3(255, 170, 235) }), 0.6, 0.6, nseq({ { 0, 1 }, { 0.5, 0 }, { 1, 1 } }), 1, { Segments = 4 }) }
				for _, b in c.fb do b.Enabled = false end
			end
			job.comets[i] = c
			box.comet = c
		end
	end
	-- the theme's ambient layer (cash tiers 4+ and premium)
	job.ambient = {}
	if P.premium or P.themeTier >= 4 then
		for i, a in th.Ambient do
			local host = job.volumes[a.where or 'around'] or job.volumes.around
			table.insert(job.ambient, Build.recipe(job, 'Ambient' .. i, a, host, P.premium and 1 or 0.7))
		end
	end
	-- the HOLD layer: the theme's own particles on a sheet just behind the pair, through the reveal and the hold (the box
	-- is named by its hero frame alone); a rim light behind the pair on the premium tier
	if th.Hold then
		job.holdVol = Make.part(job.folder, 'HoldVolume', V3(10, 7, 1), job.park, WHITE, nil, { Transparency = 1 })
		job.holdFx = Build.recipe(job, 'HoldLayer', th.Hold, job.holdVol, 1)
	end
	if P.premium or job.darkPair then
		job.rimHost = Make.part(job.folder, 'RimLight', V3(0.2, 0.2, 0.2), job.park, WHITE, nil, { Transparency = 1 })
		job.rimLight = Make.light(job.rimHost, P.premium and th.Relit or C3(255, 196, 130), 0, 14)
	end
	-- premium: the energy rings and the build-up pillar behind the box
	if P.premium then
		job.rings = {}
		for i, c in th.Rings do job.rings[i] = Ring.new(job.anchor, 'Energy' .. i, c, i == 3 and 0.2 or 0.55, i == 3 and 0.45 or 1.7) end
		job.rings[3]:setColor(WHITE)
		local a0, a1 = Make.attach(job.anchor, 'BuildFoot'), Make.attach(job.anchor, 'BuildTop')
		job.buildBeam = Make.beam(job.anchor, a0, a1, seqOf({ WHITE, th.Accent }), 1, 1, nseq({ { 0, 0.4 }, { 0.6, 0.6 }, { 1, 1 } }), 1, { Segments = 1, Tex = 'shaft' })
		job.buildBeam.Enabled = false
		job.buildAtt = { a0, a1 }
	end
	-- light pillars: premium one per box (a Buy 8: a light wall of three), the normal tier's from Mythic
	job.pillars = {}
	local spots = {}
	if P.premium then
		if P.n >= 5 then spots = { 1, math.ceil(P.n / 2), P.n } else for i = 1, P.n do table.insert(spots, i) end end
	elseif P.R.Pillar then
		spots = { P.best }
	end
	for _, i in spots do
		local a0, a1 = Make.attach(job.anchor, 'PillarFoot' .. i), Make.attach(job.anchor, 'PillarTop' .. i)
		local col = P.R.SlowMo and WHITE or (P.premium and th.Relit:Lerp(WHITE, 0.35) or rcol:Lerp(WHITE, 0.3))
		local b = Make.beam(job.anchor, a0, a1, seqOf({ WHITE, col }), 1, 1.3, nseq({ { 0, job.lightPair and 0.45 or 0.15 }, { 0.5, job.lightPair and 0.65 or 0.45 }, { 1, 1 } }), 1, { Segments = 1, Tex = 'shaft' })
		b.Enabled = false
		table.insert(job.pillars, { i = i, a0 = a0, a1 = a1, beam = b })
	end
	-- god rays behind the best pair (premium: 4 white + the rarity's; the Gold box: golden rays)
	local gold = th.Id == 'Gold'
	-- (premium: 6 white rays plus the rarity's, at least 4 in the theme's colours: a Robux Rare pays off too)
	local nr = P.premium and (6 + math.max(P.R.Rays, 4)) or P.R.Rays
	if gold then nr = math.max(nr, 6) end
	job.rays = {}
	if nr > 0 then
		job.rayHub = Make.attach(job.anchor, 'RayHub')
		for i = 1, nr do
			local tip = Make.attach(job.anchor, 'RayTip' .. i)
			local col = P.R.SlowMo and Themes.Rainbow[(i - 1) % #Themes.Rainbow + 1] or ((P.premium and i <= 6) and WHITE or (gold and C3(255, 210, 90) or ((P.premium and i % 2 == 0) and th.Color or rcol)))
			local b0 = (P.premium and 0.7 or 0.62) + (job.lightPair and 0.2 or 0)
			-- (invisible for their first third: a dozen rays meeting at the hub must not stack into a white blot between
			-- the shoes)
			local b = Make.beam(job.anchor, job.rayHub, tip, seqOf({ WHITE, col }), 0.3, 2.6, nseq({ { 0, 1 }, { 0.4, 1 }, { 0.55, b0 }, { 0.8, M.lerp(b0, 1, 0.45) }, { 1, 1 } }), 0.7, { Segments = 1, Tex = 'shaft' })
			b.Name = 'Ray' .. i
			b.Enabled = false
			table.insert(job.rays, { tip = tip, beam = b, len = M.lerp(18, 26, M.hash(i, 41)) * (P.multi and 0.9 or 0.75) })
		end
	end
	-- a soft dark backdrop behind a light pair (and every Grail: royal purple behind gold): one big normal-blend glow,
	-- locked to its attachment, so the pair separates from the rays and posters behind it
	if job.lightPair or th.Id == 'Grail' or job.darkPair then
		local col, tr, em = th.Id == 'Grail' and C3(102, 48, 153) or th.Deep:Lerp(BLACK, 0.25), th.Id == 'Grail' and 0.3 or 0.55, 0
		if job.darkPair and th.Id ~= 'Grail' then
			-- (a dark pair: the rarity's glow at 35 %, so its silhouette separates from the night)
			col, tr, em = rcol:Lerp(WHITE, 0.15), 0.65, 0.6
		end
		job.backdrop = job:emitter('Backdrop', 'glow', seqOf({ col, col }), {
			life = { 30, 30 }, speed = { 0, 0 }, rotSpeed = NR(0), rotation = NR(0), size = NumberSequence.new(1),
			transparency = nseq({ { 0, tr }, { 1, tr } }), emission = em, lightInfluence = 0, zoffset = -3,
		})
		job.backdrop.LockedToPart = true
		job.backdropDark = not (job.darkPair and th.Id ~= 'Grail')
	end
	-- Legendary+: two comets orbiting the pair (neon beads with short tails)
	job.orbiters = {}
	for i = 1, P.R.Comets do
		local head = Make.ball(job.folder, 'Orbiter', 0.6, job.park, rcol:Lerp(WHITE, 0.4), Enum.Material.Neon)
		local a0, a1 = Make.attach(job.anchor, 'OrbitA' .. i), Make.attach(job.anchor, 'OrbitB' .. i)
		local b = Make.beam(job.anchor, a0, a1, seqOf({ WHITE, rcol }), 0.5, 0, nseq({ { 0, 0.1 }, { 1, 1 } }), 1, { Segments = 8 })
		b.Enabled = false
		table.insert(job.orbiters, { head = head, a0 = a0, a1 = a1, beam = b })
	end
	if P.R.Halo or th.Id == 'Grail' then
		job.halo = PartRing.new(job.folder, job.park, 'Halo', 24, 0.16, C3(255, 226, 90))
		job.haloRainbow = P.R.Halo == true
	end
end

---------------------------------------------------------------------------------------------- signatures (themes)
-- Each schedules its one-shots (job:at) and its per-frame motion (job:onFrame); i = the box it plays on. Each decides
-- what a multi-open's other boxes get (usually a lighter touch, or nothing).
local Sig = {}
UnboxCinematic.Sig = Sig
local function keyed(keys, u)
	if u <= keys[1][1] then return keys[1][2] end
	for k = 1, #keys - 1 do
		local a, b = keys[k], keys[k + 1]
		if u >= a[1] and u <= b[1] then return M.lerp(a[2], b[2], (u - a[1]) / (b[1] - a[1])) end
	end
	return keys[#keys][2]
end
-- Street: the lamps flicker on as the box hits (lamp heads only: 2 dips in 0.4 s), a spray-paint puff ring
Sig.lampsOn = function(job, i)
	if i ~= job.P.n then return end
	local t0 = job.P.land[i]
	job.lampsOff = true
	job:onFrame(function(t)
		job.lampLevel = keyed({ { 0, 0 }, { 0.15, 1 }, { 0.4, 0.3 }, { 0.65, 1 }, { 1, 1 } }, M.c01((t - t0) / 0.4)) * (t >= t0 and 1 or 0)
	end)
end
Sig.sprayRing = function(job, i)
	local th = job.P.theme
	local e = job:emitter('Spray' .. i, 'smoke', seqOf({ th.Color, WHITE }), {
		life = { 0.6, 1.0 }, speed = { 10, 16 }, drag = 5, spread = Vector2.new(0, 180), direction = Enum.NormalId.Front, emission = 0, lightInfluence = 0.5,
		size = nseq({ { 0, 1 }, { 1, 3.4 } }), transparency = nseq({ { 0, 1 }, { 0.08, 0.2 }, { 0.6, 0.45 }, { 1, 1 } }), rotSpeed = NR(-60, 60), zoffset = -0.5,
	})
	job:at(job.P.land[i], function() job:emit(e, job.P.multi and 4 or 8, job.boxes[i].home * CF(0, 0.5, 0)) end)
end
Sig.sprayBurst = function(job, i)
	local e = Preset.burst(job, 'SprayBurst' .. i, seqOf({ WHITE, job.P.theme.Color }), { 14, 26 }, 0.6)
	job:at(job.P.pop[i], function() job:emit(e, job.P.multi and 6 or 12, job.boxes[i]:mouth()) end)
end
-- a fresh "+1" tag on the pad: a flat splat and a white mark pop on, hold, fade
Sig.tag = function(job, i)
	if job.P.multi and i ~= job.P.best then return end
	local th = job.P.theme
	local box = job.boxes[i]
	local base = box.home * CF(job.P.multi and 0 or box.W * 0.62, 0.04, -box.D * 0.5 - 1.8) * ANG(0, 0.35, 0)
	local splat = Make.disc(job.folder, 'Tag', 0.04, 4, job.park, th.Color, Enum.Material.SmoothPlastic)
	local marks = {
		{ Make.part(job.folder, 'TagMark', V3(1.5, 0.05, 0.38), job.park, WHITE, Enum.Material.SmoothPlastic), V3(-0.8, 0.02, 0) },
		{ Make.part(job.folder, 'TagMark', V3(0.38, 0.05, 1.5), job.park, WHITE, Enum.Material.SmoothPlastic), V3(-0.8, 0.02, 0) },
		{ Make.part(job.folder, 'TagMark', V3(0.38, 0.05, 1.8), job.park, WHITE, Enum.Material.SmoothPlastic), V3(0.75, 0.02, 0) },
	}
	local t0 = job.P.pop[i] + 0.12
	job:onFrame(function(t)
		local u = (t - t0) / 0.18
		if u < 0 then return end
		local s = math.max(0.05, M.back(u, 2.2))
		local a = M.c01(1 - (t - (t0 + 1.4)) / 0.5)
		splat.Size = V3(0.04, 4 * s, 4 * s)
		splat.CFrame = base * ANG(0, 0, PI / 2)
		splat.Transparency = 1 - a
		for _, m in marks do
			m[1].CFrame = base * CF(m[2] * s)
			m[1].Transparency = 1 - a
		end
	end)
end
-- Graffiti: the slam paints the floor (a crown of splats that stays), paint droplets; a rainbow mist and drips at the pop
Sig.paintCrown = function(job, i)
	local P = job.P
	local th = P.theme
	local cols = { th.Color, th.Accent, th.Third, C3(130, 230, 80) }
	local box = job.boxes[i]
	local splats = {}
	local count = P.multi and 4 or 8
	for k = 1, count do
		local a = (k - 1) / count * 2 * PI + M.hash(i, k) * 0.5
		local r = box.W * 0.75 + M.hash(k, i) * 1.5
		local d = M.lerp(1.6, 2.6, M.hash(k, 3)) * G
		local p = Make.disc(job.folder, 'PaintSplat', 0.06, d, job.park, cols[(k - 1) % #cols + 1], Enum.Material.SmoothPlastic)
		table.insert(splats, { p = p, cf = box.home * CF(math.cos(a) * r, 0.04 + k * 0.004, math.sin(a) * r) * ANG(0, a, 0) * ANG(0, 0, PI / 2), d = d, t0 = P.land[i] + k * 0.012 })
	end
	job:onFrame(function(t)
		local parts, cfs = {}, {}
		for _, s in splats do
			local u = (t - s.t0) / 0.12
			if u >= 0 and not s.done then
				local sc = math.max(0.05, M.back(u, 1.6))
				s.p.Size = V3(0.06, s.d * sc, s.d * sc)
				table.insert(parts, s.p)
				table.insert(cfs, s.cf)
				if u > 1 then s.done = true end
			end
		end
		bulk(parts, cfs)
	end)
	job:spawn({ kind = 'drop', n = P.multi and 5 or 12, colors = cols, t0 = P.land[i], at = box.home * CF(0, 0.6, 0), speed = { 10, 16 }, up = 0.6, size = 0.42, grav = 40, away = job.away }, 'slam')
end
Sig.mist = function(job, i)
	local e = job:emitter('Mist' .. i, 'smoke', rainbowSeq(0), {
		life = { 0.8, 1.2 }, speed = { 4, 8 }, drag = 3, spread = Vector2.new(70, 70), emission = 0.05, lightInfluence = 0.5,
		size = nseq({ { 0, 1.5 }, { 1, 4.5 } }), transparency = nseq({ { 0, 1 }, { 0.1, 0.35 }, { 0.6, 0.55 }, { 1, 1 } }), rotSpeed = NR(-40, 40),
	})
	job:at(job.P.pop[i], function() job:emit(e, job.P.multi and 4 or 8, job.boxes[i]:mouth()) end)
end
Sig.drips = function(job, i)
	local P = job.P
	local th = P.theme
	local box = job.boxes[i]
	local drips = {}
	for k = 1, P.multi and 3 or 6 do
		local side = k % 2 == 0 and -1 or 1
		local p = Make.part(job.folder, 'Drip', V3(0.3 * box.s, 1, 0.12), job.park, ({ th.Color, th.Accent, th.Third })[(k - 1) % 3 + 1], Enum.Material.SmoothPlastic)
		table.insert(drips, { p = p, x = (M.hash(k, i) - 0.5) * box.W * 0.8, z = side * (box.D / 2 + 0.07), t0 = P.pop[i] + 0.05 + k * 0.04, len = M.lerp(0.6, 1.4, M.hash(k, 9)) * box.s })
	end
	job:onFrame(function(t)
		local parts, cfs = {}, {}
		for _, d in drips do
			if t >= d.t0 then
				local l = math.max(0.05, d.len * M.inn((t - d.t0) / 0.6, 2))
				d.p.Size = V3(d.p.Size.X, l, 0.12)
				table.insert(parts, d.p)
				table.insert(cfs, (box.cf or box.home) * CF(d.x, box.seamY - l / 2, d.z))
			end
		end
		bulk(parts, cfs)
	end)
end
-- Frost: frost creeps out across the pad (a pale ring that holds, the pad tinting icy), a breath puff; the lid shatters
Sig.frostCreep = function(job, i)
	local P = job.P
	local box = job.boxes[i]
	local e = job:emitter('Frost' .. i, 'ring', seqOf({ C3(230, 245, 255), C3(170, 220, 255) }), {
		life = { 2.1, 2.1 }, speed = { 0.01, 0.01 }, spread = Vector2.zero, orientation = Enum.ParticleOrientation.VelocityPerpendicular,
		size = nseq({ { 0, 1 }, { 0.3, 13.2 }, { 1, 14 } }), transparency = nseq({ { 0, 0.4 }, { 0.3, 0.25 }, { 0.75, 0.35 }, { 1, 1 } }), rotSpeed = NR(0), emission = 0.6,
	})
	local puff = job:emitter('Breath' .. i, 'smoke', seqOf({ WHITE, C3(200, 230, 255) }), {
		life = { 0.6, 1 }, speed = { 6, 10 }, drag = 4, spread = Vector2.new(0, 180), direction = Enum.NormalId.Front, emission = 0, lightInfluence = 0.6,
		size = nseq({ { 0, 1 }, { 1, 3.4 } }), transparency = nseq({ { 0, 1 }, { 0.1, 0.25 }, { 1, 1 } }), rotSpeed = NR(-40, 40),
	})
	job:at(P.land[i], function()
		job:emit(e, 1, box.home * CF(0, 0.06, 0))
		job:emit(puff, P.multi and 3 or 6, box.home * CF(0, 0.5, 0))
	end)
	if i == P.n then
		local pad = job.padTint
		job:onFrame(function(t)
			if pad and t >= P.land[i] then pad.Color = C3(48, 50, 60):Lerp(C3(200, 230, 255), 0.55 * M.out((t - P.land[i]) / 0.5, 2)) end
		end)
	end
end
Sig.lidShatter = function(job, i)
	local box = job.boxes[i]
	box.shatter = true
	job:spawn({ kind = 'shard', n = job.P.multi and 4 or 6, colors = { C3(210, 240, 255), C3(160, 210, 250), WHITE }, t0 = job.P.pop[i], at = box.home * CF(0, box.topY * 0.85, 0), speed = { 9, 14 }, up = 0.75, size = box.s * 0.7, grav = 50, transparency = 0.25, away = job.away }, 'pop')
end
Sig.snowPuff = function(job, i)
	local e = Preset.burst(job, 'Snow' .. i, seqOf({ WHITE, C3(200, 235, 255) }), { 8, 14 }, 0.55)
	e.Acceleration = V3(0, -6, 0)
	job:at(job.P.pop[i], function() job:emit(e, job.P.multi and 8 or 18, job.boxes[i]:mouth()) end)
end
-- Lava: magma cracks radiate across the pad, glow, then cool; a fire geyser and embers launch the lid
Sig.magma = function(job, i)
	local P = job.P
	local box = job.boxes[i]
	local cracks = {}
	local n = P.multi and 3 or 6
	for k = 1, n do
		local a = (k - 1) / n * 2 * PI + M.hash(k, i) * 0.6
		local len = M.lerp(3, 5, M.hash(k, 4)) * G
		table.insert(cracks, { p = Make.part(job.folder, 'Crack', V3(len, 0.06, 0.15 * G), job.park, C3(255, 120, 30), Enum.Material.Neon), a = a, len = len, r0 = box.W * 0.45 })
	end
	job:onFrame(function(t)
		if t < P.land[i] or t > P.land[i] + 2.6 then return end
		local u = M.out((t - P.land[i]) / 0.2, 4)
		local cool = M.c01((t - P.land[i] - 0.4) / 2)
		local parts, cfs = {}, {}
		for _, c in cracks do
			local l = math.max(0.05, c.len * u)
			c.p.Size = V3(l, 0.06, 0.15 * G)
			c.p.Color = C3(255, 150, 40):Lerp(C3(60, 30, 26), cool)
			table.insert(parts, c.p)
			table.insert(cfs, box.home * ANG(0, -c.a, 0) * CF(c.r0 + l / 2, 0.035, 0))
		end
		bulk(parts, cfs)
	end)
end
Sig.geyser = function(job, i)
	local e = job:emitter('Geyser' .. i, 'fire', seqOf({ C3(255, 220, 120), C3(255, 110, 30) }), {
		life = { 0.5, 0.8 }, speed = { 12, 18 }, spread = Vector2.new(12, 12), drag = 1, accel = V3(0, 4, 0), emission = 0.75,
		orientation = Enum.ParticleOrientation.FacingCameraWorldUp, size = nseq({ { 0, 1.2 }, { 0.4, 2.6 }, { 1, 0.8 } }),
		transparency = nseq({ { 0, 0.4 }, { 0.2, 0.05 }, { 0.75, 0.3 }, { 1, 1 } }), rotSpeed = NR(-20, 20),
	})
	job:at(job.P.pop[i], function() job:emit(e, job.P.multi and 5 or 10, job.boxes[i]:mouth()) end)
	job:spawn({ kind = 'ember', n = job.P.multi and 6 or 14, colors = { C3(255, 210, 90), C3(255, 140, 40), C3(255, 90, 30) }, t0 = job.P.pop[i], at = job.boxes[i].home * CF(0, job.boxes[i].seamY, 0), speed = { 10, 18 }, up = 0.92, size = 0.28, grav = -6, away = job.away }, 'pop')
end
-- Toxic: a slime crown and a puddle on landing; a bubble inflates over the box and pops it open
Sig.slimeCrown = function(job, i)
	local P = job.P
	local box = job.boxes[i]
	job:spawn({ kind = 'drop', n = P.multi and 4 or 8, colors = { C3(120, 235, 70), C3(170, 255, 110) }, t0 = P.land[i], at = box.home * CF(0, 0.6, 0), speed = { 9, 14 }, up = 0.8, size = 0.55, grav = 45, away = job.away }, 'slam')
	local puddle = Make.disc(job.folder, 'Slime', 0.08, 1, job.park, C3(120, 220, 70), Enum.Material.SmoothPlastic, { Transparency = 0.2 })
	job:onFrame(function(t)
		local u = t - P.land[i]
		if u < 0 or u > 2.2 then return end
		local r = math.max(0.05, 4 * G * M.back(u / 0.25, 1.8) * (1 - M.smooth((u - 0.4) / 1.5) * 0.6))
		puddle.Size = V3(0.08, r * 2, r * 2)
		puddle.CFrame = box.home * CF(0, 0.03, 0) * ANG(0, 0, PI / 2)
	end)
end
Sig.bubblePop = function(job, i)
	local P = job.P
	local box = job.boxes[i]
	local bub = Make.ball(job.folder, 'Bubble', 1, job.park, C3(180, 255, 150), Enum.Material.Glass, { Transparency = 1 })
	local t0, t1 = P.crouch[i] - 0.35, P.pop[i]
	job:onFrame(function(t)
		if t < t0 or t > t1 + 0.1 then
			if bub.Transparency < 1 then bub.Transparency = 1; bub.CFrame = job.park end
			return
		end
		local full = 2.5 * G + box.W * 0.4
		local d = t < t1 and M.out((t - t0) / (t1 - t0), 2) * full or full * (1 + 0.2 * M.c01((t - t1) / 0.08))
		bub.Size = V3(d, d, d)
		bub.Transparency = t < t1 and 0.55 or M.lerp(0.55, 1, M.c01((t - t1) / 0.08))
		bub.CFrame = (box.cf or box.home) * CF(0, box.topY * 0.7, 0)
	end)
	job:spawn({ kind = 'drop', n = P.multi and 5 or 12, colors = { C3(190, 255, 160), C3(130, 235, 90) }, t0 = P.pop[i], at = box.home * CF(0, box.topY, 0), speed = { 8, 14 }, up = 0.5, size = 0.35, grav = 40, away = job.away }, 'pop')
end
-- Candy: the box lands like jelly (2-3 jiggles), a sweets fountain at the pop, sprinkles raining through the hold
Sig.jelly = function(job, i) job.jelly = true end
Sig.sweets = function(job, i)
	local P = job.P
	local box = job.boxes[i]
	job:spawn({ kind = 'candy', n = P.multi and 3 or 6, colors = { C3(255, 150, 200), C3(200, 190, 255), C3(120, 220, 190) }, t0 = P.pop[i], at = box.home * CF(0, box.seamY, 0), speed = { 10, 15 }, up = 0.8, size = 0.75, grav = 45, away = job.away }, 'pop')
	job:spawn({ kind = 'sprinkle', n = P.multi and 6 or 16, colors = { C3(255, 90, 150), C3(120, 200, 255), C3(255, 230, 90), C3(130, 240, 170), WHITE }, t0 = P.pop[i], at = box.home * CF(0, box.seamY, 0), speed = { 9, 16 }, up = 0.75, size = 0.42, grav = 45, away = job.away }, 'pop')
	if i == P.best then
		job:spawn({ kind = 'sprinkle', n = P.multi and 6 or 14, colors = { C3(255, 90, 150), C3(120, 200, 255), C3(255, 230, 90), C3(130, 240, 170) }, t0 = P.accent[i] - 0.3, at = job:w(V3(0, 18, 0)), speed = { 2, 5 }, size = 0.4, rain = P.padR * 0.8, spread = 1.5, grav = 30 }, 'reveal')
	end
end
-- Ocean: a wave ring rolls out with foam, a splash crown; a water spout lifts the shoe
Sig.wave = function(job, i)
	local P = job.P
	local box = job.boxes[i]
	local ring = Ring.new(job.anchor, 'Wave' .. i, C3(120, 220, 240), 0.5, 1.4)
	local foam = job:emitter('Foam' .. i, 'smoke', seqOf({ WHITE, C3(200, 240, 250) }), {
		life = { 0.5, 0.8 }, speed = { 8, 12 }, drag = 3, spread = Vector2.new(0, 180), direction = Enum.NormalId.Front, emission = 0.05, lightInfluence = 0.6,
		size = nseq({ { 0, 0.8 }, { 1, 2.6 } }), transparency = nseq({ { 0, 1 }, { 0.1, 0.25 }, { 1, 1 } }), rotSpeed = NR(-40, 40),
	})
	job:at(P.land[i], function() job:emit(foam, P.multi and 6 or 12, box.home * CF(0, 0.4, 0)) end)
	job:onFrame(function(t)
		local u = (t - P.land[i]) / 0.8
		local a = (u > 0 and u < 1) and (1 - M.inn(u, 2)) or 0
		ring:pose(box.home * CF(0, 0.3, 0) * ANG(RAD(5), 0, 0), M.lerp(1, 9 * G * (P.multi and 0.6 or 1), M.sineInOut(u)), a, u * 2)
	end)
	job:spawn({ kind = 'drop', n = P.multi and 6 or 16, colors = { C3(80, 190, 240), C3(150, 232, 222), C3(220, 245, 255) }, t0 = P.land[i], at = box.home * CF(0, 0.6, 0), speed = { 12, 18 }, up = 0.92, size = 0.38, grav = 60, transparency = 0.15, away = job.away }, 'slam')
end
Sig.spout = function(job, i)
	local P = job.P
	local box = job.boxes[i]
	local e = job:emitter('Spout' .. i, 'spark', seqOf({ WHITE, C3(150, 220, 250) }), {
		life = { 0.5, 0.7 }, speed = { 10, 16 }, spread = Vector2.new(8, 8), accel = V3(0, -30, 0), size = nseq({ { 0, 0.5 }, { 1, 0.1 } }),
		transparency = nseq({ { 0, 0 }, { 0.8, 0.2 }, { 1, 1 } }), emission = 0.3, lightInfluence = 0.5, rate = P.multi and 25 or 70,
	})
	job:at(P.pop[i], function() e.Parent.CFrame = job.anchor.CFrame:ToObjectSpace(box.home * CF(0, box.seamY, 0)); e.Enabled = true; job:recount() end)
	job:at(P.pop[i] + 0.5, function() e.Enabled = false; job:recount() end, true)
end
-- Gem: a crystal clink ring of glints round the base; the opening splits light into a rainbow fan (and shards)
Sig.clink = function(job, i)
	local P = job.P
	local box = job.boxes[i]
	local e = job:emitter('Clink' .. i, 'spark', seqOf({ WHITE, C3(255, 230, 140) }), {
		life = { 0.35, 0.5 }, speed = { 0, 0.01 }, size = nseq({ { 0, 0 }, { 0.4, 0.8 }, { 1, 0 } }), transparency = nseq({ { 0, 0 }, { 1, 0.2 } }), brightness = 2, zoffset = 1,
	})
	job:at(P.land[i] + 0.02, function()
		for k = 1, P.multi and 6 or 12 do
			local a = k / (P.multi and 6 or 12) * 2 * PI
			job:emit(e, 1, box.home * CF(math.cos(a) * box.W * 0.7, 0.4, math.sin(a) * box.W * 0.7))
		end
	end)
end
local function fan(job, name, i, count, cols, t0, life, sweep)
	local box = job.boxes[i]
	local hub = Make.attach(job.anchor, name .. 'Hub')
	local beams = {}
	for k = 1, count do
		local tip = Make.attach(job.anchor, name .. 'Tip' .. k)
		local b = Make.beam(job.anchor, hub, tip, seqOf({ WHITE, cols[(k - 1) % #cols + 1] }), 0.25, 3, nseq({ { 0, 0.3 }, { 0.6, 0.55 }, { 1, 1 } }), 1, { Segments = 1, Tex = 'shaft' })
		b.Enabled = false
		table.insert(beams, { tip = tip, b = b, k = k })
	end
	job:onFrame(function(t)
		local u = (t - t0) / life
		local on = u > 0 and u < 1
		local a = on and (M.out(u * 4, 2) * (1 - M.inn((u - 0.6) / 0.4, 2))) or 0
		local acf = job.anchor.CFrame:Inverse()
		local c = (box.cf or box.home) * CF(0, box.seamY + 0.4, 0)
		hub.CFrame = acf * c
		for _, r in beams do
			local vis = a > 0.01
			if r.b.Enabled ~= vis then r.b.Enabled = vis end
			if vis then
				local ang = RAD(-70 + (r.k - 1) / math.max(1, count - 1) * 140 + sweep * u)
				local dir = c:VectorToWorldSpace(V3(math.sin(ang), math.cos(ang) * 0.9 + 0.3, -0.35)).Unit
				r.tip.CFrame = acf * CF(c.Position + dir * 15 * G * 0.7 * a)
				r.b.Width1 = 3 * a
			end
		end
	end)
end
Sig.prism = function(job, i)
	if job.P.multi and i ~= job.P.best then return end
	fan(job, 'Prism' .. i, i, 5, { C3(255, 90, 90), C3(255, 200, 60), C3(90, 230, 120), C3(70, 170, 255), C3(170, 100, 255) }, job.P.pop[i], 0.9, 20)
	job:spawn({ kind = 'shard', n = 5, colors = { C3(120, 255, 180), C3(250, 220, 120), WHITE }, t0 = job.P.pop[i], at = job.boxes[i].home * CF(0, job.boxes[i].topY, 0), speed = { 9, 14 }, up = 0.7, size = 0.9, grav = 50, transparency = 0.2, away = job.away }, 'pop')
end
-- Galaxy: night falls (the look), the box drops out of a warp ring, stars burst on landing, hyperspace on the open
Sig.nightfall = function() end
Sig.warpDrop = function(job, i)
	if i ~= 1 then return end
	local P = job.P
	local box = job.boxes[i]
	local ring = Ring.new(job.anchor, 'WarpDrop', C3(200, 180, 255), 0.4, 1.3)
	local t0 = P.fall0[i] - 0.12
	job:onFrame(function(t)
		local u = (t - t0) / (P.fall + 0.3)
		local a = (u > 0 and u < 1) and (M.out(u * 3, 2) * (1 - M.inn((u - 0.5) / 0.5, 2))) or 0
		ring:pose(box.home * CF(0, P.fallH + box.topY * 0.5, 0), 4 * G * (0.4 + 0.6 * M.out(u * 3, 2)), a, t * 4)
	end)
end
Sig.starBurst = function(job, i)
	job:spawn({ kind = 'star', n = job.P.multi and 4 or 8, colors = { WHITE, C3(214, 204, 255), C3(170, 220, 255) }, t0 = job.P.land[i], at = job.boxes[i].home * CF(0, 0.6, 0), speed = { 9, 15 }, up = 0.7, size = 0.42, grav = 40, away = job.away }, 'slam')
end
Sig.hyperspace = function(job, i)
	if job.P.multi and i ~= job.P.best then return end
	local P = job.P
	local box = job.boxes[i]
	local ring = PartRing.new(job.folder, job.park, 'Hyperspace', 32, 0.25, C3(214, 204, 255))
	ring.len = 1.4
	local t0 = P.pop[i]
	Cam.punch(job, t0, 8, 0.12, 2.5, 0.55)
	job:onFrame(function(t)
		local u = (t - t0) / 0.5
		if u < 0 or u > 1 then
			ring:pose(job.park, 0, 0)
			return
		end
		local cam = job.camCF
		local c = box.home.Position + V3(0, box.topY * 0.7, 0)
		local face = cam and CFrame.lookAt(c, c + cam.LookVector) or box.home
		ring:pose(face * ANG(PI / 2, 0, 0), M.lerp(2, 30, M.out(u, 4)), 1 - M.inn(u, 1.5), t * 1.5, true)
	end)
	local e = job:emitter('Warp', 'spark', seqOf({ WHITE, C3(170, 200, 255) }), {
		life = { 0.4, 0.6 }, speed = { 30, 46 }, size = nseq({ { 0, 0.5 }, { 1, 0.2 } }), transparency = nseq({ { 0, 0 }, { 1, 1 } }),
		orientation = Enum.ParticleOrientation.VelocityParallel, squash = NumberSequence.new(1.8), spread = Vector2.new(180, 180),
	})
	job:at(t0, function() job:emit(e, 22, box:mouth()) end)
end
-- Gold: a gold dust ring on landing; a coin fountain (coins bounce once); golden rays behind the pair (Build.effects)
Sig.goldDust = function(job, i)
	local e = Preset.dust(job, 'GoldDust' .. i, C3(255, 214, 120), false)
	e.LightEmission = 0.3
	job:at(job.P.land[i], function() job:emit(e, job.P.multi and 4 or 8, job.boxes[i].home * CF(0, 0.4, 0)) end)
end
Sig.coinFountain = function(job, i)
	local P = job.P
	local box = job.boxes[i]
	job:spawn({ kind = 'coin', n = P.multi and 5 or 12, colors = { C3(255, 206, 70), C3(240, 170, 40), C3(255, 226, 120) }, t0 = P.pop[i], at = box.home * CF(0, box.seamY, 0), speed = { 12, 17 }, up = 0.88, size = 0.85 * G, grav = 50, bounce = 0.4, spinMin = 8, spinMax = 16, away = job.away }, 'pop')
end
-- Exclusive: a diamond-glint comet, a shard ring on the slam, prism crystals orbiting the charge, a crystal shell in the
-- dark beat that shatters under the flash, a cyan prism fan from the lid
Sig.diamondComet = function(job, i) job.diamond = true end
Sig.shardRing = function(job, i)
	job:spawn({ kind = 'shard', n = job.P.multi and 3 or 8, colors = { C3(170, 235, 255), C3(110, 210, 255), WHITE }, t0 = job.P.land[i], hz = { 12, 20 }, vz = { 22, 32 }, at = job.boxes[i].home * CF(0, 0.6, 0), size = 1.0, neon = true, grav = 110, away = job.away }, 'slam')
end
Sig.crystals = function(job, i)
	if i ~= job.P.best then return end
	local P = job.P
	local box = job.boxes[i]
	local list = {}
	for k = 1, 6 do
		table.insert(list, Make.part(job.folder, 'Crystal', V3(0.5, 1.2, 0.5) * G, job.park, k % 2 == 0 and C3(170, 235, 255) or C3(230, 190, 255), Enum.Material.Glass, { Transparency = 0.15, Reflectance = 0.3 }))
	end
	job:onFrame(function(t)
		local a = M.out((t - P.charge[1]) / 0.4, 2) * (t < P.flash and 1 or 0)
		local cfs = {}
		for k in list do
			if a <= 0.01 then cfs[k] = job.park else
				local ang = (k - 1) / 6 * 2 * PI + (t - P.charge[1]) * 0.5 * 2 * PI
				local r = 3.5 * G * (P.multi and 2 or 1) * (t > P.dip[1] and M.lerp(1, 0.75, M.c01((t - P.dip[1]) / 0.3)) or 1) * M.lerp(0.4, 1, a)
				cfs[k] = (box.cf or box.home) * CF(math.cos(ang) * r, box.topY * 0.6 + math.sin(t * 2 + k) * 0.4, math.sin(ang) * r) * ANG(0, ang, RAD(45))
			end
		end
		bulk(list, cfs)
	end)
end
Sig.shell = function(job, i)
	if i ~= job.P.best then return end
	local P = job.P
	local box = job.boxes[i]
	local list = {}
	for k = 1, 8 do
		table.insert(list, Make.part(job.folder, 'Shell', V3(box.W * 0.62, box.topY * 1.3, 0.25), job.park, C3(150, 225, 255), Enum.Material.Glass, { Transparency = 0.4 }))
	end
	job:onFrame(function(t)
		local u = math.max(0.05, M.out((t - P.dip[1]) / 0.25, 2))
		local cfs = {}
		for k, p in list do
			if t < P.dip[1] or t >= P.flash then cfs[k] = job.park else
				local ang = (k - 1) / 8 * 2 * PI
				cfs[k] = box.home * CF(0, box.topY * 0.62, 0) * ANG(0, ang, 0) * CF(0, 0, box.W * 0.72) * ANG(RAD(-12), 0, 0)
				p.Size = V3(box.W * 0.62 * u, box.topY * 1.3 * u, 0.25)
			end
		end
		bulk(list, cfs)
	end)
	-- under the flash: the shell shatters outward
	job:spawn({ kind = 'shard', n = 16, colors = { C3(170, 235, 255), C3(120, 210, 255), WHITE, C3(230, 190, 255) }, t0 = P.flash, at = box.home * CF(0, box.topY * 0.6, 0), speed = { 12, 20 }, up = 0.45, size = 1.3, grav = 30, transparency = 0.3, spinMin = 6, spinMax = 14, life = 0.8, away = job.away }, 'pop')
end
Sig.shatter = function() end
Sig.prismFan = function(job, i)
	if job.P.multi and i ~= job.P.best then return end
	fan(job, 'PrismFan' .. i, i, 6, { C3(110, 220, 255), WHITE, C3(255, 140, 230), C3(160, 255, 240) }, job.P.lid[i], 1.3, 25)
end
-- Grail: a gold beam marks the pad from the start, feathers on the slam, golden motes falling through the charge,
-- wings unfolding behind the pair, gold rays from the sky
Sig.heavenBeam = function(job, i)
	if i ~= job.P.best then return end
	local P = job.P
	local a0, a1 = Make.attach(job.anchor, 'HeavenFoot'), Make.attach(job.anchor, 'HeavenTop')
	local b = Make.beam(job.anchor, a0, a1, seqOf({ C3(255, 226, 140), C3(255, 196, 60) }), 1.2, 2.2, nseq({ { 0, 0.4 }, { 0.6, 0.65 }, { 1, 1 } }), 0.8, { Segments = 1, Tex = 'shaft' })
	b.Enabled = false
	job:onFrame(function(t)
		local a = M.c01(t / 0.3) * (t < P.land[i] and 1 or (1 - M.c01((t - P.land[i]) / 0.3)))
		local vis = a > 0.01
		if b.Enabled ~= vis then b.Enabled = vis end
		if vis then
			local acf = job.anchor.CFrame:Inverse()
			a0.CFrame = acf * CF(job.boxes[i].home.Position + V3(0, 0.2, 0))
			a1.CFrame = acf * CF(job.boxes[i].home.Position + V3(0, 70, 0))
			b.Width0, b.Width1 = 1.2 * a, 2.2 * a
		end
	end)
end
Sig.featherBurst = function(job, i)
	job:spawn({ kind = 'feather', n = job.P.multi and 4 or 10, colors = { WHITE, C3(255, 244, 220), C3(255, 226, 150) }, t0 = job.P.land[i], at = job.boxes[i].home * CF(0, 0.8, 0), speed = { 8, 13 }, up = 0.85, size = 0.9, grav = 7, away = job.away }, 'slam')
end
Sig.goldMotes = function(job, i)
	if i ~= job.P.best then return end
	local P = job.P
	-- (feather-light gold motes drifting down round the box through the charge, in the charge shot)
	local e = job:emitter('GoldMotes', 'glow', seqOf({ C3(255, 236, 170), C3(255, 200, 80) }), {
		life = { 2, 2.6 }, speed = { 1, 2 }, spread = Vector2.new(20, 20), direction = Enum.NormalId.Bottom, rotSpeed = NR(-40, 40), drag = 0.3, accel = V3(0, -0.6, 0),
		size = nseq({ { 0, 0 }, { 0.3, 0.6 }, { 1, 0.35 } }), transparency = nseq({ { 0, 1 }, { 0.2, 0.1 }, { 0.8, 0.3 }, { 1, 1 } }), rate = 12,
	}, job.volumes.around)
	job:at(P.charge[1], function() e.Enabled = true; job:recount() end)
	job:at(P.flash, function() e.Enabled = false; job:recount() end, true)
end
Sig.wings = function(job, i)
	if i ~= job.P.best then return end
	local P = job.P
	local wings = {}
	for _, side in { -1, 1 } do
		local feathers = {}
		for k = 1, 5 do
			table.insert(feathers, Make.part(job.folder, 'WingFeather', V3(0.5, (2.6 - k * 0.3) * G, 0.18) * (P.multi and 0.65 or 0.8), job.park, k % 2 == 0 and C3(232, 176, 70) or C3(240, 196, 110), Enum.Material.SmoothPlastic, { Transparency = 0.05 }))
		end
		table.insert(wings, { side = side, feathers = feathers })
	end
	job:onFrame(function(t)
		local pair = job.pairs[i]
		local parts, cfs = {}, {}
		local fade = 1 - M.c01((t - P.out) / 0.15)
		for _, wing in wings do
			for k, f in wing.feathers do
				local cf = job.park
				-- folded behind the pair while it rises in silhouette, they unfold as the light hits it (Back Out 600 ms,
				-- 40 ms a feather) and flap once at the reveal
				local t0 = P.accent[i] - 0.05
				local u = M.back((t - (t0 + (k - 1) * 0.04)) / 0.6, 1.6)
				if pair.pos and t > P.lid[i] and fade > 0 and job.pairYaw then
					local flap = 1 + 0.18 * M.bump(t, P.accent[i] + 0.75, 0.35)
					local spread = RAD(M.lerp(2, 30 + (k - 1) * 15, u)) * flap
					local root = CF(pair.pos) * job.pairYaw * CF(wing.side * (pair.width * 0.5 + 0.4), 0.3, pair.depth * 0.5 + 1.2)
					cf = root * ANG(0, 0, -wing.side * spread) * CF(0, f.Size.Y * 0.5, 0)
				end
				table.insert(parts, f)
				table.insert(cfs, cf)
			end
		end
		bulk(parts, cfs)
	end)
end
Sig.heavenRays = function(job, i)
	if i ~= job.P.best then return end
	local P = job.P
	local list = {}
	for k = 1, 4 do
		local a0, a1 = Make.attach(job.anchor, 'SkyRayTop' .. k), Make.attach(job.anchor, 'SkyRayFoot' .. k)
		local b = Make.beam(job.anchor, a0, a1, seqOf({ C3(255, 244, 200), C3(255, 210, 90) }), 3, 5, nseq({ { 0, 1 }, { 0.3, 0.7 }, { 0.85, 0.8 }, { 1, 1 } }), 0.8, { Segments = 1, Tex = 'shaft' })
		b.Enabled = false
		table.insert(list, { a0 = a0, a1 = a1, b = b, k = k })
	end
	job:onFrame(function(t)
		local a = M.c01((t - P.flash) / 0.4) * (1 - M.c01((t - P.out) / 0.2))
		local acf = job.anchor.CFrame:Inverse()
		for _, r in list do
			local vis = a > 0.02
			if r.b.Enabled ~= vis then r.b.Enabled = vis end
			if vis then
				-- (they come down behind the pair and either side of it, never across it)
				local x = (r.k - 2.5) * 5.5 + math.sin(t * 0.5 + r.k) * 0.6
				x += (x >= 0 and 3 or -3)
				r.a0.CFrame = acf * CF(job:wp(V3(x * 1.6, 60, 24)))
				r.a1.CFrame = acf * CF(job:wp(V3(x, 0.5, 7)))
				r.b.Width0, r.b.Width1 = 3 * a, 5 * a
			end
		end
	end)
end

---------------------------------------------------------------------------------------------- the beats
-- Confetti keeps off the poster words and never bunches: each piece's whole flight is seen through the camera that will
-- film it (sampled every 0.1 s from t0 for dur seconds); a piece that would cover a word for more than 0.15 s in all,
-- or join a crowd (more than 5 pieces in any 2 x 2 block of the screen's 30 px cells at 540p, checked every 0.2 s), is
-- re-rolled (about 20-35 ms once, at build)
local function viewAspect()
	local vc = workspace.CurrentCamera
	local ok, vp = pcall(function() return vc.ViewportSize end)
	return (ok and vp and vp.Y > 1) and vp.X / vp.Y or 16 / 9
end
function Job:wordGuard(t0, dur)
	local words = self.wordParts or {}
	local aspect = viewAspect()
	local dt, grid = 0.1, {}
	for k = 0, math.ceil(dur / dt) do
		local t = t0 + k * dt
		local cf, fov = Cam.at(self, t)
		local ty = math.tan(RAD(fov / 2))
		local g = { t = t, cf = cf, tx = ty * aspect, ty = ty, boxes = {} }
		for _, w in words do
			local x0, y0, x1, y1 = math.huge, math.huge, -math.huge, -math.huge
			for _, c in { V3(-1, -1, 0), V3(1, -1, 0), V3(-1, 1, 0), V3(1, 1, 0) } do
				local q = cf:PointToObjectSpace((w.CFrame * CF(c * w.Size * 0.5)).Position)
				if q.Z > -0.1 then x0 = nil; break end
				local u, v = q.X / (-q.Z * g.tx), q.Y / (-q.Z * g.ty)
				x0, y0, x1, y1 = math.min(x0, u), math.min(y0, v), math.max(x1, u), math.max(y1, v)
			end
			-- (a margin of about a piece's size round the word)
			if x0 then table.insert(g.boxes, { x0 - 0.04, y0 - 0.07, x1 + 0.04, y1 + 0.07 }) end
		end
		grid[k + 1] = g
	end
	local bits, crowd = self.bits, {}
	local function cellOf(k, u, v) return k * 4096 + math.floor((u + 1) * 16) * 64 + math.floor((1 - v) * 9) end
	return function(b)
		local inside, cells = 0, {}
		for k, g in grid do
			local tau = g.t - b.t0
			if tau >= 0 and tau < b.life then
				local q = g.cf:PointToObjectSpace((bits:pose(b, tau)))
				if q.Z < -0.1 then
					local u, v = q.X / (-q.Z * g.tx), q.Y / (-q.Z * g.ty)
					for _, bx in g.boxes do
						if u > bx[1] and u < bx[3] and v > bx[2] and v < bx[4] then
							inside += dt
							if inside > 0.15 then return false end
							break
						end
					end
					if k % 2 == 0 and math.abs(u) < 1 and math.abs(v) < 1 then
						local c = cellOf(k, u, v)
						for _, o in { 0, -1, -64, -65 } do
							local s = 0
							for _, d in { 0, 1, 64, 65 } do s += crowd[c + o + d] or 0 end
							if s >= 5 then return false end
						end
						table.insert(cells, c)
					end
				end
			end
		end
		for _, c in cells do crowd[c] = (crowd[c] or 0) + 1 end
		return true
	end
end
function Job:beats()
	local P, th, fx = self.P, self.P.theme, self.fx
	local rcol = rarityColor(P.rank)
	self:at(P.cut, function()
		for _, e in self.ambient do e.Enabled = true end
		self:recount()
	end, true)
	if P.premium then
		-- the telegraph pulses on the pad
		for _, t0 in P.telegraph do
			self:at(t0, function()
				for i, box in self.boxes do
					if P.n <= 4 or i % 2 == 1 then self:emit(fx.telegraph, 1, box.home * CF(0, 0.05, 0)) end
				end
			end)
		end
	else
		self:at(P.appear[1], function() self:emit(fx.glint, 1, self.boxes[1].home * CF(0, P.fallH + self.boxes[1].topY, 0)) end)
	end
	-- the landings: everything on the contact frame (squash, shake, punch, kick, core, shockwave, dust, sparks, debris)
	for i, box in self.boxes do
		local land = P.land[i]
		local big = (not P.multi) or i == P.n
		self:at(land, function()
			local base = box.home
			if P.premium then
				if big or i % 2 == 1 or P.n <= 4 then self:emit(fx.dust, 18 * (big and 1 or 0.6), base * CF(0, 1.0, 0)) end
			elseif big or i % 2 == 1 or P.n <= 4 then
				local np = big and 12 or 6
				for k = 0, np - 1 do
					local a = (k + 0.5) / np * 2 * PI
					local dir = base:VectorToWorldSpace(V3(math.sin(a), 0, -math.cos(a)))
					local o = base.Position + dir * (math.max(box.W, box.D) * 0.5 + 0.4) + V3(0, 0.7, 0)
					self:emit(fx.puffRing, 1, CFrame.lookAt(o, o + dir))
				end
			end
			-- (premium: the glow shockwave; normal: a crisp ring edge (Build.effects) and the dust fan read as concrete)
			if P.premium and (big or P.n <= 4 or i % 2 == 1) then self:emit(fx.shock, 1, base * CF(0, 0.06, 0)) end
			self:emit(fx.core, 1, base * CF(0, box.seamY * 0.6, 0))
			self:emit(fx.sparks, (P.premium and 14 or 6) * (big and 1 or 0.5), base * CF(0, 0.3, 0))
			for _, sp in self.speakers do sp.bumpAt = self.t end
		end)
		if P.premium and fx.shock2 and big then self:at(land + 0.07, function() self:emit(fx.shock2, 1, box.home * CF(0, 0.08, 0)) end) end
		Cam.shake(self, land, P.premium and 'slam' or 'land', P.trauma[i])
		if big then
			if P.premium then
				Cam.punch(self, land, -10, 0.06, 2.5, 0.55)
				Cam.kick(self, land, -1.2, -0.15)
				self:at(land, function() self.pulseAt = self.t end)
			else
				Cam.punch(self, land, -4, 0.05, 3.2, 0.7)
			end
		end
		-- debris: real chunks (premium 12; on the normal tier the heavy themes' rock and ice only)
		local deb = th.Debris
		local count = P.premium and (P.multi and (big and 10 or 4) or 12) or ((deb.kind == 'rock' or deb.kind == 'shard') and (P.multi and 2 or 5) or 0)
		if count > 0 then
			if P.premium then
				-- (premium: chunks in bright colours that read on the night deck, born on the box's rim and thrown toward the
				-- camera's half of the pad, so they land 2-5 studs out and rest in view through the charge)
				local cols = th.Id == 'Grail' and { C3(255, 200, 60), WHITE, C3(255, 226, 140) } or th.Id == 'Exclusive' and { C3(120, 230, 255), WHITE, C3(255, 150, 230) } or { th.Accent, WHITE, th.Color }
				local glass = th.Id == 'Exclusive'
				self:spawn({ kind = glass and 'shard' or 'cube', n = P.multi and count or 14, colors = cols, t0 = land, at = box.home * CF(0, 0.6, 0), ring = box.W * 0.55, dir = box.home:VectorToWorldSpace(V3(0, 0, -1)), cone = 3.3,
					hz = { 6, 12 }, vz = { 8, 13 }, size = 0.65, grav = 80, bounce = 0.3, spinMin = 3.1, spinMax = 9.4, material = glass and 'Glass' or 'SmoothPlastic', neon = glass, life = 2.9 }, 'slam')
			else
				self:spawn({ kind = deb.kind, n = count, colors = deb.colors, t0 = land, at = box.home * CF(0, 0.6, 0), hz = { 12, 22 }, vz = { 26, 36 }, size = 0.55, grav = 120, bounce = 0.35, spinMin = 3.1, spinMax = 9.4, material = deb.material, neon = deb.kind == 'shard', life = 2.0, away = self.away }, 'slam')
			end
		end
	end
	-- the wobbles: a seam puff at each, a little shake
	for wi, w in P.wobSpec do
		for i, box in self.boxes do
			local t0 = w[1] + P.wobOff[i]
			if t0 < P.pop[i] - 0.1 and (not P.multi or i == P.best or wi == #P.wobSpec) then
				self:at(t0 + 0.05, function() self:emit(fx.puff, (wi + 2) * (P.multi and 0.5 or 1), box:mouth()) end)
			end
		end
		Cam.shake(self, w[1], 'pop', P.premium and 0.12 or 0.08 + 0.04 * wi)
	end
	-- the pops (normal) and the lid blasts (premium)
	for i, box in self.boxes do
		local big = (not P.multi) or i == P.best
		self:at(P.pop[i], function()
			local mouth = box:mouth()
			self:emit(fx.core, 1, mouth)
			if P.premium then self:emit(fx.lidBurst, P.n >= 5 and 8 or 30, mouth) else self:emit(fx.popBurst, big and 12 or 6, mouth) end
		end, big)
		if not P.premium then Cam.shake(self, P.pop[i], 'pop', big and 0.3 or 0.15) end
	end
	if P.premium then
		self:at(P.motes, function() fx.motes.Enabled = true; self:recount() end)
		self:at(P.dip[2] - 0.1, function() fx.motes.Enabled = false; self:recount() end, true)
		local box = self.boxes[P.best]
		for k = 0, 4 do
			self:at(P.dip[1] + 0.05 + k * 0.07, function()
				self:emit(fx.crackle, 2, box.home * CF((M.hash(k, 1) - 0.5) * box.W, box.topY * (0.4 + M.hash(k, 2) * 0.6), (M.hash(k, 3) - 0.5) * box.D))
			end)
		end
		Cam.shake(self, P.flash, 'blast', 0.7)
		Cam.punch(self, P.flash, 10, 0.12, 1.6, 0.9)
		self:at(P.flash, function()
			fx.pillarMotes.Parent.CFrame = self.anchor.CFrame:ToObjectSpace(box.home * CF(0, box.seamY, 0))
			fx.pillarMotes.Enabled = true
			self:recount()
		end, true)
		self:at(P.flash + 1.5, function() fx.pillarMotes.Enabled = false; self:recount() end, true)
	end
	-- the reveal accents: the best gets its rarity's channels; the others a few sparkles
	for i, box in self.boxes do
		local best = i == P.best
		self:at(P.accent[i], function()
			local pair = self.pairs[i]
			local at = pair.pos and CF(pair.pos) or box:mouth()
			-- (premium: the reveal is busier than the charge: triple sparks, a shockwave, the lid burst again)
			self:emit(fx.accentSparks, best and P.R.Sparks * (P.premium and 3 or 1) or 6, at)
			if best and P.premium then
				self:emit(fx.shock, 1, CF(at.Position.X, self.padTop + 0.1, at.Position.Z))
				self:emit(fx.popBurst, P.n >= 5 and 10 or 24, at)
			end
			if best and P.R.Ring > 0 then self:emit(fx.accentRing, 1, CF(at.Position.X, self.padTop + 0.06, at.Position.Z)) end
			if best and fx.accentRing2 then self:at(self.t + 0.15, function() self:emit(fx.accentRing2, 1, CF(at.Position.X, self.padTop + 0.08, at.Position.Z)) end) end
			if best then fx.drift.Enabled = true; self:recount() end
		end, best)
		if best and P.R.Shake > 0 then Cam.shake(self, P.accent[i], 'reveal', P.R.Shake) end
		if best then Cam.punch(self, P.accent[i], -3, 0.05, 3, 0.7) end
	end
	-- confetti: two cannons just below the hero frame's bottom corners, 60 deg up and inward, so the pieces peak in the
	-- top third and flutter down through the frame (nothing piles up on the floor); Mythic and Secret add a rain from
	-- above across the whole width. Rects and strips.
	local nConf = P.premium and (P.rank == 2 and 32 or P.rank == 3 and 36 or 48) or P.R.Confetti
	local hs = self.heroShot
	if nConf > 0 and hs then
		local t0 = P.premium and P.confetti or (P.accent[P.best] - 0.05)
		local cols = P.R.SlowMo and Themes.Rainbow or { th.Color, th.Accent, th.Third, rcol, WHITE }
		local eye, at = self:wp(hs[1]), self:wp(hs[2])
		local cam = CFrame.lookAt(eye, at)
		local dist = (at - eye).Magnitude
		local halfH = dist * math.tan(RAD(hs[3] / 2))
		local halfW = halfH * 16 / 9
		local guard = self:wordGuard(t0, 3.8)
		for _, sx in { -1, 1 } do
			local lanes = P.n == 1
			local origin = CF(cam * V3(sx * (lanes and 0.93 or 0.95) * halfW, -(halfH + 0.8), -dist))
			local inward = cam.RightVector * -sx
			local dir = V3(inward.X, 0, inward.Z).Unit
			-- (fitted to the flutter model: the apex lands in the top third whatever the frame's size, and the pieces only
			-- reach ~0.65 of the half-width inward: they rise and flutter down beside the pair, never over it)
			-- (de-clumped: a 2 x 0.5 x 0.5 stud mouth, four puffs 70 ms apart, a wide speed range, a 35 deg cone, each piece
			-- its own drag and a little sideways drift: a spray that opens out, not a ball that drifts as one)
			-- (a single's rise up the frame's outer lanes, outside the posters that frame the pair; and a piece whose flight
			-- would sit on a poster word or join a crowd is re-rolled: Job:wordGuard)
			local hz = lanes and { 0.1 * halfH, 0.45 * halfH } or { 0.7 * halfH, 1.7 * halfH }
			local vz = { 3.67 * halfH + 4, 3.67 * halfH + 16 }
			local mouth = V3(1, 0.25, 0.25)
			local spec = { colors = cols, at = origin, hz = hz, vz = vz, dir = dir, cone = 0.6, size = 0.75, grav = 30, life = 2.3, box = mouth, bursts = 4, burstGap = 0.07, dragMin = 0.28, dragMax = 0.45, drift = 1.5, accept = guard, tries = 10 }
			local r = table.clone(spec)
			r.kind, r.n, r.t0 = 'rect', nConf / 4, t0 + (sx > 0 and 0.035 or 0)
			self:spawn(r, 'confetti')
			local st = table.clone(spec)
			st.kind, st.n, st.t0 = 'strip', nConf / 4, t0 + (sx > 0 and 0.035 or 0) + 0.02
			self:spawn(st, 'confetti')
			if P.R.Rain > 0 then
				-- (the rain falls in the two side bands, clear of the pair)
				self:spawn({ kind = 'rect', n = P.R.Rain / 2, colors = cols, t0 = t0 + 0.15, at = CF(cam * V3(sx * (lanes and 0.9 or 0.78) * halfW, halfH + 1.2, -dist)), speed = { 1, 3 }, size = 0.75, rain = halfW * (lanes and 0.08 or 0.2), spread = 0.8, grav = 16, life = 2.6, accept = guard, tries = 10 }, 'confetti')
			end
		end
	end
	-- premium: when the Power chip has counted up, a theme ring stamps under the pair with a few sparks
	if fx.stamp then
		self:at(P.count[2], function()
			local pair = self.pairs[P.best]
			if not pair.pos then return end
			self:emit(fx.stamp, 1, CF(pair.pos - V3(0, pair.height * 0.5 + 0.2, 0)))
			self:emit(fx.accentSparks, 8, CF(pair.pos))
		end)
		Cam.punch(self, P.count[2], -2, 0.05, 3, 0.7)
	end
	self:at(P.out, function() fx.drift.Enabled = false; self:recount() end, true)
end

---------------------------------------------------------------------------------------------- motion
-- Box i at t: hidden, hanging, falling (Quad In, stretched), landing (hit-stop, squash, spring), wobbling (spring kicks,
-- growing), crouching, popping; the lid hinged (it cracks on the last wobbles), then thrown (or hidden: shattered).
function Job:boxAt(i, t)
	local P = self.P
	local box = self.boxes[i]
	local home = box.home
	local land, f0, ap = P.land[i], P.fall0[i], P.appear[i]
	if t < ap or (P.premium and t < f0) then return self.park, 1, 1, { hidden = true, park = self.park } end
	if t < land then
		local cf
		local sy = 1
		if t < f0 then
			-- the hang: it appears at the top of the frame, lifts 0.4 and tilts 4 deg (Sine Out)
			local u = (t - ap) / (f0 - ap)
			cf = home * CF(0, P.fallH + 0.4 * math.sin(math.min(1, u * 1.4) * PI / 2), 0) * ANG(0, 0, RAD(4) * math.sin(u * PI))
		else
			local u = (t - f0) / (land - f0)
			local q = 1 - u * u
			if P.premium then
				-- the comet's path: a straight line down from P.cometFrom (Quad In), leaning into it
				cf = (home + home:VectorToWorldSpace(P.cometFrom * q)) * ANG(-0.45 * q, 0, 0.3 * q)
			else
				cf = home * CF(0, P.fallH * q, 0)
			end
			sy = 1 + (P.premium and 0.25 or 0.15) * M.c01((u - 0.6) / 0.4)
		end
		return cf, 1 / math.sqrt(sy), sy, { open = 0 }
	end
	local tau = t - land
	local hs = P.hs[i]
	local jelly = self.jelly and not P.premium
	local S = jelly and 0.45 or (P.premium and 0.38 or 0.28)
	local sy
	if tau < hs then sy = 1 - S
	else sy = 1 - S * (jelly and M.spring(tau - hs, 3.5, 0.2) or M.spring(tau - hs, 5, P.premium and 0.4 or 0.45)) end
	local yaw, roll, hop = 0, 0, 0
	for wi, w in P.wobSpec do
		local t0 = w[1] + P.wobOff[i] + (P.premium and (M.hash(i, wi) - 0.5) * 0.04 or 0)
		local q = t - t0
		if q >= 0 and q < 0.9 and t0 < P.pop[i] - 0.05 then
			local amp = (P.reduced and 0.5 or 1) * (P.multi and (0.85 + 0.3 * M.hash(i, wi + 5)) or 1)
			local dirn = (wi % 2 == 0) and -1 or 1
			roll += dirn * RAD(w[2]) * M.kick(q, 4.5, 0.3) * amp
			yaw += -dirn * RAD(w[2] * 0.35) * M.kick(q - 0.03, 4.5, 0.3) * amp
			if q < 0.24 then hop += w[3] * G * 0.75 * math.sin(q / 0.24 * PI) * amp end
			sy *= 1 - 0.1 * M.bump(q, -0.04, 0.08) - 0.12 * M.bump(q, 0.22, 0.1)
		end
	end
	local pop = P.pop[i]
	if not P.premium then
		local c0 = P.crouch[i]
		if t >= c0 and t < pop then sy *= 1 - 0.15 * M.out((t - c0) / math.min(0.15, pop - c0), 2) end
	elseif t >= P.dip[1] and t < pop then
		local u = (t - P.dip[1]) / (pop - P.dip[1])
		roll += math.sin(t * 90) * RAD(1.6) * u
		yaw += math.sin(t * 71) * RAD(1.1) * u
	end
	if t >= pop then sy *= 1 + 0.12 * M.spring(t - pop, 5, 0.4) end
	local sx = 1 / math.sqrt(sy)
	local cf = home * CF(0, hop, 0) * ANG(0, yaw, roll)
	local lid
	if t >= pop then
		if box.shatter then
			lid = { hidden = true, park = self.park }
		else
			local q = t - pop
			local hr = box.hingeRel
			local hinge = home * CF(hr.Position * V3(sx, sy, sx)) * hr.Rotation
			if P.premium then
				-- up 9 studs and 4 back from the camera, tumbling 540 deg, scaled to nothing by +0.7 s (never at the lens)
				local cam = self.camCF
				local away = cam and (hinge.Position - cam.Position) or home.LookVector
				away = V3(away.X, 0, away.Z)
				away = away.Magnitude > 0.1 and away.Unit or V3(0, 0, 1)
				-- (a multi-open's many lids: lower and gone sooner, so together they never fill the top of the frame)
				local life, up = P.multi and 0.45 or 0.7, P.multi and 5 or 9
				local ls = math.max(0.02, 1 - M.c01((q - life * 0.35) / (life * 0.65)))
				local flip = RAD(540) * M.out(q / life, 2)
				lid = { fly = CF(hinge.Position + V3(0, up * M.out(q / 0.5, 2), 0) + away * 4 * M.out(q / 0.7, 1.5)) * hinge.Rotation * ANG(-flip, 0, RAD(90) * M.out(q / 0.7, 2)), scale = ls }
				if ls <= 0.02 then lid = { hidden = true, park = self.park } end
			else
				local up = q < 0.3 and 3.75 * G * M.out(q / 0.3, 2) or 3.75 * G - 6.75 * G * M.inn((q - 0.3) / 0.35, 2)
				local back = 3.2 * G * M.c01(q / 0.65)
				local flip = RAD(360) * M.out(q / 0.65, 2)
				local shrink = 1 - M.c01((q - 0.45) / 0.25)
				lid = { fly = CF(hinge.Position + home:VectorToWorldSpace(V3(0, up, back))) * hinge.Rotation * ANG(-flip, 0, 0), scale = math.max(0.02, shrink) }
				if shrink <= 0.02 then lid = { hidden = true, park = self.park } end
			end
		end
	else
		local crack = 0
		for wi, w in P.wobSpec do
			local q = t - (w[1] + P.wobOff[i])
			if wi >= #P.wobSpec - 1 and q > 0.04 and q < 0.3 then crack = math.max(crack, math.sin((q - 0.04) / 0.26 * PI) * 0.08 * (wi / #P.wobSpec)) end
		end
		lid = { open = crack }
	end
	-- once its pair is up, the box sinks through the pad (Quad In 450 ms): the hero frame is the pair's alone
	local ts = P.rise[i] + P.riseLen + 0.05
	if t > ts then
		local u = M.c01((t - ts) / 0.45)
		if u >= 1 then return self.park, 1, 1, { hidden = true, park = self.park } end
		cf = cf * CF(0, -(box.fullH + 0.4) * M.inn(u, 2), 0)
	end
	return cf, sx, sy, lid
end
-- Pair i: hidden in its box; rises at its time (normal Back Out, premium Quint Out), ONE decelerating hero turn to a 3/4
-- view, then a slow idle; premium in silhouette until its accent; a multi's best scales up and steps forward.
function Job:pairAt(i, t)
	local P = self.P
	local pair = self.pairs[i]
	local box = self.boxes[i]
	if t < P.rise[i] then return nil end
	local tr = t - P.rise[i]
	if P.slowmo and i == P.best and t > P.slowmo[1] then
		-- a Secret's false calm: the clock runs at 0.3x through the slow-mo window
		local a, b = P.slowmo[1], P.slowmo[2]
		tr = (a - P.rise[i]) + (math.min(t, b) - a) * 0.3 + math.max(0, t - b)
	end
	local u = tr / P.riseLen
	local e = P.premium and M.out(u, 5) or M.back(u, 1.4)
	local start = box.home.Position + V3(0, box.seamY * 0.35, 0)
	local hover = box.home.Position + V3(0, box.seamY + P.riseH, 0)
	-- (a Buy 8's pairs fly from their boxes to the line-up: Job:lineup)
	if self.slots then hover = self:wp(self.slots[i]) end
	local pos = start:Lerp(hover, e)
	if P.multi and P.n <= 4 and not self.slots then
		-- a Buy 3: the pairs gather into a tighter row as they rise (bigger in the group shot)
		local q = self.O:PointToObjectSpace(pos)
		pos = self.O * V3(q.X * M.lerp(1, UnboxCinematic.Gather, M.c01(e)), q.Y, q.Z)
	end
	local s = P.premium and M.lerp(0.55, 1, M.out(u, 3)) or M.lerp(0.3, 1, M.back(u, 1.4))
	local spinU = tr / P.spinLen
	local yaw = RAD(-30) - (self.heroYaw or 0) + 2 * PI * P.spinTurns * (1 - (P.premium and M.out(spinU, 3) or M.out(spinU, 4)))
	local idle = math.max(0, tr - math.max(P.riseLen, P.spinLen))
	-- the hold: a slow sway (not frozen), from the end of the hero turn
	yaw += RAD(P.premium and 25 or 12) * math.sin(idle * 2 * PI / 2.4) * M.smooth(M.c01(idle / 0.8))
	pos += V3(0, math.sin(idle * PI) * 0.2 * M.c01(idle * 2), 0)
	if P.multi and i == P.best then
		local lu = M.back((t - P.accent[P.best] + 0.1) / 0.25, 1.4)
		if lu > 0 then
			if self.slots then
				-- (its slot is already the front one)
				s *= 1 + (P.n >= 5 and 0.35 or 0.15) * lu
			else
				pos += V3(0, 0.4 * lu, -(P.premium and 1.5 or 1) * G * lu)
				s *= 1 + 0.15 * lu
			end
		end
	end
	local yawCF = ANG(0, yaw, 0)
	if i == P.best then self.pairYaw = box.home.Rotation * yawCF end
	pair.pos = pos + V3(0, (pair.base + pair.height * 0.5) * s, 0)
	return CF(pos) * box.home.Rotation * yawCF * ANG(RAD(-8), 0, 0), s
end

-- A Buy 8's line-up (stage space, each pair's base): the lowest five on a back row, raised; the next two flanking the
-- best, which stands front and centre (1.35x). Every pair stays in view and none hides another.
function Job:lineup()
	local P = self.P
	if P.n == 2 then
		-- the welcome gift: the best pair centre-left (1.15x, its name under it), the other one right
		local other = P.best == 1 and 2 or 1
		local box = self.boxes[P.best]
		local y = P.homes[P.best].Y + box.seamY + P.riseH
		self.slots = { [P.best] = V3(2.4, y, -0.8), [other] = V3(-3.6, y, 0.4) }
		return
	end
	if P.n < 5 then return end
	-- (spaced by the others' typical width: one winged pair doesn't push the whole line-up away)
	local pw, ph, n = 0, 0, 0
	for i, pr in self.pairs do
		if i ~= P.best then
			pw += pr.width
			ph = math.max(ph, pr.height)
			n += 1
		end
	end
	local widest = 0
	for i, pr in self.pairs do
		if i ~= P.best then widest = math.max(widest, pr.width) end
	end
	pw = pw / math.max(1, n) * 1.08
	local sp = math.max(pw * 1.04, widest * 1.1)
	local yF = 0.22 + 2.4 * G
	local yB = yF + ph * 1.3
	local others = {}
	for _, i in P.order do
		if i ~= P.best then table.insert(others, i) end
	end
	local nb = math.max(1, #others - 2)
	local slots = {}
	for j = 1, nb do slots[others[j]] = V3((j - (nb + 1) / 2) * sp, yB, 3.2) end
	local bw = self.pairs[P.best].width * 1.35
	for j = nb + 1, #others do
		local side = (j == nb + 1) and -1 or 1
		slots[others[j]] = V3(side * (bw * 0.5 + pw * 0.55 + 0.3), yF, -1.2)
	end
	slots[P.best] = V3(0, yF + 0.2, -2.6)
	self.slots, self.lineSp, self.lineW, self.lineY = slots, sp, (nb - 1) * sp + pw, { yF, yB, ph }
	self.backRow = {}
	for j = 1, nb do self.backRow[others[j]] = true end
end

---------------------------------------------------------------------------------------------- per frame
function Job:recount()
	local n = 0
	for _, e in self.emitterList do
		if e.Enabled then n += e.Rate * (e.Lifetime.Min + e.Lifetime.Max) / 2 end
	end
	for _, p in self.pairs or {} do n += Pair.live(p) end
	self.contLive = n
end
-- The continuous layers (ambient, drift, motes, the hold layer, the pairs' ShoeFX) together get at most 50 % of the cap (and the
-- phone / low-graphics scale), so the bursts always have room.
function Job:fitBudget()
	local cont, list = 0, {}
	local function add(e)
		if e:IsA('ParticleEmitter') and e.Rate > 0 then
			cont += e.Rate * (e.Lifetime.Min + e.Lifetime.Max) / 2
			table.insert(list, e)
		end
	end
	for _, e in self.emitterList do add(e) end
	for _, p in self.pairs do
		for _, d in p.fxList do add(d) end
	end
	local k = math.min(self.vfxScale, self.cap * 0.5 / math.max(1, cont))
	if k < 1 then
		for _, e in list do e.Rate = e.Rate * k end
	end
	self.contMax = cont * math.min(1, k)
end
function Job:step(dt)
	if self.Done then return end
	local t = self.t + math.clamp(dt or 0, 0, 0.1)
	local jumped = false
	if self.skipTo then
		if self.skipTo > t then
			t, jumped = self.skipTo, true
			self.skipAt = t
		end
		self.skipTo = nil
	end
	self.t, self.T = t, t
	for _, e in self.events do
		if not e.done and e[1] <= t then
			e.done = true
			if not jumped or e[3] or e[1] > t - 0.05 then
				local ok, err = pcall(e[2])
				if not ok then warn('[UnboxCinematic] beat: ' .. tostring(err)) end
			end
		end
	end
	-- (events scheduled while firing: kept for the next frame)
	local ok, err = pcall(self.frame, self, t)
	if not ok then
		warn('[UnboxCinematic] frame: ' .. tostring(err))
		self:finish()
		return
	end
	if t >= self.P.done then self:finish() end
end
function Job:frame(t)
	local P = self.P
	self.pulse = (self.pulseAt and (t - self.pulseAt) < 0.08) and 0.18 or 0
	Look.apply(self, t)
	local cam = workspace.CurrentCamera
	if cam then
		if t >= P.cut and t < self.snapAt then
			local cf, fov = Cam.at(self, t)
			cam.CameraType = Enum.CameraType.Scriptable
			cam.CFrame = cf
			cam.FieldOfView = fov
			cam.Focus = self.focus
			self.camCF = cf
		elseif t >= self.snapAt and not self.camBack then
			self.camBack = true
			self:restoreCamera()
		end
	end
	-- boxes, their seams (the honest tease), their contact shadows
	for i, box in self.boxes do
		local cf, sx, sy, lid = self:boxAt(i, t)
		Box.pose(box, cf, sx, sy, lid)
		self:seam(i, t)
		local t0 = P.premium and P.fall0[i] - 0.1 or P.appear[i] - 0.05
		if t >= t0 and t < P.land[i] + 0.05 then
			local u = M.c01((t - t0) / (P.land[i] - t0))
			local d = box.W * M.lerp(0.4, 1.05, u * u)
			box.shadow.Size = V3(0.04, d, d * box.D / box.W)
			box.shadow.CFrame = box.home * CF(0, 0.03, 0) * ANG(0, 0, PI / 2)
			box.shadow.Transparency = 1 - M.lerp(0.3, 0.65, u)
		elseif box.shadow.Transparency < 1 then
			box.shadow.Transparency = 1
			box.shadow.CFrame = self.park
		end
	end
	-- pairs (ShoeFX on from the rise on the normal tier, at the accent on premium; a premium pair is a silhouette until
	-- the light hits it)
	local recount = false
	for i, pair in self.pairs do
		local cf, s = self:pairAt(i, t)
		if cf then
			pair.actor:pose(cf, s)
			if P.premium then pair.actor:tint(C3(12, 12, 20), 1 - M.c01((t - P.accent[i]) / 0.18)) end
			local on = t >= P.accent[i] - (P.premium and 0 or 0.5) and t < P.out + 0.15
			if pair.fxOn ~= on then Pair.fx(pair, on); recount = true end
		else
			pair.actor:pose(self.park, 0.3)
		end
	end
	if recount then self:recount() end
	self.bits:step(t)
	self:effects(t)
	for _, fn in self.updaters do fn(t) end
	Words.update(self, t)
	self.peak = math.max(self.peak or 0, self:live(t))
end
-- The seam glow: white on the first wobble, then one rarity per wobble up to the true one (normal: blue at wobble 2,
-- purple at 3, Legendary+ at the crouch; premium: Rare..Mythic/Secret at wobbles 2..5); white-hot in the dark beat.
function Job:seam(i, t)
	local P, box = self.P, self.boxes[i]
	local r = box.rank
	local w0 = P.wobSpec[1][1] + P.wobOff[i]
	local pop = P.pop[i]
	local a = 0
	if t >= w0 and t < pop + 0.2 then
		a = M.c01((t - w0) / math.max(0.2, pop - w0))
		if P.premium and t > P.dip[1] then a = 1 end
		if t >= pop then a = 1 - (t - pop) / 0.2 end
	end
	local show = 0
	for k, w in P.wobSpec do
		if t >= w[1] + P.wobOff[i] then show = k end
	end
	local step = 1
	if P.premium then
		step = math.min(r, math.max(1, show))
	else
		if show >= 2 and r >= 2 then step = 2 end
		if show >= 3 and r >= 3 then step = 3 end
		if (t >= P.crouch[i] or (#P.wobSpec < 3 and show >= #P.wobSpec)) and r >= 2 then step = r end
	end
	local col = step <= 1 and WHITE or (step >= 6 and M.hsv(t * 2, i) or rarityColor(step))
	if P.premium and t >= P.dip[1] then col = col:Lerp(WHITE, M.c01((t - P.dip[1]) / 0.3) * 0.7) end
	box.teaseColor = col
	if a > 0.02 then
		box.seam.CFrame = (box.cf or box.home) * CF(0, box.seamY, 0)
		box.seam.Transparency = M.lerp(0.75, 0, M.c01(a * 1.3))
		if box.seam.Color ~= col then box.seam.Color = col end
	elseif box.seam.Transparency < 1 then
		box.seam.Transparency = 1
		box.seam.CFrame = self.park
	end
end
function Job:effects(t)
	local P, th = self.P, self.P.theme
	local acf = self.anchor.CFrame:Inverse()
	-- the pad's neon lip and the sign: on with the stage (premium: a sweep), dim in the dark beat, relit after the flash
	local rimA = P.premium and M.c01(t / 0.4) or M.c01((t - P.cut) / 0.3)
	if P.premium and t >= P.dip[1] and t < P.flash then rimA = M.lerp(1, 0.2, M.c01((t - P.dip[1]) / 0.2)) end
	local rim = (P.premium and t >= P.flash) and th.Relit or th.Rim
	local c = C3(40, 40, 52):Lerp(rim, rimA)
	if self.padRim.Color ~= c then
		self.padRim.Color = c
		for k, p in self.signNeon do p.Color = C3(40, 40, 52):Lerp(rim, M.c01(rimA * 1.25 - (k - 1) * 0.06)) end
	end
	-- a Buy 8's posters step out of the line-up shot (they'd sit between the back row's pairs)
	if P.n >= 5 and self.posterParts then
		local d = M.c01((t - (P.group - 0.4)) / 0.3)
		if d ~= self.posterDim then
			self.posterDim = d
			for _, p in self.posterParts do
				local b = p:GetAttribute('T0')
				if b == nil then
					b = p.Transparency
					p:SetAttribute('T0', b)
				end
				p.Transparency = d >= 1 and 1 or M.lerp(b, 1, d)
			end
			for _, l in self.posterLabels do
				l[1].TextTransparency = d
				l[2].Transparency = d
			end
		end
	end
	-- the sign fades out of the hero shot before the banner lands (nothing brighter than the words near them)
	if self.signText then
		local t0 = math.min(P.banner, P.accent[P.best]) - 0.3
		local dim = M.c01((t - t0) / 0.2)
		local tr = dim >= 1 and 1 or 0.95 * dim
		if math.abs(self.signText.TextTransparency - tr) > 1e-3 then
			self.signText.TextTransparency = tr
			self.signStroke.Transparency = tr
			for _, p in self.signNeon do p.Transparency = tr end
			for _, p in self.signParts or {} do p.Transparency = tr end
		end
	end
	-- the lamps: steady (Street: off until they flicker on at the landing); off in the premium dark beat
	local lamp = self.lampsOff and (self.lampLevel or 0) or 1
	if P.premium and t >= P.dip[1] and t < P.flash then lamp = 0.15 end
	if P.premium and th.Id == 'Exclusive' and t >= P.flash and not self.coolLamps then
		-- (Exclusive: the relit stage gets a cool white key; the cyan rim is the rim light)
		self.coolLamps = true
		for _, l in self.lamps do
			l.color = C3(215, 235, 255)
			l.light.Color = l.color
			l.light.Brightness = -1
		end
	end
	-- (capped through the hold: the pair is lit by the look, not blown out by the lamps)
	local hq = M.c01((t - (P.accent[P.best] - 0.3)) / 0.5)
	lamp *= M.lerp(1, self.lightPair and 0.45 or 0.8, hq)
	for _, l in self.lamps do
		if math.abs(l.light.Brightness - 1.6 * lamp) > 1e-3 then
			l.light.Brightness = 1.6 * lamp
			l.head.Color = BLACK:Lerp(l.color, 0.15 + 0.85 * lamp)
		end
	end
	for _, sp in self.speakers do
		local q = sp.bumpAt and (t - sp.bumpAt) or 1
		sp.actor:pose(sp.base, q < 0.08 and 1.05 or 1)
	end
	-- the box's own light: the seam's glow while it charges, a burst at the pop
	local bb = self.boxes[P.best]
	local glow = 0
	for i = 1, P.n do glow = math.max(glow, M.bump(t, P.pop[i] - 0.02, 0.45)) end
	local w1 = P.wobSpec[1][1]
	local leak = (t >= w1 and t < P.pop[P.best]) and M.c01((t - w1) / (P.pop[P.best] - w1)) or 0
	self.boxLight.Brightness = leak * 1.6 + glow * (P.premium and 4 or 2.5)
	self.boxLight.Color = bb.teaseColor or WHITE
	self.boxGlow.CFrame = (bb.cf or bb.home) * CF(0, bb.seamY + 1, -1.2)
	-- premium: the comets (a glowing head and a tail; the box is inside the glow as it falls)
	for i, cm in self.comets or {} do
		local box = self.boxes[i]
		local ap, f0, land = P.appear[i], P.fall0[i], P.land[i]
		if t >= ap and t < land then
			local from = box.home:VectorToWorldSpace(P.cometFrom)
			local dir = from.Unit
			local head, size, tail, tr
			if t < f0 then
				-- the dot: high and far behind the pad, drifting in
				local u = (t - ap) / (f0 - ap)
				head = box.home.Position + from + dir * 9 * (1 - M.sineInOut(u))
				size = 2.8 * M.out(M.c01((t - ap) / 0.1), 2)
				tail, tr = 16 + 8 * u, 0
			else
				local u = M.c01((t - f0) / (land - f0))
				head = ((box.cf or box.home) * CF(0, box.fullH * 0.45, 0)).Position
				size = M.lerp(3, box.W * 0.85, u * u)
				tail, tr = M.lerp(24, 34, u), M.lerp(0.05, 0.45, u)
			end
			cm.head.Size = V3(size, size, size)
			cm.head.CFrame = CF(head)
			cm.head.Transparency = tr
			cm.a0.CFrame = acf * CF(head)
			cm.a1.CFrame = acf * CF(head + dir * tail)
			cm.tail.Width0 = math.max(2.4, size * 0.9)
			if not cm.tail.Enabled then cm.tail.Enabled = true end
			if cm.f then
				local fl = size * 1.7
				local cam = self.camCF
				local right, up = cam and cam.RightVector or V3(1, 0, 0), cam and cam.UpVector or V3(0, 1, 0)
				local spin = t * 2
				local d1 = (right * math.cos(spin) + up * math.sin(spin)) * fl
				local d2 = (right * -math.sin(spin) + up * math.cos(spin)) * fl
				cm.f[1].CFrame, cm.f[2].CFrame = acf * CF(head - d1), acf * CF(head + d1)
				cm.f[3].CFrame, cm.f[4].CFrame = acf * CF(head - d2), acf * CF(head + d2)
				for _, b in cm.fb do
					if not b.Enabled then b.Enabled = true end
				end
			end
		elseif cm.tail.Enabled then
			cm.tail.Enabled = false
			cm.head.CFrame = self.park
			if cm.fb then
				for _, b in cm.fb do b.Enabled = false end
			end
		end
	end
	for i, ring in self.slamRings or {} do
		local box = self.boxes[i]
		local u = (t - P.land[i]) / 0.4
		if u >= 0 and u <= 1 then
			local r = M.lerp(box.W * 0.45, (P.premium and 14 or 7 * G) * (P.multi and 0.6 or 1), M.out(u, 4))
			ring:pose(box.home * CF(0, 0.1, 0), r, (1 - u) ^ 1.5, 0, M.lerp(1, 0.4, u))
		elseif u > 1 and not ring.off then
			ring.off = true
			ring:pose(box.home, 0, 0, 0)
		end
	end
	if self.rings then self:ringsAt(t) end
	-- light pillars: open (Back Out 120 ms), hold, thin out
	for _, p in self.pillars do
		local box = self.boxes[p.i]
		local t0 = P.premium and P.lid[p.i] or P.accent[p.i] - 0.2
		local u = t - t0
		local w = 0
		if u >= 0 then
			w = (P.premium and 5 or 3.5) * M.back(u / 0.12, 1.8)
			local out0 = P.premium and (P.pillarOut[1] - t0) or 0.9
			w *= 1 - M.inn((u - out0) / 0.6, 2)
		end
		w = math.max(0, w) * ((P.premium and P.n >= 5) and 0.8 or 1)
		local vis = w > 0.03
		if p.beam.Enabled ~= vis then p.beam.Enabled = vis end
		if vis then
			local base = box.home.Position + V3(0, box.seamY, 0)
			p.a0.CFrame = acf * CF(base)
			p.a1.CFrame = acf * CF(base + V3(0, 60, 0))
			p.beam.Width0, p.beam.Width1 = w, w * 1.3
			if P.R.SlowMo then p.beam.Color = ColorSequence.new(WHITE, M.hsv(t, p.i)) end
		end
	end
	-- god rays behind the best pair (a fan turning at 8 deg/s, kept behind it)
	local pair = self.pairs[P.best]
	if #self.rays > 0 then
		local t0 = P.premium and P.lid[P.best] + 0.05 or P.accent[P.best] - 0.15
		local a = pair.pos and M.c01((t - t0) / 0.3) * (1 - M.c01((t - P.out) / 0.15)) or 0
		local cam = self.camCF
		if a > 0.01 and cam then
			local c = pair.pos + (pair.pos - cam.Position).Unit * 4
			self.rayHub.CFrame = acf * CF(c)
			for k, r in self.rays do
				local ang = (k - 1) / #self.rays * 2 * PI + RAD(8) * t
				r.tip.CFrame = acf * CF(c + (cam.RightVector * math.cos(ang) + cam.UpVector * math.sin(ang)) * r.len * M.out(a, 2))
				r.beam.Width1 = 2.6 * a
				if not r.beam.Enabled then r.beam.Enabled = true end
				if P.R.SlowMo then r.beam.Color = ColorSequence.new(WHITE, M.hsv(t, k)) end
			end
		else
			for _, r in self.rays do
				if r.beam.Enabled then r.beam.Enabled = false end
			end
		end
	end
	-- the hold layer on a sheet just behind the best pair (facing the camera), and the premium rim light behind it
	local camHold = self.camCF
	if self.backdrop and pair.pos and camHold then
		local fwd = pair.pos - camHold.Position
		fwd = V3(fwd.X, 0, fwd.Z).Unit
		self.backdrop.Parent.CFrame = acf * CF(pair.pos + fwd * (pair.depth * 0.5 + 1.2))
		if not self.backdropOn and t >= P.accent[P.best] - 0.2 then
			self.backdropOn = true
			-- (a dark pair's rarity glow reaches well past its outline, so the silhouette reads against the night)
			self.backdrop.Size = NumberSequence.new(self.backdropDark and 1.7 * math.max(pair.height, pair.width * 0.6) or (self.darkPair and 1.9 or 1.3) * pair.width * (P.multi and P.n >= 5 and 1.35 or 1))
			self:emit(self.backdrop, 1)
		end
	end
	if self.holdFx then
		local on = pair.pos ~= nil and camHold ~= nil and t >= P.accent[P.best] - 0.15 and t < P.out
		if on then
			local fwd = pair.pos - camHold.Position
			fwd = V3(fwd.X, 0, fwd.Z).Unit
			if not self.holdSized then
				self.holdSized = true
				self.holdVol.Size = V3(math.max(pair.width * (P.multi and 4 or 2.6), 9), math.max(pair.height * 3, 6), 0.6)
			end
			self.holdVol.CFrame = CFrame.lookAt(pair.pos + fwd * (pair.depth * 0.5 + 2.2), pair.pos + fwd * 10)
		end
		if self.holdFx.Enabled ~= on then
			self.holdFx.Enabled = on
			self:recount()
		end
	end
	if self.rimLight then
		local a = (pair.pos and camHold) and M.c01((t - P.accent[P.best]) / 0.2) * (1 - M.c01((t - P.out) / 0.15)) or 0
		if a > 0.01 then
			local fwd = pair.pos - camHold.Position
			fwd = V3(fwd.X, 0, fwd.Z).Unit
			self.rimHost.CFrame = CF(pair.pos + fwd * (pair.depth * 0.5 + 1.6) + V3(0, pair.height * 0.4, 0))
		end
		self.rimLight.Brightness = (self.lightPair and 0.5 or 2.4) * a
	end
	-- Legendary+: two comets orbiting the pair at 0.8 rev/s on an ellipse just BEHIND it in the camera's plane: they
	-- frame its outline, pass behind it, and stay above its soles (clear of the name and the chip below)
	local camNow = self.camCF
	for k, cm in self.orbiters do
		local a = (pair.pos and camNow) and M.c01((t - P.accent[P.best]) / 0.2) * (1 - M.c01((t - P.out) / 0.15)) or 0
		if a > 0.01 then
			local ang = (t - P.accent[P.best]) * 0.8 * 2 * PI + (k - 1) * PI
			local fwd = pair.pos - camNow.Position
			fwd = V3(fwd.X, 0, fwd.Z).Unit
			local right = fwd:Cross(V3(0, 1, 0))
			local centre = pair.pos + fwd * (pair.depth * 0.5 + 0.6)
			local rx, ry = pair.width * 0.62 + 0.3, pair.height * 0.5 + 0.25
			local function at(q) return centre + right * math.cos(q) * rx + V3(0, math.sin(q) * ry + math.cos(q) * rx * 0.18 * (k == 1 and 1 or -1), 0) end
			local head, tail = at(ang), at(ang - 0.55)
			cm.head.CFrame = CF(head)
			cm.a0.CFrame = acf * CF(head)
			cm.a1.CFrame = acf * CF(tail)
			if not cm.beam.Enabled then cm.beam.Enabled = true end
		elseif cm.beam.Enabled then
			cm.beam.Enabled = false
			cm.head.CFrame = self.park
		end
	end
	-- the halo (every Grail; a Secret's in rainbow) descends onto the pair (Quart Out 600 ms) and hovers
	if self.halo then
		local a = pair.pos and M.c01((t - P.accent[P.best]) / 0.15) * (1 - M.c01((t - P.out) / 0.15)) or 0
		local drop = 1 - M.out((t - P.accent[P.best]) / 0.6, 4)
		local at = pair.pos and CF(pair.pos + V3(0, pair.height * 0.5 + 0.35 + drop * 4, 0)) * ANG(RAD(12), 0, 0) or self.park
		self.halo:pose(at, math.min(pair.width * 0.22, pair.height * 0.4) + 0.2, a, t * 1.2)
		if a > 0.01 and self.haloRainbow then
			for k, p in self.halo.parts do p.Color = M.hsv(t, k * 0.3) end
		end
	end
end
-- The premium charge rings: materialise (Back Out), spin up (Quad In speed, integrated), precess, pulse in thickness,
-- shrink in the dark beat, release under the flash. Ring 1 shows the honest rarity tease.
-- { tilt (deg, the near side up), roll (deg), radius (x box width), revs/s at the start, at the end, wobble (deg) }
-- Rings 1 and 2 (the theme's two colours, thick) circle the lid with their near sides raised, so they cross above the
-- box's label; ring 3 (thin, white, the honest rarity tease) stands behind the box.
local RINGSPEC = { { 20, 12, 0.85, 0.8, 2.6, 6 }, { 48, -16, 1.0, -1.1, -3.0, 8 }, { 72, 0, 1.15, 0.6, 1.8, 4 } }
function Job:ringsAt(t)
	local P = self.P
	local box = self.boxes[P.best]
	local multiR = P.multi and (P.n >= 5 and 2.4 or 1.6) or 1
	local c0, c1 = P.charge[1], P.charge[2]
	local T = c1 - c0
	local centre = P.multi and self:w(V3(0, P.homes[1].Y + box.seamY * 0.8, P.n >= 5 and 1.8 or 0)) or ((box.cf or box.home) * CF(0, box.topY + 0.5, 0))
	local cam = self.camCF
	-- the rings' frame: local -Z toward the camera (so "near side up" stays near), Y up
	local toCam = cam and (cam.Position - centre.Position) or V3(0, 0, -1)
	toCam = V3(toCam.X, 0, toCam.Z)
	toCam = toCam.Magnitude > 0.1 and toCam.Unit or V3(0, 0, -1)
	local face = CFrame.lookAt(centre.Position, centre.Position + toCam)
	for k, ring in self.rings do
		local sp = RINGSPEC[k]
		local tin = P.ringsIn[k]
		local inA = M.back((t - tin) / 0.22, 1.7)
		local radius = sp[3] * P.boxW * multiR * (k == 3 and P.multi and 0.7 or 1)
		local alpha = M.c01((t - tin) / 0.08)
		local tc = math.clamp(t - c0, 0, T)
		local revs = sp[4] * tc + (sp[5] - sp[4]) * tc * tc * tc / (3 * T * T)
		if t > c1 then
			revs += (sp[5] > 0 and 3.2 or -3.2) * (math.min(t, P.flash) - c1)
			local q = M.inn((t - P.dip[1]) / (P.dip[2] - P.dip[1]), 2)
			radius *= M.lerp(1, 0.7, q)
			alpha *= M.lerp(1, 0.55, M.c01((t - P.dip[1]) / 0.15))
		end
		local width = 1
		if t >= P.flash then
			local q = M.c01((t - P.flash) / 0.25)
			radius *= M.lerp(0.7, 2.5, M.out(q, 4))
			alpha *= 1 - q
			width = M.lerp(1, 0.25, q)
		end
		if t < tin then alpha = 0 end
		local pulse = 1 + 0.25 * math.sin(t * 9 + k * 2) * (k == 2 and 1 or 0.4)
		local plane
		if k == 3 then
			-- (behind the box: its centre pushed away from the camera)
			plane = (face - toCam * radius * 0.7) * ANG(RAD(sp[1]), 0, 0) * ANG(0, 0, RAD(sp[2] + math.sin(t * 1.3) * sp[6]))
		else
			-- (the near side raised by the tilt, a slow wobble so the two never lock together)
			plane = face * ANG(RAD(sp[1] + math.sin(t * 1.7 + k) * sp[6]), 0, 0) * ANG(0, 0, RAD(sp[2]))
		end
		if P.multi then plane = centre * ANG(RAD(sp[1]), RAD(sp[2] * 3 + 40 * (t - c0) * (k == 2 and -1 or 1)), 0) end
		ring:pose(plane, radius * math.max(0.3, inA), alpha, revs * 2 * PI, width * pulse)
		if k == 3 then ring:setColor(box.teaseColor or WHITE) end
	end
	-- the build-up pillar behind the box through the charge (width 0.6 -> 2.0)
	local bp = self.buildBeam
	local on = t >= P.buildPillar and t < P.flash
	if bp.Enabled ~= on then bp.Enabled = on end
	if on then
		local u = M.c01((t - P.buildPillar) / (P.dip[1] - P.buildPillar))
		local acf = self.anchor.CFrame:Inverse()
		local base = self:w(V3(0, 0, (P.multi and 5 or 0) + 10))
		self.buildAtt[1].CFrame = acf * base
		self.buildAtt[2].CFrame = acf * base * CF(0, 70, 0)
		bp.Width0, bp.Width1 = M.lerp(0.6, 2, u), M.lerp(0.6, 2, u) * 1.2
	end
end

---------------------------------------------------------------------------------------------- skip, restore, finish
function Job:skip()
	if self.Done then return end
	local P = self.P
	if self.t < P.skipTo - 0.05 then
		self.skipTo = P.skipTo
		-- (a skip never shows a flash it jumped over)
		for _, f in P.flashes do
			if f[1] > self.t and f[1] < P.skipTo + 0.05 then f[2] = 0 end
		end
	elseif self.t < P.out then
		self.skipTo = P.out
	end
end
function Job:captureCamera()
	local cam = workspace.CurrentCamera
	if not cam then return end
	self.camSaved = { type = cam.CameraType, subject = cam.CameraSubject, cf = cam.CFrame, fov = cam.FieldOfView, focus = cam.Focus }
end
function Job:restoreCamera()
	local s = self.camSaved
	if not s or self.camRestored then return end
	self.camRestored = true
	local cam = workspace.CurrentCamera
	if not cam then return end
	cam.FieldOfView = s.fov
	local subject = s.subject
	if subject and not subject.Parent then
		local plr = Players.LocalPlayer
		subject = plr and plr.Character and plr.Character:FindFirstChildOfClass('Humanoid') or nil
	end
	pcall(function() cam.CameraSubject = subject end)
	cam.CFrame = s.cf
	pcall(function() cam.Focus = s.focus end)
	cam.CameraType = s.type
end
local function controls()
	local plr = Players.LocalPlayer
	local ps = plr and plr:FindFirstChild('PlayerScripts')
	local pm = ps and ps:FindFirstChild('PlayerModule')
	if not pm then return nil end
	local ok, mod = pcall(require, pm)
	if not ok or type(mod) ~= 'table' then return nil end
	local ok2, c = pcall(function() return mod:GetControls() end)
	return ok2 and c or nil
end
function Job:finish()
	if self.Done then return end
	self.Done = true
	if self.bound then
		pcall(function() RunService:UnbindFromRenderStep(self.bindName) end)
		self.bound = false
	end
	for _, c in self.conns do pcall(function() c:Disconnect() end) end
	table.clear(self.conns)
	self:restoreCamera()
	pcall(Look.restore, self)
	if self.controls and self.disabledControls then pcall(function() self.controls:Enable() end) end
	if self.folder then self.folder:Destroy() end
	if self.stageGui then self.stageGui:Destroy() end
	if self.ownGui and self.gui then self.gui:Destroy() end
	self.folder, self.stageGui = nil, nil
	table.clear(self.events)
	table.clear(self.updaters)
	if current == self then current = nil end
	if self.onDone then task.spawn(self.onDone, self) end
end

function UnboxCinematic.play(info, opts)
	opts = opts or {}
	if current and not current.Done then current:finish() end
	local player = Players.LocalPlayer
	local reduced = opts.reduced or reducedFor(player)
	local P = UnboxCinematic.plan(info, { tier = opts.tier, player = player, reduced = reduced })
	local job = setmetatable({
		P = P, Plan = P, t = 0, T = 0, Done = false, conns = {}, emits = {}, emitterList = {}, events = {}, updaters = {},
		cap = UnboxCinematic.Caps[P.tier] or 80, onDone = opts.onDone, contLive = 0, peak = 0, pairs = {}, boxes = {},
		shakes = {}, punches = {}, kicks = {},
	}, Job)
	current = job
	local low = (ShoeFX and type(ShoeFX.quality) == 'function' and ShoeFX.quality() == 'low') or false
	local touch = false
	pcall(function()
		local UIS = game:GetService('UserInputService')
		touch = UIS.TouchEnabled and not UIS.KeyboardEnabled
	end)
	job.vfxScale = (low and 0.6 or 1) * (touch and 0.8 or 1)
	job.O = opts.stageAt or UnboxCinematic.StageAt
	job.park = job.O * CF(0, -400, 0)
	job.away = V3(0, 0, -1)
	job.gui = opts.gui
	if not job.gui then
		local pg = player and player:FindFirstChild('PlayerGui')
		if pg then
			local g = Instance.new('ScreenGui')
			g.Name = 'HoodUnboxCinematic'
			g.ResetOnSpawn = false
			g.IgnoreGuiInset = true
			g.DisplayOrder = 9
			g.Parent = pg
			job.gui, job.ownGui = g, true
		end
	end
	job:captureCamera()
	local ok, err = pcall(function()
		job.folder = Instance.new('Folder')
		job.folder.Name = 'HoodUnboxStage'
		job.folder.Parent = workspace
		Kit.Stage.build(job)
		job.padTint = job.folder:FindFirstChild('Pad')
		job.bits = Bits.new(job.folder, job.park, Kit.Stage.floorAt(job))
		for i = 1, P.n do job.boxes[i] = Box.new(job, i) end
		for i, entry in P.list do job.pairs[i] = Pair.new(job, i, entry) end
		-- a light pair (white, yellow, pale) gets a softer hero light so its laces and panels don't clip to white
		local pb = job.pairs[P.best]
		job.lightPair = pb.albedo > UnboxCinematic.LightAlbedo or pb.brightShare > 0.3
		-- (and a dark pair (navy, black, deep purple) on a night stage gets a rarity glow behind it and a warm rim)
		job.darkPair = not job.lightPair and pb.albedo < UnboxCinematic.DarkAlbedo
		-- the theme's signatures first (some set flags the effects read), then the effects, the camera, the look
		local th = P.theme
		for _, list in { th.Arrive or {}, th.Land, th.Open, P.premium and th.Charge or {}, P.premium and th.Dip or {} } do
			for _, name in list do
				local fn = Sig[name]
				if fn then
					for i = 1, P.n do fn(job, i) end
				end
			end
		end
		Build.effects(job)
		job:lineup()
		Cam.build(job)
		-- a single's posters frame the pair in the hero shot, between it and the confetti lanes at the frame's edges
		if P.n == 1 and job.heroShot then
			local cf, fov = Cam.at(job, (P.premium and P.confetti or P.accent[P.best]) + 0.8)
			local d = (job:wp(job.heroShot[2]) - cf.Position).Magnitude
			Kit.Stage.framePosters(job, cf, fov, viewAspect(), pb.width * 0.5 / (d * math.tan(RAD(fov / 2)) * viewAspect()))
		end
		Look.save(job)
		Look.build(job)
		if job.gui then Words.build(job) end
		job:beats()
		job:fitBudget()
		table.sort(job.events, function(a, b) return a[1] < b[1] end)
		job:recount()
	end)
	if not ok then
		warn('[UnboxCinematic] could not build: ' .. tostring(err))
		job.Failed = true
		job:finish()
		return job
	end
	job.controls = controls()
	if job.controls then job.disabledControls = pcall(function() job.controls:Disable() end) end
	pcall(function()
		local UIS = game:GetService('UserInputService')
		table.insert(job.conns, UIS.InputBegan:Connect(function(input, processed)
			if processed then return end
			local kc = input.KeyCode
			if kc == Enum.KeyCode.Space or kc == Enum.KeyCode.Return or kc == Enum.KeyCode.E or kc == Enum.KeyCode.ButtonA then job:skip() end
		end))
	end)
	job:frame(0)
	if not opts.manual then
		job.bindName = 'HoodUnboxCinematic'
		RunService:BindToRenderStep(job.bindName, Enum.RenderPriority.Camera.Value + 1, function(dt) job:step(dt) end)
		job.bound = true
		task.delay(P.total + 3, function() if not job.Done then job:finish() end end)
	end
	return job
end

UnboxCinematic._Job, UnboxCinematic._M = Job, M
return UnboxCinematic
