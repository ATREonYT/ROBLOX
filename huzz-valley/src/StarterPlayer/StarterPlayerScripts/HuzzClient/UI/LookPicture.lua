-- A trail's or an aura's picture with YOUR avatar in it (owner, Oct 26 10:47: "for the trails and effects please remove
-- the placeholders and make it actual user characters"). The old pictures (assets/art/item-*-trail.png and the like)
-- were drawn with a stand-in figure (a white-haired boy, a blocky dummy); now a copy of your own character stands in
-- the card (UI/DancePose.avatar) with the effect drawn behind it in the item's colours (Config/CoinShop Colors):
--   Trail  two soft streaks sweeping in from the left to you, fading out behind, with a few bright dots along them;
--   Aura   a soft glow round you (rings fading outward), a ring at your feet and a gentle breathe.
-- Roblox draws no trails or particles inside a ViewportFrame, so the effect is drawn in the card, under the avatar.
-- No flashing; the breathe is slow. Used by the Shop's cards and the Inventory.
--   LookPicture.is(item)                         a trail or an aura
--   LookPicture.draw(parent, item, props, dark?) -> Frame "Look" (props: Position, Size, AnchorPoint, ZIndex)
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local CoinShop = require(Shared.Config.CoinShop)
local UI = script.Parent
local Kit = require(UI.Kit)
local Effects = require(UI.Effects)
local DancePose = require(UI.DancePose)

local new = Kit.new
local WHITE = Color3.new(1, 1, 1)
local LOCKED = Color3.fromHex("2A3550")

local LookPicture = {}

function LookPicture.is(item: any): boolean
	return item ~= nil and (item.Slot == "Trail" or item.Slot == "Aura")
end

local function round(f: GuiObject)
	new("UICorner", { CornerRadius = UDim.new(0.5, 0), Parent = f })
end

function LookPicture.draw(parent: Instance, item: any, props: { [string]: any }, dark: boolean?): Frame
	local z = props.ZIndex or 2
	local box = new("Frame", { Name = "Look", BackgroundTransparency = 1, ClipsDescendants = false, Parent = parent })
	for k, v in props do (box :: any)[k] = v end
	local colours = item.Colors or { WHITE }
	local seq = if dark then ColorSequence.new(LOCKED) else CoinShop.sequence(item)
	local main = if dark then LOCKED else colours[math.min(2, #colours)]
	local size = box.Size
	local w, h = size.X.Offset, size.Y.Offset
	local side = math.min(w, h) -- (the avatar's square)
	if item.Slot == "Trail" then
		-- the avatar a little right of the middle; the streaks come in from the left edge to its middle
		local ax = math.round(w * 0.58)
		for i, s in { { y = 0.56, t = 22, a = 0.25 }, { y = 0.7, t = 12, a = 0.05 } } do
			local len = ax - 4
			local streak = new("Frame", { Name = "Streak" .. i, AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.fromOffset(4, math.round(h * s.y)), Size = UDim2.fromOffset(len, s.t), Rotation = -8, BackgroundColor3 = WHITE, BorderSizePixel = 0, ZIndex = z, Parent = box })
			round(streak)
			new("UIGradient", { Name = "Colours", Color = seq, Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.55, 0.45 + s.a), NumberSequenceKeypoint.new(1, s.a) }), Parent = streak })
		end
		if not dark then
			for i, d in { { 0.18, 0.5, 5 }, { 0.32, 0.78, 4 }, { 0.44, 0.47, 6 }, { 0.26, 0.64, 3 } } do
				local dot = new("Frame", { Name = "Dot" .. i, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(math.round(w * d[1]), math.round(h * d[2])), Size = UDim2.fromOffset(d[3], d[3]), BackgroundColor3 = colours[1]:Lerp(WHITE, 0.6), BorderSizePixel = 0, ZIndex = z, Parent = box })
				round(dot)
			end
		end
		DancePose.avatar(box, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(ax, h // 2), Size = UDim2.fromOffset(side, side), ZIndex = z + 1 }, dark)
	else
		-- the glow: rings fading outward round the avatar, a ring at its feet
		local glow = new("Frame", { Name = "Glow", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(w // 2, h // 2), Size = UDim2.fromOffset(side, side), BackgroundTransparency = 1, ZIndex = z, Parent = box })
		for i, r in { { 1, 0.86 }, { 0.8, 0.74 }, { 0.6, 0.62 } } do
			local d = math.round(side * r[1])
			local disc = new("Frame", { Name = "Disc" .. i, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(d, d), BackgroundColor3 = main, BackgroundTransparency = if dark then 0.8 else r[2], BorderSizePixel = 0, ZIndex = z, Parent = glow })
			round(disc)
		end
		local ring = new("Frame", { Name = "Ring", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(math.round(side * 0.9), math.round(side * 0.9)), BackgroundTransparency = 1, ZIndex = z, Parent = glow })
		round(ring)
		new("UIStroke", { Name = "Rim", Color = WHITE, Thickness = 3, Transparency = 0.2, Parent = ring }, { new("UIGradient", { Name = "Colours", Rotation = 45, Color = seq }) })
		local feet = new("Frame", { Name = "Feet", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(w // 2, math.round(h * 0.5 + side * 0.4)), Size = UDim2.fromOffset(math.round(side * 0.62), math.max(6, math.round(side * 0.12))), BackgroundTransparency = 1, ZIndex = z, Parent = box })
		round(feet)
		new("UIStroke", { Name = "Rim", Color = main, Thickness = 2, Transparency = 0.15, Parent = feet })
		if not dark then pcall(Effects.breathe, glow, { scale = 1.04, seconds = 2.4 }) end
		DancePose.avatar(box, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(w // 2, h // 2), Size = UDim2.fromOffset(side, side), ZIndex = z + 1 }, dark)
	end
	return box
end

return LookPicture
