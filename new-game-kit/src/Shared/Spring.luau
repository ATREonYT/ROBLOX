--!strict
-- New Game Kit: Spring (bouncy, natural motion from code; vault note 16 §4 and note 17)
-- Install: ReplicatedStorage/Kit/Spring (ModuleScript)
-- A damped spring solved exactly (no drift at any frame rate), the same model as the `spr` library:
--   damping  < 1 overshoots and wobbles, = 1 settles cleanly, > 1 creeps in slowly
--   frequency is how many times a second it swings (higher = snappier)
-- Works on numbers, Vector3, Vector2 and anything else with + - and * number.
--   local s = Spring.new(0, 0.5, 5)   -- value, damping, frequency
--   s:SetTarget(1)                     -- move toward 1
--   s:Impulse(-20)                     -- kick it (recoil, a UI bump)
--   local v = s:Step(dt)               -- call every frame; returns the new value
--   s:IsResting()                      -- true once it has settled
-- Presets (note 16): Spring.Presets.Bouncy (0.5, 5) for a recoil return, Clean (1, 4) for UI slides,
-- Wobble (0.4, 4) for a carriage rock, Squash (0.4, 6) for a landing unsquash.
-- Status: covered by tests/Spring.spec.luau (offline).

local Spring = {}
Spring.__index = Spring

Spring.Presets = {
	Bouncy = { damping = 0.5, frequency = 5 },
	Clean = { damping = 1, frequency = 4 },
	Wobble = { damping = 0.4, frequency = 4 },
	Squash = { damping = 0.4, frequency = 6 },
	Pop = { damping = 0.45, frequency = 7 },
}

local EPSILON = 1e-4

local function zero(v: any): any
	return if type(v) == "number" then 0 else v - v
end

local function magnitude(v: any): number
	if type(v) == "number" then
		return math.abs(v)
	end
	return v.Magnitude
end

-- Exact solution of x'' = -w^2 x - 2 d w x' after dt seconds, x measured from the target.
local function solve(x0: any, v0: any, damping: number, frequency: number, dt: number): (any, any)
	local w = frequency * 2 * math.pi
	if damping < 1 then
		local h = w * math.sqrt(1 - damping * damping)
		local a = damping * w
		local decay = math.exp(-a * dt)
		local c, s = math.cos(h * dt), math.sin(h * dt)
		local x = (x0 * c + (v0 + x0 * a) * (s / h)) * decay
		local v = (v0 * c - (v0 * a + x0 * w * w) * (s / h)) * decay
		return x, v
	elseif damping == 1 then
		local decay = math.exp(-w * dt)
		local b = v0 + x0 * w
		return (x0 + b * dt) * decay, (v0 - b * (w * dt)) * decay
	else
		local root = math.sqrt(damping * damping - 1)
		local r1, r2 = -w * (damping - root), -w * (damping + root)
		local c1 = (v0 - x0 * r2) * (1 / (r1 - r2))
		local c2 = x0 - c1
		local e1, e2 = math.exp(r1 * dt), math.exp(r2 * dt)
		return c1 * e1 + c2 * e2, c1 * (r1 * e1) + c2 * (r2 * e2)
	end
end

export type Spring = typeof(setmetatable(
	{} :: { Value: any, Velocity: any, Target: any, Damping: number, Frequency: number },
	Spring
))

function Spring.new(value: any, damping: number?, frequency: number?): Spring
	local self = setmetatable({
		Value = value,
		Velocity = zero(value),
		Target = value,
		Damping = math.max(0, damping or 1),
		Frequency = math.max(0.01, frequency or 4),
	}, Spring)
	return self
end

function Spring.fromPreset(value: any, name: string): Spring
	local p = Spring.Presets[name]
	assert(p, `Spring: unknown preset {name}`)
	return Spring.new(value, p.damping, p.frequency)
end

function Spring.SetTarget(self: Spring, target: any)
	self.Target = target
end

function Spring.Impulse(self: Spring, velocity: any)
	self.Velocity = self.Velocity + velocity
end

function Spring.Snap(self: Spring, value: any)
	self.Value = value
	self.Target = value
	self.Velocity = zero(value)
end

function Spring.Step(self: Spring, dt: number): any
	if dt <= 0 then
		return self.Value
	end
	local x, v = solve(self.Value - self.Target, self.Velocity, self.Damping, self.Frequency, dt)
	self.Value = self.Target + x
	self.Velocity = v
	return self.Value
end

function Spring.IsResting(self: Spring, tolerance: number?): boolean
	local t = tolerance or EPSILON
	return magnitude(self.Value - self.Target) < t and magnitude(self.Velocity) < t * 10
end

-- The value after `t` seconds, starting at `from` (moving at `velocity`) toward `to`. Pure: for
-- tests, previews and baking a curve into keyframes.
function Spring.Sample(damping: number, frequency: number, from: any, to: any, t: number, velocity: any?): any
	local x = solve(from - to, velocity or zero(from), damping, frequency, t)
	return to + x
end

-- How long until the spring stays within `tolerance` of the target (for scheduling clean-up).
function Spring.SettleTime(damping: number, frequency: number, tolerance: number?): number
	local w = frequency * 2 * math.pi
	local rate = if damping < 1 then damping * w else w * (damping - math.sqrt(math.max(0, damping * damping - 1)))
	if rate <= 0 then
		return math.huge
	end
	return math.log(1 / (tolerance or 0.01)) / rate
end

-- Drive a property with a spring on the client every frame until it rests; returns a stop function.
-- `apply(value)` writes the value (e.g. function(v) model:PivotTo(base * CFrame.new(0, 0, v)) end).
function Spring.Run(spring: Spring, apply: (any) -> (), onDone: (() -> ())?): () -> ()
	local RunService = game:GetService("RunService")
	local connection
	connection = RunService.RenderStepped:Connect(function(dt)
		apply(spring:Step(dt))
		if spring:IsResting() then
			apply(spring.Target)
			connection:Disconnect()
			if onDone then
				onDone()
			end
		end
	end)
	return function()
		connection:Disconnect()
	end
end

return Spring
