---------------------------------------------------------------------------------------------- look (B31)
-- The look pass over the lobby (brief 31 LOOK, $S/brief/B31/LOOK_RECIPE.md): the reference's toy-plastic finish instead
-- of the B30 hall's cold, studded-everywhere look. Runs once after the lobby is built (V2.Build), touches only the
-- Lobby model, and never moves, renames or removes a part that gameplay reads (lanes, pads, prompts, slots).
--   1. Studs: Roblox's Studs surface (high-contrast white/black strokes in the real client, brief/ref23
--      ours_studio_spawn.png) comes off every face. Walkable ground (an upright part whose top is near the deck)
--      gets the reference's faint tone-on-tone studs instead: one Texture on its top face (UIKit's StudBevel, one
--      stud per tile, drawn white at Look.StudAlpha). Walls, pillars, props and items stay flat clean colour; the
--      cliffs outside keep faint studs on every face (ref_product_pads: studded clay cliffs).
--   2. Material: Plastic -> SmoothPlastic (flat colour, no grain); Neon, Glass and the rest keep theirs.
--   3. Palette: the hall's cold teal / periwinkle / navy swapped for warm saturated fields (Look.Palettes).
--   4. Variant A "warehouse done right": the roof opens (glass, panels and skylight frames go; the girders stay and
--      throw stripes of shadow), warm clay brick walls, a light warm concrete field, lavender studded walks.
--      Variant B "open hood plaza": the same slice outdoors (rules 16/19 relaxed for the comparison only): the hall
--      shell goes, the field turns to studded grass, the cliffs and hood blocks frame it.
--   5. Items on product pads: a ground halo and slow star glints (built-in textures only; box pads keep BoxModels.fx).
-- Look.Variant: 'A' (default), 'B', or 'off' (the B30 look). Look.Lighting names the HoodLighting preset per variant.
local Look = {}
Look.Variant = 'P' -- (B31 PLAZA: the open plaza, rule 26; 'A' / 'B' were the slice's variants)
Look.StudAlpha = 0.15 -- the stud texture's Transparency (B31 PLAZA, critic 1: the ref's walks and grass show their studs plainly, a lit patch's
-- luminance spread 15-25 of 255; 0.45 measured 0.4, a dead fill)
Look.Lighting = { P = 'HoodToy', A = 'HoodToy', B = 'HoodToy', off = 'HoodSun' }
-- Old colour (r,g,b) -> new colour, per variant. Keys are the hall's own colours (Lobby.Colors, Lobby.FieldColor and the
-- shades the hall builder derives), measured by area in the B30 lobby (work31_LOOK/tools: 57% of its surface was studded).
local function key(c) return string.format('%d,%d,%d', math.round(c.R * 255), math.round(c.G * 255), math.round(c.B * 255)) end
Look.Palettes = {
	A = {
		-- walls: clay brick (ref cliff clay H26 S84 V80, darker trims), a paler band, a deep brick base
		['126,183,193'] = C(224, 124, 56), ['150,202,210'] = C(236, 150, 96), ['86,130,152'] = C(142, 62, 44),
		['104,158,174'] = C(182, 88, 54),
		-- the field: light warm concrete (the walks stay the reference's lavender-grey)
		['150,152,162'] = C(212, 202, 186), ['204,206,226'] = C(238, 232, 220),
		-- pillars and the dais: warm cream stone with brick-red caps and bases
		['116,120,170'] = C(204, 182, 150), ['150,152,196'] = C(236, 222, 196), ['98,104,150'] = C(158, 78, 54),
		['200,204,228'] = C(250, 242, 226), ['126,130,178'] = C(214, 192, 160), ['176,182,218'] = C(232, 218, 196),
		-- the girders: toy-red steel (they stay; the roof between them opens)
		['72,88,118'] = C(186, 56, 44), ['84,104,134'] = C(200, 70, 52), ['76,100,138'] = C(170, 60, 46),
		-- windows and frames: dark warm brown frames, cream panels
		['18,34,72'] = C(70, 42, 34), ['146,154,188'] = C(226, 206, 176), ['150,156,186'] = C(226, 206, 176),
		['184,190,220'] = C(236, 220, 196), ['112,118,158'] = C(150, 120, 104),
	},
}
Look.Palettes.B = table.clone(Look.Palettes.A)
Look.Palettes.B['150,152,162'] = C(96, 200, 52) -- the field is grass outdoors (ref W01 grass 90,203,46 lit)
Look.Grass = C(96, 200, 52)
Look.Palettes.P = {} -- (the plaza builds in its own colours, e3_plaza)

function Look.studTexture()
	if Look._stud ~= nil then return Look._stud end
	local ok, Kit = pcall(require, ReplicatedStorage.Shared.UIKit)
	Look._stud = ok and Kit and (Kit.StudBevel ~= '' and Kit.StudBevel or Kit.StudTile) or ''
	return Look._stud
end
-- Faint studs on one face (or every face): a white StudBevel tile per stud.
function Look.faintStuds(p, faces)
	local id = Look.studTexture()
	if id == '' then return end
	for _, f in faces do
		local t = Instance.new('Texture')
		t.Name = 'LookStuds'
		t.Texture = id
		t.Face = f
		t.StudsPerTileU, t.StudsPerTileV = 1, 1
		t.Color3 = Color3.new(1, 1, 1)
		t.Transparency = Look.StudAlpha
		t:SetAttribute('PreviewTexture', 'stud_bevel')
		t.Parent = p
	end
end
local FACES = { 'TopSurface', 'BottomSurface', 'FrontSurface', 'BackSurface', 'LeftSurface', 'RightSurface' }
local ALL = { Enum.NormalId.Top, Enum.NormalId.Front, Enum.NormalId.Back, Enum.NormalId.Left, Enum.NormalId.Right }
function Look.isStudded(p)
	for _, f in FACES do if p[f] == S.Studs then return true end end
	return false
end

-- Variant B: the hall's shell goes (everything over the deck in Hall and Roof, the World 2 portal stays).
function Look.openPlaza(lobby, deckY)
	for _, name in { 'Hall', 'Roof' } do
		local g = lobby:FindFirstChild(name)
		if g then
			for _, p in g:GetDescendants() do
				if p:IsA('BasePart') and not p:FindFirstAncestor('World2Portal') then
					local top = p.CFrame.Position.Y + p.Size.Y / 2
					if name == 'Roof' or top > deckY + 1.6 then p:Destroy() end
				end
			end
		end
	end
end
-- Variant A: the roof opens to the sky; the girders stay.
function Look.openRoof(lobby)
	local roof = lobby:FindFirstChild('Roof')
	if not roof then return end
	for _, p in roof:GetDescendants() do
		if p:IsA('BasePart') and (p.Name == 'RoofCeiling' or p.Name == 'RoofPanel' or p.Name:find('^RoofSkylight')) then p:Destroy() end
	end
end

-- (B34, the owner: "Classic studs everywhere", like their "Alien" place: Plastic with all six faces SurfaceType.Studs
-- on the lobby's built blocks) the floor slabs, walks and curbs, the decks, kerbs and plinths, the dais and the armory's
-- apron, the walls, the roof's steel and the cliffs and terraces outside. Smooth stay: Neon glows, glass, anything see-
-- through, anything carrying words (a SurfaceGui), signs, boards, screens and lamps, every lane, pad, item and prop, and
-- the owner's designed meshes (MeshParts). The faint stud texture goes wherever real studs replace it.
Look.Classic = true
Look.ClassicNames = { '^Concrete$', '^Threshold$', '^Grass$', '^Wall', '^Roof', '^Path', '^SpawnSquare$', '^Plaza', '^Dais',
	'^Apron', '^Cliff', '^Floor$', '^FloorField$' }
Look.ClassicKeep = { 'Sign', 'Board', 'Glow', 'Lamp', 'Screen', 'Label', 'Text', 'Neon', 'Nosing', 'Hazard' }
function Look.classicStuds(lobby)
	local n = 0
	for _, p in lobby:GetDescendants() do
		if p:IsA('Part') and p.Shape == Enum.PartType.Block and p.Material ~= M.Neon and p.Material ~= M.Glass
			and p.Transparency < 0.05 and not p:FindFirstChildOfClass('SurfaceGui') then
			local hit = false
			for _, pat in Look.ClassicNames do if p.Name:find(pat) then hit = true break end end
			if hit then for _, k in Look.ClassicKeep do if p.Name:find(k) then hit = false break end end end
			if hit then
				for _, t in p:GetChildren() do if t:IsA('Texture') and t.Name == 'LookStuds' then t:Destroy() end end
				p.Material = M.Plastic
				for _, f in FACES do p[f] = S.Studs end
				n += 1
			end
		end
	end
	lobby:SetAttribute('ClassicStudParts', n)
end
-- Items over product pads and box pads: a soft halo on the pad under the item and a few big star glints on it.
function Look.itemFX(lobby)
	for _, m in lobby:GetDescendants() do
		if m:IsA('Model') and m.Name:find('^PassBoard_') then -- (box pads: their chests carry BoxModels.fx's own glow disc and bob, b438ce4)
			local box = m:FindFirstChild('SparkleBox', true)
			local glow = m:FindFirstChild('PadGlow', true) or m:FindFirstChild('BoxPadGlow', true)
			local tone = glow and glow.Color or C(255, 230, 120)
			local _ = box -- (B31 PLAZA: the pads' own PadShine glints instead)
			if glow then
				local att = Instance.new('Attachment')
				att.Name = 'LookHalo'
				local r = glow.CFrame
				local hy = math.abs(r.RightVector.Y) * glow.Size.X / 2 + math.abs(r.UpVector.Y) * glow.Size.Y / 2 + math.abs(r.LookVector.Y) * glow.Size.Z / 2
				att.CFrame = r:ToObjectSpace(CFrame.new(glow.CFrame.Position + Vector3.new(0, hy + 0.06, 0)))
				att.Parent = glow
				local h = Instance.new('ParticleEmitter')
				h.Name = 'LookHalo'
				h.Texture = 'rbxasset://textures/glow.png'
				h:SetAttribute('PreviewTexture', 'softglow')
				h.Orientation = Enum.ParticleOrientation.VelocityPerpendicular
				h.EmissionDirection = Enum.NormalId.Top
				h.Speed = NumberRange.new(0.01)
				h.Color = ColorSequence.new(tone:Lerp(Color3.new(1, 1, 1), 0.1)) -- (B31 PLAZA: the pad keeps its colour)
				h.LightEmission, h.LightInfluence = 1, 0
				h.Rate = 0.8
				h.Lifetime = NumberRange.new(2.5)
				local w = math.max(glow.Size.X, glow.Size.Y, glow.Size.Z) * 1.5
				h.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, w * 0.8), NumberSequenceKeypoint.new(1, w) })
				h.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.3, 0.72), NumberSequenceKeypoint.new(0.7, 0.76), NumberSequenceKeypoint.new(1, 1) })
				h.Parent = att
			end
		end
	end
end

-- (B31 PLAZA) Saturation over this on a lane's surfaces comes down to it (critic 7: big fields S 0.55-0.75; the pad tops,
-- prices and items keep theirs). Measured in the colour the part is built with; HoodToy's grade adds ~0.1 on screen.
Look.BigS = 0.38 -- (B31 PLAZA, lead: the lanes' view toward the reference's median S ~0.5)
Look.Layers = { Grass = 4, Path = 3, SpawnSquare = 3, PlazaDeck = 2, Concrete = 1 } -- (stud layers on the plaza's ground, by part name)
local function calm(col, maxS)
	local h, sat, v = col:ToHSV()
	if sat <= maxS then return col end
	return Color3.fromHSV(h, maxS, v)
end
function Look.apply(root)
	local v = Look.Variant
	if v == 'off' then return end
	local lobby = root:FindFirstChild('Lobby', true)
	if not lobby then return end
	local deckY = (V2.Origin * CFrame.new(SPAWN)).Y
	if v == 'B' then Look.openPlaza(lobby, deckY) elseif v == 'A' then Look.openRoof(lobby) end
	local pal = Look.Palettes[v] or {}
	local outside = lobby:FindFirstChild('Surroundings')
	local training = lobby:FindFirstChild('Training')
	for _, p in lobby:GetDescendants() do
		if p:IsA('BasePart') then
			local new = pal[key(p.Color)]
			if new then p.Color = new end
			if p.Material == M.Plastic then p.Material = M.SmoothPlastic end
			-- (B31 PLAZA, critic 7 and the user's "tone down" for the themed bays) big lane surfaces calm down, and a
			-- big neon face (a glowing backboard, a lip) turns into flat colour: glow only on small accents
			if v == 'P' and training and p:IsDescendantOf(training) and p.Transparency < 1 then
				local s = p.Size
				if math.max(s.X * s.Y, s.Y * s.Z, s.X * s.Z) >= 3 then p.Color = calm(p.Color, Look.BigS) end
				if p.Material == M.Neon and math.max(s.X, s.Y, s.Z) > 1.5 then p.Material = M.SmoothPlastic end
			end
			if Look.isStudded(p) then
				for _, f in FACES do p[f] = S.Smooth end
				local upright = p.CFrame.UpVector.Y > 0.99 and p:IsA('Part') and p.Shape == Enum.PartType.Block
				local top = p.CFrame.Position.Y + p.Size.Y / 2
				if outside and p:IsDescendantOf(outside) then
					if upright then Look.faintStuds(p, ALL) end
				elseif v == 'P' and Look.Layers[p.Name] then
					-- (critic 1: the ref's grass and walks show their studs plainly, a lit patch's spread 15-25; one layer of
					-- the faint bevel measured 3-7 in the renderer, so the plaza's ground stacks a few)
					for _ = 1, Look.Layers[p.Name] do Look.faintStuds(p, { Enum.NormalId.Top }) end
				elseif upright and top <= deckY + 2.6 and (v ~= 'P' or p.Size.Y <= 1.7) and p.Size.X >= 3 and p.Size.Z >= 3 then
					Look.faintStuds(p, { Enum.NormalId.Top }) -- (B31 PLAZA: walkable ground only: the grass, walks, decks, mats, pads)
				end
			end
		end
	end
	-- outdoors the field is grass (variant B): the hall floor slab and the edge fill
	if v == 'B' then
		for _, p in lobby:GetDescendants() do
			if p:IsA('BasePart') and p.Name == 'Floor' and p.Parent and p.Parent.Name == 'Hall' then p.Color = Look.Grass end
		end
	end
	if Look.Classic then Look.classicStuds(lobby) end
	-- (B34, the Huss look: "objects don't have light only around them") every lamp in the lobby stays faint: a glow on
	-- its object, no pool on the floor, no shadows of its own
	for _, l in lobby:GetDescendants() do
		if l:IsA('PointLight') or l:IsA('SpotLight') or l:IsA('SurfaceLight') then
			l.Brightness, l.Range, l.Shadows = math.min(l.Brightness, 0.5), math.min(l.Range, 8), false
		end
	end
	Look.itemFX(lobby)
	lobby:SetAttribute('LookVariant', v)
end
V2.Look = Look
V2.Stations = Stations
