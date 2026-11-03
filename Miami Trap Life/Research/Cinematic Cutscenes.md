---
tags: [miami-trap-life, research, cutscenes, camera, cinematography, tutorial]
updated: 2026-11-02 (round 2)
---
# Cinematic cutscenes: making them look studio-made

Back to [[00 Master Plan]] · Basics and our runner: [[Cutscenes]] · Funnel: [[Onboarding Funnels and Wayfinding]]

[[Cutscenes]] covers the "what" (short, skippable, the player is the star). This note is the "how to make it look expensive": the camera language film crews use, how it maps onto Roblox, and a checklist every scene in `Cutscenes/*.lua` should pass. The welcome scene (`Cutscenes/Welcome.lua`) and the first-day scene (`Cutscenes/FirstDay.lua`) were built against it.

## 1. Camera language (film grammar, applied to us)

**Every shot says one thing.** A shot that doesn't move the story (who is talking, where we are, what just changed) gets cut. Game Developer's cutscene guide puts it as: frame each shot to express a story point and remove "shoeleather", the boring shots of people walking from A to B ([Game Developer: How to build a better cutscene](https://www.gamedeveloper.com/art/how-to-build-a-better-cutscene)).

**Shot sizes and what they're for**

| Size | Use | Our numbers (FOV / distance) |
|---|---|---|
| Extreme wide / aerial | A new place, the city, "you are here" | FOV 50-60, 120-250 studs out, high |
| Wide (establishing) | The block, the store front, the meet spot | FOV 55-65, 30-60 studs |
| Medium / two-shot | Two people talking, a walk-up | FOV 45-55, 10-14 studs |
| Close-up | A face reacting, a line that matters | FOV 32-42, 4-6 studs |
| Insert (detail) | The phone screen, the dead PC, the cash | FOV 25-35, 2-4 studs |

**Classic order: wide → medium → close.** Open on where we are, then who, then how they feel. Go back to a wide when the place changes or to let a moment breathe.

**The 180° rule (the "stage line").** Draw a line between the two people talking and keep every camera on one side of it, so the player always looks screen-left and the other person screen-right. Crossing it flips who is where and the viewer gets lost. Our `two = {A, B}` and `ots = {listener, speaker}` helpers keep the side fixed with `side = 1/-1`; pick one side per conversation and keep it.

**Motivated movement.** The camera moves because something moves: it follows a walk, it pushes in when a line lands, it rises when a car drives off. Motivated moves feel invisible, unmotivated ones feel like a screensaver ([No Film School](https://nofilmschool.com/2018/06/key-good-camera-movement-motivation), [PremiumBeat](https://www.premiumbeat.com/blog/cinematography-tip-motivated-camera-movement/)). The one allowed "unmotivated" move is a slow drift on an establishing shot.

**Cut on action.** Change shots at the instant something happens (the phone buzzes, a door opens, the hand hits the keyboard), and keep eyelines matching across the cut. Cuts hidden inside motion go unnoticed.

**Hide jumps with a contrasting angle.** When the gameplay position and the scene don't line up, cut to a very different angle (a high wide, a close-up, an insert) instead of a small move. Small moves look like mistakes, big ones look intended ([Game Developer](https://www.gamedeveloper.com/art/how-to-build-a-better-cutscene)).

**Weight.** Real cameras are heavy: every move eases in and out. Erratic or weightless moves disorient people. Never Linear.

**Composition rules we use**
- *Rule of thirds:* faces on the upper third line, not dead centre. The `close` helper offsets the camera 1.3 studs sideways so the face sits off-centre.
- *Lead room:* leave space in front of where a character looks or walks.
- *Low angle* = power (the crew on first meeting, the player at the end of the welcome). *High angle* = small and lost (the new kid arriving in a city).
- *Foreground framing:* put something close to the lens (a car, a pole, a doorway) in the wide shots: it gives depth for free and is what makes a Roblox shot look "filmed" instead of "screenshotted".

## 2. Pacing

- **Shot length:** 2.5-6 s for most shots. Establishing drifts 5-7 s. A cut every 3-4 s on dialogue keeps it alive. Anything static over 6 s needs a push-in or a drift.
- **Lines:** one line per shot, shot changes with the speaker. Under ~60 characters. The runner checks readability (typing time + 1 s per 25 characters).
- **Compress the boring, stretch the important.** Walks become a 2-3 s cut, not a 10 s follow. The important beat (the phone buzz, the push-in on "Same store. Tonight.") gets a beat of silence before it.
- **The first five seconds decide.** The opening frame has to be the best-looking thing in the scene, and the player should be in control within the first minute ([Bugnet: memorable openings](https://bugnet.io/blog/how-to-design-a-memorable-opening), [Gamasutra GDC 2004: opening cinematics](https://www.gamasutra.com/marketing/postcard-from-gdc-2004-14-ways-of-drawing-players-in-with-an-opening-cinematic)). Our welcome is 27 s and skippable after 1 s.
- **Total length budget:** welcome ≤ 30 s, story scenes ≤ 40 s, gags 8-16 s (`CutsceneRules.MaxLength = 45`).

## 3. Easing (how it moves)

| Move | Ease | Why |
|---|---|---|
| Establishing drift, crane down | `Sine` (in-out), 5-7 s | slow start and stop, like a crane |
| Push-in on a face | `Quad` in-out, 3-4 s, FOV down 8-12 | builds tension |
| Hand-off into gameplay | `Cubic` in-out, 2-2.5 s | long settle, no "snap" into the player camera |
| Flyover along a curve | `path` (Catmull-Rom spline) + `Sine` | no corners where the direction changes |
| Shake | noise, decaying over 0.3-0.6 s | impacts only |

Spline paths: a camera that goes A → B → C with straight lerps has a visible "kink" at B. A Catmull-Rom spline through the points is smooth and passes exactly through every point, so you place points where you want the camera to be ([DevForum: unique camera tweens](https://devforum.roblox.com/t/if-you-were-to-tween-the-camera-in-a-unique-way-how-would-you-do-it/1215187)). Our runner now has `from = { path = {p1, p2, p3, ...}, look = ... }`.

## 4. Light, lens and grade

- **Hold the time of day.** Golden hour and early morning (low sun, long shadows) make everything look better. A scene sets `hour = 7.5` and LightingController holds it for this player only, then blends back to the world clock over a few seconds.
- **Grade per scene.** One `grade` per scene (ColorCorrection tint/saturation/contrast): warm and slightly saturated for the hopeful welcome, cool for the night meet, sickly for the flat.
- **Depth of field** pulls the eye. `DepthOfFieldEffect` has FarIntensity, FocusDistance, InFocusRadius and NearIntensity ([Roblox docs](https://create.roblox.com/docs/reference/engine/classes/DepthOfFieldEffect)). Our runner focuses on the look target every frame; a shot can set `focus = "Actor"` to rack focus to someone else and `blur` (0-1) for how strong. Wide aerials use almost none; close-ups use a lot.
- **Low graphics quality turns DOF and some post effects off.** Every shot must still read without them: composition first, effects second.
- **Lens = FOV.** Lower FOV = longer lens = flatter, more "film" look for faces. Keep 30-80 (the validator enforces 20-80).
- **Letterbox** (11% bars top and bottom) is the cheapest "this is cinema now" signal. Bars slide in over 0.3 s and out at the hand-off.

## 5. Transitions

| Transition | When |
|---|---|
| Hard cut | Same scene, new angle (most of the time) |
| Fade from black (0.8-1.2 s) | Scene start, after a teleport |
| Dip to black + title card | Time skip or chapter change ("NEXT DAY", "CHAPTER 1") |
| Hand-off (camera glides into the gameplay camera) | Scene ends with the player standing there: no black, no snap. Industry calls it camera blending ([80.lv: evolution of game cinematics](https://80.lv/articles/from-pixel-scenes-to-one-shot-cameras-the-evolution-of-game-cinematics)). On Roblox, switching Scriptable → Custom snaps unless the last frame already sits where the default camera would be ([DevForum: smooth transition Scriptable → Custom](https://devforum.roblox.com/t/smooth-transition-from-camera-type-scriptable-to-custom/2311593), [DevForum: smoothly reset camera](https://devforum.roblox.com/t/smoothly-reset-players-camera-after-a-cutscene/3560491)), so our `gameplay = true` camera spec ends the scene exactly behind the player's head and only then switches. |
| Sound bridge (J-cut) | The next shot's sound starts before the picture changes (the phone buzz is heard on the wide, then we cut to the close-up) |

## 6. Sound

Sound sells it more than pictures. Per scene: an ambience bed (city, room tone), a music cue that fades in under the establishing shot and out at the hand-off, foley on every action (buzz, door, keys) and a soft sting on title cards. Rule from Alex: **no robotic or high-pitched sounds**. Every UI sound goes through `UI/Sfx.lua`; cutscene keys fall back to `Theme.Sfx` names, so a scene can say `sound = "PhoneVibrate"`. Music and city ambience slots are empty until Alex provides tracks (`Theme.Cutscene.Sounds.WelcomeMusic`, `City`).

## 7. Roblox techniques that matter

- **Clock-driven timeline** on `RenderStepped` (not chains of tweens and waits): skip and tap-to-next-line are just clock jumps. Already in `CutsceneController`.
- **Streaming:** the place uses StreamingEnabled, so a camera far from the player can show holes. The scene lists `stream = { points }`; the runner calls `RequestStreamAroundAsync` on them while the screen is still black (capped at 2.5 s).
- **Wall safety:** a raycast pulls the camera in front of walls between it and the target (meet spots are random).
- **Local actors:** NPCs and the player's clone are client-side, so scenes are private and free for the server. Hide the real character with `LocalTransparencyModifier`.
- **Put the real player where the scene ends** (`call = "PlaceAtEnd"`), so the hand-off camera lands on the real character in the same spot.
- **Never probe the camera from the Studio assistant mid-scene:** it resets CameraType and breaks the shot (Master Plan §6).
- Plugins worth knowing for authoring shots by eye: CineCam v3 ([DevForum](https://devforum.roblox.com/t/plugin-cinecam-v3-%E2%80%94-build-preview-camera-cutscenes-live-in-studio-no-playtesting-needed/4713811)), Moon Animator for actor animations.

## 8. Checklist for every scene (copy into the scene's header comment)

1. Opens on its best frame (wide, lit, with foreground).
2. Wide → medium → close, and back to wide when the place changes.
3. One idea and at most one line per shot; shot changes with the speaker.
4. Every move eased; no straight lerp with a corner (use `path`).
5. Stage line respected in every conversation.
6. Cuts on action; a sound starts each important beat.
7. Grade + held hour set; looks right with DOF off.
8. Ends with a hand-off (`gameplay = true`) or a dip to black, never a snap.
9. Skippable after 1 s; skipping still gives everything the scene gives.
10. Under budget (welcome 30 s, story 40 s, gag 16 s).

## 9. The tutorial (what we learned and built)

- **Teach in context, one thing at a time, by doing.** Show the control at the moment it's needed, not a list up front; hints only when needed; let people skip ([Wayline: in-game tutorials](https://www.wayline.io/blog/in-game-tutorials-design-guide), [Game Developer: the art of the tutorial](https://gamedeveloper.com/design/the-art-of-the-tutorial-when-to-hold-a-player-s-hand-when-to-let-it-go)). Most of the first-session drop-off is in the first 90 seconds ([Roblox onboarding docs](https://create.roblox.com/docs/production/game-design/onboarding)).
- Built: `TutorialController` + `Config/Tutorial.lua` + `Rules/TutorialRules.lua` + `UI/Build/Tutorial.lua` (MTL_Tutorial). A small coach card ("STEP 2 OF 6", one title, one line, the right key chips for keyboard / touch / gamepad) and a pulsing ring around the real HUD element it talks about (the phone, the objective line, the job panel, the cash pill, the level ring, the menu button), found **by name** so the HUD and phone redesigns keep working. Each step completes when you actually do the thing. "Skip tutorial" is always there. Progress is saved in `Settings.Tutorial` (whitelisted in `Config/Phone.SettingKeys`), so a rejoin never repeats a finished step.

## 10. Round 2 (2026-11-02): animation, grounding, steady camera, text

**Real animations, no uploads needed.** Roblox only plays animations owned by the experience's owner *or by Roblox*. Roblox-owned ones (the default Animate set and the catalog emotes) play in every game. Checked in Studio with `KeyframeSequenceProvider:GetKeyframeSequenceAsync` + `MarketplaceService:GetProductInfo` (creator = Roblox):

| Use | Id | Source |
|---|---|---|
| Idle | 507766666 | Animate idle (R15) |
| Walk | 507777826 | Animate walk |
| Wave | 3344650532 | emote Wave |
| Point | 3344585679 | emote Point |
| Shrug | 3334392772 | emote Shrug |
| Nod | 4841397952 | emote Agree |
| Laugh | 507770818 | Animate laugh |
| Cheer / Stretch | 507770677 | Animate cheer |
| Salute | 3333474484 | emote Salute |
| (spare) | 4841401869 Disagree · 4841405708 Happy · 4841407203 Sad · 5230599789 Bored · 4686925579 Sleep · 2506281703 Sit | Roblox |

Gotcha: `InsertService:LoadAsset(emoteCatalogId)` only returns the *face* animation of an emote; the body animation is a separate asset id (the table above).

**Layering (Actors.lua).** Base layer Idle/Walk (looped, Idle/Movement priority), gestures on top (Action). While the Animator drives `Motor6D.Transform`, the head turn toward the speaker goes into the Neck's **C0** instead, so both show. Held poses (Lean, Phone, Sit...) stay procedural. R6 avatars stay procedural.

**Floating feet.** The floor raycast hit invisible lot volumes ("Footprint" parts, CanCollide off, Transparency 1) and stood actors on them. Rule: ground = first hit that is CanCollide **and** visible; skip anything else and cast again.

**Camera wobble.** Aiming at the `Head` part follows the head bob of the walk/idle animation. Aim at a fixed height above the root instead. The cutscene camera is now bound with `BindToRenderStep(..., RenderPriority.Last)` so no other camera effect can run after it; the player carries attribute `MTL_Cutscene` while a scene plays so effects like run sway can switch off.

**Wall check vs glass.** The "pull the camera in front of walls" raycast must ignore glass, plexi screens and walk-through parts (Transparency >= 0.3 or CanCollide off), or the camera ends up pressed against a shop counter's plexi.

**Night faces.** A soft warm PointLight riding beside the lens (`scene.fill`, 0.9 by day, 1.4 at night hours, no shadows) keeps faces readable without relighting the set.

**Text.** Subtitles moved *inside* the bottom letterbox bar (white on black like film, never over the picture), speaker name small and coloured above the line, Montserrat/Gotham. Title cards: heavy title, a thin gold rule, a quiet subtitle. Lines rewritten to sound like people: short, specific, one idea each ("Fifty bucks and a phone. That's the whole plan.").

**Licensed audio.** APM Music and Pro Sound Effects uploads on the Creator Store are free for every experience: welcome music `9045798330`, city bed `9112888010`, crew-intro drums `1838985214`, night traffic `9112819963`. Chosen by description, not by ear.

**Other screens.** Non-MTL ScreenGuis (the place's stock ticker) and chat / player list / backpack hide during a scene and come back after.

## 11. Round 3 (2026-11-02): costumes, props, staging

- **Costumes from the catalog without uploads.** `AvatarEditorService:SearchCatalogAsync` with `CreatorName = "Roblox"` finds Roblox-made shirts, pants, hair and hats; a `HumanoidDescription` can wear any of them (price doesn't matter for building a rig). `Config/Missions.Actors` now has ShirtId/PantsId/Hair/Hat/FaceAcc per character (Dre: denim jacket + hoodie, dreads; Smoke: beanie, denim; Nina: braids; Patel: plaid shirt, glasses; Kev: teal shirt). A plain coloured block-person reads as "placeholder" instantly; clothes and hair are the cheapest big win.
- **Props sell the beat.** A glowing phone appears in the hand for every phone pose (light on the face). The crew's getaway car is now a real sedan from `ServerStorage.VBAssets.SedanA`, saved as `ReplicatedStorage.MTL_Actors.CrewCar` (front = -Z, origin at the floor, 4 blinking "Hazard" parts + "HazardLight").
- **Emotes vs held poses.** Full-body emote animations stand a seated actor up; while a held pose is on, gestures stay procedural.
- **Coach card placement.** Top-left, 110 px in from the edge: clear of the left-edge waypoint arrows and the menu column, the character, hotbar, phone and thumbstick.

## 12. Round 4 (2026-11-02): dialogue box, typing sound, human blocking

- **Dialogue box** (Alex: "a box with the character face icon on the side, bold text, a writing sound"): flat dark panel on the letterbox edge, a live 3D portrait (the speaker's head + hair/glasses copied into a ViewportFrame, framed from the front; an initial for speakers who aren't in the scene), name tag in the speaker's colour, Montserrat Bold line, italics for the player's thoughts, a small "next" arrow once typed. Avoid the "AI look": no glow, no gradient, one thin border, real faces instead of icons.
- **Typing sound**: one soft tick every couple of letters while a line types, random pitch per tick, never while skipping ahead (`Theme.Sfx.TextBlip`, Roblox's UI Hover 01 at low volume).
- **Feet match the ground**: the walk cycle's speed is set every frame from how fast the actor actually moves (`Missions.WalkAnimRef`), so ease-in/ease-out walks don't slide.
- **Blocking like a person** (Alex: "make him open the door, not walk through walls"): walks are split at doorways and corners (approach, slow down with QuadOut, door opens, step through the middle, glance around, then go). Check every walk segment against a collision grid of the set (`GetPartBoundsInBox` every 2 studs) before shipping. If the set has no door, the scene brings one (`GlassDoor` prop: two leaves slide apart, the bell rings on it).
- **Other screens can switch themselves back on** (the place's news ticker): hide them and hold `Enabled = false` with a property listener until the scene ends.

## 13. Round 5 (2026-11-03): Act 2 "The Tab", choices, sets from another thread

- **Choice cards inside scenes.** `choice = { t, prompt, options, default }`: the clock holds at `t` on a card (keys 1-3, click, gamepad). Lines and actions tagged `when = "<option>"` play only on that branch. Branch content stays to lines, gestures, poses, held items, sounds and titles. Walks and turns are built once at the start, so a branch never moves anyone. Write each branch to the same length so the shared shots after the card fit all of them. `CutsceneRules.validate` checks every branch separately (`CutsceneRules.branch`).
- **Cut on the ellipsis.** In RoyceSoda, Royce walks in and heads for the coolers. On the cut he's at the counter, soda in hand: a 0.02 s walk plus a `hold` swap during the cut. It saves 6 seconds of walking and reads as normal film grammar.
- **Hidden-prop swap.** To change a prop "off camera" (the full pallet becomes half a pallet), move one prop to y -60 and the other into place in the same frame while the camera is on someone's face. To hide something until it appears (the business card), start it *inside* the counter (`at * CFrame.new(0, -1.6, 0)`). Its floor height is measured from where it really sits, so it pops up onto the counter surface, not the floor.
- **Hand items.** `{ t, actor, hold = "Soda" | "Bill" | "Card" | "Keys" | "Envelope" | "Clipboard" | false }` welds a small part-built item to the right hand (`Actors.HeldItems`). Passing money is three beats: the giver `hold`s it, does the `Give` gesture, then hold moves to the receiver. Without this, hand-overs read as nothing happening.
- **Sets from the building thread.** For the Cash 4 Gold office and the Ends rooftop, the scene's anchor is the world (`CFrame.new()`), and every position is a **mark** read live from the set's `Anchors` folder (`C4G_*`, `Roof_*`, prefix dropped; StoryMissions passes them). Scenes keep the as-built values as default `marks`, so they still play if the set moves. Marks now also work in `placePlayer`, `stream` and `shot.focus`.
- **"@Name" turns aim at where that actor *started*.** For someone who has walked, turn to a Vector3 instead.
- Scene list (Config/Chapters → StoryMissions): BackOfHouse (opens "CHAPTER 2 · The Tab"), RoyceSoda, KevKnows (Choice.Kev1), Cash4Gold (Street line), Rooftop, TheTab (Choice.Tab, "END OF CHAPTER 2").
- **Party scenes (LihFolk build list #15).** `CutsceneService.playGroup(players, id, opts)` plays one story beat for a whole party. Everyone gets the same token and a shared start time (`startAt` = `GetServerTimeNow() + 0.8`), so all clients hit frame 0 together. Holding skip casts a **vote**, and the hint shows "2/3 want to skip". The server ends the scene for everyone once enough people vote: both players in a party of 2, otherwise a majority plus one, capped at the whole party. Votes count only 2 s after frame 0, and anyone who leaves stops counting. Only the host (`players[1]`) picks on a choice card. The others see "Waiting for <name> to choose..." and receive the pick through `CutsceneSync`. Remotes: `CutsceneInput` (C→S) and `CutsceneSync` (S→C). StoryMissions is still solo; it switches to playGroup when parties exist.
- **Objective lines** follow verb + target + place and stay under 40 characters ("Meet Kev behind the Food Mart"). Every mission has a one-line hook (`blurb`) for the Story app.
