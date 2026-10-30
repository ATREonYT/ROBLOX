---
tags: [sector-brief, vault-corrections]
updated: 2026-10-30
---
# Vault Corrections October 2026
Back to [[00 Build Router]] · [[Sector Briefs Index]]

Older vault notes that the October 2026 research pass found outdated or wrong. **When a note below disagrees with a Sector Brief, trust the brief** (it was checked against Roblox docs on 2026-10-30). Each brief lists its sources.

## From [[Brief - 3D Assets, AI Generation and Avatars]]

- **[[I Built a Roblox Pet RPG with Claude Opus 4 MCP + Roblox Studio MCP (Full Tutorial)]]** (table row "Roblox mesh limit: about 10,000 triangles"). The engine limit is 20,000 per mesh. 10,000 is only the default cap of `generate_mesh`. Source: Roblox docs (mesh specifications); DevForum (19 Mar 2026).
- **[[Cookbook - Players and Characters]]** (about line 403) uses `GetHumanoidDescriptionFromUserId` and `ApplyDescription`. Both are deprecated: use `GetHumanoidDescriptionFromUserIdAsync` and `ApplyDescriptionAsync`. Source: Roblox docs (Players, Humanoid).
- **[[Character Select and Class Systems with Different Rigs]]** and the atlas note **[[ApplyDescription]]** recommend `ApplyDescription`. It is deprecated: use `ApplyDescriptionAsync` (or `ApplyDescriptionResetAsync`). Source: Roblox docs (Humanoid).
- **[[UGC Avatar Items and Accessories]]** gives emissive fees and advances, which are correct per the docs, but reads as if anyone can sell emissive items. Selling them was an application-only pilot from 31 Aug 2026, with a wider rollout "in the coming months" (RDC26: "Late 2026"). The "EmissiveStrength 0 to 40" limit was not confirmed in any source read today. Source: DevForum (31 Aug 2026, 11 Sep 2026).
- **[[Roblox Generative AI - Cube Mesh and Texture Generation]]** is accurate. Add: `GenerateModelAsync` starts at 10 requests per minute per experience; generated objects are not saved between sessions; weapons generate only at mild violence or higher. Source: DevForum (4 Feb 2026).
- **Code, not a vault note:** `cannon-evolution/src/server/GameServer.server.lua` line 1306 calls the deprecated `Players:CreateHumanoidModelFromDescription`. Swap it for `CreateHumanoidModelFromDescriptionAsync` inside a `pcall`. Source: Roblox docs (Players).

## From [[Brief - AI Workflow, Tooling and Testing]]

- **[[Packages and Shared Assets Across Places]]**, **[[Team Collaboration Start Here]]**, **[[Team Create Permissions and Workflows]]**. Claim: package overrides and native branching are "unconfirmed" and come only from a third-party summary. Correction: Package Overrides is an official Studio beta (DevForum, 15 Oct 2026; Studio 743+, File > Beta Features > Package Overrides; scripts overridden whole). "Branch and Merge" is in the official "RDC26: What We Announced" post (11 Sep 2026), dated early 2027.
- **[[Testing Modes - Play Run and Multi-Client]]** (and the "beta" mention in Studio Settings and Shortcuts). Claim: the Network Simulator and new Device Simulator are beta, enabled via File > Beta Features. Correction: out of beta per the DevForum Weekly Recap of 12-18 Oct 2026. The docs page still says beta, so the beta toggle may no longer be needed.
- **[[Roblox Studio MCP Server]]** section 5.4. Claim: only AlwaysOnTop BillboardGuis are missing from captures. Correction: a 14-16 Jul 2026 bug report says Play-mode captures leave out BillboardGuis, default ProximityPrompts and the top bar, and sometimes ScreenGui HUDs. No staff fix was seen.
- **[[04 AI Tools Landscape October 2026]]**. Claim: Assistant "has a built-in MCP client". Correction: Roblox's own post (21 Feb 2026) listed it as "next up". Only third-party press says it shipped, and we found no docs page, so mark it unconfirmed. Also, that note's tool list leaves out `get_studio_state` and `wait_job_finished`, which are on the docs page.
- **[[Roblox Studio Assistant]]**. Gap: it doesn't cover creator-authored Skills (9 Jul 2026), the frontmatter rules (single-line `name`/`description`, no `rbx-` prefix, account-scoped) or the built-in `rbx-*` skills.

## From [[Brief - Code, Networking and Security]]

| Note | Claim | Correction | Source |
|---|---|---|---|
| [[Engine and API Changes 2025-2026]] (section 5) | New type solver general release "late 2025; exact date Unverified" | Posted November 20, 2025 | DevForum general release post (read 2026-10-30) |
| [[Error Handling and Retries]] (line 118) | Lists `MarketplaceService` `GetProductInfo` | Use `GetProductInfoAsync` (renamed Jan 14, 2026) | Vault note [[API Renames and Deprecations 2025-2026]] |
| [[Cookbook - Players and Characters]] (lines 288, 290, 446) | Prose says `LoadCharacter` (code above it correctly uses `LoadCharacterAsync`) | Say `LoadCharacterAsync` throughout | Same as above |
| [[Server Authority and Input Migration 2026]] | Tools: "`EquipTool`/`UnequipTools` not allowed; weld a model" | Still true inside bound functions per the guide, but the July 9, 2026 release post claims "Full support for Backpacks and Tools" and warns that changing Tools during a misprediction may delete the Tool's Weld on the client. Note both. | Roblox docs guide + DevForum July 9, 2026 |
| [[Rate Limiting and Abuse Prevention]] (line 284) | "Using `tick()`: use `os.clock()`" | Fine for classic games; under Server Authority, simulation code must use `time()` | Roblox docs, Server Authority guide |

## From [[Brief - Game Design, Retention and Growth]]

- [[Engine Limits, Quotas and Defaults - Cheat Sheet]] (Publishing fee row): "Refunded after 25 highly engaged players for 60 days". Correction: the docs say the fee is refunded automatically 90 days after the game becomes eligible, or 90 days after payment if it never does. 25 HEP is the keep-eligibility bar. Source: Roblox docs, Kids and Select.
- [[Publishing an Experience]] (fee table): same refund claim ("refundable if the game keeps 25 highly engaged players for 60 days"). Same correction and source.
- [[03 What's New on Roblox - RDC 2026 and October]]: lists developer push notifications with examples "your egg hatched", "your base was raided". Correction: Roblox's RDC26 recap frames it as "alert when it's their turn" for opted-in players (turn-based and async games), timed "late 2026". General use cases are not confirmed. Source: DevForum RDC26 recap.
- [[Open Questions - Whole Vault]] (Kids/Select row): the 50,000 vs 100,000 Robux and 250 vs 500 conflict is resolved by date. 100,000 and 500 were June 2026; 500 → 250 on Aug 19, 2026; docs now say 50,000; 100 announced for November 2026. Sources: DevForum (June 16 and Aug 19, 2026), Roblox docs.

## From [[Brief - Saving, Economy and Monetization]]

- **[[DataStore Fundamentals]]**: says it is "Unverified whether `SetRateLimitForRequestType` can raise" the per-server defaults. Correction: the reference page says the defaults can be changed, and its sample sets `StandardRead` to a base of 1000 (default 60), so it can raise them. Source: DataStoreService reference, read 2026-10-30. The exact maxima (10,000 / 200, given in [[Data and Cloud Changes 2025-2026]]) were not shown on the page: unverified.
- **`LihFolk/skills/roblox-datastore-safety/SKILL.md`** lists the write base "300 vs 250" as disputed. Correction: settled at 300 since July 29, 2026 (limits page and DevForum unification post).
- **[[Ads and Rewarded Video]]**: lists `UnregisterAdOpportunity` as deprecated. Correction: the AdService reference marks only `ShowVideoAd` and `VideoAdClosed` deprecated. `UnregisterAdOpportunity` is current. Also, the guide now lives at `create.roblox.com/docs/production/promotion/rewarded-video-ads`.
- **[[Developer Products and ProcessReceipt]]**: says `PlaceIdWherePurchased` appears only in older docs. Correction: the current BindReceiptHandler docs list `PlaceIdWherePurchased` and `ReceiptType` as receipt fields.
- **Repo code (not vault): `cannon-evolution/src/server/GameServer.server.lua` ProcessReceipt** calls `save(player)` and returns `PurchaseGranted` without checking that the save succeeded. Its save is also a plain `UpdateAsync` with no session lock. This breaks the CLAUDE.md rule "answer granted only after the save". Fix by copying the huzz-valley ShopService pattern.

## From [[Brief - UI, Input and Mobile]]

| Note | Claim | Correction | Source |
|---|---|---|---|
| [[Input - UserInputService and ContextActionService]] | "`ContextActionService` is not deprecated (only its `BindActionToInputTypes` method is superseded)" | Docs now say `BindAction` and related binding methods "aren't recommended for new work and are planned for deprecation". Use the Input Action System | Roblox docs, ContextActionService (Oct 30, 2026) |
| [[Input - UserInputService and ContextActionService]], [[Responsive UI for Phone Tablet Console and PC]] | `PreferredInput` includes `MicroGamepad` | The UserInputService page lists only `Touch`, `Gamepad`, `KeyboardAndMouse`. Unverified whether `MicroGamepad` exists; don't depend on it | Roblox docs, UserInputService (Oct 30, 2026) |
| `research_notes/.../ui_implementation.md` and [[Cartoony Roblox building UI and animation]] | UIShadow: "no text shadows, no inset shadows, no UIGradients" | True for the live version. Studio beta (Oct 14, 2026) adds `Mode = Text`, `Inset`, `ShowBehindParent`, gradient shadows; can't publish with it yet | DevForum (Oct 14, 2026) |
| `research_notes/.../ui_implementation.md` | UIGradient `Type`/`Scale`/`TileMode` presented as shipped; types Linear/Radial/Conical | They are Studio beta ("Upgraded UIGradients", Sept 2, 2026); live games can't publish with them. `Elliptical` is also a type | DevForum (Sep 2, 2026); Roblox docs |
| `research_notes/.../ui_implementation.md` | Per-corner UICorner status "conflict", maybe beta | Resolved: full release June 23, 2026; the beta flag was removed | DevForum (Jun 23, 2026) |
| `business-evolution/ART.md` | "UIShadows on screen ≤ 40 (mobile)" | Roblox's only guidance is no more than 100 on screen. 40 is an unsourced house budget; label it Rule of thumb | DevForum (Jun 23, 2026) |
| [[Make Your Roblox UI Buttons SUPER Smooth in 8 Minutes!]] | Click sound on `MouseButton1Click` | Use `GuiButton.Activated` so touch and gamepad work | Vault: [[Input - UserInputService and ContextActionService]] (Docs) |
| [[03 What's New on Roblox - RDC 2026 and October]] | Lists the Upgraded UIShadow beta only | Also add the Upgraded UIGradients Studio beta (Sept 2, 2026), same no-publish rule | DevForum (Sep 2, 2026) |

## From [[Brief - VFX, Animation, Audio and Game Feel]]

| Note | Claim | Correction | Source |
|---|---|---|---|
| [[Camera Shake and Camera FX]] (section on controller rumble) | Use `HapticService` (`IsVibrationSupported`, `IsMotorSupported`) for rumble | `HapticService` is deprecated, superseded by `HapticEffect` | Roblox docs, HapticService class |
| [[Controller Support QoL]] | Snippet uses `HapticService:SetMotor` | Same: use `HapticEffect` (`Type`, `Play`, `SetWaveformKeys`) | Roblox docs |
| [[Vehicle Controls on Phone and Gamepad - Input Actions for Throttle and Steer]] | Rumble via `HapticService:SetMotor` | Same | Roblox docs |
| [[Animation Objects]] and [[Animation Editor Advanced]] (section 8) | Animation graphs are "newer and still evolving" | Full release on Jul 15, 2026, live for all games with automatic replication. Still optional | DevForum (Jul 15, 2026) |
| [[Asset Upload Automation with Open Cloud]] and [[Audio Pipeline]] | Audio quota 100/month verified, 10 unverified | Correct for Open Cloud only. The audio/assets page says 2,000 per 30 days verified and 100 unverified for normal imports. The two docs pages disagree; say which path each number is for | Roblox docs (both pages) |
| `huzz-valley/docs/notes/combine.md` (repo file, not vault) | Roblox draws at most 31 Highlights | Limit is 255 per client; disabled ones still count | Roblox docs (effects/highlighting) |

## From [[Brief - Worlds, Lighting and Performance]]

| Note | Claim | Correction | Source |
|---|---|---|---|
| Lightning Strikes and Thunder - Procedural Bolts and Sound Delay (line ~100) | PointLight `Range` "max 60 studs per Roblox docs" | The max has been 120 studs since Sep 23, 2025 | DevForum Extended Light Ranges post |
| How to make CARTOON LIGHTING in Roblox Studio (video note) | "Keep Technology as ShadowMap" | Technology is deprecated. The equivalent is `LightingStyle = Soft` + `PrioritizeLightingQuality = true` | Roblox docs (Lighting API) |
| Make Your Roblox Game Look 10x Better With Lighting (video note) | "Switch Technology to realistic/best shadows" | Use `LightingStyle = Realistic` + `PrioritizeLightingQuality = true`; for our cartoony games prefer Soft | Roblox docs (Lighting API) |
| Engine and API Changes 2025-2026; Rendering Performance; Level of Detail and Model Streaming; API Renames and Deprecations 2025-2026; AI Pitfalls - Assets and Import; SYMPTOMS | Property spelled `MeshStreamingAndImprovedLoDs` | The docs' Workspace API page lists `MeshStreamingAndImprovedLods` (lower-case "ods"). Copy the name from the Properties window before scripting against it | Roblox docs (Workspace API) |
| Mobile and Low-End Optimization | "draw distance and detail shrink" (no number) | Add: about 200 studs on low-end Android at quality 1 today; 500-stud minimum announced for late 2026 | DevForum RDC26 post |

