--!strict
-- The set dressing that makes each stage its own place. StageBuilder lays the
-- same canyon every time; everything here is what stops the walk east from
-- feeling like eight copies of one corridor.
--
-- Each decorator gets the stage folder, its base CFrame, its config and the
-- kit, and is free to build whatever suits the location. Decorators are pure
-- geometry: no gameplay, no manifest entries.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Stages = require(ReplicatedStorage.Shared.Config.Stages)

type Kit = any -- OutdoorKit, passed in to avoid a second require of a big module

local StageDecor = {}

local decorators: { [string]: (Folder, CFrame, Stages.Stage, Kit) -> () } = {}

-- ── STAGE 1 — BUSINESS PARK ────────────────────────────────────────────────
-- Low brick offices, a car park nobody parks nicely in, clipped hedges.
decorators.BusinessPark = function(parent, base, stage, Kit)
	local theme = stage.Theme
	local accent = Kit.rgb(theme.Accent)
	local prop = Kit.rgb(theme.Prop)
	local leaf = Color3.fromRGB(96, 176, 82)
	local trunk = Color3.fromRGB(122, 84, 56)

	for _, b in { { -80, -74, 44, 26, 30 }, { -10, -80, 38, 22, 26 }, { 66, -76, 40, 30, 28 } } do
		Kit.building(parent, base, b[1], b[2], b[3], b[4], b[5], prop, accent, true)
	end
	-- Car park: painted bays with chunky cars in a couple of them.
	Kit.plaza(parent, base, 0, 74, 180, 44, Color3.fromRGB(112, 116, 122), Color3.fromRGB(240, 240, 240))
	for i = 0, 7 do
		local x = -76 + i * 22
		Kit.decor(parent, base * CFrame.new(x, 1.05, 74), Vector3.new(0.6, 0.12, 40), Color3.fromRGB(244, 244, 244))
		if i % 3 == 1 then
			local carCol = if i % 2 == 0 then Color3.fromRGB(220, 76, 76) else Color3.fromRGB(70, 120, 220)
			Kit.decor(parent, base * CFrame.new(x + 11, 3.2, 74), Vector3.new(9, 3, 16), carCol)
			Kit.decor(parent, base * CFrame.new(x + 11, 5.6, 75), Vector3.new(7.6, 2.6, 8), Kit.lighten(carCol, 0.25))
			for _, wheel in { { -4, -5 }, { 4, -5 }, { -4, 5 }, { 4, 5 } } do
				Kit.decor(parent, base * CFrame.new(x + 11 + wheel[1], 1.4, 74 + wheel[2]), Vector3.new(1.6, 2.6, 2.6), Color3.fromRGB(38, 38, 42))
			end
		end
	end
	-- Hedges lining the road and a flagpole at the entrance.
	for i = 0, 9 do
		local x = -110 + i * 24
		Kit.decor(parent, base * CFrame.new(x, 2, -34), Vector3.new(18, 4, 5), leaf)
		Kit.decor(parent, base * CFrame.new(x, 2, 34), Vector3.new(18, 4, 5), leaf)
	end
	Kit.part(parent, base * CFrame.new(-100, 14, -46), Vector3.new(1, 28, 1), Color3.fromRGB(210, 214, 220))
	Kit.decor(parent, base * CFrame.new(-95, 25, -46), Vector3.new(10, 6, 0.3), accent)
	for _, spot in { { -120, 84 }, { 96, 88 }, { 118, -60 }, { -40, 96 }, { 40, 94 } } do
		Kit.tree(parent, base, spot[1], spot[2], 1.1, trunk, leaf)
	end
	-- Picnic benches, bike racks and planters: the "business park amenities"
	-- nobody has used since the office reopened.
	for _, b in { { -66, 44 }, { 4, 48 }, { 74, 44 } } do
		Kit.part(parent, base * CFrame.new(b[1], 3, b[2]), Vector3.new(14, 0.8, 5), Color3.fromRGB(168, 124, 76))
		for _, dx in { -5, 5 } do
			Kit.part(parent, base * CFrame.new(b[1] + dx, 1.5, b[2]), Vector3.new(1, 3, 5), Color3.fromRGB(128, 92, 54))
			Kit.decor(parent, base * CFrame.new(b[1] + dx * 1.5, 1.6, b[2]), Vector3.new(3, 0.6, 5), Color3.fromRGB(150, 110, 68))
		end
	end
	for i = 0, 5 do
		local x = -90 + i * 30
		Kit.decor(parent, base * CFrame.new(x, 2, -48), Vector3.new(5, 4, 5), Color3.fromRGB(186, 140, 96))
		Kit.decor(parent, base * CFrame.new(x, 4.6, -48), Vector3.new(6, 1.6, 6), leaf)
	end
	for i = 0, 3 do
		local x = 40 + i * 8
		Kit.decor(parent, base * CFrame.new(x, 2, -60), Vector3.new(0.5, 4, 6), Color3.fromRGB(150, 154, 160))
	end
end

-- ── STAGE 2 — DOWNTOWN ─────────────────────────────────────────────────────
-- Asphalt, taxis stuck in traffic, street lamps, dumpsters, a bus shelter.
decorators.Downtown = function(parent, base, stage, Kit)
	local theme = stage.Theme
	local accent = Kit.rgb(theme.Accent)
	local prop = Kit.rgb(theme.Prop)

	for _, b in { { -92, -76, 40, 60, 30 }, { -28, -84, 36, 78, 26 }, { 40, -78, 42, 52, 30 }, { 104, -80, 34, 66, 26 } } do
		Kit.building(parent, base, b[1], b[2], b[3], b[4], b[5], prop, accent, true)
	end
	-- Taxis, nose to tail, going nowhere.
	for i = 0, 3 do
		local x = -70 + i * 46
		local taxi = Color3.fromRGB(250, 198, 44)
		Kit.decor(parent, base * CFrame.new(x, 3.2, 60), Vector3.new(18, 3.4, 9), taxi)
		Kit.decor(parent, base * CFrame.new(x - 1, 6.2, 60), Vector3.new(9, 2.8, 8), Kit.lighten(taxi, 0.2))
		Kit.decor(parent, base * CFrame.new(x - 1, 8, 60), Vector3.new(3, 1, 2), Color3.fromRGB(40, 40, 46))
		for _, wheel in { { -6, -4.6 }, { 6, -4.6 }, { -6, 4.6 }, { 6, 4.6 } } do
			Kit.decor(parent, base * CFrame.new(x + wheel[1], 1.5, 60 + wheel[2]), Vector3.new(2.8, 3, 1.6), Color3.fromRGB(34, 34, 38))
		end
	end
	-- Street lamps down both sides.
	for i = 0, 6 do
		local x = -104 + i * 36
		for _, side in { -1, 1 } do
			Kit.part(parent, base * CFrame.new(x, 11, side * 40), Vector3.new(0.9, 22, 0.9), Color3.fromRGB(62, 66, 74))
			Kit.decor(parent, base * CFrame.new(x, 22, side * 36), Vector3.new(1, 0.8, 9), Color3.fromRGB(62, 66, 74))
			Kit.decor(parent, base * CFrame.new(x, 21.2, side * 32), Vector3.new(3.4, 1, 5), Color3.fromRGB(255, 240, 190), Enum.Material.Neon)
		end
	end
	-- Dumpsters and a bus shelter.
	for _, d in { { -60, -46 }, { 24, -48 }, { 88, -44 } } do
		Kit.part(parent, base * CFrame.new(d[1], 3, d[2]), Vector3.new(12, 6, 7), Color3.fromRGB(64, 128, 84))
		Kit.decor(parent, base * CFrame.new(d[1], 6.3, d[2]), Vector3.new(12.6, 0.8, 7.6), Color3.fromRGB(48, 100, 66))
	end
	Kit.part(parent, base * CFrame.new(-16, 6, 44), Vector3.new(24, 0.8, 10), Color3.fromRGB(56, 60, 68))
	for _, dx in { -11, 11 } do
		Kit.part(parent, base * CFrame.new(-16 + dx, 3, 44), Vector3.new(0.8, 6, 9), Color3.fromRGB(56, 60, 68))
	end
	Kit.label(parent, base * CFrame.new(-16, 9, 44), "BUS", accent, 28, 10)
end

-- ── STAGE 3 — FINANCIAL DISTRICT ───────────────────────────────────────────
-- Glass towers, a marble fountain, a charging bull, a ticker board.
decorators.FinancialDistrict = function(parent, base, stage, Kit)
	local theme = stage.Theme
	local accent = Kit.rgb(theme.Accent)
	local prop = Kit.rgb(theme.Prop)
	local marble = Color3.fromRGB(240, 240, 244)

	for _, b in { { -96, -80, 34, 96, 30 }, { -34, -88, 30, 120, 26 }, { 30, -84, 32, 104, 28 }, { 96, -82, 30, 84, 26 } } do
		Kit.building(parent, base, b[1], b[2], b[3], b[4], b[5], prop, accent, true)
	end
	-- Fountain: tiered marble with a neon-green water plume.
	Kit.part(parent, base * CFrame.new(-70, 1.6, 62), Vector3.new(30, 3.2, 30), marble)
	Kit.decor(parent, base * CFrame.new(-70, 3.4, 62), Vector3.new(25, 0.8, 25), accent, Enum.Material.Neon)
	Kit.part(parent, base * CFrame.new(-70, 5, 62), Vector3.new(9, 4, 9), marble)
	Kit.decor(parent, base * CFrame.new(-70, 9, 62), Vector3.new(3, 6, 3), accent, Enum.Material.Neon)
	-- The bull, in chunky blocks, on a plinth.
	Kit.part(parent, base * CFrame.new(52, 2, 60), Vector3.new(22, 4, 14), marble)
	local bronze = Color3.fromRGB(150, 112, 58)
	Kit.decor(parent, base * CFrame.new(52, 8, 60), Vector3.new(16, 8, 8), bronze)
	Kit.decor(parent, base * CFrame.new(60, 11, 60), Vector3.new(6, 5, 6), bronze)
	for _, horn in { -2.2, 2.2 } do
		Kit.decor(parent, base * CFrame.new(63, 13.5, 60 + horn), Vector3.new(3, 1, 1), marble)
	end
	for _, leg in { { -6, -3 }, { 6, -3 }, { -6, 3 }, { 6, 3 } } do
		Kit.decor(parent, base * CFrame.new(52 + leg[1], 5.5, 60 + leg[2]), Vector3.new(2.4, 5, 2.4), bronze)
	end
	-- Ticker board on the north wall.
	Kit.part(parent, base * CFrame.new(0, 20, -46), Vector3.new(70, 10, 2), Color3.fromRGB(24, 28, 36))
	Kit.decor(parent, base * CFrame.new(0, 20, -44.8), Vector3.new(66, 7, 0.4), accent, Enum.Material.Neon)
	Kit.label(parent, base * CFrame.new(0, 20, -43.5), "SYNERGY ▲ 12%   MONDAYS ▼ 98%", Color3.fromRGB(20, 30, 24), 30, 44)
end

-- ── STAGE 4 — IMPORT DOCKS ─────────────────────────────────────────────────
-- Stacked containers, gantry cranes, crates and a strip of water.
decorators.Docks = function(parent, base, stage, Kit)
	local theme = stage.Theme
	local accent = Kit.rgb(theme.Accent)
	local containerColors = {
		Color3.fromRGB(196, 84, 64),
		Color3.fromRGB(72, 120, 180),
		Color3.fromRGB(206, 158, 60),
		Color3.fromRGB(88, 148, 108),
	}
	-- Container stacks along both sides, two and three high.
	for i = 0, 6 do
		local x = -110 + i * 34
		for _, side in { -1, 1 } do
			local stackHeight = 2 + (i + (if side < 0 then 0 else 1)) % 2
			for tier = 1, stackHeight do
				local col = containerColors[((i + tier + (if side < 0 then 0 else 2)) % 4) + 1]
				local c = Kit.part(
					parent,
					base * CFrame.new(x, tier * 9 - 4.5, side * 62),
					Vector3.new(26, 9, 11),
					col
				)
				c.Name = "Container"
				-- Corrugation: thin ribs so a container is not a plain box.
				for rib = -2, 2 do
					Kit.decor(parent, base * CFrame.new(x + rib * 5, tier * 9 - 4.5, side * 62 - 5.7), Vector3.new(1.2, 8, 0.4), Kit.darken(col, 0.18))
				end
				Kit.decor(parent, base * CFrame.new(x, tier * 9 - 0.2, side * 62), Vector3.new(26.6, 0.6, 11.6), Kit.darken(col, 0.3))
			end
		end
	end
	-- Two gantry cranes straddling the road.
	for _, cx in { -60, 60 } do
		for _, side in { -1, 1 } do
			Kit.part(parent, base * CFrame.new(cx, 22, side * 42), Vector3.new(3, 44, 3), accent)
		end
		Kit.decor(parent, base * CFrame.new(cx, 45, 0), Vector3.new(4, 3, 90), accent)
		Kit.decor(parent, base * CFrame.new(cx, 40, 0), Vector3.new(8, 7, 10), Kit.darken(accent, 0.3))
		Kit.decor(parent, base * CFrame.new(cx, 30, 0), Vector3.new(1, 14, 1), Color3.fromRGB(180, 184, 190))
	end
	-- Crates near the road, and water beyond the south wall.
	for _, c in { { -86, 30 }, { -74, 36 }, { 18, -32 }, { 96, 32 } } do
		Kit.part(parent, base * CFrame.new(c[1], 3, c[2]), Vector3.new(8, 6, 8), Color3.fromRGB(168, 124, 76))
		Kit.decor(parent, base * CFrame.new(c[1], 3, c[2] - 4.1), Vector3.new(8.2, 1.2, 0.4), Color3.fromRGB(128, 92, 54))
	end
	local water = Kit.decor(parent, base * CFrame.new(0, 0.2, 108), Vector3.new(300, 1, 60), Color3.fromRGB(64, 150, 190), Enum.Material.Neon)
	water.Transparency = 0.35
end

-- ── STAGE 5 — TECH CAMPUS ──────────────────────────────────────────────────
-- Glass cubes, outdoor ping-pong, scooters, solar canopies, neon slogans.
decorators.TechCampus = function(parent, base, stage, Kit)
	local theme = stage.Theme
	local accent = Kit.rgb(theme.Accent)
	local prop = Kit.rgb(theme.Prop)

	for _, b in { { -88, -74, 46, 34, 34 }, { -8, -80, 52, 28, 38 }, { 78, -76, 44, 40, 34 } } do
		local building = Kit.building(parent, base, b[1], b[2], b[3], b[4], b[5], prop, accent, false)
		-- Full-height glazing instead of punched windows.
		for i = -1, 1 do
			local glass = Kit.decor(
				parent,
				base * CFrame.new(b[1] + i * (b[3] / 3.2), b[4] / 2, b[2] - b[5] / 2 - 0.3),
				Vector3.new(b[3] / 4, b[4] - 4, 0.5),
				Color3.fromRGB(150, 220, 235)
			)
			glass.Transparency = 0.35
			glass.Parent = building
		end
	end
	-- Solar canopies over the walkway.
	for i = 0, 4 do
		local x = -90 + i * 46
		for _, side in { -1, 1 } do
			Kit.part(parent, base * CFrame.new(x, 8, side * 44), Vector3.new(1.4, 16, 1.4), Color3.fromRGB(190, 194, 200))
		end
		local panel = Kit.decor(parent, base * CFrame.new(x, 16.6, 0), Vector3.new(12, 0.8, 84), Color3.fromRGB(38, 52, 90))
		panel.Name = "SolarPanel"
		for rib = -3, 3 do
			Kit.decor(parent, base * CFrame.new(x, 17.1, rib * 12), Vector3.new(12.2, 0.2, 0.5), Color3.fromRGB(90, 120, 180))
		end
	end
	-- Ping-pong table and scooters, because of course.
	Kit.part(parent, base * CFrame.new(-56, 3, 66), Vector3.new(18, 0.8, 10), Color3.fromRGB(52, 120, 96))
	Kit.decor(parent, base * CFrame.new(-56, 4.6, 66), Vector3.new(0.4, 2.4, 10), Color3.fromRGB(240, 240, 240))
	for _, leg in { { -8, -4 }, { 8, -4 }, { -8, 4 }, { 8, 4 } } do
		Kit.part(parent, base * CFrame.new(-56 + leg[1], 1.4, 66 + leg[2]), Vector3.new(0.8, 2.8, 0.8), Color3.fromRGB(60, 64, 70))
	end
	for i = 0, 3 do
		local x = 20 + i * 12
		Kit.decor(parent, base * CFrame.new(x, 3.4, 64), Vector3.new(1, 6, 1), Color3.fromRGB(70, 74, 82))
		Kit.decor(parent, base * CFrame.new(x, 0.9, 66), Vector3.new(1.4, 1.4, 9), Color3.fromRGB(220, 224, 230))
		Kit.decor(parent, base * CFrame.new(x, 6.4, 64), Vector3.new(5, 0.8, 1), Color3.fromRGB(70, 74, 82))
	end
	Kit.label(parent, base * CFrame.new(0, 30, -44), "MOVE FAST · BREAK SPREADSHEETS", accent, 34, 40)
	-- Bean bags, whiteboards on wheels, and a wall of potted plants.
	for i = 0, 7 do
		local angle = i * math.pi / 4
		local bag = Kit.decor(
			parent,
			base * CFrame.new(-20 + math.cos(angle) * 16, 1.6, 76 + math.sin(angle) * 12),
			Vector3.new(5, 3.2, 5),
			if i % 2 == 0 then Color3.fromRGB(255, 150, 90) else Color3.fromRGB(120, 200, 255)
		)
		bag.Name = "BeanBag"
	end
	for i = 0, 4 do
		local x = -80 + i * 34
		Kit.part(parent, base * CFrame.new(x, 6, -60), Vector3.new(16, 10, 0.6), Color3.fromRGB(248, 248, 250))
		Kit.decor(parent, base * CFrame.new(x, 11.4, -60), Vector3.new(17, 1, 1.4), accent)
		for _, dx in { -6, 6 } do
			Kit.part(parent, base * CFrame.new(x + dx, 0.6, -60), Vector3.new(1, 1.2, 3), Color3.fromRGB(120, 124, 132))
		end
		-- The graph on the whiteboard only ever goes up.
		for step = 0, 4 do
			Kit.decor(parent, base * CFrame.new(x - 6 + step * 3, 3 + step * 1.5, -59.6), Vector3.new(3, 0.5, 0.3), Color3.fromRGB(90, 200, 120))
		end
	end
	for i = 0, 9 do
		local x = -100 + i * 22
		Kit.decor(parent, base * CFrame.new(x, 2, 44), Vector3.new(4.5, 4, 4.5), Color3.fromRGB(210, 214, 220))
		Kit.decor(parent, base * CFrame.new(x, 5.4, 44), Vector3.new(6, 3, 6), Color3.fromRGB(104, 190, 110))
	end
end

-- ── STAGE 6 — THE SKYLINE ──────────────────────────────────────────────────
-- You are on the roof now: AC units, a helipad, water tower, antenna masts.
decorators.Skyline = function(parent, base, stage, Kit)
	local theme = stage.Theme
	local accent = Kit.rgb(theme.Accent)
	local prop = Kit.rgb(theme.Prop)

	-- Neighbouring towers rising past the canyon walls, so the height reads.
	for _, b in { { -104, -84, 34, 120, 30 }, { -30, -92, 30, 150, 28 }, { 44, -88, 36, 132, 30 }, { 110, -86, 28, 110, 26 } } do
		Kit.building(parent, base, b[1], b[2], b[3], b[4], b[5], prop, accent, true)
	end
	for _, b in { { -80, 92, 30, 100, 28 }, { 20, 96, 34, 128, 30 }, { 104, 90, 28, 96, 26 } } do
		Kit.building(parent, base, b[1], b[2], b[3], b[4], b[5], Kit.darken(prop, 0.12), accent, true)
	end
	-- Helipad with the big H.
	local pad = Kit.part(parent, base * CFrame.new(-64, 1.2, 62), Vector3.new(44, 2.4, 44), Color3.fromRGB(58, 62, 70))
	pad.Name = "Helipad"
	Kit.decor(parent, base * CFrame.new(-64, 2.5, 62), Vector3.new(36, 0.3, 36), Color3.fromRGB(72, 76, 84))
	for _, bar in { { -6, 0, 3, 18 }, { 6, 0, 3, 18 }, { 0, 0, 9, 3 } } do
		Kit.decor(parent, base * CFrame.new(-64 + bar[1], 2.7, 62 + bar[2]), Vector3.new(bar[3], 0.3, bar[4]), accent)
	end
	for i = 0, 7 do
		local angle = i * math.pi / 4
		Kit.decor(parent, base * CFrame.new(-64 + math.cos(angle) * 21, 2.6, 62 + math.sin(angle) * 21), Vector3.new(1.4, 0.8, 1.4), accent, Enum.Material.Neon)
	end
	-- AC units and vents scattered over the roof.
	for _, unit in { { -20, -60 }, { 6, -66 }, { 40, -58 }, { 74, -64 }, { 96, 58 }, { 30, 66 } } do
		Kit.part(parent, base * CFrame.new(unit[1], 4, unit[2]), Vector3.new(14, 8, 12), Color3.fromRGB(158, 162, 170))
		Kit.decor(parent, base * CFrame.new(unit[1], 8.4, unit[2]), Vector3.new(9, 1, 9), Color3.fromRGB(112, 116, 124))
		Kit.decor(parent, base * CFrame.new(unit[1], 9.4, unit[2]), Vector3.new(6, 1.2, 6), Color3.fromRGB(80, 84, 92))
	end
	-- Water tower on legs.
	for _, leg in { { -6, -6 }, { 6, -6 }, { -6, 6 }, { 6, 6 } } do
		Kit.part(parent, base * CFrame.new(88 + leg[1], 9, -60 + leg[2]), Vector3.new(1.4, 18, 1.4), Color3.fromRGB(96, 74, 56))
	end
	Kit.part(parent, base * CFrame.new(88, 24, -60), Vector3.new(20, 14, 20), Color3.fromRGB(126, 96, 70))
	Kit.decor(parent, base * CFrame.new(88, 32, -60), Vector3.new(21, 3, 21), Color3.fromRGB(96, 74, 56))
	-- Antenna masts with blinking-red tips.
	for _, mx in { -100, 116 } do
		Kit.part(parent, base * CFrame.new(mx, 26, 0), Vector3.new(1.6, 52, 1.6), Color3.fromRGB(180, 184, 190))
		Kit.decor(parent, base * CFrame.new(mx, 53, 0), Vector3.new(2.6, 2.6, 2.6), Color3.fromRGB(255, 70, 70), Enum.Material.Neon)
	end
end

-- ── STAGE 7 — THE BOARDROOM ────────────────────────────────────────────────
-- An absurdly oversized boardroom, outdoors, with chairs you could live in.
decorators.Boardroom = function(parent, base, stage, Kit)
	local theme = stage.Theme
	local accent = Kit.rgb(theme.Accent)
	local wood = Kit.rgb(theme.Prop)

	-- The table: a 200-stud slab of polished wood down the middle of the road.
	local table_ = Kit.part(parent, base * CFrame.new(-10, 7, 0), Vector3.new(200, 2.4, 34), wood)
	table_.Name = "BoardTable"
	Kit.decor(parent, base * CFrame.new(-10, 8.4, 0), Vector3.new(190, 0.4, 28), Kit.lighten(wood, 0.18))
	for _, edge in { -17.4, 17.4 } do
		Kit.decor(parent, base * CFrame.new(-10, 6.4, edge), Vector3.new(200, 1, 1.2), accent)
	end
	for _, lx in { -95, -35, 25, 80 } do
		Kit.part(parent, base * CFrame.new(lx, 3, 0), Vector3.new(8, 8, 26), Kit.darken(wood, 0.25))
	end
	-- Giant chairs down both sides.
	for i = 0, 5 do
		local x = -90 + i * 34
		for _, side in { -1, 1 } do
			local z = side * 30
			Kit.part(parent, base * CFrame.new(x, 5, z), Vector3.new(14, 2, 14), Kit.darken(wood, 0.35))
			Kit.part(parent, base * CFrame.new(x, 13, z + side * 6), Vector3.new(14, 18, 2.4), Kit.darken(wood, 0.3))
			Kit.decor(parent, base * CFrame.new(x, 21.4, z + side * 6), Vector3.new(14.6, 1.4, 3), accent)
			for _, leg in { { -5, -5 }, { 5, -5 }, { -5, 5 }, { 5, 5 } } do
				Kit.part(parent, base * CFrame.new(x + leg[1], 2, z + leg[2]), Vector3.new(1.6, 4, 1.6), Kit.darken(wood, 0.5))
			end
		end
	end
	-- Portraits of previous chairmen glaring down from the north wall.
	for i = 0, 4 do
		local x = -96 + i * 48
		Kit.decor(parent, base * CFrame.new(x, 24, -46), Vector3.new(20, 26, 1.4), accent)
		Kit.decor(parent, base * CFrame.new(x, 24, -45), Vector3.new(17, 23, 0.6), Kit.darken(wood, 0.15))
		Kit.label(parent, base * CFrame.new(x, 24, -44), "CHAIRMAN " .. tostring(i + 1), Kit.lighten(accent, 0.4), 26, 16)
	end
	-- Chandeliers over the table.
	for _, cx in { -70, -10, 50 } do
		Kit.decor(parent, base * CFrame.new(cx, 34, 0), Vector3.new(1, 14, 1), Kit.darken(accent, 0.3))
		Kit.decor(parent, base * CFrame.new(cx, 26, 0), Vector3.new(18, 2, 18), accent, Enum.Material.Neon)
		for i = 0, 5 do
			local angle = i * math.pi / 3
			Kit.decor(parent, base * CFrame.new(cx + math.cos(angle) * 8, 24, math.sin(angle) * 8), Vector3.new(1.6, 3, 1.6), Color3.fromRGB(255, 245, 210), Enum.Material.Neon)
		end
	end
	-- Paperwork, water carafes and microphones down the table.
	for i = 0, 11 do
		local x = -100 + i * 17
		Kit.decor(parent, base * CFrame.new(x, 8.9, -7), Vector3.new(4, 0.4, 3), Color3.fromRGB(248, 246, 238))
		Kit.decor(parent, base * CFrame.new(x, 9.2, 7), Vector3.new(3.4, 0.5, 2.6), Color3.fromRGB(240, 238, 230))
		if i % 3 == 0 then
			Kit.decor(parent, base * CFrame.new(x, 10.2, 0), Vector3.new(1.6, 3, 1.6), Color3.fromRGB(190, 220, 235))
			Kit.decor(parent, base * CFrame.new(x + 4, 9.6, 0), Vector3.new(0.6, 2.4, 0.6), Color3.fromRGB(50, 54, 62))
			Kit.decor(parent, base * CFrame.new(x + 4, 11, 0), Vector3.new(1.2, 1, 1.2), Color3.fromRGB(70, 74, 84))
		end
	end
	-- Wood panelling and sconces along both walls.
	for i = 0, 9 do
		local x = -104 + i * 24
		for _, side in { -1, 1 } do
			Kit.decor(parent, base * CFrame.new(x, 10, side * 47), Vector3.new(20, 20, 1), Kit.darken(wood, 0.1))
			Kit.decor(parent, base * CFrame.new(x, 20.5, side * 46), Vector3.new(21, 1.2, 2), accent)
			Kit.decor(parent, base * CFrame.new(x + 11, 14, side * 45.5), Vector3.new(1.4, 3, 1.4), Color3.fromRGB(255, 236, 170), Enum.Material.Neon)
		end
	end
end

-- ── STAGE 8 — ORBITAL HQ ───────────────────────────────────────────────────
-- Chrome decks over open space, Earth below, a starfield overhead.
decorators.Orbital = function(parent, base, stage, Kit)
	local theme = stage.Theme
	local accent = Kit.rgb(theme.Accent)
	local chrome = Color3.fromRGB(186, 196, 208)

	-- Starfield: a deterministic golden-angle spiral, so every server matches.
	local golden = math.pi * (3 - math.sqrt(5))
	for i = 1, 90 do
		local t = (i - 0.5) / 90
		local inclination = math.acos(1 - 2 * t)
		local azimuth = golden * i
		local radius = 250
		local size = 1.4 + (i % 4) * 0.6
		Kit.decor(
			parent,
			base * CFrame.new(
				math.sin(inclination) * math.cos(azimuth) * radius,
				math.abs(math.cos(inclination)) * 150 + 60,
				math.sin(inclination) * math.sin(azimuth) * radius
			),
			Vector3.new(size, size, size),
			if i % 6 == 0 then accent else Color3.fromRGB(255, 255, 255),
			Enum.Material.Neon
		)
	end
	-- Earth, far below the deck, with an atmosphere halo.
	local earth = Kit.decor(parent, base * CFrame.new(0, -260, 90), Vector3.new(300, 300, 300), Color3.fromRGB(42, 104, 172))
	earth.Shape = Enum.PartType.Ball
	local halo = Kit.decor(parent, base * CFrame.new(0, -260, 90), Vector3.new(322, 322, 322), Color3.fromRGB(120, 205, 255), Enum.Material.Neon)
	halo.Shape = Enum.PartType.Ball
	halo.Transparency = 0.82
	for _, land in { { 0.5, 0.4, 0.3, 96 }, { -0.5, 0.2, 0.5, 78 }, { 0.2, -0.5, -0.4, 88 } } do
		local dir = Vector3.new(land[1], land[2], land[3]).Unit
		local blob = Kit.decor(
			parent,
			base * CFrame.new(dir.X * 141, -260 + dir.Y * 141, 90 + dir.Z * 141),
			Vector3.new(land[4], land[4], land[4]),
			Color3.fromRGB(74, 148, 84)
		)
		blob.Shape = Enum.PartType.Ball
	end
	-- Chrome arches and holo-pylons framing the road.
	for i = 0, 5 do
		local x = -110 + i * 44
		for _, side in { -1, 1 } do
			Kit.part(parent, base * CFrame.new(x, 14, side * 40), Vector3.new(2.6, 28, 2.6), chrome)
			Kit.decor(parent, base * CFrame.new(x, 28.6, side * 40), Vector3.new(4, 1.4, 4), accent, Enum.Material.Neon)
		end
		Kit.decor(parent, base * CFrame.new(x, 29, 0), Vector3.new(3, 1.6, 82), chrome)
	end
	-- Floating holo-panels along the sides.
	for _, spot in { { -70, -58 }, { -10, 60 }, { 50, -60 }, { 100, 58 } } do
		Kit.decor(parent, base * CFrame.new(spot[1], 3, spot[2]), Vector3.new(6, 0.6, 6), accent, Enum.Material.Neon)
		Kit.decor(parent, base * CFrame.new(spot[1], 12, spot[2]), Vector3.new(0.5, 16, 0.5), chrome)
		local screen = Kit.decor(parent, base * CFrame.new(spot[1], 20, spot[2]), Vector3.new(14, 9, 0.5), Color3.fromRGB(40, 90, 160), Enum.Material.Neon)
		screen.Transparency = 0.25
	end
	Kit.label(parent, base * CFrame.new(0, 40, -44), "ORBITAL HQ · FLOOR ???", accent, 44, 40)
	-- Deck plating, cargo pods and antenna arrays give the platform substance.
	for i = 0, 9 do
		local x = -110 + i * 26
		for _, side in { -1, 1 } do
			Kit.decor(parent, base * CFrame.new(x, 0.15, side * 30), Vector3.new(22, 0.4, 16), Kit.lighten(Kit.rgb(stage.Theme.Ground), 0.1))
			Kit.decor(parent, base * CFrame.new(x, 0.3, side * 30), Vector3.new(20, 0.3, 1), accent, Enum.Material.Neon)
		end
	end
	for i = 0, 5 do
		local x = -96 + i * 40
		local side = if i % 2 == 0 then -1 else 1
		Kit.part(parent, base * CFrame.new(x, 4, side * 62), Vector3.new(12, 8, 10), chrome)
		Kit.decor(parent, base * CFrame.new(x, 8.4, side * 62), Vector3.new(13, 1, 11), accent)
		Kit.decor(parent, base * CFrame.new(x, 4, side * 56.8), Vector3.new(6, 4, 0.5), Color3.fromRGB(40, 90, 160), Enum.Material.Neon)
	end
	for i = 0, 4 do
		local x = -80 + i * 40
		Kit.part(parent, base * CFrame.new(x, 16, -70), Vector3.new(1.2, 32, 1.2), chrome)
		Kit.decor(parent, base * CFrame.new(x, 32, -70), Vector3.new(8, 0.6, 8), accent, Enum.Material.Neon)
		Kit.decor(parent, base * CFrame.new(x, 33.5, -70), Vector3.new(3, 2.4, 3), Color3.fromRGB(255, 255, 255), Enum.Material.Neon)
	end
end

-- Nothing to dress for the hub; it builds its own furniture.
function StageDecor.decorate(stageId: string, parent: Folder, base: CFrame, stage: Stages.Stage, kit: Kit)
	local decorator = decorators[stageId]
	if decorator then
		decorator(parent, base, stage, kit)
	end
end

return StageDecor
