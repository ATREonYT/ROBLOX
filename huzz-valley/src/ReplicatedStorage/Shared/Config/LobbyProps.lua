--[[
	The owner's five lobby props on the round pads at the front of every lobby copy (owner, Oct 18: "start working on
	implementing these objects into the lobby on top of the already placed circles. Give it some VFX and make it look
	good just like in the pictures"; his models: design/lobby/Lobby_Props.glb; the pictures:
	design/lobby/ref-shop-like-reward.png, ref-halloween-shop.png: each prop floats over a grey pad with a big bold
	coloured title over it and a glow round it).
	HuzzServer/LobbyPropService puts them on the pads (Shared/LobbyLayout.propSpots); Gameplay/LobbyProps makes them
	float, turn and open their menu. His real meshes come from ServerStorage > HuzzLobbyProps (the SetupLobbyProps
	helper after File > Import 3D); until then each is built from plain parts in his colours
	(HuzzServer/LobbyPropShapes, baked by tools/props/bake_props.py).

	What each one does (only menus the game already has; nothing invented):
	  Shop_Stall          "SHOP"           opens the Shop.
	  Pumpkin_Patch_Chest "FREE SPIN"      opens Spin the Wheel (its real free spin every 15 minutes; odds and pity are
	                                       on that screen). The line under the title counts down to your next free spin.
	  Like_Reward_Gift    "LIKE THE GAME!" opens the LIKE THE GAME window (Screens/LikeGame, Oct 23 19:44): how to like
	                                       it on Roblox. Roblox can't tell a game who liked it, so there is no reward
	                                       to claim (rename it LIKE REWARD only once a real reward exists).
	  Witch_Brew_Cauldron "WITCH'S BREW"   opens the Shop at its crate (owner, Oct 19 17:41: "make a halloween shop when
	  Sweets_Treats_Coffin "SWEETS & TREATS" you press on one of the two crates"; Oct 20 14:31: one Shop, "all close to
	                                       eachother"): their crates and the best Halloween knives, for Aura or Robux,
	                                       are in the Shop's CRATES and KNIVES (Config/HalloweenShop, Screens/Shop).
	                                       Section = where the Shop scrolls to.
	Kid-safe: nothing flashes; the sparkles and the glow under each prop are steady (the glow breathes over 4 s).
]]
return {
	Folder = "HuzzLobbyProps", -- Workspace > HuzzLobbyProps (one LobbyProp model per pad) and ServerStorage > HuzzLobbyProps (his real models)
	Tag = "HuzzLobbyProp",
	-- the pads, by side: the side with three pads (by the podiums) and the side with two (by the spawn), each list
	-- from the pad nearest the middle of the plaza outwards
	ThreePads = { "Pumpkin_Patch_Chest", "Sweets_Treats_Coffin", "Witch_Brew_Cauldron" },
	TwoPads = { "Shop_Stall", "Like_Reward_Gift" },
	Hover = 1.3, -- studs between the pad's top and the prop's lowest point
	Bob = 0.35, -- studs up and down
	BobTime = 3.4, -- seconds for one bob
	TurnTime = 18, -- seconds for one slow full turn (0 = no turn)
	AnimateWithin = 200, -- studs: further away the props stand still (nobody sees them move)
	TitleFont = "FredokaOne", -- the rounded heavy letters of the reference's SHOP / LIKE REWARD
	TitleHeight = 1.25, -- studs: the letters' height a line (the reference's SHOP is about 1.3 on a 6.5 pad)
	TitleWidth = 12, -- studs: the most a title may spread (the pads on the three-pad side are 7 apart: keep titles short)
	LineHeight = 0.5, -- studs: the small line under a title
	TitleAbove = 0.8, -- studs between the prop's highest bob and the title
	TitleMaxDistance = 160,
	Light = { Brightness = 0.5, Range = 7 }, -- a faint light in its colour, kept on the prop and its pad (Oct 19 "even" lighting: 1.4 / 12 lit a pool on the floor)
	Sparkles = { Rate = 5, Lifetime = 1.6, Size = 0.32 }, -- calm: a few at a time, rising slowly
	-- A prop with Grow (the two Halloween stands, Oct 20 "bigger so they stand out more"): his pad under it is scaled
	-- Grow times (his model as it is, never redrawn), and so are its glow, light and title; its Scale is set bigger by
	-- hand. The bigger pad moves outward along its row (away from the middle of the plaza) just far enough to stay
	-- GrowGap studs clear of the pad before it (Shared/LobbyPropBuild.grow); nothing else moves. 1.5, not 1.6: at 1.6
	-- WITCH'S BREW's title would rise into the big tree's lowest branch, just in front of it (tests/LobbyLayout.spec).
	GrowGap = 0.75,
	Props = {
		Shop_Stall = {
			Title = "SHOP", Color = Color3.fromRGB(86, 226, 255), -- the reference's cyan
			Opens = "Shop", Action = "Open Shop",
			Scale = 1.65, -- 3.9 units wide -> 6.4 studs: as wide as his pad, like the reference's stall
			Glow = Color3.fromRGB(255, 176, 64), -- his lantern
		},
		Like_Reward_Gift = {
			Title = "LIKE THE GAME!", Color = Color3.fromRGB(110, 226, 72), -- the reference's green
			Opens = "LikeGame", Action = "Like the Game", -- (Oct 23 19:44: E opens Screens/LikeGame)
			Line = "Thumbs up on the game page!",
			Scale = 2.3,
			Glow = Color3.fromRGB(255, 240, 150), -- his sparkles
		},
		Pumpkin_Patch_Chest = {
			Title = "FREE SPIN", Color = Color3.fromRGB(255, 154, 40), -- pumpkin orange
			Opens = "SpinWheel", Action = "Spin the Wheel", Line = "FreeSpin", -- (the live countdown)
			Scale = 2.2,
			Glow = Color3.fromRGB(255, 196, 64), -- his jack-o'-lantern glow
		},
		Witch_Brew_Cauldron = {
			Title = "WITCH'S\nBREW", Color = Color3.fromRGB(196, 120, 255), -- potion purple (two lines: one would run into its neighbours' titles)
			Opens = "Shop", Section = "Witch", Action = "Halloween Shop",
			Scale = 3.75, -- 1.5 x the 2.5 it had (owner, Oct 20: "make the halloween shop objects bigger so they stand out more")
			Grow = 1.5, -- its pad (his, scaled), glow, light and title 1.5 x too (see GrowGap above)
			Glow = Color3.fromRGB(200, 106, 255), -- his potion
		},
		Sweets_Treats_Coffin = {
			Title = "SWEETS &\nTREATS", Color = Color3.fromRGB(255, 128, 196), -- candy pink
			Opens = "Shop", Section = "Sweets", Action = "Halloween Shop",
			Scale = 3.45, -- 1.5 x the 2.3 it had (Oct 20, as WITCH'S BREW)
			Grow = 1.5,
			Glow = Color3.fromRGB(255, 160, 220), -- his sugar glow
		},
	},
}
