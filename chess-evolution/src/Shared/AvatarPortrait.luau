--!strict
-- +1 Chess Evolution: the player's own avatar, alive inside a ViewportFrame.
-- Copies the reference's Evolve window (clip 3, Nov 8): a chest-up shot of your character
-- flexing both arms, pumping about once a second, with a small bob.
-- No animation IDs: the clone is anchored and posed by hand every frame from its own joints,
-- so it works for R15, R6 and the newer AnimationConstraint avatars, in any ViewportFrame (no Animator needed).
-- Use: local p = AvatarPortrait.new(viewportFrame); p:Play(character); p:Stop()
local RunService = game:GetService("RunService")

local AvatarPortrait = {}
AvatarPortrait.__index = AvatarPortrait

-- Feel numbers (measured on clip 3 at 30 fps: one flex pump ~1.1 s, arms stay high)
local PUMP = 1.1 -- seconds per flex
local SHOULDER = { 72, 16 } -- degrees: arm raised out to the side, + extra on the pump
local ELBOW = { 78, 34 } -- degrees: forearm up, + squeeze on the pump
local BOB = 0.06 -- studs, body bob on the pump
local SWAY = 5 -- degrees, slow waist turn
local NOD = 4 -- degrees, head nod
local CAM_DIST = 8 -- studs from the face (FOV 30)

type Joint = { part0: BasePart, part1: BasePart, c0: CFrame, c1: CFrame, rot: CFrame, name: string }

local function strip(model: Model)
	for _, d in model:GetDescendants() do
		if d:IsA("BaseScript") or d:IsA("ModuleScript") or d:IsA("Sound") or d:IsA("BillboardGui")
			or d:IsA("ForceField") or d:IsA("Tool") or d:IsA("ParticleEmitter") or d:IsA("Beam")
			or d:IsA("Trail") or d:IsA("Light") or d:IsA("Highlight") then
			d:Destroy()
		end
	end
	-- the chess item and aura ride along as plain Models; the reference shows the bare avatar
	for _, c in model:GetChildren() do
		if c:IsA("Model") or c:IsA("Folder") then
			c:Destroy()
		end
	end
end

-- Clone a character so it can live in a ViewportFrame. Returns nil when it can't be copied yet.
local function copy(character: Model): Model?
	local was = character.Archivable
	character.Archivable = true
	local ok, clone = pcall(function()
		return character:Clone()
	end)
	character.Archivable = was
	if not ok or not clone then
		return nil
	end
	strip(clone)
	local hum = clone:FindFirstChildOfClass("Humanoid")
	if hum then
		hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		hum.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	end
	return clone
end

function AvatarPortrait.new(vf: ViewportFrame)
	local self = setmetatable({}, AvatarPortrait)
	self.vf = vf
	self.world = vf:FindFirstChildOfClass("WorldModel") or Instance.new("WorldModel")
	self.world.Parent = vf
	self.camera = vf:FindFirstChild("Cam") :: Camera?
	if not self.camera then
		local cam = Instance.new("Camera")
		cam.Name = "Cam"
		cam.Parent = vf
		self.camera = cam
	end
	vf.CurrentCamera = self.camera
	self.t0 = os.clock()
	return self
end

-- Build the rig from a fresh copy of `character`. Joints are recorded, then removed, and every part
-- is anchored: we place each part ourselves each frame.
function AvatarPortrait:SetCharacter(character: Model?): boolean
	if self.model then
		self.model:Destroy()
		self.model = nil
	end
	if not character then
		return false
	end
	local model = copy(character)
	local root = model and (model:FindFirstChild("HumanoidRootPart") or model.PrimaryPart) :: BasePart?
	if not model or not root then
		if model then
			model:Destroy()
		end
		return false
	end
	local joints: { Joint } = {}
	local links: { [BasePart]: { Joint } } = {}
	local function link(j: Joint)
		table.insert(joints, j)
		links[j.part0] = links[j.part0] or {}
		links[j.part1] = links[j.part1] or {}
		table.insert(links[j.part0], j)
		table.insert(links[j.part1], j)
	end
	for _, d in model:GetDescendants() do
		if d:IsA("JointInstance") and d.Part0 and d.Part1 then
			local c0 = d.C0
			link({ part0 = d.Part0, part1 = d.Part1, c0 = c0, c1 = d.C1, rot = c0 - c0.Position, name = d.Name })
		elseif (d:IsA("AnimationConstraint") or d:IsA("RigidConstraint")) and d.Attachment0 and d.Attachment1
			and d.Attachment0.Parent and d.Attachment0.Parent:IsA("BasePart") and d.Attachment1.Parent and d.Attachment1.Parent:IsA("BasePart") then
			-- Roblox's newer avatar joints (Nov 2026 Studio): attachments instead of Motor6D C0/C1
			local c0 = d.Attachment0.CFrame
			link({ part0 = d.Attachment0.Parent :: BasePart, part1 = d.Attachment1.Parent :: BasePart, c0 = c0, c1 = d.Attachment1.CFrame, rot = c0 - c0.Position, name = if d:IsA("AnimationConstraint") then d.Name else "" })
		elseif d:IsA("WeldConstraint") and d.Part0 and d.Part1 then
			link({ part0 = d.Part0, part1 = d.Part1, c0 = d.Part0.CFrame:ToObjectSpace(d.Part1.CFrame), c1 = CFrame.identity, rot = CFrame.identity, name = "" })
		end
	end
	for _, d in model:GetDescendants() do
		if d:IsA("JointInstance") or d:IsA("Constraint") or d:IsA("WeldConstraint") or d:IsA("NoCollisionConstraint") then
			d:Destroy()
		elseif d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
		end
	end
	-- stand at the origin; the character faces -Z, where the camera waits
	local base = CFrame.lookAt(Vector3.zero, Vector3.new(0, 0, -1))
	self.model, self.root, self.joints, self.links, self.base = model, root, joints, links, base
	model.Parent = self.world

	-- frame head and chest; arms reach up beside the head, so leave room above it
	self:Pose(0)
	local head = model:FindFirstChild("Head") :: BasePart?
	local headY = if head then head.Position.Y else 1.5
	local headSize = if head then head.Size.Y else 1.2
	-- the reference's crop: hair near the top edge, fists beside the head, cut at the belly
	local aim = Vector3.new(0, headY - headSize * 0.45, 0)
	local cam = self.camera :: Camera
	cam.FieldOfView = 30
	cam.CFrame = CFrame.lookAt(aim + Vector3.new(0, headSize * 0.2, -CAM_DIST), aim)
	return true
end

-- Rotation R (in the joint's parent part space, about the joint) as a Motor6D Transform.
local function asTransform(j: Joint, r: CFrame): CFrame
	return j.rot:Inverse() * r * j.rot
end

local rad = math.rad
local function poseFor(name: string, k: number, t: number): CFrame?
	local sh = rad(SHOULDER[1] + SHOULDER[2] * k)
	local el = rad(ELBOW[1] + ELBOW[2] * k)
	if name == "RightShoulder" or name == "Right Shoulder" then
		return CFrame.Angles(0, 0, sh)
	elseif name == "LeftShoulder" or name == "Left Shoulder" then
		return CFrame.Angles(0, 0, -sh)
	elseif name == "RightElbow" then
		return CFrame.Angles(0, 0, el)
	elseif name == "LeftElbow" then
		return CFrame.Angles(0, 0, -el)
	elseif name == "Waist" or name == "RootJoint" then
		return CFrame.Angles(0, rad(SWAY) * math.sin(t * 1.3), 0)
	elseif name == "Neck" then
		return CFrame.Angles(rad(NOD) * k - rad(2), 0, 0)
	end
	return nil
end

function AvatarPortrait:Pose(t: number)
	local root = self.root :: BasePart?
	if not root or not root.Parent then
		return
	end
	-- k: 0..1 flex pump, eased so the squeeze snaps and the release is softer
	local s = 0.5 + 0.5 * math.sin(t * 2 * math.pi / PUMP)
	local k = s * s * (3 - 2 * s)
	local placed: { [BasePart]: CFrame } = { [root] = self.base * CFrame.new(0, BOB * k, 0) }
	local queue = { root }
	local parts, frames = { root }, { placed[root] }
	local i = 1
	while i <= #queue do
		local cur = queue[i]
		i += 1
		local cf = placed[cur]
		for _, j in self.links[cur] or {} do
			local other = if j.part0 == cur then j.part1 else j.part0
			if not placed[other] then
				local r = poseFor(j.name, k, t)
				local tr = if r then asTransform(j, r) else CFrame.identity
				local ocf = if j.part0 == cur then cf * j.c0 * tr * j.c1:Inverse() else cf * j.c1 * tr:Inverse() * j.c0:Inverse()
				placed[other] = ocf
				table.insert(queue, other)
				table.insert(parts, other)
				table.insert(frames, ocf)
			end
		end
	end
	local ok = pcall(function()
		self.world:BulkMoveTo(parts, frames, Enum.BulkMoveMode.FireCFrameChanged)
	end)
	if not ok then
		for n, p in parts do
			p.CFrame = frames[n]
		end
	end
end

-- Start (or restart) the loop with a fresh copy of the character, so the outfit is always current.
function AvatarPortrait:Play(character: Model?)
	self:Stop()
	if not self:SetCharacter(character) then
		return false
	end
	self.conn = RunService.RenderStepped:Connect(function()
		self:Pose(os.clock() - self.t0)
	end)
	return true
end

function AvatarPortrait:Stop()
	if self.conn then
		self.conn:Disconnect()
		self.conn = nil
	end
end

function AvatarPortrait:Destroy()
	self:Stop()
	if self.model then
		self.model:Destroy()
		self.model = nil
	end
end

return AvatarPortrait
