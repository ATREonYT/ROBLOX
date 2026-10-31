# Making a Roblox game feel good

Lessons from building Huzz Valley with the owner. Read this before building any new game. Each point
is something we got wrong first and then fixed.

## 1. Copy the reference loop exactly, then add your twist
- When the owner names a game ("like Huss Valley"), get a screen recording first. Pull one frame per
  second, plus sharp frames of the key moments (`ffmpeg -ss <t> -frames:v 1`).
- Write the loop down as phases, with who can move in each one and what text shows. Do this before
  writing any code.
- Build that loop one to one. Put the game's own idea (here, the anime girl) on top of the loop,
  never instead of it.
- Our first loop was invented ("first across gets her"), and the owner called it "ehh". The copied
  loop (line-up, Chicken or Hero, solo Hero run, rescue, 3 in a row) is what they wanted.

## 2. Every round needs a "moment"
- Start each round with a short cinematic:
  - all players lined up;
  - the camera sweeps along them;
  - a highlight hops between them and lands on one (random, but every screen must agree);
  - zoom in on that player, who makes a choice with a visible timer (random if no answer);
  - show the choice big over their head;
  - glide the camera back to the player.
- Freeze players during it (WalkSpeed 0) and put them back on their spot if anything moves them.
- Black bars, one sound per hop and a whoosh on the zoom make it feel finished.
- Camera moves between shots must arc up and over the players, never straight through them. Check
  this on a rendered video, not in your head.

## 3. One message line tells the story
- Keep one big outlined line at the top centre with the latest event, in the event's colour:
  - green: someone reached safety or was rescued;
  - red: someone was caught;
  - gold: the prize.
- Above it, show the round number. Below it, show your role and the time left.
- Keep copy short and punchy, like "Messi reached safety!". No dashes and no long sentences.
- Big centre banners are only for big moments: 3-2-1-GO, SAFE!, YOU'RE DOWN!, the win.

## 4. People over everyone's heads
- Name tags with a coloured role title, the name, and "Lv. 6 · 8 wins". Hide Roblox's own name.
- Use faint team outlines: red catchers, blue runners, yellow Hero, green safe.
- Give status on the tag, for example "HELP!" with a rescue bar on downed players.

## 5. Second chances keep kids playing
- Being caught should not end your fun straight away: lie down where you fell, and let a teammate
  rescue you by standing next to you.
- Give rescued players a short safety window (2 s), or camping catchers make them loop forever.
  The bot simulation found this.
- Hand out small rewards often, such as coins for a brave choice.

## 6. Controls that feel sharp
- In rounds:
  - shift lock with no mouse pointer; hold Alt to get the pointer back;
  - no jumping;
  - Space dashes in any direction.
- Free the mouse whenever a choice or window is on screen.
- Running uses a hunched sprint with high knees, blended in by speed. Copy the reference's pose from
  its video.

## 7. Small, premium UI
- Keep the buttons small: the owner asked for smaller ones twice. Start small.
- Use one chunky display font (Luckiest Guy) for big words and one round font (Fredoka One) for lines.
  Give both a dark outline and a soft drop shadow.
- Colour each choice by meaning: gold Hero, cream Chicken, red catcher. The picked card gets a white rim
  and a "PICKED" tag; the other one dims.
- Never more than one flash a second, no fake timers, and odds always shown (kid-safe rules in
  `CLAUDE.md`).

## 8. Prove it before the owner sees it
- Keep the rules in a pure module with unit tests.
- Run a full-game bot simulation that plays many games. It must check that:
  - stages go in the right order;
  - nobody moves when they shouldn't;
  - both sides win sometimes.
- Keep camera shots as pure maths, so an offline video films exactly what the game does.
- Get a fresh critic before showing anything, and judge motion on a 30 fps video.

## 9. Measure the feel against the reference, number by number (Oct 17 feel study)
- Film the reference and our game, then measure: steps per second, seconds to full speed, huss length and distance,
  character height and horizon as a fraction of the screen, HUD text height, floor brightness and clipped pixels.
  `huzz-valley/docs/feel-study.md` is the worked example; its scripts are in `huzz-valley/tools/preview/feel/`.
- What made Huss Valley feel good, measured:
  - **A calm camera:** locked behind you (character ~33% of screen height, horizon ~30% from the top), no zoom pulse
    when sprinting, shot changes are one 0.2-0.3 s swing over heads, never through walls.
  - **Instant movement:** full speed in ~0.5 s, ~4.6 steps a second, a huss of ~0.3 s and ~10 studs that slows down,
    with a few white speed lines and no shake.
  - **One coloured message line, nothing in the middle:** text ~3.5% of screen height, no panel, instant swap; big
    centre words only for 3-2-1, GO, SAFE, OUT and the win, and never on top of your own character.
  - **Mid-tone ground:** floor brightness ~0.6 with few clipped pixels. A blown-out floor reads as "bland", even
    with more saturation.
  - **Effects with timing:** wind-up, one bright frame, the effect, a fade. One effect per event, not a pile-up.
- **The world sells the game:** a lobby that's a whole place (foreground, middle ground, background), no visible
  void or platform edges, decorations clustered around attractions, scenery round the field's edge only.

## 10. Make sure the owner is testing the newest code
- A Studio recording that shows old behaviour usually means old code ran: Rojo connected to an out-of-date copy of
  the repo puts the old scripts back over the downloaded place. Ask the owner to Pull in GitHub Desktop (right
  branch) before connecting Rojo, or not to connect Rojo when testing a downloaded file.
- Stamp every build: Huzz Valley shows "build <date>" small in the corner in Studio (`Config/Build`, written by
  `build_place.sh`), so any recording tells you which code ran.

## 11. Tiered stations read as one system
- Build one lane model and clone it for every tier. Colour the whole lane in the tier colour, give each
  lane one label at the same height and make higher tiers fancier. The full rules are in
  `Build Playbooks/Lesson - Tiered Training Lanes.md` (from Stone Skipping, Oct 31).
