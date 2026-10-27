# Standing rules (from briefs 30-33)

> Paths starting with `$S/` pointed into a past session's temporary folder and no longer exist. The key reference frames are now in `hood/docs/refs/`, the look recipe in `hood/docs/LOOK_RECIPE.md`, the map pieces in `hood/tools/map/pieces/`.

# Brief 30 standing rules (every agent reads these; the user's words, verbatim, where quoted)

1. **The references are the source of truth.** "use the references, they are just so important, i cant stress it enough, because that is what we are building off."
   - Copy the soldier game's layout, mechanics, animations and UI one to one, with our hood twist on the THEME only.
   - "i dont want you to start creating new layouts or anything, that layout worked for the other game".
   - The bible: $S/brief/B30/REFERENCE_BIBLE.md plus frames/. Older analyses: $S/brief/out29/REF/refs29.md and $S/brief/out28/REF/copy_spec.md.
2. **The build style for anything new.** "for the new things, keep that low poly blocky build like the map is made, it looks good, and also use it for the boss fight, check the references, how it looks, its just so detailed, i want it to look like that."
   - New props, arenas, boss stages and effects use the same chunky low-poly, studded, blocky kit as the map: the code5 kit helpers, plus BoxKit props from Blender exported as Parts.
   - Match the reference's level of DETAIL: dense, deliberate, layered props; no bare slabs, no random objects mixed together.
3. **UI.** Copied 1:1 from the user's UI references as flat 2D, with motion like the references: pops, bounces, shine sweeps, stagger-ins and number count-ups.
   - The icon art must be glossy, chunky and cartoon, like the references.
   - The user: "our drawings for ui is really bad … use anything that helps you to create the best looking ui possible, right now it looks like ai slop".
4. **Lobby.** Version C (Oct 9, commit b1ce567) is the base, with today's armory.
   - The ranges sit exactly where the soldier game puts its training.
   - Everything added later stays, but is spread along the walks, and the boards must look attractive enough to buy from.
5. **Stages.**
   - Keep the step-in basketball courts on stages 10–12.
   - Remove the BOSS pads and boss labels everywhere.
   - The last stage keeps its warehouse look with no boss extras: no BOSS pad, name card, phase bar or "WORLD 1 COMPLETE" show. It's "just a strong last enemy before the second world".
   - Keep the world boss, and make it better.
6. **Fights.** "i also want more animations, more fighting animations just like in the references, we still dont have that, it makes the fighting in general feel plain and weak".
7. **Tutorial.** "box is misplaced everywhere, it doesnt look tidy, it just jumps around, make the box for example show well for the ui, where to go, you can also adjust the size of the box … and make the arrows points more presicely".
8. **Effort.** "dont cap the agents … take your time … use your abilities to perform and make it the best you can".
   - Work in rounds: render, put it side by side with the reference, fix, repeat.
   - Play-test by filming harness play-throughs.
9. **Unchanged rules.**
   - Kid-safe and honest: no fake timers or scarcity; at most 1 flash a second, each 0.25 s or less.
   - Never edit SimulatorLobby, BlockBuilder, BlockPolish or HoodProps.
   - No asset ids in comments.
   - Nobody commits but the lead.
10. **Every point, however small** (the user): "spend time on every point, no matter if it is small, make it be done well, every single point matters, if it is small, check the references, see how its done there, and replicate".
    - For EACH item you touch, find how the reference does it and cite the frame.
    - Replicate it, then show your result next to the reference.
    - No item is "minor": labels, spacing, button states, timings, sounds-off states and hover effects all count.
11. **The user's decisions after the bible (binding):**
    - Add the third paid lane: the gold 250x head lane at the aisle's end, R$699.
    - Locked FREE lanes are black; locked PAID lanes are a full-colour teaser, like the reference.
    - Gates show "Recommended Power: X", like the reference; Level stays on the HUD bar.
    - Tone C's neon glow down like the reference: strong colour only on pads, lanes, prices, products and UI.
    - The bible ($S/brief/B30/REFERENCE_BIBLE.md, frames in $S/brief/B30/frames/) is the spec. Read §0 first.
12. **The user's own UI mockups** (7 artboards plus the handoff at /root/.claude/uploads/b317c1b8-7ed1-5c10-bdc6-d007f130e4dc/b6230714-World1-Shoe-UI-Handoff.md) are the authority for the Shop bundle, the box browser and drops, the reveal, the Inventory and equipped detail, the collection and Daily Rewards, the gift flow and the purchase states.
    - The Robux boxes are RENAMED: Exclusive becomes **Chrome**, Grail becomes **Crown** (the user agreed).
    - "The Grail Bundle" (The Grail, Astro Crown, Platinum Wings) is sold as a Robux bundle. The lead proposes a price for the user to confirm.
13. **The user's 3D render sheets** ($S/brief/ref30/user_models/01-Street-Box.png … 05-The-Grail-Bundle.png) are the design for ALL World 1 boxes and shoes.
    - The boxes are chests with a handle and a hinged lid (closed and open views).
    - The 22 shoes are in a clean blocky style.
    - The in-game models and the UI pictures must match these sheets (the user chose "Boxes and shoes").
14. **The Grail Bundle price is R$1,499** (the user: "make it cheaper to buy more … so people see it and buy it more").
15. **Animations must be SMOOTH like the references** (the user): eased, cross-faded (0.1–0.2 s), with follow-through and secondary motion, frame-rate independent. Judge them in motion (an MP4 at 30 fps), not from stills.
16. **The lobby stays a WAREHOUSE (the user's choice), but must FEEL like the reference's plaza:**
    - a calm palette with no neon, daylight through skylights or windows;
    - loud colour only on interactables;
    - the reference layout and proportions, floating text with a size hierarchy.
    - Outside the hall: a mix of orange-brown studded cliffs with grass tops and low hood brick blocks.
    - The user: "recreate it with the same feel of the other game, all of the visual effects, the animations, the core loop".
17. **No spawn symbol** (the user, twice): the spawn square is plain, with no splat or spiky decal, even though the reference has one.
18. **Lobby floor = a logical path network** (the user): straight walkways from the spawn to each destination, with branches only where needed, each ending at its thing; no random panels or stubs; turf fill everywhere else.
19. **No grass inside the warehouse** (the user): "its a warehouse". The inside floor is concrete or grey studded slabs with warehouse details; the paths stay. Grass and cliffs belong only outside.
20. **Fonts (checked against the references):** in-world text (lanes, products, boxes, gate signs, +N popups, names) uses **Montserrat Black** (= Roblox GothamBlack; Shared/Fonts Title / the map's FONT.title) with a thick near-black outline, like the reference. The gate's "Recommended" and "Power: X" are both cyan Montserrat Black; no pixel/Arcade font. HUD and screens are Montserrat too.
21. **Product pads like the reference** ($S/brief/ref30/ref_product_pads.webp): the real 3D item floating over a glowing coloured pad with a rising haze; floating price / name / benefit text. Robux boxes go out on pads too. No fake stock counters.
22. **In-world text styling like the reference:** Montserrat Black, a thick dark outline, and vertical UIGradient fills on key words (gold to orange multipliers, lime prices with the Robux hex, salmon Locked, green Unlocked, a rainbow benefit line). Size hierarchy: the multiplier biggest, the state word smallest.
23. **Boxes are presented like the reference's eggs:** round studded pedestals on a stepped dais, an oval tag in front, a floating name and price, and a hanging "BOXES" area-title panel high above (not a stand behind).
24. **The user's final push (binding, about 3 hours, credits are tight):** "make sure … the work is done perfectly done like in the other game … animations on point, lobby on point, ui, and all the core loops … use the references like crazy, i want the look of the game, all effects, to look the same, all the effects on the screen … use blender … use your vfx skills, use the animations skills … dont lose the quality".
    - Before finishing, every agent puts its result next to the matching reference frame or clip and fixes visible differences.
    - On-screen effects must match the reference: popups, bursts, flashes, hazes, glows, sizes and timings.
    - Use the `roblox-vfx` skill for effects and `blender-roblox-models` for any model.
    - No exploratory rounds: build toward the reference, check once or twice, finish.
25. **UI never just pops** (the user): every text and panel eases in and out smoothly (0.25–0.4 s, staggered).
    - After a box opening: no reveal card. Show the shoe, its name and rarity easing in, and "Click anywhere to continue" at the bottom. The pair goes straight into the inventory. Auto Open keeps only a small Stop pill.

## Brief 31 (the user's decisions after the LOOK test area; these SUPERSEDE rules 16 and 19)
22. **The lobby is an OPEN HOOD PLAZA with a warehouse in it.** The user picked "Mix: plaza with a warehouse".
    - Outdoors like the reference: grass fields outside the paths, clay cliffs and hood brick buildings framing it, sky and sun.
    - The warehouse is ONE building in the plaza, the armory (gun shop). It has a wide open front so the guns read from the plaza, and inside it's concrete with no grass.
    - Boxes, ranges, pads and the gate stay outdoors, as in the reference.
23. **The look recipe is binding:** $S/brief/B31/LOOK_RECIPE.md.
    - Classic studs everywhere (owner, Oct 26; this replaces "never SurfaceType.Studs"): Plastic, all six faces Studs, on floors, walls, plinths and cliffs. Boards, Neon, glass and designed meshes stay smooth.
    - Faint top-face studs on walkable ground only.
    - Flat SmoothPlastic everywhere else.
    - Saturated warm fields, the HoodToy sun, and at most 3 label lines per thing.
24. **Showcase items become real 3D meshes** (the user said yes): Blender → FBX → one Studio import into ServerStorage.HoodItemMeshes → the code clones them by name, with the Part build as the fallback.
25. **The old themed range bays stay, without side walls** (LOOK's d2_stations).
26. **NO warehouse in the lobby (the user: "the inside building looks bad", "It doesn't look well made"; they picked "Drop it, all outdoors").**
    - This supersedes rule 22's warehouse.
    - The whole lobby is the open plaza. The armory/gun shop stands outdoors on a raised grey plinth with a curb, like the reference's gun stands (ref_V2-02.0_gun_stand_labels.jpg).
    - "Well made" means clean craft: aligned edges, consistent trims and curbs, no z-fighting, no floating or intersecting pieces, no half-hidden junk, symmetric where the reference is.
27. **Text "way better" (the user).** Every world and UI headline uses the reference's chunky cartoon text:
    - Montserrat Black/GothamBlack, big;
    - a THICK dark outline (UIStroke ~3-4 px at 1080p, or a near-black TextStroke in-world plus a 1-2 px offset drop shadow);
    - a vertical UIGradient fill (e.g. yellow→orange, cyan→blue, white→light grey);
    - a slight tilt only where the reference has one.

    Prices are green or yellow with the Robux icon (rule 28). No thin text, no plain flat white labels without an outline.
28. **Robux products are the money and must be the most attractive things on screen (the user).** In the world and in the UI, copy the reference's selling craft:
    - glossy chunky cards and buttons;
    - a 3D item breaking out of the card frame;
    - "ONLY ⬡79" price lines;
    - a shine sweep every few seconds;
    - a gentle idle bounce or pulse;
    - sparkles;
    - value badges ("x2", "BEST VALUE", "MOST POPULAR", "+45%") where they are TRUE;
    - placement on the main walking paths and the right HUD column.

    Kid-safe and honest: no fake timers, no fake scarcity, no fake stock; at most 1 flash a second.

## Brief 32 (the user's blocky designs arrived; aim: close to release)
29. **The user's blocky designs** ($S/bz/{a,r,s}, 66 .glb + PNG sheets; LEGO-like blocks WITH studs on tops) are THE look for objects. Use them for:
    - the Robux pad prizes + Pad_Base;
    - the lobby hero objects: Gate_Stage1, Board_Boxes, Pedestal_Box, Stand_Guns, Board_Leaderboard, Chest_Codes, Chest_GroupReward, Stand_SpinWheel, Portal_World2, Spawn_Pad;
    - the plaza scenery: trees, bush, cliff, 4 buildings, street props;
    - the 10 shop guns.

    They're placed through ItemMeshes (ReplicatedStorage.HoodItemMeshes after the user's one-time import), with our Part builds as the fallback. Studs on THESE models are fine; the user likes them.
30. **KEEP OUR shooting ranges** (the themed bays without side walls). The user: "i think the shooting ranges we have now actually are better". Don't use the designed Range_* booths. Target_Dummy MAY replace a lane's target if it fits.
31. **The user's goal** (verbatim): "keep them fit into place correctly, without ruining the games vibe, making it llook like the solider game please, use the gfx/vfx, correct placeement, well made on boarding, well done animations, well done on screen effects, so please make it well done this time so we can get close to release".
32. **Renders:** only the agreed proof shots; no exploratory render loops (the user asked to cut down on render work).

## Brief 33 (the user, after seeing the plaza; SUPERSEDES rules 22 and 26)
33. **The WAREHOUSE lobby is back, AROUND TODAY'S PLAZA LAYOUT (the user: "keep the layout how it is right now, and make it low-poly/blocky, and don't waste too many tokens")** (the user: "bring back the warehouse, it doesn't look as good right now … it gives the game more personality … keep the map the same and make the map just better and more soldier game looking like as i mean in style, not exact one to one").
    - Layout = TODAY'S (HEAD, the plaza layout); the warehouse SHELL goes around it, with no grass inside.
    - Low-poly/blocky style, small token budget.
    - Improve its STYLE toward the soldier game: vibrant, clean, chunky, readable, good light, item effects.
    - Rules 16 and 19 apply again: no grass inside; outside is a mix of clay cliffs and hood blocks.
    - Keep everything else decided since: our themed ranges without side walls, the user's blocky designs through ItemMeshes, the Robux sign, chunky text, the critic's floor/label/item-size points.
