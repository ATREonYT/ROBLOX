-- Stage gates on the active map. A gate opens for you once your Power reaches its number: each client
-- blocks it locally while you're short (HoodClient/Stages), so the walk feels like a real wall. The server
-- records your first clear of each gate, pays its Cash (Config/Balance.StageCash, x2 with the x2 Cash pass), and
-- moves back anyone who slips past a gate they haven't earned. A gate you have passed stays open for good, whatever
-- your Power: a rebirth resets Power, never the map (StageRules).
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
local Balance = require(RS.Shared.Config.Balance)
local Boosts = require(script.Parent.Boosts)

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

-- (A stage the Cash table doesn't know pays the gate's own Reward attribute.)
local function clear(player, profile, gate)
	profile.Data.ClearedWalls[gate.WallId] = true
	local reward = Boosts.cashFor(player, Balance.StageCash[gate.Stage] or gate.Reward)
	profile.Data.Cash = math.min(1e12, profile.Data.Cash + reward)
	Data.push(player)
	stageClear:FireClient(player, { Kind = 'StageClear', Stage = gate.Stage, Reward = reward })
	-- Big clears are news for the whole server: other players' progress keeps the street feeling alive.
	if gate.Stage >= 3 then
		for _, other in Players:GetPlayers() do
			if other ~= player then Net.get('Notice'):FireClient(other, player.DisplayName .. ' cleared Stage ' .. gate.Stage .. '!') end
		end
	end
end

-- Teleport pads: 'Lobby' (past every gate: back to the block) and 'Furthest' (in the lobby: to the pad past
-- your furthest cleared gate). Prompts are tagged HoodTeleport by the map builder.
-- 'Lobby' lands you on the spawn facing the way a fresh spawn does (the map's LobbySpawnYaw).
local spawnYaw = active.Root:GetAttribute('LobbySpawnYaw')
local spawnPoint = frame * CFrame.new((active.Root:GetAttribute('LobbySpawn') or Vector3.new(0, 0, 30)) + Vector3.new(0, 3, 0))
	* CFrame.Angles(0, type(spawnYaw) == 'number' and spawnYaw or 0, 0)
-- Returns true, or false and why ('loading', 'unknown', 'locked').
local function teleport(player, target)
	local character = player.Character
	local root = character and character:FindFirstChild('HumanoidRootPart')
	local profile = Data.get(player)
	if not root or not profile then return false, 'loading' end
	local where, why = StageRules.travelTarget(gates, profile.Data.ClearedWalls, target)
	if not where then
		if why == 'locked' then
			Net.get('Notice'):FireClient(player, 'Clear Stage 1 first: shoot at BAY 1 until you have 10 Power, then walk through the stage door.')
		end
		return false, why
	end
	local cf = spawnPoint
	if where ~= 'Lobby' then cf = frame * CFrame.new(0, 3, where.Z - 12) end
	character:PivotTo(cf)
	return true, nil
end
-- (brief 22) The World window's travel buttons (HoodServer/TravelService) use this same teleport, so the pads and the
-- window share one rule.
do
	local travel = Instance.new('BindableFunction')
	travel.Name = 'StageTravel'
	travel.OnInvoke = function(player, target) return teleport(player, target) end
	travel.Parent = script
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
			local newly, blockedBy = StageRules.check(gates, p, profile.Data.Rep, profile.Data.ClearedWalls, player:GetAttribute('WaveCleared')) -- (WaveService: the targets before each gate)
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
