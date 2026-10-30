--!strict
-- The characters' moves (Oct 27, the owner: "add animations to all of the characters", with their R15 movement pack).
-- Roblox plays an animation only for the game whose owner uploaded it, so every id here is one the owner uploaded from
-- the pack (Studio: open the pack, the rig's AnimSaves, right-click a move, Save to Roblox; the number it gives goes
-- here). An empty one keeps Roblox's own move. The pack itself is licensed: it never goes in this (public) repo.
-- Who uses them (Shared/AnimationRules): every player (HoodServer/CharacterAnimations sets the character's Animate
-- script), and the people in the worlds that walk or stand about.
return {
	Idle = '',
	Walk = '',
	Run = '',
	Jump = '',
	Fall = '',
	Climb = '',
	Swim = '',
	-- (Oct 28, the feel round) your fight moves: a swing at a goon in contact plays Punch, Punch, Kick in turn
	-- (CharMotion.melee); while one is empty, the drawn swing (CharMotion.Swings) stands in
	Punch = '',
	Kick = '',
}
