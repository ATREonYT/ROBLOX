# ROBLOX Games

Games built together with Claude, one at a time.

| # | Game | Status | What it is |
|---|------|--------|------------|
| 1 | [Snatch a Brainrot](snatch-a-brainrot/) | ✅ Playable | Bright cartoony remake of *Steal a Brainrot* — 24 characters, mutations, stealing, fusion altar, rush events |
| 2 | [Plus One Speed: Candy Keyboard](plus-one-speed/) | ✅ Playable | Faithful *+1 Speed Keyboard Escape*-style game — clicking candy keycaps, digit plates, treadmills, trails, rebirths, full GUI |
| 3 | [Steal an Egg](steal-an-egg/) | ✅ Playable | Rebuild of *Steal an Egg* on its real canyon map — zone-by-zone wild eggs, hatching into birds, stealing, base locks, events, server-backed Trail Shop |
| 4 | [Hood (From the Block)](hood/) | 🚧 In progress | Your own game, exported from Studio — earn Power, unlock 15 looks from Corner Kid to Kingpin, train at gyms; walls, pets and new neighborhoods planned |
| 5 | [Huzz Valley](huzz-valley/) | 🚧 In progress | UI from your V2 kit on real saves, plus the core round loop: race across, dodge catchers, carry the girl overhead, steal her back, win her for your Index |

Each game folder has its own README with step-by-step setup instructions —
no coding experience needed.

## Sending Claude a game from Studio

[`tools/export-for-claude.lua`](tools/export-for-claude.lua) works for any
place. Open the place in Studio, paste the whole file into **View →
Command Bar**, and press Enter. Then copy each
`ServerStorage → ClaudeExport → PartN` into the chat. Delete the
`ClaudeExport` folder afterwards — it never runs in your game.
