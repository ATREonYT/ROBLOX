--!strict
-- Money numbers. Tune here only; no system hard-codes a price or a payout.
return {
	StartCash = 50, -- "bare minimum"
	MaxCash = 1e12,
	CashMultiplier = { Pass = 2, Boost = 2, Max = 4 }, -- pass and boost stack, capped at Max
	XPMultiplier = { Pass = 2, Boost = 2, Max = 4 },
	BoostSecondsPerPurchase = 30 * 60, -- dev product boosts: 30 minutes of PLAY time, stacking
	FirstMissionPay = 1500,
	EndsFlatPrice = 1200,
	PowerBill = 300,
}
