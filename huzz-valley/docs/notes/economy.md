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
- A real free spin every 15 min; packs of 1/10/100 for 24/170/600 Robux (halved Oct 19: `Config/Products` Price;
  Developer Products, Id 0 until the owner creates them with these prices, granted only in ShopService's
  ProcessReceipt). The daily spin quest gives a spin too (below).
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

## Daily quests (`Config/DailyQuests`, `Shared/DailyRules`, ActionService `ClaimDaily`, `Screens/DailyQuests`)
- His picture d in our look: QUESTS, "RESETS IN 9h 28m" (real: midnight UTC), the spin quest first ("NEW IN 1h 28m",
  a new one every 2 hours, +1 SPIN), then two daily quests (coins or Aura). Easy targets (play 3, cross 5, 2 catches,
  10 stars...). Opened from the QUESTS button under SPIN on the HUD, which wears a green "!" while one is ready.
- Same picks for everyone, worked out from the day number (no saved schedule): the pool of 10 is shuffled into 5
  pairs of different stats each 5 days, a new day never repeats yesterday's quests, and the pool comes round again
  (recycled). The spin quest never counts the same thing as that day's two. Progress counts the same events as the
  lore quests (`ProgressService.addStat` also feeds `DailyRules.add`; RoundService and the Aura stars wrote `Stats`
  themselves until Oct 19, so every counter now goes through it, and the spec fails on a direct write), saved in
  `Daily = { Day, Slot, Q }`.
- The server checks a claim against the save and its own clock, once each. No Robux "Refresh" or "Auto Complete"
  (his picture's buttons): paying to skip is left out (kid-safe). Spec `tests/DailyRules.spec`.

## Friend rewards (`Config/Friends`, `Shared/FriendRules`, `HuzzServer/FriendService`)
- While a Roblox friend plays in your server: +10% on every game's coin pay (RoundService, after the x2 boost) and a
  purple "+10% COINS" tag by the HUD coins (player attribute `HuzzFriendBoost`).
- When a friend joins a server you're in (what an invite does), you get the friend knife once per account (500 coins
  if you own it already). **Placeholder knife:** his Sakura Blade (Rare) until he names one; a never-sold row of its
  own waits for the knife files (`Config/CoinShop` was the knife work's). Toasts say both.
- INVITE on the HUD (over SPIN) opens Roblox's own invite window (`SocialService`, guarded; Studio can't open it).
  Spec `tests/FriendRules.spec`.

## Prestige (`Shared/PrestigeRules`, ActionService `Prestige`, Screens/Index)
- Winning a girl you already own still pays her duplicate coins (nothing taken away) and now also saves a spare copy
  (`Dupes[id]`). PRESTIGE on her picture in the Index spends one and raises `Prestige[id]` to 1/3, 2/3, 3/3.
- Cooler effects: her effects on her and on you use one rarer tier per level (Common 1 = Uncommon's look ... capped at
  Mythic; Secret keeps its own). `CompanionService` puts `HuzzCompanionPrestige` on the player; `Gameplay/Auras`
  rebuilds her look when it changes. Spec `tests/PrestigeRules.spec`.

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
- **More crates (Oct 19, owner: "knifes, dances, from crates"):** Knife Crate (100 Aura, his 30 knives that are for
  sale, by rarity), Halloween Crate (120 Aura, his 18 Halloween knives) and Dance Crate (80 Aura, 7 crate-only dances
  from his pack: Boogie Blast, Head Banger, The Twist, Zany Zig, Robot, Power Moves, Showstopper, Zombie Groove), each
  with every chance shown and a pity (40 / 40 / 30 opens). Built from `Config/CoinShop` (`knivesFrom`), never the
  pass, quest or wheel knives. Shop > CRATES stacks one section per crate, each painted its colours (`CrateArt.paint`).
- **The server decides first:** `OpenCrate` takes the Aura once, rolls with the shown odds and pity, gives the prize
  and answers `{ index, name, rarity, new, coins, pity, left, strip, at }`. `strip` is the reel: 48 honest draws with
  the shown odds (never pity, nothing planted next to the stop: `CrateRoll.strip`, spec checks the cards beside the
  stop are Legendary only at the real rate), the prize on card 40.
- **Shop > CRATES** (a 5th tab): the crate card (drawn crate, "GUARANTEED LEGENDARY in N opens" + bar from the save,
  OPEN 50 with the Aura star) and every item's exact chance in two columns. OPEN is refused in a round or the Secret
  cutscene ("Open crates in the lobby.") and with too little Aura.
- **The opening** (`Screens/CrateOpen`, 1280 x 720 like the Spin wheel, one RenderStepped loop on its own clock, so
  the film matches the game): the crate rattles harder for 0.6 s (six `roulette_tick` knocks, closer and closer), the
  lid pops off (`countdown_go`) with a green ring and sparks; the reel opens between two green light rails (streaks run
  along them at the reel's speed) and spins 4.6 s (ease-out, cubic, so the last cards still creep past) under the marker, `spin_tick` per card (max
  ~22/s, a little higher pitched as it slows); it runs 24 px past its stop and settles back over 0.4 s onto the SAME
  card (`landOffset` is kept on the left part of the card so the furthest point is on it too: an honest settle, never a
  fake near-miss), with `pick_land`; the marker turns the prize's rarity colour, the prize card lifts, others dim.
  Under the reel while it spins: the odds by rarity (chips) and the pity line. Then the prize zooms up with the prize
  sound (`spin_win`, Epic+ `spin_big_win`; `reward` 0.35 s later if new): a burst of 14 light beams in its rarity
  colour (smaller and fainter below Rare, white cores Epic+), soft kit rays, a smooth 8-layer glow, one soft flash
  (Epic+, at most once a second), a spark burst, two rings and a small shake (Legendary+), its name and rarity in
  Gotham Heavy Italic, "NEW!" or "Duplicate: +N coins" or "+N COINS"; then OPEN AGAIN / BACK and the pity line. Tap
  anywhere skips to the prize (no settle, flash or burst); Reduced Motion goes straight there. Escape or the Secret
  cutscene starting closes it and a toast says what you got.
- **Colours:** rarity colours are the Spin wheel's (`Config/SpinWheel.RarityColors`, Legendary pink FF6FC0) on the
  crate card, odds, reel and prize (owner: "no gold anywhere"). The girls and the Shop's ITEMS knives still use
  `Config/Round.Rarities` (Legendary orange): the owner's call whether to change those.
- **The HUD's coins wait for the prize:** `State.hold("Coins")` before the server call, released at the reveal (a
  duplicate's coins or a coin prize would give the result away). Aura drops at once (the price you paid).
- Uses only existing sounds (`roulette_tick`, `countdown_go`, `spin_tick`, `pick_land`, `spin_win`, `spin_big_win`,
  `reward`) through `Sfx`, so the Effects volume applies. The crate picture is drawn from UI parts
  (`UI/CrateArt.crate`): a stand-in until his art.
- Checks: `tests/CrateRoll.spec` (odds, pity, `left`, dupes, honest strip, the live config),
  `tools/preview/check_crates.luau` (contents exist, Shop odds add to 100, Aura taken once, the reel stops on the
  prize, the settle ran past and back while staying on the prize card, the odds chips, the HUD's coins held until the
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
- Not seen in Studio yet: daily quests, the winner page, friend rewards (need two real accounts), prestige effects.
- The friend knife is a placeholder (Sakura Blade, also sold and in the Knife Crate); a Mythic girl's prestige only
  shows as PRESTIGE N/3 (she already has the top look).
- Crates: contents, price and odds are Claude's first pick; the crate picture is drawn (stand-in); the sounds are our
  made stand-ins (no whoosh or riser of its own yet).

## Why it is this way / history
- The owner picked "Coin cosmetics shop" for coins.
- **Crates** (owner: "I will add them later"; Oct 19: "Also create a good case opening animation"). No crate mockup
  exists in `design/`, so the Shop card follows the COINS tab's tall cards and the opening screen the Spin wheel's
  1280 x 720 layout. Polish pass (owner, Oct 19: "also check the opening animations for the crates"), judged frame by
  frame against the best Roblox openings: the honest settle, the rails and odds framing the reel, a sharper beam
  burst, a smooth glow, the coins held, pink Legendary, sounds on the beats (rattle, pop, ticks, thunk, prize).
- **Oct 19 list:** "spin prices lower"; "knifes, dances, from crates"; "add easy quests as in this photo and make new
  ones everyday then recycle them"; "make friend rewards, add a friend knife (for inviting them) and add a 10% coin
  boost when a friend is in"; "if you get more than one of the same girl, make a button which makes them prestige
  that gives them cooler vfx". Duplicates kept their coins so nobody loses anything; the copy is extra.
- **Aura stars** (owner, Oct 17: "different colors give different amounts ... the ones that give more are rarer").
- **Admin panel** (owner, Oct 18: "give me a admin command panel or something so i can get any knife or any girl to
  spawn when i want it to do so").
