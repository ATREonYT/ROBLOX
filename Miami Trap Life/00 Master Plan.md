---
tags: [miami-trap-life, gdd, master-plan]
updated: 2026-11-01
---
# Miami Trap Life: Master Plan

Back to [[00 Start Here]] · Map: [[00 Vice Bay]] · Research: [[Cutscenes]] · [[Cinematic Cutscenes]] · [[Onboarding Funnels and Wayfinding]] · [[Jobs, Leveling and RP Game Feel]] · [[Gun Mechanics]]

**Every thread reads this note before it starts and updates the Status log (bottom) when it finishes.** If your work changes a contract in this note (a remote, a data field, a module API), edit the contract here in the same session. This note is the single source of truth for how the game fits together.

- Game: **Liberty Ends** (renamed from Miami Trap Life on Nov 2; an original GTA-style Miami RP). The visible name lives ONLY in `Config/Game.lua` (`Title`, `OSName`); internal `MTL_` names stay.
- Studio place: **[ALPHA] North Miami RP: Remastered**, placeId `95405231186296`. The Vice Bay map is already built in it.
- Core loop in one line: **Get rich.** Work, level up, take the criminal path, move up from a dirty flat in the Ends.
- Final UI art comes from Alex. Everything we build is **functional and reskinnable**: logic never lives in the visuals (see "UI rules").

---

## 1. The player's journey (story state machine)

The story is one ordered list of stages kept in the player's save (`Story.Stage`). Every system asks "what stage is this player at?" instead of keeping its own flags. Stages only move forward, and only the server moves them (`StoryService.advance`).

| # | Stage id | What the player does | What tells them what to do | Ends when |
|---|---|---|---|---|
| 1 | `Arrive` | (First join: cutscene `Welcome`, ~27 s, skippable: aerial over the Ends, "MIAMI TRAP LIFE", you walk up, Patel's text buzzes, "CHAPTER 1 · New in Town", camera glides into play.) Spawns at the Liberty Food Mart lot with a phone and $50 | Phone buzzes: text from "Mr. Patel, Liberty Food Mart: you start today, come inside" + a ground arrow to the door | Enters the store zone |
| 2 | `FirstShift` | (First time: cutscene `FirstDay`, ~16 s: Mr. Patel greets you inside, "FIRST SHIFT".) Supermarket job: restock shelves, mop spills, take the trash out (interactive tasks) | Job HUD shows the current task + a world marker on it | Reaches **Level 4** (target: about 6 minutes; a one-off "Unknown" text teases it at Level 3, ~3 min) |
| 3 | `TheCall` | Phone rings: **Unknown number**. Short call, offer to "make real money" | Full-screen incoming-call card on the phone. Accept now, or later from Recents | Accepts the call ("I'm in" = choosing crime: Path becomes `Criminal`). Declining keeps the call in Recents; the player keeps working |
| 4 | `GangMeet` | Goes to a meet spot picked at random (under the canal bridge, the motel, a garage; saved in `Story.Data.MeetSpot`). Any shift ends | Unknown number texts the spot; Story waypoint + breadcrumbs + "Go to the meet: <spot>"; the crew waits by a car with blinking hazards (local props, visible from 450 studs) | Comes within 14 studs of the spot |
| 5 | `GangIntro` | Cutscene `GangIntro` (~39 s, skippable): Dre, Smoke, Nina introduce themselves and pitch the job; push-in on the player; black; "FIRST JOB" card. Crew joins Contacts | Cutscene | Cutscene ends or is skipped |
| 6 | `FirstMission` | Rob the Liberty Food Mart: mask up at the crew car → walk in → aim at Kev the night clerk (2 s; no damage) → hold to grab the cash (3.5 s) → alarm, run to the car (clean getaway under 30 s = +$250) → cutscene `RobberyOutro` (car tears off, crew talks over black) → you're dropped next to the flat in the Ends | Tracker (top right) + objective line + one waypoint per step + outline on the target + crew barks + alarm edges | Reaches the car with the cash (pay is saved first, then the outro) |
| 7 | `MissionDone` | Payout card (take, clean-getaway bonus, 2x, total counting up, +150 XP). **Offer:** 2x Money pass / 2x Money 30-min boost, shown with what this job would have paid doubled. The crew gives a real Pistol (Guns piece) | Reward screen, then the offer card (dismissable, no timers, "Maybe later") | Closes the offer |
| 8 | `FindAPlace` | Free play starts. Goal: buy the flat in the Ends ($1,200) | Two texts from Dre + Story waypoint + breadcrumbs to the door; a pulsing outline and a "FOR SALE · $1,200" sign over it (visible from 600 studs); the FOR SALE card pops up when you reach the door (and from the door prompt): photo, honest facts, price, your cash, one BUY button (or "You need $X more") | Buys the flat (banner "IT'S YOURS") |
| 9 | `MoveIn` | Fade into **your own copy** of the room (instanced). Cutscene `PowerOut` (~16 s, skippable): walk in, the bulb flickers and dies, sit at the PC, press power: nothing, hold on the dead screen, press again, keyboard smash x3, silence, flop on the bed, phone out | Cutscene; it ends on gameplay with you already sat on the bed | Cutscene ends |
| 10 | `ChooseJob` | The phone rises by itself on the **Jobs app**: "STEP 1 OF 2 · Pick your job", 3 big cards: Liberty Food Mart (the one you robbed: "Mr. Patel's hiring again. He has no idea it was you."), Westside Auto, Burger Shack. Each: photo slot, one story line, $/min, how hands-on, distance from home, one CHOOSE. CHOOSE → "Work at X?" → "Yes, I'll take it" | Nothing else on screen; if the phone is put away, a "3 places are hiring" banner every 25 s | Picks a job (picking the Food Mart again counts) |
| 11 | `FirstNight` | The app shows "YOU'RE HIRED · STEP 2 OF 2 · Get some sleep" + "Put the phone away" | Bed outline + floating "Sleep" marker + prompt; objective "Get some sleep. Work starts tomorrow." (outside: waypoint home) | Sleeps: cutscene `NextDay` (~10 s: bulb off, window at night, black, "NEXT DAY · 6:58 AM", morning light, alarm, stretch) |
| 12 | `CommuteToWork` | Wakes standing by the bed; the boss texts ("Morning, rookie. Bays open at 7..."). Leaves the flat, walks to the job | Inside: the front door outlined + "Front door" marker + "Head out to work: use the front door". Outside: Story waypoint + breadcrumbs + "Get to work: Westside Auto Repair"; at the site "Clock in at the time clock" + the clock marker | Clocks in at the job |
| 13 | `FreePlay` | Everything is open: jobs, crime (switch path any time), story missions later. Banner "FREE PLAY", one text from Dre, the **Goals** app unlocks | The top unfinished goal sits on the objective line ("Goal: Turn the power on ($120 / $300)"); the Goals app lists them all (finish a shift, power bill, Level 8, $5,000, second gun (criminal), Level 15, + "Coming soon" ones) with XP once per goal | — |

Branching rules:
- **Path** (`Civilian` / `Criminal`) is separate from the stage. After stage 7 the player can switch at any time in the phone (Settings → "Lifestyle"). Criminal unlocks gang missions, guns in the open and PvP. Civilian keeps them in safe mode.
- Story missions after the first are optional: freestyle play is always allowed after stage 7.
- A player who leaves mid-stage resumes at the start of that stage (stages are small enough that this never costs more than a minute or two).
- Every cutscene and dialogue is skippable. Skipping still advances the stage.

Open questions for Alex (defaults in brackets, used until he answers):
1. Before the call at Level 4, is crime the *only* option, or also a "keep grinding" choice? [The call can be declined and comes back from Recents; the player is never forced.]
2. "2x for the job": a one-time boost for one shift, or a timed boost? [Developer Product, 30 minutes of play time, stacks by adding time.]
3. Which building is the flat in the Ends, and where are the meet spots? [Placeholder parts tagged `MeetSpot` / a placeholder `EndsFlat` POI until the map is ready. The Map thread places the real ones: tag the flat's real door `MTL_FlatDoor` (attribute `Id = "EndsFlat"`) and move `Locations.EndsFlat.Door/Out`. The room itself is instanced; Alex's interior model goes in `ServerStorage.MTL_FlatInterior`.]
4. Crew name and characters. [Placeholders: crew "Liberty Lows"; recruiter **Dre**, driver **Smoke**, lookout **Nina**. Easy to rename in `Config/Story.lua`.]
5. "Trapping": Roblox rules forbid drug content, so trapping has to stay abstract (selling "packs", flipping stolen goods, reselling sneakers/phones). [We use "packs" and "goods" everywhere.]

---

## 2. Locations used by the story (from the Vice Bay POIs)

North = −Z, east = +X, street level y = 2. Systems must **read positions from `Config/Locations.lua`, not from map parts**, because StreamingEnabled is on and far parts may not be loaded on the client.

| Use | POI / place | Position |
|---|---|---|
| Spawn | `HoodSpawn`, Liberty Food Mart lot | (−1432, 2, −368) |
| First job + first robbery | Liberty Food Mart | (−1442, 4, −312) |
| Restaurant job | Burger Shack | (−1442, 4, −445) |
| Car Mechanic job | Westside Auto Repair | (−1015, 4, −445) |
| The flat in the Ends | TBD by the Map thread (placeholder: Starter Crib POI). Door prompt at `Locations.EndsFlat.Door` or a map part tagged `MTL_FlatDoor` (attribute `Id = "EndsFlat"`); you come out at `EndsFlat.Out` | (−1442, 4, −165) placeholder |
| Flat interiors | Instanced: one room per owner at `Config/Property.Slots` (x = 6000 + 160·slot, y = 400, z = 6000), far off the map | built at runtime |
| Meet spots | Under a Liberty Canal bridge, a motel, a garage: TBD | placeholders |
| Later jobs (AFK-able, higher level) | Valet, Trucker, Dockworker, Car Wash, Barber... (already tagged `JobSpot` with `Job`/`Pay`) | see [[Map Bible]] |

Note: a second `HoodSpawn` exists at (694, 2, −368) and the Urus model is duplicated in Workspace. Map thread: remove the duplicates.

---

## 3. Architecture

### 3.1 Where the code lives
- **Source of truth:** `ROBLOX/Miami Trap Life/src/` in this vault (Rojo layout). The place is the output, same rule as the map build ([[Build System]]).
- Threads write a file in `src/`, then push it into Studio with the Studio MCP (`multi_edit` / `execute_luau`). Never edit a game script only in Studio.
- All game code sits in **`MTL` folders** so it never touches the map, the stock market or anything else:

```
ReplicatedStorage/MTL/            shared code + config (client and server)
  Net.lua                         every RemoteEvent/RemoteFunction, created by the server
  Signal.lua                      tiny signal class
  Config/                         ALL tunable numbers live here, no magic numbers in systems
    Economy.lua  Levels.lua  Jobs.lua  Story.lua  Locations.lua
    Monetization.lua  Guns.lua  Phone.lua
  Rules/                          pure functions (no Instances), unit-tested
    LevelRules.lua  JobRules.lua  StoryRules.lua  GunRules.lua
  Cutscenes/                      one data module per cutscene (shots, lines, actions): GangIntro, RobberyOutro (Piece 3)
  Rig.lua                         procedural poses for R15/R6 rigs (gestures, walk cycle, head look), client + server
  UI/                             UIKit (themeable widgets), Theme.lua, Motion.lua (tweens/springs)
  Config/Missions.lua  Rules/MissionRules.lua  Rules/CutsceneRules.lua   (Piece 3: crew, meet layout, robbery steps, timeline maths)
ServerScriptService/MTL/
  Main.server.lua                 boots services in order
  Services/
    DataService.lua               ProfileStore, profile schema, push to client
    EconomyService.lua            the ONLY place cash/XP change (applies multipliers, logs)
    MonetizationService.lua       game passes, ProcessReceipt, boosts
    StoryService.lua              stage machine, advance(), stage hooks
    PhoneService.lua              texts, calls, notifications, app unlocks, GPS routes, Lifestyle switch, settings
    PhoneStory.lua                story beats that arrive by phone (Arrive text, TheCall). Story thread extends it
    JobService.lua                clock in/out, tasks, pay, anti-AFK rules
    CutsceneService.lua           tells a client to play a scene and waits (token, timeout); builds crew rigs into ReplicatedStorage.MTL_Actors
    MissionService.lua            mission runner (steps: hold / zone / aim, server-validated), robbery gear, the clerk NPC
    StoryCrew.lua                 story glue for stages 4-7 (meet spot, intro, robbery payout, offer)
    PropertyService.lua           Piece 4: buying the flat, instanced rooms (placeholder or ServerStorage.MTL_FlatInterior), door
                                  fade, bed/PC/breaker prompts, power bill, stages FindAPlace -> CommuteToWork, home spawn
    GoalService.lua               Piece 4: FreePlay goals: objective line on the top goal, XP once per goal
    GunService.lua                fire validation, damage, ammo, lag compensation (+ GunModels.lua: gun models / placeholders)
    AnalyticsService (wrapper)    funnel + economy events
  Vendor/ProfileStore.lua         copy from hood/ (already vetted)
StarterPlayer/StarterPlayerScripts/MTL/
  Client.client.lua               boots controllers in order
  Controllers/
    PhoneController.lua           the phone (peek, rise, apps host)
    HUDController.lua             cash, level bar, objective line, toasts
    WayfindingController.lua      waypoints, ground breadcrumbs, distance
    CutsceneController.lua        plays Cutscenes/* data, letterbox, subtitles, tap/hold-to-skip (+ Actors.lua: local rigs + props)
    JobController.lua             task markers, minigames
    MissionController.lua         mission tracker, hold prompt, aim step, alarm, barks, meet-spot crew, payout + offer cards
    GunController.lua             aim, shoot, recoil, effects (+ GunFX.lua pooled effects, GunPose.lua procedural arms)
    UIStateController.lua         who owns the screen (hide HUD in cutscenes etc.)
  Apps/                           one module per phone app (Jobs, Messages, Calls, Map, Bank, Goals, Settings, Plug = guns/ammo shop)
  Controllers/PropertyController  Piece 4: FOR SALE card, door fade, door/bed/front-door cues, room power visuals,
                                  opens the phone on Jobs after the move-in, cutscene beats (BulbFlicker, PcPower...)
ReplicatedStorage/MTL (Piece 4 adds): Config/Property.lua · Config/Goals.lua · Rules/PropertyRules.lua · Rules/GoalRules.lua ·
  Cutscenes/PowerOut.lua · Cutscenes/NextDay.lua · UI/Build/Property.lua (MTL_Property)
Lighting (time of day): ReplicatedStorage/MTL/Config/DayNight.lua (phases, keyframes, lamps) · Rules/DayNightRules.lua ·
  ServerScriptService/MTL/Services/TimeService.lua (the world clock) · Controllers/LightingController.lua (draws it)
StarterGui/MTL_*                  ScreenGuis as real instances (Alex can reskin in Studio)
```

`Miami Trap Life/default.project.json` maps only those `MTL` folders and sets `$ignoreUnknownInstances: true` on every parent service, so Rojo can never delete the map, `StockMarket` or `VBHouseInteriors`.

### 3.2 Boot order
Server (`Main.server.lua`): `Net.init()`, then `init()` on `DataService` → `MonetizationService` → `EconomyService` → `WaypointService` → `StoryService` → everything else, then `DataService.start()` (players only load once every service is listening). In Studio, `_G.MTL` holds the services for testing from the server command bar, e.g. `_G.MTL.Economy.addXP(game.Players:GetPlayers()[1], 500, "Debug")`. A player is "ready" when `player:GetAttribute("MTL_Ready") == true`. Client controllers wait for that attribute and for the first `ProfileUpdated`.

### 3.3 Networking (`ReplicatedStorage/MTL/Net.lua`)
One folder `ReplicatedStorage/MTL_Net`, created by the server. Names are fixed here; add new ones to this table and to Net.lua.

| Remote | Type | Direction | Payload |
|---|---|---|---|
| `ProfileUpdated` | Event | S→C | public snapshot (see 3.4) |
| `Notify` | Event | S→C | `{kind="toast"|"line"|"banner", text, color?}` |
| `PhoneEvent` | Event | S→C | `{type="text", contact, name, text, silent}` · `{type="call", state="ringing"|"connected"|"ended", call, contact, name, lines?, choices?, outgoing?, outcome?}` · `{type="notify", app?, title, text}` · `{type="unlockApp", app, title}` · `{type="open", app}` · `{type="pathResult", ok, reason?}` |
| `PhoneAction` | Event | C→S | built in: `answerCall{call}` `declineCall{call}` `callChoice{call, choice}` `hangUp{call}` `callBack{call}` `readThread{contact}` `seenRecents` `openLink{contact, index}` `gpsRoute{place}` `gpsClear` `setPath{path}` `setSetting{key, value}`. Other pieces add their own with `PhoneService.onAction(type, fn)`: Jobs `chooseJob{job}`, Monetization `buy{item}` (item = a name in Config/Monetization Passes/Products). Rate limit 8/s. |
| `Waypoint` | Event | S→C | `{id, position, label, radius}` or `{id, clear=true}` |
| `PlayCutscene` | Event | S→C | `{id, token, anchor = CFrame?, marks = {Name = Vector3}?}` (positions in the scene are local to anchor; `marks` = named local points, e.g. this player's PC chair, used in the scene as `"#Name"` / `{mark, off}`) |
| `PropertyState` | Event | S→C | Piece 4: `{type="listing", home, title, area, price, blurb, facts={{k,v}}, photo, cash, canBuy, reason?, short}` · `{type="listing", close=true, bought?}` · `{type="fade", seconds}` · `{type="arrived"}` · `{type="phone", app}` (open when no cutscene) · `{type="bed", on}` · `{type="exit", on}` · `{type="power", on}` |
| `PropertyAction` | Event | C→S | Piece 4: `{type="buy", home}` (server checks stage, cash, distance to the door). Rate limit 4/s. Phone action `payPower{}` (PhoneService.onAction) |
| `SocialState` | Event | S→C | CLOUT (SocialService): `{type="hello", account, market, feed, leaders, unlocked}` · `market` · `feedPost{post}` · `feedLike{id, likes}` · `leaders` · `posted{result, post, account}` · `postFail{reason}` · `scout{spot?, car, golden, trend, collab, fatigue}` · `followed` · `recording{course, step}` · `launched{course}` · `sale{n, cash, course}` · `away{sales, cash}` · `toast{text}` |
| `SocialAction` | Event | C→S | CLOUT: `sync` · `scout` · `post{format, caption, framing}` (spot, car, collab, light and fatigue are decided by the server) · `like{id}` · `follow{userId}` · `acceptDeal{id}` · `declineDeal{id}` · `gps{spot}` · `buyBots{pack}` · `startCourse{topic, price}` (at the desk) · `recordStep{}` · `cancelRecording` · `retireCourse{id}`. Rate limit 6/s, burst 8 |
| `CutsceneDone` | Event | C→S | `{id, token, skipped}` (token must match; rate limit 4/s) |
| `JobAction` | Event | C→S | `{type="clockIn"}` · `{type="clockOut"}` · `{type="begin", task, step}` (a minigame started; server checks distance + starts the clock) · `{type="step", task, step, score?}` (step done; score 0..1 for minigames) · `{type="checkIn", token}` (post jobs) · `{type="nextShift"}` · `{type="sync"}`. Rate limit 6/s. |
| `JobState` | Event | S→C | `{job=nil}` or `{job, title, role, kind="tasks"|"post", place, onShift, storyJob, clock={id,pos,radius}, site={pos,radius}, props={{id,prop,pos}}, shift?={done,total,earned,complete}, task?={id,key,title,step,steps,kind,prompt,text,verb,fx,far,carrying,station={id,pos,radius,prop},hint?, seconds? / hits,zone,speed / items,buttons}, waiting?, leaving?, post?={station,onPost,paused,checkIn,perMinute,payEvery}, result?={label,cash,xp,at,perfectBonus}}` |
| `MissionState` | Event | S→C | `{type="state", mission, title, index, steps={{id,text,done,current}}, step={id,kind,text,verb,seconds,pos,radius}, car=CFrame, clerk, register, alarm, alarmFor?, cleanSeconds, aimFallback}` · `{type="clear", reason?}` · `{type="bark", who, text}` · `{type="progress", value}` (aim meter) · `{type="meet", cframe, label}` · `{type="meetClear"}` · `{type="payout", title, take, bonus, clean, escape?, cleanSeconds, paid, xp, mult, doubled, debug, offer={{item,kind,title,sub,id,owned}}}` |
| `MissionAction` | Event | C→S | `{type="begin", step}` · `{type="step", step}` (hold/aim: server checks distance, facing, min time) · `{type="closeOffer"}` · `{type="buy", item}` (whitelist = Config/Missions.Offer). Rate limit 6/s |
| `GunFire` | Event | C→S | `{gun, origin, dir, t = workspace:GetServerTimeNow(), rays = {{pos, part?}}}` (one ray per pellet; `part` only when it hit a character). Rate limit 30/s + per-gun RPM bucket |
| `GunFx` | Event | S→C | `{type="shot", shooter, gun, origin, ends}` to other players within 700 studs · `{type="hit", pos, head, kill, damage}` to the shooter (hitmarker) · `{type="hurt", from, damage}` to the victim |
| `GunReload` | Event | C→S | `{gun}` |
| `GunAction` | Event | C→S | `{type="equip", gun}` · `{type="holster", reason?}` · `{type="sync"}`. Rate limit 6/s |
| `GunAim` | **Unreliable**Event | C→S | `{aiming, raised, pitch, target?}` at 10 Hz while a gun is out (pose for others + intimidation; `target` = a model tagged `MTL_Intimidate`) |
| `GunState` | Event | S→C | `{equipped?, mode?, guns = {{id, mode, temp, mag, reserve}}, reloading?}` (owner only) |
| `RequestSnapshot` | Function | C→S | returns the snapshot |
| `ClientReady` | Event | C→S | client controllers are listening; server re-sends waypoints (sent on join and every respawn) |
| `Reward` | Event | S→C | `{cash?, xp?, at?, reason}` for the "+$8 / +20 XP" pops (sent by EconomyService) |
| `LevelUp` | Event | S→C | `{level, unlocks = {string}}` (banner + toasts) |
| `WaypointArrived` | Event | C→S | reserved; arrival is decided by the server (WaypointService) |

`Notify` kinds: `toast` (small, stacks of 4), `objective` (the one top line; also kept in player attribute `MTL_Objective`), `banner` (big centre words, rare).

Rules: the server validates every C→S payload (types, ranges, distance to the thing, cooldowns, current stage). Every C→S remote has a per-player rate limit (copy `RateLimiter.lua` from hood/).

### 3.4 Save data (ProfileStore, store name `MTL_Profile_v1`)
```lua
{
  Version = 1,
  Cash = 50,               -- "bare minimum" start (Config/Economy.StartCash)
  Bank = 0,
  XP = 0,                  -- XP inside the current level
  Level = 1,
  Path = "Civilian",       -- "Civilian" | "Criminal"
  Story = { Stage = "Arrive", Done = {}, Data = {} },     -- Done[stageId] = os.time()
    -- Data (per-stage scratch, Piece 3): MeetSpot = Locations.MeetSpots id · MeetTexted = bool · FlatTexted = bool (Piece 4) ·
    --   FirstMissionResult = {take, bonus, clean, escape, seconds, paid, xp, mult, at} (set once, BEFORE the outro: never paid twice)
  Job = { Current = "", Shifts = {}, TasksDone = {} }, -- Current = job id ("" = none); Shifts[jobId] = shifts finished; TasksDone[taskId] = count (coach hints show while < 2)
  Home = { Owned = {}, Current = "", PowerPaidUntil = 0, PowerOn = false },  -- Owned[homeId] = os.time() · PowerOn = the one-time power bill is paid (Piece 4)
  Goals = { Done = {} },   -- Piece 4: Done[goalId] = os.time() the FreePlay goal's XP was given (recorded before paying)
  Social = { Handle, Real, Bots, PostCount, Posts, SpotsEver, SpotsToday, Milestones, PlayerFollowers, Deals = {Offers, Done, Active?}, Courses, Earned = {Fund, Deals, Courses}, History, Today, Trust, LastPostAt, LastSeen, Joined },  -- CLOUT (Config/Social): Real/Bots followers · Posts = last 24 · Courses = {id, topic, price, launchDay, sold, revenue} · History = last 7 Clout days
  Inventory = { Guns = {}, Ammo = {}, Mags = {}, Items = {} },  -- Guns[gunId]=true · Ammo[ammoType]=reserve rounds · Mags[gunId]=rounds in the mag (temporary story guns are never saved)
  Phone = { Contacts = {}, Texts = {}, Unread = {}, Recents = {}, Apps = { Jobs=true, Messages=true, Calls=true, Map=true, Settings=true, Goals=false } },  -- Goals unlocks at FreePlay
    -- Texts[contactId] = { {me, text, t, link?}, ... } oldest first, max 60 · Unread[contactId] = n
    -- Recents = { {call?, contact, kind="missed"|"declined"|"answered"|"outgoing", t, callBack, seen}, ... } newest first, max 30
    -- Contacts[contactId] = true · link = {kind="waypoint", place=<Config/Phone.Places id>, label?} | {kind="app", app}
  Boosts = { XP2xSeconds = 0, Cash2xSeconds = 0 },   -- remaining PLAY seconds (no real-time timers)
  Purchases = {},          -- PurchaseId -> os.time() (grant once; newest 200 kept) · "Pass:StarterPack" = its cash was given
  Stats = { Earned = 0, Robberies = 0, PlayTime = 0 },
  Settings = { Music = true, Sound = true, ReducedMotion = false },
}
```
- Game passes are **never saved**: they are checked with `MarketplaceService:UserOwnsGamePassAsync` on join and on `PromptGamePassPurchaseFinished`, cached as player attributes `MTL_Pass_<Name>`.
- In Studio, ProfileStore runs in Mock mode (progress resets on Stop). That's on purpose.
- Client sees a public snapshot only (no `Purchases`).
- The existing stock market uses `leaderstats.Cash`. `EconomyService` owns `leaderstats.Cash` and `leaderstats.Level` and writes them on every change; `StockMarket`'s `getCash`/`setCash` get pointed at `EconomyService` (one line change, done by the Jobs/Economy thread).

### 3.5 Key server APIs (other systems call these, nothing else)
```lua
EconomyService.addCash(player, amount, reason) -> paid   -- applies 2x pass + boost, logs economy event
EconomyService.spend(player, amount, reason) -> ok       -- false if not enough
EconomyService.addXP(player, amount, reason) -> leveledUp -- applies 2x XP, levels up, fires LevelUp
EconomyService.LevelUp: Signal(player, newLevel)
StoryService.stage(player) -> stageId
StoryService.advance(player, fromStage)   -- only moves if the player is at fromStage
StoryService.onEnter(stageId, fn(player)) -- hooks: send texts, set waypoints, start cutscenes
PhoneService.text(player, contactId, text, {link?, silent?})  /  PhoneService.textFromMe(player, contactId, text)
PhoneService.call(player, callId) -> bool -- rings a scripted call from Config/Phone.Calls (false if already on a call)
PhoneService.CallEnded: Signal(player, callId, outcome)  -- outcome = a choice id, or "answered"|"missed"|"declined"|"hungUp"
PhoneService.isInCall(player)
PhoneService.openApp(player, appId) / unlockApp(player, appId) / notify(player, {app?, title, text})
PhoneService.route(player, placeId) / clearRoute(player)   -- GPS, waypoint id "GPS" (never replaces "Story")
PhoneService.setPath(player, "Civilian"|"Criminal", force?) -> ok, reason ; PathChanged: Signal(player, new, old)
PhoneService.addPathGuard(fn(player, wanted) -> ok, reason?)   -- e.g. GunService: no switching mid-fight
PhoneService.onAction(type, fn(player, payload))         -- your piece's phone buttons (validate the payload!)
  -- player attribute MTL_Path mirrors data.Path; MTL_GPS = the GPS place id while a route is set
WaypointService.set(player, id, position, {label, radius, breadcrumbs}) / clear(player, id) / Arrived: Signal(player, id)
  -- the story uses id "Story" for its one main waypoint; jobs/missions use their own ids
StoryService.onEnter(stage, fn(player, resumed))  -- resumed = rejoined mid-stage: re-send, don't re-grant
StoryService.data(player) -> per-stage scratch table saved with the profile
StoryService.debugSet(player, stage)      -- Studio only, to test a piece without replaying the story
Notify.toast(player, text, color?) / Notify.objective(player, text) / Notify.banner(player, title, sub?, color?)
JobService.isOnShift(player) -> jobId?   JobService.current(player) -> jobId?
JobService.setJob(player, jobId, force?) -> ok, reason   JobService.clockIn(player, force?) -> ok, reason   JobService.clockOut(player, reason?)
JobService.workplace(player) -> (Vector3?, label?)       -- the commute funnel (stage 12) points here
JobService.addShiftGuard(fn(player, jobId) -> ok, reason?) -- e.g. MissionService: no shifts mid-mission
JobService.ClockedIn(player, jobId) / ClockedOut(player, jobId, reason) / TaskDone(player, jobId, taskId, paid, xp) / ShiftDone(player, jobId, earned, bonus) / JobChosen(player, jobId, old) : Signals
  -- player attribute MTL_Job = data.Job.Current. Story wiring in JobService: FirstShift sets the story job and clocks you in
  -- inside the store; ChooseJob advances on a pick; CommuteToWork advances on clock-in; Config/Jobs.BlockedStages end shifts.
MonetizationService.ProductGranted: Signal(player, productName)   -- after ProcessReceipt granted (and before it's saved)
MissionService.start(player, missionId) / stop(player, reason?) / cleanup(player) / active(player) -> missionId?
MissionService.point(missionId, name) -> (CFrame, radius)   -- Workspace.MTL_Stations.<MissionId>.<Point> part wins over Config/Missions
MissionService.send(player, MissionState payload) / MissionService.onAction(type, fn(player, payload))
MissionService.Completed(player, missionId, {seconds, escapeSeconds, clean, take, bonus}) / StepDone(player, missionId, stepId) : Signals
  -- one shared server clerk NPC (MTL_Clerk, tag MTL_Intimidate, attr MTL_Mission) exists while anyone robs; hands go up (C0 pose).
  -- death mid-mission or > 600 studs away: back to step 1 at the car with a toast (never a fail screen).
CutsceneService.play(player, sceneId, { anchor = CFrame?, marks = {Name=Vector3}? }) -> (finished, skipped)   -- yields; timeout = length + 10 s
PropertyService.owns(player, homeId?) / isInside(player) / room(player) -> Room? {origin, marks, parts, seat, prompts}
PropertyService.enter(player, {instant?, keepBlack?}) / leave(player, opts?) / payPower(player) -> ok, reason / give(player, homeId)
PropertyService.Bought(player, homeId) / Entered / Left / PowerChanged(player, on) : Signals   -- attr MTL_InHome = homeId while inside
  -- returning players (stage >= MoveIn, owning a home) spawn inside their room on their first spawn of the session
GoalService.refresh(player) / GoalService.GoalDone(player, goalId) : Signal
TimeService.clock() -> hour 0-24 · TimeService.phase() -> "Morning"|"Day"|"Evening"|"Night" · TimeService.PhaseChanged(phase) : Signal
TimeService.setClock(hour) · TimeService.freeze(hour?)   -- debug/events; nil = run again from the held time
StoryWelcome.storeAnchor() -> CFrame   -- Welcome (Arrive) + FirstDay (FirstShift) scenes for new players; Studio: workspace attr MTL_SkipWelcome = true skips both
CutsceneService.rig(actorId) -> Model?   -- copy of a crew rig (ReplicatedStorage.MTL_Actors.<Id>; Alex's rig there wins)
StoryCrew.meet(player)   -- Studio: teleport to your meet spot
GunService.give(player, gunId, {temporary?, mode?="Live"|"Intimidate", ammo?}) -> ok   -- temporary = not saved (missions)
GunService.take(player, gunId) / GunService.lend(player, gunId, opts) / GunService.unlend(player)   -- lend = temporary Intimidate
GunService.equip(player, gunId, force?) -> ok, reason / GunService.holster(player, reason?) / GunService.equipped(player) -> gunId?, mode?
GunService.owns(player, gunId) / GunService.addAmmo(player, ammoType, n) / GunService.isInFight(player) / GunService.inSafeZone(player) -> bool, zoneId?
GunService.addFireGuard(fn(player, gunId) -> ok, reason?)
GunService.Equipped(player, gunId, mode) / Holstered(player, gunId, reason) / Fired(player, gunId, hitPos, hitModel?) /
  Damaged(attacker, victimModel, dmg, head, killed) / Killed(attacker, victimModel) / Intimidating(player, targetModel, heldSeconds) : Signals
  -- Intimidate mode: equips on any path, in safe zones, on shift; shots make noise + fire Fired but never damage.
  -- Intimidating fires ~4x/s while the player really aims (not hip) at a model tagged MTL_Intimidate: <= 30 studs, facing it (40°), line of sight.
  -- NPC Humanoids take damage only with model attribute MTL_Damageable = true. Character attrs: MTL_Gun (id or ""), MTL_GunMode, MTL_Aiming, MTL_AimPitch.
  -- Wired in GunService: live guns need Criminal; auto-holster in safe zones / on shift / on Civilian; no path switch or clock-in
  -- mid-fight (20 s); Config/Guns.Starter: on entering MissionDone (not resumed) temp guns go back and a Pistol + 24 rounds is granted;
  -- the Plug app (phone) is unlocked on the Criminal path; phone actions buyGun{gun} / buyAmmo{ammo}.
SocialService.account(player) -> data.Social · SocialService.market() -> {day, mood, moodLabel, trendSpot, trendFormat, demand} (CoinBay can read mood)
SocialService.atDesk(player) -> bool · SocialService.debug(player, "followers"|"day"|"sales"|"unlock", n?) (Studio: MTL_Debug:Invoke("Social","debug",p,"followers",12000))
SocialService.Posted(player, result) / Sale(player, n, cash) : Signals · the Clout day = floor(os.time() / DayNight cycle), shared by every server
MonetizationService.owns(player, passName) -> bool
MonetizationService.prompt(player, passOrProductName)
```

### 3.6 Key client APIs
```lua
Phone.registerApp(appId, { title, mount = fn(frame, ctx), unmount = fn(ctx)?, onEvent = fn(payload, ctx)? })
  -- or just drop a ModuleScript in StarterPlayerScripts/MTL/Apps returning { id, mount, ... }: loaded automatically.
  -- Home-screen order/icons come from Config/Phone.Apps. ctx = { frame, args, data(), onData(fn), action(type, payload),
  --   track(conn), clear(), home(), close(), UIKit, Theme, Format, Rules=PhoneRules, Config=Config/Phone, Story, Phone }
Phone.open(appId?, args?)   -- e.g. Phone.open("Messages", { contact = "Patel" }), Phone.open("Calls", { tab = "Contacts" })
Phone.fakeCall(name, message?) / Phone.currentApp() / Phone.Opened, Phone.Closed, Phone.ServerEvent : Signals
Phone.open(appId?) / Phone.close() / Phone.isOpen()
Phone.notify({ appId, title, text })        -- banner slides from the phone top
Phone.incomingCall({ caller, onAnswer, onDecline })
Wayfinder.set(id, position, { label, radius, breadcrumbs }) / Wayfinder.clear(id)   -- local-only markers
ClientData.get() / ClientData.Changed(new, old) / ClientData.waitReady()
Cutscene.play(id, { anchor = CFrame?, token?, marks? }) -> skipped   -- yields; local scenes too (no server needed)
  -- scene `marks` (defaults) + opts.marks: positions written "#Name" or { mark = "Name", off = Vector3 } (Piece 4)
  -- a fade "in" right after a fade "out" now fades back from black (the NEXT DAY card)
Cutscene.releaseBlack(fadeSeconds?) / Cutscene.isPlaying() / Cutscene.Started(id) / Cutscene.Finished(id, skipped) : Signals
Cutscene.Started(id, scene)   -- scene table is passed too (LightingController holds scene.hour)
  -- scene data adds (Research: Cinematic Cutscenes): cam { path = {pts}, look | lookPath } (Catmull-Rom),
  -- { gameplay = true, dist?, height? } (hand-off behind the real player; skipping lands there too), shot.focus / blur /
  -- safe = false, ots side, scene.hour / music / stream / placePlayer = { at, face }; sounds fall back to Theme.Sfx names
Tutorial.restart()   -- TutorialController (MTL_Tutorial, DisplayOrder 11): Config/Tutorial steps, Rules/TutorialRules,
  -- progress in Settings.Tutorial (99 = skipped); targets found by name in MTL_HUD / MTL_Phone / MTL_Job; hides while a
  -- child of MTL_HUD.Panels is visible or the HUD is hidden
Cutscene.registerAction(name, fn(ctx, action))   -- custom beats { t, call = name }; ctx = {t, anchor, actors, props, camera, scene}
LightingController.clock() / .phase()   -- what THIS player sees (a story hold can differ from the world)
LightingController.hold(hour, blendSeconds?, untilLeaveRoom?) / .release(blendSeconds?)   -- local time of day, e.g. cutscenes
  -- built-in holds: PowerOut = 21:24, NextDay = 23:18 then 07:00 on the "WorldMorning" beat; a room hold ends when you walk out
  -- scenes with holdBlack = true end on black (controls locked) until releaseBlack() or 6 s: the server moves the player meanwhile
Actors.spawn(rig | "@player") / Actors.place / Actors.render(actor, Rig.State, now) / Actors.prop(name, opts) / Actors.registerProp(name, fn)
  -- props: CrewCar (hazards), Mask. Piece 4 scenes use the REAL room (server-built, streamed to its owner) + beats
  -- registered by PropertyController: BulbFlicker, BulbOff, PcPower, KeyboardBounce, PhoneOut, MorningLight
PropertyController.fadeIn(seconds?)   -- (rest is driven by PropertyState)
MissionController.state() / MissionController.Changed : Signal
UIState.push(ownerName, { hideHUD = true, hidePhone = true, lockControls = true }) / UIState.pop(ownerName)
HUD.objective(text) / HUD.toast(text, color)
JobController.state() -> last JobState / JobController.Changed: Signal(state) / JobController.action(type, payload?)
GunController.equipped() -> gunId? / GunController.mode() / GunController.isAiming() / GunController.state() -> last GunState
GunController.equip(gunId) / GunController.holster() / GunController.Changed: Signal()
MovementController.setModifier(name, mult) / .clearModifier(name) / .isSprinting() / .Changed: Signal(sprinting)
  -- the ONLY client writer of Humanoid.WalkSpeed (Config/Movement). Need a slower walk? setModifier, never write WalkSpeed.
  -- A server write (job carry, Jobs.Carry.WalkSpeed = 14) becomes its base. FOV kick is additive: write FieldOfView as usual, it rides on top.
MovementController.punch(pitchDeg, fovDeg?) / Juice.hit("Perfect"|"Kill"|"Prompt") / Juice.hitStop(seconds)   -- feel on big moments (Config/Movement.Juice)
  -- InteractFX: every prompt you complete pops (Theme.Sfx.PromptDone + burst + camera nod). Make tap prompts HoldDuration 0 where you create them
  -- DeathController: dying = grade/blur + push-in + MTL_Dropped card with the respawn countdown (Players.RespawnTime)
  -- StrideController: takes over Animate's WalkAnim/RunAnim only while moving on the ground (walk->run blend by speed,
  --   playback rate learned from the planted foot so feet don't slide). Anything that plays its own walk/run tracks:
  --   name the Animation "WalkAnim"/"RunAnim" to get stride sync, anything else to be left alone.
  -- a full cutscene (UIState lockControls + hideHUD) drops the aim and holsters LIVE guns (story Intimidate guns stay out)
```

### 3.7 UI rules (so Alex's art drops in)
- Every ScreenGui is built once by code, **saved into StarterGui as real instances** (`MTL_Phone`, `MTL_HUD`, `MTL_Cutscene`, ...) and reused at runtime (vault rule from [[CLAUDE]]).
- Controllers find elements **by name** (`Phone.Body.Screen.AppHost`), never by position or colour. Alex can replace images, fonts and colours freely as long as names stay.
- All colours, fonts and corner radii come from `UI/Theme.lua`. Placeholders are clean and neutral (dark glass, white text, one accent colour), not "simulator style".
- All motion goes through `UI/Motion.lua` (same tween times everywhere).
- Phone: bottom-right, about 15% of its height peeks out (tilted 4°). Hover lifts it slightly; click/tap or **M** raises it with a spring (0.35 s). Click outside, **M** or swipe-down lowers it. Works on mobile (tap), console (a button to be bound).
  - Built (Piece 1): `UI/Build/Phone.lua` makes `MTL_Phone` (element names listed at the top of that file). Gamepad toggle = DPadUp. On touch screens the phone sits just left of the jump button, and drag-down on the top/bottom bar closes it (tapping the world doesn't, so the thumbstick stays usable). While closed it shows the lock screen; the open app comes back when it rises. Something arriving while closed = the phone peeks to 30% with a banner for 3.5 s. Incoming calls raise it by themselves and buzz it; hidden phones (cutscenes) queue the call until they're back.
  - All sizes/timings in `Config/Phone.Tuning`, all colours/icons/sounds in `Theme.Phone`, shared widgets in `UI/UIKit.lua` (header, row, button, toggle, card, badge...).
- No UI ID is ever invented. Images are `rbxassetid://0` with a clear `-- TODO(Alex art)` until Alex sends art.
- **Never name a child after a property** of its parent (`Text`, `Name`, `Image`, `Value`...). `label.Text` and `frame.Name` return the property, not the child, and the controller crashes (`attempt to index string with 'Text'`). Two of these were found in play-test (phone banner → `Body`, mission tracker title → `MissionName`).
- **Nothing on the client may wait for `PlayerModule`.** This place has none in PlayerScripts. `UIState` locks movement with ContextActionService when it's missing, and never yields.

### 3.8 Naming
- Modules PascalCase; ids are PascalCase strings (`"Supermarket"`, `"FirstMission"`, `"GangIntro"`).
- Attributes on players start with `MTL_` (`MTL_Ready`, `MTL_Job`, `MTL_Pass_Cash2x`).
- CollectionService tags start with `MTL_` (`MTL_JobTask`, `MTL_MeetSpot`, `MTL_Bed`, `MTL_SafeZone`).
- Output log lines start with `[MTL <System>]` so a screenshot of Output says which system spoke.

---

## 4. Systems and their numbers (first pass, tune in Config)

### Economy and levels (`Config/Economy.lua`, `Config/Levels.lua`)
- Start cash **$50**. XP needed for next level: `need(L) = round(60 + 45 * (L-1)^1.6)` → 60, 105, 197, 322 ... so **Level 4 ≈ 360 XP ≈ 6 minutes** (the gang call, `Levels.CriminalCallLevel`) and Level 5 ≈ 680 XP ≈ 10 minutes of supermarket tasks (~20 XP per 15-second task). Later levels stretch out.
- First-job pay ~$8 per task. First mission pays **$1,500**. The flat costs **$1,200**, so the robbery is what gets you the flat (the story beat), with a little left over.
- Each level-up: banner, sound, short burst, and the phone pings with anything new it unlocked ("New job unlocked: Car Wash").

### Jobs (`Config/Jobs.lua`, built in Piece 2; balance checked by `tools/tests/test_job_rules.py`)
- **9 jobs.** Tier 1 hands-on, Level 1: **Liberty Food Mart Stocker** (Restock = carry a box + hold to stack, Mop = hold, spill shrinks; Trash = carry the bag out to the dumpster; Price gun = timing, Level 2), **Westside Auto Mechanic** (Tire swap = carry + timing lug nuts, Oil change = sequence in order, Detail = hold), **Burger Shack Cook** (Grill = hold then timing flip, Build order = sequence from a ticket, Serve = carry a tray to a table, Mop). Tier 2 laid back, Level 8 (one light task, then a 5-13 s wait for the next customer): Cashier, Car Wash, Valet. Tier 3 AFK-friendly, Level 15: Security Guard + Dockworker (stand in the post ring, paid every 30 s, "Still on post?" check-in every 2 min pauses pay, never kicks), Trucker (load at the depot, deliver across town, + $0.12 per stud).
- **Numbers (simulated):** Level 2 at ~1 min, Level 3 ~2.9 min (tease text), **Level 4 (the call) ~6.3 min**, Level 5 ~11 min, Level 10 at ~72 min of tier-1 work; about $290 by Level 5. $/min at unlock: tier 1 $24-29, tier 2 $46-53, tier 3 $84-102; AFK jobs give half the XP/min of hands-on ones.
- **Shifts:** 8 tasks (post jobs: 8 minutes). Shift bonus +25% from Level 3, +50% from Level 10. Then a "Next shift / Clock out" card (a natural stopping point).
- **Quality:** each minigame scores 0..1. PERFECT (>= 0.95) shows a flourish and pays +25% "tips" from Level 5 (`Jobs.Quality.PerfectBonusLevel`; Level 4 is the call); SLOPPY (< 0.6) pays -20%.
- **Every level 2-10 unlocks something** (Config/Levels.Unlocks): price gun, shift bonus, tips, the call, +10% pay raise, quick hands (hold tasks 15% faster), tier 2 jobs, another +10%, big shift bonus. Level 15: tier 3 jobs. New jobs also ping the phone.
- **Stations** (where steps happen): parts in `Workspace.MTL_Stations.<Job>.<Station>` win over the config defaults (run `tools/PlaceJobStations.lua` once, then drag them into the map). Until then, placeholder props are drawn locally. Map `JobSpot` parts (attribute `Job`) set the tier 2/3 sites automatically.
- **Anti-exploit:** server picks tasks and stations, checks distance (radius + 6), minimum minigame time (75% of a hold, 0.3 s per timing hit, 0.25 s per sequence item), clamps scores, rate-limits, and ends a shift 15 s after you walk 90 studs away.
- 2x XP pass and 2x XP boost apply in `EconomyService.addXP` (pay goes through `addCash`, so 2x Cash applies too).

### Monetization (`Config/Monetization.lua`, all IDs `0` until Alex creates them)
| Name | Type | What it does | Shown when |
|---|---|---|---|
| `StarterPack` | Game Pass | starting cash bonus + a starter outfit/phone case (content TBD) | Shop app, first join toast (once) |
| `XP2x` | Game Pass | 2x XP forever | Jobs app, level-up banner (small button) |
| `Cash2x` | Game Pass | 2x money forever | After the first mission (stage 7), Shop app |
| `XPBoost` / `CashBoost` | Dev Product | 2x for 30 minutes of play time (stacks) | Jobs app (XP, from stage TheCall), after the first mission (Cash) |
ProcessReceipt lives in `MonetizationService` (Piece 2): grants once per PurchaseId, waits until the save holding it is written, then answers PurchaseGranted. The StarterPack's cash is granted once per save.
Kid-safe rules from [[CLAUDE]] apply: no fake timers or scarcity, grant only on the server, one ProcessReceipt, grant once per PurchaseId, answer "granted" only after the save, never sell something that does nothing yet ("coming soon" instead).

### The Ends: flat, power, goals (`Config/Property.lua`, `Config/Goals.lua`; tested by `tools/tests/test_flat_rules.py`)
- The flat costs **$1,200** (the robbery pays $1,500, so ~$640 is left with the job earnings). Power bill **$300**, paid once (phone Goals app or the breaker box by the door): the bulb comes on, the PC boots to an honest "no apps yet" screen.
- The room: one per owner (instanced, `PersistentPerPlayer` streaming), placeholder built from parts (stained mattress on pallets, CRT on a desk, boarded window, trash bags, pizza boxes, damp patches). Alex's model `ServerStorage.MTL_FlatInterior` replaces it: PrimaryPart at floor centre, door in the +Z wall, parts named as in `Config/Property.Interior.Points` (Entry, Exit, ChairSpot, BedSpot, BedStand floor markers; BedSeat = a Seat; Screen, Keyboard, PowerLed, Bulb, Window, Breaker). The cutscenes follow those parts (marks), so a different layout still lines up.
- Goals (in order): finish a full shift (+80 XP) · turn the power on (+60) · Level 8 (+100) · save $5,000 (+120) · a second gun, criminal only (+100) · Level 15 (+150) · Coming soon: first car, Dre's next job, move out of the Ends. Each pays once.

### Lighting and time of day (`Config/DayNight.lua`; tested by `tools/tests/test_daynight_rules.py`)
- Target look = Alex's hood references (vault `Vice Bay/References/Larp` + `Quality Target`): **day** warm, slightly hazy, crisp shadows, a bit desaturated; **evening** low gold sun into an orange/magenta sky; **night** purple-blue, sodium street lights, lit signs.
- One day = **28 real minutes**: Morning 05:36-09:30 (4 min) · Day 09:30-16:36 (11 min) · Evening 16:36-19:36 (5 min) · Night 19:36-05:36 (8 min). A fresh server starts at 08:12.
- The server owns only the clock (Workspace attributes `MTL_DayEpoch`, `MTL_DayFrozen`); it never writes Lighting. Every client blends 10 keyframes (midnight, pre-dawn, sunrise, morning, day, afternoon, golden hour, sunset, dusk, night) with smoothstep: Lighting, Atmosphere, ColorCorrection, Bloom, SunRays, Clouds. `GeographicLatitude = 41` (Miami's real 26 puts the noon sun overhead: flat streets). In game the place's own Sky is hidden on the client (Roblox's soft default sky gives real sunsets); the place keeps it.
- Street lights: the map's `StreetLight` / `ParkLamp` models (the Neon part is the head). Heads are unlit glass by day and glow sodium at night, each switching at a slightly different moment; the 40 closest to the camera (within 320 studs) get a real light, the closest 6 cast shadows. Fixed pool, so the cost never grows with the map.
- Quality pass (2026-11-02, Quality Gap Report #1/#2/#4): `Ambient` kept low (30-55 grey, the playbook rule) so interiors and shade get shape from real lights, not a flat wash; day sky hazed and desaturated (Haze 2.2, warm-grey Atmosphere, Saturation -0.12) instead of cartoon blue; Bloom Threshold 1.8 by day, 1.4 golden, 1.15 at night with night exposure 0.45 so white shirts, markings and signs stop glowing. **Eye adaptation** (`DayNight.Indoor`): a roof over the camera drops exposure 0.25 and raises the bloom threshold 0.4, eased over 0.8 s.
- View distance (2026-11-02, Alex: "show the city in the background"): Atmosphere Density about 0.16-0.19 and **Offset 0.06** on every key. Offset is what fades far blocks into the sky, so keep it low; Haze tints the horizon instead. The downtown towers are Atomic + `LevelOfDetail = StreamingMesh` (the map thread), so they draw as low-detail meshes beyond the streaming radius.
- Needs **Lighting.Technology = Future** (scripts can't set it). `tools/PreviewTime.lua` previews any hour in Edit mode (run it with `HOUR = nil` before saving).

### Guns (detail in [[Gun Mechanics]])
- Built in-house first (no purchase). Third-person over-the-shoulder aim (hold right-click / aim button), hitscan with server validation and lag compensation, recoil springs, tracers, muzzle flash, impacts, hitmarkers, reload, ammo HUD.
- Weapons only out of the holster for `Criminal` path; safe zones (spawn, job interiors, the flat) block shooting.
- Gun models: reuse the Blender gun set in `hood/art/models/roblox/` as placeholders (Pistol, Uzi, AK, Shotgun, Revolver, Deagle, Tommy).
- **Built (Piece 5).** 5 guns in `Config/Guns.lua` (shop level/price): Pistol (L5, $1,200, given by the crew after the first job), Uzi (L8), Shotgun (L10, 8 pellets), Revolver (L12), AK (L20). Body-shot time-to-kill on 100 HP at 20 studs: AK 0.30 s, Uzi 0.54 s, Pistol 0.63 s (5 shots), Shotgun 0.86 s, Revolver 1.0 s (2 headshots). Ammo types 9mm / 12g / .357 / 7.62, bought in packs in the **Plug** phone app (criminal path only).
- Server checks every shot: holding that gun, equip/reload time, ammo, RPM token bucket (+15%), muzzle within 7 studs of the head and not through a wall, ray inside the gun's widest cone (+4°), range, path + safe-zone rules, then a **lag-compensated hitbox** (20 Hz history, every sample from shot time −0.25 s to now, max 0.4 s back; 3.5 studs body / 1.6 head tolerance) and a map-only wall raycast. Hitmarkers only on server-confirmed hits.
- Feel (client): camera recoil = a stay part (full-auto climbs) + a spring part that bounces back; gun-model kick; muzzle flash + light + smoke; flying tracers (every shot for pistols, every 3rd for SMG/AK); sparks, dust, pooled bullet holes (40), small blood puffs; hitmarker (white / red head / bigger orange kill); directional red edge on the victim + shake; screen drains of colour under 45 HP; crosshair opens with the real spread; ADS = FOV 70→52-60, shoulder offset (1.75, 0.45), 60% walk speed, the character faces the aim; touch/gamepad get a 5° aim nudge when they start aiming. ReducedMotion scales kick/shake to 40%.
- Holster: the last live gun hangs on the hip (pistols/Uzi) or across the back (shotgun/AK) on the criminal path. No hold/aim animations exist yet: arms are posed in code (`GunPose`, R15). TODO(Alex anims) replaces it.
- Controls: PC 1-5 / X / LMB / hold RMB / R · gamepad Y (cycle) / R2 / L2 / B · touch: weapon bar, FIRE (hold), AIM (toggle), R. The phone wins: guns don't fire or aim while it's open, a click on the world that closes it doesn't shoot, opening it drops the aim.

### CLOUT, the social app (`Config/Social.lua`; detail in [[Social Media Hustle]]; tested by `tools/tests/test_social_rules.py`)
- Unlocks at FreePlay. Phone app "Clout" + desk computer app (Liberty OS, wide layout + Creator Studio). 15 photo spots on the map (score 0.7-2.0, light by time of day, some need a car).
- Post: cooldown 45 s, 3 free posts per 10 min then fatigue; viral 3.5-12% (x6-22), flop 12%. XP 16-70 per post, +25 new spot, +80 viral. Creator Fund $1.2 per 1K views from 1K followers.
- Sim (median player): 1K followers in 0.4 h, 10K in 1.6 h, 100K in 6.5 h, 1M in 20 h. Brand deals pay 60 x (followers/1K)^0.7 (about $60 at 1K, $300 at 10K, $1.5K at 100K, $7.5K at 1M), 3 a day.
- Courses at 10K followers + Level 12, recorded at the desk: $27/$97/$297/$997 (cost $1.5K-25K), max 3 live, platform fee 10%, sales vary daily (niche demand 0.4-1.9, mood 0.7-1.4). About $10K per 28-min day at 100K followers; day-to-day swing about 28%.
- Bots: 1K/$300, 10K/$2.5K, 100K/$20K. They never buy, cut deal pay above 30% share, stop deals above 60%, and a daily purge (30%) removes 40-80%.

---

## 5. Build order (one piece at a time, each one polished and play-tested before the next)

| Piece | What | Depends on | Thread |
|---|---|---|---|
| **0. Foundation** | Folder layout, Net, Signal, Config stubs, DataService + ProfileStore, EconomyService (cash/XP/levels + leaderstats), UIState, Theme/Motion, HUD (cash + level bar + objective line), StoryService skeleton, WaypointService + Wayfinding controller | — | first, alone |
| 1. Phone | Peek/rise phone, app host, Messages, Calls (incoming call card), notifications, Map/GPS app (sets waypoints), Settings (path switch) | 0 | Phone thread |
| 2. Jobs + leveling | JobService, Supermarket tasks (3 minigames), Mechanic + Restaurant tasks, Jobs app, level-up flow, passes/products hooks, StockMarket cash hook | 0, 1 (Jobs app) | Jobs thread |
| 3. Story: the call → first mission | Stages 3–7: the call, meet spot, gang intro cutscene, Cutscene system, robbery mission, payout + pass offer | 0, 1, 2 | Story thread |
| 4. Story: the Ends | Stages 8–12: buy the flat, power-out cutscene, choose-job funnel, sleep / next day, commute funnel | 3 | Story thread |
| 5. Guns | Gun framework, 3 starter guns, ammo, safe zones, PvP rules by path | 0 (and 3 uses a gun in the robbery: a no-damage "intimidate" mode first) | Guns thread |
| 6. Polish pass | Sounds, juice, funnel analytics review, mobile/console check, fresh-critic review | all | — |

Concurrency rules (several threads, **one Studio**):
1. Edit only the files your piece owns (table above). Shared files (`Net.lua`, `Config/*`, the save schema) can be **added to**, never restructured, and the change is written into this note.
2. **Only one thread play-tests at a time.** Before pressing Play, check the "Studio lock" line below; write your thread name there and clear it when you stop.
3. Before editing a vault file, read it again (others may have changed it).
4. Leave the place in Edit mode and saved (Alex: Cmd+S / publish) at the end of each piece.

**Studio lock:** free

---

## 6. Installing code into Studio
- `python3 tools/make_installer.py` turns everything in `src/` into one script, `tools/Install.lua`. Run it in Studio's Command Bar (or through the Studio MCP `execute_luau`, Edit mode). It writes every MTL script, creates missing folders, and saves `MTL_HUD` into StarterGui. It never touches anything outside the MTL folders.
- `src/ServerScriptService/MTL/Vendor/ProfileStore.lua` is copied from `hood/src/ServerScriptService/HoodServer/Vendor/ProfileStore.lua` (same vetted copy).
- Alex can use Rojo instead (`Miami Trap Life/default.project.json`); don't use both on the same session.
- **What actually worked (2026-11-02):** `tools/Install.lua` is ~800 KB, too big to send through the MCP. Instead run a file server on the Mac in the vault folder (`python3 -m http.server 34873 --bind 127.0.0.1`) and run `tools/HttpInstall.lua` in Edit mode: it turns HTTP on only while it runs, pulls every file in `tools/manifest.json`, writes the sources and saves every `UI/Build` screen into StarterGui. Small fixes can be pasted straight into a script's Source with `execute_luau`.
- **Testing from the MCP:** `execute_luau` runs in its own Lua VM, so `_G.MTL` is nil there. In Studio, Main.server.lua adds `ServerStorage.MTL_Debug` (a BindableFunction): `game.ServerStorage.MTL_Debug:Invoke("Story", "debugSet", p, "GangMeet")` calls `_G.MTL.Story.debugSet(p, "GangMeet")`. Don't probe the client camera while a cutscene plays: the Studio assistant resets the camera to Custom and breaks the scene.

### Testing the phone (server Command Bar while playing in Studio)
```lua
local p = game.Players:GetPlayers()[1]
_G.MTL.Phone.text(p, "Dre", "Spot's on your GPS.", { link = { kind = "waypoint", place = "Home", label = "Your place" } })
_G.MTL.Phone.call(p, "Recruit")                -- ring the unknown number
_G.MTL.Story.debugSet(p, "TheCall")            -- or jump the story to the call itself
_G.MTL.Story.debugSet(p, "FreePlay")           -- unlock Lifestyle in Settings
_G.MTL.Phone.notify(p, { app = "Jobs", title = "New job", text = "Car Wash unlocked" })
```
Checklist: peek visible bottom-right · hover lifts · click / M opens with a spring · M / click world closes · badge on closed phone after a text · banner tap opens the thread · Recents shows missed in red with "Call back" · GPS Route draws the breadcrumbs · Settings toggles persist in the snapshot · touch: phone sits left of the jump button.

### Testing guns (server Command Bar while playing in Studio)
```lua
local p = game.Players:GetPlayers()[1]
_G.MTL.Guns.debug(p, "Pistol")       -- Criminal path + the gun + 120 rounds + equipped (any id in Config/Guns.Order)
_G.MTL.Guns.dummy(p)                 -- a damageable R15 target dummy 15 studs in front (respawn it after it drops)
_G.MTL.Guns.dummy(p, "clerk")        -- an MTL_Intimidate dummy: aim at it, watch _G.MTL.Guns.Intimidating
_G.MTL.Guns.give(p, "Pistol", { temporary = true, mode = "Intimidate", ammo = 6 })  -- the robbery gun
_G.MTL.Guns.addAmmo(p, "9mm", 60)
```
Checklist (play solo, then a 2-player local server for PvP): 1 takes the gun out, crosshair appears, mouse icon hides · LMB fires: flash, tracer, spark + hole on walls, camera kicks and settles · hold RMB: zoom + shoulder cam, crosshair tightens, character faces the aim · Uzi held down climbs, stop and it settles · dummy: white hitmarker, red on head, bigger on kill · R reloads (bar), empty mag auto-reloads, empty everything = click + "Plug app" hint · walk into the Food Mart / spawn lot: "Safe zone: gun holstered" · switch to Civilian: gun away, can't take it out · M opens the phone mid-fight: no shots, aim drops; click the world to close: no shot · 2 players: both Criminal can hurt each other, a Civilian can't be hurt, the victim sees a red edge from the shooter's side · the other player sees your tracer/flash and hears the shot · touch emulator: FIRE/AIM/R buttons above the jump button, weapon bar taps.

### Testing the story: the call → first robbery (server Command Bar while playing in Studio)
```lua
local p = game.Players:GetPlayers()[1]
_G.MTL.Story.debugSet(p, "TheCall")       -- the unknown number rings; "I'm in" -> GangMeet
_G.MTL.Story.debugSet(p, "GangMeet")      -- meet spot texted + waypoint; _G.MTL.StoryCrew.meet(p) teleports you there
_G.MTL.Story.debugSet(p, "GangIntro")     -- the intro cutscene (hold SPACE to skip)
_G.MTL.Story.debugSet(p, "FirstMission")  -- the robbery from the car; _G.MTL.Missions.debugStep(p) completes a step
_G.MTL.Story.debugSet(p, "MissionDone")   -- payout + offer (says "debug, nothing paid" if the job wasn't played)
_G.MTL.Cutscenes.play(p, "GangIntro", { anchor = p.Character:GetPivot() })   -- any scene, anywhere
```
Before the first run: `tools/PlaceMissionPoints.lua` once (Edit mode), then drag Car / Door / Clerk / Register into the Food Mart; tag a part `MTL_MeetSpot` (attribute `Id`) at each real meet spot. Checklist: accept the call → "I'm in" text, Lifestyle shows Criminal, two texts from Unknown, breadcrumbs to the spot · from far away: car with blinking orange hazards + 3 crew members idling, heads turn toward you up close · arrive → black → intro: wide drift, Dre walks up, subtitles type out, heads turn to the speaker, tap = next line, hold = skip bar, push-in, "FIRST JOB" · fade in at the car: tracker top right, Nina + Dre by the car, glowing mask box · hold E (or press the prompt) → mask on your head · walk in → Kev outlined behind the counter · aim (RMB with the Guns piece; built-in hold-aim otherwise) → meter fills, Kev's hands go up, "Okay okay!" · hold at the till → bag on your back, alarm: red edges, flashing light, clean-getaway timer · reach the car → outro, black, crew lines → payout counts up (HUD cash ticks) → CONTINUE → offer with prices or "Coming soon" → Maybe later → "Get a place in the Ends" · die mid-robbery → back at the car with a toast · leave mid-outro and rejoin → no second payout, outro replays.

### Testing the Ends: flat → move-in → pick a job → sleep → commute (server Command Bar while playing in Studio)
```lua
local p = game.Players:GetPlayers()[1]
_G.MTL.Economy.addCash(p, 2000, "Debug", false)
_G.MTL.Story.debugSet(p, "FindAPlace")   -- Dre texts, waypoint + FOR SALE sign on the door; walk up -> the card
_G.MTL.Story.debugSet(p, "MoveIn")       -- (gives the flat if needed) fade in, PowerOut scene, phone opens on Jobs
_G.MTL.Story.debugSet(p, "FirstNight")   -- bed outline + Sleep
_G.MTL.Property.debug(p)                 -- just give the flat and walk in;  _G.MTL.Property.leave(p)
_G.MTL.Property.payPower(p)              -- power on (bulb, PC screen)
_G.MTL.Cutscenes.play(p, "PowerOut", { anchor = _G.MTL.Property.room(p).origin, marks = _G.MTL.Property.room(p).marks })
```
Checklist: after the offer card, Dre's 2 texts + breadcrumbs to the door, FOR SALE sign readable from down the street · reach the door: card pops up (photo slot, 3 facts, price, your cash, BUY IT · $1,200) · not enough cash: red line + "NEED $X" · BUY: banner, fade, you're inside a grim room (one cold light through the boards) · scene: bulb flickers and dies, sit, click, dead screen hold, click, 3 smashes with shakes, silence, bed flop, phone glow on the face, last line · camera returns with you sat on the bed and the phone rises on Jobs · 3 cards pulse, CHOOSE → confirm → Yes → YOU'RE HIRED · put the phone away: bed outlined + "Sleep" marker · Sleep: NEXT DAY card, morning light, alarm, stretch · boss text arrives · front door outlined, Leave → outside facing the street, breadcrumbs to work, "Get to work: ..." · at work "Clock in at the time clock" → clock in → FREE PLAY banner, Goals app, objective "Goal: Finish a full shift" · rejoin at any of these stages: you wake up inside your room · picking the Food Mart works too.

### Testing the time of day (server Command Bar while playing in Studio)
```lua
_G.MTL.Time.freeze(7)      -- morning (also 12 day, 17.5 evening, 22 night); _G.MTL.Time.freeze() runs again
_G.MTL.Time.setClock(18)   -- jump, keeps running
-- MCP: game.ServerStorage.MTL_Debug:Invoke("Time", "freeze", 22)
```
Checklist: the sun moves smoothly · golden light around 17:00, orange-pink sky at sunset, purple dusk · street light heads switch on one by one at dusk and light the road · PowerOut plays at night even at noon · NextDay goes from night to 7 AM behind the NEXT DAY card · walking out of the flat blends back to the world's time.

### Testing jobs (server Command Bar while playing in Studio)
```lua
local p = game.Players:GetPlayers()[1]
_G.MTL.Jobs.debug(p, "Supermarket")             -- pick a job and clock in where you stand (any job id from Config/Jobs.Order)
_G.MTL.Economy.addXP(p, 2000, "Debug")          -- jump levels (tier 2 opens at 8, tier 3 at 15)
_G.MTL.Story.debugSet(p, "ChooseJob")           -- the 3-card pick in the Jobs app
_G.MTL.Jobs.clockOut(p)
```
Checklist: Food Mart: walk in -> clocked in by itself, panel top-right shows the task, glow + marker on the stockroom · Grab box -> box in your hands, slower walk -> glowing shelf -> hold E (or the big button): products pop onto the shelf · Mop: spill shrinks while held, creeps back when you let go · Trash: bag at the bin -> dumpster out back · "+$8" flies to the cash, "+22 XP" to the bar · PERFECT flourish · 8 tasks -> SHIFT COMPLETE card · walk far away -> red countdown, shift ends · phone Jobs app: YOUR JOB card + right button (Route / Clock in / End shift) · touch: big HOLD button works, gamepad A/X work, B backs out · post job: green ring, "Still on post?" card pauses pay.

## 7. Status log (newest first; every thread adds a line when it finishes)
- 2026-11-03 · HUD thread · **LihFolk P0 #5 + #6 in Studio and play-checked.** `KeyHints` (context hints beside the minimap: on foot / crouched / gun / aiming / car / phone; keyboard only; Settings.KeyHintsMode 0 auto = gone after 10 min, 1 always, 2 never). `AudioMixer` (SoundGroups MTL_Music 80% / MTL_SFX / MTL_UI / MTL_Ambience; every Sound without a group is sorted in by where it lives; Settings MusicVol/SfxVol/UIVol/AmbVol 0-100). HUD **Settings popup** (menu → Settings): 4 volume sliders (live preview, save on release), Sprint Hold/Toggle (Settings.SprintToggle, read by MovementController's keyboard Shift), Key hints, Camera shake (Settings.Shake, CamShake), Graphics, Reduced motion, Rejoin (TeleportToPlaceInstance). **`Notify.refuse(player, reason)`**: every system should use it for refusals ("Need $120 more"); client shows a red-edged toast with a shake + Error sound, repeats don't stack (`HUD.refuse` client-side too). New SettingKeys in Config/Phone.
- 2026-11-03 · Social media thread · **CLOUT installed in Edit (not yet play-tested).** New `Config/Social`, `Rules/SocialRules`, `UI/CloutArt`, `Services/SocialService`, `Apps/Clout` (phone) and `Controllers/OS/Apps/Clout` (desk). Shared additions: Net `SocialState`/`SocialAction`, save `Social`, Main boot line, `Config/Phone` app, Theme glyph/colour, 3 `Config/Earn` hustles, `Config/OS` Clout entry. Balance sim 0 failures. Detail and numbers: [[Social Media Hustle]].
- 2026-11-03 · Story thread: **Act 2 "The Tab" built** (Story Bible 2.1, 2.2, 2.3, 2.7). New `Config/Chapters` (chapters, missions, places, choice costs) and `Services/StoryMissions` run after FreePlay: chapter save in `Story.Data` (`Chapter`, `Missions`, `Choices`), steps go/scene/texts, rewards, contacts. The Story app reads the player attribute **`MTL_Story`** (JSON, the phone thread's shape: chapter, chapterTitle, chapters[{n,title,state}], missions[{id,title,state,giver,blurb,level,line}], objective{text,place}, cast[{id,name,role}]); the phone thread owns the view. 6 scenes: BackOfHouse, RoyceSoda, KevKnows, Cash4Gold, Rooftop, TheTab. Choice cards in scenes; hand-held items; new props DeliveryTruck, Pallet, BusinessCard, SodaCan, Envelope; Driver rig. Studio: `_G.MTL.StoryMissions.debugStart(player, "KevKnows")`. Not yet play-tested. Also: party cutscenes with skip votes, `CutsceneService.playGroup` (new remotes `CutsceneInput` C→S and `CutsceneSync` S→C).
- 2026-11-02 · Minimap thread · **Round radar + GPS along the roads + full-screen map, installed in Edit (Play test queued).** New: `Controllers/MinimapController` (radar bottom-left on desktop, under the top bar on touch; turns with the camera, zooms out with speed; place blips from `Config/HUD.Markers` + `Config/Phone.Places`; gold diamond for the route target, stuck to the rim when far; street name above; route distance pill; tap the radar, press N or the MAP menu tile for the full map: drag/scroll/pinch, click a place or anywhere to drop a client-only `MapPin` waypoint snapped to the nearest road, click it again or Clear to remove, cleared on arrival), `Rules/RoadGraph` (pure: road rects cut into ~56-stud cells, linked where they touch at the same height, A* + Douglas-Peucker; 4,644 nodes, ~50 ms build on the client, routes under 5 ms; pieces that don't join the streets (lots, raceway, airside) route to the nearest street point), `Config/Minimap`, `tools/BakeRoadMap.lua` -> **`ReplicatedStorage.MTL_RoadMap`** (generated, outside the Rojo tree; 1,952 asphalt rects + 141 street names from ViceBay incl. HoodNorth/HoodWest; re-run after road edits; needed because StreamingEnabled hides far parts). Changed: `WayfindingController` (`list()`, `primary()`, `Changed`), `MenuController` (`action = "map"`), `Config/HUD` (MAP tile opens the map, hint N), Client boot line after MapMarkers. Known: the CanvasGroup circle clip doesn't render in Studio's Edit GUI preview; if it also fails in Play, set `Config/Minimap.Shape = "Rounded"`. River/canal water isn't drawn yet (those parts aren't flat water).

- 2026-11-02 · Hood Life thread · **Ambient rigs can't reach a client half-built; installed in Edit (not play-tested).** The `rig has no Humanoid/HumanoidRootPart: Ambient_Street8` warning came from `Actors.adopt` called by `AmbientPeople`. It runs on a clone of `MTL_AmbientRigs.Street8` (the `Ambient_` prefix is just the actor name). Nothing named that was ever in `MTL_Actors`, and no place in Studio holds a saved Street8, since the rigs are built at runtime. Street8 builds cleanly on its own (Edit build and a later live play session both gave 229 descendants with root and Humanoid), so the likely cause is the client cloning a rig the moment `ChildAdded` fires, before all its parts have replicated (it can also happen when a catalog load fails). Fix: `AmbientRigService.valid(model)` (Humanoid + HumanoidRootPart + Head). `build` goes full outfit, then colours only, then skips the rig, and checks it again after `ScaleTo`. It never publishes a rig without both parts. It also stamps a `Parts` attribute (descendant count) and replaces a broken rig already in the folder. `AmbientPeople` only clones a rig once it's complete (descendants >= `Parts` and both parts present), waits up to 15 s for one still arriving, and doesn't count a rig that adopt rejects. `Actors.lua` is untouched. All 8 test suites pass, Lune compiles both files, and the Studio copies match the files on disk.
- 2026-11-02 · Welcome cutscenes + tutorial thread (round 4) · Installed + play-tested: dialogue box with live 3D speaker portraits (`UI/Build/Cutscene` Subtitle/{Portrait/{View, Initial, Ring}, Text/{Speaker, Line}, Next}), typing tick `Theme.Sfx.TextBlip`, walk cycle speed matched to movement (`Missions.WalkAnimRef`), FirstDay restaged through the doorway with cutscene sliding doors (`Actors` prop `GlassDoor`, 18.8 s), ticker kept hidden during scenes. Notes: `Research/Cinematic Cutscenes.md` §12.

- 2026-11-02 · Hood Life thread · **Shop-interior sound zones fixed, installed in Edit (not play-tested).** The Food Mart read `StreetDay` indoors: its rebuilt `InteriorV2` is 110 studs wide, so most of it lay outside the old 18-stud circle round `Locations.FoodMart.Inside`, and the Burger Shack / Westside Auto `Inside` points are on the sidewalk outside both buildings. New rule `AmbientRules.shopAt`: you're in a shop if there's a roof over you **and** the floor under you (Food Mart, Burger Shack) or the roof over you (Westside Auto, whose floor is terrain) belongs to a model named `FoodMart*` / `BurgerShack*` / `AutoShop*`, within `Ambient.Sound.ShopFind` (110) of that shop's Locations Inside/Door. It follows rebuilds as long as the names keep those prefixes. `Ambient.Sound.Shops` is now `{ key, model, by, r }`; `r` = a fallback circle round Inside (Food Mart 10; 0 for the other two). `AmbientSound` makes 2 raycasts per 10 Hz step. Tests: +22 `shop.*` checks (all 8 suites pass). Live raycast check in Edit: 256/256, 256/256 and 223/240 roofed points inside BurgerShackV2 / AutoShopV2 / Food Mart InteriorV2 read Shop; the 17 Food Mart points that don't are behind its back wall. Points just outside the walls reading Shop: 0/88, 1/88 (3 studs past the Auto garage wall, under its roof), 0/88. Map note for the gameplay owners: `Locations.BurgerShack.Inside` and `WestsideAuto.Inside` (z -445) are outside the buildings (Burger Shack floor z -493..-453, Auto -495..-461).
- 2026-11-02 · Welcome cutscenes + tutorial thread · Robbery play-test fixes installed in Edit (not re-played): mask box/crew now use the floored car point (MissionController), CrewCar scaled to 0.7 (14.7 x 6.8) so the crew and player spots made for the old 13-stud box stay outside the body, cutscene subtitles sit above the Fade (lines over black read; MTL_Cutscene re-saved), payout/offer Dim reaches 80 px under the top bar (Build/Mission + saved MTL_Mission).
- 2026-11-02 · Hood Life thread (the living neighbourhood) · **Installed in Edit; the ambient layer ran clean in another thread's Play test** (`[MTL Ambient] on: 321 spots, 195 walks, 10 lanes, 600 windows`, 24 rigs built / 0 failed, no errors). Client-only living layer, one Heartbeat (near = every frame, far = 10 Hz): `Controllers/AmbientLife` (booted last) + helpers `AmbientPeople` (≤14 pooled rigs: walkers on sidewalks, stoop sitters, corner groups gesturing, vignette actors, head turn + 1-in-4 speech bubbles, hands up / run on gunshots or aiming, back after 30 s, crowd by hour, night crowd under lamps), `AmbientTraffic` (4-6 SedanA clones on lane loops, BulkMoveTo, axle steering, corner braking, stop + honk for player/peds, 1 in 3 bass, Neon lights at night + SpotLight on nearest 2), `AmbientBirds` (pigeon flocks scatter/return, wire birds, canal gulls, ≤60 parts), `AmbientSound` (owns **SoundService.MTL_Ambience** SoundGroup: zone beds Street/Alley/Shop/Underpass/Canal day+night with 2 s crossfade + night crickets, nearest-8 positional emitters: window radios, AC, dog, hoop, grill, murmur, coos, car bass/engine; one-shots; all ids real free Creator Store, mostly PSE), `AmbientWindows` (night window glow 35-45 %, 4 % TV, off one by one after 1 am; laundry/flag sway via tag `MTL_Sway`; shop neon flicker via tag `MTL_Flicker`). New config: `Config/Ambient.lua` (tunables), **`Config/Outfits.lua` (24 shared catalog outfits by role: Street, Crew, Elder, ChurchLady, Kid, Hooper, Worker, Shopkeeper; `Outfits.description(o)` -> HumanoidDescription; cutscenes/jobs can use it)**, `Config/AmbientMap.lua` (GENERATED by `tools/SurveyHoodLife.lua` -> `tools/survey/*.json` -> `tools/build_ambient_map.py`; never hand-edit). Pure maths `Rules/AmbientRules.lua` + `tools/tests/test_ambient_rules.py` (52 checks). Server: `Services/AmbientRigService` (builds outfits into `ReplicatedStorage.MTL_AmbientRigs`, colours-only fallback). Shared changes: `Actors.adopt(model, name, parent)` (spawn split), boot lines in Client/Main. Map dressing (`tools/DressHoodLife.lua`, idempotent, only `Workspace.MTL_HoodLife` + `ReplicatedStorage.MTL_AmbientCars`): 54 personality shop signs over the shops' own Sign parts + OPEN/EBT/hours/NO LOITERING, church marquee, R.I.P. Lil Dre memorial, handprints mural, 40 power-line spans + sneakers, 24 pole flyers, 6 laundry lines, vignettes (domino, car on blocks + mechanic, BBQ, yard sale, beware-of-dog, carts, crate hoop) that add NPC spots; 1,148 parts, 5 new lights. Install: `tools/InstallHoodLife.lua` (only Hood Life files + in-place boot patches; never the full installer, Studio is newer). Edit-mode shots: `tools/PreviewHoodLife.lua` + `tools/ShotsHoodLife.lua` -> `screens/life/hoodlife_v1_*` (+ grids, zip). **Next / known:** floating dog vignette + hoop beside the real park court + memorial in HoodWest + no Welcome mural + tight corner groups are fixed on disk, not yet re-run; Shift+F2/F9 numbers and a sound check need a Play test.
- 2026-11-02 · Gameplay feel thread · **Movement + pacing + juice, installed (Edit mode); movement/jobs/story timing play-tested, juice/death not yet.** New: `Config/Movement.lua`, `Controllers/MovementController.lua` (the only WalkSpeed writer: walk 16 / sprint 24 eased 0.25 s up 0.15 s down; LeftShift hold, L3 / touch RUN toggle; +7 FOV additive kick; sprint bob, strafe roll, landing dip as a transient camera offset at Camera-1/Camera+2; lean via Root C0; 0.3 s jump cooldown; `setModifier`/`punch` API), `Controllers/Juice.lua` (hit-stop + punch on PERFECT/kills), `Controllers/InteractFX.lua` (prompt pop/sound/nod), `Controllers/DeathController.lua` + `UI/Build/Dropped.lua` (MTL_Dropped saved to StarterGui), `Research/Movement and Game Feel.md`. Changed: `Config/Levels` (call at **Level 4**, `CriminalTeaseLevel = 3`, unlock lines 4/5 swapped), `Config/Jobs` (PerfectBonusLevel 5), `Config/Tutorial` + `Config/Story` text, `Config/Guns` (Fire = 9117399569 PSE pistol, TODO(Alex) swap), `UI/Theme` (+Sfx PromptDone, Dropped), `Services/PhoneStory` (Level 3 "Unknown" tease), `GunController` (aim uses the Aim modifier, kill juice, on-shift hint), `JobController` (PERFECT juice, flash outline fades, story shift auto-continues), `WayfindingController` (edge arrow falls back to the newest waypoint), `Client` boot lines, `tools/tests/test_job_rules.py`. StarterPlayer.EnableMouseLockOption = false. Play-tested: sprint/FOV/carry, Food Mart trash + restock on the new objects, Level 3 tease, Level 4 call, gun equip/fire. Not tested: robbery, Burger Shack, Westside Auto, a dummy hit, touch/gamepad sprint, juice, dropped state. Note: Studio's Client boot list doesn't have the HUD thread's `PromptController` line yet (install it with that controller). Later in the vault (push pending): `Jobs.Carry.WalkSpeed` 12 -> 14, a one-time "offer's still open" text 90 s after a declined/missed call (PhoneStory), RUN touch button placed above the jump button and hidden while the gun's touch buttons show, InteractFX no longer shortens prompt holds on the client (the server checks its own HoldDuration: make tap prompts 0 where they're created). Play slot #2: all 9 jobs pass 2 tasks each (prompts present, pay/XP), robbery runs start to payout, dropped state + edge arrow + call nudge verified; the lean was still missing because this place uses AnimationConstraint rigs (fixed in the vault: tilts Attachment0), and `Jobs.RepeatWeight` (no back-to-back task repeats) added; both pushed (Edit). Then GunPose takes Motor6D or AnimationConstraint shoulders (pushed), and Config/Jobs got 2-4 more tasks each for Cashier (BagGroceries, CountTill, GumRack), CarWash (Rinse, DryBuff, Vacuum, TireShine), Valet (FetchCar, KeyBoard) and Trucker (PreTrip, StrapLoad; Delivery now uses 4 local sidewalk drops 190-375 studs from the dock + a `Truck` station on Port Rd), $/min unchanged, tests added (pushed, Edit). **Known gap: no vehicle system, so no depot truck spawner; the far drops wait for it.** Play check 3 (17:12): lean works on AnimationConstraint rigs (~5° at full sprint), GunPose writes the shoulder Transform on AnimationConstraint shoulders, a dummy kill reaches the client (kill juice path), call screen opaque. Play check 4 (17:47): every new task finishes in Play (Cashier BagGroceries/CountTill/GumRack, CarWash Vacuum/DryBuff/TireShine, Valet KeyBoard/FetchCar, Trucker PreTrip/StrapLoad + all 4 local drops; Rinse not drawn but same shape as Vacuum); robbery: mask box at the car, no crew overlap, subtitles over black, payout dim full-screen; FirstMission.Door point sits 6.5 studs above the ground (story thread). Still untested: touch/gamepad sprint.
- 2026-11-02 · Welcome cutscenes + tutorial thread (round 3) · Installed + play-tested: crew/Kev/Patel wear Roblox-made catalog clothes + hair (`Config/Missions.Actors` ShirtId/PantsId/Hair/Hat/FaceAcc, `CutsceneService.buildRig`), phone in hand for phone poses (`Actors.lua`; PropertyController's PhoneOut skips if one exists), real CrewCar prop saved in `ReplicatedStorage.MTL_Actors.CrewCar` (from VBAssets.SedanA), gestures stay procedural during held poses, Patel moved clear of the register, coach card top-left at x 110. Notes: `Research/Cinematic Cutscenes.md` §11.
- 2026-11-02 · Welcome cutscenes + tutorial thread (round 2) · **Installed and play-tested.** Real Roblox-owned animations in every scene (`Config/Missions.Animations`: Idle, Walk, Wave, Point, Shrug, Nod, Laugh, Cheer, Salute, Stretch; layered in `Actors.lua` with the head turn on Neck C0). Fixes: floating actors (floor raycast skipped invisible/non-collide parts), camera wobble (aim above the root, camera bound at RenderPriority.Last, player attr `MTL_Cutscene` while a scene plays: camera effects must skip it), wall check ignores glass/plexi, camera fill light at night. Cinematic pass on GangIntro (spline crane, dusk hour 20.7, focus pulls, crew music), RobberyOutro (low kerb shot), PowerOut, NextDay; FirstDay restaged for the rebuilt store (checkout east, door x -1442). Writing: new lines, film subtitles inside the letterbox (`UI/Build/Cutscene` adds `Title/Rule`), tutorial copy + Montserrat. Licensed audio in `Theme.Cutscene.Sounds` / `Theme.Mission.Sounds.Ambience`. Non-MTL screens + chat hide during scenes. Notes: `Research/Cinematic Cutscenes.md` §10.
- 2026-11-02 · Phone thread · **Phone phase 3 installed + play-tested** (3 runs). Phone sits lower (peek 7%, tilt 0, open 14 px off the bottom) and moves on a spring (`Tuning.Spring*`); hover uses a mouse-in-rect test, not MouseEnter/Leave. Rounded modern look (`Theme.Phone.LowPoly=false`; true = faceted look via `UI/LowPoly.lua`): metal rim, sunset placeholder wallpaper, emoji glyphs (`Theme.Phone.Glyphs`), dock (`Theme.Phone.Dock`; find icons with `Home:FindFirstChild("App_"..id, true)`). **New shared:** `UI/Sfx.lua` + `Theme.Sfx` (all UI sounds by name; Settings > Sound effects mutes). Every built-in beep removed game-wide; all ids are Creator Marketplace (mostly PSE), 39/39 load; `JobFX.sound` pitch capped at 1.05; gun sounds wired except Fire (pick: 9117399569). **New phone:** Camera app (photo/selfie, filters on Z/X since E is interact, CaptureService save), Messages redesign (avatars, grouped bubbles, Delivered, compose bar + QuickReplies, typing dots), server action `quickReply{contact,index}` + PhoneEvent `{type="typing",contact}`, `Config/Phone.QuickReplies/AutoReplies`. Phone API adds `Phone.sfx`, `Phone.setViewfinder`, `Phone.setCaptureHidden`; ctx adds `Motion`, `sfx`. Escape can't close the phone (Roblox menu); M toggles.
- 2026-11-02 · Welcome cutscenes + tutorial thread · **Installed and play-tested in Studio.** Research: `Research/Cinematic Cutscenes.md` (camera language, pacing, easing, light/DOF, transitions, Roblox techniques, a 10-point checklist, tutorial findings) + screenshots in `Research/Cutscene shots/`. New: `Cutscenes/Welcome.lua` (26.6 s), `Cutscenes/FirstDay.lua` (16.4 s, staged inside the real store), `Services/StoryWelcome.lua`, `Config/Tutorial.lua`, `Rules/TutorialRules.lua`, `UI/Build/Tutorial.lua` (MTL_Tutorial saved to StarterGui), `Controllers/TutorialController.lua` (6 steps: open phone → walk to the store → first task with the live task name → payday → level ring → menu; ring + arrow on the real element; skip any time). Changed: `CutsceneController` (spline paths, gameplay hand-off, focus/blur, held hour, music, streaming, placePlayer, skip lands behind the player, shot.safe), `LightingController` (holds `scene.hour`, releases over 4 s), `Theme` (+Cutscene sounds WelcomeMusic/City/StoreBell, +Tutorial), `Config/Missions.Actors.Patel`, `Config/Phone.SettingKeys.Tutorial`, boot lines, `tools/manifest.json`. Tested: welcome plays and hands off with no snap, skip lands behind you, phone step (ring moves to Messages), walk step, Patel scene inside the store, job step shows "Now: <task>", no MTL errors. **Not tested:** payday/level/menu steps (timer steps), touch and gamepad wording. **Waiting on Alex:** welcome music + city ambience ids, a Patel rig (`ReplicatedStorage.MTL_Actors.Patel`), wave/point/nod/phone animations. Map note: Food Mart's glass front is at z = -323.7 and `Locations.FoodMart.Door` sits outside it.
- 2026-11-02 · HUD thread · **New main HUD, installed and play-tested.** `UI/Build/HUD.lua` rebuilt (MTL_HUD saved in StarterGui): top-right green cash pill + status row (LEVEL text, level ring = XP progress, health ring; rings are two half-masks with a hard UIGradient step, `HUD.setRing(ring, p, color?)`), objective pill moved to y=64 (under the VBX News ticker), toasts/banner/pops kept. New `Config/HUD.lua` (menu tiles, Store rows, emotes, hotbar emoji, 49 map markers with positions copied from the Vice Bay POIs) and `Theme.HUD`. New client controllers (booted after GunController): **MenuController** (left icon menu: the button shrinks away and the 2-column panel slides in, `<` tab / G / DPadLeft / Esc closes it; tiles open phone apps via `PhoneController.open/toggle`, Plug only on the Criminal path, Store popup buys through PhoneAction `buy{item}`, Emotes popup plays the character's own Animate emotes and stops when you move), **HotbarController** (round slots: 1 = fists/holster, guns 2-6, Backpack tools after; hides MTL_Gun's WeaponBar and the Roblox backpack; shifts left to keep the phone corner clear), **MapMarkers** (MTL_Markers ScreenGui, IgnoreGuiInset, placed with WorldToViewportPoint every frame; nearer markers win, farther overlapping ones hide, one name+distance tag at a time; switches off the map's 39 `MapIcon` POI billboards on the client). `Config/Guns.Keys`: Slots now Two-Six, One added to Holster. All HUD sounds go through `UI/Sfx.lua` (Tap/Hover/Open/Close). **Low-poly pass:** shared tokens `Theme.LowPoly` + helper `UI/LowPoly.lua` (`LowPoly.style(frame, color, {outline?, corner?, rim?})` = three flat diagonal facet bands, bold dark mitred outline, small hard corners; it moves button text into a child `Text` label so the gradient does not tint it). The whole HUD uses it; the phone thread was asked to use it too. **Polish pass (15:45):** Store is now a 720x500 storefront (Config/HUD.StoreTabs + Store cards with `tab`, `color`, `ribbon`; prices read live with MarketplaceService:GetProductInfo once the ids are set, SOON while 0, OWNED from `MTL_Pass_<item>`; wallet chip), every popup dims + blurs the game (`Panels/Dim`, Lighting `MTL_MenuBlur`) and closes on a click outside, and Emotes is a wheel with the name in the hub. **16:20 pass:** new `PromptController` (booted after MapMarkers) draws every Default-style ProximityPrompt with `Build/HUD.prompt()` (low-poly key tile, hold fill, tap = InputHoldBegin/End); Custom-style prompts are left alone; it never changes HoldDuration. Toasts are low-poly and sit at x=92 (right of the menu button); the level-up banner has a faceted ribbon; the objective has a gold "!" tile. MapMarkers now never draws over HUD elements or waypoint labels, hides a marker within 40 studs of an active waypoint, hides waypoint labels that would sit under the HUD, and hides everything while a roof is over the camera. Note: client-made BillboardGuis do not show in Studio MCP screen captures; verify them with execute_luau reads. Emoji are placeholders: put image ids in `Theme.HUD.Images[<menu id> / "Cash" / "MenuButton" / "Fists" / "Gun_<id>"]`.
- 2026-11-02 · Lighting thread · **Atmospheric lighting + day-night cycle installed and play-tested.** New: `Config/DayNight.lua` (4 phases, 10 keyframes tuned against Alex's hood references, street-light settings, story hours), `Rules/DayNightRules.lua` (pure, 20 checks in `tools/tests/test_daynight_rules.py`), `Services/TimeService.lua` (world clock as Workspace attributes; `_G.MTL.Time`), `Controllers/LightingController.lua` (client blend, latitude 41, default sky, street lights with a nearest-40 light pool, local story holds), `tools/PreviewTime.lua` (Edit-mode preview). Changed: `Main` + `Client` boot lines, `Cutscenes/NextDay.lua` (+ `WorldMorning` beat at 5.25 s), `test_flat_rules.py` knows the new beat, `tools/manifest.json`. Tested in Studio: phases switch, PowerOut held at 21:24 while the world was at noon, NextDay 23:18 → 07:00 on the card, hold released on leaving the room, 18 lamp lights live at night near the spawn, no MTL errors. Screenshots: `Research/Lighting shots/`. The place's Lighting is left on the Day look with latitude 41 (Sky untouched). **Not done:** lit windows at night (needs a window pass on the hood buildings), real light-on sounds; the asphalt reads pale at noon because of the road material colour, not the lighting.
- 2026-11-02 · Foundation thread · **Everything installed and play-tested in Studio** (82 scripts + 8 StarterGui screens; ProfileStore copied into Vendor; Mock data in Studio). Full story run from start to FreePlay works: $50 start → Food Mart clock-in → XP/levels → Level 5 call → accept → meet + GangIntro (19-39 s) → robbery steps → payout ($1,750) + RobberyOutro → offer card → FOR SALE card + buy ($1,200) → PowerOut gag → phone rises on Jobs → CHOOSE Mechanic → YOU'RE HIRED → bed → NextDay → front door → commute → clock in → FREE PLAY + goal "Finish a full shift". Guns: Pistol equips, server validates and applies hits on the test dummy (22 per body shot). No MTL errors in Output. **Fixed in play-test:** (1) `UIState` hung on `WaitForChild("PlayerModule")` (place has none) so every cutscene sat on a black screen with the HUD off; now never yields and locks movement through ContextActionService. (2) Phone banner child `Text` → `Body`. (3) Mission tracker child `Name` → `MissionName` (crashed MissionController). (4) Client boot now waits for the saved `MTL_*` screens to reach PlayerGui first (players got two of every screen). (5) Added `ServerStorage.MTL_Debug` for MCP testing. **Seen once, not reproduced:** after PowerOut the phone stayed down instead of opening on Jobs (that run had camera probes during the scene; the clean rerun opened it correctly). The ChooseJob nudge banner covers it if it happens. **Not tested by a human yet:** feel and visuals (phone peek/spring, cutscene shots, breadcrumbs), real mouse shooting, mobile/gamepad. Harmless noise: placeholder images `rbxassetid://0` log "asset not found" until Alex's art arrives; Lamborghini Urus (A-Chassis) and map texture errors are from the map, not ours.
- 2026-11-01 · Story thread (the Ends) · **Piece 4 code written** (stages 8-13: buy the flat → PowerOut gag → pick a job in the phone → sleep → NEXT DAY → commute → FreePlay goals). New: `Config/Property.lua` (homes, slots, room points, texts, job hooks), `Config/Goals.lua` (9 goals), `Rules/PropertyRules.lua` + `Rules/GoalRules.lua` (pure, tested), `Cutscenes/PowerOut.lua` (~16 s) + `Cutscenes/NextDay.lua` (~10 s), `UI/Build/Property.lua` (MTL_Property: FOR SALE card + door fade), `Services/PropertyService.lua` (door prompt, buy, instanced rooms with a part-built dirty placeholder, fade + teleport in/out with a 0.6 s anchor so nobody falls through a streaming floor, bed/PC/breaker prompts, power bill, stage hooks 8-13, home spawn on rejoin), `Services/GoalService.lua`, `Controllers/PropertyController.lua` (card, fade, door outline + FOR SALE billboard, bed/front-door outlines, room power visuals, phone opener + ChooseJob nudge, 6 cutscene beats), `Apps/Goals.lua`, `tools/tests/test_flat_rules.py` (45 checks: buying, slots, room points, story wiring, goal logic, both scenes validated incl. every mark, comedy timing). Changed (small, additive): Jobs app gets the 2-step story funnel (pick → confirm → hired/sleep) and measures distances from your front door while you're inside; `JobService.setJob` accepts re-picking the Food Mart at ChooseJob (it used to refuse "already your job", which would have blocked the story); CutsceneController: scene `marks` + a fade "in" after a fade "out" now fades back from black (it used to pop); CutsceneService passes `marks`; Rig: poses `SitType/SitSlump/SitPhone`, gestures `Press/Stretch` (+ animation slots); Net `PropertyState/PropertyAction`; schema `Home.PowerOn`, `Goals.Done`, `Phone.Apps.Goals=false`; `Story.Contacts.You` (inner lines), `Story.Objectives` 8/12 wording; `Locations.EndsFlat.Out`; Theme `Property`, cutscene sounds Click/Keys/BedCreak/Alarm/RoomTone, Goals app colour/icon; boot lines + `_G.MTL.Property/Goals`. Checks: all 5 test suites pass, block balance clean on every file, installer rebuilt (81 scripts). **Not installed or play-tested** (Mac offline). Waiting on assets: the real interior model (`ServerStorage.MTL_FlatInterior`), a room photo for the card, job photos for the 3 cards, sounds (bed creak, room tone, keyboard smash, alarm, door), animations for Press/Smash/Flop/Stretch. Known limits: one starter home only; the power bill is paid once (no recurring bills); the PC has no apps yet ("coming soon", honest); the bed lie-down is a sit (no lying pose without real animations).
- 2026-11-01 · Story thread · **Piece 3 code written** (stages 3-7: the call → meet → crew intro → robbing Liberty Food Mart → payout + offer). New: `Config/Missions.lua` (crew looks, meet layout, robbery steps/points/pay, offer items, animation id slots), `Rules/MissionRules.lua` + `Rules/CutsceneRules.lua` (pure, tested), `Rig.lua` (procedural R15/R6 poses: 8 held poses, 10 gestures, walk cycle, head look), `Cutscenes/GangIntro.lua` (~39 s) + `Cutscenes/RobberyOutro.lua` (~11 s), `UI/Build/Cutscene.lua` (MTL_Cutscene) + `UI/Build/Mission.lua` (MTL_Mission), `Services/CutsceneService.lua`, `Services/MissionService.lua`, `Services/StoryCrew.lua`, `Controllers/CutsceneController.lua` (+ `Actors.lua`), `Controllers/MissionController.lua`, `tools/PlaceMissionPoints.lua`, `tools/tests/test_story_rules.py` (39 checks incl. both scenes validated: order, speakers, readable line lengths, FOV range, no linear camera). Shared adds: `Theme.Cutscene` + `Theme.Mission`, `Story.Contacts.Kev`, Net payload comments, boot lines + `_G.MTL.Cutscenes/Missions/StoryCrew`. Cutscene system: clock-driven (skip = jump the clock, one pcall'd cleanup), tap = finish/next line, hold 0.6 s = skip after a 1 s grace, letterbox, typewriter subtitles, title cards, fades, colour grade + DOF, handheld noise, camera wall-safety raycast, player's own avatar cloned as the star, helper shots (two-shot / close / over-the-shoulder) that follow the actors, `holdBlack` hand-off so teleports happen off screen. Guns contract matched with the Guns thread (give Intimidate Pistol, equip on the aim step, `Intimidating` 2 s, `Fired` counts as the threat; built-in hold-aim fallback if GunService is missing). Pay is saved in `Story.Data.FirstMissionResult` before the outro, so it can't double. Checks: all 4 test suites pass, block balance clean on every file, installer rebuilt (70 scripts). **Not installed or play-tested** (Mac offline). Placeholders waiting on assets: animations (ids in `Config/Missions.Animations`), car door/engine/alarm/ambience sounds (`Theme.Mission.Sounds`), the mask accessory and a CrewCar model (drop into `ReplicatedStorage.MTL_Actors`), real meet spots + robbery points (Map thread / `tools/PlaceMissionPoints.lua`). **Piece 4 hooks:** `StoryService.onEnter("FindAPlace", ...)` (advance happens when the offer closes), the player is dropped `Missions.DropOffOffset` from `Locations.EndsFlat.Door`, `CutsceneService.play(player, "PowerOut", {anchor})` + `Cutscene.registerAction` / `Actors.registerProp` for the PC gag, `Rig` already has `Sit`, `Smash`, `Flop`, `Phone`.
- 2026-11-01 · Guns thread · **Piece 5 code written** (9 new files + adds to shared files). New: `Config/Guns.lua` (5 guns, ammo packs, safe zones, every tuning number, sound slots, keys), `Rules/GunRules.lua` (pure: path/safe-zone rules, falloff, TTK, RPM token bucket, spread/bloom/cone, recoil springs, reload, hitbox distance, lag-comp sample window, shop checks), `Services/GunService.lua` (give/take/lend, equip/holster with hip/back holster models, server-owned ammo + reloads, full shot validation with lag compensation, damage, hit/hurt confirms, intimidation signal, auto-holster watchdog, path guard + shift guard, MissionDone starter Pistol, Plug buy actions, Studio `debug`/`dummy`), `Services/GunModels.lua` (Alex's models from `ReplicatedStorage.MTL_Assets.Guns.<Model>` or clean part-built placeholders), `Controllers/GunController.lua` + `GunFX.lua` + `GunPose.lua`, `UI/Build/Gun.lua` (MTL_Gun, saved to StarterGui by the installer), `Apps/Plug.lua`, `tools/tests/test_gun_rules.py` (100+ checks incl. TTK balance and the fire-rate bucket under ±40 ms jitter). Shared adds: Net `GunState`/`GunAction`/`GunAim` (unreliable), schema `Inventory.Mags`, `Theme.Gun` + Plug app colour/icon, `Config/Phone.Apps` Plug (not default; GunService installs it on the Criminal path), boot lines + `_G.MTL.Guns`. Story thread agreed the robbery API: `give(p, "Pistol", {temporary=true, mode="Intimidate", ammo=6})` + `equip`, `Intimidating` at 2 s held on the clerk (tag `MTL_Intimidate`), `Fired` = alarm. Checks: all tests pass (gun, phone, job, story), block balance clean on every file, installer rebuilt (67 scripts). **Not installed or play-tested** (Mac offline). Still needed for top-tier feel, all assets not code: real gun sounds (the built-in placeholders are not gun sounds), hold/aim/reload animations (arms are posed in code until then), the Blender gun models in `MTL_Assets.Guns`. Not built yet: knocked-down/revive state (players just die and respawn), armour, a gun range for civilians.
- 2026-11-01 · Jobs thread · **Piece 2 code written** (8 new files + adds to shared files). New: `Config/Jobs.lua` (9 jobs, 14 tasks, stations, all tuning), `Rules/JobRules.lua`, `Services/JobService.lua`, `UI/Build/Job.lua` (MTL_Job, saved to StarterGui by the installer), `Controllers/JobController.lua` + helpers `JobFX.lua` (local props/FX) and `JobMinigames.lua` (hold/timing/sequence), `tools/PlaceJobStations.lua`, `tools/tests/test_job_rules.py` (38 checks incl. the balance sim: Level 5 at ~10.7 min). Jobs app filled in (YOUR JOB / 2x XP / FIND WORK). Shared adds: `Levels.Unlocks` 2-10, `Locations` tier 2/3 sites (placeholders), `Phone.Places` 5 sites, `Story.Contacts` Rico + Tasha, `Theme.Job`, boot lines + `_G.MTL.Jobs`. MonetizationService: ProcessReceipt (grant once, save, then granted), `buy{item}` phone action, StarterPack cash once. EconomyService: **StockMarket hook done without touching Studio**: outside changes to `leaderstats.Cash` become real cash changes. Story stages wired: FirstShift (auto clock-in), ChooseJob (advances on pick), CommuteToWork (advances on clock-in), blocked stages end shifts. Checks: block balance on all files clean, phone tests + job tests pass. **Not installed or play-tested** (Studio offline; also still blocked on `Vendor/ProfileStore.lua` missing from the shared folder). Story thread: use `JobService.workplace(player)` for the stage 12 waypoint and `JobService.clockOut(player, "story")` / `addShiftGuard` around the robbery.
- 2026-11-01 · Phone thread · **Piece 1 code written** (12 new files + small adds to shared files). New: `Config/Phone.lua`, `Rules/PhoneRules.lua`, `UI/UIKit.lua`, `UI/Build/Phone.lua`, `Services/PhoneService.lua`, `Services/PhoneStory.lua`, `Controllers/PhoneController.lua`, `Apps/{Messages,Calls,Jobs,Map,Settings}.lua`. Added to shared: `Theme.Phone`, schema `Phone.Unread` + `Apps.Calls`, boot lines in `Main.server.lua` / `Client.client.lua`, `_G.MTL.Phone`; `tools/make_installer.py` now saves every `UI/Build/*` screen (HUD + Phone) into StarterGui. Story wiring: stage 1 gets Mr. Patel's two texts; stage 3 rings the "Recruit" call ("I'm in" → GangMeet; "Not right now"/missed/hung up → stays in Recents with Call back, objective "Call back the unknown number"). Jobs app is a **shell** for the Jobs piece: reads `Config/Jobs.List` = `{ {id, title, role, pay (text), level, place (a Config/Phone.Places id)} }` if it exists, CHOOSE sends `chooseJob{job}` (register it with `PhoneService.onAction`). Checks: block balance on all 40 files clean, `tools/tests/test_phone_rules.py` 22/22 pass. **Not yet installed or play-tested in Studio.** Heads-up: `src/ServerScriptService/MTL/Vendor/` is empty in the shared folder (ProfileStore.lua missing), and `tools/tools/` is a stray duplicate.
- 2026-11-01 · Foundation thread · **Piece 0 code written** (28 files in `src/`): Net, Signal, Config (Economy, Levels, Story, Locations, Monetization), Rules (Level, Story), UI Theme/Motion/HUD builder, Format; server Data (ProfileStore, Mock in Studio), Monetization (pass checks + prompts; ProcessReceipt left for the Jobs piece), Economy (cash/XP/levels/leaderstats/boost countdown/analytics), Waypoints (server-checked arrival), Story (stage machine; Arrive and FirstShift wired), Notify, Analytics, RateLimiter; client ClientData, UIState, HUD, Wayfinding (marker, edge arrow, flowing ground chevrons on a pathfinding path). **Not yet installed or play-tested in Studio** (the Mac disconnected).
- 2026-11-01 · Plan thread · Master plan + research notes written. Studio place surveyed: map only, no gameplay code yet (just `StockMarket`, `VBHouseInteriors`, `StockTradingUI`, `VBTicker`). Next: Piece 0 Foundation.
