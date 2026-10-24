# Screen and component specification

The approved board is 1536×1024. These are gallery panels, not one runtime viewport. Split the board into individual references first. Do not build the gallery as the actual UI. Each runtime screen is a single modal over the game world.

## Reference crop bounds

| Screen | Crop bounds in approved board: left, top, right, bottom |
|---|---|
| Shop | 0, 0, 768, 355 |
| Collection | 768, 0, 1536, 355 |
| Dances | 0, 355, 768, 704 |
| Rewards | 768, 355, 1536, 704 |
| Quests | 0, 704, 768, 1024 |
| Settings | 768, 704, 1536, 1024 |

At reference scale most windows have about 30–40 px outer margins; headings/icons occupy about 36–44 px; tabs are about 26–32 px tall. These measurements are estimates: inspect actual crops, account for the smaller bottom-row crop, and preserve relationships rather than stretching every screen to identical gallery dimensions.

## Layout rules

- Centred main window. Desktop starting target: 70–82% viewport width, maximum around 1120px. Never fill the entire gameplay view. Clamp within safe bounds.
- Near-square 3–5px corners at reference scale. Thin navy outline; no futuristic clipped corners.
- Purple header with sparse square studs; title left; close button right. Header and body are separate components.
- One tab row below header. Selected tabs peach; inactive tabs navy. No green primary actions.
- Primary actions muted periwinkle; completed/disabled actions slate. Status checks lavender. Preserve text contrast.
- Square-stud overlay only on purple header and small selected-tab accents. Body and text areas smooth.
- Text hierarchy: bold headings; semibold titles; regular/medium descriptions. Calibrate Gotham/GothamBold against the source. Heavy outlines only if visibly required on major title text, never every label.
- Controls and icons are native instances; never embed screenshot text or price buttons as a single image.
- Use responsive layouts and width constraints. At smaller sizes scroll, reduce columns or move details to a separate page rather than shrinking to illegibility.

## Shop

Title + cart, balances and + controls, red X; passes/cosmetics/coins tabs. Body: two broad horizontal product rows inside a scrolling region. Each row: image block on left, name and concise benefit text, right action area. VIP ownership grey; Dance Pack price periwinkle; gifting separate icon button. Configure actual products.

## Collection

Book/title, search, tier dropdown, sort dropdown, close. ALL/OWNED/FAVOURITES tabs. Left grid ≈45% content width, right preview/details ≈55%. At reference size four cards visible, additional entries scroll. Small tier badges, top favourite icon, bottom name/owned/equipped state. Right: matching model on stud base, name/tier/status, short source hint, one favourite control, Equip/Unequip.

Reference data is illustrative. Sort applies to the entire filtered data set, not just visible cards. Never claim Name A–Z while rendering a contradictory fixed card order; match the illustrated visual layout in a dedicated demo fixture only, and use real alphabetical order at runtime.

## Dances

Music icon/title, search, sort, red X. Tabs All/Owned/Favourites. Left 2×2 card grid; right larger model preview and name. Favourite state consistent; locked state distinct. Play and Stop separate actions. Missing animation assets are unavailable, not fake working controls.

## Rewards and quests

Same Progression window with Rewards/Quests tabs; selected content swaps without moving the shell. Reward track: earned milestones and claim states. Bottom XP bar. Quests: 2×2 cards containing goal, progress, reward and claim state. Reference task names: Make 3 steals; Hold the lead for 30s; Break 5 ankles; Play 3 rounds. All progress server-authoritative.

## Settings

Gear/title, Audio/Controls/Social tabs, red X. Social has segmented choices for inventory visibility and invite requests; ON/OFF companion effects and reduced motion. Changes apply/save. Audio and controls screens extend same style; unsupported options disabled with clear explanation.

## Layering

Only one modal active. Small background blur/dim when open, no desktop OS overlays. Native platform controls remain accessible. Character models and images behind text/buttons; dropdown popup above cards; tooltips above dropdowns. Safe clipping and scrolling.
