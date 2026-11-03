--!strict
-- CLOUT: the in-game social app (phone app "Clout" + the desk computer's browser). Every number lives here;
-- the maths is in Rules/SocialRules (pure, tested by tools/tests/test_social_rules.py). Design + research:
-- vault "Research/Social Media Hustle.md".
--
-- The loop: drive your car to a photo spot -> shoot (the phone becomes a viewfinder) -> post -> views roll in,
-- some posts go viral -> followers -> brand deals (1K) -> your own courses (10K, recorded at the desk computer)
-- that sell every in-game day. Each day the market changes (trending spot, algorithm mood, course demand), so
-- income is never the same two days running. All cash goes through EconomyService.addCash (2x Cash applies) and
-- all XP through EconomyService.addXP (2x XP applies).
local Social = {}

Social.AppId = "Clout"
Social.Name = "CLOUT" -- the brand (no real platform names anywhere in the game)
Social.Domain = "clout.com" -- what the desk computer's browser shows

-- Who can use it. The app unlocks on reaching this story stage; the rest unlocks with followers / level.
Social.Unlock = {
	Stage = "FreePlay", -- app appears on the phone
	DealsFollowers = 1000, -- brand deals start arriving (real followers)
	FundFollowers = 1000, -- the Creator Fund pays per 1K views
	CoursesFollowers = 10000, -- Creator Studio: make and sell courses
	CoursesLevel = 12,
	VerifiedFollowers = 100000, -- blue check (and bots under VerifiedMaxBotShare)
	VerifiedMaxBotShare = 0.25,
}

-- Creator tiers (shown on the profile; real-world tier names)
Social.Tiers = {
	{ id = "New", min = 0, label = "New creator" },
	{ id = "Nano", min = 1000, label = "Nano creator" },
	{ id = "Micro", min = 10000, label = "Micro creator" },
	{ id = "Rising", min = 50000, label = "Rising star" },
	{ id = "Mid", min = 100000, label = "Mid-tier creator" },
	{ id = "Macro", min = 500000, label = "Macro creator" },
	{ id = "Mega", min = 1000000, label = "Mega creator" },
}

-- Follower milestones: XP once each (2x XP applies) + a banner.
Social.Milestones = {
	{ at = 100, xp = 60, title = "100 FOLLOWERS" },
	{ at = 1000, xp = 150, title = "1K FOLLOWERS", sub = "Brand deals and the Creator Fund are open" },
	{ at = 10000, xp = 300, title = "10K FOLLOWERS", sub = "Creator Studio is open on your computer" },
	{ at = 50000, xp = 450, title = "50K FOLLOWERS" },
	{ at = 100000, xp = 700, title = "100K FOLLOWERS" },
	{ at = 500000, xp = 1100, title = "500K FOLLOWERS" },
	{ at = 1000000, xp = 1800, title = "1 MILLION FOLLOWERS" },
}

---------------------------------------------------------------- photo spots
-- Where posts are worth something. The server decides which spot you're at from your character's position.
-- score = how much the spot flexes (0.6 the Ends .. 2.0 the jet). light = phases that make it pop.
-- needsCar = car meets look empty without a car (x Post.NoCarAtCarSpot). tag = the hashtag.
-- palette = the colours a post from here is drawn with for other players (top, bottom, accent).
local V = Vector3.new
local C = Color3.fromRGB
Social.Spots = {
	{ id = "Ends", label = "The Ends", tag = "#fromtheends", pos = V(-1442, 3, -170), radius = 70, score = 0.7, light = { Evening = 1.1 }, palette = { C(120, 104, 92), C(52, 44, 40), C(255, 196, 64) }, scene = "street" },
	{ id = "CarMeetWest", label = "Westside Car Meet", tag = "#carmeet", pos = V(-1881.5, 4, 710), radius = 90, score = 1.35, light = { Night = 1.3, Evening = 1.15 }, needsCar = true, palette = { C(40, 30, 70), C(14, 12, 22), C(255, 72, 104) }, scene = "lot" },
	{ id = "SoundStudio", label = "Liberty Sound Studio", tag = "#studiosession", pos = V(-1837.5, 4, 495), radius = 45, score = 1.15, light = { Night = 1.15 }, palette = { C(60, 40, 90), C(20, 16, 30), C(180, 120, 255) }, scene = "street" },
	{ id = "Wynwood", label = "Wynwood Walls", tag = "#wynwood", pos = V(-320, 4, -484), radius = 75, score = 1.5, light = { Day = 1.15, Evening = 1.2 }, palette = { C(255, 120, 160), C(80, 170, 255), C(255, 220, 80) }, scene = "mural" },
	{ id = "CreatorHouse", label = "Creator House", tag = "#creatorhouse", pos = V(-480, 4, -1018), radius = 60, score = 1.4, light = { Day = 1.1, Evening = 1.15 }, palette = { C(255, 200, 220), C(190, 220, 255), C(255, 72, 104) }, scene = "house" },
	{ id = "Theater", label = "Tower Theater", tag = "#neonnights", pos = V(-160, 4, 625), radius = 55, score = 1.3, light = { Night = 1.35 }, palette = { C(255, 60, 140), C(30, 14, 40), C(255, 210, 90) }, scene = "street" },
	{ id = "SohoMeet", label = "SoHo Car Meet", tag = "#sohomeet", pos = V(181, 4, -905), radius = 90, score = 1.55, light = { Night = 1.3, Evening = 1.15 }, needsCar = true, palette = { C(30, 40, 90), C(10, 12, 26), C(80, 200, 255) }, scene = "lot" },
	{ id = "Lookout", label = "Lookout Hill", tag = "#viewfromthetop", pos = V(185, 26, -560), radius = 70, score = 1.5, light = { Evening = 1.35, Morning = 1.15 }, palette = { C(255, 150, 90), C(120, 70, 140), C(255, 220, 140) }, scene = "skyline" },
	{ id = "Exchange", label = "Stock Exchange", tag = "#moneymoves", pos = V(800, 8, -328), radius = 60, score = 1.45, light = { Day = 1.15 }, palette = { C(200, 210, 225), C(70, 80, 100), C(114, 214, 112) }, scene = "tower" },
	{ id = "Yachts", label = "Vice Bay Yachts", tag = "#yachtlife", pos = V(1050, 5, 804), radius = 90, score = 1.8, light = { Day = 1.1, Evening = 1.3 }, palette = { C(120, 200, 255), C(20, 90, 150), C(255, 255, 255) }, scene = "water" },
	{ id = "Beach", label = "Ocean Drive Beach", tag = "#beachday", pos = V(1560, 4, -280), radius = 110, score = 1.45, light = { Day = 1.2, Morning = 1.1 }, palette = { C(120, 210, 255), C(240, 220, 170), C(255, 120, 80) }, scene = "beach" },
	{ id = "StarIsland", label = "Star Island", tag = "#mansionlife", pos = V(2420, 4, -830), radius = 110, score = 1.9, light = { Evening = 1.25, Day = 1.1 }, palette = { C(255, 210, 160), C(90, 160, 120), C(255, 255, 255) }, scene = "house" },
	{ id = "Raceway", label = "Sol Raceway", tag = "#trackday", pos = V(-250, 4, -3300), radius = 180, score = 1.7, light = { Day = 1.15 }, needsCar = true, palette = { C(230, 230, 230), C(60, 60, 64), C(255, 60, 60) }, scene = "track" },
	{ id = "Airport", label = "Private Jet Terminal", tag = "#jetlife", pos = V(-3240, 4, 1792), radius = 220, score = 2.0, light = { Evening = 1.25, Day = 1.1 }, palette = { C(180, 210, 240), C(90, 100, 120), C(255, 255, 255) }, scene = "jet" },
	{ id = "Golf", label = "Golf Club", tag = "#countryclub", pos = V(-4000, 4, -322), radius = 220, score = 1.6, light = { Morning = 1.15, Day = 1.1 }, palette = { C(150, 210, 255), C(80, 160, 70), C(255, 255, 255) }, scene = "grass" },
}
Social.NoSpot = { id = "", label = "Somewhere", tag = "#vibes", score = 0.55, palette = { C(110, 110, 120), C(40, 40, 46), C(255, 255, 255) }, scene = "street" }

---------------------------------------------------------------- posts
Social.Post = {
	Cooldown = 45, -- seconds between posts (server)
	FatigueWindow = 600, -- posts in the last 10 min beyond FatigueFree each cut reach by FatiguePer (spam)
	FatigueFree = 3,
	FatiguePer = 0.8,
	RepeatSpotPenalty = 0.7, -- same spot as one of your last RepeatSpotLookback posts
	RepeatSpotLookback = 3,
	NewSpotToday = 1.12, -- first post at this spot today
	NoCarAtCarSpot = 0.75,
	CarRange = 55, -- studs: your spawned car counts as "in the shot" this close to you
	CollabRange = 30, -- other players this close are in the shot
	CollabPer = 0.15, -- +15% per other player (max CollabMax)
	CollabMax = 3,
	TrendSpot = 1.6, -- today's trending spot
	TrendFormat = 1.25, -- today's trending format
	Verified = 1.1,
	Sponsored = 0.85, -- ads reach less (real)
	FramingMin = 0.85, -- the client's framing score (0..1) only moves quality this much
	FramingMax = 1.15,
	DefaultCarFlex = 1.25, -- a car with no `flex` in Config/Vehicles
	RolloutSeconds = 75, -- how long the counters climb on screen (the server credits followers at once)
	MaxStored = 24, -- your own posts kept in the save
	-- reach
	SeeRate = 0.32, -- share of real followers who see a post when you're small...
	SeeRateFalloff = 25000, -- ...falling like (1 + R / this)^-0.35
	ExploreBase = 260, -- non-follower views the algorithm hands a quality-1 post at 0 followers
	ExploreGrowth = 0.6, -- explore x (1 + (R / 1000)^this): bigger accounts get pushed harder
	QualityPower = 1.6, -- explore scales with quality^this
	FollowRate = 0.034, -- share of non-follower viewers who follow (x quality)
	FollowFalloff = 0.12, -- follow rate x (1 + R / 1000)^-this (big accounts convert less)
	LikeRateSmall = 0.11, -- likes / views at 0 followers...
	LikeRateBig = 0.045, -- ...towards this at 1M
	CommentRate = 0.035, -- comments / likes
	ShareRate = 0.012, -- shares / views
	-- the viral lottery (heavy tail like real feeds)
	ViralChance = 0.035, -- + ViralQualityBonus x (quality - 1), capped at ViralChanceMax
	ViralQualityBonus = 0.05,
	ViralChanceMax = 0.12,
	ViralMin = 6,
	ViralMax = 22,
	HotChance = 0.14, -- a smaller pop
	HotMin = 1.8,
	HotMax = 3.5,
	FlopChance = 0.12,
	FlopMult = 0.45,
	Noise = 0.25, -- +-25% on every post
	-- rewards per post
	XPBase = 16,
	XPPerQuality = 10,
	XPMax = 70,
	XPNewSpot = 25, -- first ever post at a spot
	XPViral = 80,
	FundPer1K = 1.2, -- Creator Fund $ per 1K views (from Unlock.FundFollowers)
	FundMax = 2500, -- per post
}

-- Post formats. The shoot screen picks the format from what's in the shot; today's trend boosts one.
Social.Formats = {
	{ id = "CarFlex", label = "Car flex", needsCar = true },
	{ id = "FitCheck", label = "Fit check" },
	{ id = "Spot", label = "Location drop" },
	{ id = "Collab", label = "Collab", needsCollab = true },
	{ id = "Proof", label = "Money proof", atDesk = true }, -- a screenshot of your earnings, desk computer only
}

-- Captions the player picks from (no free text: nothing to filter). {kind} = format id or "Any".
Social.Captions = {
	CarFlex = { "Paid in full. Allegedly.", "She don't need gas, she needs respect", "New toy. Same me.", "Pull up. Park. Get out slow.", "Rented? Nah. Leased. Kinda." },
	FitCheck = { "Fit too clean for this zip code", "Dressed like the bag already came", "Outfit cost more than my rent (I don't pay rent)", "Mirror said W" },
	Spot = { "Location: none of your business", "Views like this don't come free", "Pinch me", "Main character energy" },
	Collab = { "The team > the dream", "Squad don't miss", "We all eating", "Link up szn" },
	Proof = { "Results speak. Link in bio.", "Another day, another payout", "Screenshots don't lie (they do)", "This could be you. Course in bio." },
	Sponsored = { "Not an ad (it's an ad) #sponsored", "Shoutout to the plug #ad", "Use my code, thank me later #sponsored" },
}

-- Comment pools for the post screen (NPCs). Chosen by what the post is.
Social.Comments = {
	Any = { "W", "🔥🔥🔥", "this goes hard", "how bro", "goals fr", "first", "💯", "ok we see you", "need this energy", "who took the pic tho" },
	Car = { "bro rented that 💀", "whats the payment on that", "turo special", "drop the plate number", "clean whip", "that's the dealership lot bro" },
	Viral = { "the algorithm blessed you", "how is this on my fyp", "came from the fyp 👀", "this blew up lol" },
	Course = { "course link??", "is the course legit", "bought it, ngl it helped", "where the link", "how do i start" },
	Bots = { "nice pic 👍", "great post!!", "follow back", "amazing content 😍", "check my page" },
	Ad = { "ad 🙄", "how much they pay u", "code still work?", "sellout lol" },
	Ends = { "never forget where u came from", "the Ends raised you", "day 1s know" },
}

---------------------------------------------------------------- the daily market
-- One market per in-game day (rolls over at Morning). Seeded per server + day, so everyone in a server shares
-- the day (the feed and chat agree on what's trending). Nothing here is a timer or scarcity: it's flavour + swing.
Social.Day = {
	MoodMin = 0.7, -- algorithm mood (reach x)
	MoodMax = 1.4,
	DemandMin = 0.4, -- course niche demand (sales x), random walk from yesterday
	DemandMax = 1.9,
	DemandStep = 0.45,
	ChurnPerDay = 0.006, -- real followers you lose on a day you don't post
	BotPurgeChance = 0.3, -- a day the app purges fake accounts...
	BotPurgeMin = 0.4, -- ...removes this share of your bots
	BotPurgeMax = 0.8,
	HistoryDays = 7, -- days kept for the analytics charts
}
Social.MoodLabels = { { 0, "Dead", "Reach is down today" }, { 0.9, "Normal", "Normal reach" }, { 1.15, "Hot", "Algorithm is pushing posts" }, { 1.3, "On fire", "Everything is getting pushed" } }

---------------------------------------------------------------- fake followers ("bots")
-- Buy followers: the count goes up, real reach doesn't. Bots never see posts, never buy courses, drag the
-- engagement rate down (brands check it) and can get purged. They do add a little social proof (follow rate).
Social.Bots = {
	Packs = {
		{ id = "Bots1K", count = 1000, price = 300 },
		{ id = "Bots10K", count = 10000, price = 2500 },
		{ id = "Bots100K", count = 100000, price = 20000 },
	},
	SocialProof = 0.12, -- follow rate x (1 + this * log10(1 + bots / real))
	DealPenaltyShare = 0.3, -- bot share over this halves brand pay
	NoDealsShare = 0.6, -- over this, brands stop offering
	TrustPenalty = 0.9, -- course trust loses this x bot share
}

---------------------------------------------------------------- brand deals
-- Offers arrive as Clout DMs each day (from DealsFollowers). Accept one, post at its spot (with your car if it
-- says so) before the day after tomorrow ends, get paid on posting. Pay follows real-world tier rates:
-- Pay x (realFollowers / 1000)^PayPower: 1K ~ $60, 10K ~ $300, 100K ~ $1.5K, 1M ~ $7.5K (real tier ratios, game scale).
Social.Deals = {
	OffersPerDay = 3,
	MaxOffers = 4, -- open offers kept
	Pay = 60,
	PayPower = 0.7,
	PayMin = 80,
	DaysToDo = 2,
	XP = 90,
	EngagementGood = 0.06, -- like rate at or above this = x1.15, below EngagementBad = x0.7
	EngagementBad = 0.025,
}
Social.Brands = {
	{ id = "Glace", name = "Glacé Water", blurb = "Hydration, but make it luxury.", min = 1000, mult = 0.9 },
	{ id = "NoCap", name = "NoCap Energy", blurb = "Zero sugar. Zero cap.", min = 1000, mult = 1.0 },
	{ id = "DripLab", name = "DripLab", blurb = "Streetwear drops every Friday.", min = 1000, mult = 1.05, format = "FitCheck" },
	{ id = "SoleFlip", name = "SoleFlip", blurb = "Buy and resell sneakers.", min = 5000, mult = 1.1 },
	{ id = "Vibe", name = "VibeCheck Audio", blurb = "Headphones that go hard.", min = 5000, mult = 1.1 },
	{ id = "KashKard", name = "KashKard", blurb = "The card for people who move money.", min = 20000, mult = 1.2, spot = "Exchange" },
	{ id = "Tint", name = "Midnight Tint & Wrap", blurb = "Wraps, tints, rims.", min = 10000, mult = 1.15, car = true },
	{ id = "Coral", name = "Coral Hotel", blurb = "Stay where the ballers stay.", min = 50000, mult = 1.3, spot = "Yachts" },
	{ id = "Lamberti", name = "Lamberti", blurb = "Italian. Loud. Expensive.", min = 200000, mult = 1.6, car = true, spot = "Raceway" },
	{ id = "Skylane", name = "Skylane Jets", blurb = "Charter flights for people who don't wait.", min = 300000, mult = 1.7, spot = "Airport" },
}

---------------------------------------------------------------- courses
-- Made in Creator Studio at the desk computer (needs the flat's power on). Each course sells a few copies every
-- in-game day: buyers = Sales x realFollowers^SalesPower x demand(today) x trust x price factor x novelty x promo.
-- Sales arrive through the day as "new sale" pings (paid at once, platform keeps Fee).
Social.Courses = {
	MaxLive = 3,
	Fee = 0.1, -- the platform's cut
	Sales = 0.0003,
	SalesPower = 0.9,
	PriceRef = 97, -- price factor = (PriceRef / price)^PriceElasticity
	PriceElasticity = 1.15,
	Novelty = { 1.7, 1.35, 1.1, 0.9, 0.75, 0.6 }, -- by days since launch; then NoveltyFloor
	NoveltyFloor = 0.45,
	PromoBoost = 1.5, -- you posted today (any post = a "link in bio")
	ProofBoost = 1.25, -- you posted a Money proof today
	RecordSeconds = 6, -- per module at the desk (3 modules)
	Modules = 3,
	XPLaunch = 200,
	TickSeconds = 15, -- server: how often sales are rolled
	EveningShare = 0.45, -- share of a day's buyers who buy in the evening/night (people scroll at night)
	OfflineShare = 0.25, -- while you're away: this share of a normal day's sales...
	OfflineMaxDays = 3, -- ...for at most this many in-game days
	RefundChanceBig = 0.06, -- $297+ courses: a share of buyers refund (trust hit, no cash taken back)
	RefundTrust = 0.01,
	TrustRecover = 0.03, -- per day back towards 1
}
Social.CoursePrices = {
	{ price = 27, label = "Mini course", cost = 1500 },
	{ price = 97, label = "Course", cost = 4000 },
	{ price = 297, label = "Masterclass", cost = 9000 },
	{ price = 997, label = "Mentorship", cost = 25000 },
}
Social.CourseTopics = {
	{ id = "Larp", title = "Larp Like a Millionaire", blurb = "Rent the car, shoot the pic, return the car.", base = 1.0 },
	{ id = "Flip", title = "Flip Cars for Profit", blurb = "Buy low, detail, list high.", base = 0.9 },
	{ id = "Trading", title = "Day Trading Secrets", blurb = "Green candles only (results not typical).", base = 1.1 },
	{ id = "Grow", title = "Zero to 100K on Clout", blurb = "The algorithm, explained by someone it likes.", base = 1.0 },
	{ id = "Sneakers", title = "Sneaker Reselling 101", blurb = "Bots, drops and flips.", base = 0.85 },
	{ id = "Rich", title = "Rich in 30 Days", blurb = "Step 1: buy this course.", base = 1.2 },
}

---------------------------------------------------------------- the feed
-- NPC creators fill the feed next to real players in the server (names are made up).
Social.NPCs = {
	{ handle = "jaylen.moves", followers = 48200, color = C(255, 120, 80) },
	{ handle = "miamimami", followers = 512000, color = C(255, 80, 160) },
	{ handle = "lilwick_official", followers = 9100, color = C(120, 200, 255) },
	{ handle = "tradingwithtre", followers = 133000, color = C(114, 214, 112) },
	{ handle = "coralcarclub", followers = 27400, color = C(80, 200, 255) },
	{ handle = "nina.k", followers = 2300, color = C(200, 140, 255) },
	{ handle = "bigdre305", followers = 76000, color = C(255, 200, 64) },
	{ handle = "vicebaydaily", followers = 1240000, color = C(255, 72, 104) },
	{ handle = "solesbysam", followers = 18800, color = C(255, 160, 60) },
	{ handle = "notarealceo", followers = 301000, color = C(180, 180, 200) },
}
Social.Feed = {
	ServerPosts = 40, -- recent real posts kept on the server (all players)
	NPCPostEvery = 50, -- seconds: an NPC creator posts
	NPCKept = 16,
	Leaderboard = 8,
}

-- what the server rolls into followers when a real player in the server follows you
Social.PlayerFollowWorth = 25 -- a real player's follow counts as this many real followers (they're rare and real)

function Social.spot(id: string?): any
	if id and id ~= "" then
		for _, s in Social.Spots do
			if s.id == id then
				return s
			end
		end
	end
	return Social.NoSpot
end

function Social.format(id: string?): any?
	for _, f in Social.Formats do
		if f.id == id then
			return f
		end
	end
	return nil
end

function Social.topic(id: string?): any?
	for _, t in Social.CourseTopics do
		if t.id == id then
			return t
		end
	end
	return nil
end

function Social.brand(id: string?): any?
	for _, b in Social.Brands do
		if b.id == id then
			return b
		end
	end
	return nil
end

function Social.priceTier(price: number): any?
	for _, p in Social.CoursePrices do
		if p.price == price then
			return p
		end
	end
	return nil
end

return Social
