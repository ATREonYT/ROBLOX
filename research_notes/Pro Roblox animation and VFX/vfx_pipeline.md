# Pro Roblox VFX pipeline (anime battlegrounds and top simulators), as of Oct 2026

Scope note: these notes cover techniques only and copy no game's assets. Most hard numbers here come from Roblox's own docs and from DevForum posts. Pro artists for The Strongest Battlegrounds, Jujutsu Shenanigans, Blox Fruits and Pet Simulator 99 rarely publish their exact settings, and I found no first-party breakdown from those studios. Where a number is our own inference rather than sourced, it is labelled as an inference. Dates are given so old info can be spotted. Cross-reference: the repo already has a working implementation of many of these ideas in `LihFolk/skills/lihfolk-vfx/SKILL.md` (crescent units, BeamLaser, Shield, per-preset particle budgets) and `Build Playbooks/11 VFX Moments Playbook.md`.

## 1. Custom flipbook textures: sizes, grids, framerate, making and uploading

### Takeaway
Roblox flipbooks are a square, power-of-two PNG with frames on a 2x2, 4x4 or 8x8 grid, played at up to 30 fps. Artists render or draw the frames in any tool, pack them with a sprite-sheet packer (trim and rotate off, fixed size), keep a gap between frames, and choose Loop, OneShot, PingPong or Random. A 1024 px 8x8 sheet gives 64 frames of 128 px each, and a 4x4 sheet gives 16 frames of 256 px each.

### Cited Findings
- Flipbooks left beta on Oct 21, 2022. The layouts were renamed to `Grid2x2`, `Grid4x4` and `Grid8x8` (from TwoByTwo, FourByFour and EightByEight). — [Particles' Flipbook Release](https://devforum.roblox.com/t/particles’-flipbook-release/2029388)
- At full release, the texture must be square and power-of-two, from 8x8 up to 1024x1024 (8, 16, 32, 64, 128, 256, 512 or 1024). Border clipping was fixed, but Roblox still recommends spacing around frames to avoid artifacts. — [Particles' Flipbook Release](https://devforum.roblox.com/t/particles’-flipbook-release/2029388)
- During the beta (Mar 2022) only 1024x1024 worked. Frame sizes on a 1024 sheet: 2x2 gives 4 frames of 512 px, 4x4 gives 16 frames of 256 px, and 8x8 gives 64 frames of 128 px. To fit a longer animation, drop frames: the example cut 128 frames to 64 by keeping every other one. *(The size rule is older than the full release, which relaxed it.)* — [Particle Flipbooks Beta](https://devforum.roblox.com/t/animated-particles-with-the-particle-flipbooks-beta/1718023)
- The current docs also list a `Custom` layout that uses `FlipbookSizeX` and `FlipbookSizeY`. — [Creator Docs: Particle emitters](https://create.roblox.com/docs/effects/particle-emitters)
- `FlipbookFramerate` is a min/max range in frames per second, with a maximum of 30 fps. — [Creator Docs: Particle emitters](https://create.roblox.com/docs/effects/particle-emitters)
- The four `FlipbookMode` values:
  - **Loop** cycles through the frames.
  - **OneShot** plays once across the particle's Lifetime and ignores FlipbookFramerate, so an 8x8 sheet on a 4 s particle plays at 16 fps.
  - **PingPong** plays forward, then backward.
  - **Random** plays frames in random order with crossfades; it suits slow organic effects such as twinkles.
  - — [Particle Flipbooks Beta](https://devforum.roblox.com/t/animated-particles-with-the-particle-flipbooks-beta/1718023)
- `FlipbookStartRandom` starts each particle on a random frame. With Framerate 0, an 8x8 sheet becomes 64 different static shapes from one emitter, which is useful for varied debris, sparks and smoke puffs. — [Particle Flipbooks Beta](https://devforum.roblox.com/t/animated-particles-with-the-particle-flipbooks-beta/1718023)
- When the texture isn't a valid flipbook, the read-only `FlipbookIncompatible` warning appears and the flipbook properties are hidden. — [Particle Flipbooks Beta](https://devforum.roblox.com/t/animated-particles-with-the-particle-flipbooks-beta/1718023)
- Packing tools Roblox staff named:
  - Photoshop's Contact Sheet;
  - Free Texture Packer (free-tex-packer.com), which the staff author used;
  - CodeAndWeb's free Sprite Sheet Packer, the Leshy SpriteSheet Tool and the codeshack.io generator.
  - Settings: fixed size 1024x1024, with "trim" and "rotate" turned off. Export a PNG.
  - — [Particle Flipbooks Beta](https://devforum.roblox.com/t/animated-particles-with-the-particle-flipbooks-beta/1718023)
- Flipbooks cost memory, and clients may turn them off when memory is low, which is likely on older phones. Reusing one texture across emitters costs less than unique textures. Mip filtering may need extra spacing between frames. — [Creator Docs: Particle emitters](https://create.roblox.com/docs/effects/particle-emitters)
- Texture advice: use a PNG with a transparent background. For greyscale art without alpha, set LightEmission = 1 so the dark areas disappear (additive). — [Creator Docs: Particle emitters](https://create.roblox.com/docs/effects/particle-emitters)
- Community users noticed a visible fade or crossfade between frames and asked for a way to turn it off. Roblox didn't answer in the thread. — [Particles' Flipbook Release](https://devforum.roblox.com/t/particles’-flipbook-release/2029388)
- Free and paid flipbook libraries circulate on the DevForum, for example "2 Free Realistic Flipbook Particle Explosions". A Mar 2025 "Advanced VFX Plugin" claims a library of over 10,000 assets, and its post now points to a newer plugin. — [2 Free Flipbook Explosions](https://devforum.roblox.com/t/2-free-realistic-flipbook-particle-explosions/3035597); [Advanced VFX Plugin](https://devforum.roblox.com/t/vfx-animation-plugin-texture-library-with-200-flipbooks/3547230)
- EmberGen (JangaFX) is a real-time volumetric fire, smoke and explosion simulator that exports flipbooks. It is the common tool for "realistic" sheets. — [EmberGen](https://jangafx.com/software/embergen)

### Inferences
- For anime smoke, fire or lightning in a kid-cartoony style:
  - Draw on a 4x4 grid at 1024 px (16 frames of 256 px, sharp enough on a Retina screen), or 8x8 for short 64-frame bursts where each frame is small on screen.
  - Use OneShot with a Lifetime of 0.3 to 0.6 s for bursts: 16 frames in 0.5 s is about 32 fps, which matches the 30 fps cap.
  - Leave at least 4 to 8 px of empty margin inside each cell, because of the mip and spacing warnings. This margin is our inference, not a Roblox number.
- Upload flow (no web API from cloud sessions here): the owner uploads the PNG as a Decal or Image in Studio, then sets `ParticleEmitter.Texture`, `FlipbookLayout`, `FlipbookMode` and `FlipbookFramerate`. This fits CLAUDE.md's "owner uploads, sends back IDs" rule.
- A Claude-friendly way to make frames: render the frames procedurally in Python (PIL) or Blender, then pack them with a script into a 1024 grid with trim off. That mirrors the packers above.

### Gaps
- I found no published framerates or grid choices from TSB, JJS or Blox Fruits artists. I found no hand-drawn anime-flipbook workflow (Photoshop timeline or Figma) with steps from a named Roblox pro.
- I didn't verify the exact FlipbookMode enum names in the current API docs; the docs page I fetched didn't list them. The beta post names them.

## 2. Mesh VFX: shapes, UVs, scrolling textures, tweening, materials

### Takeaway
Pro "anime" slashes, rings, domes and wind spirals are low-poly Blender meshes, UV-unwrapped so that a gradient or streak texture runs along the arc. They are tweened in size, CFrame and transparency over fractions of a second. To fade a textured mesh, the texture usually goes on `Texture` objects (or a decal) rather than the mesh's TextureID. Neon gives the glowing core and ForceField gives the shimmering shell.

### Cited Findings
- Crescent slash recipe (Mar 2021):
  1. Make a squashed sphere.
  2. Draw lines of varying thickness, opacity and colour in GIMP.
  3. Apply Filters > Distorts > Polar Coordinates to bend the lines into an arc.
  4. In Blender, put a seam around the middle of the sphere and unwrap it.
  5. Upload the texture as a decal and put two `Texture` objects inside the mesh rather than using TextureID, so the mesh can be made transparent.
  - The post gave no tween values. — [Crescent Sword Slash Effect](https://devforum.roblox.com/t/crecent-sword-slash-effect/1113871)
- Alternatives from the same thread:
  - animate a sprite sheet by stepping the texture offset;
  - spawn mesh clones and clean them up with Debris;
  - use curved Beams that face the camera. The author preferred meshes for their true 3D curvature.
  - — [Crescent Sword Slash Effect](https://devforum.roblox.com/t/crecent-sword-slash-effect/1113871)
- The "Texture Offsets" feature (2019) lets scripts animate a `Texture`'s `OffsetStudsU/V`, which is the standard way to scroll a texture on a mesh or part. — [Texture Offsets 2019](https://devforum.roblox.com/t/texture-offsets-2019/314381/59)
- ForceField material's Fresnel rim can be shaped with the `Reflectance` property. That makes it a common choice for shields and domes. — [ForceField Fresnel via Reflection](https://devforum.roblox.com/t/control-the-fresnel-effect-of-forcefield-material-using-the-reflection-property/258289)
- A beginner anime-VFX guide (Jan 2022) used a Neon, 0.5-transparency, 2x2x2 part with CastShadow off. It tweened the part over 1 s and cleaned it up after the tween. The guide's VFX values are in screenshots that I couldn't read. — [Full Beginner's Guide on Anime VFX](https://devforum.roblox.com/t/full-beginners-guide-on-scripting-animefighting-vfxvisual-effects-part-1/1610853)
- The 2026 plugin "Sine VFX" has:
  - "3D particles", meaning mesh VFX that behave like particles;
  - beziers and splines;
  - craters;
  - transformed trails and beams;
  - trail lightning.
  - So mesh-as-particle is a current pro workflow. — [Sine VFX plugin (Aug 2026)](https://devforum.roblox.com/t/plugin-sine-vfx-a-vfx-plugin-for-roblox-studio/4803771)
- Our vault already ships a crescent unit with these parts: a body mesh with reveal and erosion textures, an ink mesh, a rim mesh, glow and ink cards, an edge Beam, and sparks spawned at the head. It also has a ForceField shield shell and Neon projectile cores. — repo file `LihFolk/skills/lihfolk-vfx/SKILL.md` (internal, not web)

### Inferences
- Meshes worth building once in Blender, each with UVs laid out as a straight strip so one horizontal gradient or streak texture runs along the effect:
  - a crescent (half-torus or squashed-sphere band);
  - a flat ring or torus;
  - a shockwave dome (hemisphere without a cap);
  - a wind spiral (a helix ribbon, unwrapped as one long strip);
  - a spike cone;
  - a low-poly sphere.
- Common timing pattern (inference; no source gave numbers):
  - a burst scale-up of 0.1 to 0.2 s with Quad/Expo Out;
  - a fade of 0.3 to 0.6 s on the Texture objects' Transparency with Quad In;
  - a slight spin throughout.
  - Check this against reference video at 30 fps, per CLAUDE.md.

### Gaps
- I found no sourced standard durations or easing from named pro artists, and no text writeup of the MeshPart+SurfaceAppearance scrolling method (SurfaceAppearance has no offset property; scrolling uses `Texture` objects or Beams).

## 3. Beams and Trails in pro effects

### Takeaway
A Beam is a textured Bézier ribbon between two Attachments. Scrolling its texture with `TextureSpeed`, in Wrap or Stretch mode, gives energy streams, lasers and curved "slash" ribbons. Trails go on weapons and projectiles. Settings are documented; pro-specific values are not published.

### Cited Findings
- **TextureMode.** In Wrap and Static, the number of repeats = beam length ÷ TextureLength. In Stretch, the texture repeats TextureLength times across the whole beam, whatever its length. — [Creator Docs: Beams](https://create.roblox.com/docs/effects/beams)
- **Curve.** The beam is a cubic Bézier:
  - CurveSize0 = the distance in studs from Attachment0 along its +X axis;
  - CurveSize1 = the distance from Attachment1 along its −X axis.
  - This is how curved slash arcs are made from a Beam. — [Creator Docs: Beams](https://create.roblox.com/docs/effects/beams)
- **FaceCamera and width.** FaceCamera keeps the beam facing the camera. Width0 and Width1 set the width in studs at each end; the docs example is 0.5 → 3. — [Creator Docs: Beams](https://create.roblox.com/docs/effects/beams)
- Roblox's official laser-trap tutorial uses Beams as the energy-laser recipe. — [Laser traps with beams](https://create.roblox.com/docs/tutorials/use-case-tutorials/vfx/laser-traps-with-beams)
- **Curved beams as slashes.** A forum reply recommends camera-facing curved Beams as an alternative to crescent meshes. — [Crescent Sword Slash Effect](https://devforum.roblox.com/t/crecent-sword-slash-effect/1113871)
- **Sine VFX tools.** It ships a trail preview, retimer and resizer, plus trail lightning. — [Sine VFX](https://devforum.roblox.com/t/plugin-sine-vfx-a-vfx-plugin-for-roblox-studio/4803771)
- **Brightness and bloom.** Repo learning: thin hairline beam streaks need low Brightness, because bloom fattens them. — repo file `LihFolk/skills/lihfolk-vfx/SKILL.md` (internal)

### Inferences
- Laser or energy beam: stack 2 to 3 Beams (a dark edge, a coloured body, a white core) with TextureMode Wrap and a scrolling TextureSpeed, and wobble the width. Our BeamLaser preset already does this.
- Weapon trail: a Trail with a short Lifetime, about 0.15 to 0.3 s (inference), WidthScale tapering to 0, a gradient texture, and LightEmission about 1 for glow.

### Gaps
- I couldn't fetch the TextureSpeed units, the Segments default or maximum, or the Trail defaults. The Beam docs page didn't include them, so check the API reference.

## 4. Layer count, 3-tone rule, timing, and the tools in use in Oct 2026

### Takeaway
I found no single documented "pro layer count" or "3-tone rule" source. What the sources do show is the 2025–2026 tooling: emitter plugins drive layered effects through attributes such as EmitDelay, EmitCount and EmitDuration, which lets one "Emit" fire a timeline of burst layers and lingering layers.

### Cited Findings
- **VFX Forge** (zilibobi) attributes:
  - EmitCount: how many particles to emit;
  - EmitDelay: seconds before emitting;
  - EmitDuration;
  - curve editors for Transparency, Size, Squash and TimeScale.
  - — [Forge docs: particle](https://zilibobi.github.io/forge-docs/effects/particle)
- **Sparkle/"VFXer"** plugin attributes:
  - EmitDelay and EmitDuration (number or NumberRange);
  - EmitRepeat (−1 means infinite) and EmitRepeatDelay;
  - ResetOnFinish and Clone;
  - TweenIn, TweenOut and TweenProperties for lights and other effects;
  - a `Color` attribute for one-click recolour.
  - — [VFXer attributes](https://vfxer.gitbook.io/plugin/attributes)
- **QP2** ("Particiliary") is another emitter framework with model and spawning docs. Sine VFX cites both Forge and QP2 as inspiration. — [QP2 docs](https://qp2-docs.pages.dev/guide/particiliary/model/); [Sine VFX](https://devforum.roblox.com/t/plugin-sine-vfx-a-vfx-plugin-for-roblox-studio/4803771)
- **Sine VFX** (Aug 11, 2026; $5 on the Creator Store) includes:
  - an emit window, colour picker and particle counter;
  - path and shape visualizers;
  - a runtime module and a NumberSequence graph editor;
  - a property copier and shifter.
  - The author says it was built with AI assistance. — [Sine VFX](https://devforum.roblox.com/t/plugin-sine-vfx-a-vfx-plugin-for-roblox-studio/4803771)
- **Advanced VFX Plugin** (Mar 2025) has mass property and colour sliders, plus impact frames and camera shake "in two clicks". Its post now redirects to a newer plugin. — [Advanced VFX Plugin](https://devforum.roblox.com/t/vfx-animation-plugin-texture-library-with-200-flipbooks/3547230)

### Inferences
- Adopt the attribute convention (EmitDelay, EmitCount, EmitDuration on each emitter) in our own runtime module. Effects then become authorable data, compatible in spirit with the Forge and Sparkle conventions, and Claude can edit them without touching code.
- Our repo playbooks hold the layering and 3-tone guidance (`Build Playbooks/11` and `15`), so treat them as house rules rather than sourced industry fact.

### Gaps
- I found no source that states a pro layer count per effect, a "3-tone" colour rule, or how Moon Animator is used for VFX timing. I found no new first-party VFX feature from Roblox in 2026 beyond the flipbook properties.

## 5. Syncing to animations, replication, pooling

### Takeaway
The battlegrounds-style pattern:
1. The client sends input.
2. The server validates it (state and cooldowns).
3. The server tells all clients.
4. Each client plays the attacker's animation locally and fires the VFX and SFX from animation events (markers).

The caster plays its own effect instantly, damage stays on the server, effects are culled by distance, and they are cleaned up with Debris or tweens.

### Cited Findings
- **TSB/JJS-style architecture.** An answer from a developer who built "Combat Legends" (Aug 16, 2026):
  - Client → Server (validate state and cooldowns) → all clients.
  - Each client plays the animation and listens for animation events to trigger VFX and SFX, which stays smooth even under the attacker's lag.
  - Split code per skill into a server Service and a client Controller, such as FireballService and FireballController.
  - Most skills don't need UnreliableRemoteEvents.
  - The answer doesn't address pooling. — [Best way to replicate VFX for a Battlegrounds game](https://devforum.roblox.com/t/best-way-to-replicate-vfxanimations-for-a-battlegrounds-game-tsbjjs-style-architecture/4814813)
- **Client Replication 101** (May 2022, with replies into 2025):
  - send minimal data (an origin CFrame plus tween goals or parameters);
  - the caster plays the effect immediately, and the server replicates only to the other clients;
  - "ONLY REPLICATE VFX NOT HITBOXES";
  - clean up with Debris or a fade tween;
  - use FastCast rather than tweens for projectiles;
  - send only to players in range;
  - for late joiners, use `workspace:GetServerTimeNow()` timestamps and a queue of recent effects.
  - — [Client Replication 101](https://devforum.roblox.com/t/client-replication-101-the-guide-to-replicating-effects-to-clients/1789487)
- **FireAllClients pattern.** The server fires all clients with a CFrame and position. Each client clones the effect from ReplicatedStorage and tweens it to match the hitbox timing. — [Full Beginner's Guide on Anime VFX](https://devforum.roblox.com/t/full-beginners-guide-on-scripting-animefighting-vfxvisual-effects-part-1/1610853)
- **Remote spam.** Rate-limiting VFX remotes against exploiter spam is a known concern. — [Prevent exploiters spamming VFX RemoteEvent](https://devforum.roblox.com/t/how-should-i-prevent-exploiters-spamming-my-remoteevent-for-vfx-replication/4749010)

### Inferences
- Animation sync: add named markers in the animation (for example "Impact" and "Release") and connect them on each client with `AnimationTrack:GetMarkerReachedSignal("Impact")` to call `Emit` or tween the meshes. This is the "animation events" approach the 2026 answer describes.
- Pooling: keep pre-cloned effect templates in a folder, move them into place, then Emit, and reset them after use (the Sparkle `ResetOnFinish` idea). None of the sources gave pool sizes.

### Gaps
- I found no sourced pool sizes or pooling benchmarks.

## 6. Common particle numbers

### Takeaway
Only engine limits and property meanings are documented. Pro "house numbers" for lifetimes, sizes, speeds and emit counts were not published in any source I could reach, so treat any numbers below as inference to tune by eye against a reference.

### Cited Findings
- Engine limits (current docs):
  - Lifetime is capped at 20 s.
  - Rate is capped at 400 particles per second per emitter, and 100 on mobile.
  - Speed is in studs per second.
  - Transparency runs from 0 to 1.
  - — [Creator Docs: Particle emitters](https://create.roblox.com/docs/effects/particle-emitters)
- LightEmission 0 = normal blending and 1 = additive, which glows. LightInfluence sets how much world light tints the particles. Brightness scales emitted light when LightInfluence = 0. ZOffset moves particles forward or back in studs without changing their size on screen. — [Creator Docs: Particle emitters](https://create.roblox.com/docs/effects/particle-emitters)
- Squash above 0 makes particles tall and thin; below 0 makes them wide. The docs' rain uses Squash 3, and a negative value when Orientation is VelocityParallel. The orientation modes are FacingCamera (default), FacingCameraWorldUp, VelocityParallel and VelocityPerpendicular. — [Creator Docs: Particle emitters](https://create.roblox.com/docs/effects/particle-emitters)
- Repo vault per-effect budgets, as a reference point:
  - Shield: about 3 particles alive, 10 per hit, 34 at break.
  - BeamLaser: 15 for the charge, about 9 alive, 16 at the end.
  - — repo file `LihFolk/skills/lihfolk-vfx/SKILL.md` (internal)

### Inferences
Starting values to tune; these are not sourced pro numbers:
- **Impact sparks:**
  - Orientation VelocityParallel with negative Squash, or a thin texture.
  - Lifetime 0.15–0.35 s, Speed 40–80, Drag 5–10, emit 10–20.
  - LightEmission 1 and LightInfluence 0.
- **Smoke puff:**
  - Lifetime 0.5–1.2 s, Speed 5–15, Size growing 1 → 4.
  - LightEmission 0 and LightInfluence 1.
  - Emit 4–8, with a flipbook in OneShot mode.
- **Glow core:**
  - one particle, Lifetime 0.1–0.2 s, large Size, LightEmission 1, ZOffset 1–2 so it stays in front.
- Keep the total count low on mobile (the 100/s Rate cap hints at the budget). Respect the house rule of at most 1 flash per second.

### Gaps
- I found no first-party or named-artist source giving lifetimes, sizes, speeds or emit counts for TSB, JJS, Blox Fruits, Pet Simulator 99, anime TD/RNG games or +1 Stone Skipping.
- YouTube tutorial transcripts and ArtStation or Fiverr listings were not fetched within this research budget. They are the next place to look, for example with `get_video_transcript` on specific "Roblox anime VFX tutorial" videos.
