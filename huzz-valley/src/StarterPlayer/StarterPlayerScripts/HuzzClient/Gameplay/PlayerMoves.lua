--[[
	Everyone walks and runs with the owner's movement pack, on every screen, in Studio and live, with nothing to
	upload (owner, Oct 18: "player to player less choppy", "make the walking animations way way better").
	  - Every R15 character on this client (other players, the Practice Bot, and yours whenever Gameplay/Locomotion
	    isn't playing the pack on your Animator, e.g. the live game before the animations are published) gets the
	    pack's Idle, Walk and Run sampled by hand from ReplicatedStorage.HuzzGirlMoves (Shared/GirlMoves.find: the
	    folder Bootstrap fills for the girls, Studio and live) and written straight onto its Motor6D.Transform
	    (R15 to R15: no retarget), blended by Shared/LocomotionMix with Config/Run.Loco (the same numbers as your
	    own walk), scaled to the avatar's size. It covers whatever Roblox's own Animate plays underneath.
	  - Other players' speed comes from where their body is over time (LocomotionMix.track: a 0.25 s window, held
	    through network stalls, teleports ignored) and then the blend's spring, never from their replicated
	    velocity, which jumps between network updates (that made the old scripted legs stutter: the "choppy" look).
	    The stride phase only moves forward, so a jumpy speed never pops the feet. Your own speed is your real one.
	  - Gameplay/Frame order 8: before the huss and cast pose (RunAnimator 10, which draws only those on anyone this
	    drives: PlayerMoves.drives), Locomotion 12, the carry 20 (a carrier's arms go to her), the stab 30, the crown
	    35 and the knockdown 40 (a downed body: speed 0 here, the knockdown owns the pose).
	  - A dance (HuzzDance) or any Action animation on their Animator: the pack fades out (Config/Run.Track.Fade) so
	    that plays; it fades back after.
	  - Cheap for a full server: keyframes found by binary search, the pose re-sampled every frame only within 70
	    studs, 30 times a second to 160, 15 beyond or behind the camera (the last pose is written every frame, so
	    Roblox's own animation never peeks through).
	  - Your own, in the live game only: the small lean into turns and into speeding up (LocomotionMix.lean), as
	    Locomotion adds in Studio.
	Off when the owner has published Idle, Walk and Run (Config/Animations): then the real tracks replicate.
]]
local M = {}

local recs = {} -- character Model -> rec (a plain table, cleared when the character goes: never a weak table)

-- True while this draws the character's walk (RunAnimator then draws only the huss and the cast pose on it).
function M.drives(character: Model?): boolean
	return character ~= nil and recs[character] ~= nil
end

local PARTS = {
	"LowerTorso", "UpperTorso", "Head",
	"LeftUpperArm", "LeftLowerArm", "LeftHand", "RightUpperArm", "RightLowerArm", "RightHand",
	"LeftUpperLeg", "LeftLowerLeg", "LeftFoot", "RightUpperLeg", "RightLowerLeg", "RightFoot",
}

function M.start()
	local Players = game:GetService("Players")
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local Workspace = game:GetService("Workspace")
	local CollectionService = game:GetService("CollectionService")

	local Shared = ReplicatedStorage:WaitForChild("Shared")
	local Animations = require(Shared.Config.Animations)
	if Animations.Idle ~= "" and Animations.Walk ~= "" and Animations.Run ~= "" then
		return -- (published: everyone's own Locomotion tracks replicate)
	end
	local RunConfig = require(Shared.Config.Run)
	local Mix = require(Shared.LocomotionMix)
	local Sampler = require(Shared.KeyframeSampler)
	local GirlMoves = require(Shared.GirlMoves)
	local RunMotion = require(Shared.RunMotion)
	local Locomotion = require(script.Parent.Locomotion)
	local Frame = require(script.Parent.Frame)
	local T = RunConfig.Track
	local DASH_LENGTH = RunConfig.Dash.Length

	local tried = {} -- character -> when we last failed to build it (its body still loading)

	local function build(character: Model, now: number)
		if tried[character] and now - tried[character] < 1 then
			return nil
		end
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not (humanoid and root) or humanoid.RigType ~= Enum.HumanoidRigType.R15 then
			tried[character] = now
			return nil
		end
		local motors, count = {}, 0
		for _, name in PARTS do
			local part = character:FindFirstChild(name)
			if part then
				for _, j in part:GetChildren() do
					if j:IsA("Motor6D") and j.Part1 == part then
						motors[name] = j
						count += 1
						break
					end
				end
			end
		end
		if count < #PARTS or not motors.LowerTorso then
			tried[character] = now
			return nil
		end
		tried[character] = nil
		local size = math.clamp((humanoid.HipHeight + root.Size.Y / 2) / RunConfig.Loco.RootHeight, 0.5, 2)
		return {
			character = character, humanoid = humanoid, root = root, motors = motors, k = size,
			mix = Mix.new(Mix.sized(RunConfig.Loco, size)), tracker = Mix.tracker(T),
			idleT = math.random() * 2, -- (idles out of step with each other)
			weight = 0, acc = math.huge, pose = nil, written = {}, base = {},
			lastScan = -math.huge, actionUntil = 0,
		}
	end

	local function release(rec)
		for name, base in rec.base do
			local m = rec.motors[name]
			if m and m.Parent then
				m.Transform = base
			end
		end
		rec.written, rec.base = {}, {}
	end

	-- An Action animation (a dance, a published stab) playing on their Animator? Checked 4 times a second.
	local function actionPlaying(rec, now)
		if now - rec.lastScan >= 0.25 then
			rec.lastScan = now
			local animator = rec.humanoid:FindFirstChildOfClass("Animator")
			if animator then
				pcall(function()
					for _, t in animator:GetPlayingAnimationTracks() do
						if t.Priority == Enum.AnimationPriority.Action and t.WeightCurrent > 0.05 then
							rec.actionUntil = now + 0.3
						end
					end
				end)
			end
		end
		return now < rec.actionUntil
	end

	local function write(rec, pose, w)
		for name, m in rec.motors do
			local cf = pose[name]
			if cf then
				if name == "LowerTorso" then
					cf = CFrame.new(cf.Position * rec.k) * cf.Rotation -- (the hips' bob, to the avatar's size)
					if rec.lean then
						cf = rec.lean * cf
					end
				end
				local current = m.Transform
				-- (nothing animated it since our last write: blend from the last real pose, don't stack)
				local base = if rec.written[name] == current then rec.base[name] else current
				rec.base[name] = base
				m.Transform = if w >= 0.999 or not base then cf else base:Lerp(cf, w)
				rec.written[name] = m.Transform -- read back: Roblox stores CFrames as float32
			end
		end
	end

	local function step(rec, dt, now, anims, isMe, camCF)
		local character, root, humanoid = rec.character, rec.root, rec.humanoid
		local pos = root.CFrame.Position
		local speed, up
		if isMe then
			local v = root.AssemblyLinearVelocity
			speed, up = Vector3.new(v.X, 0, v.Z).Magnitude, v.Y
		else
			speed, up = Mix.track(rec.tracker, now, pos)
		end
		local downed = character:GetAttribute("DownedAt") ~= nil
		if downed or root.Anchored or humanoid.Sit then
			speed = 0
		end
		local airborne = math.abs(up) > 8
		if isMe then
			local state = humanoid:GetState()
			airborne = state == Enum.HumanoidStateType.Freefall or state == Enum.HumanoidStateType.Jumping
		end

		local quiet = character:GetAttribute("HuzzDance") ~= nil or actionPlaying(rec, now)
		rec.weight = math.clamp(rec.weight + (if quiet then -dt else dt) / T.Fade, 0, 1)

		-- how often the pose is re-sampled: every frame close by, less far away or behind the camera
		local interval = 0
		if camCF then
			local d = pos - camCF.Position
			local far = d.Magnitude
			if far > T.Mid or d:Dot(camCF.LookVector) < 0 then
				interval = 1 / 15
			elseif far > T.Near then
				interval = 1 / 30
			end
		end
		rec.acc += dt
		if rec.pose == nil or rec.acc >= interval then
			local sdt = math.min(rec.acc, 0.2)
			rec.acc = 0
			Mix.step(rec.mix, sdt, {
				speed = speed, state = "ground", stride = if airborne then 0.3 else 1,
				lengths = { Walk = anims.Walk.length, Run = anims.Run.length },
			})
			rec.idleT += sdt
			local pose = Mix.pose(rec.mix, anims, rec.idleT, Sampler.sample)
			if isMe and pose.LowerTorso then
				-- the lean into turns and into speeding up (as Locomotion adds on top in Studio)
				local dashAt = RunMotion.dashAt(character)
				local hussing = type(dashAt) == "number" and Workspace:GetServerTimeNow() - dashAt < DASH_LENGTH + 0.1
				local look = root.CFrame.LookVector
				local roll, pitch = Mix.lean(rec.mix, sdt, math.atan2(-look.X, -look.Z), if downed or hussing or quiet or airborne then 1 else 0)
				rec.lean = nil
				if math.abs(roll) + math.abs(pitch) > 1e-4 then
					-- turned about the ground under you (in the root part's space), then into the joint's own frame
					local c0 = rec.motors.LowerTorso.C0
					rec.lean = c0:Inverse() * Mix.leanCFrame(roll, pitch, root.Size.Y / 2 + humanoid.HipHeight) * c0
				end
			end
			rec.pose = pose
		end
		if rec.weight > 0 then
			write(rec, rec.pose, rec.weight)
		elseif next(rec.written) then
			release(rec) -- (fully faded out: a dance plays, untouched)
		end
	end

	Frame.on(8, function(dt)
		dt = math.clamp(dt, 1 / 240, 1 / 15)
		local now = os.clock()
		local anims = GirlMoves.find(now)
		if not anims then
			return -- (the folder hasn't arrived yet: RunAnimator's scripted run meanwhile)
		end
		local me = Players.LocalPlayer
		local cam = Workspace.CurrentCamera
		local camCF = cam and cam.CFrame
		local seen = {}
		local function visit(character: Model?, isMe: boolean)
			if not character or character.Parent == nil or seen[character] then
				return
			end
			if isMe and Locomotion.drives(character) then
				return -- (your Animator plays the pack: Gameplay/Locomotion)
			end
			local rec = recs[character]
			if rec and not (rec.motors.LowerTorso.Parent and rec.root.Parent == character) then
				recs[character] = nil -- (its body was rebuilt: start over)
				rec = nil
			end
			if not rec then
				rec = build(character, now)
				recs[character] = rec
			end
			if rec then
				seen[character] = true
				step(rec, dt, now, anims, isMe, camCF)
			end
		end
		for _, p in Players:GetPlayers() do
			visit(p.Character, p == me)
		end
		for _, bot in CollectionService:GetTagged("HuzzBot") do
			if bot:IsA("Model") then
				visit(bot, false)
			end
		end
		for character, rec in recs do
			if not seen[character] then
				if character.Parent then
					release(rec) -- (Locomotion took over yours, or it left: hand the joints back)
				end
				recs[character] = nil
			end
		end
		for character in tried do
			if character.Parent == nil then
				tried[character] = nil
			end
		end
	end)
end

return M
