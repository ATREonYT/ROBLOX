--[[
	CoinFly  (ModuleScript)
	When you land home after a launch, a burst of cash coins jumps off your character and flies into the Cash
	counter, each one bumping it as it lands (vault 13, "Small things worth copying": Stone Skipping's trophies
	fly to the Wins counter). Purely visual: the server has already paid the cash.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local MIN_COINS = 6
local MAX_COINS = 12
local COIN_SIZE = 46 -- px at the 1280x720 design size

return function(ctx)
	local Kit, Config = ctx.Kit, ctx.Config
	local new = Kit.new
	local player = ctx.Player
	local Remotes = ReplicatedStorage:WaitForChild("Remotes")

	local gui = new("ScreenGui", { Name = "CoinFly", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 6, Parent = player.PlayerGui })

	local function cashIcon()
		local row = ctx.Root:FindFirstChild("HUD") and ctx.Root.HUD:FindFirstChild("Currencies")
		row = row and row:FindFirstChild("Cash")
		if not (row and row.Visible) then
			return nil
		end
		return row:FindFirstChild("Icon_Cash") or row:FindFirstChildWhichIsA("GuiObject")
	end

	-- a point on a curve from a to b that bows upward, so coins swoop instead of sliding
	local function bezier(a, c, b, t)
		local u = 1 - t
		return a * u * u + c * 2 * u * t + b * t * t
	end

	local function burst(cash)
		local target = cashIcon()
		local char = player.Character
		local root = char and char:FindFirstChild("HumanoidRootPart")
		if not (target and root) then
			return
		end
		local cam = workspace.CurrentCamera
		local at, onScreen = cam:WorldToViewportPoint(root.Position + Vector3.new(0, 2, 0))
		if not onScreen then
			return
		end
		local scale = math.min(cam.ViewportSize.X / 1280, cam.ViewportSize.Y / 720)
		local size = COIN_SIZE * scale
		local from = Vector2.new(at.X, at.Y)
		local count = math.clamp(MIN_COINS + math.floor(math.log10(math.max(cash, 1))), MIN_COINS, MAX_COINS)
		for i = 1, count do
			local coin = Kit.icon("Cash", { Size = UDim2.fromOffset(size, size), Anchor = Vector2.new(0.5, 0.5), ZIndex = 5, Parent = gui })
			coin.Position = UDim2.fromOffset(from.X, from.Y)
			coin.Rotation = math.random(-30, 30)
			local s = Kit.scale(coin)
			s.Scale = 0
			-- out: a little spray around you
			local angle = math.rad(math.random(0, 360))
			local spray = from + Vector2.new(math.cos(angle), math.sin(angle) * 0.6) * math.random(40, 90) * scale
			task.delay((i - 1) * 0.035, function()
				Kit.tween(s, 0.22, { Scale = 1 }, Enum.EasingStyle.Back)
				local out = TweenService:Create(coin, TweenInfo.new(0.24, Enum.EasingStyle.Quad), { Position = UDim2.fromOffset(spray.X, spray.Y) })
				out:Play()
				out.Completed:Wait()
				task.wait(0.05 + (i - 1) * 0.03)
				-- in: swoop to the counter, speeding up as it goes
				-- both guis ignore the top bar inset, so their pixels line up
				local goal = target.AbsolutePosition + target.AbsoluteSize / 2
				local control = Vector2.new((spray.X + goal.X) / 2, math.min(spray.Y, goal.Y) - 120 * scale)
				local start, dur = os.clock(), 0.42
				while true do
					local t = math.min((os.clock() - start) / dur, 1)
					local p = bezier(spray, control, goal, t * t)
					coin.Position = UDim2.fromOffset(p.X, p.Y)
					s.Scale = 1 - 0.35 * t
					if t >= 1 then
						break
					end
					task.wait()
				end
				coin:Destroy()
				Kit.pop(target, 1.18)
				Kit.playSound("Coin", 1 + math.min(i, 10) * 0.04)
			end)
		end
	end

	-- the same moment as the "+$" over your head: the launch ends and you're home
	local pending = nil
	Remotes.LaunchResult.OnClientEvent:Connect(function(_, cash)
		pending = cash
	end)
	player:GetAttributeChangedSignal("Launching"):Connect(function()
		if player:GetAttribute("Launching") == true or not pending then
			return
		end
		local cash = pending
		pending = nil
		if cash and cash > 0 then
			task.delay(0.15, burst, cash)
		end
	end)
end
