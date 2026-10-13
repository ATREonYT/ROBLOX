# Animation & VFX for a Cartoony Roblox Simulator ("Hood"): character, pets, procedural, world, juice (2025–2026)

> **How these notes were gathered (read first).** The research sandbox blocked direct page fetches from create.roblox.com, devforum.roblox.com, Wikipedia, GDC Vault, gamedeveloper.com and most blogs. To get around that:
> - **Roblox Creator Hub docs** were read from Roblox's official source repo, [Roblox/creator-docs on GitHub](https://github.com/Roblox/creator-docs). The latest commit was **2 Oct 2026**, so they are current. They are cited below by their public create.roblox.com URLs, which publish the same content.
> - **Community Luau modules** (spr, Quenty Spring, RbxCameraShaker, RbxUtil Shake) were read as source code from raw.githubusercontent.com.
> - **DevForum threads and theory talks** (Vlambeer, "Juice it or lose it", Sakurai, Freya Holmér) were seen only as **web-search summaries**, not full pages. Those claims are marked "(search summary)" and should be treated as less verified.
> - **All Luau snippets under "Inferences" are my own synthesis** built on the cited APIs. They have not been tested in Studio.

---

## 1. Fundamentals: the 12 principles, how they map to R15/R6 and to code, and timing guidelines

### Takeaway
The 12 Disney principles ([Thomas & Johnston, 1981](https://en.wikipedia.org/wiki/Twelve_basic_principles_of_animation)) apply directly to Roblox:
- **Keyframed rigs:** use the Animation Editor's easing, Curve Editor, IK and looping.
- **Procedural code:** springs give follow-through and overlap; exponential smoothing and easing styles give slow-in/slow-out; Bezier curves give arcs; scale tweens give squash and stretch.

Timing is the biggest lever. Roblox's editor runs at 30 fps by default. Classic references give concrete frame counts for walks, and fighting-game frame data gives counts for punches.

### Cited Findings
**The 12 principles**
- The twelve principles were introduced by Disney animators Ollie Johnston and Frank Thomas in *The Illusion of Life: Disney Animation* (1981) — [Wikipedia](https://en.wikipedia.org/wiki/Twelve_basic_principles_of_animation) (search summary)
- The list: squash and stretch; anticipation; staging; straight-ahead vs. pose-to-pose; follow-through and overlapping action; slow in/slow out; arcs; secondary action; timing; exaggeration; solid drawing; appeal — [Wikipedia](https://en.wikipedia.org/wiki/Twelve_basic_principles_of_animation); [Arlington Museum of Art](https://arlingtonmuseum.org/explore-more/the-twelve-principles-of-animation) (search summary)
- Their purpose was to create the illusion that cartoon characters obey physics, while also covering emotional timing and appeal — [Wikipedia](https://en.wikipedia.org/wiki/Twelve_basic_principles_of_animation) (search summary)

**Roblox Animation Editor basics**
- Timeline units are **seconds:frames**, and animations run at **30 fps** by default ("0:15 indicates ½ second"). The timeline defaults to 1 s long — [Roblox Docs: Animation Editor](https://create.roblox.com/docs/animation/editor)
- **Easing (slow-in/slow-out) is built in.** The default is linear, which the docs call "stiff and robotic"; cubic easing "appear[s] more natural" — [Roblox Docs: Animation Editor](https://create.roblox.com/docs/animation/editor)
  - Per-keyframe easing styles: Linear, Constant (snap), CubicV2, Elastic, Bounce.
  - Easing directions: In, Out, InOut.
- **Looping:** "A looping animation doesn't interpolate between the final keyframes and first keyframes." To loop smoothly, duplicate the first keyframes and use them as the final keyframes — [Roblox Docs: Animation Editor](https://create.roblox.com/docs/animation/editor)
- **Curve Editor:** per-axis X/Y/Z curves with tangents, and interpolation modes Linear, Constant and Cubic (only Cubic has tangents) — [Roblox Docs: Curve Editor](https://create.roblox.com/docs/animation/curve-editor)
  - It can "Generate Curve" Bounce/Elastic In/Out/InOut across selected keys, because CurveAnimations lack those easing styles natively.
  - **Warning:** switching to the Curve Editor converts the KeyframeSequence to a CurveAnimation. With Euler rotation, any quaternion → Euler conversion "is impossible to convert back". Set the rotation type first.

**Timing references**
- **Walk (Animator's Survival Kit):** at 24 fps, a brisk natural walk is **12 frames per step** (24-frame cycle, contacts at frames 1, 13, 25) — [Monmouth Univ. walk-cycle notes](https://animation.monmouth.edu/instruct/animation/walk-cycle/); [Ulster Univ. blog](https://blogs.ulster.ac.uk/scottmoore/2024/10/21/animation-strategies-animation-walk-and-runs-regular-run-cycle/) (search summary)
- **Run:** about 12–16 frames per cycle, or 4 frames per step for a very fast run, versus 24 frames per cycle for a walk — [Ulster Univ. blog](https://blogs.ulster.ac.uk/scottmoore/2024/10/21/animation-strategies-animation-walk-and-runs-regular-run-cycle/); [cloytoons run research](https://cloytoons.wordpress.com/2015/12/06/animation-research-run-cycle/) (search summary)
- **Punch (fighting-game frame data at 60 fps):** an attack has **startup** (time to come out), **active** (hitbox out, fist extended) and **recovery** (return to neutral) — [In Third Person frame-data guide](https://inthirdperson.com/2012/04/18/universal-fighting-game-guide-how-to-read-frame-data/) (search summary)
  - Jabs often start up in about 4 frames (≈67 ms) — same source.
  - A generic Tekken 8 jab is 9 startup / 1 active / 17 recovery frames (≈150 / 17 / 283 ms) — [Wavu Wiki](https://wavu.wiki/t/Frame); [In Third Person](https://inthirdperson.com/2012/04/18/universal-fighting-game-guide-how-to-read-frame-data/) (search summary)

**Reference capture**
- Studio's **Animation Capture** can generate body keyframes from uploaded video. It is in beta as "Live Animation Creator". Face capture records up to 60 s from a webcam — [Roblox Docs: Animation capture](https://create.roblox.com/docs/animation/capture)

### Inferences
**How each principle maps to Hood**

| Principle | Keyframed (Animation Editor / Moon) | Procedural (Luau) | Hood example |
|---|---|---|---|
| Squash & stretch | Limited on R15: limbs are rigid MeshParts. Fake it by stretching the pose (longer reach, body lean) and squashing via the torso/hip drop | Tween or spring `Size` on single-mesh pets and props, preserving volume (Y×s, XZ×1/√s). Use `UIScale` for UI | Pet lands from a hop → squash 0.8/1.12 for about 80 ms. Bag squashes on impact |
| Anticipation | 3–6 frames of wind-up (shoulder back, fist cocked) before the strike | Brief reverse motion before a tween (EasingStyle.Back "In") | Punch wind-up; wall "creaks" before it collapses |
| Staging | Strong silhouettes; punch arm crosses the screen plane, not toward the camera | Camera framing and FOV kick | Strike faces the bag, readable from a third-person camera |
| Straight-ahead vs pose-to-pose | Pose-to-pose: block key poses, then add breakdowns | n/a | Block anticipation → contact → recoil poses |
| Follow-through / overlap | Offset limb keys by 1–3 frames (hips lead, then shoulder, arm, fist); settle | Springs with damping < 1 give natural overshoot and settle | Bag keeps swinging after a hit; pet ears/antennas lag; Crew trails behind player |
| Slow in / slow out | Cubic/InOut easing; avoid linear except for snaps | `1 - exp(-k·dt)` smoothing, easing styles, critically damped springs | All camera, pet and UI motion |
| Arcs | Fists, heads and hands travel in arcs; check with onion skin (Moon Animator 2) | Quadratic/cubic Bezier for flying coins, thrown debris, pet hops | Power orbs fly from bag to HUD on an arc |
| Secondary action | Breathing, head bob, cloth/accessory sway | Sine bobbing, IK look-at | Crew pets look at the bag when the player punches |
| Timing | Fast strike (2–3 frames at 30 fps), longer recovery | Durations and spring frequency | See timing table below |
| Exaggeration | Push poses past realistic: bigger wind-up, deeper lean | Bigger shake, scale pops, hit-stop | "Mega punch" every Nth hit |
| Solid drawing → solid posing | Weight shift onto the front foot, no twinning (left/right mirror-identical) | n/a | Idle with asymmetric shoulders |
| Appeal | Clear, bouncy, readable poses; personality idles | Personality via random idle fidgets | Pet idle "blink/hop" variations |

**Suggested starting timings for Hood** (my synthesis from the frame data above, converted to Roblox's 30 fps; tune by feel)
- **Basic punch, ~0.35–0.5 s total:**
  - Anticipation 4–6 f (0.13–0.2 s).
  - Strike 2–3 f (0.07–0.1 s), eased Out.
  - Contact plus hit-stop 0.04–0.09 s.
  - Recovery 5–8 f (0.17–0.27 s), eased InOut.
  - Let a new click cancel the recovery so mashing feels responsive. This mirrors fighting games: short startup, longer recovery.
- **Heavy / "mega" punch:** anticipation 8–12 f (0.27–0.4 s), hit-stop 0.09–0.12 s, larger shake.
- **Idle loop:** 2–4 s breathing cycle with small offsets per limb. No primary source found; this is common practice.
- **Walk:** a 30 fps adaptation of the Survival Kit "on 12s" walk is 15 frames per step (1 s cycle) for a casual walk, 8–10 f per step for a cartoon jog. Cartoony games usually go faster and bouncier.
- **Hit reaction on a target (bag):** fast displacement (2–3 f) followed by a long underdamped settle (0.6–1.2 s).

### Gaps
- I could not open *The Animator's Survival Kit* or Wikipedia directly. Frame counts come from university notes and search summaries.
- I found no Roblox-specific official timing guide for punches or idles. The punch values above are my extrapolation from fighting-game frame data.

---

## 2. Roblox animation tooling and pipeline (editors, API, priorities, markers, default-animation replacement, ownership)

### Takeaway
**Authoring tools:**
- Built-in **Animation Editor** with Curve Editor, IK, events and video capture.
- **Moon Animator 2** (paid plugin: onion skin, graph editor, camera animation).
- **Blender**, importing FBX via the Animation Editor.

**Runtime:** load an `Animation` onto an **`Animator`** (never `Humanoid:LoadAnimation`, which is deprecated). Load once and reuse the `AnimationTrack`. Set `Priority` correctly (Core < Idle < Movement < Action < Action2–4), and drive gameplay from **markers** via `GetMarkerReachedSignal`.

**Two 2025–26 changes matter for Hood:**
1. **R15 player rigs now use `AnimationConstraint` instead of `Motor6D`** by default in new experiences (`StarterPlayer.AvatarJointUpgrade`). Procedural code must multiply into `.Transform` during `PreSimulation`.
2. The new **Animation Graph Editor** can build blend trees driven by `AnimationTrack:SetParameter`.

**Ownership pitfall:** animations must be owned by (or explicitly granted to) the experience's owner. For group games, publish animations **to the group**, or you get "Failed to load animation – sanitized ID".

### Cited Findings
**Playing animations**
- Basic pattern — [Roblox Docs: Use animations](https://create.roblox.com/docs/animation/using):
  1. Ensure the Humanoid has an `Animator`.
  2. Create an `Animation` with an `AnimationId`.
  3. `Animator:LoadAnimation()` → `AnimationTrack`.
  4. `:Play()`.
- Non-humanoid rigs need an `AnimationController` with a child `Animator` — same source.
- `Humanoid:LoadAnimation` "is deprecated in favor of using `Animator:LoadAnimation()` directly" — [Roblox API: Humanoid](https://create.roblox.com/docs/reference/engine/classes/Humanoid)
- **Replication rules for `LoadAnimation`** — [Roblox API: Animator](https://create.roblox.com/docs/reference/engine/classes/Animator):
  - Animations started by a player's client on an Animator inside that player's Character replicate to the server and other clients.
  - Animators **not** in a player character must be loaded and started **on the server** to replicate.
  - An Animator created locally won't replicate tracks at all.
  - The Animator must be in Workspace before calling `LoadAnimation()`, or it errors.
- "Calling `LoadAnimation()` always creates a **new** AnimationTrack… may impact game performance if overused." Use `Animator:GetTrackByAnimationId()` to look up an existing track — [Roblox API: Animator](https://create.roblox.com/docs/reference/engine/classes/Animator)

**AnimationTrack API** — [Roblox API: AnimationTrack](https://create.roblox.com/docs/reference/engine/classes/AnimationTrack)
- **Methods:**
  - `Play(fadeTime=0.1, weight=1, speed=1)` and `Stop(fadeTime=0.1)`.
  - `AdjustWeight(weight=1, fadeTime=0.1)`.
  - `AdjustSpeed(speed=1)`: negative plays backwards, **0 pauses**.
- **Properties and events:**
  - `Looped` (a change takes effect after the current cycle).
  - `TimePosition` (set it after calling Play).
  - `Length` returns **0 until the animation has loaded**.
  - Events: `Stopped` (may still be fading), `Ended` (fully done, back to neutral), `DidLoop`.
- **Blending:** same-priority tracks are blended by weighted average of poses. "In most cases blending animations is not required and using Priority is more suitable."
- **Priority enum** (lowest → highest): Core (Roblox defaults and catalog bundles), Idle (character idles), Movement (walk/run/swim/climb), Action (actions overriding idle and locomotion), Action2, Action3, Action4 — [Roblox API: AnimationPriority](https://create.roblox.com/docs/reference/engine/enums/AnimationPriority); [Animation Editor docs](https://create.roblox.com/docs/animation/editor)
  - The highest priority wins on a given joint. Equal priorities blend by weight — [Roblox API: AnimationTrack](https://create.roblox.com/docs/reference/engine/classes/AnimationTrack)

**Markers (events)**
- `KeyframeReached` "has been superseded by `GetMarkerReachedSignal()`" — [Roblox API: AnimationTrack](https://create.roblox.com/docs/reference/engine/classes/AnimationTrack)
- Markers are added in the Animation Editor's event track (Show Animation Events → Edit Animation Events → + Add Event, optional Parameter string) — [Roblox Docs: Animation events](https://create.roblox.com/docs/animation/events)
- Markers are detected with `track:GetMarkerReachedSignal("FootStep"):Connect(function(paramString) … end)`. One event name can be duplicated at many times on the timeline — same source.

**Replacing default animations**
- Modify the `Animate` script's child Animation objects on the server inside `CharacterAppearanceLoaded`: `animateScript.run.RunAnim`, `walk.WalkAnim`, `jump.JumpAnim`, `idle.Animation1/Animation2`, `fall.FallAnim`, `swim.Swim`, `swimidle.SwimIdle`, `climb.ClimbAnim`. The docs sample first stops all playing tracks — [Roblox Docs: Use animations](https://create.roblox.com/docs/animation/using)
- Idle variants are chosen at random by `Weight.Value`; the probability is weight / total weight — same source.
- For animations that replace default ones, rename the final keyframe to `End` (case-sensitive) before export — [Roblox Docs: Animation Editor](https://create.roblox.com/docs/animation/editor)
- **Roblox's "Cartoony" animation package IDs**, usable directly — [Roblox Docs: Use animations](https://create.roblox.com/docs/animation/using):
  - Run 742638842, Walk 742640026, Jump 742637942
  - Idle 742637544 / 742638445 / 885477856
  - Fall 742637151, Swim 742639220, SwimIdle 742639812, Climb 742636889

**Publishing and ownership**
- Saving stores a `KeyframeSequence` in ServerStorage. You must **Publish to Roblox** to get an asset ID — [Roblox Docs: Animation Editor](https://create.roblox.com/docs/animation/editor)
  - "IMPORTANT – If the animation will be used in any group-owned game, select the group from the **Creator** field."
- Asset privacy: animations have their own creation defaults (the Asset Privacy toggle affects only Images, Decals and Meshes). "Your assets are always accessible to you in your own games" — [Roblox Docs: Asset privacy](https://create.roblox.com/docs/projects/assets/privacy)
  - Creator Dashboard → Development Items → **Animations** → Permissions lets you grant an animation to collaborators (friends or groups) or to specific experiences by **Universe ID**.
  - **Game grants are permanent.**
- **Community reports** (search summaries of DevForum threads):
  - "Failed to load animation with sanitized ID" when animations are uploaded to a personal account but used in a group game. The fix is to re-upload under the group — [DevForum](https://devforum.roblox.com/t/failed-to-load-animation-with-sanitized-id-when-loading-group-owned-animations/3550557); [DevForum](https://devforum.roblox.com/t/failed-to-load-animation-sanitized-id/2814884)
  - Group animations may not play in Studio without the group's "Create and edit community experiences" permission — [DevForum](https://devforum.roblox.com/t/failed-to-load-animation-with-sanitized-id-group-animations/3827277)

**Blender / FBX pipeline**
- Animation Editor → ⋯ → **Import → From File** (.fbx) onto an R15 rig. Convert to a `CurveAnimation` and Publish to get an asset ID (documented for emotes) — [Roblox Docs: Import emotes](https://create.roblox.com/docs/avatar/emotes/import)
- **Adaptive Animation** (`HumanoidRigDescription`) lets custom-proportion characters play any R15 animation — [Roblox Docs: Adaptive Animation](https://create.roblox.com/docs/characters/adaptive-animation)

**Moon Animator 2** (paid plugin by xSIXx; search summaries)
- Keyframe animation for rigs, objects, accessories and **camera**; mirroring and looping; **onion skinning**; R6 and R15; Roblox easing styles plus a graph editor — [Lawod overview](https://www.lawod.com/roblox-moon-animator-the-ultimate-animation-tool-for-roblox-creators/); [GitHub topic moon-animator-2](https://github.com/topics/moon-animator-2)
- Community "Moonlite" is a WIP in-game player for Moon Animator files, useful for cutscenes — [GitHub MaximumADHD/Moonlite](https://github.com/MaximumADHD/Moonlite)

**IK in the editor and at runtime** — [Roblox Docs: Inverse Kinematics](https://create.roblox.com/docs/animation/inverse-kinematics); [Roblox API: IKControl](https://create.roblox.com/docs/reference/engine/classes/IKControl)
- Runtime `IKControl` requires Type, EndEffector, Target and ChainRoot, and must be a child of a Humanoid or AnimationController that has an Animator.
- Types: Transform, Position, Rotation, LookAt.
- Other properties: Weight (0–1), SmoothTime, Pole (bend direction), Priority, Offset/EndEffectorOffset.
- Hinge or BallSocket constraints on R15 rig attachments limit elbows and wrists.

**Animation Graph Editor (new)** — [Roblox Docs: Animation Graph Editor](https://create.roblox.com/docs/animation/graph-editor)
- A node-based editor (Avatar tab → Graph Editor) for blend trees: Clip, Add (base + additive), Select, Priority Select, Sequence, Random Sequence.
- It publishes an `AnimationGraphDefinition` asset that you load like a normal animation.
- At runtime, drive it with `track:SetParameter("humanoidSpeed", speed)`.

**AnimationConstraint (Avatar Joint Upgrade)** — [Roblox API: AnimationConstraint](https://create.roblox.com/docs/reference/engine/classes/AnimationConstraint); [Roblox API: StarterPlayer](https://create.roblox.com/docs/reference/engine/classes/StarterPlayer)
- It is "the replacement for Motor6D in R15 player character rigs". With `StarterPlayer.AvatarJointUpgrade` enabled (the default for new experiences), characters spawn with AnimationConstraints.
- C0/C1/Part0/Part1 are **read-only** aliases.
- `IsA("Motor6D")` returns false. Use `FindFirstChildWhichIsA("AnimationConstraint")` and fall back to Motor6D.
- Procedural layers should multiply into `Transform` during `RunService.PreSimulation`.
- `IsKinematic=false` enables force-based physical joints (ragdoll, "arm strength").

**Animator LOD and throttling**
- `Animator.PreferLodEnabled` (default true) lets the engine reduce animation evaluation for remote characters by distance, screen coverage and frame budget. Set false for important NPCs — [Roblox API: Animator](https://create.roblox.com/docs/reference/engine/classes/Animator)
- `Animator.EvaluationThrottled` tells procedural code to skip offsets on throttled frames — same source.
- `Workspace.ClientAnimatorThrottling` throttles animations of remotely simulated models based on visibility, FPS and number of active animations — [Roblox API: Workspace](https://create.roblox.com/docs/reference/engine/classes/Workspace)

### Inferences
**Pipeline recommendation for Hood**
- Author punches, idles and celebratory emotes in Moon Animator 2 or the built-in editor at 30 fps.
- Publish **to the group that owns Hood**.
- Keep a single `AnimIds` ModuleScript, the code-first approach that matches "built from code".
- Use the Cartoony package IDs above as quick placeholders for locomotion until custom ones exist.

**Code pattern: load once, cache, drive gameplay from markers**

```lua
-- LocalScript (client owns its own character → replicates)
local Players = game:GetService("Players")
local AnimIds = require(game.ReplicatedStorage.Shared.AnimIds)

local function getTrack(animator: Animator, id: string, priority: Enum.AnimationPriority): AnimationTrack
	local existing = animator:GetTrackByAnimationId(id)
	if existing then return existing end
	local anim = Instance.new("Animation")
	anim.AnimationId = id
	local track = animator:LoadAnimation(anim)
	track.Priority = priority
	return track
end

local character = Players.LocalPlayer.Character or Players.LocalPlayer.CharacterAdded:Wait()
local animator = character:WaitForChild("Humanoid"):WaitForChild("Animator") :: Animator
local punchL = getTrack(animator, AnimIds.PunchL, Enum.AnimationPriority.Action)

punchL:GetMarkerReachedSignal("Hit"):Connect(function()
	-- the exact contact frame: fire hit-stop, shake, particles, sound, bag spring, remote
end)
punchL:Play(0.05)  -- short fade-in keeps the wind-up snappy (default 0.1)
```

**Procedural layering after the Avatar Joint Upgrade**
- Don't write `C0` on R15 characters any more. Use the docs' pattern:

```lua
RunService.PreSimulation:Connect(function()
	if not animator.EvaluationThrottled then
		neck.Transform = extraRotation * neck.Transform
	end
end)
```

- For pets and NPC rigs you build yourself, `Motor6D` still works. Same rule: write `.Transform`, not C0, for per-frame offsets.

### Gaps
- I could not open the DevForum "Avatar Joint Upgrade" announcement or the Phase 2 migration post, so I don't know exact rollout dates or edge cases.
- I could not confirm Moon Animator 2's current price or 2026 feature set from its store page. Feature lists come from third-party summaries.
- I didn't verify whether the Animation Graph Editor is still in beta. The docs page has no beta banner.
- The Blender-specific export steps (Roblox Blender plugin) weren't read in detail for animations; only the FBX import path is documented above.

---

## 3. Combat and punch feel: anticipation → impact → recovery, hit-stop, camera shake, particles, flash, sound, knockback, damage numbers

### Takeaway
"Punchy" comes from layering many small feedback signals onto **one exact contact frame**, marked with an animation marker. Fire all of these together, then let springs handle a long, satisfying settle:
- a short hit-stop (≈35–120 ms);
- a brief camera shake (Bump-style: high magnitude, short, smooth fade);
- a burst of impact particles via `:Emit()`;
- a flash or highlight on the bag;
- a crisp sound;
- a bag squash and a spring-driven sway;
- a popping damage number.

### Cited Findings
**Hit-stop**
- Hitstop (hitfreeze/hitlag/hitpause) freezes the attacker and target at the moment of collision. It sells the collision, gives the eyes a few frames to register it, and makes the hit seem more powerful — [critpoints: Hitstop](https://critpoints.net/2017/05/17/hitstophitfreezehitlaghitpausehitshit/); [Sakurai column, Source Gaming](https://sourcegaming.info/2015/11/11/thoughts-on-hitstop-sakurais-famitsu-column-vol-490-1/) (search summary)
- Sakurai (Smash Bros.): both fighters freeze for the same time, and generally "the more damage an attack inflicts, the longer the hitstop". He avoids very long hitstop because it opens chances for third players in free-for-alls — [Source Gaming translation](https://sourcegaming.info/2015/11/11/thoughts-on-hitstop-sakurais-famitsu-column-vol-490-1/) (search summary)
- Suggested durations: **≈35 ms light, 70 ms heavy, 90 ms "perfect"**, capped near **120 ms**. Beyond that it "reads as a dropped frame" — [Sword Arcade guide](https://swordarcade.xyz/guides/game-feel-hitstop-and-screen-shake/) (search summary; secondary blog, not a primary source)

**Vlambeer, "The Art of Screenshake"** (Jan Willem Nijman)
- About 30 small tweaks that make a game feel better, demonstrated in roughly 45 minutes — [Make Games SA thread](https://makegamessa.com/discussion/1537/the-art-of-screenshake-by-flambeer-s-jan-willem-nijman); [Game Developer article](https://www.gamedeveloper.com/design/vlambeer-co-founder-shares-advice-on-building-better-action-games) (search summary)
- The tweaks include:
  - shake the screen opposite the direction of fire;
  - a short "sleep"/freeze when a hit lands;
  - **different shake magnitudes** (small for routine actions, large for real events);
  - random flourishes such as enemies sometimes exploding harmlessly on death.
- **Conflict:** one summary claims the freeze is "about 0.2 seconds". That is longer than the 35–120 ms guidance above and I could not verify it from the talk itself — [bluetengu experiments](https://www.bluetengu.com/2014/12/12/art-of-screenshake-experiments/) (search summary)

**"Juice it or lose it"** (Martin Jonasson & Petri Purho, GDC Europe 2012)
- A "juicy" game "feels alive and responds to everything you do – tons of cascading action and response for minimal user input". They live-upgrade a Breakout clone with tweening, sound, explosions and screen shake — [GDC Vault](https://www.gdcvault.com/play/1016487/Juice-It-or-Lose); [roblog summary](https://roblog.co.uk/2024/03/juicy-games/) (search summary)
- Counterpoint talk: too much juice can hurt immersion — [Game Developer](https://www.gamedeveloper.com/design/video-indies-resist-the-urge-to-juice-it-or-lose-it-) (search summary)

**Camera shake modules**
- **RbxCameraShaker** (Sleitnick) is a Roblox port of Unity's EZ Camera Shake. Constructor: `CameraShaker.new(renderPriority, callback)`, e.g. priority `Enum.RenderPriority.Camera.Value + 1` — [GitHub Sleitnick/RbxCameraShaker](https://github.com/Sleitnick/RbxCameraShaker)
  - Presets use `CameraShakeInstance.new(magnitude, roughness, fadeIn, fadeOut)`:

    | Preset | magnitude | roughness | fadeIn | fadeOut | posInfluence | rotInfluence | Notes |
    |---|---|---|---|---|---|---|---|
    | **Bump** | 2.5 | 4 | 0.1 | 0.75 | 0.15 | (1,1,1) | "high-magnitude, short, yet smooth" |
    | **Explosion** | 5 | 10 | 0 | 1.5 | 0.25 | (4,1,1) | |
    | **Vibration** | 0.4 | 20 | 2 | 2 | | | sustained |

    Source: [CameraShakePresets.lua](https://github.com/Sleitnick/RbxCameraShaker/blob/master/src/CameraShaker/CameraShakePresets.lua)
- **RbxUtil `Shake`** (Sleitnick) is a newer noise-based shaker — [GitHub RbxUtil/modules/shake](https://github.com/Sleitnick/RbxUtil/blob/main/modules/shake/init.luau)
  - Fields: Amplitude, Frequency (smaller = faster), FadeInTime, FadeOutTime, SustainTime, Sustain, PositionInfluence, RotationInfluence.
  - `shake:BindToRenderStep(Shake.NextRenderName(), Enum.RenderPriority.Last.Value, fn)`.
  - Its docs warn about **camera drift** with Roblox's default camera scripts. Fix: store the camera CFrame before applying the shake and restore it on Heartbeat.

**Impact particles** — [Roblox Docs: Create explosions with VFX](https://create.roblox.com/docs/tutorials/use-case-tutorials/vfx/use-particles-for-explosions)
- Official burst recipe: **Enabled = false**, Drag 10, Lifetime 0.2–0.6, Speed 20–40, SpreadAngle (180, 180), Color gradient, Transparency curve fading out, then `emitter:Emit(100)` from script.
- Roblox's Emit() plugin lets you preview bursts in Studio.

**Knockback on bags: physics movers**
- Legacy BodyMovers are **deprecated**. `BodyPosition`→`AlignPosition`, `BodyGyro`→`AlignOrientation`, `BodyVelocity`→`LinearVelocity`, `BodyForce/BodyThrust`→`VectorForce` — [Roblox Docs: Mover constraints – legacy conversion](https://create.roblox.com/docs/physics/mover-constraints#legacy-mover-conversion); [Roblox API: BodyPosition](https://create.roblox.com/docs/reference/engine/classes/BodyPosition)

**Damage numbers** (search summaries)
- Common DevForum pattern: spawn a BillboardGui with a TextLabel at the target and randomise `StudsOffset`. Tween it up 3–4 studs over about 0.8 s while fading `TextTransparency` 0→1, then destroy it. Do it client-side — [DevForum: damage indication tutorial](https://devforum.roblox.com/t/how-to-implement-a-damage-indication-system/483161); [DevForum: client-side damage indicator](https://devforum.roblox.com/t/client-side-damage-counterindicator/3401455)

**Highlights for hit flashes**
- `Highlight` is an outline-plus-fill overlay — [Roblox API: Highlight](https://create.roblox.com/docs/reference/engine/classes/Highlight)
- Only **255** may display at once on a client. Disabled Highlights still occupy a slot, so delete them rather than disable — same source.

### Inferences
**Hood punch "impact frame" recipe** (all client-side visuals; the server only validates and awards Power)
1. **Input:** play the punch track at once (`Play(0.05)`) for zero perceived latency. Send the `RemoteEvent` on the "Hit" marker, or at input with server rate-limiting.
2. **"Hit" marker reached (t = 0):**
   - **Hit-stop:** `track:AdjustSpeed(0)` for 0.04–0.06 s (normal) or 0.09–0.12 s (crit/mega), then restore speed. Freeze the bag's spring too.
   - **Bag:** instant squash (scale X/Z ×1.12, Y ×0.88), recover with an underdamped spring (damping ≈0.35, frequency ≈3–4 Hz). Add a rotation impulse away from the player.
   - **Particles:**
     - `sparks:Emit(8–15)` using the burst recipe, scaled down;
     - one `ring:Emit(1)` (Speed 0, Size 0→6, Transparency 0→1, Lifetime 0.2–0.3, LightEmission 1);
     - optional `dust:Emit(4)`.
   - **Flash:** add a `Highlight` (FillColor white, FillTransparency 0.3 → 1 over 0.1 s), then **Destroy** it.
   - **Camera:** Bump-like shake scaled by punch tier. Normal ≈ Amplitude 0.3–0.6 with fast fade; mega ≈ Explosion-like. Optional FOV kick +3–5° springing back.
   - **Sound:** play on the same frame. Small random pitch variation (0.95–1.05) prevents repetition fatigue.
   - **Number:** "+123 Power" pops with scale overshoot (EasingStyle.Back Out, 0.15 s), drifts up 2–4 studs over 0.6–0.8 s, then fades. Colour or scale it by size.
3. **Recovery:** the punch track finishes. The bag keeps swinging for 0.6–1.2 s (follow-through). Pets react (look-at via IKControl, small hop).

**Hit-stop helper**

```lua
local function hitStop(tracks: {AnimationTrack}, duration: number)
	local saved = {}
	for i, tr in tracks do
		saved[i] = tr.Speed
		tr:AdjustSpeed(0)
	end
	task.delay(duration, function()
		for i, tr in tracks do
			if tr.IsPlaying then tr:AdjustSpeed(saved[i]) end
		end
	end)
end
```

**Bag sway: physics vs procedural**
- Procedural client-side springs are deterministic, cheap and never desync; use them for training bags.
- Physics (an unanchored bag on a `RopeConstraint` / `BallSocketConstraint`, plus an impulse) looks great but replicates, can be flung by exploiters if client-owned, and costs simulation. Reserve it for one-off destruction.

**Procedural bag sway**

```lua
-- bag model's WorldPivot is set at the chain/hook point (top), so rotation swings from the top
local base = bag:GetPivot()
local angle, vel = Vector3.zero, Vector3.zero    -- x/z tilt in radians
local FREQ, DAMP = 2.5, 0.3                      -- Hz, damping ratio (underdamped = swings)

local function hit(dirWorld: Vector3, strength: number)
	local localDir = base:VectorToObjectSpace(dirWorld)
	vel += Vector3.new(localDir.Z, 0, -localDir.X) * strength   -- angular impulse
end

RunService.PreRender:Connect(function(dt)
	local w = 2 * math.pi * FREQ
	local acc = -w * w * angle - 2 * DAMP * w * vel
	vel += acc * dt                      -- semi-implicit Euler (stable for small dt)
	angle += vel * dt
	bag:PivotTo(base * CFrame.Angles(angle.X, 0, angle.Z))
end)
```

### Gaps
- No primary source confirmed Vlambeer's exact sleep duration. The 0.2 s claim conflicts with the 35–120 ms guidance.
- I couldn't access full DevForum camera-shake or damage-number threads, only summaries.
- No published A/B data shows how much juice improves Roblox retention specifically.

---

## 4. Procedural animation in code: springs, frame-rate-independent smoothing, sine, Bezier, tweening models, RunService events, IKControl, Transform, AnimationController

### Takeaway
**Which smoothing tool to use:**
- **Critically damped motion** (cameras, pets, UI that must not overshoot): `lerp(a, b, 1 - exp(-k·dt))`, or the built-in `TweenService:SmoothDamp`.
- **Underdamped springs** (wobble/"pop": bags, pets landing, UI bounce): Fraktality's `spr`, Quenty's `Spring`, or a few lines of custom spring code.

**Which RunService event to use:**
- `PreRender` (replaces RenderStepped): client visuals.
- `PreAnimation`: tweak animation tracks.
- `PreSimulation` (replaces Stepped): `.Transform` layering and physics inputs.
- `PostSimulation` / `Heartbeat`: after physics.

**Moving things:**
- Models: `PivotTo` or `BulkMoveTo`. `SetPrimaryPartCFrame` is superseded.
- Look/aim: `IKControl`.
- Non-humanoid rigs: `AnimationController + Animator`.

### Cited Findings
**Frame-rate-independent smoothing**
- `current = lerp(current, target, 1 - exp(-decay * dt))`, equivalently `(a - b) * exp(-decay*dt) + b`. Naive `lerp(a, b, 0.1)` each frame is framerate-dependent — [Freya Holmér, "Lerp smoothing is broken" (Guadalindie 2024)](https://www.classcentral.com/course/youtube-lerp-smoothing-is-broken-a-journey-of-decay-and-delta-time-293974); [Freya Holmér thread](https://x.com/FreyaHolmer/status/1757836988495847568); [Frame-rate independent damping using lerp](https://blog.rainbowmaker.co.kr/game/2019/04/04/smooth-follow-damping.html) (search summaries)
- Old lerp factors can be converted to a **half-life** that behaves the same at any framerate — same sources.

**Built-in tweening and smoothing** — [Roblox API: TweenService](https://create.roblox.com/docs/reference/engine/classes/TweenService)
- **`TweenService:SmoothDamp(current, target, velocity, smoothTime, maxSpeed?, dt?)`** "simulat[es] a critically damped spring" and returns `(newValue, newVelocity)`. Supports number, Vector2, Vector3, CFrame. You must feed velocity back in each call.
- `TweenService:GetValue(alpha, style, direction)` gives eased alphas for custom interpolation.
- Tweens can interpolate number, bool, CFrame, Rect, Color3, UDim, UDim2, Vector2, Vector3, EnumItem. Two tweens on the same property → the earlier one is cancelled.
- Easing styles: Linear, Sine, Back, Quad, Quart, Quint, Bounce, Elastic, Exponential, Circular, Cubic — [Roblox API: EasingStyle](https://create.roblox.com/docs/reference/engine/enums/EasingStyle)

**spr (Fraktality)** — [GitHub Fraktality/spr](https://github.com/Fraktality/spr)
- `spr.target(instance, dampingRatio, frequency, {Prop = goal})`.
  - Damping < 1 overshoots ("extra pop"); = 1 is critical ("visually neutral"); > 1 is overdamped.
  - Examples: `(1, 1)` slow, no overshoot; `(0.6, 4)` quick with overshoot and wobble.
- Also `spr.completed(obj, cb)` and `spr.stop(obj, prop?)`.
- Animates CFrame, Color3 (in CIELUV), UDim2, Vector3, NumberRange, ColorSequence and more directly on properties.

**Quenty Spring** (NevermoreEngine) — [GitHub Quenty/NevermoreEngine Spring.lua](https://github.com/Quenty/NevermoreEngine/blob/main/src/spring/src/Shared/Spring.lua)
- Lazy analytic spring: `Spring.new(initial)`, with `.Target`, `.Position`, `.Velocity`, `.Damper`, `.Speed`, `:Impulse(v)`, `:TimeSkip(dt)`, `:SetTarget(v, doNotAnimate)`.
- Evaluated in closed form for under-, critically and over-damped cases. Works for number, Vector3 and other types that support +, − and scalar ×.

**RunService frame events** — [Roblox API: RunService](https://create.roblox.com/docs/reference/engine/classes/RunService)
- `PreRender` "(replacement for RenderStepped)": client-only, before the frame is drawn. Use it "sparingly", because rendering waits on it.
- `PreAnimation`: before animations are stepped; useful for adjusting track speed or priority.
- `PreSimulation` "(replacement for Stepped)": before physics.
- `PostSimulation`: after physics.
- `Heartbeat`: end of frame, when `task` resumptions run.
- `RenderStepped` and `Stepped` carry migration notes saying they are superseded.
- `BindToRenderStep(name, priority, fn)`: client-only, ordered by priority. Defaults: Input = 100, Camera = 200, Character = 300, Last = 2000. Use `Enum.RenderPriority.Camera.Value + 1` to run after the camera script — [Roblox API: RenderPriority](https://create.roblox.com/docs/reference/engine/enums/RenderPriority)

**Motor6D.Transform** — [Roblox API: Motor6D](https://create.roblox.com/docs/reference/engine/classes/Motor6D)
- Recommended for custom animation instead of C0/C1.
- It is applied as a batch after `PreSimulation`, which is "much more efficient than many immediate updates".
- If an Animator is present, it overwrites Transform each frame after `PreAnimation`.
- On new R15 avatars the equivalent is `AnimationConstraint.Transform` — [Roblox API: AnimationConstraint](https://create.roblox.com/docs/reference/engine/classes/AnimationConstraint)

**Moving models**
- `Model:SetPrimaryPartCFrame` "has been superseded by `PVInstance:PivotTo()` which acts as a more performant replacement" — [Roblox API: Model](https://create.roblox.com/docs/reference/engine/classes/Model); [Roblox API: PVInstance](https://create.roblox.com/docs/reference/engine/classes/PVInstance)
- `Model:ScaleTo()` scales the whole model uniformly — [Roblox API: Model](https://create.roblox.com/docs/reference/engine/classes/Model)
- `Workspace:BulkMoveTo(parts, cframes, Enum.BulkMoveMode.FireCFrameChanged)` is "a very fast way to move large numbers of parts" — [Roblox API: WorldRoot](https://create.roblox.com/docs/reference/engine/classes/WorldRoot)

**IKControl**
- Types: LookAt (orient the chain so the end effector's forward axis points at the target), Position, Rotation, Transform — [Roblox API: IKControlType](https://create.roblox.com/docs/reference/engine/enums/IKControlType)
- `SmoothTime` is the average seconds to reach the target. `Weight` is 0–1 — [Roblox API: IKControl](https://create.roblox.com/docs/reference/engine/classes/IKControl)
- Uses: head and torso look-at, foot placement on terrain, hands on grips — same source.

**AnimationController for non-humanoid rigs**
- `AnimationController` + `Animator`, for pets, bags or trains that use keyframed clips — [Roblox Docs: Use animations](https://create.roblox.com/docs/animation/using)

### Inferences
**Code snippets** (Luau, untested synthesis)

**1. Frame-rate-independent smoothing** (works with number/Vector3/CFrame via `:Lerp`)

```lua
local function expAlpha(speed: number, dt: number): number   -- speed ≈ 1/time-constant
	return 1 - math.exp(-speed * dt)
end
local function halfLifeAlpha(halfLife: number, dt: number): number
	return 1 - 2 ^ (-dt / halfLife)                         -- reaches 50% in halfLife seconds
end
-- camera/pet follow: cf = cf:Lerp(goal, expAlpha(10, dt))   -- ~10 = snappy, ~4 = floaty
```

**2. Minimal custom spring** (frequency f in Hz, damping ratio z). Works for number or Vector3. Substep if `dt > 1/30`.

```lua
local function springStep(x, v, target, f: number, z: number, dt: number)
	local w = 2 * math.pi * f
	v += (w * w * (target - x) - 2 * z * w * v) * dt
	x += v * dt
	return x, v
end
-- presets: UI pop f=4,z=0.5 | pet follow f=2,z=1 | bag wobble f=2.5,z=0.3 | squash recover f=5,z=0.4
```

**3. Built-in critically damped follow**

```lua
local pos, vel = petPos, Vector3.zero
RunService.PreRender:Connect(function(dt)
	pos, vel = TweenService:SmoothDamp(pos, goalPos, vel, 0.15, nil, dt)
end)
```

**4. Sine bob plus slow spin** for collectibles and pets (phase-offset per object so they don't sync)

```lua
local t = os.clock()
local bob = math.sin(t * 2 * math.pi * 0.8 + phase) * 0.3       -- 0.8 Hz, ±0.3 studs
local spin = CFrame.Angles(0, t * math.rad(90), 0)               -- 90°/s
part.CFrame = baseCF * CFrame.new(0, bob, 0) * spin
```

**5. Quadratic Bezier arc** (flying Power orbs, coin to HUD, debris arcs)

```lua
local function bezier2(p0: Vector3, p1: Vector3, p2: Vector3, t: number): Vector3
	local a, b = p0:Lerp(p1, t), p1:Lerp(p2, t)
	return a:Lerp(b, t)
end
-- control point: midpoint lifted up, e.g. p1 = (p0+p2)/2 + Vector3.yAxis * 6; ease t with TweenService:GetValue
```

**6. Tween a whole Model** (Models have no tweenable CFrame property; drive `PivotTo` from a `CFrameValue`)

```lua
local cfv = Instance.new("CFrameValue")
cfv.Value = model:GetPivot()
cfv.Changed:Connect(function(v) model:PivotTo(v) end)
local tw = TweenService:Create(cfv, TweenInfo.new(0.6, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Value = goalCF})
tw.Completed:Once(function() cfv:Destroy() end)
tw:Play()
```

- For single anchored parts, tween `CFrame` directly.
- For a door, a simpler option is an anchored root part with the rest welded (WeldConstraints) or `PivotTo`.

**7. IK look-at** so the player's head and torso face the bag while punching (client-side, own character)

```lua
local ik = Instance.new("IKControl")
ik.Type = Enum.IKControlType.LookAt
ik.ChainRoot = character:WaitForChild("UpperTorso")
ik.EndEffector = character:WaitForChild("Head")
ik.Target = bag.PrimaryPart          -- or an Attachment on the bag
ik.SmoothTime = 0.12
ik.Weight = 0.0                      -- fade to 0.6 when near a bag
ik.Parent = character.Humanoid       -- must be under Humanoid/AnimationController with Animator
```

**Event choice for Hood**
- Pets, collectibles, camera effects, damage numbers → `PreRender` (or `BindToRenderStep` after Camera for shakes).
- Joint layering → `PreSimulation`.
- Track speed/priority tweaks → `PreAnimation`.
- Server game logic → `Heartbeat`.

### Gaps
- I couldn't read Freya Holmér's talk in full. The formula is consistent across several summaries and matches standard math.
- No benchmark compares spr, Quenty Spring, SmoothDamp and custom springs on Roblox.
- I didn't verify whether TweenService tweens on `Model.WorldPivot` move parts. The CFrameValue pattern is the widely used workaround, but I couldn't open the DevForum discussions behind it.

---

## 5. Pets / companions ("Crew"): following, formations, bobbing/hopping, constraints vs CFrame, client rendering, rarity effects

### Takeaway
The consensus approach for simulator pets:
- **Server** stores only *which* pets are equipped (attributes or replicated data).
- **Each client renders all pets locally:** anchored, CanCollide/CanQuery/CanTouch off, CastShadow off.
- Pets sit in formation slots behind the owner. A single `PreRender` loop moves them with exponential smoothing plus a sine bob (flying) or a hop arc (walking), using `BulkMoveTo`.
- Distance culling and a "hide others' pets" setting protect low-end devices.

AlignPosition/AlignOrientation (physics) works but adds network-ownership complexity; CFrame-per-frame on the client is simpler and smoother.

### Cited Findings
**Client-side rendering** (DevForum, search summaries)
- "If you want the pet movement smooth, you have to do it on the client"; client rendering isn't affected by server lag — [DevForum: Render pets on the client or server?](https://devforum.roblox.com/t/render-pets-on-the-client-or-server/442739); [DevForum: Making a smooth pet system](https://devforum.roblox.com/t/making-a-smooth-pet-system/336830)
- Pets are cited as the biggest performance bottleneck in pet simulators because each client renders everyone's pets. One optimization is a setting to hide other players' pets — [DevForum: Pet follow module (Simulator style)](https://devforum.roblox.com/t/pet-follow-module-simulator-style/901913)
- Advice: avoid more than about 300 pets loaded at once, and disable **CastShadow** on pets — same thread.
- An alternative used by some systems: physics movers with **network ownership given to the owning client** — [DevForum: Creating a reliable Pet / follow system](https://devforum.roblox.com/t/creating-a-reliable-pet-follow-system/365380)

**Common follow math** (DevForum, search summaries)
- Ring or semicircle slots via `math.cos/math.sin(angle) * radius`, with `angle = index * anglePerPet` — [DevForum: semi-circle formation](https://devforum.roblox.com/t/how-i-could-make-pets-file-into-a-semi-circle-formation/1740980); [DevForum: Pet Follow System](https://devforum.roblox.com/t/pet-follow-system/2952612)
- Walk/hover bobbing with `math.sin(time() * freq)` — [DevForum: Pet Follow System](https://devforum.roblox.com/t/pet-follow-system/2952612)
- Movement via `pet:GetPivot():Lerp(target, 0.1)` on RenderStepped. Note: that fixed 0.1 factor is framerate-dependent; see Section 4 — [DevForum: Pet Follow System](https://devforum.roblox.com/t/pet-follow-system/2952612); [DevForum: Calculating the Y offset](https://devforum.roblox.com/t/calculating-the-y-offset-for-a-pet-following-system/1393896)

**Engine facts that apply**
- `BodyPosition`/`BodyGyro` are deprecated; use `AlignPosition`/`AlignOrientation` if going physics-based — [Roblox Docs: legacy mover conversion](https://create.roblox.com/docs/physics/mover-constraints#legacy-mover-conversion)
- `BulkMoveTo` moves many parts cheaply — [Roblox API: WorldRoot](https://create.roblox.com/docs/reference/engine/classes/WorldRoot)
- Rigged pets with keyframed clips need an `AnimationController` + `Animator`. A non-character Animator's animations must be started on the server to replicate. Client-only pets can just play animations locally, since replication isn't needed — [Roblox API: Animator](https://create.roblox.com/docs/reference/engine/classes/Animator)
- `IKControl` LookAt can make a pet's head look at the bag or player — [Roblox API: IKControl](https://create.roblox.com/docs/reference/engine/classes/IKControl)
- Highlight outlines are capped at 255 visible per client — [Roblox API: Highlight](https://create.roblox.com/docs/reference/engine/classes/Highlight)
- Particle Rate is capped at 400/s per emitter (100/s on mobile) — [Roblox Docs: Particle emitters](https://create.roblox.com/docs/effects/particle-emitters)

### Inferences
**Recommended Crew architecture**
- **Server:** `player:SetAttribute("EquippedCrew", "id1,id2,id3")` or a replicated folder of string values. The server never moves pets.
- **Client (one `PetRenderer` module):**
  - Clones pet models from ReplicatedStorage for *every* player in range.
  - Prepares each part: Anchored = true; CanCollide, CanQuery, CanTouch = false; CastShadow = false; Massless; welded to one root part.

**Single update loop** (synthesis)

```lua
local RunService = game:GetService("RunService")
local SLOT_RADIUS, BACK = 4, 3
local parts, cfs = {}, {}

RunService.PreRender:Connect(function(dt)
	table.clear(parts); table.clear(cfs)
	local camPos = workspace.CurrentCamera.CFrame.Position
	local t = os.clock()
	for _, owner in activeOwners do                 -- owners with pets, nearest first
		local root = owner.rootPart
		if not root or (root.Position - camPos).Magnitude > 200 then continue end   -- cull
		local n = #owner.pets
		local speed = root.AssemblyLinearVelocity.Magnitude
		for i, pet in owner.pets do
			-- semicircle behind player
			local a = math.pi * (i / (n + 1))
			local slot = Vector3.new(math.cos(a) * SLOT_RADIUS, 0, BACK + math.sin(a) * 1.5)
			local goal = root.CFrame * CFrame.new(slot)
			pet.cf = pet.cf:Lerp(goal, 1 - math.exp(-8 * dt))   -- smooth follow
			local y
			if pet.flying then
				y = 2 + math.sin(t * 3 + i) * 0.35                  -- hover bob
			elseif speed > 1 then
				y = math.abs(math.sin(t * 9 + i)) * 0.8             -- hop while walking
			else
				y = math.abs(math.sin(t * 2 + i)) * 0.15            -- idle mini-hop
			end
			table.insert(parts, pet.root)
			table.insert(cfs, pet.cf * CFrame.new(0, y, 0))
		end
	end
	workspace:BulkMoveTo(parts, cfs, Enum.BulkMoveMode.FireCFrameChanged)
end)
```

**Polish**
- **Ground snapping:** raycast down from the slot for walkers, so pets don't float on stairs or slopes.
- **Facing:** face movement direction when moving (`CFrame.lookAt(pos, pos + velocityFlat)`); face the camera or player when idle.
- **Hop squash** (single-MeshPart pets only): at landing (sine crosses 0), set Size to (1.12, 0.85, 1.12) × base and spring back to 1. Small exaggeration gives a lot of appeal.
- **Reactions:** on the player's punch "Hit" marker, nearby Crew do a quick cheer hop (+0.6 stud, 0.25 s) and a look-at.

**Rarity effects** (cost increases with rarity)

| Rarity | Effect |
|---|---|
| Common | None |
| Rare | Subtle sparkle emitter, Rate 2–4/s, LightEmission 1 |
| Epic | Colored aura ring + Trail |
| Legendary | Highlight outline (watch the 255 cap; only own pets or nearest N) + ground aura + flipbook particles |
| Mythic | Beam halo + periodic `Emit` bursts |

**Device scaling**
- Cap total rendered pets (e.g., 150–300).
- Reduce effects on others' pets (no Highlights, lower particle Rate).
- Respect a "Hide others' Crew" toggle.

### Gaps
- DevForum threads were seen only as summaries. The "≈300 pets" figure is one community member's advice, not a Roblox benchmark.
- I found no official Roblox guidance on pet systems specifically.

---

## 6. World animation: collectibles, conveyors/train, doors, collapsing walls/stages, shine, animated textures, performance with many objects

### Takeaway
Run decorative motion on the **client**: bobbing pickups, spinning signs, shine sweeps, train wheels.
- Tag objects with CollectionService and drive them from one `PreRender` loop with `BulkMoveTo`, culled by distance.
- Use TweenService (client) for one-off doors and reveals.
- Breakable walls/stages: swap the intact wall for **pre-fractured chunks** (a few big pieces, not hundreds), unanchor them, add an impulse, then clean up with `Debris:AddItem` (or fade first).
- Moving trains/platforms that players stand on need physics-aware movement: constraints or server-owned movers rather than client-only CFrame.

### Cited Findings
**Moving parts efficiently**
- `BulkMoveTo` is the fast path for moving many parts; `PivotTo` replaces `SetPrimaryPartCFrame` — [Roblox API: WorldRoot](https://create.roblox.com/docs/reference/engine/classes/WorldRoot); [Roblox API: Model](https://create.roblox.com/docs/reference/engine/classes/Model)
- `PreRender` is client-only, for visual updates before rendering; keep its work light — [Roblox API: RunService](https://create.roblox.com/docs/reference/engine/classes/RunService)

**Tween on the client, not the server** — [Roblox Docs: Improve performance (replication)](https://create.roblox.com/docs/performance-optimization/improve)
- "If TweenService is used to tween an object server side, the tweened property is replicated to each client every frame." This makes tweens "jittery as clients' latency fluctuates" and "causes a lot of unnecessary network traffic".
- The same page says animation data saved by Animation Editor plugins inside rigs (the AnimSaves folder) causes needless replication when those rigs are cloned. Clean up animation metadata after importing.

**Debris cleanup** — [Roblox API: Debris](https://create.roblox.com/docs/reference/engine/classes/Debris)
- `Debris:AddItem(brick, 3)` schedules destruction without yielding, and survives the script being destroyed. The docs use "a wall being smashed into individual bricks" as the example.
- **Hardcoded maximum of 1,000 items**: when exceeded, the oldest are destroyed instantly.
- `task.delay(3, brick.Destroy, brick)` is the alternative, but it won't run if the script is destroyed.

**Destruction approaches** (DevForum and blog summaries)
- Pre-make fragment shapes. When broken, destroy the wall and spawn fragments in place, unanchored, with forces to fling them — [DevForum: Breaking Walls Effect](https://devforum.roblox.com/t/breaking-walls-effect/680293); [DevForum: How to break a wall?](https://devforum.roblox.com/t/how-to-break-a-wall/1310896)
- Optimization: break into **4–5 big jagged chunks** rather than every brick being a physics object — [roblox-destruction-script blog](https://roblox-destruction-script.pages.dev/posts/roblox-destruction-script/) (low-authority blog; consistent with DevForum advice)

**Effects for world shine and motion**
- `Trail.Lifetime`: shorter = shorter, faster-looking trail (0.5 vs 3.0 s compared in docs). Trails need two attachments; `FaceCamera` keeps them visible — [Roblox Docs: Trails](https://create.roblox.com/docs/effects/trails)
- Beams draw a textured strip between two attachments along a cubic Bezier (CurveSize0/1) with Segments and FaceCamera, and can scroll their texture — [Roblox Docs: Beams](https://create.roblox.com/docs/effects/beams)
  - Good for animated neon strips, conveyor arrows, train-track glows. The texture-scroll property (`TextureSpeed`) is from my prior knowledge of the Beam API; I did not pull it from the docs this session.

### Inferences
**Client "world animator" module**

```lua
local CollectionService = game:GetService("CollectionService")
local spinners = {}  -- {part=BasePart, base=CFrame, phase=number}
local function add(p: BasePart) table.insert(spinners, {part = p, base = p.CFrame, phase = math.random() * 6.28}) end
for _, p in CollectionService:GetTagged("Spinner") do add(p) end
CollectionService:GetInstanceAddedSignal("Spinner"):Connect(add)
-- (also handle GetInstanceRemovedSignal to remove entries)

local parts, cfs = {}, {}
RunService.PreRender:Connect(function()
	table.clear(parts); table.clear(cfs)
	local cam = workspace.CurrentCamera.CFrame.Position
	local t = os.clock()
	for _, s in spinners do
		if (s.base.Position - cam).Magnitude < 150 then
			table.insert(parts, s.part)
			table.insert(cfs, s.base * CFrame.new(0, math.sin(t * 2 + s.phase) * 0.4, 0)
				* CFrame.Angles(0, t * 1.5 + s.phase, 0))
		end
	end
	workspace:BulkMoveTo(parts, cfs, Enum.BulkMoveMode.FireCFrameChanged)
end)
```

**Doors and gates**
- Client-side `TweenService` on the hinge part's CFrame (or the CFrameValue → PivotTo pattern).
- Open with EasingStyle.Back Out (0.4–0.6 s) for a cartoony overshoot; close with Quad In.

**Breakable stage walls** (Hood's "break walls/stages")
1. **Anticipation:** on the final hit, shake the wall (local spring offset) for 0.15–0.3 s, add a crack decal or flash, and play a crunch sound.
2. **Swap:** hide the intact wall (or `Transparency = 1` + CanCollide off) and spawn 4–8 pre-cut chunk parts at matching CFrames.
3. **Burst:**
   - Unanchor chunks.
   - Apply `AssemblyLinearVelocity = outward * random(20, 40) + up * random(10, 25)` and some angular velocity.
   - Dust burst `Emit(30)` plus debris-chip particles.
   - Big camera shake (Explosion-like, scaled).
4. **Cleanup:** after 2–4 s, fade chunk Transparency over 0.5 s with a tween, then `Debris:AddItem(chunk, 0.6)`.
5. **Do it client-side if the wall is per-player progression.** Each player's stage state differs, so render destruction locally. Only the server's "stage unlocked" state matters.
6. Restore the intact wall for others / on reset.

**Train**
- If players ride it, move it on the server with physics-friendly methods so riders are carried correctly: e.g., an anchored model moved by `PivotTo` along a path each Heartbeat, or a `PrismaticConstraint` / `AlignPosition` rig.
- Then add purely visual client extras: wheel rotation, steam particles, a slight sine "rock" on carriages.
- **Caution:** moving anchored parts by CFrame does not automatically carry standing characters with correct friction in all cases. Test this.

**Animated neon/textures**
- Scroll Beam textures; tween `Color` / `Transparency` of Neon parts (client), or `spr.target(part, 1, 0.5, {Color = ...})` for smooth color pulses.
- Use flipbook particles for animated signage glows.

### Gaps
- I didn't find an official Roblox doc on moving platforms carrying characters (anchored-CFrame vs constraints), so the train advice is partly inference.
- No benchmark numbers for how many client-tweened objects are "too many". Rely on the MicroProfiler in testing.

---

## 7. VFX: ParticleEmitter essentials, Beams, Trails, Attachments, Highlight, flipbooks, stylized recipes, and where to learn

### Takeaway
Most stylized Roblox VFX are **short-lived `ParticleEmitter:Emit(n)` bursts**, layered from a few emitters on one Attachment:
- a core flash;
- a shockwave ring;
- sparks or streaks;
- dust.

Plus Beams/Trails for swooshes, and Highlights for flashes and outlines.

Key properties:
- **Transparency** fade-in/out (the docs call it "one of the most vital").
- **Size** NumberSequence.
- **LightEmission** = 1 (additive glow).
- **Drag** (fast-out-then-stop).
- **SpreadAngle**.
- **Squash** (stretch along motion).
- **Flipbooks** (2×2 / 4×4 / 8×8, up to a 1024² sheet).

Keep particle counts and screen size modest: fill-rate and overdraw are the main GPU costs, especially on mobile.

### Cited Findings
**Emitter basics** — [Roblox API: ParticleEmitter](https://create.roblox.com/docs/reference/engine/classes/ParticleEmitter)
- Parent to a BasePart (spawns within its volume or shape) or an Attachment (spawns at that point).
- Emits automatically when `Enabled` and `Rate > 0`, or manually via `:Emit(n)`.
- `:Clear()` removes all emitted particles.
- `TimeScale` (0–1) slows the effect: useful for slow-motion and hit-stop on VFX.

**Property behaviour** — [Roblox Docs: Particle emitters](https://create.roblox.com/docs/effects/particle-emitters) unless noted

| Property | What the docs say |
|---|---|
| `LightEmission` | 0 = normal blending, 1 = **additive** blending (glow) |
| `Transparency` | "One of the most vital properties": fading near start and/or end of life avoids popping |
| `Lifetime` | Min/max range per particle; hard cap 20 s |
| `Rate` | Max **400/s per emitter (100/s on mobile)** |
| `Speed` | Min/max studs/s at emission; changing it doesn't affect live particles |
| `Drag`, `Acceleration`, `VelocityInheritance` | Shape motion over lifetime. Drag = "rate at which particles will lose half their speed through exponential decay" ([API](https://create.roblox.com/docs/reference/engine/classes/ParticleEmitter)) |
| `SpreadAngle` | X/Y degrees around the emission direction |
| `Squash` | Non-uniform scaling over lifetime: > 0 = thinner and taller, < 0 = wider and shorter |
| `Orientation` | FacingCamera, FacingCameraWorldUp, VelocityParallel, VelocityPerpendicular ([Roblox API: ParticleOrientation](https://create.roblox.com/docs/reference/engine/enums/ParticleOrientation)) |
| `Shape`, `ShapeInOut`, `ShapeStyle`, `ShapePartial` | Box/sphere/cylinder/disc emission, outward/inward, volume/surface |
| `LockedToPart` | Particles move rigidly with the emitter |
| `ZOffset` | Render ordering |
| `WindAffectsDrag` | Follows `Workspace.GlobalWind` |
| `VelocitySpread` | **Superseded** by `SpreadAngle` ([API](https://create.roblox.com/docs/reference/engine/classes/ParticleEmitter)) |

**Flipbooks** — [Roblox Docs: Particle emitters](https://create.roblox.com/docs/effects/particle-emitters)
- `FlipbookLayout`: None, Grid2x2, Grid4x4, Grid8x8, Custom (`FlipbookSizeX/Y`).
- Example: a 1024×1024 sheet at 8×8 gives 64 frames. Include transparent spacing between frames for mip filtering.
- `FlipbookMode`: Loop, OneShot (spans the lifetime), PingPong, Random.
- Also `FlipbookFramerate` and `FlipbookStartRandom`.
- **Clients automatically deactivate flipbooks when low on memory** (likely on older phones). Reuse textures and prefer smaller resolutions.

**Performance warnings** — same source
- Particle **size** costs fill-rate.
- Overlapping transparent particles cost **overdraw**.

**Official burst recipe** — [Roblox Docs: Create explosions with VFX](https://create.roblox.com/docs/tutorials/use-case-tutorials/vfx/use-particles-for-explosions)
- Drag 10, Lifetime 0.2–0.6, Speed 20–40, SpreadAngle 180/180, Enabled off, `Emit(100)`.
- Color gradient and smooth transparency fade.
- "Sparkles for gathering collectable objects" is suggested as a variant.

**Beams and Trails** — [Roblox Docs: Beams](https://create.roblox.com/docs/effects/beams); [Roblox Docs: Trails](https://create.roblox.com/docs/effects/trails)
- Beam: textured strip between two attachments, Bezier-curvable (CurveSize0/1), Segments, FaceCamera.
- Trail: follows a moving pair of attachments; Lifetime controls length and speed.

**Highlight** — [Roblox API: Highlight](https://create.roblox.com/docs/reference/engine/classes/Highlight)
- Outline + interior fill, good for flash-on-hit, interactable cues and legendary pets.
- 255 simultaneous limit; delete rather than disable.

**Explosion alternatives**
- The tutorial builds an explosion entirely from a ParticleEmitter burst rather than the `Explosion` instance — [Roblox Docs: Create explosions with VFX](https://create.roblox.com/docs/tutorials/use-case-tutorials/vfx/use-particles-for-explosions)
- I did not verify the `Explosion` class's current status this session. It's commonly considered dated-looking and physics-heavy (BlastPressure flings parts).

**Where to learn and source VFX** (search summaries)
- DevForum "Introduction to VFX: Particles" (beginner series) — [DevForum](https://devforum.roblox.com/t/introduction-to-vfx-particles/2068650)
- "Yuruzuu's Open Source VFX" (free, customizable effects to study) — [DevForum](https://devforum.roblox.com/t/yuruzuus-open-source-vfx/1840021)
- Jad's Emit plugin (emits particles, beams and meshes) — [DevForum](https://devforum.roblox.com/t/dear-vfx-makers-i-present-to-you-jads-emit-plugin/1986838)
- SteakParticles plugin (VFX library and creator) — [DevForum](https://devforum.roblox.com/t/steakparticles-plugin-for-creating-vfx-and-particle-emitters/2908779)
- Texture creation with Photopea — [DevForum](https://devforum.roblox.com/t/how-to-make-textures-for-vfx-and-particles/3546172)
- Creator Store "Visual Effects" category — [Creator Store](https://create.roblox.com/store/category/visual-effects)
- Official tutorials: basic particle effects, custom particle effects (volcano), explosions, waterfalls, laser beams — [creator-docs vfx tutorials](https://github.com/Roblox/creator-docs/tree/main/content/en-us/tutorials/use-case-tutorials/vfx)

### Inferences
**Stylized recipes for Hood** (starting values to tune; all `Enabled=false`, fired with `:Emit()` from an Attachment, all LightEmission ≈ 1 unless noted)

**Punch impact (layered on one Attachment at the bag contact point)**

| Layer | Texture | Emit | Lifetime | Speed | Spread | Size / Squash | Transparency | Other |
|---|---|---|---|---|---|---|---|---|
| Core flash | soft white circle | 1 | 0.08–0.12 | 0 | — | 0→3 | 0→1 | |
| Shockwave ring | ring | 1 | 0.2–0.3 | 0 | — | 0.5→7, ease-out curve | 0.2→1 | Orientation = VelocityPerpendicular with a tiny Speed along the punch direction so it faces along the punch, or FacingCamera for a screen-facing ring |
| Spark streaks | thin streak | 8–14 | 0.15–0.35 | 30–50 | (60, 60) toward the punch direction | Squash 1→0 | — | Drag 8–10; Orientation = VelocityParallel; Color white→yellow/orange |
| Dust puff | | 3–5 | 0.4–0.7 | 4–8 | | 1→3 | 0.4→1 | LightEmission 0; Drag 5 |

**Level-up / "+Power milestone" burst**
- Vertical column: Beam or tall Squash particles rising.
- Ring at the feet.
- 20–30 star particles (Speed 10–20, Acceleration (0, -20, 0) for a fountain arc, RotSpeed ±180).
- Pair with a UI pop and a short sound sting.

**Coin / Power-orb pickup sparkle**
- 6–10 tiny star particles: Lifetime 0.3–0.5, Speed 3–6, SpreadAngle 180, Size 0.4→0.
- Plus the orb flying to the HUD on a Bezier arc (Section 4).

**Rebirth aura (sustained)**
- Ground ring Beam or particle with Rate 2–3, Lifetime 1.5, Size 2→6, Transparency 0.5→1, slow RotSpeed.
- Rising wisps: Rate 8–12, Speed 2–4, Acceleration up, flipbook flame 4×4 at 20–30 fps.
- Optional `Highlight` at OutlineTransparency 0.3 in the rebirth color.
- Limit to the local player plus the nearest few others.

**Rules of thumb**
- Fade every particle in and out.
- Prefer a few large readable shapes over many tiny ones.
- Keep ring and flash lifetimes **under ~0.3 s**, so impacts feel instant.
- Re-use one emitter set by moving its Attachment, rather than cloning emitters per hit.

### Gaps
- I couldn't load DevForum VFX tutorials in full. Specific stylized-VFX property values are my starting points, not sourced numbers.
- I didn't verify the `Explosion` instance's current deprecation status.

---

## 8. Common mistakes that make Roblox animation look amateur, and how to avoid them

### Takeaway
The usual tells:
- **Linear easing** everywhere.
- **Missing anticipation and follow-through.**
- **Wrong priorities** (actions blending with idle/walk, causing jitter).
- **Loops that hitch** (last keyframe ≠ first).
- **Default fade times** that mush snappy actions.
- **Framerate-dependent lerps.**
- **Server-side tweening and moving** of purely visual things (stutter).
- Re-calling `LoadAnimation` every time.
- **Ownership errors** that make animations silently not play.
- **No impact feedback** on hits.
- **Over-juicing** (constant shake, effects stacking past readability).

### Cited Findings
- Linear easing looks "stiff and robotic"; cubic looks more natural — [Roblox Docs: Animation Editor](https://create.roblox.com/docs/animation/editor)
- Loops don't interpolate last → first unless you duplicate the first keyframes at the end — [Roblox Docs: Animation Editor](https://create.roblox.com/docs/animation/editor)
- **Priority conflicts:** two animations at the same priority on the same joint blend, causing jitter and snapping. The fix is deliberate priorities, with only one Action+ track per body region — [DevForum: Why do my animations look stiff?](https://devforum.roblox.com/t/why-do-my-animations-look-stiff/2947662); [kitsblox: Why your Roblox animations look choppy](https://kitsblox.com/blog/fix-choppy-roblox-animations) (search summaries); consistent with [Roblox API: AnimationTrack.Priority](https://create.roblox.com/docs/reference/engine/classes/AnimationTrack)
- Using **In** easing instead of Out/InOut makes motion start smoothly but end abruptly — [DevForum (search summary)](https://devforum.roblox.com/t/animation-looks-stiff-at-the-end/2017175)
- Loading animations on the Humanoid instead of the Animator is a common error; `Humanoid:LoadAnimation` is deprecated — [Roblox API: Humanoid](https://create.roblox.com/docs/reference/engine/classes/Humanoid)
- Re-calling `LoadAnimation` creates a new track each time and hurts performance — [Roblox API: Animator](https://create.roblox.com/docs/reference/engine/classes/Animator)
- `AnimationTrack.Length` is 0 until loaded, so code that reads it immediately breaks — [Roblox API: AnimationTrack](https://create.roblox.com/docs/reference/engine/classes/AnimationTrack)
- "Animations appear stiff on other clients but perfect on your own client" is a known complaint — [DevForum](https://devforum.roblox.com/t/animations-appear-stiff-on-other-clients-but-perfect-on-your-own-client/678186) (search summary)
  - **Plausible cause:** Animator LOD throttling for remote characters; `PreferLodEnabled` and `ClientAnimatorThrottling` exist for this — [Roblox API: Animator](https://create.roblox.com/docs/reference/engine/classes/Animator); [Roblox API: Workspace](https://create.roblox.com/docs/reference/engine/classes/Workspace)
- Framerate-dependent `lerp(a, b, 0.1)` per frame behaves differently at 30, 60 and 240 fps — [Freya Holmér (search summary)](https://www.classcentral.com/course/youtube-lerp-smoothing-is-broken-a-journey-of-decay-and-delta-time-293974)
- Animations not owned by the game owner or group fail to load ("sanitized ID") — [DevForum](https://devforum.roblox.com/t/failed-to-load-animation-with-sanitized-id-when-loading-group-owned-animations/3550557); [Roblox Docs: Animation Editor (group Creator field)](https://create.roblox.com/docs/animation/editor)
- Particles that pop in and out without a transparency fade look cheap — [Roblox Docs: Particle emitters](https://create.roblox.com/docs/effects/particle-emitters)
- Overuse risk: some developers argue heavy juice reduces immersion — [Game Developer (search summary)](https://www.gamedeveloper.com/design/video-indies-resist-the-urge-to-juice-it-or-lose-it-)
- **Server-side TweenService** replicates the tweened property every frame, which causes jitter and network load. Leftover Animation Editor data in cloned rigs also bloats replication — [Roblox Docs: Improve performance](https://create.roblox.com/docs/performance-optimization/improve)
- Using deprecated movers (BodyPosition/BodyGyro) or `SetPrimaryPartCFrame` in new code — [Roblox Docs: legacy movers](https://create.roblox.com/docs/physics/mover-constraints#legacy-mover-conversion); [Roblox API: Model](https://create.roblox.com/docs/reference/engine/classes/Model)

### Inferences
**Hood checklist before shipping an animation**
1. Did you set priority intentionally? (Punch = Action, emotes = Action2, locomotion = Movement)
2. Does every action have anticipation, a fast strike, and follow-through?
3. Do the loops match first and last keyframes?
4. Are fadeTimes short for snappy actions (0.03–0.08) and longer for idles (0.2–0.3)?
5. Do gameplay events fire from markers, not `task.wait(0.2)`?
6. Is it published under the **group** that owns the game?
7. Did you test at 30 and 60+ fps, and on mobile?

**Other amateur tells**
- **Twinning:** both arms identical in idle.
- **Floaty punches:** a slow strike with a fast recovery, the opposite of what reads as powerful.
- **Characters sliding:** the walk animation speed doesn't match WalkSpeed. Scale `AdjustSpeed` with velocity.
- **Every hit identical:** randomize pitch, particle count and slight shake direction.
- **Camera shake on every click at full strength:** tier it (small/medium/large, as Vlambeer recommends).
- **Effects running server-side:** they replicate late and stutter.

**AnimationConstraint pitfall (new in 2025–26)**
- Old scripts that find `Motor6D` or write `C0` on R15 characters can silently break when AvatarJointUpgrade is on.
- Audit any procedural neck, arm or aim code — [Roblox API: AnimationConstraint](https://create.roblox.com/docs/reference/engine/classes/AnimationConstraint)

### Gaps
- Most "common mistakes" evidence came from DevForum search summaries. Full threads weren't readable.
- The link between "stiff on other clients" and LOD throttling is my hypothesis, not confirmed by a source.

---

## 9. Learning path for the Hood team (basics → advanced)

### Takeaway
Learn in four stages, each producing a shippable Hood feature:
1. Principles + Animation Editor basics → a custom punch and idle.
2. API plumbing (Animator, priorities, markers, ownership) → punch wired to gameplay.
3. Procedural motion (springs, smoothing, RunService, IK) → bag sway, pets, camera.
4. VFX and juice layering, plus performance (client rendering, culling, BulkMoveTo, particle budgets) → the "impact frame" recipe.

Then go deeper with Moon Animator 2 or Blender, the Curve Editor, the Animation Graph Editor and AnimationConstraint physics.

### Cited Findings
**Stage 1: principles and tools**
- 12 principles — [Wikipedia](https://en.wikipedia.org/wiki/Twelve_basic_principles_of_animation)
- Animator's Survival Kit walk timing — [Monmouth notes](https://animation.monmouth.edu/instruct/animation/walk-cycle/)
- Animation Editor (poses, easing, looping, priority, publishing) — [Roblox Docs](https://create.roblox.com/docs/animation/editor)
- Roblox's own step-by-step tutorials — [create-an-animation](https://github.com/Roblox/creator-docs/blob/main/content/en-us/tutorials/use-case-tutorials/animation/create-an-animation.md); [play-character-animations](https://github.com/Roblox/creator-docs/blob/main/content/en-us/tutorials/use-case-tutorials/animation/play-character-animations.md)

**Stage 2: runtime plumbing**
- [Use animations](https://create.roblox.com/docs/animation/using)
- [Animation events](https://create.roblox.com/docs/animation/events)
- [AnimationTrack API](https://create.roblox.com/docs/reference/engine/classes/AnimationTrack)
- [Asset privacy and permissions](https://create.roblox.com/docs/projects/assets/privacy)

**Stage 3: procedural motion**
- [RunService](https://create.roblox.com/docs/reference/engine/classes/RunService)
- [TweenService (incl. SmoothDamp)](https://create.roblox.com/docs/reference/engine/classes/TweenService)
- [spr](https://github.com/Fraktality/spr)
- [Quenty Spring](https://github.com/Quenty/NevermoreEngine/blob/main/src/spring/src/Shared/Spring.lua)
- [IK docs](https://create.roblox.com/docs/animation/inverse-kinematics)
- [Freya Holmér lerp talk](https://www.classcentral.com/course/youtube-lerp-smoothing-is-broken-a-journey-of-decay-and-delta-time-293974)

**Stage 4: VFX and juice**
- [Particle emitters](https://create.roblox.com/docs/effects/particle-emitters)
- [VFX tutorials](https://github.com/Roblox/creator-docs/tree/main/content/en-us/tutorials/use-case-tutorials/vfx)
- [RbxCameraShaker](https://github.com/Sleitnick/RbxCameraShaker)
- [RbxUtil Shake](https://github.com/Sleitnick/RbxUtil/blob/main/modules/shake/init.luau)
- [Juice it or lose it](https://www.gdcvault.com/play/1016487/Juice-It-or-Lose)
- [Art of Screenshake summary](https://makegamessa.com/discussion/1537/the-art-of-screenshake-by-flambeer-s-jan-willem-nijman)
- [Sakurai on hitstop](https://sourcegaming.info/2015/11/11/thoughts-on-hitstop-sakurais-famitsu-column-vol-490-1/)

**Advanced**
- [Curve Editor](https://create.roblox.com/docs/animation/curve-editor)
- [Animation Graph Editor](https://create.roblox.com/docs/animation/graph-editor)
- [AnimationConstraint / Avatar Joint Upgrade](https://create.roblox.com/docs/reference/engine/classes/AnimationConstraint)
- [Adaptive Animation](https://create.roblox.com/docs/characters/adaptive-animation)
- [Animation Capture (video → keyframes)](https://create.roblox.com/docs/animation/capture)

### Inferences
**Suggested build order for Hood**, each step testable in isolation:
1. Replace default locomotion with the Cartoony pack IDs, then custom ones.
2. Two alternating punch animations (L/R) with a "Hit" marker and a cancelable recovery.
3. Client `ImpactFX` module: `hitStop`, `shake(tier)`, `burst(tier, cframe)`, `popNumber(amount, position)`, `flash(model)`.
4. Procedural bag sway spring plus squash.
5. `PetRenderer`: formation, bob/hop, culling, rarity FX tiers.
6. `WorldAnimator`: tagged spinners and bobbers, BulkMoveTo, distance culling.
7. Stage-wall break sequence with chunk swap and cleanup.
8. Polish pass: IK look-at, pet reactions, Animation Graph for locomotion blending (optional).

### Gaps
- No single official Roblox "animation curriculum" covering procedural and VFX juice end-to-end was found. This path is my synthesis.
