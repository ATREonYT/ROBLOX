# Oct 22: release prep

Owner, 05:42: "Can you now start prepping the game for release, do back test on desync, on the game logic, look at it
from different perspectives, test it from all the ways, check if everything works, in general check if the game will
hold up when people are playing, and find any bugs"

| Job | How | Status |
| --- | --- | --- |
| Desync and server trust | audit every remote, leave / join / respawn mid-round, what each screen sees | done |
| Round logic | full rounds at 1, 2, 8, max players, every end, abilities together, the sim looped | done |
| Saves, shop, purchases, load | ProfileStore, receipts, coin races, old saves, leaks per player, per-frame cost | done |
| Fix what is confirmed | one fix per bug, with a check that failed before | done (notes: round.md, economy.md) |
| Report | short list for the owner: fixed, still needs Studio | done |
