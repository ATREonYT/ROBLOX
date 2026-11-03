# Starting a new Roblox game with Claude

These are the rule files I built up while making Huzz Valley. They hold what worked, what went wrong, and how you like to work.

## What each file is
- **CLAUDE.md**: the main rules. Claude reads it at the start of every session. It covers how you work, what "done" means, kid-safe rules, purchases, and Roblox gotchas.
- **GAME-FEEL.md**: how to make a game feel good: the round loop, cinematic moments, controls, and small UI.
- **VFX-ITEMS.md**: how to make knife, pet and skin effects look as good as the reference.
- **ROJO-SETUP.md**: how to connect Studio to the code with Rojo on your Mac.
- **EXAMPLE-game-CLAUDE.md**: Huzz Valley's own file, as an example of a game file. Don't copy it as it is. Your new game gets its own short version.

## How to use them
1. Put CLAUDE.md, GAME-FEEL.md, VFX-ITEMS.md and ROJO-SETUP.md at the top of your repo. Your ROBLOX repo already uses this layout.
2. Make a folder for the new game (for example `my-new-game/`) with its own `CLAUDE.md`. Its first lines should say what the game is, the reference game it copies, and the branch it lives on.
3. In CLAUDE.md, under "Which game is where", add a line for the new game.
4. In your first message to Claude, name the reference game, send a video or screenshots of it, and ask for the "golden slice" first: the smallest piece that shows the look and feel.

Huzz-only parts (girls, the Secret cutscene, the Combine machine) live only in the example file. Everything in the other four files applies to any game.
