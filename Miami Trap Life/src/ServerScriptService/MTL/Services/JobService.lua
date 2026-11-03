--!strict
-- Jobs (Piece 2): picking a job, clocking in/out, handing out tasks, checking them, paying for them.
-- The server owns every decision: which task, which station, whether you're close enough, whether the minigame
-- took long enough, how much it pays. The client (JobController) only draws markers/minigames and reports.
--
-- API (Master Plan §3.5):
--   JobService.isOnShift(player) -> jobId?
--   JobService.current(player) -> jobId?                  the job the player has picked (data.Job.Current)
--   JobService.setJob(player, jobId, force?) -> ok, reason the same check the phone's CHOOSE button runs
--   JobService.clockIn(player, force?) -> ok, reason       force = skip the distance check (story/debug)
--   JobService.clockOut(player, reason?)                   reason: "player" | "left" | "story" | "switch" | ...
--   JobService.workplace(player) -> (Vector3?, label?)     where the player's job is (for the commute funnel)
--   JobService.addShiftGuard(fn(player, jobId) -> (ok, reason?))   e.g. MissionService: no shifts mid-mission
--   Signals: ClockedIn(player, jobId) · ClockedOut(player, jobId, reason) · TaskDone(player, jobId, taskId, paid, xp)
--            ShiftDone(player, jobId, shiftEarned, bonus) · JobChosen(player, jobId, oldJobId)
--
-- Story hooks wired here: FirstShift (story job, auto clock-in in the store), ChooseJob ends when a job is picked,
-- CommuteToWork ends when the player clocks in at their job, BlockedStages end the shift (Config/Jobs).
local CollectionService = game:GetService("CollectionService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.MTL.Net)
local Signal = require(ReplicatedStorage.MTL.Signal)
local Jobs = require(ReplicatedStorage.MTL.Config.Jobs)
local Locations = require(ReplicatedStorage.MTL.Config.Locations)
local JobRules = require(ReplicatedStorage.MTL.Rules.JobRules)
local StoryRules = require(ReplicatedStorage.MTL.Rules.StoryRules)
local Format = require(ReplicatedStorage.MTL.Format)
local DataService = require(script.Parent.DataService)
local EconomyService = require(script.Parent.EconomyService)
local StoryService = require(script.Parent.StoryService)
local PhoneService = require(script.Parent.PhoneService)
local WaypointService = require(script.Parent.WaypointService)
local Notify = require(script.Parent.Notify)
local Analytics = require(script.Parent.Analytics)
local RateLimiter = require(script.Parent.RateLimiter)

local JobService = {}
JobService.ClockedIn = Signal.new()
JobService.ClockedOut = Signal.new()
JobService.TaskDone = Signal.new()
JobService.ShiftDone = Signal.new()
JobService.JobChosen = Signal.new()

local V = Jobs.Validation
local rng = Random.new()
local function rand(): number
	return rng:NextNumber()
end

type Task = {
	id: number,
	key: string,
	step: number,
	stations: { string },
	items: { [number]: { string } },
	stepStartedAt: number,
	begunAt: number?,
	scores: { number },
}

type Shift = {
	job: string,
	session: string,
	startedAt: number,
	done: number,
	total: number,
	earned: number,
	complete: boolean,
	task: Task?,
	history: { string },
	lastStation: { [string]: string },
	waitingUntil: number?,
	leavingSince: number?,
	carry: string?,
	result: any?,
	-- post jobs
	postTimer: number,
	onPost: boolean,
	paused: boolean,
	checkInToken: string?,
	checkInDue: number,
}

local shifts: { [Player]: Shift } = {}
local guards: { (Player, string) -> (boolean, string?) } = {}
local taskCounter = 0
local limiter = RateLimiter.new(V.RatePerSecond, V.RatePerSecond * 2)

local function log(...)
	print("[MTL Jobs]", ...)
end

local function now(): number
	return os.clock()
end

---------------------------------------------------------------- positions

local function normal(s: string): string
	return (string.lower(s):gsub("[^%w]", ""))
end

-- The map's JobSpot parts (tagged by the Map thread, attribute Job = "Car Wash" ...) replace placeholder sites.
local function resolveMapSites()
	local spots = CollectionService:GetTagged("JobSpot")
	for jobId, def in Jobs.Defs do
		if not def.mapJob then
			continue
		end
		local wanted = {}
		for _, n in def.mapJob do
			wanted[normal(n)] = true
		end
		for _, spot in spots do
			local name = spot:GetAttribute("Job")
			if type(name) == "string" and wanted[normal(name)] then
				local pos = if spot:IsA("BasePart") then spot.Position elseif spot:IsA("Model") then spot:GetPivot().Position else nil
				local loc = Locations[def.site]
				if pos and type(loc) == "table" then
					local p = Vector3.new(pos.X, pos.Y + 1, pos.Z)
					loc.Inside, loc.Door, loc.Placeholder = p, p, false
					log("job site", jobId, "from map JobSpot", spot:GetFullName())
				end
				break
			end
		end
	end
end

local function siteCenter(jobId: string): Vector3
	local def = Jobs.Defs[jobId]
	local loc = Locations[def.site] :: any
	return loc.Inside or loc.Door
end

-- Returns position, radius, and the placeholder prop name (nil when a real map part marks the station).
local function station(jobId: string, stationId: string): (Vector3, number, string?)
	local def = Jobs.Defs[jobId]
	local cfg = def.stations[stationId]
	local folder = workspace:FindFirstChild("MTL_Stations")
	local jobFolder = folder and folder:FindFirstChild(jobId)
	local part = jobFolder and jobFolder:FindFirstChild(stationId)
	if part and part:IsA("BasePart") then
		local r = part:GetAttribute("Radius")
		local prop = part:GetAttribute("Prop") -- clear this attribute once a real map object stands there
		return part.Position, if type(r) == "number" then r else cfg.radius or 6, if type(prop) == "string" and prop ~= "" then prop else nil
	end
	if cfg.pos then
		return cfg.pos, cfg.radius or 6, cfg.prop
	end
	return siteCenter(jobId) + (cfg.offset or Vector3.zero), cfg.radius or 6, cfg.prop
end

local function root(player: Player): BasePart?
	local char = player.Character
	return char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function flatDistance(a: Vector3, b: Vector3): number
	local d = a - b
	return Vector2.new(d.X, d.Z).Magnitude
end

local function near(player: Player, pos: Vector3, radius: number): boolean
	local r = root(player)
	if not r then
		return false
	end
	return flatDistance(r.Position, pos) <= radius + V.StationSlack and math.abs(r.Position.Y - pos.Y) <= 20
end

local function atSite(player: Player, jobId: string): boolean
	local r = root(player)
	if not r then
		return false
	end
	local clockPos = station(jobId, "TimeClock")
	return flatDistance(r.Position, siteCenter(jobId)) <= V.ClockInRadius or flatDistance(r.Position, clockPos) <= V.ClockInRadius
end

---------------------------------------------------------------- carry (a prop in your hands, everyone sees it)

local stopAction: (Player) -> ()

local function removeCarry(player: Player, s: Shift)
	s.carry = nil
	if stopAction then
		stopAction(player)
	end
	local char = player.Character
	if not char then
		return
	end
	local prop = char:FindFirstChild("MTL_Carry")
	if prop then
		prop:Destroy()
	end
	local hum = char:FindFirstChildOfClass("Humanoid")
	local old = char:GetAttribute("MTL_WalkSpeedBeforeCarry")
	if hum and type(old) == "number" then
		hum.WalkSpeed = old
		char:SetAttribute("MTL_WalkSpeedBeforeCarry", nil)
	end
end

local function addCarry(player: Player, s: Shift, kind: string)
	removeCarry(player, s)
	local char = player.Character
	local r = root(player)
	local spec = Jobs.Carry.Props[kind]
	if not char or not r or not spec then
		return
	end
	s.carry = kind
	local part = Instance.new("Part")
	part.Name = "MTL_Carry"
	part.Shape = spec.shape or Enum.PartType.Block
	part.Size = spec.size
	part.Color = spec.color
	part.Material = spec.material or Enum.Material.SmoothPlastic
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Massless = true
	-- held in the hands: welded to the upper torso (two-handed) or the right hand, so it follows the pose
	local holder: BasePart = r
	if spec.attach == "Torso" then
		holder = (char:FindFirstChild("UpperTorso") or char:FindFirstChild("Torso") or r) :: BasePart
	elseif spec.attach == "RightHand" then
		holder = (char:FindFirstChild("RightHand") or char:FindFirstChild("Right Arm") or r) :: BasePart
	end
	local weld = Instance.new("Weld")
	weld.Part0 = holder
	weld.Part1 = part
	weld.C0 = if holder ~= r then (spec.at or CFrame.new(0, -0.5, -1.3)) else (spec.offset or CFrame.new(0, 0.2, -1.5))
	weld.Parent = part
	if spec.pose then
		part:SetAttribute("Pose", spec.pose)
	end
	-- A real model in ReplicatedStorage.MTL_JobProps.Carry.<kind> (pivot = its centre) replaces the plain part's look.
	local props = game:GetService("ReplicatedStorage"):FindFirstChild("MTL_JobProps")
	local template = props and props:FindFirstChild("Carry") and props.Carry:FindFirstChild(kind)
	if template and template:IsA("Model") then
		part.Transparency = 1
		part.CFrame = holder.CFrame * weld.C0
		local m = template:Clone()
		m:PivotTo(part.CFrame)
		for _, d in m:GetDescendants() do
			if d:IsA("BasePart") then
				d.Anchored = false
				d.CanCollide, d.CanQuery, d.CanTouch = false, false, false
				d.Massless = true
				local wc = Instance.new("WeldConstraint")
				wc.Part0 = part
				wc.Part1 = d
				wc.Parent = d
			end
		end
		m.Parent = part
	end
	part:SetAttribute("Kind", kind)
	part.Parent = char
	local hum = char:FindFirstChildOfClass("Humanoid")
	if hum then
		char:SetAttribute("MTL_WalkSpeedBeforeCarry", hum.WalkSpeed)
		hum.WalkSpeed = math.min(hum.WalkSpeed, Jobs.Carry.WalkSpeed)
	end
end

---------------------------------------------------------------- tool actions (a tool in the right hand + a body loop)
-- While a minigame step runs, the step's `action` goes on the character as the attribute MTL_Action (every client's
-- ActionPose loops that pose) and its `tool` (ReplicatedStorage.MTL_JobProps.Tools.<name>, PrimaryPart = Grip) is
-- welded into the right hand. Both go away when the step ends, is cancelled, the shift ends, or after a timeout.
local HAND_GRIP = CFrame.new(0, -0.25, 0) * CFrame.fromMatrix(Vector3.zero, Vector3.xAxis, -Vector3.zAxis, Vector3.yAxis)
local actionToken: { [Player]: number } = {}

function stopAction(player: Player)
	actionToken[player] = (actionToken[player] or 0) + 1
	local char = player.Character
	if not char then
		return
	end
	char:SetAttribute("MTL_Action", nil)
	local tool = char:FindFirstChild("MTL_JobTool")
	if tool then
		tool:Destroy()
	end
end

local function startAction(player: Player, step: any)
	stopAction(player)
	local char = player.Character
	if not char or type(step.action) ~= "string" then
		return
	end
	char:SetAttribute("MTL_Action", step.action)
	local props = ReplicatedStorage:FindFirstChild("MTL_JobProps")
	local tools = props and props:FindFirstChild("Tools")
	local template = tools and type(step.tool) == "string" and tools:FindFirstChild(step.tool)
	local hand = char:FindFirstChild("RightHand") :: BasePart?
	if template and template:IsA("Model") and template.PrimaryPart and hand then
		local m = template:Clone()
		m.Name = "MTL_JobTool"
		m:PivotTo(hand.CFrame * HAND_GRIP)
		for _, d in m:GetDescendants() do
			if d:IsA("BasePart") then
				d.Anchored = false
				d.CanCollide, d.CanQuery, d.CanTouch = false, false, false
				d.Massless = true
				local wc = Instance.new("WeldConstraint")
				wc.Part0 = hand
				wc.Part1 = d
				wc.Parent = d
			end
		end
		m.Parent = char
	end
	local token = actionToken[player]
	local secs = if type(step.seconds) == "number" then step.seconds else 10
	task.delay(secs + 4, function()
		if actionToken[player] == token then
			stopAction(player)
		end
	end)
end

---------------------------------------------------------------- state to the client

local function stationInfo(jobId: string, stationId: string): any
	local pos, radius, prop = station(jobId, stationId)
	return { id = stationId, pos = pos, radius = radius, prop = prop }
end

local function taskInfo(player: Player, s: Shift, t: Task): any
	local def = Jobs.Tasks[t.key]
	local step = def.steps[t.step]
	local data = DataService.get(player)
	local level = if data then data.Level else 1
	local doneBefore = if data then (data.Job.TasksDone[t.key] or 0) else 0
	local info: { [string]: any } = {
		id = t.id,
		key = t.key,
		title = def.title,
		step = t.step,
		steps = #def.steps,
		kind = step.kind,
		prompt = step.prompt,
		text = step.text,
		verb = step.verb,
		fx = step.fx,
		far = step.far,
		carrying = s.carry,
		station = stationInfo(s.job, t.stations[t.step]),
		hint = if doneBefore < 2 and t.step == 1 then def.hint else nil,
	}
	if step.kind == "hold" then
		info.seconds = JobRules.holdSeconds(step, level)
	elseif step.kind == "timing" then
		info.hits, info.zone, info.speed = step.hits or 3, step.zone or 0.22, step.speed or 1
	elseif step.kind == "sequence" then
		info.items = t.items[t.step]
		-- buttons: the ticket items plus (for big pools) a couple of decoys, shuffled
		local buttons = table.clone(info.items)
		if not step.keepOrder then
			for _, p in step.pool do
				if #buttons >= math.min(#step.pool, (step.count or 4) + 2) then
					break
				end
				if not table.find(buttons, p) then
					table.insert(buttons, p)
				end
			end
		end
		for i = #buttons, 2, -1 do
			local j = rng:NextInteger(1, i)
			buttons[i], buttons[j] = buttons[j], buttons[i]
		end
		info.buttons = buttons
	end
	return info
end

local function placeholderProps(jobId: string): { any }
	local out = {}
	for id in Jobs.Defs[jobId].stations do
		local pos, _, prop = station(jobId, id)
		if prop then
			table.insert(out, { id = id, prop = prop, pos = pos })
		end
	end
	return out
end

local function sendState(player: Player)
	local data = DataService.get(player)
	if not data or not player.Parent then
		return
	end
	local s = shifts[player]
	local jobId = if s then s.job else data.Job.Current
	local def = JobRules.def(jobId)
	if not def then
		Net.get("JobState"):FireClient(player, { job = nil })
		return
	end
	local st: { [string]: any } = {
		job = jobId,
		title = def.title,
		role = def.role,
		kind = def.kind,
		place = def.place,
		onShift = s ~= nil,
		clock = stationInfo(jobId, "TimeClock"),
		site = { pos = siteCenter(jobId), radius = V.ClockInRadius },
		props = placeholderProps(jobId),
		storyJob = data.Story.Stage == "FirstShift",
	}
	if s then
		st.shift = { done = s.done, total = s.total, earned = s.earned, complete = s.complete }
		if s.task then
			st.task = taskInfo(player, s, s.task)
		end
		if s.waitingUntil then
			st.waiting = math.max(0, s.waitingUntil - now())
		end
		if s.leavingSince then
			st.leaving = math.max(0, V.LeaveGrace - (now() - s.leavingSince))
		end
		if def.kind == "post" then
			local perMin = JobRules.perMinute(jobId, data.Level)
			st.post = { station = stationInfo(jobId, "Post"), onPost = s.onPost, paused = s.paused, checkIn = s.checkInToken, perMinute = perMin, payEvery = Jobs.Post.PayEvery, timer = s.postTimer }
		end
		st.result = s.result
		s.result = nil -- one-shot (the PERFECT flourish plays once)
	end
	Net.get("JobState"):FireClient(player, st)
end

---------------------------------------------------------------- tasks

local function assignTask(player: Player, s: Shift)
	local data = DataService.get(player)
	if not data then
		return
	end
	local key = JobRules.pickTask(s.job, data.Level, s.history, rand)
	if not key then
		s.task = nil
		return
	end
	table.insert(s.history, key)
	if #s.history > 6 then
		table.remove(s.history, 1)
	end
	taskCounter += 1
	local def = Jobs.Tasks[key]
	local t: Task = { id = taskCounter, key = key, step = 1, stations = {}, items = {}, stepStartedAt = now(), begunAt = nil, scores = {} }
	for i, step in def.steps do
		local memo = key .. "#" .. i
		t.stations[i] = JobRules.pickStation(step.at, s.lastStation[memo], rand)
		s.lastStation[memo] = t.stations[i]
		if step.kind == "sequence" then
			t.items[i] = JobRules.sequenceItems(step, rand)
		end
	end
	s.task = t
	s.waitingUntil = nil
end

local function bossText(player: Player, jobId: string, which: string)
	local def = Jobs.Defs[jobId]
	local lines = def.boss and Jobs.BossLines[def.boss]
	local line = lines and lines[which]
	if type(line) == "table" then
		line = line[rng:NextInteger(1, #line)]
	end
	if type(line) == "string" then
		PhoneService.text(player, def.boss, line)
	end
end

local function finishShift(player: Player, s: Shift)
	local data = DataService.get(player)
	if not data then
		return
	end
	s.complete = true
	s.task = nil
	s.waitingUntil = nil
	removeCarry(player, s)
	data.Job.Shifts[s.job] = (data.Job.Shifts[s.job] or 0) + 1
	local share = JobRules.shiftBonusShare(data.Level)
	local bonus = 0
	if share > 0 and s.earned > 0 then
		bonus = EconomyService.addCash(player, math.floor(s.earned * share + 0.5), "Job:ShiftBonus", false)
	end
	local sub = if bonus > 0 then ("+" .. Format.cash(bonus) .. " shift bonus")
		else ("Earned " .. Format.cash(s.earned) .. ". Shift bonus unlocks at Level " .. Jobs.Shift.BonusLevel)
	Notify.banner(player, "SHIFT COMPLETE", sub)
	local count = data.Job.Shifts[s.job]
	if count <= 2 or count % 3 == 0 then
		bossText(player, s.job, "ShiftDone")
	end
	Analytics.funnel(player, "Shift", s.session, 4, "ShiftDone")
	JobService.ShiftDone:Fire(player, s.job, s.earned, bonus)
	log(player.Name, "finished a shift at", s.job, "earned", s.earned, "bonus", bonus)
end

local function completeTask(player: Player, s: Shift, t: Task, at: Vector3)
	local data = DataService.get(player)
	if not data then
		return
	end
	local def = Jobs.Tasks[t.key]
	local score: number? = nil
	for _, sc in t.scores do
		score = if score then math.min(score, sc) else sc
	end
	local distance: number? = nil
	if def.distancePay then
		local a = station(s.job, t.stations[1])
		local b = station(s.job, t.stations[#def.steps])
		distance = flatDistance(a, b)
	end
	local pay, xp, label = JobRules.taskReward(t.key, data.Level, score, distance)
	removeCarry(player, s)
	local paid = EconomyService.addCash(player, pay, "Job:" .. s.job, true, at)
	local gotXP = EconomyService.addXP(player, xp, "Job:" .. s.job, at)
	s.earned += paid
	s.done += 1
	local before = data.Job.TasksDone[t.key] or 0
	data.Job.TasksDone[t.key] = before + 1
	s.result = { label = label, cash = paid, xp = gotXP, at = at, perfectBonus = label == "PERFECT" and data.Level >= Jobs.Quality.PerfectBonusLevel }
	JobService.TaskDone:Fire(player, s.job, t.key, paid, gotXP)
	if s.done == 1 then
		Analytics.funnel(player, "Shift", s.session, 2, "FirstTask")
		local total = 0
		for _, n in data.Job.TasksDone do
			total += n
		end
		if total == 1 then
			bossText(player, s.job, "FirstTask") -- the very first task in the game
		end
	elseif s.done == math.floor(s.total / 2) then
		Analytics.funnel(player, "Shift", s.session, 3, "HalfShift")
	end
	if s.done >= s.total then
		finishShift(player, s)
		return
	end
	local jobDef = Jobs.Defs[s.job]
	if jobDef.gap then
		s.task = nil
		s.waitingUntil = now() + rng:NextNumber(jobDef.gap[1], jobDef.gap[2])
	else
		assignTask(player, s)
	end
end

---------------------------------------------------------------- shifts

function JobService.isOnShift(player: Player): string?
	local s = shifts[player]
	return if s then s.job else nil
end

function JobService.current(player: Player): string?
	local data = DataService.get(player)
	local id = data and data.Job.Current
	return if id and id ~= "" then id else nil
end

function JobService.workplace(player: Player): (Vector3?, string?)
	local id = JobService.current(player)
	if not id then
		return nil, nil
	end
	local loc = Locations[Jobs.Defs[id].site] :: any
	return loc.Door or loc.Inside, Jobs.Defs[id].title
end

function JobService.addShiftGuard(fn: (Player, string) -> (boolean, string?))
	table.insert(guards, fn)
end

function JobService.clockOut(player: Player, reason: string?)
	local s = shifts[player]
	if not s then
		return
	end
	removeCarry(player, s)
	shifts[player] = nil
	local why = reason or "player"
	if why == "player" then
		Notify.toast(player, "Clocked out. This shift: " .. Format.cash(s.earned))
	elseif why == "left" then
		Notify.toast(player, "You left work, so your shift ended.")
	end
	log(player.Name, "clocked out of", s.job, why)
	JobService.ClockedOut:Fire(player, s.job, why)
	sendState(player)
	-- the story shift can't be abandoned: point back at the store (walking in clocks you in again)
	if StoryService.stage(player) == "FirstShift" and why ~= "story" then
		local loc = Locations[Jobs.Defs[Jobs.StoryJob].site] :: any
		WaypointService.set(player, "Story", loc.Door, { label = Jobs.Defs[Jobs.StoryJob].title, radius = loc.Radius })
	end
end

local function startShift(player: Player, jobId: string)
	local def = Jobs.Defs[jobId]
	local s: Shift = {
		job = jobId,
		session = HttpService:GenerateGUID(false),
		startedAt = now(),
		done = 0,
		total = JobRules.shiftLength(jobId),
		earned = 0,
		complete = false,
		task = nil,
		history = if shifts[player] then shifts[player].history else {},
		lastStation = {},
		waitingUntil = nil,
		leavingSince = nil,
		carry = nil,
		result = nil,
		postTimer = 0,
		onPost = false,
		paused = false,
		checkInToken = nil,
		checkInDue = now() + Jobs.Post.CheckInEvery,
	}
	shifts[player] = s
	if def.kind == "tasks" then
		assignTask(player, s)
	end
	Analytics.funnel(player, "Shift", s.session, 1, "ClockIn")
end

function JobService.clockIn(player: Player, force: boolean?): (boolean, string?)
	local data = DataService.get(player)
	if not data then
		return false, "Loading"
	end
	if shifts[player] then
		return false, "You're already on shift"
	end
	local jobId = data.Job.Current
	local ok, reason = JobRules.canWork(jobId, data.Level, data.Story.Stage)
	if not ok then
		return false, reason
	end
	for _, g in guards do
		local gOk, gReason = g(player, jobId)
		if not gOk then
			return false, gReason or "Not now"
		end
	end
	if not force and not atSite(player, jobId) then
		return false, "Go to " .. Jobs.Defs[jobId].title .. " to clock in"
	end
	startShift(player, jobId)
	local def = Jobs.Defs[jobId]
	Notify.toast(player, "Clocked in: " .. def.role .. " at " .. def.title)
	log(player.Name, "clocked in at", jobId)
	JobService.ClockedIn:Fire(player, jobId)
	sendState(player)
	return true, nil
end

local function nextShift(player: Player)
	local s = shifts[player]
	if not s or not s.complete then
		return
	end
	startShift(player, s.job)
	sendState(player)
end

-- Picks the player's job (the phone's CHOOSE button). force = skip the stage/level rules (story/debug).
function JobService.setJob(player: Player, jobId: string, force: boolean?): (boolean, string?)
	local data = DataService.get(player)
	if not data or not Jobs.Defs[jobId] then
		return false, "Unknown job"
	end
	if not force then
		local ok, reason = JobRules.canChoose(jobId, data.Level, data.Story.Stage)
		if not ok then
			return false, reason
		end
	end
	local old = data.Job.Current
	if old == jobId then
		if data.Story.Stage == Jobs.ChooseFromStage then
			-- Piece 4: at ChooseJob you still hold the story job (the Food Mart); picking it again is a real choice
			JobService.JobChosen:Fire(player, jobId, old)
			sendState(player)
			return true, nil
		end
		return false, "That's already your job"
	end
	if shifts[player] then
		JobService.clockOut(player, "switch")
	end
	data.Job.Current = jobId
	player:SetAttribute("MTL_Job", jobId)
	DataService.push(player)
	JobService.JobChosen:Fire(player, jobId, old)
	sendState(player)
	return true, nil
end

---------------------------------------------------------------- client actions

local function onStepAction(player: Player, s: Shift, payload: any, begin: boolean)
	local t = s.task
	if not t or payload.task ~= t.id or payload.step ~= t.step then
		sendState(player) -- out of sync (lag, double press): resend the truth
		return
	end
	local def = Jobs.Tasks[t.key]
	local step = def.steps[t.step]
	local pos, radius = station(s.job, t.stations[t.step])
	if not near(player, pos, radius) then
		Notify.toast(player, "Get closer")
		sendState(player)
		return
	end
	local data = DataService.get(player)
	local level = if data then data.Level else 1
	if begin then
		if JobRules.isMinigame(step.kind) then
			t.begunAt = now()
			startAction(player, step)
		end
		return
	end
	stopAction(player)
	if now() - t.stepStartedAt < V.MinPromptSeconds then
		return
	end
	if JobRules.isMinigame(step.kind) then
		if not t.begunAt or now() - t.begunAt < JobRules.minStepSeconds(step, level) then
			log(player.Name, "step too fast", t.key, t.step)
			t.begunAt = nil
			sendState(player)
			return
		end
		local score = if type(payload.score) == "number" and payload.score == payload.score then math.clamp(payload.score, 0, 1) else 0.8
		table.insert(t.scores, score)
	end
	-- what this step does to your hands
	if step.kind == "drop" then
		removeCarry(player, s)
	end
	if step.carry then
		addCarry(player, s, step.carry)
	end
	if t.step >= #def.steps then
		completeTask(player, s, t, pos)
	else
		t.step += 1
		t.stepStartedAt = now()
		t.begunAt = nil
	end
	sendState(player)
end

local function onCheckIn(player: Player, s: Shift, payload: any)
	if s.checkInToken and payload.token == s.checkInToken then
		s.checkInToken = nil
		s.paused = false
		s.checkInDue = now() + Jobs.Post.CheckInEvery
		Notify.toast(player, "Checked in. Back on the clock.")
		sendState(player)
	end
end

local function onJobAction(player: Player, payload: any)
	if type(payload) ~= "table" or type(payload.type) ~= "string" or not limiter:allow(player) then
		return
	end
	if not DataService.get(player) then
		return
	end
	local kind = payload.type
	if kind == "clockIn" then
		local ok, reason = JobService.clockIn(player)
		if not ok and reason then
			Notify.toast(player, reason)
		end
		return
	elseif kind == "clockOut" then
		JobService.clockOut(player, "player")
		return
	elseif kind == "sync" then
		sendState(player)
		return
	end
	local s = shifts[player]
	if not s then
		return
	end
	if kind == "begin" or kind == "step" then
		onStepAction(player, s, payload, kind == "begin")
	elseif kind == "cancel" then
		stopAction(player) -- walked away from the minigame: put the tool down
	elseif kind == "checkIn" then
		onCheckIn(player, s, payload)
	elseif kind == "nextShift" then
		nextShift(player)
	end
end

---------------------------------------------------------------- the shift loop (1 Hz)

local function tickPost(player: Player, s: Shift, dt: number)
	local data = DataService.get(player)
	if not data or s.complete then
		return
	end
	local pos, radius = station(s.job, "Post")
	local onPost = near(player, pos, radius)
	local changed = onPost ~= s.onPost
	s.onPost = onPost
	if not s.checkInToken and now() >= s.checkInDue then
		s.checkInToken = HttpService:GenerateGUID(false)
		s.paused = true
		changed = true
		PhoneService.notify(player, { app = "Jobs", title = "Radio", text = "Still on post? Check in to keep getting paid." })
	end
	if onPost and not s.paused then
		s.postTimer += dt
		if s.postTimer >= Jobs.Post.PayEvery then
			s.postTimer -= Jobs.Post.PayEvery
			local pay, xp = JobRules.postTick(s.job, data.Level)
			local paid = EconomyService.addCash(player, pay, "Job:" .. s.job, true, pos)
			EconomyService.addXP(player, xp, "Job:" .. s.job, pos)
			s.earned += paid
			s.done += 1
			if s.done >= s.total then
				finishShift(player, s)
			end
			changed = true
		end
	end
	if changed then
		sendState(player)
	end
end

local function tick(dt: number)
	local t = now()
	for player, s in shifts do
		if not player.Parent then
			shifts[player] = nil
			continue
		end
		local r = root(player)
		if not r then
			continue
		end
		local def = Jobs.Defs[s.job]
		-- left work?
		local leaveRadius = def.leaveRadius or V.LeaveRadius
		local away = flatDistance(r.Position, siteCenter(s.job)) > leaveRadius
		if away and not s.leavingSince then
			s.leavingSince = t
			Notify.toast(player, "Head back to work or your shift ends in " .. V.LeaveGrace .. "s", Color3.fromRGB(255, 205, 80))
			sendState(player)
		elseif not away and s.leavingSince then
			s.leavingSince = nil
			sendState(player)
		elseif away and s.leavingSince and t - s.leavingSince >= V.LeaveGrace then
			JobService.clockOut(player, "left")
			continue
		end
		if def.kind == "post" then
			tickPost(player, s, dt)
		elseif s.waitingUntil and t >= s.waitingUntil and not s.complete then
			assignTask(player, s)
			sendState(player)
		end
	end
end

---------------------------------------------------------------- story

local function wireStory()
	-- 2. FirstShift: the story job is set for you and you clock in when you walk into the store
	StoryService.onEnter("FirstShift", function(player)
		local data = DataService.get(player)
		if not data then
			return
		end
		if data.Job.Current == "" then
			data.Job.Current = Jobs.StoryJob
			player:SetAttribute("MTL_Job", Jobs.StoryJob)
			DataService.push(player)
		end
		if atSite(player, Jobs.StoryJob) then
			JobService.clockIn(player, true)
		else
			local loc = Locations[Jobs.Defs[Jobs.StoryJob].site] :: any
			WaypointService.set(player, "Story", loc.Door, { label = Jobs.Defs[Jobs.StoryJob].title, radius = loc.Radius })
		end
		sendState(player)
	end)
	WaypointService.Arrived:Connect(function(player, id)
		if id == "Story" and StoryService.stage(player) == "FirstShift" and not shifts[player] then
			JobService.clockIn(player, true)
		end
	end)

	-- stages that can't have a shift (robbery, cutscenes) end it
	StoryService.StageChanged:Connect(function(player, newStage)
		if Jobs.BlockedStages[newStage] and shifts[player] then
			JobService.clockOut(player, "story")
		end
		sendState(player)
	end)

	-- 10. ChooseJob ends when a job is picked; 12. CommuteToWork ends when you clock in there
	JobService.JobChosen:Connect(function(player)
		StoryService.advance(player, "ChooseJob")
	end)
	JobService.ClockedIn:Connect(function(player)
		StoryService.advance(player, "CommuteToWork")
	end)

	-- new jobs on level-up -> a phone ping (only once the player picks their own job)
	EconomyService.LevelUp:Connect(function(player, level)
		local stage = StoryService.stage(player)
		if not stage or not StoryRules.reached(stage, Jobs.ChooseFromStage) then
			return
		end
		for _, id in JobRules.unlockedAt(level) do
			local def = Jobs.Defs[id]
			PhoneService.notify(player, { app = "Jobs", title = "New job unlocked", text = def.role .. " at " .. def.title })
		end
		sendState(player)
	end)
end

---------------------------------------------------------------- init

function JobService.init()
	resolveMapSites()
	-- station marker parts (tools/PlaceJobStations.lua) are for editing only: invisible in game
	local stations = workspace:FindFirstChild("MTL_Stations")
	if stations then
		for _, d in stations:GetDescendants() do
			if d:IsA("BasePart") then
				d.Transparency = 1
				d.CanCollide = false
				d.CanQuery = false
			end
		end
	end

	Net.get("JobAction").OnServerEvent:Connect(function(player, payload)
		local ok, err = pcall(onJobAction, player, payload)
		if not ok then
			warn("[MTL Jobs] action failed:", err)
		end
	end)

	-- the phone's CHOOSE button
	PhoneService.onAction("chooseJob", function(player, payload)
		if type(payload.job) ~= "string" then
			return
		end
		local ok, reason = JobService.setJob(player, payload.job)
		if not ok then
			Notify.toast(player, reason or "Can't pick that job")
			return
		end
		local def = Jobs.Defs[payload.job]
		Notify.toast(player, "New job: " .. def.role .. " at " .. def.title)
		if StoryService.stage(player) == "FreePlay" then
			PhoneService.route(player, def.place)
		end
	end)

	DataService.Ready:Connect(function(player, data)
		if data.Job.Current ~= "" and not Jobs.Defs[data.Job.Current] then
			data.Job.Current = "" -- a job that was removed from the config
		end
		player:SetAttribute("MTL_Job", if data.Job.Current ~= "" then data.Job.Current else nil)
		task.defer(sendState, player)
	end)
	Net.get("ClientReady").OnServerEvent:Connect(function(player)
		sendState(player)
	end)

	-- dying drops what you carry; the step goes back to the pickup
	local function watchCharacter(player: Player)
		player.CharacterRemoving:Connect(function()
			local s = shifts[player]
			if not s then
				return
			end
			s.carry = nil
			local t = s.task
			if t and t.step > 1 then
				t.step, t.stepStartedAt, t.begunAt, t.scores = 1, now(), nil, {}
				task.delay(1, sendState, player)
			end
		end)
	end
	Players.PlayerAdded:Connect(watchCharacter)
	for _, p in Players:GetPlayers() do
		watchCharacter(p)
	end
	Players.PlayerRemoving:Connect(function(player)
		shifts[player] = nil
		actionToken[player] = nil
	end)

	wireStory()

	task.spawn(function()
		local last = now()
		while true do
			task.wait(1)
			local t = now()
			local ok, err = pcall(tick, t - last)
			if not ok then
				warn("[MTL Jobs] tick failed:", err)
			end
			last = t
		end
	end)
	log("ready:", #Jobs.Order, "jobs")
end

-- Studio testing (server Command Bar): _G.MTL.Jobs.debug(player, "Mechanic") -> picks it and clocks in where you stand
function JobService.debug(player: Player, jobId: string)
	assert(game:GetService("RunService"):IsStudio(), "[MTL Jobs] debug is Studio-only")
	if shifts[player] then
		JobService.clockOut(player, "debug")
	end
	local data = DataService.get(player)
	if data then
		data.Job.Current = jobId
	end
	return JobService.clockIn(player, true)
end

return JobService
