--[[
	PetFollow  (ModuleScript)
	Every player's equipped pets, rendered on this client (the server only
	publishes the EquippedPets attribute). Walkers stay on the ground and hop
	along, rocking left and right in step with their owner; flyers hover
	behind and bank into turns. Walkers kick up a little dust on each landing,
	new pets pop in with a bounce, and pets standing still turn to look at
	their owner. Built from the vault's "Pet Hatching and
	Following End to End" (client-rendered, anchored, frame-rate independent
	smoothing, ground raycast, snap on teleport, cull when far).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

-- Pets that fly (or swim through the air). Everyone else walks on the ground.
local FLYING = {
	ladybug = true, bee = true, bat = true, parrot = true, dragon = true, phoenix = true, golden_wing = true,
	clownfish = true, seahorse = true, shark = true, narwhal = true,
	ice_cube = true, crystal_cube = true, void_cube = true, shadow_cube = true, galaxy_cube = true,
	angel_cube = true, cosmo_cube = true, royal_cube = true, rainbow_cube = true,
}
-- How walkers move: "hop" bounces high (bunny, frog), "waddle" rocks wide (penguin, chick, crab)
local GAIT = {
	bunny = "hop", frog = "hop",
	penguin = "waddle", chick = "waddle", crab = "waddle", turtle = "waddle",
}
local GAITS = {
	trot = { Height = 0.7, Roll = 14, Rate = 1.0 },
	hop = { Height = 1.5, Roll = 8, Rate = 0.75 },
	waddle = { Height = 0.35, Roll = 22, Rate = 1.2 },
}

local PET_SIZE = 3 -- studs, longest side
local RADIUS = 6 -- studs behind the owner
local SPREAD = 0.75 -- radians between pets in the arc
local SHARPNESS = 9 -- follow snappiness
local SNAP_DISTANCE = 60 -- owner teleported: snap instead of streaking across the map
local CULL_DISTANCE = 260
local POP_TIME = 0.35 -- a newly equipped pet grows in with a bounce
local DUST = "rbxasset://textures/particles/smoke_main.dds" -- built in, nothing to upload

return function(ctx)
	local State = ctx.State

	local folder = Instance.new("Folder")
	folder.Name = "PetVisuals"
	folder.Parent = workspace

	local followers = {} -- [player] = { list of pet records }
	local hidden = {}
	local lastKeys = {} -- [player] = { [petName] = count } from the previous build, so only new pets pop in
	local showPets = true
	local lowGraphics = false

	-- one small dust emitter per walking pet, fired with Emit on each landing (vault VFX brief: Rate 0 + Emit)
	local function addDust(m)
		local base = m.PrimaryPart or m:FindFirstChildWhichIsA("BasePart", true)
		if not base then
			return nil
		end
		local att = Instance.new("Attachment")
		att.Name = "PetDust"
		att.Parent = base
		local e = Instance.new("ParticleEmitter")
		e.Texture = DUST
		e.Rate = 0
		e.Lifetime = NumberRange.new(0.45, 0.7)
		e.Speed = NumberRange.new(1.5, 3)
		e.SpreadAngle = Vector2.new(80, 80)
		e.Acceleration = Vector3.new(0, 2, 0)
		e.Drag = 4
		e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.8), NumberSequenceKeypoint.new(1, 1.9) })
		e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) })
		e.Color = ColorSequence.new(Color3.fromRGB(205, 190, 160))
		e.LightInfluence = 0.6
		e.LightEmission = 0
		e.ZOffset = -0.5
		e.Parent = att
		return { Attachment = att, Emitter = e }
	end

	local function clear(owner)
		for _, r in ipairs(followers[owner] or {}) do
			r.Model:Destroy()
		end
		followers[owner] = nil
		hidden[owner] = nil
	end

	local function build(owner)
		local before = lastKeys[owner] or {}
		clear(owner)
		local key = owner:GetAttribute("EquippedPets") or ""
		local seen = {}
		lastKeys[owner] = seen
		local templates = ReplicatedStorage:FindFirstChild("Pets")
		local list = {}
		followers[owner] = list
		if not templates or key == "" then
			return
		end
		for name in string.gmatch(key, "[^,]+") do
			local template = templates:FindFirstChild(name)
			if template then
				local m = template:Clone()
				if m:IsA("BasePart") then
					local wrap = Instance.new("Model")
					m.Parent = wrap
					m = wrap
				end
				for _, d in ipairs(m:GetDescendants()) do
					if d:IsA("BasePart") then
						d.Anchored = true
						d.CanCollide = false
						d.CanQuery = false
						d.CanTouch = false
						d.CastShadow = false
					elseif d:IsA("Script") or d:IsA("LocalScript") then
						d:Destroy()
					end
				end
				local _, size = m:GetBoundingBox()
				local biggest = math.max(size.X, size.Y, size.Z)
				if biggest > 0 then
					m:ScaleTo(m:GetScale() * PET_SIZE / biggest)
				end
				-- how far the pivot sits above the pet's feet
				m:PivotTo(CFrame.new())
				local box, boxSize = m:GetBoundingBox()
				local flying = FLYING[name] == true
				local dust = not flying and addDust(m) or nil
				-- a pet that wasn't equipped last time pops in; the rest just carry on
				seen[name] = (seen[name] or 0) + 1
				local isNew = seen[name] > (before[name] or 0)
				local baseScale = m:GetScale()
				if isNew then
					m:ScaleTo(baseScale * 0.05)
				end
				m.Parent = folder
				table.insert(list, {
					Model = m,
					Flying = flying,
					Gait = GAITS[GAIT[name] or "trot"],
					Foot = boxSize.Y / 2 - box.Position.Y,
					Phase = #list * 1.7, -- so pets don't move in lockstep
					Stride = math.random() * math.pi,
					Move = 0, -- 0 standing still .. 1 walking
					Pos = nil,
					GroundY = nil,
					Yaw = nil,
					Bank = 0,
					Dust = dust,
					Landing = 0,
					BaseScale = baseScale,
					Born = isNew and os.clock() or nil,
				})
			end
		end
	end

	local function watch(owner)
		owner:GetAttributeChangedSignal("EquippedPets"):Connect(function()
			build(owner)
		end)
		build(owner)
	end
	for _, p in ipairs(Players:GetPlayers()) do
		watch(p)
	end
	Players.PlayerAdded:Connect(watch)
	Players.PlayerRemoving:Connect(function(p)
		clear(p)
		lastKeys[p] = nil
	end)

	local function readSetting()
		local s = State.Data and State.Data.Settings
		if s then
			showPets = s.ShowPets ~= false
			lowGraphics = s.LowGraphics == true
		end
	end
	State.Changed:Connect(readSetting)
	readSetting()

	-- ground rays skip pets and characters; characters change, so refresh once a second
	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	task.spawn(function()
		while true do
			local ignore = { folder }
			for _, p in ipairs(Players:GetPlayers()) do
				if p.Character then
					table.insert(ignore, p.Character)
				end
			end
			rayParams.FilterDescendantsInstances = ignore
			task.wait(1)
		end
	end)

	local function yawOf(v)
		return math.atan2(-v.X, -v.Z)
	end
	local function turn(from, to, alpha)
		local d = (to - from + math.pi) % (2 * math.pi) - math.pi
		return from + d * alpha
	end

	RunService.RenderStepped:Connect(function(dt)
		dt = math.min(dt, 0.1)
		local t = os.clock()
		local camPos = workspace.CurrentCamera.CFrame.Position
		local alpha = 1 - math.exp(-SHARPNESS * dt)
		for owner, list in pairs(followers) do
			local root = owner.Character and owner.Character:FindFirstChild("HumanoidRootPart")
			local off = not showPets or not root or (root.Position - camPos).Magnitude > CULL_DISTANCE
			if off ~= (hidden[owner] == true) then
				hidden[owner] = off
				for _, r in ipairs(list) do
					r.Model.Parent = (not off) and folder or nil
					r.Pos = nil -- snap into place when shown again
				end
			end
			if off then
				continue
			end

			local vel = root.AssemblyLinearVelocity * Vector3.new(1, 0, 1)
			local speed = vel.Magnitude
			local ownerYaw = yawOf(root.CFrame.LookVector)
			local count = #list
			for i, r in ipairs(list) do
				local angle = (i - (count + 1) / 2) * SPREAD
				local goal = root.CFrame:PointToWorldSpace(Vector3.new(math.sin(angle) * RADIUS, 0, math.cos(angle) * RADIUS))
				local prev = r.Pos
				if not prev or (prev - goal).Magnitude > SNAP_DISTANCE then
					prev = goal
					r.GroundY = nil
					r.Yaw = ownerYaw
				end
				local pos = prev:Lerp(goal, alpha)
				local step = (pos - prev) * Vector3.new(1, 0, 1)
				r.Pos = pos

				-- walking blends in and out smoothly so a stop settles instead of freezing mid-hop
				local moving = speed > 2 or step.Magnitude > dt * 3
				r.Move += ((moving and 1 or 0) - r.Move) * math.min(1, dt * 8)

				-- face where the pet is going; standing still, turn to look at the owner
				local toOwner = (root.Position - pos) * Vector3.new(1, 0, 1)
				local wantYaw
				if step.Magnitude > dt * 1.5 then
					wantYaw = yawOf(step)
				elseif r.Move < 0.3 and toOwner.Magnitude > 0.5 then
					wantYaw = yawOf(toOwner)
				else
					wantYaw = ownerYaw
				end
				r.Yaw = turn(r.Yaw or wantYaw, wantYaw, math.min(1, dt * 10))

				-- pop in: grow from small with an overshoot, then stay at full size
				local k = 1
				if r.Born then
					local a = (t - r.Born) / POP_TIME
					if a >= 1 then
						r.Born = nil
					else
						local c1, c3 = 1.70158, 2.70158 -- back-out easing
						k = math.max(0.05, 1 + c3 * (a - 1) ^ 3 + c1 * (a - 1) ^ 2)
					end
					r.Model:ScaleTo(r.BaseScale * k)
				end

				local cf
				if r.Flying then
					-- hover just above head height, bob, lean forward and bank into turns
					local bank = math.clamp((wantYaw - r.Yaw + math.pi) % (2 * math.pi) - math.pi, -0.8, 0.8)
					r.Bank += (bank - r.Bank) * math.min(1, dt * 6)
					local y = root.Position.Y + 1.5 + math.sin(t * 2.2 + r.Phase) * 0.45 + math.sin(t * 9 + r.Phase) * 0.12 * r.Move
					cf = CFrame.new(pos.X, y, pos.Z)
						* CFrame.Angles(0, r.Yaw, 0)
						* CFrame.Angles(-0.25 * r.Move, 0, r.Bank * 0.6)
				else
					local hit = workspace:Raycast(Vector3.new(pos.X, root.Position.Y + 4, pos.Z), Vector3.new(0, -24, 0), rayParams)
					local groundY = hit and hit.Position.Y or (root.Position.Y - 3)
					-- ease over small steps, snap on big drops so pets never float
					r.GroundY = r.GroundY and (math.abs(groundY - r.GroundY) > 6 and groundY or r.GroundY + (groundY - r.GroundY) * math.min(1, dt * 14)) or groundY
					-- stride speed follows the owner's speed: faster run, quicker hops
					local g = r.Gait
					r.Stride += dt * (4 + math.min(speed, 40) * 0.45) * g.Rate * r.Move
					-- each time the hop touches down, a puff of dust
					local landing = math.floor(r.Stride * 2 / math.pi)
					if landing ~= r.Landing then
						r.Landing = landing
						if r.Dust and r.Move > 0.6 and not lowGraphics then
							r.Dust.Emitter:Emit(g == GAITS.hop and 6 or 3)
						end
					end
					local s = math.sin(r.Stride * 2)
					local hop = math.abs(math.sin(r.Stride * 2)) * g.Height * r.Move
					local rock = math.rad(g.Roll) * s * r.Move -- left / right
					local sway = s * 0.25 * r.Move
					local tilt = math.rad(-6) * r.Move + math.cos(r.Stride * 4) * math.rad(4) * r.Move
					-- standing still: a slow little breathe
					local idle = (1 - r.Move) * math.sin(t * 2 + r.Phase) * 0.05
					cf = CFrame.new(pos.X, r.GroundY + r.Foot * k + hop + idle, pos.Z)
						* CFrame.Angles(0, r.Yaw, 0)
						* CFrame.new(sway, 0, 0)
						* CFrame.Angles(tilt, 0, rock)
				end
				r.Model:PivotTo(cf)
			end
		end
	end)
end
