---
tags: [build-playbooks, roleplay, social, fun, party, hangout]
updated: 2026-11-01
---

# 26 Fun and Roleplay Playbook

Back to [[00 Build Router]] · Build it: [[Blueprint - Roleplay Town]] · Pick a game: [[Game Concepts - RP and Fun]] · Taste: [[09 Owner Taste Rules]]

**Load this for any roleplay (RP), hangout, party or "fun with friends" game.** It is what makes those games *fun*, not only what keeps players. Simulators (+1, eggs, RNG) are fun alone; these games are fun because of the other people. That changes almost every design rule we use.

Older, deeper notes this builds on (grep, don't read whole): `LihFolk/LihFolk Vault V2/10 Game Design and Genres/Genre Playbook - Roleplay and Social Hangouts.md`, `Social Design and Multiplayer Play.md`, `Genre Playbook - Open-World City and Crime Roleplay.md`, `Genre Playbook - Social Deduction and Murder Mystery.md`, `Genre Playbook - Party and Minigame Collections.md`, `32 Case Studies of Top Roblox Games/Case Study - Brookhaven RP.md`, `Case Study - Adopt Me.md`, `Case Study - Jailbreak.md`, `Case Study - Dress to Impress.md`, `24 Worked Builds/Weekend Build - Roleplay Town with Jobs and Paychecks.md`, `33 Level Design/Instanced Interiors - Pooled House and Room Copies for Many Players.md`, `59 Viral and Trend Game Teardowns/Teardown - Fling Things and People.md`, `Teardown - Natural Disaster Survival.md`, `Teardown - PLS DONATE.md`.

Kit code: `new-game-kit/src/Server/Roleplay.luau` (job caps, pay for work seen by the server, one house each with guests and kick, house locking off by default for the age rules, car caps, prop caps, short jail) and `new-game-kit/src/Shared/Interact.luau` (one server check for every "press E"). Specs in `new-game-kit/tests/`.

> [!warning] Age rating decides who can even find the game
> Under the 2026 rules ([[Policy and Age Rules 2026]], Sector Brief Game Design §11): a game that Roblox classes as a **social hangout is 16+**, and a **hangout with private spaces (lockable rooms, bedrooms, bathrooms, stalls, tents) needs ID-verified 18+**. Hangouts are also excluded by default from Roblox Kids (5-8) and Select (9-15). So a kids' RP game must be **gameplay-first, not a hangout**: jobs with tasks, events, rounds, a pet or rank to raise. Chatting is a side effect, never the main purpose. Every new game also starts 16+ only until it passes selection (Sector Brief Game Design). Check this on day 1, before the map.

## 0. The one-paragraph version
A fun social game hands players **toys, a stage and a reason to meet**, then gets out of the way. Toys are things that do something funny or satisfying when you press them (a car horn, a door that slams, a fling, a costume swap). The stage is a small, readable map full of places that suggest a story (a school, a hospital, a police station, a beach). The reason to meet is a light goal that needs other people (a job someone else uses, a round with roles, a vote, a trade). Make every toy work in one press, make other players visible and loud, keep rounds or goals short, and let players' own stories be the content. Safety is not a side system in this genre: it is the floor the whole game stands on.

## 1. The chart: who is winning in social and RP (live check, 2026-11-01)
| Game | Playing now | What it really sells |
|---|---|---|
| Brookhaven RP | ~367K (record 1.29M, Dec 2025) | instant free house, car and props; a film set for your own stories |
| Adopt Me! | ~185K | raising and trading pets with friends; the dream-pet chase |
| Murder Mystery 2 | ~450K (Oct 25) | 2-3 minute rounds with secret roles; knife and gun trading |
| Dress To Impress | ~52K | timed theme, dress up, everyone votes, podium |
| Berry Avenue / LifeTogether / Dubai RP | 14-26K each | career RP, fashion, an in-game phone and social app |
| Bloxburg | ~13K | build your own house; needs and jobs (depth over reach) |
| Raise The Biggest Family, Dreamville, Gacha Online, Emergency Hamburg, Royale High | 7-13K | one twist each: family size, pets, anime avatar, emergency services, school fantasy |
| 99 Nights in the Forest, DOORS, Dandy's World, Forsaken | big | co-op or asymmetric horror: fear is fun shared |

Sources: [RoWatcher roleplay genre](https://rowatcher.com/genres/Roleplay%20%26%20Avatar%20Sim), [RoWatcher RP showdown](https://rowatcher.com/news/brookhaven-vs-berry-avenue-vs-lifetogether-the-2026-roleplay-showdown), [Endgame Tools charts](https://endgametools.com/en/roblox/charts). Counts move daily; use them as a ranking.

**Read of the chart:** RP is the biggest *genre* on Roblox (over 100M daily visits across RP games), but it is the hardest to break into because friends stay where their friends are. The newer winners (LifeTogether, Dubai RP, Raise The Biggest Family) all got in with **one sharp twist on the same town**, shipped fast. A plain "another Brookhaven" has almost no chance.

## 2. What "fun" is made of in these games (the ten ingredients)
Score a design against these. A hit has at least five.

1. **Toys before goals.** Every object answers a press with something satisfying: honk, siren, door slam, sit, dance, flip a light, ring a bell, spray a hose, launch a firework. Brookhaven has almost no goals and huge play time because every prop is a toy.
2. **Instant ownership.** Within 10 seconds you have *your* thing: a house, a car, a pet, an outfit. Brookhaven gives a house and car at the start; Bloxburg made you earn it and stayed small.
3. **Other people are the content.** Players watch, chase, help, prank and copy each other. Design so actions are **visible from far away** (big name tags with the job, siren lights, a glow on the rare pet, a podium).
4. **Roles that need each other.** A cop needs a robber, a doctor needs a patient, a shop needs a customer, a murderer needs innocents. Every job should create a reason for a *different* player to come over.
5. **Short loops with a reset.** MM2 rounds last a couple of minutes, DTI a few minutes per theme. A short round makes losing cheap, makes clutch moments feel earned, and fits kids hopping between games. Build rounds on kit `Rounds.luau` ([[32 Round-Based Games Playbook]]).
6. **Secrets and surprise.** Hidden roles, mystery boxes, an event that changes the map, a rare pet in the egg. The unknown keeps the chat buzzing.
7. **A stage that suggests stories.** A school with a principal's office, a hospital with a stretcher, a bank with a vault. Each place hands players a script without words.
8. **Show-off moments.** A podium, a runway, a parade lane, a garage door that opens on your car, a pet that flies. Status is the reward kids chase most in social games.
9. **Gentle chaos.** Flinging, ragdolls, slippery floors, disasters, a stampede of pets. Laughter comes from physics going slightly wrong *for everyone at once*. Keep it opt-in and never trap a player.
10. **Clip-worthy beats.** The reveal, the betrayal, the vote result, the disaster. Moments (Roblox's short video feature) and YouTube/TikTok "RP movies" bring new players for free. Put a clean camera and a sound sting on every big beat.

## 3. Per-game lessons, in our own words (what to learn, not copy)
- **Brookhaven: breadth and zero friction.** No tutorial, no currency grind, a free house, car and job title in seconds, dozens of houses and vehicles, new props almost weekly, events that reshape the map. Players treat it as a film set. Lesson: **the toy box beats the progression bar** for under-12s, and a weekly drop of new toys is the retention system.
- **Bloxburg: depth and effort.** Needs meters, real jobs, build-your-own house on a plot. Smaller and older audience, very loyal. When it went free it spiked to ~352K and fell to ~19K within two months: free players without an invested goal don't stay. Lesson: **depth must be reachable in the first session**, not after hours.
- **Adopt Me: the pet is the friend you show off.** Raise a pet with simple care tasks, age it up, combine copies into a glowing version, trade. Limited event pets keep their value because supply stops. Lesson: **effort you can see** (a glow that says "I raised four of these") is the strongest status signal, and a "dream item" chase lasts weeks.
- **Murder Mystery 2: roles, tension, short rounds.** Three roles with different skills (hide, deduce, survive), a lobby between rounds where groups form and trades happen, cosmetics that never change who wins. Lesson: **cosmetic-only power** keeps a social game fair and still sells.
- **Dress To Impress: create under a timer, then everyone judges.** Theme, short build window, runway, vote, podium. Adults and streamers play it too. Lesson: **a timed creative task + a public vote** is the most reliable "fun with strangers" loop on Roblox, and it needs no combat.
- **LifeTogether: the in-game phone.** Messages, a photo app, house and car management from a phone menu. Lesson: a **phone as the main menu** feels natural in RP. Warning: its photo feature was misused; anything players can create and share needs moderation (see §9).
- **Berry Avenue: careers and fashion, light on money.** Students, police, hospital staff, shop workers; no in-game currency. It locked its clothing catalogue after bad user-made items flooded in and said it would rather keep a quarter of its players and moderate properly. Lesson: **decide moderation scope before launch**.
- **Jailbreak: cops vs robbers with a chase.** Escape, rob, get chased, get caught, try again. Lesson: a **chase is the best free content** in a city game, and vehicles are the expensive system (see §8).
- **Fling Things and People / Natural Disaster Survival: physics as comedy.** Grab and throw anything, or survive whatever the map does this round. Lesson: **shared chaos** makes strangers laugh together without chat.
- **99 Nights, DOORS, Dandy's World: fear is fun with friends.** Co-op survival where friends split jobs and scream together. Lesson: **"we survived" is a social reward** as strong as loot.
- **PLS DONATE: social status as the whole game.** A booth, a sign, generosity shown publicly. Lesson: **public kindness counters** (helped 12 players, gave 30 gifts) are status kids like.

Sources: [Bloxburg vs Brookhaven](https://rowatcher.com/news/bloxburg-vs-brookhaven-two-visions-of-roblox-roleplay), [RP games rule Roblox](https://rowatcher.com/news/roleplay-games-rule-roblox-adopt-me-and-brookhaven-command-900k-players), [MM2 design](https://nichegamer.com/mm2-on-roblox-and-why-it-still-pulls-in-millions), [DTI on Dazed](https://www.dazeddigital.com/fashion/article/64382/1/what-is-dress-to-impress-why-is-everyone-so-obsessed-viral-fashion-game-roblox), [Adopt Me trading culture](https://www.gfinityesports.com/article/adopt-me-pet-trading-culture-how-players-judge-rarity-demand-and-dream-pets), [Game Developer: socialization](https://www.gamedeveloper.com/design/roblox-devs-say-socialization-is-what-makes-the-creator-led-sandbox-tick), [DevForum: why RP is popular](https://devforum.roblox.com/t/what-makes-these-rp-games-so-popular/2651246).

## 4. Roles and jobs that make fun (not chores)
- **Every job has a verb, a tool and a customer.** Firefighter: spray (hose) a burning prop that the server sets alight every few minutes. Doctor: scan, bandage, wheel a patient on a stretcher. Chef: flip, plate, hand over. Police: chase, cuff, drive to the station. If a job has no customer, it is a costume, and that is fine too (Brookhaven), but say so.
- **A job is 3 presses deep, not 30.** Pick up, do, hand over. Each press gets a sound and a small pop. A full "shift" mini-task is 20-60 s.
- **Pay for work the server saw, not for time standing still** (kit `Roleplay.Paycheck`, every 180 s). A kid who served 4 customers earns more than a kid who idled.
- **Job caps keep the town mixed** (kit `Roleplay.CanJoin`): e.g. police ≤ 25% of the server, criminal ≤ 25%, everything else open. Show the cap on the job board ("Police 4/6").
- **Big, colour-coded job tags** over heads and a matching outfit, so a kid can find "a doctor" from across the map.
- **Self-serve events** keep jobs alive with few players: a fire every few minutes, a bank alarm, a lost pet, a delivery order. An empty town still has something to do.
- **No jobs that kids can use to grief:** no jail longer than 60 s (kit clamps 10-60 s), no forced arrests on players who didn't pick a crime role, no "kidnap" or carry-away of unwilling players.

## 5. Customisation and expression
- **Avatar editing in-game** (outfits, colours, accessories) is the #1 thing RP players do. Use Roblox's built-in avatar systems and catalog where we can; see [[03 What's New on Roblox - RDC 2026 and October]] for current APIs. Never build a user-uploaded image or drawing feature without moderation (see §9).
- **Presets, not sliders.** Kids pick from 8 good outfits per job faster than they tune 20 sliders.
- **Emotes and poses** are the "voice" of kids who can't chat (since Jan 2026 most kids can't chat with strangers until an age check). Give 12-20 emotes on a wheel, plus sit, lie, wave, point, clap.
- **Quick Words:** set game-specific Quick Words in Creator Hub (up to 3 groups of 3-10 phrases, reviewed by Roblox): "Need a doctor!", "Taxi?", "Follow me!", "Nice outfit!". This is how kids talk in 2026.
- **House and car colours, name plates, a door bell sound, a garden.** Small choices that make *mine* visible to others.

## 6. Houses (the home is the heart)
- **One house each, claimed at the start, free.** Premium houses are a look, not a power (bigger windows, a pool, a garage that opens).
- **Guest list, kick, release on leave** (kit `Roleplay` house book). **House locking is off** in the kit (`Houses.LockingAllowed = false`, `SetLocked` returns `"LockingOff"`) because lockable private rooms push a hangout to 18+. Owners control their house with guests and kick instead; houses start unlocked. Only turn locking on after a rating check says the game is not a hangout.
- **Furniture props with caps** (kit cap 40 per player) so one player can't lag a server.
- **Keep homes daytime and public-feeling:** big windows, a front garden, a porch. Roblox's Aug 2025 policy put hangouts that depict private spaces behind ID verification, and the 2026 table makes that **18+** ([[Policy and Age Rules 2026]]). A bed in a dollhouse-style home isn't the target, but the overall scenario is judged. For a kids' game, make homes about *play* (kitchen, garage, pets, garden, playroom), with **no bedrooms, no bathrooms and no lockable rooms**.
- **Instanced interiors** (one copy of the inside, many doors) save memory: see `Instanced Interiors - Pooled House and Room Copies for Many Players.md`.

## 7. Social systems after the 2026 age checks
- **Most young players can't free-chat with strangers.** Since early January 2026, chat needs a facial age check, and players only chat with similar ages. Design every interaction to work **with no chat at all**: emotes, Quick Words, proximity prompts ("Ask for a ride"), pings, pointing.
- **Friends are the core.** Reward joining a friend (a shared bonus, a "came with friends" badge), make "join friend" obvious, give private servers a fair price.
- **Party up in two taps:** a "Group" button that keeps friends on the same team, car, house or round.
- **Show the crowd:** a busy plaza near spawn, a stage, a parade route. Players should see others in the first 5 seconds.
- **No social media links in the game** (banned from early 2026). Point players to the game's Roblox community instead.
- Don't build a chat-heavy feature that needs age checks for a kids' game; `Player:PromptAgeCheck()` exists but our audience won't pass it.

Sources: [Roblox age-check rules](https://about.roblox.com/newsroom/2025/11/roblox-requires-age-checks-limits-minor-and-adult-chat), [Roblox private-spaces policy](https://about.roblox.com/newsroom/2025/08/extending-roblox-policy-on-romantic-and-sexual-content).

## 8. Vehicles (the expensive system)
- **One car each** (kit), server cap ~20 in a 30-50 player town, a 10 s cooldown, and "Replace" when the cap is hit. Despawn cars nobody has sat in for 2 minutes.
- **The driver's client simulates the car** (network ownership to the driver) so it feels instant; the server checks speed and position every so often and resets cheaters. Same rule as our speed games: [[18 Studio-Level Development Playbook]].
- **Arcade handling, not realism:** fast start, strong grip, a little drift on a hard turn, a hop over curbs, no flipping (auto-right after 1 s). Horn, siren and lights on one key each.
- **Seats for friends.** A car is a social object: 4 seats, the driver chooses the music (from Roblox's licensed library).
- **Fun vehicles beat fast ones:** a giant shopping trolley, a bouncy castle truck, a pizza scooter with a delivery box, a fire truck with a working ladder.

## 9. Safety is the floor (non-negotiable for kids)
- **Roblox auto-shuts servers with a high volume of violative behaviour** and then works with the developer on changes. A game whose servers keep getting shut down dies. Design out the risky scenarios up front.
- **No user-made images, drawings, signs or photos** shared with others unless they pass Roblox's own moderation. Text on signs only through `TextService` filtering.
- **No private or lockable spaces.** No bedrooms, no bathrooms, no lockable rooms, no "date" or romance actions, no carry/kidnap emotes, no cuddling poses.
- **Block and mute work instantly in-game,** a "Report" button sits in the menu (Roblox's built-in report), and a kicked guest can't come back into that house this session.
- **Anti-grief:** no damage to players outside opt-in rounds, flings only in a fling zone or minigame, cars pass through players on sidewalks, jail ≤ 60 s.
- Run `python3 tools/kidsafe_check.py <game>` and the questionnaire in [[Policy and Age Rules 2026]] before launch.

## 10. Retention that fits social games
- **A new toy every week** (a vehicle, a house, a prop pack, a job tool) is the main retention system; the Brookhaven model. Plan 6 weeks of drops before launch.
- **Map-changing events:** snow, Halloween fog, a carnival on the plaza, a parade. Changing the stage restarts everyone's stories.
- **One long chase per player:** a pet to raise to its glowing stage, a house to finish, a collection book of outfits, a job rank (Rookie → Chief). Visible to others.
- **Daily small things:** a daily gift at your mailbox, a "today's job bonus" (doctors earn 2× today), a rotating shop.
- Reuse our kid-safe return hooks: [[21 Money and Retention at Studio Level]] §6.

## 11. Money (kid-safe, our rules)
- **Sell looks and toys, never power over other players.** Premium houses, vehicle packs, outfit packs, emote packs, a pet pack, a fun job tool (a confetti cannon for the party planner). No "VIP" anything ([[09 Owner Taste Rules]]); the top pass just looks the best.
- **A la carte gamepasses beat a subscription** for kids (LifeTogether's monthly sub is the most disliked model). Brookhaven's whole catalogue is ~5,700 Robux spread over many small passes; Berry Avenue sells far less and is "friendlier" but earns less.
- **Private servers at a fair price** are a must for friend groups and RP "movie" makers.
- Prices and ladder rules: [[21 Money and Retention at Studio Level]].

## 12. Polish and feel for RP (our premium layer applied)
- **The door test:** walk to a door, press E, it swings with a spring (not a snap), a creak plus thud, a tiny camera nudge. If doors feel good, the town feels good. Same for car doors, fridge, light switch, mailbox.
- **Every toy press = sound + motion + small particle**, ≤ 0.3 s sounds ([[09 Owner Taste Rules]]). Use [[19 Animation and VFX Recipe Book]] (UI pop, reward fly) and kit `Spring`, `Emit`, `Feedback`.
- **Ambient life:** birds, a fountain, NPC cars on a loop road, shop music near shops, day/night every 20 minutes with street lights that pop on. An empty server should still look alive.
- **Readable town at a glance:** each building one bold colour and a giant sign icon (hospital cross, police star, pizza slice). Map rules: [[10 Map Design Playbook]].
- **Phone as the menu** (jobs, house, cars, outfits, map, friends) with our small premium buttons and the staged HUD from [[14 Premium Feel Playbook]] and [[13 Beat Stone Skipping - Tutorial, Pacing and Feel]]: first load shows only the phone and the job board arrow.
- **First 30 seconds:** spawn on a busy plaza → "Pick a job" board glows → pick → outfit swaps with a pop → arrow to your free house → keys + car appear in the driveway with a sting. The player owns three things in 30 s.

## 13. Tech architecture for a 30-50 player town
| Concern | Rule |
|---|---|
| Authority | Server owns money, jobs, house ownership, guest lists, caps, jail. Clients only ask. Every "press E" goes through kit `Interact` (distance + slack, cooldown, permission, one user at a time). |
| Network | Remotes through kit `Net` with `RateLimit`. Never trust a client's position for rewards. Driver owns their car physics; server spot-checks. |
| Data | Kit `PlayerData` with session locking: owned houses, cars, outfits, pets, job ranks, settings. Furniture layout saved as a compact list (prop id, position, rotation). |
| Map size and streaming | StreamingEnabled on; keep building interiors instanced; ~1,500-3,000 parts in view on phones. Low-poly town, one tiled texture per surface type. |
| Server size | 30-40 for kids' RP (busy, but phones survive). Bigger needs more streaming work. |
| Moderation | Text filter on every name plate and sign, Quick Words, built-in report and block, server-side cap on props and vehicles. |
| Kill switches | Kit `Flags` for every new toy, so a broken or misused one can be turned off live. |

## 14. Symptoms → fixes
| Symptom | Fix |
|---|---|
| Players join, walk around, leave in 60 s | Give house + car + job in the first 30 s; spawn on a busy plaza; add 10 toys within 20 studs of spawn. |
| Town feels empty at 8 players | Shrink the map, cluster buildings, add NPC life and self-serve events (fires, deliveries). |
| Everyone picks police | Job cap + a "most needed job" bonus. |
| Nobody uses a job | It has no customer: give it a tool that does something to someone else. |
| Kids complain about being jailed or flung | Opt-in roles only, jail ≤ 60 s, fling only in zones. |
| Server lag | Prop and car caps, despawn idle cars, instanced interiors, fewer unanchored parts. |
| Spike then fall | It had reach but no depth: add one long visible chase (pet, house rank, collection). |

## 15. Honest gaps in this research
- **YouTube was not reachable** from the cloud container or Alex's Mac shell on 2026-11-01 (proxy blocks youtube.com and the Adlicio YouTube tools need a paid plan), so no frame-by-frame video study yet. Next step: Alex records 30 s of Brookhaven (first spawn) and DTI (one round) and drops them in the project, and we measure them like [[Teardown - Stone Skipping]].
- Live player counts are tracker snapshots, not Roblox's numbers.
- Age-rating rules moved several times in 2026; re-check [[Policy and Age Rules 2026]] and the Sector Brief before launch.
