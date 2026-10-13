# Copy this entire prompt into your Roblox coding AI

You are the UI artist and Luau engineer implementing the approved Huzz Valley interface. I have supplied the UI kit and my existing Roblox project. Implement the design in the project; do not just propose it or generate another picture.

## 1. Source of truth and scope

Read START-HERE.md, SCREEN-SPEC.md, theme.json, Theme.luau, asset-manifest.json and reference/approved-ui.png. Inspect every individual screen crop. The selected purple-stud/periwinkle design is the visual authority. Earlier versions are superseded.

Also read the project's CLAUDE.md and relevant instructions. This task explicitly overrides older broad visual rules that conflict with the approved UI. Keep changes scoped to UI, assets and required integrations. Preserve the game world, movement, chase mechanics, working data and existing purchase systems.

The approved image is a six-screen gallery: Shop, Collection, Dances, Progression Rewards, Quests, Settings. Implement six states, not the gallery. Gallery captions and background artwork are not interface assets. The actual world remains visible behind each menu.

Target a faithful reproduction, not a reinterpretation. Do not invent a new layout, palette, ornamental frame, font hierarchy or card style because you think it is more polished.

## 2. Inspect and measure before coding

Locate existing UI controllers, data modules, remotes, player-state replication, purchase handlers, reward logic, model assets and dance assets. Reuse those systems. Identify integration points before adding code.

Measure each reference window and component relative to its own crop. Record panel bounds, header/tab height, content padding, card gaps, grid split, icon positions, text baselines, button sizes and opacity. Separate clearly visible facts from estimates.

Use one common base window/header/tab/button/card system. Define theme tokens rather than distributing magic colours throughout scripts. Use included numeric values as starting targets and adjust against actual Studio rendering.

## 3. Visual requirements

Panels: restrained translucent slate/navy. Headers: purple with a faint square-stud strip. Tabs: peach selected, navy inactive. Actions: muted periwinkle, never bright green. Completed/disabled states: slate grey. Close controls: small red squares with white X. Rarity colours: small badges only.

Use native TextLabels/TextButtons with consistent Gotham-style hierarchy. Select the supported font closest to the reference by rendering it. Do not bake text into pictures. Calibrate font weight, size, line height and baseline. Do not use TextScaled everywhere; it creates inconsistent font sizes. Use text constraints where justified.

Use thin borders, modest near-square corners, flat fills, limited shadow and no excessive bloom. Remove decorative effects that are not in the approved reference. Stud texture belongs only in headers/trims, not behind paragraphs or portraits.

Maintain 8px-based spacing where possible. Layouts must align naturally, not through per-item positional hacks. Include UI padding, constraints, grid/list layout and correct CanvasSize handling. Text and icon content must not clip.

## 4. Assets and missing prerequisites

Use included individually named transparent PNGs for ImageLabels/ImageButtons. SVGs are editable sources; raster PNGs are provided for import. Import assets and record actual resulting IDs. Do not invent rbxassetid values.

The icons are clean original reconstructions, not exact extracted generated pixels. Use them as the production icon set and retain consistent style. If an asset differs from the reference, state the difference rather than claiming exactness.

Do NOT call robux_reference_only official. Acquire/configure the official approved Robux artwork for the purchase icon. If unavailable, use a clear temporary text price such as '149 Robux' and report the missing asset. Do not silently substitute a generic ring or hexagon.

Character reference crops contain backgrounds and are visual guides only. They are not rigged models or clean cutouts. Use actual supplied Roblox character models in ViewportFrames with consistent camera, scale and lighting. If models are absent, use simple labelled blocky placeholders and provide a model checklist. Do not silently replace unavailable anime characters with emoji or unrelated avatars.

The collection preview and selected card must show the same model. Use a small square stud base matching the reference. Locked cards use truly dark silhouettes and a lock, not visible coloured faces under a dim overlay.

Dance thumbnails and preview must use actual permitted animation assets. Do not invent animation IDs. Never make every dance play the same placeholder. Missing animations are clearly unavailable until supplied.

## 5. Shared navigation and state

Use one modal manager. Only one main window is open. Opening another switches the active window; it does not stack windows, event listeners or blur effects.

Provide entry points for Shop, Index, Dances, Progression and Settings from the existing HUD/menu. These entry points use the same icon/button system. Tier filtering remains available in Index; preserve a separate tier screen only if already implemented, styled consistently.

Close/X and supported back/Escape actions return to gameplay. Opening menus does not pause multiplayer or modify the actual round timer. Restore previous HUD, camera/input state and effects on close. Respect platform/native control safe areas and mouse-lock behaviour.

Prevent menu input from also triggering dash/tag actions. Support mouse, touch and gamepad. Use activation events and focus selection suitable for those inputs. Visual icon size and comfortable input hitbox may differ.

## 6. Shop: every control has a real action

Build Passes/Cosmetics/Coins categories from actual configured products. Render the broad product rows, scrolling and action alignment shown in the reference.

Tabs filter correctly. Currency + buttons navigate to the relevant currency offers. Prices come from configured/live appropriate product data; do not hardcode reference prices as production truth.

Marketplace purchases use the project's existing purchase flow and verified ownership/receipt processing. Never create a duplicate receipt handler. Client click does not grant an item. Coin purchases are validated server-side for item, balance and eligibility.

Show loading/pending state to prevent repeat requests. Cancellation returns to idle. Errors display a concise message. OWNED state is accurate, disabled for repeat gamepass purchase, and refreshes after successful ownership updates.

Gift button opens an eligible-player picker and uses the configured gifting system. Resolve player by UserId, show recipient clearly, and confirm intended product/recipient. If no gifting backend exists, show 'Gifting unavailable' and disable it; do not make a fake working gift flow. Do not introduce trading or paid random products without an existing configuration.

## 7. Character Index: browsing, sorting and equipment

All Characters shows the configured catalogue. Owned includes only owned characters. Favourites uses saved favourites. Search matches names case-insensitively and combines with the active filters. Show useful empty results and a Clear filters action.

Tier dropdown includes the configured tier order. Provisional order if needed: Sub1, Sub3, Sub5, MTB, HTB, Stacy, True Eve. Keep tier names/data independent of art.

Sort options: Name A–Z, Name Z–A, Tier high-to-low, Tier low-to-high, Newest acquired. Apply sorting to the complete filtered data and use deterministic name/ID tie-breakers. For Newest, missing acquisition timestamps sort last; unowned characters are not 'new acquisitions'. Displayed sort must match rendered order.

Select a card to update the right details/ViewportFrame, without losing search/scroll state. Selection, equipped status and favourite status are separate. Card favourites and preview favourite operate on the same state. Avoid duplicate favourite controls within the preview panel.

Owned selected character can Equip; currently equipped can Unequip. Server validates ownership and updates saved companion ID. Locked cards cannot equip. Display how to unlock using configured real sources, not invented odds or statistics.

Collection count is unique owned characters divided by configured catalogue count. Do not count duplicates, placeholder previews or hidden development items. Update the bar when ownership changes.

## 8. Dances

Build All/Owned/Favourites filters, search and correct sort. Thumbnail pose must match selected dance. Selected dance shows the same preview in the right pane.

Play starts the appropriate preview/player animation according to the project's design. Stop cleanly ends it. Starting another stops the previous one. Distinguish local viewport preview from actually performing on the live avatar. Label Preview versus Play correctly and do not claim other players see a viewport-only animation.

For actual player emotes, respect movement/round restrictions and use the existing approved replication/Animator system. Stop or handle emotes on respawn, character removal, gameplay interruptions and modal changes. Favourite state persists where supported. Locked/unavailable entries cannot perform a paid dance without ownership.

## 9. Progression Rewards

Rewards and Quests are tabs in one window, with the shell stationary while content changes. Show tier milestones, free rewards, applicable configured cosmetic extras and XP progress.

Each reward has one state: locked, eligible to claim, pending, claimed. Eligible uses periwinkle Claim; locked/claimed use neutral states. Buttons request server claims. Server verifies level/eligibility and atomically prevents duplicate grants; receipt/claim state survives rejoining. Currency, cosmetics and dance ownership update the UI from real replicated results.

Do not invent a premium purchase, season deadline or paid skip because the visual reference contains a second row. Configure those only if the game's actual progression system supports them. Unknown bonus rewards remain clearly unavailable, not misleadingly claimable.

XP bar reflects current-level progress and configured level threshold. Reward-track milestone progress is a different metric: label and calculate separately.

## 10. Quests

Use actual server-recorded events for: steals, accumulated possession seconds, valid ankle breaks and completed rounds. Provisional reference goals are 3 steals, 30 seconds held, 5 jukes and 3 completed rounds. Configure reward amounts separately.

UI cards show goal, concise description, current/target, segmented bar, reward and claim state. Cap visual progress at target. Claim appears only for completed unclaimed tasks. Server prevents duplicate claims. Do not let the client submit arbitrary XP or fake achievements.

Do not put fake daily reset timers on permanent tasks. Preserve persistence and reset schedules as actually configured. Correct any generated reference text mistakes: the player steals the LEAD, not a ball.

## 11. Settings

Build Audio/Controls/Social tabs in the same window. Social contains inventory visibility and invite-request scope: Everyone/Friends/Nobody. Exactly one selected per row. The selection must affect actual visibility/request permission checks; visual toggles alone are not completion.

Companion effects toggle controls relevant effects, not companion ownership. Reduced Motion disables decorative animation and uses short fades/instant state changes. Audio sliders control the correct music/SFX categories. Controls settings use features actually supported by the game.

Changes apply immediately and persist through existing data storage. Show a brief unobtrusive error if saving fails. Do not add inactive settings that imply unsupported functionality.

## 12. Animation and feedback

Hover: approximately 0.10s slight lighten of fill, no layout movement. Press: 0.07s subtle scale to 0.97–0.98, restore on release. Use UIScale/wrapper so sibling layouts do not shift.

Open: 0.20s fade and scale from 0.98 to 1, optional 6px upward motion. Close: 0.14s fade then hide. No large bounce or overshoot. Animate text/image transparency independently from final panel background transparency.

Tabs: short colour transition. Search/filter changes do not replay whole-window entrance. Claim: brief check transition and data update. Optional quiet click sound uses configured asset and SFX volume; no made-up audio IDs.

Cancel superseded tweens. Rapid clicking, switching windows, opening dropdowns then closing and round transitions must not leave stuck overlays or incorrect input states. Reduced Motion removes positional/scaling transitions.

## 13. Architecture and responsiveness

Prefer existing structure. If missing, separate Theme/Assets/Components/ModalManager client modules, screen controllers, configuration and authoritative server services. Use an Assets module populated by real IDs from asset-manifest.json. Avoid duplicated constants and connections.

Use appropriate ScreenGui safe-area behaviour, containers, padding, aspect/size constraints, scrolling and responsive layout. Build selected-character views with ViewportFrame, WorldModel/camera as appropriate to assets. Keep icon aspect ratio and transparent margins.

Desktop reproduction comes first at comparable reference proportions. Verify at 1920×1080, 1366×768, landscape tablet and landscape phone. Use fewer grid columns or a separate details page on small screens. No tiny unreadable labels. Keep native movement/jump controls accessible.

## 14. Visual acceptance and functional checks

Capture actual Studio screens for all six states, compare each beside the corresponding reference crop at comparable UI size, and correct the biggest differences first: silhouette, layout, header/tab proportions, typography, colours, opacity, art and icon scale.

Do not declare 'one-to-one' without visual evidence. If rendering is unavailable, report that visual matching is unverified. Image-generated concepts are not proof of an implemented GUI.

Respect project render limits; group changes before captures. Verify every button/tab/dropdown/search field/toggle/claim, ownership updates, currency updates, cancellation/errors, scrolling, respawn, rejoining, rapid close/open and touch/gamepad input. Follow required project checks before committing.

## 15. Deliver

Deliver changed project files, actual asset-ID mapping, required model/animation/product checklist, Studio screenshots where available, and a concise report of verified behaviours and remaining gaps. Complete all implementation work possible without missing assets. Do not stop at a plan or a single proof-of-concept button.

Start with the approved shared window and Shop, calibrate against reference, then complete Index, Dances, Progression, Quests and Settings using the same components. Never silently mark a missing integration or placeholder as complete.

## V2 addendum — authoritative assets, positions and new pages

This V2 supersedes the earlier kit's rebuilt icons. Do not use those reconstructed icons as exact copies. Use the source crops in exact-pixel-icon-references/ as the visual authority. They contain exact pixels from the approved screenshot but retain backgrounds and limited resolution. Do not treat them as original transparent assets. Trace the supplied silhouette/colours/shading if clean production art is needed; disclose that tracing is reconstruction, not recovered originals. The mockup Robux symbol remains non-official: obtain the official asset or label the button “149 Robux”.

Read specifications/icon-source-rectangles.json, page-coordinates.json and PAGE-POSITIONS.md. Each page has a reference image and numbered position overlay. Implement the specified 1920×1080 target rectangles, then scale responsively. These rectangles are explicit implementation targets; reference pixel measurements are approximate bounds, not extracted hidden Roblox GUI metadata. Calibrate against the PNG rather than claiming perfect source recovery.

There are 18 page references: the approved six screens, plus Shop Cosmetics, Shop Coins, Settings Audio, Settings Controls, Tiers, Main Menu, Lobby HUD, Match HUD, Map Vote, Recruitment, Results and Gift Picker. New pages are generated extensions. Their content is illustrative and must bind to real game state.

All/Owned/Favourites and search are data states of the same collection/dance layout. Do not invent a new screen layout for them. Selected tab colours, empty state, locked state, favourite state, selected state and ownership state follow the approved shell. Search/tier/sort dropdowns open above cards and close on outside click/Escape; top toolbar stays in place.

For cosmetics: show actual configured trail/aura/pose/outfit product content, ownership and purchase status. Demonstrate effects on the live player's avatar preview, not a permanent Aiko image. Coin offers use actual developer products and real quantities. No invented IDs.

Audio controls: master/music/effects slider values apply to correct SoundGroups, preserve relative settings and persist. Unfocused muting only if supported. Controls: rebinding must check reserved/conflicting keys, allow cancel and restore defaults. Show key hints persists. Touch uses usable controls rather than keyboard prompts.

Tiers: View in Index opens with correct tier filter. Counts derive from unique owned catalogue data. Clarify the generated tier-page text: a character's tier is fixed; collecting lower-tier characters does not magically upgrade that character. Higher tier collection progress means owning characters in that tier.

Map vote: two configured map IDs, actual server votes/countdown, one current vote per player, changing vote replaces previous vote, selected card state updates. The shown timer is a real round vote deadline, not a shop scarcity timer.

Recruitment: progress persists, server verifies unlock eligibility, duplicate recruitment prevented, only 100/100 configured entries can Recruit. Keep Playing returns to gameplay and does not spend currency. Use actual selected/featured character data.

Results: rankings use authoritative possession scores. Player avatars use UserIds. Model art in the mockup is a placeholder; a player named Jade is not necessarily a collectible named Sora. Continue and close restore gameplay. Reward and progress amounts come from server.

Gift picker: selecting a player changes confirmation summary; confirm uses real configured gifting backend and purchase flow. Do not enable until backend is connected. Recipient cannot be inferred from placeholder name. Resolve by actual UserId.

Read CHARACTER-REPLACEMENT-MAP.md and character-placeholders.json. Every listed character slot has its binding/type/pose. Catalogue NPCs and live player avatars are different sources. Create one shared model catalogue and renderer. Changing the Aiko model must refresh all Aiko cards, details, recruitment and relevant reward previews. Missing model/animation assets are still prerequisites, not falsely completed features.

Do not introduce newly generated icon artwork where an approved exact source crop exists. New pages use the same existing icons; additional waveform/keyboard/hamburger controls may use clearly identified neutral native icons until final artwork is supplied. Native text, frames, sliders, progress bars and buttons must be implemented, not screenshot images. Exact crop coordinates identify reference placement only, not permission to paste background rectangles over every button.

Deliver the actual project implementation, ID/model/animation checklist, screenshots and functional verification. Do not claim the kit alone contains a ready-to-run .rbxl or every real production asset.
