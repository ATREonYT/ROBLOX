-- The background songs (Gameplay/Music). The owner keeps his songs in his place at SoundService > Music >
-- Background_Music (Bg1 ... Bg9) and Important_Song_Actions > Winner_Music_Showcase, and those are used when they're
-- there. The place file we build doesn't have them, so their IDs can go here too ("rbxassetid://123..."): the owner
-- sends them (each Sound's SoundId in Properties). Never invent one.
return {
	Background = { -- the owner's Bg1 to Bg9 (sent Oct 18)
		"rbxassetid://102270542050721",
		"rbxassetid://99935630619723",
		"rbxassetid://116195755650146",
		"rbxassetid://128154434538961",
		"rbxassetid://124776590493339",
		"rbxassetid://91360819145121",
		"rbxassetid://96102070260365",
		"rbxassetid://127307799919519",
		"rbxassetid://134132481305495",
	},
	Winner = "rbxassetid://108781345074821", -- the song over the win (the owner's Winner_Music_Showcase, sent Oct 18)
	-- Round phonk (owner, Oct 22 16:00): his two long tracks, played while you're in a round (Gameplay/Music). Their
	-- files (round-phonk-1.mp3, round-phonk-2.mp3) are in the project files, owner-audio-oct22, not the public repo:
	-- he uploads them (Creator Hub > Audio) and sends the IDs; until then the background plays on. Never invent one.
	Phonk = {
		"", -- round-phonk-1.mp3 (his 2026-10-22 18-04-39.mp3, 55 s)
		"", -- round-phonk-2.mp3 (his 2026-10-22 18-06-18.mp3, 57 s)
	},
	PhonkVolume = 0.35, -- before the sliders (Master 80% x Round Phonk 50% makes it about 0.14, like the background)
	Volume = 0.3, -- each song before the sliders: Master 80% x Music 60% makes it about 0.14, under the effects
}
