--!strict
-- The world clock (Master Plan §4 "Lighting and time of day"). The server owns the time; every client draws the
-- lighting itself from two Workspace attributes, so the sun moves every frame with no network traffic:
--   MTL_DayEpoch  (number)  server time (workspace:GetServerTimeNow()) when the cycle was at position 0 (Morning)
--   MTL_DayFrozen (number?) a clock hour to hold the whole server at (debug / events); nil = running
-- The server never writes Lighting (it would replicate and fight the clients' smooth values).
--   TimeService.clock() -> hour 0-24        TimeService.phase() -> "Morning" | "Day" | "Evening" | "Night"
--   TimeService.setClock(hour)              jump the world to that time (keeps running)
--   TimeService.freeze(hour?)               hold the world at that hour (nil = run again from there)
--   TimeService.PhaseChanged: Signal(phase)
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Signal = require(ReplicatedStorage.MTL.Signal)
local DayNight = require(ReplicatedStorage.MTL.Config.DayNight)
local DayNightRules = require(ReplicatedStorage.MTL.Rules.DayNightRules)

local TimeService = {}
TimeService.PhaseChanged = Signal.new() -- (phase)

local function log(...)
	print("[MTL Time]", ...)
end

local function now(): number
	return workspace:GetServerTimeNow()
end

function TimeService.clock(): number
	local frozen = workspace:GetAttribute("MTL_DayFrozen")
	if type(frozen) == "number" then
		return frozen
	end
	local epoch = workspace:GetAttribute("MTL_DayEpoch")
	if type(epoch) ~= "number" then
		return DayNight.StartClock
	end
	return DayNightRules.clockAt(now() - epoch)
end

function TimeService.phase(): string
	return DayNightRules.phaseOf(TimeService.clock())
end

function TimeService.setClock(hour: number)
	assert(type(hour) == "number", "[MTL Time] setClock(hour)")
	workspace:SetAttribute("MTL_DayEpoch", now() - DayNightRules.positionFor(hour))
	if workspace:GetAttribute("MTL_DayFrozen") ~= nil then
		workspace:SetAttribute("MTL_DayFrozen", hour % 24)
	end
	log("clock set to", string.format("%.2f", hour % 24), TimeService.phase())
end

function TimeService.freeze(hour: number?)
	if hour == nil then
		-- run again from the held time, no jump
		local held = TimeService.clock()
		workspace:SetAttribute("MTL_DayFrozen", nil)
		TimeService.setClock(held)
		return
	end
	workspace:SetAttribute("MTL_DayFrozen", hour % 24)
	TimeService.setClock(hour)
end

function TimeService.init()
	workspace:SetAttribute("MTL_DayFrozen", nil)
	TimeService.setClock(DayNight.StartClock)
	local last = TimeService.phase()
	task.spawn(function()
		while true do
			task.wait(1)
			local p = TimeService.phase()
			if p ~= last then
				last = p
				log("phase", p)
				TimeService.PhaseChanged:Fire(p)
			end
		end
	end)
end

return TimeService
