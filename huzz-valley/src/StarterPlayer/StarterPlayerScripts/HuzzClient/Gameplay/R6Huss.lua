--[[
	The huss on R6 bodies plays the owner's own Dash Left / Dash Right from his BZ1 movement pack (owner, Oct 22: "use
	these animations that i sent from the movement"; 14:37 "add it by any means possible"). Shared/RunMotion's drawn
	huss pose is for R15 joints and leaves R6 bodies alone, so this draws his dash instead, by hand, on every R6
	body on this screen (yours too), from the character's DashAt / DashDir like RunMotion: the side it goes picks
	Left or Right (fixed at the start, never flipping mid-move), sampled from ReplicatedStorage.HuzzR6Moves (Shared/
	KeyframeSampler; Bootstrap fills it, Studio and live: nothing to upload). His dash is 0.4 s, the huss's length
	(Config/Run.Dash.Length): it blends in over Dash.In and out over Dash.Out on top of the walk or run underneath.
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
	local Sampler = require(Shared.KeyframeSampler)
	local RunMotion = require(Shared.RunMotion)
	local CarryMath = require(Shared.CarryMath)
	local Frame = require(script.Parent.Frame)
	local D = Run.Dash

	local dashes, tried = nil, -math.huge
	local function find(now: number)
		if dashes or now - tried < 2 then
			return dashes
		end
		tried = now
		local folder = ReplicatedStorage:FindFirstChild("HuzzR6Moves")
		local out = {}
		for key, name in { Left = "R6DashLeft", Right = "R6DashRight" } do
			local seq = folder and folder:FindFirstChild(name)
			local ok, anim = pcall(Sampler.load, seq)
			if not (seq and ok and anim and anim.length > 0) then
				return nil
			end
			out[key] = anim
		end
		dashes = out
		return out
	end

	local recs = {} -- Player -> { character, at, side, motors }
	Players.PlayerRemoving:Connect(function(p) recs[p] = nil end)

	Frame.on(13, function()
		local anims = find(os.clock())
		if not anims then
			return
		end
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
					rec = { character = character, at = at, side = if d.X >= 0 then "Right" else "Left", motors = motors }
					recs[p] = rec
				end
				local age = now - at
				local anim = anims[rec.side]
				local w = math.min(math.clamp(age / D.In, 0, 1), math.clamp((D.Length - age) / D.Out, 0, 1))
				w = w * w * (3 - 2 * w) -- (smooth in and out)
				local pose = Sampler.sample(anim, math.min(age, anim.length))
				for name, m in rec.motors do
					local cf = pose[name]
					if m and m.Parent and cf then
						m.Transform = m.Transform:Lerp(cf, w)
					end
				end
			end
		end
	end)
end

return M
