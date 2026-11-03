--!strict
-- GPS: a small north-up map (places + you), and the list of places with live distances. "Route" asks the server
-- to set the GPS waypoint (marker + ground breadcrumbs from WayfindingController); the server checks the place.
-- The map is a placeholder plot until Alex sends a map image (TODO(Alex art): Theme.Phone.MapImage + world bounds).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Locations = require(ReplicatedStorage.MTL.Config.Locations)

local App = { id = "Map", title = "GPS" }

local MAP_H = 190

local function root(): BasePart?
	local char = Players.LocalPlayer.Character
	return char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function visiblePlaces(ctx: any, d: any): { any }
	local out = {}
	local ownsHome = d.Home and d.Home.Owned and next(d.Home.Owned) ~= nil
	for _, place in ctx.Config.Places do
		if ctx.Rules.placeVisible(place, d.Story.Stage, ownsHome == true) then
			local pos = ctx.Rules.placePosition(place, Locations)
			if pos then
				table.insert(out, { place = place, pos = pos })
			end
		end
	end
	return out
end

local function build(ctx: any, d: any)
	ctx.clear()
	local UIKit, Theme, Format = ctx.UIKit, ctx.Theme, ctx.Format
	local C, P = Theme.Colors, Theme.Phone
	UIKit.header(ctx.frame, "GPS")
	local list = UIKit.scroll(ctx.frame, 44, "Places")

	local places = visiblePlaces(ctx, d)

	-- map plot
	local map = UIKit.new("Frame", {
		Name = "MapView",
		LayoutOrder = 0,
		Size = UDim2.new(1, 0, 0, MAP_H),
		BackgroundColor3 = P.Card,
		ClipsDescendants = true,
		Parent = list,
	}, { UIKit.corner(Theme.Corner) })
	UIKit.label(map, "N", { size = 11, dim = true, bold = true, align = Enum.TextXAlignment.Center }).Size = UDim2.new(1, 0, 0, 16)

	local r = root()
	local minX, maxX, minZ, maxZ = math.huge, -math.huge, math.huge, -math.huge
	local function grow(v: Vector3)
		minX, maxX = math.min(minX, v.X), math.max(maxX, v.X)
		minZ, maxZ = math.min(minZ, v.Z), math.max(maxZ, v.Z)
	end
	for _, p in places do
		grow(p.pos)
	end
	if r then
		grow(r.Position)
	end
	if minX == math.huge then
		minX, maxX, minZ, maxZ = -100, 100, -100, 100
	end
	local pad = 80
	minX -= pad
	maxX += pad
	minZ -= pad
	maxZ += pad
	local span = math.max(maxX - minX, maxZ - minZ)
	local cx, cz = (minX + maxX) / 2, (minZ + maxZ) / 2
	local function toMap(v: Vector3): UDim2
		-- uniform scale, north (-Z) up; the frame is wider than tall so fit to height
		local u = (v.X - cx) / span
		local w = (v.Z - cz) / span
		return UDim2.new(0.5, u * MAP_H, 0.5, w * MAP_H)
	end

	local active = Players.LocalPlayer:GetAttribute("MTL_GPS")
	for _, p in places do
		local on = p.place.id == active
		local dot = UIKit.new("Frame", {
			Name = "Dot_" .. p.place.id,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = toMap(p.pos),
			Size = UDim2.fromOffset(if on then 14 else 10, if on then 14 else 10),
			BackgroundColor3 = if on then C.Accent elseif p.place.category == "Home" then C.Gold else C.AccentAlt,
			Parent = map,
		}, { UIKit.corner(UDim.new(1, 0)), UIKit.stroke(0.2, P.Card) })
		local lbl = UIKit.label(dot, p.place.label, { size = 10, align = Enum.TextXAlignment.Center })
		lbl.AnchorPoint = Vector2.new(0.5, 0)
		lbl.Position = UDim2.new(0.5, 0, 1, 1)
		lbl.Size = UDim2.fromOffset(110, 12)
	end
	local me = UIKit.new("TextLabel", {
		Name = "You",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(16, 16),
		BackgroundTransparency = 1,
		FontFace = Theme.Fonts.Display,
		Text = "▲",
		TextColor3 = C.Text,
		TextSize = 14,
		ZIndex = 3,
		Visible = r ~= nil,
		Parent = map,
	}, { UIKit.new("UIStroke", { Color = C.Shadow, Thickness = 1.5, Transparency = 0.3 }) })

	-- route controls
	if active then
		UIKit.button(list, "Clear route", {
			style = "secondary",
			order = 1,
			onClick = function()
				ctx.action("gpsClear")
			end,
		})
	end
	UIKit.section(list, "Places", 2)
	local distLabels: { [string]: TextLabel } = {}
	for i, p in places do
		local on = p.place.id == active
		local row = UIKit.row(list, {
			title = p.place.label,
			sub = p.place.category,
			right = if on then "On route" else "Route",
			rightColor = if on then C.Accent else C.Text,
			glyph = string.sub(p.place.label, 1, 1),
			glyphColor = if p.place.category == "Home" then C.Gold else C.AccentAlt,
			order = 2 + i,
			onClick = function()
				if not on then
					ctx.action("gpsRoute", { place = p.place.id })
				end
			end,
		})
		distLabels[p.place.id] = row:FindFirstChild("Sub") :: TextLabel
	end
	if #places == 0 then
		UIKit.empty(list, "Nowhere to go yet.", 3)
	end

	-- live: your dot and the distances
	local token = {}
	ctx.liveToken = token
	task.spawn(function()
		while ctx.liveToken == token and ctx.frame.Parent do
			local rp = root()
			if rp then
				me.Visible = true
				me.Position = toMap(rp.Position)
				local look = rp.CFrame.LookVector
				me.Rotation = math.deg(math.atan2(look.X, -look.Z))
				for _, p in places do
					local l = distLabels[p.place.id]
					if l then
						l.Text = p.place.category .. "  ·  " .. Format.distance((rp.Position - p.pos).Magnitude)
					end
				end
			end
			task.wait(0.25)
		end
	end)
end

function App.mount(_frame: Frame, ctx: any)
	local lastKey = ""
	local function key(d: any): string
		local owned = d.Home and d.Home.Owned and next(d.Home.Owned) ~= nil
		return tostring(d.Story.Stage) .. "|" .. tostring(owned) .. "|" .. tostring(Players.LocalPlayer:GetAttribute("MTL_GPS"))
	end
	ctx.onData(function(d: any)
		local k = key(d)
		if k ~= lastKey then
			lastKey = k
			build(ctx, d)
		end
	end)
	ctx.track(Players.LocalPlayer:GetAttributeChangedSignal("MTL_GPS"):Connect(function()
		local d = ctx.data()
		if d then
			lastKey = key(d)
			build(ctx, d)
		end
	end))
end

function App.unmount(ctx: any)
	ctx.liveToken = nil
end

return App
