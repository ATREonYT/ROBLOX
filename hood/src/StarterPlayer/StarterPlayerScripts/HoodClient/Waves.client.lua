-- The stage goons on your screen (brief 18). The server decides everything (WaveService, Shared/WaveRules and
-- Shared/EnemyRules); this draws it and aims.
--   Goons: the user's HoodEnemies avatars (Shared/EnemyRig; today's goon, Shared/GoonRig, stands in until a look is
--     built), on your machine only: other players never see your goons, you never see theirs. Each stage's crew waits in a
--     loose group in front of the next gate (you can see them from the gate before); once you come near, the server's
--     moves (WaveState 'Moves', 10 a second) drive them, smoothed.
--   (brief 30) The reference's fight grammar (bible 0.6, 2.3-2.6), copied:
--     * the wave idles at the next gate and charges you at about 25 studs, running with its arms forward;
--     * every hit pops a "+N" with the bicep by YOUR body (Shared/FightFX; no damage numbers over the goons), a shot puts
--       a white X on the goon, a swing (a goon in contact: EnemyRules.MeleeRange) a white impact star and a white
--       crescent swoosh round you, and pays more (the video's +9 next to +6);
--     * the goons throw several kinds of punch (a jab, a hook, an uppercut, a kick, a shove, a haymaker: EnemyRules.Swings),
--       each with its own wind-up; a punch that lands on you is a small white star on your chest and your body snaps back;
--     * a hit makes the goon flinch away from it (from the side, it twists) and knocks it back a little;
--     * a knocked-out goon falls one of three ways (back, forward, turning onto its side) and lies there in a dark heap,
--       its head loose beside it, until the run ends (the reference's piles stay while you walk on);
--     * the last one down: "CLEAR!" on the counter (the gate's white flash and its sign are HoodClient/Stages');
--     * a crew's strongest is a named enemy with a bigger, brick-studded HP bar and one signature move telegraphed in RED
--       on the ground (Shared/BossFX) at least a second before it lands; no boss bar, card, phase or banner anywhere;
--     * the punch that would finish you knocks you down: the reference's REVIVE? screen (Shared/FightUI.revive) over the
--       blurred world, counting down 10 s: "Revive!" and "Revenge!" are Robux products (their prices on the buttons),
--       "No" (or the time running out) is free and puts you back at the stage start.
--   Shooting: while you stand in a stage with goons up (the server's WaveLeft), with your gun in hand (always): hold the
--     mouse, R2 or the SHOOT button and it fires at the nearest goon in reach (a soft aim assist that sticks to one goon
--     until it drops), and you turn to face it while you strafe; in contact you swing instead. With the Auto Fight pass
--     (Pass_AutoShoot) it fires on its own. Shoot.client stands down while you're in a fight.
--   HUD (Shared/FightUI): "N LEFT" with the skull at the top centre, green "CLEAR!" (held a moment).
--   Runs (brief 23): a beaten crew stays down (in its heaps) for the rest of the run; when the run ends (back in the
--     lobby, WaveState 'Reset') every crew is drawn fresh again on its spots.
--   Leaving a stage (brief 24): a crew you walk away from before beating it is whole again (WaveState 'Wave' with
--     Restored): its HP bars fill back up with a green glint, a knocked-out goon pops back in on its spot in a puff of
--     smoke, and the rest walk home (a crew still walking when the run ends keeps walking: Reset's Keep).
--   A court crew jogs out of the players' tunnel as you walk in (brief 29).
local Players = game:GetService('Players')
local UserInputService = game:GetService('UserInputService')
local TweenService = game:GetService('TweenService')
local RunService = game:GetService('RunService')
local CollectionService = game:GetService('CollectionService')
local RS = game:GetService('ReplicatedStorage')
local ActiveMap = require(RS.Shared.ActiveMap)
local Juice = require(RS.Shared.Juice)
local Format = require(RS.Shared.Format)
local Net = require(RS.Shared.Net)
local Guns = require(RS.Shared.Config.Guns)
local ShotRules = require(RS.Shared.ShotRules)
local WaveRules = require(RS.Shared.WaveRules)
local EnemyRules = require(RS.Shared.EnemyRules)
local StageRules = require(RS.Shared.StageRules)
local GunTool = require(RS.Shared.GunTool)
local CharMotion = require(RS.Shared.CharMotion) -- (brief 29: the arms kick with each shot; brief 30: swings, hurt, down)
local EnemyRig = require(RS.Shared.EnemyRig)
local BossFX = require(RS.Shared.BossFX)
local FightFX = require(RS.Shared.FightFX)
local WorldBossView = require(RS.Shared.WorldBossView) -- (brief 29, P3b: the World Boss, HoodClient/WorldBoss)
local FightUI = require(RS.Shared.FightUI)
local Kit = require(RS.Shared.UIKit)
local Sound = require(RS.Shared.Config.Sound)
local ShotSounds = Sound.Enabled and require(RS.Shared.ShotSounds) or nil

local player = Players.LocalPlayer
local active = ActiveMap.wait(20)
if not active then return end
local frame = active.Frame
if ShotSounds then ShotSounds.init() end
local function play(kind, pitch) if ShotSounds then ShotSounds.play(kind, pitch) end end
local remote = Net.get('WaveShot')
local function worldOf(att) return att.Parent.CFrame * att.CFrame end -- (an attachment's WorldCFrame, spelled out)

-- Maps built before the goons still carry the old cartoon targets: they're scenery now, so they go.
local function retire(model)
	if not model:IsA('Model') or EnemyRules.Kinds[model:GetAttribute('Kind') or ''] then return end
	for _, d in model:GetDescendants() do
		if d:IsA('BasePart') then d.Transparency = 1; d.CanCollide = false
		elseif d:IsA('BillboardGui') then d.Enabled = false end
	end
end
for _, m in CollectionService:GetTagged('HoodWaveTarget') do retire(m) end
CollectionService:GetInstanceAddedSignal('HoodWaveTarget'):Connect(retire)

---------------------------------------------------------------------------------------------- the crews
-- Every stage's crew from the map's gates (the server reads the same: EnemyRules.world).
-- (With streaming on, far gates arrive later: the crews are worked out again as they do; a crew's spots depend only on
-- its own gate.)
local world, arenas = {}, {}
local function readGates()
	local gateModels = {}
	for _, m in CollectionService:GetTagged('HoodStageGate') do
		if m:IsDescendantOf(active.Root) then table.insert(gateModels, m) end
	end
	world, arenas = EnemyRules.world(StageRules.fromModels(gateModels))
end
readGates()
local gatesDirty = false
CollectionService:GetInstanceAddedSignal('HoodStageGate'):Connect(function()
	if gatesDirty then return end
	gatesDirty = true
	task.delay(0.5, function()
		gatesDirty = false
		readGates()
	end)
end)
local folder = Instance.new('Folder')
folder.Name = 'HoodGoons'
folder.Parent = workspace
BossFX.Parent = folder
FightFX.Parent = folder
local Boss = {} -- (the strongest enemies' signature moves and the court walk-outs, below)

-- waves[stage] = { Stage, Known (the server told us), Cleared, Goons = { [i] = view } }
-- view = { Index, Kind, Name, Home, Rig, Tag, Pos (drawn, map frame), Srv (server's), Vel, State, Since (when the state
--   began), Hp, Max, Down, KO (time knocked out), Walk, Yaw, Y (ground), Punch (time of the last punch), Swing (its kind),
--   Flinch/FlinchV and FlinchS/FlinchSV (back and side springs), Knock/KnockV (the knock-back, studs in its own frame),
--   Fall (how it fell), Settled (its heap is drawn and still), Refill = { From, At } (the HP bar filling back up),
--   PopIn (puff in when its rig is next built) }
local waves = {}
local popIn = {} -- [stage] = { At, [index] = true }: goons that come back in a puff once their crew is drawn again
local current = 0 -- the stage you stand in (with goons), the server's WaveStage
local pending = {} -- [index] = { { damage, time }, ... }: your shots in this stage the server hasn't answered yet
local PENDING_FOR = 1.2

local function pendingSum(index)
	local list, sum = pending[index], 0
	if not list then return 0 end
	local now = os.clock()
	for i = #list, 1, -1 do
		if now - list[i][2] > PENDING_FOR then table.remove(list, i) else sum += list[i][1] end
	end
	return sum
end
local function shownHp(v)
	local hp = v.Hp
	if v.Stage == current then hp -= pendingSum(v.Index) end
	return math.max(0, hp)
end
-- What the HP bar shows: shownHp, or on its way back up to full (a crew you left, made whole: REFILL_FOR seconds).
local REFILL_FOR = 0.6
local function tagHp(v, now)
	local r = v.Refill
	if not r then return shownHp(v) end
	local k = (now - r.At) / REFILL_FOR
	if k >= 1 then
		v.Refill = nil
		return shownHp(v)
	end
	k = 1 - (1 - math.max(0, k)) ^ 2
	return r.From + (shownHp(v) - r.From) * k
end

local function toWorld(p, y) return frame * CFrame.new(p.X, y or 0, p.Z) end
local BLACK = Kit.Color.black or Color3.new(0, 0, 0)

local function newView(stage, i, e)
	local max = EnemyRules.maxHp(stage, e.Kind)
	return { Stage = stage, Index = i, Kind = e.Kind, Name = e.Name, Home = e.Home, Pos = e.Home, Srv = e.Home, SrvPrev = e.Home, SrvAt = os.clock(),
		Vel = Vector3.zero, State = EnemyRules.Idle, Since = os.clock(), Hp = max, Max = max, Down = false, Walk = 0, Yaw = 0, Y = nil,
		Flinch = 0, FlinchV = 0, FlinchS = 0, FlinchSV = 0, Knock = Vector3.zero, KnockV = Vector3.zero, SwingN = 0,
		Variant = stage * 3 + i, Look = e.Look, Walkout = e.Walkout, Reserve = e.Reserve }
end
-- The wave of a stage as you'd find it walking in: everyone on their spot, full HP (until the server says otherwise).
local function waveOf(stage)
	local w = waves[stage]
	if not w and world[stage] then
		w = { Stage = stage, Known = false, Cleared = false, Goons = {} }
		-- (goons knocked out when the run ended pop back in, if their crew is drawn again right away)
		local back = popIn[stage]
		popIn[stage] = nil
		for i, e in world[stage] do
			w.Goons[i] = newView(stage, i, e)
			if back and back[i] then w.Goons[i].PopIn = back.At end
		end
		waves[stage] = w
	end
	return w
end

local function dropRig(v)
	if v.Rig then v.Rig.Model:Destroy() end
	v.Rig, v.Tag, v.Settled = nil, nil, nil
end
-- A puff of white smoke at `at` (world), `scale` the goon's size: a goon vanishing or popping in.
local function puffAt(at, scale, count)
	for k = 1, count or 7 do
		local p = Instance.new('Part')
		p.Name = 'Poof'
		p.Shape = Enum.PartType.Ball
		p.Material = Enum.Material.SmoothPlastic
		p.Color = k % 3 == 0 and Color3.fromRGB(220, 220, 228) or Color3.fromRGB(250, 250, 252)
		p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
		local a = k / (count or 7) * math.pi * 2
		local off = Vector3.new(math.cos(a) * 1.3, (k % 2) * 0.9, math.sin(a) * 1.3) * scale
		p.Size = Vector3.one * 1.2 * scale
		p.CFrame = CFrame.new(at + off * 0.4)
		p.Parent = folder
		TweenService:Create(p, TweenInfo.new(0.42, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = Vector3.one * 3.2 * scale, CFrame = CFrame.new(at + off + Vector3.new(0, 1, 0)), Transparency = 1 }):Play()
		task.delay(0.5, function() p:Destroy() end)
	end
end
-- The name over a goon: the user's own names ("Recess Bully", "Court King"); a crew's strongest by EnemyRules.shownName
-- (brief 30: never "Boss").
local function titleOf(v, rig)
	if v.Kind == 'Boss' then return EnemyRules.shownName(v.Look) end
	return rig and rig.R15 and rig.Model:GetAttribute('DisplayName') or v.Name
end
local function buildRig(v)
	local crew = EnemyRules.Crews[v.Stage] or 'Red'
	if v.Kind == 'Boss' then crew = 'Boss' end
	local rig = EnemyRig.build(v.Look, v.Kind, crew, v.Variant, folder)
	rig.Model:SetAttribute('Stage', v.Stage)
	rig.Model:SetAttribute('Index', v.Index)
	v.Title = titleOf(v, rig)
	-- (brief 30) a crew's strongest: a bigger tag, its bar brick-studded (the reference's Charger)
	local strong = v.Kind == 'Boss'
	local tag = FightUI.tag(rig.Head, v.Title, v.Max, strong)
	-- (bigger goons carry their tag higher: the Bruiser's and the strongest's heads are bigger)
	tag.Gui.StudsOffset = (FightUI.TagOffset or Vector3.new(0, 2.6, 0)) + Vector3.new(0, (rig.Scale - 1) * 1.6 + (strong and 0.5 or 0), 0)
	v.Rig, v.Tag, v.TagK = rig, tag, nil
	v.Model = rig.Model
	-- (brief 30) a heap stays dark when it is drawn again
	if v.Down then
		tag.Gui.Enabled = false
		EnemyRig.darken(rig, 0.72)
	end
	-- Back on its spot a moment ago (its crew made whole, or a new run): it pops up out of a puff (draw() puffs once it
	-- is placed). A crew first drawn later, as you walk up, just stands there.
	if v.PopIn and os.clock() - v.PopIn < 2 then v.Spawned, v.PuffIn = os.clock(), true end
	v.PopIn = nil
end

---------------------------------------------------------------------------------------------- the server's word
local function setState(v, state)
	if v.State == state then return end
	v.State, v.Since = state, os.clock()
	-- (brief 30) a new wind-up: the next kind of punch in its turn (a jab, a hook, an uppercut, a kick ...)
	if state == EnemyRules.Windup then
		v.SwingN += 1
		v.Swing = EnemyRules.swingFor(v.Kind, v.SwingN + v.Index)
	end
end
-- snap: the crew was only just drawn (put everyone where the server has them, no puffs).
local function applyMoves(w, d, snap)
	local now = os.clock()
	for i, v in w.Goons do
		local x, z, st = d[3 * i - 2], d[3 * i - 1], d[3 * i]
		if type(x) == 'number' and type(z) == 'number' then
			local p = Vector3.new(x, 0, z)
			local age = math.max(1 / 30, now - v.SrvAt)
			local vel = (p - v.Srv) / age
			if vel.Magnitude > 30 or snap then vel = Vector3.zero end
			v.Vel = v.Vel:Lerp(vel, 0.6)
			-- (only a running goon is drawn a little ahead of the server: one that has stopped, on its spot or squaring up
			-- to you, stands exactly where the server has it, not a stride past)
			if type(st) == 'number' and st ~= EnemyRules.Chase and st ~= EnemyRules.Return then v.Vel = Vector3.zero end
			v.SrvPrev, v.Srv, v.SrvAt = v.Srv, p, now
			if snap then
				v.Pos = p
			elseif (v.Pos - p).Magnitude > 12 and not v.Atk and not v.Down then
				-- (a jump: snap. One you can see goes in a puff and comes out of one: put back on its spot)
				if v.Rig then
					puffAt(toWorld(v.Pos, (v.Y or 0) + 2 * v.Rig.Scale).Position, v.Rig.Scale, 5)
					v.PuffIn = true
				end
				v.Pos = p
			end
		end
		if type(st) == 'number' and not v.Down then setState(v, st) end
	end
end

-- (brief 30) A hit on goon v from `from` (world): it flinches away from the hit (from the side it twists) and is knocked
-- back a little (a swing a lot more); `power` ~1 a shot, ~2 a swing, more on the hit that knocks it out.
-- (r3, matched side by side to W 31-33 s: the reference's guards show no stagger at all, only the X and the bar, so the
-- hit is a small tick: Stagger scales every push)
local STAGGER = 0.22
local function impulse(v, from, power)
	power *= STAGGER
	if not v.Rig then
		v.FlinchV += 7 * power
		return
	end
	local at = toWorld(v.Pos).Position
	local d = Vector3.new(at.X - from.X, 0, at.Z - from.Z)
	d = d.Magnitude > 1e-3 and d.Unit or Vector3.new(0, 0, 1)
	-- its own frame: CFrame.Angles(0, Yaw, 0) in the map frame; X its right, Z its back
	local right = frame:VectorToWorldSpace(Vector3.new(math.cos(v.Yaw), 0, -math.sin(v.Yaw)))
	local back = frame:VectorToWorldSpace(Vector3.new(math.sin(v.Yaw), 0, math.cos(v.Yaw)))
	local side, behind = d:Dot(right), d:Dot(back)
	v.FlinchV += 7 * power * (0.4 + 0.6 * math.max(0, behind))
	v.FlinchSV += 9 * power * side
	v.KnockV += Vector3.new(side, 0, behind) * 7 * power
end

-- A goon goes down: the hit throws it back, it falls one of three ways and settles into its heap (draw()).
local function knockOut(v, animate, melee)
	if v.Down then return end
	v.Down = true
	v.KO = animate and os.clock() or (os.clock() - 10)
	v.Fall = EnemyRules.fallFor(v.Index, melee)
	v.Settled = nil
	-- (r3, matched side by side to W 32.8-34.6 s: the reference's heaps lie apart, where each guard dropped, never on
	-- you) the knock-out hit slides it about 2.5 studs straight away from you as it falls
	local c = player.Character
	local r = c and c:FindFirstChild('HumanoidRootPart')
	if animate and r and v.Rig then
		local at = toWorld(v.Pos).Position
		local d = Vector3.new(at.X - r.Position.X, 0, at.Z - r.Position.Z)
		d = d.Magnitude > 1e-3 and d.Unit or Vector3.new(0, 0, 1)
		-- (fanned out: one goes left, the next straight, the next right, so the heaps lie apart round you)
		d = CFrame.Angles(0, (((v.Index or 1) % 3) - 1) * 0.8, 0):VectorToWorldSpace(d)
		local right = frame:VectorToWorldSpace(Vector3.new(math.cos(v.Yaw), 0, -math.sin(v.Yaw)))
		local back = frame:VectorToWorldSpace(Vector3.new(math.sin(v.Yaw), 0, math.cos(v.Yaw)))
		v.KnockV += Vector3.new(d:Dot(right), 0, d:Dot(back)) * 30
	end
	v.Atk = nil
	if v.Tag then v.Tag.Gui.Enabled = false end
end

-- (brief 30) A punch landing on you: the reference's small white impact star on your chest, your body snapping back.
local function landed(v)
	local c = player.Character
	local root = c and c:FindFirstChild('HumanoidRootPart')
	if not root then return end
	local from = v and v.Rig and v.Rig.Head.Position or root.Position + root.CFrame.LookVector * 3
	local d = Vector3.new(root.Position.X - from.X, 0, root.Position.Z - from.Z)
	d = d.Magnitude > 1e-3 and d.Unit or -root.CFrame.LookVector
	FightFX.star(root.Position + Vector3.new(0, 0.9, 0) - d * 0.7, 1.7, 0.1)
	CharMotion.hurt(1)
	play('Tock', 0.7)
end

local HEAL_GREEN = Color3.fromRGB(96, 232, 112)
local function onWave(info)
	local stage = info.Stage
	local drawn = waves[stage] ~= nil
	local w = waveOf(stage)
	if not w then return end
	w.Known, w.Cleared = true, false
	local now = os.clock()
	for i, v in w.Goons do
		local max = type(info.Max) == 'table' and info.Max[i] or v.Max
		local hp = type(info.HP) == 'table' and info.HP[i] or max
		local wasDown, was = v.Down, tagHp(v, now)
		v.Max, v.Hp = max, hp
		if hp > 0 then
			if wasDown then
				-- Back on its spot (a crew you left, made whole): it pops up out of a puff there.
				v.Down, v.KO, v.Fall, v.Settled = false, nil, nil, nil
				v.Knock, v.KnockV = Vector3.zero, Vector3.zero
				dropRig(v)
				v.Pos, v.Srv, v.SrvPrev, v.Vel = v.Home, v.Home, v.Home, Vector3.zero
				v.PopIn = now
			elseif info.Restored and was < hp and v.Rig then
				-- (brief 24) its HP bar fills back up, with a green glint
				v.Refill = { From = was, At = now }
				Juice.burst(v.Rig.Head.Position, HEAL_GREEN, 0.9 * v.Rig.Scale)
			end
			if v.Tag then v.Tag.set(tagHp(v, now), max) end
		else
			knockOut(v, false)
		end
	end
	if type(info.D) == 'table' then applyMoves(w, info.D, not drawn) end
	if stage == current then table.clear(pending) end
end

---------------------------------------------------------------------------------------------- the HUD
local gui, root, fit = Kit.screen('HoodWaves', nil, 6)
local pill = FightUI.pill(root)
FightUI.dock(pill.Gui, 'FightChipSlot', root) -- (the HUD's slot at the top centre, HudSpec.TopCentre)
-- (LOOP) The first fights teach themselves: while goons are up and you haven't fired for a moment, "Hold click to
-- shoot!" (or "Hold SHOOT to fire!" on a touch screen) sits under the counter, in the goal line's gold. Only until
-- you have beaten a couple of stages; the Auto Fight pass needs no telling.
local shootHint = Kit.text({ Name = 'ShootHint', Text = 'Hold click to shoot!', TextSize = 26, Stroke = BLACK, StrokeThickness = 3.5, TextColor3 = Kit.hex('FFD21A'), AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 52), Size = UDim2.fromOffset(460, 32), Visible = false, Parent = root })
local HINT_UNTIL, HINT_IDLE = 2, 1.2 -- (shown while WaveCleared < HINT_UNTIL, after HINT_IDLE s without a shot)
-- (Oct 27, flow: the audit's "the first fight is over before it starts") A crew you have never beaten announces itself:
-- "CREW INCOMING!" in red over the street for a beat as you walk in (once a stage a visit). It cannot wait its turn, so
-- it takes the moment queue's screen at once (MomentQueue.mark) and the others hold back.
local TextStyle = require(RS.Shared.TextStyle)
local MomentQueue = require(RS.Shared.MomentQueue)
local announced = {}
local CREW_FOR = 1.4
local function crewIncoming(stage)
	if announced[stage] then return end
	local best = player:GetAttribute('WaveCleared')
	if type(best) == 'number' and stage <= best then return end
	announced[stage] = true
	MomentQueue.mark('CrewIncoming', CREW_FOR)
	local holder = Kit.new('Frame', { Name = 'CrewIncoming', BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.3), Size = UDim2.fromOffset(700, 80), Parent = root })
	local sc = Kit.new('UIScale', { Scale = 0.5, Parent = holder })
	local t = Kit.text({ Name = 'Text', Text = 'CREW INCOMING!', TextSize = 54, ZIndex = 3, Parent = holder })
	TextStyle.apply(t, 'red', { Shadow = true })
	TweenService:Create(sc, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	task.delay(CREW_FOR - 0.35, function()
		local out = TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		for _, d in holder:GetDescendants() do
			if d:IsA('TextLabel') then TweenService:Create(d, out, { TextTransparency = 1 }):Play() end
			if d:IsA('UIStroke') then TweenService:Create(d, out, { Transparency = 1 }):Play() end
		end
		task.delay(0.4, function() holder:Destroy() end)
	end)
end
local clearUntil = 0 -- (the CLEAR! moment holds the pill until then)

-- (brief 30) The revive screen (Shared/FightUI.revive), its prices from Config/Products.
local Products = (function()
	local ok, r = pcall(function() return require(RS.Shared.Config.Products) end)
	return ok and type(r) == 'table' and r or nil
end)()
local function priceOf(key)
	local e = Products and Products.ByKey and Products.ByKey[key]
	return e and e.Price or nil
end
local revive = FightUI.revive(root, { Revive = priceOf('Revive'), Revenge = priceOf('Revenge') })

---------------------------------------------------------------------------------------------- the gun
local downed = nil -- (brief 30) you're knocked down: { At, Left, Paused }
local function training() return ShotRules.counts(player:GetAttribute('TrainingStation')) end
local function inFight()
	if downed then return false end
	local left = player:GetAttribute('WaveLeft')
	if current == 0 and WorldBossView.Active then return true end -- (the World Boss pier)
	return current > 0 and type(left) == 'number' and left > 0 and not training()
end
local function humanoid()
	local c = player.Character
	return c and c:FindFirstChildOfClass('Humanoid')
end
local function heldGun() return player.Character and GunTool.held(player.Character) or nil end
-- (brief 23) Your gun is always in your hand (the hotbar is hidden; Shoot.client and GunService keep it equipped): in a
-- fight this makes sure of it, and it never puts the gun away after one.
local function refreshEquip()
	local h = humanoid()
	if not h or h.Health <= 0 or not inFight() then return end
	local tool = GunTool.find(player)
	if tool and tool.Parent ~= player.Character then h:EquipTool(tool) end
end
player.DescendantAdded:Connect(function(d)
	if d:IsA('Tool') then task.defer(refreshEquip) end
end)
player.CharacterAdded:Connect(function() task.defer(refreshEquip) end)

-- Recoil: the gun kicks up and back in the hand (Tool.Grip) and springs home (as on the ranges).
local recoil = { angle = 0, vel = 0, tool = nil, base = nil, conn = nil }
local function kick(tool, strength)
	if recoil.tool ~= tool then
		if recoil.tool and recoil.tool.Parent and recoil.base then recoil.tool.Grip = recoil.base end
		recoil.tool, recoil.base, recoil.angle, recoil.vel = tool, tool.Grip, 0, 0
	end
	recoil.vel += 9 * strength
	if recoil.conn then return end
	recoil.conn = RunService.PreRender:Connect(function(dt)
		recoil.angle, recoil.vel = Juice.springStep(recoil.angle, recoil.vel, 0, 6, 0.55, dt)
		local t = recoil.tool
		if t and t.Parent then t.Grip = recoil.base * CFrame.Angles(-recoil.angle, 0, 0) * CFrame.new(0, 0, -recoil.angle * 0.5) end
		if math.abs(recoil.angle) < 1e-3 and math.abs(recoil.vel) < 1e-3 then
			if t and t.Parent then t.Grip = recoil.base end
			recoil.conn:Disconnect()
			recoil.conn = nil
		end
	end)
end

---------------------------------------------------------------------------------------------- shooting and swinging
local sticky -- the goon you're on (its index)
local function rootPart()
	local c = player.Character
	return c and c:FindFirstChild('HumanoidRootPart')
end
local function target()
	local r = rootPart()
	local w = waves[current]
	if not r or not w then return nil end
	local list = {}
	for i, v in w.Goons do
		if not v.Down and v.Rig and v.Rig.Model.Parent and shownHp(v) > 0 then list[i] = { Pos = toWorld(v.Pos).Position, Up = true } end
	end
	local cam = workspace.CurrentCamera
	sticky = WaveRules.pick(list, r.Position, cam and cam.CFrame.LookVector or r.CFrame.LookVector, sticky)
	return sticky and w.Goons[sticky]
end
local function chestOf(v)
	if v.Rig and v.Rig.R15 and v.Rig.Chest then return v.Rig.Chest.Position end
	if v.Rig and v.Rig.Head then return v.Rig.Head.Position - Vector3.new(0, 1.4 * v.Rig.Scale, 0) end
	return toWorld(v.Pos, (v.Y or 0) + 3).Position
end
-- The "+N" a hit pays (the server's own sum: ShotRules.pay of your x1 ShotBase off the ranges, times gun and shoes).
local shoeCarry = {}
local function gain(melee)
	-- (brief 29: a hit pays ShotRules.EnemyShare of that, the fraction carried like the server's; brief 30: a swing
	-- EnemyRules.MeleePay times that, in its own carry)
	local share = ShotRules.EnemyShare * (melee and EnemyRules.MeleePay or 1)
	return ShotRules.share(ShotRules.pay(player:GetAttribute('ShotBase'), player:GetAttribute('GunMultiplier'), player:GetAttribute('ShoeMultiplier'), shoeCarry), share, shoeCarry, melee and 'Melee' or 'Enemy')
end
-- (brief 30) Your "+N" pops by your body, a little to the left of your chest on screen, each one a touch apart (the
-- reference's "+6" / "+9" with the bicep).
local gainSide = 0
local function popGain(r, amount, melee)
	if amount <= 0 then return end
	local cam = workspace.CurrentCamera
	local right = cam and cam.CFrame.RightVector or Vector3.new(1, 0, 0)
	gainSide = (gainSide + 1) % 3
	local at = r.Position - right * (1.5 + gainSide * 0.35) + Vector3.new(0, 0.5 + gainSide * 0.3, 0)
	FightFX.gain(at, amount, { melee = melee, text = Format.compact(amount) })
end

local last, aimed, aimUntil = 0, nil, 0
local swingN = 0
local MELEE_EVERY = 0.26 -- (the reference's swings come 0.1-0.2 s apart in the scrum; a touch slower than a shot)
local function shoot()
	local meleeNext = false
	local r = rootPart()
	-- (P3b) on the World Boss pier the gun fires at the giant: a stand-in view for the shot's look below
	local boss = current == 0 and WorldBossView.Active and r and WorldBossView.aim(r.Position)
	Boss.wbView = Boss.wbView or { Boss = true, FlinchV = 0, FlinchSV = 0, KnockV = Vector3.zero }
	local v = (not boss) and target() or nil
	if v and r then
		local at = toWorld(v.Pos).Position
		meleeNext = Vector3.new(at.X - r.Position.X, 0, at.Z - r.Position.Z).Magnitude <= EnemyRules.MeleeRange
	end
	if os.clock() - last < (meleeNext and MELEE_EVERY or ShotRules.Cooldown) or not inFight() then return false end
	v = boss and Boss.wbView or v
	if not r or not v then return false end
	last = os.clock()
	aimed, aimUntil = v, os.clock() + 0.45
	local damage = EnemyRules.damage(player:GetAttribute('Power'))
	if meleeNext then
		-- (brief 30) a swing: the reference's close-range hit in the scrum (W 38.2-42.4 s): your arm sweeps across, a white
		-- crescent swoosh round you, a white star on the goon, and it pays more
		damage = math.floor(damage * EnemyRules.MeleePay)
		swingN += 1
		remote:FireServer(v.Stage, v.Index, true)
		pending[v.Index] = pending[v.Index] or {}
		table.insert(pending[v.Index], { damage, os.clock() })
		CharMotion.melee(swingN)
		local chest = chestOf(v)
		local look = Vector3.new(chest.X - r.Position.X, 0, chest.Z - r.Position.Z)
		look = look.Magnitude > 1e-3 and look.Unit or r.CFrame.LookVector
		FightFX.swoosh(CFrame.lookAt(r.Position, r.Position + look) * CFrame.new(0, 0.1, -0.4), swingN)
		play('Tock', 0.9)
		local hitV = v
		task.delay(0.08, function()
			if not hitV.Rig then return end
			FightFX.star(chestOf(hitV) - look * 0.5, 2.5, 0.1)
			impulse(hitV, r.Position, 2.2)
		end)
		popGain(r, gain(true), true)
		if v.Tag then v.Tag.set(shownHp(v), v.Max) end
		return true
	end
	if boss then
		Net.get('WorldBossShot'):FireServer()
	else
		remote:FireServer(v.Stage, v.Index)
		pending[v.Index] = pending[v.Index] or {}
		table.insert(pending[v.Index], { damage, os.clock() })
	end
	local tool = heldGun()
	local gun = Guns.ById[tool and tool:GetAttribute('GunId') or player:GetAttribute('EquippedGun') or ''] or Guns.List[1]
	local rig = tool and Juice.gunRig(tool)
	local to = (boss or chestOf(v)) + Vector3.new((math.random() - 0.5) * 0.6, (math.random() - 0.5) * 0.6, 0)
	local from = rig and worldOf(rig.muzzle).Position or (r.Position + Vector3.new(0, 1.2, 0))
	play('Shot', 1.1 - gun.Tier * 0.04)
	Juice.muzzle(rig, gun.Color, 0.9 + gun.Tier * 0.1)
	Juice.tracer(from, to, gun.Color, 0.18 + gun.Tier * 0.015)
	if rig and rig.eject then Juice.casing(worldOf(rig.eject)) end
	if tool then kick(tool, (0.8 + gun.Tier * 0.05) * 0.4) end -- (r3: the reference's gun barely kicks)
	CharMotion.shot(0.9 + gun.Tier * 0.03)
	-- (brief 30) the reference's hit: a white X on the goon and a small white star, no camera shake, no damage numbers
	FightFX.hitX(to)
	FightFX.star(to + Vector3.new(0, 0.2, 0), 1.0, 0.07)
	if boss then
		WorldBossView.hit(damage, to)
	else
		impulse(v, r.Position, 1)
	end
	play('Tock', 1.1)
	popGain(r, gain(false), false)
	if v.Tag then v.Tag.set(shownHp(v), v.Max) end
	return true
end

-- Hold to fire: the mouse, R2 or the SHOOT button. The Auto Fight pass fires whenever a goon is in reach.
local held = {}
local function autoFight() return player:GetAttribute('Pass_AutoShoot') == true end
local function sourceOf(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 then return 'mouse' end
	if input.KeyCode == Enum.KeyCode.ButtonR2 then return 'r2' end
	return nil
end
UserInputService.InputBegan:Connect(function(input, processed)
	if processed or not inFight() then return end
	local source = sourceOf(input)
	if source then
		held[source] = true
		shoot()
	end
end)
UserInputService.InputEnded:Connect(function(input)
	local source = sourceOf(input)
	if source then held[source] = nil end
end)

-- The round SHOOT button (Shoot.client's twin, same place) while you're in a fight: the way to shoot on a phone.
local shootGui = Instance.new('ScreenGui')
shootGui.Name = 'WaveShootButton'
shootGui.ResetOnSpawn = false
shootGui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
shootGui.Parent = player:WaitForChild('PlayerGui')
local button = Instance.new('TextButton')
button.Name = 'Shoot'
button.AnchorPoint = Vector2.new(1, 1)
button.Position = UDim2.new(1, -150, 1, -40)
button.Size = UDim2.fromOffset(112, 112)
button.BackgroundColor3 = Color3.fromRGB(255, 71, 87)
button.Text = 'SHOOT'
button.FontFace = Kit.Font.display
button.TextSize = 24
button.TextColor3 = Color3.new(1, 1, 1)
button.TextYAlignment = Enum.TextYAlignment.Bottom
button.AutoButtonColor = false
button.Visible = false
button.Parent = shootGui
Kit.corner(UDim.new(0.5, 0)).Parent = button
Kit.new('UIPadding', { PaddingBottom = UDim.new(0, 22), Parent = button })
Kit.stroke(Color3.fromRGB(74, 11, 22), 4, true).Parent = button
local ring = Kit.new('Frame', { Name = 'Crosshair', AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0, 34), Size = UDim2.fromOffset(26, 26), BackgroundTransparency = 1, Parent = button })
Kit.corner(UDim.new(0.5, 0)).Parent = ring
Kit.stroke(Color3.new(1, 1, 1), 3).Parent = ring
for _, bar in { { 2, 34 }, { 34, 2 } } do
	Kit.new('Frame', { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(bar[1] + 1, bar[2] + 1), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, Parent = ring })
end
local buttonScale = Kit.new('UIScale', { Parent = button })
local pressing = nil
button.InputBegan:Connect(function(input)
	if input.UserInputType ~= Enum.UserInputType.Touch and input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
	pressing = input
	held.button = true
	shoot()
	buttonScale.Scale = 0.88
	TweenService:Create(buttonScale, TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
end)
local function release(input)
	if not held.button then return end
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input == pressing then
		pressing = nil
		held.button = nil
	end
end
button.InputEnded:Connect(release)
UserInputService.InputEnded:Connect(release)

-- Your own name/Power tag over your head (LobbyService's HoodTag) would sit right where the goons are on your screen,
-- and from the spawn right over the Stage 1 gate's sign: it is hidden on your screen only (everyone else still sees
-- it; your HUD shows your Power and rebirths). (LOOP: it used to show outside fights.)
local function ownTag(_)
	local show = false
	local c = player.Character
	local head = c and c:FindFirstChild('Head')
	local tag = head and head:FindFirstChild('HoodTag')
	if tag and tag:IsA('BillboardGui') and tag.Enabled ~= show then tag.Enabled = show end
end

---------------------------------------------------------------------------------------------- drawing
-- The ground under a goon (the map's collidable surfaces only), looked up when it has moved.
local rayParams
pcall(function()
	rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Include
	rayParams.FilterDescendantsInstances = { active.Root }
	rayParams.RespectCanCollide = true
end)
local function groundAt(v, p)
	local w = toWorld(p, (v.Y or 0.6) + 3).Position
	local ok, hit = pcall(function() return workspace:Raycast(w, Vector3.new(0, -12, 0), rayParams) end)
	if ok and hit then return frame:PointToObjectSpace(hit.Position).Y end
	return v.Y or (math.abs(p.X) <= 8.6 and 0 or 0.6)
end

local DRAW_FAR, BUILD_FAR = 150, 170
local TAG_NEAR = 16 -- (LOOP: studs from the camera inside which a goon's tag stops growing on screen)
local function yawTo(from, to)
	local d = Vector3.new(to.X - from.X, 0, to.Z - from.Z)
	if d.Magnitude < 1e-3 then return nil end
	return math.atan2(-d.X, -d.Z) -- (a CFrame's yaw that looks along d)
end
local function turn(a, b, maxStep)
	local d = (b - a + math.pi) % (2 * math.pi) - math.pi
	return a + math.clamp(d, -maxStep, maxStep)
end
local S = EnemyRules
local SETTLE = EnemyRig.FallTime + EnemyRig.PileTime + 0.12 -- (a heap is still after this)
local function draw(v, dt, now, you)
	local kind = S.Kinds[v.Kind] or S.Kinds.Goon
	-- Where: toward the server's spot plus a little of its run (the server's goons trail the real ones by ~0.1 s).
	if not v.Down then
		local lead = math.min(now - v.SrvAt, 0.15)
		local goal = v.Srv + v.Vel * lead
		local before = v.Pos
		local scripted = Boss.place(v, now)
		v.Pos = scripted or v.Pos:Lerp(goal, Juice.alpha(14, dt))
		if scripted and (v.Pos - before).Magnitude > 1e-3 then v.Heading = yawTo(before, v.Pos) end
		local moved = (v.Pos - before).Magnitude
		v.Speed = moved / math.max(dt, 1e-3)
		v.Walk = (v.Walk + moved / (3.6 * (v.Rig and v.Rig.Scale or 1)) * math.pi) % (2 * math.pi)
		if not v.GroundY or (v.GroundAt or 0) < now - 0.25 or moved > 0.6 then
			v.GroundY, v.GroundAt = groundAt(v, v.Pos), now
		end
		-- (steps up a kerb in a quick hop instead of popping onto it)
		v.Y = v.Y and (v.Y + (v.GroundY - v.Y) * Juice.alpha(20, dt)) or v.GroundY
	end
	if not v.Rig then return end
	-- Which way it faces: at you while it fights, along its run going home, up the street (toward the way in) at rest.
	local want
	local fighting = v.State == S.Alert or v.State == S.Chase or v.State == S.Windup or v.State == S.Recover or v.State == S.Tele or v.State == S.Dash
	if v.Enter and v.Heading then want = v.Heading
	elseif v.Atk and v.Atk.Face then want = v.Atk.Face
	elseif fighting and you then want = yawTo(v.Pos, you)
	elseif v.State == S.Return and v.Speed and v.Speed > 1 then want = yawTo(v.Pos, v.Srv + v.Vel)
	elseif v.State == S.Idle then want = (you and (you - v.Pos).Magnitude < S.Notice + 12) and yawTo(v.Pos, you) or 0 end
	if want and not v.Down then v.Yaw = turn(v.Yaw, want, dt * 9) end
	-- The pose: the hit springs (back, side) and the knock-back (a spring while it stands; a slide that stops when down)
	v.Flinch, v.FlinchV = Juice.springStep(v.Flinch, v.FlinchV, 0, 3, 0.4, dt)
	v.FlinchS, v.FlinchSV = Juice.springStep(v.FlinchS or 0, v.FlinchSV or 0, 0, 3, 0.45, dt)
	if v.Down then
		v.Knock += v.KnockV * dt
		v.KnockV *= math.exp(-9 * dt)
	else
		v.Knock, v.KnockV = Juice.springStep(v.Knock, v.KnockV, Vector3.zero, 3.2, 0.7, dt)
	end
	local knock = Vector3.new(math.clamp(v.Knock.X, -3.5, 3.5), 0, math.clamp(v.Knock.Z, -1, 3.5))
	local p = { walk = v.Walk, stride = math.clamp((v.Speed or 0) / 7, 0, 1), flinch = math.clamp(v.Flinch * 0.06, -0.4, 0.5), flinchSide = math.clamp(v.FlinchS * 0.06, -0.5, 0.5), knock = knock, idle = now + v.Variant }
	if v.State == S.Idle and not v.Down and not v.Enter then
		p.arms = v.Variant % 2
		p.bob = math.sin(now * 4.2 + v.Variant) * 0.05 * v.Rig.Scale
		p.look = 0.05
	elseif fighting and not v.Down then
		p.guard = v.Rig.R15 and 0.9 or 0.75
		p.lean = 0.06
		-- (brief 30) the run-in: arms forward, chest down, like the reference's guards charging at you
		if v.State == S.Chase and (v.Speed or 0) > 6 then
			p.charge = math.clamp(((v.Speed or 0) - 6) / 5, 0, 1)
			p.guard = p.guard * (1 - p.charge)
			p.lean = 0.06 + 0.16 * p.charge
		end
		-- (a boxer's bounce while it squares up)
		if v.Rig.R15 and (v.Speed or 0) < 2 then p.bob = math.abs(math.sin(now * 6.5 + v.Variant)) * 0.1 * v.Rig.Scale end
	end
	if v.State == S.Windup and not v.Down then
		-- anticipation: eases back into the wind-up of its punch's kind, held tense at the end
		p.swing = v.Swing
		p.windup = EnemyRig.ready((now - v.Since) / math.max(0.1, kind.Windup))
		p.twist = v.Rig.R15 and 0 or -0.35 * p.windup
		p.lean = 0.12 - 0.1 * p.windup
	end
	if v.Punch then
		local t = now - v.Punch
		if t < EnemyRig.StrikeTime then
			-- the snap, a beat held out, then back to guard with a little overshoot
			p.swing = v.Swing
			p.punch = EnemyRig.strike(t)
			p.twist = v.Rig.R15 and 0 or 0.3 * p.punch
			p.lean = 0.12 + 0.18 * math.max(0, p.punch)
			p.windup = 0
		else
			v.Punch = nil
		end
	end
	Boss.pose(v, p, now)
	if v.Spawned then
		local t = now - v.Spawned
		if t < 0.3 then p.bob = (p.bob or 0) - (1 - t / 0.3) * 1.2 * v.Rig.Scale else v.Spawned = nil end
	end
	if v.Down then
		-- (brief 30) the fall, its own way, then the heap; dark, with a little brown dust as it lands; it stays
		local t = now - (v.KO or now)
		p.fall = v.Fall or 'Back'
		p.ko, p.pile = EnemyRig.fallCurve(t)
		p.guard, p.charge, p.windup, p.punch, p.swing, p.bob = nil, nil, nil, nil, nil, nil
		if t >= EnemyRig.FallTime * 0.8 and not v.Rig.Dark then
			EnemyRig.darken(v.Rig, 0.72)
			if t < EnemyRig.FallTime + 0.2 then FightFX.dust(toWorld(v.Pos + knock, (v.Y or 0) + 0.3).Position, 0.9 * v.Rig.Scale, 5) end
		end
		if t >= SETTLE then v.Settled = true end
	end
	local at = toWorld(v.Pos, v.Y or 0) * CFrame.Angles(0, v.Yaw, 0)
	if v.PuffIn then
		v.PuffIn = nil
		puffAt(at.Position + Vector3.new(0, 2 * v.Rig.Scale, 0), v.Rig.Scale, 5)
	end
	EnemyRig.pose(v.Rig, at, p)
	if v.Tag then
		local on = not v.Down and (v.Stage == current or v.State ~= S.Idle or v.Hp < v.Max or v.Refill ~= nil)
		if v.Tag.Gui.Enabled ~= on then v.Tag.Gui.Enabled = on end
		if on then
			v.Tag.set(tagHp(v, now), v.Max)
			-- (LOOP) A crew's tags all say their names, and in a group they stacked: only the goon your gun is on (and a
			-- crew's strongest) shows its name; the rest show just their HP bar.
			local named = v.Kind == 'Boss' or (v.Stage == current and v.Index == sticky)
			if v.Tag.Name and v.Tag.Name.Visible ~= named then v.Tag.Name.Visible = named end
			-- (LOOP) The tag is sized in studs, so a goon right by the camera (between it and you) had a bar filling the
			-- screen: inside TAG_NEAR studs of the camera it shrinks, never bigger on screen than it is at TAG_NEAR.
			local cam = workspace.CurrentCamera
			if cam and v.Rig and v.Rig.Head then
				local k = math.clamp((v.Rig.Head.Position - cam.CFrame.Position).Magnitude / TAG_NEAR, 0.25, 1)
				if math.abs(k - (v.TagK or 1)) > 0.02 then
					v.TagK = k
					local size = v.Kind == 'Boss' and FightUI.StrongSize or FightUI.TagSize or Vector2.new(4.6, 1.55)
					v.Tag.Gui.Size = UDim2.fromScale(size.X * k, size.Y * k)
				end
			end
		end
	end
end

---------------------------------------------------------------------------------------------- strongest enemies and walk-outs
Boss.teles = {} -- [view] = { T = the red telegraph (BossFX), At, Hit }

-- A court goon waits in the players' tunnel until you walk into its stage, then jogs out to its spot (staggered).
function Boss.walkout(v, stage, now)
	if not v.Walkout or v.Out then return end
	if stage == current or v.State ~= S.Idle or v.Hp < v.Max or v.Down then
		v.Out = true
		local a = arenas[stage]
		if stage == current and v.State == S.Idle and not v.Down and a and a.Tunnel then
			v.Enter = { At = now + 0.2 + ((v.Index - 1) % 3) * 0.45, From = a.Tunnel, Mid = a.Mouth }
			v.Pos = a.Tunnel
		end
	end
end

-- Where a goon is drawn when the script says so (nil: follow the server): jogging out of the tunnel, or a leap.
local JOG = 11
function Boss.place(v, now)
	local e = v.Enter
	if e then
		if v.State ~= S.Idle then
			v.Enter = nil
			return nil
		end
		local d = math.max(0, now - e.At) * JOG
		local s1, s2 = (e.Mid - e.From).Magnitude, (v.Home - e.Mid).Magnitude
		if d < s1 then return e.From:Lerp(e.Mid, d / math.max(s1, 1e-3)) end
		if d < s1 + s2 then return e.Mid:Lerp(v.Home, (d - s1) / math.max(s2, 1e-3)) end
		v.Enter = nil
		return v.Home
	end
	local a = v.Atk
	if a and a.Jump and a.P1 then
		local k = (now - (a.Hit - a.Flight)) / a.Flight
		if k >= 0 and k <= 1 then return a.O:Lerp(a.P1, k) end
		if k > 1 and now < a.Hit + 0.3 then return a.P1 end
	end
	return nil
end

-- A strongest enemy's body through its signature move: the ready pose builds up through the telegraph (with a shiver at
-- the end), the strike snaps as it lands (a thrown thing leaves its hands Flight seconds before), then it recovers.
function Boss.pose(v, p, now)
	local a = v.Atk
	if not a or v.Down then return end
	local throwing = Boss.Throwing[a.Move]
	local strikeAt = throwing and (a.Hit - a.Flight) or a.Hit
	p.move = a.Move
	if now < strikeAt then
		local liftOff = a.Jump and (a.Hit - a.Flight) or strikeAt
		local k = (now - a.At) / math.max(0.1, liftOff - a.At)
		p.ready = EnemyRig.ready(k)
		p.tremble = math.clamp((k - 0.7) * 3.3, 0, 1)
		if a.Jump then
			if now < liftOff then
				p.crouch = p.ready * 0.9
			else
				local j = (now - liftOff) / a.Flight
				p.jump = 28 * j * (1 - j) * (v.Rig.Scale or 1)
				p.ready, p.tremble = 1, 0
			end
		end
	else
		local t = now - strikeAt
		local s = EnemyRig.strike(t)
		p.strike = s
		p.ready = t < 0.16 and 1 or math.max(0, s)
		if t > EnemyRig.StrikeTime + (a.Move == 'Charge' and 0.3 or 0) then v.Atk = nil end
	end
end

-- 'Tele': it winds up and its red shape goes down on the ground (the reference's lane: no words pop over it).
Boss.Throwing = { Throw = true, Volley = true, Roll = true, Forklift = true, Containers = true }
function Boss.tele(v, info)
	if not v or v.Down then return end
	local now = os.clock()
	local T = math.max(0.3, tonumber(info.T) or 1)
	local O = Vector3.new(info.O and info.O[1] or v.Pos.X, 0, info.O and info.O[2] or v.Pos.Z)
	local D = Vector3.new(info.D and info.D[1] or 0, 0, info.D and info.D[2] or 1)
	local a = { Move = info.Move, At = now, Hit = now + T, Flight = tonumber(info.Flight) or 0.6, Jump = info.Jump, O = O, D = D, Info = info }
	if type(info.P) == 'table' and info.P[1] then a.P1 = Vector3.new(info.P[1][1], 0, info.P[1][2]) end
	a.Face = yawTo(O, a.P1 and (a.P1 - O).Magnitude > 1 and a.P1 or (O + D))
	v.Atk = a
	if Boss.teles[v] then Boss.teles[v].T.finish(false) end
	local y = v.Y or 0.6
	if info.Shape == 'Circle' then
		for _, c in info.P or {} do y = math.max(y, groundAt(v, Vector3.new(c[1], 0, c[2]))) end
	end
	Boss.teles[v] = { T = BossFX.telegraph(frame, info, y, folder), At = now, Hit = now + T }
	local b = EnemyRules.bossOf(v.Look)
	play('Tock', 0.55)
	if not Boss.Throwing[info.Move] then return end
	task.delay(math.max(0, T - a.Flight), function()
		if v.Atk ~= a or v.Down or not v.Rig then return end
		local prop = (b.Props and b.Props[info.Move]) or b.Prop
		if info.Move == 'Forklift' then
			-- (P3b) a forklift from behind it, flat out down the red lane, through the spot as it lands
			local ry = (v.Y or 0.6) + 0.1
			BossFX.fly(prop, toWorld(O - D * 8, ry).Position, toWorld(O + D * ((info.L or 40) + 4), ry).Position, a.Flight * 1.6, { slide = true })
		elseif info.Drop then
			-- (P3b) cargo containers off the crane, one onto each red square
			for k, c in info.P or {} do
				local to = Vector3.new(c[1], 0, c[2])
				local m = BossFX.drop(prop, toWorld(to, groundAt(v, to) + 3.8).Position, a.Flight, 26)
				if m and m.PrimaryPart then m:SetAttribute('Yaw', k) end
			end
		elseif info.Move == 'Roll' then
			local ry = (v.Y or 0.6) + 1
			BossFX.fly(prop, toWorld(O + D * 2, ry).Position, toWorld(O + D * (info.L or 30), ry).Position, a.Flight + 0.25, { roll = true, scale = 0.9 })
		else
			local hand = v.Rig.Chest.Position + Vector3.new(0, 1.4 * v.Rig.Scale, 0)
			for _, c in info.P or {} do
				local to = Vector3.new(c[1], 0, c[2])
				BossFX.fly(prop, hand, toWorld(to, groundAt(v, to) + 0.6).Position, a.Flight, { radius = info.R, scale = 0.9 })
			end
		end
	end)
end

-- 'Blast': it lands. The shape flashes and goes; a stomp rings out over the ground, a charge kicks up dust down its lane.
function Boss.blast(v, info)
	local te = v and Boss.teles[v]
	if te then
		te.T.finish(info.Landed)
		Boss.teles[v] = nil
	end
	if not v then return end
	local a = v.Atk
	local move = info.Move or (a and a.Move)
	local throwing = Boss.Throwing[move]
	if a and not throwing then a.Hit = math.min(a.Hit, os.clock()) end
	local y = (v.Y or 0.6) + 0.1
	if a and move == 'Anchor' then
		for k = 0, 4 do
			local t = -1 + k * 0.5
			local d = Vector3.new(a.D.X * math.cos(t) - a.D.Z * math.sin(t), 0, a.D.X * math.sin(t) + a.D.Z * math.cos(t))
			task.delay(k * 0.04, function() BossFX.dust(toWorld(a.O + d * ((a.Info.L or 16) - 3), y + 0.3).Position, 1.3) end)
		end
	elseif a and (move == 'Stomp' or move == 'Leap') then
		BossFX.impact(toWorld(move == 'Leap' and a.P1 or a.O, y).Position, a.Info.R or 8)
	elseif a and move == 'Blast' then
		for k = 1, 3 do
			task.delay(k * 0.07, function() BossFX.impact(toWorld(a.O + a.D * (k * (a.Info.L or 18) / 3.3), y).Position, 2.5 + k * 1.6, Color3.fromRGB(110, 200, 255)) end)
		end
	elseif a and move == 'Charge' then
		for k = 0, 4 do
			task.delay(k * 0.06, function() BossFX.dust(toWorld(a.O + a.D * (k * (a.Info.L or 24) / 5), y + 0.3).Position, 1.1) end)
		end
	end
	if info.Landed then
		landed(v)
		-- (the reference Pouncer's leap: a green spiral slash wraps the one it lands on)
		local r = rootPart()
		if r and move == 'Leap' then FightFX.slash(r.CFrame) end
	end
	play('Pop', 0.6)
end

-- Every frame: the telegraphs fill up; a stale one (no 'Blast': it was called off) goes.
function Boss.step(now)
	for v, te in Boss.teles do
		te.T.update((now - te.At) / math.max(0.1, te.Hit - te.At))
		if now > te.Hit + 0.6 or v.Down or v.State == S.Return or v.State == S.Idle then
			te.T.finish(false)
			Boss.teles[v] = nil
			if now < te.Hit then v.Atk = nil end
		end
	end
end
function Boss.clear()
	for v, te in Boss.teles do
		te.T.finish(false)
		Boss.teles[v] = nil
		v.Atk = nil
	end
end

-- A look the server has just built: a goon standing in as today's goon puts it on (while it stands easy).
task.spawn(function()
	local models = RS:WaitForChild(EnemyRig.FolderName, 60)
	if not models then return end
	models.ChildAdded:Connect(function(m)
		for _, w in waves do
			for _, v in w.Goons do
				if v.Rig and not v.Rig.R15 and v.Look == m.Name and v.State == S.Idle and not v.Down and not v.Enter then dropRig(v) end
			end
		end
	end)
end)

---------------------------------------------------------------------------------------------- knocked down (brief 30)
-- The reference's knockout (V4 16.1-16.7 s): you fall, and 0.2-0.3 s later the world blurs behind REVIVE?, its
-- countdown and the three buttons. Your body lies on its back (CharMotion.down: the Root joint; your HumanoidRootPart
-- is held still, anchored on your machine, so the server's moves still reach it); "Revive!" / "Revenge!" ask Roblox for
-- the product (Products.canBuy; "Coming soon!" under the button while its id is 0) and tell the server the countdown
-- waits meanwhile; "No" asks the server to put you back at the stage start. Its answer ('Up') stands you up.
local Lighting = game:GetService('Lighting')
local function reviveRemote()
	local net = RS:FindFirstChild('HoodNet')
	return net and net:FindFirstChild('Revive') or nil
end
local function tellServer(what, on)
	local r = reviveRemote()
	if r then r:FireServer(what, on) end
end
local blur = nil
local function setBlur(on)
	if on and not blur then
		blur = Instance.new('BlurEffect')
		blur.Name = 'HoodReviveBlur'
		blur.Size = 0
		blur.Parent = Lighting
		TweenService:Create(blur, TweenInfo.new(0.25), { Size = 14 }):Play()
	elseif not on and blur then
		blur:Destroy()
		blur = nil
	end
end
local function holdRoot(on)
	local r = rootPart()
	if r then r.Anchored = on end
end
-- (the HUD's one-window-at-a-time state, Shared/HudWindows: the revive screen takes it, so any open window closes, the
-- HUD steps aside and notices wait, HudToasts; PlayerGui's HoodWindow reads 'Revive' while it is up)
local HudWindows = (function()
	local node = RS.Shared:FindFirstChild('HudWindows')
	local ok, r = pcall(function() return node and require(node) end)
	return ok and type(r) == 'table' and r or nil
end)()
local function takeScreen(on)
	pcall(function()
		local pg = player.PlayerGui
		if on then
			if HudWindows and HudWindows.current and HudWindows.current() then HudWindows.close() end
			pg:SetAttribute('HoodWindow', 'Revive')
		elseif pg:GetAttribute('HoodWindow') == 'Revive' then
			pg:SetAttribute('HoodWindow', '')
		end
	end)
end
local function standUp()
	if not downed then return end
	downed = nil
	revive.hide()
	setBlur(false)
	CharMotion.down(false)
	holdRoot(false)
	takeScreen(false)
end
local function knockedDown(seconds)
	seconds = math.max(1, tonumber(seconds) or 10)
	downed = { At = os.clock(), Left = seconds, Paused = false }
	table.clear(held)
	aimed = nil
	Boss.clear()
	CharMotion.down(true)
	holdRoot(true)
	local mine = downed
	task.delay(0.25, function()
		if downed ~= mine then return end
		revive.show(seconds - 0.25)
		setBlur(true)
		takeScreen(true)
	end)
	play('Pop', 0.5)
end
local paying = nil -- the product key whose prompt is open
revive.Choice(function(key)
	if not downed then return end
	if key == 'No' then
		tellServer('No')
		return
	end
	local ok = Products and Products.canBuy and Products.canBuy(key)
	if not ok then
		revive.note(key, 'Coming soon!')
		return
	end
	paying = key
	tellServer('Paying', true)
	pcall(function() game:GetService('MarketplaceService'):PromptProductPurchase(player, Products.idOf(key)) end)
end)
pcall(function()
	game:GetService('MarketplaceService').PromptProductPurchaseFinished:Connect(function()
		if paying then
			paying = nil
			tellServer('Paying', false)
		end
	end)
end)

---------------------------------------------------------------------------------------------- every frame
-- Which goons to draw: the crews near the camera (your fight, the next stage's crew waiting behind its gate, the heaps
-- behind you); the rest are not built (or are put away) so nobody pays for goons out of sight.
local idleTick = 0
local function stageNear(stage, camPos)
	local a = arenas[stage]
	if not a then return false end
	local p = frame:PointToObjectSpace(camPos)
	local dz = p.Z > a.Z0 and p.Z - a.Z0 or (p.Z < a.Z1 and a.Z1 - p.Z or 0)
	return dz < BUILD_FAR
end
RunService.PreRender:Connect(function(dt)
	local cam = workspace.CurrentCamera
	if not cam then return end
	local now = os.clock()
	local r = rootPart()
	local you = r and frame:PointToObjectSpace(r.Position)
	you = you and Vector3.new(you.X, 0, you.Z)
	idleTick += dt
	local idleFrame = idleTick >= 1 / 15
	if idleFrame then
		idleTick = 0
		ownTag(not inFight())
		local learning = (player:GetAttribute('WaveCleared') or 0) < HINT_UNTIL
		-- (brief 32, FEEL: not while the tutorial's own hint says the same thing, in a new player's first fight)
		-- (Oct 27, round 8: YOU'RE READY! now lands in a fight, in the same top band: the hint waits while a goal moment
		-- is up, PlayerGui GoalMoment)
		local want = learning and inFight() and not autoFight() and now - last > HINT_IDLE and player:GetAttribute('OnboardingStep') ~= 'Fight'
			and player.PlayerGui:GetAttribute('GoalMoment') ~= true
		if want and shootHint.Visible == false then
			local okT, touch = pcall(function() return UserInputService.TouchEnabled and not UserInputService.MouseEnabled end)
			touch = okT and touch
			shootHint.Text = touch and 'Hold SHOOT to fire!' or 'Hold click to shoot!'
		end
		if shootHint.Visible ~= want then shootHint.Visible = want end
	end
	for stage in world do
		local near = stageNear(stage, cam.CFrame.Position)
		local w = near and waveOf(stage) or waves[stage]
		if w then
			for _, v in w.Goons do
				Boss.walkout(v, stage, now)
				local show = near and (not v.Walkout or v.Out)
				local fresh = false
				if show and not v.Rig then
					buildRig(v)
					fresh = true
				end
				if not show and v.Rig then dropRig(v) end
				if v.Rig then
					local busy = v.State ~= S.Idle or (v.Down and not v.Settled) or v.Hop or v.Punch or v.Spawned or v.Refill or v.PuffIn or v.Enter or v.Atk or math.abs(v.FlinchV) > 1e-2 or math.abs(v.Flinch) > 1e-2 or math.abs(v.FlinchSV or 0) > 1e-2 or v.KnockV.Magnitude > 1e-2 or v.Knock.Magnitude > 1e-2
					if v.Down and v.Settled then
						-- a heap is still: drawn once when it is (re)built, then left alone
						if fresh then draw(v, 1 / 15, now, you) end
					else
						-- (brief 29) close up, an R15 goon breathes and shifts every frame; further off, 15 times a second
						busy = busy or (v.Rig.R15 and (toWorld(v.Pos).Position - cam.CFrame.Position).Magnitude < 60)
						if busy or idleFrame or fresh then draw(v, busy and dt or 1 / 15, now, you) end
					end
				end
			end
		end
	end
	Boss.step(now)
	-- the revive screen's countdown (it waits while a purchase prompt is open)
	if downed and not downed.Paused then revive.set(downed.Left - (now - downed.At)) end
	-- Face the goon you shoot while you fire (you can still strafe and back off).
	local h = humanoid()
	if h and r and not downed then
		local facing = aimed and now < aimUntil and not aimed.Down and (aimed.Rig or aimed.Boss)
		if facing and aimed.Rig then
			if h.AutoRotate then h.AutoRotate = false; h:SetAttribute('WaveAim', true) end
			local look = toWorld(aimed.Pos).Position
			local yaw = yawTo(r.Position, look)
			if yaw then
				-- (brief 30: you turn to the goon over about 0.1 s, never in one frame)
				local lv = r.CFrame.LookVector
				local cur = math.atan2(-lv.X, -lv.Z)
				local d = (yaw - cur + math.pi) % (2 * math.pi) - math.pi
				r.CFrame = CFrame.new(r.Position) * CFrame.Angles(0, cur + d * (1 - math.exp(-20 * math.min(dt, 0.1))), 0)
			end
		elseif h:GetAttribute('WaveAim') then
			h.AutoRotate = true
			h:SetAttribute('WaveAim', nil)
		end
	end
	-- The trigger: held, or the Auto Fight pass with a goon in reach.
	if inFight() and (next(held) or autoFight()) then shoot() end
end)

---------------------------------------------------------------------------------------------- the server's word
local wasOn = false
local function refresh()
	local stage = player:GetAttribute('WaveStage')
	stage = type(stage) == 'number' and stage or 0
	if stage ~= current then
		current = stage
		table.clear(pending)
		sticky = nil
	end
	local left = player:GetAttribute('WaveLeft')
	if current > 0 and type(left) == 'number' and left > 0 then
		clearUntil = 0
		pill.set(left)
	elseif os.clock() >= clearUntil then
		pill.hide()
	end
	local on = inFight()
	-- (brief 32, FEEL: the round SHOOT button is a touch control; with a mouse the reference shows none, W 31 s)
	local okT, touchOnly = pcall(function() return UserInputService.TouchEnabled and not UserInputService.MouseEnabled end)
	button.Visible = on and (not okT or touchOnly == true)
	ownTag(not on)
	if on then
		refreshEquip()
	elseif wasOn then
		table.clear(held)
	end
	wasOn = on
end
for _, name in { 'WaveStage', 'WaveLeft', 'TrainingStation' } do
	player:GetAttributeChangedSignal(name):Connect(refresh)
end

-- The run ended: every crew stands again, fresh (the views are made again from the map's crews as they come in view):
-- a knocked-out goon (or one caught out of place) pops back in on its spot if its crew is drawn again right away; the
-- heaps go. The crews in `keep` are still walking home, whole again: they walk on (their Restored 'Wave' follows).
local function resetRun(keep)
	local kept = {}
	for _, n in type(keep) == 'table' and keep or {} do
		if type(n) == 'number' then kept[n] = true end
	end
	local now = os.clock()
	for stage, w in waves do
		if kept[stage] then
			w.Cleared = false
		else
			local back = nil
			for i, v in w.Goons do
				local away = v.Rig and not v.Down and (v.State ~= S.Idle or (v.Pos - v.Home).Magnitude > 1)
				if away then puffAt(toWorld(v.Pos, (v.Y or 0) + 2 * v.Rig.Scale).Position, v.Rig.Scale, 5) end
				if v.Down or away then
					back = back or { At = now }
					back[i] = true
				end
				dropRig(v)
			end
			waves[stage] = nil
			popIn[stage] = back
		end
	end
	table.clear(pending)
	table.clear(held)
	aimed, sticky = nil, nil
	clearUntil = 0
	pill.hide()
end

Net.get('WaveState').OnClientEvent:Connect(function(info)
	if type(info) ~= 'table' or type(info.Stage) ~= 'number' then return end
	if info.Kind == 'Reset' then
		resetRun(info.Keep)
		return
	end
	if info.Kind == 'Up' then
		standUp()
		refresh()
		return
	end
	local stage = info.Stage
	if info.Kind == 'Wave' then
		onWave(info)
		if not info.Restored then pcall(crewIncoming, stage) end
		return
	end
	local drawn = waves[stage] ~= nil
	local w = waveOf(stage)
	if info.Kind == 'KO' then
		knockedDown(info.For)
		refresh()
		return
	elseif info.Kind == 'Wait' then
		if downed then
			downed.Left, downed.At, downed.Paused = tonumber(info.For) or downed.Left, os.clock(), info.Paused == true
			revive.set(downed.Left)
		end
		return
	end
	if not w then
		return
	elseif info.Kind == 'Moves' and type(info.D) == 'table' then
		w.Known = true
		applyMoves(w, info.D, not drawn)
	elseif info.Kind == 'Hit' and type(info.Index) == 'number' and type(info.HP) == 'number' then
		local v = w.Goons[info.Index]
		local list = pending[info.Index]
		if list and #list > 0 and stage == current then table.remove(list, 1) end
		if v then
			v.Hp = info.HP
			if info.HP <= 0 then
				-- (brief 30) the hit that knocks it out throws it back harder: a swing hardest
				local r = rootPart()
				if r and not v.Down then impulse(v, r.Position, info.Melee and 2.4 or 1.6) end
				knockOut(v, true, info.Melee == true)
			elseif v.Tag then v.Tag.set(shownHp(v), v.Max) end
		end
	elseif info.Kind == 'Punch' and type(info.Index) == 'number' then
		local v = w.Goons[info.Index]
		if v and not v.Down then
			v.Punch = os.clock()
			if not v.Swing then v.Swing = EnemyRules.swingFor(v.Kind, v.Index) end
			if info.Landed then landed(v) end
		end
	elseif info.Kind == 'Tele' and type(info.Index) == 'number' then
		Boss.tele(w.Goons[info.Index], info)
	elseif info.Kind == 'Blast' and type(info.Index) == 'number' then
		Boss.blast(w.Goons[info.Index], info)
	elseif info.Kind == 'Cleared' then
		w.Cleared = true
		for _, g in w.Goons do if not g.Down then knockOut(g, g.Rig ~= nil) end end
		local reward = type(info.Reward) == 'number' and info.Reward or 0
		-- (brief 30) the reference's CLEAR! chip with its line under it ("Mission complete!"): ours says the gate ahead
		-- opened, "STAGE N OPEN!" (the user's words), where the big banner over the gate sign used to be
		local nextStage = type(stage) == 'number' and stage < #EnemyRules.Lineups and ('STAGE ' .. (stage + 1) .. ' OPEN!') or nil
		pill.clear(reward > 0 and ('+' .. Format.compact(reward) .. ' Cash') or nextStage)
		-- "CLEAR!" holds a moment, then goes (unless a wave comes back first)
		local token = os.clock() + 2.4
		clearUntil = token
		task.delay(2.45, function()
			if clearUntil == token and ((player:GetAttribute('WaveLeft') or 0) == 0 or current == 0) then pill.hide() end
		end)
	end
end)

gui:GetPropertyChangedSignal('AbsoluteSize'):Connect(function() fit(gui.AbsoluteSize) end)
gui.Parent = player:WaitForChild('PlayerGui')
fit(gui.AbsoluteSize)
refresh()
