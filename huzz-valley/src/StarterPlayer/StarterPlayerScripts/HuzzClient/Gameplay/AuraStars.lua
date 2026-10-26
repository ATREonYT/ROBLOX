--[[
	Draws the field's Aura stars (HuzzServer/AuraPickupService, tag "HuzzAuraStar") on this screen with the
	owner's Aura star (design/aura): the purple one as drawn, the other colours from its all-white copy, tinted. A
	soft halo behind it breathes, sparkles, a soft light and a glow on the floor; it bobs and sways gently. Rainbow
	stars drift through the colours slowly (never a flash). Rarer stars (worth more) are bigger, sparkle more and glow
	brighter, so you can tell them apart from far away. Collecting one (run into it) pops it like Huss Valley's gems: a
	"+N" in the star's colour jumps up where it was and fades, with a soft burst of sparkles (bigger for rarer ones) and
	a sound. Everyone near sees the burst (so the field feels alive); only the collector gets the "+N" and the sound.
	Only stars near the camera animate.
]]
local M = {}

function M.start()
	local CollectionService = game:GetService("CollectionService")
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local RunService = game:GetService("RunService")
	local Workspace = game:GetService("Workspace")

	local Shared = ReplicatedStorage:WaitForChild("Shared")
	local Config = require(Shared.Config.AuraStars)
	local Net = require(Shared.Net)
	local AuraLook = require(Shared.AuraLook)
	local UI = script.Parent.Parent.UI
	local Kit = require(UI.Kit)
	local Sfx = require(script.Parent.Sfx)
	local Burst = require(script.Parent.Burst)
	local Players = game:GetService("Players")

	local NEAR = 140
	local kinds, tierOf = {}, {}
	for i, k in Config.Kinds do kinds[k.Name] = k; tierOf[k.Name] = i - 1 end -- 0 = most common
	local looks = {} -- star part -> its pieces

	local function build(star: BasePart)
		if looks[star] then return end
		local kind = kinds[star:GetAttribute("Kind") or ""] or Config.Kinds[1]
		local color = kind.Color
		local tier = tierOf[kind.Name] or 0
		local gui = Instance.new("BillboardGui")
		gui.Name = "AuraLook"
		local size = 4.2 * (1 + tier * 0.14) -- rarer = bigger (studs: grows and shrinks with distance, like a real object)
		gui.Size = UDim2.fromScale(size, size)
		gui.LightInfluence = 0
		gui.MaxDistance = NEAR
		gui.Adornee = star
		gui.Parent = star
		local asDrawn = kind.Name == "Purple" -- (the owner drew the purple one; the rest tint the white copy)
		local function img(name, icon, size, transparency, z, tint)
			local l = Kit.icon(icon, { Name = name, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(size, size), ImageColor3 = tint, ImageTransparency = transparency, ZIndex = z, Parent = gui })
			return l
		end
		local halo = img("Halo", "AuraStarWhite", 1.3, 0.8, 1, color)
		local core = img("Star", if asDrawn then "AuraStar" else "AuraStarWhite", 1, 0, 2, if asDrawn then Color3.new(1, 1, 1) else color)
		-- sparkles and a light, on an attachment at the star
		local att = Instance.new("Attachment")
		att.Name = "AuraFx"
		att.Parent = star
		local sparkles = Instance.new("ParticleEmitter")
		sparkles.Name = "Sparkles"
		sparkles.Texture = AuraLook.TEXTURES.Star or "rbxasset://textures/particles/sparkles_main.dds"
		sparkles.Color = ColorSequence.new(Color3.new(1, 1, 1), color)
		sparkles.LightEmission = 0.8
		sparkles.Rate = 5 + tier * 3
		sparkles.Lifetime = NumberRange.new(0.8, 1.5)
		sparkles.Speed = NumberRange.new(0.6, 1.6)
		sparkles.SpreadAngle = Vector2.new(180, 180)
		sparkles.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.25), NumberSequenceKeypoint.new(1, 0) })
		sparkles.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(1, 1) })
		sparkles.Parent = att
		local light = Instance.new("PointLight")
		light.Color = color
		light.Brightness = 0.6 + tier * 0.15 -- (Oct 19 "even" lighting: was 1.2 + 0.25 / 9 + 1.5, a pool round every star)
		light.Range = 6 + tier
		light.Shadows = false
		light.Parent = star
		-- a soft glow on the floor under it
		local floor = Instance.new("Part")
		floor.Name = "AuraFloorGlow"
		floor.Shape = Enum.PartType.Cylinder
		floor.Anchored, floor.CanCollide, floor.CanQuery, floor.CanTouch, floor.CastShadow = true, false, false, false, false
		floor.Material = Enum.Material.Neon
		floor.Color = color
		floor.Transparency = 0.82
		floor.Size = Vector3.new(0.06, 3.4 + tier * 0.5, 3.4 + tier * 0.5)
		floor.CFrame = CFrame.new(star.Position - Vector3.new(0, Config.Height - 0.05, 0)) * CFrame.Angles(0, 0, math.rad(90))
		floor.Parent = star
		looks[star] = { gui = gui, halo = halo, core = core, sparkles = sparkles, light = light, floor = floor, kind = kind, seed = math.random() * 10 }
	end

	local function forget(star)
		looks[star] = nil
	end
	CollectionService:GetInstanceAddedSignal("HuzzAuraStar"):Connect(function(star)
		task.defer(build, star)
	end)
	CollectionService:GetInstanceRemovedSignal("HuzzAuraStar"):Connect(forget)
	for _, star in CollectionService:GetTagged("HuzzAuraStar") do
		task.defer(build, star)
	end

	local clock = 0
	RunService.RenderStepped:Connect(function(dt)
		clock += dt
		local cam = Workspace.CurrentCamera
		for star, l in looks do
			if not star.Parent then
				looks[star] = nil
			elseif cam and (cam.CFrame.Position - star.Position).Magnitude < NEAR then
				local t = clock + l.seed
				l.gui.StudsOffset = Vector3.new(0, math.sin(t * 1.8) * 0.28, 0) -- bob
				l.core.Rotation = math.sin(t * 0.9) * 6 -- a gentle sway
				local pulse = 1 + math.sin(t * 2.6) * 0.03
				l.core.Size = UDim2.fromScale(pulse, pulse)
				l.halo.ImageTransparency = 0.78 + math.sin(t * 1.3) * 0.06 -- the halo breathes slowly
				if l.kind.Rainbow then
					local c = Color3.fromHSV((t * 0.12) % 1, 0.55, 1) -- a slow drift through the colours, no flashing
					l.core.ImageColor3, l.halo.ImageColor3 = c, c
					l.light.Color, l.floor.Color = c, c
				end
			end
		end
	end)

	-- Collected: a soft burst where it was (everyone near), and for the collector a "+N" in the star's colour that
	-- jumps up and fades (Huss Valley's "+1" over a gem) and a sound. No toast at the top: the HUD's Aura counts up.
	Net.get("Round").OnClientEvent:Connect(function(kind, data)
		if kind ~= "AuraCollected" or type(data) ~= "table" then return end
		local mine = data.id == nil or data.id == Players.LocalPlayer.UserId
		local at = data.at
		local k = kinds[data.kind or ""] or Config.Kinds[1]
		local tier = tierOf[k.Name] or 0
		local cam = Workspace.CurrentCamera
		if typeof(at) == "Vector3" and (mine or (cam and (cam.CFrame.Position - at).Magnitude < NEAR)) then
			local color = if k.Rainbow then Color3.fromHSV((os.clock() * 0.12) % 1, 0.55, 1) else k.Color
			Burst.sparks(at, { color }, (if mine then 14 else 8) + tier * 5, {
				texture = AuraLook.TEXTURES.Star, glow = 0.7, life = NumberRange.new(0.35, 0.6), speed = NumberRange.new(4, 8),
				drag = 5, gravity = Vector3.new(0, 2, 0),
				size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35 + tier * 0.04), NumberSequenceKeypoint.new(1, 0) }),
			})
			if mine then
				-- (the White star's text keeps a coloured edge so it still reads against the sky)
				Burst.pop(at + Vector3.new(0, 0.6, 0), `+{data.value or 1}`, color, {
					height = 1.5 + tier * 0.18, rise = 2.6, time = 0.85,
					outline = if k.Name == "White" or k.Rainbow then Color3.fromRGB(70, 40, 120) else nil,
				})
			end
		end
		if mine then
			Sfx.play("aura_pickup", { pitch = if (data.value or 1) >= 5 then 0.85 elseif (data.value or 1) > 1 then 0.95 else 1 })
		end
	end)
end

return M
