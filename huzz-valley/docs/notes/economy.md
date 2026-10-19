# Economy: coins, Aura, shop, wheel, quests, cosmetics, crates, admin

Read before touching prices, the shop tabs, Aura stars, Spin the Wheel, quests, cosmetic slots, rewards, crates or
the admin panel. Round pay and XP: [round.md](round.md). Knife skins and Game Pass knives: [knives.md](knives.md).
Purchases follow the root `CLAUDE.md` rules (one ProcessReceipt in `ShopService`, never invent IDs, "coming soon"
while `Id = 0`).

## Coins and the shop
- **Coins** buy looks in the Shop's ITEMS tab (`Config/CoinShop`: trails, name colours, knife skins). Items with
  `Unlock` (quest knives) or `NotForSale` (Spin Knife) are never sold.
- The COINS tab sells coin packs for Robux (cards after the Oct 17 mockup, `docs/previews/coins-vs-mockup.jpg`; art
  cut by `tools/icons/make_screen_art.py`, placeholders until sharp PNGs); its buttons keep the Robux mark, never a
  coin icon.
- Shop passes copy the owner's banners: [ui.md](ui.md). Shop > PASSES opens on the knife pass cards: [knives.md](knives.md).

## Aura stars
- The owner's star art in `design/aura`, packed `AuraStar` + white `AuraStarWhite` for tinting.
- Float only in the playing zone (map Middle, outside ZoneA/ZoneB: `MapService.playSpot`) while a map is loaded, none
  between games; **run through one to collect** (server checks distance 10x a second). Only runners pick them up in a game.
- Blue 1 (40%), Green 2 (25%), Purple 3 (16%), Pink 5 (10%), White 10 (6%), Rainbow 25 (3%); rarer stars are bigger
  and brighter. The Aura "+" buttons explain it.
- Collecting one pops a "+N" in the star's colour where it was (HV's gems) with a soft burst everyone near sees
  ("AuraCollected" goes to all clients with the collector's id); no toast. Light 0.6+0.15t / 6+t
  ([look-and-lighting.md](look-and-lighting.md)).

## Spin the Wheel (`Config/SpinWheel`, `Shared/SpinRules`, `HuzzServer/SpinService`, `Screens/SpinWheel`)
- A real free spin every 15 min; packs of 1/10/100 for 48/340/1200 Robux (Developer Products, Id 0 until the owner
  creates them, granted only in ShopService's ProcessReceipt).
- Odds shown: 100 coins 28%, 250 coins 22%, 25 Aura 16%, x2 Coins 15 min 12%, 500 coins 10%, 60 Aura 7%, 1,000 coins
  4%, Spin Knife 1%; a Legendary is guaranteed by spin 40 (pity shown where the reference had a fake "daily discount").
- While an x2 Coins boost lasts, a green "x2 COINS 12:33" tag sits over the HUD coin pill (`LobbyHud`, from the saved
  `Boosts.Coins` end time).
- Opens from the owner's wheel model (name contains "spin" + "wheel", or tag `HuzzSpinWheel`), the SPIN button or the
  FREE SPIN lobby prop ([lobby.md](lobby.md)). Spec `tests/SpinWheel.spec`.

## Lore quests (`Config/Progression.Chapters`)
- 4 chapters x 2 quests with a story line, opened in order (server-checked; a chapter opens once ONE quest of the
  chapter before is claimed). Rewards: coins, Aura and three quest-only knives (Rookie, Hunter, Moonlit). Stats from
  real events: Rounds, Crossings, AuraStars, Heroes, Rescues, Catches, HoldSeconds, Wins (`ProgressService.addStat`).
- Not done yet (need screens): a dot on Menu when a quest can be claimed.

## Cosmetics and rewards
- **Cosmetic slots** (`CoinShop.Slots`: Trail, Tag, Knife, Aura, Title, Pose, Outfit; read with `CoinShop.worn(data,
  slot)`: `""` = taken off on purpose, nil = an owned Robux cosmetic of that slot is worn). Robux cosmetics carry
  `Slot` in `Config/Products`.
- **Rewards** (`Earn` items, Price 0): Secret/Mythic/Legendary girls give a title, aura and trail; Girl Collector, Huss
  Hero, Guardian from stats. `RewardService.sync` grants them (never over a paid look).
- Worn auras: `AuraLook.worn` (their look: [effects.md](effects.md)); Crown Pose: `Shared/CrownPose` +
  `Gameplay/CrownPose` (cooldown); Midnight = tint + cape. Not seen in Studio yet: Crown Pose, Midnight cape, worn auras.

## Crates (`Config/Crates`, `Shared/CrateRoll`, ActionService `OpenCrate`, Shop > CRATES, `Screens/CrateOpen`)
- **One live crate, Claude's first pick** waiting on the owner's own crate design: the **Starter Crate**, 50 Aura, only
  things that already exist: 150 / 400 coins, coin shop looks (Rusty Shiv, Box Cutter, Pink Name, Jade Kunai, Mint
  Trail, Thunder Fang, Ocean Trail, Candy Trail, Storm Kunai, Void Fang, Galaxy Trail) and the Robot dance. Common 50%,
  Uncommon 27%, Rare 15%, Epic 6%, Legendary 2% (Void Fang 1%, Galaxy Trail 1%); a Legendary at the latest on the
  30th open. A look you own already pays coins back by rarity (50 / 100 / 200 / 400 / 1,000). No Dance Pack dances
  (the pass sells them), no rewards, pass, quest or wheel prizes. Aura is only earned, never sold for Robux.
- **The server decides first:** `OpenCrate` takes the Aura once, rolls with the shown odds and pity, gives the prize
  and answers `{ index, name, rarity, new, coins, pity, left, strip, at }`. `strip` is the reel: 48 honest draws with
  the shown odds (never pity, nothing planted next to the stop: `CrateRoll.strip`, spec checks the cards beside the
  stop are Legendary only at the real rate), the prize on card 40.
- **Shop > CRATES** (a 5th tab): the crate card (drawn crate, "GUARANTEED LEGENDARY in N opens" + bar from the save,
  OPEN 50 with the Aura star) and every item's exact chance in two columns. OPEN is refused in a round or the Secret
  cutscene ("Open crates in the lobby.") and with too little Aura.
- **The opening** (`Screens/CrateOpen`, 1280 x 720 like the Spin wheel, one RenderStepped loop on its own clock, so
  the film matches the game): crate shakes harder 0.6 s, lid pops off with a green ring and sparks; the reel opens and
  spins 5.2 s (ease-out, quartic) under the green marker, `spin_tick` per card (max ~22/s), green light behind it;
  lands (prize card lifts, others dim, `spin_win`, Epic+ `spin_big_win`); the prize zooms up with a rarity halo, rays
  (Rare+, a second layer Epic+), one soft flash (Epic+, at most once a second), a spark burst and two rings
  (Legendary+), its name and rarity in Gotham Heavy Italic, "NEW!" (+ `reward`) or "Duplicate: +N coins" or
  "+N COINS"; then OPEN AGAIN / BACK and the pity line. Tap anywhere skips to the prize (no flash, no burst); Reduced
  Motion goes straight there. Escape or the Secret cutscene starting closes it and a toast says what you got.
- Uses only existing sounds (`pick_land`, `spin_tick`, `spin_win`, `spin_big_win`, `reward`) through `Sfx`, so the
  Effects volume applies. The crate picture is drawn from UI parts (`UI/CrateArt.crate`): a stand-in until his art.
- Checks: `tests/CrateRoll.spec` (odds, pity, `left`, dupes, honest strip, the live config),
  `tools/preview/check_crates.luau` (contents exist, Shop odds add to 100, Aura taken once, the reel stops on the
  prize, ticks, flash limit, skip, OPEN AGAIN, pity, duplicates, blocked in rounds and the cutscene). Shots
  `shop-crates`, `crate-spin`, `crate-prize`; film `tools/preview/crate_film.sh` → `docs/previews/crate-open.mp4` and
  `crate-open.jpg`.

## Admin panel (`Screens/Admin` + `HuzzServer/AdminService` + `Shared/AdminRules`)
- Only the game's owner: Studio, else `player.UserId == game.CreatorId` (a game he owns) or rank 255 in the creator
  group (a group game); no user IDs typed anywhere, the server checks every request (remote `Admin`, ActionService's
  0.15 s limit).
- Admins get a small ADMIN button bottom-left (Player attribute `HuzzAdmin`) opening KNIVES (GIVE: yours and worn) and
  GIRLS (SPAWN: yours and your companion, behind you at once; NEXT GAME: `GirlService.setNext`, the next roll lands on
  her, a Secret plays her cutscene). Spawning a girl loose mid-lobby doesn't fit the loop, so it's companion or next game.
- Checks `tests/AdminRules.spec` (a non-admin is refused), `tools/preview/check_admin.luau` (the real server).

## Honest gaps
- Not seen in Studio yet: stars in the playing zone, the spin animation, Crown Pose, Midnight cape, worn auras, the
  crate opening (its feel, the sounds' levels, the blur behind it).
- Crates: contents, price and odds are Claude's first pick; the crate picture is drawn (stand-in); the HUD coin pill
  can show a coin prize a moment before the reel stops (the save updates at once).

## Why it is this way / history
- The owner picked "Coin cosmetics shop" for coins.
- **Crates** (owner: "I will add them later"; Oct 19: "Also create a good case opening animation"). No crate mockup
  exists in `design/`, so the Shop card follows the COINS tab's tall cards and the opening screen the Spin wheel's
  1280 x 720 layout.
- **Aura stars** (owner, Oct 17: "different colors give different amounts ... the ones that give more are rarer").
- **Admin panel** (owner, Oct 18: "give me a admin command panel or something so i can get any knife or any girl to
  spawn when i want it to do so").
