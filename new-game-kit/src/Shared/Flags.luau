--!strict
-- New Game Kit: Flags (kill switches; vault note 18 §5)
-- Install: ReplicatedStorage/Kit/Flags (ModuleScript)
-- Turn a feature off on live servers without publishing a fix:
--   if Flags.On("RareReveal") then RareReveal.Play(...) end
-- Where the answer comes from, first match wins:
--   1. an attribute on ReplicatedStorage named "Flag_<Name>" (true/false). The server can set it at
--      runtime (e.g. from a ConfigService value, an admin command or the Command Bar in a live server),
--      and it replicates to every client.
--   2. Config.Flags[<Name>] in GameConfig (the default shipped with the build).
--   3. true (a feature with no flag is on).
-- Flags.Set(name, value) is for the server only. Flags.Changed(name, fn) re-runs fn when it flips.
-- Status: covered by tests/Flags.spec.luau (offline).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Flags = {}

local defaults: { [string]: boolean } = {}

function Flags.SetDefaults(map: { [string]: boolean }?)
	defaults = map or {}
end

do
	local ok, config = pcall(function()
		local module = ReplicatedStorage:FindFirstChild("GameConfig")
		return if module then (require :: any)(module) else nil
	end)
	if ok and type(config) == "table" and type(config.Flags) == "table" then
		Flags.SetDefaults(config.Flags)
	end
end

function Flags.On(name: string): boolean
	local live = ReplicatedStorage:GetAttribute("Flag_" .. name)
	if type(live) == "boolean" then
		return live
	end
	local default = defaults[name]
	if type(default) == "boolean" then
		return default
	end
	return true
end

function Flags.Set(name: string, value: boolean?)
	ReplicatedStorage:SetAttribute("Flag_" .. name, value)
	print(`[Flags] {name} = {tostring(value)}`)
end

function Flags.Changed(name: string, fn: (boolean) -> ()): RBXScriptConnection
	return ReplicatedStorage:GetAttributeChangedSignal("Flag_" .. name):Connect(function()
		fn(Flags.On(name))
	end)
end

return Flags
