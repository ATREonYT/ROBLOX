# How Roblox hood games build their maps, and a part-built Stage 1 block (2026-10-03)

> **How these notes were gathered (read first).**
> - **Sources.** Every web claim is a paraphrase of a **WebSearch result summary**, marked **[S]**, with its URL inline. **WebFetch was blocked by the egress proxy on every domain tried**: south-bronx-the-trenches.wiki, officialroms.com, dahoodwiki.wiki, builtbybit.com, roblox-hood-games-maps.pages.dev, aris-oww.itch.io, en.wikipedia.org and roblox.com. So no full page was read and **no screenshot was seen**.
> - **Inferences.** My design reasoning, dimensions in studs, palettes and part recipes are marked **[I]**. Where I describe what a game *looks like* from general familiarity rather than a source, it is marked **[I, unverified]**. Check those against 3–5 screenshots before relying on them.
> - **Local code.** Facts read from `/home/user/ROBLOX/hood/src` are marked **[L]**.
> - **What this builds on.** `hood_style_and_bags.md` §1.1 already covers the genre shorthand (brownstones, stoops, murals, court, subway, deli, bank), Spider-Verse, Do the Right Thing, Sesame Street, the bodega yellow-awning story, water-tank and hydrant-spray sources, and the Roblox alcohol rule. None of that is repeated here.
> - **Direction change.** That earlier note argued for a **saturated, candy-bright** hood. The developer has since said the result had **"too many colours"** and wants **"an actual looking hood"**. This note therefore argues for a **muted, believable base where colour is spent in a few small places**. For Stage 1 it supersedes §1.3 rules 3–7 of the earlier note.

---

## 0. TL;DR

1. **Hood maps read as "hood" through a continuous brick street wall, not through colour.**
   - Every hood map and kit description lists the same anatomy [S]: dense brick buildings, alleyways, a fenced court, a corner deli, a gas station, projects towers, train tracks and graffiti in the alleys.
   - Colour comes from **signage, cars and avatars**. Insomniac's Harlem shows "dull brickwork of the old high-rises" behind a few big murals [S].
2. **The one sourced critique of a Roblox hood map is our exact failure mode [S].** The DevForum thread "Hood style game MAP" got these comments:
   - "too much green", like a "happy deserted town"
   - buildings that look "washed" and too well kept
   - roads and sidewalks that need texture
   - graffiti placed on a third-floor wall "where nobody could realistically reach"
   - a look "in-between well kept and decrepit", which reads as unrealistic

   See [DevForum](https://devforum.roblox.com/t/hood-style-game-map/2938255).
3. **Pick one level of wear and commit to it.** For a kids' game, that level is **"worn but cared for"** [I]:
   - roller shades half down, window ACs, trash bags out at the curb
   - one roll-down gate with a street-level tag, chain-link around a lot that's now a garden

   No cracks, boarded windows or burned-out lots.
4. **Use a 12-colour palette with roles** [I, built on the 60-30-10 rule [S](https://bugnet.io/blog/color-palettes-for-indie-games)]:
   - about 60% greys: asphalt, concrete, off-white trim
   - about 30% three bricks plus iron "ink": red, brown, buff
   - about 10% accents: deli green, signal red, warm window light

   The last attempt used well over 50 saturated RGBs on top of a +0.25 saturation grade [L].
5. **Proportions matter more than detail [I].**
   - Keep floors at life height: 10–12 studs, since 1 stud = 0.28 m [S](https://devforum.roblox.com/t/what-is-the-real-height-of-a-stud/1523959).
   - Compress widths: 14–20-stud buildings stand for 25-ft lots [S].
   - Aim for buildings about as tall as the 40-stud street is wide, which is the 1:1 "enclosure" ratio urban designers rate best [S](https://www.cnu.org/publicsquare/2023/04/18/how-urbanism-density-and-spatial-enclosure-are-related).
6. **Silhouette kit: what to place [I, from S].**
   - Vary heights (2–6 storeys) and leave one gap (a vacant lot).
   - Add one water tank per side, zig-zag fire escapes on 1 in 3 facades, and cornices.
   - At street level: cobra-head lamps on grey octagonal poles, a hydrant, a green mesh litter basket, parked cars that are 80% white, black or grey [S], and **one** awninged deli on the corner.
7. **Ten stages, one hood.** Section 6 maps ten instantly readable scenes onto World 1's existing wall names [L]: Block, Court, Corner-store Avenue, Summer Block, Gas & Auto, Sidewalk-shed Street, Under the El, Block Party, Projects & Rooftops, Station.
8. **The genre's own content is mostly off-limits.**
   - Roblox prohibits "organized criminal activity, gangs and gang violence" [S].
   - It also bans depicting drugs, tobacco or vaping [S], and alcohol makes an experience 17+ (earlier note).

   So: no gun stores, trap houses, "trenches", liquor stores, lotto signs, police tape or real brands. Section 7 gives the swaps.
9. **Section 8 is the build spec.** It's a part-by-part 48-stud block, about 850 Parts, with exact sizes, positions and RGBs.

---

## 1. What the games and kits show (sourced)

### 1.1 The big hood games: map structure and the landmarks that matter

| Game | What sources say about the map [S] | Takeaway for us [I] |
|---|---|---|
| **Da Hood** (2019) | "Built like a small American city", "might remind you of Los Santos in GTA: San Andreas". About five named blocks are joined by main streets, alleyways and "a raised highway loop that runs along the outer edge": Bank Block (bank, ATM row, police, **basketball court**), Uphill/Projects (school, hospital, **projects housing**), the Strip (club, taco, burger, jewelry, **sewer entrance**), Downtown/Gym Block, and Suburbs/School Edge (houses, **parking lots**). [pocketgamer](https://www.pocketgamer.com/roblox/da-hood-map/), [hablamosdegamers](https://hablamosdegamers.com/en/guides/roblox-da-hood-map/) | **Districts with a job each**, plus a perimeter road that frames the playable blocks. |
| Da Hood, details | Uphill Park has "a bathroom and several benches" [fandom](https://da-hood-roblox.fandom.com/wiki/Uphill_Park). A secret club sits on top of a "**blue building with exterior stairs**" across from Hood Fitness, and a "rooftop parkour chain runs across three buildings" [sportskeeda](https://www.sportskeeda.com/roblox-news/are-secret-places-roblox-da-hood). There's a sewer pipe behind a fence next to the bank [pocketgamer](https://www.pocketgamer.com/roblox/da-hood-map/), and the gas station sits "on the map's periphery" [hablamosdegamers](https://hablamosdegamers.com/en/guides/roblox-da-hood-map/). | **Rooftops are part of the map.** Players expect to climb exterior stairs and fire escapes. |
| **The Streets** (2016, the genre's ancestor) | The Hood is "the area of the map where the most houses are", along with the gas station, bank, **court** and port. In The Streets 2, the hood area has "just a couple of homes, an **abandoned playground**". [The Hood](https://the-streets-roblox.fandom.com/wiki/The_Hood), [The Hood (TS2)](https://the-streets-roblox.fandom.com/wiki/The_Hood_(TS2)), [NamuWiki](https://en.namu.wiki/w/The%20Streets%20(Roblox)) | The court and gas station were already the anchors in 2016. |
| **Tha Bronx 3** | **Bronx Deli**: chopped cheese, a safe zone, "central part of the main Bronx region". Also a laundromat on "the main Bronx western street", a car dealership (NW), gas stations (west side), and a store "upstairs inside a building" with a "Roof Shop" beside it. [thabronx3.com](https://thabronx3.com/locations/tha-bronx-3-locations-guide/), [fandom](https://tha-bronx-3.fandom.com/wiki/Locations) | **The deli is the hub.** Upper floors and roofs hold content too. |
| Tha Bronx 3 cars | The dealership sells Caprice, Tahoe, Impala, K1500, a van, Suburban, "donks", Escalade, Magnum and similar [tha-bronx-3.wiki](https://www.tha-bronx-3.wiki/vehicles/tha-bronx-3-all-cars). | Parked-car silhouettes: **boxy 80s–90s sedans, big SUVs, vans, pickups**. Use generic bodies, never brands. |
| **South Bronx: The Trenches** (2022) | "Gritty streets, brownstone buildings". "The **subway area** serves as a landmark for navigation" and a money hub. The map also has delis, a chip factory, a casino, a graveyard, and a "**Boxing Facility** with tournaments". It is "dense, with floating sky icons… you still need to know which buildings generate money versus which are **empty shells**". [GameFAQs/summary](https://gamefaqs.gamespot.com/roblox/540655-south-bronx-the-trenches), [fandom](https://south-bronx-the-trenches.fandom.com/wiki/Locations), [sportskeeda](https://www.sportskeeda.com/roblox-news/south-bronx-guide) | **Most buildings are facades (shells).** Only a few open. A boxing gym is already genre-native. |
| **Philly Streetz 2** | A "dense, Philadelphia-inspired city". Landmark types: "economic nodes… loot interiors… **mobility lanes (long avenues for vehicles)**… danger blocks… **social hubs** (places people flex)". [phillystreetz2.wiki](https://phillystreetz2.wiki/map/) | Long straight avenues are a design element in their own right. |
| **Bronx Streetz** | "Apartments, houses, a car dealership, and a studio" [roblox.com summary](https://www.roblox.com/games/16995353837/Bronx-Streetz). | — |
| **Streetz War 2/3** | **London**-set, with "a police station, a dealership, and turfs" [roblox.com summary](https://roblox.com/games/11177482306/Streetz-War-2-1M-VISITS). | Not every hood is NYC, but ours should pick one city's vocabulary and stick to it [I]. |
| **Hood Customs / Da Hood Aim Trainer / Hood Modded** | Arena modes (1v1, 2v2, FFA, Anarchy) on Da Hood-like maps. Aim trainers are free-for-all with bots. "Inspired by Da Hood". [rolimons](https://www.rolimons.com/game/9825515356), [roblox.com](https://www.roblox.com/games/90718718036600/Da-Hood-Aim-Trainer), [robloxden](https://robloxden.com/game-codes/hood-modded) | **Clones reuse the Da Hood map grammar.** That grammar is what players recognise. |
| **City-themed RPs** | Atlanta Streetz (Zones 1/3/4/6, gas station, barbershop, tattoo, clothing) [roblox.com](https://www.roblox.com/games/114801278260975/Atlanta-Streetz). Detroit hood maps [BuiltByBit](https://builtbybit.com/resources/hood-map.59074/). Chicago maps (below). | Atlanta and Detroit lean **low-rise**: houses, lots and gas stations. NYC/Philly lean **dense rowhouses and walk-ups** [I]. |
| **Da Brickz** | "A da hood game with a twist, it has a **retro style** uncommon in most games nowadays". Testers liked "visual hints on actionable items". [DevForum](https://devforum.roblox.com/t/please-test-feedback-da-brickz-a-retro-style-da-hood-game/2022403) | **Precedent for a classic/retro (studded) hood.** |

### 1.2 What builders say makes a Roblox hood map read as "hood" [S]

From the DevForum "Hood style game MAP" feedback thread ([link](https://devforum.roblox.com/t/hood-style-game-map/2938255)):
- "The ambiance was … too ordinary with **too much green**", looking like "a **happy deserted town**."
- "The buildings look '**washed**' and not generally something you'd find in a hood, as the buildings would most likely not look as well kept."
- "If the road was cracked and in poor condition it would look more like a 'hood'." Roads and sidewalks "need texture."
- "The **graffiti** is completely incorrect and placed in odd positions such as outside a **3rd floor wall** where nobody could realistically reach."
- "Genuinely looks **in-between well kept and decrepit** which generally is unrealistic."
- "**Palm trees** [are] unlikely for a typical hood"; a homeless tent was "out of place".

How I apply this to a kids' simulator [I]:
- **"Too much green" is the lawns and lime caps.** TheBlockV2 uses 3-tone lime lawns plus lime grass caps on the terraces [L]. A hood block has almost no grass: one tree pit, one garden lot.
- **"Washed" means everything is pastel and evenly lit.** Fix it with darker, warmer brick, deep window "holes" (ink glass), and shadowed recesses.
- **Swap cracks for the cheapest honest wear:**
  - joint lines in the sidewalk
  - a manhole and a storm drain
  - one patched asphalt rectangle
  - shades at different heights
  - trash bags out at the curb
  - a gate that's down
- **Graffiti goes only where a person can reach:** gates, mailboxes, poles, dumpsters, the lower 8 studs of walls. The street-tag sources agree [S]: tags go on "mailboxes, poles, and dumpsters… newspaper boxes… subway columns, payphones, doorways" ([graffspace](https://www.graffspace.com/blog/graffiti-tags), [Street Fame](https://street-fame.com/graffiti-styles-101-the-official-street-bible/)). High "heaven spots" exist, but they're the exception.

Related DevForum advice [S]:
- "One common mistake… is using **too many bright colors together**."
- For realistic builds, "grab a reference image… and try to match the colors."

Source: [DevForum colour-palette threads](https://devforum.roblox.com/t/feedback-on-color-scheme-of-this-map/297405).

### 1.3 What hood map kits list as essential [S]

| Kit | Contents as described |
|---|---|
| **Chicago, Illinois** (BuiltByBit 71438) | "Trap houses… normal houses… shopping centres with **auto shops, barbers, large stores and projects**… apartment blocks… **parking lots, train tracks, alleyways**, a graveyard, a high school… a grocery store, shoe store, women's hairdresser, music recording studio, **pawn shop**." [link](https://builtbybit.com/resources/chicago-illinois.71438/) |
| **Chicago, Illinois** (Pulse Development, 72190) | "Apartments, restaurants, **graffiti-filled alleyways and train tracks**… barber shop… food markets." [link](https://builtbybit.com/resources/chicago-illinois.72190/) |
| **Aris Oww Chicago RP** | **2244 × 2480 studs**, "once recognized as the best-looking hood map on Roblox", "stunning lighting", "dynamic weather". It includes "public housing projects" and **adult interiors we must not copy** (drug crates, alcohol, guns on sofas). [itch.io](https://aris-oww.itch.io/roblox-chicago-roleplay-map) |
| **Payhip "Bronx Urban RP Map"** | "Realistic street layouts, **dense buildings, alleyways**… **outdoor basketball courts, detailed street corners**, and urban props". A 7 MB RBXL. [link](https://payhip.com/b/VXCyf) |
| **ClearlyDev "Realistic Hood Shooter Map"** | "Various **Streets & Sidestreets**, Gun Store, **Two Groceries Stores, Basketball Court, Small Park**… **Car Garages**." [link](https://clearlydev.com/product/realistic-hood-shooter-map) |
| **ClearlyDev "New York: Detailed Hood Map"** | "Hidden corners and underground bunkers", "**Scripted Street Lights**… for nighttime", safe zones. [link](https://clearlydev.com/product/new-york-detailed-hood-map-with-scripted-systems) |
| **Creator Store "Bronx Building for Hood Game"** | A single building. The creator says they made everything except the "**Roll up garage door**" from the toolbox. 5,236 triangles. [link](https://create.roblox.com/store/asset/77763562844431/Bronx-Building-for-Hood-Game) |
| **BuiltByBit Detroit "Hood map"**, Baltimore RP, "South Atlanta, USA" | "Big ghetto map based in Detroit", "big builds", "big suburban area". [link](https://builtbybit.com/resources/hood-map.59074/), [South Atlanta](https://builtbybit.com/resources/south-atlanta-usa.38869/) |

**[I] Consensus kit.** The kits agree on these pieces:
- brick apartment blocks and walk-ups
- a corner grocery or deli
- a barber
- an auto shop or garage with roll-up doors
- a fenced court
- a small park
- alleys with graffiti
- train tracks or an el
- projects towers
- a gas station
- parking lots
- working street lights

The roll-up garage door is common enough that people pull it from the toolbox.

### 1.4 Non-Roblox game references for the same streets [S]
- **GTA IV, Bohan (Bronx parody).** "An **elevated train passes between tenement buildings**." The Northern Gardens Projects sit beside small convenience shops. [GTA wiki](https://gta.fandom.com/wiki/Bohan)
- **Marvel's Spider-Man: Miles Morales (Harlem).** "The **dull brickwork** of the old high-rises hides behind giant, colorful murals." The game also has "store street-level storefronts that resemble Spanish Harlem". [GameSpot](https://www.gamespot.com/articles/spider-man-miles-morales-enriched-an-already-thriving-new-york/1100-6536102/), [But Why Tho](https://butwhytho.net/2020/11/spider-man-miles-morales-is-uniquely-harlem/). **[I]** This is the restrained-palette proof: brick stays dull, and colour arrives in a few big placed spots.
- **GTA San Andreas, Grove Street.** A **cul-de-sac** "with single-story homes, front yards, **chain fencing**". It's based on Palmwood Drive, Crenshaw. [gta.fandom](https://gta.fandom.com/wiki/Grove_Street_(3D_Universe)). **[I]** That's the West Coast/Atlanta template, if a later world wants low-rise.

### 1.5 What I could not verify
- **No exact palette, material or lighting values** from Da Hood, Tha Bronx 3, South Bronx or Philly Streetz 2. No source described them in text.
- **[I, unverified] My general impression.** Older hood maps (Da Hood era) are mostly flat-coloured parts in stock Brick/Concrete/Asphalt materials: greys, browns, dull reds and dark roads. Newer "realistic" ones (Tha Bronx 3, Philly Streetz 2, the BuiltByBit Chicago maps) add textures and decals, and lean on overcast, dusk or night lighting.
- Either way the walls are not where the colour lives. Confirm this with a handful of screenshots before quoting it to anyone.

---

## 2. Street layout

### 2.1 Real dimensions and stud equivalents

1 stud = 0.28 m (Roblox's official conversion) [S](https://devforum.roblox.com/t/what-is-the-real-height-of-a-stud/1523959). So 1 ft ≈ 1.09 studs.

| Element | Real-world fact [S] | Studs at true scale [I] | Use in game [I] |
|---|---|---|---|
| Side-street right-of-way | 60 ft (Manhattan standard cross street); avenues 100 ft [Commissioners' Plan](https://en.wikipedia.org/wiki/Commissioners'_Plan_of_1811) | 65 (avenue 109) | **40** (road 20 + 2×10). Avenue stages: 56–64. |
| Roadway curb-to-curb | Local residential 26–36 ft; a 60-ft ROW has 34–40 ft of roadway with 2 parking lanes ([search summary of NYC sidewalk/street pages](https://libertygcny.com/how-wide-is-a-sidewalk-nyc-westchester/)) | 28–44 | **20** = 2 parking lanes of 5 + a 10-stud travel strip |
| Sidewalk | NYC DOT desirable widths run from 8 ft+ on "Baseline Streets" up to 25 ft+ on major corridors ([same](https://libertygcny.com/how-wide-is-a-sidewalk-nyc-westchester/); [Streetsblog](https://nyc.streetsblog.org/2020/04/23/this-is-not-an-opinion-column-new-yorks-sidewalks-really-are-too-narrow)) | 9–27 | **10** (generous, which suits running) |
| Block length | Manhattan blocks are 200 ft N–S × 600–920 ft E–W [Commissioners' Plan](https://thegreatestgrid.mcny.org/greatest-grid/making-the-plan/12) | 218 × 650–1000 | A stage of 40–48 studs is **one short stretch of a block**, never a whole block |
| Tenement lot | Usually **25 × 100 ft**, **5–7 storeys**, "four… apartments per floor" [Old Law Tenement](https://en.wikipedia.org/wiki/Old_Law_Tenement) | 27 wide | **14–20 wide** |
| Philly rowhouse | **14–18 ft** wide, brick, cornice and parapet; full-width porches common in N/W Philly [hiddencityphila](https://hiddencityphila.org/2017/06/row-house-past-and-its-future/), [phillyhomeadvisors](https://phillyhomeadvisors.com/blog/philadelphia-rowhome-styles-a-buyers-guide) | 15–20 | 12–16 wide |
| Floor-to-floor | 9.5–10 ft residential ([search summary](https://www.adventuresincre.com/glossary/floor-floor-height/)) | 10–11 | **10** upper, **12** ground storefront |
| Enclosure ratio | Best "sense of enclosure" at height:width **1:1**; worse than **1:4** reads car-oriented [CNU](https://www.cnu.org/publicsquare/2023/04/18/how-urbanism-density-and-spatial-enclosure-are-related) | — | 40-wide street → **35–65-stud** street wall |

**[I] Compression rule.** Keep **vertical scale real** so doors, windows and floors look right next to a 5–6-stud avatar. Compress **horizontal scale to about 60–70%**. A 40-stud street with 4–5-storey walls (about 45–55 studs) then lands at about 1.1–1.4:1. That reads as a proper city canyon without hiding the sky.

### 2.2 Block anatomy that sells "real street" [I, from S]

- **Continuous street wall.** Buildings meet edge to edge at the property line (x = ±20), with no side yards. Only the brownstone gets a **3-stud areaway** (front well) behind an iron fence, because that's the real type.
- **One gap per block face.** A **vacant lot behind chain-link** shows the side walls of its neighbours. South Bronx gardeners turned rubble lots into **community gardens with fences, raised beds and "casitas"** [S](http://theprotocity.com/casitas-in-the-south-bronx/), [S](https://www.cityfarmer.org/casitas.html). That's the kid-safe version of the lot.
- **The corner is commercial.** The deli or bodega sits on the corner, often with a wrap-around awning. Mid-block is residential with one or two shops.
- **Alleys.** NYC tenement blocks rarely have through-alleys [I]. Chicago's are famous: the South Side "Alley L" ran on steel trestles "above the alley itself" [S](https://www.chicago-l.org/history/southside.html). Use alleys in a Chicago or Philly stage, not on the NYC block.
- **Intersections.**
  - Zebra crosswalk, with bars running parallel to traffic.
  - Corner lamp plus traffic signal, a hydrant near the corner, the mailbox and litter basket at the corner.
  - A bus stop on avenues only.
- **Courts and parks are fenced islands.** Playgrounds are "sections bordered by chain link fence with **handball courts**". NYC has over 1,940 handball courts, "utilizing existing walls of buildings or standing tall on their own" [S](https://hunterurbanreview.commons.gc.cuny.edu/new-yorks-home-courts/), [S](https://www.spottedbylocals.com/new-york/the-cage-in-west-village/).
- **Projects break the grid.** Red-brick towers sit "around landscaped open areas… lawns, wide walkways" and "vast stretches of **barren asphalt**" [S](https://en.wikipedia.org/wiki/Cypress_Hills_Houses), [S](https://urbanomnibus.net/2025/01/more-than-skin-deep/). That makes them a **separate stage** (a plaza), not part of the Stage 1 block.

---

## 3. Buildings

### 3.1 Typology, with what is sourced and how it translates to studs

| Type | Sourced facts [S] | Stud recipe [I] |
|---|---|---|
| **Tenement walk-up** (the default hood building) | 5–7 storeys on 25-ft lots. Old-law: "four- or five-story **red brick** structures with **stone or terra-cotta window details** and a neo-Grec **pressed metal cornice**". New-law: "up to six stories with brick and glazed terra-cotta trim". [Old Law Tenement](https://en.wikipedia.org/wiki/Old_Law_Tenement), [Village Preservation](https://villagepreservation.org/2022/05/17/the-evolution-of-tenement-typologies-in-the-east-village/) | 14–20 wide; ground 12 + 10 per floor; **3–4 window bays at 5-stud pitch**; off-white sills and lintels; projecting cornice 1.2–1.4; storefront at grade. |
| **Brownstone** | A "tall **10- to 12-step stoop**"; the parlor floor is "about **six feet up**" with high ceilings; an English basement is partly below grade. Anglo-Italianate versions have only 2–4 steps. [Brownstoner](https://www.brownstoner.com/architecture/what-is-the-anglo-italianate-architecture-style-mid-19th-century-brownstone-brooklyn-nyc/), [HomeLight](https://www.homelight.com/blog/buyer-what-is-a-brownstone/) | 16 wide; 3-stud areaway; **5 risers × 1.2** up to a parlor floor at +6; parlor floor 11 tall with taller windows; dark bracketed cornice. |
| **Philly porch rowhouse** | 14–18 ft wide, red brick, cornice and parapet, "**full-width porches**"; Philly is an **aluminum-awning** town (Humphrys, since 1874) [Philly Home Advisors](https://phillyhomeadvisors.com/blog/philadelphia-rowhome-styles-a-buyers-guide), [Humphrys](https://humphrysawnings.com/residential/aluminum-awnings) | 12–14 wide, 2 storeys plus porch roof; striped metal awning (2 colours from the palette). Use it for a "Summer Block" stage. |
| **Baltimore rowhouse** | White **marble steps**, "keeping them clean became an art". **Formstone** stucco molded to look like stone. [Baltimore Magazine](https://www.baltimoremagazine.com/section/homegarden/baltimore-rowhome-architectural-history/), [Smithsonian](https://americanart.si.edu/artwork/view-east-baltimore-looking-west-brick-row-houses-and-white-117908) | Steal the **white steps** for one door per block. Off-white and cheap, they read as "cared for". |
| **Projects tower** | "Boxy red brick… very little trim". Heights vary: 7 storeys (Cypress Hills), 9–14 (Forest Houses), 25 (Holmes Towers). "Towers in the park": "simple, brick or concrete-clad high-rise… with little ornamentation". [Urban Omnibus](https://urbanomnibus.net/2025/01/more-than-skin-deep/), [Cypress Hills](https://en.wikipedia.org/wiki/Cypress_Hills_Houses), [Forest Houses](https://en.wikipedia.org/wiki/Forest_Houses), [Towers in the park](https://en.wikipedia.org/wiki/Towers_in_the_park) | 30×30 footprint (or a cross plan), **8–14 floors at 9 studs** (72–126 tall); a flat grid of identical windows; no cornice; concrete base band; set back 20+ studs on asphalt. |
| **Taxpayer** (1–2-storey commercial row) | "A one- or two-story building… as a temporary revenue stream". "The ground floor could be divided into **multiple storefronts**". By 1933, every plan on 3rd/Lex/Madison was for one. [Taxpayer](https://en.wikipedia.org/wiki/Taxpayer_(building)), [Brownstoner](https://www.brownstoner.com/architecture/taxpayer-buildings-architecture-history-670-nostrand-avenue/) | **The corner-store strip:** 14–16 tall, 3–4 shopfronts of 10–12 each, one long sign band, a low parapet. A good way to drop the skyline between tall walk-ups. |
| **Corner deli / bodega** | "Bright, corrugated metal awnings and signs" whose origin "nobody seems to know"; "red and yellow awnings… 'cold cuts and cold beer'"; "**privilege signs**" with soda logos paid for by brands. [Gothamist](https://gothamist.com/food/ask-a-native-new-yorker-whats-the-difference-between-a-bodega-a-deli-corner-grocer), [Juke](https://www.juke.press/p/the-yellow-awnings-of-new-york) | Corner ground floor of a walk-up. One awning (wrap the corner), an "OPEN" light, crates, a menu board. **No beer, lotto or brand signs** (section 7). |
| **Roll-down gates** | Solid corrugated gates "turned city blocks into dark, **graffiti-strewn metal alleyways**" at night. Since 2011, new gates need **70% visibility**, and old solid ones must be replaced by **1 Jul 2026**. **Commissioned gate murals** "are a New York art form". [NBC NY](https://www.nbcnewyork.com/news/local/ban-on-solid-rolldown-gates-takes-effect/1869901/), [Nacmias Law](https://nacmiaslaw.com/resources/articles/gate-gate-nyc-storefront-security-gate-law) | **One closed gate per block** (grey with horizontal slats). Use it for a street-level tag or a kid-friendly gate mural. Put a gate-box housing over every other shop. |
| **Storefront church** | Occupies "a former beauty parlor"; storefronts are "highly visible… exteriors zoned for signage". [Storefront church](https://en.wikipedia.org/wiki/Storefront_church), [The Site Magazine](https://www.thesitemagazine.com/read/storefront-worship) | A shopfront with a hand-painted sign band and curtains in the window. A quiet, real hood detail. |
| **Chicken / takeout spot** | Chicken shops "mainly **red, yellow, and black**"; backlit signs [antdisplay](https://antdisplay.com/Ideas/too-easy-to-open-an-american-fried-chicken-shop/) | A backlit menu box over the counter window. A good place to spend the red accent on the Avenue stage. |
| **Auto / tire shop** | Willets Point's "Iron Triangle": about 225 auto body shops with "stacks of tires" [Slate](https://slate.com/human-interest/2013/11/willets-point-queens-iron-triangle-auto-body-shops-new-york-city-neighorhood.html) | Two roll-up garage doors (10 wide × 10 tall), tire stacks (ink cylinders), chain-link yard. |
| **School** | Da Hood has a school and "High School" [pocketgamer](https://www.pocketgamer.com/roblox/da-hood-map/) | **[I]** A 4-storey buff-brick "PS ###" with a chain-link schoolyard and a handball wall. Useful backdrop for the Court stage. |

### 3.2 Facade and roof clutter (the "life" layer)

| Item | Sourced facts [S] | Stud recipe and frequency [I] |
|---|---|---|
| **Fire escapes** | Balconies "not less than **3'-4"** in width overall and may project… **up to 4 feet**". Drop ladder "**15 inches** in width… not more than **16 feet**". Gooseneck ladder to the roof. Introduced after 1860s tenement fires. [1 RCNY §15-10](https://www.nyc.gov/assets/buildings/rules/1_RCNY_15-10.pdf), [Old Law Tenement](https://en.wikipedia.org/wiki/Old_Law_Tenement) | Balcony 3.6 deep, spanning 2 bays; deck 2.4 above each floor; zig-zag stair between decks; a 1.4-wide drop ladder ending about 7 above the sidewalk. Ink. On **1 in 3 walk-ups**. |
| **Water tanks** | "**10 to 12 feet** in both diameter and height… around 10,000 gallons"; "Western red and yellow **cedar**", held by **steel straps**; on steel stands [JLC](https://www.jlconline.com/how-to/watering-manhattan_o), [6sqft](https://www.6sqft.com/nyc-water-towers-history-use-and-infrastructure/) | True scale is 11–13 studs. Use 8–9 on compressed roofs. Brown body, 3 ink hoops, dark conical roof, 4-leg stand. **About 1 per side per block.** |
| **Window ACs** | Ubiquitous. NYC requires **exterior brackets** above the first floor (Local Law 11 for 6+ storeys) [Brick Underground](https://www.brickunderground.com/improve/window-air-conditioner-ac-installation-rules-brackets-dripping-safety-nyc) | Off-white box 2.4×1.6×1.8 on the sill with 2 ink brackets. **About 1 in 4 upper windows**, never ground floor. |
| **Satellite dishes** | — | **[I]** 1–2 per block, off-white, on parapets or high walls. |
| **Rooftop pigeon coops** | "In the 1950s, almost every other low-rise roof in certain neighborhoods… had a coop"; Brooklyn flocks "circling overhead in massive flocks" [NatGeo](https://www.nationalgeographic.com/photography/article/pigeon-keeper-brooklyn-bird-brain-photos), [Messy Nessy](https://www.messynessychic.com/2013/09/11/the-rooftop-pigeon-men-of-new-york/) | Plywood shed with mesh front. The hero of the "Pigeon Flock" stage. |
| **Ground-floor window bars** | — | **[I]** On residential ground-floor windows only: 3 vertical ink bars + 1 horizontal. It reads "city", not "prison", if it stays thin. |
| **Roller shades** | — | **[I]** An off-white panel over the top ⅓ of about 1 in 4 windows. This is the cheapest realism in the whole kit. |

---

## 4. Materials, palette and light

### 4.1 What the sources say colours are [S]
- **Brick.**
  - "Common brick" in NYC is "the standard **reddish**-colored clay brick".
  - Many **Bronx** Art Deco apartment houses have "predominantly **yellow or beige** brick facades".
  - Some are "vibrant red bricks and **brown trim**".
  - Others mix "**yellow, orange, and brown** bricks".

  Sources: [CooperatorNews](https://cooperatornews.com/article/on-the-bricks), [Untapped Cities](https://www.untappedcities.com/10-pre-war-apartment-house-gems-of-the-south-bronx-nyc/).
- **Projects:** red brick with "very little trim" [S](https://urbanomnibus.net/2025/01/more-than-skin-deep/).
- **Basketball courts:** "nearly **two-thirds** of the surface area… is made up of **gray** tones" across more than 1,600 NYC courts. A minority are green, blue or red. Jackie Robinson Park's refit used "teal, black, and gray". [Nate Rattner, Courts of New York](https://naterattner.com/courts-of-new-york/), [NYC Parks](https://www.nycgovparks.org/parks/jackie-robinson-park_brooklyn/pressrelease/22262)
- **Cars:** white 25.7%, black 23.4%, gray 22.9%, silver 8.4%. Grayscale is **80.4%** of the market. [Motor1 / iSeeCars summary](https://www.motor1.com/news/800113/car-colors-usa-popularity/)
- **Street lamps:**
  - Octagonal aluminum or galvanized-steel poles, "usually **silver or gray**-painted", with a **cobra-head** luminaire.
  - The Type 10 pole (Donald Deskey Associates, GE cobra head) was installed more than 11,000 times in 1963–65.
  - Older "Bishop's crook" posts survive in places.

  Sources: [Forgotten NY](https://forgotten-ny.com/2012/03/know-your-lampposts-the-curved-masts/), [Cooper Hewitt](https://www.cooperhewitt.org/2016/10/12/drumming-up-a-streetlight/).
- **Sidewalk sheds:** solid panels must be **hunter green**, using standard 4' × 8' plywood sheets [NYC Admin Code 3307.6.4.11](https://codelibrary.amlegal.com/codes/newyorkcity/latest/NYCadmin/0-0-0-186242), [NYC DOB](https://www.nyc.gov/assets/buildings/pdf/sheds_scaffolds_fences.pdf).
- **Litter baskets:** "the **green, wire-mesh** basket… largely unchanged since the 1930s", more than 23,250 of them. Being replaced since 2023 by grey "Better Bins". [amNY](https://www.amny.com/news/trash-can-designs-nyc-1.20240251/), [DSNY](https://www.nyc.gov/site/dsny/collection/containerization/litter-basket-of-the-future.page)
- **Mailboxes:** "USPS **Dark Blue**" since 1971 [PostGrid summary](https://www.postgrid.com/usps-mail-collection-box/).
- **Hydrants:** the standard body is "chrome yellow", but practice varies by city. **Cap colour encodes flow**: red under 500 GPM, orange, green, then blue over 1,500. [QRFS](https://blog.qrfs.com/286-fire-hydrant-colors-their-nfpa-spectrum-and-meaning/)
- **Subway globes:** **green** means an open entrance and red means exit only. Half-moon globes appeared in the mid-90s. [Untapped Cities](https://www.untappedcities.com/cities-101-the-actual-purpose-of-nyc-subway-globes/)
- **Trash:** NYC has "for decades… piled its trash in heaps of **bags** on city sidewalks" the evening before collection. Smaller buildings have been required to use lidded bins since Nov 2024. [NPR](https://www.npr.org/2023/09/30/1202863246/nyc-trash-bags-out-bins-in), [DSNY](https://www.nyc.gov/site/dsny/collection/residents/trash.page)

**[I] Takeaway.** In the real place, almost everything big is grey, brown or brick red. Green is reserved for municipal objects (litter baskets, sheds, subway globes, sign blades). Red appears in small hardware. The "hood colour" people remember is **signage and murals on a dull base**, which matches Insomniac's Harlem [S].

### 4.2 Diagnosis of the last attempt [L]
- The palette table `P` in `hood/src/ServerStorage/TheBlockV2.lua` (lines 24–60) defines:
  - 8 "candy" facade hues, plus 3 era sets of 8 / 8 / 6
  - 4 door/awning accents, 4 flower colours, 5 Memphis colours, 4 chalk colours, 3 crate colours
  - lime lawns and caps, plus brick, trim and props
  - a **10-stage hue ladder** (lime → teal → blue → violet → pink → red → orange → gold)

  That's well over 50 distinct, mostly high-saturation RGBs.
- The `FrontPage` lighting preset then adds **ColorCorrection Saturation +0.25** (`HoodLighting.lua`).
- **[I]** Every facade competes, so nothing reads as "brick street". The players' own avatars and the stage gate, which should be the loud objects, get drowned out.

### 4.3 Palette rules for the hood [I]
1. **Use 12 colours with fixed roles (section 8.1).** Nothing outside the table goes into the Stage 1 build except player-facing UI and the gate.
2. **Follow 60-30-10 by area** [S](https://bugnet.io/blog/color-palettes-for-indie-games):
   - 60% neutrals: asphalt, concrete, off-white trim
   - 30% masonry and ink: three bricks plus iron
   - 10% accents: deli green, signal red, warm light
3. **One accent per facade, at most.** The deli's accent is its green awning. The barber's is its red-white pole. The brownstone's is its oxblood door. All other facades get none.
4. **Neighbours differ by one brick step.** Never two identical bricks side by side. Alternate red → brown → red, or buff → gap → brown.
5. **Glass is ink, not blue.** Windows read as deep holes. About 1 in 6 is warm-lit, about 1 in 4 has a half-drawn off-white shade.
6. **Green appears only on municipal or retail objects:** awning, litter basket, one tree, hydrant caps, the signal's green lens. No lawns on the block.
7. **The stage gate is the one saturated object in view.** If the gate stays saturated, everything around it must stay in the palette.

### 4.4 Lighting for "an actual looking hood" that is still kid-friendly [I]
Starting values for a new preset, "BlockAfternoon", to sit beside `FrontPage`/`GoldenBlock` in `HoodLighting.lua`. Tune them in Studio.

- **Lighting:**
  - LightingStyle Soft, ClockTime about 15.0–15.5. Choose the hour so the sun **rakes one side** of the street and the other side is in shade. Two-tone facades are the most "real street" cue there is.
  - Brightness 2.6, ExposureCompensation 0
  - Ambient (118,118,126), OutdoorAmbient (138,138,150)
  - ColorShift_Top (255,236,214), ColorShift_Bottom (90,96,120)
  - EnvironmentDiffuseScale 0.4, EnvironmentSpecularScale 0.08, ShadowSoftness 0.15, GlobalShadows on
- **Atmosphere:** Density 0.3, Offset 0.2, Haze 1.0, Glare 0, Color (200,196,188) (warm grey city haze), Decay (150,154,168)
- **ColorCorrection:** Saturation **0.0** (not +0.25), Contrast 0.08, Brightness 0, TintColor (255,250,242)
- **Bloom:** Intensity 0.3, Size 24, Threshold 1.6. Only Neon (the OPEN sign and lamp lenses) should bloom.
- **SunRays:** 0.02.
- **Night or "Block Party" variant:** use the existing GoldenBlock at Saturation 0.1. Turn on lamp SpotLights (warm (255,214,150), Range 28, Angle 70) and lit-window Neon.

---

## 5. Street furniture and clutter: what sells "hood"

| Prop | Sourced facts [S] | Recipe in studs, palette ids from 8.1 [I] | Stage 1? |
|---|---|---|---|
| **Cobra-head lamp** | Grey octagonal pole, cobra-head luminaire, the 1963–65 Type 10 standard [Forgotten NY](https://forgotten-ny.com/2012/03/know-your-lampposts-the-curved-masts/), [Cooper Hewitt](https://www.cooperhewitt.org/2016/10/12/drumming-up-a-streetlight/) | Pole P4 Ø0.6 × 18; base collar Ø1.0 × 1.5; arm Ø0.35 rising at 20° for 2 then horizontal 4; head P5 2.2×0.7×1.0; lens P12 1.6×0.1×0.7 (Neon only at night). Every 24–30 studs, alternating sides. | yes, 3 |
| **Traffic signal** | — | Pole P4 Ø0.7 × 16, mast arm P4 to the road centre; head P9 1.2×3.2×1.2 with 3 lenses Ø0.8 (P11 / P12 / P10). | yes, 1 at the corner |
| **Hydrant** | Cap colour encodes flow (green = 1,000–1,499 GPM) [QRFS](https://blog.qrfs.com/286-fire-hydrant-colors-their-nfpa-spectrum-and-meaning/) | 1.4× hero size: barrel P11 Ø1.3 × 2.4, dome Ball Ø1.3, 2 side nozzles Ø0.6 × 0.5 and top nut in P10. 1 stud from the curb. | yes |
| **Litter basket** | Green wire-mesh, since the 1930s [amNY](https://www.amny.com/news/trash-can-designs-nyc-1.20240251/) | Cylinder P10 Ø2.0 × 3.0, rim ring P9 Ø2.1 × 0.25. At corners only. | yes |
| **Curbside trash bags** | Bags out the evening before collection [NPR](https://www.npr.org/2023/09/30/1202863246/nyc-trash-bags-out-bins-in) | 3 P9 Balls (Ø2.2 / 1.8 / 2.0) plus 1 P4 can. **One cluster per block, never a pile.** | yes |
| **Dumpster** | — | P5 box 6×3.5×4, P9 lid wedge, 4 P9 casters. In lots and alleys, never on the sidewalk. | yes, in the lot |
| **Mailbox** | USPS dark blue [PostGrid](https://www.postgrid.com/usps-mail-collection-box/) | Spot navy 2.2×3.0×2.2 plus a half-cylinder top, 4 P9 legs 0.6. At a corner. | yes |
| **Bus shelter** | NYC regular shelter **14 × 5 × 8'11"**, stainless and glass, side ad panels, "uncluttered transparency" [NYC Street Design Manual](https://www.nycstreetdesign.info/furniture/bus-stop-shelter) | 13×5×9: P4 frame, glass P3 at Transparency 0.7, an ad panel showing **an in-game poster** (never a real brand). | Avenue stage |
| **Newsrack** | ≤50" H × 24" W × 24" D; 18–24" from the curb [NYC DOT](https://www.nyc.gov/html/dot/html/infrastructure/newsracksintro.shtml) | 2 boxes 2×4×2, P4 and P5. | Avenue stage |
| **Payphone** | Removed citywide (2022) [I] | Skip. It's a retro prop at best. | no |
| **Parked cars** | 80% of cars are white/black/grey/silver [Motor1](https://www.motor1.com/news/800113/car-colors-usa-popularity/). Hood games sell boxy sedans, SUVs, vans and pickups [S](https://www.tha-bronx-3.wiki/vehicles/tha-bronx-3-all-cars) | Boxy sedan 4.4×10 and SUV 4.6×11 (section 8.6). 3 of 4 grayscale, 1 oxblood. | yes, 4 |
| **Sidewalk shed** | Hunter-green panels, 4'×8' plywood [NYC code](https://codelibrary.amlegal.com/codes/newyorkcity/latest/NYCadmin/0-0-0-186242) | Posts P4 every 8, deck 10 above the sidewalk, plywood skirt in P10 panels 4.4×8.8; flyer posters P3. | Scaffolding stage |
| **Cones / barriers** | — | **[I]** Blue-and-white wooden sawhorse barricades (block party), orange-and-white drums (construction). Each adds a new colour, so **only in their own stages**. | no |
| **Graffiti / tags** | Street-level tags on gates, mailboxes, poles and dumpsters; high "heaven spots" are rarer [graffspace](https://www.graffspace.com/blog/graffiti-tags), [Street Fame](https://street-fame.com/graffiti-styles-101-the-official-street-bible/). Third-floor graffiti reads wrong [DevForum](https://devforum.roblox.com/t/hood-style-game-map/2938255) | 3–5 thin P9 strokes on the gate, 2.5–6 above the sidewalk. One per block. | yes, 1 |
| **Murals** | Commissioned gate and wall murals are "a New York art form" [Nacmias](https://nacmiaslaw.com/resources/articles/gate-gate-nyc-storefront-security-gate-law); Harlem murals cover dull brick [GameSpot](https://www.gamespot.com/articles/spider-man-miles-morales-enriched-an-already-thriving-new-york/1100-6536102/) | One per block, on a side wall exposed by the lot. **Three palette colours only.** | yes, 1 |
| **Posters** | — | **[I]** Wheatpaste: 3 P3 rectangles 2×3 at slight angles, on plywood or a pier. | yes |
| **Power lines** | Center City Philly is free of overhead wires; the rest "has regressed", with poles everywhere [Hidden City](https://hiddencityphila.org/2013/01/wired-city/) | Wood poles (P7) with crossarms and 3 sagging wires (P9 0.15 rods), in **Philly, Chicago or Atlanta stages**. NYC blocks have no overhead wires [I]. | no |
| **Sneakers on a wire** | Covered in the earlier note | At most one pair, on a Philly-stage wire. | no |
| **Court** | Two-thirds of NYC court surface is grey [Courts of NY](https://naterattner.com/courts-of-new-york/). Handball walls are everywhere [Hunter](https://hunterurbanreview.commons.gc.cuny.edu/new-yorks-home-courts/) | Grey P5 court, **one** coloured key (P10 or P11), off-white lines, chain-link 12–16 tall, a freestanding handball wall 16×20×1 in P4. | Court stage |
| **El (elevated train)** | Columns "at intervals of not less than **20 feet**… along the **curbstone line**". Two-column bents up to **29 ft** high; the West End el averages **12'6"**. It was criticised for "**darkening the streets**". [nycsubway.org ch.13](https://www.nycsubway.org/wiki/Chapter_13._Design_of_Steel_Elevated_Railways), [ch.06](https://www.nycsubway.org/wiki/Chapter_06:_Elevated_Railroads), [Forgotten NY](https://forgotten-ny.com/2017/04/polo-grounds-shuttle-2017/) | Columns P9 1.2×1.2 at x = ±10 (on the curb line), **every 22 studs**. Deck girders P9 at y 24–28 spanning the full road. Ties as P5 slats. Underneath stays in permanent **striped shade**, which is the scene's signature. | El stage |
| **Subway entrance** | Green globe = open, red = exit-only [Untapped](https://www.untappedcities.com/cities-101-the-actual-purpose-of-nyc-subway-globes/) | Stair well 6×12 with P9 railings, 2 posts with Ball Ø1.2 globes in P10 Neon, a sign band P9 with P3 letters. | Station stage |

---

## 6. Ten scenes from hood maps that become ten stages of one hood world

The order follows World 1's existing walls in `Maps.lua` [L]: Moving Boxes, Chain Link Fence, Delivery Truck, Hydrant Spray, Construction Barrier, Scaffolding, Food Cart Line, Block Party, Pigeon Flock, Station Turnstile. Each scene **adds one new thing** to the shared palette and keeps everything earlier, which is the "one new privilege per stage" idea from the earlier note.

| # | Wall [L] | Scene | Where hood games have it [S] | Reads instantly because (3 signatures) [I] | New colour or feature allowed [I] |
|---|---|---|---|---|---|
| 1 | Moving Boxes | **The Block**: residential side street | Every map: Da Hood houses, The Streets "most houses", South Bronx brownstones | Continuous brick walk-ups with fire escapes; a brownstone stoop with moving boxes; a corner deli with a green awning | Base palette only (section 8) |
| 2 | Chain Link Fence | **The Court**: fenced court + handball wall + garden lot | Da Hood basketball court; Bronx and Payhip kits; ClearlyDev court | 14-tall chain-link cage; a backboard silhouette against a buff schoolhouse; a freestanding handball wall | One coloured court key (P10 or P11) and chalk lines |
| 3 | Delivery Truck | **Corner-store Avenue**: a taxpayer row | Tha Bronx 3 Deli and Laundromat; Da Hood Taco/Burger/Furniture strip; Chicago "barbers, large stores" | A 1–2-storey row of 4 shops under one long sign band; a box truck double-parked; a bus shelter | Chicken-spot red/black menu box; laundromat portholes |
| 4 | Hydrant Spray | **Summer Block**: Philly/Brooklyn rowhouses | Hydrant spray block party (earlier note) | Open hydrant with spray cap and puddle; porches with **striped aluminum awnings**; chalk on the sidewalk | Water VFX, plus one awning stripe colour |
| 5 | Construction Barrier | **Gas & Auto**: gas station and tire shop | Da Hood gas station "on the periphery"; The Streets gas station; Tha Bronx 3 gas stations; Chicago "auto shops"; Willets Point | A flat canopy on 4 columns over pumps; roll-up garage doors with tire stacks; chain-link yard with orange drums | Orange/white barrier stripes; canopy fascia band |
| 6 | Scaffolding | **Sidewalk-Shed Street** | NYC's "400 miles of scaffolding" [Gothamist](https://gothamist.com/news/heres-why-nyc-sidewalks-are-still-covered-with-400-miles-of-scaffolding) | A hunter-green plywood tunnel over the sidewalk; wheatpaste posters; pipe scaffold climbing a facade | Shed green as a large area, plus poster colours (still palette) |
| 7 | Food Cart Line | **Under the El** | GTA IV Bohan "el between tenements"; Chicago kits "train tracks", Alley L | Black steel columns at the curb line every 22; striped shadow on the street; stairs up to an el station; food carts with umbrellas | One umbrella colour; train-pass sound and shadow sweep |
| 8 | Block Party | **Block Party**: closed street | Block party (earlier note) | Blue-and-white sawhorse barricades at both ends; a DJ table with a speaker stack; string lights between fire escapes | String-light warm Neon; one bunting colour |
| 9 | Pigeon Flock | **The Projects & Rooftops** | Da Hood Uphill/Projects; Chicago "projects"; GTA IV Northern Gardens | 10–14-storey plain red-brick towers on asphalt with benches; a playground; a **rooftop pigeon coop** with a circling flock | Height. The first skyline view across the city |
| 10 | Station Turnstile | **The Station**: subway mezzanine | South Bronx "subway area… a landmark for navigation" | Green globes at the stair head; white tile walls with a coloured stripe; turnstiles and a token-booth window | Tile and stripe colour; the gold "next world" sign |

Notes [I]:
- **South Bronx: The Trenches already has a "Boxing Facility with tournaments"** [S](https://south-bronx-the-trenches.fandom.com/wiki/Locations), and Da Hood has Hood Fitness. A boxing gym on a hood street is genre-native, not a stretch.
- **Keep one city's vocabulary for World 1.** NYC (Bronx/Brooklyn) fits best, since stoops, water tanks, the el and the subway are all NYC. Stage 4 can borrow Philly porches as "the Brooklyn rowhouse side". Save Chicago alleys and Atlanta low-rise for later worlds if needed.
- **Most buildings are facades.** South Bronx players learn which buildings are "empty shells" [S]. Build the street as a **facade set** about 6–20 studs deep, with roofs. Only the stage's training spot and one shop need interiors.

---

## 7. What to avoid in a kids' simulator, and what to swap in

| Genre staple | Why it's out [S where noted] | Kid-safe swap [I] |
|---|---|---|
| Gun stores ("Tyrone's", "Uphill/Downhill Gunz"), guns, masks, ammo at gas stations | Da Hood's landmarks are mostly gun stores [S](https://da-hood-roblox.fandom.com/wiki/Downhill_Gunz). Violence pushes the maturity label up; "Minimal" allows only "occasional mild violence" [S](https://en.help.roblox.com/hc/en-us/articles/8862768451604-Content-Maturity-Labels) | Sporting goods / "BOXING SUPPLY", sneaker shop, gym |
| Gangs, turf, "trenches", crew colours, hand signs | Roblox prohibits "organized criminal activity, **gangs and gang violence**" [S](https://devforum.roblox.com/t/are-gang-related-aspects-allowed-in-games/394215), [Community Standards PDF](https://devforum-uploads.s3.dualstack.us-east-2.amazonaws.com/uploads/original/5X/b/6/6/4/b66495abfec47da8fa56359b21ec1b4207fc313e.pdf) | "The Block", "Crew" means friends or party. Avoid red-vs-blue team palettes on the street |
| Trap houses, drug props, "hot chips" economies, swiping, laundering | Depicting drugs or paraphernalia is prohibited (search summary of Roblox policy pages) [S](https://ag.ny.gov/sites/default/files/social-media-policy-report/2025-q3-roblox-corporation-policy.pdf). The Chicago kits ship with drug crates and guns [S](https://aris-oww.itch.io/roblox-chicago-roleplay-map) | Never import paid hood kits wholesale. Use only facades, or strip every interior |
| Liquor store, "cold beer" awnings, bottles | Alcohol makes an experience 17+ (earlier note) | "DELI • GROCERY • 24/7", juice and ice-cream signs |
| Cigarettes, vape shop signs | Tobacco and vaping depiction prohibited [S](https://ag.ny.gov/sites/default/files/social-media-policy-report/2025-q3-roblox-corporation-policy.pdf) | Phone repair shop, "99¢ & UP" |
| Lotto and "scratch-off" signs, casino | Gambling content appears in the maturity criteria [S](https://en.help.roblox.com/hc/en-us/articles/8862768451604-Content-Maturity-Labels). South Bronx has a casino [S] | Arcade (claw-machine window) |
| Real brands | Da Hood's gas station "exclusively sells… **Starbucks** coffee" [S](https://da-hood-roblox.fandom.com/wiki/Gas_Station). Tha Bronx 3's car list is all real makes [S]. Bodega "privilege signs" carry soda logos [S]. Mister Softee trade dress (earlier note) | Invented names ("SUNNY DELI", "FRESH CUTS"), generic boxy car bodies, an in-game poster in every ad slot |
| Police tape, chalk outlines, bullet holes, blood decals | Hood kits advertise "blood decals" [S](https://builtbybit.com/tags/hood/) | Kids' chalk drawings, hopscotch |
| Boarded or burned buildings, rubble lots | They tie to the 1970s Bronx fires [S](http://theprotocity.com/casitas-in-the-south-bronx/), and read "decrepit", which mixes badly with "kept" [S](https://devforum.roblox.com/t/hood-style-game-map/2938255) | Lot becomes a **community garden** with raised beds and a casita |
| Homeless tents and NPCs | South Bronx sells to "Homeless NPCs" [S](https://south-bronx-the-trenches.fandom.com/wiki/Earning_money); the DevForum called a tent "out of place" [S] | Don't depict. Use a bench with a pigeon instead |
| Police stations, prisons, "feds" chases | Core to the genre's RP | Firehouse (red doors give a natural accent) |
| Pawn and check-cashing | Fine in reality, but they signal "poverty economy" | "CELL REPAIR", "99¢ & UP", laundromat |

---

## 8. Stage 1 build spec: one 48-stud hood block ("The Block", wall: Moving Boxes)

All values are **[I]** unless tagged. Parts only, **Plastic**. Studs only render on Plastic [S](https://roblox.fandom.com/wiki/Studs_(surface)). New parts don't get them by default, so set `TopSurface = Studs` / `BottomSurface = Inlet` from script; the TheBlockV2 builder already has a `studs(p)` helper [L].

**Studs go on upward faces only** (road, sidewalk, roofs, stoop treads, ledges). Vertical faces stay Smooth, which is the classic look.

### 8.1 Palette: 12 colours plus 1 spot

| ID | Role | RGB | Hex | Nearest BrickColor | Area share |
|---|---|---|---|---|---|
| P1 | Asphalt | 66, 68, 72 | #424448 | between Dark stone grey and Black | 60% neutrals |
| P2 | Faded road yellow | 204, 170, 72 | #CCAA48 | custom (muted) | ″ |
| P3 | Off-white: crosswalk, sills, lintels, cornices, ACs, curb, shades | 229, 228, 223 | #E5E4DF | **Light stone grey** (exact) | ″ |
| P4 | Concrete: sidewalk, lamp poles, chain-link, gate, stoop steps on red | 163, 162, 165 | #A3A2A5 | **Medium stone grey** (exact) [S](https://devforum.roblox.com/t/roblox-brick-color-codes/1185382) | ″ |
| P5 | Dark concrete: roofs, joints, gate slats, tank roof, lot ground, SUV | 99, 95, 98 | #635F62 | **Dark stone grey** (exact) [S](https://devforum.roblox.com/t/roblox-brick-color-codes/1185382) | ″ |
| P6 | Red brick | 148, 70, 54 | #944636 | between Rust (143,76,42) and Dusty Rose (163,75,75) [S](https://robloxden.com/color-codes) | 30% masonry/ink |
| P7 | Brown brick / brownstone / wood (tank, doors, trunk, buff trim, boxes' tape) | 105, 64, 40 | #694028 | **Reddish brown** (exact) [S](https://devforum.roblox.com/t/roblox-brick-color-codes/1185382) | ″ |
| P8 | Buff (Bronx yellow) brick, plus cardboard moving boxes | 194, 160, 112 | #C2A070 | custom (between Brick yellow 215,197,154 and Fawn brown 160,132,79) | ″ |
| P9 | Ink: iron, glass, tires, trash bags, brownstone cornice | 38, 40, 46 | #26282E | custom (Black 27,42,53 minus the blue) | ″ |
| P10 | Deli green: awning, litter basket, tree, hydrant caps, green lens | 40, 127, 71 | #287F47 | **Dark green** (exact) | 10% accents |
| P11 | Signal red: hydrant, barber stripes, brownstone door, one car, red lens, tail-lights | 170, 44, 38 | #AA2C26 | custom (muted Bright red 196,40,28) | ″ |
| P12 | Warm light: lit windows, OPEN sign, lamp lens, transom, amber lens, headlights | 240, 196, 96 | #F0C460 | custom | ″ |
| spot | Mailbox navy (one object) | 34, 56, 104 | #223868 | ≈ Navy blue | <1% |

**Material:** Plastic everywhere. Neon only on the OPEN sign (P12) and, at night, the lamp lenses. Transparency 0.55 only on chain-link mesh.

### 8.2 Frame, ground and markings
- **Stage-local frame.**
  - It matches TheBlockV2's street [L]: x = 0 is the road centre, the block runs from z = 0 (gate side) to z = −48, and y = 0 is the road top.
  - The left side is x < 0 and its facades face +x. The right side is x > 0 and faces −x.
  - **Facade line at x = ±20.**
- **Road.** P1, size (20, 1, 48), centre (0, −0.5, −24), top Studs.
- **Curbs.** P3, size (0.6, 1.8, 48), centres (±10.3, −0.1, −24). Top at y = 0.8, so the curb shows as a light line against the dark road.
- **Sidewalks.** P4, size (9.4, 1.8, 48), centres (±15.3, −0.1, −24). Top y = 0.8, studs on top.
  - **Joints:** P5 strips 0.15 × 0.02 × 9.4, lying 0.01 proud, every 5 studs along z (z = −5, −10 … −45), 9 per side.
  - Add one longitudinal joint at x = ±15.3.
- **Centre line.** P2 dashes (0.5, 0.04, 4) at x = 0 and z = −10, −18, −26, −34, −42. A side street gets dashes, not double solid.
- **Crosswalk.** At the gate end: 6 P3 bars (1.4, 0.04, 4) centred at z = −2.5, x = ±1.6, ±4.8, ±8.0.
- **Patch.** One P5 rectangle (6, 0.03, 4) at (−4, 0.015, −31): an old asphalt patch, which is the honest wear.
- **Manhole.** P5 cylinder Ø2.4 × 0.06 at (3, 0.03, −20).
- **Storm drains.** P9 (0.6, 0.05, 2) at (±9.6, 0.03, −14) and (±9.6, 0.03, −38).

### 8.3 Buildings
Shared rules:
- **Floors.** Ground floors run y 0.8 → 12.8; upper floors are 10 each.
- **Windows.**
  - Upper windows are **3 wide × 5 tall**, with the sill at floor + 3.
  - Glass: P9, 0.2 thick, front face 0.1 proud of the wall.
  - Sill: trim colour, (3.6 × 0.4), protruding 0.6.
  - Lintel: trim colour, (3.6 × 0.6), protruding 0.3, at window top.
- **Hero facades (L1, R1): deep reveals.** Build these from piers and spandrel strips, and set the glass back 0.6 instead of proud.
- **Walls.** Each building is one box from its facade line to x = ±40 (20 deep) and from y 0.8 to the roof, plus a parapet 2 high × 1 thick with a P3 cap (0.4 thick, 0.3 proud). Roofs are P5 with studs.
- **Lit windows (P12).** L1 floor 3 bay −9; R1 floor 4 bay −7.5; R1 floor 6 bay −17.5; L2 parlor bay −21; L3 floor 5 bay −41; R3 floor 3 bay −45. All other glass is P9.
- **Half shades.** A P3 panel (3 × 1.7) over the top of the glass on about 1 in 4 of the other windows. Vary the heights.

**Left side (facades at x = −20, facing +x)**

**L1. Corner deli walk-up.**
- **Massing.** z 0 → −18, 4 storeys. Wall **P6**, trim **P3**. Roof at y 42.8; cornice P3 at y 41.6–43.4, protruding 1.3, with 5 wedge brackets (0.8 × 1.2) beneath.
- **Upper windows.** Floors 2–4 at bays z −4, −9, −14.
- **Corner side wall** (plane z = 0, facing +z, x −20 → −40). It faces the gate. Two bays per floor at x −27 and −34.
- **Storefront.** z −0.5 → −12.5, wrapping 8 studs around the corner along x −20 → −28 on the z = 0 face.
  - Kneewall P7 y 0.8–2.0.
  - Glass P9 y 2.0–9.0, with P3 mullions every 4.
  - Glass door z −9.5 → −12.5, with a P3 frame.
- **Gate box.** P5 (0.9 × 0.9 × 12) at y 9.0–9.9, the rolled-up gate.
- **Sign band.** P10, y 9.9–11.9, with P3 lettering "SUNNY DELI • GROCERY" (SurfaceGui, or skip the text).
- **Awning.** P10 wedge, 12 long × 3.5 deep, high edge y 10.0 at the facade, low edge y 8.4 at x −16.5. P10 valance 0.8 tall, with a 0.2 P3 stripe along its bottom. Repeat as a short wedge along the z = 0 face.
- **Window dressing.** "OPEN" plate, P12 Neon (2 × 0.8 × 0.1), in the glass at z −3, y 6. Behind the glass, 2 shelf rows of small boxes (0.8 cubes) in P3/P8/P11 only.
- **Outside the shop.**
  - 2 milk crates P11 (1.6 cubes) stacked under the corner window at (−18.8, 0.8, −1.8), with a brown **bodega cat** (P7 Ball body Ø1.0, wedge ears) on top.
  - An A-frame board P9 (1.6 × 2.6) at (−17.5, 0.8, −7) reading "CHOPPED CHEESE" in P3. Tha Bronx 3's deli sells chopped cheese [S](https://thabronx3.com/locations/tha-bronx-3-locations-guide/).
- **Residential entry.** z −13.5 → −17: door P7 (3.2 × 7.2), P3 frame 0.4, P12 transom (3.2 × 1.0), one P4 step (4 × 0.4 × 1).
- **Facade clutter.**
  - AC units at floor 3 bay −14 and floor 4 bay −4. Each: P3 box (2.4 × 1.6 × 1.8) on the sill, protruding 1.2, with a P5 grille strip and 2 P9 brackets.
  - Satellite dish on the wall at floor 4 near z −16.8.

**L2. Brownstone with stoop (the moving-day house).**
- **Massing.** z −18 → −34, **facade set back to x = −23**. Wall **P7**, trim **P7** (projection does the work), cornice **P9**.
- **Areaway.** Floor P4 at y 0.8. An iron fence P9 along x = −20 from z −18.5 → −29 and −33 → −33.8: top rail 0.25 at y 3.8, pickets 0.2 × 3 every 1.0.
- **Basement.** Windows (3 × 2.4) at y 1.6–4.0, bays z −21 and −26, with P9 bars.
- **Stoop** at z −29 → −33 (bay −31), all P7.
  - Landing (1.5 deep) at y 6.8 against the facade.
  - Treads 1.0 deep, tops at y 5.6 / 4.4 / 3.2 / 2.0, stepping out to x −17.5.
  - Cheek walls are wedges.
  - Railings P9: 2 rails and 4 balusters per side, plus a Ball newel Ø0.7 at the bottom.
- **Parlor floor** (y 6.8–17.8).
  - Door at bay −31: **P11 oxblood** (3.2 × 7), P12 transom, and a P7 hood (4.4 × 0.8, protruding 0.8) on 2 brackets.
  - Tall windows (3 × 7, y 8.6–15.6) at bays −21 and −26.
- **Upper floors.** Floors at y 17.8 and 27.8, with 3 windows (3 × 5.5) at bays −21, −26, −31. Each gets a P7 hood protruding 0.6.
- **Cornice.** P9, y 37.8–39.8, protruding 1.4, with 4 P9 brackets (0.8 × 1.6 × 1.2) at z −18.8, −23.3, −28.7, −33.2.
- **Pigeons.** 4 on the cornice: P4 Ball body Ø0.7, P5 head Ø0.4.
- **Moving-day props** (ties to the "Moving Boxes" gate).
  - 5 boxes P8 with P7 tape strips: 2.0/1.6/1.4 cubes, stacked on the landing and bottom tread.
  - One hand truck P9 at (−16.8, 0.8, −34).
- **Tree pit** at (−14.5, 0.8, −24).
  - Pit P5 (4 × 0.05 × 4).
  - Trunk P7 Ø0.8 × 7.
  - Canopy: 3 P10 Balls (Ø5 / 4.5 / 4) at y 8.5–11.
  - This is **the only greenery on the street**.

**L3. Red walk-up with fire escape and water tank.**
- **Massing.** z −34 → −48, 5 storeys. Wall **P6**, trim **P3**, cornice **P5** (pressed-metal look). Roof at y 52.8; cornice y 51.4–53.4, protruding 1.2.
- **Upper windows.** 3 bays at **4.2 pitch** (z −36.8, −41, −45.2), windows 2.8 × 5, floors 2–5.
- **Ground floor, residential.**
  - Door P9 (3 × 7) at bay −41, with a P3 frame and 2 P4 steps.
  - Windows (2.8 × 5, y 3–8) at bays −36.8 and −45.2, with **P9 bars** (3 vertical, 1 horizontal).
- **Fire escape** across all 3 bays (z −35.2 → −46.8, 11.6 long).
  - Decks P9 (3.6 deep × 0.3) at y 15.2, 25.2, 35.2 and 45.2.
  - Railings: top rail at deck + 3, plus 4 posts.
  - Zig-zag stairs between decks: 2 stringers 0.25, 6 treads (1.4 × 0.15 × 0.5), alternating ends.
  - Drop ladder: 2 rails 1.4 apart plus 6 rungs, hanging from y 15.2 to y 8.0.
- **ACs** at floor 2 bay −36.8 and floor 4 bay −45.2.
- **Water tank** (roof centre x −30, z −41).
  - 4 P9 legs (0.6 × 4 × 0.6) on a 7 × 7 square, with X-braces 0.25.
  - P7 plank deck (8 × 0.4 × 8).
  - Tank: P7 cylinder **Ø8 × 8** at y 57.2–65.2, with 3 P9 hoops (Ø8.1 × 0.3).
  - Conical roof: 3 stacked P5 cylinders Ø8.4 / 5.6 / 2.8 × 0.8, plus a P9 finial Ball Ø0.8. Top ≈ y 68.
  - 1 P9 gooseneck ladder up the parapet.

**Right side (facades at x = +20, facing −x)**

**R1. Six-storey buff walk-up with barbershop.**
- **Massing.** z 0 → −20, 6 storeys. Wall **P8**, trim **P7** (the sourced Bronx buff-with-brown look), cornice **P7** at y 61.6–63.6, protruding 1.2. Roof at y 62.8.
- **Upper windows.** Floors 2–6 at bays z −2.5, −7.5, −12.5, −17.5. Use deep reveals.
- **Barbershop** at z −1 → −11.
  - Glass P9 y 2.0–9.0.
  - Gate box P5.
  - Sign band **P9** y 9.9–11.9, with P3 lettering "FRESH CUTS".
  - **Pole** at (20.6, 4–8, −11.6): P3 cylinder Ø0.8 × 4 with 4 tilted P11 rings (Ø0.85 × 0.3, 20°) and P4 Ball caps. It's the block's red accent, and it can spin client-side.
- **Residential door** at z −13 → −17: P7 door, P3 frame, one step.
- **Fire escape** over bays −12.5 and −17.5 (z −10.4 → −19.6). Decks at y 15.2, 25.2, 35.2, 45.2, 55.2; drop ladder to 8.0.
- **ACs** at floor 3 bay −2.5 and floor 5 bay −7.5.
- **Roof.**
  - Stair bulkhead P8 (6 × 5 × 7) at x 30, z −15, with a P9 door.
  - Satellite dish (P3 Ø2 × 0.3, tilted 30°, on a P9 arm) at x 22, z −4.
- **Side wall over the lot** (plane z = −20, facing −z, x 20 → 40). This is **the block's one mural.**
  - P3 base panel (14 × 10) at y 14–24, protruding 0.05.
  - A P11 sun disc (Ø5, flat cylinder) and a P10 band (14 × 1.6).
  - Bubble text "THE BLOCK" in P9 with a P3 stroke.
  - It reads like an old painted wall sign, not a candy mural.

**R2. Vacant lot turned garden.** z −20 → −32; it's also the stage's training spot.
- **Ground.** P5 box from x 20 → 40 with top at y 0.6 (0.2 below the sidewalk), studs on top.
- **Fence** along x = 20.2.
  - P4 posts Ø0.4 × 9 at z −20.5, −24, −28, −31.5.
  - Top rail P4 Ø0.25.
  - Mesh panels P4 at Transparency 0.55.
  - **Gate opening z −24 → −28** (the bag spot entrance).
  - A P3 sign (3 × 1.5) "NO DUMPING" with P11 text on the fence at y 5.
- **Inside.**
  - 2 raised beds P7 (4 × 1 × 2) along x 34–38, each with 3 P10 plant Balls Ø1.2.
  - A dumpster (P5 6 × 3.5 × 4 with a P9 lid) at (36, 0.6, −30).
  - The stage's training bag stands mid-lot.
- **R3's side wall** (plane z = −32, facing +z): a **ghost outline** of a demolished rowhouse. P5 strips 0.4 wide, 0.05 proud, tracing a 12-wide, 22-tall house with a stepped roofline.

**R3. Brown 3-storey with closed shop.**
- **Massing.** z −32 → −48. Wall **P7**, trim **P3**, cornice P3 at y 31.4–33.2, protruding 1.0, with 4 wedge brackets. Roof at y 32.8.
- **Upper windows.** Floors 2–3 at bays z −35, −40, −45.
- **Shop, gate down** (z −33 → −43).
  - Gate P4 (9.6 × 8) at y 0.8–8.8, with 8 P5 slat strips (9.6 × 0.12 × 0.1) every 1 stud.
  - Gate box P5 (10.4 × 1 × 1) at y 8.8–9.8.
  - Sign band P3 y 9.8–11.8, with P9 lettering "99¢ & UP".
  - **The block's one tag**: 4 P9 strokes (0.3 wide, rotated) at y 2.5–6, covering 3 × 2.
  - 3 wheatpaste posters (P3, 2 × 3, rotated ±4°) on the pier at z −43.5.
- **Residential door** at z −44 → −47.6: P9 door, P3 frame, and **2 P3 "marble" steps** (4 × 0.6 × 1). This is the Baltimore nod: "cared for".
- **ACs** at floor 2 bay −40 (plus floor 3 bay −35).
- **Roof** satellite dish at x 22, z −46.

**Skyline check** (it should read as stepped, not flat):
- Left: 44 / 40 / 55 + tank to 68.
- Right: 64 / gap / 35.

### 8.4 Street props with positions (stage-local)

| Prop | Position (x, y base, z) | Spec |
|---|---|---|
| Lamp 1 | (−11.2, 0.8, −10), arm toward +x | §5 recipe, 18 tall |
| Lamp 2 | (11.2, 0.8, −26), arm toward −x | ″ |
| Lamp 3 | (−11.2, 0.8, −40), arm toward +x | ″ |
| Traffic signal | (11.2, 0.8, −1), arm to x 0 at y 16; head hanging at x 4 | §5 |
| Hydrant | (11.6, 0.8, −22.5) (in front of the lot) | P11 body, P10 caps (sourced green cap = 1,000–1,499 GPM) |
| Litter basket | (−11.4, 0.8, −2.5) (deli corner) | P10, P9 rim |
| Mailbox (spot navy) | (−11.6, 0.8, −6) | §5 |
| Trash bags + can | (−11.8, 0.8, −15) to (−11.8, 0.8, −17) (in front of L1's door) | 3 P9 Balls, 1 P4 can with a P5 lid |
| Car A: boxy sedan, white | centre (−7.4, 0, −21), along z | P3 body (§8.6) |
| Car B: boxy SUV, grey | centre (−7.4, 0, −42.5) | P5 body |
| Car C: boxy sedan, black | centre (7.4, 0, −13) | P9 body, P4 bumpers |
| Car D: boxy sedan, oxblood | centre (7.4, 0, −40) | P11 body. **The one coloured car** |
| Tree | (−14.5, 0.8, −24) | L2 recipe |
| Moving boxes + hand truck | L2 stoop / (−16.8, 0.8, −34) | P8, P7, P9 |
| Milk crates + cat | (−18.8, 0.8, −1.8) | P11, P7 |
| A-frame board | (−17.5, 0.8, −7) | P9, P3 |
| Pigeons (4) | L2 cornice, y 39.8 | P4, P5 |

Keep clear [I]:
- the sidewalk walkway, at least 6 wide on each side
- the lot gate (z −24 → −28)
- the travel lane (x −5 → 5) for the gate and any runners

### 8.5 Fire escape, AC and tank counts at a glance
- **Fire escapes:** 2 (L3 and R1). That's 2 of 5 buildings, close to "1 in 3".
- **Water tanks:** 1 (L3). R1's bulkhead and dish balance it on the right.
- **ACs:** 8 across the block. Satellite dishes: 3.
- **Accents in view from the gate:**
  - green: awning, basket, tree, hydrant caps, signal lens
  - red: hydrant, barber pole, brownstone door, Car D, crates
  - warm: 6 lit windows, OPEN sign, transoms

  That's roughly 10% of the visible area. Count it on a phone-size screenshot.

### 8.6 Car recipe (boxy, generic)

**Sedan (10 long), about 20 parts:**

| Part | Size | Position / colour |
|---|---|---|
| Wheels ×4 | Cylinder Ø1.8 × 0.7 | P9; centres y 0.9, z ±3.3, x ±2.0 |
| Hubcaps | Ø1.0 × 0.05 | P4 |
| Lower body | 4.4 × 1.8 × 10 | y 0.9–2.7, body colour |
| Cabin | 4.0 × 1.5 × 5.2 | y 2.7–4.2, offset 0.6 rearward |
| Windshield and rear glass | 0.2-thick P9 wedges, angled 30° | — |
| Side glass | P9 panels (0.05 proud) | — |
| Bumpers | 4.6 × 0.6 × 0.4 | P4 |
| Headlights | 0.9 × 0.4 | P12 |
| Tail-lights | 0.9 × 0.4 | P11 |

**SUV:** body 4.6 × 2.6 × 11, cabin 4.4 × 1.8 × 7, wheels Ø2.0.

### 8.7 Budget and settings
- **About 850 Parts:**
  - ground and markings: about 60
  - buildings: about 420, including about 130 for the 2 fire escapes
  - lot: about 40
  - props: about 110
  - cars: about 85
  - lamps and signal: about 30
- **Settings.** All Anchored. Small props get `CanCollide = false`, `CanTouch = false`, `CanQuery = false` and `CastShadow = false` (window glass, sills, slats, joints, posters, pigeons).
- **Hidden faces.** Facades only need to be 20 deep, and backs can stay hidden. Wrap each building in a Model named for its role (`L1_Deli`, `R2_Lot`…) so later stages can clone and recolour within the palette.

### 8.8 Read test before calling it done [I]
1. **Gate view (camera at 15 studs).** You should see brick canyon walls, the green deli awning on the left corner, the red barber pole on the right, the water tank and fire escapes against the sky, and the lot gap. It should look like a street, not a toy shop.
2. **Palette audit.** Any RGB not in 8.1 is a bug, except the gate and UI.
3. **Wear audit.** Tags stay below y 8. There's exactly one tag, one mural, one closed gate and one bag cluster. No cracks, no boarded windows.
4. **Phone screenshot at 50% size.** It should still read "city block, deli, brick". If it reads "brown blur", raise the off-white trim contrast (sills, cornices, curb) before adding any colour.
5. **Kid check.** No guns, gangs, alcohol, lotto, tobacco, real brands or police tape anywhere, including signs and posters (section 7).

---

### Gaps
- No page bodies or screenshots could be read. The game-specific visual claims are limited to what search summaries said. Anything about how Da Hood or Tha Bronx 3 *look* (materials, colours, lighting) is marked **[I, unverified]**. Confirm it against screenshots.
- Real-world dimensions come from summaries of codes and articles, not the codes themselves. The sidewalk-width figures were mixed across several pages.
- Every RGB except the exact BrickColor matches is my proposal. I didn't build the block in Studio or test the lighting preset.
- I found nothing describing Creator Store hood/city map kits beyond one single building. The Creator Store couldn't be fetched.
