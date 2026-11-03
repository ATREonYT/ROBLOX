---
tags: [miami-trap-life, plan, gaps, art-direction, feel]
updated: 2026-11-03
---
# Feel gap list: South Ends vs Alex's reference game

2026-11-03. Compares our current build (shots in the project files from 2026-11-03: `04-hud-day`, `05-aerial-neighborhood`, `06-sunset-street`, `07-night-street`, `22 graffiti title`, `foodmart_entrance_after`, `01-supermarket-interior`, `hud_store_v3`) with the 13 reference shots in [[Reference Game Feel - Breakdown]].

**Where we already win:** story and cutscenes, guide arrows and goal cards, the phone, the Food Mart stock (our shelves are fuller than their supermarket), the title card, and a cleaner modern HUD. Don't throw those away to match.

**Where they win:** mood, depth, palms, place icons, street mess, warm interiors and big labelled buttons. None of these need new systems. They are mostly lighting values, props and UI layout, so this list is fast compared with the [[Benchmark Gap List]].

Size: S ≤ 1 day, M = 2-4 days, L = a week. Owner is the thread area the coordinator routes to.

## P0: the "see the difference straight away" items
| # | Gap | Us now | Reference | Change | Owner | Size |
|---|---|---|---|---|---|---|
| 1 | **Mood and haze** | Clear teal sky, crisp to the map edge, no depth. The sunset shot has glare but no haze. (The Quality Gap Report already ranks "hazy sky + grade" as gap #1.) | Dusty pink-lavender dusk, heavy fog, far blocks fade out, warm light vs cool navy shade | Make a "Vice Dusk" preset the default daytime look: Atmosphere Density ≈ 0.42, Color ≈ (199,170,175), Decay ≈ (106,92,130), Haze ≈ 2; ClockTime ≈ 17.4 with a low sun; ShadowSoftness ≈ 0.15; navy Ambient; light pink ColorCorrection tint, low Bloom. Day/night cycle should spend most of its time near this look | lighting | S |
| 2 | **Palm-lined streets** | A few palms; streets read as wide empty asphalt with poles and wires | Tall thin palms every ~30 studs on both curbs, long shadows across the road | Line every main street with palms (40-60 studs, mixed heights and leans) in curb planting strips. Use one palm model with 3 variants so it stays cheap | building | M |
| 3 | **Floating place icons** | Small circle chips (HOME, PARK, JOB) on the title card, plus an objective pill | Big cartoon icon + bold outlined word above every key place, readable from the next street | Add a world BillboardGui icon over each key place (Food Mart, Plug, Car Dealer, Job Centre, Apartment, Mechanic, Restaurant, ATM). Our own icon art, our own words, our own colours. Size by distance, max range ~600 studs, hide when inside. Tie into the existing waypoint system so the active goal's icon pulses | building (world) with HUD for the icon art | M |

## P1: makes the world feel lived in
| # | Gap | Us now | Reference | Change | Owner | Size |
|---|---|---|---|---|---|---|
| 4 | **Street clutter** | Clean streets, parked cars only | Wrecks, van on rims, pallets + tarp, trash bag piles, jersey barriers, fences, debris | Build a clutter kit (≈15 props) and dress every block: 1 wreck or dead vehicle per block, trash piles at every alley mouth and shop side door, pallets, barriers, chain-link and iron fences, cardboard, a dumpster per alley. Keep road lanes and sidewalks walkable | building | M |
| 5 | **Ground contrast and detail** | Dark asphalt with yellow lines, grey sidewalks, few decals | Near-white sidewalks, navy asphalt, thick white zebra crossings, red curb paint, mulch strips, crack and dead-leaf decals | Lighten sidewalks, darken the road toward navy, thicken crosswalk bars, add red-painted curbs at corners, red-orange mulch planting strips with bushes and hydrants, and scatter crack/leaf/manhole decals | building | S |
| 6 | **Graffiti and alleys** | Few murals | Big colour murals on blank walls, tagged alleys with poles and sagging wires | Put 1 big original mural on each long blank wall and tags in alleys. Dress alleys with utility poles, wires, electrical boxes with warning stickers, trash bags | building | S |
| 7 | **Warm, full interiors** | White walls that blow out under light (Quality Gap Report gap #2), tidy | Cream walls, wood floors, dark runner mats, wall racks, posters, labelled stations; the job space is messy on purpose | Warm wall colours and wood/tile floors in shops; wall racks and pegboards; posters; floating coloured labels over each NPC station; for job spaces, visible mess (spills, mop bucket, boxes) that the job then cleans. A purple-lit graffiti room for the crew hideout | interiors | M |
| 8 | **Chunky labelled HUD** | Sleek dark HUD, small icons, a grid button, money top right | Left rail of big labelled icon buttons, fat cash bar + "+" , health bar, top "Daily Rewards" pill, gift timer with badge, blue notification toast with a progress bar | Keep our layout ideas but make them chunkier: a left rail of 4-5 large labelled icon buttons (Shop, Crew, Garage, Jobs, Invite) with a collapse arrow; a bigger cash pill with a "+"; a fat health bar plus a thin XP bar under it; a playtime gift with a count badge and a real countdown; a notification toast with a progress bar for events. Heavy rounded font with a dark stroke | HUD | M |

## P2: polish and personality
| # | Gap | Us now | Reference | Change | Owner | Size |
|---|---|---|---|---|---|---|
| 9 | **Car dealer menu** | Dealership planned (Benchmark Gap List 3.1), no menu yet | Showroom with the car on the floor, right-side card list (render, name, year), stats bars, 18 colour swatches, X / Customize / Buy | Build the dealer screen to that layout with our own made-up cars: card list, Speed/Acceleration/Handling/Braking bars, live colour swatches, Test drive + Customize + Buy. Cars are never lost | cars | M |
| 10 | **Funny pole signs** | Shop name signs only | Tall roadside sale signs with jokes ("cheap guns fr") | 4-6 tall roadside signs with our own jokes for the Plug, car wash, pawn shop, chicken spot | building | S |
| 11 | **Seasonal props** | None | Pumpkins at shop doors | A date-driven Seasonal folder (Halloween pumpkins and webs now, lights in December) toggled on server start | building | S |
| 12 | **Announcements** | Tutorial toasts only | Big outlined top-centre text for server messages | Reuse the toast for server events (airdrop, store open), big outlined text. Skip "like the game" nags or keep them rare | HUD | S |

## What we should not copy
- Weed grow room, drug dealers and real gun or car brand names: against our kid-safe rules.
- Their bare boxy buildings and half-empty shelves: we're already better.
- Constant "JOIN THE GROUP / LIKE THE GAME" banners: one gentle prompt after a session is enough.

## Suggested order
1 → 2 → 5 → 3 → 4 → 8 → 7 → 6 → 9, then 10-12. Items 1, 2 and 5 alone should make a before/after screenshot look like a different game. Take the after shot from the same spots as `06-sunset-street` and `05-aerial-neighborhood`, and put it next to reference shot 09.
