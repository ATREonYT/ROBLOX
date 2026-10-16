-- Animation IDs ("rbxassetid://123"). Empty = keep Roblox's defaults.
-- Walk/Run/Idle/Jump replace the default Animate script's animations on every
-- player's own character, so Huss Valley walks and huss moves drop straight in.
return {
	Walk = "",
	Run = "",
	Idle = "",
	Jump = "",
	Fall = "",

	-- Optional: an upper-body carry animation (Action priority, looped). When
	-- set, it replaces the scripted arm pose; bob, sway and pickup stay scripted.
	CarryArms = "",

	-- The catcher's stab and the carrier's huss move. Empty = the built-in placeholder moves
	-- (Shared/StabMotion, Shared/CarryMotion). With an ID, that animation plays instead (the
	-- girl's throw and catch stay scripted). Make them Action priority.
	Stab = "",
	Huss = "",

	-- The girl walking after a catcher. Set GirlWalk (and ideally GirlRun and GirlIdle)
	-- and she plays these instead of the built-in walk; they're sped up or slowed down
	-- to match how fast she's moving. Speed* = the speed each was made for (studs/s).
	GirlIdle = "",
	GirlWalk = "",
	GirlRun = "",
	GirlWalkSpeed = 8,
	GirlRunSpeed = 18,
}
