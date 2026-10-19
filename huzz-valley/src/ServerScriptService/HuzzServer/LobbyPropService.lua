--[[
	Puts the owner's five lobby props on the round pads at the front of every lobby copy (owner, Oct 18: "start working
	on implementing these objects into the lobby on top of the already placed circles. Give it some VFX and make it
	look good just like in the pictures"). Config/LobbyProps says which prop goes on which pad, its title and what it
	opens; Shared/LobbyLayout.propSpots finds the pads; Shared/LobbyPropBuild builds each one; Gameplay/LobbyProps (on
	every screen) makes them float and turn and opens their menus.

	1. Props the place already has (Workspace > HuzzLobbyProps, saved by the place build, so he can drag them or type
	   another Title or Scale) are kept. If the place has none (his own place synced by Rojo), they are made here.
	2. His real models: once he has run the SetupLobbyProps helper (ServerStorage > HuzzLobbyProps > <name>), any
	   stand-in (plain parts, attribute StandIn) on a pad is swapped for his model at the same place and size.
	The menus open on the client (no remote: the prompt and the click are seen on the screen that used them).
]]
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config.LobbyProps)
local LobbyLayout = require(Shared.LobbyLayout)
local LobbyPropBuild = require(Shared.LobbyPropBuild)
local FxTexture = require(Shared.FxTexture)
local Shapes = require(script.Parent.LobbyPropShapes)

local LobbyPropService = {}

local api = LobbyPropBuild.api({
	Instance = Instance, Vector2 = Vector2, Vector3 = Vector3, CFrame = CFrame, Color3 = Color3, ColorSequence = ColorSequence,
	ColorSequenceKeypoint = ColorSequenceKeypoint, NumberSequence = NumberSequence, NumberSequenceKeypoint = NumberSequenceKeypoint,
	NumberRange = NumberRange, UDim = UDim, UDim2 = UDim2, Enum = Enum, Font = Font,
})

local function tag(inst: Instance)
	if not pcall(function() inst:AddTag(Config.Tag) end) then pcall(function() CollectionService:AddTag(inst, Config.Tag) end) end
end

-- His set-up model for this prop (a fresh copy), or nil.
local function real(key: string): Model?
	local holder = ServerStorage:FindFirstChild(Config.Folder)
	local m = holder and holder:FindFirstChild(key)
	if m and m:IsA("Model") then return m:Clone() end
	return nil
end

-- A stand-in already on a pad, swapped for his model (same place, same size).
local function swap(lp: Instance)
	local key = lp:GetAttribute("Prop")
	local old = lp:FindFirstChild("Prop")
	if type(key) ~= "string" or not old or old:GetAttribute("StandIn") ~= true then return end
	local model = real(key)
	local oldRoot = old:IsA("Model") and old.PrimaryPart
	if not model or not oldRoot then return end
	local shape = Shapes[key]
	local pad = lp:FindFirstChild("Pad")
	if not shape or not pad then return end
	-- build a fresh one on the same spot, then keep where he dragged the old prop to
	-- (with what's typed on the pad's LobbyProp: its Scale above all, so his model comes out the stand-in's size)
	local cfg = table.clone(Config)
	cfg.Props = { [key] = { Title = lp:GetAttribute("Title") or key, Scale = lp:GetAttribute("Scale"), Color = lp:GetAttribute("Color"),
		Glow = lp:GetAttribute("Glow"), Opens = lp:GetAttribute("Opens"), Action = lp:GetAttribute("Action"), Line = lp:GetAttribute("Line") } }
	local fresh = LobbyPropBuild.make(api, { at = pad.CFrame * CFrame.new(0, -0.1, 0), Prop = key }, cfg, shape, model, FxTexture.get("Twinkle"))
	local prop = fresh:FindFirstChild("Prop") :: Model
	prop:PivotTo(old:GetPivot())
	old:Destroy()
	prop.Parent = lp
	fresh:Destroy()
end

function LobbyPropService.start()
	local folder = Workspace:FindFirstChild(Config.Folder)
	local how = "placed"
	if not folder then
		how = "made on the pads"
		local made = 0
		for _, floor in { LobbyLayout.main(Workspace) } do -- (the one lobby: MapService puts the other copies away)
			for _, spot in LobbyLayout.propSpots(api, Workspace, floor, Config.ThreePads, Config.TwoPads) do
				local shape = Shapes[spot.Prop]
				if shape and Config.Props[spot.Prop] then
					if not folder then
						folder = Instance.new("Folder")
						folder.Name = Config.Folder
						folder.Parent = Workspace
					end
					local ok, err = pcall(function()
						local lp = LobbyPropBuild.make(api, spot, Config, shape, real(spot.Prop), FxTexture.get("Twinkle"))
						lp.Parent = folder
						made += 1
					end)
					if not ok then warn("[Huzz] lobby prop " .. spot.Prop .. ": " .. tostring(err)) end
				end
			end
		end
		if made == 0 then return end
	end
	local n, standIns = 0, 0
	for _, lp in folder:GetChildren() do
		if lp:IsA("Model") and lp:GetAttribute("Prop") then
			local ok, err = pcall(swap, lp)
			if not ok then warn("[Huzz] lobby prop swap: " .. tostring(err)) end
			tag(lp)
			n += 1
			local prop = lp:FindFirstChild("Prop")
			if prop and prop:GetAttribute("StandIn") == true then standIns += 1 end
		end
	end
	print(string.format("[Huzz] Lobby props: %d %s (%d stand-ins: import design/lobby/Lobby_Props.glb and run SetupLobbyProps for his real models)", n, how, standIns))
end

return LobbyPropService
