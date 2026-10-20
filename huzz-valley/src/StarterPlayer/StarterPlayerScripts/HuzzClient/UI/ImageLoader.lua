-- Draws the kit's icons and pictures in-game from the pixel data packed into Shared/Images (EditableImage), so they
-- show without the owner uploading them. If an image has an uploaded ID in Config/Assets, that ID is used instead.
-- Each image is decoded once and shared by every ImageLabel that shows it.
-- Why pictures can be missing (owner, Oct 19: "make the pictures in all of the ui appear"): Config/ImageIds is empty
-- until he runs Upload Pictures once, so every picture is drawn here with EditableImage, which Roblox only allows when
-- Game Settings > Security > "Allow Mesh / Image APIs" is on (and the place is published). With it off nothing can
-- be drawn. Then each picture gets a stand-in glyph instead of staying blank (a coin for coins, a knife for knife
-- pictures..., GLYPH below; decorations like rays get none), and Output gets one [HuzzUI] line with the one fix
-- (docs/STUDIO-STEPS.md Part 1); never a box on screen (owner, Oct 19: "please remove the red pop up"). The glyphs
-- carry the NoPicture attribute: never saved into StarterGui, never drawn by the offline preview, and removed as soon
-- as the real picture shows.
local AssetService = game:GetService("AssetService")
local Images = game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Images")

local ImageLoader = {}

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

-- A new EditableImage holding the packed pixels (kind = "Icons" or "Art"). Errors if it can't be made here.
-- (Also used by tools/studio/upload-images.lua to upload each image once; it passes `module` for the effect
-- textures, which live in ServerStorage > HuzzImages > Fx.)
function ImageLoader.editable(kind: string, name: string, module: Instance?): EditableImage
	local folder = Images:FindFirstChild(kind)
	module = module or (folder and folder:FindFirstChild(name))
	assert(module, "no packed image " .. kind .. "/" .. name)
	local d = require(module)
	local size = Vector2.new(d.W, d.H)
	local image = AssetService:CreateEditableImage({ Size = size })
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
	image:WritePixelsBuffer(Vector2.zero, size, pixels)
	return image
end

local cache: { [string]: any } = {}
local warned = false

-- Returns a Content for the packed image (kind = "Icons" or "Art"), or nil if it can't be drawn here.
function ImageLoader.content(kind: string, name: string): any
	local key = kind .. "/" .. name
	if cache[key] ~= nil then return cache[key] or nil end
	local folder = Images:FindFirstChild(kind)
	local module = folder and folder:FindFirstChild(name)
	if not module then
		cache[key] = false
		return nil
	end
	local ok, result = pcall(function() return Content.fromObject(ImageLoader.editable(kind, name)) end)
	if not ok and not warned then
		warned = true
		warn("[HuzzUI] The icons can't be drawn (" .. tostring(result) .. "). Fix: Home > Game Settings > Security > turn on"
			.. " 'Allow Mesh / Image APIs', then Save; or upload them once (Plugins > Huzz Valley > Upload Pictures).")
	end
	cache[key] = ok and result or false
	return ok and result or nil
end

-- Big pictures not drawn yet wait in a queue and are drawn one per frame (critic: opening the shop drew 29 knife
-- pictures of 192 px in one frame, a stutter on phones).
local queue: { { label: ImageLabel, kind: string, name: string } } = {}
local pumping = false
local function pump()
	pumping = true
	task.spawn(function()
		while #queue > 0 do
			local job = table.remove(queue, 1)
			-- (guarded: one picture that fails must not stop the queue, or every knife picture after it stays blank)
			pcall(function()
				if job.label.Parent then
					local content = ImageLoader.content(job.kind, job.name)
					if content then
						job.label.ImageContent = content
						ImageLoader.clearStandIn(job.label)
					else
						ImageLoader.standIn(job.label, job.kind, job.name)
					end
				end
			end)
			task.wait()
		end
		pumping = false
	end)
end

-- Points an ImageLabel at the image: the uploaded ID if there is one, otherwise the built-in pixels.
function ImageLoader.apply(label: ImageLabel, kind: string, name: string, uploadedId: string)
	if uploadedId ~= "" then
		label.Image = uploadedId
		ImageLoader.clearStandIn(label)
		return
	end
	if kind == "Art" and cache[kind .. "/" .. name] == nil and string.sub(name, 1, 5) == "Knife" then
		table.insert(queue, { label = label, kind = kind, name = name })
		if not pumping then pump() end
		return
	end
	local content = ImageLoader.content(kind, name)
	if content then
		label.ImageContent = content
		ImageLoader.clearStandIn(label)
	else
		ImageLoader.standIn(label, kind, name)
	end
end

-- Stand-in glyphs for pictures that can't be drawn (see the header). Icons by name; art by its name's start.
-- Decorations (rays, wedges, studs, glows) have none: without them the screen still reads.
local GLYPH: { [string]: string } = {
	AudioMusic = "🎵", AudioSpeaker = "🔊", AudioWaveform = "🎶", AuraStar = "✨", AuraStarWhite = "✨", ChatBenefit = "💬",
	CheckEquipped = "✅", CheckOwned = "✔", Close = "✖", CollectionBook = "📖", CompanionEffects = "✨", ControlsDash = "💨",
	ControlsKeyboard = "⌨", ControlsMenu = "☰", CurrencyCoin = "🪙", CurrencyGem = "💎", CurrencyPlus = "➕", DancesNote = "🎵",
	Envelope = "✉", FavouriteFilled = "⭐", FavouriteOutline = "☆", GiftAction = "🎁", GiftBenefit = "🎁",
	InventoryVisibility = "👁", Lock = "🔒", MainMenuLines = "☰", Map = "🗺", Monitor = "🖥", MusicBenefit = "🎵",
	Play = "▶", Players = "👥", QuestsClipboard = "📋", RewardsTrophy = "🏆", Search = "🔍", SettingsGear = "⚙",
	ShirtBenefit = "👕", ShirtEquip = "👕", ShopCart = "🛒", Sneaker = "👟", SpinWheel = "🎡", Stop = "⏹",
	Stopwatch = "⏱", TagFist = "✊", TierCrown = "👑", VipCrown = "👑", XpBadge = "⭐", ArrowNext = "▶",
	AbilityShield = "🛡", AbilitySpeedBoost = "⚡", AbilityBearTrap = "🪤", AbilitySlowWave = "🌀", AbilityInvisible = "👻",
	AbilityGlitchy = "📺", AbilityBodyDouble = "👥",
}
local ART_GLYPH = { -- (first match wins)
	{ "Knife", "🔪" }, { "DanceStill", "💃" }, { "Dance", "💃" }, { "CoinPack", "🪙" }, { "RewardCoins", "🪙" },
	{ "RewardGems", "💎" }, { "Map", "🗺" }, { "HowToPlay", "❓" }, { "Pass", "🎟" }, { "Char", "👧" }, { "Bonus", "🎁" },
	{ "TierCrown", "👑" }, { "Vip", "👑" }, { "CrownPose", "👑" }, { "Outfit", "👗" }, { "MidnightOutfit", "👗" },
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

return ImageLoader
