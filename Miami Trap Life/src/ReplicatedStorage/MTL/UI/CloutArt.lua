--!strict
-- CLOUT post pictures. A post can't carry a real screenshot to other players (Roblox captures stay on the device
-- that took them), so every post is drawn the same way for everyone: the spot's sky and palette at the time it
-- was posted, a silhouette of the place (skyline, sea, car meet lights, mural...), the poster's car as a real 3D
-- model (ViewportFrame, ReplicatedStorage.MTL_SocialProps.<car template>) and the poster's avatar. The poster
-- also sees their real screenshot this session (opts.capture). Deterministic per post (post.seed).
--   CloutArt.draw(parent, post, { size = UDim2?, capture = contentId?, viewport = bool?, z = number? }) -> Frame
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Social = require(ReplicatedStorage.MTL.Config.Social)
local Vehicles = require(ReplicatedStorage.MTL.Config.Vehicles)

local CloutArt = {}

local C = Color3.fromRGB

local function new(className: string, props: { [string]: any }): any
	local inst = Instance.new(className)
	for k, v in props do
		if k ~= "Parent" then
			(inst :: any)[k] = v
		end
	end
	if props.Parent then
		inst.Parent = props.Parent
	end
	return inst
end

-- tiny seeded random (same picture every time for the same post)
local function rand(seed: number): () -> number
	local x = (math.floor(seed) % 2147483646) + 1
	return function(): number
		x = (x * 48271) % 2147483647
		return x / 2147483647
	end
end

local function hourTint(phase: string?): (Color3, number)
	if phase == "Night" then
		return C(20, 24, 60), 0.45
	elseif phase == "Evening" then
		return C(255, 120, 60), 0.25
	elseif phase == "Morning" then
		return C(255, 210, 170), 0.15
	end
	return C(255, 255, 255), 1
end

local function rect(parent: Instance, x: number, y: number, w: number, h: number, color: Color3, z: number, t: number?): Frame
	return new("Frame", {
		Position = UDim2.fromScale(x, y),
		Size = UDim2.fromScale(w, h),
		BackgroundColor3 = color,
		BackgroundTransparency = t or 0,
		BorderSizePixel = 0,
		ZIndex = z,
		Parent = parent,
	})
end

local function darker(c: Color3, k: number): Color3
	return Color3.new(c.R * k, c.G * k, c.B * k)
end

-- the place behind the subject
local function scenery(f: Frame, spot: any, phase: string?, r: () -> number, z: number)
	local top, bottom, accent = spot.palette[1], spot.palette[2], spot.palette[3]
	local night = phase == "Night"
	local scene = spot.scene or "street"
	local ink = if night then C(10, 10, 18) else darker(bottom, 0.55)
	local horizon = 0.58
	if scene == "water" or scene == "beach" then
		-- sea + far skyline + (beach) sand
		for i = 1, 14 do
			local w = 0.03 + r() * 0.05
			local h = 0.04 + r() * 0.16
			rect(f, r() * 0.95, horizon - h, w, h, darker(ink, 1.3), z)
		end
		rect(f, 0, horizon, 1, 1 - horizon, darker(top, if night then 0.25 else 0.7), z)
		for i = 1, 5 do
			rect(f, r() * 0.8, horizon + 0.03 + i * 0.045, 0.1 + r() * 0.25, 0.006, C(255, 255, 255), z + 1, 0.6)
		end
		if scene == "beach" then
			rect(f, 0, 0.8, 1, 0.2, if night then C(60, 54, 50) else C(236, 214, 168), z + 1)
		else
			-- a yacht
			rect(f, 0.58, horizon + 0.07, 0.32, 0.05, C(250, 250, 250), z + 2)
			rect(f, 0.64, horizon + 0.03, 0.16, 0.04, C(235, 235, 240), z + 2)
			rect(f, 0.66, horizon + 0.035, 0.12, 0.012, C(30, 40, 60), z + 3)
			rect(f, 0, 0.84, 1, 0.16, C(70, 66, 62), z + 1) -- dock
		end
	elseif scene == "lot" or scene == "track" then
		-- tarmac, lights, (track) kerbs
		for i = 1, 9 do
			local w = 0.06 + r() * 0.08
			local h = 0.08 + r() * 0.22
			rect(f, r() * 0.94, horizon - h, w, h, ink, z)
		end
		rect(f, 0, horizon, 1, 1 - horizon, if night then C(22, 22, 28) else C(70, 70, 76), z)
		for i = 0, 4 do
			rect(f, 0.04 + i * 0.22, 0.86, 0.1, 0.012, C(240, 240, 240), z + 1, 0.3)
		end
		if scene == "track" then
			for i = 0, 9 do
				rect(f, i * 0.1, horizon, 0.05, 0.02, if i % 2 == 0 then C(230, 40, 40) else C(255, 255, 255), z + 1)
			end
		end
		if night then
			for i = 1, 4 do
				local x = 0.08 + (i - 1) * 0.28
				rect(f, x, 0.18, 0.006, horizon - 0.18, C(30, 30, 34), z + 1)
				local glow = rect(f, x - 0.05, 0.15, 0.1, 0.06, accent, z + 1, 0.55)
				new("UICorner", { CornerRadius = UDim.new(1, 0), Parent = glow })
			end
		end
	elseif scene == "mural" then
		local colors = { C(255, 72, 104), C(80, 170, 255), C(255, 220, 80), C(120, 230, 160), C(190, 120, 255), C(255, 140, 60) }
		rect(f, 0, 0.2, 1, horizon + 0.1 - 0.2, C(240, 236, 228), z)
		for i = 1, 22 do
			local blob = rect(f, r() * 0.95, 0.22 + r() * 0.5, 0.06 + r() * 0.22, 0.04 + r() * 0.18, colors[1 + math.floor(r() * #colors)], z + 1, if night then 0.35 else 0)
			if r() < 0.5 then
				new("UICorner", { CornerRadius = UDim.new(1, 0), Parent = blob })
			end
		end
		rect(f, 0, horizon + 0.1, 1, 1 - horizon - 0.1, C(150, 146, 140), z + 1)
		if night then
			rect(f, 0, 0, 1, 1, C(10, 10, 30), z + 2, 0.5)
		end
	elseif scene == "house" then
		-- a white villa + palms
		rect(f, 0, horizon + 0.12, 1, 1, if night then C(30, 50, 40) else C(96, 168, 98), z)
		rect(f, 0.12, 0.3, 0.76, 0.34, if night then C(190, 186, 176) else C(250, 248, 242), z + 1)
		rect(f, 0.08, 0.27, 0.84, 0.04, if night then C(150, 146, 140) else C(230, 228, 222), z + 2)
		for i = 0, 4 do
			rect(f, 0.16 + i * 0.145, 0.38, 0.09, 0.14, if night then C(255, 210, 120) else C(110, 160, 200), z + 2, if night then 0.1 else 0.2)
		end
		for _, x in { 0.04, 0.9 } do
			rect(f, x, 0.2, 0.014, 0.5, C(110, 84, 60), z + 3)
			local crown = rect(f, x - 0.06, 0.15, 0.14, 0.08, if night then C(20, 40, 30) else C(40, 120, 60), z + 3)
			new("UICorner", { CornerRadius = UDim.new(1, 0), Parent = crown })
		end
		if spot.id == "CreatorHouse" then
			local ring = rect(f, 0.42, 0.42, 0.16, 0.16, C(255, 255, 255), z + 3, 0.1)
			new("UICorner", { CornerRadius = UDim.new(1, 0), Parent = ring })
			rect(f, 0.495, 0.58, 0.01, 0.12, C(30, 30, 30), z + 3)
		end
	elseif scene == "jet" then
		rect(f, 0, horizon + 0.05, 1, 1, if night then C(28, 28, 34) else C(120, 122, 128), z)
		-- the jet: fuselage, wing, tail, windows
		local body = rect(f, 0.08, 0.42, 0.84, 0.1, C(248, 248, 250), z + 1)
		new("UICorner", { CornerRadius = UDim.new(1, 0), Parent = body })
		rect(f, 0.36, 0.5, 0.3, 0.035, C(220, 222, 228), z + 2)
		rect(f, 0.82, 0.3, 0.06, 0.14, C(240, 240, 244), z + 1)
		for i = 0, 7 do
			local w = rect(f, 0.24 + i * 0.06, 0.45, 0.022, 0.03, C(40, 50, 70), z + 2)
			new("UICorner", { CornerRadius = UDim.new(1, 0), Parent = w })
		end
		rect(f, 0.08, 0.55, 0.84, 0.006, accent, z + 2, 0.2)
	elseif scene == "grass" then
		rect(f, 0, horizon, 1, 1, if night then C(20, 40, 24) else C(110, 180, 90), z)
		local flag = rect(f, 0.7, 0.36, 0.006, 0.24, C(240, 240, 240), z + 1)
		rect(f, 0.706, 0.36, 0.06, 0.04, C(230, 40, 40), z + 1)
		local _ = flag
	else
		-- street / tower / skyline: block buildings with lit windows
		local count = if scene == "skyline" then 18 elseif scene == "tower" then 8 else 11
		for i = 1, count do
			local w = (if scene == "tower" then 0.1 else 0.05) + r() * 0.1
			local h = (if scene == "skyline" then 0.08 + r() * 0.3 elseif scene == "tower" then 0.3 + r() * 0.4 else 0.12 + r() * 0.22)
			local x = r() * (1 - w)
			local b = rect(f, x, horizon - h, w, h, darker(ink, 0.9 + r() * 0.4), z)
			if night or scene == "tower" then
				for k = 1, 5 do
					rect(b, 0.15 + r() * 0.6, 0.1 + r() * 0.8, 0.1, 0.03, if night then C(255, 214, 140) else C(180, 200, 220), z + 1, if night then 0.2 else 0.5)
					local _ = k
				end
			end
		end
		rect(f, 0, horizon, 1, 1 - horizon, if night then C(26, 26, 30) else darker(bottom, 0.7), z)
		rect(f, 0, horizon + 0.2, 1, 0.006, C(255, 220, 120), z + 1, 0.5)
		if spot.id == "Theater" then
			rect(f, 0.36, 0.22, 0.28, 0.08, C(255, 60, 140), z + 2, 0.05)
			new("TextLabel", {
				Position = UDim2.fromScale(0.36, 0.22),
				Size = UDim2.fromScale(0.28, 0.08),
				BackgroundTransparency = 1,
				Font = Enum.Font.GothamBlack,
				Text = "TOWER",
				TextScaled = true,
				TextColor3 = C(255, 240, 200),
				ZIndex = z + 3,
				Parent = f,
			})
		end
	end
end

local carCache: { [string]: Model? } = {}
local function carModel(carId: string?): Model?
	if not carId then
		return nil
	end
	local def = Vehicles.get(carId)
	local name = if def then (def.template or def.id) else carId
	if carCache[name] ~= nil then
		return carCache[name]
	end
	local folder = ReplicatedStorage:FindFirstChild("MTL_SocialProps")
	local m = folder and folder:FindFirstChild(name)
	if m and m:IsA("Model") then
		carCache[name] = m
		return m
	end
	return nil
end

local function drawCar(f: Frame, carId: string, phase: string?, accent: Color3, z: number, r: () -> number)
	local src = carModel(carId)
	local vp = new("ViewportFrame", {
		Name = "Car",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.fromScale(0.58, 0.97),
		Size = UDim2.fromScale(0.95, 0.62),
		BackgroundTransparency = 1,
		Ambient = if phase == "Night" then C(90, 90, 130) else C(170, 170, 170),
		LightColor = if phase == "Night" then accent else (if phase == "Evening" then C(255, 190, 140) else C(255, 250, 240)),
		LightDirection = Vector3.new(-0.6, -1, -0.5),
		ZIndex = z,
		Parent = f,
	})
	if not src then
		-- a clean placeholder silhouette until the car is in MTL_SocialProps
		local body = rect(f, 0.3, 0.72, 0.6, 0.12, C(20, 20, 24), z)
		new("UICorner", { CornerRadius = UDim.new(0.4, 0), Parent = body })
		rect(f, 0.42, 0.64, 0.32, 0.1, C(30, 30, 36), z)
		return
	end
	local model = src:Clone()
	model.Parent = vp
	local cf, size = model:GetBoundingBox()
	local cam = Instance.new("Camera")
	cam.FieldOfView = 30
	-- a low 3/4 angle (seeded left/right), like a real car shot
	local side = if r() < 0.5 then 1 else -1
	local dist = math.max(size.X, size.Z) * 1.9
	local look = cf.Position + Vector3.new(0, -size.Y * 0.1, 0)
	local dir = (cf.LookVector * 0.85 + cf.RightVector * 0.55 * side).Unit
	cam.CFrame = CFrame.lookAt(look + dir * dist + Vector3.new(0, size.Y * 0.35, 0), look)
	cam.Parent = vp
	vp.CurrentCamera = cam
end

-- the avatar: Roblox's own full-body render of the poster (rbxthumb), standing by the car
local function drawPerson(f: Frame, userId: number?, z: number)
	if not userId or userId <= 0 then
		return
	end
	new("ImageLabel", {
		Name = "Person",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.fromScale(0.2, 1.02),
		Size = UDim2.fromScale(0.62, 0.62),
		BackgroundTransparency = 1,
		Image = string.format("rbxthumb://type=Avatar&id=%d&w=420&h=420", userId),
		ZIndex = z,
		Parent = f,
	})
end

function CloutArt.draw(parent: Instance, post: any, opts: any?): Frame
	opts = opts or {}
	local z = opts.z or 2
	local spot = Social.spot(post.spot)
	local phase = post.phase
	local f = new("Frame", {
		Name = "Art",
		Size = opts.size or UDim2.fromScale(1, 1),
		Position = opts.position or UDim2.new(),
		BackgroundColor3 = spot.palette[2],
		BorderSizePixel = 0,
		ClipsDescendants = true,
		ZIndex = z,
		Parent = parent,
	})
	if opts.capture then
		new("ImageLabel", {
			Name = "Photo",
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			Image = opts.capture,
			ScaleType = Enum.ScaleType.Crop,
			ZIndex = z + 1,
			Parent = f,
		})
		return f
	end
	local r = rand(post.seed or 1)
	-- sky
	local sky = new("UIGradient", {
		Rotation = 90,
		Color = ColorSequence.new(spot.palette[1], spot.palette[2]),
		Parent = f,
	})
	local _ = sky
	if phase == "Evening" or phase == "Day" or phase == "Morning" then
		local sun = rect(f, 0.62 + r() * 0.2, if phase == "Evening" then 0.38 else 0.08, 0.16, 0.16, if phase == "Evening" then C(255, 200, 120) else C(255, 250, 220), z, 0.1)
		sun.SizeConstraint = Enum.SizeConstraint.RelativeXX
		new("UICorner", { CornerRadius = UDim.new(1, 0), Parent = sun })
	elseif phase == "Night" then
		for _ = 1, 10 do
			rect(f, r(), r() * 0.35, 0.006, 0.006, C(255, 255, 255), z, 0.3)
		end
	end
	scenery(f, spot, phase, r, z + 1)
	if post.car and opts.viewport ~= false then
		drawCar(f, post.car, phase, spot.palette[3], z + 6, r)
	end
	if post.format ~= "Proof" then
		drawPerson(f, post.userId, z + 8)
	else
		-- money proof: a fake earnings dashboard
		local card = rect(f, 0.1, 0.18, 0.8, 0.64, C(250, 250, 252), z + 6)
		new("UICorner", { CornerRadius = UDim.new(0.06, 0), Parent = card })
		new("TextLabel", {
			Position = UDim2.fromScale(0.08, 0.08),
			Size = UDim2.fromScale(0.84, 0.14),
			BackgroundTransparency = 1,
			Font = Enum.Font.GothamMedium,
			Text = "Total revenue · today",
			TextScaled = true,
			TextColor3 = C(110, 110, 120),
			TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = z + 7,
			Parent = card,
		})
		new("TextLabel", {
			Position = UDim2.fromScale(0.08, 0.24),
			Size = UDim2.fromScale(0.84, 0.26),
			BackgroundTransparency = 1,
			Font = Enum.Font.GothamBlack,
			Text = "$" .. tostring(1000 + math.floor(r() * 48000)) .. "." .. tostring(10 + math.floor(r() * 89)),
			TextScaled = true,
			TextColor3 = C(20, 20, 24),
			TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = z + 7,
			Parent = card,
		})
		for i = 0, 9 do
			local h = 0.1 + r() * 0.3
			rect(card, 0.08 + i * 0.085, 0.92 - h, 0.06, h, C(99, 91, 255), z + 7)
		end
	end
	-- grade + vignette (a light filter, like a real app)
	local tint, alpha = hourTint(phase)
	if alpha < 1 then
		rect(f, 0, 0, 1, 1, tint, z + 9, 1 - alpha * 0.6)
	end
	local vignette = rect(f, 0, 0.62, 1, 0.38, C(0, 0, 0), z + 9, 0)
	new("UIGradient", {
		Rotation = 90,
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 0.45) }),
		Parent = vignette,
	})
	-- sponsored tag
	if post.brand then
		local b = Social.brand(post.brand)
		local tag = new("TextLabel", {
			Name = "Paid",
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -8, 0, 8),
			Size = UDim2.fromOffset(0, 18),
			AutomaticSize = Enum.AutomaticSize.X,
			BackgroundColor3 = C(0, 0, 0),
			BackgroundTransparency = 0.4,
			Font = Enum.Font.GothamBold,
			Text = "  Paid partnership · " .. (if b then b.name else "brand") .. "  ",
			TextSize = 10,
			TextColor3 = C(255, 255, 255),
			ZIndex = z + 10,
			Parent = f,
		})
		new("UICorner", { CornerRadius = UDim.new(0, 4), Parent = tag })
	end
	return f
end

-- avatar circle: the player's headshot (rbxthumb) or an initial on the NPC's colour
function CloutArt.avatar(parent: Instance, post: any, size: number, z: number?): Frame
	local f = new("Frame", {
		Name = "Avatar",
		Size = UDim2.fromOffset(size, size),
		BackgroundColor3 = post.color or C(60, 60, 70),
		BorderSizePixel = 0,
		ZIndex = z or 2,
		Parent = parent,
	})
	new("UICorner", { CornerRadius = UDim.new(1, 0), Parent = f })
	if post.userId and post.userId > 0 then
		new("ImageLabel", {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			Image = string.format("rbxthumb://type=AvatarHeadShot&id=%d&w=150&h=150", post.userId),
			ZIndex = (z or 2) + 1,
			Parent = f,
		}).Parent = f
		local img = f:FindFirstChildOfClass("ImageLabel")
		if img then
			new("UICorner", { CornerRadius = UDim.new(1, 0), Parent = img })
		end
	else
		new("TextLabel", {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			Font = Enum.Font.GothamBlack,
			Text = string.upper(string.sub(post.handle or "?", 1, 1)),
			TextColor3 = C(255, 255, 255),
			TextScaled = true,
			ZIndex = (z or 2) + 1,
			Parent = f,
		}, nil)
	end
	return f
end

local _ = Players
return CloutArt
