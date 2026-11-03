--!strict
-- Thin, crash-proof wrapper over AnalyticsService. Only records in the published game (Studio calls are no-ops there).
local AnalyticsService = game:GetService("AnalyticsService")

local Analytics = {}

local function try(fn, ...)
	local ok, err = pcall(fn, ...)
	if not ok then
		warn("[MTL Analytics]", err)
	end
end

-- Story stage -> onboarding funnel step (step number = stage index in Config/Story).
function Analytics.onboarding(player: Player, step: number, name: string)
	try(function()
		AnalyticsService:LogOnboardingFunnelStepEvent(player, step, name)
	end)
end

-- Recurring funnels (job app, shop): one sessionId per visit.
function Analytics.funnel(player: Player, funnel: string, sessionId: string, step: number, name: string)
	try(function()
		AnalyticsService:LogFunnelStepEvent(player, funnel, sessionId, step, name)
	end)
end

-- One-off custom events (A/B test assignment, etc.). value is a number; fields are short strings.
function Analytics.custom(player: Player, name: string, value: number?, fields: { [string]: string }?)
	try(function()
		AnalyticsService:LogCustomEvent(player, name, value or 1, fields or {})
	end)
end

-- Every cash change. source = true for money in, false for money out. reason is our own short id ("Job:Supermarket").
function Analytics.cash(player: Player, source: boolean, amount: number, balance: number, reason: string)
	if amount <= 0 then
		return
	end
	try(function()
		local flow = if source then Enum.AnalyticsEconomyFlowType.Source else Enum.AnalyticsEconomyFlowType.Sink
		local kind = if string.find(reason, "^Purchase") then Enum.AnalyticsEconomyTransactionType.IAP.Name
			elseif source then Enum.AnalyticsEconomyTransactionType.Gameplay.Name
			else Enum.AnalyticsEconomyTransactionType.Shop.Name
		AnalyticsService:LogEconomyEvent(player, flow, "Cash", amount, balance, kind, reason)
	end)
end

return Analytics
