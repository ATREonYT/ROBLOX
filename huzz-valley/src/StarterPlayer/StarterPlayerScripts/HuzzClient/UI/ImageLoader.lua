-- Draws the kit's icons and pictures in-game from the pixel data packed into Shared/Images (EditableImage), so they
-- show without the owner uploading them. If an image has an uploaded ID in Config/Assets, that ID is used instead.
-- Each image is decoded once and shared by every ImageLabel that shows it.
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
	local ok, result = pcall(function()
		local d = require(module)
		local size = Vector2.new(d.W, d.H)
		local image = AssetService:CreateEditableImage({ Size = size })
		image:WritePixelsBuffer(Vector2.zero, size, decode(d.Data))
		return Content.fromObject(image)
	end)
	if not ok and not warned then
		warned = true
		warn("[HuzzUI] built-in images can't be drawn on this device (" .. tostring(result) .. "); upload them to show them")
	end
	cache[key] = ok and result or false
	return ok and result or nil
end

-- Points an ImageLabel at the image: the uploaded ID if there is one, otherwise the built-in pixels.
function ImageLoader.apply(label: ImageLabel, kind: string, name: string, uploadedId: string)
	if uploadedId ~= "" then
		label.Image = uploadedId
		return
	end
	local content = ImageLoader.content(kind, name)
	if content then label.ImageContent = content end
end

return ImageLoader
