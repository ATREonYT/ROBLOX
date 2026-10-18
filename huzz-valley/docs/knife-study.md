# Knife study: Huss Valley vs ours (Oct 18)

Goal: knives "just like in huss valley", animated well, good effects, ready for the owner's own knife models.
Study only; no game code changed. Pictures: `docs/previews/knife-study-back.jpg`, `knife-study-slash.jpg`,
`knife-study-lunge.jpg` (made by a Pillow script over ffmpeg stills).

## Sources
- **Only one Huss Valley recording was in this session:** `f1c7bb86` (Oct 16, 62 s, 3020x1882, 120 fps, no sound).
  The other uploads are VFX TikToks (`751b9a66`, `fc7f6583`), another game (`d5670b97`) and our own Studio tests.
  HV videos `32fe8d21` / `87565d66` (section 1 of CLAUDE.md) were not in the uploads folders, so not rechecked.
- In `f1c7bb86` the recorder (alex) is a **runner**, so catchers are only seen from 15 to 40 studs away. One
  catcher (Danilo, pink knife skin) is clear enough to time: a lunge through two runners at 41.6 s and a slash at
  43.3 s. The knife-in-hand angles below are good to about +-20 degrees, not better.
- Scale: R6 body 5 studs tall, torso 2 studs wide, arm 2 studs long. Times are counted in 30 fps steps (0.033 s).

## What Huss Valley does

### 1. Knife on the back (everyone, runners too)
- **Across the lower back at the belt, not over the shoulder** (5.0 s, lobby line-up seen from behind; 33.0 s and
  35.5 s, alex running). 5 of the 6 knives seen are worn this way:
  - lying almost flat, tilted **12 to 20 degrees**: grip on the **right hip**, blade pointing to the wearer's
    **left** and a little down;
  - the guard sits about at the spine, the blade sticks out **0.7 to 0.9 studs past the left side** of the body;
  - its height: the belt line (bottom of the torso), about 0.2 studs above the torso's bottom edge;
  - the flat of the blade faces backward, so you see its full width from behind;
  - **length about 2.7 to 3.0 studs** (1.35 to 1.5 torso widths); blade about 1.9, grip about 0.8.
- One player (Messi, 5.0 s) wears a long dagger upright down the spine, blade down. It may be his skin; the rest
  are all flat across the belt.
- It is welded tight: **no sway or bounce while running** (33 to 36 s, frames side by side).
- The default knife is plain steel with a dark checkered grip (alex, 33 s). Skins are bright and ornate: gold guards,
  purple, cyan gems, curved white blades, a pink one with sparkles (5.0 s, 43.4 s).

### 2. Knife in the catcher's hand
- **Right hand, normal grip**: the blade carries on along the forearm, pointing down and a bit forward while the arm
  hangs (42.3 to 42.6 s, 43.63 s, 44.33 s close-up). The arm hangs low by the hip in the run, with no guard pose.
- Its length in the hand reads about one arm long (about 2 to 2.5 studs) at 43.47 s, which fits the back knives.
- **Skin glow:** the pink skin keeps a soft pink glow with small sparkles around the blade, all the time (44.2 to
  44.7 s), brighter during the swing (43.4 to 43.5 s).

### 3. The slash (43.10 to 43.77 s, `knife-study-slash.jpg`)
- **No wind-up.** The catcher runs up with the knife low, and the arm sweeps straight out:
  - 43.20 s carry: knife low by the right hip;
  - 43.27 s strike: the arm sweeps out and across (about 0.07 to 0.10 s, 2 to 3 frames, from carry to reach);
  - **43.30 s the hit**: the runner's whole body **fills solid red** for 2 frames (43.30 to 43.33 s);
  - 43.37 to 43.50 s follow-through and **hold**: the knife arm sits out to the side, about level and a little
    back, with the free arm pointing ahead at the runner (about 0.17 s);
  - 43.53 to 43.63 s: the arm drops back to carry (about 0.13 s);
  - total from start to carry again: **about 0.40 s**, with the hit only about 0.07 s after the start.
- It reads as a **sideways sweep**, not a straight thrust, at least from this angle.
- **Trail:** only a short pink smear around the blade in the skin's colour (about one knife long, gone in about
  0.1 s). There is **no big white arc, no spark burst and no flash on screen**. The recorder's camera doesn't shake.
  (A white wedge on the ground near them is a huss's ground trail, not the knife.)

### 4. A catch landing (41.60 to 42.13 s and 43.30 to 43.77 s, `knife-study-lunge.jpg`)
- **Red hit flash on the caught runner:** solid red for 2 frames, then a darker red tint for about 0.2 s. After
  that a **red outline stays while they lie down** (42.07 s, 43.77 s, 44.3 s). Catchers have red outlines too;
  standing runners have blue ones.
- They fall stiffly **flat in 0.40 s** (41.67 to 42.07 s) **to 0.47 s** (43.30 to 43.77 s).
- **The lunge goes through people:** Danilo leaps, catches afek at 41.67 s and Sabtwini at **41.80 s, 0.13 s
  later in the same leap**, then dives low, lands about 42.0 s and is up by about 42.27 s.
- **Lunge ribbon:** a long, soft **white-to-pink ribbon** trails from his body. It is about 0.6 to 1 stud wide,
  **about 6 to 8 studs long**, and arcs up with the leap (41.80 to 42.13 s), fading in about 0.3 s. It might be his
  bought Trail cosmetic rather than a lunge effect; one catcher can't settle that.
- Knife on equip/unequip: no draw animation seen. The knife is just in the catcher's hand during the round.

## Ours today (KnifeService, StabMotion, Config/Round), biggest gaps first
1. **Back position is wrong.** Ours sits upright, the blade up over one shoulder at 35 degrees
   (`giveBack` C0 `CFrame.new(0.15, -0.05, back) * Angles(0, 0, -35)`). HV's lies flat across the belt, grip on the
   right hip, blade to the left, tilted 12 to 20 degrees, with the flat facing back.
2. **The stab is slower to land and a different shape.** Ours coils back first (0.11 s), so the blade lands at
   about 0.17 s, and it is a forward thrust. HV has no coil: a sideways sweep lands at about 0.07 s, holds with
   the arm out (about 0.17 s) and is back by about 0.40 s.
3. **No red hit flash on the caught body, and downed runners lose their outline.** Ours: a red spark burst
   (`Juice`), a screen tint and a shake for you. `RoundHud.refreshHighlight` gives a Down runner no outline. HV:
   solid red body for 2 frames, a red tint, then a red outline while down, and no spark burst.
4. **No lunge ribbon.** HV shows a long white-to-pink ribbon arcing with the leap (if it isn't his cosmetic). We
   have nothing on the lunge.
5. **One runner per lunge.** Ours stops after the first hit (`RoundService` "one runner per lunge"). HV caught two
   in one leap, 0.13 s apart. This is a rule change: ask the owner before changing it.
6. **Skins don't glow.** Ours only recolours the blade Neon. HV skins have a soft glow with small sparkles.
7. **Ours is a little small.** Ours is about 2.2 studs (grip 0.75 + blade 1.05 + tip 0.42). HV's is 2.7 to 3.0.
8. Already close: hand grip (blade down and forward along the forearm, `KnifeGrip` -150 degrees), fall time
   (`Knockdown.FallTime` 0.45 vs HV 0.40 to 0.47), no camera shake on a lunge, and a short skin-coloured trail
   (`SlashTrail` 0.16 s).

## Plan for the owner's own knives
**First, the files.** A render is a picture. It can be the shop icon, but it can't go in a hand. To hold it in 3D we
need each knife as a **mesh** (`.fbx` or `.obj`, or a Roblox model / `.rbxm`), one per knife, named like the kit (for
example `Knife_Moonlit.fbx`). The owner imports each one in Studio (Avatar or 3D Importer), or sends the files. If
only renders come, ask for the meshes; never redraw them. Renders go in `design/knives/`.

**How a knife model plugs in** (extends today's `HuzzKnife` hook in KnifeService):
- `ServerStorage/HuzzKnives/<SkinKey>`: one Model per `CoinShop` knife key, with `HuzzKnife` as the default.
- Inside each model:
  - a part `Handle` (the grip): its **+Y points to the blade tip**, its **X is the blade's flat side** (the thin
    way);
  - an Attachment `Grip` where the fist closes (the middle of the grip, just under the guard);
  - Attachments `TrailBase` (at the guard) and `TrailTip` (at the tip);
  - optional `Glow`: a PointLight plus a small sparkle ParticleEmitter, off until the knife is placed.
  A Studio helper can set these on an imported mesh (a Command Bar script tagged `[HuzzKnife]`).
- **Scale on load**: `Model:ScaleTo` so the knife is **2.8 studs from pommel to tip** (HV 2.7 to 3.0), whatever
  size it was made at.
- **In the hand** (as now, a Motor6D `KnifeGrip` on RightHand): put `Grip` on `RightGripAttachment`, blade along the
  forearm, pointing down and about 30 degrees forward: today's C0 `Angles(-150, 0, 0)` is right; just offset it by the
  model's `Grip` instead of the Handle's centre.
- **On the back** (`giveBack`): weld to `LowerTorso` (R15; `Torso` on R6) at the belt:
  `C0 = CFrame.new(0.55, 0, LowerTorso.Size.Z/2 + 0.15) * Angles(0, 0, rad(105)) * Angles(0, rad(90), 0)`.
  The Grip sits on the right hip, the blade points left and 15 degrees down, the flat faces back, and the tip
  shows about 0.8 studs past the left side. Measure it against `knife-study-back.jpg` in one side-by-side
  before showing the owner.

**Motion** (`Shared/StabMotion` KEYS, `Config/Round.Stab`):
- `Stab.Time` 0.42 → **0.40**. Keys (as parts of 0..1):
  - 0.00 carry;
  - **0.18 reach**: the arm sweeps out and across to the right, about level, the waist turned 20 degrees into
    it, the free arm pointing ahead;
  - 0.25 small overshoot;
  - 0.60 still held out;
  - 1.00 back to carry.
  Drop the coil (or keep it under 0.03 s). Move `trailOn` to 0.08 to 0.45. The server's hit can stay as it is.
- **Lunge** (`Gameplay/Dash` + Actions): play the same sweep at take-off. A dive low at the end (the waist
  pitched forward 35 degrees for 0.15 s), up by +0.25 s. No new numbers in `Config/Round.Lunge`.

**Effects** (all neon parts, Trails and Highlights, so nothing waits for an upload):
- `SlashTrail`: keep it short. Lifetime **0.12**, width = the blade's length, colour = the skin's colour fading to
  white at the tip, Transparency 0.2 → 1, LightEmission 0.8. On only during the sweep.
- **Hit flash on the caught runner** (client, from the Caught event): a Highlight Fill red at FillTransparency
  **0.15 for 0.07 s**, then to 0.6 by 0.25 s, then fill off. Then the **red outline while down** (add a Down case to
  `refreshHighlight`). It's one body flash per catch, not a screen flash. Still, run it through `Burst.flashOk` to
  keep to 1 flash a second. Consider dropping the red spark burst in `Juice` (HV has none), so the moment isn't
  doubled.
- **Lunge ribbon** (only if the owner wants it; HV's might be a cosmetic): a Trail from shoulder to hip
  Attachments. Lifetime **0.3**, white → the skin's colour, Transparency 0.3 → 1, on for the leap only.
- **Skin glow**: each skin's `Glow`, a PointLight (Range 4, Brightness 1, skin colour) plus at most 4 sparkles a
  second (Rate 4, Lifetime 0.4, Size 0.15). For Legendary-style skins, glow on the back too. The default steel
  knife gets none.

**Still unknown or Studio-only:** the exact slash direction (seen from one side only), whether the ribbon is a
cosmetic, the knife's sound (the recording has no audio), and how the owner's meshes look at 2.8 studs under our
lighting.

## Done (Oct 18: the owner's 30 knives, `.glb`)
- All 30 in the coin shop (`Config/CoinShop` Knife slot, his names and rarities, priced by rarity), with card
  pictures rendered from the real models (`assets/art/knife-*.png` via `tools/knives/render_cards.mjs` +
  `compose_cards.py`; sheet `docs/previews/knife-cards.jpg`). Studio setup script `tools/knives/setup_knives.lua`
  (lengths 2.4 to 3.3 studs by each model's real length, not one 2.8).
- Mounts, slash, lunge and the effects ladder as planned above (`Shared/KnifeLook`, `StabMotion`, `Shared/KnifeLeap`:
  the leap goes forward or sideways, never back). Side by side `docs/previews/knives-vs-hv.jpg`
  (`tools/knives/knives_vs_hv.py`), film `docs/previews/knife-leap.mp4` (`motion3d/knife_scene.luau`).
- Not done: the red Highlight hit flash and the red outline while down (Juice's spark burst stays), the lunge ribbon.
  In hand from the front our blades read thinner than HV's.
