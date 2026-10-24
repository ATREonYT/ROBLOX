--[[
	The sign over whoever has the girl (owner, Oct 22 12:26: "make it so that there is a sign over the person who has
	the girl that he has the girl, but dont make it overly too big, make it known, with some nice text colours,
	matching to the girl that he has"). One line just above the name tag: "HAS <HER NAME>" in her own two colours
	(Config/GirlLooks, by her model's name; else her rarity colour), top bright to bottom deep, with a dark outline in
	her deep colour. A runner carrying her and a catcher she follows both get it (CarryService.give / follow), and it
	goes when she leaves them (CarryService.remove) or with their body.
	Sized in studs with a small pixel floor, so it reads across the field without growing big close up; seen to
	SEEN studs (name tags hide at 80). When the HERO / CHICKEN word shows over the head (NameTagService Badge), the
	sign sits above it. Made on the server, so everyone sees the same; an Invisible runner's screens switch it off
	with the rest of the tag (Gameplay/PowerEffects: every BillboardGui in the body).
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Looks = require(ReplicatedStorage.Shared.Config.GirlLooks)
local Round = require(ReplicatedStorage.Shared.Config.Round)

local GirlSign = {}

local NAME = "HuzzGirlSign"
local SEEN = 160 -- studs
local LOW, HIGH = 4.75, 6.55 -- studs over the head: just above the name tag, or above its HERO / CHICKEN word
local FONT = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Heavy, Enum.FontStyle.Italic)

-- Her two colours (bright, deep).
function GirlSign.colors(girl): (Color3, Color3)
	local look = girl and Looks[girl.id or ""]
	if look and look.Colors and look.Colors[1] then
		return look.Colors[1], look.Colors[2] or look.Colors[1]
	end
	local c = Color3.fromRGB(255, 150, 200)
	for _, r in Round.Rarities do
		if girl and r.Name == girl.rarity and r.Name ~= "Secret" then c = r.Color end
	end
	return c:Lerp(Color3.new(1, 1, 1), 0.25), c:Lerp(Color3.new(0, 0, 0), 0.3)
end

-- The words on it.
function GirlSign.text(girl): string
	local name = girl and type(girl.name) == "string" and girl.name or "THE GIRL"
	return "HAS " .. string.upper(name)
end

function GirlSign.remove(character: Model?)
	local head = character and character:FindFirstChild("Head")
	local old = head and head:FindFirstChild(NAME)
	if old then old:Destroy() end
end

function GirlSign.put(character: Model?, girl)
	local head = character and character:FindFirstChild("Head")
	if not (head and head:IsA("BasePart")) then return nil end
	GirlSign.remove(character)
	local bright, deep = GirlSign.colors(girl)
	local gui = Instance.new("BillboardGui")
	gui.Name = NAME
	gui.Size = UDim2.new(3.4, 64, 0.62, 12)
	gui.StudsOffsetWorldSpace = Vector3.new(0, LOW, 0)
	gui.MaxDistance = SEEN
	gui.LightInfluence = 0
	gui.AlwaysOnTop = false
	gui.ResetOnSpawn = false
	local label = Instance.new("TextLabel")
	label.Name = "Words"
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.FontFace = FONT
	label.Text = GirlSign.text(girl)
	label.TextScaled = true
	label.TextColor3 = Color3.new(1, 1, 1) -- (the gradient colours it)
	label.Parent = gui
	local gradient = Instance.new("UIGradient")
	gradient.Rotation = 90
	gradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, bright:Lerp(Color3.new(1, 1, 1), 0.35)),
		ColorSequenceKeypoint.new(0.45, bright),
		ColorSequenceKeypoint.new(1, bright:Lerp(deep, 0.55)),
	})
	gradient.Parent = label
	local stroke = Instance.new("UIStroke")
	stroke.Color = deep:Lerp(Color3.fromRGB(10, 20, 51), 0.6)
	stroke.Thickness = 2
	stroke.LineJoinMode = Enum.LineJoinMode.Round
	stroke.Parent = label
	gui.Adornee = head
	gui.Parent = head
	GirlSign.place(character)
	return gui
end

-- Above the HERO / CHICKEN word while it shows, else just over the name tag (NameTagService calls this whenever it
-- sets the word).
function GirlSign.place(character: Model?)
	local head = character and character:FindFirstChild("Head")
	local gui = head and head:FindFirstChild(NAME)
	if not (gui and gui:IsA("BillboardGui")) then return end
	local tag = head:FindFirstChild("HuzzTag")
	local badge = tag and tag:FindFirstChild("Badge")
	local up = badge ~= nil and badge:IsA("TextLabel") and badge.Visible and badge.Text ~= ""
	gui.StudsOffsetWorldSpace = Vector3.new(0, if up then HIGH else LOW, 0)
end

return GirlSign
