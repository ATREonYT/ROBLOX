-- Floating labels that fade with the distance (BRIEF20). The world's labels (a lane's stack over the ranges: "Locked",
-- "🔄 6", "x5 Power"; the guns' nameplates; the shoe boxes' names; the LOBBY / FURTHEST pads; the hall's notices) are
-- big and clear near you. Walking away they fade out (text, outline and chip together) and shrink a little over a band
-- of distance; walking back they fade in and settle with a small pop, like the reference +1 games.
-- HoodClient/LabelFade runs it; this module holds the rules and the per-label state (UnitTest/Cases/LabelFade_Test).
--
-- Which labels: a BillboardGui inside the active map named Label (on a part named Sign: a lane's stack), GunLabel or
-- WorldLabel, or any BillboardGui tagged HoodFadeLabel. Never GateSign (HoodClient/Stages grows the gate sign with the
-- distance instead, so it reads from the lobby), nor one with FadeOff = true.
-- Optional attributes on the BillboardGui (else its kind's numbers, Kinds below):
--   FadeNear, FadeFar   studs from the camera: whole inside FadeNear, gone past FadeFar (a smoothstep between)
--   FadeMin             its size at FadeFar, as a share of its own size (0.85)
--   FadeShrink, FadeShrinkMin   inside FadeShrink studs it shrinks with the distance, down to FadeShrinkMin (a lane's
--                       big stack never towers over the screen up close: LOOP's 34 / 0.35, like the gate sign's 36)
--   FadeGroup           labels of one group that overlap on screen declutter: one more than 12% covered by a nearer
--                       one fades out until it is under 6% (LOOP's rule for the lanes lined up down the aisle)
--   FadeHold            true: fade out whatever the distance (HoodClient/Lobby: your own lane and its neighbours while
--                       you stand in its box)
--   FadeOff             true: left alone
-- The fades run at a steady rate (in 0.3 s, out 0.4 s), so a camera jump never flickers; a fade-in that ends whole
-- gets the pop. MaxDistance is set to the band's end plus a margin, so the engine stops drawing a label soon after it
-- has faded. LabelFade owns each label's Size and the transparencies of its texts, outlines, frames and images.
local LabelFade = {}

LabelFade.Tag = 'HoodFadeLabel'
LabelFade.IN_TIME, LabelFade.OUT_TIME = 0.3, 0.4 -- seconds for a whole fade in / out (a steady rate)
LabelFade.POP, LabelFade.POP_TIME = 0.12, 0.34 -- the pop's strength (peak ~7% bigger) and length
LabelFade.ARM = 0.35 -- a label that fell below this shows again with the pop
LabelFade.MIN = 0.85 -- the size at the far edge of the band
LabelFade.COVER, LabelFade.SHOW = 0.12, 0.06 -- declutter: share of a label's screen area a nearer one may cover (hide / show again)
LabelFade.SHRINK_TIME = 0.08 -- the near shrink follows the camera with this lag (smooth over the 10 Hz decisions)
LabelFade.PAINT_STEP, LabelFade.SIZE_STEP = 0.025, 0.006 -- smallest change worth writing (transparency, size share)

-- Each kind's band (studs from the camera). Near: whole inside; Far: gone past it.
LabelFade.Kinds = {
	Lane = { Near = 45, Far = 75, Shrink = 34, ShrinkMin = 0.35, Group = 'Lanes' }, -- a lane's stack (12 x 7.2 studs)
	Gun = { Near = 38, Far = 62 }, -- a gun's nameplate in the ARMORY
	Box = { Near = 34, Far = 58 }, -- a shoe box's name and price on the dais
	Pad = { Near = 26, Far = 44 }, -- LOBBY / FURTHEST over a stage's pads
	Sign = { Cap = 70, NearShare = 0.6 }, -- a small WorldLabel (notices, the lobby's FURTHEST STAGE pad): ends at its MaxDistance, 70 at most
	Title = { NearShare = 0.75, TallFrom = 4 }, -- a big floating title (4+ studs tall): across the hall, gone from the streets
}

local function num(v) return type(v) == 'number' and v == v and v or nil end

-- 1 inside near, 0 past far, a smoothstep between.
function LabelFade.band(d, near, far)
	if d <= near then return 1 end
	if d >= far then return 0 end
	local t = (d - near) / (far - near)
	return 1 - t * t * (3 - 2 * t)
end
-- The near shrink: the share of its size a label keeps at distance d (1 when it has none).
function LabelFade.shrink(d, from, least)
	if not from or from <= 0 then return 1 end
	return math.clamp(d / from, least or 0.35, 1)
end
-- One step of a steady-rate fade toward the target.
function LabelFade.approach(a, target, dt)
	if a < target then return math.min(target, a + dt / LabelFade.IN_TIME) end
	if a > target then return math.max(target, a - dt / LabelFade.OUT_TIME) end
	return a
end
-- The size share that goes with a fade (min at a = 0, whole at a = 1).
function LabelFade.fadeSize(a, min) min = min or LabelFade.MIN return min + (1 - min) * a end
-- The pop at u (0..1 of its length): grows, peaks at ~0.35 and settles back to 1 with no jolt at the end.
function LabelFade.pop(u)
	if u <= 0 or u >= 1 then return 1 end
	return 1 + LabelFade.POP * math.sin(math.pi * u) * (1 - u)
end

-- The kind of a BillboardGui, or nil when it isn't one of ours.
function LabelFade.kindOf(gui)
	if typeof(gui) ~= 'Instance' or not gui:IsA('BillboardGui') or gui.Name == 'GateSign' then return nil end
	if gui:GetAttribute('FadeOff') == true then return nil end
	local parent = gui.Parent
	local pname = parent and parent.Name or ''
	if gui.Name == 'Label' and pname == 'Sign' then return 'Lane' end
	if gui.Name == 'GunLabel' then return 'Gun' end
	local tagged = false
	pcall(function() tagged = gui:HasTag(LabelFade.Tag) end)
	if gui.Name == 'WorldLabel' or tagged then
		if pname:match('^BoxLabel_') then return 'Box' end
		if pname:match('PadLabel$') then return 'Pad' end
		return gui.Size.Y.Scale >= LabelFade.Kinds.Title.TallFrom and 'Title' or 'Sign'
	end
	return nil
end

-- A label's numbers: its kind's, with the attributes on top. maxDist: the builder's MaxDistance (Sign and Title kinds).
function LabelFade.config(gui, kind, maxDist)
	local k = LabelFade.Kinds[kind] or LabelFade.Kinds.Sign
	local near, far
	maxDist = num(maxDist) or 90
	if kind == 'Title' then
		far = maxDist
		near = far * k.NearShare
	elseif k.Near then
		near, far = k.Near, k.Far
	else
		far = math.min(maxDist, k.Cap or 70)
		near = far * (k.NearShare or 0.6)
	end
	near = num(gui:GetAttribute('FadeNear')) or near
	far = num(gui:GetAttribute('FadeFar')) or far
	near = math.max(0, near)
	if far < near + 1 then far = near + 1 end
	local group = gui:GetAttribute('FadeGroup')
	if type(group) ~= 'string' or group == '' then group = k.Group end
	return {
		Near = near, Far = far,
		Min = math.clamp(num(gui:GetAttribute('FadeMin')) or LabelFade.MIN, 0.1, 1),
		Shrink = num(gui:GetAttribute('FadeShrink')) or k.Shrink,
		ShrinkMin = math.clamp(num(gui:GetAttribute('FadeShrinkMin')) or k.ShrinkMin or 0.35, 0.05, 1),
		Group = group,
	}
end
-- How far the engine keeps drawing a label with this band: room for a fade-out after a camera jump.
function LabelFade.maxDistanceFor(cfg) return cfg.Far + math.max(15, cfg.Far * 0.35) end

-- Declutter one group (LOOP's lane rule): rows { e = entry, depth, x0, x1, y0, y1, area } in screen pixels; nearest
-- first, a row more than COVER (SHOW while hidden) covered by a shown nearer one is hidden. Sets e.hidden. A change
-- has to be wanted HIDE_PASSES (to hide) or SHOW_PASSES (to show again) decisions running, so a faint label at the
-- edge of a nearer one doesn't blink while you walk (the first decision for a label counts at once).
LabelFade.HIDE_PASSES, LabelFade.SHOW_PASSES = 2, 3
function LabelFade.declutter(rows)
	table.sort(rows, function(a, b) return a.depth < b.depth end)
	local shown = {}
	for _, r in rows do
		local e = r.e
		local covered = 0
		for _, o in shown do
			local ix = math.max(0, math.min(r.x1, o.x1) - math.max(r.x0, o.x0))
			local iy = math.max(0, math.min(r.y1, o.y1) - math.max(r.y0, o.y0))
			covered = math.max(covered, ix * iy)
		end
		local want = covered > r.area * (e.hidden and LabelFade.SHOW or LabelFade.COVER)
		if e.hidden == nil then
			e.hidden, e.flips = want, 0
		elseif want ~= e.hidden then
			e.flips = (e.flips or 0) + 1
			if e.flips >= (want and LabelFade.HIDE_PASSES or LabelFade.SHOW_PASSES) then e.hidden, e.flips = want, 0 end
		else
			e.flips = 0
		end
		if not e.hidden then table.insert(shown, r) end
	end
end

-- Where a label hangs: its Adornee's or parent part's (or attachment's) position plus StudsOffsetWorldSpace.
local function worldOffset(gui)
	local ok, v = pcall(function() return gui.StudsOffsetWorldSpace end)
	return ok and typeof(v) == 'Vector3' and v or Vector3.zero
end
function LabelFade.anchorOf(gui, offset)
	local a = gui.Adornee or gui.Parent
	local pos
	if a and a:IsA('BasePart') then
		pos = a.CFrame.Position
	elseif a and a:IsA('Attachment') and a.Parent and a.Parent:IsA('BasePart') then
		pos = (a.Parent.CFrame * a.CFrame).Position
	end
	return pos and pos + (offset or worldOffset(gui)) or nil
end

-- The faded properties of a label's descendants, with their own (unfaded) values.
local PROPS = {
	TextLabel = { 'TextTransparency', 'TextStrokeTransparency', 'BackgroundTransparency' },
	TextButton = { 'TextTransparency', 'TextStrokeTransparency', 'BackgroundTransparency' },
	TextBox = { 'TextTransparency', 'TextStrokeTransparency', 'BackgroundTransparency' },
	ImageLabel = { 'ImageTransparency', 'BackgroundTransparency' },
	ImageButton = { 'ImageTransparency', 'BackgroundTransparency' },
	Frame = { 'BackgroundTransparency' },
	UIStroke = { 'Transparency' },
}
-- old: a previous list (an instance already in it keeps its own value, not the faded one it shows now).
function LabelFade.collect(gui, old)
	local known = {}
	for _, it in old or {} do
		known[it.inst] = known[it.inst] or {}
		known[it.inst][it.prop] = it.base
	end
	local items = {}
	for _, d in gui:GetDescendants() do
		local props = PROPS[d.ClassName]
		if props then
			for _, prop in props do
				local base = known[d] and known[d][prop]
				if base == nil then base = d[prop] end
				if base < 0.999 then table.insert(items, { inst = d, prop = prop, base = base }) end
			end
		end
	end
	return items
end
function LabelFade.paint(items, a)
	for _, it in items do it.inst[it.prop] = 1 - (1 - it.base) * a end
end

---------------------------------------------------------------------------------------------- the fader
-- local fader = LabelFade.new(); fader:add(gui); every ~0.1 s fader:decide(camera CFrame, focal px); every frame
-- fader:step(dt, camera CFrame). decide reads the attributes, the distances and the declutter; step animates only the
-- labels that are moving or sitting inside a band (the rest cost nothing per frame).
local Fader = {}
Fader.__index = Fader
local builderMax = setmetatable({}, { __mode = 'k' }) -- each label's MaxDistance and Size as the map built them (we change both)
local builderSize = setmetatable({}, { __mode = 'k' })

function LabelFade.new()
	return setmetatable({ entries = {}, awake = {}, count = 0, ticks = 0 }, Fader)
end

local function setSize(e, k)
	e.k = k
	local s = e.size
	e.gui.Size = UDim2.new(s.X.Scale * k, s.X.Offset * k, s.Y.Scale * k, s.Y.Offset * k)
end
local function setAlpha(e, a)
	e.painted = a
	LabelFade.paint(e.items, a)
end
local CFG_KEYS = { 'Near', 'Far', 'Min', 'Shrink', 'ShrinkMin', 'Group' }
local function configure(e)
	local old, cfg = e.cfg, LabelFade.config(e.gui, e.kind, builderMax[e.gui])
	e.cfg = cfg
	local md = LabelFade.maxDistanceFor(cfg)
	if e.gui.MaxDistance ~= md then e.gui.MaxDistance = md end
	e.offset = worldOffset(e.gui)
	for _, k in CFG_KEYS do
		if not old or old[k] ~= cfg[k] then e.still = false break end -- (a new band or size: animate to it)
	end
end

function Fader:add(gui)
	if self.entries[gui] then return self.entries[gui] end
	local kind = LabelFade.kindOf(gui)
	if not kind then return nil end
	if builderMax[gui] == nil then builderMax[gui], builderSize[gui] = gui.MaxDistance, gui.Size end
	local e = { gui = gui, kind = kind, size = builderSize[gui], a = 1, painted = 1, k = 1, s = 1, target = 1, shrinkT = 1, fresh = true }
	e.items = LabelFade.collect(gui)
	configure(e)
	-- (children that arrive later, an icon say, join at the next decision; attribute edits apply at once where the
	-- engine has the signal, else within a second)
	pcall(function() e.conns = { gui.DescendantAdded:Connect(function() e.dirty = true end), gui.AttributeChanged:Connect(function(name)
		if name:sub(1, 4) == 'Fade' and name ~= 'FadeHold' then e.stale = true end
	end) } end)
	self.entries[gui] = e
	self.count += 1
	return e
end
-- Stop managing a label; keep = true leaves it as it shows now, else it goes back to its own look.
function Fader:remove(gui, keep)
	local e = self.entries[gui]
	if not e then return end
	self.entries[gui] = nil
	self.awake[e] = nil
	self.count -= 1
	for _, c in e.conns or {} do c:Disconnect() end
	if not keep then
		pcall(setAlpha, e, 1)
		pcall(setSize, e, 1)
		pcall(function() gui.MaxDistance = builderMax[gui] or gui.MaxDistance end)
	end
end
function Fader:get(gui) return self.entries[gui] end

-- The 10 Hz pass. cam: the camera's CFrame; focal: pixels per stud at one stud's depth (viewport height / 2tan(fov/2)).
function Fader:decide(cam, focal)
	self.ticks += 1
	local poll = self.ticks % 10 == 0
	local eye = cam.Position
	local groups = {}
	for gui, e in self.entries do
		if not gui.Parent then
			self:remove(gui, true)
			continue
		end
		if poll then
			if gui:GetAttribute('FadeOff') == true then
				self:remove(gui)
				continue
			end
			e.stale = true
		end
		if e.stale then
			e.stale = false
			configure(e)
		end
		if e.dirty then
			e.dirty = false
			e.items = LabelFade.collect(gui, e.items)
			setAlpha(e, e.a)
		end
		local pos = gui.Enabled and LabelFade.anchorOf(gui, e.offset)
		if not pos then
			-- Switched off by its owner (a cleared gate's pads, HoodClient/Stages): it shows again by fading in.
			if e.a > 0 or e.fresh then
				e.a, e.target, e.armed, e.fresh, e.popT = 0, 0, true, false, nil
				setAlpha(e, 0)
				setSize(e, e.s * LabelFade.fadeSize(0, e.cfg.Min))
			end
			e.off, e.live = true, false
			self.awake[e] = nil
			continue
		end
		e.off = false
		local cfg = e.cfg
		local d = (pos - eye).Magnitude
		e.band = LabelFade.band(d, cfg.Near, cfg.Far)
		e.shrinkT = LabelFade.shrink(d, cfg.Shrink, cfg.ShrinkMin)
		e.live = (e.band > 0 and e.band < 1) or (cfg.Shrink ~= nil and cfg.Shrink > 0 and d < cfg.Shrink)
		e.hold = gui:GetAttribute('FadeHold') == true
		if cfg.Group and not e.hold and e.band > 0.05 then
			local p = cam:PointToObjectSpace(pos) + gui.StudsOffset
			local depth = -p.Z
			if depth > 1 then
				local s = e.size
				local w = (s.X.Scale * e.shrinkT / depth) * focal + s.X.Offset * e.shrinkT
				local h = (s.Y.Scale * e.shrinkT / depth) * focal + s.Y.Offset * e.shrinkT
				local cx, cy = p.X / depth * focal, p.Y / depth * focal
				groups[cfg.Group] = groups[cfg.Group] or {}
				table.insert(groups[cfg.Group], { e = e, depth = depth, x0 = cx - w / 2, x1 = cx + w / 2, y0 = cy - h / 2, y1 = cy + h / 2, area = w * h })
			else
				e.hidden, e.flips = false, 0 -- (beside or behind the camera: nothing covers it)
			end
		elseif not cfg.Group then
			e.hidden = nil
		end -- (held or faded by the distance: it keeps its last declutter decision for when it comes back)
	end
	for _, rows in groups do LabelFade.declutter(rows) end
	for _, e in self.entries do
		if not e.off and e.band then
			e.target = (e.hold or e.hidden) and 0 or e.band
			if e.fresh then
				-- First sight: shown as it should be, no fade (no burst of pops when the map loads).
				e.fresh = false
				e.a, e.s, e.armed = e.target, e.shrinkT, e.target <= LabelFade.ARM
				setAlpha(e, e.a)
				setSize(e, e.s * LabelFade.fadeSize(e.a, e.cfg.Min))
				e.still = true
			end
			if e.a ~= e.target or e.s ~= e.shrinkT then e.still = false end
			if e.live or not e.still or e.popT then self.awake[e] = true end
		end
	end
end

-- One frame. cam (optional): the camera's CFrame, so labels inside a band follow the distance every frame.
function Fader:step(dt, cam)
	local eye = cam and cam.Position
	local moved = eye ~= nil and (self.eye == nil or (eye - self.eye).Magnitude > 0.01)
	if moved then self.eye = eye end
	for e in self.awake do
		local gui, cfg = e.gui, e.cfg
		if e.live and moved then
			local pos = LabelFade.anchorOf(gui, e.offset)
			if pos then
				local d = (pos - eye).Magnitude
				e.band = LabelFade.band(d, cfg.Near, cfg.Far)
				e.shrinkT = LabelFade.shrink(d, cfg.Shrink, cfg.ShrinkMin)
				e.target = (e.hold or e.hidden) and 0 or e.band
				if e.target ~= e.a or e.shrinkT ~= e.s then e.still = false end
			end
		end
		if e.still and not e.popT then
			-- (settled and written: a label inside a band waits here for the camera to move)
			if not e.live then self.awake[e] = nil end
			continue
		end
		local was = e.a
		local a = LabelFade.approach(was, e.target, dt)
		if a <= LabelFade.ARM then e.armed = true end
		if a >= 1 and was < 1 and e.armed then
			e.armed, e.popT = false, 0 -- (whole again after a real fade: the pop)
		end
		e.a = a
		local s = e.s + (e.shrinkT - e.s) * math.min(1, dt / LabelFade.SHRINK_TIME)
		if math.abs(e.shrinkT - s) < 0.002 then s = e.shrinkT end
		e.s = s
		local pop = 1
		if e.popT then
			e.popT += dt
			local u = e.popT / LabelFade.POP_TIME
			if u >= 1 then e.popT = nil else pop = LabelFade.pop(u) end
		end
		local k = s * LabelFade.fadeSize(a, cfg.Min) * pop
		local settled = a == e.target and s == e.shrinkT and not e.popT
		if math.abs(a - e.painted) >= LabelFade.PAINT_STEP or (a ~= e.painted and (settled or a == 0 or a == 1)) then setAlpha(e, a) end
		if math.abs(k - e.k) >= LabelFade.SIZE_STEP or (settled and k ~= e.k) then setSize(e, k) end
		if settled then
			e.still = true
			if not e.live then self.awake[e] = nil end
		end
	end
end
-- How many labels animate this frame (tests, debugging).
function Fader:awakeCount()
	local n = 0
	for _ in self.awake do n += 1 end
	return n
end

return LabelFade
