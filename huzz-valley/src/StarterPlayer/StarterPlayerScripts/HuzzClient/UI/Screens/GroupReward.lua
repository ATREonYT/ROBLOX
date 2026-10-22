-- "Join our group" window (owner, Oct 22 19:09: "make a 'join the group' ui pop up for a reward in the style of our
-- ui, and make the reward 5 free spins on the wheel"). Our kit's window: FREE SPINS, the wheel icon turning in green
-- rays, "+5 SPINS", what to do in two steps, then JOIN GROUP (Roblox's own join prompt, GroupService:PromptJoinAsync,
-- guarded: not every device or Studio has it) and CLAIM. The server checks with Roblox that you're in the group and
-- gives the spins once (ActionService "ClaimGroup" -> ProgressService.claimGroup); this window only asks.
-- It opens by itself once per visit, Config/Group.PopupAfter seconds into the lobby, while the spins aren't claimed
-- (like How to Play: never over a round or another window). The lobby's GROUP button (Screens/LobbyHud) opens it too.
-- With no group set (Config/Group.Id 0): both buttons say COMING SOON and do nothing, and it never pops up live
-- (in Studio it still does, so you can see it).
local Players = game:GetService("Players")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Group = require(Shared.Config.Group)
local UI = script.Parent.Parent
local Theme = require(UI.Theme)
local Kit = require(UI.Kit)
local State = require(UI.State)
local Toast = require(UI.Toast)
local ModalManager = require(UI.ModalManager)
local Motion = require(UI.Motion)
local Effects = require(UI.Effects)

local new = Kit.new
local C, F = Theme.Colors, Theme.Fonts

local GroupRewardScreen = {}

local W, H = 440, 330

local function line(props: { [string]: any }, stroke: number?): TextLabel
	props.TextWrapped = props.TextWrapped == true
	local l = Kit.text(props)
	new("UIStroke", { Name = "Outline", Color = C.TitleStroke, Thickness = stroke or 1.5, LineJoinMode = Enum.LineJoinMode.Round, Parent = l })
	return l
end

function GroupRewardScreen.set(): boolean return (tonumber(Group.Id) or 0) > 0 end

function GroupRewardScreen.build(parent: Instance)
	local player = Players.LocalPlayer
	local window = Kit.window({ Name = "GroupReward", Title = "FREE SPINS", Icon = "SpinWheel", Width = W, Height = H, TitleX = 56, TitleWidth = 140, Parent = parent, OnClose = function() ModalManager.close() end })
	local panel = window.Panel
	-- the wheel, turning in green rays, and the reward under it
	local rays = Effects.rays(panel, UDim2.fromOffset(W // 2, 112), 150, { color = C.Accent, transparency = 0.35, seconds = 12, z = 2, name = "Rays" })
	local wheel = Kit.icon("SpinWheel", { Name = "Wheel", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(W // 2, 112), Size = UDim2.fromOffset(84, 84), ZIndex = 3, Parent = panel })
	local spinning = false
	Effects.spin(wheel, 8, function() return spinning end)
	local amount = line({ Name = "Amount", Text = "+" .. Group.Spins .. " SPINS", FontFace = F.Heading, TextSize = 26, TextColor3 = C.Accent, TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.fromOffset(16, 158), Size = UDim2.fromOffset(W - 32, 30), ZIndex = 3, Parent = panel }, 2)
	local name = if Group.Name ~= "" then Group.Name else "our group"
	local about = line({ Name = "About", Text = "Join " .. name .. " and get " .. Group.Spins .. " free spins on the wheel!", FontFace = F.Name, TextSize = 16, TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.fromOffset(16, 192), Size = UDim2.fromOffset(W - 32, 22), ZIndex = 3, Parent = panel })
	Kit.fitLine(about, W - 32, 16, 12, true)
	local steps = line({ Name = "Steps", Text = "1. Press JOIN GROUP.   2. Come back and press CLAIM.", FontFace = F.Body, TextSize = 14, TextColor3 = C.NoteText, TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.fromOffset(16, 216), Size = UDim2.fromOffset(W - 32, 20), ZIndex = 3, Parent = panel }, 1)
	local join = Kit.button({ Name = "Join", Text = "JOIN GROUP", Style = "Action", FontFace = F.Button, TextSize = 16, Corner = 7, RimThickness = 2, Position = UDim2.fromOffset(32, H - 78), Size = UDim2.fromOffset(176, 44), ZIndex = 4, Parent = panel })
	local claim = Kit.button({ Name = "Claim", Text = "CLAIM", Style = "Selected", FontFace = F.Button, TextSize = 16, Corner = 7, RimThickness = 2, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -32, 1, -78), Size = UDim2.fromOffset(176, 44), ZIndex = 4, Parent = panel })

	local pending = false
	local function refresh()
		local got = State.data.GroupReward == true
		if not GroupRewardScreen.set() then
			steps.Text = "Our group is coming soon. Check back later!"
			join.setText("COMING SOON"); join.setStyle("Disabled"); join.setEnabled(false)
			claim.setText("COMING SOON"); claim.setStyle("Disabled"); claim.setEnabled(false)
		elseif got then
			steps.Text = "Thanks for joining! Your spins are on the wheel."
			join.setText("JOIN GROUP"); join.setStyle("Disabled"); join.setEnabled(false)
			claim.setText("CLAIMED"); claim.setStyle("Disabled"); claim.setEnabled(false)
		else
			steps.Text = "1. Press JOIN GROUP.   2. Come back and press CLAIM."
			join.setText("JOIN GROUP"); join.setStyle("Action"); join.setEnabled(true)
			claim.setText(if pending then "..." else "CLAIM"); claim.setStyle("Selected"); claim.setEnabled(not pending)
		end
		rays.Visible = not got
	end

	join.onClick(function()
		if not GroupRewardScreen.set() then return end
		task.spawn(function()
			local ok = pcall(function() game:GetService("GroupService"):PromptJoinAsync(Group.Id) end)
			if not ok then Toast.show("The join window can't open here. Find " .. name .. " on our game's page, join it, then press CLAIM.") end
		end)
	end)
	claim.onClick(function()
		if pending or State.data.GroupReward == true or not GroupRewardScreen.set() then return end
		pending = true
		refresh()
		task.spawn(function()
			local ok, why = State.action("ClaimGroup")
			pending = false
			if ok then
				Toast.show("+" .. Group.Spins .. " spins on the wheel!")
				Motion.pop(amount)
			else
				Toast.show(why or "Couldn't claim that. Try again.")
			end
			refresh()
		end)
	end)

	local open = false
	ModalManager.register("GroupReward", {
		window = window,
		onOpen = function() open = true; spinning = true; refresh() end,
		onClose = function() open = false; spinning = false end,
		firstSelect = function() return claim.Instance end,
	})
	State.changed(function() if open then refresh() end end)
	refresh()

	-- By itself: once per visit, PopupAfter seconds after the save loaded, in the lobby with nothing else open
	-- (if a round or a window is in the way, it waits for the lobby). Never live with no group set.
	local studio = game:GetService("RunService"):IsStudio()
	local shown, due, timer = false, nil, false
	local function free(): boolean
		local role = player:GetAttribute("HuzzRole")
		return ModalManager.current() == nil and role ~= "Runner" and role ~= "Catcher"
	end
	local function maybeOpen()
		if shown or timer or not State.data.Loaded or State.data.GroupReward == true then return end
		if not (GroupRewardScreen.set() or studio) then return end
		due = due or os.clock() + Group.PopupAfter
		timer = true
		task.delay(math.max(due - os.clock(), 0) + 0.05, function()
			timer = false
			if shown or State.data.GroupReward == true then return end
			if free() then -- (else the next lobby moment or closed window looks again)
				shown = true
				ModalManager.open("GroupReward")
			end
		end)
	end
	State.changed(maybeOpen)
	ModalManager.changed(function() task.defer(maybeOpen) end)
	player:GetAttributeChangedSignal("HuzzRole"):Connect(maybeOpen)
	maybeOpen()
	return window.Holder
end

return GroupRewardScreen
