# Every icon the game's screens use (Oct 27)

The owner asked for the full list so they can draw them. Each name below is the file name to use
(`<Name>.png`). Icons the code no longer shows are left out (PVP, BasketRed, AutoFight, PowerTiny,
PowerSmall, ProBay, GoldBay).

## How to make each one
- PNG, 512 x 512, transparent background.
- The picture centred, its longer side about 88% of the square (the same framing for all).
- Flat, bright cartoon look with a thick dark outline (#060632), like the reference game's icons.
- Name the file exactly as below (capital letters matter), e.g. `Shop.png`.

## Main buttons (left side and top of the screen)
Shop, Rebirth, Rewards, Backpack, World (the worlds/teleport button), Missions, Quest, Rank,
SkinsPistol (the Skins/guns button), Trophy (leaderboards), Evolve, Sneaker (shoes), ShoeBox,
ShoePile, Gun, Muscle, Basket, Shield, Skull, XP, VIP, Arrow (pointers), RebirthSkip.

## Money and Power
Cash, Power, Robux, CashTiny, CashSmall, CashMedium, CashLarge, PowerMedium, PowerLarge.

## Shop items (Robux products and passes)
PowerPack1, PowerPack2, PowerPack3 (small, medium, big Power pack), DoublePower, DoubleCash,
TenXCash, Lucky, TripleOpen (open 3 boxes), ExtraEquip, AutoCollect, BoostBundle,
PotionRed, PotionGold, BlockParty.

## Free rewards
SpinWheel, SpinWheelDisc (the wheel itself, seen from the front, so it can spin), PlaytimeGift,
StarterCrate.

## Small buttons in windows
Delete (trash can), Favorite (star), Search (magnifier).

## Pictures that come from the 3D models (no need to draw unless you want to)
One per shoe (`Shoe_<shoe>`), per shoe box (`Box_<box>`, with its lid and body as `BoxLid_<box>`
and `BoxBase_<box>`) and per gun (`Gun_<gun>`). These are rendered from the game's models.

## Sending them
Send the PNGs in the chat, or put them in `hood/art/icons3d/` and push with GitHub Desktop. They
still need uploading to Roblox (Studio's Asset Manager, or `hood/tools/upload_assets.py` with your
key); the ids then go in `ReplicatedStorage/Shared/Models/IconModels.lua`.
