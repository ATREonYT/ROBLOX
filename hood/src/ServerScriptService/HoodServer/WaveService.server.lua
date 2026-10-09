-- Stage target waves (the soldier game's guard waves, the hood way: cartoon targets only; the rules are WaveRules).
-- Every stage street holds a few targets (map: TheBlockV2 Waves.build, Models tagged HoodWaveTarget with attributes
-- Stage, Index, Kind and Aim). Each player has their own wave per stage, kept here: Waves.client asks to shoot one
-- (WaveShot stage, index) and the server checks the shot (you stand in that stage, the target is up and within
-- WaveRules.Range, the ranges' shot rate), deals the shot's pay as damage and pays it as Power (a x1 lane: your
-- rebirth multiplier, gun, shoes and boosts). The last target down clears the wave: a stage's first clear pays Cash
-- (Balance.WaveCash) and opens the next gate (StageService and HoodClient/Stages read WaveCleared). A cleared wave comes
-- back WaveRules.RespawnDelay seconds after the clear (while you stay, or on your next visit), and every later clear pays
-- a little Cash (WaveRules.repeatReward: World 1's repeatable Cash). Cash is x2 with the x2 Cash pass.
-- Player attributes: WaveCleared (the highest stage whose wave you ever cleared, saved as profile Waves.Cleared),
-- WaveStage (the stage with targets you stand in, 0 = none), WaveLeft (your targets still up there).
-- Remote WaveState, to that player only: { Kind = 'Wave', Stage, HP, Max, Left } when you enter a stage (a fresh or
-- a kept wave), { Kind = 'Hit', Stage, Index, HP, Left, Damage } per hit, { Kind = 'Cleared', Stage, Reward, First }.
local Players = game:GetService('Players')
local RS = game:GetService('ReplicatedStorage')
local CollectionService = game:GetService('CollectionService')
local Data = require(script.Parent.DataService)
local Net = require(RS.Shared.Net)
local ActiveMap = require(RS.Shared.ActiveMap)
local StageRules = require(RS.Shared.StageRules)
local WaveRules = require(RS.Shared.WaveRules)
local ShotRules = require(RS.Shared.ShotRules)
local RebirthRules = require(RS.Shared.RebirthRules)
local Boosts = require(script.Parent.Boosts)

while not RS:GetAttribute('FoundationReady') do task.wait(0.1) end
local active = ActiveMap.get()
if not active then return end
local frame = active.Frame

local function tagged(tag)
	local list = {}
	for _, m in CollectionService:GetTagged(tag) do
		if m:IsDescendantOf(active.Root) then table.insert(list, m) end
	end
	return list
end
local gates = StageRules.fromModels(tagged('HoodStageGate'))
local world, bad = WaveRules.worldFrom(tagged('HoodWaveTarget'))
if #bad > 0 then warn('[WaveService] Skipped targets with bad attributes: ' .. table.concat(bad, ', ')) end
-- No gates or no targets on this map: no waves (WaveCleared stays unset, so gates ask for Power only).
if #gates == 0 or next(world) == nil then return end
local lastStage = gates[#gates].Stage

local stateRemote = Net.get('WaveState')
local sessions = {}
local shoeCarry = {}
local function sessionOf(player)
	local s = sessions[player]
	if not s then
		s = WaveRules.session(world, os.clock)
		sessions[player] = s
	end
	return s
end
local function best(profile) return WaveRules.effective(profile.Data.Waves.Cleared, world, lastStage) end
local function set(player, name, value)
	if player:GetAttribute(name) ~= value then player:SetAttribute(name, value) end
end
local function publish(player, profile, s)
	set(player, 'WaveCleared', best(profile))
	set(player, 'WaveStage', s.Stage)
	local w = s:current()
	set(player, 'WaveLeft', w and w.Left or 0)
end
-- Where you stand now; on entering a stage with targets its wave (fresh or kept) goes to your client, and so does a
-- cleared wave coming back while you stay.
local function place(player, s, root)
	local before = s.Stage
	s:move(WaveRules.stageAt(gates, frame:PointToObjectSpace(root.Position)))
	local back = s.Stage == before and s:revive()
	local w = s:current()
	if (s.Stage ~= before or back) and w then
		stateRemote:FireClient(player, { Kind = 'Wave', Stage = s.Stage, HP = table.clone(w.HP), Max = table.clone(w.Max), Left = w.Left })
	end
end

Net.get('WaveShot').OnServerEvent:Connect(function(player, stage, index)
	local profile = Data.get(player)
	local c = player.Character
	local root = c and c:FindFirstChild('HumanoidRootPart')
	local h = c and c:FindFirstChildOfClass('Humanoid')
	if not profile or not root or not h or h.Health <= 0 then return end
	local s = sessionOf(player)
	place(player, s, root) -- (where you are now, not at the last tick)
	-- A hit is worth what a shot pays on a x1 lane: your rebirth multiplier and boosts, times your gun, times your
	-- equipped shoes (ShoeService's ShoeMultiplier; their fraction carries to the next hit).
	shoeCarry[player] = shoeCarry[player] or {}
	local perShot = ShotRules.perShot(1, RebirthRules.count(profile.Data.Rebirths), Boosts.power(player))
	local damage = ShotRules.pay(perShot, player:GetAttribute('GunMultiplier'), player:GetAttribute('ShoeMultiplier'), shoeCarry[player])
	local ok, _, w, _, cleared = s:shoot(stage, index, root.Position, damage)
	if not ok then return end
	profile.Data.Rep = math.min(1e12, profile.Data.Rep + damage)
	player:SetAttribute('Power', profile.Data.Rep)
	stateRemote:FireClient(player, { Kind = 'Hit', Stage = stage, Index = index, HP = w.HP[index], Left = w.Left, Damage = damage })
	if cleared then
		local first = stage > best(profile)
		if first then profile.Data.Waves.Cleared = math.max(profile.Data.Waves.Cleared, stage) end
		local reward = Boosts.cashFor(player, first and WaveRules.reward(stage) or WaveRules.repeatReward(stage))
		profile.Data.Cash = math.min(1e12, profile.Data.Cash + reward)
		player:SetAttribute('Cash', profile.Data.Cash)
		Data.push(player)
		stateRemote:FireClient(player, { Kind = 'Cleared', Stage = stage, Reward = reward, First = first })
	end
	publish(player, profile, s)
end)

Players.PlayerRemoving:Connect(function(player)
	sessions[player] = nil
	shoeCarry[player] = nil
end)

while task.wait(0.25) do
	for _, player in Players:GetPlayers() do
		local profile = Data.get(player)
		local c = player.Character
		local root = c and c:FindFirstChild('HumanoidRootPart')
		if profile then
			local s = sessionOf(player)
			if root then place(player, s, root) end
			publish(player, profile, s)
		end
	end
end
