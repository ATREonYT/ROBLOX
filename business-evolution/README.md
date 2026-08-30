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

## Setup (Windows, ~5 minutes, no coding)

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
