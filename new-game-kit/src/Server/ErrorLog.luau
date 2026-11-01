--!strict
-- New Game Kit: ErrorLog (vault note 18 §7.4)
-- Install: ServerScriptService/Kit/ErrorLog (ModuleScript)
-- What it does, so one bug shows up as ONE line with a count, not 500 lines:
--   * catches every server script error (ScriptContext.Error);
--   * takes client errors through one rate-limited remote ("ErrorLog.Client");
--   * strips numbers, ids and names from each message, so the same bug groups
--     together (Roblox's own Error Report keeps only 500 different errors);
--   * counts save health: loads that failed, and why (from PlayerData.LoadFailed).
-- It prints tagged lines in Output, at most once per group per minute:
--   [ErrorLog] server x3: Kit.Shop:42: attempt to index nil with 'Price'
-- Alex can type in the Command Bar of a live server to see the top groups:
--   require(game.ServerScriptService.Kit.ErrorLog).Print()
-- The client half: KitClient calls ErrorLog.Client remote (see KitClient, "Error reports").
-- Status: covered by tools/sim.luau (offline). Check in Studio that ScriptContext.Error fires.

local Players = game:GetService("Players")

local Net = require(game:GetService("ReplicatedStorage"):WaitForChild("Kit"):WaitForChild("Net"))
local T = Net.T

local ErrorLog = {}

export type Group = { key: string, source: string, count: number, players: number, lastPrinted: number }

local MAX_GROUPS = 200 -- past this, new kinds of errors only add to "other"
local PRINT_GAP = 60 -- seconds between Output lines for the same group

local groups: { [string]: Group } = {}
local groupCount = 0
local seenPlayers: { [string]: { [number]: boolean } } = {}
local counters: { [string]: number } = {}
local started = false

-- Turns "Players.Kid42.PlayerGui.Hud:118: bad value 3.5 for 7f3a..." into
-- "Players.<name>.PlayerGui.Hud:#: bad value # for <id>" so repeats group.
function ErrorLog.Normalize(message: string): string
	local text = string.sub(tostring(message), 1, 400)
	text = string.gsub(text, "%x%x%x%x%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%x%x%x%x%x%x%x%x", "<id>")
	text = string.gsub(text, "Players%.[%w_]+", "Players.<name>")
	text = string.gsub(text, "Workspace%.[%w_]+", "Workspace.<name>")
	text = string.gsub(text, "%d+%.?%d*", "#")
	text = string.gsub(text, "%s+", " ")
	return string.sub(text, 1, 200)
end

function ErrorLog.Record(source: string, message: string, player: Player?)
	local key = source .. ": " .. ErrorLog.Normalize(message)
	local group = groups[key]
	if not group then
		if groupCount >= MAX_GROUPS then
			key = source .. ": (other)"
			group = groups[key]
		end
		if not group then
			group = { key = key, source = source, count = 0, players = 0, lastPrinted = -math.huge }
			groups[key] = group
			groupCount += 1
		end
	end
	group.count += 1
	if player then
		local seen = seenPlayers[key] or {}
		seenPlayers[key] = seen
		if not seen[player.UserId] then
			seen[player.UserId] = true
			group.players += 1
		end
	end
	local now = os.clock()
	if now - group.lastPrinted >= PRINT_GAP then
		group.lastPrinted = now
		print(`[ErrorLog] {source} x{group.count}{if group.players > 0 then ` ({group.players} players)` else ""}: {string.sub(key, #source + 3)}`)
	end
end

-- Save health and other things worth counting: ErrorLog.Count("SaveLoadFailed:locked")
function ErrorLog.Count(name: string, by: number?)
	counters[name] = (counters[name] or 0) + (by or 1)
end

function ErrorLog.Snapshot(): ({ Group }, { [string]: number })
	local list = {}
	for _, group in groups do
		table.insert(list, table.clone(group))
	end
	table.sort(list, function(a, b)
		return a.count > b.count
	end)
	return list, table.clone(counters)
end

function ErrorLog.Print(limit: number?)
	local list, counts = ErrorLog.Snapshot()
	print(`[ErrorLog] {#list} kinds of error since this server started`)
	for i = 1, math.min(#list, limit or 10) do
		local group = list[i]
		print(`[ErrorLog] #{i} x{group.count} ({group.players} players) {group.key}`)
	end
	for name, count in counts do
		print(`[ErrorLog] count {name} = {count}`)
	end
end

function ErrorLog.Start(playerData: any?)
	if started then
		return
	end
	started = true
	-- Server errors. pcall: the offline harness has no ScriptContext.
	pcall(function()
		game:GetService("ScriptContext").Error:Connect(function(message: string, trace: string, _script: Instance?)
			local where = string.match(trace or "", "^[^\n]+") or ""
			ErrorLog.Record("server", `{where} {message}`)
		end)
	end)
	-- Client errors: small, rare and checked like every other remote.
	Net.Listen("ErrorLog.Client", {
		rate = { burst = 3, perSecond = 0.05 },
		args = { T.string(300), T.optional(T.string(200)) },
		handler = function(player: Player, message: string, where: string?)
			ErrorLog.Record("client", `{where or ""} {message}`, player)
		end,
	})
	if playerData and playerData.LoadFailed then
		playerData.LoadFailed:Connect(function(_player: Player, reason: string)
			ErrorLog.Count(`SaveLoadFailed:{string.match(tostring(reason), "^[%w_]+") or "other"}`)
		end)
	end
	Players.PlayerRemoving:Connect(function(player: Player)
		for _, seen in seenPlayers do
			seen[player.UserId] = nil
		end
	end)
end

function ErrorLog._reset()
	groups, groupCount, seenPlayers, counters = {}, 0, {}, {}
end

return ErrorLog
