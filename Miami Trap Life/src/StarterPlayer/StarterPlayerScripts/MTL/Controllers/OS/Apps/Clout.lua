--!nonstrict
-- Liberty OS window for CLOUT (clout.com in the desk PC's browser). The app itself is the phone module
-- StarterPlayerScripts/MTL/Apps/Clout (owned by the social thread); this file only gives it a phone-like ctx in a
-- wide frame (ctx.args.desktop = true: left nav, centred column, Creator Studio can record courses here).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Theme = require(ReplicatedStorage.MTL.UI.Theme)

local MTL = script.Parent.Parent.Parent.Parent -- StarterPlayerScripts/MTL
local ClientData = require(MTL.Controllers.ClientData)

local App = {}

function App.mount(content: Frame, api: any)
	local ok, Clout = pcall(require, MTL.Apps.Clout)
	if not ok or type(Clout) ~= "table" then
		warn("[MTL OS] Clout app missing", Clout)
		return { unmount = function() end }
	end
	local frame = Instance.new("Frame")
	frame.Name = "CloutHost"
	frame.Size = UDim2.fromScale(1, 1)
	frame.BackgroundTransparency = 1
	frame.ClipsDescendants = true
	frame.Parent = content
	local conns = {}
	local Phone = {
		notify = function(n)
			if api.notify then
				api.notify((n.title and (n.title .. ": ") or "") .. (n.text or ""))
			end
		end,
		setViewfinder = function() end,
		setCaptureHidden = function() end,
	}
	local ctx = {
		id = "Clout",
		frame = frame,
		args = { desktop = true },
		Theme = Theme,
		Phone = Phone,
		sfx = function()
			if api.tap then
				api.tap()
			end
		end,
		data = function()
			return ClientData.get()
		end,
		track = function(c)
			table.insert(conns, c)
			return c
		end,
		home = function() end,
		close = function() end,
	}
	function ctx.onData(fn)
		table.insert(conns, ClientData.Changed:Connect(function(new)
			if frame.Parent then
				fn(new)
			end
		end))
		local d = ClientData.get()
		if d then
			task.spawn(fn, d)
		end
	end
	function ctx.clear()
		frame:ClearAllChildren()
	end
	task.defer(function()
		local okMount, err = pcall(Clout.mount, frame, ctx)
		if not okMount then
			warn("[MTL OS] Clout mount failed", err)
		end
	end)
	return {
		unmount = function()
			if Clout.unmount then
				pcall(Clout.unmount, ctx)
			end
			for _, c in conns do
				if typeof(c) == "RBXScriptConnection" then
					c:Disconnect()
				elseif type(c) == "table" and c.Disconnect then
					c.Disconnect()
				end
			end
			frame:Destroy()
		end,
	}
end

local _ = Players
return App
