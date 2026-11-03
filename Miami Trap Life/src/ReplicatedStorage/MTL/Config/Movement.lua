--!strict
-- Moment-to-moment movement feel (client, Controllers/MovementController.lua). Why these numbers:
-- Research/Movement and Game Feel.md. Tune by feel; nothing here is saved or checked by the server.
local Movement = {}

-- speed (studs/s). MovementController is the only client script that writes Humanoid.WalkSpeed.
Movement.WalkSpeed = 16 -- Roblox default: every map, door and prompt distance was built around it
Movement.SprintSpeed = 24 -- x1.5: clearly faster, still lands inside the job sites' prompt ranges
Movement.EaseUpSeconds = 0.25 -- walk -> sprint reaches ~95% in this long (no snap)
Movement.EaseDownSeconds = 0.15 -- sprint -> walk (stopping should feel quicker than starting)

-- input
Movement.SprintKeys = { Enum.KeyCode.LeftShift } -- PC: hold. StarterPlayer.EnableMouseLockOption is off so Shift is free
Movement.SprintToggleKeys = { Enum.KeyCode.ButtonL3 } -- gamepad: click the left stick to toggle
Movement.ToggleOffIdleSeconds = 0.35 -- a toggled sprint (L3 / touch) switches off after standing still this long
Movement.TouchButton = { title = "RUN", position = UDim2.new(1, -150, 1, -100), gap = 10 } -- start spot; then moved to sit `gap` px above the jump button

-- camera (all off in first person, cutscenes, non-Custom cameras and with Settings.ReducedMotion)
Movement.SprintFov = 7 -- FOV added while sprinting (degrees), on top of whatever FOV the game set
Movement.FovEaseSeconds = 0.3
Movement.BobPitch = 0.35 -- sprint head bob (degrees, at full sprint)
Movement.BobRoll = 0.25 -- sprint sway (degrees)
Movement.BobStepsPerStud = 0.18 -- bob frequency follows ground speed (steps per stud travelled)
Movement.StrafeRoll = 1.25 -- camera roll at full speed sideways (degrees)
Movement.LandDipMax = 2.5 -- landing dip (degrees of pitch down) at LandDipFallSpeed
Movement.LandDipDrop = 0.35 -- and this many studs down
Movement.LandDipMinFallSpeed = 18 -- falls slower than this (a curb, a normal jump ~50 down) do nothing much
Movement.LandDipFallSpeed = 90

-- character lean (R15 LowerTorso.Root / R6 RootJoint C0, local only; pivots at the feet)
Movement.SprintLean = 5 -- forward lean at full sprint (degrees)
Movement.TurnLean = 6 -- side lean into a fast turn (degrees, max)
Movement.TurnLeanRate = 7 -- yaw rate (rad/s) that gives the full side lean
Movement.LeanStiffness = 90 -- spring (higher = snappier)
Movement.LeanDamping = 0.85 -- share of critical damping

-- jumping
Movement.JumpCooldown = 0.3 -- seconds after landing before the next jump (no bunny-hop spam)

-- "Juice" on big moments (Controllers/Juice.lua). hitStop freezes your own character's animations for a beat;
-- punch = camera pitch kick (degrees) + FOV pop (degrees), both spring back. ReducedMotion: no FOV pop, pitch x0.4.
Movement.Juice = {
	Perfect = { hitStop = 0.04, pitch = 0.6, fov = -1.5 }, -- a PERFECT job task: small "snap" toward the work
	Kill = { hitStop = 0.05, pitch = 1.2, fov = -2.5 }, -- a server-confirmed gun kill
	Prompt = { pitch = 0.25 }, -- any proximity prompt you complete
}
-- Getting dropped (Controllers/DeathController.lua): grade + blur in, a slow push-in, the card after a beat.
Movement.Dropped = {
	FadeSeconds = 0.8, -- colour drains over this
	Saturation = -0.85,
	Contrast = 0.12,
	Brightness = -0.04,
	Blur = 6,
	PushFov = 9, -- the "slow-mo" push-in (degrees narrower)
	PushSeconds = 2.2,
	CardDelay = 0.6, -- seconds before the card rises (let the moment land first)
}
-- Proximity prompts (Controllers/InteractFX.lua). Rule for whoever makes a prompt: tap actions (doors, shop, start
-- job, grab) use HoldDuration 0; only hold where holding IS the action (car seat 1 s, "hold to grab the cash").
Movement.PromptSound = "PromptDone" -- Theme.Sfx name played on every completed prompt

-- Stride sync (Controllers/StrideController.lua): the walk/run animations of whatever avatar pack the player has are
-- re-timed every frame so the planted foot stays still on the ground (no foot sliding), and blended walk -> run by
-- ground speed instead of switching. Why it's a feedback loop: Research/Movement and Game Feel.md.
Movement.Stride = {
	BlendStart = 16, -- at/below walking speed (studs/s): all walk animation (carry 14 too)
	BlendEnd = 23, -- above this: all run animation (sprint is 24)
	MinSpeed = 2.5, -- slower than this: Roblox's Animate keeps control (idle / stop / start)
	MinRate = 0.35, -- playback-rate clamp
	MaxRate = 2.4,
	Memory = 3, -- seconds of foot samples a learned clip speed averages over (higher = steadier, slower to re-learn)
	FacingShare = 0.7, -- only learn while moving mostly where the body faces (not strafing while aiming)
	WeightEase = 0.12, -- seconds for the walk/run weights to follow the speed
	MinStanceFrames = 4, -- a foot contact shorter than this (frames) is a stumble/transition, not a step: not learned
}

-- Footsteps: the default Roblox character sounds (PlayerScripts.RbxCharacterSounds) already play steps and
-- landings in this place, so nothing extra here. TODO(Alex sfx): custom surface footsteps would go in Theme.Sfx. The
-- 2026-11-02 Creator Store search found no licensed (ProSoundEffects) shoe footsteps, only sounds ripped from other
-- games, so none are wired. StrideController knows the exact plant moments if real ones are uploaded later.

return Movement
