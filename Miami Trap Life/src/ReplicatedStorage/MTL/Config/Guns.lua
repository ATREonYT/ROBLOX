--!strict
-- Guns (Piece 5). Every gun number lives here; GunService (server), GunController (client) and Rules/GunRules
-- read it. Research: [[Gun Mechanics]]. Units: degrees for angles, studs for distance, seconds for time.
--
-- A gun:
--   Display        name on the HUD / shop
--   Model          ReplicatedStorage.MTL_Assets.Guns.<Model> if Alex drops a model there (needs a part "Handle"
--                  and an Attachment "Muzzle"; optional Attachment "Grip" = where the hand holds it).
--                  Missing -> a placeholder is built from parts (Services/GunModels.lua).
--   Slot           "Secondary" (holstered on the hip) | "Primary" (slung on the back)
--   TwoHanded      left arm reaches for the gun too
--   Damage         per bullet (per pellet for shotguns) · HeadMult on the Head part
--   RPM, Auto      fire rate; Auto = hold to keep firing
--   Pellets        bullets per shot (shotgun) · PelletSpread = extra cone for pellets
--   Mag, Ammo      magazine size, ammo type (shared pools: Pistol + Uzi both use "9mm")
--   Reload, EquipTime
--   Range          max distance · FalloffStart..FalloffEnd: damage goes linearly from 100% to FalloffMin
--   Spread         cone half-angle: Hip / Aim base, + Move while walking, + Air while jumping,
--                  + Bloom per shot (up to MaxBloom), shrinking by Recover degrees per second
--   Recoil         Up (deg per shot, camera), Side (+- deg), Return (share of the kick that springs back),
--                  Kick (studs the gun model snaps back), KickRot (deg the gun model tips up)
--   AimFov         camera field of view while aiming · TracerEvery: draw a tracer every Nth shot
--   Price, Level   the Plug app (criminal path only) · Sounds: per-gun overrides of Guns.Sounds
--   Shake, ShakeCap camera trauma each shot adds (Guns.Feel), and the most your own shots can build up to
local Guns = {}

Guns.Order = { "Pistol", "Uzi", "Shotgun", "Revolver", "AK" } -- shop + weapon bar order

Guns.Defs = {
	Pistol = {
		Display = "9mm Pistol",
		Model = "Pistol",
		Sounds = { Fire = "rbxassetid://9117399569" }, -- Pistol Single Shots 1 (PSE)
		Slot = "Secondary",
		TwoHanded = true,
		Damage = 22,
		HeadMult = 1.8,
		RPM = 380,
		Auto = false,
		Pellets = 1,
		Mag = 12,
		Ammo = "9mm",
		Reload = 1.5,
		EquipTime = 0.3,
		Range = 300,
		FalloffStart = 70,
		FalloffEnd = 220,
		FalloffMin = 0.6,
		Spread = { Hip = 2.4, Aim = 0.35, Move = 1.2, Air = 4, Bloom = 0.55, MaxBloom = 3, Recover = 7 },
		Recoil = { Up = 1.3, Side = 0.35, Return = 0.75, Kick = 0.18, KickRot = 8 },
		AimFov = 55,
		Shake = 0.12, ShakeCap = 0.2,
		TracerEvery = 1,
		Price = 1200,
		Level = 5,
	},
	Uzi = {
		Display = "Uzi",
		Model = "Uzi",
		Sounds = { Fire = "rbxassetid://9114729252" }, -- Gun Single Shots 11, Mini Uzi (PSE)
		Slot = "Secondary",
		TwoHanded = true,
		Damage = 13,
		HeadMult = 1.6,
		RPM = 780,
		Auto = true,
		Pellets = 1,
		Mag = 30,
		Ammo = "9mm",
		Reload = 1.9,
		EquipTime = 0.35,
		Range = 220,
		FalloffStart = 40,
		FalloffEnd = 140,
		FalloffMin = 0.5,
		Spread = { Hip = 3.2, Aim = 1.1, Move = 1.2, Air = 4, Bloom = 0.22, MaxBloom = 3.5, Recover = 9 },
		Recoil = { Up = 0.55, Side = 0.45, Return = 0.6, Kick = 0.1, KickRot = 4 },
		AimFov = 58,
		Shake = 0.08, ShakeCap = 0.2,
		TracerEvery = 3,
		Price = 3500,
		Level = 8,
	},
	Shotgun = {
		Display = "Pump Shotgun",
		Model = "Shotgun",
		Sounds = { Fire = "rbxassetid://132711300701696", Pump = "rbxassetid://113837896417526" }, -- community uploads; Pump plays with the pump animation
		Slot = "Primary",
		TwoHanded = true,
		Damage = 11,
		HeadMult = 1.4,
		RPM = 70,
		Auto = false,
		Pellets = 8,
		PelletSpread = 4.5,
		Mag = 6,
		Ammo = "12g",
		Reload = 2.6,
		EquipTime = 0.45,
		Range = 90,
		FalloffStart = 14,
		FalloffEnd = 45,
		FalloffMin = 0.25,
		Spread = { Hip = 1.5, Aim = 0.6, Move = 0.8, Air = 3, Bloom = 0, MaxBloom = 0, Recover = 10 },
		Recoil = { Up = 4.5, Side = 0.8, Return = 0.7, Kick = 0.35, KickRot = 14 },
		AimFov = 60,
		Shake = 0.35, ShakeCap = 0.35,
		TracerEvery = 1,
		Price = 2800,
		Level = 10,
	},
	Revolver = {
		Display = ".357 Revolver",
		Model = "Revolver",
		Sounds = { Fire = "rbxassetid://9117402631" }, -- Pistol Single Shots 5, .45 (PSE): heavier crack for the revolver
		Slot = "Secondary",
		TwoHanded = true,
		Damage = 45,
		HeadMult = 1.8,
		RPM = 120,
		Auto = false,
		Pellets = 1,
		Mag = 6,
		Ammo = ".357",
		Reload = 2.2,
		EquipTime = 0.35,
		Range = 320,
		FalloffStart = 90,
		FalloffEnd = 260,
		FalloffMin = 0.65,
		Spread = { Hip = 2.6, Aim = 0.25, Move = 1.4, Air = 4, Bloom = 1.4, MaxBloom = 3, Recover = 5 },
		Recoil = { Up = 3.2, Side = 0.6, Return = 0.8, Kick = 0.25, KickRot = 16 },
		AimFov = 52,
		Shake = 0.2, ShakeCap = 0.3,
		TracerEvery = 1,
		Price = 4500,
		Level = 12,
	},
	AK = {
		Display = "AK",
		Model = "AK",
		Sounds = { Fire = "rbxassetid://108908168277265" }, -- Realistic AK Gunshot (community upload). TODO(Alex): swap if you prefer another
		Slot = "Primary",
		TwoHanded = true,
		Damage = 27,
		HeadMult = 1.7,
		RPM = 600,
		Auto = true,
		Pellets = 1,
		Mag = 30,
		Ammo = "7.62",
		Reload = 2.4,
		EquipTime = 0.5,
		Range = 400,
		FalloffStart = 110,
		FalloffEnd = 320,
		FalloffMin = 0.7,
		Spread = { Hip = 3.6, Aim = 0.5, Move = 1.6, Air = 5, Bloom = 0.3, MaxBloom = 3, Recover = 6 },
		Recoil = { Up = 0.95, Side = 0.5, Return = 0.55, Kick = 0.14, KickRot = 5 },
		AimFov = 52,
		Shake = 0.11, ShakeCap = 0.25,
		TracerEvery = 3,
		Price = 9000,
		Level = 20,
	},
}

-- Ammo packs in the Plug app: Count rounds for Price.
Guns.Ammo = {
	["9mm"] = { Display = "9mm", Count = 30, Price = 60, Max = 360 },
	["12g"] = { Display = "12 gauge", Count = 12, Price = 80, Max = 96 },
	[".357"] = { Display = ".357", Count = 18, Price = 90, Max = 120 },
	["7.62"] = { Display = "7.62", Count = 30, Price = 150, Max = 300 },
}

-- The crew hands you a real piece after the first job (Story thread agreed). GrantOnStage = "" turns it off.
Guns.Starter = { GrantOnStage = "MissionDone", Gun = "Pistol", Ammo = 24 }

-- Modes. "Live" = a normal gun. "Intimidate" = a story/mission gun: equips on any path and inside safe zones,
-- shots never damage anyone (they still make noise and fire GunService.Fired).
Guns.Modes = { Live = true, Intimidate = true }

-- Safe zones from config (positions from Config/Locations so they work before the map streams in).
-- Plus every part tagged MTL_SafeZone (the inside of its box counts). Height is checked within +-Height.
-- Being on a job shift also counts as safe (Master Plan: "job interiors while on shift").
Guns.SafeZones = {
	{ id = "SpawnLot", location = "Spawn", radius = 45, height = 30 },
	{ id = "FoodMart", location = "FoodMart", field = "Inside", radius = 20, height = 20 },
	{ id = "BurgerShack", location = "BurgerShack", field = "Inside", radius = 20, height = 20 },
	{ id = "WestsideAuto", location = "WestsideAuto", field = "Inside", radius = 22, height = 20 },
	{ id = "EndsFlat", location = "EndsFlat", field = "Door", radius = 14, height = 20 },
}

Guns.Tuning = {
	-- camera / feel (client)
	BaseFov = 70,
	AimCameraOffset = Vector3.new(1.75, 0.45, 0), -- over the right shoulder while aiming
	AimTween = 0.15,
	AimWalkSpeedMult = 0.6,
	HipTurnSeconds = 0.6, -- after a hip-fire shot the character keeps facing the aim for this long
	RecoilStiffness = 420, -- camera spring (higher = snappier)
	RecoilDamping = 0.8, -- share of critical damping
	KickRecover = 14, -- how fast the gun model returns after the kick (per second)
	ReducedMotionScale = 0.4, -- Settings.ReducedMotion scales camera kick + shake
	SemiBuffer = 0.12, -- a semi-auto click this early before the gun is ready still fires when it is
	AutoReloadDelay = 0.3, -- empty mag + reserve -> reload starts by itself
	LowReadyPitch = -30, -- arms hold the gun pointed down this much while not aiming
	AimAssistDegrees = 5, -- touch + gamepad only: starting to aim nudges the camera onto a valid target this close
	AimAssistRange = 120,
	AimAssistSeconds = 0.12,
	-- network
	AimSendHz = 10, -- GunAim updates (aim flag, pitch, intimidate target)
	-- server validation
	FireRateTolerance = 0.85, -- allow shots 15% faster than RPM (stops lag eating shots)
	FireBurst = 2, -- shots that may arrive bunched together
	OriginTolerance = 7, -- studs between the claimed muzzle and the head
	AngleTolerance = 4, -- degrees beyond the gun's widest cone a hit may sit from the aim direction
	BodyTolerance = 3.5, -- studs outside a body part's box a hit may land (lag)
	HeadTolerance = 1.6,
	HistoryHz = 20, -- lag compensation: character positions kept per second
	HistorySeconds = 1,
	MaxRewind = 0.4, -- never look further back than this
	RewindWindow = 0.25, -- check every sample from (shot time - this) up to now
	ReloadGrace = 0.9, -- the server accepts shots after 90% of the reload time
	EquipGrace = 0.8,
	FightSeconds = 20, -- "in a fight" after shooting at / being hit by a player (blocks path switch + clock-in)
	IntimidateRange = 30,
	IntimidateFacing = 40, -- degrees between where the character faces and the target
	IntimidatePing = 0.25, -- Intimidating signal rate
	SafeCheckSeconds = 0.5,
	-- effects (client)
	FxRange = 700, -- other players further than this don't get your shot effects
	TracerSpeed = 1400, -- studs per second
	TracerLength = 7,
	TracerWidth = 0.07,
	MaxImpacts = 40, -- bullet holes kept
	ImpactSeconds = 12,
	HitmarkerSeconds = 0.15,
	HurtSeconds = 0.6,
	LowHealth = 45, -- below this the screen desaturates
}

-- Feel (client, Controllers/CamShake). One trauma value: things add to it, it fades by Decay per second, and the
-- camera shakes by trauma^2 (smooth noise). Max* = degrees at trauma 1. While aiming the shake is scaled by
-- tan(FOV/2) / tan(35 deg). Settings.Shake (0-100, default 100) and Settings.ReducedMotion (x ReducedMotion) scale it.
-- HitStop: the victim's animation freezes on your screen when a hit lands; Cap seconds at most in any Window.
Guns.Feel = {
	Hurt = 0.35, -- you got hit (Finisher tier)
	Downed = 0.6, -- you went down
	Finish = 0.35, -- you finished someone
	Decay = 1.1,
	MaxPitch = 7,
	MaxYaw = 5,
	MaxRoll = 6,
	Frequency = 16, -- noise speed
	ReducedMotion = 0.4,
	HitStop = { Hit = 0.04, Head = 0.06, Kill = 0.09, Cap = 0.14, Window = 0.6 },
}

-- Downed -> finish (Services/GunDowned + Controllers/DownedPose). A gun shot that would kill a player downs them:
-- they crawl, can't shoot or draw, and bleed out after BleedSeconds. Anyone allowed to shoot them can hold E
-- (FinishHold) within FinishRange to finish them; only a finish counts as a kill (GunService.Killed).
Guns.Downed = {
	Enabled = true,
	BleedSeconds = 20,
	FinishHold = 1.5,
	FinishRange = 8,
	CrawlSpeed = 3.5, -- studs per second
	Health = 1, -- health kept while down
	RespawnAfter = 2, -- the death card's Respawn button works after this many seconds
}

-- Sound slots. "" = silent. Built-in placeholders only; these are NOT good gun sounds.
-- TODO(Alex sfx): upload real shot / tail / reload sounds (or pick licensed ones from the Creator Store) and paste
-- the ids here or per gun (Defs.<Gun>.Sounds = { Fire = "rbxassetid://..." }).
Guns.Sounds = {
	Fire = "rbxassetid://9117399569", -- "Pistol Single Shots 1" (ProSoundEffects, Creator Store), checked 2026-11-02. TODO(Alex): swap if you prefer another
	Tail = "", -- distant echo layer, long roll-off
	Empty = "rbxassetid://117629133235583", -- "Dry Fire" (ChipTheTrainer2, community upload)
	ReloadStart = "rbxassetid://9113104176", -- Ammo Magazine 1 (PSE): mag out
	ReloadEnd = "rbxassetid://9113104337", -- Ammo Magazine 3 (PSE): mag in
	Equip = "rbxassetid://9117396530", -- Pistol Handling 1 (PSE)
	Hit = "rbxassetid://9113502506", -- Body Hits 8 (PSE): soft thud when the server confirms a hit
	Kill = "rbxassetid://9116329927", -- Low Impacts 2 (PSE): low thud on a kill
	Hurt = "",
}

-- Input. Gamepad: R2 fire, L2 aim, B reload, Y next gun (after the last gun = holster). DPadUp stays the phone.
Guns.Keys = {
	Reload = { Enum.KeyCode.R, Enum.KeyCode.ButtonB },
	Cycle = { Enum.KeyCode.ButtonY },
	Holster = { Enum.KeyCode.X, Enum.KeyCode.One }, -- 1 = the fists slot on the HUD hotbar
	Slots = { Enum.KeyCode.Two, Enum.KeyCode.Three, Enum.KeyCode.Four, Enum.KeyCode.Five, Enum.KeyCode.Six }, -- hotbar slots 2-6
	FireGamepad = Enum.KeyCode.ButtonR2,
	AimGamepad = Enum.KeyCode.ButtonL2,
}

return Guns
