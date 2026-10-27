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
local Fonts = optional('Fonts')
-- (brief 28: STAGE28's game-style sets, a drop-in for Kit.Stage; the old rooftop is the fallback)
local Stage = optional('UnboxStage') or Kit.Stage
-- (brief 28c: the normal openings in the world, where the player stands)
local World = optional('UnboxWorld')

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
UnboxCinematic.Caps = { egg = 80, gift = 80, crazy = 300, secret = 300, normal = 80, premium = 300 }
UnboxCinematic.MaxSeconds = 10 -- (one segment; a Secret's whole chain stays within 11 s, a batch's adds its summary)
UnboxCinematic.FlashMax = 0.25
UnboxCinematic.G = 1.33 -- the stage's scale over ANIMLAB's studs (our boxes are built at ~1.6)
UnboxCinematic.BitCaps = { slam = 36, pop = 36, confetti = 70, reveal = 30 }
UnboxCinematic.HeroYaw = { normal = math.rad(15), premium = math.rad(-20) } -- (a 3/4 from the left; a low 3/4 from the right)
UnboxCinematic.Gather = 0.74
-- How the Secret's carousel shows its five candidates (one switch): 'silhouette' (black, outlined), 'colour' (lit) or
-- 'mystery' (black, outlined, a "?" over each). The true pair's tease face and reveal are lit whatever it is.
UnboxCinematic.CarouselLook = 'silhouette'
-- (brief 28c) Normal openings (Common to Mythic, singles, the gift, Buy 3 / Buy 8) and a Secret's prelude play in the
-- player's own view (UnboxWorld); off: on the egg stage (brief 28b)
UnboxCinematic.InWorld = true
-- (the user, after brief 28: a box always looks like itself, whatever it holds: no rainbow version for a Legendary or a
-- Mythic; they escalate after the pop. On: brief 28's rainbow boxes (Box.rainbowSetup))
UnboxCinematic.RainbowBoxes = false
-- (the user, on the in-world preview: no "+N% Power" reel or chip at the reveal, at any rarity, in a Secret or a batch)
UnboxCinematic.ShowPower = false
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
-- 'secret' when any pair of the opening is a Secret (from any box), 'gift' for the onboarding welcome gift, else 'egg'
-- (Cash and Robux boxes alike).
function UnboxCinematic.tierFor(info, player)
	player = player or Players.LocalPlayer
	for _, e in (UnboxCinematic.entries(info)) do
		if rankOf(e.Shoe) >= 6 then return 'secret' end
	end
	if UnboxCinematic.isGift(info, player) then return 'gift' end
	return 'egg'
end
-- The drop chance (percent) of a shoe from its box, and its text ("3%", "0.45%").
local function chanceOf(boxId, shoeId)
	local box = boxDef(boxId)
	if box and box.Shoes and box.Chances then
		for i, id in box.Shoes do
			if id == shoeId then return box.Chances[i] end
		end
	end
	local s = shoeDef(shoeId)
	local row = s and rarityRow(s.Rank)
	return row and row.Chance or nil
end
local function chanceText(c)
	if not c then return nil end
	if c >= 10 or math.abs(c - math.floor(c + 0.5)) < 1e-6 then return string.format('%d%%', math.floor(c + 0.5)) end
	local str = string.format(c >= 1 and '%.1f' or '%.2f', c):gsub('0+$', ''):gsub('%.$', '')
	return str .. '%'
end
-- "1 in 33" (the hatch games' way to say a chance)
local function oneIn(c)
	if not c or c <= 0 then return nil end
	local n = math.max(1, math.floor(100 / c + 0.5))
	local str = tostring(n):reverse():gsub('(%d%d%d)', '%1,'):reverse():gsub('^,', '')
	return '1 in ' .. str
end
UnboxCinematic.chanceOf, UnboxCinematic.chanceText, UnboxCinematic.oneIn = chanceOf, chanceText, oneIn

---------------------------------------------------------------------------------------------- the plan (pure)
local EXTRA_E = { 0, 0.1, 0.25, 0.45, 0.7, 0.7 } -- the egg's read hold past 3.4 s, by rank (a single)
local EXTRA_P = { 0, 0, 0.3, 0.7, 1.1, 1.4 } -- the crazy sheet's past 8.2 s
local G = UnboxCinematic.G
local LEGACY = { normal = 'egg', premium = 'crazy' }

-- Layouts (stage space; y = the surface the box stands on): homes, box scale, pad radius, the Buy 8's riser.
-- The Secret's carousel (28b): five real candidates from the box's odds row, the true pair among them (the result is
-- decided before the opening starts; the carousel only presents it): the true one and the four rarest others, in rank
-- order round the ring. Returns the ids and the true one's slot.
function UnboxCinematic.candidates(boxId, trueId)
	local b = boxDef(boxId)
	local row = b and b.Shoes or {}
	local others = {}
	for _, id in row do
		if id ~= trueId then table.insert(others, id) end
	end
	table.sort(others, function(x, y) return rankOf(x) > rankOf(y) end)
	local pick = { trueId }
	for k = 1, math.min(4, #others) do table.insert(pick, others[k]) end
	table.sort(pick, function(x, y) if rankOf(x) ~= rankOf(y) then return rankOf(x) < rankOf(y) end return x < y end)
	local slot = 1
	for k, id in pick do
		if id == trueId then slot = k end
	end
	return pick, slot
end
local function layout(P)
	local n = P.n
	if n == 1 then
		P.boxScale = (P.premium and not P.secretCut) and 1.75 or 1.6
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

-- The plan of one opening. Tiers: 'egg' (every non-Secret opening, Cash and Robux boxes alike), 'gift' (the egg flow
-- with the welcome gift's two pairs), 'secret' (a chain: the egg prelude, the cut, the crazy sheet, a batch's summary)
-- and 'crazy' (the crazy sheet alone, brief 27's premium; the Secret chain's middle). opts: tier, player, reduced, and
-- for the chain's segments prelude / summary / secretCut / batch.
function UnboxCinematic.plan(info, opts)
	opts = opts or {}
	local tier = opts.tier or UnboxCinematic.tierFor(info, opts.player)
	tier = LEGACY[tier] or tier
	if tier == 'secret' then return UnboxCinematic._secret(info, opts) end
	local list, best = UnboxCinematic.entries(info)
	local n = #list
	local P = { tier = tier, n = n, best = best, list = list, box = info.Box, theme = Themes.get(info.Box), G = G }
	P.premium, P.gift, P.multi = tier == 'crazy', tier == 'gift', n > 1
	P.egg = not P.premium
	P.reduced = opts.reduced == true
	P.prelude, P.summary, P.secretCut, P.batch = opts.prelude == true, opts.summary == true, opts.secretCut == true, opts.batch == true
	P.inworld = UnboxCinematic.InWorld and World ~= nil and P.egg and not P.summary
	P.k = Themes.strength(info.Box, P.premium and 'premium' or 'normal')
	P.themeTier = Themes.tierOf(info.Box)
	P.deluxe = nil -- (brief 28: every egg is in the game's daylight; the crazy sheet has its own night)
	P.ranks = {}
	for i, e in list do P.ranks[i] = rankOf(e.Shoe) end
	P.rank = P.ranks[best]
	local rr = P.gift and math.min(P.rank, 4) or P.rank -- (the gift's extras stop at the Legendary row)
	P.R = Themes.Rarity[rr] or Themes.Rarity[1]
	if P.egg and (P.R.SlowMo or P.R.Flash2) then
		-- (an egg never slows down or flashes white: a Secret's big moments belong to the crazy sheet)
		P.R = table.clone(P.R)
		P.R.SlowMo, P.R.Flash2 = false, false
	end
	-- the rainbow boxes: a Legendary's box is the rainbow version of that box, a Mythic's the stronger one, from the
	-- drop (the truth: a Secret's box stays plain, and the cut is its surprise)
	P.rainbow = {}
	for i, r in P.ranks do P.rainbow[i] = (UnboxCinematic.RainbowBoxes and P.egg and r == 4) and 1 or (UnboxCinematic.RainbowBoxes and P.egg and r == 5) and 2 or 0 end
	-- the opens in ascending rarity, ties left to right, the best last (it changes no outcome)
	local order = {}
	for i = 1, n do
		if i ~= best then table.insert(order, i) end
	end
	table.sort(order, function(a, b) if P.ranks[a] ~= P.ranks[b] then return P.ranks[a] < P.ranks[b] end return a < b end)
	table.insert(order, best)
	P.order = order
	if P.inworld then World.layout(P) else layout(P) end
	P.appear, P.fall0, P.land, P.hs, P.pop, P.crouch, P.rise, P.accent, P.trauma, P.wobOff = {}, {}, {}, {}, {}, {}, {}, {}, {}, {}
	if P.premium then UnboxCinematic._premium(P) elseif P.inworld then World.plan(P) else UnboxCinematic._egg(P) end
	if P.inworld then
		-- (in the world: the hold waits for a tap; the close flies the pair into the inventory button)
		P.done = P.out + P.closeLen
	else
		P.done = P.out + (P.gift and 0.2 or 0.35)
		if P.done > UnboxCinematic.MaxSeconds - 0.05 then
			P.out = UnboxCinematic.MaxSeconds - 0.4
			P.done = P.out + 0.35
		end
	end
	P.start = P.start or 0
	P.total = P.done - P.start
	P.skipTo = (P.multi and not P.fan and not P.inworld) and P.group or P.accent[best]
	P.chance = chanceOf(info.Box, list[best].Shoe)
	return P
end

-- THE EGG (REF28's copy spec §9: the crate's craft restyled to the hit games' hatch): the camera pushes in (0.17 s), the
-- box's shadow grows on the pad, the box appears at 0.30 and falls in 0.15 s (lands 0.48: squash, a 50 ms hit-stop, an
-- exposure pulse, dust, a ground ring, chunks that rest on the pad), three escalating left-right shakes (0.75 / 1.15 /
-- 1.52), an anticipation dip (1.80-2.05), the pop (2.10: a soft flash, a burst; the pair scales 0 -> 1.15 -> 1 in
-- 0.28 s) with the card (rarity, chance, name) entering under it, the Power reel 0.4 s later; auto-continue 3.4 s + the
-- rarity's hold. A Buy 3 / Buy 8 is an egg row: drops 100 / 70 ms apart, the shakes together, the pops in rising
-- rarity (the best last). Tuning: UnboxThemes.Egg.
function UnboxCinematic._egg(P)
	local n, best = P.n, P.best
	local E = Themes.Egg
	P.cut, P.clear = 0, 0.12
	P.fallH = 8 -- (the box shows at the top of the frame, then drops)
	P.fall = 0.16
	-- (28b: the box hangs glinting in the sky ~0.25 s, then drops fast; a row's boxes land in a staggered arc)
	local gap = n >= 5 and 0.07 or 0.1
	for i = 1, n do
		P.appear[i] = 0.05 + (i - 1) * gap
		P.fall0[i] = P.appear[i] + (E.Glint or 0.25)
		P.land[i] = P.fall0[i] + P.fall
		P.hs[i] = P.reduced and 0 or 0.05
		P.trauma[i] = n == 1 and 0.4 or n == 2 and 0.35 or n <= 4 and ({ 0.3, 0.35, 0.45 })[math.min(i, 3)] or 0.12
		P.wobOff[i] = n <= 4 and (i - 1) * 0.04 or ((i - 1) % 4) * 0.03
	end
	-- the shakes: { time (s), roll (deg), hop (studs), length (s) }: quick left-right rocks on the box's bottom edges
	-- (L-R-L), each bigger, the rests shrinking
	local s0 = n == 1 and E.First or P.land[n] + 0.27
	P.wobSpec = {}
	local tw = s0
	for k, sh in E.Shakes do
		table.insert(P.wobSpec, { tw, sh[1], sh[2], sh[3] })
		tw += sh[3] + (E.Pauses[k] or 0)
	end
	if P.prelude then
		-- a Secret's prelude (copy_spec §9.1 "The Secret CUT"): two plain shakes; the cue: shake 2 freezes at its peak
		-- (120 ms), two wrong-way vertical hops, a thin line of the theme's light at the seam (no rarity hint); the cut at
		-- 1.65: the light falls to the deep-blue sky in 4-5 frames while the camera tilts up 24 deg (0.17 s) and the box
		-- lifts off (6 studs in 0.25 s, Quad In) into a tear opening in the sky (1.80), gone by 2.10; the crazy sheet takes
		-- over at 2.20 (the chain)
		local p0 = n == 1 and E.First or P.land[n] + 0.27
		P.wobSpec = { { p0, 7, 0.1, 0.18 }, { p0 + 0.4, 11, 0.15, 0.2 } }
		P.freeze = { p0 + 0.52, p0 + 0.64 }
		P.hops = { p0 + 0.67, p0 + 0.79 }
		P.cue = P.freeze[1]
		P.cutAt = p0 + 0.9
		P.lift = P.cutAt
		P.tear = P.cutAt + 0.15
		P.stop = P.cutAt + 0.55
	end
	local shakesEnd = P.wobSpec[#P.wobSpec][1] + P.wobSpec[#P.wobSpec][4]
	-- the anticipation dip and the pops: a single at 2.10; the gift's lower pair first; a Buy 3 ascending 0.25 s apart;
	-- a Buy 8 the lowest first, then a ripple 70 ms apart, the best last
	local p0 = P.prelude and P.stop + 5 or math.max(shakesEnd + 0.35, n == 1 and 2.1 or 0)
	P.eggDip = (not P.prelude) and { shakesEnd + 0.05, p0 - 0.05 } or nil
	for j, i in P.order do
		if n == 1 then P.pop[i] = p0
		elseif n == 2 then P.pop[i] = p0 + (j == 1 and 0 or 0.15)
		elseif n <= 4 then P.pop[i] = p0 + (j - 1) * 0.25
		else P.pop[i] = j == 1 and p0 or p0 + 0.3 + (j - 2) * 0.07 end
		P.crouch[i] = P.eggDip and P.eggDip[1] or P.pop[i] - 0.25
		P.rise[i] = P.pop[i] + 0.02
	end
	P.riseLen = n == 1 and 0.35 or n >= 5 and 0.5 or 0.4
	P.riseH = (n == 1 and 3.0 or n >= 5 and 2.2 or 2.6) * G
	-- (28b: the pair shoots up spinning fast and slows to face the camera)
	P.spinLen, P.spinTurns = n == 1 and 0.6 or 0.65, n == 1 and 1.25 or 1
	-- the card enters under the pop; the name is readable 0.15 s later; the Power reel 0.4 s after the pop
	local lastPop = P.pop[best]
	-- (28b: a Legendary's or Mythic's single adds the reference's beats 13-15, short: the pair rises in silhouette, a
	-- dusk dip, rings scale in round it while it spins 1.5 turns, the rarity flash, the reveal)
	local LX = (n == 1 and not P.prelude and not P.summary and P.rank >= 4 and P.rank <= 5) and E.Lux and E.Lux[P.rank - 3]
	if LX then
		local d0 = lastPop + 0.38
		P.lux = { level = P.rank - 3, dusk = { d0, d0 + LX.dusk }, spin = { d0 + LX.dusk, d0 + LX.dusk + LX.spin }, turns = LX.turns, rings = LX.rings, size = LX.size }
		P.reveal = P.lux.spin[2]
		P.accent[best] = P.reveal
		P.banner = P.reveal + 0.02
	elseif n == 1 then
		P.accent[best] = lastPop + 0.3
		P.banner = lastPop + 0.02
	else
		P.accent[best] = lastPop + (n == 2 and 0.35 or 0.3)
		P.group = P.accent[best] - 0.25
		for j, i in P.order do
			if i ~= best then P.accent[i] = P.pop[i] + 0.3 end
		end
		P.banner = lastPop + 0.02
	end
	-- 28b, a Buy 3 / Buy 8: the pairs fly up into a loop (the fan) that revolves and slows, settle into the line-up,
	-- then flip to their reveals in rising rarity, 0.25 / 0.22 s apart, the best last (a Legendary or better: it comes
	-- forward with a short 1.5-turn spin)
	if n >= 3 and not P.prelude and not P.summary then
		P.fan = { lastPop + 0.35, lastPop + 0.35 + (n >= 5 and 1.1 or 0.9) }
		local step = n >= 5 and 0.22 or 0.25
		P.flipAt = {}
		for j, i in P.order do
			P.flipAt[i] = P.fan[2] + 0.3 + (j - 1) * step
			P.accent[i] = P.flipAt[i] + 0.12
		end
		if P.rank >= 4 then
			P.bestSpin = { P.flipAt[best], P.flipAt[best] + 0.45 }
			P.accent[best] = P.bestSpin[2]
		end
		P.group = P.fan[2] - 0.2
		P.banner = P.accent[best] + 0.02
	end
	local rv = P.reveal or (P.fan and P.accent[best]) or lastPop
	P.newT, P.nameT = P.banner + 0.1, rv + 0.15
	-- (28b: the Power reel ticks for 0.8 s)
	P.count = { rv + 0.4, rv + 1.2 }
	P.tap = rv + 0.9
	local a = P.accent[best]
	if P.gift or n == 2 then P.out = a + 1.4
	elseif P.lux then P.out = P.reveal + 2.0
	elseif P.fan then P.out = a + (n >= 5 and 1.4 or 1.3)
	elseif n == 1 then P.out = 3.4 + EXTRA_E[P.rank] + 0.4
	elseif n <= 4 then P.out = a + 1.6 + EXTRA_E[P.rank] / 2
	else P.out = a + 1.9 + EXTRA_E[P.rank] / 2 end
	if P.summary then
		-- a Secret batch's summary: it starts as the line-up forms and holds it 1.2 s
		P.start = P.group - 0.15
		P.out = a + 1.2
	end
	-- the pop's soft flash (2 frames held, a 150 ms tail; never white-out); none in a summary
	P.flashes, P.soft = {}, {}
	local rbBest = P.rainbow[best] > 0
	if not P.reduced and not P.summary then table.insert(P.soft, { lastPop, E.Flash[rbBest and 2 or 1], 0.2 }) end
	-- (a Legendary's or Mythic's rarity flash at its reveal, >= 1 s after the pop: 2 white frames; Reduced Motion: a faint
	-- wash in the rarity colour)
	if P.lux then
		if P.reduced then table.insert(P.soft, { P.reveal, 0.12, 0.3 }) else table.insert(P.flashes, { P.reveal, 0.9, 0.2, 0.06 }) end
	end
	P.firstPop = P.pop[P.order[1]]
	P.lastLand = P.land[n]
end

-- THE SECRET (from any box): a chain of plans played one after another (UnboxCinematic.play's Chain), each segment its
-- own job (its own set, camera, look and restore): the egg prelude (the drop, a shake, a violent one; <= 2 s), a hard
-- cut to black (no flash), the crazy sheet for the Secret pair (brief 27's premium with the box's theme), and for a
-- batch the summary of every pair. Times on the chain's clock: segment k runs its plan from t0 to t1, starting at `at`.
UnboxCinematic.CutBlack = 0 -- (no black at the seam: the prelude darkens and tilts up into the tear; copy_spec §9.1)
function UnboxCinematic._secret(info, opts)
	local list, best = UnboxCinematic.entries(info)
	local si = best
	if rankOf(list[si].Shoe) < 6 then
		for i, e in list do
			if rankOf(e.Shoe) >= 6 then si = i; break end
		end
	end
	local multi = #list > 1
	local function o(extra)
		local t = { player = opts.player, reduced = opts.reduced }
		for k, v in extra do t[k] = v end
		return t
	end
	local pre = UnboxCinematic.plan(info, o({ tier = 'egg', prelude = true }))
	pre.secretAt = si
	local e = list[si]
	local one = { Box = info.Box, Shoe = e.Shoe, Rarity = e.Rarity, New = e.New, Count = e.Count, Equipped = e.Equipped, Better = e.Better }
	local crazy = UnboxCinematic.plan(one, o({ tier = 'crazy', secretCut = true, batch = multi }))
	local sum = multi and UnboxCinematic.plan(info, o({ tier = 'egg', summary = true })) or nil
	local segs = {}
	local at = 0
	local function add(kind, plan, t0, t1, gap)
		at += gap or 0
		table.insert(segs, { kind = kind, plan = plan, t0 = t0, t1 = t1, at = at })
		at += t1 - t0
	end
	add('prelude', pre, 0, pre.stop)
	add('crazy', crazy, crazy.start, crazy.done)
	if sum then add('summary', sum, sum.start, sum.done) end
	local P = { tier = 'secret', secret = true, n = #list, best = best, secretAt = si, list = list, box = info.Box, theme = Themes.get(info.Box), G = G }
	P.multi, P.reduced, P.segments = multi, opts.reduced == true, segs
	P.ranks = {}
	for i, x in list do P.ranks[i] = rankOf(x.Shoe) end
	P.rank = P.ranks[best]
	P.R = Themes.Rarity[P.rank] or Themes.Rarity[6]
	local cz = segs[2]
	local function onChain(seg, t) return seg.at + (t - seg.t0) end
	P.cutAt = pre.cutAt
	P.land, P.appear = pre.land, pre.appear
	P.firstPop = onChain(cz, crazy.firstPop)
	P.accent = { [best] = onChain(cz, crazy.accent[1]) }
	P.flash = onChain(cz, crazy.flash)
	P.flashes, P.soft = {}, {}
	for _, f in crazy.flashes do table.insert(P.flashes, { onChain(cz, f[1]), f[2], f[3], f[4] }) end
	for _, f in crazy.soft do table.insert(P.soft, { onChain(cz, f[1]), f[2], f[3] }) end
	local last = segs[#segs]
	P.out = onChain(last, last.plan.out)
	P.group = sum and onChain(last, sum.group) or nil
	P.done, P.total = at, at
	P.skipTo = P.accent[best]
	P.chance = chanceOf(info.Box, list[best].Shoe)
	return P
end

function UnboxCinematic._premium(P)
	local n, best = P.n, P.best
	P.cut, P.clear = 0, 0
	P.fallH = 34 * G
	P.fall = 0.45
	-- the comet comes in from high up, behind and to the left (in the low wide shot's frame), straight down onto the pad
	P.cometFrom = V3(-24 * G, 30 * G, 14 * G)
	local C = Themes.Crazy
	P.telegraph = table.clone(C.Telegraph)
	if n == 1 then
		P.appear[1], P.fall0[1], P.land[1] = C.Appear, C.Fall0, C.Land
		P.fall = C.Land - C.Fall0
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
		P.charge, P.ringsIn = table.clone(C.Charge), table.clone(C.RingsIn)
		P.wobSpec = {}
		for k, w in C.Wobbles do P.wobSpec[k] = table.clone(w) end
	elseif n <= 4 then
		P.charge, P.ringsIn = { 2.0, 3.7 }, { 2.0, 2.15, 2.3 }
		P.wobSpec = { { 2.15, 5, 0.2 }, { 2.6, 8, 0.35 }, { 2.98, 11, 0.5 }, { 3.27, 14, 0.65 }, { 3.48, 17, 0.8 } }
	else
		P.charge, P.ringsIn = { 2.1, 3.5 }, { 2.1, 2.25, 2.4 }
		P.wobSpec = { { 2.3, 6, 0.25 }, { 2.75, 10, 0.4 }, { 3.11, 13, 0.55 }, { 3.39, 16, 0.7 } }
	end
	P.motes = P.charge[1] + 0.3
	P.buildPillar = P.charge[1] + (P.secretCut and 0.13 or 0.5)
	P.dip = { P.charge[2], P.charge[2] + (n == 1 and C.Dip or 0.35) }
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
		local C = Themes.Crazy
		P.accent[best] = P.flash + C.Accent
		if P.R.SlowMo and not P.secretCut then P.slowmo = { P.flash + C.SlowMo[1], P.flash + C.SlowMo[2] }; P.accent[best] = P.flash + C.SlowAccent end
		if P.secretCut then
			-- the reference's second act: the dusk dip, the rings closing in round the spinning pair, the reveal flash
			P.dusk = { P.accent[best] - C.Dusk, P.accent[best] - C.Rings2 }
			-- 28b (copy_spec §1 beats 9-12): the whip (the pair launches past the lens, a speck in the blue, flies back),
			-- the carousel of five real candidates from this box's odds row (the true pair among them), the pick (the
			-- others fly out), the edge-on tease (its face for 3 frames)
			local fl = P.flash
			P.whip = { fl + C.Whip[1], fl + C.Whip[2] }
			P.carousel = { fl + C.Carousel[1], fl + C.Carousel[2] }
			P.pick = { fl + C.Pick[1], fl + C.Pick[2] }
			P.tease = { fl + C.Tease[1], fl + C.Tease[2] }
			P.rise[best] = P.whip[1]
			local ids, slot = UnboxCinematic.candidates(P.box, P.list[best].Shoe)
			P.carouselIds, P.carouselTrue = ids, slot
			P.rings2 = { P.accent[best] - C.Rings2, P.accent[best] }
		end
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
	if P.secretCut then
		-- the Secret chain's middle: it takes over at its telegraph beat (0.30: the prelude did the darkening and the tilt)
		-- with three flashes like the reference's (the slam, the end of the charge, the reveal), the words under the
		-- reveal's white, the Power reel 0.4 s after it; it holds the read 2.7 s (a batch's 1.6 s: its summary follows)
		P.start = 0.3
		P.banner = a + 0.02
		P.newT, P.nameT = P.banner + 0.1, a + 0.15
		P.count = { a + 0.4, a + 1.2 }
		P.tap = a + 0.8
		P.out = a + (P.batch and 1.6 or Themes.Crazy.Hold)
		P.flashes, P.soft = {}, {}
		if P.reduced then
			-- (Reduced Motion: a faint wash in the rarity colour, not a white flash)
			table.insert(P.soft, { P.land[1], 0.12, 0.3 })
			table.insert(P.soft, { P.flash, 0.12, 0.3 })
			table.insert(P.soft, { a, 0.12, 0.3 })
		else
			table.insert(P.flashes, { P.land[1], 0.9, 0.23 })
			-- (flash 2 opens onto the bright middle, so its tail is shorter: 2 frames at the top, then down at once)
			table.insert(P.flashes, { P.flash, 0.9, 0.13, 0.05 })
			table.insert(P.flashes, { a, 0.95, 0.25 })
		end
	end
	if not P.secretCut then
		P.flashes, P.soft = {}, {}
		if not P.reduced then
			table.insert(P.flashes, { P.flash, 0.9, 0.22 })
			if P.R.Flash2 then table.insert(P.flashes, { math.max(a, P.flash + 1.05), 0.75, 0.2 }) end
		else
			table.insert(P.soft, { P.flash, 0.22, 0.3 })
		end
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
	-- (in the world: the seal tape across the lid's seam, torn a little more at each shake)
	local sealPieces = P.inworld and World.seal(job, model, home, s) or nil
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
	self.W, self.D = size.W * s, size.D * s
	local level = P.rainbow and P.rainbow[i] or 0
	if level > 0 then
		Box.rainbowSetup(self, level)
		local RB = Themes.Egg.Rainbow[level] or {}
		local top = (size.Top or 3.08) * s
		if RB.stars or RB.aura then
			-- a Mythic's extras ride with the box on an invisible volume hugging it: larger star sparkles in the Mythic
			-- colour twinkling on its faces (each 4-6 frames, 1-2 at once; the Rare+ glints are small and white) and a
			-- soft halo behind it, reaching past its edges
			local mcol = rarityColor(5)
			local vol = Make.part(model, 'RainbowAura', V3(self.W * 1.05, top * 1.02, self.D * 1.05), home * CF(0, top * 0.51, 0), WHITE, nil, { Transparency = 1 })
			table.insert(body, vol)
			if RB.stars then
				self.stars = job:emitter('RainbowStars', 'spark', seqOf({ mcol:Lerp(WHITE, 0.35), mcol }), {
					life = { 0.13, 0.2 }, speed = { 0, 0.2 }, spread = Vector2.new(180, 180), rate = RB.stars, emission = 1, brightness = 2,
					size = nseq({ { 0, 0 }, { 0.35, 0.42 * self.W, 0.1 }, { 1, 0 } }), transparency = nseq({ { 0, 0 }, { 1, 0.4 } }), rotSpeed = NR(-90, 90), zoffset = 1,
					shape = Enum.ParticleEmitterShape.Box,
				}, vol)
			end
			if RB.aura then
				self.aura = job:emitter('RainbowHalo', 'glow', seqOf({ mcol:Lerp(WHITE, 0.25), mcol }), {
					life = { 1.1, 1.1 }, speed = { 0, 0 }, rate = 2, rotSpeed = NR(0), rotation = NR(0), emission = 1, lightInfluence = 0,
					size = NumberSequence.new(self.W * (1 + 2 * RB.aura) * 1.15), transparency = nseq({ { 0, 1 }, { 0.3, 0.45 }, { 0.7, 0.45 }, { 1, 1 } }), zoffset = -3,
				}, vol)
				self.aura.LockedToPart = true
			end
		end
		if RB.ring then
			-- (and a ring of light round it, in the Mythic colour, tilted and turning)
			self.mring = Ring.new(job.anchor, 'MythicRing' .. i, rarityColor(5), 0.06 * self.W, 0.2 * self.W, true)
			self.mring:setColor(rarityColor(5), true)
		end
	end
	self.body = Actor.new(body, home)
	self.hingeRel = hinge and home:ToObjectSpace(hinge.CFrame) or CF(0, 2.1 * s, 1.7 * s)
	self.lid = Actor.new(lidParts, hinge and hinge.CFrame or home * self.hingeRel)
	if sealPieces then World.sealRig(self, sealPieces, home, hinge and hinge.CFrame or home * self.hingeRel) end
	self.seamY = size.Body * s
	self.topY = (size.Top or 3.08) * s
	local _, bmax = bounds(model:GetDescendants(), home)
	self.fullH = math.max(self.topY, bmax.Y)
	-- the light leaking from the seam as it charges: a glowing slab under the lid
	self.seam = Make.part(job.folder, 'Seam', V3(self.W * 0.98, 0.16 * s, self.D * 0.98), job.park, WHITE, Enum.Material.Neon, { Transparency = 1 })
	-- the contact shadow (it grows on the pad while the box falls)
	self.shadow = Make.disc(job.folder, 'Shadow', 0.04, 1, job.park, C3(10, 10, 16), Enum.Material.SmoothPlastic, { Transparency = 1 })
	model.Parent = job.folder
	return self
end
-- The rainbow version of a box: the same model, shape and label with a living rainbow sweeping over it. The hue runs
-- round the box (the front from right to left, then the sides) and climbs with height, so the bands slant (a 30 deg
-- diagonal), and scrolls (Legendary 0.35 turns a second, Mythic 0.7); one turn spans ~0.85 box widths, so the front's
-- flat face alone shows ~280 deg. The big faces (the tub, its band, the lid's rim and body) are one gradient each (a SurfaceGui,
-- lit like the face, its colours rebuilt every frame), so the colour is continuous across them; the round corners and
-- the small pieces take the hue at their place. Each keeps its own value, so the 2-3 tones of every face still read.
-- The plate and the foot keep their colours, so the box's name reads. A Mythic's rim and band glow (Neon, pulsing).
local KEEP_COLOUR = { Plate = true, PlateFrame = true, Inside = true, LidInside = true, Root = true, Hinge = true, RainbowAura = true, Foot = true, Emblem = true, RainbowBand = true, Seal = true }
local GLOW_TRIM = { LidRim = true, BodyBand = true }
local FACE_LAYERS = { Body = true, BodyBand = true, LidRim = true, LidBody = true, LidCap = true }
local RB_KEYS = 8
-- the place on the box's perimeter (design studs, from the front's right edge going left, then round), x/z design
local function perimeter(x, z, W, D)
	if math.abs(x) / W >= math.abs(z) / D then
		if x < 0 then return W + math.clamp(z + D / 2, 0, D) end
		return 2 * W + D + math.clamp(D / 2 - z, 0, D)
	end
	if z < 0 then return math.clamp(W / 2 - x, 0, W) end
	return W + D + math.clamp(x + W / 2, 0, W)
end
function Box.rainbowSetup(self, level)
	local R = Themes.Egg.Rainbow[level] or Themes.Egg.Rainbow[1]
	local W, D = self.W / self.s, self.D / self.s
	self.rb = { level = level, parts = {}, faces = {}, W = W, D = D, L = W * (R.cycle or 0.85) }
	for _, d in self.model:GetDescendants() do
		if d:IsA('BasePart') and d.Transparency < 0.9 and not KEEP_COLOUR[d.Name] and not d:FindFirstChildOfClass('SurfaceGui') then
			local _, _, v = d.Color:ToHSV()
			local lp = self.home:PointToObjectSpace(d.CFrame.Position) / self.s
			local glow = R.glow and GLOW_TRIM[d.Name]
			table.insert(self.rb.parts, { d, perimeter(lp.X, lp.Z, W, D), lp.Y, math.max(0.62, v), glow })
			if glow then d.Material = Enum.Material.Neon end
			-- (a layer's two crossing blocks: the deeper one carries the front, the wider one the sides)
			if FACE_LAYERS[d.Name] and d:IsA('Part') and d.Shape == Enum.PartType.Block then
				local sz = d.Size / self.s
				local front = sz.Z / D >= sz.X / W
				for _, face in (front and { Enum.NormalId.Front } or { Enum.NormalId.Left, Enum.NormalId.Right }) do
					local s0, w
					if face == Enum.NormalId.Front then s0, w = W / 2 - (lp.X + sz.X / 2), sz.X
					elseif face == Enum.NormalId.Left then s0, w = W + (lp.Z - sz.Z / 2 + D / 2), sz.Z
					else s0, w = 2 * W + D + (D / 2 - (lp.Z + sz.Z / 2)), sz.Z end
					local g = Instance.new('SurfaceGui')
					g.Name = 'RainbowFace'
					g.Face = face
					g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
					g.PixelsPerStud = 12
					g.LightInfluence = 1
					local f = Instance.new('Frame')
					f.Size = UDim2.fromScale(1, 1)
					f.BorderSizePixel = 0
					f.BackgroundColor3 = WHITE
					f.Parent = g
					local grad = Instance.new('UIGradient')
					grad.Parent = f
					g.Parent = d
					table.insert(self.rb.faces, { grad, s0, w, lp.Y, math.max(0.62, v), glow })
				end
			end
		end
	end
end
function Box.rainbow(self, t)
	local rb = self.rb
	local R = Themes.Egg.Rainbow[rb.level] or Themes.Egg.Rainbow[1]
	local speed, sat, L = R.sweep, R.sat, rb.L
	local pulse = 0.75 + 0.25 * math.sin(t * 2 * PI * (R.pulse or 0))
	local base = t * speed
	-- hue = frac(t * speed - (0.866 * s + 0.5 * y) / L): the CRITIC5 diagonal sweep
	local function hue(sp, y) return (base - (0.866 * sp + 0.5 * y) / L) % 1 end
	for _, e in rb.parts do
		local c = Color3.fromHSV(hue(e[2], e[3]), sat, e[5] and pulse or e[4])
		if e[1].Color ~= c then e[1].Color = c end
	end
	for _, f in rb.faces do
		local keys = table.create(RB_KEYS)
		for k = 0, RB_KEYS - 1 do
			local u = k / (RB_KEYS - 1)
			keys[k + 1] = ColorSequenceKeypoint.new(u, Color3.fromHSV(hue(f[2] + u * f[3], f[4]), sat, f[6] and pulse or f[5]))
		end
		f[1].Color = ColorSequence.new(keys)
	end
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
		-- (in the world the pair floats: no pool of light, shafts or ring on a floor under it)
		if P.inworld then
			for _, d in model:GetDescendants() do
				if d:IsA('ParticleEmitter') and (d.Name == 'Ground' or d.Name == 'Shafts' or d.Name == 'Ring') then d:Destroy() end
			end
		end
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
-- Ours: a ColorCorrection, a Bloom, a Blur and a DepthOfField under the camera (they compose with the place's and are
-- just destroyed).
-- Edited after a snapshot and restored exactly: Lighting (incl. ClockTime), the Atmosphere, the Sky's stars, SunRays.
local LIGHT_PROPS = { 'ClockTime', 'Brightness', 'Ambient', 'OutdoorAmbient', 'ColorShift_Top', 'EnvironmentDiffuseScale', 'EnvironmentSpecularScale', 'ExposureCompensation', 'GeographicLatitude' }
local ATM_PROPS = { 'Density', 'Offset', 'Color', 'Decay', 'Haze', 'Glare' }
UnboxCinematic.LightProps, UnboxCinematic.AtmProps = LIGHT_PROPS, ATM_PROPS
local Look = {}
function Look.save(job)
	local from = job.inherit
	if from and from.saved then
		-- (a chain's later segment: the world is what the first segment saved, not what it has done to it since; the
		-- Atmosphere the first one made (if the place had none) is handed on, not destroyed)
		local o = from.saved
		local s = { light = table.clone(o.light), atm = o.atm and { inst = o.atm.inst, v = table.clone(o.atm.v) }, sky = o.sky and table.clone(o.sky), rays = o.rays and table.clone(o.rays), clouds = o.clouds and table.clone(o.clouds), blooms = {} }
		for _, b in o.blooms or {} do table.insert(s.blooms, table.clone(b)) end
		job.saved = s
		job.ownAtm = from.ownAtm
	else
		Look.saveWorld(job)
	end
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
	-- (the hero hold's soft background, so the set's words don't compete with the pair; off until then)
	job.dof = Instance.new('DepthOfFieldEffect')
	job.dof.Name = 'HoodUnboxFocus'
	job.dof.Enabled = false
	job.dof.FarIntensity, job.dof.NearIntensity, job.dof.FocusDistance, job.dof.InFocusRadius = 0, 0, 20, 5
	job.dof.Parent = parent
end
function Look.saveWorld(job)
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
	-- (the Terrain's clouds: the Secret's charge clears the sky)
	local clouds = workspace.Terrain:FindFirstChildOfClass('Clouds')
	if clouds then s.clouds = { inst = clouds, Cover = clouds.Cover, Density = clouds.Density } end
	-- the place's own blooms (the hold eases them down so a light pair never clips; restored exactly)
	s.blooms = {}
	for _, b in Lighting:GetChildren() do
		if b:IsA('BloomEffect') then table.insert(s.blooms, { inst = b, Intensity = b.Intensity, Threshold = b.Threshold }) end
	end
	job.saved = s
end
-- Put the world back (a chain's handover only drops this segment's own effects: the next one carries on from here).
function Look.restore(job, handover)
	if handover then
		for _, x in { job.grade, job.bloom, job.blur, job.dof } do
			if x then x:Destroy() end
		end
		job.grade, job.bloom, job.blur, job.dof = nil, nil, nil, nil
		job.ownAtm, job.saved = nil, nil
		return
	end
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
	if s.clouds and s.clouds.inst.Parent then
		s.clouds.inst.Cover = s.clouds.Cover
		s.clouds.inst.Density = s.clouds.Density
	end
	for _, b in s.blooms or {} do
		if b.inst.Parent then
			b.inst.Intensity = b.Intensity
			b.inst.Threshold = b.Threshold
		end
	end
	for _, x in { job.grade, job.bloom, job.blur, job.dof } do
		if x then x:Destroy() end
	end
	if job.ownAtm then job.ownAtm:Destroy() end
	job.grade, job.bloom, job.blur, job.dof, job.ownAtm = nil, nil, nil, nil, nil
	job.saved = nil
end
-- The looks of this opening (each names only what it changes; the rest is the world's as saved) and their keyframes.
function Look.build(job)
	local P, th = job.P, job.P.theme
	local s = job.saved
	local world = { gB = 0, gC = 0, gS = 0, gT = WHITE, bI = 0, bS = 24, bT = 2, stars = s.sky and s.sky.StarCount or 0, rays = s.rays and s.rays.Intensity or 0,
		cCover = s.clouds and s.clouds.Cover or 0, cDensity = s.clouds and s.clouds.Density or 0 }
	for _, k in LIGHT_PROPS do world[k] = s.light[k] end
	for k, v in s.atm.v do world['a' .. k] = v end
	local function from(base, o)
		local L = table.clone(base)
		for k, v in o do L[k] = v end
		return L
	end
	local looks = { world = world }
	-- cash boxes: the day with a touch more contrast; the deluxe tiers tint it (Galaxy goes to night, Gold to golden hour)
	-- (the egg's sky: fewer, thinner clouds, so the frame's contrast stays in the reference's window; CRITIC5)
	looks.day = from(world, { gB = P.egg and -0.04 or 0, gC = P.egg and -0.14 or 0.06, gS = P.egg and 0.16 or 0.08,
		cCover = world.cCover * (P.egg and 0.6 or 1), cDensity = world.cDensity * (P.egg and 0.4 or 1) })
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
	-- the Secret's lights (copy_spec §9.3), each reached in 4-5 frames and held: the deep-blue sky of the cut (Y 50-60,
	-- saturated), the charge's vivid day-blue (Y 115-130), the dip's dark in the theme's tint (Y 60-75, desaturated, never
	-- below 40), the bright day of the middle and the reveal, the purple dusk before the reveal (Y 45-75)
	local deepBlue = C3(30, 42, 120)
	looks.secretDark = from(world, {
		ClockTime = 20.6, Brightness = 0.36, Ambient = C3(58, 68, 130), OutdoorAmbient = C3(58, 68, 130), EnvironmentDiffuseScale = 0.1,
		aDensity = 0.3, aOffset = 0.2, aHaze = 1.2, aGlare = 0, aColor = deepBlue, aDecay = C3(16, 22, 63),
		stars = 0, gB = -0.05, gC = 0.1, gS = 0.35, gT = C3(176, 190, 255), bI = 0.15, bS = 24, bT = 1.2,
	})
	-- (the charge: a vivid saturated day-blue sky, its haze tinted deep blue, not night)
	looks.charge = from(world, { gB = -0.08, gC = 0.18, gS = 0.6, gT = C3(198, 214, 255), aDensity = 0.3, aHaze = 0.8, aGlare = 0, aColor = C3(56, 108, 236), aDecay = C3(40, 80, 200),
		cCover = world.cCover * 0.35, bI = 0.12, bS = 24, bT = 1.3 })
	local warm = (th.Id == 'Frost' or th.Id == 'Galaxy' or th.Id == 'Ocean' or th.Id == 'Exclusive') and C3(196, 206, 236) or C3(236, 206, 176)
	looks.dipWarm = from(world, { gB = -0.28, gC = 0.1, gS = -0.85, gT = warm:Lerp(WHITE, 0.3), Brightness = (world.Brightness or 1) * 0.7, cCover = looks.charge.cCover, bI = 0, bS = 24, bT = 1.3 })
	looks.dayLit = from(world, { gB = 0.04, gC = 0.06, gS = 0.12, bI = 0.1, bT = 1.4 })
	-- (the Secret's bright middle: day, but not white-hot, so flash 2 reads as a flash and drops in 3 frames: thinner
	-- clouds, a touch less exposure; the reference's island stage sits at Y ~160)
	looks.middle = from(looks.dayLit, { gB = -0.04, cCover = world.cCover * 0.6, cDensity = world.cDensity * 0.4 })
	-- (the whip's sky: the reference's speck in a fully saturated blue, S >= 0.85)
	looks.whipSky = from(looks.middle, { gB = -0.04, gS = 1, gT = C3(170, 196, 255), cCover = 0 })
	looks.dayHold = from(looks.day, { gB = (looks.day.gB or 0) + 0.09 })
	looks.dusk = from(world, {
		ClockTime = 18.4, Brightness = 1.3, Ambient = C3(176, 146, 196), OutdoorAmbient = C3(176, 146, 196),
		aDensity = 0.3, aOffset = 0.2, aHaze = 1.4, aGlare = 0, aColor = C3(92, 56, 105), aDecay = C3(55, 34, 82),
		stars = 0, gB = 0, gC = 0.1, gS = 0.1, gT = C3(228, 206, 255), bI = 0.15, bT = 1.2,
	})
	local keys = {}
	local function key(t, look, blur, ease) table.insert(keys, { t, look, blur or 0, ease or 'smooth' }) end
	if P.inworld then
		-- in the world: the world's own light throughout (no grade, no blur); a Secret's prelude falls to the deep-blue sky
		-- at the cut (>= 50 % in 0.15 s, never black, never white)
		key(0, world, 0)
		if P.prelude and P.cutAt then
			key(P.cutAt, world, 0)
			key(P.cutAt + 0.15, looks.secretDark, 0, 'quadOut')
		end
		key(P.done + 1, keys[#keys][2], 0)
		job.looks, job.lookKeys = looks, keys
		job.snapAt = P.done + 1
		return
	end
	if P.premium and P.secretCut then
		-- (it starts in the prelude's deep blue; each change in 4-5 frames, the big ones hidden under the white)
		-- (Reduced Motion: no flash hides the jumps, so the light eases up over 0.3 s instead)
		local a = P.accent[P.best]
		local up, ue = P.reduced and 0.3 or 0.01, P.reduced and 'sineInOut' or 'step'
		key(0, looks.secretDark, 0)
		key(P.land[1] + 0.02, looks.secretDark, 0)
		key(P.land[1] + 0.02 + up, looks.charge, 0, ue)
		key(P.dip[1], looks.charge, 0)
		key(P.dip[1] + 0.15, looks.dipWarm, 0, 'quadOut')
		key(P.flash + 0.02, looks.dipWarm, 0)
		key(P.flash + 0.02 + up, looks.middle, 0, ue)
		-- (28b: the whip into a fully saturated blue sky, blurred as the camera swings up; the hard cut to the carousel)
		if P.whip then
			key(P.whip[1] + 0.15, looks.middle, 0)
			key(P.whip[1] + 0.21, looks.whipSky, P.reduced and 0 or 14, 'quadOut')
			key(P.whip[1] + 0.32, looks.whipSky, 0, 'quadOut')
			key(P.whip[2], looks.whipSky, 0)
			key(P.whip[2] + 0.001, looks.middle, 0, 'step')
		end
		key(P.dusk[1], looks.middle, 0)
		key(P.dusk[1] + 0.14, looks.dusk, 0, 'quadOut')
		key(a + 0.02, looks.dusk, 0)
		key(a + 0.02 + up, looks.dayLit, 0, ue)
	elseif P.premium then
		key(0, looks.nightIn, 0)
		key(0.6, looks.night, 0, 'sineOut')
		key(P.dip[1], looks.night, 0)
		key(P.dip[2] - 0.01, looks.dip, 0, 'quadIn')
		key(P.flash + 0.02, looks.lit, 0, 'step')
	elseif P.prelude then
		-- a Secret's prelude: the egg's day, then the cut: the light falls >= 50 % in 4-5 frames to the deep-blue sky
		-- (never black, never white) and holds
		key(0, world, 0)
		key(P.clear, looks.day, 0, 'quadOut')
		key(P.cutAt, looks.day, 0)
		key(P.cutAt + 0.15, looks.secretDark, 0, 'quadOut')
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
			-- (the egg's card: a touch lighter, changed under the pop's flash)
			if P.egg and not P.prelude then
				key(P.pop[P.best] + 0.04, start, 0)
				key(P.pop[P.best] + 0.05, looks.dayHold, 0, 'step')
				if P.lux then
					-- (28b: the Legendary's / Mythic's dusk dip in 4-5 frames, held through the spin; day again under the flash)
					key(P.lux.dusk[1], looks.dayHold, 0)
					key(P.lux.dusk[1] + 0.14, looks.dusk, 0, 'quadOut')
					key(P.reveal + 0.02, looks.dusk, 0)
					key(P.reveal + 0.03, looks.dayHold, 0, 'step')
				end
			end
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
	if P.egg and not P.inworld then
		-- the egg's landing: a one-frame exposure pulse (+0.12; CRITIC5: never 25 luma over the frame before) decaying over
		-- 120 ms (no white); the anticipation before the pop: the frame darkens 10 % and loses a fifth of its colour in 4
		-- frames (Quad Out), then keeps sinking to -15 % and x0.7 at the pop; half on a Common (copy_spec §9.1)
		local lt = t - P.land[P.n]
		-- (a row lands on a wide pale pad, so its pulse is smaller)
		if lt >= 0 and lt < 0.12 and not P.reduced then L.gB += (P.multi and 0.08 or 0.12) * (1 - lt / 0.12) end
		local d = P.eggDip
		if d and t >= d[1] and t < P.pop[P.best] then
			local q = 0.7 * (1 - (1 - M.c01((t - d[1]) / 0.13)) ^ 2) + 0.3 * M.c01((t - d[1] - 0.13) / math.max(0.05, P.pop[P.best] - d[1] - 0.13))
			local k = P.rank == 1 and 0.5 or 1
			L.gB -= 0.1 * q * k
			L.gS -= 0.3 * q * k
		end
	end
	if job.skipAt and not P.inworld then L.blur = math.max(L.blur, 16 * M.bump(t, job.skipAt, 0.24)) end
	if P.slowmo and t >= P.slowmo[1] - 0.15 and t < P.accent[P.best] then
		local q = M.c01((t - (P.slowmo[1] - 0.15)) / 0.15)
		L.gS = M.lerp(L.gS, -0.8, q)
		L.gB = M.lerp(L.gB, -0.1, q)
	end
	-- the hold (from just before the reveal): bloom down and its threshold up, the grade eased back down after the flash;
	-- a light pair also gets the key and the fill down (key x0.65, fill x0.7), so it never clips to flat white
	local hq = M.c01((t - (P.accent[P.best] - 0.3)) / 0.5) * (1 - M.c01((t - P.out) / 0.15))
	if hq > 0 and not P.inworld then
		local lp = job.lightPair
		L.bI *= M.lerp(1, lp and 0.3 or 0.6, hq)
		L.bT = math.min(2.5, L.bT + (lp and 0.45 or 0.25) * hq)
		L.pbK = M.lerp(1, lp and 0.35 or 0.7, hq)
		L.pbT = (lp and 0.45 or 0.2) * hq
		L.gB -= (lp and 0.09 or 0.04) * hq
		if lp and not (P.egg or P.secretCut) then
			L.Brightness *= M.lerp(1, 0.8, hq)
			L.Ambient = L.Ambient:Lerp(BLACK, 0.15 * hq)
			L.OutdoorAmbient = L.OutdoorAmbient:Lerp(BLACK, 0.15 * hq)
			L.gC = M.lerp(L.gC, L.gC + 0.05, hq)
		end
	end
	if P.rank >= 6 and not P.gift and not P.secretCut and not P.egg and t > P.accent[P.best] and t < P.out then
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
	if s.clouds then
		set(s.clouds.inst, 'Cover', L.cCover)
		set(s.clouds.inst, 'Density', L.cDensity)
	end
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
	egg = { 2.6, 1.0, 1.5, 0.15, 3.2, 12 }, -- (an egg's landing: ~3.7 % of the frame's height at 70 deg, gone in 0.31 s)
	crazy = { 7, 3, 1, 0.6, 1.3, 12 }, -- (the Secret's slam: ~10 % of the height at its peak, 8-15 Hz, gone in 0.8 s)
}
-- The hero distance: the pair fills ~40 % of the screen's height and <= 70 % of a 16:9 width (it turns, so its widest
-- side counts), plus half its depth.
local function heroDist(pair, fov, share)
	local t = math.tan(RAD(fov / 2))
	local dv = pair.height / (2 * (share or 0.4) * t)
	local dh = pair.width / (2 * 0.7 * t * 16 / 9)
	return math.max(dv, dh) + pair.depth * 0.5
end
-- A single egg's shot (stage space) and the Secret's sky pose: the egg shot after its 4 % push-in, tilted up 24 deg
-- about the eye (copy_spec §9.1), and where the tear opens in it (8 deg above the frame's centre, behind the pad). The
-- prelude ends on this pose and the crazy sheet starts on it, so the seam has no cut.
local function eggShot(job)
	local P, E = job.P, Themes.Egg
	local b1 = job.boxes[P.best]
	local fov = E.Fov
	local tv = math.tan(RAD(fov / 2))
	-- (the user, after the r3 preview: no floor-level shot. A raised 3/4 instead: the eye 1.15 box heights over the pad,
	-- 18 deg round to the side, looking 11 deg down; far enough that the box's tub and lid span ~31 % of the height with
	-- its base ~72 % down, the set and the sky above it)
	local y0 = P.homes[1].Y
	local eyeH = b1.topY * 1.15
	local dFront = eyeH / math.tan(RAD(11) + math.atan(0.22 * 2 * tv))
	local d0 = dFront + b1.D * 0.5
	local yaw = RAD(E.Yaw or 18)
	local eye = V3(math.sin(yaw) * d0, y0 + eyeH, -math.cos(yaw) * d0)
	local look = V3(0, y0 + eyeH - d0 * math.tan(RAD(11)), 0)
	return eye, look, fov, d0, yaw
end
local function tiltUp(eye, look, deg)
	local d = look - eye
	local h = V3(d.X, 0, d.Z)
	local p = math.atan2(d.Y, h.Magnitude) + RAD(deg)
	local L = d.Magnitude
	return eye + h.Unit * math.cos(p) * L + V3(0, math.sin(p) * L, 0)
end
function Cam.skyPose(job)
	local eye, look, fov, d0 = eggShot(job)
	eye = V3(eye.X * 0.96, eye.Y, eye.Z * 0.96)
	local up = tiltUp(eye, look, 24)
	local tear = eye + (tiltUp(eye, look, 32) - eye).Unit * (d0 + 18)
	return eye, up, fov, tear
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
		-- THE EGG (copy_spec §9.2): FOV 70; the takeover pushes in from a lower, wider framing (0.17 s Quart Out, a 0.25 s
		-- settle); the box (tub and lid) ~32 % of the height, low and looking up, so the sky fills the frame's top ~45 %;
		-- still through the shakes but for a 4 % push-in; the hero: the pair ~45 % of the height after a 0.3 s Quart Out
		-- reframe, sliding 7 % of the width left when the Power reel shows (on the right)
		local e0, look, fov, d0, yaw0 = eggShot(job)
		local tv = math.tan(RAD(fov / 2))
		local eyeY = e0.Y
		-- (28b: the camera never parks before the read: from a raised 3/4 (never from the floor) it eases up to the
		-- glinting box at the top of the frame, tilts down with the drop, then pushes in 12 % and orbits 12 deg round the
		-- box through the shakes; a punch on every impact (Cam.punch in the beats))
		local function orb(deg, dist, dy)
			local a = yaw0 + RAD(deg)
			return V3(math.sin(a) * dist, eyeY + (dy or 0), -math.cos(a) * dist)
		end
		shot(0, orb(-9, d0 * 1.14, 0.9), look + V3(0, 0.3, 0), fov)
		shot(0.17, orb(-4, d0 * 1.05, 0.2), look + V3(0, 1.3, 0), fov, 'quartOut')
		shot(P.fall0[1], orb(-5.5, d0 * 1.04, 0.15), look + V3(0, 1.6, 0), fov, 'lin')
		shot(P.land[1] + 0.03, orb(-6, d0 * 1.03, 0.1), look, fov, 'quadIn')
		if P.prelude then
			-- (a Secret's prelude ends on the egg shot's own eye, where the sky pose starts: the seam has no cut)
			local eye, up = Cam.skyPose(job)
			shot(P.freeze[1], eye, look, fov, 'lin')
			-- the cut: the tilt-up (24 deg in 0.17 s, Quart Out; Reduced Motion: a straight cut to it), then held
			shot(P.cutAt, eye, look, fov)
			shot(P.cutAt + (P.reduced and 0.001 or 0.17), eye, up, fov, P.reduced and 'lin' or 'quartOut')
			shot(P.stop + 1, eye, up, fov)
		end
		shot(P.pop[1] - 0.02, orb(6, d0 * 0.9, -0.2), look, fov, 'lin')
		local hd = heroDist(pb, fov, 0.46)
		-- (the pair a touch above the middle: clear of the name under it and of the rarity line over it; framed 7 % left
		-- of centre from the start, room for the Power reel on the right)
		local aim = V3(0, hoverY - 0.06 * h, 0)
		local eye = V3(0, hoverY - 0.12 * h, -hd)
		local sx = -0.07 * 2 * hd * tv * 16 / 9 -- (stage +X is the screen's left from this side: the camera moves to -X)
		local function rot(v, deg)
			local a = RAD(deg)
			return V3(v.X * math.cos(a) - v.Z * math.sin(a), v.Y, v.X * math.sin(a) + v.Z * math.cos(a))
		end
		if P.lux then
			-- a Legendary's or Mythic's: up to the silhouette, a 5 % push-in and a 5 deg orbit through the dusk and the
			-- spin, a cut under the rarity flash to the read frame
			shot(P.pop[1] + 0.3, rot(eye, 4), aim, fov, 'quartOut')
			shot(P.lux.spin[2] - 0.01, rot(aim + (eye - aim) * 0.95, -1), aim, fov, 'lin')
			shot(P.lux.spin[2], eye + V3(sx, 0, 0), aim + V3(sx, 0, 0), fov, 'lin')
		else
			shot(P.pop[1] + 0.3, eye + V3(sx, 0, 0), aim + V3(sx, 0, 0), fov, 'quartOut')
		end
		-- the read: only a slow drift (2 % in over the hold)
		shot(P.out, eye + V3(sx, 0, 0) + (aim - eye) * 0.02, aim + V3(sx, 0, 0), fov, 'sine')
		job.heroYaw = 0
		job.heroShot = { eye + V3(sx, 0, 0), aim + V3(sx, 0, 0), fov }
	elseif n == 1 and P.secretCut then
		-- THE SECRET (copy_spec §2/§9.2, FOV 70): it opens on the prelude's sky pose (the tear above; the streak falls
		-- from it); a hidden cut under the slam's white to the close shot: level with the crate's lid and looking 6 deg up,
		-- so the crate (~58 % of the height) stands against the vivid sky with the horizon ~58 % down,
		-- a slow drift to 1.33 s then still; a hard cut under flash 2's white to the bright middle (the pair in
		-- silhouette, 45 % of the height), still; a 4 % push-in through the dusk and the rings; after the reveal it
		-- slides 7 % of the width left for the Power reel
		local eye, up, fov, tear = Cam.skyPose(job)
		job.tear = tear
		P.cometFrom = b1.home:VectorToObjectSpace(job:wp(tear) - b1.home.Position)
		shot(0, eye, up, fov)
		shot(P.land[1] + 0.02, eye, up, fov)
		local tv = math.tan(RAD(fov / 2))
		-- (the user, after the r3 preview: never below the box's mid-height; level with the lid, 6 deg up)
		local dc = b1.fullH * 1.25
		local ceye = V3(0, P.homes[1].Y + b1.fullH * 0.6, -dc)
		local clook = ceye + V3(0, dc * math.tan(RAD(6)), dc)
		shot(P.land[1] + 0.021, ceye + V3(0, 0.25, 0), clook + V3(0, 0.25, 0), fov, 'lin')
		shot(1.33, ceye, clook, fov, 'sine')
		shot(P.flash + 0.03, ceye, clook, fov)
		-- (a Secret pair wears its halo and crown above it: a little smaller and lower than an egg's, clear of the title)
		local hd = heroDist(pb, fov, 0.42)
		local aim = V3(0, hoverY + 0.1 * h, 0)
		local heye = V3(0, hoverY - 0.12 * h, -hd)
		-- 9 the whip: the close shot holds as the pair launches past the lens, then whips up into the sky (Quart Out,
		-- 0.12 s, blurred) and drifts on the speck until the hard cut
		local skyLook = ceye + V3(0, dc * math.tan(RAD(58)), dc)
		job.whip = { eye = ceye, dir = (skyLook - ceye).Unit }
		shot(P.whip[1] + 0.15, ceye + V3(0, 0.1, 0.2), clook, fov, 'lin')
		shot(P.whip[1] + 0.27, ceye, skyLook, fov, 'quartOut')
		shot(P.whip[2], ceye + V3(0.4, 0, 0), skyLook + V3(-2, 0.6, 0), fov, 'lin')
		-- 10 the carousel: a hard cut to the ring of five, seen from a little below against the sky, pushing in slowly;
		-- 11-12 the pick and the tease: in to the hero framing
		local R, pw = job.carouselR or 6, pb.width
		local weye = V3(0, hoverY - 0.2 * pw, -1.9 * pw)
		local wlook = V3(0, hoverY + 0.32 * pw, R * 0.5)
		shot(P.carousel[1] + 0.001, weye, wlook, fov, 'lin')
		shot(P.carousel[2], weye + (wlook - weye) * 0.1, wlook, fov, 'lin')
		shot(P.tease[1] + 0.1, heye + (aim - heye) * -0.06, aim, fov, 'quartOut')
		shot(P.dusk[1], heye, aim, fov, 'lin')
		shot(P.accent[1], heye + (aim - heye) * 0.04, aim, fov, 'sine')
		local sx = -0.07 * 2 * hd * tv * 16 / 9
		local heye2 = heye + (aim - heye) * 0.04
		shot(P.count[1], heye2, aim, fov)
		shot(P.count[1] + 0.35, heye2 + V3(sx, 0, 0), aim + V3(sx, 0, 0), fov)
		shot(P.out, heye2 + V3(sx, 0, 0) + (aim - heye2) * 0.02, aim + V3(sx, 0, 0), fov, 'sine')
		job.heroYaw = 0
		job.heroShot = { heye2 + V3(sx, 0, 0), aim + V3(sx, 0, 0), fov }
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
		local fov = P.premium and 62 or Themes.Egg.Fov
		local tv = math.tan(RAD(fov / 2))
		local d = math.max(rowW / 0.8 / (2 * tv * 16 / 9), (fullH + top) / 0.55 / (2 * tv)) + (n >= 5 and 3 or 1.5)
		local midY = 0.22 + (fullH + top) * 0.45
		-- (no floor-level shot: the eye over the boxes, looking 12 deg down at the row; the crazy batch keeps its own)
		local eyeY = P.premium and midY + (n >= 5 and 2.6 or 1) or math.max(midY + d * math.tan(RAD(12)), 0.22 + (fullH + top) * 1.05)
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
			-- (the takeover push-in from a little higher, 0.17 s Quart Out, then a settle)
			shot(0, V3(0, eyeY + 1.0, -d * 1.1), V3(look.X, lookY0 - d * 0.1, look.Z), fov)
			shot(0.17, V3(0, eyeY + 0.2, -d * 1.01), V3(look.X, lookY0 - d * 0.02, look.Z), fov, 'quartOut')
			if P.fan then
				-- (28b: the camera sweeps across the row as the boxes slam in, 24 deg round it, pushing in through the shakes)
				local function sw(deg, k)
					local a = RAD(deg)
					return V3(math.sin(a) * d * k, eyeY, look.Z - math.cos(a) * d * k)
				end
				shot(0.42, sw(-12, 1), V3(look.X, lookY0, look.Z), fov, 'sine')
				shot(P.lastLand + 0.15, sw(2, 0.99), look, fov, 'lin')
				shot(P.firstPop, sw(12, 0.92), look, fov, 'lin')
			else
				shot(0.42, V3(0, eyeY, -d), V3(look.X, lookY0, look.Z), fov, 'sine')
				shot(P.lastLand + 0.15, V3(0, eyeY, -d), look, fov, 'sine')
			end
			if P.prelude then
				-- (a Secret batch's cut: the row's shot tilts up 24 deg as the Secret's box lifts into the tear)
				shot(P.cutAt, V3(0, eyeY, -d), look, fov)
				shot(P.cutAt + (P.reduced and 0.001 or 0.17), V3(0, eyeY, -d), tiltUp(V3(0, eyeY, -d), look, 24), fov, P.reduced and 'lin' or 'quartOut')
				shot(P.stop + 1, V3(0, eyeY, -d), tiltUp(V3(0, eyeY, -d), look, 24), fov)
			end
			if not P.fan then shot(P.group - 0.35, V3(-1, eyeY - 0.3, -d * 0.95), look, fov, 'sine') end
		end
		if n >= 5 and job.lineY then
			-- a Buy 8: the whole line-up (back row, the best front and centre between two) fills ~85 % of the width, in
			-- the middle band of the frame (the banner above it, the name and the chip below it)
			local yF, yB, ph = job.lineY[1], job.lineY[2], job.lineY[3]
			-- (a longer lens than the egg's, so the back row isn't shrunk by perspective: CRITIC5 wants it >= 12 % of H)
			local gf = P.premium and 46 or 48
			local gt = math.tan(RAD(gf / 2))
			local gd = job.lineW / 0.88 / (2 * gt * 16 / 9)
			-- (the line-up sits a little low, so the back row's tags stay under the title block)
			local tgt = V3(0, yF + (yB - yF + ph + 1.2) * 0.5 + 0.09 * 2 * gd * gt, 0.4)
			local eye = V3(0.5, tgt.Y + gd * 0.14, tgt.Z - gd)
			-- (28b: pulled back round the revolving fan, then in to the line-up as it settles)
			if P.fan then
				shot(P.fan[1], V3(-2, tgt.Y + gd * 0.16, tgt.Z - gd * 1.1), tgt + V3(0, 0.5, 0), gf, 'quartOut')
				shot(P.fan[2], V3(1, tgt.Y + gd * 0.15, tgt.Z - gd * 1.04), tgt + V3(0, 0.3, 0), gf, 'lin')
			end
			shot(P.group + 0.25 + (P.fan and 0.3 or 0), eye, tgt, gf, P.fan and 'sine' or nil)
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
			local gf = P.premium and 52 or Themes.Egg.Fov
			local gt = math.tan(RAD(gf / 2))
			local pRow = (maxX - minX) * UnboxCinematic.Gather + pairW * 1.1
			local tgt = V3(0, hy, -0.5)
			if n == 2 and job.slots then
				pRow = 6 + pairW * 1.7
				tgt = V3(-0.4, hy, -0.2)
			end
			local gd = pRow / 0.85 / (2 * gt * 16 / 9) + 1.5
			local eye = V3(0.5, hy + gd * 0.12, -gd)
			if P.fan then
				shot(P.fan[1], V3(-2, hy + gd * 0.12, -gd * 1.08), tgt + V3(0, 0.4, 0), gf, 'quartOut')
				shot(P.fan[2], V3(1, hy + gd * 0.1, -gd * 1.03), tgt + V3(0, 0.2, 0), gf, 'lin')
			end
			shot(P.group + 0.25 + (P.fan and 0.3 or 0), eye, tgt, gf, P.fan and 'sine' or nil)
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
local CAMEASE = { cubic = M.inout, sine = M.sineInOut, quadIn = function(u) return M.c01(u) ^ 2 end, lin = M.c01, quartOut = function(u) return 1 - (1 - M.c01(u)) ^ 4 end }
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
-- (brief 28: one family for the game, Shared/Fonts by role; the house outline is plain near-black, round joins)
local ROLE = { reveal = 'Title', title = 'Title', heading = 'Heading', body = 'Body', number = 'Number' }
local OUTLINE = Fonts and Fonts.Outline and Fonts.Outline.Color or C3(6, 6, 8)
local function font(name)
	local role = ROLE[name] or 'Title'
	if Fonts and Fonts[role] then return Fonts[role] end
	return Font.new('rbxasset://fonts/families/Montserrat.json', role == 'Body' and Enum.FontWeight.Bold or Enum.FontWeight.Heavy)
end
local function label(parent, props)
	local t = Instance.new('TextLabel')
	t.BackgroundTransparency = 1
	t.BorderSizePixel = 0
	t.TextScaled = false
	t.TextTransparency = 1
	t.TextColor3 = WHITE
	t.FontFace = props.FontFace or font(props.Role or 'reveal')
	for k, v in props do
		if k ~= 'Stroke' and k ~= 'StrokeThickness' and k ~= 'FontFace' and k ~= 'Role' then (t :: any)[k] = v end
	end
	local s = Instance.new('UIStroke')
	s.Color = props.Stroke or OUTLINE
	-- (the house outline's thickness for this size and role when Fonts is there)
	local role = ROLE[props.Role or 'reveal'] or 'Title'
	s.Thickness = (Fonts and type(Fonts.strokeFor) == 'function' and Fonts.strokeFor(props.TextSize or 24, role)) or props.StrokeThickness or 4
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
	-- (the soft pop flash in the rarity's own colour, so the frame keeps its colour under it; CRITIC5: S >= 0.35)
	W.softColor = P.egg and rcol:Lerp(WHITE, 0.4) or rcol:Lerp(WHITE, 0.7)
	W.tintColor = rcol:Lerp(WHITE, 0.25)
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
	-- (copy_spec §9.5: the rarity line is small and quiet, top-centre, its cap height 4.5 % of the height and its midline
	-- 17 % down; it enters under the pop / the flash with no fly-in. The spectacle carries the hype, not the words.)
	local rname = string.upper(rarityRow(rank).Name or 'Common')
	local big = 40
	local rowY = 110
	W.rarity = label(stage, { Name = 'Rarity', Text = rname, TextSize = big, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0, rowY), Size = UDim2.new(1, 0, 0, big + 10), ZIndex = 32 })
	W.rarityScale = Instance.new('UIScale')
	W.rarityScale.Scale = 1
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
	local below = rowY - 34 -- (the box line keeps the top; the rarity word sits under the pair, below)
	if P.multi then
		local box = boxDef(P.box)
		W.sub = label(stage, { Name = 'Count', Role = 'heading', Text = P.gift and 'Welcome gift!' or ((box and box.Name or 'Box') .. '  x' .. P.n), TextSize = 22, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0, below + 34), Size = UDim2.new(1, 0, 0, 28), ZIndex = 32 })
		gradient(W.sub, { C3(255, 242, 122), C3(255, 168, 26) }, 90)
	end
	-- (the gift's best pair stands centre-left: its name and chip sit under it)
	local nameX = P.n == 2 and 0.28 or P.n == 1 and 0.43 or 0.5
	W.reelRight = P.n == 1 -- (a single: the Power reel stands right of the pair, which slides left to make room)
	W.name = label(stage, { Name = 'Name', Text = sd and sd.Name or tostring(best.Shoe), TextSize = P.multi and 46 or 54, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(nameX, 0, 1, P.multi and -100 or -76), Size = UDim2.new(1, 0, 0, 62), ZIndex = 32 })
	-- (Oct 27, release fixes: the open item "rarity text under the shoe") the rarity word, in its colour, right under the
	-- pair's name (the in-world opening has it there too) instead of alone at the top
	W.rarity.TextSize = 30
	W.rarity.AnchorPoint = Vector2.new(0.5, 1)
	W.rarity.Position = UDim2.new(nameX, 0, 1, P.multi and -64 or -40)
	W.rarity.Size = UDim2.new(1, 0, 0, 36)
	W.bonusValue = sd and sd.Bonus or 0
	if W.reelRight then
		W.bonus = label(stage, { Name = 'Bonus', Role = 'number', Text = '+0% Power', TextSize = 36, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.81, 0, 0.46, 0), Size = UDim2.fromOffset(280, 46), ZIndex = 32 })
	else
		W.bonus = label(stage, { Name = 'Bonus', Role = 'number', Text = '+0% Power', TextSize = 32, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(nameX, 0, 1, -26), Size = UDim2.new(1, 0, 0, 44), ZIndex = 32 })
	end
	W.bonusScale = Instance.new('UIScale')
	W.bonusScale.Parent = W.bonus
	-- the Power chip: the bonus drops into it from the name's line, then counts up (a tick a step)
	if W.reelRight then
		W.chip = frame(stage, 'PowerChip', { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.81, 0, 0.46, 0), Size = UDim2.fromOffset(270, 58), BackgroundColor3 = C3(18, 16, 30), ZIndex = 31 })
	else
		W.chip = frame(stage, 'PowerChip', { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(nameX, 0, 1, -20), Size = UDim2.fromOffset(300, 54), BackgroundColor3 = C3(18, 16, 30), ZIndex = 31 })
	end
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
	-- 28b, the reference's beat 16: the Power reel, a slot reel of star-numbered rows rolling up inside the chip and
	-- easing to a stop on the pair's Power in 0.8 s (a single's; the stars are two gold squares, one turned 45 deg)
	if W.reelRight then
		local clip = frame(stage, 'PowerReel', { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.81, 0, 0.46, 0), Size = UDim2.fromOffset(270, 58), ClipsDescendants = true, ZIndex = 32 })
		W.reel = { clip = clip, rows = {} }
		local K = 10
		for k = 1, K do
			local v = math.floor(W.bonusValue * (k / K) ^ 0.75 + 0.5)
			local row = frame(clip, 'Row' .. k, { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 0, 0.5, 0), Size = UDim2.new(1, 0, 0, 58), ZIndex = 33 })
			local stars = {}
			for _, r in { 0, 45 } do
				table.insert(stars, frame(row, 'Star', { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0, 34, 0.5, 0), Size = UDim2.fromOffset(19, 19), Rotation = r, BackgroundColor3 = k == K and C3(255, 214, 60) or C3(220, 200, 150), ZIndex = 34 }))
			end
			local l = label(row, { Name = 'Value', Role = 'number', Text = ('+%d%% Power'):format(v), TextSize = 32, AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 54, 0.5, 0), Size = UDim2.new(1, -60, 1, 0), TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 34 })
			if k == K then
				if rank >= 6 then gradient(l, rainbowSeq(2), 0) else gradient(l, { WHITE, rcol:Lerp(WHITE, 0.3) }, 90) end
			end
			W.reel.rows[k] = { row = row, label = l, stars = stars }
		end
	end
	if not UnboxCinematic.ShowPower then
		for _, g in { W.bonus, W.chip, W.reel and W.reel.clip } do g.Visible = false end
	end
	-- the chance: the pair's drop chance from this box, under the rarity word
	local ct = oneIn(P.chance)
	if ct then
		W.chance = label(stage, { Name = 'Chance', Role = 'number', Text = ct, TextSize = 27, TextColor3 = WHITE, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0, below + 6), Size = UDim2.new(1, 0, 0, 32), ZIndex = 32 })
	end
	if best.New then
		-- (clear of the rarity word by >= 0.3 of its cap height: placed from the word's measured width)
		local wordW = #rname * big * 0.78
		pcall(function()
			local ts = game:GetService('TextService')
			local v = ts:GetTextSize(rname, big, Fonts and Fonts.Enum and Fonts.Enum.Title or Enum.Font.GothamBlack, Vector2.new(2000, 200))
			if v.X > 0 then wordW = v.X end
		end)
		W.new = label(stage, { Name = 'New', Role = 'heading', Text = 'NEW', TextSize = 22, TextColor3 = C3(124, 255, 79), AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0.5, wordW * 0.5 + math.max(12, big * 0.7 * 0.3), 0, rowY - 12), Size = UDim2.fromOffset(80, 28), TextXAlignment = Enum.TextXAlignment.Left, Rotation = -8, ZIndex = 33 })
	end
	W.tap = label(stage, { Name = 'Tap', Role = 'body', Text = 'Tap to skip', TextSize = 22, StrokeThickness = 3, TextColor3 = C3(230, 230, 240), AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -24, 1, -14), Size = UDim2.fromOffset(260, 30), TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 34 })
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
				local l = label(bb, { Name = 'Tag', Role = 'heading', Text = string.upper(rarityRow(r).Name or ''), TextSize = 24, StrokeThickness = 3, Size = UDim2.fromScale(1, 0.62), ZIndex = 2 })
				l.TextScaled = true
				fadeText(l, 1)
				if r >= 6 then gradient(l, rainbowSeq(0), 0) else gradient(l, { WHITE, rarityColor(r) }, 90) end
				if pair.entry.New then
					local nw = label(bb, { Name = 'New', Role = 'heading', Text = 'NEW!', TextSize = 18, StrokeThickness = 2.5, TextColor3 = C3(124, 255, 79), Position = UDim2.fromScale(0, 0.6), Size = UDim2.fromScale(1, 0.4), ZIndex = 2 })
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
				-- (copy_spec §3: no rise, a 2-frame hold, then the tail (Cubic out))
				local hold = f[4] or 0.067
				if tau < hold then a = 1 else a = 1 - M.out((tau - hold) / (dur - hold), 3) end
				if f[2] * a > fa then
					fa = f[2] * a
					soft = li == 2
				end
			end
		end
	end
	local fc = soft and ((P.reduced and W.tintColor) or W.softColor or WHITE) or WHITE
	if W.flash.BackgroundColor3 ~= fc then W.flash.BackgroundColor3 = fc end
	local ft = 1 - M.c01(fa)
	if W.flash.BackgroundTransparency ~= ft then W.flash.BackgroundTransparency = ft end
	local outA = 1 - M.c01((t - P.out) / 0.15)
	-- the banner: scale 1.6 -> 1 (Back Out 220 ms) with an 80 ms fade-in; Legendary and up pulse once
	-- (no fly-in: it is there when the pop / the flash clears)
	fadeText(W.rarity, M.c01((t - P.banner) / 0.07) * outA)
	if W.rarityGrad then W.rarityGrad.Offset = Vector2.new((t * 0.5) % 1 - 0.5, 0) end
	local bandA = M.c01((t - P.banner + 0.1) / 0.25) * outA * 0.3
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
	if W.reel then
		-- (the reel rolls up through its rows, ~1 a frame at first, Quart Out to a stop on the last at count[2]; the rows
		-- near the window's edges fade; the last one ticks bigger as it lands)
		fadeText(W.bonus, 0)
		local K = #W.reel.rows
		local rq = M.c01((t - P.count[1]) / (P.count[2] - P.count[1]))
		local pos = (K - 1) * M.out(rq, 4)
		for k, r in W.reel.rows do
			local off = (k - 1) - pos
			local y = -off * 58
			if r.row.Position.Y.Offset ~= y then r.row.Position = UDim2.new(0, 0, 0.5, y) end
			local a = cq * outA * M.c01(1 - math.abs(off) * 0.9)
			fadeText(r.label, a)
			for _, st in r.stars do
				local bt = 1 - a
				if math.abs(st.BackgroundTransparency - bt) > 1e-3 then st.BackgroundTransparency = bt end
			end
		end
		local land = M.c01((t - P.count[2]) / 0.2)
		W.chipScale.Scale = cq > 0 and (M.back(cq, 1.8) + 0.08 * math.sin(land * PI)) or 0.01
	elseif W.reelRight then fadeText(W.bonus, cq * outA) else line(W.bonus, cT, -46) end
	line(W.chance, P.banner + 0.12)
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
		W.new.Size = UDim2.fromOffset(80 * ns, 28 * ns)
		W.new.Rotation = -8
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
	fx.puffRing = job:emitter('LandPuff', 'smoke', seqOf({ C3(232, 226, 216), C3(206, 200, 190) }), {
		life = { 0.45, 0.6 }, speed = { 10, 14 }, drag = 5, accel = V3(0, 1.5, 0), spread = Vector2.new(8, 8), direction = Enum.NormalId.Front,
		lightInfluence = 0, emission = 0, size = nseq({ { 0, 1.5 * G * 0.8, 0.2 }, { 1, 4.5 * G * 0.8 } }),
		transparency = nseq({ { 0, 1 }, { 0.05, 0.2 }, { 0.6, 0.55 }, { 1, 1 } }), rotSpeed = NR(-50, 50), zoffset = 1,
	})
	-- landings: a thin, even ring edge racing out over the pad (a beam circle, not a glow disc); premium on top of its
	-- floor glow, out to 14 studs
	job.slamRings = {}
	for i = 1, P.n do
		if i == P.n or P.n <= 4 or i % 2 == 1 then job.slamRings[i] = Ring.new(job.anchor, 'SlamRing' .. i, P.egg and WHITE or th.Color:Lerp(WHITE, 0.55), P.premium and 0.3 or 0.22, P.premium and 0.9 or 0.7, true) end
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
	if P.egg then
		-- the egg's target ring (a thin white circle ~1.1x the box's footprint, 0.2 s) and the rainbow pop's ring burst
		-- (2.5 -> 5 box widths in 0.1 s, the rarity colour, facing the camera)
		local W0 = job.boxes[P.best].W
		fx.target = job:emitter('Target', 'ring', seqOf({ WHITE, WHITE }), {
			life = { 0.22, 0.22 }, speed = { 0.01, 0.01 }, spread = Vector2.zero, orientation = Enum.ParticleOrientation.VelocityPerpendicular,
			size = NumberSequence.new(W0 * 0.62), transparency = nseq({ { 0, 0.15 }, { 0.6, 0.35 }, { 1, 1 } }), rotation = NR(0), rotSpeed = NR(0), emission = 1,
		})
		-- the pop's radial burst at the box (CRITIC5: ~2.5 box widths; the overlay flash stays soft): a ring racing out
		-- from the box to 2.5 widths in 4 frames and a hot core glow, in the rarity colour
		fx.ringBurst = job:emitter('RingBurst', 'ring', seqOf({ WHITE:Lerp(rcol, 0.6), rcol }), {
			life = { 0.15, 0.15 }, speed = { 0.01, 0.01 }, spread = Vector2.zero, orientation = Enum.ParticleOrientation.VelocityPerpendicular,
			size = nseq({ { 0, W0 * 0.45 }, { 0.8, W0 * 1.25 }, { 1, W0 * 1.3 } }), transparency = nseq({ { 0, 0 }, { 0.6, 0.2 }, { 1, 1 } }), rotation = NR(0), rotSpeed = NR(0), emission = 1, zoffset = 2,
		})
		fx.popGlow = job:emitter('PopGlow', 'glow', seqOf({ WHITE, WHITE:Lerp(rcol, 0.5) }), {
			life = { 0.16, 0.16 }, speed = { 0.01, 0.01 }, spread = Vector2.zero, rotation = NR(0), rotSpeed = NR(0), emission = 1, lightInfluence = 0,
			size = nseq({ { 0, W0 * 0.6 }, { 1, W0 * 1.0 } }), transparency = nseq({ { 0, 0.25 }, { 0.4, 0.5 }, { 1, 1 } }), zoffset = 1,
		})
	end
	-- 28b, a Legendary's or Mythic's single: the rings that close in round the spinning silhouette (3 for a Legendary
	-- in golds, 4 bigger for a Mythic in its pinks and violet; solid saturated colours)
	if P.lux then
		job.luxRings = {}
		local cols = P.lux.level == 2 and { C3(255, 50, 140), C3(255, 40, 70), C3(170, 70, 255), WHITE } or { C3(255, 186, 20), C3(255, 120, 20), C3(255, 236, 140) }
		local pw = job.pairs[P.best].width
		for k = 1, P.lux.rings do
			local r = Ring.new(job.anchor, 'LuxRing' .. k, cols[k], 0.07 * pw, 0.07 * pw * 2.4, true, cols[k] ~= WHITE)
			r:setColor(cols[k], true)
			job.luxRings[k] = r
		end
	end
	fx.glint = job:emitter('Glint', 'spark', seqOf({ WHITE, th.Color:Lerp(WHITE, 0.5) }), {
		life = { 0.35, 0.35 }, speed = { 0, 0.01 }, size = nseq({ { 0, 0 }, { 0.4, 2.6 }, { 1, 0 } }), transparency = nseq({ { 0, 0 }, { 1, 0.2 } }), brightness = 2, zoffset = 1,
	})
	if P.premium then
		fx.telegraph = Preset.shock(job, 'Telegraph', P.multi and 5 * G or 6 * G, 0.5, th.Color)
		fx.crackle = job:emitter('Crackle', 'spark', seqOf({ WHITE, WHITE }), {
			life = { 0.1, 0.18 }, speed = { 0, 0.01 }, size = nseq({ { 0, (P.secretCut and 3.4 or 2.8) * G, 0.4 }, { 1, 2.4 * G } }), transparency = nseq({ { 0, 0 }, { 1, 1 } }), brightness = 3,
			rotation = NR(0, 360),
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
		-- (the Secret's mystery middle: motes in its neon rising past the silhouette until the reveal)
		local moteCol = P.secretCut and (th.Neon or { th.Relit })[1] or th.Relit
		fx.pillarMotes = job:emitter('PillarMotes', 'spark', seqOf({ WHITE, moteCol }), {
			life = { 1, 1.4 }, speed = { 6, 10 }, spread = Vector2.new(P.secretCut and 14 or 8, P.secretCut and 14 or 8), drag = 0.5,
			size = nseq({ { 0, P.secretCut and 0.55 or 0.3 }, { 1, 0 } }), transparency = nseq({ { 0, 1 }, { 0.2, 0 }, { 1, 1 } }), rate = P.secretCut and 30 or 25,
		})
		-- (and an outline in that neon round the silhouette, so it reads as a shape, not a hole)
		if P.secretCut then
			local hl = Instance.new('Highlight')
			hl.Name = 'SilhouetteEdge'
			hl.Adornee = job.pairs[P.best].model
			hl.FillTransparency = 1
			hl.OutlineColor = moteCol
			hl.OutlineTransparency = 1
			hl.DepthMode = Enum.HighlightDepthMode.Occluded
			hl.Enabled = false
			hl.Parent = job.folder
			job.silEdge = hl
			-- (the carousel's others wear the same outline: nothing marks the true one)
			if job.cands then
				job.candEdges = {}
				for k, c in job.cands do
					local h = hl:Clone()
					h.Adornee = c.model
					h.OutlineTransparency = 0
					h.Parent = job.folder
					job.candEdges[k] = h
				end
			end
		end
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
	-- the Secret's tear in the sky (copy_spec §9.1): a jagged slit in the theme's colour, ~8 % of the frame's width, with
	-- a soft glow; it opens in the prelude's dark (the box rises into it) and the crazy sheet's streak falls from it
	if P.prelude or P.secretCut then
		local _, _, _, tear = Cam.skyPose(job)
		local eye = Cam.skyPose(job)
		local cf = CFrame.lookAt(job:wp(tear), job:wp(eye))
		local col = th.Color:Lerp(WHITE, 0.3)
		job.tearParts = {}
		local pts = { V3(-1.9, 0.1, 0), V3(-0.95, -0.28, 0), V3(0, 0.3, 0), V3(0.95, -0.22, 0), V3(1.9, 0.12, 0) }
		for k = 1, #pts - 1 do
			local a, b = pts[k] * G * 2.4, pts[k + 1] * G * 2.4
			local seg = Make.part(job.folder, 'Tear', V3((b - a).Magnitude + 0.3, 0.5, 0.1), job.park, col, Enum.Material.Neon)
			table.insert(job.tearParts, { seg, CF((a + b) / 2) * CFrame.Angles(0, 0, math.atan2(b.Y - a.Y, b.X - a.X)) })
		end
		local glow = Make.part(job.folder, 'TearGlow', V3(0.2, 0.2, 0.2), job.park, WHITE, nil, { Transparency = 1 })
		table.insert(job.tearParts, { glow, CF(0, 0, 0.3) })
		job.tearGlow = job:emitter('TearGlow', 'glow', seqOf({ th.Color:Lerp(WHITE, 0.2), th.Color }), {
			life = { 30, 30 }, speed = { 0, 0 }, rotSpeed = NR(0), rotation = NR(0), size = NumberSequence.new(9 * G),
			transparency = nseq({ { 0, 0.35 }, { 1, 0.35 } }), emission = 1, lightInfluence = 0, zoffset = -1,
		}, glow)
		job.tearGlow.LockedToPart = true
		job.tearCF = cf
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
		-- (phones: 3 PointLights at most; the rim light takes the far lamp's)
		local far = job.lamps and job.lamps[2]
		if far and far.light then
			far.light:Destroy()
			far.light = nil
		end
	end
	-- premium: the energy rings and the build-up pillar behind the box
	if P.premium then
		job.rings = {}
		if P.secretCut then
			-- copy_spec §4: few, big, flat single-colour rings, thick and saturated (drawn in their own colour, so they stay
			-- vivid over the blue sky): A (the theme's first neon, 1.9 crate widths, 0.09 thick), B (its second, 2.3,
			-- 0.08), C (a thin fast yellow one, 1.3, 0.035), D (huge and white behind, 3.7, 0.05)
			local W0 = job.boxes[P.best].W
			local neon = th.Neon or { th.Color, th.Accent }
			for i, spec in { { neon[1], 0.09, true }, { neon[2], 0.08, true }, { C3(255, 214, 40), 0.035, true }, { WHITE, 0.05, false } } do
				local r = Ring.new(job.anchor, 'Energy' .. i, spec[1], spec[2] * W0, spec[2] * W0 * 2.4, true, spec[3])
				r:setColor(spec[1], true)
				job.rings[i] = r
			end
		else
			for i, c in th.Rings do job.rings[i] = Ring.new(job.anchor, 'Energy' .. i, c, i == 3 and 0.2 or 0.55, i == 3 and 0.45 or 1.7) end
			job.rings[3]:setColor(WHITE)
		end
		local a0, a1 = Make.attach(job.anchor, 'BuildFoot'), Make.attach(job.anchor, 'BuildTop')
		job.buildBeam = Make.beam(job.anchor, a0, a1, seqOf({ WHITE, th.Accent }), 1, 1, nseq({ { 0, 0.4 }, { 0.6, 0.6 }, { 1, 1 } }), 1, { Segments = 1, Tex = 'shaft' })
		job.buildBeam.Enabled = false
		job.buildAtt = { a0, a1 }
	end
	-- light pillars: premium one per box (a Buy 8: a light wall of three), the normal tier's from Mythic
	job.pillars = {}
	local spots = {}
	if P.premium then
		if P.secretCut then spots = {} elseif P.n >= 5 then spots = { 1, math.ceil(P.n / 2), P.n } else for i = 1, P.n do table.insert(spots, i) end end
	elseif P.egg and P.rank >= 4 or P.R.Pillar then
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
	if P.egg or P.secretCut then nr = 0 end
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
	if job.lightPair or th.Id == 'Grail' or job.darkPair or P.egg then
		local col, tr, em = th.Id == 'Grail' and C3(102, 48, 153) or th.Deep:Lerp(BLACK, 0.25), th.Id == 'Grail' and 0.3 or 0.55, 0
		if P.egg then
			-- (an egg's reveal card: the rarity's soft glow behind the pair, in daylight)
			col, tr, em = rcol:Lerp(WHITE, 0.3), job.lightPair and 0.45 or 0.6, 0.7
		elseif job.darkPair and th.Id ~= 'Grail' then
			-- (a dark pair: the rarity's glow at 35 %, so its silhouette separates from the night)
			col, tr, em = rcol:Lerp(WHITE, 0.15), 0.65, 0.6
		end
		job.backdrop = job:emitter('Backdrop', 'glow', seqOf({ col, col }), {
			life = { 30, 30 }, speed = { 0, 0 }, rotSpeed = NR(0), rotation = NR(0), size = NumberSequence.new(1),
			transparency = nseq({ { 0, tr }, { 1, tr } }), emission = em, lightInfluence = 0, zoffset = -3,
		})
		job.backdrop.LockedToPart = true
		job.backdropDark = not P.egg and not (job.darkPair and th.Id ~= 'Grail')
	end
	-- Legendary+: two comets orbiting the pair (neon beads with short tails)
	job.orbiters = {}
	for i = 1, (P.premium and not P.secretCut) and P.R.Comets or 0 do
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
	fan(job, 'PrismFan' .. i, i, 6, { C3(110, 220, 255), WHITE, C3(255, 140, 230), C3(160, 255, 240) }, job.P.lid and job.P.lid[i] or job.P.pop[i], 1.3, 25)
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
				if pair.pos and t > (P.lid and P.lid[i] or P.pop[i]) and fade > 0 and job.pairYaw then
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
		local a = M.c01((t - (P.flash or P.accent[P.best] - 0.4)) / 0.4) * (1 - M.c01((t - P.out) / 0.2))
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
	-- the set's night (UnboxStage: lit windows, shop glass, the theme's string lights) with the Secret's dark beats
	if type(Stage.night) == 'function' then
		local function night(t0, a, lights) self:at(t0, function() pcall(Stage.night, self, a, lights) end, true) end
		if P.prelude and P.cutAt then night(P.cutAt + 0.05, 1) end
		if P.lux then
			night(P.lux.dusk[1] + 0.08, 1, 0.35)
			night(P.reveal + 0.03, 0)
		end
		if P.secretCut then
			night(0, 1)
			night(P.land[1] + 0.03, 0)
			night(P.dip[1] + 0.1, 0.5)
			night(P.flash + 0.03, 0)
			night(P.dusk[1] + 0.1, 1, 0.35)
			night(P.accent[P.best] + 0.03, 0)
		end
	end
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
		-- the egg's telegraph: the shadow grows on the pad (Job:frame) and a thin white target ring marks it at 0.30
		for i, box in self.boxes do
			if fx.target and (P.n <= 4 or i % 2 == 1) then self:at(P.appear[i], function() self:emit(fx.target, 1, box.home * CF(0, 0.06, 0)) end) end
			-- (28b: the box glints twice as it hangs in the sky, the anticipation before the drop)
			if fx.glint and (P.n <= 4 or i % 2 == 1) then
				for k, dt in { 0.03, 0.15 } do
					self:at(P.appear[i] + dt, function()
						self:emit(fx.glint, 1, box.home * CF((k == 1 and 0.3 or -0.25) * box.W, P.fallH + box.topY * (k == 1 and 0.75 or 0.4), -box.D * 0.55))
					end)
				end
			end
		end
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
		if P.premium then
			Cam.shake(self, land, P.secretCut and 'crazy' or 'slam', P.trauma[i])
		else
			-- (the egg: 2-4.5 % of the height, gone in 0.31 s; a row's boxes shake the frame less, the last one most)
			Cam.shake(self, land, 'egg', big and 1 or 0.45)
		end
		if big then
			if P.premium then
				Cam.punch(self, land, -10, 0.06, 2.5, 0.55)
				Cam.kick(self, land, -1.2, -0.15)
				self:at(land, function() self.pulseAt = self.t end)
			else
				Cam.punch(self, land, -2, 0.05, 3.2, 0.7)
			end
		end
		-- debris: real chunks (premium 12; on the normal tier the heavy themes' rock and ice only)
		local deb = th.Debris
		local count = P.premium and (P.multi and (big and 10 or 4) or 12) or (P.multi and (big and 4 or 0) or 7)
		if count > 0 then
			if P.premium then
				-- (premium: chunks in bright colours that read on the night deck, born on the box's rim and thrown toward the
				-- camera's half of the pad, so they land 2-5 studs out and rest in view through the charge)
				local cols = th.Id == 'Grail' and { C3(255, 200, 60), WHITE, C3(255, 226, 140) } or th.Id == 'Exclusive' and { C3(120, 230, 255), WHITE, C3(255, 150, 230) } or { th.Accent, WHITE, th.Color }
				local glass = th.Id == 'Exclusive'
				-- (the Secret's low close shot: smaller chunks thrown out to the sides and back, so none lands at the lens)
				if P.secretCut then cols = th.Debris.colors end
				local sc = P.secretCut and not P.multi
				self:spawn({ kind = glass and 'shard' or 'cube', n = P.multi and count or 13, colors = cols, t0 = land, at = box.home * CF(0, 0.6, 0), ring = box.W * 0.55, dir = box.home:VectorToWorldSpace(V3(0, 0, sc and 1 or -1)), cone = sc and 3.6 or 3.3,
					hz = sc and { 4, 9 } or { 6, 12 }, vz = { 8, 13 }, size = P.secretCut and box.W * (sc and 0.09 or 0.18) or 0.65, grav = 80, bounce = 0.3, spinMin = 3.1, spinMax = 9.4, material = glass and 'Glass' or 'SmoothPlastic', neon = glass,
					life = P.secretCut and (P.flash - land) or 2.9 }, 'slam')
			else
				-- (the egg: 6-8 chunks in the box's own colours, 0.12-0.2 of its width, thrown low off its rim; they rest on
				-- the pad until the pop)
				local cols = { th.Color, th.Accent, th.Third }
				self:spawn({ kind = 'cube', n = count, colors = cols, t0 = land, at = box.home * CF(0, 0.4, 0), ring = box.W * 0.5, dir = box.home:VectorToWorldSpace(V3(0, 0, -1)), cone = 4.2,
					hz = { 5, 10 }, vz = { 7, 11 }, size = box.W * 0.16, grav = 70, bounce = 0.3, spinMin = 3.1, spinMax = 9.4, life = math.max(0.5, P.pop[i] - land + 0.05), away = self.away }, 'slam')
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
		if P.premium then Cam.shake(self, w[1], 'pop', 0.12) end
		-- (28b: each shake lands with a small camera punch, and a few bits pop off the lid's seam)
		if P.egg and not P.reduced then
			Cam.punch(self, w[1] + w[4], -0.8 - 0.4 * wi, 0.04, 3.4, 0.7)
			for i, box in self.boxes do
				if (not P.multi or i == P.best or wi == #P.wobSpec) and w[1] + P.wobOff[i] < P.pop[i] - 0.1 then
					self:spawn({ kind = 'cube', n = P.multi and 1 or 2, colors = { P.theme.Color, P.theme.Accent }, t0 = w[1] + P.wobOff[i] + w[4], at = box.home * CF(0, box.seamY, 0), ring = box.W * 0.45,
						dir = box.home:VectorToWorldSpace(V3(0, 0, -1)), cone = 5.5, hz = { 2.5, 5 }, vz = { 6, 9 }, size = box.W * 0.06, grav = 60, bounce = 0.3, spinMin = 4, spinMax = 10, life = 1.1 }, 'slam')
				end
			end
		end
		-- (Rare and up: white twinkles on the box as it shakes)
		if P.egg and not P.prelude then
			for i, box in self.boxes do
				if (i == P.best or not P.multi) and P.ranks[i] >= 2 then
					for k = 1, 2 do
						self:at(w[1] + P.wobOff[i] + 0.05 * k, function()
							local at = (box.cf or box.home) * CF((M.hash(wi, k) - 0.5) * box.W * 0.8, box.topY * (0.3 + 0.6 * M.hash(k, wi)), -box.D * 0.52)
							self:emit(fx.glint, 1, at)
						end)
					end
				end
			end
		end
	end

	-- the pops (normal) and the lid blasts (premium)
	for i, box in self.boxes do
		local big = (not P.multi) or i == P.best
		self:at(P.pop[i], function()
			local mouth = box:mouth()
			self:emit(fx.core, 1, mouth)
			-- (a rainbow box pops bigger: x1.2 for a Legendary, x1.4 for a Mythic)
			local rb = Themes.Egg.Rainbow[P.rainbow and P.rainbow[i] or 0]
			if P.premium then self:emit(fx.lidBurst, P.n >= 5 and 8 or 30, mouth) else self:emit(fx.popBurst, (big and 12 or 6) * (rb and rb.pop or 1), mouth) end
			-- (the radial burst: a ring and a hot glow at the box, facing the camera)
			if fx.ringBurst and big then
				local face = CFrame.lookAt(mouth.Position, mouth.Position + (self.camCF and -self.camCF.LookVector or V3(0, 0, -1)))
				self:emit(fx.ringBurst, 1, face)
				self:emit(fx.popGlow, 1, face)
			end
		end, big)
		if not P.premium then
			Cam.shake(self, P.pop[i], 'pop', big and 0.3 or 0.15)
			if big and not P.reduced then Cam.punch(self, P.pop[i], -2.6, 0.04, 3, 0.7) end
		end
	end
	if P.premium then
		self:at(P.motes, function() fx.motes.Enabled = true; self:recount() end)
		self:at(P.dip[2] - 0.1, function() fx.motes.Enabled = false; self:recount() end, true)
		local box = self.boxes[P.best]
		-- (the dip's white crackles all over the crate, the only bright things with the swirl; CRITIC5)
		local nk = P.secretCut and 9 or 5
		for k = 0, nk - 1 do
			self:at(P.dip[1] + 0.05 + k * (P.dip[2] - P.dip[1] - 0.08) / nk, function()
				self:emit(fx.crackle, 2, box.home * CF((M.hash(k, 1) - 0.5) * box.W * 1.1, box.topY * (0.3 + M.hash(k, 2) * 0.8), (M.hash(k, 3) - 0.5) * box.D - box.D * 0.3))
			end)
		end
		Cam.shake(self, P.flash, 'blast', 0.7)
		Cam.punch(self, P.flash, 10, 0.12, 1.6, 0.9)
		self:at(P.flash, function()
			fx.pillarMotes.Parent.CFrame = self.anchor.CFrame:ToObjectSpace(box.home * CF(0, box.seamY, 0))
			fx.pillarMotes.Enabled = true
			self:recount()
		end, true)
		self:at(P.secretCut and P.accent[P.best] or P.flash + 1.5, function() fx.pillarMotes.Enabled = false; self:recount() end, true)
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
	local nConf = P.premium and (P.rank == 2 and 32 or P.rank == 3 and 36 or 48) or (P.egg and not P.summary and Themes.Egg.Confetti[P.rank]) or P.R.Confetti
	local hs = self.heroShot
	if nConf > 0 and hs then
		local t0 = P.premium and P.confetti or P.egg and (P.reveal or (P.fan and P.accent[P.best]) or P.pop[P.best]) + 0.05 or (P.accent[P.best] - 0.05)
		local cols = P.R.SlowMo and Themes.Rainbow or { th.Color, th.Accent, th.Third, rcol, WHITE }
		local eye, at = self:wp(hs[1]), self:wp(hs[2])
		local cam = CFrame.lookAt(eye, at)
		local dist = (at - eye).Magnitude
		local halfH = dist * math.tan(RAD(hs[3] / 2))
		local halfW = halfH * 16 / 9
		local guard = self:wordGuard(t0, 3.8)
		if P.egg then
			-- the egg: confetti falls from the top (copy_spec §9.4), in two side bands clear of the pair (the left one wider,
			-- the right one narrow beside the Power reel), flat rects and strips that flutter down ~25 % of the height per
			-- 0.3 s
			for _, b in { { -0.72, 0.24, 0.65 }, { 0.86, 0.12, 0.35 } } do
				for _, kind in { 'rect', 'strip' } do
					self:spawn({ kind = kind, n = nConf * b[3] / 2, colors = cols, t0 = t0 + (kind == 'strip' and 0.04 or 0), at = CF(cam * V3(b[1] * halfW, halfH + 1, -dist)),
						speed = { 2, 5 }, size = 0.75, rain = halfW * b[2], spread = 0.5, grav = 32, life = 2.2, accept = guard, tries = 10 }, 'confetti')
				end
			end
		end
		for _, sx in (P.egg and {} or { -1, 1 }) do
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
	-- (a Secret's prelude: the box freezes at shake 2's peak for 120 ms, hops twice the wrong way (straight up), then
	-- lifts off into the tear: Job:preludeBox)
	if P.prelude and P.freeze and t >= P.freeze[1] then return self:preludeBox(i, t) end
	-- (the Secret's box is done once the carousel's cut comes)
	if P.carousel and t >= P.carousel[1] then return self.park, 1, 1, { hidden = true, park = self.park } end
	local home = box.home
	local land, f0, ap = P.land[i], P.fall0[i], P.appear[i]
	if t < ap or (P.premium and t < f0) then return self.park, 1, 1, { hidden = true, park = self.park } end
	if t < land then
		local cf
		local sy = 1
		if t < f0 then
			-- the hang (28b: the anticipation before the drop): it pops in at the top of the frame glinting, lifts 0.4 and
			-- tilts back and forth (2.6 Hz), squeezing up a little just before it drops
			local u = (t - ap) / (f0 - ap)
			cf = home * CF(0, P.fallH + 0.4 * math.sin(math.min(1, u * 1.4) * PI / 2), 0) * ANG(0, RAD(10) * u, RAD(5) * math.sin((t - ap) * 2 * PI * 2.6))
			if P.egg then sy = 1 + 0.08 * M.c01((u - 0.7) / 0.3) end
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
	-- (28b: the egg's landing squash, the box ~0.76 of its height on the contact frame)
	local S = jelly and 0.45 or (P.premium and 0.38 or (1 - (Themes.Egg.Squash or 0.76)))
	local sy
	if tau < hs then sy = 1 - S
	else sy = 1 - S * (jelly and M.spring(tau - hs, 3.5, 0.2) or M.spring(tau - hs, 5, P.premium and 0.4 or 0.45)) end
	local yaw, roll, hop = 0, 0, 0
	for wi, w in P.wobSpec do
		local t0 = w[1] + P.wobOff[i] + (P.premium and (M.hash(i, wi) - 0.5) * 0.04 or 0)
		local q = t - t0
		if P.egg and w[4] then
			-- the egg shake (28b): a crouch (the anticipation), a hop with a left-right roll in the air (L-R-L), a squash as
			-- it lands (Reduced Motion: half the angles and hops)
			if q >= -0.08 and q < w[4] + 0.12 and t0 < P.pop[i] - 0.05 then
				local amp = (P.reduced and 0.5 or 1) * (P.multi and (0.85 + 0.3 * M.hash(i, wi + 5)) or 1)
				local ph = P.multi and M.hash(i, 9) * 0.5 or 0
				if q < 0 then
					sy *= 1 - 0.07 * math.sin((q + 0.08) / 0.08 * PI / 2)
				elseif q < w[4] then
					local u = q / w[4]
					local air = math.sin(u * PI)
					roll += RAD(w[2]) * amp * math.sin(u * PI) * math.sin(u * 2 * Themes.Egg.Swings * PI + ph)
					yaw += RAD(w[2] * 0.25) * amp * air * math.sin(u * 2 * Themes.Egg.Swings * PI + ph + 1.2)
					hop += w[3] * G * amp * air
					sy *= 1 + 0.05 * air
				else
					local v = (q - w[4]) / 0.12
					sy *= 1 - (1 - (Themes.Egg.ShakeSquash or 0.86)) * math.sin(v * PI) * (P.reduced and 0.5 or 1)
				end
			end
		elseif q >= 0 and q < 0.9 and t0 < P.pop[i] - 0.05 then
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
		-- the crouch: down to 0.85 in 0.12 s, then on to 0.81 at the pop, shivering faster and faster (not with Reduced
		-- Motion)
		local c0 = P.crouch[i]
		if t >= c0 and t < pop then
			local q = M.c01((t - c0) / math.max(0.05, pop - c0))
			sy *= 1 - (0.15 + 0.04 * q) * M.out(M.c01((t - c0) / 0.12), 2)
			if not P.reduced then roll += math.sin(t * 2 * PI * (12 + 10 * q)) * RAD(1.5) * M.c01((q - 0.25) / 0.5) end
		end
	elseif t >= P.dip[1] and t < pop then
		local u = (t - P.dip[1]) / (pop - P.dip[1])
		roll += math.sin(t * 90) * RAD(1.6) * u
		yaw += math.sin(t * 71) * RAD(1.1) * u
	end
	if t >= pop then sy *= 1 + 0.12 * M.spring(t - pop, 5, 0.4) end
	local sx = 1 / math.sqrt(sy)
	local cf
	if P.egg then
		-- (an egg rocks on the edge that stays down: the pivot is the bottom edge on the side it leans to)
		local px = (roll > 0 and -1 or 1) * box.W * 0.5
		cf = home * CF(0, hop, 0) * ANG(0, yaw, 0) * CF(px, 0, 0) * ANG(0, 0, roll) * CF(-px, 0, 0)
	else
		cf = home * CF(0, hop, 0) * ANG(0, yaw, roll)
	end
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
				-- (28b: the lid blasts off, spinning, up and to one side out of the top of the frame, away from the lens;
				-- gone within 0.5 s)
				local side = (M.hash(i, 77) > 0.5 and 1 or -1) * (P.multi and 3 or 5) * G * M.c01(q / 0.5)
				local up = (P.multi and 9 or 13) * G * M.out(M.c01(q / 0.5), 2)
				local back = 2.5 * G * M.c01(q / 0.5)
				local flip = RAD(900) * M.out(M.c01(q / 0.5), 2)
				local shrink = 1 - M.c01((q - 0.3) / 0.2)
				lid = { fly = CF(hinge.Position + home:VectorToWorldSpace(V3(side, up, back))) * hinge.Rotation * ANG(-flip, 0, flip * 0.35), scale = math.max(0.02, shrink) }
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
-- A Secret prelude's box from the freeze: held at the pose of the freeze's first frame; two straight-up hops (0.1 s,
-- 0.3 studs); from the cut, Quad In 6 studs up in 0.25 s, then on up into the tear, shrinking, gone by cut + 0.45.
-- (Reduced Motion: no freeze-hop; the box simply lifts.) Only the Secret's box goes; a batch's others stay.
function Job:preludeBox(i, t)
	local P, box = self.P, self.boxes[i]
	local secretBox = (not P.multi) or i == (P.secretAt or P.best)
	local held = self.heldPose and self.heldPose[i]
	if not held then
		self.heldPose = self.heldPose or {}
		local saved = self.P.freeze
		self.P.freeze = nil
		local cf, sx, sy = self:boxAt(i, P.reduced and saved[2] + 1 or saved[1])
		self.P.freeze = saved
		held = { cf, sx, sy }
		self.heldPose[i] = held
	end
	local cf, sx, sy = held[1], held[2], held[3]
	if t >= P.freeze[2] then
		cf, sx, sy = box.home, 1, 1
		if not P.reduced then
			for _, h in P.hops do
				local q = (t - h) / 0.1
				if q >= 0 and q < 1 then cf = cf * CF(0, 0.3 * G * math.sin(q * PI), 0) end
			end
		end
	end
	if secretBox and t >= P.lift then
		local q = t - P.lift
		local up = q < 0.25 and 6 * (q / 0.25) ^ 2 or 6 + 48 * (q - 0.25) + 60 * (q - 0.25) ^ 2
		local s = 1 - M.c01((q - 0.25) / 0.2)
		if s <= 0.02 then return self.park, 1, 1, { hidden = true, park = self.park } end
		cf = box.home * CF(0, up, 0)
		sx, sy = s, s
	end
	return cf, sx, sy, { open = 0 }
end
-- Pair i: hidden in its box; rises at its time (normal Back Out, premium Quint Out), ONE decelerating hero turn to a 3/4
-- view, then a slow idle; premium in silhouette until its accent; a multi's best scales up and steps forward.
function Job:pairAt(i, t)
	local P = self.P
	local pair = self.pairs[i]
	local box = self.boxes[i]
	if t < P.rise[i] then return nil end
	if P.carousel and i == P.best and t < P.dusk[1] then return self:secretMiddle(t) end
	if P.fan and self.fan then return self:fanAt(i, t) end
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
	local s
	if P.premium then
		s = M.lerp(0.55, 1, M.out(u, 3))
	else
		-- the egg's pop: the pair scales 0 -> 1.15 -> 1 in 0.3 s (Themes.Egg.Pop)
		local pk, pt = Themes.Egg.Pop[1], Themes.Egg.Pop[2]
		local q = tr / pt
		s = q < 0.6 and pk * M.out(q / 0.6, 2) or q < 1 and pk - (pk - 1) * M.smooth((q - 0.6) / 0.4) or 1
		s = math.max(0.02, s)
	end
	local spinU = tr / P.spinLen
	local yaw = RAD(-30) - (self.heroYaw or 0) + 2 * PI * P.spinTurns * (1 - (P.premium and M.out(spinU, 3) or M.out(spinU, 4)))
	local idle = math.max(0, tr - math.max(P.riseLen, P.spinLen))
	if P.secretCut and P.rings2 and i == P.best then
		-- the Secret's middle: the pair rises (Quint Out) in silhouette, turning 1.25 turns as it slows to its back
		-- toward us, floating; then it spins 1.5 turns with the second rings into its 3/4 view at the reveal; the hold's
		-- sway from there (CRITIC5: never still for 0.5 s)
		local q = M.inout(M.c01((t - P.rings2[1]) / (P.rings2[2] - P.rings2[1])))
		local mu = M.c01((t - P.rise[i]) / (P.rings2[1] - P.rise[i]))
		yaw = RAD(-30) + PI + 2.5 * PI * (1 - M.out(mu, 2)) + 3 * PI * q
		pos += V3(0, math.sin(math.max(0, t - P.rise[i]) * 2.6) * 0.3 * G * (1 - q), 0)
		idle = math.max(0, t - P.accent[i])
	elseif P.lux and i == P.best then
		-- 28b, a Legendary's or Mythic's single: the pair shoots up in silhouette spinning 1.25 turns and slows to its
		-- back toward us through the dusk dip, floating; then it spins 1.5 turns as the rings close in, into its 3/4
		-- view at the rarity flash
		local L = P.lux
		local q = M.inout(M.c01((t - L.spin[1]) / (L.spin[2] - L.spin[1])))
		local mu = M.c01((t - P.rise[i]) / (L.spin[1] - P.rise[i]))
		yaw = RAD(-30) + PI + 2.5 * PI * (1 - M.out(mu, 3)) + 2 * PI * L.turns * q
		pos += V3(0, math.sin(math.max(0, t - P.rise[i]) * 2.9) * 0.22 * G * (1 - q), 0)
		idle = math.max(0, t - P.accent[i])
	end
	-- the hold (28b): an idle turn (~18 deg/s, easing in) and a bob of ~3 % of the pair's height at 0.55 Hz, from the
	-- end of the hero turn
	local ease = M.smooth(M.c01(idle / 0.6))
	yaw += RAD(P.premium and 20 or 18) * math.max(0, idle - 0.3) * ease
	pos += V3(0, math.sin(idle * 2 * PI * 0.55) * 0.03 * pair.height * ease, 0)
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

-- 28b, the Secret's animated middle (copy_spec §1 beats 9-12), the true pair's path: the WHIP (it launches out of the
-- box past the lens, is a speck in the blue sky while the camera looks up, then flies back at the lens spinning); the
-- CAROUSEL (its slot on the ring of five candidates); the PICK (it stays in front while the others fly out); the TEASE
-- (back to us, it turns edge-on, shows its face for ~3 frames, turns back). A silhouette throughout but the face.
function Job:carouselBase(k, t)
	local P = self.P
	local box = self.boxes[P.best]
	local c0, c1 = P.carousel[1], P.carousel[2]
	local u = M.c01((t - c0) / (c1 - c0))
	-- (fast, then slowing: Quad Out over 2.5 turns, so its speed falls ~4x by three quarters of the way; the true pair
	-- comes round to the front)
	local th = -2 * PI * (P.carouselTrue - 1) / 5 - 2.5 * 2 * PI * (1 - u) ^ 2
	local phi = th + 2 * PI * (k - 1) / 5
	local R = self.carouselR
	-- (the ring rides a little higher than the hero pair's hover, against the sky above the roofs; it settles at the pick)
	local lift = 0.25 * self.pairs[P.best].width * (1 - M.smooth(M.c01((t - P.pick[1]) / 0.3)))
	local base = box.home * CF(math.sin(phi) * R, box.seamY + P.riseH + lift, R - math.cos(phi) * R)
	return base.Position, phi
end
function Job:secretMiddle(t)
	local P = self.P
	local i = P.best
	local pair, box = self.pairs[i], self.boxes[i]
	local home = box.home
	local w0, w1 = P.whip[1], P.whip[2]
	local yawRel, pos, s = RAD(-30) + PI, nil, 1
	local W = self.whip
	if t < w1 and W then
		local eye, dir = self:wp(W.eye), home:VectorToWorldSpace(W.dir)
		local la, sp = w0 + 0.2, w1 - 0.21
		if t < la then
			-- (out of the box and past the lens, above and left of it, spinning)
			local u = (t - w0) / (la - w0)
			local from = home.Position + V3(0, box.seamY * 0.6, 0)
			local to = eye + home:VectorToWorldSpace(V3(1.4, 1.6, 1.2))
			pos = from:Lerp(to, u * u)
			yawRel += 4 * PI * u
		elseif t < sp then
			-- (a speck high in the blue, drifting)
			local u = (t - la) / (sp - la)
			pos = eye + dir * 58 + home:VectorToWorldSpace(V3(2 - 4 * u, 1.5 * u, 0))
			yawRel += 1.5 * PI * u
		else
			-- (back at the lens, spinning 3 turns, filling the frame by the cut)
			local u = (t - sp) / (w1 - sp)
			pos = (eye + dir * 58):Lerp(eye + dir * (pair.height * 1.6 + 2), u * u)
			yawRel += 6 * PI * M.out(u, 2)
		end
		pos -= V3(0, (pair.base + pair.height * 0.5), 0)
	elseif t < P.pick[1] then
		local p, phi = self:carouselBase(P.carouselTrue, t)
		pos = p + V3(0, math.sin(t * 2.3) * 0.15 * G, 0)
		yawRel -= phi
	else
		pos = self:carouselBase(P.carouselTrue, t)
		local tq = M.c01((t - P.tease[1]) / (P.tease[2] - P.tease[1]))
		-- (the tease: back -> edge-on -> its 3/4 face (held ~3 frames) -> edge-on -> back)
		local turn = tq < 0.3 and M.inout(tq / 0.3) * 0.5 or tq < 0.42 and 0.5 + M.inout((tq - 0.3) / 0.12) * 0.5 or tq < 0.58 and 1 or tq < 0.7 and 1 - M.inout((tq - 0.58) / 0.12) * 0.5 or 0.5 - M.inout((tq - 0.7) / 0.3) * 0.5
		yawRel -= PI * turn
		self.teaseFace = tq > 0.4 and tq < 0.6
		pos += V3(0, math.sin(t * 2.3) * 0.15 * G, 0)
	end
	local yawCF = ANG(0, yawRel, 0)
	self.pairYaw = home.Rotation * yawCF
	pair.pos = pos + V3(0, (pair.base + pair.height * 0.5) * s, 0)
	return CF(pos) * home.Rotation * yawCF * ANG(RAD(-8), 0, 0), s
end
-- The carousel's other four (silhouettes, each with its own little bob): on the ring from the cut, flying out sideways
-- at the pick, gone by its end.
function Job:carouselAt(t)
	local P = self.P
	for k, c in self.cands do
		local on = t >= P.carousel[1] and t < P.pick[2]
		if on then
			local base, phi = self:carouselBase(k, math.min(t, P.pick[1] - 0.001))
			local pos = base + V3(0, math.sin(t * (2.0 + 0.41 * k) + k) * 0.15 * G, 0)
			if t >= P.pick[1] then
				local u = (t - P.pick[1]) / (P.pick[2] - P.pick[1])
				local out = self.boxes[P.best].home:VectorToWorldSpace(V3(math.sin(phi) >= 0 and 1 or -1, 0.15, 0.25))
				pos += out * 26 * u * u
			end
			c.actor:pose(CF(pos) * self.boxes[P.best].home.Rotation * ANG(0, RAD(-30) + PI - phi, 0) * ANG(RAD(-8), 0, 0), 1)
			c.actor:tint(C3(12, 12, 20), UnboxCinematic.CarouselLook == 'colour' and 0 or 1)
		elseif not c.parked then
			c.actor:pose(self.park, 0.3)
		end
		c.parked = not on
		local e = self.candEdges and self.candEdges[k]
		if e and e.Enabled ~= on then e.Enabled = on end
	end
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
	if P.n < 5 then
		if P.fan then
			-- (28b, a Buy 3: its line-up is the boxes' row gathered in, at the hover height)
			self.slots = {}
			for i = 1, P.n do
				local hm = P.homes[i]
				self.slots[i] = V3(hm.X * UnboxCinematic.Gather, hm.Y + self.boxes[i].seamY + P.riseH, hm.Z * 0.5 - 0.4)
			end
			self:fanLoop()
		end
		return
	end
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
	for j = 1, nb do slots[others[j]] = V3((j - (nb + 1) / 2) * sp, yB, 2.2) end
	local bw = self.pairs[P.best].width * 1.35
	for j = nb + 1, #others do
		local side = (j == nb + 1) and -1 or 1
		slots[others[j]] = V3(side * (bw * 0.5 + pw * 0.55 + 0.3), yF, -1.2)
	end
	slots[P.best] = V3(0, yF + 0.2, -2.6)
	self.slots, self.lineSp, self.lineW, self.lineY = slots, sp, (nb - 1) * sp + pw, { yF, yB, ph }
	self.backRow = {}
	for j = 1, nb do self.backRow[others[j]] = true end
	if P.fan then self:fanLoop() end
end
-- 28b, a Buy 3 / Buy 8 pair: up from its box (Quint Out, growing 0 -> 1.15 -> 1) onto the loop; round it, slowing
-- (Quad Out over 1.25 turns: the speed falls >= 3x), back to us; into its line-up slot; at its flip a half turn (Back
-- Out) into its 3/4 view as the light reaches it; the best, if a Legendary or better, steps forward with a 1.5-turn
-- spin; then the idle turn and bob
function Job:fanAt(i, t)
	local P = self.P
	local pair, box, F = self.pairs[i], self.boxes[i], self.fan
	local f0, f1 = P.fan[1], P.fan[2]
	local u = M.c01((t - f0) / (f1 - f0))
	local th = -1.25 * 2 * PI * (1 - u) ^ 2
	local function loopPos()
		local ph = F.phase[i] + th
		return self:wp(F.c + V3(F.A * math.sin(ph), 0.3 * math.sin(ph * 2 + i), -F.B * math.cos(ph)))
	end
	local slot = self:wp(self.slots[i])
	local start = box.home.Position + V3(0, box.seamY * 0.4, 0)
	local pos
	if t < f0 then
		local q = M.c01((t - P.rise[i]) / math.max(0.1, f0 - P.rise[i]))
		pos = start:Lerp(loopPos(), M.out(q, 5)) + V3(0, math.sin(q * PI) * 1.2 * G, 0)
	elseif t < f1 + 0.3 then
		pos = loopPos():Lerp(slot, M.smooth(M.c01((t - f1) / 0.3)))
	else
		pos = slot
	end
	local tr = t - P.rise[i]
	local pk, pt = Themes.Egg.Pop[1], Themes.Egg.Pop[2]
	local q = tr / pt
	local s = math.max(0.02, q < 0.6 and pk * M.out(q / 0.6, 2) or q < 1 and pk - (pk - 1) * M.smooth((q - 0.6) / 0.4) or 1)
	-- (each pair turns slowly on its own while it rides the loop, at its own rate)
	local yaw = RAD(-30) + PI + (t - P.rise[i]) * RAD(40 + 17 * (i % 3)) * (1 - M.c01((t - f1) / 0.3))
	if t >= P.flipAt[i] then yaw += PI * M.back(M.c01((t - P.flipAt[i]) / 0.3), 1.3) end
	if P.bestSpin and i == P.best and t >= P.bestSpin[1] then
		local bq = M.c01((t - P.bestSpin[1]) / (P.bestSpin[2] - P.bestSpin[1]))
		yaw += 3 * PI * M.inout(bq)
		s *= 1 + (P.n >= 5 and 0.35 or 0.25) * M.back(bq, 1.4)
		pos += self.O:VectorToWorldSpace(V3(0, 0.3 * M.c01(bq * 2), -1.2 * G * M.out(bq, 3)))
	elseif P.multi and i == P.best and t >= P.flipAt[i] then
		s *= 1 + (P.n >= 5 and 0.35 or 0.15) * M.back(M.c01((t - P.flipAt[i]) / 0.25), 1.4)
	end
	local idle = math.max(0, t - P.accent[i])
	local ease = M.smooth(M.c01(idle / 0.6))
	yaw += RAD(12 + 3 * (i % 4)) * math.max(0, idle - 0.3) * ease
	pos += V3(0, math.sin(idle * 2 * PI * (0.45 + 0.05 * (i % 5))) * 0.03 * pair.height * ease, 0)
	local yawCF = ANG(0, yaw, 0)
	if i == P.best then self.pairYaw = self.O.Rotation * yawCF end
	pair.pos = pos + V3(0, (pair.base + pair.height * 0.5) * s, 0)
	return CF(pos) * self.O.Rotation * yawCF * ANG(RAD(-8), 0, 0), s
end
-- 28b, a Buy 3 / Buy 8's fan: a flat loop round the line-up (stage space) the pairs revolve on before they settle
function Job:fanLoop()
	local P = self.P
	local cx, cy, cz, n = 0, 0, 0, 0
	local minX, maxX, pw = math.huge, -math.huge, 0
	for i, sl in self.slots do
		cx += sl.X; cy += sl.Y; cz += sl.Z; n += 1
		minX, maxX = math.min(minX, sl.X), math.max(maxX, sl.X)
		pw = math.max(pw, self.pairs[i].width)
	end
	local A = (maxX - minX) * 0.5 + pw * 0.45
	local phase = {}
	for j, i in P.order do phase[i] = 2 * PI * (j - 1) / P.n end
	self.fan = { c = V3(cx / n, cy / n + 0.5, cz / n), A = A, B = A * 0.32, phase = phase }
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
	if P.inworld then return World.frame(self, t) end
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
			-- the hero hold of a single: the background softens (FarIntensity 0.5 in 0.3 s), the pair in focus (CRITIC5:
			-- at most one set word legible next to it)
			local pr = self.pairs[P.best]
			local hq = (P.n == 1 and not P.prelude) and M.c01((t - P.accent[P.best] - 0.05) / 0.3) * (1 - M.c01((t - P.out) / 0.15)) or 0
			if self.dof and hq > 0.005 and pr and pr.pos then
				if not self.dof.Enabled then self.dof.Enabled = true end
				self.dof.FarIntensity = 0.5 * hq
				self.dof.FocusDistance = (pr.pos - cf.Position).Magnitude
				self.dof.InFocusRadius = math.max(4, pr.height)
			elseif self.dof and self.dof.Enabled then
				self.dof.Enabled = false
			end
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
		if box.rb and t >= P.appear[i] - 0.05 and t < P.pop[i] + 0.6 then Box.rainbow(box, t) end
		for _, e in { box.stars, box.aura } do
			local on = t >= P.appear[i] and t < P.pop[i]
			if e.Enabled ~= on then e.Enabled = on; self:recount() end
		end
		if box.mring then
			local on = t >= P.appear[i] and t < P.pop[i]
			local rc = (box.cf or box.home) * CF(0, box.topY * 0.42, 0) * ANG(RAD(-14), 0, RAD(8))
			box.mring:pose(rc, box.W * 0.82, on and 1 or 0, t * 2.4, 1)
		end
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
			if P.premium or P.fan or (P.lux and i == P.best) then
				local dark = 1 - M.c01((t - (P.flipAt and P.flipAt[i] + 0.06 or P.accent[i])) / 0.12)
				-- (the Secret's tease shows the true pair's face, lit, for ~3 frames)
				if self.teaseFace and i == P.best and P.tease and t < P.tease[2] then dark = 0 end
				if P.carousel and i == P.best and UnboxCinematic.CarouselLook == 'colour' and t >= P.carousel[1] and t < P.pick[1] then dark = 0 end
				pair.actor:tint(C3(12, 12, 20), dark)
			end
			local on = t >= P.accent[i] - ((P.premium or P.fan or (P.lux and i == P.best)) and 0 or 0.5) and t < P.out + 0.15
			if pair.fxOn ~= on then Pair.fx(pair, on); recount = true end
		else
			pair.actor:pose(self.park, 0.3)
		end
	end
	if recount then self:recount() end
	if self.cands then self:carouselAt(t) end
	if self.mysteryMarks then
		local on = t >= P.carousel[1] and t < P.pick[1]
		for _, bb in self.mysteryMarks do
			if bb.Enabled ~= on then bb.Enabled = on end
		end
	end
	-- (the Secret's silhouette outline: on as the pair rises, gone under the reveal's white)
	if self.silEdge then
		local on = t >= P.rise[P.best] and t < P.accent[P.best]
		if self.silEdge.Enabled ~= on then self.silEdge.Enabled = on end
		local tr = 1 - M.c01((t - P.rise[P.best]) / 0.15)
		if on and self.silEdge.OutlineTransparency ~= tr then self.silEdge.OutlineTransparency = tr end
	end
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
	if P.cue and t >= P.cue then
		-- (a Secret's prelude: a thin line of the box's own theme light leaks from the seam; it names no rarity; gone as
		-- the box lifts and shrinks into the tear, so no lit slab hangs where it was)
		a, col = (P.lift and t >= P.lift + 0.1) and 0 or 0.55, self.P.theme.Color:Lerp(WHITE, 0.35)
	end
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
	-- (the Secret's dark beats keep it at 0.2: from the cut until the slam, the warm dip, the dusk)
	if P.prelude and P.cutAt then rimA = M.lerp(rimA, 0.2, M.c01((t - P.cutAt) / 0.15)) end
	if P.secretCut then rimA = 0.2 + 0.8 * M.c01((t - P.land[1]) / 0.15) end
	if P.premium and t >= P.dip[1] and t < P.flash then rimA = M.lerp(1, 0.2, M.c01((t - P.dip[1]) / 0.2)) end
	if P.dusk and t >= P.dusk[1] and t < P.accent[P.best] then rimA = math.min(rimA, M.lerp(1, 0.2, M.c01((t - P.dusk[1]) / 0.14))) end
	-- (an egg's pad lip is the hood's pale tone, not the box's colour again; the Secret wears its theme)
	local rim = P.egg and C3(232, 236, 248) or ((P.premium and t >= P.flash) and th.Relit or th.Rim)
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
	if P.prelude and P.cutAt then lamp *= 1 - M.c01((t - P.cutAt) / 0.15) end
	if P.secretCut and t < P.land[1] then lamp = 0 end
	if P.premium and th.Id == 'Exclusive' and t >= P.flash and not self.coolLamps then
		-- (Exclusive: the relit stage gets a cool white key; the cyan rim is the rim light)
		self.coolLamps = true
		for _, l in self.lamps do
			l.color = C3(215, 235, 255)
			if l.light then
				l.light.Color = l.color
				l.light.Brightness = -1
			end
		end
	end
	-- (capped through the hold: the pair is lit by the look, not blown out by the lamps)
	local hq = M.c01((t - (P.accent[P.best] - 0.3)) / 0.5)
	lamp *= M.lerp(1, self.lightPair and 0.45 or 0.8, hq)
	for _, l in self.lamps do
		local hc = BLACK:Lerp(l.color, 0.15 + 0.85 * lamp)
		if l.light and math.abs(l.light.Brightness - 1.6 * lamp) > 1e-3 then l.light.Brightness = 1.6 * lamp end
		if l.head.Color ~= hc then l.head.Color = hc end
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
		local u = (t - P.land[i]) / (P.egg and 0.3 or 0.4)
		if u >= 0 and u <= 1 then
			local r = M.lerp(box.W * 0.45, P.egg and box.W or (P.premium and 14 or 7 * G) * (P.multi and 0.6 or 1), M.out(u, 4))
			ring:pose(box.home * CF(0, 0.1, 0), r, (1 - u) ^ 1.5, 0, M.lerp(1, 0.4, u))
		elseif u > 1 and not ring.off then
			ring.off = true
			ring:pose(box.home, 0, 0, 0)
		end
	end
	if self.rings then self:ringsAt(t) end
	if self.luxRings then self:luxRingsAt(t) end
	if self.tearParts then
		local open
		if P.prelude then
			open = P.tear and M.out(M.c01((t - P.tear) / 0.15), 3) or 0
		else
			open = 1 - M.c01((t - P.fall0[1]) / 0.1)
		end
		local pulse = 1 + 0.15 * math.sin(t * 3 * 2 * PI)
		if self.tearGlow then
			local on = open > 0.05
			if on and not self.tearGlowOn then self.tearGlowOn = true; self:emit(self.tearGlow, 1) end
			if not on and self.tearGlowOn then self.tearGlowOn = false; pcall(function() self.tearGlow:Clear() end) end
			if on then self.tearGlow.Size = NumberSequence.new(9 * G * open * pulse) end
		end
		for _, e in self.tearParts do
			local p = e[1]
			if open > 0.01 then
				p.CFrame = self.tearCF * CF(e[2].Position * V3(open, 1, 1)) * e[2].Rotation
				local sc = p.Name == 'TearGlow' and pulse or 1
				if not e.size then e.size = p.Size end
				p.Size = V3(e.size.X * open * sc, e.size.Y * sc, e.size.Z)
			elseif p.CFrame ~= self.park then
				p.CFrame = self.park
			end
		end
	end
	-- light pillars: open (Back Out 120 ms), hold, thin out
	for _, p in self.pillars do
		local box = self.boxes[p.i]
		local t0 = P.premium and P.lid[p.i] or P.egg and P.pop[p.i] or P.accent[p.i] - 0.2
		local u = t - t0
		local w = 0
		if u >= 0 then
			w = (P.premium and 5 or P.egg and box.W * 0.35 or 3.5) * M.back(u / 0.12, 1.8)
			local out0 = P.premium and (P.pillarOut[1] - t0) or P.egg and 0.3 or 0.9
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
-- The Secret's rings (copy_spec §4/§6): through the charge A tumbles a full turn in 2.4 s, B wobbles +-10 deg round the
-- crate's base, C spins fast (2.2 rev/s) on a diagonal, D stands huge and white behind; in the dip they fade and D
-- becomes the tight white swirl (a turn in 0.4 s); before the reveal three of them close in round the spinning pair
-- (white 3.9, the theme's 2.5, the rarity's 2.4 crate widths; Back Out in 4 frames, a tumble every 0.6 s) and burst
-- outward with the reveal's white.
function Job:ringsSecret(t)
	local P = self.P
	local box = self.boxes[P.best]
	local W0 = box.W
	local c0 = P.charge[1]
	local centre = (box.cf or box.home) * CF(0, box.topY * 0.55, 0)
	local cam = self.camCF
	local toCam = cam and (cam.Position - centre.Position) or V3(0, 0, -1)
	toCam = V3(toCam.X, 0, toCam.Z)
	toCam = toCam.Magnitude > 0.1 and toCam.Unit or V3(0, 0, -1)
	local face = CFrame.lookAt(centre.Position, centre.Position + toCam)
	-- (radii in crate widths; A and B a little under the reference's 1.9 / 2.7 widths so their near sides stay off
	-- the lens of the low close shot)
	local R = { 0.88, 1.08, 0.62, 1.85 }
	local pair = self.pairs[P.best]
	local r2on = P.rings2 and t >= P.rings2[1] and t < P.accent[P.best] + 0.12
	local neon = P.theme.Neon or { P.theme.Color, P.theme.Accent }
	for k, ring in self.rings do
		local alpha, radius, plane, theta, width = 0, 0, face, 0, 1
		if r2on and k <= 3 and pair.pos then
			-- the second rings, round the pair: three saturated rings scaling in from 1x to 3.9 / 2.5 / 2.4 widths in 4
			-- frames (Back Out), each tumbling about its own axis at a turn per 0.6 s
			local q = (t - P.rings2[1]) / 0.13
			local R2 = ({ 1.95, 1.25, 1.2 })[k]
			radius = R2 * W0 * M.lerp(0.5, 1, M.back(math.min(q, 1), 1.7))
			alpha = M.c01(q * 2)
			local col = neon[k] or rarityColor(P.rank)
			if P.rank >= 6 and k == 3 then col = Color3.fromHSV((t * 0.8) % 1, 0.85, 1) end
			ring:setColor(col, true)
			local b = t - P.accent[P.best]
			if b > 0 then
				radius *= M.lerp(1, 2.6, M.out(b / 0.1, 2))
				alpha *= 1 - M.c01(b / 0.12)
			end
			-- (about a turn per 0.6 s each, on its own axis and at its own rate: 1.0, 0.8, 1.3 turns per 0.6 s)
			local spin = (t - P.rings2[1]) / 0.6 * 2 * PI
			local base = CF(pair.pos) * CFrame.lookAt(V3(), toCam).Rotation
			if k == 1 then plane = base * ANG(RAD(15) + spin, 0, 0)
			elseif k == 2 then plane = base * ANG(0, 0, -spin * 0.8) * ANG(RAD(62), 0, 0)
			else plane = base * ANG(RAD(30), spin * 1.3, 0) end
			theta = spin
			-- (each at least 0.07 crate widths thick)
			width = ({ 0.85, 1, 2.1 })[k]
		elseif t >= P.ringsIn[math.min(k, 3)] and t < P.flash then
			local tin = P.ringsIn[math.min(k, 3)]
			local inA = M.back((t - tin) / 0.13, 1.7)
			alpha = M.c01((t - tin) / 0.07)
			radius = R[k] * W0 * math.max(0.3, inA)
			local tc = t - c0
			-- (the reference's orbits: flat ellipses round the crate, tilted 22-30 deg with the near side down so it
			-- crosses in front of the crate's foot, rolled against each other and precessing; their centres a little
			-- behind the crate, so the near arcs stay clear of the lens; the thin yellow one steeper and fast)
			if k == 1 then
				plane = (face - toCam * W0 * 0.25 + V3(0, 0.4, 0)) * ANG(0, 0, RAD(14 + 10 * math.sin(tc * 1.9))) * ANG(RAD(-28 - 5 * math.sin(tc * 2.3)), 0, 0)
				theta = tc * 1.5
			elseif k == 2 then
				plane = (face - toCam * W0 * 0.35 + V3(0, 0.2, 0)) * ANG(0, 0, RAD(-18 - 8 * math.sin(tc * 1.4))) * ANG(RAD(-22 - 4 * math.sin(tc * 1.7)), 0, 0)
				theta = -tc * 0.8
			elseif k == 3 then
				plane = face * ANG(0, 0, RAD(40) + tc * RAD(160)) * ANG(RAD(-50), 0, 0)
				theta = tc * 2.2 * 2 * PI
			else
				plane = (face - toCam * W0 * 1.2) * ANG(RAD(88), 0, RAD(4 * math.sin(tc * 0.5)))
				theta = tc * 0.1
			end
			-- the dip: the rings fade; D tightens into the white swirl round the crate
			if t >= P.dip[1] then
				local q = M.c01((t - P.dip[1]) / 0.12)
				if k == 4 then
					radius = M.lerp(radius, 0.65 * W0, q)
					plane = face * ANG(RAD(70), 0, RAD(15))
					theta = (t - P.dip[1]) / 0.4 * 2 * PI
					width = M.lerp(1, 0.6, q)
				else
					alpha *= 1 - q
				end
			end
		end
		ring:pose(plane, radius, alpha, theta, width)
	end
	-- the pillar behind the crate through the charge (0.38 crate widths)
	local bp = self.buildBeam
	local on = t >= P.buildPillar and t < P.dip[2]
	if bp.Enabled ~= on then bp.Enabled = on end
	if on then
		local u = M.c01((t - P.buildPillar) / 0.15) * (1 - M.c01((t - P.dip[1]) / 0.2))
		local acf = self.anchor.CFrame:Inverse()
		local base = self:w(V3(0, 0, 3))
		self.buildAtt[1].CFrame = acf * base
		self.buildAtt[2].CFrame = acf * base * CF(0, 70, 0)
		bp.Width0, bp.Width1 = W0 * 0.38 * u, W0 * 0.38 * u
	end
end
-- 28b, a Legendary's or Mythic's single: its rings scale in round the silhouette from 1x to 2.5-3.9 pair widths in 4
-- frames (Back Out) as the spin starts, each tumbling on its own axis at its own speed (no two alike), then burst out
-- past the frame under the rarity flash
function Job:luxRingsAt(t)
	local P = self.P
	local L = P.lux
	local pair = self.pairs[P.best]
	local on = pair.pos and t >= L.spin[1] and t < P.reveal + 0.12
	local cam = self.camCF
	local toCam = cam and (cam.Position - (pair.pos or cam.Position)) or V3(0, 0, -1)
	toCam = V3(toCam.X, 0, toCam.Z)
	toCam = toCam.Magnitude > 0.1 and toCam.Unit or V3(0, 0, -1)
	local pw = pair.width
	-- (radii in pair widths: a pair is wider than the reference's card, so 0.6 of the reference's 1.95/1.3/1.25)
	local R = { 1.17, 0.78, 0.75, 0.96 }
	local tilt = { 18, 64, 32, 80 }
	local rate = { 1.67, -1.3, 2.4, 0.35 } -- (turns a second, each its own)
	for k, ring in self.luxRings do
		if not on then
			ring:pose(CFrame.identity, 0, 0, 0, 1)
		else
			local q = (t - L.spin[1]) / 0.13
			local radius = R[k] * pw * L.size * M.lerp(0.5, 1, M.back(math.min(q, 1), 1.7))
			local alpha = M.c01(q * 2)
			local b = t - P.reveal
			if b > 0 then
				radius *= M.lerp(1, 2.6, M.out(b / 0.1, 2))
				alpha *= 1 - M.c01(b / 0.12)
			end
			local spin = (t - L.spin[1]) * rate[k] * 2 * PI * (L.level == 2 and 1.5 or 1)
			local base = CF(pair.pos) * CFrame.lookAt(V3(), toCam).Rotation
			local plane
			if k == 1 then plane = base * ANG(RAD(tilt[1]) + spin, 0, 0)
			elseif k == 2 then plane = base * ANG(0, 0, spin) * ANG(RAD(tilt[2]), 0, 0)
			elseif k == 3 then plane = base * ANG(RAD(tilt[3]), spin, RAD(20))
			else plane = base * ANG(RAD(tilt[4]), 0, RAD(8) + spin * 0.2) end
			ring:pose(plane, radius, alpha, spin, 1)
		end
	end
end
function Job:ringsAt(t)
	local P = self.P
	if P.secretCut then return self:ringsSecret(t) end
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
-- Start at t0 (a chain's segment that opens mid-sheet): the beats before it are past (only the essential ones fire).
function Job:seek(t0)
	for _, e in self.events do
		if not e.done and e[1] < t0 then
			e.done = true
			if e[3] then
				local ok, err = pcall(e[2])
				if not ok then warn('[UnboxCinematic] beat: ' .. tostring(err)) end
			end
		end
	end
	self.t, self.T = t0, t0
	local ok, err = pcall(self.frame, self, t0)
	if not ok then
		warn('[UnboxCinematic] frame: ' .. tostring(err))
		self:finish()
	end
end
-- A tap: to the reveal, then to the end (a chain's segment hands the tap to its chain).
function Job:skip()
	if self.Done then return end
	if self.onSkip then return self.onSkip() end
	self:doSkip()
end
function Job:doSkip()
	if self.Done then return end
	local P = self.P
	if P.inworld and not P.prelude then
		-- in the world: a tap before the reveal jumps to it (no wash it jumped over); in the hold it closes now, faster
		if self.t < P.skipTo - 0.05 then
			self.skipTo = P.skipTo
			for _, list in { P.flashes, P.soft } do
				for _, f in list do
					if f[1] > self.t and f[1] < P.skipTo + 0.05 then f[2] = 0 end
				end
			end
		elseif self.t < P.out then
			P.out = self.t
			self.closeLen = Themes.World.Close[2]
			P.done = P.out + self.closeLen
		end
		return
	end
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
-- handover: a chain's segment ending into the next one (the camera, the Lighting and the controls stay as they are: the
-- next segment takes them over in the same frame; only this segment's own things go)
function Job:finish(handover)
	if self.Done then return end
	self.Done = true
	if self.bound then
		pcall(function() RunService:UnbindFromRenderStep(self.bindName) end)
		self.bound = false
	end
	for _, c in self.conns do pcall(function() c:Disconnect() end) end
	table.clear(self.conns)
	if not handover then self:restoreCamera() end
	pcall(Look.restore, self, handover)
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

-- One job: builds the set, the boxes, the pairs, the effects, the camera, the look and the words for plan P, and plays it
-- (bound to the render step unless opts.manual).
local function newJob(opts, P)
	local player = Players.LocalPlayer
	local job = setmetatable({
		P = P, Plan = P, t = 0, T = 0, Done = false, conns = {}, emits = {}, emitterList = {}, events = {}, updaters = {},
		cap = UnboxCinematic.Caps[P.tier] or 80, onDone = opts.onDone, onSkip = opts.onSkip, contLive = 0, peak = 0, pairs = {}, boxes = {},
		shakes = {}, punches = {}, kicks = {}, inherit = opts.inherit,
	}, Job)
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
	if opts.inherit then job.camSaved = opts.inherit.camSaved else job:captureCamera() end
	local ok, err = pcall(function()
		job.folder = Instance.new('Folder')
		job.folder.Name = 'HoodUnboxStage'
		job.folder.Parent = workspace
		if P.inworld then
			-- (in the world: no set; the rig is placed from the player's camera, which is held where it is)
			World.place(job)
			World.build(job)
			job.bits = Bits.new(job.folder, job.park, World.floorAt(job))
		else
			Stage.build(job, (job.P.premium) and 'secret' or 'egg')
			job.padTint = job.folder:FindFirstChild('Pad')
			job.bits = Bits.new(job.folder, job.park, Stage.floorAt(job))
		end
		for i = 1, P.n do job.boxes[i] = Box.new(job, i) end
		for i, entry in P.list do job.pairs[i] = Pair.new(job, i, entry) end
		if P.inworld then
			-- each pair's place (its box's middle) and its fit; the boxes' ghosts (a Buy 8's best only)
			World.fitPairs(job)
			for i, box in job.boxes do
				if P.n <= 4 or i == P.best then World.ghost(job, box) end
			end
			if P.prelude then World.tear(job) end
		end
		-- (the Secret's carousel: the four other candidates from the box's odds row, real pairs, in silhouette)
		if P.carouselIds then
			job.cands = {}
			local wmax = job.pairs[P.best].width
			for k, id in P.carouselIds do
				if k ~= P.carouselTrue then
					local c = Pair.new(job, 100 + k, { Shoe = id, New = false, Count = 1 })
					job.cands[k] = c
					wmax = math.max(wmax, c.width)
				end
			end
			job.carouselR = 2.1 * wmax
			-- ('mystery': a "?" over each of the five while they revolve)
			if UnboxCinematic.CarouselLook == 'mystery' then
				job.mysteryMarks = {}
				local all = { [P.carouselTrue] = job.pairs[P.best] }
				for k, c in job.cands do all[k] = c end
				for k, c in all do
					local bb = Instance.new('BillboardGui')
					bb.Name = 'MysteryMark'
					bb.Size = UDim2.fromScale(2.4, 2.4)
					bb.StudsOffsetWorldSpace = V3(0, c.base + c.height + 1.4, 0)
					bb.AlwaysOnTop = true
					bb.LightInfluence = 0
					bb.Enabled = false
					local l = label(bb, { Name = 'Mark', Role = 'heading', Text = '?', TextSize = 48, Size = UDim2.fromScale(1, 1), ZIndex = 2 })
					l.TextScaled = true
					fadeText(l, 1)
					local root = c.model.PrimaryPart or c.actor.parts[1]
					bb.Adornee = root
					bb.Parent = root
					job.mysteryMarks[k] = bb
				end
			end
		end
		-- a light pair (white, yellow, pale) gets a softer hero light so its laces and panels don't clip to white
		local pb = job.pairs[P.best]
		job.lightPair = pb.albedo > UnboxCinematic.LightAlbedo or pb.brightShare > 0.3
		-- (and a dark pair (navy, black, deep purple) on a night stage gets a rarity glow behind it and a warm rim)
		job.darkPair = not job.lightPair and pb.albedo < UnboxCinematic.DarkAlbedo
		-- the theme's signatures first (some set flags the effects read), then the effects, the camera, the look
		local th = P.theme
		-- (an egg plays only the landing and the pop: the arrivals (comets, nightfall) belong to the crazy sheet)
		-- (the Secret's sheet has no ray fans: copy_spec §9.4 cuts the god-ray starbursts)
		local NO_RAYS = { prismFan = true, heavenRays = true }
		-- (in the world: no theme signatures; the box, the pair and the rays carry it)
		for _, list in (P.inworld and {} or { P.premium and th.Arrive or {}, th.Land, th.Open, P.premium and th.Charge or {}, P.premium and th.Dip or {} }) do
			for _, name in list do
				local fn = not (P.secretCut and NO_RAYS[name]) and Sig[name]
				if fn then
					for i = 1, P.n do fn(job, i) end
				end
			end
		end
		if P.inworld then
			World.effects(job)
			job.onClose, job.closeTarget = opts.onClose, opts.closeTarget
		else
			Build.effects(job)
			job:lineup()
			Cam.build(job)
		end
		-- a single's posters frame the pair in the hero shot, between it and the confetti lanes at the frame's edges
		if P.n == 1 and job.heroShot then
			local cf, fov = Cam.at(job, (P.premium and P.confetti or P.accent[P.best]) + 0.8)
			local d = (job:wp(job.heroShot[2]) - cf.Position).Magnitude
			Stage.framePosters(job, cf, fov, viewAspect(), pb.width * 0.5 / (d * math.tan(RAD(fov / 2)) * viewAspect()))
		end
		Look.save(job)
		Look.build(job)
		if job.gui then
			if P.inworld then World.words(job) else Words.build(job) end
		end
		if P.inworld then World.beats(job) else job:beats() end
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
	if not opts.noControls then
		job.controls = controls()
		if job.controls then job.disabledControls = pcall(function() job.controls:Disable() end) end
	end
	pcall(function()
		local UIS = game:GetService('UserInputService')
		table.insert(job.conns, UIS.InputBegan:Connect(function(input, processed)
			if processed then return end
			local kc = input.KeyCode
			if kc == Enum.KeyCode.Space or kc == Enum.KeyCode.Return or kc == Enum.KeyCode.E or kc == Enum.KeyCode.ButtonA then job:skip() end
		end))
	end)
	-- (a dormant segment is built ahead and starts when its chain hands over: Chain)
	if opts.dormant then return job end
	if (P.start or 0) > 0 then job:seek(P.start) else job:frame(0) end
	if not opts.manual then
		job.bindName = 'HoodUnboxCinematic'
		RunService:BindToRenderStep(job.bindName, Enum.RenderPriority.Camera.Value + 1, function(dt) job:step(dt) end)
		job.bound = true
		task.delay(P.total + 3, function() if not job.Done then job:finish() end end)
	end
	return job
end

---------------------------------------------------------------------------------------------- the Secret chain
-- Plays a Secret's segments (UnboxCinematic._secret) one after another, each its own job, on one clock. The prelude ->
-- crazy seam has no black and no white (copy_spec §9.1 "The Secret CUT"): the prelude itself darkens to the deep-blue
-- sky, tilts up and lifts the box into the tear; the crazy sheet (built ahead, at the prelude's freeze, and dormant
-- until then) takes over in the same frame from the same camera and the same light, at its telegraph beat. The world
-- (camera, Lighting, controls) is saved once, by the first segment, and put back once, by the last; a handover only
-- drops the segment's own things. A batch's summary follows the crazy sheet through a short black dip. A tap in the
-- prelude goes straight to the Secret's reveal.
local Chain = {}
local CHAIN_FIELDS = { folder = true, pairs = true, boxes = true, bitList = true }
Chain.__index = function(self, k)
	local v = Chain[k]
	if v ~= nil then return v end
	if CHAIN_FIELDS[k] then
		local job = rawget(self, 'job')
		if not job then return nil end
		if k == 'pairs' and rawget(self, 'seg') and self.seg.kind == 'crazy' then return { [self.P.best] = job.pairs[1] } end
		return job[k]
	end
	return nil
end
function Chain.new(opts, P)
	local self = setmetatable({ P = P, Plan = P, t = 0, T = 0, Done = false, onDone = opts.onDone, peak = 0, k = 0, opts = opts }, Chain)
	local player = Players.LocalPlayer
	self.gui = opts.gui
	if not self.gui then
		local pg = player and player:FindFirstChild('PlayerGui')
		if pg then
			local g = Instance.new('ScreenGui')
			g.Name = 'HoodUnboxCinematic'
			g.ResetOnSpawn = false
			g.IgnoreGuiInset = true
			g.DisplayOrder = 9
			g.Parent = pg
			self.gui, self.ownGui = g, true
		end
	end
	if self.gui then
		local root = self.gui:FindFirstChild('Root') or self.gui
		local b = Instance.new('Frame')
		b.Name = 'ChainDip'
		b.BorderSizePixel = 0
		b.BackgroundColor3 = BLACK
		b.BackgroundTransparency = 1
		b.Position = UDim2.fromOffset(-140, -140)
		b.Size = UDim2.new(1, 280, 1, 280)
		b.ZIndex = 60
		b.Parent = root
		self.black = b
	end
	-- (the chain holds the controls for its whole run)
	self.controls = controls()
	if self.controls then self.disabledControls = pcall(function() self.controls:Disable() end) end
	self:enter(1)
	if self.Done then return self end
	if not opts.manual then
		self.bindName = 'HoodUnboxCinematic'
		RunService:BindToRenderStep(self.bindName, Enum.RenderPriority.Camera.Value + 1, function(dt) self:step(dt) end)
		self.bound = true
		task.delay(P.total + 4, function() if not self.Done then self:finish() end end)
	end
	return self
end
-- Segment k's job: the first saves the world; the later ones inherit it (built dormant, started by enter).
function Chain:build(k)
	local seg = self.P.segments[k]
	return newJob({ gui = self.gui, manual = true, stageAt = self.opts.stageAt, onSkip = function() self:skip() end, inherit = k > 1 and self.world or nil, dormant = k > 1, noControls = true }, seg.plan)
end
function Chain:enter(k)
	local seg = self.P.segments[k]
	local job = (self.pending and self.pending.k == k) and self.pending.job or self:build(k)
	self.pending = nil
	self.k, self.seg, self.job = k, seg, job
	self.segAt = self.t + (seg.gap or 0)
	if job.Failed then
		if k == 1 then self.Failed = true end
		return self:finish()
	end
	if k == 1 then
		-- (the world as it was, kept by the chain for every later segment and the last restore)
		local s = job.saved
		self.world = { camSaved = job.camSaved, ownAtm = job.ownAtm, saved = s and { light = table.clone(s.light), atm = s.atm and { inst = s.atm.inst, v = table.clone(s.atm.v) }, sky = s.sky and table.clone(s.sky), rays = s.rays and table.clone(s.rays), clouds = s.clouds and table.clone(s.clouds), blooms = s.blooms } }
	else
		job:seek(seg.t0)
	end
end
function Chain:step(dt)
	if self.Done then return end
	dt = math.clamp(dt or 0, 0, 0.1)
	local seg, job = self.seg, self.job
	local t = self.t + dt
	if t < self.segAt then
		self.t = t -- (a black hold before a segment opens)
	else
		job:step(math.max(0, t - math.max(self.t, self.segAt)))
		self.t = self.segAt + (job.t - seg.t0)
	end
	self.T = self.t
	self.peak = math.max(self.peak, job.peak or 0)
	-- the next segment is built ahead, at the prelude's freeze (the hitch hides in the freeze)
	local nextK = self.k + 1
	if seg.kind == 'prelude' and not self.pending and nextK <= #self.P.segments and job.t >= (seg.plan.freeze and seg.plan.freeze[1] or seg.t1 - 0.4) then
		self.pending = { k = nextK, job = self:build(nextK) }
	end
	if self.cutNow or job.Done or job.t >= seg.t1 - 1e-6 then
		self.cutNow = false
		local more = nextK <= #self.P.segments
		if more and self.pending and self.pending.job.Failed then more = false end
		if not job.Done then job:finish(more) end
		if more and not self.Done then
			self:enter(nextK)
			if self.Done then return end
			if self.skipNext then
				-- (a tap in the prelude: straight to the Secret's reveal)
				self.skipNext = false
				self.segAt = self.t
				self.job:doSkip()
			end
			self.job:step(0)
		else
			return self:finish()
		end
	end
	self:dark()
end
-- The black dip between the crazy sheet and a batch's summary (nothing at the prelude's seam).
function Chain:dark()
	if not self.black then return end
	local seg, job, t = self.seg, self.job, self.t
	local a = 0
	if seg.kind ~= 'prelude' then
		if t < self.segAt then
			a = 1
		elseif seg.kind == 'summary' then
			a = 1 - M.c01((t - self.segAt) / 0.2)
		end
		if self.k < #self.P.segments then a = math.max(a, M.c01((job.t - (seg.t1 - 0.15)) / 0.15)) end
	end
	local tr = 1 - a
	if self.black.BackgroundTransparency ~= tr then self.black.BackgroundTransparency = tr end
end
function Chain:skip()
	if self.Done then return end
	if self.seg.kind == 'prelude' then
		self.cutNow, self.skipNext = true, true
	else
		self.job:doSkip()
	end
end
function Chain:finish()
	if self.Done then return end
	self.Done = true
	if self.bound then
		pcall(function() RunService:UnbindFromRenderStep(self.bindName) end)
		self.bound = false
	end
	if self.pending and not self.pending.job.Done then self.pending.job:finish(true) end
	if self.job and not self.job.Done then self.job:finish() end
	if self.controls and self.disabledControls then pcall(function() self.controls:Enable() end) end
	if self.black then self.black:Destroy() end
	if self.ownGui and self.gui then self.gui:Destroy() end
	self.black = nil
	if current == self then current = nil end
	if self.onDone then task.spawn(self.onDone, self) end
end

function UnboxCinematic.play(info, opts)
	opts = opts or {}
	if current and not current.Done then current:finish() end
	local player = Players.LocalPlayer
	local reduced = opts.reduced or reducedFor(player)
	local P = UnboxCinematic.plan(info, { tier = opts.tier, player = player, reduced = reduced })
	local job = P.secret and Chain.new(opts, P) or newJob(opts, P)
	if not job.Done then current = job end
	return job
end

UnboxCinematic._Job, UnboxCinematic._M = Job, M
if World then
	World.install({
		Box = Box, Pair = Pair, Look = Look, BoxModels = BoxModels, ShoeModels = ShoeModels, rarityColor = rarityColor, rarityRow = rarityRow,
		shoeDef = shoeDef, oneIn = oneIn, label = label, fadeText = fadeText, frame = frame, gradient = gradient,
	})
end
return UnboxCinematic
