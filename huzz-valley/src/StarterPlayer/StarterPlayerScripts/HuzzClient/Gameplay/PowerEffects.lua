--[[
	One-off power effects, drawn on each client from the server's "Power" messages on the Round
	remote (HuzzServer/PowerService). The lasting ones (the shield bubble, rush trail, traps and
	head badges) are made on the server, so they're already in everyone's world.
	  CharmWave:  a pink ring spreads out from the catcher to the wave's reach.
	  ShieldPop:  hearts burst out of the runner whose Heart Shield blocked a stab.
	  TrapSprung: hearts pop up out of the Love Trap that caught someone.
	No flashing: everything fades in about half a second.
]]
local M = {}

function M.start()
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local TweenService = game:GetService("TweenService")
	local Workspace = game:GetService("Workspace")
	local Players = game:GetService("Players")
	local Sfx = require(script.Parent.Sfx)

	local Net = require(ReplicatedStorage:WaitForChild("Shared").Net)
	local RoundNet = Net.get("Round") :: RemoteEvent
	local PINK = Color3.fromRGB(255, 110, 190)

	local folder = Instance.new("Folder")
	folder.Name = "HuzzPowerEffects"
	folder.Parent = Workspace

	local function ring(at: Vector3, radius: number)
		local p = Instance.new("Part")
		p.Shape = Enum.PartType.Cylinder
		p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
		p.Material = Enum.Material.Neon
		p.Color = PINK
		p.Transparency = 0.35
		p.Size = Vector3.new(0.15, 2, 2)
		p.CFrame = CFrame.new(at - Vector3.new(0, 2.6, 0)) * CFrame.Angles(0, 0, math.rad(90))
		p.Parent = folder
		local t = TweenService:Create(p, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Size = Vector3.new(0.15, radius * 2, radius * 2), Transparency = 1,
		})
		t.Completed:Connect(function() p:Destroy() end)
		t:Play()
	end

	-- Little hearts flying out of a point and fading.
	local function hearts(at: Vector3, count: number, glyph: string, spread: number)
		for i = 1, count do
			local holder = Instance.new("Part")
			holder.Anchored, holder.CanCollide, holder.CanQuery, holder.CanTouch = true, false, false, false
			holder.Transparency = 1
			holder.Size = Vector3.new(0.2, 0.2, 0.2)
			holder.CFrame = CFrame.new(at)
			holder.Parent = folder
			local gui = Instance.new("BillboardGui")
			gui.Size = UDim2.new(1.4, 0, 1.4, 0)
			gui.LightInfluence = 0
			gui.Parent = holder
			local label = Instance.new("TextLabel")
			label.Size = UDim2.fromScale(1, 1)
			label.BackgroundTransparency = 1
			label.Text = glyph
			label.TextScaled = true
			label.Parent = gui
			local angle = (i / count) * math.pi * 2
			local out = Vector3.new(math.cos(angle) * spread, 2 + (i % 3) * 0.8, math.sin(angle) * spread)
			TweenService:Create(holder, TweenInfo.new(0.7, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { CFrame = CFrame.new(at + out) }):Play()
			local fade = TweenService:Create(label, TweenInfo.new(0.7, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { TextTransparency = 1 })
			fade.Completed:Connect(function() holder:Destroy() end)
			fade:Play()
		end
	end

	RoundNet.OnClientEvent:Connect(function(kind, data)
		if kind ~= "Power" or type(data) ~= "table" then return end
		local mine = data.id == Players.LocalPlayer.UserId
		local SOUND = { HeartShield = "heart_shield", RizzRush = "power_rush", CharmWave = "power_rush", LoveTrap = "heart_shield", ShieldPop = "heart_shield" }
		if SOUND[data.name] and (mine or data.by == Players.LocalPlayer.UserId) then
			Sfx.play(SOUND[data.name])
		end
		local at = data.at
		if typeof(at) ~= "Vector3" then return end
		if data.name == "CharmWave" then
			ring(at, data.radius or 16)
			hearts(at + Vector3.new(0, 1, 0), 6, "💞", 4)
		elseif data.name == "ShieldPop" then
			hearts(at, 8, "💖", 3.5)
		elseif data.name == "TrapSprung" then
			hearts(at + Vector3.new(0, 1, 0), 5, "💘", 2)
		end
	end)
end

return M
