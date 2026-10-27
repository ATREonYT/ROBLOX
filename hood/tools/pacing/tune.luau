-- Tries a set of World 1 numbers in pacing.luau's player before they go into the game. Appended to pacing.luau in
-- one snippet, after setting any of NEED, SP, PAD, WALK, LANES (globals; leave one out to keep the game's own):
--   lune run hood/tools/checks/harness_unit.luau hood/src - "PACING_REPORT = false NEED = {...} $(cat hood/tools/pacing/pacing.luau) $(cat hood/tools/pacing/tune.luau)"
-- The owner's target (Oct 27): World 1 in 25-30 minutes, later worlds longer. Paste what works into Config/Balance
-- (RebirthNeed, StagePower, PadCash) and Config/Skins (the lanes' Rebirths).
local function copy(dst, src) for i, v in src do dst[i] = v end end
if NEED then copy(Balance.RebirthNeed, NEED) end
if SP then copy(Balance.StagePower, SP) end
if PAD then copy(Balance.PadCash, PAD) end
if WALK then copy(Balance.Walk, WALK) end
if NEED then for i = #NEED + 1, #Balance.RebirthNeed do Balance.RebirthNeed[i] = nil end end
if LANES then
	for _, g in Skins.Stations do
		if LANES[g.Id] then g.Rebirths = LANES[g.Id] end
	end
end
report()
