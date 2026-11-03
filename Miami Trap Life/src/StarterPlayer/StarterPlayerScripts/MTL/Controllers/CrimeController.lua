--!strict
-- The crime loop on the client (server: CrimeService / CrimeJobs / PoliceService):
--   heat stars + the "lose them" bar, the dirty-cash pill, the crime tracker card, the stickup aim bar,
--   local ProximityPrompts from the server's per-player list (PromptController restyles them), the minigames
--   (JobMinigames on the MTL_Job screen), the wash bar, Marcus's shop, the BOOKED card, door fades,
--   police lightbars flashing, officers raising their guns, and police shot tracers.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local Net = require(ReplicatedStorage.MTL.Net)
local Theme = require(ReplicatedStorage.MTL.UI.Theme)
local Motion = require(ReplicatedStorage.MTL.UI.Motion)
local Rig = require(ReplicatedStorage.MTL.Rig)
local Crime = require(ReplicatedStorage.MTL.Config.Crime)
local CrimeRules = require(ReplicatedStorage.MTL.Rules.CrimeRules)
local Build = require(ReplicatedStorage.MTL.UI.Build.Crime)
local UIState = require(script.Parent.UIState)
local JobFX = require(script.Parent.JobFX)
local Minigames = require(script.Parent.JobMinigames)

local player = Players.LocalPlayer
local CrimeController = {}

local gui: any = nil
local action: RemoteEvent = nil :: any

local function fire(payload: any)
	action:FireServer(payload)
end

local function tween(inst: Instance, t: number, props: { [string]: any })
	local tw = TweenService:Create(inst, TweenInfo.new(t, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), props)
	tw:Play()
	return tw
end

local function sound(id: string, volume: number?, speed: number?)
	if id == "" then
		return
	end
	local s = Instance.new("Sound")
	s.SoundId = id
	s.Volume = volume or 0.6
	s.PlaybackSpeed = speed or 1
	s.Parent = workspace.CurrentCamera
	s:Play()
	Debris:AddItem(s, 6)
end

---------------------------------------------------------------- heat + dirty

local heatState = { stars = 0, unseen = 0, lose = 0, at = 0, seen = false }

local function drawHeat()
	local h = gui.Side.Heat
	h.Visible = heatState.stars > 0
	for i = 1, Crime.Heat.Max do
		local star = h:FindFirstChild("Star" .. i) :: TextLabel?
		if star then
			star.TextTransparency = if i <= heatState.stars then 0 else 0.78
		end
	end
end

local function onHeat(p: any)
	local old = heatState.stars
	heatState.stars = p.stars or 0
	heatState.unseen = p.unseen or 0
	heatState.lose = p.lose or 0
	heatState.seen = p.seen == true
	heatState.at = os.clock()
	drawHeat()
	if heatState.stars > old then
		local h = gui.Side.Heat
		local scale = gui.Side:FindFirstChild("Scale") :: UIScale?
		if scale then
			scale.Scale = 1.18
			Motion.tween(scale, Motion.Spring, { Scale = 1 })
		end
		local _ = h
	end
end

local function onDirty(p: any)
	local d = gui.Side.Dirty
	local amount = p.dirty or 0
	d.Visible = amount > 0
	d.Amount.Text = CrimeRules.money(amount)
	if (p.delta or 0) ~= 0 then
		d.Size = UDim2.fromOffset(160, 34)
		tween(d, 0.25, { Size = UDim2.fromOffset(150, 32) })
	end
end

---------------------------------------------------------------- tracker

local runTitle = {
	Stickup = "STICKUP",
	TipJob = "TIP JOB",
	HouseLick = "HOUSE LICK",
	CarBoost = "CAR BOOST",
	AtmDrill = "ATM DRILL",
	Heist = "CREW HEIST",
}
local runState: any = nil

local function drawRun()
	local r = gui.Run
	if not runState then
		r.Visible = false
		return
	end
	r.Visible = true
	r.Title.Text = runTitle[runState.method] or string.upper(runState.title or "")
	local fill = r.Bar.Fill
	if runState.method == "AtmDrill" then
		local t, total = runState.t or 0, runState.total or 45
		r.Sub.Text = if runState.stalled then "Drill stalled. Get back to it." else ("Drilling  " .. CrimeRules.clock(total - t))
		fill.Size = UDim2.fromScale(math.clamp(t / total, 0, 1), 1)
	elseif runState.method == "CarBoost" then
		r.Sub.Text = string.format("Pay %s  ·  %d dents", CrimeRules.money(runState.pay or Crime.Methods.CarBoost.pay), runState.hits or 0)
		fill.Size = UDim2.fromScale(math.clamp((runState.pay or 1400) / Crime.Methods.CarBoost.pay, 0, 1), 1)
	elseif runState.total and runState.method ~= "AtmDrill" then
		r.Sub.Text = string.format("%d of %d  ·  %s", runState.count or 0, runState.total, CrimeRules.money(runState.value or 0))
		fill.Size = UDim2.fromScale(math.clamp((runState.count or 0) / runState.total, 0, 1), 1)
	else
		r.Sub.Text = "Grab it and go"
		fill.Size = UDim2.fromScale(0, 1)
	end
end

---------------------------------------------------------------- prompts

local promptFolder: Folder
local prompts: { [string]: { part: BasePart, prompt: ProximityPrompt, data: any } } = {}

local function setPose(name: string?)
	local char = player.Character
	if char then
		char:SetAttribute("MTL_Action", name)
	end
end

local function makePrompt(d: any)
	local part = Instance.new("Part")
	part.Name = "CrimePrompt"
	part.Size = Vector3.new(0.4, 0.4, 0.4)
	part.Transparency = 1
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Position = d.pos
	part.Parent = promptFolder
	local pp = Instance.new("ProximityPrompt")
	pp.ActionText = d.action
	pp.ObjectText = d.object or ""
	pp.HoldDuration = d.hold or 0
	pp.MaxActivationDistance = d.range or 8
	pp.RequiresLineOfSight = false
	pp.KeyboardKeyCode = Enum.KeyCode.E
	pp.Style = Enum.ProximityPromptStyle.Default
	pp:SetAttribute("MTL_Crime", true)
	pp.Parent = part
	pp.PromptButtonHoldBegan:Connect(function()
		fire({ type = "holdBegin", id = d.id })
		if d.pose then
			setPose(d.pose)
		end
	end)
	pp.PromptButtonHoldEnded:Connect(function()
		if d.pose then
			setPose(nil)
		end
	end)
	pp.Triggered:Connect(function()
		if d.pose then
			setPose(nil)
		end
		fire({ type = "prompt", id = d.id })
	end)
	prompts[d.id] = { part = part, prompt = pp, data = d }
end

local function onPrompts(list: { any })
	local keep: { [string]: boolean } = {}
	for _, d in list do
		keep[d.id] = true
		local e = prompts[d.id]
		if e then
			-- update in place (labels change: "Load it", money on the stacks)
			e.part.Position = d.pos
			e.prompt.ActionText = d.action
			e.prompt.ObjectText = d.object or ""
			e.prompt.HoldDuration = d.hold or 0
			e.data = d
		else
			makePrompt(d)
		end
	end
	for id, e in prompts do
		if not keep[id] then
			e.part:Destroy()
			prompts[id] = nil
		end
	end
end

---------------------------------------------------------------- minigames

local mini: any = nil

local function onMini(p: any)
	if mini then
		mini.cancel()
		mini = nil
	end
	local jobGui = player.PlayerGui:FindFirstChild("MTL_Job")
	if not jobGui then
		fire({ type = "mini", id = p.id, cancel = true })
		return
	end
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	local fx = JobFX.forStep(nil, if root then root.Position else Vector3.zero)
	local hitSound = p.info and p.info.sound and (Crime.Sounds :: any)[p.info.sound]
	if hitSound then
		local inner = fx.hit
		fx = {
			progress = fx.progress,
			hit = function()
				inner()
				sound(hitSound, 0.8, 0.95 + math.random() * 0.1)
			end,
			finish = fx.finish,
			destroy = fx.destroy,
		}
	end
	UIState.push("CrimeMini", { lockControls = true })
	local id = p.id
	mini = Minigames.run(jobGui, p.info, fx, function(score: number)
		mini = nil
		UIState.pop("CrimeMini")
		fx.destroy()
		fire({ type = "mini", id = id, score = score })
	end, function()
		mini = nil
		UIState.pop("CrimeMini")
		fx.destroy()
		fire({ type = "mini", id = id, cancel = true })
	end)
end

---------------------------------------------------------------- wash

local washConn: RBXScriptConnection? = nil

local function onWash(p: any)
	local w = gui.Wash
	w.Visible = true
	w.Title.Text = "WASHING " .. CrimeRules.money(p.amount)
	w.Sub.Text = string.format("Benny keeps %d%%. You get %s clean. Stay at the counter.", math.floor(p.cut * 100 + 0.5), CrimeRules.money(p.clean))
	w.Bar.Fill.Size = UDim2.fromScale(0, 1)
	tween(w.Bar.Fill, p.seconds, { Size = UDim2.fromScale(1, 1) })
end

local function onWashEnd(p: any)
	local w = gui.Wash
	if p.ok then
		w.Title.Text = "CLEAN " .. CrimeRules.money(p.clean)
		sound(Theme.Sounds.Toast, 0.6)
		task.delay(1.4, function()
			w.Visible = false
		end)
	else
		w.Visible = false
	end
	local _ = washConn
end

---------------------------------------------------------------- Marcus's shop

local function closeShop()
	gui.Shop.Visible = false
	UIState.pop("CrimeShop")
end

local function onShop(p: any)
	local shop = gui.Shop
	local list = shop.List
	for _, c in list:GetChildren() do
		if c:IsA("GuiObject") then
			c:Destroy()
		end
	end
	shop.Cash.Text = CrimeRules.money(p.cash or 0)
	for i, t in p.tools do
		local row = Instance.new("Frame")
		row.Name = t.id
		row.LayoutOrder = i
		row.Size = UDim2.new(1, 0, 0, 62)
		row.BackgroundColor3 = Color3.fromRGB(30, 32, 40)
		row.BackgroundTransparency = 0.1
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 10)
		corner.Parent = row
		local title = Instance.new("TextLabel")
		title.BackgroundTransparency = 1
		title.Position = UDim2.fromOffset(14, 8)
		title.Size = UDim2.new(1, -130, 0, 22)
		title.FontFace = Theme.Fonts.Display
		title.TextSize = 17
		title.TextXAlignment = Enum.TextXAlignment.Left
		title.TextColor3 = Theme.Colors.Text
		title.Text = t.title
		title.Parent = row
		local blurb = Instance.new("TextLabel")
		blurb.BackgroundTransparency = 1
		blurb.Position = UDim2.fromOffset(14, 31)
		blurb.Size = UDim2.new(1, -130, 0, 24)
		blurb.FontFace = Theme.Fonts.Body
		blurb.TextSize = 12
		blurb.TextWrapped = true
		blurb.TextXAlignment = Enum.TextXAlignment.Left
		blurb.TextYAlignment = Enum.TextYAlignment.Top
		blurb.TextColor3 = Theme.Colors.TextDim
		blurb.Text = t.blurb
		blurb.Parent = row
		local btn = Instance.new("TextButton")
		btn.AnchorPoint = Vector2.new(1, 0.5)
		btn.Position = UDim2.new(1, -10, 0.5, 0)
		btn.Size = UDim2.fromOffset(104, 38)
		btn.FontFace = Theme.Fonts.Display
		btn.TextSize = 15
		local c2 = Instance.new("UICorner")
		c2.CornerRadius = UDim.new(0, 10)
		c2.Parent = btn
		if t.owned then
			btn.Text = "Owned"
			btn.BackgroundColor3 = Color3.fromRGB(44, 47, 58)
			btn.TextColor3 = Theme.Colors.TextDim
			btn.AutoButtonColor = false
		elseif (p.level or 1) < t.level then
			btn.Text = "Level " .. t.level
			btn.BackgroundColor3 = Color3.fromRGB(44, 47, 58)
			btn.TextColor3 = Theme.Colors.TextDim
			btn.AutoButtonColor = false
		else
			btn.Text = CrimeRules.money(t.price)
			btn.BackgroundColor3 = if (p.cash or 0) >= t.price then Theme.Colors.Accent else Color3.fromRGB(70, 60, 60)
			btn.TextColor3 = Color3.fromRGB(10, 30, 22)
			btn.Activated:Connect(function()
				fire({ type = "buyTool", id = t.id })
			end)
		end
		btn.Parent = row
		row.Parent = list
	end
	local fence = shop.Fence
	if (p.fence or 0) > 0 then
		fence.Text = "Fence the goods  " .. CrimeRules.money(p.fence)
		fence.AutoButtonColor = true
		fence.BackgroundTransparency = 0
	else
		fence.Text = "Nothing to fence"
		fence.BackgroundTransparency = 0.6
	end
	if not shop.Visible then
		shop.Visible = true
		UIState.push("CrimeShop", { modal = true, lockControls = true })
		local scale = shop:FindFirstChild("Scale") :: UIScale?
		if scale then
			scale.Scale = 0.9
			Motion.tween(scale, Motion.Spring, { Scale = 1 })
		end
	end
end

---------------------------------------------------------------- booked + fade

local function onBooked(p: any)
	local b = gui.Booked
	b.Visible = true
	b.GroupTransparency = 1
	b.Sub.Text = if (p.lost or 0) > 0
		then ("They took the " .. CrimeRules.money(p.lost) .. " dirty cash on you. Out in " .. p.seconds .. "s.")
		else ("Nothing on you, so nothing to take. Out in " .. p.seconds .. "s.")
	b.Bar.Fill.Size = UDim2.fromScale(0, 1)
	tween(b, 0.3, { GroupTransparency = 0 })
	tween(b.Bar.Fill, p.seconds, { Size = UDim2.fromScale(1, 1) })
	sound(Crime.Sounds.Cuffs, 0.9)
	task.delay(p.seconds, function()
		tween(b, 0.4, { GroupTransparency = 1 })
		task.delay(0.45, function()
			b.Visible = false
		end)
	end)
end

local function onFade()
	local f = gui.Fade
	f.BackgroundTransparency = 1
	tween(f, 0.25, { BackgroundTransparency = 0 })
	task.delay(0.55, function()
		tween(f, 0.35, { BackgroundTransparency = 1 })
	end)
end

---------------------------------------------------------------- aim bar (stickup)

local aimHideAt = 0
local function onAim(p: any)
	local a = gui.Aim
	a.Visible = true
	a.Text.Text = string.upper(p.label or "Hands up")
	tween(a.Ring.Fill, 0.25, { Size = UDim2.fromScale(math.clamp(p.t or 0, 0, 1), 1) })
	aimHideAt = os.clock() + 0.9
end

---------------------------------------------------------------- police: lightbars, aim pose, shots

local lightParts: { [Model]: { red: { BasePart }, blue: { BasePart } } } = {}

local function watchCar(car: Instance)
	if not car:IsA("Model") then
		return
	end
	local red, blue = {}, {}
	for _, d in car:GetDescendants() do
		if d:IsA("BasePart") then
			local n = string.lower(d.Name)
			if string.find(n, "red") and string.find(n, "light") then
				table.insert(red, d)
			elseif string.find(n, "blue") and string.find(n, "light") then
				table.insert(blue, d)
			end
		end
	end
	lightParts[car] = { red = red, blue = blue }
	for _, p in red do
		local l = Instance.new("PointLight")
		l.Name = "Flash"
		l.Color = Color3.fromRGB(255, 40, 40)
		l.Range = 18
		l.Brightness = 0
		l.Parent = p
	end
	for _, p in blue do
		local l = Instance.new("PointLight")
		l.Name = "Flash"
		l.Color = Color3.fromRGB(40, 90, 255)
		l.Range = 18
		l.Brightness = 0
		l.Parent = p
	end
end

local officerJoints: { [Model]: any } = {}

local function tracer(from: Vector3, to: Vector3)
	local dist = (to - from).Magnitude
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Material = Enum.Material.Neon
	p.Color = Color3.fromRGB(255, 220, 150)
	p.Size = Vector3.new(0.06, 0.06, dist)
	p.CFrame = CFrame.lookAt(from, to) * CFrame.new(0, 0, -dist / 2)
	p.Parent = workspace.CurrentCamera
	tween(p, 0.12, { Transparency = 1 })
	Debris:AddItem(p, 0.2)
end

local function onShot(p: any)
	tracer(p.from, p.to)
	-- the crack, at the muzzle
	local a = Instance.new("Attachment")
	a.WorldPosition = p.from
	a.Parent = workspace.Terrain
	local s = Instance.new("Sound")
	s.SoundId = Crime.Sounds.Shot
	s.Volume = 0.8
	s.RollOffMode = Enum.RollOffMode.InverseTapered
	s.RollOffMaxDistance = 400
	s.Parent = a
	s:Play()
	Debris:AddItem(a, 3)
end

---------------------------------------------------------------- init

function CrimeController.init()
	local pg = player:WaitForChild("PlayerGui")
	gui = pg:FindFirstChild("MTL_Crime")
	if not gui then
		gui = Build.build()
		gui.Parent = pg
	end
	action = Net.get("CrimeAction")
	promptFolder = Instance.new("Folder")
	promptFolder.Name = "MTL_CrimePrompts"
	promptFolder.Parent = workspace

	gui.Wash.Cancel.Activated:Connect(function()
		fire({ type = "washCancel" })
	end)
	gui.Shop.Close.Activated:Connect(closeShop)
	gui.Shop.Fence.Activated:Connect(function()
		fire({ type = "fence" })
	end)

	Net.get("CrimeState").OnClientEvent:Connect(function(p: any)
		if type(p) ~= "table" then
			return
		end
		local t = p.type
		if t == "heat" then
			onHeat(p)
		elseif t == "dirty" then
			onDirty(p)
		elseif t == "pop" then
			sound(Crime.Sounds.CashGrab, 0.5, 1.1)
		elseif t == "prompts" then
			onPrompts(p.list or {})
		elseif t == "mini" then
			onMini(p)
		elseif t == "miniCancel" then
			if mini then
				mini.cancel()
				mini = nil
			end
		elseif t == "wash" then
			onWash(p)
		elseif t == "washEnd" then
			onWashEnd(p)
		elseif t == "shop" then
			onShop(p)
		elseif t == "booked" then
			if gui.Shop.Visible then
				closeShop()
			end
			onBooked(p)
		elseif t == "fade" then
			onFade()
		elseif t == "aim" then
			onAim(p)
		elseif t == "runStart" then
			runState = { method = p.method, title = p.title, total = p.total, count = 0, value = 0, pay = p.pay, hits = 0 }
			gui.Aim.Visible = false
			drawRun()
		elseif t == "runProgress" then
			if runState then
				for k, v in p do
					if k ~= "type" then
						runState[k] = v
					end
				end
				drawRun()
			end
		elseif t == "boostDamage" then
			if runState then
				runState.hits = p.hits
				runState.pay = p.pay
				drawRun()
			end
			sound(Crime.Sounds.Break, 0.5, 1.2)
		elseif t == "runEnd" then
			runState = nil
			drawRun()
		elseif t == "policeShot" then
			onShot(p)
		elseif t == "dropped" then
			sound(Crime.Sounds.CashGrab, 0.6, 0.7)
		end
	end)

	-- lightbars + officer aim, every frame
	for _, car in CollectionService:GetTagged("MTL_PoliceCar") do
		watchCar(car)
	end
	CollectionService:GetInstanceAddedSignal("MTL_PoliceCar"):Connect(function(car)
		task.wait(0.2)
		watchCar(car)
	end)
	CollectionService:GetInstanceRemovedSignal("MTL_PoliceCar"):Connect(function(car)
		lightParts[car :: Model] = nil
	end)
	CollectionService:GetInstanceRemovedSignal("MTL_Officer"):Connect(function(m)
		officerJoints[m :: Model] = nil
	end)
	local hudTop: GuiObject? = nil
	RunService.RenderStepped:Connect(function()
		local now = os.clock()
		-- the stars + dirty pill sit just under the HUD's cash/level block (the two ScreenGuis use different inset
		-- settings, so a fixed offset lands on top of the LEVEL badge)
		if not hudTop or not hudTop.Parent then
			local hud = player.PlayerGui:FindFirstChild("MTL_HUD")
			hudTop = if hud then hud:FindFirstChild("Top", true) :: GuiObject? else nil
		end
		if hudTop and hudTop.Visible then
			local side = gui.Side
			local y = hudTop.AbsolutePosition.Y + hudTop.AbsoluteSize.Y + 8 - gui.AbsolutePosition.Y
			if math.abs(side.Position.Y.Offset - y) > 0.5 then
				side.Position = UDim2.new(side.Position.X.Scale, side.Position.X.Offset, 0, y)
			end
		end
		-- red/blue in turn, double-blink pattern
		local phase = (now * 2.4) % 1
		local redOn = phase < 0.22 or (phase > 0.3 and phase < 0.42)
		local blueOn = (phase > 0.5 and phase < 0.72) or (phase > 0.8 and phase < 0.92)
		for car, lp in lightParts do
			if not car.Parent then
				lightParts[car] = nil
				continue
			end
			local on = car:GetAttribute("Lights") == true
			for _, p in lp.red do
				p.Transparency = if on and redOn then 0 else 0.55
				local l = p:FindFirstChild("Flash") :: PointLight?
				if l then
					l.Brightness = if on and redOn then 4 else 0
				end
			end
			for _, p in lp.blue do
				p.Transparency = if on and blueOn then 0 else 0.55
				local l = p:FindFirstChild("Flash") :: PointLight?
				if l then
					l.Brightness = if on and blueOn then 4 else 0
				end
			end
		end
		for _, m in CollectionService:GetTagged("MTL_Officer") do
			if m:IsA("Model") and m:GetAttribute("MTL_OfficerAim") then
				local j = officerJoints[m]
				if not j then
					j = Rig.joints(m)
					officerJoints[m] = j
				end
				Rig.apply(j, Rig.compose({ pose = "Aim", poseT0 = -10, breath = false }, now), "Transform")
			end
		end
		-- the stickup aim bar hides when you stop aiming
		if gui.Aim.Visible and now > aimHideAt then
			gui.Aim.Visible = false
		end
		-- the "lose them" bar fills while you're unseen
		if heatState.stars > 0 and heatState.lose > 0 then
			local unseen = heatState.unseen + (now - heatState.at)
			gui.Side.Heat.Lose.Fill.Size = UDim2.fromScale(math.clamp(unseen / heatState.lose, 0, 1), 1)
			-- stars blink while they can see you
			local blink = heatState.seen and (now % 0.5) < 0.25
			for i = 1, heatState.stars do
				local star = gui.Side.Heat:FindFirstChild("Star" .. i) :: TextLabel?
				if star then
					star.TextTransparency = if blink then 0.45 else 0
				end
			end
		end
	end)

	-- ask for the current state (dirty, prompts) once we're listening
	task.defer(function()
		fire({ type = "sync" })
	end)
	player.CharacterAdded:Connect(function()
		task.wait(1)
		fire({ type = "sync" })
	end)
end

return CrimeController
