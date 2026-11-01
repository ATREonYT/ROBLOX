---
tags: [build-playbooks, realistic, lighting, atmosphere, post-processing, day-night]
updated: 2026-11-01
---

# 34 Realistic Lighting and Atmosphere

Back to [[33 Realistic World Building Playbook]] · [[00 Build Router]] · Presets measured from Alex's Larp photos: [[41 Larp Reference Study - Atmosphere, Surfaces and Feel]] §3 · Deep reference: `LihFolk/LihFolk Vault V2/07 Lighting VFX and Audio/` (Lighting Technologies and Settings, Atmosphere Sky Clouds and Post-Processing, Light Sources and Shadows, Lighting Mood and Time of Day)

> **TL;DR**
> - **Realistic maps use `LightingStyle = Realistic` + `PrioritizeLightingQuality = true`** (the old "Future"). The cartoony rule in [[Brief - Worlds, Lighting and Performance]] (Soft + true) is for our cartoony games only.
> - **`EnvironmentDiffuseScale` and `EnvironmentSpecularScale` at 1** so PBR materials pick up the sky. Without this, PBR looks flat and plastic (Roblox docs, outdoor lighting tutorial).
> - **Atmosphere does the heavy lifting:** it sets mood, hides the map edge and sells scale. Match its `Color` to the average colour of the world and its `Decay` to the sky's horizon.
> - **Post stack, in this order:** ColorCorrection (small moves), Bloom (high threshold so only lights glow), SunRays (low), DepthOfField (only for cutscenes and menus, off in gameplay).
> - **Phones turn shadows off below graphics quality 4.** The scene must read by value and colour alone. Test at quality 1.
> - **Set lighting first, then build.** Every material and colour choice is wrong under default lighting.

---

## 1. The lighting stack, layer by layer

| Layer | What it does for realism | Key properties |
|---|---|---|
| `Lighting` (global) | Sun strength and colour, shade colour, shadow softness | `LightingStyle`, `Brightness`, `Ambient`, `OutdoorAmbient`, `ColorShift_Top`, `ColorShift_Bottom`, `EnvironmentDiffuseScale`, `EnvironmentSpecularScale`, `ShadowSoftness`, `ClockTime`, `GeographicLatitude`, `ExposureCompensation` |
| `Sky` | What reflects in PBR and water; the horizon colour | Skybox faces, `SunAngularSize`, `MoonAngularSize`, `StarCount` |
| `Atmosphere` | Air: haze, distance fade, sun glow | `Density`, `Offset`, `Color`, `Decay`, `Glare`, `Haze` |
| `Clouds` (under Terrain) | Moving 3D clouds; react to `GlobalWind` | `Cover`, `Density`, `Color` |
| `ColorCorrectionEffect` | Final grade | `Brightness`, `Contrast`, `Saturation`, `TintColor` |
| `BloomEffect` | Glow on bright lights and wet highlights | `Intensity`, `Size`, `Threshold` |
| `SunRaysEffect` | God rays past buildings and trees | `Intensity`, `Spread` |
| `DepthOfFieldEffect` | Camera focus (cinematics only) | `FarIntensity`, `FocusDistance`, `InFocusRadius`, `NearIntensity` |
| Local lights | Streetlights, wall packs, shop glow, car lights | `PointLight`, `SpotLight`, `SurfaceLight`: `Brightness`, `Range` (max 120), `Color`, `Shadows` |

**What each global property really does (our plain-word cheat sheet):**
- `Brightness`: sun strength. 2–3 for day. Above 4 blows out light concrete.
- `OutdoorAmbient`: the colour of shade outside. This is where realism lives: a **cool, slightly blue or purple** shade against a **warm** sun is how real daylight looks.
- `Ambient`: shade colour indoors (where the sky can't see). Keep it **darker** than `OutdoorAmbient` or interiors glow.
- `ColorShift_Top`: tints sunlit surfaces. A pale warm tint (255, 240, 215) for afternoon.
- `ColorShift_Bottom`: tints surfaces facing away from the sun (bounce light). A faint warm ground bounce helps the undersides of balconies and awnings.
- `EnvironmentDiffuseScale` / `EnvironmentSpecularScale`: how much the sky lights and reflects on materials. **1 / 1 for realistic.** Lower diffuse a little (0.7–0.9) if colours wash out.
- `ShadowSoftness`: 0.05–0.15 for crisp sun shadows (hood shots); 0.3–0.5 for overcast (coastal shots).
- `GeographicLatitude`: changes the sun's path. ~34 for Los Angeles, ~26 for South Florida. A lower latitude gives a higher midday sun.
- `ExposureCompensation`: overall camera exposure. Use it last, in small steps (−0.3 to +0.3).

---

## 2. Rules for a believable sky and atmosphere

1. **Match the Atmosphere `Color` to the world's average colour** (green-grey for a jungle coast, warm sand-grey for a dry city). Docs tip: it should look like the environment it's lighting.
2. **`Decay` is the horizon colour away from the sun.** Make it a little darker or cooler than `Color`.
3. **`Density` hides distance.** Clear city: 0.25–0.32. Hazy LA afternoon: 0.32–0.38. Humid coast: 0.40–0.50. Above 0.5, the street itself starts to look foggy.
4. **`Haze` adds the milky layer near the horizon.** 1–2 for sunny city, 2–3 for humid coast.
5. **`Glare` is the sun's halo through haze.** 0–1 for normal days, 2–5 for golden hour.
6. **`Offset` pushes the fog up the sky.** Small values (0–0.25) for realism.
7. **Sky choice:** a photo-based skybox with real clouds, whose lower half matches the ground colour and is darker than the top (Roblox docs tip). Our own skybox or a licensed one; note its source.
8. **Dynamic `Clouds`** on top of the skybox add motion. Cover 0.4–0.6, Density 0.6–0.8. They drift with `GlobalWind`.
9. **One Atmosphere, never fog on top.** Fog properties do nothing while an Atmosphere exists.

---

## 3. Four ready presets (Command Bar, edit time)

Run in Studio's Command Bar, look, then save. Values are our starting points, tuned by eye from Alex's references and the sources below. **Tune on a phone, not just on the Mac.** With Rojo, also list the Lighting properties in the project file so a sync doesn't reset them.

```lua
--!strict
-- Realistic lighting presets. Paste into the Command Bar, change PRESET, run, then Ctrl/Cmd+S.
local PRESET = "SunnyAfternoon" -- "SunnyAfternoon" | "HumidCoastal" | "GoldenHour" | "Night"

local Lighting = game:GetService("Lighting")
local Terrain = workspace:FindFirstChildOfClass("Terrain")

local function get(className: string, parent: Instance): Instance
	return parent:FindFirstChildOfClass(className) or (function()
		local i = Instance.new(className)
		i.Parent = parent
		return i
	end)()
end

local P = {
	SunnyAfternoon = { -- West Coast hood (hood-01..03)
		ClockTime = 16, Latitude = 34, Brightness = 2.6, Exposure = 0,
		Ambient = Color3.fromRGB(70, 72, 82), Outdoor = Color3.fromRGB(128, 132, 150),
		Top = Color3.fromRGB(255, 238, 212), Bottom = Color3.fromRGB(60, 50, 40),
		Soft = 0.08, Diffuse = 0.9, Specular = 1,
		Atmo = { Density = 0.33, Offset = 0.1, Color = Color3.fromRGB(199, 186, 170), Decay = Color3.fromRGB(120, 125, 140), Glare = 0.6, Haze = 1.6 },
		CC = { Brightness = 0, Contrast = 0.08, Saturation = -0.08, Tint = Color3.fromRGB(255, 248, 238) },
		Bloom = { Intensity = 0.35, Size = 24, Threshold = 1.6 },
		Rays = { Intensity = 0.06, Spread = 0.6 },
		Clouds = { Cover = 0.45, Density = 0.6 },
	},
	HumidCoastal = { -- Florida coast (coast-01..05)
		ClockTime = 14.5, Latitude = 26, Brightness = 2.2, Exposure = 0.1,
		Ambient = Color3.fromRGB(80, 84, 86), Outdoor = Color3.fromRGB(150, 156, 160),
		Top = Color3.fromRGB(245, 240, 228), Bottom = Color3.fromRGB(40, 50, 40),
		Soft = 0.35, Diffuse = 1, Specular = 1,
		Atmo = { Density = 0.45, Offset = 0.05, Color = Color3.fromRGB(170, 178, 168), Decay = Color3.fromRGB(120, 132, 126), Glare = 0.3, Haze = 2.6 },
		CC = { Brightness = 0.02, Contrast = 0.05, Saturation = 0.05, Tint = Color3.fromRGB(250, 252, 248) },
		Bloom = { Intensity = 0.4, Size = 28, Threshold = 1.4 },
		Rays = { Intensity = 0.03, Spread = 0.8 },
		Clouds = { Cover = 0.6, Density = 0.75 },
	},
	GoldenHour = { -- thumbnails, evening RP
		ClockTime = 18.1, Latitude = 34, Brightness = 2.4, Exposure = 0.05,
		Ambient = Color3.fromRGB(70, 60, 80), Outdoor = Color3.fromRGB(140, 120, 170),
		Top = Color3.fromRGB(255, 205, 150), Bottom = Color3.fromRGB(70, 45, 30),
		Soft = 0.12, Diffuse = 1, Specular = 1,
		Atmo = { Density = 0.36, Offset = 0.15, Color = Color3.fromRGB(210, 170, 140), Decay = Color3.fromRGB(110, 90, 130), Glare = 3, Haze = 2 },
		CC = { Brightness = 0, Contrast = 0.1, Saturation = 0.05, Tint = Color3.fromRGB(255, 240, 225) },
		Bloom = { Intensity = 0.5, Size = 30, Threshold = 1.3 },
		Rays = { Intensity = 0.12, Spread = 0.7 },
		Clouds = { Cover = 0.5, Density = 0.7 },
	},
	Night = { -- streetlights carry the scene
		ClockTime = 0.5, Latitude = 34, Brightness = 0.6, Exposure = 0.2,
		Ambient = Color3.fromRGB(18, 20, 30), Outdoor = Color3.fromRGB(45, 52, 78),
		Top = Color3.fromRGB(170, 185, 255), Bottom = Color3.fromRGB(10, 10, 20),
		Soft = 0.2, Diffuse = 0.8, Specular = 1,
		Atmo = { Density = 0.38, Offset = 0, Color = Color3.fromRGB(60, 66, 90), Decay = Color3.fromRGB(30, 34, 50), Glare = 0, Haze = 1.5 },
		CC = { Brightness = 0, Contrast = 0.12, Saturation = -0.1, Tint = Color3.fromRGB(225, 232, 255) },
		Bloom = { Intensity = 0.7, Size = 30, Threshold = 1.1 },
		Rays = { Intensity = 0, Spread = 0.5 },
		Clouds = { Cover = 0.5, Density = 0.6 },
	},
}

local p = P[PRESET]
assert(p, "Unknown preset " .. PRESET)

Lighting.LightingStyle = Enum.LightingStyle.Realistic
Lighting.PrioritizeLightingQuality = true
Lighting.GlobalShadows = true
Lighting.ClockTime = p.ClockTime
Lighting.GeographicLatitude = p.Latitude
Lighting.Brightness = p.Brightness
Lighting.ExposureCompensation = p.Exposure
Lighting.Ambient = p.Ambient
Lighting.OutdoorAmbient = p.Outdoor
Lighting.ColorShift_Top = p.Top
Lighting.ColorShift_Bottom = p.Bottom
Lighting.ShadowSoftness = p.Soft
Lighting.EnvironmentDiffuseScale = p.Diffuse
Lighting.EnvironmentSpecularScale = p.Specular

local atmo = get("Atmosphere", Lighting) :: Atmosphere
for k, v in p.Atmo do (atmo :: any)[k] = v end

local cc = get("ColorCorrectionEffect", Lighting) :: ColorCorrectionEffect
cc.Brightness, cc.Contrast, cc.Saturation, cc.TintColor = p.CC.Brightness, p.CC.Contrast, p.CC.Saturation, p.CC.Tint

local bloom = get("BloomEffect", Lighting) :: BloomEffect
bloom.Intensity, bloom.Size, bloom.Threshold = p.Bloom.Intensity, p.Bloom.Size, p.Bloom.Threshold

local rays = get("SunRaysEffect", Lighting) :: SunRaysEffect
rays.Intensity, rays.Spread = p.Rays.Intensity, p.Rays.Spread

if Terrain then
	local clouds = get("Clouds", Terrain) :: Clouds
	clouds.Cover, clouds.Density = p.Clouds.Cover, p.Clouds.Density
end
print("Applied lighting preset", PRESET)
```

**Status:** these numbers are a starting point written from the references and sources, **not yet checked in Studio** against the screenshots. The first golden-slice run must do a side-by-side (repo rule 2) and write the tuned values back here.

### 3.1 Tuning notes per preset
- **SunnyAfternoon:** if concrete blows out, drop `Brightness` to 2.2 before touching exposure. If shadows look black, lift `OutdoorAmbient` toward (140, 145, 165). The hood shots have warm sun and a slightly lilac-grey shade; that split is the look.
- **HumidCoastal:** haze is the hero. If the street looks foggy, lower `Density` by 0.05 and raise `Haze` instead (Haze stays near the horizon). Soft shadows (0.3–0.4) match an overcast sun.
- **GoldenHour:** the sun sits low, so long shadows cross the road. Great for thumbnails ([[08 Thumbnails, Icons & Marketing]]).
- **Night:** turn on local lights (§4). Bloom threshold drops so lamps glow. Keep the moon (`MoonAngularSize` ~11) and some stars.

---

## 4. Local lights that sell a city

| Light | Object | Settings to start | Shadows |
|---|---|---|---|
| Streetlight (sodium, old hood) | `SpotLight` facing down from the lamp head | Brightness 2–3, Range 40–60, Angle 100–120, Color (255, 180, 100) | Only on 1 in 4, near main roads |
| Streetlight (LED, modern coast) | `SpotLight` | Brightness 2–3, Range 40–60, Angle 110, Color (225, 235, 255) | Same |
| Wall pack (fire station, coast-01) | `SurfaceLight` on the fixture face + a Neon or emissive fixture | Brightness 1.5, Range 16–24, Angle 90 | Off |
| Shop window glow | `SurfaceLight` inside the window, facing out | Brightness 1, Range 12–16, warm white | Off |
| Neon sign | `SurfaceAppearance` emissive mask or Neon part + small `PointLight` | Brightness 1, Range 8–12, sign colour | Off |
| Car headlights | Two `SpotLight`s per car (client-side only) | Brightness 3, Range 50, Angle 45 | Off |
| Interior room | One `PointLight` per room, near the ceiling | Brightness 0.8–1.2, Range 16–24 | On only in hero interiors |

Rules:
- **Shadows on local lights cost the most.** Turn them on only where they visibly add to the scene (Roblox docs advice).
- **Range caps at 120 studs.** Use more small lights rather than one giant one, and **turn lights off by distance** (a client loop that disables lights more than ~200 studs away, see [[39 Living World - Traffic, NPCs and Ambience]] §6).
- **Tag lights `StreetLight` and switch them at dusk** with one client script, not one script per lamp.
- **Emissive beats Neon** for signs: `SurfaceAppearance.EmissiveMaskContent` + `EmissiveStrength` + `EmissiveTint` lets only the letters glow.

---

## 5. Day and night cycle (client-side, smooth, cheap)

The server owns the clock (so everyone agrees on time); each client blends lighting locally. Moving `ClockTime` moves the sun; blending the other properties between presets keeps colours right at each hour.

```lua
--!strict
-- StarterPlayerScripts/DayNight.client.luau (sketch, not yet run in Studio)
-- Server sets workspace:SetAttribute("WorldClock", hours 0-24) every few seconds.
local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")

type Key = { t: number, outdoor: Color3, top: Color3, bright: number, density: number, atmo: Color3 }
local KEYS: { Key } = { -- hour, then values; add more keys for finer control
	{ t = 0,  outdoor = Color3.fromRGB(45, 52, 78),   top = Color3.fromRGB(170, 185, 255), bright = 0.6, density = 0.38, atmo = Color3.fromRGB(60, 66, 90) },
	{ t = 6,  outdoor = Color3.fromRGB(120, 110, 150), top = Color3.fromRGB(255, 200, 160), bright = 1.6, density = 0.40, atmo = Color3.fromRGB(200, 170, 160) },
	{ t = 12, outdoor = Color3.fromRGB(135, 140, 155), top = Color3.fromRGB(255, 245, 230), bright = 2.8, density = 0.32, atmo = Color3.fromRGB(199, 190, 175) },
	{ t = 18, outdoor = Color3.fromRGB(140, 120, 170), top = Color3.fromRGB(255, 205, 150), bright = 2.4, density = 0.36, atmo = Color3.fromRGB(210, 170, 140) },
	{ t = 24, outdoor = Color3.fromRGB(45, 52, 78),   top = Color3.fromRGB(170, 185, 255), bright = 0.6, density = 0.38, atmo = Color3.fromRGB(60, 66, 90) },
}

local function sample(h: number): Key
	for i = 1, #KEYS - 1 do
		local a, b = KEYS[i], KEYS[i + 1]
		if h >= a.t and h <= b.t then
			local f = (h - a.t) / (b.t - a.t)
			return {
				t = h,
				outdoor = a.outdoor:Lerp(b.outdoor, f),
				top = a.top:Lerp(b.top, f),
				bright = a.bright + (b.bright - a.bright) * f,
				density = a.density + (b.density - a.density) * f,
				atmo = a.atmo:Lerp(b.atmo, f),
			}
		end
	end
	return KEYS[1]
end

local atmo = Lighting:FindFirstChildOfClass("Atmosphere")
local lampsOn: boolean? = nil
local acc = 0
RunService.Heartbeat:Connect(function(dt)
	acc += dt
	if acc < 0.25 then return end -- 4 updates a second is plenty
	acc = 0
	local h = (workspace:GetAttribute("WorldClock") :: number?) or 14
	local k = sample(h)
	Lighting.ClockTime = h
	Lighting.OutdoorAmbient = k.outdoor
	Lighting.ColorShift_Top = k.top
	Lighting.Brightness = k.bright
	if atmo then
		atmo.Density = k.density
		atmo.Color = k.atmo
	end
	local wantOn = h < 6.3 or h > 18.4
	if wantOn ~= lampsOn then
		lampsOn = wantOn
		for _, lamp in CollectionService:GetTagged("StreetLight") do
			for _, l in lamp:GetDescendants() do
				if l:IsA("Light") then l.Enabled = wantOn end
			end
		end
	end
end)
```

- A full day of 24–48 real minutes suits RP (long enough to play a shift, short enough to see night).
- Lamps that stream in later must check the current state too (listen to `CollectionService:GetInstanceAddedSignal("StreetLight")`).
- Weather (rain, wet roads) is its own system: `LihFolk/LihFolk Vault V2/07 Lighting VFX and Audio/Weather System Architecture - State Machine, Transitions and Replication.md` and `Rain - Camera-Local Particles, Splashes and Wet Surfaces.md`.

---

## 6. Graphics settings menu (keeps phones happy)

Realistic maps need a **Graphics: High / Medium / Low** toggle in Settings, applied on the client only:

| Setting | High | Medium | Low |
|---|---|---|---|
| SunRays | on | on | off |
| Bloom | on | on (lower intensity) | off |
| DepthOfField (cutscenes) | on | off | off |
| Clouds | on | on | off |
| Local light shadows | on | off | off |
| Light cull distance | 300 | 200 | 120 |
| Foliage wind (WindShake render distance) | 150 | 100 | 50 |
| Ambient NPCs / traffic counts | 100% | 60% | 30% |
| Decal wear on far blocks | on | on | near only |

Default to **Medium on phones**, **High on desktop** (`UserInputService.TouchEnabled` and screen size as the hint). The engine's own quality level still applies on top.

---

## 7. Mistakes to avoid
- Copying "hyper-realistic" presets with Brightness 5+ and Contrast 0.3: they look great in one screenshot and blow out every white wall in play.
- Saturation above +0.2 in ColorCorrection: realistic scenes are slightly desaturated; colour comes from a few accents.
- Bloom with a low threshold (< 1): every white wall glows. Keep it above ~1.1 in day.
- DepthOfField on during gameplay: it blurs the road ahead and annoys drivers. Use it for menus, cutscenes and photo mode.
- Lighting edited by the server at runtime for one zone: it replicates to everyone. Zone moods change on the client.
- Testing only in Studio at max quality. Always check the Device Emulator plus a real phone at quality 1.

## Sources
Roblox docs [Enhance outdoor environments](https://create.roblox.com/docs/tutorials/use-case-tutorials/lighting/enhance-outdoor-environments) (Realistic style, Diffuse/Specular 1, ambient and atmosphere colour advice, shadows only where they add), [Post-processing effects](https://create.roblox.com/docs/environment/post-processing-effects), [Improve performance](https://create.roblox.com/docs/performance-optimization/improve) (shadows off below quality 4, light costs). DevForum [Hyper realistic lighting settings](https://devforum.roblox.com/t/hyper-realistic-lighting-settings/915802) (Brightness 1–3, ShadowSoftness ~0.1, SunRays 0.2/0.7, Bloom 0.1/0.4/0.8 as one builder's taste). Vault: [[Brief - Worlds, Lighting and Performance]], `LihFolk/.../Lighting Technologies and Settings.md`.
