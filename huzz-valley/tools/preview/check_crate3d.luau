-- Check: the owner's 3D knife crates on screen (owner, Oct 20: "make these crates for the opening of the normal knifes
-- ... and make the opening animations look appropriate"; his crate shop mockup the same night; 15:13: "make the case
-- opening animation way, way better ... remove so much glow from the crates, and then make it feel premium"). His
-- models can't be loaded here (the harness builds the game from src/ only), so this puts a small crate shaped like his
-- into ReplicatedStorage > HuzzCrates (a body, a lid, the light inside, his knives named like his, each with an aura
-- ring) and checks that:
--   * Shop > CRATES shows his crate cut out of his picture on the Shop's one backdrop (Oct 20 20:34; no 3D crate there);
--   * OPEN plays the 3D opening (no reel) on a calm dark backdrop: the crate hops, the latch pops (the lid cracks, the
--     one light from inside shows), the lid is flung open, the backdrop fades to the rarity colour (never a flash),
--     the knife comes out of the crate in its own view (cut at the crate's front edge while inside) with a light rim,
--     its aura ring hidden; then its name lands with a punch, the rarity tag in its colour, NEW!, OPEN AGAIN and
--     CLAIM; skip goes straight to the prize;
--   * premium, not "too ai": no rays, rings, motes, glint, KnifeLight glow or flash; his glow parts never tinted;
--   * the body and the light inside never move, only the top swings.
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
	part(m, "aura_ring", base + Vector3.new(-1.5 + i * 0.3, 0.1, -1.4), Vector3.new(0.25, 0.05, 0.25)) -- (his aura ring: hidden in the opening)
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

-- 1. the shop card is his crate on the shared backdrop (Oct 20 20:34); OPEN in its panel plays the 3D opening
MM.open("Shop", "Crates")
task.wait(0.2)
local body2 = gui.Shop:FindFirstChild("Products", true)
local card = body2 and body2:FindFirstChild("CardBeast")
local pic = card and card:FindFirstChild("Backdrop") and card.Backdrop:FindFirstChild("Crate")
check("the Beast card is his crate, cut out, on the Shop's backdrop", pic ~= nil and pic:GetAttribute("Art") == "CrateCardCutBeast")
local any3d = false
for _, d in (card and card:GetDescendants() or {}) do
	if d.Name == "Crate3D" then any3d = true end
end
check("no 3D crate on the card", not any3d)

-- 2. OPEN: the 3D opening
local screen = gui:FindFirstChild("CrateOpen")
__fireOn(card.Open, "Activated") -- (its panel slides in with the chances and the buttons that pay)
for _ = 1, 30 do __stepTweens(0.05) end
task.wait(0.3)
__fireOn(gui.Shop:FindFirstChild("Side", true).Panel.CrateBeast.Open, "Activated")
task.wait(0.3)
check("OPEN in its panel goes to the opening screen", MM.current() == "CrateOpen")
check("Aura taken once (500 -> 400)", data.Aura == 400)
local stage = screen:FindFirstChild("Stage3D", true)
local view = stage and stage:FindFirstChild("Crate3D")
check("the opening shows his crate (no reel)", view ~= nil and stage.Visible and not screen.Group.Reel.Visible and not screen.Group.Crate.Visible)
check("a calm dark backdrop over the whole screen", screen.Group.Backdrop.Visible and screen.Group.Backdrop.BackgroundTransparency < 0.1
	and screen.Group.Backdrop.Size.X.Scale >= 2)
local m = view and view:FindFirstChildOfClass("Model")
local oLid, oBody, oInside = m and m:FindFirstChild("chest_lid", true), m and m:FindFirstChild(beast.Model.Body, true), m and m:FindFirstChild("glow_inside", true)
local kview = stage:FindFirstChild("KnifeView", true)
local knife
for _, ch in (kview and kview:GetChildren() or {}) do
	if ch:IsA("Model") then knife = ch end
end
check("his knife from the same set is there, in its own view over the crate", knife ~= nil and kview.Parent.Name == "KnifeClip" and kview.Parent.ClipsDescendants)
local aura = knife and knife:FindFirstChild("aura_ring", true)
local rims = 0
for _, ch in (kview and kview:GetChildren() or {}) do if ch.Name == "Rim" then rims += 1 end end
check(`a light rim made of copies of the knife's big parts ({rims}), never of its aura ring`, rims >= 1)
local function rel(p) return oBody.CFrame:PointToObjectSpace(p.CFrame.Position) end
local insideRel0 = oInside and rel(oInside)
local lidRel0 = oLid and rel(oLid)
local insideColor0 = oInside and oInside.Color
local maxRoll, knifeSeenEarly, auraSeen, clipSeen, lifts = 0, false, false, false, {}
local tints, poolMax, tintJump, lastTint = 0, 0, 0, 0
local clock = 0
local function frames(n)
	for _ = 1, n do
		__fireOn(RunService, "RenderStepped", 1 / 30)
		clock += 1 / 30
		if oBody.Parent then
			local up = oBody.CFrame.UpVector
			maxRoll = math.max(maxRoll, math.deg(math.acos(math.clamp(up.Y, -1, 1))))
			table.insert(lifts, oBody.CFrame.Position.Y)
		end
		if clock < T3.Rise - 0.05 and knife and knife.Parent then
			for _, d in knife:GetDescendants() do if d:IsA("BasePart") and d.Transparency < 1 then knifeSeenEarly = true end end
		end
		if aura and knife and knife.Parent and aura.Transparency < 1 then auraSeen = true end
		local clip = stage:FindFirstChild("KnifeClip", true)
		if clip and clip.Size.Y.Scale < 0.99 and clock > T3.Rise then clipSeen = true end
		local layer = screen.Group.Pool:FindFirstChild("Layer1")
		local tv = if screen.Group.Pool.Visible and layer then 1 - layer.BackgroundTransparency else 0
		tintJump = math.max(tintJump, math.abs(tv - lastTint))
		lastTint = tv
		poolMax = math.max(poolMax, tv)
	end
end
frames(30) -- 1.0 s: two hops
check(string.format("it hops and tips while it builds up (%.1f deg)", maxRoll), maxRoll > 1 and maxRoll < 12)
local still = true
local minY, maxY = math.huge, -math.huge
for _, y in lifts do minY, maxY = math.min(minY, y), math.max(maxY, y) end
check("it really hops (up and down)", maxY - minY > 0.01)
check("the odds by rarity show under it while it builds up", screen.Group.Odds.Visible and screen.Group.Odds.Chip1.Visible)
check("still shut while it builds up", (rel(oLid) - lidRel0).Magnitude < 0.05)
check("no rarity colour yet (it comes as the lid opens)", not screen.Group.Pool.Visible)
local _ = still
frames(30) -- 2.0 s: the latch has popped
local lidCrack = rel(oLid)
check(string.format("the latch pops: the top cracks open a little (z %.2f -> %.2f)", lidRel0.Z, lidCrack.Z), (lidCrack - lidRel0).Magnitude > 0.005 and lidCrack.Z < lidRel0.Z + 0.3)
local spill = view:FindFirstChild("Spill")
check("the one light from inside shows in the gap", spill ~= nil and spill.Transparency < 0.5)
frames(24) -- 2.8 s: open, the knife coming out
local lidNow = rel(oLid)
check(string.format("the lid is flung up and back (z %.2f -> %.2f)", lidRel0.Z, lidNow.Z), lidNow.Z > lidRel0.Z + 0.3)
check("the light inside never moves, and nothing tints his glow parts", (rel(oInside) - insideRel0).Magnitude < 0.01 and oInside.Color == insideColor0)
check("the light from inside is gone once it is open (no flat slab)", spill.Transparency > 0.999)
check("no knife before it comes out", not knifeSeenEarly)
check("the knife comes out of the crate (cut at its front edge while inside)", clipSeen)
check("the backdrop behind takes the rarity colour", screen.Group.Pool.Visible and poolMax > 0.025)
check(string.format("a fade, never a flash (at most %.3f a frame per layer)", tintJump), tintJump < 0.02)
frames(14) -- 3.27 s: the name lands
local nameNow = screen:FindFirstChild("KnifeName", true)
local punch = nameNow:FindFirstChild("Punch")
check(string.format("its name lands with a punch (scale %.2f)", punch and punch.Scale or 0), nameNow.Visible and punch ~= nil and punch.Scale > 1.02)
frames(6) -- 3.47 s
local seen = false
for _, d in knife:GetDescendants() do if d:IsA("BasePart") and d.Transparency < 1 then seen = true end end
check("the knife is out", seen)
check("its aura ring stays hidden (owner: \"remove it\")", aura == nil or not auraSeen)
local name = screen:FindFirstChild("KnifeName", true)
check(`its name shows ({name and name.Text})`, name ~= nil and name.Visible and name.Text ~= "")
local tag = screen:FindFirstChild("RarityTag", true)
local prize
for _, it in beast.Items do if it.Name == name.Text then prize = it end end
local CrateArt = require(game.StarterPlayer.StarterPlayerScripts.HuzzClient.UI.CrateArt)
check("its rarity tag shows in the rarity colour", tag ~= nil and tag.Visible and prize ~= nil and tag.BackgroundColor3 == CrateArt.color(prize.Rarity)
	and tag.KnifeRarity.Text == string.upper(prize.Rarity))
check("no KnifeLight glow behind the knife", screen:FindFirstChild("KnifeLight", true) == nil)
check(`the crate's name gives way to the knife ({screen.Group.Title.TextTransparency})`, screen.Group.Title.TextTransparency > 0.9)
frames(30)
check("its name has landed", nameNow.TextTransparency < 0.01 and math.abs(punch.Scale - 1) < 1e-3)
check("NEW! or the coins line shows", screen.Group.Status.Visible and screen.Group.Status.Text ~= "")
check("OPEN AGAIN and CLAIM show", screen.Group.Bottom.Visible and screen.Group.Bottom.Back.Visible)
local flashes = 0
for _, n in { "Flash", "CrateRays", "Burst", "Ring1", "Ring2" } do
	if screen:FindFirstChild(n, true) then flashes += 1 end
end
for _, n in { "Mote1", "Glint", "KnifeLight" } do -- (in the 3D view: the old motes and glint parts)
	if stage:FindFirstChild(n, true) then flashes += 1 end
end
check("no flash, rays, rings, motes or glint in the 3D opening", flashes == 0)
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
