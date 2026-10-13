-- Fonts: the one type family the whole game uses, by role (brief 28).
--
-- The user's references (the hero simulator's Store, Pets and Rebirth windows, its HUD and world signs, the shop in the
-- Store video, the aura trainer) set 65 of 71 measured words in Montserrat, the family Roblox now draws for the old
-- Gotham fonts (the other 6 are the pet-count tags in one Pets window). Their window titles, section heads and detail
-- lines are its Bold; item and box names, HUD buttons, prices, counts and world signs are heavier (Black is the nearest
-- weight Roblox ships). The text is white or a bright tone with a thick plain-black outline.
-- (Brief 28's font report has the evidence: the crops, the glyph sheet and the runners-up.)
--
-- Use a role, never a family path, so the look changes here alone:
--   label.FontFace = Fonts.Title
--   Fonts.apply(label, 'Title', { stroke = true })   -- the face and the house outline, sized from the TextSize
--   Fonts.apply(label, 'Body', { stroke = 2 })        -- the face and a 2 px house outline
-- Roles:
--   Title    Black: the shoe's name (the reveal, cards, the index), box names, rarity words, HUD buttons, world signs
--   Heading  Bold: window titles ("Store", "Rebirth") and section heads
--   Body     Bold: detail lines, descriptions, small print
--   Number   Black: counters, prices, chances, timers
--   Italic   Bold italic: the Store's "~Gamepass~" section heads
-- Roblox ships Montserrat in Regular, Medium, Bold and Black only (no ExtraBold, no italic file), so the roles use Bold
-- and Black. Fonts.Enum holds an Enum.Font per role for the few APIs that still take one (TextService:GetTextSize):
-- the Gotham names, which Roblox maps to Montserrat.
local Fonts = {}

Fonts.Family = 'rbxasset://fonts/families/Montserrat.json'
local W = Enum.FontWeight

Fonts.Title = Font.new(Fonts.Family, W.Heavy)
Fonts.Heading = Font.new(Fonts.Family, W.Bold)
Fonts.Body = Font.new(Fonts.Family, W.Bold)
Fonts.Number = Font.new(Fonts.Family, W.Heavy)
Fonts.Italic = Font.new(Fonts.Family, W.Bold, Enum.FontStyle.Italic)

Fonts.Roles = { 'Title', 'Heading', 'Body', 'Number', 'Italic' }

Fonts.Enum = {
	Title = Enum.Font.GothamBlack,
	Heading = Enum.Font.GothamBold,
	Body = Enum.Font.GothamBold,
	Number = Enum.Font.GothamBlack,
	Italic = Enum.Font.GothamBold,
}

-- The house outline: plain black, round joins, about a tenth of the text size (less on the big window titles, whose
-- outline in the references is no thicker than the lines under them), never thinner than 1.5 px.
Fonts.Outline = {
	Color = Color3.fromRGB(6, 6, 8),
	Ratio = { Title = 0.09, Heading = 0.075, Body = 0.1, Number = 0.1, Italic = 0.09 },
	Min = 1.5,
	Scaled = 3, -- a TextScaled label has no fixed size to go by: this many px unless opts.size says how big it draws
}

local lower = {}
for _, role in Fonts.Roles do lower[string.lower(role)] = role end

-- The role's proper name ('title' and 'Title' both work); anything else is Body.
function Fonts.role(role)
	if type(role) == 'string' then
		if Fonts.Outline.Ratio[role] then return role end
		local r = lower[string.lower(role)]
		if r then return r end
	end
	return 'Body'
end

-- The Font for a role.
function Fonts.face(role)
	return Fonts[Fonts.role(role)]
end

-- The house outline thickness (px) for text of this size in this role, rounded to half a pixel.
function Fonts.strokeFor(size, role)
	local ratio = Fonts.Outline.Ratio[Fonts.role(role)]
	return math.max(Fonts.Outline.Min, math.floor((size or 0) * ratio * 2 + 0.5) / 2)
end

-- Sets textObject.FontFace to the role's face. opts (all optional):
--   stroke        true: the house outline sized from the TextSize (or opts.size); a number: that many px
--   strokeColor   the outline colour (the house black otherwise)
--   transparency  the outline's Transparency (0)
--   size          the size to size a true outline from, for a TextScaled label
-- With a stroke it adds a UIStroke, or updates the one the label already has (never two), and hides the legacy
-- TextStroke so the outline is not drawn twice. Returns the text object and its UIStroke (if any).
function Fonts.apply(textObject, role, opts)
	opts = opts or {}
	local r = Fonts.role(role)
	textObject.FontFace = Fonts[r]
	local s = textObject:FindFirstChildOfClass('UIStroke')
	if opts.stroke then
		local thickness
		if type(opts.stroke) == 'number' then
			thickness = opts.stroke
		elseif opts.size then
			thickness = Fonts.strokeFor(opts.size, r)
		elseif textObject.TextScaled then
			thickness = Fonts.Outline.Scaled
		else
			thickness = Fonts.strokeFor(textObject.TextSize, r)
		end
		if not s then
			s = Instance.new('UIStroke')
			s.Parent = textObject
		end
		s.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
		s.LineJoinMode = Enum.LineJoinMode.Round
		s.Color = opts.strokeColor or Fonts.Outline.Color
		s.Thickness = thickness
		s.Transparency = opts.transparency or 0
		textObject.TextStrokeTransparency = 1
	end
	return textObject, s
end

-- Every text object under root (root included) that still uses another family gets its role's face: Title when it is
-- big (TextSize 36 or more, or TextScaled on a BillboardGui or SurfaceGui), Body otherwise. Outlines are left alone.
-- Text that keeps its own face on purpose is skipped: the pixel "Power: X" line on the gate signs (Arcade, as on the
-- references' corridor sign), monospaced logs (Code, RobotoMono) and anything with the attribute KeepFont = true.
-- For text built by code we may not edit (the map builders): run it once after they build. Returns how many changed.
Fonts.Keep = { Arcade = true, Code = true, RobotoMono = true, PressStart2P = true }
function Fonts.keeps(d)
	if d:GetAttribute('KeepFont') == true then return true end
	local ok, f = pcall(function() return d.Font end)
	if ok and typeof(f) == 'EnumItem' and Fonts.Keep[f.Name] then return true end
	local okF, fam = pcall(function() return d.FontFace.Family end)
	if okF and type(fam) == 'string' then
		local name = string.match(fam, 'families/(%w+)%.json')
		if name and Fonts.Keep[name] then return true end
	end
	return false
end
function Fonts.sweep(root, role)
	local n = 0
	local function one(d)
		if (d:IsA('TextLabel') or d:IsA('TextButton') or d:IsA('TextBox')) and not Fonts.keeps(d) then
			local ok, fam = pcall(function() return d.FontFace.Family end)
			if not (ok and fam == Fonts.Family) then
				local r = role
				if not r then
					local inWorld = d.TextScaled and not d:FindFirstAncestorWhichIsA('ScreenGui')
					r = (d.TextSize >= 36 or inWorld) and 'Title' or 'Body'
				end
				d.FontFace = Fonts.face(r)
				n += 1
			end
		end
	end
	one(root)
	for _, d in root:GetDescendants() do one(d) end
	return n
end

return Fonts
