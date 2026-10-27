# Welcome and flow: how the best simulators hook a new player in 10 minutes

Research for "+1 Hood Evolution", Oct 27 2026. The owner's complaint: "feels rushed, no flow, no welcoming
traits, the tutorial isn't good". About 40 web lookups: Roblox's own creator docs, DevForum threads, wikis,
guides for the +1 games (Giggity Goo Games' +1 Superhero Evolution, +1 Soldier Evolution), Bee Swarm,
Pet Simulator 99, Grow a Garden, and a viral-dev talk transcript. Sources are listed at the bottom.

How to read the tags:
- **[seen]** means a source in this session said it.
- **[genre]** means it is common across the top simulators, from general knowledge, and wasn't re-checked here.
  Check these against a real play of the game before building on them.

## The big picture in 5 lines
1. **Act first, explain never (or later).** Players decide to stay or leave in about 90 seconds. The first
   real choice should come within 20 s, and one visible goal within 60 s. Text walls and "press W" NPCs drive them off.
2. **One thing at a time, taught at the moment it matters,** not a list of systems up front.
3. **Rewards come fast and big early, then spread out.** There are a dozen cheap wins in the first 5 minutes,
   and the first one comes in seconds.
4. **There is always a next goal on screen,** and a clear "you can do it now!" when one is ready.
5. **Every win gets a celebration.** The tutorial ends on a deliberate "moment of joy".

---

## The ranked patterns (most impact first)

### 1. The first reward comes in the first seconds, from the core action itself
- **What:** the very first click or step gives a visible, loud +1 (number pop, sound, bar moves). There is no menu,
  no loading talk and no popup before it.
- **Who:** the +1 games: click or stand in the Training area and Power ticks up at once [seen, bloxodes].
  The "Candy Crush first match" and "Vampire Survivors readable in 10 s" benchmarks [seen, rowatcher].
- **Why:** the "stay or leave" verdict forms in about 90 s, and a first decision after 20 s is "a problem"
  (after 45 s, "a crisis") [seen, rowatcher].
- **Ours:** spawn facing a lane two steps away. Power ticks in the first 3 s with a pop and a sound, before any hint.

### 2. One visible goal at a time, in the world, not in a quest log
- **What:** a single target the player can see (a glowing door, a beam to it, a big word over it). The next one
  shows only when this one is done.
- **Who:** the "one visible goal within 60 s" rule [seen, rowatcher]. Bee Swarm's Black Bear gives one quest,
  you return, and he gives the next ("Come talk to me again when you're ready") [seen, fandom]. PS99 ranks show
  the quests in a side panel [seen, fandom].
- **Why:** kids don't read lists, and a single target removes the "what now?" pause that feels like "no flow".
- **Ours:** exactly ONE guide on screen at any moment. One arrow trail and one word, never two systems at once.
  (Our code has three guides: Tutorial floor arrows, Onboarding chevrons and Lobby's floor guide. Check in play
  that they never overlap or hand over with a jump. A jump or overlap reads as "rushed".)

### 3. Teach each system at the moment it matters (contextual triggers)
- **What:** don't explain the shop, rebirth and pets at the start. Show the gun shop the first time you can
  afford a gun, and rebirth the first time the bar fills.
- **Who:** the viral-dev talk: "show the food shop when food runs out, trails at 1K cash, plot upgrades when the
  plot is full". Teaching four systems at once "was too much" [seen, sozai]. Roblox docs: "If you must have a
  tutorial, keep it short, contextual, and interactive" [seen, create.roblox.com].
- **Why:** each lesson lands when the player wants it, so it feels like help, not homework.
- **Ours:** the first 2 minutes are train → open the gate → win → cash only. Guns, shoes and rebirth are each
  introduced by a "you can now…" moment the first time it's true.

### 4. Starter gift on arrival (free, honest, no strings)
- **What:** a free item or currency in the first minute, so the player feels the fun of owning something.
- **Who:** Roblox docs: "provide starter items or soft currency so players can enjoy them" [seen]. The viral dev
  pre-stocked food so players skipped the shop at first [seen, sozai]. +1 Soldier gives a welcome code
  ("SOLDIER": potions plus spins), redeemable after the tutorial [seen, robloxden].
- **Why:** owning something early makes the game "yours" and shows what the shop is for.
- **Ours:** keep the welcome present, but give it at a calm beat (after the first gate). Make it a gun or shoe the
  player then uses right away, so the gift is felt, not just collected.

### 5. Low first thresholds: a dozen cheap upgrades in the first 5 minutes
- **What:** the first few goals (Stage 1 gate, first gun, first shoe) are cheap and come in quick succession.
  Later ones space out.
- **Who:** "Give players a dozen upgrades they can afford within the first five minutes" [seen, creation.dev].
  Roblox docs: "keep early XP thresholds low so players level up quickly" [seen]. Black Bear's first quests
  ask 100 → 250 → 500 pollen, small steps [seen]. The viral dev found only 60% bought the first treadmill and made
  it cheaper. D1 retention went from about 7% to about 16% after the progression overhaul [seen, sozai].
- **Why:** the early rhythm ("win, win, win") is what feels like flow. A wall at minute 10 is what kills D1.
- **Ours:** run `pacing.luau` for a fresh player's first 10 minutes. Count goals reached per minute and aim for one
  every 30-60 s at first. Test on a fresh profile, never a progressed one (the viral dev's hidden wall).

### 6. "You can do it now!" nudges (ready-state glow)
- **What:** when a goal becomes possible (afford a gun, gate unlocked, rebirth ready), its button or pad glows,
  bounces or gets a badge. A greyed button means "not yet".
- **Who:** +1 Superhero's Rebirth button is usable only at the exact cap; grey means one level short [seen,
  allthings]. DevForum: players miss that they can rebirth, so "the UI should indicate when rebirth is
  available" [seen]. Red dot or "!" badges on HUD buttons in PS99-style UIs [genre].
- **Why:** it turns a waiting player into an acting player without any text.
- **Ours:** a soft gold pulse (slower than 1 per second) on the Rebirth button and on the next affordable gun pad,
  plus a small "!" on the shop button. Only one pulse at a time.

### 7. Always-on "next goal" bar on the HUD
- **What:** a slim bar or card that always says the next thing and how close you are ("Stage 2 gate: 340/500
  Power").
- **Who:** PS99 quest panel with progress [seen, fandom]. The +1 games' World button shows the next map's need
  [seen, bloxodes]. Roblox docs: "make the next goal and how to reach it clear" [seen].
- **Why:** progress bars make waiting feel like getting closer. It's the main fix for "what now?".
- **Ours:** we have Goals and GoalGuide. Check they always show something, and that the bar fills smoothly instead of jumping.

### 8. Celebrate every milestone (a "moment of joy")
- **What:** a big number pop, a happy sound, a short burst of particles or confetti, the character pose. The end of
  the tutorial gets the biggest one.
- **Who:** Roblox docs: "end onboarding with a deliberate moment of joy: rewards, animations, celebratory visual
  effects" [seen]. The viral dev's first feed made the pet about 5x bigger, an instant "wow" [seen, sozai].
- **Why:** the celebration is the reward the kid actually feels. It also marks "chapter done", which gives a rhythm.
- **Ours:** three sizes of celebration: small (gun bought), medium (gate opened), big (first boss, first rebirth).
  Keep it to at most 1 flash per second, no strobe, and a small or no screen shake (respect ReducedMotion).

### 9. Guidance that is impossible to miss, but never blocks
- **What:** a beam or arrow trail from the feet to the target, a bobbing arrow over it, and an edge-of-screen
  pointer when it's off screen. Short words, typed in.
- **Who:** the DevForum "players are confused" thread: make the beam the most obvious thing, use a clear highlight
  (not a tint), type text in, point at the UI button to press, and move the spawn closer to the first target [seen].
  The arrow and beam tutorial kits sold for Roblox [seen, builtbybit].
- **Why:** some kids have never played a game like this, so the guide has to win against everything else on screen.
- **Ours:** we already do the chevron trail, the bouncing arrow and the edge pointer. The gap is hand-off: one
  colour, one style, from spawn to the end of the first loop.

### 10. Nothing pops up before the first fun
- **What:** no "favourite and invite friends" popup, no daily-reward window, no offers and no settings in the
  first minutes.
- **Who:** DevForum: an instant favorite/invite popup "is annoying" and drives players away [seen]. Rowatcher's
  cut list: "dismissable text prompts", "loading screen monologues", "NPC dialogue walls" [seen].
- **Why:** each popup is a door out. Kids close windows without reading, then feel lost.
- **Ours:** keep the rule that the Retention script shows no daily or offers on a first join. Check the Roblox
  favourite prompt, the group prompt and the code box also wait until after the first rebirth.

### 11. Auto-train / idle progress so play never feels like a chore
- **What:** standing in the training zone gains Power by itself. Clicking only speeds it up. "Equip best" and
  "auto fight" buttons are common.
- **Who:** +1 Superhero: "inside the hub's Training area, Power builds automatically" [seen, bloxodes], and boss
  fights have Auto Fight [seen, allthings]. The DevForum sword simulator added an auto-clicker after playtime sat
  at 3-4 minutes [seen].
- **Why:** kids on tablets get tired of tapping. Auto keeps the numbers moving while they look around.
- **Ours:** lanes already train while you stand in them. Make that obvious in the first 10 s (the number climbs
  without tapping), and let tapping add a visible bonus pop.

### 12. Playtime gifts: a ladder of free rewards for staying
- **What:** a "Free Gifts" button with a row of presents that unlock at 1, 3, 5, 10, 15, 20, 30… minutes of play.
  The first one comes very early.
- **Who:** +1 Superhero's playtime ladder: +2K, +3K, +5K, +10K, +25K, +225K Wins, then an egg, 2x boosts, and a
  final pet [seen, allthings]. PS99 "Free Gifts" [genre].
- **Why:** it gives a reason to stay "just 2 more minutes". It's honest because the time is real play time.
- **Ours:** "Free Gifts" with the first one at 1 minute (a Cash bag), then 3, 6, 10, 15, 20, 30. Show the real
  minutes left. No fake "hurry" wording, no expiring gifts.

### 13. In-session milestone rewards beat daily-login bonuses
- **What:** reward doing things (first boss, 10 gates, first rebirth) more than just logging in.
- **Who:** Rowatcher: daily login bonuses can be "a churn accelerator": players check in, collect and leave.
  Rewards tied to in-session actions work better [seen]. PS99 ranks reward completed quests [seen].
- **Why:** it teaches "this is a game to play", not "a thing to check".
- **Ours:** keep the daily reward (returning players expect it, and it's honest) but small. Put the big free
  rewards on milestones and rank-ups.

### 14. The welcome back after rebirth: point at the new thing at once
- **What:** after a rebirth, a short "you're stronger now: x2!" card, then the guide arrow points straight at the
  lane or stage that just got faster.
- **Who:** +1 Superhero shows the multiplier and what resets before you confirm [seen, allthings]. Higher
  rebirths unlock better training areas, a fresh visible goal [seen].
- **Why:** rebirth feels like a loss unless the very next seconds show the gain.
- **Ours:** we already have "Now go train again!". Add the new multiplier as a big number, and show your training
  speed visibly faster in the first 5 s back.

### 15. Lobby music and a sound for everything
- **What:** a cheerful looping lobby track, a different one in stages or boss fights, and short "pop" or "cha-ching"
  sounds on every gain. There is a mute button.
- **Who:** DevForum: "add sound effects" was top feedback on a 3-4 minute playtime simulator [seen]. Lobby music
  is standard in every top simulator [genre].
- **Why:** silence reads as "dead". Music sets the mood in the first second, before any visual is understood.
- **Ours:** we found a Music setting in the profile, but no music track playing. Add one calm, upbeat hood-style
  loop for the lobby and a punchier one for stages, at low volume, honouring the setting.

### 16. Social proof: other players and a leaderboard in view
- **What:** other players visible training nearby, a leaderboard on the wall, and joining friends allowed.
- **Who:** Rowatcher: "social signals: other players, leaderboards or chat showing the world is alive" [seen].
  Roblox docs: don't block new players from their friends [seen]. Grow a Garden puts farms next to each
  other [seen, naavik].
- **Why:** kids copy what others do. Seeing someone at a stage is the best tutorial there is.
- **Ours:** a Power leaderboard on the lobby wall facing spawn, and a "friend boost" line (we have one).

### 17. Short-, mid- and long-term goals visible from the start
- **What:** show a glimpse of what's ahead (World 2 door, the boss, the top gun) so the kid knows there's more.
- **Who:** Roblox docs: "surface short, mid, and long-term goals" (Jailbreak's season pass example) [seen].
  creation.dev: a hub where locked areas are visible gives visual goals [seen].
- **Why:** "I want THAT" is the hook for day 2.
- **Ours:** the top exclusive gun displayed (locked, with its Power or price) by the gun shop, and the World 2 door
  visible but locked.

### 18. Fresh-account testing and a step funnel
- **What:** log each first-session step (trained, gate 1, cash, gift, gun, rebirth) and see where kids stop.
  Always test on a brand-new profile.
- **Who:** Roblox docs (Player Funnel, A/B test "short dialogue vs guided arrow") [seen]. DevForum: log each
  tutorial step and what players do after [seen]. Viral dev: a wall at minute 10 was hidden by testing on a
  progressed account [seen].
- **Why:** you can't fix the step you can't see.
- **Ours:** `first30` and `core_loop` already walk this offline. Add Roblox funnel events (AnalyticsService)
  for the same steps before release.

---

## Don't copy (banned for us, or not kid-safe)
- **"Limited-time" items to create scarcity.** Roblox's own strategies page suggests it [seen]. Our rule: no fake
  scarcity. Real events with real dates are fine; "only 3 left!" is not.
- **Rotating shop stock you can skip with Robux** (Grow a Garden's seed shop) [seen]. The restock is real, but it's
  FOMO bait. Don't copy it.
- **Dev products that "boost legendary odds"** (creation.dev) [seen]. If we ever sell luck, Roblox requires the
  boosted odds in numbers before purchase [seen, Roblox paid random items policy]. We go further: odds plus a pity
  counter on every paid random item.
- **Spins, keys or tickets that hide what's inside.** Roblox requires all outcomes with % odds before spending,
  shown in view (a bare "(i)" icon is not enough), totalling 100%, and a different path for restricted
  players (`PolicyService.ArePaidRandomItemsRestricted`) [seen].
- **Countdown timers on offers** ("deal ends in 4:59"). Banned: no fake timers. Raid and boss timers that are real
  game schedules are fine.
- **Daily streaks that punish you for missing a day.** They're a guilt hook, not fun [seen, rowatcher]. If we keep
  a streak, missing a day should not wipe it to zero.
- **Flashy celebrations:** strobe, rapid flashes or heavy screen shake. At most 1 flash per second. Keep shake
  tiny and off when ReducedMotion is on.
- **"Hidden better odds for new players".** Refused before (CLAUDE.md lesson 9). Use the visible pity counter.

## Quick wins for our game (from the list, cheapest first)
1. Make sure nothing but the core action happens in the first 10 s (no popup, no hint before the first +1).
2. One guide at a time, in one style, from spawn to the first gun (check the hand-offs in a 30 fps video).
3. Add lobby music and a gain sound (we have the setting, not the track).
4. Add a Free Gifts playtime ladder (first gift at 1 minute).
5. Add ready-glow on Rebirth and on the next affordable gun (slow pulse).
6. Make the first-rebirth return land on a visibly faster lane with a big "x2!".

## Sources
- Roblox creator docs, Onboarding: https://create.roblox.com/docs/production/game-design/onboarding
- Roblox creator docs, Recommended strategies: https://create.roblox.com/docs/get-started/strategies
- Roblox creator docs, Paid random items policy: https://create.roblox.com/docs/en-us/production/monetization/paid-random-items
- Rowatcher, "Your First 90 Seconds Are Destroying Roblox Retention": https://rowatcher.com/news/your-first-90-seconds-are-destroying-roblox-retention
- Rowatcher, "Roblox Onboarding in 90 Seconds or Your Game Is Already Dead": https://rowatcher.com/news/roblox-onboarding-in-90-seconds-or-your-game-is-already-dead
- Rowatcher, "Why Daily Login Bonuses Backfire": https://rowatcher.com/news/reward-schedules-in-roblox-why-daily-login-bonuses-backfire
- DevForum, "Why the players are so confused in my game?": https://devforum.roblox.com/t/why-the-players-are-so-confused-in-my-game/3885660
- DevForum, "Why is playtime so low?": https://devforum.roblox.com/t/why-is-playtime-so-low/2771140
- DevForum, "How to improve player retention": https://devforum.roblox.com/t/how-to-improve-player-retention/2574477
- Viral-dev transcript, "I Made 3 Viral Roblox Games in a Row": https://sozai.app/transcript/made-3-viral-roblox-games/
- +1 Superhero Evolution guides: https://bloxodes.com/articles/1-superhero-evolution-beginner-guide and https://allthings.how/1-superhero-evolution-how-to-rebirth-fast-in-roblox/
- +1 Superhero Evolution stats: https://rowatcher.com/games/10577588270/1-superhero-evolution
- +1 Soldier Evolution codes and description: https://robloxden.com/game-codes/1-soldier-evolution
- Bee Swarm Simulator, Black Bear: https://bee-swarm-simulator.fandom.com/wiki/Black_Bear
- Pet Simulator 99, Ranks: https://pet-simulator.fandom.com/wiki/Ranks_(Pet_Simulator_99)
- creation.dev simulator guide: https://www.creation.dev/blog/roblox-simulator-game-guide
- Naavik, "Predicting the next big hits on Roblox": https://naavik.co/digest/predicting-the-next-big-hits-on-roblox/
- Grow a Garden beginner guide: https://thebackdash.com/gaming/roblox-grow-a-garden-beginner-guide/

Not found in this pass: a frame-by-frame account of +1 Soldier Evolution's own first minute (no video page with
chapters turned up). Muscle Legends, Arm Wrestle and Strongman guides only had code lists. The owner's own play of
the reference is still the best source for the exact first 60 s.
