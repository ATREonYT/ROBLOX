--!strict
-- Every sound in the game, in one place. Defaults use rbxasset:// paths that
-- ship inside every Roblox client, so they always play with zero setup.
-- To upgrade any of them later: upload/pick a sound in the Creator Store and
-- replace the string with "rbxassetid://<id>" — nothing else to change.

export type SoundDef = {
	SoundId: string,
	Volume: number,
	PlaybackSpeed: number?, -- optional pitch tweak
}

local Sounds: { [string]: SoundDef } = {
	Click = { SoundId = "rbxasset://sounds/button-09.mp3", Volume = 0.5 },
	Crit = { SoundId = "rbxasset://sounds/button-10.mp3", Volume = 0.7, PlaybackSpeed = 1.2 },
	BigCrit = { SoundId = "rbxasset://sounds/short_spring.mp3", Volume = 0.8 },
	RankUp = { SoundId = "rbxasset://sounds/victory.wav", Volume = 0.9 },
	RivalDefeated = { SoundId = "rbxasset://sounds/impact_generic_large_water_1.mp3", Volume = 0.8 },
	BossDefeated = { SoundId = "rbxasset://sounds/victory.wav", Volume = 1, PlaybackSpeed = 0.9 },
	Purchase = { SoundId = "rbxasset://sounds/electronicpingshort.wav", Volume = 0.7 },
	Error = { SoundId = "rbxasset://sounds/pause.mp3", Volume = 0.6 },
	Restructure = { SoundId = "rbxasset://sounds/collide.wav", Volume = 0.9 },
	InternHired = { SoundId = "rbxasset://sounds/bell.wav", Volume = 0.8 },
	Teleport = { SoundId = "rbxasset://sounds/swoosh.wav", Volume = 0.7 },
	UiOpen = { SoundId = "rbxasset://sounds/swoosh.wav", Volume = 0.4, PlaybackSpeed = 1.4 },
	Typing = { SoundId = "rbxasset://sounds/button-09.mp3", Volume = 0.15, PlaybackSpeed = 1.6 },
}

return Sounds
