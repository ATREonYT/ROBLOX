-- FlashGate (Oct 27, flow round 2, kid-safe): at most ONE white flash a second on this screen, whatever asks for it.
-- The owner's rule is "at most 1 flash per second"; a fresh critic found Juice.flash whitening a target on every hit,
-- and with auto-fire (2 shots a second, the lane's targets taking turns) and other players about, that made 2-5 white
-- flashes a second. Every white flash in the game asks here first:
--   FlashGate.take(kind) -> boolean   true: flash now (the next white flash waits MinGap seconds); false: do the soft
--                                     version instead (a faint warm tint, a scale or sway punch: no white, no big jump in
--                                     brightness)
--   FlashGate.note(kind)              a white flash that can't wait (it is the moment: a shoe box's reveal) was shown:
--                                     the gate closes behind it the same way
--   FlashGate.allowed(lastAt, now)    the pure rule (unit-tested, Flow_Test)
-- Sources (Oct 27): Juice.flash (lane targets, the boss, the ARMORY's gun on a buy), Stages' gate-clear flash, BossFX's
-- finish flash, Progress' level bloom. The shoe box reveals (UnboxCinematic / UnboxWorld / Shoes) plan their own
-- flashes at least 1 s apart (UnboxCinematic_Test) and note them here.
-- FlashGate.log keeps the last 64 white flashes { At, Kind } for the play-tests (tools/checks: flashes a second).
local FlashGate = {}
FlashGate.MinGap = 1.0
FlashGate.log = {}

function FlashGate.allowed(lastAt: number?, now: number): boolean
	return type(lastAt) ~= 'number' or now - lastAt >= FlashGate.MinGap
end

local lastAt = nil
local function record(kind)
	local now = os.clock()
	local last = FlashGate.log[#FlashGate.log]
	local held = last and last.Kind == tostring(kind or '?') and lastAt and now - lastAt < 0.3 -- (a flash noted frame by frame is one flash)
	lastAt = now
	if held then return end
	table.insert(FlashGate.log, { At = now, Kind = tostring(kind or '?') })
	if #FlashGate.log > 64 then table.remove(FlashGate.log, 1) end
end

function FlashGate.take(kind: string?): boolean
	if not FlashGate.allowed(lastAt, os.clock()) then return false end
	record(kind)
	return true
end

function FlashGate.note(kind: string?)
	record(kind)
end

return FlashGate
