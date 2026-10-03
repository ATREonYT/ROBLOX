-- Stage gates on the active map. A gate opens for you once your Power reaches its number: each client
-- blocks it locally while you're short (HoodClient/Stages), so the walk feels like a real wall. The server
-- records your first clear of each gate, pays its Cash reward, and moves back anyone who slips past a
-- gate they haven't earned.
--
-- Gate contract (built by map builders): a Model tagged 'HoodStageGate' with attributes
--   Stage, WallId, Required, Reward, LineZ (gate plane, map frame; stages run toward -Z), HalfWidth.
local Players = game:GetService('Players')
local RS = game:GetService('ReplicatedStorage')
local CollectionService = game:GetService('CollectionService')
local Data = require(script.Parent.DataService)
local Net = require(RS.Shared.Net)
local ActiveMap = require(RS.Shared.ActiveMap)
local Format = require(RS.Shared.Format)
local StageRules = require(RS.Shared.StageRules)

while not RS:GetAttribute('FoundationReady') do task.wait(0.1) end
local active = ActiveMap.get()
if not active then return end

local models = {}
for _, model in CollectionService:GetTagged('HoodStageGate') do
	if model:IsDescendantOf(active.Root) then table.insert(models, model) end
end
local gates = StageRules.fromModels(models)
if #gates == 0 then return end
local frame = active.Frame
local stageClear = Net.get('Cinematic')

local function clear(player, profile, gate)
	profile.Data.ClearedWalls[gate.WallId] = true
	profile.Data.Cash = math.min(1e12, profile.Data.Cash + gate.Reward)
	Data.push(player)
	stageClear:FireClient(player, { Kind = 'StageClear', Stage = gate.Stage, Reward = gate.Reward })
	-- Big clears are news for the whole server: other players' progress keeps the street feeling alive.
	if gate.Stage >= 3 then
		for _, other in Players:GetPlayers() do
			if other ~= player then Net.get('Notice'):FireClient(other, player.DisplayName .. ' cleared Stage ' .. gate.Stage .. '!') end
		end
	end
end

-- Teleport pads: 'Lobby' (past every gate: back to the block) and 'Furthest' (in the lobby: to the pad past
-- your furthest cleared gate). Prompts are tagged HoodTeleport by the map builder.
local spawnPoint = frame * CFrame.new((active.Root:GetAttribute('LobbySpawn') or Vector3.new(0, 0, 30)) + Vector3.new(0, 3, 0))
local function teleport(player, target)
	local character = player.Character
	local root = character and character:FindFirstChild('HumanoidRootPart')
	local profile = Data.get(player)
	if not root or not profile then return end
	local cf = spawnPoint
	if target == 'Furthest' then
		local best
		for _, gate in gates do if profile.Data.ClearedWalls[gate.WallId] then best = gate end end
		if not best then
			Net.get('Notice'):FireClient(player, 'Clear Stage 1 first: train on the Tire Bag, then walk through the green gate.')
			return
		end
		cf = frame * CFrame.new(0, 3, best.Z - 12)
	end
	character:PivotTo(cf * CFrame.Angles(0, 0, 0))
end
local teleportLimit = {}
local function hookPrompt(prompt)
	if not prompt:IsA('ProximityPrompt') or not prompt:IsDescendantOf(active.Root) then return end
	prompt.Triggered:Connect(function(player)
		if os.clock() - (teleportLimit[player] or 0) < 1 then return end
		teleportLimit[player] = os.clock()
		teleport(player, prompt:GetAttribute('Target'))
	end)
end
for _, prompt in CollectionService:GetTagged('HoodTeleport') do hookPrompt(prompt) end
CollectionService:GetInstanceAddedSignal('HoodTeleport'):Connect(hookPrompt)
Players.PlayerRemoving:Connect(function(player) teleportLimit[player] = nil end)

local function stageStat(player, n)
	local stats = player:FindFirstChild('leaderstats')
	if not stats then return end
	local v = stats:FindFirstChild('Stage')
	if not v then
		v = Instance.new('IntValue')
		v.Name = 'Stage'
		v.Parent = stats
	end
	v.Value = n
end

while task.wait(0.25) do
	for _, player in Players:GetPlayers() do
		local profile = Data.get(player)
		local character = player.Character
		local root = character and character:FindFirstChild('HumanoidRootPart')
		if profile and root then
			local p = frame:PointToObjectSpace(root.Position)
			local newly, blockedBy = StageRules.check(gates, p, profile.Data.Rep, profile.Data.ClearedWalls)
			for _, gate in newly do clear(player, profile, gate) end
			if blockedBy then
				-- Slipped through a gate this player can't open yet: put them back in front of it.
				local back = (frame * CFrame.new(p.X, p.Y, blockedBy.Z + 5)).Position
				character:PivotTo(CFrame.new(back) * (root.CFrame - root.Position))
			end
			local cleared = StageRules.count(gates, profile.Data.ClearedWalls)
			player:SetAttribute('StagesCleared', cleared)
			stageStat(player, cleared)
			player:SetAttribute('Cash', profile.Data.Cash)
		end
	end
end
