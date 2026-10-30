--[[
	Draws the huss dash and a power's cast pose (Shared/RunMotion) on every R15 character on this client, so
	everyone sees everyone huss the same way (the dash from the character's DashAt/DashDir attributes,
	Gameplay/Dash; the cast from HuzzCastAt / HuzzCastLen, set on this screen by Gameplay/PowerEffects). Off when the
	owner's run is published (Config/Animations.Run).
	The walk and run under it are the owner's pack: on your own character through your Animator
	(Gameplay/Locomotion) and on everyone else through Gameplay/PlayerMoves (owner, Oct 18: "player to player less
	choppy"), so here only the huss and the cast (RunMotion with speed 0: `dashOnly`). Only while the pack's folder
	hasn't arrived (PlayerMoves.drives is false) does this still draw the old scripted Huss Valley run, driven by
	the replicated velocity. A carrier keeps the carry arms (CarryAnimator layers after this).
]]
local M = {}

function M.start()
	local Players = game:GetService("Players")
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local Workspace = game:GetService("Workspace")

	local Shared = ReplicatedStorage:WaitForChild("Shared")
	local Animations = require(Shared.Config.Animations)
	local RunMotion = require(Shared.RunMotion)
	local Frame = require(script.Parent.Frame)
	local PlayerMoves = require(script.Parent.PlayerMoves)
	local Locomotion = require(script.Parent.Locomotion)
	-- The owner's run plays instead (Gameplay/Locomotion, the huss: Gameplay/Dash). Published: for everyone.
	if Animations.Run ~= "" then
		return
	end

	local carried = Workspace:WaitForChild("HuzzCarried")
	local recs = {} -- Player -> { character, rec }

	Players.PlayerRemoving:Connect(function(p)
		recs[p] = nil
	end)

	Frame.on(10, function(dt)
		dt = math.clamp(dt, 1 / 240, 1 / 15)
		local now = Workspace:GetServerTimeNow()
		local carriers = {}
		for _, model in carried:GetChildren() do
			local id = model:GetAttribute("Carrier")
			if id then
				carriers[id] = true
			end
		end
		for _, p in Players:GetPlayers() do
			local character = p.Character
			-- the walk and run are the pack's (yours on your Animator, everyone's by hand): only the huss here
			local dashOnly = PlayerMoves.drives(character) or Locomotion.drives(character)
			local r = recs[p]
			-- (Re)build when the character changes, its joints were replaced, or it wasn't complete yet.
			if r and (r.character ~= character or not (r.rec and r.rec.joints.root.Parent)) then
				r = nil
			end
			if character and not r then
				local rec = RunMotion.new(character)
				if rec then
					r = { character = character, rec = rec }
					recs[p] = r
				end
			end
			local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if r and root then
				local v = root.AssemblyLinearVelocity
				-- Knocked down: speed 0, so the sprint fades out under the fall instead of snapping off.
				local speed = if character:GetAttribute("DownedAt") or dashOnly then 0 else Vector3.new(v.X, 0, v.Z).Magnitude
				-- The huss dash: its age and its direction in the body's frame (x right, z forward).
				local dashAt, dashDir = RunMotion.dashAt(character), character:GetAttribute("DashDir")
				local age, localDir = nil, nil
				if type(dashAt) == "number" and typeof(dashDir) == "Vector3" then
					age = now - dashAt
					-- sideways only: which side of the body it goes (Gameplay/Dash turns the body at most 90 degrees over
					-- the first frames, never past the side, so this never flips mid-move)
					local d = root.CFrame:VectorToObjectSpace(dashDir)
					localDir = Vector3.new(if d.X >= 0 then 1 else -1, 0, 0)
				end
				-- a power's wind-up (Gameplay/PowerEffects stamps it on this screen): the cast pose
				local castAt, castLen = character:GetAttribute("HuzzCastAt"), character:GetAttribute("HuzzCastLen")
				local castAge = if type(castAt) == "number" and type(castLen) == "number" then now - castAt else nil
				RunMotion.step(r.rec, dt, speed, math.abs(v.Y) < 10, carriers[p.UserId] == true, age, localDir, castAge, castLen,
					character:GetAttribute("HuzzCastKind"))
			end
		end
	end)
end

return M
