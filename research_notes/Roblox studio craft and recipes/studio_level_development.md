# Studio-Level Roblox Development: Recipes for Our Kit

Written October 31, 2026, for Claude sessions building the owner's kid games from `new-game-kit/`.
Goal: work the way a professional Roblox studio works, as concrete steps, without repeating what the kit already does.

**Labels.** [LihFolk] = from the LihFolk Vault V2 notes in `LihFolk/LihFolk Vault V2/` (third-party, verified by its
authors around October 28, 2026). [cited] = checked on the web for this note (link given). [suggested] = our own
recommendation. Where the vault and the root `CLAUDE.md` disagree, `CLAUDE.md` wins.

**How to read a vault note cheaply:** `python3 "LihFolk/LihFolk Vault V2/_tools/vault.py" "<question>"` prints the 3 best TL;DRs;
`--sections "<title>"` lists headings; `--read "<title>" "<heading words>"` prints one section.

---

## 0. Where the kit already stands (don't redo this)

Checked in `new-game-kit/` today:

| Studio practice | Kit status |
|---|---|
| One server entry Script, everything else modules, explicit boot order | Done: `src/Main.server.luau` (Configure -> Init -> hooks -> Receipts.Start -> PlayerData.Start) |
| One `Net` module creating all remotes, rate limit + validator per argument, no InvokeClient | Done: `src/Shared/Net.luau`, `RateLimit.luau` |
| Session-locked saves, fencing token, migrations, newer schema refused, Studio store separate | Done: `src/Server/PlayerData.luau` (hand-rolled lease, ProfileStore-like Mock in Studio) |
| One ProcessReceipt, grant once per PurchaseId, "granted" only after save | Done: `Receipts.luau` + `PlayerData.ProcessPurchaseAsync`; play-through tests redelivery and failed save |
| `--!strict` on every file | Done: all 37 files in `src/` |
| Unit specs + offline play-through + pacing bot + kid-safe scan | Done: `tests/*.spec.luau`, `tools/test.luau`, `sim.luau`, `pace.luau`, `tools/kidsafe_check.py`, all via `tools/check.sh` |
| Monotonic leaderboards with UpdateAsync, BindToClose with a deadline | Done |

**What the kit lacks versus studio practice** (each one is a recipe below): no CI on GitHub, no linter/formatter/type
checker run outside Studio, no error telemetry, no feature flags or kill switches, no boot error isolation or timing,
no release checklist (test place -> live), no data restore tool, no migration fixture saves, no performance budgets
or debug overlay, no map hygiene check, no Studio-only setting checklist (streaming, collision groups), no
suspicion scoring on the TAP/action remotes.

---

## 1. Project architecture

### Takeaway
Big studios use **one server entry and one client entry, everything else ModuleScripts, started in two phases**
(`init` = wire things, never yield; `start` = loops and players). The order is a visible list, each module is started
inside `pcall` so one broken system cannot stop the rest, and slow requires are reported. Frameworks are optional:
Knit is archived, so new games use plain modules (what we do) [LihFolk: Project Structure and Bootstrapping;
Frameworks - Knit Matter and Others]. Our kit is already this shape on the server; the client is one 618-line
LocalScript, which is the part to split.

### Recipes
1. **Keep the kit layout. Don't adopt a framework.** [LihFolk decision table: "Solo developer... plain modules,
   two-phase bootstrap, Net wrapper"]. Knit's repo was archived on July 31, 2024 [LihFolk]. Flamework only makes sense
   with roblox-ts (TypeScript), which the owner doesn't need. An ECS (jecs, Matter) only for one subsystem with
   hundreds of similar things (projectiles, crops, NPC swarms), never the whole game [LihFolk].
2. **Isolate each system at boot** [LihFolk, adapted; suggested for `Main.server.luau`]:
   ```lua
   local function boot(name: string, fn: () -> ())
       local t0 = os.clock()
       local ok, err = xpcall(fn, debug.traceback)
       local ms = (os.clock() - t0) * 1000
       if not ok then warn(("[Boot] %s failed: %s"):format(name, tostring(err))) end
       if ms > 50 then warn(("[Boot] %s took %.0f ms"):format(name, ms)) end
   end
   boot("Currency", function() Currency.Init(Config) end)
   ```
   Exception: `PlayerData.Configure` and `Receipts.Start` must stay fatal (if saves or receipts fail to start,
   the server must not run half-working).
3. **Split the client the same way** [suggested]: `src/Client/Main.client.luau` requires `src/Client/Controllers/*`
   (TopBar, Shop, Eggs, Settings, FX), each with `Init()`/`Start()`. A module over a few thousand lines is a refactor
   signal; a Script's source has a hard 200,000-character limit [LihFolk, measured in one production game].
4. **Dependency rules** [LihFolk: Module Design and Dependency Injection]: Shared never requires Server; no require
   cycles; services get the clock (`now`) and random source passed in, so daily rewards and odds are testable
   (the kit's specs already do this for some modules; make it the rule).
5. **Reserved names**: remotes live only in their own folder (`KitRemotes`) so content can never shadow them
   [LihFolk: a clip named `Origin` once broke every damage request].
6. **Test flags warn on live servers** [LihFolk]: any `ServerStorage` attribute starting with `Test`, `Force` or
   `Simulate` prints a `[Boot]` warning when `not RunService:IsStudio()`.

### Sources
- [LihFolk] `03 Architecture and Networking/Project Structure and Bootstrapping.md` (two phases, production lessons)
- [LihFolk] `03 Architecture and Networking/Frameworks - Knit Matter and Others.md` (Knit archived, decision table)
- [LihFolk] `35 Advanced Luau/Module Design and Dependency Injection.md`

### What our kit should adopt next
1. Per-system `xpcall` + timing in `Main.server.luau` (S).
2. Test-flag warning at boot (S).
3. Split `KitClient` into controllers with Init/Start (M).

---

## 2. Networking

### Takeaway
Every client message is hostile until checked: **rate limit first, then argument count and types, then ranges,
then "does this player own that?", then act with no yield between check and write.** The kit's `Net` already does
the first three. Buffer-based libraries (Zap, Blink: schema compilers; ByteNet, Packet: runtime) only pay off when the
Developer Console's Network tab says bandwidth is the problem; a typed `u8` still needs the ownership check
[LihFolk: Frameworks... Networking libraries]. Server Authority (`Workspace.AuthorityMode = Server`) was fully
released July 9, 2026; it forces StreamingEnabled, deferred signals, fixed simulation, Next Generation Replication and
Input Action System player scripts [LihFolk: Roblox Changes 2025-2026]. Not worth it for a simulator; worth a look
for a future combat game.

### Recipes
1. **New remote checklist** (kit shape, keep using it): `Net.Handle(name, { rate = {burst, perSecond}, args = {validators...}, handler })`.
   Cheap work before the rate check is a CPU attack vector [LihFolk symptom: "remote spam becomes server CPU load"].
2. **Server-built values only**: never relay raw client arguments with `FireAllClients`; the server builds the
   effect description (which pet, which tier) and sends that [LihFolk].
3. **Unreliable remotes for cosmetic streams** (other players' trails, tap sparkles): `UnreliableRemoteEvent`,
   small payloads, losing one is fine [LihFolk: RemoteEvents RemoteFunctions and Unreliable Remotes].
4. **Batch per frame** when a system sends many small updates (e.g. +N pops): collect in a table, flush on
   `Heartbeat` once [LihFolk].
5. **Under Next Generation Replication, property changes are not ordered against RemoteEvents** [LihFolk: change #4].
   Never "set an attribute, then fire a remote, and expect the client to see the attribute first". Put the value in
   the remote payload.
6. **Measure before switching libraries**: Developer Console > Network, per-remote KB/s at full server.
   Only if one remote dominates, move it to a buffer (`buffer.create`, `writeu8`/`writef32`) [LihFolk: Buffers and Binary Data].

### Sources
- [LihFolk] `03 Architecture and Networking/Server Authority and Validation.md`, `RemoteEvents RemoteFunctions and Unreliable Remotes.md`, `Remote Abuse Patterns and Rate Limiting in Practice.md`
- [LihFolk] `49 Roblox Platform Features/Server Authority and Input Migration 2026.md`
- [cited] DevForum comparisons: https://devforum.roblox.com/t/zap-or-bytenet-performance-security/2888968 ,
  https://devforum.roblox.com/t/packet-networking-library/3573907 (titles only seen; content not read)

### What our kit should adopt next
1. Add a `Net.Unreliable(name)` push for cosmetic broadcasts (S).
2. A remote fuzz spec in `tests/` that throws wrong types, NaN, huge numbers, long strings and 1000 calls at every
   registered `Net.Handle` and asserts no error and no state change [LihFolk: Testing Your Own Remotes - Fuzzing and Abuse Tests] (M).
3. Don't adopt Zap/ByteNet now (no measured need) [suggested].

---

## 3. Data

### Takeaway
The kit's `PlayerData` already matches studio practice (lease + fencing token, three load outcomes, migrations,
idempotent receipts). Studios add three things on top: **a way to restore one player, a snapshot before risky
releases, and numbers that show save health in production.** ProfileStore (loleris) is the maintained library if a
game ever wants to swap: `ProfileStore.New`, `StartSessionAsync`, `EndSession`, `MessageAsync`, `.Mock` [LihFolk].
Keep ours: it is tested offline and handles purchases in the same write. DataStore limits are now per experience
and shared with Open Cloud (since July 29, 2026); storage is 500 MB + 1 MB per lifetime player [LihFolk].

### Recipes
1. **Restore one player** [LihFolk: Data Loss Prevention and Recovery]. Version history keeps the first write per key
   per UTC hour for 30 days. Ship as a Command Bar script (`tools/restore-player.lua`) that calls
   `store:GetVersionAtTimeAsync(key, whenMs)` and writes it back with `UpdateAsync` **only if no live lease**,
   bumping the save version and stamping `RestoredFrom`. Never restore with `SetAsync` while the player is online:
   their autosave overwrites it.
2. **Snapshot before data-changing releases** [LihFolk]: Open Cloud "Snapshot Data Stores", once per day. Our cloud
   sessions can't reach apis.roblox.com, so this is an owner step: put it on the release checklist (section 7).
3. **Migration fixtures (golden saves)** [LihFolk: Save Migration Tests - Fixture Saves and Golden Files]: keep one
   saved JSON per old schema version in `tests/fixtures/save_v1.json`, `save_v2.json`...; a spec loads each through
   `PlayerData`'s migrations and compares to the expected latest shape. Any schema bump adds a fixture.
4. **Save health counters** [LihFolk]: count load results (`new`, `loaded`, `failed`, `locked`) and save results
   (`saved`, `error`, `lost`) per server and send them as `AnalyticsService` custom events (section 7). A rising
   `locked` count means sessions aren't released.
5. **Inventories keyed by GUID, not arrays** for anything tradable later [LihFolk: Economy Exploits]. The kit's pets
   should keep a stable id per pet.
6. **Data reset for support**: kick the player, wait for the lease to expire, then clear [LihFolk symptom table].

### Sources
- [LihFolk] `04 Data and Persistence/Session Locking and Profile Libraries.md` (Libraries table), `Data Loss Prevention and Recovery.md`, `Data Schema Design and Migrations.md`
- [LihFolk] `49 Roblox Platform Features/Data and Cloud Changes 2025-2026.md`
- [cited] ProfileStore thread: https://devforum.roblox.com/t/profilestore-save-your-player-data-easy-datastore-module/3190543

### What our kit should adopt next
1. Golden-save fixtures + spec (S).
2. `tools/restore-player.lua` Command Bar helper with `[Restore]` output lines (M).
3. Save-health counters wired into the telemetry module (S once telemetry exists).

---

## 4. Code quality: types, lint, format, review, tests, CI

### Takeaway
Studio standard toolchain, current versions per the vault (October 2026): **Rojo 7.7, Wally, selene, StyLua,
luau-lsp, Lune, pinned with Rokit** [LihFolk: External Tooling]. Rojo 7.7.0 added `rojo syncback` (turn a place into
a project), WebSockets for `serve`, `.jsonc` support and safer `serve` defaults [cited]. Luau's new type solver is
the default since early 2026 [LihFolk]. Roblox's built-in **Script Sync** is still a Studio beta (Oct 28, 2026) and its
file naming differs from Rojo's (`x.client.luau` = a client-context Script, not a LocalScript), so don't mix them
[LihFolk]. TestEZ is old and unmaintained; Jest-Lua (`jsdotlua/jest-lua`) is the maintained Roblox test framework
[cited, repo exists]; our own `tests/Runner.luau` on Lune is fine and needs no Roblox. **Everything in `tools/check.sh`
can run on GitHub Actions today** because it only needs Lune and Python. Engine-level tests need Open Cloud Luau
Execution against a test place (owner-only, needs an API key) [LihFolk].

### Recipes
1. **Pin tools** [LihFolk]: `rokit.toml` at the repo root:
   ```toml
   [tools]
   lune = "lune-org/lune@0.10.5"      # the kit is tested on 0.10.5; vault lists 0.11.1 as current
   selene = "Kampfkarren/selene@0.32.0"
   stylua = "JohnnyMorganz/StyLua@2.6.0"
   luau-lsp = "JohnnyMorganz/luau-lsp@1.70.1"
   rojo = "rojo-rbx/rojo@7.7.1"
   ```
   (Versions from the vault; confirm each tag exists before relying on it.)
2. **Lint** [LihFolk]: `selene.toml` with `std = "roblox"`, `global_usage = "deny"`, `unused_variable = "warn"`,
   `shadowing = "warn"`. For offline CI set `roblox-std-source = "pinned"` and commit `roblox.yml`.
3. **Format**: `stylua.toml` (tabs, column 120 to match the kit), run `stylua --check src tests tools`.
   First run: format everything in one separate commit so later diffs stay readable [suggested].
4. **Type check outside Studio** [LihFolk]:
   ```sh
   rojo sourcemap default.project.json -o sourcemap.json
   luau-lsp analyze --platform=roblox --sourcemap=sourcemap.json \
     --definitions=@roblox=tools/globalTypes.d.luau --ignore="Packages/**" src
   ```
   `globalTypes.d.luau` comes from the luau-lsp repo (`scripts/globalTypes.d.luau`); commit a copy so CI is offline.
   This is the cheapest way to catch invented APIs in AI-written code.
5. **CI workflow** [LihFolk Stage 7, adapted; suggested] `.github/workflows/kit-check.yml`:
   ```yaml
   name: kit-check
   on: [push, pull_request]
   jobs:
     check:
       runs-on: ubuntu-latest
       steps:
         - uses: actions/checkout@v4
         - name: Install Lune 0.10.5
           run: |
             mkdir -p $HOME/bin && cd /tmp
             curl -sSLo lune.zip https://github.com/lune-org/lune/releases/download/v0.10.5/lune-0.10.5-linux-x86_64.zip
             unzip -o lune.zip -d $HOME/bin && chmod +x $HOME/bin/lune
             echo "$HOME/bin" >> $GITHUB_PATH
         - run: sh new-game-kit/tools/check.sh
         - run: python3 tools/kidsafe_check.py
   ```
   Add one job per game folder that has a `tools/check.sh`. Add selene/StyLua/luau-lsp steps once they pass locally.
   Note: `check.sh` rebuilds the `.rbxl`; in CI, upload it as an artifact instead of committing it.
6. **Review order for AI-written code** [LihFolk: Code Review for Luau Teams], risk first:
   trust boundaries (remotes, ProcessReceipt, client-writable attributes) -> persistence (every DataStore call, every
   grant) -> yields between check and write -> lifecycle (who disconnects this?) -> types and nil casts -> contracts
   (remote names, attribute names) -> readability last. AI-specific smells: invented APIs, `wait()`/`spawn()`,
   trusting a client price or damage, "handles disconnects" comments over code that doesn't, giant diffs.
7. **Test what matters** [LihFolk: Automated Testing with TestEZ and Jest-Lua]: money, odds (statistical test over
   100k rolls with a seeded random), migrations (fixtures), validators, config invariants (every egg's odds add to
   100%, every product id 0 is hidden). Don't unit-test UI glue; that's what the preview renders and Studio are for.
8. **Grep gate for deprecated names** [LihFolk: Engine and API Changes 2025-2026]: fail check if new code uses
   `:GetProductInfo(`, `:AwardBadge(`, `:LoadCharacter(`, `:IsInGroup(`, `:ReserveServer(` (use the `Async` names).
   The kit currently passes this.

### Sources
- [LihFolk] `01 Studio and Workflow/External Tooling - Rojo Wally Selene StyLua.md`
- [LihFolk] `17 Pipelines/Code Pipeline - Rojo Git and CI.md` (Stages 5 to 7: Luau Execution limits, CI yaml, Place Publishing API)
- [LihFolk] `50 Team Collaboration and Project Management/Code Review for Luau Teams.md`
- [LihFolk] `49 Roblox Platform Features/Engine and API Changes 2025-2026.md` (new type solver, Script Sync beta)
- [cited] Rojo 7.7.0 release notes: https://github.com/rojo-rbx/rojo/releases/tag/v7.7.0
- [cited] Jest-Lua: https://github.com/jsdotlua/jest-lua ; TestEZ: https://github.com/Roblox/TestEZ
- [cited] pesde (alternative to Wally, Rust, also for Lune): https://lib.rs/crates/pesde (we have no packages, so neither is needed yet)

### What our kit should adopt next
1. GitHub Actions running every `check.sh` + kid-safe scan on each push (S). Biggest single win: no broken kit merges.
2. selene + StyLua configs, then CI steps (S).
3. luau-lsp analyze in CI with committed type definitions (M; expect a first batch of new-solver errors).
4. Deprecated-name grep in `kidsafe_check.py` or `check.sh` (S).

---

## 5. Performance

### Takeaway
Measure in milliseconds, on a real phone, in a live server, not Studio. Budget for a 60 fps phone: rendering 8 to
10 ms, engine simulation 2 to 3 ms, **all our client scripts 2 ms**, 2 to 3 ms headroom; server scripts under about
5 ms per heartbeat at full player count [LihFolk: Performance Fundamentals, rule of thumb]. Memory: low-end phone well
under 1 GB in heavy areas; investigate when the dashboard crash rate passes 2 to 3% [LihFolk]. The Performance
dashboard needs at least 100 DAU before it shows charts [LihFolk].

### Recipes
1. **Which tool for which question** [LihFolk]:
   - Hitch or low fps, unknown cause: MicroProfiler (Ctrl+F6 / Ctrl+P), capture 30 to 90 frames, find the family
     (script, physics, render, network, UI).
   - Which function costs most: Developer Console > ScriptProfiler, Functions view, 1 kHz, 1 minute; **name your
     handlers** (`local function onHeartbeat(dt)`) or they show as `<anonymous>`; export JSON before and after.
   - Memory: Developer Console > Memory. PlaceMemory and PlaceScriptMemory are ours. `Instances` -> fewer parts or
     streaming; `PhysicsCollision` -> lower CollisionFidelity, CanCollide/CanQuery off; `GraphicsTexture` -> reuse
     texture ids; `LuaHeap` -> leaks.
   - Bandwidth: Developer Console > Network.
2. **Script patterns that win** [LihFolk: Script Performance]: gate loops by visibility; lower the cadence (10 Hz is
   fine for UI numbers); distance tiers for effects; write a property only when the value changed; no new tables or
   closures per item in a hot loop.
3. **Leak rules** [LihFolk: Memory Budgets and Leaks]: every table keyed by Player has a `PlayerRemoving` cleanup;
   every per-round connection goes in a Janitor; capped caches. (Root `CLAUDE.md` adds: never key a weak table by Instance.)
4. **Effect budgets with a cap, a measured value and a low mode** [LihFolk, measured]: e.g. a big celebration about
   3,200 particles over 2 s for the caster, half for onlookers; at most 3 Highlights per effect, pooled. The kit's
   `Emit` and `Setting_LowGraphics` give the low mode; write the cap next to each effect in config.
5. **Parallel Luau only when profiled** [LihFolk: Parallel Luau and Actors]: worth it for heavy pure compute or many
   spatial queries split across many Actors with `ConnectParallel`; writes to instances need `task.synchronize()`.
   Simulators almost never need it.
6. **Gated debug overlay** [LihFolk: Gated Tester Commands and Debug Panels]: a small client panel (fps, ping,
   memory, instance count, remote calls per second) that only opens for the owner's user id or in Studio.

### Sources
- [LihFolk] `12 Performance Testing and Debugging/Performance Fundamentals.md` (Budgets), `MicroProfiler Guide.md`,
  `Script Performance.md`, `Developer Console and Stats.md` (Memory categories), `Memory Budgets and Leaks.md`
- [LihFolk] `02 Luau Scripting/Parallel Luau and Actors.md`

### What our kit should adopt next
1. `Config.Budgets` table (particles per effect, max Highlights, client ms) + a check that every Emit call names its
   budget (M).
2. Gated debug overlay in the client (M).
3. A "perf pass" line in the release checklist: one live server, one phone, MicroProfiler + memory screenshot (S).

---

## 6. Building in Studio at studio level

### Takeaway
Pro maps are cheap for the engine: **everything static anchored, decoration with CanCollide, CanTouch and CanQuery
off, simple invisible colliders for complex meshes, Box or Hull collision fidelity (Precise only where you walk on
detail), streaming on, buildings Atomic, and shared props as Packages.** Collision groups are now set on
`workspace` (WorldRoot) since September 2026; the old `PhysicsService` calls forward with a deprecation warning, max
32 groups [LihFolk]. CollisionFidelity can't be changed by script on a loaded part: set it in Properties or when the
mesh is created [LihFolk].

### Recipes
1. **Collision groups** [LihFolk]:
   ```lua
   workspace:RegisterCollisionGroup("Players")
   workspace:RegisterCollisionGroup("Pets")
   workspace:CollisionGroupSetCollidable("Players", "Pets", false)
   -- on spawn: for each BasePart of the character, part.CollisionGroup = "Players"
   ```
   Register once at boot; write the group matrix in the game's `CLAUDE.md`.
2. **Part hygiene script** (Command Bar, prints `[Hygiene]` lines) [LihFolk checklist; suggested tool]: count parts,
   unanchored parts outside characters, decoration with CanTouch/CanQuery on, MeshParts with
   `PreciseConvexDecomposition`, scripts inside Workspace models. Same checks can run in Lune on the built `.rbxl`
   (we already load places in Lune for `build_place.luau`).
3. **Streaming settings** (non-scriptable, set in Studio Properties on Workspace) [LihFolk, Roblox docs via vault]:
   StreamingEnabled on; `StreamingMinRadius` 64; `StreamingTargetRadius` 1024; `StreamOutBehavior` Opportunistic;
   `StreamingIntegrityMode` PauseOutsideLoadedArea; `ModelStreamingBehavior` Improved. Shops, eggs and stands as
   `ModelStreamingMode = Atomic`; only true essentials Persistent. Client code finds world things by
   CollectionService tags with `GetInstanceAddedSignal`, never long `WaitForChild` chains. Before a server teleport
   inside the map, `player:RequestStreamAroundAsync(pos)`.
   Since the owner sets these by hand, give a Command Bar script that prints the current values next to the wanted
   values (scripts can't set them).
4. **Streaming QA** [LihFolk: StreamingEnabled QA]: test once with Opportunistic and a small target radius so things
   really stream out; walk away from each egg/shop, come back, use it again.
5. **Packages for shared assets** [LihFolk: Packages and Asset Reuse]: create packages under the group, wrap single
   parts in a Model first, per-copy differences only through attributes on the root, never touch `PackageLink`,
   publish nested packages inside-out. A package publish is not live until each place is republished and servers restart.
6. **Lighting presets as data** [suggested]: keep Lighting + Atmosphere + Sky values in a config module per mood and
   apply at boot, so the look is in Git (the cartoony-building skill already defines the presets to use).
7. **Mesh streaming**: `MeshPart.RenderFidelity` is ignored when `Workspace.MeshStreamingAndImprovedLoDs` is on and is
   planned for removal; 4096 px textures render in live games since January 30, 2026 [LihFolk].

### Sources
- [LihFolk] `12 Performance Testing and Debugging/Physics Performance.md`, `StreamingEnabled QA - Forcing Stream-Out to Catch Nil Bugs.md`
- [LihFolk] `03 Architecture and Networking/Instance Streaming.md` (Workspace properties table)
- [LihFolk] `01 Studio and Workflow/Packages and Asset Reuse.md`, `50 Team Collaboration and Project Management/Packages and Shared Assets Across Places.md`
- [LihFolk] `49 Roblox Platform Features/Roblox Changes 2025-2026.md` (#9 mesh streaming)

### What our kit should adopt next
1. Lune map hygiene check on the built place, added to `check.sh` (M).
2. Command Bar "Studio settings report" for streaming + collision groups (S).
3. Collision groups registered in a kit module using the `workspace` API (S).

---

## 7. Workflow: branches, releases, flags, analytics, errors, updates

### Takeaway
Studios keep **dev, test and live separate** (separate places, ideally a separate test experience so test saves
never touch live DataStores), release on a checklist, keep **kill switches** for every new feature, and watch the
**Error Report filtered to "new since version"** after each publish [LihFolk]. Roblox's **Configs (ConfigService)**
lets the owner change values live from Creator Hub (staged first, then "Publish now" in about 15 s to 1 min, or over
15 min; history with one-click restore; server only) [LihFolk: Global State and Live Config; not checked on the web
here]. Restarting servers from the dashboard already moves players to updated servers, so a custom soft shutdown is
only needed when you want to control where they land [LihFolk].

### Recipes
1. **Branches** [suggested, fits GitHub Desktop]: `main` = what's live. Each change on a branch, CI green, then
   merge. Tag each live publish `v<date>` in GitHub Desktop so a rollback is "open the tagged place file".
2. **Test place -> live place** [LihFolk: Build Test and Release Pipeline]: the owner keeps a second private
   experience "<Game> TEST" with its own DataStores. Publish there first, play 10 minutes on phone + PC, then publish
   the same `.rbxl` to live. Never test purchases or data resets in the live experience.
3. **Release checklist** (copy into each game's `CLAUDE.md`) [LihFolk: Release Process and Rollbacks; Pre-release
   checklist; plus our rules]:
   - `check.sh` green; kid-safe green; no test flags set; no Studio-only KeyframeSequence animations in gameplay code.
   - Every product/pass id real, or 0 and hidden. Animations published to the experience owner (group).
   - If the save schema changed: owner takes a DataStore snapshot first; migration fixture added.
   - Publish to TEST, play it, then live. Note `game.PlaceVersion` in the commit tag.
   - After publish: Creator Hub > Monitoring > Error Report, filter "new since version", 30 min and 24 h later.
   - Rollback = publish the previous tagged place (Version History), or flip the kill switch.
4. **Kill switches** [LihFolk]: a `Flags` module, attribute on ReplicatedStorage wins, else config default:
   ```lua
   function Flags.on(name: string): boolean
       local v = ReplicatedStorage:GetAttribute("Flag_" .. name)
       if typeof(v) == "boolean" then return v end
       return Defaults[name] == true
   end
   ```
   Server copies live values into those attributes from ConfigService (recipe 5), so the owner can turn a broken
   event off without publishing. Every new feature ships with a flag.
5. **Live config with safe defaults** [LihFolk]: `ConfigService:GetConfigAsync()` in `pcall`; on failure use code
   defaults; type-check each value against its default; on `UpdateAvailable` call `snapshot:Refresh()` (or wait for
   a round boundary). Good uses for kids' games: weekend 2x event on/off, code list, egg rotation. Not for prices
   (prices come from Roblox product info) and never for odds without updating the shown odds in the same step.
6. **Error telemetry** [LihFolk: Crash and Error Telemetry]: a server `Telemetry` module that listens to
   `ScriptContext.Error`, takes client errors through a rate-limited `Net.Listen("ClientError")` (10 per minute, strings
   cut to 500/2000 chars), strips numbers from messages (so one bug = one row; the Error Report only tracks 500 unique
   errors), and flushes once a minute as `[telemetry vN]` warns plus `AnalyticsService` custom events. Keep player ids
   out of message text.
7. **Analytics** [suggested; vault: `52 Core Concepts` analytics notes]: send funnel steps the blueprints care about
   (joined, first tap, first egg, first rebirth, first purchase prompt) with `AnalyticsService:LogFunnelStepEvent`
   and economy sources/sinks with `LogEconomyEvent`. Check the exact signatures in the current docs before writing them.
8. **Soft shutdown** [LihFolk]: not needed for normal updates. If used: save first (our BindToClose already does),
   only on `Enum.CloseReason.DeveloperUpdate`, teleport to a reserved holding server via `TeleportOptions.ReservedServerId`,
   then back. Teleports don't run in Studio or during moderation shutdowns.
9. **Old servers keep running old code** during a rollout [LihFolk]: remote names and save fields only get added, never
   renamed, in the same release; PlayerData already refuses newer schemas, which protects saves.
10. **Disaster recovery** [LihFolk: Disaster Recovery...]: everything owned by the group, not a personal account; the
    repo is the code backup; weekly `.rbxl` export of the live place into `design/` or a release; asset source files kept.

### Sources
- [LihFolk] `13 Production and Case Studies/Release Process and Rollbacks.md` (Kill switches, Pre-release checklist)
- [LihFolk] `17 Pipelines/Build Test and Release Pipeline.md`
- [LihFolk] `04 Data and Persistence/Global State and Live Config.md` (ConfigService)
- [LihFolk] `12 Performance Testing and Debugging/Crash and Error Telemetry.md`
- [LihFolk] `03 Architecture and Networking/Server Lifecycle and Shutdown.md` (soft-shutdown sketch)
- [LihFolk] `13 Production and Case Studies/Disaster Recovery for a Roblox Game - Places, Code, Assets, Data and Accounts.md`

### What our kit should adopt next
1. `Telemetry` module (ScriptContext.Error + client reporter + save-health counters) (M).
2. `Flags` module + every service checks its flag; optional ConfigService feed (S, then M).
3. Release checklist + TEST experience in each game's `CLAUDE.md` (S).
4. Funnel analytics events for the first-session beats (S).

---

## 8. Security for simulators

### Takeaway
In a simulator, cheaters want **free currency, duped pets and auto-farming**. The defences that matter: every
gain computed on the server; one synchronous commit per economic action (no yield between check and write);
purchases only in ProcessReceipt or `UserOwnsGamePassAsync`; server cadence caps on TAP and action remotes (drop
extra calls silently, don't kick); suspicion scores from several signals before any action [LihFolk]. Since the
client can't be trusted, **making the macro pointless beats detecting it**: offer auto-tap as a feature (or hold to
repeat) so autoclickers give no edge [LihFolk: Autoclicker and Macro Detection].

### Recipes
1. **Cadence cap on TAP** [LihFolk]: the server accepts at most N taps per second (a human-plausible number, e.g.
   10 to 12) and silently drops the rest. The kit's per-remote RateLimit does this; make sure the TAP rate is the
   human cap, not a generous one.
2. **Proximity prompts, ClickDetectors and Touched are remotes too** [LihFolk]: check distance on the server
   (`(root.Position - part.Position).Magnitude < promptRange + 4`) and cooldown.
3. **Movement**: for an obby or speed game, server checks on speed/teleport with exemptions for server moves
   (respawn, teleport pads) and a suspicion score, never a kick on one hit [LihFolk: Detecting Movement Exploits].
4. **Conservation audit** [LihFolk: Dupe Hunting Test Script]: in `tools/sim.luau`, after the play-through, assert
   total coins in = earned + bought - spent for every player, and pets created = hatched + granted. Run it again with
   slow and failing DataStore knobs.
5. **Admin commands** [LihFolk: Admin Commands Done Safely]: allowed user ids on the server only, every command
   logged; never trust a client "isAdmin".
6. **Toolbox safety**: insert free models in a scratch place first and read every script [LihFolk symptom table].
7. **Account security** [LihFolk: Creator Account Security]: 2-step verification on the owner account and group;
   API keys per purpose, minimum scopes, never in the repo.

### Sources
- [LihFolk] `22 Anti-Exploit and Security/Anti-Exploit Start Here.md`, `Economy Exploits - Dupes Races and Purchase Abuse.md`,
  `Autoclicker and Macro Detection for Combat Remotes.md`, `Testing Your Own Remotes - Fuzzing and Abuse Tests.md`
- [LihFolk] `03 Architecture and Networking/Exploits and Anti-Cheat.md`

### What our kit should adopt next
1. Conservation audit in `sim.luau` (S).
2. Remote fuzz spec (M, shared with section 2).
3. Server distance checks helper for prompts/touches (`Net.NearPart(player, part, range)`) (S).

---

## Top adoptions, ranked (all sections)

| # | Adopt | Why | Effort |
|---|---|---|---|
| 1 | GitHub Actions running `check.sh` + kid-safe scan on every push | No broken merges; agents' work is checked automatically | S |
| 2 | Error telemetry module (ScriptContext.Error + rate-limited client reports + save-health counters) | We learn about live bugs without the owner screenshotting Output | M |
| 3 | `Flags` kill switches (+ optional ConfigService feed) on every new feature | Turn a broken feature off without a publish | S/M |
| 4 | Release checklist + separate TEST experience, tagged releases | Test saves never touch live; rollback is one step | S |
| 5 | Boot isolation: per-system `xpcall`, timing, test-flag warning | One broken system can't kill the server silently | S |
| 6 | Golden-save migration fixtures | Schema changes can't wipe saves | S |
| 7 | selene + StyLua + luau-lsp analyze (with committed type defs) | Catches invented APIs and nil bugs in AI code before Studio | M |
| 8 | Remote fuzz spec + conservation audit in the play-through | Proves no free currency or dupes from bad input | M |
| 9 | Map hygiene check + Studio settings report (streaming, collision groups, CanQuery/CanTouch) | Phone performance and fewer stream-in bugs | M |
| 10 | Split `KitClient` into controllers; perf budgets + gated debug overlay | Client stays editable; effects stay inside budget | M |

Owner-only steps these imply (cloud sessions can't do them): create the TEST experience, take DataStore snapshots
before schema changes, read the Error Report after each publish, set Workspace streaming properties by hand, create
any Open Cloud API key (only if we later want cloud tests or CI publishing).
