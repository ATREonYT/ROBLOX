--[[
	Draws the lobby's Aura stars (HuzzServer/AuraPickupService, tag "HuzzAuraStar") on this screen with the
	owner's Aura star (design/aura): the purple one as drawn, the other colours from its all-white copy, tinted. A
	soft halo behind it breathes, sparkles, a soft light and a glow on the floor; it bobs and sways gently. Rainbow
	stars drift through the colours slowly (never a flash). Collecting one (E) pops it: a burst of sparkles, a sound
	and "+1 Aura".
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
	local Toast = require(UI.Toast)
	local Sfx = require(script.Parent.Sfx)

	local NEAR = 140
	local kinds = {}
	for _, k in Config.Kinds do kinds[k.Name] = k end
	local looks = {} -- star part -> its pieces

	local function build(star: BasePart)
		if looks[star] then return end
		local kind = kinds[star:GetAttribute("Kind") or ""] or Config.Kinds[1]
		local color = kind.Color
		local gui = Instance.new("BillboardGui")
		gui.Name = "AuraLook"
		gui.Size = UDim2.fromScale(4.2, 4.2) -- (studs: grows and shrinks with distance, like a real object)
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
		sparkles.Rate = if kind.Value > 1 then 9 else 5
		sparkles.Lifetime = NumberRange.new(0.8, 1.5)
		sparkles.Speed = NumberRange.new(0.6, 1.6)
		sparkles.SpreadAngle = Vector2.new(180, 180)
		sparkles.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.25), NumberSequenceKeypoint.new(1, 0) })
		sparkles.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(1, 1) })
		sparkles.Parent = att
		local light = Instance.new("PointLight")
		light.Color = color
		light.Brightness = 1.2
		light.Range = 9
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
		floor.Size = Vector3.new(0.06, 3.4, 3.4)
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

	-- Collected (yours): a burst where it was, a sound, "+N Aura".
	Net.get("Round").OnClientEvent:Connect(function(kind, data)
		if kind ~= "AuraCollected" or type(data) ~= "table" then return end
		local at = data.at
		if typeof(at) == "Vector3" then
			local k = kinds[data.kind or ""] or Config.Kinds[1]
			local p = Instance.new("Part")
			p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.Transparency = true, false, false, false, 1
			p.Size = Vector3.one
			p.CFrame = CFrame.new(at)
			local e = Instance.new("ParticleEmitter")
			e.Texture = AuraLook.TEXTURES.Star or "rbxasset://textures/particles/sparkles_main.dds"
			e.Color = ColorSequence.new(Color3.new(1, 1, 1), k.Color)
			e.LightEmission = 0.9
			e.Rate = 0
			e.Lifetime = NumberRange.new(0.5, 0.9)
			e.Speed = NumberRange.new(6, 12)
			e.SpreadAngle = Vector2.new(180, 180)
			e.Drag = 4
			e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.45), NumberSequenceKeypoint.new(1, 0) })
			e.Parent = p
			p.Parent = Workspace
			e:Emit(24)
			task.delay(1.5, function() p:Destroy() end)
		end
		Sfx.play(if (data.value or 1) > 1 then "reward" else "coin")
		Toast.show(`+{data.value or 1} Aura`)
	end)
end

return M
