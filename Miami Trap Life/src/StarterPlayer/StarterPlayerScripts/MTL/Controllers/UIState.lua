--!strict
-- Who owns the screen right now. Cutscenes, the open phone, minigames etc. push a state and pop it when done.
-- Flags merge with OR across everything pushed:
--   hideHUD, hidePhone, hideWaypoints, lockControls, lockCamera
--   UIState.push("Cutscene", { hideHUD = true, hidePhone = true, lockControls = true })
--   UIState.pop("Cutscene")
--   UIState.get().hideHUD ; UIState.Changed:Connect(function(state) end)
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Signal = require(ReplicatedStorage.MTL.Signal)

local UIState = {}
UIState.Changed = Signal.new()

local owners: { [string]: { [string]: boolean } } = {}
local merged: { [string]: boolean } = {}
local controls: any = nil

-- Movement lock. Uses the PlayerModule when the place has one; otherwise (newer Roblox builds don't put a
-- PlayerModule in PlayerScripts) sinks every movement input with ContextActionService. Never yields: a push or
-- pop must return at once, or a cutscene waiting on it would hang on a black screen.
local ContextActionService = game:GetService("ContextActionService")
local LOCK_ACTION = "MTL_LockControls"
local SINK_INPUTS = {
	Enum.PlayerActions.CharacterForward,
	Enum.PlayerActions.CharacterBackward,
	Enum.PlayerActions.CharacterLeft,
	Enum.PlayerActions.CharacterRight,
	Enum.PlayerActions.CharacterJump,
	Enum.KeyCode.W, Enum.KeyCode.A, Enum.KeyCode.S, Enum.KeyCode.D,
	Enum.KeyCode.Up, Enum.KeyCode.Down, Enum.KeyCode.Left, Enum.KeyCode.Right,
	Enum.KeyCode.Space, Enum.KeyCode.ButtonA, Enum.KeyCode.Thumbstick1,
}

local function getControls()
	if controls then
		return controls
	end
	local ps = Players.LocalPlayer:FindFirstChild("PlayerScripts")
	local pmScript = ps and ps:FindFirstChild("PlayerModule")
	if pmScript then
		local ok, result = pcall(function()
			return (require(pmScript :: any) :: any):GetControls()
		end)
		if ok then
			controls = result
		end
	end
	return controls
end

local function stopCharacter()
	local char = Players.LocalPlayer.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if hum then
		hum:Move(Vector3.zero)
	end
end

local function setLocked(locked: boolean)
	local c = getControls()
	if c then
		if locked then
			c:Disable()
		else
			c:Enable()
		end
	end
	if locked then
		ContextActionService:BindActionAtPriority(LOCK_ACTION, function()
			return Enum.ContextActionResult.Sink
		end, false, Enum.ContextActionPriority.High.Value + 100, table.unpack(SINK_INPUTS))
		stopCharacter()
	else
		ContextActionService:UnbindAction(LOCK_ACTION)
	end
end

local function recompute()
	local m: { [string]: boolean } = {}
	for _, flags in owners do
		for k, v in flags do
			if v then
				m[k] = true
			end
		end
	end
	local wasLocked = merged.lockControls == true
	merged = m
	if (m.lockControls == true) ~= wasLocked then
		local ok, err = pcall(setLocked, m.lockControls == true)
		if not ok then
			warn("[MTL UIState] control lock failed:", err)
		end
	end
	UIState.Changed:Fire(merged)
end

function UIState.push(owner: string, flags: { [string]: boolean })
	owners[owner] = flags
	recompute()
end

function UIState.pop(owner: string)
	if owners[owner] then
		owners[owner] = nil
		recompute()
	end
end

function UIState.get(): { [string]: boolean }
	return merged
end

function UIState.has(owner: string): boolean
	return owners[owner] ~= nil
end

function UIState.init()
	-- a respawn never leaves controls locked by a state whose owner died with the character
	Players.LocalPlayer.CharacterAdded:Connect(function()
		task.wait()
		if merged.lockControls then
			pcall(setLocked, true)
		end
	end)
end

return UIState
