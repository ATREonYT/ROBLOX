-- An admin's message to every server (owner, Oct 25 13:20: "make an admin message button for the admin panel, and make
-- it so that when we write something there, it sends it out to all active server appearing on the top of the
-- screen"). HuzzServer/BroadcastService sends it on the "AdminMessage" remote ({ text, from, seconds }, the text
-- already through Roblox's filter); it shows here as a gold banner across the top of the screen, under the toasts,
-- for `seconds`, then slides away. A newer message replaces the one showing. The banner is a saved part like every
-- screen (hidden until a message comes).
local TweenService = game:GetService("TweenService")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Net = require(Shared.Net)
local UI = script.Parent.Parent
local Theme = require(UI.Theme)
local Kit = require(UI.Kit)

local new = Kit.new
local C, F = Theme.Colors, Theme.Fonts

local AdminMessage = {}

local W, H, TOP = 640, 66, 60
local GOLD = Color3.fromHex("FFC24A")

function AdminMessage.build(parent: Instance)
	local banner = new("Frame", { Name = "AdminMessage", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, TOP), Size = UDim2.fromOffset(W, H), BackgroundColor3 = Color3.fromHex("221A3D"), BackgroundTransparency = 0.08, BorderSizePixel = 0, ZIndex = 45, Visible = false, Parent = parent }, { Kit.corner(10) })
	new("UIStroke", { Name = "Rim", Color = GOLD, Thickness = 2.5, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = banner })
	new("UISizeConstraint", { Name = "Fit", MaxSize = Vector2.new(W, H), Parent = banner })
	banner.Size = UDim2.new(0.9, 0, 0, H)
	local head = Kit.text({ Name = "From", Text = "MESSAGE FROM THE ADMINS", FontFace = F.Button, TextSize = 13, TextColor3 = GOLD, TextXAlignment = Enum.TextXAlignment.Center, TextWrapped = false, Position = UDim2.fromOffset(12, 5), Size = UDim2.new(1, -24, 0, 16), ZIndex = 46, Parent = banner })
	local body = Kit.text({ Name = "Text", Text = "", FontFace = F.Heading, TextSize = 20, TextColor3 = Color3.new(1, 1, 1), TextXAlignment = Enum.TextXAlignment.Center, TextWrapped = true, TextScaled = false, Position = UDim2.fromOffset(12, 22), Size = UDim2.new(1, -24, 0, 40), ZIndex = 46, Parent = banner })
	new("UIStroke", { Name = "Outline", Color = C.TitleStroke, Thickness = 1.5, LineJoinMode = Enum.LineJoinMode.Round, Parent = body })
	new("UITextSizeConstraint", { Name = "Fit", MinTextSize = 12, MaxTextSize = 20, Parent = body })
	body.TextScaled = true

	local shownAt = 0
	local function hide(at: number)
		if shownAt ~= at then return end -- (a newer message took over)
		local t = TweenService:Create(banner, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Position = UDim2.new(0.5, 0, 0, -H - 10) })
		t:Play()
		t.Completed:Connect(function() if shownAt == at then banner.Visible = false end end)
	end
	;(Net.get("AdminMessage") :: RemoteEvent).OnClientEvent:Connect(function(m)
		if type(m) ~= "table" or type(m.text) ~= "string" then return end
		head.Text = if type(m.from) == "string" and m.from ~= "" then `MESSAGE FROM {string.upper(m.from)}` else "MESSAGE FROM THE ADMINS"
		body.Text = m.text
		local at = os.clock()
		shownAt = at
		banner.Position = UDim2.new(0.5, 0, 0, -H - 10)
		banner.Visible = true
		TweenService:Create(banner, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Position = UDim2.new(0.5, 0, 0, TOP) }):Play()
		task.delay(math.clamp(tonumber(m.seconds) or 10, 3, 30), hide, at)
	end)
	return banner
end

return AdminMessage
