--[[
	Where the round's tap buttons sit on a phone or tablet (owner, Oct 23: "make the placement of all the abilities
	better"). Like popular Roblox chase games, they are round buttons grouped in the bottom-right corner round the main
	one, under the right thumb, clear of Roblox's thumbstick (it takes touches on the left 40% of the screen) and of the
	top HUD. This game has no jumping (jump power 0), so Roblox hides its jump button, and the main button (DASH, or
	CATCH for a catcher: Space on a keyboard) takes the jump button's spot.
	  Main   : Screens/PowerBar's dash button (86 across)
	  Left   : Gameplay/Actions' STAB (a catcher only)
	  UpLeft : the Q ability
	  Up     : the E ability
	Each is points from the screen's bottom-right corner to the button's centre, and the button's size (74 across:
	easy for a thumb, Roblox's own jump is 70). Sizes are even, so the centres land on whole pixels.
	A keyboard keeps its own layout: this file is used only when the screen is touch only.
]]

local UserInputService = game:GetService("UserInputService")

local TouchPad = {}

TouchPad.SLOTS = {
	Main = { X = 62, Y = 62, D = 86 },
	Left = { X = 172, Y = 62, D = 74 },
	UpLeft = { X = 140, Y = 140, D = 74 },
	Up = { X = 62, Y = 172, D = 74 },
}

function TouchPad.active(): boolean
	return UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
end

-- Puts a button in its slot: centred there, round-ready (its corner is the caller's).
function TouchPad.place(b: GuiObject, slot: string)
	local s = TouchPad.SLOTS[slot]
	b.AnchorPoint = Vector2.new(0.5, 0.5)
	b.Position = UDim2.new(1, -s.X, 1, -s.Y)
	b.Size = UDim2.fromOffset(s.D, s.D)
end

return TouchPad
