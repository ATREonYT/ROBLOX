-- XP, levels, the reward track and quests. Gameplay reports real events with ProgressService.addStat; nothing the
-- client sends can add XP or progress. Claims are checked here and can only happen once (saved with the profile).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Progression = require(ReplicatedStorage.Shared.Config.Progression)
local Dances = require(ReplicatedStorage.Shared.Config.Dances)
local DataService = require(script.Parent.DataService)

local ProgressService = {}

-- Gameplay calls this: ProgressService.addStat(player, "Steals", 1). Unknown stats are ignored.
function ProgressService.addStat(player: Player, stat: string, amount: number)
	if not table.find(Progression.Stats, stat) or type(amount) ~= "number" or amount <= 0 then return end
	DataService.update(player, function(data) data.Stats[stat] = (data.Stats[stat] or 0) + amount end)
end

function ProgressService.claimReward(player: Player, level: any): (boolean, string?)
	local reward = type(level) == "number" and Progression.reward(level)
	if not reward then return false, "Unknown reward." end
	if reward.Unavailable then return false, reward.Name .. " is coming soon." end
	local ok, why = false, nil
	DataService.update(player, function(data)
		local key = tostring(reward.Level)
		if data.Claimed[key] then why = "Already claimed."; return end
		if Progression.level(data.XP) < reward.Level then why = "Reach level " .. reward.Level .. " first."; return end
		if reward.Kind == "Coins" then data.Coins += reward.Amount
		elseif reward.Kind == "Aura" then data.Aura += reward.Amount
		elseif reward.Kind == "Dance" and Dances.get(reward.Id) then data.Dances[reward.Id] = true
		else why = "That reward can't be given yet."; return end
		data.Claimed[key] = true
		ok = true
	end)
	return ok, why
end

function ProgressService.claimQuest(player: Player, id: any): (boolean, string?)
	local quest = type(id) == "string" and Progression.quest(id)
	if not quest then return false, "Unknown quest." end
	local ok, why = false, nil
	DataService.update(player, function(data)
		if data.QuestsClaimed[quest.Id] then why = "Already claimed."; return end
		if (data.Stats[quest.Stat] or 0) < quest.Target then why = "Not finished yet."; return end
		data.QuestsClaimed[quest.Id] = true
		data.XP += quest.XP
		ok = true
	end)
	return ok, why
end

return ProgressService
