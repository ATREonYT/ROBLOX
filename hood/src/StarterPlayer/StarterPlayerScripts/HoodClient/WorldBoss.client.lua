-- (brief 29, P3b) The World Boss on your screen (HoodServer/WorldBossService, Shared/WorldBossRules).
--   The invite (the reference's top-centre panel): WORLD BOSS, its name in gold, a big countdown and a green JOIN, while
--     it is about to land or is up and you aren't on the pier (and not in a stage fight). JOIN puts you on the pier.
--   The lobby's countdown board (tagged HoodWorldBossBoard): its name, NEXT IN m:ss or FIGHT NOW!, a hint.
--   (brief 30) The reference's top line while you wait (Shared/FightUI.bossTimer): "Next <NAME> boss fight in: m:ss" and
--     a blue SKIP (the Robux product WorldBossSkip: the next one lands now, for everyone; "Coming soon!" while its id
--     is 0). It sits in the HUD's TopCentre.BossTimerSlot (FightUI.dock) and hides while the invite is up, while the
--     fight is on, while you're down and while the fight's "N LEFT" / CLEAR! chip has the top centre (PlayerGui's
--     FightChip); PlayerGui's BossTimer attribute says when it shows.
--     The giant's moves are telegraphed in red like a crew's, with no words over it (the reference's grammar).
--   On the pier while it's up: the giant (Shared/EnemyRig, a crew boss grown with Model:ScaleTo) walking, squaring up,
--     winding up its punches and big moves (anticipation, snap, recovery), its moves' RED telegraphs (Shared/BossFX),
--     its HP bar at the top (Shared/FightUI) with your share of the damage; your gun aims at it (Shared/WorldBossView:
--     HoodClient/Waves fires). When it goes down: a burst, and your Cash and rank from the server.
local Players = game:GetService('Players')
local RunService = game:GetService('RunService')
local TweenService = game:GetService('TweenService')
local CollectionService = game:GetService('CollectionService')
local RS = game:GetService('ReplicatedStorage')
local ActiveMap = require(RS.Shared.ActiveMap)
local Net = require(RS.Shared.Net)
local Kit = require(RS.Shared.UIKit)
local Juice = require(RS.Shared.Juice)
local Format = require(RS.Shared.Format)
local EnemyRules = require(RS.Shared.EnemyRules)
local EnemyRig = require(RS.Shared.EnemyRig)
local BossFX = require(RS.Shared.BossFX)
local FightUI = require(RS.Shared.FightUI)
local WB = require(RS.Shared.WorldBossRules)
local View = require(RS.Shared.WorldBossView)
local FightFX = require(RS.Shared.FightFX)
local CharMotion = require(RS.Shared.CharMotion)

local player = Players.LocalPlayer
local active = ActiveMap.wait(20)
if not active then return end
local frame = active.Frame
if not active.Root:FindFirstChild('WorldBossArena', true) then return end
local BLACK = Kit.Color.ink
local S = EnemyRules

---------------------------------------------------------------------------------------------- the invite and the board
local gui, root = Kit.screen('HoodWorldBoss', nil, 5)
local invite = Kit.new('Frame', { Name = 'Invite', AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 132), Size = UDim2.fromOffset(300, 128), BackgroundColor3 = Color3.fromRGB(28, 22, 34), Visible = false, Parent = root })
Kit.corner(UDim.new(0, 12)).Parent = invite
Kit.stroke(BLACK, 3, true).Parent = invite
local head = Kit.new('Frame', { Name = 'Header', Size = UDim2.new(1, 0, 0, 30), BackgroundColor3 = Color3.new(1, 1, 1), Parent = invite })
Kit.corner(UDim.new(0, 12)).Parent = head
Kit.gradient(Color3.fromRGB(216, 72, 40), Color3.fromRGB(232, 120, 56), 0.5).Parent = head
Kit.text({ Name = 'Title', Text = 'WORLD BOSS', TextSize = 22, Stroke = BLACK, StrokeThickness = 2.5, Size = UDim2.fromScale(1, 1), Parent = head })
local nameLabel = Kit.text({ Name = 'BossName', Text = '', TextSize = 20, Stroke = BLACK, StrokeThickness = 2.5, TextColor3 = Color3.fromRGB(248, 232, 112), Position = UDim2.fromOffset(0, 32), Size = UDim2.new(1, 0, 0, 24), Parent = invite })
local clockLabel = Kit.text({ Name = 'Clock', Text = '0:00', TextSize = 40, Stroke = BLACK, StrokeThickness = 3, Position = UDim2.fromOffset(12, 60), Size = UDim2.fromOffset(150, 56), TextXAlignment = Enum.TextXAlignment.Left, Parent = invite })
local join, hit = Kit.button({ Name = 'Join', Text = 'JOIN', Tone = 'green', Width = 116, Height = 52, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -12, 0, 64), Parent = invite })
join.Parent = invite
local joinRemote = Net.get('WorldBossJoin')
local joinAt = 0
local function tryJoin()
	if os.clock() - joinAt < 1.5 then return end
	joinAt = os.clock()
	joinRemote:FireServer()
end
if hit then hit.Activated:Connect(tryJoin) end
gui.Parent = player:WaitForChild('PlayerGui')

local function serverNow()
	local ok, t = pcall(function() return workspace:GetServerTimeNow() end)
	return ok and t or os.clock()
end
local function phase() return RS:GetAttribute('WorldBossPhase') or 'Wait', tonumber(RS:GetAttribute('WorldBossAt')) or 0 end
local function onPier()
	local c = player.Character
	local r = c and c:FindFirstChild('HumanoidRootPart')
	if not r then return false end
	local p = frame:PointToObjectSpace(r.Position)
	local A = WB.Arena
	return math.abs(p.X - A.X) <= A.Half + 4 and math.abs(p.Z - A.Z) <= A.Half + 4
end
local function boards()
	local list = {}
	for _, m in CollectionService:GetTagged('HoodWorldBossBoard') do
		local face = m:FindFirstChild('Board', true)
		local lines = face and face:FindFirstChild('Lines')
		if lines then table.insert(list, lines) end
	end
	return list
end
local function setText(gui2, name, text)
	local l = gui2:FindFirstChild(name, true)
	if l and l:IsA('TextLabel') and l.Text ~= text then l.Text = text end
end

---------------------------------------------------------------------------------------------- the giant on the pier
local folder = Instance.new('Folder')
folder.Name = 'HoodWorldBoss'
folder.Parent = workspace
local bar = FightUI.bossBar(root)
bar.Gui.Position = UDim2.new(0.5, 0, 0, 100)
-- (brief 30) the reference's timer line and its SKIP
local timer = FightUI.bossTimer(root)
FightUI.dock(timer.Gui, 'BossTimerSlot', root) -- (the HUD's slot at the top centre, HudSpec.TopCentre)
local Products = (function()
	local ok, r = pcall(function() return require(RS.Shared.Config.Products) end)
	return ok and type(r) == 'table' and r or nil
end)()
timer.Skip(function()
	local ok = Products and Products.canBuy and Products.canBuy('WorldBossSkip')
	if not ok then
		timer.note('Coming soon!')
		return
	end
	pcall(function() game:GetService('MarketplaceService'):PromptProductPurchase(player, Products.idOf('WorldBossSkip')) end)
end)
local share = Kit.text({ Name = 'Share', Text = '', TextSize = 18, Stroke = BLACK, StrokeThickness = 2, TextColor3 = Color3.fromRGB(69, 230, 255), AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 176), Size = UDim2.fromOffset(300, 22), Visible = false, Parent = root })
local boss = nil -- { Rig, Look, Pos, Srv, State, Since, Walk, Yaw, Atk = { Move, At, Hit, Flight, T }, Punch }
local myDamage = 0
local tele = nil
local function toWorld(p, y) return frame * CFrame.new(p.X, y or 0, p.Z) end
local function drop()
	if boss and boss.Rig then boss.Rig.Model:Destroy() end
	boss = nil
	if tele then tele.finish(false) tele = nil end
end
local function ensure()
	local look = RS:GetAttribute('WorldBossLook')
	if boss and boss.Look == look then return boss end
	drop()
	if not look then return nil end
	local home = Vector3.new(WB.Home[1], 0, WB.Home[2])
	local rig = EnemyRig.build(look, 'Boss', 'Boss', 1, folder, WB.Scale)
	boss = { Rig = rig, Look = look, Pos = home, Srv = home, State = S.Idle, Since = os.clock(), Walk = 0, Yaw = 0, Flinch = 0, FlinchV = 0 }
	return boss
end
local remote = Net.get('WorldBoss')
-- (brief 30) a hit that lands on you: the reference's small white star on your chest, your body snapping back
local function hurtYou()
	local c = player.Character
	local r = c and c:FindFirstChild('HumanoidRootPart')
	if not r then return end
	FightFX.star(r.Position + Vector3.new(0, 0.9, 0) + r.CFrame.LookVector * 0.7, 1.9, 0.1)
	CharMotion.hurt(1.3)
end
remote.OnClientEvent:Connect(function(info)
	if type(info) ~= 'table' then return end
	local now = os.clock()
	if info.Kind == 'Moves' and type(info.D) == 'table' and boss then
		boss.Srv = Vector3.new(info.D[1] or 0, 0, info.D[2] or 0)
		if info.D[3] ~= boss.State then boss.State, boss.Since = info.D[3], now end
	elseif info.Kind == 'Tele' and boss then
		if tele then tele.finish(false) end
		tele = BossFX.telegraph(frame, info, 0.08, folder)
		local T = math.max(0.3, tonumber(info.T) or 1)
		boss.Atk = { Move = info.Move, At = now, Hit = now + T, Flight = tonumber(info.Flight) or 0.6, Info = info }
		-- (brief 30: the reference's telegraph is only the red shape: no words pop over it)
	elseif info.Kind == 'Blast' and boss then
		if tele then tele.finish(info.Landed) tele = nil end
		local a = boss.Atk
		if a then
			a.Hit = math.min(a.Hit, now)
			local at = toWorld(boss.Pos, 0.2).Position
			BossFX.impact(at, (a.Info and a.Info.R) or 12, Color3.fromRGB(255, 200, 90))
		end
		if info.Landed then hurtYou() end
	elseif info.Kind == 'Punch' and boss then
		boss.Punch = now
		if info.Landed then hurtYou() end
	elseif info.Kind == 'Down' then
		if boss and boss.Rig and boss.Rig.Chest then
			local at = boss.Rig.Chest.Position
			for k = 0, 4 do task.delay(k * 0.08, function() Juice.burst(at + Vector3.new(0, k, 0), Color3.fromRGB(255, 210, 26), 3) end) end
			BossFX.impact(toWorld(boss.Pos, 0.2).Position, 18, Color3.fromRGB(255, 210, 26))
		end
		task.delay(0.6, drop)
	elseif info.Kind == 'Gone' then
		drop()
	elseif info.Kind == 'Reward' then
		local cash = tonumber(info.Cash) or 0
		local text = string.format('WORLD BOSS DOWN!  +%s Cash  (#%d of %d, %d%%)', Format.compact(cash), tonumber(info.Rank) or 1, tonumber(info.Of) or 1, math.floor((tonumber(info.Share) or 0) * 100 + 0.5))
		local card = Kit.text({ Name = 'Reward', Text = text, TextSize = 30, Stroke = BLACK, StrokeThickness = 3, TextColor3 = Color3.fromRGB(255, 210, 26), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.34), Size = UDim2.fromOffset(820, 48), Parent = root })
		task.delay(4, function() card:Destroy() end)
	end
end)

-- Gun hook (HoodClient/Waves fires at it): the point to shoot at, in reach; and each shot's share.
function View.aim(from)
	if not boss or not boss.Rig or not boss.Rig.Chest then return nil end
	local at = boss.Rig.Chest.Position
	local flat = Vector3.new(at.X - from.X, 0, at.Z - from.Z)
	if flat.Magnitude > S.FightRange + 12 then return nil end
	return at
end
function View.hit(damage, _)
	myDamage += damage
	if boss then
		boss.FlinchV += 3
		if boss.Rig then Juice.flash(boss.Rig.Model) end
	end
end

local function yawTo(a, b)
	local d = b - a
	return math.atan2(-d.X, -d.Z)
end
local function draw(dt, now, you)
	local b = boss
	if not b or not b.Rig then return end
	local before = b.Pos
	b.Pos = b.Pos:Lerp(b.Srv, Juice.alpha(10, dt))
	local moved = (b.Pos - before).Magnitude
	local scale = b.Rig.Scale or 1
	b.Walk = (b.Walk + moved / (3.6 * scale) * math.pi) % (2 * math.pi)
	local want = you and yawTo(b.Pos, you) or 0
	local dy = (want - b.Yaw + math.pi) % (2 * math.pi) - math.pi
	b.Yaw += dy * Juice.alpha(5, dt)
	b.Flinch, b.FlinchV = Juice.springStep(b.Flinch, b.FlinchV, 0, 3, 0.4, dt)
	local p = { walk = b.Walk, stride = math.clamp(moved / math.max(dt, 1e-3) / (7 * scale), 0, 1), idle = now, flinch = math.clamp(b.Flinch * 0.04, -0.3, 0.4), scale = scale }
	if b.State ~= S.Idle then p.guard = 0.9 end
	if b.State == S.Windup then p.windup = EnemyRig.ready((now - b.Since) / 0.9) end
	if b.Punch then
		local t = now - b.Punch
		if t < EnemyRig.StrikeTime then p.punch, p.windup = EnemyRig.strike(t), 0 else b.Punch = nil end
	end
	local a = b.Atk
	if a then
		local throwing = a.Move == 'Throw' or a.Move == 'Volley' or a.Move == 'Roll'
		local strikeAt = throwing and (a.Hit - a.Flight) or a.Hit
		p.move = a.Move
		if now < strikeAt then
			local k = (now - a.At) / math.max(0.1, strikeAt - a.At)
			p.ready, p.tremble = EnemyRig.ready(k), math.clamp((k - 0.7) * 3.3, 0, 1)
		else
			p.strike = EnemyRig.strike(now - strikeAt)
			p.ready = 0
			if now - strikeAt > EnemyRig.StrikeTime + 0.2 then b.Atk = nil end
		end
	end
	if tele and a then tele.update((now - a.At) / math.max(0.1, a.Hit - a.At)) end
	EnemyRig.pose(b.Rig, toWorld(b.Pos, 0.08) * CFrame.Angles(0, b.Yaw, 0), p)
end

---------------------------------------------------------------------------------------------- every frame / second
local lastSecond = 0
RunService.PreRender:Connect(function(dt)
	local now = os.clock()
	local ph, at = phase()
	local here = onPier()
	local fightOn = ph == 'Fight'
	View.Active = here and fightOn and boss ~= nil
	-- the giant: drawn while it's up and you are near the pier
	if fightOn and here then
		ensure()
		local c = player.Character
		local r = c and c:FindFirstChild('HumanoidRootPart')
		draw(dt, now, r and frame:PointToObjectSpace(r.Position) * Vector3.new(1, 0, 1) or nil)
	elseif boss and not fightOn then
		drop()
	end
	if not fightOn then myDamage = 0 end
	-- the HP bar and your share
	local hp, max = tonumber(RS:GetAttribute('WorldBossHp')) or 0, tonumber(RS:GetAttribute('WorldBossMax')) or 1
	bar.show(fightOn and here)
	share.Visible = fightOn and here
	if fightOn and here then
		bar.set(RS:GetAttribute('WorldBossTitle') or 'WORLD BOSS', hp, max, 1)
		share.Text = myDamage > 0 and ('YOUR DAMAGE ' .. Format.compact(myDamage)) or 'SHOOT IT TOGETHER!'
	end
	-- once a second: the invite and the boards
	if now - lastSecond < 0.25 then return end
	lastSecond = now
	local left = at - serverNow()
	local fighting = (player:GetAttribute('WaveLeft') or 0) > 0
	invite.Visible = (ph == 'Invite' or fightOn) and not here and not fighting
	-- (brief 30) the timer line while you wait (not over the invite, the fight or the revive screen)
	local look = RS:GetAttribute('WorldBossLook')
	-- (and, like the reference's top line, it gives way to the fight's "N LEFT" / CLEAR! chip in the same spot)
	local showTimer = ph == 'Wait' and not here and look ~= nil and player:GetAttribute('Downed') == nil and player.PlayerGui:GetAttribute('FightChip') ~= true
	timer.show(showTimer)
	if showTimer then timer.set(WB.shortName(look), left) end
	if player.PlayerGui:GetAttribute('BossTimer') ~= (showTimer or nil) then player.PlayerGui:SetAttribute('BossTimer', showTimer or nil) end
	nameLabel.Text = tostring(RS:GetAttribute('WorldBossTitle') or '')
	clockLabel.Text = fightOn and 'FIGHT!' or WB.clock(left)
	for _, lines in boards() do
		setText(lines, 'Name', tostring(RS:GetAttribute('WorldBossTitle') or 'WORLD BOSS'))
		setText(lines, 'Time', fightOn and ('FIGHT NOW!  ' .. WB.clock(left)) or ('NEXT IN ' .. WB.clock(left)))
		setText(lines, 'Hint', fightOn and 'Press JOIN at the top to fight it!' or 'Everyone fights it together. Rewards by damage!')
	end
end)
