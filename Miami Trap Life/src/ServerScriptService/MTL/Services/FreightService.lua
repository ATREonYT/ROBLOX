--!strict
-- Freight (Liberty OS app "Freight", server half; vault §7.3). The PC places orders; the work happens on the map:
--   SOURCE: PC "source" {prop, n} -> pay -> a crate stack appears at a Port container yard spot, GPS set.
--           Hold "Load crate" n times -> GPS to your warehouse -> hold "Unload" at the door -> stock += n.
--   SELL:   PC "sell" {prop, n} -> 1-3 buyer drops on the map (FreightRules.drops), GPS to the first.
--           Hold "Hand over" at each drop -> paid that drop's share at the sale's per-crate price.
-- One job at a time per player. Jobs expire after Freight.JobMinutes (sourced crates lost; unsold crates return).
-- Save: Freight = { [propId] = { Crates, Sold, Upgrades = { Sourcer = true, Security = true }, Full = os.time()? } }
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Freight = require(ReplicatedStorage.MTL.Config.Freight)
local Realty = require(ReplicatedStorage.MTL.Config.Realty)
local FreightRules = require(ReplicatedStorage.MTL.Rules.FreightRules)
local DataService = require(script.Parent.DataService)
local EconomyService = require(script.Parent.EconomyService)
local Notify = require(script.Parent.Notify)
local WaypointService = require(script.Parent.WaypointService)

local FreightService = {}

type Job = {
	kind: string, -- "source" | "sell"
	prop: string,
	n: number,
	step: number, -- source: crates loaded; sell: drops done
	stage: string, -- source: "load" | "return" ; sell: "drop"
	drops: { { name: string, at: Vector3, n: number } }?,
	each: number?,
	at: number,
	folder: Folder,
	pickup: Vector3?,
}
local jobs: { [Player]: Job } = {}

local WAY = "Freight"
local BROWN = Color3.fromRGB(150, 112, 70)

local function store(d: any, prop: string): any
	d.Freight = d.Freight or {}
	local w = d.Freight[prop]
	if not w then
		w = { Crates = 0, Sold = 0, Upgrades = {} }
		d.Freight[prop] = w
	end
	w.Upgrades = w.Upgrades or {}
	return w
end

local function owns(d: any, prop: string): boolean
	local p = Realty.Props[prop]
	return p ~= nil and p.kind == "freight" and d.Realty ~= nil and d.Realty.Owned ~= nil and d.Realty.Owned[prop] ~= nil
end

---------------------------------------------------------------- the world bits (built from parts, no scripts)

local function crate(parent: Instance, cf: CFrame): Model
	local m = Instance.new("Model")
	m.Name = "Crate"
	local box = Instance.new("Part")
	box.Name = "Box"
	box.Size = Vector3.new(2.6, 2.2, 2.6)
	box.CFrame = cf
	box.Material = Enum.Material.WoodPlanks
	box.Color = BROWN
	box.Anchored = true
	box.CanCollide = true
	box.Parent = m
	for _, y in { -0.85, 0.85 } do
		local band = Instance.new("Part")
		band.Name = "Band"
		band.Size = Vector3.new(2.7, 0.18, 2.7)
		band.CFrame = cf * CFrame.new(0, y, 0)
		band.Material = Enum.Material.Metal
		band.Color = Color3.fromRGB(60, 60, 64)
		band.Anchored = true
		band.CanCollide = false
		band.Parent = m
	end
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.CanvasSize = Vector2.new(260, 220)
	gui.LightInfluence = 1
	gui.Parent = box
	local t = Instance.new("TextLabel")
	t.Size = UDim2.fromScale(1, 0.4)
	t.Position = UDim2.fromScale(0, 0.3)
	t.BackgroundTransparency = 1
	t.Text = "LIBERTY IMPORTS\nFRAGILE · THIS SIDE UP"
	t.Font = Enum.Font.Oswald
	t.TextScaled = true
	t.TextColor3 = Color3.fromRGB(30, 22, 16)
	t.TextTransparency = 0.25
	t.Parent = gui
	m.PrimaryPart = box
	m.Parent = parent
	return m
end

local function promptAt(parent: Instance, pos: Vector3, action: string, object: string, hold: number, owner: Player): (Part, ProximityPrompt)
	local a = Instance.new("Part")
	a.Name = "PromptAnchor"
	a.Size = Vector3.new(1, 1, 1)
	a.Transparency = 1
	a.CanCollide = false
	a.CanQuery = false
	a.Anchored = true
	a.Position = pos + Vector3.new(0, 2.5, 0)
	a.Parent = parent
	local pp = Instance.new("ProximityPrompt")
	pp.ActionText = action
	pp.ObjectText = object
	pp.HoldDuration = hold
	pp.MaxActivationDistance = 10
	pp.RequiresLineOfSight = false
	pp:SetAttribute("MTL_Owner", owner.UserId) -- the client hides prompts that aren't yours
	pp.Parent = a
	return a, pp
end

local function jobFolder(player: Player): Folder
	local root = workspace:FindFirstChild("MTL_Jobs")
	if not root then
		root = Instance.new("Folder")
		root.Name = "MTL_Jobs"
		root.Parent = workspace
	end
	local f = Instance.new("Folder")
	f.Name = "Freight_" .. player.UserId
	f.Parent = root
	return f
end

local function endJob(player: Player, why: string?)
	local j = jobs[player]
	if not j then
		return
	end
	jobs[player] = nil
	WaypointService.clear(player, WAY)
	j.folder:Destroy()
	if why then
		Notify.toast(player, why)
	end
end

---------------------------------------------------------------- sourcing

local function freePickup(): Vector3
	local used: { [Vector3]: boolean } = {}
	for _, j in jobs do
		if j.pickup then
			used[j.pickup] = true
		end
	end
	for _, p in Freight.Pickups do
		if not used[p] then
			return p
		end
	end
	return Freight.Pickups[math.random(1, #Freight.Pickups)]
end

local function startReturn(player: Player, j: Job)
	j.stage = "return"
	local door = Realty.Props[j.prop].at
	WaypointService.set(player, WAY, door, { label = Realty.Props[j.prop].title, radius = 12, breadcrumbs = true })
	Notify.objective(player, string.format("Take %d crate%s to the %s", j.n, if j.n == 1 then "" else "s", Realty.Props[j.prop].title))
	local _, pp = promptAt(j.folder, door, "Unload " .. j.n .. " crate" .. (if j.n == 1 then "" else "s"), Realty.Props[j.prop].title, Freight.UnloadSeconds * j.n, player)
	pp.Triggered:Connect(function(who)
		if who ~= player or jobs[player] ~= j or j.stage ~= "return" then
			return
		end
		local d = DataService.get(player)
		if not d then
			return
		end
		local w = store(d, j.prop)
		local cap = Realty.Props[j.prop].cap or 0
		local put = math.min(j.n, cap - w.Crates)
		w.Crates += put
		EconomyService.addXP(player, Freight.XP.Sourced * put, "FreightSource", Realty.Props[j.prop].at)
		DataService.push(player)
		endJob(player)
		Notify.toast(player, string.format("%d crate%s stored · %d/%d", put, if put == 1 then "" else "s", w.Crates, cap), Color3.fromRGB(92, 196, 104))
	end)
end

local function source(player: Player, d: any, prop: string, n: number): any
	if jobs[player] then
		return { ok = false, err = "Finish your current run first" }
	end
	if not owns(d, prop) then
		return { ok = false, err = "You don't own that warehouse" }
	end
	n = math.clamp(math.floor(n), 1, Freight.SourceMax)
	local w = store(d, prop)
	local cap = Realty.Props[prop].cap or 0
	if w.Crates + n > cap then
		return { ok = false, err = "Not enough room (" .. w.Crates .. "/" .. cap .. ")" }
	end
	local cost = Freight.Source[n] * n
	if not EconomyService.spend(player, cost, "FreightSource") then
		return { ok = false, err = "Need $" .. cost }
	end
	local pickup = freePickup()
	local j: Job = { kind = "source", prop = prop, n = n, step = 0, stage = "load", at = os.clock(), folder = jobFolder(player), pickup = pickup }
	jobs[player] = j
	local stack: { Model } = {}
	for i = 1, n do
		local off = Vector3.new(((i - 1) % 2) * 2.8 - 1.4, 1.1 + math.floor((i - 1) / 2) * 2.2, 0)
		table.insert(stack, crate(j.folder, CFrame.new(pickup + off) * CFrame.Angles(0, math.rad(math.random(-6, 6)), 0)))
	end
	local _, pp = promptAt(j.folder, pickup + Vector3.new(0, 0, 2.5), "Load crate", "Liberty Imports", Freight.LoadSeconds, player)
	pp.Triggered:Connect(function(who)
		if who ~= player or jobs[player] ~= j or j.stage ~= "load" then
			return
		end
		j.step += 1
		local top = table.remove(stack)
		if top then
			top:Destroy()
		end
		if j.step >= j.n then
			pp.Parent:Destroy()
			startReturn(player, j)
		else
			pp.ObjectText = string.format("Liberty Imports · %d left", j.n - j.step)
		end
	end)
	WaypointService.set(player, WAY, pickup, { label = "Port pickup", radius = 12, breadcrumbs = true })
	Notify.objective(player, "Pick up " .. n .. " crate" .. (if n == 1 then "" else "s") .. " at the Port of Vice Bay")
	return { ok = true, cost = cost }
end

---------------------------------------------------------------- selling

local function nextDrop(player: Player, j: Job)
	local drops = j.drops :: any
	local dr = drops[j.step + 1]
	WaypointService.set(player, WAY, dr.at, { label = dr.name, radius = 12, breadcrumbs = true })
	Notify.objective(player, string.format("Deliver %d crate%s to %s (%d/%d)", dr.n, if dr.n == 1 then "" else "s", dr.name, j.step + 1, #drops))
	local anchor, pp = promptAt(j.folder, dr.at, "Hand over " .. dr.n .. " crate" .. (if dr.n == 1 then "" else "s"), dr.name, Freight.HandSeconds, player)
	pp.Triggered:Connect(function(who)
		if who ~= player or jobs[player] ~= j then
			return
		end
		anchor:Destroy()
		local d = DataService.get(player)
		if not d then
			return
		end
		local w = store(d, j.prop)
		w.Sold += dr.n
		local pay = (j.each :: number) * dr.n
		EconomyService.addCash(player, pay, "FreightSale", true, dr.at)
		EconomyService.addXP(player, Freight.XP.Sold * dr.n, "FreightSale", dr.at)
		DataService.push(player)
		j.step += 1
		if j.step >= #drops then
			endJob(player)
			Notify.banner(player, "SALE COMPLETE", string.format("%d crates · $%d each", j.n, j.each :: number), Color3.fromRGB(92, 196, 104))
		else
			nextDrop(player, j)
		end
	end)
end

local function sell(player: Player, d: any, prop: string, n: number): any
	if jobs[player] then
		return { ok = false, err = "Finish your current run first" }
	end
	if not owns(d, prop) then
		return { ok = false, err = "You don't own that warehouse" }
	end
	local w = store(d, prop)
	n = math.floor(n)
	if n < 1 or n > w.Crates then
		return { ok = false, err = "You have " .. w.Crates .. " crates" }
	end
	local count = FreightRules.drops(n, Freight.Drops)
	local split = FreightRules.split(n, count)
	local pool = table.clone(Freight.Buyers)
	local drops = {}
	for i = 1, count do
		local b = table.remove(pool, math.random(1, #pool))
		table.insert(drops, { name = b.name, at = b.at, n = split[i] })
	end
	w.Crates -= n -- on the road now; an expired sale puts the undelivered ones back
	DataService.push(player)
	local j: Job = { kind = "sell", prop = prop, n = n, step = 0, stage = "drop", drops = drops, each = FreightRules.each(n, Freight.SellCurve), at = os.clock(), folder = jobFolder(player) }
	jobs[player] = j
	nextDrop(player, j)
	return { ok = true, each = j.each, drops = count }
end

---------------------------------------------------------------- PC

local function state(player: Player, d: any): any
	local out = {}
	for _, id in Realty.Order do
		local p = Realty.Props[id]
		if p.kind == "freight" then
			local w = if owns(d, id) then store(d, id) else nil
			local ups = {}
			for uid, u in Freight.Upgrades do
				table.insert(ups, { id = uid, title = u.title, price = u.price, level = u.level, blurb = u.blurb, owned = w ~= nil and w.Upgrades[uid] == true })
			end
			table.sort(ups, function(a, b)
				return a.price < b.price
			end)
			table.insert(out, { id = id, title = p.title, area = p.area, cap = p.cap, owned = w ~= nil, crates = w and w.Crates or 0, sold = w and w.Sold or 0, upgrades = ups })
		end
	end
	local j = jobs[player]
	local curve = {}
	for _, n in { 1, 3, 12, 40, 100 } do
		table.insert(curve, { n = n, each = FreightRules.each(n, Freight.SellCurve) })
	end
	return {
		ok = true,
		warehouses = out,
		job = j and { kind = j.kind, prop = j.prop, n = j.n, step = j.step, stage = j.stage, left = math.max(0, Freight.JobMinutes * 60 - (os.clock() - j.at)) },
		source = Freight.Source,
		curve = curve,
		cash = d.Cash,
		level = d.Level,
	}
end

function FreightService.handle(player: Player, action: string, args: any): any
	local d = DataService.get(player)
	if not d then
		return { ok = false, err = "Still loading" }
	end
	args = if type(args) == "table" then args else {}
	local prop = tostring(args.prop)
	local res: any
	if action == "state" then
		return state(player, d)
	elseif action == "source" then
		res = source(player, d, prop, tonumber(args.n) or 1)
	elseif action == "sell" then
		res = sell(player, d, prop, tonumber(args.n) or 0)
	elseif action == "cancel" then
		local j = jobs[player]
		if j and j.kind == "sell" and j.drops then
			local back = 0
			for i = j.step + 1, #j.drops do
				back += j.drops[i].n
			end
			store(d, j.prop).Crates += back
		end
		endJob(player, "Run cancelled")
		res = { ok = true }
	elseif action == "upgrade" then
		local u = Freight.Upgrades[tostring(args.id)]
		if not u or not owns(d, prop) then
			return { ok = false, err = "Can't do that" }
		end
		local w = store(d, prop)
		if w.Upgrades[tostring(args.id)] then
			return { ok = false, err = "Already done" }
		end
		if (d.Level or 1) < u.level then
			return { ok = false, err = "Level " .. u.level }
		end
		if not EconomyService.spend(player, u.price, "FreightUpgrade") then
			return { ok = false, err = "Need $" .. u.price }
		end
		w.Upgrades[tostring(args.id)] = true
		DataService.push(player)
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

-- Raids while away: called from init on join (Freight.Raid). Returns a short line per hit warehouse.
local function settleAway(player: Player)
	local d = DataService.get(player)
	if not d or not d.Freight then
		return
	end
	local lastSeen = tonumber(d.LastSeen) or os.time()
	local days = math.floor((os.time() - lastSeen) / 86400)
	for id, w in d.Freight do
		local p = Realty.Props[id]
		if type(w) == "table" and p and p.cap and days > 0 and w.Crates >= p.cap * Freight.Raid.Full then
			local chance = Freight.Raid.Chance * (if w.Upgrades and w.Upgrades.Security then 0.5 else 1)
			for _ = 1, math.min(days, 7) do
				if math.random() < chance then
					local lost = math.max(1, math.floor(w.Crates * Freight.Raid.Lose))
					w.Crates -= lost
					Notify.toast(player, string.format("%s was hit while you were away: %d crates gone", p.title, lost), Color3.fromRGB(232, 84, 84))
				end
			end
		end
	end
end

function FreightService.init(_desk: any)
	Players.PlayerRemoving:Connect(function(p)
		local j = jobs[p]
		if j and j.kind == "sell" and j.drops then
			local d = DataService.get(p)
			if d then
				local back = 0
				for i = j.step + 1, #j.drops do
					back += j.drops[i].n
				end
				store(d, j.prop).Crates += back
			end
		end
		if j then
			j.folder:Destroy()
		end
		jobs[p] = nil
	end)
	Players.PlayerAdded:Connect(function(p)
		task.delay(8, settleAway, p)
	end)
	-- expiry + the sourcer upgrade (1 crate every N s while online)
	task.spawn(function()
		local tick = 0
		while true do
			task.wait(10)
			tick += 10
			for p, j in jobs do
				if os.clock() - j.at > Freight.JobMinutes * 60 then
					if j.kind == "sell" and j.drops then
						local d = DataService.get(p)
						if d then
							local back = 0
							for i = j.step + 1, #j.drops do
								back += j.drops[i].n
							end
							store(d, j.prop).Crates += back
						end
					end
					endJob(p, "Freight run timed out")
				end
			end
			if tick % Freight.Upgrades.Sourcer.every == 0 then
				for _, p in Players:GetPlayers() do
					local d = DataService.get(p)
					for id, w in (d and d.Freight or {}) do
						local cap = Realty.Props[id] and Realty.Props[id].cap
						if type(w) == "table" and w.Upgrades and w.Upgrades.Sourcer and cap and w.Crates < cap then
							w.Crates += 1
							Notify.toast(p, "Your sourcer dropped a crate at the " .. Realty.Props[id].title)
							DataService.push(p)
						end
					end
				end
			end
		end
	end)
end

return FreightService
