--!strict
-- Phone app: Recents (missed in red, "Call back" on calls that wait for an answer) and Contacts.
-- Calling a contact with no scripted call plays the local "Calling... / No answer" screen.
local App = { id = "Calls", title = "Phone" }

local KIND_TEXT = {
	missed = "Missed call",
	declined = "Declined",
	answered = "Incoming",
	outgoing = "Outgoing",
}

local function name(ctx: any, id: string): string
	if id == "Unknown" then
		return "Unknown number"
	end
	local c = ctx.Story.Contacts[id]
	return if c then c.Name else id
end

local function glyph(ctx: any, id: string): string
	return if id == "Unknown" then "?" else string.sub(name(ctx, id), 1, 1)
end

-- the newest Recents entry for this contact that can be called back
local function callBackFor(d: any, contact: string): any?
	for _, r in d.Phone.Recents or {} do
		if r.contact == contact and r.callBack then
			return r
		end
	end
	return nil
end

local function tabs(ctx: any, active: string, onPick: (string) -> ())
	local UIKit, Theme = ctx.UIKit, ctx.Theme
	local bar = UIKit.new("Frame", {
		Name = "Tabs",
		Position = UDim2.fromOffset(12, 46),
		Size = UDim2.new(1, -24, 0, 32),
		BackgroundColor3 = Theme.Phone.Card,
		Parent = ctx.frame,
	}, { UIKit.corner(UDim.new(0, 8)), UIKit.list(0, true), UIKit.padding(3) })
	for i, t in { "Recents", "Contacts" } do
		local on = t == active
		local b = UIKit.new("TextButton", {
			Name = t,
			LayoutOrder = i,
			Size = UDim2.new(0.5, 0, 1, 0),
			BackgroundColor3 = if on then Theme.Phone.CardHover else Theme.Phone.Card,
			BackgroundTransparency = if on then 0 else 1,
			AutoButtonColor = false,
			FontFace = Theme.Fonts.Display,
			Text = t,
			TextColor3 = if on then Theme.Colors.Text else Theme.Colors.TextDim,
			TextSize = 14,
			Parent = bar,
		}, { UIKit.corner(UDim.new(0, 8)) })
		b.Activated:Connect(function()
			onPick(t)
		end)
	end
end

local show: (any, string) -> ()

local function recents(ctx: any, list: ScrollingFrame, d: any)
	local UIKit, Theme = ctx.UIKit, ctx.Theme
	local entries = d.Phone.Recents or {}
	if #entries == 0 then
		UIKit.empty(list, "No calls yet.")
		return
	end
	local now = os.time()
	for i, r in entries do
		local missed = r.kind == "missed" or r.kind == "declined"
		local row = UIKit.row(list, {
			title = name(ctx, r.contact),
			sub = (KIND_TEXT[r.kind] or r.kind) .. "  ·  " .. ctx.Rules.ago(now - (r.t or now)),
			right = if r.callBack then "Call back" else nil,
			rightColor = if r.callBack then Theme.Colors.Accent else nil,
			glyph = glyph(ctx, r.contact),
			contact = r.contact,
			order = i,
			onClick = function()
				if r.callBack and r.call then
					ctx.action("callBack", { call = r.call })
				else
					ctx.Phone.fakeCall(name(ctx, r.contact), ctx.Config.NoAnswer[r.contact])
				end
			end,
		})
		if missed then
			row.Title.TextColor3 = Theme.Colors.Danger
		end
		if r.callBack then
			-- accent outline so the one thing to do here is obvious
			local stroke = UIKit.stroke(0.4, Theme.Colors.Accent)
			stroke.Parent = row
		end
	end
end

local function contacts(ctx: any, list: ScrollingFrame, d: any)
	local UIKit = ctx.UIKit
	local ids = {}
	for id in d.Phone.Contacts or {} do
		table.insert(ids, id)
	end
	table.sort(ids, function(a, b)
		return name(ctx, a) < name(ctx, b)
	end)
	if #ids == 0 then
		UIKit.empty(list, "No contacts yet.")
		return
	end
	for i, id in ids do
		local c = ctx.Story.Contacts[id]
		UIKit.row(list, {
			title = name(ctx, id),
			sub = c and c.Subtitle or nil,
			right = "Call",
			glyph = glyph(ctx, id),
			contact = id,
			order = i,
			onClick = function()
				local cb = callBackFor(d, id)
				if cb then
					ctx.action("callBack", { call = cb.call })
				else
					ctx.Phone.fakeCall(name(ctx, id), ctx.Config.NoAnswer[id])
				end
			end,
		})
	end
end

show = function(ctx: any, tab: string)
	ctx.clear()
	ctx.tab = tab
	ctx.UIKit.header(ctx.frame, "Phone")
	tabs(ctx, tab, function(t)
		if t ~= ctx.tab then
			show(ctx, t)
		end
	end)
	local list = ctx.UIKit.scroll(ctx.frame, 84, tab)
	local token = {}
	ctx.token = token
	ctx.onData(function(d: any)
		if ctx.token ~= token then
			return
		end
		for _, c in list:GetChildren() do
			if c:IsA("GuiObject") then
				c:Destroy()
			end
		end
		if tab == "Recents" then
			recents(ctx, list, d)
		else
			contacts(ctx, list, d)
		end
	end)
end

function App.mount(_frame: Frame, ctx: any)
	show(ctx, ctx.args.tab or "Recents")
	local d = ctx.data()
	if d and ctx.Rules.missedCount(d.Phone) > 0 then
		ctx.action("seenRecents")
	end
end

return App
