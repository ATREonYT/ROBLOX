# Secret cutscene: beat sheet

The Secret girl's arrival (`Shared/SecretReveal` = timing and camera, `Gameplay/SecretReveal` = effects). Owner,
Oct 19: "work on the secret animation a bit more, make it more detailed, especially the beams, and then the
animation, make the duration of it logical". Since Oct 19 it is **10.0 s** (was 14.5 s). Times below are seconds
from `RevealAt` (the server stamps it on the showcase after streaming her spot in). They are the numbers in
`Shared/SecretReveal` (also listed there as `SecretReveal.BEATS`); change them there, then here.

## Why 10 seconds

- Everyone in the server watches it, between rounds, and nobody can skip it. Every second is a second the whole
  lobby waits.
- Roughly how long other reveals take (from memory of playing them, not measured): Roblox egg hatches and summons
  3 to 6 s, the big gacha games' top-rarity reveals about 7 to 10 s before the character card (and those can be
  skipped). The owner's reference video is about 14 s, but it is a showcase clip, not a reveal people wait through.
- 14.5 s dragged: the old film had about 4 s between the landing and the speed streaks where almost nothing
  happened on a dark screen.
- Under about 9 s the beams lose their build (few, then many, then converging needs about 0.5 to 0.8 s a step) and
  her name is up too briefly to read (kids read slowly: it stays up 1.8 s).
- So: 3.4 s of build to the burst, about 4.2 s with her (landing, name, push into her face), about 1.9 s of finale
  and her rise, and the 0.5 s hand-back.

## The beats (time → event)

Sound column: the cue the code plays today (`Sfx.play`); the other rows are suggestions for where a sound fits.

| Time (s) | Part | Event | Sound today |
|---|---|---|---|
| 0.00 | anticipation | Cut to her spot; night falls on your screen (0.15 s), motes and crystals drift, haze in the sky | |
| 0.25 | anticipation | A small orb of light appears; sparks rush into it, four lights circle it | `secret_riser` |
| 0.45 | anticipation | A little starburst on the orb | |
| 0.55 / 0.68 / 0.80 | build | Three hair-thin light threads fall from the sky (few) | |
| 0.95 | build | **Beam A strikes** (camera bump, sparks shower) | |
| 1.30 / 1.45 / 1.60 / 1.75 | build | Four red-pink slashes cross the screen | |
| 1.35 to 2.05 | build | Glowing rungs climb beam A | |
| 1.70 | build | **Beam B strikes**: twin beams | |
| 2.10 to 2.50 | build | Six more beams strike in a ring, one every 0.08 s (many) | |
| 2.50 | build | Two big glowing eyes open between the twins | |
| 2.85 to 3.30 | converge | Every beam swings its foot into the eyes' point, pinching thin, the strands winding faster | |
| 3.30 | hit-stop | Everything nearly freezes (0.12 s) | (silence) |
| 3.42 | **BURST** | Manga frame (0.09 s), shockwave dome + ring on the floor + ring facing you, rays, sparkles; she appears in white | `secret_impact` |
| 3.80 | land | She lands: ring, dust, smoke; the magic circle lights up under her | `secret_land` |
| 4.00 / 4.30 / 4.60 | reveal | Crescent slashes swirl round her | |
| 4.50 | reveal | **Her NAME** on screen (SECRET and 7 stars over it, a line draws out under it) and a star flare behind her head; the message line says "SECRET: name!" | |
| 5.10 to 6.35 | reveal | Speed streaks rush past while the camera pushes into her face | |
| 6.15 | reveal | Eye glint in the close-up | |
| 6.30 | reveal | Name card gone | |
| 6.40 | finale | **The one cut** (under a soft bloom swell) to wide; red streak lines sweep across (6.45 to 6.85) | |
| 6.55 | finale | Butterfly swarm bursts out round her | |
| 6.85 to 7.60 | finale | A pink star flare grows on her, crackling | |
| 7.60 | **LAST BURST** | Rays, a ring facing you, a ring on the floor, pink cloud, shards | `secret_impact` |
| 7.75 | rise | She floats up to her place over the map (her name over her head comes back at 8.05) | |
| 8.30 to 9.50 | rise | The sun comes back up, the night haze fades | |
| 9.50 | hand-back | Dip to black (0.2 s) | |
| ~9.70 | hand-back | Under black: the camera goes back to you; black lifts (0.3 s) | |
| 10.00 | end | The game goes on | |

Flashes (kid-safe, at most one a second): soft brightness pulses only at 3.42, 6.40 (weaker) and 7.60, measured on
the film with `tools/preview/flash_check.py`.

## The beams (the owner's focus)

`SecretReveal.PILLARS` lists all 11 (where, how tall, how wide, lean, bend, strands, filament, colour) and
`SecretReveal.LAYERS` the five layers of each. Each beam is a stack of plain Beams (no pictures needed):

- outer haze, glow, inner glow, core and a white-hot middle, each narrower and less see-through, so the flat strips
  add up to a soft falloff; the outer three scroll the owner's beam-glow picture at different speeds once uploaded;
- three bright pulses climbing the glow layers (their Transparency is rebuilt every frame), faster as they converge;
- strands winding round the big ones (a helix of short curved Beams), dimmer where they pass behind;
- a jagged white filament on the twins that re-bends every 0.11 s and glides there (a shimmer, never a strobe);
- sparks shedding off, a pool of light on the floor, a spark shower where each strikes; the beams light the floor;
- a slow width breath (5%), a lean to the right like the reference, and a bend.

## Against the owner's reference (`design/vfx/ref3`, Oct 17)

What we kept from it, compressed: the starburst, the striking beam, the ladder, the twin beams, the eyes, the
impact frame, the calm wide shot, the crescents, the speed-streak push into the face, the swell, the red lines, the
butterflies, the growing flare, the second burst, back to night. What we cut: its over-the-shoulder shot and its
second star flare (5.7 to 7.0 s), which were the slowest part. What we added: her name, the magic circle, the
shockwaves, the converging beams. Side by side: `docs/previews/secret-vs-ref3.jpg` (beat by beat) and
`secret-vs-ref3.mp4` (the reference re-timed to our beats).

What Roblox can't do like the reference: chromatic aberration, real volumetric beams, motion blur, a full-screen
white flash (not kid-safe anyway).
