# Procedural and Code-Driven Animation on Roblox (and Rigging Objects Like a Cannon)

Scope: how a team that builds everything in code, with no hand animating in Studio, can still get pro-quality motion. Current as of Oct 31, 2026.
Number labels: **[cited]** means a source states the number. **[suggested]** means it is our own starting value, to tune by eye on a 30 fps video.
Cross-reference: the frame-by-frame cannon shot timings, muzzle VFX and camera shake are already in `research_notes/Pro Roblox animation and VFX/cannon_launch_animation.md` and `Build Playbooks/16 Pro Animation and VFX Playbook.md`. These notes do not repeat them. They cover the systems underneath: springs vs tweens, rigs, IK, Transform layering, the new animation APIs and performance.

> **Biggest 2026 change to know first:** R15 player characters no longer spawn with Motor6D joints in new experiences. They use **AnimationConstraint** joints instead (Avatar Joint Upgrade, live Jan 26, 2026; default in Phase 2, target H2 2026). Code that does `:IsA("Motor6D")` or writes `C0`/`C1` on character joints breaks: the check misses them, and the write errors. Props and NPC models you build yourself still use Motor6D, which keeps working (see Q2 and Q4).

---

## Q1. TweenService vs springs vs RenderStepped lerps: when to use each, and which easing for each job

### Takeaway
Use **TweenService** for fixed-length, one-shot moves that won't be interrupted (UI slide-ins, fades, door opens). Use a **spring** (spr, a Fusion Spring, or a 20-line custom one) for anything that can be interrupted, retargeted or should overshoot and wobble: UI pops, recoil, hover, follow-the-mouse, counters. Use a **per-frame lerp** with frame-rate independent smoothing for camera and look-at follow. Run all of them on the client.

### Cited Findings
- spr API: `spr.target(obj, dampingRatio, undampedFrequency, {props})`, `spr.stop(obj, prop?)`, `spr.completed(obj, cb)`. It animates boolean, CFrame, Color3, ColorSequence, number, NumberRange, UDim, UDim2, Vector2 and Vector3, with Color3 in CIELUV space. It is one ModuleScript, MIT licensed. It errors with an explanation on non-converging parameters. — [spr GitHub](https://www.github.com/Fraktality/spr)
- spr damping semantics: below 1 is underdamped and overshoots; 1 is critical, which the docs call "the most visually neutral"; above 1 is overdamped and slower. Doc examples **[cited]**: `(1, 1)` for a smooth move and `(0.6, 4)` for an overshooting wobble. spr recommends damping below 1 when you want "pop". — [spr GitHub](https://www.github.com/Fraktality/spr)
- Fusion 0.3: `scope:Spring(goal, speed, damping)`. Damping 0 oscillates forever. Between 0 and 1 it oscillates and settles. 1 reaches the goal as fast as possible without overshoot. Above 1 is "viscous". Springs keep their velocity when the goal changes, so "they handle interruptions smoothly". `setPosition` and `setVelocity` teleport or kick the spring. Doc example uses speed 25 and damping 0.5 **[cited]**. — [Fusion docs: Springs](https://elttob.uk/Fusion/0.3/tutorials/animation/springs/)
- Server tweens look choppy. TweenService "just tweens the property, it does no replication". A server-tweened platform replicated at about 20–30 Hz and stuttered **[cited, community]**. The recommended pattern is to tell clients to tween, wait the duration on the server, then set the final value on the server. — [DevForum: Does TweenService optimise replication?](https://devforum.roblox.com/t/does-tweenservice-optimise-replication/199734)
- The existing repo note (sourced) uses `alpha = 1 − exp(−k·dt)` with k = 6–10 for frame-rate independent follow, or spr at damping 1 and frequency 3–5. — `research_notes/Pro Roblox animation and VFX/cannon_launch_animation.md` (line 143)
- A Model has no tweenable CFrame. Tween a `CFrameValue` and call `model:PivotTo()` on Changed, or spring a CFrameValue. — same repo note (lines 212, 224)

### Inferences (our recipes, all values [suggested])
**Decision table**

| Job | Tool | Values [suggested] |
|---|---|---|
| UI button press / pop-in | spr on a `UIScale.Scale` (not Size, so the layout doesn't jump) | press: target 0.9 at damping 1, freq 8; release: target 1 at damping 0.45, freq 5 (overshoots to about 1.1) |
| Panel slide-in | TweenService | 0.25–0.35 s, Quint or Back Out; slide-out 0.15–0.2 s, Quad In |
| Fade | TweenService | 0.15–0.25 s, Linear or Sine |
| Object recoil (cannon) | Kick: set the spring's velocity or position instantly. Return: spring | return damping 0.4–0.55, freq 4–6 (matches the repo's cannon note) |
| Idle bob / hover | Pure math in RenderStepped or PreRender: `y = A·sin(2π·f·t + phase)` | A 0.15–0.3 studs, f 0.5–0.8 Hz, random phase per object so they don't bob in sync. Add a rotation sway of about 3° at a different frequency |
| Pickup collect / fly-to-counter | Screen-space: clone an ImageLabel at `WorldToViewportPoint(pos)`, then fly it on a quadratic Bezier to the counter icon | 0.45–0.7 s with ease In (Quad or Cubic In) so it accelerates into the counter; on arrival, pop the counter with spr (UIScale 1.25, then back at damping 0.4, freq 6). Stagger multiple coins by 0.03–0.05 s |
| Number counter roll | Tween a NumberValue and write `math.floor` to the text on Changed | 0.4–0.8 s, Quad Out |
| Look-at / turret follow | Exp-smoothed lerp or slerp each frame, or a critically damped spring | k 8–12, or damping 1 at freq 3–5 |
| Camera shake | Sum of decaying sines or noise on a camera offset (see the repo cannon note) | — |

**Minimal custom critically damped spring** (no dependency). This is the standard closed-form approach. Treat it as our pattern, not a cited Roblox API:
```luau
-- x: position, v: velocity, goal; omega = 2*pi*freq; zeta = damping
local function stepSpring(x, v, goal, zeta, omega, dt)
    -- semi-implicit Euler, substepped for stability
    local steps = math.ceil(dt / (1/240))
    local h = dt / steps
    for _ = 1, steps do
        local a = -2*zeta*omega*v - omega*omega*(x - goal)
        v += a*h
        x += v*h
    end
    return x, v
end
```
- It works on numbers and on Vector3s (component-wise arithmetic works). For a CFrame, spring the position and an axis-angle rotation vector separately, then rebuild the CFrame.
- **Rule of thumb:** a tween needs a known start, end and duration. A spring needs only a goal. If the target can change mid-motion (aiming, hovering, a button pressed twice quickly), use a spring, because a restarted tween snaps its velocity to 0 and looks cheap.
- Performance: one RenderStepped loop that updates N springs is cheaper than N connections. Disconnect it, or skip the work, when everything has settled (|x−goal| and |v| under an epsilon).

### Gaps
- No official Roblox benchmark compares TweenService with Luau springs. The "TweenService is engine-side and cheap" belief is community lore that I did not verify in a primary source.
- I did not confirm Fusion's default speed and damping values from its docs. The page lists them as optional with no defaults.

---

## Q2. Rigging non-character objects (cannon, chest, egg): Motor6D, AnimationController, Bones, KeyframeSequences from code

### Takeaway
For a code-only team, the simplest pro rig is an **anchored root part plus Motor6D joints** to each moving piece. Drive `Motor6D.Transform` from springs on the client, and play Animator clips only when you have real authored animations. Add an `AnimationController` with a child `Animator` only if you will play KeyframeSequence clips on the prop. **Bones cannot scale**, so do squash and stretch on rigid parts by changing their Size or scale, not with bones.

### Cited Findings
- "To play animations on rigs that do not contain a Humanoid, you must create an AnimationController with a child Animator." — [Roblox docs: Using animations](https://create.roblox.com/docs/animation/using)
- `Motor6D.Transform` is "the internal CFrame that is manipulated when a Motor6D is being animated", and the docs recommend it "for custom animations rather than C0 and C1". If the model has an Animator, Transform "will usually be overwritten every frame by the Animator after RunService.PreAnimation and before RunService.PreSimulation". It "can be set manually using RunService.PreSimulation or through an Animator". Transforms are applied "as a batch in a parallel job after PreSimulation, immediately before physics steps". — [Motor6D reference](https://create.roblox.com/docs/reference/engine/classes/Motor6D.md)
- Motor6Ds keep working but are now "legacy JointInstances that won't receive improvements". The post said they would be marked deprecated "in the coming weeks". The Avatar Joint Upgrade only applies to characters spawned through the Player or HumanoidDescription flows. Existing NPC models in a place are not upgraded. — [DevForum: Avatar Joint Upgrade is now live (Jan 26, 2026)](https://devforum.roblox.com/t/avatar-joint-upgrade-for-physically-simulated-character-movement-is-now-live/4298561)
- `AnimationConstraint` aligns two parts through Attachments.
  - With `IsKinematic = true` (the default) it follows Transform exactly, like Motor6D. With `false`, force and torque drive it, limited by MaxForce and MaxTorque.
  - `AngularStrength` and `LinearStrength` are f/60, where f is the target frequency in Hz. The default 1 means 60 Hz, and values above 1 can destabilise **[cited]**. `AngularDamping` and `LinearDamping` are damping ratios, where 1 is critical **[cited]**.
  - Procedural layers multiply into Transform during PreSimulation.
  - C0, C1, Part0 and Part1 are read-only aliases. Don't edit `RigAttachment.CFrame` directly.
  — [AnimationConstraint reference](https://create.roblox.com/docs/reference/engine/classes/AnimationConstraint.md)
- Bones "only support translation and rotation". Scale is discarded on import, and approximating volume change needs "many extra bones" (feature request, Jul 28, 2026). — [DevForum: Bone scaling feature request](https://devforum.roblox.com/t/feature-request-bone-scaling-deformation-support/4761420)
- Building a KeyframeSequence in code:
  - `Instance.new("KeyframeSequence")` with `Loop` and `Priority` set.
  - Create a `Keyframe` with a `Time`, and add Poses with `keyframe:AddPose(pose)`.
  - Nest Poses with `pose:AddSubPose(child)`. The example names Poses after parts (`HumanoidRootPart` > `LowerTorso`) and sets Weight to 0 on the root Pose.
  - Finish with `seq:AddKeyframe(kf)`.
  — [KeyframeSequence reference](https://create.roblox.com/docs/vi-vn/reference/engine/classes/KeyframeSequence)
- `KeyframeSequenceProvider:RegisterKeyframeSequence(seq)` returns a temporary hash ID for "localized testing" that "cannot be used outside of Studio". `RegisterActiveKeyframeSequence` returns an `active://` URL, also temporary. To use the clip online, upload the KeyframeSequence. `GetKeyframeSequenceAsync(assetId)` yields, so wrap it in pcall. — [KeyframeSequenceProvider reference](https://create.roblox.com/docs/reference/engine/classes/KeyframeSequenceProvider.md)
- Repo rule (already in CLAUDE.md): the owner's raw KeyframeSequences are extracted with Lune into `.rbxm`, played in Studio via KeyframeSequenceProvider, and need a publish helper for the live game. — `/home/user/roblox/CLAUDE.md`

### Inferences (our recipes, [suggested])
**Cannon rig layout (code-built):**
```
Cannon (Model, PrimaryPart = Base)
  Base        (anchored; the only anchored part)
  Yaw         Motor6D Base→Turntable   (turn left/right)
  Pitch       Motor6D Turntable→Barrel (tilt up/down; C0 at the trunnion/axle point)
  Recoil      Motor6D Barrel→BarrelTube (slides back along -Z)
  WheelL/R    Motor6D Base→Wheel (spin on X)
  AnimationController > Animator   (only if you will play clips)
```
- **Joint pivots:** place each Motor6D's C0 and C1 at the real hinge (the axle or trunnion) so rotations look physical. A wrong pivot is the most common reason a code rig "looks cheap". All non-root parts are unanchored and `Massless`, and CanCollide is off for decoration.
- **Drive it** in one client `RunService.PreSimulation` loop (or `PreRender` if no Animator is involved):
  - `Yaw.Transform = CFrame.Angles(0, yawSpring.x, 0)`
  - `Pitch.Transform = CFrame.Angles(pitchSpring.x, 0, 0)`
  - `Recoil.Transform = CFrame.new(0, 0, recoilSpring.x)`
  - To fire: set the recoil spring's position to 0.6–1.0 studs back instantly (the kick), and let it return at damping 0.45, freq 5.
- **Chest:** one Motor6D for the lid hinge at the back edge. Open with a spring to −100° at damping 0.5, freq 4, so it overshoots and slams back a little. Pre-open anticipation is a 0.08 s shake: ±3° at 25 Hz.
- **Egg:** a single part. Do the wobble with Transform rotation around the egg's bottom (pivot C0 at its base): ±8–15°, rising in frequency before the hatch. Squash and stretch: change `Size` (or use `Model:ScaleTo` on a model) with volume preserved: `sy = s`, `sx = sz = 1/sqrt(s)`. Bones can't scale, so this is the only native squash on rigid parts.
- **Squash with skinned meshes:** fake it with 3–5 bones in a column that move apart or together and splay outwards. Only worth it with a Blender-made mesh (`blender-roblox-models` skill).
- **Authoring clips from code** (when you want an Animator clip, for example a looping idle shared by 50 eggs):
  1. Build the KeyframeSequence with Poses named after the rig's part names. Pose hierarchy follows the joint tree: root part > child part.
  2. Set each Pose's `CFrame` (an offset from rest), `EasingStyle` and `EasingDirection`.
  3. Save it to `.rbxm` via Lune.
  4. Studio test: register it with KeyframeSequenceProvider.
  5. Live game: the owner right-clicks the KeyframeSequence and chooses Save to Roblox (or uses a publish helper), then pastes the ID back. Never invent IDs (repo rule).
- For props, code-driven springs on Transform usually beat clips. They react to gameplay (fire rate, power) and need no upload. Use clips only for long, hand-timed motion.

### Gaps
- The Pose, NumberPose and KeyframeMarker property pages were not fetched. The Pose CFrame and Easing property names above are from general API knowledge, so verify them in Studio.
- I found no official statement on whether non-character Motor6D props will ever be force-migrated. The joint upgrade post only covers characters.
- The exact current publish UI for a KeyframeSequence (Save to Roblox vs the Animation Editor's Publish) was not re-verified for Oct 2026.

---

## Q3. IKControl: types, aiming a cannon, character pointing, look-at, recoil and arm IK

### Takeaway
`IKControl` solves a chain from `ChainRoot` to `EndEffector` toward a `Target` (a part or attachment). Use the **LookAt** type for "point this at that" (head looks at player, cannon barrel tracks a target). Use **Position** or **Transform** for hands on handles. For a simple two-axis cannon, plain math (yaw from atan2, pitch from the elevation angle) on Motor6D.Transform is more predictable than IK.

### Cited Findings
- `Enum.IKControlType` values:
  - **Transform (0)**: "full 6-DoF… aligns the EndEffector CFrame to that of the Target". This is the default.
  - **Position (1)**: aligns the EndEffector position.
  - **Rotation (2)**: aligns the EndEffector rotation.
  - **LookAt (3)**: "moves and orients the whole chain to make the forward axis on the EndEffector point at a position".
  — [IKControlType enum](https://create.roblox.com/docs/reference/engine/enums/IKControlType.md)
- IKControl properties: ChainRoot, Enabled, EndEffector, EndEffectorOffset, Offset, Pole, Priority, SmoothTime, Target, Type, Weight. Methods: GetChainCount, GetChainLength, GetNodeLocalCFrame, GetNodeWorldCFrame, GetRawFinalTarget, GetSmoothedFinalTarget. The doc sample parents an IKControl to the Humanoid with Type Position, EndEffector LeftHand, ChainRoot LeftUpperArm and Target an Attachment on HumanoidRootPart offset (−1, 0, −1). — [IKControl reference](https://create.roblox.com/docs/reference/engine/classes/IKControl)

### Inferences ([suggested])
- **Character points at a thing:** one IKControl, type LookAt, ChainRoot UpperTorso, EndEffector Head, Weight about 0.6–0.8 (so the head doesn't snap 180°), SmoothTime about 0.1–0.2. Add a second IKControl for an arm: Position type, ChainRoot UpperArm, EndEffector Hand, with a Pole attachment behind the elbow so the elbow bends the right way.
- **Two hands on a cannon handle / weapon:** Transform-type IKControls whose Targets are Attachments welded to the prop's grips. The hands then follow recoil for free, because the prop moves and IK follows.
- **Procedural recoil on a character:** play nothing extra. Add a decaying spring offset to the UpperTorso or RightUpperArm joint Transform in PreSimulation (see Q4), and let hand IK keep the hand on the gun.
- **Cannon aim by math:** `yaw = atan2(-dir.X, -dir.Z)` in the base's local space, `pitch = asin(dir.Y)`. Feed both to springs (damping 1, freq 3–5) so the barrel glides instead of snapping. Clamp pitch to the rig's range, for example −5° to 45°.
- Run IK on the client for visuals. The engine doesn't replicate per-frame IK solutions; set Target and Weight on whichever machine owns the visual. That is an inference, not confirmed in docs.

### Gaps
- The IKControl page I fetched gave no per-property descriptions, defaults, Animator requirement or replication behaviour. Check the full Creator Docs page or the "IKControl" guide in Studio. Weight and SmoothTime defaults are unconfirmed.
- I did not verify how IKControl interacts with AnimationConstraint joints on upgraded avatars.

---

## Q4. Character animation from code: lean, landing squash, Transform layering, Animate override, priorities, weights, markers, blending

### Takeaway
The pro pattern is **clips first, then procedural layers on top**. Let the Animator write joint Transforms, then multiply your own offsets (lean, recoil, breathing, head look) in `RunService.PreSimulation`, which runs after the Animator has written that frame. Use clip priorities and weights for big state changes, and markers to sync VFX and sound.

### Cited Findings
- **Frame order:** the Animator writes Transform after `PreAnimation` and before `PreSimulation`. Manual writes go in `PreSimulation`. — [Motor6D reference](https://create.roblox.com/docs/reference/engine/classes/Motor6D.md)
- On upgraded avatars, layer procedural adjustments "by multiplying into Transform during PreSimulation", which "keeps animation retargeting intact". — [AnimationConstraint reference](https://create.roblox.com/docs/reference/engine/classes/AnimationConstraint.md)
- Joint-upgrade breaking changes:
  - `IsA("Motor6D")` misses the new joints.
  - Setting C0, C1, Part0 or Part1 errors.
  - Ragdolls should disable or weaken AnimationConstraints.
  - Opt-out is `StarterPlayer.AvatarJointUpgrade = Disabled`, temporary in Phase 2 (target H2 2026). Phase 3 removes the opt-out (date TBD).
  - R6 is not upgraded.
  — [DevForum: Avatar Joint Upgrade is live](https://devforum.roblox.com/t/avatar-joint-upgrade-for-physically-simulated-character-movement-is-now-live/4298561)
- **AnimationTrack defaults [cited]:** `Play(fadeTime = 0.1, weight = 1, speed = 1)`, `AdjustWeight(weight = 1, fadeTime = 0.1)`, `AdjustSpeed(speed = 1)`. Also `GetMarkerReachedSignal(name)`, `KeyframeReached`, `Priority`, `WeightCurrent` and `WeightTarget`, `Looped`, `Stopped`, `Ended`, `TimePosition`. — [robloxapi AnimationTrack](https://robloxapi.github.io/ref-temp/class/AnimationTrack.html)
- **Overriding default animations:** set the `AnimationId` of the values inside the character's `Animate` script (for example `animateScript.run.RunAnim.AnimationId`) from a server Script on `CharacterAppearanceLoaded`. When a state has several animations, Animate picks one at random, weighted by "animation weight / total weight of all state animations". Use `GetMarkerReachedSignal()` for named events. — [Roblox docs: Using animations](https://create.roblox.com/docs/animation/using)
- Repo brief: Animation Graphs are fully released (Jul 15, 2026). Use `Animator:GetTrackByAnimationId` instead of loading a track twice. — `Build Playbooks/Sector Briefs/Brief - VFX, Animation, Audio and Game Feel.md`

### Inferences ([suggested])
**Layering loop (client, local character):**
```luau
RunService.PreSimulation:Connect(function(dt)
    local v = root.AssemblyLinearVelocity
    local localV = root.CFrame:VectorToObjectSpace(v)
    -- lean into movement: forward tilt and side roll, springed
    leanX = spring(leanX, math.clamp(-localV.Z/16, -1, 1) * math.rad(8), dt)
    leanZ = spring(leanZ, math.clamp(-localV.X/16, -1, 1) * math.rad(6), dt)
    waist.Transform = waist.Transform * CFrame.Angles(leanX, 0, leanZ)
    -- landing squash: a short dip offset on the root joint, kicked on Landed
    rootJoint.Transform = rootJoint.Transform * CFrame.new(0, -landDip, 0)
end)
```
- Lean: 6–10° forward and 4–8° side at full walk speed. Spring at damping 0.7, freq 3.
- Landing: on `Humanoid.StateChanged` to Landed, kick `landDip` to 0.3–0.5 studs scaled by fall speed, return at damping 0.5, freq 6. Add an optional camera dip of 0.1–0.2 studs. You can't scale R15 limbs per frame cheaply, so "squash" on a character is a dip plus knee bend, not a Size change.
- Always multiply onto the Transform the Animator just wrote. Never assign a fresh CFrame, or you erase the clip.

**Priorities and weights:**
- The order is Core < Idle < Movement < Action < Action2 < Action3 < Action4.
- Use Action for attacks and emotes, and Action2–4 for overlays that must beat other actions (for example a hit-react).
- Same-priority tracks blend by weight. Crossfade by calling `Play(0.15)` on the new track and `Stop(0.15)` on the old one.
- For a walk-to-run blend without Animation Graphs: play both looped, then each frame `walk:AdjustWeight(1-a, 0)`, `run:AdjustWeight(a, 0)`, and `AdjustSpeed` both to the speed ratio.

**Markers:** in the clip, place markers named `Hit`, `TrailOn`, `TrailOff`, `Sfx`. In code, `track:GetMarkerReachedSignal("Hit"):Connect(...)` spawns the VFX on the client. This keeps the effect frame-perfect even if the clip is re-timed.

**Load once:** cache tracks (`GetTrackByAnimationId`, or your own table). Loading a track on every play leaks tracks.

### Gaps
- The docs page I fetched did not state the priority list or the same-priority blend rule; the order above is from general API knowledge, so verify it on the Enum.AnimationPriority page.
- I didn't check whether an engine track limit (the community-reported "256 tracks" warning) still applies.
- I did not verify that writing Transform in PreSimulation works the same on AnimationConstraint joints with IsKinematic false.

---

## Q5. What the owner would do by hand (Animation Editor, Moon Animator 2) and the 2025–2026 animation features

### Takeaway
By hand: pose a rig in the Animation Editor or Moon Animator 2, save it (a KeyframeSequence), publish it to get an ID, and send the ID. New in 2026: **Animation Graphs**, with state machines and Luau expressions, are released and scriptable. Motion matching for default movement is on the roadmap, not shipped.

### Cited Findings
- **Moon Animator 2 (current version):** "just Save the animation in Moon Animator UI". The KeyframeSequence is stored under the rig's `AnimSaves`. Save that KeyframeSequence to Roblox to get an asset ID, then use it in an `Animation`. — [DevForum: How to export using Moon Animator 2](https://devforum.roblox.com/t/how-to-export-using-moon-animator-2/2092413)
- **Animation Graph Editor:**
  - It creates an `AnimationGraphDefinition` asset. You publish it for an asset ID, load it like a clip with `animator:LoadAnimation`, and drive it with `AnimationTrack:SetParameter(name, value)`.
  - Nodes include Clip (with a Speed port), Add, Select, Priority Select, Sequence, Random Sequence, Parameter and Graph Output.
  - **Graph > Create Animate script** generates an `Animate` ModuleScript, a `RunClient` LocalScript and a `RunServer` Script. Players get them in StarterCharacterScripts; NPCs get them on the rig.
  - Authority modes:
    - Automatic: parameters replicate, player graphs run on the owning client and NPC graphs on the server.
    - Server: the server simulates and clients predict. Set parameters from both RunServer and RunClient for player characters.
  - Transition curves support only `PoseEasingStyle.Linear` and `CubicV2`.
  — [Roblox docs: Graph editor](https://create.roblox.com/docs/animation/graph-editor.md)
- **State machines:**
  - States (Idle, Walk, Run, Jump) can be clips, blends or nested machines. An Entry state picks the start.
  - Transitions wait on an Expression (for example `Speed >= 12` or `ShouldJump`) or on Finished/BeforeFinished.
  - Default blend Duration is 0.15 s **[cited]**. Priority ranges 0–65,535 **[cited]**; equal priorities are chosen at random.
  — [Roblox docs: Graph editor state machines](https://create.roblox.com/docs/animation/graph-editor-state-machine) (page updated Oct 28, 2026)
- **Conflict on status:** the repo's sector brief says Animation Graphs reached full release on Jul 15, 2026 (DevForum). An older repo note (`03 What's New… RDC 2026`) calls "Animation Graph State Machines + Luau Expressions" a Studio beta. A third-party blog is titled "Stop shipping Roblox Animation Graph State Machines to live experiences – 2026" ([gamineai](https://gamineai.com/blog/stop-shipping-roblox-animation-graph-state-machines-to-live-2026), not read). The docs pages I fetched state no status. Likely reading: graphs are released, and the state-machine plus expressions layer is newer or beta. Treat that as unconfirmed.
- **Motion matching** for default movement and prompt-set NPC behaviour are RDC 2026 roadmap items (late 2026–2027), not shipped. — repo `Build Playbooks/03 What's New on Roblox - RDC 2026 and October.md`; `research_notes/Pro Roblox animation and VFX/character_animation.md` (citing NPCMotion, a vendor source)

### Inferences ([suggested])
- **Owner's by-hand steps:**
  1. Install Moon Animator 2, or use the built-in Animation Editor (Avatar tab).
  2. Select the rig and make a new file.
  3. Set key poses about every 4–8 frames, then right-click the keys to set easing (Out for snappy hits, InOut for idles).
  4. Add named markers for effects.
  5. Save, then publish (Save to Roblox).
  6. Send the ID.
  Props need a rig first: Motor6Ds at the hinges, which our code can generate and save into the place so the owner only poses.
- For our simple kid games, keep plain clips plus code layers. Adopt Animation Graphs only for character locomotion blends, and avoid state-machine graphs in live games until their status is confirmed.

### Gaps
- No primary source fetched on Animation Capture updates in 2026.
- Moon Animator 2's own rigging tools (for example its weld and rig helpers) were not covered by the thread I fetched.

---

## Q6. Performance: number of tweens, client-only animation, network ownership

### Takeaway
Do all cosmetic motion on the **client**: tweens, springs, IK, Transform layers and VFX. The server only sets the final state and fires one event. Anchor animated props, or make sure the server owns them, so physics replication never fights your code.

### Cited Findings
- Server-side tweens replicate property changes at about 20–30 Hz and look stuttery. The pattern is: clients tween, the server waits and then sets the final state. Community modules (TweenService V2) package this. — [DevForum](https://devforum.roblox.com/t/does-tweenservice-optimise-replication/199734)
- Animation Graph parameters set with SetParameter replicate automatically under AuthorityMode.Automatic, and several calls in one frame collapse to the last value. — [Graph editor docs](https://create.roblox.com/docs/animation/graph-editor.md)
- Motor6D/AnimationConstraint Transforms are applied in a batched parallel job before physics. — [Motor6D reference](https://create.roblox.com/docs/reference/engine/classes/Motor6D.md)

### Inferences ([suggested])
- **Pattern:**
  1. The server validates "fire cannon" and fires a RemoteEvent to all clients with `(cannonId, power, t0)`.
  2. Every client plays recoil, VFX and sound locally.
  3. The server sets only state that matters for gameplay.
- Animations played by a client on its own character's Animator replicate to others automatically. Prop animations driven by code on the client do not replicate, so each client runs them itself (that's the point).
- Write `Transform` (not `CFrame`) on prop joints, and keep only the root anchored. Writing CFrame on unanchored welded parts forces physics work and ownership fights.
- If a prop must be unanchored and physical, call `SetNetworkOwner(nil)` on the server so no player's client controls its physics.
- Budget: a few hundred active tweens or springs on a client is fine in practice (community experience, not benchmarked). The real costs are per-frame `Instance.new`, many separate RenderStepped connections, and animating things off-screen. Pool collect icons, use one loop, and pause anything more than about 150 studs away or outside the viewport.

### Gaps
- No official numbers for maximum tweens, springs or IKControls per client were found.
- I didn't verify the exact replication rate of server property changes from a Roblox primary source; the 20–30 Hz figure is one community report.
