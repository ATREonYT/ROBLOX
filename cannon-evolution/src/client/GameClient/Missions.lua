--[[
	Missions panel: Daily / Weekly / Infinite with progress and Claim.
	Progress = stat now - stat when the mission period started (Base).
]]

return function(ctx)
	local Kit, Config, State = ctx.Kit, ctx.Config, ctx.State

	local panel = Kit.panel({ Title = "Missions", Icon = "Missions", Size = UDim2.fromOffset(760, 520) })
	local body = panel.Body
	local timer = Kit.text({ Text = "", Size = 20, Color = Kit.Colors.Yellow, FrameSize = UDim2.new(1, 0, 0, 24), Position = UDim2.fromOffset(0, 46), ZIndex = 24, Parent = body })
	local scroll = Kit.scrolling({ Parent = body, Position = UDim2.fromOffset(0, 74), Size = UDim2.new(1, 0, 1, -74), ZIndex = 23 })
	Kit.list(scroll, 8)

	local current = "Daily"
	local rows = {}

	local function stat(data, s)
		return s == "Distance" and data.BestDistance or (data.Stats[s] or 0)
	end

	local function rewardText(reward, scale)
		scale = scale or 1
		if reward.Gems then
			return "💎 " .. Config.Format(reward.Gems * scale)
		elseif reward.Cash then
			return "💵 " .. Config.Format(reward.Cash * scale)
		end
		return "🎁"
	end

	local function build()
		Kit.clear(scroll)
		rows = {}
		for i, def in ipairs(Config.Missions[current]) do
			local row = Kit.card({ Color = Kit.Colors.Card, Size = UDim2.new(1, -12, 0, 84), Order = i, Parent = scroll, ZIndex = 24 })
			Kit.icon("Quest", { Size = UDim2.fromOffset(60, 60), Position = UDim2.fromOffset(12, 12), ZIndex = 26, Parent = row })
			local title = Kit.text({ Text = "", Size = 24, AlignX = Enum.TextXAlignment.Left, FrameSize = UDim2.new(1, -330, 0, 30), Position = UDim2.fromOffset(84, 8), ZIndex = 26, Parent = row })
			local bar = Kit.progress({ Parent = row, Position = UDim2.fromOffset(84, 46), Size = UDim2.new(1, -330, 0, 24), ZIndex = 25 })
			local reward = Kit.text({ Text = "", Size = 22, FrameSize = UDim2.fromOffset(100, 30), Position = UDim2.new(1, -250, 0.5, 0), Anchor = Vector2.new(0, 0.5), ZIndex = 26, Parent = row })
			local btn = Kit.button({ Text = "Claim", Color = "Green", Size = UDim2.fromOffset(130, 52), Position = UDim2.new(1, -12, 0.5, 0), Anchor = Vector2.new(1, 0.5), ZIndex = 27, Parent = row, OnClick = function()
				ctx.Request("ClaimMission", current, def.Id)
			end })
			rows[def.Id] = { Title = title, Bar = bar, Reward = reward, Button = btn }
		end
	end

	local function refresh()
		local data = State.Data
		if not data then
			return
		end
		local m = data.Missions
		for _, def in ipairs(Config.Missions[current]) do
			local r = rows[def.Id]
			local st = m[current] and m[current][def.Id]
			if r and st then
				local progress = stat(data, def.Stat) - st.Base
				local goal = def.Goal
				local scale = 1
				if current == "Infinite" then
					goal = math.floor(def.Goal * def.GoalGrowth ^ (st.Tier - 1))
					scale = st.Tier
					r.Title.Text = string.format(def.Text, Config.Format(goal)) .. "  (Tier " .. st.Tier .. ")"
				else
					r.Title.Text = def.Text
				end
				r.Bar:Set(progress / goal, Config.Format(math.min(progress, goal)) .. " / " .. Config.Format(goal))
				r.Reward.Text = rewardText(def.Reward, scale)
				if st.Claimed then
					r.Button:SetText("Done ✔")
					r.Button:SetColor("Gray")
				elseif progress >= goal then
					r.Button:SetText("Claim")
					r.Button:SetColor("Green")
					Kit.pop(r.Button.Instance, 1.04)
				else
					r.Button:SetText("Claim")
					r.Button:SetColor("Gray")
				end
			end
		end
	end

	-- countdown to the next reset (UTC midnight / Monday)
	Kit.animate(timer, function()
		if not panel.Frame.Visible then
			return
		end
		local now = State.ServerTime()
		if current == "Daily" then
			timer.Text = "Resets in " .. Config.FormatTime(86400 - now % 86400)
		elseif current == "Weekly" then
			local week = 7 * 86400
			timer.Text = "Resets in " .. Config.FormatTime(week - (now + 3 * 86400) % week)
		else
			timer.Text = "Infinite missions level up forever!"
		end
	end)

	local tabs = Kit.tabs({ Names = { "Daily", "Weekly", "Infinite" }, Parent = body, OnSelect = function(name)
		current = name
		build()
		refresh()
	end })

	return {
		Frame = panel.Frame,
		OnOpen = function(tab)
			tabs:Select(tab or current)
		end,
		Refresh = refresh,
	}
end
