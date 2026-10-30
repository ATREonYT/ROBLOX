-- ImageLoader: draws the game's pictures in game from the pixels packed into Shared/Images (EditableImage), so they
-- show without the owner uploading anything (the owner, Oct 27: "directly import the images of the ui, I did it with my
-- other game"). Ported from his Huzz Valley (HuzzClient/UI/ImageLoader.lua and docs/notes/ui.md), with its lessons:
--   * an uploaded id wins: a label with one (IconModels.Images) shows it and is never drawn here;
--   * Roblox draws EditableImages only when Game Settings > Security > "Allow Mesh / Image APIs" is on (and the place
--     is published). With it off nothing can be drawn: every label gets its stand-in (opts.onFail: Kit's own drawn look
--     or the flat icon, never a blank or a box on screen) and Output gets ONE [HoodUI] line naming the fix;
--   * each screen has a fixed EditableImage memory budget. So a picture is drawn only while a label showing it is on
--     screen (its ScreenGui on, every frame up to it Visible, inside its scrolling list or half a list away), one a
--     frame; each picture counts its labels: one whose labels are all gone is freed at once, one nobody saw for
--     IDLE_FREE seconds is freed too (drawn again when it shows); when the budget is full the picture unseen longest
--     is freed to make room (at most 8 times for one picture);
--   * a failure is never kept: it is tried again after RETRY seconds, doubling up to RETRY_MAX;
--   * a big picture is decoded in slices (a frame each) so opening a window never freezes the game;
--   * a strong table of labels, dropped on Destroying (never a weak table keyed by Instance, CLAUDE.md);
--   * every loop pcalls each step and reports an error once.
-- Packed formats (hood/tools/ui/pack_images.py): Icons (Oct 27, round 7) { W, H, Z = base64 zlib stream of the PNG's
-- filtered RGBA rows } (full colour, edge-colour filled; Shared/Inflate decodes it); Ui { W, H, P = base64 RGBA palette,
-- Data = base64 (count, index) runs, Mode?, Slice? }. Kinds: 'Icons' (hood/art/icons3d) and 'Ui' (the owner's UI
-- pieces, hood/art/ui_owner).
--   (round 7, OUR_UI_AUDIT C1: no picture pops in after a window opens) ImageLoader.prepare(root, maxWait, done): draws
--   now every picture under `root` that will be in view once it shows (at most PrepareMax of them) and preloads its
--   uploaded ones, then calls done() (at the latest after maxWait seconds): a window opens when its pictures are ready.
--   ImageLoader.fresh(name): whether an icon's upload is its current drawing (Shared/Images/Uploads, from the packer).
--   ImageLoader.apply(label, kind, name, uploadedId?, opts?)  opts: onShow(label) once its picture shows, onFail(label)
--                                                             when it can't (yet); both may run again later
--   ImageLoader.packed(kind, name) -> module?                 ImageLoader.meta(kind, name) -> { W, H, Mode, Slice }?
-- Every label it takes gets the attribute Packed = '<kind>/<name>' (the offline UI preview draws the PNG by it).
local ImageLoader = {}
ImageLoader.IDLE_FREE = 120
ImageLoader.RETRY = 5
ImageLoader.RETRY_MAX = 60

local Images = script.Parent:FindFirstChild('Images')
local Inflate = require(script.Parent.Inflate)
ImageLoader.PrepareMax = 24 -- pictures one window may draw before it opens (the rest draw as they scroll into view)

local ALPHABET = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'
local VALUE = {}
for i = 1, 64 do VALUE[string.byte(ALPHABET, i)] = i - 1 end

local function decode(s)
	local n = #s
	local pad = (string.sub(s, -2) == '==' and 2) or (string.sub(s, -1) == '=' and 1) or 0
	local len = n // 4 * 3 - pad
	local out = buffer.create(len)
	local o = 0
	local slice = coroutine.isyieldable() and 49152 or math.huge
	local nextWait = slice
	for i = 1, n, 4 do
		if i > nextWait then
			nextWait += slice
			task.wait()
		end
		local a, b, c, d = string.byte(s, i, i + 3)
		local v = VALUE[a] * 262144 + VALUE[b] * 4096 + (VALUE[c] or 0) * 64 + (VALUE[d] or 0)
		buffer.writeu8(out, o, v // 65536)
		if o + 1 < len then buffer.writeu8(out, o + 1, (v // 256) % 256) end
		if o + 2 < len then buffer.writeu8(out, o + 2, v % 256) end
		o += 3
	end
	return out
end

ImageLoader.base64 = decode -- (base64 text -> buffer; the checks use it)

function ImageLoader.packed(kind, name)
	local folder = Images and Images:FindFirstChild(kind)
	local m = folder and folder:FindFirstChild(name)
	return m
end
local metas = {}
function ImageLoader.meta(kind, name)
	local key = kind .. '/' .. name
	if metas[key] == nil then
		metas[key] = false
		local m = ImageLoader.packed(kind, name)
		if m then
			local ok, d = pcall(require, m)
			if ok and type(d) == 'table' then metas[key] = { W = d.W, H = d.H, Mode = d.Mode, Slice = d.Slice } end
		end
	end
	return metas[key] or nil
end

-- The packed pixels as RGBA bytes.
function ImageLoader.pixels(kind, name)
	local m = ImageLoader.packed(kind, name)
	assert(m, 'no packed image ' .. kind .. '/' .. name)
	local d = require(m)
	if d.Z then
		-- (round 7) full colour: the PNG's own compressed rows, inflated and un-filtered
		local raw = Inflate.zlib(decode(d.Z), d.H * (d.W * 4 + 1))
		return Inflate.unfilter(raw, d.W, d.H), d.W, d.H
	end
	local palette = decode(d.P)
	local runs = decode(d.Data)
	local rgba = buffer.create(d.W * d.H * 4)
	local o, limit = 0, d.W * d.H * 4
	for i = 0, buffer.len(runs) - 2, 2 do
		local count, idx = buffer.readu8(runs, i), buffer.readu8(runs, i + 1)
		local px = buffer.readu32(palette, idx * 4)
		for _ = 1, count do
			if o >= limit then break end
			buffer.writeu32(rgba, o, px)
			o += 4
		end
	end
	return rgba, d.W, d.H
end

-- A new EditableImage of the packed pixels and the Content a label shows it by. Errors when Roblox refuses (the
-- setting) or the screen's picture memory is full. (A preview or test may replace it.)
function ImageLoader.make(kind, name)
	local AssetService = game:GetService('AssetService')
	local rgba, w, h = ImageLoader.pixels(kind, name)
	local size = Vector2.new(w, h)
	local image = AssetService:CreateEditableImage({ Size = size })
	if not image then error('out of picture memory (EditableImage budget)') end
	local ok, err = pcall(function() image:WritePixelsBuffer(Vector2.zero, size, rgba) end)
	if not ok then
		image:Destroy()
		error(err)
	end
	local fine, content = pcall(function() return Content.fromObject(image) end)
	if not fine then
		image:Destroy()
		error(content)
	end
	return image, content
end

-- Whether this place can draw at all (a client with AssetService:CreateEditableImage). The offline harness can't: its
-- labels go straight to their stand-ins. (A preview may set ImageLoader.Supported = true with a fake make.)
function ImageLoader.supported()
	if ImageLoader.Supported ~= nil then return ImageLoader.Supported end
	local ok, yes = pcall(function()
		return game:GetService('RunService'):IsClient() and type(game:GetService('AssetService').CreateEditableImage) == 'function'
	end)
	ImageLoader.Supported = ok and yes == true
	return ImageLoader.Supported
end

local drawn = {} -- [key] = { image, content, seen }
local failed = {} -- [key] = { at, wait }
local bound = {} -- [label] = { kind, name, key, shown, opts, failedShown }
local hooked = {}
local anyDrawn, blocked = false, false
local warned = {}
local evictions = {}

local function warnOnce(kind, text)
	if warned[kind] then return end
	warned[kind] = true
	warn('[HoodUI] ' .. text)
end

local function inView(label, box)
	local ls, bs = label.AbsoluteSize, box.AbsoluteSize
	if ls.X <= 0 or ls.Y <= 0 or bs.X <= 0 or bs.Y <= 0 then return true end
	local lp, bp = label.AbsolutePosition, box.AbsolutePosition
	local margin = bs.Y * 0.5
	return lp.X + ls.X >= bp.X and lp.X <= bp.X + bs.X and lp.Y + ls.Y >= bp.Y - margin and lp.Y <= bp.Y + bs.Y + margin
end
local function chain(node, memo)
	if not node then return { shown = false } end
	local known = memo[node]
	if known then return known end
	local c
	if node:IsA('GuiObject') then
		if not node.Visible then
			c = { shown = false }
		else
			local up = chain(node.Parent, memo)
			c = { shown = up.shown, scroll = node:IsA('ScrollingFrame') and node or up.scroll }
		end
	elseif node:IsA('LayerCollector') then
		c = { shown = node.Enabled and not node:IsDescendantOf(game:GetService('StarterGui')) }
	else
		c = chain(node.Parent, memo)
	end
	memo[node] = c
	return c
end
local function onScreen(label, memo)
	if label:IsA('GuiObject') and not label.Visible then return false end
	local c = chain(label.Parent, memo or {})
	if not c.shown then return false end
	if c.scroll then
		local fine, shown = pcall(inView, label, c.scroll)
		if fine and not shown then return false end
	end
	return true
end
ImageLoader.onScreen = onScreen

local function call(fn, label)
	if type(fn) ~= 'function' then return end
	local ok, err = pcall(fn, label)
	if not ok then warnOnce('callback', 'picture callback: ' .. tostring(err)) end
end
local function setContent(label, content) pcall(function() label.ImageContent = content end) end
local function clearContent(label) pcall(function() label.ImageContent = Content.none end) end

local function show(label, b, e)
	-- (a label already dropped or destroyed is skipped: its callback would touch a face that is gone)
	local there, parent = pcall(function() return label.Parent end)
	if not there or parent == nil then return end
	setContent(label, e.content)
	b.shown, b.failedShown = true, false
	call(b.opts.onShow, label)
end
local function fail(label, b)
	if b.failedShown or label.Parent == nil then return end
	b.failedShown = true
	call(b.opts.onFail, label)
end

local function unbind(label)
	bound[label] = nil
	local c = hooked[label]
	if c then
		c:Disconnect()
		hooked[label] = nil
	end
end

local function free(key)
	local e = drawn[key]
	if not e then return end
	drawn[key] = nil
	for label, b in bound do
		if b.key == key and b.shown then
			b.shown = false
			clearContent(label)
		end
	end
	pcall(function() e.image:Destroy() end)
end

local function freeOldest()
	local showing, memo = {}, {}
	for label, b in bound do
		local fine, visible = pcall(onScreen, label, memo)
		if b.shown and fine and visible then showing[b.key] = true end
	end
	local oldest, at = nil, math.huge
	for key, e in drawn do
		if not showing[key] and e.seen < at then oldest, at = key, e.seen end
	end
	if oldest then free(oldest) end
	return oldest ~= nil
end

local function draw(kind, name, key)
	local ok, a, c = pcall(ImageLoader.make, kind, name)
	local now = os.clock()
	if ok then
		local e = { image = a, content = c, seen = now }
		drawn[key] = e
		failed[key], evictions[key] = nil, nil
		anyDrawn, blocked = true, false
		for label, b in bound do
			if b.key == key then show(label, b, e) end
		end
		return true
	end
	local why = tostring(a)
	local lower = string.lower(why)
	local memory = anyDrawn or string.find(lower, 'memory', 1, true) ~= nil or string.find(lower, 'budget', 1, true) ~= nil
	if memory and (evictions[key] or 0) < 8 and freeOldest() then
		evictions[key] = (evictions[key] or 0) + 1
		return false
	end
	evictions[key] = nil
	local f = failed[key]
	local wait = f and math.min(f.wait * 2, ImageLoader.RETRY_MAX) or ImageLoader.RETRY
	failed[key] = { at = now + wait, wait = wait }
	if memory then
		warnOnce('memory', "Some pictures can't be drawn right now: this screen's picture memory is full (" .. why .. '). They are tried again as others are freed. Uploading them once avoids this.')
	else
		blocked = true
		warnOnce('blocked', "The UI pictures can't be drawn (" .. why .. "). Fix: Home > Game Settings > Security > turn on 'Allow Mesh / Image APIs', then Save (the place must be published). Until then the windows show their plain drawn look.")
	end
	for label, b in bound do
		if (b.key == key or (blocked and not drawn[b.key])) and not b.shown then fail(label, b) end
	end
	return false
end

local running = false
local lastSweep = 0
local pending = {}
local function scan()
	local now = os.clock()
	local seen, held, listed, dead, memo = {}, {}, {}, {}, {}
	table.clear(pending)
	for label, b in bound do
		local fine, visible = pcall(onScreen, label, memo)
		local there, parent = pcall(function() return label.Parent end)
		if not fine or not there or parent == nil then table.insert(dead, label) end -- (a label dropped without Destroy too)
		if fine then held[b.key] = true end
		if fine and visible then
			seen[b.key] = true
			local e = drawn[b.key]
			if e then
				e.seen = now
				if not b.shown then show(label, b, e) end
			elseif not listed[b.key] then
				local f = failed[b.key]
				if not f or now >= f.at then
					listed[b.key] = true
					table.insert(pending, { label = label, b = b })
				end
			end
		end
	end
	for _, label in dead do unbind(label) end
	if now - lastSweep > 1 then
		lastSweep = now
		local gone = {}
		for key, e in drawn do
			if not held[key] or (not seen[key] and now - e.seen > ImageLoader.IDLE_FREE) then table.insert(gone, key) end
		end
		for _, key in gone do free(key) end
	end
end
local function drawNext()
	while #pending > 0 do
		local job = table.remove(pending, 1)
		local b = job.b
		local fine, visible = pcall(onScreen, job.label)
		if bound[job.label] == b and not drawn[b.key] and fine and visible then
			local fine, done = pcall(draw, b.kind, b.name, b.key)
			if fine and not done and not failed[b.key] then table.insert(pending, 1, job) end
			return true
		end
	end
	return false
end
local function loop()
	running = true
	task.spawn(function()
		local lastScan = 0
		while next(bound) ~= nil or next(drawn) ~= nil do
			local busy = false
			if blocked then table.clear(pending) end
			if #pending > 0 then
				local fine, tried = pcall(drawNext)
				if not fine then warnOnce('loop', 'picture loop: ' .. tostring(tried)) end
				busy = fine and tried
			end
			if not busy and os.clock() - lastScan >= 0.2 then
				lastScan = os.clock()
				local fine, err = pcall(scan)
				if not fine then warnOnce('loop', 'picture loop: ' .. tostring(err)) end
				busy = #pending > 0 and not blocked
			end
			task.wait(busy and nil or 0.2)
		end
		running = false
	end)
end

-- Points `label` at a picture: the uploaded id when there is one, else the packed pixels (drawn while the label is on
-- screen). Without a packed picture, or where nothing can be drawn, opts.onFail(label) puts its stand-in up.
function ImageLoader.apply(label, kind, name, uploadedId, opts)
	opts = opts or {}
	label:SetAttribute('Packed', kind .. '/' .. name)
	if type(uploadedId) == 'string' and uploadedId ~= '' then
		unbind(label)
		label.Image = uploadedId
		call(opts.onShow, label)
		return
	end
	local key = kind .. '/' .. name
	local b = { kind = kind, name = name, key = key, shown = false, opts = opts, failedShown = false }
	if not ImageLoader.packed(kind, name) or not ImageLoader.supported() then
		unbind(label)
		fail(label, b)
		return
	end
	local old = bound[label]
	if old and old.key ~= key and old.shown then clearContent(label) end
	bound[label] = b
	if not hooked[label] then
		hooked[label] = label.Destroying:Connect(function() unbind(label) end)
	end
	local e = drawn[key]
	if e then
		show(label, b, e)
	elseif blocked or failed[key] then
		fail(label, b)
	end
	if not running then loop() end
end

-- Is `label` (a descendant of root) in view once root shows: every GuiObject from it up to root Visible, and inside
-- its scrolling list (or half a list away), whatever root's own ancestors are doing.
local function inViewUnder(label, root)
	if label:IsA('GuiObject') and not label.Visible then return false end
	local node, scroll = label.Parent, nil
	while node and node ~= root do
		if node:IsA('GuiObject') then
			if not node.Visible then return false end
			if not scroll and node:IsA('ScrollingFrame') then scroll = node end
		end
		node = node.Parent
	end
	if node ~= root then return false end
	if scroll then
		local fine, shown = pcall(inView, label, scroll)
		if fine and not shown then return false end
	end
	return true
end
local preloaded = {} -- [uploaded id] = true
-- (Oct 27, round 7) Gets root's pictures ready before it shows: the packed ones that will be in view are drawn now (one
-- after another, at most PrepareMax), the uploaded ones are preloaded (ContentProvider); done() runs once when they are
-- all there, or after maxWait seconds (whichever is first; at once when nothing is missing). Returns true when nothing
-- was missing (done has already run).
function ImageLoader.prepare(root, maxWait, done)
	local finished = false
	local function finish()
		if finished then return end
		finished = true
		if type(done) == 'function' then
			local ok, err = pcall(done)
			if not ok then warnOnce('prepare', 'prepare callback: ' .. tostring(err)) end
		end
	end
	local missing, keys, uploads = {}, {}, {}
	local now = os.clock()
	local okWalk = pcall(function()
		for label, b in bound do
			if label:IsDescendantOf(root) and inViewUnder(label, root) then
				local e = drawn[b.key]
				if e then
					e.seen = now
					if not b.shown then show(label, b, e) end
				elseif not keys[b.key] and not blocked and not failed[b.key] and #missing < ImageLoader.PrepareMax then
					keys[b.key] = true
					table.insert(missing, b)
				end
			end
		end
		for _, d in root:GetDescendants() do
			if d:IsA('ImageLabel') or d:IsA('ImageButton') then
				local id = d.Image
				if type(id) == 'string' and string.sub(id, 1, 13) == 'rbxassetid://' and not preloaded[id] and inViewUnder(d, root) then
					preloaded[id] = true
					table.insert(uploads, d)
				end
			end
		end
	end)
	if not okWalk or (#missing == 0 and #uploads == 0) then
		finish()
		return true
	end
	local left = (#missing > 0 and 1 or 0) + (#uploads > 0 and 1 or 0)
	local function part()
		left -= 1
		if left <= 0 then finish() end
	end
	if #missing > 0 then
		task.spawn(function()
			for _, b in missing do
				if finished and maxWait then break end -- (late: the rest draw as usual, once in view)
				if not drawn[b.key] and not failed[b.key] and not blocked then
					local fine, ok = pcall(draw, b.kind, b.name, b.key)
					if fine and not ok and not failed[b.key] then pcall(draw, b.kind, b.name, b.key) end -- (once more after freeing room)
				end
			end
			part()
		end)
	end
	if #uploads > 0 then
		task.spawn(function()
			pcall(function() game:GetService('ContentProvider'):PreloadAsync(uploads) end)
			part()
		end)
	end
	if maxWait then task.delay(maxWait, finish) end
	if not running then loop() end
	return false
end

-- Whether an icon's upload (IconModels.Images) is its current drawing: Shared/Images/Uploads.Fresh, written by the
-- packer. Without that list every upload counts as current (as before).
local uploadsInfo
function ImageLoader.fresh(name)
	if uploadsInfo == nil then
		uploadsInfo = false
		local m = Images and Images:FindFirstChild('Uploads')
		if m then
			local ok, d = pcall(require, m)
			if ok and type(d) == 'table' and type(d.Fresh) == 'table' then uploadsInfo = d end
		end
	end
	if not uploadsInfo then return true end
	return uploadsInfo.Fresh[name] == true
end

-- For the checks: whether the label shows its drawn picture, and how many pictures are drawn.
function ImageLoader.showing(label)
	local b = bound[label]
	return b ~= nil and b.shown and drawn[b.key] ~= nil
end
function ImageLoader.drawnCount()
	local n = 0
	for _ in drawn do n += 1 end
	return n
end

return ImageLoader
