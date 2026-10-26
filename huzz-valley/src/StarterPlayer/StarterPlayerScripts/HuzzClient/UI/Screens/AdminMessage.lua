-- An admin's message to every server (owner, Oct 25 13:20: "make an admin message button for the admin panel, and make
-- it so that when we write something there, it sends it out to all active server appearing on the top of the
-- screen"). HuzzServer/BroadcastService sends it on the "AdminMessage" remote ({ text, from, seconds }, the text
-- already through Roblox's filter); it shows here as one outlined line near the top of the screen for `seconds`,
-- then fades. A newer message replaces the one showing. It is a saved part like every screen (hidden until a message
-- comes).
-- The same line tells everyone when someone boosts the server's luck (owner, Oct 26 09:42: "ATRE_playzYT BOOSTED THE
-- SERVER LUCK: x8"): HuzzServer/LuckService's "LuckBoost" remote ({ name, luck }), the luck in green.
local TweenService = game:GetService("TweenService")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Net = require(Shared.Net)
local UI = script.Parent.Parent
local Kit = require(UI.Kit)
local Scale = require(UI.Scale)

local new = Kit.new

local AdminMessage = {}

-- Owner, Oct 25 15:50 (his picture: a classic Roblox announcement line): "make the admin text look more like this,
-- not how it looks like now, its too ai now". So no box: one line of plain bold white words with a black outline,
-- "Name: message", centred near the top of the screen; it fades in, stays `seconds`, and fades out.
local TOP, H = 64, 30
local SIZE = 22
local BOOST_SECONDS = 6
-- Under the lobby's SERVER LUCK sign and NEXT ROUND plate (Screens/LobbyHud's top group, 347-point page: the plate
-- ends 98 points down, SKIP 140 when it shows), so the line never prints over them (the preview, Oct 26).
local UNDER_PLATE, UNDER_SKIP = 102, 144

function AdminMessage.build(parent: Instance)
	local holder = new("Frame", { Name = "AdminMessage", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, TOP), Size = UDim2.new(0.92, 0, 0, H * 2), BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 45, Visible = false, Parent = parent })
	local line = new("TextLabel", { Name = "Text", Text = "", FontFace = Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.Bold), TextSize = SIZE, TextColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 1, TextXAlignment = Enum.TextXAlignment.Center, TextYAlignment = Enum.TextYAlignment.Top, TextWrapped = true, RichText = true, Size = UDim2.fromScale(1, 1), ZIndex = 46, Parent = holder })
	local outline = new("UIStroke", { Name = "Outline", Color = Color3.new(0, 0, 0), Thickness = 2, Transparency = 0.15, LineJoinMode = Enum.LineJoinMode.Round, Parent = line })

	local shownAt = 0
	local function fade(to: number, time: number)
		TweenService:Create(line, TweenInfo.new(time, Enum.EasingStyle.Quad), { TextTransparency = to }):Play()
		TweenService:Create(outline, TweenInfo.new(time, Enum.EasingStyle.Quad), { Transparency = math.max(to, 0.15) }):Play()
	end
	local function hide(at: number)
		if shownAt ~= at then return end -- (a newer message took over)
		fade(1, 0.6)
		task.delay(0.65, function() if shownAt == at then holder.Visible = false end end)
	end
	local function escape(s: string): string
		return (s:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;"):gsub("\"", "&quot;"))
	end
	local function place()
		local lobby = parent:FindFirstChild("LobbyHud")
		local group = lobby and lobby:FindFirstChild("Round")
		local skip = group and group:FindFirstChild("Skip")
		local under = if skip and skip:IsA("GuiObject") and skip.Visible then UNDER_SKIP else UNDER_PLATE
		holder.Position = UDim2.new(0.5, 0, 0, math.max(TOP, math.ceil(under * Scale.hud(347)) + 2))
	end
	local function show(text: string, seconds: number)
		place()
		line.Text = text
		local at = os.clock()
		shownAt = at
		line.TextTransparency, outline.Transparency = 1, 1
		holder.Visible = true
		fade(0, 0.25)
		task.delay(seconds, hide, at)
	end
	;(Net.get("AdminMessage") :: RemoteEvent).OnClientEvent:Connect(function(m)
		if type(m) ~= "table" or type(m.text) ~= "string" then return end
		local from = if type(m.from) == "string" and m.from ~= "" then m.from else "Admin"
		show(escape(`{from}: {m.text}`), math.clamp(tonumber(m.seconds) or 10, 3, 30))
	end)
	;(Net.get("LuckBoost") :: RemoteEvent).OnClientEvent:Connect(function(m)
		if type(m) ~= "table" or type(m.name) ~= "string" or tonumber(m.luck) == nil then return end
		show(`{escape(m.name)} BOOSTED THE SERVER LUCK: <font color="#3FE184">x{math.floor(tonumber(m.luck) :: number)}</font>`, BOOST_SECONDS)
	end)
	return holder
end

return AdminMessage
