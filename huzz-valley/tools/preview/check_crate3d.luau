-- Check: the owner's 3D knife crates on screen (owner, Oct 20: "make these crates for the opening of the normal knifes
-- ... and make the opening animations look appropriate"; his crate shop mockup the same night). His models can't be
-- loaded here (the harness builds the game from src/ only), so this puts a small crate shaped like his into
-- ReplicatedStorage > HuzzCrates (a body, a lid, the light inside, his knives named like his) and checks that:
--   * Shop > CRATES shows his own picture of the cards (no 3D crate there since Oct 20, 07:23);
--   * OPEN plays the 3D opening (no reel): the crate rocks, the top cracks a little and holds, then swings up, the
--     knife from the same set rises, a few motes drift up, one glint; then its name and rarity fade in, NEW!, the
--     buttons; skip goes straight to the prize;
--   * premium, not "too ai" (owner, Oct 20 07:51): no rays, rings, sparks or flash in the 3D opening;
--   * the body and the light inside never move, only the top swings;
--   * a soft light stands behind the knife only when its blade is dark (Hollow Moon).
-- From tools/preview: lune run harness.luau ../../src - @check_crate3d.luau setup_ui.luau
local ok, fails = 0, 0
local function check(name, cond)
	if cond then ok += 1 else fails += 1; print("FAIL " .. name) end
end
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

-- a crate like his Void Beast Chest (front to -Z, built square to the world), and his knives beside it
local Crates = require(RS.Shared.Config.Crates)
local CoinShop = require(RS.Shared.Config.CoinShop)
local CrateModels = require(RS.Shared.CrateModels)
local CrateMotion = require(RS.Shared.CrateMotion)
local T3 = CrateMotion.T
local beast = Crates.get("Beast")
local folder = Instance.new("Folder"); folder.Name = "Standard_Crates"
local set = Instance.new("Model"); set.Name = beast.Model.Set; set.Parent = folder
local crateM = Instance.new("Model"); crateM.Name = beast.Model.Crate; crateM.Parent = set
local function part(parent, name, pos, size)
	local p = Instance.new("MeshPart"); p.Name = name; p.Size = size; p.CFrame = CFrame.new(pos); p.Parent = parent
	return p
end
local base = Vector3.new(-278, 13.3, -696)
local body = part(crateM, beast.Model.Body, base + Vector3.new(0, 0.6, 0), Vector3.new(1.8, 1.2, 1.6))
local jaw = Instance.new("Model"); jaw.Name = "Node1464"; jaw.Parent = crateM -- (his .glb's lid group)
local lid = part(jaw, "chest_lid", base + Vector3.new(0, 1.4, 0), Vector3.new(1.8, 0.4, 1.6))
local horn = part(jaw, "horn_3", base + Vector3.new(0.5, 1.8, 0.2), Vector3.new(0.2, 0.5, 0.2))
local inside = part(crateM, "glow_inside", base + Vector3.new(0, 1.15, 0), Vector3.new(1.5, 0.1, 1.3))
Instance.new("SurfaceAppearance").Parent = inside
for i, it in beast.Items do
	local m = Instance.new("Model"); m.Name = CrateModels.knifeName(CoinShop.get(it.Id)); m.Parent = set
	part(m, "blade_1", base + Vector3.new(-1.5 + i * 0.3, 0.3, -1.4), Vector3.new(0.08, 0.45, 0.04))
	part(m, "handle", base + Vector3.new(-1.5 + i * 0.3, 0.05, -1.4), Vector3.new(0.06, 0.15, 0.06))
end
local scrates = Instance.new("Folder"); scrates.Name = "scrates"; scrates.Parent = workspace
folder.Parent = scrates

local me = Instance.new("Player"); me.Name = "Tester"; me.UserId = 78; me.Parent = Players
Players.LocalPlayer = me
Instance.new("PlayerGui").Parent = me
__copyStarterGui(me)
__runScript(game.ServerScriptService.HuzzServer.Bootstrap)
task.wait(0.1)
check("the game start moves his crates to ReplicatedStorage > HuzzCrates", RS:FindFirstChild("HuzzCrates") ~= nil and RS.HuzzCrates:FindFirstChild(beast.Model.Set) ~= nil)
__fireOn(Players, "PlayerAdded", me)
task.wait(0.3)
local HS = game.ServerScriptService.HuzzServer
local DataService = require(HS.DataService)
local data = DataService.get(me).Data
DataService.update(me, function(d) d.Aura, d.Coins = 500, 1000 end)
__runScript(game.StarterPlayer.StarterPlayerScripts.HuzzClient.Main)
task.wait(0.3)
local MM = require(game.StarterPlayer.StarterPlayerScripts.HuzzClient.UI.ModalManager)
local gui = me.PlayerGui:FindFirstChild("HuzzUI")

-- 1. the shop card is his picture (Oct 20, 07:23); OPEN on it plays the 3D opening
MM.open("Shop", "Crates")
task.wait(0.2)
local body2 = gui.Shop:FindFirstChild("Products", true)
local card = body2 and body2:FindFirstChild("CardBeast")
check("the Beast card is his picture, no 3D crate on it", card ~= nil and card:FindFirstChild("Picture") ~= nil and card:FindFirstChild("Crate3D", true) == nil)

-- 2. OPEN: the 3D opening
local screen = gui:FindFirstChild("CrateOpen")
__fireOn(card.Open, "Activated")
task.wait(0.3)
check("OPEN goes to the opening screen", MM.current() == "CrateOpen")
check("Aura taken once (500 -> 400)", data.Aura == 400)
local stage = screen:FindFirstChild("Stage3D", true)
local view = stage and stage:FindFirstChild("Crate3D")
check("the opening shows his crate (no reel)", view ~= nil and stage.Visible and not screen.Group.Reel.Visible and not screen.Group.Crate.Visible)
local m = view and view:FindFirstChildOfClass("Model")
local oLid, oBody, oInside = m and m:FindFirstChild("chest_lid", true), m and m:FindFirstChild(beast.Model.Body, true), m and m:FindFirstChild("glow_inside", true)
local knife
for _, ch in (view and view:GetChildren() or {}) do
	if ch:IsA("Model") and ch ~= m then knife = ch end
end
check("his knife from the same set is there for the reveal", knife ~= nil)
local function rel(p) return oBody.CFrame:PointToObjectSpace(p.CFrame.Position) end
local insideRel0 = oInside and rel(oInside)
local lidRel0 = oLid and rel(oLid)
local flash = screen:FindFirstChild("Flash", true)
local flashes, wasFlash, maxRoll, knifeSeenEarly = {}, false, 0, false
local rays = screen:FindFirstChild("CrateRays", true)
local raysSeen, motesSeen, glintFrames, fxSeen = false, 0, 0, false
local clock = 0
local function frames(n)
	for _ = 1, n do
		__fireOn(RunService, "RenderStepped", 1 / 30)
		clock += 1 / 30
		if flash.Visible and not wasFlash then table.insert(flashes, clock) end
		wasFlash = flash.Visible
		if oBody.Parent then
			local up = oBody.CFrame.UpVector
			maxRoll = math.max(maxRoll, math.deg(math.acos(math.clamp(up.Y, -1, 1))))
		end
		if rays.Visible then raysSeen = true end
		for _, d in screen:GetDescendants() do
			if (string.match(d.Name, "^Ring%d") or string.match(d.Name, "^Spark%d")) and d:IsA("GuiObject") and d.Visible then fxSeen = true end
		end
		local shown = 0
		for _, d in (stage:FindFirstChild("Crate3D") or stage):GetChildren() do
			if string.match(d.Name, "^Mote%d") and d.Transparency < 1 then shown += 1 end
			if d.Name == "Glint" and d.Transparency < 1 then glintFrames += 1 end
		end
		motesSeen = math.max(motesSeen, shown)
		if clock < T3.Rise - 0.05 and knife and knife.Parent then
			for _, d in knife:GetDescendants() do if d:IsA("BasePart") and d.Transparency < 1 then knifeSeenEarly = true end end
		end
	end
end
frames(30) -- 1 s: building up
check(string.format("it rocks while it builds up (%.1f deg)", maxRoll), maxRoll > 1 and maxRoll < 16)
check("the odds by rarity show under it while it builds up", screen.Group.Odds.Visible and screen.Group.Odds.Chip1.Visible)
check("still shut while it builds up", (rel(oLid) - lidRel0).Magnitude < 0.05)
frames(42) -- 2.4 s: cracked a little
local lidCrack = rel(oLid)
check(string.format("the top cracks open a little first (z %.2f -> %.2f)", lidRel0.Z, lidCrack.Z), (lidCrack - lidRel0).Magnitude > 0.005 and lidCrack.Z < lidRel0.Z + 0.3)
frames(27) -- 3.3 s: open
local lidNow = rel(oLid)
check(string.format("the lid swings up and back as it opens (z %.2f -> %.2f)", lidRel0.Z, lidNow.Z), lidNow.Z > lidRel0.Z + 0.3)
check("the light inside never moves", (rel(oInside) - insideRel0).Magnitude < 0.01)
check("no knife before it opens", not knifeSeenEarly)
frames(36) -- 4.5 s: the reveal (4.45 s)
local nameNow = screen:FindFirstChild("KnifeName", true)
check(string.format("its name fades in, not at once (%.2f)", nameNow.TextTransparency), nameNow.Visible and nameNow.TextTransparency > 0.3)
frames(6) -- 4.7 s
local seen = false
for _, d in knife:GetDescendants() do if d:IsA("BasePart") and d.Transparency < 1 then seen = true end end
check("the knife has risen out of it", seen)
local name = screen:FindFirstChild("KnifeName", true)
check(`its name shows ({name and name.Text})`, name ~= nil and name.Visible and name.Text ~= "")
check("its rarity shows", screen:FindFirstChild("KnifeRarity", true).Visible)
local light = screen:FindFirstChild("KnifeLight", true)
local prize
for _, it in beast.Items do if it.Name == name.Text then prize = it end end
local pc = prize and CoinShop.get(prize.Id)
local isDark = CrateMotion.isDark(pc and pc.Colors and pc.Colors[1])
check(`a soft light behind the knife only for a dark blade ({name.Text}: {isDark and "dark" or "not dark"})`, light ~= nil
	and (if isDark then light.Visible and light.ImageTransparency < 0.6 and light.Size.Y.Offset > light.Size.X.Offset * 2 else not light.Visible))
check(`a few motes drift up, never a burst (at most {motesSeen} at once)`, motesSeen >= 1 and motesSeen <= CrateMotion.Motes)
check(`one glint along the blade ({glintFrames} frames)`, glintFrames >= 5 and glintFrames <= 20)
frames(30)
check("its name has faded in", nameNow.TextTransparency < 0.01)
check("NEW! or the coins line shows", screen.Group.Status.Visible and screen.Group.Status.Text ~= "")
check("OPEN AGAIN and BACK show", screen.Group.Bottom.Visible)
check(`no flash in the 3D opening ({#flashes})`, #flashes == 0)
check("no rays, rings or sparks in the 3D opening", not raysSeen and not fxSeen)
local item = beast.Items[1]
check("the prize is yours", data.Cosmetics ~= nil and next(data.Cosmetics) ~= nil)

-- 3. OPEN AGAIN, then skip straight to the prize
__fireOn(screen:FindFirstChild("OpenAgain", true), "Activated")
task.wait(0.3)
check("OPEN AGAIN took 100 more (400 -> 300)", data.Aura == 300)
frames(5)
__fireOn(screen:FindFirstChild("Skip", true), "Activated")
frames(30)
check("a tap skips to the prize", screen:FindFirstChild("KnifeName", true).Visible and screen.Group.Bottom.Visible)
local _ = item

print(string.format("crate3d: %d ok, %d failed", ok, fails))
