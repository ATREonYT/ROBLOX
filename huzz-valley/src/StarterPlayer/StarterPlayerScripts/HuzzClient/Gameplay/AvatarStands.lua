--[[
	Lobby avatar stands that show a Game Pass (owner, Oct 18: "make the blocks i have in the lobby, next to the spin
	the wheel turn into my character and have like animated running or something along those lines, selling a
	gamepass"; reference: Huss Valley's stands, clones of YOUR avatar with a sign and a price button).

	Any Part or Model named "AvatarStand" (also "AvatarStand 2" ...) or tagged "HuzzAvatarStand" becomes one. Its
	attributes, typed in Studio's Properties:
	  Pass      a Game Pass key from Config/Products ("VIP", "DancePack") or a Game Pass ID number
	  Title     the big words (default: the pass's name);  Subtitle: what it gives (default: its blurb)
	  Tag       the little pill over the sign (default "GAME PASS");  Price: Robux to show (default: Products)
	  Color     the glow and button colour (default: the pass's colour, else Huss Valley green)
	  StandOn   "Floor" (the block turns into your character: it hides and you stand where it stood) or "Top"
	            (you stand on top of it). Default: a tall block (like his 4 x 8 x 4 ones) turns into you, a flat
	            one is a pedestal.
	On each screen a copy of THAT player's own avatar stands there running in place with the game's run (the
	owner's run animation when it can play here, Shared/AnimationLibrary "Run"; otherwise Shared/RunMotion, the
	scripted Huss Valley run, on R15; a simple swing on R6), slowly turning to face you like the leaderboards. A
	calm glow under the feet (a soft disc, a small light, a few slow sparkles; owner: calmer effects). Above: the tag,
	the title plate and the subtitle; at the waist the price button ("1,799 · VIEW"). No timers, no "limited",
	no "ends in" (kid-safe, even though the reference has them).
	Buying: only through Shared/AvatarStandRules (a real Game Pass ID AND a pass the game already grants);
	otherwise the button says SOON and tapping it only says it's coming soon. Ownership is the server's
	(ShopService asks Roblox), read here from State.
]]
local M = {}

function M.start()
	local CollectionService = game:GetService("CollectionService")
	local MarketplaceService = game:GetService("MarketplaceService")
	local Players = game:GetService("Players")
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local RunService = game:GetService("RunService")
	local Workspace = game:GetService("Workspace")

	local Shared = ReplicatedStorage:WaitForChild("Shared")
	local Products = require(Shared.Config.Products)
	local Rules = require(Shared.AvatarStandRules)
	local LeaderRules = require(Shared.LeaderboardRules)
	local RunMotion = require(Shared.RunMotion)
	local Library = require(Shared.AnimationLibrary)
	local Format = require(Shared.Format)
	local UI = script.Parent.Parent.UI
	local Theme = require(UI.Theme)
	local State = require(UI.State)
	local Toast = require(UI.Toast)

	local player = Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui")
	local TAG = "HuzzAvatarStand"
	local NEAR = 160 -- copies further away than this stop moving
	local SPEED = 26 -- the run's pace (studs a second: a runner's sprint)
	local TURN = 2.2

	local holder = Instance.new("Folder")
	holder.Name = "HuzzStandAvatars" -- (this screen only)
	holder.Parent = Workspace

	local stands = {} -- [stand instance] = rec
	local livePrice = {} -- [passId] = Robux from Roblox

	local function key(name: string): string
		return (string.gsub(name, "[%s_%-]", "")):lower()
	end

	local function isStand(d: Instance): boolean
		if not (d:IsA("BasePart") or d:IsA("Model")) then return false end
		if string.sub(key(d.Name), 1, 11) == "avatarstand" then return true end
		local ok, has = pcall(CollectionService.HasTag, CollectionService, d, TAG)
		return ok and has == true
	end

	-- The block's box: its centre CFrame and size.
	local function box(stand: Instance): (CFrame, Vector3)
		if stand:IsA("BasePart") then return stand.CFrame, stand.Size end
		local ok, cf, size = pcall(function() return (stand :: Model):GetBoundingBox() end)
		if ok then return cf, size end
		return (stand :: Model):GetPivot(), Vector3.new(4, 1, 4)
	end

	local function accentOf(stand: Instance, info): Color3
		local c = stand:GetAttribute("Color")
		if typeof(c) == "Color3" then return c end
		local p = info.Key and Products.get(info.Key) :: any
		if p and typeof(p.Accent) == "Color3" then return p.Accent end
		return Theme.Colors.Accent
	end

	local function attrs(stand: Instance)
		return {
			Pass = stand:GetAttribute("Pass"), Title = stand:GetAttribute("Title"), Subtitle = stand:GetAttribute("Subtitle"),
			Tag = stand:GetAttribute("Tag"), Price = stand:GetAttribute("Price"),
		}
	end

	-- A still copy of your avatar, with nothing that runs, talks, glows or collides.
	local function copyAvatar(): Model?
		local char = player.Character
		if not char or not char:FindFirstChild("HumanoidRootPart") then return nil end
		local was = char.Archivable
		char.Archivable = true
		local ok, copy = pcall(char.Clone, char)
		pcall(function() char.Archivable = was end)
		if not ok or not copy then return nil end
		-- the game's own extras on your body don't belong on the statue (your knife, aura and girl effects)
		for _, d in copy:GetDescendants() do
			if d.Name:sub(1, 4) == "Huzz" and d.Parent then d:Destroy() end
		end
		for _, d in copy:GetDescendants() do
			if d:IsA("BaseScript") or d:IsA("Sound") or d:IsA("BillboardGui") or d:IsA("SurfaceGui") or d:IsA("ParticleEmitter")
				or d:IsA("Trail") or d:IsA("Beam") or d:IsA("Light") or d:IsA("Highlight") or d:IsA("ForceField")
				or d:IsA("Tool") or d:IsA("ProximityPrompt") or d:IsA("BodyMover") or d:IsA("AlignPosition")
				or d:IsA("AlignOrientation") or d:IsA("LinearVelocity") or d:IsA("VectorForce") then
				d:Destroy()
			end
		end
		for _, d in copy:GetDescendants() do
			if d:IsA("BasePart") then
				d.Anchored = false
				d.CanCollide = false
				d.CanTouch = false
				d.CanQuery = false
				d.Massless = true
			end
		end
		local hum = copy:FindFirstChildOfClass("Humanoid")
		if hum then
			pcall(function()
				hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
				hum.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
				hum.PlatformStand = true
				hum.EvaluateStateMachine = false
				hum.BreakJointsOnDeath = false
			end)
		end
		copy.Name = "StandAvatar"
		for _, name in { "HuzzDance", "HuzzDanceAt", "HuzzCastAt", "DashAt" } do pcall(function() copy:SetAttribute(name, nil) end) end
		return copy
	end

	-- Root height over the feet.
	local function hipOffset(copy: Model): number
		local hum = copy:FindFirstChildOfClass("Humanoid")
		local root = copy:FindFirstChild("HumanoidRootPart") :: BasePart
		if hum and hum.RigType == Enum.HumanoidRigType.R15 then
			return hum.HipHeight + root.Size.Y / 2
		end
		local leg = copy:FindFirstChild("Left Leg")
		return root.Size.Y / 2 + (if leg and leg:IsA("BasePart") then leg.Size.Y else 2)
	end

	-- The run on the copy: the owner's run animation if it plays here, else the scripted one.
	local function startRun(rec)
		local copy = rec.copy
		local hum = copy:FindFirstChildOfClass("Humanoid")
		local id = Library.id("Run")
		if hum and id ~= "" and hum.RigType == Enum.HumanoidRigType.R15 then
			local ok = pcall(function()
				local animator = hum:FindFirstChildOfClass("Animator") or Instance.new("Animator")
				animator.Parent = hum
				local anim = Instance.new("Animation")
				anim.AnimationId = id
				local track = animator:LoadAnimation(anim)
				track.Looped = true
				track.Priority = Enum.AnimationPriority.Action
				track:Play(0.2)
				rec.track = track
			end)
			if ok then return end
		end
		rec.motion = RunMotion.new(copy) -- (nil on R6)
		if not rec.motion then
			local torso = copy:FindFirstChild("Torso")
			if torso then
				rec.r6 = {}
				for _, name in { "Left Shoulder", "Right Shoulder", "Left Hip", "Right Hip" } do
					local m = torso:FindFirstChild(name)
					if m and m:IsA("Motor6D") then rec.r6[name] = m end
				end
			end
		end
		rec.phase = 0
	end

	local function stepRun(rec, dt: number)
		if rec.track then return end
		if rec.motion then
			RunMotion.step(rec.motion, dt, SPEED, true, false)
		elseif rec.r6 then
			rec.phase = (rec.phase + dt * 9) % (2 * math.pi)
			local s = math.sin(rec.phase) * math.rad(60)
			for name, m in rec.r6 do
				local sign = if name == "Left Shoulder" or name == "Right Hip" then 1 else -1
				m.Transform = CFrame.Angles(0, 0, sign * s)
			end
		end
	end

	-- The calm glow under the feet: a soft disc, a small light, a few slow sparkles.
	local function glow(rec, floorY: number, centre: Vector3, width: number)
		local d = math.clamp(width * 0.9, 3, 5)
		local disc = Instance.new("Part")
		disc.Name = "StandGlow"
		disc.Shape = Enum.PartType.Cylinder
		disc.Anchored, disc.CanCollide, disc.CanTouch, disc.CanQuery, disc.CastShadow = true, false, false, false, false
		disc.Size = Vector3.new(0.12, d, d)
		disc.CFrame = CFrame.new(centre.X, floorY + 0.07, centre.Z) * CFrame.Angles(0, 0, math.rad(90))
		disc.Material = Enum.Material.Neon
		disc.Color = rec.accent
		disc.Transparency = 0.6
		disc.Parent = holder
		local light = Instance.new("PointLight")
		light.Color, light.Brightness, light.Range, light.Shadows = rec.accent, 0.9, 9, false
		light.Parent = disc
		local sparkle = Instance.new("ParticleEmitter")
		sparkle.Color = ColorSequence.new(rec.accent:Lerp(Color3.new(1, 1, 1), 0.5))
		sparkle.LightEmission = 0.6
		sparkle.Rate = 2
		sparkle.Lifetime = NumberRange.new(2, 3)
		sparkle.Speed = NumberRange.new(0.6, 1.2)
		sparkle.SpreadAngle = Vector2.new(12, 12)
		sparkle.Size = NumberSequence.new(0.18, 0.05)
		sparkle.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.2, 0.35), NumberSequenceKeypoint.new(1, 1) })
		sparkle.EmissionDirection = Enum.NormalId.Right -- (the disc lies on its side: its +X points up)
		sparkle.Parent = disc
		rec.disc = disc
	end

	-- The sign over the head and the price button at the waist (BillboardGuis in PlayerGui, so the button clicks).
	local function signs(rec)
		local info, accent = rec.info, rec.accent
		local head = rec.copy:FindFirstChild("Head") or rec.root
		local top = Instance.new("BillboardGui")
		top.Name = "StandSign"
		top.Adornee = head
		top.Size = UDim2.fromScale(9, 3.3) -- studs: it shrinks with distance like a real sign
		top.StudsOffsetWorldSpace = Vector3.new(0, 3.1, 0)
		top.LightInfluence = 0
		top.MaxDistance = 140
		top.ResetOnSpawn = false
		local pill = Instance.new("TextLabel")
		pill.Name = "Tag"
		pill.AnchorPoint = Vector2.new(0.5, 0)
		pill.Position = UDim2.fromScale(0.5, 0)
		pill.Size = UDim2.fromScale(0.44, 0.2)
		pill.BackgroundColor3 = accent
		pill.Text = info.Tag
		pill.TextScaled = true
		pill.FontFace = Theme.Fonts.Heading
		pill.TextColor3 = Color3.new(1, 1, 1)
		pill.ZIndex = 3
		pill.Parent = top
		local pc = Instance.new("UICorner"); pc.CornerRadius = UDim.new(0.5, 0); pc.Parent = pill
		local pp = Instance.new("UIPadding"); pp.PaddingTop = UDim.new(0.14, 0); pp.PaddingBottom = UDim.new(0.14, 0); pp.Parent = pill
		local ps = Instance.new("UIStroke"); ps.Color = Color3.fromRGB(30, 18, 40); ps.Thickness = 1; ps.Transparency = 0.4; ps.Parent = pill
		local plate = Instance.new("Frame")
		plate.Name = "Plate"
		plate.AnchorPoint = Vector2.new(0.5, 0)
		plate.Position = UDim2.fromScale(0.5, 0.15)
		plate.Size = UDim2.fromScale(1, 0.62)
		plate.BackgroundColor3 = Color3.fromRGB(22, 16, 30)
		plate.BackgroundTransparency = 0.12
		plate.Parent = top
		local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0.18, 0); c.Parent = plate
		local rim = Instance.new("UIStroke"); rim.Color = accent:Lerp(Color3.new(1, 1, 1), 0.35); rim.Thickness = 3; rim.ApplyStrokeMode = Enum.ApplyStrokeMode.Border; rim.Parent = plate
		local title = Instance.new("TextLabel")
		title.Name = "Title"
		title.BackgroundTransparency = 1
		title.Position = UDim2.fromScale(0.05, 0.14)
		title.Size = UDim2.fromScale(0.9, 0.5)
		title.Text = info.Title
		title.TextScaled = true
		title.FontFace = Theme.Fonts.Heading
		title.TextColor3 = Color3.new(1, 1, 1)
		title.Parent = plate
		local sub = Instance.new("TextLabel")
		sub.Name = "Subtitle"
		sub.BackgroundTransparency = 1
		sub.Position = UDim2.fromScale(0.08, 0.66)
		sub.Size = UDim2.fromScale(0.84, 0.22)
		sub.Text = info.Subtitle
		sub.TextScaled = true
		sub.FontFace = Theme.Fonts.Name
		sub.TextColor3 = accent:Lerp(Color3.new(1, 1, 1), 0.55)
		sub.Visible = info.Subtitle ~= ""
		sub.Parent = plate
		top.Parent = playerGui

		local low = Instance.new("BillboardGui")
		low.Name = "StandButton"
		low.Adornee = rec.root
		low.Size = UDim2.fromScale(4.6, 1.15)
		low.StudsOffsetWorldSpace = Vector3.new(0, -0.6, 0)
		low.LightInfluence = 0
		low.MaxDistance = 90
		low.Active = true
		low.ResetOnSpawn = false
		local button = Instance.new("TextButton")
		button.Name = "View"
		button.Size = UDim2.fromScale(1, 1)
		button.BackgroundColor3 = accent:Lerp(Color3.new(1, 1, 1), 0.15)
		button.AutoButtonColor = true
		button.TextScaled = true
		button.FontFace = Theme.Fonts.Button
		button.TextColor3 = Color3.new(1, 1, 1)
		button.Parent = low
		local bc = Instance.new("UICorner"); bc.CornerRadius = UDim.new(0.5, 0); bc.Parent = button
		local bs = Instance.new("UIStroke"); bs.Color = Color3.new(1, 1, 1); bs.Thickness = 2; bs.Transparency = 0.15; bs.ApplyStrokeMode = Enum.ApplyStrokeMode.Border; bs.Parent = button
		local bp = Instance.new("UIPadding"); bp.PaddingTop = UDim.new(0.2, 0); bp.PaddingBottom = UDim.new(0.2, 0); bp.PaddingLeft = UDim.new(0.08, 0); bp.PaddingRight = UDim.new(0.08, 0); bp.Parent = button
		local ts = Instance.new("UIStroke"); ts.Color = Color3.fromRGB(30, 18, 40); ts.Thickness = 1.5; ts.Transparency = 0.3; ts.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual; ts.Parent = button
		low.Parent = playerGui
		rec.sign, rec.buttonGui, rec.button = top, low, button

		local function refresh()
			local owned = info.Key ~= nil and State.owns(info.Key)
			local text, mark = Rules.button(info, owned, livePrice[info.Id])
			button.Text = if mark then Format.RobuxMark .. " " .. text else text
		end
		rec.refresh = refresh
		refresh()
		button.Activated:Connect(function()
			local owned = info.Key ~= nil and State.owns(info.Key)
			if owned then
				Toast.show("You own " .. info.Title .. ".")
			elseif Rules.canPrompt(info, owned) then
				local ok = pcall(MarketplaceService.PromptGamePassPurchase, MarketplaceService, player, info.Id)
				if not ok then Toast.show("The purchase couldn't open. Try again.") end
			else
				Toast.show(info.Title .. " is coming soon.") -- (never opens a purchase: Shared/AvatarStandRules)
				if not rec.warned then
					rec.warned = true
					warn("[Huzz] Avatar stand " .. rec.stand:GetFullName() .. " isn't on sale: " .. info.Why)
				end
			end
		end)
	end

	local function clear(rec)
		for _, k in { "copy", "disc", "sign", "buttonGui" } do
			if rec[k] then rec[k]:Destroy() rec[k] = nil end
		end
		if rec.hidden then
			for part, was in rec.hidden do
				if part.Parent then part.LocalTransparencyModifier, part.CanCollide = was[1], was[2] end
			end
			rec.hidden = nil
		end
		rec.track, rec.motion, rec.r6 = nil, nil, nil
	end

	local function build(stand: Instance)
		local rec = stands[stand] or { stand = stand }
		stands[stand] = rec
		clear(rec)
		local copy = copyAvatar()
		if not copy then return end
		rec.info = Rules.resolve(attrs(stand), Products)
		rec.accent = accentOf(stand, rec.info)
		if rec.info.Status == "Ready" and livePrice[rec.info.Id] == nil then
			livePrice[rec.info.Id] = false
			task.spawn(function()
				local ok, data = pcall(MarketplaceService.GetProductInfo, MarketplaceService, rec.info.Id, Enum.InfoType.GamePass)
				if ok and data and type(data.PriceInRobux) == "number" then
					livePrice[rec.info.Id] = data.PriceInRobux
					for _, r in stands do if r.refresh then r.refresh() end end
				end
			end)
		end
		local cf, size = box(stand)
		local mode = stand:GetAttribute("StandOn")
		local onFloor
		if type(mode) == "string" and key(mode) == "top" then onFloor = false
		elseif type(mode) == "string" and key(mode) == "floor" then onFloor = true
		else onFloor = size.Y >= 1.5 * math.max(size.X, size.Z) end
		local footY = cf.Position.Y + (if onFloor then -size.Y / 2 else size.Y / 2)
		if onFloor then
			-- the block turns into your character: hide it on this screen only (the owner still sees it in Studio)
			rec.hidden = {}
			local parts = if stand:IsA("BasePart") then { stand } else stand:GetDescendants()
			for _, p in parts do
				if p:IsA("BasePart") then
					local okT, t = pcall(function() return p.LocalTransparencyModifier end)
					rec.hidden[p] = { if okT and t then t else 0, p.CanCollide }
					p.LocalTransparencyModifier = 1
					p.CanCollide = false -- (this screen only: you walk through where the block was, onto your copy's spot)
				end
			end
		end
		local root = copy:FindFirstChild("HumanoidRootPart") :: BasePart
		root.Anchored = true
		local look = cf.LookVector
		rec.yaw = rec.yaw or LeaderRules.yawTo(0, 0, look.X, look.Z)
		rec.at = Vector3.new(cf.Position.X, footY + hipOffset(copy), cf.Position.Z)
		root.CFrame = CFrame.new(rec.at) * CFrame.Angles(0, rec.yaw, 0)
		copy.Parent = holder
		rec.copy, rec.root = copy, root
		startRun(rec)
		glow(rec, footY, cf.Position, math.min(size.X, size.Z))
		signs(rec)
	end

	local function tryBuild(stand: Instance)
		local ok, err = pcall(build, stand)
		if not ok then warn("[Huzz] avatar stand: " .. tostring(err)) end
	end

	local function rebuildAll()
		for stand in stands do
			if stand.Parent then tryBuild(stand) else clear(stands[stand]); stands[stand] = nil end
		end
	end

	local function consider(d: Instance)
		if not stands[d] and isStand(d) then
			stands[d] = { stand = d }
			task.defer(tryBuild, d)
		end
	end

	for _, d in Workspace:GetDescendants() do consider(d) end
	pcall(function()
		Workspace.DescendantAdded:Connect(function(d)
			if d:IsA("BasePart") or d:IsA("Model") then consider(d) end
		end)
		Workspace.DescendantRemoving:Connect(function(d)
			local rec = stands[d]
			if rec then clear(rec) stands[d] = nil end
		end)
	end)
	pcall(function()
		CollectionService:GetInstanceAddedSignal(TAG):Connect(consider)
	end)
	pcall(function() player.CharacterAdded:Connect(function()
		task.delay(1.5, rebuildAll)
		task.delay(6, rebuildAll) -- (accessories that loaded late)
	end) end)
	pcall(function() player.CharacterAppearanceLoaded:Connect(function() task.delay(0.3, rebuildAll) end) end)
	State.changed(function() for _, rec in stands do if rec.refresh then rec.refresh() end end end)

	RunService.RenderStepped:Connect(function(dt)
		local char = player.Character
		local me = char and char:FindFirstChild("HumanoidRootPart")
		for _, rec in stands do
			local root = rec.root
			if root and root.Parent and me then
				local at = me.CFrame.Position
				local dx, dz = at.X - rec.at.X, at.Z - rec.at.Z
				local d2 = dx * dx + dz * dz
				if d2 < NEAR * NEAR then
					if d2 > 1 then
						rec.yaw = LeaderRules.turn(rec.yaw, LeaderRules.yawTo(rec.at.X, rec.at.Z, at.X, at.Z), dt, TURN)
						root.CFrame = CFrame.new(rec.at) * CFrame.Angles(0, rec.yaw, 0)
					end
					stepRun(rec, dt)
				end
			end
		end
	end)
end

return M
