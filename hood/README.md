# Hood (From the Block)

Your own game, copied out of Roblox Studio so Claude can read and work on it.
Everything here is the **scripts** — the map itself (`Workspace.TheBlock`,
the courtyard, buildings, train, etc.) lives in your Studio place.

## What the game does right now

You spawn in **The Block** — a walled hood courtyard with rowhouses, a
court, a food truck and string lights — and earn **Power** every second.

- **The Drip Shop** holds all **15 looks**, from **Corner Kid** (free,
  +1/sec) up to **Kingpin** (30,000 Power, +110/sec), on three compact
  rows. Walk up to one and press **E** to wear it once you have enough
  Power. Your look decides how much Power you earn.
- **The Block Boxing Club** has **8 bags**, and the **Champ Ring** sits in
  the middle of the courtyard. Stand on a mat to multiply your Power:

  | Station | Power needed | Multiplier |
  |---|---|---|
  | Tire Bag | free | x2 |
  | Duct Tape Bag | 50 | x3 |
  | Street Bag | 150 | x4 |
  | Heavy Bag | 500 | x6 |
  | Speed Bag | 1,000 | x8 |
  | Double-End Bag | 3,000 | x12 |
  | Pro Bag | 8,000 | x18 |
  | Gold Bag | 20,000 | x25 |
  | Champ Ring | 50,000 | x40 |

  Bags you can't use yet show as **black silhouettes**, and the bag you're
  training on swings.
- A **server leaderboard** on the courtyard wall shows the top 5, and Power
  shows in the player list.
- **Saving** uses ProfileStore. In Studio it runs in *Mock* mode, so
  progress resets when you press Stop — that's on purpose.
- Already planned in the config but **not built yet**: walls/stages, Cash,
  evolutions, Crew pets and boxes, rebirths, moving out to the Suburbs,
  Uptown and the Hills, and game passes. Their buttons currently answer
  "This feature arrives in a later build milestone."

## Where each script lives in Studio

| Folder here | In Studio | What's inside |
|---|---|---|
| `src/ServerScriptService/HoodServer/` | ServerScriptService → HoodServer | `Bootstrap` (starts everything), `DataService` + `ProfileSchema` (saving), `LobbyService` (Power, looks, training mats, leaderboard), `RateLimiter`, `ServerConfig`, `Vendor/ProfileStore`, `UnitTestRunner` (disabled) |
| `src/ReplicatedStorage/Shared/` | ReplicatedStorage → Shared | `Net` (remotes), `SkinArt` (builds the outfits), `LobbyRules`, `RepMath`, `Format`, and `Config/` (Skins, Maps, Balance, Crew, Products, MorphTextures) |
| `src/StarterPlayer/StarterPlayerScripts/HoodClient/` | StarterPlayerScripts → HoodClient | `Lobby` (Power HUD, tips, equip prompts, locked-bag silhouettes, swinging bags), `BlockEnvironment` (train, sounds, neighbors), `Foundation` (Studio-only test panel) |
| `src/ServerStorage/` | ServerStorage | `SimulatorLobby` (builds the lobby), `TheBlockV2` (builds the second World 1), `BlockBuilder`, `BlockPolish` (older map builders) — these only run when you call them from the Command Bar — and `UnitTest/` (tests) |

Left out on purpose: the backup folders in ServerStorage
(`BeforeCompactStages_…`, `BeforeFriendlyCourtyard_…`) and the two
`print("Hello world!")` Scripts in Workspace.

## ⚠️ Before you publish

`src/ReplicatedStorage/Shared/Config/Maps.lua` has
`placeIds = {Block = 0, ...}`. In Studio that's fine, but on a real Roblox
server the game **refuses to start** until `Block` is set to your place's
ID (the code does this on purpose so it never saves to the wrong place).
After publishing, put your PlaceId there — Claude can do it for you.

## Building the lobby

The lobby is made by `src/ServerStorage/SimulatorLobby.lua`. After its
scripts are in Studio (Rojo sync, below), build it once:

1. Open the **Command Bar** (⌘ + Shift + /, type `command bar`).
2. Paste this and press Enter:
   ```lua
   require(game.ServerStorage.SimulatorLobby).Build()
   ```
3. The Output window prints how many parts were built and what was moved
   out of the way. The old lobby and anything that stood inside the new
   courtyard go into **ServerStorage → BeforeHoodLobby_…**, so nothing is
   lost — and **Ctrl+Z / ⌘+Z** undoes the whole build in one step.

Run it again any time the lobby code changes; it replaces itself.

## The second World 1 (The Block V2)

`src/ServerStorage/TheBlockV2.lua` builds a **separate, second version of
World 1** so you can compare it with the first one. It is built far away
from the original (2,400 studs along X) as its own model,
`Workspace.TheBlockV2`, and it never touches `TheBlock`, its lobby, the
lighting or any script.

- **Lobby:** a hood street with a spawn plaza, the **Drip Shop** (a
  brownstone with all 15 looks on a three-row stoop), the **Block Boxing**
  gym (8 bag stations), the **Champ Ring**, the **Bodega Box** stall with
  the 4 Crew pets, a **Free Stash** safe, three **leaderboards**, a
  **Kingpin** statue, the **Uptown subway** down to the World 2 portal,
  string lights with sneakers on the wire, and glowing arrows from the
  spawn to the shop.
- **Map:** stepped brick-and-grass terraces all around, and a straight
  street to the **10 stages** — white, see-through walls 28 studs apart,
  each with its name and recommended Power, ending at Juniper Station.
- It is **looks only** for now: the game's scripts still run on the first
  map, and V2's spawn is switched off, so playing still starts in
  `TheBlock`.

Build it from the Command Bar:

```lua
require(game.ServerStorage.TheBlockV2).Build()
```

Then click **TheBlockV2** in the Explorer and press **F** to fly there.
Running it again replaces only the old V2 (a backup goes to
`ServerStorage → TheBlockV2_Before_…`), and **⌘+Z** undoes it.

## Syncing with Rojo

Same steps as [ROJO-SETUP.md](../ROJO-SETUP.md), run from this `hood`
folder. Two things to know for this game:

- Rojo only touches the scripts listed above. Your map, the backup
  folders and anything else Rojo doesn't know about are left alone.
- Rojo **overwrites** those scripts with the versions in this folder. If
  you change a script in Studio yourself, send Claude a fresh export
  first so nothing gets lost.

## Sending Claude a fresh copy

`tools/export-for-claude.lua` is the command that made this copy. Paste
it into Studio's **Command Bar** and press Enter, then copy each
`ServerStorage → ClaudeExport → PartN` into the chat. Delete the
`ClaudeExport` folder afterwards — it never runs in your game.
