# Release checklist: +1 Hood Evolution, World 1

Do these in order. Each step says where the details are. Tick them off as you go.

## A. Get the latest game into Studio
1. In GitHub Desktop: **Fetch origin → Pull** on branch `claude/elegant-cannon-i9r37o`.
2. Open `hood/places/HoodEvolution.rbxl` in Studio, or sync the scripts with Rojo (`ROJO-SETUP.md`).

## B. One-time Studio steps
3. **Your designs:** follow `hood/art/MESH_IMPORT.md`.
   - **File → Import 3D**, then pick the 4 files in `hood/art/models/items/`.
   - Paste `hood/tools/blender/studio_item_meshes.lua` into the **Command Bar**.
   - Check: `ReplicatedStorage → HoodItemMeshes` has 57 models. Press Play and the plaza shows your designs.
4. **Icons:** upload the UI pictures with `python3 hood/tools/upload_assets.py`, using your Open Cloud API key (`hood/art/README_upload.md`). Without this, menus show stand-ins.
5. **Saving:** Game Settings → Security → turn on **Enable Studio Access to API Services**, so DataStores save in Studio tests.

## C. Robux items (this is the money)
6. **Passes and products:** create every game pass and developer product listed in `hood/MONETIZATION.md`, at the prices given. Paste each id into `hood/src/ReplicatedStorage/Shared/Config/Products.lua`.
   - Until an id is pasted, that button says "Coming soon!" and nothing breaks.
7. **Group:** put your group id in `hood/src/ServerScriptService/HoodServer/ServerConfig.lua` (`GroupId`). This turns on the group reward chest.
8. **Optional:** the 5 Robux exclusive guns (Neon Viper, Galaxy Ray, Inferno Cannon, Frostbite, Royal Crown) are imported but not for sale yet. Tell Claude if you want them sold, and at what prices.

## D. Test before anyone else plays (Studio → Play)
9. **First 5 minutes, as a new player:**
   - the tutorial hint and arrows lead you to the range, the gun shop, Stage 1 and a box;
   - nothing is stuck, no error in Output.
10. **Purchases:** Studio test purchases are free. Buy one pass, one box and one Cash pack; check each gives what it says.
11. **Save:** play, earn Cash, stop, play again; the Cash must still be there.
12. **Phone:** Test → Device → an iPhone. Every button must be reachable, and no text cut off.
13. **Two players:** Test → Clients and Servers → 2 players. Check the World Boss, the leaderboards and gifting.

## E. Publish
14. **Experience page.** These are worth designing in Claude Design, with the same blocky prompt (`hood/art/CLAUDE_DESIGN_PROMPT.md`):
    - an icon, 512×512;
    - 3+ thumbnails, 1920×1080, showing the plaza, a fight and a box opening;
    - a short description.
15. **Content questionnaire:** Creator Dashboard → your experience → **Questionnaire**. Answer honestly. The game has toy-style blocky guns and knock-outs with no blood, and paid random items (the shoe boxes show their odds and a pity counter).
16. **Private first:**
    - Publish, keep it **Private** or friends-only;
    - play it on a real phone and a computer with 2-3 friends;
    - fix what they find.
17. **Public:** make it Public. Watch the first day's **Analytics** (Retention, Monetization) and send Claude what you see.

## Known open items
- Stage props: a batch from Claude Design is still to come. The stages keep their current props until then.
- The FEEL pass (tutorial, animations and on-screen effects judged against the soldier game) is in progress.
