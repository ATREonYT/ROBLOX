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
- a transparent background if the AI can do it; otherwise one plain, strong flat colour such as bright green or
  magenta (Claude removes it). Avoid white or grey backgrounds: they get confused with white parts of the picture;
- no words or numbers in the picture ("2x" stickers, prices and names are drawn by the game);
- no characters from other games or films.

## Brief 30: the new style (use this instead of the older prompt below)

Attach the 3 shop screenshots you sent (Exclusive Shop, the pass cards, the cash packs) as style examples, then write:

> Roblox simulator shop icon of **[OBJECT]**. Glossy, chunky cartoon object in exactly the style of the attached
> shop icons: bright saturated colours, smooth soft shading with a strong white shine on the top-left, slightly
> blocky / voxel-like shapes where it suits the object (like the attached four-leaf clover made of cubes), a thick
> even dark outline around the whole shape, slight three-quarter view from above. One object, centred, filling most
> of the square, no text or numbers, no ground shadow, transparent background. Square image, 1024 x 1024.

For the Featured backgrounds use the same style, but:

> Wide painted background for a Roblox shop card, **[SCENE]**, in the same glossy cartoon style as the attached
> "Heaven Pack" card, soft and slightly blurred so items can sit on top, bright and readable, no text, no
> characters. Wide image, 1536 x 576.

### Brief 30 list (file name = what the game looks for)

| File name | [OBJECT] or [SCENE] |
|---|---|
| `DoublePower.png` | a golden flexed strong arm with a lightning bolt |
| `DoubleCash.png` | two chunky stacks of green dollar bills with a big gold "x2"-shaped sparkle (no text) |
| `VIP.png` | a gold crown with red and blue gems |
| `AutoFight.png` | a cartoon submachine gun inside a green circular arrow |
| `Lucky.png` | a green four-leaf clover made of chunky cubes, with sparkles |
| `TripleOpen.png` | three small shoe boxes stacked together |
| `ExtraEquip.png` | a blue sneaker with a green plus badge |
| `TenXCash.png` | a big green money bag overflowing with bills |
| `ProBay.png` | a green and white bullseye target on a stand |
| `GoldBay.png` | a golden bullseye target with a small crown on top |
| `AutoOpen.png` | a shoe box with its lid popping open and a circular arrow around it |
| `Speed2x.png` | a sneaker with speed lines and a lightning bolt |
| `ServerBoost.png` | a big chunky golden lightning bolt made of cubes, with sparkles |
| `BlockParty.png` | a purple party popper with confetti |
| `CashTiny.png` | one small stack of green bills and two gold coins |
| `CashSmall.png` | a money bag with a dollar sign and a few coins |
| `CashMedium.png` | an open treasure chest full of bills and coins |
| `CashBig.png` | a blue vault door with bills spilling out |
| `CashLarge.png` | a big heap of bill stacks, gold coins and money bags |
| `CashMega.png` | a giant mountain of bill stacks, gold bars and money bags, with sparkles |
| `PowerTiny.png` … `PowerMega.png` | the same six-step ladder but with red dumbbells, growing from one dumbbell to a glowing mountain |
| `PotionRed.png` / `PotionGold.png` | a star-shaped glass potion with red / yellow liquid and a gold cork |
| `Gift.png` | a blue gift box with a red ribbon (the Gift A Player button) |
| `FeaturedBg_Grail.png` | [SCENE] a golden vault with stacked cash and a glowing shoe box on a plinth |
| `FeaturedBg_Street.png` | [SCENE] a sunny hood street block party with balloons and a DJ booth |
| `FeaturedBg_Sneaker.png` | [SCENE] a bright sneaker shop wall with shelves of colourful shoe boxes |

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
