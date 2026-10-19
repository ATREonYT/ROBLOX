-- Crate opening (owner, Oct 19: "Also create a good case opening animation"). Opened by Shop > CRATES > OPEN.
-- The server decides everything first (ActionService "OpenCrate": takes the Aura once, rolls with the shown odds and
-- the pity counter, gives the prize, and builds the reel from honest draws); this screen only animates to its answer:
--   1. the crate shakes harder and harder, its lid pops off with a ring and sparks (0.85 s);
--   2. a reel of item cards (their real pictures, rims in the rarity colour) opens and spins past the green centre
--      marker, fast at first and easing out for ~5 s to stop on the prize, a soft tick for each card passing;
--   3. the prize card lifts, the rest dim, then it zooms up in front with turning rays in its rarity colour, its name
--      and rarity in big Gotham Heavy Italic and "NEW!" or "Duplicate: +N coins". Rarer prizes get more: Rare rays,
--      Epic one soft flash, Legendary and up a spark burst and a second ring too.
-- Kid-safe: every card on the reel is a fair draw with the real odds (Shared/CrateRoll.strip), nothing is planted next
-- to the stop; at most one flash a second; the odds and the pity counter are in the Shop and on this screen.
-- Tap anywhere while it runs to skip to the prize. OPEN AGAIN opens another (same price), BACK returns to the Shop.
-- Not in a round or during the Secret cutscene (HuzzCinematic): it won't start, and closes if the cutscene begins.
-- Laid out at 1280 x 720 like the Spin the Wheel screen; plain frames (no CanvasGroup). Every moving part is driven by
-- one RenderStepped loop from its own clock (so the offline film plays exactly as the game does).
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Crates = require(Shared.Config.Crates)
local CrateRoll = require(Shared.CrateRoll)
local Format = require(Shared.Format)
local Net = require(Shared.Net)
local UI = script.Parent.Parent
local Theme = require(UI.Theme)
local Kit = require(UI.Kit)
local Motion = require(UI.Motion)
local State = require(UI.State)
local Toast = require(UI.Toast)
local ModalManager = require(UI.ModalManager)
local CrateArt = require(UI.CrateArt)
local Sfx = require(UI.Parent.Gameplay.Sfx)

local C, F = Theme.Colors, Theme.Fonts
local new = Kit.new
local INK = C.TitleStroke

local CrateOpen = {}

local W, H = 1280, 720
local CX = W / 2
local REEL = { X = 90, Y = 236, W = 1100, H = 226 } -- the reel's panel
local CARD = { W = 150, H = 196, Pitch = 162, Top = 15 }
local START_CARD = 4 -- the card under the marker before the spin (three honest cards show to its left)
-- the timeline (seconds from the server's answer)
local T = {
	ShakeEnd = 0.6, PopEnd = 0.85, ReelIn = 0.62, ReelInLen = 0.3,
	Spin = 0.8, SpinLen = 5.2, LandLen = 0.5, RevealLen = 0.45,
}
T.SpinEnd = T.Spin + T.SpinLen
T.Reveal = T.SpinEnd + T.LandLen
local SPARKS = 16
local RAYS_SPEED = 22 -- degrees a second

local function clamp01(x: number): number return math.clamp(x, 0, 1) end
local function easeOutBack(u: number): number
	local c1 = 1.70158
	return 1 + (c1 + 1) * (u - 1) ^ 3 + c1 * (u - 1) ^ 2
end
local function easeOut(u: number, p: number): number return 1 - (1 - u) ^ p end

-- White words with a dark outline (the game's big-moment text).
local function words(props: { [string]: any }, thickness: number?): TextLabel
	props.BackgroundTransparency = 1
	props.TextColor3 = props.TextColor3 or C.Text
	props.FontFace = props.FontFace or F.Heading
	props.TextXAlignment = props.TextXAlignment or Enum.TextXAlignment.Center
	props.TextWrapped = false
	local l = new("TextLabel", props)
	new("UIStroke", { Name = "Outline", Color = INK, Thickness = thickness or 2, LineJoinMode = Enum.LineJoinMode.Round, Parent = l })
	return l
end

local function circle(props: { [string]: any }, d: number, children: { Instance }?)
	props.Size = UDim2.fromOffset(d, d)
	props.AnchorPoint = Vector2.new(0.5, 0.5)
	props.BorderSizePixel = 0
	local f = new("Frame", props, children)
	local corner = f:FindFirstChildOfClass("UICorner") or new("UICorner", { Parent = f })
	corner.CornerRadius = UDim.new(0.5, 0) -- (set every time: a saved corner comes back at 8 px)
	return f
end

function CrateOpen.build(parent: Instance)
	local player = Players.LocalPlayer
	local holder = new("Frame", { Name = "CrateOpen", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(W, H), BackgroundTransparency = 1, Visible = false, ZIndex = 20, Parent = parent })
	new("UIScale", { Name = "FitScale", Parent = holder })
	local group = new("Frame", { Name = "Group", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Visible = false, Parent = holder })
	local openScale = new("UIScale", { Name = "OpenScale", Parent = group })

	-- top: the crate's name and your Aura
	local title = words({ Name = "Title", Text = "", TextSize = 44, Position = UDim2.fromOffset(240, 46), Size = UDim2.fromOffset(800, 52), ZIndex = 5, Parent = group }, 3)
	local auraBox = new("Frame", { Name = "Aura", Position = UDim2.fromOffset(1060, 26), Size = UDim2.fromOffset(190, 46), BackgroundColor3 = C.Pill, BackgroundTransparency = 0.15, BorderSizePixel = 0, ZIndex = 5, Parent = group }, { Kit.corner(23), Kit.stroke(C.Frame, 3) })
	Kit.icon("AuraStar", { Name = "Icon", AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 6, 0.5, 0), Size = UDim2.fromOffset(38, 38), ZIndex = 6, Parent = auraBox })
	local auraText = words({ Name = "Amount", Text = "0", FontFace = F.Number, TextSize = 24, TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.fromOffset(52, 0), Size = UDim2.fromOffset(130, 46), ZIndex = 6, Parent = auraBox }, 2)

	-- the crate, with green light turning behind it
	local crateRays = Kit.art("LightRays", { Name = "CrateRays", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(CX, 350), Size = UDim2.fromOffset(560, 560), ScaleType = Enum.ScaleType.Stretch, ImageColor3 = C.Accent, ImageTransparency = 0.55, ZIndex = 2, Parent = group })
	local crate, crateBody, lid = CrateArt.crate(group, 250, UDim2.fromOffset(CX, 350), "Crate")
	crate.ZIndex = 3
	local cratePop = crate:FindFirstChild("Pop") :: UIScale
	local lidHome = lid.Position

	-- the reel: a see-through kit panel, the cards inside a clipped window, soft fades at both ends, the marker
	local reel = new("Frame", { Name = "Reel", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(REEL.X + REEL.W / 2, REEL.Y + REEL.H / 2), Size = UDim2.fromOffset(REEL.W, REEL.H), BackgroundColor3 = C.Panel, BackgroundTransparency = 0.12, BorderSizePixel = 0, ZIndex = 4, Parent = group }, { Kit.corner(10), new("UIStroke", { Name = "Frame", Color = C.Frame, Thickness = 4 }) })
	Kit.studPattern(reel, 0.22)
	local window = new("Frame", { Name = "Window", Position = UDim2.fromOffset(4, 4), Size = UDim2.new(1, -8, 1, -8), BackgroundTransparency = 1, ClipsDescendants = true, ZIndex = 5, Parent = reel })
	local strip = new("Frame", { Name = "Strip", Position = UDim2.fromOffset(0, CARD.Top - 4), Size = UDim2.fromOffset(CARD.W, CARD.H), BackgroundTransparency = 1, ZIndex = 5, Parent = window })
	for i, side in { 0, 1 } do
		local fade = new("Frame", { Name = if i == 1 then "FadeLeft" else "FadeRight", AnchorPoint = Vector2.new(side, 0), Position = UDim2.fromScale(side, 0), Size = UDim2.new(0, 230, 1, 0), BackgroundColor3 = C.Panel, BorderSizePixel = 0, ZIndex = 8, Parent = window })
		new("UIGradient", { Rotation = if side == 0 then 0 else 180, Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.05), NumberSequenceKeypoint.new(1, 1) }), Parent = fade })
	end
	local markerGlow = new("Frame", { Name = "MarkerGlow", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.5, 0), Size = UDim2.new(0, 16, 1, 4), BackgroundColor3 = C.Accent, BackgroundTransparency = 0.7, BorderSizePixel = 0, ZIndex = 9, Parent = reel }, { Kit.corner(8) })
	new("Frame", { Name = "Marker", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(0, 4, 1, 4), BackgroundColor3 = C.Accent, BorderSizePixel = 0, ZIndex = 10, Parent = reel }, { Kit.stroke(C.Frame, 1) })
	local pointers = {}
	for i, y in { 0, 1 } do
		local p = new("Frame", { Name = if i == 1 then "PointerTop" else "PointerBottom", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, y, if y == 0 then -10 else 10), Size = UDim2.fromOffset(26, 26), Rotation = 45, BackgroundColor3 = C.Accent, BorderSizePixel = 0, ZIndex = 11, Parent = reel }, { Kit.corner(4), Kit.stroke(C.Frame, 3) })
		pointers[i] = p
	end
	local hint = words({ Name = "Hint", Text = "TAP TO SKIP", FontFace = F.Name, TextSize = 18, TextColor3 = C.SubText, Position = UDim2.fromOffset(440, REEL.Y + REEL.H + 26), Size = UDim2.fromOffset(400, 24), ZIndex = 5, Parent = group }, 1.5)

	-- the prize, in front: turning rays and a glow in its rarity colour, the card, the big words
	local flash = new("Frame", { Name = "Flash", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(3, 3), BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 1, BorderSizePixel = 0, Visible = false, ZIndex = 40, Parent = group })
	local prize = new("Frame", { Name = "Prize", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(CX, 330), Size = UDim2.fromOffset(320, 344), BackgroundTransparency = 1, Visible = false, ZIndex = 20, Parent = group })
	-- two layers of rays turning opposite ways (Rare and up), and a soft halo hugging the card (three rims, fading out)
	local prizeRays = Kit.art("LightRays", { Name = "PrizeRays", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(1000, 1000), ScaleType = Enum.ScaleType.Stretch, ImageTransparency = 0, ZIndex = 17, Parent = prize })
	local prizeRays2 = Kit.art("LightRays", { Name = "PrizeRaysInner", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(720, 720), Rotation = 30, ScaleType = Enum.ScaleType.Stretch, ImageTransparency = 0, ZIndex = 18, Parent = prize })
	local halos = {}
	for i, h in { { 10, 0.5 }, { 24, 0.74 }, { 44, 0.88 } } do
		halos[i] = new("Frame", { Name = "Halo" .. i, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(320 + h[1], 344 + h[1]), BackgroundTransparency = h[2], BorderSizePixel = 0, ZIndex = 22 - i, Parent = prize }, { Kit.corner(14 + h[1] // 2) })
		halos[i]:SetAttribute("Base", h[2])
	end
	local prizeCard = new("Frame", { Name = "Card", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(320, 344), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, ZIndex = 22, Parent = prize }, { Kit.corner(14), new("UIStroke", { Name = "Rim", Color = Color3.new(1, 1, 1), Thickness = 5 }) })
	new("UIGradient", { Name = "Fill", Rotation = 90, Color = ColorSequence.new(Color3.fromHex("22306A"), Color3.fromHex("10183A")), Parent = prizeCard })
	Kit.studPattern(prizeCard, 0.18)
	local prizePop = new("UIScale", { Name = "Pop", Parent = prize })
	local picSpot = new("Frame", { Name = "PictureSpot", Position = UDim2.fromOffset(16, 16), Size = UDim2.fromOffset(288, 200), BackgroundTransparency = 1, ZIndex = 23, Parent = prizeCard })
	local prizeName = words({ Name = "PrizeName", Text = "", FontFace = F.Big, TextSize = 38, Position = UDim2.fromOffset(8, 224), Size = UDim2.fromOffset(304, 46), ZIndex = 24, Parent = prizeCard }, 3)
	local prizeRarity = words({ Name = "Rarity", Text = "", FontFace = F.Big, TextSize = 26, Position = UDim2.fromOffset(8, 270), Size = UDim2.fromOffset(304, 32), ZIndex = 24, Parent = prizeCard }, 2.5)
	local prizeFoot = new("Frame", { Name = "Foot", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -12), Size = UDim2.fromOffset(200, 8), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, ZIndex = 24, Parent = prizeCard }, { Kit.corner(4) })
	local status = words({ Name = "Status", Text = "", FontFace = F.Big, TextSize = 34, Position = UDim2.fromOffset(240, 510), Size = UDim2.fromOffset(800, 38), Visible = false, ZIndex = 25, Parent = group }, 2.5)
	local statusPop = new("UIScale", { Name = "Pop", Parent = status })
	local sub = words({ Name = "Sub", Text = "", FontFace = F.Name, TextSize = 18, TextColor3 = C.SubText, Position = UDim2.fromOffset(240, 550), Size = UDim2.fromOffset(800, 24), Visible = false, ZIndex = 25, Parent = group }, 1.5)

	-- sparks and rings (a fixed set, reused): the lid's pop and the Legendary burst
	local sparks = {}
	for i = 1, SPARKS do
		sparks[i] = new("Frame", { Name = "Spark" .. i, AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(12, 12), Rotation = 45, BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, Visible = false, ZIndex = 30, Parent = group }, { Kit.corner(3) })
	end
	local rings = {}
	for i = 1, 2 do
		rings[i] = circle({ Name = "Ring" .. i, Position = UDim2.fromOffset(CX, 350), BackgroundTransparency = 1, Visible = false, ZIndex = 29, Parent = group }, 10, { new("UIStroke", { Name = "Line", Color = Color3.new(1, 1, 1), Thickness = 6 }) })
	end

	-- bottom: OPEN AGAIN, BACK and the pity counter
	local bottom = new("Frame", { Name = "Bottom", Position = UDim2.fromOffset(240, 584), Size = UDim2.fromOffset(800, 130), BackgroundTransparency = 1, Visible = false, ZIndex = 25, Parent = group })
	local again = Kit.button({ Name = "OpenAgain", Text = "OPEN AGAIN 50", Icon = "AuraStar", IconAfter = true, IconSize = 30, Gap = 8, Style = "Selected", FontFace = F.Heading, TextSize = 26, Corner = 8, RimThickness = 2.5, Position = UDim2.fromOffset(130, 0), Size = UDim2.fromOffset(330, 60), ZIndex = 26, Parent = bottom })
	local back = Kit.button({ Name = "Back", Text = "BACK", Style = "Slate", FontFace = F.Heading, TextSize = 26, Corner = 8, RimThickness = 2.5, Position = UDim2.fromOffset(480, 0), Size = UDim2.fromOffset(190, 60), ZIndex = 26, Parent = bottom })
	local pityLine = words({ Name = "Pity", Text = "", FontFace = F.Name, TextSize = 17, Position = UDim2.fromOffset(0, 72), Size = UDim2.fromOffset(800, 22), ZIndex = 26, Parent = bottom }, 1.5)
	local pityTrack = new("Frame", { Name = "PityTrack", Position = UDim2.fromOffset(250, 100), Size = UDim2.fromOffset(300, 8), BackgroundColor3 = C.TrackRim, BorderSizePixel = 0, ZIndex = 26, Parent = bottom }, { Kit.corner(4) })
	local pityFill = new("Frame", { Name = "Fill", Size = UDim2.fromScale(0, 1), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, ZIndex = 26, Parent = pityTrack }, { Kit.corner(4) })

	-- tap anywhere to skip (only while it runs)
	local skip = new("TextButton", { Name = "Skip", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(3, 3), BackgroundTransparency = 1, Text = "", AutoButtonColor = false, Visible = false, ZIndex = 50, Parent = group })

	---------------------------------------------------------------------------------------------------------------
	local crateDef: any = Crates.List[1]
	local result: any = nil -- the server's answer
	local cards: { Frame } = {}
	local clock = 0
	local running = false -- the timeline is playing
	local busy = false -- waiting for the server, or playing
	local skipped = false
	local fired: { [string]: boolean } = {}
	local lastTickCard = 0
	local lastTickAt = -1
	local lastFlash = -10 -- os.clock() of the last flash (kid-safe: at most one a second)
	local landOffset = 0
	local conn: RBXScriptConnection? = nil

	local function setAura()
		auraText.Text = Format.commas(State.data.Aura or 0)
	end

	local function setPity()
		local P = crateDef.Pity
		local pity = (State.data.Pity or {})[crateDef.Id] or 0
		local left = CrateRoll.left(crateDef, pity)
		if not P or not left then pityLine.Text = ""; pityTrack.Visible = false; return end
		pityTrack.Visible = true
		pityLine.Text = if left <= 1 then `{P.Rarity} guaranteed on your next open!` else `{P.Rarity} guaranteed in {left} opens`
		pityFill.Size = UDim2.fromScale(clamp01(pity / P.After), 1)
		pityFill.BackgroundColor3 = CrateArt.color(P.Rarity)
	end

	local function stripX(t: number): number
		-- x of the strip (window coords) so that, at spin progress e, the marker sits over card START_CARD + travel
		local centre = (REEL.W - 8) / 2
		local from = centre - ((START_CARD - 1) * CARD.Pitch + CARD.W / 2)
		if not result then return from end
		local to = centre - ((result.at - 1) * CARD.Pitch + CARD.W / 2 + landOffset)
		local u = clamp01((t - T.Spin) / T.SpinLen)
		return from + (to - from) * easeOut(u, 4)
	end

	local function clearCards()
		for _, c in cards do c:Destroy() end
		cards = {}
	end

	local function buildCards()
		clearCards()
		for i, index in result.strip do
			local item = crateDef.Items[index]
			if item then
				local c = CrateArt.card(strip, item, CARD.W, CARD.H, "Card" .. i)
				c.Position = UDim2.fromOffset((i - 1) * CARD.Pitch, 0)
				new("UIScale", { Name = "Lift", Parent = c })
				new("Frame", { Name = "Shade", Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 9, Parent = c }, { Kit.corner(8) })
				cards[i] = c
			end
		end
	end

	local function spark(i: number, x: number, y: number, angle: number, dist: number, u: number, colour: Color3, size: number)
		local s = sparks[i]
		if not s then return end
		local k = easeOut(u, 3)
		s.Visible = u < 1
		s.Position = UDim2.fromOffset(math.round(x + math.cos(angle) * dist * k), math.round(y + math.sin(angle) * dist * k))
		s.BackgroundColor3 = colour
		s.BackgroundTransparency = u ^ 2
		local px = math.max(2, math.round(size * (1 - u * 0.6)))
		s.Size = UDim2.fromOffset(px, px)
	end
	local function ring(i: number, x: number, y: number, d: number, u: number, colour: Color3, thick: number)
		local r = rings[i]
		r.Visible = u < 1
		r.Position = UDim2.fromOffset(x, y)
		local size = math.max(2, math.round(d * easeOut(u, 3)))
		r.Size = UDim2.fromOffset(size, size)
		local line = r:FindFirstChild("Line") :: UIStroke
		line.Color = colour
		line.Transparency = u
		line.Thickness = math.max(1, thick * (1 - u))
	end
	local function hideFx()
		for _, s in sparks do s.Visible = false end
		for _, r in rings do r.Visible = false end
		flash.Visible = false
	end

	local function rank(): number return CrateRoll.RANK[result and result.rarity or ""] or 0 end

	local function showPrize()
		local item = crateDef.Items[result.index]
		local col = CrateArt.color(item.Rarity)
		for _, ch in picSpot:GetChildren() do ch:Destroy() end
		CrateArt.picture(picSpot, item, 288, 200, 10, UDim2.new(), 23)
		prizeName.Text = item.Name
		Kit.fitLine(prizeName, 300, 38, 22, true)
		prizeRarity.Text = string.upper(item.Rarity)
		prizeRarity.TextColor3 = col
		prizeFoot.BackgroundColor3 = col
		local rim = prizeCard:FindFirstChild("Rim") :: UIStroke
		rim.Color = col
		prizeRays.ImageColor3 = col
		prizeRays2.ImageColor3 = col:Lerp(Color3.new(1, 1, 1), 0.6)
		prizeRays.Visible = rank() >= CrateRoll.RANK.Rare
		prizeRays2.Visible = rank() >= CrateRoll.RANK.Epic
		for _, h in halos do h.BackgroundColor3 = col end
		if item.Kind == "Coins" then
			status.Text, status.TextColor3 = `+{Format.commas(result.coins)} COINS`, C.Text
			sub.Text = ""
		elseif result.new then
			status.Text, status.TextColor3 = "NEW!", C.Accent
			sub.Text = if item.Kind == "Dance" then "Find it in Dances" else "Wear it from Shop > Items"
		else
			status.Text, status.TextColor3 = `Duplicate: +{Format.commas(result.coins)} coins`, C.Text
			sub.Text = "You already have this one"
		end
		-- the title becomes the moment: "LEGENDARY!" / "EPIC!" in its colour, else "YOU GOT"
		title.FontFace = F.Big
		title.Text = if rank() >= CrateRoll.RANK.Epic then string.upper(item.Rarity) .. "!" else "YOU GOT"
		title.TextColor3 = if rank() >= CrateRoll.RANK.Epic then col else C.Text
		prize.Visible = true
	end

	-- Everything on screen at time t of the timeline (dt: since the last frame).
	local function render(t: number, dt: number)
		local item = result and crateDef.Items[result.index]
		-- 1. the crate: shakes harder, then the lid pops off and the box shrinks away
		local shake = clamp01(t / T.ShakeEnd)
		if t < T.PopEnd then
			crate.Visible, crateRays.Visible = true, true
			local amp = if Motion.reduced then 0 else (2 + 8 * shake * shake)
			crate.Rotation = math.sin(t * 2 * math.pi * 8) * amp
			if t < T.ShakeEnd then
				cratePop.Scale = 1 + 0.07 * shake
				lid.Position = lidHome
				lid.Rotation = 0
				lid.Visible = true
			else
				local u = clamp01((t - T.ShakeEnd) / (T.PopEnd - T.ShakeEnd))
				cratePop.Scale = (1.07 + 0.1 * math.sin(u * math.pi)) * (1 - easeOut(u, 2) * 0.9)
				lid.Position = lidHome + UDim2.fromOffset(math.round(30 * u), math.round(-150 * easeOut(u, 2)))
				lid.Rotation = -30 * u
			end
			crateRays.ImageTransparency = 0.55 - 0.25 * shake
			crateRays.Rotation += dt * (30 + 120 * shake)
		else
			-- the crate's green light stays on behind the reel while it spins, softer, and goes when the prize shows
			crate.Visible = false
			crateRays.Visible = t < T.Reveal
			crateRays.ImageTransparency = 0.72
			crateRays.Rotation += dt * 20
		end
		-- the pop: a ring and sparks from where the lid was
		if t >= T.ShakeEnd and not fired.pop and not skipped then
			fired.pop = true
			Sfx.play("pick_land")
		end
		local pu = (t - T.ShakeEnd) / 0.5
		if pu >= 0 and pu < 1 and not skipped then
			ring(1, CX, 330, 420, pu, C.Accent, 8)
			for i = 1, 10 do
				spark(i, CX, 330, (i / 10) * math.pi * 2 + 0.3, 210 + (i % 3) * 30, pu, if i % 2 == 0 then C.Accent else Color3.new(1, 1, 1), 14)
			end
		elseif t >= T.ShakeEnd + 0.5 and t < T.Reveal then
			hideFx()
		end
		-- 2. the reel opens out of the middle, spins and eases out onto the prize
		local ru = clamp01((t - T.ReelIn) / T.ReelInLen)
		reel.Visible = ru > 0
		reel.Size = UDim2.fromOffset(REEL.W, math.max(2, math.round(REEL.H * math.min(easeOutBack(ru), 1.04))))
		strip.Position = UDim2.fromOffset(math.round(stripX(t)), CARD.Top - 4)
		hint.Visible = running and not skipped and t >= T.Spin and t < T.SpinEnd
		-- a tick for each card that passes the marker (at full speed no more than ~22 a second)
		local centre = (REEL.W - 8) / 2
		local under = math.floor((centre - stripX(t)) / CARD.Pitch) + 1
		if under ~= lastTickCard then
			lastTickCard = under
			if t >= T.Spin and t <= T.SpinEnd and t - lastTickAt > 0.045 and not skipped then
				lastTickAt = t
				Sfx.play("spin_tick")
				for _, p in pointers do p.Rotation = 45 + 10 end
			end
		end
		for _, p in pointers do p.Rotation = 45 + (p.Rotation - 45) * math.max(0, 1 - dt * 14) end
		-- 3. it lands: the prize card lifts, the others dim, the marker glows
		local lu = clamp01((t - T.SpinEnd) / 0.35)
		for i, c in cards do
			local shade = c:FindFirstChild("Shade") :: Frame?
			local lift = c:FindFirstChild("Lift") :: UIScale?
			if i == (result and result.at) then
				if lift then lift.Scale = 1 + 0.1 * easeOutBack(lu) end
				c.ZIndex = 6
			elseif shade then
				shade.BackgroundTransparency = 1 - 0.6 * lu
			end
		end
		markerGlow.BackgroundTransparency = 0.7 - 0.35 * lu
		if t >= T.SpinEnd and not fired.land and item then
			fired.land = true
			if not skipped then Sfx.play(if rank() >= CrateRoll.RANK.Epic then "spin_big_win" else "spin_win") end
		end
		-- 4. the prize in front
		if t >= T.Reveal and item then
			if not fired.reveal then
				fired.reveal = true
				showPrize()
				if skipped then Sfx.play(if rank() >= CrateRoll.RANK.Epic then "spin_big_win" else "spin_win") end
				if result.new then Sfx.play("reward") end
				-- one soft flash for Epic and up (never more than one a second, whoever asks)
				if rank() >= CrateRoll.RANK.Epic and not skipped and not Motion.reduced and os.clock() - lastFlash >= 1 then
					lastFlash = os.clock()
					fired.flashAt = true
					flash.Visible = true
				end
			end
			local vu = clamp01((t - T.Reveal) / T.RevealLen)
			prizePop.Scale = if Motion.reduced or skipped then 1 else 0.25 + 0.75 * easeOutBack(vu)
			prizeRays.Rotation += dt * RAYS_SPEED
			prizeRays2.Rotation -= dt * RAYS_SPEED * 1.5
			local breathe = 0.5 + 0.5 * math.sin((t - T.Reveal) * 2.4) -- (a slow swell, about every 2.6 s)
			for _, h in halos do h.BackgroundTransparency = (h:GetAttribute("Base") :: number) - 0.08 * breathe end
			-- the reel folds away under the prize (its cut-off cards read as clutter round the card)
			local cu = clamp01((t - T.Reveal) / 0.25)
			reel.Visible = cu < 1
			reel.Size = UDim2.fromOffset(REEL.W, math.max(2, math.round(REEL.H * (1 - easeOut(cu, 2)))))
			if flash.Visible then
				local fu = clamp01((t - T.Reveal) / 0.35)
				flash.BackgroundTransparency = 0.55 + 0.45 * fu
				if fu >= 1 then flash.Visible = false end
			end
			-- Legendary and up: a spark burst in its colour and a second, bigger ring
			local bu = (t - T.Reveal - 0.05) / 0.8
			if rank() >= CrateRoll.RANK.Legendary and not skipped and not Motion.reduced and bu >= 0 and bu < 1 then
				local col = CrateArt.color(item.Rarity)
				ring(1, CX, 330, 640, bu, col, 10)
				ring(2, CX, 330, 440, clamp01(bu * 1.3), Color3.new(1, 1, 1), 6)
				for i = 1, SPARKS do
					spark(i, CX, 330, (i / SPARKS) * math.pi * 2, 300 + (i % 4) * 40, bu, if i % 3 == 0 then Color3.new(1, 1, 1) else col, 16)
				end
			elseif bu >= 1 or skipped then
				for _, s in sparks do s.Visible = false end
				for _, r in rings do r.Visible = false end
			end
			-- the words under it and the buttons
			local su = clamp01((t - T.Reveal - 0.3) / 0.3)
			status.Visible, sub.Visible = su > 0, su > 0 and sub.Text ~= ""
			statusPop.Scale = if Motion.reduced or skipped then 1 else 0.5 + 0.5 * easeOutBack(su)
			local bu2 = clamp01((t - T.Reveal - 0.45) / 0.3)
			bottom.Visible = bu2 > 0
			bottom.Position = UDim2.fromOffset(240, 584 + math.round(40 * (1 - easeOut(bu2, 3))))
			if bu2 >= 1 and running then
				running = false
				busy = false
				skip.Visible = false
				setPity()
			end
		end
	end

	local function stop()
		if conn then conn:Disconnect(); conn = nil end
	end
	local function play()
		stop()
		conn = RunService.RenderStepped:Connect(function(dt)
			if not holder.Visible then return end
			clock += dt
			render(clock, dt) -- (after the prize shows, only its rays turn and its glow breathes)
		end)
	end

	-- the idle crate before the server answers (it wobbles a little)
	local function resetScene()
		stop()
		result = nil
		clearCards()
		clock, skipped, fired, lastTickCard, lastTickAt = 0, false, {}, 0, -1
		crate.Visible, crateRays.Visible, lid.Visible = true, true, true
		crate.Rotation, cratePop.Scale, lid.Position, lid.Rotation = 0, 1, lidHome, 0
		reel.Visible, prize.Visible, status.Visible, sub.Visible, bottom.Visible, hint.Visible = false, false, false, false, false, false
		hideFx()
		title.Text, title.FontFace, title.TextColor3 = string.upper(crateDef.Name), F.Heading, C.Text
		again.setText(`OPEN AGAIN {crateDef.Price}`)
		setAura()
		setPity()
	end

	local function blocked(): boolean
		local role = player:GetAttribute("HuzzRole")
		return role == "Runner" or role == "Catcher" or player:GetAttribute("HuzzChoosing") == true or player:GetAttribute("HuzzCinematic") == true
	end

	local function start(crateId: any)
		if busy then return end
		local c = type(crateId) == "string" and Crates.get(crateId) or crateDef
		if not c then return end
		crateDef = c
		if blocked() then
			Toast.show("Open crates in the lobby.")
			task.defer(function() if ModalManager.current() == "CrateOpen" then ModalManager.close() end end) -- (after the open finishes)
			return
		end
		resetScene()
		busy = true
		local okCall, ok, answer = pcall(function() return (Net.get("Action") :: RemoteFunction):InvokeServer("OpenCrate", crateDef.Id) end)
		if not okCall or not ok or type(answer) ~= "table" or type(answer.strip) ~= "table" or not crateDef.Items[answer.index] or answer.strip[answer.at] ~= answer.index then
			busy = false
			Sfx.play("ui_error")
			Toast.show(if okCall and type(answer) == "string" then answer else "Couldn't open it. Try again.")
			task.defer(function() if ModalManager.current() == "CrateOpen" then ModalManager.open("Shop", "Crates") end end)
			return
		end
		result = answer
		landOffset = math.round((math.random() * 2 - 1) * CARD.W * 0.22) -- somewhere on the prize card, never its edge
		buildCards()
		setAura()
		running = true
		skip.Visible = true
		if Motion.reduced then -- (no shaking or spinning: straight to the prize)
			skipped = true
			clock = T.Reveal
		end
		render(clock, 0)
		play()
	end

	skip.Activated:Connect(function()
		if not running or clock >= T.Reveal then return end
		skipped = true
		clock = T.Reveal
		hideFx()
	end)

	again.onClick(function()
		if busy then return end
		local have = State.data.Aura or 0
		if have < crateDef.Price then
			Sfx.play("ui_error")
			Toast.show(`You need {crateDef.Price - have} more Aura. Collect stars on the field!`)
			return
		end
		start(crateDef.Id)
	end)
	back.onClick(function() ModalManager.open("Shop", "Crates") end)

	local function onClose()
		-- closed mid-animation (Escape, the cutscene): the prize is yours already; say what it was
		if result and running then
			local item = crateDef.Items[result.index]
			Toast.show(if result.new then `You got {item.Name}!` elseif item.Kind == "Coins" then `You got {item.Name}!` else `{item.Name} again: +{result.coins} coins`)
		end
		stop()
		running, busy = false, false
		skip.Visible = false
	end

	ModalManager.register("CrateOpen", {
		window = { Holder = holder, Group = group, OpenScale = openScale, Width = W, Height = H },
		onOpen = function(crateId) task.spawn(start, crateId) end,
		onClose = onClose,
		firstSelect = function() return again.Instance end,
	})
	State.changed(function()
		if holder.Visible then
			setAura()
			if not running then setPity() end
		end
	end)
	-- the Secret cutscene starting while this is open closes it (the prize is kept)
	player:GetAttributeChangedSignal("HuzzCinematic"):Connect(function()
		if player:GetAttribute("HuzzCinematic") == true and ModalManager.current() == "CrateOpen" then ModalManager.close() end
	end)
	resetScene()
	return holder
end

return CrateOpen
