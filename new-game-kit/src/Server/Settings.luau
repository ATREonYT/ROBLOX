--!strict
-- New Game Kit: Settings (saved comfort and performance toggles)
-- Install: ServerScriptService/Kit/Settings (ModuleScript)
--
-- Kid-safe defaults: flashes and screen shake can be turned off, and phones
-- can hide other players' effects. The client applies them; the server only
-- validates and saves. Keys and defaults come from config, values are booleans.
-- Remote: Settings.Set(key, value) -> Net.Result
-- Attributes: Setting_<key> = boolean (the client reads these)
-- Status: runs in the offline Lune harness (tools/sim.luau); not yet run in Studio.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Kit")
local Net = require(Shared:WaitForChild("Net"))
local PlayerData = require(script.Parent.PlayerData)

local T = Net.T

export type Config = { defaults: { [string]: boolean } }

local Settings = {}

local defaults: { [string]: boolean } = {}

function Settings.Get(player: Player, key: string): boolean
	local profile = PlayerData.Get(player)
	local saved = if profile then profile.Data.Settings[key] else nil
	if saved == nil then
		return defaults[key] == true
	end
	return saved
end

local function set(player: Player, key: string, value: boolean): Net.Result
	local profile = PlayerData.Get(player)
	if not profile then
		return Net.fail("NotReady")
	end
	-- Store only differences from the default, so new defaults reach old players.
	profile.Data.Settings[key] = if value == defaults[key] then nil else value
	PlayerData.MarkDirty(profile)
	player:SetAttribute(`Setting_{key}`, value)
	return Net.ok({ key = key, value = value })
end

function Settings.Init(config: Config)
	for key, value in config.defaults do
		assert(string.match(key, "^[%w_]+$") and #key <= 32, `Settings: bad key '{key}'`)
		assert(type(value) == "boolean", `Settings {key}: default must be a boolean`)
		defaults[key] = value
	end
	PlayerData.RegisterSlice("Settings", function()
		return {}
	end)
	Net.Handle("Settings.Set", {
		rate = { burst = 10, perSecond = 3 },
		args = { T.key(defaults), T.boolean },
		handler = set,
	})
	PlayerData.Loaded:Connect(function(player: Player)
		for key in defaults do
			player:SetAttribute(`Setting_{key}`, Settings.Get(player, key))
		end
	end)
end

return Settings
