--!strict
-- Settings: Lifestyle (Civilian / Criminal, Master Plan §1 branching rules), sound/music/reduced motion, help.
-- Lifestyle is locked until free play (after the first mission). Switching asks for a confirm, then the server
-- checks the stage, the cooldown and any guards (e.g. no switching mid-fight) and answers with "pathResult".
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local StoryRules = require(ReplicatedStorage.MTL.Rules.StoryRules)
local Quality = require(ReplicatedStorage.MTL.Config.Quality)
local GameInfo = require(ReplicatedStorage.MTL.Config.Game)

local App = { id = "Settings", title = "Settings" }

local render: (any, any) -> ()

local function confirm(ctx: any, path: string)
	ctx.clear()
	ctx.confirming = path
	local UIKit, Theme = ctx.UIKit, ctx.Theme
	local info = ctx.Config.Paths[path]
	UIKit.header(ctx.frame, "Lifestyle", function()
		ctx.confirming = nil
		local d = ctx.data()
		if d then
			render(ctx, d)
		end
	end)
	local list = UIKit.scroll(ctx.frame, 44, "Confirm")
	local card = UIKit.card(list, 1)
	UIKit.label(card, "Switch to " .. info.title .. "?", { size = 18, bold = true, order = 1 })
	UIKit.label(card, info.blurb, { wrap = true, dim = true, order = 2 })
	UIKit.label(card, "You can switch back later.", { size = 12, dim = true, order = 3 })
	local status = UIKit.label(list, "", { wrap = true, order = 4, align = Enum.TextXAlignment.Center, name = "Status" })
	status.TextColor3 = Theme.Colors.Danger
	ctx.statusLabel = status
	UIKit.button(list, "Switch to " .. info.title, {
		style = if path == "Criminal" then "danger" else "primary",
		order = 5,
		onClick = function()
			status.Text = "..."
			ctx.action("setPath", { path = path })
		end,
	})
	UIKit.button(list, "Cancel", {
		style = "secondary",
		order = 6,
		onClick = function()
			ctx.confirming = nil
			local d = ctx.data()
			if d then
				render(ctx, d)
			end
		end,
	})
end

render = function(ctx: any, d: any)
	ctx.clear()
	ctx.statusLabel = nil
	local UIKit, Theme = ctx.UIKit, ctx.Theme
	local C = Theme.Colors
	UIKit.header(ctx.frame, "Settings")
	local list = UIKit.scroll(ctx.frame, 44, "Settings")

	-- Lifestyle
	UIKit.section(list, "Lifestyle", 1)
	local open = StoryRules.freePlayOpen(d.Story.Stage)
	for i, path in { "Civilian", "Criminal" } do
		local info = ctx.Config.Paths[path]
		local mine = d.Path == path
		local row = UIKit.row(list, {
			title = info.title,
			sub = info.blurb,
			right = if mine then "Current" elseif open then "Switch" else "Locked",
			rightColor = if mine then C.Accent elseif open then C.Text else C.TextDim,
			dot = if mine then (if path == "Criminal" then C.Danger else C.Accent) else nil,
			order = 1 + i,
			name = "Path_" .. path,
			onClick = function()
				if open and not mine then
					confirm(ctx, path)
				end
			end,
		})
		row.Size = UDim2.new(1, 0, 0, 62)
		row.Sub.TextWrapped = true
		row.Sub.Size = UDim2.new(row.Sub.Size.X.Scale, row.Sub.Size.X.Offset, 0, 30)
	end
	if not open then
		UIKit.label(list, "Unlocks after your first mission.", { size = 12, dim = true, order = 4 })
	end

	-- Sound & motion
	UIKit.section(list, "Sound & motion", 10)
	local s = d.Settings or {}
	local function setter(key: string)
		return function(v: boolean)
			ctx.action("setSetting", { key = key, value = v })
		end
	end
	UIKit.toggle(list, "Sound effects", s.Sound ~= false, setter("Sound"), 11)
	UIKit.toggle(list, "Music", s.Music ~= false, setter("Music"), 12)
	UIKit.toggle(list, "Reduced motion", s.ReducedMotion == true, setter("ReducedMotion"), 13)
	-- Graphics: Auto follows the device and frame rate (QualityController); tap cycles Auto / Low / Med / High
	local graphics = Quality.Choices[s.Graphics or 0] or "Auto"
	UIKit.row(list, {
		title = "Graphics",
		sub = if graphics == "Auto" then "Adapts to your device (now " .. tostring(Players.LocalPlayer:GetAttribute("MTL_QualityTier") or "Med") .. ")" else "Fixed quality",
		right = graphics,
		rightColor = C.Accent,
		order = 14,
		name = "Graphics",
		onClick = function()
			ctx.action("setSetting", { key = "Graphics", value = ((s.Graphics or 0) + 1) % 4 })
		end,
	})

	-- Help
	UIKit.section(list, "Help", 20)
	local help = UIKit.card(list, 21)
	local touch = game:GetService("UserInputService").TouchEnabled
	UIKit.label(help, if touch then "Tap the phone to open it. Drag the top or bottom bar down to put it away." else "Press M or click the phone to open it. Press M again or click the world to put it away.", { wrap = true, dim = true, size = 13, order = 1 })
	if d.DataMode == "Mock" then
		UIKit.label(help, "Studio test mode: progress resets when you stop.", { wrap = true, size = 12, order = 2, color = C.Gold })
	end
	UIKit.label(list, GameInfo.Title .. " · " .. Players.LocalPlayer.Name, { size = 11, dim = true, order = 30, align = Enum.TextXAlignment.Center })
end

function App.mount(_frame: Frame, ctx: any)
	local lastKey = ""
	ctx.onData(function(d: any)
		if ctx.confirming then
			-- the switch went through while confirming -> back to the list
			if d.Path == ctx.confirming then
				ctx.confirming = nil
			else
				return
			end
		end
		local st = d.Settings or {}
		local k = table.concat({ tostring(d.Story.Stage), tostring(d.Path), tostring(st.Sound), tostring(st.Music), tostring(st.ReducedMotion), tostring(st.Graphics) }, "|")
		if k ~= lastKey then
			lastKey = k
			render(ctx, d)
		end
	end)
end

function App.onEvent(msg: any, ctx: any)
	if msg.type == "pathResult" and not msg.ok and ctx.statusLabel and ctx.statusLabel.Parent then
		ctx.statusLabel.Text = msg.reason or "Can't switch right now"
	end
end

return App
