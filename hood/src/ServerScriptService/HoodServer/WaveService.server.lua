-- Stage goons (brief 18; the rules are Shared/WaveRules and Shared/EnemyRules). Every stage street and the Boss Yard holds
-- a small crew of cartoon goons in front of the next gate. Each player has their own: the server runs them here as plain
-- points (no Humanoids, no physics, EnemyRules.Tick = 10 steps a second, only while they are up and about) and sends
-- their moves to that player alone; Waves.client draws them (Shared/GoonRig), so other players never see your goons.
--   They notice you as you walk in, run at you, wind up and punch. A punch that lands takes EnemyRules.punch off your
--   Humanoid's health (Roblox's own health bar and hurt flash). The punch that would finish you is a KO instead: you're put
--   back at the stage start (just inside its gate), healed, with a short ForceField, and the goons walk home keeping their HP.
--   Your shots: Waves.client asks to shoot one (WaveShot stage, index); the server checks it (you stand in that stage, the
--   goon is up and within reach, the shot rate) and deals your Power as damage (EnemyRules.damage), and pays the x1 shot's
--   Power for the hit (rebirth multiplier, boosts, gun, shoes), like the video's "+6". The last goon down clears the wave
--   and opens the next gate for the rest of the run (brief 23: HoodServer/Runs; StageService and HoodClient/Stages read
--   RunStage); a clear heals you. A stage's first clear EVER pays a little Cash (WaveRules.reward), a later one
--   WaveRules.repeatReward (0 for now: the pads before the gate pay). Cash is x2 with the x2 Cash pass.
--   A cleared wave stays down for the rest of the run. When the run ends (back in the lobby: StageService calls
--   Runs.reset) your session is reset and every crew stands again, fresh.
-- Player attributes: WaveCleared (the highest stage whose wave you ever cleared, saved as profile Waves.Cleared),
-- WaveStage (the stage with goons you stand in, 0 = none), WaveLeft (your goons still up there); Runs sets RunCleared
-- and RunStage.
-- Remote WaveState, to that player only:
--   { Kind = 'Wave', Stage, HP, Max, Left, Enemies = { {Kind, Name, Home = {x, z}} }, D }  entering a stage (fresh or kept)
--   { Kind = 'Moves', Stage, D = {x, z, state, ...} }  10 a second while they move (map frame; EnemyRules state codes)
--   { Kind = 'Hit', Stage, Index, HP, Left, Damage, Gain }  each hit
--   { Kind = 'Punch', Stage, Index, Damage, Landed }  a wind-up ending (Landed: it reached you)
--   { Kind = 'KO', Stage }  your soft respawn;  { Kind = 'Cleared', Stage, Reward, First, Opens (the gate it opened) }
--   { Kind = 'Reset', Stage = 0 }  the run ended: every crew is fresh again
local Players = game:GetService('Players')
local RS = game:GetService('ReplicatedStorage')
local CollectionService = game:GetService('CollectionService')
local Debris = game:GetService('Debris')
local Data = require(script.Parent.DataService)
local Net = require(RS.Shared.Net)
local ActiveMap = require(RS.Shared.ActiveMap)
local StageRules = require(RS.Shared.StageRules)
local WaveRules = require(RS.Shared.WaveRules)
local EnemyRules = require(RS.Shared.EnemyRules)
local ShotRules = require(RS.Shared.ShotRules)
local RebirthRules = require(RS.Shared.RebirthRules)
local Boosts = require(script.Parent.Boosts)
local Runs = require(script.Parent.Runs)

while not RS:GetAttribute('FoundationReady') do task.wait(0.1) end
local active = ActiveMap.get()
if not active then return end
local frame = active.Frame

local models = {}
for _, m in CollectionService:GetTagged('HoodStageGate') do
	if m:IsDescendantOf(active.Root) then table.insert(models, m) end
end
local gates = StageRules.fromModels(models)
-- No gates on this map: no waves (WaveCleared stays unset).
if #gates == 0 then return end
local world, arenas = EnemyRules.world(gates)
local lastStage = gates[#gates].Stage
-- (the run counts a stage without goons as beaten; a map with gates and no goons at all opens every gate)
Runs.setCrews(world, lastStage)
if next(world) == nil then return end
local gateOf = {}
for _, g in gates do gateOf[g.Stage] = g end

local stateRemote = Net.get('WaveState')
local sessions, shoeCarry = {}, {}
local function sessionOf(player)
	local s = sessions[player]
	if not s then
		s = WaveRules.session(world, os.clock, arenas)
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
local function living(player)
	local c = player.Character
	local root = c and c:FindFirstChild('HumanoidRootPart')
	local h = c and c:FindFirstChildOfClass('Humanoid')
	if not root or not h or h.Health <= 0 then return nil end
	return c, root, h
end
local function mapPos(root)
	local p = frame:PointToObjectSpace(root.Position)
	return Vector3.new(p.X, 0, p.Z)
end

-- The wave you just walked into (or that came back), whole, for your client.
local function sendWave(player, stage, w)
	local enemies = {}
	for i, e in world[stage] or {} do enemies[i] = { Kind = e.Kind, Name = e.Name, Home = { e.Home.X, e.Home.Z } } end
	stateRemote:FireClient(player, { Kind = 'Wave', Stage = stage, HP = table.clone(w.HP), Max = table.clone(w.Max), Left = w.Left, Enemies = enemies, D = WaveRules.pack(w) })
end
-- Where you stand now; on entering a stage with goons its wave (fresh or kept) goes to your client, and the run is on.
local function place(player, s, root)
	local before = s.Stage
	s:move(root and WaveRules.stageAt(gates, frame:PointToObjectSpace(root.Position)) or nil)
	local w = s:current()
	if s.Stage ~= 0 then Runs.start(player) end
	if s.Stage ~= before and w then sendWave(player, s.Stage, w) end
end

local function heal(player)
	local _, _, h = living(player)
	if h then h.Health = h.MaxHealth end
end

-- KO: back to the stage start (just inside its gate, facing in), healed, shielded; the goons go home calm.
local function knockout(player, s, stage)
	local c, _, h = living(player)
	local gate = gateOf[stage]
	if not c or not gate then return end
	s:knockout()
	c:PivotTo(frame * CFrame.new(0, 3, gate.Z - 4))
	h.Health = h.MaxHealth
	local shield = Instance.new('ForceField')
	shield.Name = 'KOShield'
	shield.Parent = c
	Debris:AddItem(shield, EnemyRules.Shield)
	stateRemote:FireClient(player, { Kind = 'KO', Stage = stage })
end

-- A wind-up ended: did it land, and what did it do.
local function punch(player, s, ev)
	local c, _, h = living(player)
	local landed = ev.Landed and c ~= nil and ev.Stage == s.Stage and not c:FindFirstChildOfClass('ForceField')
	stateRemote:FireClient(player, { Kind = 'Punch', Stage = ev.Stage, Index = ev.Index, Damage = landed and ev.Damage or 0, Landed = landed })
	if not landed then return end
	if h.Health - ev.Damage <= 0 then
		knockout(player, s, ev.Stage)
	else
		h:TakeDamage(ev.Damage)
	end
end

Net.get('WaveShot').OnServerEvent:Connect(function(player, stage, index)
	local profile = Data.get(player)
	local _, root = living(player)
	if not profile or not root then return end
	-- (only a crew behind a gate this run has opened: someone who slipped past a shut gate, before StageService puts
	-- them back, can't beat a crew further down the street)
	if type(stage) ~= 'number' or stage > Runs.stage(player) then return end
	local s = sessionOf(player)
	place(player, s, root) -- (where you are now, not at the last tick)
	-- Damage is your Power; the hit pays what a shot pays on a x1 lane: your rebirth multiplier and boosts, times your
	-- gun, times your equipped shoes (ShoeService's ShoeMultiplier; their fraction carries to the next hit).
	local damage = EnemyRules.damage(profile.Data.Rep)
	local ok, _, w, _, cleared = s:shoot(stage, index, mapPos(root), damage)
	if not ok then return end
	shoeCarry[player] = shoeCarry[player] or {}
	local perShot = ShotRules.perShot(1, RebirthRules.count(profile.Data.Rebirths), Boosts.power(player))
	local gain = ShotRules.pay(perShot, player:GetAttribute('GunMultiplier'), player:GetAttribute('ShoeMultiplier'), shoeCarry[player])
	profile.Data.Rep = math.min(1e12, profile.Data.Rep + gain)
	player:SetAttribute('Power', profile.Data.Rep)
	stateRemote:FireClient(player, { Kind = 'Hit', Stage = stage, Index = index, HP = w.HP[index], Left = w.Left, Damage = damage, Gain = gain })
	if cleared then
		local first = stage > best(profile)
		if first then profile.Data.Waves.Cleared = math.max(profile.Data.Waves.Cleared, stage) end
		local base = first and WaveRules.reward(stage) or WaveRules.repeatReward(stage)
		local reward = base > 0 and Boosts.cashFor(player, base) or 0
		if reward > 0 then
			profile.Data.Cash = math.min(1e12, profile.Data.Cash + reward)
			player:SetAttribute('Cash', profile.Data.Cash)
			Data.push(player)
		end
		heal(player)
		-- The gate after this stage opens for the rest of the run (Stages.client plays its open moment).
		local opens = Runs.clear(player, stage) and gateOf[stage + 1] and stage + 1 or nil
		stateRemote:FireClient(player, { Kind = 'Cleared', Stage = stage, Reward = reward, First = first, Opens = opens })
	end
	publish(player, profile, s)
end)

-- The run ended (StageService: back in the lobby): every crew stands again, fresh, and your client drops its goons.
Runs.onReset(function(player)
	local s = sessions[player]
	if s then s:reset() end
	stateRemote:FireClient(player, { Kind = 'Reset', Stage = 0 })
	local profile = Data.get(player)
	if profile and s then publish(player, profile, s) end
end)

Players.PlayerRemoving:Connect(function(player)
	sessions[player] = nil
	shoeCarry[player] = nil
end)

-- The goons' clock: 10 steps a second for every player whose goons are up and about; where everyone stands and the
-- attributes 4 times a second.
local since = 0
while true do
	local dt = task.wait(EnemyRules.Tick)
	dt = math.min(dt, 0.5)
	since += dt
	local beat = since >= 0.25
	if beat then since = 0 end
	for _, player in Players:GetPlayers() do
		local profile = Data.get(player)
		if profile then
			local s = sessionOf(player)
			local _, root = living(player)
			if beat then place(player, s, root) end
			local you = root and s.Stage ~= 0 and mapPos(root) or nil
			local events, moved = s:tick(dt, you)
			for _, ev in events do
				if ev.Kind == 'punch' then punch(player, s, ev) end
			end
			for stage in moved do
				local w = s.Waves[stage]
				if w then stateRemote:FireClient(player, { Kind = 'Moves', Stage = stage, D = WaveRules.pack(w) }) end
			end
			if beat then publish(player, profile, s) end
		end
	end
end
