--[[
	Shift lock while you're in a round (owner's call; never in the lobby): the mouse stays in the middle,
	the camera sits over your shoulder and you face where the camera looks. Hold Alt to let go of it for
	as long as you hold it. The mouse pointer is hidden while it's on (owner's call: no cursor in the game;
	Alt brings it back). It lets go of the mouse whenever a window is open (MenuOpen), the Chicken or Hero
	pick shows (HuzzChoosing) or the round's intro camera plays (HuzzCinematic). Phones and tablets get it too
	since Oct 23 (owner, playing on his phone: "make the shift lock be turned on when you are in the game"): the
	body faces where the camera looks and the camera sits over the shoulder; there is no mouse to hold, so the
	thumb still drags the camera round as usual.
	Roblox's own Shift-key mouse lock is switched off by the server (DevEnableMouseLock), so the two
	never fight.
	M.wouldLock() answers "will shift lock be on once the camera shots let go?" with the same test (Gameplay/Cinematic
	and Gameplay/SecretReveal aim their hand-back over your shoulder only then).
]]
local M = {}

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local PLAYING = { HeroRun = true, Countdown = true, Running = true, RoundOver = true }
local OFFSET = Vector3.new(1.75, 0, 0) -- over the right shoulder, as Roblox's shift lock
M.OFFSET = OFFSET
local altHeld = false
local round: Instance? = nil

-- The one test for "shift lock on". ignoreCinematic: answer as if no camera shot were playing (for the hand-back).
local function wants(ignoreCinematic: boolean?): boolean
	local player = Players.LocalPlayer
	local c = player.Character
	local h = c and c:FindFirstChildOfClass("Humanoid")
	local alive = h ~= nil and h.Health > 0 and h.RootPart ~= nil
	local role = player:GetAttribute("HuzzRole")
	local stage = if round then round:GetAttribute("Stage") or "" else ""
	local inRound = (role == "Runner" or role == "Catcher") and PLAYING[stage] == true
	return inRound and not altHeld and alive and player:GetAttribute("MenuOpen") ~= true
		and player:GetAttribute("HuzzChoosing") ~= true
		and (ignoreCinematic == true or player:GetAttribute("HuzzCinematic") ~= true)
		and player:GetAttribute("HuzzWheel") ~= true -- (the G dance wheel needs the mouse)
end

function M.wouldLock(): boolean
	local ok, on = pcall(wants, true)
	return ok and on == true
end

function M.start()
	local RunService = game:GetService("RunService")
	local Workspace = game:GetService("Workspace")

	local player = Players.LocalPlayer
	local active = false
	local Net = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared").Net)
	round = Net.get("Round") :: RemoteEvent

	local function humanoidAndRoot()
		local c = player.Character
		local h = c and c:FindFirstChildOfClass("Humanoid")
		return h, h and h.RootPart
	end

	local function setActive(on)
		if on == active then
			return
		end
		active = on
		player:SetAttribute("HuzzShiftLock", on) -- (Gameplay/Dash reads it before handing the turning back)
		local h = humanoidAndRoot()
		if h then
			h.AutoRotate = not on
			h.CameraOffset = if on then OFFSET else Vector3.zero
		end
		UserInputService.MouseIconEnabled = not on -- no pointer while it's on
		if not on then
			UserInputService.MouseBehavior = Enum.MouseBehavior.Default
		end
	end

	local function isAlt(input)
		return input.KeyCode == Enum.KeyCode.LeftAlt or input.KeyCode == Enum.KeyCode.RightAlt
	end
	UserInputService.InputBegan:Connect(function(input)
		if isAlt(input) then
			altHeld = true
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if isAlt(input) then
			altHeld = false
		end
	end)
	UserInputService.WindowFocusReleased:Connect(function()
		altHeld = false -- (Alt-Tab away never sends the release)
	end)
	player.CharacterAdded:Connect(function()
		active = true
		setActive(false) -- the new character starts free (pointer back); the next frame sets it up again
	end)

	RunService:BindToRenderStep("HuzzShiftLock", Enum.RenderPriority.Camera.Value + 1, function()
		local _, root = humanoidAndRoot()
		local on = wants(false)
		setActive(on)
		if not on or not root then
			return
		end
		if UserInputService.MouseEnabled then -- (a phone has no pointer to hold in the middle)
			UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
		end
		-- Face where the camera looks (not while lying on the floor: the server holds the body still; nor while
		-- stunned on your belly after a dive, HuzzServer/PowerService.stun, or the body would spin on the floor).
		local camera = Workspace.CurrentCamera
		local t = Workspace:GetServerTimeNow()
		local stunned = t >= (player:GetAttribute("StunnedFrom") or math.huge) and t < (player:GetAttribute("StunnedUntil") or 0)
		if camera and not root.Anchored and not stunned then
			local look = camera.CFrame.LookVector
			local flat = Vector3.new(look.X, 0, look.Z)
			if flat.Magnitude > 0.01 then
				root.CFrame = CFrame.lookAt(root.Position, root.Position + flat)
			end
		end
	end)
end

return M
