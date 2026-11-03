# Benchmarks: Urban Reload, OPPS, BlockSpin

**Full write-up: [analysis.md](analysis.md)**

Research pack collected 2026-11-02. One folder per game. Per video: `<id>_thumb.jpg`, `<id>_frame01..10.jpg` (1280 px wide, spread from 6% to 94% of the video), and `<id>.txt` (auto-transcript, when YouTube allowed it). `anim/` holds 3-second, 8 fps bursts for studying animation.

## How the animations are done (what the frames show)

The 10 frames per video show stills. For motion, `anim/` in each game folder holds a 3-second burst at 8 fps (24 frames + a `_sheet.jpg` contact sheet).

**Urban Reload is the one to copy for gun animations.** (`urban-reload/anim/KnBi15zsgz4_run-aim_*`)
- **Split body:** the legs play a run or strafe cycle in the direction of movement. The upper body twists separately so the rifle points where the camera aims. In the burst, she runs sideways and even backwards along the fence with the rifle on target. That is procedural: the Waist and Neck Motor6Ds are rotated toward the mouse/camera every frame on top of the run animation. It is not a separate "run while aiming" clip.
- **Low tactical stance:** a deep, knees-bent crouch-run with a wide stride and the torso pitched forward. This is a custom animation, not Roblox's default run.
- **Two weapon poses:** a two-handed shoulder hold while firing, then a **high-ready / port-arms pose (rifle vertical, muzzle up)** when sprinting or not shooting. Switching between them reads as "realistic".
- **Over-the-shoulder camera:** the camera sits behind the right shoulder (offset camera, shift-lock style). It is close while fighting, with the crosshair at screen centre.
- Weapon skins (leopard, flame) on realistic gun meshes with attachments. A red muzzle flash and a tracer line point at the target.
- Body: R15 with layered clothing and realistic body packages (not blocky). This makes the animations look smoother.
- Movement tech is a big deal in this game. Videos titled "movement player", "move like a demon" and "3KD movement" show players sliding, strafing and crouch-peeking. Settings video: `9mJ-bs7r2IM`.

**BlockSpin: functional, blocky, with stamina-gated movement.** (`blockspin/anim/OlhizsSLv1g_aim-fire_*`)
- Blocky R15 avatars. The gun is held out in front in a simple two-handed hold. When aiming, the camera pulls in over the shoulder.
- **Contextual keybind panel** (bottom left), which changes with state. On foot: `LShift Sprint · RMB Aim · Q Alt Aim (swap shoulder) · R Reload · C Crouch`. In a car: `Space Handbrake · E Exit Vehicle`. Melee: `LMB Hit`.
- **Stamina** limits sprinting ("+70 Stamina" pickups; the Red Bull drink restores 40).
- "In Combat" skull icon, damage numbers and hit markers. When someone dies, loot spills out as floating stacked item icons with ×counts.
- Cars do handbrake drifts with tyre smoke. The starter vehicle is a mobility scooter, which is a funny progression hook.
- The store description talks up "unforgettable finishers" (execution animations), but none are visible in these frames.

**OPPS: default-ish animation, carried by lighting.** (`opps/anim/QKjJHRGLGNM_run_*`)
- The run cycle looks like the stock Roblox R15 run, and guns sit in a basic tool-hold pose. There is nothing custom you can see.
- What sells it is **Future lighting with hard shadows, fog/haze, palm-tree LA streets, and day/night**. Classic blocky avatars.

## HUD and UI at a glance

| | Urban Reload | BlockSpin | OPPS |
|---|---|---|---|
| Money | top right, green box ($) | top right, big cash-stack icon + $ | top right, small green pill |
| Health | red bar + number under money; blue stamina bar | green bar under money | small icons under money |
| Hotbar | bottom centre, 5 square slots: fist, gun (ammo 30/30 under it), drink, armor, car | bottom centre, small square slots with ammo count | bottom centre, small **circular** slots with coloured durability rings |
| Menus | compact icon column on the right (Shop, Effects, Crew, Clan, Emotes, Event) | 2×4 icon grid on the right (Items, Skills, Quests, Store, Crews, Emotes, Codes) | 2×4 icon grid on the left (Items, Quests, Skills, Crews, Store, Emotes, Settings, Codes) |
| Other | compass strip top centre, kill feed top left, "Farm Zone"/"Safe Zone" banners, kill-streak popups ("DOUBLE KILL", +$), ammo count bottom right | contextual keybind hints, In-Combat skull, safe-zone toasts, performance stats on screen | car speedometer bottom left (MPH), waypoint icons floating over the city, crate-opening reveal screen |
| Lighting | grey overcast NYC (elevated train, diner, motel); purple Halloween sky | bright Florida suburb, mid-contrast | Future lighting, strong shadows, haze |
| Cars | hatchback starter → Lambo; garage with neon/lights/paint, plus loot-crate odds | scooter → ATV → muscle cars, with drift smoke | dealership ("Rick Motors"), Lambos, Charger, SUVs |

## [🎃] Urban Reload (urban-reload/)

https://www.roblox.com/games/84448037861644/Urban-Reload · Squad Labs (Group 726956795) · 11,710 playing · 8,297,218 visits · 85.4% likes · 7 game passes. Details: `urban-reload/store.md`, `urban-reload/store.json`.

> The place id in the brief (10769552054) is actually Urban Reload's UNIVERSE id; as a place id it points to an unrelated empty starter place. Real root place: 84448037861644.

| Video | Channel | Views | Length | Uploaded | Files |
|---|---|---|---|---|---|
| [BEGINNER GUIDE (FAST MONEY, XP, BEST WEAPONS & PVP) in Urban Reload Roblox](https://www.youtube.com/watch?v=EVh64L6Xxi4) `EVh64L6Xxi4` | Radex Tips | 3,664 | 2:42 | 2026-11-01 | 10 frames, thumb, transcript |
| [I PACKED THE LAMBO IN URBAN RELOAD! (PVP)](https://www.youtube.com/watch?v=-7znNlx-GQQ) `-7znNlx-GQQ` | SKI | 2,736 | 10:42 | 2026-11-02 | 10 frames, thumb, transcript |
| [I FOUND ALL THE SECRET GHOST LOCATIONS! 👻🎃 (Urban Reload Halloween Update)](https://www.youtube.com/watch?v=ueoyuJdCGGk) `ueoyuJdCGGk` | urryuk | 9,189 | 1:10 | 2026-10-27 | 10 frames, thumb, transcript |
| [Urban Reload Guide! (Tips & Tricks, Get Money FAST) ROBLOX](https://www.youtube.com/watch?v=fl-Q6vVplXg) `fl-Q6vVplXg` | ItzVexo | 9,148 | 5:53 | 2026-10-30 | 10 frames, thumb, **no transcript** |
| [Dominating ENTIRE SERVERS in Urban Reload with A 3KD!](https://www.youtube.com/watch?v=KnBi15zsgz4) `KnBi15zsgz4` | eternal | 9,424 | 12:48 | 2026-10-27 | 10 frames, thumb, **no transcript** |
| [👹 THESE SETTINGS MAKE YOU MOVE LIKE A DEMON IN URBAN RELOAD! 😭🔥 (BEST MOVEMENT + PERFORMANCE)](https://www.youtube.com/watch?v=9mJ-bs7r2IM) `9mJ-bs7r2IM` | Miami RBX | 2,461 | 13:19 | 2026-11-02 | 10 frames, thumb, **no transcript** |

Animation bursts: `urban-reload/anim/KnBi15zsgz4_run-aim_sheet.jpg`

## OPPS 🔪 (opps/)

https://www.roblox.com/games/114939661069378/OPPS · #1 Hood (Group 503085633) · 279 playing · 3,740,665 visits · 79.4% likes · 2 game passes. Details: `opps/store.md`, `opps/store.json`.

| Video | Channel | Views | Length | Uploaded | Files |
|---|---|---|---|---|---|
| [ROBLOX OPPS..](https://www.youtube.com/watch?v=xY6uTxMZChI) `xY6uTxMZChI` | ProjectSupreme | 14,892 | 27:02 | 2026-08-19 | 10 frames, thumb, transcript |
| [ROBLOX OPPS..](https://www.youtube.com/watch?v=0W6SYkfwqKE) `0W6SYkfwqKE` | Racks 2 | 1,442 | 15:59 | 2026-08-19 | 10 frames, thumb, transcript |
| [I JOINED A GANG IN ROBLOX OPPS](https://www.youtube.com/watch?v=QKjJHRGLGNM) `QKjJHRGLGNM` | Racks 2 | 3,268 | 16:51 | 2026-08-22 | 10 frames, thumb, **no transcript** |
| [I BECAME A COP IN ROBLOX OPPS](https://www.youtube.com/watch?v=JHAoW3cKCqs) `JHAoW3cKCqs` | Racks 2 | 1,938 | 9:56 | 2026-08-23 | 10 frames, thumb, **no transcript** |
| [They BULLIED Me, So The OWNER Helped Me Get Revenge... (Roblox Opps)](https://www.youtube.com/watch?v=6rj-JeeVZUs) `6rj-JeeVZUs` | Racks 2 | 1,317 | 35:12 | 2026-08-21 | 10 frames, thumb, **no transcript** |

Animation bursts: `opps/anim/QKjJHRGLGNM_run_sheet.jpg`

## BlockSpin 🔪 [HALLOWEEN UPDATE!] (blockspin/)

https://www.roblox.com/games/104715542330896/BlockSpin · Cinnamon Go! (Group 33720745, verified) · 24,772 playing · 1,325,582,708 visits · 78.8% likes · 0 game passes. Details: `blockspin/store.md`, `blockspin/store.json`.

| Video | Channel | Views | Length | Uploaded | Files |
|---|---|---|---|---|---|
| [The ULTIMATE Beginner's Guide To Roblox BlockSpin](https://www.youtube.com/watch?v=j1XWaZs3Bfk) `j1XWaZs3Bfk` | 2kane | 37,399 | 9:04 | 2025-03-05 | 10 frames, thumb, transcript |
| [The Ultimate Blockspin Farming Guide](https://www.youtube.com/watch?v=3AGJU4b5g9o) `3AGJU4b5g9o` | Dakota | 236,688 | 8:16 | 2025-07-21 | 10 frames, thumb, transcript |
| [WIPING LEGENDARY LOBBIES In Roblox BlockSpin](https://www.youtube.com/watch?v=OlhizsSLv1g) `OlhizsSLv1g` | 2kane | 29,872 | 14:39 | 2026-05-27 | 10 frames, thumb, transcript |
| [Can I Go From Noob to Pro in 60 Minutes? / Roblox Blockspin](https://www.youtube.com/watch?v=gBKaBC4rgF4) `gBKaBC4rgF4` | ChrisOffScript | 444,404 | 30:19 | 2025-04-27 | 10 frames, thumb, **no transcript** |
| [STEALING LEGENDARY'S USING THE NEW AWP AND AUG IN BLOCKSPIN!](https://www.youtube.com/watch?v=IcXpnBlWjkU) `IcXpnBlWjkU` | K8yden | 34,776 | 12:06 | 2026-10-27 | 10 frames, thumb, **no transcript** |
| [🎃TODO sobre la NUEVA ACTUALIZACIÓN de HALLOWEEN 😱👻 / Block Spin](https://www.youtube.com/watch?v=vBqCeXzw8oU) `vBqCeXzw8oU` | Sonvenn | 17,026 | 12:44 | 2026-10-17 | 10 frames, thumb, **no transcript** |

Animation bursts: `blockspin/anim/OlhizsSLv1g_aim-fire_sheet.jpg`

## Not collected

- **Store screenshots and icons**: thumbnails.roblox.com and games.roblox.com can't be reached from this machine's sandbox. Game details and votes were read through the in-app browser instead, but the screenshot download was blocked.
- **Missing transcripts**: YouTube answered subtitle requests with HTTP 429 (rate limit) after the first few videos. These are listed as "no transcript" above.
- **BlockSpin game passes**: the API returns none. It sells through developer products, which have no public list.
- OPPS's two passes are both off sale (no price).

## File tree

```
urban-reload/
  -7znNlx-GQQ.txt
  -7znNlx-GQQ_frame01.jpg
  -7znNlx-GQQ_frame02.jpg
  -7znNlx-GQQ_frame03.jpg
  -7znNlx-GQQ_frame04.jpg
  -7znNlx-GQQ_frame05.jpg
  -7znNlx-GQQ_frame06.jpg
  -7znNlx-GQQ_frame07.jpg
  -7znNlx-GQQ_frame08.jpg
  -7znNlx-GQQ_frame09.jpg
  -7znNlx-GQQ_frame10.jpg
  -7znNlx-GQQ_thumb.jpg
  9mJ-bs7r2IM_frame01.jpg
  9mJ-bs7r2IM_frame02.jpg
  9mJ-bs7r2IM_frame03.jpg
  9mJ-bs7r2IM_frame04.jpg
  9mJ-bs7r2IM_frame05.jpg
  9mJ-bs7r2IM_frame06.jpg
  9mJ-bs7r2IM_frame07.jpg
  9mJ-bs7r2IM_frame08.jpg
  9mJ-bs7r2IM_frame09.jpg
  9mJ-bs7r2IM_frame10.jpg
  9mJ-bs7r2IM_thumb.jpg
  EVh64L6Xxi4.txt
  EVh64L6Xxi4_frame01.jpg
  EVh64L6Xxi4_frame02.jpg
  EVh64L6Xxi4_frame03.jpg
  EVh64L6Xxi4_frame04.jpg
  EVh64L6Xxi4_frame05.jpg
  EVh64L6Xxi4_frame06.jpg
  EVh64L6Xxi4_frame07.jpg
  EVh64L6Xxi4_frame08.jpg
  EVh64L6Xxi4_frame09.jpg
  EVh64L6Xxi4_frame10.jpg
  EVh64L6Xxi4_thumb.jpg
  KnBi15zsgz4_frame01.jpg
  KnBi15zsgz4_frame02.jpg
  KnBi15zsgz4_frame03.jpg
  KnBi15zsgz4_frame04.jpg
  KnBi15zsgz4_frame05.jpg
  KnBi15zsgz4_frame06.jpg
  KnBi15zsgz4_frame07.jpg
  KnBi15zsgz4_frame08.jpg
  KnBi15zsgz4_frame09.jpg
  KnBi15zsgz4_frame10.jpg
  KnBi15zsgz4_thumb.jpg
  failures.txt
  fl-Q6vVplXg_frame01.jpg
  fl-Q6vVplXg_frame02.jpg
  fl-Q6vVplXg_frame03.jpg
  fl-Q6vVplXg_frame04.jpg
  fl-Q6vVplXg_frame05.jpg
  fl-Q6vVplXg_frame06.jpg
  fl-Q6vVplXg_frame07.jpg
  fl-Q6vVplXg_frame08.jpg
  fl-Q6vVplXg_frame09.jpg
  fl-Q6vVplXg_frame10.jpg
  fl-Q6vVplXg_thumb.jpg
  store.json
  store.md
  ueoyuJdCGGk.txt
  ueoyuJdCGGk_frame01.jpg
  ueoyuJdCGGk_frame02.jpg
  ueoyuJdCGGk_frame03.jpg
  ueoyuJdCGGk_frame04.jpg
  ueoyuJdCGGk_frame05.jpg
  ueoyuJdCGGk_frame06.jpg
  ueoyuJdCGGk_frame07.jpg
  ueoyuJdCGGk_frame08.jpg
  ueoyuJdCGGk_frame09.jpg
  ueoyuJdCGGk_frame10.jpg
  ueoyuJdCGGk_thumb.jpg
  anim/
    KnBi15zsgz4_pose_closeup.jpg
    KnBi15zsgz4_run-aim_01.jpg
    KnBi15zsgz4_run-aim_02.jpg
    KnBi15zsgz4_run-aim_03.jpg
    KnBi15zsgz4_run-aim_04.jpg
    KnBi15zsgz4_run-aim_05.jpg
    KnBi15zsgz4_run-aim_06.jpg
    KnBi15zsgz4_run-aim_07.jpg
    KnBi15zsgz4_run-aim_08.jpg
    KnBi15zsgz4_run-aim_09.jpg
    KnBi15zsgz4_run-aim_10.jpg
    KnBi15zsgz4_run-aim_11.jpg
    KnBi15zsgz4_run-aim_12.jpg
    KnBi15zsgz4_run-aim_13.jpg
    KnBi15zsgz4_run-aim_14.jpg
    KnBi15zsgz4_run-aim_15.jpg
    KnBi15zsgz4_run-aim_16.jpg
    KnBi15zsgz4_run-aim_17.jpg
    KnBi15zsgz4_run-aim_18.jpg
    KnBi15zsgz4_run-aim_19.jpg
    KnBi15zsgz4_run-aim_20.jpg
    KnBi15zsgz4_run-aim_21.jpg
    KnBi15zsgz4_run-aim_22.jpg
    KnBi15zsgz4_run-aim_23.jpg
    KnBi15zsgz4_run-aim_24.jpg
    KnBi15zsgz4_run-aim_sheet.jpg
opps/
  0W6SYkfwqKE.txt
  0W6SYkfwqKE_frame01.jpg
  0W6SYkfwqKE_frame02.jpg
  0W6SYkfwqKE_frame03.jpg
  0W6SYkfwqKE_frame04.jpg
  0W6SYkfwqKE_frame05.jpg
  0W6SYkfwqKE_frame06.jpg
  0W6SYkfwqKE_frame07.jpg
  0W6SYkfwqKE_frame08.jpg
  0W6SYkfwqKE_frame09.jpg
  0W6SYkfwqKE_frame10.jpg
  0W6SYkfwqKE_thumb.jpg
  6rj-JeeVZUs_frame01.jpg
  6rj-JeeVZUs_frame02.jpg
  6rj-JeeVZUs_frame03.jpg
  6rj-JeeVZUs_frame04.jpg
  6rj-JeeVZUs_frame05.jpg
  6rj-JeeVZUs_frame06.jpg
  6rj-JeeVZUs_frame07.jpg
  6rj-JeeVZUs_frame08.jpg
  6rj-JeeVZUs_frame09.jpg
  6rj-JeeVZUs_frame10.jpg
  6rj-JeeVZUs_thumb.jpg
  JHAoW3cKCqs_frame01.jpg
  JHAoW3cKCqs_frame02.jpg
  JHAoW3cKCqs_frame03.jpg
  JHAoW3cKCqs_frame04.jpg
  JHAoW3cKCqs_frame05.jpg
  JHAoW3cKCqs_frame06.jpg
  JHAoW3cKCqs_frame07.jpg
  JHAoW3cKCqs_frame08.jpg
  JHAoW3cKCqs_frame09.jpg
  JHAoW3cKCqs_frame10.jpg
  JHAoW3cKCqs_thumb.jpg
  QKjJHRGLGNM_frame01.jpg
  QKjJHRGLGNM_frame02.jpg
  QKjJHRGLGNM_frame03.jpg
  QKjJHRGLGNM_frame04.jpg
  QKjJHRGLGNM_frame05.jpg
  QKjJHRGLGNM_frame06.jpg
  QKjJHRGLGNM_frame07.jpg
  QKjJHRGLGNM_frame08.jpg
  QKjJHRGLGNM_frame09.jpg
  QKjJHRGLGNM_frame10.jpg
  QKjJHRGLGNM_thumb.jpg
  failures.txt
  store.json
  store.md
  xY6uTxMZChI.txt
  xY6uTxMZChI_frame01.jpg
  xY6uTxMZChI_frame02.jpg
  xY6uTxMZChI_frame03.jpg
  xY6uTxMZChI_frame04.jpg
  xY6uTxMZChI_frame05.jpg
  xY6uTxMZChI_frame06.jpg
  xY6uTxMZChI_frame07.jpg
  xY6uTxMZChI_frame08.jpg
  xY6uTxMZChI_frame09.jpg
  xY6uTxMZChI_frame10.jpg
  xY6uTxMZChI_thumb.jpg
  anim/
    QKjJHRGLGNM_run_01.jpg
    QKjJHRGLGNM_run_02.jpg
    QKjJHRGLGNM_run_03.jpg
    QKjJHRGLGNM_run_04.jpg
    QKjJHRGLGNM_run_05.jpg
    QKjJHRGLGNM_run_06.jpg
    QKjJHRGLGNM_run_07.jpg
    QKjJHRGLGNM_run_08.jpg
    QKjJHRGLGNM_run_09.jpg
    QKjJHRGLGNM_run_10.jpg
    QKjJHRGLGNM_run_11.jpg
    QKjJHRGLGNM_run_12.jpg
    QKjJHRGLGNM_run_13.jpg
    QKjJHRGLGNM_run_14.jpg
    QKjJHRGLGNM_run_15.jpg
    QKjJHRGLGNM_run_16.jpg
    QKjJHRGLGNM_run_17.jpg
    QKjJHRGLGNM_run_18.jpg
    QKjJHRGLGNM_run_19.jpg
    QKjJHRGLGNM_run_20.jpg
    QKjJHRGLGNM_run_21.jpg
    QKjJHRGLGNM_run_22.jpg
    QKjJHRGLGNM_run_23.jpg
    QKjJHRGLGNM_run_24.jpg
    QKjJHRGLGNM_run_sheet.jpg
blockspin/
  3AGJU4b5g9o.txt
  3AGJU4b5g9o_frame01.jpg
  3AGJU4b5g9o_frame02.jpg
  3AGJU4b5g9o_frame03.jpg
  3AGJU4b5g9o_frame04.jpg
  3AGJU4b5g9o_frame05.jpg
  3AGJU4b5g9o_frame06.jpg
  3AGJU4b5g9o_frame07.jpg
  3AGJU4b5g9o_frame08.jpg
  3AGJU4b5g9o_frame09.jpg
  3AGJU4b5g9o_frame10.jpg
  3AGJU4b5g9o_thumb.jpg
  IcXpnBlWjkU_frame01.jpg
  IcXpnBlWjkU_frame02.jpg
  IcXpnBlWjkU_frame03.jpg
  IcXpnBlWjkU_frame04.jpg
  IcXpnBlWjkU_frame05.jpg
  IcXpnBlWjkU_frame06.jpg
  IcXpnBlWjkU_frame07.jpg
  IcXpnBlWjkU_frame08.jpg
  IcXpnBlWjkU_frame09.jpg
  IcXpnBlWjkU_frame10.jpg
  IcXpnBlWjkU_thumb.jpg
  OlhizsSLv1g.txt
  OlhizsSLv1g_frame01.jpg
  OlhizsSLv1g_frame02.jpg
  OlhizsSLv1g_frame03.jpg
  OlhizsSLv1g_frame04.jpg
  OlhizsSLv1g_frame05.jpg
  OlhizsSLv1g_frame06.jpg
  OlhizsSLv1g_frame07.jpg
  OlhizsSLv1g_frame08.jpg
  OlhizsSLv1g_frame09.jpg
  OlhizsSLv1g_frame10.jpg
  OlhizsSLv1g_thumb.jpg
  failures.txt
  gBKaBC4rgF4_frame01.jpg
  gBKaBC4rgF4_frame02.jpg
  gBKaBC4rgF4_frame03.jpg
  gBKaBC4rgF4_frame04.jpg
  gBKaBC4rgF4_frame05.jpg
  gBKaBC4rgF4_frame06.jpg
  gBKaBC4rgF4_frame07.jpg
  gBKaBC4rgF4_frame08.jpg
  gBKaBC4rgF4_frame09.jpg
  gBKaBC4rgF4_frame10.jpg
  gBKaBC4rgF4_thumb.jpg
  j1XWaZs3Bfk.txt
  j1XWaZs3Bfk_frame01.jpg
  j1XWaZs3Bfk_frame02.jpg
  j1XWaZs3Bfk_frame03.jpg
  j1XWaZs3Bfk_frame04.jpg
  j1XWaZs3Bfk_frame05.jpg
  j1XWaZs3Bfk_frame06.jpg
  j1XWaZs3Bfk_frame07.jpg
  j1XWaZs3Bfk_frame08.jpg
  j1XWaZs3Bfk_frame09.jpg
  j1XWaZs3Bfk_frame10.jpg
  j1XWaZs3Bfk_thumb.jpg
  store.json
  store.md
  vBqCeXzw8oU_frame01.jpg
  vBqCeXzw8oU_frame02.jpg
  vBqCeXzw8oU_frame03.jpg
  vBqCeXzw8oU_frame04.jpg
  vBqCeXzw8oU_frame05.jpg
  vBqCeXzw8oU_frame06.jpg
  vBqCeXzw8oU_frame07.jpg
  vBqCeXzw8oU_frame08.jpg
  vBqCeXzw8oU_frame09.jpg
  vBqCeXzw8oU_frame10.jpg
  vBqCeXzw8oU_thumb.jpg
  anim/
    OlhizsSLv1g_aim-fire_01.jpg
    OlhizsSLv1g_aim-fire_02.jpg
    OlhizsSLv1g_aim-fire_03.jpg
    OlhizsSLv1g_aim-fire_04.jpg
    OlhizsSLv1g_aim-fire_05.jpg
    OlhizsSLv1g_aim-fire_06.jpg
    OlhizsSLv1g_aim-fire_07.jpg
    OlhizsSLv1g_aim-fire_08.jpg
    OlhizsSLv1g_aim-fire_09.jpg
    OlhizsSLv1g_aim-fire_10.jpg
    OlhizsSLv1g_aim-fire_11.jpg
    OlhizsSLv1g_aim-fire_12.jpg
    OlhizsSLv1g_aim-fire_13.jpg
    OlhizsSLv1g_aim-fire_14.jpg
    OlhizsSLv1g_aim-fire_15.jpg
    OlhizsSLv1g_aim-fire_16.jpg
    OlhizsSLv1g_aim-fire_17.jpg
    OlhizsSLv1g_aim-fire_18.jpg
    OlhizsSLv1g_aim-fire_19.jpg
    OlhizsSLv1g_aim-fire_20.jpg
    OlhizsSLv1g_aim-fire_21.jpg
    OlhizsSLv1g_aim-fire_22.jpg
    OlhizsSLv1g_aim-fire_23.jpg
    OlhizsSLv1g_aim-fire_24.jpg
    OlhizsSLv1g_aim-fire_sheet.jpg
```
