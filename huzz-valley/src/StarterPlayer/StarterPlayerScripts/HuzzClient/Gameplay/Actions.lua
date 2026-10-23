--[[
	The catchers' move: STAB (while a round runs): left click, a gamepad's R2, or the STAB button.
	It plays at once on your own screen; the runner inside your knife's reach on your screen (Gameplay/HitCheck,
	"make hitboxes pinpoint") is sent to the server (RoundService), which checks it's possible and tags them. (The girl toss is gone: owner's call.)

	Also plays everyone's stab (Shared/StabMotion, or Config/Animations.Stab when set), the Practice Bot's
	too (RoundService sends "Stab" with bot = true), and lights the knife's slash trail. Oct 19 (owner: "better knife
	animations, not only during gameplay"): an Epic or better knife also draws a thin crescent round the front and
	right of the catcher as the arm sweeps (Shared/KnifeLook.ARC, in the knife's SlashColor, gone in 0.2 s); a knife's
	KnifeBurst throws half of its Burst attribute (Epic and up: a few sparkles in the knife's colour, Shared/KnifeFx).
	Buttons sit bottom right, above a phone's jump
	button, and only show when the move is available.
	Knife pass 2 (Oct 19, the lunge): your own lunge plays the moment you press Space (M.lungeLocal from Gameplay/Dash;
	it used to wait for the server's echo, a network round trip late); the echo is ignored. A lunge's slash (and its
	arc and burst) starts when the knife reaches someone (M.lungeHit from Dash on your screen; the server's Caught on
	everyone else's), else LEAP.SlashBy into the leap (Shared/StabMotion). The leap draws a soft ribbon from the
	body (Shared/KnifeLook.CATCH.Streak: white into the knife's colour, about 8 studs, on for the push only).
	Knife check (Oct 19): a long blade is held more forward in hand so its tip clears the floor (KnifeLook.handC0);
	during a stab or a lunge it eases back to the usual angle (KnifeLook.slashC0) and returns after.
]]
local M = {}

function M.start()
	local Players = game:GetService("Players")
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local RunService = game:GetService("RunService")
	local UserInputService = game:GetService("UserInputService")
	local TweenService = game:GetService("TweenService")
	local Workspace = game:GetService("Workspace")

	local Shared = ReplicatedStorage:WaitForChild("Shared")
	local Net = require(Shared.Net)
	local Config = require(Shared.Config.Round)
	local Animations = require(Shared.Config.Animations)
	local CarryMath = require(Shared.CarryMath)
	local StabMotion = require(Shared.StabMotion)
	local KnifeLook = require(Shared.KnifeLook)
	local Sfx = require(script.Parent.Sfx)
	local HitCheck = require(script.Parent.HitCheck)

	local player = Players.LocalPlayer
	local RoundNet = Net.get("Round") :: RemoteEvent
	local StabNet = Net.get("Stab") :: RemoteEvent

	-- Everyone's stabs, keyed by Player, or "bot" for the Practice Bot (never by a character Instance in a weak table).
	local stabs = {} -- Player | "bot" -> { rec, character, trail, track }
	local localLungeAt = -math.huge -- (os.clock of your own lunge: the server's echo of it is ignored)

	-- The leap's ribbon (KnifeLook.CATCH.Streak): one Trail per character, between two points on the UpperTorso.
	local function streakOf(character)
		local torso = character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso") -- (R6: its one Torso)
		if not (torso and torso:IsA("BasePart")) then return nil end
		local trail = torso:FindFirstChild("HuzzLungeStreak")
		if trail then return trail end
		local St = KnifeLook.CATCH.Streak
		local ok, made = pcall(function()
			local a0 = Instance.new("Attachment")
			a0.Name = "HuzzStreak0"
			a0.Position = Vector3.new(0, St.Top, 0)
			a0.Parent = torso
			local a1 = Instance.new("Attachment")
			a1.Name = "HuzzStreak1"
			a1.Position = Vector3.new(0, St.Bottom, 0)
			a1.Parent = torso
			local t = Instance.new("Trail")
			t.Name = "HuzzLungeStreak"
			t.Attachment0, t.Attachment1 = a0, a1
			t.Lifetime = St.Life
			t.MinLength = 0
			t.FaceCamera = false
			t.LightEmission, t.LightInfluence = St.LightEmission, 0
			t.Transparency = NumberSequence.new(St.Transparency[1], St.Transparency[2])
			pcall(function() t.WidthScale = NumberSequence.new(1, 0.5) end)
			t.Enabled = false
			t.Parent = torso
			return t
		end)
		return if ok then made else nil
	end

	-- The dive seen by everyone (KnifeLook.CATCH.Dive; owner, Oct 21 14:53: "make the leaping visible, not just
	-- disappearing"): a puff of dust at the feet as it springs and again as the belly lands, and a soft outline in
	-- the knife's colour that fades out over the dive. Made here, destroyed after (never saved).
	local function diveFx(character, colour: Color3)
		local root = character:FindFirstChild("HumanoidRootPart")
		if not (root and root:IsA("BasePart")) then return end
		local D = KnifeLook.CATCH.Dive
		pcall(function()
			local feet = Instance.new("Attachment")
			feet.Name = "HuzzDiveDust"
			feet.Position = Vector3.new(0, -2.6, 0)
			feet.Parent = root
			local dust = Instance.new("ParticleEmitter")
			dust.Name = "HuzzDiveDust"
			dust.Texture = "rbxasset://textures/particles/smoke_main.dds"
			dust.Color = ColorSequence.new(Color3.fromRGB(235, 230, 220), colour)
			dust.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 1) })
			dust.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.8), NumberSequenceKeypoint.new(1, 2.6) })
			dust.Lifetime = NumberRange.new(0.35, 0.6)
			dust.Speed = NumberRange.new(6, 12)
			dust.SpreadAngle = Vector2.new(80, 15)
			dust.EmissionDirection = Enum.NormalId.Top
			dust.Drag = 6
			dust.LightEmission = 0.3
			dust.Rate = 0
			dust.Parent = feet
			dust:Emit(D.Dust)
			task.delay(D.LandAt, function() if dust.Parent then dust:Emit(D.LandDust) end end)
			task.delay(1.4, function() feet:Destroy() end)
		end)
		pcall(function()
			local old = character:FindFirstChild("HuzzDiveGlow")
			if old then old:Destroy() end
			local glow = Instance.new("Highlight")
			glow.Name = "HuzzDiveGlow"
			glow.FillTransparency = 1
			glow.OutlineColor = colour
			glow.OutlineTransparency = D.GlowTransparency
			glow.DepthMode = Enum.HighlightDepthMode.Occluded
			glow.Adornee = character
			glow.Parent = character
			TweenService:Create(glow, TweenInfo.new(D.Glow, Enum.EasingStyle.Sine, Enum.EasingDirection.In), { OutlineTransparency = 1 }):Play()
			task.delay(D.Glow + 0.05, function() glow:Destroy() end)
		end)
	end

	-- The slash arc and the element's burst for one stab (Shared/KnifeLook.ARC): a Beam on two attachments on the root.
	local function dropArc(s)
		if s.arc then
			for _, inst in s.arc.parts do pcall(inst.Destroy, inst) end
			s.arc = nil
		end
	end
	local function slashFx(s, character, ago)
		dropArc(s)
		local knife = character:FindFirstChild("HuzzKnife")
		local root = character:FindFirstChild("HumanoidRootPart")
		if not (knife and root) then return end
		local burst = knife:FindFirstChild("KnifeBurst", true)
		if burst and burst:IsA("ParticleEmitter") then
			pcall(function() burst:Emit(math.ceil((knife:GetAttribute("Burst") or 10) * 0.5)) end)
		end
		local colour = knife:GetAttribute("SlashColor")
		if typeof(colour) ~= "Color3" then return end
		local A = KnifeLook.ARC
		local ok = pcall(function()
			local a0 = Instance.new("Attachment")
			a0.Name = "HuzzArc0"
			a0.CFrame = CFrame.new(A.From) -- (its +X, the way the curve leaves: to the right)
			a0.Parent = root
			local a1 = Instance.new("Attachment")
			a1.Name = "HuzzArc1"
			a1.CFrame = CFrame.fromMatrix(A.To, Vector3.new(0, 0, 1), Vector3.new(0, 1, 0)) -- (its +X backwards: it arrives from the front)
			a1.Parent = root
			local beam = Instance.new("Beam")
			beam.Name = "HuzzSlashArc"
			beam.Attachment0, beam.Attachment1 = a0, a1
			beam.CurveSize0, beam.CurveSize1 = A.Curve, A.Curve
			beam.Width0, beam.Width1 = A.Width[1], A.Width[2]
			beam.Segments = 20
			beam.FaceCamera = true
			beam.LightEmission = A.LightEmission
			beam.LightInfluence = 0
			beam.Color = ColorSequence.new(colour, colour:Lerp(Color3.new(1, 1, 1), 0.6))
			beam.Transparency = NumberSequence.new(1)
			beam.Parent = root
			s.arc = { parts = { beam, a0, a1 }, beam = beam, start = os.clock() - (ago or 0) + A.At }
		end)
		if not ok then dropArc(s) end
	end

	-- ago: how far into the move to start (the bot's stab arrives after its hit, so it starts near the thrust)
	-- lunge: the Space leap (the slash, then a dive into the leap's direction: Shared/StabMotion)
	local function playStab(p, model: Model?, ago: number?, lunge: boolean?)
		local character = model or (typeof(p) == "Instance" and (p :: Player).Character or nil)
		local rig = character and CarryMath.rig(character)
		-- (R6 too: the game is R6 since Oct 22 and StabMotion has had its R6 swing and dive since then, but this
		-- still let only R15 bodies through, so nobody's swing or dive showed; owner, Oct 23 14:10/14:11)
		if not (rig and (rig.kind == "R15" or rig.kind == "R6")) then
			return
		end
		local s = stabs[p]
		if not s or s.character ~= character then
			if s then
				StabMotion.release(s.rec)
			end
			s = { rec = StabMotion.new(rig, character:FindFirstChild("HumanoidRootPart")), character = character }
			stabs[p] = s
		end
		StabMotion.play(s.rec, os.clock() - (ago or 0), lunge)
		s.fxDone = false
		if not lunge then -- (a lunge's slash, arc and burst wait for the knife to reach someone: the Frame loop)
			s.fxDone = true
			slashFx(s, character, ago)
		else
			local knife = character:FindFirstChild("HuzzKnife")
			local colour = knife and knife:GetAttribute("SlashColor")
			colour = if typeof(colour) == "Color3" then colour else Color3.fromRGB(235, 240, 255)
			local streak = streakOf(character)
			if streak then
				streak.Color = ColorSequence.new(Color3.new(1, 1, 1), colour)
				streak.Enabled = true
				s.streak, s.streakUntil = streak, os.clock() + Config.Lunge.Time
			end
			diveFx(character, colour)
		end
		if Animations.Stab ~= "" then
			local humanoid = character:FindFirstChildOfClass("Humanoid")
			local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
			if animator and not s.track then
				local animation = Instance.new("Animation")
				animation.AnimationId = Animations.Stab
				local ok, track = pcall(animator.LoadAnimation, animator, animation)
				if ok then
					track.Priority = Enum.AnimationPriority.Action
					s.track = track
				end
			end
			if s.track then
				s.track:Play(0.05)
			end
		end
	end

	require(script.Parent.Frame).on(30, function()
		local now = os.clock()
		for p, s in stabs do
			local character = s.character
			if not character.Parent or (typeof(p) == "Instance" and p.Parent == nil) then
				dropArc(s)
				stabs[p] = nil
			else
				local root = s.rec.root
				if s.rec.lunge and root then -- the dive leans the way the body is flying (forward or sideways)
					local v = root.CFrame:VectorToObjectSpace(root.AssemblyLinearVelocity)
					if Vector3.new(v.X, 0, v.Z).Magnitude > 8 then StabMotion.setDive(s.rec, v) end
				end
				local playing = StabMotion.step(s.rec, now, Animations.Stab == "")
				local slashAt = playing and s.rec.lunge and StabMotion.slashStart(s.rec, now)
				if slashAt and not s.fxDone then
					s.fxDone = true
					slashFx(s, character, now - slashAt)
				end
				if s.streak and now >= s.streakUntil then
					s.streak.Enabled = false
					s.streak = nil
				end
				local knife = character:FindFirstChild("HuzzKnife")
				local trail = knife and knife:FindFirstChild("SlashTrail", true)
				if trail then
					trail.Enabled = playing and StabMotion.trailOn(s.rec, now)
				end
				-- a long blade is held more forward so it clears the floor (KnifeLook.handC0); in the slash it turns
				-- back to the usual angle, so every knife cuts and leads the leap the same way (KnifeLook.slashC0)
				local grip = knife and knife:FindFirstChild("KnifeGrip", true)
				if grip and grip:IsA("Motor6D") then
					if s.grip ~= grip then s.grip, s.held, s.gripK = grip, grip.C0, 0 end
					local dt = math.clamp(now - (s.gripAt or now), 0, 0.1)
					s.gripAt = now
					local H = KnifeLook.HAND
					s.gripK = if playing then math.min(1, s.gripK + dt / H.In) else math.max(0, s.gripK - dt / H.Out)
					grip.C0 = KnifeLook.slashC0(s.held, s.gripK)
				end
				local arc = s.arc
				if arc then -- the crescent: in fast, fading out, solid in the middle and thin at both ends
					local fade = KnifeLook.arcFade(now - arc.start)
					if now - arc.start > KnifeLook.ARC.Life then
						dropArc(s)
					elseif arc.beam.Parent then
						arc.beam.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, fade),
							NumberSequenceKeypoint.new(1, math.min(1, fade + 0.3)) })
					end
				end
			end
		end
	end)

	RoundNet.OnClientEvent:Connect(function(kind, data)
		if kind == "Stab" and data.bot then
			local CollectionService = game:GetService("CollectionService")
			local bot = CollectionService:GetTagged("HuzzBot")[1]
			if bot and bot:IsA("Model") then
				playStab("bot", bot, if data.hit then 0.12 else 0)
			end
		elseif kind == "Stab" and (data.id ~= player.UserId or data.lunge) then
			local p = Players:GetPlayerByUserId(data.id)
			local echo = data.id == player.UserId and os.clock() - localLungeAt < 0.8 -- (yours already played)
			if p and not echo then
				playStab(p, nil, 0, data.lunge == true)
			end
		elseif kind == "Caught" and type(data) == "table" and type(data.catcher) == "number" then
			-- the leaping knife reached them: the catcher's slash starts now (on the catcher's own screen it already did)
			local p = Players:GetPlayerByUserId(data.catcher)
			local s = p and stabs[p]
			if s then StabMotion.slash(s.rec, os.clock()) end
		end
	end)
	Players.PlayerRemoving:Connect(function(p)
		stabs[p] = nil
	end)

	-- Your own lunge, the moment you press Space (Gameplay/Dash), and the moment its knife reaches someone.
	function M.lungeLocal()
		localLungeAt = os.clock()
		playStab(player, nil, 0, true)
	end
	function M.lungeHit()
		local s = stabs[player]
		if s then StabMotion.slash(s.rec, os.clock()) end
	end

	-- Stunned after your dive (Config/Round.Lunge.Stun, HuzzServer/PowerService.stun): from your own press at once
	-- (the server's StunnedFrom / StunnedUntil arrive a moment later and also count). When the server takes the stun
	-- away early (PowerService.clear at the end of a Hero run sets StunnedUntil to nil), your own press stops counting.
	local stunClearedAt = -math.huge
	player:GetAttributeChangedSignal("StunnedUntil"):Connect(function()
		if player:GetAttribute("StunnedUntil") == nil then
			stunClearedAt = os.clock()
		end
	end)
	function M.stunned(): boolean
		local L = Config.Lunge
		local after = L.StunAfter or L.Time
		local since = os.clock() - localLungeAt
		if localLungeAt > stunClearedAt and since >= after and since < after + (L.Stun or 0) then
			return true
		end
		local t = Workspace:GetServerTimeNow()
		return t >= (player:GetAttribute("StunnedFrom") or math.huge) and t < (player:GetAttribute("StunnedUntil") or 0)
	end

	-- What you can do right now.
	local lastStab = -math.huge
	local function busy()
		local c = player.Character
		return player:GetAttribute("MenuOpen") == true or c == nil or c:GetAttribute("DownedAt") ~= nil
	end
	local function canStab()
		local c = player.Character
		local stage = RoundNet:GetAttribute("Stage")
		return Config.TagMode == "Stab" and player:GetAttribute("HuzzRole") == "Catcher" and (stage == "Running" or stage == "HeroRun")
			and player:GetAttribute("HuzzFrozen") ~= true
			and c ~= nil and c:FindFirstChild("HuzzKnife") ~= nil and not busy()
			and (player:GetAttribute("DizzyUntil") or 0) <= Workspace:GetServerTimeNow() -- a popped Shield
			and not M.stunned()
	end
	local function stab()
		if canStab() and os.clock() - lastStab >= Config.Stab.Cooldown then
			lastStab = os.clock()
			-- (the knife charges back up on your bar: Screens/PowerBar reads this, on your screen only)
			player:SetAttribute("KnifeReady", Workspace:GetServerTimeNow() + Config.Stab.Cooldown)
			playStab(player)
			Sfx.play("stab")
			-- pinpoint (Gameplay/HitCheck): the runner inside your knife's reach on your screen, now or while the
			-- blade comes round (0.1 s); false = a clean miss; nothing sent = this build can't check
			local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
			if not root then
				StabNet:FireServer()
				return
			end
			local S = Config.Stab
			local hit, shown = HitCheck.find(root, S.Reach, S.Width)
			if hit == false then
				StabNet:FireServer()
				return
			end
			if hit then
				StabNet:FireServer(hit, shown) -- (who, and where this screen showed you both: the server judges that)
				return
			end
			task.spawn(function()
				local t0 = os.clock()
				while os.clock() - t0 < 0.1 do
					RunService.Heartbeat:Wait()
					local found, seenNow = nil, nil
					if root.Parent then
						found, seenNow = HitCheck.find(root, S.Reach, S.Width)
					end
					if found then
						StabNet:FireServer(found, seenNow)
						return
					end
				end
				StabNet:FireServer(false)
			end)
		end
	end
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed or UserInputService:GetFocusedTextBox() then
			return
		end
		local t, key = input.UserInputType, input.KeyCode
		if t == Enum.UserInputType.MouseButton1 or key == Enum.KeyCode.ButtonR2 then
			stab()
		end
	end)

	-- On-screen buttons (the kit's periwinkle action style).
	local Theme = require(script.Parent.Parent.UI.Theme)
	local DISPLAY = Theme.Fonts.Heading -- (the kit's faces)
	local ROUNDED = Theme.Fonts.Button
	local C = Theme.Colors
	local ACTION, ACTION_TOP, RIM = C.Action, C.ActionTop, C.ActionRim
	local SLATE = C.Slate
	local gui = Instance.new("ScreenGui")
	gui.Name = "HuzzActions"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 4
	local touch = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled

	local function button(name, label, hint, y, onPress)
		local b = Instance.new("TextButton")
		b.Name = name
		b.AnchorPoint = Vector2.new(1, 1)
		b.Position = UDim2.new(1, -22, 1, y)
		b.Size = UDim2.fromOffset(if touch then 104 else 150, if touch then 104 else 58)
		b.BackgroundColor3 = Color3.new(1, 1, 1)
		b.AutoButtonColor = false
		b.Text = ""
		b.Visible = false
		b.Parent = gui
		local corner = Instance.new("UICorner")
		corner.CornerRadius = if touch then UDim.new(0.5, 0) else UDim.new(0, 10)
		corner.Parent = b
		local stroke = Instance.new("UIStroke")
		stroke.Thickness, stroke.Color = 2.5, RIM
		stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		stroke.Parent = b
		local gradient = Instance.new("UIGradient")
		gradient.Rotation = 90
		gradient.Parent = b
		local text = Instance.new("TextLabel")
		text.BackgroundTransparency = 1
		text.Size = UDim2.new(1, -10, if touch then 0.42 else 0.62, 0)
		text.Position = UDim2.new(0, 5, if touch then 0.24 else 0.06, 0)
		text.FontFace = DISPLAY
		text.Text = label
		text.TextScaled = true
		text.TextColor3 = Color3.new(1, 1, 1)
		text.Parent = b
		local textStroke = Instance.new("UIStroke")
		textStroke.Thickness, textStroke.Color = 1.5, RIM
		textStroke.Parent = text
		local small = Instance.new("TextLabel")
		small.BackgroundTransparency = 1
		small.Size = UDim2.new(1, -10, 0.26, 0)
		small.Position = UDim2.new(0, 5, if touch then 0.64 else 0.66, 0)
		small.FontFace = ROUNDED
		small.Text = if touch then "" else hint
		small.TextScaled = true
		small.TextColor3 = Color3.fromRGB(226, 228, 255)
		small.Parent = b
		b.Activated:Connect(onPress)
		local function paint(ready)
			local top, bottom = if ready then ACTION_TOP else SLATE:Lerp(Color3.new(1, 1, 1), 0.08), if ready then ACTION else SLATE
			gradient.Color = ColorSequence.new(top, bottom)
		end
		paint(true)
		return b, paint
	end
	local y0 = if touch then -150 else -110
	local Device = require(script.Parent.Parent.UI.Device)
	local stabButton, paintStab = button("Stab", "STAB", string.upper(Device.word("Stab") or "CLICK"), y0, stab)
	-- (a phone: a round 74 button left of the CATCH button in the bottom-right group, UI/TouchPad; owner Oct 23,
	-- "make the placement of all the abilities better")
	if touch then require(script.Parent.Parent.UI.TouchPad).place(stabButton, "Left") end
	-- (the hint under STAB says the button you press on what you play with: CLICK, R2 or RT; owner, Oct 21)
	Device.changed(function(kind)
		local small
		for _, l in stabButton:GetChildren() do
			if l:IsA("TextLabel") and l.Text ~= "STAB" then small = l end
		end
		if small then small.Text = if touch then "" else string.upper(Device.word("Stab", kind) or "") end
	end)
	gui.Parent = player:WaitForChild("PlayerGui")

	RunService.RenderStepped:Connect(function()
		stabButton.Visible = canStab()
		if stabButton.Visible then
			paintStab(os.clock() - lastStab >= Config.Stab.Cooldown)
		end
	end)
end

return M
