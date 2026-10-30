# Notice

The server modules in `src/Server/` (except `Upgrades`, `Income`, `Pets`, `PlaytimeGifts`, `Settings`),
the shared modules `Net`, `Odds`, `Signal`, `Janitor`, `RateLimit`, `Feedback`, the config layout, the specs in `tests/`
(except `Format.spec` and `KitServices.spec`) and the files in `examples/` are adapted from
**LihFolk Systems** (`LihFolk/skills/lihfolk-systems/`), part of "LihFolk Vault V2", (c) 2026 LihFolk,
licensed under Creative Commons Attribution 4.0 International: https://creativecommons.org/licenses/by/4.0/

Changes: renamed folders and config (`Kit`, `GameConfig`, `GameSecrets`), added `Rebirth.Rebirthed`,
an in-memory Studio save mode in `PlayerData` (`studioResetsProgress`), display names in config,
and the new services, HUD, client and offline tools listed above.

`tools/preview/render.html`, `shoot.js` and the exporter in `export.luau` come from this repo's
`huzz-valley/tools/preview/`. `tools/preview/fonts/Fredoka.ttf` is under the SIL Open Font License
(`tools/preview/fonts/OFL-Fredoka.txt`).
