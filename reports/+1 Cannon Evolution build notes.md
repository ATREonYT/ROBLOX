# +1 Cannon Evolution: build notes (2026-10-29)

A Stone Skipping style +1 game with cannons. You train Power at the stations, walk into the Launch Zone, and your cannon fires a ball that skims down the water track through 15 areas. Distance pays Cash, Cash and Power buy rebirths, rebirths unlock new cannons, stations and worlds.

Code and setup: [[cannon-evolution/README|cannon-evolution/README.md]]. Reference images, the cannon GLB pack and the screen recordings are in `cannon-evolution/references/`.

## Files
- `src/shared/GameConfig.lua`: every number in the game (stations, launch physics, rebirth costs, upgrades, worlds, pets, eggs, cannons, gamepasses, products, codes).
- `src/server/GameServer.server.lua`: saving, training, launching, rebirths, eggs, purchases, and the tutorial guide character.
- `src/client/GameClient/`: one module per panel (HUD, Shop, Cannons, Pets, Rebirth, Worlds, Upgrades, Missions, Rewards, Leaderboard, Settings) plus Effects (flight camera, the player's cannon) and Tutorial.
- `src/tools/`: Command Bar builders for the map pieces (World 1 stations, lobby extras, rebirth signs, cannonball stand).
- `old/`: the first version, kept for reference.

## Core loop numbers
- Rebirth 1 costs 500 Power and 150 Cash, then x2.5 each time. Each rebirth gives +50% Power and +25% Cash.
- Launch direction is -X. Speed = 180 + 1.6 x sqrt(Power), max 1900. Cash = 0.25 per stud.
- Each skip is 0.86 of the last. The first arc is 20% of the distance and at least 160 studs, so it clears the lobby.

## Track areas (border x position)
Meadow Pond -152, Mushroom Grove -279, Sandy Shore -443, Lighthouse Point -659, Shipwreck Bay -938, Skull Rock -1298, Red Mesa -1770, Ancient Ruins -2384, Maple Woods -3180, Fortress Walls -4213, Igloo Camp -5559, Aurora Peaks -7308, Crystal Caverns -9580, Volcano Core -12532, Sky Kingdom -16349.

## Cannons from rebirths
- Iron, Steel, Heavy, Industrial and Golden unlock at 2, 4, 6, 8 and 10 rebirths. They can't be bought.
- The best owned cannon (highest Mult) is equipped automatically and stands next to the Launch Zone. The ball leaves its muzzle when you launch.
- You can switch cannons in the Cannons panel.

## Flight
- The camera chases the ball low over the water, with a big distance counter.
- Each skip gets a splash and a cash pop. An area banner shows as the ball crosses each border, and the ball leaves a trail.

## Tutorial (one to one with the reference video)
- **Intro cutscene, about 21s, skippable:**
  - the guide waves by the cannon;
  - the camera chases the ball through the worlds;
  - the guide points and talks;
  - the camera glides over the pads and lands behind the player.
- **Quest bar steps:** Train 30 Power, Launch twice, Earn 100 Cash, Hatch an egg, Rebirth Power, Rebirth Cash, Rebirth Now.
- **Guidance:** a flowing 3D arrow line, built from pathfinding, leads to each target. A ring and pointer mark UI buttons.
- **Ending:** a TUTORIAL COMPLETE screen, then Daily Rewards.
- **Text:** every word is in the `TEXT` table at the top of Tutorial.lua. Alex writes the final lines.

## Studio lessons learned
- The Studio MCP id changes every time Studio reopens.
- `execute_luau` needs `datamodel_type` (Edit, Client or Server).
- Large scripts go in as chunks. Check the install with `loadstring` and by matching the byte count.
- While the Mac display sleeps, TweenService and RenderStepped stop in Play mode but Heartbeat keeps running. Test with Heartbeat, and give tweens snap fallbacks.
- A NumberValue only tweens while it's parented in the DataModel.
- A Highlight needs a Model as its adornee, not a Folder.
- Keep StreamingEnabled off so the whole track renders.

## Still open
- Final tutorial lines from Alex, plus optional UI art (quest banner, arrow, pointer hand, complete title).
- Whether to make the first rebirth cheaper. It takes about 7 minutes now, against about 40s in the reference.
- Real cannon GLBs to replace the placeholders, the 5th egg, and the gamepass and product ids.
- Upload the icons and paste the ids into Icons.lua.
- Note: testing gave Alex's own save 2 rebirths and the Iron Cannon.
