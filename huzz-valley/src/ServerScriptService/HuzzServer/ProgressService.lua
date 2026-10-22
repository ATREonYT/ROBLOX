-- XP, levels, the reward track and quests. Gameplay reports real events with ProgressService.addStat; nothing the
-- client sends can add XP or progress. Claims are checked here and can only happen once (saved with the profile).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Progression = require(ReplicatedStorage.Shared.Config.Progression)
local Dances = require(ReplicatedStorage.Shared.Config.Dances)
local DailyRules = require(ReplicatedStorage.Shared.DailyRules)
local DataService = require(script.Parent.DataService)
local CoinShop = require(ReplicatedStorage.Shared.Config.CoinShop)
local Crates = require(ReplicatedStorage.Shared.Config.Crates)

local ProgressService = {}

-- Gameplay calls this: ProgressService.addStat(player, "Steals", 1). Unknown stats are ignored.
function ProgressService.addStat(player: Player, stat: string, amount: number)
	if not table.find(Progression.Stats, stat) or type(amount) ~= "number" or amount <= 0 then return end
	DataService.update(player, function(data)
		data.Stats[stat] = (data.Stats[stat] or 0) + amount
		data.Daily = DailyRules.add(data.Daily, stat, amount, os.time()) -- (the daily quests count the same events)
	end)
end

-- A finished daily quest (Config/DailyQuests): once each, checked against the saved progress and the server's clock.
function ProgressService.claimDaily(player: Player, key: any): (boolean, string?)
	local ok, why = false, nil
	DataService.update(player, function(data)
		local reward
		reward, why = DailyRules.claim(data.Daily, key, os.time())
		if not reward then return end
		if reward.Kind == "Coins" then data.Coins = (data.Coins or 0) + reward.Amount
		elseif reward.Kind == "Aura" then data.Aura = (data.Aura or 0) + reward.Amount
		elseif reward.Kind == "Spin" then data.Spins = (data.Spins or 0) + reward.Amount end
		ok = true
	end)
	return ok, why
end

-- A finished game's XP (Progression.gameXP). Returns the XP and the new level if one was reached; each new level
-- past the reward track pays Progression.Beyond at once.
function ProgressService.gameXP(player: Player, won: boolean, tally: { [string]: number }): (number, number?)
	local xp = Progression.gameXP(won, tally or {})
	local newLevel = nil
	DataService.update(player, function(data)
		local before = Progression.level(data.XP or 0)
		data.XP = (data.XP or 0) + xp
		local after = Progression.level(data.XP)
		if after > before then
			newLevel = after
			local last = Progression.Rewards[#Progression.Rewards].Level
			for level = before + 1, after do
				if level > last then
					data.Coins = (data.Coins or 0) + Progression.Beyond.Coins
					data.Aura = (data.Aura or 0) + Progression.Beyond.Aura
				end
			end
		end
	end)
	return xp, newLevel
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
		elseif reward.Kind == "Dance" and Dances.get(reward.Id) then
			-- (a dance you bought already: its coin price back, never nothing; release check, Oct 22)
			if data.Dances[reward.Id] then data.Coins = (data.Coins or 0) + (Dances.get(reward.Id).Coins or 0) end
			data.Dances[reward.Id] = true
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
		if quest.Chapter and Progression.currentChapter(data.QuestsClaimed) < quest.Chapter then why = "Claim a quest in the chapter before first."; return end
		if (data.Stats[quest.Stat] or 0) < quest.Target then why = "Not finished yet."; return end
		local r = quest.Reward
		if r and r.Kind == "Coins" then data.Coins = (data.Coins or 0) + r.Amount
		elseif r and r.Kind == "Aura" then data.Aura = (data.Aura or 0) + r.Amount
		elseif r and r.Kind == "Knife" then
			if data.Cosmetics[r.Id] then
				-- (yours already, from a crate: its duplicate coins instead, and the knife you wear stays; release
				-- check, Oct 22: it gave nothing and swapped your knife)
				local item = CoinShop.get(r.Id)
				data.Coins = (data.Coins or 0) + ((Crates.KnifeDuplicate :: any)[item and item.Rarity or "Common"] or 60)
			else
				data.Cosmetics[r.Id] = true
				data.Wear.Knife = r.Id -- (wear it straight away; change it in the Inventory)
			end
		end
		data.QuestsClaimed[quest.Id] = true
		data.XP += quest.XP
		ok = true
	end)
	return ok, why
end

return ProgressService
