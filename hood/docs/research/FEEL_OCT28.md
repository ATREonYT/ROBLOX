# Feel audit, Oct 28 (HEAD 76004336)

The owner, comparing us with the +1 games: "ours feels packed up, rushed, not well made ... add the nice effects that
they use, add the good fighting animations ... if the animations and core loop feel fine then it's okay."

This file is the audit (worst first), what this round changed for each point, and what is still weaker than the
reference. The fixes are listed under "Done this round" at the end.

## How this was measured

- **Play:** the real server and client scripts in the offline harness, on first30's route (`tools/checks/route.luau`):
  the welcome, BAY 1, the walk to Stage 1, the fight, the pad, the ARMORY and Stage 2. It was recorded frame by frame
  at 30 fps (`tools/preview/ui/firstvideo.sh`), the whole first 40 s before the change, and game frames 400-760 (the
  fight and the pad) after it.
- **Pictures:** the hall is drawn by render14. The screens, and now also the world's billboards (the "+N", the hit
  marks, the goons' tags, the new stars and rings), are drawn by ui/index.html. The billboards are new in the
  recorder; before this round they were missing from every offline video.
- **Compared with:** `docs/refs` ref_V1 (the death pile), ref_V5 and ref_W00/W01, and the research notes
  WELCOME_AND_FLOW.md, OUR_FIRST_10_MIN.md and CRITIC_OCT27.md.
- **What the offline pictures can't show (only Studio can):**
  - your own avatar and its swings (a blocky stand-in is drawn);
  - the real R15 goons (the box-built GoonRig stands in, because the harness can't build avatars);
  - particles (the sparks and the confetti);
  - Highlight tints;
  - the camera's FOV kick and shake;
  - sound (`Config/Sound.Enabled` is false).

## What makes ours feel packed, rushed or cheap, worst first

1. **The game is silent.** `Sound.Enabled = false`, so no shot, hit, knock-out, Cash or gate sound plays. Of
   everything here, this is the biggest single reason a fight feels cheap. Every effect below lands without a
   sound, and the +1 games are loud.
   - Not fixed here: the sound needs the owner's sound pass (which sounds, uploaded by the owner).
   - The hooks already exist: `ShotSounds.play('Shot' / 'Tock')`, and the knock-out now plays a Tock that rises in
     pitch with the streak.
2. **Hits don't land.**
   - A shot put a 3-frame white X and a tiny star on the goon, and the goon barely moved (`STAGGER = 0.22`: brief 30
     matched it to reference stills where the guards show no stagger).
   - A swing was the same with a swoosh.
   - Nothing froze, nothing squashed, there was no spark on the body and the camera did nothing. Shooting a crew
     felt like shooting scenery.
3. **The knock-out has no payoff.** It was a 0.28 s fall, a darkened heap and a puff of brown dust. There was no
   beat on the hit, no bounce and no reward you could see. The Power went up in the corner while you looked at the
   crew.
4. **The fight is short and flat.**
   - Stage 1 is 3 goons with 2 hits each, about 3 s from the first hit to CLEAR! (frames 500-585).
   - There's no build-up between the hits and no feeling for clearing a crew fast: no streak, no combo.
   - The crew's HP was not changed: the balance numbers are the owner's, and the flow round already made Stage 1
     tougher.
5. **Four voices at the fight's door.** At the Stage 1 gate (before, frame 330) these were all on screen at once:
   - "CREW INCOMING!";
   - "3 LEFT";
   - "Hold click to shoot!";
   - the tutorial's stale "Go to STAGE 1!", though you're already through the gate.
6. **The trip back from a pad is a hard cut.** You step on the pad and the camera jumps 94 studs to the lobby spawn in
   one frame. The World window's trips cut the same way.
7. **Things snap on and off.**
   - The shoot hint, the "N LEFT / CLEAR!" chip's exit and the goal line coming back after a fight all appeared or
     vanished in one frame.
   - The goons' HP tags still do: their `Enabled` is switched with no fade (see below).
8. **World labels crowd the fight.** The two pads' boards ("+200 Cash / 10x Cash" and "+20 Cash / Return") stand at
   eye height on both sides of the crew, so the fight is framed by two price signs. The critic found the same:
   "the clutter is world labels", not the HUD.
9. **The camera sits on top of the scrum.** In melee the goons stand right on you. From Roblox's follow camera your
   body covers them, and their tags pile up over your head (before, frame 520). Only Studio shows the real camera.
10. **HUD at phone size.** The phone shot (844 x 390, with a notch) is no more crowded than the reference's. One
    overlap was flagged: the shoot hint sits on the goal line. In a real fight the goal line steps aside, so this
    only happens in the preview scene. No HUD layout was changed this round: the UI agent owns it.

## Done this round

- **Hits** (`Waves.client`, `Shared/FightJuice`, `Shared/FightFX`):
  - A hit now rocks the goon: the stagger is up from 0.22 to 0.5.
  - It squashes for 0.28 s: a quick dip, its knees giving (`FightJuice.squash`).
  - Sparks fly in the gun's colour (`Juice.burst`).
  - The goon gets a soft tint (`Juice.flash`). It is white at most once a second, through FlashGate; the hits in
    between get the warm tint.
  - A swing also holds both of you on the hit frame for 0.06 s (hit-stop, `CharMotion.hitStop`) and thumps the
    camera's FOV by 0.9 degrees.
- **Wind-up:** a warm glint over the goon's head as it draws back (`FightJuice.glint`), so a kid sees the punch
  coming.
- **The knock-out:**
  - a 0.09-0.11 s hit-stop, then the throw;
  - a gold ring of light and a puff of smoke (`koBurst`);
  - one bounce off the ground (`bounce`);
  - three gold stars circling its head for 1.3 s (`dizzy`);
  - 3-7 Power orbs that burst out of it and fly into your Power counter, which bumps as they land (`orbs`);
  - a small camera shake (`Juice.kick` 0.3-0.45) and an FOV thump (1.6-2.2 degrees, capped at 3).
- **The "+N":** it pops bigger (0.3 to 1.22 to 1, a swing's to 1.35) and arcs out to the side and up 1.4 studs on an
  eased curve.
- **Streaks:** knock-outs each within 2.5 s of the last say "DOUBLE KO!", "TRIPLE KO!", then "KO xN!" in gold over the
  fight, below the top band (the counter, "CLEAR!" and the hint keep that band to themselves), and the orbs grow with the streak. A cleared crew throws gold confetti over you. The streak is only shown:
  it pays nothing extra, so nothing is promised that the server doesn't pay.
- **Your fight moves:**
  - `Config/Animations` has `Punch` and `Kick`. Your swings go Punch, Punch, Kick (`CharMotion.melee`) and play the
    owner's uploaded move at Action priority (`AnimationRules.oneShot`).
  - While an id is empty, the drawn swipe and hook stand in.
  - Hit-stop holds either one on the hit.
- **One voice:** the shoot hint waits while "CREW INCOMING!" is up. It eases in and out every frame, so it can't
  get stuck on screen (the first recording of this round caught it stuck after a fight, back in the lobby).
- **No hard cuts:** a pad's trip back now happens under a 0.2 s dip to night blue (`Shared/ScreenDip`). The server
  moves you 0.24 s later (`StageRules.DipFor`), the dip lifts in 0.35 s, and the pad's Cash flies into your Cash
  counter as green orbs. The World window's trips dip the same way. It's never white and never a flash.
- **Nothing snaps:**
  - the "N LEFT / CLEAR!" chip shrinks away;
  - the goal line fades back up after a fight or a moment;
  - the shoot hint fades.
- **The offline recorder now draws the world's billboards.** Billboards were missing from every earlier offline
  video. Short effects also used to vanish between the slow frames: Debris now runs on the recorder's frame clock.

## Proof

`hood/art/renders/feel-oct28/stage1_fight.mp4` (30 fps, 9 s, the offline recorder and render14): CREW INCOMING!, the
wind-up glints, hits with sparks and the arcing "+1", knock-outs with the ring, the bounce, the dizzy stars and the
Power orbs flying into the counter, DOUBLE KO! / TRIPLE KO!, CLEAR! with confetti, then the pad's trip back under the
dip. Render round 2 of 2. The renderer draws a blocky avatar, no particles and no camera FOV or shake.

## Checks in this container (Oct 28)

All pass except four core_loop wall-time checks (training within 1.5 s, Power every second, the counter ticking,
training stops within 1.5 s) and first30's "the tutorial hint over NEW GUN! at most 3 ticks" (4-5). The same five fail
on the untouched HEAD 76004336 in this container at the same time (another agent's harness was using a core), so they
are the machine's load, not this round. Re-run them on a quiet machine before merging.

## Still weaker than the reference (honest)

- **Silence.** It is the biggest gap, and it needs the owner's sound pass.
- **The fight is still short** (about 3 s for Stage 1). The new juice fills those 3 s, but there is no rising danger.
  Making it longer would mean changing the owner's Balance numbers, so it was left alone.
- **The world labels by the crew** (the two pad boards) still frame the fight, and the "TRIPLE KO!" chip lands on
  their row in the video. That's a map change, for a later round.
- **The goons' HP tags still switch on and off with no fade.**
- **Your own swings** are the drawn ones until the owner uploads Punch and Kick, and they were never judged in
  Studio. The offline video draws a blocky stand-in.
- **Not checked in Studio:** the real R15 goons' squash (crouch), the Highlight tint, the camera's FOV thump and shake,
  and the sparks and confetti particles.
