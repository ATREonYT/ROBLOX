--[[
	The server keeps an eye on how fast every body really moves (owner, Oct 21 14:55: "make the game not client sided,
	but server sided also"). Roblox lets each player's own screen move their body (network ownership: that is what
	keeps controls sharp), so a changed screen could move it faster than the game allows or jump it across the map.
	Here, four times a second, each player's root is compared with the spot the server accepted up to WINDOW seconds
	before: across the ground it may cover at most top speed x SLACK x the time since, plus BURST studs for a huss
	and a dive in one go (Config/Round Dash ~15 studs, Lunge ~19). That catches a body going about twice its top
	speed or more, or jumping across the map; honest running, hussing and diving never come near it. Farther than that and the server sends them back to that spot (the proper
	way, HuzzServer/PlaceService: their own screen is told to move) with one "[HuzzMove]" line in Output (at most
	MAX_LINES). The top speed is the server's own (Humanoid WalkSpeed, or the HuzzSpeed it sets, whichever is more).
	Never checked: a body lying caught (anchored), sitting, a move the game itself just sent them (PlaceService, for
	GRACE seconds), a body that just spawned. Up and down are free (falls, jumps, the fall net catches those).
	A screen that froze and then caught up is fine: the time counts from the last spot it moved from (at most MAX_GAP s).
	Hits were already the server's to judge (Shared/TouchHit, RoundService.screenHit).
	Release check (Oct 22, "check if the game will hold up when people are playing"): a body the server holds still
	(WalkSpeed 0: a Bear Trap, a slip, a stun) gets no walking allowance, and the full BURST only right after a huss
	or a dive the server accepted (DashAt / LungeAt); otherwise SMALL_BURST. RoundService asks MoveGuard.fine(player)
	the moment a runner reaches the goal (a body that jumped into it isn't made safe) and MoveGuard.flagged(player)
	before a catcher's hit counts (a body sent back in the last FLAG_HOLD seconds can't stab).
	Errors go to Output on "[Huzz] MoveGuard:" lines; one body's error never stops the others.
]]
local MoveGuard = {}

MoveGuard.EVERY = 0.25 -- seconds between looks
MoveGuard.WINDOW = 2 -- seconds the accepted spot is kept before it moves on
MoveGuard.SLACK = 1.25 -- times the top speed (a lag spike's catch-up, a slope, a push)
MoveGuard.BURST = 36 -- studs on top (a huss and a dive inside the same window, with room)
MoveGuard.MAX_GAP = 2.5 -- seconds: the most time a jump is spread over
MoveGuard.GRACE = 2 -- seconds after the game moved you itself
MoveGuard.MIN_TOP = 16 -- studs a second: the least top speed counted (Roblox's own walk)
MoveGuard.MAX_LINES = 12
MoveGuard.SMALL_BURST = 22 -- studs on top with no huss or dive just accepted (a huss is ~15: one the server refused still passes)
MoveGuard.BURST_FOR = 2.5 -- seconds after a huss or dive the full BURST holds
MoveGuard.FLAG_HOLD = 2 -- seconds a body sent back can't hit anyone

-- How far (studs, across the ground) a body may go in dt seconds at this top speed. top 0 = held still (no
-- walking at all); burst = the studs on top (default BURST).
function MoveGuard.allowed(top: number, dt: number, burst: number?): number
	local walk = if top <= 0 then 0 else math.max(top, MoveGuard.MIN_TOP)
	return walk * MoveGuard.SLACK * math.clamp(dt, 0, MoveGuard.MAX_GAP) + (burst or MoveGuard.BURST)
end

-- One look at one body. rec: { at = Vector3, t = number, top = number? } (the last accepted spot, nil at first);
-- returns the new rec and true when the body went too far (then rec is unchanged: the spot to send it back to).
-- The walking allowance is the highest top speed seen since that spot (rec.top), not only the one now (owner,
-- Oct 22 18:53: the catcher's dive "teleports you back to the middle": the dive's 0.4 s stun is speed 0, and that
-- 0 counted for the whole run before it, so a catcher who ran and then dived was sent back up to 2 s).
function MoveGuard.look(rec, pos: Vector3, now: number, top: number, burst: number?)
	if not rec then return { at = pos, t = now, top = top }, false end
	local seen = math.max(top, rec.top or 0)
	local flat = Vector3.new(pos.X - rec.at.X, 0, pos.Z - rec.at.Z).Magnitude
	if flat > MoveGuard.allowed(seen, now - rec.t, burst) then
		return rec, true
	end
	-- (the spot moves on once a window has passed, and only if the body moved: a frozen copy keeps its time)
	if now - rec.t >= MoveGuard.WINDOW and (pos - rec.at).Magnitude > 0.01 then
		return { at = pos, t = now, top = top }, false
	end
	if seen ~= rec.top then
		return { at = rec.at, t = rec.t, top = seen, character = rec.character }, false
	end
	return rec, false
end

local function read(x: any, key: string): any
	local ok, v = pcall(function() return x[key] end)
	return if ok then v else nil
end

local recs = {} -- Player -> { at, t, character } (a plain table, cleared on leave)
local flaggedAt = {} -- Player -> os.clock() of the last send back
local told, errors = 0, 0
local started = false

-- One look at one player now (the 4-a-second loop, and RoundService at the goal line). Returns true when the body
-- went too far (it is sent back).
local function check(player: Player, now: number): boolean
	local PlaceService = require(script.Parent.PlaceService)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local rec = recs[player]
	if not (root and humanoid) or (read(humanoid, "Health") or 100) <= 0 then recs[player] = nil return false end
	-- (a new body, lying caught, sitting, or a move the game sent: start again from here)
	if (rec and rec.character ~= character) or read(root, "Anchored") or read(humanoid, "Sit") or read(humanoid, "PlatformStand")
		or PlaceService.pending(player) or now - PlaceService.lastMoveAt(player) < MoveGuard.GRACE then
		recs[player] = { at = root.CFrame.Position, t = now, character = character }
		return false
	end
	local speed = humanoid:GetAttribute("HuzzSpeed") or character:GetAttribute("HuzzSpeed")
	local walkSpeed = read(humanoid, "WalkSpeed") or 16
	local top = math.max(walkSpeed, if type(speed) == "number" then speed else 0)
	if walkSpeed <= 0 then top = 0 end -- (held still by the server: a trap, a slip, a stun)
	local serverNow = workspace:GetServerTimeNow()
	local dashAt, lungeAt = character:GetAttribute("DashAt"), character:GetAttribute("LungeAt")
	local moved = (type(dashAt) == "number" and serverNow - dashAt < MoveGuard.BURST_FOR) or (type(lungeAt) == "number" and serverNow - lungeAt < MoveGuard.BURST_FOR)
	local burst = if moved then MoveGuard.BURST else MoveGuard.SMALL_BURST
	local new, far = MoveGuard.look(rec, root.CFrame.Position, now, top, burst)
	if far and rec then
		flaggedAt[player] = now
		if told < MoveGuard.MAX_LINES then
			told += 1
			warn(string.format("[HuzzMove] %s moved %.0f studs in %.2f s (at most %.0f at speed %.0f): sent back",
				player.Name, Vector3.new(root.CFrame.Position.X - rec.at.X, 0, root.CFrame.Position.Z - rec.at.Z).Magnitude,
				now - rec.t, MoveGuard.allowed(top, now - rec.t, burst), top))
		end
		PlaceService.place(player, CFrame.new(rec.at) * root.CFrame.Rotation, "speed check")
		return true
	end
	new.character = character
	recs[player] = new
	return false
end

-- Did this player's body get here honestly? (a look right now; true when MoveGuard isn't running, e.g. the sim)
function MoveGuard.fine(player: Player?): boolean
	if not started or not player then return true end
	if MoveGuard.flagged(player) then return false end -- (just sent back: still on the way out of where it jumped to)
	local ok, far = pcall(check, player, os.clock())
	return not ok or not far
end

-- Was this player's body sent back in the last FLAG_HOLD seconds?
function MoveGuard.flagged(player: Player?): boolean
	local at = player and flaggedAt[player]
	return at ~= nil and os.clock() - at < MoveGuard.FLAG_HOLD
end

function MoveGuard.start()
	local Players = game:GetService("Players")
	started = true
	Players.PlayerRemoving:Connect(function(p) recs[p] = nil; flaggedAt[p] = nil end)
	task.spawn(function()
		while true do
			task.wait(MoveGuard.EVERY)
			local now = os.clock()
			for _, player in Players:GetPlayers() do
				local ok, err = pcall(check, player, now)
				if not ok and errors < MoveGuard.MAX_LINES then
					errors += 1
					warn("[Huzz] MoveGuard: " .. tostring(err))
				end
			end
		end
	end)
end

return MoveGuard
