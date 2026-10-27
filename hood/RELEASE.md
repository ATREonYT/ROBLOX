# Release checklist: +1 Hood Evolution, World 1

Do these in order. Each step says where the details are. Tick them off as you go.

## A. Get the latest game into Studio
1. In GitHub Desktop: **Fetch origin → Pull** on branch `claude/project-thread-u3g0qe`.
2. Open your game in Studio with Rojo connected (`rojo serve` in the `hood` folder, then Rojo → Connect), or open `hood/places/HoodEvolution.rbxl`.
   - After a map change, rebuild the map once: paste `require(game.ServerStorage.TheBlockV2).Build()` into the **Command Bar** (the old map is kept in ServerStorage as a backup).

## B. One-time Studio steps
3. **Your designs:** follow `hood/art/MESH_IMPORT.md`.
   - **File → Import 3D**, then pick the 4 files in `hood/art/models/items/`.
   - Paste `hood/tools/blender/studio_item_meshes.lua` into the **Command Bar**.
   - Check: `ReplicatedStorage → HoodItemMeshes` has 57 models. Press Play and the plaza shows your designs.
4. **Icons and footsteps:** upload the UI pictures and the footstep sounds with `python3 hood/tools/upload_assets.py`, using your Open Cloud API key (`hood/art/README_upload.md`). Without this, menus show stand-ins.
5. **Lighting:** select **Lighting** in the Explorer and set **Technology** to **ShadowMap** in Properties (a script can't set it; the rest of the Huzz Valley look is applied when the game starts).
6. **Animations:** upload the 7 moves from your R15 pack (Idle, Walk, Run, Jump, Fall, Climb, Swimming: right-click each in the pack's AnimSaves → Save to Roblox) and paste the numbers into `hood/src/ReplicatedStorage/Shared/Config/Animations.lua` (or send them to Claude). The pack itself stays out of GitHub: its licence forbids sharing it.
7. **Saving:** Game Settings → Security → turn on **Enable Studio Access to API Services**. In Studio, progress is on purpose a throwaway copy that resets when you press Stop, so your real saves are never touched by tests (Output says "MOCK DATA").

## C. Robux items (this is the money)
8. **Passes and products:** create every game pass and developer product listed in `hood/MONETIZATION.md`, at the prices given. Paste each id into `hood/src/ReplicatedStorage/Shared/Config/Products.lua`.
   - Until an id is pasted, that button says "Coming soon!" and nothing breaks.
9. **Group:** put your group id in `hood/src/ServerScriptService/HoodServer/ServerConfig.lua` (`GroupId`). This turns on the group reward chest.
10. **Exclusive guns:** the 5 Robux exclusive guns (Neon Viper, Frostbite, Galaxy Ray, Inferno Cannon, Royal Crown) are sold as game passes in the Shop. They're in the pass list in step 8, so create them with the rest.

## D. Test before anyone else plays (Studio → Play)
11. **First 5 minutes, as a new player:**
   - the tutorial hint and arrows lead you to the range, the gun shop, Stage 1 and a box;
   - nothing is stuck, no error in Output.
12. **Purchases:** Studio test purchases are free. Buy one pass, one box and one Cash pack; check each gives what it says.
13. **Save:** this one is tested in the published game (step 18), not in Studio, because Studio progress resets on Stop. There: play, earn Cash, leave, join again; the Cash must still be there.
14. **Phone:** Test → Device → an iPhone. Every button must be reachable, and no text cut off.
15. **Two players:** Test → Clients and Servers → 2 players. Check the leaderboards and gifting. (The World Boss and the free gift are switched off for now: `Config/Features`.)

## D2. World 2 (Downtown), a second place in the same game
- **Add the place:** in Studio, open your game, then View → **Asset Manager** → **Places** → right-click → **Add New Place**. Open the new place and publish `hood/places/HoodEvolution_World2.rbxl` into it (File → Open the .rbxl, then File → **Publish to Roblox As…** → your game → the new place).
- **The two place ids:** in Asset Manager → Places, right-click each place → **Copy ID**. Put them in `hood/src/ReplicatedStorage/Shared/Config/Worlds.lua`: World 1's id on the `The Hood` line, World 2's on the `Downtown` line (or send both numbers to Claude). Until World 2's id is in, its door says "coming soon".
- **Both places get the same settings:** Game Settings → Security → turn on **Allow Mesh / Image APIs** (the menus' pictures) and **Enable Studio Access to API Services** (saving). Lighting → Technology → **ShadowMap** in each place.
- **Test the trip:** in the published game (Studio can't teleport), beat World 1's Stage 16, walk through the World 2 door, then use the World window to go back.

## E. Publish
16. **Experience page.** These are worth designing in Claude Design, with the same blocky prompt (`hood/art/CLAUDE_DESIGN_PROMPT.md`):
    - an icon, 512×512;
    - 3+ thumbnails, 1920×1080, showing the plaza, a fight and a box opening;
    - a short description.
17. **Content questionnaire:** Creator Dashboard → your experience → **Questionnaire**. Answer honestly. The game has toy-style blocky guns and knock-outs with no blood, and paid random items (the shoe boxes show their odds and a pity counter).
18. **Private first:**
    - Publish, keep it **Private** or friends-only;
    - play it on a real phone and a computer with 2-3 friends;
    - do the save test from step 13 (earn Cash, leave, join again);
    - fix what they find.
19. **Public:** make it Public. Watch the first day's **Analytics** (Retention, Monetization) and send Claude what you see.

## Known open items
- Stage props: a batch from Claude Design is still to come. The stages keep their current props until then.
- The FEEL pass (tutorial, animations and on-screen effects judged against the soldier game) is in progress.
