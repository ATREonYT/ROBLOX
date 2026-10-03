# UI Visual Design for Cartoony Roblox Simulators: what hand-crafted UI looks like, and a design system for "Hood"

> **How these notes were researched (read first).** The network egress policy for this session blocked direct page fetches of devforum.roblox.com, create.roblox.com, artstation.com, medium.com, itch.io, builtbybit.com, vizzbees.com, therookies.co, sulle.ca and most other sites. What was used instead:
> - Roblox's **official Creator Docs**, read in full from the public GitHub mirror (`github.com/Roblox/creator-docs`), which holds the same source text as create.roblox.com.
> - **Search-engine result summaries** of DevForum threads and blogs. Any claim sourced from a DevForum, blog or wiki URL other than the GitHub creator-docs comes from the search engine's summary of that page, not from a full read. Treat those claims as "the page says roughly this". They are still cited to the original URL.
> - Everything under "Inferences" is my own synthesis or proposal. Hex values for "Hood" are **proposals**, not quotes from any game.

---

## Q1. What visual traits define top Roblox simulator UI?

### Takeaway
Front-page cartoony simulator UI is a **sticker/toy look**. Its traits:
- thick dark outlines on both frames and text
- chunky, saturated "pushable" buttons that are lit from the top and have a darker lip or bevel at the bottom
- generous corner radii and hard-offset shadows
- bold rounded display type
- illustrated vector icons with outlines and shading, never emoji
- strict color coding by function and by rarity

What separates the pros is a *standardized* visual language: the same silhouettes, gradients, lighting direction and materials everywhere, built as reusable modular components.

### Cited Findings

**General look of the "chunky cartoon" style**
- The chunky cartoon style "features thick outlines, generous corner radii, saturated primaries, drop shadows with a hard offset, and slightly bouncy proportions". The recipe given is "thick dark outlines, 16 px rounded corners, saturated primary colours, hard drop shadows, and playful oversized buttons", and the style works because "it reads instantly at small sizes on a phone". Caveat: this comes from the blog of an AI UI/thumbnail-generator vendor. — [VizzBees: 12 Roblox UI Design Ideas](https://vizzbees.com/blog/roblox-ui-design-ideas)
- The same source advises that a UI style should be specified by naming "the palette, the corner radius, the outline weight, the type, and the mood — in that order". Those five decisions make up a style spec. — [VizzBees](https://vizzbees.com/blog/roblox-ui-design-ideas)
- On hand-drawn or sketch UI (wobbly ink outlines, paper texture, marker fills): "consistency is the hard part — every element needs the same wobble or the ones that lack it look broken". — [VizzBees](https://vizzbees.com/blog/roblox-ui-design-ideas)

**How the Pet Simulator franchise does it (BIG Games)**
- A BIG Games visual designer made "icons, item art, event visuals, skyboxes, and UI systems" for Pet Simulator X, Pet Simulator 99 and Pets Go, in "the series' playful, high-readability style". They built "a scalable, cohesive visual language for icons and UI systems by standardizing silhouettes, gradients, lighting, and material treatments" and designed "modular, reusable UI components to support faster updates". — [sulle portfolio: BIG Games](https://sulle.ca/project/big-games)
- BIG Games shipped 140+ weekly updates across PSX, PS99 and Pets Go. Each one had an owner for "art direction, UI, and internal tooling" and for "release polish", at 1.5M+ concurrent players. This explains why their UI is componentized: it has to be re-skinned every week. — [Centio: Pet Simulator case study](https://centio.solutions/work/pet-simulator/)
- A front-page simulator icon commission asks for the "bright/playful vector aesthetic of current front page simulators". The deliverables listed are UI screen icons, background icons, gamepass icons, the game icon/thumbnail, badge icons, and "pet icons and pet faces in Bubble Gum Sim / Pet Sim style". Budget: 5,000 Robux for the set; at least 1 year of Roblox UI/icon experience required. — [DevForum: Need 2D Icon Artist (Pet Sim / BGS style)](https://devforum.roblox.com/t/need-2d-icon-artist-for-cartoon-simulator-pet-sim-bgs-style/4768916)

**The standard Photoshop/Photopea button recipe**
- The layer styles used are **Stroke, Inner Shadow and Color Overlay**:
  - Stroke size is "typically between 6 and 15", with Position set to **Outside** and a stroke color with good contrast against the main color.
  - Inner Shadow "adds a shadow inside the layer… to give depth".
  - Elements that will be animated or used as buttons must be exported individually.
  — [DevForum: How to make UI styled for simulator (Detailed Tutorial)](https://devforum.roblox.com/t/how-to-make-ui-styled-for-simulator-detailed-tutorial/2895762)
- Advice for a Pet-Sim-style close button: instead of UIStroke, put a frame behind another frame or image. The inner frame uses `AnchorPoint (0.5,0.5)` and Size `(0.9,0,0.9,0)` ("always takes up 90% of the background"), and both frames are tweened together for animation. The reason given was that UIStroke "doesn't scale well on smaller screens". That problem is now addressed by `StrokeSizingMode` (see Q4). — [DevForum: Make buttons like pet simulator](https://devforum.roblox.com/t/make-buttons-like-pet-simulator/3984742)

**The same look in Supercell's Clash Royale (benchmark)**
- Clash Royale is the benchmark for cartoony mobile UI:
  - "white text with a dark outline"
  - "shiny push buttons that press down and beveled panels"
  - **yellow for the most important functions** (Enter Battle, Request Cards), **green for secondary**, **blue as background or sometimes on buttons**
  - the most important bright elements get "special visual effects like animated highlights"
  — [The Rookies: Detailed breakdown of Clash Royale UX](https://www.therookies.co/blog/education/game-design-ux-best-practices-detailed-breakdown-of-clash-royale)

**Fonts**
- Fredoka One "screams generic simulator". It is "so overused nowadays" that people "associate it with slop Simulator/Obby/Tycoon games", and one commenter says "nearly every front-page experience uses Poppins and Fredoka One". Others defend it: it is "one of the only fonts that matches a very popular style on Roblox (bright, bubbly, cartoonish)", and Super Golf uses it well. — [DevForum: What's a good font face to use as a general "theme" for a game?](https://devforum.roblox.com/t/whats-a-good-font-face-to-use-as-a-general-theme-for-a-game/2538479)
- FredokaOne, Gotham (Medium/Bold/Black) and LuckiestGuy are the fonts associated with simulator games. — [DevForum: Where can I find this "simulator" font?](https://devforum.roblox.com/t/where-can-i-find-this-simulator-font/650336); [Button Simulator wiki: Font credits](https://button-simulatored.fandom.com/wiki/Wiki_Font_Credits)
- Gotham was deprecated and **Builder Sans** replaced it. — [DevForum font thread](https://devforum.roblox.com/t/whats-a-good-font-face-to-use-as-a-general-theme-for-a-game/2538479)
  - Builder Sans (by Roblox and Colophon Foundry) has Thin through **Extra Bold**. There is **no Black weight**.
  - Builder Extended has Light through Extra Bold.
  — [Creator Store: Builder Sans](https://create.roblox.com/store/asset/16658221428/Builder-Sans); [Builder Extended](https://create.roblox.com/store/asset/16658237174/Builder-Extended)
- Luckiest Guy is "a friendly heavyweight sans… inspired by 1950s advertisements". — [Font Squirrel: Luckiest Guy](https://www.fontsquirrel.com/fonts/luckiest-guy)
  - Known Roblox issue: UIStroke on Luckiest Guy text "can leave little holes inside" some glyphs. — [DevForum: UI Stroke creating hollow areas](https://devforum.roblox.com/t/ui-stroke-creating-hollow-areas/3283340)
- Roblox-available display fonts that suit a street theme:
  - Local fonts: **Bangers** (comic), **Permanent Marker** (marker), **Fredoka One**, **Luckiest Guy**, Amatic SC, Creepster, Press Start 2P
  - Cloud fonts: **Bungee Inline**, **Bungee Shade**, **Rubik Wet Paint**, **Rubik Marker Hatch**, Are You Serious, Faster One, Monoton, Rye
  — [Gist: almost complete list of Roblox local + cloud fonts](https://gist.github.com/cxmeel/38f6d9ba5dc5fd048489a37853bcaa87)

**Rarity color conventions**

| Source | Tiers and colors |
|---|---|
| General game convention | Common white/grey, Uncommon green, Rare blue, Epic purple/pink, Legendary gold/orange ([Games Learning Society](https://www.gameslearningsociety.org/wiki/what-color-is-common-rare-epic-legendary/), low-authority aggregator) |
| DevForum suggestion | Common grey, Uncommon green, Rare blue, Epic bright purple, Legendary gold, Mythic violet/dark purple, Deadlocked black, Contraband red, Limited rainbow ([DevForum: value colors](https://devforum.roblox.com/t/need-help-on-selecting-value-colors/793985); [DevForum: tier list names](https://devforum.roblox.com/t/need-tier-list-names/761008)) |
| **Adopt Me** (April 2026, after testing) | Common **white**, Uncommon **green**, Rare **blue**, Ultra-Rare **purple**, Legendary **orange**, described as "following Fortnite's rarity colors". Old scheme was Common blue, Uncommon purple, Rare green, Ultra-Rare red, Legendary black. The change "divides fans", but it moved the biggest legacy Roblox game onto the cross-industry standard ([X: @AMGlormies](https://x.com/AMGlormies/status/2043788065039163623); [X: @BloxyMiner](https://x.com/BloxyMiner/status/2043812117497651402); [X trending](https://x.com/i/trending/2044834911899574351)) |
| **Pet Simulator 99** (11 rarities) | Basic gray, Rare (pastel) green, Epic (baby) blue, Legendary (pastel) orange, Mythical (pastel) red, Exotic purple/neon pink, Exclusive pink/baby purple, then later Divine yellow, Superior cyan, Celestial pink+blue mix, Secret dark blue ([Pet Simulator Wiki: Rarities (PS99)](https://pet-simulator.fandom.com/wiki/Rarities_(Pet_Simulator_99))) |
| **Steal a Brainrot** | Common, Rare, Epic, Legendary, Mythic, Brainrot God, Secret, OG. Reported colors: Common white, Rare blue, Epic dark purple, Legendary yellow gradient (light to dark yellow), Mythic red, Brainrot God multicolor/rainbow. Secret/OG colors not found. Aggregator source, low confidence ([The Click: SaB rarities](https://www.theclick.gg/steal-a-brainrot-rarities/)) |
| Miners World (example with hex) | Common #cccccc/#ffffff, Uncommon #00ff00, Epic #8a2be2, Legendary #ffff00, Mythic #ff0000. Fully saturated "web" colors, a less refined example ([Miners World wiki: Rarities](https://roblox-miners-world.fandom.com/wiki/Rarities)) |

**Number formatting**
- Standard suffixes are K, M, B, T, then Qa, Qi, Sx… "Most modern simulator games use the standard system". Some games vary (Miner's Haven uses lowercase "qd"; others use Qd/Qn). Typical output: 12345 becomes "12.3K", 1234567 becomes "1.2M" (one decimal). — [BloxControl: Roblox number abbreviations](https://bloxcontrol.com/guides/roblox-number-abbreviations-k-m-b-t-qa-qi-explained/); [DevForum: Simulator Number Abbreviation System](https://devforum.roblox.com/t/simulator-number-abbreviation-system-with-custom-decimals/1647339)

**Specific games**
- **Grow a Garden** uses "studded textures evocative of old-school Roblox games"; the map, fruits and pets are "blocky classic stud style". — [Wikipedia: Grow a Garden](https://en.wikipedia.org/wiki/Grow_a_Garden); [Medium: The Design Tactics of Grow a Garden](https://medium.com/@rtxhyperion/the-design-tactics-of-grow-a-garden-rob-c48e9e2dc7fd)
  - Its shops are **physical (in-world) rather than UI** and restock every 5 minutes with the same items for all players. — [Medium: Design Tactics of GAG](https://medium.com/@rtxhyperion/the-design-tactics-of-grow-a-garden-rob-c48e9e2dc7fd)
  - Third-party "Grow a Garden style" UI packs reproduce its screen set: Seed Shop, Gear Shop, Teleport Buttons, Weather, Notifications, Confirmation, Codes, Limited Shop, Pet/Cosmetic Shop, HUD, Inventory, Hotbar, Quests, Settings. — [BuiltByBit: UI Pack GAG style](https://builtbybit.com/resources/ui-pack-grow-a-garden-style.102616/); [itch.io: gag ui pack](https://adrianart.itch.io/gag-ui-pack)
- **Steal a Brainrot-era** UI kits are sold as "stud UI" / "shiny stud UI… cashgrab/brainrot style". They include HUD frames (Top, Bottom, Left, Right), shop, currencies, upgrades, rebirth, index, and daily rewards. — [BuiltByBit: stud-ui tag](https://builtbybit.com/tags/stud-ui/); [BuiltByBit: Premium UI Pack (Brainrot)](https://builtbybit.com/resources/premium-ui-pack-12-ui-frames-brainrot.103666/)
- **Pet Simulator 99's** pet inventory is described as having "colorful pet slots, level displays, search and filter elements, equip controls, and a responsive open/close system". This is a third-party clone's description. — [ClearlyDev: Inventory Pet Simulator UI](https://clearlydev.com/product/inventory-pet-simulator-ui)
- One AI tool vendor's generator outputs "Frames with UICorner, UIGradient and UIStroke". — [VizzBees: How to make a Roblox UI](https://vizzbees.com/blog/how-to-make-a-roblox-ui)

### Inferences
- **The "toy object" test.** Every pro simulator element looks like a physical, pressable object:
  - an outline that separates it from any 3D background
  - a lit top (lighter fill or a 1–2 px inner highlight line)
  - a shaded bottom (darker lip or bevel)
  - a hard shadow
  Generic UI looks like a *window*: flat translucent panels. Pro cartoony UI looks like *stickers and toys*.
- **Outline color is a darker shade of the fill, not pure black.** Roblox's own UI tutorial does this: dark green stroke `RGB 8,78,52` on mint `RGB 88,218,171` (see Q4). Use one global "ink" color, a very dark desaturated purple/navy, for the outermost outline. Use hue-matched dark shades for inner bevels and text strokes on colored buttons.
- **Three layers of stroke make up the chunky look:**
  1. outer dark ink outline
  2. colored body with a darker bottom lip
  3. thin inner light highlight along the top edge
  Most amateur UI has only layer 2, or layer 1 in flat black.
- **Rarity colors.** Adopt Me's 2026 switch is strong evidence that the cross-industry ladder (white/grey → green → blue → purple → orange/gold) is what players already know. Extend it upward with red/pink (Mythic) and an animated special treatment for Secret.
- **The "Fredoka One problem" is about default use, not the font itself.** If Hood uses a rounded font, it needs a distinctive treatment: a heavier stroke, a colored stroke, or a second display face for titles.

### Gaps
- No primary source (developer statement or published style guide) gives exact stroke pixel values, radii or hex codes for Pet Simulator 99, Grow a Garden, Steal a Brainrot, Blade Ball, Adopt Me, Bee Swarm Simulator, Anime Defenders or Toilet Tower Defense. Searches turned up no design breakdown articles for Blade Ball, Bee Swarm, Anime Defenders or TTD. Describing those HUDs in detail would need screenshots or gameplay video. Not done here, because image and video sites were blocked.
- The exact fonts in PS99 / Grow a Garden / Steal a Brainrot are not confirmed by any source found.
- The ArtStation page "Pet Simulator 99 & Pets GO! – Enchants, UI & Icons" by Camille Bruneaud (https://www.artstation.com/artwork/AZNZJX) and Jenni Rambach's Pet Simulator 2 icons (https://jennirambach.artstation.com/projects/0nevx4) likely show the real icon style. Both were blocked; view them manually.

---

## Q2. Standard layouts and conventions, mobile vs PC, and screen coverage

### Takeaway
Roblox's own docs fix the hard constraints:
- Keep interactive UI out of the **bottom-left (thumbstick)** and **bottom-right (jump)** corners.
- Stay inside `CoreUISafeInsets`, below a **58 px (desktop) / 52 px (mobile)** top bar.
- Group by category, show things contextually, and keep the layout balanced.

Touch targets should be at least about 44–48 px, with 8 px gaps. The convention inside those constraints:
- currencies along the top or top-left
- a vertical column of square icon buttons on a side edge
- centered modal popups with a red X in the top corner
- toasts that slide in
- tutorial arrows or beams pointing at the next action

### Cited Findings

**Official layout rules (Roblox curriculum: wireframe your layouts)**
- **Do not place interactive UI in the bottom-left (virtual thumbstick) or bottom-right (jump button)**.
- Account for core UI: player list, health, backpack, chat, capture and emote buttons. Disable them if gameplay doesn't need them.
- "Group UI elements from the same category together"; "display UI elements contextually for different workflows"; "Aim for balance and symmetry".
- "Place interactive elements in easy-to-reach zones" near natural thumb resting positions, and avoid far corners on phones and tablets.
- "Test your layouts against a variety of possible backgrounds".
- Wireframe with grayscale basic shapes; "create one adaptive design rather than separate versions per device".
— [Roblox Creator Docs: Wireframe your layouts (GitHub source)](https://github.com/Roblox/creator-docs/blob/main/content/en-us/tutorials/curriculums/user-interface-design/wireframe-your-layouts.md) (live at create.roblox.com/docs/tutorials/curriculums/user-interface-design/wireframe-your-layouts)

**Official hierarchy rules (Roblox curriculum: choose an art style)**
- Use three interaction levels (primary/secondary/tertiary) with visual emphasis matching how likely each is to be used.
- "Maintain left-to-right visual hierarchy".
- "Provide at least one form of visual feedback for interactable UI elements".
— [Roblox Creator Docs: Choose an art style (GitHub source)](https://github.com/Roblox/creator-docs/blob/main/content/en-us/tutorials/curriculums/user-interface-design/choose-an-art-style.md)

**Official UI/UX principles**
- Hierarchy of Information: show "only what matters contextually – swapping out the buttons and information depending on what's useful in each context".
- Attention tools are "Color, Size, Space, Proximity, Movement", but "Moderation is key… Excessive use of bright, moving elements might overwhelm and confuse players."
- Conventions: "Leveraging this familiarity can make an interface more intuitive and lessen the need for game-specific instructions."
- Consistency: "Whatever decisions a UI designer makes, they should consistently apply them throughout the game."
- Visual language should be documented in a **Style Guide**.
- Mobile: "small screens can easily get overwhelmed with excessive buttons, screens, and text."
— [Roblox Creator Docs: UI and UX design (GitHub source)](https://github.com/Roblox/creator-docs/blob/main/content/en-us/production/game-design/ui-ux-design.md)

**Safe areas and the top bar**
- `ScreenInsets` options:
  - **CoreUISafeInsets** (default): "keeps all descendant GuiObjects inside the core UI safe area, clear of the top bar buttons and other screen cutouts". Recommended for interactive UI.
  - **DeviceSafeInsets**: avoids notches but not the Roblox top bar.
  - **TopbarSafeInsets**: places UI *inside* the top bar row, between the Roblox controls and the right edge.
  - **None**: reserve "only for non-interactive content like background images".
  — [Roblox Creator Docs: screen-insets include (GitHub source)](https://github.com/Roblox/creator-docs/blob/main/content/en-us/includes/ui/screen-insets.md)
- The reintroduced Roblox top bar is **58 px tall on desktop and 52 px on mobile**. Developers had to re-layout HUDs around it. — [DevForum: Reintroduction of the topbar messing up UI](https://devforum.roblox.com/t/reintroduction-of-the-topbar-messing-up-ui/3260927); [DevForum: Topbar based on TopBarSafeInsets](https://devforum.roblox.com/t/how-to-produce-a-topbar-based-on-topbarsafeinsets/2914413)

**Touch target sizes**
- Apple HIG minimum is **44×44 pt**. Material Design is **48×48 dp**. Both are about 9 mm physically. WCAG 2.1 AAA asks for 44×44 CSS px. — [LogRocket: All accessible touch target sizes](https://blog.logrocket.com/ux-design/all-accessible-touch-target-sizes/)
- Roblox-oriented guidance found in search (exact page not verified):
  - minimum touch target 44 px, with **56 px for important or destructive actions**, and at least **8 px between targets**
  - mobile-first minimum button size around **0.15 width × 0.08 height** in scale
  — [KitsBlox: Fix Roblox UI scaling on mobile](https://kitsblox.com/blog/fix-roblox-ui-scaling-mobile); [Superbullet docs: Making UI](https://docs.superbulletstudios.com/prompt-engineering/making-user-interface)
- A DevForum tutorial uses **70 px buttons on small screens and 120 px on larger ones**, switching when the screen dimension exceeds 500 px. — [DevForum: The Correct Way to Design Mobile Buttons](https://devforum.roblox.com/t/the-correct-way-to-design-mobile-buttons/2494558)

**Critiques of simulator HUDs on DevForum**
- "Some elements can take up too much space while other parts look too small". One reviewer noted chat and leaderstats too small and "side buttons limiting the player view". — [DevForum: [Opinions] Simulator UI](https://devforum.roblox.com/t/opinions-simulator-ui/1405242)

**Shops and social visibility**
- Grow a Garden puts shops in the world, so "you can learn from other players' interactions". This is an alternative to pure-screen shops. — [Medium: Design Tactics of GAG](https://medium.com/@rtxhyperion/the-design-tactics-of-grow-a-garden-rob-c48e9e2dc7fd)

### Inferences (proposed Hood HUD layout; my synthesis)

**Top band** (just under the 58/52 px top bar, inside CoreUISafeInsets)
- Currency pills: **Power** (primary, larger) and **Cash**.
- Each pill: an icon that overlaps the pill's left end, the abbreviated number, and a small green "+" button on the right end that opens the shop to that currency's tab. This is the familiar "currency + plus" pattern from mobile F2P games.
- Top-left or top-center both work. Top-left keeps the left-to-right hierarchy Roblox recommends.

**Left-middle column** (vertically centered, so it clears the bottom-left thumbstick)
- 4–6 square icon buttons, each about 1:1 with an icon plus a short label underneath: **Shop/Outfits, Crew, Rebirth, Quests/Daily, Gifts/Codes**.
- Red notification dot or badge on a button's corner when something is claimable.

**Right-middle column**
- Secondary utilities: **Leaderboards**, **Settings**, **Teleport/Walls**.

**Bottom-center**
- The contextual primary action, e.g. the big "TRAIN" or "PUNCH" button and a training-bag readout.
- Keep it above and between the thumbstick and jump zones.
- This is the one place for the **largest** button (56 px+ on phones).

**Popups**
- Centered modal. On phones about 85–92% of screen width; on PC about 55–70% width, capped with a `UISizeConstraint` so it doesn't balloon on 1440p and 4K.
- Dim the world behind with a black overlay at about 40–50% opacity.
- Red circular **X** overlapping the top-right corner, 44–56 px on phones.
- Title in a colored **header strip** or ribbon, often overlapping the panel's top edge (sticker effect).

**Toasts and notifications**
- Top-center under the currencies, or right-middle. Short, stackable, auto-dismiss.

**Tutorial**
- Bouncing arrow or pointer over the next UI button, plus a 3D beam or footprints to world targets.
- One instruction at a time in a speech-bubble card.

**Screen coverage targets (heuristic)**
- Idle HUD at most about 15–20% of screen area on phones, less on PC. Everything else is contextual.
- One modal at a time.

### Gaps
- No source gave measured HUD layouts (positions, percentages) for PS99, GAG, SaB or Adopt Me. The layout above is a synthesis of Roblox's rules and genre familiarity, not a measurement.
- No authoritative source found for "how much screen should HUD cover" in Roblox specifically.

---

## Q3. What makes UI look AI-generated or amateur, and the craft details professionals use instead

### Takeaway
"Slop" UI is the **statistical average** of many templates, made when no decisions were taken. Its tells:
- one default font
- purple/blue gradients
- identical rounded cards with 1 px grey borders and soft shadows on everything
- dark mode by default
- everything centered
- emoji as icons
- inconsistent spacing

Pro UI is the opposite: a small, documented set of committed decisions (palette, radius scale, stroke scale, type scale, spacing scale, light direction, icon style), applied with total consistency. Color and motion are reserved for what matters.

### Cited Findings

**What AI slop looks like (web/app design sources)**
- AI slop has "a fingerprint: the Inter typeface, an indigo-to-purple gradient, three rounded cards in a row". It comes from tools that "default to the same Inter font, the same purple-to-blue gradient, and the same rounded-corner card layout". The full-viewport centered hero is called out as a tell. — [925 Studios: AI slop design tells](https://www.925studios.co/blog/ai-slop-design-tells); [925 Studios: AI slop web design guide](https://www.925studios.co/blog/ai-slop-web-design-guide)
- Tells also include "a gray 1px border on every card", "dark mode", "gradients everywhere", "the same rounded corners with a shadow on every button and ghost borders on every card". — [Developers Digest: AI Design Slop, 16 patterns](https://www.developersdigest.tech/blog/ai-design-slop-and-how-to-spot-it); [Managed Code: AI slop in design](https://managed-code.com/blog-post/ai-slop-in-design)
- "Inconsistent spacing, over-polished typography, cluttered visuals… emoji slop… inconsistent kerning, baselines". — [Venngage: What is AI slop in design](https://venngage.com/blog/ai-slop-in-design/); [VibeCodeKit: AI slop design](https://vibecodekit.dev/ai-slop-design)

**Why it happens, and the fix**
- Root cause: LLMs output "the statistical average" of training templates. "The real cause of slop is no decision — when nothing tells the agent which direction to commit to, it falls back on the safe, high-probability look." — [VibeCodeKit](https://vibecodekit.dev/ai-slop-design); [Developers Digest](https://www.developersdigest.tech/blog/ai-design-slop-and-how-to-spot-it)
- Fix: give "specific brand constraints, or make the taste decisions yourself", "replace default… typography with distinctive fonts", "add intentional micro-interactions". — [925 Studios](https://www.925studios.co/blog/ai-slop-design-tells)

**Roblox-specific amateur tells (DevForum critiques)**
- Inconsistent padding, e.g. "padding to the left of icons is larger than the top padding".
- Non-uniform gaps between elements make UI "appear incomplete".
- Coloring that isn't consistent or doesn't follow contrast rules.
— [DevForum: Feedback on my UI](https://devforum.roblox.com/t/feedback-on-my-ui/753642); [DevForum: My UI is bad, don't know how to fix](https://devforum.roblox.com/t/my-ui-is-bad-dont-know-how-to-fix/2154422); [DevForum: How much is too much gradient?](https://devforum.roblox.com/t/how-much-is-too-much-gradient/656936)
- **Conflicting opinion:** some DevForum feedback says outlines "can make GUIs look old fashioned" and suggests rounder corners instead. — [DevForum: Feedback on my UI](https://devforum.roblox.com/t/feedback-on-my-ui/753642). This contradicts the cartoony-simulator recipe of thick outlines ([DevForum simulator tutorial](https://devforum.roblox.com/t/how-to-make-ui-styled-for-simulator-detailed-tutorial/2895762); [VizzBees](https://vizzbees.com/blog/roblox-ui-design-ideas)). The likely resolution: thin, uniform black 1 px borders look dated, while thick, hue-aware outlines are a deliberate cartoon style.

**Official Roblox rules that prevent slop**
- "Limit your color theme to only highlight the key information".
- "Don't always rely on color alone… combine colors with icons, shapes, and/or animations".
- Keep color "readable over both light and dark elements in the 3D world".
- "Limit details on your icons that would become unrecognizable on mobile".
- "Embrace the symbolism within your game's genre".
- "Use stylized text sparingly, such as for titles or alert text".
- "Display text on top of a contrasting color or with a stroke".
- "Reference the most space your text can take up" (for localization).
— [Roblox Creator Docs: Choose an art style](https://github.com/Roblox/creator-docs/blob/main/content/en-us/tutorials/curriculums/user-interface-design/choose-an-art-style.md)

**Purposeful color (Nintendo's Splatoon team)**
- Nintendo's Splatoon UI team made "icons high chroma to emphasize importance, while keeping background elements like modal windows low chroma".
- They also built a custom typeface mixing "sporty and thick strokes with liquid and organic shapes".
— [Haiiro: How Nintendo designed Switch and Splatoon (UI Crunch talk)](https://medium.com/haiiro-io/how-nintendo-designed-switch-and-splatoon-d1a14b9cc2de)

**Spacing systems (general UI)**
- 8-pt spacing scale: 8/16/24/32/40/48/56, with 4 for tight spots.
- "Font sizes don't need to follow the 8px grid"; type follows its own (modular) scale.
- Internal padding should be ≤ external spacing (the "internal ≤ external" rule).
— [Cieden: Spacing best practices](https://cieden.com/book/sub-atomic/spacing/spacing-best-practices); [Design for Ducks: UI spacing cheat sheet](https://designforducks.com/ui-spacing-cheat-sheet-a-complete-guide-2/); [Atlassian Design: Spacing](https://atlassian.design/foundations/spacing)

**Consistency is the pro differentiator**
- At BIG Games, consistency came from standardizing "silhouettes, gradients, lighting, and material treatments" and using modular components. — [sulle: BIG Games](https://sulle.ca/project/big-games)

### Inferences: Roblox "AI slop" checklist (avoid) vs the pro equivalent

| Slop tell (Roblox flavor) | Pro equivalent for Hood |
|---|---|
| Flat dark `#1E1E1E`-ish Frames at 0.3 transparency, white Gotham/Builder text, same UICorner on everything | Opaque, colored, *material* panels (cardboard, sticker, signboard) with ink outline, header strip, inner inset |
| Emoji as icons (💪💵🐶) | Custom illustrated icons, one style: thick ink outline, 2–3 tone cel shading, white sticker border, same light direction. **Inference:** emoji can't take UIStroke, can't match palette or stroke weight, and render with a different art style. Not verified by a source |
| One font at one size, or `TextScaled` on every label | 2–3 families max, a 4–5 step type scale. **Inference:** `TextScaled` makes every label pick its own size, which breaks the type scale. Cap with `UITextSizeConstraint` or use fixed sizes per token |
| Gradients everywhere at random angles | Gradients only to express **light from the top** (light top, darker bottom, about 15–25% luminance change) and on special things (Legendary+, rebirth). Same angle everywhere |
| Everything centered, symmetric stacks of identical buttons | Clear hierarchy: one dominant CTA per screen (yellow or green, biggest, animated shine), secondary buttons smaller and quieter, tertiary as text or icon only |
| Random spacing | 4/8/16/24/32 spacing tokens; internal padding ≤ gap between groups |
| Random radii | 3 radius tokens (small 8, medium 16, large 24, plus pill) |
| Color as decoration | Color = meaning: green buy/confirm, red close/cancel, yellow primary/premium, blue info/navigation, rarity ladder for items. Backgrounds low chroma, icons and CTAs high chroma (Splatoon rule) |
| No pressed state / no feedback | Every button has hover (PC), press (squash plus lip collapse) and disabled (desaturated, no shine) states |
| Generic labels ("Buy", "Item 1") | Flavorful, short copy in-theme ("COP IT", "FLEX", "REP") but only where clarity isn't lost; prices always show icon plus abbreviated number |
| Stroke 1 px black on everything | Stroke *scale*: outer ink 3–4 px, text stroke about 8–12% of font size, inner highlight 1–2 px |
| No light direction (shadows on all sides, glows) | One light direction (top-left or top), hard drop shadows offset straight down (or down-right) at a fixed distance |

**Micro-details pros add:**
- 1–2 px white inner highlight line along the top inside edge at 30–50% opacity
- a "gloss" band on the top half of buttons
- subtle pattern texture inside panels at 3–8% opacity (stripes, dots, brick)
- tiny sparkles or stars on rare items
- notification badges with their own outline
- number "pop" when values change
- icons breaking the frame (overlapping the panel edge)
- slight rotation (−3° to +3°) on stickers and badges for life
- consistent drop-shadow offset

### Gaps
- No Roblox-specific published "anti-AI-slop" article was found. The mapping above applies general web/app findings plus DevForum critiques to Roblox.
- I found no source on how Roblox renders emoji in TextLabels across platforms. The claim that emoji look inconsistent or cheap is an inference.

---

## Q4. How professionals build it: images from Figma/Photoshop (9-slice) vs Frames + UICorner/UIStroke/UIGradient

### Takeaway
Both approaches are used:
- **Image-based** (Photoshop/Photopea/Figma, exported PNGs, 9-slice) is the classic simulator commission workflow. It gives the richest look: inner shadows, textures, illustrated icons.
- **Frame-based** (UICorner + UIStroke + UIGradient) became far more capable in 2025. UIStroke gained `StrokeSizingMode.ScaledSize`, `BorderStrokePosition` (Inner/Center/Outer), `BorderOffset`, and multiple strokes with ZIndex. It is better for animation, theming and scaling.

**Recommended for Hood: a hybrid.**
- Frames + modifiers for panels, buttons and pills (tokenized, animatable, re-colorable).
- Images only for illustrated icons, decorative stickers/tape, textures and 9-slice "material" panels where a Frame can't produce the look.

### Cited Findings

**Image workflow (the simulator commission standard)**
- Design in Photopea/Photoshop with Stroke (6–15 px, Outside), Inner Shadow and Color Overlay. "If you plan on animating or using frames as buttons, you have to export them individually." — [DevForum: Simulator UI detailed tutorial](https://devforum.roblox.com/t/how-to-make-ui-styled-for-simulator-detailed-tutorial/2895762)
- Commission designers describe the toolset as "Adobe Illustrator, Photoshop, XD, Figma… with most using Adobe Photoshop". — search summary of DevForum portfolio threads ([DevForum: Fantasy Cartoony UI](https://devforum.roblox.com/t/fantasy-cartoony-ui/1968790); [DevForum: Illustrative Cartoony UI](https://devforum.roblox.com/t/illustrative-cartoony-ui/1927870))

**9-slice (official docs)**
- 9-slice "lets you create UI elements of varying sizes without distorting the borders or corners". Corners don't scale; edges scale on one axis; the center scales on both.
- Set `ScaleType = Slice` and define `SliceCenter` in pixels.
- Use it "for components with unpredictable content sizes" and localization.
— [Roblox Creator Docs: 9-slice (GitHub source)](https://github.com/Roblox/creator-docs/blob/main/content/en-us/ui/9-slice.md)

**UIStroke, UIGradient and UICorner capabilities (official docs)**
- **UIStroke**
  - `ApplyStrokeMode.Contextual` outlines text; `Border` outlines the box. You can "parent two UIStroke instances to a text object with different modes".
  - `LineJoinMode` options: Round, Bevel, Miter.
  - `BorderStrokePosition`: Outer, Center, Inner. `BorderOffset` adds extra offset.
  - `StrokeSizingMode.ScaledSize` makes thickness relative to font size (text) or parent size.
  - Supports child UIGradient for gradient strokes, and a `ZIndex` for layering multiple strokes.
  - Warning: "Avoid tweening the Thickness property of a UIStroke… applied to text" (performance).
- **UIGradient**: Linear, Radial or Conical types; Offset and Rotation; TileMode Clamp/Repeat/Mirror.
- **UICorner**: `CornerRadius` as UDim (scale = fraction of the shortest edge); **scale ≥ 0.5 produces a pill**. Per-corner `TopLeftRadius` etc. are available.
— [Roblox Creator Docs: Appearance modifiers (GitHub source)](https://github.com/Roblox/creator-docs/blob/main/content/en-us/ui/appearance-modifiers.md)
- With the full release of the UIStroke improvements: "You no longer need to create invisible Frame instances for layered stroke effects". — [DevForum: [Full Release] UIStroke Improvements: Scaling, Offsets, and More](https://devforum.roblox.com/t/full-release-uistroke-improvements-scaling-offsets-and-more/3958036)

**Before ScaledSize: the old scaling problems**
- UIStroke thickness was pixel-based while Scale sizing follows screen ratio, so strokes looked too thick on phones. Many popular games used Offset sizing for this reason. Community modules existed to rescale strokes. — [DevForum: UICorners and UIStrokes break on different resolutions](https://devforum.roblox.com/t/uicorners-and-uistrokes-break-on-different-screen-resolutions-and-other-ui-struggles/2767673); [DevForum: UIStrokeAdjuster](https://devforum.roblox.com/t/uistrokeadjuster-properly-scale-your-uistrokes/1889014)

**Performance**
- UICorner has "minimal to no impact". Rounded 9-slice images are worth it only with "200+ UICorner elements" on low-end targets. — [DevForum: UICorner vs rounded image](https://devforum.roblox.com/t/uicorner-vs-rounded-image/1206815)

**Roblox's own tutorial (laser-tag UI)**
- `ImageLabel`s for decorative shapes; Frames as transparent containers.
- Font: **Montserrat** Medium/Bold.
- Dark panels: black at 0.3 transparency.
- Text stroke color is a dark shade of the fill: **`RGB 8,78,52`** on mint **`88,218,171`**.
- UICorner radii: **0.075** (subtle), **0.1** (buttons), **0.2** (select buttons), all as scale.
- `UIAspectRatioConstraint` keeps proportions.
— [Roblox Creator Docs: Implement designs in Studio (GitHub source)](https://github.com/Roblox/creator-docs/blob/main/content/en-us/tutorials/curriculums/user-interface-design/implement-designs-in-studio.md)

**Frames-only cartoony kits exist**
- e.g. a free "fully scripted simulator-style UI pack made… using ONLY Frames". — [itch.io: FREE Cartoony Roblox UI Pack (Zxgly)](https://zxgly.itch.io/free-cartoony-roblox-ui-pack); [BuiltByBit mirror](https://builtbybit.com/resources/free-cartoony-roblox-ui-pack.91822/)

**What commissions cost and how designers pitch themselves**
- Planey (UI/scripting portfolio):
  - now designs "in Adobe Photoshop, sometimes in Figma"
  - prices: buttons **70–100 Robux each**, menus **1k–2k Robux**, full system UI **3k+ Robux**
  — [DevForum: Planey's UI/Scripting Portfolio](https://devforum.roblox.com/t/planeys-uiscripting-portfolio/3560776)
- Other quotes seen (portfolio threads, exact thread not pinned down by the search summary):
  - single UI element 500–1k Robux / $10–25
  - full sets 5–10k Robux / $35–65
  - [DevForum: Professional GUI Designer](https://devforum.roblox.com/t/open-professional-gui-designer/1334367); [DevForum: Portfolio for hire](https://devforum.roblox.com/t/portfolio-for-hire/4069998)
- Market ranges: $20–100 per screen, $100–500 for coordinated menus and HUD, $500–2,000 for complete UI suites. — [BloxG: Roblox UI/UX design services](https://bloxg.com/marketplace/services/ui_design)
- Fiverr listings start at about $10 for Figma-based Roblox UI. — [Fiverr: loomui](https://www.fiverr.com/loomui/design-professional-roblox-ui-and-ux-with-figma-for-your-game)
- Designers advertise specialties such as "simulator UI", "open world combat UI" and "general UI". — [DevForum: DevHue portfolio](https://devforum.roblox.com/t/devhue-ui-designer-portfolio/1072945); [DevForum: Ssamrox portfolio](https://devforum.roblox.com/t/ssamrox-ui-design-portfolio/1019187)

### Inferences (recommended process for Hood)

**1. Style tile first, in Figma**
- One board with the palette tokens, type scale, radius and stroke scale, one button in all states, one currency pill, one item card in each rarity, one modal, and 6 icons.
- Get this approved before building screens. It is the "Style Guide" Roblox's docs call for.

**2. Build primitives as Frames + modifiers**
- **Button anatomy (Frames):**
  - `Lip` frame: dark shade, offset +4–6 px downward, same UICorner
  - `Body` frame: base color, UIGradient top-light/bottom-dark, UIStroke ink with `BorderStrokePosition = Outer` and `StrokeSizingMode = ScaledSize`
  - `Highlight`: a second UIStroke `Inner`, white at about 60% transparency, or a thin top frame
  - `Label`: white text with a contextual UIStroke in the button's dark shade
  - `Icon`: ImageLabel
- Pressing moves Body down onto Lip (the lip "collapses").
- This is the PS99-style "frame behind frame" structure from the DevForum thread, now simpler with multi-stroke support.

**3. Use images for**
- illustrated icons (currency, crew pets, outfits, stat icons)
- stickers, tape and graffiti decals
- panel textures and patterns (tiled ImageLabel at low opacity, via `ScaleType Tile`)
- complex 9-slice "material" panels such as torn cardboard or a metal sign plate
- Export at 2× and keep a consistent icon canvas (e.g. 256×256 with 16 px padding) so all icons share the same visual weight.

**4. Token-drive everything**
- Colors, radii, strokes and type sizes come from one ModuleScript or StyleSheet. Roblox now has a UI Styling system in creator-docs at `ui/styling/` with an editor and CSS comparisons ([GitHub creator-docs ui/styling](https://github.com/Roblox/creator-docs/tree/main/content/en-us/ui/styling)); the implementation researcher should evaluate it.
- This is what makes the UI read as "designed": every button is the same object.

**5. Test on real phones**
- Test against bright and dark world backgrounds, as Roblox's docs say.

### Gaps
- Not confirmed whether PS99 / GAG / SaB build primarily with images or Frames. The BIG Games portfolio says "modular, reusable UI components" but not the implementation method.
- The Roblox UI Styling (StyleSheet) docs were not read in detail. Left for the implementation researcher.

---

## Q5. Color palettes and hex values for cartoony UI, and an urban/"hood" aesthetic that still reads clearly

### Takeaway
No hit game publishes its hex palette, so the guide has to define its own.

What sources agree on:
- saturated primaries for actions
- color coding by function: yellow most important, green secondary/confirm, blue background or info, red close/cancel
- high-chroma icons and CTAs over low-chroma backgrounds
- outlines in dark hue-matched shades
- text always white or light with a dark stroke

For Hood, the street theme should live in **materials and decoration**: cardboard and paper panels, tape, die-cut stickers, spray-paint tags, street signs, neon accents. The **functional layer** stays in the standard cartoony grammar, so readability never suffers.

### Cited Findings
- Clash Royale's palette logic: **yellow = most important functionality, green = secondary, blue = background or sometimes buttons**, with animated highlights on the most important bright elements. — [The Rookies: Clash Royale breakdown](https://www.therookies.co/blog/education/game-design-ux-best-practices-detailed-breakdown-of-clash-royale)
- Splatoon: **high-chroma icons, low-chroma modal and background windows**. Its graffiti exists in-world as "stickers, posters, or spray painted" designs. — [Haiiro: How Nintendo designed Splatoon](https://medium.com/haiiro-io/how-nintendo-designed-switch-and-splatoon-d1a14b9cc2de); [Inkipedia: Graffiti](https://splatoonwiki.org/wiki/Graffiti)
- Roblox's tutorial palette example: mint `RGB 88,218,171` (≈ #58DAAB), carnation pink `RGB 255,170,255` (≈ #FFAAFF), dark-green stroke `RGB 8,78,52` (≈ #084E34), black panels at 0.3 transparency, white text. — [Roblox Creator Docs: Implement designs in Studio](https://github.com/Roblox/creator-docs/blob/main/content/en-us/tutorials/curriculums/user-interface-design/implement-designs-in-studio.md)
- Roblox docs on color: "prioritize simple UI with color that remains readable over both light and dark elements in the 3D world", and don't rely on color alone. — [Roblox Creator Docs: Choose an art style](https://github.com/Roblox/creator-docs/blob/main/content/en-us/tutorials/curriculums/user-interface-design/choose-an-art-style.md)
- Street-style game UI references:
  - Street Fighter 6 graffiti HUD community mods ("Graffiti UI", themes "Neon" and "Outline") — [Nexus Mods: SF6 Round Announcement UI (Graffiti UI)](https://www.nexusmods.com/streetfighter6/mods/2564)
  - a Warner Bros. "Street Style" minigames UI portfolio (urban, graffiti, street-styled) — [Tom Miller ArtStation: "Street Style" Minigames UI](https://thomasmiller.artstation.com/projects/2g6wB?album_id=90707)
- Grafitti/marker fonts available in Roblox: **Permanent Marker**, **Bangers**, **Rubik Wet Paint**, **Rubik Marker Hatch**, **Bungee Inline/Shade**. — [Gist: Roblox font list](https://gist.github.com/cxmeel/38f6d9ba5dc5fd048489a37853bcaa87)

### Inferences: proposed "Hood" palette and theme (proposal, not sourced values)

**Core tokens**
| Token | Hex | Use |
|---|---|---|
| `ink` | `#1C1830` | All outer outlines, text strokes on light panels, hard shadows (at 0 transparency, offset 4 px down) |
| `asphalt` | `#2B2E45` | Dark insets, list wells, progress-bar tracks (never the main panel) |
| `asphalt-line` | `#FFD23F` | Dashed "road line" accents on dark insets |
| `cardboard` | `#FFEFD2` | Default panel body (warm paper/cardboard) |
| `cardboard-inset` | `#F4D9A8` | Inner wells, card backgrounds on panels |
| `cardboard-edge` | `#C99A5B` | Panel bevel / bottom lip |
| `brick` | `#E2553D` / lip `#9C2F22` | Panel header strips, "Hood" brand accent |
| `concrete` | `#D9D4CC` | Disabled fills, Common rarity backing |

**Function colors** (each has `top` highlight / `base` / `lip` shade / `stroke`)
| Function | top | base | lip | stroke |
|---|---|---|---|---|
| Buy / Confirm / Claim (green) | `#8CF06A` | `#43C24A` | `#23802C` | `#123F17` |
| Primary CTA / Power (yellow; Clash rule: most important = yellow) | `#FFE76A` | `#FFC21A` | `#D57D00` | `#5A2E00` |
| Close / Cancel / Danger (red) | `#FF8A8A` | `#FF4757` | `#B01E35` | `#4A0B16` |
| Info / Navigate / Teleport (blue) | `#7CCBFF` | `#2F9BFF` | `#1A5FB4` | `#0B2A55` |
| Robux purchase | Green button with the Robux glyph; keep it the same green as Buy for trust | | | |
| Neon (rebirth, limited, sale only) | pink `#FF3EA5`, cyan `#2EF2FF` with outer glow | | | |

**Currencies**
- **Power**: electric yellow `#FFC21A` with a fist or lightning icon.
- **Cash**: dollar green `#3FD46B` with a banknote-stack icon.
- Numbers on both: white, ink stroke.

**Rarity ladder** (cross-industry standard, extended)
| Rarity | Color | Treatment |
|---|---|---|
| Common | `#B8BEC8` | Flat |
| Uncommon | `#5BD45B` | Flat |
| Rare | `#3D9BFF` | Flat |
| Epic | `#A64DFF` | Flat |
| Legendary | `#FFB020` | Gradient + shine sweep |
| Mythic | `#FF3B5C` | Gradient + sparkles |
| Secret | `#15121F` card with animated rainbow/neon UIGradient stroke | Rotating gradient, unique sound |

- Card background = rarity color at about 25–35% tinted into `cardboard-inset`, or as a radial gradient behind the item render. Stroke = darker rarity shade. A rarity label pill sits at the bottom.
- Only Legendary and up animate. Restraint makes them special.

**Text**
- Labels on colored buttons: white with a stroke in that button's dark shade.
- Body text on cardboard: ink, no stroke.
- Numbers in the HUD: white + ink stroke + 2 px drop shadow, so they read over any 3D scene.

**Fonts (max three families)**
- **Titles and CTA buttons**: a heavy display face, either **Luckiest Guy** (watch for the UIStroke hole artifact, so test glyphs) or **Bangers** for a comic/street feel.
- **Numbers and labels**: **Builder Sans ExtraBold** (Roblox-native, crisp digits) or **Fredoka One** if a rounded look is preferred.
- **Accent only**: **Permanent Marker** for graffiti "tags", e.g. "NEW!", "HOT", "SALE", Crew nicknames on sticker badges. Never for numbers or long text.
- Type scale at a 1920×1080 reference: 48 (modal titles) / 32 (CTA, big numbers) / 24 (buttons, card titles) / 18 (labels) / 14 (fine print, avoid on mobile). Scale down via `UIScale` on small screens, not via `TextScaled`.

**Street-themed but readable: theme ideas**
- **Cardboard and paper panels** with a slightly irregular 9-slice edge and a **masking-tape strip** holding the header (tape at 5–8° rotation, semi-opaque cream `#F3E6C4`).
- **Die-cut sticker icons**: illustrated icon → 3–4 px **white** sticker border → 2–3 px ink outline → hard shadow. Use for side buttons, Crew pets and outfit badges. This reads like stickers on a skateboard or laptop and suits "hood" while staying cartoony.
- **Spray-paint tags** behind section titles (Permanent Marker / Rubik Wet Paint in brick or neon, rotated −4°), a drippy underline for "REBIRTH", and stencil numbers for wall/stage numbers.
- **Street signs** for navigation: green street-sign plates for Walls/Stages teleports ("1ST ST", "BLOCK 2"), and a yellow diamond warning sign for confirmation popups ("ARE YOU SURE?").
- **Neon shop sign** for the Shop header and Rebirth: neon tube text with outer glow, flickering once on open. Neon only on 1–2 screens, so it stays special.
- **Chain-link, brick or asphalt patterns** inside panels at 3–6% opacity (low chroma, per Splatoon's rule) so they never fight the content.
- **Boombox / gold chain / sneaker motifs** for icons: training bag, Power fist, Cash stack, Crew paw-with-cap, Outfit hanger with hoodie, Rebirth spray can or recycle arrows, Leaderboard trophy-with-chain.
- **Leaderboards** styled as a **"Wall of Fame"** brick wall: top-3 rows as gold/silver/bronze spray-painted plaques.
- **Outfit shop (15 looks)**: a 5×3 grid on PC, 3×5 scroll on mobile. Each card has a character render via ViewportFrame or pre-rendered image, a rarity backing, the name in the title font, and a price pill. Owned = green check sticker. Equipped = yellow "WEARING" tape across the corner. Locked = grey with padlock and requirement text. Selected = thick yellow outer stroke + slight scale-up + preview on a 3D mannequin on the left.

### Gaps
- No published hex values from any target game. All hex codes above are proposals and should be validated with a contrast check and on-device tests.
- No Roblox game with an established "hood/street" cartoony UI was found to benchmark against.

---

## Q6. UI motion as part of the look: conventions and timing

### Takeaway
Motion is part of cartoony UI's style:
- buttons squash and spring back
- popups scale in from about 0.7–0.85 with a slight overshoot
- numbers tick up and pop
- important CTAs get a periodic shine sweep

Keep it fast: presses about 80–120 ms, popups about 0.2–0.35 s. Reserve continuous motion for the one or two things that matter, because Roblox's docs warn that too many moving elements overwhelm players.

### Cited Findings
- Roblox: "Moderation is key… Excessive use of bright, moving elements might overwhelm and confuse players." Movement is one of five attention tools. — [Roblox Creator Docs: UI and UX design](https://github.com/Roblox/creator-docs/blob/main/content/en-us/production/game-design/ui-ux-design.md)
- Roblox: "provide at least one form of visual feedback for interactable UI elements". — [Roblox Creator Docs: Choose an art style](https://github.com/Roblox/creator-docs/blob/main/content/en-us/tutorials/curriculums/user-interface-design/choose-an-art-style.md)
- Popup convention on Roblox: add a `UIScale` and tween `Scale` **from 0.7 to 1**, together with transparency tweens per Open/Close state. — [DevForum: How do I make this kind of UI popup animation](https://devforum.roblox.com/t/how-do-i-make-this-kind-of-ui-popup-animation/1468785)
- Hover tweens commonly use about **0.3 s** Quad InOut on `MouseEnter` / `MouseLeave`, with `Activated` for click. — [DevForum: Hover Button script](https://devforum.roblox.com/t/hover-button-script/2802290); [DevForum: Animation tween on all buttons with 1 script](https://devforum.roblox.com/t/animation-tween-on-all-buttons-with-1-script/2644255)
- Squash-and-stretch press: "crushes wide and short, overshoots tall and thin on the way back, and settles", about **420 ms** total. A spring version uses stiffness 360 / damping 16 ("lower = more wobble"). — [Valdemird: Game feel on the web](https://valdemird.com/blog/game-feel-on-the-web/)
- A web motion spec uses "press 120 ms" and settle at 1.04–1.06 without bounce. This is a web, not game, reference; game UI is usually bouncier. — [GitHub cubealgos/website issue #9](https://github.com/cubealgos/website/issues/9)
- **Shine sweep**: a UIGradient whose ColorSequence is primary → lighter → primary, rotated about **45°**, with its `Offset` tweened across the element. Animate Offset rather than Rotation. — [DevForum: 4 UIGradient Animations](https://devforum.roblox.com/t/4-uigradient-animations-including-rainbow/557922); [DevForum: GUI Shine Module](https://devforum.roblox.com/t/open-source-simple-ui-shineglint-module/4816664); [GitHub: GradientKit](https://github.com/biotoxin495/GradientKit)
- Clash Royale gives its most important yellow buttons "animated highlights". — [The Rookies](https://www.therookies.co/blog/education/game-design-ux-best-practices-detailed-breakdown-of-clash-royale)
- Don't tween UIStroke `Thickness` on text (performance). — [Roblox Creator Docs: Appearance modifiers](https://github.com/Roblox/creator-docs/blob/main/content/en-us/ui/appearance-modifiers.md)

### Inferences (recommended Hood motion tokens; implementation details belong to the other researcher)

| Interaction | Motion | Timing |
|---|---|---|
| Button hover (PC) | Scale 1.0 → 1.05, highlight brightens | 0.12–0.15 s, Quad Out |
| Button press | Scale → 0.92 (or body drops onto lip) | 0.06–0.10 s, Quad Out |
| Button release | Overshoot to 1.06, then 1.0 | 0.18–0.25 s, Back Out |
| Popup open | UIScale 0.8 → 1.0, overlay fades 0 → 0.45 | 0.22–0.30 s, Back Out |
| Popup close | UIScale 1.0 → 0.85 + fade | 0.12–0.18 s, Quad In |
| Currency gain | Number ticks up, icon pops 1.0 → 1.25 → 1.0, "+1.2K" floater rises | Tick 0.4–0.8 s; pop 0.15 s; floater fades over about 0.8 s |
| Big reward / rebirth | Burst rays rotating behind, confetti, screen-center card, rarity-colored glow | 1.0–1.5 s total, skippable on tap |
| Shine sweep | Primary CTA and Legendary+ cards only | One sweep of about 0.6–0.8 s, every 3–5 s |
| Notification badge | Idle bounce or wobble (±6°) | Every 2–3 s |
| Toast | Slide in + fade, hold, slide out | In 0.2–0.25 s; hold 2–3 s |
| Tutorial arrow | Bob up and down 8–12 px | Loop 0.6–0.8 s, Sine InOut |

Also: every motion should pair with a short UI sound (click, pop, coin), because juice is audio plus visual.

### Gaps
- No source gave measured timings from PS99, GAG or SaB specifically. The values above are synthesized from general game-feel sources and common Roblox patterns.
- Number tick-up timing and "reward burst" conventions came from no Roblox-specific source. Those rows are inferences.
