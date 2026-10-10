-- Stage gates, runs and the pads before every gate (brief 23: the reference's loop).
--   Runs: every trip out of the lobby is a run (HoodServer/Runs). A gate opens for you when you beat the crew of the
--     stage before it (WaveService), every run; gate 1 (lobby -> Stage 1) is always open. Power opens nothing: a gate's
--     Required is the "Recommended Power" on its sign. Each client blocks a shut gate locally (HoodClient/Stages), so the
--     walk feels like a real wall; this server puts anyone standing past a gate they haven't opened this run back in
--     front of it (at any depth).
--   The run ends (every gate shuts again, your goons come back: Runs.reset) when you go back to the lobby: a pad, the
--     World window's trips (Lobby, Stage 1), a respawn (you land in the lobby), walking back in. A goon KO does not end it
--     (WaveService puts you back at that stage's start). Leaving the game ends it too (nothing is saved).
--   The pads (parts tagged HoodStagePad, attributes Stage = the crew stage they pay for and Kind): two on the sidewalks
--     before every gate n >= 2 (paying for stage n - 1) and a pair at the far end of the boss yard (stage 16). Step on
--     one (its Touched, and a position check every POLL seconds as a backstop; your root over the pad, alive) once that
--     stage's crew is down this run:
--       Return (yellow): + PadRules.reward(stage, false) Cash, and you go to the lobby spawn: the run ends.
--       TenX (magenta): with the 10x Cash pass (Pass_TenXCash), + PadRules.reward(stage, true) and the same trip. Without
--         it the pass's purchase prompt (Products.canBuy), or "coming soon" while its id is 0, or in a new player's first
--         minutes (OnboardingQuiet) only "get it in the Store": no pay, no trip.
--     Both go through Boosts.cashFor (the x2 Cash pass, VIP) like every Cash reward, and pay once a run (Runs.claim).
--     One action a stay on a pad: step off and on again for another (a fresh pass purchase acts at once).
--   Your first pass of a gate ever is saved (ClearedWalls: StagesCleared and the leaderboard's Stage); it pays nothing
--     now (ECON: the pads pay). Big ones are news for the server.
-- Gate contract (built by map builders): a Model tagged 'HoodStageGate' with attributes
--   Stage, WallId, Required, Reward, LineZ (gate plane, map frame; stages run toward -Z), HalfWidth.
-- Player attributes: RunCleared, RunStage (Runs), StagesCleared, CashOuts (pad cash-outs this session), BestCashOut (the
-- furthest stage cashed out at this session), Cash.
-- Remote Cinematic, to that player: { Kind = 'CashOut', Stage, Reward, TenX } once a pad has paid (you are in the lobby).
local Players = game:GetService('Players')
local RS = game:GetService('ReplicatedStorage')
local CollectionService = game:GetService('CollectionService')
local MarketplaceService = game:GetService('MarketplaceService')
local Data = require(script.Parent.DataService)
local Net = require(RS.Shared.Net)
local ActiveMap = require(RS.Shared.ActiveMap)
local StageRules = require(RS.Shared.StageRules)
local Products = require(RS.Shared.Config.Products)
local Boosts = require(script.Parent.Boosts)
local Runs = require(script.Parent.Runs)

while not RS:GetAttribute('FoundationReady') do task.wait(0.1) end
local active = ActiveMap.get()
if not active then return end

local models = {}
for _, model in CollectionService:GetTagged('HoodStageGate') do
	if model:IsDescendantOf(active.Root) then table.insert(models, model) end
end
local gates = StageRules.fromModels(models)
if #gates == 0 then return end
Runs.LastGate = gates[#gates].Stage
local frame = active.Frame
local cinematic = Net.get('Cinematic')
local function notice(player, text) Net.get('Notice'):FireClient(player, text) end

-- ECON's pad Cash (Shared/PadRules), with a stand-in until it is there: 10 x 2^(stage - 1), x10 for the magenta pad.
local PadRules
do
	local m = RS.Shared:FindFirstChild('PadRules')
	local ok, result = pcall(function() return m and require(m) end)
	if ok and type(result) == 'table' then PadRules = result end
end
local TENX = PadRules and type(PadRules.Pass) == 'string' and PadRules.Pass or 'TenXCash'
local function padReward(stage, tenX)
	if PadRules and type(PadRules.reward) == 'function' then
		local ok, v = pcall(PadRules.reward, stage, tenX)
		if ok and type(v) == 'number' and v == v and v >= 0 and v < math.huge then return math.floor(v) end
	end
	local s = math.clamp(math.floor(tonumber(stage) or 1), 1, 16)
	return 10 * 2 ^ (s - 1) * (tenX and 10 or 1)
end
local function ownsTenX(player) return player:GetAttribute('Pass_' .. TENX) == true end

---------------------------------------------------------------------------------------------- trips
-- 'Lobby' lands you on the spawn facing the way a fresh spawn does (the map's LobbySpawnYaw); 'Stage1' just inside the
-- Stage 1 gate. Both end the run you are on first.
local spawnYaw = active.Root:GetAttribute('LobbySpawnYaw')
local spawnPoint = frame * CFrame.new((active.Root:GetAttribute('LobbySpawn') or Vector3.new(0, 0, 30)) + Vector3.new(0, 3, 0))
	* CFrame.Angles(0, type(spawnYaw) == 'number' and spawnYaw or 0, 0)
-- Returns true, or false and why ('loading', 'unknown', 'locked').
local function teleport(player, target, why)
	local character = player.Character
	local root = character and character:FindFirstChild('HumanoidRootPart')
	if not root or not Data.get(player) then return false, 'loading' end
	local where, err = StageRules.travelTarget(gates, target)
	if not where then return false, err end
	Runs.reset(player, why or 'trip')
	local cf = spawnPoint
	if where ~= 'Lobby' then cf = frame * CFrame.new(0, 3, where.Z - StageRules.TripLand) end
	character:PivotTo(cf)
	return true, nil
end
-- (brief 22) The World window's travel buttons (HoodServer/TravelService) use this same teleport.
do
	local travel = Instance.new('BindableFunction')
	travel.Name = 'StageTravel'
	travel.OnInvoke = function(player, target) return teleport(player, target, 'trip') end
	travel.Parent = script
end
-- Older maps' teleport prompts (tagged HoodTeleport): a Lobby / Stage1 one still works; the retired furthest-stage trip
-- ('Furthest') is switched off so it never offers a trip that goes nowhere.
local promptLimit = {}
local function hookPrompt(prompt)
	if not prompt:IsA('ProximityPrompt') or not prompt:IsDescendantOf(active.Root) then return end
	if not StageRules.travelTarget(gates, prompt:GetAttribute('Target')) then
		prompt.Enabled = false
		return
	end
	prompt.Triggered:Connect(function(player)
		if os.clock() - (promptLimit[player] or 0) < 1 then return end
		promptLimit[player] = os.clock()
		teleport(player, prompt:GetAttribute('Target'), 'trip')
	end)
end
for _, prompt in CollectionService:GetTagged('HoodTeleport') do hookPrompt(prompt) end
CollectionService:GetInstanceAddedSignal('HoodTeleport'):Connect(hookPrompt)

---------------------------------------------------------------------------------------------- pads
local POLL = 0.25
local PAD_EDGE, PAD_LOW, PAD_HIGH = 1.5, -1, 9 -- your root may be this far past the pad's edge, below and above its top
local pads = {} -- [part] = { Part, Stage, Kind }
local stay = {} -- [player] = { Part (the pad you stand on), Asked (the pass prompt went out this stay) }
local said, asked = {}, {} -- [player] = os.clock() of the last "beat the crew" notice / pass prompt
local cashOuts = {} -- [player] = pad cash-outs this session

local function over(part, position)
	local p = part.CFrame:PointToObjectSpace(position)
	local s = part.Size
	return math.abs(p.X) <= s.X / 2 + PAD_EDGE and math.abs(p.Z) <= s.Z / 2 + PAD_EDGE and p.Y >= s.Y / 2 + PAD_LOW and p.Y <= s.Y / 2 + PAD_HIGH
end
local function living(player)
	local c = player.Character
	local root = c and c:FindFirstChild('HumanoidRootPart')
	local h = c and c:FindFirstChildOfClass('Humanoid')
	if not root or not h or h.Health <= 0 then return nil end
	return c, root
end

local function promptPass(player)
	if os.clock() - (asked[player] or -math.huge) < 4 then return end
	asked[player] = os.clock()
	local entry = Products.ByKey and Products.ByKey[TENX]
	-- (HOOK: no purchase prompt in a new player's first minutes, OnboardingService's OnboardingQuiet)
	if player:GetAttribute('OnboardingQuiet') == true then
		notice(player, (entry and entry.Title or '10x Cash') .. ': get it in the Store')
		return
	end
	if Products.canBuy(TENX) then
		local ok = pcall(function() MarketplaceService:PromptGamePassPurchase(player, Products.idOf(TENX)) end)
		if ok then return end
	end
	notice(player, (entry and entry.Title or '10x Cash') .. ' is coming soon!')
end

local function cashOut(player, pad)
	local profile = Data.get(player)
	if not profile or not Runs.claim(player, pad.Stage) then return end
	local tenX = pad.Kind == 'TenX'
	local reward = Boosts.cashFor(player, padReward(pad.Stage, tenX))
	profile.Data.Cash = math.min(1e12, profile.Data.Cash + reward)
	player:SetAttribute('Cash', profile.Data.Cash)
	cashOuts[player] = (cashOuts[player] or 0) + 1
	player:SetAttribute('BestCashOut', math.max(tonumber(player:GetAttribute('BestCashOut')) or 0, pad.Stage))
	player:SetAttribute('CashOuts', cashOuts[player])
	Data.push(player)
	teleport(player, 'Lobby', 'pad')
	stay[player] = nil
	cinematic:FireClient(player, { Kind = 'CashOut', Stage = pad.Stage, Reward = reward, TenX = tenX })
end

-- You are on a pad (its Touched or the poll). One action a stay.
local function onPad(player, pad)
	local st = stay[player]
	if st and st.Part == pad.Part and not (st.Asked and ownsTenX(player)) then return end
	local _, root = living(player)
	if not root or not over(pad.Part, root.Position) or not Data.get(player) then return end
	stay[player] = { Part = pad.Part }
	if not StageRules.padReady(pad.Stage, Runs.cleared(player)) then
		if os.clock() - (said[player] or -math.huge) > 3 then
			said[player] = os.clock()
			notice(player, 'Beat this street\'s crew first!')
		end
		return
	end
	if pad.Kind == 'TenX' and not ownsTenX(player) then
		stay[player].Asked = true
		promptPass(player)
		return
	end
	cashOut(player, pad)
end

local function trackPad(part)
	if pads[part] or not part:IsA('BasePart') or not part:IsDescendantOf(active.Root) then return end
	local stage, kind = part:GetAttribute('Stage'), part:GetAttribute('Kind')
	if type(stage) ~= 'number' or (kind ~= 'Return' and kind ~= 'TenX') then return end
	local pad = { Part = part, Stage = stage, Kind = kind }
	pads[part] = pad
	part.Touched:Connect(function(hit)
		local character = hit and hit.Parent
		local player = character and Players:GetPlayerFromCharacter(character)
		if player then onPad(player, pad) end
	end)
end
for _, part in CollectionService:GetTagged('HoodStagePad') do trackPad(part) end
CollectionService:GetInstanceAddedSignal('HoodStagePad'):Connect(trackPad)

-- The poll's half: the pad you stand on (nil when none), so a stay ends when you step off.
local function padCheck(player, root)
	for part, pad in pads do
		if part.Parent and over(part, root.Position) then
			onPad(player, pad)
			return
		end
	end
	stay[player] = nil
end

---------------------------------------------------------------------------------------------- players
local function joined(player)
	Runs.publish(player)
	player.CharacterAdded:Connect(function()
		-- (a respawn lands you in the lobby: that run is over)
		Runs.reset(player, 'respawn')
		stay[player] = nil
	end)
end
Players.PlayerAdded:Connect(joined)
for _, player in Players:GetPlayers() do task.spawn(joined, player) end
Players.PlayerRemoving:Connect(function(player)
	promptLimit[player], stay[player], said[player], asked[player], cashOuts[player] = nil, nil, nil, nil, nil
	Runs.forget(player)
end)

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

-- Your first pass of a gate ever: saved; big ones are news for the whole server (other players' progress keeps the
-- street feeling alive).
local function reached(player, profile, gate)
	profile.Data.ClearedWalls[gate.WallId] = true
	Data.push(player)
	if gate.Stage >= 3 then
		for _, other in Players:GetPlayers() do
			if other ~= player then notice(other, player.DisplayName .. ' reached Stage ' .. gate.Stage .. '!') end
		end
	end
end

while task.wait(POLL) do
	for _, player in Players:GetPlayers() do
		local profile = Data.get(player)
		local character, root = living(player)
		if profile and root then
			local p = frame:PointToObjectSpace(root.Position)
			if StageRules.inLobby(gates, p) then
				Runs.reset(player, 'lobby')
				stay[player] = nil
			else
				local newly, blockedBy = StageRules.check(gates, p, Runs.stage(player), profile.Data.ClearedWalls)
				for _, gate in newly do reached(player, profile, gate) end
				if blockedBy then
					-- Past a gate you haven't opened this run: back in front of it, on the road (clear of the end buildings).
					local back = (frame * CFrame.new(math.clamp(p.X, -8, 8), 3, blockedBy.Z + 5)).Position
					character:PivotTo(CFrame.new(back) * (root.CFrame - root.Position))
				end
				padCheck(player, root)
			end
			Runs.publish(player)
			local cleared = StageRules.count(gates, profile.Data.ClearedWalls)
			player:SetAttribute('StagesCleared', cleared)
			stageStat(player, cleared)
			player:SetAttribute('Cash', profile.Data.Cash)
			if player:GetAttribute('CashOuts') == nil then player:SetAttribute('CashOuts', cashOuts[player] or 0) end
		end
	end
end
