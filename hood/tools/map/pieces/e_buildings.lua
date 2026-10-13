---------------------------------------------------------------------------------------------- buildings
-- The reference street's buildings (ref1_street.png, measured with a matched camera): studded red brick, two
-- storeys of ~15 studs, a slate-blue band between them, big grey-framed windows of four blue panes, a slate eave
-- and a low hip roof. Building frame: origin at the facade's left end on the ground, +X along the facade, +Z out
-- of it; the building runs back to z = -depth. One builder serves both sides of the street.
local function lotFrame(ctx, s, za, w)
	if s < 0 then return ctx:at(CFrame.lookAt(V(-FRONT, 0, za), V(-FRONT - 1, 0, za))) end
	return ctx:at(CFrame.lookAt(V(FRONT, 0, za - w), V(FRONT + 1, 0, za - w)))
end

-- Window: a studded grey stone frame standing proud of the wall, a lighter stone sill under it and a lintel over it
-- (each a step further out, so the frame reads in three shades and casts a shadow line), and, set back inside, four
-- studded panes (the two on the left a darker blue, like the reference's reflections) split by navy bars.
-- x = centre, y = frame bottom.
local function window(c, x, y, o)
	o = o or {}
	local w, h, t = o.w or 15, o.h or P.street.winH, 1.3
	local x0, x1, y1 = x - w / 2, x + w / 2, y + h
	local trim = P.st.trim
	-- (the frame stands 1 stud proud, so the glass sits in a 0.9-deep recess with a shadowed reveal)
	sbox(c, 'WindowFrame', V(x0, y, -0.2), V(x0 + t, y1, 1.0), trim, true)
	sbox(c, 'WindowFrame', V(x1 - t, y, -0.2), V(x1, y1, 1.0), trim, true)
	sbox(c, 'WindowFrame', V(x0 + t, y, -0.2), V(x1 - t, y + t, 1.0), trim, true)
	sbox(c, 'WindowFrame', V(x0 + t, y1 - t, -0.2), V(x1 - t, y1, 1.0), trim, true)
	sbox(c, 'WindowSill', V(x0 - 0.6, y - 0.8, -0.2), V(x1 + 0.6, y, 1.6), P.st.sill, true)
	sbox(c, 'WindowLintel', V(x0 - 0.3, y1, -0.2), V(x1 + 0.3, y1 + 0.9, 1.3), P.st.trimDark, true)
	-- the reveal: a darker strip inside the top and left of the frame, where the frame shades the glass (big windows
	-- only: on small ones it isn't seen and the parts add up on tall buildings)
	if w >= 8 then
		local rev = P.st.trimDark:Lerp(P.black, 0.3)
		sbox(c, 'WindowReveal', V(x0 + t, y1 - t - 0.45, -0.2), V(x1 - t, y1 - t, 0.5), rev, true)
		sbox(c, 'WindowReveal', V(x0 + t, y + t, -0.2), V(x0 + t + 0.45, y1 - t - 0.45, 0.5), rev, true)
	end
	local n = o.panes or (w >= 9 and 4 or 2)
	local bar = 0.7
	local g0, g1 = x0 + t, x1 - t
	local pw = (g1 - g0 - (n - 1) * bar) / n
	-- the glass: one darker pane across the opening, the right half lighter, navy bars in front
	sbox(c, 'Glass', V(g0, y + t, -0.2), V(g1, y1 - t, 0.1), P.st.glassA, true)
	sbox(c, 'Glass', V((g0 + g1) / 2, y + t, -0.2), V(g1, y1 - t, 0.12), P.st.glassB, true)
	for k = 1, n - 1 do
		local a = g0 + k * pw + (k - 1) * bar
		sbox(c, 'WindowBar', V(a, y + t, -0.2), V(a + bar, y1 - t, 0.25), P.st.mullion, true)
	end
end

-- Hip roof (45 degrees by default) in studded slate over the rectangle x0..x1, z0..z1 standing at y: a darker eave
-- slab overhanging the walls by one stud, wedge slopes on all four sides with corner wedges, and a flat top with a
-- darker rim round a lighter panel.
local function hipRoof(c, x0, z0, x1, z1, y, rise, run)
	rise, run = rise or 5, run or 5
	local col, dark = P.st.roof, P.st.roofDark
	sbox(c, 'RoofEave', V(x0 - 1, y, z0 - 1), V(x1 + 1, y + 1, z1 + 1), dark)
	y += 1
	local my = y + rise / 2
	local lx, lz = x1 - x0 - 2 * run, z1 - z0 - 2 * run
	local mx, mz = (x0 + x1) / 2, (z0 + z1) / 2
	-- (a wedge's slope rises toward its local +Z)
	c:wedge('RoofSlope', V(lx, rise, run), CFrame.new(mx, my, z1 - run / 2) * CFrame.Angles(0, math.pi, 0), col, M.Plastic)
	c:wedge('RoofSlope', V(lx, rise, run), CFrame.new(mx, my, z0 + run / 2), col, M.Plastic)
	c:wedge('RoofSlope', V(lz, rise, run), CFrame.new(x0 + run / 2, my, mz) * CFrame.Angles(0, math.pi / 2, 0), col, M.Plastic)
	c:wedge('RoofSlope', V(lz, rise, run), CFrame.new(x1 - run / 2, my, mz) * CFrame.Angles(0, -math.pi / 2, 0), col, M.Plastic)
	-- corners: a corner wedge's peak stands over its local (+X, -Z) corner; turn it toward the roof's middle
	for _, k in { { x0, z1, 0 }, { x1, z1, 90 }, { x1, z0, 180 }, { x0, z0, -90 } } do
		local cx = k[1] + (k[1] == x0 and run / 2 or -run / 2)
		local cz = k[2] + (k[2] == z0 and run / 2 or -run / 2)
		local p = Instance.new('CornerWedgePart')
		p.Name = 'RoofCorner'
		p.Anchored = true
		p.Size = V(run, rise, run)
		p.CFrame = c:world(CFrame.new(cx, my, cz) * CFrame.Angles(0, math.rad(k[3]), 0))
		p.Color, p.Material = col, M.Plastic
		smooth(p)
		p.Parent = c.parent
	end
	sbox(c, 'RoofTop', V(x0 + run, y, z0 + run), V(x1 - run, y + rise + 0.3, z1 - run), dark)
	if lx > 2 and lz > 2 then sbox(c, 'RoofPanel', V(x0 + run + 1, y + rise + 0.3, z0 + run + 1), V(x1 - run - 1, y + rise + 0.5, z1 - run - 1), col, true) end
end

-- A face of a w x depth block as a facade frame (+Z out of it, +X along it as seen from outside), and its width.
local function faceFrame(c, face, w, depth)
	if face == 'left' then return c:at(CFrame.new(0, 0, -depth) * CFrame.Angles(0, -math.pi / 2, 0)), depth end
	if face == 'right' then return c:at(CFrame.new(w, 0, 0) * CFrame.Angles(0, math.pi / 2, 0)), depth end
	if face == 'back' then return c:at(CFrame.new(w, 0, -depth) * CFrame.Angles(0, math.pi, 0)), w end
	return c, w
end

-- Gable roof, studded slate: the darker eave slab, two slopes up to a ridge cap, and brick gable triangles. along =
-- 'x': the ridge runs along the facade (eaves front and back); along = 'z': the ridge runs back from the street and
-- the gable (with a stone-trimmed pediment and a round vent) faces it.
local function gableRoof(c, w, d, H, rise, along, wall)
	local col, dark = P.st.roof, P.st.roofDark
	sbox(c, 'RoofEave', V(-1, H, -d - 1), V(w + 1, H + 1, 1), dark)
	local y = H + 1
	local function W(name, size, cf, color) studs(c:wedge(name, size, cf, color, M.Plastic), true) end
	if along == 'z' then
		-- slopes rising from the side eaves to a ridge over the middle; the gables front and back
		W('RoofSlope', V(d + 2, rise, w / 2 + 1), CFrame.new(w / 4 - 0.5, y + rise / 2, -d / 2) * CFrame.Angles(0, math.pi / 2, 0), col)
		W('RoofSlope', V(d + 2, rise, w / 2 + 1), CFrame.new(w * 3 / 4 + 0.5, y + rise / 2, -d / 2) * CFrame.Angles(0, -math.pi / 2, 0), col)
		for _, zf in { -0.5, -d + 0.5 } do
			W('Gable', V(1, rise, w / 2), CFrame.new(w / 4, y + rise / 2, zf) * CFrame.Angles(0, math.pi / 2, 0), wall)
			W('Gable', V(1, rise, w / 2), CFrame.new(w * 3 / 4, y + rise / 2, zf) * CFrame.Angles(0, -math.pi / 2, 0), wall)
		end
		sbox(c, 'RidgeCap', V(w / 2 - 0.6, y + rise - 0.3, -d - 1), V(w / 2 + 0.6, y + rise + 0.4, 1), dark, true)
		decor(c:part('GableVent', V(0.3, 2.2, 2.2), CFrame.new(w / 2, y + rise * 0.4, 0.1) * CFrame.Angles(0, math.pi / 2, 0), P.st.trim, M.Plastic, Enum.PartType.Cylinder))
		decor(c:part('GableVentHole', V(0.32, 1.4, 1.4), CFrame.new(w / 2, y + rise * 0.4, 0.12) * CFrame.Angles(0, math.pi / 2, 0), P.st.gutter, M.Plastic, Enum.PartType.Cylinder))
	else
		W('RoofSlope', V(w + 2, rise, d / 2 + 1), CFrame.new(w / 2, y + rise / 2, 0.5 - d / 4) * CFrame.Angles(0, math.pi, 0), col)
		W('RoofSlope', V(w + 2, rise, d / 2 + 1), CFrame.new(w / 2, y + rise / 2, -d * 3 / 4 - 0.5), col)
		for _, xf in { 0.5, w - 0.5 } do
			W('Gable', V(1, rise, d / 2), CFrame.new(xf, y + rise / 2, -d * 3 / 4), wall)
			W('Gable', V(1, rise, d / 2), CFrame.new(xf, y + rise / 2, -d / 4) * CFrame.Angles(0, math.pi, 0), wall)
		end
		sbox(c, 'RidgeCap', V(-1, y + rise - 0.3, -d / 2 - 0.6), V(w + 1, y + rise + 0.4, -d / 2 + 0.6), dark, true)
	end
end

-- Flat roof behind a brick parapet with a stone coping, a dark deck and rooftop clutter (air-con boxes, a vent).
local function flatRoof(c, w, d, H, wall)
	sbox(c, 'RoofDeck', V(0, H, -d), V(w, H + 0.4, 0), P.st.roofDark)
	for _, e in { { V(-0.3, H, -0.9), V(w + 0.3, H + 2.2, 0.3) }, { V(-0.3, H, -d - 0.3), V(w + 0.3, H + 2.2, -d + 0.9) },
		{ V(-0.3, H, -d), V(0.9, H + 2.2, 0) }, { V(w - 0.9, H, -d), V(w + 0.3, H + 2.2, 0) } } do
		sbox(c, 'Parapet', e[1], e[2], wall)
		sbox(c, 'Coping', V(e[1].X - 0.3, H + 2.2, e[1].Z - 0.3), V(e[2].X + 0.3, H + 2.8, e[2].Z + 0.3), P.st.trim, true)
	end
	for k, x in { w * 0.3, w * 0.62 } do
		sbox(c, 'RoofAirCon', V(x - 1.8, H + 0.4, -d * 0.55 - 1.5), V(x + 1.8, H + 2.6, -d * 0.55 + 1.5), C(206, 210, 216), true)
		decor(c:box('RoofAirConFan', V(x - 1.2, H + 2.6, -d * 0.55 - 1), V(x + 1.2, H + 2.75, -d * 0.55 + 1), C(110, 116, 126), M.Plastic))
		if k == 2 then decor(c:post('RoofVent', 0.5, 3.4, V(x + 4, H + 0.4, -d * 0.4), P.st.gutter, M.Plastic)) end
	end
end

-- Brick chimney stack on the roof: a stone cap and two pots.
local function chimney(c, x, z, y0, y1, wall)
	sbox(c, 'Chimney', V(x - 1.5, y0, z - 1.3), V(x + 1.5, y1, z + 1.3), wall)
	sbox(c, 'ChimneyCap', V(x - 1.8, y1, z - 1.6), V(x + 1.8, y1 + 0.6, z + 1.6), P.st.trim, true)
	for _, dx in { -0.7, 0.7 } do decor(c:post('ChimneyPot', 0.42, 1.0, V(x + dx, y1 + 0.6, z), P.st.trunk, M.Plastic)) end
end

-- An entrance in a facade frame at x: a stone surround standing proud of the wall, the door set back in it with a
-- glazed transom over it, a brass knob, a house number and a wall lamp. kind: 'stoop' (three steps up to a landing
-- between brick cheek walls with stone caps, a slate canopy on brackets), 'porch' (a deck across span = { x0, x1 }
-- with two steps, posts with bases and caps, a rail and a roof with a fascia) or 'door' (two steps and a canopy).
local function entrance(c, x, o)
	local kind, dw, number = o.kind or 'door', 3.8, o.number or '12'
	local rise = kind == 'stoop' and 1.8 or (kind == 'porch' and 1.0 or 0.9)
	local y0 = 0.6 + rise -- (the grass is at 0.6)
	local trim, dark = P.st.trim, P.st.trimDark
	-- surround, door, transom, knob, number, lamp
	sbox(c, 'DoorSurround', V(x - dw / 2 - 1.2, y0 - 0.2, -0.2), V(x - dw / 2, y0 + 9.6, 0.8), trim, true)
	sbox(c, 'DoorSurround', V(x + dw / 2, y0 - 0.2, -0.2), V(x + dw / 2 + 1.2, y0 + 9.6, 0.8), trim, true)
	sbox(c, 'DoorHead', V(x - dw / 2 - 1.5, y0 + 9.6, -0.2), V(x + dw / 2 + 1.5, y0 + 10.6, 1.0), dark, true)
	sbox(c, 'Door', V(x - dw / 2, y0, -0.2), V(x + dw / 2, y0 + 7.8, 0.15), o.door or C(40, 110, 76))
	sbox(c, 'DoorPanel', V(x - dw / 2 + 0.5, y0 + 4.4, 0.15), V(x + dw / 2 - 0.5, y0 + 7.2, 0.3), (o.door or C(40, 110, 76)):Lerp(P.black, 0.18), true)
	sbox(c, 'DoorPanel', V(x - dw / 2 + 0.5, y0 + 0.6, 0.15), V(x + dw / 2 - 0.5, y0 + 3.8, 0.3), (o.door or C(40, 110, 76)):Lerp(P.black, 0.18), true)
	sbox(c, 'Transom', V(x - dw / 2, y0 + 7.8, -0.2), V(x + dw / 2, y0 + 9.6, 0.1), P.st.glassB, true)
	decor(c:box('DoorKnob', V(x + dw / 2 - 0.8, y0 + 3.9, 0.15), V(x + dw / 2 - 0.4, y0 + 4.3, 0.55), C(232, 188, 70), M.Plastic))
	local plate = sbox(c, 'HouseNumber', V(x + dw / 2 + 1.4, y0 + 6.2, -0.2), V(x + dw / 2 + 2.8, y0 + 7.4, 0.25), P.white, true)
	line(surface(plate, Enum.NormalId.Back, 30), 'Number', number, C(30, 40, 70), FONT.title, 0.05, 0.9)
	local lampBox = sbox(c, 'WallLamp', V(x - dw / 2 - 2.6, y0 + 6.4, 0), V(x - dw / 2 - 1.5, y0 + 8.0, 1.0), P.st.lamp, true)
	decor(c:box('WallLampGlow', V(x - dw / 2 - 2.45, y0 + 6.6, 1.0), V(x - dw / 2 - 1.65, y0 + 7.8, 1.1), P.st.lampGlow, M.Neon)).CastShadow = false
	light(lampBox, P.st.lampGlow, 0.6, 10)
	if kind == 'porch' then
		local x0, x1 = o.span[1], o.span[2]
		local dp = 3.6
		sbox(c, 'PorchDeck', V(x0, -1, 0), V(x1, y0, dp), C(176, 150, 120))
		sbox(c, 'PorchDeckEdge', V(x0 - 0.2, y0 - 0.5, dp - 0.4), V(x1 + 0.2, y0 + 0.1, dp + 0.2), C(150, 124, 96), true)
		for k = 1, 2 do sbox(c, 'PorchStep', V(x - 2.6, -1, dp + (k - 1) * 0.9), V(x + 2.6, y0 - k * 0.5, dp + k * 0.9), P.st.sill) end
		for _, px in { x0 + 0.5, x - 3.4, x + 3.4, x1 - 0.5 } do
			sbox(c, 'PorchPostBase', V(px - 0.7, y0, dp - 1.2), V(px + 0.7, y0 + 0.8, dp - 0.1), dark, true)
			sbox(c, 'PorchPost', V(px - 0.45, y0 + 0.8, dp - 0.95), V(px + 0.45, y0 + 8.6, dp - 0.35), P.white, true)
			sbox(c, 'PorchPostCap', V(px - 0.7, y0 + 8.6, dp - 1.2), V(px + 0.7, y0 + 9.1, dp - 0.1), dark, true)
		end
		for _, seg in { { x0 + 0.5, x - 3.4 }, { x + 3.4, x1 - 0.5 } } do
			sbox(c, 'PorchRail', V(seg[1], y0 + 2.6, dp - 0.8), V(seg[2], y0 + 3.0, dp - 0.5), P.white, true)
			for bx = seg[1] + 1, seg[2] - 0.5, 1.2 do decor(c:box('PorchBaluster', V(bx - 0.15, y0, dp - 0.75), V(bx + 0.15, y0 + 2.6, dp - 0.55), P.white, M.Plastic)) end
		end
		sbox(c, 'PorchRoof', V(x0 - 0.4, y0 + 9.1, -0.2), V(x1 + 0.4, y0 + 9.7, dp + 0.5), P.st.roofDark, true)
		sbox(c, 'PorchFascia', V(x0 - 0.5, y0 + 8.9, dp + 0.2), V(x1 + 0.5, y0 + 9.8, dp + 0.7), trim, true)
	else
		local steps = kind == 'stoop' and 3 or 2
		local land = kind == 'stoop' and 1.6 or 1.0
		local sw = dw + 2.4
		sbox(c, 'StoopLanding', V(x - sw / 2, -1, 0), V(x + sw / 2, y0, land), P.st.sill)
		for k = 1, steps do sbox(c, 'StoopStep', V(x - sw / 2, -1, land + (k - 1) * 0.9), V(x + sw / 2, y0 - k * rise / steps, land + k * 0.9), P.st.sill:Lerp(P.black, (k % 2) * 0.05)) end
		if kind == 'stoop' then
			local dz = land + steps * 0.9
			for _, sx in { -1, 1 } do
				local cx = x + sx * (sw / 2 + 0.5)
				sbox(c, 'CheekWall', V(cx - 0.5, -1, 0), V(cx + 0.5, y0 + 0.9, dz), P.st.brickDark)
				sbox(c, 'CheekCap', V(cx - 0.65, y0 + 0.9, 0), V(cx + 0.65, y0 + 1.3, dz + 0.15), trim, true)
				sbox(c, 'StoopRail', V(cx - 0.12, y0 + 1.3, 0.3), V(cx + 0.12, y0 + 3.3, 0.6), P.iron, true)
				sbox(c, 'StoopRail', V(cx - 0.12, y0 + 3.0, 0.3), V(cx + 0.12, y0 + 3.3, dz - 0.3), P.iron, true)
				sbox(c, 'StoopRail', V(cx - 0.12, y0 + 1.3, dz - 0.6), V(cx + 0.12, y0 + 3.3, dz - 0.3), P.iron, true)
			end
		end
		sbox(c, 'Canopy', V(x - dw / 2 - 1.8, y0 + 10.8, -0.2), V(x + dw / 2 + 1.8, y0 + 11.3, 2.6), P.st.roofDark, true)
		sbox(c, 'CanopyFascia', V(x - dw / 2 - 1.9, y0 + 10.6, 2.4), V(x + dw / 2 + 1.9, y0 + 11.4, 2.8), trim, true)
		for _, sx in { -1, 1 } do decor(c:bar('CanopyBracket', V(x + sx * (dw / 2 + 1.2), y0 + 9.2, 0.2), V(x + sx * (dw / 2 + 1.2), y0 + 10.8, 2.2), 0.3, P.iron, M.Plastic)) end
	end
end

-- Shopfront on a facade frame (+Z out of the wall) between x0 and x1, the ground floor of a shop with flats above:
-- a stone stall riser, display glass in two tones split by dark mullions, a glazed door (sh.door = its centre, default
-- near x1), dark pilasters either side, a fascia board in the shop's colour carrying its name (sh.sign), and a striped
-- fabric awning (sh.stripes) sloping out over the pavement with a valance.
local function shopfront(c, sh)
	local x0, x1 = sh.x0, sh.x1
	local col = sh.color or C(40, 110, 76)
	local dark = col:Lerp(P.black, 0.35)
	local dx = sh.door or (x1 - 3)
	sbox(c, 'ShopPilaster', V(x0 - 0.8, 0.6, -0.2), V(x0, 10, 0.9), dark)
	sbox(c, 'ShopPilaster', V(x1, 0.6, -0.2), V(x1 + 0.8, 10, 0.9), dark)
	sbox(c, 'StallRiser', V(x0, 0.6, -0.2), V(x1, 2.4, 0.7), P.st.trim)
	sbox(c, 'StallSill', V(x0 - 0.2, 2.4, -0.2), V(x1 + 0.2, 2.8, 1.0), P.st.sill, true)
	-- the glass, the door's opening left out
	local spans = { { x0, dx - 2.2 }, { dx + 2.2, x1 } }
	for _, sp in spans do
		if sp[2] - sp[1] > 1 then
			sbox(c, 'ShopGlass', V(sp[1], 2.8, -0.2), V(sp[2], 9.2, 0.1), P.st.glassA, true)
			sbox(c, 'ShopGlass', V((sp[1] + sp[2]) / 2, 2.8, -0.2), V(sp[2], 9.2, 0.12), P.st.glassB, true)
			local n = math.max(1, math.floor((sp[2] - sp[1]) / 4.5 + 0.5))
			for k = 1, n - 1 do
				local mx = sp[1] + (sp[2] - sp[1]) * k / n
				sbox(c, 'ShopMullion', V(mx - 0.3, 2.8, -0.2), V(mx + 0.3, 9.2, 0.5), dark, true)
			end
			sbox(c, 'ShopTransom', V(sp[1], 9.2, -0.2), V(sp[2], 10, 0.6), dark, true)
		end
	end
	-- the door: frame, glass, push bar, a step
	sbox(c, 'ShopDoorFrame', V(dx - 2.2, 0.6, -0.2), V(dx + 2.2, 10, 0.6), dark)
	sbox(c, 'ShopDoor', V(dx - 1.6, 0.6, -0.2), V(dx + 1.6, 8.6, 0.75), P.st.glassB, true)
	sbox(c, 'ShopDoorBar', V(dx - 1.2, 4.2, 0.75), V(dx + 1.2, 4.6, 1.05), C(214, 216, 222), true)
	sbox(c, 'ShopStep', V(dx - 2.4, -0.5, 0), V(dx + 2.4, 0.9, 1.6), P.st.sill)
	-- fascia board with the shop's name
	local board = sbox(c, 'Fascia', V(x0 - 0.8, 10, -0.2), V(x1 + 0.8, 12.8, 1.1), col)
	sbox(c, 'FasciaCap', V(x0 - 1.0, 12.8, -0.2), V(x1 + 1.0, 13.3, 1.4), dark, true)
	if sh.sign then
		local g = surface(board, Enum.NormalId.Back, 20)
		line(g, 'Name', sh.sign, sh.text or P.white, FONT.loud, 0.12, 0.76, col:Lerp(P.black, 0.6), 3)
	end
	-- the awning: stripes sloping from under the fascia out to a valance (a wedge rises toward its local +Z)
	local stripes = sh.stripes or { col, P.white }
	local n = math.max(2, math.floor((x1 - x0) / 1.8))
	local depth = sh.awning or 3.4
	for k = 0, n - 1 do
		local a, b = x0 + (x1 - x0) * k / n, x0 + (x1 - x0) * (k + 1) / n
		local sc = stripes[k % #stripes + 1]
		decor(c:wedge('Awning', V(b - a, 1.8, depth), CFrame.new((a + b) / 2, 9.1, depth / 2 + 0.1) * CFrame.Angles(0, math.pi, 0), sc, M.SmoothPlastic))
		decor(c:box('AwningValance', V(a, 7.6, depth), V(b, 8.2, depth + 0.2), sc, M.SmoothPlastic))
	end
end

-- Fire escape on a facade frame at x (w wide): a dark iron landing under the windows of every upper floor, railings
-- with posts, a stair between each landing and the next, and a drop ladder under the lowest.
local function fireEscape(c, x, w, floors)
	local iron, rail = C(46, 50, 60), C(62, 66, 78)
	local x0, x1 = x - w / 2, x + w / 2
	local prev
	for f = 2, floors do
		local y = P.street.sills[2] + (f - 2) * 15 - 1.4
		sbox(c, 'EscapeLanding', V(x0, y - 0.4, 0), V(x1, y, 2.8), iron, true)
		decor(c:box('EscapeRail', V(x0, y + 3.2, 2.5), V(x1, y + 3.5, 2.8), rail, M.Plastic))
		for _, ex in { x0, x1 - 0.3 } do decor(c:box('EscapeRail', V(ex, y + 3.2, 0), V(ex + 0.3, y + 3.5, 2.8), rail, M.Plastic)) end
		for bx = x0, x1 + 0.01, w / math.max(2, math.floor(w / 2)) do
			decor(c:box('EscapePost', V(math.min(bx, x1 - 0.25), y, 2.5), V(math.min(bx, x1 - 0.25) + 0.25, y + 3.2, 2.75), rail, M.Plastic))
		end
		if prev then
			-- the stair from the landing below, rising along the facade
			decor(c:bar('EscapeStair', V(x0 + 1.5, prev + 0.2, 1.4), V(x1 - 2.5, y - 0.2, 1.4), 1.6, iron, M.Plastic))
			decor(c:bar('EscapeStringer', V(x0 + 1.5, prev + 1.4, 2.3), V(x1 - 2.5, y + 1.0, 2.3), 0.25, rail, M.Plastic))
		else
			-- the drop ladder, hooked up under the lowest landing
			for _, lx in { x1 - 2.2, x1 - 0.8 } do decor(c:box('EscapeLadder', V(lx - 0.12, y - 6, 2.3), V(lx + 0.12, y - 0.4, 2.5), rail, M.Plastic)) end
			for ly = y - 5.5, y - 1, 1.1 do decor(c:box('EscapeRung', V(x1 - 2.2, ly, 2.3), V(x1 - 0.8, ly + 0.15, 2.5), rail, M.Plastic)) end
		end
		prev = y
	end
end

-- Balcony on a facade frame at x (w wide) with its floor at y: a stone slab with a darker edge, an iron railing (top
-- rail, posts) and a door-height window behind it is the wall's own window.
local function balcony(c, x, y, w)
	sbox(c, 'BalconySlab', V(x - w / 2, y - 0.6, -0.2), V(x + w / 2, y, 2.8), P.st.trim, true)
	sbox(c, 'BalconyEdge', V(x - w / 2 - 0.1, y - 0.9, 2.5), V(x + w / 2 + 0.1, y - 0.3, 3.0), P.st.trimDark, true)
	decor(c:box('BalconyRail', V(x - w / 2, y + 3, 2.5), V(x + w / 2, y + 3.35, 2.85), P.iron, M.Plastic))
	for _, ex in { x - w / 2, x + w / 2 - 0.3 } do decor(c:box('BalconyRail', V(ex, y + 3, 0), V(ex + 0.3, y + 3.35, 2.85), P.iron, M.Plastic)) end
	for bx = x - w / 2 + 0.6, x + w / 2 - 0.5, 1.0 do decor(c:box('BalconyBar', V(bx - 0.1, y, 2.55), V(bx + 0.1, y + 3, 2.75), P.iron, M.Plastic)) end
end

-- Red brick house of the reference street, built as a family with real variety: w along the facade, o.depth deep,
-- eave at o.h, in three brick tones (the wall, a darker plinth and thin darker courses every 2.5 studs wrapped round
-- the block), a slate band between the storeys and a stone cornice. Options:
--   o.roof = 'hip' (default) | 'gable' (ridge along the street) | 'gableFront' (gable facing it) | 'flat' (parapet)
--   o.pilasters = n: brick piers with stone caps cut the front into n bays, one window per bay and floor
--   o.bays / o.winW: evenly spaced front windows without piers; o.windows = { { face, x, w } } instead
--   o.entrance = { x =, kind = 'stoop' | 'porch' | 'door', door = Color3, number =, span = { x0, x1 } }: the ground-floor
--     window in its bay is left out
--   o.chimney = { x, z } on the roof; o.gutters (faces with an eave gutter and downpipes, default front, none on a
--   flat roof); o.ac = { { face, x, y } } air-con boxes; o.tags = { { face, x, y, text, color } } spray-painted tags.
local function brickBuilding(ctx, w, o)
	o = o or {}
	local c, model = ctx:group(o.name or 'BrickBuilding')
	local d, ST = o.depth or DEPTH, P.street
	-- storeys: 15 studs each (the picture's two); o.floors 3-4 for the taller districts
	local floors = o.floors or 2
	local H = o.h or (floors == 2 and ST.eave or floors * 15)
	local sills, bands = {}, {}
	for f = 1, floors do
		table.insert(sills, f == 1 and ST.sills[1] or ST.sills[2] + (f - 2) * 15)
		if f >= 2 then table.insert(bands, ST.band + (f - 2) * 15) end
	end
	local wall = o.wall or P.st.brick
	local dark = wall:Lerp(P.black, 0.18)
	local roof = o.roof or 'hip'
	sbox(c, 'Wall', V(0, -1, -d), V(w, H, 0), wall)
	sbox(c, 'Plinth', V(-0.3, -1, -d - 0.3), V(w + 0.3, 2.4, 0.3), dark)
	for y = 4.9, H - 2, floors > 2 and 5 or 2.5 do -- (tall blocks: every other course, read from further away)
		local nearBand = false
		for _, b in bands do if math.abs(y - b) <= 1.6 then nearBand = true end end
		if not nearBand then decor(c:box('BrickCourse', V(-0.06, y, -d - 0.06), V(w + 0.06, y + 0.35, 0.06), dark:Lerp(wall, 0.35), M.Plastic)) end
	end
	for _, b in bands do sbox(c, 'Band', V(-0.5, b, -d - 0.5), V(w + 0.5, b + 1.2, 0.5), P.st.band, true) end
	sbox(c, 'Cornice', V(-0.6, H - 1.2, -d - 0.6), V(w + 0.6, H, 0.6), P.st.trim, true)
	local top = H + 1
	if roof == 'flat' then flatRoof(c, w, d, H, wall); top = H + 2.8
	elseif roof == 'gable' or roof == 'gableFront' then
		local rise = o.rise or (roof == 'gable' and d * 0.32 or w * 0.36)
		gableRoof(c, w, d, H, rise, roof == 'gable' and 'x' or 'z', wall)
		top = H + 1 + rise
	else hipRoof(c, 0, -d, w, 0, H, o.rise, o.run); top = H + 1 + (o.rise or 5) end
	if o.chimney then chimney(c, o.chimney[1], o.chimney[2], H, top + 3, wall) end
	-- Bays: piers at the bay lines (corner piers included), one window per bay and floor.
	local list = o.windows
	if not list then
		list = {}
		local n = o.pilasters or o.bays or math.max(1, math.floor(w / 22 + 0.5))
		local bw = w / n
		for k = 1, n do table.insert(list, { face = 'front', x = bw * (k - 0.5), w = o.winW or (o.pilasters and bw - 4.6 or math.min(16, bw - 6)) }) end
		if o.pilasters then
			for k = 0, n do
				local px = math.clamp(bw * k, 0.8, w - 0.8)
				sbox(c, 'Pilaster', V(px - 0.8, 2.4, 0), V(px + 0.8, H - 1.2, 0.6), wall:Lerp(P.black, 0.06))
				sbox(c, 'PilasterBase', V(px - 1.0, 0.6, 0), V(px + 1.0, 2.4, 0.9), dark, true)
				sbox(c, 'PilasterCap', V(px - 1.0, H - 2.2, 0), V(px + 1.0, H - 1.2, 0.9), P.st.trim, true)
			end
		end
	end
	local ent = o.entrance
	local function inShop(face, x, half)
		for _, sh in o.shops or {} do
			if (sh.face or 'front') == face and x + half > sh.x0 - 0.5 and x - half < sh.x1 + 0.5 then return true end
		end
		return false
	end
	for _, win in list do
		local f = faceFrame(c, win.face, w, d)
		for fl, y in sills do
			local skip = fl == 1 and ((ent and win.face == 'front' and math.abs(win.x - ent.x) < win.w / 2 + 3.5) or inShop(win.face, win.x, win.w / 2) or o.noGround)
			if not skip then window(f, win.x, y, { w = win.w, h = o.winH }) end
		end
	end
	if ent then entrance(c, ent.x, ent) end
	for _, sh in o.shops or {} do shopfront(faceFrame(c, sh.face or 'front', w, d), sh) end
	for _, fe in o.fireEscapes or {} do fireEscape(faceFrame(c, fe.face or 'front', w, d), fe.x, fe.w or 10, floors) end
	for _, b in o.balconies or {} do
		local f = faceFrame(c, b.face or 'front', w, d)
		for fl = 2, floors do balcony(f, b.x, sills[fl] - 0.8, b.w or 10) end
	end
	-- Gutters along the eave and a downpipe at each end of the face, with a kick-out shoe at the foot.
	for _, face in o.gutters or (roof == 'flat' and {} or { 'front' }) do
		local f, fw = faceFrame(c, face, w, d)
		sbox(f, 'Gutter', V(-1, H - 0.2, 1.0), V(fw + 1, H + 0.5, 1.8), P.st.gutter, true)
		for _, xp in { 1.4, fw - 1.4 } do
			sbox(f, 'Downpipe', V(xp - 0.25, 1.2, 0.6), V(xp + 0.25, H - 0.2, 1.1), P.st.gutter, true)
			sbox(f, 'DownpipeShoe', V(xp - 0.3, 0.4, 0.6), V(xp + 0.3, 1.2, 1.7), P.st.gutter, true)
		end
	end
	for _, a in o.ac or {} do
		local f = faceFrame(c, a[1], w, d)
		sbox(f, 'AirCon', V(a[2] - 1.6, a[3], 0), V(a[2] + 1.6, a[3] + 2.2, 1.8), C(206, 210, 216), true)
		decor(f:box('AirConGrille', V(a[2] - 1.3, a[3] + 0.3, 1.8), V(a[2] + 1.3, a[3] + 1.9, 1.9), C(120, 126, 136), M.Plastic))
		sbox(f, 'AirConBracket', V(a[2] - 1.2, a[3] - 0.4, 0), V(a[2] + 1.2, a[3], 1.4), P.st.gutter, true)
	end
	for _, t in o.tags or {} do
		local f = faceFrame(c, t[1], w, d)
		local plate = ghost(f:box('Tag', V(t[2] - 4, t[3], 0.02), V(t[2] + 4, t[3] + 3, 0.08), P.white, M.SmoothPlastic))
		local g = surface(plate, Enum.NormalId.Back, 24) -- (the plate's back faces out of the wall)
		line(g, 'Tag', t[4], t[5], FONT.tag, 0.02, 0.96, P.black, 3).Rotation = -6
	end
	model:SetAttribute('Floors', floors)
	return c, model
end

-- Blue corrugated warehouse with a roll-up door, a light bar and a side door.
local function warehouse(ctx, w, color)
	color = color or P.warehouse
	local c, model = ctx:group('Warehouse')
	local h = 22
	c:box('Wall', V(0, -1, -DEPTH), V(w, h, 0), color, M.SmoothPlastic)
	for x = 1.2, w - 1, 2.4 do decor(c:box('Ridge', V(x - 0.35, 0.5, 0), V(x + 0.35, h - 0.6, 0.25), color:Lerp(P.white, 0.14), M.SmoothPlastic)) end
	local roofBlue = color:Lerp(P.white, 0.25)
	c:box('Roof', V(-0.6, h, -DEPTH - 0.6), V(w + 0.6, h + 1, 1.2), roofBlue, M.SmoothPlastic)
	c:wedge('RoofRidge', V(w + 1.2, 3, DEPTH / 2 + 0.9), CFrame.new(w / 2, h + 2.5, -DEPTH / 4 + 0.15) * CFrame.Angles(0, math.pi, 0), roofBlue, M.SmoothPlastic)
	c:wedge('RoofRidge', V(w + 1.2, 3, DEPTH / 2 + 0.9), CFrame.new(w / 2, h + 2.5, -DEPTH * 3 / 4 - 0.15), roofBlue, M.SmoothPlastic)
	local dx = w * 0.42
	c:box('DoorFrame', V(dx - 8, 0, 0), V(dx + 8, 15.2, 0.4), P.warehouseDark, M.Metal)
	c:box('RollDoor', V(dx - 7, 0, 0), V(dx + 7, 14, 0.5), P.rollDoor, M.Metal)
	for y = 1, 13.5, 1.1 do decor(c:box('DoorSlat', V(dx - 7, y, 0.5), V(dx + 7, y + 0.14, 0.58), P.rollDoor:Lerp(P.black, 0.35), M.Metal)) end
	decor(c:box('LightBar', V(dx - 3, 16, 0), V(dx + 3, 16.6, 0.6), C(255, 210, 60), M.Neon))
	c:box('SideDoorFrame', V(w - 8.6, 0, 0), V(w - 3.4, 9, 0.35), P.warehouseDark, M.Metal)
	c:box('SideDoor', V(w - 8, 0, 0), V(w - 4, 8.2, 0.45), C(30, 56, 120), M.Metal)
	local lampBox = c:box('WallLamp', V(w - 7, 10.6, 0), V(w - 5, 11.4, 1.2), P.iron, M.Metal)
	decor(c:box('WallLampGlow', V(w - 6.8, 10.4, 0.2), V(w - 5.2, 10.6, 1.1), C(255, 230, 160), M.Neon))
	light(lampBox, C(255, 230, 160), 1, 12)
	model:SetAttribute('Floors', 2)
	return c
end

-- A lot of stacked shipping containers behind a low wall, crates out front (the yards' side "buildings").
local function containerLot(ctx, w, seed)
	local c = ctx:group('ContainerLot')
	c:box('LotFloor', V(0, -1, -DEPTH), V(w, 0.06, 0), C(176, 178, 184), M.Concrete)
	c:box('LotWall', V(0, -1, -DEPTH), V(w, 6, -DEPTH + 2), P.wall, M.Concrete)
	local colors = { P.containerBlue, P.containerRed, C(60, 150, 90), P.containerRed }
	local n = math.floor(w / 20)
	for k = 0, n - 1 do
		local x = (w - n * 20) / 2 + 10 + k * 20
		local h = (seed or 0) + k
		container(c, CFrame.new(x, 0.06, -10) * CFrame.Angles(0, math.pi / 2, 0), colors[h % 4 + 1])
		if h % 2 == 0 then container(c, CFrame.new(x, 8.66, -10) * CFrame.Angles(0, math.pi / 2, 0), colors[(h + 1) % 4 + 1]) end
		container(c, CFrame.new(x, 0.06, -21) * CFrame.Angles(0, math.pi / 2, 0), colors[(h + 2) % 4 + 1])
		container(c, CFrame.new(x, 8.66, -21) * CFrame.Angles(0, math.pi / 2, 0), colors[(h + 3) % 4 + 1])
	end
	for k, x in { 4, w * 0.45, w - 5 } do
		pallet(c, CFrame.new(x, 0.06, -3))
		crate(c, CFrame.new(x, 0.86, -3), 3)
		if k == 2 then crate(c, CFrame.new(x + 0.3, 3.86, -3.2) * CFrame.Angles(0, 0.25, 0), 2.6) end
	end
	-- Chain-link along the front with a gap, so it reads as a yard and not a wall.
	chainLink(c, V(0.3, 0.06, 0.3), V(w - 0.3, 0.06, 0.3), 8, { { w * 0.5 - 3, w * 0.5 + 3 } })
	return c
end
