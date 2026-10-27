---------------------------------------------------------------------------------------------- stage gates
-- A gate at the start of every stage (and the boss yard), built to read from the lobby as SHUT (BRIEF18): a
-- see-through red-tinted haze across the opening between the end buildings (deeper at the top, lighter at the foot,
-- so the street and the next gates show through it), two hazard-striped barrier bars across it and a big chunky
-- padlock hanging on the lower one (the video's locked gate), a lit lip and edges and a glowing emitter track along
-- its foot. Its frame follows the video game's gates: a sturdy studded pillar each side (plinth, a column of
-- recesses, banded cap) and a hazard-striped beam. The text is ONE sign hung in the opening (the video's): "STAGE N" in
-- white, "Recommended" in cyan, "Power: X" in cyan pixel letters (the reference's corridor sign) and a state line, with
-- a thick dark outline. (Brief 29: it is a fixed board now, a SurfaceGui on a thin invisible panel in the gate's own
-- plane, 34 x 12 studs, so it never grows, shrinks, fades or turns; its letters and outlines are painted at one size.
-- HoodClient/Stages only shows it on your next gate and switches its lines for "STAGE N / OPEN!".)
-- The run (brief 23): a gate opens for you when you beat the crew of the stage before it, every run, and shuts again
-- when you go back to the lobby (HoodServer/Runs; gate 1 is always open). HoodClient/Stages keeps the wall solid and
-- locked-looking while it is shut, and at the moment the crew falls shatters the haze, drops the bars and padlock and
-- turns the badge green; StageService keeps anyone from walking past a gate they haven't opened.
-- Two pads stand on the sidewalks just before every gate n >= 2, the reference's "+2 WINS / 2x Wins" and "+1 WIN /
-- Return": yellow on the right ("+10 Cash / Return": the stage's Cash and back to the lobby) and magenta on the left
-- ("+100 Cash / 10x Cash": ten times that, with the 10x Cash pass), both paying for stage n - 1's crew; each a
-- three-tone slab on a dark rim with a neon edge, chevrons home and a few sparkles (d_kit's stagePad).
local GATE = {
	H = 18.5, -- the wall's height (the reference's wall reaches the end buildings' second floor)
	pink = C(250, 160, 222), -- the gate's colour (attribute Color: the STAGE CLEARED banner)
	mint = C(150, 250, 190), -- what flies off when you break through (attribute Light: shards, burst)
	-- The locked haze from the top of the wall down: height above the street, colour, opacity. Deep crimson at the top
	-- (the "closed" read from far away), rose at eye level, where it is thin enough to see the street beyond.
	-- (The opacity only grows upward: the haze is drawn as stacked panes, each from the top down to its band.)
	haze = {
		{ 18.5, C(168, 24, 58), 0.78 }, { 16.5, C(186, 32, 68), 0.72 }, { 12.5, C(212, 54, 90), 0.62 },
		{ 8, C(230, 86, 120), 0.54 }, { 3, C(242, 122, 152), 0.5 }, { 0, C(246, 142, 168), 0.5 },
	},
	bands = 74, -- quarter-stud bands (5 px each at the haze's 20 pixels per stud)
	-- The world's text style (brief 28: the references' Montserrat Black, like the lobby's labels and the pads; was
	-- FredokaOne): heavy letters with a thick near-black outline, colour by meaning: white STAGE N, cyan Recommended and
	-- cyan "Power: X" (the video's #45E6FF, both in this one face, brief 30: ref_W30.0_stage1_gate_close), and the
	-- state line as a badge, white on red (locked, blocked) or green (open).
	font = FONT.title,
	title = C(255, 255, 255), titleInk = C(14, 16, 26),
	sub = C(69, 230, 255), subInk = C(8, 26, 46),
	status = C(255, 255, 255), statusInk = C(40, 6, 14), plate = C(214, 34, 58), plateInk = C(36, 8, 16),
	-- The sign: its size in studs where it stands and the height of its foot (just over the padlock; it grows upward
	-- from there, see HoodClient/Stages: GrowFrom studs, GrowPow, GrowMax, never past the openings in front of it), and
	-- its lines: name, top and height (0-1 of the sign) and outline thickness as a share of the line's height (UI2's:
	-- ~7% on titles, ~11% on small lines).
	signW = 34, signH = 11.6, signY = 6.8, signZ = 2.9, signPPS = 30, -- (the board: studs, foot height, distance in front of the wall, px per stud)
	lines = {
		{ 'Title', 0, 0.37, 0.075 }, { 'Sub', 0.375, 0.235, 0.1 }, { 'Power', 0.61, 0.235, 0.1 }, { 'Status', 0.88, 0.12, 0.1 },
	},
	plateBox = { 0.24, 0.87, 0.52, 0.13 }, -- the state badge behind the Status line: x, y, w, h (0-1 of the sign)
	magenta = C(255, 32, 255), yellow = C(250, 246, 70), padRim = C(58, 66, 98), -- the pads and the dark rim under them
	-- Each pad: its lit top, the darker sides, the neon edge between them, its label's big words (the reference's
	-- "2M Wins" magenta and "200K Wins" yellow) in a well-known game face.
	padLook = {
		magenta = { shade = C(184, 16, 186), rim = C(255, 178, 255), label = C(255, 56, 236) },
		yellow = { shade = C(204, 184, 24), rim = C(255, 255, 196), label = C(255, 232, 36) },
	},
	padFont = FONT.title,
	edge = C(255, 176, 196), -- the haze's lit lip along the top and its side edges
	-- The frame: studded concrete in three tones, dark recesses, a hazard beam with a darker lip.
	pillarW = 4, beamH = 3,
	stone = C(160, 162, 172), stoneDark = C(116, 118, 130), stoneLight = C(190, 192, 200), recess = C(62, 66, 80),
	hazard = C(250, 204, 40), hazardDark = C(36, 38, 46), hazardLip = C(196, 146, 28),
	steel = C(70, 74, 90), bolt = C(156, 160, 172), -- the plates clamping the beam to the pillars
	track = C(58, 66, 98), trackGlow = C(255, 96, 128), -- the emitter track along the foot and its glowing line
	-- The lock: two barrier rails low across the opening (bottom y, height; the stripes' width; the padlock hangs on
	-- the upper one) and the padlock (gold body in three tones, a dark keyhole, a steel shackle).
	bars = { { 1.6, 1.2 }, { 4.6, 1.3 } }, stripe = 1.5,
	gold = C(255, 196, 40), goldDark = C(206, 142, 18), goldLight = C(255, 232, 140), keyhole = C(64, 36, 8),
	shackle = C(196, 202, 216), shackleDark = C(132, 138, 156),
	titleShade = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(222, 228, 240)), -- lighter top, deeper foot
}
-- Colour and opacity of the haze at height h (linear between the keys above).
function GATE.hazeAt(h)
	local k = GATE.haze
	for n = 1, #k - 1 do
		local a, b = k[n], k[n + 1]
		if h <= a[1] and h >= b[1] then
			local t = (a[1] - h) / (a[1] - b[1])
			return a[2]:Lerp(b[2], t), a[3] + (b[3] - a[3]) * t
		end
	end
	return k[#k][2], k[#k][3]
end
-- One line of the sign (y and h are 0-1 of its height), centred, outlined; HoodClient/Stages sets the outline's
-- thickness is the line's height in canvas pixels times its Ink share (about 7% on the title, 10% on the small lines,
-- UI2's), painted once.
function GATE.text(gui, name, value, y, h, color, ink, share)
	local px = GATE.signH * GATE.signPPS * h
	local t = line(gui, name, value, color, GATE.font, y, h, ink, math.max(3, math.floor(px * share + 0.5)))
	t.Position, t.Size = UDim2.fromScale(0, y), UDim2.fromScale(1, h)
	t.TextWrapped = false
	t.ZIndex = 2
	t:SetAttribute('Ink', share)
	return t
end
-- One finished-edge frame over the haze (drawn above its bands).
function GATE.edgeFrame(gui, pos, size, transparency, z)
	local f = Instance.new('Frame')
	f.Name = 'Pane'
	f.BorderSizePixel = 0
	f.Position, f.Size = pos, size
	f.BackgroundColor3, f.BackgroundTransparency = GATE.edge, transparency
	f.ZIndex = z
	f:SetAttribute('BaseColor', GATE.edge)
	f:SetAttribute('BaseTransparency', transparency)
	f.Parent = gui
	return f
end
-- Black stripes slanting "/" across the approach face (at z) of a yellow bar from y to y + h, x -half..half: each
-- stripe two wedges, a parallelogram as wide as its slant (as on the beam).
function GATE.stripes(g, name, half, y, h, a, z)
	local face = CFrame.fromMatrix(Vector3.zero, V(0, 0, 1), V(0, 1, 0))
	local n = math.floor((2 * half - 1.5) / (2 * a))
	local parts = {}
	for k = 0, n - 1 do
		local x = -a * n + 2 * a * k
		table.insert(parts, decor(g:wedge(name, V(0.06, h, a), CFrame.new(x + a / 2, y + h / 2, z) * CFrame.Angles(0, math.pi, 0) * face, GATE.hazardDark, M.SmoothPlastic)))
		table.insert(parts, decor(g:wedge(name, V(0.06, h, a), CFrame.new(x + a * 1.5, y + h / 2, z) * CFrame.Angles(math.pi, 0, 0) * face, GATE.hazardDark, M.SmoothPlastic)))
	end
	return parts
end
-- The lock (only while the gate is shut for you; HoodClient/Stages hides every Lock* part once you can pass): two
-- hazard-striped barrier bars mounted across the haze's approach face, between the pillars, and a big padlock
-- hanging on the lower one in the middle, in front of everything (a gold body with a lighter lip, a darker foot and a
-- keyhole; a steel shackle over the bar).
function GATE.lock(g, inner)
	local parts = {}
	local function add(p) p.CastShadow = false; table.insert(parts, decor(p)); return p end
	for _, b in GATE.bars do
		local y, h = b[1], b[2]
		add(g:box('LockBar', V(-inner, y, 0.34), V(inner, y + h, 0.74), GATE.hazard, M.SmoothPlastic))
		add(g:box('LockBarLip', V(-inner, y - 0.12, 0.3), V(inner, y, 0.78), GATE.hazardLip, M.SmoothPlastic))
		for _, p in GATE.stripes(g, 'LockStripe', inner, y, h, GATE.stripe, 0.77) do add(p) end
	end
	local by = GATE.bars[2][1] -- the upper rail's foot: the body hangs under it, the shackle loops over it
	local x, y0, y1, z0, z1 = 2.3, by - 3.9, by - 0.1, 0.9, 2.3
	add(g:box('LockShackle', V(-1.75, by - 0.4, 1.3), V(-0.95, by + 2.4, 1.9), GATE.shackle, M.SmoothPlastic))
	add(g:box('LockShackle', V(0.95, by - 0.4, 1.3), V(1.75, by + 2.4, 1.9), GATE.shackle, M.SmoothPlastic))
	add(g:box('LockShackle', V(-1.75, by + 1.7, 1.3), V(1.75, by + 2.5, 1.9), GATE.shackle, M.SmoothPlastic))
	add(g:box('LockShackleShade', V(-1.75, by + 2.3, 1.25), V(1.75, by + 2.6, 1.95), GATE.shackleDark, M.SmoothPlastic))
	add(g:box('LockBody', V(-x, y0 + 0.6, z0), V(x, y1, z1), GATE.gold, M.SmoothPlastic))
	add(g:box('LockFoot', V(-x, y0, z0), V(x, y0 + 0.6, z1), GATE.goldDark, M.SmoothPlastic))
	add(g:box('LockLip', V(-x - 0.12, y1 - 0.45, z0 - 0.12), V(x + 0.12, y1, z1 + 0.12), GATE.goldLight, M.SmoothPlastic))
	local cy = (y0 + y1) / 2 + 0.15
	add(g:part('LockKeyhole', V(0.1, 1.1, 1.1), CFrame.new(0, cy + 0.25, z1 + 0.05) * CFrame.Angles(0, math.pi / 2, 0), GATE.keyhole, M.SmoothPlastic, Enum.PartType.Cylinder))
	add(g:box('LockKeyhole', V(-0.22, cy - 0.85, z1), V(0.22, cy + 0.2, z1 + 0.1), GATE.keyhole, M.SmoothPlastic))
	for _, p in parts do p:SetAttribute('BaseTransparency', p.Transparency) end
	return parts
end
-- The sign: one fixed board in the opening (the video's gate sign): a SurfaceGui on a thin invisible panel standing in
-- front of the lock, facing the street (the approach side). A panel in the gate's plane is depth-tested like the wall,
-- so the beam and the pillars never cut it, and it holds one size, at one outline, from every distance. It is wide as
-- the opening (34 of its 36 studs) and its top meets the beam; the lock's upper bar and padlock are under its foot.
-- HoodClient/Stages shows it only on your next gate and writes the state line.
function GATE.sign(g, i, req)
	local board = ghost(g:part('SignBoard', V(GATE.signW, GATE.signH, 0.1), CFrame.new(0, GATE.signY + GATE.signH / 2, GATE.signZ), P.white))
	board.CastShadow = false
	local gui = surface(board, Enum.NormalId.Back, GATE.signPPS)
	gui.Name = 'GateSign'
	gui.AlwaysOnTop = false
	-- (brief 28) Built as a player first sees it: HoodClient/Stages shows only your next gate's sign, which from the spawn is
	-- gate 1's; the others start hidden, so Studio's edit view and the previews never stack the far signs behind it.
	gui.Enabled = i == 1
	local L = {}
	for _, l in GATE.lines do L[l[1]] = l end
	local function put(name, text, color, ink)
		return GATE.text(gui, name, text, L[name][2], L[name][3], color, ink, L[name][4])
	end
	-- (brief 30) the last stage is "STAGE 16" like the rest (the user: "remove everything saying its a boss")
	local title = put('Title', 'STAGE ' .. i, GATE.title, GATE.titleInk)
	local grad = Instance.new('UIGradient')
	grad.Color, grad.Rotation = GATE.titleShade, 90
	grad.Parent = title
	put('Sub', 'Recommended', GATE.sub, GATE.subInk)
	-- (brief 30, the user's decision: "Gates show Recommended Power: X, like the reference; Level stays on the HUD bar")
	-- "Power: X" in the sign's own heavy face, cyan like "Recommended" (ref_W30.0_stage1_gate_close: one face, one colour)
	put('Power', 'Power: ' .. compact(req), GATE.sub, GATE.subInk)
	-- The state line on its badge: "Defeat the crew first" while the stage before still has its goons this run (as
	-- built), "OPEN!" once its crew is down (HoodClient/Stages writes it and the badge colour, and makes an open gate's
	-- sign compact: the title over the badge).
	-- (The badge and the line are siblings so every preview exporter places both in the sign's own frame.)
	local b = GATE.plateBox
	local plate = Instance.new('Frame')
	plate.Name = 'StatusPlate'
	plate.BorderSizePixel = 0
	plate.Position, plate.Size = UDim2.fromScale(b[1], b[2]), UDim2.fromScale(b[3], b[4])
	plate.BackgroundColor3, plate.BackgroundTransparency = GATE.plate, 0.08
	plate.ZIndex = 1
	local corner = Instance.new('UICorner')
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = plate
	local edge = Instance.new('UIStroke')
	edge.Color, edge.Thickness = GATE.plateInk, 5
	edge.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	edge.Parent = plate
	plate.Parent = gui
	-- (brief 30) the reference's states: a shut gate shows only its white "Defeat the crew first" line mid-barrier, no badge
	-- (HoodClient/Stages writes "Defeat <name>" where a crew's strongest stands); an open one the STAGE / Recommended /
	-- Power lines. Built as the player first sees them: gate 1 open, the rest shut.
	plate.Visible = false
	local status = put('Status', 'Defeat the crew first', GATE.status, GATE.statusInk)
	status.Position, status.Size = UDim2.fromScale(0.03, 0.44), UDim2.fromScale(0.94, 0.17)
	status.Visible = i > 1
	for _, n in { 'Title', 'Sub', 'Power' } do
		local l = gui:FindFirstChild(n)
		if l then l.Visible = i == 1 end
	end
	return gui
end
-- The frame (stays up once you've cleared the gate): a pillar each side of the opening, standing on the gate line
-- in front of the end building's corner (inner face at x = +-inner, outer at +-outer), and the striped beam across
-- the top of the wall between them.
function GATE.frame(g, inner, outer, H)
	local top, half = H + GATE.beamH, 1.7
	for _, s in { -1, 1 } do
		local mid = s * (inner + outer) / 2
		g:box('GatePlinth', V(s * (inner - 0.3), 0, -half - 0.3), V(s * outer, 1.4, half + 0.3), GATE.stoneDark, M.Concrete)
		-- (The pillars rise a little over the beam, as in the video, so the gate reads as two posts and a lintel.)
		studs(g:box('GatePillar', V(s * inner, 1.4, -half), V(s * outer, top + 1.6, half), GATE.stone, M.Plastic), true)
		g:box('GateCapBand', V(s * (inner - 0.15), top + 1.6, -half - 0.15), V(s * outer, top + 2, half + 0.15), GATE.stoneDark, M.SmoothPlastic)
		studs(g:box('GateCap', V(s * (inner - 0.3), top + 2, -half - 0.3), V(s * outer, top + 2.7, half + 0.3), GATE.stoneLight, M.Plastic))
		-- A column of square recesses down the approach face, the back face and the face toward the road, each in a
		-- sunk channel: two lighter strips stand proud along its edges (the face reads as pilaster - channel - pilaster).
		for k = 0, 5 do
			local y = 3 + k * 2.55
			for _, f in { -1, 1 } do
				decor(g:box('GateRecess', V(mid - 0.6, y, f * half), V(mid + 0.6, y + 1.2, f * (half + 0.06)), GATE.recess, M.SmoothPlastic))
			end
			decor(g:box('GateRecess', V(s * (inner - 0.06), y, -0.6), V(s * inner, y + 1.2, 0.6), GATE.recess, M.SmoothPlastic))
		end
		for _, f in { -1, 1 } do
			for _, e in { inner, outer - 0.9 } do
				decor(g:box('GatePilaster', V(s * e, 1.4, f * half), V(s * (e + 0.9), H - 0.3, f * (half + 0.15)), GATE.stoneLight, M.SmoothPlastic))
			end
		end
		for _, zc in { -half + 0.6, half - 0.6 } do
			decor(g:box('GatePilaster', V(s * (inner - 0.15), 1.4, zc - 0.6), V(s * inner, H - 0.3, zc + 0.6), GATE.stoneLight, M.SmoothPlastic))
		end
	end
	-- The beam: yellow with a darker lip under and over it, black stripes slanting across its approach face (each
	-- stripe two wedges: a parallelogram as wide as its slant).
	g:box('GateBeam', V(-inner, H, -1.2), V(inner, top, 1.2), GATE.hazard, M.SmoothPlastic)
	for _, y in { H - 0.25, top } do
		g:box('GateBeamLip', V(-inner, y, -1.3), V(inner, y + 0.25, 1.3), GATE.hazardLip, M.SmoothPlastic)
	end
	-- A steel plate clamps each end of the beam to its pillar, front and back, with two bolts each.
	for _, s in { -1, 1 } do
		for _, f in { -1, 1 } do
			local z0, z1 = f * 1.2, f * 1.45
			g:box('GateClamp', V(s * (inner - 1.3), H - 0.3, z0), V(s * inner, top + 0.3, z1), GATE.steel, M.SmoothPlastic)
			for _, y in { H + 0.55, top - 0.95 } do
				decor(g:box('GateBolt', V(s * (inner - 0.85), y, z1), V(s * (inner - 0.45), y + 0.4, z1 + f * 0.12), GATE.bolt, M.SmoothPlastic))
			end
		end
	end
	local a, h = GATE.beamH, GATE.beamH
	local face = CFrame.fromMatrix(Vector3.zero, V(0, 0, 1), V(0, 1, 0)) -- a wedge's triangle turned onto the XY plane
	local n = math.floor((2 * inner - 3) / (2 * a))
	for k = 0, n - 1 do
		local x = -a * n + 2 * a * k
		-- left half: right angle at the bottom right; right half: right angle at the top left (both slant "/"), on the
		-- approach face and (mirrored, so they read "/" from that side too) on the back
		for _, f in { 1, -1 } do
			local xa, xb = f * (x + a / 2), f * (x + a * 1.5)
			decor(g:wedge('GateStripe', V(0.06, h, a), CFrame.new(xa, H + h / 2, f * 1.23) * CFrame.Angles(0, f > 0 and math.pi or 0, 0) * face, GATE.hazardDark, M.SmoothPlastic))
			decor(g:wedge('GateStripe', V(0.06, h, a), CFrame.new(xb, H + h / 2, f * 1.23) * CFrame.Angles(0, f > 0 and 0 or math.pi, 0) * CFrame.Angles(math.pi, 0, 0) * face, GATE.hazardDark, M.SmoothPlastic))
		end
	end
end
-- The two pads of `stage` (its crew pays out on them), at +-x, z in g's frame, on a floor at y: magenta 10x Cash on the
-- left, yellow Return on the right, both with chevrons home (toward +Z, the way back). Their first words (ECON's PadRules
-- when it is there; HoodClient/Stages keeps them current).
function GATE.pads(g, stage, x, z, y, w, d)
	local okPads, PadRules = pcall(function() return require(ReplicatedStorage.Shared.PadRules) end)
	local function words(kind)
		if okPads and type(PadRules) == 'table' and type(PadRules.labels) == 'function' then
			local ok, big, small, price = pcall(PadRules.labels, stage, kind, false)
			if ok and type(big) == 'string' then return big, small, price end
		end
		local cash = 10 * 2 ^ (stage - 1) * (kind == 'TenX' and 10 or 1)
		return '+' .. compact(cash) .. ' Cash', kind == 'TenX' and '10x Cash' or 'Return', nil
	end
	for _, side in { { -1, 'TenXPad', 'TenX', GATE.magenta, GATE.padLook.magenta }, { 1, 'ReturnPad', 'Return', GATE.yellow, GATE.padLook.yellow } } do
		local look = side[5]
		local big, small, price = words(side[3])
		stagePad(g, side[2], side[1] * x, z, side[4], stage, side[3], { w = w, d = d, y = y, h = 0.25, material = M.SmoothPlastic,
			base = GATE.padRim, shade = look.shade, rim = look.rim, sparkle = true, arrow = 1, font = GATE.padFont,
			label = { big = big, small = small, price = price, color = look.label } })
	end
end
-- (brief 30, FIGHTS: shared with the warehouse's World 2 door, code5/f4_finale) The wall's see-through haze: an invisible
-- collider across the opening (-inner..inner, H high) carrying the banded haze on its approach face. Returns the Barrier.
function GATE.hazeWall(g, inner, H, dense)
	local barrier = g:box('Barrier', V(-inner, 0, -0.3), V(inner, H, 0.3), GATE.pink, M.SmoothPlastic)
	barrier.Transparency = 1
	barrier:SetAttribute('BaseTransparency', 1)
	barrier.CastShadow = false
	-- The haze: one pane per quarter-stud band, each running from the top of the wall down to its band, so band n
	-- shows panes n..last stacked (the haze is densest at the top). Each pane's colour and opacity are solved so the
	-- stack matches the band's colour exactly; no pane edge falls between two bands, so there are no seams.
	local haze = surface(barrier, Enum.NormalId.Back, 20)
	haze.Name = 'Haze'
	-- Finished edges: a brighter lip along the top and a soft lit edge down each side (above the bands; parented
	-- before them, see below).
	local side = 0.4 / (2 * inner)
	GATE.edgeFrame(haze, UDim2.fromScale(0, 0), UDim2.fromScale(1, 0.3 / H), 0.5, GATE.bands + 1)
	GATE.edgeFrame(haze, UDim2.fromScale(0, 0), UDim2.fromScale(side, 1), 0.62, GATE.bands + 2)
	GATE.edgeFrame(haze, UDim2.fromScale(1 - side, 0), UDim2.fromScale(side, 1), 0.62, GATE.bands + 3)
	local pa, pc = 0, Vector3.zero -- the stack so far (the panes below this band's): opacity and premultiplied colour
	local panes = {}
	for n = GATE.bands - 1, 0, -1 do
		local color, alpha = GATE.hazeAt(H * (1 - (n + 0.5) / GATE.bands))
		-- (The boss yard's wall is denser: the Champ Ring's glow right behind it would drown it.)
		if dense then alpha = 1 - (1 - alpha) * 0.5 end
		alpha = math.max(alpha, pa)
		local a = pa < 1 and 1 - (1 - alpha) / (1 - pa) or 0
		local want = V(color.R, color.G, color.B) * alpha
		local c = a > 0.001 and (want - pc * (1 - a)) / a or V(color.R, color.G, color.B)
		c = V(math.clamp(c.X, 0, 1), math.clamp(c.Y, 0, 1), math.clamp(c.Z, 0, 1))
		pa, pc = alpha, c * a + pc * (1 - a)
		local paneColor = Color3.new(c.X, c.Y, c.Z)
		local f = Instance.new('Frame')
		f.Name = 'Pane'
		f.BorderSizePixel = 0
		f.Position, f.Size = UDim2.fromScale(0, 0), UDim2.fromScale(1, (n + 1) / GATE.bands)
		f.BackgroundColor3, f.BackgroundTransparency = paneColor, 1 - a
		f.ZIndex = GATE.bands - n
		f:SetAttribute('BaseColor', paneColor)
		f:SetAttribute('BaseTransparency', 1 - a)
		panes[n + 1] = f
	end
	-- (ZIndex sets the order in Roblox; parenting the top pane first also keeps preview exporters, which list frames
	-- in reverse, drawing them in the same order.)
	for n = 1, #panes do panes[n].Parent = haze end
	return barrier
end
local function stageGate(ctx, i)
	local z = gateZ(i)
	local st = P.street or {}
	local road, walk, kerb, open, front = st.road or 8.5, st.walk or 8.5, st.kerb or 0.6, st.open or 22, st.front or FRONT
	local H = GATE.H
	local req = STAGE_POWER[i]
	local g, model = ctx:at(CFrame.new(0, 0, z)):group('StageGate' .. i)
	-- The pillars stand on the grass in front of the end buildings' corners; the wall spans the opening between them.
	local inner = open - GATE.pillarW
	-- (B31 PLAZA, rule 29) gate 1 is the user's Gate_Stage1 when imported, scaled to the frame's width (its pillars at
	-- +-4.6..10.1 and its beam's foot 10 up, in design studs): the wall, the lock, the field and the sign's opening follow
	-- its narrower opening, and two invisible blocks make its pillars solid. Else (and for every other gate) our frame.
	local frameTop = H + GATE.beamH + 2.7
	if i == 1 and type(Lobby) == 'table' and Lobby.hasDesign and Lobby.hasDesign('Gate_Stage1') then
		local k = open / 10.1
		Lobby.designed(g, 'Gate_Stage1', k)
		inner, H, frameTop = 4.6 * k, 10 * k, 14.17 * k
		-- its white board (blank by design, 15.9 x 2.3, 12.45 up): the world's name, in the gate's chunky words
		local board = g:box('GateBoardFace', V(-7.6 * k, 11.4 * k, -2.55 * k - 0.05), V(7.6 * k, 13.5 * k, -2.55 * k), P.white, M.SmoothPlastic)
		local bt = line(surface(board, Enum.NormalId.Front, 6), 'World', 'WORLD 1', C(255, 214, 60), FONT.title, 0.08, 0.84, C(40, 30, 10), 4)
		bt.Name = 'GateWorldName'
		for _, sx in { -1, 1 } do
			local post = ghost(g:box('GatePillarSolid', V(sx * inner, 0, -2.35 * k), V(sx * open, H, 2.35 * k), P.white))
			post.CanCollide, post.CastShadow = true, false
		end
	else
		GATE.frame(g, inner, open, H)
	end
	-- The wall: an invisible collider across the opening (solid on the server; HoodClient/Stages lets you through
	-- once it is open for you this run), carrying the haze on its approach face.
	GATE.hazeWall(g, inner, H, i > STAGES)
	-- The lock: barrier bars and the padlock (Lock* parts).
	GATE.lock(g, inner)
	-- The sign (shown by HoodClient/Stages on your next gate only).
	GATE.sign(g, i, req)
	-- The field's foot: a dark emitter track along the ground on the approach side with a glowing line on top,
	-- stepping up onto the sidewalks (HoodClient/Stages tints and clears every Field* part with the haze).
	for _, seg in { { -inner, -road, kerb }, { -road, road, 0 }, { road, inner, kerb } } do
		local x0, x1, y = seg[1], seg[2], seg[3]
		local track = decor(g:box('FieldTrack', V(x0, y, 0.3), V(x1, y + 0.2, 0.95), GATE.track, M.SmoothPlastic))
		local glow = decor(g:box('FieldGlow', V(x0, y + 0.2, 0.54), V(x1, y + 0.27, 0.72), GATE.trackGlow, M.Neon))
		glow.CastShadow = false
		for _, p in { track, glow } do
			p:SetAttribute('BaseColor', p.Color)
			p:SetAttribute('BaseTransparency', 0)
		end
	end
	-- Pads on the sidewalks just before the wall (measured on the reference: ~6 x 11 with the dark rim, a 3-stud strip of
	-- pavement between them and the wall, 0.5 off the kerb), paying for the stage before this gate: 10x Cash (magenta,
	-- left) and Return (yellow, right).
	local padW, padD = math.min(5.6, walk - 1.5), 11
	local padX, padZ = road + 0.5 + padW / 2, 3 + padD / 2
	if i > 1 then GATE.pads(g, i - 1, padX, padZ, kerb, padW, padD) end
	-- Confetti the client fires when you break through.
	local shell = ghost(g:box('PassShell', V(-12, 16, -1), V(12, 17, 1), P.white))
	local fx = Instance.new('ParticleEmitter')
	fx.Name = 'PassFX'
	fx.Texture = 'rbxasset://textures/particles/SquareParticle.png'
	fx:SetAttribute('PreviewTexture', 'confetti')
	fx.Enabled = false
	fx.Rate = 0
	fx.Lifetime, fx.Speed = NumberRange.new(1.6, 2.6), NumberRange.new(8, 18)
	fx.SpreadAngle = Vector2.new(70, 70)
	fx.Acceleration = V(0, -18, 0)
	fx.Drag = 1.2
	fx.Size = NumberSequence.new(0.5)
	fx.RotSpeed, fx.Rotation = NumberRange.new(-260, 260), NumberRange.new(0, 360)
	fx.Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, GATE.magenta), ColorSequenceKeypoint.new(0.5, GATE.yellow), ColorSequenceKeypoint.new(1, P.white) })
	fx.EmissionDirection = Enum.NormalId.Bottom
	fx.LightInfluence = 1
	fx.Parent = shell
	model:SetAttribute('Stage', i)
	model:SetAttribute('WallId', 'HoodW1Stage' .. i)
	model:SetAttribute('Required', req)
	model:SetAttribute('LineZ', z)
	model:SetAttribute('PadZ', z + padZ)
	model:SetAttribute('HalfWidth', front)
	model:SetAttribute('Color', GATE.pink)
	model:SetAttribute('Light', GATE.mint)
	-- The openings HoodClient/Stages fits a grown sign into: this gate's opening and frame outline, and (gate 1) the
	-- hall's doorway it is seen through from the lobby.
	model:SetAttribute('OpenHalf', inner)
	model:SetAttribute('OpenTop', H)
	model:SetAttribute('FrameHalf', open)
	model:SetAttribute('FrameTop', frameTop)
	if i == 1 and type(Lobby) == 'table' and type(Lobby.Door) == 'number' then
		model:SetAttribute('DoorHalf', Lobby.Door)
		model:SetAttribute('DoorTop', Lobby.DoorH or 30)
		model:SetAttribute('DoorZ', Lobby.DoorZ or ((Lobby.N or 6) + 0.9))
	end
	pcall(function() model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic end)
	model:AddTag('HoodStageGate')
	return model
end
---------------------------------------------------------------------------------------------- stages
-- Every stage is the reference street (ref1_street.png), copied 1:1 for now. buildGround lays the cross-section
-- (road, sidewalks, grass); each stage adds, measured from the picture (z' = studs past the stage's own gate):
--   z' 0..56   the open street: a plank fence along each front yard (|x| = 34.5) and a long two-storey brick
--              building behind it (fronts at |x| = 36);
--   z' 56..64  the end buildings come forward to |x| = 22 and run up to the next gate, whose wall fills the gap;
--   tall navy lamps (left at z' 19 and 53.5, right at 50), stacked-cube trees, low hedges, the green dumpster, blue
--   flowers and grass tufts, where the picture has them (P.street holds the numbers). The camera that matches the
--   picture stands at z' 2, 13.6 up, 1.1 right of the centre line, pitched 17.6 down, FOV 70. The picture's wall is
--   ~120 studs ahead and its narrowing starts ~85 out; ours are 62 and 54 (the stages are 64 long), so the far
--   things here sit closer together than in the picture while the near ones stand where the picture has them.
local function sideRow(ctx, s, za, lots)
	local z = za
	for _, lot in lots do
		lot[2](lotFrame(ctx, s, z, lot[1]), lot[1])
		z -= lot[1]
	end
end
-- The end building on side s, from its front (z0, facing back up the street) to the next gate line (z1): solid from
-- |x| = open out to the back of the lots, windows on the strip of front that shows and on the side facing the road.
local function endBuilding(ctx, s, z0, z1, extra)
	local ST = P.street
	local w, d = FRONT + DEPTH - ST.open, z0 - z1
	local strip = FRONT - ST.open
	local inner = s < 0 and 'right' or 'left'
	-- A stone pillar on the inner front corner frames the narrowing: a darker base, a studded shaft, a darker cap.
	for _, zc in { z0 } do -- (GATES' own pillars frame the wall at the gate line)
		local f = zc == z0 and 1 or -1 -- (which way the corner's exposed face looks: back up the street, or on past the gate)
		local x0, x1 = s * (ST.open - 0.8), s * (ST.open + 1.2)
		local za, zb = zc - f * 1.2, zc + f * 0.8
		sbox(ctx, 'CornerPillarBase', V(x0 - s * 0.3, -0.5, za), V(x1, 2.8, zb + f * 0.3), P.st.trimDark)
		sbox(ctx, 'CornerPillar', V(x0, 2.8, za), V(x1, ST.eave + 2.4, zb), P.st.trim)
		sbox(ctx, 'CornerPillarCap', V(x0 - s * 0.3, ST.eave + 2.4, za), V(x1, ST.eave + 3.6, zb + f * 0.3), P.st.trimDark, true)
	end
	local o = { name = 'EndBuilding', depth = d, h = ST.eave + 2, run = math.min(5, d / 2 - 1), rise = 4, windows = {
		{ face = 'front', x = s < 0 and w - strip / 2 or strip / 2, w = 10 },
		{ face = inner, x = d / 2, w = math.min(10, d - 2) },
	}, gutters = { 'front', inner } }
	-- (extra: the district's own wall colour, storeys and roof)
	for k, v in extra or {} do o[k] = v end
	if o.floors and not (extra and extra.h) then o.h = nil end
	return brickBuilding(ctx:at(CFrame.new(s < 0 and -(FRONT + DEPTH) or ST.open, 0, z0)), w, o)
end
-- Stage plans. Stage 1 is the production section (art direction brief 15): a family of four brick houses that differ
-- in width, height, roofline, setback, entrance and window rhythm, with the fence opening onto paths at their doors.
-- Stages without a plan keep the measured reference street (one long block a side) until the districts are built.
-- A house: { w (along the street), front (|x| of its facade), options for brickBuilding }; rows run from z' 0.
local PLANS = {
	[1] = {
		L = {
			{ 24, 40, edge = 'wall', { name = 'House12', roof = 'gable', h = 27, bays = 3, winW = 5.6, wall = P.st.brickDeep, chimney = { 20.5, -9 },
				entrance = { x = 12, kind = 'stoop', door = C(40, 110, 76), number = '12' } } },
			{ 32, 36, { name = 'House14', roof = 'hip', h = 30, pilasters = 2, chimney = { 8, -15 }, ac = { { 'front', 26, 16.4 } } } },
		},
		R = {
			{ 22, 40, edge = 'picket', { name = 'House15', roof = 'gableFront', h = 26, bays = 3, winW = 4.4, wall = P.st.brickLight,
				entrance = { x = 11, kind = 'porch', span = { 1, 21 }, door = C(36, 60, 110), number = '15' } } },
			{ 34, 38, { name = 'House17', roof = 'flat', h = 31, pilasters = 3, wall = P.st.brick:Lerp(P.st.brickDeep, 0.5), ac = { { 'front', 5.7, 16.4 } },
				entrance = { x = 28.33, kind = 'door', door = C(170, 50, 50), number = '17' } } },
		},
		-- fence gateways (z' ranges) and the paver paths from the sidewalk to the steps (x end, z' centre)
		gates = { L = { { 10.5, 13.5 } }, R = { { 9.5, 12.5 }, { 26.2, 29.2 } } },
		paths = { { -35.7, 12 }, { 34.6, 11 }, { 35.2, 27.7 } },
	},
	-- Stage 2: a porch house and a long hip-roofed terrace on the left; a flat-roofed house, a side yard (shed, washing
	-- line) and a gabled stoop house on the right. (Paths stay out of MECHANICS' backstops: left z' 22..47, right 13..24.)
	[2] = {
		L = {
			{ 20, 40, edge = 'picket', { name = 'House22', roof = 'gableFront', h = 27, bays = 2, winW = 5.4, wall = P.st.brickLight,
				entrance = { x = 10, kind = 'porch', span = { 1, 19 }, door = C(170, 50, 50), number = '22' } } },
			{ 36, 36, { name = 'House24', roof = 'hip', h = 30, pilasters = 3, chimney = { 26, -12 }, ac = { { 'front', 6, 16.4 } } } },
		},
		R = {
			{ 24, 38, { name = 'House21', roof = 'flat', h = 29, bays = 2, winW = 7, wall = P.st.brickDeep,
				entrance = { x = 18, kind = 'door', door = C(36, 60, 110), number = '21' } } },
			{ 10, yard = true },
			{ 22, 41, edge = 'wall', { name = 'House25', roof = 'gable', h = 28, bays = 2, winW = 6, chimney = { 4, -8 },
				entrance = { x = 6, kind = 'stoop', door = C(40, 110, 76), number = '25' } } },
		},
		gates = { L = { { 8.5, 11.5 } }, R = { { 4.5, 7.5 }, { 48.5, 51.5 } } },
		paths = { { -34.6, 10 }, { 35.2, 6 }, { 36.7, 50 } },
	},
	-- Stage 3: a three-storey flat-roofed block and a chimneyed stoop house on the left; a front-gabled porch house, a
	-- side yard and a hip-roofed door house on the right.
	[3] = {
		L = {
			{ 28, 36, { name = 'House32', roof = 'flat', floors = 3, pilasters = 3, wall = P.st.brick:Lerp(P.st.brickDeep, 0.4), ac = { { 'front', 5, 31.4 } } } },
			{ 28, 41, edge = 'wall', { name = 'House34', roof = 'gable', h = 28, bays = 3, winW = 5, chimney = { 6, -9 }, wall = P.st.brickDeep,
				entrance = { x = 21, kind = 'stoop', door = C(130, 60, 160), number = '34' } } },
		},
		R = {
			{ 18, 40, edge = 'picket', { name = 'House31', roof = 'gableFront', h = 26, bays = 2, winW = 4.6, wall = P.st.brickLight,
				entrance = { x = 9, kind = 'porch', span = { 1, 17 }, door = C(40, 110, 76), number = '31' } } },
			{ 12, yard = true },
			{ 26, 38, { name = 'House35', roof = 'hip', h = 30, pilasters = 2, entrance = { x = 6, kind = 'door', door = C(200, 140, 40), number = '35' } } },
		},
		gates = { L = { { 47.5, 50.5 } }, R = { { 7.5, 10.5 }, { 48.5, 51.5 } } },
		paths = { { -36.7, 49 }, { 34.6, 9 }, { 35.2, 50 } },
	},
}
-- A side yard (between two houses, open to the street over a low picket fence): grass, a plank shed with a sloped
-- roof, a washing line with clothes, a small tree and a kettle grill, closed at the back by a tall wall.
local function sideYard(d, s, za, w, top, seed)
	local ST = P.street
	sbox(d, 'SideYard', V(s * FRONT, -1, za - w), V(s * 64, ST.kerb, za), P.st.grass)
	sbox(d, 'YardWall', V(s * 64, -1, za - w), V(s * 65.6, 14, za), P.st.brickDark)
	sbox(d, 'YardWallCoping', V(s * 63.7, 14, za - w), V(s * 65.9, 14.6, za), P.st.trim, true)
	local mz = za - w / 2
	local shed = d:at(CFrame.new(s * 58, ST.kerb, mz)):group('Shed')
	sbox(shed, 'ShedBody', V(-3.5, 0, -3), V(3.5, 6.4, 3), C(150, 110, 70))
	for z = -2.4, 2.5, 1.2 do decor(shed:box('ShedPlank', V(-s * 3.5 - 0.05, 0.2, z - 0.06), V(-s * 3.5 + s * 0.05, 6.2, z + 0.06), C(118, 84, 52), M.Plastic)) end
	sbox(shed, 'ShedDoor', V(-s * 3.5 - 0.1, 0, -1.2), V(-s * 3.5 + s * 0.1, 5.2, 1.2), C(110, 78, 48), true)
	studs(shed:wedge('ShedRoof', V(w - 3, 1.6, 8.4), CFrame.new(0, 7.2, 0) * CFrame.Angles(0, s > 0 and -math.pi / 2 or math.pi / 2, 0), P.st.roofDark, M.Plastic), true)
	for _, z in { za - 2, za - w + 2 } do
		sbox(d, 'LinePost', V(s * 44 - 0.25, ST.kerb, z - 0.25), V(s * 44 + 0.25, ST.kerb + 7, z + 0.25), C(200, 204, 210), true)
	end
	decor(d:box('WashLine', V(s * 44 - 0.06, ST.kerb + 6.6, za - w + 2), V(s * 44 + 0.06, ST.kerb + 6.72, za - 2), C(240, 240, 240), M.Plastic))
	local cloth = { C(240, 90, 90), C(80, 160, 240), P.white, C(250, 210, 60) }
	for k = 1, math.floor((w - 4) / 2.2) do
		local cz = za - 2 - k * 2.0
		decor(d:box('Laundry', V(s * 44 - 0.08, ST.kerb + 4.2 + (k % 2) * 0.6, cz - 0.8), V(s * 44 + 0.08, ST.kerb + 6.6, cz + 0.8), cloth[k % #cloth + 1], M.Plastic))
	end
	tree(d, V(s * 51, ST.kerb, za - w + 3), seed, 0.7)
	local grill = d:at(CFrame.new(s * 40, ST.kerb, mz)):group('Grill')
	for _, a in { 0, 2.1, 4.2 } do decor(grill:box('GrillLeg', V(math.cos(a) * 0.6 - 0.1, 0, math.sin(a) * 0.6 - 0.1), V(math.cos(a) * 0.6 + 0.1, 2.2, math.sin(a) * 0.6 + 0.1), C(30, 32, 36), M.Plastic)) end
	decor(grill:part('GrillBowl', V(1.8, 1.4, 1.8), CFrame.new(0, 2.7, 0), C(30, 32, 36), M.Plastic, Enum.PartType.Ball))
end
-- A house frame like lotFrame, with the facade at |x| = front.
local function houseFrame(ctx, s, za, w, front)
	if s < 0 then return ctx:at(CFrame.lookAt(V(-front, 0, za), V(-front - 1, 0, za))) end
	return ctx:at(CFrame.lookAt(V(front, 0, za - w), V(front + 1, 0, za - w)))
end
-- A porch bench (seat, back, legs) and a terracotta pot with a cube plant, for doorsteps.
local function porchBench(c, cf)
	local b = c:at(cf):group('Bench')
	sbox(b, 'BenchSeat', V(-2.4, 1.4, -0.7), V(2.4, 1.8, 0.7), C(150, 104, 66))
	sbox(b, 'BenchBack', V(-2.4, 1.8, 0.4), V(2.4, 3.4, 0.7), C(150, 104, 66))
	for _, x in { -2.0, 2.0 } do sbox(b, 'BenchLeg', V(x - 0.25, 0, -0.6), V(x + 0.25, 1.4, 0.6), P.iron, true) end
	return b
end
local function plantPot(c, pos, seed)
	local p = c:at(CFrame.new(pos)):group('PlantPot')
	sbox(p, 'Pot', V(-0.8, 0, -0.8), V(0.8, 1.3, 0.8), C(196, 104, 66))
	sbox(p, 'PotRim', V(-0.95, 1.1, -0.95), V(0.95, 1.4, 0.95), C(170, 86, 54), true)
	sbox(p, 'Plant', V(-0.7, 1.4, -0.7), V(0.7, 2.6 + (seed % 2) * 0.6, 0.7), P.st.leaf, true)
	return p
end

---------------------------------------------------------------------------------------------- districts
-- The district family (brief 15 section 5): every look keeps the street's cross-section, so the walk, GATES' gates
-- and MECHANICS' target bands (the sidewalks, and the grass strip |x| 16.5..19 at z' 13..47) work everywhere, and
-- changes what stands beside it, in the same studded kit: The Block (1-3, houses), Corner Shop (4-6, a T-junction
-- with a corner store), The Alley (7-9, tall walls, fire escapes, a sky bridge), The Courts (10-12, a fenced court on
-- the right), The Yards (13-15, a warehouse dock and a container yard). Open ground beside the street is closed by a
-- tall wall at |x| 64 so the walk can't go round a gate. z' = studs past the stage's gate (map z = gateZ - z').
local District = {}

-- The stage group with its (hidden) fight marker; at(x, z') is a point on the grass/sidewalk level.
function District.base(ctx, i)
	local top = stageTop(i)
	local d = ctx:group('Stage' .. i)
	local pad = fightPad(d, i, V(0, 0, padZ(i)), P.padRed, lookOf(i), nil, nil, true)
	pad:SetAttribute('Stage', i)
	return d, top, function(x, zp) return V(x, P.street.kerb, top - zp) end
end
-- Flat studded ground (paving, a court, an apron) between |x| xa..xb on side s and z' za..zb, its top at y.
function District.floor(d, top, s, xa, xb, za, zb, y, color, name)
	return sbox(d, name or 'Paving', V(s * xa, y - 1.4, top - za), V(s * xb, y, top - zb), color)
end
-- A tall brick boundary wall along Z at |x| x (stone coping, darker plinth), closing open ground beside the street.
function District.backWall(d, top, s, x, za, zb, h)
	h = h or 14
	sbox(d, 'BackWall', V(s * x, -1, top - za), V(s * (x + 1.6), h, top - zb), P.st.brickDark)
	sbox(d, 'BackWallPlinth', V(s * (x - 0.3), -1, top - za), V(s * (x + 1.9), 1.6, top - zb), P.st.brickDark:Lerp(P.black, 0.15), true)
	sbox(d, 'BackWallCoping', V(s * (x - 0.3), h, top - za), V(s * (x + 1.9), h + 0.6, top - zb), P.st.trim, true)
end
-- Zebra stripes: n bars, each a x b studs, from p stepping by step (all in the stage frame), white studded paint.
function District.zebra(d, p, a, b, step, n)
	for k = 0, n - 1 do
		local q = p + step * k
		decor(sbox(d, 'Zebra', q - V(a / 2, 0.05, b / 2), q + V(a / 2, 0.14, b / 2), C(240, 240, 236))).CastShadow = false
	end
end
-- Traffic light: a navy pole with a collar, an arm over the road and a yellow three-lamp head facing +Z (the way the
-- player comes), red lit. dir = the arm's direction (+1 or -1 in x).
function District.trafficLight(d, pos, dir)
	local t = d:at(CFrame.new(pos)):group('TrafficLight')
	local col = P.st.lamp
	sbox(t, 'SignalBase', V(-1.2, 0, -1.2), V(1.2, 1.2, 1.2), P.st.lampDark)
	sbox(t, 'SignalPole', V(-0.6, 1.2, -0.6), V(0.6, 17, 0.6), col)
	sbox(t, 'SignalArm', V(math.min(0, dir * 9), 15.6, -0.4), V(math.max(0, dir * 9), 16.4, 0.4), col, true)
	for _, hx in { dir * 1.6, dir * 8 } do
		local h = t:at(CFrame.new(hx, 0, 0))
		sbox(h, 'SignalHead', V(-0.9, 10.6 + (hx == dir * 1.6 and 0 or 2.6), -0.6), V(0.9, 15.4 + (hx == dir * 1.6 and 0 or 0.2), 0.6), C(240, 196, 40), true)
		local y0 = 10.6 + (hx == dir * 1.6 and 0 or 2.6)
		for k, c3 in { C(255, 60, 50), C(80, 70, 40), C(50, 70, 50) } do
			local lamp = decor(h:box('SignalLamp', V(-0.55, y0 + 4.8 - k * 1.5 - 0.15, 0.6), V(0.55, y0 + 4.8 - k * 1.5 + 0.95, 0.75), c3, k == 1 and M.Neon or M.Plastic))
			lamp.CastShadow = false
			decor(h:box('SignalHood', V(-0.65, y0 + 4.8 - k * 1.5 + 0.95, 0.6), V(0.65, y0 + 4.8 - k * 1.5 + 1.15, 1.2), C(30, 32, 38), M.Plastic))
		end
	end
	return t
end
-- Stop sign on a short pole: red octagon look (a square and a turned square), white border, facing +Z.
function District.stopSign(d, pos)
	local t = d:at(CFrame.new(pos)):group('StopSign')
	sbox(t, 'SignPole', V(-0.25, 0, -0.25), V(0.25, 8, 0.25), C(150, 154, 162))
	local face = sbox(t, 'StopFace', V(-1.3, 8, 0.25), V(1.3, 10.6, 0.5), C(220, 40, 40), true)
	decor(t:part('StopFace', V(2.6, 2.6, 0.24), CFrame.new(0, 9.3, 0.37) * CFrame.Angles(0, 0, math.rad(45)), C(220, 40, 40), M.Plastic))
	line(surface(face, Enum.NormalId.Back, 30), 'Stop', 'STOP', P.white, FONT.title, 0.28, 0.44)
	return t
end
-- Ice chest outside a shop: a white studded box with a blue lid and handle bar.
function District.iceBox(d, cf)
	local t = d:at(cf):group('IceBox')
	local body = sbox(t, 'IceBox', V(-2.4, 0, -1.2), V(2.4, 3.2, 1.2), C(236, 240, 246))
	sbox(t, 'IceLid', V(-2.5, 3.2, -1.3), V(2.5, 3.7, 1.3), C(40, 110, 220))
	sbox(t, 'IceHandle', V(-1, 3.7, -0.15), V(1, 4.0, 0.15), C(30, 60, 140), true)
	line(surface(body, Enum.NormalId.Front, 30), 'Ice', 'ICE', C(40, 110, 220), FONT.loud, 0.2, 0.6)
	return t
end
-- Bike rack: a low steel rail on feet with two loops, one or two bikes in it. Along local X.
function District.bikeRack(d, cf, bikes)
	local t = d:at(cf):group('BikeRack')
	sbox(t, 'RackRail', V(-3, 0, -0.2), V(3, 0.4, 0.2), C(150, 154, 162))
	for _, x in { -2.2, 0, 2.2 } do
		decor(t:box('RackLoop', V(x - 0.15, 0.4, -0.15), V(x + 0.15, 2.6, 0.15), C(170, 174, 182), M.Plastic))
		decor(t:box('RackLoopTop', V(x - 0.15, 2.6, -0.8), V(x + 0.15, 2.9, 0.8), C(170, 174, 182), M.Plastic))
	end
	for k = 1, bikes or 1 do bike(t, CFrame.new(-1.1 + (k - 1) * 2.2, 0, 0.6) * CFrame.Angles(0, math.rad(90), 0), ({ C(60, 140, 240), C(240, 90, 60) })[k]) end
	return t
end
-- Newspaper box: a small blue studded box on legs with a window.
function District.newsBox(d, cf, color)
	local t = d:at(cf):group('NewsBox')
	for _, x in { -0.8, 0.8 } do sbox(t, 'NewsLeg', V(x - 0.15, 0, -0.6), V(x + 0.15, 1.2, 0.6), P.iron, true) end
	sbox(t, 'NewsBody', V(-1.1, 1.2, -0.8), V(1.1, 4.2, 0.8), color or C(40, 90, 200))
	sbox(t, 'NewsWindow', V(-0.8, 2.6, -0.9), V(0.8, 3.8, -0.8), P.st.glassB, true)
	return t
end
-- A parked car in the studded kit: a two-tone body, glass band, darker skirt, four black wheels (front = local -Z).
function District.car(d, cf, color)
	local k = d:at(cf):group('ParkedCar')
	local dark = color:Lerp(P.black, 0.3)
	for _, x in { -2.2, 2.2 } do
		for _, z in { -3.3, 3.3 } do decor(k:part('Wheel', V(0.9, 2.1, 2.1), CFrame.new(x, 1.05, z) * CFrame.Angles(0, 0, 0), C(30, 32, 36), M.Plastic, Enum.PartType.Cylinder)) end
	end
	sbox(k, 'CarSkirt', V(-2.3, 0.7, -5.2), V(2.3, 1.6, 5.2), dark)
	sbox(k, 'CarBody', V(-2.3, 1.6, -5.2), V(2.3, 3.0, 5.2), color)
	sbox(k, 'CarCabin', V(-2.0, 3.0, -2.2), V(2.0, 4.8, 2.8), color)
	sbox(k, 'CarGlass', V(-2.05, 3.2, -2.25), V(2.05, 4.5, 2.85), P.st.glassA, true)
	sbox(k, 'CarRoof', V(-2.1, 4.8, -2.0), V(2.1, 5.1, 2.6), dark, true)
	for _, x in { -1.6, 1.6 } do
		decor(k:box('Headlight', V(x - 0.5, 2.0, -5.3), V(x + 0.5, 2.6, -5.2), C(255, 244, 200), M.Plastic))
		decor(k:box('TailLight', V(x - 0.5, 2.0, 5.2), V(x + 0.5, 2.6, 5.3), C(220, 40, 40), M.Plastic))
	end
	return k
end

-- Corner Shop (stages 4-6): a T-junction on the right with a corner store on one corner (shopfronts on both streets,
-- produce, an ice chest, a bike rack), shops with flats above down the left, zebra crossings, a traffic light and a
-- stop sign, the side street closing at a fence and a parked car.
District.SHOPS = {
	{ sign = 'BARBER', color = C(40, 80, 180), stripes = { C(220, 50, 50), P.white, C(40, 80, 180), P.white } },
	{ sign = 'PIZZA', color = C(200, 46, 40), stripes = { C(200, 46, 40), P.white }, text = C(255, 222, 80) },
	{ sign = 'LAUNDRY', color = C(60, 150, 200), stripes = { C(60, 150, 200), P.white } },
	{ sign = 'SNEAKERS', color = C(36, 36, 44), stripes = { C(36, 36, 44), C(240, 240, 240) } },
	{ sign = 'DELI', color = C(40, 130, 70), stripes = { C(40, 130, 70), C(250, 220, 90) } },
	{ sign = 'PHONES', color = C(130, 60, 200), stripes = { C(130, 60, 200), P.white } },
}
function District.corner(ctx, i)
	local d, top, at = District.base(ctx, i)
	local ST = P.street
	local t = trioOf(i)
	local sa = ({ 28, 30, 27 })[t] -- the side street from z' sa to sa + 18, always on the right
	local sb = sa + 18
	local storeNear = t ~= 2
	-- Left: three shops with flats above, fronts at |x| 26 behind a paved forecourt.
	District.floor(d, top, -1, ST.road + ST.walk, 26, 0, 56, ST.kerb + 0.08, P.st.walk:Lerp(P.white, 0.08), 'Forecourt')
	local lw = ({ { 20, 20, 16 }, { 16, 22, 18 }, { 22, 16, 18 } })[t]
	local z = top
	for k = 1, 3 do
		local sh = District.SHOPS[(i + k) % #District.SHOPS + 1]
		local w = lw[k]
		local floors = (k + t) % 3 == 0 and 3 or 2
		brickBuilding(houseFrame(d, -1, z, w, 26), w, { name = 'Shop' .. k, floors = floors, depth = 38, roof = ({ 'flat', 'gable', 'hip' })[(k + t) % 3 + 1],
			wall = ({ P.st.brick, P.st.brickDeep, P.st.brickLight })[(k + i) % 3 + 1], bays = 2, winW = w / 2 - 4.6,
			shops = { { x0 = 1.6, x1 = w - 1.6, door = w - 4, sign = sh.sign, color = sh.color, stripes = sh.stripes, text = sh.text } } })
		z -= w
	end
	-- Right: the corner store, the side street, the far corner shop.
	local function rightBuilding(z0, z1, store, corner)
		local w = z1 - z0 -- (z0 < z1: z' runs away from the gate)
		local sh = store and { sign = 'CORNER STORE', color = C(30, 120, 60), stripes = { C(30, 120, 60), C(250, 214, 60) } } or District.SHOPS[(i + 4) % #District.SHOPS + 1]
		-- (right side: local x runs back up the street, so the side street side is 'left' for the near corner, 'right'
		-- for the far one)
		local shops = { { x0 = 1.6, x1 = w - 1.6, door = corner == 'left' and 4 or w - 4, sign = sh.sign, color = sh.color, stripes = sh.stripes, text = sh.text } }
		-- (the side face's local x runs from the back to the street on the 'left' face, from the street back on 'right')
		local near = corner == 'left' and function(a) return 40 - a end or function(a) return a end
		if store then table.insert(shops, { face = corner, x0 = math.min(near(3), near(18)), x1 = math.max(near(3), near(18)), door = near(15), sign = '24/7', color = sh.color, stripes = sh.stripes }) end
		brickBuilding(houseFrame(d, 1, top - z0, w, 24), w, { name = store and 'CornerStore' or 'CornerShop', floors = store and 2 or 3, roof = 'flat',
			wall = store and P.st.brickLight or P.st.brick, bays = 2, winW = w / 2 - 4.6, shops = shops, depth = 40,
			windows = (function()
				local list = { { face = 'front', x = w * 0.25, w = w / 2 - 4.6 }, { face = 'front', x = w * 0.75, w = w / 2 - 4.6 } }
				if store then table.insert(list, { face = corner, x = near(10.5), w = 12 }); table.insert(list, { face = corner, x = near(29), w = 12 }) end
				return list
			end)() })
	end
	District.floor(d, top, 1, ST.road + ST.walk, 24, 0, sa, ST.kerb + 0.08, P.st.walk:Lerp(P.white, 0.08), 'Forecourt')
	District.floor(d, top, 1, ST.road + ST.walk, 24, sb, 56, ST.kerb + 0.08, P.st.walk:Lerp(P.white, 0.08), 'Forecourt')
	rightBuilding(0, sa, storeNear, 'left')
	rightBuilding(sb, 56, not storeNear, 'right')
	-- The side street: asphalt at sidewalk level between two narrow sidewalks with kerb stones, a zebra across its
	-- mouth, a fence and barriers at its dead end, the back wall behind, a parked car.
	local rx = ST.road + ST.walk
	District.floor(d, top, 1, rx, 62, sa + 3.4, sb - 3.4, ST.kerb + 0.05, P.st.road, 'SideRoad')
	for _, e in { { sa, sa + 3 }, { sb - 3, sb } } do
		District.floor(d, top, 1, rx, 62, e[1], e[2], ST.kerb + 0.3, P.st.walk, 'SideWalk')
		local kz = e[1] == sa and sa + 3 or sb - 3.4
		District.floor(d, top, 1, rx, 62, kz, kz + 0.4, ST.kerb + 0.36, P.st.kerbStone, 'SideKerb')
	end
	District.zebra(d, V(19.6, ST.kerb + 0.05, top - (sa + 3.4) - 1.2), 4, 1, V(0, 0, -2), 5)
	District.zebra(d, V(-7, 0, top - (sa - 4)), 1.4, 5, V(2, 0, 0), 8)
	decor(sbox(d, 'StopLine', V(-8.4, -0.05, top - (sa - 7.3)), V(8.4, 0.14, top - (sa - 6.7)), C(240, 240, 236))).CastShadow = false
	chainLink(d, V(58, ST.kerb, top - sa), V(58, ST.kerb, top - sb), 12)
	for k = 0, 2 do
		local bz = top - (sa + 4.5 + k * 4.5)
		sbox(d, 'Barrier', V(54.6, ST.kerb, bz - 1.9), V(56.4, ST.kerb + 3, bz + 1.9), C(206, 208, 214))
		for q = 0, 1 do sbox(d, 'BarrierStripe', V(54.5, ST.kerb + 1.2 + q * 1.2, bz - 1.95), V(56.5, ST.kerb + 1.8 + q * 1.2, bz + 1.95), C(220, 50, 50), true) end
	end
	District.backWall(d, top, 1, 62.4, sa, sb)
	District.car(d, CFrame.new(at(38, sa + 6.6)) * CFrame.Angles(0, math.rad(storeNear and 90 or -90), 0), ({ C(250, 200, 40), C(230, 230, 236), C(52, 110, 220) })[t])
	-- Corner furniture: the traffic light on the near corner, a stop sign facing the side street, a lamp a side.
	District.trafficLight(d, at(17.2, sa - 1.2), -1)
	District.stopSign(d, at(19.8, sb + 1.2))
	lantern(d, at(-20.5, 12), V(1, 0, 0))
	lantern(d, at(21, 9), V(-1, 0, 0))
	hydrant(d, at(-20.2, 51))
	-- The store's front: produce on pallets under the awning, the ice chest, a bike rack, a news box (clear of the
	-- targets' backstop on the right grass, x 17.8..19, z' 13..23.5).
	storeCrates(d, CFrame.new(at(22.2, storeNear and 7 or sb + 9)) * CFrame.Angles(0, math.rad(90), 0), 2)
	District.iceBox(d, CFrame.lookAt(at(22, storeNear and 24.8 or sb + 4), at(10, storeNear and 24.8 or sb + 4)))
	District.bikeRack(d, CFrame.new(at(26, sa + 1.4)) * CFrame.Angles(0, 0, 0), 2)
	District.newsBox(d, CFrame.lookAt(at(21.6, storeNear and 3.6 or sb + 2.4), at(10, storeNear and 3.6 or sb + 2.4)))
	-- Left shop props: a bench and bins, out of the left target band (z' 22..48 by the sidewalk).
	trashBags(d, CFrame.new(at(-24, 8)) * CFrame.Angles(0, 0.6, 0), 2)
	wheelieBin(d, CFrame.new(at(-24.4, 16)) * CFrame.Angles(0, math.pi, 0), C(40, 90, 160))
	storeCrates(d, CFrame.new(at(-23, 51)) * CFrame.Angles(0, math.rad(90), 0), 1)
	endBuilding(d, -1, top - ST.endZ, top - SLEN, { wall = P.st.brickDeep, roof = 'flat', floors = 3 })
	endBuilding(d, 1, top - ST.endZ, top - SLEN, { wall = P.st.brick, roof = 'flat', floors = 3 })
	-- street: a manhole and a drain
	decor(sbox(d, 'Manhole', V(-3.4, -0.2, top - 14 - 1.2), V(-1.0, 0.08, top - 14 + 1.2), P.st.manhole)).CastShadow = false
	return d
end

-- The Alley (stages 7-9): tall brick walls close in to |x| 20 on both sides (three and four storeys, flat roofs),
-- fire escapes, a glazed sky bridge across the alley, cables strung with bulbs overhead, service recesses with a
-- dumpster and a back door, wall lamps, bins along a paved gutter strip, puddles on the asphalt.
function District.alley(ctx, i)
	local d, top, at = District.base(ctx, i)
	local ST = P.street
	local t = trioOf(i)
	local F = 20 -- the facades
	District.floor(d, top, -1, ST.road + ST.walk, F + 0.2, 0, 56, ST.kerb + 0.08, P.st.walk:Lerp(P.black, 0.12), 'AlleyEdge')
	District.floor(d, top, 1, ST.road + ST.walk, F + 0.2, 0, 56, ST.kerb + 0.08, P.st.walk:Lerp(P.black, 0.12), 'AlleyEdge')
	for _, s in { -1, 1 } do
		decor(sbox(d, 'GutterChannel', V(s * (ST.road + ST.walk), ST.kerb + 0.02, top), V(s * (ST.road + ST.walk + 0.7), ST.kerb + 0.1, top - 56), P.st.roadDark)).CastShadow = false
	end
	-- Each side: a tall block, a service recess (a one-storey back building 10 further back), another block.
	local plan = ({
		{ L = { { 0, 14, 4 }, { 14, 24, 'recess' }, { 24, 56, 3 } }, R = { { 0, 30, 3 }, { 30, 40, 'recess' }, { 40, 56, 4 } }, esc = { L = 1, R = 3 } },
		{ L = { { 0, 20, 3 }, { 20, 30, 'recess' }, { 30, 56, 4 } }, R = { { 0, 26, 4 }, { 26, 36, 'recess' }, { 36, 56, 3 } }, esc = { L = 3, R = 1 } },
		{ L = { { 0, 12, 3 }, { 12, 22, 'recess' }, { 22, 56, 4 } }, R = { { 0, 34, 4 }, { 34, 44, 'recess' }, { 44, 56, 3 } }, esc = { L = 3, R = 1 } },
	})[t]
	local walls = { P.st.brickDeep, P.st.brickDark:Lerp(P.st.brick, 0.5), P.st.brick, P.st.brickLight }
	local TAGS = { { 'HOOD', C(255, 96, 206) }, { '+1', C(70, 220, 255) }, { 'BLOCK', C(255, 222, 60) }, { 'GG', C(120, 240, 90) } }
	for _, s in { -1, 1 } do
		local side = s < 0 and 'L' or 'R'
		for k, b in plan[side] do
			local z0, z1 = b[1], b[2]
			local w = z1 - z0
			local za = top - z0
			if b[3] == 'recess' then
				-- the recess: paved, a one-storey back building with a door, a dumpster and bags
				District.floor(d, top, s, F, F + 10.2, z0, z1, ST.kerb + 0.08, P.st.walk:Lerp(P.black, 0.18), 'RecessFloor')
				brickBuilding(houseFrame(d, s, za, w, F + 10), w, { name = 'BackBuilding', floors = 1, h = 13, roof = 'flat', depth = 34, wall = P.st.brickDark,
					windows = {}, entrance = { x = w / 2, kind = 'door', door = C(70, 76, 90), number = tostring(20 + i) } })
				-- (turned to run along the back wall, its front toward the way the player comes)
				dumpster(d, CFrame.new(V(s * (F + 5.2), ST.kerb + 0.08, top - (z0 + 3.4))) * CFrame.Angles(0, math.rad(90), 0))
				trashBags(d, CFrame.new(V(s * (F + 5.6), ST.kerb + 0.08, top - (z0 + 7.8))), 3)
			else
				local floors = b[3]
				local esc = plan.esc[side] == k
				local wall = walls[(k + i + (s > 0 and 1 or 0)) % #walls + 1]
				local tag = TAGS[(i + k) % #TAGS + 1]
				local n = math.max(2, math.floor(w / 8))
				-- (local x runs down the street on the left, back up it on the right)
				local function lx(zp) return s < 0 and zp - z0 or z1 - zp end
				local doorZ = s < 0 and (z0 < 20 and z0 + 5 or z1 - 4) or (z1 > 26 and z1 - 4 or z0 + 4)
				local okDoor = not (s < 0 and doorZ > 21 and doorZ < 48) and not (s > 0 and doorZ > 12 and doorZ < 25)
				brickBuilding(houseFrame(d, s, za, w, F), w, { name = 'AlleyBlock', floors = floors, roof = 'flat', depth = 44, wall = wall, bays = n, winW = math.min(6, w / n - 3),
					fireEscapes = esc and { { x = w / 2, w = math.min(12, w - 4) } } or nil,
					entrance = okDoor and { x = lx(doorZ), kind = 'door', door = C(60, 66, 80), number = tostring(i * 10 + k) } or nil,
					ac = { { 'front', w * 0.3, 16.5 }, floors > 3 and { 'front', w * 0.7, 31.5 } or nil },
					tags = k == 1 and { { 'front', w * 0.5, 9.6, tag[1], tag[2] } } or nil })
			end
		end
	end
	-- The sky bridge: a glazed brick link across the alley at the second floor, a stone sill and slate roof.
	local bz = ({ 32, 22, 40 })[t]
	local bridge = d:group('SkyBridge')
	local y0, y1 = 21, 30
	sbox(bridge, 'BridgeFloor', V(-F, y0 - 1.2, top - bz), V(F, y0, top - (bz + 8)), P.st.trim)
	sbox(bridge, 'BridgeWall', V(-F, y0, top - bz - 0.2), V(F, y0 + 2.4, top - (bz + 7.8)), walls[(i % 4) + 1])
	sbox(bridge, 'BridgeWall', V(-F, y1 - 1.6, top - bz - 0.2), V(F, y1, top - (bz + 7.8)), walls[(i % 4) + 1])
	for _, zf in { bz + 0.25, bz + 7.75 } do
		sbox(bridge, 'BridgeGlass', V(-F, y0 + 2.4, top - zf - 0.15), V(F, y1 - 1.6, top - zf + 0.15), P.st.glassA, true)
		for x = -F + 4, F - 3, 4 do sbox(bridge, 'BridgeMullion', V(x - 0.35, y0 + 2.4, top - zf - 0.3), V(x + 0.35, y1 - 1.6, top - zf + 0.3), P.st.mullion, true) end
	end
	sbox(bridge, 'BridgeRoof', V(-F, y1, top - bz + 0.6), V(F, y1 + 0.8, top - (bz + 8.6)), P.st.roofDark)
	sbox(bridge, 'BridgeFascia', V(-F, y1 - 0.2, top - bz + 0.7), V(F, y1 + 1.0, top - bz + 0.3), P.st.trim, true)
	for _, s in { -1, 1 } do
		decor(bridge:bar('BridgeBrace', V(s * F, y0 - 5, top - bz - 1), V(s * (F - 4), y0 - 1.2, top - bz - 1), 0.6, C(46, 50, 60), M.Plastic))
		decor(bridge:bar('BridgeBrace', V(s * F, y0 - 5, top - bz - 7), V(s * (F - 4), y0 - 1.2, top - bz - 7), 0.6, C(46, 50, 60), M.Plastic))
	end
	-- Two pipes across at the top, on brackets.
	local pz = ({ 12, 46, 14 })[t]
	for k, py in { 41, 42.4 } do
		decor(d:rod('Pipe', 0.5, 2 * F, CFrame.new(0, py, top - pz - k * 1.3), k == 1 and C(150, 154, 162) or C(196, 120, 60), M.Plastic))
	end
	-- Cables with bulbs, sagging from wall to wall.
	for k, cz in ipairs(({ { 6, 10, 36 }, { 8, 34, 48 }, { 4, 26, 50 } })[t]) do
		local yA, yB, sag = 38 - k * 3, 37 - k * 3, 2.4
		local a, b = V(-F, yA, top - cz), V(F, yB, top - cz - 5)
		local mid = (a + b) / 2 - V(0, sag, 0)
		decor(d:bar('Cable', a, mid, 0.15, C(30, 32, 38), M.Plastic))
		decor(d:bar('Cable', mid, b, 0.15, C(30, 32, 38), M.Plastic))
		for q = 1, 9 do
			local u = q / 10
			local p = u < 0.5 and a:Lerp(mid, u * 2) or mid:Lerp(b, (u - 0.5) * 2)
			local bulb = decor(d:box('Bulb', p - V(0.3, 0.75, 0.3), p - V(-0.3, 0.15, -0.3), ({ C(255, 214, 120), C(255, 120, 160), C(120, 220, 255) })[q % 3 + 1], M.Neon))
			bulb.CastShadow = false
		end
	end
	-- Wall lamps on brackets, bins along the gutter strip (clear of the targets' backstops), puddles.
	for k, lp in ipairs({ { -1, 10 }, { 1, 8 }, { -1, 50 }, { 1, 44 } }) do
		local s, zp = lp[1], lp[2]
		local base = V(s * F, 13, top - zp)
		local arm = sbox(d, 'WallLampArm', base + V(-s * 0, 0, -0.2), base + V(-s * 1.8, 0.4, 0.2), C(46, 50, 60), true)
		sbox(d, 'WallLampHead', base + V(-s * 1.2, -1.0, -0.6), base + V(-s * 2.4, 0.2, 0.6), C(46, 50, 60), true)
		decor(d:box('WallLampGlow', base + V(-s * 1.35, -1.2, -0.45), base + V(-s * 2.25, -1.0, 0.45), P.st.lampGlow, M.Neon)).CastShadow = false
	end
	for _, b in ipairs({ { -1, 4 }, { -1, 8 }, { 1, 30 }, { 1, 47 }, { -1, 51 } }) do
		wheelieBin(d, CFrame.new(V(b[1] * 18.4, ST.kerb + 0.08, top - b[2])) * CFrame.Angles(0, b[1] < 0 and math.pi or 0, 0), ({ C(40, 120, 70), C(40, 90, 160), C(70, 74, 84) })[(b[2] + i) % 3 + 1])
	end
	for _, pd in ipairs({ { -3, 18, 4, 3 }, { 4, 37, 3, 5 }, { -5, 50, 3, 2.5 } }) do
		decor(d:box('Puddle', V(pd[1] - pd[3] / 2, -0.05, top - pd[2] - pd[4] / 2), V(pd[1] + pd[3] / 2, 0.06, top - pd[2] + pd[4] / 2), C(70, 90, 120), M.Glass)).Transparency = 0.3
	end
	endBuilding(d, -1, top - ST.endZ, top - SLEN, { wall = P.st.brickDark:Lerp(P.st.brick, 0.5), roof = 'flat', floors = 4 })
	endBuilding(d, 1, top - ST.endZ, top - SLEN, { wall = P.st.brickDeep, roof = 'flat', floors = 4 })
	return d
end

-- Basketball hoop on a frame whose +Z faces the court: a padded post, an arm, a white backboard with a red square,
-- an orange rim and a white net.
function District.hoop(d, cf, sideMount)
	local h = d:at(cf):group('Hoop')
	if not sideMount then -- (P3: a side-mounted hoop hangs from an arm over the court: no pole in the walk)
		sbox(h, 'HoopBase', V(-1.2, 0, -1.2), V(1.2, 1, 1.2), C(46, 50, 60))
		sbox(h, 'HoopPost', V(-0.5, 1, -0.5), V(0.5, 11.5, 0.5), C(60, 66, 80))
		sbox(h, 'HoopPad', V(-0.8, 1, -0.8), V(0.8, 5, 0.8), C(40, 90, 200), true)
	end
	sbox(h, 'HoopArm', V(-0.35, 10.6, 0), V(0.35, 11.2, 2.6), C(60, 66, 80), true)
	sbox(h, 'Backboard', V(-3, 9.2, 2.6), V(3, 13, 3), P.white, true)
	decor(h:box('BoardSquare', V(-1.1, 9.9, 3), V(1.1, 11.3, 3.1), C(220, 60, 50), M.Plastic))
	for q = 0, 7 do
		local a = q / 8 * math.pi * 2
		decor(h:part('Rim', V(0.8, 0.15, 0.18), CFrame.new(math.cos(a) * 0.95, 9.6, 4.1 + math.sin(a) * 0.95) * CFrame.Angles(0, -a + math.pi / 2, 0), C(240, 110, 40), M.Plastic))
		decor(h:bar('Net', V(math.cos(a) * 0.9, 9.55, 4.1 + math.sin(a) * 0.9), V(math.cos(a) * 0.5, 8.4, 4.1 + math.sin(a) * 0.5), 0.08, P.white, M.Plastic))
	end
	return h
end
-- Floodlight pole: a dark base, a tall pole and a head of four lamps turned toward the court (-Z of the frame, as
-- CFrame.lookAt aims it).
function District.floodlight(d, cf, h)
	h = h or 26
	local f = d:at(cf):group('Floodlight')
	sbox(f, 'FloodBase', V(-1.2, 0, -1.2), V(1.2, 1.2, 1.2), C(46, 50, 60))
	sbox(f, 'FloodPole', V(-0.5, 1.2, -0.5), V(0.5, h, 0.5), C(150, 156, 166))
	sbox(f, 'FloodFrame', V(-2.6, h, -0.6), V(2.6, h + 3, 0.6), C(60, 66, 80), true)
	for _, x in { -1.3, 1.3 } do for _, y in { h + 0.75, h + 2.25 } do
		decor(f:box('FloodLamp', V(x - 1, y - 0.6, -0.8), V(x + 1, y + 0.6, -0.6), C(250, 248, 230), M.Neon)).CastShadow = false
	end end
	return f
end
-- Bleachers along Z on side s: three studded aluminium tiers stepping up away from the court (x0 = the front edge),
-- blue seat boards and a back rail.
function District.bleachers(d, top, s, x0, za, zb)
	local g = d:group('Bleachers')
	for k = 0, 2 do
		local xa, xb = x0 + k * 1.8, x0 + 6
		sbox(g, 'BleacherTier', V(s * xa, P.street.kerb, top - za), V(s * xb, P.street.kerb + 1.4 * (k + 1), top - zb), C(186, 192, 204))
		sbox(g, 'BleacherSeat', V(s * (xa + 0.2), P.street.kerb + 1.4 * (k + 1), top - za - 0.3), V(s * (xa + 1.2), P.street.kerb + 1.4 * (k + 1) + 0.4, top - zb + 0.3), C(40, 90, 200), true)
	end
	decor(g:box('BleacherRail', V(s * (x0 + 5.8), P.street.kerb + 6.6, top - za), V(s * (x0 + 6), P.street.kerb + 6.9, top - zb), C(150, 156, 166), M.Plastic))
	for z = za, zb, (zb - za) / 4 do decor(g:box('BleacherRailPost', V(s * (x0 + 5.8), P.street.kerb + 4.2, top - z - 0.1), V(s * (x0 + 6), P.street.kerb + 6.6, top - z + 0.1), C(150, 156, 166), M.Plastic)) end
	return g
end

-- The Courts (stages 10-12): the right side opens onto a fenced basketball court (hoops, lines, bleachers, benches,
-- floodlights, a mural wall behind), an apartment block with balconies on the left, trees on its grass.
District.COURTS = {
	{ court = C(226, 120, 52), key = C(196, 92, 40), ground = C(60, 128, 92) },
	{ court = C(52, 112, 210), key = C(36, 86, 170), ground = C(84, 92, 110) },
	{ court = C(196, 60, 60), key = C(160, 44, 44), ground = C(46, 70, 120) },
}
function District.courts(ctx, i)
	local d, top, at = District.base(ctx, i)
	local ST = P.street
	local t = trioOf(i)
	local K = District.COURTS[t]
	-- Left: apartments with balconies (three storeys), a front garden strip with trees.
	local lw = ({ { 30, 26 }, { 24, 32 }, { 28, 28 } })[t]
	local z = top
	District.floor(d, top, -1, FRONT, 40, 0, 56, ST.kerb, P.st.grass, 'Yard')
	for k = 1, 2 do
		local w = lw[k]
		brickBuilding(houseFrame(d, -1, z, w, 40), w, { name = 'Apartments', floors = 3, roof = k == 1 and 'flat' or 'hip', pilasters = math.max(2, math.floor(w / 10)),
			wall = ({ P.st.brickLight, P.st.brick, P.st.brickDeep })[(k + t) % 3 + 1], depth = 24,
			balconies = { { x = w / 2, w = 8 } }, entrance = { x = k == 1 and 5 or w - 5, kind = 'stoop', door = ({ C(40, 110, 76), C(36, 60, 110), C(170, 50, 50) })[(k + t) % 3 + 1], number = tostring(100 + i * 2 + k) } })
		z -= w
	end
	-- the plank fence opens at both stoops, with paver paths across the grass
	fence(d, -ST.fence, top, top - ST.endZ, 1, nil, { { top - 3.2, top - 6.8 }, { top - 49.2, top - 52.8 } })
	for _, zc in { 5, 51 } do
		for x = ST.road + ST.walk, 34.4, 2 do sbox(d, 'Paver', V(-x, ST.kerb - 0.3, top - zc + 1.5), V(-math.min(x + 1.9, 34.5), ST.kerb + 0.07, top - zc - 1.5), (x // 2) % 2 == 0 and P.st.kerbStone or P.st.sill) end
	end
	for k, zp in ipairs({ 9, 30, 52 }) do tree(d, at(-26.5, zp), i * 100 + k, 0.95, 20 + k * 25) end
	lantern(d, at(-20.5, 15), V(1, 0, 0))
	-- Right: the apron beside the street, where the players' tunnel stands (the fenced yard below).
	local x0, x1, za, zb = 22, 62.4, 3, 55
	District.floor(d, top, 1, ST.road + ST.walk, x1, 0, 56, ST.kerb + 0.08, K.ground, 'CourtGround')
	-- THE COURT IS THE STREET (P3, BRIEF29, the user: "make some of the stages a basketball court, without it being on the
	-- side, as soon as you step in it's a basketball court"): a full court laid over the road and both sidewalks, sideline to
	-- sideline (x +-15, z' 6..58) with its out-of-bounds border, the key and the free-throw circle at each end, the three-point
	-- arc, the half-court line and the centre circle round the fight spot (z' 32). The hoops hang from arms off the left
	-- side so no pole stands in the walk from gate to gate. Layers (tops): sidewalk 0.6, border 0.66, court 0.72, key 0.76,
	-- lines 0.80.
	local sl = ST.road + ST.walk -- 16.5, the sidewalks' outer edge
	local yb, yc, yk, yl = ST.kerb + 0.06, ST.kerb + 0.12, ST.kerb + 0.16, ST.kerb + 0.2
	sbox(d, 'CourtBorder', V(-sl, ST.kerb - 0.4, top - 4.5), V(sl, yb, top - 59.5), K.ground:Lerp(P.black, 0.12))
	sbox(d, 'Court', V(-15, ST.kerb - 0.3, top - 6), V(15, yc, top - 58), K.court)
	local function paint(a, b, y, color, w)
		local lo, hi = V(math.min(a.X, b.X), y - 0.04, math.min(top - a.Z, top - b.Z)), V(math.max(a.X, b.X), y, math.max(top - a.Z, top - b.Z))
		decor(d:box('CourtLine', lo, hi, color or P.white, M.Plastic)).CastShadow = false
	end
	local function mark(x0_, z0_, x1_, z1_) paint(V(x0_ - 0.2, 0, z0_ - 0.2), V(x1_ + 0.2, 0, z1_ + 0.2), yl, P.white) end
	mark(-15, 6, 15, 6); mark(-15, 58, 15, 58); mark(-15, 6, -15, 58); mark(15, 6, 15, 58); mark(-15, 32, 15, 32)
	for _, e in { { 6, 17.6 }, { 46.4, 58 } } do
		decor(d:box('CourtKey', V(-4.4, yc, top - e[2]), V(4.4, yk, top - e[1]), K.key, M.Plastic)).CastShadow = false
		mark(-4.4, e[1], -4.4, e[2]); mark(4.4, e[1], 4.4, e[2])
		mark(-4.4, e[1] == 6 and 17.6 or 46.4, 4.4, e[1] == 6 and 17.6 or 46.4)
	end
	local function arc(cx, cz, r, a0, a1, n)
		for q = 0, n - 1 do
			local t0, t1 = a0 + (a1 - a0) * q / n, a0 + (a1 - a0) * (q + 1) / n
			local p0 = V(cx + math.cos(t0) * r, yl - 0.02, top - (cz + math.sin(t0) * r))
			local p1 = V(cx + math.cos(t1) * r, yl - 0.02, top - (cz + math.sin(t1) * r))
			decor(d:part('CourtArc', V(0.4, 0.04, (p1 - p0).Magnitude + 0.05), CFrame.lookAt((p0 + p1) / 2, p1), P.white, M.Plastic)).CastShadow = false
		end
	end
	arc(0, 32, 3.6, 0, math.pi * 2, 14) -- the centre circle, round the fight spot
	arc(0, 17.6, 4.4, 0, math.pi, 8) -- the free-throw circles
	arc(0, 46.4, 4.4, math.pi, math.pi * 2, 8)
	arc(0, 8, 13, math.rad(14), math.rad(166), 14) -- the three-point arcs
	arc(0, 56, 13, math.rad(194), math.rad(346), 14)
	-- the hoops: the board and rim at each baseline on the centre line, hung from a long arm off a pole on the left grass
	for _, hp in { { 4, math.pi }, { 60, 0 } } do
		District.hoop(d, CFrame.new(at(0, hp[1])) * CFrame.Angles(0, hp[2], 0), true)
		sbox(d, 'HoopSideArm', V(-18.4, ST.kerb + 10.4, top - hp[1] - 0.35), V(0.35, ST.kerb + 11.0, top - hp[1] + 0.35), C(60, 66, 80), true)
		sbox(d, 'HoopSideBrace', V(-18.4, ST.kerb + 7.8, top - hp[1] - 0.2), V(-17.6, ST.kerb + 10.4, top - hp[1] + 0.2), C(60, 66, 80))
		sbox(d, 'HoopSideBase', V(-19.4, ST.kerb, top - hp[1] - 1.2), V(-17.0, ST.kerb + 1, top - hp[1] + 1.2), C(46, 50, 60))
		sbox(d, 'HoopSidePost', V(-18.9, ST.kerb + 1, top - hp[1] - 0.5), V(-17.9, ST.kerb + 11.2, top - hp[1] + 0.5), C(60, 66, 80))
		sbox(d, 'HoopSidePad', V(-19.3, ST.kerb + 1, top - hp[1] - 0.8), V(-17.5, ST.kerb + 5, top - hp[1] + 0.8), C(40, 90, 200), true)
	end
	-- The fence: chain-link round three sides with a gateway onto the grass, the back wall behind with a mural.
	chainLink(d, V(x0, ST.kerb, top - za), V(x0, ST.kerb, top - zb), 12, { { 23, 27.5 } })
	chainLink(d, V(x0, ST.kerb, top - za), V(x1 - 0.4, ST.kerb, top - za), 12)
	chainLink(d, V(x0, ST.kerb, top - zb), V(x1 - 0.4, ST.kerb, top - zb), 12)
	District.backWall(d, top, 1, x1, 0, 56, 16)
	local mural = ghost(d:box('Mural', V(x1 - 0.08, ST.kerb + 3, top - 14), V(x1 - 0.02, ST.kerb + 13, top - 42), P.white, M.SmoothPlastic))
	local g = surface(mural, Enum.NormalId.Left, 12)
	line(g, 'Mural', ({ 'HOOD BALLERS', 'GAME ON', 'NEXT UP' })[t], ({ C(255, 210, 60), C(255, 96, 206), C(70, 220, 255) })[t], FONT.tag, 0.1, 0.8, P.black, 4).Rotation = -4
	District.bleachers(d, top, 1, 23.4, 5, 20) -- (P3: behind the fence, watching the street court; clear of the gateway at z' 23..27.5)
	for _, bz in { 18, 46 } do
		local b = d:at(CFrame.lookAt(at(-18.4, bz), at(-8, bz))):group('TeamBench')
		sbox(b, 'BenchSeat', V(-3.5, 1.4, -0.7), V(3.5, 1.8, 0.7), C(40, 90, 200))
		for _, x in { -3, 3 } do sbox(b, 'BenchLeg', V(x - 0.25, 0, -0.6), V(x + 0.25, 1.4, 0.6), P.iron, true) end
	end
	for k, bp in ipairs({ { -9, 14 }, { 7.5, 44 }, { -3, 33 } }) do decor(d:part('Basketball', V(1.2, 1.2, 1.2), CFrame.new(at(bp[1], bp[2]) + V(0, 0.75, 0)), C(236, 112, 40), M.Plastic, Enum.PartType.Ball)) end
	sbox(d, 'WaterCooler', at(24.4, 44.4), at(25.8, 45.8) + V(0, 2.2, 0), C(40, 120, 220))
	-- (brief 29: the far-left one stands outside the fence now, clear of the players' tunnel)
	for _, fl in { { -19.6, 6 }, { 19.6, 6 }, { -19.6, 58 }, { 19.6, 58 } } do
		District.floodlight(d, CFrame.lookAt(at(fl[1], fl[2]), at(0, 32)), 26)
	end
	-- (brief 29) The players' tunnel in the court's far corner (PropModels 'CourtTunnel', built with BoxKit in Blender's
	-- kit), its mouth toward the gate: the court crew waits inside and jogs out as you walk in (EnemyRules.Courts: the
	-- mouth at x 26.6, z' 45.4; Waves.client draws the walk-out). Its walls are solid; the inside stays open.
	local props = Armory.optional('PropModels')
	local okT, tunnel = false, nil
	if props and props.build then okT, tunnel = pcall(props.build, 'CourtTunnel', 1) end
	if okT and tunnel and tunnel.PrimaryPart then
		tunnel.Name = 'PlayersTunnel'
		local goal = d:world(CFrame.new(at(26.6, 50.4) + V(0, 0.2, 0)) * CFrame.Angles(0, math.pi, 0))
		local delta = goal * tunnel.PrimaryPart.CFrame:Inverse()
		for _, p in tunnel:GetDescendants() do
			if p:IsA('BasePart') then
				p.CFrame = delta * p.CFrame
				p.Anchored, p.CanTouch, p.CanQuery = true, false, false
				p.CanCollide = p.Name == 'Wall' or p.Name == 'Back' or p.Name == 'Post'
			end
		end
		tunnel.Parent = d.parent
	end
	endBuilding(d, -1, top - ST.endZ, top - SLEN, { wall = P.st.brickLight, roof = 'hip', floors = 3 })
	endBuilding(d, 1, top - ST.endZ, top - SLEN, { name = 'Clubhouse', wall = P.st.brickDeep, roof = 'flat', floors = 1, h = 14 })
	return d
end

-- Corrugated metal shed on a lot frame (+Z out of the front): a darker plinth, the wall with a lighter rib every 2.6
-- studs along the front, a dark sign band, a low gable roof along the street with a ridge cap.
function District.shed(c, w, dep, H, color, sign)
	local g = c:group('Warehouse')
	local dark = color:Lerp(P.black, 0.3)
	sbox(g, 'ShedWall', V(0, -1, -dep), V(w, H, 0), color)
	sbox(g, 'ShedPlinth', V(-0.3, -1, -dep - 0.3), V(w + 0.3, 2.2, 0.3), dark)
	for x = 1.3, w - 1, 2.6 do decor(g:box('ShedRib', V(x - 0.4, 2.2, 0), V(x + 0.4, H - 2.6, 0.3), color:Lerp(P.white, 0.14), M.Plastic)) end
	local band = sbox(g, 'ShedBand', V(-0.3, H - 2.6, -dep - 0.3), V(w + 0.3, H, 0.4), dark)
	if sign then line(surface(band, Enum.NormalId.Back, 16), 'Sign', sign, P.white, FONT.loud, 0.1, 0.8, P.black, 3) end
	gableRoof(g, w, dep, H, dep * 0.18, 'x', color:Lerp(P.white, 0.2))
	return g
end
-- Shipping container in the studded kit (8 wide, 20 long along local Z, 8.6 tall): body, darker corner posts and top
-- rim, door end with locking bars.
function District.container(d, cf, color)
	local k = d:at(cf):group('Container')
	local dark = color:Lerp(P.black, 0.28)
	sbox(k, 'ContainerBody', V(-4, 0, -10), V(4, 8.6, 10), color)
	for _, x in { -4.2, 3.6 } do for _, z in { -10.2, 9.6 } do sbox(k, 'ContainerPost', V(x, 0, z), V(x + 0.6, 8.6, z + 0.6), dark, true) end end
	sbox(k, 'ContainerRim', V(-4.2, 8.2, -10.2), V(4.2, 8.8, 10.2), dark, true)
	for z = -7.5, 7.6, 3 do for _, x in { -4.15, 4.0 } do decor(k:box('ContainerRib', V(x, 0.4, z - 0.45), V(x + 0.15, 8.2, z + 0.45), color:Lerp(P.white, 0.1), M.Plastic)) end end
	for _, x in { -1.6, 1.6 } do decor(k:box('ContainerBar', V(x - 0.15, 0.6, 10), V(x + 0.15, 8, 10.25), dark, M.Plastic)) end
	return k
end
-- Forklift (front = local -Z): yellow body, a dark counterweight, the cab frame, mast and forks.
function District.forklift(d, cf)
	local k = d:at(cf):group('Forklift')
	local y = C(250, 196, 40)
	for _, x in { -1.6, 1.6 } do for _, z in { -1.6, 1.8 } do decor(k:part('Wheel', V(0.8, 1.6, 1.6), CFrame.new(x, 0.8, z), C(30, 32, 36), M.Plastic, Enum.PartType.Cylinder)) end end
	sbox(k, 'LiftBody', V(-1.6, 0.6, -2.2), V(1.6, 2.6, 2.6), y)
	sbox(k, 'LiftWeight', V(-1.7, 0.6, 2.2), V(1.7, 3.2, 3.2), C(46, 50, 60))
	sbox(k, 'LiftSeat', V(-0.8, 2.6, 0.4), V(0.8, 3.4, 1.8), C(30, 32, 36), true)
	for _, x in { -1.4, 1.4 } do
		decor(k:box('CabPost', V(x - 0.15, 2.6, -0.8), V(x + 0.15, 6.4, -0.5), C(30, 32, 36), M.Plastic))
		decor(k:box('CabPost', V(x - 0.15, 2.6, 2.0), V(x + 0.15, 6.4, 2.3), C(30, 32, 36), M.Plastic))
	end
	sbox(k, 'CabRoof', V(-1.6, 6.4, -0.9), V(1.6, 6.7, 2.4), C(30, 32, 36), true)
	sbox(k, 'Mast', V(-1.2, 0.6, -2.8), V(1.2, 7.2, -2.3), C(60, 66, 80), true)
	for _, x in { -0.8, 0.8 } do sbox(k, 'Fork', V(x - 0.2, 0.5, -5.6), V(x + 0.2, 0.8, -2.8), C(60, 66, 80), true) end
	return k
end

-- The Yards (stages 13-15): concrete aprons; a corrugated warehouse with a loading dock (bumpers, roll-up doors, a
-- canopy, stairs) on one side; a container yard behind chain-link with a sliding gate, stacks two high, a forklift
-- and pallets on the other; floodlights, drums and barriers.
function District.yards(ctx, i)
	local d, top, at = District.base(ctx, i)
	local ST = P.street
	local t = trioOf(i)
	local apron = C(196, 198, 202)
	for _, s in { -1, 1 } do District.floor(d, top, s, ST.road + ST.walk, 63, 0, 56, ST.kerb + 0.08, apron, 'Apron') end
	for _, st in ipairs({ { -22, 8, 3, 2 }, { -26, 32, 4, 3 }, { 20.5, 6, 2.5, 3 }, { 21, 40, 3, 2 }, { -21, 50, 2, 2.5 } }) do
		decor(sbox(d, 'OilStain', at(st[1] - st[3] / 2, st[2] - st[4] / 2) + V(0, 0.06, 0), at(st[1] + st[3] / 2, st[2] + st[4] / 2) + V(0, 0.11, 0), apron:Lerp(P.black, 0.35))).CastShadow = false
	end
	for _, s in { -1, 1 } do decor(sbox(d, 'LaneLine', V(s * 17.4, ST.kerb + 0.08, top), V(s * 17.9, ST.kerb + 0.13, top - 56), C(250, 204, 40))).CastShadow = false end
	-- Left: the warehouse and its dock.
	local wcol = ({ C(84, 118, 170), C(150, 156, 166), C(120, 140, 110) })[t]
	local wf = 30
	District.shed(houseFrame(d, -1, top - 2, 52, wf), 52, 34, 22, wcol, 'DEPOT ' .. i)
	District.floor(d, top, -1, wf - 0.2, 64, 0, 2, ST.kerb + 0.08, apron, 'Apron')
	District.backWall(d, top, -1, 64, 0, 2, 14)
	District.backWall(d, top, -1, 64, 54, 56, 14)
	local dz0, dz1 = 10, 44
	sbox(d, 'Dock', V(-wf, -1, top - dz0), V(-(wf - 5), 4.2, top - dz1), C(176, 178, 184))
	sbox(d, 'DockEdge', V(-(wf - 5) - 0.3, 3.8, top - dz0), V(-(wf - 5) + 0.3, 4.3, top - dz1), C(250, 204, 40), true)
	for zb = dz0 + 3, dz1 - 2, 6 do sbox(d, 'DockBumper', V(-(wf - 5) + 0.2, 1.4, top - zb - 0.7), V(-(wf - 5) - 0.6, 3.6, top - zb + 0.7), C(30, 32, 36), true) end
	for k, s in ipairs({ { dz1, dz1 + 1.1, 3.4 }, { dz1 + 1.1, dz1 + 2.2, 2.2 }, { dz1 + 2.2, dz1 + 3.3, 1.0 } }) do
		sbox(d, 'DockStep', V(-wf, -1, top - s[1]), V(-(wf - 3), s[3], top - s[2]), C(176, 178, 184))
	end
	for _, dzc in { 19, 35 } do
		sbox(d, 'RollDoorFrame', V(-wf + 0.2, 4.2, top - dzc - 6.6), V(-wf - 0.4, 16.6, top - dzc + 6.6), wcol:Lerp(P.black, 0.4))
		sbox(d, 'RollDoor', V(-wf + 0.35, 4.2, top - dzc - 5.8), V(-wf - 0.4, 15.8, top - dzc + 5.8), C(178, 184, 194))
		for yy = 5.4, 15, 1.2 do decor(d:box('DoorSlat', V(-wf + 0.45, yy, top - dzc - 5.8), V(-wf + 0.3, yy + 0.25, top - dzc + 5.8), C(130, 136, 148), M.Plastic)) end
	end
	-- a clerestory strip high on the front, lamps over the doors, an office door with its own canopy at the far end
	sbox(d, 'Clerestory', V(-wf + 0.15, 19.4, top - 4), V(-wf - 0.2, 22.2, top - 52), P.st.glassA, true)
	for zc = 4, 52, 4 do sbox(d, 'ClerestoryBar', V(-wf + 0.3, 19.4, top - zc - 0.3), V(-wf - 0.2, 22.2, top - zc + 0.3), wcol:Lerp(P.black, 0.4), true) end
	for _, dzc in { 19, 35 } do
		local lb = sbox(d, 'DoorLamp', V(-wf + 1.4, 17.0, top - dzc - 0.8), V(-wf, 17.4, top - dzc + 0.8), C(46, 50, 60), true)
		decor(d:box('DoorLampGlow', V(-wf + 1.3, 16.9, top - dzc - 0.6), V(-wf + 0.1, 17.0, top - dzc + 0.6), P.st.lampGlow, M.Neon)).CastShadow = false
	end
	sbox(d, 'OfficeDoor', V(-wf + 0.3, ST.kerb, top - 47.5), V(-wf - 0.2, ST.kerb + 7.6, top - 50.5), C(70, 76, 90))
	sbox(d, 'OfficeDoorFrame', V(-wf + 0.2, ST.kerb, top - 47), V(-wf - 0.2, ST.kerb + 8.2, top - 51), wcol:Lerp(P.black, 0.4))
	sbox(d, 'OfficeCanopy', V(-wf, ST.kerb + 9, top - 46.2), V(-wf + 2.6, ST.kerb + 9.5, top - 51.8), C(46, 50, 60), true)
	sbox(d, 'OfficeWindow', V(-wf + 0.2, ST.kerb + 3.4, top - 52.4), V(-wf - 0.2, ST.kerb + 7.2, top - 53.6), P.st.glassB, true)
	sbox(d, 'DockCanopy', V(-wf, 17.4, top - dz0 + 1), V(-(wf - 6.5), 18.2, top - dz1 - 1), wcol:Lerp(P.black, 0.25))
	for zb = dz0 + 2, dz1 - 1, 10 do decor(d:bar('CanopyBrace', V(-wf, 13.4, top - zb), V(-(wf - 6), 17.4, top - zb), 0.4, C(46, 50, 60), M.Plastic)) end
	pallet(d, CFrame.new(V(-(wf - 2), 4.2, top - 26)))
	crate(d, CFrame.new(V(-(wf - 2), 5.0, top - 26)) * CFrame.Angles(0, 0.2, 0), 2.6)
	for k, dp in ipairs({ { -21.5, 6 }, { -22.6, 7.6 }, { -21, 8.8 } }) do
		local drum = d:post('Drum', 1.1, 3.4, at(dp[1], dp[2]), ({ C(40, 90, 200), C(200, 50, 40), C(40, 90, 200) })[k], M.Plastic)
		studs(drum)
		decor(d:post('DrumRim', 1.18, 0.3, at(dp[1], dp[2]) + V(0, 3.2, 0), C(30, 32, 36), M.Plastic))
	end
	-- Right: the container yard.
	local fx = 23
	chainLink(d, V(fx, ST.kerb, top - 2), V(fx, ST.kerb, top - 54), 12, { { 20, 34 } })
	chainLink(d, V(fx, ST.kerb, top - 2), V(63, ST.kerb, top - 2), 12)
	chainLink(d, V(fx, ST.kerb, top - 54), V(63, ST.kerb, top - 54), 12)
	District.backWall(d, top, 1, 63, 0, 56, 14)
	-- the sliding gate, shut: a framed chain-link leaf on wheels across the gap, a sign
	local gate = d:group('YardGate')
	sbox(gate, 'GateFrame', V(fx - 0.2, ST.kerb + 0.6, top - 22), V(fx + 0.3, ST.kerb + 11.4, top - 36), C(150, 156, 166))
	local mesh = gate:box('GateMesh', V(fx - 0.25, ST.kerb + 1.2, top - 22.6), V(fx + 0.35, ST.kerb + 10.8, top - 35.4), C(70, 74, 82), M.DiamondPlate)
	mesh.Transparency = 0.45
	for _, gz in { 23, 35 } do decor(gate:part('GateWheel', V(0.5, 1.2, 1.2), CFrame.new(fx + 0.05, ST.kerb + 0.6, top - gz), C(30, 32, 36), M.Plastic, Enum.PartType.Cylinder)) end
	local sign = sbox(gate, 'YardSign', V(fx - 0.5, ST.kerb + 6, top - 26.5), V(fx - 0.3, ST.kerb + 8.6, top - 31.5), P.white, true)
	line(surface(sign, Enum.NormalId.Left, 30), 'Sign', 'YARD ' .. i, C(200, 40, 40), FONT.title, 0.12, 0.76)
	local colors = { C(196, 52, 42), C(44, 96, 186), C(46, 150, 90), C(232, 130, 40) }
	local rows = ({ { { 32, 3, 2 }, { 32, 30, 1 }, { 45, 5, 2 }, { 45, 31, 2 }, { 57, 4, 1 }, { 57, 30, 2 } },
		{ { 32, 4, 1 }, { 32, 30, 2 }, { 45, 4, 2 }, { 45, 30, 1 }, { 57, 4, 2 }, { 57, 30, 2 } },
		{ { 32, 3, 2 }, { 32, 30, 2 }, { 45, 5, 1 }, { 45, 31, 2 }, { 57, 4, 2 }, { 57, 30, 1 } } })[t]
	for k, r in ipairs(rows) do
		for lvl = 0, r[3] - 1 do
			District.container(d, CFrame.new(at(r[1], r[2] + 10.6) + V(0, -ST.kerb + ST.kerb + 0.08 + lvl * 8.7, 0)) * CFrame.Angles(0, math.rad((k * 3 + lvl * 2) % 5 - 2), 0), colors[(k + lvl + i) % #colors + 1])
		end
	end
	District.forklift(d, CFrame.new(at(38.5, 27.5) + V(0, 0.08, 0)) * CFrame.Angles(0, math.rad(70), 0))
	-- the gatehouse by the gate (inside), a stack of tyres, a second pallet stack
	local booth = d:at(CFrame.new(at(26.6, 41) + V(0, 0.08, 0))):group('Gatehouse')
	sbox(booth, 'BoothBase', V(-2.4, 0, -2.6), V(2.4, 1, 2.6), C(150, 156, 166))
	sbox(booth, 'BoothWall', V(-2.2, 1, -2.4), V(2.2, 3.4, 2.4), C(236, 238, 242))
	sbox(booth, 'BoothGlass', V(-2.25, 3.4, -2.45), V(2.25, 6.2, 2.45), P.st.glassA, true)
	for _, x in { -2.2, 1.9 } do for _, z in { -2.4, 2.1 } do sbox(booth, 'BoothPost', V(x, 3.4, z), V(x + 0.3, 6.2, z + 0.3), C(236, 238, 242), true) end end
	sbox(booth, 'BoothRoof', V(-2.8, 6.2, -3), V(2.8, 6.9, 3), C(46, 96, 186))
	for k = 0, 2 do decor(d:part('Tyre', V(1, 2.4, 2.4), CFrame.new(at(26.2, 51.5) + V(0, 0.6 + k * 1.0, 0)) * CFrame.Angles(0, 0, math.pi / 2), C(34, 36, 40), M.Plastic, Enum.PartType.Cylinder)) end
	for k = 0, 1 do
		pallet(d, CFrame.new(at(39, 52) + V(0, 0.08 + k * 0.8, 0)) * CFrame.Angles(0, k * 0.15, 0))
	end
	crate(d, CFrame.new(at(39, 52) + V(0, 1.68, 0)) * CFrame.Angles(0, 0.2, 0), 3)
	pallet(d, CFrame.new(at(25.6, 8) + V(0, 0.08, 0)) * CFrame.Angles(0, math.rad(90), 0))
	crate(d, CFrame.new(at(25.6, 8) + V(0, 0.88, 0)), 2.8)
	pallet(d, CFrame.new(at(25.6, 28) + V(0, 0.08, 0)) * CFrame.Angles(0, math.rad(90), 0))
	for k = 0, 2 do
		local bz = top - (4 + k * 4)
		sbox(d, 'Barrier', V(19.4, ST.kerb, bz - 1.8), V(21.2, ST.kerb + 3, bz + 1.8), C(206, 208, 214))
		sbox(d, 'BarrierStripe', V(19.3, ST.kerb + 1.6, bz - 1.85), V(21.3, ST.kerb + 2.2, bz + 1.85), C(250, 204, 40), true)
	end
	District.floodlight(d, CFrame.lookAt(at(-20.5, 14), at(0, 28)), 24)
	District.floodlight(d, CFrame.lookAt(at(26, 50), at(45, 28)), 26)
	endBuilding(d, -1, top - ST.endZ, top - SLEN, { wall = C(150, 156, 166), roof = 'flat', floors = 2 })
	endBuilding(d, 1, top - ST.endZ, top - SLEN, { wall = wcol, roof = 'flat', floors = 2 })
	return d
end

local function streetStage(ctx, i)
	local top = stageTop(i)
	local ST = P.street
	local d = ctx:group('Stage' .. i)
	-- The fight hook stays (V2.Fights, HoodFightPad) as an invisible marker: the picture's road has no pad.
	local pad = fightPad(d, i, V(0, 0, padZ(i)), P.padRed, lookOf(i), nil, nil, true)
	pad:SetAttribute('Stage', i)
	local zEnd = top - ST.endZ
	-- Hood touches on the long fronts: a window air-con box and a spray-painted tag above the fence, a different word
	-- each side and stage (kid-friendly ones).
	local TAGS = { { 'HOOD', C(255, 96, 206) }, { '+1', C(70, 220, 255) }, { 'BLOCK', C(255, 222, 60) }, { 'GG', C(120, 240, 90) } }
	local plan = PLANS[i]
	for _, s in { -1, 1 } do
		local tag = TAGS[(i * 2 + (s > 0 and 1 or 0)) % #TAGS + 1]
		local function lx(zp) return s < 0 and zp or ST.endZ - zp end -- (the lot runs along -Z on the left, +Z on the right)
		local gaps = {}
		if plan then
			local z = top
			for _, g in plan.gates[s < 0 and 'L' or 'R'] do table.insert(gaps, { top - g[1], top - g[2] }) end
			for _, h in plan[s < 0 and 'L' or 'R'] do
				if h.yard then
					sideYard(d, s, z, h[1], top, i * 100 + 77)
					picketFence(d, s * ST.fence, z, z - h[1], -s)
					z -= h[1]
					continue
				end
				brickBuilding(houseFrame(d, s, z, h[1], h[2]), h[1], h[3])
				-- the yard in front of a set-back house
				if h[2] > FRONT then sbox(d, 'Yard', V(s * FRONT, -1, z - h[1]), V(s * h[2], ST.kerb, z), P.st.grass) end
				-- its boundary: the tall plank fence of the picture, a low picket fence or a brick garden wall
				local mine = {}
				for _, g in gaps do if math.min(g[1], g[2]) < z and math.max(g[1], g[2]) > z - h[1] then table.insert(mine, g) end end
				if h.edge == 'picket' then picketFence(d, s * ST.fence, z, z - h[1], -s, mine)
				elseif h.edge == 'wall' then gardenWall(d, s * ST.fence, z, z - h[1], -s, mine)
				else fence(d, s * ST.fence, z, z - h[1], -s, nil, mine) end
				z -= h[1]
			end
		else
			sideRow(d, s, top, { { ST.endZ, function(f, w) brickBuilding(f, w, { bays = 2, ac = { { 'front', lx(s < 0 and 18 or 46), 16.4 } }, tags = { { 'front', lx(28), 9.9, tag[1], tag[2] } } }) end } })
		end
		endBuilding(d, s, zEnd, top - SLEN)
		if not plan then fence(d, s * ST.fence, top, zEnd, -s) end
	end
	-- Paver paths from the sidewalk to each gateway's steps: 3 wide, studded slabs in two stone tones.
	for _, pth in plan and plan.paths or {} do
		local s, x1, zc = math.sign(pth[1]), math.abs(pth[1]), top - pth[2]
		local k = 0
		for x = ST.road + ST.walk, x1 - 0.01, 2 do
			k += 1
			sbox(d, 'Paver', V(s * x, ST.kerb - 0.3, zc - 1.5), V(s * math.min(x + 1.9, x1), ST.kerb + 0.07, zc + 1.5), k % 2 == 0 and P.st.kerbStone or P.st.sill)
		end
	end
	local seed = i * 100
	local function at(x, zp) return V(x, ST.kerb, top - zp) end
	-- Dressing keeps off the paver paths (and their 1.5-stud margins): free(x, z', r) is false where an item of
	-- radius r would stand on one.
	local function free(x, zp, r)
		for _, pth in plan and plan.paths or {} do
			if math.sign(pth[1]) == math.sign(x) and math.abs(x) - r < math.abs(pth[1]) and math.abs(zp - pth[2]) < 1.5 + r + 0.5 then return false end
		end
		return true
	end
	-- Left, near to far: hedge, lamp, the big tree, the far tree, a hedge and the second lamp by the end building.
	if free(-27, 5, 3) then hedge(d, plan and at(-27, 5) or at(-25, 14), plan and 5 or 6) end
	lantern(d, at(-20, 19), V(1, 0, 0))
	tree(d, at(-24.5, 28.5), seed + 1, 1, 38)
	if free(-23.8, 45, 3.2) then tree(d, at(-23.8, 45), seed + 2, 0.85, 20) end
	if free(-23, 51, 2.2) then hedge(d, at(-23, 51), 4) end
	-- (the far lamps stand out at |x| 25.5, clear of the line from the street to GATES' gate pillars)
	lantern(d, at(-25.5, 53.5), V(1, 0, 0))
	-- Right: open grass with a flower, the low hedge, the lamp (with its street sign) and the dumpster behind it.
	if free(25.8, 34, 3.2) then hedge(d, at(25.8, 34), 6) end
	local lamp = lantern(d, at(25.5, 50), V(-1, 0, 0))
	local sign = sbox(lamp, 'StreetSign', V(0.9, 17.4, -2.4), V(1.2, 19.0, -0.2), C(40, 150, 70), true)
	for _, face in { Enum.NormalId.Right, Enum.NormalId.Left } do line(surface(sign, face, 30), 'Street', 'HOOD ST', P.white, FONT.title, 0.18, 0.64) end
	if free(31, 50.5, 4.5) then dumpster(d, CFrame.new(at(31, 50.5)))
	elseif free(31, 41, 4.5) then dumpster(d, CFrame.new(at(31, 41))) end
	for k, f in { { 20.6, 17.5 }, { 24, 41 }, { -21, 40 }, { -20, 34 }, { -29.8, 24 }, { 20.8, 62.5 } } do if free(f[1], f[2], 1.2) then flower(d, at(f[1], f[2]), seed + 10 + k) end end
	for k, t in { { -33, 33.5 }, { -31.8, 35 }, { -32.5, 30 }, { 22.8, 38 }, { 21, 50 }, { -18, 57.5 } } do if free(t[1], t[2], 1) then tuft(d, at(t[1], t[2]), seed + 20 + k) end end
	-- The grass in two greens: darker clumps where the picture's grass is shaded or worn.
	for _, g in { { -28, plan and 18 or 10, 3, 5 }, { -30.5, 38, 2.5, 4 }, { -19.5, 44, 2, 3 }, { -31, 22, 2, 3 }, { 28, plan and 18 or 12, 4, 3 }, { 22, plan and 33 or 28, 2.5, 4 }, { 31, plan and 22 or 25, 2, 3 }, { 26.5, 44, 3, 2.5 } } do
		local p = at(g[1], g[2])
		if not free(g[1], g[2], math.max(g[3], g[4]) / 2) then continue end
		decor(sbox(d, 'GrassClump', p + V(-g[3] / 2, -0.2, -g[4] / 2), p + V(g[3] / 2, 0.05, g[4] / 2), P.st.grassDark)).CastShadow = false
	end
	-- Street furniture in the road: a manhole and two kerb drains (dark grates in lighter frames).
	local mh = V(3.6, 0, top - 31)
	decor(sbox(d, 'ManholeRim', mh + V(-1.5, -0.2, -1.5), mh + V(1.5, 0.05, 1.5), P.st.manhole)).CastShadow = false
	decor(sbox(d, 'Manhole', mh + V(-1.1, -0.2, -1.1), mh + V(1.1, 0.08, 1.1), P.st.manhole:Lerp(P.white, 0.12))).CastShadow = false
	for _, dr in { { -1, 15 }, { 1, 42 } } do
		local p = V(dr[1] * (ST.road - 0.65), 0, top - dr[2])
		decor(sbox(d, 'DrainFrame', p + V(-0.55, -0.2, -1.4), p + V(0.55, 0.06, 1.4), P.st.kerbStone:Lerp(P.black, 0.25))).CastShadow = false
		decor(sbox(d, 'DrainGrate', p + V(-0.35, -0.2, -1.15), p + V(0.35, 0.08, 1.15), C(34, 38, 46))).CastShadow = false
	end
	-- Hood prop clusters at the sides, never on the walk: bags and a wheelie bin by the dumpster; a crate with a
	-- boombox on it by the left end building; a hydrant on the right before the gate.
	if free(28.4, 44, 2.5) then trashBags(d, CFrame.new(at(28.4, 44)) * CFrame.Angles(0, 0.4, 0), 3) end
	if free(31.9, 41.4, 1.8) then wheelieBin(d, CFrame.new(at(31.9, 41.4))) end
	crate(d, CFrame.new(at(-19.8, 55)) * CFrame.Angles(0, 0.2, 0), 2.6)
	boombox(d, CFrame.new(at(-19.8, 55) + V(0, 2.6, 0)) * CFrame.Angles(0, math.rad(-70), 0))
	hydrant(d, at(19.6, 54.5))
	-- Right, by the near fence: a bike parked against it and corner-store produce crates on a pallet.
	local bz = plan and 16.5 or 13.5
	if not free(32.4, bz, 2.4) then bz = 30 end
	if free(32.4, bz, 2.4) then bike(d, CFrame.new(at(32.4, bz)) * CFrame.Angles(0, math.pi, 0), ({ C(230, 60, 60), C(60, 140, 240), C(250, 200, 40) })[i % 3 + 1]) end
	if i == 1 then
		-- The porch house: a bench on the porch and pots by its steps; pots on the stoop's cheek walls.
		porchBench(d, CFrame.lookAt(V(38.2, ST.kerb + 1.0, top - 18), V(30, ST.kerb + 1.0, top - 18)))
		for _, zp in { 7.4, 14.6 } do plantPot(d, V(37.2, ST.kerb + 1.0, top - zp), zp) end
		for _, zp in { 8.4, 15.6 } do plantPot(d, V(-36.4, ST.kerb + 3.1, top - zp), zp) end
		-- No. 12's front garden behind its wall: soil beds with flowers either side of the stoop, a clipped bush.
		for k, b in { { 1.5, 7.2 }, { 16.8, 22.5 } } do
			decor(sbox(d, 'FlowerBed', V(-39.9, ST.kerb - 0.2, top - b[1]), V(-37.4, ST.kerb + 0.25, top - b[2]), C(110, 84, 64))).CastShadow = false
			for q = 0, 2 do flower(d, V(-38.6, ST.kerb + 0.2, top - (b[1] + 1 + q * 2)), seed + 40 + k * 3 + q) end
		end
		hedge(d, V(-36.8, ST.kerb, top - 20), 3)
	elseif free(30.8, 20.5, 2.6) then
		storeCrates(d, CFrame.new(at(30.8, 20.5)) * CFrame.Angles(0, 0.1, 0), 3)
	end
	-- Left, by the fence between the trees: a junk corner of a chain-link panel, a tagged board leaning on it and a
	-- pallet with a crate.
	if free(-31, 40, 4) then
		chainLink(d, at(-32.9, 36.6), at(-32.9, 43.4), 7)
		local tag2 = TAGS[(i + 2) % #TAGS + 1]
		graffitiBoard(d, CFrame.lookAt(at(-31.7, 40), at(-31.7, 40) + V(1, 0, 0)), tag2[1], tag2[2])
		pallet(d, CFrame.new(at(-29.6, 42.8)) * CFrame.Angles(0, 0.3, 0))
		crate(d, CFrame.new(at(-29.6, 42.8) + V(0, 0.8, 0)) * CFrame.Angles(0, 0.5, 0), 2.4)
	end
	-- A darker repair patch in the asphalt.
	decor(sbox(d, 'RoadPatch', V(-5.6, -0.2, top - 47), V(-2.2, 0.03, top - 41.5), P.st.roadDark)).CastShadow = false
	-- Stage 1: brick wings between the warehouse wall and the gate line, so its wall is the only way through.
	if i == 1 then
		for _, s in { -1, 1 } do
			-- (out to |x| 40: the set-back houses' yards must not open onto the hall's grass)
			brickBuilding(d:at(CFrame.new(s < 0 and -40 or ST.open, 0, Lobby.N - 1)), 40 - ST.open, { name = 'GateWing', depth = Lobby.N - 1, h = ST.eave + 2, run = 1.5, rise = 1.5, windows = {}, gutters = {} })
		end
	end
	return d
end

---------------------------------------------------------------------------------------------- boss yard
-- The warehouse on the left, containers on the right, the Champ Ring in the middle (the last training
-- spot) and the boss pad under its sign at the far end, between the Boss's two pads.
local function bossYard(ctx)
	-- (brief 29, P3b) the Harbor Crew's warehouse (code5/f4_finale: no ring), and the World Boss pier and board
	if V2.Finale then
		local yard = V2.Finale.yard(ctx)
		if V2.feature('WorldBoss') then -- (Oct 27: the World Boss is a later update; Config/Features)
			V2.Finale.arena(ctx)
			V2.Finale.board(ctx)
		end
		return yard
	end
	local b = ctx:group('BossYard')
	b:box('YardSlab', V(-FRONT, 0, BOSS_END), V(FRONT, 0.06, BOSS_TOP - 4), C(176, 178, 184), M.Concrete)
	sideRow(b, -1, BOSS_TOP, {
		{ 56, function(f, w) warehouse(f, w) end },
		{ 40, function(f, w) brickBuilding(f, w, { wall = P.warehouse:Lerp(P.black, 0.1), bays = 2 }) end },
	})
	sideRow(b, 1, BOSS_TOP, { { 96, function(f, w) containerLot(f, w, 3) end } })
	car(b, CFrame.new(-26, 0, BOSS_TOP - 70) * CFrame.Angles(0, math.rad(80), 0), P.white)
	local ring = SKINS.StationById.Ring
	local ringCtx, ringModel = b:at(CFrame.new(0, 0, BOSS_TOP - 34) * CFrame.Angles(0, math.pi, 0)):group('Training_' .. ring.Id)
	Props.ring(ringCtx, PROPS_KIT, ring, 7)
	-- The champion aura (tier 9) on the canvas, like the stations along the way.
	local canvas = ringModel:FindFirstChild('TrainingZone')
	local vfx = Armory.optional('HoodVFX')
	if canvas and vfx then vfx.station(canvas, 9, nil, V(14, 12, 14)) end
	local bz = BOSS_END + 22
	-- (brief 30: no BOSS pad, ring or banner: the last stage's strongest is just a strong enemy; the pad marker stays hidden)
	fightPad(b, 16, V(0, 0, bz), P.padRed, 6, 14, nil, true)
	-- (brief 23) The stage's pads: beat its crew, then cash out here like before every gate (stage 16's Cash).
	GATE.pads(b, 16, 15, bz - 7, 0.06, 5.6, 11)
	for x = -30, 30, 15 do tree(b, V(x, 0, BOSS_END + 4), 600 + x, 1) end
	return b
end

---------------------------------------------------------------------------------------------- the strong enemies' arenas
-- (brief 30, FIGHTS; bible 2.4 "The arena") Where a crew's strongest fights (the even stages: its name on the gate
-- sign), the street gets that crew's set dressing in the reference's layers: mid, clusters of 2-4 themed props hugging
-- the yards, the forecourts and the side street (never on the road or the pads' sidewalks: the middle stays clear);
-- back, a billboard or a water tower on a flat end-building roof over the gate. One theme a crew, nothing random. The
-- props are BoxKit models (Shared/Models/PropModels, hood/tools/blender/models/props.py), given the map kit's studs on
-- their big plastic tops. The generic props a theme replaces are taken out first (Arena.clear).
--   bullies (2)   Big Bully Brock's schoolyard: a school bus on the lawn, its stop arm out; a dodgeball cart; cones
--   crooks (4)    The Ringleader's getaway: the van in the side street, back doors open on money bags; a safe
--   muscle (6)    The Foreman's site: scaffold, cement mixer, barriers and cones across the side street
--   little (8)    Big Shot's alley show: speaker stacks in the service recesses
--   gangsters (10) Furcoat Frankie's corner: the purple lowrider, burning barrels, a card table
--   ballers (12)  Court King's court: ball racks at the sidelines
--   dockhands (14) The Dockmaster's yard edge: drums, bollards, rope coils, cones and tyres
local Arena = {}
Arena.Crews = { [2] = 'bullies', [4] = 'crooks', [6] = 'muscle', [8] = 'little', [10] = 'gangsters', [12] = 'ballers', [14] = 'dockhands' }
Arena.Signs = { -- the crew's sign on the end building's front and its bunting's two colours
	bullies = { 'RECESS RULES', C(255, 196, 32), C(232, 48, 52) }, crooks = { 'CASH 4 GOLD', C(92, 214, 110), C(255, 206, 64) },
	muscle = { 'BUILD IT BIG', C(255, 140, 40), C(250, 204, 40) }, little = { 'BIG SHOT LIVE', C(196, 110, 255), C(70, 220, 255) },
	gangsters = { "FRANKIE'S", C(255, 120, 200), C(150, 70, 220) }, ballers = { 'COURT KINGS', C(255, 150, 40), C(40, 90, 200) },
	dockhands = { 'HARBOR FREIGHT', C(80, 170, 255), C(250, 204, 40) },
}
-- A BoxKit prop at pos (this ctx's frame) turned yaw about Y, anchored; solid: its visible parts collide.
function Arena.prop(c, id, pos, yaw, scale, solid)
	local props = Armory.optional('PropModels')
	local ok, m = false, nil
	if props and props.build then ok, m = pcall(props.build, id, scale or 1) end
	if not ok or not m or not m.PrimaryPart then return nil end
	local delta = c:world(CFrame.new(pos) * CFrame.Angles(0, yaw or 0, 0)) * m.PrimaryPart.CFrame:Inverse()
	for _, p in m:GetDescendants() do
		if p:IsA('BasePart') then
			p.CFrame = delta * p.CFrame
			p.Anchored, p.CanTouch, p.CanQuery = true, false, false
			p.CanCollide = solid == true and p.Transparency < 1
			-- (brief 30, the lead: no stud textures on props until the LOOK agent's recipe lands; smooth toy tops)
			if p:IsA('Part') then p.TopSurface = S.Smooth end
		end
	end
	m.Parent = c.parent
	return m
end
-- The generic props (models named in `names`) standing in a box of the stage (|x| side s from xa to xb, z' za..zb).
function Arena.clear(stage, top, names, s, xa, xb, za, zb)
	for _, m in stage:GetChildren() do
		if m:IsA('Model') and names[m.Name] then
			local p = m:FindFirstChildWhichIsA('BasePart', true)
			if p then
				local q = V2.Origin:PointToObjectSpace(p.CFrame.Position)
				local x, zp = q.X * s, top - q.Z
				if x >= xa and x <= xb and zp >= za and zp <= zb then m:Destroy() end
			end
		end
	end
end
-- The back layer, framing the gate the crew waits at (the end buildings are too tall for anything on their roofs to show
-- from the street): the crew's sign on the left end building's front, lit, and a line of pennant bunting in the crew's
-- two colours strung across the street over the gate's beam.
function Arena.backdrop(d, top, crew)
	local sign = Arena.Signs[crew]
	if not sign then return end
	local ST = P.street
	local zf = top - ST.endZ -- (the end buildings' fronts face back up the street at z' 56)
	local x0 = -(ST.open + (FRONT - ST.open) / 2)
	local frameP = sbox(d, 'CrewSignFrame', V(x0 - 6.6, 13.4, zf + 0.05), V(x0 + 6.6, 18.6, zf + 0.45), C(30, 34, 46))
	local board = sbox(d, 'CrewSign', V(x0 - 6.1, 13.9, zf + 0.45), V(x0 + 6.1, 18.1, zf + 0.6), C(20, 24, 36), true)
	line(surface(board, Enum.NormalId.Back, 24), 'Sign', sign[1], sign[2], FONT.title, 0.14, 0.72, P.black, 4)
	for _, dx in { -4.5, 4.5 } do
		sbox(d, 'CrewSignLampArm', V(x0 + dx - 0.2, 18.6, zf + 0.4), V(x0 + dx + 0.2, 19.0, zf + 1.8), C(46, 50, 60), true)
		decor(d:box('CrewSignLamp', V(x0 + dx - 0.7, 18.3, zf + 1.4), V(x0 + dx + 0.7, 18.6, zf + 2.2), P.st.lampGlow, M.Neon)).CastShadow = false
	end
	local _ = frameP
	-- the bunting: a cord sagging from end building to end building, a pennant every 2 studs
	local zb, half, yTop, sag = zf + 2.2, ST.open - 0.4, 26.2, 2.6
	local function cordY(x) return yTop - sag * (1 - (x / half) ^ 2) end
	local prev = nil
	for x = -half, half + 0.01, half / 6 do
		local p = V(x, cordY(x), zb)
		if prev then decor(d:bar('BuntingCord', prev, p, 0.12, C(40, 40, 46), M.Plastic)).CastShadow = false end
		prev = p
	end
	local k = 0
	for x = -half + 1.2, half - 1.2, 2 do
		k += 1
		local y = cordY(x)
		local flag = d:part('Pennant', V(1.15, 1.15, 0.12), CFrame.new(x, y - 0.55, zb) * CFrame.Angles(0, 0, math.rad(45)), k % 2 == 0 and sign[2] or sign[3], M.SmoothPlastic)
		decor(flag).CastShadow = false
	end
end
local GENERIC = { Hedge = true, TrashBags = true, WheelieBin = true, Dumpster = true, ParkedCar = true }
function Arena.dress(d, i)
	local crew = Arena.Crews[i]
	if not crew then return end
	local stage = d.parent
	local top = stageTop(i)
	local ST = P.street
	local function at(x, zp, y) return V(x, y or ST.kerb, top - zp) end
	local a = d:group('Arena')
	local t = trioOf(i)
	if crew == 'bullies' then
		Arena.clear(stage, top, GENERIC, 1, 19.5, 34.4, 20, 48)
		Arena.prop(a, 'SchoolBus', at(27.4, 35.2), 0, 1, true)
		Arena.prop(a, 'DodgeballCart', at(21.6, 46.6), math.rad(16), 1)
		for k, z in { 27, 30.5, 34 } do Arena.prop(a, 'TrafficCone', at(19.7 + (k % 2) * 0.3, z), k * 0.4, 1) end
		Arena.prop(a, 'DodgeballCart', at(-21.2, 50.8), math.rad(-12), 1)
		Arena.backdrop(a, top, crew)
	elseif crew == 'crooks' or crew == 'muscle' then
		local sa = ({ 28, 30, 27 })[t]
		local sb = sa + 18
		if crew == 'muscle' then Arena.clear(stage, top, GENERIC, 1, 20, 62, sa, sb) end
		if crew == 'crooks' then
			-- (on the left forecourt, nose to the gate, its back doors open toward you as you come down the street; the
			-- car in the side street stays)
			Arena.clear(stage, top, GENERIC, -1, 16.5, 27, 28, 52)
			Arena.prop(a, 'GetawayVan', at(-21.8, 40.2, ST.kerb + 0.08), 0, 1, true)
			Arena.prop(a, 'Safe', at(-19.6, 29.2, ST.kerb + 0.08), math.rad(160), 1, true)
			for k, mb in { { -21.4, 30.4 }, { -23.2, 31.4 }, { -18.9, 31.8 } } do Arena.prop(a, 'MoneyBag', at(mb[1], mb[2], ST.kerb + 1.1), k * 0.7, 1) end
			Arena.prop(a, 'TrafficCone', at(19.4, 49.6, ST.kerb + 0.08), 0.3, 1)
		else
			Arena.prop(a, 'Scaffold', at(33, sb - 2.2, ST.kerb + 0.05), math.pi, 1, true)
			Arena.prop(a, 'CementMixer', at(42.5, sa + 8, ST.kerb + 0.05), 0.7, 1, true)
			for _, bz in { sa + 6, sa + 11 } do Arena.prop(a, 'RoadBarrier', at(20.6, bz, ST.kerb + 0.05), math.pi / 2, 1, true) end
			for k, cz in { sa + 3.6, sb - 3.2, sa + 8.5 } do Arena.prop(a, 'TrafficCone', at(k == 3 and 24.2 or 18.6, cz), k * 0.5, 1) end
			Arena.prop(a, 'PalletStack', at(-22.6, 45.6), 0.12, 1, true)
			Arena.prop(a, 'Crate', at(-21.2, 49.6, ST.kerb + 1.3), 0.4, 1, true)
		end
		Arena.backdrop(a, top, crew)
	elseif crew == 'little' then
		local plan = ({ { 14, 24, 30, 40 }, { 20, 30, 26, 36 }, { 12, 22, 34, 44 } })[t]
		Arena.clear(stage, top, GENERIC, -1, 20, 31, plan[1], plan[2])
		Arena.clear(stage, top, GENERIC, 1, 20, 31, plan[3], plan[4])
		Arena.prop(a, 'SpeakerStack', at(-25.2, (plan[1] + plan[2]) / 2, ST.kerb + 0.08), math.pi / 2, 1, true)
		Arena.prop(a, 'SpeakerStack', at(25.2, (plan[3] + plan[4]) / 2, ST.kerb + 0.08), -math.pi / 2, 1, true)
		-- and the show at the alley's end, a stack each side against the walls, facing the street, where the crew waits
		Arena.clear(stage, top, { WheelieBin = true }, 1, 16, 21, 44, 56)
		Arena.clear(stage, top, { WheelieBin = true }, -1, 16, 21, 44, 56)
		Arena.prop(a, 'SpeakerStack', at(18.4, 50.5, ST.kerb + 0.08), -math.pi / 2, 0.8, true)
		Arena.prop(a, 'SpeakerStack', at(-18.4, 49.0, ST.kerb + 0.08), math.pi / 2, 0.8, true)
		Arena.backdrop(a, top, crew)
	elseif crew == 'gangsters' then
		Arena.prop(a, 'Lowrider', at(-27.6, 41.2), 0, 1, true)
		for _, fb in { { -20.6, 38.4 }, { -20.8, 52.2 }, { 19.8, 41.5 } } do Arena.prop(a, 'FireBarrel', at(fb[1], fb[2], fb[1] > 0 and ST.kerb + 0.08 or nil), fb[2] * 0.1, 1, true) end
		Arena.prop(a, 'CardTable', at(-23.4, 25.4), 0.25, 1, true)
		Arena.backdrop(a, top, crew)
	elseif crew == 'ballers' then
		Arena.prop(a, 'BallRack', at(19.6, 38.6, ST.kerb + 0.08), -math.pi / 2, 1, true)
		Arena.prop(a, 'BallRack', at(-19.8, 31.5), math.pi / 2, 1, true)
		Arena.prop(a, 'TrafficCone', at(19.4, 33.4, ST.kerb + 0.08), 0.4, 1)
		Arena.backdrop(a, top, crew)
	elseif crew == 'dockhands' then
		for k, br in { { -21.2, 46.6 }, { -22.8, 48.4 }, { -20.8, 49.8 } } do Arena.prop(a, 'Barrel', at(br[1], br[2], ST.kerb + 0.08 + 1.5), k * 0.8, 1, true) end
		Arena.prop(a, 'RopeCoil', at(-24.6, 51.6, ST.kerb + 0.08), 0.6, 1)
		for _, bz in { 42.6, 53.8 } do Arena.prop(a, 'Bollard', at(-19.6, bz, ST.kerb + 0.08), 0, 1, true) end
		for k, cz in { 45.6, 48.8 } do Arena.prop(a, 'TrafficCone', at(19.8 + k * 0.3, cz, ST.kerb + 0.08), k, 1) end
		Arena.prop(a, 'TireStack', at(21.2, 53.2, ST.kerb + 0.08), 0.3, 1)
		Arena.backdrop(a, top, crew)
	end
end

local function buildStages(ctx)
	local byLook = { streetStage, District.corner, District.alley, District.courts, District.yards }
	for i = 1, STAGES do
		local d = (byLook[lookOf(i)] or streetStage)(ctx, i)
		if d then Arena.dress(d, i) end -- (brief 30: the strong enemies' arenas)
	end
	local gates = ctx:group('Gates')
	for i = 1, STAGES + 1 do stageGate(gates, i) end
	bossYard(ctx)
end
