--[[
	Crown Pose (a Robux cosmetic): when a player who wears it wins a game (or puts it on in the Shop), the server
	stamps HuzzPoseAt on their character; every client then plays the pose and the crown for everyone it can see
	(the pose and crown shapes: Shared/CrownPose, the same numbers as the offline video).
	The pose rides on top of Roblox's animations in the shared pose step (Gameplay/Frame order 35: after the run,
	carry and stab, before the knockdown), so legs keep walking and a downed player never poses.
	The crown is plain parts (moved after physics each frame): white metal and glowing pink gems, a twinkle burst as it lands on the head.
]]
local M = {}

function M.start()
	local Players = game:GetService("Players")
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local RunService = game:GetService("RunService")
	local Workspace = game:GetService("Workspace")

	local Shared = ReplicatedStorage:WaitForChild("Shared")
	local CrownPose = require(Shared.CrownPose)
	local CarryMath = require(Shared.CarryMath)
	local FxTexture = require(Shared.FxTexture)
	local Frame = require(script.Parent.Frame)

	local METAL = Color3.fromRGB(236, 238, 255)
	local GEM = Color3.fromRGB(255, 95, 180)
	local active = {} -- character -> { at, joints, crown, parts, burst, landed }

	local function jointsOf(character: Model)
		local joints = {}
		for _, d in character:GetDescendants() do
			if (d:IsA("Motor6D") or d.ClassName == "AnimationConstraint") and CrownPose.TARGET[d.Name] then
				joints[d.Name] = CarryMath.joint(d) -- (the newer joints too, his own avatar's)
			end
		end
		return joints
	end

	local function makeCrown(character: Model)
		local model = Instance.new("Model")
		model.Name = "HuzzCrown"
		local parts = {}
		for _, def in CrownPose.parts() do
			local p = Instance.new("Part")
			p.Shape = if def.shape == "Ball" then Enum.PartType.Ball else Enum.PartType.Block
			p.Size = def.size
			p.Color = if def.kind == "Gem" then GEM else METAL
			p.Material = if def.kind == "Gem" then Enum.Material.Neon else Enum.Material.Metal
			p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
			p.Parent = model
			table.insert(parts, { part = p, def = def })
		end
		local centre = Instance.new("Part")
		centre.Name = "Centre"
		centre.Transparency, centre.Size = 1, Vector3.new(0.2, 0.2, 0.2)
		centre.Anchored, centre.CanCollide, centre.CanQuery, centre.CanTouch = true, false, false, false
		centre.Parent = model
		-- the landing burst and a soft twinkle while it's worn
		local burst = Instance.new("ParticleEmitter")
		burst.Name = "Burst"
		FxTexture.flipbook(burst, "Twinkle", "Random")
		burst.Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)), ColorSequenceKeypoint.new(0.3, Color3.fromRGB(255, 190, 230)), ColorSequenceKeypoint.new(1, GEM) })
		burst.LightEmission, burst.LightInfluence = 1, 0
		burst.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.08, 0.55, 0.15), NumberSequenceKeypoint.new(1, 0) })
		burst.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.75, 0), NumberSequenceKeypoint.new(1, 1) })
		burst.Lifetime = NumberRange.new(0.45, 0.8)
		burst.Speed = NumberRange.new(4, 8)
		burst.Drag = 6
		burst.SpreadAngle = Vector2.new(180, 180)
		burst.Rotation = NumberRange.new(0, 360)
		burst.Rate = 0
		burst.Parent = centre
		local glint = burst:Clone()
		glint.Name = "Glint"
		glint.Speed = NumberRange.new(0.2, 0.6)
		glint.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.3, 0.3, 0.1), NumberSequenceKeypoint.new(1, 0) })
		glint.Rate = 5
		glint.Parent = centre
		model.Parent = Workspace
		return model, parts, centre
	end

	local function stop(character: Model)
		local a = active[character]
		if not a then return end
		active[character] = nil
		CrownPose.apply(a.joints, CrownPose.LENGTH + 1, a.written) -- (lets go of any joint no animation drives)
		if a.crown then a.crown:Destroy() end
	end

	local function start(character: Model)
		stop(character)
		local at = character:GetAttribute("HuzzPoseAt")
		if character:GetAttribute("HuzzPose") ~= "CrownPose" or type(at) ~= "number" then return end
		if Workspace:GetServerTimeNow() - at > CrownPose.LENGTH then return end -- (stamped long ago: someone joining late)
		local crown, parts, centre = makeCrown(character)
		active[character] = { at = at, joints = jointsOf(character), written = {}, crown = crown, parts = parts, centre = centre, landed = false }
	end

	local function watch(character: Model)
		character:GetAttributeChangedSignal("HuzzPoseAt"):Connect(function() start(character) end)
		character.Destroying:Connect(function() stop(character) end)
	end
	local function watchPlayer(p: Player)
		if p.Character then watch(p.Character) end
		p.CharacterAdded:Connect(watch)
	end
	Players.PlayerAdded:Connect(watchPlayer)
	for _, p in Players:GetPlayers() do watchPlayer(p) end

	Frame.on(35, function()
		local now = Workspace:GetServerTimeNow()
		for character, a in active do
			local t = now - a.at
			local head = character:FindFirstChild("Head") :: BasePart?
			if t > CrownPose.LENGTH or not head or not character.Parent then
				stop(character)
				continue
			end
			if character:GetAttribute("DownedAt") == nil then
				CrownPose.apply(a.joints, t, a.written)
			end
		end
	end)
	-- the crown follows the head after physics has moved it (no lag behind a running player)
	RunService.Heartbeat:Connect(function()
		local now = Workspace:GetServerTimeNow()
		for character, a in active do
			local t = now - a.at
			local head = character:FindFirstChild("Head") :: BasePart?
			if not head then continue end
			local up, spin, k = CrownPose.crownAt(t)
			local size = head.Size.X / 1.2 -- (scaled to the head)
			local top = head.CFrame * CFrame.new(0, head.Size.Y * 0.5 + 0.12 * size + up, 0) * CFrame.Angles(0, spin, 0)
			a.centre.CFrame = top
			local s = math.max(k, 0.01) * size
			local resize = s ~= a.lastScale -- (sizes only change while it grows in or shrinks away)
			a.lastScale = s
			for _, c in a.parts do
				if resize then c.part.Size = c.def.size * s end
				c.part.CFrame = top * CFrame.new(c.def.cf.Position * s) * c.def.cf.Rotation
			end
			if not a.landed and t >= 0.42 then
				a.landed = true
				a.centre.Burst:Emit(18)
			end
		end
	end)
end

return M
