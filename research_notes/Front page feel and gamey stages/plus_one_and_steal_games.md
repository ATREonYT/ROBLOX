# "+1 … Evolution" games, Steal a Brainrot and Steal an Egg: how front-page hits look and play, and what Hood should copy (Oct 2026)

> **Method note (read first).**
> - This session's egress proxy blocked **every page fetch** (sportskeeda, beebom, techwiser, allthings.how, games.gg, wikipedia, medium, roblox.com, rolimons, the fan wikis, sketchfab, fontsinuse and others all returned `EGRESS_BLOCKED`). YouTube, Reddit, Fandom and the DevForum were blocked too.
> - So every web fact below comes from **search-engine result summaries** of the linked page. The page itself was not opened. Treat each one as an unverified paraphrase.
> - The search budget ran out partway through, so a few topics are thin. Those are listed under **Gaps**.
> - Tags used:
>   - **[S]** = search summary of the linked URL.
>   - **[R]** = read from this repo.
>   - **[I]** = my inference or analyst observation (general familiarity with these games up to mid-2026, **not verified this session**).
> - Several fan wikis and code sites contradict each other on dates, creators and CCU. Conflicts are flagged, not resolved.
> - Companion notes already in this repo cover lighting values, palettes, VFX and UI kits in depth, so this note links to them instead of repeating them:
>   - `research_notes/Tiered props VFX and vibrant maps/vibrant_maps.md`: lighting presets H1/H2 and the colour-budget table
>   - `research_notes/Cartoony Roblox building UI and animation/building_stylized_techniques.md` §3: lobby layout numbers
>   - `.../ui_visual_design.md`: rarity colours and UI kits

---

## 0. TL;DR

1. **The "+1 X Evolution" format is almost exactly Hood's design**, and in 2026 it's a crowded, chart-topping genre. Examples: +1 Superhero Evolution, +1 Muscle Evolution, +1 Mog Evolution, +1 Magic Evolution, +1 Dino Evolution, +1 Phonk Evolution, +1 Speed Evolve and +1 Speed Keyboard Escape. Every one uses the same loop:
   - **gain +1 of a stat** (by click, step or second)
   - **train** (bags, treadmills or boulders)
   - **break through numbered stages** down one long lane, using the stat as the key
   - **collect Wins** at the stage end, often on a **yellow pad that also teleports you home**
   - **spend Wins** on the next **evolution**, on **eggs/pets** in the lobby, or on worlds
   - **rebirth** for a multiplier
2. **Time to first reward is seconds, not minutes.**
   - Superhero Evolution's first action is "click for +1 Power".
   - Keyboard Escape spawns you **on** the track, with a free treadmill at spawn. Stage 1 is "a couple of gaps" for 1 Win.
   - Steal a Brainrot puts you in your base with $100. The tutorial then points you at a $25 brainrot on the conveyor a few steps away.
3. **The map is a stage, not a diorama.**
   - Each hit has one readable spine: Steal a Brainrot's red conveyor, Steal an Egg's long biome corridor, or the +1 games' straight stage lane.
   - Lighting is bright default daylight with extra saturation.
   - The colour budget goes to things you collect or unlock.
4. **Hood already has the skeleton:** passive +1 Power, 8 bags + Champ Ring, 10 walls per map with `WallBase 50` / `WallGrowth 2.1`, red→green force-field gates, and a "STAGE 3 CLEARED" banner. The main gaps against the genre:
   - spawn is about 81 studs from the Stage 1 gate inside a walled courtyard
   - no Win pad / teleport-home beat at stage ends
   - no lineup showing all evolutions or titles
   - no eggs in the lobby yet
   - no overhead power number

---

## 1. The "+1 X Evolution / Evolve / Every Second" genre

### 1.1 Who's in the genre (dated facts)

| Game | Creator (as reported) | Created | Scale (as reported) | Stat & how you gain it | Where you spend the stat | Source |
|---|---|---|---|---|---|---|
| **+1 Superhero Evolution** | Giggity Goo Games | 27 Jul 2026 | 29.2M visits; another list says 23.1M plays | Click for +1 **Power**; sandbag training area | 15 stages of enemies per world, plus a Thanos boss on a countdown | [S] [rolimons](https://www.rolimons.com/game/97824450589417), [superhero-evolution.wiki](https://superhero-evolution.wiki/), [adellion list](https://adellion.com/roblox-simulator-games) |
| **+1 Muscle Evolution** | Need More Cement | 30 May 2026 | 56.3M visits | Click for **Damage**; punching bags | Stages of enemies, beaten by rapid tapping | [S] [rolimons](https://www.rolimons.com/game/133007106457547), [sportskeeda rebirth](https://www.sportskeeda.com/roblox-news/1-muscle-evolution-rebirth-guide) |
| **+1 Mog Evolution** (W1, then W2 as a separate experience) | n/a | 30 Aug 2026 | Day 16: #30 trending, ~10.1k CCU, 4.15M visits, 71k favourites | Click + treadmill for **Appeal** | Stages that each "ask for a certain amount of Appeal before it lets you through" | [S] [1mogevolution.pro](https://1mogevolution.pro/), [lolga guide](https://www.lolga.com/news/1-mog-evolution-beginner-guide-to-appeal-wins-ascend-rebirth) |
| **+1 Magic Evolution** | Me & You Studios | 4 May 2026 | 29.7M+ visits, 1.19M favourites, 98.7% likes | Click for **Magical Power**; train on **boulders** | Bosses for Wins; zones | [S] [earnaldo](https://earnaldo.com/blog/1-magic-evolution-free-robux-guide), [rolimons](https://www.rolimons.com/game/116223724643557) |
| **+1 Dino Evolution** | Best Dino Productions | n/a | ~3.6k players, 92.2% approval; 15.7M plays | Click for **Strength** | Dinosaur stages, bosses, areas | [S] [robipedia](https://robipedia.com/game/1-dino-evolution-10664667515), [dino-evolution.wiki](https://dino-evolution.wiki/updates/) |
| **+1 Phonk Evolution** | Paint n Relax | 2026 | 15.8M plays | Click for **Phonk**; **treadmills** | Enemies/stages, then areas | [S] [phonkevolution.wiki](https://phonkevolution.wiki/) |
| **+1 Speed Evolve** | **Conflict:** "Mauv +1" (beebom, creatorexchange) vs "aib games, released 2 Dec 2025" (rouniverse) | **Conflict:** 19 Apr 2026 (rolimons) vs 2 Dec 2025 | 109.7M visits | Each **step** = +1 Speed, which raises your Level | 15 obby stages in W1, then W2 (4 stages) and W3 | [S] [destructoid](https://www.destructoid.com/1-speed-evolve-codes/), [creatorexchange](https://creatorexchange.io/roblox-game/10057343903/1-speed-evolve), [rouniverse review](https://rouniverse.com/articles/1-speed-evolve-review/) |
| **+1 Speed Keyboard Escape** | Secret_Lokii / SecretVerse Studio | early 2026 | >2.5B visits, all-time peak ~6.2M CCU (Aug 2026); was #8 with 127k CCU in June 2026 | Each **key you step on** = +1 Speed | 15 stages in W1, plus more worlds | [S] [thebloxline](https://www.thebloxline.com/articles/1-speed-keyboard-escape-has-become-one-of-roblox-s-biggest-games-here-s-why-it-works), [deathgamer](https://deathgamer.com/2026/06/02/1-speed-keyboard-escape-how-did-this-become-robloxs-8-game/) |
| Older "every second" ancestors | various | 2022–2025 | **+1 Jump Every Second 🚀**: ~98.9M visits, 15 realms. **+1 Slap Power Every Second**: 5.2M, gains even offline. **+1 Strength Every Second** (Strong Bull Studios): fight bosses for wins, Premium gives +2/s | **Passive +1 per second** | Towers, realms, bosses | [S] [rolimons +1 Jump](https://www.rolimons.com/game/11988615696), [rolimons +1 Slap](https://www.rolimons.com/game/84693897878923), [roblox +1 Strength](https://www.roblox.com/games/11756031749/1-Strength-Every-Second) |

**Takeaway [I]:**
- The 2026 wave moved from "**every second**" (pure passive) to "**+1 per click/step**" plus **training stations** plus **stages that gate on the stat**, with an **evolution ladder** as the main thing you buy.
- Hood's "+1 Power every second" is the older hook. The bags-as-multipliers and wall stages put it right in the newer format.
- Hood should add a **tap/punch bonus** on top of the passive tick, because every 2026 title gives the player an active verb.

### 1.2 The shared core loop (sourced pieces)

- **Superhero Evolution:** "click for +1 Power, spend that Power on heroes, beat the Thanos boss for Wins, then Rebirth to multiply it all." [S] [superhero-evolution.wiki how-to-play](https://superhero-evolution.wiki/guides/how-to-play/)
- **Muscle Evolution:** "click nonstop to build Damage, then smash punching bags… fight enemies, clear stages, and gather Wins. Those Wins unlock new Evolutions and open bigger areas." [S] [muscleevolutionroblox.wiki](https://muscleevolutionroblox.wiki/)
- **Phonk Evolution:** "clicking for Phonk, training with Treadmills, fighting enemies and clearing stages, collecting Wins, then unlocking Evolutions and Areas." [S] [phonkevolution.wiki](https://phonkevolution.wiki/)
- **Mog Evolution:** "Build Appeal on the treadmill and by clicking, break through Stages to earn Wins, then spend those Wins on Ascend… Each stage has its own Appeal requirement… once your Appeal total reaches that number, you break through." [S] [lolga](https://www.lolga.com/news/1-mog-evolution-beginner-guide-to-appeal-wins-ascend-rebirth)
- **Speed Evolve:** "walk to build speed, bank the Wins you earn, then spend those Wins to evolve into the next animal." [S] [bloxodes animals](https://bloxodes.com/wiki/1-speed-evolve/animals)
- **Two currencies everywhere:** the **stat** (Power, Damage, Speed, Appeal) is the key that opens stages, and **Wins** are what you spend. Hood uses Power plus Cash in the same way. [R] `hood/src/ServerScriptService/HoodServer/StageService.server.lua`

### 1.3 Game-by-game details that matter for Hood

**+1 Superhero Evolution** (the closest analogue: punching, training bags, stages, titles = heroes, pets)
- **Spawn and first action:** "you spawn in Start City… your very first action is to click to generate +1 Power." On PC you left-click the arena. On mobile/Xbox you tap a **Power button** or press RT. "The Store and Rebirth buttons are accessible from the sidebar." [S] [how-to-play](https://superhero-evolution.wiki/guides/how-to-play/)
- **Training:** "approach the training area to [gain Power] automatically" or click manually. Better punching bags unlock at about **15, 30, 50 and 100 rebirths**, "each new station providing more strength per hit." [S] [sportskeeda beginner](https://www.sportskeeda.com/roblox-news/1-superhero-evolution-a-beginner-s-guide), [techwiser](https://techwiser.com/plus-1-superhero-evolution-beginner-guide/)
- **Stage structure:**
  - "a lengthy **hallway** that is fragmented into multiple sections called '**Levels**'… upon entering a Level, you will encounter a set of enemies."
  - "After defeating enemies in any stage, you'll notice a **purple and a yellow platform**… stepping on any of them **claims Wins and returns you to the lobby**."
  - "completing the final stage in World 1 unlocks the **Teleport button** for World 2."
  - World 1 has **15 stages**, and the last needs **≥1 billion Power**.
  
  [S] [sportskeeda beginner](https://www.sportskeeda.com/roblox-news/1-superhero-evolution-a-beginner-s-guide), [sportskeeda heroes](https://www.sportskeeda.com/roblox-news/all-world-1-heroes-1-superhero-evolution), [techwiser max level](https://techwiser.com/plus-1-superhero-evolution-reach-max-level/)
- **Worlds:** Start City (Power gate 0–1), **Neon District** (1–10K; opens once you pass 1K Power, "denser enemy packs"), Sky Arena (10K+), then Worlds 4–5. "Every world runs a Thanos boss fight on a **countdown**." [S] [superhero-evolution.wiki](https://superhero-evolution.wiki/)
- **Evolution = heroes on a pedestal.** "You can find all heroes on the **massive pedestal in the lobby**." The hero ladder (unlock cost → power per click):

  | Hero | Unlock | Power per click |
  |---|---|---|
  | Starter | free | 1 |
  | Spider-Man | 1 Win | 2 |
  | Black Widow | 5 | 5 |
  | Batman | 25 | 10 |
  | Hulk | 100 | 25 |
  | Wolverine | 250 | 60 |
  | Deadpool | 750 | 150 |
  | Thor | 2,000 | 400 |
  | Doctor Strange | 5,000 | 1,000 |
  | Flash | 15,000 | 3,000 |
  | Captain America | 40,000 | 8,000 |
  | Green Lantern | 100,000 | 22,000 |
  | Iron Man | 300,000 | 60,000 |
  | Superman | 119 R$ | 500 |
  | Thanos | 199 R$ | "100% better than your best hero" |

  Costs grow about ×2.5–×5 per step, and power about ×2–×3. [S] [deltiasgaming list](https://deltiasgaming.com/all-world-1-heroes-in-1-superhero-evolution-roblox/), [techwiser heroes](https://techwiser.com/1-superhero-evolution-heroes/), [sportskeeda W1 heroes](https://www.sportskeeda.com/roblox-news/all-world-1-heroes-1-superhero-evolution). The "massive pedestal" quote comes from the same search cluster ([techwiser beginner](https://techwiser.com/plus-1-superhero-evolution-beginner-guide/)).
- **Eggs (World 1):**
  - **Basic 10 Wins:** Dog ×2, Cat ×3, Egg ×4, Bunny ×5, Golem ×7, Dragon ×10
  - **Farm 2.5K Wins:** ×6 to ×16
  - **Dominus 49 R$:** ×45 to ×165
  - **Neon 99 R$:** ×70 to ×350
  
  [S] [sportskeeda eggs](https://www.sportskeeda.com/roblox-news/all-world-1-eggs-1-superhero-evolution)
- **Rebirth** "resets your level while keeping **25% of your Power** and applying a **2x multiplier**." [S] [allthings.how rebirth](https://allthings.how/1-superhero-evolution-how-to-rebirth-fast-in-roblox/)
- **Scheduled social events:**
  - a **Dungeon Raid every hour at XX:30**: a "Go!" button teleports you in, you get 3 lives, and the course is an enemy room, then a rolling-boulder room, then obbies, then a final boss
  - "Admin Abuse" events
  
  [S] [sportskeeda dungeons](https://www.sportskeeda.com/roblox-news/1-superhero-evolution-dungeons-guide)

**+1 Muscle Evolution** (the muscle/punching sibling)
- "Wins can be collected by standing on the **green or yellow platforms at the end of a stage**… you must first beat enemies in the particular stage by rapidly tapping on the screen." [S] [sportskeeda pets/stages](https://www.sportskeeda.com/roblox-news/all-pets-1-muscle-evolution)
- "**Pets can be hatched from the eggs displayed in the lobby**." Egg prices:

  | Egg | Price |
  |---|---|
  | Basic | 100 Wins |
  | Better | 25K |
  | Rainbow | 1M |
  | Magma | 150M |
  | Circus | 7.5B |
  | Coconut | 125B |
  | "67 Egg" | 79 R$ |

  That's roughly ×40–×250 per egg tier. Top-pet odds are about 3.1% (0.1% for Circus's Kitsune). [S] [allthings.how eggs](https://allthings.how/1-muscle-evolution-every-egg-pet-and-hatch-cost/), [sportskeeda pets](https://www.sportskeeda.com/roblox-news/all-pets-1-muscle-evolution)
- **Rebirth ladder:**

  | Rebirth | Requires | Damage | New level cap |
  |---|---|---|---|
  | 1 | nothing | ×2 | n/a |
  | 2 | Lv 26 | ×3 | 32 |
  | 3 | Lv 32 | ×4 | 43 |
  | 4 | Lv 43 | ×5 | 48 |
  | 5 | Lv 48 | ×6 | 60 |
  | 6 | Lv 60 | ×7 | 72 |

  A rebirth resets Damage, Level, Wins **and Evolutions**, and there are 20+ rebirth tiers. [S] [sportskeeda rebirth](https://www.sportskeeda.com/roblox-news/1-muscle-evolution-rebirth-guide)

**+1 Speed Evolve** (the evolution and stage-pad pattern)
- **Evolution chain:** Squirrel → Chicken/Hen → Rabbit → Goose → Cat → Fox → Deer. One wiki lists 12 animals. "Each form changes your appearance." "Each evolution stacks a speed multiplier." [S] [bloxodes animals](https://bloxodes.com/wiki/1-speed-evolve/animals), [rouniverse guide](https://rouniverse.com/articles/1-speed-evolve-guide/)
- **Stage reward:** "Reaching the platform doesn't pay you — jumping on the **yellow Win button** does. It sits in every stage's **safe zone**." W1 has **15 stages**, and late W1 needs about level 100–120. W2 has 4 longer stages (recommended level 140 → 200+). [S] [earnaldo](https://earnaldo.com/blog/1-speed-evolve), [speedevolve.wiki W2](https://speedevolve.wiki/worlds/world-2/)
- **Level curve:** "the first nine levels cost 5, 10, 15 and so on, and every level after that costs six percent more than the last." The first rebirth is around level 25. [S] [speedevolve.wiki](https://speedevolve.wiki/)
- **Treadmills sit in the "Spawn treadmill area"** and give passive/idle gains. Paid tiers: Gold 69, Diamond 199, Emerald 499, Ruby 1,299 R$. [S] [speedevolve.wiki treadmills](https://speedevolve.wiki/items/treadmills/)
- **Trails:** Orange ×1.5, Blue ×2, Star ×100. Trails and **Auras** stack multiplicatively. [S] [bloxodes trails](https://bloxodes.com/wiki/1-speed-evolve/trails)
- **Free starter boost:** joining the group gives a **permanent +10%** that survives rebirth. [S] [earnaldo](https://earnaldo.com/blog/1-speed-evolve)
- **Feel:** "immediately gratifying… constant feedback paired with frequent visual evolutions… The early game is brisk, with **new evolutions every few minutes**." [S] [rouniverse review](https://rouniverse.com/articles/1-speed-evolve-review/)

**+1 Speed Keyboard Escape** (the genre king; the repo already has a remake, `plus-one-speed/`)
- **Spawn:** "you'll land on a giant keyboard at the spawn area". "The free Chocolate treadmill is located right at the spawn area." Treadmills are "scattered across the map, especially near the spawn area". [S] [techwiser beginner](https://techwiser.com/1-speed-keyboard-escape-beginners-guide/)
- **Free boosts at join:** liking the game and joining the group each give **15,000 speed**. A social code gives the same, for **>30,000 free speed** at the very start. [S] [techwiser beginner](https://techwiser.com/1-speed-keyboard-escape-beginners-guide/)
- **Stage 1** "a couple of gaps… to get **1 win**". "After clearing a stage, step onto the **yellow pads in the safe zone**. Doing so **banks your Wins and then teleports you back to spawn**." [S] [fandom Stage 1](https://1-speedkeyboardescape.fandom.com/wiki/Stage_1_(World_1)), [techwiser](https://techwiser.com/1-speed-keyboard-escape-beginners-guide/)
- **Win ladder, World 1:** 1, 3, 10, 20, 60, 100, 150, 300, 500, 1,000, 2,500, 10,000, 25,000, 50,000, 150,000. World 2 starts at 250K and runs 400K, 600K, 1M, 1.5M. That's about ×2–×3 per stage early, with bigger jumps late. [S] [techwiser stages](https://techwiser.com/1-speed-keyboard-escape-stages/), [fandom Stages](https://1-speedkeyboardescape.fandom.com/wiki/Stages)
- **Named stages:** Gummy Gateway, Candy Cane Walk, Chocolate Creek, Marshmallow Maze, Caramel Canyon, Lollipop Ledge, Fudge Falls… [S] [techwiser stages](https://techwiser.com/1-speed-keyboard-escape-stages/)
- **Why it works,** per the analyses:
  - "no complicated story… no enormous tutorial… you start moving and immediately understand what the game wants from you"
  - "Numbers increase, your character gets noticeably faster, **bright objects fill the screen**, and the keyboard provides repeated visual and audio feedback"
  - "ASMR keyboard sounds, candy visuals"
  
  [S] [thebloxline](https://www.thebloxline.com/articles/1-speed-keyboard-escape-has-become-one-of-roblox-s-biggest-games-here-s-why-it-works), [deathgamer](https://deathgamer.com/2026/06/02/1-speed-keyboard-escape-how-did-this-become-robloxs-8-game/)

**Punch-wall ancestors** (the "numbered wall" visual grammar)
- In Punch Wall, walls have **health values** you punch down, and "the more walls you break in one continuous run, the higher your **combo multiplier**." Pets give +3% (common) to +50% (legendary). [S] [ofzenandcomputing](https://www.ofzenandcomputing.com/punch-wall-master-guide/)
- Wall Punch Simulator advertises "**100+ rainbow stages** where you smash your way through giant brick and crazy walls". [S] [roblox Wall Punch Simulator](https://www.roblox.com/games/12888107609/Wall-Punch-Simulator)

### 1.4 What the player sees in the first 10 seconds

Sourced:
- They're already on the play surface: the keyboard (Keyboard Escape) or Start City with click-for-Power live (Superhero).
- A free trainer is at spawn (Keyboard Escape's Chocolate treadmill; Speed Evolve's "Spawn treadmill area").
- The first goal is one short stage away.

[I] Typical composition from the spawn camera in these games:
- The **stage lane starts straight ahead**, with Stage 1's wall/arch and its number visible.
- **Trainers** (bags, treadmills) sit in a row a few studs to one side.
- **Eggs** stand on a raised row with price billboards on the other side.
- An **evolution/hero lineup** (pedestal) is behind or beside you.
- A **leaderboard** wall faces spawn.
- The HUD shows:
  - top/top-left: the stat counter with a "+1" floater
  - left edge: a column of big square buttons (Store, Pets, Rebirth, Codes)
  - bottom-right on mobile: a big action button

The lobby is **compact**: all of it fits in one or two screen widths, with no long walk before the first action.

### 1.5 Map layout: hub + one straight lane of stages

- **Sourced spine:**
  - Superhero Evolution's "lengthy hallway… fragmented into… Levels"
  - Keyboard Escape's "obstacle course stages" with safe-zone pads, after which you're "teleported back to spawn"
  - Mog Evolution's "break through Stages"
  - Steal an Egg's "biomes laid out as **one long map**"
  
  [S] (links above), [allthings.how Steal an Egg biomes](https://allthings.how/steal-an-egg-every-biome-and-its-minimum-speed-requirement/)
- **Worlds are separate places or teleports,** unlocked by finishing the last stage. Superhero Evolution has a Teleport button; Mog Evolution's W2 is even a separate experience with its own leaderboards. [S]
- [I] Because the pad teleports you home, the loop is a **sawtooth**: walk out → clear the furthest stage you can → pad → back to hub → spend → walk out again. The lane only has to be walkable one way. The hub is where you spend, so the **hub should be next to the lane's start**, not across a big plaza.

### 1.6 How stages, gates and walls look

Sourced fragments:
- stage requirements show on **in-game stage signs** ("copy them directly from the in-game stage signs") [S] [techwiser stages](https://techwiser.com/1-speed-keyboard-escape-stages/)
- **yellow** Win button/pads in a **safe zone** after each stage (Keyboard Escape, Speed Evolve)
- **purple + yellow** platforms (Superhero Evolution) and **green or yellow** platforms (Muscle Evolution) at stage ends
- **rainbow stages** with "giant brick… walls" (Wall Punch Simulator)
- Steal an Egg's guardian "**turns red** and chases you"

[I] The visual grammar these games share (unverified, from familiarity):
- **The stage boundary spans the whole lane.** It's an arch, a wall or a coloured barrier, as wide as the track, so you can't miss it. It's taller than a character by 3–5× (15–25 studs).
- **Huge numbers.** The stage number ("STAGE 3") and the requirement (an icon plus a compact number, e.g. "⚡ 2.2K") are in a chunky cartoon font with a thick dark outline. They're readable from the previous stage.
- **The lock state is colour-coded:** red or translucent with a lock icon when you're short, green or open when you qualify. Hood's client already flips red (255,60,90) to green (70,255,140). [R] `HoodClient/Stages.client.lua`
- **A per-stage colour or theme change** makes the lane read as a progress bar: rainbow ordering, or a new candy/biome theme per stage.
- **The reward pad is the brightest thing in the safe zone:** saturated yellow, often glowing, with a big "WIN" or "+X" label.
- **Simple geometry:** blocks, cylinders and wedges in SmoothPlastic and Neon. Detail goes into colour, signage and motion, not mesh complexity.

### 1.7 How "evolution" is shown

- **Sourced:**
  - Speed Evolve: "Each form **changes your appearance**", from squirrel to deer.
  - Superhero Evolution: buy and equip heroes that replace your look; all heroes stand on a **lobby pedestal**.
  - Muscle Evolution: evolutions are bought with Wins and reset on rebirth.
  
  [S] (links above)
- **Auras and trails** are separate multiplier layers in Speed Evolve. [S]
- [I] Common display patterns:
  - **the lineup:** every form on podiums in order, with locked ones as dark silhouettes and a price tag
  - a **name/title plus stat BillboardGui** over each player's head, so everyone sees everyone's progress (the repo's Keyboard Escape remake does this: "Your speed floats over your head for everyone to envy" [R] `plus-one-speed/README.md`)
  - a **morph/size change** at each evolution, with a flash + particle burst + banner
- Hood already has **15 looks** (Corner Kid → Kingpin) and black-silhouette locked bags [R] `hood/README.md`. Those are exactly the lineup and silhouette patterns.

### 1.8 Pets and eggs placement

- **Sourced:**
  - Muscle Evolution: "eggs **displayed in the lobby**", bought with Wins.
  - Superhero Evolution: World 1 has 4 eggs (2 for Wins, 2 for Robux).
  - The first egg is cheap: **10 Wins** (Superhero) or **100 Wins** (Muscle).
  - First-egg pets are about ×2–×10.
  
  [S] (links above)
- [I] Eggs stand in a **row of 3–5 on plinths near spawn**, each with a price billboard and a hatch animation that plays in screen-centre. Robux eggs sit at the end of the row with a gold or rainbow treatment.

### 1.9 UI style

- **Sourced:**
  - Superhero Evolution has "Store and Rebirth buttons… in the sidebar" and a **mobile Power button**. The Codes box sits at the bottom of the Store.
  - Magic Evolution has a "blue bird icon at the top right" for codes.
  - Keyboard Escape uses the default Tab leaderboard, plus in-world leaderboards.
  
  [S] [superhero how-to-play](https://superhero-evolution.wiki/guides/how-to-play/), [beebom Magic](https://beebom.com/plus-1-magic-evolution-codes/), [thebloxline](https://www.thebloxline.com/articles/1-speed-keyboard-escape-has-become-one-of-roblox-s-biggest-games-here-s-why-it-works)
- The repo's `ui_visual_design.md` covers the "stud UI / shiny stud UI… cashgrab/brainrot style" kits these games buy (HUD frames, shop, currencies, rebirth). [R]

### 1.10 Retention hooks (sourced)

- **Compounding multipliers**: evolutions × trails × auras × rebirth × group boost, all multiplicative. [S] [bloxodes trails](https://bloxodes.com/wiki/1-speed-evolve/trails)
- **Frequent visible upgrades:** "new evolutions every few minutes" early on. [S] [rouniverse review](https://rouniverse.com/articles/1-speed-evolve-review/)
- **Idle/AFK gain:** treadmills, including offline. +1 Slap Power gains even offline. [S]
- **Scheduled events:** hourly raids at XX:30, boss countdowns, Admin Abuse. [S] [sportskeeda dungeons](https://www.sportskeeda.com/roblox-news/1-superhero-evolution-dungeons-guide)
- **Social:** like/favourite/group rewards and leaderboards. [S]

---

## 2. Steal a Brainrot (SaB)

**Facts**
- Developed by SpyderSammy and released on Roblox **16 May 2025**. One summary says it is "the only Roblox game to have surpassed **25 million CCU**". [S] [wikipedia](https://en.wikipedia.org/wiki/Steal_a_Brainrot), [stealaneggguide](https://stealaneggguide.wiki/guides/who-made-steal-an-egg/)

**Map layout**
- **8 bases, 8-player servers.** "The player spawns at one of the 8 bases." "Bases are lined up on either side of the conveyor belt." "Eight players match the capacity of a public server and cover all eight bases." [S] [sportskeeda map guide](https://www.sportskeeda.com/roblox-news/steal-brainrot-map-guide), [progameguides](https://progameguides.com/roblox/steal-a-brainrot-private-server-links/)
- **The spine is the Red Carpet:** "This **studded red carpet** runs through the **center** of the map, **connecting two tunnels** where Brainrots continuously spawn, walk across, and disappear if not purchased." Brainrots "march along displaying their rarity, cost, and earning rate". [S] [noleep red carpet](https://noleep.com/en/steal-a-brainrot-red-carpet-guide-all-brainrot-spawn-rates-tips/), [bloxspot](https://bloxspot.com/steal-a-brainrot-wiki-2026-complete-guide-brainrot-list-rebirths-gears-stealing-tips/)
- **Shops sit in the middle:** "three shops in the middle of the red conveyor": the Item Shop (cash), the Robux Shop and a Craft Machine. [S] [fandom](https://roblox.fandom.com/wiki/BRAZILIAN_SPYDER/Steal_a_Brainrot)

**First minute (time to first reward)**
- "you spawn with **$100** at one of eight bases… your base automatically **locked for 30 seconds**. The in-game tutorial guides you to purchase your first brainrot — **Noobini Pizzanini for $25, earning $1 per second** — from the red conveyor." [S] [games.gg beginner](https://games.gg/roblox/guides/steal-a-brainrot-ultimate-beginners-guide/)
- [I] Your base door opens onto the carpet, so the first purchase is about a 5–15 s walk from spawn. Income starts ticking immediately.

**The base**
- "a building with a gate consisting of **red laser beams**. Only the owner (and optionally their Connections) can go through."
- Lock: **60 s**, +10 s per rebirth, +10 s with VIP.
- Floors: a **2nd floor at rebirth 2**, with an **outside staircase on the right side**. A **3rd floor at rebirth 10**, with a ladder inside.
- Capacity: 10 + 8 + 7 = **27 brainrots** at 18 rebirths.
- Completing a mutation index gives a **base skin in that mutation's colour** (gold, rainbow).

[S] [fandom Base](https://stealabrainrot.fandom.com/wiki/Base), [rosenberryrooms](https://www.rosenberryrooms.com/get-the-second-floor-in-steal-a-brainrot/), [eldorado skins](https://www.eldorado.gg/blog/steal-a-brainrot-en/steal-a-brainrot-base-skins/)

**Stealing**
- "the thief is **slowed, stripped of all items, and the owner is alerted**". The stolen brainrot "sits on your back". [S] [fandom](https://roblox.fandom.com/wiki/BRAZILIAN_SPYDER/Steal_a_Brainrot)

**Building style and what kit makers say**
- A BuiltByBit kit: "8 plots, each with 3 floors… 30 brainrot slots… pathways for brainrots, stalls, a lucky wheel, and leaderboards… **low poly** style… medium-sized map". [S] [builtbybit](https://builtbybit.com/resources/steal-a-brainrot-map.93631/)
- A free Creator Store version also exists. [S] [create.roblox.com](https://create.roblox.com/store/asset/101491434169003/Steal-A-Brainrot-Map)
- A YouTube "Part 1: Base" tutorial: the base is "**walls, a roof, a spawner, a sign, and a locking mechanism with lasers**". That's the entire base vocabulary. [S] [glasp summary](https://glasp.co/youtube/-VAgHBboxLA)
- DevForum "Complete Game Kit + Tutorial Series" covers brainrot customization and sounds, stealing and base progression, rebirths, NPC shops and tools, UI setup and effects, module-based code, and rarity and mutations. [S] [devforum 4137672](https://devforum.roblox.com/t/how-to-make-roblox-%E2%80%9Csteal-a-brainrot%E2%80%9D-game-tutorial-series/4137672)
- Character art: "small bodies with large heads, simple pixel textures, and blocky shapes." [S] [sketchfab packs](https://sketchfab.com/3d-models/steal-a-brainrot-characters-animated-low-poly-1-5b1fcf10be9d4d749cdae20ed262060b)

**Lighting and palette**
- A DevForum thread on "What lighting is best for a brainrot game?" is summarised as: SaB "uses **mostly default lighting but with enhanced saturation**". A common approach is "**cartoony sky, increased saturation**, eye-hurting brightness." [S] [devforum 4075247](https://devforum.roblox.com/t/what-lighting-is-the-best-for-a-brainrot-game/4075247)
- One kit's author warns "it may be a bit bright". [S]
- "Every corner bursts with bright colors and animated meme creatures." [S] (via `vibrant_maps.md`)

**Signage and fonts**
- Fonts in Use: the **purchase prompt is Comic Sans**, brainrot names are **Source Sans**, and the main brainrot name is **Montserrat**. These are plain system-ish fonts, not custom display type. [S] [fontsinuse](https://fontsinuse.com/uses/73361/steal-a-brainrot-video-game)

**Events re-skin the same geometry**
- Easter Hour: "floor becomes **pink** and the conveyor becomes a rocky path".
- Egg City: egg-shaped houses next to bases.
- North Pole: a train in the middle to an event map.

[S] [sportskeeda map guide](https://www.sportskeeda.com/roblox-news/steal-brainrot-map-guide)

**Why it's sticky (analyses)**
- "simple mechanics… the upside (rare Brainrots, big multiplier income) is **visible**"
- tycoon/idle + PvP hybrid
- "colorful, absurd, and intentionally comedic"
- variable rewards

[S] [psychreg](https://www.psychreg.org/why-steal-brainrot-feels-addictive/), [medium](https://medium.com/@emtertoszef/steal-a-brainrot-phenomenon-6af7b49081e0)

**[I] What makes it look the way it does**
1. A flat ground plane, with no hills in the play area.
2. One saturated **red** stripe (the carpet) as the focal line, and constant motion on it: characters walking left to right all the time.
3. Bases are simple boxes, repeated 8×, so the eye reads them as one pattern and the unique content is *what's inside*.
4. Each brainrot has a **floating text stack**: name, rarity in its rarity colour, $/s, and a price button. The UI is in the world.
5. Red lasers mean danger; the colour code does the explaining.
6. A bright default sky with saturation pushed up.

---

## 3. "Steal an Egg" and the other egg-stealing games (what "steal and egg" probably means)

The user's "steal and egg" most likely means **Steal an Egg**. Three other games match the phrase.

### Steal An Egg (the big one)

**Facts**
- By the group "and Collect Rare Pets" (owned by MisfitsBSthree), released **25 Jul 2026**, with about 4.47B visits. [S] [stealaneggguide](https://stealaneggguide.wiki/guides/who-made-steal-an-egg/), [fandom](https://roblox.fandom.com/wiki/And_Collect_Rare_Pets/Steal_An_Egg)
- **CCU conflict:**
  - RoVitals' recorded peak is **14,272,591 on 19 Sep 2026**. [S] [rovitals](https://rovitals.com/game/107778070777162)
  - The earlier note quotes rblxdb at **2.15M CCU, #1 in Sept 2026**. [S] (`vibrant_maps.md`)
  - Both agree it was the #1 game in September 2026.

**Loop**
- "raid guarded nests across multiple biomes, sprint back to your base with an egg, hatch it into a pet, and watch that pet generate passive income every second." [S] [games.gg beginner](https://games.gg/roblox/guides/steal-an-egg-beginner-guide/)

**Map**
- "biomes are laid out as **one long map**, and **Speed is the only stat** that decides how far down it you can safely rob."
- Minimum Speed per biome:

  | Biome | Min Speed |
  |---|---|
  | Forest | 0 |
  | Lake | 900 |
  | Desert | 10K |
  | Jungle | 40K |
  | Snow | 170K |
  | Volcano | 700K |
  | Abyss Ocean | 2.5M |
  | Prehistoric | 17M |
  | Cosmic | 700M |
  | Cherry Blossom | 2.5B |
  | Titan Temple | 7B |

- Each biome has a guardian: Chicken, Swan, Scorpion, Tiger, Yeti, Hellhound, Moby, T-Rex, Dragon, Nine-tailed Fox, Gorilla King.
- That's about ×4–×10 between neighbouring biome gates.

[S] [allthings.how biomes](https://allthings.how/steal-an-egg-every-biome-and-its-minimum-speed-requirement/), [eldorado](https://www.eldorado.gg/blog/steal-an-egg/steal-an-egg-biomes-and-speed-requirements/)

**Chase**
- "The zone's guardian wakes up, **turns red** and chases you, and it **speeds up the further you run**." "Holding an egg reduces your movement agility." [S] [steal-an-egg-game.wiki guardians](https://steal-an-egg-game.wiki/guide/guardians)

**Base and treadmill**
- "Every player has a **personal Treadmill permanently located in front of their base**. At Level 1… +1 Speed with every step." [S] [sportskeeda beginner](https://www.sportskeeda.com/roblox-news/steal-an-egg-a-beginner-s-guide)
- Conflict: another guide says the treadmill unlocks with the **first $1,000 base upgrade**. [S] [games.gg beginner](https://games.gg/roblox/guides/steal-an-egg-beginner-guide/)

**Join rewards**
- Liking, favouriting and joining the group gives **10,000 free speed immediately**. [S] [games.gg beginner](https://games.gg/roblox/guides/steal-an-egg-beginner-guide/)

**Visuals**
- "colorful trails and leave a glowing effect behind you while you sprint". Trails are also multipliers. [S] [freetopgames](https://freetopgames.io/steal-an-egg)
- The repo's own rebuild (`steal-an-egg/`) models it as a walled canyon of checkered zone floors with sloped dirt walls and grass tops, and a red safe-zone line. [R] `steal-an-egg/README.md`
- That rebuild uses ClockTime 10.5, ColorCorrection Saturation 0.25 and Bloom 0.6/28/1.1. [R] (via `vibrant_maps.md`)

### Look-alikes

**Break and Steal an Egg**
- You **break** eggs with a pickaxe (the Wooden Pickaxe has 1 Power).
- Speed-gated zones:

  | Zone | Speed needed |
  |---|---|
  | Forest | 5 |
  | Desert | 1,000 |
  | Snowy | 50K |
  | Candy | 750K |
  | Swamp | 12M |
  | Ocean | 150M |
  | Hell | 1B |
  | Blossom | 5B |
  | Galaxy | 25B |

- The **Safe Zone** holds your Pen, the Pickaxe Shop, the Trails Shop and a merging machine.

[S] [sportskeeda zones](https://www.sportskeeda.com/roblox-news/all-zones-break-steal-egg), [sportskeeda beginner](https://www.sportskeeda.com/roblox-news/break-and-steal-an-egg-a-beginner-guide)

**Steal A Brainrot Egg**
- Created 23 Aug 2026, 13.6M plays.
- **6-player servers**, average session **9.41 min**.
- "**Every 5 minutes it's night** — all eggs reset and NEW ones spawn."
- Offline hatching.

[S] [rolimons](https://www.rolimons.com/game/126016859830524)

Also seen: "Steal An Egg Brainrot" and "Steal & Hatch Brainrot Eggs". [S] (roblox.com listings)

---

## 4. Grow a Garden and Grow a Garden 2 (the same "bright, readable, straight-into-gameplay" look)

**Grow a Garden**
- "a large island with **4 Garden Plots** (formerly 6 until the developers changed the server size), **shops at the sides** of the map and an **event hub in the middle**."
- Each plot is "fully fenced" with sub-plots and a small decorative lake with rock borders.
- A "massive rock mountain backdrop", with outer edges "heavily decorated with surrounding trees, flowers, mushrooms".

[S] [growagarden fandom Map](https://growagarden.fandom.com/wiki/Map)

**Grow a Garden 2** (12 Jun 2026)
- A "**circular map where player gardens surround a central hub**" with the shops, plus stealing and a day/night cycle. [S] (via `vibrant_maps.md`)

**[I] Lessons for Hood**
- The player's own plot is the spawn, and the shops are a few seconds' walk across one open plane.
- Server size is cut so the map stays small and every plot stays visible.
- The heavy decoration sits at the **edges**, and the play floor stays clean.

---

## 5. Common traits across all of these

| Trait | Evidence | Value to copy |
|---|---|---|
| **Join → first reward** | Superhero: click = +1 immediately. Keyboard Escape: on the track, free treadmill at spawn, Stage 1 = a couple of gaps for 1 Win. SaB: $100 start, $25 first buy, $1/s. Steal an Egg: 10K free speed for like/fav/group. [S] | Stat ticks within **1 s**. First "purchase/unlock" within **≤30 s**. First stage clear within **≤60 s**. |
| **Bounce window** | Roblox's June 2026 algorithm counts "bounce rate" (the % leaving within **60 s**) as a ranking factor. Aggregator advice says a simulator player should be "clicking, collecting, and seeing numbers go up before the first minute ends", and "every second of non-gameplay in the first five minutes costs… 2–3% of your new player cohort". [S] [sozai transcript](https://sozai.app/transcript/roblox-algorithm-changes-june-2026/), [rolearn](https://rolearn.dev/guidance/first-week-retention-optimization/) (low-authority) | No intro screens and no forced dialogue. Teach contextually: a bouncing arrow or glowing trail to the next thing (official [Onboarding techniques](https://create.roblox.com/docs/production/game-design/onboarding-techniques), via the repo notes). |
| **Core-loop cadence** | "first tap-to-reward cycle fits inside **15–20 seconds**". [S] [game-ace](https://game-ace.com/blog/roblox-simulation-games/) | Something pays out every 15–20 s early on: a gate, a bag unlock, a look. |
| **Server size** | SaB 8 (one per base). GAG cut 6 → 4 plots. Steal A Brainrot Egg 6. [S] | 8–12 for Hood, so the lane looks busy but you still see your own progress. |
| **Spawn placement** | On your base (SaB, GAG), in the Safe Zone with your pen and treadmill (Steal an Egg / Break and Steal), on the track (Keyboard Escape), in Start City with click-to-train live (Superhero). [S] | Spawn **at the start of the lane**, beside the first free trainer, facing Stage 1. |
| **Layout spine** | Central red carpet (SaB). One long biome corridor (Steal an Egg). Hallway of Levels (Superhero). Stage course (Keyboard Escape, Speed Evolve). Central hub (GAG2). [S] | One straight street, with the hub at its mouth. |
| **Saturation and sky** | SaB uses "mostly default lighting… enhanced saturation". The team's remakes use Saturation +0.22 to +0.25. [S]/[R] | Use preset H1 from `vibrant_maps.md`: ClockTime ≈14.5, ColorCorrection Saturation ≈+0.22, low haze, Bloom threshold ≈1.1. |
| **Screen activity** | SaB's conveyor of walking characters. Keyboard Escape's keys pressing down with clicks and "bright objects fill the screen". Guardians chasing in Steal an Egg. Trails and auras. Boss countdowns and hourly raids. [S] | Always-moving set dressing on the lane, "+N" floaters, other players' overhead numbers, a server-wide "X cleared Stage 7!" ticker, and scheduled events. |
| **Re-skins** | SaB Easter (pink floor), Egg City, North Pole. [S] | Recolour the street weekly using the same geometry. |

---

## 6. Hood today vs the genre (gap check from the repo)

| What Hood has [R] | Genre norm | Gap |
|---|---|---|
| Spawn medallion at z = 108 inside a 150 × 95-stud walled courtyard. The Stage 1 gate is at z = 27, about **81 studs (~5 s) away**, behind a 32-stud gate opening (`SimulatorLobby.lua` L700–702, L759–783) | Spawn on or at the lane's start, next to a free trainer | Move spawn to within ~10 studs of the free Tire Bag, with Stage 1 in view about 30–40 studs ahead |
| Wall 1 needs **50 Power** (`Balance.WallBase = 50`, `WallGrowth 2.1`, 10 walls/map, design target FirstWall 1–60 s) | Stage 1 in under 60 s | Good: 50 Power at ×2 from the free bag is about 25 s |
| Gate force field turns red → green, sparks, camera kick, "STAGE N CLEARED +Cash" banner (`Stages.client.lua`, `StageService.server.lua`) | Same, plus a **yellow Win pad that pays and teleports you home** | Optionally add a pad + "Back to the Block" teleport after each cleared stage |
| 15 looks in the Drip Shop on three rows; locked bags shown as black silhouettes | Evolution lineup on a pedestal with silhouettes and prices; an overhead title | Add an "Evolution Wall"/podium lineup by spawn and an overhead `Title · ⚡Power` billboard |
| Crew pets and eggs planned, not built | Eggs on plinths in the lobby; first egg affordable within the first 5–10 min | Place 3–4 egg plinths beside spawn |
| Passive +1/s only | Every 2026 title adds an active verb (click/tap/step) | Add a tap-to-punch bonus (e.g. +10% of per-second gain per tap, capped) |

---

## 7. Design rules to copy into Hood

Each rule says where it comes from:
- **[S]** = directly supported by a sourced fact above
- **[I]** = my recommendation, built from the sourced pattern

### Spawn and the first minute

1. **Spawn on the street, not in a plaza.**
   - Put the SpawnLocation within **6–10 studs of the free Tire Bag** (×2).
   - Face it down the lane (−Z).
   - The **Stage 1 gate should be 30–40 studs ahead** and fully on-screen from the spawn camera.
   - Compare today's ~81 studs inside a walled courtyard. Precedent: Keyboard Escape's free treadmill "right at the spawn area". [S]+[I]
2. **The first number goes up in the first second.** Show a "+1 ⚡" floater above the head and on the HUD every tick, from the moment the character loads. Use no splash screen or dialogue before control. [S]+[I]
3. **Stage 1 inside 30 s.** Keep `WallBase = 50`. At ×2 from the free bag that's about 25 s. Wall 2 (105) should land at about 60–75 s, once Duct Tape Bag ×3 is affordable at 50. [S] (Keyboard Escape Stage 1 = 1 Win, a couple of gaps)
4. **Free join boosts:** a one-tap "Like + Favourite + Join group" reward of a **permanent +10% Power** that survives rebirth. Precedents: Speed Evolve +10%, Steal an Egg 10K speed, Keyboard Escape 15K per action. [S]

### Layout

5. **One straight lane.**
   - Run the 10 gates of a map down one straight street, **40 studs wide** (matches `HalfWidth = 20` in `StageService`).
   - Space gates **60–80 studs apart** (4–5 s at WalkSpeed 16).
   - Put the hub (bags, Drip Shop, evolution lineup, eggs, leaderboard) at the street's mouth, within a **40-stud radius of spawn**.
   - [S] pattern (hallway of Levels, one long biome corridor) + [I] numbers
6. **Sawtooth loop.** After each newly cleared gate, put a **10–12-stud-diameter Win pad** in a short safe pocket. Make it yellow, `#FFD400`, Neon rim, label "+CASH". Stepping on it pays and offers **"Back to the Block"** (teleport to spawn). Players then spend and walk back out. Precedents: Keyboard Escape and Speed Evolve yellow pads; Superhero purple/yellow; Muscle green/yellow. [S]
7. **The next world is a big door at the end of the street.** Clearing gate 10 lights a **"MOVE TO THE SUBURBS →"** portal/teleport button. Superhero Evolution unlocks its World 2 Teleport button the same way. [S]

### Stage gates

8. **Gate shape.**
   - A full-width frame: **40 studs wide × 20–24 studs tall**, with pillars **4 × 4 studs**.
   - A **2-stud-thick translucent force-field slab** (Transparency 0.35, ForceField or Neon material).
   - Make it tall enough that you can't jump it (≥10 studs per Roblox greybox guidance; 7.2-stud default jump).
   - [I], with the jump numbers from the building notes
9. **Gate text.**
   - **Top beam:** "STAGE 3", **6–8 studs tall** letters, LuckiestGuy or FredokaOne, white fill with a **4–6 px near-black stroke**.
   - **Slab face:** "⚡ 2.2K" requirement, compact-formatted.
   - **Both sides:** a "**You need 1.4K more**" line plus a **horizontal fill bar** that tracks your Power.
   - Signs must read from the previous gate, 60–80 studs away. [S] (stage signs show requirements) + [I] sizes
10. **Lock-state colours.** Keep the existing locked **(255,60,90) `#FF3C5A`** and open **(70,255,140) `#46FF8C`**. Add a lock icon when locked. When it flips to open: a **0.3 s scale-pulse**, a chime, and a floor arrow lighting up. [R]+[I]
11. **The street is a rainbow progress bar.** Give gate frames and the floor strip before each gate one hue in order:

    | Stage | Colour | Hex |
    |---|---|---|
    | 1 | green | `#3DDC5A` |
    | 2 | teal | `#1FD1C1` |
    | 3 | sky | `#2BA8FF` |
    | 4 | blue | `#4F63FF` |
    | 5 | purple | `#8B5CFF` |
    | 6 | pink | `#FF4FB6` |
    | 7 | red | `#FF3B3B` |
    | 8 | orange | `#FF8A1F` |
    | 9 | gold | `#FFC21A` |
    | 10 | black frame + gold/rainbow Neon trim (boss gate) | n/a |

    Keep the lock/open colours as the only red/green on the slab itself. Precedent: "100+ rainbow stages" in Wall Punch Simulator, and colour-themed biomes in Steal an Egg. [S]+[I]
12. **Breaking through is the money shot.** On first clear:
    - the slab shatters into **8–14 coloured chunks** (unanchored for 1.2 s, then fade)
    - **0.06 s hit-stop**
    - camera shake
    - a full-width "STAGE 3 CLEARED! +X Cash" banner (already built)
    - a **server-wide ticker** line, "Tay cleared Stage 7!"
    
    [R]+[I]
13. **Reward ladder.** Pay roughly **×2–×3 more per stage**, with a bigger jump on stages 5 and 10 ("boss" gates). Keyboard Escape's W1 runs 1 → 3 → 10 → 20 → 60 → 100 → 150 → 300 → 500 → 1,000 → … → 150,000. [S]

### Evolution, titles and pets

14. **Evolution lineup at spawn.**
    - Put all 15 looks on **numbered podiums in one arc or row** (an "Evolution Wall"), visible from spawn.
    - Owned looks are in full colour. Locked ones are **black silhouettes** with a price tag (reuse the bag silhouette code).
    - The next affordable one gets a bouncing arrow.
    
    Precedent: Superhero Evolution's "massive pedestal in the lobby". [S]+[R]
15. **Evolving is an event.** Each new look gets:
    - a white flash
    - a **2–3 stud size or proportion bump** for higher tiers
    - a coloured **aura** from tier 6 up
    - a centre-screen title card
    
    Precedent: "Each form changes your appearance". [S]+[I]
16. **Overhead identity.** Each player gets a BillboardGui **6 studs wide** showing `TITLE` (look name, tier-coloured) over `⚡ 12.4K`, readable at **100+ studs**, so other players' progress fills the screen. [I] (pattern from the repo's Keyboard Escape remake [R])
17. **Eggs by spawn.**
    - Put **3–4 egg plinths** on one side of spawn, each with a price billboard.
    - The **first egg must be affordable within 5–10 minutes**, with pets ×1.5–×3.
    - Robux eggs go at the end of the row with a gold/rainbow treatment.
    
    Precedents: Superhero Basic Egg 10 Wins with ×2–×10 pets; Muscle "eggs displayed in the lobby". [S]+[I]
18. **Multipliers stack visibly.** Show Power/sec as a product on the HUD (`+1 × Bag ×6 × Look ×3 × Crew ×2 = 36/s`). Keep every layer multiplicative, as Speed Evolve does with trails × auras × rebirth × group. [S]
19. **Rebirth.**
    - First rebirth available at about **20–30 min**, for **×2**.
    - Keep a sliver of progress (Superhero keeps **25% Power**).
    - Unlock better bags at fixed rebirth counts (Superhero: about 15/30/50/100).
    
    [S]

### Look, UI and "always active"

20. **Bright default day plus saturation.** Use preset **H1** from `vibrant_maps.md`: ClockTime ≈14.5, Atmosphere Haze ≈0.25 with Offset ≈0.55, ColorCorrection **Saturation +0.22 / Contrast +0.10**, Bloom 0.6/28/**1.1**, Default tonemapper. The dusk "Block Party" look becomes an event, not the default. Precedent: SaB's "mostly default lighting… enhanced saturation". [S]+[R]
21. **Simple geometry, loud colour.** Gates, pads and podiums are boxes and cylinders in **SmoothPlastic + Neon trim**. Spend the detail budget on signage, colour and motion, the way SaB's base is just "walls, a roof, a spawner, a sign, and lasers". [S]
22. **HUD.**
    - **Top-centre:** Power counter with a floater.
    - **Left column:** 4–5 big square buttons (Shop, Crew, Rebirth, Codes, Teleport).
    - **Mobile:** a big **PUNCH** button bottom-right. Each tap adds a bonus and plays the punch animation.
    
    Precedent: Superhero's sidebar Store/Rebirth plus its mobile Power button. [S]+[I]
23. **Keep the lane moving.** At least one moving element in every screen-width of street: traffic crossing at intersections, swinging bags, bobbing signs, a train or bus passing on a timer. That gives the "bright objects fill the screen" feeling of Keyboard Escape and the never-empty conveyor of SaB. [S]+[I]
24. **Scheduled social beats.**
    - A **server boss or "Block Party" every hour at a fixed minute** (Superhero: XX:30 raids) with an in-world countdown board at spawn.
    - A weekly re-palette of the street (SaB's Easter/Egg City/North Pole re-skins).
    
    [S]
25. **Server size 8–12.** It keeps the lane populated and readable. Precedents: SaB 8, Steal A Brainrot Egg 6, GAG cut its plots from 6 to 4 for server size. [S]

---

## Gaps

- **No screenshots or videos were viewable** (YouTube, Fandom, DevForum and Roblox pages were all blocked). So the **exact geometry, colours and sizes** of the +1 games' stage walls, pads and lobbies are **not sourced**. §1.6 and the sizes and hex values in the rules are recommendations.
- I couldn't read any first-hand Superhero Evolution or Muscle Evolution lobby layout: distance from spawn to the bags, eggs and stage entrance.
- **Conflicting metadata:**
  - +1 Speed Evolve's creator and date (Mauv +1 / 19 Apr 2026 vs aib games / 2 Dec 2025)
  - Steal an Egg's peak CCU (14.27M on RoVitals vs about 2.15M on rblxdb)
  - Keyboard Escape's 6.2M peak (Aug) vs 127k CCU at #8 (June)
- I didn't verify the content of the DevForum "How to make Steal a Brainrot" series or the BuiltByBit kits (part sizes, materials). Only their titles and summaries were available.
- The search budget ran out before I could cover Grow a Garden's onboarding timing, Steal an Egg's exact base geometry, or fresh "Evolution" titles from September–October 2026 beyond those listed.
