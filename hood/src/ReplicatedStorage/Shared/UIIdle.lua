-- UIIdle (Oct 27, the owner: "make the ui more animated, make the luck clovers spin left and right little, add some
-- effects to it to make it look more buyable like references show"): the small idle motions of the Shop and the HUD's
-- offers, all driven by ONE shared Heartbeat loop (not a loop or a tween per card). Every motion is a smooth sine of its
-- own clock, staggered by its phase so nothing moves in sync, and it is only worked out while its gui is on screen (the
-- window open, the card scrolled into view): a closed window costs nothing. The loop stops when nothing is registered.
-- Kid-safe: no flashes (a glow breathes over 1.6 s at most 35% opaque; a shine is one soft band every few seconds), no
-- strobing. ReducedMotion (a player attribute) holds everything still.
--
-- (Oct 27, round 7, OUR_UI_AUDIT C: "the animations are bad") A BUDGET: at most UIIdle.Budget (6) motions move on
-- screen at once, the highest opts.Priority first (the hero cards 3, their big buy buttons 2, the rest 1), then the
-- oldest; the others rest still until one leaves the screen. Nothing wobbles endlessly: a 'rock' swings once and rests
-- (opts.Rest seconds) between swings.
--
--   UIIdle.add(gui, kind, opts) -> rec        rec.stop() ends it (and puts the gui back as it was); opts.Phase (0..1),
--                                             opts.Watch (what must be on screen; default gui), opts.Priority (1)
--     'rock'     gui.Rotation swings +-Deg (5) over Period (1.5 s), then rests Rest (2.5 s)   (the Lucky clover)
--     'bob'      gui.Position rises Px (4) and back over Period (2.2 s)           (cash, boxes, gifts)
--     'breathe'  a UIScale (opts.Name, 'IdleScale') 1 -> 1 + Amount (0.04) over Period (1.8 s)   (potions, crowns)
--     'glow'     a soft rounded halo behind gui (opts.Color, Pad 5, Radius 10) breathing 0.65 -> 0.95 transparent
--                over Period (1.6 s)                                                (the green Robux buttons)
--     'sweep'    opts.Band (a Frame in a clipping parent) crosses from X -0.3 to 1.3 over Dur (0.9 s), once every
--                Every (3.5 s), after Delay; or, with opts.Gradient, the band stays and that UIGradient's Offset
--                crosses from -1 to 1 (UIMotion.shine)                             (the shine on cards and buttons)
--     'twinkle'  opts.Star (a Frame) with opts.Scale (its UIScale): grows in (0.35 s), turns 45 deg, shrinks out by 0.72
--                s, at a new random spot (Inset) every Every (2.8 s)               (SellFX.sparkles)
--   UIIdle.icon(art, id, i) -> rec | nil       the idle motion that suits an item icon (by its icon id), phase i
--   UIIdle.step(dt)                            one tick by hand (the offline renderer); UIIdle.count()
local RunService = game:GetService('RunService')
local Players = game:GetService('Players')

local UIIdle = {}
UIIdle.VisEvery = 0.25 -- seconds between the on-screen checks (and the budget's pick)
UIIdle.Budget = 6 -- motions moving on screen at once (UI_CRISP_AND_JUICE: a calm screen with a few loud things)

local ImageLoader -- (lazy: its onScreen walks the parents, ScrollingFrames included)
local items = {}
local clock = 0
local conn
local GOLDEN = 0.618034

local function onScreen(gui, memo)
	if not ImageLoader then
		local ok, m = pcall(require, script.Parent.ImageLoader)
		ImageLoader = ok and m or false
	end
	if not ImageLoader then return true end
	local ok, shown = pcall(ImageLoader.onScreen, gui, memo)
	return ok and shown
end
local function reduced()
	local p = Players.LocalPlayer
	return p ~= nil and p:GetAttribute('ReducedMotion') == true
end
local function wave(rec) return math.sin((clock / rec.period + rec.phase) * 2 * math.pi) end

local KINDS = {}
KINDS.rock = {
	init = function(rec) rec.base = rec.gui.Rotation; rec.period = rec.o.Period or 1.5 end,
	step = function(rec, still)
		-- (one swing, then a rest: a little wiggle every few seconds, never an endless wobble)
		local cycle = rec.period + (rec.o.Rest or 2.5)
		local t = (clock + rec.phase * cycle) % cycle
		local a = (still or t >= rec.period) and 0 or (rec.o.Deg or 5) * math.sin(t / rec.period * 2 * math.pi)
		rec.gui.Rotation = rec.base + a
	end,
	stop = function(rec) rec.gui.Rotation = rec.base end,
}
KINDS.bob = {
	init = function(rec) rec.base = rec.gui.Position; rec.period = rec.o.Period or 2.2 end,
	step = function(rec, still)
		local y = still and 0 or -(rec.o.Px or 4) * (0.5 + 0.5 * wave(rec))
		rec.gui.Position = rec.base + UDim2.fromOffset(0, math.floor(y * 10 + 0.5) / 10)
	end,
	stop = function(rec) rec.gui.Position = rec.base end,
}
KINDS.breathe = {
	init = function(rec)
		rec.period = rec.o.Period or 1.8
		local name = rec.o.Name or 'IdleScale'
		rec.scale = rec.gui:FindFirstChild(name)
		if not (rec.scale and rec.scale:IsA('UIScale')) then
			rec.scale = Instance.new('UIScale')
			rec.scale.Name = name
			rec.scale.Parent = rec.gui
		end
	end,
	step = function(rec, still) rec.scale.Scale = 1 + (still and 0 or (rec.o.Amount or 0.04) * (0.5 + 0.5 * wave(rec))) end,
	stop = function(rec) rec.scale.Scale = 1 end,
}
KINDS.glow = {
	init = function(rec)
		rec.period = rec.o.Period or 1.6
		local pad = rec.o.Pad or 5
		local g = Instance.new('Frame')
		g.Name = 'IdleGlow'
		g.BorderSizePixel = 0
		g.BackgroundColor3 = rec.o.Color or Color3.fromRGB(150, 255, 90)
		g.BackgroundTransparency = 1
		g.AnchorPoint = Vector2.new(0.5, 0.5)
		g.Position = UDim2.fromScale(0.5, 0.5)
		g.Size = UDim2.new(1, 2 * pad, 1, 2 * pad)
		g.ZIndex = math.max(0, rec.o.ZIndex or (rec.gui.ZIndex - 1))
		local c = Instance.new('UICorner')
		c.CornerRadius = UDim.new(0, rec.o.Radius or 10)
		c.Parent = g
		g.Parent = rec.gui
		rec.glow = g
	end,
	step = function(rec, still)
		-- (0.65 .. 0.95 transparent: a soft breath, never a flash)
		rec.glow.BackgroundTransparency = still and 1 or (0.8 - 0.15 * wave(rec))
	end,
	stop = function(rec) rec.glow:Destroy() end,
}
local function smooth(u) return u * u * (3 - 2 * u) end
KINDS.sweep = {
	init = function(rec) rec.period = rec.o.Every or 3.5 end,
	step = function(rec, still)
		local band = rec.o.Band
		local dur = rec.o.Dur or 0.9
		local t = clock - rec.t0 - (rec.o.Delay or 0) + rec.phase * rec.period
		local u = t >= 0 and (t % rec.period) / dur or 2
		local g = rec.o.Gradient
		if g then
			-- (a full-size band whose UIGradient carries the light: its Offset crosses from -1 to 1)
			g.Offset = Vector2.new((still or u >= 1) and -1 or (-1 + 2 * smooth(u)), 0)
		elseif still or u >= 1 then
			if band.Visible then band.Visible = false end
		else
			band.Visible = true
			band.Position = UDim2.new(-0.3 + 1.6 * smooth(u), 0, band.Position.Y.Scale, band.Position.Y.Offset)
		end
	end,
	stop = function(rec) if rec.o.Gradient then rec.o.Gradient.Offset = Vector2.new(-1, 0) else rec.o.Band.Visible = false end end,
}
local function backOut(u) local c = 1.70158; u -= 1; return 1 + (c + 1) * u ^ 3 + c * u * u end
KINDS.twinkle = {
	init = function(rec)
		rec.period = rec.o.Every or 2.8
		rec.rng = Random.new(rec.o.Seed or 1)
		rec.cycle = -1
	end,
	step = function(rec, still)
		local star, sc = rec.o.Star, rec.o.Scale
		local t = clock - rec.t0 - (rec.o.Delay or 0)
		if still or t < 0 then
			if star.Visible then star.Visible = false end
			return
		end
		local n = math.floor(t / rec.period)
		local c = t - n * rec.period
		if n ~= rec.cycle then
			rec.cycle = n
			local inset = rec.o.Inset or 0.08
			star.Position = UDim2.fromScale(inset + rec.rng:NextNumber() * (1 - 2 * inset), inset + rec.rng:NextNumber() * (1 - 2 * inset))
		end
		if c >= 0.72 then
			if star.Visible then star.Visible = false end
			return
		end
		star.Visible = true
		star.Rotation = 45 * smooth(math.min(1, c / 0.7))
		sc.Scale = c < 0.35 and backOut(c / 0.35) or (c < 0.42 and 1 or 1 - (c - 0.42) / 0.3)
	end,
	stop = function(rec) rec.o.Star.Visible = false end,
}

local pickAt = 0
local function stepRec(rec, still)
	local ok, err = pcall(rec.k.step, rec, still)
	if not ok and not rec.warned then
		rec.warned = true
		warn('[UIIdle] ' .. rec.kind .. ': ' .. tostring(err))
	end
end
local function before(a, b)
	if a.prio ~= b.prio then return a.prio > b.prio end
	return a.serial < b.serial
end
local function tick(dt)
	clock += dt
	local now = clock
	local still = reduced()
	local repick = now >= pickAt
	local memo = repick and {} or nil
	if repick then pickAt = now + UIIdle.VisEvery end
	local live = repick and {} or nil
	for i = #items, 1, -1 do
		local rec = items[i]
		local alive, parent = pcall(function() return rec.gui.Parent end)
		if rec.dead or not alive or parent == nil then
			table.remove(items, i)
		elseif repick then
			rec.vis = onScreen(rec.watch, memo)
			if rec.vis then table.insert(live, rec) end
		end
	end
	if repick then
		-- the budget: the first Budget on screen move, the others rest
		table.sort(live, before)
		for _, rec in items do rec.wasOn, rec.on = rec.on, false end
		for n, rec in live do rec.on = n <= UIIdle.Budget end
		for _, rec in items do
			if rec.wasOn and not rec.on then stepRec(rec, true) end -- (put to rest, not frozen mid-swing)
		end
	end
	for _, rec in items do
		if rec.on then stepRec(rec, still) end
	end
	if #items == 0 and conn then
		conn:Disconnect()
		conn = nil
	end
end
UIIdle.step = tick
function UIIdle.count() return #items end

local serial = 0
function UIIdle.add(gui, kind, opts)
	local k = KINDS[kind]
	if not (k and typeof(gui) == 'Instance') then return nil end
	serial += 1
	opts = opts or {}
	-- (staggered: an explicit Phase (0..1), else the golden-ratio walk, so neighbours never move together)
	-- (opts.Watch: what must be on screen for it to move, when gui itself hides between beats: a sparkle, a shine band)
	local rec = { gui = gui, watch = opts.Watch or gui, kind = kind, k = k, o = opts, phase = opts.Phase or ((serial * GOLDEN) % 1), vis = false, on = false, t0 = clock,
		prio = tonumber(opts.Priority) or 1, serial = serial }
	pickAt = 0 -- (a new motion joins the budget at the next tick)
	local ok, err = pcall(k.init, rec)
	if not ok then
		warn('[UIIdle] ' .. kind .. ': ' .. tostring(err))
		return nil
	end
	function rec.stop()
		if rec.dead then return end
		rec.dead = true
		pcall(k.stop, rec)
	end
	table.insert(items, rec)
	if not conn then
		local okC, c = pcall(function() return RunService.Heartbeat:Connect(function(dt)
			local fine, e = pcall(tick, dt)
			if not fine then warn('[UIIdle] loop: ' .. tostring(e)) end
		end) end)
		if okC then conn = c end
	end
	return rec
end

-- The idle motion for an item icon, by what it shows: the clover (and the other "luck" things) rocks; cash, boxes and
-- gifts bob; potions, crowns, muscles and the rest breathe. i: its place in a row (the stagger).
local ROCK = { Lucky = true, Clover = true, LuckyClover = true, Speed2x = true, Arrow = true, Sneaker = true }
local BOB = { Cash = true, CashSmall = true, CashMedium = true, CashLarge = true, CashBig = true, CashMega = true, DoubleCash = true,
	TripleOpen = true, AutoOpen = true, Gift = true, StarterPack = true, ServerBoost = true, BlockParty = true }
-- (round 7) prio: its budget Priority (default 1). The clover's swing is one 1.2 s wiggle every 4 s (the owner asked
-- for the clovers to "spin left and right little"); a gun breathes (no endless rotation).
function UIIdle.icon(art, id, i, prio)
	if typeof(art) ~= 'Instance' then return nil end
	id = tostring(id or '')
	local phase = ((i or 0) * 0.29) % 1
	if ROCK[id] then return UIIdle.add(art, 'rock', { Deg = 5, Period = 1.2, Rest = 2.8, Phase = phase, Priority = prio }) end
	if BOB[id] or id:match('^Box_') or id:match('^Cash') then return UIIdle.add(art, 'bob', { Px = 4, Period = 2.0, Phase = phase, Priority = prio }) end
	return UIIdle.add(art, 'breathe', { Amount = 0.04, Period = 2.0, Phase = phase, Priority = prio })
end

return UIIdle
