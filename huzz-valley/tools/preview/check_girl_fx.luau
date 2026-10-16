-- The anime girls' effects (Gameplay/AuraFX from Shared/AuraLook) build, play and clean up on a stand-in rig.
local RS = game:GetService("ReplicatedStorage")
local AuraLook = require(RS.Shared.AuraLook)
local Looks = require(RS.Shared.Config.GirlLooks)
local AuraFX = require(game.StarterPlayer.StarterPlayerScripts.HuzzClient.Gameplay.AuraFX)
local ok, failed = 0, 0
local function check(name, c) if c then ok += 1 else failed += 1; print("FAIL " .. name) end end
local function rig()
	local m = Instance.new("Model")
	for _, n in { "HumanoidRootPart", "UpperTorso", "Head", "RightHand", "LeftHand" } do
		local p = Instance.new("Part"); p.Name = n; p.Size = Vector3.new(1, 1, 1); p.Parent = m
	end
	m.Parent = workspace
	return m
end
for _, kind in { "Player", "Companion", "Showcase" } do
	for _, case in { { "CAC_R6_ixKatsu_358858", "Mythic" }, { "CAC_R6_GoodwinDakota422_AA2072", "Epic" }, { "nobody", "Secret" }, { "nobody", "Common" } } do
		local spec = AuraLook.build(AuraLook.lookFor(Looks, case[1], Color3.new(1, 0, 0)), case[2], kind)
		if kind == "Player" and case[2] == "Common" then
			check("Common girls give no player aura", spec == nil)
		else
			local m = rig()
			local okAttach, handle = pcall(AuraFX.attach, m, spec)
			check(kind .. " " .. case[2] .. " builds", okAttach)
			if okAttach then
				local okStep, err = pcall(function() for _ = 1, 60 do handle.step(1 / 30) end end)
				check(kind .. " " .. case[2] .. " steps: " .. tostring(err), okStep)
				local emitters = 0
				for _, d in m:GetDescendants() do if d:IsA("ParticleEmitter") then emitters += 1 end end
				check(kind .. " has emitters", emitters >= 2)
				handle.setEnabled(false)
				handle.destroy()
				local left = 0
				for _, d in m:GetDescendants() do if d.Name:find("HuzzAura") or d.Name:find("HuzzSlash") then left += 1 end end
				check(kind .. " cleans up", left == 0)
			end
		end
	end
end
print(`fx smoke: {ok} ok, {failed} failed`)
return ""
