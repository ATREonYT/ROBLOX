# 🔌 Rojo Setup — sync this repo straight into Roblox Studio

Rojo makes the scripts in this repo flow into Studio automatically, so
updates never need copy-pasting again. It has three pieces:

1. **This repo on your computer** (the files)
2. **The Rojo program** (`rojo.exe`) — a tiny server that runs on YOUR PC.
   When it says `listening on 127.0.0.1:34872`, that IS the "localhost":
   a private connection inside your own computer, nothing internet-facing.
3. **The Rojo plugin inside Studio** — connects to that localhost and
   creates/updates the scripts in your place.

Each game folder already contains its map file (`default.project.json`)
telling Rojo which script goes into which Studio service. You don't need
to touch those.

## One-time setup (Windows)

1. **Get the repo onto your PC.** Easiest long-term: install
   [GitHub Desktop](https://desktop.github.com), sign in, **Clone** this
   repository. (Quick-and-dirty alternative: the green **Code → Download
   ZIP** button on GitHub, then extract — but then future updates mean
   re-downloading, while GitHub Desktop updates with one click.)
2. **Get Rojo.** Download the latest `rojo-*-windows.zip` from the
   official releases page: <https://github.com/rojo-rbx/rojo/releases> —
   extract `rojo.exe` and put a copy inside the game folder you want to
   sync (e.g. `plus-one-speed/`).
   ⚠️ Only download Rojo from that official page. Never from a re-upload.
3. **Install the Rojo plugin in Studio.** Official page:
   <https://rojo.space> → Installation → "Roblox Studio plugin" (it links
   the official plugin on Roblox's Creator Store — click Install).

## Every time you work

1. Open the game folder, click the address bar, type `cmd`, press Enter
   (this opens a terminal already pointed at the folder).
2. Run:
   ```
   rojo.exe serve
   ```
   Leave that window open — the `listening on 127.0.0.1:34872` line means
   it's working.
3. Open your place in Roblox Studio → **Plugins** tab → **Rojo** →
   **Connect** (the default address is already `localhost:34872`).
4. The scripts appear/update in ServerScriptService (and
   StarterPlayerScripts for the keyboard game). While connected, any file
   change on disk syncs into Studio **live**.

## Getting Claude's updates

When new changes are pushed to this repo:

1. Open GitHub Desktop → click **Pull origin** (one click).
2. If `rojo serve` is running and Studio is connected, the scripts update
   in Studio instantly. Otherwise reconnect and they update on connect.
3. Press Play. That's the whole loop.

## Notes

- Rojo only manages the scripts listed in `default.project.json` — your
  hand-built models, parts, and everything else in the place are left
  alone.
- One game per Studio place: run `rojo serve` from the folder of the game
  that place is for.
- If Studio's Connect fails, the `rojo serve` window is usually closed —
  start it again.
