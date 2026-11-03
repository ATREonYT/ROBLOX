--!strict
-- The desk PC (vault: Research/Desk Computer Empire.md §4). Who is sat at a desk, and the one door every
-- Liberty OS button goes through.
--   * PropertyService calls DeskService.sit(player, screenPos, chairCFrame) from the room's "Use PC" prompt
--     (power on only). The client (DeskController) does the walk-up, chair, sit pose and camera.
--   * Remote OSRequest (RemoteFunction): (app, action, args) -> result table. The app must be unlocked
--     (Config/OS.Apps gate, re-checked here) and the player must be seated, except "Shell" actions.
--     Each app's server half is a module with handle(player, action, args) -> result.
--   * Remote DeskAction: { type = "stand" } from the client when it leaves the PC.
--   * Remote DeskState (S->C): { type = "sit", screen = Vector3, chair = CFrame } | { type = "stand" } |
--     { type = "push", app, data } (live data an open app subscribed to, e.g. CoinBay prices).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.MTL.Net)
local OS = require(ReplicatedStorage.MTL.Config.OS)
local OSRules = require(ReplicatedStorage.MTL.Rules.OSRules)
local DataService = require(script.Parent.DataService)
local RateLimiter = require(script.Parent.RateLimiter)

local DeskService = {}

type Seat = { at: number, screen: Vector3, chair: CFrame }
local seated: { [Player]: Seat } = {}
local handlers: { [string]: any } = {}
local appById: { [string]: any } = {}
for _, a in OS.Apps do
	appById[a.id] = a
end
local limiter = RateLimiter.new(12, 20)

local stateRemote: RemoteEvent

local function log(...)
	print("[MTL Desk]", ...)
end

local function root(player: Player): BasePart?
	local c = player.Character
	local r = c and c:FindFirstChild("HumanoidRootPart")
	return if r and r:IsA("BasePart") then r else nil
end

function DeskService.isSeated(player: Player): boolean
	return seated[player] ~= nil
end

-- Called by PropertyService (and later any home with a PC). screen = the monitor's world position,
-- chair = the chair spot (floor, facing the desk).
function DeskService.sit(player: Player, screen: Vector3, chair: CFrame)
	if seated[player] then
		return
	end
	seated[player] = { at = os.clock(), screen = screen, chair = chair }
	player:SetAttribute("MTL_AtDesk", true)
	stateRemote:FireClient(player, { type = "sit", screen = screen, chair = chair })
	log(player.Name, "sat at the PC")
end

function DeskService.stand(player: Player, reason: string?)
	if not seated[player] then
		return
	end
	seated[player] = nil
	player:SetAttribute("MTL_AtDesk", nil)
	for _, h in handlers do
		if h.onStand then
			task.spawn(pcall, h.onStand, player)
		end
	end
	if reason then
		stateRemote:FireClient(player, { type = "stand", reason = reason })
	end
end

-- Live data for an open app (CoinBay ticks, notifications).
function DeskService.push(player: Player, app: string, data: any)
	stateRemote:FireClient(player, { type = "push", app = app, data = data })
end

-- An app's server half registers itself (handle(player, action, args) -> result).
function DeskService.register(appId: string, handler: any)
	handlers[appId] = handler
end

local function ownedTitle(id: string): string
	local ok, Realty = pcall(function()
		return require(ReplicatedStorage.MTL.Config.Realty) :: any
	end)
	local p = ok and Realty and Realty.Props and Realty.Props[id]
	return if p then p.title else id
end

-- What the desktop shows: every app with locked/unlocked + why.
local function shell(player: Player, action: string, _args: any): any
	local d = DataService.get(player)
	if not d then
		return { ok = false, err = "Still loading" }
	end
	if action == "apps" then
		local out = {}
		for _, a in OS.Apps do
			local ok, why = OSRules.gate(a.gate, d, ownedTitle)
			table.insert(out, { id = a.id, open = ok, why = why })
		end
		return { ok = true, apps = out }
	elseif action == "mail" then
		local box = {}
		d.Desk = d.Desk or { Mail = {} }
		d.Desk.Mail = d.Desk.Mail or {}
		for id, m in OS.Mail do
			local show = true
			if m.when and m.when.app then
				local a = appById[m.when.app]
				show = a ~= nil and (OSRules.gate(a.gate, d, ownedTitle))
			end
			if show then
				if not d.Desk.Mail[id] then
					d.Desk.Mail[id] = os.time()
				end
				table.insert(box, { id = id, from = m.from, subject = m.subject, body = m.body, at = d.Desk.Mail[id] })
			end
		end
		table.sort(box, function(a, b)
			return a.at > b.at
		end)
		return { ok = true, mail = box }
	end
	return { ok = false, err = "Unknown action" }
end

local function onRequest(player: Player, app: any, action: any, args: any): any
	if type(app) ~= "string" or type(action) ~= "string" then
		return { ok = false, err = "Bad request" }
	end
	if not limiter:allow(player) then
		return { ok = false, err = "Slow down" }
	end
	if app == "Shell" then
		return shell(player, action, args)
	elseif app == "Mail" then
		return shell(player, "mail", args)
	end
	local def = appById[app]
	if not def then
		return { ok = false, err = "Unknown app" }
	end
	if not seated[player] then
		return { ok = false, err = "Sit at your PC first" }
	end
	local d = DataService.get(player)
	local ok, why = OSRules.gate(def.gate, d, ownedTitle)
	if not ok then
		return { ok = false, err = "Locked: " .. tostring(why) }
	end
	local h = handlers[app]
	if not h then
		return { ok = false, err = "Coming soon" }
	end
	local okCall, res = pcall(h.handle, player, action, args)
	if not okCall then
		warn("[MTL Desk] handler error", app, action, res)
		return { ok = false, err = "Something went wrong" }
	end
	return res
end

function DeskService.init()
	stateRemote = Net.get("DeskState")
	local req: RemoteFunction = Net.get("OSRequest")
	req.OnServerInvoke = onRequest
	Net.get("DeskAction").OnServerEvent:Connect(function(player: Player, msg: any)
		if type(msg) == "table" and msg.type == "stand" then
			DeskService.stand(player)
		end
	end)
	-- stand players up if they get moved away from the desk (teleport, death, leaving the flat)
	task.spawn(function()
		while true do
			task.wait(1)
			for p, s in seated do
				local r = root(p)
				local hum = p.Character and p.Character:FindFirstChildOfClass("Humanoid")
				if not r or not hum or hum.Health <= 0 or (r.Position - s.screen).Magnitude > OS.Desk.MaxDistance then
					DeskService.stand(p, "moved")
				end
			end
		end
	end)
	Players.PlayerRemoving:Connect(function(p)
		seated[p] = nil
	end)
	-- the app halves (each registers itself; missing modules are fine while they're being built)
	for _, a in OS.Apps do
		if a.server then
			local m = script.Parent:FindFirstChild(a.server)
			if m then
				local ok, mod = pcall(require, m)
				if ok and type(mod) == "table" then
					if mod.init then
						local okInit, err = pcall(mod.init, DeskService)
						if not okInit then
							warn("[MTL Desk] init failed", a.server, err)
						end
					end
					DeskService.register(a.id, mod)
				else
					warn("[MTL Desk] require failed", a.server, mod)
				end
			end
		end
	end
	log("ready")
end

return DeskService
