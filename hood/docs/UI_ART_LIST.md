# +1 Hood Evolution: the UI pictures to make (Oct 27)

What every piece of the UI should look like, taken from the soldier game's screens we copy (references:
`hood/docs/refs/ref_W01.0_spawn_view_north.jpg` for the main screen, `ref_V3-00.5_store_exclusive.jpg` for a window) and
your Skip Rebirth button. The game writes the words, numbers and prices on top, so **make every button and panel EMPTY
(no text)** unless it says otherwise. Icons are a separate list (`ICON_LIST.md`, already done).

## The look (the owner's pick, Oct 27: `hood/docs/refs/ui/ref_ui_shop_*.png`)
The shop in those pictures is the model for every window:
- the window's inside is a **bright lime green** with a faint big-block pattern, framed in a thick dark grey-blue border;
- a **yellow-gold header bar** across the top with the title in white with a dark outline, a blue **Gift A Player** button
  and a **red square X** at its right end;
- the contents are **cards in solid bold colours** (red, yellow-orange, sky blue, green, purple), each with a dark outline,
  a faint square pattern, a big glossy picture on the left (clover, dice, cash stack) and the title, one line of
  description and a **yellow pill button** (Buy / OWNED) on the right;
- section titles ("CASH PACKS", "COMMUNITY CODES") in white with a dark outline on a darker strip;
- pack cards are tall tiles with the big amount ("10K", "250K") in yellow-gold and the price in a white-outlined pill.

Paste this at the start of every AI prompt:
> Roblox simulator game UI in the style of popular Roblox simulators: bright lime-green window with a faint block
> pattern, thick dark outline on everything, yellow-gold header bar, solid bold-coloured cards (red, yellow, blue, green,
> purple) with a subtle square pattern, glossy cartoon pictures, chunky rounded shapes, a lighter top and darker bottom
> lip so things look raised. No text. Transparent background, PNG, straight-on view.

## A. Main screen buttons
| # | File name | Size (w x h) | What it looks like |
|---|---|---|---|
| A1 | `Btn_Shop.png` | 620 x 240 | Wide pill, warm yellow-orange gradient, thick outline. Space on the left where the basket icon pokes out over the top. |
| A2 | `Btn_Square_Yellow.png` | 280 x 280 | Rounded square, yellow (Rebirth, Items). Shine streak, dark lip. Room for an icon in the middle and a word at the bottom. |
| A3 | `Btn_Square_Blue.png` | 280 x 280 | Same, bright blue (Shoes, Skins). |
| A4 | `Btn_Square_Red.png` | 280 x 280 | Same, red (spare colour for new buttons). |
| A5 | `Card_Offer_Gold.png` | 640 x 210 | The "x2 Cash" card: a wide rounded card, gold-yellow gradient, a darker gold bottom strip for the price. |
| A6 | `Card_Offer_Cyan.png` | 640 x 210 | Same in cyan (x2 Power). |
| A7 | `Btn_Pack.png` | 480 x 140 | Small Power-pack button under the bar: purple-blue gradient, a dark tag on the right for the Robux price. |
| A8 | `Bar_Rebirth_Frame.png` | 1600 x 150 | The rebirth bar's frame: a long rounded trough, dark see-through inside, thick outline, small studs. |
| A9 | `Bar_Rebirth_Fill.png` | 1600 x 150 | Its fill: a purple-to-pink glossy gradient with a shine streak (stretches, so keep the ends simple). |
| A10 | `Btn_AutoFight.png` | 280 x 160 | Small rounded button, green when on, with room for a crossed-swords icon. |
| A11 | `Btn_SkipRebirth.png` | 900 x 230 | Like yours: a rainbow gradient (red to orange to yellow to green to blue to pink), thick outline, sparkles. |
| A12 | `Btn_Plus.png` | 140 x 140 | The green square "+" (Friend Boost). This one has the + drawn on it. |
| A13 | `Badge_Bang.png` | 120 x 120 | The rainbow round "!" badge for "something new". |
| A14 | `Badge_Count.png` | 100 x 100 | A cyan circle with an outline (the game writes the number). |
| A15 | `Pill_Percent.png` | 200 x 100 | A small dark pill for "57%". |

## B. Windows
| # | File name | Size | What it looks like |
|---|---|---|---|
| B1 | `Win_Panel.png` | 2000 x 1300 | The window body: lime green inside with a faint big-block pattern, a thick dark grey-blue frame. |
| B2 | `Win_Header.png` | 2000 x 200 | The header bar across the top: yellow-gold, lighter on top, a darker bottom edge. |
| B2b | `Btn_Gift.png` | 700 x 140 | The blue "Gift A Player" button with the gift box on its left (word written by the game). |
| B3 | `Btn_Close.png` | 200 x 200 | The red square X button: bright red, white X drawn on it, thick outline, shine (as in the reference's top-right). |
| B4 | `Card_Item_Common.png` ... `_Rare`, `_Epic`, `_Legendary`, `_Secret` | 400 x 480 each | An item tile (shoes, guns): rounded card, grey / blue / purple / gold / rainbow gradient by rarity, a lighter top. |
| B5 | `Card_Red.png`, `Card_Yellow.png`, `Card_Blue.png`, `Card_Green.png`, `Card_Purple.png` | 900 x 420 each | The product cards: solid bold colour, faint square pattern, thick outline, room for a picture on the left. |
| B6 | `Card_Pack.png` | 600 x 620 | A tall cash-pack tile (green, faint pattern), room for the picture and the big amount. |
| B6b | `Btn_Pill_Yellow.png` | 500 x 130 | The yellow pill button on the cards (Buy / OWNED written by the game). |
| B7 | `Btn_Buy_Green.png` | 480 x 150 | The green price button (Robux sign + price written by the game). |
| B8 | `Btn_Buy_Yellow.png` | 480 x 150 | Yellow price button (x3). |
| B9 | `Btn_Buy_Rainbow.png` | 480 x 150 | Rainbow price button (x10, the best deal). |
| B10 | `Btn_Claim.png` | 480 x 150 | Bright green "Claim!" button (the game writes the word). |
| B11 | `Btn_Big_Purple.png` | 900 x 230 | The big Rebirth button in its window. |
| B12 | `Tab_On.png` / `Tab_Off.png` | 400 x 140 | Window tabs: on = bright yellow, off = grey-blue. |
| B13 | `Box_Search.png` | 900 x 140 | A white rounded search box with a dark outline. |
| B14 | `Tag_New.png` | 260 x 110 | A tilted "NEW!" sticker: yellow-green with the word drawn. |
| B15 | `Tag_Best.png` | 260 x 110 | A tilted "BEST!" sticker: hot pink with the word drawn. |

## C. Pop-ups and the top of the screen
| # | File name | Size | What it looks like |
|---|---|---|---|
| C1 | `Banner_Goal.png` | 1400 x 200 | The "NEXT GOAL" plate behind the goal line: a dark see-through rounded bar with a gold top edge. |
| C2 | `Banner_RankUp.png` | 1600 x 500 | The "RANK UP!" burst: gold rays behind a ribbon (the game writes the rank). |
| C3 | `Toast.png` | 1200 x 160 | A rounded dark see-through bar for short messages ("+5K Power"). |

## Don't make (not allowed in a kids' game)
- "2900/3000 LEFT", "Limited Time!", deal countdowns ("26d 0h 33m"), or crossed-out "was" prices (the "2500" on the
  MEGA PACK): these pressure kids with fake scarcity, and Roblox's rules and ours don't allow them. A plain "BEST DEAL"
  sticker is fine.
- Hidden odds: anything random that costs Robux always shows its odds (the reference's 83% / 12% ... is good).

## Sending them
Name the files as above and send them here, one sheet with names under each is fine too (like your icon sheet; I'll cut
it). Upload goes the same way as the icons.
