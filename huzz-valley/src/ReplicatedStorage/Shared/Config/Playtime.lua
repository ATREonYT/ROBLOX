--[[
	Playtime coin boost (owner, Oct 24 06:12: "make the playtime rewards be like coin boosts, and they stack overtime if
	you are playing, but when you leave they go away"). Every Every seconds you play in a server (not while AFK: the
	clock waits), your game pay goes up another Step, to at most Max steps. It lives only in this server: leaving
	ends it (a rejoin within KeepFor seconds, like the AFK rejoin, keeps it). Free; nothing is bought.
	HuzzServer/PlaytimeService counts it (player attributes HuzzPlayStacks and HuzzPlayNextAt, the server time of the
	next step, nil while AFK or at the top); RoundService adds it to the game pay; Screens/LobbyHud shows the tag.
	Kid-safe: the clock shown is the real one.
]]
local Playtime = {
	Every = 300, -- seconds of play for each step (5 minutes)
	Step = 0.10, -- +10% coins a step
	Max = 10, -- at most +100% (50 minutes of play)
	KeepFor = 120, -- seconds: back in the same server within this keeps your steps
}

-- The game pay with `stacks` steps on top (whole coins).
function Playtime.coins(amount: number, stacks: number?): number
	local n = math.clamp(math.floor(stacks or 0), 0, Playtime.Max)
	return math.floor(amount * (1 + Playtime.Step * n) + 0.5)
end

-- "+30% COINS" for the HUD.
function Playtime.tag(stacks: number): string
	return string.format("+%d%% COINS", math.floor(math.clamp(stacks, 0, Playtime.Max) * Playtime.Step * 100 + 0.5))
end

return Playtime
