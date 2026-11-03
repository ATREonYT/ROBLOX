# Hood-game benchmark analysis: Urban Reload, OPPS, BlockSpin

Sources: 170 video frames, 3 animation bursts at 8 fps, 8 auto-transcripts (the other 9 were blocked by YouTube rate limits), and Roblox store data pulled 2026-11-02. Frame files are named `<folder>/<videoId>_frameNN.jpg`. **Seen** means visible in a frame. **Said** means it comes from a transcript. Anything not marked is inference.

---

## 1. Urban Reload (Squad Labs): tactical PvP in grey New York

**Store:** 11,710 playing, 8.3M visits in 4 weeks (created 2026-10-05), 85.4% likes, 20-player servers. Pitch: "Tactical PvP in a city where every street is a fight… You lose your weapons, so play smart… Realistic guns, attachments and rare camos."

**Core loop:** spawn → fight players or farm NPC zombies for cash → spend cash on weapon cases → fight with better guns. Fighting is the economy.
- **Kills pay.** Said: "Knocking an enemy down isn't enough. You need to finish them to receive money." Seen: "+$2,500" per player kill, "+$3,250" for a loot kill, "+$960" / "+$5,680" for zombie kills.
- **Farm Zone:** a walled area with NPC zombies and its own skull-icon map marker. Seen: "Vehicles aren't allowed in the farm zone" and "Press [E] to loot" over bodies. One video is literally titled "AFK ZOMBIE GLITCH (Free in-game money)".
- **Starting cash:** $15,000. Seen money ranges from $15k for a beginner to $9,092,650 for a grinder.
- **No jobs** and no robberies seen. It is a pure PvP/PvE gunfight game.

**Death:** knock-down → finish system (downed state first). Seen: ragdoll death with the body crumpled on the pavement. On death you drop your weapons and looters take them ("You can loot their guns"). Case UI says: "You drop it if you die in combat unless it is in a protected slot." **Safe:** a "Safe" inventory window with "YOUR ITEMS" (13/50) above a protected SAFE grid (drag to store). A cash bag goes into protected slots. "+10 Safe" is a game pass.

**Cars:** a blue hatchback starter (Fiesta-like), a white Peugeot-style hatch, a purple Porsche Cayenne, a yellow Lambo ("I PACKED THE LAMBO"). You get cars from the hotbar: slot 5 is your car and you spawn it from there. **Garage** (French-language video) has categories for Paint (Peinture: Noir, Brillance bleue/verte/violette…), Wheels, Neons ("Néons $150,000"), Headlights ("Phares avant $100,000"), Spoilers, Horns and Suspension. Loot-box odds are shown right in the garage: Yellow/Ice Blue 26.46% (common), Xenon/Green 14.81%, Red/Purple 7.41%, Pink 2.65% (legendary). Said: "You can… eliminate enemies by running them over. However, vehicles aren't indestructible." Lock/unlock icon on the left when near a car.

**Guns:**
- Seen: AK/AR rifles, an M4, an M60, a SPAS-12, an SMG with a grenade-launcher-style attachment, a pistol, melee (Baseball Bat, Baton, Brass Knuckles).
- **Weapon Cases $5,000–$30,000** in three tiers (Basic / Normal / Legendary). Basic Case = $5,000, with odds listed (Baseball Bat 10.426%, Baton 10.425%, Brass Knuckles 10.425%…).
- Camos: gold, leopard, flame and galaxy-purple skins. Attachments: optics, foregrips, lasers (green and red laser lines visible).
- Ammo shows under the hotbar slot (30/30, 45/45, 60/60) plus a big "30 / ∞" reserve count at bottom right.
- Kill feed top left (red/blue names, "X killed Y"). Kill-streak popups: "DOUBLE KILL", "PLAYER KILLS 19/1,000".
- Tracers: a coloured beam per shot (green, red, purple). Big orange-yellow muzzle flash.
- Said: "carry med kits to restore your health… behind cover". Medkits and Kevlar are hotbar items, plus a purple "E-Drink" consumable.

**Movement:** sprint (blue stamina bar under health), crouch, **roll**, climbing buildings. Said: "Rolling is especially useful for dodging enemy damage, while crouching and climbing buildings can help you change your position." There is a "movement player" meta: video titles include "FAST 3KD MOVEMENT Player", "MOVE LIKE A DEMON", "Movement Player Unlocks Tier 2". The settings video shows players raising the max frame rate to 240 FPS and changing camera sensitivity and mouse DPI for movement.

**Animations: the best of the three.** (`urban-reload/anim/KnBi15zsgz4_*`)
- **Split body.** The lower body plays run/strafe in the movement direction. The upper body twists toward the camera aim, so the rifle stays on target while running sideways or backwards. This is procedural (Waist/Neck Motor6D rotated per frame toward the camera), layered on the locomotion clip.
- **Custom deep crouch-run.** Knees bent, wide stride, torso pitched forward. A **high-ready pose** (rifle vertical, muzzle up) while sprinting and a **two-handed shoulder hold** while firing. Players with pistols run with the gun held low and pointed forward.
- Over-the-right-shoulder camera, close in combat. R15 with realistic body packages and layered clothing (crop tops, cargo pants), which makes the motion look smooth.

**HUD:**
- Money top right in a dark box with a green border ($ in a white serif font). Under it a red heart + health bar (150 HP), a blue stamina bar, and a red skull + streak count.
- Compass strip top centre (N/NE/E with degree ticks and event markers). Kill feed top left. Small Roblox topbar icons plus a "Wardrobe" button top left.
- Bottom centre hotbar: 5 square slots numbered 1–5 (fist, primary gun with ammo, E-Drink ×5, Kevlar ×1, Medkit ×1/×3, car). Rarity-coloured backgrounds: purple/violet, and gold for the equipped gun.
- Right edge: a column of small icon buttons (inventory, Shop, Effects; later Crew, Clan, Emotes, Event) with keys J/K/L and red notification badges.
- Bottom left: "Hold ALT to free your cursor and click on menus." Ammo bottom right. Green "SAFE ZONE" pill top centre in shops.
- The fonts are a serif display face (old-style numerals), which looks like a "premium" mobile-shooter style.

**Menus/shops:** a dark purple/black Shop panel with tabs (SHOP / EFFECTS). INSTANT CASH dev products: **$1,000,000 for R$1,499, $10,000,000 for R$6,999, $100,000,000 for R$29,999**. There's a "Support creator code" field. Weapon-case kiosk (green). Garage (dark panels, teal cards). Halloween Event panel with tiered rewards.

**Lighting/time:** day is grey overcast NYC with flat light and autumn trees. Night has strong blue ambient plus neon signs (DINER, MOTEL, URBAN RELOAD billboard). During the Halloween event the sky turns pink/magenta with orange foliage. **Map:** New York: elevated subway tracks, brownstones, a 50s chrome diner, a motel, a used-car lot, docks, a tunnel, warehouses with roll-up doors, a park with a checkerboard plaza, a pawn shop, a gun store and a gravesite. Dense and grungy, with realistic textures (brick, chain-link, graffiti).

**Social:** Crews (create costs Robux, R$299 pass), Clans (R$499), Crew + Clan bundle (R$799), and clan leaderboards. Said: clans are "especially useful if you want to compete for higher positions on the leaderboards." Crew tags show in names, e.g. "[UWU] Miami", "[SKY] SKI".

**Events:** Halloween Event (ends in 6d 21h). Tier 1 quests: **Ghosts 10/10** (hidden around the city), **Pumpkin zombies 150/150** (pumpkin heads only), **Player kills 250**. Rewards: **Grim Reaper skin**, then Shadow Grim Reaper, then Inverted Grim Reaper. Said: "I can tell I'm excited about this update and I can't wait to use the skin." Map decor: pumpkins, bats, cobwebs, bunting.

**Monetization:** passes Starter Pack R$99, Skip case animation R$499, Crew Create R$299, Clan R$499, Crew + Clan R$799, plus +10 Safe and Beta Pack (both off sale). Instant cash dev products from R$1,499 to R$29,999. Cases are paid with in-game cash. **What players love:** the movement/PvP skill ceiling (montages, "3KD" titles), and controller support ("URBAN RELOAD ON CONTROLLER 🎮 INSANE MONTAGE").

---

## 2. OPPS (#1 Hood group): a LA hood sandbox with a YouTuber cast

**Store:** 279 playing (peaked with YouTuber launches, 3.7M visits since 2026-08-14), 79.4% likes, 50-player servers. Pitch: "open-world city adventure… PvP battles… Train your character and unlock new abilities… Customize and upgrade your vehicles."

**Core loop:** tutorial job (janitor) → buy a gun → rob/kill players for their drops → store loot in a rented house's safe → craft/upgrade. It is very social: launch videos are YouTubers (ProjectSupreme, Racks, Voice) hunting each other.

**Money:**
- **Janitor job:** mop puddles. Said: "Did we just get paid $7, bro?" Two puddles per task.
- Killing and looting players. Said: "they got 500,000 off of me". Robbing stores: seen "The convenience store is being robbed."
- A pawn shop. Fishing (Silver Fishing Rod craftable at the crafting bench). Shootable loot sleds/crates in the street ("Keep shooting at the legendary loot", the "Large Crate" sleigh).
- Seen money: $67 → $9,590 → $1.99M.

**Jobs:** janitor (tutorial), plus a "Crafting Bench" (Silver Fishing Rod = Wooden Rod + Magnet + Silver). Cop role exists ("I BECAME A COP IN ROBLOX OPPS"). Asimo Jewelers is a robbery location. The world map also has a briefcase icon, a jewelry store, a gas station and a hospital.

**Death:** you drop your loot. Said: "All right, we lost all our loot." Death screen: "Killed by <name>" + **"Get Revenge?" button (Glock + 20 Ammo, Robux)** + red "Respawn". Said: "Revenge pack. 27 Robux. Dang, that's kind of cheap. Let me get that." Combat-logging rules apply.

**House/safe:** rent a house for $100. Said: "$100. Oh, I just got it… You can repair your guns. That's dope. All right, safe. Let's put all these up." The house has a safe plus a gun-repair bench. Guns have **durability** (coloured ring around each hotbar icon).

**Cars:** **car crates** at the dealership ("Rick Motors"): Basic (Trackhawk best), Rare (Hellcat / Scat Pack), Elite (Lamborghini, McLaren). Said: "it takes 25, gang. It took all my money… A low rider… The Low Rider is the worst one." Also seen: a Charger, an Escalade-style SUV, a Ferrari, a white 60s Impala. Cars can be locked, and there's a "No Car Cooldown" pass. Said: "This car is literally one shot" and "Why is this car so strong?" Damage balance is inconsistent. Seen: a speedometer bottom left in MPH ("70 MPH") with lock/horn/headlight icons. Drivebys are core: "We doing drivebys."

**Guns:** gun shop with a **restock timer** ("Restock in 11:23") and stock counts ("x9 Stock").
- **Dual pricing: Glock R$59 or $900; P226 R$69 or $900; Revolver.**
- Said list: Glock, revolver, Draco ("the Draco on sale"), MP5, AK-47 with skin, shotgun, sniper, crossbow (arrows), RPG. "We got a flamethrower" coming.
- Ammo types: pistol, rifle, shotgun ("Shotgun Ammo Epic $350", "Explosive Ammo Legendary $1,500"). Bulletproof vest. **Skin crates** (gifted). Ammo crates.
- Hit feedback: red damage numbers and blood splats. Seen: "+ Uzi / +1 Trinket / + Large Ink" loot toasts.

**Movement:** sprint with stamina. Said: "Oh, I'm out of stamina. Oh no." Hide in bushes ("Hide in the bush. They're not going to see me"). No crouch/slide visible.

**Animations:** the run looks like stock R15 and guns use a basic tool hold. Seen in the 8 fps burst (`opps/anim/QKjJHRGLGNM_run_*`): a standard arm-swing run with no custom stance. "Sliding" in transcripts is slang (to "slide on" someone means to attack them), not a mechanic.

**HUD:**
- **Very minimal.** Money top right in a small green pill (cash icon), with two tiny circular status icons under it (stamina, armor).
- Bottom centre hotbar of small **circular** slots with a coloured durability ring around each icon, numbered 1–4.
- Left side 2×4 menu grid with labels: ITEMS, QUESTS, SKILLS, CREWS, STORE, EMOTES, SETTINGS, CODES. Icons are glossy/3D (fireball, flag, blue box, dancing figure, gear, gift), with red notification dots. A single square "menu" toggle button.
- Floating 3D waypoint icons over the whole city skyline (shops, gas, hospital). Bottom-right row of small icons. Player nametags show "@handle / Name / Lv. 0".
- Modern clean sans font (Gotham-like). Settings menu: Radio Music, Low Graphics, Waypoint Icons, Reduced Motion toggles.
- Items window: rounded dark-grey panel, "Items 14/15", circular item tiles with ×counts.

**Menus/shops:** the gun shop is a red/black panel with weapon cards (rarity: Uncommon), a purple Robux price and a green cash price. Ammo panel is the same style. Crate reveal is a full-screen item reveal ("Pistol Ammo ×50", Skip). Crews: create one with a colour picker; costs Robux. Emotes have to be bought.

**Lighting/time:** **Future lighting** with long hard shadows, haze/atmosphere and a full day-night cycle (purple dusk, dark night with street lamps). Realistic PBR asphalt with road markings, crosswalks and arrows. **Map:** Los Angeles: palm trees, strip malls, Fuel Up gas station, Asimo Jewelers, Ammo City, Rick Motors, motels, overpasses, beach. Large ("I didn't even know the map was this big").

**Characters:** classic Roblox avatars (blocky, players' own outfits) with shields over the head in safe zones. **Social:** crews (Robux to create), voice chat central ("Voice"), safe zones ("You are now protected by a safezone"), YouTuber "owner" storylines. Said: "This game is actually one of the best hood games out on Roblox right now", "I'm loving it, bro". Hate: getting sniped ("this sniper is putting in some work"), cars one-shot, getting "back doored".

**Monetization:** passes Toy Bundle and No Car Cooldown (both off sale now). Guns for Robux (R$59–69). Revenge Pack R$27. Starter pack ("starter pack. Yeah, we're buying now"). Car crates. Skin crates. Paid emotes. Paid crew creation. "Crash out deluxe servers" (private-server upsell).

---

## 3. BlockSpin (Cinnamon Go!): the market leader, a GTA-lite life sim in Florida

**Store:** 24,772 playing, **1.33 BILLION visits**, 1.0M favorites, 78.8% likes, 28-player servers, live since 2024-11. Pitch: "Grind your way through jobs to unbox random reward cases… You drop everything in your inventory on death, place items into the safe in your house." New-player code W7C28D gives $500.

**Core loop:** job → cash → cases (guns/cars) → house + safe → PvP/robbery → repeat, with **skills** (XP per activity) gating better tools. Said: "it's literally GTA but on Roblox."

**Money methods (with numbers):**
- **Jobs:** Janitor ("$9–$18 per puddle"), Shelf Stocker at Quick-11 (seen "+$770", "+774 Shelf Stocker XP", "Complete in 5.24 seconds"), Burger Spot, and more. Said: "the more you run you just gain XP… you can become a level one janitor."
- **ATM hacking:** "shady dude in the alley" behind the Butcher Cut sells a **Basic Hack Tool $10 → Pro Hack Tool $150 → Ultimate** (gated by level). Seen: Quick-11 counter sells Basic Hack Tool $10, Shiesty (mask) $200, Pro Hack Tool $150.
- **Farming** (the meta). Rent a house (now free), buy soil and seeds at Jack's Hardware, plant in pots.
  - **Sunflower:** water once, 15 min, **$800/plant**.
  - **Corn:** 1 hour. **Tomato:** 24 hours.
  - Golden pot +40%, diamond pot +70%, premium soil stacking to +90% with 50% water retention. "six diamond pots and six golden tomatoes with premium soil will earn you about $90,000 per plant." BlockSpin+ multiplies by 1.5.
  - Farming Skill level 40 unlocks Organic Fertilizer (−30 min), level 45 unlocks +1 pot slot. Said: "I used just sunflowers to climb from level one to level 70 in one week."
- **Multiplier boxes** in the Quick-11 basement: golden 25× (6-hour cooldown), electronics 5×, sunflower 3×.
- **"Swiping"** (card fraud mechanic): "Those 500 quantums… can get you over $500,000 extra dollars a day… I've earned over a million a day."
- **Bank vault robbery:** seen a vault with cash on the floor and a "MONEY: $167,955" ticker.
- **Airdrops:** "Large Crate will drop by the Graveyard in 60 s".
- Fishing (said: "Fishing… There's tunas and everything").
- Pawn shop: "you can literally sell anything." Players carry $8 to $983,575.

**Death and storage:** Said: "when your combat's logged and you die you will lose all your items… but if you're not and you haven't been attacked then you can join a new server… and you'll keep all your stuff." Vehicles are permanent and never dropped. **House:** rent from the "For Rent" mailbox ($250, later free). It contains a **safe** (Items 1/17 ↔ Safe 7/11, upgradable to 15/18 and 22/23) and a **workbench to repair durability**. The safe can store vehicles too. The **mansion** game pass adds lockdown and **security cameras** (seen: camera-view UI with ◀ ▶ arrows). Said: "Not only can you lock it down like it's the freaking purge, but we also have security cameras." Trap houses: "They can break your windows, kill you while you're AFK." On death the loot spills out as floating icons with stack counts (×8, ×16, ×17). Bank withdraw is an ATM UI with a slider ("Retirar dinero / Cantidad $10").

**Cars:**
- Car crates at the dealership: basic **$540** ("Rusty ass car"), rare, elite.
- Starter vehicles are a **mobility scooter** (literally an old-person scooter) and a yellow ATV/quad, then Mustangs, a Lamborghini Urus, a humvee and a Rolls-Royce Cullinan.
- **Handbrake drift with heavy tyre smoke** (Space = Handbrake). Speed shows as a number at top centre (79). Lock and horn buttons. Steal-able cars: "did this guy just take my car… you can lock your car".
- Halloween **car wraps** from cases: Body Wraps+ case $25,000, with odds Wraithfire 1%, Witching Hour 3.5%, Monster Mash 4.5%, Ghost Runner 6%, Pumpkin King 12%, Vampire Bite 15%, Widow Web 17%, Bone Collector 19%, Toxic Drip 22%. Robux wraps Sunset and Haunted Red. Underglow neon.

**Guns:** **5 weapon crates** at the Patriot Gun Store, with odds shown. Legendary case: **AWP 0.051%, Anaconda 0.067%, M16 0.496%, RPG 0.683%, AK47 1.192%, AUG 1.192%, Remington 1.59%, Crossbow 2.088%, Tactical Axe 3.424%, MP5 3.646%, Tactical Shovel 4.03%, Tactical Knife 4.864%, M24 6.076%.**
- Also: Uzi, M249 ("RAREST M249"), M60, Glock, Draco, double-barrel, RPG, plus melee (knife, axe, shovel, wrench, bottle).
- Ammo crates (10/50/100 pistol bullets). Durability, repaired at the workbench.
- Red hit markers, red damage numbers, a red hurt vignette. Ammo shows next to the crosshair ("22/30") and under the slot.
- **Alt Aim (Q)** probably switches shoulder (inferred from the name). Bottle as a throwable weapon ("buying like 25 of these… start throwing them at people").

**Movement:** LShift sprint (**stamina**: Bull Energy $40 = +40 stamina and a speed boost; "+70 Stamina" popups), C crouch. Said: "every time I run it was just me like… breathing hella hard" (heavy breathing SFX when sprinting). Climbing ladders and rooftops. Said: "hopping in the window seal".

**Animations:** blocky R15 with a simple two-handed hold. Aiming zooms the camera over the shoulder, and Q is "Alt Aim" (probably a shoulder swap). Sprint has a forward lean, crouch-walk is low. Store copy promises "unforgettable finishers" (execution animations). Seen: punch/finish on downed players with blood splats. Players say "finish him" constantly, so there is a downed state before finishers.

**HUD:**
- Money top right: a **big cash-stack icon + white bold $ figure in a dark rounded box with a green rim**. Green health bar and blue XP/stamina bar under it.
- Right side 2×4 grid of 3D icons: Items (blue gem), Skills (chevrons), Quests (!), Store (red), Crews (green), Emotes, Codes (barcode). A colourful 4-square menu toggle.
- Bottom centre: small square hotbar slots (fist, gun with ammo, consumables).
- **Bottom left: a contextual keybind list** (LShift Sprint · Mouse Button 2 Aim · Q Alt Aim · R Reload · C Crouch; in a car: Spacebar Handbrake · E Exit Vehicle).
- "In Combat" skull bottom left of the hotbar. Toasts at the bottom ("You're now protected by a safe zone"). Fonts: bold chunky sans for money, a blackletter/serif display font for panel titles ("Items", "Safe", "Quick-11", "Farming Skill").
- Some players turn on Roblox performance stats.

**Menus/shops:** chunky rounded panels, dark grey with green buy buttons and red ✕ close circles. Clothing store (free): Hat / Shoes / Top. Barber (free) with named cuts ("Boosy fade", "klock dreads"). Hospital blood bags ($100, +50 HP). Quick-11 sells Bottle $10 and Bull Energy $40. Case-buy popup ("Buy Case?" plus an odds list). Item reveal on a pedestal.

**Lighting/time:** bright Florida daylight, soft shadows, haze, sunset orange skies, dark nights with headlight cones. **Materials:** clean modern white stucco, glossy floors, PBR asphalt with skid marks, lush grass. **Map:** suburban Florida county: modern mansions, beige houses, Quick-11 gas station, Patriot Gun Store, Butcher Cut, Burger Spot, hospital, bank vault, pawn shop, graveyard, sewers ("Randy, how you die in the sewers"), dealership, beach road.

**Characters:** players' own blocky avatars (bandanas, "Shiesty" ski masks, cowboy hats). Nametags are faded grey text.

**Social:** crews, "land fights", groups of 3–4 players with voice. Said: "Don't kill RP" (RP = RPG holder, i.e. the players who carry RPGs). Trading ("TRADING FROM UZI TO ANACONDA"). Level badges ("I'm level 90").

**Events:** Halloween update: Body Wraps+ and Halloween cases, Pumpkin Bombs, a "Pumpkin Smasher" quest (smash 25 pumpkins → $10,000 + 5 Pumpkin Bombs), and new weapons.

**Monetization:** **no game passes listed via the API** (they sell through dev products and the Store menu). BlockSpin+ subscription (1.5× earnings), Mansion pass, Robux car wraps, explosives bundles, underground mansion ("Mansión subterránea"). Cases are paid with in-game cash. **What players love:** the "GTA on Roblox" feel, the farming grind ("best money-making strategy"), high-stakes loot ("Stealing 110+ Legendary Guns"). **What they hate:** exploiters ("always exploiters roaming around", "He's cheating, bro"), being killed while AFK, lag, wall exploits at ATMs.

---

## 4. Comparison

| | Urban Reload | OPPS | BlockSpin |
|---|---|---|---|
| Players now / visits | 11.7k / 8.3M (4 wks) | 279 / 3.7M | 24.8k / 1.33B |
| Likes | 85.4% | 79.4% | 78.8% |
| Server size | 20 | 50 | 28 |
| Setting | grey NYC, El train, diner | sunny LA, palms | Florida suburbs |
| Avatars | realistic R15 bodies + layered clothes | classic blocky | classic blocky |
| Core money | PvP kills (+$2,500) + zombie farm | janitor ($7), robbing, looting | jobs, farming ($800–$90k/plant), ATM hacking, swiping |
| Jobs | none | janitor, cop, crafting | janitor, shelf stocker, burger, farming |
| Crime | PvP only | store robbery, jewelers | ATM hacking, bank vault, swiping |
| Death | knock → finish, drop guns | drop loot, Revenge Pack R$27 | drop all items if combat-logged; vehicles kept |
| Storage | Safe (13/50, protected slots) | house safe ($100 rent) + repair | house safe (11→23 slots) + workbench + mansion cameras |
| Gun source | cases $5k–$30k | shop (cash or R$59–69) with restock | 5 cases with posted odds (AWP 0.051%) |
| Gun extras | camos, attachments, lasers, tracers | skins, durability, ammo types | durability, ammo crates, throwables |
| Cars | spawn from hotbar; garage neons $150k, odds-based paint | car crates (Trackhawk → Lambo) | car crates from $540; scooter start; drift smoke; wraps |
| Movement | sprint, crouch, roll, climb (skill meta) | sprint + stamina | sprint + stamina drinks, crouch, Alt Aim |
| Animation | custom: split-body aim, tactical crouch-run, high-ready | stock R15 | simple custom hold + finishers |
| Camera | tight right-shoulder | 3rd person default | 3rd person; over-shoulder on aim, Q = Alt Aim |
| HUD money | top right box, serif font | top right small green pill | top right big cash icon, bold |
| HUD menus | right column of icons | left 2×4 grid with labels | right 2×4 grid with 3D icons |
| Keybind hints | "Hold ALT to free cursor" | none | full contextual list bottom left |
| Minimap / nav | compass strip top | floating 3D waypoints | none (event markers) |
| Lighting | flat overcast / neon night | Future lighting, hard shadows, haze | bright, soft, sunset/night |
| Social | crews R$299, clans R$499, leaderboards | crews (Robux), voice | crews, trading, levels |
| Event | Halloween tiers (Grim Reaper skin) | — | Halloween wraps + pumpkin quests |
| Monetization | passes R$99–799; instant cash R$1,499–29,999 | guns for Robux, revenge pack, car crates | BlockSpin+ (1.5×), mansion, wraps, dev products |

### Takeaways for our game
1. **Copy Urban Reload's gun feel:** a split-body aim twist, a tactical crouch-run, high-ready when sprinting, a tight shoulder camera, tracers and a big muzzle flash, kill-streak popups, and kill money paid only on the finish.
2. **Copy BlockSpin's economy depth:** several jobs with XP skills, farming that grows offline, ATM hacking tiers, house safes with slot upgrades and a repair bench, cases with posted odds, vehicles that are never lost, and a contextual keybind panel.
3. **Copy OPPS's look:** Future lighting, haze, day-night, floating waypoints, and a clean minimal HUD. Its weak spots (stock animations, one-shot cars, a sparse economy) are what made it lose players after launch.
4. **Avoid:** pay-to-win gun Robux pricing (OPPS), and exploitable AFK farming and wall exploits (BlockSpin, Urban Reload zombie glitch).
