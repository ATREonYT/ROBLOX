---
tags: [miami-trap-life, research, hood-games, art-direction, feel]
updated: 2026-11-03
---
# Reference game feel: what makes it look and feel good

2026-11-03 · Alex shared 13 screenshots of a hood RP game they like: "can you focus on making it feel more like this, its okay now, but i want the feel to be better, you can see the difference straight away."

Shots: [[#Shot index]] below, all in `shots/`. Contact sheet: `shots/_sheet.jpg`. The gap list against our map is in [[Feel Gap List - South Ends vs Reference]].

**Rule, same as every benchmark note: build our own version.** Take the recipe (haze, density, readable icons, chunky UI), never their assets, names, icon art or text. Kid-safe rules stay: the reference has a weed grow room ("GRASS DEALER") and real car names (Vette, GTR, Titan). We take neither; we only take the purple-light graffiti *look* and the dealer *layout*.

## The short version
The reference is not more detailed than South Ends. Its buildings are simple boxes and its interiors are fairly bare. It feels better for five reasons, in this order:

1. **One strong mood.** Every outdoor shot is the same dusty pink-lavender dusk with heavy fog. Far buildings melt into the haze, so the world feels deep and big, and the edges of the map are never visible.
2. **Palms and their shadows.** Tall thin palms line every street on both sides. The low sun throws long, sharp palm shadows across the road. That one thing says "Miami" in every frame.
3. **Big cartoon icons over places.** GUN SHOP, JOB, SWIPE, SHOP and Car Dealer float above their buildings, visible from far away. They work as wayfinding and as decoration at the same time, and they give the skyline colour.
4. **Lived-in streets.** Wrecked cars, a van on its rims, pallets under a tarp, trash bag piles, jersey barriers, iron fences, graffiti, pumpkins. Every few metres there is something to look at.
5. **Chunky, friendly HUD.** Big icon buttons with labels, fat bars, a gift timer. It reads as "game" instantly, even if each piece is simple.

## 1. Atmosphere and lighting
What you see (shots 02, 05, 08, 09, 10, 11):
- **Time of day:** late afternoon or early dusk. Sun low and to the side, so shadows are 3-5× the height of the object and cross the whole road.
- **Fog colour:** dusty rose at the horizon, sampled around RGB (190, 172, 180). Sky goes from that rose at the horizon up to a pale lavender-blue, around (180, 185, 207), with pink clouds.
- **Fog distance:** strong. Buildings 150-250 studs away are already half gone, and the end of every long street is a flat pink wall. Close objects stay crisp.
- **Shadows:** sharp, dark navy, not black. Road shadow samples around (50, 52, 66); deep shade (9, 14, 34). Shadows are cool, light is warm. That warm-vs-cool split is most of the mood.
- **Asphalt:** very dark blue-grey, almost navy, with crack decals. Sidewalks are near white. That contrast makes every street read clearly.
- **Interiors:** not part of the dusk. Warm cream walls, wood floors, plain ceiling panel lights, no bloom (06, 07). The odd one out is the graffiti room (13): fully purple-pink light with fog inside, which is a nice "secret place" contrast.
- **Night:** not in the shots, so no evidence.

Roblox recipe to try first (numbers are a starting point for the lighting thread, not tested):
- `Lighting.ClockTime` ≈ 17.2-17.6 (or ≈ 6.6 for a morning version), `GeographicLatitude` set so the sun sits 15-25° above the horizon.
- `Atmosphere.Density` ≈ 0.40-0.45, `Offset` ≈ 0.1-0.25, `Color` ≈ (199, 170, 175), `Decay` ≈ (106, 92, 130), `Glare` ≈ 0.2-0.5, `Haze` ≈ 1.5-2.5.
- `Lighting.ShadowSoftness` ≈ 0.1-0.2 (sharp), `OutdoorAmbient` cool lavender, `Ambient` dark navy so shade stays blue.
- `ColorCorrection`: slight pink-magenta tint (≈ 255, 240, 245), contrast +0.1, saturation +0.05 to +0.1. Keep `Bloom` low; the reference has almost none.
- A sky with pink clouds, or the default sky tinted by the Atmosphere.

## 2. Streets: palms, ground and props
- **Palms** (02, 03, 08, 09, 11): 40-60 studs tall, thin trunks, every ~25-35 studs along both curbs, set in the planting strip between curb and sidewalk. Some lean. Their shadows are the hero of every street shot.
- **Planting strips** (02, 08, 09): a raised curb strip of red-orange mulch with small bushes and a fire hydrant. It adds a warm colour line along every street.
- **Ground** (08, 09): thick, bright white zebra crosswalks; red-painted curb sections; road crack decals; scattered dead palm-leaf decals in gutters (02); manhole covers.
- **Street furniture:** cobra-head streetlights, stop signs, a parking meter, a payphone and newspaper box (10), benches, bus-stop sign, fire hydrants, iron and chain-link fences, utility poles with sagging wires in the alley (12).
- **Wrecks and mess** (02, 03, 10, 11, 12): a rusted sedan wreck in the road, a van on its rims with doors missing, a box truck with an open cab, pallets with a tarp, trash bag piles at walls and doors, cardboard and debris on the alley floor, jersey barriers, spider webs on a boarded shop.
- **Graffiti** (03, 10, 11, 12): big colour murals on long blank walls and tags on alley walls. It gives grey walls colour without detail work.
- **Seasonal props** (05, 10): jack-o'-lanterns at shop doors for Halloween. A cheap way to make the world feel alive and current.

## 3. Floating place icons (billboards)
Shots 02, 03, 05, 08, 09.
- Each key place has one big icon floating high above the roof: a cartoon picture (gun, briefcase, card, storefront) with a short bold word under it ("GUN SHOP", "JOB", "SWIPE", "SHOP"). Plain white text for Car Dealer.
- Style: thick dark outline, bright fill, slightly tilted. GUN SHOP text is red with a graffiti feel; JOB is yellow; SWIPE is light blue.
- They show from very far (you can see GUN SHOP from the next street in 09), and they shrink with distance but stay readable. Several in view at once make a colourful skyline.
- **Physical pole signs** add humour and local colour: a tall "RIFLES & PISTOLS / SALE / cheap guns fr" sign (08, 09) and a "PISTOLS" sign (05).
- Inside shops, NPC stations have floating coloured labels: GET WEAPONS (green), FILL AMMO (orange), AUTO DRACO DRUM (red), JANITOR JOB (green) (04, 06, 07).

## 4. Interiors
- **Gun shop** (06, 07): cream walls, warm wood floor, a dark runner mat, white glass display counters full of guns, a pegboard wall of rifles, posters with three gun cards, a big "NEW!" text, labelled NPC clerks. Full, warm, readable.
- **Supermarket** (04): honestly sparse. Half-empty shelves, but the *job mess* sells it: brown spill puddles on the floor, a yellow mop bucket, cardboard boxes by the door, a labelled janitor NPC. Mess means "something to do here".
- **Graffiti room** (13): wall-to-wall murals, purple-pink light and haze, wire racks, crates, duffel bags, cardboard boxes, a green glowing hand-in pad on the floor with painted arrows. Our use: a hideout or crew room. Not a grow room.
- **Car showroom** (01): plain grey garage with fluorescent tubes and a raised white floor. Simple, but the car is lit well and the UI does the work.

## 5. HUD
Shots 01-13 (same HUD everywhere).
- **Left icon rail**, vertically centred: four big square icon buttons with a label under each (Shop, Crews, Invite, Teams), cartoon 3D-style icons on blue tiles, and a "<" collapse arrow.
- **Bottom left:** a fat blue cash bar with a cash-stack icon and a green "+" button (buy cash), and under it a green 100/100 bar (health). We saw no XP bar on screen.
- **Top bar:** a "Daily Rewards 🎁" pill and five round icon buttons next to the Roblox menu.
- **Right edge, middle:** a gift icon with a red count badge and a countdown (playtime reward; the count goes 1 → 2 over the session).
- **Notifications:** a blue box bottom right, "Notification! Jewelry Store is open!" with a progress bar (12, 13).
- **Announcements:** big white outlined text top centre ("LIKE & FAVORITE THE GAME!", "JOIN THE GROUP!").
- **Hotbar:** one small slot bottom centre ("Phone").
- **Minimap:** small square bottom right (03, 07).
- **Prompts:** dark rounded "E · Buy Glock 19X for $2700" boxes (06, 07).
- Font: heavy rounded sans with a dark stroke everywhere.
- Honest read: our HUD is cleaner and more modern. What theirs has that ours lacks is **size, colour and labels**. Every button is big, bright and named, so a new player knows what each does without hovering.

## 6. Car dealer menu
Shot 01.
- You stand in a showroom; the selected car sits in the middle of the floor at full size.
- **Right column:** a scrolling list of cards, each with a car render, name and year.
- **Vehicle Stats panel** under it: Acceleration, Handling, Braking as green bars.
- **Colour row** bottom centre: 18 swatches, the car repaints live.
- **Buttons** bottom right: red X, yellow "Customize", blue "Buy ($200000$)".
- We use made-up car names and bodies only (see [[Car Model Shortlist]] and the benchmark gap list task 3.6).

## Shot index
| # | File | What to look at |
|---|---|---|
| 01 | `01 Car dealer showroom and stats menu.jpg` | Dealer list, stats bars, colour swatches, buttons |
| 02 | `02 Palm boulevard in dusk haze, Car Dealer label.jpg` | Haze depth, palms both sides, leaf decals, pallets + tarp, wreck |
| 03 | `03 Boarded shop, wrecked van, JOB icon.jpg` | JOB icon, van on rims, trash bags, barrier, spider webs |
| 04 | `04 Supermarket janitor job interior.jpg` | Spills, mop bucket, boxes, JANITOR JOB label |
| 05 | `05 Gun shop lot with GUN SHOP and SWIPE icons.jpg` | Stacked icons, pole sign, pumpkin, long shadows, pink sky |
| 06 | `06 Gun shop interior, wall racks.jpg` | Warm interior, pegboard wall, counters, station labels, buy prompt |
| 07 | `07 Gun shop interior, buy prompt and NEW sign.jpg` | Stocked counters, posters, NEW! text, minimap |
| 08 | `08 Intersection with SHOP icon and pole sign.jpg` | Fog wall at street end, crosswalks, mulch strips, SHOP icon |
| 09 | `09 Crosswalk, long palm shadows, RIFLES and PISTOLS sign.jpg` | Best single mood shot: palms, shadows, haze, signs |
| 10 | `10 Barber shop row, wrecked car, pumpkin.jpg` | Shop row facades, payphone, wreck, graffiti, announcement text |
| 11 | `11 Graffiti wall, van and box truck.jpg` | Mural wall, parked vans, palm shadows on road |
| 12 | `12 Back alley, trash bags, notification toast.jpg` | Alley dressing, utility poles + wires, notification box |
| 13 | `13 Graffiti room interior, purple light.jpg` | Purple interior mood, murals, crates, floor arrows |
