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
- **Every colour and size is measured** from the references (the critic report's numbers are in `UI/Theme.lua`). Settings deliberately resizes per tab, because its references differ (Social 258 tall, Audio/Controls 287).
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
- **Sizes are reference px** (as measured on the 768-wide pages). `UI/Scale.lua` applies one UIScale per window, about 1.82x at 1920x1080.

## Checks and previews (run before every commit)
- Put Lune on PATH: `/root/bin/lune`, or download 0.10.5 to `/root/bin`.
- `sh tools/preview/check.sh` runs all three check files and must show 0 failed (37 + 33 + 29 at the time of writing).
- `NODE_PATH=/opt/node22/lib/node_modules sh tools/preview/shots.sh <outDir> [names]` renders each screen under its reference page at 2x. Names: shop-passes, shop-cosmetics, shop-coins, settings-social, settings-audio, settings-controls, menu, lobby-hud.
- Copy the ones that changed to `docs/previews/` as JPEG.
- The renderer approximates Roblox:
  - the Robux glyph draws small;
  - the avatar is a grey stand-in;
  - icons come from `assets/icons` even before they're imported.
- **Icons:** most of `assets/icons` (about 180-210 px) come from the owner's sharp sheet `design/icons-hd/owner-icon-sheet.webp`, cut by `python3 tools/icons/slice_sheet.py` (the name map is in the script). The rest are still the small kit crops cleared by `clear_background.py`: currency-plus, controls-menu, check-equipped, favourites, lock, search, play/stop, xp-badge, quests-clipboard, stopwatch, tag-fist, shirt, sneaker, gift-benefit, music-benefit. Running `clear_background.py` overwrites the sheet icons, so run `slice_sheet.py` after it. **Never redraw or upscale them** (the owner's call). `pack_images.py` shrinks the packed in-game copies to 128 px.

## Studio safety
- Lune's built-in copy of the Roblox API is older than Roblox (it lacks EditableImage, for example), so a clean harness run does not prove the code runs in Studio.
- Main.client starts every part through `Report.run`: a failing part can't stop the others, and any error shows in a red box on screen for the owner to screenshot.
- Images draw in-game from `Shared/Images` (EditableImage) until IDs are uploaded. Re-run `python3 tools/icons/pack_images.py` after changing anything in `assets/`.

## Place file
`sh tools/place/build_place.sh` rebuilds `places/HuzzValley.rbxl` (all scripts plus a baseplate). Rebuild it whenever `src/` changes, so the owner can always just open the file.

## Open items (owner's checklist lives in `README.md`)
- **Built:** Lobby HUD, Menu (a side panel over the HUD's side buttons), Shop, Settings, Character Index, Tiers, Dances and Progression (Rewards and Quests). Every main window is 701 x 320.
- **Next:** the round-driven pages (Map Vote, Recruitment, Results, Match HUD) and the Gift Picker. These need the round system and the gifting backend first.
- **Missing from the owner:**
  - sharp versions of the icons still from the kit crops (list under Checks and previews);
  - Game Pass and Developer Product IDs;
  - dance and pose animations;
  - companion models;
  - outfit assets.
- **Decided:**
  - not-on-sale items show their price but only say "coming soon" when tapped;
  - Aiko and Step are the starter companion and dance;
  - quests count real match events only;
  - there are no timers.
