---
tags: [build-playbooks, owner, taste, rules, lessons]
updated: 2026-10-30
---

# 09 Owner Taste Rules

Back to [[00 Build Router]] · Process: [[08 Few-Prompt Game Building with AI]]

**Load this for every UI, sound, look or feel job.** These are the owner's (Alex's) calls, collected from their messages and the commit history up to Oct 30, 2026 (Cannon Evolution, Hood, Huzz Valley). Building to them up front saves a correction round each.

**Add a line here every time they correct something.**

## Direction
- **"Feel and operate like the hit, but don't make it like it."** Copy the reference's loop, flow, timing and feel one to one. Use our own look, theme, names and art (Oct 30, Cannon Evolution vs Stone Skipping).
- **Borrow every well-made idea from the competition and do it well** (Oct 30). Use the Borrow List: [[07 Borrow List - Game by Game]].
- **Quality bar: release-ready, as polished as the front page, and beat it** (Oct 30). They judge by eye, against the reference, side by side.
- **"Use the vault and make it crazy"** (Oct 30): go big on juice and effects, within the kid-safe rules.
- **Mobile matters:** they ask whether it loads fast on phones. Keep part counts low (the Cannon map went from 9,162 to 187 pieces) and test the phone view.

## UI
- **Small, premium buttons.** They asked for smaller ones twice on Huzz Valley, and the Cannon UI went 18% smaller (phones keep near full size). Start small.
- **Their mockups and UI kits are the authority** (`<game>/design/`). Lay menus out like their pictures; use their kit colours and icons as they are.
- **No emoji in the final UI**, only their icons. Emoji are a placeholder until the icon IDs are uploaded.
- **No red error box on screen**: errors go to Output on tagged lines (Oct 19).
- **UI lives in StarterGui as real parts they can edit** (repo rule 11).
- **One tiled texture beats many small parts** (header studs).
- **See-through panels with floating titles and studded flat buttons**, like Stone Skipping's (Oct 30 style pass).

## Sound
- **Smooth, "satisfying", ASMR-like.** No harsh clicks.
- **Nothing long:** button sounds 0.1–0.3 s; rewards, rebirth, hatch and unlock done by 0.6–0.8 s; splash = only its first second.
- Silent beats a harsh stand-in. Leave the slot empty until a good sound exists.
- A warm high cut and a gentle compressor on every sound (Sfx module).

## Look
- **Blocky, studded, cartoony** (classic studs on the lobby, booths and cannons).
- **Booths copied from their pictures:** no lamp posts, neon only where their picture has it.
- **Glow that grows with tier**, but bloom nearly off. No floating orbs (they turned them off).
- **Water:** real ripple rings, not flat neon discs; turquoise water.
- **Tutorial arrows like the reference:** a chain of white notched arrowheads with a thin dark outline, flat to the screen, floating straight to the target, evenly spaced.
- **Area walls show only while you fly**, so their names don't stack in the lobby.

## Pace and progression
- **The reference pace is the target.** Its first rebirth comes at ~85 s; Cannon's took ~7 min. Hood's World 1 was set to 25–30 minutes on their call (Oct 27).
- **"Coming soon" instead of fake features:** Auto Collect shows Coming soon until it's real.

## Working with them
- They write short messages and change direction. For a real direction change, ask ONE multiple-choice question; otherwise act, then report.
- They test a ready-made place file, or Studio through the MCP when their Mac is on. Tell them exactly the 2–3 clicks only they can do (Import 3D, upload icons, publish IDs).
- Plain words, no jargon, one thing per change, and a picture when there's something to judge.
