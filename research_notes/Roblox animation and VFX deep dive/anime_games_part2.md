# Roblox anime games, part 2: the games part 1 missed, summon odds, and sound design (Oct 31 2026)

This extends `anime_games_study.md` in the same folder. Read that first; nothing here repeats it.

**How much this note could check.** Searches return page titles only, and web-page fetches were rate-limited and shared across agents. I read 8 pages in full; 1 more failed.
- **Cited:** I read the page myself.
- **Title only:** a page with that title exists, but I couldn't read it.
- **[I] = estimated:** my own read from general knowledge of the genre, not verified this session. Check it on a 30 fps video before using a number.

A warning on sources: many search results for these games are auto-generated spam on unrelated domains (`*.pages.dev`, university or council subdomains with titles like "Comprehensive Guide"). I used none of them.

Project rule: learn the patterns only. Never copy these games' move names, character names, meshes, textures or sounds.

## Blox Fruits / King Legacy: fruit awakenings, V4 race awakening, fruit rarity on the fruit itself

### Takeaway
Blox Fruits ties its biggest visual power-up (Race V4) to a long, social, world-event unlock: a full moon, a party of different races, and a temple trial. The look and feel of the activation itself (glow, meter, duration) was not in any page I could read. The unlock is the "cinematic moment"; the activation visuals stay a gap.

### Cited Findings
- **Race V4 unlock chain:**
  - The quest opens trials at a temple.
  - Step 1 needs a level-5000 raid boss whose spawn is signalled by "a thick fog". That is a world-wide visual cue before a big event.
  - The trial needs a party of "at least two other players of different races". Each player stands at their race's door and uses their racial skill and the levers at the same time.
  - It requires a **full moon**.

  — [Gfinity Race V4](https://www.gfinityesports.com/roblox/blox-fruits-race-v4/)
- **A moon cue:** on a special island during a full moon, the player uses the racial skill and has their character "stare at the moon". The moon "should glow" after a few seconds, and a "hidden blue gear" spawns somewhere on the island. — [Gfinity](https://www.gfinityesports.com/roblox/blox-fruits-race-v4/)
- **Progress after the unlock:** "The first run unlocks Awakening without any passives"; later runs let you spend points on passives, "with each run becoming harder and harder." The guide gives no activation key, meter, duration or visuals. — [Gfinity](https://www.gfinityesports.com/roblox/blox-fruits-race-v4/)
- Fruit-awakening guides exist on Twinfinite, Gfinity and WePC (titles only). — [Twinfinite](https://twinfinite.net/guides/how-you-awaken-fruits-blox-fruits/?amp=1); [Gfinity](https://www.gfinityesports.com/article/blox-fruits-awaken-fruits); [WePC](https://www.wepc.com/gaming/blox-fruits-how-to-awaken-fruits/)

### Inferences
- [I] **The pattern to copy:** announce a big event to the whole server with an environmental cue (fog, a glowing moon, a sky colour change) a few seconds before it. Make the unlock a group moment, where players act together at once.
  - This fits GAME-FEEL.md's "cinematic moment" and "rescues/co-op" ideas.
  - It's kid-safe if it never needs paid items.
- [I] **Usual fruit-awakening and transformation staging (not verified this session):**
  - a short crouch-and-burst power-up with an invulnerability window;
  - a ring shockwave;
  - a model swap or accessory (wings, a beast form) welded on;
  - a looping aura in the fruit's accent colour while it's active;
  - a camera FOV punch (wider for about 0.2 s, then back).

  Treat these as estimates and check them on a showcase video.
- [I] **Fruit rarity on the fruit (Blox Fruits style):** the spawned fruit is a coloured, recognisable mesh in the world, with a name, rarity colour and despawn timer on hover. Rarer fruits are told apart by their unique shape more than by glow.
  - For our games: put the rarity colour in a small BillboardGui label and a soft PointLight, not a strobe.

### Gaps
- What the Race V4 activation looks like: the glow pattern, whether there's a meter, duration and sound. No readable source.
- Per-fruit awakening visuals for Blox Fruits and King Legacy: the wiki pages couldn't be fetched within the budget.
- King Legacy: nothing found beyond titles.

## Signature move staging: GPO / Rell Seas, Shindo Life, Project Slayers / Demonfall, YBA / Sakura Stand, Peroxide / Type Soul

### Takeaway
The pattern across these RPGs:
- the big form (a Bankai-style release) is earned through a long, multi-stage quest that ends in a boss fight and a cutscene;
- in combat it's a key combo fed by a meter you charge by fighting;
- move families are themed by element, and each element's "feel" is described by its motion (flowing multi-hit, near-instant dash, obscuring mist), not by its numbers.

### Cited Findings
- **Type Soul release progression (the Bleach-style Shikai/Bankai):**
  - Stage 1: win 13 raids, 7 clan wars or 26 ranked matches. An NPC reports progress in 20% steps (0/20/40/60/80/100%).
  - Stage 2: 80 NPC kills, 15 "grips" and 1 boss kill **without dying**. Dying resets the counters.
  - Stage 2.5: a search for three swords with three mistakes allowed. A wrong click shows floating lines pointing to the next sword.
  - Stage 3: meditate, then fight your own weapon spirit as a boss. Beating it "triggers a cutscene and grants the Bankai powers".

  — [Twinfinite Type Soul Bankai](https://twinfinite.net/guides/all-bankai-progression-type-soul/)
- **Type Soul activation:**
  - J = first release, Ctrl+J = the full release, T and G = the powers.
  - "The Bankai meter must have charge. Fill it by killing players or NPCs, or the powers won't activate."
  - The guide doesn't describe auras, transformation visuals or durations.

  — [Twinfinite](https://twinfinite.net/guides/all-bankai-progression-type-soul/)
- **Project Slayers breathing styles, described by motion and theme:**
  - Flame: "powerful, quick slashes and burn damage over time".
  - Mist: "very fast sword slashes hide the user's own movements".
  - Snow: quick swings, jabs and strikes, swift area attacks.
  - Water: "flowing, multi-hit attacks that can knock enemies back".
  - Wind: far-reaching gusts.
  - Thunder: near-instant speed, where "the ground under the user breaks and degrades, and the air vibrates with loud cracks".
  - Sound: explosive damage visuals.
  - Beast: erratic combo extenders.
  - Insect: high-speed thrusts that puncture rather than slash, with poison on the blade.

  Players rank the styles by effectiveness; the tier list doesn't discuss animation or effects quality. — [eXputer breathing tier list](https://exputer.com/guides/tier-lists/project-slayers-breathing/)
- Shindo Life has "Modes" you get and activate, with sub-abilities, tier-listed with "Spirits" (titles only). — [GamerEmpire Modes guide](https://gamerempire.net/shindo-life-modes-guide/); [Sportskeeda Mode sub-abilities](https://www.sportskeeda.com/roblox-news/5-best-mode-sub-abilities-roblox-shindo-life)
- Type Soul beginner guide (four races) and "True Bankai" requirements guide (titles only). — [ItemLevel](https://itemlevel.net/type-soul-complete-beginners-guide-soul-reaper-quincy-fullbringer-hollow/); [Deltia's](https://deltiasgaming.com/?p=369602)

### Inferences
- [I] **Element = motion signature.** Give each move family one motion verb and one ground reaction:
  - flowing (curved trails, multi-hit);
  - instant (a teleport dash with a straight streak and cracked ground at the start point);
  - hidden (a puff or mist cloud that hides the wind-up);
  - piercing (thin straight thrust lines, not arcs).

  Our version: "splash / zap / puff / poke" families in bright colours, with no anime names.
- [I] **Earned transformation = a quest arc plus a self-boss fight plus a cutscene.**
  - The "fight your own inner spirit" idea is a strong, IP-free story beat for kids: a mirror version of the player's own avatar.
  - The progress NPC with 20% steps is a cheap, clear progress UI.
  - Kid-safe change: Type Soul resets on death. Use checkpoints instead.
- [I] **A meter-gated form** (charge by fighting, then a key to release) matches the battlegrounds Awakening in part 1. It's the shared genre convention.
- [I] **Stand-style summon** (YBA / Sakura Stand, not verified):
  - a guardian figure fades in behind the shoulder: transparency 1 to 0.3 over about 0.25 s, with a small upward drift;
  - a pose plays;
  - the figure then mirrors the user's attacks with a rapid "barrage" of many short punches.

  Kid-safe and IP-free: a pet buddy that pops out behind the player with a sparkle ring.

### Gaps
- GPO, Rell Seas, Peroxide, Demonfall, YBA and Sakura Stand: no readable source this session (spam results or titles only).
- No frame data or seconds for any of these transformations.
- What players praise about the animation feel: no review or Reddit text was reachable. Next step: Reddit threads and showcase-video comments.

## Anime TD summon animations (Anime Defenders / Anime Last Stand / Anime Adventures) and evolve animations

### Takeaway
I confirmed full odds and pity tables for Anime Last Stand, and that shinies in Anime Defenders are "simple recolors". Paid luck boosts there have **undisclosed** effects, which breaks our rules. No source described the reveal animation itself.

### Cited Findings
- **Anime Last Stand banner odds (wiki):**
  - Banner 2: Ultimate 0.01%, Celestial 0.5%, Mythic 2% each (2 units), Legendary 5.5%, Epic 12%, Rare 80%.
  - Banner 3: Ultimate 0.3%, Celestial 1.25% each (2 units), Mythic 5% each (2 units), Legendary 22%, Epic 30%, Rare 40.2%.
  - Banner 1: Mythic 0.5%, Legendary 2%, Epic 27.5%, Rare 70%. As listed it adds up to more than 100%, so the wiki itself is ambiguous here.

  — [ALS Wiki Summoning Banners](https://alsroblox.fandom.com/wiki/Summoning_Banners)
- **Anime Last Stand pity:**
  - Banner 1: Legendary at 60 summons (3000 currency, 2400 with VIP); Mythic at 250 (12,500, or 10,000 with VIP).
  - Banner 2: Mythic at 100, Celestial at 250.
  - Skin banner: Legendary at 10, Mythic at 30.
  - Event banners: pity of 10–25, and 500 for a Secret unit.
  - A Halloween shiny unit has "no pity".

  — [ALS Wiki](https://alsroblox.fandom.com/wiki/Summoning_Banners)
- The ALS wiki doesn't state a shiny chance and doesn't describe the summon animation or evolution. — [ALS Wiki](https://alsroblox.fandom.com/wiki/Summoning_Banners)
- **Anime Defenders shinies** are "simple recolors of the standard characters".
  - Paid boosts: a Shiny Hunter Pass at **1299 Robux**, and Lucky / Super Lucky potions at **99 / 149 Robux**.
  - The guide says of the boost: "We don't know the exact measure to which it rises."
  - It recommends about 2000–5000 gems "to help the pity system work in your favour".

  — [ProGameGuides AD shiny](https://progameguides.com/roblox/how-to-get-shiny-characters-in-anime-defenders-roblox/)
- "How Evolutions work in Anime Defenders" exists (title only). — [Sportskeeda](https://www.sportskeeda.com/roblox-news/how-evolutions-work-anime-defenders)

### Inferences
- [I] **Rarity ladder colours (the genre convention, not verified for these games):** Rare blue, Epic purple, Legendary gold, Mythic red or rainbow, top tier (Secret, Celestial, Ultimate) rainbow or white-black.
  - Use one more beam or ring per tier, more shake, and a longer hold on the reveal pose for higher tiers.
  - Shiny = the same unit with a hue shift plus a sparkle loop and a "Shiny" tag.

  Check on an "all summon animations" video before copying any timing.
- [I] **ALS has 6–7 rarity tiers.** Tiers this fine need a strong colour language, otherwise players can't tell Celestial from Mythic.
  - For a kid game, 4–5 tiers is enough. Higher tiers should add *motion* (rings, beams) rather than only new colours.
- [I] **Evolve/upgrade animation:** the unit glows white and its silhouette flashes once; the new model pops in with a burst and a stat-up card. Keep it to one flash (project rule: at most 1 flash per second).

### Gaps
- Summon reveal timing (seconds per beat), beam counts and colours for ALS, AD and Anime Adventures: no readable source. Next step: frame-step summon-showcase videos at 30 fps.
- Anime Adventures: nothing current found.

## Sound design for anime games: impact layering, risers, stingers, mix levels, royalty-free sources

### Takeaway
A good hit has four layers, each in its own frequency band:
- a transient crack above 1 kHz;
- a mid body near 200 Hz;
- a falling sine sub at 30–60 Hz over about 200–400 ms;
- a short dark reverb tail on the body only, with the sub kept dry.

Game hits should stay a few hundred ms long. Big SFX sit louder than music (roughly music at about −20 dB, hits at −20 to −10 dB).

### Cited Findings
- **The four layers:**
  - Transient: "a short, bright crack, mostly above 1 kHz" (snare, clap, stick hit or a fast noise burst, trimmed to the click).
  - Body: mid-range weight from a tom, kick, metal hit or synth stab.
  - Sub: "a low sine that drops in pitch", "the part you feel more than hear".
  - Tail: "a long, dark reverb on the body only. Keep the sub dry."

  — [Violet Recording: impact sounds](https://violetrecording.com/how-to-make-impact-sounds/)
- **Numbers (same source):**
  - sub at about 30–60 Hz, not much below 30 Hz;
  - high-pass everything below about 25 Hz;
  - the sub pitch drops from high to low over about **200–400 ms**;
  - two body layers both near 200 Hz will cancel and muddy, so EQ each layer into its own band;
  - trigger all layers on the same downbeat;
  - game and UI hits stay "a few hundred milliseconds", while trailer stings ring 800 ms or more.

  — [Violet Recording](https://violetrecording.com/how-to-make-impact-sounds/)
- **Processing:** bus-compress the layers to glue them, without squashing the transient's crack. Saturate the body and transient so the hit "cuts through, especially on small speakers". — [Violet Recording](https://violetrecording.com/how-to-make-impact-sounds/)
- **Mix levels (rule of thumb, from a film-leaning article):**
  - music at about −20 dB;
  - footsteps and ambience at about −20 dB;
  - hits and cracks between −20 and −10 dB, with peaks higher;
  - in games, sound design is "quite loud in the mix" because it gives player actions weight;
  - test on phone speakers, earbuds and TVs.

  — [Krotos: balancing music and SFX](https://krotos.studio/blog/how-to-balance-music-and-sound-effects)
- Music masters are around −14 LUFS (streaming). The page gives no game LUFS target. — [Krotos](https://krotos.studio/blog/how-to-balance-music-and-sound-effects)
- Audiokinetic (Wwise maker) has a loudness best-practice series for games (title only). — [Audiokinetic](https://blog.audiokinetic.com/loudness-processing-best-practice-chapter-3-scalable-loudness-processing-for-games/)

### Inferences
- [I] **For `make_sfx.py` (synthesised, so no licensing issue):** build each hit from four parts:
  1. a noise burst with a high-pass around 1–2 kHz and 10–30 ms decay;
  2. a sine or triangle stab near 150–250 Hz with about 80 ms decay;
  3. a sine sweep from about 120 Hz down to 45 Hz over 250 ms;
  4. a short low-passed reverb tail on part 2 only.

  Then saturate lightly. Scale by tier: a light M1 hit uses only parts 1 and 2; the finisher uses all four.
- [I] **Charge riser:** a rising noise and sine sweep over the charge time (0.5–1.5 s), getting louder and higher.
  - Cut it to near-silence for about 0.1–0.15 s just before the release.
  - Then fire the full four-layer hit plus a stinger: a short bright chord or "shing" under 1 s.
- [I] **Mix rules for Roblox:**
  - Music SoundGroup is quieter than SFX (start music Volume at about 0.3–0.4 and big SFX at 0.8–1.0, then adjust by ear).
  - Duck music by about 50% for 0.5 s on an ultimate.
  - Phones cut sub frequencies, so the transient and saturated body must carry the hit by themselves.
- [I] **Royalty-free sources:**
  - generate our own (preferred, per project rules);
  - CC0 libraries such as Kenney audio packs and freesound.org, filtered to CC0 only;
  - the Roblox Creator Store audio, which is licensed for use in Roblox.

  Never rip anime shouts or voice lines. (These sources come from general knowledge, not checked this session.)

### Gaps
- Real audio breakdowns for any named Roblox anime game. None found; searches returned spam sites only.
- No game-specific LUFS target was in a source I read (the Audiokinetic page was title only).

## 2025–2026 newcomer anime hits and what they changed

### Takeaway
Not verified. The one list page for 2026 failed to load, and the other results were generic or spam.

### Cited Findings
- A "10 best anime games in 2026" list exists (title only; the fetch failed). — [PlayNews](https://www.playnews.gg/en/guides/roblox-the-10-best-anime-games-in-2026)
- Other lists exist (titles only). — [PocketGamer best anime games](https://www.pocketgamer.com/roblox/best-anime-games/); [Deltia's top 10 anime 2025](https://deltiasgaming.com/?p=126801)

### Inferences
- [I] Part 1 already lists Anime Vanguards and AFS Endless as recent hits. The trend in the genre is TD/gacha plus battlegrounds, with ever-finer rarity ladders and paid luck boosts. That trend is exactly where our kid-safe rules push us the other way.

### Gaps
- Which 2025–2026 anime titles broke out, and what they changed in animation or VFX. Next step: re-fetch the PlayNews and PocketGamer lists when the budget allows.

## Kid-safety flags found in this round
- **Undisclosed paid luck (breaks our rules):** Anime Defenders sells a 1299-Robux Shiny pass and 99/149-Robux luck potions, and a guide says the effect size is unknown ("We don't know the exact measure"). Never sell luck without stating the exact new odds. — [ProGameGuides](https://progameguides.com/roblox/how-to-get-shiny-characters-in-anime-defenders-roblox/)
- **Extremely low top odds and no pity:** ALS has Ultimate at 0.01%, and a shiny event unit with "no pity". Every paid random item we make has a pity counter. — [ALS Wiki](https://alsroblox.fandom.com/wiki/Summoning_Banners)
- **VIP discounts on pity cost:** ALS pity costs 2400 instead of 3000 with VIP. That's a pay-to-gamble-cheaper loop; don't copy it. — [ALS Wiki](https://alsroblox.fandom.com/wiki/Summoning_Banners)
- **Harsh resets:** Type Soul resets progress counters on death. That's frustrating for kids; use checkpoints. — [Twinfinite](https://twinfinite.net/guides/all-bankai-progression-type-soul/)
- **Combat themes:** "burn damage", "poison on the blade" and "puncture" thrusts (Project Slayers). Restyle them as cartoony elements (sparkle, bubble, zap) with no wounds. — [eXputer](https://exputer.com/guides/tier-lists/project-slayers-breathing/)
