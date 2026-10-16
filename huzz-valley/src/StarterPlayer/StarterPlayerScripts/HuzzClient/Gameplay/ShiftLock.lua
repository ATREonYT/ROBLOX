--[[
	Shift lock while you play (owner's call): the mouse stays in the middle, the camera sits over your
	shoulder and you face where the camera looks. Alt switches it off and on again. It lets go of the
	mouse whenever a window is open (MenuOpen) or the Hero / Chicken pick shows (HuzzChoosing), and does
	nothing on phones and tablets.
	Roblox's own Shift-key mouse lock is switched off by the server (DevEnableMouseLock), so the two
	never fight.
]]
local M = {}

function M.start()
	local Players = game:GetService("Players")
	local RunService = game:GetService("RunService")
	local UserInputService = game:GetService("UserInputService")
	local Workspace = game:GetService("Workspace")

	local player = Players.LocalPlayer
	local OFFSET = Vector3.new(1.75, 0, 0) -- over the right shoulder, as Roblox's shift lock
	local wanted = true -- Alt flips this
	local active = false

	if UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled then
		return
	end

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
		local h = humanoidAndRoot()
		if h then
			h.AutoRotate = not on
			h.CameraOffset = if on then OFFSET else Vector3.zero
		end
		if not on then
			UserInputService.MouseBehavior = Enum.MouseBehavior.Default
		end
	end

	UserInputService.InputBegan:Connect(function(input, processed)
		if processed or UserInputService:GetFocusedTextBox() then
			return
		end
		if input.KeyCode == Enum.KeyCode.LeftAlt or input.KeyCode == Enum.KeyCode.RightAlt then
			wanted = not wanted
			local ok, Toast = pcall(require, script.Parent.Parent.UI.Toast)
			if ok then
				Toast.show(if wanted then "Shift lock on (Alt to turn off)" else "Shift lock off (Alt to turn on)", 1.5)
			end
		end
	end)
	player.CharacterAdded:Connect(function()
		active = false -- the new character starts free; the next frame sets it up again
	end)

	RunService:BindToRenderStep("HuzzShiftLock", Enum.RenderPriority.Camera.Value + 1, function()
		local h, root = humanoidAndRoot()
		local alive = h ~= nil and h.Health > 0 and root ~= nil
		local on = wanted and alive and player:GetAttribute("MenuOpen") ~= true and player:GetAttribute("HuzzChoosing") ~= true
		setActive(on)
		if not on then
			return
		end
		UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
		-- Face where the camera looks (not while lying on the floor: the server holds the body still).
		local camera = Workspace.CurrentCamera
		if camera and not root.Anchored then
			local look = camera.CFrame.LookVector
			local flat = Vector3.new(look.X, 0, look.Z)
			if flat.Magnitude > 0.01 then
				root.CFrame = CFrame.lookAt(root.Position, root.Position + flat)
			end
		end
	end)
end

return M
