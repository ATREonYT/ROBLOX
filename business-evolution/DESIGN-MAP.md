# Map Design — +1 Business Evolution

This is the buildable map spec. It merges the **verified layout of `+1 Superhero
Evolution`** (researched Aug 2026: compact hub + linear segmented grind corridor
per world, physical cash-out pads, training props in the hub, left-side UI stack)
with the **corporate tower theme and floor list from CLAUDE.md §3/§11**.

## Verified reference skeleton (what the real game does)

- Each world = a **compact HUB** (spawn, click/auto-training area, gacha
  station, egg/pet stands, rebirth station, leaderboard) + a **"lengthy hallway
  fragmented into Levels"** — a linear corridor of enemy packs.
- Clicking is **click-anywhere** (no giant button); the hub also has physical
  **auto-training zones** — stand there and the stat ticks up on its own.
- After clearing each corridor segment there is a **yellow cash-out pad**:
  step on it → bank Wins → teleport back to the hub. Or keep pushing deeper.
- **World travel is a teleport button/panel**, gated by progression.
- One **recurring boss per world on a countdown**; the Wins faucet.
- UI: left-edge vertical button stack (Shop, Pets, Rebirth…), stat meter low on
  screen, top-right Roblox leaderstats, odds published on gacha stations.

## Our translation, per floor of the tower

Every floor is **HUB (lobby) + GRIND WING (corridor) + BOSS OFFICE**, rebuilt
from the same kit, retinted with the floor's locked palette, with per-floor
signature set-pieces. Floors are stacked vertically at the origins in
`Config/Floors.luau`; travel is by **elevator** (physical doors + panel in each
hub; also the HUD Floors button).

### HUB — ~150×150 studs, one big readable room

```
        N:  [ELEVATOR bank]  [Employee of the Month]  [Wins leaderboard]
  W: TRAINING AREA                                        E: [Gear Shop kiosk]
     rows of workstations                                    [Coffee Machine]
     (3 tiers of desks)          [SPAWN]                     [HR / Restructure desk]
        S-E: >>> double doors → GRIND WING >>>
```

- **Spawn** dead centre, facing the room so every station is visible in the
  first second (genre rule: readable to a 10-year-old in 10 seconds).
- **Training area** (west): rows of desks with chairs + glowing monitors.
  Standing in a desk's zone auto-earns click-equivalent Productivity:
  tier 1 desk = 1×/sec (open to all), tier 2 standing desk = 2×/sec,
  tier 3 corner battlestation = 4×/sec (progressively rank-gated).
  Floating "+N/s" billboard over each tier row. Clicking anywhere still works —
  the two stack, exactly like the reference.
- **Gear Shop kiosk** (east): counter + shelf display showing the three ladders
  (keyboard / chair / coffee props on the shelf). ProximityPrompt opens ShopUi.
- **Coffee Machine** (east): comically oversized espresso machine (the intern
  gacha). Odds board mounted beside it (published %, §7). Prompt opens InternUi.
- **HR desk / Restructure** (east): red-stamp desk with "RESTRUCTURING"
  paperwork tray. Prompt opens RestructureUi.
- **Employee of the Month board** (north wall): server's top 3 by rank, live.
- **Wins leaderboard** (north wall): classic all-time board.
- **Elevator bank** (north): 2 door frames + glowing call panel → ElevatorUi.
- Palette decor: plants, posters, water cooler, ceiling light panels, windows
  where the floor's altitude makes sense.

### GRIND WING — the dungeon corridor

- One straight corridor, ~48 wide × ~330 long, in **5 segments** + boss office.
- Segment k holds a **pack of rivals of ladder type k** (2–3 copies of the same
  def for segments 1–2, then 2, then 1–2) standing at sabotaged desks facing
  the aisle. Rival types per floor come from `Config/Rivals.luau`
  (Temp → New Hire → Colleague → Rival Analyst → Overachiever → Teacher's Pet).
- Between segments: an **archway gate** with floating text showing the next
  pack's Workload ("Next: Colleague — 350 Workload") so under-powered players
  self-select back to training, never a hard block (§5: never block, never kill).
- After each segment: a **gold PAYDAY pad** (our yellow button) — stepping on
  it pays a **streak bonus** (+25% of the Wins earned in the wing this run,
  scaling with depth) and teleports you back to the hub spawn. Wins from kills
  are still awarded instantly per §5; the pad is pure upside, no loss on exit.
- **BOSS OFFICE** at the end: oversized double doors, giant desk, the floor's
  Manager at 2.5× scale with name + dialogue billboard and a chunky health bar.
  Defeat → floor-boss flag (gates the next floor's elevator entry), big payout,
  confetti of paperwork.

### Per-floor identity (palette in `Config/Palettes.luau`)

| Floor | Hub signature set-pieces | Wing name |
|---|---|---|
| **B1 Mailroom** | Basement: low ceiling, exposed pipes, ONE flickering fluorescent tube (the only moody floor), cardboard stacks, groaning photocopier, dying spider plant, letter conveyor | SORTING WING — mail carts, package shelves |
| **3 Cubicle Farm** | Grey partition maze framing the hub, motivational posters ("SYNERGY", "The grind never stops"), sickly green carpet, humming vending machine | AUDIT WING — filing cabinets to the ceiling |
| **12 Open Plan** | Exposed brick, wood floor, plants *everywhere*, beanbags, ping-pong table (nobody plays), neon "HUSTLE" sign, kombucha tap | GROWTH WING — whiteboards with graphs going up |
| **40 Executive** | Dark marble, glass-walled offices, gold trim, one enormous abstract painting, leather seating | STRATEGY WING — war-room tables, world maps |
| **88 Penthouse** | White marble + gold, floor-to-ceiling glass, infinity pool on the terrace, helipad visible outside, open sky | BOARD WING — a boardroom table 40 studs long |
| **??? Orbital HQ** | Chrome + cyan neon, starfield dome, Earth visible below through glass floor panels, floating holo-displays | ORBITAL WING — zero-g desks on light beams |

### Kit (one module, everything parameterized by palette)

Reused across all six floors, recoloured (§11 "reuse aggressively"):
`desk, officeChair, monitor, keyboardProp, mug, paperStack, filingCabinet,
partition, pottedPlant, poster, waterCooler, photocopier, vendingMachine,
coffeeMachineBig, ceilingPanelLight, fluorescentTube, windowWall, doubleDoor,
elevatorDoors, elevatorPanel, rug, bookshelf, whiteboard, beanbag,
pingpongTable, pillar, trimStrip, gateArch, paydayPad, spawnPad, boardFrame
(EOTM + leaderboard), hrDesk, shopKiosk, bossDesk, swivelChair, cardboardStack,
mailCart, conveyor, neonSign`.

Style rules (§11): chunky proportions, `SmoothPlastic`/`Neon` only, oversized
props (mugs the size of heads), flat saturated fills, no sharp edge on hero
props (cap-inset bevel trick), `CastShadow = false` on small props,
everything `Anchored`, collision only on walls/floors/large furniture.

### Technical contract (what the code needs from the map)

Each floor builder is `Server/World/Floors/<FloorId>.luau` exporting
`build(parent: Folder, origin: Vector3, palette) -> Manifest`:

```lua
type Manifest = {
	Spawn: CFrame,
	RivalSpots: { { DefIndex: number, Cf: CFrame } }, -- boss = last def index
	TrainingZones: { { Rate: number, Zone: BasePart } },
	PaydayPads: { { Segment: number, Pad: BasePart } },
	Prompts: { Shop: BasePart, Coffee: BasePart, Hr: BasePart, Elevator: BasePart },
	Boards: { Eotm: BasePart, Wins: BasePart },
}
```

`MapService` builds all floors at startup into `workspace.BusinessEvolutionMap`,
keeps the manifests, and exposes lookups. Client-side flair (flicker, monitor
glow, pool shimmer, ticker signs) is driven by `CollectionService` tags the kit
applies: `FlickerLight`, `GlowScreen`, `WaterShimmer`, `TickerSign`, `IdleBob`.

Part budget: ≤ ~2,800 parts per floor, ≤ ~14k total (mobile-first).
Lighting: bright & even (ClockTime 14, ShadowMap); the Mailroom is enclosed so
its gloom comes from geometry + its one flickering local light, not Lighting.
