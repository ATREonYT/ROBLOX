--!strict
-- One player's private world prompt (a pickup only they were sent to, their stash's station). Uses the crime
-- thread's client-made prompts when CrimeService is there (only that player sees it, the server checks every
-- press and the hold time); otherwise a server ProximityPrompt that ignores everyone else.
--   PlayerPrompt.set(player, id, { pos, action, object, hold, range?, fn(player) }) ; PlayerPrompt.clear(player, id)
local PlayerPrompt = {}

local Crime: any = nil
local function crime(): any
	if Crime == nil then
		local m = script.Parent:FindFirstChild("CrimeService")
		local ok, mod = false, nil
		if m then
			ok, mod = pcall(require, m)
		end
		Crime = if ok and type(mod) == "table" and mod.setPlayerPrompt then mod else false
	end
	return Crime or nil
end

local fallback: { [Player]: { [string]: Instance } } = {}
local ids: { [Player]: { [string]: boolean } } = {}

function PlayerPrompt.set(player: Player, id: string, o: { [string]: any })
	PlayerPrompt.clear(player, id)
	ids[player] = ids[player] or {}
	ids[player][id] = true
	local C = crime()
	if C then
		C.setPlayerPrompt(player, {
			id = id,
			pos = o.pos,
			action = o.action,
			object = o.object,
			hold = o.hold or 0,
			range = o.range or 10,
			fn = function(p: Player)
				o.fn(p)
			end,
		})
		return
	end
	local a = Instance.new("Part")
	a.Name = "MTL_Prompt_" .. id
	a.Size = Vector3.one
	a.Transparency = 1
	a.CanCollide = false
	a.CanQuery = false
	a.Anchored = true
	a.Position = o.pos
	local pp = Instance.new("ProximityPrompt")
	pp.ActionText = o.action
	pp.ObjectText = o.object or ""
	pp.HoldDuration = o.hold or 0
	pp.MaxActivationDistance = o.range or 10
	pp.RequiresLineOfSight = false
	pp:SetAttribute("MTL_Owner", player.UserId)
	pp.Parent = a
	pp.Triggered:Connect(function(who)
		if who == player then
			o.fn(player)
		end
	end)
	local root = workspace:FindFirstChild("MTL_Jobs")
	if not root then
		root = Instance.new("Folder")
		root.Name = "MTL_Jobs"
		root.Parent = workspace
	end
	a.Parent = root
	fallback[player] = fallback[player] or {}
	fallback[player][id] = a
end

function PlayerPrompt.clear(player: Player, id: string)
	if ids[player] then
		ids[player][id] = nil
	end
	local C = crime()
	if C then
		C.clearPlayerPrompt(player, id)
	end
	local t = fallback[player]
	if t and t[id] then
		t[id]:Destroy()
		t[id] = nil
	end
end

function PlayerPrompt.clearAll(player: Player)
	for id in table.clone(ids[player] or {}) do
		PlayerPrompt.clear(player, id)
	end
	ids[player] = nil
	fallback[player] = nil
end

return PlayerPrompt
