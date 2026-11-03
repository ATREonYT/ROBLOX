--!strict
-- Camera: the phone becomes a viewfinder (you see the world through the glass, the HUD hides). Photo or Selfie
-- (the camera swings round in front of your face). The shutter takes a real Roblox screenshot (CaptureService)
-- with the phone hidden for that frame, flashes, and drops the photo in the roll. The roll keeps this session's
-- photos; "Save" asks Roblox to save one to the player's Captures gallery.
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local UIState = require(script.Parent.Parent.Controllers.UIState)

local App = { id = "Camera", title = "Camera" }

local player = Players.LocalPlayer
local roll: { string } = {} -- contentIds taken this session, newest last
local MAX_ROLL = 24

local function captureService(): any?
	local ok, svc = pcall(function()
		return game:GetService("CaptureService")
	end)
	return if ok then svc else nil
end

---------------------------------------------------------------- filters
-- Colour filters for the viewfinder (a ColorCorrection on Lighting, client only, so it's in the photo too).
local FILTERS = {
	{ name = "Normal" },
	{ name = "Vivid", saturation = 0.35, contrast = 0.12 },
	{ name = "Miami", tint = Color3.fromRGB(255, 214, 236), saturation = 0.25, contrast = 0.05, brightness = 0.02 },
	{ name = "Sunset", tint = Color3.fromRGB(255, 220, 180), saturation = 0.15, contrast = 0.08 },
	{ name = "Night", tint = Color3.fromRGB(190, 210, 255), saturation = -0.2, contrast = 0.15, brightness = -0.04 },
	{ name = "Noir", saturation = -1, contrast = 0.25 },
	{ name = "Faded", saturation = -0.35, contrast = -0.15, brightness = 0.05 },
}
local filterIndex = 1

local function setFilter(i: number?)
	local old = Lighting:FindFirstChild("MTL_CameraFilter")
	local f = if i then FILTERS[i] else nil
	if not f or f.name == "Normal" then
		if old then
			old:Destroy()
		end
		return
	end
	local cc = (old or Instance.new("ColorCorrectionEffect")) :: ColorCorrectionEffect
	cc.Name = "MTL_CameraFilter"
	cc.TintColor = f.tint or Color3.new(1, 1, 1)
	cc.Saturation = f.saturation or 0
	cc.Contrast = f.contrast or 0
	cc.Brightness = f.brightness or 0
	cc.Parent = Lighting
end

---------------------------------------------------------------- selfie camera

local selfieConn: RBXScriptConnection? = nil
local savedCamType: Enum.CameraType? = nil
local savedFov: number? = nil

local function stopSelfie()
	if selfieConn then
		selfieConn:Disconnect()
		selfieConn = nil
	end
	local cam = workspace.CurrentCamera
	if cam and savedCamType then
		cam.CameraType = savedCamType
		if savedFov then
			cam.FieldOfView = savedFov
		end
		local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		if hum then
			cam.CameraSubject = hum
		end
	end
	savedCamType = nil
	savedFov = nil
end

local function startSelfie()
	local cam = workspace.CurrentCamera
	if not cam or selfieConn then
		return
	end
	savedCamType = cam.CameraType
	savedFov = cam.FieldOfView
	cam.CameraType = Enum.CameraType.Scriptable
	local smooth: CFrame? = nil
	selfieConn = RunService.RenderStepped:Connect(function(dt)
		local char = player.Character
		local head = char and char:FindFirstChild("Head") :: BasePart?
		if not head then
			return
		end
		-- arm's length in front of the face, a little above and to the side, looking back at you
		local h = head.CFrame
		local eye = h.Position + h.LookVector * 3.6 + h.UpVector * 0.55 + h.RightVector * 0.9
		local want = CFrame.lookAt(eye, h.Position + h.UpVector * 0.15)
		smooth = if smooth then smooth:Lerp(want, math.clamp(dt * 12, 0, 1)) else want
		cam.CFrame = smooth :: CFrame
		cam.FieldOfView = 62
	end)
end

---------------------------------------------------------------- views

local render: (any) -> ()

local function flash(ctx: any)
	local gui = ctx.frame:FindFirstAncestorOfClass("ScreenGui")
	if not gui then
		return
	end
	local f = gui:FindFirstChild("Flash") :: Frame?
	if not f then
		f = ctx.UIKit.new("Frame", {
			Name = "Flash",
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = Color3.new(1, 1, 1),
			BackgroundTransparency = 1,
			ZIndex = 100,
			Parent = gui,
		})
	end
	assert(f)
	f.BackgroundTransparency = 0.25
	game:GetService("TweenService"):Create(f, TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { BackgroundTransparency = 1 }):Play()
end

local busy = false
local lastShot = -1e9

local function shoot(ctx: any)
	-- one photo per press: ignore repeats (Space can also reach a focused button)
	if busy or os.clock() - lastShot < 1 then
		return
	end
	lastShot = os.clock()
	local cs = captureService()
	busy = true
	ctx.sfx("PhoneShutter")
	if not cs then
		flash(ctx)
		busy = false
		ctx.Phone.notify({ title = "Camera", text = "Photos aren't available here" })
		return
	end
	-- hide the phone for the frame the picture is taken
	ctx.Phone.setCaptureHidden(true)
	RunService.RenderStepped:Wait()
	local done = false
	local ok = pcall(function()
		cs:CaptureScreenshot(function(contentId: any)
			done = true
			ctx.Phone.setCaptureHidden(false)
			flash(ctx)
			if contentId then
				table.insert(roll, tostring(contentId))
				while #roll > MAX_ROLL do
					table.remove(roll, 1)
				end
			end
			busy = false
			if ctx.frame.Parent then
				render(ctx)
			end
		end)
	end)
	if not ok then
		done = true
		busy = false
		ctx.Phone.setCaptureHidden(false)
		flash(ctx)
		ctx.Phone.notify({ title = "Camera", text = "Couldn't take the photo" })
		return
	end
	-- never leave the phone hidden if Roblox doesn't answer
	task.delay(1.5, function()
		if not done then
			ctx.Phone.setCaptureHidden(false)
			busy = false
		end
	end)
end

local function save(ctx: any, contentId: string, status: TextLabel)
	local cs = captureService()
	if not cs then
		status.Text = "Saving isn't available here"
		return
	end
	local ok = pcall(function()
		cs:PromptSaveCapturesToGallery({ contentId }, function(results: any)
			local saved = type(results) == "table" and results[contentId] == true
			if status.Parent then
				status.Text = if saved then "Saved to your Captures" else "Not saved"
			end
		end)
	end)
	if not ok then
		status.Text = "Saving isn't available here"
	end
end

local function showPhoto(ctx: any, index: number)
	ctx.clear()
	ctx.view = "photo"
	stopSelfie()
	setFilter(nil)
	ctx.Phone.setViewfinder(false)
	local UIKit = ctx.UIKit
	UIKit.header(ctx.frame, string.format("Photo %d of %d", index, #roll), function()
		ctx.view = "roll"
		render(ctx)
	end)
	local id = roll[index]
	UIKit.new("ImageLabel", {
		Name = "Photo",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 50),
		Size = UDim2.new(1, -20, 1, -150),
		BackgroundColor3 = Color3.new(0, 0, 0),
		Image = id or "",
		ScaleType = Enum.ScaleType.Fit,
		Parent = ctx.frame,
	}, { UIKit.corner(UDim.new(0, 18)) })
	local bottom = UIKit.new("Frame", {
		Name = "Actions",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -8),
		Size = UDim2.new(1, -20, 0, 84),
		BackgroundTransparency = 1,
		Parent = ctx.frame,
	}, { UIKit.list(6) })
	local status = UIKit.label(bottom, "", { size = 12, dim = true, align = Enum.TextXAlignment.Center, order = 2, name = "Status" })
	UIKit.button(bottom, "Save to Captures", {
		order = 1,
		onClick = function()
			if id then
				status.Text = "..."
				save(ctx, id, status)
			end
		end,
	})
end

local function showRoll(ctx: any)
	ctx.clear()
	ctx.view = "roll"
	stopSelfie()
	setFilter(nil)
	ctx.Phone.setViewfinder(false)
	local UIKit = ctx.UIKit
	UIKit.header(ctx.frame, "Photos", function()
		ctx.view = "camera"
		render(ctx)
	end)
	local list = UIKit.scroll(ctx.frame, 44, "Roll")
	list:FindFirstChildOfClass("UIListLayout"):Destroy()
	UIKit.new("UIGridLayout", {
		CellSize = UDim2.fromOffset(84, 112),
		CellPadding = UDim2.fromOffset(6, 6),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = list,
	})
	if #roll == 0 then
		UIKit.empty(list, "No photos yet.")
	end
	for i = #roll, 1, -1 do
		local b = UIKit.new("ImageButton", {
			Name = "Photo",
			LayoutOrder = #roll - i,
			BackgroundColor3 = Color3.new(0, 0, 0),
			Image = roll[i],
			ScaleType = Enum.ScaleType.Crop,
			AutoButtonColor = false,
			Parent = list,
		}, { UIKit.corner(UDim.new(0, 10)) })
		b.Activated:Connect(function()
			showPhoto(ctx, i)
		end)
	end
end

local function showCamera(ctx: any)
	ctx.clear()
	ctx.view = "camera"
	local UIKit, Theme = ctx.UIKit, ctx.Theme
	local C = Theme.Colors
	ctx.Phone.setViewfinder(true)
	setFilter(filterIndex)
	if ctx.selfie then
		startSelfie()
	else
		stopSelfie()
	end

	-- mode switch (top)
	local modes = UIKit.new("Frame", {
		Name = "Modes",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 8),
		Size = UDim2.fromOffset(170, 30),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.45,
		Parent = ctx.frame,
	}, { UIKit.corner(UDim.new(0, 8)), UIKit.list(0, true), UIKit.padding(3) })
	for i, m in { "PHOTO", "SELFIE" } do
		local on = (m == "SELFIE") == (ctx.selfie == true)
		local b = UIKit.new("TextButton", {
			Name = "Mode_" .. m,
			LayoutOrder = i,
			Size = UDim2.new(0.5, 0, 1, 0),
			BackgroundColor3 = C.Text,
			BackgroundTransparency = if on then 0 else 1,
			AutoButtonColor = false,
			FontFace = Theme.Fonts.Display,
			Text = m,
			TextColor3 = if on then Color3.new(0, 0, 0) else C.Text,
			TextSize = 13,
			Parent = modes,
		}, { UIKit.corner(UDim.new(0, 8)) })
		b.Activated:Connect(function()
			local want = m == "SELFIE"
			if want ~= (ctx.selfie == true) then
				ctx.selfie = want
				showCamera(ctx)
			end
		end)
	end

	-- framing guides (rule of thirds, very faint)
	local guides = UIKit.new("Frame", {
		Name = "Guides",
		Position = UDim2.fromOffset(0, 46),
		Size = UDim2.new(1, 0, 1, -142),
		BackgroundTransparency = 1,
		Parent = ctx.frame,
	})
	for i = 1, 2 do
		UIKit.new("Frame", { Name = "GuideV", Position = UDim2.fromScale(i / 3, 0), Size = UDim2.new(0, 1, 1, 0), BackgroundColor3 = C.Text, BackgroundTransparency = 0.82, BorderSizePixel = 0, Parent = guides })
		UIKit.new("Frame", { Name = "GuideH", Position = UDim2.fromScale(0, i / 3), Size = UDim2.new(1, 0, 0, 1), BackgroundColor3 = C.Text, BackgroundTransparency = 0.82, BorderSizePixel = 0, Parent = guides })
	end

	-- bottom bar: last photo · shutter · flip
	local bar = UIKit.new("Frame", {
		Name = "Controls",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, 0),
		Size = UDim2.new(1, 0, 0, 96),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.35,
		Parent = ctx.frame,
	})
	local thumb = UIKit.new("ImageButton", {
		Name = "Roll",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.18, 0, 0.5, 0),
		Size = UDim2.fromOffset(46, 46),
		BackgroundColor3 = Color3.fromRGB(30, 30, 34),
		Image = roll[#roll] or "",
		ScaleType = Enum.ScaleType.Crop,
		AutoButtonColor = false,
		Parent = bar,
	}, { UIKit.corner(UDim.new(0, 12)), UIKit.stroke(0.3, C.Text) })
	thumb.Activated:Connect(function()
		showRoll(ctx)
	end)
	local shutter = UIKit.new("TextButton", {
		Name = "Shutter",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(66, 66),
		BackgroundColor3 = C.Text,
		AutoButtonColor = false,
		Text = "",
		Parent = bar,
	}, { UIKit.corner(UDim.new(1, 0)), UIKit.new("UIStroke", { Color = Color3.new(0, 0, 0), Thickness = 3, Transparency = 0.2 }) })
	shutter:SetAttribute("MTL_NoTapSound", true)
	shutter.Selectable = false
	local ring = UIKit.new("Frame", {
		Name = "Ring",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(78, 78),
		BackgroundTransparency = 1,
		Parent = bar,
	}, { UIKit.corner(UDim.new(1, 0)), UIKit.new("UIStroke", { Color = C.Text, Thickness = 3 }) })
	ring.ZIndex = shutter.ZIndex - 1
	local sscale = UIKit.new("UIScale", { Parent = shutter })
	shutter.MouseButton1Down:Connect(function()
		ctx.Motion.tween(sscale, ctx.Motion.Fast, { Scale = 0.88 })
	end)
	shutter.MouseButton1Up:Connect(function()
		ctx.Motion.tween(sscale, ctx.Motion.Fast, { Scale = 1 })
	end)
	shutter.Activated:Connect(function()
		ctx.Motion.tween(sscale, ctx.Motion.Fast, { Scale = 1 })
		shoot(ctx)
	end)
	local flip = UIKit.new("TextButton", {
		Name = "Flip",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.82, 0, 0.5, 0),
		Size = UDim2.fromOffset(46, 46),
		BackgroundColor3 = Color3.fromRGB(30, 30, 34),
		AutoButtonColor = false,
		FontFace = Theme.Fonts.Bold,
		Text = "Flip",
		TextColor3 = C.Text,
		TextSize = 12,
		Parent = bar,
	}, { UIKit.corner(UDim.new(1, 0)) })
	flip.Activated:Connect(function()
		ctx.selfie = not ctx.selfie
		showCamera(ctx)
	end)
	-- filter strip (above the controls): tap a name, or step through with Z / X
	local strip = UIKit.new("ScrollingFrame", {
		Name = "Filters",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 0, 1, -100),
		Size = UDim2.new(1, 0, 0, 30),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.X,
		ScrollingDirection = Enum.ScrollingDirection.X,
		ScrollBarThickness = 0,
		Parent = ctx.frame,
	}, {
		UIKit.new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 4), VerticalAlignment = Enum.VerticalAlignment.Center }),
		UIKit.new("UIPadding", { PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8) }),
	})
	for i, f in FILTERS do
		local on = i == filterIndex
		local b = UIKit.new("TextButton", {
			Name = "Filter_" .. f.name,
			LayoutOrder = i,
			Size = UDim2.fromOffset(0, 24),
			AutomaticSize = Enum.AutomaticSize.X,
			BackgroundColor3 = if on then C.Accent else Color3.new(0, 0, 0),
			BackgroundTransparency = if on then 0 else 0.45,
			AutoButtonColor = false,
			FontFace = Theme.Fonts.Display,
			Text = string.upper(f.name),
			TextColor3 = C.Text,
			TextSize = 12,
			Parent = strip,
		}, { UIKit.corner(UDim.new(0, 8)), UIKit.padding(10, 0, 0) })
		b.Activated:Connect(function()
			filterIndex = i
			showCamera(ctx)
		end)
	end
	if filterIndex > 4 then
		task.defer(function()
			strip.CanvasPosition = Vector2.new(math.max(0, strip.AbsoluteCanvasSize.X - strip.AbsoluteWindowSize.X), 0)
		end)
	end
	local hint = UIKit.label(ctx.frame, if UserInputService.TouchEnabled then "" else "Space = photo   Z / X = filter", { size = 11, dim = true, align = Enum.TextXAlignment.Center, name = "Hint" })
	hint.AnchorPoint = Vector2.new(0.5, 1)
	hint.Position = UDim2.new(0.5, 0, 1, -134)
end

render = function(ctx: any)
	if ctx.view == "roll" then
		showRoll(ctx)
	else
		showCamera(ctx)
	end
end

function App.mount(_frame: Frame, ctx: any)
	ctx.view = "camera"
	ctx.selfie = false
	UIState.push("PhoneCamera", { hideHUD = true, hideWaypoints = true })
	-- putting the phone away leaves the camera (camera back to normal, HUD back)
	ctx.track(ctx.Phone.Closed:Connect(function()
		ctx.home()
	end))
	-- Space = shutter while the viewfinder is up
	ctx.track(UserInputService.InputBegan:Connect(function(input, processed)
		if processed or ctx.view ~= "camera" then
			return
		end
		if input.KeyCode == Enum.KeyCode.Space then
			shoot(ctx)
		elseif input.KeyCode == Enum.KeyCode.Z or input.KeyCode == Enum.KeyCode.X then
			-- (not Q/E: E is the interact key and would hop you into cars)
			local dir = if input.KeyCode == Enum.KeyCode.X then 1 else -1
			filterIndex = (filterIndex - 1 + dir) % #FILTERS + 1
			ctx.sfx("PhoneTap")
			showCamera(ctx)
		end
	end))
	render(ctx)
end

function App.unmount(ctx: any)
	stopSelfie()
	setFilter(nil)
	ctx.Phone.setViewfinder(false)
	ctx.Phone.setCaptureHidden(false)
	UIState.pop("PhoneCamera")
end

return App
