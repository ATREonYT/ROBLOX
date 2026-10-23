# Economy: coins, Aura, shop, wheel, quests, cosmetics, crates, admin

Read before touching prices, the shop tabs, Aura stars, Spin the Wheel, quests, cosmetic slots, rewards, crates or
the admin panel. Round pay and XP: [round.md](round.md). Knife skins and Game Pass knives: [knives.md](knives.md).
Purchases follow the root `CLAUDE.md` rules (one ProcessReceipt in `ShopService`, never invent IDs, "coming soon"
while `Id = 0`). `OnSale` only stops prompts: a paid receipt is always granted, once per PurchaseId, "granted" only
after the save (`tools/preview/check_bughunt.luau` checks an off-sale coin pack's receipt). The client's one-time
`GetState` ask is limited (one waiting at a time, a second apart) so it can't be spammed.

## Coins and the shop
- **Coins** buy looks in the Shop (COSMETICS > FOR COINS) (`Config/CoinShop`: trails, name colours, titles, auras), dances
  (Shop > DANCES, below) and his Halloween crates (coins or Aura). Items with `Unlock` (quest knives) or `NotForSale`
  (Spin Knife) are never sold.
- **Knives are never sold for coins (owner, Oct 20 20:34: "make the knifes not be bought but opened from crates. So
  remove the buying menu").** They come from the crates, the Halloween knives (Aura or Robux), the Game Passes and
  quests; `ActionService.BuyWithCoins` refuses any `Slot = "Knife"` ("Knives come from crates."). Every coin knife
  is in at least one crate (his three crates hold all 30, the Halloween crates his 18 Halloween ones). Shop > KNIVES
  lists only the knives you own, to wear.
- **Dances for coins (owner, Oct 20 20:34: "make a seperate section for dances, so that the dances you get by buying
  them individually, or in the dances section keep them there and make them be able to be bought there").** Shop >
  DANCES: the Dance Pack pass on top, then every dance with a `Coins` price (`Config/Dances`), bought one by one with
  `ActionService "BuyDance"` (price, "already yours" (also through the Dance Pack) and "not enough coins" checked in
  the one save write). Claude's prices: the seven dances only the Shop sells by how fancy (the old Dance Crate's
  rarities): Boogie Blast, Head Banger 400; The Twist, Zany Zig 600; Power Moves 800; Showstopper 1,200; Zombie Groove
  2,000; the Robot 600 (also the reward track's level 3); the four Dance Pack dances are Robux only, through the pass (owner, Oct 21: "make the dances be some for Robux, some
  for coins"; they have no `Coins`, so Shop > DANCES doesn't list them and BuyDance refuses them). The 20
  starter dances stay free.
- The COINS section sells coin packs for Robux (cards after the Oct 17 mockup, `docs/previews/coins-vs-mockup.jpg`; art
  cut by `tools/icons/make_screen_art.py`, placeholders until sharp PNGs); its buttons keep the Robux mark, never a
  coin icon.
- **The AURA section (Oct 20 14:07, owner: "make a buy section for aura")** sits just above COINS, laid out like it:
  3 Developer Products in `Products.Aura` (`Aura200`, `Aura700`, `Aura1500`: 200 / 700 / 1,500 Aura for 49 / 149 /
  299 R$, **Id = 0**, so each only says "coming soon", README checklist). Amounts are Claude's pick, matched to the
  crate keys: a key is 25 R$ for one 100 Aura open, so 200 Aura for 49 R$ is two opens at the key's price and the
  bigger packs are a little cheaper per open (the coordinator's 500 / 2,000 / 5,000 would have made Aura opens far
  cheaper than keys). Granted only in ShopService's ProcessReceipt (`grant`, Kind "Aura": once per PurchaseId,
  "granted" only after the save; `check_bughunt` section 5). The picture is his own Aura star (the kit's `AuraStar`,
  one, two or three stars on a violet glow), no new art. Every Aura "+" opens the Shop scrolled to AURA: the Shop header's and
  the top bar's (`LobbyHud`, was a toast plus Quests).
- Shop passes copy the owner's banners: [ui.md](ui.md). Shop > PASSES opens on the knife pass cards: [knives.md](knives.md).

## Abilities for coins (`Config/Powers`, `Shared/AbilityRules`, ActionService `BuyAbility` / `EquipAbility`, Shop > ABILITIES)
- **Owner, Oct 20 15:13:** "Please then make the abilities be bought, add a few more abilities". Round abilities are
  bought with **coins only** (never Robux) and kept for good (`Abilities` in the save); you buy them AND pick what
  you bring in the Shop's ABILITIES section (one place: an 8th Menu row didn't fit the Menu, critic Oct 20): the runner's Q (or **Random**: a new one you own each round, the old way) and the
  catcher's Q and E (`Loadout` in the save; picking the other key's one swaps them). A change plays from the next
  round (PowerService reads the loadout when a round starts). Speed Boost stays free (only while carrying the girl).
- **Prices** (`Config/Powers` `Price`; 25 coins a game, 50 a win, so 20 to 40 games' pay, spec-checked between 8 and
  40): Invisible 500, Glitchy 500, Banana Peel 600, Body Double 750, Radar 750, Smoke Bomb 900, Lasso 1,000.
  Starters, free and owned by everyone: Shield (runner), Bear Trap and Slow Wave (catcher: two keys, so two).
- **Oct 22 (owner, 12:26: "make everyone start with the shield ability, and then for the other abilities you have to
  buy them and equip them"):** a fresh save brings Shield on the runner key (was Random, which played bought ones
  without equipping); Random stays a pick you can choose. `Powers.Grandfathered` is empty: old saves get nothing free
  now (test saves keep what they were already given). Catchers still start with Bear Trap and Slow Wave (his message
  only names Shield; one line in `Config/Powers` to make them bought too).
- **Old saves kept everything** (until Oct 22): a save from before Oct 20 (no `Abilities` field before Reconcile)
  gets the four runner abilities it could already roll (Shield, Invisible, Glitchy, Body Double:
  `Powers.Grandfathered`), so nobody loses anything; new players start with the three starters and buy the rest.
  `AbilityRules.migrate`, called by DataService once on load.
- **Server only:** `BuyAbility(name)` checks the name, the side, that it isn't owned and the coins, then takes the
  coins and adds it inside one `DataService.update`; `EquipAbility(key, name)` checks the key (Runner / CatcherQ /
  CatcherE), the side and that you own it. Both go through ActionService's shared rate limit. A save with a bad or
  unowned pick falls back to the defaults (`AbilityRules.loadout`). Rules and prices: `tests/AbilityRules.spec`.
- The cards are `UI/AbilityCards` (picture or glyph, what it does, its cooldown, "Beat it:", BUY / EQUIP / Q and E):
  the Shop's ABILITIES section (between KNIVES and PASSES) is `AbilityCards.build(slot)`: a green "YOU BRING" line
  (your runner Q, catcher Q and E), then RUNNERS (RANDOM first) and CATCHERS. Picture `docs/previews/shop-abilities.jpg`
  (shots.sh `shop-abilities`; `tools/preview/check_filters.luau`).

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

## Join our group (`Config/Group`, ActionService `ClaimGroup` -> `ProgressService.claimGroup`, `Screens/GroupReward`; Oct 22)
- Owner, Oct 22 19:09: a "join the group" popup in our style, reward 5 free spins. FREE SPINS window: the wheel in
  green rays, +5 SPINS, JOIN GROUP (GroupService:PromptJoinAsync, guarded) and CLAIM. Lobby HUD GROUP button under
  QUESTS until claimed. Pops up once per visit after `PopupAfter` s in the lobby (never over a round or a window).
- Server only: asks Roblox fresh (GroupService:GetGroupsAsync; IsInGroup only as a fallback, it caches the answer
  from join), adds `Spins` to the save once (`GroupReward` in the save and the snapshot).
- **`Config/Group.Id` is 0 (owner's checklist):** COMING SOON on both buttons, CLAIM gives nothing, no popup or HUD
  button live (both show in Studio so he can see it). Check: `tools/preview/check_group.luau`; shot `group-reward`.

## Prestige: replaced by Combine (owner, Oct 21: "replace prestige with combine")
- Winning a girl you already own still pays her duplicate coins and saves a copy (`Copies[id]`, [combine.md](combine.md)).
  There is no PRESTIGE any more: the ActionService verb is gone and the Index's button is COMBINE (opens the Combine
  window on her when two match). A save that was already prestiged keeps its level and her rarer-tier effects
  (`Shared/PrestigeRules.effectRarity`, `HuzzCompanionPrestige`, `Gameplay/Auras`); nothing raises it now.

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

## Crates (`Config/Crates`, `Shared/CrateRoll`, ActionService `OpenCrate`, Shop > HALLOWEEN and CRATES, `Screens/CrateOpen`)
- **Since Oct 20 20:34 (owner: "remove the two crates that dont have pictures, the starter one ... make the halloween
  crates be changed out by the sweet and the cauldron pictures"; his picture `design/owner-oct20/2034-ablt1-powers-and-crates.png`,
  bottom half):** six crates, all with his pictures. Removed: the Starter Crate and the Dance Crate (read as "the two
  crates that dont have pictures"; their old pity counters stay in old saves, unused). His Halloween crates, renamed
  and repriced as his picture says, open with **coins or Aura** (`CoinPrice`, `OpenCrate(id, "Coins")`):

  | Crate (id) | Picture | Price | Holds |
  |---|---|---|---|
  | Candy Crate (`Sweets`) | his candy coffin | 250 coins or 49 Aura | his 6 Candy knives |
  | Witch Crate (`Witch`) | his witch cauldron | 350 coins or 79 Aura | his 6 Witch knives |
  | Halloween Crate (`Halloween`) | his Halloween chest | 500 coins or 99 Aura | his 18 Halloween knives |
  | Shinobi Dojo Chest / Elemental Storm Vault / Void Beast Chest | his crate cards | 100 Aura (or a Robux key) | his 30 knives (below) |

  Odds and pity are unchanged (Halloween ones: C 46 / U 27.6 / R 16.1 / E 6.9 / L 2.3 / M 1.1%, a Legendary or the
  Mythic at the latest on the 40th). The Robux keys (Witch, Candy, Dojo, Storm, Beast: Id 0, "coming soon") still open
  a crate once before any coins or Aura. Every crate is his crate cut out of his own picture
  (`tools/crates/cut_crates.py`, rembg, his pixels kept; the cauldron's smoke is lost in the cut) on one shared
  backdrop the Shop draws: [ui.md](ui.md). The Shop page shows no odds; tapping a crate slides its panel in with every
  chance, the pity and the only buttons that pay, so the odds are always in view when a kid pays.
- *(Before Oct 20 20:34; kept for the history.)*
- **Removed Oct 20 20:34. One live crate, Claude's first pick** waiting on the owner's own crate design: the **Starter Crate**, 50 Aura, only
  things that already exist: 150 / 400 coins, coin shop looks (Rusty Shiv, Box Cutter, Pink Name, Jade Kunai, Mint
  Trail, Thunder Fang, Ocean Trail, Candy Trail, Storm Kunai, Void Fang, Galaxy Trail) and the Robot dance. Common 50%,
  Uncommon 27%, Rare 15%, Epic 6%, Legendary 2% (Void Fang 1%, Galaxy Trail 1%); a Legendary at the latest on the
  30th open. A look you own already pays coins back by rarity (50 / 100 / 200 / 400 / 1,000). No Dance Pack dances
  (the pass sells them), no rewards, pass, quest or wheel prizes. Aura is earned, and since Oct 20 14:07 also sold
  in the Shop's AURA section (above).
- **More crates (Oct 19, owner: "knifes, dances, from crates"; the Dance Crate removed Oct 20 20:34, its dances sold
  in DANCES):** Halloween Crate (120 Aura then, his 18 Halloween knives) and Dance Crate (80 Aura, 7 crate-only dances from his pack: Boogie Blast, Head Banger, The Twist, Zany Zig, Robot,
  Power Moves, Showstopper, Zombie Groove), each with every chance shown and a pity (40 / 30 opens). The Halloween one
  is built from `Config/CoinShop` (`knivesFrom`), never the pass knives. The two Halloween stands' crates (Witch's
  Brew, Sweets & Treats) are in the same CRATES section with a HALLOWEEN tag (below).
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
  `CrateCardBeast`; nothing redrawn or cleaned), shown since Oct 20 14:31 on the one-page Shop's cards ([ui.md](ui.md), "The Shop"): each crate one 251 x 338
  card, its title, his picture cut to the crate (never recoloured), then the pity line ("GUARANTEED LEGENDARY" /
  "IN 40 OPENS"), **OPEN 100** with Aura (or "USE KEY (n)") and **KEY** for Robux: a crate key Developer Product
  (`Products.Crates`: `DojoCrateKey`, `StormCrateKey`, `BeastCrateKey`, 25 R$ our pick, **Id = 0**, so it only says
  "coming soon"; `ShopService.promptCrateKey` refuses too, and the receipt grants +1 key only on the server). An "i"
  scrolls to that crate's full odds under the cards (EVERY CHANCE). **Never a cardboard box** (Oct 20
  14:07: his Play showed ImageLoader's glyph on all three, and to him the crates looked missing): when his picture
  can't be drawn, `CrateArt.hisPicture` hides the glyph and stands his real 3D crate (`HuzzCrates`, `Crate3D` view
  "Card": the whole crate, turned a little as on his cards) in the picture's box; without his model yet, the drawn
  crate in his crate's colours. The stand-in is made at run time, tagged
  NoPicture, never saved into StarterGui. In Studio's editor the cards stay blank
  until he uploads them (`Config/ImageIds`, README checklist); in Play the game draws them (`UI/ImageLoader`). The
  Starter, Dance and Halloween crates follow in the same rows with the drawn crate. The old full-card row
  (`docs/previews/crate-shop-vs-mockup.jpg`) was before the Oct 20 14:31 one-page Shop.
- **The 3D opening** (`Screens/CrateOpen` with `UI/Crate3D`; timeline `Shared/CrateMotion` (T), one maths for the game
  and the film). Owner, Oct 20 15:13: "please make the case opening animation way, way better, right now its so vague
  and doesnt look good, remove so much glow from the crates, and then make it feel premium" (after 07:51's "too ai",
  "the circle around the knife": see Why). No crate opening in his Huss Valley references, so the beats are ours,
  built on weight, one clear moment and quiet everywhere else. A fixed shot on the crate (a slow 6% push-in, no wobble);
  a calm dark navy backdrop (`Backdrop`, 0A0E22) over the whole screen:
  - 0.3, 0.82, 1.3 s: three hops, each heavier (up, a tip to one side, a thud on landing `crate_thud`, a small bounce),
    still between them; the odds chips and pity line under it;
  - 1.8 s: the latch pops (`crate_latch`): the top cracks about 11 deg with a small jolt and a thin line of light in
    the rarity colour shows in the gap (`Spill`, the ONE light from inside);
  - 2.2 s: the lid is flung open (`crate_open`): a spring, fast, about 9% past open, back, still in 0.55 s; the crate
    rocks back a touch; the light inside goes out; the backdrop takes the rarity colour as a soft pool behind the
    knife (`Pool`, 16 ellipses, 0.6 s fade, quieter for Common to Rare: `CrateMotion.poolStrength`); the crate's
    title fades away;
  - 2.3 to 3.2 s: his knife from the same set comes out (`crate_rise`): up from inside, cut at the crate's front edge
    until clear (`KnifeClip`), then towards you, growing to full size (1.3 crate heights), a three quarter turn that
    ends on its profile, leaning into a diagonal, stopping sharp (3% past, back; `crate_reveal`, Epic+
    `crate_reveal_big`); the crate falls into shadow (half dark) so the knife is the only bright thing. A thin light
    rim outlines the blade (`Rim`: Neon copies of its big parts just behind it, wider for a dark blade like Hollow
    Moon), a rim and never a glow; his knife's own aura parts (`aura_ring`, `aura_shard`) are hidden here ("remove
    it"), his model is not changed;
  - 3.25 s: its name lands with a short scale punch (1.3 to 1, 0.22 s), the rarity tag (a pill in the rarity colour)
    0.1 s later, NEW! or the coins, then OPEN AGAIN and CLAIM. After that a tiny bob and sway.
  His crate's own glow parts are turned down to 30% of his EmissiveStrength while it is on screen (`Crate3D.GlowKeep`;
  his models in `HuzzCrates` are never changed or recoloured, the view holds a copy); no tint, motes, glint, rays, rings,
  KnifeLight or flash. Tap to skip lands on the end card; reduced motion: no hops, no swing, the knife simply there.
  `Crate3D.RevealHook` (nil today) is where the knife's own effect can hook in. Without his model loaded it plays the
  old crate and reel. Sounds: made by `tools/sfx/make_sfx.py` (`assets/sfx/crate_*.ogg`), keys "" in
  `Config/SoundIds` until he uploads them (Roblox stand-ins play meanwhile). Film: `docs/previews/crate-open-3d.mp4`
  (Legendary), `docs/previews/crate-open-3d-strip.jpg`, and before vs now for a Common and a Legendary pull, same size:
  `docs/previews/crate-open-3d-old-vs-new.mp4` / `.jpg` (`tools/preview/motion3d/crate_open_scene.luau`).
- **The server decides first:** `OpenCrate` takes the Aura once, rolls with the shown odds and pity, gives the prize
  and answers `{ index, name, rarity, new, coins, pity, left, strip, at }`. `strip` is the reel: 48 honest draws with
  the shown odds (never pity, nothing planted next to the stop: `CrateRoll.strip`, spec checks the cards beside the
  stop are Legendary only at the real rate), the prize on card 40.
- **Shop > CRATES** (the first section of the one-page Shop): a card per crate (picture, "GUARANTEED LEGENDARY" /
  "IN N OPENS" from the save, OPEN with the Aura star) and, under the cards, every item's exact chance per crate. OPEN is refused in a round or the Secret
  cutscene ("Open crates in the lobby.") and with too little Aura.
- **The opening** (`Screens/CrateOpen`, 1280 x 720 like the Spin wheel, one RenderStepped loop on its own clock, so
  the film matches the game): the crate rattles harder for 0.6 s (six `roulette_tick` knocks, closer and closer), the
  lid pops off (`countdown_go`, softer; no ring or sparks since Oct 20); the reel opens between two green light rails (streaks run
  along them at the reel's speed) and spins 4.6 s (ease-out, cubic, so the last cards still creep past) under the marker, `spin_tick` per card (max
  ~22/s, a little higher pitched as it slows); it runs 24 px past its stop and settles back over 0.4 s onto the SAME
  card (`landOffset` is kept on the left part of the card so the furthest point is on it too: an honest settle, never a
  fake near-miss), with `pick_land`; the marker turns the prize's rarity colour, the prize card lifts, others dim.
  Under the reel while it spins: the odds by rarity (chips) and the pity line. Then the prize card comes up gently
  (90% to full size) with the prize sound (`spin_win`, Epic+ `spin_big_win`; `reward` 0.5 s later if new), with no
  glow round it (its 8 `Halo` layers stay hidden since Oct 20 15:13, "remove so much glow"); its name fades in (Gotham Heavy Italic), the rarity a
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

## Halloween shop (`Config/HalloweenShop`, part of `Screens/Shop` since Oct 20 14:31, ActionService `BuyHalloweenKnife`)
- **Owner, Oct 19 17:41:** "make a halloween shop when you press on one of the two crates. and then you can buy the
  crates, or the best knifes for either aura or robux." His stands: `design/owner-oct19/1840-halloween-crates.png`.
  WITCH'S BREW and SWEETS & TREATS (`Config/LobbyProps` `Opens = "Shop"`, `Section = "Witch"` / `"Sweets"`) open the
  Shop scrolled to their crate's card, from the prompt (E) or a click (a stand saved earlier with "HalloweenShop" still
  opens the Shop: `Gameplay/LobbyProps`). A stand saved in his place before it had a menu gets its prompt and click from `LobbyPropService` (backfill).
- **Since Oct 20 20:34 (owner: "keep the halloween knifes, and put them on the top of the shop ui"):** the Shop's first
  section is HALLOWEEN: the featured Halloween Crate, his three Halloween crates (Candy, Witch, Halloween: coins or
  Aura, his new pictures, see Crates above), then these knives. The two stands' crates are now the **Candy Crate**
  (`Sweets`) and the **Witch Crate** (`Witch`). The knives keep their Aura prices: they are worked out from the crates'
  old 120 Aura (`HalloweenShop.PriceBasis`), not from the new 49 / 79. A stand opens the Shop at its crate and slides
  that crate's panel in (its chances, pity, coins / Aura / KEY). The bullets below are the earlier state.
- **No separate window since Oct 20 14:31** (owner: "make it all logically connected an all close to eachother"):
  its crates are cards in Shop > CRATES (tagged HALLOWEEN, with KEY for Robux) and its knives are the last row of
  Shop > KNIVES (HALLOWEEN KNIVES, Aura and Robux buttons). The rules below are unchanged. Shots `shop-halloween`,
  `shop-knives`.
- **CRATES:** two set crates, one per stand (Claude's reading of "the two crates"): **Witch's Brew Crate** (his 6
  Witch knives) and **Sweets & Treats Crate** (his 6 Candy knives). Same odds by rarity as the Halloween Crate
  (Common 46%, Uncommon 27.6%, Rare 16.1%, Epic 6.9%, Legendary 2.3%, Mythic 1.1%), pity 40 (a Legendary or the
  Mythic), 120 Aura an open. They have `Home = "HalloweenShop"`, which now only gives their card the HALLOWEEN tag and the
  Robux KEY (the 18-knife Halloween Crate has neither). Every chance and the pity counter show, as for every crate.
  Their picture is his own crate card (Oct 20 14:07, "make the halloween shop have the images of the crates from the
  ones i sent you before"), cut to the crate above his BUY, never recoloured: Witch's Brew = his Beast card (purple),
  Sweets & Treats = his Dojo card (red, lanterns), Claude's pick (`Config/HalloweenShop.Crates[].Picture`). His 3D
  crate stands in when it can't be drawn, as in Shop > CRATES.
  OPEN plays `Screens/CrateOpen`; its BACK returns to the Shop at that crate's card (every crate).
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
  `HuzzShopNotice` = "<n>|<line>", the Shop shows it as a toast; no new remote).
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
- **Gaps:** not seen in Studio; the Robux IDs are 0 and the prices are ours; the crate is his Beast / Dojo card picture, not
  his stand models; his coin shop also sells these
  four knives for coins (4,000 / 8,000), which is the cheaper way to get them, so Aura buyers pay more on purpose.
  The knife cards are pictures rendered from his own meshes (`assets/art/knife-*.png`), drawn by script until he
  uploads them; the knife you then hold is the server's plain stand-in, dressed as his .glb only where Studio allows
  Mesh / Image APIs, until he imports `Halloween_Knives.glb` ([knives.md](knives.md)). The "you got keys instead" line
  shows from the Shop screen (always built in the game; checked offline only).

## Admin panel (`Screens/Admin` + `HuzzServer/AdminService` + `Shared/AdminRules`)
- Only the game's owner: Studio, else `player.UserId == game.CreatorId` (a game he owns) or rank 255 in the creator
  group (a group game); no user IDs typed anywhere, the server checks every request (remote `Admin`, ActionService's
  0.15 s limit).
- Admins get a small ADMIN button bottom-left (Player attribute `HuzzAdmin`) opening KNIVES (GIVE: yours and worn) and
  GIRLS (SPAWN: yours and your companion, behind you at once; NEXT GAME: `GirlService.setNext`, the next roll lands on
  her, a Secret plays her cutscene). Spawning a girl loose mid-lobby doesn't fit the loop, so it's companion or next game.
- Checks `tests/AdminRules.spec` (a non-admin is refused), `tools/preview/check_admin.luau` (the real server).

## Honest gaps
- Abilities: the prices are Claude's first pick; the four new ones show glyphs until the owner sends pictures. Not
  seen in Studio yet.
- Not seen in Studio yet: stars in the playing zone, the spin animation, Crown Pose, Midnight cape, worn auras, the
  crate opening (its feel, the sounds' levels, the blur behind it).
- Not seen in Studio yet: daily quests, the winner page, friend rewards (need two real accounts), prestige effects.
- The friend knife is a placeholder (Sakura Blade, also sold and in the Shinobi Dojo Chest); a Mythic girl's prestige only
  shows as PRESTIGE N/3 (she already has the top look).
- Crates: contents, price and odds are Claude's first pick; the Starter and Dance crate pictures are drawn
  (stand-in); the sounds are our made stand-ins (no whoosh or riser of its own yet).
- His three knife crates: their real look (meshes, textures, glow) is only Studio's to judge: offline pictures draw his
  parts as boxes. Not seen in Studio: the 3D opening (the film draws his crate as boxes and darkens it by colour; only
  Studio shows his real meshes, how far `GlowKeep` 0.3 turns his EmissiveStrength down (pcall: nothing breaks if Roblox
  refuses), the knife's cut at the crate's edge in the ViewportFrame, the Neon rim's look, the backdrop on a phone screen,
  and the new sounds' levels), his picture cards in the Shop. The crate keys' Robux IDs are 0 and the 25 R$ is ours. His
  picture's crates (the Shop cards) are a concept render; the opening shows his model as he built it (the Dojo roof,
  the crystals, the jaw), so the two look a little different. His cards are a mockup at 2172 px: sharp enough at
  448 px, but his BUY buttons are part of the picture, so they don't light up or press down like our buttons.

## Why it is this way / history
- **Abilities for coins** (Oct 20 15:13: "make the abilities be bought ... make them well made, right now they are
  kind of quick and feel cheap"): coins, not Robux, so a kid can earn every one by playing (no pay-to-win); a starter
  per key so nobody enters a round empty-handed; old players keep the four they already had.
- The owner picked "Coin cosmetics shop" for coins.
- **Crates** (owner: "I will add them later"; Oct 19: "Also create a good case opening animation"). No crate mockup
  exists in `design/`, so the Shop card follows the COINS tab's tall cards and the opening screen the Spin wheel's
  1280 x 720 layout. Polish pass (owner, Oct 19: "also check the opening animations for the crates"), judged frame by
  frame against the best Roblox openings: the honest settle, the rails and odds framing the reel, a smooth glow
  (its beam burst went on Oct 20, "too ai"), the coins held, pink Legendary, sounds on the beats (rattle, pop, ticks, thunk, prize).
- **The 3D opening** went through two passes on Oct 20. 07:51: "Can you please make the opening animation of the crates
  feel more premium, right now it feels too ai, as now they have the circle around the knife when it opens, remove
  it, add s nice animation for the knife when it starts rising up from the crater" (the rays, ring, sparks, round
  light and Epic flash went; we kept his knife's aura ring then, which was the circle he meant). 15:13: "please make
  the case opening animation way, way better, right now its so vague and doesnt look good, remove so much glow from
  the crates, and then make it feel premium". "Vague" read as no clear moment: nine small jumps, a slow 1.6 s rise,
  a small knife over a bright glowing crate, tinted glow parts, motes and a glint. So: three heavy hops, a latch, a
  flung lid, the knife big and sharp on a dark backdrop, one colour for the rarity, the name punching in, his aura
  parts hidden and his crate's glow turned down to 30%. Critic pass on our own 10 fps sheets: the latch did not read
  (7 deg, now 11 with a jolt and a brighter line), the crate was small in the frame (camera nearer), the crate's
  title sat over the knife's tip (it now fades as the lid opens).
- **Oct 19 list:** "spin prices lower"; "knifes, dances, from crates"; "add easy quests as in this photo and make new
  ones everyday then recycle them"; "make friend rewards, add a friend knife (for inviting them) and add a 10% coin
  boost when a friend is in"; "if you get more than one of the same girl, make a button which makes them prestige
  that gives them cooler vfx". Duplicates kept their coins so nobody loses anything; the copy is extra.
- **Aura stars** (owner, Oct 17: "different colors give different amounts ... the ones that give more are rarer").
- **Admin panel** (owner, Oct 18: "give me a admin command panel or something so i can get any knife or any girl to
  spawn when i want it to do so").

## Earning speed and Robux IDs (Oct 21)
- Owner, Oct 21 17:25 / 17:34: all 11 Game Passes and 8 Developer Products have his IDs and prices (`Config/Products`).
  The 4 Halloween knives are Game Passes (`GamePass = true`): Roblox's pass prompt, given in `ShopService.refreshPasses`.
  No product left at Id 0 (the Spin packs came Oct 23 19:46, the 3 Shop crate keys Oct 23 21:10).
- "you get very quick aura and coins, so please pop it down a bit": Aura stars 4 out (was 7), back in 60-90 s (was
  25-45): ~550 Aura an hour at most (was ~1,900). Game pay 15 / 30 for a win (was 25 / 50). The wheel's coin and Aura
  slices about halved (keys unchanged: 50 / 100 / 250 / 500 coins, 15 / 40 Aura).

## Release check (Oct 22)
- **A Halloween knife pass for a knife you already own** gives that knife's crate keys once (`PassRefunds[pass]`, a
  shop notice). Knives given by a pass set `PassKnives[pass]`, so it never pays twice.
- **Pass refresh** keeps a pass that was true and re-merges other passes after its waits (two buys could overwrite).
  The join refresh waits 130 s.
- **Quest knife you own already:** its duplicate coins (`Crates.KnifeDuplicate`), and your worn knife stays. **Track
  dance you bought already:** its coin price back.
- Shutdown (`ProfileStore.IsClosing`) no longer kicks with a "session ended" message; Combine doesn't keep entries for
  players who left.
Not fixed: the leaderboard saves after the profile on leave (order), and big full-save updates may spike with many
players. Only Studio / the live game can confirm real pass timing and prompts.
