-- Shooting at the ranges (brief 18: "make your gun shoot on its own when you step on it"): step into an open lane's
-- shooter's box and your gun (the gun tool GunService gives you) comes out and fires by itself, ShotRules.AutoRate
-- shots a second, until you step off. Nobody clicks and nothing is sent: the server pays the same shots on its own
-- clock (LobbyService). Each shot is worth the lane x your rebirths (the ShotBase attribute) x your gun x your shoes
-- (ShotRules). Everything you see is local and cheap: a muzzle flash, a tracer to the target, sparks, the target
-- knocked back (a can flying off, a bottle shattering, a plate swinging, a disc spinning, a balloon popping into
-- confetti), a shell casing, a little recoil, and one running "+N" over the target per lane (the stream of shots rolls
-- it up and counts the hits). A locked lane doesn't fire. Leaving the lane puts the gun away again (and the hip
-- holster comes back: Armory.client). Other players near you firing at their lanes show too (muzzle, tracer, knock).
-- Sounds only with Config/Sound.Enabled.
local Players = game:GetService('Players')
local RunService = game:GetService('RunService')
local RS = game:GetService('ReplicatedStorage')
local ActiveMap = require(RS.Shared.ActiveMap)
local Juice = require(RS.Shared.Juice)
local Format = require(RS.Shared.Format)
local Guns = require(RS.Shared.Config.Guns)
local ShotRules = require(RS.Shared.ShotRules)
local GunTool = require(RS.Shared.GunTool)

local player = Players.LocalPlayer

---------------------------------------------------------------------------------------------- sounds
-- Layered built-in shot and hit sounds through the 'Shots' SoundGroup (ShotSounds), only while sounds are on
-- (Config/Sound: off for now).
local Sound = require(RS.Shared.Config.Sound)
local ShotSounds = Sound.Enabled and require(RS.Shared.ShotSounds) or nil
if ShotSounds then ShotSounds.init() end
local function play(kind, pitch) if ShotSounds then ShotSounds.play(kind, pitch) end end
-- An attachment's world frame (the same as WorldCFrame, spelled out so offline checks can run this file).
local function worldOf(att) return att.Parent.CFrame * att.CFrame end
local active = ActiveMap.wait(20)
if not active then return end

---------------------------------------------------------------------------------------------- stations
-- Each range's targets, read once per station model (and again if the model is rebuilt or streams back in).
local stations, missing = {}, {}
local function station(id)
	local s = stations[id]
	if s and s.Model.Parent then return s end
	if (missing[id] or 0) > os.clock() then return nil end
	local model = active.Lobby:FindFirstChild('Training_' .. id, true)
	if not model then
		missing[id] = os.clock() + 5 -- (not built or streamed out: look again in a while)
		return nil
	end
	s = { Model = model, Targets = {}, Main = nil, Turn = 0, Tier = model:GetAttribute('Tier') or (id == 'Ring' and 9) or 1 }
	local equipment = model:FindFirstChild('Equipment')
	for _, d in (equipment and equipment:GetDescendants() or {}) do
		if d:IsA('Model') and d:GetAttribute('Knock') then
			local entry = { Model = d, Aim = d:GetAttribute('Aim'), Knocker = Juice.knocker(d) }
			if typeof(entry.Aim) ~= 'Vector3' then entry.Aim = d:GetPivot().Position end
			table.insert(s.Targets, entry)
			if d:GetAttribute('Main') then s.Main = entry end
		end
	end
	-- Older stations (no targets): aim at the HitPoint, or the middle of the equipment.
	if #s.Targets == 0 then
		local hit = model:GetAttribute('HitPoint')
		if typeof(hit) ~= 'Vector3' then hit = equipment and equipment:GetPivot().Position or model:GetPivot().Position end
		s.Main = { Model = equipment or model, Aim = hit }
		s.Targets = { s.Main }
	end
	s.Main = s.Main or s.Targets[1]
	stations[id] = s
	return s
end
-- Every other shot goes to the main target, the others take turns, and a target that is away (popped, shattered,
-- flown off: it grows back in a moment) is skipped (ShotRules.pick).
local function present(t) return not t.Knocker or t.Knocker:present() end
local function nextTarget(s) return ShotRules.pick(s, s.Targets, s.Main, present) end

---------------------------------------------------------------------------------------------- the gun
local function training()
	local id = player:GetAttribute('TrainingStation') or ''
	return ShotRules.counts(id) and id or nil
end
local function humanoid()
	local c = player.Character
	return c and c:FindFirstChildOfClass('Humanoid')
end
local function heldGun()
	return player.Character and GunTool.held(player.Character) or nil
end
-- On a range the gun comes out by itself; when you leave, it goes back if it was us who took it out.
local autoEquipped = false
local function refreshEquip()
	local h = humanoid()
	if not h or h.Health <= 0 then return end
	if training() then
		local tool = GunTool.find(player)
		if tool and tool.Parent ~= player.Character then
			h:EquipTool(tool)
			autoEquipped = true
		end
	elseif autoEquipped then
		autoEquipped = false
		if heldGun() then h:UnequipTools() end
	end
end
player:GetAttributeChangedSignal('TrainingStation'):Connect(refreshEquip)
-- The tool can arrive after you step on (GunService gives it on spawn and swaps it when you change guns).
player.DescendantAdded:Connect(function(d)
	if d:IsA('Tool') then task.defer(refreshEquip) end -- (its GunId attribute is set before it is parented)
end)
player.CharacterAdded:Connect(function() task.defer(refreshEquip) end)

-- Recoil: the gun kicks up and back in the hand (Tool.Grip) and springs home.
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

-- Idle life on every lane near the camera (everyone sees it): plates sway, spinners turn, balloons bob.
local Skins = require(RS.Shared.Config.Skins)
local IDLE_RANGE = 90
local idleCheck, near = 0, {}
RunService.PreRender:Connect(function()
	local camera = workspace.CurrentCamera
	if not camera then return end
	if os.clock() > idleCheck then
		-- (Which lanes are near is re-checked twice a second.)
		idleCheck = os.clock() + 0.5
		table.clear(near)
		for _, row in Skins.Stations do
			local s = station(row.Id)
			if s and (s.Model:GetPivot().Position - camera.CFrame.Position).Magnitude < IDLE_RANGE then table.insert(near, s) end
		end
	end
	for _, s in near do
		for _, t in s.Targets do
			if t.Knocker and t.Knocker.idle then t.Knocker:pose() end
		end
	end
end)

---------------------------------------------------------------------------------------------- shooting
-- One shot's show (the server pays it on its own clock: LobbyService). Nothing is sent.
local shoeCarry = {} -- (the shoes' fraction of a shot, carried like the server does: ShotRules.pay)
local function shoot(id)
	local tool = heldGun()
	local c = player.Character
	local root = c and c:FindFirstChild('HumanoidRootPart')
	if not root then return end
	local gun = Guns.ById[tool and tool:GetAttribute('GunId') or player:GetAttribute('EquippedGun') or ''] or Guns.List[1]
	local gunPower = 0.9 + gun.Tier * 0.1
	local rig = tool and Juice.gunRig(tool)
	local from = rig and worldOf(rig.muzzle).Position or (root.Position + Vector3.new(0, 1.2, 0))
	local s = station(id)
	if not s then return end
	local target, there = nextTarget(s)
	local to = target.Aim + Vector3.new((math.random() - 0.5) * 0.5, (math.random() - 0.5) * 0.5, 0)
	-- Turn to face what you shoot (only while standing still, so walking is never fought).
	local h = humanoid()
	if h and h.MoveDirection.Magnitude < 0.1 then
		local look = Vector3.new(to.X, root.Position.Y, to.Z)
		if (look - root.Position).Magnitude > 0.5 then root.CFrame = CFrame.lookAt(root.Position, look) end
	end
	if rig then from = worldOf(rig.muzzle).Position end
	-- (Bigger guns sound a little deeper.)
	play('Shot', 1.1 - gun.Tier * 0.04)
	Juice.muzzle(rig, gun.Color, gunPower)
	Juice.tracer(from, to, gun.Color, 0.18 + gun.Tier * 0.015)
	if rig and rig.eject then Juice.casing(worldOf(rig.eject)) end
	if tool then kick(tool, 0.8 + gun.Tier * 0.05) end
	Juice.kick(0.05 + gun.Tier * 0.01) -- (a touch softer than a held trigger used to be: it never stops now)
	local color = s.Model:GetAttribute('HitColor') or gun.Color
	Juice.burst(to, color, 0.7 + s.Tier * 0.07)
	if there then
		if target.Knocker then target.Knocker:hit(1) end
		local hit = target.Model:GetAttribute('Hit') or 'Ding'
		-- A steel ding rises in pitch lane by lane (0.53 to 0.78 of the stage chime's).
		play(hit, hit == 'Ding' and (1 + 0.07 * s.Tier) or 1)
		Juice.flash(target.Model)
	end
	local gain = ShotRules.pay(player:GetAttribute('ShotBase'), player:GetAttribute('GunMultiplier'), player:GetAttribute('ShoeMultiplier'), shoeCarry)
	-- One running "+N" per lane over the main target's top edge and to its right (the stream of shots rolls it up and
	-- counts the hits instead of piling numbers on the target): white outlined in a dark shade of the lane's colour,
	-- bigger on the top lanes.
	s.ComboAt = s.ComboAt or Juice.comboAt(s.Main.Model, s.Model)
	Juice.combo(s.Model, s.ComboAt, gain, { color = color, big = s.Tier >= 5, format = Format.compact })
end

-- The auto-fire clock (brief 18): while you stand in an open lane the gun fires ShotRules.AutoRate times a second by
-- itself, the first shot at once; a locked lane or stepping off stops it. The server pays the same shots on its clock.
local due, wasIn = 0, nil
RunService.PreRender:Connect(function(dt)
	local id = training()
	if not id then
		due, wasIn = 0, nil
		return
	end
	if wasIn ~= id then
		wasIn = id
		due = 1 -- (the first shot as you step on)
	else
		due += dt * ShotRules.AutoRate
	end
	-- (the gun may still be coming out: wait for it, a shot without a gun in hand looks wrong)
	if not heldGun() then
		due = math.min(due, 1)
		return
	end
	local shots = math.min(math.floor(due), 2)
	if shots >= 1 then
		due -= shots
		for _ = 1, shots do shoot(id) end
	end
end)

---------------------------------------------------------------------------------------------- everyone else
-- The other players at the ranges fire too, on your screen (their TrainingStation attribute is everyone's to read): a
-- muzzle flash, a tracer to their lane's target and its knock, a little slower than your own and without their "+N", so a
-- hall full of players reads busy. Only players near your camera, a few at most.
local OTHERS_RANGE, OTHERS_MAX, OTHERS_RATE = 90, 6, 2.5
local others, othersCheck = {}, 0
local function shootFor(other, id)
	local c = other.Character
	local root = c and c:FindFirstChild('HumanoidRootPart')
	local s = station(id)
	if not root or not s then return end
	local tool = GunTool.held(c)
	if not tool then return end
	local gun = Guns.ById[tool:GetAttribute('GunId') or ''] or Guns.List[1]
	local rig = Juice.gunRig(tool)
	local target, there = nextTarget(s)
	local to = target.Aim + Vector3.new((math.random() - 0.5) * 0.5, (math.random() - 0.5) * 0.5, 0)
	local from = rig and worldOf(rig.muzzle).Position or (root.Position + Vector3.new(0, 1.2, 0))
	Juice.muzzle(rig, gun.Color, 0.8 + gun.Tier * 0.08)
	Juice.tracer(from, to, gun.Color, 0.15 + gun.Tier * 0.012)
	if there and target.Knocker then target.Knocker:hit(0.8) end
end
RunService.PreRender:Connect(function(dt)
	local camera = workspace.CurrentCamera
	if not camera then return end
	othersCheck -= dt
	if othersCheck <= 0 then
		-- (who is near and firing, looked at four times a second)
		othersCheck = 0.25
		local list = {}
		for _, other in Players:GetPlayers() do
			local id = other ~= player and other:GetAttribute('TrainingStation')
			local c = other.Character
			local root = c and c:FindFirstChild('HumanoidRootPart')
			if id and ShotRules.counts(id) and root and (root.Position - camera.CFrame.Position).Magnitude < OTHERS_RANGE then
				table.insert(list, { player = other, id = id, d = (root.Position - camera.CFrame.Position).Magnitude })
			end
		end
		table.sort(list, function(a, b) return a.d < b.d end)
		local keep = {}
		for i = 1, math.min(#list, OTHERS_MAX) do
			local e = list[i]
			local was = others[e.player]
			keep[e.player] = { id = e.id, due = was and was.id == e.id and was.due or math.random() }
		end
		others = keep
	end
	for other, e in others do
		e.due += dt * OTHERS_RATE
		if e.due >= 1 then
			e.due -= 1
			shootFor(other, e.id)
		end
	end
end)
