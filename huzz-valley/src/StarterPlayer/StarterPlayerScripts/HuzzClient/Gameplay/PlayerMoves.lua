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
	  - Shift lock in a round (owner, Oct 19: "the only thing that moves when you press w a s d (etc) is their body
	    not their head"): a body moving another way than it faces gets its hips and legs turned toward the move and
	    its head turned back to where it faces (LocomotionMix.strafe; backwards = a back-pedal), from the way its
	    body goes (LocomotionMix.track's vel), so everyone sees it, yours too in the live game. Heads (Oct 19 19:48,
	    "make it follow mouse movements"): yours looks at the point under your mouse (Gameplay/HeadAim, live), the
	    others' spring to the turn their screen sent (their character's HuzzLook, ~5 a second: HeadLookService).
	  - Setting off walks first and a stop from a run plays the quick plant (LocomotionMix SetOff / Stop, measured on
	    Huss Valley's recording): the body tips back a little and the arms swing out, on everyone. Others' stops read
	    ~0.15 s after their body stops (LocomotionMix.track: a body still for longer than a network stall has stopped).
	  - The halt (owner, Oct 20 07:55: "they move a little forward as a sort of "hault""): yours from Gameplay/Sprint's
	    HuzzHalt, anyone else's from their MoveDirection going to zero while the body still slides at
	    a run: the plant at once and the feet skid (LocomotionMix input.halt).
	Off when the owner has published Idle, Walk and Run (Config/Animations): then the real tracks replicate.
]]
local M = {}

local recs = {} -- character Model -> rec (a plain table, cleared when the character goes: never a weak table)

-- True while this draws the character's walk (RunAnimator then draws only the huss and the cast pose on it).
function M.drives(character: Model?): boolean
	return character ~= nil and recs[character] ~= nil
end

-- True while this screen shows the character halting (the last frame's read; tests/PlayerMoves.spec).
function M.halting(character: Model?): boolean
	local rec = character and recs[character]
	return rec ~= nil and rec.halt == true
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
	local HeadAim = require(script.Parent.HeadAim)
	local T = RunConfig.Track
	local DASH_LENGTH = RunConfig.Dash.Length
	local LEAP_LENGTH = 0.85 -- seconds a catcher's leap owns the body (Shared/StabMotion LEAP.Up, plus a little)
	local BRACE_JOINTS = { LowerTorso = "Root", RightUpperLeg = "RightHip", RightLowerLeg = "RightKnee",
		LeftUpperLeg = "LeftHip", LeftLowerLeg = "LeftKnee" } -- (part -> its joint, for LocomotionMix.braceJoint)
	local PLAYING = { HeroRun = true, Countdown = true, Running = true, RoundOver = true } -- (shift lock's stages)

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
			if m and m.Parent and m.Transform == rec.written[name] then -- (a joint posed again this frame keeps it)
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
						-- (the carry arms are an Action loop too, but the legs keep walking under them: CarryAnimator)
						if t.Priority == Enum.AnimationPriority.Action and t.WeightCurrent > 0.05
							and not (Animations.CarryArms ~= "" and t.Animation and t.Animation.AnimationId == Animations.CarryArms) then
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
			if cf and name == "LowerTorso" then
				cf = CFrame.new(cf.Position * rec.k) * cf.Rotation -- (the hips' bob, to the avatar's size)
				if rec.lean then
					cf = rec.lean * cf
				end
			end
			cf = (rec.turned and rec.turned[name]) or cf -- (shift lock's strafe: the final pose, lean and size in)
			if cf then
				local current = m.Transform
				-- (nothing animated it since our last write: blend from the last real pose, don't stack)
				local base = if rec.written[name] == current then rec.base[name] else current
				rec.base[name] = base
				m.Transform = if w >= 0.999 or not base then cf else base:Lerp(cf, w)
				rec.written[name] = m.Transform -- read back: Roblox stores CFrames as float32
			end
		end
	end

	local function step(rec, dt, now, anims, isMe, camCF, playing)
		local character, root, humanoid = rec.character, rec.root, rec.humanoid
		local pos = root.CFrame.Position
		local speed, up
		if isMe then
			local v = root.AssemblyLinearVelocity
			speed, up = Vector3.new(v.X, 0, v.Z).Magnitude, v.Y
		else
			local v = root.AssemblyLinearVelocity
			speed, up = Mix.track(rec.tracker, now, pos, Vector3.new(v.X, 0, v.Z).Magnitude)
		end
		local downed = character:GetAttribute("DownedAt") ~= nil
		if downed or root.Anchored or humanoid.Sit then
			speed = 0
		end
		-- (their replicated velocity too: the tracked climb is averaged over a window, so it lags a fall or a knock by a few frames)
		local airborne = math.abs(up) > 8 or math.abs(root.AssemblyLinearVelocity.Y) > 8
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
		-- The halt (owner, Oct 20 07:55: "they move a little forward as a sort of "hault""): yours from Gameplay/Sprint
		-- (HuzzHalt); anyone else's when their Humanoid says no key is held (MoveDirection) while the
		-- body still slides at a run. Only once their MoveDirection has been seen moving: if it never reaches this
		-- screen, it never reads as a halt. The feet plant and skid (LocomotionMix input.halt). Never mid huss or dive
		-- (a huss with no key held, on a phone) nor in the air (a fall, a knock): those move fast with no key too.
		local halt = false
		local hussAt, diveAt, nowServer = RunMotion.dashAt(character), character:GetAttribute("LungeAt"), Workspace:GetServerTimeNow()
		local pushed = (type(hussAt) == "number" and nowServer - hussAt < DASH_LENGTH + 0.1)
			or (type(diveAt) == "number" and nowServer - diveAt < LEAP_LENGTH)
		if isMe then
			halt = character:GetAttribute("HuzzHalt") == true
		elseif pushed or airborne then
			halt = false
		elseif not downed then
			local md = humanoid.MoveDirection
			if typeof(md) == "Vector3" and md.Magnitude > 0.1 then
				rec.sawMove = true
			elseif rec.sawMove and typeof(md) == "Vector3" and speed > rec.mix.C.RunFull then
				halt = true
			end
		end
		rec.halt = halt
		rec.acc += dt
		if rec.pose == nil or rec.acc >= interval then
			local sdt = math.min(rec.acc, 0.2)
			rec.acc = 0
			Mix.step(rec.mix, sdt, {
				speed = speed, state = "ground", stride = if airborne then 0.3 else 1,
				lengths = { Walk = anims.Walk.length, Run = anims.Run.length },
				halt = halt,
			})
			rec.idleT += sdt
			local pose = Mix.pose(rec.mix, anims, rec.idleT, Sampler.sample)
			-- the stop's plant: arms out as the feet come together (and below, the body tips back a little)
			local plant = if downed or quiet or airborne then 0 else Mix.stopAmount(rec.mix)
			if plant > 1e-4 then
				if pose.RightUpperArm then pose.RightUpperArm = Mix.stopArm(rec.mix, plant, 1) * pose.RightUpperArm end
				if pose.LeftUpperArm then pose.LeftUpperArm = Mix.stopArm(rec.mix, plant, -1) * pose.LeftUpperArm end
			end
			-- the halt's braced stance: hips low and back, one leg forward, knees bent (LocomotionMix.brace)
			local brace = if downed or quiet or airborne then 0 else Mix.brace(rec.mix)
			if brace > 1e-4 then
				for part, joint in BRACE_JOINTS do
					local m = rec.motors[part]
					if pose[part] and m then
						pose[part] = Mix.braceJoint(rec.mix, brace, joint, m.C0) * pose[part]
					end
				end
			end
			rec.lean = nil
			if not isMe and plant > 1e-4 and pose.LowerTorso then
				local c0 = rec.motors.LowerTorso.C0
				local pitch = math.rad(rec.mix.C.Stop.Lean) * plant
				rec.lean = c0:Inverse() * Mix.leanCFrame(0, pitch, root.Size.Y / 2 + humanoid.HipHeight) * c0
			end
			rec.roll = 0
			if pose.LowerTorso and (isMe or plant <= 1e-4) then
				-- the lean into turns and into speeding up (as Locomotion adds on top in Studio); everyone's, so another
				-- runner banks into a turn too (owner, Oct 21), the stop's plant inside it (Mix.lean)
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
				rec.roll = roll
			end
			-- shift lock's strafe: yours from your shift lock, anyone else's in a round from the way their body goes
			local dashAt = RunMotion.dashAt(character)
			local lungeAt = character:GetAttribute("LungeAt")
			local server = Workspace:GetServerTimeNow()
			local busy = (type(dashAt) == "number" and server - dashAt < DASH_LENGTH + 0.1)
				or (type(lungeAt) == "number" and server - lungeAt < LEAP_LENGTH)
			local vel = if isMe then root.AssemblyLinearVelocity else rec.tracker.vel
			local on = if isMe then Players.LocalPlayer:GetAttribute("HuzzShiftLock") == true else playing == true
			local still = if downed or busy or quiet or airborne then 1 else 0
			local turn = Mix.strafe(rec.mix, sdt, root.CFrame:VectorToObjectSpace(vel), on, still)
			-- heads: yours toward the point under your mouse (Gameplay/HeadAim), the others' to what their screen sent
			local look, tilt = 0, 0
			if isMe and camCF then
				local aim, up = HeadAim.aim(root)
				look, tilt = Mix.look(rec.mix, sdt, aim, not on, still, up)
				HeadAim.report(look, tilt)
			elseif not isMe then
				local sent = character:GetAttribute("HuzzLook")
				if typeof(sent) == "Vector2" or rec.mix.look ~= 0 or (rec.mix.lookUp or 0) ~= 0 then
					local v = if typeof(sent) == "Vector2" then sent else Vector2.zero
					look, tilt = Mix.look(rec.mix, sdt, math.rad(v.X), true, still, math.rad(v.Y), true)
				end
			end
			rec.turned = nil
			local hipsM, waistM, neckM = rec.motors.LowerTorso, rec.motors.UpperTorso, rec.motors.Head
			local lt, ut, hd = pose.LowerTorso, pose.UpperTorso, pose.Head
			if (math.abs(turn) > 1e-3 or math.abs(look) > 1e-3 or math.abs(tilt) > 1e-3) and hipsM and waistM and neckM and lt and ut and hd then
				local hips = CFrame.new(lt.Position * rec.k) * lt.Rotation
				if rec.lean then
					hips = rec.lean * hips
				end
				local r, w, n = Mix.strafePose(rec.mix, turn, {
					root = { C0 = hipsM.C0, C1 = hipsM.C1, T = hips },
					waist = { C0 = waistM.C0, C1 = waistM.C1, T = ut },
					neck = { C0 = neckM.C0, C1 = neckM.C1, T = hd },
				}, look, tilt)
				rec.turned = { LowerTorso = r, UpperTorso = w, Head = n }
			end
			-- the head stays level while the body banks (Config/Run.Loco.HeadLevel)
			local level = -(rec.roll or 0) * (rec.mix.C.HeadLevel or 0)
			if math.abs(level) > 1e-4 then
				if rec.turned then
					rec.turned.Head = rec.turned.Head * CFrame.Angles(0, 0, level)
				elseif pose.Head then
					pose.Head = pose.Head * CFrame.Angles(0, 0, level)
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
		local remotes = ReplicatedStorage:FindFirstChild("Remotes") -- (Shared/Net's folder; the Round remote holds Stage)
		local round = remotes and remotes:FindFirstChild("Round")
		local stage = round and round:GetAttribute("Stage")
		local roundOn = PLAYING[stage] == true
		local function visit(character: Model?, isMe: boolean, playing: boolean?)
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
				step(rec, dt, now, anims, isMe, camCF, playing)
			end
		end
		for _, p in Players:GetPlayers() do
			local role = p:GetAttribute("HuzzRole")
			visit(p.Character, p == me, roundOn and (role == "Runner" or role == "Catcher"))
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
