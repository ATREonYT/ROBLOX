-- Check: the owner's rarity folders and model names (owner, Oct 27: "make the divine girls be more rare than secrets
-- and be above them ... change the names of the new girls to what their models are named not for example epic girls 9").
-- A folder named "DIVINE GIRLS" or "Secrets" still counts as that rarity (so Divine keeps her low odds and cutscene),
-- a girl shows her model's own name, and an avatar-export name (CAC_R6_<username>_...) never reaches players.
-- From tools/preview: lune run harness.luau ../../src - "$(cat check_girl_folders.luau)" setup_ui.luau
local ok, fails = 0, 0
local function check(name, cond)
	if cond then ok += 1 else fails += 1; print("FAIL " .. name) end
end
local RS = game:GetService("ReplicatedStorage")
local root = Instance.new("Folder"); root.Name = "ANIME GIRLS"; root.Parent = workspace
local function girl(folderName, modelName)
	local f = root:FindFirstChild(folderName) or Instance.new("Folder")
	f.Name = folderName; f.Parent = root
	local m = Instance.new("Model"); m.Name = modelName
	local p = Instance.new("Part"); p.Name = "Head"; p.Parent = m
	m.Parent = f
end
girl("DIVINE GIRLS", "Celestia_Star")
girl("Divine", "  Aurora ")
girl("Secrets", "Night Queen")
girl("epic", "CAC_R6_SomeUser_ABC123")
girl("Mythic Girls", "Luna")
local HS = game.ServerScriptService.HuzzServer
local GirlService = require(HS.GirlService)
GirlService.init()
local by = {}
for _, g in GirlService.catalog do by[g.id] = g end
check("DIVINE GIRLS folder is Divine", by.Celestia_Star and by.Celestia_Star.rarity == "Divine")
check("Divine folder is Divine", by["  Aurora "] and by["  Aurora "].rarity == "Divine")
check("Secrets folder is Secret", by["Night Queen"] and by["Night Queen"].rarity == "Secret")
check("epic folder is Epic", by.CAC_R6_SomeUser_ABC123 and by.CAC_R6_SomeUser_ABC123.rarity == "Epic")
check("Mythic Girls folder is Mythic", by.Luna and by.Luna.rarity == "Mythic")
check("shows her model name", by.Celestia_Star and by.Celestia_Star.name == "Celestia Star")
check("trims spaces", by["  Aurora "] and by["  Aurora "].name == "Aurora")
check("keeps spaces inside", by["Night Queen"] and by["Night Queen"].name == "Night Queen")
check("an avatar export never shows its username", by.CAC_R6_SomeUser_ABC123 and not string.find(by.CAC_R6_SomeUser_ABC123.name, "SomeUser"))
local Round = require(RS.Shared.Config.Round)
local w = {}
for i, r in Round.Rarities do w[r.Name] = { weight = r.Weight, at = i } end
check("Divine rarer than Secret", w.Divine.weight < w.Secret.weight)
check("Divine listed above Secret", w.Divine.at > w.Secret.at)
check("Divine gets her real weight", GirlService.rarity("Divine").Weight == w.Divine.weight)
local divine, n = 0, 20000
for _ = 1, n do
	local g = GirlService.roll()
	if g and g.rarity == "Divine" then divine += 1 end
end
local secret = 0
for _ = 1, n do
	local g = GirlService.roll()
	if g and g.rarity == "Secret" then secret += 1 end
end
check(`Divine rolls less than Secret ({divine} vs {secret} in {n})`, divine < secret)
print(`girl folders: {ok} ok, {fails} failed`)
return ""
