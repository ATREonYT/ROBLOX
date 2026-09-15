# +1 Business Evolution

Climb the corporate tower. Start as an Unpaid Intern in a basement mailroom,
click your way to Chairman, out-work your rivals, and Restructure your way to
the Orbital HQ.

Built to the spec in `CLAUDE.md` (game design brief) and `DESIGN-MAP.md`
(map plan, modelled on the verified layout of the genre's current hit).

## What's in the box

- **Full map, built by code** — all six floors (Mailroom → Cubicle Farm →
  Open Plan → Executive → Penthouse → Orbital HQ), each with a hub, a grind
  wing of rival packs, payday pads, and a boss office. The map assembles
  itself when the server starts: press Play and it's there.
- **Server-authoritative economy** — clicking, training zones, idle income,
  gear shop, Restructures with Severance perk choices, intern hiring with
  published odds. Remotes carry intent only; the server owns every number.
- **Persistence** — ProfileStore with session locking; progress survives
  rejoins and server hops.
- **Visible rank** — your outfit, props and aura change with your job title,
  for everyone to see. Employee of the Month board updates live.
- **The juice** — number popups, squash-and-stretch buttons, promotion
  cinematic, comedic rival firings (swivel-chair exit), interns trailing
  behind you.

## Fastest way to look at it: open the place file

Ask Claude for a fresh `BusinessEvolution.rbxlx`, or build one yourself with
Rojo (see below). Then:

1. **Double-click the `.rbxlx`** — it opens in Roblox Studio as its own place.
2. Press **Play**.

That's it. No Rojo server, no plugin, no syncing. The whole world builds itself
when the server starts, so the place file contains only code — you'll see an
empty grey void in edit mode, and the full six-floor tower once you hit Play.

Two Studio settings worth setting once (File → Game Settings):
- **Avatar → Avatar Type → R15** — required for the better DevEx rate.
- **Security → Enable Studio Access to API Services → ON** — lets progress save
  between playtests. Without it the game still runs, it just won't remember.

To rebuild the place file after code changes:

```
rojo.exe build default.project.json -o BusinessEvolution.rbxlx
```

⚠️ Rebuilding **overwrites** the file — anything you hand-built in Studio and
saved into that place is lost. Once you start building by hand, switch to the
live-sync workflow below, which leaves your own work alone.

## Live sync (for ongoing work — leaves your hand-built stuff alone)

You've done this before with the other games in this repo — same drill:

1. **Pull this repo** (GitHub Desktop → Pull origin).
2. **Copy `rojo.exe` into this `business-evolution/` folder** (or reuse the
   one from another game folder).
3. Open the folder, click the address bar, type `cmd`, Enter, then run:
   ```
   rojo.exe serve
   ```
4. Open your place in Roblox Studio (an **empty baseplate place is perfect** —
   delete the baseplate itself; the game builds its own world). Plugins tab →
   Rojo → **Connect**.
5. **Enable Studio API access** so saving works in playtests:
   Game Settings → Security → "Enable Studio Access to API Services" → ON.
   (Without it the game still runs; progress just doesn't save in Studio.)
6. Press **Play**. You should spawn in the Mailroom, click anywhere for +1,
   and see the whole loop working.

> If Studio says the game is for R6 avatars, switch it: Game Settings →
> Avatar → Avatar Type → **R15** (also required for the better DevEx rate).

## Publishing checklist

- Game Settings → Avatar → **R15**.
- Monetization: create the gamepasses listed in
  `src/ReplicatedStorage/Shared/Config/Monetization.luau` on the Creator
  Dashboard, then paste each pass's numeric id into that file (each `Id = 0`).
  Everything works without them; passes just won't show until wired.
- Sounds: the game ships with built-in Roblox sounds so it works everywhere.
  Upgrading them is one-line swaps in
  `src/ReplicatedStorage/Shared/Config/Sounds.luau`.

## Where the knobs live

Every balance number is data, not code — edit and Rojo syncs live:

| File (under `src/ReplicatedStorage/Shared/Config/`) | Controls |
|---|---|
| `Balance.luau` | click gain, crits, restructure cost/bonus, caps |
| `Ranks.luau` | the 12 job titles + requirements |
| `Floors.luau` | floor gates + positions |
| `Gear.luau` | the three ladders + costs |
| `Rivals.luau` | every rival's workload + wins per floor |
| `Interns.luau` | the intern roster + hire odds |
| `Severance.luau` | the perk cards |
| `Palettes.luau` | each floor's 5-colour palette |

## For developers

Offline checks (no Studio needed) — from this folder:

```
luau tests/run.luau        # config sanity + pacing simulation
```

Architecture: one server entry (`Main.server.luau`), one client entry
(`Main.client.luau`), everything else ModuleScripts. Interface contracts in
`CONTRACTS.md`. Player data shape in `Shared/Types.luau`; all mutation flows
through `DataService.update`.

## What to look at first in Studio

Press Play and check these in order — they're the things worth judging:

1. **The Mailroom** — you spawn here. One flickering fluorescent, cardboard
   everywhere, a photocopier that's been out of toner since '19. Click
   anywhere for +1.
2. **Stand at a desk** in the west training area — Productivity ticks up on
   its own. Better desks (tier 2/3) need higher ranks.
3. **Walk east into the Sorting Wing** — rows of rivals at desks. Click one to
   out-work it; when its workload hits zero it slumps into a swivel chair and
   rolls off down the aisle.
4. **Step on a gold PAYDAY pad** after clearing a segment — banks a bonus and
   sends you back to the hub.
5. **Rank up** (100 Productivity gets you to Mail Clerk) — the promotion
   cinematic plays and your outfit changes. Other players see it too.
6. **The elevator** (north wall) — the floor list with lock reasons. Floors 12+
   need Restructures, so they'll show locked on a fresh save.

To see the later floors without grinding, open the Command Bar in Studio and
give yourself progress, e.g.:

```lua
-- Server-side (Command Bar, while playtesting):
local DS = require(game.ServerScriptService.Server.Data.DataService)
DS.update(game.Players:GetPlayers()[1], function(d) d.Restructures = 30 end)
```

Then ride the elevator up to the Penthouse and Orbital HQ.

## Offline checks

Everything below runs **without Roblox Studio** — useful before a push, or if
you ever want to change a balance number and know instantly whether you broke
something. You need the [Luau CLI](https://github.com/luau-lang/luau/releases)
and Python 3. From this folder:

```
python3 tools/verify.py
```

That runs 196 checks in three suites:

| Suite | What it proves |
|---|---|
| **config + pacing** (24) | Intern odds sum to exactly 100, the rank curve only goes up, gear costs follow `1.12^owned`, floor gates work, currency formatting is right, saved data stays JSON-safe — plus a minute-by-minute simulation of a first session that asserts the pacing targets from the brief |
| **map geometry** (150) | Actually *builds all six floors* against a mock Roblox API: no runtime errors, every part anchored, no NaN positions, correct rival packs, training zones invisible and intangible, payday pads numbered 1–5, prompt and board parts present and parented, nothing escaping its floor's bounds, part counts within a mobile budget |
| **multiplier stack** (22) | Executes the real income math: rank/gear/restructure multipliers, the Restructure bonus staying *additive* rather than compounding, Wins perks, linear rebirth cost — and the brief's key rule, that a Robux multiplier is exactly 2× for a brand-new and a maxed account alike |

The map suite is the interesting one: `tools/roblox_mock.luau` is a headless
stand-in for the slice of the Roblox API the map builders use (with real CFrame
matrix maths), so the floors can be built and inspected outside Studio. It is
the closest thing to pressing Play that works in CI.
