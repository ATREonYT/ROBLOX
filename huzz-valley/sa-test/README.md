# Server Authority test place

A separate place to try Roblox's Server Authority (the server is the only truth; your screen runs the same code one
step ahead and is rewound when it guessed wrong) before touching the real game. Owner's call, Oct 21:
"Tune now, Server Authority test".

- `src/HussSim.luau`: the shared simulation (the 1 s build-up, the huss, the dive, the catch), run by both
  `src/SATestServer.server.luau` and `src/SATestClient.client.luau`. Numbers come from the game's Config/Round and Run.
- `build.luau`: makes `huzz-valley/places/ServerAuthorityTest.rbxl` (run from the repo root with Lune).
- `check.luau`: offline checks (distances, cooldown, catch window, replay gives the same answer, the silent-failure rules).

How to try it (Studio only):
1. Open `places/ServerAuthorityTest.rbxl`. Check Workspace > AuthorityMode says Server.
2. Test tab > Clients and Servers, 2 players, Start. Optional: Network Simulation (Studio settings) at 100-200 ms.
3. Run (WASD), Space = huss, E or click = dive. A caught player glows red for 2 s.
4. Compare the two windows on the posts. Cmd+Shift+F6 shows Roblox's own Server Authority numbers.
5. Send the `[SATest]` lines from Output.
