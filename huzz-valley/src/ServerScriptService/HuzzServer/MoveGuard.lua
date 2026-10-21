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

-- How far (studs, across the ground) a body may go in dt seconds at this top speed.
function MoveGuard.allowed(top: number, dt: number): number
	return math.max(top, MoveGuard.MIN_TOP) * MoveGuard.SLACK * math.clamp(dt, 0, MoveGuard.MAX_GAP) + MoveGuard.BURST
end

-- One look at one body. rec: { at = Vector3, t = number } (the last accepted spot, nil at first); returns the new
-- rec and true when the body went too far (then rec is unchanged: the spot to send it back to).
function MoveGuard.look(rec, pos: Vector3, now: number, top: number)
	if not rec then return { at = pos, t = now }, false end
	local flat = Vector3.new(pos.X - rec.at.X, 0, pos.Z - rec.at.Z).Magnitude
	if flat > MoveGuard.allowed(top, now - rec.t) then
		return rec, true
	end
	-- (the spot moves on once a window has passed, and only if the body moved: a frozen copy keeps its time)
	if now - rec.t >= MoveGuard.WINDOW and (pos - rec.at).Magnitude > 0.01 then
		return { at = pos, t = now }, false
	end
	return rec, false
end

local function read(x: any, key: string): any
	local ok, v = pcall(function() return x[key] end)
	return if ok then v else nil
end

function MoveGuard.start()
	local Players = game:GetService("Players")
	local PlaceService = require(script.Parent.PlaceService)
	local recs = {} -- Player -> { at, t, character } (a plain table, cleared on leave)
	local told, errors = 0, 0
	Players.PlayerRemoving:Connect(function(p) recs[p] = nil end)
	task.spawn(function()
		while true do
			task.wait(MoveGuard.EVERY)
			local now = os.clock()
			for _, player in Players:GetPlayers() do
				local ok, err = pcall(function()
					local character = player.Character
					local root = character and character:FindFirstChild("HumanoidRootPart")
					local humanoid = character and character:FindFirstChildOfClass("Humanoid")
					local rec = recs[player]
					if not (root and humanoid) or (read(humanoid, "Health") or 100) <= 0 then recs[player] = nil return end
					-- (a new body, lying caught, sitting, or a move the game sent: start again from here)
					if (rec and rec.character ~= character) or read(root, "Anchored") or read(humanoid, "Sit") or read(humanoid, "PlatformStand")
						or PlaceService.pending(player) or now - PlaceService.lastMoveAt(player) < MoveGuard.GRACE then
						recs[player] = { at = root.CFrame.Position, t = now, character = character }
						return
					end
					local speed = humanoid:GetAttribute("HuzzSpeed") or character:GetAttribute("HuzzSpeed")
					local top = math.max(read(humanoid, "WalkSpeed") or 16, if type(speed) == "number" then speed else 0)
					local new, far = MoveGuard.look(rec, root.CFrame.Position, now, top)
					if far and rec then
						if told < MoveGuard.MAX_LINES then
							told += 1
							warn(string.format("[HuzzMove] %s moved %.0f studs in %.2f s (at most %.0f at speed %.0f): sent back",
								player.Name, Vector3.new(root.CFrame.Position.X - rec.at.X, 0, root.CFrame.Position.Z - rec.at.Z).Magnitude,
								now - rec.t, MoveGuard.allowed(top, now - rec.t), top))
						end
						PlaceService.place(player, CFrame.new(rec.at) * root.CFrame.Rotation, "speed check")
						return
					end
					new.character = character
					recs[player] = new
				end)
				if not ok and errors < MoveGuard.MAX_LINES then
					errors += 1
					warn("[Huzz] MoveGuard: " .. tostring(err))
				end
			end
		end
	end)
end

return MoveGuard
