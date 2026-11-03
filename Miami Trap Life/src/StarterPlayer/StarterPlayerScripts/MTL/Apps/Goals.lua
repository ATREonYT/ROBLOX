--!strict
-- Goals app (Piece 4, Master Plan §1 stage 13 FreePlay): "what do I do now?". Unlocks when free play starts.
--   NEXT UP  the top unfinished goal, big, with a progress bar and its one button (Pay $300 / Route to work / Open)
--   GOALS    every other goal: done ones ticked, "Coming soon" ones greyed (kid-safe: nothing fake is sold)
-- Same rules as the server (Rules/GoalRules over the save snapshot), so the list and the HUD line always agree.
-- Buttons: PhoneAction payPower / gpsRoute{place}; opening another app goes through ctx.Phone.open.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GoalRules = require(ReplicatedStorage.MTL.Rules.GoalRules)
local Jobs = require(ReplicatedStorage.MTL.Config.Jobs)

local App = { id = "Goals", title = "Goals" }

local function progressBar(UIKit: any, Theme: any, parent: Instance, p: number, order: number, color: Color3?)
	local track = UIKit.new("Frame", {
		Name = "Progress",
		LayoutOrder = order,
		Size = UDim2.new(1, 0, 0, 4),
		BackgroundColor3 = Theme.Phone.CardHover,
		Parent = parent,
	}, { UIKit.corner(UDim.new(0, 1)) })
	UIKit.new("Frame", {
		Name = "Fill",
		Size = UDim2.fromScale(math.clamp(p, 0, 1), 1),
		BackgroundColor3 = color or Theme.Colors.Accent,
		Parent = track,
	}, { UIKit.corner(UDim.new(0, 1)) })
	return track
end

local function doAction(ctx: any, d: any, action: any)
	if type(action) ~= "table" then
		return
	end
	if action.kind == "payPower" then
		ctx.action("payPower", {})
	elseif action.kind == "route" then
		local place = action.place
		if place == "@job" then
			local def = Jobs.Defs[d.Job and d.Job.Current or ""]
			place = def and def.place
		end
		if place then
			ctx.action("gpsRoute", { place = place })
			ctx.close()
		end
	elseif action.kind == "app" and action.app then
		ctx.Phone.open(action.app, action.args) -- args: e.g. { tab = "Dealer" } for the Garage
	end
end

local function render(ctx: any, d: any)
	ctx.clear()
	local UIKit, Theme = ctx.UIKit, ctx.Theme
	local C = Theme.Colors
	UIKit.header(ctx.frame, "Goals")
	local list = UIKit.scroll(ctx.frame, 44, "Goals")
	local entries = GoalRules.evaluate(d)
	local top = GoalRules.top(d)
	local order = 0
	local function nextOrder(): number
		order += 1
		return order
	end

	if top then
		UIKit.section(list, "NEXT UP", nextOrder())
		local card = UIKit.card(list, nextOrder(), "Top")
		UIKit.stroke(0, C.Gold).Parent = card
		UIKit.label(card, top.title, { size = 18, bold = true, wrap = true, name = "Title", order = 1 })
		UIKit.label(card, top.sub or "", { size = 12, dim = true, wrap = true, name = "Sub", order = 2 })
		progressBar(UIKit, Theme, card, top.progress, 3, C.Gold)
		UIKit.label(card, top.progressText .. (if top.reward > 0 then ("   ·   +" .. top.reward .. " XP") else ""), { size = 12, color = C.Gold, name = "ProgressText", order = 4 })
		if top.action then
			-- always pressable: the server checks the cash and answers with a toast ("You need $80 more...")
			UIKit.button(card, top.action.label or "Go", {
				style = "primary",
				name = "Action",
				order = 10,
				onClick = function()
					doAction(ctx, d, top.action)
				end,
			})
		end
	else
		UIKit.section(list, "NEXT UP", nextOrder())
		UIKit.empty(list, "You've done every goal there is for now. More come with every update.", nextOrder())
	end

	UIKit.section(list, "GOALS", nextOrder())
	for _, e in entries do
		if top and e.id == top.id then
			continue
		end
		local card = UIKit.card(list, nextOrder(), "Goal_" .. e.id)
		UIKit.label(card, (if e.done then "DONE  ·  " else "") .. e.title, {
			size = 15,
			bold = true,
			wrap = true,
			color = if e.done then C.Accent elseif e.soon then C.TextDim else C.Text,
			name = "Title",
			order = 1,
		})
		UIKit.label(card, if e.soon then ("Coming soon. " .. (e.sub or "")) else (e.sub or ""), { size = 12, dim = true, wrap = true, name = "Sub", order = 2 })
		if not e.soon and not e.done then
			progressBar(UIKit, Theme, card, e.progress, 3)
			UIKit.label(card, e.progressText, { size = 11, dim = true, name = "ProgressText", order = 4 })
		end
		if e.soon then
			card.BackgroundTransparency = 0.4
		end
	end
end

function App.mount(frame: Frame, ctx: any)
	local last = ""
	ctx.onData(function(d)
		if not d or not frame.Parent then
			return
		end
		-- re-render only when something a goal reads changed
		local claimed = 0
		for _ in (d.Goals and d.Goals.Done) or {} do
			claimed += 1
		end
		local key = table.concat({
			tostring(d.Cash),
			tostring(d.Level),
			tostring(d.Path),
			tostring(d.Home and d.Home.PowerOn),
			tostring(d.Job and d.Job.Current),
			tostring(d.Job and d.Job.Current and d.Job.Shifts and d.Job.Shifts[d.Job.Current]),
			tostring(claimed),
		}, "|")
		if key ~= last then
			last = key
			render(ctx, d)
		end
	end)
end

return App
