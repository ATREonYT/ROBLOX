# +1 Hood Evolution: project memory

A kids' Roblox simulator in Luau, modelled on "+1 Soldier Evolution" with a hood theme. The game is in `hood/`. Work on the branch the session names; the current line of work is `claude/elegant-cannon-i9r37o`. The owner is on a Mac and uses Studio, GitHub Desktop and Claude Design.

## The owner's standing rules (short version; full list in `hood/docs/RULES.md`)
- **Match the soldier game in style, not one to one.** Vibrant, clean, chunky, readable; calm space, loud interactables; smooth eased motion; nothing "AI slop".
- **Objects are the owner's blocky designs** (LEGO-like blocks, studs on tops are fine), placed through `Shared/ItemMeshes` with a Part build as the fallback. They live in `hood/art/models/items/`, as 4 GLBs plus a manifest. New objects come from the owner via Claude Design (`hood/art/CLAUDE_DESIGN_PROMPT.md`), not from us.
- **The lobby is a compact warehouse** (Oct 26 relayout, the plan the owner picked):
  - the Stage 1 gate straight ahead of spawn, as the one focal point; ranges west, gun shop east, shoe boxes south behind you;
  - 2 Robux pads by spawn, the other products beside the station they belong to;
  - calm open floor; props only along the walls.
  - Keep our themed shooting-range bays, without side walls.
  - No grass inside; clay cliffs and hood buildings outside.
  - No spawn symbol.
- **Text:** Montserrat Black (GothamBlack) with a thick dark outline and gradient fills (`Shared/TextStyle`). Robux prices show the Robux sign (`Shared/RobuxText.fmt`).
- **Kid-safe and honest:**
  - no fake timers, scarcity or stock;
  - at most 1 flash per second;
  - paid random items show their odds and a pity counter.
- **Don't edit:** SimulatorLobby, BlockBuilder, BlockPolish, HoodProps. No asset ids in comments.
- **Token budget matters to the owner:**
  - grep, don't read big files whole;
  - few agents, and reuse them;
  - at most 2 render rounds;
  - one picture or video per change, only when there's something to judge.

## How the code is built
- **Map:** `hood/src/ServerStorage/TheBlockV2.lua` is GENERATED. Edit `hood/tools/map/pieces/*.lua`, then run `sh hood/tools/map/assemble.sh`. The order is in `pieces/ASSEMBLE.txt`.
- **Lighting preset:** `HoodToy` in `ServerStorage/HoodLighting.lua`.
- **Shared code:** `ReplicatedStorage/Shared` (rules modules are unit-tested); client code in `StarterPlayer/StarterPlayerScripts/HoodClient`; server in `ServerScriptService/HoodServer`.
- **Robux items:** `Shared/Config/Products.lua`; the list to create on the website is `hood/MONETIZATION.md`.
- **Pacing:** the owner wants World 1 to take 25-30 minutes and later worlds longer (Oct 27). `hood/tools/pacing/pacing.luau` simulates players on the real numbers (`Config/Balance`, `Guns`, `Skins`, `Shoes`); run it after any change to rebirth needs, stage Power, pad Cash, gun prices, lanes or walk speed, and try new numbers with `tune.luau` (both headers say how). World 1 now: 9 rebirths (the boss at about 30 min); the ladder goes on to 50 rebirths (about 4 h), lanes open at 2, 4, 7, 15, 30 and the Champ Ring at 50 (the owner: "more rebirths, up to like 50").
- **Place file:** `LUNE=<lune> sh hood/tools/place/build_place.sh` writes `hood/places/HoodEvolution.rbxl`. Rebuild it when committing map changes.

## Checks (must all pass before every commit)
`LUNE=<path to lune> sh hood/tools/checks/run_checks.sh`. The expected result:
- check_locals: 0 failing;
- unit: all pass (399 since the Oct 26 lessons pass);
- integ_waves: no issues;
- integ_lobby: walk cleared;
- play_run: 82 checks / 0 failed;
- live_shoes and live_reveal: exit 0;
- first30: 8 ok with 0 purchase prompts;
- finale_play: 18/0;
- wb_play: 10/0. It's timing-sensitive under heavy CPU load; re-run alone before calling it a failure.

Lune: <https://lune-org.github.io>. The harness runs the game offline (no Studio needed).

## Previews
- **3D:** `hood/tools/preview` (harness + three.js renderer; draws Montserrat and the Robux sign).
- **Reference frames for comparing:** `hood/docs/refs/`.
- **Look rules with numbers:** `hood/docs/LOOK_RECIPE.md`. The critic's checklist is `hood/docs/CRITIC_POINTS.md`.
- **Renderer that draws the owner's designs:** `hood/tools/preview/render14` (r14: the GLBs in `hood/art/models/items`, faked into the build by `tools/fake_items.luau`; export, render, side-by-side, walk video and lobby metrics; see its README, `npm install` there first).

## Lessons learned building this with the owner (read these; they cost a lot to learn)
1. **The owner judges by eye, against the reference.**
   - Every visual change gets ONE side-by-side, ours next to the reference, from the same camera angle.
   - Never say "matches the reference" without that picture.
   - Motion (animations, effects) is judged on a 30 fps MP4, not on stills.
2. **Prove it small before scaling.** Build a "golden slice" (spawn + 2 lanes + one pad) first, get a yes, then roll it out. Full rebuilds that miss waste days.
3. **What made it look "dead" or "AI slop":**
   - Studs everywhere in harsh contrast. **Oct 26 the owner chose classic studs everywhere** (Plastic, all six faces `SurfaceType.Studs`, like their Alien inspiration map; see `hood/docs/INSPIRATION.md`). Keep the colours mid-tone and warm, so the studs don't read as black and white noise. Text boards, Neon, glass and the owner's meshes stay smooth.
   - A grey or cold palette ("calm" was misread as grey). Big warm, saturated fields with loud items work; neon doesn't.
   - Flat light with no shadows. Use the `HoodToy` sun.
   - Too many labels, tiny items, and stray props.
4. **Objects: the owner's own designs beat anything we model.** If an object looks weak, ask the owner for a design batch rather than iterating our Part builds. Claude Design must be told "BLOCKY: built only from bevelled cuboids", not "low poly", which gives faceted or rounded blobs.
5. **Agents grade themselves too kindly.** Before showing the owner, have a fresh critic (one that didn't build it) compare against the reference and list the worst gaps first.
6. **Check the data before "fixing" a scare.** "Fallen" objects were a steep camera angle, and a "?" price was the owner's own earlier request. Read the history and measure first.
7. **The preview renderer can lie** (fonts, the Robux sign drawn as a box, shadows, particles). Fix the renderer, not the game, and say what only Studio can show.
8. **Merging agents' work:**
   - Agents work in their own copies.
   - Only copy the files each agent changed, onto the current HEAD.
   - Never copy an agent's older version of a file that changed on HEAD since. That once almost reverted the tutorial.
   - When gameplay rules change, the play-test tools change with them; stale tools give false failures.
9. **Kid-safe is non-negotiable.**
   - The owner once asked for hidden better odds for new players. That was refused (not allowed for paid random items) and replaced by a visible pity counter.
   - No fake timers or scarcity.
10. **The owner is very token-conscious.**
    - Few agents, reused for follow-ups; no render loops.
    - Short status lines; one deliverable per change.
    - Anything worth keeping goes in the repo, not the session's temp folder (it vanishes).
11. **Talking with the owner.**
    - Use plain words and no code jargon. The owner writes short messages and changes direction (warehouse → plaza → warehouse around the plaza layout → compact warehouse).
    - For a direction change, ask ONE quick multiple-choice question, with the recommended option first. Otherwise act and report.
    - Always state honestly what is still worse than the reference.
12. **The place file:** `build_place.sh` makes a fresh `.rbxl`, so anything the owner imported in Studio (the design meshes) is lost unless it's saved to the repo as an `.rbxm` and included in the build. If the owner sends `hood/art/models/items/HoodItemMeshes.rbxm`, make `build_place` include it.

## Inspiration from the owner's other games
`hood/docs/INSPIRATION.md`: lessons from the owner's own Huss game (branch `HUZZ-VALLEY`, built with this same way of working; take lessons, don't copy it) and an Alien map they liked (one 8-stud grid, terraces, grass drips, classic studs). The lighting preset `HoodToy` follows Huss's even, cartoony light (strong sky fill, soft sun).

## Lessons from the owner's other games (read before building)
`hood/docs/LESSONS_FROM_OTHER_GAMES.md`: the scripting, feel and working mistakes from Huzz Valley and the early games, and where Hood stands on each. The scripting rules in short:
- per-instance memory uses `Shared/InstanceMap`, never a weak table (`{ __mode = 'k' }`) keyed by instances;
- a model the client reads streams in whole (`ModelStreamingMode.Atomic`), or the client looks again until its parts are there;
- every forever loop and every queue pcalls each tick or job, and reports an error once;
- Studio Play's top-right tag shows the scripts' build stamp: check it on any recording that shows old behaviour.

## Release
`hood/RELEASE.md` is the owner's step-by-step checklist: import, icons, Robux items, tests, publish.

## Open items (at the time of writing)
- Box opening: hide the HUD during the cinematic; rarity text under the shoe.
- Product labels too big when passing on the walk to the gate.
- Stale "Buy a gun" goal after buying.
- Phone HUD right column overlap.
- The 5 Robux exclusive guns (NeonViper, GalaxyRay, InfernoCannon, Frostbite, RoyalCrown) are imported but not for sale; waiting on the owner's prices.
- Stage props: waiting on a Claude Design batch from the owner.
