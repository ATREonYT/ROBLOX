# Huzz Valley

The UI for Huzz Valley, built from your Huzz-Valley-UI-V2 kit (kept in `design/`). This first build is the "golden slice":
- the **Lobby HUD**;
- the **Main Menu**;
- the **Shop**, with its Passes, Cosmetics and Coins tabs;
- **Settings**, with its Audio, Controls and Social tabs.

All of these work against a real save system. When you're happy with how they look in Studio, the same parts get used to build the other pages.

![Ours under each reference](docs/previews/overview.jpg)

## Getting it into Studio
1. In GitHub Desktop, switch to the **HUZZ-VALLEY** branch and click **Pull**.
2. Follow [ROJO-SETUP.md](../ROJO-SETUP.md), running `rojo serve` from this `huzz-valley` folder.
3. Open your Huzz Valley place, then go to **Plugins → Rojo → Connect** and press **Play**.

**What to try:**
- Press **M**, or click **Menu**.
- Open the **Shop** and switch tabs.
- Open **Settings** with the gear and change things. The changes stay while you play in Studio. Studio uses test saves, so they reset when you press Stop.

## Your checklist (things only you can do)
1. **Import the icons.** They stay blank in Studio until you do this.
   1. Go to **View → Asset Manager → Bulk Import** and select every PNG in `huzz-valley/assets/icons`.
   2. Right-click each imported image, choose **Copy ID**, and paste it into `src/ReplicatedStorage/Shared/Config/Assets.lua` next to its name, like `"rbxassetid://123..."`. You can also just send me the list of names and IDs.
2. **Create the Robux items** on the Creator Dashboard after you publish:
   1. **VIP** is a Game Pass (it gives the [VIP] chat tag).
   2. **Sunset Trail** and **Blossom Aura** are Developer Products.
   3. Put each ID into `src/ReplicatedStorage/Shared/Config/Products.lua` (`Id = ...`). Until then their buttons say the item isn't on sale and never open a purchase.
   4. Prices there are placeholders. Roblox's live price shows automatically once an ID is set.
3. **Things that need assets before they can go on sale** show **SOON** for now:
   - Dance Pack: the 4 dance animations;
   - Crown Pose: a pose animation;
   - Midnight Outfit: the clothing;
   - coin packs: they turn on once coins can buy something.

## What's honest about this build
- **Icons** are your exact files from the kit, used unchanged. They are small (about 30-60 px) and have their background baked in. On a background of a different colour, a square edge can show, and at big sizes they look a bit soft.
- **Product pictures** show your own avatar, because there are no companion models yet. The coin cards use the coin icon instead of the gold-cube stacks.
- **The next-round timer** only appears once a round system exists. It never shows a made-up countdown.
- **Gifting** says "unavailable" until the Gift Picker is built.
- **The Social settings** save and are checked on the server, but nothing in the game shows inventories or sends invites yet.
- **The Controls tab:** Dash and Dances show SOON until those exist. The Open Menu key can be changed now.
- **The pictures above come from an offline preview, not Studio.** Fonts and layout are close; the Robux sign and the blur behind windows are approximate. Your look in Studio is the real test.
