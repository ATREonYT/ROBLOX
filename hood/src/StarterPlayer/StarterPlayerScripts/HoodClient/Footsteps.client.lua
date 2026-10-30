-- Our own footsteps, each one the moment a foot lands on screen (Oct 27, the owner: "make custom walking sounds ... not
-- the original Roblox ones, and make them sound exactly when a step is taken on screen to not throw people off").
-- Every frame each nearby player's feet are read (their height under the character's root) and Shared/FootstepRules
-- says which one just landed; that foot plays a random take of the set for the floor under it (hard: floors, streets,
-- stages; soft: grass, dirt, sand), its pitch nudged a little so no two steps sound alike. A jump's landing plays one
-- louder step. Roblox's own running loop is muted on the characters we step for. While Shared/Config/Sound has no ids
-- for the steps (before hood/tools/upload_assets.py ran) this does nothing and Roblox's footsteps stay.
local Players = game:GetService('Players')
local RunService = game:GetService('RunService')
local Shared = game:GetService('ReplicatedStorage'):WaitForChild('Shared')
local Sound = require(Shared.Config.Sound)
local Rules = require(Shared.FootstepRules)
local InstanceMap = require(Shared.InstanceMap)

local HARD = { 'StepHard1', 'StepHard2', 'StepHard3' }
local SOFT = { 'StepSoft1', 'StepSoft2', 'StepSoft3' }
local FEET = { { 'LeftFoot', 'Left Leg' }, { 'RightFoot', 'Right Leg' } }
local RANGE = 70 -- studs from the camera: nearer characters are heard
local VOLUME, VOLUME_OTHERS, LAND = 0.4, 0.28, 1.4
local MOVING = 1.5 -- studs a second across the ground

local function ready(): boolean
	for _, k in HARD do if (Sound.Steps[k] or '') == '' then return false end end
	return Sound.Footsteps
end
if not ready() then return end

local rng = Random.new()
local chars = InstanceMap.new() -- character -> { feet = { {part, foot, sounds} }, root, humanoid }

local function muteRoblox(root: BasePart)
	local function mute(s: Instance)
		if s:IsA('Sound') and s.Name == 'Running' then
			s.Volume = 0
			s:GetPropertyChangedSignal('Volume'):Connect(function()
				if s.Volume ~= 0 then s.Volume = 0 end
			end)
		end
	end
	for _, s in root:GetChildren() do mute(s) end
	root.ChildAdded:Connect(mute)
end

local function soundsFor(part: BasePart, volume: number)
	local out = {}
	for _, list in { HARD, SOFT } do
		for _, k in list do out[k] = Sound.step(Sound.Steps[k], volume, part) end
	end
	return out
end

local function play(entry, foot, louder: number?)
	local list = if Rules.soft(entry.humanoid.FloorMaterial) then SOFT else HARD
	local s = foot.sounds[list[rng:NextInteger(1, #list)]]
	if not s then return end
	s.PlaybackSpeed = rng:NextNumber(0.92, 1.08)
	s.Volume = entry.volume * (louder or 1)
	s:Play()
end

local function track(char: Model, own: boolean)
	local humanoid = char:WaitForChild('Humanoid', 10) :: Humanoid?
	local root = char:WaitForChild('HumanoidRootPart', 10) :: BasePart?
	if not humanoid or not root or not char.Parent then return end
	local entry = { root = root, humanoid = humanoid, feet = {}, volume = own and VOLUME or VOLUME_OTHERS }
	for _, names in FEET do
		local part = char:WaitForChild(names[1], 3) or char:FindFirstChild(names[2])
		if part and part:IsA('BasePart') then
			table.insert(entry.feet, { part = part, foot = Rules.foot(), sounds = soundsFor(part, entry.volume) })
		end
	end
	if #entry.feet == 0 then return end
	muteRoblox(root)
	humanoid.StateChanged:Connect(function(_, new)
		if new == Enum.HumanoidStateType.Landed and entry.feet[1] then
			play(entry, entry.feet[1], LAND)
			for _, f in entry.feet do f.foot.armed = false end
		end
	end)
	chars[char] = entry
end

local function watch(p: Player)
	p.CharacterAdded:Connect(function(c) track(c, p == Players.LocalPlayer) end)
	if p.Character then task.spawn(track, p.Character, p == Players.LocalPlayer) end
end
for _, p in Players:GetPlayers() do watch(p) end
Players.PlayerAdded:Connect(watch)

local reported = false
RunService.Heartbeat:Connect(function(dt)
	local ok, err = pcall(function()
		local cam = workspace.CurrentCamera
		local eye = cam and cam.CFrame.Position
		for char, entry in chars do
			if not char.Parent or not entry.root.Parent then
				chars[char] = nil
				continue
			end
			local root, humanoid = entry.root, entry.humanoid
			local v = root.AssemblyLinearVelocity
			local moving = humanoid.Health > 0 and humanoid.FloorMaterial ~= Enum.Material.Air
				and Vector2.new(v.X, v.Z).Magnitude > MOVING
				and (not eye or (root.Position - eye).Magnitude < RANGE)
			for _, f in entry.feet do
				local h = root.CFrame:PointToObjectSpace(f.part.Position).Y
				if Rules.step(f.foot, h, dt, moving) then play(entry, f) end
			end
		end
	end)
	if not ok and not reported then
		reported = true
		warn('[Footsteps] ' .. tostring(err))
	end
end)
