--[[
	Everyone else drawn where the server has them now, not where they were a moment ago (owner, Oct 22 19:45, two
	recordings of one round, runner's and catcher's screens: "you see the difference in user locations, please fix
	it with the desync"). Measured on them (both pings ~55 ms): when the catcher's screen had the knife on the runner,
	the runner's screen had the catcher several studs behind. Each screen draws the others late: Roblox sends a body
	from its owner to the server and then here (half a ping each way), then smooths it (about 0.1 s more). Two late
	views add up, so a fast chase looked a body length or two apart.
	Here every other player's body is drawn ahead along the way they're moving by this screen's share of that delay
	(Config/Round.Ahead: your half ping + Interp, at most MaxLead s and MaxStuds studs), so it shows about where the
	server has them now; the runner and the catcher then see nearly the same thing. Only the drawn body moves: their
	root (what Roblox sends) stays, the root joint's C0 is shifted on this screen only (never sent). A body that
	stands still, lies caught (anchored) or jumps across the map (a teleport) is drawn where it is. The offset eases
	in and out (Smooth), so a turn bends instead of snapping.
	Gameplay/HitCheck sends this offset with the runner's root (`ahead`), and the server follows the runner's real path
	that far (Shared/TouchHit.verify), so the touch is judged where this screen drew them.
	Honest limits: a sharp turn shows the body a little past the corner for a moment (at most the lead's distance);
	the 0.1 s smoothing is an estimate, only real servers can show the best number.
	Since Oct 23 (owner, 08:36: "make the desync the most precise it can be"), no more guessing when the body's own
	stamps arrive (Shared/MotionStamps: each screen sends where its body is, how fast and where its keys head, with the
	server's clock; HuzzServer/MotionRelay passes them on; the Practice Bot's come from the server): the body is drawn
	where its newest stamp says it is right now, moved on by exactly the time since it was taken, heading the way the
	keys ask (so a turn shows as soon as it reaches this screen, not a smoothing later). Whatever Roblox's own delay is,
	the offset is from where Roblox draws the body to there, so it is measured, not guessed. A stamp older than
	MaxAge, or none yet: the guess above. Lag model (STAMP=1 lune run huzz-valley/tools/sim/touch_lag.luau).
	OthersAhead.offset(character) -> Vector3: how far this screen draws that body ahead (zero for your own).
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local Workspace = game:GetService("Workspace")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Round = require(Shared.Config.Round)
local MotionStamps = require(Shared.MotionStamps)

local OthersAhead = {}

type Rec = { joint: Motor6D, root: BasePart, base: CFrame, set: CFrame?, offset: Vector3 }
local recs: { [Model]: Rec } = {} -- (a plain table, dropped when the body goes)
local stamps: { [Model]: any } = {} -- character -> its newest stamp (Shared/MotionStamps; dropped with the body)

-- Keeps a stamp the server passed on (Net "Motion": the character, then the stamp).
function OthersAhead.stamp(model: Model, t, p, v, g, push)
	if typeof(model) ~= "Instance" or not model:IsA("Model") then return end
	local st = MotionStamps.read(t, p, v, g, push)
	local old = stamps[model]
	if st and not (old and old.t > st.t) then stamps[model] = st end -- (an unreliable one can come late: never go back)
end

-- Where the stamp says this body's root is drawn from Roblox's copy (flat, capped), or nil with no fresh stamp.
function OthersAhead.stampOffset(model: Model, root: BasePart, serverNow: number): Vector3?
	local st = stamps[model]
	if not st then return nil end
	-- (caught: their screen stops stamping, and the last one would carry the body on; the guess has it still)
	if model:GetAttribute("DownedAt") ~= nil then
		stamps[model] = nil
		return nil
	end
	local age = serverNow - st.t
	if age < -0.05 or age > MotionStamps.Config.MaxAge then return nil end
	return MotionStamps.limit(MotionStamps.predict(st, age) - root.CFrame.Position)
end

-- The seconds to draw others ahead: half your round trip plus Roblox's smoothing, capped.
function OthersAhead.lead(ping: number?): number
	local A = Round.Ahead
	local p = ping
	if p == nil then
		local ok, v = pcall(function() return Players.LocalPlayer:GetNetworkPing() end)
		p = if ok and type(v) == "number" and v == v then v else 0.1
	end
	return math.clamp((p :: number) / 2 + A.Interp, 0, A.MaxLead)
end

-- Where a body moving at `velocity` should be drawn ahead of its root (flat, capped; zero for a teleport's speed).
function OthersAhead.target(velocity: Vector3, lead: number): Vector3
	local A = Round.Ahead
	local flat = Vector3.new(velocity.X, 0, velocity.Z)
	if flat.Magnitude < 0.5 or flat.Magnitude > A.MaxSpeed then return Vector3.zero end
	local off = flat * lead
	if off.Magnitude > A.MaxStuds then off = off.Unit * A.MaxStuds end
	return off
end

-- The root joint's C0 that draws the body `offset` (world) away from its root.
function OthersAhead.c0(base: CFrame, rootCF: CFrame, offset: Vector3): CFrame
	return CFrame.new(base.Position + rootCF:VectorToObjectSpace(offset)) * base.Rotation
end

function OthersAhead.offset(character: Model?): Vector3
	local r = character and recs[character]
	return if r then r.offset else Vector3.zero
end

local function jointOf(model: Model): (Motor6D?, BasePart?)
	local root = model:FindFirstChild("HumanoidRootPart")
	if not (root and root:IsA("BasePart")) then return nil, nil end
	for _, j in root:GetChildren() do -- R6: RootJoint in the root
		if j:IsA("Motor6D") and j.Part0 == root and j.Part1 then return j, root end
	end
	local lower = model:FindFirstChild("LowerTorso") -- R15: Root in the LowerTorso
	local j = lower and lower:FindFirstChild("Root")
	if j and j:IsA("Motor6D") and j.Part0 == root then return j, root end
	return nil, root
end

-- (the same joint value, give or take float rounding)
local function same(a: CFrame, b: CFrame): boolean
	return (a.Position - b.Position).Magnitude < 1e-3 and (a.LookVector - b.LookVector).Magnitude < 1e-4
		and (a.UpVector - b.UpVector).Magnitude < 1e-4
end

local function release(model: Model)
	local r = recs[model]
	recs[model] = nil
	if r and r.joint.Parent then pcall(function() r.joint.C0 = r.base end) end
end

function OthersAhead.step(dt: number)
	local me = Players.LocalPlayer
	local lead = OthersAhead.lead()
	local k = 1 - math.exp(-Round.Ahead.Smooth * dt)
	local kStamp = 1 - math.exp(-(Round.Ahead.StampSmooth or Round.Ahead.Smooth) * dt)
	local serverNow = Workspace:GetServerTimeNow()
	local live: { [Model]: boolean } = {}
	local bodies: { Model } = {}
	for _, p in Players:GetPlayers() do
		if p ~= me and p.Character then table.insert(bodies, p.Character) end
	end
	for _, bot in CollectionService:GetTagged("HuzzBot") do
		if bot:IsA("Model") then table.insert(bodies, bot) end
	end
	for _, model in bodies do
		if live[model] then continue end
		live[model] = true
		local r = recs[model]
		if r and (r.joint.Parent == nil or r.root.Parent ~= model) then
			release(model)
			r = nil
		end
		if not r then
			local j, root = jointOf(model)
			if not (j and root) then continue end
			r = { joint = j, root = root, base = j.C0, set = nil, offset = Vector3.zero }
			recs[model] = r
		end
		local rec = r :: Rec
		-- (the server changed the joint itself, e.g. a body resized: that is the new base)
		if rec.set and not same(rec.joint.C0, rec.set) then rec.base = rec.joint.C0 end
		local fromStamp = if rec.root.Anchored then nil else OthersAhead.stampOffset(model, rec.root, serverNow)
		local target = if rec.root.Anchored then Vector3.zero
			else fromStamp or OthersAhead.target(rec.root.AssemblyLinearVelocity, lead)
		rec.offset = rec.offset:Lerp(target, if fromStamp then kStamp else k)
		if rec.offset.Magnitude < 0.01 and target == Vector3.zero then rec.offset = Vector3.zero end
		local c0 = OthersAhead.c0(rec.base, rec.root.CFrame, rec.offset)
		rec.joint.C0 = c0
		rec.set = c0
	end
	for model in recs do
		if not live[model] then release(model) end
	end
	for model in stamps do
		if not live[model] and model.Parent == nil then stamps[model] = nil end
	end
end

function OthersAhead.start()
	require(Shared.Net).get("Motion").OnClientEvent:Connect(OthersAhead.stamp)
	-- (before the physics step, so the body is drawn and hit-tested where it's shifted to this frame)
	require(script.Parent.Frame).on(1, OthersAhead.step)
end

return OthersAhead
