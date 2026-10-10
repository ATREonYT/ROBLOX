-- The stage goons on your screen (brief 18). The server decides everything (WaveService, Shared/WaveRules and
-- Shared/EnemyRules); this draws it and aims.
--   Goons: cartoon rival-crew kids (Shared/GoonRig) built here, on your machine only: other players never see your goons,
--     you never see theirs. Each stage's crew stands on its spots in front of the next gate (you can see them waiting from
--     the gate before); once you walk in, the server's moves (WaveState 'Moves', 10 a second) drive them, smoothed: they
--     notice you ("!"), run at you, put their fists up, wind up and punch (a white swipe; Roblox's own health bar and
--     red hurt flash show the damage), flinch and flash white when hit, and a knocked-out goon falls flat on its back,
--     sees stars and vanishes in a poof. Over each: its name and a red HP bar ("Goon 1  40/40", Shared/FightUI: UI2's look).
--   Shooting: while you stand in a stage with goons up (the server's WaveLeft), with your gun in hand (always): hold the
--     mouse, R2 or the SHOOT button and it fires at the nearest goon in reach (a soft aim assist that sticks to one goon
--     until it drops), and you turn to face it while you strafe. With the Auto Fight pass (Pass_AutoShoot) it fires on its
--     own. Each shot: muzzle flash, tracer, sparks, recoil, a red damage number over the goon (your Power) and your "+N"
--     Power by you. Shoot.client stands down while you're in a fight.
--   HUD (Shared/FightUI, UI2's look): "💀 N LEFT" at the top centre, green "CLEAR!" with the Cash a clear paid (held a
--     moment; the gate ahead opens with it, HoodClient/Stages); "KNOCKED OUT!" when a punch would have finished you (the
--     server puts you back at the stage start).
--   Runs (brief 23): a beaten crew stays down for the rest of the run; when the run ends (back in the lobby, WaveState
--     'Reset') every crew is drawn fresh again on its spots, the next one waiting behind its gate.
--   Leaving a stage (brief 24): a crew you walk away from before beating it is whole again (WaveState 'Wave' with
--     Restored): its HP bars fill back up with a green glint, a knocked-out goon pops back in on its spot in a puff of
--     smoke, and the rest walk home (a crew still walking when the run ends keeps walking: Reset's Keep).
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
local GoonRig = require(RS.Shared.GoonRig)
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

-- waves[stage] = { Stage, Known (the server told us), Cleared, Goons = { [i] = view } }
-- view = { Index, Kind, Name, Home, Rig, Tag, Pos (drawn, map frame), Srv (server's), Vel, State, Since (when the state
--   began), Hp, Max, Down, KO (time knocked out), Walk, Yaw, Y (ground), Punch (time of the last punch), Flinch, FlinchV,
--   Refill = { From, At } (the HP bar filling back up), PopIn (puff in when its rig is next built) }
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

-- Moments over a goon: a yellow "!" that pops when it notices you, and three "★" circling its head when it is knocked
-- out (UI2's outline style: Kit's display font, a plain black stroke).
local BLACK = Kit.Color.black or Color3.new(0, 0, 0)
local function alertOver(head, height)
	local g = Instance.new('BillboardGui')
	g.Name = 'GoonAlert'
	g.Size = UDim2.fromScale(2.2, 2.2)
	g.StudsOffsetWorldSpace = Vector3.new(0, height, 0)
	g.LightInfluence, g.AlwaysOnTop, g.MaxDistance = 0, true, 120
	local t = Kit.text({ Name = 'Mark', Text = '!', Stroke = BLACK, StrokeThickness = 3, TextColor3 = Color3.fromRGB(255, 214, 64), Parent = g })
	t.TextScaled = true
	local scale = Kit.new('UIScale', { Scale = 0.2, Parent = t })
	g.Parent = head
	TweenService:Create(scale, TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	TweenService:Create(t, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, false, 0.5), { TextTransparency = 1 }):Play()
	local st = t:FindFirstChildOfClass('UIStroke')
	if st then TweenService:Create(st, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, false, 0.5), { Transparency = 1 }):Play() end
	task.delay(0.8, function() g:Destroy() end)
end
local function starsOver(head, height)
	local g = Instance.new('BillboardGui')
	g.Name = 'GoonStars'
	g.Size = UDim2.fromScale(4, 1.6)
	g.StudsOffsetWorldSpace = Vector3.new(0, height, 0)
	g.LightInfluence, g.AlwaysOnTop, g.MaxDistance = 0, true, 120
	local stars = {}
	for k = 1, 3 do
		local t = Kit.text({ Name = 'Star', Text = '★', Stroke = BLACK, StrokeThickness = 2, TextColor3 = Color3.fromRGB(255, 220, 60), AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromScale(0.3, 0.75), Parent = g })
		t.TextScaled = true
		stars[k] = t
	end
	g.Parent = head
	local self = { Gui = g }
	function self:spin(time)
		for k, t in stars do
			local a = time * 7 + k * math.pi * 2 / 3
			t.Position = UDim2.fromScale(0.5 + 0.38 * math.cos(a), 0.5 + 0.22 * math.sin(a))
			t.ZIndex = math.sin(a) > 0 and 2 or 1
		end
	end
	self:spin(0)
	return self
end

local function newView(stage, i, e)
	local max = EnemyRules.maxHp(stage, e.Kind)
	return { Stage = stage, Index = i, Kind = e.Kind, Name = e.Name, Home = e.Home, Pos = e.Home, Srv = e.Home, SrvPrev = e.Home, SrvAt = os.clock(),
		Vel = Vector3.zero, State = EnemyRules.Idle, Since = os.clock(), Hp = max, Max = max, Down = false, Walk = 0, Yaw = 0, Y = nil,
		Flinch = 0, FlinchV = 0, Variant = stage * 3 + i }
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
	v.Rig, v.Tag, v.Stars = nil, nil, nil
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
local function buildRig(v)
	local crew = EnemyRules.Crews[v.Stage] or 'Red'
	if v.Kind == 'Boss' then crew = 'Boss' end
	local rig = GoonRig.build(v.Kind, crew, v.Variant, folder)
	rig.Model:SetAttribute('Stage', v.Stage)
	rig.Model:SetAttribute('Index', v.Index)
	local tag = FightUI.tag(rig.Head, v.Name, v.Max)
	-- (bigger goons carry their tag higher: the Bruiser's and the Boss's heads are bigger)
	tag.Gui.StudsOffset = (FightUI.TagOffset or Vector3.new(0, 2.6, 0)) + Vector3.new(0, (rig.Scale - 1) * 1.6, 0)
	v.Rig, v.Tag, v.TagK = rig, tag, nil
	v.Model = rig.Model
	-- Back on its spot a moment ago (its crew made whole, or a new run): it pops up out of a puff (draw() puffs once it
	-- is placed). A crew first drawn later, as you walk up, just stands there.
	if v.PopIn and os.clock() - v.PopIn < 2 then v.Spawned, v.PuffIn = os.clock(), true end
	v.PopIn = nil
end

---------------------------------------------------------------------------------------------- the server's word
local function setState(v, state)
	if v.State == state then return end
	local was = v.State
	v.State, v.Since = state, os.clock()
	if state == EnemyRules.Alert and (was == EnemyRules.Idle or was == EnemyRules.Return) and v.Rig then
		alertOver(v.Rig.Head, v.Rig.Head.Size.Y / 2 + 2.6 * v.Rig.Scale)
		v.Hop = os.clock()
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
			elseif (v.Pos - p).Magnitude > 12 then
				-- (a jump: snap. One you can see goes in a puff and comes out of one: put back on its spot)
				if v.Rig and not v.Down then
					puffAt(toWorld(v.Pos, (v.Y or 0) + 2 * v.Rig.Scale).Position, v.Rig.Scale, 5)
					v.PuffIn = true
				end
				v.Pos = p
			end
		end
		if type(st) == 'number' and not v.Down then setState(v, st) end
	end
end

-- A goon goes down: flat on its back, stars, then a poof and gone.
local function knockOut(v, animate)
	if v.Down then return end
	v.Down = true
	v.KO = animate and os.clock() or (os.clock() - 10)
	if v.Tag then v.Tag.Gui.Enabled = false end
	if animate and v.Rig then
		v.Stars = starsOver(v.Rig.Head, 1.2 * v.Rig.Scale)
		-- (LOOP: up over the tag's height, clear of the red numbers and your "+N" by the goons' chests)
		Juice.popNumber(v.Rig.Head.Position + Vector3.new(0, 4 * v.Rig.Scale, 0), 'KO!', Color3.fromRGB(255, 220, 60), Kit.Font.display, { size = Vector2.new(3.6, 1.6), thickness = 3, stroke = BLACK })
	end
end
local function poof(v)
	if not v.Rig then return end
	local at = v.Rig.Head.Position - Vector3.new(0, 1.6 * v.Rig.Scale, 0)
	puffAt(at, v.Rig.Scale)
	Juice.burst(at + Vector3.new(0, 1, 0), Color3.fromRGB(255, 220, 60), 1.4 * v.Rig.Scale)
	Juice.shards(at + Vector3.new(0, 1.5, 0), Color3.fromRGB(255, 220, 60), 'confetti')
	play('Pop', 0.9)
	dropRig(v)
end

-- A punch landing on you (or just missing): the arm snaps out, a white swipe across you, a camera knock.
local function swipe(v)
	local c = player.Character
	local root = c and c:FindFirstChild('HumanoidRootPart')
	if not root or not v.Rig then return end
	local from = v.Rig.Head.Position
	local chest = root.Position + Vector3.new(0, 0.6, 0)
	local dir = Vector3.new(chest.X - from.X, 0, chest.Z - from.Z)
	dir = dir.Magnitude > 1e-3 and dir.Unit or Vector3.new(0, 0, -1)
	local side = dir:Cross(Vector3.new(0, 1, 0))
	local holder = Instance.new('Part')
	holder.Name = 'Swipe'
	holder.Anchored, holder.CanCollide, holder.CanQuery, holder.CanTouch, holder.Transparency = true, false, false, false, 1
	holder.Size = Vector3.one * 0.2
	holder.CFrame = CFrame.new(chest)
	holder.Parent = folder
	local a0, a1 = Instance.new('Attachment'), Instance.new('Attachment')
	a0.Position = side * 1.8 + Vector3.new(0, 1.0, 0) - dir * 0.6
	a1.Position = -side * 1.8 - Vector3.new(0, 0.6, 0) - dir * 0.6
	a0.Parent, a1.Parent = holder, holder
	local beam = Instance.new('Beam')
	beam.Attachment0, beam.Attachment1 = a0, a1
	beam.Width0, beam.Width1 = 0.9, 0.15
	beam.CurveSize0, beam.CurveSize1 = -2.2, 2.2
	beam.Segments = 16
	beam.FaceCamera = true
	beam.LightEmission, beam.LightInfluence = 1, 0
	beam.Color = ColorSequence.new(Color3.new(1, 1, 1))
	beam.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(0.4, 0), NumberSequenceKeypoint.new(1, 0.5) })
	beam.Parent = holder
	task.delay(0.14, function() holder:Destroy() end)
	Juice.burst(chest - dir * 0.8, Color3.new(1, 1, 1), 0.8)
	Juice.kick(0.55)
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
				v.Down, v.KO, v.Stars = false, nil, nil
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
-- (LOOP) The first fights teach themselves: while goons are up and you haven't fired for a moment, "Hold click to
-- shoot!" (or "Hold SHOOT to fire!" on a touch screen) sits under the counter, in the goal line's gold. Only until
-- you have beaten a couple of stages; the Auto Fight pass needs no telling.
local shootHint = Kit.text({ Name = 'ShootHint', Text = 'Hold click to shoot!', TextSize = 26, Stroke = BLACK, StrokeThickness = 3.5, TextColor3 = Kit.hex('FFD21A'), AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 52), Size = UDim2.fromOffset(460, 32), Visible = false, Parent = root })
local HINT_UNTIL, HINT_IDLE = 2, 1.2 -- (shown while WaveCleared < HINT_UNTIL, after HINT_IDLE s without a shot)
local clearUntil = 0 -- (the CLEAR! moment holds the pill until then)
-- "KNOCKED OUT!" over "Train more Power at the ranges!" (UI2's banner style: Kit text, a black stroke, a lit gradient):
-- pops in, holds, floats up and fades.
local banner
local function koBanner()
	if banner then banner:Destroy() end
	local holder = Kit.new('Frame', { Name = 'FightBanner', BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.32), Size = UDim2.fromOffset(680, 150), Parent = root })
	banner = holder
	local scale = Kit.new('UIScale', { Scale = 0.3, Parent = holder })
	-- (LOOP) on a dark see-through backing, like the GOAL DONE moment: it lands over the next gate's sign and the street
	local back = Kit.new('Frame', { Name = 'Back', BackgroundColor3 = Kit.hex('10131E'), BackgroundTransparency = 0.4, BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, -4), Size = UDim2.new(0.84, 0, 0, 140), ZIndex = 0, Parent = holder })
	Kit.corner(12).Parent = back
	local t = Kit.text({ Name = 'Title', Text = 'KNOCKED OUT!', TextSize = 72, Stroke = BLACK, StrokeThickness = 5, Size = UDim2.new(1, 0, 0, 84), Parent = holder })
	t.TextScaled = true
	Kit.gradient(Color3.fromRGB(255, 160, 150), Color3.fromRGB(255, 59, 59), 0.5).Parent = t
	local d = Kit.text({ Name = 'Detail', Text = 'Train more Power at the ranges!', TextSize = 34, Stroke = BLACK, StrokeThickness = 3.5, TextColor3 = Kit.Color.white, Position = UDim2.fromOffset(0, 88), Size = UDim2.new(1, 0, 0, 40), Parent = holder })
	d.TextScaled = true
	TweenService:Create(scale, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	task.delay(2.2, function()
		if banner ~= holder then return end
		local fade = TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		TweenService:Create(holder, fade, { Position = UDim2.fromScale(0.5, 0.26) }):Play()
		TweenService:Create(back, fade, { BackgroundTransparency = 1 }):Play()
		for _, x in { t, d } do
			TweenService:Create(x, fade, { TextTransparency = 1 }):Play()
			local st = x:FindFirstChildOfClass('UIStroke')
			if st then TweenService:Create(st, fade, { Transparency = 1 }):Play() end
		end
		task.delay(0.45, function() if banner == holder then holder:Destroy(); banner = nil end end)
	end)
end

---------------------------------------------------------------------------------------------- the gun
local function training() return ShotRules.counts(player:GetAttribute('TrainingStation')) end
local function inFight()
	local left = player:GetAttribute('WaveLeft')
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

---------------------------------------------------------------------------------------------- shooting
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
		if not v.Down and v.Rig and shownHp(v) > 0 then list[i] = { Pos = toWorld(v.Pos).Position, Up = true } end
	end
	local cam = workspace.CurrentCamera
	sticky = WaveRules.pick(list, r.Position, cam and cam.CFrame.LookVector or r.CFrame.LookVector, sticky)
	return sticky and w.Goons[sticky]
end
local function chestOf(v)
	if v.Rig and v.Rig.Head then return v.Rig.Head.Position - Vector3.new(0, 1.4 * v.Rig.Scale, 0) end
	return toWorld(v.Pos, (v.Y or 0) + 3).Position
end
-- The "+N" a hit pays (the server's own sum: ShotRules.pay of your x1 ShotBase off the ranges, times gun and shoes).
local shoeCarry = {}
local function gain()
	return ShotRules.pay(player:GetAttribute('ShotBase'), player:GetAttribute('GunMultiplier'), player:GetAttribute('ShoeMultiplier'), shoeCarry)
end
local DAMAGE_RED = Color3.fromRGB(255, 70, 70)
-- (brief 19, LOOP: in a scrum one red number per shot stacked into a column over the goons) One red number per goon at
-- most every DAMAGE_EVERY seconds: the first shot pops at once, the shots after it add up into the next one.
local DAMAGE_EVERY = 0.3
local damageAcc = setmetatable({}, { __mode = 'k' }) -- [goon] = { Sum, Last, Pending, At }
local function popDamage(v, damage, at)
	local acc = damageAcc[v]
	if not acc then
		acc = { Sum = 0, Last = 0 }
		damageAcc[v] = acc
	end
	acc.Sum += damage
	acc.At = at
	if acc.Pending then return end
	local function flush()
		acc.Pending = false
		acc.Last = os.clock()
		if acc.Sum <= 0 then return end
		Juice.popNumber(acc.At + Vector3.new(0, 1.6, 0), Format.compact(acc.Sum), DAMAGE_RED, Kit.Font.display, { size = Vector2.new(2.6, 1.1), thickness = 2, stroke = BLACK })
		acc.Sum = 0
	end
	local wait = DAMAGE_EVERY - (os.clock() - acc.Last)
	if wait <= 0 then
		flush()
	else
		acc.Pending = true
		task.delay(wait, flush)
	end
end

local last, aimed, aimUntil = 0, nil, 0
local gainCombo -- (the running "+N" rig: kept by your shoulder as you move)
local function shoot()
	if os.clock() - last < ShotRules.Cooldown or not inFight() then return false end
	local r = rootPart()
	local v = target()
	if not r or not v then return false end
	last = os.clock()
	remote:FireServer(v.Stage, v.Index)
	local damage = EnemyRules.damage(player:GetAttribute('Power'))
	pending[v.Index] = pending[v.Index] or {}
	table.insert(pending[v.Index], { damage, os.clock() })
	local tool = heldGun()
	local gun = Guns.ById[tool and tool:GetAttribute('GunId') or player:GetAttribute('EquippedGun') or ''] or Guns.List[1]
	local rig = tool and Juice.gunRig(tool)
	local to = chestOf(v) + Vector3.new((math.random() - 0.5) * 0.6, (math.random() - 0.5) * 0.6, 0)
	aimed, aimUntil = v, os.clock() + 0.45
	local from = rig and worldOf(rig.muzzle).Position or (r.Position + Vector3.new(0, 1.2, 0))
	play('Shot', 1.1 - gun.Tier * 0.04)
	Juice.muzzle(rig, gun.Color, 0.9 + gun.Tier * 0.1)
	Juice.tracer(from, to, gun.Color, 0.18 + gun.Tier * 0.015)
	if rig and rig.eject then Juice.casing(worldOf(rig.eject)) end
	if tool then kick(tool, 0.8 + gun.Tier * 0.05) end
	Juice.kick(0.06 + gun.Tier * 0.012)
	Juice.burst(to, gun.Color, 0.8)
	if v.Rig then Juice.flash(v.Rig.Model) end
	v.FlinchV += 7
	play('Tock', 1.1)
	-- The video's numbers: red damage over the goon, your "+N" Power by you.
	popDamage(v, damage, to)
	-- your Power: one running "+N" by your shoulder that rolls up while you fire (the ranges' combo), and follows you
	local cam = workspace.CurrentCamera
	local right = cam and cam.CFrame.RightVector or Vector3.new(1, 0, 0)
	local at = r.Position + right * 2.4 + Vector3.new(0, 2.6, 0)
	local c = Juice.combo('HoodFightGain', at, gain(), { color = Kit.Color.power, format = Format.compact })
	if c and c.part then
		c.part.CFrame = CFrame.new(at)
		if c.gui then c.gui.Size = UDim2.fromScale(2.8, 1.6) end -- (smaller than the ranges': it sits right by you)
		gainCombo = c
	end
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
local function draw(v, dt, now, you)
	local kind = S.Kinds[v.Kind] or S.Kinds.Goon
	-- Where: toward the server's spot plus a little of its run (the server's goons trail the real ones by ~0.1 s).
	if not v.Down then
		local lead = math.min(now - v.SrvAt, 0.15)
		local goal = v.Srv + v.Vel * lead
		local before = v.Pos
		v.Pos = v.Pos:Lerp(goal, Juice.alpha(14, dt))
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
	local fighting = v.State == S.Alert or v.State == S.Chase or v.State == S.Windup or v.State == S.Recover
	if fighting and you then want = yawTo(v.Pos, you)
	elseif v.State == S.Return and v.Speed and v.Speed > 1 then want = yawTo(v.Pos, v.Srv + v.Vel)
	elseif v.State == S.Idle then want = (you and (you - v.Pos).Magnitude < S.Notice + 12) and yawTo(v.Pos, you) or 0 end
	if want and not v.Down then v.Yaw = turn(v.Yaw, want, dt * 9) end
	-- The pose.
	v.Flinch, v.FlinchV = Juice.springStep(v.Flinch, v.FlinchV, 0, 3, 0.4, dt)
	local p = { walk = v.Walk, stride = math.clamp((v.Speed or 0) / 7, 0, 1), flinch = math.clamp(v.Flinch * 0.06, -0.4, 0.5) }
	if v.State == S.Idle and not v.Down then
		p.arms = v.Variant % 2
		p.bob = math.sin(now * 4.2 + v.Variant) * 0.05 * v.Rig.Scale
		p.look = 0.05
	elseif fighting and not v.Down then
		p.guard = 0.75
		p.lean = 0.06
	end
	if v.Hop then
		local t = now - v.Hop
		if t < 0.3 then p.bob = (p.bob or 0) + math.sin(t / 0.3 * math.pi) * 0.7 * v.Rig.Scale else v.Hop = nil end
	end
	if v.State == S.Windup and not v.Down then
		p.windup = math.clamp((now - v.Since) / math.max(0.1, kind.Windup), 0, 1)
		p.twist = -0.35 * p.windup
		p.lean = 0.12 - 0.1 * p.windup
	end
	if v.Punch then
		local t = now - v.Punch
		if t < 0.45 then
			p.punch = t < 0.08 and t / 0.08 or math.max(0, 1 - (t - 0.08) / 0.37)
			p.twist = 0.3 * p.punch
			p.lean = 0.12 + 0.18 * p.punch
			p.windup = 0
		else
			v.Punch = nil
		end
	end
	if v.Spawned then
		local t = now - v.Spawned
		if t < 0.3 then p.bob = (p.bob or 0) - (1 - t / 0.3) * 1.2 * v.Rig.Scale else v.Spawned = nil end
	end
	if v.Down then
		local t = now - (v.KO or now)
		p.ko = math.min(1, t / 0.32)
		p.ko = 1 - (1 - p.ko) ^ 3 -- (falls fast, lands)
		if v.Stars then v.Stars:spin(t) end
		if t > 0.95 then poof(v); return end
	end
	local at = toWorld(v.Pos, v.Y or 0) * CFrame.Angles(0, v.Yaw, 0)
	if v.PuffIn then
		v.PuffIn = nil
		puffAt(at.Position + Vector3.new(0, 2 * v.Rig.Scale, 0), v.Rig.Scale, 5)
	end
	GoonRig.pose(v.Rig, at, p)
	if v.Tag then
		local on = not v.Down and (v.Stage == current or v.State ~= S.Idle or v.Hp < v.Max or v.Refill ~= nil)
		if v.Tag.Gui.Enabled ~= on then v.Tag.Gui.Enabled = on end
		if on then
			v.Tag.set(tagHp(v, now), v.Max)
			-- (LOOP) A crew's tags all say "Goon N", and in a group they stacked into "Goon 1Goon 1": only the goon your
			-- gun is on (and the Boss) shows its name; the rest show just their HP bar.
			local named = v.Kind == 'Boss' or (v.Stage == current and v.Index == sticky)
			if v.Tag.Name and v.Tag.Name.Visible ~= named then v.Tag.Name.Visible = named end
			-- (LOOP) The tag is sized in studs, so a goon right by the camera (between it and you) had a bar filling the
			-- screen: inside TAG_NEAR studs of the camera it shrinks, never bigger on screen than it is at TAG_NEAR.
			local cam = workspace.CurrentCamera
			if cam and v.Rig and v.Rig.Head then
				local k = math.clamp((v.Rig.Head.Position - cam.CFrame.Position).Magnitude / TAG_NEAR, 0.25, 1)
				if math.abs(k - (v.TagK or 1)) > 0.02 then
					v.TagK = k
					local size = FightUI.TagSize or Vector2.new(4.6, 1.55)
					v.Tag.Gui.Size = UDim2.fromScale(size.X * k, size.Y * k)
				end
			end
		end
	end
end

-- Which goons to draw: the crews near the camera (your fight, the next stage's crew waiting behind its gate); the rest
-- are not built (or are put away) so nobody pays for goons out of sight.
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
		local want = learning and inFight() and not autoFight() and now - last > HINT_IDLE
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
				local dying = v.Down and v.KO and now - v.KO <= 1
				local show = near and (not v.Down or dying)
				if show and not v.Rig and not v.Down then buildRig(v) end
				if not show and v.Rig then dropRig(v) end
				if v.Rig then
					local busy = v.State ~= S.Idle or v.Down or v.Hop or v.Punch or v.Spawned or v.Refill or v.PuffIn or math.abs(v.FlinchV) > 1e-2 or math.abs(v.Flinch) > 1e-2
					if busy or idleFrame then draw(v, busy and dt or 1 / 15, now, you) end
				end
			end
		end
	end
	if gainCombo and gainCombo.alive and gainCombo.part and r then
		local camRight = cam.CFrame.RightVector
		gainCombo.part.CFrame = CFrame.new(r.Position + camRight * 2.4 + Vector3.new(0, 2.6, 0))
	end
	-- Face the goon you shoot while you fire (you can still strafe and back off).
	local h = humanoid()
	if h and r then
		local facing = aimed and now < aimUntil and not aimed.Down and aimed.Rig
		if facing then
			if h.AutoRotate then h.AutoRotate = false; h:SetAttribute('WaveAim', true) end
			local look = toWorld(aimed.Pos).Position
			local yaw = yawTo(r.Position, look)
			if yaw then r.CFrame = CFrame.new(r.Position) * CFrame.Angles(0, yaw, 0) end
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
	button.Visible = on
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
-- a knocked-out goon (or one caught out of place) pops back in on its spot if its crew is drawn again right away. The
-- crews in `keep` are still walking home, whole again: they walk on (their Restored 'Wave' follows).
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
	local stage = info.Stage
	if info.Kind == 'Wave' then
		onWave(info)
		return
	end
	local drawn = waves[stage] ~= nil
	local w = waveOf(stage)
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
			if info.HP <= 0 then knockOut(v, true) elseif v.Tag then v.Tag.set(shownHp(v), v.Max) end
		end
	elseif info.Kind == 'Punch' and type(info.Index) == 'number' then
		local v = w.Goons[info.Index]
		if v and not v.Down then
			v.Punch = os.clock()
			if info.Landed then swipe(v) end
		end
	elseif info.Kind == 'KO' then
		koBanner()
		table.clear(held)
		aimed = nil
	elseif info.Kind == 'Cleared' then
		w.Cleared = true
		local reward = type(info.Reward) == 'number' and info.Reward or 0
		pill.clear(reward > 0 and ('+' .. Format.compact(reward) .. ' Cash') or nil)
		-- "CLEAR!" holds a moment, then goes (unless a wave comes back first)
		local token = os.clock() + 2.4
		clearUntil = token
		task.delay(2.45, function()
			if clearUntil == token and ((player:GetAttribute('WaveLeft') or 0) == 0 or current == 0) then pill.hide() end
		end)
		local r = rootPart()
		if r then Juice.shards(r.Position + Vector3.new(0, 3, 0), Kit.hex('FFC21A'), 'confetti') end
	end
end)

gui:GetPropertyChangedSignal('AbsoluteSize'):Connect(function() fit(gui.AbsoluteSize) end)
gui.Parent = player:WaitForChild('PlayerGui')
fit(gui.AbsoluteSize)
refresh()
