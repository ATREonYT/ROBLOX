-- (brief 29, P3b) The World Boss (Shared/WorldBossRules): every Interval seconds of server time a giant crew boss lands
-- on the World Boss pier (the map's WorldBossArena, code5/f4_finale) and everyone there fights it together. One boss for
-- the whole server, run here as a plain point (EnemyRules.step, like the stage goons: no Humanoid, no physics), 10 steps
-- a second only while it's up; between fights this sleeps half a second at a time.
--   ReplicatedStorage attributes (every client reads them): WorldBossPhase ('Wait' | 'Invite' | 'Fight'), WorldBossAt
--   (server time the countdown or the fight ends), WorldBossLook, WorldBossTitle, WorldBossHp, WorldBossMax.
--   Player attribute WorldBossFight: you are on the pier while it's up (your gun aims at it; the ranges' free shot rests).
--   Remote WorldBoss, to the players on the pier: { Kind = 'Moves', D = {x, z, state} } (map frame), 'Tele' (its red
--   shape, as WaveState's), 'Blast' { Move, Landed }, 'Punch' { Landed }; to everyone 'Down' / 'Gone'; to each who hit it
--   'Reward' { Cash, Share, Rank, Of }.
--   WorldBossShot (no args): one shot at it, checked (on the pier, in reach, the shot rate); its damage is your Power,
--   and it pays a x1 shot's Power like a goon hit. Your first shot adds your share to its HP (WorldBossRules.join).
--   WorldBossJoin: JOIN on the invite: to the pier's landing spot (while the invite or the fight is on).
--   A hit that would finish you is a soft KO: back to the landing spot, healed, a short ForceField.
local Players = game:GetService('Players')
local RS = game:GetService('ReplicatedStorage')
local Debris = game:GetService('Debris')
local Data = require(script.Parent.DataService)
local Boosts = require(script.Parent.Boosts)
local Net = require(RS.Shared.Net)
local ActiveMap = require(RS.Shared.ActiveMap)
local EnemyRules = require(RS.Shared.EnemyRules)
local ShotRules = require(RS.Shared.ShotRules)
local RebirthRules = require(RS.Shared.RebirthRules)
local WB = require(RS.Shared.WorldBossRules)

while not RS:GetAttribute('FoundationReady') do task.wait(0.1) end
local active = ActiveMap.get()
if not active then return end
local pier = active.Root:FindFirstChild('WorldBossArena', true)
if not pier then return end -- (a map without the pier has no world boss)
local frame = active.Frame
local A = WB.Arena
local arena = { X = A.Half - 3, Z0 = A.Z + A.Half - 3, Z1 = A.Z - A.Half + 3, Blocks = {} }
local landing = pier:FindFirstChild('WorldBossSpawn', true)
local remote = Net.get('WorldBoss')
local S = EnemyRules
-- (server time, so every server's boss lands together; the clock where there is none, offline)
local function serverNow()
	local ok, t = pcall(function() return workspace:GetServerTimeNow() end)
	return ok and t or os.clock()
end

local function setAttr(name, value) if RS:GetAttribute(name) ~= value then RS:SetAttribute(name, value) end end
local function living(player)
	local c = player.Character
	local root = c and c:FindFirstChild('HumanoidRootPart')
	local h = c and c:FindFirstChildOfClass('Humanoid')
	if not root or not h or h.Health <= 0 then return nil end
	return c, root, h
end
local function onPier(root)
	local p = frame:PointToObjectSpace(root.Position)
	return math.abs(p.X - A.X) <= A.Half + 4 and math.abs(p.Z - A.Z) <= A.Half + 4, Vector3.new(p.X, 0, p.Z)
end
-- Everyone alive on the pier: { { Player, Root, Hum, Pos (map frame) } }.
local function present()
	local list = {}
	for _, player in Players:GetPlayers() do
		local c, root, h = living(player)
		if c then
			local inside, pos = onPier(root)
			if inside then table.insert(list, { Player = player, Root = root, Hum = h, Pos = pos }) end
		end
	end
	return list
end
local function toLanding(player)
	local c, _, h = living(player)
	if not c or not landing then return end
	local at = landing.CFrame.Position + Vector3.new(math.random(-3, 3), 3, 0)
	local look = (frame * CFrame.new(WB.Home[1], 3, WB.Home[2])).Position
	c:PivotTo(CFrame.lookAt(at, Vector3.new(look.X, at.Y, look.Z)))
	return h
end

local fight = nil -- { Look, From, G, Hp, Max, Damage = {[player] = n}, Joined = {[player] = true} }
local lastShot, lastJoin = {}, {}
local function start(at)
	local look = WB.lookFor(WB.slotOf(at))
	-- (its look is a crew boss's: WaveService has EnemyModels build every crew's boss already)
	local powers = {}
	for _, e in present() do
		local profile = Data.get(e.Player)
		table.insert(powers, profile and profile.Data.Rep or 0)
	end
	local hp = WB.hpFor(powers)
	fight = { Look = look, From = at, G = S.new('Boss', Vector3.new(WB.Home[1], 0, WB.Home[2]), 0, look), Hp = hp, Max = hp, Damage = {}, Joined = {} }
	fight.G.Moves = WB.movesFor(look) -- (brief 30: a giant has more than a crew's one move)
	for _, e in present() do fight.Joined[e.Player] = true end
	setAttr('WorldBossLook', look)
	setAttr('WorldBossTitle', WB.titleOf(look))
end
local function finish(won)
	local f = fight
	fight = nil
	if not f then return end
	if won then
		local damage, n = {}, 0
		for player, d in f.Damage do
			if player.Parent then damage[player], n = d, n + 1 end
		end
		local rewards, shares = WB.split(damage, WB.pool(n))
		local order = {}
		for player in rewards do table.insert(order, player) end
		table.sort(order, function(a, b) return damage[a] > damage[b] end)
		for rank, player in order do
			local profile = Data.get(player)
			if profile then
				local pay = Boosts.cashFor(player, rewards[player])
				profile.Data.Cash = math.min(1e12, profile.Data.Cash + pay)
				player:SetAttribute('Cash', profile.Data.Cash)
				Data.push(player)
				remote:FireClient(player, { Kind = 'Reward', Cash = pay, Share = shares[player], Rank = rank, Of = #order })
			end
		end
	end
	remote:FireAllClients({ Kind = won and 'Down' or 'Gone' })
end

-- A boss's hit on one player: Damage off their health, or a soft KO back to the landing spot.
local function hurt(e, damage)
	if e.Hum.Parent and e.Hum.Parent:FindFirstChildOfClass('ForceField') then return false end
	damage = math.clamp(damage, 0, S.MaxPunch)
	if e.Hum.Health - damage <= 0 then
		local h = toLanding(e.Player)
		if h then h.Health = h.MaxHealth end
		local shield = Instance.new('ForceField')
		shield.Name = 'KOShield'
		shield.Parent = e.Player.Character
		Debris:AddItem(shield, S.Shield)
	else
		e.Hum:TakeDamage(damage)
	end
	return true
end
local function xz(v) return { math.floor(v.X * 100 + 0.5) / 100, math.floor(v.Z * 100 + 0.5) / 100 } end
local function toPier(list, msg)
	for _, e in list do remote:FireClient(e.Player, msg) end
end

Net.get('WorldBossShot').OnServerEvent:Connect(function(player)
	local f = fight
	if not f then return end
	local now = os.clock()
	if now - (lastShot[player] or 0) < ShotRules.Cooldown * 0.7 then return end
	local profile = Data.get(player)
	local _, root = living(player)
	if not profile or not root then return end
	local inside, pos = onPier(root)
	if not inside or (pos - f.G.Pos).Magnitude > S.FightRange + S.Slack + 12 then return end
	lastShot[player] = now
	if not f.Joined[player] then
		f.Joined[player] = true
		f.Hp, f.Max = WB.join(f.Hp, f.Max, profile.Data.Rep)
	end
	local damage = math.min(S.damage(profile.Data.Rep), f.Hp)
	f.Hp -= damage
	f.Damage[player] = (f.Damage[player] or 0) + damage
	-- (a hit pays like a goon hit: a x1 shot's Power)
	local perShot = ShotRules.perShot(1, RebirthRules.count(profile.Data.Rebirths), Boosts.power(player))
	local gain = ShotRules.pay(perShot, player:GetAttribute('GunMultiplier'), player:GetAttribute('ShoeMultiplier'), {})
	profile.Data.Rep = math.min(1e15, profile.Data.Rep + gain)
	player:SetAttribute('Power', profile.Data.Rep)
	if f.G.State == S.Idle then S.alert(f.G, 0) end
	if f.Hp <= 0 then finish(true) end
end)

Net.get('WorldBossJoin').OnServerEvent:Connect(function(player)
	local phase = RS:GetAttribute('WorldBossPhase')
	if phase ~= 'Invite' and phase ~= 'Fight' then return end
	if os.clock() - (lastJoin[player] or 0) < 2 then return end
	lastJoin[player] = os.clock()
	toLanding(player)
end)

Players.PlayerRemoving:Connect(function(player)
	lastShot[player], lastJoin[player] = nil, nil
	if fight then fight.Damage[player], fight.Joined[player] = nil, nil end
end)

local due = WB.nextAt(serverNow() + 1)
-- (brief 30) The SKIP product (StoreReceipts -> StoreService -> this): the next landing moves up to SkipLead seconds from
-- now, or right after the fight that's on. Everyone in the server gets it.
do
	local fn = Instance.new('BindableFunction')
	fn.Name = 'SkipGrant'
	fn.OnInvoke = function(player)
		local now = serverNow()
		if fight then
			due = math.max(fight.From + WB.FightTime + 1, math.min(due, fight.From + WB.FightTime + WB.SkipLead))
		else
			due = math.min(due, now + WB.SkipLead)
		end
		for _, p in Players:GetPlayers() do
			Net.get('Notice'):FireClient(p, (player and player.DisplayName or 'Someone') .. ' skipped the wait: the World Boss is coming!')
		end
		return true
	end
	fn.Parent = script
end
local beat, lastSent = 0, nil
local lastTickError -- (the loop carries on after an error; the same error is reported once, not every tick)
while true do
	local ok, err = pcall(function()
		local dt = math.min(task.wait(fight and WB.Tick or 0.5), 0.5)
		local now = serverNow()
		if not fight and now >= due then
			start(due)
			due = WB.nextAt(due + 1) -- (the next landing: one a slot, however this one ends)
		end
		local f = fight
		if f and now >= f.From + WB.FightTime then
			finish(false)
			f = nil
		end
		if not f and now >= due then due = WB.nextAt(now + 1) end
		local list = f and present() or nil
		if f then
			-- the nearest player on the pier is the one it goes for; its big moves hit everyone inside them
			local g = f.G
			local best, target = math.huge, nil
			for _, e in list do
				local d = (e.Pos - g.Pos).Magnitude
				if d < best then best, target = d, e end
			end
			if g.State == S.Idle and target then S.alert(g, 0) end
			local ev, landed = S.step(g, dt, target and target.Pos or nil, os.clock(), nil, arena, nil)
			if ev == 'tele' and g.Atk then
				WB.grow(g.Atk)
				local a = g.Atk
				local points = {}
				for k, p in a.P or {} do points[k] = xz(p) end
				toPier(list, { Kind = 'Tele', Move = a.Move, Shape = a.Shape, O = xz(a.O), D = xz(a.D), L = a.L, W = a.W, R = a.R, A = a.A, Ri = a.Ri, P = points, T = a.Tele, Flight = a.Flight, Jump = a.Jump })
			elseif ev == 'blast' and g.Atk then
				for _, e in list do
					local hit = S.inAttack(g.Atk, e.Pos) and hurt(e, g.Atk.Damage)
					remote:FireClient(e.Player, { Kind = 'Blast', Move = g.Atk.Move, Landed = hit == true })
				end
			elseif ev == 'punch' then
				local hit = landed and target and hurt(target, S.punch('Boss') * 1.5)
				toPier(list, { Kind = 'Punch', Landed = hit == true })
			end
			local d = { math.floor(g.Pos.X * 100 + 0.5) / 100, math.floor(g.Pos.Z * 100 + 0.5) / 100, g.State }
			local key = table.concat(d, ',')
			if key ~= lastSent then
				lastSent = key
				toPier(list, { Kind = 'Moves', D = d })
			end
		end
		beat += dt
		if beat >= 0.25 then
			beat = 0
			if fight then
				setAttr('WorldBossPhase', 'Fight')
				setAttr('WorldBossAt', math.floor(fight.From + WB.FightTime))
				setAttr('WorldBossHp', math.max(0, fight.Hp))
				setAttr('WorldBossMax', fight.Max)
			else
				setAttr('WorldBossPhase', due - now <= WB.Warn and 'Invite' or 'Wait')
				setAttr('WorldBossAt', due)
				setAttr('WorldBossLook', WB.lookFor(WB.slotOf(due)))
				setAttr('WorldBossTitle', WB.titleOf(WB.lookFor(WB.slotOf(due))))
			end
			local on = {}
			for _, e in (fight and (list or present())) or {} do on[e.Player] = true end
			for _, player in Players:GetPlayers() do
				local want = on[player] == true
				if player:GetAttribute('WorldBossFight') ~= want then player:SetAttribute('WorldBossFight', want) end
			end
		end
	end)
	if not ok and err ~= lastTickError then warn('[WorldBossService] tick failed, carrying on: ' .. tostring(err)) end
	lastTickError = if ok then nil else err
end
