--!strict
-- The Miami look (MTL_LightingDirector): warm gold days, orange-pink sunsets, purple-blue nights.
-- Shared by the server script ServerScriptService.MTL_LightingDirector (makes the effects, sets the static
-- settings) and the client LightingController (blends these keys every few frames). Only the client writes the
-- look at runtime, so the two never fight; the server sets the workspace attribute MTL_LightingDirector = true.
-- Clock: the game's own TimeService clock (Config/DayNight phases), not a separate day length.
-- The grade stays within ~25 of white (sat <= 0.16): warmth comes from Atmosphere and ColorShift_Top, never a pink grade.
-- Atmosphere colours follow the LihFolk sky picks (lighting.json): blue day haze, amber golden hour, navy night.
-- Keys are timed to Roblox's real sun: it sets at ~18.0, so the sunset key is 17.6, purple dusk 18.3, night 19.2.
local Lighting = game:GetService("Lighting")

local MiamiLook = {}

local C = Color3.fromRGB
-- br Brightness, exp ExposureCompensation, amb Ambient, out OutdoorAmbient, top ColorShift_Top,
-- aCol/aDec/den/haze/glare Atmosphere, tint/sat/con grade, bI/bS/bT bloom, sun SunRays intensity
local K = {
	{ t = 0,    br = 1.6, exp = 0.5,  amb = C(38,42,68),  out = C(96,104,156), top = C(170,160,220), aCol = C(40,44,78),   aDec = C(28,30,60) ,   den = 0.3,  haze = 1.1, glare = 0,   tint = C(230,228,255), sat = 0.04, con = 0.12, bI = 1.0, bS = 30, bT = 0.95,sun = 0 },
	{ t = 5.5,  br = 1.6, exp = 0.45, amb = C(42,36,58),  out = C(112,100,146),top = C(190,160,220), aCol = C(120,100,150),aDec = C(76,56,100),  den = 0.32, haze = 1.7, glare = 0.2, tint = C(236,230,255), sat = 0.06, con = 0.12, bI = 0.9, bS = 28, bT = 1.0, sun = 0.05 },
	{ t = 6.8,  br = 2.0, exp = 0.1,  amb = C(50,36,46),  out = C(160,120,130),top = C(255,180,150), aCol = C(240,170,150),aDec = C(170,100,120), den = 0.32, haze = 2.0, glare = 0.8, tint = C(255,240,230), sat = 0.12, con = 0.1,  bI = 0.8, bS = 30, bT = 1.2, sun = 0.14 },
	{ t = 9,    br = 3.0, exp = 0,    amb = C(44,40,46),  out = C(140,134,136),top = C(255,240,220), aCol = C(200,212,228),aDec = C(140,160,190), den = 0.27, haze = 0.9, glare = 0.3, tint = C(255,248,240), sat = 0.14, con = 0.08, bI = 0.55,bS = 24, bT = 1.7, sun = 0.06 },
	{ t = 13,   br = 3.4, exp = -0.05,amb = C(44,42,48),  out = C(140,138,142),top = C(255,246,230), aCol = C(196,214,236),aDec = C(150,175,210), den = 0.25, haze = 0.7, glare = 0.15, tint = C(255,250,242), sat = 0.16, con = 0.08, bI = 0.5, bS = 24, bT = 1.8, sun = 0.05 },
	{ t = 16.5, br = 3.0, exp = 0,    amb = C(52,42,44),  out = C(156,130,120),top = C(255,214,170), aCol = C(222,190,162),aDec = C(190,165,160), den = 0.3, haze = 1.4, glare = 0.45, tint = C(255,242,230), sat = 0.14,  con = 0.1,  bI = 0.65,bS = 26, bT = 1.5, sun = 0.1 },
	{ t = 17.6, br = 2.4, exp = 0.15, amb = C(60,44,50),  out = C(164,136,134),top = C(255,170,110), aCol = C(232,178,150),aDec = C(196,150,150), den = 0.32, haze = 1.6, glare = 0.5, tint = C(255,236,222), sat = 0.12,  con = 0.1,  bI = 0.85,bS = 32, bT = 1.2, sun = 0.2 },
	{ t = 18.3, br = 1.8, exp = 0.4,  amb = C(54,40,66),  out = C(132,114,150),top = C(220,140,175), aCol = C(92,80,122),  aDec = C(58,50,88)  ,  den = 0.32, haze = 1.6, glare = 0.5, tint = C(248,232,246), sat = 0.12, con = 0.12, bI = 1.0, bS = 32, bT = 1.0, sun = 0.06 },
	{ t = 19.2, br = 1.6, exp = 0.5,  amb = C(38,42,68),  out = C(96,104,156), top = C(170,160,220), aCol = C(40,44,78),   aDec = C(28,30,60) ,   den = 0.3,  haze = 1.1, glare = 0,   tint = C(230,228,255), sat = 0.04, con = 0.12, bI = 1.0, bS = 30, bT = 0.95,sun = 0 },
}
local last = table.clone(K[1])
last.t = 24
table.insert(K, last)
MiamiLook.Keys = K

MiamiLook.AtmoOffset = 0.18
MiamiLook.RaysSpread = 0.7
MiamiLook.Blur = { FocusDistance = 140, InFocusRadius = 120, NearIntensity = 0, FarIntensity = 0.12 }

-- Street lamps: every StreetLight / ParkLamp head has a saved light named and tagged "MTL_NightLight" (SpotLight
-- facing down, Shadows off). LightingController switches them: on near the camera only (Radius), fading with lamps().
MiamiLook.NightLights = { Radius = 420, Brightness = 5, ParkBrightness = 2 } -- spot Range 55, Angle 110

local function smooth(a: number, b: number, x: number): number
	local t = math.clamp((x - a) / (b - a), 0, 1)
	return t * t * (3 - 2 * t)
end

-- 0..1 street lamp level: on through 18.2-18.9 (fully on ~18.6), off through 6.0-6.6
function MiamiLook.lamps(clock: number): number
	clock %= 24
	return math.max(smooth(18.2, 18.9, clock), 1 - smooth(6.0, 6.6, clock))
end

-- Skyboxes (LihFolk pack): Sky instances in ReplicatedStorage, swapped on the client by LightingController.
-- Day 6.8-16.5, Golden 16.5-18.0, Night the rest. Missing skies = no swap (the place's own sky rules apply).
MiamiLook.Skies = {
	{ name = "MTL_Sky_Day", from = 6.8, to = 16.5 },
	{ name = "MTL_Sky_Golden", from = 16.5, to = 18.0 },
}
MiamiLook.NightSky = "MTL_Sky_Night"

function MiamiLook.skyFor(clock: number): string
	clock %= 24
	for _, s in MiamiLook.Skies do
		if clock >= s.from and clock < s.to then
			return s.name
		end
	end
	return MiamiLook.NightSky
end

-- the instances the look drives (names the server script makes them with)
export type Refs = {
	atmosphere: Atmosphere,
	grade: ColorCorrectionEffect,
	bloom: BloomEffect,
	rays: SunRaysEffect,
}

function MiamiLook.find(): Refs?
	local atm = Lighting:FindFirstChildOfClass("Atmosphere")
	local grade = Lighting:FindFirstChild("MTL_Grade")
	local bloom = Lighting:FindFirstChild("MTL_Bloom")
	local rays = Lighting:FindFirstChild("MTL_SunRays")
	if not (atm and grade and bloom and rays) then
		return nil
	end
	return { atmosphere = atm, grade = grade :: ColorCorrectionEffect, bloom = bloom :: BloomEffect, rays = rays :: SunRaysEffect }
end

local function lerp(a: any, b: any, f: number): any
	if typeof(a) == "Color3" then
		return (a :: Color3):Lerp(b, f)
	end
	return a + (b - a) * f
end

-- exposureAdd / thresholdAdd: the client's indoor eye adaptation
function MiamiLook.apply(clock: number, refs: Refs, exposureAdd: number?, thresholdAdd: number?)
	clock %= 24
	local a, b = K[1], K[2]
	for i = 1, #K - 1 do
		if clock >= K[i].t and clock < K[i + 1].t then
			a, b = K[i], K[i + 1]
			break
		end
	end
	local f = (clock - a.t) / (b.t - a.t)
	f = f * f * (3 - 2 * f)
	local function v(k: string): any
		return lerp((a :: any)[k], (b :: any)[k], f)
	end
	Lighting.Brightness = v("br")
	Lighting.ExposureCompensation = v("exp") + (exposureAdd or 0)
	Lighting.Ambient = v("amb")
	Lighting.OutdoorAmbient = v("out")
	Lighting.ColorShift_Top = v("top")
	local atm = refs.atmosphere
	atm.Color = v("aCol")
	atm.Decay = v("aDec")
	atm.Density = v("den")
	atm.Haze = v("haze")
	atm.Glare = v("glare")
	atm.Offset = MiamiLook.AtmoOffset
	refs.grade.TintColor = v("tint")
	refs.grade.Saturation = v("sat")
	refs.grade.Contrast = v("con")
	refs.grade.Brightness = 0
	refs.bloom.Intensity = v("bI")
	refs.bloom.Size = v("bS")
	refs.bloom.Threshold = v("bT") + (thresholdAdd or 0)
	refs.rays.Intensity = v("sun")
	refs.rays.Spread = MiamiLook.RaysSpread
end

return MiamiLook
