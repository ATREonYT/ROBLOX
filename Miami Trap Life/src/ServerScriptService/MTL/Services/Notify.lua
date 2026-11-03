--!strict
-- Server -> client messages for the HUD. kinds: "toast" (small, stacks), "refuse" (why an action was refused),
-- "objective" (the one top line),
-- "banner" (big centre words: LEVEL UP, MISSION COMPLETE; use rarely).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Net = require(ReplicatedStorage.MTL.Net)

local Notify = {}

function Notify.toast(player: Player, text: string, color: Color3?)
	Net.get("Notify"):FireClient(player, { kind = "toast", text = text, color = color })
end

-- "Why can't I?": a clear reason when an action is refused ("Need $120 more", "Robbery cooldown 2:14").
-- Shows as a red-edged toast with a small shake and the Error sound. Use it for EVERY refusal a player can hit.
function Notify.refuse(player: Player, reason: string)
	Net.get("Notify"):FireClient(player, { kind = "refuse", text = reason })
end

function Notify.objective(player: Player, text: string)
	player:SetAttribute("MTL_Objective", text) -- also kept as an attribute so a respawned HUD can read it
	Net.get("Notify"):FireClient(player, { kind = "objective", text = text })
end

function Notify.banner(player: Player, text: string, sub: string?, color: Color3?)
	Net.get("Notify"):FireClient(player, { kind = "banner", text = text, sub = sub, color = color })
end

return Notify
