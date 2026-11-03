--!strict
-- Guns on the client (Piece 5): input, aim camera, firing with instant local effects, recoil, crosshair,
-- hitmarkers, ammo HUD, weapon bar, touch + gamepad, and other players' shot effects.
-- The server decides everything (GunService); this side predicts the ammo counter and draws.
--
-- Controls
--   PC       1-5 take out a gun (same key again or X puts it away) · LMB fire · hold RMB aim · R reload
--   Gamepad  Y next gun (after the last = holster) · R2 fire · L2 aim · B reload
--   Touch    weapon bar at the bottom · FIRE (hold) · AIM (toggle) · R
-- Phone: while the phone is open (or was closed this instant by a click on the world) guns don't fire or aim,
-- and opening it drops the aim. Cutscenes (UIState lockControls) drop the aim and put live guns away.
--
-- API (Master Plan §3.6)
--   GunController.equipped() -> gunId?          GunController.isAiming() -> bool
--   GunController.mode() -> "Live"|"Intimidate"|nil   GunController.state() -> last GunState
--   GunController.equip(gunId) / GunController.holster()   (asks the server)
--   GunController.Changed: Signal()             equip / holster / aim changes
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")

local Net = require(ReplicatedStorage.MTL.Net)
local Signal = require(ReplicatedStorage.MTL.Signal)
local Guns = require(ReplicatedStorage.MTL.Config.Guns)
local GunRules = require(ReplicatedStorage.MTL.Rules.GunRules)
local Theme = require(ReplicatedStorage.MTL.UI.Theme)
local Build = require(ReplicatedStorage.MTL.UI.Build.Gun)
local UIState = require(script.Parent.UIState)
local ClientData = require(script.Parent.ClientData)
local GunFX = require(script.Parent.GunFX)
local GunPose = require(script.Parent.GunPose)
local MovementController = require(script.Parent.MovementController)
local Juice = require(script.Parent.Juice)
local CamShake = require(script.Parent.CamShake)
local DownedPose = require(script.Parent.DownedPose)

local T = Guns.Tuning
local Feel = Guns.Feel
local G = Theme.Gun
local C = Theme.Colors

local GunController = {}
GunController.Changed = Signal.new()

local player = Players.LocalPlayer
local rng = Random.new()

-- server truth
local serverState: any = { guns = {} }
-- local (predicted) state of the gun in hand
local equipped: string? = nil
local mode: string? = nil
local def: any = nil
local mag = 0
local reserve = 0
local equipAt = 0
local reloadUntil = 0
local reloadStart = 0
local pendingServer: any = nil -- server state that arrived mid-reload (applied when it ends)
-- input
local trigger = false
local semiQueued = -1
local aimHeld = false
local aimToggle = false
local aiming = false
local nextShot = 0
local bloom = 0
local shots = 0
local hipTurnUntil = 0
local phoneClosedAt = -1
local lastAimSend = 0
local lastAimSent: any = {}
local intimidateTarget: Model? = nil
-- camera
local pitchSpring = { x = 0, v = 0 }
local yawSpring = { x = 0, v = 0 }
local lastPitch, lastYaw = 0, 0
local stayPitch, stayYaw = 0, 0
local assistPitch, assistYaw, assistLeft = 0, 0, 0
local camTween: Tween? = nil
local offTween: Tween? = nil
local mouseHidden = false
local turnedOff = false -- we switched Humanoid.AutoRotate off to face the aim
-- ui
local gui: ScreenGui
local hitUntil = 0

---------------------------------------------------------------- helpers

local Phone: any = nil
local Jobs: any = nil
local function lazy()
	if not Phone then
		local m = script.Parent:FindFirstChild("PhoneController")
		if m then
			local ok, p = pcall(require, m)
			Phone = if ok then p else false
		end
	end
	if not Jobs then
		local m = script.Parent:FindFirstChild("JobController")
		if m then
			local ok, j = pcall(require, m)
			Jobs = if ok then j else false
		end
	end
end

local function phoneOpen(): boolean
	return Phone and Phone.isOpen and Phone.isOpen() or false
end

local function onShift(): boolean
	local s = Jobs and Jobs.state and Jobs.state()
	return type(s) == "table" and s.onShift == true
end

local function char(): (Model?, Humanoid?, BasePart?)
	local c = player.Character
	if not c then
		return nil, nil, nil
	end
	return c, c:FindFirstChildOfClass("Humanoid"), c:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function gunModel(c: Model?): Model?
	local m = c and c:FindFirstChild("MTL_Gun")
	return if m and m:IsA("Model") then m else nil
end

local function blocked(): boolean
	if phoneOpen() or os.clock() - phoneClosedAt < 0.2 then
		return true
	end
	local ui = UIState.get()
	if ui.lockControls or ui.hideHUD then
		return true
	end
	if UserInputService:GetFocusedTextBox() then
		return true
	end
	local c, hum = char()
	return not hum or hum.Health <= 0 or (c ~= nil and c:GetAttribute("MTL_Downed") == true)
end

local function reducedMotion(): boolean
	local d = ClientData.get()
	return d ~= nil and d.Settings ~= nil and d.Settings.ReducedMotion == true
end

local function usesMouse(): boolean
	local last = UserInputService:GetLastInputType()
	return UserInputService.MouseEnabled and not (last == Enum.UserInputType.Touch or string.find(last.Name, "Gamepad") ~= nil)
end

local function reloading(): boolean
	return os.clock() < reloadUntil
end

function GunController.equipped(): string?
	return equipped
end
function GunController.mode(): string?
	return mode
end
function GunController.isAiming(): boolean
	return aiming
end
function GunController.state(): any
	return serverState
end

function GunController.equip(gunId: string)
	Net.get("GunAction"):FireServer({ type = "equip", gun = gunId })
end

function GunController.holster(reason: string?)
	if equipped then
		Net.get("GunAction"):FireServer({ type = "holster", reason = reason })
	end
end

---------------------------------------------------------------- raycasts

local castParams = RaycastParams.new()
castParams.FilterType = Enum.RaycastFilterType.Exclude
castParams.IgnoreWater = true

-- Ray that passes through non-colliding scenery (zones, decor) but stops on characters (any part) and walls.
-- Accessories resolve to the body part they're worn on.
local function cast(origin: Vector3, vector: Vector3): (RaycastResult?, BasePart?)
	local c = player.Character
	local ignore: { Instance } = { GunFX.folder() }
	if c then
		table.insert(ignore, c)
	end
	for _ = 1, 6 do
		castParams.FilterDescendantsInstances = ignore
		local r = Workspace:Raycast(origin, vector, castParams)
		if not r then
			return nil, nil
		end
		local inst = r.Instance
		local acc = inst:FindFirstAncestorOfClass("Accessory")
		if acc then
			local w = inst:FindFirstChild("AccessoryWeld") :: any
			local body = w and (if w.Part0 == inst then w.Part1 else w.Part0)
			if body and body:IsA("BasePart") then
				return r, body
			end
			table.insert(ignore, acc)
		elseif GunFX.isCharacterPart(inst) then
			return r, inst :: BasePart
		elseif not inst.CanCollide then
			table.insert(ignore, inst)
		else
			return r, nil
		end
	end
	return nil, nil
end

-- Where on screen the shot goes: the crosshair (centre) when aiming / on touch / on gamepad, else the mouse.
local function aimScreenPoint(): Vector2
	local cam = Workspace.CurrentCamera
	if aiming or not usesMouse() then
		return cam.ViewportSize / 2
	end
	return UserInputService:GetMouseLocation()
end

local function threatModel(model: Model?): boolean
	if not model or not equipped then
		return false
	end
	if CollectionService:HasTag(model, "MTL_Intimidate") then
		return true
	end
	if mode ~= "Live" then
		return false
	end
	local other = Players:GetPlayerFromCharacter(model)
	if other then
		return other ~= player and other:GetAttribute("MTL_Path") == "Criminal" and player:GetAttribute("MTL_Path") == "Criminal"
	end
	return model:GetAttribute("MTL_Damageable") == true
end

local function modelOf(inst: Instance?): Model?
	local cur = inst
	while cur and cur ~= Workspace do
		if cur:IsA("Model") and cur:FindFirstChildOfClass("Humanoid") then
			return cur
		end
		cur = cur.Parent
	end
	return nil
end

---------------------------------------------------------------- HUD

local function ui(path: string): any
	local cur: any = gui
	for name in string.gmatch(path, "[^/]+") do
		cur = cur and cur:FindFirstChild(name)
	end
	return cur
end

local function placeAmmo()
	-- sit just left of the phone (it lives bottom-right); fall back to the built-in position
	local ammo = ui("Ammo")
	local pg = player:FindFirstChild("PlayerGui")
	local phone = pg and pg:FindFirstChild("MTL_Phone")
	local body = phone and phone:FindFirstChild("Body", true) :: GuiObject?
	if ammo and body and body:IsA("GuiObject") and body.AbsoluteSize.X > 0 then
		local cam = Workspace.CurrentCamera
		local x = body.AbsolutePosition.X - 16 - (cam.ViewportSize.X)
		ammo.Position = UDim2.new(1, math.min(-200, x), 1, -24)
	end
end

local function slotKeyLabel(i: number): string
	if UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled then
		return ""
	end
	return tostring(i)
end

local function refreshBar()
	local bar = ui("WeaponBar")
	if not bar then
		return
	end
	local template = bar:FindFirstChild("SlotTemplate")
	local want: { [string]: boolean } = {}
	for i, g in serverState.guns or {} do
		want["Slot_" .. g.id] = true
		local slot = bar:FindFirstChild("Slot_" .. g.id)
		if not slot and template then
			slot = template:Clone()
			slot.Name = "Slot_" .. g.id
			slot.Visible = true
			slot.Parent = bar
			local id = g.id
			slot.Activated:Connect(function()
				if equipped == id then
					GunController.holster()
				else
					GunController.equip(id)
				end
			end)
		end
		if slot then
			local gdef = Guns.Defs[g.id]
			slot.LayoutOrder = i
			slot.Key.Text = slotKeyLabel(i)
			slot.Title.Text = if gdef then gdef.Display else g.id
			local m = if g.id == equipped then mag else g.mag
			local r = if g.id == equipped then reserve else g.reserve
			slot.Count.Text = if g.mode == "Intimidate" then "story" else (tostring(m) .. " / " .. tostring(r))
			local active = g.id == equipped
			local stroke = slot:FindFirstChild("Stroke") :: UIStroke?
			if stroke then
				stroke.Color = if active then G.SlotActive else C.Stroke
				stroke.Transparency = if active then 0 else C.StrokeTransparency
				stroke.Thickness = if active then 2 else 1
			end
		end
	end
	for _, child in bar:GetChildren() do
		if child:IsA("GuiObject") and child.Name ~= "SlotTemplate" and not want[child.Name] then
			child:Destroy()
		end
	end
	bar.Visible = #(serverState.guns or {}) > 0
end

local function refreshAmmo()
	local ammo = ui("Ammo")
	if not ammo then
		return
	end
	ammo.Visible = equipped ~= nil
	if not equipped or not def then
		return
	end
	ammo.Gun.Text = string.upper(def.Display)
	ammo.Mag.Text = tostring(mag)
	ammo.Reserve.Text = "/ " .. tostring(reserve)
	ammo.Mag.TextColor3 = if mag == 0 then G.Empty elseif mag <= math.ceil(def.Mag * 0.3) then G.Low else C.Text
	local help = ""
	if mag == 0 and reserve == 0 then
		help = if mode == "Live" then "Out of ammo. Get more in the Plug app." else "Out of ammo"
	elseif mag <= math.ceil(def.Mag * 0.3) and reserve > 0 and not reloading() then
		help = if usesMouse() then "R to reload" elseif UserInputService.TouchEnabled then "Tap R to reload" else "B to reload"
	end
	ammo.Help.Text = help
	refreshBar()
end

local function showHitmarker(head: boolean, kill: boolean)
	local hm = ui("Hitmarker")
	if not hm then
		return
	end
	local color = if kill then G.Kill elseif head then G.HitHead else G.Hit
	for _, b in hm:GetChildren() do
		if b:IsA("Frame") then
			b.BackgroundColor3 = color
		end
	end
	local size = if kill then 38 else 28
	hm.Size = UDim2.fromOffset(size * 0.7, size * 0.7)
	hm.Position = UDim2.fromOffset(aimScreenPoint().X, aimScreenPoint().Y)
	hm.Visible = true
	TweenService:Create(hm, TweenInfo.new(0.08, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Size = UDim2.fromOffset(size, size) }):Play()
	hitUntil = os.clock() + T.HitmarkerSeconds * (if kill then 2.5 else 1)
end

local function hurtFlash(from: Vector3?)
	local cam = Workspace.CurrentCamera
	local edge = "Bottom"
	if from then
		local v = cam.CFrame:VectorToObjectSpace(from - cam.CFrame.Position)
		if math.abs(v.X) > math.abs(v.Z) then
			edge = if v.X < 0 then "Left" else "Right"
		else
			edge = if v.Z < 0 then "Top" else "Bottom"
		end
	end
	local hurt = ui("Hurt")
	if not hurt then
		return
	end
	for _, f in hurt:GetChildren() do
		if f:IsA("Frame") then
			f.BackgroundTransparency = if f.Name == edge then 0.15 else 0.75
			TweenService:Create(f, TweenInfo.new(T.HurtSeconds, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { BackgroundTransparency = 1 }):Play()
		end
	end
	CamShake.add(Feel.Hurt)
end

---------------------------------------------------------------- aim on / off

local function setMouseHidden(hide: boolean)
	if hide ~= mouseHidden then
		mouseHidden = hide
		UserInputService.MouseIconEnabled = not hide
	end
end

local function tweenCamera(fov: number, offset: Vector3)
	local cam = Workspace.CurrentCamera
	local _, hum = char()
	local info = TweenInfo.new(T.AimTween, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	if camTween then
		camTween:Cancel()
	end
	camTween = TweenService:Create(cam, info, { FieldOfView = fov })
	assert(camTween):Play()
	if hum then
		if offTween then
			offTween:Cancel()
		end
		offTween = TweenService:Create(hum, info, { CameraOffset = offset })
		assert(offTween):Play()
	end
end

local function firstPerson(): boolean
	local c = player.Character
	local head = c and c:FindFirstChild("Head") :: BasePart?
	return head ~= nil and (Workspace.CurrentCamera.CFrame.Position - head.Position).Magnitude < 1.6
end

local function startAimAssist()
	if usesMouse() or not equipped then
		return
	end
	local cam = Workspace.CurrentCamera
	local best, bestAngle = nil :: Vector3?, T.AimAssistDegrees
	local candidates: { Model } = {}
	for _, p in Players:GetPlayers() do
		if p ~= player and p.Character then
			table.insert(candidates, p.Character)
		end
	end
	for _, m in CollectionService:GetTagged("MTL_Intimidate") do
		if m:IsA("Model") then
			table.insert(candidates, m)
		end
	end
	for _, m in candidates do
		if threatModel(m) then
			local part = (m:FindFirstChild("UpperTorso") or m:FindFirstChild("Torso") or m:FindFirstChild("HumanoidRootPart")) :: BasePart?
			if part then
				local d = part.Position - cam.CFrame.Position
				if d.Magnitude <= T.AimAssistRange then
					local look = cam.CFrame.LookVector
					local a = GunRules.angle(look.X, look.Y, look.Z, d.X, d.Y, d.Z)
					if a < bestAngle then
						best, bestAngle = part.Position, a
					end
				end
			end
		end
	end
	if best then
		local v = cam.CFrame:VectorToObjectSpace(best - cam.CFrame.Position)
		assistYaw = math.deg(math.atan2(-v.X, -v.Z))
		assistPitch = math.deg(math.atan2(v.Y, math.sqrt(v.X * v.X + v.Z * v.Z)))
		assistLeft = T.AimAssistSeconds
	end
end

local function setAiming(on: boolean)
	if on == aiming then
		return
	end
	aiming = on
	if on and def then
		tweenCamera(def.AimFov, if firstPerson() then Vector3.zero else T.AimCameraOffset)
		MovementController.setModifier("Aim", T.AimWalkSpeedMult) -- also stops a sprint
		startAimAssist()
	else
		tweenCamera(T.BaseFov, Vector3.zero)
		MovementController.clearModifier("Aim")
		assistLeft = 0
	end
	GunController.Changed:Fire()
end

local function dropInput()
	trigger = false
	semiQueued = -1
	aimHeld = false
	aimToggle = false
	setAiming(false)
end

---------------------------------------------------------------- reload

local function startReload()
	if not equipped or not def or reloading() or not GunRules.canReload(mag, def.Mag, reserve) then
		return
	end
	reloadStart = os.clock()
	reloadUntil = reloadStart + def.Reload
	pendingServer = nil
	Net.get("GunReload"):FireServer({ gun = equipped })
	GunPose.reload(nil, def.Reload)
	local model = gunModel(player.Character)
	local style = GunPose.STYLES[def.Model or ""]
	task.delay(def.Reload * 0.1, function()
		if reloadUntil > 0 and os.clock() - reloadStart < def.Reload then
			GunFX.sound(model, "ReloadStart") -- mag out / cylinder open / first shell
		end
	end)
	if style and style.kind == "mag" then
		local started = reloadStart
		task.delay(def.Reload * 0.63, function()
			if reloadStart == started and reloadUntil > 0 then
				GunFX.sound(model, "ReloadEnd") -- mag seated
			end
		end)
	end
	local bar = ui("Ammo/Reload")
	if bar then
		bar.Visible = true
	end
	refreshAmmo()
end

local function finishReload()
	reloadUntil = 0
	if def then
		mag, reserve = GunRules.reload(mag, def.Mag, reserve)
	end
	local style = def and GunPose.STYLES[def.Model or ""]
	if not (style and style.kind == "mag") then
		GunFX.sound(gunModel(player.Character), "ReloadEnd") -- mag guns already played it when the mag went in
	end
	local bar = ui("Ammo/Reload")
	if bar then
		bar.Visible = false
	end
	if pendingServer then
		local p = pendingServer
		pendingServer = nil
		for _, g in p.guns or {} do
			if g.id == equipped then
				mag, reserve = g.mag, g.reserve
			end
		end
	end
	refreshAmmo()
end

---------------------------------------------------------------- firing

local function kickCamera()
	if not def then
		return
	end
	local scale = if reducedMotion() then T.ReducedMotionScale else 1
	local up, side = GunRules.recoilKick(def, rng:NextNumber() * 2 - 1, scale * (if aiming then 0.8 else 1))
	local stay, bounce = GunRules.recoilSplit(def, up)
	local sStay, sBounce = GunRules.recoilSplit(def, side)
	stayPitch += stay
	stayYaw += sStay
	pitchSpring.v += GunRules.kickVelocity(bounce, T.RecoilStiffness)
	yawSpring.v += GunRules.kickVelocity(sBounce, T.RecoilStiffness)
	GunPose.kick(def.Recoil.Kick, def.Recoil.KickRot)
end

local function fire()
	local c, hum = char()
	local model = gunModel(c)
	if not c or not hum or not equipped or not def or not model then
		return
	end
	local now = os.clock()
	if now < equipAt + def.EquipTime or reloading() then
		return
	end
	if mag <= 0 then
		GunFX.sound(model, "Empty")
		trigger = false
		if reserve > 0 then
			task.delay(T.AutoReloadDelay, startReload)
		end
		refreshAmmo()
		return
	end
	nextShot = now + GunRules.fireInterval(def)
	mag -= 1
	shots += 1

	local cam = Workspace.CurrentCamera
	local sp = aimScreenPoint()
	local camRay = cam:ViewportPointToRay(sp.X, sp.Y)
	local aimHit = cast(camRay.Origin, camRay.Direction * (def.Range + 30))
	local aimPoint = if aimHit then aimHit.Position else camRay.Origin + camRay.Direction * def.Range
	local head = c:FindFirstChild("Head") :: BasePart?
	local muzzle = GunFX.muzzlePosition(model) or (head and head.Position) or camRay.Origin
	local dir = aimPoint - muzzle
	if dir.Magnitude < 1.5 or dir.Unit:Dot(camRay.Direction) <= 0.2 then
		dir = camRay.Direction
	end
	dir = dir.Unit

	local spread = GunRules.spread(def, {
		aiming = aiming,
		moving = hum.MoveDirection.Magnitude > 0.1,
		airborne = hum.FloorMaterial == Enum.Material.Air,
		bloom = bloom,
	})
	local base = CFrame.lookAt(Vector3.zero, dir)
	local rays = {}
	local pellets = def.Pellets or 1
	for i = 1, pellets do
		local cone = spread + (if pellets > 1 then (def.PelletSpread or 0) else 0)
		local px, py = GunRules.coneOffset(cone, rng:NextNumber(), rng:NextNumber())
		local d = (base * CFrame.Angles(px, py, 0)).LookVector
		local r, body = cast(muzzle, d * def.Range)
		local pos = if r then r.Position else muzzle + d * def.Range
		rays[i] = { pos = pos, part = body }
		if i <= 4 and (pellets > 1 or (shots - 1) % (def.TracerEvery or 1) == 0) then
			GunFX.tracer(muzzle, pos)
		end
		if r then
			GunFX.impact(pos, r.Normal, r.Instance)
		end
	end
	Net.get("GunFire"):FireServer({ gun = equipped, origin = muzzle, dir = dir, t = Workspace:GetServerTimeNow(), rays = rays })

	GunFX.muzzle(model)
	GunFX.sound(model, "Fire")
	GunFX.sound(model, "Tail", 0.6)
	GunPose.fired()
	if def.Sounds and def.Sounds.Pump then
		task.delay(0.14, GunFX.sound, model, "Pump", 0.8)
	end
	kickCamera()
	CamShake.add(def.Shake or 0.12, def.ShakeCap)
	bloom = GunRules.bloomAfterShot(def, bloom)
	hipTurnUntil = now + T.HipTurnSeconds
	if not def.Auto then
		trigger = false
	end
	if mag == 0 and reserve > 0 then
		task.delay(T.AutoReloadDelay, startReload)
	end
	refreshAmmo()
end

---------------------------------------------------------------- server events

local function applyState(s: any)
	if type(s) ~= "table" then
		return
	end
	serverState = s
	local was = equipped
	equipped = s.equipped
	mode = s.mode
	if equipped ~= was then
		reloadUntil = 0
		pendingServer = nil
		GunPose.cancelReload()
		local bar = ui("Ammo/Reload")
		if bar then
			bar.Visible = false
		end
		if equipped then
			def = Guns.Defs[equipped]
			equipAt = os.clock()
			bloom = 0
			trigger = false
			-- the model arrives with the state; play the equip sound once it's there
			task.delay(0.05, function()
				GunFX.sound(gunModel(player.Character), "Equip", 0.7)
			end)
			if aimHeld or aimToggle then
				setAiming(true)
			end
		else
			def = nil
			dropInput()
		end
		GunController.Changed:Fire()
	end
	if equipped then
		for _, g in s.guns or {} do
			if g.id == equipped then
				if reloading() then
					pendingServer = s
				else
					mag, reserve = g.mag, g.reserve
				end
			end
		end
	end
	refreshAmmo()
	refreshBar()
end

local function otherShot(fx: any)
	local shooter = fx.shooter
	if typeof(shooter) ~= "Instance" or shooter == player or type(fx.ends) ~= "table" then
		return
	end
	local c = (shooter :: Player).Character
	local model = gunModel(c)
	local from = GunFX.muzzlePosition(model) or fx.origin
	if typeof(from) ~= "Vector3" then
		return
	end
	local gdef = Guns.Defs[fx.gun]
	GunFX.muzzle(model)
	GunFX.sound(model, "Fire")
	GunFX.sound(model, "Tail", 0.8)
	if c then
		GunPose.fired(c)
	end
	if gdef and gdef.Sounds and gdef.Sounds.Pump then
		task.delay(0.14, GunFX.sound, model, "Pump", 0.8)
	end
	for i, pos in fx.ends do
		if i > 4 or typeof(pos) ~= "Vector3" then
			break
		end
		if (gdef and (gdef.Pellets or 1) > 1) or i == 1 then
			GunFX.tracer(from, pos)
		end
		local d = pos - from
		if d.Magnitude > 0.5 then
			castParams.FilterDescendantsInstances = { GunFX.folder(), c :: Instance }
			local r = Workspace:Raycast(from, d + d.Unit * 0.6, castParams)
			if r and (r.Position - pos).Magnitude < 2 then
				GunFX.impact(r.Position, r.Normal, r.Instance)
			end
		end
	end
end

local function onFx(fx: any)
	if type(fx) ~= "table" then
		return
	end
	if fx.type == "shot" then
		otherShot(fx)
	elseif fx.type == "hit" then
		showHitmarker(fx.head == true, fx.kill == true)
		local hs = Feel.HitStop
		CamShake.hitStop(fx.model, if fx.kill then hs.Kill elseif fx.head then hs.Head else hs.Hit)
		if fx.kill then
			Juice.hit("Kill")
		end
		GunFX.ui(if fx.kill then Guns.Sounds.Kill else Guns.Sounds.Hit, if fx.kill then 0.6 else 0.45)
	elseif fx.type == "hurt" then
		hurtFlash(if typeof(fx.from) == "Vector3" then fx.from else nil)
		GunFX.ui(Guns.Sounds.Hurt, 0.5)
	elseif fx.type == "downed" then
		dropInput()
		CamShake.add(Feel.Downed)
		DownedPose.localDowned(if type(fx.seconds) == "number" then fx.seconds else Guns.Downed.BleedSeconds)
	elseif fx.type == "finish" then
		CamShake.add(Feel.Finish)
		CamShake.hitStop(fx.model, Feel.HitStop.Kill)
		Juice.hit("Kill")
	elseif fx.type == "reloadHint" then
		-- once, in the first robbery, right after the first shot
		local m = script.Parent:FindFirstChild("HUDController")
		local ok, hud = pcall(require, m :: any)
		if ok and hud and hud.toast then
			local key = if usesMouse() then "Press R to reload" elseif UserInputService.TouchEnabled then "Tap R to reload" else "Press B to reload"
			hud.toast(key, G.SlotActive)
		end
	end
end

---------------------------------------------------------------- per frame

local lowHealth: ColorCorrectionEffect? = nil

local function camStep(dt: number)
	local cam = Workspace.CurrentCamera
	-- recoil springs (bounce) + the part that stays (climb) + aim assist, applied as a delta to the camera
	GunRules.springStep(pitchSpring, T.RecoilStiffness, T.RecoilDamping, dt)
	GunRules.springStep(yawSpring, T.RecoilStiffness, T.RecoilDamping, dt)
	local take = math.clamp(dt * 30, 0, 1)
	local sp, sy = stayPitch * take, stayYaw * take
	stayPitch -= sp
	stayYaw -= sy
	local ap, ay = 0, 0
	if assistLeft > 0 then
		local share = math.clamp(dt / assistLeft, 0, 1)
		ap, ay = assistPitch * share, assistYaw * share
		assistPitch -= ap
		assistYaw -= ay
		assistLeft -= dt
	end
	local dPitch = (pitchSpring.x - lastPitch) + sp + ap
	local dYaw = (yawSpring.x - lastYaw) + sy + ay
	lastPitch, lastYaw = pitchSpring.x, yawSpring.x
	-- (hit / shot shake is Controllers/CamShake, applied after this and taken back out before the next frame)
	if math.abs(dPitch) > 1e-5 or math.abs(dYaw) > 1e-5 then
		cam.CFrame = cam.CFrame * CFrame.Angles(math.rad(dPitch), math.rad(dYaw), 0)
	end

	local c, hum, root = char()
	local now = os.clock()
	if equipped and c and hum and root and hum.Health > 0 then
		-- face where you aim (aiming, or briefly after a hip shot)
		local face = aiming or now < hipTurnUntil
		if face then
			hum.AutoRotate = false
			turnedOff = true
			local look = cam.CFrame.LookVector
			local flat = Vector3.new(look.X, 0, look.Z)
			if flat.Magnitude > 0.05 then
				root.CFrame = CFrame.lookAt(root.Position, root.Position + flat)
			end
		elseif turnedOff then
			hum.AutoRotate = true
			turnedOff = false
		end
		if aiming and usesMouse() and not phoneOpen() then
			UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
		end
		local pitch = math.deg(math.asin(math.clamp(cam.CFrame.LookVector.Y, -1, 1)))
		GunPose.setLocal(pitch, face)
	elseif turnedOff then
		turnedOff = false
		if hum then
			hum.AutoRotate = true -- put back what we took (only ours: other systems' AutoRotate is left alone)
		end
	end
end

local function frame(dt: number)
	local now = os.clock()
	if def then
		bloom = GunRules.bloomRecover(def, bloom, dt)
	end
	-- trigger
	if equipped and def and not blocked() then
		local wantAim = aimHeld or aimToggle
		if wantAim ~= aiming then
			setAiming(wantAim)
		end
		if now >= nextShot then
			if trigger then
				fire()
			elseif semiQueued > 0 and now - semiQueued <= T.SemiBuffer then
				semiQueued = -1
				trigger = true
				fire()
			end
		end
	elseif aiming then
		setAiming(false)
	end
	if reloadUntil > 0 and now >= reloadUntil then
		finishReload()
	end

	-- crosshair + hint
	local cam = Workspace.CurrentCamera
	local cross = ui("Crosshair")
	local hint = ui("Hint")
	local hidden = UIState.get().hideHUD == true
	local show = equipped ~= nil and def ~= nil and not phoneOpen() and not hidden
	local isMouse = usesMouse()
	setMouseHidden(show and isMouse)
	if cross then
		cross.Visible = show
		if show and def then
			local _, hum = char()
			local spread = GunRules.spread(def, {
				aiming = aiming,
				moving = hum ~= nil and hum.MoveDirection.Magnitude > 0.1,
				airborne = hum ~= nil and hum.FloorMaterial == Enum.Material.Air,
				bloom = bloom,
			}) + (if (def.Pellets or 1) > 1 then (def.PelletSpread or 0) else 0)
			local gap = math.clamp(GunRules.crosshairGap(spread, cam.FieldOfView, cam.ViewportSize.Y), 3, 120)
			local sp = aimScreenPoint()
			cross.Position = UDim2.fromOffset(sp.X, sp.Y)
			cross.Top.Position = UDim2.fromOffset(0, -gap - 4)
			cross.Bottom.Position = UDim2.fromOffset(0, gap + 4)
			cross.Left.Position = UDim2.fromOffset(-gap - 4, 0)
			cross.Right.Position = UDim2.fromOffset(gap + 4, 0)
			-- threat colour when the crosshair is on someone you can hurt / intimidate
			local ray = cam:ViewportPointToRay(sp.X, sp.Y)
			local r, body = cast(ray.Origin, ray.Direction * math.min(def.Range, 400))
			local m = modelOf(body or (r and r.Instance))
			local threat = threatModel(m)
			local color = if threat then G.CrosshairThreat else G.Crosshair
			for _, b in cross:GetChildren() do
				if b:IsA("Frame") then
					b.BackgroundColor3 = color
				end
			end
			intimidateTarget = if aiming and m and CollectionService:HasTag(m, "MTL_Intimidate") and r and (r.Position - ray.Origin).Magnitude <= T.IntimidateRange + 15 then m else nil
		else
			intimidateTarget = nil
		end
	end
	if hint then
		hint.Visible = show and intimidateTarget ~= nil
		hint.Text = if intimidateTarget then "Keep aiming..." else ""
		hint.TextColor3 = G.CrosshairThreat
		if cross and cross.Visible then
			hint.Position = UDim2.new(0, cross.Position.X.Offset, 0, cross.Position.Y.Offset + 34)
		end
	end
	local hm = ui("Hitmarker")
	if hm and hm.Visible and now >= hitUntil then
		hm.Visible = false
	end
	-- reload bar
	if reloadUntil > 0 and def then
		local fill = ui("Ammo/Reload/Fill")
		if fill then
			fill.Size = UDim2.fromScale(math.clamp((now - reloadStart) / def.Reload, 0, 1), 1)
		end
	end
	-- touch buttons
	local touch = ui("Touch")
	if touch then
		touch.Visible = show and UserInputService.TouchEnabled
		local aimBtn = touch:FindFirstChild("Aim")
		if aimBtn then
			aimBtn.BackgroundColor3 = if aimToggle then G.SlotActive else G.Panel
		end
	end
	local bar = ui("WeaponBar")
	if bar then
		bar.Visible = #(serverState.guns or {}) > 0 and not hidden
	end
	-- aim updates for the server (pose for others + intimidation)
	if equipped and now - lastAimSend >= 1 / T.AimSendHz then
		local pitch = math.floor(math.deg(math.asin(math.clamp(cam.CFrame.LookVector.Y, -1, 1))) + 0.5)
		local raised = aiming or now < hipTurnUntil
		if raised ~= lastAimSent.aiming or math.abs(pitch - (lastAimSent.pitch or 0)) >= 2 or intimidateTarget ~= lastAimSent.target or intimidateTarget then
			lastAimSend = now
			lastAimSent = { aiming = raised, pitch = pitch, target = intimidateTarget }
			Net.get("GunAim"):FireServer({ aiming = aiming, raised = raised, pitch = pitch, target = intimidateTarget })
		end
	end
end

---------------------------------------------------------------- input

local function keyIn(list: { Enum.KeyCode }, key: Enum.KeyCode): boolean
	for _, k in list do
		if k == key then
			return true
		end
	end
	return false
end

local function slotPressed(i: number)
	local g = (serverState.guns or {})[i]
	if not g then
		return
	end
	if equipped == g.id then
		GunController.holster()
	else
		GunController.equip(g.id)
	end
end

local function cycle()
	local list = serverState.guns or {}
	if #list == 0 then
		return
	end
	local idx = 0
	for i, g in list do
		if g.id == equipped then
			idx = i
		end
	end
	if idx >= #list then
		GunController.holster()
	else
		GunController.equip(list[idx + 1].id)
	end
end

local lastShiftHint = 0
local function shiftHint()
	if os.clock() - lastShiftHint < 3 then
		return
	end
	lastShiftHint = os.clock()
	local m = script.Parent:FindFirstChild("HUDController")
	local ok, hud = pcall(require, m :: any)
	if ok and hud and hud.toast then
		hud.toast("You're on shift: end it in the Jobs panel to use a gun")
	end
end

local function pressTrigger()
	if not equipped or blocked() then
		return
	end
	trigger = true
	if def and not def.Auto and os.clock() < nextShot then
		semiQueued = os.clock() -- a little early: fire as soon as the gun is ready
		trigger = false
	end
end

local function bindInput()
	local K = Guns.Keys
	UserInputService.InputBegan:Connect(function(input, processed)
		local t = input.UserInputType
		if t == Enum.UserInputType.MouseButton1 then
			if not processed then
				pressTrigger()
			end
			return
		elseif t == Enum.UserInputType.MouseButton2 then
			if not processed and equipped and not blocked() then
				aimHeld = true
			end
			return
		end
		local key = input.KeyCode
		if key == K.FireGamepad then
			pressTrigger()
			return
		elseif key == K.AimGamepad then
			if equipped and not blocked() then
				aimHeld = true
			end
			return
		end
		if processed or blocked() then
			return
		end
		if onShift() then
			-- guns stay away on a job shift; say so instead of doing nothing (play-test 2026-11-02)
			local owns = type(serverState.guns) == "table" and next(serverState.guns) ~= nil
			if owns and (keyIn(K.Cycle, key) or table.find(K.Slots, key)) then
				shiftHint()
			end
			return
		end
		if keyIn(K.Reload, key) then
			startReload()
		elseif keyIn(K.Holster, key) then
			GunController.holster()
		elseif keyIn(K.Cycle, key) then
			cycle()
		else
			for i, k in K.Slots do
				if k == key then
					slotPressed(i)
					break
				end
			end
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		local t = input.UserInputType
		if t == Enum.UserInputType.MouseButton1 or input.KeyCode == K.FireGamepad then
			trigger = false
		elseif t == Enum.UserInputType.MouseButton2 or input.KeyCode == K.AimGamepad then
			aimHeld = false
		end
	end)

	-- touch buttons
	local fireBtn = ui("Touch/Fire")
	if fireBtn then
		fireBtn.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
				pressTrigger()
			end
		end)
		fireBtn.InputEnded:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
				trigger = false
			end
		end)
	end
	local aimBtn = ui("Touch/Aim")
	if aimBtn then
		aimBtn.Activated:Connect(function()
			if equipped then
				aimToggle = not aimToggle
			end
		end)
	end
	local reloadBtn = ui("Touch/Reload")
	if reloadBtn then
		reloadBtn.Activated:Connect(startReload)
	end
end

---------------------------------------------------------------- init

function GunController.init()
	lazy()
	local pg = player:WaitForChild("PlayerGui")
	local existing = pg:FindFirstChild("MTL_Gun")
	if existing and existing:IsA("ScreenGui") then
		gui = existing
	else
		gui = Build.build()
		gui.Parent = pg
	end
	GunFX.init()
	GunPose.init()
	CamShake.init()
	DownedPose.init() -- after GunPose: its pose wins on downed characters
	bindInput()

	Net.get("GunState").OnClientEvent:Connect(applyState)
	Net.get("GunFx").OnClientEvent:Connect(onFx)

	RunService:BindToRenderStep("MTL_GunCamera", Enum.RenderPriority.Camera.Value + 1, camStep)
	RunService.RenderStepped:Connect(frame)

	if Phone then
		Phone.Opened:Connect(function()
			dropInput()
		end)
		Phone.Closed:Connect(function()
			phoneClosedAt = os.clock()
		end)
	end
	UIState.Changed:Connect(function(s)
		if s.lockControls or s.hideHUD then
			dropInput()
			if s.lockControls and s.hideHUD and mode == "Live" then
				GunController.holster("cutscene") -- full cutscene: live guns go away (story guns stay)
			end
		end
	end)

	-- low health: the screen drains of colour
	local function watchHealth(c: Model)
		local hum = c:WaitForChild("Humanoid", 10) :: Humanoid?
		if not hum then
			return
		end
		if not lowHealth or not lowHealth.Parent then
			local cc = Instance.new("ColorCorrectionEffect")
			cc.Name = "MTL_LowHealth"
			cc.Parent = Lighting
			lowHealth = cc
		end
		local function upd()
			local h = hum.Health
			local cc = lowHealth :: ColorCorrectionEffect
			local a = if h < T.LowHealth and h > 0 then 1 - h / T.LowHealth else 0
			TweenService:Create(cc, TweenInfo.new(0.3), { Saturation = -0.7 * a, Contrast = 0.1 * a }):Play()
		end
		hum.HealthChanged:Connect(upd)
		upd()
	end
	if player.Character then
		task.spawn(watchHealth, player.Character)
	end
	player.CharacterAdded:Connect(function(c)
		equipped, def, mode = nil, nil, nil
		dropInput()
		task.spawn(watchHealth, c)
	end)

	placeAmmo()
	Workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(placeAmmo)
	task.delay(2, placeAmmo) -- the phone lays itself out after boot

	-- ask for the current state (guns owned) once the save is in
	task.spawn(function()
		ClientData.waitReady()
		Net.get("GunAction"):FireServer({ type = "sync" })
	end)
end

return GunController
