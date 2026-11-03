--!strict
-- Contact faces for the phone (Messages, Calls, banners): a round photo of the contact's head, rendered live from
-- the same rigs the cutscenes use (ReplicatedStorage.MTL_Actors.<contactId>, built by CutsceneService at server
-- start). Contacts without a rig (Unknown, Rico, Tasha...) get a real-phone "no photo" circle: soft grey gradient
-- with white initials. "You" uses the player's own Roblox headshot.
-- Never blocks: the circle shows the initials at once and swaps to the face when the rig is there.
--   Avatars.make(parent, contactId, size, props?) -> Frame   (Name = "Avatar")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Story = require(ReplicatedStorage.MTL.Config.Story)

local Avatars = {}

local heads: { [string]: Model } = {} -- contactId -> head-only model (cached, never parented)
local waiting: { [string]: { (Model) -> () } } = {}
local watching = false
local selfShot: string? = nil

local GREY_TOP = Color3.fromRGB(166, 170, 181)
local GREY_BOTTOM = Color3.fromRGB(128, 133, 145)

local function displayName(id: string): string
	local c = (Story.Contacts :: any)[id]
	return if c and c.Name then c.Name else id
end

local function initials(id: string): string
	if id == "Unknown" then
		return "?"
	end
	local name = string.gsub(displayName(id), "^Mr%.%s*", "")
	name = string.gsub(name, "^Mrs%.%s*", "")
	local a, b = string.match(name, "^(%S)%S*%s+(%S)")
	if a and b then
		return string.upper(a .. b)
	end
	return string.upper(string.sub(name, 1, 1))
end

-- head + the hair/hat/glasses around it, anchored, no joints
local function cutHead(rig: Model): Model?
	local head = rig:FindFirstChild("Head")
	if not head or not head:IsA("BasePart") then
		return nil
	end
	local m = Instance.new("Model")
	m.Name = "Face"
	local function copy(part: BasePart)
		local was = part.Archivable
		part.Archivable = true
		local c = part:Clone()
		part.Archivable = was
		for _, d in c:GetDescendants() do
			if d:IsA("JointInstance") or d:IsA("WeldConstraint") or d:IsA("Attachment") or d:IsA("Script") or d:IsA("LocalScript") then
				d:Destroy()
			end
		end
		c.Anchored = true
		c.CanCollide = false
		c.LocalTransparencyModifier = 0
		c.Parent = m
	end
	copy(head)
	for _, acc in rig:GetChildren() do
		local handle = acc:IsA("Accessory") and acc:FindFirstChild("Handle")
		if handle and handle:IsA("BasePart") and (handle.Position - head.Position).Magnitude < 4 then
			copy(handle)
		end
	end
	m.PrimaryPart = m:FindFirstChild("Head") :: BasePart?
	return m
end

local function offer(rig: Instance)
	if not rig:IsA("Model") or heads[rig.Name] then
		return
	end
	local function try(): boolean
		local h = cutHead(rig)
		if not h then
			return false
		end
		heads[rig.Name] = h
		local list = waiting[rig.Name]
		waiting[rig.Name] = nil
		for _, fn in list or {} do
			task.spawn(fn, h)
		end
		return true
	end
	if not try() then
		-- the rig's parts can arrive a moment after the model
		local conn
		conn = rig.ChildAdded:Connect(function()
			if heads[rig.Name] or try() then
				conn:Disconnect()
			end
		end)
	end
end

local function watch()
	if watching then
		return
	end
	watching = true
	local function hook(folder: Instance)
		for _, r in folder:GetChildren() do
			offer(r)
		end
		folder.ChildAdded:Connect(offer)
	end
	local f = ReplicatedStorage:FindFirstChild("MTL_Actors")
	if f then
		hook(f)
	else
		local conn
		conn = ReplicatedStorage.ChildAdded:Connect(function(c)
			if c.Name == "MTL_Actors" then
				conn:Disconnect()
				hook(c)
			end
		end)
	end
end

local function fillViewport(view: ViewportFrame, head: Model)
	view:ClearAllChildren()
	local m = head:Clone()
	m.Parent = view
	local h = m.PrimaryPart or m:FindFirstChild("Head") :: BasePart?
	if not h then
		return
	end
	local cam = Instance.new("Camera")
	cam.FieldOfView = 28
	local look = h.CFrame.LookVector
	local focus = h.Position + Vector3.new(0, 0.1, 0)
	cam.CFrame = CFrame.lookAt(focus + look * 3.3 + h.CFrame.RightVector * 0.55 + Vector3.new(0, 0.15, 0), focus)
	cam.Parent = view
	view.CurrentCamera = cam
end

function Avatars.make(parent: Instance, id: string, size: number, props: { [string]: any }?): Frame
	watch()
	local a = Instance.new("Frame")
	a.Name = "Avatar"
	a.Size = UDim2.fromOffset(size, size)
	a.BackgroundColor3 = Color3.new(1, 1, 1)
	a.BorderSizePixel = 0
	a.ClipsDescendants = true
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = a
	local grad = Instance.new("UIGradient")
	grad.Rotation = 90
	grad.Color = ColorSequence.new(GREY_TOP, GREY_BOTTOM)
	grad.Parent = a

	local letters = Instance.new("TextLabel")
	letters.Name = "Initials"
	letters.Size = UDim2.fromScale(1, 1)
	letters.BackgroundTransparency = 1
	letters.FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Bold)
	letters.Text = initials(id)
	letters.TextColor3 = Color3.new(1, 1, 1)
	letters.TextSize = math.floor(size * 0.42)
	letters.Parent = a

	for k, v in props or {} do
		(a :: any)[k] = v
	end
	letters.ZIndex = a.ZIndex
	a.Parent = parent

	if id == "You" then
		local img = Instance.new("ImageLabel")
		img.Name = "Photo"
		img.Size = UDim2.fromScale(1, 1)
		img.BackgroundTransparency = 1
		img.ZIndex = a.ZIndex + 1
		img.Parent = a
		local inner = Instance.new("UICorner")
		inner.CornerRadius = UDim.new(1, 0)
		inner.Parent = img
		if selfShot then
			img.Image = selfShot
		else
			task.spawn(function()
				local ok, url = pcall(function()
					return Players:GetUserThumbnailAsync(Players.LocalPlayer.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size150x150)
				end)
				if ok and url then
					selfShot = url
					img.Image = url
				end
			end)
		end
		return a
	end

	local function show(head: Model)
		if not a.Parent then
			return
		end
		local view = Instance.new("ViewportFrame")
		view.Name = "Photo"
		view.Size = UDim2.fromScale(1, 1)
		view.BackgroundColor3 = Color3.fromRGB(196, 200, 210)
		view.BackgroundTransparency = 0
		view.Ambient = Color3.fromRGB(190, 188, 196)
		view.LightColor = Color3.fromRGB(255, 246, 234)
		view.LightDirection = Vector3.new(-0.6, -0.4, -1)
		view.ZIndex = a.ZIndex + 1
		local inner = Instance.new("UICorner")
		inner.CornerRadius = UDim.new(1, 0)
		inner.Parent = view
		fillViewport(view, head)
		view.Parent = a
		letters.Visible = false
	end
	if id ~= "Unknown" then
		local cached = heads[id]
		if cached then
			show(cached)
		else
			local list = waiting[id] or {}
			waiting[id] = list
			table.insert(list, show)
		end
	end
	return a
end

-- for list rows that only need the text fallback (search, etc.)
Avatars.initials = initials
Avatars.displayName = displayName

return Avatars
