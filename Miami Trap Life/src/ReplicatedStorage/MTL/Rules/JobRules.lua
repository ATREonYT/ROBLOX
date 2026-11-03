--!strict
-- Pure job maths and rules (no Instances): which jobs a player sees and may work, which task comes next,
-- how a minigame score turns into pay and XP, shift bonuses, and the minimum time a step may take
-- (the server's anti-exploit check). Shared by JobService, JobController, the Jobs app and the unit tests.
local Jobs = require(script.Parent.Parent.Config.Jobs)
local StoryRules = require(script.Parent.StoryRules)

local JobRules = {}

function JobRules.def(jobId: any): any?
	return if type(jobId) == "string" then Jobs.Defs[jobId] else nil
end

function JobRules.task(taskId: any): any?
	return if type(taskId) == "string" then Jobs.Tasks[taskId] else nil
end

---------------------------------------------------------------- who can see / pick / work a job

-- Jobs listed in the phone at this story stage.
--   before ChooseJob : only the story job (Mr. Patel is expecting you)
--   ChooseJob        : the 3 starter jobs (the story beat)
--   after            : every job (locked ones show their level)
function JobRules.visibleJobs(stage: string): { string }
	if stage == Jobs.ChooseFromStage then
		return table.clone(Jobs.StarterJobs)
	end
	if not StoryRules.reached(stage, Jobs.ChooseFromStage) then
		return { Jobs.StoryJob }
	end
	return table.clone(Jobs.Order)
end

function JobRules.isVisible(jobId: string, stage: string): boolean
	return table.find(JobRules.visibleJobs(stage), jobId) ~= nil
end

-- May this player pick `jobId` as their job right now?
function JobRules.canChoose(jobId: any, level: number, stage: string): (boolean, string?)
	local def = JobRules.def(jobId)
	if not def then
		return false, "Unknown job"
	end
	if not StoryRules.reached(stage, Jobs.ChooseFromStage) then
		return false, "Finish your shifts at the Food Mart first"
	end
	if not JobRules.isVisible(jobId, stage) then
		return false, "Not hiring right now"
	end
	if level < def.level then
		return false, "Reach Level " .. def.level
	end
	return true, nil
end

-- May this player clock in to `jobId` right now?
function JobRules.canWork(jobId: any, level: number, stage: string): (boolean, string?)
	local def = JobRules.def(jobId)
	if not def then
		return false, "Pick a job in the Jobs app"
	end
	if Jobs.BlockedStages[stage] then
		return false, "Not now"
	end
	if level < def.level then
		return false, "Reach Level " .. def.level
	end
	return true, nil
end

-- Job ids that unlock exactly at `level` (for the level-up phone ping).
function JobRules.unlockedAt(level: number): { string }
	local out = {}
	for _, id in Jobs.Order do
		if Jobs.Defs[id].level == level and level > 1 then
			table.insert(out, id)
		end
	end
	return out
end

---------------------------------------------------------------- tasks

-- Tasks of this job the player can get at this level.
function JobRules.availableTasks(jobId: string, level: number): { string }
	local def = JobRules.def(jobId)
	local out = {}
	if not def or not def.tasks then
		return out
	end
	for _, id in def.tasks do
		local t = Jobs.Tasks[id]
		if t and (t.level or 1) <= level then
			table.insert(out, id)
		end
	end
	return out
end

-- Weighted pick of the next task. `history` = recent task ids, newest last. A task never comes up a
-- third time in a row (variety inside a shift). `rand()` returns [0, 1).
function JobRules.pickTask(jobId: string, level: number, history: { string }, rand: () -> number): string?
	local pool = JobRules.availableTasks(jobId, level)
	if #pool == 0 then
		return nil
	end
	local n = #history
	local banned: string? = nil
	if n >= 2 and history[n] == history[n - 1] and #pool > 1 then
		banned = history[n]
	end
	-- the task you just did is much less likely to come straight back (play-test 2026-11-02: Trash, Trash)
	local last = if #pool > 1 then history[n] else nil
	local function weight(id: string): number
		local w = Jobs.Tasks[id].weight or 1
		return if id == last then w * Jobs.RepeatWeight else w
	end
	local total = 0
	for _, id in pool do
		if id ~= banned then
			total += weight(id)
		end
	end
	local r = rand() * total
	for _, id in pool do
		if id ~= banned then
			r -= weight(id)
			if r < 0 then
				return id
			end
		end
	end
	for i = #pool, 1, -1 do
		if pool[i] ~= banned then
			return pool[i]
		end
	end
	return pool[1]
end

-- Picks a station id from a step's `at` list, avoiding `last` when there's a choice.
function JobRules.pickStation(at: { string }, last: string?, rand: () -> number): string
	if #at == 1 then
		return at[1]
	end
	local options = {}
	for _, s in at do
		if s ~= last then
			table.insert(options, s)
		end
	end
	if #options == 0 then
		options = at
	end
	return options[math.clamp(math.floor(rand() * #options) + 1, 1, #options)]
end

-- The ordered items for a sequence step. keepOrder = the pool IS the order (oil change);
-- otherwise `count` random items from the pool, in random order (burger ticket).
function JobRules.sequenceItems(step: any, rand: () -> number): { string }
	local pool = table.clone(step.pool or {})
	if step.keepOrder then
		return pool
	end
	local out = {}
	local count = math.min(step.count or #pool, #pool)
	for _ = 1, count do
		local i = math.clamp(math.floor(rand() * #pool) + 1, 1, #pool)
		table.insert(out, table.remove(pool, i) :: string)
	end
	return out
end

-- Seconds a hold minigame takes at this level (Quick hands perk).
function JobRules.holdSeconds(step: any, level: number): number
	local s = step.seconds or 3
	if level >= Jobs.QuickHandsLevel then
		s *= Jobs.QuickHandsScale
	end
	return s
end

-- The fastest an honest player can finish this step after it began (server check).
function JobRules.minStepSeconds(step: any, level: number): number
	local V = Jobs.Validation
	if step.kind == "hold" then
		return JobRules.holdSeconds(step, level) * V.HoldTolerance
	elseif step.kind == "timing" then
		return (step.hits or 3) * V.TimingMinPerHit
	elseif step.kind == "sequence" then
		return (step.count or 4) * V.SequenceMinPerItem
	end
	return V.MinPromptSeconds
end

function JobRules.isMinigame(kind: string): boolean
	return kind == "hold" or kind == "timing" or kind == "sequence"
end

---------------------------------------------------------------- scores (0..1, computed on the client, clamped on the server)

function JobRules.scoreHold(releases: number): number
	return math.clamp(1 - 0.15 * releases, 0.4, 1)
end

function JobRules.scoreTiming(hits: number, misses: number): number
	if hits <= 0 then
		return 0.4
	end
	return math.clamp(hits / (hits + misses), 0.4, 1)
end

function JobRules.scoreSequence(mistakes: number): number
	return math.clamp(1 - 0.2 * mistakes, 0.4, 1)
end

---------------------------------------------------------------- pay and XP

-- Multiplier from level pay raises (Level 6: +10%, Level 9: +20%).
function JobRules.payRaise(level: number): number
	local m = 1
	for _, r in Jobs.PayRaises do
		if level >= r.level then
			m += r.share
		end
	end
	return m
end

-- score -> multiplier, label ("PERFECT" | "" | "SLOPPY"). The PERFECT bonus (tips) starts at Quality.PerfectBonusLevel.
function JobRules.quality(score: number?, level: number?): (number, string)
	local Q = Jobs.Quality
	if score == nil then
		return 1, ""
	end
	if score >= Q.Perfect then
		local bonus = if (level or 1) >= Q.PerfectBonusLevel then Q.PerfectBonus else 0
		return 1 + bonus, "PERFECT"
	elseif score < Q.Good then
		return 1 - Q.SloppyPenalty, "SLOPPY"
	end
	return 1, ""
end

-- Base pay and XP for finishing a task (before the 2x passes/boosts, which EconomyService applies).
-- `score` = the minigame score (nil if the task had no minigame), `distance` = studs (route jobs).
function JobRules.taskReward(taskId: string, level: number, score: number?, distance: number?): (number, number, string)
	local t = Jobs.Tasks[taskId]
	if not t then
		return 0, 0, ""
	end
	local q, label = JobRules.quality(score, level)
	local pay = t.pay * JobRules.payRaise(level) * q
	if t.distancePay and distance then
		pay += t.distancePay * math.max(0, distance)
	end
	local xp = t.xp * q
	return math.floor(pay + 0.5), math.floor(xp + 0.5), label
end

-- Post jobs: pay and XP per pay tick.
function JobRules.postTick(jobId: string, level: number): (number, number)
	local def = Jobs.Defs[jobId]
	if not def or def.kind ~= "post" then
		return 0, 0
	end
	local share = Jobs.Post.PayEvery / 60
	return math.floor(def.perMinute * share * JobRules.payRaise(level) + 0.5), math.floor((def.xpPerMinute or 0) * share + 0.5)
end

function JobRules.shiftBonusShare(level: number): number
	local S = Jobs.Shift
	if level >= S.BigBonusLevel then
		return S.BigBonusShare
	elseif level >= S.BonusLevel then
		return S.BonusShare
	end
	return 0
end

function JobRules.shiftLength(jobId: string): number
	local def = Jobs.Defs[jobId]
	return if def and def.kind == "post" then Jobs.Shift.PostTicks else Jobs.Shift.Tasks
end

-- Rough $/min and XP/min for the app ("about $24/min"). Uses each task's `est` seconds + the job's gap.
function JobRules.perMinute(jobId: string, level: number): (number, number)
	local def = Jobs.Defs[jobId]
	if not def then
		return 0, 0
	end
	if def.kind == "post" then
		return math.floor(def.perMinute * JobRules.payRaise(level) + 0.5), def.xpPerMinute or 0
	end
	local pool = JobRules.availableTasks(jobId, math.max(level, def.level))
	local wsum, cash, xp, secs = 0, 0, 0, 0
	local gap = if def.gap then (def.gap[1] + def.gap[2]) / 2 else 0
	for _, id in pool do
		local t = Jobs.Tasks[id]
		local w = t.weight or 1
		wsum += w
		cash += w * (t.pay + (t.distancePay or 0) * (t.estDistance or 0))
		xp += w * t.xp
		secs += w * ((t.est or 20) + gap)
	end
	if wsum == 0 or secs == 0 then
		return 0, 0
	end
	local perSec = 60 / secs
	return math.floor(cash * perSec * JobRules.payRaise(level) + 0.5), math.floor(xp * perSec + 0.5)
end

-- "Chill" label for the app.
function JobRules.tierLabel(tier: number): string
	if tier >= 3 then
		return "AFK-friendly"
	elseif tier == 2 then
		return "Laid back"
	end
	return "Hands-on"
end

return JobRules
