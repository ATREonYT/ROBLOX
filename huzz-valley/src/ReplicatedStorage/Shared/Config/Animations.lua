-- Published animation IDs ("rbxassetid://123"). The owner's own animations are already in the game as raw
-- KeyframeSequences (ReplicatedStorage.HuzzAnimations, from the movement pack and the dance file; see
-- Shared/AnimationLibrary): Studio plays those directly, so these can stay empty while testing in Studio. For the
-- live game, publish them once (tools/studio/publish-animations.lua prints this file filled in).
-- Walk/Run/Idle/Jump/Fall/Climb replace the default Animate script's animations on your own character (they
-- replicate): Walk at low speed blending into Run as you speed up (Gameplay/Sprint ramps the speed while you hold
-- W). Dash is the huss dash (Space), played over the run.
return {
	Walk = "",
	Run = "",
	Idle = "",
	Jump = "",
	Fall = "",
	Climb = "",
	Dash = "",

	-- Optional: an upper-body carry animation (Action priority, looped). When
	-- set, it replaces the scripted arm pose; bob, sway and pickup stay scripted.
	CarryArms = "",

	-- The catcher's stab. Empty = the built-in scripted move (Shared/StabMotion). Make it Action priority.
	Stab = "",

	-- The girl walking after a catcher. Set GirlWalk (and ideally GirlRun and GirlIdle)
	-- and she plays these instead of the built-in walk; they're sped up or slowed down
	-- to match how fast she's moving. Speed* = the speed each was made for (studs/s).
	GirlIdle = "",
	GirlWalk = "",
	GirlRun = "",
	GirlWalkSpeed = 8,
	GirlRunSpeed = 18,
}
