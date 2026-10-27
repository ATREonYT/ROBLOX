# World 2: Downtown (design, Oct 27)

The owner (Oct 27): "start working on a second world, using the style you already learnt from building this map, and
then make it not the hood, make the second world more advanced, by that i mean make it more of a city, not the hood, as
they are escaping the hood (+1 hood evolution) and then import some characters from roblox that you find of more office
workers, bosses, etc. But dont use your placeholders as they look bad, also give them animations". Earlier: "we need them
to beat the final boss to get to the next world"; World 2 longer than World 1 (the sim's target 40 minutes).

## The story in one line
You beat the Harbor crew's boss, the World 2 door opens, and you've made it out of the hood into Downtown: glass towers,
offices and bosses in suits. Same loop, bigger numbers.

## Order of work (World 1 ships first)
1. World 1 release polish (the Oct 27 list, jobs 1-9 in `plan-2026-10-27.md`).
2. World 2 golden slice: the Downtown lobby corner, Stage 1-2 street and one crew with real characters, judged by the
   owner against the reference before the rest is built (CLAUDE.md lesson 2).
3. The rest of World 2's 16 stages, its ranges, guns and boxes, then the pacing sim.

## How worlds work (the soldier game's model, kept simple)
- Power, rebirths, guns and shoes carry over. Each world has its own stages 1-16 (a run always starts at that world's
  Stage 1), its own lobby with its own ranges, gun shop and two Cash shoe boxes (`Shoes` already plans W2's two boxes).
- World 2's Stage 1 asks for about World 1's boss Power; pads pay more; its ranges multiply more (the lanes keep opening
  by rebirths, World 2's set above World 1's).
- Unlock: the World 2 door opens once you've beaten World 1's boss yard (saved, once ever). You can always travel back.
- Pacing: World 2 runs at 5000x World 1's numbers (Power in the billions, the owner: "in other games it's usually billions"), one stage per rebirth from 10 to 25; about 62 minutes from the door to its boss (the owner: "make it way longer").

## The look ("more advanced", same style)
Same LEGO-like blocky kit, classic studs, the Huzz lighting. City instead of hood: clean asphalt avenues with white lane
lines and crosswalks, glass-and-steel towers (big flat window grids, warm mid-tone stone bases, no grey-only palettes),
office lobbies, food trucks, yellow taxis and buses, planters with trimmed trees, billboards, a rooftop for the boss yard.
Calm streets, loud interactables. Props from the owner's Claude Design batches when they come (CLAUDE.md lesson 4).

Oct 27 decisions:
- The lobby is the owner's "C": the Oct 10 indoor hall (aqua studded walls, periwinkle pillars, cyan floor lines,
  skylights and blue trusses) round World 2's own zones, at World 1's size; downtown's towers show through its door,
  windows and skylights (`tools/map/city/e6_hall.lua`).
- The track is five districts of three stages each, after the owner's mockup
  (`docs/refs/world2/owner_world2_districts_oct27.png`; "don't make it exactly like this ... more low poly/cartoony"):
  City Streets 1-3, Modern Plaza 4-6, Construction Zone 7-9, Transit Area 10-12, Luxury District 13-15 with the red BOSS
  gateway before gate 16, then the CEO tower's rooftop (Stage 16). Our own chunky props (`tools/map/city/f4_districts.lua`).

## The people (no placeholders)
Office workers, security guards, managers, a CEO boss: real Roblox characters, animated with the owner's pack. Two ways
to get them, both real (we never invent ids):
- the owner picks models in Studio's Toolbox and saves them to `hood/art/models/world2/World2People.rbxm` (we strip every
  script from them: free models can carry bad scripts), or
- real catalog outfits (suits, ties, hair, glasses) dressed on blocky R15 rigs through a HumanoidDescription, like the
  World 1 crews (`ServerStorage/HoodEnemies/EnemyRoster.lua`), picked by the owner.

## Crews (draft, 2 stages each like World 1)
Interns (coffee runs), Mailroom, Security, Sales Team, Lawyers, Managers, Board Members; the boss yard: the CEO on the
rooftop helipad.
