---
tags: [build-playbooks, architecture, networking, data, testing, ci, performance, release, security, studio-level]
updated: 2026-10-31
---

# 18 Studio-Level Development Playbook

Back to [[00 Build Router]] · Whole-game craft: [[20 Whole-Game Field Guide]] · Recipes: [[19 Animation and VFX Recipe Book]] · Code brief: `Sector Briefs/Brief - Code, Networking and Security.md` · Installing into the owner's open Studio: [[24 Working Live in Studio - Saves, Turns and Hand Edits]]

**Why this note exists.** On Oct 31 Alex asked us to "learn studio level developing". This note is how professional Roblox studios build, tuned for us: Claude writes all the code from the cloud, and Alex tests in Studio.

**Sources:**
- Full notes with snippets and sources: `research_notes/Roblox studio craft and recipes/studio_level_development.md`.
- Most facts are from the LihFolk vault (checked around Oct 28, 2026). Mark anything you rely on heavily as "check in Studio".

## 0. What our kit already does at studio level (don't rebuild it)
| Studio practice | Where |
|---|---|
| One server entry Script, everything else modules, fixed start order | `new-game-kit/src/Main.server.luau` |
| One `Net` module makes every remote, with a rate limit and argument checks | `Shared/Net.luau`, `RateLimit.luau` |
| Session-locked saves, fencing token, migrations, newer save versions refused | `Server/PlayerData.luau` |
| One ProcessReceipt, grant once per PurchaseId, "granted" only after the save | `Server/Receipts.luau` |
| `--!strict` on every file | all of `src/` |
| Unit specs, offline play-through, pacing bot, kid-safe scan | `tools/check.sh` |
| **New Oct 31:** checks run automatically on every GitHub push | `.github/workflows/checks.yml` |
| **New Oct 31:** kill switches | `Shared/Flags.luau` |
| **New Oct 31 (2nd pass):** errors grouped into one line per bug, client errors collected, failed save loads counted | `Server/ErrorLog.luau` |
| **New Oct 31 (2nd pass):** bad input thrown at every remote (17 kinds × every remote) | `tools/sim.luau`, "Bad input" |
| **New Oct 31 (2nd pass):** real old saves must still load, with gems and rebirths kept | `tests/fixtures/save_v1.json` + `tools/sim.luau` |
| **New Oct 31 (2nd pass):** the timings in notes 16, 17 and 19 are checked against the kit's code | `tests/VaultNumbers.spec.luau` |

**Each new check was proved to bite** (a check that never fails proves nothing):
- the bad-input test failed when we planted a crash in the codes remote;
- the old-save test failed when we added a migration that wiped gems (205 → 0).

## 1. Architecture
- **One server entry and one client entry; everything else is a ModuleScript.**
  - Start in two phases: `Init` wires things up and never waits; `Start` runs loops and handles players.
  - Keep the order as a visible list.
- **No framework.** Knit was archived in July 2024. Plain modules are what new games use, and what we use.
- **Next step:** split the kit's 618-line `KitClient` into small controllers, each with `Init` and `Start`.
- **Starting systems inside `pcall`:** only for systems that don't own saved data. If a system that registers a save slice fails and the game keeps going, the next save could wipe that slice. Save loading and receipts stay fatal on purpose.

## 2. Networking
- **Every client message is hostile until checked, in this order:**
  1. rate limit;
  2. argument count and types;
  3. ranges;
  4. "does this player own that?";
  5. then act, with no waiting between the check and the write.
- **Effects:** the server decides and fires one remote (effect name, position, `GetServerTimeNow()`). Clients play the visuals. Replicate effects, never hitboxes.
- **Buffer libraries** (Zap, Blink, ByteNet, Packet) only pay off when the Developer Console's Network tab shows bandwidth is the problem.
- **Server Authority** (`Workspace.AuthorityMode = Server`) was released July 9, 2026. It forces streaming and a different input system. Not worth it for simulators; consider it for a future combat game.
- **Combat games:**
  - push the knocked-back player on their own device;
  - check hits on the server with about 1 s of position history, rewinding at most 250 ms.

## 3. Data
- **Keep our `PlayerData`.** It matches studio practice. Studios add three things on top:
  1. a way to restore one player's save;
  2. a snapshot before any release that changes the save format (owner step);
  3. save-health numbers in production: failed loads, locked loads, and the time a save takes.
- **Migration test saves (built):** `tests/fixtures/save_v<N>.json` is a real save from a played session. The play-through loads every one on today's build and checks gems and rebirths survive. See §11 A for the steps when the save format changes.
- **Limits:**
  - DataStore limits are per experience and shared with Open Cloud since July 29, 2026.
  - Storage is 500 MB plus 1 MB per lifetime player.
  - ProfileStore (loleris) is the maintained library if a game ever needs to swap.

## 4. Code quality, tests and CI
- **Standard toolchain (Oct 2026):** Rojo 7.7, Wally, selene, StyLua, luau-lsp and Lune, all pinned with Rokit.
  - Rojo 7.7 added `rojo syncback`, which turns a place into a project.
- **Luau's new type checker** has been the default since early 2026. Expect new warnings the first time you run it.
- **Studio's Script Sync** is still a beta and names files differently from Rojo. Don't mix the two.
- **Tests:** TestEZ is unmaintained; Jest-Lua is the maintained Roblox test framework. Our Lune `tests/Runner.luau` needs no Roblox and stays.
- **CI:** `.github/workflows/checks.yml` runs `new-game-kit/tools/check.sh` and `tools/kidsafe_check.py` on every push and pull request. When a check is red, fix it; never skip a test.
- **Next, the cheapest way to catch made-up APIs in AI-written code:** add `selene` (linter), `StyLua` (formatter) and `luau-lsp analyze` (type check), with Roblox's type definitions committed.
- **Before every push, look for the old API names:** `:GetProductInfo(`, `:AwardBadge(`, `:LoadCharacter(`, `:IsInGroup(`, `:ReserveServer(`. Use the `Async` versions.
- **Review checklist for any change:**
  - strict mode on;
  - no waiting between a check and a write;
  - every remote has a rate limit and a validator;
  - no invented IDs;
  - kid-safe check passes;
  - the place rebuilds.

## 5. Performance (measure on a real phone, in a live server)
- **60 fps phone budget:**

  | Work | Budget |
  |---|---|
  | Rendering | 8–10 ms |
  | Engine simulation | 2–3 ms |
  | All our client scripts | **2 ms** |
  | Headroom | 2–3 ms |
  | Server scripts (full player count) | under about 5 ms per heartbeat |

- **Scene budget:** about 500 draw calls and 500k triangles; about 150 draw calls for UI; under 1.3 GB of memory.
  - Each ParticleEmitter or Beam is one draw call; BillboardGuis add up fast.
- **Investigate when:**
  - the crash rate passes 2–3%;
  - a low-end phone uses close to 1 GB in heavy areas.

  The Performance dashboard needs 100+ daily players before it shows charts.
- **Tools:**
  - MicroProfiler (Ctrl+F6);
  - Script Profiler;
  - the Developer Console's Memory tab, by category;
  - the Network tab.
- **Cosmetic motion runs on the client.** Use pooling for projectiles and popups, and `Emit()` bursts instead of many emitters.
- **Parallel Luau (Actors):** only for heavy maths across many objects, such as path grids or procedural generation. Never for UI.

## 6. Building in Studio at studio level
- **Anchor everything static.** Decoration gets CanCollide, CanTouch and CanQuery **off**.
- **Complex meshes:** use simple invisible colliders, with Box or Hull collision fidelity. Use Precise only where players walk on the detail.
  - CollisionFidelity can't be changed by script on a loaded part: set it in Properties.
- **Streaming on.** Buildings are Atomic models. Props shared across places are **Packages**.
- **Collision groups** are set on `workspace` since Sept 2026 (the old PhysicsService calls warn). The maximum is 32.
- **Next:** a Lune map check on the built place. It flags unanchored parts, decoration with CanTouch or CanQuery on, and Precise collision on meshes. A Command Bar report for Alex shows the streaming settings.

## 7. Workflow: release like a studio
1. **Three places:**
   - dev (Studio and Rojo);
   - test, ideally a separate **TEST experience** so test saves never touch live data (owner creates it);
   - live.
2. **Every new feature ships behind a kill switch:** `if Flags.On("RareReveal") then ... end`.
   - Turn a feature off live by setting the `Flag_<Name>` attribute on ReplicatedStorage from a server: Command Bar, an admin command, or a ConfigService value.
3. **Release checklist:**
   1. checks green;
   2. the place rebuilt;
   3. tested in the TEST experience;
   4. a save snapshot if the save format changed;
   5. publish;
   6. tag the release in git;
   7. read the Error Report filtered to "new since version" the next day.
4. **Error logging (built: `Server/ErrorLog.luau`):**
   - server errors come from `ScriptContext.Error`; client errors come through one rate-limited remote (each new kind once, at most 20 per player per session);
   - numbers, ids and player names are stripped, so one bug is one row with a count and a number of players (Roblox's Error Report tracks only 500 unique errors);
   - failed save loads are counted by reason (`SaveLoadFailed:locked`, `:newer`, `:corrupt`);
   - Output gets one `[ErrorLog]` line per kind of error per minute, never a flood. To see the top 10, see §11 C.
5. **Live config:** Roblox's Configs (ConfigService) lets Alex change values from the Creator Hub without publishing. It takes about 15 s to 1 min, and keeps a history with one-click restore. Check the exact calls in the docs before using it.
6. **Updates:** restarting servers from the dashboard already moves players to updated servers. Only build a custom soft shutdown if you need to control where players land.
7. **Funnels:** AnalyticsService funnels are logged on the server, up to 10, for steps such as join, first tap, first purchase, first rebirth.

## 8. Security for simulators
- **What cheaters want:** free currency, duplicated pets, auto-farming. The defences:
  - every gain is computed on the server;
  - one write per economic action, with no waiting between the check and the write;
  - purchases only in ProcessReceipt or `UserOwnsGamePassAsync`;
  - caps on how often tap and action remotes can fire (silently drop extra calls; never kick);
  - suspicion scores from several signals before taking any action.
- **Make the macro pointless:** offer auto-tap (or hold-to-repeat) as a feature, so autoclickers give no edge.
- **Built:** the play-through throws 17 kinds of bad input at every remote: NaN, infinity, negative, huge, fractions, `"__index"`, empty and 100 kB strings, broken text, empty and 40-deep tables, wrong types, and 9 extra arguments. Each remote must answer with a proper result, never crash, and move no coins, gems, upgrades, rebirths or settings.
- **Still to do:** the same coins-and-pets check while saves are slow or failing.

## 9. Ranked to-do for the kit
| # | Adopt | Effort | Status |
|---|---|---|---|
| 1 | Checks on every GitHub push | S | ✓ done Oct 31 |
| 2 | Kill switches (`Flags`) | S | ✓ done Oct 31 (ConfigService feed not yet) |
| 3 | Error logging module | M | ✓ done Oct 31 (`ErrorLog`) |
| 4 | Release checklist and a TEST experience | S | checklist here; Alex creates the experience |
| 5 | Migration test saves | S | ✓ done Oct 31 |
| 6 | selene, StyLua, luau-lsp in CI | M | to do (needs their Roblox type files pinned) |
| 7 | Bad-input test for every remote, plus the coins-and-pets check | M | bad input ✓ done Oct 31; slow-save check to do |
| 8 | Map check and Studio settings report | M | to do |
| 9 | Split `KitClient`, effect budgets, debug overlay | M | to do |

## 10. Owner-only steps
These are steps cloud sessions can't do:
- Create the TEST experience.
- Take a save snapshot before any release that changes the save format.
- Read the Error Report after each publish.
- Set the Workspace streaming properties.
- Create Open Cloud API keys (only if we later want tests or publishing run from GitHub).

## 11. Worked examples (copy these)

### A. Changing the save format without losing anyone's progress
Example: Coins become "Gold".
1. **Before touching code**, keep a save from today's build: `SAVE_FIXTURE=1 lune run tools/sim.luau` (from the game folder). It writes `tests/fixtures/save_v1.json`. Commit it.
2. In `GameConfig.luau`, set `schemaVersion = 2` and add the step:
   ```lua
   migrations = {
       [2] = function(data)
           local b = data.Currency.Balances
           b.Gold = (b.Gold or 0) + (b.Coins or 0)
           b.Coins = nil
       end,
   },
   ```
3. Run `sh tools/check.sh`. The play-through loads `save_v1.json` on the new build. If a step loses gems or rebirths, it fails and names the file.
4. Never edit or delete an old fixture. Each save version keeps its own file forever, because some player will come back after a year.
5. Owner step: take a save snapshot in the Creator Hub before publishing.

**Rules for a migration step:** it only adds or moves fields; it never errors on a field that is missing (`or 0`); it never reads the clock or other players. A step that errors makes that player's load fail, and the save is left untouched. That is safe, but they can't play until it is fixed.

### B. Turning a feature off in a live game
1. The feature is already wrapped: `if Flags.On("RareReveal") then ... end`.
2. Owner, in a live server: press F9 to open the Developer Console, open the **Server** side, and type in its command line (owner only; check where it sits in today's console):
   `game.ReplicatedStorage:SetAttribute("Flag_RareReveal", false)`
3. That server stops the feature at once. Other servers keep it until they restart, so for every server, change `Config.Flags.RareReveal = false` and publish (or use ConfigService later).

### C. Reading errors the day after a publish
1. In a live server, open F9 → Server, and type `require(game.ServerScriptService.Kit.ErrorLog).Print()`.
2. It prints the top 10 kinds of error with counts and how many players hit each one, then the save-health counts.
3. Fix the top one first. A `SaveLoadFailed:newer` count above 0 means an old server is still running next to a new build: restart old servers from the dashboard.
4. The Creator Hub's Error Report shows the same server errors over days, but not client errors grouped by player. Use both.

### D. Adding a new remote the studio way
```lua
Net.Handle("Pets.Rename", {
    rate = { burst = 3, perSecond = 0.5 },             -- 1. a rate limit (required)
    args = { T.guid, T.string(20, "^[%w ]+$") },      -- 2. one validator per argument
    handler = function(player, uid, name)
        local pet = Inventory.GetUnique(player, uid)  -- 3. does this player own it?
        if not pet then return Net.fail("NotOwned") end
        Inventory.SetName(player, uid, name)          -- 4. write through the owning module at once
                                                      --    (SetName is an example: Inventory has no rename yet)
        return Net.ok()
    end,
})
```
Then run `sh tools/check.sh`. The bad-input test finds the new remote by itself and throws all 17 kinds of bad input at it. Names that players type also need Roblox's text filter before other players see them; see the code brief.

