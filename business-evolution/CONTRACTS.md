# Code Contracts — +1 Business Evolution

Binding interface spec for every module. If a module needs something not
listed here, it computes it itself from `Config/` — it does NOT invent new
cross-module APIs. Style: `--!strict` everywhere; every connection into a
`Trove`; comments explain *why*; no `Enum.EasingStyle.Linear` on anything
visible; server logic never in ReplicatedStorage (§13).

## Existing modules (already written — require, don't reimplement)

### Vendored packages
- `ReplicatedStorage.Packages.Trove`, `.Signal`, `.t` (sleitnick/osyris APIs)
- `ServerScriptService.Packages.ProfileStore` (loleris v1: `.New(name, template)`,
  `store:StartSessionAsync(key, {Cancel=fn})`, `profile:Reconcile()/:EndSession()/:IsActive()`,
  `.OnSessionEnd`, `.Data`)

### `ReplicatedStorage.Shared.Config.*` (pure data + pure helpers)
- `Balance` — all tunables. Fields used below exist exactly as named
  (BaseClickGain, MaxClicksPerSecond, BaseClickCooldown, CritChance,
  BigCritChance, CritMultiplier, BigCritMultiplier, IdleTickSeconds,
  RestructureBaseCost, RestructureCostPerOwned, RestructureBonusPerOwned,
  RestructureMinRank, GearCostGrowth, RivalTickHz, RivalReachStuds,
  RivalRespawnSeconds, BossRespawnSeconds, TrainingTierRates {1,2,4},
  TrainingTierMinRank {1,5,8}, PaydayBonusFraction, BaseInternSlots,
  CoffeeMachineCost, ConsultantKeepFraction, MaxNumber, StateSyncHz)
- `Ranks` — `.List {Name, Requirement, Band, Blurb}`, `.multiplierFor(i)`,
  `.rankForProductivity(p)`, `.nextRequirement(i)`
- `Floors` — `.List {Id, DisplayName, FloorLabel, Gate, Origin {x,y,z}, Tagline}`,
  `.get(id)`, `.canEnter(floorId, rank, restructures, bossesDefeated) -> (bool, reason?)`
- `Gear` — `.Ladders`, `.getLadder(id)`, `.nextTierCost(ladderId, owned) -> number?`,
  `.keyboardMultiplier(owned)`, `.chairIdleRate(owned)`, `.coffeeCooldownMultiplier(owned)`
- `Rivals` — `.ByFloor[floorId] -> { {Title, Workload, Wins, IsBoss?, BossName?, BossLine?} }`
  (index 7 = boss), `.rivalId(floorId, defIndex, copy)`, `.parse(id) -> (floorId?, defIndex?, copy?)`,
  `.get(floorId, defIndex)`
- `Interns` — `.RarityOdds` (% sum 100), `.RarityOrder`, `.RarityColors`,
  `.Roster {Id, Name, Rarity, PerSecond, Special?, Blurb}`, `.get(id)`,
  `.ofRarity(r)`, `.hasSpecialEquipped(owned, equippedUids, special)`
- `Severance` — `.List {Id, Name, Description, Icon, Repeatable}`, `.get(id)`,
  `.offerablePool(ownedIds)`, `.effects(ownedIds)`
- `Monetization` — `.Passes {Key, Id, Name, Price, Description}`, `.Trails`,
  `.DelegateClicksPerSecond`, `.passByKey(key)`
- `Palettes` — `.ByFloor`, `.get(floorId) -> {Ground, Wall, Primary, Accent, Dark}`
  ({r,g,b} 0-255 arrays), `.color(rgb) -> Color3`
- `Sounds` — map of key → {SoundId, Volume, PlaybackSpeed?}. Keys: Click, Crit,
  BigCrit, RankUp, RivalDefeated, BossDefeated, Purchase, Error, Restructure,
  InternHired, Teleport, UiOpen, Typing
- `Shared.Util.Format` — `.abbreviate(n)`, `.commas(n)`, `.duration(s)` (ALL
  currency display goes through this)
- `Shared.Util.Sanitize` — `.stat(v, fallback?)`, `.validateSavable(v) -> (bool, why?)`

### `ServerScriptService.Server.Net.Net`
- `Net.bind(remoteName, ratePerSecond, burst, tValidator, handler(player, ...))`
- `Net.sendTo(player, remoteName, ...)`, `Net.sendAll(remoteName, ...)`
- Already handles token bucket + silent drops. One bind per remote TOTAL.

### `ServerScriptService.Server.Data.DataService`
- `.get(player) -> ProfileData?` (nil until loaded)
- `.update(player, fn(data))` — THE only mutation path; sanitizes + queues sync
- `.pushState(player)` — force immediate ClientState push
- `.passesFor(player) -> Passes`, `.setPassProvider(fn)` (MonetizationService calls in Start)
- `.PlayerLoaded: Signal (player, data)`, `.PlayerUnloading: Signal (player)`
- `.Template` — ProfileData shape (see Shared/Types.luau)

### `ServerScriptService.Server.Economy.Stack` (pure math)
- `.clickIncome(data, passes)`, `.idlePerSecond(data, passes)`,
  `.outworkDamage(productivity, data, passes)`, `.winsAward(baseWins, data, passes)`,
  `.restructureCost(restructures)`, `.internSlots(data, passes)`, `.clickCooldown(data)`

## Remotes (`ReplicatedStorage.Remotes.*`) — payloads are law

Client → server (bind with rates shown):
| Remote | Args | Rate/burst | Bound by |
|---|---|---|---|
| RequestClick | () | 22/s, burst 25 | ProductivityService |
| RequestOutwork | (rivalId: string) | 22/s, burst 25 | RivalService |
| RequestPurchaseGear | (ladderId: string) | 3/s, 5 | ShopService |
| RequestRestructure | () | 1/s, 2 | RestructureService |
| RequestSeverance | (perkId: string) | 1/s, 2 | RestructureService |
| RequestHireIntern | () | 2/s, 3 | InternService |
| RequestEquipIntern | (uid: string, equip: boolean) | 5/s, 8 | InternService |
| RequestTeleport | (floorId: string) | 1/s, 2 | FloorService |

Server → client:
- `StateChanged (state: ClientState)` — full snapshot; fields in Types.luau plus
  `ClickCooldown: number`. Client caches it in StateController.
- `ClickResult ({ Amount: number, Crit: "none"|"crit"|"big", Kind: "click"|"train"|"outwork", RivalId: string? })`
  — fired to the earning player only; drives popups + sounds.
- `RivalState (msg)` — `{ Full: { { Id, DefIndex, Cf: {number} -- 12 CFrame components, Remaining, RespawnAt } } }`
  on join/floor build, or `{ Delta: { { Id, Remaining, RespawnAt } } }` at 5 Hz
  when dirty. Workload maxes come from Config.
- `Fx ({ Kind: FxKind, UserId: number?, RivalId: string?, Position: {number}?, Rank: number?, Wins: number? })`
  — world-visible moments: "RankUp" (UserId, Rank), "RivalDefeated"/"BossDefeated"
  (RivalId, UserId, Wins), "Restructure" (UserId), "InternHired" (UserId), "Payday" (UserId, Wins).
- `InternRollResult ({ InternId: string, Uid: string, Rarity: string })` — to the roller.

## Server services (each: `{ Init: (self)->(), Start: (self)->() }`, required by Main)

- **ProductivityService** (`Server/Economy/`): binds RequestClick (server-rolls
  crits; income = Stack.clickIncome × crit; update data.Productivity +
  TotalClicks; send ClickResult). Idle loop every IdleTickSeconds: chair+intern
  income via Stack.idlePerSecond; training zones — players standing inside a
  manifest TrainingZone (AABB check on zone part) with rank ≥ tier gate earn
  Rate × Stack.clickIncome per second (Kind="train" ClickResult, batched 1/s).
  Delegate pass = 5 auto-clicks/s worth, same loop. Never reads leaderstats.
- **RankService** (`Server/Progression/`): on every Productivity change
  (subscribe via its own loop or DataService.PlayerLoaded + polling in the idle
  hook — implementation's choice, but detection ≤ 1s), recompute
  Ranks.rankForProductivity; on rise: set data.Rank, BestRank, fire Fx RankUp,
  tell AppearanceService. Restructure resets are done by RestructureService.
- **AppearanceService** (`Server/Progression/`): server-driven look per rank
  Band (1-5): body/suit colors on character parts, procedural props (Band 1:
  lanyard + carried cardboard box; 2: clipboard + coffee mug; 3: briefcase +
  subtle sparkle ParticleEmitter; 4: floating tablet part + gold aura emitter;
  5: golden suit colors + orbiting ticker ribbon parts tagged `OrbitRibbon`).
  Applies on PlayerLoaded, CharacterAdded, and rank change. Exposes
  `.applyFor(player)` for RankService/RestructureService. No Humanoid changes,
  R15-safe, all props welded, CanCollide false, CanQuery false.
- **RivalService** (`Server/Rivals/`): owns rival live state from MapService
  manifests (RivalSpots). No Humanoids, no server models — pure state +
  RivalState replication at RivalTickHz (Full on PlayerAdded, Delta on change).
  Binds RequestOutwork: validate rival alive + character within RivalReachStuds
  of spot; damage = Stack.outworkDamage; on defeat: Wins via Stack.winsAward
  (+wing-run tracking for Payday), Fx RivalDefeated/BossDefeated, ClickResult
  (Kind="outwork"), BossesDefeated update for bosses, respawn timers
  (RivalRespawnSeconds/BossRespawnSeconds), InsiderKnowledge head start on
  spawn. Payday pads: Touched on manifest pads → bank
  PaydayBonusFraction × winsThisRun × segment, Fx Payday, teleport to hub spawn,
  reset run tracker. Run tracker also resets on floor teleport/leave.
- **FloorService** (`Server/Progression/`): binds RequestTeleport; validate via
  Floors.canEnter + skip passes (ExecutiveSkip/PenthouseSkip bypass gates for
  those floors only); PivotTo manifest Spawn; RespawnLocation/fall-catch: if a
  character falls below (floor Origin Y - 120), teleport back to that floor's
  spawn. Tracks each player's current floor; exposes `.floorOf(player)`.
- **ShopService** (`Server/Economy/`): binds RequestPurchaseGear; cost from
  Gear.nextTierCost; pay Wins, increment ladder tier, Fx Purchase, push state.
- **RestructureService** (`Server/Economy/`): binds RequestRestructure (rank ≥
  RestructureMinRank AND Productivity ≥ Stack.restructureCost → consume:
  Productivity → 0 (× ConsultantKeepFraction kept if Consultant equipped),
  Rank → 1 (or 2 with Nepotism), Restructures += 1, offer 3 severance cards:
  sample distinct ids from Severance.offerablePool into data.PendingSeverance,
  Fx Restructure). Binds RequestSeverance (perkId must be in PendingSeverance;
  append to Severance, clear pending). AppearanceService.applyFor after reset.
- **InternService** (`Server/Economy/`): binds RequestHireIntern (cost
  Balance.CoffeeMachineCost Wins; server-side rarity roll from RarityOdds then
  uniform pick within rarity; uid = HttpService GUID; append to Interns;
  auto-equip if slots free; InternRollResult + Fx InternHired). Binds
  RequestEquipIntern (validate uid owned; enforce Stack.internSlots cap).
- **MonetizationService** (`Server/Economy/`): pass ownership cache
  (UserOwnsGamePassAsync, pcall, skip Id==0), PromptGamePassPurchaseFinished →
  refresh + one-time StarterPack grant (500 Wins + Keyboard tier 1 if tier 0,
  guarded by "grant_StarterPack" in PurchaseLog). Calls
  DataService.setPassProvider in Start. Buyout implies DoubleWins +
  DoubleProductivity + InternSlots + Delegate. Trail passes: attach trail to
  character (color from config) for owners on CharacterAdded.
- **LeaderboardService** (`Server/Boards/`): every 30s update SurfaceGuis on
  manifest Boards: Eotm = top 3 in-server by (Rank, then Productivity) with
  name + rank title; Wins = all-time OrderedDataStore top 10 (pcall everything;
  write player Wins on leave + every 60s; skip cleanly when DataStores
  unavailable). Server-built SurfaceGui text is fine here (low rate).
- **MapService** (`Server/World/`): on Init builds `workspace.BusinessEvolutionMap`
  (a Folder) — for each Floors.List entry requires
  `Server/World/Floors/<Id>.luau` and calls `.build(floorFolder, origin, palette)`;
  stores manifests. Sets Lighting (ClockTime 14, ShadowMap, bright ambient,
  slight saturation boost via ColorCorrection). Exposes `.manifestFor(floorId)`,
  `.allManifests()`. Spawn handling: a SpawnLocation at Mailroom spawn (only one).

## Map modules

### `Server/World/Kit.luau` — the shared prop kit (server-only)
Every function takes `(parent: Instance, cf: CFrame, palette: Palettes.Palette)`
first (plus documented extras), builds Anchored parts, returns its root
Model/Part. Exact exports (all must exist; sizes are footprints in studs):

`part(parent, cf, size, color, material?) -> Part` (base helper: Anchored,
SmoothPlastic default, CastShadow false when size.Magnitude < 6, TopSurface/
BottomSurface Smooth) · `bevelBlock(parent, cf, size, color)` (block + inset
top cap for the chunky look) · `desk(4×2×2)` · `officeChair(2×3×2, seat color
param)` · `monitor(1.6×1.2 glowing Neon screen, tag GlowScreen)` ·
`keyboardProp` · `mug(oversized, 0.9 tall)` · `paperStack` · `filingCabinet
(2×4×2)` · `partition(w, h felt wall)` · `pottedPlant(dying: boolean?)` ·
`poster(w, h, text, onPart?) -> creates SurfaceGui text poster` ·
`waterCooler` · `photocopier(3×3.5×2.5)` · `vendingMachine(3×6×2)` ·
`coffeeMachineBig(6×8×4 hero prop, tag GlowScreen on its display)` ·
`ceilingLight(4×0.3×4 Neon panel)` · `fluorescentTube(6 long, tag FlickerLight
when flicker param true)` · `windowWall(w, h, transparent glass + frame)` ·
`doubleDoor(8×10)` · `elevatorDoors(8×10 metallic + gold seam)` ·
`elevatorPanel(1×2 glowing)` · `rug(w, l)` · `bookshelf(4×7×1.5)` ·
`whiteboard(6×4 on legs)` · `beanbag(3Ø squashed ball)` · `pingpongTable
(9×3×5 + net)` · `pillar(2Ø × h)` · `trimStrip(length, gold Neon strip)` ·
`gateArch(width 14, h 12, label text floating)` · `paydayPad(6Ø gold Neon
cylinder, pulsing tag IdleBob)` · `spawnPad(8Ø)` · `boardFrame(10×6 wall board,
title) -> (Model, SurfaceGui contentFrame)` · `hrDesk` · `shopKiosk(8×4×3
counter + shelves + sign)` · `bossDesk(10×3×5)` · `swivelChair` ·
`cardboardStack(n boxes)` · `mailCart` · `conveyor(length, with letter parts)` ·
`neonSign(text, color)` · `room(parent, origin, w, h, l, palette, opts
{windows: boolean?, ceiling: boolean?}) -> Folder` (floor slab + walls +
ceiling with palette; the workhorse).
All text via one internal `textLabelOn(part, face, text, color)` using
`Enum.Font.FredokaOne` for display text, `Gotham` for body.

### `Server/World/Floors/<FloorId>.luau` (six files, one per floor)
`return { build = function(parent: Folder, origin: Vector3, palette): Manifest }`

```lua
type Manifest = {
	Spawn: CFrame,
	RivalSpots: { { DefIndex: number, Cf: CFrame } }, -- 2-3 copies of defs 1-2, then 1-2 each, boss (def 7) once
	TrainingZones: { { Rate: number, MinRank: number, Zone: BasePart } }, -- invisible, CanCollide false
	PaydayPads: { { Segment: number, Pad: BasePart } },
	Prompts: { Shop: BasePart, Coffee: BasePart, Hr: BasePart, Elevator: BasePart },
	Boards: { Eotm: BasePart, Wins: BasePart },
}
```
MapService attaches ProximityPrompts to the four Prompt parts (names:
`OpenShop`, `OpenCoffee`, `OpenHr`, `OpenElevator`; ActionText matches).
Hub + wing layout per DESIGN-MAP.md. Rivals face the corridor aisle.

## Client (each controller `{ Init/Start }`, required by Main.client)

- **StateController**: caches latest ClientState; `.Get() -> ClientState?`;
  `.Changed: Signal (state)`. Everything else reads state from here only.
- **SoundController**: `.play(key)`, `.playAt(key, position)` from Config.Sounds.
- **ClickController**: click/tap-anywhere → RequestClick, respecting
  state.ClickCooldown locally (server bucket is the real cap); when the click
  hits a rival model part (raycast), fire RequestOutwork(rivalId) instead.
  Mobile: TouchTap. Ignores clicks over GUI (UserInputService gameProcessed).
- **PopupController**: listens ClickResult → floating "+N 💼" TextLabels at
  cursor/rival with ±20 px jitter; 0.15s in (Linear ok for FADES only) → hold
  0.25 → 0.4 out (Quart); crit = orange 255,200,0, big = larger + brighter.
  Also "+N 🏆" wins popups on Fx RivalDefeated for the local player.
- **RivalRenderer**: builds one blocky suit-guy model per rival from RivalState
  Full (client-side only!), name/workload billboard with chunky bar, procedural
  idle typing bob; interpolates Remaining; defeat → comedic tween: ragdoll-ish
  spin into a swivel chair sliding away + paper burst (ParticleEmitter), fade,
  respawn countdown billboard, pop back with Elastic. Boss: 2.5× scale, name +
  dialogue billboard, boss bar. Pools models.
- **InternRenderer**: renders EVERY player's equipped interns client-side from
  their StateChanged... interns of OTHER players aren't in your state — so:
  renders from character attributes: server (InternService) sets a character
  attribute `EquippedInternIds` = comma-joined intern ids on any change;
  renderer watches all characters' attribute. Blocky mini-figures with rarity
  tint, sine bob + trailing follow (lerp on RenderStepped, capped 6 per player).
- **CameraFx**: `.shake(intensity)`, `.zoomPunch()`; subtle shake on big crit +
  boss defeat.
- **WorldFxController** (`Controllers/`): CollectionService tag animations:
  FlickerLight (random flicker), GlowScreen (hue drift), IdleBob (sine
  pos+rot), OrbitRibbon (orbit around character), WaterShimmer, TickerSign
  (scrolling text). Cheap: one RenderStepped loop, distance-culled (>150 studs
  skipped).
- **Ui/Theme**: shared UI factory: `.panel()`, `.button()` (squash 0.92/0.06s →
  Back 1.0/0.18s + hover grow + click sound), `.title()`, `.currencyLabel()`,
  colors (bg #2B2F3A dark panels, gold #FFC428 accents, white text,
  FredokaOne display / Gotham body), `.tween` helpers with the easing rules,
  `.open(frame)/.close(frame)` (Back in, Quad out). All UIs use it.
- **Ui/Hud**: top-centre big Productivity counter (animated count-up) + rank
  progress bar to NextRankAt + rank title; Wins counter top-right-ish; LEFT
  vertical button stack (genre convention): Shop, Interns, Floors, Restructure
  (pulses when affordable); bottom "+N per click · +N/s" readout. Buttons open
  the respective UIs. Also listens PromptTriggered (ProximityPromptService,
  prompt names above) to open the same UIs.
- **Ui/ShopUi**: three ladder columns (next tier card each: name, effect,
  cost, affordable state) + owned tier pips + gamepass row (PromptGamePassPurchase
  client-side, hide Id==0 passes). Fires RequestPurchaseGear.
- **Ui/InternUi**: coffee machine panel: HIRE button (cost), published odds
  table (from Config.Interns.RarityOdds — always visible, §7), roll reveal
  animation on InternRollResult (cup shakes → intern pops out with rarity
  color burst), inventory grid with equip toggles (RequestEquipIntern), slots
  "3/3" from state.InternSlots.
- **Ui/RestructureUi**: shows cost vs Productivity bar, keeps/resets lists,
  big red "RESTRUCTURE" button → confirm; after Fx Restructure for self, the
  three PendingSeverance cards slide in (pick one → RequestSeverance).
  Auto-opens when PendingSeverance non-empty (rejoin safety).
- **Ui/ElevatorUi**: floor list with FloorLabel + DisplayName + Tagline +
  lock reason via Floors.canEnter(clientState...); click unlocked →
  RequestTeleport + door-close transition overlay.
- **Ui/RankUpFx**: on Fx RankUp for self: freeze input 1.2s
  (ContextActionService sink), camera dolly-in, white flash, screen-wide
  "PROMOTED — <Rank Name>" with Elastic scale-in, confetti burst, fanfare,
  release. For others: burst + floating "<Name> was promoted!" toast.

## Non-negotiables checklist for every agent
- `--!strict` first line; passes `luau-lsp analyze` with zero errors on YOUR files.
- Connections in a Trove; no `wait()` (use task.wait); no Humanoids on NPCs;
  no free-model asset ids; sounds only via Config.Sounds keys.
- Currency displays only via Format.abbreviate.
- Server never trusts client args beyond the bound validators.
- UI: no Linear easing except pure fades; every button uses Theme.button.
