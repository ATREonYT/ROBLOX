--!strict
-- Story Piece 4: homes. Buying the flat in the Ends, the instanced dirty room, walking in and out, the power bill,
-- the bed, and the story stages that happen at home (Master Plan §1 stages 8-12; 13 FreePlay's welcome).
--
--   8  FindAPlace     Dre texts, Story waypoint to the flat's door, the FOR SALE card pops up when you get there
--                     (and from the door prompt). BUY -> cash spent, the flat is yours -> MoveIn.
--   9  MoveIn         fade into YOUR copy of the room, you're sat on the bed (hidden), the PowerOut cutscene plays
--                     (sit at the PC, no power, keyboard smash, bed, phone) -> ChooseJob.
--   10 ChooseJob      the phone rises on the Jobs app (client); JobService advances when a job is picked.
--   11 FirstNight     the bed glows + "Sleep" prompt (outside: a waypoint home). Sleep -> NextDay cutscene -> 12.
--   12 CommuteToWork  the boss texts; waypoint to the front door, then (outside) to work. JobService advances on
--                     clock-in. 13 FreePlay: the Goals app unlocks (GoalService runs the list).
--
-- Rooms: one per owner, built far from the map at a slot (Config/Property.Slots), streamed to the owner only
-- (PersistentPerPlayer). Alex's model ServerStorage.MTL_FlatInterior replaces the placeholder (see Config/Property).
--
-- API:
--   PropertyService.owns(player, homeId?) -> bool       PropertyService.isInside(player) -> bool
--   PropertyService.room(player) -> Room?               (builds it if the player owns a home)
--   PropertyService.enter(player, opts?) / leave(player, opts?)    opts.instant = no fade, opts.keepBlack = no fade-in
--   PropertyService.payPower(player) -> ok, reason      PropertyService.give(player, homeId)  (Studio / story safety)
--   Signals: Bought(player, homeId) · Entered(player, homeId) · Left(player, homeId) · PowerChanged(player, on)
-- Player attribute MTL_InHome = homeId while inside (the Jobs app measures distances from the front door then).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")

local Net = require(ReplicatedStorage.MTL.Net)
local Signal = require(ReplicatedStorage.MTL.Signal)
local Property = require(ReplicatedStorage.MTL.Config.Property)
local Locations = require(ReplicatedStorage.MTL.Config.Locations)
local GameInfo = require(ReplicatedStorage.MTL.Config.Game)
local Jobs = require(ReplicatedStorage.MTL.Config.Jobs)
local PropertyRules = require(ReplicatedStorage.MTL.Rules.PropertyRules)
local StoryRules = require(ReplicatedStorage.MTL.Rules.StoryRules)
local DataService = require(script.Parent.DataService)
local EconomyService = require(script.Parent.EconomyService)
local StoryService = require(script.Parent.StoryService)
local PhoneService = require(script.Parent.PhoneService)
local WaypointService = require(script.Parent.WaypointService)
local CutsceneService = require(script.Parent.CutsceneService)
local Notify = require(script.Parent.Notify)
local RateLimiter = require(script.Parent.RateLimiter)
local Analytics = require(script.Parent.Analytics)

local PropertyService = {}
PropertyService.Bought = Signal.new() -- (player, homeId)
PropertyService.Entered = Signal.new() -- (player, homeId)
PropertyService.Left = Signal.new() -- (player, homeId)
PropertyService.PowerChanged = Signal.new() -- (player, on)

export type Room = {
	owner: Player,
	home: string,
	slot: number,
	model: Model,
	origin: CFrame,
	marks: { [string]: Vector3 }, -- local points (cutscene marks)
	parts: { [string]: BasePart }, -- named parts found in the model
	seat: Seat?,
	prompts: { [string]: ProximityPrompt },
}

local rooms: { [Player]: Room } = {}
local takenSlots: { [number]: boolean } = {}
local inside: { [Player]: boolean } = {}
local busy: { [Player]: boolean } = {} -- a fade / scene is running
local lastDoor: { [Player]: number } = {}
local limiter = RateLimiter.new(4, 6)
local V = Vector3.new

local function log(...)
	print("[MTL Property]", ...)
end

local function fire(player: Player, payload: { [string]: any })
	Net.get("PropertyState"):FireClient(player, payload)
end

local function root(player: Player): BasePart?
	local c = player.Character
	return c and c:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function humanoid(player: Player): Humanoid?
	local c = player.Character
	return c and c:FindFirstChildOfClass("Humanoid")
end

local function money(n: number): string
	return "$" .. tostring(math.floor(n)):reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
end

local function homeOf(player: Player): string?
	local d = DataService.get(player)
	if not d then
		return nil
	end
	if d.Home.Current ~= "" and d.Home.Owned[d.Home.Current] then
		return d.Home.Current
	end
	for id in d.Home.Owned do
		return id
	end
	return nil
end

function PropertyService.owns(player: Player, homeId: string?): boolean
	local d = DataService.get(player)
	if not d then
		return false
	end
	return if homeId then PropertyRules.owns(d, homeId) else PropertyRules.ownsAny(d)
end

function PropertyService.isInside(player: Player): boolean
	return inside[player] == true
end

---------------------------------------------------------------- the placeholder room

local function folder(name: string): Folder
	local f = workspace:FindFirstChild(name)
	if not f then
		local nf = Instance.new("Folder")
		nf.Name = name
		nf.Parent = workspace
		f = nf
	end
	return f :: Folder
end

local function part(m: Instance, props: { [string]: any }): BasePart
	local cls = props.ClassName or "Part"
	local p = Instance.new(cls) :: any
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = Enum.Material.SmoothPlastic
	for k, v in props do
		if k ~= "ClassName" and k ~= "At" and k ~= "Rot" then
			p[k] = v
		end
	end
	local at: Vector3 = props.At or V()
	local rot: Vector3 = props.Rot or V()
	p.CFrame = CFrame.new(at) * CFrame.Angles(math.rad(rot.X), math.rad(rot.Y), math.rad(rot.Z))
	p.Parent = m
	return p
end

-- A grim one-room flat, built around (0, 0, 0) = floor centre; door in the +Z wall, the back wall at -Z.
-- TODO(Alex art): replace with ServerStorage.MTL_FlatInterior (keep the part names in Config/Property.Interior.Points).
local function buildPlaceholder(): Model
	local m = Instance.new("Model")
	m.Name = "FlatInterior"
	local P = Property.Interior.Points
	local C = Color3.fromRGB
	local wall = C(150, 140, 118)
	local origin = part(m, { Name = "Origin", Size = V(1, 0.1, 1), Transparency = 1, CanCollide = false, CanQuery = false, CanTouch = false })
	m.PrimaryPart = origin
	-- shell
	part(m, { Name = "Floor", Size = V(28, 1, 24), At = V(0, -0.5, 0), Material = Enum.Material.WoodPlanks, Color = C(92, 70, 52) })
	part(m, { Name = "Ceiling", Size = V(28, 1, 24), At = V(0, 12.5, 0), Material = Enum.Material.Concrete, Color = C(118, 112, 100) })
	part(m, { Name = "WallBack", Size = V(28, 13, 1), At = V(0, 6, -11.5), Material = Enum.Material.Concrete, Color = wall })
	part(m, { Name = "WallLeft", Size = V(1, 13, 24), At = V(-13.5, 6, 0), Material = Enum.Material.Concrete, Color = wall })
	part(m, { Name = "WallRight", Size = V(1, 13, 24), At = V(13.5, 6, 0), Material = Enum.Material.Concrete, Color = wall })
	part(m, { Name = "WallFront", Size = V(18, 13, 1), At = V(-5, 6, 11.5), Material = Enum.Material.Concrete, Color = wall })
	part(m, { Name = "WallFront", Size = V(6, 13, 1), At = V(11, 6, 11.5), Material = Enum.Material.Concrete, Color = wall })
	part(m, { Name = "WallFront", Size = V(4, 5, 1), At = V(6, 10.5, 11.5), Material = Enum.Material.Concrete, Color = wall })
	part(m, { Name = "ExitDoor", Size = V(4, 8, 0.4), At = V(6, 4, 11.2), Material = Enum.Material.WoodPlanks, Color = C(70, 50, 38) })
	part(m, { Name = "DoorKnob", Shape = Enum.PartType.Ball, Size = V(0.35, 0.35, 0.35), At = V(4.6, 3.8, 10.9), Material = Enum.Material.Metal, Color = C(160, 150, 120), CanCollide = false })
	-- grime: damp patches on the walls, stains on the floor
	for _, s in { { V(-13, 9, -4), V(0.1, 3, 5) }, { V(-4, 10.5, -11), V(6, 2.4, 0.1) }, { V(13, 3, 4), V(0.1, 2.2, 3) }, { V(-9, 2, 11), V(4, 1.6, 0.1) } } do
		part(m, { Name = "Damp", Size = s[2], At = s[1], Color = C(110, 104, 82), CanCollide = false, CanQuery = false })
	end
	for _, s in { { V(-2, 0.02, 3), 4 }, { V(3, 0.02, -2), 2.5 }, { V(-9, 0.02, 6), 3 } } do
		part(m, { Name = "Stain", Shape = Enum.PartType.Cylinder, Size = V(0.04, s[2], s[2]), At = s[1], Rot = V(0, 0, 90), Color = C(60, 46, 34), CanCollide = false, CanQuery = false })
	end
	-- the one light: a bare bulb on a cord
	part(m, { Name = "Cord", Size = V(0.08, 2.4, 0.08), At = V(P.Bulb.X, P.Bulb.Y + 1.5, P.Bulb.Z), Color = C(20, 20, 20), CanCollide = false })
	local bulb = part(m, { Name = "Bulb", Shape = Enum.PartType.Ball, Size = V(0.6, 0.6, 0.6), At = P.Bulb, Material = Enum.Material.Neon, Color = C(255, 214, 150), CanCollide = false })
	local light = Instance.new("PointLight")
	light.Name = "Light"
	light.Color = C(255, 206, 150)
	light.Range = 24
	light.Brightness = 1.3
	light.Shadows = true
	light.Enabled = false -- no power yet; PropertyController turns it on locally once the bill is paid
	light.Parent = bulb
	-- the boarded window: the only light while the power is off (cold street light through the boards)
	local window = part(m, { Name = "Window", Size = V(5, 4, 0.2), At = P.Window, Material = Enum.Material.Glass, Color = C(40, 52, 76), Transparency = 0.2, CanCollide = false })
	local street = Instance.new("SpotLight")
	street.Name = "StreetLight"
	street.Face = Enum.NormalId.Back -- into the room (+Z)
	street.Color = C(150, 172, 225)
	street.Brightness = 1.6
	street.Range = 26
	street.Angle = 100
	street.Shadows = true
	street.Parent = window
	for i, y in { -1.2, 0, 1.2 } do
		part(m, { Name = "Board", Size = V(5.8, 0.6, 0.2), At = P.Window + V(0, y, 0.15), Rot = V(0, 0, (i - 2) * 6), Material = Enum.Material.WoodPlanks, Color = C(120, 92, 62), CanCollide = false })
	end
	-- the desk + the dead PC
	part(m, { Name = "Desk", Size = V(5, 0.3, 2.4), At = V(P.Screen.X, 2.05, -9.5), Material = Enum.Material.Wood, Color = C(110, 82, 60) })
	for _, o in { V(-2.3, 0, -1), V(2.3, 0, -1), V(-2.3, 0, 1), V(2.3, 0, 1) } do
		part(m, { Name = "DeskLeg", Size = V(0.25, 1.9, 0.25), At = V(P.Screen.X, 0.95, -9.5) + o, Color = C(80, 60, 44) })
	end
	part(m, { Name = "Monitor", Size = V(2.6, 2.2, 2.2), At = V(P.Screen.X, 3.4, P.Screen.Z - 1.14), Color = C(190, 184, 168) })
	local screen = part(m, { Name = "Screen", Size = V(2.1, 1.7, 0.08), At = P.Screen, Material = Enum.Material.Glass, Color = C(14, 16, 14), CanCollide = false })
	local sg = Instance.new("SurfaceGui")
	sg.Name = "Display"
	sg.Face = Enum.NormalId.Back -- the +Z face (toward the chair)
	sg.CanvasSize = Vector2.new(320, 260)
	sg.LightInfluence = 0
	sg.Enabled = false
	sg.Parent = screen
	local txt = Instance.new("TextLabel")
	txt.Name = "Text"
	txt.Size = UDim2.fromScale(1, 1)
	txt.BackgroundColor3 = C(20, 60, 120)
	txt.TextColor3 = C(235, 240, 255)
	txt.TextScaled = true
	txt.FontFace = Font.new("rbxasset://fonts/families/RobotoMono.json")
	txt.Text = GameInfo.OSName .. "\n\nNo apps yet."
	txt.Parent = sg
	part(m, { Name = "Keyboard", Size = V(2.2, 0.15, 0.7), At = P.Keyboard, Color = C(200, 195, 180), CanCollide = false })
	part(m, { Name = "Tower", Size = V(0.9, 2, 2), At = V(P.PowerLed.X, 1, P.PowerLed.Z - 1.02), Color = C(190, 184, 168) })
	part(m, { Name = "PowerLed", Size = V(0.14, 0.14, 0.05), At = P.PowerLed, Material = Enum.Material.Neon, Color = C(60, 10, 10), CanCollide = false })
	-- the chair (CanQuery off so cutscene actors find the floor under it)
	local chairAt = P.ChairSpot
	part(m, { Name = "ChairSeat", Size = V(2, 0.3, 2), At = chairAt + V(0, 0.85, 0.2), Color = C(60, 62, 70), CanQuery = false })
	part(m, { Name = "ChairBack", Size = V(2, 2.2, 0.3), At = chairAt + V(0, 2.1, 1.2), Rot = V(-8, 0, 0), Color = C(60, 62, 70), CanQuery = false })
	for _, o in { V(-0.85, 0, -0.65), V(0.85, 0, -0.65), V(-0.85, 0, 1.05), V(0.85, 0, 1.05) } do
		part(m, { Name = "ChairLeg", Size = V(0.18, 0.75, 0.18), At = chairAt + V(0, 0.37, 0.2) + o, Color = C(40, 40, 44), CanQuery = false })
	end
	-- the bed: a stained mattress on pallets
	local bedAt = V(P.BedSeat.X + 1.8, 0, P.BedSeat.Z)
	part(m, { Name = "Pallets", Size = V(5, 0.5, 8.4), At = bedAt + V(0, 0.25, 0), Material = Enum.Material.WoodPlanks, Color = C(150, 120, 80), CanQuery = false })
	part(m, { Name = "Mattress", Size = V(4.6, 0.6, 8), At = bedAt + V(0, 0.8, 0), Material = Enum.Material.Fabric, Color = C(200, 190, 160), CanQuery = false })
	part(m, { Name = "MattressStain", Shape = Enum.PartType.Cylinder, Size = V(0.04, 2.2, 2.2), At = bedAt + V(0.4, 1.12, 1.6), Rot = V(0, 0, 90), Color = C(170, 150, 104), CanCollide = false, CanQuery = false })
	part(m, { Name = "Blanket", Size = V(3.2, 0.3, 3.4), At = bedAt + V(0.3, 1.25, 2.1), Rot = V(4, 18, -3), Material = Enum.Material.Fabric, Color = C(90, 100, 80), CanCollide = false, CanQuery = false })
	part(m, { Name = "Pillow", Size = V(2.2, 0.45, 1.3), At = bedAt + V(0.5, 1.3, -3.1), Material = Enum.Material.Fabric, Color = C(214, 206, 180), CanCollide = false, CanQuery = false })
	local seat = Instance.new("Seat")
	seat.Name = "BedSeat"
	seat.Size = V(2, 0.2, 2)
	seat.CFrame = CFrame.new(P.BedSeat) * CFrame.Angles(0, math.rad(90), 0) -- the sitter faces -X (into the room)
	seat.Anchored = true
	seat.Transparency = 1
	seat.CanCollide = false
	seat.CanQuery = false
	seat.CanTouch = false -- no sitting by walking into it; the prompt / story seats you
	seat.Parent = m
	-- trash
	for _, b in { V(-11.2, 1.1, 9.2), V(-9.4, 0.9, 10.1), V(12, 0.9, 7.6) } do
		part(m, { Name = "TrashBag", Shape = Enum.PartType.Ball, Size = V(2.2, 1.9, 2.2), At = b, Color = C(24, 24, 26), Material = Enum.Material.Plastic, CanQuery = false })
	end
	for i = 1, 3 do
		part(m, { Name = "PizzaBox", Size = V(2, 0.2, 2), At = V(-10.6, 0.1 + (i - 1) * 0.21, -8.4), Rot = V(0, i * 9, 0), Material = Enum.Material.Cardboard, Color = C(176, 136, 90), CanQuery = false })
	end
	for _, c in { V(-3.2, 0.3, -9.6), V(1.5, 0.3, 4.2), V(-7.4, 0.25, -3), V(9.2, 0.25, 2.4), V(-4.4, 2.6, -9.2) } do
		part(m, { Name = "Can", Shape = Enum.PartType.Cylinder, Size = V(0.8, 0.5, 0.5), At = c, Rot = V(0, 30, if c.Y < 1 then 0 else 90), Material = Enum.Material.Metal, Color = C(200, 40, 40), CanCollide = false, CanQuery = false })
	end
	-- breaker box by the door
	part(m, { Name = "Breaker", Size = V(1.4, 2, 0.4), At = P.Breaker, Material = Enum.Material.Metal, Color = C(120, 124, 130) })
	-- invisible floor markers (actors stand/sit on these; Alex's room needs parts with these names too)
	for _, name in { "Entry", "Exit", "ChairSpot", "BedSpot", "BedStand" } do
		part(m, { Name = name, Size = V(1, 0.05, 1), At = (P :: any)[name], Transparency = 1, CanCollide = false, CanQuery = false, CanTouch = false })
	end
	return m
end

---------------------------------------------------------------- rooms

local function template(): Model?
	local t = ServerStorage:FindFirstChild("MTL_FlatInterior")
	return if t and t:IsA("Model") and t.PrimaryPart then t else nil
end

local function promptOn(room: Room, key: string, at: BasePart, opts: { [string]: any }): ProximityPrompt
	local p = Instance.new("ProximityPrompt")
	p.Name = "MTL_Prompt_" .. key
	p.ActionText = opts.action or "Use"
	p.ObjectText = opts.object or ""
	p.HoldDuration = opts.hold or 0
	p.MaxActivationDistance = opts.distance or Property.Interior.PromptDistance
	p.RequiresLineOfSight = false
	p.Parent = at
	room.prompts[key] = p
	return p
end

local onRoomPrompt: (Player, Room, string) -> () -- set below

local function bedText(player: Player): string
	return if StoryService.stage(player) == "FirstNight" then "Sleep" else "Sit"
end

local function buildRoom(player: Player, homeId: string): Room?
	local slot = PropertyRules.freeSlot(takenSlots)
	if not slot then
		warn("[MTL Property] no free room slot for", player.Name)
		return nil
	end
	local t = template()
	local model: Model
	if t then
		local was = t.Archivable
		t.Archivable = true
		model = t:Clone()
		t.Archivable = was
	else
		model = buildPlaceholder()
	end
	local origin = CFrame.new(PropertyRules.slotOrigin(slot))
	model:PivotTo(origin)
	model.Name = "Flat_" .. player.UserId
	model:SetAttribute("Owner", player.UserId)
	model:SetAttribute("Home", homeId)
	local d = DataService.get(player)
	model:SetAttribute("PowerOn", d ~= nil and d.Home.PowerOn == true)
	pcall(function()
		model.ModelStreamingMode = Enum.ModelStreamingMode.PersistentPerPlayer
	end)
	model.Parent = folder("MTL_Flats")
	pcall(function()
		model:AddPersistentPlayer(player)
	end)
	takenSlots[slot] = true
	local room: Room = {
		owner = player,
		home = homeId,
		slot = slot,
		model = model,
		origin = origin,
		marks = {},
		parts = {},
		seat = nil,
		prompts = {},
	}
	for name, default in Property.Interior.Points do
		local p = model:FindFirstChild(name, true)
		if p and p:IsA("BasePart") then
			room.parts[name] = p
			room.marks[name] = origin:PointToObjectSpace(p.Position)
		else
			room.marks[name] = default
		end
	end
	for _, extra in { "ExitDoor", "Mattress" } do
		local p = model:FindFirstChild(extra, true)
		if p and p:IsA("BasePart") then
			room.parts[extra] = p
		end
	end
	local seat = model:FindFirstChild("BedSeat", true)
	room.seat = if seat and seat:IsA("Seat") then seat else nil
	-- prompts (this room is only ever reached by its owner, so the server can set the texts)
	local function anchorPart(name: string, lift: number): BasePart
		local base = room.parts[name]
		local pos = if base then base.Position else origin:PointToWorldSpace(room.marks[name])
		local a = Instance.new("Part")
		a.Name = "PromptAt_" .. name
		a.Size = V(0.4, 0.4, 0.4)
		a.Transparency = 1
		a.Anchored = true
		a.CanCollide = false
		a.CanQuery = false
		a.CanTouch = false
		a.Position = pos + V(0, lift, 0)
		a.Parent = model
		return a
	end
	local h = Property.Homes[homeId]
	promptOn(room, "Exit", room.parts.ExitDoor or anchorPart("Exit", 3), { action = "Leave", object = h and h.title or "" })
	promptOn(room, "Bed", anchorPart("BedSeat", 0.8), { action = bedText(player), object = "Bed" })
	promptOn(room, "PC", room.parts.Screen or anchorPart("Screen", 0), { action = "Use PC", object = "PC" })
	promptOn(room, "Breaker", room.parts.Breaker or anchorPart("Breaker", 0), {
		action = "Pay power bill · " .. money(Property.Power.Bill),
		object = "Breaker box",
		hold = 0.5,
	})
	for key, p in room.prompts do
		p.Triggered:Connect(function(who)
			if who == player then
				onRoomPrompt(player, room, key)
			end
		end)
	end
	if d and d.Home.PowerOn then
		room.prompts.Breaker.Enabled = false
	end
	rooms[player] = room
	log(player.Name, "room built in slot", slot, if t then "(Alex's model)" else "(placeholder)")
	return room
end

function PropertyService.room(player: Player): Room?
	local r = rooms[player]
	if r and r.model.Parent then
		return r
	end
	local homeId = homeOf(player)
	if not homeId then
		return nil
	end
	return buildRoom(player, homeId)
end

local function roomCFrame(room: Room, mark: string, faceTo: Vector3?): CFrame
	local p = room.origin:PointToWorldSpace(room.marks[mark])
	local dir = if faceTo then (faceTo - p) else room.origin:VectorToWorldSpace(V(0, 0, -1))
	dir = V(dir.X, 0, dir.Z)
	if dir.Magnitude < 0.01 then
		dir = V(0, 0, -1)
	end
	return CFrame.lookAt(p, p + dir.Unit)
end

local function syncPrompts(player: Player)
	local room = rooms[player]
	if not room then
		return
	end
	room.prompts.Bed.ActionText = bedText(player)
	local d = DataService.get(player)
	room.prompts.Breaker.Enabled = not (d and d.Home.PowerOn)
end

---------------------------------------------------------------- moving in and out

local function unseat(player: Player)
	local hum = humanoid(player)
	if hum and hum.SeatPart then
		local w = hum.SeatPart:FindFirstChild("SeatWeld")
		if w then
			w:Destroy()
		end
		hum.Sit = false
	end
end

local function teleport(player: Player, cf: CFrame, hold: boolean?)
	local char = player.Character
	local r = root(player)
	if not char or not r then
		return
	end
	unseat(player)
	pcall(function()
		player:RequestStreamAroundAsync(cf.Position, 4)
	end)
	-- hold the body still for a moment so it can't drop through a floor that is still streaming in
	local still = hold ~= false
	if still then
		r.Anchored = true
	end
	char:PivotTo(cf + V(0, 3, 0))
	r.AssemblyLinearVelocity = Vector3.zero
	if still then
		task.delay(0.6, function()
			if r.Parent then
				r.Anchored = false
			end
		end)
	end
end

local function setInside(player: Player, room: Room?, on: boolean)
	inside[player] = on
	player:SetAttribute("MTL_InHome", if on and room then room.home else nil)
end

-- Fade -> teleport -> fade in. opts.instant: no fade (spawning). opts.keepBlack: stay black (a cutscene follows).
local function move(player: Player, cf: CFrame, opts: { [string]: any }?)
	local o = opts or {}
	if o.instant then
		teleport(player, cf)
		return
	end
	fire(player, { type = "fade", seconds = Property.Door.FadeOut })
	task.wait(Property.Door.FadeOut)
	pcall(function()
		player:RequestStreamAroundAsync(cf.Position, 4)
	end)
	task.wait(Property.Door.Hold)
	teleport(player, cf)
	if not o.keepBlack then
		fire(player, { type = "arrived" })
	end
end

function PropertyService.enter(player: Player, opts: { [string]: any }?): Room?
	local room = PropertyService.room(player)
	if not room then
		return nil
	end
	if inside[player] then
		return room
	end
	local exitPos = room.origin:PointToWorldSpace(room.marks.Exit)
	local entry = room.origin:PointToWorldSpace(room.marks.Entry)
	move(player, roomCFrame(room, "Entry", entry + (entry - exitPos)), opts)
	setInside(player, room, true)
	syncPrompts(player)
	PropertyService.Entered:Fire(player, room.home)
	return room
end

local function outsideCFrame(homeId: string): CFrame
	local h = Property.Homes[homeId]
	local loc = (Locations :: any)[h and h.location or "EndsFlat"]
	local door, out = loc.Door, loc.Out or (loc.Door + V(0, 0, -8))
	local away = out - door
	away = V(away.X, 0, away.Z)
	if away.Magnitude < 0.01 then
		away = V(0, 0, -1)
	end
	return CFrame.lookAt(out, out + away.Unit)
end

function PropertyService.leave(player: Player, opts: { [string]: any }?)
	local room = rooms[player]
	if not room or not inside[player] then
		return
	end
	move(player, outsideCFrame(room.home), opts)
	setInside(player, room, false)
	PropertyService.Left:Fire(player, room.home)
end

local function seatOnBed(player: Player, room: Room)
	local hum = humanoid(player)
	if not hum or not room.seat then
		return
	end
	local r = root(player)
	if r then
		r.Anchored = false -- a seat can't pull an anchored body onto it
	end
	teleport(player, room.seat.CFrame, false)
	task.wait()
	pcall(function()
		(room.seat :: Seat):Sit(hum)
	end)
end

---------------------------------------------------------------- buying

local function sendListing(player: Player, homeId: string)
	local d = DataService.get(player)
	local h = Property.Homes[homeId]
	if not d or not h then
		return
	end
	local ok, reason, short = PropertyRules.canBuy(d, homeId)
	fire(player, {
		type = "listing",
		home = homeId,
		title = h.title,
		area = h.area,
		price = h.price,
		blurb = h.blurb,
		facts = h.facts,
		photo = h.photo,
		cash = d.Cash,
		canBuy = ok,
		reason = reason,
		short = short,
	})
	Analytics.funnel(player, "Flat", tostring(player.UserId), 1, "Listing")
end

local function doorPosition(homeId: string): Vector3
	for _, p in CollectionService:GetTagged("MTL_FlatDoor") do
		if p:IsA("BasePart") and p:GetAttribute("Id") == homeId then
			return p.Position
		end
	end
	local h = Property.Homes[homeId]
	return ((Locations :: any)[h.location]).Door
end

local function nearDoor(player: Player, homeId: string): boolean
	local r = root(player)
	if not r then
		return false
	end
	local d = r.Position - doorPosition(homeId)
	return Vector2.new(d.X, d.Z).Magnitude <= Property.Door.Radius + 4 and math.abs(d.Y) < 20
end

function PropertyService.give(player: Player, homeId: string)
	local d = DataService.get(player)
	if not d or not Property.Homes[homeId] then
		return
	end
	d.Home.Owned[homeId] = d.Home.Owned[homeId] or os.time()
	d.Home.Current = homeId
	DataService.push(player)
end

local function buy(player: Player, homeId: string)
	local d = DataService.get(player)
	local h = Property.Homes[homeId]
	if not d or not h or busy[player] then
		return
	end
	local ok, reason, short = PropertyRules.canBuy(d, homeId)
	if not ok then
		if short > 0 then
			Notify.toast(player, "You need " .. money(short) .. " more.")
		else
			Notify.toast(player, reason or "Can't buy that")
		end
		sendListing(player, homeId)
		return
	end
	if not nearDoor(player, homeId) then
		Notify.toast(player, "Go to the front door to buy it.")
		return
	end
	if not EconomyService.spend(player, h.price, "Home:" .. homeId) then
		sendListing(player, homeId)
		return
	end
	PropertyService.give(player, homeId)
	fire(player, { type = "listing", close = true, bought = true })
	Notify.banner(player, "IT'S YOURS", h.title .. " · " .. h.area)
	Analytics.funnel(player, "Flat", tostring(player.UserId), 2, "Bought")
	log(player.Name, "bought", homeId, "for", h.price)
	WaypointService.clear(player, "Story")
	PropertyService.Bought:Fire(player, homeId)
	task.wait(1.2) -- let the banner land before the fade
	if not player.Parent then
		return
	end
	if StoryService.stage(player) == "FindAPlace" then
		StoryService.advance(player, "FindAPlace") -- MoveIn walks you in
	else
		PropertyService.enter(player)
	end
end

---------------------------------------------------------------- power

function PropertyService.payPower(player: Player): (boolean, string?)
	local d = DataService.get(player)
	if not d then
		return false, "Loading"
	end
	if not PropertyRules.ownsAny(d) then
		return false, "You don't have a place yet"
	end
	if d.Home.PowerOn then
		return false, "The power's already on"
	end
	local bill = Property.Power.Bill
	if not EconomyService.spend(player, bill, "Bill:Power") then
		return false, "You need " .. money(bill - d.Cash) .. " more for the power bill"
	end
	d.Home.PowerOn = true
	DataService.push(player)
	local room = rooms[player]
	if room then
		room.model:SetAttribute("PowerOn", true)
	end
	syncPrompts(player)
	Notify.toast(player, "Power's on. The light finally stopped flickering.")
	fire(player, { type = "power", on = true })
	PropertyService.PowerChanged:Fire(player, true)
	log(player.Name, "paid the power bill")
	return true, nil
end

---------------------------------------------------------------- scenes

local function playMoveIn(player: Player)
	if busy[player] then
		return
	end
	busy[player] = true
	local d = DataService.get(player)
	if d and not PropertyRules.ownsAny(d) then
		warn("[MTL Property]", player.Name, "is at MoveIn without a home; giving the starter flat")
		PropertyService.give(player, Property.StarterHome)
	end
	local wasInside = inside[player]
	local room = PropertyService.enter(player, { keepBlack = true })
	if not room or not player.Parent then
		busy[player] = nil
		return
	end
	seatOnBed(player, room) -- hidden during the scene; when it ends you're sat right where the scene left you
	CutsceneService.play(player, "PowerOut", { anchor = room.origin, marks = room.marks })
	busy[player] = nil
	if not player.Parent then
		return
	end
	if wasInside then
		fire(player, { type = "arrived" }) -- (no fade was used; harmless)
	end
	StoryService.advance(player, "MoveIn")
end

local function playSleep(player: Player)
	local room = rooms[player]
	if busy[player] or not room or StoryService.stage(player) ~= "FirstNight" then
		return
	end
	busy[player] = true
	fire(player, { type = "bed", on = false })
	seatOnBed(player, room)
	CutsceneService.play(player, "NextDay", { anchor = room.origin, marks = room.marks })
	busy[player] = nil
	if not player.Parent then
		return
	end
	local exitPos = room.origin:PointToWorldSpace(room.marks.Exit)
	teleport(player, roomCFrame(room, "BedStand", exitPos))
	StoryService.advance(player, "FirstNight")
end

---------------------------------------------------------------- prompts

onRoomPrompt = function(player: Player, room: Room, key: string)
	if busy[player] or not limiter:allow(player) then
		return
	end
	if key == "Exit" then
		PropertyService.leave(player)
	elseif key == "Bed" then
		if StoryService.stage(player) == "FirstNight" then
			playSleep(player)
		else
			seatOnBed(player, room)
		end
	elseif key == "PC" then
		local d = DataService.get(player)
		Notify.toast(player, if d and d.Home.PowerOn then Property.PC.OnText else Property.PC.OffText)
	elseif key == "Breaker" then
		local ok, reason = PropertyService.payPower(player)
		if not ok and reason then
			Notify.toast(player, reason)
		end
	end
end

local function makeDoor(homeId: string)
	local h = Property.Homes[homeId]
	local doorPart: BasePart? = nil
	for _, p in CollectionService:GetTagged("MTL_FlatDoor") do
		if p:IsA("BasePart") and p:GetAttribute("Id") == homeId then
			doorPart = p
		end
	end
	if not doorPart then
		local p = Instance.new("Part")
		p.Name = "Door_" .. homeId
		p.Size = V(4, 7, 1)
		p.Transparency = 1
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.Position = doorPosition(homeId) + V(0, 1.5, 0)
		p.Parent = folder("MTL_Property")
		doorPart = p
	end
	assert(doorPart)
	doorPart:SetAttribute("MTL_Home", homeId)
	CollectionService:AddTag(doorPart, "MTL_HomeDoor") -- the client finds it to set its own prompt text + highlight
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "MTL_DoorPrompt"
	prompt.ActionText = "Door" -- each client rewrites this locally ("For sale · $1,200" / "Go inside")
	prompt.ObjectText = h.title .. " · " .. h.area
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Parent = doorPart
	prompt.Triggered:Connect(function(player)
		if busy[player] or not limiter:allow(player) then
			return
		end
		local now = os.clock()
		if lastDoor[player] and now - lastDoor[player] < Property.Door.EnterCooldown then
			return
		end
		lastDoor[player] = now
		local d = DataService.get(player)
		if not d then
			return
		end
		if PropertyRules.owns(d, homeId) then
			if StoryService.stage(player) == "MoveIn" then
				task.spawn(playMoveIn, player)
			else
				PropertyService.enter(player)
			end
		elseif StoryRules.reached(d.Story.Stage, "FindAPlace") then
			sendListing(player, homeId)
		else
			Notify.toast(player, "This place isn't for sale yet.")
		end
	end)
end

---------------------------------------------------------------- the commute funnel (stage 12)

local function refreshCommute(player: Player)
	if StoryService.stage(player) ~= "CommuteToWork" then
		return
	end
	local js = script.Parent:FindFirstChild("JobService")
	local JobService: any = js and require(js) :: any
	if JobService and JobService.isOnShift(player) then
		StoryService.advance(player, "CommuteToWork")
		return
	end
	local room = rooms[player]
	if inside[player] and room then
		local door = room.origin:PointToWorldSpace(room.marks.Exit)
		WaypointService.set(player, "Story", door, { label = "Front door", radius = 2.5, breadcrumbs = false })
		Notify.objective(player, "Head out to work: use the front door")
		fire(player, { type = "exit", on = true })
		return
	end
	fire(player, { type = "exit", on = false })
	local pos, label = nil, nil
	if JobService then
		pos, label = JobService.workplace(player)
	end
	if not pos then
		Notify.objective(player, "Pick a job in your phone's Jobs app")
		return
	end
	local def = Jobs.Defs[JobService.current(player)]
	local loc = def and (Locations :: any)[def.site]
	WaypointService.set(player, "Story", pos, { label = "Work: " .. tostring(label), radius = (loc and loc.Radius) or 14 })
	Notify.objective(player, "Get to work: " .. tostring(label))
end

local function refreshNight(player: Player)
	if StoryService.stage(player) ~= "FirstNight" then
		return
	end
	if inside[player] then
		WaypointService.clear(player, "Story")
		Notify.objective(player, "Get some sleep. Work starts tomorrow.")
		fire(player, { type = "bed", on = true })
	else
		fire(player, { type = "bed", on = false })
		local homeId = homeOf(player)
		if homeId then
			WaypointService.set(player, "Story", doorPosition(homeId), { label = "Home", radius = Property.Door.Radius })
			Notify.objective(player, "Go home and get some sleep")
		end
	end
end

---------------------------------------------------------------- init

function PropertyService.init()
	for id in Property.Homes do
		makeDoor(id)
	end

	Net.get("PropertyAction").OnServerEvent:Connect(function(player, payload)
		if type(payload) ~= "table" or not limiter:allow(player) then
			return
		end
		if payload.type == "buy" and type(payload.home) == "string" and Property.Homes[payload.home] then
			task.spawn(buy, player, payload.home)
		end
	end)
	PhoneService.onAction("payPower", function(player)
		local ok, reason = PropertyService.payPower(player)
		if not ok and reason then
			Notify.toast(player, reason)
		end
	end)

	-- 8. FindAPlace
	StoryService.onEnter("FindAPlace", function(player)
		local d = DataService.get(player)
		if not d then
			return
		end
		if PropertyRules.ownsAny(d) then
			StoryService.advance(player, "FindAPlace")
			return
		end
		local homeId = Property.StarterHome
		local h = Property.Homes[homeId]
		WaypointService.set(player, "Story", doorPosition(homeId), { label = h.title .. " · for sale", radius = Property.Door.Radius })
		Notify.objective(player, "Buy the flat in the Ends: " .. money(h.price))
		local sd = StoryService.data(player)
		if sd and not sd.FlatTexted then
			sd.FlatTexted = true
			task.wait(1.2)
			for i, t in Property.Texts.FindAPlace do
				PhoneService.text(player, t.who, if t.link then (t.text .. " It's on your map.") else t.text)
				if i < #Property.Texts.FindAPlace then
					task.wait(1.6)
				end
			end
		end
	end)
	WaypointService.Arrived:Connect(function(player, id)
		if id ~= "Story" then
			return
		end
		local stage = StoryService.stage(player)
		if stage == "FindAPlace" then
			sendListing(player, Property.StarterHome) -- the card pops up when you reach the door
			Notify.objective(player, "Buy the flat: " .. money(Property.Homes[Property.StarterHome].price))
		elseif stage == "CommuteToWork" and not inside[player] then
			Notify.objective(player, "Clock in at the time clock")
		elseif stage == "FirstNight" and not inside[player] then
			Notify.objective(player, "Go inside and get some sleep")
		end
	end)

	-- 9. MoveIn
	StoryService.onEnter("MoveIn", function(player)
		playMoveIn(player)
	end)

	-- 10. ChooseJob: the phone opens on the Jobs app (the client waits until the scene is over)
	StoryService.onEnter("ChooseJob", function(player)
		WaypointService.clear(player, "Story")
		fire(player, { type = "phone", app = "Jobs" })
	end)

	-- 11. FirstNight / 12. CommuteToWork
	StoryService.onEnter("FirstNight", function(player)
		syncPrompts(player)
		refreshNight(player)
	end)
	StoryService.onEnter("CommuteToWork", function(player, resumed)
		syncPrompts(player)
		if not resumed then
			local d = DataService.get(player)
			local def = d and Jobs.Defs[d.Job.Current]
			local boss = def and def.boss
			task.wait(1.4)
			if boss then
				PhoneService.text(player, boss, Property.Texts.Wake[boss] or Property.Texts.Wake.default)
			end
		end
		refreshCommute(player)
	end)

	-- 13. FreePlay: the Goals app + one welcome text (GoalService keeps the objective line on the next goal)
	StoryService.onEnter("FreePlay", function(player, resumed)
		PhoneService.unlockApp(player, "Goals")
		syncPrompts(player)
		if not resumed then
			Notify.banner(player, "FREE PLAY", "Work, hustle, get rich. Your call.")
			task.wait(2.5)
			PhoneService.text(player, Property.Texts.FreePlay.who, Property.Texts.FreePlay.text)
		end
	end)

	PropertyService.Entered:Connect(function(player)
		refreshCommute(player)
		refreshNight(player)
	end)
	PropertyService.Left:Connect(function(player)
		refreshCommute(player)
		refreshNight(player)
	end)
	StoryService.StageChanged:Connect(function(player)
		syncPrompts(player)
	end)

	-- returning players wake up at home (first spawn of the session); a respawn puts you outside like normal
	DataService.Ready:Connect(function(player, data)
		task.spawn(function()
			local char = player.Character or player.CharacterAdded:Wait()
			if not char then
				return
			end
			char:WaitForChild("HumanoidRootPart", 10)
			task.wait(0.3)
			if player.Parent and PropertyRules.spawnsAtHome(data) and data.Story.Stage ~= "MoveIn" then
				PropertyService.enter(player, { instant = true })
			end
		end)
	end)
	local function watch(player: Player)
		player.CharacterAdded:Connect(function()
			if inside[player] then
				setInside(player, rooms[player], false)
			end
			task.delay(1.5, function()
				if player.Parent then
					refreshCommute(player)
					refreshNight(player)
				end
			end)
		end)
	end
	Players.PlayerAdded:Connect(watch)
	for _, p in Players:GetPlayers() do
		watch(p)
	end
	Players.PlayerRemoving:Connect(function(player)
		local room = rooms[player]
		if room then
			takenSlots[room.slot] = nil
			room.model:Destroy()
		end
		rooms[player] = nil
		inside[player] = nil
		busy[player] = nil
		lastDoor[player] = nil
	end)

	-- respawned / rejoined clients re-get their home state (door text, bed glow)
	Net.get("ClientReady").OnServerEvent:Connect(function(player)
		local stage = StoryService.stage(player)
		if stage == "FirstNight" then
			fire(player, { type = "bed", on = inside[player] == true })
		elseif stage == "CommuteToWork" then
			fire(player, { type = "exit", on = inside[player] == true })
		end
	end)
	log("ready")
end

-- Studio helpers (server Command Bar): _G.MTL.Property.debug(player) gives the flat and walks you in;
-- _G.MTL.Property.leave(player) / _G.MTL.Property.payPower(player).
function PropertyService.debug(player: Player)
	assert(RunService:IsStudio(), "Studio-only")
	PropertyService.give(player, Property.StarterHome)
	task.spawn(PropertyService.enter, player)
end

return PropertyService
