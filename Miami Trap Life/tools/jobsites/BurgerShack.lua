-- Burger Shack: full interior rebuild for the Restaurant (Cook) job.
-- Run:  require(game.ServerStorage.MTL_Tools.JobSite_BurgerShack)()
-- Builds <Shops model at (-1453,-471)>.BurgerShackV2 and moves the Restaurant stations inside (they were out on the
-- sidewalk). Old interior parts go to ServerStorage.MTL_ReplacedJobSites.BurgerShack. Re-running rebuilds.
--
-- Layout (world, the glass front is at z -453.6 facing +Z / the street, floor top y 2.15, the door at x -1449.3):
--   dining  z -453.5..-470 : three window booths (Table1-3), two 2-tops, soda fountain, checker floor
--   counter z -472          : order counter wall to wall, registers, heat-lamp pass (Pass), menu boards above
--   kitchen z -473..-491.8  : back line (fryers, flat-top Grill, stove, prep fridge) under a hood, prep island (Prep),
--                             staff corner with the TimeClock by the kitchen gap at the west end, shelving, dish sink
local K = require(script.Parent.JobSiteKit)
local C, M = K.C, K.M

local FY = 2.15
local XW, XE = -1452.35, -1413.35 -- the east wall's plaster sticks out past its inner panel
local ZF, ZB = -453.5, -491.85
local CEIL = 15.85
local ZC = -472 -- order counter centre line

local function W(x, y, z)
	return CFrame.new(x, FY + y, z)
end
local V = Vector3.new

return function()
	local shop
	for _, m in workspace.ViceBay.Landmarks.Hood:GetChildren() do
		if m.Name == "Shops" and m:IsA("Model") and (m:GetPivot().Position - V(-1452.7, 22, -471)).Magnitude < 30 then
			shop = m
		end
	end
	assert(shop, "Burger Shack Shops model not found")
	local site = "BurgerShack"

	local old = shop:FindFirstChild("BurgerShackV2")
	if old then
		old:Destroy()
	end
	local moved = 0
	for _, p in shop:GetChildren() do
		if p:IsA("BasePart") then
			local q = p.Position
			if q.X > XW + 0.05 and q.X < XE - 0.05 and q.Z < ZF - 0.1 and q.Z > ZB + 0.02 and q.Y > FY + 0.05 and q.Y < CEIL then
				K.stash(site, p)
				moved += 1
			end
		end
	end

	local model = Instance.new("Model")
	model.Name = "BurgerShackV2"
	model:SetAttribute("MTL_Style", "JobInteriorV2")
	local b = K.builder(model)
	local P, group = b.P, b.group
	local rng = Random.new(1442)
	local RED, CREAM, STEEL, DARK = C(178, 34, 34), C(244, 232, 206), C(196, 198, 202), C(36, 36, 40)

	---------------------------------------------------------------- room
	do
		local g = group("Room")
		local dz0, dz1 = ZF, ZC + 1 -- dining floor
		local dining = P("FloorDining", V(XE - XW, 0.05, dz0 - dz1), CFrame.new((XW + XE) / 2, FY - 0.005, (dz0 + dz1) / 2), C(240, 240, 236), M.SmoothPlastic, { parent = g })
		K.checker(dining, Enum.NormalId.Top, 16, 7, C(236, 234, 228), C(170, 32, 32))
		P("FloorKitchen", V(XE - XW, 0.05, (ZC + 1) - ZB), CFrame.new((XW + XE) / 2, FY - 0.005, (ZC + 1 + ZB) / 2), C(150, 72, 52), M.CeramicTiles, { parent = g })
		-- walls: white tile wainscot + red band in the dining room, all-tile in the kitchen
		for _, side in { { XW + 0.04, Enum.NormalId.Right }, { XE - 0.04, Enum.NormalId.Left } } do
			P("Wainscot", V(0.06, 4.2, dz0 - dz1), CFrame.new(side[1], FY + 2.1, (dz0 + dz1) / 2), C(240, 238, 232), M.CeramicTiles, { parent = g, deco = true })
			P("RedBand", V(0.07, 0.5, dz0 - dz1), CFrame.new(side[1], FY + 4.3, (dz0 + dz1) / 2), RED, M.SmoothPlastic, { parent = g, deco = true })
			P("UpperWall", V(0.05, CEIL - FY - 4.55, dz0 - dz1), CFrame.new(side[1], FY + 4.55 + (CEIL - FY - 4.55) / 2, (dz0 + dz1) / 2), CREAM, M.SmoothPlastic, { parent = g, deco = true })
			P("KitchenTile", V(0.06, 8, (ZC + 1) - ZB), CFrame.new(side[1], FY + 4, (ZC + 1 + ZB) / 2), C(236, 238, 236), M.CeramicTiles, { parent = g, deco = true })
		end
		P("BackTile", V(XE - XW, 8, 0.06), CFrame.new((XW + XE) / 2, FY + 4, ZB + 0.04), C(236, 238, 236), M.CeramicTiles, { parent = g, deco = true })
		-- ceiling lights: pendants over the booths, panels in the kitchen
		for _, x in { -1440, -1430.5, -1421 } do
			P("PendantCord", V(0.06, 4.0, 0.06), CFrame.new(x, CEIL - 2.0, -456.5), C(30, 30, 30), M.SmoothPlastic, { parent = g, deco = true })
			local shade = P("PendantShade", V(1.6, 0.9, 1.6), CFrame.new(x, CEIL - 4.4, -456.5), RED, M.Metal, { parent = g, deco = true })
			P("PendantBulb", V(0.7, 0.2, 0.7), CFrame.new(x, CEIL - 4.9, -456.5), C(255, 230, 180), M.Neon, { parent = g, deco = true })
			local l = Instance.new("PointLight")
			l.Range = 16
			l.Brightness = 0.9
			l.Color = C(255, 226, 180)
			l.Shadows = false
			l.Parent = shade
		end
		for _, pos in { V(-1446, 0, -463), V(-1430, 0, -464), V(-1418, 0, -463), V(-1444, 0, -481), V(-1430, 0, -481), V(-1418, 0, -486) } do
			P("Panel", V(2.2, 0.1, 4.2), CFrame.new(pos.X, CEIL - 0.1, pos.Z), C(246, 248, 255), M.Neon, { parent = g, deco = true })
		end
		for _, pos in { V(-1436, CEIL - 0.6, -462), V(-1436, CEIL - 0.6, -482), V(-1420, CEIL - 0.6, -482) } do
			local a = P("LightPoint", V(0.2, 0.2, 0.2), CFrame.new(pos), C(255, 255, 255), M.SmoothPlastic, { parent = g, deco = true, Transparency = 1 })
			local l = Instance.new("PointLight")
			l.Range = 24
			l.Brightness = 0.85
			l.Color = C(255, 246, 230)
			l.Shadows = false
			l.Parent = a
		end
		-- wall decor
		local posters = {
			{ V(XE - 0.08, 7.5, -462), Enum.NormalId.Left, "SMASH\nBURGER\n$5.99", RED, C(255, 230, 120), V(0.05, 3.0, 3.0) },
			{ V(XW + 0.08, 7.5, -462), Enum.NormalId.Right, "HOME OF THE\nSHACK STACK", C(30, 30, 30), C(255, 200, 60), V(0.05, 2.4, 4.0) },
			{ V(XW + 0.08, 7.0, -486), Enum.NormalId.Right, "EMPLOYEES MUST\nWASH HANDS", C(255, 255, 255), C(30, 80, 160), V(0.05, 1.4, 2.6) },
		}
		for _, d in posters do
			local p = P("Poster", d[6], CFrame.new(d[1].X, FY + d[1].Y, d[1].Z), d[4], M.SmoothPlastic, { parent = g, deco = true })
			K.sign(p, d[2], d[3], d[4], d[5])
		end
	end
	model.Parent = shop
	task.wait()

	---------------------------------------------------------------- dining: booths, 2-tops, soda fountain, trash
	local tableSpots = {}
	do
		local g = group("Dining", model)
		local function booth(x)
			local bg = group("Booth", g)
			local tz = -456.6
			P("TableTop", V(2.8, 0.2, 4.2), W(x, 2.6, tz), C(220, 214, 200), M.Marble, { parent = bg })
			P("TableEdge", V(2.9, 0.12, 4.3), W(x, 2.46, tz), C(160, 160, 164), M.Metal, { parent = bg, deco = true })
			P("TablePost", V(0.4, 2.5, 0.4), W(x, 1.25, tz), C(50, 50, 54), M.Metal, { parent = bg })
			P("TableFoot", V(1.6, 0.12, 1.6), W(x, 0.06, tz), C(50, 50, 54), M.Metal, { parent = bg })
			for s = -1, 1, 2 do
				local bx = x + s * 2.65
				P("Seat", V(1.9, 0.6, 4.6), W(bx, 1.5, tz - 0.2), RED, M.Fabric, { parent = bg })
				P("SeatBase", V(1.9, 1.2, 4.6), W(bx, 0.6, tz - 0.2), C(90, 30, 30), M.SmoothPlastic, { parent = bg })
				P("SeatBack", V(0.6, 3.0, 4.6), W(bx + s * 0.75, 3.2, tz - 0.2), RED, M.Fabric, { parent = bg })
				P("SeatTrim", V(0.65, 0.12, 4.6), W(bx + s * 0.75, 4.76, tz - 0.2), C(200, 200, 204), M.Metal, { parent = bg, deco = true })
			end
			-- condiments + napkins
			P("Ketchup", V(0.25, 0.6, 0.25), W(x - 0.5, 3.0, tz - 1.7), C(200, 20, 20), M.SmoothPlastic, { parent = bg, deco = true })
			P("Mustard", V(0.25, 0.6, 0.25), W(x - 0.15, 3.0, tz - 1.7), C(250, 210, 30), M.SmoothPlastic, { parent = bg, deco = true })
			P("Napkins", V(0.6, 0.5, 0.4), W(x + 0.4, 2.95, tz - 1.7), C(60, 60, 64), M.Metal, { parent = bg, deco = true })
			table.insert(tableSpots, V(x, FY + 2.5, tz))
		end
		booth(-1440)
		booth(-1430.5)
		booth(-1421)
		local function twoTop(x, z)
			local tg = group("TwoTop", g)
			P("TableTop", V(3.0, 0.2, 3.0), W(x, 2.6, z), C(220, 214, 200), M.Marble, { parent = tg })
			P("TablePost", V(0.35, 2.5, 0.35), W(x, 1.25, z), C(50, 50, 54), M.Metal, { parent = tg })
			for s = -1, 1, 2 do
				local cx = x + s * 2.2
				P("ChairSeat", V(1.4, 0.3, 1.4), W(cx, 1.6, z), RED, M.Fabric, { parent = tg })
				P("ChairBack", V(0.2, 1.8, 1.4), W(cx + s * 0.6, 2.6, z), RED, M.Fabric, { parent = tg })
				for _, dz in { -0.55, 0.55 } do
					P("ChairLeg", V(0.15, 1.45, 0.15), W(cx, 0.72, z + dz), C(160, 160, 164), M.Metal, { parent = tg, deco = true })
				end
			end
			P("Tray", V(1.4, 0.08, 1.0), W(x + 0.3, 2.74, z), RED, M.Plastic, { parent = tg, deco = true })
			P("Basket", V(0.8, 0.3, 0.6), W(x + 0.3, 2.93, z), C(250, 230, 160), M.SmoothPlastic, { parent = tg, deco = true })
		end
		twoTop(-1437, -463.5)
		twoTop(-1424.5, -463.5)
		-- soda fountain on the east wall
		local sf = group("SodaFountain", g)
		P("SodaCounter", V(2.2, 3.3, 7.0), W(XE - 1.1, 1.65, -462.5), C(60, 60, 64), M.Metal, { parent = sf })
		P("SodaTop", V(2.3, 0.12, 7.1), W(XE - 1.1, 3.36, -462.5), C(200, 200, 204), M.Metal, { parent = sf })
		P("Machine", V(1.6, 3.0, 4.6), W(XE - 0.9, 4.92, -463.2), C(30, 30, 34), M.SmoothPlastic, { parent = sf })
		for i = 0, 5 do
			local z = -465.1 + i * 0.75
			P("Valve", V(0.3, 0.6, 0.4), W(XE - 1.85, 4.6, z), K.Drinks[(i % #K.Drinks) + 1][1], M.SmoothPlastic, { parent = sf, deco = true })
		end
		local sfs = P("SodaSign", V(0.06, 1.0, 4.6), W(XE - 1.73, 6.0, -463.2), C(200, 30, 30), M.SmoothPlastic, { parent = sf, deco = true })
		K.sign(sfs, Enum.NormalId.Left, "FREE REFILLS", C(200, 30, 30), C(255, 255, 255), { lit = true })
		for i = 0, 2 do
			P("CupStack", V(0.5, 1.4, 0.5), W(XE - 1.4, 4.1, -459.6 + i * 0.6), C(250, 250, 246), M.SmoothPlastic, { parent = sf, deco = true })
		end
		-- trash + tray return by the door
		P("TrashCab", V(2.0, 3.6, 2.4), W(-1450.9, 1.8, -468.4), C(120, 70, 40), M.Wood, { parent = g })
		local tc = P("TrashTop", V(2.1, 0.15, 2.5), W(-1450.9, 3.67, -468.4), C(200, 200, 204), M.Metal, { parent = g })
		local flap = P("TrashFlap", V(0.05, 0.8, 1.4), W(-1449.88, 2.9, -468.4), C(30, 30, 30), M.Metal, { parent = g, deco = true })
		K.sign(flap, Enum.NormalId.Right, "THANK YOU", C(30, 30, 30), C(255, 255, 255))
		_ = tc
	end
	task.wait()

	---------------------------------------------------------------- order counter + pass + menu boards
	local passSpot
	do
		local g = group("Counter", model)
		local x0, x1 = -1446.2, XE
		local xc, L = (x0 + x1) / 2, x1 - x0
		P("CounterBody", V(L, 3.3, 2.0), W(xc, 1.65, ZC), RED, M.SmoothPlastic, { parent = g })
		P("CounterTile", V(L, 2.6, 0.06), W(xc, 1.55, ZC + 1.02), C(240, 238, 232), M.CeramicTiles, { parent = g, deco = true })
		P("CounterTop", V(L + 0.1, 0.15, 2.3), W(xc, 3.37, ZC), C(200, 200, 204), M.Metal, { parent = g })
		P("Kick", V(L, 0.3, 2.05), W(xc, 0.15, ZC), DARK, M.SmoothPlastic, { parent = g, deco = true })
		-- registers
		for _, x in { -1443.4, -1439.4 } do
			P("RegBase", V(1.2, 0.35, 1.0), W(x, 3.62, ZC + 0.3), DARK, M.SmoothPlastic, { parent = g, deco = true })
			local s = P("RegScreen", V(1.1, 0.8, 0.08), W(x, 4.3, ZC + 0.25) * CFrame.Angles(math.rad(-15), 0, 0), C(30, 30, 34), M.SmoothPlastic, { parent = g, deco = true })
			P("RegGlow", V(0.95, 0.65, 0.02), s.CFrame * CFrame.new(0, 0, 0.05), C(110, 200, 255), M.Neon, { parent = g, deco = true })
			P("TipJar", V(0.4, 0.5, 0.4), W(x + 0.9, 3.7, ZC + 0.6), C(220, 236, 240), M.Glass, { parent = g, deco = true, Transparency = 0.4 })
		end
		-- pass: heat-lamp shelf with a ticket rail
		local px = -1433
		P("PassShelf", V(5.0, 0.15, 1.6), W(px, 5.0, ZC), C(200, 200, 204), M.Metal, { parent = g })
		for _, dx in { -2.3, 2.3 } do
			P("PassPost", V(0.15, 1.6, 0.15), W(px + dx, 4.2, ZC), C(200, 200, 204), M.Metal, { parent = g, deco = true })
		end
		P("HeatLamp", V(4.8, 0.35, 0.9), W(px, 7.2, ZC), C(60, 60, 64), M.Metal, { parent = g, deco = true })
		P("LampGlow", V(4.4, 0.06, 0.6), W(px, 7.0, ZC), C(255, 120, 60), M.Neon, { parent = g, deco = true })
		for _, dx in { -2.2, 2.2 } do
			P("LampRod", V(0.08, 2.0, 0.08), W(px + dx, 6.1, ZC), C(60, 60, 64), M.Metal, { parent = g, deco = true })
		end
		local glow = Instance.new("SurfaceLight")
		glow.Face = Enum.NormalId.Bottom
		glow.Color = C(255, 150, 80)
		glow.Brightness = 1.5
		glow.Range = 6
		glow.Parent = g:FindFirstChild("HeatLamp")
		P("TicketRail", V(5.0, 0.12, 0.15), W(px, 6.4, ZC - 0.8), C(200, 200, 204), M.Metal, { parent = g, deco = true })
		for i = 0, 3 do
			P("Ticket", V(0.6, 0.9, 0.02), W(px - 1.8 + i * 1.2, 5.9, ZC - 0.85), C(250, 250, 246), M.SmoothPlastic, { parent = g, deco = true })
		end
		-- a finished order waiting under the lamp
		P("OrderTray", V(1.6, 0.08, 1.1), W(px - 1.2, 3.49, ZC), RED, M.Plastic, { parent = g, deco = true })
		P("Wrapper", V(0.8, 0.4, 0.8), W(px - 1.4, 3.73, ZC), C(250, 240, 210), M.SmoothPlastic, { parent = g, deco = true })
		P("Fries", V(0.45, 0.7, 0.35), W(px - 0.7, 3.88, ZC), RED, M.SmoothPlastic, { parent = g, deco = true })
		P("FriesTop", V(0.42, 0.25, 0.3), W(px - 0.7, 4.35, ZC), C(250, 200, 70), M.SmoothPlastic, { parent = g, deco = true })
		P("Cup", V(0.5, 0.9, 0.5), W(px + 1.3, 3.9, ZC), C(250, 250, 246), M.SmoothPlastic, { parent = g, deco = true })
		passSpot = V(px, FY + 2.5, ZC)
		-- menu boards hanging over the counter
		local boards = {
			{ -1442, "<b>BURGERS</b>\nShack Stack  $6.49\nCheeseburger  $4.99\nDouble Smash  $7.99" },
			{ -1432, "<b>COMBOS</b>\n#1 Shack Combo  $9.49\n#2 Wings Combo  $10.99\n#3 Fish Combo  $9.99" },
			{ -1422, "<b>SIDES & DRINKS</b>\nFries  $2.49\nOnion Rings  $3.29\nSoda  $1.99" },
		}
		for _, bd in boards do
			local p = P("MenuBoard", V(9.0, 3.4, 0.25), W(bd[1], 10.2, ZC - 0.6), C(40, 40, 44), M.SmoothPlastic, { parent = g, deco = true })
			K.sign(p, Enum.NormalId.Back, bd[2], C(34, 34, 38), C(255, 240, 200), { lit = true, font = Enum.Font.GothamBold, pad = 0.06, brightness = 2 })
			local ml = Instance.new("SurfaceLight") -- the boards read solid black in Play without their own light
			ml.Face = Enum.NormalId.Back
			ml.Range = 8
			ml.Brightness = 1.4
			ml.Angle = 100
			ml.Color = C(255, 236, 200)
			ml.Parent = p
			for _, dx in { -4, 4 } do
				P("MenuWire", V(0.05, CEIL - FY - 11.9, 0.05), CFrame.new(bd[1] + dx, (FY + 11.9 + CEIL) / 2, ZC - 0.6), C(30, 30, 30), M.Metal, { parent = g, deco = true })
			end
		end
		-- the kitchen gap: a swinging half door at the west end
		local hd = P("HalfDoor", V(0.15, 3.4, 2.4), W(-1446.4, 2.0, ZC + 1.0) * CFrame.Angles(0, math.rad(25), 0), C(120, 70, 40), M.Wood, { parent = g, deco = true })
		local hs = P("HalfDoorSign", V(0.03, 0.7, 2.0), hd.CFrame * CFrame.new(0.1, 0.8, 0), C(255, 255, 255), M.SmoothPlastic, { parent = g, deco = true })
		K.sign(hs, Enum.NormalId.Right, "EMPLOYEES ONLY", C(255, 255, 255), RED)
	end
	task.wait()

	---------------------------------------------------------------- kitchen
	local grillSpot, prepSpot, clockSpot
	do
		local g = group("Kitchen", model)
		local lz = ZB + 1.35 -- back line centre (depth 2.6)
		-- fryers
		for i = 0, 1 do
			local x = -1448.2 + i * 2.3
			P("FryerBody", V(2.1, 3.2, 2.6), W(x, 1.6, lz), STEEL, M.Metal, { parent = g })
			P("FryerOil", V(1.6, 0.1, 1.6), W(x, 3.17, lz + 0.2), C(170, 120, 30), M.SmoothPlastic, { parent = g, deco = true })
			P("Basket", V(1.2, 0.6, 1.0), W(x, 3.6, lz - 0.6), C(150, 150, 154), M.DiamondPlate, { parent = g, deco = true })
			P("BasketHandle", V(0.12, 0.12, 1.2), W(x, 3.8, lz - 1.6), C(30, 30, 30), M.SmoothPlastic, { parent = g, deco = true })
		end
		-- flat-top grill (the Grill station: Sizzle FX sits 3.2 above the floor, so the plate is no-query)
		local gx = -1439
		P("GrillBody", V(6.0, 2.85, 2.6), W(gx, 1.425, lz), STEEL, M.Metal, { parent = g, deco = true })
		K.blockers(b, g, W(gx, 0, lz), V(6.1, 3.3, 2.7))
		P("GrillPlate", V(5.8, 0.15, 2.4), W(gx, 2.92, lz), C(40, 40, 42), M.Metal, { parent = g, deco = true })
		P("GrillSplash", V(6.0, 1.0, 0.15), W(gx, 3.5, lz + 1.22), STEEL, M.Metal, { parent = g, deco = true })
		P("GrillTrough", V(5.8, 0.2, 0.3), W(gx, 2.9, lz - 1.3), C(120, 120, 124), M.Metal, { parent = g, deco = true })
		for i = 0, 3 do
			P("Knob", V(0.25, 0.25, 0.15), W(gx - 2.2 + i * 1.45, 2.3, lz - 1.35), C(20, 20, 20), M.SmoothPlastic, { parent = g, deco = true })
		end
		for i, dx in { -1.8, -0.4, 1.4 } do
			P("Patty", V(0.18, 1.1, 1.1), W(gx + dx, 3.07, lz - 0.2 + (i % 2) * 0.4) * CFrame.Angles(0, 0, math.rad(90)), C(110, 60, 40), M.SmoothPlastic, { parent = g, deco = true, shape = Enum.PartType.Cylinder })
		end
		P("Spatula", V(0.6, 0.05, 0.4), W(gx + 2.4, 3.03, lz - 0.6), C(200, 200, 204), M.Metal, { parent = g, deco = true })
		grillSpot = V(gx, FY + 2.5, lz)
		-- stove with pots
		P("Stove", V(4.0, 3.0, 2.6), W(-1433.5, 1.5, lz), STEEL, M.Metal, { parent = g })
		for i = 0, 3 do
			local bx, bz = -1434.5 + (i % 2) * 2.0, lz - 0.6 + math.floor(i / 2) * 1.2
			P("Burner", V(0.8, 0.06, 0.8), W(bx, 3.03, bz), C(30, 30, 30), M.Metal, { parent = g, deco = true })
		end
		P("Pot", V(1.0, 0.9, 1.0), W(-1434.5, 3.5, lz + 0.6), C(170, 172, 176), M.Metal, { parent = g, deco = true, shape = Enum.PartType.Cylinder, CFrame = W(-1434.5, 3.5, lz + 0.6) * CFrame.Angles(0, 0, math.rad(90)) })
		P("Pan", V(0.15, 1.1, 1.1), W(-1432.5, 3.1, lz - 0.6) * CFrame.Angles(0, 0, math.rad(90)), C(30, 30, 30), M.Metal, { parent = g, deco = true, shape = Enum.PartType.Cylinder })
		-- prep fridge (sandwich unit) with ingredient pans
		P("PrepFridge", V(7.0, 3.0, 2.6), W(-1426.5, 1.5, lz), STEEL, M.Metal, { parent = g })
		local pans = { C(80, 160, 60), C(210, 40, 40), C(245, 240, 220), C(250, 200, 50), C(60, 120, 50), C(150, 90, 60), C(240, 150, 40) }
		for i, col in pans do
			P("PrepPan", V(0.85, 0.12, 1.1), W(-1429.6 + (i - 1) * 0.95, 3.06, lz + 0.2), col, M.SmoothPlastic, { parent = g, deco = true })
		end
		P("FridgeDoorLine", V(0.05, 2.2, 0.05), W(-1426.5, 1.6, lz - 1.31), C(120, 120, 124), M.Metal, { parent = g, deco = true })
		-- hood over the whole line
		P("Hood", V(31, 2.2, 3.6), W(-1435.5, 9.6, ZB + 1.8), STEEL, M.Metal, { parent = g, CanQuery = false })
		P("HoodLip", V(31, 0.5, 0.2), W(-1435.5, 8.4, ZB + 3.55), C(150, 152, 156), M.Metal, { parent = g, deco = true })
		P("HoodDuct", V(3.0, CEIL - FY - 10.7, 2.0), W(-1435.5, 10.7 + (CEIL - FY - 10.7) / 2, ZB + 1.2), STEEL, M.Metal, { parent = g })
		for _, x in { -1446, -1436, -1426 } do
			local hl = P("HoodLight", V(1.4, 0.06, 0.8), W(x, 8.47, ZB + 2.6), C(255, 240, 210), M.Neon, { parent = g, deco = true })
			local sl = Instance.new("SpotLight") -- the kitchen read dark in Play
			sl.Face = Enum.NormalId.Bottom
			sl.Range = 14
			sl.Angle = 110
			sl.Brightness = 1.6
			sl.Color = C(255, 240, 215)
			sl.Parent = hl
		end
		for _, pos in { V(-1444, 13.0, -481), V(-1428, 13.0, -481), V(-1418, 13.0, -488) } do
			local a = P("KitchenLight", V(0.2, 0.2, 0.2), W(pos.X, pos.Y, pos.Z), C(255, 255, 255), M.SmoothPlastic, { parent = g, deco = true, Transparency = 1 })
			local l = Instance.new("PointLight")
			l.Range = 24
			l.Brightness = 1.3
			l.Color = C(255, 248, 236)
			l.Shadows = false
			l.Parent = a
		end
		P("Shelf", V(31, 0.12, 1.2), W(-1435.5, 6.4, ZB + 0.6), STEEL, M.Metal, { parent = g, deco = true })
		for i = 0, 9 do
			local col = ({ C(200, 30, 30), C(250, 200, 40), C(240, 240, 236), C(120, 70, 40) })[(i % 4) + 1]
			P("Bottle", V(0.4, 1.0, 0.4), W(-1449 + i * 3.1, 7.0, ZB + 0.6), col, M.SmoothPlastic, { parent = g, deco = true })
		end
		-- prep island
		local ix, iz = -1436, -481.5
		P("IslandTop", V(9.0, 0.15, 3.0), W(ix, 3.1, iz), STEEL, M.Metal, { parent = g })
		P("IslandShelf", V(8.6, 0.1, 2.6), W(ix, 0.8, iz), STEEL, M.Metal, { parent = g, deco = true })
		for _, dx in { -4.3, 4.3 } do
			for _, dz in { -1.3, 1.3 } do
				P("IslandLeg", V(0.18, 3.0, 0.18), W(ix + dx, 1.5, iz + dz), STEEL, M.Metal, { parent = g })
			end
		end
		P("Board", V(2.4, 0.12, 1.6), W(ix - 1.5, 3.24, iz), C(240, 240, 236), M.SmoothPlastic, { parent = g, deco = true })
		for i = 0, 3 do
			P("Bun", V(0.9, 0.4, 0.9), W(ix + 1.6 + (i % 2) * 1.0, 3.4 + math.floor(i / 2) * 0.42, iz - 0.5), C(214, 150, 70), M.SmoothPlastic, { parent = g, deco = true })
		end
		P("BunTray", V(2.4, 0.1, 1.6), W(ix + 2.1, 3.2, iz - 0.3), C(150, 150, 154), M.Metal, { parent = g, deco = true })
		P("SauceRed", V(0.3, 0.8, 0.3), W(ix - 3.5, 3.6, iz + 0.8), C(200, 20, 20), M.SmoothPlastic, { parent = g, deco = true })
		P("SauceYellow", V(0.3, 0.8, 0.3), W(ix - 3.1, 3.6, iz + 0.8), C(250, 210, 30), M.SmoothPlastic, { parent = g, deco = true })
		P("WrapperStack", V(1.0, 0.3, 1.0), W(ix + 3.4, 3.33, iz + 0.6), C(250, 240, 210), M.SmoothPlastic, { parent = g, deco = true })
		for i = 0, 2 do
			P("Box", V(1.6, 1.0, 1.4), W(ix - 2.5 + i * 2.2, 1.4, iz), C(176, 132, 84), M.Cardboard, { parent = g, deco = true })
		end
		prepSpot = V(ix, FY + 2.5, iz + 2.3) -- in the aisle beside the island (the top would catch the beacon ray)
		-- staff corner (west wall, by the kitchen gap): time clock, schedule, lockers
		local tc = group("TimeClock", g)
		P("ClockBody", V(0.6, 1.6, 1.2), W(XW + 0.3, 4.6, -477.5), C(214, 210, 196), M.SmoothPlastic, { parent = tc })
		P("ClockDigits", V(0.04, 0.22, 0.6), W(XW + 0.62, 5.0, -477.5), C(255, 80, 60), M.Neon, { parent = tc, deco = true })
		P("CardSlot", V(0.05, 0.1, 0.5), W(XW + 0.62, 4.3, -477.5), C(20, 20, 20), M.SmoothPlastic, { parent = tc, deco = true })
		P("CardRack", V(0.3, 2.2, 1.2), W(XW + 0.2, 4.6, -479.0), C(150, 150, 154), M.Metal, { parent = tc })
		for i = 0, 5 do
			P("TimeCard", V(0.05, 0.9, 0.18), W(XW + 0.38, 4.9, -479.45 + i * 0.18), C(240, 236, 210), M.SmoothPlastic, { parent = tc, deco = true })
		end
		local sch = P("Schedule", V(0.05, 1.6, 1.4), W(XW + 0.1, 5.2, -480.8), C(255, 255, 255), M.SmoothPlastic, { parent = g, deco = true })
		K.grid(sch, Enum.NormalId.Right, 3, 6, C(250, 250, 246), C(120, 120, 120), false)
		clockSpot = V(XW + 2.0, FY + 2.5, -477.5)
		for i = 0, 2 do
			P("Locker", V(1.4, 6.0, 1.4), W(XW + 0.75, 3, -484.0 - i * 1.5), C(160, 40, 40), M.Metal, { parent = g })
			P("LockerVent", V(0.05, 0.5, 0.8), W(XW + 1.47, 5.2, -484.0 - i * 1.5), C(90, 20, 20), M.SmoothPlastic, { parent = g, deco = true })
		end
		-- east side: dry storage rack, dish sink, mop bucket
		local rx = XE - 1.1
		for _, y in { 0.4, 2.4, 4.4, 6.4 } do
			P("RackShelf", V(2.0, 0.08, 7.0), W(rx, y, -478.5), C(170, 172, 176), M.DiamondPlate, { parent = g, deco = true })
			if y < 6 then
				local z = -481.8
				while z < -475.6 do
					local w = rng:NextNumber(0.9, 1.6)
					local kind = rng:NextNumber()
					local col = if kind < 0.5 then C(176, 132, 84) elseif kind < 0.75 then C(240, 240, 236) else C(200, 40, 40)
					local h = rng:NextNumber(0.8, 1.6)
					P("Stock", V(1.6, h, w), W(rx, y + 0.04 + h / 2, z + w / 2), col, if kind < 0.5 then M.Cardboard else M.SmoothPlastic, { parent = g, deco = true })
					z += w + 0.15
				end
			end
		end
		for _, dz in { -3.4, 3.4 } do
			for _, dx in { -0.9, 0.9 } do
				P("RackPost", V(0.12, 7.0, 0.12), W(rx + dx, 3.5, -478.5 + dz), C(140, 142, 146), M.Metal, { parent = g })
			end
		end
		P("Sink", V(2.4, 3.1, 6.0), W(XE - 1.2, 1.55, -486.5), STEEL, M.Metal, { parent = g })
		for i = 0, 2 do
			P("Basin", V(1.8, 0.1, 1.7), W(XE - 1.2, 3.12, -488.5 + i * 2.0), C(110, 112, 116), M.Metal, { parent = g, deco = true })
		end
		P("Faucet", V(0.2, 1.4, 0.2), W(XE - 0.35, 3.8, -486.5), C(200, 200, 204), M.Metal, { parent = g, deco = true })
		P("DishRack", V(1.6, 0.8, 1.6), W(XE - 1.2, 3.55, -484.4), C(150, 150, 154), M.DiamondPlate, { parent = g, deco = true })
		P("MopBucket", V(1.2, 1.0, 1.0), W(-1418.5, 0.5, -490.4), C(250, 200, 30), M.Plastic, { parent = g })
		P("MopHandle", V(0.12, 5.0, 0.12), W(-1418.5, 2.6, -490.4) * CFrame.Angles(math.rad(-12), 0, 0), C(200, 180, 140), M.Wood, { parent = g, deco = true })
		P("Extinguisher", V(0.5, 1.4, 0.5), W(XE - 0.3, 2.6, -474.5), C(200, 20, 20), M.SmoothPlastic, { parent = g, deco = true })
		P("Mat", V(8, 0.05, 2.2), W(-1438, 0.03, ZB + 3.8), C(30, 30, 30), M.Rubber, { parent = g, deco = true })
	end
	task.wait()

	---------------------------------------------------------------- stations
	K.dress(model, {
		FloorDining = { "MTL_DinerCheck", true }, FloorKitchen = "MTL_KitchenTile",
		Wainscot = "MTL_WallTile", KitchenTile = "MTL_WallTile", BackTile = "MTL_WallTile", CounterTile = "MTL_WallTile",
		UpperWall = "MTL_Drywall", TrashCab = "MTL_CounterWood",
	})
	for _, p in shop:GetChildren() do -- the unit's own ceiling slab
		if p:IsA("BasePart") and p.Size.Y < 0.2 and math.abs(p.Position.Y - 15.9) < 0.1 and p.Position.X > XW - 1 and p.Position.X < XE + 1 then
			K.dressPart(p, "MTL_CeilingTile")
		end
	end
	K.quietFootprints(V(-1442, 0, -460), 40)
	local stations = workspace:FindFirstChild("MTL_Stations")
	local spots = {
		TimeClock = { clockSpot },
		Grill = { grillSpot },
		Prep = { prepSpot },
		Pass = { passSpot },
		Table1 = { tableSpots[1] },
		Table2 = { tableSpots[2] },
		Table3 = { tableSpots[3] },
		Floor1 = { V(-1445.5, FY + 2.5, -462.0), true },
		Floor2 = { V(-1431.0, FY + 2.5, -468.0), true },
	}
	local report = {}
	local f = stations and stations:FindFirstChild("Restaurant")
	for id, s in spots do
		local p = f and f:FindFirstChild(id)
		if p and p:IsA("BasePart") then
			if p:GetAttribute("MTL_OldPos") == nil then
				p:SetAttribute("MTL_OldPos", p.Position)
			end
			p.CFrame = CFrame.new(s[1])
			if not s[2] then
				p:SetAttribute("Prop", "")
			end
			table.insert(report, id)
		end
	end
	return string.format("BurgerShackV2: %d parts, %d old parts stashed, stations moved: %s", b.n, moved, table.concat(report, ", "))
end
