# Huzz Valley UI V2 — references, positions and character bindings

Upload this ZIP plus your actual Roblox project. Send the AI:

**Read START-HERE.md, IMPLEMENTATION-PROMPT.md, CHARACTER-REPLACEMENT-MAP.md and specifications/PAGE-POSITIONS.md. Implement all 18 pages using the included page images, annotated positions and real project data. Use approved-original.png as the existing design authority.**

## Contents
- 18 separate page references and 18 numbered position overlays.
- Exact source-pixel crops of 46 icons/badges with coordinate/provenance data.
- A full icon reference overview.
- Exact specified 1920×1080 implementation coordinates, reference rectangles and normalized window coordinates for major controls.
- A detailed character-slot replacement map (catalogue NPCs, real player avatars, cosmetics, dance/reward previews, world companions).
- Shared theme and stud texture, detailed implementation prompt and missing-asset rules.

## What is exact and what is not
The six selected page crops and source icon crops preserve original screenshot pixels. Icon crops are NOT transparent original artwork: background is baked in and resolution is small. They are precise visual references for extraction/tracing, not guaranteed ready-to-import production sprites.

The twelve additional pages are generated extensions of the approved style. Their screenshots are now concrete layout references, not a claim that an existing game implements them. Positions are explicit reconstruction targets; no hidden original GUI metadata was recovered. Native text and high-resolution traced icons can differ until calibrated in Studio.

Actual Roblox NPC models, avatar-specific poses, real animation assets, official Robux artwork, product IDs and the gameplay backend are NOT supplied. The complete slot map tells the coding AI exactly where each belongs; it does not pretend the assets already exist. No prompt can manufacture a one-to-one live model from this screenshot.

## Page/state coverage
Shop: passes/cosmetics/coins. Collection and Dances: their base layout plus defined All/Owned/Favourites/search/filter states. Progression: rewards/quests. Settings: audio/controls/social. Tiers and main menu. Lobby and match HUD. Map vote, recruitment, results, gifting.

Filtered tabs reuse the same page layout. Dedicated error/empty/confirmation states use that same shell. They are defined by the prompt instead of having a new invented layout for each content combination.

## Production prerequisites
Supply your project, configure real catalogue models and dance animations, connect existing server data/purchases/rewards, import clean icon assets and the official Robux icon. Use the screenshot crops as the tracing reference, not the earlier approximation pack.
