# Drop Players Into the Street, Not a Lobby

Today's front-page hits put a new player on the play surface with a free reward a few steps away, and they make progress visible as a straight line of numbered, brightly coloured barriers. The "+1 … Evolution" games (+1 Superhero Evolution, +1 Speed Evolve, +1 Mog Evolution), Steal a Brainrot and Steal an Egg all follow this pattern. Hood already has the same core loop: Power ticks up every second, bags multiply it, and walls ask for a number. What held it back was layout and light. The Block V2 spawned players inside a 128 × 104-stud courtyard about 80 studs from the first wall, under a low 17:12 sun and a beige haze. This round rebuilds V2 as a single street. You spawn 10 studs from the free Tire Bag with Stage 1's gate in view 34 studs ahead. Ten rainbow gates block you until you have the Power, and each better bag waits just past the gate that unlocks it. The street gets nicer stage by stage, from the block to the edge of uptown. A "Front-page Day" lighting preset is applied when the map is built.

**Source caveat.** YouTube, Reddit, Fandom, the DevForum and create.roblox.com were blocked from this environment. The connected Adlicio video-transcript tool needs a paid plan. So no videos were watched. The findings come from written guides, wikis and search-result summaries, gathered by three research agents. Their notes, with every link, are in `research_notes/Front page feel and gamey stages/`. Sizes and colours marked as recommendations are design proposals, not measurements from the games.

## What the hits have in common

### The "+1 Evolution" games play like Hood, laid out as a hallway

These games all share one loop: gain +1 of a stat, train to multiply it, and break through numbered stages. +1 Superhero Evolution describes its world as "a lengthy hallway… fragmented into Levels". World 1 has 15 stages, and the last one unlocks the teleport to World 2 ([how to play](https://superhero-evolution.wiki/guides/how-to-play/)). +1 Speed Keyboard Escape gives you a free treadmill at spawn and makes Stage 1 a couple of jumps for 1 Win ([Stage 1](https://1-speedkeyboardescape.fandom.com/wiki/Stage_1_(World_1))). Evolutions show up as a lineup of every form on a lobby pedestal, plus overhead names and numbers, so everyone sees everyone's progress. A June 2026 change to Roblox's ranking counts players who leave in the first 60 seconds against a game. That makes "first reward within seconds" a requirement, not a nicety ([game-ace](https://game-ace.com/blog/roblox-simulation-games/)).

### Steal a Brainrot and Steal an Egg: simple geometry, one loud spine, constant motion

Steal a Brainrot has 8 bases on either side of a studded red carpet that characters walk along all the time. Each base is just "walls, a roof, a spawner, a sign, and a locking mechanism with lasers" ([sportskeeda map guide](https://www.sportskeeda.com/roblox-news/steal-brainrot-map-guide), [tutorial summary](https://glasp.co/youtube/-VAgHBboxLA)). A new player gets $100 and a $25 first buy that earns $1 a second ([beginner guide](https://games.gg/roblox/guides/steal-a-brainrot-ultimate-beginners-guide/)). Its lighting is "mostly default lighting but with enhanced saturation" ([DevForum thread](https://devforum.roblox.com/t/what-lighting-is-the-best-for-a-brainrot-game/4075247)). "Steal and egg" most likely means Steal an Egg, the #1 game in September 2026. It is one long map of biomes gated by Speed ([biomes](https://allthings.how/steal-an-egg-every-biome-and-its-minimum-speed-requirement/)). In every case the detail goes into colour, signs and motion, not into geometry.

### "Too dark" had five causes, and lighting fixes most of them

- **The sun.** At 17:12 the sun is low, so tall walls shade most of a 40-stud street.
- **The lighting style.** `Realistic` raises contrast in the shade.
- **The haze.** A beige haze at 1.6, plus a warm tint, multiplies the blues down.
- **Bloom.** A threshold of 1.2 keeps Neon from glowing.
- **Dark surfaces.** The road filled the bottom third of every frame.

The Front-page Day preset fixes these: `Soft` style, a 13:00 sun behind players walking down the street, a cool bright shadow fill (OutdoorAmbient 162, 168, 200), Haze 0.2, Saturation +0.25, and Bloom 0.65 with a 1.1 threshold. It also brightens the road and turns off shadows from the terraces lining the street. The full table, and a brighter "Golden Block" evening version, are in `lighting_and_gates.md`.

### Gamey gates are a rainbow of solid frames with huge numbers and a see-through, solid-for-you barrier

The gate spec has these pieces:

- **Frame:** 4 × 16 × 4 pillars with a 40 × 6 header carrying a number that reads three gates away, and a stage badge on top.
- **Barrier:** a ForceField sheet with lasers, a padlock and a per-player progress bar.
- **Floor:** a yellow-and-black win strip behind the gate, and chevrons in front of it.

Gates run a colour ladder from lime to gold, with a black-and-gold final gate. A gate is locked (solid for you), ready (green and pulsing), or cleared (gone). Breaking through should feel like an event: shards, confetti, a camera kick and a rising chime. When you're short, the gate should tell you by exactly how much.

### The hood should read as warm and busy at the start and get calmer and shinier toward the goal

The props that say "city block" instantly include:

- rowhouses with stoops and cornices
- water towers and zig-zag fire escapes
- a corner deli with a yellow awning, a neon OPEN sign and a cat
- murals, a basketball court with chain-link, and an open hydrant
- a boombox, a barber pole, and street-name blades

Wear should read as personality (tape, chalk, stickers), never decay. Moving "out of the hood" changes several things at once: materials, greenery, fences, clutter and the share of gold. The goal should be visible from the start, as a skyline and a hillside sign ([hood_style_and_bags.md](../research_notes/Front%20page%20feel%20and%20gamey%20stages/hood_style_and_bags.md)).

### Bags need different silhouettes, not recolours

Five of the nine old stations were the same cylinder on the same frame. The redesign gives each tier its own shape and adds one new privilege per tier. The story runs from street junk to the gym classic, then the pro, then gold, then the arena.

## What changed in the game

### A compact lobby where you spawn next to the action

The new lobby is 88 × 44 studs, down from 128 × 104:

- **Spawn:** on a medallion facing down the street. The free Tire Bag is 9.7 studs away, turned toward you, with yellow chevrons leading over. Stage 1's gate is 34 studs ahead, so with the ×2 bag you clear it in about 25 seconds.
- **Around spawn:** the Drip Shop's 15 looks face the plaza from the right. The Bodega Box with its four crew pets stands in front of a yellow-awning corner deli on the left.
- **Back wall:** the leaderboards, with a THE BLOCK sign on the roof.
- **Next to spawn:** a "Best stage" pad that teleports returning players to their furthest cleared gate.
- **Hood details:** a barbershop with a spinning pole, a hopscotch, a mailbox and newspaper box, a boombox, and the giant glove on a brick pier.

### A rainbow street with a bag behind each gate

Ten gates stand 40 studs apart, built to the spec above. Each next bag waits in an alcove just past the first gate whose number is at or under the bag's price, so you can use it almost as soon as you reach it. A unit test now enforces that rule. Segment 3 holds the basketball court and segment 8 a block party with a colour-cycling dance floor. After gate 10 comes the finale plaza: the Champ Ring as an arena, the Kingpin statue, a spinning trophy, and Juniper Station ("World 2 – coming soon"). An Uptown skyline and THE HILLS sign sit on the horizon.

### Out of the hood, stage by stage

- **Stages 1–3:** warm brick and terracotta facades, chain-link with coloured slats, moving boxes and a delivery van.
- **Stages 4–8:** candy facades, an open hydrant with a mini rainbow, wet paint, scaffolding, string lights across the street and the block party.
- **Stage 9 to the station:** pastel and limestone, rooftop gardens, boxwood planters, brass rails and the first gold.

Cream cornices replace the grass lips on the block, and roofs take a light tint of their own building so the map stays colourful from above.

### The nine bags

| # | Bag | Silhouette and story | New this tier |
|---|---|---|---|
| 1 | Tire Bag | Three fat tyres with a chalk smiley, hung from a bent street lamp that's still lit; hopscotch slab, milk crate, cardboard FREE sign | Personality |
| 2 | Duct Tape Bag | Lumpy olive duffel leaning 5°, silver tape, tape-X eye, neon-green zip ties, on a green scaffold; pallet with a boombox | First bright accent |
| 3 | Street Bag | Clean blue canvas with a BLOCK tag patch and paint splats, under a street-sign pole; chain-link backdrop with blue slats and a tag | Paint, first glow |
| 4 | Heavy Bag | Fat glossy red classic (3.2 × 6), white caps, chrome hardware, black steel gallows, BLOCK BOXING CLUB poster | Pedestal, first light |
| 5 | Speed Bag | Wall rig: tufted pink backboard, round platform, oversized teardrop, timer clock showing 3:00 | Chrome, first particles |
| 6 | Double-End Bag | 13-stud arch with a HIGH VOLTAGE plate, navy ball with a cyan belt, electric bungees, lightning across the header, orbiting chips | Motion, electricity |
| 7 | Pro Bag | 8-stud tapered "banana" in black, red and gold on a three-step stage, FIGHT NIGHT banner, spotlight, embers | Stage, spotlight |
| 8 | Gold Bag | Gold wrecking ball with a diamond band and a crown, under a marble arch, on a 12-sided dais with a red carpet; halo, god-ray, gems | Gold and gems |
| 9 | Champ Ring | Rainbow ropes, belt hologram, confetti, bleachers with a bobbing crowd, sweeping spotlights, a lit sign | The arena |

Training mats grow with the station: 6.8 studs for tiers 1–5, up to 9.8 for the Gold Bag.

### The game actually runs on V2

`TheBlockV2.Build()` now makes V2 the active map. Players spawn there, and the server and client gameplay use it through a shared `ActiveMap` lookup. `SetActive(false)` hands the game back to the original Block. Other spawn points are switched off and remembered, never deleted.

- **Gates (`StageService`):** a gate is solid for you until you have the Power. The server records each first clear, pays its Cash reward and adds a Stage leaderstat. It announces clears of Stage 3 and up to the server, and moves back anyone who slips past a locked gate.
- **Gate feedback (`Stages.client`):** locked, ready and cleared states, a bump back with "NEED X MORE", and on break-through: shatter, confetti, a camera FOV kick and a chime.
- **Overhead tags:** every player shows their look's name and Power above their head.
- **Punching (`Punch.client`):** while you stand on a mat, a click, R2 or the big PUNCH button throws a punch. Each punch pays a tenth of your per-second gain, at least 1 and up to about 7 a second. Sparks come out in the bag's rarity colour and the camera nudges harder on higher tiers.

`Juice` already had pooled bursts and reusable flashes from the last round, so punches don't create effects from scratch.

### Lighting

- **Presets:** `HoodLighting` now has Front-page Day (the default) and Golden Block. They also set the lighting style, a Sky (turned slowly by clients), Clouds and wind, and `Restore()` still puts everything back exactly.
- **Applied on build:** `Build()` applies Front-page Day. The old preset names `Day` and `BlockParty` still work.
- **Sun direction:** if the sun would sit in front of players walking down the street, the latitude flips so the gates show their lit faces.

## How to try it

Pull the branch, run `./rojo serve` in `hood`, connect the plugin, and in the Command Bar run:

- `require(game.ServerStorage.TheBlockV2).Build()` builds the street, applies the lighting and makes V2 the game map. Press Play to spawn on the Block.
- `require(game.ServerStorage.TheBlockV2).SetActive(false)` gives the game back to the original Block.
- `require(game.ServerStorage.HoodLighting).Restore()` puts the old lighting back. `.Apply('GoldenBlock')` gives the evening look.

## Limits and next steps

**What was checked:**

- The Lune harness builds the map (9,378 parts).
- An integration check confirms the gameplay finds all 9 training mats, 15 outfit stands, the leaderboard, 10 gates in order and 10 teleport pads, and that a new player can train on the Tire Bag.
- 52 unit tests pass.
- A face-overlap check found nothing visible left to flicker.

**What wasn't:**

- None of it has been played in Studio or on a phone.
- The previews come from my own renderer, which only approximates Roblox lighting.
- Built-in sounds stand in for real ones.

These are worth doing next:

- an evolution lineup with silhouettes and a flash on each new look;
- working eggs;
- rebirth;
- an hourly block-party event;
- uploading the custom effect textures in `hood/art/vfx`;
- a balance pass now that punching can add up to about +70% while you train.
