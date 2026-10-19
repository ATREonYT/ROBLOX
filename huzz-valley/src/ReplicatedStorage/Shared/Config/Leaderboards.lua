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

-- Turning to face you in real time (owner, Oct 18: first "make the leaderboards move smoothly", then "make it follow
-- me in real time, not adjust after i move"; Shared/LeaderboardRules aimSmooth / turn). Each screen turns its own copy,
-- never into his build: it first measures how far each board can turn each way (LeaderboardRules.room).
Leaderboards.TurnMax = 75 -- degrees either way from the way the board was placed, never more (never edge-on, never spins)
Leaderboards.TurnBehind = 120 -- degrees off its front: further round (behind it) it eases back, home when you're straight behind
Leaderboards.TurnRate = 20 -- how fast it catches up with you (20 = 63% in 0.05 s: it moves as you move, no wait)
Leaderboards.TurnSpeedMax = 300 -- degrees a second, never faster (running past at 6 studs is ~150, a huss close by ~300;
-- a respawn's 75 degree swing takes a quarter second instead of jumping 37 degrees in one frame at 30 fps)
Leaderboards.TurnRange = 120 -- studs: up to here it faces you (Oct 19: 90 left MOST CATCHES looking away from the spawn, 114 studs off)
Leaderboards.TurnFade = 20 -- studs past TurnRange over which it eases home (no jump at the edge; the other lobbies are 600+ away)
Leaderboards.TurnStep = 3 -- degrees: how finely each screen checks how far a board can turn before it cuts into his build

-- The slab (studs). 14 x 18 measured from the clip: one Roblox stud per stud cell, 14 across and 18 down.
Leaderboards.Size = { X = 14, Y = 18, Z = 0.6 }
Leaderboards.Lift = 1.2 -- the slab's bottom over the ground (it stands on a low stone base)

return Leaderboards
