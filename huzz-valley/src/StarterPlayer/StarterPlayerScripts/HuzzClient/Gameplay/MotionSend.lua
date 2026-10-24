--[[
	Sends a stamp of your own body to the server, which passes it on to every screen (Shared/MotionStamps,
	HuzzServer/MotionRelay; owner, Oct 23 08:36: "make the desync the most precise it can be"): the server's clock now,
	where your root is, how fast it goes, the speed your keys ask for (MoveDirection x WalkSpeed) and whether a huss,
	dive or halt is pushing it. 20 a second while you move (2 a second standing still), and at once when your keys
	change (a turn, a stop, setting off: at most 60 a second, and the server takes 40), so the others' screens see a turn half a ping sooner
	than your body's own movement would show it. On the Motion UnreliableRemoteEvent: a lost stamp is simply replaced
	by the next. Nothing is sent while you lie caught, are anchored, or have no body.
]]
local M = {}

function M.start()
	local Players = game:GetService("Players")
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local Workspace = game:GetService("Workspace")
	local Shared = ReplicatedStorage:WaitForChild("Shared")
	local MotionStamps = require(Shared.MotionStamps)
	local remote = require(Shared.Net).get("Motion")
	local C = MotionStamps.Config
	local player = Players.LocalPlayer
	local last, lastG, lastPush, lastMoving = -math.huge, Vector3.zero, 0, false
	local movedAt, blockedFor = -math.huge, 0

	-- How long this body's speed is carried on (Shared/MotionStamps push): a huss, dive or halt for PushFor; a lasso's
	-- or a glitch's pull for PullFor (the keys don't steer those); 0 when the keys steer it.
	local function pushed(root: BasePart): number
		for _, name in { "HuzzLasso", "HuzzGlitch" } do
			if root:FindFirstChild(name) then return C.PullFor end
		end
		for _, name in { "HuzzDash", "HuzzLunge", "HuzzHalt" } do
			if root:FindFirstChild(name) then return C.PushFor end
		end
		return 0
	end

	require(script.Parent.Frame).on(2, function(dt)
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local h = character and character:FindFirstChildOfClass("Humanoid")
		if not (root and root:IsA("BasePart") and h) or root.Anchored or h.Health <= 0 or character:GetAttribute("DownedAt") ~= nil then
			return
		end
		-- (only while you play in a game: in the lobby nobody needs them, and with a full server they were most of
		-- what everyone downloaded; owner, Oct 24 07:04: "its very laggy when people are playing and joning")
		local role = player:GetAttribute("HuzzRole")
		if role ~= "Runner" and role ~= "Catcher" then return end
		local now = os.clock()
		local v = root.AssemblyLinearVelocity
		local flatV = Vector3.new(v.X, 0, v.Z)
		local md = h.MoveDirection
		local g = Vector3.new(md.X, 0, md.Z) * h.WalkSpeed
		local push = pushed(root)
		-- (pressing into a wall: the keys say go but the body stays; after a moment, say what the body really does)
		blockedFor = if g.Magnitude > 4 and flatV.Magnitude < g.Magnitude * 0.25 and push == 0 then blockedFor + (dt or 0) else 0
		if blockedFor > 0.12 then g = flatV end
		local moving = flatV.Magnitude > 0.5 or g.Magnitude > 0.5
		if moving then movedAt = now end
		-- (a key change: set off, stop, a turn of more than ~20 degrees, a push starting or ending, the body coming to
		-- rest; the build-up's speed and small turns go with the 20 a second)
		local was, now_ = lastG.Magnitude > 0.5, g.Magnitude > 0.5
		local changed = push ~= lastPush or was ~= now_ or moving ~= lastMoving
			or (was and now_ and lastG.Unit:Dot(g.Unit) < C.Turn)
		local gap = now - last
		local busy = now - movedAt < C.Settle -- (still moving, or just stopped: 20 a second)
		if (changed and gap >= C.MinGap) or gap >= (if busy then C.Every else C.Idle) then
			last, lastG, lastPush, lastMoving = now, g, push, moving
			remote:FireServer(Workspace:GetServerTimeNow(), root.Position, flatV, g, push)
		end
	end)
end

return M
