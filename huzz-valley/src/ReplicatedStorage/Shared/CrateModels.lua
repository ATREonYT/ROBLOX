--[[
	Where the owner's 3D knife crates live (owner, Oct 20: "here is the new one with updated crates, make these crates
	for the opening of the normal knifes"). He built them in his place at Workspace > scrates > Standard_Crates: one
	set Model per crate (dojo_set, storm_set, beast_set), each holding his crate Model and the ten little knives he
	laid out in front of it. They stand on a spare lobby copy, which the game puts away, so they are not lobby props:
	they are only shown in Shop > CRATES and the crate opening (UI/Crate3D).

	publish() moves his Standard_Crates folder to ReplicatedStorage > HuzzCrates so every client can clone them into
	a ViewportFrame. The place build does it once (tools/place/build_yours.luau, so Studio's edit view of the
	download shows them there); HuzzServer/Bootstrap does it again at game start for his own Rojo place (searching
	Workspace and ServerStorage, since the spare lobby may already be put away). Never redrawn: his models as they are.

	Config/Crates names each crate's Set, Crate and Body; knifeName() turns a Config/CoinShop knife's Model
	("05_Common_Plain_Tanto") into his little knife's name in the set ("Plain_Tanto").
]]
local CrateModels = {}

CrateModels.Folder = "HuzzCrates" -- (ReplicatedStorage > HuzzCrates)
CrateModels.Source = "Standard_Crates" -- (his folder's name, anywhere under Workspace or ServerStorage)

-- His knife's name in a crate set, from a Config/CoinShop item's Model ("05_Common_Plain_Tanto" -> "Plain_Tanto").
function CrateModels.knifeName(item: any): string?
	return item and type(item.Model) == "string" and string.match(item.Model, "^%d+_%a+_(.+)$") or nil
end

-- Moves his crates to ReplicatedStorage > HuzzCrates (kept when it is already there). Returns the folder or nil.
function CrateModels.publish(workspace: Instance, serverStorage: Instance, replicatedStorage: Instance): Instance?
	local have = replicatedStorage:FindFirstChild(CrateModels.Folder)
	if have then return have end
	local found: Instance? = nil
	for _, root in { workspace, serverStorage } do
		for _, d in root:GetDescendants() do
			if d.Name == CrateModels.Source and #d:GetChildren() > 0 then found = d; break end
		end
		if found then break end
	end
	if not found then return nil end
	local f = found :: Instance
	f.Name = CrateModels.Folder
	f.Parent = replicatedStorage
	return f
end

-- His crate Model and set for a Config/Crates crate (nil until his models are there).
function CrateModels.crate(folder: Instance?, crate: any): (Instance?, Instance?)
	if not folder or not crate or not crate.Model then return nil, nil end
	local set = folder:FindFirstChild(crate.Model.Set)
	local model = set and set:FindFirstChild(crate.Model.Crate)
	return model, set
end

-- The nameless group of his .glb ("Node<n>", right under the crate Model) a part sits in, if any: his file keeps the
-- lid's parts together in one (Shared/CrateMotion.split).
function CrateModels.groupOf(part: Instance, crateModel: Instance): string?
	local node = part.Parent
	while node and node.Parent ~= crateModel do node = node.Parent end
	if node and node ~= crateModel and string.match(node.Name, "^Node%d+$") then return node.Name end
	return nil
end

-- His little knife Model in that crate's set for a Config/CoinShop item (nil when he has none for it).
function CrateModels.knife(set: Instance?, item: any): Instance?
	local name = CrateModels.knifeName(item)
	return set and name and set:FindFirstChild(name) or nil
end

return CrateModels
