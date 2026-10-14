# Huzz Valley

The UI for Huzz Valley, built from your Huzz-Valley-UI-V2 kit (kept in `design/`). This first build is the "golden slice":
- the **Lobby HUD**;
- the **Main Menu**;
- the **Shop**, with its Passes, Cosmetics and Coins tabs;
- **Settings**, with its Audio, Controls and Social tabs;
- the **Character Index**, **Tiers**, **Dances** and **Progression** (Rewards and Quests) pages ([pictures](docs/previews/new-pages.jpg)).

All of these work against a real save system. When you're happy with how they look in Studio, the same parts get used to build the other pages.

![Ours under each reference](docs/previews/overview.jpg)

## Quickest way: open the ready-made game file
`places/HuzzValley.rbxl` has all the scripts plus a simple grass baseplate. You don't need Rojo.
1. On your Mac, open it on GitHub (branch **HUZZ-VALLEY**, folder `huzz-valley/places`) and click **Download raw file**. Or pull in GitHub Desktop and find it in the folder.
2. Double-click it, or in Studio use **File → Open from File**. Press **Play**.
3. To make it your real Huzz Valley game, use **File → Publish to Roblox As** and pick your Huzz Valley place. Your current place is empty, so nothing gets lost.

## Editing the UI in Studio
The whole UI is in **StarterGui > HuzzUI** as normal parts you can click and change.
- The HUD (side buttons, coins, gear) shows straight away. Each window (Shop, Settings, Index, and so on) is hidden: tick its **Visible** box to see it while you edit, then untick it again.
- **What stays in the game:** changes to position, size, colours, fonts, images and corners.
- **What the scripts still set:** text and on/off states.
- **Icons look empty while editing.** The game draws them when it runs. Upload an icon and paste its ID into the image's **Image** box to see it in Studio too.
- **What doesn't stay:** edits to items inside lists (shop items, character and dance cards, rewards and quests), because the game redraws them. Tell me what you want changed there.
- **Before you ask me for UI changes after editing in Studio,** send me your export (the usual `tools/export-for-claude.lua` steps). Each new game file I make starts from my copy, so your edits need to come to me first.
- **If you use Rojo:** connecting Rojo replaces StarterGui > HuzzUI with my copy, so save your edits and send them to me first.

## Getting it into Studio with Rojo (for live updates)
1. In GitHub Desktop, switch to the **HUZZ-VALLEY** branch and click **Pull**.
2. Follow [ROJO-SETUP.md](../ROJO-SETUP.md), running `rojo serve` from this `huzz-valley` folder.
3. Open your Huzz Valley place, then go to **Plugins → Rojo → Connect** and press **Play**.

**What to try:**
- Press **M**, or click **Menu**.
- Open the **Shop** and switch tabs.
- Open **Settings** with the gear and change things. The changes stay while you play in Studio. Studio uses test saves, so they reset when you press Stop.

## Your checklist (things only you can do)
1. **Upload the pictures once, so they show everywhere, including StarterGui while you edit:**
   1. Open the place in Studio (not while playing) and open **View → Command Bar**.
   2. Paste all of `huzz-valley/tools/studio/upload-images.lua` into it, press Enter, and wait for **Done** in the Output window.
   3. Save, then send me the text of **ReplicatedStorage → Shared → Config → ImageIds**, so my next game file has them too.
   - New pictures can stay grey for a few minutes while Roblox checks them.
   - If it shows red errors, send me a screenshot.
2. **Create the Robux items** on the Creator Dashboard after you publish:
   1. **VIP** is a Game Pass (it gives the [VIP] chat tag).
   2. **Sunset Trail** and **Blossom Aura** are Developer Products.
   3. Put each ID into `src/ReplicatedStorage/Shared/Config/Products.lua` (`Id = ...`). Until then their buttons say the item isn't on sale and never open a purchase.
   4. Prices there are placeholders. Roblox's live price shows automatically once an ID is set.
3. **Things that need assets before they can go on sale** show their price, but only say "coming soon" when tapped:
   - Dance Pack: the 4 dance animations;
   - Crown Pose: a pose animation;
   - Midnight Outfit: the clothing;
   - coin packs: they turn on once coins can buy something.

## What's honest about this build
- **Pictures and icons:** almost all are now your sharp files (`design/sharp` and `design/icons-hd`), used as drawn and only trimmed to fit their spots. Nine small icons are still the soft kit crops: the favourite stars, the equipped tick, the quest clipboard, stopwatch, fist, shirt, sneaker, small gift and small music note. Your pictures have see-through backgrounds, so the cards show a blue backdrop behind them.
- **Product pictures** show your own avatar, because there are no companion models yet. The coin cards use the coin icon instead of the gold-cube stacks.
- **The next-round timer** only appears once a round system exists. It never shows a made-up countdown.
- **Gifting** says "unavailable" until the Gift Picker is built.
- **The Social settings** save and are checked on the server, but nothing in the game shows inventories or sends invites yet.
- **The Controls tab:** Dash and Dances show SOON until those exist. The Open Menu key can be changed now.
- **The pictures above come from an offline preview, not Studio.** Fonts and layout are close; the Robux sign and the blur behind windows are approximate. Your look in Studio is the real test.
