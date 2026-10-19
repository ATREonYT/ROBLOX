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

## Other round screens
- `Screens/HeroChoice` (60% size), `Screens/NextMap` (your vote tucks into a NEXT MAP panel).
- Map pictures: `Config/Round` `Map.Pictures` names the `Config/Assets.Art` picture per map folder
  (Base/Halloween/BasketBall from `design/maps/`, packed 512 px, Play only until uploaded); a map not listed shows its
  live 3D view.
- `Screens/Results`: [round.md](round.md). Admin: [economy.md](economy.md).

## Oct 17 screens
- Shop ITEMS/COINS, DANCES and HOW TO PLAY (`Screens/HowToPlay`, was `Welcome`: first join + Menu) built from the
  `design/ui-oct17` mockups (`docs/previews/*-vs-mockup.jpg`, `tools/preview/side_by_side.py`, checks in
  `tools/preview/check_oct17.luau`). Their pictures are mockup crops (placeholders): ask for sharp PNGs. Not seen in
  Studio yet.

## Honest gaps
- Not seen in Studio yet: the Oct 17 UI shine/rays/spin, the Oct 17 screens.

## Why it is this way / history
- **Text fit** (owner: "the rarities ... go out of the uis borders").
- **Living UI** (owner: "more effects, like shining, spinning ... like in the game pass sections").
- **Message colour:** the owner asked for the switch; earlier he wanted white everywhere.
- **HeroChoice** at 60%: "make the boxes smaller". The text-only HUD and the message line came from the feel study
  (Oct 17); "less ui" (Oct 17 round 2) moved the HUD aside while running.
- **Map pictures** (owner Oct 18).
