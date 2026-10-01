# Hood (From the Block)

Your own game, copied out of Roblox Studio so Claude can read and work on it.
Everything here is the **scripts** — the map itself (`Workspace.TheBlock`,
the courtyard, buildings, train, etc.) lives in your Studio place.

## What the game does right now

You spawn in **The Block** courtyard and earn **Power** every second.

- **15 looks** stand on the 3-tier pedestal, from **Corner Kid** (free,
  +1/sec) up to **Kingpin** (30,000 Power, +110/sec). Walk up to one and
  press **E** to wear it once you have enough Power. Your look decides how
  much Power you earn.
- **3 gym mats** multiply your Power while you stand on them:
  Corner Gym **x2** (free), Street Gym **x4** (150 Power),
  Boss Gym **x8** (1,000 Power).
- A **server leaderboard** shows the top 5, and Power shows in the
  player list.
- **Saving** uses ProfileStore. In Studio it runs in *Mock* mode, so
  progress resets when you press Stop — that's on purpose.
- Already planned in the config but **not built yet**: walls/stages, Cash,
  evolutions, Crew pets and boxes, rebirths, moving out to the Suburbs,
  Uptown and the Hills, and game passes. Their buttons currently answer
  "This feature arrives in a later build milestone."

## Where each script lives in Studio

| Folder here | In Studio | What's inside |
|---|---|---|
| `src/ServerScriptService/HoodServer/` | ServerScriptService → HoodServer | `Bootstrap` (starts everything), `DataService` + `ProfileSchema` (saving), `LobbyService` (Power, looks, gyms, leaderboard), `RateLimiter`, `ServerConfig`, `Vendor/ProfileStore`, `UnitTestRunner` (disabled) |
| `src/ReplicatedStorage/Shared/` | ReplicatedStorage → Shared | `Net` (remotes), `SkinArt` (builds the outfits), `LobbyRules`, `RepMath`, `Format`, and `Config/` (Skins, Maps, Balance, Crew, Products, MorphTextures) |
| `src/StarterPlayer/StarterPlayerScripts/HoodClient/` | StarterPlayerScripts → HoodClient | `Lobby` (Power HUD, tips, equip prompts), `BlockEnvironment` (train, sounds, neighbors), `Foundation` (Studio-only test panel) |
| `src/ServerStorage/` | ServerStorage | `BlockBuilder`, `BlockPolish`, `SimulatorLobby` (edit-time map builders — they never run during play) and `UnitTest/` (tests) |

Left out on purpose: the backup folders in ServerStorage
(`BeforeCompactStages_…`, `BeforeFriendlyCourtyard_…`) and the two
`print("Hello world!")` Scripts in Workspace.

## ⚠️ Before you publish

`src/ReplicatedStorage/Shared/Config/Maps.lua` has
`placeIds = {Block = 0, ...}`. In Studio that's fine, but on a real Roblox
server the game **refuses to start** until `Block` is set to your place's
ID (the code does this on purpose so it never saves to the wrong place).
After publishing, put your PlaceId there — Claude can do it for you.

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
