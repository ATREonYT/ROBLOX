--!strict
-- CLOUT maths (Config/Social). Pure functions, no Instances: the server and the app both use them, and
-- tools/tests/test_social_rules.py runs them under Lua 5.4 (balance sim: how long 1K / 10K / 100K / 1M take).
-- Randomness is passed IN (rolls in 0..1) so the server owns the dice and tests are repeatable.
local Social = require(script.Parent.Parent.Config.Social)

local SocialRules = {}

local function clamp(x: number, a: number, b: number): number
	if x < a then
		return a
	elseif x > b then
		return b
	end
	return x
end

local function lerp(a: number, b: number, t: number): number
	return a + (b - a) * t
end

---------------------------------------------------------------- dice
-- Deterministic 0..1 from an integer seed and a stream index (same in Luau and Lua 5.4; no bit ops).
function SocialRules.rand(seed: number, n: number): number
	local x = (math.floor(seed) * 7919 + math.floor(n) * 104729 + 1013904223) % 2147483647
	for _ = 1, 3 do
		x = (x * 48271) % 2147483647
	end
	return x / 2147483647
end

---------------------------------------------------------------- display
-- 950 -> "950", 1234 -> "1.2K", 12345 -> "12.3K", 123456 -> "123K", 1234567 -> "1.2M"
function SocialRules.short(n: number): string
	n = math.floor(n or 0)
	local neg = n < 0
	n = math.abs(n)
	local s
	if n < 1000 then
		s = tostring(n)
	elseif n < 100000 then
		s = string.format("%.1fK", math.floor(n / 100) / 10)
	elseif n < 1000000 then
		s = string.format("%dK", math.floor(n / 1000))
	elseif n < 100000000 then
		s = string.format("%.1fM", math.floor(n / 100000) / 10)
	else
		s = string.format("%dM", math.floor(n / 1000000))
	end
	s = string.gsub(s, "%.0([KM])", "%1")
	if neg then
		s = "-" .. s
	end
	return s
end

function SocialRules.tier(followers: number): any
	local best = Social.Tiers[1]
	for _, t in Social.Tiers do
		if followers >= t.min then
			best = t
		end
	end
	return best
end

function SocialRules.total(acc: any): number
	return math.max(0, math.floor((acc.Real or 0) + (acc.Bots or 0)))
end

function SocialRules.botShare(acc: any): number
	local t = SocialRules.total(acc)
	if t <= 0 then
		return 0
	end
	return (acc.Bots or 0) / t
end

-- milestone entries crossed going from `old` to `new` real+bot followers that aren't in `done` yet
function SocialRules.milestones(old: number, new: number, done: { [string]: any }?): { any }
	local out = {}
	for _, m in Social.Milestones do
		if new >= m.at and old < m.at and not (done and done[tostring(m.at)]) then
			table.insert(out, m)
		end
	end
	return out
end

function SocialRules.verified(acc: any): boolean
	return (acc.Real or 0) >= Social.Unlock.VerifiedFollowers and SocialRules.botShare(acc) <= Social.Unlock.VerifiedMaxBotShare
end

---------------------------------------------------------------- the daily market
-- day = the in-game day number on this server, salt = a per-server number. prev = yesterday's Demand table.
-- Returns { day, mood, moodLabel, trendSpot, trendFormat, demand = {topicId = x} }
function SocialRules.market(day: number, salt: number, prev: { [string]: number }?): any
	local D = Social.Day
	local seed = day * 131 + salt
	local mood = lerp(D.MoodMin, D.MoodMax, SocialRules.rand(seed, 1))
	local spots = {}
	for _, s in Social.Spots do
		if s.id ~= "Ends" then
			table.insert(spots, s.id)
		end
	end
	local trendSpot = spots[1 + math.floor(SocialRules.rand(seed, 2) * #spots) % #spots]
	local formats = { "CarFlex", "FitCheck", "Spot", "Collab" }
	local trendFormat = formats[1 + math.floor(SocialRules.rand(seed, 3) * #formats) % #formats]
	local demand = {}
	for i, t in Social.CourseTopics do
		local last = (prev and prev[t.id]) or t.base
		local step = (SocialRules.rand(seed, 10 + i) * 2 - 1) * D.DemandStep
		-- pull gently back towards the topic's base so nothing stays dead for days
		local v = last + step + (t.base - last) * 0.25
		demand[t.id] = math.floor(clamp(v, D.DemandMin, D.DemandMax) * 100 + 0.5) / 100
	end
	local label, sub = "Normal", ""
	for _, m in Social.MoodLabels do
		if mood >= m[1] then
			label, sub = m[2], m[3]
		end
	end
	return {
		day = day,
		mood = math.floor(mood * 100 + 0.5) / 100,
		moodLabel = label,
		moodText = sub,
		trendSpot = trendSpot,
		trendFormat = trendFormat,
		demand = demand,
	}
end

---------------------------------------------------------------- one post
-- What the shot had. Every field is decided by the server except framing (client hint, clamped).
-- shot = { spot = id?, phase = "Day"|..., carFlex = number?, format = id, collab = n, framing = 0..1,
--          newSpotToday, repeatSpot, recentPosts = posts in the fatigue window, sponsored, verified, market }
function SocialRules.quality(shot: any): (number, { any })
	local P = Social.Post
	local spot = Social.spot(shot.spot)
	local parts = {}
	local q = spot.score
	table.insert(parts, { label = spot.label, mult = spot.score })
	local light = (spot.light and spot.light[shot.phase or ""]) or 1
	if light ~= 1 then
		q *= light
		local name = (shot.phase or "") .. " light"
		if shot.phase == "Evening" then
			name = "Golden hour"
		elseif shot.phase == "Night" then
			name = "Night lights"
		end
		table.insert(parts, { label = name, mult = light })
	end
	if shot.carFlex and shot.carFlex > 0 then
		q *= shot.carFlex
		table.insert(parts, { label = "Car in the shot", mult = shot.carFlex })
	elseif spot.needsCar then
		q *= P.NoCarAtCarSpot
		table.insert(parts, { label = "No car at a car meet", mult = P.NoCarAtCarSpot })
	end
	local collab = math.min(shot.collab or 0, P.CollabMax)
	if collab > 0 then
		local m = 1 + P.CollabPer * collab
		q *= m
		table.insert(parts, { label = "Collab x" .. collab, mult = m })
	end
	local framing = lerp(P.FramingMin, P.FramingMax, clamp(tonumber(shot.framing) or 0.5, 0, 1))
	q *= framing
	table.insert(parts, { label = "Framing", mult = framing })
	if shot.newSpotToday then
		q *= P.NewSpotToday
		table.insert(parts, { label = "Fresh spot today", mult = P.NewSpotToday })
	end
	if shot.repeatSpot then
		q *= P.RepeatSpotPenalty
		table.insert(parts, { label = "Same spot again", mult = P.RepeatSpotPenalty })
	end
	return q, parts
end

-- Reach-side multipliers that aren't about the picture (trend, mood, fatigue, ads, check).
function SocialRules.reachMult(shot: any): (number, { any })
	local P = Social.Post
	local m, parts = 1, {}
	local mk = shot.market
	if mk then
		m *= mk.mood
		table.insert(parts, { label = "Algorithm: " .. tostring(mk.moodLabel), mult = mk.mood })
		if shot.spot and shot.spot == mk.trendSpot then
			m *= P.TrendSpot
			table.insert(parts, { label = "Trending spot", mult = P.TrendSpot })
		end
		if shot.format and shot.format == mk.trendFormat then
			m *= P.TrendFormat
			table.insert(parts, { label = "Trending format", mult = P.TrendFormat })
		end
	end
	local recent = math.max(0, (shot.recentPosts or 0) - P.FatigueFree)
	if recent > 0 then
		local f = P.FatiguePer ^ recent
		m *= f
		table.insert(parts, { label = "Posting a lot", mult = f })
	end
	if shot.sponsored then
		m *= P.Sponsored
		table.insert(parts, { label = "Sponsored", mult = P.Sponsored })
	end
	if shot.verified then
		m *= P.Verified
		table.insert(parts, { label = "Verified", mult = P.Verified })
	end
	return m, parts
end

-- The viral lottery: luck (0..1) -> (multiplier, "viral"|"hot"|"flop"|"normal"); spread (0..1) picks the size.
function SocialRules.luck(quality: number, luck: number, spread: number): (number, string)
	local P = Social.Post
	local viral = math.min(P.ViralChance + P.ViralQualityBonus * math.max(0, quality - 1), P.ViralChanceMax)
	if luck < viral then
		-- skewed towards the small end of the range
		return lerp(P.ViralMin, P.ViralMax, spread * spread), "viral"
	elseif luck < viral + P.HotChance then
		return lerp(P.HotMin, P.HotMax, spread), "hot"
	elseif luck > 1 - P.FlopChance then
		return P.FlopMult, "flop"
	end
	return 1, "normal"
end

-- acc = { Real, Bots }. rolls = { luck, spread, noise } each 0..1.
-- Returns { views, likes, comments, shares, gained, quality, outcome, luckMult, parts, xp, fund, likeRate }
function SocialRules.post(acc: any, shot: any, rolls: any): any
	local P = Social.Post
	local R = math.max(0, acc.Real or 0)
	local B = math.max(0, acc.Bots or 0)
	local q, parts = SocialRules.quality(shot)
	local rm, rparts = SocialRules.reachMult(shot)
	for _, p in rparts do
		table.insert(parts, p)
	end
	local luckMult, outcome = SocialRules.luck(q, rolls.luck or 0.5, rolls.spread or 0.5)
	local noise = 1 + ((rolls.noise or 0.5) * 2 - 1) * P.Noise

	local seeRate = P.SeeRate * (1 + R / P.SeeRateFalloff) ^ -0.35
	local seen = R * seeRate * math.min(1.3, q ^ 0.5) * rm * noise
	local explore = P.ExploreBase * (q ^ P.QualityPower) * (1 + (R / 1000) ^ P.ExploreGrowth) * rm * luckMult * noise
	-- a viral post also reaches more of your own followers
	if outcome == "viral" then
		seen *= 1.6
	end
	local views = math.floor(seen + explore)

	local proof = 1 + Social.Bots.SocialProof * math.log(1 + B / math.max(R, 50), 10)
	local followRate = P.FollowRate * math.min(q, 2.2) * proof * (1 + R / 1000) ^ -P.FollowFalloff
	local gained = math.floor(explore * followRate)

	local t = clamp(math.log(1 + R, 10) / 6, 0, 1)
	local likeRate = lerp(P.LikeRateSmall, P.LikeRateBig, t) * math.min(1.25, q ^ 0.35)
	local likes = math.floor(views * likeRate)
	local comments = math.floor(likes * P.CommentRate)
	local shares = math.floor(views * P.ShareRate)
	if outcome == "viral" then
		shares *= 3
	end

	local xp = math.min(P.XPMax, math.floor(P.XPBase + P.XPPerQuality * q))
	if shot.firstEverAtSpot then
		xp += P.XPNewSpot
	end
	if outcome == "viral" then
		xp += P.XPViral
	end
	local fund = 0
	if R >= Social.Unlock.FundFollowers then
		fund = math.min(P.FundMax, math.floor(views / 1000 * P.FundPer1K))
	end
	return {
		views = views,
		likes = likes,
		comments = comments,
		shares = shares,
		gained = gained,
		quality = math.floor(q * 100 + 0.5) / 100,
		outcome = outcome,
		luckMult = math.floor(luckMult * 10 + 0.5) / 10,
		parts = parts,
		xp = xp,
		fund = fund,
		likeRate = likeRate,
	}
end

-- engagement rate as brands see it: likes on your last posts / TOTAL followers (bots drag it down)
function SocialRules.engagement(acc: any, recentLikes: number?): number
	local t = SocialRules.total(acc)
	if t <= 0 then
		return 0
	end
	local likes = recentLikes or 0
	return likes / t
end

---------------------------------------------------------------- brand deals
function SocialRules.dealPay(acc: any, brand: any, mood: number, engagement: number, roll: number): number
	local D = Social.Deals
	local R = math.max(0, acc.Real or 0)
	local pay = D.Pay * (R / 1000) ^ D.PayPower * (brand.mult or 1) * (0.85 + 0.3 * roll) * (0.85 + 0.15 * mood)
	if engagement >= D.EngagementGood then
		pay *= 1.15
	elseif engagement < D.EngagementBad then
		pay *= 0.7
	end
	if SocialRules.botShare(acc) > Social.Bots.DealPenaltyShare then
		pay *= 0.5
	end
	pay = math.max(D.PayMin, pay)
	-- round to something a brand would say
	local step = 500
	if pay < 1000 then
		step = 10
	elseif pay < 10000 then
		step = 50
	end
	return math.floor(pay / step + 0.5) * step
end

-- brands that would talk to this account today (min followers, bot share)
function SocialRules.dealsOpen(acc: any): boolean
	return (acc.Real or 0) >= Social.Unlock.DealsFollowers and SocialRules.botShare(acc) <= Social.Bots.NoDealsShare
end

---------------------------------------------------------------- courses
function SocialRules.novelty(daysSince: number): number
	local C = Social.Courses
	local i = math.floor(math.max(0, daysSince)) + 1
	return C.Novelty[i] or C.NoveltyFloor
end

function SocialRules.priceFactor(price: number): number
	local C = Social.Courses
	return (C.PriceRef / math.max(1, price)) ^ C.PriceElasticity
end

-- expected buyers in one whole in-game day for one course
-- course = { topic, price, launchDay }, ctx = { day, demand = {topicId=x}, trust, promo, proof }
function SocialRules.courseBuyers(acc: any, course: any, ctx: any): number
	local C = Social.Courses
	local R = math.max(0, acc.Real or 0)
	local topic = Social.topic(course.topic)
	local demand = (ctx.demand and ctx.demand[course.topic]) or (topic and topic.base) or 1
	local n = C.Sales * (R ^ C.SalesPower) * demand * clamp(ctx.trust or 1, 0.1, 1.2)
	n *= SocialRules.priceFactor(course.price)
	n *= SocialRules.novelty((ctx.day or 0) - (course.launchDay or 0))
	if ctx.promo then
		n *= C.PromoBoost
	end
	if ctx.proof then
		n *= C.ProofBoost
	end
	return n
end

-- course trust (0.1..1.2): bots and refunds pull it down, it recovers by TrustRecover a day
function SocialRules.trust(acc: any, base: number?): number
	local t = (base or 1) - SocialRules.botShare(acc) * Social.Bots.TrustPenalty
	return clamp(t, 0.1, 1.2)
end

-- share of the day's buyers expected in this slice of the day (evening/night weighted)
function SocialRules.daySlice(phase: string, seconds: number, phaseSeconds: number): number
	local C = Social.Courses
	local night = phase == "Evening" or phase == "Night"
	-- Evening 5 min + Night 8 min = 13 of 28 min carry EveningShare of the buyers
	local share = 1 - C.EveningShare
	if night then
		share = C.EveningShare
	end
	return share * seconds / math.max(1, phaseSeconds)
end

-- Poisson-ish: number of sales from an expected value and a 0..1 roll (fine for small rates)
function SocialRules.sales(expected: number, roll: number): number
	if expected <= 0 then
		return 0
	end
	local whole = math.floor(expected)
	local frac = expected - whole
	-- spread: +-35% around the mean for bigger numbers
	if whole >= 3 then
		local n = math.floor(expected * (0.65 + 0.7 * roll) + 0.5)
		return math.max(0, n)
	end
	if roll < frac then
		whole += 1
	end
	return whole
end

-- the course's net per copy after the platform fee
function SocialRules.net(price: number): number
	return math.floor(price * (1 - Social.Courses.Fee) + 0.5)
end

return SocialRules
