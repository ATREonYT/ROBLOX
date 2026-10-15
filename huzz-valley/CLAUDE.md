# Huzz Valley: project memory

A Roblox game based on Huss Valley: rounds where players steal and hold the lead, plus collectible anime companions ranked in tiers (Sub1, Sub3, Sub5, MTB, HTB, Stacy, True Eve), dances, quests and cosmetics. Work on the branch the session names (`HUZZ-VALLEY` so far).

**Gameplay doesn't exist yet.** Only the UI golden slice and its backend are built: saving, coins and gems, shop purchases and settings.

## Design authority
- The design kit is in `design/`:
  - `approved-original.png` is the approved look;
  - `pages/01-18` are the page references and `annotated/` the numbered positions;
  - `specifications/PAGE-POSITIONS.md` has the target rectangles;
  - `IMPLEMENTATION-PROMPT.md` has the full rules;
  - `CHARACTER-REPLACEMENT-MAP.md` has the model slots.
- Read only the page you're building.
- **Colours:** purple header with faint square studs; peach selected tab, navy inactive; periwinkle actions (never green); slate for done or disabled; small red close square.
- **Fonts (the owner's table; don't change them):**
  - window headings: Montserrat Black (Heavy) in caps with a thin dark outline;
  - names and product titles: Montserrat Bold, no outline;
  - tabs: Roboto Condensed Bold, in caps;
  - buttons: Roboto Condensed Bold with a minimal outline;
  - descriptions: Roboto Condensed Regular;
  - prices, currencies and XP: Montserrat Bold;
  - search fields and small labels: Montserrat Medium.
  - All of these live in `UI/Theme.lua` as `Theme.Fonts`.
- **Every colour and size is measured** from the references (the critic report's numbers are in `UI/Theme.lua`). Every main window is 701 x 320 (the owner asked for one size), so Settings no longer resizes per tab.
- **Robux prices:** every Robux price wears the Robux badge: U+E002, Roblox's own Robux mark, in dark navy before the number. Never use the kit's mockup hexagon (not official).

## Code map (`src/`, Rojo)
- `ReplicatedStorage/Shared`:
  - `Net` (every remote);
  - `Format`;
  - `Config/Products` (shop items: Id 0 = not created; `OnSale = false` = shows SOON);
  - `Config/Settings` (defaults and validation);
  - `Config/Assets` (icon IDs; empty until imported).
- `ServerScriptService/HuzzServer`:
  - `Bootstrap` (also makes the Master/Music/Effects SoundGroups);
  - `DataService` (ProfileStore; all changes go through `update()`);
  - `ShopService` (receipts and passes);
  - `SettingsService` (`allows()` answers social permissions, so any inventory or invite feature must call it);
  - `CosmeticsService` (trail and aura on the character).
- `StarterPlayerScripts/HuzzClient`:
  - `Main` (starts everything; applies audio, reduced motion, menu key and the VIP chat tag);
  - `UI/Kit` (the only component set: window, tabs, button, pill, segmented, slider);
  - `UI/ModalManager` (one window at a time; the player's `MenuOpen` attribute tells gameplay to ignore menu clicks);
  - `UI/Screens/*`.
- `StarterGui/HuzzUI.rbxm`: the whole UI as real parts the owner edits in Studio. It is **generated**: `build_place.sh` builds the UI from the scripts and saves it there. Never edit it by hand.
- **Sizes are reference px** (as measured on the 768-wide pages). `UI/Scale.lua` applies one UIScale per window, about 1.82x at 1920x1080.

## Checks and previews (run before every commit)
- Put Lune on PATH: `/root/bin/lune`, or download 0.10.5 to `/root/bin`.
- `sh tools/preview/check.sh` runs all three check files and must show 0 failed (39 + 34 + 29, plus 37 built from nothing, at the time of writing).
- `NODE_PATH=/opt/node22/lib/node_modules sh tools/preview/shots.sh <outDir> [names]` renders each screen under its reference page at 2x. Names: shop-passes, shop-cosmetics, shop-coins, settings-social, settings-audio, settings-controls, menu, lobby-hud, dances, index, progression, quests, tiers.
- Copy the ones that changed to `docs/previews/` as JPEG.
- The renderer approximates Roblox:
  - the Robux glyph draws small;
  - the avatar is a grey stand-in;
  - icons come from `assets/icons` even before they're imported.
- **Packed picture names** come from the file names (`tier-crown-mtb` → `TierCrownMtb`), so code must use that spelling. The renderer finds files without caring about capitals, so a wrong name only shows up in Studio; `check_index_tiers` checks the crowns.
- **Pictures (`assets/art`) and 7 icons** come from the owner's sharp pack `design/sharp/Huzz-Valley-UI-Sharp.zip` (see-through renders, 1254 px squares), brought in by `python3 tools/icons/import_sharp.py`. That script only frames each picture to its slot's shape (top crop, centre crop or fit with margins) and sizes it to 2x the slot (crowns 3x). The name map and slot shapes are in the script. The pictures have no backgrounds, so cards draw a blue gradient behind them. Card pictures have no printed badges or stars, so badges are live, in one spot.
- **Icons:** most of `assets/icons` (about 180-210 px) come from the owner's sharp sheet `design/icons-hd/owner-icon-sheet.webp`, cut by `python3 tools/icons/slice_sheet.py` (the name map is in the script). Lock, search, play, stop, xp-badge, currency-plus and controls-menu come from the sharp pack. The outline star, the equipped tick, the sneaker and the navy shirt (`shirt-equip`, for EQUIP/UNEQUIP) come from `design/sharp/Huzz-Valley-Additional-Icons.zip`. The fist, stopwatch and players (quest icons) come from `design/sharp/Huzz-Valley-Quest-Icons.zip`. All packs are imported by `import_sharp.py`. The rest are still small kit crops cleared by `clear_background.py`: the filled star, quests-clipboard, the white shirt (shop benefit), gift-benefit and music-benefit. The pack's hearts were a mix-up and are unused. Running `clear_background.py` overwrites the sheet icons, so run `slice_sheet.py` after it. **Never redraw or upscale them** (the owner's call). `pack_images.py` shrinks the packed in-game icons to 192 px (sharp on Retina screens, where icons show at about 200 px).

## Studio safety
- Lune's built-in copy of the Roblox API is older than Roblox (it lacks EditableImage, for example), so a clean harness run does not prove the code runs in Studio.
- Main.client starts every part through `Report.run`: a failing part can't stop the others, and any error shows in a red box on screen for the owner to screenshot.
- Images draw in-game from `Shared/Images` (EditableImage) until IDs are uploaded. Re-run `python3 tools/icons/pack_images.py` after changing anything in `assets/`.
- **Pictures in Studio's edit mode:** `src/ServerStorage/HuzzStudioTools/ShowPictures.server.lua` is a Studio helper, installed once with right-click > Save as Local Plugin. It adds a "Huzz Valley" toolbar:
  - **Show Pictures** draws the packed pixels onto StarterGui images by their `Icon`/`Art` attribute (`ImageContent`, display only). It also runs when the place opens.
  - **Upload Pictures** does the same as `upload-images.lua`.
  - It reports in Output on lines starting with `[Huzz]`, and scripts in ServerStorage never run in the game.
  - It is untested here because it needs Studio. The first owner test showed nothing, either because it wasn't installed or because of a silent failure, which is why it now reports.
- **Uploading:** `tools/studio/upload-images.lua` (owner pastes it into the Command Bar) uploads every packed image with `AssetService:CreateAssetAsync`, writes `Config/ImageIds` (checked first by `Config/Assets`), and fills `Image` on StarterGui parts by their `Icon`/`Art` attribute. It is untested here: cloud sessions can't reach Roblox (apis.roblox.com is blocked). When the owner sends their ImageIds text, commit it to `src/ReplicatedStorage/Shared/Config/ImageIds.lua` and rebuild, so the StarterGui copy carries the IDs.

## UI in StarterGui (owner's call)
- **How it works:** Roblox copies `StarterGui.HuzzUI` into PlayerGui, and the screens reuse those parts instead of making new ones. `Kit.new` reuses an unused saved child with the same class and name (its "twin").
- **What the saved part keeps vs what the code sets:**
  - the saved part keeps its look (`Kit.LOOK`: position, size, colours, fonts, images, corners), so Studio edits show in the game;
  - the code still sets text, visibility and behaviour.
  - With no saved UI, the same code builds everything from nothing.
- **Rules for screen code:**
  - Make parts with `Kit.new`/Kit helpers and a `Parent`.
  - Never use `x.Parent = y` in screens; use `Kit.attach(x, y)` and use the part it returns.
  - A list that the code refills must clear its old children first (the saved example cards included).
  - Kit's used/reused bookkeeping uses plain tables cleared on `Destroying`, never weak tables. Weak tables with Instance keys drop entries at random (in Roblox and in Lune), which made the reuse random.
  - Siblings with the same name must be identical: a saved part is matched by name, and same-named siblings can come back in any order. Give differing ones their own names (as `Kit.studs` does: Studs, Studs2...). The "nothing doubled" check catches mistakes.
  - A position that depends on the device (the top bar, phones) is assigned after creation, so it applies to saved parts too.
- **Checks:** `check.sh` runs everything on the saved UI, plus `check.luau` once built from nothing (`HUZZ_FRESH=1`). It also checks that nothing is doubled and that a Studio edit survives.
- **Owner's edits:** the owner's Studio edits live only in their place. Regenerating `HuzzUI.rbxm` starts from the code again. Before changing UI code after they have edited in Studio, ask for their export (`tools/export-for-claude.lua`) and copy their changes into the code.
- **Limits:**
  - Icons look blank in Studio's edit mode unless the ShowPictures helper is installed or real image IDs are set.
  - Items inside lists (shop items, character and dance cards, rewards, quests) are redrawn by the code, so Studio edits there don't stay.

## Screen layout (owner's calls)
- The HUD's side buttons are Index, Shop, Dances and Menu (the owner swapped Tiers for Shop; Tiers stays in the Menu). They are centred on the left edge. The Menu side panel opens in that same spot (centred on the left edge) and replaces them.
- The gear sits in Roblox's top bar row: 44 px tall, 12 px from the right edge, lined up with Roblox's own buttons. On touch devices the coin and gem pills move into that row too, so the thumbstick has the bottom-left.
- Windows fit the ScreenGui's own area (`Scale.setRoot`), which is below the top bar and inside a phone's safe area.
- No dim layer behind windows: on phones it left grey bands at the sides. The blur alone covers the screen.
- The Dances preview is a navy card (picture, name, help line) with equal Play and Stop buttons inside it. There is no brown floor.

## Place file
`sh tools/place/build_place.sh` rebuilds `places/HuzzValley.rbxl` (all scripts plus a baseplate). Rebuild it whenever `src/` changes, so the owner can always just open the file.

## Open items (owner's checklist lives in `README.md`)
- **Built:** Lobby HUD, Menu (a side panel over the HUD's side buttons), Shop, Settings, Character Index, Tiers, Dances and Progression (Rewards and Quests). Every main window is 701 x 320.
- **Next:** the round-driven pages (Map Vote, Recruitment, Results, Match HUD) and the Gift Picker. These need the round system and the gifting backend first.
- **Missing from the owner:**
  - sharp versions of the 5 icons still from the kit crops (list under Checks and previews), including the filled star;
  - big preview pictures for Step and Wave (the Index preview uses each character's whole-body render);
  - running `tools/studio/upload-images.lua` and sending back the ImageIds text;
  - Game Pass and Developer Product IDs;
  - dance and pose animations;
  - companion models;
  - outfit assets.
- **Decided:**
  - not-on-sale items show their price but only say "coming soon" when tapped;
  - Aiko and Step are the starter companion and dance;
  - quests count real match events only;
  - there are no timers.
