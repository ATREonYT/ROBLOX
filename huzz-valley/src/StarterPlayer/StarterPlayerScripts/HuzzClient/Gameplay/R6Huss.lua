--[[
	The huss on R6 bodies: the game's own huss pose (owner, Oct 22 17:21: "make the huss animation not like that, but
	actually like the huss movement, just adjusted to the new animations"), Shared/R6HussPose: Shared/RunMotion's
	wide low crouch leaning into the move, rebuilt for R6 (RunMotion's is for R15 joints and leaves R6 bodies alone).
	It replaced his pack's Dash Left / Right (14:37), which he didn't want. Drawn by hand on every R6 body on this
	screen (yours too), from the character's DashAt / DashDir like RunMotion: the side it goes is fixed at the start,
	never flipping mid-move. Same timing as RunMotion's: in over Dash.In, held while the push lasts and settling
	deeper (Dash.Settle), out over Dash.Out, on top of the walk or run underneath.
	Gameplay/Frame order 13: after Locomotion (12) and PlayerMoves (8), before the carry (20) and the stab (30).
]]
local M = {}

local PARTS = { "Torso", "Head", "Right Arm", "Left Arm", "Right Leg", "Left Leg" }

function M.start()
	local Players = game:GetService("Players")
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local Workspace = game:GetService("Workspace")
	local Shared = ReplicatedStorage:WaitForChild("Shared")
	local Run = require(Shared.Config.Run)
	local Pose = require(Shared.R6HussPose)
	local RunMotion = require(Shared.RunMotion)
	local CarryMath = require(Shared.CarryMath)
	local Frame = require(script.Parent.Frame)
	local D = Run.Dash

	local recs = {} -- Player -> { character, at, side, motors }
	Players.PlayerRemoving:Connect(function(p) recs[p] = nil end)

	Frame.on(13, function()
		local now = Workspace:GetServerTimeNow()
		for _, p in Players:GetPlayers() do
			local character = p.Character
			local humanoid = character and character:FindFirstChildOfClass("Humanoid")
			local root = character and character:FindFirstChild("HumanoidRootPart")
			local at = character and RunMotion.dashAt(character)
			local dir = character and character:GetAttribute("DashDir")
			if humanoid and root and humanoid.RigType == Enum.HumanoidRigType.R6 and root:IsA("BasePart")
				and type(at) == "number" and typeof(dir) == "Vector3" and now - at >= 0 and now - at < D.Length
				and not character:GetAttribute("DownedAt") then
				local rec = recs[p]
				if not (rec and rec.character == character and rec.at == at) then
					local motors = {}
					for _, name in PARTS do
						motors[name] = CarryMath.holding(character, name)
					end
					local d = root.CFrame:VectorToObjectSpace(dir)
					rec = { character = character, at = at, side = if d.X >= 0 then 1 else -1, motors = motors }
					recs[p] = rec
				end
				local age = now - at
				local w = math.min(math.clamp(age / D.In, 0, 1), math.clamp((D.Length - age) / D.Out, 0, 1))
				w = w * w * (3 - 2 * w) -- (smooth in and out)
				local hold = math.max(D.Length - D.Out - D.In, 1e-3)
				local u = math.clamp((age - D.In) / hold, 0, 1)
				local depth = 1 - (D.Settle or 0) * (1 - u * u * (3 - 2 * u))
				local whole = true
				for _, m in rec.motors do
					if not m.Parent then whole = false end
				end
				if whole then
					Pose.pose(rec.motors, rec.side, depth, w)
				end
			end
		end
	end)
end

return M
