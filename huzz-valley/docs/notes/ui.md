# UI rules (UI lives in StarterGui as real parts: owner's call)

Read before building or changing any screen, the round HUD, text sizes, shine/rays effects or the shop's pass rows.
The look rules (Gotham, white text, no gold, green accent, see-through studded panels) are the owner's standing calls
in core `CLAUDE.md` section 1. Recipe for a new screen: core section 6. Preview tools: core section 4.

## Building
- Build with `Kit.new` / helpers and `Parent`; saved parts are reused by name ("twins"), and the saved look wins.
- Windows 701 x 320, one at a time (`ModalManager`). `Kit.button` adds shade, outline and stud texture.
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
  and Studio Play shows one red note bottom left (`ImageLoader.studioNote`). Set icons with `Kit.setIcon` /
  `Kit.setArt` (they clear the stand-in). A new icon needs a `GLYPH` entry (`check_pictures.luau` fails without).
  The preview hides stand-ins unless STUDIO=1 (Studio's look). One real miss found: ArrowNext was never packed
  (`pack_images.py` listed it as unused), so NEXT MAP's arrow was blank everywhere.

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
- Shop passes copy the owner's banners (`design/shop/pass-banners.png`): navy glass rows, coloured rim and button per
  pass (`Products` `Accent`, Kit styles `PassViolet` / `PassPink`). The knife pass cards: [knives.md](knives.md).
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
- Rarity colours on reward screens: the Spin wheel's (`Config/SpinWheel.RarityColors`, Legendary pink FF6FC0) through
  `CrateArt.color`. `Config/Round.Rarities` (Legendary orange 255,190,60) still colours the girls' screens and the
  Shop's ITEMS knife rarities (to change only when the owner says).
- Light beams without uploaded pictures: a rotated full-size frame per beam holding a bar anchored (0.5, 1) at the
  centre with a UIGradient fading towards its tip (the preview draws frame gradients, not image gradients). A soft glow
  is many faint layers a few px apart (8 x 0.88 see-through), not 2 or 3 strong ones (those read as bands).

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

## Oct 17 screens
- Shop ITEMS/COINS, DANCES and HOW TO PLAY (`Screens/HowToPlay`, was `Welcome`: first join + Menu) built from the
  `design/ui-oct17` mockups (`docs/previews/*-vs-mockup.jpg`, `tools/preview/side_by_side.py`, checks in
  `tools/preview/check_oct17.luau`). Their pictures are mockup crops (placeholders): ask for sharp PNGs. Not seen in
  Studio yet.

## Honest gaps
- Not seen in Studio yet: the Oct 17 UI shine/rays/spin, the Oct 17 screens, the winner page (real avatars), daily
  quests, the HUD's INVITE / QUESTS / "+10% COINS", the Index PRESTIGE button, the picture stand-ins.

## Why it is this way / history
- **Text fit** (owner: "the rarities ... go out of the uis borders").
- **Living UI** (owner: "more effects, like shining, spinning ... like in the game pass sections").
- **Message colour:** the owner asked for the switch; earlier he wanted white everywhere.
- **HeroChoice** at 60%: "make the boxes smaller". The text-only HUD and the message line came from the feel study
  (Oct 17); "less ui" (Oct 17 round 2) moved the HUD aside while running.
- **Map pictures** (owner Oct 18).
