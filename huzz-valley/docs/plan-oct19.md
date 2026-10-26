# Plan: the owner's big list (Oct 19, 14:45 and 15:00)

Every item from his two messages, grouped into four batches that run side by side. Each batch is checked
frame by frame against his pictures, gets a harsh critic pass, then is merged, rebuilt and sent as one place.
Where his words left a choice open, the default we picked is written in *italics*; he can change any of them.

## 1. Controls and feel
- Smoother animations everywhere (blend times, no pops).
- Shift lock: only the body moves with W A S D, the head doesn't. *The head stops following the camera in shift lock.*
- Huss: quicker and smoother, ready again after 2 seconds.
- Speed goes up a very tiny bit every round. *+2% a round, at most +20%.*
- You only start moving once your feet touch the floor. *No walking in the air after a spawn or drop.*
- Player to player touch way more accurate (catch hitboxes match the bodies).
- Going AFK: rejoin automatically just before Roblox would kick you.

## 2. Catcher and runner abilities, and the ability HUD
- Simple names (no "Rizz Rush"). *Shield, Speed Boost, Bear Trap, Slow Wave.*
- Knife: one second to charge between stabs, shown on the bar.
- Bear Trap: thrown in front of you with a small throw animation (replaces Love Trap).
- Catcher dive: Space dives forward and catches who it reaches; after it you're stunned for 2 seconds.
- Runner abilities: Invisible, Glitchy, Body Double. *One ability on Q, like his picture.*
- Speed Boost only for the person carrying the girl.
- His pictures b and c: the ability card above a clean dash bar that shows the recharge ("CATCH READY", "SPACE · DASH").
- Heartbeat: when a catcher gets close the screen edges pulse red with a heartbeat sound (calm, never more than one flash a second).

## 3. Lobby, spawns and girls
- One lobby instead of one per map.
- Spawns on open ground, never inside objects, with barriers around the spawn.
- Catchers spawn in the middle.
- Everyone can see the girls (not just their owner).
- Nice girl animation when she's picked up.
- Synced dancing (dance together in time).

## 4. Rewards and screens
- Lower spin prices. *About half.*
- Crates give knives (his Halloween ones too) and dances.
- Easy daily quests like his picture d: new ones every day, recycled. *Two daily quests plus one that changes every 2 hours. No Robux refresh or auto-complete (paying to skip is left out unless he asks).*
- Winner page like his picture a: who won, MVP / Survival / Catches tabs, top 3 with avatars, XP gained, level bar.
- Friend rewards: a friend knife for bringing a friend, and +10% coins while a friend is in your server. *You get the friend knife when a friend joins your server; the knife model is our pick from his sets until he names one.*
- Prestige: with more than one of the same girl, a PRESTIGE button gives her cooler effects. *Each duplicate can raise her prestige level, up to 3.*
- Icons and pictures appear everywhere in the UI. *First we find out why they're missing in his Studio (most likely the same "Allow Mesh / Image APIs" switch, or pictures not uploaded yet) and fix what code can fix.*

## Notes for CLAUDE.md
Each batch writes what it learned into its topic file in `docs/notes/` in the same commit, so the next session
starts from it.
