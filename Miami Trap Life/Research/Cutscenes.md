---
tags: [miami-trap-life, research, cutscenes, camera]
updated: 2026-11-01
---
# Cutscenes (how to make them feel good in Roblox)

Back to [[00 Master Plan]] · Studio-quality camera work: [[Cinematic Cutscenes]] · Related vault notes: [[Claude MCP + Codex Help me create Roblox Skill Cutscene in Minutes Roblox Studio MCP]], `new-game-kit/GAME-FEEL.md` §2 (the "moment" recipe from Huzz Valley).

## What a good RP cutscene does
1. **Short.** Story cutscenes 15–40 s, gags (the power-out PC smash) 8–15 s. Break anything longer into beats with a player action in between. Players decide within the first 90 seconds whether they stay, and long unskippable talk is the top reason they leave ([rowatcher](https://rowatcher.com/news/your-first-90-seconds-are-destroying-roblox-retention)).
2. **Always skippable**, after a 1-second grace (stops accidental skips). Skip = hold the button/key for 0.6 s with a fill ring; a tap only speeds up the current dialogue line. Skipping still gives the reward and advances the story.
3. **The player's own avatar is the star.** Clone the player's character (or use `Players:CreateHumanoidModelFromUserId`) so the gang talks to *them*.
4. **One idea per shot.** Each shot shows one thing: who is talking, or what just happened. Change shot when the speaker changes.
5. **Comedy is timing.** The PC gag: sit → hold 1 s on the dead screen → tiny camera push-in → keyboard smash (3 fast hits, small camera shake, key sounds) → 0.5 s silence → stand, flop on the bed, phone out. The pause before the punchline is the joke.

## Shot grammar (cheat sheet)
| Shot | Use it for | Roblox setup |
|---|---|---|
| Establishing (wide, high) | New place: the motel, the bridge | Camera 30–60 studs out, slow 4–6 s drift |
| Two-shot | Crew member talking to the player | Both in frame, camera at chest height |
| Over-the-shoulder | Dialogue back and forth | Camera behind listener's shoulder, offset (1.5, 1, 4) |
| Close-up | Reaction, punchline (dead PC screen) | FieldOfView 30–40 on the face/object |
| Push-in | Tension, "this is serious" | Tween FOV 70 → 55 over 2–3 s |
| Handheld | Robbery, chaos | Add a small noise to the CFrame (0.05–0.15 studs, 6–10 Hz) |

Movement rules:
- Ease curves: `Sine`/`Quad` InOut for drifts; never Linear on camera (looks robotic).
- Camera moves between shots arc over characters, never through them or through walls (raycast the path; GAME-FEEL §2).
- Cut on action: switch shots at the moment something happens (door opens, hit lands), not in the quiet.
- Keep FOV between 30 and 80; default gameplay FOV 70.

## Polish layer (what makes it look "finished")
- **Letterbox bars** slide in over 0.3 s (top and bottom, ~11% of screen height each). They also hide the HUD area, which reads as "cinema now".
- **Hide the HUD and phone**, lock controls (`UIState.push("Cutscene", {...})`), and restore all of it at the end even if the cutscene errors.
- **Depth of field** (`DepthOfFieldEffect`, FocusDistance on the speaker) and a light `ColorCorrectionEffect` grade per scene (cool blue under the bridge, warm sodium orange in the motel).
- **Subtitles** always, bottom centre above the bar: speaker name in the accent colour + line. Typewriter reveal ~40 chars/s, tap to finish the line.
- **Sound** sells it: room tone/ambience per scene, a short sting on the title card, foley on actions (door, keyboard, bed creak). No voice acting needed.
- **Title card** for a new chapter: "CHAPTER 2 · THE CALL" for 2 s.

## How we build it (code structure)
- Cutscenes are **data**, not code: `ReplicatedStorage/MTL/Cutscenes/GangIntro.lua` returns
  ```lua
  return {
    anchor = "MeetSpot",            -- shots are relative to this CFrame (so the same scene works at any meet spot)
    actors = { Dre = "Rig_Dre", Smoke = "Rig_Smoke", Player = "@player" },
    shots = {
      { t = 0,   cam = CFrame.new(0, 8, 30) , look = Vector3.new(0, 3, 0), fov = 60, ease = "Sine", dur = 4 },
      { t = 4,   cam = "OTS:Player>Dre", fov = 50, line = { "Dre", "So you the new kid from the Food Mart?" } },
      ...
    },
    actions = { { t = 4.2, actor = "Dre", anim = "Wave" }, { t = 9, sound = "CarDoor" } },
  }
  ```
- `CutsceneController.play(id)` runs the timeline on the client with `RunService.RenderStepped` + a clock (not chains of `task.wait`), so **skip = jump the clock to the end** and run cleanup once. This is the clean answer to the classic "how do I skip a cutscene" problem: no coroutine killing, one `finish()` path that always runs (wrapped in `pcall` + `task.defer`).
- Cleanup restores: `CameraType = Custom`, `CameraSubject = humanoid`, FOV 70, effects removed, actors destroyed, UIState popped, controls unlocked.
- NPC actors are client-side clones (local only), so each player's cutscene is private and costs the server nothing.
- Server tells the client to play (`PlayCutscene`) and waits for `CutsceneDone` (with a timeout = scene length + 10 s, then advances anyway).
- Animations: no animation IDs are invented. Use Roblox default emotes/animations where they fit, and list each custom animation (keyboard smash, bed flop, sit at PC) as a `0` placeholder for Alex's animation workflow (vault: [[How to Make Roblox Animations With AI (R6 + R15, Claude Opus 5.5)]]). Until then, use simple procedural poses (Motor6D tweens) so the scene still plays.
- Tools worth knowing: CineCam v3 plugin (build and preview camera shots in Studio without play-testing) — [devforum](https://devforum.roblox.com/t/plugin-cinecam-v3-%E2%80%94-build-preview-camera-cutscenes-live-in-studio-no-playtesting-needed/4713811); CutsceneManager 2.0 — [devforum](https://devforum.roblox.com/t/cutscenemanger-20-%E2%94%81-create-and-manage-cutscenes-in-a-clean-and-organised-way/3635714); Moonlite (plays Moon Animator files in game). We build our own small runner because our scenes must anchor to random meet spots and use the player's avatar.

## The three cutscenes in the first hour
| Scene | Length | Beats |
|---|---|---|
| `GangIntro` | ~35 s | wide establishing of the meet spot → Dre steps out ("You the one from the Food Mart?") → Smoke and Nina intros (one line each, what they do) → the pitch ("Same store. Tonight.") → push-in on the player → cut to black → title card "FIRST JOB" |
| `RobberyOutro` | ~10 s | car pulls away, cash bag on the seat, crew laughs, "Told you." → payout screen |
| `PowerOut` | ~12 s | enters the flat (handheld, flickering bulb) → sits at the PC, presses power: nothing → close-up dead screen, 1 s hold → keyboard smash (3 hits + shake) → stands, flops on the bed → takes phone out → Jobs app opens (straight into the funnel) |

Sources: [CineCam v3](https://devforum.roblox.com/t/plugin-cinecam-v3-%E2%80%94-build-preview-camera-cutscenes-live-in-studio-no-playtesting-needed/4713811), [CutsceneManager 2.0](https://devforum.roblox.com/t/cutscenemanger-20-%E2%94%81-create-and-manage-cutscenes-in-a-clean-and-organised-way/3635714), [Implementing cutscene skipping](https://devforum.roblox.com/t/implementing-cutscene-skipping/924709), [First 90 seconds](https://rowatcher.com/news/your-first-90-seconds-are-destroying-roblox-retention).

## What we built (Piece 3) and what still needs art
- Runner: `Controllers/CutsceneController.lua`; data format documented at its top; example scenes `Cutscenes/GangIntro.lua`, `Cutscenes/RobberyOutro.lua`. Everything is a pure function of the clock, so skip / tap-to-next-line are just clock jumps. `tools/tests/test_story_rules.py` validates every scene (order, speakers, readable line length: typing time + 1 s per 25 chars, FOV 20-80, no Linear camera ease, ≤ 45 s).
- Camera helpers that follow the actors: `two = {A, B}`, `close = A`, `ots = {listener, speaker}`, plus raw `pos/look`. A raycast pulls the camera in front of any wall between it and its target (meet spots are random and the map changes).
- Actors are local clones (crew rigs built by the server from colours; the player's own avatar). Heads turn to whoever is speaking; the speaker looks at the player. Poses are procedural (`Rig.lua`) until real animations exist: paste ids in `Config/Missions.Animations` and gestures play them instead.
- Hand-off trick: scenes with `holdBlack` end on black with controls locked, the server teleports the player, and the next screen (mission tracker, payout) fades the world back in. No visible pops.
- Still needed for a "finished" feel (assets, not code): crew animations (wave, point, lean, phone, hands up), door/engine/alarm/ambience sounds, a crew car model, a mask accessory, and a title-card sting.


## What we built (Piece 4: the Ends)
- `Cutscenes/PowerOut.lua` (~16 s) plays the gag beat for beat: handheld walk-in while the bulb flickers and dies → sit → press power (click, the LED blinks, nothing) → **1.8 s close-up on the dead screen with a slow push-in** (the pause is the joke) → a second press off-screen (just the click) → "Come on. Come ON." → 3 keyboard hits, each with a key sound, a keyboard bounce and a bigger shake than the last → 0.8 s of quiet on a wide shot → stand, flop on the bed → phone out (its screen lights the face) → the scene ends on gameplay with the real you already sitting on that bed, and the phone rises on the Jobs app. No black hand-off needed.
- `Cutscenes/NextDay.lua` (~10 s): bulb off → the window at night → black → "NEXT DAY · 6:58 AM" → fade back in on warm morning light through the boards → phone alarm → stretch → stand. (The runner now fades back in properly after a fade out.)
- **Marks:** a scene can name points of the room ("#ChairSpot", `{ mark = "Screen", off = ... }`) instead of fixed coordinates. The server sends this player's real room points, so when Alex's room replaces the placeholder (different desk or bed spot), the actors and cameras follow it. Every mark is checked by `tools/tests/test_flat_rules.py`.
- The player's thoughts are subtitled as **YOU** (`Story.Contacts.You`), short and dry. Comedy lines are under 40 characters so they read in one glance.
- Still needed for the "finished" feel: bed creak, room tone, a proper keyboard smash and alarm sound, animations for Press / Smash / Flop / Stretch (procedural poses stand in), and a lying-down pose for sleeping (a sit for now).
