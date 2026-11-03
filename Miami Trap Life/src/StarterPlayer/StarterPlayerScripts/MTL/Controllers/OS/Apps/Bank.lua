--!strict
-- Liberty OS "Bank": cash on you vs. money in the account, move between them, and a statement of the last
-- money moves (where your money is coming from). Server half: Services/BankService.
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
		new("UIPadding", { PaddingLeft = UDim.new(0, 32), PaddingRight = UDim.new(0, 32), PaddingTop = UDim.new(0, 28), PaddingBottom = UDim.new(0, 24) }),
	})

	local function card(x: number, label: string): TextLabel
		local c = new("Frame", { Parent = pad, Position = UDim2.new(x, if x > 0 then 8 else 0, 0, 0), Size = UDim2.new(0.5, -8, 0, 120), BackgroundColor3 = L.Panel2, BorderSizePixel = 0 }, { corner(), stroke() })
		text(c, label, { size = 13, color = L.Dim, pos = UDim2.fromOffset(20, 16), sizeU = UDim2.new(1, -40, 0, 16) })
		return text(c, "-", { name = "Value", font = L.Head, size = 48, color = L.Money, pos = UDim2.fromOffset(20, 40), sizeU = UDim2.new(1, -40, 0, 56) })
	end
	local cashV = card(0, "CASH ON YOU")
	local bankV = card(0.5, "LIBERTY SAVINGS")

	local row = new("Frame", { Parent = pad, Position = UDim2.fromOffset(0, 140), Size = UDim2.new(1, 0, 0, 44), BackgroundTransparency = 1 })
	local box = new("TextBox", {
		Parent = row,
		Name = "Amount",
		Size = UDim2.new(0.4, 0, 1, 0),
		BackgroundColor3 = L.Panel2,
		Text = "",
		PlaceholderText = "$ amount",
		Font = L.Head,
		TextSize = 22,
		TextColor3 = L.Text,
		TextXAlignment = Enum.TextXAlignment.Left,
		ClearTextOnFocus = false,
		BorderSizePixel = 0,
	}, { corner(), stroke(), new("UIPadding", { PaddingLeft = UDim.new(0, 12) }) })
	local msg = text(pad, "", { name = "Msg", size = 13, color = L.Gold, pos = UDim2.fromOffset(0, 190), sizeU = UDim2.new(1, 0, 0, 18) })

	local today = text(pad, "", { name = "Today", font = L.Bold, size = 14, pos = UDim2.fromOffset(0, 220), sizeU = UDim2.new(1, 0, 0, 20), rich = true })
	text(pad, "STATEMENT", { font = L.Head, size = 18, pos = UDim2.fromOffset(0, 252), sizeU = UDim2.new(1, 0, 0, 22) })
	local list = new("ScrollingFrame", {
		Parent = pad,
		Name = "Statement",
		Position = UDim2.fromOffset(0, 280),
		Size = UDim2.new(1, 0, 1, -280),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 3,
		ScrollBarImageColor3 = L.Dim,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
	}, { new("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder }) })

	local shown = { cash = 0, bank = 0 }
	local function roll(label: TextLabel, from: number, to: number)
		local v = Instance.new("NumberValue")
		v.Value = from
		v.Changed:Connect(function(x)
			label.Text = Format.cash(math.floor(x))
		end)
		local tw = TweenService:Create(v, TweenInfo.new(0.45, Enum.EasingStyle.Quint), { Value = to })
		tw.Completed:Once(function()
			label.Text = Format.cash(to)
			v:Destroy()
		end)
		tw:Play()
	end

	local function draw(s: any)
		roll(cashV, shown.cash, s.cash)
		roll(bankV, shown.bank, s.bank)
		shown.cash, shown.bank = s.cash, s.bank
		today.Text = string.format('This session:  <font color="#5CC468">+%s earned</font>   <font color="#E85454">-%s spent</font>', Format.cash(s.today.earned), Format.cash(s.today.spent))
		for _, ch in list:GetChildren() do
			if ch:IsA("GuiObject") then
				ch:Destroy()
			end
		end
		for i, m in s.recent do
			local r = new("Frame", { Parent = list, Size = UDim2.new(1, 0, 0, 36), BackgroundTransparency = 1, LayoutOrder = i })
			text(r, os.date("%H:%M", m.at) :: string, { size = 12, color = L.Dim, font = L.Mono, sizeU = UDim2.new(0, 60, 1, 0) })
			text(r, m.reason, { size = 14, pos = UDim2.fromOffset(70, 0), sizeU = UDim2.new(1, -230, 1, 0) })
			text(r, (if m.delta >= 0 then "+" else "-") .. Format.cash(math.abs(m.delta)), { font = L.Bold, size = 14, color = if m.delta >= 0 then L.Money else L.Text, align = Enum.TextXAlignment.Right, pos = UDim2.new(1, 0, 0, 0), anchor = Vector2.new(1, 0), sizeU = UDim2.new(0, 160, 1, 0) })
			new("Frame", { Parent = r, Position = UDim2.new(0, 0, 1, -1), Size = UDim2.new(1, 0, 0, 1), BackgroundColor3 = L.Line, BackgroundTransparency = 0.94, BorderSizePixel = 0 })
		end
		if #s.recent == 0 then
			text(list, "No money moves yet this session.", { size = 14, color = L.Dim, sizeU = UDim2.new(1, 0, 0, 40) })
		end
	end

	local function act(action: string)
		local res = api.request(action, { amount = tonumber(box.Text) or 0 })
		if res and res.ok then
			msg.Text = ""
			box.Text = ""
			draw(res)
		else
			msg.Text = res and res.err or "Failed"
		end
	end
	button(row, "DEPOSIT", function()
		act("deposit")
	end, { pos = UDim2.new(0.4, 10, 0, 0), sizeU = UDim2.new(0.2, -10, 1, 0), color = Color3.fromRGB(46, 120, 60) })
	button(row, "WITHDRAW", function()
		act("withdraw")
	end, { pos = UDim2.new(0.6, 10, 0, 0), sizeU = UDim2.new(0.2, -10, 1, 0) })
	button(row, "ALL CASH", function()
		box.Text = tostring(shown.cash)
	end, { pos = UDim2.new(0.8, 10, 0, 0), sizeU = UDim2.new(0.2, -10, 1, 0), size = 13 })

	task.spawn(function()
		local res = api.request("state")
		if alive and res and res.ok then
			draw(res)
		elseif alive then
			msg.Text = res and res.err or "Can't reach the bank"
		end
	end)

	return {
		unmount = function()
			alive = false
		end,
	}
end

return App
