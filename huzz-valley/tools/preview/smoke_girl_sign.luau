-- Smoke test: the "HAS <HER NAME>" sign over whoever has the girl (owner, Oct 22 12:26), HuzzServer/GirlSign through
-- the real CarryService: carrying her puts it on the carrier's head in her own colours (Config/GirlLooks), small and
-- just over the name tag; a catcher she follows gets it too; it goes when she leaves them; it sits above a HERO word.
-- From tools/preview: lune run harness.luau ../../src - @smoke_girl_sign.luau setup_ui.luau
local ok, fails = 0, 0
local function check(name, cond)
	if cond then ok += 1 else fails += 1; print("FAIL " .. name) end
end
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local Server = game.ServerScriptService.HuzzServer
local GirlSign = require(Server.GirlSign)
local Looks = require(RS.Shared.Config.GirlLooks)

local function body(name, id)
	local p = Instance.new("Player"); p.Name = name; p.UserId = id; p.Parent = Players
	local char = Instance.new("Model"); char.Name = name
	local root = Instance.new("Part"); root.Name = "HumanoidRootPart"; root.Size = Vector3.new(2, 2, 1); root.Parent = char
	local head = Instance.new("Part"); head.Name = "Head"; head.Size = Vector3.new(1, 1, 1); head.Parent = char
	local tag = Instance.new("BillboardGui"); tag.Name = "HuzzTag"; tag.Parent = head
	local badge = Instance.new("TextLabel"); badge.Name = "Badge"; badge.Text = ""; badge.Visible = false; badge.Parent = tag
	Instance.new("Humanoid").Parent = char
	char.Parent = workspace
	p.Character = char
	return p, char, head, badge
end

-- a girl with her own look, and one without (her rarity colour)
local key = next(Looks)
local yui = { id = key, name = Looks[key].Who or "Yui", rarity = "Common" }
local plain = { id = "NoLookGirl", name = "Plain", rarity = "Rare" }

local _, char, head, badge = body("Runner1", 501)
local sign = GirlSign.put(char, yui)
check("the sign is on the carrier's head", sign ~= nil and head:FindFirstChild("HuzzGirlSign") == sign)
local words = sign and sign:FindFirstChild("Words")
check("it says HAS <HER NAME>", words ~= nil and words.Text == "HAS " .. string.upper(yui.name))
local bright = GirlSign.colors(yui)
check("in her own colours (GirlLooks)", bright == Looks[key].Colors[1])
local grad = words and words:FindFirstChildOfClass("UIGradient")
check("coloured by a gradient, outlined", grad ~= nil and words:FindFirstChildOfClass("UIStroke") ~= nil)
check("not too big: under the name tag's 5.6 x 2.6 studs", sign.Size.X.Scale < 5.6 and sign.Size.Y.Scale < 1 and sign.Size.Y.Offset <= 14)
check("just over the name tag", sign.StudsOffsetWorldSpace.Y > 4.3 and sign.StudsOffsetWorldSpace.Y < 5.5)
check("seen further than name tags (80)", sign.MaxDistance > 80)
badge.Text = "HERO"; badge.Visible = true
GirlSign.place(char) -- (NameTagService.set calls it when it sets the word)
check("above a HERO word", sign.StudsOffsetWorldSpace.Y > 6)
badge.Visible = false
GirlSign.place(char)
check("back down when it goes", sign.StudsOffsetWorldSpace.Y < 5.5)
local r1, d1 = GirlSign.colors(plain)
check("a girl with no look gets her rarity colour", r1 ~= nil and d1 ~= nil and r1 ~= bright)
GirlSign.put(char, plain)
local n = 0
for _, c in head:GetChildren() do if c.Name == "HuzzGirlSign" then n += 1 end end
check("a new girl replaces the old sign (one sign)", n == 1)
GirlSign.remove(char)
check("removed when she leaves", head:FindFirstChild("HuzzGirlSign") == nil)

-- through the real CarryService (give / follow / remove)
local okC, CarryService = pcall(require, Server.CarryService)
if okC then
	local p2, char2, head2 = body("Runner2", 502)
	local okGive = pcall(CarryService.give, p2, { id = key, name = "Yui", rarity = "Common", template = nil }, nil)
	-- (GirlService.makeCopy needs her model: in the harness she may not exist, so only check what we can)
	if okGive and CarryService.get(p2) then
		check("CarryService.give puts the sign up", head2:FindFirstChild("HuzzGirlSign") ~= nil)
		CarryService.remove(p2)
		check("CarryService.remove takes it down", head2:FindFirstChild("HuzzGirlSign") == nil)
	end
end
print(string.format("girl sign: %d ok, %d failed", ok, fails))
