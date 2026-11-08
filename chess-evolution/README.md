# +1 Chess Evolution

The live game is built in the owner's Studio place (placeId 116055826555583). This folder keeps
copies of scripts made in cloud sessions so they are not lost.

- `src/StarterPlayer/StarterPlayerScripts/GlassSmash.client.luau`: the win moment from reference
  clip 1 (Nov 8). The beaten rival ragdolls backwards through the stage's glass gate, the glass
  shatters, and you hear a whoosh, an "oof", the smash and an "ouch". Client only, uses Roblox's
  built-in sounds, listens to the `BattleEnd` push. Other client code can fire
  `ReplicatedStorage.ChessFx.GlassSmash` with a stage id (for auto wins).
