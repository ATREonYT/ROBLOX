--!strict
-- Downed -> finish -> ragdoll (LihFolk build list item 4, the guns side). Helper of GunService: required and
-- init'd by it, not booted on its own. Numbers: Config/Guns.Downed.
--
-- A gun shot that would kill a player downs them instead. Health stays at Downed.Health and the character gets
--   MTL_Downed = true · MTL_DownedBy = attacker UserId · MTL_DownedAt = server time
-- A downed player crawls (Controllers/DownedPose poses them on every screen), can't jump, shoot or draw, and bleeds
-- out after Downed.BleedSeconds. Anyone allowed to shoot them can walk up and hold E (MTL_FinishPrompt on the root)
-- to finish them. Only a finish is a kill: GunService.Killed fires then, by the finisher, so kill money, bounties
-- and loot hang off the finish. Bleeding out or any other death is not a kill. NPCs still drop on the spot.
-- Every player death (and every NPC a gun kills) ragdolls: joints swap for ball sockets, nothing breaks apart.
-- The death card reads these character attributes:
--   MTL_DeathCause = "Finished" | "BledOut" | "Other" · MTL_DeathBy = display name (finisher) · MTL_FinishedBy = UserId
-- Signals (on GunService): Downed(attacker, victim) · Finished(finisher, victim, downedByUserId?) ·
--   BledOut(victim, downedByUserId?)
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Net = require(ReplicatedStorage.MTL.Net)
local Guns = require(ReplicatedStorage.MTL.Config.Guns)
local GunRules = require(ReplicatedStorage.MTL.Rules.GunRules)
local Notify = require(script.Parent.Notify)

local D = Guns.Downed
local DANGER = Color3.fromRGB(255, 86, 96)
local PROMPT = "MTL_FinishPrompt"

local GunDowned = {}

local ctx: any = nil -- GunService + a few of its locals (path, markFight)
local downedAt: { [Model]: number } = {}

local function root(char: Model?): BasePart?
	return char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
end

function GunDowned.isDowned(char: Instance?): boolean
	return char ~= nil and char:GetAttribute("MTL_Downed") == true
end

local function clear(char: Model)
	downedAt[char] = nil
	local r = root(char)
	local p = r and r:FindFirstChild(PROMPT)
	if p then
		p:Destroy()
	end
	char:SetAttribute("MTL_Downed", nil)
end

-- May `finisher` finish `victim`? Same rules as shooting them with a live gun.
local function allowed(finisher: Player, victim: Player): (boolean, string?)
	if finisher == victim then
		return false, nil
	end
	local fc = finisher.Character
	local fh = fc and fc:FindFirstChildOfClass("Humanoid")
	if not fc or not fh or fh.Health <= 0 or GunDowned.isDowned(fc) then
		return false, nil
	end
	local a, b = root(fc), root(victim.Character)
	if not a or not b or (a.Position - b.Position).Magnitude > D.FinishRange + 3 then
		return false, "Get closer"
	end
	local ok = GunRules.canDamage("Live", ctx.path(finisher), (ctx.GunService.inSafeZone(finisher)), {
		isPlayer = true,
		path = ctx.path(victim),
		safe = (ctx.GunService.inSafeZone(victim)),
		damageable = false,
		self = false,
	})
	if not ok then
		return false, if ctx.path(finisher) ~= "Criminal" then "Only the street life finishes people" else "Not here"
	end
	return true, nil
end

local function finish(victim: Player, char: Model, finisher: Player)
	if victim.Character ~= char or not GunDowned.isDowned(char) then
		return
	end
	local ok, why = allowed(finisher, victim)
	if not ok then
		if why then
			Notify.refuse(finisher, why)
		end
		return
	end
	local hum = char:FindFirstChildOfClass("Humanoid")
	if not hum or hum.Health <= 0 then
		return
	end
	local by = char:GetAttribute("MTL_DownedBy")
	clear(char)
	char:SetAttribute("MTL_DeathCause", "Finished")
	char:SetAttribute("MTL_DeathBy", finisher.DisplayName)
	char:SetAttribute("MTL_FinishedBy", finisher.UserId)
	hum:SetAttribute("MTL_LastAttacker", finisher.UserId)
	ctx.markFight(finisher, victim)
	hum.Health = 0
	Net.get("GunFx"):FireClient(finisher, { type = "finish", model = char })
	Notify.toast(finisher, "You finished " .. victim.DisplayName, DANGER)
	ctx.GunService.Killed:Fire(finisher, char)
	ctx.GunService.Finished:Fire(finisher, victim, if type(by) == "number" then by else nil)
end

local function bleedOut(victim: Player, char: Model, at: number)
	if victim.Character ~= char or downedAt[char] ~= at or not GunDowned.isDowned(char) then
		return
	end
	local hum = char:FindFirstChildOfClass("Humanoid")
	if not hum or hum.Health <= 0 then
		return
	end
	local by = char:GetAttribute("MTL_DownedBy")
	clear(char)
	char:SetAttribute("MTL_DeathCause", "BledOut")
	hum.Health = 0
	ctx.GunService.BledOut:Fire(victim, if type(by) == "number" then by else nil)
end

-- Called by GunService instead of dealing a killing blow to a player. Returns true if they went down.
function GunDowned.down(attacker: Player, victim: Player, char: Model, hum: Humanoid): boolean
	if not D.Enabled or GunDowned.isDowned(char) or hum.Health <= 0 then
		return false
	end
	local r = root(char)
	if not r then
		return false
	end
	local at = Workspace:GetServerTimeNow()
	downedAt[char] = at
	hum.Health = math.max(1, D.Health)
	char:SetAttribute("MTL_Downed", true)
	char:SetAttribute("MTL_DownedBy", attacker.UserId)
	char:SetAttribute("MTL_DownedAt", at)
	if ctx.GunService.equipped(victim) then
		ctx.GunService.holster(victim, "downed")
	end

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = PROMPT
	prompt.ActionText = "Finish"
	prompt.ObjectText = victim.DisplayName
	prompt.HoldDuration = D.FinishHold
	prompt.MaxActivationDistance = D.FinishRange
	prompt.RequiresLineOfSight = false
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.GamepadKeyCode = Enum.KeyCode.ButtonX
	prompt.Parent = r
	prompt.Triggered:Connect(function(finisher: Player)
		finish(victim, char, finisher)
	end)

	task.delay(D.BleedSeconds, bleedOut, victim, char, at)
	Net.get("GunFx"):FireClient(victim, { type = "downed", by = attacker, seconds = D.BleedSeconds })
	Notify.toast(attacker, victim.DisplayName .. " is down. Hold E on them to finish.", DANGER)
	ctx.GunService.Downed:Fire(attacker, victim)
	return true
end

---------------------------------------------------------------- ragdoll

local LIMIT: { [string]: { number } } = { -- UpperAngle, TwistLower, TwistUpper (degrees)
	Neck = { 35, -40, 40 },
	Waist = { 25, -25, 25 },
	Root = { 20, -20, 20 },
	RightShoulder = { 80, -60, 60 },
	LeftShoulder = { 80, -60, 60 },
	RightElbow = { 70, 0, 0 },
	LeftElbow = { 70, 0, 0 },
	RightWrist = { 30, -20, 20 },
	LeftWrist = { 30, -20, 20 },
	RightHip = { 60, -30, 30 },
	LeftHip = { 60, -30, 30 },
	RightKnee = { 70, 0, 0 },
	LeftKnee = { 70, 0, 0 },
	RightAnkle = { 25, -15, 15 },
	LeftAnkle = { 25, -15, 15 },
}

-- Swaps the body's joints for ball sockets so it falls like a body. Call on death with BreakJointsOnDeath = false.
function GunDowned.ragdoll(char: Model)
	if char:GetAttribute("MTL_Ragdoll") then
		return
	end
	char:SetAttribute("MTL_Ragdoll", true)
	local gun = char:FindFirstChild("MTL_Gun")
	for _, m in char:GetDescendants() do
		if m:IsA("Motor6D") and m.Part0 and m.Part1 and not (gun and m:IsDescendantOf(gun)) and not m:FindFirstAncestorOfClass("Accessory") then
			local lim = LIMIT[m.Name] or { 45, -30, 30 }
			local a0 = Instance.new("Attachment")
			a0.Name = "MTL_Rag0"
			a0.CFrame = m.C0
			a0.Parent = m.Part0
			local a1 = Instance.new("Attachment")
			a1.Name = "MTL_Rag1"
			a1.CFrame = m.C1
			a1.Parent = m.Part1
			local b = Instance.new("BallSocketConstraint")
			b.Name = "MTL_Rag"
			b.Attachment0 = a0
			b.Attachment1 = a1
			b.LimitsEnabled = true
			b.UpperAngle = lim[1]
			b.TwistLimitsEnabled = lim[2] ~= 0 or lim[3] ~= 0
			b.TwistLowerAngle = lim[2]
			b.TwistUpperAngle = lim[3]
			b.Parent = m.Part1
			m.Enabled = false
		elseif m:IsA("AnimationConstraint") and m.Attachment0 and m.Attachment1 and not (gun and m:IsDescendantOf(gun)) and not m:FindFirstAncestorOfClass("Accessory") then
			-- AnimationConstraint rigs: same joint, same attachments, ball socket instead
			local j = m.Attachment1.Parent
			local lim = LIMIT[m.Name] or LIMIT[j and j.Name:gsub("RigAttachment$", "") or ""] or { 45, -30, 30 }
			local b = Instance.new("BallSocketConstraint")
			b.Name = "MTL_Rag"
			b.Attachment0 = m.Attachment0
			b.Attachment1 = m.Attachment1
			b.LimitsEnabled = true
			b.UpperAngle = lim[1]
			b.TwistLimitsEnabled = lim[2] ~= 0 or lim[3] ~= 0
			b.TwistLowerAngle = lim[2]
			b.TwistUpperAngle = lim[3]
			b.Parent = m.Parent
			m.Enabled = false
		end
	end
	for _, p in char:GetChildren() do
		if p:IsA("BasePart") then
			if p.Name == "HumanoidRootPart" then
				p.CanCollide = false
				p.Massless = true
			else
				p.CanCollide = true
			end
		end
	end
end

---------------------------------------------------------------- lifecycle

function GunDowned.onCharacter(player: Player, char: Model, hum: Humanoid)
	hum.BreakJointsOnDeath = false
	hum.Died:Connect(function()
		char:SetAttribute("MTL_DiedAt", Workspace:GetServerTimeNow())
		if char:GetAttribute("MTL_DeathCause") == nil then
			char:SetAttribute("MTL_DeathCause", "Other")
		end
		clear(char)
		GunDowned.ragdoll(char)
	end)
end

-- The death card's Respawn button (GunAction { type = "respawn" }).
function GunDowned.respawn(player: Player)
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not char or not hum or hum.Health > 0 then
		return
	end
	local diedAt = char:GetAttribute("MTL_DiedAt")
	if type(diedAt) == "number" and Workspace:GetServerTimeNow() - diedAt < D.RespawnAfter then
		return
	end
	player:LoadCharacter()
end

function GunDowned.init(context: any)
	ctx = context
	Players.PlayerRemoving:Connect(function(player)
		local char = player.Character
		if char then
			downedAt[char] = nil
		end
	end)
end

return GunDowned
