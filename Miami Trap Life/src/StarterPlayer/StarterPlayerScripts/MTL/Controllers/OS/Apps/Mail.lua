--!strict
-- Liberty OS "Mail": one email per unlock (Config/OS.Mail, stamped server-side in Desk.Mail). Inbox on the left,
-- the open email on the right. New (unread this session) mail gets a blue dot.
local App = {}

local seen: { [string]: boolean } = {} -- read this session (client-only; the server only stamps "received")

function App.mount(root: Frame, api: any): any
	local L = api.look
	local ui = api.ui
	local new, text, corner, stroke = ui.new, ui.text, ui.corner, ui.stroke
	local alive = true

	local inbox = new("ScrollingFrame", {
		Parent = root,
		Name = "Inbox",
		Size = UDim2.new(0, 360, 1, 0),
		BackgroundColor3 = L.Panel,
		BorderSizePixel = 0,
		ScrollBarThickness = 3,
		ScrollBarImageColor3 = L.Dim,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
	}, { new("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder }) })
	new("Frame", { Parent = root, Position = UDim2.fromOffset(360, 0), Size = UDim2.new(0, 1, 1, 0), BackgroundColor3 = L.Line, BackgroundTransparency = L.LineT, BorderSizePixel = 0 })
	local read = new("Frame", { Parent = root, Name = "Read", Position = UDim2.fromOffset(361, 0), Size = UDim2.new(1, -361, 1, 0), BackgroundTransparency = 1 }, {
		new("UIPadding", { PaddingLeft = UDim.new(0, 40), PaddingRight = UDim.new(0, 40), PaddingTop = UDim.new(0, 32) }),
	})
	local subj = text(read, "", { name = "Subject", font = L.Head, size = 30, sizeU = UDim2.new(1, 0, 0, 38) })
	local from = text(read, "", { name = "From", size = 14, color = L.Dim, pos = UDim2.fromOffset(0, 44), sizeU = UDim2.new(1, 0, 0, 18) })
	new("Frame", { Parent = read, Position = UDim2.fromOffset(0, 74), Size = UDim2.new(1, 0, 0, 1), BackgroundColor3 = L.Line, BackgroundTransparency = L.LineT, BorderSizePixel = 0 })
	local body = text(read, "", { name = "Body", size = 18, pos = UDim2.fromOffset(0, 92), sizeU = UDim2.new(1, 0, 1, -120), wrap = true, valign = Enum.TextYAlignment.Top })
	body.LineHeight = 1.25

	local rows: { [string]: any } = {}

	local function stamp(at: number): string
		local dt = os.time() - at
		if dt < 3600 then
			return "just now"
		elseif dt < 86400 then
			return math.floor(dt / 3600) .. "h ago"
		end
		return os.date("%b %d", at) :: string
	end

	local function open(m: any)
		seen[m.id] = true
		subj.Text = m.subject
		from.Text = "From " .. m.from .. "  ·  " .. stamp(m.at)
		body.Text = m.body
		for id, r in rows do
			r.row.BackgroundColor3 = if id == m.id then L.Panel2 else L.Panel
			r.dot.Visible = not seen[id]
		end
	end

	task.spawn(function()
		local res = api.request("mail")
		if not alive then
			return
		end
		if not res or not res.ok then
			text(inbox, res and res.err or "Can't load mail", { color = L.Dim, align = Enum.TextXAlignment.Center, sizeU = UDim2.new(1, 0, 0, 60) })
			return
		end
		for i, m in res.mail do
			local row = new("TextButton", { Parent = inbox, Name = "Mail_" .. m.id, Size = UDim2.new(1, 0, 0, 76), BackgroundColor3 = L.Panel, AutoButtonColor = false, Text = "", BorderSizePixel = 0, LayoutOrder = i })
			local dot = new("Frame", { Parent = row, Name = "Unread", Position = UDim2.fromOffset(14, 18), Size = UDim2.fromOffset(7, 7), BackgroundColor3 = L.Select, BorderSizePixel = 0, Visible = not seen[m.id] }, { corner(4) })
			text(row, m.from, { font = L.Bold, size = 15, pos = UDim2.fromOffset(30, 10), sizeU = UDim2.new(1, -110, 0, 20) })
			text(row, stamp(m.at), { size = 12, color = L.Dim, align = Enum.TextXAlignment.Right, pos = UDim2.new(1, -16, 0, 12), anchor = Vector2.new(1, 0), sizeU = UDim2.new(0, 80, 0, 16) })
			text(row, m.subject, { size = 14, pos = UDim2.fromOffset(30, 32), sizeU = UDim2.new(1, -46, 0, 18) })
			text(row, m.body, { size = 12, color = L.Dim, pos = UDim2.fromOffset(30, 52), sizeU = UDim2.new(1, -46, 0, 16) })
			new("Frame", { Parent = row, Position = UDim2.new(0, 0, 1, -1), Size = UDim2.new(1, 0, 0, 1), BackgroundColor3 = L.Line, BackgroundTransparency = 0.94, BorderSizePixel = 0 })
			rows[m.id] = { row = row, dot = dot }
			row.Activated:Connect(function()
				api.tap()
				ui.click()
				open(m)
			end)
		end
		if res.mail[1] then
			open(res.mail[1])
		end
	end)
	_ = stroke

	return {
		unmount = function()
			alive = false
		end,
	}
end

return App
