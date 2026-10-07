-- SPEED treadmills: stand on the belt of a treadmill you have unlocked and every second it adds its
-- Multiplier to your Speed (Jog x1, Run x3, Sprint x10; Config/Treadmills). Speed makes you walk faster:
-- Config/Treadmills.walkSpeed turns it into Humanoid.WalkSpeed (16 up to a cap of 40, quick gains first).
--
-- Treadmills are the Treadmill_<Id> models in the active map (built by TheBlockV2's Treadmills.build), each
-- with an invisible TreadmillZone over its belt. A locked one (not enough Power) pays nothing and says once
-- what it needs. Speed is saved in the profile (ProfileSchema field Speed).
--
-- Player attributes kept in step with the profile:
--   Speed      the stat
--   WalkSpeed  the walk speed it gives (also set on the Humanoid every spawn and whenever it changes)
--   Treadmill  id of the unlocked treadmill you are running on, or ''
local Players = game:GetService('Players')
local RS = game:GetService('ReplicatedStorage')
local Data = require(script.Parent.DataService)
local Net = require(RS.Shared.Net)
local ActiveMap = require(RS.Shared.ActiveMap)
local Format = require(RS.Shared.Format)
local Treadmills = require(RS.Shared.Config.Treadmills)

while not RS:GetAttribute('FoundationReady') do task.wait(0.1) end
-- No treadmills on this map is fine: Speed still sets your walk speed.
local active = ActiveMap.get()

-- Every treadmill's zone: { Id, Part }. Read once from the built map (and again later if it had none yet).
local zones = {}
local function scan()
	table.clear(zones)
	if not active then return end
	for _, d in active.Root:GetDescendants() do
		if d.Name == 'TreadmillZone' and d:IsA('BasePart') and d.Parent then
			local model = d.Parent
			local id = model:GetAttribute('TreadmillId') or string.match(model.Name, '^Treadmill_(.+)$')
			if id and Treadmills.ById[id] then table.insert(zones, { Id = id, Part = d }) end
		end
	end
end
scan()
if active and #zones == 0 then warn('[TreadmillService] No Treadmill_<Id> models with a TreadmillZone in the active map.') end

-- The treadmill under a HumanoidRootPart position: over the zone's footprint (a little slack sideways) and
-- from just under its top to 8 studs above it.
local function treadmillAt(position)
	for _, z in zones do
		local part = z.Part
		local rel = part.CFrame:PointToObjectSpace(position)
		local size = part.Size
		local up = rel.Y - size.Y / 2
		if math.abs(rel.X) <= size.X / 2 + 0.3 and math.abs(rel.Z) <= size.Z / 2 and up >= -0.5 and up <= 8 then
			return z.Id
		end
	end
	return nil
end

-- Profile -> attributes and the Humanoid. WalkSpeed is written only when the target changes (or on a new
-- character), so anything else that slows a player for a moment isn't fought every second.
local applied = setmetatable({}, { __mode = 'k' }) -- Humanoid -> the WalkSpeed we last gave it
local function speedOf(profile)
	local s = profile.Data.Speed
	return (type(s) == 'number' and s == s and s >= 0) and s or 0
end
local function sync(player, profile)
	local speed = speedOf(profile)
	local walk = Treadmills.walkSpeed(speed)
	player:SetAttribute('Speed', speed)
	player:SetAttribute('WalkSpeed', walk)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass('Humanoid')
	if humanoid and applied[humanoid] ~= walk then
		applied[humanoid] = walk
		humanoid.WalkSpeed = walk
	end
end

local function watch(player)
	player:SetAttribute('Treadmill', '')
	local function ready()
		local profile = player:GetAttribute('ProfileReady') and Data.get(player)
		if profile then sync(player, profile) end
	end
	player:GetAttributeChangedSignal('ProfileReady'):Connect(ready)
	player.CharacterAdded:Connect(function(character)
		-- The Humanoid arrives with the character; give it the walk speed as soon as it is there.
		local humanoid = character:FindFirstChildOfClass('Humanoid') or character:WaitForChild('Humanoid', 10)
		if humanoid then ready() end
	end)
	ready()
end
Players.PlayerAdded:Connect(watch)
for _, player in Players:GetPlayers() do task.spawn(watch, player) end

local told = {} -- player -> the locked treadmill they were last told about
Players.PlayerRemoving:Connect(function(player) told[player] = nil end)

local function tick(player)
	local profile = Data.get(player)
	if not profile then return end
	local character = player.Character
	local root = character and character:FindFirstChild('HumanoidRootPart')
	local humanoid = character and character:FindFirstChildOfClass('Humanoid')
	local on = ''
	local id = root and humanoid and humanoid.Health > 0 and treadmillAt(root.Position)
	if id then
		local t = Treadmills.ById[id]
		if Treadmills.unlocked(profile.Data.Rep, id) then
			on = id
			profile.Data.Speed = math.min(1e12, speedOf(profile) + t.Multiplier)
			told[player] = nil
		elseif told[player] ~= id then
			told[player] = id
			Net.get('Notice'):FireClient(player, 'Reach ' .. Format.compact(t.Required) .. ' Power to run on the ' .. t.Name .. ' treadmill')
		end
	else
		told[player] = nil
	end
	local was = player:GetAttribute('Treadmill') or ''
	player:SetAttribute('Treadmill', on)
	sync(player, profile)
	-- A run just ended: send the client a fresh snapshot (attributes already carry the live numbers).
	if was ~= '' and on == '' then Data.push(player) end
end

local rescan = 0
while true do
	task.wait(1)
	if active and #zones == 0 then
		rescan += 1
		if rescan % 15 == 0 then scan() end
	end
	for _, player in Players:GetPlayers() do tick(player) end
end
