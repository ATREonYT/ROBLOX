-- The Daily Rewards window (brief 29, P5: the reference's window; moved out of HUD.client in brief 30). Brief 30 (MOCKUP):
-- restyled to the user's own artboard (05 right, Shared/ShoeScreens.daily): a cyan studded header with the calendar and
-- the red X, six day cards with their coloured strips (green, cyan, yellow, magenta, purple, orange) and the tall Day 7,
-- claimed days under a big green tick, today's "Claim!" button, the days to come plain; the status strip under them.
-- Everything comes from the server (RetentionService 'State'; the numbers are Shared/RetentionRules and are the ones
-- granted; a claim is answered once, the server refuses a second). P5's streak and restore logic is kept: after a missed
-- day, "Restore" (a small Robux product, its real price on the button) or start again at Day 1; the group reward's Claim.
--   require(DailyWindow)(Windows, { buy, label, fillText }) -> the HudWindows window
local RS = game:GetService('ReplicatedStorage')
local MarketplaceService = game:GetService('MarketplaceService')
local Kit = require(RS.Shared.UIKit)
local Net = require(RS.Shared.Net)
local Products = require(RS.Shared.Config.Products)
local RobuxText = require(RS.Shared.RobuxText)
local A = require(RS.Shared.ArtKit)
local Screens = require(RS.Shared.ShoeScreens)

return function(Windows, helpers)
	local buy = helpers.buy
	local rewards = Windows.make('Rewards', { Title = 'Daily Rewards', Icon = 'Rewards', Tone = 'headerCyan', Width = 951, Height = 748, TitleSize = 64, Gloss = false })
	-- (the HudWindows frame stays as the window's shell; the artboard's panel covers it)
	for _, c in rewards.Panel:GetChildren() do
		if c:IsA('GuiObject') and c.Name ~= 'Sink' then c.Visible = false end
	end
	local holder = Kit.new('Frame', { Name = 'Art', BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 40, Parent = rewards.Panel })
	local dailyState, dailyBusy, dailyAt = nil, false, 0
	local view
	local function askRetention(action)
		local ok, res = pcall(function() return Net.get('Retention'):InvokeServer(action) end)
		return ok and type(res) == 'table' and res or nil
	end
	local function paint()
		if not view then return end
		view.paint(dailyState)
	end
	local function claim(action)
		if dailyBusy then return end
		dailyBusy = true
		if view and view.ClaimButton then A.setState(view.ClaimButton, 'loading', 'Claim...') end
		local res = askRetention(action)
		dailyBusy = false
		if res and res.State then dailyState, dailyAt = res.State, os.clock() end
		paint()
	end
	view = Screens.daily(holder, nil, {
		close = function() Windows.close() end,
		claim = function() claim('ClaimDaily') end,
		claimGroup = function() claim('ClaimGroup') end,
		restore = function() buy('RestoreStreak') end,
		restorePrice = function()
			local e = Products.ByKey.RestoreStreak
			return e and RobuxText.fmt(e.Price) or ''
		end,
		waitLeft = function()
			local d = dailyState and dailyState.Daily
			return d and math.max(0, (d.Wait or 0) - (os.clock() - dailyAt)) or 0
		end,
	})
	A.place(view.P, 0, 0, 1)
	local function refresh()
		local res = askRetention('State')
		if res and res.State then
			dailyState, dailyAt = res.State, os.clock()
			paint()
		end
	end
	rewards.Open = function()
		paint()
		task.spawn(refresh)
	end
	pcall(function()
		MarketplaceService.PromptProductPurchaseFinished:Connect(function(_, id, bought)
			if bought and Products.keyFor('Product', id) == 'RestoreStreak' then
				task.delay(2, function() if Windows.current() == rewards then refresh() end end)
			end
		end)
	end)
	task.spawn(function()
		while task.wait(1) do
			if Windows.current() == rewards and dailyState and dailyState.Daily and not dailyState.Daily.Ready then paint() end
		end
	end)
	return rewards
end
