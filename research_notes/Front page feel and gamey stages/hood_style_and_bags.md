# Hood style guide: a bright "hood" that reads instantly, an "out of the hood" progression, and a 9-tier bag ladder (2026-10-03)

> **How these notes were gathered (read first).**
> - **Sources.** Every web claim comes from **WebSearch result summaries**, marked **[S]**. WebFetch was blocked by the egress proxy on every domain I tried: cartoonbrew, gamesradar, brooklynpaper, pocketgamer, slashfilm, artstation, syntystore, stevelowtwait.com and phillystreetz2.wiki. So I never read the full pages. Treat [S] claims as paraphrases of the linked page.
> - **Local code.** Hood's current state comes from reading `/home/user/ROBLOX/hood/src`, marked **[L]**.
> - **Inferences.** My own design inferences, recommendations, hex palettes and part recipes are marked **[I]**.
> - **No screenshots.** I had no image access, so nothing here was measured from a picture.
> - **Prior notes this builds on.** Their palettes, lighting presets and the first-pass tier ladder are not repeated here:
>   - `research_notes/Tiered props VFX and vibrant maps/vibrant_maps.md`: palettes P1–P5, lighting presets H1/H2, prop density rules
>   - `research_notes/Tiered props VFX and vibrant maps/prop_modeling_and_tiers.md`: rarity ladders, bag hardware, ring specs
>   - `research_notes/Cartoony Roblox building UI and animation/building_stylized_techniques.md`: rowhouse kit, chamfers, prop scale ×1.3–2

---

## 0. TL;DR

1. **A hood is read from five things, in this order [I]:**
   - **Skyline silhouette:** water towers, cornices, zig-zag fire escapes.
   - **Ground-floor rhythm:** stoops, plus storefronts with awnings and neon.
   - **Painted walls:** murals and tags.
   - **Street play:** the court, hydrant spray, block party.
   - **Sound:** boombox, ice-cream jingle.

   Hood already has many of these props in TheBlockV2 [L]. The bigger gap is that **the terraced brick-and-grass "canyon" massing hides the city-block silhouette**, and the props are life-size instead of hero-size.
2. **Hood can be saturated and warm.** *Do the Right Thing* limited its palette to the hot end of the spectrum and painted walls red and orange "theatrically" [S]. Spider-Verse gave Miles's neighborhood "warm values" so he feels at home [S]. Earth-42 is the counter-example: noir green/purple and heavy ink, with color fading into shadow [S]. That is the "rough" look to avoid in World 1.
3. **Swap grit for "lived-in" [I].** Keep patches, tape, stickers, chalk and crates. Drop cracks, boarded windows, crime tape, trash piles, guns and gang colors.
   - Avoid alcohol signage too. Roblox requires alcohol references to be disclosed, and experiences that depict alcohol are 17+ only [S]. So the classic bodega "cold cuts & cold beer" awning becomes "DELI • GROCERY • 24/7".
4. **Show "out of the hood" with several channels at once [I, from S patterns]:**
   - building height and altitude
   - density (lower)
   - cleaner ground
   - greenery
   - materials: brick and chain-link → siding and pickets → glass and limestone → stucco and gold
   - signage: hand-painted and neon → yard signs → LED billboards → monogram gates
   - gold share: 0 → 2 → 5 → 15%

   Each world keeps one hero hue, which `Maps.lua` already has [L]. Show the goal from the start: put an Uptown skyline and a "THE HILLS" hillside sign on the horizon, the way the Vinewood Sign does in GTA [S].
5. **Bags: give each tier one new "visual privilege" on top of all earlier ones.** This is Sunstrike's merge-art rule: "more crystals, then a base, then gold, then a frame — never two at once" [S]. Pair that with **a distinct silhouette per tier** and a **story ladder: street junk → gym classic → pro → gold → arena**.
   - The current HoodProps ladder [L] has good channels but **near-identical silhouettes**. Tiers 2–4, 7 and 8 all use the same cylinder bag on an L-gallows (tier 1 shares the gallows), with body heights of only 4.4–6.0 studs.
   - It also has **two conflicting color systems**: `Skins.Stations.Color` and `Props.Rarity`.

---

## 1. The visual vocabulary of a bright, instantly readable hood

### 1.1 What the references say (sourced)

**Roblox hood games: the setting players already expect** (borrow the setting, not the content)
- **Da Hood [S].** Districts are named Uphill and Downhill, with a Bank downtown between a Jewelry Store and a Furniture Store. The "Uphill/Projects" area has the School, Hospital, Projects housing and a **Basketball Court**, plus "raised terrain that creates ledges". Most other landmarks are gun stores. — [pocketgamer Da Hood map](https://www.pocketgamer.com/roblox/da-hood-map/); [dahoodwiki beginner guide](https://dahoodwiki.wiki/en/guides/beginner-guide/); [Downhill Gunz (fandom)](https://da-hood-roblox.fandom.com/wiki/Downhill_Gunz)
- **South Bronx: The Trenches / Bronx Streetz [S].** Summaries describe "brownstone buildings and stoops, graffiti art that reflects real Bronx murals…, basketball courts and parks, and subway stations and trains". The tone is "run-down buildings, graffiti-laden walls". — [rolimons South Bronx](https://www.rolimons.com/game/10179538382); [Bronx Streetz](https://www.roblox.com/games/16995353837/Bronx-Streetz)
- **Tha Bronx 3 [S].** The "Bronx Deli" sells **Chopped Cheese** and is a **safe zone**. Other spots are a car dealership, bank and gas stations. — [Tha Bronx 3 Locations (fandom)](https://tha-bronx-3.fandom.com/wiki/Locations); [thabronx3 locations guide](https://thabronx3.com/locations/tha-bronx-3-locations-guide/)
- **Philly Streetz 2 [S]:** a "dense, Philadelphia-inspired city" with vendors and loot interiors. — [phillystreetz2.wiki map](https://phillystreetz2.wiki/map/)
- **Hood Customs [S]:** "Fighting" genre with 1v1/2v2/FFA/Anarchy modes and gun skins. Players spawn with guns and a mask. — [Hood Customs](https://www.roblox.com/games/9825515356/Hood-Customs); [hoodcustoms.wiki](https://hoodcustoms.wiki/guides/)
- **Takeaway [I].** The genre's shared shorthand is **brownstones + stoops + graffiti/murals + court + subway + corner deli + money/bank**. The genre is built around guns, gangs and crime, so Hood's cheerful version is a **differentiation bet**. Keep the deli, court, stoops and subway. Drop the guns, masks, gang turf and "trenches" framing.

**Cartoons and films: how to make a city warm and whimsical**
- **Hey Arnold!'s Hillwood [S]:**
  - The city is an amalgam of Seattle, Portland and **Brooklyn (the bridge, the brownstones, the subway)**, with "brownstones, stoops, boarding houses".
  - Creator Craig Bartlett photographed old buildings and compiled "Hey Arnold's Little Book of Grunge" as the artists' reference.
  - Backgrounds were "painted with acrylics and textured on top with colored pencils". The look is summarized as "gritty but whimsical".
  - Sources: [Hillwood (Paramount fandom)](https://paramount.fandom.com/wiki/Hillwood_(Hey_Arnold!)); [Brooklyn Paper, Hey Arnold at 30](https://www.brooklynpaper.com/hey-arnold-brooklyn-30-years/); [pdxmonthly](https://www.pdxmonthly.com/arts-and-culture/2021/07/looking-for-portland-in-hey-arnold); [Steve Lowtwait backgrounds](http://stevelowtwait.com/hey-arnold-backgrounds)
- **Into the Spider-Verse [S]:** "Everything from Miles' room, kitchen and front porch to the neighborhood has **warm values** that represent him feeling comfortable and in his element". Production designer Justin K. Thompson used "vibrant and eclectic colors". — [Cartoon Brew](https://www.cartoonbrew.com/feature-film/spider-man-into-the-spider-verse-production-design-is-about-character-not-style-168137.html); [shapes.inc art-style summary](https://shapes.inc/fandom/spider-man-into-the-spider-verse/art-style)
- **Across the Spider-Verse bodega [S]:**
  - Production designer Patrick O'Keefe's team visited real Brooklyn bodegas.
  - They filled the set with "**layers upon layers of art, from floor to ceiling, shelves to display cases**".
  - Details include parody magazines ("Vague", "Rocking Stone"), a Jamaican menu (curry goat, ackee and saltfish, roti), and "a cute little **bodega cat** hanging out on top of a freezer".
  - Source: [GamesRadar](https://www.gamesradar.com/spider-man-across-the-spider-verse-production-design-details-bodega/)
- **Earth-42 (the "rough" counter-example) [S]:** "neon-noir green and purple", "colors fade into deep shadows and a heavy, gritty inking style dominates, erasing light". — [maxblizz (VFX supervisor Michael Lasker)](https://maxblizz.com/spider-man-across-the-spider-verse-vfx-supervisor-reveals-the-gritty-dark-and-sinister-visual-style-of-earth-42/); [Michigan Daily](https://www.michigandaily.com/arts/see-it-to-believe-it-spider-man-across-the-spider-verse-and-visual-storytelling/)
- **Marvel's Spider-Man: Miles Morales (Harlem) [S].** Murals celebrate African American and Latino culture. Bodegas "aren't organized — everything is there but only workers or regulars know where things are". Holiday lights and snow give the area its identity. — [Newsweek interview](https://www.newsweek.com/spiderman-miles-morales-insomniac-games-interview-culture-harlem-1547296); [Checkpoint review](https://checkpointgaming.net/reviews/2020/11/marvels-spider-man-miles-morales-review-whats-up-danger/)
- **Do the Right Thing (Bed-Stuy) [S]:**
  - "The color palette was limited to the **hotter end of the spectrum**."
  - "Some of the buildings were … painted shades of **red and orange** to add to the sense of heat."
  - The red wall behind the Corner Men was "a **blatantly theatrical choice to sneak color into the picture**".
  - The block was chosen with no trees, so there's no shade.
  - Sources: [Mental Floss](https://www.mentalfloss.com/entertainment/movies/little-known-story-behind-do-right-thing); [Moviejawn on Wynn Thomas](https://www.moviejawn.com/home/2021/3/10/split-decision-wynn-thomas); [NYC in Film](https://nycinfilm.com/2023/04/16/do-the-right-thing-1989/)
- **Sesame Street [S]:**
  - The core set pieces are the **stoop at 123**, Oscar's **trash can**, the **street sign** and Hooper's Store.
  - The original set was "a realistic city street, complete with peeling paint, alleys, front stoops, and metal trash cans".
  - Later versions were "**repainted in brighter colors**… everything seemed **cleaner**", with a bike shop and a **rooftop garden**. That doubles as a progression reference (section 2).
  - Sources: [Wikipedia, Sesame Street (location)](https://en.wikipedia.org/wiki/Sesame_Street_(fictional_location)); [Current.org](https://current.org/2019/08/after-50-years-on-tv-has-sesame-street-been-gentrified/); [Architect's Newspaper on the 2015 makeover](https://www.archpaper.com/2015/04/after-45-years-sesame-streets-iconic-set-gets-a-streetscape-makeover-by-visual-storyteller-david-gallo/)
- **LEGO Ideas 21324 "123 Sesame Street" (the toy-city reference) [S].** The brownstone keeps the door and windows "spot on". It has a **fire escape** on the side, a small garden, and **sticker ads** for a construction company. The two buildings "feature **complementary colours**". — [Brickset](https://brickset.com/article/54013/review-21324-123-sesame-street); [Brothers Brick](https://www.brothers-brick.com/2020/10/22/come-and-play-lego-ideas-123-sesame-street-21324-review/); [Bricktastic](https://bricktasticblog.com/blog/21324-123-sesame-street-review/)
- **Fat Albert's junkyard (DIY look) [S].** The Junkyard Band plays instruments built from junk: trash-can drums, a pipe trombone, a can xylophone, and a bedspring harp. The gang meets in a North Philadelphia junkyard. — [Junkyard Band (fandom)](https://fatalbert.fandom.com/wiki/Junkyard_Band); [Wikipedia](https://en.wikipedia.org/wiki/Fat_Albert_and_the_Cosby_Kids)
- **The Fresh Prince of Bel-Air opening [S].** It's "full of **vibrant colours, intricate graffiti, sped-up cartoonish motion**" and moves from a West Philadelphia basketball scene to a Bel-Air mansion. — [Art of the Title](https://www.artofthetitle.com/title/the-fresh-prince-of-bel-air/)
- **90s "Memphis Lite" graphics [S]:**
  - "Pink, yellow, and blue are the most common colors", with "purple and teal" added in the late 80s and early 90s.
  - Typical shapes: circles, triangles, and "zig-zagged and squiggly lines (usually black)".
  - This is the cheerful graphic language of 90s hip-hop-era TV.
  - Sources: [Memphis Lite (aesthetics wiki)](https://aesthetics.fandom.com/wiki/Memphis_Lite); [Memphis Design](https://aesthetics.fandom.com/wiki/Memphis_Design); [Design Shack](https://designshack.net/articles/graphics/designing-with-an-80s-trend-memphis-design-101/)
- **Rocky's Mighty Mick's Gym [S].** The exterior has "a pair of **red boxing gloves** that were painted as part of a mural". The set dressing is rowhouses, meat lockers and run-down gyms. — [Total Rocky](https://totalrocky.com/filming-locations/mighty-micks-gym/); [Rocky fandom](https://rocky.fandom.com/wiki/Mighty_Mick's_Gym)

**Games with bright city looks**
- **Subway Surfers [S]:** "a celebration of graffiti and skateboarding culture". One artist visualized every environment, train and pickup. The city theme changes every few weeks. — [Sketchfab asset pack](https://sketchfab.com/3d-models/sub-way-surf-assets-e435b57e2d7f459182b4af0fc3e38540); [Johannes Helgeson, Subway Surfers City](https://www.artstation.com/artwork/AZJmkW); [SYBO (Wikipedia)](https://en.wikipedia.org/wiki/SYBO)
- **Bomb Rush Cyberfunk [S]:** cel-shaded, with "hard colors punctuating the environments". Each gang has different graffiti, and the city has five distinct boroughs. — [Wikipedia](https://en.wikipedia.org/wiki/Bomb_Rush_Cyberfunk); [NookGaming review](https://www.nookgaming.com/bomb-rush-cyberfunk-review/)
- **Fortnite Neo Tilted (an "uptown" reference) [S]:** "branded stores, hologram billboards, new trees, and vibrant colored lights", with "around 150 outsourced props" filling it. — [Neo Tilted (fandom)](https://fortnite.fandom.com/wiki/Neo_Tilted); [Scott Homer](https://scotthomer.artstation.com/projects/oOYX1B)
- **Brookhaven RP [S]:** "clean and modern, inspired by small-town life and luxury suburban design. Bright visuals". This is a good tone match for the Suburbs. — [games.gg](https://games.gg/brookhaven-rp/)

**Real-world anchors for the iconic props**
- **Bodega awnings [S].** NYC delis "used to have **yellow awnings** as an old expedient for visibility". "Yellow awnings touch a deep, primitive part of the brain." Red-and-yellow awnings, hand-painted "Deli Grocery" signs, neon (being replaced by LED) and small ATM signs are the typical look. — [Juke, "The Yellow Awnings of New York"](https://www.juke.press/p/the-yellow-awnings-of-new-york); [Time Out on bodega signs](https://www.timeout.com/newyork/news/show-your-city-pride-with-this-new-nyc-bodega-inspired-streetwear-042220); [Bodega cat (Wikipedia)](https://en.wikipedia.org/wiki/Bodega_cat)
- **Brownstones [S].** Key features:
  - The **stoop**: "a raised entrance… providing space for residents to socialize and watch the neighborhood go by".
  - Bracketed **cornices** and arched windows.
  - Heavy **cast-iron railings**.
  - "Overflowing flower boxes" and old trees.

  Sources: [Golan Team, 10 elements](https://golanteam.com/blog/the-10-architectural-elements-of-a-brooklyn-brownstone); [Brownstoner Italianate](https://www.brownstoner.com/architecture/italianate-style-architecture-brownstone-brooklyn/); [Peter Mancini on stoops](https://petermancininyc.com/blog/why-brownstone-stoops-still-matter-in-brooklyn-real-estate)
- **Rooftop water tanks [S]:** "instantly recognizable **cylindrical** features of the skyline with **conical roofs**", "one of the symbols of New York City". More than 5,600 remain. — [Vital City](https://www.vitalcitynyc.org/nyc-wooden-water-tanks-architecture-history/)
- **Hydrant spray [S].** Kids in swim gear, "the whole street turning into a playground". The legal city-approved **spray cap** works "similar to a sprinkler". Kids running through hydrant spray is a feature of Brooklyn block parties. — [99% Invisible](https://99percentinvisible.org/article/refreshingly-clever-fire-hydrant-spray-caps-help-citizens-cool-down-safely/); [Ephemeral New York](https://ephemeralnewyork.wordpress.com/2018/07/02/opening-a-fire-hydrant-is-a-city-summer-tradition/); [Gothamist block party guide](https://gothamist.com/news/want-to-throw-a-block-party-in-nyc-heres-what-you-need-to-know)
- **Block party [S]:** a closed street with **barricades**, then "a **speaker on an extension cord**", plus BBQ and games. Hip-hop was born at DJ Kool Herc's back-to-school jam on Sedgwick Ave on 11 Aug 1973. — [Block party (Wikipedia)](https://en.wikipedia.org/wiki/Block_party); [Mr Porter](https://www.mrporter.com/en-us/journal/lifestyle/how-the-block-party-invented-hip-hop-665720)
- **Sneakers on power lines ("shoefiti") [S].** There is no single meaning. Readings range from a prank, an end-of-school rite or a memorial to the urban legend of a drug-sale marker. — [Reader's Digest](https://www.rd.com/article/shoes-on-power-lines/); [urban75](https://www.urban75.org/blog/the-mystery-of-sneakers-dangling-on-the-power-lines-of-new-york/). **[I]** One pair as an Easter egg is fine (V2 already has one [L]). Don't make it a motif.
- **Ice-cream truck [S].** Mister Softee's protected trade dress is a blue-and-white truck with a blue bottom stripe, the "Conehead" cone-headed mascot, and a registered jingle. The company enforces it. — [Mister Softee (Wikipedia)](https://en.wikipedia.org/wiki/Mister_Softee); [Stites & Harbison, Trademarkology](https://www.stites.com/resources/trademarkology/trademarkology-mister-softee-comes-down-hard-on-imposters/). **[I]** Use an original pink/mint livery and an original tune.
- **Roblox maturity rules that touch hood theming [S].** The Maturity & Compliance Questionnaire asks about violence, blood, fear, crude humor and **alcohol**. Experiences that depict alcohol are only available to verified players 17+. Unrated experiences became unplayable on **30 Sep 2025**. — [Content maturity (creator docs)](https://create.roblox.com/docs/production/promotion/content-maturity); [Roblox Help: Content Maturity Labels](https://en.help.roblox.com/hc/en-us/articles/8862768451604-Content-Maturity-Labels)

**What 2025–26 stylized city asset packs treat as essential kit pieces [S]**
- **Synty POLYGON City Pack:** 331 assets, including **Fire Escape Stairs ×3, Shop Covers ×5, Trash bins/bags ×7, Bus Stop, Rooftop Access**. — [Synty](https://syntystore.com/products/polygon-city-pack); [Fab listing](https://www.fab.com/listings/d38cfdd2-8dcf-4dd8-b9d4-83663129bb02)
- **Kenney City Kits (CC0):**
  - Commercial: "awnings, building parts and signs", 50+ objects.
  - Roads: barriers, traffic lights and road signs, 90 objects.
  - Suburban: 40 houses "with color variations", plus fences, trees and driveways.
  - Sources: [City Kit Suburban](https://kenney.nl/assets/city-kit-suburban); [City Kit Commercial](https://opengameart.org/content/city-kit-commercial); [City Kit Roads](https://opengameart.org/content/city-kit-roads)
- **Other packs:** "TOON City" has 565 blueprints, and Entroverse's "Stylized New York Megapack" covers streets, interiors and cafes. — [TOON City (Fab)](https://www.fab.com/listings/79434941-bcee-43d0-a9e1-a3454da81ecb); [Stylized New York Megapack](https://www.artstation.com/marketplace/p/PX35P/stylized-new-york-megapack)
- **[I]** The packs agree on modular building shells plus **fire escapes, shop awnings and signs, trash, transit stops and rooftop access**. Water towers, stoops and murals are the NYC-specific "flavor" layer on top.

### 1.2 Which props matter most for instant recognition (ranked) [I]

Ranking criteria:
- **Silhouette:** it reads at simulator camera distance or against the sky.
- **Uniqueness:** it says "city block", not just "town".
- **Cheer:** how easily it stays happy.
- **Sources:** how many of the references above use it.

"V2" means TheBlockV2 already builds some version of the prop, per a grep of `ServerStorage/TheBlockV2.lua` [L].

| # | Prop | Why it reads | V2? |
|---|---|---|---|
| 1 | **Brownstone/brick rowhouse with stoop + cornice** | It is the block itself. Every reference uses it (Hillwood, Sesame, Spider-Verse, Bronx games). | facades, stoops on terrace faces |
| 2 | **Rooftop water tower** | The skyline signature ("symbol of NYC"). It reads in silhouette from 100+ studs. | yes (`waterTower`) |
| 3 | **Zig-zag fire escape** | A diagonal pattern that no other building type has. It's in Synty's kit and on LEGO 123 Sesame. | yes |
| 4 | **Bodega / corner deli** (yellow awning, neon OPEN, cat) | "Yellow awnings touch a primitive part of the brain". The deli is a hub in Tha Bronx 3 and Spider-Verse. | yes, but with a green/white awning |
| 5 | **Mural / graffiti wall** (bubble letters, Memphis shapes) | Shared by Subway Surfers, JSR/BRC, Fresh Prince, the Miles Morales murals and the Bronx games. | welcome mural plus tags |
| 6 | **Street basketball court + chain-link fence** | Da Hood, Bronx games, Fresh Prince opening, Roblox hoops games. | yes |
| 7 | **Open hydrant spray** | The happiest hood image there is: water, kids, summer. | hydrant yes, spray not checked |
| 8 | **Subway entrance with green globes / elevated train** | Transit identity. It's also the World 2 portal (`Transit='Train'` in `Maps.lua`) [L]. | yes (`World2Subway`, globes) |
| 9 | **Boombox / block-party speaker stack** | Sound plus silhouette, and the origin of hip-hop block parties. | speakers in a stage |
| 10 | **Ice-cream truck** (original livery) | Color, a jingle, and a magnet for kids. | old BlockBuilder only |
| 11 | **Barbershop with spinning pole** | Built-in motion, and a hood social hub. | yes |
| 12 | **Laundromat** with porthole washers | Round shapes look cute, and the bubbles are easy VFX. | old BlockBuilder only |
| 13 | **Street-corner kit**: green street-name blades on a lamp post, mailbox, newspaper box, traffic light | The "this is a city corner" read, as with Sesame's street sign. | lamps yes, blades on Street Bag |
| 14 | **Stoop-life clutter**: milk crates, lawn chairs, potted plants, a crate-hoop | Lived-in, not grim. The crates are already there. | crates yes |
| 15 | **Pigeons + string lights + a sneaker pair** | The "alive" layer. | yes |

Next tier down, use sparingly: shopping cart (turn it into a kid's go-kart, not abandoned), trash bags (glossy navy and cute, never piled), sidewalk-shed scaffolding (a World 1 wall name already), food cart with umbrella, pay phone, newspaper stand, delivery bikes.

### 1.3 Keeping it bright: concrete rules [I]

1. **Wear becomes personality, never decay.**
   - Allowed: tape patches, stickers, chalk drawings, hand-painted signs, mismatched paint, crates, potted plants.
   - Banned: cracks with dark shadows, boarded or broken windows, crime tape, rust streaks, garbage piles, police helicopters (GTA's "deprived" cue [S]), guns, masks, gang colors and drug or alcohol signage.
2. **Warm values on the home block** (Spider-Verse [S]). Shadows stay cool and colored, not gray. That's preset H1 in `vibrant_maps.md`.
3. **Theatrical paint is allowed** (*Do the Right Thing* [S]). Paint 1–2 whole walls per view in a hot solid color (#E63B2E or #FF7A5C) behind a hangout spot.
4. **Every hood prop has one saturated "toy" color.**
   - Hydrant #E2383E with a #FFC21A cap
   - Mailbox #2F7BFF, newspaper box #FF3F7F
   - Milk crates #2F7BFF / #FF3F7F / #19B36B
   - Awning #FFC72C
5. **No large black areas.** Iron, fire escapes and lamp posts use black-plum **#2B2633** (43,38,51), never #000. Tires use #2E2E36.
6. **Memphis graphics on murals and signs.** The palette is #FF5DA2, #FFD23F, #33C3F0, #8E5CF7 and #2EC4B6, with black #1A1A1E squiggles, zig-zags, triangles and dots. It reads "90s hip-hop", stays cheerful, and is cheap to build as flat parts.
7. **Hood-specific accents** that complement P1–P5 in `vibrant_maps.md`:

| Role | Hex | RGB |
|---|---|---|
| Bodega awning yellow | #FFC72C | 255,199,44 |
| Awning lettering / hot wall | #E63B2E | 230,59,46 |
| Street-sign green | #1F8A4C | 31,138,76 |
| Subway globe (Neon) | #2DBE60 | 45,190,96 |
| Bright brownstone | #B8664A | 184,102,74 |
| Brownstone plinth | #8E4B36 | 142,75,54 |
| Iron black-plum | #2B2633 | 43,38,51 |
| Water-tank wood / roof / hoops | #B07A4A / #8A5A36 / #3A3A44 | 176,122,74 / 138,90,54 / 58,58,68 |
| Chain-link silver | #B8C0CC | 184,192,204 |
| Chalk pink / blue / cream | #FF8FB8 / #63BFFF / #FFF4DE | — |

8. **The "toy" read** (LEGO 123 Sesame Street [S]):
   - Use complementary colors on neighboring buildings.
   - Use sticker-style ads (SurfaceGui signs with a thick outline) instead of real-brand ads.
   - Open one storefront so its interior shows from the street, as the LEGO set does.

### 1.4 What specifically holds TheBlockV2 back from "feeling hood" [L + I]

- **Massing.**
  - What's there [L]: the header says "terraces three stepped brick tiers (8 / 14 / 20 studs) around everything walkable", each with a grass lip that "overhangs each terrace face by 0.6 studs, like the grass on a canyon terrace".
  - Why it hurts [I]: a stepped brick terrace with grass caps reads as a **canyon or park**. Its outline against the sky is flat steps, not a city skyline.
  - Fix [I]: turn the top terrace into **rooflines**. Add a cornice band, a parapet with a cap, and every 2–3 buildings a **water tower** or rooftop access shed so they show in silhouette. Put a **fire escape on the end wall** of each block. Keep grass only on lawns and tree pits.
- **Prop scale** [L + I]. V2 props are close to life-size: the hydrant barrel is radius 0.55 and about 2.5 studs tall, and the tank is radius 2.2. Hero props that sell the theme (hydrant, mailbox, boombox, awning letters) should be **1.5–2× life** so they read on a phone. The prior building note recommends ×1.3–2.
- **Bodega awning** [L + I]. Today it's green and white ("SUNNY SIDE BODEGA"). Switch it to **yellow #FFC72C with red #E63B2E letters**, which is the sourced visibility trick, and hang a neon "OPEN" sign in the window.
- **Missing goal on the horizon** [I]. No skyline or teaser exists (`Skyline` has 0 matches) [L]. See section 2.3.

---

## 2. "Out of the hood": showing rough-to-rich across worlds and inside World 1

### 2.1 Sourced patterns

- **Bully [S].** New Coventry is "the run-down, urban-poor borough, consisting of mainly **tenement housing, with few shops**". Old Bullworth Vale has "**mansions overlooking the water and lighthouse**". The game has "distinct neighborhood lines where visible seams appear" between districts. — [Bullworth (fandom)](https://bully.fandom.com/wiki/Bullworth); [Old Bullworth Vale](https://bully.fandom.com/wiki/Old_Bullworth_Vale); [TCRF Bully geometry](https://tcrf.net/Bully_(PlayStation_2)/Development_Leftovers_and_Oversights/Geometry)
- **GTA V [S].**
  - Grove Street is a "modest residential cul-de-sac" where "police helicopters [are] often seen patrolling".
  - Vinewood Hills has "**Bauhaus-inspired modernism**", "winding roads lined with mansions", and the **Vinewood Sign on the summit of Mount Haan** as the aspirational landmark.
  - Strawberry shows "low-income urban density".
  - Sources: [Grove Street (fandom)](https://gta.fandom.com/wiki/Grove_Street_(HD_Universe)); [Vinewood](https://gta.fandom.com/wiki/Vinewood_(HD_Universe)); [Vinewood Sign](https://gta.fandom.com/wiki/Vinewood_Sign_(HD_Universe)); [ArchUp map analysis](https://archup.net/comparing-los-santos-map-los-angeles/)
- **Sesame Street's makeover [S]:** "repainted in **brighter** colors… everything seemed **cleaner**", plus a bike shop and a **rooftop garden**. — [Current.org](https://current.org/2019/08/after-50-years-on-tv-has-sesame-street-been-gentrified/)
- **The Jeffersons [S]:** "movin' on up… to a **deluxe apartment in the sky**", "a metaphor for achieving a higher level of comfort". Upward mobility shown as literal height. — [Musician Wages](https://www.musicianwages.com/the-meaning-behind-the-song-movin-on-up-theme-to-the-jeffersons-by-janet-dubois-and-oren-waters/); [Cord Cutters News](https://cordcuttersnews.com/movin-on-up-the-jeffersons-first-premiered-50-years-ago-today/)
- **Fresh Prince [S]:** a West Philly playground and basketball court, then the Bel-Air mansion, with the whole move told in a bright graffiti-styled opening. — [Art of the Title](https://www.artofthetitle.com/title/the-fresh-prince-of-bel-air/)
- **Rocky IV [S]:** "the ruggedness of Rocky's training in the wilderness and **DIY training tools**" against Drago's "**high-tech, computer-run** athletics facility". It's the same climb told through equipment. — [SlashFilm](https://www.slashfilm.com/1215487/rocky-iv-has-the-greatest-training-montage-of-all-time/); [Collider](https://collider.com/best-training-montages-from-rocky-creed-ranked/)
- **Clash of Clans material ladder (walls) [S]:**
  - L1 "wooden fences with rope"
  - L2 uncut rock, L3 cut stone, L4 solid iron and taller
  - L5 **carved gold**
  - L6–8 crystal (pink, then purple, then black with a skull)
  - L9–11 spikes, fire and lava
  - L12 white and gold "with golden lights shining through"
  - L13 electric, L14 ice

  Sources: [Wall (CoC fandom)](https://clashofclans.fandom.com/wiki/Wall); [clasher.us](https://www.clasher.us/clash-of-clans/unit/Wall)
- **Clash of Clans Town Hall [S].** TH6 adds "small **golden pillars** … with **vines**". TH10 adds an "octagonal golden rim", and "the **red carpet** entryway receives **gold trim**". TH11 gets a golden entrance. Higher levels add "ethereal blue glows" and ice or lava themes. — [Town Hall/Upgrade Differences](https://clashofclans.fandom.com/wiki/Town_Hall/Upgrade_Differences)
- **Idle Fitness Gym Tycoon [S]:** you "**transform a small empty gym into the crowded sports center**" with "visible progress in your premises". — [Google Play](https://play.google.com/store/apps/details?id=com.codigames.idle.fitness.gym.tycoon); [App Store](https://apps.apple.com/vc/app/idle-fitness-gym-tycoon-game/id1478629374)
- **Simulator zone ladders** (from prior notes, [S]). Muscle Legends gyms get "larger treadmills… glowing statue". Arm Wrestle Simulator goes School → Space Gym → … Steal an Egg has 10 biomes, each gated by speed. Strongest Punch Simulator has 30 worlds of themed walls ("Desert… Cobblestone looking walls", "Grasslands… Grassy walls"). — [Strongest Punch Sim Worlds](https://roblox-strongest-punch-simulator.fandom.com/wiki/Worlds)

### 2.2 The progression axes [I]

Use 5–6 axes at once and keep **one hero hue per world**. The world accents already exist in `ReplicatedStorage/Shared/Config/Maps.lua` [L]:
- Block (242,182,50) = #F2B632
- Suburbs (111,175,78) = #6FAF4E
- Uptown (96,172,255) = #60ACFF
- Hills (255,138,76) = #FF8A4C

| Axis | World 1 The Block | World 2 The Suburbs | World 3 Uptown | World 4 The Hills |
|---|---|---|---|---|
| **Signature silhouette** | Water tower + zig-zag fire escape + stoop | Gable roof + picket fence + hoop over the garage | Glass tower + doorman canopy + rooftop pool | White villa on a hilltop + palm + infinity pool + gold gate |
| **Height / altitude** | 2–4 storeys (22–44 studs), tight | 1–2 storeys (12–24), wide lots | Street level framed by 8–30-storey towers (backdrop 80–250 studs); the player can reach rooftops | 2 storeys, but **on high ground** (+40–80 studs) with long views. Height turns into altitude. |
| **Density** (prop cluster every…) | 12–16 studs of path edge | 20–30 | 16–24, curated and symmetrical | 30–40. Empty lawn is the luxury. |
| **Ground** | Light sidewalk slabs #EDE6DA with chalk drawings and patch tiles; asphalt #4B5263 | Smooth sidewalks, lawns #7AD957, driveways #D9D4CC | Two-tone pavers #E8E2D6/#CFC6B6, marble steps, red carpet #C8102E | Warm cobble drive #E7D3B0, gravel paths, lawns |
| **Greenery** | Tree pits, window boxes, a community garden | Lawns, round trees, flower beds, hedges | Boxwood balls in planters #3FA65A, rooftop garden, fountain park | Palms #2FBF71 / trunk #B98A5A, cypress, hedges, vineyard rows |
| **Walls / materials** | Brick and brownstone, chain-link, plywood, tape | Siding in pastels: #A8D8F0, #FFE7A3, #CDEBC0, #F7C6D9; white trim | Glass #7CC4FF with white mullions, steel #C9D1DC, limestone #F3E9D2 | Stucco #FFF8EE, terracotta roofs #E0703E, marble, gold |
| **Fences** | Chain-link with colored privacy slats | White picket | Velvet ropes, glass rails | Wrought iron with gold finials + hedges |
| **Signage** | Hand-painted, neon OPEN, bodega awnings, murals | Yard signs, named mailboxes, a "HOA" sign | LED and hologram billboards (#FF2E9A/#22E5FF), lightbox storefronts, address numbers on canopies | Almost none: gold monogram on gates, hillside letters |
| **Gold share of accents** | 0% (gold only on the station and trophies) | ~2% (brass house numbers, door knobs #C9A24A) | ~5% (canopy piping #E8C25A, elevator doors) | 10–15% (gates, fixtures, trims #FFC83D) |
| **Light** (`Maps.lua` ClockTime) | Warm afternoon (17.2 today; the prior note suggests 14.5 for day) | Fresh morning (10) | Dusk with neon (18.6) | Golden hour (18.1) |
| **Transit** (`Maps.lua`) | Train | Car | Helicopter | Jet teaser |
| **Wall theme** (`Maps.lua` wall names) | Chain Link Fence, Hydrant Spray, Block Party… | Sprinklers, HOA Fence, School Bus… | Velvet Ropes, Revolving Door, Rooftop Party… | Estate Gate, Palm Drive, Car Show… |

Rules [I]:
1. **Never make World 1 "the bad place."** The last evolution title is already "Made It From the Block" [L], so the arc is about pride.
   - The Block is humble but loved: warm, saturated and full of people.
   - Later worlds are bigger, shinier and more spacious, but quieter.
   - Carry Block callbacks upward: a Block mural in the Suburbs garage, a Block trophy in the Hills mansion. The Jeffersons and Fresh Prince both frame the move as aspiration, not escape [S].
2. **The richer the world, the less clutter and the more empty space.** Bully's poor district has "few shops" and is dense; the rich side has mansions "overlooking the water" [S]. Space and view are luxury cues.
3. **Material ladder** (Clash of Clans pattern [S]): rope and wood → stone and brick → iron and steel → gold → crystal and glass. Hood's version per world: brick and chain-link → siding and picket → glass and steel → stucco, marble and gold.
4. **Gold enters late and stays small until World 4.** In Clash of Clans, gold pillars appear at TH6 and red carpet gold trim at TH10 [S], so gold is a mid-to-late privilege.

### 2.3 Show the destination from the start [I, modeled on S]

- **Skyline teaser.** From the Block lobby, put a low-poly **Uptown skyline** on the horizon: 5–8 tall boxes in #7CC4FF and #C9D1DC with Neon window strips, faded by Atmosphere. On a far hill, place a "**THE HILLS**" letter sign in white with gold #FFC83D trim. This copies the Vinewood Sign idea: an aspirational landmark on a summit, visible across the map [S]. It's also the Jeffersons' "apartment in the sky" [S].
- **Transit as a reward.** The subway entrance (green globes #2DBE60) is the doorway out. Give it the **only gold trim in World 1** and a big "NEXT STOP: THE SUBURBS" lightbox.
- **Peek-through.** Past the last stage wall, let players glimpse **Suburbs green** (lawn, a round tree, a picket fence) through the station's far exit.

### 2.4 Stages inside World 1: "the street gets nicer as you go" [I]

What exists [L]:
- `Maps.lua` defines 10 walls for the Block: Moving Boxes, Chain Link Fence, Delivery Truck, Hydrant Spray, Construction Barrier, Scaffolding, Food Cart Line, Block Party, Pigeon Flock, Station Turnstile.
- TheBlockV2 already gives each stage segment **one dominant hue**, a "colour-coded mural gallery" (`TheBlockV2.lua` ~line 376).

Proposed sub-arcs, each adding **one visual privilege** per stage (Sunstrike rule [S]):

| Stage (wall) | Sub-arc | New privilege added here (all earlier ones stay) | Building height |
|---|---|---|---|
| 1 Moving Boxes | **Back Alley** | Base set: crates, chalk hopscotch, cardboard, chain-link | 2 storeys |
| 2 Chain Link Fence | Back Alley | Colored privacy slats in the fence, using the stage hue | 2 |
| 3 Delivery Truck | Back Alley | The first full **mural** wall in the stage hue | 2–3 |
| 4 Hydrant Spray | **Main Block** | First **water and particles**: an open hydrant spray with a mini rainbow and a puddle | 3 |
| 5 Construction Barrier | Main Block | **Fresh paint**: one facade mid-repaint, with rollers, a drop cloth and wet-paint sign | 3 |
| 6 Scaffolding | Main Block | **Reveal**: the scaffolding comes down to show freshly painted facades with flower boxes | 3 |
| 7 Food Cart Line | **The Avenue** | **String lights** across the street + food carts with striped umbrellas | 3–4 |
| 8 Block Party | The Avenue | **Neon + music**: bunting, DJ speaker stack, balloons, neon signs | 4 |
| 9 Pigeon Flock | **Station Plaza** | **Clean pavers + planters + a fountain**, with pigeons fluttering off when walked through | 4 |
| 10 Station Turnstile | Station Plaza | **First gold**: tiled station entrance, green globes, gold sign, a Suburbs glimpse | 4 + skyline |

- Keep stage 1 **bright**. "Rough" here means busier and more DIY, never darker or dirtier.
- Ramp the street light from about 3 lamps per stage to about 6, ColorCorrection saturation +0 → +0.06, and flower count 0 → 12.

---

## 3. Punching bags and boxing-gym presentation

### 3.1 Real bag types: defining shape and hardware

From prior notes [S]:
- **Heavy bag:** 4 top D-rings, chain spider to a swivel, 70–150 lb, 2.5–6 ft.
- **Speed bag:** teardrop under a wooden rebound platform on a steel bracket.
- **Double-end:** a ball between floor and ceiling bungees with carabiners.
- **Tire bag:** a tire stack; 4 tires weigh about 80–90 lb.
- **Ring:** 4 ropes, 16 turnbuckles, red/blue/white/white corners.

Sources: `prop_modeling_and_tiers.md` §3.

New this session:

| Type | Defining shape and hardware | Notes |
|---|---|---|
| **Banana bag** (Muay Thai) | **6 ft, tapered** tall bag. The Fairtex HB6 is about 40 kg filled, Syntek leather, handmade in Thailand. | Colors: black, yellow, red, green, blue, pink, black/gold, throwback brown [S]. [Fairtex](https://www.fairtex.com/products/6ft-muaythai-banana-bag-unfilled-all); [fairtexstore](https://fairtexstore.com/en-us/collections/fairtex-heavy-bags) |
| **Teardrop / uppercut / wrecking-ball / body-snatcher / bowling-pin** | Wide-bottomed or spherical bags for knees and uppercuts. Angle bags have an angled striking face. | [S] [FightMMA types](https://www.fightmma.org/types-of-punching-bags/); [Way of the Fighter](https://wayofthefighter.com/types-of-punching-bags/); [Wikipedia, Punching bag](https://en.wikipedia.org/wiki/Punching_bag) |
| **Wall bag** | Flat bag mounted on a wall with an angled striking area | [S] same sources |
| **Free-standing / BOB** | A weighted base. BOB is shaped like a human torso. | [S] same sources |
| **Maize bag** (slip bag) | **Small teardrop on a long chain at head height**, historically filled with **dried corn**. It swings along an arc for slipping and bobbing. | [S] [Honour & Glory](https://www.honourandglory.co.uk/blog/boxing-maize-bag-training-guide); [Ask Me Boxing](https://askmeboxing.com/types-of-punching-bags-explained/) |
| **Aqua bag** | **Water-filled teardrop**, thick-walled vinyl, injection-molded ends, weight markings. Sizes 15–190 lb. | Colors: **Bad Boy Blue, Haymaker Black, Fireball Orange** [S]. [Aqua Training Bag](https://www.aquatrainingbag.com/pages/aqua-punching-bags); [Revgear 190 lb](https://revgear.com/aqua-training-heavy-bag-21-190lb/) |
| **DIY / duffel bag** | A duffel stuffed with clothes or sand-filled pillowcases, **rope-wrapped, duct-taped, zip-tied**. Costs about $10. | [S] [Instructables](https://www.instructables.com/DIY-Punching-Bag/); [theplywood](https://theplywood.com/diy-punching-bag/); [musclerig](https://musclerig.com/homemade-punching-bag) |

### 3.2 Color grammar of boxing gear [S]

Use the **color grammar only, never the names or logos**.

| Grammar | Where it comes from | Use in Hood [I] |
|---|---|---|
| **Classic red + black** | Cleto Reyes Heavy Bag in "Classic Red" and black; gym bag "red and black nylon with … Champy emblem". [Cleto heavy bag](https://cletoreyesboxing.com/product/cleto-reyes-heavy-bag/); [Cleto gym bag](https://cletoreyesboxing.com/product/cleto-reyes-gym-bag/) | Heavy Bag body red; Pro Bag black with red bands |
| **Green + gold** | Cleto "Classic Speed Bag – WBC Edition in the iconic green and gold". The WBC belt is a green strap with a gold medallion and **country flags**. [Cleto WBC speed bag](https://cletoreyesboxing.com/product/classic-speed-bag-wbc-edition/); [WBC belt history](https://wbcboxing.com/en/the-evolution-of-our-wbc-championship-belt/) | Champ belt hologram colorway (original design) |
| **Gold + black, with a globe** | WBA belt. [Royal Belts explainer](https://www.royalbelts.com/blogs/royal-belts-blog/wbc-vs-wba-vs-ibf) | Gold tier trims |
| **Red strap, eagle + globe; light blue variant** | IBF belt. Same source. | Ring apron/skirt |
| **Burgundy, blue, gold** | WBO belt, redesigned Nov 2025. [Fightnews](https://fightnews.com/wbo-introduces-new-belt-design/140692) | — |
| **Camo** | Everlast camo canvas bag, "popular in armed services gyms", plus a digital-camo kit. [Amazon listing](https://www.amazon.com/everlast-training-heavy-camo-70-pound/dp/b000lolrk2); [Walmart kit](https://www.walmart.com/ip/Everlast-80lb-Digital-Camo-Heavy-Bag-Kit/47531056) | An olive-drab army duffel for the Duct Tape Bag |
| **Toy brights** | Aqua bag Blue/Black/Orange; Fairtex banana-bag rainbow of colors | Shows that bright bags are real-world normal |

### 3.3 How boxing and punch games present gyms and upgrades [S]

- **Boxing League (Roblox):**
  - The **Smoll Gym** is "Class C's only gym", with dumbbells, pull-up bars, push-up mats and **punching bags**.
  - Classes are C (lvl 1), B (20), A (40) and S (70).
  - The bag minigame shows a **random target number** to reach with jabs and uppercuts (uppercuts +100).
  - Sources: [Smoll Gym](https://boxing-league-roblox.fandom.com/wiki/Smoll_Gym); [Punching Bag](https://boxing-league-roblox.fandom.com/wiki/Punching_Bag); [Class C](https://boxing-league-roblox.fandom.com/wiki/Class_C)
- **Untitled Boxing Game (767M+ visits):** fight "maps". Everyone starts with "the regular boxing ring and the plain blue performance maps", and "cooler maps can be bought in the store". There's also an unobtainable "Kamogawa Gym" map. — [UBG Maps (fandom)](https://untitled-boxing-games.fandom.com/wiki/Maps); [Sportskeeda beginner guide](https://www.sportskeeda.com/roblox-news/beginner-s-guide-roblox-untitled-boxing-game)
- **Boxing Simulator (Roblox):** "unlock new awesome **islands** using your powers, sell your strength for better **gloves** and DNA… **pets**". — [Boxing Simulator](https://www.roblox.com/games/4058282580/Boxing-Simulator)
- **Punch Wall:** default **black gloves** and a **glove shop at the center of the lobby**. Ascending unlocks gloves and skins, and new themed worlds keep arriving ("China"). — [Sportskeeda guide](https://www.sportskeeda.com/roblox-news/punch-wall-a-beginner-s-guide); [player.one](https://www.player.one/roblox-punch-wall-codes-october-2025-keep-punching-brick-walls-break-through-worlds-161435)
- **Strongest Punch Simulator:** 30 worlds whose walls carry the theme, e.g. "Desert with Cobblestone looking walls". — [Worlds](https://roblox-strongest-punch-simulator.fandom.com/wiki/Worlds)
- **Boxing Star (mobile):** a gym of equipment whose **combinations** set training efficiency, with equipment grades up to **Grade 8**. — [Boxing Star Gym (fandom)](https://boxingstar.fandom.com/wiki/Gym); [MMOHuts](https://mmohuts.com/news/boxing-star-introduces-new-boxing-star-gym/)
- **Takeaway [I].** In the boxing and punch games I found, equipment is functional furniture (Boxing League) or the cosmetics are gloves, maps and pets. **None treats the bag itself as a collectible showpiece**, so a 9-step bag ladder with growing spectacle is a real differentiator for Hood. The Rocky IV "DIY vs high-tech" contrast [S] gives the ladder its story.

### 3.4 How stylized games make an item look more valuable [S → I]

- **One privilege per step [S]:** "Each step adds one visual privilege — more crystals, then a base, then gold, then a frame — and never adds two at once… each tier reads as an upgrade of the last through **size, gold trim and glow**." — [Sunstrike Studios, Game Art Styles](https://sunstrikestudios.com/en/blog/game-art-styles/)
- **Silhouette first [S]:** "Every object needs a silhouette recognizable at a glance… at gameplay distance the silhouette is most of what a player sees." — same source (search summary)
- **Material ladders [S]:** the Clash of Clans walls and Town Hall (§2.1).
- **Color ladders [S].** Fortnite uses gray, green, blue, purple, then gold/orange, with "Exotic" in light blue and cyan. In v29.20 (Apr 2024) Epic removed visible rarity colors from cosmetics only. — [fnlocker](https://www.fnlocker.gg/guides/fortnite-rarities); [eXputer](https://exputer.com/guides/fortnite-weapon-rarity/); [TechRadar](https://www.techradar.com/gaming/consoles-pc/fortnite-has-removed-item-rarities-and-some-players-arent-happy); [TV Tropes, Color-Coded Item Tiers](https://tvtropes.org/pmwiki/pmwiki.php/Main/ColorCodedItemTiers)
- **Reconciling with the prior note [I].** The prior note's rule is "stack channels". Sunstrike's rule is "one new privilege per step". They fit together: privileges are **cumulative**, and every tier keeps the earlier ones. Hood's ladder of privileges, in order:
  1. identity and personality
  2. a bright accent plus sound
  3. paint and graphics plus a faint glow
  4. pedestal plus the first real light
  5. chrome plus particles
  6. motion plus electricity
  7. stage, spotlight and a fire element
  8. gold, gems, halo and god-ray
  9. arena: crowd, hue-cycling and confetti

  Size ramps on every tier, and the unlock ceremony scales with the tier.

### 3.5 Diagnosis of the current bag ladder [L + I]

What `ServerStorage/HoodProps.lua` does well [L]:
- Channels are cumulative: first light at Heavy, particles at Speed, motion at Double-End, halo and gems at Gold, hue-cycling at the Ring.
- Real hardware: D-rings, spider, swivel, seams, buckle.
- A rarity nameplate, a price tag, and a barrel bulge on every bag.

What holds it back [I]:
1. **Silhouette sameness.**
   - Measured from the code [L]: tiers 2, 3, 4, 7 and 8 all call `bag()` (cylinder plus belly) on an L-shaped `gallows()`. Body radius is 1.25 / 1.3 / 1.5 / 1.35 / 1.55 and height 4.4 / 4.6 / 5.4 / 6.0 / 5.8.
   - The Gold Bag (5.8) is shorter than the Pro Bag (6.0). The total size range is only about 1.3×.
   - At lobby distance, five of nine stations read as "the same bag, recolored".
2. **Two color systems** [L].
   - `Skins.Stations[].Color`: tan Tape, red Heavy, orange Speed, purple Double-End, teal Pro, pink Ring.
   - `Props.Rarity`: green, purple, pink, cyan, red, white/hue.
   - The UI uses the first; the props, nameplates and mats use the second. Pick one. I recommend `Props.Rarity`, because it follows the industry ladder, and setting `Skins.Stations.Color` to the same values.
3. **The hood story stops at tier 3.** Tiers 4–9 are generic gym kit. The mount is the cheapest storytelling channel: lamp post, then scaffold, then street sign, then gym gallows, then gym wall, then arch, then stage, then marble arch, then arena.
4. **Small for a phone.** Bodies of 4.4–6 studs next to a 5-stud character, on 8×8 pads spaced 10 studs apart (`TheBlockV2.lua` `buildBoxingClub`: cols −28/−38/−48/−58, 2 rows [L]). The top tiers need room to be bigger.
5. **Hit feedback isn't tier-specific.** Every bag should *sound and burst* like its tier, e.g. coins from the Gold Bag.

---

## 4. Cartoony proportions and "cool, not realistic" rules for bags [I]

- **Fatter than real.**
  - Real heavy bag: about 14 in × 48 in, a diameter-to-height ratio of about 1:3.4.
  - Cartoon heavy bag: **1:1.8–1:2.2** (3.2 × 6.0 studs).
  - Belly 8–10% wider than the caps. Caps 1.05× the body, using Ball parts squashed to 0.35–0.6 height.
- **Hardware 2–3× real.**
  - D-rings 0.6 studs, chain links 0.5–0.6, swivel ball 0.7–0.9, buckles 0.6 × 0.6.
  - Chrome #C9D1DC, or gold #FFC83C on top tiers.
- **Size ramp.**
  - Hanging body height across tiers 1→8: about 4.2 → 4.8 → 5.2 → 6.0 → (speed rig) → (double-end arch 13 tall) → 8.0 → 6.5 tall but 4.6 wide.
  - Frame top: 10 → 10.5 → 11 → 11.5 → 12 → 13 → 14 → 16. The Ring truss is 17+.
- **Personality decals on low tiers:** a chalk smiley on the tire, tape "X" eyes on the duffel, a tagged name on the Street Bag. Humor reads at small size.
- **Every tier gets a distinct silhouette:** stack, lump, cylinder, fat cylinder, wall rig, arch, tall banana, sphere-teardrop, arena.
- **Juice on hit.**
  - Squash and stretch the bag: scale Y 0.92 → 1.04 over 0.12 s.
  - Swing on the chain and jingle the hardware.
  - Fire a tier-specific particle burst and sound.
  - Add a camera micro-shake only from tier 7 up.
- **Avoid realism traps.** No fine stitching, no realistic leather textures, no real brand logos, no blood. Wear shows as flat patches and tape, not grime.

---

## 5. Hood starter kit

These are the 15 props to build first, each as a part recipe with colors (sizes in studs). Several already exist in TheBlockV2 in a simpler, life-size form [L]. Treat these as the target spec and **upgrade those to hero scale**. All recipes are [I].

1. **Rowhouse module.**
   - Body: 18–22 wide × 2–4 storeys of 11 studs, brick #D8603F or bright brownstone #B8664A, on a 1.5-stud plinth #8E4B36.
   - Cornice: a cream #FFF4DE band 1.2 thick protruding 0.8, with dentil blocks (0.5 cube every 1.5) and 2 wedge brackets per bay.
   - Parapet cap on top.
   - Windows: inset 0.5, glass #2A3A6B (about 1 in 5 lit #FFE29A), cream frames 0.5, protruding sills 0.6.
   - A window box with 3 Ball flowers (#FF2E9A / #FFD23F / #FFFFFF) on every second window.
2. **Stoop + door.**
   - 5 Block steps, each 1 rise × 1.2 run × 6 wide, in #B8664A with cream nosing strips.
   - 2 iron railings #2B2633 (0.3 bars) ending in Ball finials 0.6.
   - Door 4 × 8 in an accent (#2F7BFF / #FF3F7F / #19B36B) with 2 inset panels.
   - Transom: Neon #FFD98A at Transparency 0.3. A wedge-bracket hood above.
3. **Zig-zag fire escape.**
   - Per floor: a 6 × 2.5 DiamondPlate platform #2B2633 with 0.25-bar railings at 3 tall.
   - Diagonal stair between floors: a 1.6-wide plate with 6 step blocks, about 45°.
   - A drop ladder of 2 rails plus rungs at the bottom.
   - Put it on 1 in 3 facades, plus every block end wall. Hang a potted plant or a laundry line off one platform.
4. **Rooftop water tower** (hero scale: 1.4× the current V2 one).
   - Tank: Cylinder 6 diameter × 6 tall, WoodPlanks #B07A4A.
   - 3 hoops: Cylinder 6.1 × 0.3, #3A3A44.
   - Conical roof: 3 stacked cylinders 6.4 / 4.2 / 2 × 0.7, #8A5A36, plus a Ball finial.
   - Stand: 4 legs (0.6 square × 5) with X-braces, on a plank deck.
   - Optional: painted "THE BLOCK" lettering in #FFF4DE. Place at least 1 on every skyline view.
5. **Bodega / corner deli.**
   - Storefront 16 wide.
   - **Awning:** a 16 × 3 × 1.5 slanted Wedge in #FFC72C with flat end-cap wedges and red #E63B2E letters "DELI • GROCERY • 24/7" (SurfaceGui with a white stroke).
   - Window: stacked mini product boxes (0.6–1 cubes) in 6 colors behind glass.
   - "OPEN" sign: Neon #FF2E9A letters on a #1A1A1E board, with a PointLight.
   - A rolled-up gate cylinder (#A7AFBA) above the door.
   - The **bodega cat** (orange #F28C38 Ball body, wedge ears) on a milk crate.
   - No beer or lottery signs (17+ rule).
6. **Mural wall.**
   - Base coat in the stage hue.
   - 3–5 flat shapes 0.1 proud: triangles from wedges, dots from flat cylinders, squiggles from chains of rotated 0.4-wide blocks. Use #FF5DA2, #FFD23F, #33C3F0, #8E5CF7 and #2EC4B6.
   - Behind each shape, a #1A1A1E copy 0.3 larger as an outline.
   - Bubble letters ("THE BLOCK", "+1", the stage number) via SurfaceGui with a thick stroke.
   - A sunburst on 1 in 3 walls.
7. **Chain-link fence with slats.**
   - Posts: Cylinder 0.3 × 9 every 6, #B8C0CC, with a top rail.
   - Mesh: a semi-transparent panel at 0.55 as in V2, or a diamond-grid Texture.
   - **Woven privacy slats**: vertical 0.25-wide blocks every 0.6 in the stage hue on alternating posts, so the fence reads bright.
8. **Street hoop + court.**
   - Pole: Cylinder 0.5 × 10, #2B2633, with a curved arm.
   - Backboard: 4 × 2.6 white with a red #E63B2E square.
   - Rim: orange ring of 12 small blocks.
   - **Chain net**: 8 silver #C9D1DC bars tapering down.
   - Court #FF8A3D with a #2BB8F0 key (already in V2), plus a crate-hoop (milk crate on a pole) as a DIY second hoop.
9. **Open hydrant spray.**
   - Hydrant at **1.6× hero size**: barrel Cylinder 1.8 diameter × 2.8, #E2383E; Ball dome cap #FFC21A; side nozzles 0.8.
   - A spray-cap nozzle feeding a ParticleEmitter fan: #9EE7FF, Speed 16–20, SpreadAngle (10, 25), Acceleration (0, −40, 0), Lifetime 0.6.
   - A puddle disc: Cylinder 7 × 0.05, #6FD3FF at Transparency 0.4.
   - A 3-band mini rainbow arc in Neon at Transparency 0.6.
   - 1–2 NPC kids in swim gear.
10. **Subway entrance (World 2 portal).**
    - Stair opening with green #1F8A4C railings.
    - 2 globe lamps: Ball 1.4, Neon #2DBE60, on 6-stud posts.
    - Lintel band "BLOCK STATION": white on #1A1A1E.
    - Tiled cheek walls #FFF4DE with a #2DBE60 stripe.
    - The **only gold trim in World 1**: #FFC83D sign frame plus a "NEXT STOP: THE SUBURBS" lightbox.
11. **Boombox + speaker stack.**
    - Boombox: 3 × 1.6 × 1, body #2B2633, silver #C9D1DC face.
    - 2 speaker cones (flat Cylinders 1.0, #1A1A1E) with Neon rim rings (#FF5DA2 / #33C3F0).
    - A bar handle on top.
    - Speaker stack: 3 cubes of 2.5 whose cones bob to the beat (client tween, scale 1 → 1.08).
    - Place under a striped pop-up tent at the block party.
12. **Ice-cream truck (original livery).**
    - Rounded van body 10 × 5 × 5: white #FFFFFF, bubblegum stripe #FF8FB8, mint roof #74D9B5.
    - A serving window with a little striped awning.
    - A **giant cone on the roof**: Wedge-built cone #E8B26A plus Ball scoop #FFD1E8 and a cherry.
    - Use an original jingle. Not Mister Softee's blue/white or cone-head mascot [S].
13. **Barbershop pole.**
    - Glass housing Cylinder 0.9 × 4 at Transparency 0.4.
    - Inside: alternating tilted #E63B2E / #FFFFFF / #2F7BFF bands, client-spun at 90°/s.
    - Chrome Ball caps #C9D1DC.
    - Sign "FRESH CUTS" (V2 has "UPTOWN CUTS" [L]; keep "Uptown" for World 3).
14. **Laundromat front.**
    - A window row of 4 washer portholes: Cylinder 2 diameter, chrome ring #C9D1DC, glass #63BFFF.
    - White Neon "bubble" balls drifting up inside (client tween).
    - Sign "SUDS" in bubble letters on teal #22BFB0.
    - Steam-puff particles from a side vent.
15. **Street-corner kit.**
    - Lamp post #2B2633 carrying two crossed green **street-name blades** (#1F8A4C, white text: "BLOCK ST" / "HOOD AVE").
    - A hanging traffic light with a #FFC21A housing.
    - Mailbox #2F7BFF (1.5× size), newspaper box #FF3F7F, trash can #19B36B.
    - **Pigeons**: #9AA3B5 Ball bodies with an iridescent neck band (#6E4BA8 / #3FBF8F) that flap away when a player gets close.

Seasoning, used sparingly: string lights across streets, one sneaker pair on a wire, milk crates (#2F7BFF / #FF3F7F / #19B36B), lawn chairs on stoops, a "Rocky-style" painted pair of red gloves on the gym's outside wall (Mighty Mick's mural [S]).

---

## 6. Bag ladder redesign

Here's the per-tier spec. All of it is [I], built on the sourced patterns in §3.

**Story:** Street junk (1–3) → the gym classic (4–6) → the pro (7) → gold (8) → the arena (9).

**Tier colors.** Use `Props.Rarity` everywhere: trim, nameplate, mat, particles and UI. Align `Skins.Stations.Color` to match.

| Tier | Rarity color |
|---|---|
| 1 | #AAAEB8 |
| 2 | #4CD964 |
| 3 | #409CFF |
| 4 | #AA55FF |
| 5 | #FF5AC8 |
| 6 | #3CE6FF |
| 7 | #FF3C3C |
| 8 | #FFC83C |
| 9 | hue-cycle |

**Layout.** Turn the 4×2 grid (10-stud spacing [L]) into a "**Walk of Fame**" aisle in tier order, with footprints that grow:

| Tiers | Footprint (studs) | Floor |
|---|---|---|
| 1–3 | 8 | Sidewalk |
| 4–6 | 9 | Rubber gym floor #3A3F4B with colored lane lines |
| 7 | 10 | Stage carpet |
| 8 | 12 | Stage carpet |
| 9 | Ring at the end | Ring |

Hang a spotlight over the **next affordable** station. For locked stations, use a tarp or silhouette with the price; see `prop_modeling_and_tiers.md` §5.

| # | Station (cost, mult) | Silhouette and size | Body and colors | Mount / frame | Base | **New privilege** | Idle motion | Hit reaction | Unlock "wow" |
|---|---|---|---|---|---|---|---|---|---|
| 1 | **Tire Bag** (free, ×2) "Corner Tire" | Stack of 3 fat tires, each 3.4 diameter × 1.1, total about 4.2 tall | Tires #2E2E36 with a cream whitewall stripe; a **chalk smiley** on the front tire (#FFF4DE + #FF8FB8 cheeks) | Bent street-lamp arm (#2B2633) with its warm Neon lamp still lit; frayed rope #C49A64 | Sidewalk slab #D8D0C2 with **chalk hopscotch** (#FFD23F / #63BFFF squares), a milk crate seat, a cardboard "FREE" sign #C9A36B | Identity + personality | Lazy swing ±4° | Rubber "boing" squash, dust puff #D8D0C2 | (Free) the lamp flickers on |
| 2 | **Duct Tape Bag** (50, ×3) "Patched Duffel" | Lumpy duffel, 2.6 diameter × 4.8, tilted 5°, lopsided belly | Olive army duffel #7A8B3A (camo-gym grammar [S]); 4 jaunty Foil tape bands #C9CED6, a tape "X" patch (cartoon eye), a dangling tape tail; **neon-green zip ties #4CD964**; rope wrap | Scaffold pipes, or a sidewalk-shed frame painted #1F8A4C, with clamps | Wood pallet #C49A64 + a **boombox** on a crate | First bright accent + first sound (boombox loop) | Swing; boombox cones bob | Tape flap + white stuffing tufts #FFFFFF | Boombox drops a beat |
| 3 | **Street Bag** (150, ×4) "Tagged Canvas" | Clean cylinder 2.8 diameter × 5.2 | Canvas #409CFF covered in **Memphis squiggles + bubble-letter tag** (#FF5DA2, #FFD23F, #1A1A1E outlines) | Green street-sign pole with crossed street blades (already in code [L]) + a **chain-link backdrop panel with blue slats and tags** | Curb with a blue painted edge + faint Neon ground ring (Transparency 0.5) | Paint and graphics + first glow | Swing | **Paint-splat** particles (flat squares in 3 mural colors) | Spray-can "psst" + a tag appears on the backdrop |
| 4 | **Heavy Bag** (500, ×6) "The Classic" | **Fat** cylinder 3.2 × 6.0 (first big jump: about 1.4× tier 3's volume) | Glossy red #D62834, white caps #F5F5F5, black strap #1E1E24 with chrome buckle, 4 chunky D-rings 0.6, swivel ball 0.8 | Black steel gallows #24262E with gussets and bolts | DiamondPlate plinth 0.9 with a **purple Neon edge** + a **gym poster board** behind ("BLOCK BOXING CLUB", painted red gloves) | Pedestal + first real light (purple uplight) | Swing + chain jiggle | Deep **thump shockwave ring** (white → #AA55FF) + chain jingle | Uplight slams on with a "dun" |
| 5 | **Speed Bag** (1K, ×8) "Speed Rig" | Wall unit: padded backboard 7 wide × 9 tall + round platform 6 diameter at about 8 high + an **oversized teardrop** 2.2 × 3.0 | Bag #FF5AC8 / #FFE3F4 two-tone with seam band; platform glossy wood #C47A3A with chrome rim #C9D1DC; backboard of tufted pink pads (3×2 rounded blocks) | Chrome wall bracket + a **round timer clock** (box with red/green Neon lights, "3:00") | One-step plinth with pink trim | Chrome + first particles (sparkles) | **Constant fast rattle** (±15° at about 4 Hz) | Rapid "tat-tat-tat" sparkle bursts + motion streaks | Clock bell "DING" |
| 6 | **Double-End Bag** (3K, ×12) "Live Wire" | **Arch** frame 7 wide × 13 tall + big ball 2.6 diameter | Ball navy #24305A with a cyan Neon belt #3CE6FF; **Neon bungees** with lightning Beams | Two uprights + a header in #28304A, a yellow "HIGH VOLTAGE" plate #FFD23F | Octagon two-step stage #28304A with cyan Neon trim | Motion (orbiting chips) + electricity | Ball bobs; orbit spins 90°/s | **Zap** spark burst + quick white flash; exaggerated wobble | Arc of lightning across the header |
| 7 | **Pro Bag** (8K, ×18) "Pro Banana" | **Tall tapered banana** 2.6 diameter × **8.0** (taller than the player; new silhouette) | Black #1E1E24 with red #FF3C3C bands and gold #FFC83C piping (red/black + gold grammar [S]); gold "PRO" plate; gold hardware | Heavy industrial gallows with red Neon strips | 3-step black stage, corner posts with red Neon caps, a **vertical fight-poster banner** behind | Stage + spotlight + first element (embers) | Slow sway; embers rise; floor emblem turns | **Ember burst** + camera micro-shake | Spotlight snaps on, crowd "ooh" sting |
| 8 | **Gold Bag** (20K, ×25) "Golden Wrecking Ball" | **Teardrop / wrecking-ball** 4.6 diameter × 6.5 (sphere silhouette = trophy) | Gold #FFC428 + highlight band #FFE882 + seams #D68C10; a **band of Neon diamonds** #AAF5FF; a small **crown topper** (5 wedges) on the swivel; gold chain | **White marble arch** #F4F2EC with gold caps (arch = gateway) | 12-sided marble dais with gold Neon rings + a **red carpet runner #C8102E with gold trim** (CoC TH10 [S]) | Gold + gems + halo + god-ray | Halo spins, gems bob, slow sparkle | **Coin burst** (gold discs, LightEmission 0.5) + "cha-ching" | God-ray switches on; gold confetti |
| 9 | **Champ Ring** (50K, ×40) "The Arena" | Raised ring (current), with truss + **bleachers** | Ropes hue-cycle; apron navy #1A2040; canvas #ECEEF4 with logo; corners red #E2383E / blue #3874E8 / white | Truss with **sweeping spotlights** (rotating SpotLights) | Ring + steps + 2–3 rows of **crowd** (Ball heads on block bodies in random accents, bobbing) + a "CHAMP" entrance lightbox | Arena: crowd + hue-cycle + sweeping lights + confetti | Belt hologram spins; camera-flash sparkles (random white Neon blinks) | Crowd "OOH!" + flash pops | Fireworks + walk-out music + name on a jumbotron (optional) |

Per-tier build notes [I]:
- **Tier 1.**
  - The lamp post doubles as a street prop, so the starter station looks like it belongs to the sidewalk, not the gym.
  - Keep it cheerful: the smiley face does the work.
- **Tier 2.**
  - Lean the body 5° and make its belly asymmetric: two offset Ball parts inside the cylinder.
  - The green zip ties are the first rarity color showing *on the bag itself*.
- **Tier 3.**
  - The tag can spell the player's crew name via SurfaceGui (a cheap personalization hook).
  - The street blades already exist in `Build.Street` [L].
- **Tier 4.**
  - This is the first "real gym" step and the first big size jump, so make it clearly fatter.
  - The poster board starts the backdrop channel that tiers 7–9 escalate (banner → arch → arena).
- **Tier 5.**
  - A speed bag is small by nature, so the **rig** (backboard + platform + clock) carries the scale and value.
  - Don't shrink the station.
- **Tier 6.**
  - The arch frame gives the first "doorway" silhouette. Electricity is the new element.
  - Beams are already in the code [L].
- **Tier 7.**
  - The banana shape is the payoff of the silhouette rule: tall, and unlike tier 4.
  - Embers and the stage are already in the code; the silhouette is the missing piece [L].
- **Tier 8.**
  - Swap the cylinder for a teardrop so the most valuable bag is the most **object-like** (trophy or ornament).
  - Halo, god-ray and gems are already built [L]. Add the crown, red carpet and arch.
- **Tier 9.**
  - The current ring is already strong [L]. Add a crowd, sweeping lights and an entrance lightbox so it reads as an **arena**, not equipment.
  - Belt colorway: an original design. A gold center plate with a strap in the current world's accent (Block #F2B632) borrows WBC-style flags-and-medallion grammar without copying any real belt [S].

Sound ladder [I]: rubber boing → tape slap → canvas thud → leather thump → rattle → zap → heavy thud + whoosh → cha-ching → crowd roar. Pitch and reverb rise with tier.

### Gaps

- I couldn't open any page or image, so every [S] item is a search-summary paraphrase. None of the hex values are measured from the referenced shows or games. All palettes here are my design proposals.
- I found no sourced description of how Roblox boxing or punch simulators style their bags tier by tier. The ladder above is inference from merge-game, Clash of Clans and Fortnite patterns.
- The milk-crate hoop, stoop clutter, sidewalk sheds and timer clock are common real-world sights, but I didn't verify them with sources this session.
- I didn't playtest anything. Check the size ramp and Walk-of-Fame layout against the Boxing Club floor (x −64..−24, z 4..44 [L]) and on a phone-size screenshot.
