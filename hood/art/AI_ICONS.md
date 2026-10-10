# Making the UI pictures with an image AI

You make the pictures, Claude puts them in the game: it cleans each one up, sizes it like the others, checks it
reads at phone size, and wires it into the UI. Then you run the upload command once.

## How to send them

1. Save each picture as a PNG with the exact file name from the lists below (for example `World.png`).
2. Put the files in `hood/art/incoming/` in this repo.
3. Commit and push them on the branch `claude/elegant-cannon-i9r37o` (GitHub Desktop: Commit, then Push), and tell
   Claude. Sending them only in the chat lets Claude see them, but not always save them as files, so push them.

**Each picture:**
- one object, centred, nothing else in the picture;
- square, at least 512 x 512;
- a transparent background if the AI can do it; otherwise one plain flat colour (Claude removes it);
- no words or numbers in the picture ("2x" stickers, prices and names are drawn by the game);
- no characters from other games or films.

## The style prompt (use it for every picture, so they all match)

Attach 2 or 3 of the reference screenshots (the HUD buttons, the Store window) to the AI as style examples, then
write:

> Roblox simulator game UI icon of **[OBJECT]**. Chunky cartoon object in the same style as the attached icons:
> soft gentle shading with bright saturated colours, thin sharp white highlight streaks along the top-left edges,
> subtle raised rounded square tiles (like Roblox bricks) on hard surfaces, a thick even dark navy outline around
> the whole shape, slight three-quarter view from above. One object, centred, no text, no ground shadow,
> transparent background. Square image.

Replace **[OBJECT]** with the description from the lists. Keep the rest of the prompt the same every time.

## First batch: the buttons you see all the time

| File name | [OBJECT] |
|---|---|
| `Basket.png` | an orange shopping basket with a grey-blue handle (the Store button) |
| `BasketRed.png` | a red shopping basket with a grey-blue handle (the Store window title) |
| `World.png` | a round planet Earth globe, blue sea and big green continents |
| `Rebirth.png` | two thick curved arrows, one red and one white, chasing each other in a circle |
| `Sneaker.png` | a red and white high-top sneaker, side view |
| `Gun.png` | a grey cartoon pistol with a brown grip, side view |
| `Backpack.png` | a red school backpack with a flap and two straps |
| `Quest.png` | a rolled paper scroll tied with a red ribbon |
| `Rewards.png` | a pink gift box with a gold ribbon and bow |
| `Power.png` | an orange flexed strong arm (bicep), fist up |
| `Cash.png` | a stack of green dollar bills with a paper band and a gold coin |

## Second batch: the Store

| File name | [OBJECT] |
|---|---|
| `PotionRed.png` | a star-shaped glass potion bottle with red liquid and a gold cork |
| `PotionGold.png` | a star-shaped glass potion bottle with yellow liquid and a gold cork |
| `BoostBundle.png` | three star-shaped potion bottles (red, yellow, blue) grouped together |
| `CashTiny.png` | one small stack of green dollar bills and two gold coins |
| `CashSmall.png` | three stacks of green dollar bills and a few gold coins |
| `CashMedium.png` | a pile of green dollar bill stacks, gold coins and a money bag with a dollar sign |
| `CashLarge.png` | a big heap of green dollar bill stacks, gold coins and money bags, with sparkles |
| `PowerTiny.png` | one red dumbbell |
| `PowerSmall.png` | two red dumbbells |
| `PowerMedium.png` | a small rack of red dumbbells |
| `PowerLarge.png` | a big glowing pile of red dumbbells with sparkles |
| `DoublePower.png` | a golden flexed strong arm with a lightning bolt |
| `DoubleCash.png` | two stacks of green dollar bills with a lightning bolt |
| `VIP.png` | a gold crown with a red gem |
| `AutoFight.png` | a cartoon submachine gun inside a green circular arrow |
| `Lucky.png` | a green four-leaf clover |
| `TripleOpen.png` | three small shoe boxes stacked together |
| `ExtraEquip.png` | a blue sneaker with a green plus badge |
| `TenXCash.png` | a big green money bag with a dollar sign, overflowing with bills |
| `ProBay.png` | a green and white bullseye target on a stand |
| `GoldBay.png` | a golden bullseye target on a stand with a small crown on top |
| `BlockParty.png` | a purple party popper with confetti |
| `RebirthSkip.png` | the two curved arrows, one green and one white, in a circle |

## Third batch: small extras

| File name | [OBJECT] |
|---|---|
| `Delete.png` | a pink-red X made of rounded blocks |
| `Favorite.png` | a gold star |
| `XP.png` | a blue shield badge |
| `Trophy.png` | a gold trophy cup |
| `Arrow.png` | a big green arrow pointing up |
| `ShoeBox.png` | an orange shoe box with a sneaker picture on the side |
| `Box_Street.png` | a white shoe box with a red lid |
| `Box_Graffiti.png` | a black shoe box with a pink lid and paint splashes |
| `Box_Exclusive.png` | a white and blue shoe box with a diamond on the lid |
| `Box_Grail.png` | a purple and gold shoe box with little gold wings |

The shoe and gun pictures (`Shoe_*`, `Gun_*`) are made from the game's own 3D shoes and guns so they match what you
wear and hold; Claude matches their outline and colours to your set.

## After Claude has put them in

Claude tells you when they're in. Then upload them (same as before):

```
cd ~/Documents/GitHub/ROBLOX
git checkout -- hood/places/HoodEvolution.rbxl
git pull
export ROBLOX_CREATOR_ID=36081705
export ROBLOX_CREATOR_TYPE=Group
read -s ROBLOX_API_KEY
export ROBLOX_API_KEY
/usr/bin/python3 hood/tools/upload_assets.py
git add hood/art/asset_ids.json hood/src && git commit -m "Upload icon ids" && git push
```

Check which pictures Roblox has approved: `/usr/bin/python3 hood/tools/upload_assets.py --status`. A picture shows
in the game only after it's approved.
