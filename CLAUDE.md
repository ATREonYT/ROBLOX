# +1 Hood Evolution: project memory

A kids' Roblox simulator in Luau, modelled on "+1 Soldier Evolution" with a hood theme. The game is in `hood/`. Work on the branch the session names; the current line of work is `claude/elegant-cannon-i9r37o`. The owner is on a Mac and uses Studio, GitHub Desktop and Claude Design.

## The owner's standing rules (short version; full list in `hood/docs/RULES.md`)
- **Match the soldier game in style, not one to one.** Vibrant, clean, chunky, readable; calm space, loud interactables; smooth eased motion; nothing "AI slop".
- **Objects are the owner's blocky designs** (LEGO-like blocks, studs on tops are fine), placed through `Shared/ItemMeshes` with a Part build as the fallback. They live in `hood/art/models/items/`, as 4 GLBs plus a manifest. New objects come from the owner via Claude Design (`hood/art/CLAUDE_DESIGN_PROMPT.md`), not from us.
- **The lobby is a warehouse around the open plaza layout** (commit 4a04b59).
  - Keep this layout.
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
- **Place file:** `LUNE=<lune> sh hood/tools/place/build_place.sh` writes `hood/places/HoodEvolution.rbxl`. Rebuild it when committing map changes.

## Checks (must all pass before every commit)
`LUNE=<path to lune> sh hood/tools/checks/run_checks.sh`. The expected result:
- check_locals: 0 failing;
- unit: all pass (394 at 4a04b59+);
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
- **Renderer version caveat:** the renderer that draws the owner's GLB designs (r14) lived only in a past session. If it's needed, extend `hood/tools/preview/render` with three.js GLTFLoader for ids in `hood/art/models/items/manifest.json`.

## Release
`hood/RELEASE.md` is the owner's step-by-step checklist: import, icons, Robux items, tests, publish.

## Open items (at the time of writing)
- Box opening: hide the HUD during the cinematic; rarity text under the shoe.
- Product labels too big when passing on the walk to the gate.
- Stale "Buy a gun" goal after buying.
- Phone HUD right column overlap.
- The 5 Robux exclusive guns (NeonViper, GalaxyRay, InfernoCannon, Frostbite, RoyalCrown) are imported but not for sale; waiting on the owner's prices.
- Stage props: waiting on a Claude Design batch from the owner.
