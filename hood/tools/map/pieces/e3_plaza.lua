---------------------------------------------------------------------------------------------- the open plaza (B31)
-- B31 PLAZA (the user: an OPEN outdoor plaza like the reference, "Drop it, all outdoors": no warehouse, no hall; rules
-- 22-28). This piece runs after e2_lobby and swaps the hall's shell, floor and wall dressing for the soldier game's
-- plaza (bible §2.1, ref_W01.0_spawn_view_north.jpg, ref_STILL_lobby_topdown_superhero.png, ref_product_pads.webp):
--   Ground   one studded grass field (ref W01 lit grass #5ACB2E) inside a ring of terraced clay cliffs: 9-10 studs a
--            step, a grass cap on every column, a few blocky trees on the steps; low hood brick blocks stand back on
--            the upper step as landmarks (never up close). The cliffs are the plaza's edge (invisible walls on their faces).
--   Paths    a plus from the spawn: the spine north to the Stage 1 gate, the west arm into the training deck's aisle,
--            the east arm to the gun stand, the south walk to the box dais. Two-tone 4 x 4 studded tiles with a dark
--            1-stud curb on every side no other path continues from (ref W01's walks). The spawn square is plain grey.
--   Zones    each on a raised grey plinth with a dark curb: the training deck (rows of 4 + the head lane on its own
--            extension), the gun stand (the armory's apron and kerb), the stepped box dais. Products stand on the grass
--            in rows beside the spine and the south walk (ref_product_pads: pads on the grass by the path).
-- Gameplay contracts (slots, prompts, tags, names) are the builders' own (Stations, Armory, productStand,
-- boxPadStand, shoeDais, worldBossStand, leaderboard); only where they stand changes. Map frame, north = -Z.
Lobby.Open = true
-- B35 LAYOUT (the owner: "make it more based on the other references ... way way more optimal"; THE plan is
-- ref_STILL_lobby_topdown_superhero.png). One plus of walks from the crossing (z 36): north to the Stage 1 door (the gate
-- just outside it, z 0), west into the training aisle, east to the gun stand, south to the box row. Round it:
--   W   the training block: two rows of 4 compact bays (13 deep, Stations.Compact) facing an 8-wide aisle that the west
--       arm runs on into, on one sand plinth whose mouth meets the arm 2.5 studs past the spine; the head lane on its
--       gold stage on a small extension closing the aisle (the reference's lone lane at the training block's end)
--   E   the gun stand (ARMORY) on the east arm's end, the owner's gun shop behind it (the reference's evolutions stand)
--   S   the box row on its stepped plinth at the spine's south end (the reference's eggs)
--   N   two special-sale spots flanking the spine before the door (ref_W01's "MOST OP!" showcase), the CODES chest and
--       the group chest in the two north corners beside the door, the spin wheel by the group chest
--   SW  the WORLD 2 portal; SE the World Boss board and the three leaderboards in an angled row toward the east wall.
--       The portal and every board face the crossing (the owner: "make the portal and leaderboards face the main center").
-- No game-pass pads in the world (the owner: passes live in the Store). Calm floor fields between the zones.
Lobby.PlazaGap = 6.5 -- the training deck's mouth (x -6.5): 2.5 studs past the spine's edge
Lobby.Aisle = 4 -- the training aisle's half width (8: the walks' own width)
Lobby.Stand.Pitch = 10 -- lane centre to lane centre (9-wide bays, a stud between)
Lobby.RowZ = { N = Lobby.CrossZ - Lobby.Aisle - Lobby.laneHalf(), S = Lobby.CrossZ + Lobby.Aisle + Lobby.laneHalf() } -- (the aisle's half width + the bays' half length)
Lobby.HeadFront = -51 -- the head lane's shooter end; its stage's red steps end 3 past the deepest bays
Lobby.Plaza = { x0 = -50, x1 = -Lobby.PlazaGap, z0 = Lobby.CrossZ - 19.2, z1 = Lobby.CrossZ + 19.2, aisle = { Lobby.CrossZ - 4, Lobby.CrossZ + 4 }, deck = 0.36 }
Lobby.HeadDeck = { x0 = -67, z0 = Lobby.CrossZ - 8, z1 = Lobby.CrossZ + 8 } -- the deck's extension under the head lane
-- the warehouse's inner wall faces (e4's Lobby.WH; f_areas puts its keep-in walls on them): x -70..54, z 6..82, the
-- north door's mouth |x| < 24
Lobby.Bounds = { x = 70, xw = 70, xe = 54, n = 6, s = 82, mouth = 24 }
function Lobby.edgeX(sx) return sx < 0 and Lobby.Bounds.xw or Lobby.Bounds.xe end
-- where you land: on the spine 3 south of the crossing, facing north over it to the gate (ref_W01.0)
Lobby.SpawnAt = SPAWN + V(0, 0, 3)
-- the gun stand: its front on the east arm's end (x 12), its centre line 2 north of the arm's axis
Lobby.ArmoryX, Lobby.ArmoryZ = 12, Lobby.CrossZ - 2
Lobby.ArmoryAt = CFrame.lookAt(V(Lobby.ArmoryX, 0, Lobby.ArmoryZ), V(0, 0, Lobby.ArmoryZ))
-- the box row: a narrower plinth (4 boxes 10 apart), its front step 2 studs past the training plinth's south kerb
Lobby.Dais.X, Lobby.Dais.StairW, Lobby.Dais.Slots = 20, 2.5, { 15, 5, -5, -15 }
Lobby.DaisAt = CFrame.new(0, 0, Lobby.Plaza.z1 + 2)
-- (B31) colours as Color3 (HoodToy's grade adds saturation; the renders land on the reference's measured fields)
Lobby.PlazaColors = {
	grass = C(122, 204, 82), -- (renders ~#5ACB2E, ref W01 lit grass)
	-- (B34 fix round: no cold lavender, no tile grid) one warm grey walk with a warm dark curb
	pathA = C(180, 172, 160), pathB = C(180, 172, 160), curb = C(98, 86, 78), spawn = C(180, 172, 160),
	clay = C(196, 112, 58), clayLight = C(210, 128, 70), cap = C(118, 196, 66), capDark = C(98, 174, 58),
}
-- the training deck's plinth in the reference's pale grey-lavender (ref_STILL_training_lanes_superhero: #CFD9EA lit)
Lobby.Stand.Colors.deck = C(217, 160, 102) -- (B34: the west quadrant's warm sand field, #D9A066)
-- (B34 fix round) the box dais in warm cream and brown-grey, not lavender
Lobby.Colors.dais, Lobby.Colors.panelLight, Lobby.Colors.pillarSide = C(214, 204, 190), C(198, 186, 170), C(142, 122, 106)
Lobby.Stand.Colors.kerb = Lobby.PlazaColors.curb
Lobby.Stand.Colors.kerbTop = C(132, 116, 104)
Lobby.Stand.Colors.aisle = Lobby.PlazaColors.pathA
Lobby.Stand.Colors.aisleEdge = Lobby.PlazaColors.curb
Lobby.Stand.Colors.riserDark = Lobby.PlazaColors.curb
Lobby.Stand.Colors.carpet, Lobby.Stand.Colors.carpetDark = C(196, 70, 70), C(140, 40, 48) -- (the head lane's red steps, ref_W06.5)
-- the aisle's runner in the walks' darker tile, not a red carpet (critic 7: a big saturated field)
Lobby.Stand.Colors.runner, Lobby.Stand.Colors.runnerEdge = Lobby.PlazaColors.pathB, Lobby.PlazaColors.curb -- (calmer: a big field)
Lobby.BoardTilt = 0 -- (critic 9: no leaning slabs; ref_V2-07.0 boards stand upright on the grass)

-- Where everything stands (map frame). The centre every board turns to: the crossing.
Lobby.Centre = V(0, 0, Lobby.CrossZ)
Lobby.Plan = (function()
return {
	Stands = {}, -- (B35, the owner: no game-pass pads in the world; every pass is in the Store's Gamepasses)
	BoxPads = {},
	-- the special-sale spots, one each side of the spine before the door (ref_W01's "MOST OP!" showcase), turned to where
	-- you land. Filled for now with the Robux shoe offers (Lobby.saleSpot); the owner's renders will dress them later.
	Sales = {
		{ Name = 'West', Box = 'Grail', Key = 'ShoeBoxGrail', x = -12, z = 12, Tone = C(236, 90, 200), Tag = 'NEW' },
		{ Name = 'East', Box = 'GrailBundle', Key = 'GrailBundle', x = 12, z = 12, Tone = C(176, 96, 255), Special = '3 PAIRS' },
	},
	-- the north corners beside the door: the CODES chest (west), the group chest and the spin wheel (east)
	Group = { codes = { -25, 11 }, chest = { 24, 11 }, scale = 0.62 },
	World2 = { x = -33, z = 64, look = Lobby.Centre, scale = 0.85 }, -- (SW, facing the crossing)
	WorldBoss = { x = 32, z = 59, look = Lobby.Centre }, -- (SE, facing the crossing)
	-- (SE) the three boards in an angled row toward the east wall, each facing the crossing
	Boards = { { 46, 51.5 }, { 44.5, 61 }, { 40.5, 70.5 } },
}
end)()

-- ItemMeshes (MESH, Shared/ItemMeshes): the showcase items as real meshes, the Part build as the fallback. Until it
-- lands, the brief's stub: clone ReplicatedStorage.HoodItemMeshes[id] scaled to fit `size` with its bottom centre at cf.
function Lobby.itemMeshes()
	if Lobby._meshes ~= nil then return Lobby._meshes end
	local mod = Lobby.sharedModule('ItemMeshes')
	if not (mod and mod.place) then
		mod = {}
		function mod.place(id, cf, size, parent, fallbackFn)
			local folder = ReplicatedStorage:FindFirstChild('HoodItemMeshes')
			local t = folder and folder:FindFirstChild(id)
			if t and t:IsA('Model') then
				local m = t:Clone()
				local cfB, ext = m:GetBoundingBox()
				local fit = typeof(size) == 'Vector3' and math.min(size.X / ext.X, size.Y / ext.Y, size.Z / ext.Z) or size / math.max(ext.X, ext.Y, ext.Z)
				pcall(function() m:ScaleTo(m:GetScale() * fit) end)
				cfB, ext = m:GetBoundingBox()
				m:PivotTo(cf * CFrame.new(0, ext.Y / 2, 0) * (cfB:Inverse() * m:GetPivot()))
				for _, p in m:GetDescendants() do if p:IsA('BasePart') then p.Anchored, p.CanCollide, p.CanTouch, p.CanQuery = true, false, false, false end end
				m.Parent = parent
				return m, true
			end
			return fallbackFn(cf, size, parent), false
		end
	end
	Lobby._meshes = mod
	return mod
end
local function vmin(a, b) return V(math.min(a.X, b.X), math.min(a.Y, b.Y), math.min(a.Z, b.Z)) end
local function vmax(a, b) return V(math.max(a.X, b.X), math.max(a.Y, b.Y), math.max(a.Z, b.Z)) end
-- (B31 PLAZA, rule 29) The user's blocky designs ($S/bz: Blender -> GLB -> the user's one-time import into
-- ReplicatedStorage.HoodItemMeshes) are THE objects; our Part builds are the fallback until they're imported. Their design
-- sizes in studs (GLB bounds; 1 unit = 1 stud, standing on their bottom, front -Z): Lobby.Designed[id] = { x, y, z }.
Lobby.Designed = {
	Pad_Base = { 8.12, 1.39, 8.12 }, Pedestal_Box = { 7, 1.1, 7 }, Spawn_Pad = { 12, 1.17, 12 },
	Gate_Stage1 = { 20.2, 14.17, 4.7 }, Board_Boxes = { 16.3, 10.1, 2.4 }, Board_Leaderboard = { 8.5, 12.15, 3.4 },
	Stand_Guns = { 14.6, 11.28, 6.81 }, Stand_SpinWheel = { 6.6, 8.09, 3.55 }, Portal_World2 = { 16.4, 14.14, 5.46 },
	Chest_Codes = { 4.74, 3.99, 3.64 }, Chest_GroupReward = { 4.74, 3.99, 3.64 },
	Scn_Tree_1 = { 10.6, 13.5, 7.4 }, Scn_Tree_2 = { 8.7, 14.5, 7 }, Scn_Bush_1 = { 3.2, 2.37, 2.64 }, Scn_Cliff_Block = { 16, 12.17, 16 },
	Scn_Building_1 = { 19.05, 15.97, 14.95 }, Scn_Building_2 = { 19.15, 21.95, 14.4 }, Scn_Building_3 = { 19.05, 17, 14.75 }, Scn_Building_4 = { 21.05, 14.18, 15.2 },
	Scn_Hydrant = { 2.48, 3.06, 2.26 }, Scn_TrashCan = { 2.24, 3.65, 2.26 }, Scn_Bench = { 4.7, 2.75, 2.24 }, Scn_StreetLamp = { 4.7, 8.43, 2 },
	Scn_Cone = { 2.7, 2.56, 2.7 }, Scn_Barrel = { 2.06, 3.04, 2.12 }, Scn_Crate = { 2.7, 2.51, 2.7 }, Scn_Sandbag = { 4.68, 1.72, 1.28 },
	Scn_Car = { 5.26, 4.68, 10 }, Scn_Hoop = { 5.4, 9.98, 5.4 }, Scn_Fence = { 8, 4.63, 0.92 }, Scn_GraffitiWall = { 8, 5.39, 1.44 },
}
-- Is the designed model imported (so a builder can lay out round it)?
function Lobby.hasDesign(id)
	local IM = Lobby.itemMeshes()
	return IM.has ~= nil and IM.has(id) == true
end
-- Place the designed model `id` with its bottom centre at c (front -Z), `k` times its design size (default 1); else run
-- build(c) (our Part build). Returns usedMesh, the model. A solid design gets an invisible box collider round its
-- footprint (the import's parts never collide): solid = true (its whole box) or a height.
function Lobby.designed(c, id, k, build, solid)
	local IM = Lobby.itemMeshes()
	local d = Lobby.Designed[id] or { 4, 4, 4 }
	k = k or 1
	local size = math.max(d[1], d[2], d[3]) * k
	local ok, m, used = pcall(IM.place, id, c:world(CFrame.new()), size, c.parent, function() return nil end)
	if ok and m and used ~= false then
		m.Name = id
		if solid then
			local h = type(solid) == 'number' and solid or d[2] * k
			local box = ghost(c:box('DesignCollider', V(-d[1] * k / 2, 0, -d[3] * k / 2), V(d[1] * k / 2, h, d[3] * k / 2), P.white))
			box.CanCollide, box.CastShadow = true, false
		end
		return true, m
	end
	if not ok then warn('[Lobby] ' .. id .. ': ' .. tostring(m)) end
	if build then build(c) end
	return false, nil
end
-- A model's world box (min, max) over its visible parts.
function Lobby.boundsOf(model)
	local lo, hi = V(math.huge, math.huge, math.huge), V(-math.huge, -math.huge, -math.huge)
	for _, p in model:GetDescendants() do
		if p:IsA('BasePart') and p.Transparency < 1 then
			local x, y, z, r00, r01, r02, r10, r11, r12, r20, r21, r22 = p.CFrame:GetComponents()
			local h = V((math.abs(r00) * p.Size.X + math.abs(r01) * p.Size.Y + math.abs(r02) * p.Size.Z) / 2,
				(math.abs(r10) * p.Size.X + math.abs(r11) * p.Size.Y + math.abs(r12) * p.Size.Z) / 2,
				(math.abs(r20) * p.Size.X + math.abs(r21) * p.Size.Y + math.abs(r22) * p.Size.Z) / 2)
			lo, hi = vmin(lo, V(x, y, z) - h), vmax(hi, V(x, y, z) + h)
		end
	end
	return lo, hi
end
-- Fit a Part-built model (any pose) so its largest side is `size`, its bottom centre at world cf.
function Lobby.fitModel(model, cf, size)
	local lo, hi = Lobby.boundsOf(model)
	if lo.X == math.huge then return model end
	local ext = hi - lo
	local k = size / math.max(ext.X, ext.Y, ext.Z, 0.1)
	local bottom = V((lo.X + hi.X) / 2, lo.Y, (lo.Z + hi.Z) / 2)
	for _, p in model:GetDescendants() do
		if p:IsA('BasePart') then
			local rel = p.CFrame - bottom
			p.Size *= k
			p.CFrame = cf * (rel.Rotation + rel.Position * k)
		end
	end
	return model
end

---------------------------------------------------------------------------------------------- ground and cliffs
-- (replaces the hall) The grass field, and the terraced clay cliffs round it.
function Lobby.hall(L)
	local K = Lobby.PlazaColors
	local h = L:group('Hall')
	local g = h:box('Floor', V(-128, -1, Lobby.N - 1), V(128, 0, Lobby.S + 1), K.grass, M.Plastic)
	studs(g)
	g.Name = 'Grass'
	Lobby.cliffs(L)
	return h
end
-- One terrace step along a face: columns 8-12 wide from u0 to u1 (along the face), from the face back to `back`
-- (depth), each column h0 +- 1 tall with a grass cap (overhanging the face 0.4) and, now and then, a blocky tree set
-- back on its top. face(u, d, y) maps along / depth / height to the map frame.
function Lobby.terrace(c, face, u0, u1, back, h0, seed, trees)
	local K = Lobby.PlazaColors
	local r = Random.new(seed)
	local u, k = u0, 0
	while u < u1 - 0.01 do
		-- (B34, the owner's "Alien" place: one 8-stud grid, steps in 4s)
		local w = math.min(u1 - u, ({ 8, 16, 16, 24 })[r:NextInteger(1, 4)])
		if u1 - (u + w) < 4 then w = u1 - u end -- (no sliver at the end)
		local hgt = h0 + ({ 0, 0, 4 })[r:NextInteger(1, 3)]
		k += 1
		local function box(name, a, b, color)
			local lo, hi = face(a.X, a.Y, a.Z), face(b.X, b.Y, b.Z)
			return c:box(name, vmin(lo, hi), vmax(lo, hi), color, M.Plastic)
		end
		studs(box('CliffBody', V(u, 0, -1), V(u + w, back, hgt - 1.2), k % 3 == 0 and K.clayLight or K.clay), true)
		studs(box('CliffCap', V(u, -0.4, hgt - 1.2), V(u + w, back, hgt), k % 4 == 1 and K.capDark or K.cap), true)
		-- grass drips: green strips running down the face from the cap, 4-8 wide, a quarter to three quarters of the face
		local du = u + r:NextInteger(0, math.max(0, math.floor(w) - 8))
		while du < u + w - 3.9 do
			local dw = math.min(({ 4, 4, 8 })[r:NextInteger(1, 3)], u + w - du)
			local len = (hgt - 1.2) * ({ 0.25, 0.5, 0.75 })[r:NextInteger(1, 3)]
			decor(box('CliffDrip', V(du, -0.4, hgt - 1.2 - len), V(du + dw, -0.1, hgt - 1.2), K.cap)).CastShadow = false
			du += dw + 4 * r:NextInteger(1, 3)
		end
		if trees and w >= 10 and r:NextNumber() < trees then
			local p = face(u + w / 2, math.min(back - 4, 6 + r:NextNumber(0, 3)), hgt)
			Lobby.designed(c:at(CFrame.new(p) * CFrame.Angles(0, r:NextInteger(0, 3) * math.pi / 2, 0)), k % 2 == 0 and 'Scn_Tree_1' or 'Scn_Tree_2', 0.7,
				function(f) tree(f, V(0, 0, 0), seed + k, 0.62, nil, true) end)
		end
		u += w
	end
end
function Lobby.cliffs(L)
	local g = L:group('Surroundings')
	local B = Lobby.Bounds
	local X, N, S, mouth = B.x, B.n, B.s, B.mouth
	local function west(base, sx) return function(u, d, y) return V(sx * (base + d), y, u) end end
	local function south(base) return function(u, d, y) return V(u, y, base + d) end end
	local function north(base) return function(u, d, y) return V(u, y, base - d) end end
	-- tier 1 (the step you see over the grass): the user's Scn_Cliff_Block tiles when imported (16 x 12 x 16, stepped,
	-- studded, grass on every step), else our clay columns; tiers 2 and 3 (the high ground behind, out past the map's wall)
	-- stay our columns either way (a tile's back half sinks into tier 2)
	local tiles = Lobby.hasDesign('Scn_Cliff_Block')
	local XW, XE = Lobby.edgeX(-1), Lobby.edgeX(1)
	if tiles then
		Lobby.cliffTiles(g, V(-XW, 0, N), V(-XW, 0, S + 16), V(1, 0, 0), 1)
		Lobby.cliffTiles(g, V(XE, 0, N), V(XE, 0, S + 16), V(-1, 0, 0), 1)
		Lobby.cliffTiles(g, V(-XW, 0, S), V(XE, 0, S), V(0, 0, -1), 1)
		Lobby.cliffTiles(g, V(-mouth, 0, N), V(-XW - 16, 0, N), V(0, 0, 1), 0.75)
		Lobby.cliffTiles(g, V(mouth, 0, N), V(XE + 16, 0, N), V(0, 0, 1), 0.75)
	end
	for _, sx in { -1, 1 } do
		local X = Lobby.edgeX(sx)
		if not tiles then Lobby.terrace(g, west(X, sx), N, S, 8, 8, 600 + sx, 0.35) end
		Lobby.terrace(g, west(X + 8, sx), Lobby.N - 6, S + 45, 12, 16, 620 + sx, 0.25)
		Lobby.terrace(g, west(X + 20, sx), Lobby.N - 6, S + 45, 127 - (X + 20), 24, 630 + sx, 0.2) -- (out past the map's wall)
		-- the north step either side of the gate's mouth, and the higher step behind it beside the stage's blocks
		local function nface(u, d, y) return V(sx * u, y, N - d) end
		if not tiles then
			Lobby.terrace(g, nface, mouth, 37, 12, 9, 640 + sx, 0)
			Lobby.terrace(g, nface, 37, X + 8, 6, 9, 650 + sx, 0)
		end
		Lobby.terrace(g, function(u, d, y) return V(sx * u, y, Lobby.N - d) end, 37, X + 8, 6, 17, 660 + sx, 0)
	end
	if not tiles then Lobby.terrace(g, south(S), -XW - 8, XE + 8, 8, 8, 680, 0.3) end
	Lobby.terrace(g, south(S + 8), -XW - 20, XE + 20, 14, 16, 700, 0.2)
	Lobby.terrace(g, south(S + 22), -127, 127, 23, 24, 710, 0.15)
	local _ = north
	-- the hood blocks on the high ground: flat-roofed two-storey brick blocks set back from the step's edge, tagged
	local lm = L:group('Landmarks')
	if brickBuilding then
		local spots = { -- (on the top step, set back from its edge)
			{ V(-(X + 23), 28, 34), V(1, 0, 0), 30 }, { V(-(X + 23), 28, 92), V(1, 0, 0), 26 },
			{ V(Lobby.edgeX(1) + 23, 28, 26), V(-1, 0, 0), 26 }, { V(Lobby.edgeX(1) + 23, 28, 84), V(-1, 0, 0), 30 },
			{ V(-46, 28, S + 26), V(0, 0, -1), 30 }, { V(40, 28, S + 26), V(0, 0, -1), 34 },
		}
		local tags = { { 'front', 7, 6, 'HOOD', C(255, 90, 160) }, { 'front', 19, 7, '+1', C(80, 220, 255) } }
		for k, s in spots do
			-- (rule 29) the user's Scn_Building_1..4 (a snack bar, a 21 walk-up, the SUDS laundromat, the REVZ garage), 1.2x,
			-- their fronts to the plaza; else brickBuilding (footprint x 0..w, z -d..0, its front on +Z)
			local front = s[1] - V(0, 1, 0) -- (sunk a stud: the step's columns stand 27-29 tall, never a gap under it)
			local mid = front - s[2] * (15 * 1.2 / 2)
			Lobby.designed(lm:at(CFrame.lookAt(mid, mid + s[2])), 'Scn_Building_' .. ((k - 1) % 4 + 1), 1.2, function()
				local cf = CFrame.lookAt(front, front - s[2]) * CFrame.new(-s[3] / 2, 0, 0)
				pcall(brickBuilding, lm:at(cf), s[3], { name = 'HoodBlock', floors = 1, depth = 12, roof = 'flat', bays = 2, tags = k % 2 == 1 and tags or nil, wall = k % 3 == 0 and C(170, 84, 64) or nil })
			end, true)
		end
	end
	for _, p in g.parent:GetDescendants() do
		if p:IsA('BasePart') then p.CastShadow = p.Size.Y > 6 end -- (the steps throw short shadows on the grass at their foot)
	end
	for _, p in lm.parent:GetDescendants() do
		if p:IsA('BasePart') then p.CastShadow = false end
	end
	return g
end
Lobby.surroundings = function() end -- (the cliffs are built with the ground)
-- A row of the user's Scn_Cliff_Block tiles along a cliff face from a to b (map frame, on the ground), fronts toward
-- `inward` (the plaza): as many whole tiles as fit at up to kmax of their 16-stud size, scaled to fill the run exactly.
function Lobby.cliffTiles(g, a, b, inward, kmax)
	local len = (b - a).Magnitude
	local dir = (b - a).Unit
	local n = math.max(1, math.ceil(len / (16 * kmax) - 0.01))
	local k = len / (16 * n)
	for i = 0, n - 1 do
		local mid = a + dir * (16 * k * (i + 0.5)) - inward * (8 * k)
		Lobby.designed(g:at(CFrame.lookAt(mid, mid + inward)), 'Scn_Cliff_Block', k, nil, true)
	end
end

---------------------------------------------------------------------------------------------- the path network
function Lobby.paths()
	local Z, N = Lobby.CrossZ, Lobby.N
	local sz = Lobby.DaisAt.Position.Z -- the dais's front step
	return {
		-- (B34) one clean plus from the crossing, each arm ending at its zone: no cross walks, no stubs
		{ -4, 4, Z - 4, Z + 4, 'Crossroads' }, -- (B34 fix round: 8 wide)
		{ -4, 4, N - 1, Z - 4, 'North' },
		{ -Lobby.PlazaGap, -4, Z - 4, Z + 4, 'West' },
		{ 4, Lobby.ArmoryX, Z - 4, Z + 4, 'East' },
		{ -4, 4, Z + 4, sz, 'South' },
	}
end
-- One path rectangle: two-tone 4 x 4 studded tiles on a grid from the spawn, a dark 1-stud curb along every stretch of
-- its sides that no other path continues across (a hair higher than the tiles).
function Lobby.pathRect(f, r, all)
	local K = Lobby.PlazaColors
	local x0, x1, z0, z1 = r[1], r[2], r[3], r[4]
	local top, ct, e = 0.12, 0.24, 1
	if r[5] == 'Crossroads' then
		studs(f:box('SpawnSquare', V(x0, 0, z0), V(x1, top, z1), K.spawn, M.Plastic)).CastShadow = false
	else
		local T, cz = 4, Lobby.CrossZ - 1 -- (the grid: x on 0, z on the spawn's square edges)
		local function cuts(a, b, origin)
			local list, v = {}, a
			while v < b - 0.01 do
				local nxt = math.min(b, origin + (math.floor((v - origin) / T + 1e-6) + 1) * T)
				table.insert(list, { v, nxt, math.floor((v - origin) / T + 1e-6) })
				v = nxt
			end
			return list
		end
		for _, cx in cuts(x0, x1, 0) do
			for _, czr in cuts(z0, z1, cz) do
				local tone = (cx[3] + czr[3]) % 2 == 0 and K.pathA or K.pathB
				studs(f:box('Path', V(cx[1], 0, czr[1]), V(cx[2], top, czr[2]), tone, M.Plastic)).CastShadow = false
			end
		end
	end
	local function open(fixed, isX, u0, u1, outward)
		local cutsList = {}
		for _, o in all do
			if o ~= r then
				local t0, t1, s0, s1
				if isX then t0, t1, s0, s1 = o[1], o[2], o[3], o[4] else t0, t1, s0, s1 = o[3], o[4], o[1], o[2] end
				local probe = fixed + outward * 0.3
				if probe > s0 and probe < s1 then table.insert(cutsList, { math.max(u0, t0), math.min(u1, t1) }) end
			end
		end
		-- (the gate's end and the plinths a path runs onto take no curb either)
		if isX and outward < 0 and fixed <= Lobby.N then table.insert(cutsList, { u0, u1 }) end
		if not isX and outward < 0 and math.abs(fixed + Lobby.PlazaGap) < 0.01 then table.insert(cutsList, { u0, u1 }) end
		if not isX and outward > 0 and math.abs(fixed - Lobby.ArmoryX) < 0.01 then table.insert(cutsList, { u0, u1 }) end
		local dx = Lobby.Dais.X + Lobby.Dais.StairW
		if isX and outward > 0 and math.abs(fixed - Lobby.DaisAt.Position.Z) < 0.01 then table.insert(cutsList, { math.max(u0, -dx), math.min(u1, dx) }) end
		table.sort(cutsList, function(p, q) return p[1] < q[1] end)
		local runs, u = {}, u0
		for _, c in cutsList do
			if c[2] > c[1] then
				if c[1] > u then table.insert(runs, { u, c[1] }) end
				u = math.max(u, c[2])
			end
		end
		if u1 > u then table.insert(runs, { u, u1 }) end
		return runs
	end
	local function curb(a, b) studs(f:box('PathCurb', a, b, K.curb, M.Plastic)).CastShadow = false end
	for _, run in open(z0, true, x0, x1, -1) do curb(V(run[1], 0, z0), V(run[2], ct, z0 + e)) end
	for _, run in open(z1, true, x0, x1, 1) do curb(V(run[1], 0, z1 - e), V(run[2], ct, z1)) end
	for _, run in open(x0, false, z0, z1, -1) do
		local a2, b2 = math.max(run[1], z0 + e), math.min(run[2], z1 - e)
		if b2 > a2 then curb(V(x0, 0, a2), V(x0 + e, ct, b2)) end
	end
	for _, run in open(x1, false, z0, z1, 1) do
		local a2, b2 = math.max(run[1], z0 + e), math.min(run[2], z1 - e)
		if b2 > a2 then curb(V(x1 - e, 0, a2), V(x1, ct, b2)) end
	end
end
function Lobby.floorPlan(L)
	local f = L:group('FloorPlan')
	local all = Lobby.paths()
	Lobby.Path = {}
	for _, r in all do
		Lobby.pathRect(f, r, all)
		Lobby.Path[r[5]] = { r[1], r[2], r[3], r[4] }
	end
	-- the dark chevrons on the spine pointing to the gate (ref W01: the walk's arrow marks toward STAGE 1)
	for _, tz in { Lobby.CrossZ - 13, Lobby.CrossZ - 21 } do
		for _, sx in { -1, 1 } do
			local tip, tail = V(0, 0.15, tz), V(sx * 2.6, 0.15, tz + 2.8)
			decor(f:part('WalkChevron', V(1.2, 0.06, (tip - tail).Magnitude + 0.6), CFrame.lookAt((tip + tail) / 2, tip), Lobby.PlazaColors.curb, M.SmoothPlastic)).CastShadow = false
		end
	end
	-- the training deck's extension under the head lane: the deck's own slab and curb, round its three outer sides
	local St = Lobby.Stand
	local Kc, Pz, Hd = St.Colors, Lobby.Plaza, Lobby.HeadDeck
	local hgt = Pz.deck
	local t = L:group('HeadDeck')
	local kw = 1.2
	studs(t:box('PlazaDeck', V(Hd.x0 + kw, 0, Hd.z0 + kw), V(Pz.x0, hgt, Hd.z1 - kw), Kc.deck, M.Plastic))
	for _, e in { { V(Hd.x0, 0, Hd.z0), V(Pz.x0, hgt + 0.25, Hd.z0 + kw) }, { V(Hd.x0, 0, Hd.z1 - kw), V(Pz.x0, hgt + 0.25, Hd.z1) }, { V(Hd.x0, 0, Hd.z0 + kw), V(Hd.x0 + kw, hgt + 0.25, Hd.z1 - kw) } } do
		studs(t:box('PlazaKerb', e[1], e[2], Kc.kerb, M.Plastic), true)
	end
	return f
end

---------------------------------------------------------------------------------------------- what the plaza drops
-- No wall dressing out here: no murals, no stray crates, drums or tyres on the deck, no stockroom racks or forklift, no
-- vending corner, no carton piles (critic 9: no strays). Their builders stay for other callers.
Lobby.rangeMural = function() end
Lobby.standProps = function() end
Lobby.armoryYard = function() end
Lobby.hoodProps = function() end
Lobby.decor = function() end

-- The plaza's two area titles: TRAIN over the head lane at the aisle's end, ARMORY over the gun stand. One line each.
function Lobby.signs(L)
	local s = L:group('HallSigns')
	local tt = Lobby.title(s, V(Lobby.endX() - 3, 24, Lobby.CrossZ), 19, 5.2, 'TRAIN', nil, P.white, 220)
	tt.Name = 'TrainTitle'
	-- (B34 fix round: the walls and the air stay quiet; only TRAIN and the dais's BOXES sign float)
	return s
end
-- (B35) the CODES chest and the group chest in the north corners beside the door, each on its own small plinth (the
-- training deck's slab in its dark kerb), turned to where you land.
function Lobby.northBays(L)
	local b = L:group('NorthBays')
	local g = Lobby.Plan.Group
	for _, it in { { 'CodesPlinth', g.codes, Lobby.codeTerminal }, { 'GroupPlinth', g.chest, Lobby.rewardChest } } do
		local x, z = it[2][1], it[2][2]
		local y = Lobby.plinth(L, it[1], x - 3.6, x + 3.6, z - 3.4, z + 3.4) + 0.06
		local cf = CFrame.lookAt(V(x, y, z), V(Lobby.SpawnAt.X, y, Lobby.SpawnAt.Z))
		local model = it[3](b:at(cf))
		if model then Lobby.scaleAbout(model, cf, g.scale or 1) end
	end
	return b
end
-- The spawn: the plain grey square at the crossing (no mark, the user's rule 17).
function Lobby.spawn(L)
	local spawn = Instance.new('SpawnLocation')
	spawn.Name = 'Spawn'
	spawn.Anchored = true
	spawn.Enabled = false
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Size = V(8, 0.2, 8)
	spawn.CFrame = V2.Origin * CFrame.new(Lobby.SpawnAt + V(0, 0.4, 0))
	spawn.Transparency = 1
	spawn.CanCollide = false
	spawn.Parent = L.parent
	Lobby.Slots.Spawn = CFrame.new(Lobby.SpawnAt)
end

---------------------------------------------------------------------------------------------- spin wheel stand
-- (rule 29) The user's Stand_SpinWheel on the grass north of the gun stand, by the spine's east row, turned to where you
-- land: a hold opens the Spin Wheel window (HoodClient/Wheel: the prompt's OpenSpin attribute). Our Part wheel when the
-- design isn't imported: a studded base, a post, an eight-wedge wheel with a pointer. One line of words over it.
Lobby.SpinAt = { x = 33, z = 12 } -- (B35: the NE corner beside the group chest)
function Lobby.spinStand(L)
	local at = V(Lobby.SpinAt.x, 0.06, Lobby.SpinAt.z)
	local c, model = L:group('SpinWheelStand')
	c = c:at(CFrame.lookAt(at, V(Lobby.SpawnAt.X, 0.06, Lobby.SpawnAt.Z)))
	Lobby.designed(c, 'Stand_SpinWheel', 1, function(f)
		studs(f:box('WheelBase', V(-3.3, 0, -1.8), V(3.3, 0.6, 1.8), C(236, 240, 248), M.Plastic))
		f:box('WheelBaseBand', V(-3.35, 0.45, -1.85), V(3.35, 0.6, 1.85), C(70, 120, 255), M.SmoothPlastic)
		f:box('WheelPost', V(-0.6, 0.6, -0.2), V(0.6, 4.2, 0.9), C(70, 120, 255), M.SmoothPlastic)
		local hub = CFrame.new(0, 4.6, -0.4)
		local cols = { C(255, 70, 70), C(255, 200, 40), C(60, 200, 90), C(60, 150, 255), C(255, 70, 70), C(255, 200, 40), C(60, 200, 90), C(60, 150, 255) }
		f:part('WheelRim', V(0.5, 7, 7), hub * CFrame.Angles(0, math.pi / 2, 0), C(250, 250, 252), M.SmoothPlastic, Enum.PartType.Cylinder)
		for k, col in cols do
			f:part('WheelWedge', V(0.3, 2.9, 1.9), hub * CFrame.new(0, 0, -0.2) * CFrame.Angles(0, 0, (k - 1) * math.pi / 4) * CFrame.new(0, 1.65, 0), col, M.SmoothPlastic)
		end
		f:part('WheelHub', V(0.7, 1.2, 1.2), hub * CFrame.new(0, 0, -0.35) * CFrame.Angles(0, math.pi / 2, 0), C(250, 250, 252), M.SmoothPlastic, Enum.PartType.Cylinder)
		f:wedge('WheelPointer', V(0.4, 1.0, 0.9), hub * CFrame.new(0, 3.9, -0.5) * CFrame.Angles(math.pi, 0, 0), C(40, 44, 60), M.SmoothPlastic)
	end, true)
	local hit = ghost(c:box('WheelHit', V(-2.5, 0, -4.5), V(2.5, 6, -1.5), P.white))
	local p = Lobby.prompt(hit, 'Spin', 'Spin Wheel', 10)
	p:SetAttribute('ComingSoon', nil)
	p:SetAttribute('OpenSpin', true)
	p.Name = 'SpinPrompt'
	local a = Lobby.signWords(c, V(0, 10.8, 0), 8, 1.6, { { 'Title', 'SPIN WHEEL', 1, Lobby.Grad.gold, 3.5 } }, 36)
	Lobby.nearWords(a.WorldLabel, 26, 36)
	return model
end

---------------------------------------------------------------------------------------------- scenery (rule 29)
-- The user's plaza scenery (Scn_*), placed like the reference frames: few props, in tight clusters at the edges, never on
-- a walk: sandbags behind the training rows' far ends (ref_W07.5: sandbags behind the targets), street lamps at the
-- crossing's south corners and on the gate approach, benches facing the leaderboards, a hydrant and a bin by the box walk,
-- a barrel-and-crate corner by the world boss board, a parked car, a hoop, a graffiti wall between two fence panels at
-- the east cliff, trees at two corners and bushes at the cliffs' feet. Our Part builds (Lobby.Scn[id]) when the designs
-- aren't imported. Each: { id, x, z, yaw (deg: 0 = front -Z, toward the gate), k = scale }.
Lobby.Scenery = (function()
	local list = {}
	local function add(id, x, z, yaw, k) table.insert(list, { id, x, z, yaw or 0, k or 1 }) end
	local Pz = Lobby.Plaza
	for x = Pz.x0 + 3, Pz.x1 - 3, 4.8 do
		add('Scn_Sandbag', x, Pz.z0 - 1.6, 0)
		add('Scn_Sandbag', x, Pz.z1 + 1.6, 180)
	end
	for _, sx in { -1, 1 } do
		add('Scn_StreetLamp', sx * 14.5, 9, sx * 90) -- (either side of the gate's opening, in front of its pillars)
		add('Scn_StreetLamp', 21.5, sx > 0 and 62.5 or 47.5, 90) -- (the east arm's end, by the gun stand's front corners)
	end
	add('Scn_Hydrant', 7.4, 80, -90) add('Scn_TrashCan', -7.4, 80, 90)
	add('Scn_Barrel', 73, 34, 0) add('Scn_Barrel', 75.4, 35.2, 20) add('Scn_Crate', 73.6, 37.6, 8) add('Scn_Crate', 76.6, 38, -10)
	add('Scn_Car', 66, 28, 90)
	add('Scn_Hoop', -80, 30, 90)
	add('Scn_GraffitiWall', 78.4, 72, -90) add('Scn_Fence', 78.6, 64, -90) add('Scn_Fence', 78.6, 80, -90)
	add('Scn_Tree_1', 70, 48, 0) add('Scn_Tree_2', -84, 106, 0) add('Scn_Tree_2', -82, 14, 0)
	for _, z in { 22, 38, 80, 94 } do add('Scn_Bush_1', -91, z, 90) end
	for _, z in { 22, 56, 88, 100 } do add('Scn_Bush_1', 77.6, z, -90) end
	for _, x in { -70, -55, -40, 40, 55, 70 } do add('Scn_Bush_1', x, 13.5, 180) end
	for _, x in { -80, -66, -30, 30 } do add('Scn_Bush_1', x, 115.4, 0) end
	return list
end)()
local SOLID = { Scn_Car = true, Scn_Hoop = true, Scn_Fence = true, Scn_GraffitiWall = true, Scn_Tree_1 = true, Scn_Tree_2 = true }
-- Our Part builds of the scenery: c is the bottom centre, front -Z. Chunky, 2-3 tones each, sized like the designs.
Lobby.Scn = {}
function Lobby.Scn.Scn_Sandbag(c)
	local tan, dark = C(206, 176, 120), C(170, 138, 88)
	for k, b in { { -1.17, 0, 2.2 }, { 1.17, 0, 2.2 }, { 0, 0.86, 2.2 } } do
		c:box('Sandbag', V(b[1] - b[3] / 2, b[2], -0.6), V(b[1] + b[3] / 2, b[2] + 0.86, 0.6), k == 3 and tan or (k == 1 and tan or dark), M.SmoothPlastic)
	end
end
function Lobby.Scn.Scn_StreetLamp(c)
	local navy, glow = C(56, 62, 110), C(255, 236, 160)
	c:box('LampFoot', V(-0.8, 0, -0.8), V(0.8, 0.5, 0.8), navy:Lerp(P.black, 0.3), M.SmoothPlastic)
	c:box('LampPost', V(-0.35, 0.5, -0.35), V(0.35, 8, 0.35), navy, M.SmoothPlastic)
	c:box('LampBand', V(-0.45, 3.4, -0.45), V(0.45, 3.8, 0.45), C(255, 200, 60), M.SmoothPlastic)
	c:box('LampArm', V(-0.25, 7.6, -0.25), V(3.2, 8.0, 0.25), navy, M.SmoothPlastic)
	c:box('LampHood', V(2.2, 6.9, -0.7), V(3.8, 7.6, 0.7), navy, M.SmoothPlastic)
	decor(c:box('LampGlow', V(2.4, 5.9, -0.5), V(3.6, 6.9, 0.5), glow, M.Neon)).CastShadow = false
end
function Lobby.Scn.Scn_Bench(c) Lobby.bench(c:at(CFrame.new(0, 0, 0) * CFrame.Angles(0, math.pi, 0))) end
function Lobby.Scn.Scn_Hydrant(c) hydrant(c, V(0, 0, 0)) end
function Lobby.Scn.Scn_TrashCan(c)
	c:post('BinBody', 1.05, 3.1, V(0, 0, 0), C(56, 150, 80), M.SmoothPlastic)
	c:post('BinBand', 1.12, 0.3, V(0, 1.9, 0), C(40, 110, 60), M.SmoothPlastic)
	c:post('BinLid', 1.15, 0.4, V(0, 3.1, 0), C(40, 110, 60), M.SmoothPlastic)
end
function Lobby.Scn.Scn_Barrel(c) if Stations then Stations.drum(c, V(0, 0, 0), 1.0, 3.0, C(60, 130, 230), C(40, 90, 180), C(30, 70, 150), M.SmoothPlastic) end end
function Lobby.Scn.Scn_Crate(c) crate(c, CFrame.new(0, 0, 0), 2.6) end
function Lobby.Scn.Scn_Cone(c) if Stations then Stations.cone(c, CFrame.new()) end end
function Lobby.Scn.Scn_Car(c) car(c, CFrame.new() * CFrame.Angles(0, math.pi / 2, 0), C(214, 52, 52)) end
function Lobby.Scn.Scn_Hoop(c)
	c:box('HoopFoot', V(-1.4, 0, -1.4), V(1.4, 0.6, 1.4), C(56, 62, 110), M.SmoothPlastic)
	c:box('HoopPole', V(-0.3, 0.6, -0.3), V(0.3, 8.4, 0.3), C(56, 62, 110), M.SmoothPlastic)
	c:box('HoopBoard', V(-2.4, 7.2, -1.2), V(2.4, 10, -0.9), P.white, M.SmoothPlastic)
	c:box('HoopSquare', V(-0.9, 7.6, -1.25), V(0.9, 8.8, -1.2), C(255, 120, 40), M.SmoothPlastic)
	c:part('HoopRim', V(0.2, 1.8, 1.8), CFrame.new(0, 7.6, -2.2) * CFrame.Angles(0, 0, math.pi / 2), C(255, 120, 40), M.SmoothPlastic, Enum.PartType.Cylinder)
end
function Lobby.Scn.Scn_Fence(c)
	for k = 0, 3 do
		local x = -3 + k * 2
		c:box('FencePlank', V(x - 0.95, 0, -0.4), V(x + 0.95, 4.2 + (k % 2) * 0.4, 0.4), k % 2 == 0 and C(206, 150, 96) or C(184, 128, 80), M.SmoothPlastic)
	end
end
function Lobby.Scn.Scn_GraffitiWall(c)
	local w = c:box('GraffitiWall', V(-4, 0, -0.6), V(4, 5, 0.6), C(196, 196, 214), M.SmoothPlastic)
	c:box('GraffitiCap', V(-4.1, 5, -0.7), V(4.1, 5.4, 0.7), C(150, 152, 176), M.SmoothPlastic)
	line(surface(w, Enum.NormalId.Front, 20), 'Tag', 'WOW!', C(255, 90, 170), FONT.title, 0.2, 0.6, Lobby.Ink, 3)
end
function Lobby.Scn.Scn_Tree_1(c) tree(c, V(0, 0, 0), 31, 0.8, 0, true) end
function Lobby.Scn.Scn_Tree_2(c) tree(c, V(0, 0, 0), 37, 0.85, 0, true) end
function Lobby.Scn.Scn_Bush_1(c)
	c:box('Bush', V(-1.6, 0, -1.3), V(1.6, 1.6, 1.3), C(70, 170, 70), M.SmoothPlastic)
	c:box('Bush', V(-0.9, 1.6, -0.9), V(1.1, 2.4, 1.0), C(100, 200, 90), M.SmoothPlastic)
end
function Lobby.scenery(L)
	local g = L:group('Scenery')
	for _, s in Lobby.Scenery do
		local c = g:at(CFrame.new(s[2], 0.06, s[3]) * CFrame.Angles(0, math.rad(s[4]), 0))
		Lobby.designed(c, s[1], s[5], Lobby.Scn[s[1]], SOLID[s[1]] and (s[1]:find('Tree') and 6 or true) or nil)
	end
	-- every prop stays a prop: nothing collides but the solid ones' boxes (and our Part trees' and car's own parts)
	for _, p in g.parent:GetDescendants() do
		if p:IsA('BasePart') and p.Name ~= 'DesignCollider' and not p:FindFirstAncestor('Tree') and not p.Name:find('^Car') then decor(p) end
	end
	return g
end

-- The spawn pad (rule 29: the user's Spawn_Pad, 12 wide, plain, no symbol) over the crossing, sunk so its top stands
-- 0.35 over the walks (no step to trip on); our plain crossing square when it isn't imported (pathRect).
function Lobby.spawnPad(L)
	-- (B34 fix round) a 6-wide plate under where you land, flush with the walk (0.02 proud), a shade lighter than it: no
	-- symbol, nothing to blow out the view
	local g = L:group('SpawnPad')
	local at = Lobby.SpawnAt
	studs(g:box('SpawnPlate', V(at.X - 3, 0.12, at.Z - 3), V(at.X + 3, 0.14, at.Z + 3), C(196, 188, 176), M.Plastic)).CastShadow = false
end
-- (B34, the owner's "Alien" place) a soft white sparkle fountain rising off a station: one emitter on a flat box (cf in the
-- map frame, the box's centre on the floor; hx / hz its half sizes), the built-in sparkle texture, a low steady rate (no
-- flashing). The pads and the Robux boxes keep their own sparkles (Lobby.sparkles).
function Lobby.fountain(L, name, cf, hx, hz, tone)
	local box = ghost(L:at(cf):box(name, V(-hx, 0, -hz), V(hx, 0.2, hz), P.white))
	box.CastShadow = false
	local sp = Instance.new('ParticleEmitter')
	sp.Name = 'SparkleFountain'
	sp.Texture = 'rbxasset://textures/particles/sparkles_main.dds'
	sp:SetAttribute('PreviewTexture', 'sparkle')
	sp.Color = ColorSequence.new(P.white, (tone or P.white):Lerp(P.white, 0.5))
	sp.LightEmission, sp.LightInfluence = 0.8, 0
	sp.EmissionDirection = Enum.NormalId.Top
	sp.Rate = math.clamp(hx * hz * 0.12, 2, 6)
	sp.Lifetime = NumberRange.new(1.6, 2.6)
	sp.Speed = NumberRange.new(1.5, 3)
	sp.Acceleration = V(0, 0.6, 0)
	sp.SpreadAngle = Vector2.new(12, 12)
	sp.Size = Lobby.seq({ { 0, 0 }, { 0.3, 0.45 }, { 1, 0 } })
	sp.Transparency = Lobby.seq({ { 0, 0.2 }, { 0.7, 0.5 }, { 1, 1 } })
	sp.Parent = box
	return box
end
function Lobby.extras(L)
	Lobby.spinStand(L)
	Lobby.spawnPad(L)
	Lobby.scenery(L)
	-- (B34, general lessons from the owner's other game, in the hood's own dress) one big colour field under the box row's
	-- zone: a painted loading-bay floor in the hood's yellow (the south wall's field above it), flush with the floor (0.06
	-- proud: nothing to trip on); and the Stage 1 door marked by two of the owner's street lamps, their arms over the
	-- spine (warm glows on the lamps, no light pools: the look pass keeps every lobby light faint)
	local fl = L:group('FloorFields')
	local dz = Lobby.DaisAt.Position.Z
	local Wh = Lobby.WH or { x0 = -70, x1 = 54, z1 = 82 }
	studs(fl:box('FloorField', V(-25.5, 0, dz - 1.6), V(25.5, 0.06, Wh.z1), C(236, 190, 84), M.Plastic)).CastShadow = false
	-- (B35) the east quadrant's green field under the gun stand's zone, the SE corner's warm coral under the World Boss
	-- board and the leaderboards, the SW's soft violet under the portal (the west one is the training deck's sand)
	studs(fl:box('FloorField', V(4, 0, Wh.z0), V(Wh.x1, 0.06, 51), C(112, 186, 84), M.Plastic)).CastShadow = false
	-- the north-west and the west margin round the training plinth in a warm sand a shade deeper than the deck
	local sand = C(226, 164, 96)
	studs(fl:box('FloorField', V(Wh.x0, 0, Wh.z0), V(-4, 0.06, Lobby.Plaza.z0), sand, M.Plastic)).CastShadow = false
	studs(fl:box('FloorField', V(Wh.x0, 0, Lobby.Plaza.z0), V(Lobby.Plaza.x0, 0.06, Lobby.Plaza.z1), sand, M.Plastic)).CastShadow = false
	studs(fl:box('FloorField', V(Lobby.Plaza.x1, 0, Lobby.Plaza.z0), V(-4, 0.06, Lobby.Plaza.z1), sand, M.Plastic)).CastShadow = false
	studs(fl:box('FloorField', V(25.5, 0, 51), V(Wh.x1, 0.06, Wh.z1), C(232, 128, 96), M.Plastic)).CastShadow = false
	studs(fl:box('FloorField', V(Wh.x0, 0, Lobby.Plaza.z1), V(-25.5, 0.06, Wh.z1), C(178, 132, 226), M.Plastic)).CastShadow = false
	local ln = L:group('DoorLamps')
	for _, sx in { -1, 1 } do
		local c = ln:at(CFrame.new(sx * 7, 0.06, Lobby.N + 2.6) * CFrame.Angles(0, sx < 0 and 0 or math.pi, 0))
		Lobby.designed(c, 'Scn_StreetLamp', 1, Lobby.Scn.Scn_StreetLamp)
	end
	for _, p in ln.parent:GetDescendants() do if p:IsA('BasePart') then decor(p) end end
	local f = L:group('Fountains')
	local D = Lobby.Dais
	-- along the box row (on the dais deck, in front of the boxes) and along the gun stand's front step
	Lobby.fountain(f, 'BoxRowFountain', Lobby.DaisAt * CFrame.new(0, D.Low, D.RowZ - 4.4), 16, 0.6, C(255, 220, 120))
	Lobby.fountain(f, 'GunStandFountain', CFrame.new(Lobby.ArmoryX + 1.2, 0.4, Lobby.ArmoryZ), 0.6, 14, C(255, 140, 200))
end

---------------------------------------------------------------------------------------------- the corners (B34)
-- The low zones round the plus: the leaderboards' plinth on the east wall (SE), the group corner's plinth (SW). A
-- plinth is the training deck's slab in its dark kerb, the kerb's top 0.46 over the floor (nothing to trip on).
function Lobby.plinth(L, name, x0, x1, z0, z1)
	local Kc = Lobby.Stand.Colors
	local t = L:group(name)
	local kw, h = 1.2, Lobby.Plaza.deck
	studs(t:box('PlazaDeck', V(x0 + kw, 0, z0 + kw), V(x1 - kw, h, z1 - kw), Kc.deck, M.Plastic))
	local ky = math.min(h + 0.1, 0.46)
	for _, e in { { V(x0, 0, z0), V(x1, ky, z0 + kw) }, { V(x0, 0, z1 - kw), V(x1, ky, z1) },
		{ V(x0, 0, z0 + kw), V(x0 + kw, ky, z1 - kw) }, { V(x1 - kw, 0, z0 + kw), V(x1, ky, z1 - kw) } } do
		studs(t:box('PlazaKerb', e[1], e[2], Kc.kerb, M.Plastic), true)
	end
	return h
end
-- the three boards in one straight row along the east wall, facing the hall (west): 10 apart
Lobby.Boards = {
	{ x = 0, z = -10, yaw = 90, lift = 0, name = 'POWER', title = 'Top Power', color = C(255, 166, 40), live = 'PowerLeaderboard', main = 'POWER', extra = 'REBIRTHS' },
	{ x = 0, z = 0, yaw = 90, lift = 0, name = 'REBIRTHS', title = 'Top Rebirth', color = C(255, 70, 70), live = 'ServerLeaderboard', main = 'REBIRTHS', extra = 'POWER' },
	{ x = 0, z = 10, yaw = 90, lift = 0, name = 'CASH', title = 'Top Cash', color = C(120, 226, 70), live = 'CashLeaderboard', main = 'CASH', extra = 'STAGE' },
}
-- Scale a built model's parts about a frame's origin (k < 1 shrinks it toward cf; cf in the map frame).
function Lobby.scaleAbout(model, cf, k)
	cf = V2.Origin * cf
	for _, p in model:GetDescendants() do
		if p:IsA('BasePart') then
			local rel = cf:ToObjectSpace(p.CFrame)
			p.Size *= k
			p.CFrame = cf * (rel.Rotation + rel.Position * k)
		end
	end
end
function Lobby.corners(L)
	local Pl = Lobby.Plan
	local centre = Lobby.Centre
	-- WORLD 2 (SW): the portal turned to the crossing; 0.85 of its size
	local w2 = Pl.World2
	local g = L:group('World2Corner')
	local at = V(w2.x, 0.06, w2.z)
	local cf = CFrame.lookAt(at, V(w2.look.X, 0.06, w2.look.Z))
	local model = Lobby.world2(g, cf)
	if model then Lobby.scaleAbout(model, cf, w2.scale or 1) end
	Lobby.Slots.World2 = cf
	Lobby.Slots.World2Portal = cf
	local words = Lobby.signWords(g, (cf * CFrame.new(0, 17.5 * (w2.scale or 1), -1)).Position, 12, 3.6, {
		{ 'Title', 'World 2', 0.6, Lobby.Grad.pink, 4.5 },
		{ 'Soon', 'COMING SOON!', 0.4, Lobby.Grad.white, 3.5 },
	}, 120)
	words.WorldLabel:SetAttribute('FadeNear', 30)
	words.WorldLabel:SetAttribute('FadeFar', 48)
	-- the leaderboards (SE): an angled row toward the east wall, each board's face turned to the crossing
	local bg = L:group('BoardCorner'):group('Leaderboards')
	for k, b in Lobby.Boards do
		local p = Pl.Boards[k]
		local bcf = CFrame.lookAt(V(p[1], 0.06, p[2]), V(centre.X, 0.06, centre.Z))
		Lobby.Slots['Leaderboard' .. k] = bcf
		Lobby.leaderboard(bg, bcf, b)
	end
end

---------------------------------------------------------------------------------------------- special-sale spots (B35)
-- (the owner: "not even game passes we need there, we need the special sales for shoes or in general the special sales")
-- Two spots beside the spine before the door, the place of ref_W01's "MOST OP!" showcase. Each spot is a frame (its
-- centre on the floor, turned to where you land) and one builder: today Lobby.saleOffer, the Robux shoe offer on its
-- showcase pad (boxPadStand: the box turning over the pad, its name and its price with the Robux sign, the Buy prompt
-- that opens the Store at its card). Honest words only: no stock, no timer, no "limited". The owner's renders will
-- replace the look in Lobby.saleOffer; the spots (Lobby.Plan.Sales) stay.
function Lobby.saleOffer(c, sale)
	local model = Lobby.boxPadStand(c, sale.Box, sale.Key, sale.Tone, sale.Tag, sale.Special, sale.Lift)
	Lobby.limitedLine(model)
	return model
end
-- The sale's third line under the price, for the limiteds system to come (stock left, time left on the sale): the
-- words stack grows 1.2 studs upward (the name and the price keep their size, nothing moves down onto the box) and gets
-- a hidden, EMPTY row (TextLabels LimitedStock in red and LimitedTimer in white, chunky outlined; the billboard's
-- LimitedLine attribute marks it). The map never writes
-- words into it: Shared/Config/Limiteds fills it (a static placeholder only in Studio, see there; later the real stock
-- and timer).
Lobby.LimitedRowH = 1.2
function Lobby.limitedLine(model)
	local anchor = model and model:FindFirstChild('WordsAnchor', true)
	local g = anchor and anchor:FindFirstChild('WorldLabel')
	if not g then return nil end
	local w, h0 = g.Size.X.Scale, g.Size.Y.Scale
	local h = h0 + Lobby.LimitedRowH
	local k = h0 / h
	for _, t in g:GetChildren() do
		if t:IsA('GuiObject') then
			t.Position = UDim2.new(t.Position.X.Scale, t.Position.X.Offset, t.Position.Y.Scale * k, t.Position.Y.Offset)
			t.Size = UDim2.new(t.Size.X.Scale, t.Size.X.Offset, t.Size.Y.Scale * k, t.Size.Y.Offset)
		end
	end
	g.Size = UDim2.fromScale(w, h)
	anchor.CFrame += V(0, Lobby.LimitedRowH / 2, 0)
	-- (two labels straight in the billboard, each hidden until Limiteds fills it; LimitedLine marks the billboard)
	g:SetAttribute('LimitedLine', true)
	local stock = line(g, 'LimitedStock', '', P.white, FONT.title, k, 1 - k, Lobby.Ink, 3)
	stock.Position, stock.Size, stock.TextXAlignment = UDim2.fromScale(0.02, k), UDim2.fromScale(0.54, 1 - k), Enum.TextXAlignment.Right
	Lobby.fill(stock, Lobby.Grad.red)
	local timer = line(g, 'LimitedTimer', '', P.white, FONT.title, k, 1 - k, Lobby.Ink, 3)
	timer.Position, timer.Size, timer.TextXAlignment = UDim2.fromScale(0.6, k), UDim2.fromScale(0.38, 1 - k), Enum.TextXAlignment.Left
	Lobby.fill(timer, Lobby.Grad.white)
	stock.Visible, timer.Visible = false, false
	return g
end
function Lobby.saleSpot(g, sale)
	local at = V(sale.x, 0.06, sale.z)
	local cf = CFrame.lookAt(at, V(Lobby.SpawnAt.X, 0.06, Lobby.SpawnAt.Z))
	Lobby.Slots['Sale_' .. sale.Name] = cf
	Lobby.Slots['BoxPad_' .. sale.Box] = cf
	local model = Lobby.saleOffer(g:at(cf), sale)
	if model then model:SetAttribute('SaleSpot', sale.Name) end
	return model
end
function Lobby.stands(L)
	local g = L:group('SaleSpots')
	for _, sale in Lobby.Plan.Sales do Lobby.saleSpot(g, sale) end
	return g
end
