--[[
	Lobby avatar stands that show a Game Pass (owner, Oct 18: "make the blocks i have in the lobby, next to the spin
	the wheel turn into my character and have like animated running or something along those lines, selling a
	gamepass"; reference: Huss Valley's stands, clones of YOUR avatar with a sign and a price button).

	Any Part or Model named "AvatarStand" (also "AvatarStand 2" ...) or tagged "HuzzAvatarStand" becomes one. In his
	own place (synced by Rojo, where nothing renamed his blocks) HuzzServer/AvatarStandService finds his six grey
	blocks beside the spin wheels and tags them, so the stands work there too with no steps. Its attributes, typed in
	Studio's Properties:
	  Pass      a Game Pass key from Config/Products ("VIP", "DancePack") or a Game Pass ID number
	  Title     the big words (default: the pass's name);  Subtitle: what it gives (default: its blurb)
	  Tag       the little pill over the sign (default "GAME PASS");  Price: Robux to show (default: Products)
	  Color     the glow and button colour (default: the pass's colour, else Huss Valley green)
	  Knife     the exclusive knife in your copy's hand (owner: "equipped with some exclusive knifes"): a key of
	            one of that pass's knives in Config/CoinShop (e.g. "CelestialSeraph"); unset, the server picks the
	            pass's knives in turn. The model comes ready in ReplicatedStorage > HuzzStandKnives (AvatarStandService).
	  StandOn   "Floor" (the block turns into your character: it hides and you stand where it stood) or "Top"
	            (you stand on top of it). Default: a tall block (like his 4 x 8 x 4 ones) turns into you, a flat
	            one is a pedestal.
	On each screen a copy of THAT player's own avatar stands there. Holding a pass knife it shows the knife off
	(owner, Oct 18: "for these make them showcase the swords that the gamepass includes. For example the swinging
	animation, make it look good though"): Shared/StandShowcase, a ready guard with the blade up in front, and every
	~3 s a combo, a flourish or a rising cut ending in a twirl, the slash trail during the cuts; each stand has its
	own timing and order (seed from its spot). Oct 19 (owner: "right now its very small and you dont even notice it";
	"make the knife animations look like the ones i have attached in the video"): the knife is BIG (about 4.4 studs,
	KnifeService.display scales it), with its stand effects (Shared/KnifeFx: Rare and up, Oct 20), and each knife
	has its own hold and moves (Shared/StandShowcase.STYLES: big arcs, a spin slash, flicks, a raised spin); a move's
	burst would throw the knife's KnifeBurst particles out, but stand copies carry none (Shared/KnifeLook.vfx: only a
	slash in hand throws sparkles; Huss Valley shows no spark showers).
	Without a knife it runs in place with the game's run (the
	owner's run animation when it can play here, Shared/AnimationLibrary "Run"; otherwise Shared/RunMotion, the
	scripted Huss Valley run, on R15; a simple swing on R6). It turns to face you like the leaderboards. No disc under
	the feet any more (owner, Oct 19 evening: "without that green circle on the bottom ... add some vfx, make the
	characters more atrractive"): an aura in the knife's own colours (Shared/KnifeLook.AURA: specks rising from round
	the feet, a few stars twinkling round the body, a soft light on the character). Above: the tag,
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
	local CoinShop = require(Shared.Config.CoinShop)
	local KnifeLook = require(Shared.KnifeLook)
	local FxTexture = require(Shared.FxTexture)
	local LeaderConfig = require(Shared.Config.Leaderboards)
	local Rules = require(Shared.AvatarStandRules)
	local LeaderRules = require(Shared.LeaderboardRules)
	local RunMotion = require(Shared.RunMotion)
	local StandShowcase = require(Shared.StandShowcase)
	local Library = require(Shared.AnimationLibrary)
	local Format = require(Shared.Format)
	local UI = script.Parent.Parent.UI
	local Theme = require(UI.Theme)
	local State = require(UI.State)
	local Toast = require(UI.Toast)

	local player = Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui")
	local TAG = "HuzzAvatarStand"
	local NEAR = StandShowcase.NEAR -- copies further away than this stop moving
	local SPEED = 26 -- the run's pace (studs a second: a runner's sprint)
	local TURN_MAX, TURN_BEHIND = math.rad(70), math.rad(130) -- (it turns to you in real time, like the boards)

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
		local ok, has = pcall(function() return d:HasTag(TAG) end)
		if ok and has == true then return true end
		ok, has = pcall(function() return CollectionService:HasTag(d, TAG) end)
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

	-- The sword showcase (Shared/StandShowcase) on a copy holding a knife: the pose, the knife's turn in the fist
	-- (twirls) and the trail during cuts.
	local function stepShowcase(rec)
		local pose = StandShowcase.step(rec.showcase, os.clock())
		local weld = rec.knifeWeld
		if weld and weld.Parent then
			weld.C0 = CFrame.new(rec.gripAt) * StandShowcase.knifeTurn(pose, rec.handTurn) -- (twirls, and the broad face out at rest)
		end
		if rec.trail and rec.trail.Enabled ~= pose.trail then rec.trail.Enabled = pose.trail end
		-- the move's burst of the knife's element (once per burst; not on the first frame seen, mid-move)
		local id = if pose.burst then pose.loop * 10 + pose.burst else nil
		if id and id ~= rec.lastBurst and rec.lastBurst ~= nil and rec.burster and rec.burster.Parent then
			pcall(function() rec.burster:Emit(rec.burstCount) end)
		end
		rec.lastBurst = id or rec.lastBurst or -1
	end

	local function stepRun(rec, dt: number)
		if rec.showcase then
			stepShowcase(rec)
			return
		end
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

	-- The pass's exclusive knife in the copy's right hand (the hand's grip, the knife's own Grip attachment, as
	-- HuzzServer/KnifeService holds a catcher's knife). The ready model comes from ReplicatedStorage.HuzzStandKnives.
	local function mountKnife(rec, knifeKey: string, template: Instance)
		local copy = rec.copy
		if not copy or not copy.Parent then return end
		local old = copy:FindFirstChild("StandKnife")
		if old then old:Destroy() end
		local hand = copy:FindFirstChild("RightHand") or copy:FindFirstChild("Right Arm")
		if not (hand and hand:IsA("BasePart")) then return end
		local knife = template:Clone()
		knife.Name = "StandKnife"
		local handle = knife:FindFirstChild("Handle", true)
		if not (handle and handle:IsA("BasePart")) then knife:Destroy() return end
		for _, d in knife:GetDescendants() do
			if d:IsA("BasePart") then
				d.Anchored, d.CanCollide, d.CanTouch, d.CanQuery, d.Massless = false, false, false, false, true
			end
		end
		local grip = hand:FindFirstChild("RightGripAttachment")
		local at = if grip and grip:IsA("Attachment") then grip.Position else Vector3.new(0, -hand.Size.Y / 2 + 0.1, 0)
		local own = handle:FindFirstChild("Grip")
		local weld = Instance.new("Weld")
		weld.Name = "StandKnifeGrip"
		weld.Part0, weld.Part1 = hand, handle
		weld.C0 = KnifeLook.handC0(at)
		weld.C1 = if own and own:IsA("Attachment") then own.CFrame else CFrame.identity
		weld.Parent = handle
		knife:SetAttribute("Knife", knifeKey)
		-- the slash trail for the showcase's cuts (as KnifeService's, a little longer so the arc reads)
		local base = knife:FindFirstChild("StandTrailBase", true) or knife:FindFirstChild("TrailBase", true) -- (halfway up the blade: a crescent, not a sheet)
		local tip = knife:FindFirstChild("TrailTip", true)
		local trail = nil
		if base and tip and base:IsA("Attachment") and tip:IsA("Attachment") then
			local tl = KnifeLook.trailLook(CoinShop.get(knifeKey), KnifeLook.element(knifeKey))
			trail = Instance.new("Trail")
			trail.Name = "StandSlash"
			trail.Attachment0, trail.Attachment1 = base, tip
			trail.Lifetime = StandShowcase.TRAIL_LIFETIME
			trail.MinLength = 0
			trail.FaceCamera = false
			trail.LightEmission = tl.light
			trail.Color = ColorSequence.new(tl.colours[1], tl.colours[2])
			trail.Transparency = NumberSequence.new(tl.transparency[1], tl.transparency[2])
			pcall(function() trail.WidthScale = NumberSequence.new(1, 0.3) end) -- (a crescent: full at the blade, thin at the end)
			trail.Enabled = false
			trail.Parent = handle
		end
		knife.Parent = copy
		rec.knifeWeld, rec.gripAt, rec.handTurn, rec.trail = weld, at, KnifeLook.handC0(at).Rotation, trail
		local burster = knife:FindFirstChild("KnifeBurst", true)
		rec.burster = if burster and burster:IsA("ParticleEmitter") then burster else nil
		rec.burstCount = knife:GetAttribute("Burst") or 12
	end

	local function knifeFor(rec)
		local key = rec.knifeKey
		if not key then return end
		local folder = ReplicatedStorage:FindFirstChild("HuzzStandKnives")
		local template = folder and folder:FindFirstChild(key)
		if template then
			pcall(mountKnife, rec, key, template)
			return
		end
		local copy = rec.copy
		task.spawn(function() -- (streamed in late: wait for it, then only if this copy is still the one shown)
			local f = ReplicatedStorage:WaitForChild("HuzzStandKnives", 30)
			local t = f and f:WaitForChild(key, 30)
			if t and rec.copy == copy then pcall(mountKnife, rec, key, t) end
		end)
	end

	-- The aura (Shared/KnifeLook.AURA; owner, Oct 19 evening: "make the gamepass characters look better without that
	-- green circle on the bottom, and add some vfx, make the characters more atrractive so people buy the knifes"):
	-- no disc under the feet. In the stand's colour (its knife's element, else the pass colour): soft specks rising
	-- from a ring round the feet, a few stars twinkling round the body, a soft light in front of the chest. Two
	-- invisible parts hold the emitters (round, so the copy's turning doesn't matter); the light rides on the copy.
	local function aura(rec, floorY: number, centre: Vector3)
		local A = KnifeLook.AURA
		local colour = rec.glow
		local white = Color3.new(1, 1, 1)
		local function holderPart(name: string, size: Vector3, at: Vector3): Part
			local p = Instance.new("Part")
			p.Name = name
			p.Anchored, p.CanCollide, p.CanTouch, p.CanQuery, p.CastShadow = true, false, false, false, false
			p.Transparency = 1
			p.Size = size
			p.CFrame = CFrame.new(at)
			p.Parent = holder
			return p
		end
		local function emit(parent: BasePart, name: string, spec, shape: string)
			local e = Instance.new("ParticleEmitter")
			e.Name = name
			e.Color = ColorSequence.new(colour:Lerp(white, spec.whiten), colour)
			e.LightEmission, e.LightInfluence = 1, 0
			e.Rate = spec.rate
			e.Lifetime = NumberRange.new(spec.life[1], spec.life[2])
			e.Rotation = NumberRange.new(0, 360)
			e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.25, 0.25), NumberSequenceKeypoint.new(1, 1) })
			e.EmissionDirection = Enum.NormalId.Top
			pcall(function()
				e.Shape = Enum.ParticleEmitterShape.Cylinder
				e.ShapeStyle = if shape == "ring" then Enum.ParticleEmitterShapeStyle.Surface else Enum.ParticleEmitterShapeStyle.Volume
			end)
			e.Parent = parent
			return e
		end
		local ring = holderPart("StandAura", Vector3.new(A.Width, 0.2, A.Width), Vector3.new(centre.X, floorY + 0.15, centre.Z))
		local M = A.Motes
		local motes = emit(ring, "AuraMotes", M, "ring")
		motes.Speed = NumberRange.new(M.speed[1], M.speed[2])
		motes.Acceleration = Vector3.new(0, M.rise, 0)
		motes.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.2, M.size), NumberSequenceKeypoint.new(1, 0) })
		motes.Texture = FxTexture.get(M.texture)
		local column = holderPart("StandAuraBody", Vector3.new(A.Width, A.Height, A.Width), Vector3.new(centre.X, floorY + A.Height / 2, centre.Z))
		local T = A.Twinkles
		local stars = emit(column, "AuraTwinkles", T, "body")
		stars.Speed = NumberRange.new(0)
		stars.RotSpeed = NumberRange.new(-40, 40)
		stars.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.45, T.size), NumberSequenceKeypoint.new(1, 0) })
		FxTexture.flipbook(stars, T.texture, "Random")
		local root = rec.root
		if root then
			local at = Instance.new("Attachment")
			at.Name = "StandAuraLight"
			at.CFrame = CFrame.new(0, A.Light.Up, -A.Light.Front) -- (in front of the chest: it lights the character, not a pool on the floor)
			at.Parent = root
			local light = Instance.new("PointLight")
			light.Color, light.Brightness, light.Range, light.Shadows = colour:Lerp(white, A.Light.Whiten), A.Light.Brightness, A.Light.Range, false
			light.Parent = at
		end
		rec.aura = { ring, column }
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
		for _, k in { "copy", "sign", "buttonGui" } do
			if rec[k] then rec[k]:Destroy() rec[k] = nil end
		end
		for _, p in rec.aura or {} do p:Destroy() end
		rec.aura = nil
		if rec.hidden then
			for part, was in rec.hidden do
				if part.Parent then part.LocalTransparencyModifier, part.CanCollide = was[1], was[2] end
			end
			rec.hidden = nil
		end
		rec.track, rec.motion, rec.r6, rec.showcase = nil, nil, nil, nil
		rec.knifeWeld, rec.trail, rec.burster, rec.lastBurst = nil, nil, nil, nil
	end

	local standCount = 0
	local function build(stand: Instance)
		local rec = stands[stand] or { stand = stand }
		stands[stand] = rec
		if not rec.number then
			standCount += 1
			rec.number = standCount
		end
		clear(rec)
		local copy = copyAvatar()
		if not copy then return end
		rec.info = Rules.resolve(attrs(stand), Products)
		local knifeKey, why = Rules.knife(rec.info.Key, stand:GetAttribute("Knife"), CoinShop.Items, 1)
		if why and not rec.knifeWarned then
			rec.knifeWarned = true
			warn("[Huzz] Avatar stand " .. stand:GetFullName() .. ": " .. why)
		end
		rec.knifeKey = knifeKey
		if knifeKey then rec.info = Rules.resolve(attrs(stand), Products, CoinShop.get(knifeKey)) end
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
		rec.home = LeaderRules.yawTo(0, 0, look.X, look.Z)
		rec.yaw = rec.yaw or rec.home
		rec.goal, rec.vel = rec.goal or rec.yaw, rec.vel or 0
		rec.at = Vector3.new(cf.Position.X, footY + hipOffset(copy), cf.Position.Z)
		root.CFrame = CFrame.new(rec.at) * CFrame.Angles(0, rec.yaw, 0)
		copy.Parent = holder
		rec.copy, rec.root = copy, root
		if knifeKey then
			-- each stand its own timing (from where it stands) and first move (from its number: the 1st, 2nd and 3rd
			-- stand start on different moves, so stands side by side never play the same move at once)
			local spot = math.floor(math.abs(cf.Position.X) * 3 + math.abs(cf.Position.Z) * 7) % 331
			local seed = spot * 3 + rec.number
			rec.showcase = StandShowcase.new(copy, seed, knifeKey)
		end
		if not rec.showcase then startRun(rec) end
		knifeFor(rec)
		local el = knifeKey and KnifeLook.element(knifeKey)
		rec.glow = if el then el.light else rec.accent -- (the aura in the knife's own colours)
		aura(rec, footY, cf.Position)
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
			pcall(function()
				d:GetAttributeChangedSignal("Knife"):Connect(function()
					if stands[d] then task.defer(tryBuild, d) end
				end)
			end)
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
					-- the same real-time turn as the boards (Shared/LeaderboardRules aim + turn; owner: "follow me in real time")
					local want = LeaderRules.aim(rec.home, rec.at.X, rec.at.Z, at.X, at.Z, TURN_MAX, TURN_BEHIND, NEAR)
					local before = rec.yaw
					rec.yaw = LeaderRules.turn(rec.yaw, want, math.min(dt, 0.1), LeaderConfig.TurnRate)
					if rec.yaw ~= before then root.CFrame = CFrame.new(rec.at) * CFrame.Angles(0, rec.yaw, 0) end
					stepRun(rec, dt)
				end
			end
		end
	end)
end

return M
