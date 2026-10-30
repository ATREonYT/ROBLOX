---
tags: [build-playbooks, platform-updates, rdc-2026, 2026-10]
updated: 2026-10-30
---

# 03 What's New on Roblox - RDC 2026 and October

Back to [[00 Build Router]] · Older changes: [[Roblox Changes 2025-2026]], [[Engine and API Changes 2025-2026]], [[Discovery and Monetization Changes 2025-2026]]

Everything announced at RDC 2026 (September) and in the October 2026 weekly recaps, sorted by **what it means for our games**. "Late 2026" etc. are Roblox's own timings, not promises.

Sources: [RDC26: What We Announced (DevForum)](https://devforum.roblox.com/t/rdc26-what-we-announced/4865880) · [RDC 2026 newsroom](https://about.roblox.com/newsroom/2026/09/rdc-2026-the-world-needs-more-play) · [Weekly Recap Oct 5-9](https://devforum.roblox.com/t/weekly-recap-october-5-october-9-2026/4924062) · [Weekly Recap Oct 12-18](https://devforum.roblox.com/t/weekly-recap-october-12-18-2026/4938638) · [PocketGamer.biz](https://www.pocketgamer.biz/roblox-unveils-new-play-creation-and-monetisation-tools-at-rdc-2026/) · [TNW on the agentic Assistant](https://thenextweb.com/news/oblox-ai-assistant-agentic-tools-planning-procedural-models) · [Cube / 4D generation (Feb 2026)](https://about.roblox.com/de/newsroom/2026/02/accelerating-creation-powered-roblox-cube-foundation-model). All read 2026-10-30.

## Use now (live or beta today)

| What | Status | Use it for |
|---|---|---|
| **Early testers**: invite up to 10 friends or Group members before going public | Live (Oct 2026) | Playtest every new game privately before launch day. |
| **One-question path to reach 16+** (no age-restricted content) | Live (Oct 2026) | Faster first publish for a 16+ trial launch (see [[02 Launch and Discovery Cheat Sheet]]). |
| **Highly Engaged Player counts update hourly**; HEP threshold drops **250 → 100** from November | Live / Nov 2026 | Easier to qualify for features gated on HEP. |
| **Game-specific Quick Words**: up to 3 categories × 3-10 phrases, reviewed before publish (Creator Hub > Configure > Chat) | Live | Kid-safe chat that fits the game: "Steal it!", "Help me!", "Trade?". Many players can't chat freely after the age-check rules. |
| **Discovery measurement pipeline changed Oct 12, 2026** | Live | Impressions and plays may rise and PTR may dip slightly. Don't "fix" a small PTR drop from that week. |
| **Device Simulator** out of beta, plus a network simulator | Live | Test every UI on phone sizes and on a slow network before showing the owner. |
| **Age Check API**: `Player:PromptAgeCheck()`, `Player.AgeChecked` | Live | Only if a feature needs age-checked players (chat-heavy). Not needed for our kid games. |
| **US 18+ DevEx rate** for Paid Access: $0.54 per 100 Earned Robux (was $0.38) | Live (Sept 21) | Not relevant for kid games; note for revenue maths. |
| **Collision Summaries API** `BasePart:BindToCollisionSummaries` (contact points, normals, impact speeds) | Live | Better hit sounds, impact VFX and damage from real collisions (cannonballs, thrown food, ragdolls). |
| **Text-to-speech auto-translation** (11 languages); `AudioTextToSpeech.AutoLocalize` defaults to true | Live | Free localisation of spoken tutorial lines. Set it to false where the original language matters. |
| **Package overrides** | Studio beta | Reuse one shared system package across games while each game keeps local tweaks. |
| **Upgraded UIShadow**: text, knockout, inset shadows, gradient fills | Studio beta (**can't publish while on**) | Prototype the cartoony UI look; don't ship with it until it leaves beta. |
| **Texture Generation Quality mode**: 4K PBR (colour, roughness, metal) | Beta | `/generate_texture` in Assistant with a mesh selected. Cartoony games usually want flat colour; use it for hero props. |
| **`if local` / `if const`** Luau syntax | Studio beta | Don't use in shipped code until it's live. |
| **Animation Graph State Machines + Luau Expressions** | Studio beta | Locomotion and attack states without script glue. Watch, don't ship yet. |
| **SLIM debug tints** (streaming, LOD, transcoder view modes) | Studio beta | Find why a map loads slowly on phones. |
| **Studio Assistant**: planning mode, builds from prompts with Cube, tests and self-corrects, **built-in MCP client** | Live (2026) | See [[Roblox Studio Assistant]] and [[Roblox Studio MCP Server]]. Third-party agent integration (Claude, Cursor, Codex) is on the roadmap. |
| **4D generation** (Cube): Car-5 and Body-1 schemas; players generate working objects in-game | Beta | A "generate your own car/pet" feature. In early access it showed 64% longer playtime (Wish Master). |
| **Makeup creation in-experience** (70% revenue share after recouping the advance) | Live | Only for avatar-creator games. |
| **Friends chat tab, voice typing** | Live | Nothing to build; more players can coordinate with friends. |

## Coming late 2026 (plan for it)

- **Play in Chrome from a link**, with no app install. Every TikTok/YouTube link becomes a one-tap play. Make sure the first 60 s work with a mouse and keyboard on a laptop.
- **Pre-roll video ads** while the game loads: Roblox serves them and shares revenue, with no code. Plus subscribers don't see them. Free money for kid games, but keep the loading screen short.
- **Developer push notifications** for opted-in players ("your egg hatched", "your base was raided"). A strong come-back tool; ask for opt-in after the first win, not at join.
- **Turn-based multiplayer notifications** (Studio beta in October, full release by year end).
- **Scene Generator**: a text prompt + reference image gives a scene layout to refine in Studio. Use it for first-pass map blocking, then the `roblox-cartoony-building` skill.
- **NPC Dynamic Behavior**: NPCs built from Studio prompts, versioned and reusable, including NPCs that playtest games.
- **Asset Moderation feedback** during development, with instant detail.
- **Player Support inbox** and an **Observability Platform** (session traces and logs, fixes from Studio).
- **2D games**: orthographic camera, animated image containers, sprite-sheet import.
- **New primitives**: cone, capsule, disc and rounded parts. **Rounded parts are big for the cartoony style** (soft edges without meshes).
- **Improved collision geometry** with a debug overlay.
- **Minimum draw distance 500 studs** even on low-end Android (up from 200). Maps can rely on a longer view.
- **Emissive textures** for UGC avatar items.
- **Roblox Wallet** (US, 18+): daily payouts in USD. A forum reply suggests the US moves away from DevEx in mid-2027 (Unverified).

## 2027
Branch and merge for places, test teleports in Studio, a new default movement (motion matching), silhouette-preserving layered clothing, in-game creation persistence, offline solo play (mid-2027), terrain scattering and path splines, material layering, the Roblox Card.

## Bigger picture (for game choice)
- Discovery is **age-aware**: younger players prefer shorter games, older players deeper ones. Short, readable loops suit our kid games.
- Roblox is testing ranking boosts for games that **bring new players to Roblox**, which fits shareable web links and Moments videos.
- **Moments** (short gameplay videos) is fully live in the US, and videos from a game's page show there. Make the payoff moment clip-worthy (see [[Blueprint - Plus One Evolution]]).
- In August 2026, **33% of the top 1,000 games had launched in the last 90 days**: new games can break in.
- Creators earned about **$1.7B** through DevEx in the 12 months to June 2026.
