--[[
	Where another player's body is NOW, from their own screen's word (owner, Oct 23 08:36: "only focus on making the
	desync the most precise it can be so that people have good gameplay and so its not laggy").
	Roblox draws everyone else late: their screen sends their body to the server (half their ping), the server sends
	it on (half yours), and Roblox smooths it (an amount it doesn't publish). Gameplay/OthersAhead used to guess that
	delay (your half ping + 0.1 s) and the way they move (the drawn body's own speed, which lags a turn).
	Now each screen also sends a stamp of its own body (Gameplay/MotionSend, an UnreliableRemoteEvent "Motion"):
	  t     the server's clock when it was taken (Workspace:GetServerTimeNow(): every screen shares that clock)
	  p, v  where the root was and how fast it went
	  g     the speed the keys ask for (Humanoid.MoveDirection x WalkSpeed): where it's heading next
	  push  a huss, dive or halt is pushing it (its speed is the push, not the keys)
	20 times a second, and at once when a key changes (a turn reaches everyone half a ping sooner than the body's own
	speed would show it). The server checks it against its own copy (HuzzServer/MotionRelay) and passes it on.
	MotionStamps.predict(stamp, dt) moves it on by the exact time since it was taken: a Roblox Humanoid on the ground
	takes the keys' speed within about a tenth of a second (Config K), a push keeps its speed for at most PushFor.
	So every screen draws everyone about where they are on their own screen at that moment: the same spot everywhere,
	only off when someone turned within the last half ping or so (nothing can know that sooner).
	MotionStamps.limit(offset) caps how far a body is drawn from where Roblox has it (MaxStuds; a teleport: none).
]]
local MotionStamps = {}

MotionStamps.Config = {
	Every = 1 / 20, -- seconds between stamps while moving (and on every key change, at most every MinGap)
	MinGap = 1 / 60,
	Idle = 0.5, -- seconds between stamps standing still (so a stale stamp never says "moving")
	MaxAge = 0.6, -- seconds: an older stamp is ignored (the old guess takes over: OthersAhead.lead)
	K = 12, -- per second: how fast a Humanoid's speed turns into what the keys ask for (~0.1 s to 70%)
	PushFor = 0.12, -- seconds a push's speed is carried on (a huss eases off fast: further would overshoot)
	MaxStuds = 10, -- studs at most between the drawn body and Roblox's copy
	Teleport = 14, -- studs: further apart than this, it's a teleport (drawn where Roblox has it)
	MaxSpeed = 150, -- studs/s: never believe a stamp faster than this
	Near = 6, -- studs (server): a stamp this far from the server's own copy, moved on, is refused (HuzzServer/MotionRelay)
}
local C = MotionStamps.Config

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

-- Where the stamp's body is `dt` seconds after it was taken (flat; the height stays the stamp's).
function MotionStamps.predict(stamp, dt: number): Vector3
	dt = math.clamp(dt, 0, C.MaxAge)
	local v, g = flat(stamp.v), flat(stamp.g or stamp.v)
	if v.Magnitude > C.MaxSpeed then v = v.Unit * C.MaxSpeed end
	if g.Magnitude > C.MaxSpeed then g = g.Unit * C.MaxSpeed end
	if stamp.push then
		-- a push: its speed for a moment, then the keys' (no long overshoot past a huss)
		local hold = math.min(dt, C.PushFor)
		return stamp.p + v * hold + g * (dt - hold)
	end
	-- the speed moves from v to g as e^(-K t): the distance is g dt + (v - g)(1 - e^(-K dt)) / K
	local k = C.K
	return stamp.p + g * dt + (v - g) * ((1 - math.exp(-k * dt)) / k)
end

-- The drawn body's offset from Roblox's copy, capped (flat).
function MotionStamps.limit(offset: Vector3): Vector3
	local o = flat(offset)
	if o ~= o or o.Magnitude > C.Teleport then return Vector3.zero end
	if o.Magnitude > C.MaxStuds then o = o.Unit * C.MaxStuds end
	return o
end

-- A stamp as sent (t, p, v, g, push), checked for shape: nil when it isn't one.
function MotionStamps.read(t, p, v, g, push)
	if type(t) ~= "number" or t ~= t or typeof(p) ~= "Vector3" or typeof(v) ~= "Vector3" or typeof(g) ~= "Vector3" then
		return nil
	end
	if p ~= p or v ~= v or g ~= g then return nil end
	return { t = t, p = p, v = v, g = g, push = push == true }
end

return MotionStamps
