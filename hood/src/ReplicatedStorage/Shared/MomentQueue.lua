-- MomentQueue (Oct 27, flow round: the owner's "the feel of the game feels rushed, there is no flow"; the audit
-- hood/docs/research/OUR_FIRST_10_MIN.md found five GOAL DONE moments, banners and notices landing on one another in
-- the first 25 seconds). ONE voice at a time, client-side: every popup that wants the middle or the top of the screen
-- (the first-join welcome, GOAL DONE / YOU'RE READY!, the rank-up, the rebirth moment, the new-gun reveal, the shoe box
-- introduction, the HUD's notices) asks here first and waits its turn, and after each one the screen stays calm for a
-- moment before the next: Gap seconds after a small one, BigGap after a big one.
--   MomentQueue.acquire(name, opts?) -> token | nil   yields until it is this one's turn. opts:
--       Size     'big' (default) | 'small'
--       Ready    function() -> boolean: may it start now? (not in a fight, no window open...); it waits while false
--       Timeout  seconds to wait at most (default 30); nil comes back when it ran out (the caller drops its moment)
--       Priority number (default 0) or function() -> number: among the moments that may start, the highest goes first
--                (round 8: the tutorial's "YOU'RE READY!" lands within ~3 s of its last step, ahead of a GOAL DONE)
--   MomentQueue.release(token)                        the moment has left the screen: the calm starts now
--   MomentQueue.mark(name, seconds, size?)            a moment that cannot wait (the fight's "CREW INCOMING!"): it takes
--                                                     the screen now, for `seconds`, and the calm follows it
--   MomentQueue.busy() -> boolean                     a moment is on screen
--   MomentQueue.current() -> name | nil
-- PlayerGui's attribute HoodMoment is the name of the moment on screen ('' when none): other scripts (the tutorial's
-- hint, the level toasts) step aside for it, and the play-test tools read it.
-- The order is the highest Priority first, then first come, first served, among the moments whose Ready says yes. A token never released (a script
-- error) frees the screen after MaxHold seconds, so nothing can lock the queue.
-- The pure part (gapAfter, pick) is unit-tested (UnitTest/Cases/Flow_Test).
local MomentQueue = {}
MomentQueue.Gap = 1.5 -- calm seconds after a small moment (a notice) before the next one
MomentQueue.BigGap = 2.5 -- calm seconds after a big one (the owner's "breathing room": 2-3 s)
MomentQueue.MaxHold = 20 -- a token older than this is let go
MomentQueue.Poll = 0.05

-- The calm owed after a moment of `size` ('big' | 'small').
function MomentQueue.gapAfter(size: string?): number
	return size == 'small' and MomentQueue.Gap or MomentQueue.BigGap
end

-- Which waiter starts now (pure): waiters = { { Ready = bool, Priority = number? }, ... } in arrival order; state =
-- { Active = bool, Now = number, CalmUntil = number }. Returns the index of the Ready one with the highest Priority (the
-- earliest of equals), or nil when none may start yet.
function MomentQueue.pick(waiters: { any }, state: any): number?
	if type(state) ~= 'table' or state.Active then return nil end
	if type(state.Now) == 'number' and type(state.CalmUntil) == 'number' and state.Now < state.CalmUntil then return nil end
	local best, bestP = nil, -math.huge
	for i, w in waiters do
		local p = type(w.Priority) == 'number' and w.Priority or 0
		if w.Ready and p > bestP then best, bestP = i, p end
	end
	return best
end

---------------------------------------------------------------------------------------------- the live queue (client)
local active = nil -- { Name, Size, At, Until? }
local calmUntil = 0
local waiters = {}
local function now() return os.clock() end
local function publish()
	pcall(function()
		local Players = game:GetService('Players')
		local pg = Players.LocalPlayer and Players.LocalPlayer:FindFirstChildOfClass('PlayerGui')
		if pg then pg:SetAttribute('HoodMoment', active and active.Name or '') end
	end)
end
local function expire()
	if not active then return end
	local t = now()
	if (active.Until and t >= active.Until) or t - active.At > MomentQueue.MaxHold then
		calmUntil = math.max(calmUntil, (active.Until or t) + MomentQueue.gapAfter(active.Size))
		active = nil
		publish()
	end
end

function MomentQueue.busy(): boolean
	expire()
	return active ~= nil
end
function MomentQueue.current(): string?
	expire()
	return active and active.Name or nil
end
-- Seconds until a waiting moment could start (0: now), ignoring Ready.
function MomentQueue.calmLeft(): number
	expire()
	if active then return math.huge end
	return math.max(0, calmUntil - now())
end

function MomentQueue.acquire(name: string, opts: any?)
	opts = type(opts) == 'table' and opts or {}
	local me = { Name = tostring(name), Size = opts.Size == 'small' and 'small' or 'big', Ready = false, Fn = opts.Ready, PriorityOf = opts.Priority, Priority = 0 }
	table.insert(waiters, me)
	local deadline = now() + (type(opts.Timeout) == 'number' and opts.Timeout or 30)
	while true do
		expire()
		for _, w in waiters do
			local ok, r = true, true
			if type(w.Fn) == 'function' then ok, r = pcall(w.Fn) end
			w.Ready = ok and r == true
			local pr = w.PriorityOf
			if type(pr) == 'function' then
				local okP, v = pcall(pr)
				pr = okP and v or 0
			end
			w.Priority = type(pr) == 'number' and pr or 0
		end
		local i = MomentQueue.pick(waiters, { Active = active ~= nil, Now = now(), CalmUntil = calmUntil })
		if i and waiters[i] == me then
			table.remove(waiters, i)
			active = { Name = me.Name, Size = me.Size, At = now() }
			publish()
			return active
		end
		if now() >= deadline then
			local at = table.find(waiters, me)
			if at then table.remove(waiters, at) end
			return nil
		end
		task.wait(MomentQueue.Poll)
	end
end

function MomentQueue.release(token: any)
	if token == nil or token ~= active then return end
	calmUntil = math.max(calmUntil, now() + MomentQueue.gapAfter(active.Size))
	active = nil
	publish()
end

function MomentQueue.mark(name: string, seconds: number, size: string?)
	local t = now()
	if active and active.Until == nil then
		-- (a moment that cannot wait cuts in: the one on screen keeps its token, and it ends when it ends)
		calmUntil = math.max(calmUntil, t + (tonumber(seconds) or 1) + MomentQueue.gapAfter(size))
		return
	end
	active = { Name = tostring(name), Size = size == 'small' and 'small' or 'big', At = t, Until = t + (tonumber(seconds) or 1) }
	publish()
	task.delay((tonumber(seconds) or 1) + 0.05, expire) -- (its end is published on time, not at the next ask)
end

return MomentQueue
