-- Draws the kit's icons and pictures in-game from the pixel data packed into Shared/Images (EditableImage), so they
-- show without the owner uploading them. If an image has an uploaded ID in Config/Assets, that ID is used instead.
-- Each image is decoded once and shared by every ImageLabel that shows it.
-- Why pictures can be missing (owner, Oct 19: "make the pictures in all of the ui appear"): Config/ImageIds is empty
-- until he runs Upload Pictures once, so every picture is drawn here with EditableImage, which Roblox only allows when
-- Game Settings > Security > "Allow Mesh / Image APIs" is on (and the place is published). With it off nothing can
-- be drawn. Then each picture gets a stand-in glyph instead of staying blank (a coin bag for coins, a knife for knife
-- pictures..., GLYPH below; decorations like rays get none), and Output gets one [HuzzUI] line with the one fix
-- (docs/STUDIO-STEPS.md Part 1); never a box on screen (owner, Oct 19: "please remove the red pop up"). The glyphs
-- carry the NoPicture attribute: never saved into StarterGui, never drawn by the offline preview, and removed as soon
-- as the real picture shows.
-- Picture memory (owner, Oct 20 14:07: "please fix all of the placeholders for knifes, coins": in Play most knife
-- cards and two coin packs showed stand-ins while the first few drew). Roblox gives each screen a fixed memory
-- budget for EditableImages (shared with the EditableMeshes Gameplay/KnifeDress makes); past it CreateEditableImage
-- gives nothing (or errors), and the old loader then kept that "can't draw" forever and drew everything up front,
-- seen or not. Now:
--   * a picture is drawn only while a label showing it is on screen (its ScreenGui on, every frame up to it Visible),
--     one per frame, so a closed shop tab holds no memory;
--   * each picture counts the labels that show it: one whose labels are all gone is freed at once, one not on screen
--     for IDLE_FREE seconds is freed too (drawn again when it shows), and when the budget is full the picture unseen
--     the longest is freed to make room;
--   * a failure is never kept: it is tried again later (RETRY seconds, doubling up to a minute);
--   * the last fallback for a knife card that still can't be drawn is the knife's own 3D model in a ViewportFrame
--     (remote KnifeView: HuzzServer/KnifeGlbService hands this screen a copy), never the kitchen-knife emoji.
-- Output says once which of the two it was ("[HuzzUI] ..."): Roblox refusing (the setting) or the memory budget.
local AssetService = game:GetService("AssetService")
local Players = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Images = Shared:WaitForChild("Images")

local ImageLoader = {}
ImageLoader.IDLE_FREE = 30 -- seconds a drawn picture may stay off screen before it's freed
ImageLoader.RETRY = 5 -- seconds before a picture that failed is tried again (doubles each time, up to RETRY_MAX)
ImageLoader.RETRY_MAX = 60

local ALPHABET = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local VALUE = {}
for i = 1, 64 do VALUE[string.byte(ALPHABET, i)] = i - 1 end

local function decode(s: string): buffer
	local n = #s
	local pad = if string.sub(s, -2) == "==" then 2 elseif string.sub(s, -1) == "=" then 1 else 0
	local len = n // 4 * 3 - pad
	local out = buffer.create(len)
	local o = 0
	for i = 1, n, 4 do
		local a, b, c, d = string.byte(s, i, i + 3)
		local v = VALUE[a] * 262144 + VALUE[b] * 4096 + (VALUE[c] or 0) * 64 + (VALUE[d] or 0)
		buffer.writeu8(out, o, v // 65536)
		if o + 1 < len then buffer.writeu8(out, o + 1, (v // 256) % 256) end
		if o + 2 < len then buffer.writeu8(out, o + 2, v % 256) end
		o += 3
	end
	return out
end

-- A new EditableImage holding the packed pixels (kind = "Icons" or "Art"). Errors if it can't be made here
-- (Roblox refused, or the screen's picture memory is full: then CreateEditableImage gives nil).
-- (Also used by tools/studio/upload-images.lua to upload each image once; it passes `module` for the effect
-- textures, which live in ServerStorage > HuzzImages > Fx.)
function ImageLoader.editable(kind: string, name: string, module: Instance?): EditableImage
	local folder = Images:FindFirstChild(kind)
	module = module or (folder and folder:FindFirstChild(name))
	assert(module, "no packed image " .. kind .. "/" .. name)
	local d = require(module)
	local size = Vector2.new(d.W, d.H)
	local image = AssetService:CreateEditableImage({ Size = size })
	if not image then error("out of picture memory (EditableImage budget)") end
	local pixels = decode(d.Data)
	if d.Mask then -- (effect shapes: white, packed as runs of (count, alpha) bytes by tools/icons/pack_images.py)
		local rgba = buffer.create(d.W * d.H * 4)
		local o = 0
		for i = 0, buffer.len(pixels) - 2, 2 do
			local count, a = buffer.readu8(pixels, i), buffer.readu8(pixels, i + 1)
			local px = 0xFFFFFF + a * 0x1000000 -- (little-endian RGBA: R, G, B = 255, then the alpha)
			for _ = 1, count do
				buffer.writeu32(rgba, o, px)
				o += 4
			end
		end
		pixels = rgba
	end
	local ok, err = pcall(function() image:WritePixelsBuffer(Vector2.zero, size, pixels) end)
	if not ok then
		image:Destroy()
		error(err)
	end
	return image
end

-- The EditableImage and the Content a label shows it by (tools/preview/smoke_picture_memory.luau swaps this for a
-- fake with a small budget).
function ImageLoader.make(kind: string, name: string): (any, any)
	local image = ImageLoader.editable(kind, name)
	local ok, content = pcall(function() return (Content :: any).fromObject(image) end)
	if not ok then
		image:Destroy()
		error(content)
	end
	return image, content
end

-- Drawn pictures: [kind/name] = { image, content, seen = when a label last showed it on screen }.
local drawn: { [string]: { image: any, content: any, seen: number } } = {}
-- Pictures that failed: [kind/name] = { at = when it may be tried again, wait = the next wait }.
local failed: { [string]: { at: number, wait: number } } = {}
-- Labels that show a built-in picture: [label] = { kind, name, key, shown }. (A strong table, dropped on Destroying
-- or when the label gets another picture: never a weak table keyed by Instance, root CLAUDE.md.)
local bound: { [ImageLabel]: { kind: string, name: string, key: string, shown: boolean } } = {}
local hooked: { [ImageLabel]: RBXScriptConnection } = {}
local anyDrawn = false -- one picture drew this session: Roblox allows it, so a failure means memory
local blocked = false -- Roblox refused before anything drew (the setting): stand-ins go on at once
local warned: { [string]: boolean } = {}
local evictions: { [string]: number } = {} -- pictures freed to make room for this one since it last drew (at most 8)

local function warnOnce(kind: string, text: string)
	if warned[kind] then return end
	warned[kind] = true
	warn("[HuzzUI] " .. text)
end

local function packed(kind: string, name: string): boolean
	local folder = Images:FindFirstChild(kind)
	return folder ~= nil and folder:FindFirstChild(name) ~= nil
end

-- On screen: its ScreenGui / SurfaceGui is on and in this player's view, every frame up to it is Visible, and a
-- scrolling list it sits in shows it (or nearly: within half the list's height, so the next row is ready).
local function inView(label: GuiObject, box: GuiObject): boolean
	local ls, bs = label.AbsoluteSize, box.AbsoluteSize
	if ls.X <= 0 or ls.Y <= 0 or bs.X <= 0 or bs.Y <= 0 then return true end -- (no layout yet: count it as shown)
	local lp, bp = label.AbsolutePosition, box.AbsolutePosition
	local margin = bs.Y * 0.5
	return lp.X + ls.X >= bp.X and lp.X <= bp.X + bs.X and lp.Y + ls.Y >= bp.Y - margin and lp.Y <= bp.Y + bs.Y + margin
end
-- (memo: one pass's answers for the frames above the labels, which most labels share, so a pass over every label
-- reads each frame once: [frame] = { shown = all of it up to its gui shows, scroll = the nearest scrolling list })
type Chain = { shown: boolean, scroll: GuiObject? }
local function chain(node: Instance?, memo: { [Instance]: Chain }): Chain
	if not node then return { shown = false } end
	local known = memo[node]
	if known then return known end
	local c: Chain
	if node:IsA("GuiObject") then
		if not node.Visible then
			c = { shown = false }
		else
			local up = chain(node.Parent, memo)
			c = { shown = up.shown, scroll = if node:IsA("ScrollingFrame") then node else up.scroll }
		end
	elseif node:IsA("LayerCollector") then
		c = { shown = node.Enabled and not node:IsDescendantOf(StarterGui) }
	else
		c = chain(node.Parent, memo)
	end
	memo[node] = c
	return c
end
local function onScreen(label: Instance, memo: { [Instance]: Chain }?): boolean
	if label:IsA("GuiObject") and not label.Visible then return false end
	local c = chain(label.Parent, memo or {})
	if not c.shown then return false end
	if c.scroll then
		local fine, shown = pcall(inView, label :: GuiObject, c.scroll)
		if fine and not shown then return false end
	end
	return true
end

local function setContent(label: ImageLabel, content: any)
	pcall(function() label.ImageContent = content end)
end
local function clearContent(label: ImageLabel)
	pcall(function() label.ImageContent = (Content :: any).none end)
end

local function unbind(label: ImageLabel)
	bound[label] = nil
	local c = hooked[label]
	if c then
		c:Disconnect()
		hooked[label] = nil
	end
end

local function free(key: string)
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

-- Frees the drawn picture no label on screen shows that was seen the longest ago (room for a new one).
local function freeOldest(): boolean
	local showing = {}
	local memo = {}
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

local knifeView -- (below)

-- Where a picture can't be drawn: a stand-in (a knife card asks for its 3D model too).
local function fallback(label: ImageLabel, b)
	local fine, err = pcall(function()
		-- (a knife card asks for its model first and shows the glyph only if that fails: no kitchen-knife emoji
		-- flashing up while the copy arrives, owner Oct 20 14:07 "fix all of the placeholders for knifes")
		if not knifeView(label, b) then ImageLoader.standIn(label, b.kind, b.name) end
	end)
	if not fine then warnOnce("fallback", "stand-in: " .. tostring(err)) end
end

-- Draws one picture and shows it on every label bound to it; false when it failed.
local function draw(kind: string, name: string, key: string): boolean
	local ok, result = pcall(function()
		local image, content = ImageLoader.make(kind, name)
		return { image = image, content = content }
	end)
	local now = os.clock()
	if ok then
		drawn[key] = { image = result.image, content = result.content, seen = now }
		failed[key], evictions[key] = nil, nil
		anyDrawn, blocked = true, false
		for label, b in bound do
			if b.key == key then
				setContent(label, result.content)
				ImageLoader.clearStandIn(label)
				b.shown = true
			end
		end
		return true
	end
	local why = tostring(result)
	local lower = string.lower(why)
	local memory = anyDrawn or string.find(lower, "memory", 1, true) ~= nil or string.find(lower, "budget", 1, true) ~= nil
	if memory and (evictions[key] or 0) < 8 and freeOldest() then -- (room made: tried again next frame)
		evictions[key] = (evictions[key] or 0) + 1
		return false
	end
	evictions[key] = nil
	local f = failed[key]
	local wait = if f then math.min(f.wait * 2, ImageLoader.RETRY_MAX) else ImageLoader.RETRY
	failed[key] = { at = now + wait, wait = wait }
	if memory then
		warnOnce("memory", "Some pictures can't be drawn right now: this screen's picture memory is full (" .. why .. ")."
			.. " They are tried again as others are freed. Uploading them once avoids this (Plugins > Huzz Valley > Upload Pictures).")
	else
		blocked = true
		warnOnce("blocked", "The icons can't be drawn (" .. why .. "). Fix: Home > Game Settings > Security > turn on"
			.. " 'Allow Mesh / Image APIs', then Save; or upload them once (Plugins > Huzz Valley > Upload Pictures).")
	end
	for label, b in bound do
		if (b.key == key or (blocked and not drawn[b.key])) and not b.shown then fallback(label, b) end
	end
	return false
end

-- The one loop: shows drawn pictures on labels that come on screen, draws the next missing one (one a frame), and
-- frees pictures nobody sees.
local running = false
local lastSweep = 0
-- One pass; true when it drew (or tried) a picture, so the next pass comes next frame.
-- A pass over every label (5 a second): shows drawn pictures on labels that came on screen, lists the missing ones
-- on screen (drawn after it, one a frame, without passing over every label again), frees what nobody sees.
local pending: { { label: ImageLabel, b: any } } = {}
local function scan()
	local now = os.clock()
	local seen: { [string]: boolean } = {}
	local held: { [string]: boolean } = {}
	local listed: { [string]: boolean } = {}
	local dead = {}
	local memo = {}
	table.clear(pending)
	for label, b in bound do
		local fine, visible = pcall(onScreen, label, memo)
		if not fine then table.insert(dead, label) end -- (a label destroyed without its Destroying: let it go)
		if fine then held[b.key] = true end
		if fine and visible then
			seen[b.key] = true
			local e = drawn[b.key]
			if e then
				e.seen = now
				if not b.shown then
					setContent(label, e.content)
					ImageLoader.clearStandIn(label)
					b.shown = true
				end
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
-- Draws the next listed picture whose label is still bound to it and on screen; true when it tried one.
local function drawNext(): boolean
	while #pending > 0 do
		local job = table.remove(pending, 1)
		local b = job.b
		if bound[job.label] == b and not drawn[b.key] and onScreen(job.label) then
			-- (pcall: one picture that fails must not stop the loop, or every picture after it stays blank)
			local fine, done = pcall(draw, b.kind, b.name, b.key)
			if fine and not done and not failed[b.key] then table.insert(pending, 1, job) end -- (room was made: again)
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
			if blocked then table.clear(pending) end -- (nothing can draw: tried again at the slow pace)
			if #pending > 0 then
				local fine, tried = pcall(drawNext)
				if not fine then warnOnce("loop", "picture loop: " .. tostring(tried)) end
				busy = fine and tried
			end
			if not busy and os.clock() - lastScan >= 0.2 then
				lastScan = os.clock()
				local fine, err = pcall(scan)
				if not fine then warnOnce("loop", "picture loop: " .. tostring(err)) end
				busy = #pending > 0 and not blocked
			end
			task.wait(if busy then nil else 0.2)
		end
		running = false
	end)
end

-- Points an ImageLabel at the image: the uploaded ID if there is one, otherwise the built-in pixels (drawn when the
-- label is on screen).
function ImageLoader.apply(label: ImageLabel, kind: string, name: string, uploadedId: string)
	if uploadedId ~= "" then
		unbind(label)
		label.Image = uploadedId
		ImageLoader.clearStandIn(label)
		return
	end
	if not packed(kind, name) then
		unbind(label)
		ImageLoader.standIn(label, kind, name)
		return
	end
	local key = kind .. "/" .. name
	local old = bound[label]
	if old and old.key ~= key and old.shown then clearContent(label) end -- (Kit.setArt: not the old picture meanwhile)
	local b = { kind = kind, name = name, key = key, shown = false }
	bound[label] = b
	if not hooked[label] then
		hooked[label] = label.Destroying:Connect(function() unbind(label) end)
	end
	local e = drawn[key]
	if e then
		setContent(label, e.content)
		ImageLoader.clearStandIn(label)
		b.shown = true
	elseif blocked or failed[key] then
		fallback(label, b)
	end
	if not running then loop() end
end

-- For the checks: whether this label shows its drawn picture now, whether it's on screen, and how many are drawn.
function ImageLoader.showing(label: ImageLabel): boolean
	local b = bound[label]
	return b ~= nil and b.shown and drawn[b.key] ~= nil
end
ImageLoader.onScreen = onScreen
function ImageLoader.drawnCount(): number
	local n = 0
	for _ in drawn do n += 1 end
	return n
end

-- Returns a Content for the packed image (kind = "Icons" or "Art") if it's drawn now, else nil. (Kept for callers
-- that ask directly; labels should use apply, which draws only what's on screen.)
function ImageLoader.content(kind: string, name: string): any
	local e = drawn[kind .. "/" .. name]
	return e and e.content or nil
end

-- Stand-in glyphs for pictures that can't be drawn (see the header). Icons by name; art by its name's start.
-- Decorations (rays, wedges, studs, glows) have none: without them the screen still reads. Only emoji Roblox's font
-- has: the coin emoji (U+1FA99) and the mouse trap (U+1FAA4) are too new and drew as an empty box (owner, Oct 20
-- 14:07, the 2,000 and 5,000 coin packs), so coins are a money bag.
local GLYPH: { [string]: string } = {
	AudioMusic = "🎵", AudioSpeaker = "🔊", AudioWaveform = "🎶", AuraStar = "✨", AuraStarWhite = "✨", ChatBenefit = "💬",
	CheckEquipped = "✅", CheckOwned = "✔", Close = "✖", CollectionBook = "📖", CompanionEffects = "✨", ControlsDash = "💨",
	ControlsKeyboard = "⌨", ControlsMenu = "☰", CurrencyCoin = "💰", CurrencyGem = "💎", CurrencyPlus = "➕", DancesNote = "🎵",
	Envelope = "✉", FavouriteFilled = "⭐", FavouriteOutline = "☆", GiftAction = "🎁", GiftBenefit = "🎁",
	InventoryVisibility = "👁", Lock = "🔒", MainMenuLines = "☰", Map = "🗺", Monitor = "🖥", MusicBenefit = "🎵",
	Play = "▶", Players = "👥", QuestsClipboard = "📋", RewardsTrophy = "🏆", Search = "🔍", SettingsGear = "⚙",
	ShirtBenefit = "👕", ShirtEquip = "👕", ShopCart = "🛒", Sneaker = "👟", SpinWheel = "🎡", Stop = "⏹",
	Stopwatch = "⏱", TagFist = "✊", TierCrown = "👑", VipCrown = "👑", XpBadge = "⭐", ArrowNext = "▶",
	AbilityShield = "🛡", AbilitySpeedBoost = "⚡", AbilityBearTrap = "🐻", AbilitySlowWave = "🌀", AbilityInvisible = "👻",
	AbilityGlitchy = "📺", AbilityBodyDouble = "👥",
}
local ART_GLYPH = { -- (first match wins)
	{ "Knife", "🔪" }, { "DanceStill", "💃" }, { "Dance", "💃" }, { "CoinPack", "💰" }, { "RewardCoins", "💰" },
	{ "RewardGems", "💎" }, { "Map", "🗺" }, { "HowToPlay", "❓" }, { "Pass", "🎟" }, { "Char", "👧" }, { "Bonus", "🎁" },
	{ "CrateCard", "📦" }, { "TierCrown", "👑" }, { "Vip", "👑" }, { "CrownPose", "👑" }, { "Outfit", "👗" }, { "MidnightOutfit", "👗" },
	{ "ItemMint", "💫" }, { "Item", "💫" }, { "SunsetTrail", "💫" }, { "BlossomAura", "🌸" },
}
local DECOR = { LightRays = true, SpinWedge = true, DanceFxCore = true, DanceFxGlow = true, StudPattern = true, StudTile = true, BoardStud = true, BoardWeb = true }

function ImageLoader.glyph(kind: string, name: string): string?
	if DECOR[name] then return nil end
	if kind == "Icons" then return GLYPH[name] end
	for _, g in ART_GLYPH do
		if string.sub(name, 1, #g[1]) == g[1] then return g[2] end
	end
	return nil
end

function ImageLoader.standIn(label: ImageLabel, kind: string, name: string)
	if label:FindFirstChild("NoPicture") then return end
	local glyph = ImageLoader.glyph(kind, name)
	if not glyph then return end
	local t = Instance.new("TextLabel")
	t.Name = "NoPicture"
	t:SetAttribute("NoPicture", true)
	t.BackgroundTransparency = 1
	t.AnchorPoint = Vector2.new(0.5, 0.5)
	t.Position = UDim2.fromScale(0.5, 0.5)
	t.Size = UDim2.fromScale(0.8, 0.8)
	t.Text = glyph
	t.TextScaled = true
	t.TextColor3 = Color3.new(1, 1, 1)
	t.ZIndex = label.ZIndex
	local ratio = Instance.new("UIAspectRatioConstraint") -- (square, so a wide picture's glyph stays a glyph)
	ratio.Parent = t
	t.Parent = label
end

function ImageLoader.clearStandIn(label: ImageLabel)
	local t = label:FindFirstChild("NoPicture")
	if t then t:Destroy() end
end

-- A knife card that can't be drawn shows the knife itself: a copy of its model (his own from ServerStorage/HuzzKnives,
-- else its stand-in), which only the server can reach, so remote KnifeView puts one in this player's PlayerGui
-- (HuzzServer/KnifeGlbService). Laid diagonal like the card pictures (tip up and right, flat side to us), in a
-- ViewportFrame named NoPicture (so it goes the moment the real picture draws, and is never saved).
local CoinShop
local views: { [string]: Instance | boolean } = {} -- [knife key] = the model PlayerGui holds, or true while asking
local function itemFor(name: string)
	if string.sub(name, 1, 5) ~= "Knife" then return nil end
	if not CoinShop then
		local ok, m = pcall(require, Shared:WaitForChild("Config"):WaitForChild("CoinShop"))
		if not ok then return nil end
		CoinShop = m
	end
	for _, item in CoinShop.Items do
		if item.Art == name and item.Slot == "Knife" then return item end
	end
	return nil
end

local function showView(label: ImageLabel, model: Instance)
	local copy = model:Clone()
	local handle = copy:FindFirstChild("Handle", true)
	if not (handle and handle:IsA("BasePart")) then copy:Destroy() return end
	-- the Handle's +Y (to the tip) up and to the right at 35 degrees, its thin X toward the camera
	local want = CFrame.Angles(0, 0, math.rad(-55)) * CFrame.Angles(0, math.rad(90), 0)
	copy:PivotTo(want * handle.CFrame:Inverse() * copy:GetPivot())
	local centre, size = copy:GetBoundingBox()
	local length = math.max(size.X, size.Y, size.Z)
	local vf = Instance.new("ViewportFrame")
	vf.Name = "NoPicture"
	vf:SetAttribute("NoPicture", true)
	vf.BackgroundTransparency = 1
	vf.Size = UDim2.fromScale(1, 1)
	vf.ZIndex = label.ZIndex
	vf.Ambient = Color3.fromRGB(170, 170, 180)
	vf.LightColor = Color3.new(1, 1, 1)
	vf.LightDirection = Vector3.new(-0.4, -1, -0.6)
	local cam = Instance.new("Camera")
	cam.FieldOfView = 30
	cam.CFrame = CFrame.lookAt(centre.Position + Vector3.new(0, 0, length * 1.45), centre.Position)
	cam.Parent = vf
	vf.CurrentCamera = cam
	copy.Parent = vf
	ImageLoader.clearStandIn(label)
	vf.Parent = label
end

function knifeView(label: ImageLabel, b): boolean
	if b.kind ~= "Art" then return false end
	if b.viewing then return true end
	local item = itemFor(b.name)
	if not item then return false end
	b.viewing = true
	task.spawn(function()
		pcall(function()
			local key = item.Key
			local model = views[key]
			if not model then
				views[key] = true
				-- (pcall: if asking fails, the "asking" mark must go, or every card waiting below loops forever)
				local fine, got = pcall(function()
					local Net = require(Shared:WaitForChild("Net"))
					local ok = (Net.get("KnifeView") :: RemoteFunction):InvokeServer(key)
					local player = Players.LocalPlayer
					local folder = ok and player and player:WaitForChild("PlayerGui"):WaitForChild("HuzzKnifeViews", 5)
					return folder and folder:WaitForChild(key, 5)
				end)
				if not fine then warnOnce("knifeview", "knife card model: " .. tostring(got)) end
				got = if fine then got else nil
				views[key] = got or nil
				model = got
			end
			while model == true do -- (another card is asking for the same knife)
				task.wait(0.2)
				model = views[key]
			end
			if typeof(model) == "Instance" and bound[label] == b and not b.shown then showView(label, model) end
		end)
		if bound[label] == b and not b.shown and not label:FindFirstChild("NoPicture") then ImageLoader.standIn(label, b.kind, b.name) end
		b.viewing = false
	end)
	return true
end

return ImageLoader
