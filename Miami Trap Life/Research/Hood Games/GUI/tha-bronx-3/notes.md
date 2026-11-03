# Tha Bronx 3 — GUI notes

**Roblox store data (games.roblox.com, fetched 2026-11-03):** name "(🎃UPDATE🎃) THA BRONX 3" · universe 10737656087 · place 128899661081075 · creator **223Z STUDIOS** (group) · **2,911 playing at fetch time, the most of any game in this pack (Da Hood had 1,895)** · 15,393,140 visits · 25,705 favourites · 18,987 up / 1,648 down (92% like) · created 2026-08-18 (the current place; earlier TB3 places existed, as the videos below from 2025 show) · updated 2026-11-02. Store tags: "Switches, Hood Game, Shooting, Open World, Money, Grind, RolePlay, Buttons".

**Videos used:** `WMEPaall0o8` (Kalo 2X, rags to riches, 2026-05-04), `ktNboOkiAQQ` (Kalo 2X, best ways to make money, 2025-10-04), `vPU4Qjc0m0w` (semi, summer update review, 2026-06-23). The realistic lighting and textures stand out (near-photoreal NYC streets), while avatars are classic blocky.

## The overall look
- **Vitals stack, left-middle (the signature element):** a vertical column at the left ~5–20% from the edge. From top to bottom:
  1. Two money figures side by side, each under a small icon. **Cash** is white "$668,835" under a white bank/pillars icon, and **Bank / dirty money** is **red** "$5,836" under a red bank icon. White bold condensed text, ~11 px.
  2. Four fat **rounded pill bars** (~7% wide × 1.6% tall) with a 1-px darker outline and a translucent grey track. **White = stamina** (running-man icon), **yellow = hunger** (drumstick icon), **red = health** (red heart-with-pulse icon), **dark blue/indigo = sleep/energy** (crescent-moon "zzz" icon). The icons sit to the right of each bar.
  3. A **white R6 body silhouette** (~3% wide × 8% tall) below. Injured limbs turn **red** (`hud-injured-hospital`), and a red text line "OR GO TO HOSPITAL" appears next to it. A red "You are tired" label appears above it when sleep is low.
- **"INVENTORY / TAKE OFF" buttons** above the stack: two small black rectangles with white 7 px caps.
- **Hotbar, bottom-centre:** tiny square slots (~2.3% wide), translucent dark, with white 6–7 px captions ("Phone", "Fist", "Carkeys", "Lemonade", "223Rifle", "5.56"). The selected slot has a **blue 2 px outline**.
- **Centre-bottom status line:** "Immunity will expire in 893 seconds" in thin white 10 px (new-spawn protection).
- **Red warnings:** "You are being seen on camera!" in red bold small text at the bottom-centre. "Rent Timer: 5m 24s" in red on the right-middle (apartment rent).
- **Fonts:** a mix. Menus use a **serif font (Times/Garamond-like)** ("City Shop", "You were killed by…"), and the HUD uses bold sans.
- **Top-right:** a team list identical in idea to South Bronx: coloured full-width rows "Police" (navy), "Prisoner" (orange), "EMS" (red), "Neutral" (grey), then player names. A "RADIO" icon (white boom-box) sits at the top-right in vehicles.

## Frames
- `hud-tired-stats_vPU4Qjc0m0w_f14.jpg` — The full vitals stack, with the sleep bar nearly empty and the red "You are tired" note. A "Rent Timer" sits right. Immunity text at the bottom.
- `hud-injured-hospital_WMEPaall0o8_f12.jpg` — **Injury state:** the body silhouette's leg is red, with "OR GO TO HOSPITAL" in yellow-red small caps. The screen has a white/red blood vignette. The health bar is low (short red fill).
- `hud-car-fuel_WMEPaall0o8_f04.jpg` — **Vehicle HUD, bottom-centre:** small white text "1500CHEV" (car name) over "68 mph", a white fuel-can icon to the left, and a thin **orange fuel bar** (~12% wide) under it. Very minimal, with no gauge.
- `hud-car-dealership_vPU4Qjc0m0w_f03.jpg` — The same car HUD ("WIDEBODY TRX 13 mph") plus the red "You are being seen on camera" warning. A blue "Dealership" building sign.
- `dealership-list_ktNboOkiAQQ_f02.jpg` — **Dealership UI:** a narrow dark vertical list (~6% wide) of car names in white 7 px ("2003 TrailBZ", "Impala Bigwheel", "2017SuburbanChev", "Bronco", "1999Toyota" selected in **red fill**, "DirtBike", "GT500"…). Beside it is a detail block: "1999TOYOTA" in white bold italic, "$55,000", then two buttons "Spawn" (dark) and "REFUND" (red).
- `shop-city-illegal_vPU4Qjc0m0w_f06.jpg` — **Illegal "City Shop":** a dark translucent box with a **serif** title "City Shop" and a small red square "X". Rows: name / stock count / price ("Card 8 $4000", "Fully-ARPR 2 $40000", "Fully-AK47 6 $40000", "Incognito G40", "Glox-FRT", "Kiger9CButton", "StrikePad" highlighted grey, "Swiss Screw"). The footer shows the selected name "None", "Price: $3000" and a **green "Buy" button**. After buying, a **green "Success! -$3000"** pops at the bottom-centre. A red warning triangle with the word "Illegal !" is painted on the wall in red.
- `shop-ammo-table_ktNboOkiAQQ_f05.jpg` — **Ammo shop:** magazines on a table with world labels (".Drum", "5.56", "9mm", "Extended"…) in white italic. A circular **E prompt with a ring** is on the hovered item. A red "-$20!" shows after buying.
- `hud-gun-refill_ktNboOkiAQQ_f06.jpg` — First-person rifle (spraying from a can = refill station). "Refilled 1 gun." white centre text. **Ammo, bottom-right:** "10 /30" over the hints "RightHold - Aim" and "Q - Shiftlock" in tiny white.
- `menu-animations_vPU4Qjc0m0w_f15.jpg` — **Animations menu, right side:** a dark navy panel (~RGB 20,25,45) with a **royal-blue header bar** "Animations" (~RGB 30,60,160). Categories as plain white 8 px rows: Communicate, Sitting, Money Flexes, Dances, Signs, Watch Flexes, Props, Voice Chat.
- `menu-player-actions_WMEPaall0o8_f06.jpg` — **Click-on-player menu:** a dark card with the player avatar, name and @handle. Rows with line icons: "Friend request", "Examine Avatar", "Block", "Report Abuse". Next to it is the team/player list. Clean Roblox-like style.
- `job-cartheft-attempts_WMEPaall0o8_f10.jpg` — **Car lock-picking (a crime job):** an "[E] Sit" style prompt on the car door and a **green "Attempts: 1"** counter at the bottom-centre. "DPadDown/G - Drop Tool" hint at the bottom-right. Red "Rent Timer".
- `inventory-search_WMEPaall0o8_f13.jpg` — **Inventory:** Roblox-backpack-like translucent grey grid with a "Search" field. A 10-slot numbered hotbar under it. Red room lighting.
- `hud-immunity-rent_WMEPaall0o8_f09.jpg` — An apartment interior. The bank money is red ("$14,000"), there is an immunity line at the centre, and a red "Rent Timer: 9m 4s".
- `warning-camera_WMEPaall0o8_f03.jpg` — Driving at night: the car-name HUD, an orange fuel line, and a red "You are being seen on camera!" under it. Very bright realistic lighting.
- `death-killedby_ktNboOkiAQQ_f16.jpg` — **Death:** a dark-red tinted screen with blood-texture edges. Centred **serif** text: "You were killed by 722s5" (red) and "Respawning in 9" (white). The HUD dims to ~30%.
- `death-jail-release_WMEPaall0o8_f01.jpg` — **Jail/arrest:** a red-tinted screen (prison yard) with a large white **italic serif** "Releasing in 104" at the bottom-centre, the killed-by text and the respawn timer. The hotbar has "PrisonMop" and "Basketball" (prison items).

**Takeaways:** a "survival sim" HUD with four needs bars (stamina, hunger, health, sleep), a body-damage silhouette, cash vs. red bank money, and rent and camera warnings. It is very informative but visually plain. The odd mix of serif and sans fonts looks dated, but players clearly don't mind (92% like, top concurrent players). The shops are simple list windows. Gun names imitate real "switch" culture (Glock "buttons", "Fully-AR").
