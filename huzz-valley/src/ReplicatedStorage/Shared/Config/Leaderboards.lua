-- The lobby leaderboards (owner, Oct 18: "make the leaderboards just like in the video i sent you from the game,
-- make them follow your character"). Huss Valley's boards, one to one: tall see-through mauve slabs with studs, a
-- big white title top-left, "GLOBAL · ALL TIME · TOP 50", then rows of headshot, "#1 name" and the value.
-- Measured from the owner's clip (rec1018c lb.mov, frames lb_f1/lb_f2): see Shared/LeaderboardLook for the layout.
--
-- Plain numbers and strings only (no Roblox types), so the place build (tools/place/build_yours.luau) can read it.
--   Stat    the saved number it ranks (Shared/LeaderboardRules.values reads it from the save)
--   Format  "Level" = "LEVEL 402"; "Trophy" = "2611" + the trophy icon; "Unit" = "33.5K CATCHES" (Unit after)
local Leaderboards = {}

Leaderboards.Boards = {
	{ Stat = "Level", Title = "HIGHEST LEVEL", Format = "Level" },
	{ Stat = "Wins", Title = "MOST WINS", Format = "Trophy" },
	{ Stat = "Girls", Title = "MOST GIRLS", Format = "Unit", Unit = "GIRLS" }, -- girls collected (the Index)
	{ Stat = "Catches", Title = "MOST CATCHES", Format = "Unit", Unit = "CATCHES" },
	{ Stat = "Rescues", Title = "MOST RESCUES", Format = "Unit", Unit = "RESCUES" },
}
-- (in this order onto the owner's grey podiums first: his lobbies have three, east of the girls; the rest stand
-- along the back edge. Shared/LeaderboardLook.layout)

Leaderboards.Subtitle = "GLOBAL · ALL TIME · TOP 50"
Leaderboards.Top = 50 -- rows kept (the board shows 12 and scrolls, like theirs)
Leaderboards.Shown = 12

-- Saving to Roblox's leaderboards (OrderedDataStores, one per stat). Live game only: in Studio saves are a Mock
-- (progress resets on Stop), so the boards there show the players in this server instead.
Leaderboards.StorePrefix = "HuzzValley_LB_v1_"
Leaderboards.WriteEvery = 90 -- seconds between saving each player's numbers (and once more when they leave)
Leaderboards.ReadEvery = 60 -- seconds between reading each board's top 50
Leaderboards.PublishEvery = 15 -- seconds between sending the boards to everyone (live numbers of players here)
Leaderboards.StudioPublishEvery = 5

-- Turning to face you (each screen turns its own copy; nothing is sent).
Leaderboards.TurnRate = 2.2 -- how fast a board catches up with you (higher = less lag)
Leaderboards.TurnRange = 260 -- boards further away than this stop turning

-- The slab (studs). 14 x 18 measured from the clip: one Roblox stud per stud cell, 14 across and 18 down.
Leaderboards.Size = { X = 14, Y = 18, Z = 0.6 }
Leaderboards.Lift = 1.2 -- the slab's bottom over the ground (it stands on a low stone base)

return Leaderboards
