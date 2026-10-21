-- Gold on every coin counter (owner, Oct 21: "for the coins add some gold animations"). CoinFx.attach(pill) takes a
-- Kit.pill with the coin icon and returns set(n): it shows n with commas, and when n goes up the coin pops, a few
-- gold sparks burst from it, a gold "+N" floats up and the number glows gold and settles back to white (one soft
-- glow per gain, never a flash: kid-safe). The pill also catches a slow shine every 6 s. The sparks and the "+N" are
-- made at run time and destroyed after (never saved into StarterGui). Reduced Motion: just the number.
local TweenService = game:GetService("TweenService")
local UI = script.Parent
local Kit = require(UI.Kit)
local Motion = require(UI.Motion)
local Effects = require(UI.Effects)
local Format = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Format"))

local CoinFx = {}

local GOLD = Color3.fromHex("FFC93C")
local LIGHT = Color3.fromHex("FFE27A")
local WHITE = Color3.new(1, 1, 1)
local SPARKS = 6

local function tween(inst: Instance, t: number, props: { [string]: any }, style: Enum.EasingStyle?)
	local tw = TweenService:Create(inst, TweenInfo.new(t, style or Enum.EasingStyle.Quad, Enum.EasingDirection.Out), props)
	tw:Play()
	return tw
end

function CoinFx.attach(pill: { Instance: Frame, setAmount: (string) -> () }): (number) -> ()
	local f = pill.Instance
	local icon = f:FindFirstChild("Icon") :: GuiObject?
	local amount = f:FindFirstChild("Amount") :: TextLabel?
	Effects.shine(f, { every = 6, corner = 6, strength = 0.25, z = (f.ZIndex or 1) + 3 })
	local last: number? = nil
	local busy = 0
	return function(n: number)
		pill.setAmount(Format.commas(n))
		local gained = if last then n - last else 0
		last = n
		if gained <= 0 or Motion.reduced or not icon or busy > 2 then return end
		busy += 1
		local ok = pcall(function()
			Motion.pop(icon)
			if amount then
				amount.TextColor3 = GOLD
				tween(amount, 0.8, { TextColor3 = WHITE }, Enum.EasingStyle.Sine)
			end
			local cx = icon.Position.X.Offset + math.floor(icon.Size.X.Offset / 2)
			local cy = math.floor(f.Size.Y.Offset / 2)
			-- the sparks: small gold diamonds flying out from the coin and fading
			for i = 1, SPARKS do
				local a = (i - 1) / SPARKS * math.pi * 2 + 0.4
				local s = Kit.new("Frame", { Name = "CoinSpark", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(cx, cy),
					Size = UDim2.fromOffset(5, 5), Rotation = 45, BackgroundColor3 = if i % 2 == 0 then GOLD else LIGHT, BorderSizePixel = 0,
					ZIndex = (icon.ZIndex or 1) + 2, Parent = f })
				local d = 16 + (i % 3) * 4
				tween(s, 0.55, { Position = UDim2.fromOffset(cx + math.floor(math.cos(a) * d), cy + math.floor(math.sin(a) * d)), BackgroundTransparency = 1, Rotation = 225 })
				task.delay(0.6, function() s:Destroy() end)
			end
			-- the "+N" floating up over the pill
			local plus = Kit.text({ Name = "CoinGain", Text = "+" .. Format.commas(gained), FontFace = Font.new("rbxasset://fonts/families/FredokaOne.json"),
				TextSize = 18, TextColor3 = GOLD, TextXAlignment = Enum.TextXAlignment.Center, TextWrapped = false,
				AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 0, -2), Size = UDim2.fromOffset(120, 22), ZIndex = (f.ZIndex or 1) + 5, Parent = f })
			Kit.new("UIStroke", { Name = "Outline", Color = Color3.fromHex("3A2400"), Thickness = 2, LineJoinMode = Enum.LineJoinMode.Round, Parent = plus })
			tween(plus, 0.9, { Position = UDim2.new(0.5, 0, 0, -26), TextTransparency = 1 }, Enum.EasingStyle.Sine)
			local o = plus:FindFirstChild("Outline")
			if o then tween(o, 0.9, { Transparency = 1 }, Enum.EasingStyle.Sine) end
			task.delay(0.95, function() plus:Destroy() end)
		end)
		task.delay(0.9, function() busy -= 1 end)
		if not ok then busy = math.max(0, busy) end
	end
end

return CoinFx
