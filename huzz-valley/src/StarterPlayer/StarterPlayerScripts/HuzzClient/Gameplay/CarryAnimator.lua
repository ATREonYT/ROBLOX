--[[
	Runs the girl animations on this client. The motion itself lives in
	Shared/CarryMotion and Shared/GirlMotion, which is the same code the offline
	preview runs. This script feeds them real parts every frame:
	  - every carried girl (Workspace.HuzzCarried): the pickup (owner, Oct 19: "add the nice girl animations when
	    they are picked up": she appears in front of him in a soft puff in her rarity colour, rises turning once into
	    his arms, and a soft ring at his feet and sparkles mark the catch: Config/Carry; no screen flash), the
	    carrier's raised arms and lean, her limbs and mood (model attributes Mood, MoodAt);
	  - the prize girl (tag "HuzzPrize"): her idle, watching the nearest player;
	  - a girl following a catcher (tag "HuzzFollower", Shared/FollowMotion): she drops
	    to the ground, then walks or runs behind him and stands when he stops;
	  - the big girl over the map (tag "HuzzShowcase"): she turns and floats slowly and plays the pack's Idle (the
	    scripted idle if the pack isn't here), watches the nearest player and waves and kicks now and then
	    (GirlMotion.showcase; owner Oct 20 "it doesnt seem fixed": the Idle alone read as a statue from the field). While the Secret cutscene plays her (HuzzRevealing) her
	    stand and stand lights are hidden on this screen and where she is is left to the cutscene; her Idle keeps
	    playing on her joints, so she breathes and looks round while her name is up (not a statue).
	The prize's idle and the follower's walk/run/idle are the owner's movement pack (Shared/GirlMoves:
	ReplicatedStorage.HuzzGirlMoves, which Bootstrap fills in Studio and live), played by hand on her joints;
	the built-in scripted ones (Shared/GirlMotion) only until that has arrived, or if it can't be read.
	Uploaded girl animations (Config/Animations.GirlWalk) still win when set.
	It writes Motor6D.Transform in PreSimulation, after Roblox's animations, so
	walk, run and huss animations keep the legs. An upper-body animation ID in
	Config/Animations.CarryArms replaces the scripted arms.
]]
local M = {}

function M.start()
	local CollectionService = game:GetService("CollectionService")
	local Players = game:GetService("Players")
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local Workspace = game:GetService("Workspace")

	local Shared = ReplicatedStorage:WaitForChild("Shared")
	local Animations = require(Shared.Config.Animations)
	local CarryMath = require(Shared.CarryMath)
	local CarryMotion = require(Shared.CarryMotion)
	local GirlMotion = require(Shared.GirlMotion)
	local FollowMotion = require(Shared.FollowMotion)
	local GirlMoves = require(Shared.GirlMoves)
	local RoundConfig = require(Shared.Config.Round)
	local Carry = require(Shared.Config.Carry)
	local Burst = require(script.Parent.Burst)

	local GirlLook = require(Shared.Config.GirlMotion).Idle
	local folder = Workspace:WaitForChild("HuzzCarried")
	-- One Output line (owner's Studio): whether this screen plays the movement pack on the girls or the scripted moves.
	local packState = nil
	local function packSaid(found)
		if packState == nil or (found and packState == false) then
			packState = found
			print(if found then "[Huzz] girls: movement pack found, the big girl plays its Idle"
				else "[Huzz] girls: movement pack not here yet, scripted idle (ReplicatedStorage.HuzzGirlMoves)")
		end
	end
	local useArmAnimation = Animations.CarryArms ~= ""
	local carries = {} -- model -> { rec, model, humanoid, armTrack }
	local prizes = {} -- model -> { state, joints, root }
	local showcases = {} -- model -> { state, joints, pack, rootHeight, stand = { parts }, lights = { lights } }
	local followers = {} -- model -> FollowMotion record (+ leaderId)

	local function motorsOf(model, except)
		local list = {}
		for _, d in model:GetDescendants() do
			if d:IsA("Motor6D") and d ~= except then
				table.insert(list, d)
			end
		end
		return list
	end

	-- Streaming: a model can reach this screen before its parts (GirlService sends the girls Persistent, so they come
	-- whole, but never trust it: known pitfall). Wait until she has her root and her parts stop arriving, up to 5 s.
	local function whenWhole(model)
		local whole = model.PrimaryPart ~= nil
		for _, d in model:GetDescendants() do
			if d:IsA("Motor6D") and not (d.Part0 and d.Part1) then whole = false end
		end
		if whole then return true end -- (the usual case: no wait, so her pickup starts on time)
		local count, still = -1, 0
		for _ = 1, 50 do
			if not model.Parent then return false end
			local n = 0
			for _, d in model:GetDescendants() do
				if d:IsA("BasePart") then n += 1 end
			end
			if model.PrimaryPart and n > 0 and n == count then
				still += 1
				if still >= 2 then return true end
			else
				still = 0
			end
			count = n
			task.wait(0.1)
		end
		return model.PrimaryPart ~= nil
	end

	local function seedOf(model)
		local seed = 0
		for i = 1, #model.Name do
			seed = (seed * 31 + string.byte(model.Name, i)) % 1000003
		end
		return seed
	end

	-- Her rarity colour (the Secret's own is near black: a pale glow instead, as her showcase does).
	local rarityColour = {}
	for _, r in RoundConfig.Rarities do
		rarityColour[r.Name] = r.Color
	end
	local function colourOf(model)
		local rarity = model:GetAttribute("Rarity")
		if rarity == "Secret" then
			return Color3.fromRGB(235, 235, 255)
		end
		return rarityColour[rarity] or Burst.PINK
	end

	-- The pickup's soft effects, once each, only while it is happening (not for someone who joins mid-carry) and only
	-- near this camera: a small puff where she appears, then a ring at his feet and sparkles round her as she lands.
	local function pickupFx(c, now)
		local rec = c.rec
		local age = now - rec.start
		local camera = Workspace.CurrentCamera
		if age > Carry.PickupTime + 0.5 or (camera and (camera.CFrame.Position - rec.root.Position).Magnitude > 150) then
			c.fxDone = true
			return
		end
		local colour = colourOf(c.model)
		if not c.puffed then
			c.puffed = true
			if age < 0.3 then
				pcall(Burst.sparks, rec.from, { colour, Burst.WHITE }, 8,
					{ speed = NumberRange.new(2, 5), gravity = Vector3.new(0, 3, 0), drag = 3, life = NumberRange.new(0.4, 0.7), glow = 0.4 })
			end
		end
		if CarryMotion.progress(rec, now) >= 1 then
			c.fxDone = true
			local girlRoot = rec.motor.Part1
			local at = if girlRoot then girlRoot.Position else rec.root.Position + Vector3.new(0, 4, 0)
			pcall(Burst.sparks, at, { colour, Burst.WHITE }, 14,
				{ speed = NumberRange.new(4, 8), gravity = Vector3.new(0, -4, 0), drag = 3, life = NumberRange.new(0.4, 0.8), glow = 0.4 })
			local humanoid = c.humanoid
			local down = if humanoid.HipHeight > 0.5 then humanoid.HipHeight + rec.root.Size.Y / 2 else 3
			pcall(Burst.ring, CFrame.new(rec.root.Position - Vector3.new(0, down - 0.15, 0)),
				{ r0 = 1.2, r1 = 5, time = 0.55, width = 0.14, glow = 0.5, color = colour, edge = colour, fade = 0.5 })
		end
	end

	local function stopCarry(model)
		local c = carries[model]
		if not c then
			return
		end
		carries[model] = nil
		CarryMotion.release(c.rec)
		if c.armTrack then
			c.armTrack:Stop(0.25)
		end
	end

	local function startCarry(model)
		local motor = model:WaitForChild("HuzzCarryMotor", 10)
		if motor then whenWhole(model) end -- (her limbs' joints, read once below)
		local torso = motor and motor.Part0
		local character = torso and torso.Parent
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local rig = character and CarryMath.rig(character)
		if not (humanoid and humanoid.RootPart and rig) or not model.Parent then
			return
		end
		local c = {
			model = model,
			humanoid = humanoid,
			rec = CarryMotion.new({
				motor = motor,
				rig = rig,
				root = humanoid.RootPart,
				girlMotors = motorsOf(model, motor),
				start = model:GetAttribute("Start") or Workspace:GetServerTimeNow(),
				from = model:GetAttribute("From"),
				seed = seedOf(model),
				useArmAnimation = useArmAnimation,
			}),
		}
		if useArmAnimation and character == Players.LocalPlayer.Character then
			local animator = humanoid:FindFirstChildOfClass("Animator")
			if animator then
				local animation = Instance.new("Animation")
				animation.AnimationId = Animations.CarryArms
				c.armTrack = animator:LoadAnimation(animation)
				c.armTrack.Priority = Enum.AnimationPriority.Action
				c.armTrack.Looped = true
				c.armTrack:Play(0.2)
			end
		end
		carries[model] = c
	end

	local function startPrize(model)
		if not whenWhole(model) or not model:HasTag("HuzzPrize") then return end
		local root = model.PrimaryPart
		if root then
			-- her root above her feet (sets her size for the pack's speeds and hips)
			local ok, cf, size = pcall(function() return model:GetBoundingBox() end)
			local rootHeight = if ok then math.clamp(root.Position.Y - (cf.Position.Y - size.Y / 2), 1, 6) else 3
			prizes[model] = { state = GirlMotion.new(seedOf(model)), joints = GirlMotion.joints(motorsOf(model)), root = root, rootHeight = rootHeight }
		end
	end

	-- The nearest player's head to a point.
	local function nearestHead(position)
		local best, bestDist = nil, math.huge
		for _, p in Players:GetPlayers() do
			local head = p.Character and p.Character:FindFirstChild("Head")
			if head then
				local d = (head.Position - position).Magnitude
				if d < bestDist then
					best, bestDist = head.Position, d
				end
			end
		end
		return best, bestDist
	end

	-- The owner's girl walk/run/idle animations (Config/Animations), played on this client.
	local function loadGirlTracks(model)
		if Animations.GirlWalk == "" then
			return nil
		end
		local humanoid = model:FindFirstChildOfClass("Humanoid")
		local animator = humanoid and (humanoid:FindFirstChildOfClass("Animator") or Instance.new("Animator", humanoid))
		if not animator then
			return nil
		end
		local tracks = {}
		for key, id in { Idle = Animations.GirlIdle, Walk = Animations.GirlWalk, Run = Animations.GirlRun } do
			if id ~= "" then
				local animation = Instance.new("Animation")
				animation.AnimationId = id
				local ok, track = pcall(animator.LoadAnimation, animator, animation)
				if ok then
					track.Looped = true
					track:Play(0.2, 0.001)
					tracks[key] = track
				end
			end
		end
		return tracks
	end

	-- Blends idle / walk / run by her speed and plays them at a matching rate.
	local function driveGirlTracks(tracks, speed)
		local walkSpeed, runSpeed = Animations.GirlWalkSpeed, Animations.GirlRunSpeed
		local run = if tracks.Run then math.clamp((speed - walkSpeed) / (runSpeed - walkSpeed), 0, 1) else 0
		local moving = math.clamp(speed / 2, 0, 1)
		local weights = { Idle = 1 - moving, Walk = moving * (1 - run), Run = moving * run }
		for key, track in tracks do
			track:AdjustWeight(math.max(weights[key], 0.001), 0.15)
		end
		if tracks.Walk then
			tracks.Walk:AdjustSpeed(math.max(speed, 1) / walkSpeed)
		end
		if tracks.Run then
			tracks.Run:AdjustSpeed(math.max(speed, 1) / runSpeed)
		end
	end

	local function startFollower(model)
		if not whenWhole(model) or not model:HasTag("HuzzFollower") then return end
		local root = model.PrimaryPart
		if not root then
			return
		end
		local tracks = loadGirlTracks(model)
		local rec = FollowMotion.new({
			root = root,
			motors = motorsOf(model),
			from = root.Position,
			rootHeight = model:GetAttribute("RootHeight"),
			seed = seedOf(model),
			animated = tracks ~= nil,
			moves = GirlMoves.find(os.clock()),
		})
		rec.leaderId = model:GetAttribute("Follow")
		rec.tracks = tracks
		followers[model] = rec
	end

	-- Ground height under a point, ignoring every character and girl, and anything you can't stand on: the maps'
	-- zone boxes (ZoneA / ZoneB / Middle: invisible markers but CanQuery on) and see-through effects. Without
	-- RespectCanCollide she stood on top of a zone box after the win (owner, Oct 20 15:13: "make the girls always be
	-- on the floor after the game is won"; tests/GirlFloor.spec: up to several studs up on his maps).
	local rayParams = RaycastParams.new()
	local filterAt = -math.huge -- (when the ray filter was last rebuilt)
	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	rayParams.RespectCanCollide = true
	local function groundAt(from, above)
		local origin = Vector3.new(from.X, math.max(from.Y, above) + 6, from.Z)
		local hit = Workspace:Raycast(origin, Vector3.new(0, -80, 0), rayParams)
		return hit and hit.Position.Y
	end

	folder.ChildAdded:Connect(function(model)
		task.spawn(startCarry, model)
	end)
	folder.ChildRemoved:Connect(stopCarry)
	for _, model in folder:GetChildren() do
		task.spawn(startCarry, model)
	end
	CollectionService:GetInstanceAddedSignal("HuzzPrize"):Connect(function(model) task.spawn(startPrize, model) end)
	CollectionService:GetInstanceRemovedSignal("HuzzPrize"):Connect(function(model)
		prizes[model] = nil
	end)
	for _, model in CollectionService:GetTagged("HuzzPrize") do
		task.spawn(startPrize, model)
	end
	CollectionService:GetInstanceAddedSignal("HuzzFollower"):Connect(function(model) task.spawn(startFollower, model) end)
	CollectionService:GetInstanceRemovedSignal("HuzzFollower"):Connect(function(model)
		followers[model] = nil
	end)
	for _, model in CollectionService:GetTagged("HuzzFollower") do
		task.spawn(startFollower, model)
	end

	require(script.Parent.Frame).on(20, function(dt)
		dt = math.clamp(dt, 1 / 240, 1 / 15)
		local now = Workspace:GetServerTimeNow()
		for model, c in carries do
			local rec = c.rec
			if not (model.Parent and rec.motor.Parent and rec.root.Parent and rec.rig.torso.Parent) then
				stopCarry(model)
			else
				local moodAt = model:GetAttribute("MoodAt") or rec.start
				CarryMotion.step(rec, dt, now, model:GetAttribute("Mood"), now - moodAt, nil, false) -- (no toss: owner's call)
				if not c.fxDone then
					pickupFx(c, now)
				end
			end
		end
		if next(followers) and now - filterAt > 0.5 then -- (rebuilt twice a second, not every frame)
			filterAt = now
			local ignore = { folder, Workspace:FindFirstChild("HuzzFollowers") }
			for _, p in Players:GetPlayers() do
				table.insert(ignore, p.Character)
			end
			rayParams.FilterDescendantsInstances = ignore
		end
		for model, rec in followers do
			local leader = Players:GetPlayerByUserId(rec.leaderId or 0)
			local leaderRoot = leader and leader.Character and leader.Character:FindFirstChild("HumanoidRootPart")
			if not model.Parent then
				followers[model] = nil
			elseif leaderRoot then
				rec.moves = rec.moves or GirlMoves.find(os.clock()) -- (once the pack has arrived)
				local head = leader.Character:FindFirstChild("Head")
				FollowMotion.step(rec, dt, now, leaderRoot.CFrame, function(p)
					return groundAt(p, leaderRoot.Position.Y)
				end, head and head.Position)
				if rec.tracks then
					driveGirlTracks(rec.tracks, rec.speed)
				end
			end
		end
		-- The big girl over the map turns slowly, floats up and down and breathes (the pack's Idle).
		for _, model in CollectionService:GetTagged("HuzzShowcase") do
			local base = model:GetAttribute("Base")
			local revealing = model:GetAttribute("HuzzRevealing") == true -- (Gameplay/SecretReveal moves her while it plays)
			local sc = showcases[model]
			if not sc and model.Parent and model.PrimaryPart then
				local ok, cf, size = pcall(function() return model:GetBoundingBox() end)
				local root = model.PrimaryPart
				sc = {
					state = GirlMotion.new(seedOf(model)), joints = GirlMotion.joints(motorsOf(model)), stand = {}, lights = {},
					rootHeight = if ok then math.max(root.Position.Y - (cf.Position.Y - size.Y / 2) - 1, 1) else 3, -- (her Aura box reaches 1 stud under her feet)
				}
				for _, name in { "StandTop", "StandBand", "StandGlow", "KeyLight", "RimLight" } do
					local part = model:FindFirstChild(name)
					if part and part:IsA("BasePart") then
						table.insert(sc.stand, part)
						for _, l in part:GetChildren() do
							if l:IsA("Light") then table.insert(sc.lights, l) end
						end
					end
				end
				showcases[model] = sc
			end
			if sc and sc.hidden ~= revealing then
				sc.hidden = revealing
				for _, part in sc.stand do part.LocalTransparencyModifier = if revealing then 1 else 0 end
				for _, l in sc.lights do l.Enabled = not revealing end
			end
			if typeof(base) == "CFrame" and model.Parent then
				local S = RoundConfig.Showcase
				if not revealing then
					model:PivotTo(base * CFrame.new(0, math.sin(now * 1.1) * S.Bob, 0) * CFrame.Angles(0, (now * S.Spin) % (2 * math.pi), 0))
				end
				if sc then
					-- she watches the nearest player wherever they are on the field (looking down at them)
					local target, distance = nearestHead(model:GetPivot().Position)
					local ctx = { target = target, distance = if target then math.min(distance, GirlLook.LookDistance - 1) else nil }
					local anims = GirlMoves.find(os.clock())
					packSaid(anims ~= nil)
					if anims then
						sc.pack = sc.pack or GirlMoves.new(anims, sc.rootHeight)
						GirlMoves.idle(sc.pack, sc.joints, dt, GirlMotion.look(sc.state, sc.joints, dt, now, ctx))
					else
						-- (the pack not here: the scripted idle, never a statue; she used to have no fallback at all)
						GirlMotion.idle(sc.state, sc.joints, dt, now, ctx)
					end
					GirlMotion.showcase(sc.state, sc.joints, dt, now) -- a wave and a kick now and then (Config/GirlMotion.Showcase)
				end
			end
		end
		for model in showcases do
			if not model:IsDescendantOf(game) then showcases[model] = nil end
		end
		for model, p in prizes do
			if model.Parent then
				local target, distance = nearestHead(p.root.Position)
				local anims = GirlMoves.find(os.clock())
				if anims then
					-- the pack's Idle, her head turned toward the nearest player on top
					p.pack = p.pack or GirlMoves.new(anims, p.rootHeight)
					local look = GirlMotion.look(p.state, p.joints, dt, now, { target = target, distance = distance })
					GirlMoves.idle(p.pack, p.joints, dt, look)
				else
					GirlMotion.idle(p.state, p.joints, dt, now, { target = target, distance = distance })
				end
			else
				prizes[model] = nil
			end
		end
	end)
end

return M
