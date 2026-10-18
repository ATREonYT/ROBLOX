--[[
	Builds one lobby prop on its pad (owner, Oct 18: "implementing these objects into the lobby on top of the already
	placed circles. Give it some VFX and make it look good just like in the pictures"; Config/LobbyProps).
	Used by HuzzServer/LobbyPropService at game start and by the place build (tools/place/build_yours.luau), so his
	Rojo-synced place and the downloaded build get the same thing. Everything new is made with the `api` table
	(Roblox's or Lune's Instance, Vector2, Vector3, CFrame, Color3, ColorSequence(Keypoint), NumberSequence(Keypoint),
	NumberRange, UDim, UDim2, Enum, Font: LobbyPropBuild.api(env) collects them).

	Workspace > HuzzLobbyProps > LobbyProp (Model, tag HuzzLobbyProp; attributes Prop, Title, Line, Opens, Action,
	Scale, Color, Glow: he can type another Title or Scale in Studio)
	  Pad    an invisible part on the pad's top: the soft light under the prop (in its glow colour), a glow pool on
	         the pad (three see-through circles), the title over the prop (BillboardGui "PropTitle": big bold letters in
	         the prop's colour with a dark outline, like the reference's SHOP / LIKE REWARD, and a small line under it),
	         and for a prop that opens a menu, a ProximityPrompt (attribute HuzzOpens).
	  Prop   his model: the real meshes from ServerStorage > HuzzLobbyProps when he has set them up (SetupLobbyProps),
	         else the stand-in made of plain parts (HuzzServer/LobbyPropShapes; attribute StandIn). Every part is welded
	         to an invisible Root in the middle of the prop, so Gameplay/LobbyProps floats and turns it by moving the
	         Root alone (on each screen). Sparkles rise from the Root's box; a ClickDetector opens the menu too.
]]
local LobbyPropBuild = {}

local DARK = { 22, 14, 34 } -- the titles' outline (near black, a touch purple: Halloween)

-- The datatypes the builder needs, from a table holding them (Roblox's globals, or Lune's roblox library).
function LobbyPropBuild.api(env)
	local out = {}
	for _, k in { "Instance", "Vector2", "Vector3", "CFrame", "Color3", "ColorSequence", "ColorSequenceKeypoint", "NumberSequence",
		"NumberSequenceKeypoint", "NumberRange", "UDim", "UDim2", "Enum", "Font" } do
		out[k] = env[k]
	end
	return out
end

local function make(api, class: string, props: { [string]: any }, parent: any?)
	local i = api.Instance.new(class)
	for k, v in props do
		i[k] = v
	end
	if parent then i.Parent = parent end
	return i
end

-- The stand-in: his model as plain parts (blocks, balls, cylinders) in his colours, welded to `root`.
function LobbyPropBuild.standIn(api, shape, scale: number, root, model)
	local CFrame, Vector3 = api.CFrame, api.Vector3
	local half = shape.size[2] / 2
	for _, r in shape.parts do
		local kind, x, y, z = r[1], r[2], r[3], r[4]
		local size = Vector3.new(math.max(0.05, r[14] * scale), math.max(0.05, r[15] * scale), math.max(0.05, r[16] * scale))
		local cf = root.CFrame * CFrame.new(x * scale, (y - half) * scale, z * scale)
			* CFrame.new(0, 0, 0, r[5], r[8], r[11], r[6], r[9], r[12], r[7], r[10], r[13])
		local p = make(api, "Part", {
			Name = kind == "S" and "Ball" or (kind == "C" and "Cylinder" or "Block"),
			Size = size, CFrame = cf, Anchored = false, CanCollide = false, CanTouch = false, CanQuery = true,
			Massless = true, Color = api.Color3.fromRGB(tonumber(r[17]:sub(1, 2), 16), tonumber(r[17]:sub(3, 4), 16), tonumber(r[17]:sub(5, 6), 16)),
			Material = r[18] == 1 and api.Enum.Material.Neon or api.Enum.Material.SmoothPlastic,
			CastShadow = r[18] ~= 1,
			TopSurface = api.Enum.SurfaceType.Smooth, BottomSurface = api.Enum.SurfaceType.Smooth,
		}, model)
		if kind == "C" then
			p.Shape = api.Enum.PartType.Cylinder
		elseif kind == "S" then
			if math.abs(size.X - size.Y) < 0.02 and math.abs(size.Y - size.Z) < 0.02 then
				p.Shape = api.Enum.PartType.Ball
			else
				make(api, "SpecialMesh", { MeshType = api.Enum.MeshType.Sphere }, p) -- (an egg shape: fills the part's box)
			end
		end
		make(api, "WeldConstraint", { Part0 = root, Part1 = p }, p)
	end
end

local function hexColour(api, h: string)
	return api.Color3.fromRGB(tonumber(h:sub(1, 2), 16), tonumber(h:sub(3, 4), 16), tonumber(h:sub(5, 6), 16))
end

--[[
	One prop on its pad. `spot` = LobbyLayout.propSpots row ({ at, Prop }), `config` = Config/LobbyProps, `shape` =
	its LobbyPropShapes entry (sizes in .glb units), `real` = his set-up model or nil, `texture` = the sparkle picture.
]]
function LobbyPropBuild.make(api, spot, config, shape, real, texture: string)
	local CFrame, Vector3, Color3 = api.CFrame, api.Vector3, api.Color3
	local Enum = api.Enum
	local cfg = config.Props[spot.Prop]
	local scale = cfg.Scale or 2
	local size = Vector3.new(shape.size[1], shape.size[2], shape.size[3]) * scale
	local glow = cfg.Glow or hexColour(api, shape.glow)
	local lp = make(api, "Model", { Name = "LobbyProp" })
	lp:SetAttribute("Prop", spot.Prop)
	lp:SetAttribute("Title", cfg.Title)
	if cfg.Line then lp:SetAttribute("Line", cfg.Line) end
	if cfg.Opens then
		lp:SetAttribute("Opens", cfg.Opens)
		lp:SetAttribute("Action", cfg.Action or "Open")
	end
	lp:SetAttribute("Scale", scale)
	lp:SetAttribute("Color", cfg.Color)
	lp:SetAttribute("Glow", glow)

	-- the pad: light, glow pool, title, prompt
	local pad = make(api, "Part", {
		Name = "Pad", Size = Vector3.new(6, 0.2, 6), CFrame = spot.at * CFrame.new(0, 0.1, 0), Anchored = true,
		CanCollide = false, CanTouch = false, CanQuery = false, Transparency = 1, CastShadow = false,
	}, lp)
	local lightAt = make(api, "Attachment", { Name = "LightAt", Position = Vector3.new(0, 0.9, 0) }, pad)
	make(api, "PointLight", { Name = "PropLight", Color = glow, Brightness = config.Light.Brightness, Range = config.Light.Range, Shadows = false }, lightAt)
	local pool = make(api, "SurfaceGui", {
		Name = "GlowPool", Face = Enum.NormalId.Top, CanvasSize = api.Vector2.new(240, 240), LightInfluence = 0,
		AlwaysOnTop = false, ResetOnSpawn = false,
	}, pad)
	for i, ring in { { 1.0, 0.82 }, { 0.72, 0.7 }, { 0.44, 0.58 } } do
		local c = make(api, "Frame", {
			Name = "Glow" .. i, AnchorPoint = api.Vector2.new(0.5, 0.5), Position = api.UDim2.fromScale(0.5, 0.5),
			Size = api.UDim2.fromScale(ring[1], ring[1]), BackgroundColor3 = glow, BackgroundTransparency = ring[2],
			BorderSizePixel = 0,
		}, pool)
		make(api, "UICorner", { CornerRadius = api.UDim.new(0.5, 0) }, c)
	end
	-- the title (over where the prop floats): letters TitleHeight studs tall a line, like the reference's SHOP / LIKE
	-- REWARD, the small line under it; its bottom TitleAbove over the prop's highest bob
	local lines = 1
	for _ in string.gmatch(cfg.Title, "\n") do lines += 1 end
	local titleH = lines * config.TitleHeight * 1.15
	local lineH = if cfg.Line then config.LineHeight * 1.2 else 0
	local bbH = titleH + lineH
	local bb = make(api, "BillboardGui", {
		Name = "PropTitle", Size = api.UDim2.fromScale(config.TitleWidth, bbH), LightInfluence = 0, MaxDistance = config.TitleMaxDistance,
		StudsOffsetWorldSpace = Vector3.new(0, config.Hover + size.Y + config.Bob + config.TitleAbove + bbH / 2, 0), ResetOnSpawn = false,
		AlwaysOnTop = false,
	}, pad)
	local font = Enum.Font[config.TitleFont] or Enum.Font.GothamBlack
	local title = make(api, "TextLabel", {
		Name = "Title", BackgroundTransparency = 1, Size = api.UDim2.fromScale(1, titleH / bbH), Text = cfg.Title,
		FontFace = api.Font.fromEnum(font), TextScaled = true, TextColor3 = cfg.Color,
	}, bb)
	make(api, "UIStroke", { Color = Color3.fromRGB(DARK[1], DARK[2], DARK[3]), Thickness = 3, LineJoinMode = Enum.LineJoinMode.Round }, title)
	make(api, "UIGradient", { -- a soft white lift at the top of the letters (the reference's shine)
		Rotation = 90,
		Color = api.ColorSequence.new({
			api.ColorSequenceKeypoint.new(0, cfg.Color:Lerp(Color3.new(1, 1, 1), 0.45)),
			api.ColorSequenceKeypoint.new(0.45, cfg.Color),
			api.ColorSequenceKeypoint.new(1, cfg.Color),
		}),
	}, title)
	local line = make(api, "TextLabel", {
		Name = "Line", BackgroundTransparency = 1, Position = api.UDim2.fromScale(0, titleH / bbH), Size = api.UDim2.fromScale(1, math.max(lineH, 0.01) / bbH),
		Text = (cfg.Line and cfg.Line ~= "FreeSpin") and cfg.Line or "", FontFace = api.Font.fromEnum(Enum.Font.GothamBold), TextScaled = true,
		TextColor3 = Color3.new(1, 1, 1),
	}, bb)
	make(api, "UIStroke", { Color = Color3.fromRGB(DARK[1], DARK[2], DARK[3]), Thickness = 1.5 }, line)
	if cfg.Opens then
		local prompt = make(api, "ProximityPrompt", {
			Name = "PropPrompt", ActionText = cfg.Action or "Open", ObjectText = "", HoldDuration = 0,
			MaxActivationDistance = 12, RequiresLineOfSight = false, KeyboardKeyCode = Enum.KeyCode.E,
		}, pad)
		prompt:SetAttribute("HuzzOpens", cfg.Opens)
	end

	-- the prop: Root in the middle of its box, his model (or the stand-in) welded to it, front to the plaza
	local prop = make(api, "Model", { Name = "Prop" })
	local root = make(api, "Part", {
		Name = "Root", Size = size * 1.1, Anchored = true, CanCollide = false, CanTouch = false, CanQuery = false,
		Transparency = 1, CastShadow = false,
		CFrame = spot.at * CFrame.Angles(0, math.pi, 0) * CFrame.new(0, config.Hover + size.Y / 2, 0),
	}, prop)
	prop.PrimaryPart = root
	if real then
		for _, d in real:GetChildren() do
			if d.Name ~= "Root" then d.Parent = prop end
		end
		local realRoot = real.PrimaryPart or real:FindFirstChild("Root")
		-- his parts keep their places round his Root: move each by the same step onto ours, then scale
		if realRoot then
			for _, d in prop:GetDescendants() do
				if d:IsA("BasePart") and d ~= root then
					local rel = realRoot.CFrame:ToObjectSpace(d.CFrame)
					d.Size = d.Size * scale
					d.CFrame = root.CFrame * (rel - rel.Position + rel.Position * scale)
					d.Anchored = false
					for _, j in d:GetChildren() do
						if j:IsA("WeldConstraint") or j:IsA("JointInstance") then j:Destroy() end
					end
					make(api, "WeldConstraint", { Part0 = root, Part1 = d }, d)
				end
			end
		end
		prop:SetAttribute("StandIn", false)
	else
		LobbyPropBuild.standIn(api, shape, scale, root, prop)
		prop:SetAttribute("StandIn", true)
	end
	-- sparkles rising slowly from round the prop (steady, never a flash)
	local sp = config.Sparkles
	make(api, "ParticleEmitter", {
		Name = "PropSparkles", Texture = texture, Rate = sp.Rate, Lifetime = api.NumberRange.new(sp.Lifetime * 0.7, sp.Lifetime),
		Speed = api.NumberRange.new(0.3, 0.9), SpreadAngle = api.Vector2.new(25, 25), EmissionDirection = Enum.NormalId.Top,
		Shape = Enum.ParticleEmitterShape.Box, ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume,
		Acceleration = Vector3.new(0, 0.4, 0), LightEmission = 1, LightInfluence = 0,
		Color = api.ColorSequence.new(glow:Lerp(Color3.new(1, 1, 1), 0.35), glow),
		Size = api.NumberSequence.new({ api.NumberSequenceKeypoint.new(0, 0), api.NumberSequenceKeypoint.new(0.25, sp.Size),
			api.NumberSequenceKeypoint.new(0.75, sp.Size * 0.8), api.NumberSequenceKeypoint.new(1, 0) }),
		Transparency = api.NumberSequence.new({ api.NumberSequenceKeypoint.new(0, 0.3), api.NumberSequenceKeypoint.new(0.6, 0.35),
			api.NumberSequenceKeypoint.new(1, 1) }),
		Rotation = api.NumberRange.new(0, 360), RotSpeed = api.NumberRange.new(-40, 40),
	}, root)
	if cfg.Opens then
		make(api, "ClickDetector", { Name = "PropClick", MaxActivationDistance = 40 }, prop)
	end
	prop.Parent = lp
	return lp
end

return LobbyPropBuild
