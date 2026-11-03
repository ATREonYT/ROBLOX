--!strict
-- The Re-Up (Liberty OS app "ReUp", server half; vault §7.4). Criminal only; every sale is dirty cash.
--   PC:  state · order { prop, n } · assign { corner, prop|nil } · bulk { prop, n } · upgrade { prop, id } · gps
--   Map: the Plug's container at the docks ("Grab the duffel", heat chance) -> your stash ("Stash it") -> raw.
--        At the stash: "Pack up" (release minigame, ReUp.Batch raw -> packs per round), "Collect" (the runners'
--        dirty cash), "Move the stock" (during a raid warning).
--        Runners stand on your corners (a rig from CrimeService.buildRig) and sell 1 pack every 45-75 s.
-- Save: ReUp = { Stash = { [prop] = { Raw, Packs, Dirty, Upgrades = {} } }, Runners = { [cornerId] = prop }, Sold,
--               Heat = { [cornerId] = 0..1 } }
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ReUp = require(ReplicatedStorage.MTL.Config.ReUp)
local Realty = require(ReplicatedStorage.MTL.Config.Realty)
local DataService = require(script.Parent.DataService)
local EconomyService = require(script.Parent.EconomyService)
local Notify = require(script.Parent.Notify)
local WaypointService = require(script.Parent.WaypointService)
local PlayerPrompt = require(script.Parent.PlayerPrompt)

local ReUpService = {}

local WAY = "ReUp"
local PURPLE = Color3.fromRGB(180, 110, 255)

local function lazy(name: string): any
	local m = script.Parent:FindFirstChild(name)
	if not m then
		return nil
	end
	local ok, mod = pcall(require, m)
	return if ok then mod else nil
end

type Job = { kind: string, prop: string, n: number, stage: string, at: number, meet: any? }
local jobs: { [Player]: Job } = {}
type Raid = { prop: string, at: number, deadline: number }
local raids: { [Player]: Raid } = {}
local runnerNext: { [Player]: { [string]: number } } = {}
local runnerRigs: { [Player]: { [string]: Model } } = {}
local packing: { [Player]: boolean } = {}

local cornerById: { [string]: any } = {}
for _, c in ReUp.Corners do
	cornerById[c.id] = c
end

---------------------------------------------------------------- save helpers

local function save(d: any): any
	d.ReUp = d.ReUp or {}
	local r = d.ReUp
	r.Stash = r.Stash or {}
	r.Runners = r.Runners or {}
	r.Heat = r.Heat or {}
	r.Sold = r.Sold or 0
	return r
end

local function stash(d: any, prop: string): any
	local r = save(d)
	local s = r.Stash[prop]
	if not s then
		s = { Raw = 0, Packs = 0, Dirty = 0, Upgrades = {} }
		r.Stash[prop] = s
	end
	s.Upgrades = s.Upgrades or {}
	return s
end

local function owns(d: any, prop: string): boolean
	local p = Realty.Props[prop]
	return p ~= nil and p.kind == "stash" and d.Realty ~= nil and d.Realty.Owned ~= nil and d.Realty.Owned[prop] ~= nil
end

local function cap(prop: string): number
	return Realty.Props[prop].cap or 0
end

local function slots(level: number): number
	local n = 0
	for _, row in ReUp.CornerSlots do
		if level >= row[1] then
			n = row[2]
		end
	end
	return n
end

local function addDirty(player: Player, amount: number, reason: string, at: Vector3?): number
	local C = lazy("CrimeService")
	if C and C.addDirty then
		return C.addDirty(player, amount, reason, at)
	end
	warn("[MTL ReUp] CrimeService missing: dirty cash not paid", amount)
	return 0
end

local function heat(player: Player, stars: number, why: string)
	local P = lazy("PoliceService")
	if P and P.raise then
		P.raise(player, stars, why)
	end
end

---------------------------------------------------------------- stash prompts (always there while you own one)

local function stashPoint(prop: string, side: number): Vector3
	-- TODO(Studio): stash interiors with named points (Station, Safe). For now: beside the front door.
	return Realty.Props[prop].at + Vector3.new(side * 3, 0, 0)
end

local refreshStash: (Player, string) -> ()

local function packRound(player: Player, prop: string)
	if packing[player] then
		return
	end
	local d = DataService.get(player)
	if not d then
		return
	end
	local s = stash(d, prop)
	if s.Raw <= 0 then
		Notify.toast(player, "No raw stock. Order a re-up on the PC.")
		return
	end
	if s.Packs >= cap(prop) then
		Notify.toast(player, "The stash is full. Move some packs first.")
		return
	end
	local C = lazy("CrimeService")
	local function finish(p: Player, score: number)
		packing[p] = nil
		local dd = DataService.get(p)
		if not dd then
			return
		end
		local ss = stash(dd, prop)
		local n = math.min(ReUp.Batch, ss.Raw, cap(prop) - ss.Packs)
		if score < ReUp.Waste then
			ss.Raw -= 1
			Notify.toast(p, "Torn seal. One pack wasted.", Color3.fromRGB(232, 84, 84))
		else
			ss.Raw -= n
			ss.Packs += n
			local xp = ReUp.XP.Pack * n + (if score >= ReUp.Perfect then ReUp.XP.Perfect else 0)
			EconomyService.addXP(p, xp, "ReUpPack", stashPoint(prop, -1))
			Notify.toast(p, string.format("%s%d packs sealed · %d/%d", if score >= ReUp.Perfect then "PERFECT · " else "", n, ss.Packs, cap(prop)), PURPLE)
		end
		DataService.push(p)
		refreshStash(p, prop)
	end
	packing[player] = true
	if C and C.mini then
		C.mini(player, "reup:pack", ReUp.Mini, ReUp.MiniMin, finish, function(p)
			packing[p] = nil
		end)
	else
		task.delay(ReUp.MiniMin, finish, player, 0.8)
	end
end

refreshStash = function(player: Player, prop: string)
	local d = DataService.get(player)
	if not d or not owns(d, prop) then
		return
	end
	local s = stash(d, prop)
	PlayerPrompt.set(player, "reup:pack:" .. prop, {
		pos = stashPoint(prop, -1),
		action = "Pack up",
		object = string.format("%d raw · %d/%d packs", s.Raw, s.Packs, cap(prop)),
		hold = 0,
		fn = function(p)
			packRound(p, prop)
		end,
	})
	if s.Dirty > 0 then
		PlayerPrompt.set(player, "reup:collect:" .. prop, {
			pos = stashPoint(prop, 1),
			action = "Collect $" .. s.Dirty,
			object = "Runners' take",
			hold = 1,
			fn = function(p)
				local dd = DataService.get(p)
				if not dd then
					return
				end
				local ss = stash(dd, prop)
				local took = addDirty(p, ss.Dirty, "ReUpRunners", stashPoint(prop, 1))
				ss.Dirty -= took
				DataService.push(p)
				refreshStash(p, prop)
			end,
		})
	else
		PlayerPrompt.clear(player, "reup:collect:" .. prop)
	end
end

---------------------------------------------------------------- re-up run (docks -> stash)

local function endJob(player: Player, why: string?)
	if not jobs[player] then
		return
	end
	jobs[player] = nil
	WaypointService.clear(player, WAY)
	PlayerPrompt.clear(player, "reup:job")
	if why then
		Notify.toast(player, why)
	end
end

local function order(player: Player, d: any, prop: string, n: number): any
	if jobs[player] then
		return { ok = false, err = "Finish your current run first" }
	end
	if not owns(d, prop) then
		return { ok = false, err = "You don't own that stash" }
	end
	local o = nil
	for _, row in ReUp.Orders do
		if row.n == n then
			o = row
		end
	end
	if not o then
		return { ok = false, err = "Pick an order size" }
	end
	local s = stash(d, prop)
	if s.Raw + s.Packs + n > cap(prop) then
		return { ok = false, err = string.format("Not enough room (%d/%d)", s.Raw + s.Packs, cap(prop)) }
	end
	if not EconomyService.spend(player, o.n * o.each, "ReUpOrder") then
		return { ok = false, err = "Need $" .. o.n * o.each }
	end
	local j: Job = { kind = "order", prop = prop, n = n, stage = "grab", at = os.clock() }
	jobs[player] = j
	WaypointService.set(player, WAY, ReUp.Plug, { label = "The container", radius = 12, breadcrumbs = true })
	Notify.objective(player, "Pick up the duffel at the docks")
	PlayerPrompt.set(player, "reup:job", {
		pos = ReUp.Plug,
		action = "Grab the duffel",
		object = n .. " packs, raw",
		hold = ReUp.GrabSeconds,
		fn = function(p)
			if jobs[p] ~= j or j.stage ~= "grab" then
				return
			end
			j.stage = "stash"
			if math.random() < ReUp.GrabHeat.chance then
				heat(p, ReUp.GrabHeat.stars, "ReUpPickup")
			end
			local door = stashPoint(prop, 0)
			WaypointService.set(p, WAY, door, { label = Realty.Props[prop].title, radius = 12, breadcrumbs = true })
			Notify.objective(p, "Get the duffel to the " .. Realty.Props[prop].title)
			PlayerPrompt.set(p, "reup:job", {
				pos = door,
				action = "Stash it",
				object = Realty.Props[prop].title,
				hold = 1.5,
				fn = function(q)
					if jobs[q] ~= j or j.stage ~= "stash" then
						return
					end
					local dd = DataService.get(q)
					if not dd then
						return
					end
					stash(dd, prop).Raw += n
					EconomyService.addXP(q, ReUp.XP.Order, "ReUpOrder", door)
					DataService.push(q)
					endJob(q)
					Notify.toast(q, n .. " raw stashed. Pack it up at the station.", PURPLE)
					refreshStash(q, prop)
				end,
			})
		end,
	})
	return { ok = true }
end

---------------------------------------------------------------- bulk buyer (Level 18)

local function bulk(player: Player, d: any, prop: string, n: number): any
	if jobs[player] then
		return { ok = false, err = "Finish your current run first" }
	end
	if (d.Level or 1) < ReUp.Bulk.level then
		return { ok = false, err = "Level " .. ReUp.Bulk.level }
	end
	if not owns(d, prop) then
		return { ok = false, err = "You don't own that stash" }
	end
	local s = stash(d, prop)
	n = math.floor(n)
	if n < ReUp.Bulk.min or n > s.Packs then
		return { ok = false, err = string.format("The buyer wants %d+ packs (you have %d)", ReUp.Bulk.min, s.Packs) }
	end
	s.Packs -= n
	DataService.push(player)
	local meet = ReUp.Bulk.meets[math.random(1, #ReUp.Bulk.meets)]
	local j: Job = { kind = "bulk", prop = prop, n = n, stage = "meet", at = os.clock(), meet = meet }
	jobs[player] = j
	WaypointService.set(player, WAY, meet.at, { label = meet.name, radius = 12, breadcrumbs = true })
	Notify.objective(player, string.format("Take %d packs to the buyer at %s", n, meet.name))
	PlayerPrompt.set(player, "reup:job", {
		pos = meet.at,
		action = "Make the swap",
		object = n .. " packs",
		hold = 2.5,
		fn = function(p)
			if jobs[p] ~= j then
				return
			end
			local dd = DataService.get(p)
			if not dd then
				return
			end
			save(dd).Sold += n
			addDirty(p, n * ReUp.Bulk.each, "ReUpBulk", meet.at)
			EconomyService.addXP(p, ReUp.XP.Bulk, "ReUpBulk", meet.at)
			DataService.push(p)
			endJob(p)
			Notify.banner(p, "SWAP DONE", n .. " packs moved", PURPLE)
		end,
	})
	return { ok = true }
end

---------------------------------------------------------------- runners on corners

local function placeRunner(player: Player, cornerId: string)
	runnerRigs[player] = runnerRigs[player] or {}
	if runnerRigs[player][cornerId] then
		return
	end
	local C = lazy("CrimeService")
	local c = cornerById[cornerId]
	if not C or not C.buildRig or not c then
		return
	end
	local skins = { Color3.fromRGB(141, 85, 36), Color3.fromRGB(198, 134, 66), Color3.fromRGB(92, 58, 38), Color3.fromRGB(224, 172, 105) }
	local shirts = { Color3.fromRGB(36, 36, 42), Color3.fromRGB(120, 30, 34), Color3.fromRGB(200, 200, 205), Color3.fromRGB(40, 60, 110) }
	local look = { Skin = skins[math.random(1, #skins)], Shirt = shirts[math.random(1, #shirts)], Pants = Color3.fromRGB(30, 32, 40) }
	local ok, rig = pcall(C.buildRig, "Runner", look)
	if ok and rig then
		local root = workspace:FindFirstChild("MTL_Jobs") or Instance.new("Folder")
		root.Name = "MTL_Jobs"
		root.Parent = workspace
		pcall(C.placeRig, rig, CFrame.new(c.at) * CFrame.Angles(0, math.rad(math.random(0, 359)), 0), root)
		rig.Name = "Runner_" .. player.UserId .. "_" .. cornerId
		runnerRigs[player][cornerId] = rig
	end
end

local function removeRunner(player: Player, cornerId: string)
	local t = runnerRigs[player]
	if t and t[cornerId] then
		t[cornerId]:Destroy()
		t[cornerId] = nil
	end
end

local function assign(player: Player, d: any, cornerId: string, prop: string?): any
	local r = save(d)
	if not cornerById[cornerId] then
		return { ok = false, err = "Unknown corner" }
	end
	if prop == nil or prop == "" then
		r.Runners[cornerId] = nil
		removeRunner(player, cornerId)
		DataService.push(player)
		return { ok = true }
	end
	if not owns(d, prop :: string) then
		return { ok = false, err = "You don't own that stash" }
	end
	local used = 0
	for id in r.Runners do
		if id ~= cornerId then
			used += 1
		end
	end
	if used >= slots(d.Level or 1) then
		return { ok = false, err = if slots(d.Level or 1) == 0 then "Runners unlock at Level 15" else "No free corners at your level" }
	end
	r.Runners[cornerId] = prop
	placeRunner(player, cornerId)
	DataService.push(player)
	return { ok = true }
end

local function runnerTick(player: Player)
	local d = DataService.get(player)
	if not d or not d.ReUp then
		return
	end
	local r = save(d)
	local now = os.clock()
	runnerNext[player] = runnerNext[player] or {}
	local changed: { [string]: boolean } = {}
	for cornerId, prop in r.Runners do
		local c = cornerById[cornerId]
		if not c or not owns(d, prop) then
			continue
		end
		placeRunner(player, cornerId)
		local due = runnerNext[player][cornerId]
		if not due then
			runnerNext[player][cornerId] = now + math.random(ReUp.Runner.min, ReUp.Runner.max)
			continue
		end
		if now >= due then
			runnerNext[player][cornerId] = now + math.random(ReUp.Runner.min, ReUp.Runner.max)
			local s = stash(d, prop)
			if s.Packs > 0 then
				s.Packs -= 1
				s.Dirty += math.floor(c.pay * (1 - ReUp.Runner.cut))
				r.Sold += 1
				r.Heat[cornerId] = math.min(1, (r.Heat[cornerId] or 0) + ReUp.Runner.heatPerSale)
				EconomyService.addXP(player, ReUp.XP.Sold, "ReUpRunner")
				changed[prop] = true
			end
		end
	end
	for cornerId, h in r.Heat do
		r.Heat[cornerId] = math.max(0, h - ReUp.HeatDecay)
	end
	for prop in changed do
		refreshStash(player, prop)
	end
end

---------------------------------------------------------------- raids

local function startRaid(player: Player, prop: string, lookout: boolean)
	local warn = if lookout then ReUp.Raid.warnLookout else ReUp.Raid.warn
	local rd: Raid = { prop = prop, at = os.clock(), deadline = os.clock() + warn }
	raids[player] = rd
	Notify.banner(player, "LOOKOUT", "Blue lights heading to the " .. Realty.Props[prop].title .. ". Move the stock!", Color3.fromRGB(232, 84, 84))
	WaypointService.set(player, "ReUpRaid", stashPoint(prop, 0), { label = "Move the stock", radius = 10, breadcrumbs = true })
	PlayerPrompt.set(player, "reup:raid", {
		pos = stashPoint(prop, 0),
		action = "Move the stock",
		object = Realty.Props[prop].title,
		hold = 3,
		fn = function(p)
			if raids[p] ~= rd then
				return
			end
			raids[p] = nil
			PlayerPrompt.clear(p, "reup:raid")
			WaypointService.clear(p, "ReUpRaid")
			Notify.toast(p, "Stock moved. The stash is clean.", PURPLE)
			heat(p, 1, "ReUpRaid")
		end,
	})
end

local function raidTimeout(player: Player)
	local rd = raids[player]
	if not rd or os.clock() < rd.deadline then
		return
	end
	raids[player] = nil
	PlayerPrompt.clear(player, "reup:raid")
	WaypointService.clear(player, "ReUpRaid")
	local d = DataService.get(player)
	if not d then
		return
	end
	local s = stash(d, rd.prop)
	local lostP = math.floor(s.Packs * ReUp.Raid.lose)
	local lostD = math.floor(s.Dirty * ReUp.Raid.lose)
	s.Packs -= lostP
	s.Dirty -= lostD
	DataService.push(player)
	refreshStash(player, rd.prop)
	Notify.banner(player, "RAIDED", string.format("Lost %d packs and $%d", lostP, lostD), Color3.fromRGB(232, 84, 84))
end

local function raidRoll(player: Player)
	if raids[player] then
		return
	end
	local d = DataService.get(player)
	if not d or not d.ReUp then
		return
	end
	local r = save(d)
	for prop, s in r.Stash do
		if owns(d, prop) and s.Packs >= ReUp.Raid.min then
			local h = 0
			for cornerId, p in r.Runners do
				if p == prop then
					h = math.max(h, r.Heat[cornerId] or 0)
				end
			end
			local lookout = s.Upgrades.Lookout == true
			local chance = (ReUp.Raid.base + ReUp.Raid.heat * h) * (if lookout then 0.5 else 1)
			if math.random() < chance then
				startRaid(player, prop, lookout)
				return
			end
		end
	end
end

---------------------------------------------------------------- PC

local function state(player: Player, d: any): any
	local r = save(d)
	local stashes = {}
	for _, id in Realty.Order do
		local p = Realty.Props[id]
		if p.kind == "stash" then
			local s = if owns(d, id) then stash(d, id) else nil
			local ups = {}
			for uid, u in ReUp.Upgrades do
				table.insert(ups, { id = uid, title = u.title, price = u.price, level = u.level, blurb = u.blurb, owned = s ~= nil and s.Upgrades[uid] == true })
			end
			table.sort(ups, function(a, b)
				return a.price < b.price
			end)
			table.insert(stashes, { id = id, title = p.title, cap = p.cap, owned = s ~= nil, raw = s and s.Raw or 0, packs = s and s.Packs or 0, dirty = s and s.Dirty or 0, upgrades = ups })
		end
	end
	local corners = {}
	for _, c in ReUp.Corners do
		table.insert(corners, { id = c.id, title = c.title, pay = c.pay, turf = c.turf, prop = r.Runners[c.id], heat = r.Heat[c.id] or 0 })
	end
	local j = jobs[player]
	return {
		ok = true,
		stashes = stashes,
		corners = corners,
		slots = slots(d.Level or 1),
		orders = ReUp.Orders,
		bulk = { level = ReUp.Bulk.level, min = ReUp.Bulk.min, each = ReUp.Bulk.each },
		sold = r.Sold,
		level = d.Level,
		job = j and { kind = j.kind, prop = j.prop, n = j.n, stage = j.stage },
		raid = raids[player] and { prop = raids[player].prop, left = math.max(0, raids[player].deadline - os.clock()) },
	}
end

function ReUpService.handle(player: Player, action: string, args: any): any
	local d = DataService.get(player)
	if not d then
		return { ok = false, err = "Still loading" }
	end
	args = if type(args) == "table" then args else {}
	local prop = tostring(args.prop or "")
	local res: any
	if action == "state" then
		return state(player, d)
	elseif action == "order" then
		res = order(player, d, prop, tonumber(args.n) or 0)
	elseif action == "bulk" then
		res = bulk(player, d, prop, tonumber(args.n) or 0)
	elseif action == "assign" then
		res = assign(player, d, tostring(args.corner), if args.prop then tostring(args.prop) else nil)
	elseif action == "cancel" then
		local j = jobs[player]
		if j and j.kind == "bulk" then
			stash(d, j.prop).Packs += j.n
		end
		endJob(player, "Run cancelled")
		res = { ok = true }
	elseif action == "upgrade" then
		local id = tostring(args.id)
		local u = ReUp.Upgrades[id]
		if not u or not owns(d, prop) then
			return { ok = false, err = "Can't do that" }
		end
		local s = stash(d, prop)
		if s.Upgrades[id] then
			return { ok = false, err = "Already done" }
		end
		if (d.Level or 1) < u.level then
			return { ok = false, err = "Level " .. u.level }
		end
		if not EconomyService.spend(player, u.price, "ReUpUpgrade") then
			return { ok = false, err = "Need $" .. u.price }
		end
		s.Upgrades[id] = true
		DataService.push(player)
		res = { ok = true }
	elseif action == "gps" then
		if Realty.Props[prop] then
			WaypointService.set(player, WAY, stashPoint(prop, 0), { label = Realty.Props[prop].title, radius = 12, breadcrumbs = true })
		elseif cornerById[prop] then
			WaypointService.set(player, WAY, cornerById[prop].at, { label = cornerById[prop].title, radius = 12, breadcrumbs = true })
		end
		res = { ok = true }
	else
		return { ok = false, err = "Unknown action" }
	end
	if res.ok then
		local s = state(player, d)
		for k, v in res do
			s[k] = v
		end
		return s
	end
	return res
end

local function setup(player: Player)
	task.wait(6)
	local d = DataService.get(player)
	if not d or not d.ReUp then
		return
	end
	for prop in save(d).Stash do
		refreshStash(player, prop)
	end
end

function ReUpService.init(_desk: any)
	Players.PlayerAdded:Connect(setup)
	for _, p in Players:GetPlayers() do
		task.spawn(setup, p)
	end
	local okR, RealtyService = pcall(require, script.Parent.RealtyService)
	if okR and RealtyService and RealtyService.Bought then
		RealtyService.Bought:Connect(function(p: Player, id: string)
			if Realty.Props[id] and Realty.Props[id].kind == "stash" then
				local d = DataService.get(p)
				if d then
					stash(d, id)
					refreshStash(p, id)
				end
			end
		end)
	end
	Players.PlayerRemoving:Connect(function(p)
		local j = jobs[p]
		if j and j.kind == "bulk" then
			local d = DataService.get(p)
			if d then
				stash(d, j.prop).Packs += j.n
			end
		end
		jobs[p] = nil
		raids[p] = nil
		packing[p] = nil
		runnerNext[p] = nil
		for _, rig in runnerRigs[p] or {} do
			rig:Destroy()
		end
		runnerRigs[p] = nil
		PlayerPrompt.clearAll(p)
	end)
	task.spawn(function()
		local t = 0
		while true do
			task.wait(10)
			t += 10
			for _, p in Players:GetPlayers() do
				runnerTick(p)
				raidTimeout(p)
				local j = jobs[p]
				if j and os.clock() - j.at > ReUp.JobMinutes * 60 then
					if j.kind == "bulk" then
						local d = DataService.get(p)
						if d then
							stash(d, j.prop).Packs += j.n
						end
					end
					endJob(p, "The run timed out")
				end
				if t % ReUp.Upgrades.Crew.every == 0 then
					local d = DataService.get(p)
					for prop, s in (d and d.ReUp and d.ReUp.Stash or {}) do
						if s.Upgrades and s.Upgrades.Crew and s.Raw > 0 and s.Packs < cap(prop) then
							s.Raw -= 1
							s.Packs += 1
						end
					end
				end
				if t % ReUp.Raid.every == 0 then
					raidRoll(p)
				end
			end
		end
	end)
end

return ReUpService
