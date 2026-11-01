--!strict
-- New Game Kit: Stamina (vault "Realistic City RP/05 Health, Stamina, Sprint and Knockouts")
-- Install: ReplicatedStorage/Kit/Stamina (ModuleScript). Pure logic, same file on client and server.
--
-- The CLIENT runs it every frame so sprint feels instant (bar, FOV kick, footstep speed).
-- The SERVER runs the same numbers on a slower tick (0.25 s) and only checks the result:
-- if a player is moving at sprint speed while the server's copy says "Exhausted", the server
-- puts their WalkSpeed back. Same maths both sides = no false alarms.
--
--   local s = Stamina.new()
--   Stamina.Step(s, dt, wantsSprint, isMoving)  -> speed (studs/s) to set on the Humanoid
--   Stamina.Spend(s, amount)                    -> ok (a punch, a jump, a vault)
--   s.value (0..max), s.exhausted (true until it refills to Rules.recoverAt)
-- Status: covered by tests/Stamina.spec.luau (offline).

local Stamina = {}

Stamina.Rules = {
	max = 100,
	walkSpeed = 16,
	sprintSpeed = 24, -- 1.5x walk: fast enough to matter, slow enough that cars still win
	drainPerSecond = 12.5, -- a full bar = 8 s of sprinting
	regenPerSecond = 20, -- 5 s from empty to full when resting...
	regenWalking = 10, -- ...half speed while walking
	regenDelay = 0.8, -- seconds after the last spend before regen starts (makes stamina readable)
	recoverAt = 30, -- once empty, you can't sprint again until 30%
}

export type State = { value: number, exhausted: boolean, sinceSpend: number, sprinting: boolean }

function Stamina.new(): State
	return { value = Stamina.Rules.max, exhausted = false, sinceSpend = 999, sprinting = false }
end

function Stamina.Step(s: State, dt: number, wantsSprint: boolean, isMoving: boolean): number
	local r = Stamina.Rules
	dt = math.clamp(dt, 0, 1) -- a frame hitch never drains a whole bar at once
	local canSprint = wantsSprint and isMoving and not s.exhausted and s.value > 0
	s.sprinting = canSprint
	if canSprint then
		s.value = math.max(0, s.value - r.drainPerSecond * dt)
		s.sinceSpend = 0
		if s.value <= 0 then
			s.exhausted = true
			s.sprinting = false
		end
	else
		s.sinceSpend += dt
		if s.sinceSpend >= r.regenDelay then
			local rate = if isMoving then r.regenWalking else r.regenPerSecond
			s.value = math.min(r.max, s.value + rate * dt)
		end
		if s.exhausted and s.value >= r.recoverAt then
			s.exhausted = false
		end
	end
	return if s.sprinting then r.sprintSpeed else r.walkSpeed
end

function Stamina.Spend(s: State, amount: number): boolean
	if s.exhausted or s.value < amount then
		return false
	end
	s.value -= amount
	s.sinceSpend = 0
	if s.value <= 0 then
		s.exhausted = true
	end
	return true
end

return Stamina
