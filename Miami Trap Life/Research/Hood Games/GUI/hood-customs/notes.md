# Hood Customs — GUI notes

**Roblox store data (games.roblox.com, fetched 2026-11-03):** name "Hood Customs" · universe 3634139746 · place 9825515356 · creator **Hood Customs Entertainment** (group) · 407 playing at fetch time · 165,772,086 visits · 98,839 favourites · 50,848 up / 20,131 down (72% like) · created 2022-06-05 · updated 2026-10-26 · genre Fighting · 32-player servers. Store pitch: "Fight the best of the best! … cosmetics, including Gun Skins, Knives, Name Tags, Bullet Tracers, Gun Charms". **Not an RP game:** it is a Da Hood-style PvP arena with 1v1 matchmaking in a lobby, plus a map of a block-style hood.

**Videos used:** `EiV18K4TkkM` (rex, solo raiding + 1v1s, 2023-04-22), `Iy5IIhRrWqs` (sai, #1 leaderboard player, 2024-02-23), `MEW8UOKIksA` (SigilJah, first time playing, 2025-03-21). Note: most YouTube results for "Hood Customs" are cheat/script showcases (skipped). The thin perf bar at the very top (Mem/CPU/GPU/Sent/Recv/Ping graphs) is Roblox's own Ctrl+F7 stats, not the game.

## The overall look
- **Almost no HUD**, built for PvP clarity.
- **Health, bottom-centre:** one thin bar (~7% wide × 1.3% tall) with a **neon-green fill** (~RGB 90,240,70) and a **soft green outer glow**. The word "Health" is written inside in white with a dark outline. It turns **orange-red** with the fill shortening as you get hurt.
- **Hotbar:** directly under the health bar, 3–5 small square slots (~2.7% wide) in **flat grey translucent**. Item icons are flat **dark-green tinted silhouettes** of the weapons (knife, revolver, shotgun, rifle), with photo-real food icons (a burger PNG) for heals. The selected slot has a **thick blue (~RGB 80,120,255) outline**. Slot numbers are white, top-left.
- **Ammo, bottom-right:** a row of tiny white bullet glyphs (shells) and a ring/reload circle; in later versions a dark rounded box with "3/6".
- **Top-centre:** three small square icon buttons with a thin white outline on a dark fill: crew/inventory (bag), **shop (cart)**, and a ▾ dropdown. A round "…" chat/menu button sits top-right.
- **Bottom-left (on the map):** "Killstreak: 3x" in white bold on a dark translucent bar, with the number in red.
- **Left edge:** the same Da Hood-style emote list (white rows "Lean, Lay, Dance1, Dance2, Greet, Chest Pump" with a red "CLOSE").

## Frames
- `lobby-waiting-queue_EiV18K4TkkM_f01.jpg` — **1v1 queue pad:** a cyan glowing pad on the lobby floor. A dark rounded card floats beside it with the player's avatar, name and a stat line, and another dark card says "0 - 0 / Waiting For Players…" with a thin white progress line. Lobby: green checkerboard baseplate, pink cherry trees, purple night sky.
- `lobby-match-card_MEW8UOKIksA_f04.jpg` — **Match card** (world BillboardGui): a black rounded slab "3 - 4 · In Match: 01:59" in white bold. Next to it is a player card (round avatar, name, "Wins: 1", "Losses: 7", a heart/like icon). Top-centre is an info toast: a **dark rounded box with a white outline**, a circled "i" icon, and "you are hidden for players inside matches, they cannot hear and see you".
- `hud-round-score_EiV18K4TkkM_f02.jpg` — **Round score:** "5 - 0" in white sans inside a **black rounded box with a white 2 px outline**, at the top-centre. The health bar turns orange "Health" and the 3-slot hotbar has a revolver selected.
- `hud-score-chat_Iy5IIhRrWqs_f02.jpg` — Score "2 - 2" box. Roblox bubble chat ("my ping is throwing"). The green health bar.
- `hud-spawn-shield_EiV18K4TkkM_f06.jpg` — A **spawn-protection bubble**: a translucent teal/green sphere around the player (ForceField restyled). A pink galaxy shotgun skin in first person.
- `hud-hotbar-ammo_EiV18K4TkkM_f16.jpg` — The bottom HUD: the glowing green Health bar above a 5-slot hotbar (green weapon silhouettes + a burger). Ammo shells at the bottom-right. The emote list is open on the left.
- `menu-emotes-side_EiV18K4TkkM_f08.jpg` — The **emote list** at the left edge (white rows, red CLOSE), the same as Da Hood's. The hood map: blocky houses, a "HAMBURGERS" sign, red barrels.
- `world-grab-food-tracers_Iy5IIhRrWqs_f10.jpg` — **Pickups:** floating labels "Grab - [Burger]", "Grab - [Chicken]" over yellow glowing discs. **Yellow bullet tracers** and red blood decals. "Killstreak:" bar at the bottom-left. Name tags are white small text with a thin health line under the name.
- `playerlist_Iy5IIhRrWqs_f14.jpg` — **Player list, top-right:** a narrow dark translucent column with player names in white small sans and small square badge icons for some names. It scrolls. Health nearly empty (red sliver).
- `hud-killstreak_Iy5IIhRrWqs_f16.jpg` — "Killstreak: 3x" (red "3x") bottom-left, an ammo box "1/2" bottom-right, and a hit **crosshair** (white +) on a downed player.
- `hud-ammo-firstperson_Iy5IIhRrWqs_f03.jpg` — First-person shotgun, "4/6" ammo bottom-right, health bar bottom-centre. Night lobby with pink trees.
- `lobby-ping-tags_MEW8UOKIksA_f05.jpg` — **Ping tags:** every player has a small **green rounded tag with their ping** ("65ms", "70ms", "118ms") under them, and a blue "AFK" tag on idle players. Long player list on the right. Many cosmetic auras and flame effects (paid cosmetics).
- `lobby-shop-world_MEW8UOKIksA_f09.jpg` — A **"Shop" building** in the lobby (pink text sign on a brown hut). Cosmetics are bought there or via the top cart button. A world item stand "Heart Balloon R$ 400" sign is visible in the video (frame 03, not kept).
- `loading-connection_MEW8UOKIksA_f16.jpg` — **Loading screen:** pure black with a white **playing-cards icon (a hand of aces)** and "ESTABLISHING CONNECTION…" in white bold caps, "Please Be Patient!" in small grey under it.

**Takeaways:** a combat-first minimal HUD. The good ideas are the glowing health bar with the label inside, 1v1 queue pads with floating match cards, ping tags over players, a killstreak counter, and "hidden while in match" privacy. The aesthetic (checkerboard baseplate plus neon pink trees) is purposely gamey, not realistic.
