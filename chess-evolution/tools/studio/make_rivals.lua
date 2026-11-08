-- +1 Chess Evolution: rebuilds ServerStorage > ChessRivals from real Roblox catalog items.
-- Paste into Studio's Command Bar (Edit mode). It reports on lines starting with [Rivals].
-- Every id below came from AvatarEditorService:SearchCatalog with creator "Roblox", not from guessing.
-- NPCs can wear any catalog item, so nobody has to own them.
local Players = game:GetService("Players")
local folder = game.ServerStorage:FindFirstChild("ChessRivals") or Instance.new("Folder")
folder.Name = "ChessRivals"
folder.Parent = game.ServerStorage
folder:ClearAllChildren()
local C = Color3.fromRGB
local SK = { C(255, 214, 170), C(234, 184, 140), C(198, 140, 100), C(141, 92, 62), C(250, 205, 180) }
-- A ladder from park player to world champion: clothes get more formal, poise and size go up,
-- and chess flair grows (chess tee, then the "!!" brilliant icon, then the champion's crown and aura).
-- acc = extra accessories as { id, AccessoryType }.
local AT = Enum.AccessoryType
local RIVALS = {
	{ id = "PawnPete", name = "Pawn Pete", title = "Park Player", stage = 1, skin = SK[1], hair = "63690008", hat = "607702162",
		tshirt = 71221853714181, shirt = 382538059, pants = 382538503, scale = 1.0 },
	{ id = "KnightNadia", name = "Knight Nadia", title = "Club Player", stage = 2, skin = SK[3], hair = "376527350",
		shirt = 144076358, pants = 382537569, sweater = 9240758221, scale = 1.02 },
	{ id = "RookRocco", name = "Rook Rocco", title = "Tournament Player", stage = 3, skin = SK[2], hair = "376524487", hat = "3533875312",
		shirt = 14478025982, pants = 129459077, scale = 1.04 },
	{ id = "BishopBea", name = "Bishop Bea", title = "Candidate Master", stage = 4, skin = SK[5], hair = "81688919", face = "11884330",
		shirt = 107484591664508, pants = 138627474864249, undershirt = C(245, 245, 245), scale = 1.06 },
	{ id = "QueenQuinn", name = "Queen Quinn", title = "International Master", stage = 5, skin = SK[4], hair = "376526888", hat = "1031418",
		shirt = 11996637526, pants = 138627474864249, scale = 1.08 },
	{ id = "KingKai", name = "King Kai", title = "Grandmaster", stage = 6, skin = SK[2], hair = "376548738",
		shirt = 136245704733357, pants = 129459077, jacket = 12300764586, neck = "28554622",
		acc = { { 135230198494014, AT.Shoulder } }, scale = 1.12 },
	{ id = "GrandmasterOrion", name = "Grandmaster Orion", title = "World Champion", stage = 7, skin = SK[1], hair = "1744250468", hat = "18534733183",
		back = "1340205609", shirt = 9739333519, pants = 129459077, neck = "28554622",
		acc = { { 125411092824350, AT.Shoulder } }, scale = 1.22 },
}
for _, r in RIVALS do
	local d = Instance.new("HumanoidDescription")
	for _, k in { "HeadColor", "TorsoColor", "LeftArmColor", "RightArmColor", "LeftLegColor", "RightLegColor" } do d[k] = r.skin end
	if r.undershirt then d.TorsoColor = r.undershirt end -- open blazers show the torso colour as the shirt
	d.HairAccessory, d.HatAccessory, d.FaceAccessory, d.BackAccessory = r.hair or "", r.hat or "", r.face or "", r.back or ""
	d.NeckAccessory = r.neck or ""
	d.Shirt, d.Pants, d.GraphicTShirt = r.shirt or 0, r.pants or 0, r.tshirt or 0
	local acc = d:GetAccessories(true)
	if r.sweater then table.insert(acc, { AssetId = r.sweater, AccessoryType = Enum.AccessoryType.Sweater, Order = 2, IsLayered = true }) end
	if r.jacket then table.insert(acc, { AssetId = r.jacket, AccessoryType = Enum.AccessoryType.Jacket, Order = 3, IsLayered = true }) end
	for _, a in r.acc or {} do table.insert(acc, { AssetId = a[1], AccessoryType = a[2], IsLayered = false }) end
	d:SetAccessories(acc, true)
	if r.scale then d.HeightScale, d.WidthScale, d.DepthScale, d.HeadScale = r.scale, r.scale, r.scale, r.scale end
	local ok, m = pcall(Players.CreateHumanoidModelFromDescription, Players, d, Enum.HumanoidRigType.R15)
	if not ok then warn("[Rivals] " .. r.id .. " failed: " .. tostring(m)) continue end
	m.Name = r.id
	local hum = m:FindFirstChildOfClass("Humanoid")
	hum.DisplayName = r.name
	hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	if not hum:FindFirstChildOfClass("Animator") then Instance.new("Animator").Parent = hum end
	for _, s in m:GetDescendants() do if s:IsA("LuaSourceContainer") then s:Destroy() end end
	m:SetAttribute("RivalId", r.id); m:SetAttribute("DisplayName", r.name); m:SetAttribute("Stage", r.stage); m:SetAttribute("Scale", r.scale or 1); m:SetAttribute("Title", r.title)
	local hrp = m:FindFirstChild("HumanoidRootPart")
	hrp.Anchored = true
	m.PrimaryPart = hrp
	-- pivot at the feet, facing -Z, so rival:PivotTo(table.SeatB.CFrame) stands it on the pad
	local lowest = math.huge
	for _, p in m:GetChildren() do if p:IsA("BasePart") and p.Name:find("Foot") then lowest = math.min(lowest, p.Position.Y - p.Size.Y / 2) end end
	hrp.PivotOffset = CFrame.new(0, -(hrp.Position.Y - lowest), 0)
	m:PivotTo(CFrame.new())
	m.Parent = folder
	print("[Rivals] built " .. r.id)
	task.wait()
end
