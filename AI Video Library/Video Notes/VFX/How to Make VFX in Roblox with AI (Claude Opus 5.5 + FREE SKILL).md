---
tags: [roblox, video-notes, vfx]
source: https://www.youtube.com/watch?v=-Ax_uc0x-UE
creator: "fwjelaa"
video_id: "-Ax_uc0x-UE"
---
# How to Make VFX in Roblox with AI (Claude Opus 5.5 + FREE SKILL)

Back to [[00 Start Here]] · [[00 Video Notes Index]]

## TL;DR
Generate a reference image of the VFX (an aura) in ChatGPT, then give it to Claude together with a downloadable MD skill file and tell Claude which VFX tools you actually have. Claude builds the aura in Studio via MCP. Always supply references and demand constant movement.

## Tools and setup
- ChatGPT (image generation for the reference; the creator no longer has Plus and mostly uses Claude now).
- Claude (with Roblox Studio MCP enabled), and Blender is mentioned as an alternative route.
- The free skill/MD file is distributed on the creator's Discord (link in the video description); the file is the "skill".
- Studio VFX tools named: VFX Studio and VFX Editor (preferred: Studio). VFX Forge is NOT used.
- Astra is mentioned as a good alternative method, skipped in the video.
- Plain Studio particle effects were skipped ("looks terrible").

## Step-by-step
1. [00:00] Pick a method: Astra, Blender, design, or plain Studio. The creator picks the Blender-style middle ground with a reference-image workflow and skips plain Studio particles.
2. [01:00] In ChatGPT, ask for an aura for your Roblox game: very detailed, cool, nice. Choose the theme yourself, but make sure Claude can reproduce it and avoid details Claude cannot see.
3. [02:06] Add reference images to ChatGPT whenever you are recreating something; otherwise state the general mood.
4. [03:07] Save the chosen image (copy to desktop). Close ChatGPT.
5. [03:30] In Claude, attach the reference image and the MD skill file from the Discord.
6. [04:07] Tell Claude which tools you have and do not have (see prompts) so it does not talk nonsense.
7. [05:08] Check the Studio MCP is enabled; Claude switches to your place and starts checking the VFX Studio options.
8. [08:11] After about 14 minutes Claude has made an aura with a rig. While it polishes, tell it to attach the aura to your character so pressing Play shows it.
9. [09:11] Notice nothing moves in its test; immediately tell Claude the aura must move constantly.
10. [10:11] Compare the result to the reference in a test: crystals in place, a star on top going straight up and down, small side stars, a crescent moon, floor animation.
11. [11:11] In-game check: there are quality levels (the creator toggles levels one and two with keys); ask for a style change (watercolor, realistic) by writing it explicitly.

## Exact settings and values
| Setting | Value | Notes |
|---|---|---|
| Generation time | about 14 minutes | Claude's first aura pass |
| Quality levels | up to 4th level / 3rd quality toggles | Aura has toggleable quality levels |
| Style | none specified | Result defaults to a simple style unless you request one |

Most other values were not stated.

## Prompts and skills used
- ChatGPT: "Yo, I need an aura for my Roblox game. I want it to look very detailed, cool, and nice." (theme chosen by you)
- To Claude (with reference image + MD file): "I don't have VFX Forge. I have other VFX tools. Like VFX Studio and VFX Editor. Please use Studio or an editor, preferably Studio, because it looks better, for creating a reference image."
- Mid-run correction: "The aura has to be moving all the time. There is no reason why the aura should not move... Everything has to move."
- Extra request: add the aura to my character before finishing so it shows when I press Play.
- Skill: free MD file on the creator's Discord (link in description). Tools: VFX Studio, VFX Editor.

## Gotchas and fixes
- Without references Claude gives mediocre output: always provide an image.
- If Claude assumes tools you lack (VFX Forge), tell it exactly what you have.
- Do not include details in the reference that Claude cannot reproduce or see.
- First aura did not animate; fix by interrupting with a prompt demanding constant motion before it finishes.
- Style defaults to simple; specify style (watery, realistic) if you want it.
- Plain Studio particle work alone looks poor in his opinion.

## Use it in our games
- Generate a reference image first for any aura or rarity glow, then give it plus a skill file to Claude (inferred for our pet/brainrot rarity effects).
- Explicitly state "everything must move" in VFX prompts so auras are never static.
- Use the quality levels idea for tiered auras, one per rarity or rebirth tier (inferred).
- Tell Claude which VFX tools and the repo's roblox-vfx skill are available so it uses them instead of inventing (inferred).

<!-- related:start -->
## Related

- Hubs: [[00 Video Notes Index]] · [[00 Build Router]] · [[05 VFX]]
- More in VFX: [[Claude MCP + Codex Help me create Roblox Skill Cutscene in Minutes Roblox Studio MCP]] · [[Claude Opus 4.7 Just Built My Roblox VFX… (Ice Slash Effect Tutorial)]] · [[How I Made Anime Dragon Skill in Roblox Studio Using Claude MCP]]
<!-- related:end -->
