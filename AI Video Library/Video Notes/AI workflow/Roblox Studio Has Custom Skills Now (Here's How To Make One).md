---
tags: [roblox, video-notes, ai-workflow]
source: https://www.youtube.com/watch?v=5dY9z4gHIdY
creator: "ScriptedOcean"
video_id: "5dY9z4gHIdY"
---
# Roblox Studio Has Custom Skills Now (Here's How To Make One)

Back to [[00 Start Here]] · [[00 Video Notes Index]]

## TL;DR
Roblox Studio's AI Assistant now supports reusable custom skills (also usable outside Studio). Two ways to create one: prompt the Assistant to write it, or add one manually and write the body yourself. If the Assistant doesn't use the skill automatically, ask it by name.

## Tools and setup
- Roblox Studio AI Assistant (three-dots menu, Manage skills).
- Example skill: "Roblox lead systems architect" (name the creator invented).

## Step-by-step
1. [00:00] Open Studio, a new or existing experience, open the AI Assistant.
2. [00:00] Method 1 (prompting): three dots, Manage skills, Create new. Paste a prompt: first the skill name, then how it should function, optionally the format (optional; the default model handles it).
3. [01:01] Send; reopen Manage skills to verify the skill was created.
4. [01:01] Edit: select skill, Open, turn the Editor toggle on, change details. Delete: select skill and press Delete.
5. [02:01] Method 2 (manual, more control over the first draft): three dots, Manage skills, Add; type the name; write a description; Create; Open; Editor mode on; write what the skill does (the agent reads this when it invokes the skill); Save; close with the X by the name.
6. [03:03] Compare: disable the skill and prompt "can you make the tool in starter pack damage the clone of my Roblox avatar? Play a sparkling effect for everyone and track the amount of times I killed my clone in leaderstats." Run the same in the skill-enabled experience.
7. [05:08] If the skill isn't invoked, ask: "can you use the <skill name> to update the scripts."

## Exact settings and values
None stated in the video.

## Prompts and skills used
- Test prompt: "Can you make the tool in StarterPack damage the clone of my Roblox avatar? Play a sparkling effect for everyone and track the amount of times I killed my clone in leaderstats."
- Re-invoke prompt: "Can you use the [skill name] to update the scripts?"
- Skill: "Roblox lead systems architect skill" (name, description, body). Skills also work in other AI tools.

## Gotchas and fixes
- The Assistant did not automatically invoke the custom skill; fix by explicitly asking it to use the skill by name.
- Method 1 is faster and fixable later; Method 2 gives control over the first draft.
- The video cuts before showing the comparison result in detail.

## Use it in our games
- Make a skill with our conventions (config tables, remote naming, cartoony UI rules, DataStore patterns) so the Studio Assistant follows them (inferred).
- Write a "simulator economy" skill describing +1 per second, rebirth scaling, and cost curves (inferred).
- Always invoke the skill by name in the prompt to be sure it loads.
- Keep one skill per area (UI, economy, steal mechanics) so each is small (inferred).

<!-- related:start -->
## Related

- Hubs: [[00 Video Notes Index]] · [[00 Build Router]] · [[01 Setup & Workflow]] · [[02 Full Game Builds]]
- Playbooks: [[Blueprint - Plus One Evolution]]
- More in AI workflow: [[Building Viral Roblox Game w AI (pretty easy)]] · [[Building a Viral Roblox Game w ONLY AI]] · [[Can AI Make an Entire Roblox Creature Capture Game (3D Models, Map, Code)]] · [[Can AI Make an Entire Roblox Incremental Game (Art, 3D Models, Code)]] · [[How Big Studios Develop on Roblox]] · [[How to Make a Roblox Game With AI (Claude Opus 5.5 Full Tutorial)]] · [[How to make Roblox Games Using Claude]] · [[Superbullet × Claude Opus 5.5 Is INSANE for Roblox Development]]
<!-- related:end -->
