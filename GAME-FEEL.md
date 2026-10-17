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
