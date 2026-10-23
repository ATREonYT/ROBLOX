--[[
	Sends a stamp of your own body to the server, which passes it on to every screen (Shared/MotionStamps,
	HuzzServer/MotionRelay; owner, Oct 23 08:36: "make the desync the most precise it can be"): the server's clock now,
	where your root is, how fast it goes, the speed your keys ask for (MoveDirection x WalkSpeed) and whether a huss,
	dive or halt is pushing it. 20 a second while you move (2 a second standing still), and at once when your keys
	change (a turn, a stop, setting off: at most 60 a second), so the others' screens see a turn half a ping sooner
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
	local last, lastG, lastPush = -math.huge, Vector3.zero, false

	local function pushed(root: BasePart): boolean
		for _, name in { "HuzzDash", "HuzzLunge", "HuzzHalt" } do
			if root:FindFirstChild(name) then return true end
		end
		return false
	end

	require(script.Parent.Frame).on(2, function()
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local h = character and character:FindFirstChildOfClass("Humanoid")
		if not (root and root:IsA("BasePart") and h) or root.Anchored or h.Health <= 0 or character:GetAttribute("DownedAt") ~= nil then
			return
		end
		local now = os.clock()
		local v = root.AssemblyLinearVelocity
		local flatV = Vector3.new(v.X, 0, v.Z)
		local md = h.MoveDirection
		local g = Vector3.new(md.X, 0, md.Z) * h.WalkSpeed
		local push = pushed(root)
		local moving = flatV.Magnitude > 0.5 or g.Magnitude > 0.5
		-- (a key change: set off, stop, or a turn of more than ~10 degrees; the build-up's speed goes with the 20 a second)
		local was, now_ = lastG.Magnitude > 0.5, g.Magnitude > 0.5
		local changed = push ~= lastPush or was ~= now_ or (was and now_ and lastG.Unit:Dot(g.Unit) < 0.985)
		local gap = now - last
		if (changed and gap >= C.MinGap) or gap >= (if moving then C.Every else C.Idle) then
			last, lastG, lastPush = now, g, push
			remote:FireServer(Workspace:GetServerTimeNow(), root.Position, flatV, g, push)
		end
	end)
end

return M
