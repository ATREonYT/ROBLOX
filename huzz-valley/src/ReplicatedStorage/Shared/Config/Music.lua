-- The background songs (Gameplay/Music). The owner keeps his songs in his place at SoundService > Music >
-- Background_Music (Bg1 ... Bg9) and Important_Song_Actions > Winner_Music_Showcase, and those are used when they're
-- there. The place file we build doesn't have them, so their IDs can go here too ("rbxassetid://123..."): the owner
-- sends them (each Sound's SoundId in Properties). Never invent one.
return {
	Background = {}, -- e.g. { "rbxassetid://111", "rbxassetid://222" }
	Winner = "", -- the song over the win
	Volume = 0.3, -- each song before the sliders: Master 80% x Music 60% makes it about 0.14, under the effects
}
