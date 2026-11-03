--!strict
-- Client side of Piece 4 (the flat). Listens to PropertyState (PropertyService) and:
--   * the FOR SALE card (MTL_Property.Listing): BUY sends PropertyAction buy; "Not now" / Esc / B closes it
--   * the door fade when you walk in or out (ends by itself after 4 s, or the moment a cutscene takes over)
--   * the outside door: this player's own prompt text ("For sale · $1,200" / "Go inside"), and while you're house
--     hunting (FindAPlace) a pulsing outline + a FOR SALE sign over it you can see from down the street
--   * highlights inside your room: the bed at FirstNight ("Sleep"), the front door when it's time to go to work
--   * your room's power: the dead bulb, the PC screen and its power light (lit once the bill is paid)
--   * opens the phone on an app when the server asks (the Jobs app after the move-in scene), and nudges the phone
--     while the ChooseJob stage waits for a pick
--   * the custom cutscene beats used by Cutscenes/PowerOut + NextDay: BulbFlicker, BulbOff, PcPower,
--     KeyboardBounce, PhoneOut, MorningLight
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local CollectionService = game:GetService("CollectionService")
local SoundService = game:GetService("SoundService")
local GuiService = game:GetService("GuiService")

local Net = require(ReplicatedStorage.MTL.Net)
local Theme = require(ReplicatedStorage.MTL.UI.Theme)
local Sfx = require(ReplicatedStorage.MTL.UI.Sfx)
local Motion = require(ReplicatedStorage.MTL.UI.Motion)
local Format = require(ReplicatedStorage.MTL.Format)
local Property = require(ReplicatedStorage.MTL.Config.Property)
local Locations = require(ReplicatedStorage.MTL.Config.Locations)
local PropertyRules = require(ReplicatedStorage.MTL.Rules.PropertyRules)
local Build = require(ReplicatedStorage.MTL.UI.Build.Property)
local ClientData = require(script.Parent.ClientData)
local UIState = require(script.Parent.UIState)

local player = Players.LocalPlayer
local K = Theme.Property

local PropertyController = {}

local gui: any
local listingHome: string? = nil
local fadeToken = 0
local bedOn = false
local exitOn = false
local sceneLight = { bulbOverride = false, morning = nil :: Light? }

local function log(...)
	print("[MTL Property]", ...)
end

local function sibling(name: string): any?
	local m = script.Parent:FindFirstChild(name)
	if not m then
		return nil
	end
	local ok, mod = pcall(require, m)
	return if ok then mod else nil
end

local function playSound(id: string?, volume: number?)
	if type(id) ~= "string" or id == "" then
		return
	end
	Sfx.playId(id, { volume = volume or 0.5 })
end

local function myRoom(): Model?
	local f = workspace:FindFirstChild("MTL_Flats")
	local m = f and f:FindFirstChild("Flat_" .. player.UserId)
	return if m and m:IsA("Model") then m else nil
end

local function roomPart(name: string): BasePart?
	local m = myRoom()
	local p = m and m:FindFirstChild(name, true)
	return if p and p:IsA("BasePart") then p else nil
end

local function powerOn(): boolean
	local d = ClientData.get()
	return d ~= nil and d.Home ~= nil and d.Home.PowerOn == true
end

---------------------------------------------------------------- fade

local function fadeOut(seconds: number?)
	fadeToken += 1
	local token = fadeToken
	local f = gui.Fade
	f.Visible = true
	Motion.tween(f, TweenInfo.new(seconds or 0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { BackgroundTransparency = 0 })
	UIState.push("PropertyFade", { hideHUD = true, hideWaypoints = true, lockControls = true })
	task.delay(4, function()
		if token == fadeToken then
			PropertyController.fadeIn()
		end
	end)
end

function PropertyController.fadeIn(seconds: number?)
	fadeToken += 1
	local token = fadeToken
	UIState.pop("PropertyFade")
	local f = gui.Fade
	if not f.Visible then
		return
	end
	local t = Motion.tween(f, TweenInfo.new(seconds or 0.45, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), { BackgroundTransparency = 1 })
	t.Completed:Connect(function()
		if token == fadeToken then
			f.Visible = false
		end
	end)
end

local function clearFadeNow()
	fadeToken += 1
	UIState.pop("PropertyFade")
	gui.Fade.BackgroundTransparency = 1
	gui.Fade.Visible = false
end

---------------------------------------------------------------- FOR SALE card

local function closeListing()
	if not gui.Listing.Visible then
		return
	end
	listingHome = nil
	UIState.pop("PropertyListing")
	if GuiService.SelectedObject and GuiService.SelectedObject:IsDescendantOf(gui) then
		GuiService.SelectedObject = nil
	end
	local card = gui.Listing.Card
	Motion.tween(card.Scale, Motion.Fast, { Scale = 0.94 })
	task.delay(0.12, function()
		if not listingHome then
			gui.Listing.Visible = false
		end
	end)
end

local function showListing(msg: any)
	local card = gui.Listing.Card
	listingHome = msg.home
	card.Title.Text = tostring(msg.title or "")
	card.Area.Text = tostring(msg.area or "")
	card.Blurb.Text = tostring(msg.blurb or "")
	card.Price.Text = Format.cash(msg.price or 0)
	card.Cash.Text = "You have " .. Format.cash(msg.cash or 0)
	local photo = card.Photo
	if type(msg.photo) == "string" and msg.photo ~= "rbxassetid://0" then
		photo.Image.Image = msg.photo
		photo.Sign.Visible = false
	end
	-- facts: one row per line
	local facts = card.Facts
	for _, c in facts:GetChildren() do
		if c.Name == "Fact" then
			c:Destroy()
		end
	end
	local template = facts:FindFirstChild("FactTemplate")
	if template then
		for i, f in (if type(msg.facts) == "table" then msg.facts else {}) do
			local row = template:Clone()
			row.Name = "Fact"
			row.LayoutOrder = i
			row.Visible = true
			row.Key.Text = tostring(f[1])
			row.Value.Text = tostring(f[2])
			row.Parent = facts
		end
	end
	local buy = card.Buttons.Buy
	if msg.canBuy then
		card.Short.Text = ""
		card.Short.Visible = false
		buy.Text = "BUY IT · " .. Format.cash(msg.price or 0)
		buy.Active = true
		buy.AutoButtonColor = false
		buy.BackgroundTransparency = 0
		buy.TextTransparency = 0
	else
		local short = tonumber(msg.short) or 0
		card.Short.Visible = true
		card.Short.Text = if short > 0 then ("You need " .. Format.cash(short) .. " more. Work a shift (phone, Jobs app) and come back.")
			else tostring(msg.reason or "Not for sale")
		buy.Text = if short > 0 then ("NEED " .. Format.cash(short)) else "NOT FOR SALE"
		buy.Active = false
		buy.BackgroundTransparency = 0.6
		buy.TextTransparency = 0.4
	end
	gui.Listing.Visible = true
	UIState.push("PropertyListing", { hidePhone = true })
	if UserInputService.GamepadEnabled then
		GuiService.SelectedObject = if buy.Active then buy else card.Buttons.Later
	end
	card.Scale.Scale = 0.9
	Motion.tween(card.Scale, Motion.Spring, { Scale = 1 })
end

---------------------------------------------------------------- outlines

local highlights: { [string]: Highlight } = {}

local function outline(key: string, target: Instance?)
	local old = highlights[key]
	if old then
		old:Destroy()
		highlights[key] = nil
	end
	if not target then
		return
	end
	-- the house style for every cue (UI/Guide): gold outline, gentle shared pulse, not drawn through walls
	local h = require(ReplicatedStorage.MTL.UI.Guide).outline(target, workspace) -- local (client-made, never replicates)
	h.Name = "MTL_Outline_" .. key
	highlights[key] = h
end

-- a glowing frame for invisible door parts (a Highlight can't outline something you can't see)
local doorGlow: Model? = nil
local doorSign: BillboardGui? = nil

local function clearDoorCue()
	if doorGlow then
		doorGlow:Destroy()
		doorGlow = nil
	end
	if doorSign then
		doorSign:Destroy()
		doorSign = nil
	end
	outline("Door", nil)
end

local function doorCue(door: BasePart, price: number)
	clearDoorCue()
	if door.Transparency < 1 then
		outline("Door", door)
	else
		local m = Instance.new("Model")
		m.Name = "MTL_DoorGlow"
		local s = door.Size
		local strips = {
			{ CFrame.new(0, s.Y / 2, 0), Vector3.new(s.X + 0.4, 0.25, 0.25) },
			{ CFrame.new(-s.X / 2, 0, 0), Vector3.new(0.25, s.Y, 0.25) },
			{ CFrame.new(s.X / 2, 0, 0), Vector3.new(0.25, s.Y, 0.25) },
		}
		for _, st in strips do
			local p = Instance.new("Part")
			p.Anchored = true
			p.CanCollide = false
			p.CanQuery = false
			p.CanTouch = false
			p.Material = Enum.Material.Neon
			p.Color = K.Highlight
			p.Transparency = 0.25
			p.Size = st[2]
			p.CFrame = door.CFrame * st[1]
			p.Parent = m
		end
		m.Parent = workspace
		doorGlow = m
	end
	local bb = Instance.new("BillboardGui")
	bb.Name = "MTL_ForSale"
	bb.Size = UDim2.fromOffset(170, 54)
	bb.StudsOffsetWorldSpace = Vector3.new(0, door.Size.Y / 2 + 2.6, 0)
	bb.AlwaysOnTop = true
	bb.MaxDistance = 600
	bb.LightInfluence = 0
	bb.Adornee = door
	local sign = Instance.new("TextLabel")
	sign.Size = UDim2.fromScale(1, 1)
	sign.BackgroundColor3 = K.Sign
	sign.TextColor3 = K.SignText
	sign.FontFace = Theme.Fonts.Display
	sign.TextScaled = true
	sign.Text = "FOR SALE · " .. Format.cash(price)
	sign.Parent = bb
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = sign
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 8)
	pad.PaddingRight = UDim.new(0, 8)
	pad.Parent = sign
	bb.Parent = gui
	doorSign = bb
end

local function refreshDoors()
	local d = ClientData.get()
	if not d or not d.Story then
		return
	end
	local hunting = d.Story.Stage == "FindAPlace" and not PropertyRules.ownsAny(d)
	local cued = false
	for _, door in CollectionService:GetTagged("MTL_HomeDoor") do
		if door:IsA("BasePart") then
			local homeId = door:GetAttribute("MTL_Home")
			local prompt = door:FindFirstChild("MTL_DoorPrompt")
			if type(homeId) == "string" and prompt and prompt:IsA("ProximityPrompt") then
				prompt.ActionText = PropertyRules.doorText(d, homeId) -- local only: every player sees their own text
				if hunting and homeId == Property.StarterHome then
					cued = true
					if not doorSign or doorSign.Adornee ~= door then
						doorCue(door, Property.Homes[homeId].price)
					end
				end
			end
		end
	end
	if not cued then
		clearDoorCue()
	end
end

local function refreshRoomCues()
	local bed = roomPart("Mattress") or roomPart("BedSeat")
	outline("Bed", if bedOn and bed then bed else nil)
	local door = roomPart("ExitDoor") or roomPart("Exit")
	outline("Exit", if exitOn and door then door else nil)
	local Wayfinder = sibling("WayfindingController")
	if Wayfinder then
		if bedOn and bed then
			Wayfinder.set("MTL_Bed", bed.Position + Vector3.new(0, 1.5, 0), { label = "Sleep", radius = 3, breadcrumbs = false })
		else
			Wayfinder.clear("MTL_Bed", true)
		end
	end
end

---------------------------------------------------------------- power visuals (your room only)

local function applyPower()
	local on = powerOn()
	local bulb = roomPart("Bulb")
	if bulb and not sceneLight.bulbOverride then
		local light = bulb:FindFirstChildWhichIsA("Light")
		if light then
			light.Enabled = on
		end
		bulb.Material = if on then Enum.Material.Neon else Enum.Material.Glass
		bulb.Color = if on then K.Bulb else Color3.fromRGB(150, 146, 136)
	end
	local screen = roomPart("Screen")
	local display = screen and screen:FindFirstChildWhichIsA("SurfaceGui")
	if display then
		display.Enabled = on
	end
	local led = roomPart("PowerLed")
	if led then
		led.Color = if on then Color3.fromRGB(80, 255, 120) else Color3.fromRGB(60, 10, 10)
	end
end

---------------------------------------------------------------- cutscene beats

local function registerBeats()
	local Cutscene = sibling("CutsceneController")
	if not Cutscene then
		warn("[MTL Property] no CutsceneController; the flat scenes play without their props")
		return
	end
	-- the light switch: a few weak flickers, then dead (only if the power is off)
	Cutscene.registerAction("BulbFlicker", function(_ctx, a)
		local bulb = roomPart("Bulb")
		local light = bulb and bulb:FindFirstChildWhichIsA("Light")
		if not bulb or not light or powerOn() then
			return
		end
		sceneLight.bulbOverride = true
		local stop = os.clock() + (a.dur or 2)
		task.spawn(function()
			local rng = Random.new()
			while os.clock() < stop and bulb.Parent do
				local lit = rng:NextNumber() < 0.45
				light.Enabled = lit
				bulb.Material = if lit then Enum.Material.Neon else Enum.Material.Glass
				task.wait(rng:NextNumber(0.04, 0.16))
			end
			sceneLight.bulbOverride = false
			applyPower()
		end)
	end)
	Cutscene.registerAction("BulbOff", function()
		local bulb = roomPart("Bulb")
		local light = bulb and bulb:FindFirstChildWhichIsA("Light")
		if light then
			sceneLight.bulbOverride = true
			light.Enabled = false
			bulb.Material = Enum.Material.Glass
		end
	end)
	-- press power: the light blinks once, the screen twitches, nothing
	Cutscene.registerAction("PcPower", function()
		local led = roomPart("PowerLed")
		local screen = roomPart("Screen")
		if powerOn() then
			return
		end
		if led then
			led.Color = Color3.fromRGB(255, 40, 40)
			task.delay(0.12, function()
				led.Color = Color3.fromRGB(60, 10, 10)
			end)
		end
		if screen then
			local was = screen.Color
			screen.Color = Color3.fromRGB(40, 44, 40)
			task.delay(0.07, function()
				screen.Color = was
			end)
		end
	end)
	Cutscene.registerAction("KeyboardBounce", function()
		local kb = roomPart("Keyboard")
		if not kb then
			return
		end
		local base = kb:GetAttribute("MTL_Base") :: CFrame?
		if not base then
			base = kb.CFrame
			kb:SetAttribute("MTL_Base", base)
		end
		assert(base)
		local rng = Random.new()
		kb.CFrame = base * CFrame.new(rng:NextNumber(-0.05, 0.05), 0.22, 0) * CFrame.Angles(math.rad(rng:NextNumber(-8, 8)), 0, math.rad(rng:NextNumber(-6, 6)))
		task.delay(0.09, function()
			kb.CFrame = base * CFrame.Angles(0, math.rad(rng:NextNumber(-4, 4)), 0)
		end)
	end)
	-- a phone in the actor's right hand, its screen lighting the face
	Cutscene.registerAction("PhoneOut", function(ctx)
		local actor = ctx.actors and ctx.actors.Player
		local model = actor and actor.model
		local hand = model and (model:FindFirstChild("RightHand") or model:FindFirstChild("Right Arm"))
		if not hand or not hand:IsA("BasePart") or model:FindFirstChild("ScenePhone") then
			return -- Actors already put a phone in the hand for the SitPhone pose
		end
		local phone = Instance.new("Part")
		phone.Name = "ScenePhone"
		phone.Size = Vector3.new(0.45, 0.85, 0.08)
		phone.Color = Color3.fromRGB(18, 19, 24)
		phone.CanCollide = false
		phone.CanQuery = false
		phone.CanTouch = false
		phone.Massless = true
		local screen = Instance.new("Part")
		screen.Name = "Glow"
		screen.Size = Vector3.new(0.38, 0.75, 0.02)
		screen.Material = Enum.Material.Neon
		screen.Color = Color3.fromRGB(150, 190, 255)
		screen.CanCollide = false
		screen.CanQuery = false
		screen.Massless = true
		local light = Instance.new("PointLight")
		light.Color = Color3.fromRGB(150, 190, 255)
		light.Brightness = 1.2
		light.Range = 5
		light.Parent = screen
		local yOff = if hand.Name == "RightHand" then -0.25 else -1.1
		phone.CFrame = hand.CFrame * CFrame.new(0, yOff, -0.2) * CFrame.Angles(math.rad(-70), 0, 0)
		screen.CFrame = phone.CFrame * CFrame.new(0, 0, -0.05)
		local w1 = Instance.new("WeldConstraint")
		w1.Part0 = hand
		w1.Part1 = phone
		w1.Parent = phone
		local w2 = Instance.new("WeldConstraint")
		w2.Part0 = phone
		w2.Part1 = screen
		w2.Parent = screen
		phone.Parent = model
		screen.Parent = model -- destroyed with the actor when the scene ends
	end)
	-- morning light through the boards (stays a minute, then fades)
	Cutscene.registerAction("MorningLight", function()
		local window = roomPart("Window")
		if not window then
			return
		end
		if sceneLight.morning then
			sceneLight.morning:Destroy()
		end
		local l = Instance.new("SpotLight")
		l.Name = "MTL_Morning"
		l.Face = Enum.NormalId.Back
		l.Color = K.Morning
		l.Brightness = 3
		l.Range = 30
		l.Angle = 70
		l.Shadows = true
		l.Parent = window
		sceneLight.morning = l
		task.delay(60, function()
			if l.Parent then
				Motion.tween(l, TweenInfo.new(4), { Brightness = 0 })
				task.delay(4.2, function()
					l:Destroy()
				end)
			end
		end)
	end)
	Cutscene.Started:Connect(function()
		clearFadeNow() -- the cutscene's own black takes over from the door fade
		closeListing()
	end)
	Cutscene.Finished:Connect(function(id)
		if id == "PowerOut" or id == "NextDay" then
			sceneLight.bulbOverride = false
			applyPower()
			local kb = roomPart("Keyboard")
			local base = kb and kb:GetAttribute("MTL_Base")
			if kb and typeof(base) == "CFrame" then
				kb.CFrame = base
			end
		end
	end)
end

---------------------------------------------------------------- the phone

local phoneWanted: string? = nil

local function openPhoneWhenFree(app: string)
	phoneWanted = app
	task.spawn(function()
		local Phone = sibling("PhoneController")
		local Cutscene = sibling("CutsceneController")
		if not Phone then
			return
		end
		local deadline = os.clock() + 30
		while os.clock() < deadline and phoneWanted == app do
			local st = UIState.get()
			local scene = Cutscene and Cutscene.isPlaying()
			if not scene and not st.hidePhone then
				task.wait(0.4) -- let the camera settle back first
				if not (Cutscene and Cutscene.isPlaying()) and not UIState.get().hidePhone then
					Phone.open(app)
					if Phone.isOpen() and Phone.currentApp() == app then
						break
					end
				end
			end
			task.wait(0.25)
		end
		if phoneWanted == app then
			phoneWanted = nil
		end
	end)
end

-- ChooseJob: if the phone is put away without a pick, nudge it (a banner that opens Jobs), not more than every 25 s
local function nudgeLoop()
	local closedSince: number? = nil
	local lastNudge = 0
	while true do
		task.wait(1)
		local d = ClientData.get()
		local Phone = sibling("PhoneController")
		if d and d.Story and d.Story.Stage == "ChooseJob" and Phone then
			if Phone.isOpen() then
				closedSince = nil
			else
				closedSince = closedSince or os.clock()
				if os.clock() - (closedSince :: number) > 10 and os.clock() - lastNudge > 25 and not UIState.get().hidePhone then
					lastNudge = os.clock()
					Phone.notify({ app = "Jobs", title = "Jobs", text = "3 places are hiring. Tap to pick one." })
				end
			end
		else
			closedSince = nil
		end
	end
end

---------------------------------------------------------------- init

local function getGui()
	local pg = player:WaitForChild("PlayerGui")
	local existing = pg:FindFirstChild("MTL_Property")
	if existing then
		return existing
	end
	local built = Build.build()
	built.Parent = pg
	return built
end

local function onState(msg: any)
	if type(msg) ~= "table" then
		return
	end
	local kind = msg.type
	if kind == "listing" then
		if msg.close then
			closeListing()
			if msg.bought then
				playSound(K.Sounds.Buy, 0.6)
			end
		else
			showListing(msg)
		end
	elseif kind == "fade" then
		closeListing()
		fadeOut(msg.seconds)
	elseif kind == "arrived" then
		PropertyController.fadeIn()
		task.delay(0.6, applyPower)
	elseif kind == "phone" and type(msg.app) == "string" then
		openPhoneWhenFree(msg.app)
	elseif kind == "bed" then
		bedOn = msg.on == true
		refreshRoomCues()
	elseif kind == "exit" then
		exitOn = msg.on == true
		refreshRoomCues()
	elseif kind == "power" then
		applyPower()
	end
end

function PropertyController.init()
	gui = getGui()
	gui.Listing.Visible = false
	gui.Fade.Visible = false
	local card = gui.Listing.Card
	card.Buttons.Buy.Activated:Connect(function()
		if listingHome and card.Buttons.Buy.Active then
			Net.get("PropertyAction"):FireServer({ type = "buy", home = listingHome })
			card.Buttons.Buy.Text = "..."
		end
	end)
	card.Buttons.Later.Activated:Connect(closeListing)
	UserInputService.InputBegan:Connect(function(input, processed)
		if gui.Listing.Visible and (input.KeyCode == Enum.KeyCode.Escape or input.KeyCode == Enum.KeyCode.ButtonB) then
			closeListing()
		end
	end)
	-- walking away closes the card
	RunService.Heartbeat:Connect(function()
		if not listingHome then
			return
		end
		local char = player.Character
		local r = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
		local h = Property.Homes[listingHome]
		local loc = h and (Locations :: any)[h.location]
		if r and loc and (Vector2.new(r.Position.X - loc.Door.X, r.Position.Z - loc.Door.Z)).Magnitude > Property.Door.Radius + 18 then
			closeListing()
		end
	end)

	Net.get("PropertyState").OnClientEvent:Connect(function(msg)
		local ok, err = pcall(onState, msg)
		if not ok then
			warn("[MTL Property] state failed:", err)
		end
	end)
	ClientData.Changed:Connect(function()
		refreshDoors()
		applyPower()
	end)
	CollectionService:GetInstanceAddedSignal("MTL_HomeDoor"):Connect(function()
		task.defer(refreshDoors)
	end)
	-- your room streams in after you join (and after a rejoin): apply its power + cues when it appears
	task.spawn(function()
		local flats = workspace:WaitForChild("MTL_Flats", 60)
		if flats then
			flats.ChildAdded:Connect(function(c)
				if c.Name == "Flat_" .. player.UserId then
					task.wait(0.5)
					applyPower()
					refreshRoomCues()
				end
			end)
		end
	end)
	-- the outline pulses gently (max one pulse a second; Research: Onboarding)
	-- (outlines pulse in UI/Guide; this only keeps the door glow in step with them, so nothing blinks out of sync)
	RunService.Heartbeat:Connect(function()
		local a = (math.sin(os.clock() * math.pi * 2 * 0.7) + 1) / 2
		if doorGlow then
			for _, p in doorGlow:GetChildren() do
				if p:IsA("BasePart") then
					p.Transparency = 0.15 + 0.5 * a
				end
			end
		end
	end)
	registerBeats()
	task.spawn(nudgeLoop)
	task.defer(function()
		ClientData.waitReady()
		refreshDoors()
		applyPower()
	end)
	log("ready")
end

return PropertyController
