--[[
	Leaderboard panel: global top 10 for each board in Config.LEADERBOARDS.
	Server pushes new boards every minute (State.Leaderboards).
]]

return function(ctx)
	local Kit, Config, State = ctx.Kit, ctx.Config, ctx.State

	local MEDALS = { Color3.fromRGB(255, 205, 40), Color3.fromRGB(200, 210, 225), Color3.fromRGB(215, 135, 70) }

	local panel = Kit.panel({ Title = "Leaderboard", Icon = "Trophy", Size = UDim2.fromOffset(640, 540) })
	local body = panel.Body
	local scroll = Kit.scrolling({ Parent = body, Position = UDim2.fromOffset(0, 50), Size = UDim2.new(1, 0, 1, -50), ZIndex = 23 })
	Kit.list(scroll, 6)

	local names = {}
	for _, b in ipairs(Config.LEADERBOARDS) do
		table.insert(names, b.Name)
	end
	local current = Config.LEADERBOARDS[1]

	local function build()
		Kit.clear(scroll)
		local rows = State.Leaderboards[current.Id]
		if not rows or #rows == 0 then
			Kit.text({ Text = "Loading...", Size = 28, FrameSize = UDim2.new(1, 0, 0, 60), ZIndex = 25, Parent = scroll })
			return
		end
		for i, entry in ipairs(rows) do
			local medal = MEDALS[i]
			local row = Kit.card({ Color = medal or Kit.Colors.Card, Size = UDim2.new(1, -12, 0, 52), Order = i, Parent = scroll, ZIndex = 24 })
			if i == 1 then
				Kit.shine(row, 3)
			end
			Kit.text({ Text = "#" .. i, Size = 28, FrameSize = UDim2.fromOffset(70, 52), ZIndex = 26, Parent = row })
			local isMe = entry.Name == ctx.Player.Name
			Kit.text({ Text = entry.Name .. (isMe and " (You)" or ""), Size = 24, Color = isMe and Kit.Colors.Yellow or Kit.Colors.White, AlignX = Enum.TextXAlignment.Left, FrameSize = UDim2.new(1, -260, 1, 0), Position = UDim2.fromOffset(76, 0), ZIndex = 26, Parent = row })
			local value = Config.Format(entry.Value) .. (current.Id == "Distance" and " studs" or "")
			Kit.text({ Text = value, Size = 24, AlignX = Enum.TextXAlignment.Right, FrameSize = UDim2.fromOffset(180, 52), Position = UDim2.new(1, -192, 0, 0), ZIndex = 26, Parent = row })
		end
	end

	local tabs = Kit.tabs({ Names = names, Parent = body, OnSelect = function(name)
		for _, b in ipairs(Config.LEADERBOARDS) do
			if b.Name == name then
				current = b
			end
		end
		build()
	end })

	return {
		Frame = panel.Frame,
		OnOpen = function(tab)
			if next(State.Leaderboards) == nil then
				task.spawn(function()
					local boards = ctx.Request("GetLeaderboards")
					if type(boards) == "table" then
						State.Leaderboards = boards
						build()
					end
				end)
			end
			tabs:Select(tab or current.Name)
		end,
		Refresh = function(what)
			if what == "Leaderboards" then
				build()
			end
		end,
	}
end
