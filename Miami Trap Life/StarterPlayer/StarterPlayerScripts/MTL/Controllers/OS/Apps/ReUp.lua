--!strict
-- Liberty OS "The Re-Up": stash stock (raw -> packs), order a re-up, runners on corners (with heat), the bulk buyer
-- and upgrades. Dark purple, terse, burner-phone energy. Server half: Services/ReUpService.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Format = require(ReplicatedStorage.MTL.Format)

local App = {}

function App.mount(root: Frame, api: any): any
	local L = api.look
	local ui = api.ui
	local new, text, button, corner, stroke = ui.new, ui.text, ui.button, ui.corner, ui.stroke
	local purple = Color3.fromRGB(180, 110, 255)
	local alive = true
	local st: any = nil
	local sel: string? = nil
	local bulkN = 25

	local pad = new("Frame", { Parent = root, Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 }, {
		new("UIPadding", { PaddingLeft = UDim.new(0, 28), PaddingRight = UDim.new(0, 28), PaddingTop = UDim.new(0, 22) }),
	})

	local draw: () -> ()
	local function call(action: string, args: any)
		local res = api.request(action, args)
		if res and res.ok then
			st = res
			draw()
		else
			api.notify(res and res.err or "Failed", L.Loss)
		end
	end

	local function panel(x: number, y: number, w: number, h: number, title: string): Frame
		local f = new("Frame", { Parent = pad, Position = UDim2.new(x, if x > 0 then 7 else 0, 0, y), Size = UDim2.new(w, -7, 0, h), BackgroundColor3 = L.Panel2, BorderSizePixel = 0 }, { corner(), stroke() })
		text(f, title, { font = L.Head, size = 17, color = purple, pos = UDim2.fromOffset(16, 10), sizeU = UDim2.new(1, -32, 0, 20) })
		return f
	end

	local function meter(parent: Instance, y: number, label: string, v: number, max: number, color: Color3)
		text(parent, label, { size = 12, color = L.Dim, pos = UDim2.fromOffset(16, y), sizeU = UDim2.new(0.5, 0, 0, 16) })
		text(parent, string.format("%d / %d", v, max), { font = L.Bold, size = 13, align = Enum.TextXAlignment.Right, pos = UDim2.new(1, -16, 0, y), anchor = Vector2.new(1, 0), sizeU = UDim2.new(0.5, 0, 0, 16) })
		local track = new("Frame", { Parent = parent, Position = UDim2.fromOffset(16, y + 20), Size = UDim2.new(1, -32, 0, 6), BackgroundColor3 = L.Panel3, BorderSizePixel = 0 }, { corner(3) })
		local fill = new("Frame", { Parent = track, Size = UDim2.fromScale(0, 1), BackgroundColor3 = color, BorderSizePixel = 0 }, { corner(3) })
		TweenService:Create(fill, TweenInfo.new(0.5, Enum.EasingStyle.Quint), { Size = UDim2.fromScale(math.clamp(v / math.max(1, max), 0, 1), 1) }):Play()
	end

	draw = function()
		for _, ch in pad:GetChildren() do
			if ch:IsA("GuiObject") then
				ch:Destroy()
			end
		end
		local owned = {}
		for _, s in st.stashes do
			if s.owned then
				table.insert(owned, s)
				if not sel then
					sel = s.id
				end
			end
		end
		text(pad, "THE RE-UP", { font = L.Head, size = 32, color = purple, sizeU = UDim2.new(0.5, 0, 0, 38) })
		text(pad, string.format("%d packs moved all-time", st.sold), { size = 13, color = L.Dim, pos = UDim2.fromOffset(0, 38), sizeU = UDim2.new(0.5, 0, 0, 16) })
		-- stash tabs
		local tabs = new("Frame", { Parent = pad, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 4), Size = UDim2.new(0.5, 0, 0, 34), BackgroundTransparency = 1 }, {
			new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Right, Padding = UDim.new(0, 6) }),
		})
		for i, s in owned do
			local b = button(tabs, string.upper(s.title), function()
				sel = s.id
				draw()
			end, { sizeU = UDim2.new(0, 150, 1, 0), size = 12, order = i, color = if s.id == sel then purple else L.Panel3 })
			if s.id == sel then
				b.TextColor3 = Color3.new(0, 0, 0)
			end
		end
		if #owned == 0 then
			text(pad, "Buy a stash house on Royce Realty to start.", { size = 18, color = L.Dim, pos = UDim2.fromOffset(0, 80), sizeU = UDim2.new(1, 0, 0, 30) })
			return
		end
		local s: any = nil
		for _, x in owned do
			if x.id == sel then
				s = x
			end
		end
		local y = 64
		if st.raid then
			local b = new("Frame", { Parent = pad, Position = UDim2.fromOffset(0, y), Size = UDim2.new(1, 0, 0, 44), BackgroundColor3 = Color3.fromRGB(90, 20, 24), BorderSizePixel = 0 }, { corner(), stroke(0.3, L.Loss) })
			text(b, string.format("RAID INCOMING · %ds · get to the stash and move the stock", math.floor(st.raid.left)), { font = L.Bold, size = 15, align = Enum.TextXAlignment.Center, sizeU = UDim2.fromScale(1, 1) })
			y += 54
		elseif st.job then
			local b = new("Frame", { Parent = pad, Position = UDim2.fromOffset(0, y), Size = UDim2.new(1, 0, 0, 44), BackgroundColor3 = Color3.fromRGB(44, 30, 64), BorderSizePixel = 0 }, { corner(), stroke(0.4, purple) })
			local line = if st.job.kind == "order" then (if st.job.stage == "grab" then "Pick up the duffel at the docks" else "Get the duffel to the stash") else string.format("Meet the buyer with %d packs", st.job.n)
			text(b, "ON A RUN · " .. line, { font = L.Bold, size = 14, pos = UDim2.fromOffset(16, 0), sizeU = UDim2.new(1, -140, 1, 0) })
			button(b, "CANCEL", function()
				call("cancel", {})
			end, { anchor = Vector2.new(1, 0.5), pos = UDim2.new(1, -8, 0.5, 0), sizeU = UDim2.fromOffset(100, 30), size = 12 })
			y += 54
		end

		-- stash
		local sp = panel(0, y, 0.34, 226, "STASH")
		meter(sp, 42, "Raw", s.raw, s.cap, Color3.fromRGB(150, 120, 90))
		meter(sp, 82, "Packs", s.packs, s.cap, purple)
		text(sp, "Runners' take", { size = 12, color = L.Dim, pos = UDim2.fromOffset(16, 124), sizeU = UDim2.new(1, -32, 0, 16) })
		text(sp, Format.cash(s.dirty), { font = L.Head, size = 30, color = L.Money, pos = UDim2.fromOffset(16, 140), sizeU = UDim2.new(1, -32, 0, 34) })
		text(sp, "Dirty: collect it at the stash, wash it at the laundromat", { size = 11, color = L.Dim, pos = UDim2.fromOffset(16, 176), sizeU = UDim2.new(1, -32, 0, 30), wrap = true, valign = Enum.TextYAlignment.Top })
		button(sp, "GPS", function()
			call("gps", { prop = s.id })
			api.notify("GPS set: " .. s.title, L.Select)
		end, { anchor = Vector2.new(1, 0), pos = UDim2.new(1, -12, 0, 8), sizeU = UDim2.fromOffset(60, 26), size = 12 })

		-- order
		local op = panel(0.34, y, 0.33, 226, "RE-UP  ·  pick up at the docks")
		for i, o in st.orders do
			local b = button(op, "", function()
				call("order", { prop = s.id, n = o.n })
			end, { pos = UDim2.fromOffset(16, 40 + (i - 1) * 60), sizeU = UDim2.new(1, -32, 0, 52), color = L.Panel3 })
			text(b, o.n .. " PACKS", { font = L.Head, size = 20, pos = UDim2.fromOffset(14, 0), sizeU = UDim2.new(0.5, 0, 1, 0) })
			text(b, string.format("%s  ·  %s ea", Format.cash(o.n * o.each), Format.cash(o.each)), { font = L.Bold, size = 13, color = L.Money, align = Enum.TextXAlignment.Right, pos = UDim2.new(1, -14, 0, 0), anchor = Vector2.new(1, 0), sizeU = UDim2.new(0.5, 0, 1, 0) })
		end

		-- bulk buyer
		local bp = panel(0.67, y, 0.33, 226, "BULK BUYER")
		if (st.level or 1) < st.bulk.level then
			text(bp, "Unlocks at Level " .. st.bulk.level, { font = L.Bold, size = 14, color = L.Gold, pos = UDim2.fromOffset(16, 44), sizeU = UDim2.new(1, -32, 0, 18) })
			text(bp, string.format("Moves %d+ packs at once for %s each at a meet.", st.bulk.min, Format.cash(st.bulk.each)), { size = 13, color = L.Dim, pos = UDim2.fromOffset(16, 68), sizeU = UDim2.new(1, -32, 0, 40), wrap = true, valign = Enum.TextYAlignment.Top })
		else
			bulkN = math.clamp(bulkN, st.bulk.min, math.max(st.bulk.min, s.packs))
			local nL = text(bp, "", { font = L.Head, size = 34, pos = UDim2.fromOffset(16, 40), sizeU = UDim2.new(1, -32, 0, 40) })
			local tL = text(bp, "", { font = L.Bold, size = 15, color = L.Money, pos = UDim2.fromOffset(16, 82), sizeU = UDim2.new(1, -32, 0, 20) })
			local function refresh()
				nL.Text = bulkN .. " packs"
				tL.Text = Format.cash(bulkN * st.bulk.each) .. " dirty"
			end
			refresh()
			local row = new("Frame", { Parent = bp, Position = UDim2.fromOffset(16, 116), Size = UDim2.new(1, -32, 0, 34), BackgroundTransparency = 1 }, {
				new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6) }),
			})
			for i, dlt in { -5, 5 } do
				button(row, (if dlt > 0 then "+" else "") .. dlt, function()
					bulkN = math.clamp(bulkN + dlt, st.bulk.min, math.max(st.bulk.min, s.packs))
					refresh()
				end, { sizeU = UDim2.new(0.5, -3, 1, 0), order = i, size = 13 })
			end
			button(bp, "SET UP THE MEET", function()
				call("bulk", { prop = s.id, n = bulkN })
			end, { pos = UDim2.fromOffset(16, 160), sizeU = UDim2.new(1, -32, 0, 44), color = Color3.fromRGB(80, 50, 120), size = 15 })
		end
		y += 240

		-- corners
		local cp = panel(0, y, 1, 168, string.format("CORNERS  ·  %d runner slot%s at your level", st.slots, if st.slots == 1 then "" else "s"))
		for i, c in st.corners do
			local x = (i - 1) / #st.corners
			local card = new("Frame", { Parent = cp, Position = UDim2.new(x, 16 - (i - 1) * 8, 0, 40), Size = UDim2.new(1 / #st.corners, -12, 0, 114), BackgroundColor3 = L.Panel3, BorderSizePixel = 0 }, { corner() })
			text(card, c.title, { font = L.Bold, size = 14, pos = UDim2.fromOffset(12, 8), sizeU = UDim2.new(1, -24, 0, 18) })
			text(card, string.format("%s ea · %s", Format.cash(c.pay), c.turf), { size = 12, color = L.Dim, pos = UDim2.fromOffset(12, 28), sizeU = UDim2.new(1, -24, 0, 16) })
			local hc = if c.heat > 0.6 then L.Loss elseif c.heat > 0.3 then L.Warn else L.Select
			text(card, "Heat", { size = 11, color = L.Dim, pos = UDim2.fromOffset(12, 48), sizeU = UDim2.new(0.5, 0, 0, 14) })
			local track = new("Frame", { Parent = card, Position = UDim2.fromOffset(46, 52), Size = UDim2.new(1, -58, 0, 5), BackgroundColor3 = L.Panel, BorderSizePixel = 0 }, { corner(3) })
			new("Frame", { Parent = track, Size = UDim2.fromScale(c.heat, 1), BackgroundColor3 = hc, BorderSizePixel = 0 }, { corner(3) })
			if c.prop == s.id then
				button(card, "PULL RUNNER", function()
					call("assign", { corner = c.id })
				end, { pos = UDim2.fromOffset(12, 70), sizeU = UDim2.new(1, -24, 0, 32), size = 12, color = Color3.fromRGB(80, 50, 120) })
			elseif c.prop then
				text(card, "Runner from another stash", { size = 12, color = L.Dim, pos = UDim2.fromOffset(12, 76), sizeU = UDim2.new(1, -24, 0, 18) })
			else
				button(card, "SEND RUNNER", function()
					call("assign", { corner = c.id, prop = s.id })
				end, { pos = UDim2.fromOffset(12, 70), sizeU = UDim2.new(1, -24, 0, 32), size = 12 })
			end
		end
		y += 182

		-- upgrades
		for i, u in s.upgrades do
			local r = new("Frame", { Parent = pad, Position = UDim2.new((i - 1) / 2, if i == 1 then 0 else 7, 0, y), Size = UDim2.new(0.5, -7, 0, 64), BackgroundColor3 = L.Panel2, BorderSizePixel = 0 }, { corner(), stroke() })
			text(r, u.title, { font = L.Bold, size = 15, pos = UDim2.fromOffset(14, 8), sizeU = UDim2.new(0.6, 0, 0, 20) })
			text(r, u.blurb, { size = 12, color = L.Dim, pos = UDim2.fromOffset(14, 30), sizeU = UDim2.new(0.66, 0, 0, 28), wrap = true, valign = Enum.TextYAlignment.Top })
			if u.owned then
				text(r, "ON IT", { font = L.Bold, size = 14, color = L.Select, align = Enum.TextXAlignment.Right, pos = UDim2.new(1, -14, 0.5, -10), anchor = Vector2.new(1, 0), sizeU = UDim2.fromOffset(100, 20) })
			else
				button(r, if (st.level or 1) >= u.level then Format.cash(u.price) else "Level " .. u.level, function()
					call("upgrade", { prop = s.id, id = u.id })
				end, { anchor = Vector2.new(1, 0.5), pos = UDim2.new(1, -12, 0.5, 0), sizeU = UDim2.fromOffset(110, 32), size = 13 })
			end
		end
	end

	local function load()
		local res = api.request("state")
		if not alive then
			return
		end
		if res and res.ok then
			st = res
			draw()
		end
	end
	task.spawn(load)
	-- the runners keep selling while you watch: refresh every 15 s
	task.spawn(function()
		while alive do
			task.wait(15)
			if alive then
				load()
			end
		end
	end)

	return {
		unmount = function()
			alive = false
		end,
	}
end

return App
