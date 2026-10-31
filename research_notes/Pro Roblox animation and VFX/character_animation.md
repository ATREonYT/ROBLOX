# Pro Roblox character animation: workflow, tools and craft numbers (Oct 2026)

Scope: how top Roblox games (The Strongest Battlegrounds, Jujutsu Shenanigans, Heroes Battlegrounds, Blox Fruits, simulators) get snappy character animation, and what a small AI-assisted team can use in October 2026.
Sources are web pages (URLs) and, where the web had no hard numbers, the repo's own vault notes (LihFolk Vault V2, a third-party knowledge base kept in this repo; cited as `repo:` paths). Vault numbers come from one live action game ("the reference project") or are labelled as rules of thumb there; they are not measured from TSB or JJS.

## 1. Tools and workflow (Moon Animator 2, Animation Editor 2026, Blender, mocap, AI)

### Takeaway
There is still no built-in text-to-animation in Roblox Studio in Oct 2026; the realistic pipeline is: rough motion from video (Roblox Animation Capture beta for R15, or Rokoko/DeepMotion/Move.ai into Blender), then hand-keyed pose-to-pose polish in Moon Animator 2 or the Animation Editor, published as an asset and played with markers. Battleground-style snappy moves are hand-keyed, not mocapped: mocap gives realistic, floaty timing that has to be re-timed.

### Cited Findings
**Roblox Animation Editor (Clip Editor)**
- Runs at 30 fps; timeline shows seconds:frames (0:15 = half a second); default length 1 s, extendable — [Roblox Docs: Animation Editor](https://create.roblox.com/docs/animation/editor)
- Seven priorities, highest to lowest: Action4, Action3, Action2, Action, Movement, Idle, Core; a higher priority overrides a lower one already playing — [Roblox Docs](https://create.roblox.com/docs/animation/editor)
- Easing styles: Linear, Constant (snap, no interpolation), CubicV2, Elastic, Bounce; directions In / Out / InOut — [Roblox Docs](https://create.roblox.com/docs/animation/editor)
- Loops do not interpolate last key back to first: duplicate the first keys as the last keys. Renaming the last keyframe "End" is needed to replace default Animate-script clips. Saves a KeyframeSequence in ServerStorage — [Roblox Docs](https://create.roblox.com/docs/animation/editor)
- Sept 24, 2025 update: the editor now evaluates keys exactly like the engine (preview = in-game); legacy Cubic had Ease In and Ease Out swapped at runtime — old "Cubic V1" clips keep their old behaviour, new "Cubic V2" behaves as labelled; Auto Tangent "bounce" fixed; 0→180° rotations now display correctly; animations on scaled bodies (e.g. 0% body type) may shift — [DevForum: Animation Clip Editor Update](https://devforum.roblox.com/t/animation-clip-editor-update-better-authoring-playback/3956668)
- Curve Editor (per-channel tangent control; a keyframe clip can be promoted to a CurveAnimation) — [DevForum: New Animation Curve Editor](https://devforum.roblox.com/t/new-animation-curve-editor-beta-fine-grain-control-of-animations/1770367); [Docs: Curve editor](https://create.roblox.com/docs/animation/curve-editor.md)
- IK in the editor (body-part and full-body IK with pinning) dates from 2018 — [DevForum: Inverse Kinematics](https://devforum.roblox.com/t/new-to-animation-editor-inverse-kinematics/183507)
- Users in the 2025 thread were still asking for Sine and more easing styles; not announced — [DevForum](https://devforum.roblox.com/t/animation-clip-editor-update-better-authoring-playback/3956668)

**Animation Capture (video → keyframes, Roblox built-in, beta)**
- Body: enable Beta Features ⟩ Live Animation Creator; R15 rigs only; .mp4/.mov, one person, well lit, single continuous shot under 15 s, stable camera; keyframes appear after ~1 minute and are editable — [Docs: Animation capture](https://create.roblox.com/docs/animation/capture)
- Face: webcam, up to 60 s, for animatable (dynamic) heads — [Docs: Animation capture](https://create.roblox.com/docs/animation/capture)
- Original beta thread — [DevForum: Live Animation Creator Beta](https://devforum.roblox.com/t/live-animation-creator-beta/1908284)

**AI / text-to-animation (Oct 2026 status)**
- A guide dated Oct 6, 2026 says Roblox Assistant has no animation command and "There is no text-to-animation in Studio"; RDC 2026 roadmap items are prompt-set NPC behaviour and motion matching for default movement (late 2026–2027). Caveat: the page is written by NPCMotion, which sells a third-party text/video → R15 KeyframeSequence plugin — [NPCMotion: Roblox AI tools](https://www.npcmotion.com/blog/roblox-ai-tools)
- Cube "4D" generation makes functional objects (a 5-part car, single-mesh objects), not character animation; animations listed as something it "will eventually" generate; reviewer called quality poor / "in its infancy" — [PCGamesN](https://www.pcgamesn.com/roblox/4d-generative-ai-model-update); [Roblox Newsroom, Feb 2026](https://about.roblox.com/newsroom/2026/02/accelerating-creation-powered-roblox-cube-foundation-model)
- Repo's own Oct 2026 tool list: Ropilot ($20/mo) claims Blender models and animations — `repo: Build Playbooks/04 AI Tools Landscape October 2026.md`
- Repo note: Animation Graph state machines are a Studio beta ("watch, don't ship yet") — `repo: Build Playbooks/03 What's New on Roblox - RDC 2026 and October.md`

**Third-party mocap (video → FBX, then Blender → Roblox)**
- Rokoko: free Starter tier has unlimited FBX export but only 30 s/month of Vision AI video and 5 Text-to-Motion imports/month, default meshes only; Basic $10–12/mo adds custom-character retargeting, 600 s video, 100 text-to-motion imports; Plus $20–28/mo; Pro $50–70/mo. The pricing page contradicts itself on some tiers — [Rokoko Pricing](https://www.rokoko.com/pricing)
- DeepMotion: video-to-mocap (body, face, hands), Starter $9/mo up to Studio $83/mo (annual), free 60 s/month, FBX/BVH/GLB; dim video lowers quality — [fast.io list, updated May 2026](https://fast.io/resources/best-ai-animation-tools-2026/) (aggregator)
- Cascadeur: physics-assisted keyframing (auto-posing, ballistic arcs), free non-commercial, Indie $8–19/mo, FBX/DAE — [fast.io](https://fast.io/resources/best-ai-animation-tools-2026/)
- Autodesk Flow Studio: markerless video mocap, Lite $19.99/mo — [fast.io](https://fast.io/resources/best-ai-animation-tools-2026/)
- Older DevForum tutorial for DeepMotion → Roblox — [DevForum: Animate from a Recording with DeepMotion](https://devforum.roblox.com/t/animate-from-a-recording-with-deepmotion-ai-tutorial/1692852)

**Blender → Roblox**
- Roblox's FBX export settings for animation: set scene Start/End to cover all keys; Path Mode Copy + Embed Textures; Custom Properties on; Apply Scalings = FBX Unit Scale; Add Leaf Bones OFF; Animation ON with NLA Strips, All Actions and Force Start/End Keying OFF and Simplify 0.0 — [Roblox Docs: Export emote from Blender](https://create.roblox.com/docs/it-it/avatar/emotes/export)
- Bulk upload plugin exists for publishing many clips — [DevForum: Bulk Animation Upload](https://devforum.roblox.com/t/bulk-animation-upload-%E2%80%94-no-more-tedious-uploads/3504606)
- Vault has full Blender rig/bone-roll/import notes — `repo: LihFolk/LihFolk Vault V2/08 Animation/02 Rigging and Importing/Animation Data from Blender to Roblox.md`

**Moon Animator 2 (paid plugin, the battlegrounds standard)**
- Workflow: insert an R6 rig (Character Inserter) → File ⟩ New animation → "+" add the model → rotate parts in the viewport (auto-keyframing records it) → Numpad +/= adds a pause key, G resets, 7 opens a key's values (easing, AttachToPart) → markers track (Numpad *) → camera track with FOV keys (20–50 for scenes) and subtitles — [DevForum: Getting Started with Moon Animator 2](https://devforum.roblox.com/t/getting-started-with-moon-animator-2-unofficial/476330)
- Tips there: avoid linear except for arcs/fake physics/ragdoll; R6 has pose limits (don't raise arms too high); CFrame (non-Motor6D) tracks can't export as a Roblox animation and must be replayed by script — [same](https://devforum.roblox.com/t/getting-started-with-moon-animator-2-unofficial/476330)
- Camera and effect tracks from Moon files need custom code to play in-game — [DevForum: playing Moon 2 files' effects and camera](https://devforum.roblox.com/t/how-do-i-play-moon-2-files-effects-and-camera-movement/2878483)
- Only buy the official listing; pirated "free Moon" builds are a security risk — `repo: LihFolk/LihFolk Vault V2/08 Animation/03 Authoring/Moon Animator and Third-Party Tools.md`

### Inferences
- Recommended pipeline for this repo (small team + AI): (1) record a 5–15 s reference video of the move (or find one); (2) R15: Roblox Animation Capture; R6: Rokoko/DeepMotion → Blender → retarget, or just use the video as reference; (3) in Moon Animator 2 / Animation Editor, strip to 4–8 key poses, push them (§3), re-time to the frame chart (§2), set per-key easing; (4) add markers (Hit, TrailOn/Off, VFX); (5) publish; repo rule says owner's files are raw KeyframeSequences played via KeyframeSequenceProvider in Studio until published.
- Mocap output alone looks "realistic and floaty" next to TSB/JJS; the hit games' look comes from hand-keyed extremes, holds and VFX, so budget time for re-timing, not capture.
- Use CubicV2 (not legacy Cubic) for new clips; old clips with Cubic may ease the "wrong" way when edited.

### Gaps
- No primary Roblox announcement found confirming any 2026 change to the Animation Editor's frame rate options (an older 2021 "New Settings" thread exists: https://devforum.roblox.com/t/new-settings-available-in-the-animation-editor/1489673 — not read).
- Moon Animator 2's official easing list and IK features were not documented on any page fetched; easing lists on SEO pages were unreliable and skipped.
- No independent quality test of NPCMotion, Rokoko text-to-motion or Roblox capture on fast anime moves was found.
- Move.ai current pricing: only aggregator pages found; not verified.

## 2. Craft numbers (frame counts, holds, easing, overshoot, smears)

### Takeaway
At 30 fps: light hits = 2–6 f anticipation, 1–3 f strike, 2–4 f contact hold, 4–8 f settle; heavies = 6–15 f anticipation. Hit-stop is added at runtime (30–60 ms light, 80–150 ms heavy), never baked. Smears are faked with trails, slash meshes, afterimages and flipbook particles, because Roblox animations can't scale limbs.

### Cited Findings
- Light anticipation 2–6 frames, heavy 6–15 (30 fps); strike 1–3 frames with a trail window — `repo: LihFolk/LihFolk Vault V2/08 Animation/03 Authoring/Combat Animation Craft.md`
- Contact "moving hold": 2–4 frames near-zero velocity, then 4–8 frames of settle — `repo: .../03 Authoring/Timing Spacing and Frame Charts.md` and `Combat Animation Craft.md`
- Hit-stop: runtime only, on confirmed hits (baked freezes make whiffs look like hits); 30–60 ms light, 80–150 ms heavy/finisher; general game-feel range 50–100 ms — `repo: .../Combat Animation Craft.md`; `repo: .../05 Systems/Hit Reactions Stagger and Hit-Stop.md`
- Better hit-stop for networked games: slow the track to ~0.12× then catch up at ~1.88× so the body doesn't drift behind clock-timed VFX (plain `AdjustSpeed(0)` makes swords arrive after sparks in flurries) — `repo: .../Hit Reactions Stagger and Hit-Stop.md`
- `AdjustSpeed(0)` is the standard community way to freeze a pose — [DevForum: freeze animation](https://devforum.roblox.com/t/how-to-freeze-animation-in-current-time/1295624)
- Overshoot: dash lean with an extra key pushing the upper body 45% further, then settling 18% past upright before returning, made a 0.30 s dash read as momentum — `repo: .../Timing Spacing and Frame Charts.md`
- Landing: 2–4 frames down, 4–8 frames recovery (rule of thumb) — `repo: .../Timing Spacing and Frame Charts.md`
- At 1–2 frames per strike the eye sees nothing: blade tips at impact moved 1,000–2,000°/s (17–33° per 60 Hz frame); show the path with a trail, smear mesh or blur timed by TrailOn/TrailOff markers — `repo: .../Timing Spacing and Frame Charts.md`
- Smear meshes: a curved slash mesh along the arc for 2–4 frames — `repo: .../Combat Animation Craft.md`
- Flipbook particles (animated sprite sheets) are available for slash/smear sprites — [DevForum: Particle Flipbooks](https://devforum.roblox.com/t/animated-particles-with-the-particle-flipbooks-beta/1718023)
- Fighting-game reference: a typical 3D fighting game jab hits around frame 8–10 at 60 fps (≈4–5 frames at 30); split each move into anticipation, connection, follow-through (blend to next combo move here) and recovery — [Pushing Buttons: Attack animations part 2](https://pushing-buttons.blogspot.com/2009/02/attack-animations-part-2.html)
- Repo's adopted anime chart (30 fps): M1 jab 2–3 f wind-up / 2 f strike / 1–2 f hold / 4–6 f recovery (~0.35 s per hit); M1 finisher 5–6 / 3 / 3 / 8–10; heavy 8–12 / 3–4 / 3 / 10–14; ultimate 15–30 f charge — `repo: Build Playbooks/15 Anime VFX and Animation Playbook.md` §6
- Easing rule in repo: ease OUT fast from the extreme (Quint/Exponential in Tween terms; in the Animation Editor the closest is CubicV2 Out or Constant for snaps), hold the extreme 2–4 f, never ease into a hit — `repo: Build Playbooks/15 ...` §6; editor easing list from [Roblox Docs](https://create.roblox.com/docs/animation/editor)
- `AdjustSpeed` also scales marker times: at 1.5× a marker at 0.30 s fires 0.20 s after play — `repo: .../Combat Animation Craft.md`
- Network: a 3-frame (0.1 s) wind-up may never be seen by a bystander on 150 ms ping; strikes and trails must read on their own — `repo: .../Combat Animation Craft.md`

### Inferences
- Practical default for this repo at 30 fps: light M1 ≈ 10–13 frames total, heavy ≈ 25–32 frames, throw/launch ≈ heavy timing with a longer hold (3–5 f) at release and a 1-frame impact flash.
- Because the editor only offers Linear/Constant/CubicV2/Elastic/Bounce, "snappy" is built from key placement: put a key 1 frame after the strike extreme (the overshoot), then use CubicV2 Out for settles; use Constant for 1-frame snaps into anticipation.
- Afterimages (cloning body parts with ForceField/Neon material, fading over ~0.2 s) are the common battlegrounds trick for "speed"; this is in LihFolk's DashTrail system per the repo playbook §5.

### Gaps
- No measured frame data for TSB, JJS or Blox Fruits moves was found online; numbers above are from game-animation practice and the vault's reference project. Measuring the hits frame by frame from 30 fps recordings would close this.
- No authoritative source found for exact overshoot percentages on attack extremes beyond the dash example.

## 3. Posing: line of action, silhouette, asymmetry, R6 vs R15

### Takeaway
Pose for the gameplay camera (behind/above, small on screen), with a clear line of action and broken symmetry. Most battlegrounds pick R6 because 6 parts are faster to animate, read as bolder shapes, and give everyone the same hitbox.

### Cited Findings
- Check every key pose from the gameplay camera, not side view; break symmetry everywhere; keep the weapon outside the body outline; clear line of action; centre of mass over the feet unless falling; no twinning — `repo: LihFolk/LihFolk Vault V2/08 Animation/03 Authoring/Posing and Silhouettes.md`
- Why combat devs prefer R6: "easier to animate, looks better"; an R15 cutscene takes ~2.5× longer; R15 has many more joints to key; adjustable R15 proportions can give some players smaller hitboxes; players in those communities preferred R6 and pushing R15 hurt reception. Counterpoint: Heroes Battlegrounds shows skilled R6 can look as good; some prefer R15 for realism — [DevForum: Why combat devs lean towards R6](https://devforum.roblox.com/t/why-do-combat-game-developers-lean-more-towards-r6-rather-than-r15/3136549)
- R6 pose limit: arms can't be raised too high without breaking the shoulder look — [DevForum: Moon Animator 2 guide](https://devforum.roblox.com/t/getting-started-with-moon-animator-2-unofficial/476330)
- R6→R15 adapter lets R6 games use R15-only tech (e.g. layered clothing) — [DevForum: R6 to R15 Adapter](https://devforum.roblox.com/t/r6-to-r15-adapter-beta-enable-r15-tech-in-r6-experiences/2557840)
- Roblox's built-in Animation Capture works only on R15 — [Docs](https://create.roblox.com/docs/animation/capture)

### Inferences
- For a kid-focused game using standard avatars (R15 by default, layered clothing, Animation Capture), R15 is the practical choice; get "R6 boldness" by exaggerating torso twist and lean (UpperTorso/LowerTorso split is R15's advantage) and keeping limbs straight-ish in extremes.
- Exaggeration on Roblox rigs = torso lean 20–40° and big root drops (crouch) rather than limb bending, since R6 limbs can't bend and R15 elbows/knees read small at gameplay distance. (Rule of thumb, not sourced.)

### Gaps
- No primary source on whether TSB / JJS specifically force R6 (widely reported by players, but not verified here).

## 4. Priorities, blending, weight/speed tricks, markers

### Takeaway
Put attacks on Action–Action4, keep upper-body variants for moving attacks, fade in 0–0.05 s for snappy starts, use AdjustSpeed for hit-stop and startup tuning, and fire every effect from markers, not timers.

### Cited Findings
- Priority order Action4 > Action3 > Action2 > Action > Movement > Idle > Core — [Roblox Docs](https://create.roblox.com/docs/animation/editor)
- Priority works per joint: a track competes only on joints it keys; an attack that keys only torso/arms/head lets legs keep walking. An attack clip with leg keys makes the character skate. Ship `<Clip>Upper` copies for moving attacks — `repo: LihFolk/LihFolk Vault V2/08 Animation/01 Fundamentals/Playback, Priorities and Blending.md`
- `Play(fadeTime)` ramps weight linearly over fadeTime; never sort priorities by `.Value` (Core = 1000 but ranks lowest) — `repo: same`
- A one-shot holds its last pose then fades out over 0.3 s (measured); for held charges loop a short hold clip — `repo: .../05 Systems/Stance and Charge Moves.md`
- Author for the pose, play at gameplay speed: a 1.2 s stance played at 1.71× to reach full charge in 0.7 s; markers move in step — `repo: .../Stance and Charge Moves.md`
- Fire VFX on `GetMarkerReachedSignal("Hit")` at the contact frame — `repo: Build Playbooks/15 ...` §6; markers in Moon Animator via the marker track — [DevForum Moon guide](https://devforum.roblox.com/t/getting-started-with-moon-animator-2-unofficial/476330)

### Inferences
- Speeding up startups: play the full clip and `AdjustSpeed(1.2–1.5)` only through the anticipation, then back to 1 at the "Strike" marker; this keeps the authored pose but feels more responsive.

### Gaps
- Exact fade times used by TSB/JJS are unknown.

## 5. Charge-up / power-up sequence (anime style)

### Takeaway
Charge = crouch anticipation (fists clenched, chin down, elbows out) → burst pose (chest out, arms flung down and back, head up "scream") → looping hold with a small shake, synced to aura layers and a camera kick on release.

### Cited Findings
- Repo charge-up beat sheet: 0–0.3 s anticipation crouch, aura pulls in; 0.3 s burst (ground rings 0.12 s apart, dust, streaks, flames ×2.2, shake 0.35–0.7); 0.3–0.7 s speed lines and rising rocks; 0.7 s settle; ultimate charge 15–30 frames, uncancellable — `repo: Build Playbooks/15 Anime VFX and Animation Playbook.md` §3, §6
- Stance/charge moves = 2–3 clips (stance, hold loop, release) stitched by a state machine; server measures charge time from its own press/release receipt (≈50 ms tolerance); release gets camera kick, flash, hit-stop, shake — `repo: LihFolk/LihFolk Vault V2/08 Animation/05 Systems/Stance and Charge Moves.md`
- Ultimate cutscene recipe in repo: camera cut low 3/4, FOV 70→55 over 0.4 s, letterbox bars 0.15 s, move name slam 1.6→1 in 0.2 s, under 3 s total — `repo: Build Playbooks/15 ...` §7
- Moon Animator camera tracks with FOV keys are how creators author these cutscene cameras, but they must be replayed by script in-game — [DevForum Moon guide](https://devforum.roblox.com/t/getting-started-with-moon-animator-2-unofficial/476330); [DevForum: playing Moon 2 camera](https://devforum.roblox.com/t/how-do-i-play-moon-2-files-effects-and-camera-movement/2878483)

### Inferences
- Key poses for a charge (4–5): (1) neutral; (2) crouch: root down ~0.5–1 stud, knees out, fists at hips, torso pitched forward 15–25°; (3) tension: shoulders up, small 1–2 frame vibration keys (±2–3° on torso) — kid-safe flash rules still apply to effects; (4) burst/scream: torso back 15–20°, head up, arms down-and-back, held 6–10 f on the aura burst; (5) settle into a powered idle that's broader and taller than the normal idle.
- Hair/aura motion is VFX (particles, beams) rather than animation on Roblox avatars.

### Gaps
- No web source found giving frame-by-frame breakdowns of a TSB/JJS charge or emote animation; a 30 fps capture of the live games is the only way to get these numbers. Idle and emote numbers (breath cycle length, emote lengths) were not researched online; see `repo: .../03 Authoring/Idle Breathing and Secondary Motion.md` and `.../05 Systems/Emotes and Social Animation.md`.
