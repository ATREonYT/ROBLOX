# Roblox anime games: how they animate, do VFX and get their feel (study, Oct 31 2026)

Scope: battlegrounds games (The Strongest Battlegrounds = TSB, Jujutsu Shenanigans = JJS, Heroes Battlegrounds), anime RPGs (Blox Fruits, King Legacy, GPO, Type Soul, Peroxide, Shindo Life, Rell Seas, Project Slayers / Demonfall, YBA, Sakura Stand), boxing (Untitled Boxing Game), and anime tower-defence / gacha (Anime Vanguards, Anime Defenders, Anime Last Stand, Anime Adventures, AFS Endless, Anime Champions Simulator).

**Read this first: how much this note could check.** The web-fetch budget is shared by every agent in the session, and it ran out after about 6 full-page reads (proxy message: "web-fetch budget for this session is exhausted: 100 per hour"). Searches still worked but only return page titles, with no text. So:
- **Cited** = I read the page myself, or the claim is only that a page with that title exists (marked "title only").
- **Estimated / [I]** = my own read from general knowledge of the genre. Not verified this session. Check on a 30 fps video before using a number.
- Rule from the project: learn the patterns only. Never copy these games' textures, meshes, move names, character names or sounds.

## Move design: M1 combos, dashes, ultimates/awakenings, cutscene ultimates, counters, transformations

### Takeaway
Each battlegrounds character has 4 base moves on number keys and a meter-fed "Awakening" that swaps in 4 different ultimate moves. A counter is a standard slot on most kits. Domain-style ultimates (JJS) take over the target for a fixed time, then leave the user drained, with every skill on cooldown and the meter empty. That built-in downside is the key design idea. I found no frame data (startup or recovery frames) on any source I could read.

### Cited Findings
- TSB: every character has 4 base moves. Awakening swaps in 4 ultimate moves "sometimes changing normal punches", and the meter builds through combat. One character's Awakening "has no timer" and each of its ultimates fires once; the guide says most other characters' Awakenings expire. The source gives no meter amounts or durations. — [allthings.how TSB roster](https://allthings.how/the-strongest-battlegrounds-character-roster-movesets-and-access-rules/)
- TSB kit archetypes the guide lists:
  - balanced beginner;
  - close-range grappler, with a counter in its base kit;
  - "fastest fighter, built on dashes", where missed ultimates carry less risk;
  - block-breaking heavy whose "long startup punishes misses", with a counter added during Awakening;
  - a sword user whose counter "stuns instead of knocking back" and which "rewards dash-cancel timing";
  - a multi-target grab psychic with lower damage per hit;
  - a rush brawler "with many stuns";
  - a ranged zoner "strong against groups";
  - a cyborg whose base moves are blockable but "chip damage gets through" and whose "finishers reset cooldowns".

  — [allthings.how](https://allthings.how/the-strongest-battlegrounds-character-roster-movesets-and-access-rules/)
- TSB also has a transformation (a "Monster Form" with its own 4 moves and 4 ultimates), and characters limited to events or admins, e.g. a summer boss that "spawns every 30 minutes", where the top three damage dealers each get one use of it. — [allthings.how](https://allthings.how/the-strongest-battlegrounds-character-roster-movesets-and-access-rules/)
- TSB has a "Skill Builder V2", a custom-moveset tool (title only). — [narcosis-the-game](https://www.narcosis-the-game.com/?p=2353)
- JJS domain-style ultimate:
  - It needs a full Awakening bar, then a two-key input (G+R). The guide calls the activation time "extremely short".
  - The targeted opponent is out for **7 s** while the user plays an extended rush. The full-area domain variant lasts **14 s** and "freezes every enemy nearby".
  - Afterwards "every skill is on cooldown and the Awakening meter is at zero", which leaves the user open in free-for-all.

  — [Sportskeeda JJS domain guide](https://www.sportskeeda.com/roblox-news/jujutsu-shenanigans-0-2-domain-guide)
- Untitled Boxing Game sorts its kits into "styles", with tier lists and a "knockout effects" cosmetic category (titles only). — [Pocket Tactics styles](https://www.pockettactics.com/untitled-boxing-game-styles/); [Bloxodes knockout effects](https://bloxodes.com/wiki/untitled-boxing-game/knockout-effects)
- A DevForum resource packages battlegrounds systems as modules: "ragdoll, stun, direction, cooldown" (title only). — [Battleground modulepack](https://devforum.roblox.com/t/battleground-modulepack-ragdoll-stun-direction-cooldown/3488881)

### Inferences
- [I] **The structure to copy:** 4 base moves, then a meter, then an Awakening state with 4 bigger moves and a changed look (aura, new M1 effects). The meter turns a long fight into one build-up and one payoff. For a kid game, the meter is the "cinematic moment" the project's GAME-FEEL.md asks for.
- [I] **Every big move has a cost** you can see: long startup (the heavy), a drained state afterwards (domain), or a cooldown on everything. That is what makes ultimates feel big without making them unfair.
- [I] **Usual M1 chain (estimated, not cited):** 4–5 hits, where the last hit is a launcher or knockback finisher. The finisher gets the big effect, a hit-stop and a camera shake. The first hits get small sparks only. Side dashes are short (about 0.3–0.4 s) and the front dash is longer. A dash-cancel (dashing out of a move's recovery) is the skill-ceiling mechanic.
- [I] **Cutscene ultimates:** on hit, the target is anchored and both rigs play a paired animation. The camera is scripted for about 2–5 s: a close-up of the attacker, then a wide shot of the impact. Other players keep their own camera. The [V] vault notes already cover the Moon Animator 2 camera export (see `rare_reveals_and_cutscenes.md`).
- [I] **Transformations** use a short invulnerable "power-up" animation (crouch, then arms out), a flash or shockwave ring, then a new aura that stays on the whole time. The rig often gets recoloured accents or a hair or eye swap.

### Gaps
- **No frame data was reachable.** I found no startup, active or recovery frames, and no cooldown seconds, for any TSB, JJS, Heroes BG, Type Soul, Peroxide or YBA move. Fandom pages couldn't be fetched (budget), and most guide sites leave numbers out. Next step: frame-step 30 fps move-showcase videos.
- **Not researched (budget):** Blox Fruits and King Legacy awakening mechanics, GPO and Rell Seas move timings, Shindo Life mode transformations, Project Slayers / Demonfall breathing styles, Sakura Stand and YBA stand summons, Peroxide and Type Soul resurrection forms.
- **2025–2026 newcomers:** none could be verified.

## VFX language: auras, shockwaves, impact frames, speed lines, craters and rocks, slashes, beams, domains, hit sparks, ragdoll

### Takeaway
The anime look in Roblox comes from a few stock pieces, each of which has open-source versions:
- **Impact frames:** a ColorCorrection set to full black-and-white with huge contrast for about 0.1 s, plus Neon or Highlight silhouettes.
- **Rock and crater modules** that copy the ground colour and recycle parts from a pool.
- **Mesh-based auras and slashes,** built in Blender and tweened, rather than particles alone.
- **Ragdoll knockback,** with known replication pitfalls.

### Cited Findings
- **Impact frame, open-source module (numbers from its source):**
  - Each effect is a `ColorCorrectionEffect` in Lighting.
  - "White" type: Saturation −1, Contrast **25000**, TintColor ≈ (0.64, 0.64, 0.65).
  - "Black" type: Saturation −1, Contrast **−25000**.
  - Default duration **0.1 s**.
  - Character parts are switched to Neon and recoloured to the tint, then restored. Highlights exist in the source, but the author avoids them because "highlights are not supported on mobile".
  - The module has Pause/Resume, which lines it up with hit-stop.
  - The page's example uses the wrong key names (`CustomSettings` / `Color` instead of `CustomProperties` / `TintColor`), so copying the example as written falls back to defaults.

  — [DevForum Impactframe Module](https://devforum.roblox.com/t/open-source-impactframe-module/2963136)
- Other DevForum threads on the same effect (titles only):
  - "Advanced impact frames": [link](https://devforum.roblox.com/t/advanced-impact-frames/2468478)
  - "Recreate impact frame and chromatic aberration": [link](https://devforum.roblox.com/t/recreate-impact-frame-and-chromatic-aberration-effect-in-roblox-studio/2892126)
  - "In-game silhouette effect": [link](https://devforum.roblox.com/t/in-game-silhouette-effect/2997599)
  - "How could I implement drawn impact frames": [link](https://devforum.roblox.com/t/how-could-i-implement-drawn-impact-frames/2591414)
  - "impact frame that has lines on the character without using an imagelabel": [link](https://devforum.roblox.com/t/2652420)
  - "Moon Animator not exporting particle or impact frame effect": [link](https://devforum.roblox.com/t/moon-animator-not-exporting-particle-or-impact-frame-effect/2927891)

  The last one shows that artists build impact frames inside Moon Animator, and that those effects don't come through the export on their own.
- **Rock modules:**
  - **Rocks Module, "Useful for Anime Games Skill Effects":** the author extended it to spawn rocks on walls. Calls take a surface normal from a raycast so the rocks face the surface. It added a fade-in and uses PartCache "to reduce lag". The thread names a GPO-style showcase as its origin. — [DevForum Rocks Module #23](https://devforum.roblox.com/t/rocks-module-useful-for-anime-games-skill-effects/1687374/23)
  - **"Punch Rock Module inspired by TSB":** "only the rocks on the ground in a line, not the craters or the ones that fly into the air". It uses ObjectCache for pooling and has no code comments. — [DevForum](https://devforum.roblox.com/t/punch-rock-module-inspired-by-tsb/3171422)
  - Many more exist (titles only):
    - [Battlegrounds crater module](https://devforum.roblox.com/t/battlegrounds-crater-module/3370194)
    - [Rock Module V1.0 – Craters, Explosions](https://devforum.roblox.com/t/rock-module-v10-craters-explosions-and-more-effects/3041562)
    - [Rock module based on TSB](https://devforum.roblox.com/t/rock-module-based-on-tsb/2894908)
    - [Crater system by Frodev](https://devforum.roblox.com/t/crater-system-by-frodev/2628508)
    - [How to make cool rocks stuff like GPO](https://devforum.roblox.com/t/how-to-make-cool-rocks-stuff-like-gpo/1457410/28)
    - [VoxelDestruct](https://devforum.roblox.com/t/voxeldestruct-voxelated-destruction-physics-with-greedy-meshing-hitboxes-and-more/3044264)
- **Ragdoll and knockback (titles only):**
  - [Ragdoll knockback lag (replication)](https://devforum.roblox.com/t/ragdoll-knockback-lag-replication-issue/2845470)
  - [Smooth/seamless ragdoll knockback](https://devforum.roblox.com/t/smoothseamless-ragdoll-knockback/3173710)
  - [InteractiveRagdoll, smooth on all clients, R6](https://devforum.roblox.com/t/interactiveragdoll-smooth-ragdoll-on-all-clients-r6-only/3042854/15)
  - [Problems with knockback for mobile players](https://devforum.roblox.com/t/problems-with-knockback-for-mobile-players/1979809)
  - A reply suggests Quenty's ragdoll module and says to set the player's state to Physics on the client. — [DevForum](https://devforum.roblox.com/t/how-would-i-make-a-knockback-ragdoll-for-a-combat-system/2049791)
- **Auras and slashes (titles only):**
  - [How do y'all make auras](https://devforum.roblox.com/t/how-do-yall-make-auras/1383893)
  - [How to make animated slash effects with only Blender](https://devforum.roblox.com/t/how-to-make-animated-slash-effects-with-only-blender/1794034)
  - [How to make a GPO-like sword effect](https://devforum.roblox.com/t/how-to-make-a-gpo-like-sword-effect/1509225)
  - [Anime aura VFX manual (Japanese)](https://nkdtr.hatenablog.com/entry/2022/12/21/192834)
  - [Anime-style aura tutorial (Blender Artists)](https://blenderartists.org/t/anime-style-aura-tutorial/1165451)
  - [How do the devs of Anime Vanguards get this effect in a GUI](https://devforum.roblox.com/t/how-do-the-devs-of-anime-vanguards-get-this-effect-in-a-gui/3178407)
- **TSB death effect:** a DevForum thread asks how to copy TSB's "died" effect. — [DevForum](https://devforum.roblox.com/t/how-to-make-the-died-effect-if-a-player-dies-like-the-strongest-battlegrounds/3273149) (cited in sibling note `signature_moments_teardown.md`)

### Inferences
- [I] **Impact frame recipe, safe version for kids.** The cited default of a 0.1 s hold is about 3 frames at 30 fps.
  - Use it only on finishers and ultimates, never on every M1, so the screen can't flash more than once per second (project rule).
  - Prefer the "Black" (dark) type or a strong desaturation over a full white flash.
  - Leave out the alternating black-white-black triple flash that some games use. A triple flash inside 0.3 s breaks the one-flash-per-second rule.
- [I] **Rock-burst pattern seen across TSB and GPO-likes (estimated numbers):**
  - 8–16 wedge parts in a ring of radius about 4–10 studs, tilted outward about 20–40°;
  - each copies the colour and material of the ground under it, found with a raycast;
  - they pop up over about 0.1 s, hold 2–4 s, then sink or shrink over 0.5–1 s;
  - add 3–6 small flying chunks with physics or a parabola tween, plus a dust ring;
  - recycle every part from a pool (PartCache or ObjectCache, as the cited modules do).
- [I] **Typical aura stack:**
  - 2–3 MeshParts (a flame shell, a tall "tongue" mesh and a ground ring) with a scrolling or flipbook texture and Neon or high LightEmission;
  - the meshes are swapped or re-rotated every 2–4 frames to flicker;
  - particle sparks rise on top, with a crackle Beam at high tiers;
  - a PointLight in the element colour;
  - the "three tones" rule from playbook 15: a white core, the element colour, and a dark edge.
- [I] **Other pieces of the visual language:**
  - Speed lines are a ScreenGui ring of thin rotating images, or a camera-attached cylinder mesh.
  - Shockwaves are a flat ring mesh (and a sphere for air bursts) that scale up quickly while fading.
  - Slashes are a crescent mesh with a texture swept in Blender and tweened along the swing.
  - Hit sparks are 2–4 star or flare billboards that last about 0.15 s.
- [I] **Blood-free hits:** use white or element-coloured sparks, a hit flash on the target (a Highlight fill for 1–2 frames), knockback, and a camera nudge. JJS and TSB already mostly use stylised, non-red hit effects. Check this before relying on it.
- [I] **Domain takeovers:** a large inverted sphere or dome mesh with a stylised texture, a Lighting or Atmosphere swap for the people inside, and often a ColorCorrection tint. Bodies inside are frozen, which matches the cited JJS behaviour.

### Gaps
- **Missing numbers:** particle rates, mesh counts and timing for any named game's aura or ultimate. The DevForum "how do y'all make auras" thread wasn't readable (budget).
- **Hitbox modules:** I couldn't read the MuchachoHitbox or ShapecastHitbox threads. The links exist:
  - [MuchachoHitbox, a SpatialQuery-based hitbox](https://devforum.roblox.com/t/muchachohitbox-an-easy-to-use-spatialquery-based-hitbox-system/3682320)
  - [ShapecastHitbox for melee](https://devforum.roblox.com/t/shapecasthitbox-for-all-your-melee-needs/3624241)
  - [Creating a battlegrounds-like hitbox](https://devforum.roblox.com/t/creating-a-battlegrounds-like-hitbox/3623640/2)
  - [What hitbox system is best for fast-paced combat](https://devforum.roblox.com/t/what-hitbox-system-is-best-for-a-fast-paced-combat-game/2688732)

  The titles only confirm that the spatial-query and shapecast approaches are the current choices.
- **Camera shake modules** were not researched this session. The vault's LihFolk "Hit-Stop and Screen Shake Tuning by Numbers" note holds the numbers.

## Who makes the VFX, prices, tools and open-source modules

### Takeaway
Anime VFX on Roblox is mostly done by freelancers who advertise through DevForum "for hire" posts, carrd.co portfolios and Fiverr. One freelancer I could read prices simple effects at about 500–1,000 Robux and advanced moves at 5,000–10,000 Robux (about $28–52). Moon Animator 2 is the common tool for staging moves.

### Cited Findings
- **A freelance UI and VFX artist (3 years in anime and cartoony styles) lists these base prices:**
  - Basic: 500–1,000 R$ (they quote $1.75–3.50);
  - Medium (slashes, hit effects, impacts): 2,000–4,000 R$ + tax ($12–20);
  - Advanced (moves, complicated effects): 5,000–10,000 R$ + tax ($28–52);
  - prices are "negotiable" and depend on complexity.

  The page doesn't list tools or past games. — [sst0rmy.carrd.co](https://sst0rmy.carrd.co)
- **Where to hire:**
  - Fiverr gigs sell "Roblox VFX, combat abilities, anime effects and animation" (titles only): [Fiverr emmyjovfx](https://fiverr.com/emmyjovfx/create-roblox-vfx-combat-abilities-anime-effects-and-animation), [Fiverr ethani_smith](https://fiverr.com/ethani_smith/make-vfx-animations-and-custom-skills-scripts-for-your-roblox-fighting-game)
  - DevForum hiring posts ask for "VFX / weapon mesher for an anime-based game" (title only). — [DevForum](https://devforum.roblox.com/t/open-seeking-a-vfx-weapon-mesher-for-anime-based-game-usd/617849)
- **Tools (from sibling notes this session):**
  - Moon Animator 2 export and cutscene playback, through Moon2Cutscene: [DevForum Moon2Cutscene](https://devforum.roblox.com/t/v2-moon2cutscene-play-moon-animator-2-files/3001411?page=3), [How to export using Moon Animator 2](https://devforum.roblox.com/t/how-to-export-using-moon-animator-2/2092413)
  - VFX Forge, a custom VFX system plugin: [DevForum](https://devforum.roblox.com/t/plugin-vfx-forge-an-advanced-custom-vfx-system/3867553)
  - Effect Designer Suite: [DevForum](https://devforum.roblox.com/t/effect-designer-suite-%E2%80%94-vfx-tooling-assets-and-more/4754553)
  - Blender-only slash workflow (title only): [DevForum](https://devforum.roblox.com/t/how-to-make-animated-slash-effects-with-only-blender/1794034)
- **Pooling used by rock modules:** PartCache. — [PartCache thread](https://devforum.roblox.com/t/partcache-for-all-your-quick-part-creation-needs/246641)

### Inferences
- [I] **Price range:** the cited prices are low-end freelancer rates. Studio-level artists who work for the top games likely charge far more per move, or are on retainer. That is not verified.
- [I] **For this project:** the owner has no budget line for this, and we build in-house. The useful lesson is the build method (mesh + texture + tween, staged in Moon Animator), not hiring.
- [I] **Usual toolchain (not verified per game):**
  - Blender for meshes (crescents, shells, spikes);
  - Photoshop, Krita or EmberGen for flipbook sheets;
  - Roblox ParticleEmitter flipbooks (2x2, 4x4 or 8x8 grids);
  - Moon Animator 2 to sync rig, camera and effect keyframes.

### Gaps
- **Not reachable this session:**
  - the artists who credit themselves on TSB, JJS, GPO or Blox Fruits;
  - Hidden Developers or Talent Hub rate cards;
  - EmberGen use in Roblox.
- **No developer post-mortems** from the top games were found.

## Summon/gacha banners in anime TD games: how the reveal escalates by rarity

### Takeaway
I confirmed the odds and pity structure (Anime Vanguards). I couldn't confirm how the summon animation escalates by rarity: no reachable source described the colours, beams or timing.

### Cited Findings
- **Anime Vanguards banner:**
  - shows 3 Mythic units, with the middle one most likely;
  - "resets every hour";
  - odds: Rare 75.496%, Epic 20%, Legendary 4%, Mythic 0.5%, Secret 0.04%; Shiny 1.5% (a rarer version of an existing unit, not its own tier);
  - Secret and Shiny need level 10 or higher;
  - two pity bars in the Summon box: **Legendary guaranteed at 50, Mythic at 400** summons;
  - odds can be checked in the Index;
  - the article doesn't describe the animation.

  — [DroidGamers Anime Vanguards banner](https://www.droidgamers.com/guides/anime-vanguards-banner/)
- Anime Defenders has Banner and Exclusive Wish wiki pages (titles only; I couldn't read them). — [Banner](https://animedefenders.fandom.com/wiki/Banner); [Exclusive Wish](https://animedefenders.fandom.com/wiki/Exclusive_Wish)
- The sibling note confirms this gap: "No source I could reach gave seconds per beat for … Anime Vanguards / Anime Defenders summons." — `rare_reveals_and_cutscenes.md` (this folder)

### Inferences
- [I] **Common pattern (needs a 30 fps check):** a capsule, orb or portal, a beam or light that changes colour by rarity, more shake and particles at higher rarity, and a "fake-out" upgrade where the colour steps up mid-reveal. Then the unit appears in a pose with a name card and a rarity banner. Multi-summons (10x) let you skip low rarities quickly and pause on high ones.
- [I] **Kid-safe version (project rules):**
  - show the odds and the pity counter on the banner (Anime Vanguards does, with two pity bars);
  - no "resets in" countdown that pushes buying (an hourly rotation is fine; a fake timer is not);
  - no fake-out escalation on paid pulls that teases a rarity the player then doesn't get;
  - flashing stays under 1 per second.

### Gaps
- **No data on the reveal itself:** rarity colours, beam counts and seconds per beat for Anime Vanguards, Anime Defenders, Anime Last Stand, Anime Adventures, AFS Endless or Anime Champions Simulator. Next step: frame-step "all summon animations" videos.

## Sound design in anime games

### Takeaway
I found no reliable source. Searches for Roblox anime sound design only returned spam pages from auto-generated "sound script" sites.

### Cited Findings
- None reliable. Searches like "roblox anime game sound design impact whoosh layering devforum" returned only generated `*.pages.dev` SEO pages (e.g. "roblox anime punch sound script"). I did not use them as sources.

### Inferences
- [I] **Usual layering (general game-audio practice, not verified on these games):**
  - each heavy hit = a sharp transient (crack or snap) + a low body thump + a short tail (debris or air);
  - whooshes start 2–4 frames before contact;
  - ultimates add a riser during the charge, a short silence (about 0.1–0.2 s) at the impact frame, then a bass drop or boom;
  - Awakening adds an aura loop.
- [I] Make our own sounds with `<game>/tools/sfx/make_sfx.py`. Never rip voice lines or shouts from anime or other games.

### Gaps
- Real sound breakdowns for TSB, JJS or Blox Fruits, and developer audio posts. Not found.

## Anything kid-unsafe to avoid

### Takeaway
The real risks:
- strobing impact frames, which can flash several times a second in combos;
- gacha pressure (hourly banner rotations, very low Secret odds such as 0.04%);
- violent themes in some games' source anime.

The project's rules cover all three.

### Cited Findings
- Secret units at **0.04%** and Mythic at **0.5%**, with pity at 400 summons, so the top rarity is very rare. — [DroidGamers](https://www.droidgamers.com/guides/anime-vanguards-banner/)
- Banners that "reset every hour". — [DroidGamers](https://www.droidgamers.com/guides/anime-vanguards-banner/)
- The default impact frame is a full-screen black/white switch with Contrast ±25000 for 0.1 s, which is a high-contrast flash. — [DevForum Impactframe Module](https://devforum.roblox.com/t/open-source-impactframe-module/2963136)
- A Roblox game was reportedly linked to an epilepsy death, and its developers were criticised over flashing. — [GosuGamers](https://www.gosugamers.net/entertainment/news/78238-roblox-game-allegedly-linked-to-player-s-epilepsy-death-developers-criticised-for-negligence) (cited in sibling notes; the claim is "alleged")
- DevForum: "Extremely dangerous flashing UI issues". — [DevForum](https://devforum.roblox.com/t/extremely-dangerous-flashing-ui-issues/1645143)
- Roblox paid random item rules. — [Creator Docs](https://create.roblox.com/docs/en-us/production/monetization/paid-random-items.md)

### Inferences
- [I] **Cap impact frames:**
  - at most one per second for the whole screen, enforced in code by a global cooldown, not per move;
  - use dark-tint or desaturate, not full-white;
  - offer a "reduce flashing" setting.
- [I] **No gore:** no blood, dismemberment or bodies that stay down. Replace with sparks, stars, knockback and a cartoony poof (see the vault `Gore Policy and Kid-Friendly Hit Feedback.md`).
- [I] **Gacha:**
  - show the odds and pity;
  - no countdowns or fake-outs on paid pulls;
  - no FOMO "limited" units for Robux;
  - an hourly rotation of free banners is fine.
- [I] **No IP:** domain expansion, named techniques, Stands and breathing styles are anime IP. Rename them and redesign them. The LihFolk TSB case study notes the takedown risk.

### Gaps
- Exact flash frequencies in TSB or JJS combos (needs video frame-stepping), and the current Roblox maturity labels for each game. Not verified.
