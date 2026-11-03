--!strict
-- Draws the time of day on this client (Master Plan §4 "Lighting and time of day"; looks in Config/DayNight).
--   * the clock comes from the server (TimeService: Workspace attributes MTL_DayEpoch / MTL_DayFrozen) and the sun
--     moves every frame; the rest of the look (ambient, atmosphere, grade, bloom, sun rays, clouds) is blended
--     between the keyframes a few times a second
--   * street lights: lamp heads glow sodium orange at night (each switches at a slightly different moment), and
--     the closest lamps to the camera get real SpotLights (a fixed pool, so the cost never grows with the map)
--   * eye adaptation: under a roof the exposure drops and bloom backs off (DayNight.Indoor), so interiors keep shape
--   * story holds: a cutscene can show THIS player another time without touching anyone else. PowerOut = night,
--     NextDay = night, then morning on the "WorldMorning" beat. A hold made in a room ends when you walk out.
-- API:
--   LightingController.clock() -> hour 0-24 (what this player sees)
--   LightingController.phase() -> "Morning" | "Day" | "Evening" | "Night"
--   LightingController.hold(hour, blendSeconds?, untilLeaveRoom?)   LightingController.release(blendSeconds?)
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")

local DayNight = require(ReplicatedStorage.MTL.Config.DayNight)
local DayNightRules = require(ReplicatedStorage.MTL.Rules.DayNightRules)
local Cutscene = require(script.Parent.CutsceneController)
local MiamiLook = require(ReplicatedStorage.MTL.Config.MiamiLook)
local Quality = require(ReplicatedStorage.MTL.Config.Quality)

local player = Players.LocalPlayer
local LightingController = {}

-- this client's graphics tier (QualityController sets the attribute; Config/Quality.Tiers)
local function qualityLook(): any
	return Quality.Tiers[player:GetAttribute("MTL_QualityTier") or "High"] or Quality.Tiers.High
end

-- scale an effect by the tier; one the tier switched off comes back on when the tier allows it again
local function scaleEffect(e: BloomEffect | SunRaysEffect, k: number)
	e.Intensity *= k
	if k <= 0 then
		if e.Enabled then
			e.Enabled = false
			e:SetAttribute("MTL_QualityOff", true)
		end
	elseif e:GetAttribute("MTL_QualityOff") then
		e:SetAttribute("MTL_QualityOff", nil)
		e.Enabled = true
	end
end

local function applyQuality(b: BloomEffect, r: SunRaysEffect)
	local q = qualityLook()
	scaleEffect(b, q.Bloom)
	scaleEffect(r, q.SunRays)
	local blur = Lighting:FindFirstChild("MTL_DistanceBlur")
	if blur and blur:IsA("DepthOfFieldEffect") and blur.Enabled ~= q.DistanceBlur then
		blur.Enabled = q.DistanceBlur
	end
end

local LOOK_EVERY = 0.12 -- seconds between full look blends (the sun itself moves every frame)

-- the instances we drive (the place's own ones are taken over; missing ones are made)
local atmosphere: Atmosphere
local grade: ColorCorrectionEffect
local bloom: BloomEffect
local rays: SunRaysEffect
local clouds: Clouds?

type Hold = {
	hour: number,
	from: number, -- clock shown when the hold (or release) started
	start: number,
	blend: number,
	room: boolean,
	releasing: boolean,
}
local hold: Hold? = nil
local shownClock = DayNight.StartClock
local lampsValue = 0
local indoor = 0 -- 0 outdoors .. 1 indoors (eased), see DayNight.Indoor
local indoorTarget = 0

local function find(className: string, name: string): any
	local inst = Lighting:FindFirstChild(name)
	if inst and inst.ClassName == className then
		return inst
	end
	inst = Lighting:FindFirstChildOfClass(className :: any)
	if inst and className ~= "ColorCorrectionEffect" then
		return inst
	end
	local made = Instance.new(className :: any)
	made.Name = name
	made.Parent = Lighting
	return made
end

local function worldClock(): number
	local frozen = workspace:GetAttribute("MTL_DayFrozen")
	if type(frozen) == "number" then
		return frozen
	end
	local epoch = workspace:GetAttribute("MTL_DayEpoch")
	if type(epoch) ~= "number" then
		return DayNight.StartClock
	end
	return DayNightRules.clockAt(workspace:GetServerTimeNow() - epoch)
end

local function inRoom(): boolean
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	return root ~= nil and root.Position.Y > DayNight.RoomArea.MinY
end

local function currentClock(): number
	local world = worldClock()
	local h = hold
	if not h then
		return world
	end
	local target = if h.releasing then world else h.hour
	local a = if h.blend <= 0 then 1 else math.clamp((os.clock() - h.start) / h.blend, 0, 1)
	a = a * a * (3 - 2 * a)
	if h.releasing and a >= 1 then
		hold = nil
		return world
	end
	return (h.from + DayNightRules.clockDelta(h.from, target) * a) % 24
end

function LightingController.clock(): number
	return shownClock
end

function LightingController.phase(): string
	return DayNightRules.phaseOf(shownClock)
end

function LightingController.hold(hour: number, blendSeconds: number?, untilLeaveRoom: boolean?)
	hold = {
		hour = hour % 24,
		from = shownClock,
		start = os.clock(),
		blend = blendSeconds or 0,
		room = untilLeaveRoom == true,
		releasing = false,
	}
end

function LightingController.release(blendSeconds: number?)
	local h = hold
	if not h or h.releasing then
		return
	end
	h.releasing = true
	h.from = shownClock
	h.start = os.clock()
	h.blend = blendSeconds or 3
end

----------------------------------------------------------------------------------------------------------------
-- the look

local function lerpN(a: number, b: number, t: number): number
	return a + (b - a) * t
end

-- eye adaptation: a roof over the camera = indoors (one ray straight up; the player's own character is ignored)
local roofParams = RaycastParams.new()
roofParams.FilterType = Enum.RaycastFilterType.Exclude
roofParams.IgnoreWater = true
local function checkIndoor()
	local cam = workspace.CurrentCamera
	local char = player.Character
	roofParams.FilterDescendantsInstances = if char then { char } else {}
	local hit = workspace:Raycast(cam.CFrame.Position, Vector3.new(0, DayNight.Indoor.Height, 0), roofParams)
	-- glass, leaves and see-through parts don't count as a roof
	indoorTarget = if hit and hit.Instance.Transparency < 0.5 and hit.Material ~= Enum.Material.Glass then 1 else 0
end

-- Miami skyboxes: one client-side copy in Lighting, swapped when the clock crosses a sky's range
local shownSky: string? = nil
local function updateSky(clock: number)
	local want = MiamiLook.skyFor(clock)
	if want == shownSky then
		return
	end
	local source = ReplicatedStorage:FindFirstChild(want)
	if not (source and source:IsA("Sky")) then
		return -- skies not installed: leave the place's sky rules alone
	end
	shownSky = want
	for _, s in Lighting:GetChildren() do
		if s:IsA("Sky") then
			s.Parent = nil -- this client only (the map sky, or the last Miami sky)
		end
	end
	local sky = source:Clone()
	sky.Name = "MTL_ActiveSky"
	sky.Parent = Lighting
end

local function applyLook(clock: number)
	local a, b, t = DayNightRules.sample(clock)
	local function n(k: string): number
		return lerpN(a[k], b[k], t)
	end
	local function c(k: string): Color3
		return (a[k] :: Color3):Lerp(b[k], t)
	end
	-- MTL_LightingDirector (server) is on: the Miami keys own the look; clouds and lamps still come from DayNight
	local miami = if workspace:GetAttribute("MTL_LightingDirector") then MiamiLook.find() else nil
	if miami then
		MiamiLook.apply(clock, miami, DayNight.Indoor.Exposure * indoor, DayNight.Indoor.Threshold * indoor)
		updateSky(clock)
		applyQuality(miami.bloom, miami.rays)
		local cl = clouds
		if cl then
			cl.Cover = n("Cover")
			cl.Density = n("CloudDensity")
			cl.Color = c("CloudColor")
		end
		lampsValue = MiamiLook.lamps(clock)
		return
	end
	Lighting.Brightness = n("Brightness")
	Lighting.ExposureCompensation = n("Exposure") + DayNight.Indoor.Exposure * indoor
	Lighting.Ambient = c("Ambient")
	Lighting.OutdoorAmbient = c("Outdoor")
	Lighting.ColorShift_Top = c("Top")
	Lighting.ColorShift_Bottom = c("Bottom")
	Lighting.EnvironmentDiffuseScale = n("EnvDiffuse")
	Lighting.EnvironmentSpecularScale = n("EnvSpecular")
	Lighting.ShadowSoftness = n("Softness")
	atmosphere.Density = n("Density")
	atmosphere.Offset = n("Offset")
	atmosphere.Color = c("AtmoColor")
	atmosphere.Decay = c("Decay")
	atmosphere.Glare = n("Glare")
	atmosphere.Haze = n("Haze")
	grade.Brightness = n("GBright")
	grade.Contrast = n("Contrast")
	grade.Saturation = n("Saturation")
	grade.TintColor = c("Tint")
	bloom.Intensity = n("Bloom")
	bloom.Size = n("BloomSize")
	bloom.Threshold = n("Threshold") + DayNight.Indoor.Threshold * indoor
	rays.Intensity = n("Rays")
	rays.Spread = n("Spread")
	applyQuality(bloom, rays)
	local cl = clouds
	if cl then
		cl.Cover = n("Cover")
		cl.Density = n("CloudDensity")
		cl.Color = c("CloudColor")
	end
	lampsValue = n("Lamps")
end

----------------------------------------------------------------------------------------------------------------
-- street lights

local L = DayNight.Lamps
-- own: the lamp's saved MTL_NightLight (every pole has one, tag "MTL_NightLight"); lamps without one borrow from the pool
type Lamp = { head: BasePart, park: boolean, threshold: number, on: boolean?, light: Light?, own: Light?, glowOnly: boolean? }
local lamps: { [BasePart]: Lamp } = {}
local spotPool: { SpotLight } = {}
local pointPool: { PointLight } = {}
local lit: { Lamp } = {}

local function register(part: Instance)
	if not part:IsA("BasePart") or lamps[part] then
		return
	end
	if part.Material ~= Enum.Material.Neon and not part:GetAttribute("MTL_LampHead") then
		return
	end
	local model = part.Parent
	if not model or not model:IsA("Model") or not L.Models[model.Name] then
		return
	end
	lamps[part] = {
		head = part,
		park = model.Name ~= "StreetLight",
		threshold = L.On + (math.random() - 0.5) * 0.3, -- staggered switch-on, like real photocells
		own = part:FindFirstChild("MTL_NightLight") :: Light?,
		-- a second head on a pole whose light sits on the other head: glow only, no pool light
		glowOnly = part:FindFirstChild("MTL_NightLight") == nil and model:FindFirstChild("MTL_NightLight", true) ~= nil,
	}
	-- apply the current state right away (streamed in mid-night)
	local on = lampsValue >= lamps[part].threshold
	part.Material = if on then Enum.Material.Neon else Enum.Material.SmoothPlastic
	part.Color = if on then L.HeadNight else L.HeadDay
	lamps[part].on = on
end

local function takeLight(park: boolean): Light
	if park then
		local l = table.remove(pointPool)
		if l then
			return l
		end
		local p = Instance.new("PointLight")
		p.Name = "MTL_LampLight"
		p.Color = L.ParkLight.Color
		p.Range = L.ParkLight.Range
		p.Shadows = false
		return p
	end
	local s = table.remove(spotPool)
	if s then
		return s
	end
	local sp = Instance.new("SpotLight")
	sp.Name = "MTL_LampLight"
	sp.Face = Enum.NormalId.Bottom
	sp.Color = L.Light.Color
	sp.Range = L.Light.Range
	sp.Angle = L.Light.Angle
	return sp
end

local function giveBack(lamp: Lamp)
	local l = lamp.light
	if not l then
		return
	end
	lamp.light = nil
	l.Parent = nil
	if l:IsA("SpotLight") then
		table.insert(spotPool, l)
	elseif l:IsA("PointLight") then
		table.insert(pointPool, l)
	end
end

local function refreshLamps()
	local camPos = workspace.CurrentCamera.CFrame.Position
	local q = qualityLook()
	local candidates = {}
	local owned = {}
	-- lights fade in with the lamps value, so dusk isn't a pop
	local strength = math.clamp((lampsValue - 0.3) / 0.7, 0, 1)
	for head, lamp in lamps do
		if not head.Parent then
			giveBack(lamp)
			lamps[head] = nil
			continue
		end
		local on = lampsValue >= lamp.threshold
		if on ~= lamp.on then
			lamp.on = on
			head.Material = if on then Enum.Material.Neon else Enum.Material.SmoothPlastic
			head.Color = if on then L.HeadNight else L.HeadDay
		end
		local own = lamp.own
		if own then
			-- the pole's own light: only the closest ones near the camera (graphics tier), so the live count stays small
			local d = (head.Position - camPos).Magnitude
			if on and d < q.LampRadius then
				table.insert(owned, { light = own, d = d, park = lamp.park })
			elseif own.Enabled then
				own.Enabled = false
			end
			continue
		end
		if on and not lamp.glowOnly then
			local d = (head.Position - camPos).Magnitude
			if d < math.min(L.Radius, q.LampRadius) then
				table.insert(candidates, { lamp = lamp, d = d })
			end
		end
	end
	table.sort(candidates, function(x, y)
		return x.d < y.d
	end)
	local keep: { [Lamp]: number } = {}
	for i = 1, math.min(#candidates, L.MaxLights, q.MaxLamps) do
		keep[candidates[i].lamp] = i
	end
	for _, lamp in lit do
		if not keep[lamp] then
			giveBack(lamp)
		end
	end
	lit = {}
	-- shadows only on the closest few street lamps (Future lighting)
	table.sort(owned, function(x, y)
		return x.d < y.d
	end)
	local shadows = 0
	for i, o in owned do
		local want = i <= q.MaxLamps
		if o.light.Enabled ~= want then
			o.light.Enabled = want
		end
		if want then
			o.light.Brightness = (if o.park then MiamiLook.NightLights.ParkBrightness else MiamiLook.NightLights.Brightness) * strength
		end
		local cast = want and not o.park and shadows < q.LampShadows
		if cast then
			shadows += 1
		end
		if o.light.Shadows ~= cast then
			o.light.Shadows = cast
		end
	end
	for lamp, rank in keep do
		local l = lamp.light or takeLight(lamp.park)
		lamp.light = l
		l.Brightness = (if lamp.park then L.ParkLight.Brightness else L.Light.Brightness) * strength
		l.Shadows = (not lamp.park) and rank <= q.LampShadows
		l.Parent = lamp.head
		table.insert(lit, lamp)
	end
end

----------------------------------------------------------------------------------------------------------------

function LightingController.init()
	atmosphere = find("Atmosphere", "Atmosphere")
	grade = find("ColorCorrectionEffect", "ColorCorrection")
	bloom = find("BloomEffect", "Bloom")
	rays = find("SunRaysEffect", "SunRays")
	clouds = workspace.Terrain:FindFirstChildOfClass("Clouds")
	Lighting.GlobalShadows = true
	Lighting.GeographicLatitude = DayNight.Latitude
	if DayNight.HideMapSky then
		local sky = Lighting:FindFirstChildOfClass("Sky")
		if sky then
			sky.Parent = nil -- this client only; the place keeps its Sky
		end
	end
	Lighting.FogEnd = 100000 -- the Atmosphere does the haze

	shownClock = worldClock()
	applyLook(shownClock)

	-- lamps: what's streamed in now + whatever streams in later
	local map = workspace:FindFirstChild("ViceBay")
	if map then
		for _, d in map:GetDescendants() do
			register(d)
		end
	end
	workspace.DescendantAdded:Connect(function(d)
		if d:IsA("BasePart") and d.Material == Enum.Material.Neon then
			task.defer(register, d) -- parent model name is set by then
		end
	end)

	-- story holds (only this player sees them)
	local sceneHold = false -- a scene's own `hour` (Research: Cinematic Cutscenes §4), released when it ends
	Cutscene.Started:Connect(function(id, scene)
		if id == "PowerOut" then
			LightingController.hold(DayNight.Story.MoveIn, 0, true)
		elseif id == "NextDay" then
			LightingController.hold(DayNight.Story.Sleep, 0, true)
		elseif type(scene) == "table" and type(scene.hour) == "number" then
			LightingController.hold(scene.hour, 0)
			sceneHold = true
		end
	end)
	Cutscene.Finished:Connect(function()
		if sceneHold then
			sceneHold = false
			LightingController.release(4)
		end
	end)
	Cutscene.registerAction("WorldMorning", function()
		LightingController.hold(DayNight.Story.Wake, 0, true)
	end)

	-- small mood filters on top of the look (grade split, far blur, vignette, dust)
	require(script.Parent.MoodFX).init(LightingController)

	local lookTimer, lampTimer, roofTimer = 0, 0, 0
	RunService.Heartbeat:Connect(function(dt)
		local h = hold
		if h and h.room and not h.releasing and not Cutscene.isPlaying() and not inRoom() then
			LightingController.release(2.5)
		end
		shownClock = currentClock()
		Lighting.ClockTime = shownClock
		roofTimer += dt
		if roofTimer >= DayNight.Indoor.Check then
			roofTimer = 0
			checkIndoor()
		end
		indoor += (indoorTarget - indoor) * math.clamp(dt / DayNight.Indoor.Blend * 3, 0, 1)
		lookTimer += dt
		if lookTimer >= LOOK_EVERY then
			lookTimer = 0
			applyLook(shownClock)
		end
		lampTimer += dt
		if lampTimer >= L.Refresh then
			lampTimer = 0
			refreshLamps()
		end
	end)
end

return LightingController
