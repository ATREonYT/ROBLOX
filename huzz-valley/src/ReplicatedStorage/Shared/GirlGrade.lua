--[[
	A girl in her Combine grade (owner, Oct 20 14:57: "then you make the girls in silver, gold, and diamond"). The
	Combine machine (Shared/CombineRules) makes Silver, Gold and Diamond copies of a girl; this dresses any copy of
	her model in that grade, wherever she shows: your companion (Gameplay/Auras), the Index, the Tiers page and the Combine window's
	pictures (UI/GirlPicture), the merge itself (Gameplay/CombineMachine).
	  * Her hair and accessories (not her face: the Face accessories, or anything named face, eye, brow, lash,
	    blush, mouth) take the grade's colour and material (Config/Combine.Grades: Silver and Gold metal, Diamond
	    clear glass); their picture is taken off so the colour shows, so the whole hairdo reads at a glance.
	  * Her clothes keep their pictures, tinted by the grade (Shirt / Pants / ShirtGraphic Color3: a multiply).
	  * Her skin and face stay as they are.
	  * fx (world copies only, never in a picture): a soft sheen and rim in the grade's colour (a Highlight, Sheen),
	    a glint (Roblox's own sparkles_main), soft motes (smoke_main) and one soft light, in the grade's colour, on
	    an invisible box over her body. Sized for her height. Built-in pictures only (VFX-ITEMS.md). Kid-safe: the
	    glint is on a fixed calm timer like the knives' (Shared/KnifeMotes.glint: one every Glint.Every seconds,
	    never two within 1.5 s for one girl), not a random rate; one Heartbeat steps every girl's glint.
	apply(model, grade, opts?) -> handle?   opts = { fx = true, lite = true (half the particles, no light) }
	handle = { setEnabled(on), destroy() }. Normal (or an unknown grade) changes nothing and returns nil.
]]
local Config = require(script.Parent.Config.Combine)
local KnifeMotes = require(script.Parent.KnifeMotes)

local GirlGrade = {}

-- Every live girl's glint: { emitter, every, nextAt }. One Heartbeat steps them all (hooked on the first one).
local glints = {}
local hooked = false
local seedCount = 0
-- Steps every glint to time t; returns the emitters that glinted (nil when none), for the checks.
function GirlGrade.stepGlints(t: number): { ParticleEmitter }?
	local fired = nil
	for i = #glints, 1, -1 do
		local g = glints[i]
		if not g.emitter.Parent then
			table.remove(glints, i)
		elseif g.on then
			local now, nextAt = KnifeMotes.glint(g.nextAt, t, g.every)
			g.nextAt = nextAt
			if now then
				pcall(function() g.emitter:Emit(1) end)
				fired = fired or {}
				table.insert(fired, g.emitter)
			end
		end
	end
	return fired
end
local function addGlint(e: ParticleEmitter, every: number)
	seedCount += 1
	local g = { emitter = e, every = every, on = true, nextAt = KnifeMotes.firstGlint(os.clock(), every, seedCount * 0.77) }
	table.insert(glints, g)
	if not hooked then
		hooked = true
		pcall(function()
			game:GetService("RunService").Heartbeat:Connect(function() GirlGrade.stepGlints(os.clock()) end)
		end)
	end
	return g
end

local SPARKLE = "rbxasset://textures/particles/sparkles_main.dds"
local SMOKE = "rbxasset://textures/particles/smoke_main.dds"
local FACE_WORDS = { "face", "eye", "brow", "lash", "blush", "mouth" }

-- Should this accessory take the grade's look? Everything but her face.
function GirlGrade.dresses(accessory: Instance): boolean
	local name = string.lower(accessory.Name)
	for _, w in FACE_WORDS do
		if string.find(name, w, 1, true) then return false end
	end
	local kind = nil
	pcall(function() kind = (accessory :: any).AccessoryType end)
	return kind ~= Enum.AccessoryType.Face
end

local function dress(part: BasePart, look)
	if part.Transparency >= 0.99 then return end -- (an invisible holder part)
	part.Color = look.Hair
	part.Material = look.Material
	part.Reflectance = look.Reflectance
	if look.Transparency > part.Transparency then part.Transparency = look.Transparency end
	for _, c in part:GetChildren() do
		if c:IsA("SpecialMesh") then
			pcall(function()
				(c :: any).TextureId = ""
				c.VertexColor = Vector3.new(1, 1, 1)
			end)
		elseif c:IsA("SurfaceAppearance") then
			pcall(function() c:Destroy() end) -- (it would paint over the colour)
		end
	end
	if part:IsA("MeshPart") then
		pcall(function() (part :: any).TextureID = "" end)
	end
end

-- Her body's height (studs), for sizing the effect.
local function heightOf(model: Model): number
	local ok, _, size = pcall(function() return model:GetBoundingBox() end)
	return if ok and size then math.clamp(size.Y, 1, 40) else 5
end

function GirlGrade.fx(model: Model, grade: string, opts: any?)
	local look = Config.Grades[grade]
	local spec = look and look.Fx
	local root = model:FindFirstChild("HumanoidRootPart") or model.PrimaryPart
	if not (spec and root and root:IsA("BasePart")) then return nil end
	if model:FindFirstChild("HuzzGradeFx") then model.HuzzGradeFx:Destroy() end -- (dressed again: one effect, one glint timer)
	local lite = opts and opts.lite
	local h = heightOf(model)
	local k = h / 5
	local box = Instance.new("Part")
	box.Name = "HuzzGradeFx"
	box.Transparency, box.CanCollide, box.CanQuery, box.CanTouch, box.CastShadow, box.Massless = 1, false, false, false, false, true
	box.Anchored = false
	box.Size = Vector3.new(1.6 * k, h * 0.8, 1.2 * k)
	box.CFrame = root.CFrame + Vector3.new(0, h * 0.1, 0) -- (over her body, a little up from her middle)
	local weld = Instance.new("WeldConstraint")
	weld.Part0, weld.Part1 = root, box
	weld.Parent = box
	local emitters = {}
	local glint = nil
	local function emitter(kind, g)
		local e = Instance.new("ParticleEmitter")
		e.Name = kind
		e.Shape = Enum.ParticleEmitterShape.Box
		e.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
		e.LightInfluence = 0
		e.Rate = if kind == "Glint" then 0 else g.Rate * (if lite then 0.5 else 1)
		e.Color = ColorSequence.new(g.Color)
		if kind == "Glint" then
			glint = addGlint(e, g.Every * (if lite then 1.5 else 1))
			e.Texture = SPARKLE
			e.Lifetime = NumberRange.new(0.6, 1)
			e.Speed = NumberRange.new(0, 0)
			e.Rotation = NumberRange.new(0, 360)
			e.RotSpeed = NumberRange.new(-60, 60)
			e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.5, g.Size * k), NumberSequenceKeypoint.new(1, 0) })
			e.LightEmission = 0.5
			e.ZOffset = 0.5
		else
			e.Texture = SMOKE
			e.Lifetime = NumberRange.new(1.6, 2.4)
			e.Speed = NumberRange.new(0.15 * k, 0.4 * k)
			e.SpreadAngle = Vector2.new(180, 180)
			e.Acceleration = Vector3.new(0, 0.5 * k, 0)
			e.Drag = 0.5
			e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.3, g.Size * k), NumberSequenceKeypoint.new(1, 0) })
			e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.25, 0.1), NumberSequenceKeypoint.new(0.75, 0.2), NumberSequenceKeypoint.new(1, 1) })
			e.LightEmission = 0.3
		end
		e.Parent = box
		table.insert(emitters, e)
	end
	if spec.Glint then emitter("Glint", spec.Glint) end
	if spec.Motes then emitter("Motes", spec.Motes) end
	local light = nil
	if spec.Light and not lite then
		light = Instance.new("PointLight")
		light.Color, light.Brightness, light.Range, light.Shadows = spec.Light.Color, spec.Light.Brightness, spec.Light.Range * math.max(k, 0.5), false
		light.Parent = box
	end
	local sheen = nil
	if look.Sheen then
		pcall(function()
			sheen = Instance.new("Highlight")
			sheen.Name = "HuzzGradeSheen"
			sheen.FillColor, sheen.FillTransparency = look.Sheen.Color, look.Sheen.Fill
			sheen.OutlineColor, sheen.OutlineTransparency = look.Sheen.Color, look.Sheen.Rim
			sheen.DepthMode = Enum.HighlightDepthMode.Occluded
			sheen.Adornee = model
			sheen.Parent = box
		end)
	end
	box.Parent = model
	local handle = {}
	function handle.setEnabled(on: boolean)
		for _, e in emitters do e.Enabled = on end
		if glint then glint.on = on end
		if light then light.Enabled = on end
		if sheen then sheen.Enabled = on end
	end
	function handle.destroy()
		box:Destroy()
	end
	return handle
end

function GirlGrade.apply(model: Model, grade: string?, opts: any?)
	local look = grade and Config.Grades[grade]
	if not (look and look.Hair) then return nil end
	model:SetAttribute("HuzzGrade", grade)
	for _, d in (if Config.Recolour then model:GetDescendants() else {}) do -- (off: her own look, the aura only)
		if d:IsA("BasePart") then
			local acc = d:FindFirstAncestorOfClass("Accessory")
			if acc and GirlGrade.dresses(acc) then dress(d, look) end
		elseif d:IsA("Shirt") or d:IsA("Pants") or d:IsA("ShirtGraphic") then
			pcall(function() (d :: any).Color3 = look.Cloth end)
		end
	end
	if opts and opts.fx then
		return GirlGrade.fx(model, grade :: string, opts)
	end
	return nil
end

return GirlGrade
