--!strict
-- The first thing you can buy (Config/StarterShop): a small stand inside Liberty Food Mart with a durag, a cap and a
-- chain on pegs (the real accessories, so you see exactly what you get). Buy with the prompt; it goes straight on your
-- avatar and stays on every spawn. Press again to take it off / put it back on. Server-owned: price checks and the
-- save happen here. Save: data.Inventory.Items.Starter = { Owned = { id = true }, Hat = id?, Neck = id? }.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local InsertService = game:GetService("InsertService")

local Config = require(ReplicatedStorage.MTL.Config.StarterShop)
local DataService = require(script.Parent.DataService)
local EconomyService = require(script.Parent.EconomyService)
local Notify = require(script.Parent.Notify)

local StarterShop = {}

local byId: { [string]: any } = {}
for _, it in Config.Items do
	byId[it.id] = it
end

local function log(...)
	print("[MTL StarterShop]", ...)
end

local function state(player: Player): any?
	local data = DataService.get(player)
	if not data then
		return nil
	end
	local items = data.Inventory.Items
	items.Starter = items.Starter or { Owned = {} }
	return items.Starter
end

-- comma list of accessory ids minus every starter item of that slot, plus the worn one
local function mergeIds(list: string, slot: string, wornAsset: number?): string
	local keep = {}
	for idText in string.gmatch(list or "", "[^,%s]+") do
		local n = tonumber(idText)
		local isStarter = false
		for _, it in Config.Items do
			if it.slot == slot and it.asset == n then
				isStarter = true
			end
		end
		if not isStarter then
			table.insert(keep, idText)
		end
	end
	if wornAsset then
		table.insert(keep, tostring(wornAsset))
	end
	return table.concat(keep, ",")
end

function StarterShop.apply(player: Player)
	local st = state(player)
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not st or not hum then
		return
	end
	local ok, err = pcall(function()
		local desc = hum:GetAppliedDescription()
		local hat = st.Hat and byId[st.Hat]
		local neck = st.Neck and byId[st.Neck]
		desc.HatAccessory = mergeIds(desc.HatAccessory, "Hat", hat and hat.asset)
		desc.NeckAccessory = mergeIds(desc.NeckAccessory, "Neck", neck and neck.asset)
		hum:ApplyDescription(desc)
	end)
	if not ok then
		warn("[MTL StarterShop] couldn't dress", player.Name, err)
	end
end

local function promptText(prompt: ProximityPrompt, it: any, st: any?)
	-- per-player text isn't possible on a shared prompt: keep it general, the server decides buy vs wear
	prompt.ObjectText = it.title
	prompt.ActionText = string.format("Buy · $%d", it.price)
end

local function onTriggered(player: Player, it: any)
	local st = state(player)
	if not st then
		return
	end
	if not st.Owned[it.id] then
		if not EconomyService.spend(player, it.price, "Shop:Starter:" .. it.id) then
			Notify.toast(player, string.format("You need $%d for the %s.", it.price, it.title))
			return
		end
		st.Owned[it.id] = true
		st[it.slot] = it.id
		Notify.toast(player, string.format("Bought: %s. Looking fresh.", it.title))
		log(player.Name, "bought", it.id)
	elseif st[it.slot] == it.id then
		st[it.slot] = nil
		Notify.toast(player, string.format("Took off: %s", it.title))
	else
		st[it.slot] = it.id
		Notify.toast(player, string.format("Wearing: %s", it.title))
	end
	DataService.push(player)
	StarterShop.apply(player)
end

-- the stand: a dark wooden display with three pegs and the real accessories on them, a small sign above
local function buildStand()
	local old = workspace:FindFirstChild("MTL_StarterStand")
	if old then
		old:Destroy()
	end
	local at: Vector3 = Config.Stand.At
	local face: Vector3 = Config.Stand.Face
	-- find the floor under the stand
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local hit = workspace:Raycast(at + Vector3.new(0, 4, 0), Vector3.new(0, -20, 0), params)
	local floorY = if hit then hit.Position.Y else at.Y - 1
	local base = CFrame.lookAt(Vector3.new(at.X, floorY, at.Z), Vector3.new(at.X, floorY, at.Z) + face)
	local m = Instance.new("Model")
	m.Name = "MTL_StarterStand"
	local function part(name: string, size: Vector3, cf: CFrame, color: Color3, mat: Enum.Material?): Part
		local p = Instance.new("Part")
		p.Name = name
		p.Size = size
		p.CFrame = cf
		p.Color = color
		p.Material = mat or Enum.Material.Wood
		p.Anchored = true
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		p.Parent = m
		return p
	end
	local wood = Color3.fromRGB(70, 48, 34)
	local back = part("Back", Vector3.new(6, 6.4, 0.3), base * CFrame.new(0, 3.2, 0.6), wood)
	part("Foot", Vector3.new(6.2, 0.4, 1.6), base * CFrame.new(0, 0.2, 0.2), wood)
	part("Shelf", Vector3.new(6, 0.2, 1.1), base * CFrame.new(0, 2.6, 0.15), Color3.fromRGB(196, 200, 206), Enum.Material.Metal)
	-- sign
	local sign = part("Sign", Vector3.new(6, 1, 0.12), base * CFrame.new(0, 6.9, 0.55), Color3.fromRGB(24, 25, 29), Enum.Material.SmoothPlastic)
	local sg = Instance.new("SurfaceGui")
	sg.Face = Enum.NormalId.Front -- the LookVector side = toward the shopper (the stand looks along +face)
	sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	sg.PixelsPerStud = 60
	sg.LightInfluence = 1
	sg.Parent = sign
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = "FRESH FITS"
	label.FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Heavy)
	label.TextColor3 = Color3.fromRGB(240, 192, 72)
	label.TextScaled = true
	label.Parent = sg
	-- the three items on pegs, each with its own prompt
	for i, it in Config.Items do
		local x = (i - 2) * 1.9
		local pegCf = base * CFrame.new(x, 4.6, 0.25)
		part("Peg" .. i, Vector3.new(0.15, 0.15, 0.6), pegCf, Color3.fromRGB(196, 200, 206), Enum.Material.Metal)
		local holder = part("Item_" .. it.id, Vector3.new(1.4, 1.4, 0.6), base * CFrame.new(x, 4.1, -0.05), Color3.new(1, 1, 1))
		holder.Transparency = 1
		holder.CanCollide = false
		-- the real accessory, posed on the peg
		task.spawn(function()
			local ok, model = pcall(function()
				return InsertService:LoadAsset(it.asset)
			end)
			local acc = ok and model and model:FindFirstChildWhichIsA("Accessory", true)
			local handle = acc and acc:FindFirstChild("Handle")
			if handle and handle:IsA("BasePart") then
				handle.Parent = m
				handle.Name = "Show_" .. it.id
				for _, d in handle:GetChildren() do
					if d:IsA("JointInstance") or d:IsA("WeldConstraint") then
						d:Destroy()
					end
				end
				handle.Anchored = true
				handle.CanCollide = false
				handle.CFrame = CFrame.new(holder.Position) * base.Rotation * CFrame.Angles(0, math.pi, 0)
			end
			if model then
				model:Destroy()
			end
		end)
		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = "Buy"
		prompt.KeyboardKeyCode = Enum.KeyCode.E
		prompt.HoldDuration = 0.3
		prompt.MaxActivationDistance = 8
		prompt.RequiresLineOfSight = false
		promptText(prompt, it, nil)
		prompt.Parent = holder
		prompt.Triggered:Connect(function(player)
			onTriggered(player, it)
		end)
	end
	m.PrimaryPart = back
	m.Parent = workspace
end

function StarterShop.init()
	task.spawn(buildStand)
	local function hook(player: Player)
		player.CharacterAppearanceLoaded:Connect(function()
			task.wait(0.2)
			StarterShop.apply(player)
		end)
	end
	Players.PlayerAdded:Connect(hook)
	for _, p in Players:GetPlayers() do
		hook(p)
	end
	DataService.Ready:Connect(function(player)
		if player.Character then
			StarterShop.apply(player)
		end
	end)
	log("ready:", #Config.Items, "items")
end

return StarterShop
