--!strict
-- Feet that stick to the ground. Roblox's default Animate script still plays the walk/run/idle clips (the player's
-- own pack, or the ids Config/Movement.Anims sets at spawn), plus jump, fall, climb, swim and emotes; this controller
-- only takes over the WALK and RUN tracks while you're moving on the ground:
--   * blends walk -> run by ground speed with weights (Config/Movement.Stride BlendStart..BlendEnd), no hard switch
--   * sets their playback rate every frame so the planted foot doesn't slide: the rate comes from each clip's
--     authored speed, which is MEASURED from the planted foot (feedback, Rules/StrideRules) and remembered PER
--     ANIMATION ID, so any pack, a clip swapped at spawn, and any body scale all work without hand-tuned numbers.
-- How a measurement is taken (play-test 2026-11-02): during each foot contact we keep the sample from the moment the
-- foot is lowest (the true plant); landing and lift-off frames move fast in any clip and would read as sliding.
-- Hands control back to Animate when you stop, sit, swim, climb, fall, during cutscenes and minigames, and while
-- strafing / backpedalling (the clip only walks forward, so there's nothing to match). Local character only;
-- Animator replication shows the same timing to other players. GunPose (arms), the lean (root attachment) and the
-- cutscene Actors (their own rigs) are untouched.
-- Debug: the character gets attributes MTL_StrideRate, MTL_StrideSlip (mid-stance foot world speed, studs/s,
-- smoothed), MTL_StrideWalkA / MTL_StrideRunA (learned authored speeds of the clips playing now).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Movement = require(ReplicatedStorage.MTL.Config.Movement)
local StrideRules = require(ReplicatedStorage.MTL.Rules.StrideRules)
local UIState = require(script.Parent.UIState)

local S = Movement.Stride
local player = Players.LocalPlayer

local StrideController = {}

type Clip = { a: number, n: number } -- learned authored speed (studs/s at rate 1) + seconds of evidence
type Plant = { footVel: number, height: number, rate: number, runW: number, speed: number, dt: number, frames: number }

local hum: Humanoid? = nil
local root: BasePart? = nil
local lfoot: BasePart? = nil
local rfoot: BasePart? = nil
local animator: Animator? = nil

local learned: { [string]: Clip } = {} -- by AnimationId; survives respawns and clip swaps
local walkId: string? = nil -- the clips playing this frame
local runId: string? = nil
local runW = 0 -- eased run weight
local active = false
local lastRate = 1
local slip = 0
local prevL: Vector3? = nil
local prevR: Vector3? = nil
local stanceLeft: boolean? = nil
local plant: Plant? = nil -- lowest-foot sample of the current contact

local function blocked(h: Humanoid): boolean
	if player:GetAttribute("MTL_Cutscene") ~= nil or UIState.get().lockControls or h.Sit or h.Health <= 0 then
		return true
	end
	local st = h:GetState()
	return st ~= Enum.HumanoidStateType.Running and st ~= Enum.HumanoidStateType.RunningNoPhysics
end

-- found by name every frame, so tracks Animate (re)loads at spawn or after a clip swap are picked up at once
local function tracks(a: Animator): (AnimationTrack?, AnimationTrack?)
	local walk, run = nil, nil
	for _, t in a:GetPlayingAnimationTracks() do
		local anim = t.Animation
		local name = anim and anim.Name
		if name == "WalkAnim" then
			walk = t
		elseif name == "RunAnim" then
			run = t
		end
	end
	return walk, run
end

local function idOf(t: AnimationTrack?): string?
	local anim = t and t.Animation
	return anim and anim.AnimationId or nil
end

local function onCharacter(c: Model)
	hum, root, lfoot, rfoot, animator = nil, nil, nil, nil, nil
	local h = c:WaitForChild("Humanoid", 10) :: Humanoid?
	local r = c:WaitForChild("HumanoidRootPart", 10) :: BasePart?
	if not h or not r or player.Character ~= c then
		return
	end
	hum, root = h, r
	animator = h:WaitForChild("Animator", 10) :: Animator?
	active, prevL, prevR, stanceLeft, plant, slip = false, nil, nil, nil, nil, 0
end

local function feet(c: Model): (BasePart?, BasePart?)
	if not (lfoot and lfoot.Parent == c) then
		lfoot = c:FindFirstChild("LeftFoot") :: BasePart?
	end
	if not (rfoot and rfoot.Parent == c) then
		rfoot = c:FindFirstChild("RightFoot") :: BasePart?
	end
	return lfoot, rfoot
end

local function setWeight(t: AnimationTrack, w: number)
	if math.abs(t.WeightTarget - w) > 0.02 or (w <= 0.0001 and t.WeightTarget > 0.0001) then
		t:AdjustWeight(w, 0)
	end
end

-- a clip we've never measured starts from Animate's own idea of it (speed / the rate Animate gave it)
local function clip(id: string?, seed: number): Clip?
	if not id or id == "" then
		return nil
	end
	local c = learned[id]
	if not c then
		c = { a = seed, n = 0 }
		learned[id] = c
	end
	return c
end

-- before the Animator steps: set this frame's weights + rate
local function preAnimation(dt: number)
	local h, r, a = hum, root, animator
	if not h or not r or not a or not h.Parent then
		return
	end
	local v = r.AssemblyLinearVelocity
	local speed = Vector3.new(v.X, 0, v.Z).Magnitude
	if speed < S.MinSpeed or blocked(h) then
		active = false -- Animate's next Running event sets its own rate/weights again
		return
	end
	local walk, run = tracks(a)
	if not walk and not run then
		active = false
		return
	end
	local want = if run and walk then StrideRules.runWeight(speed, S.BlendStart, S.BlendEnd) elseif run then 1 else 0
	runW = StrideRules.follow(runW, want, 3 / math.max(S.WeightEase, 0.01), dt)
	if walk and run then
		setWeight(walk, math.max(1 - runW, 0.0001))
		setWeight(run, math.max(runW, 0.0001))
	end
	walkId, runId = idOf(walk), idOf(run)
	local seedTrack = (walk or run) :: AnimationTrack
	local seed = speed / math.max(seedTrack.Speed, 0.1)
	local wc = clip(walkId, seed)
	local rc = clip(runId, seed)
	-- a run clip we haven't measured yet doesn't get a say in the blend
	local w = if walk and run then (if rc and rc.n > 0 then runW else 0) elseif run then 1 else 0
	local authored = StrideRules.blendAuthored(if wc then wc.a elseif rc then rc.a else seed, if rc then rc.a elseif wc then wc.a else seed, w)
	-- rounded to 0.02 and only sent on change: AdjustSpeed/AdjustWeight replicate to other players
	local rate = math.floor(StrideRules.rateFor(speed, authored, S.MinRate, S.MaxRate) * 50 + 0.5) / 50
	if walk and math.abs(walk.Speed - rate) > 0.005 then
		walk:AdjustSpeed(rate)
	end
	if run and math.abs(run.Speed - rate) > 0.005 then
		run:AdjustSpeed(rate)
	end
	lastRate = rate
	active = true
end

-- one plant (the lowest-foot sample of a finished contact) -> learn the clips' authored speeds
local function learnFrom(p: Plant)
	if p.frames < S.MinStanceFrames then
		return
	end
	slip = StrideRules.follow(slip, math.abs(p.footVel), 6, 0.25)
	local a = StrideRules.authoredSpeed(p.speed, p.footVel, p.rate)
	if not a then
		return
	end
	-- each sample counts for one step's worth of evidence (~0.25 s)
	local dt = 0.25
	local wc = walkId and learned[walkId]
	local rc = runId and learned[runId]
	if p.runW < 0.5 and wc then
		local own = StrideRules.unblend(a, if rc and rc.n > 0 then rc.a else nil, p.runW)
		if own then
			wc.a, wc.n = StrideRules.learn(wc.a, wc.n, own, dt, S.Memory)
		end
	elseif rc then
		local own = StrideRules.unblend(a, if wc then wc.a else nil, 1 - p.runW)
		if own then
			rc.a, rc.n = StrideRules.learn(rc.a, rc.n, own, dt, S.Memory)
		end
	end
end

-- after physics: follow the planted foot; keep its lowest moment as this contact's sample
local function postSimulation(dt: number)
	local h, r = hum, root
	local c = player.Character
	if not h or not r or not c or dt <= 0 then
		return
	end
	local lf, rf = feet(c)
	if not lf or not rf then
		return -- R6 / custom rig: no feet to measure, Animate's seeded rate stays
	end
	local lp, rp = lf.Position, rf.Position
	local pl, pr = prevL, prevR
	prevL, prevR = lp, rp
	local v = r.AssemblyLinearVelocity
	local flat = Vector3.new(v.X, 0, v.Z)
	local speed = flat.Magnitude
	local look = r.CFrame.LookVector
	local facing = Vector3.new(look.X, 0, look.Z)
	if not active or not pl or not pr or speed < S.MinSpeed or facing.Magnitude < 0.1 then
		stanceLeft, plant = nil, nil
		return
	end
	local dir = flat / speed
	if facing.Unit:Dot(dir) < S.FacingShare then
		stanceLeft, plant = nil, nil -- strafing / backpedalling: nothing to learn from a forward walk clip
		return
	end
	local leftDown = lp.Y < rp.Y
	if stanceLeft ~= leftDown then
		-- the other foot just landed: the previous contact is over, learn from its plant
		local done = plant
		if stanceLeft ~= nil and done then
			learnFrom(done)
		end
		stanceLeft, plant = leftDown, nil
	end
	local p, pp = if leftDown then lp else rp, if leftDown then pl else pr
	local footVel = ((p - pp) / dt):Dot(dir)
	local cur = plant
	if not cur then
		plant = { footVel = footVel, height = p.Y, rate = lastRate, runW = runW, speed = speed, dt = dt, frames = 1 }
	else
		cur.frames += 1
		if p.Y < cur.height then
			cur.footVel, cur.height, cur.rate, cur.runW, cur.speed = footVel, p.Y, lastRate, runW, speed
		end
	end
	local wc = walkId and learned[walkId]
	local rc = runId and learned[runId]
	c:SetAttribute("MTL_StrideRate", math.floor(lastRate * 100 + 0.5) / 100)
	c:SetAttribute("MTL_StrideSlip", math.floor(slip * 100 + 0.5) / 100)
	c:SetAttribute("MTL_StrideWalkA", if wc then math.floor(wc.a * 10 + 0.5) / 10 else nil)
	c:SetAttribute("MTL_StrideRunA", if rc then math.floor(rc.a * 10 + 0.5) / 10 else nil)
end

function StrideController.init()
	player.CharacterAdded:Connect(onCharacter)
	if player.Character then
		task.spawn(onCharacter, player.Character)
	end
	RunService.PreAnimation:Connect(preAnimation)
	RunService.PostSimulation:Connect(postSimulation)
end

return StrideController
