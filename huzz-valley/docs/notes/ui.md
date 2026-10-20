# UI rules (UI lives in StarterGui as real parts: owner's call)

Read before building or changing any screen, the round HUD, text sizes, shine/rays effects or the shop's pass rows.
The look rules (Gotham, white text, no gold, green accent, see-through studded panels) are the owner's standing calls
in core `CLAUDE.md` section 1. Recipe for a new screen: core section 6. Preview tools: core section 4.

## Building
- Build with `Kit.new` / helpers and `Parent`; saved parts are reused by name ("twins"), and the saved look wins.
- Windows 701 x 320, one at a time (`ModalManager`). `Kit.button` adds shade, outline and stud texture.
- **Windows step aside for the round** (bug hunt, Oct 20): a full window closes when you become a runner or catcher,
  or the line-up starts for you (`ModalManager.watchRound` / `roundWants`); the Menu side panel stays, except for the
  runner picked for HERO/CHICKEN (Picking with your PickId), so the pick always shows. A player watching from the
  lobby keeps their window. Before, an open Shop hid the whole round HUD (RoundHud is off while a full window is open)
  and the kid missed the countdown and the pick.
- **Escape** closes a window whether or not Roblox already handled the key (its own menu takes Escape), and so does
  Roblox's menu opening (`GuiService.MenuOpened`). Gamepad B too.
- **Never use CanvasGroup for animation** (it lagged). Fade with scale/position tweens instead.
- **Rounded corners:** Lune writes `UICorner.CornerRadius` only under newer per-corner names that Studio may not read,
  so the build also stores the size in attribute `HuzzRadius` and `HuzzClient/Main` restores it at start.
- Roblox gotchas the preview won't show: whole-pixel offsets; ClipsDescendants ignores UICorner; never key weak tables
  by Instance; picture names are case-sensitive; guard APIs Lune lacks (`Sound.Ended`, `CharacterAppearanceLoaded`,
  `LoadAnimation`, `ViewportFrame.CurrentCamera` reads) with `pcall`.
- Icons/art: the owner's files, used as drawn (`tools/icons/pack_images.py`, icons packed at 192 px).
- **Why pictures go missing in his Studio** (Oct 19, "make the icons appear for everything in the ui"):
  `Config/ImageIds` is empty (nothing uploaded yet), so every picture is drawn by `ImageLoader` with EditableImage,
  which needs Game Settings > Security > "Allow Mesh / Image APIs" on a published game; Studio's edit view shows
  uploaded pictures only (ShowPictures plugin). One fix for him: STUDIO-STEPS Part 1 (top note there).
  Until then: a picture that can't be drawn gets a stand-in (`ImageLoader.standIn`: an emoji per icon from `GLYPH`,
  a TextLabel named NoPicture, removed the moment the picture shows or is uploaded; never saved into HuzzUI.rbxm),
  and Output gets one `[HuzzUI]` line with the fix (no box on screen: owner, Oct 19, "please remove the red pop up";
  the old Studio note was removed in the Oct 20 bug hunt). Set icons with `Kit.setIcon` /
  `Kit.setArt` (they clear the stand-in). A new icon needs a `GLYPH` entry (`check_pictures.luau` fails without).
  The preview hides stand-ins unless STUDIO=1 (Studio's look). One real miss found: ArrowNext was never packed
  (`pack_images.py` listed it as unused), so NEXT MAP's arrow was blank everywhere.
- **Picture memory** (Oct 20 14:07, owner: "please fix all of the placeholders for knifes, coins": in Play Ember Edge,
  500 Coins and the Halloween knives drew, most ITEMS knife cards showed the kitchen-knife emoji and 2,000 / 5,000
  Coins an empty box). Cause: Roblox gives each screen a fixed EditableImage memory budget (shared with KnifeDress's
  EditableMeshes); past it `CreateEditableImage` gives nil. The old loader drew every picture as soon as a screen was
  built (seen or not, nothing ever freed), then hit `nil:WritePixelsBuffer`, kept that picture as "can't draw"
  forever, and its one `[HuzzUI]` line blamed the Security setting. The pictures that failed are packed under their
  exact names, the same size and format as ones that drew (`check_pictures`), so the budget was the only per-picture
  failure left. Now `ImageLoader` (header) draws a picture only while a label of it is on screen (its gui on, every
  frame up to it Visible, inside a scrolling list's view or half a list's height of it), one a frame; counts the
  labels of each picture (all gone: freed; none on screen for 30 s: freed); frees the longest-unseen picture to make
  room when the budget is full; retries a failure after 5 s, doubling to a minute. A knife card that still can't be
  drawn shows its own 3D model in a ViewportFrame (remote `KnifeView`: `HuzzServer/KnifeGlbService` puts a plain copy
  from `KnifeService.view`, one copy a knife for the whole server in `ReplicatedStorage > HuzzKnifeViews`). The empty box was the coin emoji (U+1FA99,
  too new for Roblox's font): coins now use a money bag, the Bear Trap a bear (its mouse-trap emoji was too new as
  well). `[HuzzUI]` now says which it was: the setting, or the memory. Test: `tools/preview/smoke_picture_memory.luau`
  (a fake budget of 100: every ITEMS knife card and coin pack draws after other screens filled it; a failure retries;
  a picture nobody shows is freed). Studio only: the real budget's size and how many cards fit at once.

## Text must fit its box
- Never leave a name or chip on AutomaticSize in a row with no width cap. `Kit.textWidth` (TextService, else a
  Montserrat estimate), `Kit.fitLine(label, maxW, size, min, keepBox)` (shrink, then "..."), `Kit.fitBlock` (two
  lines), `Kit.badge` (rarity chip, measured and capped). Set sizes after `Kit.new` (saved twins keep their saved look).
- The Index preview gives the name the whole 128 px column and puts the rarity chip on the picture's top-right corner,
  like the cards.
- Check: `tools/preview/overflow.sh` (in `check.sh`; `overflow.js` flags text past its box, window, panel or the
  screen, and text on text, on every `shots.sh` screen plus the long-name shots `index-girls*`, `tiers-girls`,
  `*-long`). The preview draws TextScaled with its UITextSizeConstraint and TextTruncate.

## Shop passes and living UI
- Shop passes: since Oct 20 14:31 the video's cards and wide rows ("The Shop" above); the old navy pass banners
  (`design/shop/pass-banners.png`) are gone. The knife pass cards: [knives.md](knives.md).
- **Living UI** (`UI/Effects`): `shine` (white streak every 4-5 s: pass rows, buy buttons, coin cards, the HUD Shop
  button), `rays` (our `assets/art/light-rays.png` turning behind the Spin wheel, and green behind the HUD Spin button
  while a free spin waits; its icon spins and FREE breathes), plus the knife cards' `pulse`, `motes` and `lift`.
  Parts are saved twins but invisible until the loop starts; Reduced Motion stops all (`Effects.setCalm` from Main).
  Previews park streaks off the edge; `SHINE=0` freezes mid-sweep.
- Colours kept as the kit (Huss Valley look): the owner left a palette switch optional.

## Round HUD (`Gameplay/RoundHud`, built by code at runtime, not a saved twin; `docs/previews/feel-ui-after.jpg`)
- Text only at the top like Huss Valley, IgnoreGuiInset: "ROUND 2 · 1 OF 3 IN A ROW" (14) in Roblox's top-bar row
  (y 5-20 of 720, centred), the message line (Gotham Heavy, TextScaled 14-27 in a 512 x 28 box = 40% wide, 3 px dark
  outline, no panel, instant swap; outside a game it shows 5 s below the NEXT ROUND plate), "Runner · 0:21" (14, ends
  y 62 = 8.6%; HV 8.8%), a help line only in the player's very first round. Big banners only for big moments.
- **`Theme.MessageColour`** (default true) colours the message words; false = always white.
- Big words at y 194 of 720 (27%); 3-2-1-GO drawn each frame from EndsAt (pop 1.4 to 1 in 0.15 s, fade by 0.94 s; GO!
  green 124; the wait after a camera shot: [round.md](round.md)).
- The prize card sits under the top bar, hidden in Countdown/HeroRun/Running. While running the prize card, the gear
  (not on touch: no Menu key) and Roblox's player list step aside.
- Own name tag faded, hidden in camera shots (`HuzzCinematic`/`HuzzChoosing`; a HERO/CHICKEN word stays, except during
  3-2-1-GO) and from HeroRun through RoundOver (it sat where the centre words print). Outlines 0.55 see-through, no fill.
- Today's Girl roller (`Screens/GirlRoll`): right edge under the gear, 0.5 of a window.
- Check: `tools/preview/check_round_hud.luau`; shots `round-hud-runner`, `round-count`; picture `feel_ui_after.py`.

## Timed reward screens (Spin wheel, crate opening)
- Laid out at 1280 x 720 (a `FitScale` holder like a window), plain frames, never a CanvasGroup.
- `Screens/CrateOpen` drives every moving part from one RenderStepped loop and its own clock (`clock += dt`), never
  `os.clock()` or `task.delay`, so the offline film (`crate_film.sh`, which fires RenderStepped at 1/30 s) plays
  exactly as the game. Reel cards are made per open (not saved twins); everything else is a saved part.
- Big flashes go through one guard (at most one a second); "tap to skip" is a full-screen see-through button that only
  shows while it runs. The harness doesn't fire attribute signals by itself: checks call `__fireOn(p, "Attr_<Name>")`.
- **Don't spoil the prize:** the save updates the moment the server rolls, so a screen that animates to a result holds
  the HUD's number until it shows: `State.hold("Coins")` before the call, `State.release("Coins")` at the reveal, on
  failure and on close. Pills that show a held number read `State.shown(key)` (LobbyHud and Shop coin pills), never
  `State.data` directly. Aura isn't held: the price is paid at OPEN and showing that at once is honest.
- **Closed while the server answers** (X, Escape, the map vote, a round starting): `CrateOpen` sees the window went
  (a close counter) and shows the prize as a toast instead of playing the reel in a hidden window (bug hunt, Oct 20).
- Check for these and the round-start closing: `tools/preview/check_bughunt.luau`.
- Rarity colours on reward screens: the Spin wheel's (`Config/SpinWheel.RarityColors`, Legendary pink FF6FC0) through
  `CrateArt.color`. `Config/Round.Rarities` (Legendary orange 255,190,60) still colours the girls' screens and the
  Shop's ITEMS knife rarities (to change only when the owner says).
- Light beams without uploaded pictures: a rotated full-size frame per beam holding a bar anchored (0.5, 1) at the
  centre with a UIGradient fading towards its tip (the preview draws frame gradients, not image gradients). A soft glow
  is many faint layers a few px apart (8 x 0.88 see-through), not 2 or 3 strong ones (those read as bands).

## Ability cards and the dash bar (`Screens/PowerBar`, a saved twin in `HuzzUI.rbxm`)
- Owner Oct 19: "abilities above a clean, nice dash bar which shows the reset", one-to-one with his pictures
  `design/owner-oct19/pic-b-catcher-bar.png` (catcher) and `pic-c-runner-bar.png` (runner).
- **Measured in his pixels** (his screenshots are crops of a 1920-wide screen: the bar is 886 px, 46% across), laid out
  in those pixels (`P` in PowerBar) under one UIScale = `Scale.touchMin(Scale.hud(347) / 1.375, 0.6, 886)`, so at 1920
  wide one of ours is one of his:
  - bar 886 x 11 outline box (1 px black outline, a pill), 20 px over the screen's bottom; fill 884 x 9: green
    78,248,97 → 58,187,73 when Space is ready, grey 216 → 162 filling back up while it charges ("shows the reset"),
    amber while stunned or stuck;
  - state over the left end (CATCH READY / DASH PAUSED...: Gotham Bold 17, caps 12 px tall, 10 px over the bar), help
    line over the right end (Medium 17, DEDEDE, right end 3 px in), key line centred (PRESS SPACE TO CATCH / SPACE ·
    DASH: Heavy 21, stroke 1.5; white for a catcher, DEDEDE for a runner, as in his two pictures); a catcher's
    ATTACK at x 671 and the mouse (32 x 48 at x 772, y -68), greyed while the knife charges;
  - cards 194 x 77 (192 x 75 + a 1 px rim, corner 8), bottom 116 px over the bar, 10 px apart, centred: fill 23,37,31
    shading half-way to the ability's colour at the right, icon 72 x 72, "ABILITY" 9, title 13 (white when it can be
    used, 180,181,181 otherwise), status 10 in the ability's colour at y 46, a 171 x 3 line at (10, 66) that fills as
    it charges.
- **Card text:** WAIT FOR ROUND (on the line), Q · LET'S GO!, READY IN Ns, ON · Ns (Shield, Invisible), USED THIS
  ROUND (Shield), STUNNED / STUCK (the server refuses abilities then).
- **Bar states:** catcher DIVE PAUSED, STUNNED 💫 (the dive's 0.4 s stun draining), DIZZY 💫, KNIFE CHARGING (the 1 s knife
  charge, `KnifeReady` set by `Gameplay/Actions`), DIVE RECHARGING, CATCH READY; runner DASH PAUSED / "Waiting for
  movement", STUCK! / "Caught in a bear trap", DASH RECHARGING / "Ready in 1.0s", DASH READY.
- **How many cards:** a runner has one (this round's Q ability, like picture c: the one they bring, or Random) plus
  Speed Boost on E only while carrying the girl; a catcher has two (the two they bring; Bear Trap Q, Slow Wave E to
  start): picture b shows one, so the second card is ours. A card back from its cooldown chimes (`power_ready`) and
  its rim glows a moment. The picture is his own power picture in its tile (65 x 65, rounded, a 2 px rim in his tile's
  colour, `Config/Powers` Tile), with ABILITY, the title, the state and the line beside it instead of over it (owner,
  Oct 20 20:34: "bring back the old pictures for the powers. Right now this is a bare copy of huss valley. We want to
  stand out"). Before and after: `docs/previews/power-bar-his-pictures.png` (shot `power-bar-banana` too).
- **Shop > ABILITIES** (Oct 20; the Menu keeps its 7 rows: an 8th "Abilities" row pushed MENU off a 658 px screen,
  critic): `UI/AbilityCards` in the Shop's slot: a "YOU BRING" line, then the cards (116 high, two columns: his
  picture in its rounded tile, rimmed in its colour, name, STARTER / OWNED, what it does, "Beat it: ..." on up to two lines,
  the cooldown in its colour, then a coin BUY button, EQUIP / EQUIPPED, or Q and E that glow green when that key holds
  it). Shot `shop-abilities`. Rules: [economy.md](economy.md).
- Side by side: `docs/previews/ability-bar-vs-owner.png` (`tools/preview/side_by_side_bar.py`, which also prints each
  text box's position in his pixels next to ours: within 1 to 3 px, the state 3 to 6 px wider: Gotham, his font looks
  like Montserrat). Shots `power-bar`, `power-bar-catcher`, `power-bar-stunned`, `power-bar-carrying`,
  `power-bar-cooldown` (the scene's clock is fixed: `_G.__serverClock`).
- Icons: his 11 power pictures (Random and the 10 he drew, Oct 20 20:34), cut from his sheet
  `design/owner-oct20/2034-ablt1-powers-and-crates.png` by `tools/icons/cut_power_tiles.py`: from inside each tile,
  his name cut off (our cards print it), 164 to 171 px square, his art as it is. Under 192 px, so a little soft on his
  Retina screen: 256 px PNGs from him would be sharper. Speed Boost isn't on his sheet: it keeps our three.js render
  (`tools/icons/ability_icons.mjs`, now that one only) on a tile in its colour. Drawn in Play only until uploaded; the
  emoji shows if a picture can't be drawn.

## Other round screens
- `Screens/HeroChoice` (60% size), `Screens/NextMap` (your vote tucks into a NEXT MAP panel).
- Map pictures: `Config/Round` `Map.Pictures` names the `Config/Assets.Art` picture per map folder
  (Base/Halloween/BasketBall from `design/maps/`, packed 512 px, Play only until uploaded); a map not listed shows its
  live 3D view.
- **Winner page** (`Screens/Results`, his picture a's top half one to one in our look; what it shows: [round.md](round.md)):
  701 x 334, header 58 with the title centred (Gotham Heavy Italic 27), the tab's line under it in his pink-red, "Next
  match · 12s" left (only with a real `NextRoundAt`). Tabs at y 64 (113 wide), cards measured off his picture at
  0.649: #2 (38, 96, 191 x 130), #1 (241, 90, 219 x 142, green rim), #3 (472, 96). Avatars:
  `Players:GetUserThumbnailAsync` (AvatarBust 180, pcall, cached per user) over a person icon; Studio's test players
  have no avatar (negative ids), so they keep the icon. His orange/gold (#1 rim, numbers, bar) is our green. The
  JOURNEY / PREMIUM half is left out (a paid season pass we don't have). `docs/previews/winner-vs-pic-a.jpg`.
- **Daily quests** (`Screens/DailyQuests`, his picture d): 520 x 452, rows 488 x 88 at y 110 (gap 8); reward words in
  the Spin wheel's purple with the reward's icon; IN PROGRESS (Slate) / CLAIM (green) / CLAIMED (dim).
  `docs/previews/daily-quests-vs-pic-d.jpg`. Rules: [economy.md](economy.md).
- **HUD right column:** INVITE (y 66), SPIN (132), QUESTS (198, green "!" while one is ready); centred-anchored
  buttons keep their own Y when mirrored. "+10% COINS" (purple) over the coin pill with a friend in, stacked over
  the green x2 tag when both show.
- Admin: [economy.md](economy.md).

## The Shop (`Screens/Shop`: one page since Oct 20 14:31; the golden slice, other menus wait for his yes)
- **Oct 20 20:34 rework (owner):** "remove the two crates that dont have pictures, the starter one, and then make a
  seperate section for dances ... make them be able to be bought there. Then can you please remove all of the chances
  of the knifes, only show it when you click on a crate, then on the side it pops up. And also, make the knifes not be
  bought but opened from crates. So remove the buying menu ... keep the halloween knifes, and put them on the top of
  the shop ui, and then also make a halloween style ui look, also animate the ui more ... make all of the crate
  pictures have the same background ... make the ui for the shop colour match our ui. But keep the layout". What
  changed (the layout, sizes, jump column and filters below stay):
  - **Sections:** HALLOWEEN (the featured Halloween Crate, his Candy / Witch / Halloween crates, HALLOWEEN KNIVES),
    CRATES (Dojo, Storm, Beast), DANCES (the Dance Pack banner, then every dance with a coin price: small cards with
    the dance's still swaying), KNIVES (only the knives you own, WEAR / WEARING; rarity chips and "Search your knives";
    no OWNED chips; with none owned the line says "No knives yet. Open a crate to get one!"), ABILITIES, PASSES (knife
    passes and VIP), AURA, COINS, COSMETICS. Jump buttons: HALLOWEEN orange, CRATES kit purple, DANCES pink, then as before
    (9 buttons, 49 apart, the last ends at y 518 inside the 550 window).
  - **No odds on the page.** Tapping a crate (its card, its OPEN, the banner) slides its **panel** in from the right
    over the page (520 wide, the page dims behind it; tap beside it or its X to close): his crate on the backdrop, the
    pity ("GUARANTEED LEGENDARY / IN n OPENS OR SOONER"), keys you have, EVERY CHANCE (2 columns, scrolls when long)
    and the only buttons that pay: coins + Aura (his Halloween crates), OPEN for Aura (his knife crates), a Robux KEY
    where it has one; a key turns the first button into USE KEY (n). So the odds are always on screen when a kid pays.
    A stand, or BACK from an opening, opens the Shop at that crate with its panel in. A dance's card slides in the
    same panel with a preview (your avatar dancing it, as the Dances window does, wherever its animation can play:
    in Studio, or once the owner publishes the dances; otherwise its still swaying to a beat), its line and BUY / YOURS!.
  - **One backdrop for every crate:** a deep purple stage (2B1352 / 3D1A6B / 150829), a warm orange glow behind the
    crate, a soft floor shadow and a thin orange rim, drawn from frames; on it his crate cut out of his own picture
    (`assets/art/crate-card-cut-*.png`, `tools/crates/cut_crates.py`).
  - **Colours: our kit's.** The window is Kit.window as it comes (the purple studded title bar, the see-through navy
    studded body), the title still FredokaOne; cards navy (2A4276 to 1A2A52, rim Theme Frame); buy buttons the kit's
    green (SelectedTab), Robux buttons the kit's purple (Action), Aura buttons blue (2A9FD8). **Halloween touches:** an
    orange line under the title bar, a pumpkin and two bats (emoji text, the bats rocking) beside the title, the
    HALLOWEEN cards deep purple with orange rims and orange OPEN buttons, orange embers rising on the featured crate.
  - **Motion** (his video `1425-shop-reference.mp4` only scrolls; this is the coordinator's list): the cards in view
    pop in one after another when the Shop opens (0.8 to 1 with a small overshoot, 0.05 s apart); every crate rocks
    gently (2.5 degrees, 1.6 s); the featured crate's shine sweeps every 6 s (never more than one flash a second) and
    its OPEN breathes; cards lift a little under the mouse; buttons squish on press (Kit); the panel slides in (0.38 s)
    and out (0.22 s). Reduced Motion stops all of it. Film: `tools/preview/shop_film.sh` ->
    `docs/previews/shop-oct20-2034-motion.mp4`.
  - Checks: `check_crates` (no odds on the page, every crate on the same backdrop with his picture, the panel's
    chances / pity / buttons, coins and Aura opens, knives refused for coins), `check_halloween` (stands open the
    panel, KEY, USE KEY), `check_filters` (owned-only KNIVES, the jump order, DANCES: cards, panel, BUY, server
    refusals), `check_crate3d`, `check_oct17`. Shots: `shop-top`, `shop-halloween` (the Witch panel in), `shop-crates`,
    `shop-dances`, `shop-dance-panel`, `shop-knives`.
- *(The bullets below are the Oct 20 14:31 to 15:13 state: still true for the layout and the filters.)*
- **Owner, Oct 20:** 14:25 "also make our ui shop and in general make it like that, based of this" (his reference
  video `design/owner-oct20/1425-shop-reference.mp4`, frames `1425-shop-ref-*.jpg`); 14:31 "can you make the shop
  more logical, make it not so spread out as it is, make it all logically connected an all close to eachother, like
  other games, make the ui logical layout also way better". 15:13 "add filters within the ui so people can find
  trails, titles, knifes easier".
- **Layout, as in the video:** one window (869 x 550, title bar 77, red X 73 square) and ONE scrolling page; a column
  of jump buttons right of the window (128 x 43, 49 apart, from y 83; words 30), each its section's colour (CRATES
  orange, KNIVES purple, ABILITIES pink, PASSES blue, AURA teal, COINS green, COSMETICS blue: the video's EGGS /
  POTIONS / PASSES / CODES / MONEY / SPEED colours); the button of the section at the top wears a white rim. Sections in order: a featured banner
  (the Void Beast Chest: a real crate, no timer, no "one-time offer"), CRATES (every crate, then EVERY CHANCE: each
  crate's full odds), KNIVES (filters, coin knives by rarity, then HALLOWEEN KNIVES for Aura or Robux), ABILITIES (a slot
  for the bought abilities: `UI/AbilityCards.build(slot)` fills a 795 px wide frame and returns its height; until that
  module exists, or if it errors, the section and its jump button hide and the column closes up), PASSES (the 5 knife
  passes, then VIP and the Dance Pack as wide rows), AURA, COINS, COSMETICS (filters, Robux looks, then FOR COINS). No codes
  (we have no codes system) and no gift button (no gifting).
- **Sizes** are the video's at 0.8 (his window is 1086 px wide at 1280): content 795 wide; big cards 251 x 338, 14
  apart, 3 to a row (bold title 37, picture 152 high, one line 18 + a small line 13, green price button 54 high);
  small cards 149 x 224, 5 to a row (coin knives, coin looks); Halloween knives 189 wide, 4 to a row; section header
  95 with its word at 58 in a two-tone gradient; a short last row is centred. Whole pixels only (check_oct17).
- **Look:** charcoal title bar (1E1E20 to 131315), "Shop" 50 in chunky white with a dark outline; the page his solid
  mid green 264F31 (measured the same in every frame; 0.06 see-through; it read brown over the world before); solid
  saturated cards (top-to-bottom gradients 317019/17441A and 1D587A/0F3448, near-black rims); green price buttons
  (3FCC12, Robux mark + price; violet for Robux next to an Aura price), studded like his (stud texture 0.42, Kit's
  buttons 0.22), every button word with a solid dark outline. **Font: FredokaOne** (Roblox's built-in rounded heavy
  font, the closest to the video's): the Shop only, so this overrides the Gotham rule for the Shop (his newer call).
  Coins and Aura pills stay in the title bar (the video has none; ours have the +).
- **Where it opens:** every way in names a section (`ModalManager.open("Shop", key)`: a section, or a crate id for
  its card): the HUD Shop button opens the top; Coins "+" COINS; every Aura "+" AURA; WITCH'S BREW / SWEETS & TREATS
  their crate's card (no separate Halloween window any more: [economy.md](economy.md)); BACK from a crate opening
  returns to that crate's card. The page jumps without a tween when it opens and glides on a jump button.
- **Filters** (15:13): right under the KNIVES header, rarity chips (ALL, COMMON, UNCOMMON, RARE, EPIC, LEGENDARY,
  MYTHIC: each dark with words in its rarity colour, filled with a white rim when picked), then OWNED / NOT OWNED (tap
  again for both) and a search box ("Search knives", any case, an X clears it). Under the COSMETICS header: type
  chips (ALL, TRAILS, TITLES, NAME COLOURS, AURAS), OWNED / NOT OWNED and rarity chips (ANY RARITY, LEGENDARY,
  MYTHIC, SECRET: the rarities its looks have), over both the Robux looks and FOR COINS. Chips are 40 px high (touch),
  words 19 (smaller only if a row must fit 795). A tap shows only what matches at once: the grid closes up (rows of
  5, a short row centred), a rarity header with nothing under it hides, "No knives match..." shows only when nothing
  does. What you picked stays for the session (closing the Shop keeps it). The KNIVES filters cover the Halloween
  knives too. There is no separate inventory screen: the Shop's WEAR / WEARING is where you put on what you own (the
  girls' Index has its own search and tier filter).
- **Rules kept:** every chance shown (EVERY CHANCE, and the "i" on a card scrolls to it), pity on every crate card,
  Id 0 = "coming soon" and never a prompt, grants only on the server, UI saved into StarterGui (cards made once).
- Checks: `check_oct17` (jump buttons, order, banner, COINS/AURA cards), `check_filters` (chips, search, OWNED,
  tidy grid, remembered, COSMETICS types, ABILITIES hidden / shown with a builder), `check_crates`, `check_crate3d`,
  `check_halloween`, `check.luau` (pass cards). Shots `shop-top`, `shop-crates`, `shop-halloween`, `shop-knives`,
  `shop-filter-knives` (EPIC picked), `shop-filter-cosmetics` (TRAILS picked), `shop-passes`, `shop-aura`,
  `shop-coins`, `shop-cosmetics` (2560 x 1408 at SCALE 2.5 = his video's 1280 x 704 halved). Side by side:
  `docs/previews/shop-oct20-1425-vs-video.jpg` and, with the filters, `docs/previews/shop-oct20-1513-filters-vs-video.jpg`
  (`tools/preview/shop_vs_video.py`).
- **Gaps (vs the video):** a gift button by each price (we have no gifting); his banner is a full-width picture (ours
  is his crate on a violet card); his card pictures are big bright renders, ours are his knife renders, darker and
  smaller on the card; with ALL picked the KNIVES section is still long (about 47 coin knives: the chips are how to
  narrow it); the filter chips are ours (the video has none). Not seen in Studio.

## Oct 17 screens
- Shop ITEMS/COINS, DANCES and HOW TO PLAY (`Screens/HowToPlay`, was `Welcome`: first join + Menu) built from the
  `design/ui-oct17` mockups (`docs/previews/*-vs-mockup.jpg`, `tools/preview/side_by_side.py`, checks in
  `tools/preview/check_oct17.luau`). Their pictures are mockup crops (placeholders): ask for sharp PNGs. Not seen in
  Studio yet.
- The Shop's tabs are gone since Oct 20 14:31 (one page, above). His crate pictures never show ImageLoader's glyph:
  `UI/CrateArt.hisPicture` puts his 3D crate in their place (economy.md).

## Honest gaps
- Not seen in Studio yet: the Oct 17 UI shine/rays/spin, the Oct 17 screens, the winner page (real avatars), daily
  quests, the HUD's INVITE / QUESTS / "+10% COINS", the Index PRESTIGE button, the picture stand-ins, the ability cards and dash bar
  (Oct 19: their icons draw in Play only until uploaded).

## Why it is this way / history
- **Text fit** (owner: "the rarities ... go out of the uis borders").
- **Living UI** (owner: "more effects, like shining, spinning ... like in the game pass sections").
- **Message colour:** the owner asked for the switch; earlier he wanted white everywhere.
- **HeroChoice** at 60%: "make the boxes smaller". The text-only HUD and the message line came from the feel study
  (Oct 17); "less ui" (Oct 17 round 2) moved the HUD aside while running.
- **Map pictures** (owner Oct 18).
