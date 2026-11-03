---
tags: [miami-trap-life, design, research, property, pc, business]
updated: 2026-11-02
---
# Desk Computer Empire: the flat, the desk PC and the big businesses

Back to [[00 Master Plan]] · Quality bar: [[Studio Quality Playbook]] · UI rules: [[UI Art Direction - Lessons]] · Textures: [[Interior Textures]] · Story: [[01 Story Bible]]

**What Alex asked (Nov 2):** a fully modelled, good-looking, interactive flat with all the necessities. A desk PC that works like GTA's: a smooth sit-down, the camera moves to the screen, then a polished OS. From the PC, the big progression businesses: buying warehouses and other properties, trading meme coins on a market that changes every day, and running the trapping logistics. Gate them by level and by finishing earlier steps. Tie them to real places on the map so players move around. The 2x XP pass counts. It's going on TikTok, so it has to look like a studio made it.

---

## 1. Research: what the best versions do

### GTA Online, office PC (SecuroServ) and business laptops
- You walk up to the desk and get one prompt. The character pulls the chair out, sits and rolls in (about 1.5 s). The camera blends from third person to a desk view, and then the screen fills the frame as a full-screen fake OS. Exiting reverses the move.
- The OS is the business hub. You **buy** property (warehouses, bunkers), **start** source and sell missions, **assign** staff, and **watch** stock and value. The actual gameplay happens out on the map: you drive there, carry the crates and defend the delivery.
- The in-world monitor already shows the OS before you sit, so the room never has a dead screen.

### GTA Online, Special Cargo (warehouses)
- Three sizes: small, 16 crates (GTA$250-400k); medium, 42 crates (~GTA$1M); large, 111 crates (GTA$1.9-3.5M).
- **Sourcing** costs more per crate the more you take at once (1 crate GTA$2k, 3 crates GTA$18k), so it rewards the grind.
- **Selling pays more per crate the bigger the sale**: 1 crate GTA$10k, 42 crates GTA$17.5k each, 111 crates GTA$20k each. A full large warehouse pays double the per-crate rate of a single crate. This is the "bigger you expand, the more you earn" curve Alex asked for.
- Risk: rivals can hit sell missions, and NPCs raid a well-stocked warehouse. Bigger sales need more vehicles, so they carry more risk.
- Source: [gtaboss special cargo guide](https://www.gtaboss.gg/gta-5-online/guides/gta-online-special-cargo-guide)

### GTA Online, Nightclub warehouse (staff and passive income)
- Technicians are hired staff (each one costs more than the last) and each is assigned to one goods line. Every line has a unit value, a cap and a time per unit. A technician on a full line stops working, so players come back and reassign them. That's the re-engagement loop.
- Upgrades speed up production (equipment) or raise caps (storage floors). One "Sell all" run makes several drop-offs close together. The middleman takes a capped cut.
- Source: [gtaboom nightclub warehouse guide](https://www.gtaboom.com/gta-online-nightclub-warehouse-business-guide/)

### Meme coins in real life (pump.fun)
- Every coin has the same shape: 1B supply, 80% sold along a **bonding curve** (price rises as more is bought, so early buyers pay up to 100x less), 1% fee per trade, and "graduation" to a real exchange at about 85 SOL.
- **Fewer than 2% graduate.** About 70% die on launch day, and only about 5% are alive after 90 days.
- Rugs need no hacking. Insiders and the dev buy 20-30% of supply at the bottom (often in the launch block) and sell into later buyers. Graduation itself often triggers a sell-off (~80% in minutes).
- The signals real traders read are dev wallet %, top-10 holder share (>30% = fragile), holder growth (a steady climb is good, a spike then a plateau is bad), how full the curve is, and promos that come *after* the wallets already loaded up.
- Sources: [crypto.news](https://crypto.news/how-meme-coins-are-made-bonding-curves-pump-fun-rug-pulls/), [KuCoin: 70% gone on launch day](https://www.kucoin.com/news/flash/nearly-70-of-pump-fun-tokens-disappear-on-launch-day-80-gone-in-2-days), [Cryptobriefing: 5% survive 90 days](https://cryptobriefing.com/pump-fun-token-survival-rate-study/)

### Roblox hood games (Tha Bronx 3, Da Hood, South Bronx)
- Money comes in tiers: a safe grind job (construction: $1,200 per block at Level 12), mid-game dirty money (trap house looting, studio robbery at $3k / $7.5k / $16k by tier, with PvP and police risk), "card methods" for advanced players, and a crew-only bank job at the end. Dirty money has to be washed at a laundromat before you can spend it on big buys.
- What players love is the **visible tier jump**: a new method that pays 3-5x the last one and needs a tool, a level or a crew. What they hate is mop-job pay with nothing to unlock.
- Source: [Tha Bronx 3 money guide](https://tha-bronx-3.pages.dev/money/)

### Real-world distribution (kept abstract: Roblox rules ban drug content)
How small-time street distribution is structured, used only as **game structure**. In game it is always "packs" and "the re-up", never a substance (Master Plan open question 5):
- A **connect** sells in bulk (cheaper per unit the more you buy). The **stash** is never where you sleep and never where you sell. The bulk gets **broken down** into small units. **Runners** work corners in shifts and **lookouts** watch for police. Then you **re-up**.
- The risks are raids on the stash (more stock = bigger loss), robbery ("jacks") on runs and heat on a corner that sells too fast. Profit gets laundered before it can be spent.

---

## 2. Design pillars (every business follows these)
1. **The PC plans it, the street does it.** The PC is where you buy, order, assign and watch. Every unit of stock moves through a real place on the map: the Port, the warehouses in Wynwood, the corners in the Ends.
2. **Bulk pays.** Selling 40 at once pays more per unit than selling 1 at a time (the GTA curve), so expanding is always the better move.
3. **Passive needs you.** Staff and runners make money while you're away, up to a cap. You come back to collect, re-up and reassign.
4. **Risk scales with size.** A big stash, a big sale and a hot corner each carry a real chance of loss. Upgrades (lookouts, security) cut it down.
5. **Each tier is a visible jump** of 3-5x the last (the hood-game rule), and every one needs a level *and* something you did first.
6. **Everything gives XP through `EconomyService.addXP`,** so the 2x XP pass and boosts apply automatically.

---

## 3. The flat (Flat 3B, the Ends)

### Layout (room space: floor y = 0, door in the +Z wall, back wall at -Z)
The story points stay where they are, so the PowerOut and NextDay cutscenes still line up: ChairSpot (-6, 0, -6.4), Screen (-6, 3.55, -8.56), BedSeat (7.8, 1.05, -4.5), Exit (6, 0, 10.6), Breaker (11.6, 4.5, 10.75), Window (6, 6, -10.9), Bulb (0, 9.6, 0).

| Zone | Where | What's in it |
|---|---|---|
| Desk corner | back-left | Real desk with drawers, the PC (tower with a front LED, monitor on an arm, keyboard and mouse on a mat), an office chair that slides out, a desk lamp, a cork board (Royce flyers, a Liberty map with pins) |
| Bed | back-right | Starts as a mattress on pallets. Upgrades to a real bed frame with sheets, a nightstand, a phone charger and an alarm clock |
| Kitchenette | left wall, front | Counter run with a sink and tap, a 2-burner stove, a microwave, a fridge, a kettle and an overhead cupboard |
| Bathroom | through a door in the left wall | Shower with a curtain, toilet, basin, mirror cabinet and a towel rail. Tiled (MTL_WallTile) |
| Lounge | middle | A worn couch facing a CRT TV on a crate (upgrades to a flat TV on a stand), a rug and a coffee table |
| Entry | front | Door, breaker box, shoe pile, coat hook, a light switch and the stash floorboard |
| Wardrobe | right wall, front | Clothes rail and wardrobe (opens the outfit picker) |

### Interactions (each one is a ProximityPrompt + an animation + a sound)
| Thing | Prompt | What happens |
|---|---|---|
| PC | Use PC | Sit, camera to the screen, Liberty OS (§4) |
| Fridge | Grab a snack | The door swings open and you eat: +25 health, 60 s cooldown |
| Stove | Cook | 6 s cook with steam and sizzle: +60 health, 3 min cooldown |
| Sink / basin | Wash hands | Water stream particles and sound |
| Shower | Shower | Curtain closes, steam and water, fade: "Fresh" (+10% XP from jobs for 10 min, a small reason to come home) |
| Toilet | Use | Camera looks away, flush sound (the joke everybody clips) |
| TV | Watch TV | Sits you on the couch. VBX News loops headlines that hint at coin pumps (§6), so the TV is worth watching |
| Light switch | Lights | Room light on/off (once the power is on) |
| Wardrobe | Change clothes | Opens the outfit picker (Config/Outfits) |
| Bed | Sit / Sleep | Same as now (story) + sleep sets your respawn here |
| Window | Look outside | Camera through the window at the street |
| Stash floorboard | Stash | Unlocks with The Re-Up (§7.4): the board lifts, and you put packs and dirty cash in or out |

### Upgrades (bought from the PC's Home app)
- **As found** (the story start): trash bags, pizza boxes, cans, damp patches and the boarded window.
- **Clean up** ($400, Level 6): trash gone, stains gone, window un-boarded with blinds, a real bulb shade.
- **Fixed up** ($2,500, Level 9): fresh paint, a rug, a bed frame, a flat TV, LED strip behind the desk and plants.
- **Setup** ($8,000, Level 12): a dual-monitor gaming desk with an RGB tower, a gaming chair and a neon sign. This is the TikTok shot.
- Each tier is a folder in the room model (`Tier0`, `Tier1`...). The server shows the folders up to your tier. Story points never move.

---

## 4. The desk PC (GTA style)

### The sit-down (client, `Controllers/DeskController`)
1. **Prompt** "Use PC" (hold 0.25 s).
2. **Walk-up** (0.35 s): the character is moved to the chair's stand point, facing the desk (eased, never snapped).
3. **Chair out** (0.3 s): the chair slides back 1.2 studs and turns 15°.
4. **Sit** (0.55 s): `Rig` pose `SitType` blends in, the root eases down `_drop`, and the chair slides back in under you (0.35 s).
5. **Camera** (0.7 s, Quint Out): from the player camera to an over-the-shoulder shot of the screen. Then a **push-in** to the monitor (0.55 s, Sine InOut), with DepthOfField on the room and a FOV squeeze from 70 to 50.
6. **Hand-off** (0.15 s): the full-screen OS fades in over the monitor. It's the same wallpaper and layout as the in-world SurfaceGui, so it reads as the screen growing, not a menu popping up.
7. Keys clack while you click. The fan hums. Exit (the ✕ in the OS, Backspace or B) reverses it all: fade out, pull back, stand up and the chair returns.
- Mobile: the same, plus a big EXIT button. Reduced Motion setting: skip the push and fade straight to the screen.
- While seated the character keeps the typing pose. Other players (later rooms) see you sat typing.

### Liberty OS (client, `UI/Build/LibertyOS` + `Controllers/OS/*`)
- **Look:** Alex's palette (dark grey 24,25,29 panels, white text, green only on money, gold for level, soft blue 96,170,255 for selected), Oswald headings, Gotham body, 2 px corners, hairline borders and eased motion. No emoji as icons: each app gets a flat glyph built from frames.
- **Desktop:** wallpaper (the Liberty skyline at dusk), app icons in a column, a taskbar with Start, the open apps, the clock (world time), the cash and the wallet. Notifications slide up bottom-right ("Runner on 5th sold 6 packs · +$810").
- **Windows:** one app at a time, maximised, with a title bar (minimise to the taskbar, close). Fast app switching from the taskbar.
- **The in-world screen** shows the desktop live (clock, a notification count) whenever the power is on.

| App | What it's for | Unlocks |
|---|---|---|
| **Mail** | Royce, Dre, Rico and "Royce Properties" send mail that teaches each business (one email per unlock, with a button that sets the GPS) | Always |
| **Bank** | Clean cash, dirty cash (from the crime piece), business income history and a 7-day chart | Always |
| **Home** | Flat upgrades (§3) | Level 6 |
| **CoinBay** | Meme coin market (§6) | Level 8 |
| **Royce Realty** | Buy properties on a map of Vice Bay (§5) | Level 10 |
| **Freight** | Run your warehouses (§7.3) | Own a lockup or warehouse |
| **The Re-Up** | Packs logistics (§7.4) | Criminal + Level 12 + own a stash house |
| **Clipz** | Social media (the social thread owns it; the icon is here) | That thread decides |

---

## 5. Royce Realty (properties)
Royce owns most of the Ends (Story Bible §2). Buying from him is the story's point: you're getting rich in *his* book. Every property is a **real building on the map**, gets a map marker, and its listing has a photo, size, cap and price.

| Property | Map building | Price | Level | Needs | What it does |
|---|---|---|---|---|---|
| Ends Lockup | Garage row in the Ends | $25,000 | 10 | — | Freight: 12 crates |
| Stash House | Hood apartment block (-1300, -224) | $18,000 | 12 | Criminal | The Re-Up: 40 packs |
| Wynwood Warehouse | Wynwood.Warehouse (-491, -341) | $90,000 | 14 | 20 crates sold | Freight: 40 crates |
| Second Stash | Hood apartment (-1106, -640) | $45,000 | 16 | Stash House, 200 packs sold | +60 packs, a second runner base |
| Port Warehouse | Port.Warehouse (-858, 1024) | $240,000 | 20 | 100 crates sold | Freight: 100 crates |
| Habana Apartment | Habana block (-66, 562) | $60,000 | 15 | — | A better home with a PC |
| Brickell Penthouse | Downtown tower | $400,000 | 25 | — | Home with a dual-screen office |
| Star Island Estate | VBInteriors mansion | $2,500,000 | 40 | — | The flex: mansion, garage, office |

---

## 6. CoinBay (meme coin market)
- **One market for every server.** Coin launches, prices and fates come from a seeded generator keyed on real time (UTC), so every server shows the same chart at the same moment and friends can talk about the same coin. There's no player price impact (that keeps it exploit-proof), and positions are capped.
- **New coin every 6 minutes.** Names come from a hood/Miami meme list ("$PATEL", "$BIGBACK", "$SKRRT", "$CANALRAT", "$MANGO"...). Each has a generated logo (colour + glyph).
- **Every coin has a hidden fate** drawn from the seed, shaped on the real stats: about 55% rug or fade in under 10 minutes; 30% pump 2-5x then bleed; 12% run 10-30x; 3% "graduate" (100x+), get **listed** and stay tradable for the rest of the real day.
- **Signals make it skill, not gambling.** Every coin shows dev wallet %, top-10 share, holders (a live line), curve fill % and "Clipz buzz". Fate odds lean on the signals the same way they do in real life: high dev % and high top-10 share mean rug-heavy; a steady holder climb means pump-heavy. Players who read the signals win more than they lose. Players who ape everything lose.
- **The day matters.** Each real day has a market mood (bull / crab / bear) from the seed that shifts every fate. The TV news (VBX ticker) and Mail hint at it: "Analysts: degen season is back".
- **Blue chips:** three steadier coins ($LBTY, $VBX, $GOLDTEETH) do a daily random walk of ±3-12%. Somewhere to park money.
- **Caps** (to keep the economy sane): max per coin at Level 8 $1,000, Level 12 $5,000, Level 18 $20,000, Level 25 $75,000. 1% fee per trade.
- **Where the money goes:** buying uses clean cash. Selling goes to your CoinBay balance, and withdrawals land in clean cash instantly from the PC.
- **XP:** +5 per trade, +50 for a 5x, +200 for selling a coin before its rug candle (a "caught the top" toast).
- **The look:** a real candle chart (1 candle = 10 s), buy/sell with presets (25/50/100%), a live "trades" feed of fake wallets, and the TikTok moment: a 50x green candle with the cash count-up.

---

## 7. The businesses

### 7.1 Gates at a glance
| Step | Needs |
|---|---|
| PC works | Power bill paid (story) |
| CoinBay | Level 8 |
| Royce Realty | Level 10 |
| Freight (Lockup) | Level 10, $25k |
| The Re-Up | Criminal, Level 12, 10 crime jobs done (`Crime.Count`), own the Stash House |
| Runners | Level 15, 1 / 2 / 3 / 4 corners at Level 15 / 18 / 22 / 28 |
| Wynwood Warehouse | Level 14, 20 crates sold |
| Port Warehouse | Level 20, 100 crates sold |

### 7.2 Economy targets (per real minute, for tuning)
- First job: ~$27/min. Crime ladder: ~$100-250/min (Config/Crime).
- Freight lockup: ~$180/min active. Wynwood: ~$400/min. Port (full sale): ~$800/min.
- The Re-Up: one corner ~$120/min passive (minus heat), four corners + bulk sales ~$700/min.
- CoinBay: averages around zero for random buying and +20-40% per cycle for good signal reading, inside the caps.

### 7.3 Freight (warehouses; works on either path)
Grey-market imports (sneakers, phones, designer bags): the same goods the crime piece fences, but bought in bulk.
- **Source (PC → Port):** order 1-3 crates ($300 each, rising to $400 each for 3). A pickup appears at the Port of Vice Bay, the GPS is set and a crate van spawns at your warehouse. Drive to the Port, carry the crates into the van (the carry pose from the crime piece), and drive back to unload. ~3 min per run. +40 XP per crate.
- **Hire a sourcer** (Level 16): 1 crate every 6 min while you're online, up to the cap.
- **Sell (PC → buyer):** the bigger the sale, the more per crate: 1 crate $650, 12 crates $800 each, 40 crates $1,000 each, 100 crates $1,250 each. Drops go to real map spots (Brickell valet, the airport cargo gate, SoHo, Star Island). 1-11 crates is one van; 12-39 is 2 trips; 40+ is a box truck with 3 drops. +25 XP per crate sold.
- **Risk:** sales of 40+ crates have a 25% chance of an NPC hijack car on the route. If the crates are taken, you lose them. A warehouse raid can happen when you're offline and stock is at 80% or more (10% chance a day, lose 10%). The Security upgrade ($30k) halves both.

### 7.4 The Re-Up (packs logistics; Criminal only)
Plain brown packs and duffels in the world. Never named as a substance anywhere.
- **Re-up (PC → the Port docks):** order raw stock in bulk: 10 / 25 / 50 packs at $70 / $60 / $50 each. Pick it up from the Plug's container at the docks (a timed pickup with a 1-star heat chance), then drive it to the stash.
- **Bag up (at the stash):** a station minigame. Hold to weigh and seal, with a PERFECT window, 2 s per pack. Or hire a **cook-up crew** ($8k, Level 14): 1 pack every 20 s while you're online, up to the stash cap.
- **Move it:**
  - **Hand-to-hand:** stand on one of your corners. NPC buyers walk up and you do a quick handoff (prompt + swap animation): $110-150 per pack. Corner heat rises with every sale.
  - **Runners:** assign a runner to a corner in the PC. They take packs from the stash and sell 1 every 45-75 s ($120 each, 15% to the runner) until they run out. Dirty cash collects in the stash.
  - **Bulk buyer (Level 18):** a buyer wants 25+ packs at $135 each. Drive it to a meet (the motel, under the canal bridge).
- **Corners:** real street corners in the Ends and on NW 52nd, each with a demand meter (refills over time) and heat. The 52s' corners pay more but can start a turf beef event.
- **Risk:** a stash with 30+ packs and corner heat has a raid chance every 10 min. You get 60 s of warning ("Lookout: blue lights on 5th"). Get there and move the stock, or lose 50%. A **Lookout** ($6k) gives earlier warnings and half the raid chance.
- **Money:** all of it is dirty cash (Crime.Dirty). Wash it at the laundromat (crime piece), which pulls players back across the map.

---

## 8. Code plan (contracts other threads should know)
- **Config:** `Config/Flat.lua` (room tiers, interactions), `Config/OS.lua` (apps, gates, look), `Config/Coins.lua`, `Config/Freight.lua`, `Config/ReUp.lua`, `Config/Realty.lua`.
- **Rules (pure, tested with tools/tests):** `Rules/CoinRules.lua` (seeded market: launch times, price at time t, fate), `Rules/BusinessRules.lua` (sell curves, caps, gates).
- **Server:** `Services/DeskService.lua` (who's seated), `Services/RealtyService.lua`, `Services/CoinService.lua`, `Services/FreightService.lua`, `Services/ReUpService.lua`. Remote `OSAction` (rate-limited) for every OS button. The server re-checks everything.
- **Client:** `Controllers/DeskController.lua` (sit + camera), `Controllers/FlatController.lua` (room interactions), `UI/Build/LibertyOS.lua`, `Controllers/OS/{Mail,Bank,Home,CoinBay,Realty,Freight,ReUp}.lua`.
- **Save (ProfileSchema):** `Home.Tier`, `Home.Upgrades`; `Realty.Owned`; `Coins = { Balance, Pos = {[coinId] = {qty, cost}}, Stats }`; `Freight = { [propId] = { Crates, Sold } }`; `ReUp = { Stash = {Raw, Packs, Dirty}, Runners = {}, Corners = {}, Sold }`.
- **The room model:** `ServerStorage.MTL_FlatInterior` (PropertyService already prefers it), built by `tools/BuildFlatInterior.lua` so it can be re-run. No marketplace models: the props are built from parts with the vetted MaterialVariants (`MaterialService.MTL_Interior`, packs scanned with 0 scripts). Anything pulled from the Creator Store is scanned for `LuaSourceContainer` and named "Runtime" scripts before use.

## 9. Build order (each step play-tested with screenshots before the next)
1. The flat: modelled (Tier 0 story look + Tiers 1-3), lit, all interactions.
2. The desk sit + camera + Liberty OS shell (Mail, Bank, Home).
3. CoinBay (no map dependency, fastest to show on TikTok).
4. Royce Realty + Freight (the Port, the warehouses, the van, the sell drops).
5. The Re-Up (stash, bag-up station, corners, runners, raids).
6. Bigger homes (Habana, Brickell, Star Island) reusing the PC.

## 10. Coordination
- **Crime loop thread:** owns dirty cash, washing, heat stars and the carry pose. The Re-Up writes `Crime.Dirty` and raises heat only through CrimeService's API.
- **Phone thread:** the Money app lists the businesses (Config/Earn entries, kind = "Business").
- **Social media thread:** owns Clipz; the OS has its icon slot. CoinBay "buzz" can read Clipz posts later.
- **Quality thread:** the room, the sit-down and the OS go through the Studio Quality Playbook checklist.
