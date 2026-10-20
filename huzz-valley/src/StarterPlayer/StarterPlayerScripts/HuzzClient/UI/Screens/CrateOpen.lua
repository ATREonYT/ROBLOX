-- Crate opening (owner, Oct 19: "Also create a good case opening animation"). Opened by Shop > CRATES > OPEN, or the
-- Halloween shop's OPEN (its crates' Home; BACK returns there). A Robux crate key is used before Aura: USE KEY (n).
-- The server decides everything first (ActionService "OpenCrate": takes the Aura once, rolls with the shown odds and
-- the pity counter, gives the prize, and builds the reel from honest draws); this screen only animates to its answer:
--   1. the crate rattles harder and harder (faster wooden ticks), its lid pops off (0.85 s);
--   2. a reel of item cards (their real pictures, rims in the rarity colour) opens between two green light rails and
--      spins past the centre marker, fast at first and easing out for ~4.6 s; light streaks run along the rails with
--      its speed and each passing card ticks (a little higher as it slows). It runs a few pixels past its stop and
--      settles back onto the SAME card (an honest settle: the marker never leaves the prize card, no fake near-miss),
--      with a thunk; the marker takes the prize's rarity colour. Under the reel: the crate's odds by rarity and the
--      pity line, so the odds stay in view while it spins;
--   3. the prize card lifts, the rest dim, then it comes up in front with a soft glow round it in its rarity colour
--      (the prize sound with it); its name and rarity fade in (big Gotham Heavy Italic), one glint runs round its rim,
--      then "NEW!" or "Duplicate: +N coins". Calm like the 3D opening since the owner's Oct 20 07:51 "feels too ai":
--      no rays, beams, rings, sparks, flash or shake anywhere on this screen.
-- His three knife crates (owner, Oct 20: "make these crates for the opening of the normal knifes ... and make the opening
-- animations look appropriate") open in 3D instead, with his own crate model (UI/Crate3D, Shared/CrateMotion: the same
-- maths the offline film uses), no reel. Owner, Oct 20 07:51: "make the opening animation of the crates feel more
-- premium, right now it feels too ai ... remove [the circle around the knife] ... add s nice animation for the knife
-- when it starts rising up": restraint and timing, light instead of shapes (no rays, rings, sparks, discs or flash):
--   1. his crate rocks and jumps a little harder and faster, a wooden knock on each jump (2.1 s);
--   2. its top (his lid, roof or jaw) cracks open a few degrees with a soft knock and light in the prize's rarity
--      colour spills out of the gap (his glowing parts and the light take that colour); a short pause;
--   3. it swings open with a soft overshoot; his own little knife from the same set rises out slowly (a strong
--      ease-out, leaning a little, one slow turn), the camera easing in a touch, a few small motes drifting up from
--      inside; it settles into a gentle hover facing you and one glint runs along its blade;
--   4. its name and rarity fade in, then NEW! or the coins back, and the buttons (4.45 s in).
--   A dark knife (Hollow Moon) gets a soft light behind its blade, shaped and leaned like the blade (KnifeLight).
--   Without his model (not loaded yet) the plain crate and the reel play as below. The odds by rarity and the pity line
--   show under the crate while it builds up.
-- Rarity colours are the Spin wheel's (CrateArt.color): Legendary is pink, never gold (owner: "no gold anywhere").
-- The HUD's coin count waits for the prize (State.hold("Coins")), so a duplicate's coins don't give it away.
-- Kid-safe: every card on the reel is a fair draw with the real odds (Shared/CrateRoll.strip), nothing is planted next
-- to the stop; no flashes at all; the odds and the pity counter are in the Shop and on this screen.
-- Tap anywhere while it runs to skip to the prize. OPEN AGAIN opens another (same price), BACK returns to the Shop.
-- Not in a round or during the Secret cutscene (HuzzCinematic): it won't start, and closes if the cutscene begins.
-- Laid out at 1280 x 720 like the Spin the Wheel screen; plain frames (no CanvasGroup). Every moving part is driven by
-- one RenderStepped loop from its own clock (so the offline film plays exactly as the game does).
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Crates = require(Shared.Config.Crates)
local CoinShop = require(Shared.Config.CoinShop)
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
local Crate3D = require(UI.Crate3D)
local CrateMotion = require(Shared.CrateMotion)
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
	Spin = 0.8, SpinLen = 4.6, SettleLen = 0.4, LandLen = 0.45, RevealLen = 0.45, GlintLen = 0.6,
}
T.Stop = T.Spin + T.SpinLen -- furthest point (OVERSHOOT past the stop)
T.SpinEnd = T.Stop + T.SettleLen -- settled on the prize
T.Reveal = T.SpinEnd + T.LandLen
local OVERSHOOT = 24 -- px the reel runs past its stop before settling back (always still on the prize card)
local HALO = 8 -- soft glow layers round the prize card (many faint layers, so no visible steps)
local TITLE_Y = { Spin = 140, Prize = 40 } -- the title sits just over the crate and reel, then rises for the prize
local RAIL_Y = { REEL.Y - 18, REEL.Y + REEL.H + 18 }
local STREAKS = 6 -- light streaks per rail
local CHIPS = 6 -- odds by rarity under the reel (Common .. Mythic)
-- the 3D opening (his crates): its timeline (Shared/CrateMotion), where his crate stands, and where the words go
local T3 = CrateMotion.T
local STAGE = { Y = 280, W = 560, H = 400 } -- the crate's ViewportFrame, centred at (CX, Y)
local WORDS3 = { Name = 478, Rarity = 514, Status = 556, Sub = 572, Bottom = 600 } -- under the crate, for the reveal

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

function CrateOpen.build(parent: Instance)
	local player = Players.LocalPlayer
	local holder = new("Frame", { Name = "CrateOpen", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(W, H), BackgroundTransparency = 1, Visible = false, ZIndex = 20, Parent = parent })
	new("UIScale", { Name = "FitScale", Parent = holder })
	local group = new("Frame", { Name = "Group", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Visible = false, Parent = holder })
	local openScale = new("UIScale", { Name = "OpenScale", Parent = group })

	-- top: the crate's name and your Aura
	local title = words({ Name = "Title", Text = "", TextSize = 44, Position = UDim2.fromOffset(240, TITLE_Y.Spin), Size = UDim2.fromOffset(800, 52), ZIndex = 5, Parent = group }, 3)
	local auraBox = new("Frame", { Name = "Aura", Position = UDim2.fromOffset(1060, 26), Size = UDim2.fromOffset(190, 46), BackgroundColor3 = C.Pill, BackgroundTransparency = 0.15, BorderSizePixel = 0, ZIndex = 5, Parent = group }, { Kit.corner(23), Kit.stroke(C.Frame, 3) })
	Kit.icon("AuraStar", { Name = "Icon", AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 6, 0.5, 0), Size = UDim2.fromOffset(38, 38), ZIndex = 6, Parent = auraBox })
	local auraText = words({ Name = "Amount", Text = "0", FontFace = F.Number, TextSize = 24, TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.fromOffset(52, 0), Size = UDim2.fromOffset(130, 46), ZIndex = 6, Parent = auraBox }, 2)

	-- the crate (no light turning behind it since Oct 20: "too ai")
	local crate, crateBody, lid = CrateArt.crate(group, 250, UDim2.fromOffset(CX, 350), "Crate")
	crate.ZIndex = 3
	local cratePop = crate:FindFirstChild("Pop") :: UIScale
	local lidHome = lid.Position
	-- his 3D crate (UI/Crate3D builds its ViewportFrame in here at run time), and the knife's name and rarity under it
	-- a soft light right behind a dark knife's blade (CrateMotion.rimLight: only for a dark blade, so Hollow Moon never
	-- reads as a thin dark sliver), stretched along the blade and leaned with it at run time (light, never a disc)
	local backlight = Kit.art("DanceFxGlow", { Name = "KnifeLight", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(CX, 205), Size = UDim2.fromOffset(90, 300), ScaleType = Enum.ScaleType.Stretch, ImageTransparency = 1, Visible = false, ZIndex = 3, Parent = group })
	local stage = new("Frame", { Name = "Stage3D", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(CX, STAGE.Y), Size = UDim2.fromOffset(STAGE.W, STAGE.H), BackgroundTransparency = 1, Visible = false, ZIndex = 4, Parent = group })
	local knifeName = words({ Name = "KnifeName", Text = "", FontFace = F.Big, TextSize = 36, Position = UDim2.fromOffset(240, WORDS3.Name), Size = UDim2.fromOffset(800, 40), Visible = false, ZIndex = 25, Parent = group }, 3)
	local knifeRarity = words({ Name = "KnifeRarity", Text = "", FontFace = F.Big, TextSize = 22, Position = UDim2.fromOffset(240, WORDS3.Rarity), Size = UDim2.fromOffset(800, 26), Visible = false, ZIndex = 25, Parent = group }, 2.5)

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
	-- two green light rails frame the reel (fading at both ends), with streaks of light running along them at the
	-- reel's speed; they glow brighter while it spins fast
	local function fadeEnds(inner: number, edge: number): NumberSequence
		return NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(edge, inner), NumberSequenceKeypoint.new(1 - edge, inner), NumberSequenceKeypoint.new(1, 1) })
	end
	local rails, streaks = {}, {}
	for i, y in RAIL_Y do
		local rail = new("Frame", { Name = if i == 1 then "RailTop" else "RailBottom", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(CX, y), Size = UDim2.fromOffset(1220, 4), BackgroundColor3 = C.Accent, BorderSizePixel = 0, Visible = false, ZIndex = 3, Parent = group }, { Kit.corner(2) })
		new("UIGradient", { Transparency = fadeEnds(0, 0.18), Parent = rail })
		local glow = new("Frame", { Name = "Glow", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(1, 0, 0, 20), BackgroundColor3 = C.Accent, BackgroundTransparency = 0.8, BorderSizePixel = 0, ZIndex = 2, Parent = rail }, { Kit.corner(10) })
		new("UIGradient", { Transparency = fadeEnds(0, 0.25), Parent = glow })
		rails[i] = rail
		for k = 1, STREAKS do
			local s = new("Frame", { Name = "Streak" .. k, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0, 0.5), Size = UDim2.fromOffset(110, 4), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, ZIndex = 4, Parent = rail }, { Kit.corner(2) })
			new("UIGradient", { Transparency = fadeEnds(0, 0.45), Parent = s })
			table.insert(streaks, s)
		end
	end
	local hint = words({ Name = "Hint", Text = "TAP TO SKIP", FontFace = F.Name, TextSize = 18, TextColor3 = C.SubText, Position = UDim2.fromOffset(440, 640), Size = UDim2.fromOffset(400, 24), ZIndex = 5, Parent = group }, 1.5)
	-- under the reel while it spins: the odds by rarity (chips in their colours) and how far the pity counter is
	local chipRow = new("Frame", { Name = "Odds", Position = UDim2.fromOffset(0, 536), Size = UDim2.fromOffset(W, 34), BackgroundTransparency = 1, Visible = false, ZIndex = 5, Parent = group })
	local chips = {}
	for i = 1, CHIPS do
		local chip = new("Frame", { Name = "Chip" .. i, Size = UDim2.fromOffset(172, 34), BackgroundColor3 = C.Pill, BackgroundTransparency = 0.25, BorderSizePixel = 0, Visible = false, ZIndex = 5, Parent = chipRow }, { Kit.corner(17), new("UIStroke", { Name = "Rim", Color = Color3.new(1, 1, 1), Thickness = 2 }) })
		new("Frame", { Name = "Dot", AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 10, 0.5, 0), Size = UDim2.fromOffset(14, 14), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, ZIndex = 6, Parent = chip }, { Kit.corner(7) })
		words({ Name = "Label", Text = "", FontFace = F.Name, TextSize = 15, TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.fromOffset(30, 0), Size = UDim2.fromOffset(136, 34), ZIndex = 6, Parent = chip }, 1.5)
		chips[i] = chip
	end
	local pityNow = words({ Name = "PityNow", Text = "", FontFace = F.Name, TextSize = 17, TextColor3 = C.SubText, Position = UDim2.fromOffset(240, 584), Size = UDim2.fromOffset(800, 24), Visible = false, ZIndex = 5, Parent = group }, 1.5)

	-- the prize, in front: turning rays and a glow in its rarity colour, the card, the big words
	local prize = new("Frame", { Name = "Prize", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(CX, 330), Size = UDim2.fromOffset(320, 344), BackgroundTransparency = 1, Visible = false, ZIndex = 20, Parent = group })
	-- a soft glow hugging the card (HALO faint layers a few px apart, so it fades smoothly instead of in bands)
	local halos = {}
	for i = 1, HALO do
		local grow = i * 7
		halos[i] = new("Frame", { Name = "Halo" .. i, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(320 + grow, 344 + grow), BackgroundTransparency = 0.88, BorderSizePixel = 0, ZIndex = 21, Parent = prize }, { Kit.corner(14 + grow // 2) })
	end
	local prizeCard = new("Frame", { Name = "Card", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(320, 344), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, ZIndex = 22, Parent = prize }, { Kit.corner(14), new("UIStroke", { Name = "Rim", Color = Color3.new(1, 1, 1), Thickness = 5 }) })
	new("UIGradient", { Name = "Fill", Rotation = 90, Color = ColorSequence.new(Color3.fromHex("22306A"), Color3.fromHex("10183A")), Parent = prizeCard })
	Kit.studPattern(prizeCard, 0.18)
	local prizePop = new("UIScale", { Name = "Pop", Parent = prize })
	-- the one glint: a white band in a gradient on the card's rim, swept across once (parked off the card otherwise)
	local prizeRim = prizeCard:FindFirstChild("Rim") :: UIStroke
	local rimGlint = prizeRim:FindFirstChild("Glint") :: UIGradient? or new("UIGradient", { Name = "Glint", Rotation = 35, Offset = Vector2.new(-1, 0), Parent = prizeRim })
	local picSpot = new("Frame", { Name = "PictureSpot", Position = UDim2.fromOffset(16, 16), Size = UDim2.fromOffset(288, 200), BackgroundTransparency = 1, ZIndex = 23, Parent = prizeCard })
	local prizeName = words({ Name = "PrizeName", Text = "", FontFace = F.Big, TextSize = 38, Position = UDim2.fromOffset(8, 224), Size = UDim2.fromOffset(304, 46), ZIndex = 24, Parent = prizeCard }, 3)
	local prizeRarity = words({ Name = "Rarity", Text = "", FontFace = F.Big, TextSize = 26, Position = UDim2.fromOffset(8, 270), Size = UDim2.fromOffset(304, 32), ZIndex = 24, Parent = prizeCard }, 2.5)
	local prizeFoot = new("Frame", { Name = "Foot", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -12), Size = UDim2.fromOffset(200, 8), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, ZIndex = 24, Parent = prizeCard }, { Kit.corner(4) })
	local status = words({ Name = "Status", Text = "", FontFace = F.Big, TextSize = 34, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(CX, 529), Size = UDim2.fromOffset(800, 38), Visible = false, ZIndex = 25, Parent = group }, 2.5)
	local statusPop = new("UIScale", { Name = "Pop", Parent = status })
	local sub = words({ Name = "Sub", Text = "", FontFace = F.Name, TextSize = 18, TextColor3 = C.SubText, Position = UDim2.fromOffset(240, 550), Size = UDim2.fromOffset(800, 24), Visible = false, ZIndex = 25, Parent = group }, 1.5)

	-- (a UI saved before Oct 20 still holds the rays, beams, rings, sparks and flash: put them away, never shown)
	for _, n in { "CrateRays", "Flash", "PrizeRays", "Burst", "Ring1", "Ring2" } do
		local old = group:FindFirstChild(n, true)
		if old then old:Destroy() end
	end
	for i = 1, 16 do
		local old = group:FindFirstChild("Spark" .. i)
		if old then old:Destroy() end
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
	local landOffset = 0
	local conn: RBXScriptConnection? = nil
	local view3d: any = nil -- his crate (UI/Crate3D) when this crate has his model, else nil: the plain crate and the reel
	local function revealAt(): number return if view3d then T3.Reveal else T.Reveal end

	local function setAura()
		auraText.Text = Format.commas(State.data.Aura or 0)
	end

	local function setPity()
		local P = crateDef.Pity
		local pity = (State.data.Pity or {})[crateDef.Id] or 0
		local left = CrateRoll.left(crateDef, pity)
		if not P or not left then pityLine.Text = ""; pityNow.Text = ""; pityTrack.Visible = false; return end
		pityTrack.Visible = true
		pityLine.Text = if left <= 1 then `{P.Rarity} guaranteed on your next open!` else `{P.Rarity} guaranteed in {left} opens`
		pityFill.Size = UDim2.fromScale(clamp01(pity / P.After), 1)
		pityFill.BackgroundColor3 = CrateArt.color(P.Rarity)
		pityNow.Text = pityLine.Text
	end

	-- the chips under the reel: each rarity in the crate with its total chance (the same numbers as the Shop's list)
	local function setOdds()
		local sum, order = {}, {}
		for _, o in CrateRoll.odds(crateDef) do
			local r = o.item.Rarity
			if not sum[r] then sum[r] = 0; table.insert(order, r) end
			sum[r] += o.chance
		end
		table.sort(order, function(a, b) return (CrateRoll.RANK[a] or 0) < (CrateRoll.RANK[b] or 0) end)
		local n = math.min(#order, CHIPS)
		local cw, gap = 172, 12
		local x0 = math.round(CX - (n * cw + (n - 1) * gap) / 2)
		for i, chip in chips do
			local r = order[i]
			chip.Visible = i <= n
			if r and i <= n then
				local col = CrateArt.color(r)
				chip.Position = UDim2.fromOffset(x0 + (i - 1) * (cw + gap), 0)
				local rim = chip:FindFirstChild("Rim") :: UIStroke
				rim.Color = col
				local dot = chip:FindFirstChild("Dot") :: Frame
				dot.BackgroundColor3 = col
				local label = chip:FindFirstChild("Label") :: TextLabel
				label.Text = string.format("%s %g%%", string.upper(r), math.floor(sum[r] * 10 + 0.5) / 10)
			end
		end
	end

	-- x of the strip (window coords) at time t: from START_CARD under the marker it eases out for SpinLen to OVERSHOOT
	-- px past the stop, then settles back onto it over SettleLen. landOffset is clamped so that both the furthest
	-- point and the stop are on the prize card (the settle never shows a different card under the marker).
	local function stripX(t: number): number
		local centre = (REEL.W - 8) / 2
		local from = centre - ((START_CARD - 1) * CARD.Pitch + CARD.W / 2)
		if not result then return from end
		local to = centre - ((result.at - 1) * CARD.Pitch + CARD.W / 2 + landOffset)
		local over = if skipped or Motion.reduced then 0 else OVERSHOOT
		if t < T.Stop then
			local u = clamp01((t - T.Spin) / T.SpinLen)
			return from + (to - over - from) * easeOut(u, 3) -- (cubic: the last cards still creep past; quartic sat nearly still for ~1.5 s)
		end
		local s = clamp01((t - T.Stop) / T.SettleLen)
		return to - over * (1 - (1 - math.cos(s * math.pi)) / 2)
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

	-- A label's words and outline at u of their fade in (0 hidden .. 1 shown).
	local function fade(l: TextLabel, u: number)
		l.TextTransparency = 1 - easeOut(u, 2)
		local o = l:FindFirstChild("Outline") :: UIStroke?
		if o then o.Transparency = 1 - easeOut(u, 2) end
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
		-- the rim in its rarity colour, with the glint's white band in the middle of its gradient (parked off the card)
		prizeRim.Color = Color3.new(1, 1, 1)
		rimGlint.Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, col), ColorSequenceKeypoint.new(0.44, col), ColorSequenceKeypoint.new(0.5, Color3.new(1, 1, 1)), ColorSequenceKeypoint.new(0.56, col), ColorSequenceKeypoint.new(1, col) })
		rimGlint.Offset = Vector2.new(-1, 0)
		for _, h in halos do h.BackgroundColor3 = col end
		markerGlow.BackgroundColor3 = col
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
		State.release("Coins") -- (the HUD may show the coins now)
	end

	-- The prize under his 3D crate: the knife itself is the picture (it has risen out of the crate), so no card; its
	-- name and rarity under it, the title says the moment ("EPIC!" in its colour, else "YOU GOT").
	local function showPrize3d()
		local item = crateDef.Items[result.index]
		local col = CrateArt.color(item.Rarity)
		knifeName.Text = item.Name
		Kit.fitLine(knifeName, 780, 36, 22, true)
		knifeRarity.Text, knifeRarity.TextColor3 = string.upper(item.Rarity), col
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
		title.FontFace = F.Big
		title.Text = if rank() >= CrateRoll.RANK.Epic then string.upper(item.Rarity) .. "!" else "YOU GOT"
		title.TextColor3 = if rank() >= CrateRoll.RANK.Epic then col else C.Text
		State.release("Coins") -- (the HUD may show the coins now)
	end

	-- Everything on screen at time t of the 3D opening (his crate; see the header).
	local function render3d(t: number, dt: number)
		local item = result and crateDef.Items[result.index]
		local calm = Motion.reduced
		local col = if item then CrateArt.color(item.Rarity) else C.Accent
		crate.Visible, reel.Visible = false, false
		for _, rail in rails do rail.Visible = false end
		stage.Visible = true
		title.Position = UDim2.fromOffset(240, TITLE_Y.Prize)
		view3d.pose(t, calm, if item then col else nil)
		-- no rays, rings, sparks or discs here (owner: "too ai"): the light is his crate's own glow (Crate3D)
		-- a dark knife: a soft light behind its blade, stretched along it and leaned with it
		local shop = item and CoinShop.get(item.Id)
		local rim = if item then CrateMotion.rimLight(t, shop and shop.Colors and shop.Colors[1]) else 0
		backlight.Visible = rim > 0
		if rim > 0 then
			local y, len, lean = view3d.knifeScreen()
			local long = math.max(math.round(len * STAGE.H * 1.25), 2)
			backlight.Size = UDim2.fromOffset(math.max(math.round(long * 0.3), 2), long)
			backlight.Position = UDim2.fromOffset(CX, STAGE.Y - math.round(y * STAGE.H))
			backlight.Rotation = math.deg(lean)
			backlight.ImageColor3 = col:Lerp(Color3.new(1, 1, 1), CrateMotion.RimWhite)
			backlight.ImageTransparency = 1 - rim
		end
		-- a wooden knock on each jump, a soft low knock as it cracks, a softer pop as it opens, a thunk as the knife stops
		for k, at in CrateMotion.Ticks do
			if t >= at and t < T3.Build and not fired["knock" .. k] and not skipped then
				fired["knock" .. k] = true
				Sfx.play("roulette_tick", { volume = 0.4 + 0.04 * k, pitch = 0.85 + 0.03 * k })
			end
		end
		if t >= T3.Crack and not fired.crack and not skipped then
			fired.crack = true
			Sfx.play("roulette_tick", { volume = 0.6, pitch = 0.6 })
		end
		if t >= T3.Open and not fired.pop and not skipped then
			fired.pop = true
			Sfx.play("countdown_go", { volume = 0.4, pitch = 0.9 })
		end
		if t >= T3.Rise + T3.RiseLen and not fired.land and item then
			fired.land = true
			if not skipped then Sfx.play("pick_land") end
		end
		hint.Visible = running and not skipped and t < T3.Reveal
		chipRow.Visible = running and t < T3.Reveal
		pityNow.Visible = chipRow.Visible and pityNow.Text ~= ""
		-- the reveal: its name and rarity, NEW! or the coins back, the buttons
		if t >= T3.Reveal and item then
			if not fired.reveal then
				fired.reveal = true
				showPrize3d()
				Sfx.play(if rank() >= CrateRoll.RANK.Epic then "spin_big_win" else "spin_win")
			end
			if result.new and not fired.reward and t >= T3.Reveal + 0.5 then
				fired.reward = true
				Sfx.play("reward")
			end
			-- the words fade in (no flash, no pop): the title and name first, the rarity a beat later
			local nu = if skipped then 1 else clamp01((t - T3.Reveal) / 0.45)
			local ru = if skipped then 1 else clamp01((t - T3.Reveal - 0.12) / 0.45)
			knifeName.Visible, knifeRarity.Visible = true, true
			knifeName.Position = UDim2.fromOffset(240, WORDS3.Name + math.round(8 * (1 - easeOut(nu, 3))))
			fade(knifeName, nu)
			fade(title, nu)
			fade(knifeRarity, ru)
			local su = if skipped then 1 else clamp01((t - T3.Reveal - 0.4) / 0.4)
			status.Visible, sub.Visible = su > 0, su > 0 and sub.Text ~= ""
			statusPop.Scale = if calm or skipped then 1 else 0.92 + 0.08 * easeOut(su, 3)
			fade(status, su)
			fade(sub, su)
			local bu2 = clamp01((t - T3.Reveal - 0.6) / 0.3)
			bottom.Visible = bu2 > 0
			bottom.Position = UDim2.fromOffset(240, WORDS3.Bottom + math.round(40 * (1 - easeOut(bu2, 3))))
			if bu2 >= 1 and running then
				running = false
				busy = false
				skip.Visible = false
				setPity()
			end
		end
	end

	-- Everything on screen at time t of the timeline (dt: since the last frame).
	local railPhase = 0
	local function render(t: number, dt: number)
		if view3d then render3d(t, dt) return end
		local item = result and crateDef.Items[result.index]
		local calm = Motion.reduced
		-- 0. the title sits just over the crate and reel, and rises to the top for the prize
		local tu = clamp01((t - T.Reveal) / 0.3)
		title.Position = UDim2.fromOffset(240, math.round(TITLE_Y.Spin + (TITLE_Y.Prize - TITLE_Y.Spin) * easeOut(tu, 3)))
		-- 1. the crate: rattles harder (a wooden tick on each knock, closer and closer), then the lid pops off
		local shake = clamp01(t / T.ShakeEnd)
		if t < T.PopEnd then
			crate.Visible = true
			local amp = if calm then 0 else (2 + 8 * shake * shake)
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
		else
			crate.Visible = false
		end
		for k, at in { 0.12, 0.26, 0.37, 0.45, 0.51, 0.56 } do
			if t >= at and t < T.ShakeEnd and not fired["rattle" .. k] and not skipped then
				fired["rattle" .. k] = true
				Sfx.play("roulette_tick", { volume = 0.5 + 0.08 * k, pitch = 0.85 + 0.05 * k })
			end
		end
		-- the pop as the lid comes off (a sound only: no ring or sparks)
		if t >= T.ShakeEnd and not fired.pop and not skipped then
			fired.pop = true
			Sfx.play("countdown_go", { volume = 0.5, pitch = 0.9 })
		end
		-- 2. the reel opens out of the middle between its rails, spins, runs a little past and settles onto the prize
		local ru = clamp01((t - T.ReelIn) / T.ReelInLen)
		local cu = clamp01((t - T.Reveal) / 0.25) -- (folding away under the prize)
		reel.Visible = ru > 0 and cu < 0.6 -- (gone before it is a thin line across the prize)
		local open = if t < T.Reveal then math.min(easeOutBack(ru), 1.04) else 1 - easeOut(cu, 2)
		reel.Size = UDim2.fromOffset(REEL.W, math.max(2, math.round(REEL.H * open)))
		local x = stripX(t)
		strip.Position = UDim2.fromOffset(math.round(x), CARD.Top - 4)
		local speed = if t > T.Spin and t < T.Stop then math.abs(x - stripX(t - 1 / 60)) * 60 else 0 -- px a second
		local fast = math.clamp(speed / 3000, 0, 1)
		-- the rails slide apart with the reel, glow with its speed, and their streaks run with the cards
		local railOpen = (REEL.H / 2 + 18) * open
		for i, rail in rails do
			rail.Visible = ru > 0 and cu < 0.6
			rail.Position = UDim2.fromOffset(CX, math.round(REEL.Y + REEL.H / 2 + (if i == 1 then -railOpen else railOpen)))
			rail.BackgroundTransparency = 0.25 - 0.25 * fast
			local glow = rail:FindFirstChild("Glow") :: Frame
			glow.BackgroundTransparency = 0.86 - 0.22 * fast
		end
		railPhase = (railPhase + speed * dt * 0.2) % 1220
		for k, s in streaks do
			local slot = (k - 1) % STREAKS
			local sx = ((slot * 1220 / STREAKS) - railPhase + (if k > STREAKS then 100 else 0)) % 1220
			s.Position = UDim2.new(0, math.round(sx), 0.5, 0)
			s.BackgroundTransparency = 1 - 0.85 * fast
			s.Visible = fast > 0.02 and not calm
		end
		hint.Visible = running and not skipped and t >= T.Spin and t < T.SpinEnd
		-- the odds and the pity line under the reel while it spins (the bottom buttons take their place after)
		chipRow.Visible = ru > 0 and t < T.Reveal
		pityNow.Visible = chipRow.Visible and pityNow.Text ~= ""
		-- a tick for each card that passes the marker (no more than ~22 a second), a little higher as it slows
		local centre = (REEL.W - 8) / 2
		local under = math.floor((centre - x) / CARD.Pitch) + 1
		if under ~= lastTickCard then
			lastTickCard = under
			if t >= T.Spin and t <= T.Stop and t - lastTickAt > 0.045 and not skipped then
				lastTickAt = t
				Sfx.play("spin_tick", { pitch = 1 + 0.18 * (1 - fast) })
				for _, p in pointers do p.Rotation = 45 + 10 end
			end
		end
		for _, p in pointers do p.Rotation = 45 + (p.Rotation - 45) * math.max(0, 1 - dt * 14) end
		-- 3. settled: a thunk, the marker takes the prize's colour, the prize card lifts and the others dim
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
			local col = CrateArt.color(item.Rarity)
			markerGlow.BackgroundColor3 = col
			for _, p in pointers do p.BackgroundColor3 = col end
			if not skipped then Sfx.play("pick_land") end
		end
		-- 4. the prize in front (its sound hits with the zoom)
		if t >= T.Reveal and item then
			if not fired.reveal then
				fired.reveal = true
				showPrize()
				Sfx.play(if rank() >= CrateRoll.RANK.Epic then "spin_big_win" else "spin_win")
			end
			if result.new and not fired.reward and t >= T.Reveal + 0.5 then
				fired.reward = true
				Sfx.play("reward")
			end
			-- it comes up gently (no zoom from small, no shake); its glow breathes slowly
			local vu = clamp01((t - T.Reveal) / T.RevealLen)
			prizePop.Scale = if calm or skipped then 1 else 0.9 + 0.1 * easeOut(vu, 3)
			prize.Position = UDim2.fromOffset(CX, 330)
			local breathe = 0.5 + 0.5 * math.sin((t - T.Reveal) * 2.4) -- (a slow swell, about every 2.6 s)
			for _, h in halos do h.BackgroundTransparency = 0.9 - 0.035 * breathe end
			-- its name, then its rarity, fade in
			fade(prizeName, if skipped then 1 else clamp01((t - T.Reveal - 0.1) / 0.45))
			fade(prizeRarity, if skipped then 1 else clamp01((t - T.Reveal - 0.22) / 0.45))
			-- one glint round its rim, once it is up (none in reduced motion)
			local gu = (t - T.Reveal - T.RevealLen - 0.15) / T.GlintLen
			rimGlint.Offset = Vector2.new(if calm or gu <= 0 or gu >= 1 then -1 else -1 + 2 * (gu * gu * (3 - 2 * gu)), 0)
			-- the words under it and the buttons
			local su = if skipped then 1 else clamp01((t - T.Reveal - 0.45) / 0.4)
			status.Visible, sub.Visible = su > 0, su > 0 and sub.Text ~= ""
			statusPop.Scale = if calm or skipped then 1 else 0.92 + 0.08 * easeOut(su, 3)
			fade(status, su)
			fade(sub, su)
			local bu2 = clamp01((t - T.Reveal - 0.6) / 0.3)
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
	-- crate keys bought with Robux (the Halloween shop): the server uses one before any Aura
	local function keys(): number
		return ((State.data.CrateKeys or {})[crateDef.Id]) or 0
	end
	local againIcon = again.Instance:FindFirstChild("Icon", true) :: GuiObject?
	local function setAgain()
		local n = keys()
		again.setText(if n > 0 then `USE KEY ({n})` else `OPEN AGAIN {crateDef.Price}`)
		if againIcon then againIcon.Visible = n <= 0 end
	end

	local function resetScene()
		stop()
		result = nil
		clearCards()
		clock, skipped, fired, lastTickCard, lastTickAt = 0, false, {}, 0, -1
		crate.Visible, lid.Visible = true, true
		crate.Rotation, cratePop.Scale, lid.Position, lid.Rotation = 0, 1, lidHome, 0
		reel.Visible, prize.Visible, status.Visible, sub.Visible, bottom.Visible, hint.Visible = false, false, false, false, false, false
		chipRow.Visible, pityNow.Visible, backlight.Visible = false, false, false
		for _, rail in rails do rail.Visible = false end
		markerGlow.BackgroundColor3 = C.Accent
		for _, p in pointers do p.BackgroundColor3 = C.Accent end
		prize.Position = UDim2.fromOffset(CX, 330)
		rimGlint.Offset = Vector2.new(-1, 0)
		title.Text, title.FontFace, title.TextColor3 = string.upper(crateDef.Name), F.Heading, C.Text
		CrateArt.paint(crate, crateDef) -- (each crate in its own colour)
		title.Position = UDim2.fromOffset(240, TITLE_Y.Spin)
		-- his 3D crate when this crate has his model (else the plain crate and the reel)
		if view3d then view3d.destroy(); view3d = nil end
		knifeName.Visible, knifeRarity.Visible, stage.Visible = false, false, false
		for _, l in { title, knifeName, knifeRarity, status, sub, prizeName, prizeRarity } do
			l.TextTransparency = 0
			local o = l:FindFirstChild("Outline") :: UIStroke?
			if o then o.Transparency = 0 end
		end
		local okView, v = pcall(function() return if crateDef.Model and Crate3D.available(crateDef) then Crate3D.new(stage, crateDef, "Open", { ZIndex = 4 }) else nil end)
		if not okView then warn("[HuzzUI] CrateOpen: his crate couldn't be drawn:", v) end
		view3d = if okView then v else nil
		if view3d then
			crate.Visible, stage.Visible = false, true
			title.Position = UDim2.fromOffset(240, TITLE_Y.Prize)
			status.Position = UDim2.fromOffset(CX, WORDS3.Status)
			sub.Position = UDim2.fromOffset(240, WORDS3.Sub)
			view3d.pose(0, true, nil)
		else
			status.Position = UDim2.fromOffset(CX, 529)
			sub.Position = UDim2.fromOffset(240, 550)
		end
		setAgain()
		setAura()
		setPity()
		setOdds()
	end

	local function blocked(): boolean
		local role = player:GetAttribute("HuzzRole")
		return role == "Runner" or role == "Catcher" or player:GetAttribute("HuzzChoosing") == true or player:GetAttribute("HuzzCinematic") == true
	end

	-- back to the page that sells this crate (Config/Crates Home: the Halloween stands' crates), else Shop > CRATES
	local function goHome()
		if crateDef.Home and ModalManager.has(crateDef.Home) then ModalManager.open(crateDef.Home, "Crates") else ModalManager.open("Shop", "Crates") end
	end
	-- what you won, in one line (a toast when the window closed before the reel could show it)
	local closes = 0 -- onClose counts up: a start that sees it change was closed while it asked the server
	local function prizeLine(r): string
		local item = crateDef.Items[r.index]
		return if r.new then `You got {item.Name}!` elseif item.Kind == "Coins" then `You got {item.Name}!` else `{item.Name} again: +{r.coins} coins`
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
		State.hold("Coins") -- (the HUD keeps showing the old coins until the prize shows: a duplicate's coins would spoil it)
		local closesAtAsk = closes
		local okCall, ok, answer = pcall(function() return (Net.get("Action") :: RemoteFunction):InvokeServer("OpenCrate", crateDef.Id) end)
		-- closed while the server answered (X, Escape, the map vote, a round starting): the prize is yours already, so
		-- say it in a toast instead of playing the reel in a hidden window (bug hunt, Oct 20)
		if closes ~= closesAtAsk or ModalManager.current() ~= "CrateOpen" then
			busy = false
			State.release("Coins")
			if okCall and ok and type(answer) == "table" and crateDef.Items[answer.index] then
				Toast.show(prizeLine(answer))
			end
			return
		end
		if not okCall or not ok or type(answer) ~= "table" or type(answer.strip) ~= "table" or not crateDef.Items[answer.index] or answer.strip[answer.at] ~= answer.index then
			busy = false
			State.release("Coins")
			Sfx.play("ui_error")
			Toast.show(if okCall and type(answer) == "string" then answer else "Couldn't open it. Try again.")
			task.defer(function() if ModalManager.current() == "CrateOpen" then goHome() end end)
			return
		end
		result = answer
		-- somewhere on the prize card, never its edge, and room left for the settle's OVERSHOOT on the same card
		landOffset = math.round(-CARD.W * 0.3 + math.random() * CARD.W * 0.42)
		if view3d then
			view3d.knife(crateDef.Items[answer.index].Id) -- (his little knife from the same set rises out of it)
		else
			buildCards()
		end
		setAura()
		running = true
		skip.Visible = true
		if Motion.reduced then -- (no shaking or spinning: straight to the prize)
			skipped = true
			clock = revealAt()
		end
		render(clock, 0)
		play()
	end

	skip.Activated:Connect(function()
		if not running or clock >= revealAt() then return end
		skipped = true
		clock = revealAt()
	end)

	again.onClick(function()
		if busy then return end
		local have = State.data.Aura or 0
		if keys() <= 0 and have < crateDef.Price then
			Sfx.play("ui_error")
			Toast.show(`You need {crateDef.Price - have} more Aura. Collect stars on the field!`)
			return
		end
		start(crateDef.Id)
	end)
	back.onClick(goHome)

	local function onClose()
		-- closed mid-animation (Escape, the cutscene): the prize is yours already; say what it was
		closes += 1
		if result and running then
			Toast.show(prizeLine(result))
		end
		stop()
		running, busy = false, false
		skip.Visible = false
		State.release("Coins")
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
			setAgain() -- (a crate key used or bought)
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
