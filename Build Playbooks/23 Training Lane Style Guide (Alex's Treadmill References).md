---
tags: [build-playbooks, style, training-lanes, gamepass, voxel, neon, idle-motion, reference]
updated: 2026-10-31
---

# 23 Training Lane Style Guide (Alex's Treadmill References)

Back to [[00 Build Router]] · Lane layout: [[Lesson - Tiered Training Lanes]] · Taste: [[09 Owner Taste Rules]] · Effects: [[11 VFX Moments Playbook]] · Selling: [[21 Money and Retention at Studio Level]]

**What Alex said (Oct 31):** "I really like these designs... this is the style I am aiming at, add some nice effects, I want them to look like they have life, but also not too crazy at the same time, and especially the gamepass ones will look better than the plain ones."

**The sheets:** `Build Playbooks/references/treadmill-lanes/treadmill_reference_sheet_1.png` to `_3.png` (32 frames from one TikTok clip, about 1 s apart).
- **Style reference only.** They are another creator's builds (TikTok @chunkydevpug). We copy the *look* (palette, shapes, how alive they feel), never the models. Every lane is built by us from parts or our own meshes.

## 1. The shared look (every lane, free or paid)
- **Chunky voxel build:** blocky parts with bevelled corners, a dark base (near-black blue-grey, about (30, 34, 45)), and **neon strips** on every edge. The glow comes from Neon parts and thin light strips, not from big lights.
- **One main colour per lane, plus white.** The belt, the rails, the corner lights and the console screen all share it. The dark body makes the colour pop.
- **A console at the front with a glowing screen** (an icon or symbol in the lane's colour).
- **Glowing corner blocks** at the four corners of the base.
- **The ground stays plain dark.** The lane is the only colourful thing in its spot.
- **Belt motion:** the belt texture scrolls toward the back (Texture `OffsetStudsV`, about 2 studs per second idle, faster while someone runs).

## 2. "Alive, but not too crazy" (idle motion budget per lane)
| Layer | Free lane | Gamepass lane |
|---|---|---|
| Belt scroll | yes | yes |
| Neon breathing (brightness 0.8 ↔ 1.0) | 1 cycle every **3 s** | 1 cycle every **2.5 s** |
| Floating bits (particles) | none, or 2–4 slow sparkles | 8–20 themed bits, Rate 3–6, Lifetime 1.5–3 s, rising slowly |
| Moving prop (ring, halo, orb, moon) | none | **one**, turning 1 turn every 6–10 s or bobbing 0.3 studs over 2 s |
| Light | none | one PointLight, Brightness 1–2, Range 8–12 |
| Flashes | **never** | **never**. Nothing blinks faster than once a second. |

**Rule of thumb:** a lane has at most **3 moving things** (belt, one prop, one particle layer). More than that reads as "crazy". Keep every emitter under 20 live particles; a row of 8 lanes must stay under about 150 particles total (phone budget, note 18 §5).

## 3. Free versus gamepass (paid must always look better)
- **Free lanes:** the plain neon look (sheet 1, frames 1–4). Cool blue neon on the dark body, belt scroll and soft breathing. Clean and good, but simple.
- **Gamepass lanes add four things free lanes never get:**
  1. a **themed silhouette** on the console (horns, wings, spires, a halo or a moon disc);
  2. a **themed ground "spill"** around the base (rubble, clouds, crystals or embers), made of blocks 1–3 studs tall in the lane's colour;
  3. **one moving prop**;
  4. **themed particles**.
- **The gamepass label is plain**, for example "GAMEPASS" or the theme's name. Never "VIP" (house rule). An owned lane says "Owned ✓". A lane for a pass that isn't built yet shows its price and "Coming soon", and never prompts.
- **Brighter is not better.** Paid lanes win by **shape and life**, not by more glow. Match the free lane's neon strength, so the row looks like one family.

## 4. The eight themes (pick from these for paid lanes)
| Theme | Colours | Silhouette | Ground spill | Moving prop | Particles | Kid-safe note |
|---|---|---|---|---|---|---|
| **Plain neon** (free) | ice blue (90, 200, 255) + white | simple console | none | none | none | — |
| **Fire** | red (255, 50, 30) + orange (255, 150, 40) | two horns on the console | glowing embers | belt with **chevron arrows** scrolling | rising ember sparks | Warm, not scary |
| **Angelic** | white + gold (230, 190, 90) + sky-blue gem | a gold arch with a glowing **blue diamond** | puffy white **clouds** at the corners | 2 small **halos** orbiting | soft white motes | — |
| **Void** | purple (150, 70, 255) + pink-white | a dark ring portal with a **spiral** | dark rubble with purple **star speckles** | a purple ring turning | small purple flames, galaxy dots | A spiral, not a face |
| **Ice** | cyan (120, 230, 255) + white | **crystal shards** on the console. Sheet 2 has a horned skull: **we use an ice crown instead**. | ice crystals and speckles | none, or a slowly spinning crystal | snow motes | No skulls for our kids' game |
| **Storm** | electric blue (60, 140, 255) + gold trim | gold **spires** with a glowing orb | dark rocks with blue sparks | the orb bobs | small bolts on the belt (no screen flash) | Lightning is drawn on the belt only, at most once a second |
| **Arcane** | magenta (230, 80, 255) | twin **fans** like wings, an X rune on the screen | dark rubble with magenta sparkles | the fans sway 5° slowly | rune sparkles | — |
| **Red moon** | red (230, 40, 50) | a big red **moon disc** on the console. Sheet 2 shows a skull face in it: **we use a plain moon with craters.** | dark rubble with red sparks | the moon turns slowly | red motes | We say "Red Moon", never "Blood"; no skulls |
| **Emerald** | green (40, 230, 150) | castle **spires**, an X rune on the screen | dark rubble with green sparkles | the spires' gems twinkle (slower than once a second) | green motes | — |

## 5. How to build one (for the training-lanes thread)
1. Keep the existing lane layout and positions from [[Lesson - Tiered Training Lanes]]. This guide changes the **look** only.
2. Base: a dark body (SmoothPlastic, (30, 34, 45)), corner blocks with a Neon inset, Neon edge strips about 0.2 studs thick in the theme colour.
3. Belt: a dark plastic surface plus a scrolling Texture (our own stripe or chevron PNG; Alex uploads it). On the Fire lane the chevrons point backwards.
4. Console: a dark frame with a SurfaceGui screen showing the theme icon (draw it from simple shapes or our own image; never invent an ID).
5. Paid extras from §3, one at a time, with the motion numbers from §2.
6. Put the motion in **one client script** that loops over all lanes, so 8 lanes don't mean 8 loops. Skip lanes more than 150 studs from the camera.
7. Check against the sheets side by side (same angle: three-quarter view from the front left), at the same size. Look at the silhouette and colour first, and life second.

## 6. Checklist before showing Alex
- [ ] The free lane looks clean and good alone (sheet 1, frames 1–4).
- [ ] Every paid lane beats the free one by shape and motion, without being brighter.
- [ ] At most 3 moving things per lane; nothing blinks faster than once a second.
- [ ] No skulls, no "blood", no "VIP".
- [ ] Under about 150 live particles for the whole row.
- [ ] One side-by-side picture next to the sheet, at the same angle.
