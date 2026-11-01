--!strict
-- New Game Kit: Interact (vault notes 26 and 27, server-checked interactions for any genre)
-- Install: ReplicatedStorage/Kit/Interact (ModuleScript). Pure logic: no remotes, no Instances.
--
-- Every "press E" in the game (a door, a job board, a register, a seat, a pet bowl, a shop
-- counter) goes through the same server check. The client only says WHICH thing it pressed;
-- the server decides whether that player may use it right now, and why not.
--
--   local gate = Interact.new({ range = 10, cooldown = 0.5, busy = true })
--   local ok, why = gate:Try(userId, targetId, ctx, now)
--     ctx = { distance = number, allowed = boolean?, alive = boolean? }
--   gate:Release(targetId)     -- when a busy target (a seat, a register) is free again
--   gate:Forget(userId)        -- on PlayerRemoving
--
-- Reasons (shown to the player as a friendly line, never as an error): "TooFar", "Wait",
-- "NotAllowed", "Busy", "Dead", "Ok". The distance comes from the SERVER's positions, never
-- from the client's message. Range is checked with a small slack for lag (default +2 studs).
-- Status: covered by tests/Interact.spec.luau (offline).

local Interact = {}
Interact.__index = Interact

export type Rule = {
	range: number, -- studs; match the ProximityPrompt's MaxActivationDistance
	cooldown: number?, -- seconds between two uses by the same player (default 0.25)
	busy: boolean?, -- true: one user at a time (seats, registers, a shared stove)
	slack: number?, -- extra studs allowed for lag (default 2)
}

export type Context = {
	distance: number, -- measured on the server
	allowed: boolean?, -- the caller's permission check (owner, team, gamepass); nil = allowed
	alive: boolean?, -- nil = alive
}

export type Gate = typeof(setmetatable(
	{} :: {
		rule: Rule,
		lastUse: { [number]: number },
		holder: { [string]: number },
	},
	Interact
))

function Interact.new(rule: Rule): Gate
	assert(type(rule.range) == "number" and rule.range > 0, "Interact.new: range must be > 0")
	return setmetatable({ rule = rule, lastUse = {}, holder = {} }, Interact)
end

function Interact.Try(self: Gate, userId: number, targetId: string, ctx: Context, now: number): (boolean, string)
	local rule = self.rule
	if ctx.alive == false then
		return false, "Dead"
	end
	if type(ctx.distance) ~= "number" or ctx.distance ~= ctx.distance then
		return false, "TooFar" -- NaN or missing: treat as far, never as near
	end
	if ctx.distance > rule.range + (rule.slack or 2) then
		return false, "TooFar"
	end
	local last = self.lastUse[userId]
	if last and now - last < (rule.cooldown or 0.25) then
		return false, "Wait"
	end
	if ctx.allowed == false then
		return false, "NotAllowed"
	end
	if rule.busy then
		local holder = self.holder[targetId]
		if holder and holder ~= userId then
			return false, "Busy"
		end
		self.holder[targetId] = userId
	end
	self.lastUse[userId] = now
	return true, "Ok"
end

function Interact.Holder(self: Gate, targetId: string): number?
	return self.holder[targetId]
end

function Interact.Release(self: Gate, targetId: string)
	self.holder[targetId] = nil
end

function Interact.Forget(self: Gate, userId: number)
	self.lastUse[userId] = nil
	for target, holder in self.holder do
		if holder == userId then
			self.holder[target] = nil
		end
	end
end

-- Friendly lines for the one message line (GAME-FEEL.md). Kids read these, so keep them short.
Interact.Lines = {
	TooFar = "Get closer!",
	Wait = "One sec...",
	NotAllowed = "That's not yours.",
	Busy = "Someone is using that.",
	Dead = "",
	Ok = "",
}

return Interact
