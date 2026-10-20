--[[
	The knife effects that live on this screen only (owner, Oct 20: "make the vfx for some swords way better and more
	detailed, make them better for more high end ones"; the coordinator: "keep it light on performance ... drop worn
	effects for far-away players").
	1. Ball motes: Huss Valley's MELON5MAN has two or three crisp glowing balls drifting round the blade, which soft
	   particles can't match. Every knife the server marked (Shared/KnifeFx: tag "HuzzKnifeMotes", attributes Motes,
	   MoteColor, MoteSize, MoteDrift, MoteSeed; in hand, worn, and the lobby stands' copies) gets that many small
	   Neon balls here, made on this screen only (moving parts made on the server would replicate every frame), all
	   moved by one RenderStepped loop with Shared/KnifeMotes: soft paths off the blade's edges, fading in and out
	   over 0.8 s, never a pop or a blink. CastShadow, CanCollide, CanQuery and CanTouch off, Massless, Anchored, in
	   one folder ("HuzzKnifeMotes" in Workspace).
	2. Four times a second: knives more than RANGE studs from the camera lose their balls, a worn knife's particles
	   (KnifeService "HuzzBackKnife") switch off past RANGE, and every knife's particles and balls switch off while
	   its player is Invisible (character InvisibleUntil, as Gameplay/PowerEffects fades the body: they'd give them
	   away; the gem's glow is a part on the knife, so it fades with the body).
	Errors go to Output on "[Huzz] KnifeFxRange:" lines; one knife's error never stops the others.
]]
local KnifeMotes = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("KnifeMotes"))

local M = {}

M.RANGE = 70 -- studs
M.EVERY = 0.25 -- seconds
M.TAG = "HuzzKnifeMotes" -- (Shared/KnifeFx.TAG)

local function invisible(character: Instance?, now: number): boolean
	local untilT = character and character:GetAttribute("InvisibleUntil")
	return type(untilT) == "number" and now < untilT
end

function M.start()
	local Players = game:GetService("Players")
	local Workspace = game:GetService("Workspace")
	local RunService = game:GetService("RunService")
	local CollectionService = game:GetService("CollectionService")
	local folder = Instance.new("Folder")
	folder.Name = "HuzzKnifeMotes"
	folder.Parent = Workspace
	local live = {} -- [Model] = { area, balls = { Part }, n, size, drift, seed }

	local function drop(model)
		local rec = live[model]
		if not rec then return end
		for _, b in rec.balls do b:Destroy() end
		live[model] = nil
	end

	local function make(model: Model, area: BasePart)
		local n = math.clamp(math.floor(tonumber(model:GetAttribute("Motes")) or 0), 0, 4)
		if n == 0 then return end
		local colour = model:GetAttribute("MoteColor")
		local size = tonumber(model:GetAttribute("MoteSize")) or 0.15
		local rec = { area = area, balls = {}, n = n, size = size, drift = tonumber(model:GetAttribute("MoteDrift")) or 0,
			seed = tonumber(model:GetAttribute("MoteSeed")) or 0 }
		for _ = 1, n do
			local b = Instance.new("Part")
			b.Name = "KnifeFxMote"
			b.Shape = Enum.PartType.Ball
			b.Material = Enum.Material.Neon
			b.Color = if typeof(colour) == "Color3" then colour else Color3.new(1, 1, 1)
			b.Size = Vector3.new(size, size, size)
			b.Transparency = 1
			b.Anchored, b.CanCollide, b.CanQuery, b.CanTouch, b.CastShadow, b.Massless = true, false, false, false, false, true
			b.CFrame = area.CFrame
			b.Parent = folder
			table.insert(rec.balls, b)
		end
		live[model] = rec
	end

	-- the balls, every frame
	RunService.RenderStepped:Connect(function()
		local t = os.clock()
		for model, rec in live do
			local ok, err = pcall(function()
				if not rec.area.Parent then drop(model) return end
				local cf = rec.area.CFrame
				for i, b in rec.balls do
					local offset, rise, tr = KnifeMotes.at(i, rec.n, t, rec.seed, rec.area.Size, rec.size, rec.drift)
					b.CFrame = CFrame.new(cf * offset + Vector3.new(0, rise, 0))
					b.Transparency = tr
				end
			end)
			if not ok then
				warn("[Huzz] KnifeFxRange: " .. tostring(err))
				drop(model)
			end
		end
	end)

	-- which knives get balls and particles, four times a second
	task.spawn(function()
		while true do
			task.wait(M.EVERY)
			local camera = Workspace.CurrentCamera
			local eye = camera and camera.CFrame.Position
			local now = Workspace:GetServerTimeNow()
			if eye then
				-- worn and held knives: particles off far away (worn) or while Invisible
				for _, player in Players:GetPlayers() do
					local ok, err = pcall(function()
						local c = player.Character
						local hidden = invisible(c, now)
						for _, name in { "HuzzBackKnife", "HuzzKnife" } do
							local knife = c and c:FindFirstChild(name)
							local area = knife and knife:FindFirstChild("KnifeFxArea", true)
							if area and area:IsA("BasePart") then
								local on = not hidden and (name == "HuzzKnife" or (area.CFrame.Position - eye).Magnitude <= M.RANGE)
								for _, d in knife:GetDescendants() do
									if d:IsA("ParticleEmitter") and string.find(d.Name, "^KnifeFx") and d.Enabled ~= on then
										d.Enabled = on
									end
								end
							end
						end
					end)
					if not ok then warn("[Huzz] KnifeFxRange: " .. tostring(err)) end
				end
				-- ball motes: every marked knife in range and not on an Invisible player
				local okT, tagged = pcall(function() return CollectionService:GetTagged(M.TAG) end)
				local want = {}
				for _, model in (if okT then tagged else {}) do
					local ok, err = pcall(function()
						if not model:IsA("Model") or not model:IsDescendantOf(Workspace) then return end
						local area = model:FindFirstChild("KnifeFxArea", true)
						if not (area and area:IsA("BasePart")) then return end
						local owner = model:FindFirstAncestorWhichIsA("Model")
						if (area.CFrame.Position - eye).Magnitude <= M.RANGE and not invisible(owner, now) then
							want[model] = area
						end
					end)
					if not ok then warn("[Huzz] KnifeFxRange: " .. tostring(err)) end
				end
				for model in live do
					if not want[model] then drop(model) end
				end
				for model, area in want do
					if not live[model] then
						local ok, err = pcall(make, model, area)
						if not ok then warn("[Huzz] KnifeFxRange: " .. tostring(err)) end
					end
				end
			end
		end
	end)
end

return M
