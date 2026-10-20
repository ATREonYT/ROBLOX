# Economy: coins, Aura, shop, wheel, quests, cosmetics, crates, admin

Read before touching prices, the shop tabs, Aura stars, Spin the Wheel, quests, cosmetic slots, rewards, crates or
the admin panel. Round pay and XP: [round.md](round.md). Knife skins and Game Pass knives: [knives.md](knives.md).
Purchases follow the root `CLAUDE.md` rules (one ProcessReceipt in `ShopService`, never invent IDs, "coming soon"
while `Id = 0`). `OnSale` only stops prompts: a paid receipt is always granted, once per PurchaseId, "granted" only
after the save (`tools/preview/check_bughunt.luau` checks an off-sale coin pack's receipt). The client's one-time
`GetState` ask is limited (one waiting at a time, a second apart) so it can't be spammed.

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
  `Gameplay/CrownPose` (cooldown); Midnight = tint + cape (re-made on the avatar's own torso when Roblox swaps it in; `tests/Cape.spec`,
  `docs/previews/cape-fix.jpg` from `motion3d/cape_scene.luau`). Oct 20 this was blamed for the owner's "floating
  black block"; it wasn't: his block is thick (a visible top face, about 0.3 deep) with no purple lining, the cape is
  0.08 thin with a Neon lining, and the outfit can't be had yet (Id 0, coming soon; his Studio progress resets each Play) (where the block
  hunt stands: [knives.md](knives.md)). Not seen in Studio yet: Crown Pose, Midnight cape, worn auras.

## Crates (`Config/Crates`, `Shared/CrateRoll`, ActionService `OpenCrate`, Shop > CRATES, `Screens/CrateOpen`)
- **One live crate, Claude's first pick** waiting on the owner's own crate design: the **Starter Crate**, 50 Aura, only
  things that already exist: 150 / 400 coins, coin shop looks (Rusty Shiv, Box Cutter, Pink Name, Jade Kunai, Mint
  Trail, Thunder Fang, Ocean Trail, Candy Trail, Storm Kunai, Void Fang, Galaxy Trail) and the Robot dance. Common 50%,
  Uncommon 27%, Rare 15%, Epic 6%, Legendary 2% (Void Fang 1%, Galaxy Trail 1%); a Legendary at the latest on the
  30th open. A look you own already pays coins back by rarity (50 / 100 / 200 / 400 / 1,000). No Dance Pack dances
  (the pass sells them), no rewards, pass, quest or wheel prizes. Aura is only earned, never sold for Robux.
- **More crates (Oct 19, owner: "knifes, dances, from crates"):** Halloween Crate (120 Aura, his 18 Halloween knives)
  and Dance Crate (80 Aura, 7 crate-only dances from his pack: Boogie Blast, Head Banger, The Twist, Zany Zig, Robot,
  Power Moves, Showstopper, Zombie Groove), each with every chance shown and a pity (40 / 30 opens). The Halloween one
  is built from `Config/CoinShop` (`knivesFrom`), never the pass knives. The two Halloween stands' crates (Witch's
  Brew, Sweets & Treats) live on the Halloween shop page instead (below).
- **His three knife crates (Oct 20, 03:33: "here is the new one with updated crates, make these crates for the opening
  of the normal knifes ... and make all of the knifes earned either through crates/bought/ or robux. and make the
  opening animations look appropriate").** They replace the Oct 19 Knife Crate. In his place he built
  `Workspace > scrates > Standard_Crates` with three sets: a crate and the ten little knives he laid out in front of
  it, all 30 of his knives between them (`knivesNamed`; `tests/CrateModels.spec` checks each crate's items are exactly
  the ten beside his crate, by his knife model names):

  | Crate (`Config/Crates` id) | His set / model | Knives |
  |---|---|---|
  | Shinobi Dojo Chest (`Dojo`) | `dojo_set` / `Shinobi_Dojo_Chest` (built shut) | Training Kunai, Plain Tanto, Scout Dagger, Jade Kunai, Crimson Tanto, Night Tanto, Sakura Blade, Spirit Kunai, Blood Moon Tanto, Celestial Edge |
  | Elemental Storm Vault (`Storm`) | `storm_set` / `Elemental_Storm_Vault` (built open 31 deg) | Kitchen Cleaver, Field Knife, Box Cutter, Ice Shard, Copper Cleaver, Thunder Fang, Frost Fang, Ember Edge, Storm Kunai, Solar Reaper |
  | Void Beast Chest (`Beast`) | `beast_set` / `Void_Beast_Chest` (jaw built open 15 deg) | Rusty Shiv, Bone Knife, Serrated Fang, Hunter's Hook, Venom Kris, Hollow Moon, Shadow Knife, Twin Fang, Void Fang, Abyss Eclipse |

  100 Aura each, a Legendary at the latest on the 40th open (each its own counter), odds by rarity from
  `KNIFE_WEIGHT` (Dojo C 42.9 / U 35.7 / R 14.3 / E 4.8 / L 2.4%; Storm 45 / 25 / 22.5 / 5 / 2.5%) and, for the Beast
  Chest, `BEAST_WEIGHT` (C 40 / U 30 / R 15 / E 10.5 / L 3 / M 1.5%): its mix of items (one Rare, three Epics) made
  Epic 18.5% beside Rare 9.2% with the shared weights, so it has its own and every rarer tier is rarer
  (`tests/CrateModels.spec` checks each crate). Old saves: the Oct 19 Knife Crate's pity counter (and any keys) move
  on load into the knife crate with the highest count, the Dojo Chest by default, keeping the higher number
  (`Shared/CrateSaves`, `tests/CrateSaves.spec`); nothing else in a save counts per crate. They also hold the three quest knives (Training Kunai, Hunter's Hook, Hollow
  Moon) and the wheel's Celestial Edge, which had no other way to get them besides the quest or the wheel. Every
  knife now has a crate, coins, Aura or Robux way (the spec lists them).
- **His models in the game** (`Shared/CrateModels`): the crates stand on a spare lobby copy (put away), so they are
  not lobby props; his `Standard_Crates` moves to `ReplicatedStorage > HuzzCrates` in the place build
  (`build_yours.luau`) and again at game start (`Bootstrap`, for his own Rojo place). `UI/Crate3D` clones one into a
  ViewportFrame, never redrawn. His .glb groups say what moves: the Storm Vault's lid group and the Beast Chest's jaw
  group (`Node<n>` holding a "...lid..." part); the Dojo Chest has none, so its whole roof (everything over its body's
  top, not the floating sparkles and petals) swings (`Shared/CrateMotion` split). `Built` in `Config/Crates` is how
  far his model already stands open (measured from his lid: the front edge comes down onto the body; the spec checks).
- **Shop > CRATES = his crate shop picture itself** (Oct 20, 03:48 "Here are the ui mock ups", then 07:23 "Just put
  the ui picture i sent you, no need to try recreate" / "For the crates"): `design/owner-oct20/0348-crate-shop-mockup.png`
  cut down the middle of the gaps into its three cards at full size (`tools/crates/cut_mockup_cards.py` ->
  `assets/art/crate-card-{dojo,storm,beast}.png`, packed at 448 px as `Art/CrateCardDojo`, `CrateCardStorm`,
  `CrateCardBeast`; nothing redrawn or cleaned), shown side by side at their own proportions (193 px high, centred in
  the row) so the row is his picture again: his crate renders, sparkles and BUY buttons as he drew them. An invisible
  button lies over each of his BUY buttons: a crate key Developer Product (`Products.Crates`: `DojoCrateKey`,
  `StormCrateKey`, `BeastCrateKey`, 25 R$ our pick, **Id = 0**, so it only says "coming soon"; `ShopService.promptCrateKey`
  refuses too, and the receipt grants +1 key only on the server). Kept for kid safety on a slim line UNDER each card
  (never on his art), small and in his colours (BUY violet, his lilac, his card navy): **OPEN 100** with Aura (or
  "OPEN · N KEYS"), the pity line ("LEGENDARY IN 40") and an "i" that scrolls to that crate's full odds list under the
  row. A card and its line fit the Shop's body, so they show without scrolling. In Studio's editor the cards stay blank
  until he uploads them (`Config/ImageIds`, README checklist); in Play the game draws them (`UI/ImageLoader`). The
  Starter and Dance crates keep their old cards below. Side by side: `docs/previews/crate-shop-vs-mockup.jpg`.
- **The 3D opening** (`Screens/CrateOpen` with `UI/Crate3D`; timeline `Shared/CrateMotion` (T), one maths for the game
  and the film). Owner, Oct 20 07:51: "Can you please make the opening animation of the crates feel more premium,
  right now it feels too ai, as now they have the circle around the knife when it opens, remove it, add s nice
  animation for the knife when it starts rising up from the crater". So: restraint and timing, light instead of
  shapes; the rays behind the crate, the ring and sparks, the round light behind the knife and the Epic flash are gone
  from the 3D opening. No crate or case opening in his Huss Valley references (his uploads and `design/` were looked
  through Oct 20), so the beats are ours:
  - shut (a crate built open is shut first), it rocks and jumps a little harder and faster for 2.1 s, a knock on each
    of 9 closer-and-closer jumps;
  - 2.1 s: the top cracks open about 9 deg with a low knock and holds; light in the prize's rarity colour spills out of
    the gap (a thin glowing layer just under his top, `Spill`, `CrateMotion.spill`; his glow parts and the viewport's
    ambient light take the colour; if Roblox refuses the tint on his SurfaceAppearance, the part's own colour takes
    it);
  - 2.6 s: it swings open with a soft overshoot (to 100 deg from shut, at most 10% past) and a soft pop; the lit
    layer fades out over 0.4 s as it opens, so it is the light only while the top is cracked and never a flat slab
    inside the open crate (the lavender floor in the film after that is his own glow part, drawn as a stand-in box);
  - 2.75 s: his own little knife from the same set rises out slowly (1.6 s, a strong ease-out), leaning about 10 deg,
    making one slow turn, and settles into a gentle hover facing you (a small bob and sway); the camera eases in 8%;
    six small motes in the rarity colour drift up from inside, one at a time (never a burst);
  - 4.2 s: one glint, a thin streak of light sliding up the face of the blade (`Glint`);
  - 4.45 s: its name and the title fade in, the rarity a beat later, then NEW! or the coins, the buttons.
  A dark knife (its first `CoinShop` colour darker than 0.3, like Hollow Moon or Shadow Cleaver) gets a soft light
  right behind its blade, stretched along it and leaned with it (`KnifeLight`, `CrateMotion.rimLight`: strength 0.92,
  the rarity colour lifted 88% towards white, since the critic found 0.55/70% still left Hollow Moon a thin dark
  sliver on navy), so its dark shape stands out on the light; the rest get none. As the knife rises and hovers the
  whole crate view brightens a little (`CrateMotion.viewLift`: the ambient and light colour towards white, fully for a
  dark blade, a third for the rest). His knife's own aura ring is part of his model and stays as he made it. The lid swings on its back
  hinge (checked from the side, `SIDE=1` on the film scene), it never lifts flat. No reel for these crates; the odds
  chips and pity line show under it while it builds up; no flash at all; tap to skip; reduced motion: no shake,
  motes or glint, and the knife is simply there. `Crate3D.RevealHook` (nil today) is where the knife's own effect
  (the knife VFX work, Rare and up) can hook in when his knife is placed. Without his model loaded it plays the old
  crate and reel. Film: `docs/previews/crate-open-3d.mp4`, `docs/previews/crate-open-3d-strip.jpg` and before/after
  `docs/previews/crate-open-3d-before-after.jpg` (`tools/preview/motion3d/crate_open_scene.luau`).
- **The server decides first:** `OpenCrate` takes the Aura once, rolls with the shown odds and pity, gives the prize
  and answers `{ index, name, rarity, new, coins, pity, left, strip, at }`. `strip` is the reel: 48 honest draws with
  the shown odds (never pity, nothing planted next to the stop: `CrateRoll.strip`, spec checks the cards beside the
  stop are Legendary only at the real rate), the prize on card 40.
- **Shop > CRATES** (a 5th tab): the crate card (drawn crate, "GUARANTEED LEGENDARY in N opens" + bar from the save,
  OPEN 50 with the Aura star) and every item's exact chance in two columns. OPEN is refused in a round or the Secret
  cutscene ("Open crates in the lobby.") and with too little Aura.
- **The opening** (`Screens/CrateOpen`, 1280 x 720 like the Spin wheel, one RenderStepped loop on its own clock, so
  the film matches the game): the crate rattles harder for 0.6 s (six `roulette_tick` knocks, closer and closer), the
  lid pops off (`countdown_go`, softer; no ring or sparks since Oct 20); the reel opens between two green light rails (streaks run
  along them at the reel's speed) and spins 4.6 s (ease-out, cubic, so the last cards still creep past) under the marker, `spin_tick` per card (max
  ~22/s, a little higher pitched as it slows); it runs 24 px past its stop and settles back over 0.4 s onto the SAME
  card (`landOffset` is kept on the left part of the card so the furthest point is on it too: an honest settle, never a
  fake near-miss), with `pick_land`; the marker turns the prize's rarity colour, the prize card lifts, others dim.
  Under the reel while it spins: the odds by rarity (chips) and the pity line. Then the prize card comes up gently
  (90% to full size) with the prize sound (`spin_win`, Epic+ `spin_big_win`; `reward` 0.5 s later if new) and a
  smooth 8-layer glow in its rarity colour that breathes slowly; its name fades in (Gotham Heavy Italic), the rarity a
  beat later; one glint, a white band in a gradient on the card's rim (`Glint`), runs across it once; then "NEW!" or
  "Duplicate: +N coins" or "+N COINS" fade in, then OPEN AGAIN / BACK and the pity line. Calm like the 3D opening
  since the owner's Oct 20 07:51 "feels too ai" (so he never sees "the circle" on any path): no light rays behind the
  crate or the reel, no beam burst, rings, sparks, flash or shake (a UI saved before then has them: the screen
  destroys them at start). Tap anywhere skips to the prize (no settle); Reduced Motion goes straight there, no glint. Escape or the Secret
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

## Halloween shop (`Config/HalloweenShop`, `Screens/HalloweenShop`, ActionService `BuyHalloweenKnife`)
- **Owner, Oct 19 17:41:** "make a halloween shop when you press on one of the two crates. and then you can buy the
  crates, or the best knifes for either aura or robux." His stands: `design/owner-oct19/1840-halloween-crates.png`.
  WITCH'S BREW and SWEETS & TREATS (`Config/LobbyProps` `Opens = "HalloweenShop"`) open it from the prompt (E) or a
  click. A stand saved in his place before it had a menu gets its prompt and click from `LobbyPropService` (backfill).
- **The page:** the Shop's 701 x 320 window, header pumpkin orange (FFAA4C to D2560E), plum body (2A1646), tabs
  CRATES / KNIVES. Side by side with our Shop: `docs/previews/halloween-shop-vs-shop.jpg` (shots `halloween-crates`,
  `halloween-knives`; `side_by_side.py pages`).
- **CRATES:** two set crates, one per stand (Claude's reading of "the two crates"): **Witch's Brew Crate** (his 6
  Witch knives) and **Sweets & Treats Crate** (his 6 Candy knives). Same odds by rarity as the Halloween Crate
  (Common 46%, Uncommon 27.6%, Rare 16.1%, Epic 6.9%, Legendary 2.3%, Mythic 1.1%), pity 40 (a Legendary or the
  Mythic), 120 Aura an open. They have `Home = "HalloweenShop"`, so they are only on this page, not in Shop > CRATES
  (the 18-knife Halloween Crate stays there). Every chance and the pity counter show on the page, like Shop > CRATES.
  OPEN plays `Screens/CrateOpen`; its BACK returns to the page.
- **Crate keys (Robux):** one key = one open of that crate. Saved as `CrateKeys[crateId]`; `OpenCrate` uses a key
  before any Aura, in the same save write. The button then reads USE KEY (n). A key open counts toward pity as usual.
- **KNIVES:** the Legendary and the Mythic of each set, as his pictures (Art): Coven Katana, Grand Witch Scythe, Sugar
  Rush Katana, Candy Reaper. Each for Aura or Robux; OWNED once yours (the Robux button hides).
- **Aura price of a knife** = 3 x what it costs on average to get it from its own crate, to the nearest 100.
  `CrateRoll.expectedOpens` is exact with the pity (a chain over the pity counts, solved back from the 40th;
  `tests/HalloweenShop.spec` checks it against a hand-worked case and a long seeded run):
  - Legendary: 32.8 opens x 120 = 3,937 Aura on average, so **11,800 Aura**.
  - Mythic: 65.6 opens x 120 = 7,875 Aura on average, so **23,600 Aura**.
- **Robux prices (Claude's pick, the owner may change them):** crate key 25 R$ (a single spin is 24), Legendary knife
  149 R$, Mythic knife 249 R$. All six are Developer Products in `Products.Halloween` with **Id = 0**: the button shows
  the price, a tap only says "<name> for Robux is coming soon." and never opens a purchase. Once an ID is set the live
  Roblox price shows and Roblox's prompt opens.
- **Server only:** `BuyHalloweenKnife` accepts only the page's knives, refuses an owned one ("You own this already.")
  and too little Aura ("You need N more Aura."), and takes the Aura and gives the knife (worn) in one save write, so a
  double tap buys it once. Robux: `ShopService` grants once per PurchaseId and answers "granted" only after the save;
  what a receipt gives is `HalloweenShop.grant` (a key: +1; a knife: owned and worn).
- **Never Robux for nothing** (fresh critic, Oct 19: the knife receipt used to charge for a knife you already had):
  the client never prompts; it asks the server (ActionService `PromptHalloween` -> `ShopService.promptHalloween`),
  which opens Roblox's prompt only for this page's products with an ID and never for a knife you own
  (`HalloweenShop.canPrompt`). A receipt that still arrives for an owned knife (a stale page, bought on another
  server first) gives **crate keys** for that knife's own crate worth its Robux price instead: price / key price,
  rounded (Legendary 149 / 25 = 6 keys, Mythic 249 / 25 = 10 keys). Keys, not Aura, because Aura is only earned,
  never sold for Robux. Uses the configured prices, not Roblox's live ones. The player is told: "You already had
  Candy Reaper, so you got 10 Sweets & Treats Crate keys instead." (ShopService sets the Player attribute
  `HuzzShopNotice` = "<n>|<line>", the Halloween screen shows it as a toast; no new remote).
- **A paid receipt is always granted,** even if the item was taken off sale while the purchase was on its way:
  `OnSale` only stops new prompts (`canPrompt`); `HalloweenShop.grant` ignores it (second critic, Oct 19: it used to
  answer "not processed yet" until Roblox gave up). Since the Oct 20 bug hunt the rest of the products (coins,
  Robux cosmetics, spins) are granted the same way: `ShopService.grant` never checks `OnSale` (an unknown product is
  still never answered "granted"). A product that gives nothing yet has no prompt anywhere, so no receipt for it.
- Checks: `tests/HalloweenShop.spec` (prices, Id 0, no prompt for an owned knife or without an ID, the receipt rules
  and the refund keys and their line, an off-sale receipt still granted), `tools/preview/check_halloween.luau` (stands open it, the backfill, odds add to 100, pity,
  both prices, not enough Aura, already owned, double tap, a knife not sold here, Id 0 never prompts, an ID prompts,
  the server refuses to prompt an owned knife, receipts once and after the save, an owned knife's receipt gives keys,
  a key used before Aura, OPEN plays the opening).
- **Gaps:** not seen in Studio; the Robux IDs are 0 and the prices are ours; the crate is the drawn stand-in box, not
  his stand models; the header icon is the Shop cart (no pumpkin icon in his kit); his coin shop also sells these
  four knives for coins (4,000 / 8,000), which is the cheaper way to get them, so Aura buyers pay more on purpose.
  The knife cards are pictures rendered from his own meshes (`assets/art/knife-*.png`), drawn by script until he
  uploads them; the knife you then hold is the server's plain stand-in, dressed as his .glb only where Studio allows
  Mesh / Image APIs, until he imports `Halloween_Knives.glb` ([knives.md](knives.md)). The "you got keys instead" line
  only shows if the Halloween screen was built (it always is in the game; checked offline only).

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
- The friend knife is a placeholder (Sakura Blade, also sold and in the Shinobi Dojo Chest); a Mythic girl's prestige only
  shows as PRESTIGE N/3 (she already has the top look).
- Crates: contents, price and odds are Claude's first pick; the Starter and Dance crate pictures are drawn
  (stand-in); the sounds are our made stand-ins (no whoosh or riser of its own yet).
- His three knife crates: their real look (meshes, textures, glow) is only Studio's to judge: offline pictures draw his
  parts as boxes. Not seen in Studio: the 3D opening (the glint and motes are plain Neon parts: a ViewportFrame has no bloom, so
  they may read flatter than in the film), his picture cards in the Shop, whether `SurfaceAppearance.Color` takes the rarity
  tint on his glow parts (pcall: nothing breaks if not). The crate keys' Robux IDs are 0 and the 25 R$ is ours. His
  picture's crates (the Shop cards) are a concept render; the opening shows his model as he built it (the Dojo roof,
  the crystals, the jaw), so the two look a little different. His cards are a mockup at 2172 px: sharp enough at
  448 px, but his BUY buttons are part of the picture, so they don't light up or press down like our buttons.

## Why it is this way / history
- The owner picked "Coin cosmetics shop" for coins.
- **Crates** (owner: "I will add them later"; Oct 19: "Also create a good case opening animation"). No crate mockup
  exists in `design/`, so the Shop card follows the COINS tab's tall cards and the opening screen the Spin wheel's
  1280 x 720 layout. Polish pass (owner, Oct 19: "also check the opening animations for the crates"), judged frame by
  frame against the best Roblox openings: the honest settle, the rails and odds framing the reel, a smooth glow
  (its beam burst went on Oct 20, "too ai"), the coins held, pink Legendary, sounds on the beats (rattle, pop, ticks, thunk, prize).
- **Oct 19 list:** "spin prices lower"; "knifes, dances, from crates"; "add easy quests as in this photo and make new
  ones everyday then recycle them"; "make friend rewards, add a friend knife (for inviting them) and add a 10% coin
  boost when a friend is in"; "if you get more than one of the same girl, make a button which makes them prestige
  that gives them cooler vfx". Duplicates kept their coins so nobody loses anything; the copy is extra.
- **Aura stars** (owner, Oct 17: "different colors give different amounts ... the ones that give more are rarer").
- **Admin panel** (owner, Oct 18: "give me a admin command panel or something so i can get any knife or any girl to
  spawn when i want it to do so").
