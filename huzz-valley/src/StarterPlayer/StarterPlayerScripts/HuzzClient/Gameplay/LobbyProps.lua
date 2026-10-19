--[[
	Brings the owner's lobby props to life on this screen (owner, Oct 18: "implementing these objects into the lobby on
	top of the already placed circles. Give it some VFX and make it look good just like in the pictures"; the props
	are HuzzServer/LobbyPropService's, Config/LobbyProps).
	- Each prop floats over its pad: a slow bob (Bob studs over BobTime s) and one slow full turn every TurnTime s,
	  each prop on its own beat. Only this screen moves it (the Root it's welded to), only within AnimateWithin studs.
	- The soft light under it breathes gently (4 s; never a flash).
	- FREE SPIN's line counts down to your next free spin (Shared/SpinRules, your saved FreeSpinAt: a real timer).
	- A prop with a menu (Opens: Shop, SpinWheel) opens it from its prompt (E) or a click, never during a round or
	  the Hero pick (like the wheel in the lobby).
	- His place streams: a prop's Pad (light, title, FREE SPIN line) can arrive after the prop, so it's looked up
	  again until found (tools/preview/check_new_lobby.luau brings one in late).
]]
local M = {}

function M.start()
	local CollectionService = game:GetService("CollectionService")
	local Players = game:GetService("Players")
	local ProximityPromptService = game:GetService("ProximityPromptService")
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local RunService = game:GetService("RunService")
	local Workspace = game:GetService("Workspace")

	local Shared = ReplicatedStorage:WaitForChild("Shared")
	local Config = require(Shared.Config.LobbyProps)
	local SpinRules = require(Shared.SpinRules)
	local SpinWheel = require(Shared.Config.SpinWheel)
	local UI = script.Parent.Parent.UI
	local ModalManager = require(UI.ModalManager)
	local State = require(UI.State)
	local player = Players.LocalPlayer

	local function open(what: string?)
		if type(what) ~= "string" or not ModalManager.has(what) then return end
		local role = player:GetAttribute("HuzzRole")
		if role == "Runner" or role == "Catcher" or player:GetAttribute("HuzzChoosing") == true then return end
		if player:GetAttribute("HuzzCinematic") == true then return end -- (the Secret cutscene plays in the lobby, before roles)
		if ModalManager.current() == what then return end
		ModalManager.open(what)
	end

	ProximityPromptService.PromptTriggered:Connect(function(prompt, who)
		if who ~= player then return end
		local what = prompt:GetAttribute("HuzzOpens")
		if what then open(what) end
	end)

	-- [LobbyProp model] = { lp, phase, light, base, line, clicks }; homes[Root] = its place as the server put it
	local props = {}
	local homes = {}
	local hooked = {}

	local function hookClick(lp: Instance)
		for _, d in lp:GetDescendants() do
			if d:IsA("ClickDetector") and not hooked[d] then
				hooked[d] = true
				pcall(function()
					d.MouseClick:Connect(function(who)
						if who == player then open(lp:GetAttribute("Opens")) end
					end)
				end)
				d.Destroying:Connect(function() hooked[d] = nil end)
			end
		end
	end

	-- The pad's light and title line. Looked up again until found: his place streams, so the LobbyProp model can
	-- arrive before its Pad part (the other lobbies' pads only stream in when you get near), and a one-time look-up
	-- left FREE SPIN's countdown blank there for good (bug hunt, Oct 19).
	local function fill(rec)
		local pad = rec.lp:FindFirstChild("Pad")
		if not (pad and pad:IsA("BasePart")) then return end
		if not rec.placed then
			local p = pad.CFrame.Position
			rec.phase, rec.placed = (p.X * 0.37 + p.Z * 0.61) % 1, true
		end
		local light = pad:FindFirstChild("PropLight", true)
		if light ~= rec.light then
			rec.light, rec.base = light, if light and light:IsA("Light") then light.Brightness else 0
		end
		local title = pad:FindFirstChild("PropTitle")
		rec.line = title and title:FindFirstChild("Line")
	end

	local function add(lp: Instance)
		if props[lp] or not lp:IsA("Model") then return end
		local rec = { lp = lp, phase = 0, base = 0 }
		props[lp] = rec
		fill(rec)
		hookClick(lp)
		lp.DescendantAdded:Connect(function(d)
			if d:IsA("ClickDetector") then task.defer(hookClick, lp) end
		end)
		lp.Destroying:Connect(function() props[lp] = nil end)
	end

	local function scan()
		local folder = Workspace:FindFirstChild(Config.Folder)
		if folder then
			for _, lp in folder:GetChildren() do add(lp) end
		end
	end
	for _, lp in CollectionService:GetTagged(Config.Tag) do add(lp) end
	CollectionService:GetInstanceAddedSignal(Config.Tag):Connect(add)
	scan()
	Workspace.ChildAdded:Connect(function(c)
		if c.Name == Config.Folder then
			task.defer(scan)
			c.ChildAdded:Connect(add)
		end
	end)
	local folder = Workspace:FindFirstChild(Config.Folder)
	if folder then folder.ChildAdded:Connect(add) end

	local bobTime, turnTime = math.max(0.5, Config.BobTime), Config.TurnTime
	RunService.RenderStepped:Connect(function()
		local cam = Workspace.CurrentCamera
		local char = player.Character
		local body = char and char:FindFirstChild("HumanoidRootPart")
		local eye = if cam then cam.CFrame.Position elseif body then body.CFrame.Position else nil
		if not eye then return end
		local t = os.clock()
		for lp, rec in props do
			local prop = lp:FindFirstChild("Prop")
			local root = prop and prop:IsA("Model") and prop.PrimaryPart
			if root and root.Parent then
				local home = homes[root]
				if not home then
					home = root.CFrame
					homes[root] = home
					root.Destroying:Connect(function() homes[root] = nil end)
				end
				if (home.Position - eye).Magnitude <= Config.AnimateWithin then
					local bob = math.sin((t / bobTime + rec.phase) * 2 * math.pi) * Config.Bob
					local turn = if turnTime and turnTime > 0 then ((t / turnTime + rec.phase) % 1) * 2 * math.pi else 0
					root.CFrame = home * CFrame.new(0, bob, 0) * CFrame.Angles(0, turn, 0)
					if rec.light then
						rec.light.Brightness = rec.base * (0.85 + 0.15 * math.sin((t / 4 + rec.phase) * 2 * math.pi))
					end
				end
			end
		end
	end)

	-- FREE SPIN's countdown (twice a second is plenty)
	task.spawn(function()
		while true do
			local now = Workspace:GetServerTimeNow()
			for lp, rec in props do
				if not (rec.line and rec.line.Parent and rec.light and rec.light.Parent) then fill(rec) end -- (streamed in late)
				if rec.line and lp:GetAttribute("Line") == "FreeSpin" then
					local text
					if State.data and State.data.Loaded == true then
						local left = SpinRules.freeIn(State.data, now)
						text = if left <= 0 then "Free spin ready!" else "Next free spin in " .. SpinRules.clock(left)
					else
						text = string.format("A free spin every %d minutes", math.floor(SpinWheel.FreeEvery / 60))
					end
					if rec.line.Text ~= text then rec.line.Text = text end
				end
			end
			task.wait(0.5)
		end
	end)
end

return M
