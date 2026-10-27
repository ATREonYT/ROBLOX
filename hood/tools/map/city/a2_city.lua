---------------------------------------------------------------------------------------------- World 2: Downtown (city)
-- TheCity: World 2's map (hood/docs/WORLD2.md; the owner, Oct 27: "make the second world more advanced ... more of a
-- city, not the hood, as they are escaping the hood"). Assembled by tools/map/city_assemble.sh from World 1's shared
-- pieces (the kit, the lobby's zone builders, the stage gates, the look pass, the build) plus the city's own:
--   city/c_layout.lua   the layout constants: the golden slice builds Stage 1 and 2 (and gate 3, shut)
--   city/e5_plaza.lua   the lobby: an open downtown plaza (calm light stone floor, low planter walls round it, glass
--                       towers all round behind a ring street) in place of the warehouse; the same zones and slots
--   city/f5_avenue.lua  the stages: a downtown avenue (asphalt, white lane lines, crosswalks, stone sidewalks, glass
--                       towers on warm stone bases, taxis, a bus stop, planters with trees, food trucks)
-- Same contracts as TheBlockV2 (the root's Active / Origin / LobbySpawn / LobbySpawnYaw, Training_<Id> stations,
-- HoodStageGate models, HoodStagePad parts, HoodFightPad markers, the lobby slots), the root named TheCity with
-- HoodWorld = 2. Command Bar:  require(game.ServerStorage.TheCity).Build()
V2.Name, V2.World, V2.Where = 'TheCity', 2, 'city'

-- The avenue's colours (the bright reference palette: light clean stone, mid asphalt, white lines) over the hood
-- street's: f_areas' ground and the gate builders read P.st.
P.st.road, P.st.roadDark, P.st.dash = C(98, 104, 122), C(84, 90, 106), C(250, 250, 250)
P.st.walk, P.st.kerbStone, P.st.walkJoint = C(232, 226, 214), C(246, 244, 238), C(210, 202, 188)
P.st.grass, P.st.grassDark, P.st.grassEdge = C(222, 212, 194), C(206, 194, 174), C(196, 184, 164)
P.st.gutter, P.st.manhole = C(120, 126, 142), C(92, 98, 114)

-- The city's own builders and colours (city/e5_plaza.lua and city/f5_avenue.lua fill it): one table, so the chunk keeps
-- its spare locals (check_locals).
local City = {
	-- the plaza's warm sand pavers (two tones), its edge stone, the planters' terracotta and the hedges on them
	paverA = C(238, 212, 168), paverB = C(232, 204, 158), edge = C(222, 186, 140), edgeCap = C(246, 232, 206),
	clay = C(214, 140, 102), clayCap = C(240, 206, 168), hedge = C(76, 186, 84), hedgeTop = C(112, 210, 100),
	walk = P.st.walk, kerb = P.st.kerbStone, road = P.st.road, line = C(250, 250, 250), yellow = C(255, 206, 40),
	-- glass towers: sky-blue, teal and violet-blue glass, white mullions, warm stone bases, steel-blue roofs
	glass = { C(126, 196, 248), C(108, 214, 226), C(150, 168, 250), C(134, 224, 206) },
	base = { C(228, 180, 130), C(216, 140, 104), C(242, 218, 176), C(206, 160, 118) },
	mullion = C(244, 247, 252), roof = C(96, 112, 156), roofDark = C(78, 92, 132), doorGlass = C(46, 70, 108),
	taxiYellow = C(255, 204, 32), steel = C(150, 162, 186), steelDark = C(96, 108, 136),
}
