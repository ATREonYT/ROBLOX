--!strict
-- CLOUT, the server side (Config/Social, Rules/SocialRules; design in vault "Research/Social Media Hustle.md").
-- Owns: the player's creator account (save field Social), posts (the server decides the spot, the car, who's in
-- the shot and the time of day; the client only sends a framing hint), the daily market, brand deals, courses and
-- their sales, fake followers, the server feed (real players + NPC creators), likes, follows and the leaderboard.
-- Every dollar goes through EconomyService.addCash (2x Cash applies) and every XP through addXP (2x XP applies).
--
-- Remotes: SocialAction (C->S, rate limited) · SocialState (S->C). Payloads in Master Plan §3.3.
-- API: SocialService.atDesk(player) -> bool · SocialService.account(player) -> table? · SocialService.market()
--      SocialService.Posted: Signal(player, post, result) · SocialService.Sale: Signal(player, courseId, n, cash)
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
local HttpService = game:GetService("HttpService")

local Net = require(ReplicatedStorage.MTL.Net)
local Signal = require(ReplicatedStorage.MTL.Signal)
local Social = require(ReplicatedStorage.MTL.Config.Social)
local SocialRules = require(ReplicatedStorage.MTL.Rules.SocialRules)
local StoryRules = require(ReplicatedStorage.MTL.Rules.StoryRules)
local Vehicles = require(ReplicatedStorage.MTL.Config.Vehicles)

local DataService = require(script.Parent.DataService)
local EconomyService = require(script.Parent.EconomyService)
local PhoneService = require(script.Parent.PhoneService)
local StoryService = require(script.Parent.StoryService)
local TimeService = require(script.Parent.TimeService)
local Notify = require(script.Parent.Notify)
local RateLimiter = require(script.Parent.RateLimiter)

local function optional(name: string): any?
	local m = script.Parent:FindFirstChild(name)
	if not m then
		return nil
	end
	local ok, svc = pcall(require, m)
	return if ok then svc else nil
end

local SocialService = {}
SocialService.Posted = Signal.new() -- (player, post, result)
SocialService.Sale = Signal.new() -- (player, courseId, copies, cashPaid)

local function log(...)
	print("[MTL Social]", ...)
end

local stateRemote: RemoteEvent
local limiter = RateLimiter.new(6, 8)
local rng = Random.new()

---------------------------------------------------------------- the clock: one Clout day = one in-game day length
-- A global day number (same in every server, survives rejoining): course age, deal deadlines and the market use it.
local DAY_SECONDS = 1680
do
	local ok, DayNightRules = pcall(function()
		return require(ReplicatedStorage.MTL.Rules.DayNightRules)
	end)
	if ok and DayNightRules and DayNightRules.cycleSeconds then
		local s = DayNightRules.cycleSeconds()
		if type(s) == "number" and s > 60 then
			DAY_SECONDS = math.floor(s)
		end
	end
end

local function today(): number
	return math.floor(os.time() / DAY_SECONDS)
end

local function nextDayIn(): number
	return DAY_SECONDS - (os.time() % DAY_SECONDS)
end

local markets: { [number]: any } = {}
local function marketFor(day: number): any
	local m = markets[day]
	if m then
		return m
	end
	-- the demand random walk needs yesterday's demand: walk forward from a week back (cheap, deterministic)
	local prev = nil
	for d = day - 7, day do
		local mk = markets[d] or SocialRules.market(d, 0, prev)
		markets[d] = mk
		prev = mk.demand
	end
	for d in markets do
		if d < day - 8 then
			markets[d] = nil
		end
	end
	return markets[day]
end

function SocialService.market(): any
	return marketFor(today())
end

---------------------------------------------------------------- the account (save field `Social`)

local function account(player: Player): any?
	local d = DataService.get(player)
	if not d then
		return nil
	end
	local s = d.Social
	if type(s) ~= "table" then
		s = {}
		d.Social = s
	end
	-- fill anything an older save is missing (Reconcile does the top level; nested tables are checked here)
	s.Handle = if type(s.Handle) == "string" and s.Handle ~= "" then s.Handle else string.lower(player.Name)
	s.Real = math.max(0, math.floor(tonumber(s.Real) or 0))
	s.Bots = math.max(0, math.floor(tonumber(s.Bots) or 0))
	s.Posts = if type(s.Posts) == "table" then s.Posts else {}
	s.PostCount = tonumber(s.PostCount) or 0
	s.SpotsEver = if type(s.SpotsEver) == "table" then s.SpotsEver else {}
	s.SpotsToday = if type(s.SpotsToday) == "table" then s.SpotsToday else { day = -1, ids = {} }
	s.Milestones = if type(s.Milestones) == "table" then s.Milestones else {}
	s.PlayerFollowers = if type(s.PlayerFollowers) == "table" then s.PlayerFollowers else {}
	s.Deals = if type(s.Deals) == "table" then s.Deals else {}
	s.Deals.Offers = if type(s.Deals.Offers) == "table" then s.Deals.Offers else {}
	s.Deals.Active = if type(s.Deals.Active) == "table" then s.Deals.Active else nil
	s.Deals.Done = tonumber(s.Deals.Done) or 0
	s.Courses = if type(s.Courses) == "table" then s.Courses else {}
	s.Earned = if type(s.Earned) == "table" then s.Earned else {}
	for _, k in { "Fund", "Deals", "Courses" } do
		s.Earned[k] = tonumber(s.Earned[k]) or 0
	end
	s.History = if type(s.History) == "table" then s.History else {}
	s.Today = if type(s.Today) == "table" then s.Today else { day = -1, income = 0, sales = 0, posted = false, proof = false, gained = 0 }
	s.Trust = tonumber(s.Trust) or 1
	s.LastPostAt = tonumber(s.LastPostAt) or 0
	s.LastSeen = tonumber(s.LastSeen) or 0
	s.Joined = tonumber(s.Joined) or 0
	return s
end
SocialService.account = account

local function unlocked(player: Player): boolean
	local stage = StoryService.stage(player)
	return stage ~= nil and StoryRules.reached(stage, Social.Unlock.Stage)
end

local function send(player: Player, payload: any)
	stateRemote:FireClient(player, payload)
end

-- House rule (HUD thread): every refused action tells the player why, through Notify.refuse.
local function refuse(player: Player, reason: string)
	if (Notify :: any).refuse then
		(Notify :: any).refuse(player, reason)
	else
		send(player, { type = "toast", text = reason })
	end
end

local function push(player: Player)
	DataService.push(player)
end

local function notify(player: Player, title: string, text: string)
	PhoneService.notify(player, { app = Social.AppId, title = title, text = text })
end

local function earn(player: Player, s: any, amount: number, reason: string, bucket: string): number
	if amount <= 0 then
		return 0
	end
	local paid = EconomyService.addCash(player, amount, reason, true)
	s.Earned[bucket] = (s.Earned[bucket] or 0) + paid
	s.Today.income = (s.Today.income or 0) + paid
	return paid
end

---------------------------------------------------------------- where the player is, what's in the shot

local function root(player: Player): BasePart?
	local c = player.Character
	local hrp = c and c:FindFirstChild("HumanoidRootPart")
	local hum = c and c:FindFirstChildOfClass("Humanoid")
	if hrp and hrp:IsA("BasePart") and hum and hum.Health > 0 then
		return hrp
	end
	return nil
end

local function spotAt(pos: Vector3): any?
	local best, bestD = nil, math.huge
	for _, s in Social.Spots do
		local d = (Vector3.new(pos.X, 0, pos.Z) - Vector3.new(s.pos.X, 0, s.pos.Z)).Magnitude
		if d <= s.radius and d < bestD then
			best, bestD = s, d
		end
	end
	return best
end
SocialService.spotAt = spotAt

local function carNear(player: Player, pos: Vector3): (string?, number)
	local folder = workspace:FindFirstChild(Vehicles.SpawnFolder or "MTL_SpawnedCars")
	if not folder then
		return nil, 0
	end
	for _, car in folder:GetChildren() do
		if car:IsA("Model") and car:GetAttribute("MTL_Owner") == player.UserId then
			local ok, cf = pcall(function()
				return car:GetPivot()
			end)
			if ok and (cf.Position - pos).Magnitude <= Social.Post.CarRange then
				local id = car:GetAttribute("MTL_CarId")
				local def = if type(id) == "string" then Vehicles.get(id) else nil
				local flex = (def and tonumber(def.flex)) or Social.Post.DefaultCarFlex
				return (if type(id) == "string" then id else "Car"), flex
			end
		end
	end
	return nil, 0
end

local function collabNear(player: Player, pos: Vector3): { Player }
	local out = {}
	for _, other in Players:GetPlayers() do
		if other ~= player then
			local r = root(other)
			if r and (r.Position - pos).Magnitude <= Social.Post.CollabRange then
				table.insert(out, other)
			end
		end
	end
	return out
end

-- At the desk computer: inside your flat with the power on, close to the PC (or seated at it by the computer
-- piece, which sets the player attribute MTL_AtDesk = true).
function SocialService.atDesk(player: Player): boolean
	if player:GetAttribute("MTL_AtDesk") == true then
		return true
	end
	local Property = optional("PropertyService")
	if not Property or not Property.isInside or not Property.isInside(player) then
		return false
	end
	local d = DataService.get(player)
	if not d or not (d.Home and d.Home.PowerOn) then
		return false
	end
	local room = Property.room and Property.room(player)
	local r = root(player)
	if not room or not r then
		return false
	end
	local mark = room.marks and (room.marks.ChairSpot or room.marks.Keyboard)
	if typeof(mark) ~= "Vector3" then
		return true -- a room with no PC marks: being home counts
	end
	local p = room.origin:PointToWorldSpace(mark)
	return (Vector3.new(p.X, 0, p.Z) - Vector3.new(r.Position.X, 0, r.Position.Z)).Magnitude <= 9
end

---------------------------------------------------------------- the server feed

local feed: { any } = {} -- newest first: real posts (this server) + NPC posts
local likedBy: { [Player]: { [string]: boolean } } = {}

local function commentsFor(post: any, s: any?): { any }
	local pools = { Social.Comments.Any }
	if post.car then
		table.insert(pools, Social.Comments.Car)
	end
	if post.outcome == "viral" then
		table.insert(pools, Social.Comments.Viral)
	end
	if post.brand then
		table.insert(pools, Social.Comments.Ad)
	end
	if post.spot == "Ends" then
		table.insert(pools, Social.Comments.Ends)
	end
	if s and #s.Courses > 0 then
		table.insert(pools, Social.Comments.Course)
	end
	if s and SocialRules.botShare(s) > 0.3 then
		table.insert(pools, Social.Comments.Bots)
	end
	local out, used = {}, {}
	local names = {}
	for _, npc in Social.NPCs do
		table.insert(names, npc.handle)
	end
	for _ = 1, 3 do
		local pool = pools[rng:NextInteger(1, #pools)]
		local text = pool[rng:NextInteger(1, #pool)]
		if not used[text] then
			used[text] = true
			table.insert(out, { who = names[rng:NextInteger(1, #names)], text = text })
		end
	end
	return out
end

local function addToFeed(post: any)
	table.insert(feed, 1, post)
	local real, npc = 0, 0
	for i = #feed, 1, -1 do
		local p = feed[i]
		if p.npc then
			npc += 1
		else
			real += 1
		end
	end
	-- trim oldest of whichever kind is over its cap
	for i = #feed, 1, -1 do
		local p = feed[i]
		if p.npc and npc > Social.Feed.NPCKept then
			table.remove(feed, i)
			npc -= 1
		elseif not p.npc and real > Social.Feed.ServerPosts then
			table.remove(feed, i)
			real -= 1
		end
	end
	stateRemote:FireAllClients({ type = "feedPost", post = post })
end

local function npcPost()
	local npc = Social.NPCs[rng:NextInteger(1, #Social.NPCs)]
	local spot = Social.Spots[rng:NextInteger(1, #Social.Spots)]
	local formats = { "CarFlex", "FitCheck", "Spot" }
	local format = formats[rng:NextInteger(1, #formats)]
	local acc = { Real = npc.followers, Bots = 0 }
	local r = SocialRules.post(acc, {
		spot = spot.id,
		phase = TimeService.phase(),
		carFlex = if format == "CarFlex" then 1.4 else 0,
		format = format,
		framing = rng:NextNumber(0.4, 1),
		market = SocialService.market(),
	}, { luck = rng:NextNumber(), spread = rng:NextNumber(), noise = rng:NextNumber() })
	local captions = Social.Captions[format] or Social.Captions.Spot
	local post = {
		id = HttpService:GenerateGUID(false),
		npc = true,
		handle = npc.handle,
		color = npc.color,
		followers = npc.followers,
		t = os.time(),
		phase = TimeService.phase(),
		spot = spot.id,
		format = format,
		caption = captions[rng:NextInteger(1, #captions)],
		car = if format == "CarFlex" then "Oros" else nil,
		views = r.views,
		likes = r.likes,
		commentCount = r.comments,
		outcome = r.outcome,
		seed = rng:NextInteger(1, 1e6),
	}
	post.comments = commentsFor(post, nil)
	addToFeed(post)
end

local function leaders(): { any }
	local out = {}
	for _, p in Players:GetPlayers() do
		local s = DataService.get(p) and account(p)
		if s and unlocked(p) then
			table.insert(out, {
				userId = p.UserId,
				handle = s.Handle,
				name = p.DisplayName,
				followers = SocialRules.total(s),
				verified = SocialRules.verified(s),
			})
		end
	end
	table.sort(out, function(a, b)
		return a.followers > b.followers
	end)
	while #out > Social.Feed.Leaderboard do
		table.remove(out)
	end
	return out
end

local leadersDirty = false
local function markLeaders()
	leadersDirty = true
end

---------------------------------------------------------------- deals

local function rollOffers(player: Player, s: any, day: number)
	if not SocialRules.dealsOpen(s) then
		return 0
	end
	-- drop expired offers
	for i = #s.Deals.Offers, 1, -1 do
		if (s.Deals.Offers[i].day or 0) < day - 1 then
			table.remove(s.Deals.Offers, i)
		end
	end
	local brands = {}
	for _, b in Social.Brands do
		if (s.Real or 0) >= b.min then
			table.insert(brands, b)
		end
	end
	if #brands == 0 then
		return 0
	end
	local mk = marketFor(day)
	local made = 0
	local recentLikes = 0
	for i = 1, math.min(5, #s.Posts) do
		recentLikes += s.Posts[i].likes or 0
	end
	local eng = SocialRules.engagement(s, recentLikes / math.max(1, math.min(5, #s.Posts)))
	for _ = 1, Social.Deals.OffersPerDay do
		if #s.Deals.Offers >= Social.Deals.MaxOffers then
			break
		end
		local b = brands[rng:NextInteger(1, #brands)]
		local spotId = b.spot
		if not spotId then
			local list = {}
			for _, sp in Social.Spots do
				if sp.id ~= "Ends" then
					table.insert(list, sp.id)
				end
			end
			spotId = list[rng:NextInteger(1, #list)]
		end
		table.insert(s.Deals.Offers, {
			id = HttpService:GenerateGUID(false),
			brand = b.id,
			spot = spotId,
			car = b.car == true,
			format = b.format,
			pay = SocialRules.dealPay(s, b, mk.mood, eng, rng:NextNumber()),
			day = day,
		})
		made += 1
	end
	return made
end

local function dealFor(s: any, id: any): (any?, number?)
	for i, o in s.Deals.Offers do
		if o.id == id then
			return o, i
		end
	end
	return nil, nil
end

---------------------------------------------------------------- the day rolling over (per player)

local function rollDay(player: Player, s: any, quiet: boolean?)
	local day = today()
	if s.Today.day == day then
		return
	end
	local old = s.Today
	if old.day and old.day >= 0 then
		table.insert(s.History, 1, {
			day = old.day,
			income = old.income or 0,
			sales = old.sales or 0,
			followers = SocialRules.total(s),
			gained = old.gained or 0,
		})
		while #s.History > Social.Day.HistoryDays do
			table.remove(s.History)
		end
		-- churn: real followers drift away on a day you don't post (BitLife-style consistency)
		if not old.posted and (s.Real or 0) > 0 then
			s.Real = math.max(0, s.Real - math.floor(s.Real * Social.Day.ChurnPerDay))
		end
	end
	-- bots get purged sometimes
	if (s.Bots or 0) > 0 and rng:NextNumber() < Social.Day.BotPurgeChance then
		local gone = math.floor(s.Bots * rng:NextNumber(Social.Day.BotPurgeMin, Social.Day.BotPurgeMax))
		s.Bots -= gone
		if not quiet and gone > 0 then
			notify(player, "CLOUT", "Clout removed " .. SocialRules.short(gone) .. " fake accounts from your followers.")
		end
	end
	s.Trust = math.min(1, (s.Trust or 1) + Social.Courses.TrustRecover)
	s.Today = { day = day, income = 0, sales = 0, posted = false, proof = false, gained = 0 }
	-- deals: the active one expires after DaysToDo
	if s.Deals.Active and (s.Deals.Active.day or 0) + Social.Deals.DaysToDo < day then
		if not quiet then
			notify(player, "Deal expired", (Social.brand(s.Deals.Active.brand) or { name = "A brand" }).name .. " moved on.")
		end
		s.Deals.Active = nil
	end
	local made = rollOffers(player, s, day)
	if made > 0 and not quiet then
		notify(player, "New brand deals", made .. " brands slid into your DMs.")
	end
	if not quiet and old.day and old.day >= 0 and (old.income or 0) > 0 then
		notify(player, "Yesterday on Clout", "You made $" .. SocialRules.short(old.income or 0) .. ". A new day starts now.")
	end
end

---------------------------------------------------------------- courses: sales through the day

local function liveCourses(s: any): { any }
	local out = {}
	for _, c in s.Courses do
		if not c.retired then
			table.insert(out, c)
		end
	end
	return out
end

local pendingSales: { [Player]: { n: number, cash: number, title: string } } = {}

local function courseTick(player: Player, s: any, seconds: number)
	local courses = liveCourses(s)
	if #courses == 0 then
		return
	end
	local day = today()
	local mk = marketFor(day)
	local phase = TimeService.phase()
	-- seconds of this phase in a day (Evening 5 + Night 8 of 28 min) -> share of the day's buyers this tick
	local nightSecs = DAY_SECONDS * 13 / 28
	local daySecs = DAY_SECONDS - nightSecs
	local slice = SocialRules.daySlice(phase, seconds, if phase == "Evening" or phase == "Night" then nightSecs else daySecs)
	local trust = SocialRules.trust(s, s.Trust)
	for _, c in courses do
		local exp = SocialRules.courseBuyers(s, c, {
			day = day,
			demand = mk.demand,
			trust = trust,
			promo = s.Today.posted,
			proof = s.Today.proof,
		})
		local n = SocialRules.sales(exp * slice, rng:NextNumber())
		if n > 0 then
			local net = SocialRules.net(c.price)
			local paid = earn(player, s, net * n, "CourseSale", "Courses")
			c.sold = (c.sold or 0) + n
			c.revenue = (c.revenue or 0) + paid
			s.Today.sales = (s.Today.sales or 0) + n
			-- refunds on the big tickets: no cash taken back, trust takes the hit
			if c.price >= 297 then
				for _ = 1, n do
					if rng:NextNumber() < Social.Courses.RefundChanceBig then
						c.refunds = (c.refunds or 0) + 1
						s.Trust = math.max(0.1, (s.Trust or 1) - Social.Courses.RefundTrust)
					end
				end
			end
			local p = pendingSales[player] or { n = 0, cash = 0, title = "" }
			p.n += n
			p.cash += paid
			p.title = (Social.topic(c.topic) or { title = "your course" }).title
			pendingSales[player] = p
			SocialService.Sale:Fire(player, c.id, n, paid)
		end
	end
end

local function flushSales(player: Player)
	local p = pendingSales[player]
	if not p or p.n <= 0 then
		return
	end
	pendingSales[player] = nil
	send(player, { type = "sale", n = p.n, cash = p.cash, title = p.title })
	notify(player, if p.n == 1 then "💸 New sale" else ("💸 " .. p.n .. " new sales"), p.title .. "  +$" .. SocialRules.short(p.cash))
end

-- while you were away: a share of normal days' sales, capped
local function offlineSales(player: Player, s: any)
	local away = os.time() - (s.LastSeen or 0)
	if (s.LastSeen or 0) <= 0 or away < 120 then
		return
	end
	local courses = liveCourses(s)
	if #courses == 0 then
		return
	end
	local days = math.min(away / DAY_SECONDS, Social.Courses.OfflineMaxDays)
	local mk = SocialService.market()
	local trust = SocialRules.trust(s, s.Trust)
	local total, cash = 0, 0
	for _, c in courses do
		local exp = SocialRules.courseBuyers(s, c, { day = today(), demand = mk.demand, trust = trust })
		local n = SocialRules.sales(exp * days * Social.Courses.OfflineShare, rng:NextNumber())
		if n > 0 then
			local paid = earn(player, s, SocialRules.net(c.price) * n, "CourseSaleOffline", "Courses")
			c.sold = (c.sold or 0) + n
			c.revenue = (c.revenue or 0) + paid
			total += n
			cash += paid
		end
	end
	if total > 0 then
		task.delay(8, function()
			if player.Parent then
				send(player, { type = "away", n = total, cash = cash })
				notify(player, "While you were away", total .. " people bought your courses  +$" .. SocialRules.short(cash))
			end
		end)
	end
end

---------------------------------------------------------------- posting

local lastPostTimes: { [Player]: { number } } = {}

local function milestoneCheck(player: Player, s: any, before: number)
	local after = SocialRules.total(s)
	for _, m in SocialRules.milestones(before, after, s.Milestones) do
		s.Milestones[tostring(m.at)] = os.time()
		EconomyService.addXP(player, m.xp, "CloutMilestone")
		Notify.banner(player, m.title, m.sub or "on Clout")
	end
	local v = SocialRules.verified(s)
	if v and not s.Verified then
		s.Verified = true
		Notify.banner(player, "VERIFIED", "The blue check is yours")
	end
	markLeaders()
end

local function handlePost(player: Player, payload: any)
	if not unlocked(player) then
		refuse(player, "Clout unlocks once you're settled in (free play)")
		send(player, { type = "postFail", shown = true })
		return
	end
	local s = account(player)
	local r = root(player)
	if not s or not r then
		return
	end
	rollDay(player, s)
	local now = os.clock()
	local times = lastPostTimes[player] or {}
	lastPostTimes[player] = times
	if #times > 0 and now - times[#times] < Social.Post.Cooldown then
		local reason = "Wait " .. math.ceil(Social.Post.Cooldown - (now - times[#times])) .. " s before posting again"
		refuse(player, reason)
		send(player, { type = "postFail", reason = reason, shown = true })
		return
	end
	local recent = 0
	for i = #times, 1, -1 do
		if now - times[i] <= Social.Post.FatigueWindow then
			recent += 1
		else
			table.remove(times, i)
		end
	end

	local pos = r.Position
	local spot = spotAt(pos)
	local spotId = if spot then spot.id else ""
	local carId, carFlex = carNear(player, pos)
	local others = collabNear(player, pos)
	local wanted = if type(payload.format) == "string" then payload.format else "Spot"
	local fmt = Social.format(wanted)
	local format = "Spot"
	if fmt then
		if fmt.needsCar and not carId then
			format = "Spot"
		elseif fmt.needsCollab and #others == 0 then
			format = "Spot"
		elseif fmt.atDesk and not SocialService.atDesk(player) then
			format = "Spot"
		else
			format = fmt.id
		end
	end
	if format == "Proof" then
		spotId = "" -- a screenshot, not a place
		carId, carFlex = nil, 0
	end

	-- brand deal: posting at the deal's spot (with the car if needed) completes it
	local deal = s.Deals.Active
	local completesDeal = deal ~= nil and payload.deal == true and deal.spot == spotId and (not deal.car or carId ~= nil)
	local day = today()
	if s.SpotsToday.day ~= day then
		s.SpotsToday = { day = day, ids = {} }
	end
	local repeatSpot = false
	for i = 1, math.min(Social.Post.RepeatSpotLookback, #s.Posts) do
		if spotId ~= "" and s.Posts[i].spot == spotId then
			repeatSpot = true
		end
	end
	local shot = {
		spot = spotId,
		phase = TimeService.phase(),
		carFlex = carFlex,
		format = format,
		collab = #others,
		framing = math.clamp(tonumber(payload.framing) or 0.5, 0, 1),
		newSpotToday = spotId ~= "" and not s.SpotsToday.ids[spotId],
		firstEverAtSpot = spotId ~= "" and not s.SpotsEver[spotId],
		repeatSpot = repeatSpot,
		recentPosts = recent,
		sponsored = completesDeal,
		verified = SocialRules.verified(s),
		market = SocialService.market(),
	}
	local res = SocialRules.post(s, shot, { luck = rng:NextNumber(), spread = rng:NextNumber(), noise = rng:NextNumber() })

	-- caption: an index into the format's list (no free text)
	local captions = if completesDeal then Social.Captions.Sponsored else (Social.Captions[format] or Social.Captions.Spot)
	local ci = math.clamp(math.floor(tonumber(payload.caption) or 1), 1, #captions)

	local before = SocialRules.total(s)
	s.Real += res.gained
	table.insert(times, now)
	s.PostCount += 1
	s.LastPostAt = os.time()
	s.Today.posted = true
	s.Today.gained = (s.Today.gained or 0) + res.gained
	if format == "Proof" then
		s.Today.proof = true
	end
	if spotId ~= "" then
		s.SpotsToday.ids[spotId] = true
		s.SpotsEver[spotId] = os.time()
	end
	if s.Joined == 0 then
		s.Joined = os.time()
	end

	local post = {
		id = HttpService:GenerateGUID(false),
		userId = player.UserId,
		handle = s.Handle,
		name = player.DisplayName,
		followers = SocialRules.total(s),
		verified = SocialRules.verified(s),
		t = os.time(),
		phase = shot.phase,
		spot = spotId,
		format = format,
		caption = captions[ci],
		car = carId,
		with = {},
		views = res.views,
		likes = res.likes,
		commentCount = res.comments,
		shares = res.shares,
		gained = res.gained,
		outcome = res.outcome,
		quality = res.quality,
		brand = if completesDeal and deal then deal.brand else nil,
		seed = rng:NextInteger(1, 1e6),
	}
	for _, o in others do
		table.insert(post.with, o.DisplayName)
	end
	post.comments = commentsFor(post, s)

	-- keep it in the save (small copy)
	table.insert(s.Posts, 1, {
		id = post.id,
		t = post.t,
		phase = shot.phase,
		spot = spotId,
		format = format,
		caption = post.caption,
		car = carId,
		views = res.views,
		likes = res.likes,
		comments = res.comments,
		gained = res.gained,
		outcome = res.outcome,
		brand = post.brand,
		seed = post.seed,
	})
	while #s.Posts > Social.Post.MaxStored do
		table.remove(s.Posts)
	end

	-- rewards: XP (2x XP applies), Creator Fund (2x Cash applies), the deal
	local xpGiven = EconomyService.addXP(player, res.xp, "CloutPost")
	local fund = earn(player, s, res.fund, "CloutFund", "Fund")
	local dealPaid = 0
	if completesDeal and deal then
		dealPaid = earn(player, s, deal.pay, "BrandDeal", "Deals")
		EconomyService.addXP(player, Social.Deals.XP, "BrandDeal")
		s.Deals.Done += 1
		s.Deals.Active = nil
	end
	-- collab: everyone in the shot gets a slice of the followers
	for _, o in others do
		local os_ = account(o)
		if os_ and unlocked(o) then
			local share = math.floor(res.gained * 0.25)
			if share > 0 then
				local b = SocialRules.total(os_)
				os_.Real += share
				milestoneCheck(o, os_, b)
				notify(o, "Collab with @" .. s.Handle, "+" .. SocialRules.short(share) .. " followers from their post")
				push(o)
			end
		end
	end
	milestoneCheck(player, s, before)
	push(player)

	addToFeed(post)
	send(player, {
		type = "posted",
		post = post,
		result = {
			views = res.views,
			likes = res.likes,
			comments = res.comments,
			shares = res.shares,
			gained = res.gained,
			outcome = res.outcome,
			luck = res.luckMult,
			quality = res.quality,
			parts = res.parts,
			xp = xpGiven,
			fund = fund,
			deal = dealPaid,
			brand = post.brand,
			rollout = Social.Post.RolloutSeconds,
		},
	})
	SocialService.Posted:Fire(player, post, res)
	log(player.Name, "posted", format, "at", spotId == "" and "-" or spotId, "q", res.quality, res.outcome, res.views, "views +", res.gained)
end

---------------------------------------------------------------- the other actions

local handlers: { [string]: (Player, any) -> () } = {}

handlers.post = handlePost

handlers.sync = function(player, _payload)
	local s = account(player)
	if s then
		rollDay(player, s)
	end
	send(player, {
		type = "hello",
		market = SocialService.market(),
		nextDayIn = nextDayIn(),
		daySeconds = DAY_SECONDS,
		feed = feed,
		leaders = leaders(),
		liked = likedBy[player] or {},
		unlocked = unlocked(player),
	})
end

-- a quick "where am I" for the shoot screen (spot, car, collab, desk), checked by the server
handlers.scout = function(player, _payload)
	local r = root(player)
	if not r then
		return
	end
	local spot = spotAt(r.Position)
	local carId = carNear(player, r.Position)
	send(player, {
		type = "scout",
		spot = spot and spot.id or "",
		car = carId,
		collab = #collabNear(player, r.Position),
		desk = SocialService.atDesk(player),
		phase = TimeService.phase(),
	})
end

handlers.like = function(player, payload)
	local id = payload.id
	if type(id) ~= "string" or #id > 64 then
		return
	end
	likedBy[player] = likedBy[player] or {}
	if likedBy[player][id] then
		return
	end
	for _, p in feed do
		if p.id == id then
			likedBy[player][id] = true
			p.likes = (p.likes or 0) + 1
			p.playerLikes = (p.playerLikes or 0) + 1
			stateRemote:FireAllClients({ type = "feedLike", id = id, likes = p.likes })
			if not p.npc and p.userId ~= player.UserId then
				local owner = Players:GetPlayerByUserId(p.userId)
				local s = owner and account(owner)
				if owner and s then
					notify(owner, "@" .. string.lower(player.Name) .. " liked your post", "A real one 👀")
				end
			end
			return
		end
	end
end

handlers.follow = function(player, payload)
	local uid = tonumber(payload.userId)
	if not uid or uid == player.UserId then
		return
	end
	local target = Players:GetPlayerByUserId(uid)
	local s = target and account(target)
	if not target or not s or not unlocked(target) then
		return
	end
	local key = tostring(player.UserId)
	if s.PlayerFollowers[key] then
		return
	end
	local n = 0
	for _ in s.PlayerFollowers do
		n += 1
	end
	if n >= 500 then
		return
	end
	local before = SocialRules.total(s)
	s.PlayerFollowers[key] = os.time()
	s.Real += Social.PlayerFollowWorth
	milestoneCheck(target, s, before)
	notify(target, "New follower", "@" .. string.lower(player.Name) .. " (a real one) followed you")
	push(target)
	send(player, { type = "followed", userId = uid })
end

handlers.acceptDeal = function(player, payload)
	local s = account(player)
	if not s then
		return
	end
	rollDay(player, s)
	local offer, i = dealFor(s, payload.id)
	if not offer or not i then
		return
	end
	if s.Deals.Active then
		refuse(player, "Finish your current deal first")
		return
	end
	table.remove(s.Deals.Offers, i)
	offer.day = today()
	s.Deals.Active = offer
	push(player)
	local spot = Social.spot(offer.spot)
	send(player, { type = "toast", text = "Deal on. Post at " .. spot.label .. (if offer.car then " with your car" else "") })
	-- GPS to the spot (the phone's GPS waypoint)
	local Waypoints = optional("WaypointService")
	if Waypoints and spot.pos then
		pcall(Waypoints.set, player, "GPS", spot.pos, { label = spot.label .. " · deal", radius = math.min(40, spot.radius) })
	end
end

handlers.declineDeal = function(player, payload)
	local s = account(player)
	if not s then
		return
	end
	local _, i = dealFor(s, payload.id)
	if i then
		table.remove(s.Deals.Offers, i)
		push(player)
	end
end

handlers.gps = function(player, payload)
	local spot = Social.spot(payload.spot)
	if not spot or spot.id == "" then
		return
	end
	local Waypoints = optional("WaypointService")
	if Waypoints then
		pcall(Waypoints.set, player, "GPS", spot.pos, { label = spot.label, radius = math.min(40, spot.radius) })
		player:SetAttribute("MTL_GPS", "Clout_" .. spot.id)
		send(player, { type = "toast", text = "GPS set: " .. spot.label })
	end
end

handlers.buyBots = function(player, payload)
	local s = account(player)
	if not s or not unlocked(player) then
		return
	end
	local pack
	for _, p in Social.Bots.Packs do
		if p.id == payload.pack then
			pack = p
		end
	end
	if not pack then
		return
	end
	if not EconomyService.spend(player, pack.price, "CloutBots") then
		refuse(player, "Not enough cash")
		return
	end
	local before = SocialRules.total(s)
	s.Bots += pack.count
	milestoneCheck(player, s, before)
	push(player)
	send(player, { type = "toast", text = "+" .. SocialRules.short(pack.count) .. " followers (they're bots)" })
end

-- courses: start recording at the desk, finish each module after RecordSeconds, the last one launches it
local recording: { [Player]: { topic: string, price: number, step: number, at: number } } = {}

handlers.startCourse = function(player, payload)
	local s = account(player)
	local d = DataService.get(player)
	if not s or not d then
		return
	end
	if (s.Real or 0) < Social.Unlock.CoursesFollowers or (d.Level or 1) < Social.Unlock.CoursesLevel then
		refuse(player, "Courses need " .. SocialRules.short(Social.Unlock.CoursesFollowers) .. " real followers and Level " .. Social.Unlock.CoursesLevel)
		return
	end
	if not SocialService.atDesk(player) then
		refuse(player, "Record it at your desk computer (power on)")
		return
	end
	if #liveCourses(s) >= Social.Courses.MaxLive then
		refuse(player, "Retire a course first (max " .. Social.Courses.MaxLive .. ")")
		return
	end
	local topic = Social.topic(payload.topic)
	local tier = Social.priceTier(tonumber(payload.price) or 0)
	if not topic or not tier then
		return
	end
	if not EconomyService.spend(player, tier.cost, "CourseProduction") then
		refuse(player, "Production costs $" .. SocialRules.short(tier.cost))
		return
	end
	recording[player] = { topic = topic.id, price = tier.price, step = 0, at = os.clock() }
	send(player, { type = "recording", topic = topic.id, price = tier.price, step = 0, of = Social.Courses.Modules, seconds = Social.Courses.RecordSeconds })
end

handlers.recordStep = function(player, _payload)
	local rec = recording[player]
	local s = account(player)
	if not rec or not s then
		return
	end
	if not SocialService.atDesk(player) then
		refuse(player, "Stay at your desk to record")
		return
	end
	if os.clock() - rec.at < Social.Courses.RecordSeconds * 0.9 then
		return
	end
	rec.step += 1
	rec.at = os.clock()
	if rec.step < Social.Courses.Modules then
		send(player, { type = "recording", topic = rec.topic, price = rec.price, step = rec.step, of = Social.Courses.Modules, seconds = Social.Courses.RecordSeconds })
		return
	end
	recording[player] = nil
	local c = {
		id = HttpService:GenerateGUID(false),
		topic = rec.topic,
		price = rec.price,
		launchDay = today(),
		launchedAt = os.time(),
		sold = 0,
		revenue = 0,
	}
	table.insert(s.Courses, 1, c)
	-- keep retired ones for the history, but not forever
	while #s.Courses > 8 do
		table.remove(s.Courses)
	end
	EconomyService.addXP(player, Social.Courses.XPLaunch, "CourseLaunch")
	push(player)
	local t = Social.topic(rec.topic)
	Notify.banner(player, "COURSE LIVE", (t and t.title or "Your course") .. " · $" .. rec.price)
	send(player, { type = "launched", course = c })
end

handlers.cancelRecording = function(player, _payload)
	recording[player] = nil
	send(player, { type = "recording", cancel = true })
end

handlers.retireCourse = function(player, payload)
	local s = account(player)
	if not s then
		return
	end
	for _, c in s.Courses do
		if c.id == payload.id then
			c.retired = true
		end
	end
	push(player)
end

---------------------------------------------------------------- lifecycle

local function onReady(player: Player, data: any)
	local s = account(player)
	if not s then
		return
	end
	if unlocked(player) then
		PhoneService.unlockApp(player, Social.AppId)
	end
	rollDay(player, s, true)
	offlineSales(player, s)
	s.LastSeen = os.time()
	push(player)
	markLeaders()
end

function SocialService.init()
	stateRemote = Net.get("SocialState")
	Net.get("SocialAction").OnServerEvent:Connect(function(player: Player, payload: any)
		if type(payload) ~= "table" or type(payload.type) ~= "string" then
			return
		end
		if not limiter:allow(player) then
			return
		end
		local fn = handlers[payload.type]
		if fn then
			local ok, err = pcall(fn, player, payload)
			if not ok then
				warn("[MTL Social] action failed:", payload.type, err)
			end
		end
	end)

	DataService.Ready:Connect(onReady)
	StoryService.onEnter(Social.Unlock.Stage, function(player: Player, resumed: boolean)
		PhoneService.unlockApp(player, Social.AppId)
		if not resumed then
			task.delay(20, function()
				if player.Parent then
					notify(player, "CLOUT", "Everybody's posting. Pull up somewhere nice with your car and post.")
				end
			end)
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		local s = DataService.get(player) and account(player)
		if s then
			s.LastSeen = os.time()
		end
		lastPostTimes[player] = nil
		likedBy[player] = nil
		recording[player] = nil
		pendingSales[player] = nil
		markLeaders()
	end)

	-- client copies of the cars so posts can show them (ViewportFrame); scripts/sounds stripped
	task.spawn(function()
		local src = ServerStorage:FindFirstChild(Vehicles.TemplateFolder or "MTL_Cars")
		if not src then
			return
		end
		local dst = ReplicatedStorage:FindFirstChild("MTL_SocialProps") or Instance.new("Folder")
		dst.Name = "MTL_SocialProps"
		for _, car in src:GetChildren() do
			if car:IsA("Model") and not dst:FindFirstChild(car.Name) then
				local ok, copy = pcall(function()
					return car:Clone()
				end)
				if ok and copy then
					for _, d in copy:GetDescendants() do
						if d:IsA("LuaSourceContainer") or d:IsA("Sound") or d:IsA("ProximityPrompt") then
							d:Destroy()
						end
					end
					for _, d in copy:GetDescendants() do
						if d:IsA("BasePart") then
							d.Anchored = true
							d.CanCollide = false
						end
					end
					copy.Parent = dst
				end
			end
		end
		dst.Parent = ReplicatedStorage
	end)

	-- the clock: course sales, day rollover, NPC posts, leaderboard
	task.spawn(function()
		local lastTick = os.clock()
		local lastNpc = 0
		local lastFlush = 0
		local lastLeaders = 0
		local lastDay = today()
		for _ = 1, 4 do
			npcPost()
		end
		while true do
			task.wait(1)
			local now = os.clock()
			if now - lastTick >= Social.Courses.TickSeconds then
				local secs = now - lastTick
				lastTick = now
				for _, p in Players:GetPlayers() do
					local s = DataService.get(p) and account(p)
					if s then
						rollDay(p, s)
						local ok, err = pcall(courseTick, p, s, secs)
						if not ok then
							warn("[MTL Social] course tick:", err)
						end
						s.LastSeen = os.time()
					end
				end
			end
			if now - lastFlush >= 30 then
				lastFlush = now
				for _, p in Players:GetPlayers() do
					flushSales(p)
					if DataService.get(p) then
						push(p)
					end
				end
			end
			if now - lastNpc >= Social.Feed.NPCPostEvery then
				lastNpc = now
				npcPost()
			end
			local d = today()
			if d ~= lastDay then
				lastDay = d
				stateRemote:FireAllClients({ type = "market", market = SocialService.market(), nextDayIn = nextDayIn() })
			end
			if leadersDirty and now - lastLeaders >= 5 then
				leadersDirty = false
				lastLeaders = now
				stateRemote:FireAllClients({ type = "leaders", leaders = leaders() })
			end
		end
	end)
	log("ready · day", today(), "· trending", SocialService.market().trendSpot, "· mood", SocialService.market().mood)
end

-- Studio helpers (via _G.MTL.Social / MTL_Debug): give followers, force a day roll, set real/bots
function SocialService.debug(player: Player, what: string, n: number?)
	local s = account(player)
	if not s then
		return "no account"
	end
	if what == "followers" then
		local b = SocialRules.total(s)
		s.Real += math.floor(n or 1000)
		milestoneCheck(player, s, b)
	elseif what == "day" then
		s.Today.day = -1
		rollDay(player, s)
	elseif what == "sales" then
		courseTick(player, s, (n or 60))
		flushSales(player)
	elseif what == "unlock" then
		PhoneService.unlockApp(player, Social.AppId)
	end
	push(player)
	return { real = s.Real, bots = s.Bots, posts = s.PostCount, courses = #s.Courses }
end

return SocialService
