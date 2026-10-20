-- Check: the owner's 3D knife crates on screen (owner, Oct 20: "make these crates for the opening of the normal knifes
-- ... and make the opening animations look appropriate"; his crate shop mockup the same night). His models can't be
-- loaded here (the harness builds the game from src/ only), so this puts a small crate shaped like his into
-- ReplicatedStorage > HuzzCrates (a body, a lid, the light inside, his knives named like his) and checks that:
--   * Shop > CRATES draws it in a ViewportFrame on its card (UI/Crate3D), open for the Beast as on the mockup;
--   * OPEN plays the 3D opening (no reel): the crate rocks, the lid swings up, the knife from the same set rises,
--     then its name and rarity, NEW!, the buttons; at most one flash a second; skip goes straight to the prize;
--   * the body and the light inside never move, only the top swings;
--   * a crate whose model arrives after the Shop was built (a slow join) swaps its plain crate for his;
--   * each card has its own sparkles (the mockup's colours), and the reveal puts a light behind the knife.
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

-- 1. the shop card draws his crate (open, as the mockup draws the Beast Chest)
MM.open("Shop", "Crates")
task.wait(0.2)
local body2 = gui.Shop:FindFirstChild("Products", true)
local card = body2 and body2:FindFirstChild("CardBeast")
local vp = card and card:FindFirstChild("Crate3D", true)
check("the Beast card draws his crate in a ViewportFrame", vp ~= nil and vp:IsA("ViewportFrame") and vp:FindFirstChildOfClass("Camera") ~= nil)
check("no plain crate on that card", card ~= nil and card:FindFirstChild("CratePicture", true) == nil)
check("the crates without his model there draw the plain crate", body2:FindFirstChild("CardDojo") ~= nil and body2.CardDojo:FindFirstChild("CratePicture", true) ~= nil)
check("it is built at run time only (never saved in StarterGui)", vp ~= nil and vp:GetAttribute("RuntimeOnly") == true)
local copy = vp and vp:FindFirstChildOfClass("Model")
local cLid = copy and copy:FindFirstChild("chest_lid", true)
local cBody = copy and copy:FindFirstChild(beast.Model.Body, true)
check("on the card it stands as he built it (the lid where he put it)", cLid ~= nil and cBody ~= nil and (cBody.CFrame:PointToObjectSpace(cLid.CFrame.Position) - Vector3.new(0, 0.8, 0)).Magnitude < 0.01)
local function sparkles(c)
	local out = {}
	for _, d in c:GetDescendants() do if d:GetAttribute("Sparkle") then table.insert(out, d) end end
	return out
end
local bs, ds = sparkles(card), sparkles(body2.CardDojo)
check(`each card has its own sparkles (Beast {#bs}, Dojo {#ds})`, #bs == 7 and #ds == 3 and card:FindFirstChild("Sparkle1", true).ImageColor3 == Color3.fromHex("FF5CE8"))
check("the Dojo's are white 4-point stars", ds[1]:GetAttribute("Icon") == "SparkleStar" and ds[1].ImageColor3 == Color3.new(1, 1, 1))

-- 1b. his Dojo Chest arrives late (after the Shop was built): its card swaps the plain crate for his
local dojo = Crates.get("Dojo")
local dSet = Instance.new("Model"); dSet.Name = dojo.Model.Set
local dCrate = Instance.new("Model"); dCrate.Name = dojo.Model.Crate; dCrate.Parent = dSet
part(dCrate, dojo.Model.Body, base + Vector3.new(0, 0.6, 0), Vector3.new(1.8, 1.2, 1.6))
part(dCrate, "roof", base + Vector3.new(0, 1.4, 0), Vector3.new(2, 0.4, 1.8))
dSet.Parent = RS.HuzzCrates
__fireOn(RS.HuzzCrates, "DescendantAdded", dCrate)
task.wait(0.1)
check("a late Dojo Chest replaces the plain crate on its card", body2.CardDojo:FindFirstChild("Crate3D", true) ~= nil and body2.CardDojo:FindFirstChild("CratePicture", true) == nil)

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
		if clock < 2.2 and knife and knife.Parent then
			for _, d in knife:GetDescendants() do if d:IsA("BasePart") and d.Transparency < 1 then knifeSeenEarly = true end end
		end
	end
end
frames(30) -- 1 s: building up
check(string.format("it rocks while it builds up (%.1f deg)", maxRoll), maxRoll > 1 and maxRoll < 16)
check("the odds by rarity show under it while it builds up", screen.Group.Odds.Visible and screen.Group.Odds.Chip1.Visible)
check("still shut while it builds up", (rel(oLid) - lidRel0).Magnitude < 0.05)
frames(36) -- 2.2 s: open
local lidNow = rel(oLid)
check(string.format("the lid swings up and back as it opens (z %.2f -> %.2f)", lidRel0.Z, lidNow.Z), lidNow.Z > lidRel0.Z + 0.3)
check("the light inside never moves", (rel(oInside) - insideRel0).Magnitude < 0.01)
check("no knife before it opens", not knifeSeenEarly)
frames(45) -- 3.7 s: the reveal
local seen = false
for _, d in knife:GetDescendants() do if d:IsA("BasePart") and d.Transparency < 1 then seen = true end end
check("the knife has risen out of it", seen)
local name = screen:FindFirstChild("KnifeName", true)
check(`its name shows ({name and name.Text})`, name ~= nil and name.Visible and name.Text ~= "")
check("its rarity shows", screen:FindFirstChild("KnifeRarity", true).Visible)
local light = screen:FindFirstChild("KnifeLight", true)
check("a soft light stands behind the knife", light ~= nil and light.Visible and light.ImageTransparency < 0.5)
frames(30)
check("NEW! or the coins line shows", screen.Group.Status.Visible and screen.Group.Status.Text ~= "")
check("OPEN AGAIN and BACK show", screen.Group.Bottom.Visible)
check(`at most one flash a second ({#flashes})`, #flashes <= 1 or (flashes[2] - flashes[1]) >= 1)
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
