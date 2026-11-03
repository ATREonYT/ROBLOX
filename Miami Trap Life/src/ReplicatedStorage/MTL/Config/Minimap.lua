--!strict
-- The round radar (bottom-left), its GPS route and the full-screen map. Look follows Theme.HUD (plain dark grey,
-- white text, gold = "go here" from UI/Guide). Roads come from ReplicatedStorage.MTL_RoadMap (tools/BakeRoadMap.lua).
-- Places on the map: Config/HUD.Markers.List (emoji) + Config/Phone.Places (jobs, home) + live waypoints.
local C = Color3.fromRGB

return {
	-- radar
	Size = 196, -- px, desktop / tablet
	SmallSize = 148, -- px when the screen is short (phones)
	SmallBelow = 560, -- viewport height that counts as short
	Margin = 16, -- px from the left and bottom edges
	ZoomFoot = 0.42, -- px per stud on foot (radar shows about 230 studs each way)
	ZoomDrive = 0.2, -- px per stud at speed
	DriveSpeed = 45, -- studs/s that counts as full speed for the zoom
	CullCell = 256, -- studs; road pieces are grouped in squares this size and only nearby squares draw
	BlipSize = 22,
	RotateWithCamera = true, -- false = north up
	Shape = "Circle", -- "Circle" (CanvasGroup clip) or "Rounded" (rounded square, plain clipping, works everywhere)

	-- full map
	MapKeys = { Enum.KeyCode.N, Enum.KeyCode.ButtonSelect },
	MapZoomStart = 0.3,
	MapZoomMin = 0.07,
	MapZoomMax = 1.4,
	PinId = "MapPin", -- the waypoint the player sets on the full map (client-only, cleared on arrival)
	PinArrive = 24, -- studs

	-- route
	RouteWidth = 13, -- studs (drawn on the map, so it gets thinner as the radar zooms out)
	Reroute = 1.2, -- seconds between route refreshes while moving
	OffRoute = 35, -- studs off the line -> refresh now

	Colors = {
		Land = C(33, 35, 41),
		Road = C(84, 88, 98),
		Highway = C(118, 122, 134),
		Water = C(36, 58, 86),
		Ring = C(255, 255, 255),
		RingTransparency = 0.82,
		Player = C(245, 245, 245),
		Pin = C(240, 192, 72), -- same gold as Guide.Color
	},

	-- blips that are not in Config/HUD.Markers (Phone.Places categories)
	CategoryEmoji = { Work = "💼", Home = "🏠" },
}
