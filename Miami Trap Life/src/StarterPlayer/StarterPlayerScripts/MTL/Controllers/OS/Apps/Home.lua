--!strict
-- Liberty OS "Home": order the flat's upgrades (Config/OS.Home tiers). Four cards left to right, as-found to the
-- full setup; the one you can buy next is lit. The room re-dresses when you get up from the desk.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Format = require(ReplicatedStorage.MTL.Format)

local App = {}

function App.mount(root: Frame, api: any): any
	local L = api.look
	local ui = api.ui
	local new, text, button, corner, stroke = ui.new, ui.text, ui.button, ui.corner, ui.stroke
	local alive = true

	local pad = new("Frame", { Parent = root, Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 }, {
		new("UIPadding", { PaddingLeft = UDim.new(0, 32), PaddingRight = UDim.new(0, 32), PaddingTop = UDim.new(0, 26), PaddingBottom = UDim.new(0, 26) }),
	})
	text(pad, "FLAT 3B", { font = L.Head, size = 34, sizeU = UDim2.new(1, 0, 0, 40) })
	local sub = text(pad, "Royce Properties · improvements are installed when you get up from the desk", { size = 14, color = L.Dim, pos = UDim2.fromOffset(0, 42), sizeU = UDim2.new(1, 0, 0, 18) })
	local cards = new("Frame", { Parent = pad, Position = UDim2.fromOffset(0, 84), Size = UDim2.new(1, 0, 1, -84), BackgroundTransparency = 1 }, {
		new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 14), SortOrder = Enum.SortOrder.LayoutOrder }),
	})

	local draw: (any) -> ()
	local function buy(tier: number)
		local res = api.request("buy", { tier = tier })
		if res and res.ok then
			api.notify("Ordered: " .. res.tiers[tier + 1].title .. ". Get up to see it.", L.Money)
			sub.Text = "Order placed. Stand up from the desk and the crew does the rest."
			sub.TextColor3 = L.Gold
			draw(res)
		else
			api.notify(res and res.err or "Failed", L.Loss)
		end
	end

	draw = function(s: any)
		for _, ch in cards:GetChildren() do
			if ch:IsA("GuiObject") then
				ch:Destroy()
			end
		end
		for i, t in s.tiers do
			local current = t.tier == s.tier
			local nextUp = t.tier == s.tier + 1
			local c = new("Frame", {
				Parent = cards,
				Name = "Tier" .. t.tier,
				Size = UDim2.new(0.25, -11, 1, 0),
				BackgroundColor3 = if nextUp then L.Panel2 else L.Panel,
				BorderSizePixel = 0,
				LayoutOrder = i,
			}, { corner(), stroke(if current or nextUp then 0.4 else nil, if current then L.Select elseif nextUp then L.Gold else nil) })
			new("UIPadding", { Parent = c, PaddingLeft = UDim.new(0, 18), PaddingRight = UDim.new(0, 18), PaddingTop = UDim.new(0, 18) })
			text(c, "TIER " .. t.tier, { font = L.Bold, size = 12, color = if current then L.Select else L.Dim, sizeU = UDim2.new(1, 0, 0, 16) })
			text(c, t.title, { font = L.Head, size = 26, pos = UDim2.fromOffset(0, 20), sizeU = UDim2.new(1, 0, 0, 32) })
			text(c, if t.price > 0 then Format.cash(t.price) else "Free", { font = L.Head, size = 22, color = L.Money, pos = UDim2.fromOffset(0, 56), sizeU = UDim2.new(1, 0, 0, 26) })
			text(c, "Level " .. t.level, { font = L.Bold, size = 13, color = L.Gold, pos = UDim2.fromOffset(0, 84), sizeU = UDim2.new(1, 0, 0, 16) })
			local y = 116
			for _, line in t.lines do
				local l = text(c, "·  " .. line, { size = 14, pos = UDim2.fromOffset(0, y), sizeU = UDim2.new(1, 0, 0, 40), wrap = true, valign = Enum.TextYAlignment.Top })
				l.TextColor3 = if t.owned then L.Dim else L.Text
				y += 46
			end
			local foot = new("Frame", { Parent = c, AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 0, 1, -18), Size = UDim2.new(1, 0, 0, 40), BackgroundTransparency = 1 })
			if current then
				text(foot, "YOU ARE HERE", { font = L.Bold, size = 14, color = L.Select, align = Enum.TextXAlignment.Center, sizeU = UDim2.fromScale(1, 1) })
			elseif t.owned then
				text(foot, "DONE", { font = L.Bold, size = 14, color = L.Dim, align = Enum.TextXAlignment.Center, sizeU = UDim2.fromScale(1, 1) })
			elseif t.can then
				button(foot, "ORDER", function()
					buy(t.tier)
				end, { sizeU = UDim2.fromScale(1, 1), color = Color3.fromRGB(46, 120, 60), size = 16 })
			else
				text(foot, t.why or "Locked", { font = L.Bold, size = 14, color = L.Dim, align = Enum.TextXAlignment.Center, sizeU = UDim2.fromScale(1, 1) })
			end
			c.BackgroundTransparency = 1
			TweenService:Create(c, TweenInfo.new(0.25 + i * 0.05, Enum.EasingStyle.Quad), { BackgroundTransparency = 0 }):Play()
		end
	end

	task.spawn(function()
		local res = api.request("state")
		if alive and res and res.ok then
			draw(res)
		elseif alive then
			sub.Text = res and res.err or "Can't load"
		end
	end)

	return {
		unmount = function()
			alive = false
		end,
	}
end

return App
