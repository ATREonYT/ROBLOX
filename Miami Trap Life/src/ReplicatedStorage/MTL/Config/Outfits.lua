--!strict
-- Shared outfits for NPCs (ambient people now; cutscenes and jobs can use them too). Each one is a full
-- HumanoidDescription: real skin tone, catalog hair/hat (Hats), shirt + pants (classic clothing), sometimes a chain
-- (Neck), a bag (Back) or bangs/short hair (Face accessories). Ids are public Creator Marketplace items found with the
-- catalog API on 2026-11-02 (generic names only, no brand knock-offs). Alex: swap any id for a better one; 0 = none.
-- Built on the server by Services/AmbientRigService (Players:CreateHumanoidModelFromDescription, R15). If an item fails
-- to load the rig is rebuilt with colours only, so a bad id never costs us the person.
--   Outfits.description(outfit, plain?) -> HumanoidDescription
--   Outfits.byRole(role) -> { id }      Outfits.ambientIds(roles) -> { id }
local C = Color3.fromRGB

local Outfits = {}

export type Outfit = {
	Role: string,
	Skin: Color3,
	Shirt: number?,
	Pants: number?,
	Hats: { number }?,
	Face: { number }?, -- face accessories (bangs, short hair)
	Neck: { number }?,
	Back: { number }?,
	ShirtColor: Color3?, -- torso colour under the shirt / when plain
	PantsColor: Color3?,
	Height: number?,
}

-- skin tones (real range, mostly brown: it's Liberty Heights)
local SK = {
	C(58, 40, 32), C(74, 50, 38), C(92, 62, 46), C(110, 74, 52), C(128, 86, 60),
	C(150, 104, 72), C(172, 122, 86), C(198, 150, 112), C(224, 184, 152),
}

-- catalog items (Creator Marketplace)
local I = {
	-- shirts
	WhiteTee = 103583755955229, WhiteTee2 = 7855041382, Tank = 6145043612, Tank2 = 7448140301,
	Flannel = 78714973796689, Flannel2 = 6071039031, Jersey = 1463961859, Jersey2 = 5391350500,
	Sweater = 76388218976956, Sweater2 = 10082424346, Polo = 7435394290, Polo2 = 5323358274,
	ChurchSuit = 5098849111, Hoodie = 3469262007, Hoodie2 = 881361325, Hoodie3 = 6904944249, Uniform = 4871829951,
	-- pants
	Jeans = 101970051814016, Jeans2 = 5895321617, Jeans3 = 137249345759567,
	Sweats = 6020586634, Sweats2 = 5193737022, Sweats3 = 78658399064814,
	Shorts = 5551536418, Shorts2 = 4526708605, Cargo = 6554993857, Cargo2 = 83846196721115,
	Skirt = 6952483641, Skirt2 = 8537077071, Slacks = 1281704171, Slacks2 = 15036182444,
	-- hair (hat-type accessories)
	Dreads = 138787823412343, Dreads2 = 87816698159243, Dreads3 = 123473321647874,
	Afro = 110593213657584, AfroBrown = 115347302790448, AfroCurly = 15442744585,
	Braids = 100720528915971, Braids2 = 134380023977127, GrayHair = 97396641893799,
	-- short hair / bangs (face accessories)
	ShortBlack = 14610802451, ShortBlack2 = 15688836776,
	-- hats
	Durag = 32132836, DuragBlack = 136235011069192, DuragGray = 76119996540113,
	Beanie = 16150990347, Beanie2 = 14414027540, Cap = 129057054940664, Cap2 = 18221928871, Cap3 = 10967701637,
	ChurchHatBlack = 127501110899299, ChurchHatWhite = 119935932695372, ChurchHat = 133635436823097,
	Bucket = 13998035099, Bucket2 = 15505770571,
	-- extras
	Chain = 100390764800210, Chain2 = 131921760594564, Chain3 = 138878513242930,
	Backpack = 18166289334, Backpack2 = 10558534981,
}
Outfits.Items = I

Outfits.List = {
	-- street: the corner, the stoops, walking the block
	Street1 = { Role = "Street", Skin = SK[2], Shirt = I.WhiteTee, Pants = I.Jeans, Hats = { I.DuragBlack }, Neck = { I.Chain } },
	Street2 = { Role = "Street", Skin = SK[4], Shirt = I.Hoodie, Pants = I.Sweats, Hats = { I.Dreads } },
	Street3 = { Role = "Street", Skin = SK[3], Shirt = I.Tank, Pants = I.Shorts, Hats = { I.Cap }, Neck = { I.Chain2 } },
	Street4 = { Role = "Street", Skin = SK[6], Shirt = I.Flannel, Pants = I.Cargo, Face = { I.ShortBlack } },
	Street5 = { Role = "Street", Skin = SK[1], Shirt = I.WhiteTee2, Pants = I.Sweats2, Hats = { I.Dreads2 } },
	Street6 = { Role = "Street", Skin = SK[5], Shirt = I.Hoodie3, Pants = I.Jeans2, Hats = { I.Beanie } },
	Street7 = { Role = "Street", Skin = SK[3], Shirt = I.Tank2, Pants = I.Jeans3, Hats = { I.Braids }, Height = 0.96 },
	Street8 = { Role = "Street", Skin = SK[7], Shirt = I.Sweater, Pants = I.Skirt, Hats = { I.AfroCurly }, Height = 0.95 },
	Street9 = { Role = "Street", Skin = SK[2], Shirt = I.Hoodie2, Pants = I.Cargo2, Hats = { I.Bucket }, Back = { I.Backpack } },
	Street10 = { Role = "Street", Skin = SK[4], Shirt = I.Polo, Pants = I.Shorts2, Hats = { I.Durag }, Neck = { I.Chain3 } },
	-- crew: corner boys in dark colours
	Crew1 = { Role = "Crew", Skin = SK[1], Shirt = I.Hoodie, Pants = I.Sweats3, Hats = { I.DuragGray }, Neck = { I.Chain }, Height = 1.04 },
	Crew2 = { Role = "Crew", Skin = SK[3], Shirt = I.Hoodie3, Pants = I.Jeans, Hats = { I.Dreads3 }, Neck = { I.Chain3 } },
	-- elders: the domino table, the porch
	Elder1 = { Role = "Elder", Skin = SK[2], Shirt = I.Polo2, Pants = I.Slacks, Hats = { I.GrayHair, I.Bucket2 } },
	Elder2 = { Role = "Elder", Skin = SK[4], Shirt = I.Flannel2, Pants = I.Slacks2, Hats = { I.GrayHair } },
	Elder3 = { Role = "Elder", Skin = SK[6], Shirt = I.Sweater2, Pants = I.Slacks, Hats = { I.Cap2 } },
	Elder4 = { Role = "Elder", Skin = SK[3], Shirt = I.Tank, Pants = I.Slacks2, Hats = { I.GrayHair } },
	-- church ladies (Kingdom of Faith)
	Church1 = { Role = "ChurchLady", Skin = SK[3], Shirt = I.Sweater, Pants = I.Skirt2, Hats = { I.ChurchHatWhite }, Height = 0.94 },
	Church2 = { Role = "ChurchLady", Skin = SK[5], Shirt = I.ChurchSuit, Pants = I.Skirt, Hats = { I.ChurchHatBlack }, Height = 0.95 },
	-- kids
	Kid1 = { Role = "Kid", Skin = SK[4], Shirt = I.Jersey, Pants = I.Shorts, Hats = { I.Afro }, Height = 0.72 },
	Kid2 = { Role = "Kid", Skin = SK[2], Shirt = I.WhiteTee, Pants = I.Shorts2, Hats = { I.Braids2 }, Back = { I.Backpack2 }, Height = 0.7 },
	-- hoopers
	Hooper1 = { Role = "Hooper", Skin = SK[1], Shirt = I.Jersey2, Pants = I.Shorts, Hats = { I.Durag }, Height = 1.05 },
	Hooper2 = { Role = "Hooper", Skin = SK[5], Shirt = I.Tank2, Pants = I.Shorts2, Hats = { I.AfroBrown } },
	-- workers / shopkeepers
	Worker1 = { Role = "Worker", Skin = SK[4], Shirt = I.Uniform, Pants = I.Cargo, Hats = { I.Cap3 } }, -- the mechanic
	Shop1 = { Role = "Shopkeeper", Skin = SK[7], Shirt = I.Polo, Pants = I.Slacks, Face = { I.ShortBlack2 } },
}

local DEFAULT_SHIRT = C(70, 74, 84)
local DEFAULT_PANTS = C(46, 50, 62)

local function list(ids: { number }?): string
	local out = {}
	for _, id in ids or {} do
		if id ~= 0 then
			table.insert(out, tostring(id))
		end
	end
	return table.concat(out, ",")
end

-- plain = colours only (the fallback when a catalog item won't load)
function Outfits.description(o: Outfit, plain: boolean?): HumanoidDescription
	local d = Instance.new("HumanoidDescription")
	d.HeadColor = o.Skin
	d.LeftArmColor = o.Skin
	d.RightArmColor = o.Skin
	d.TorsoColor = o.ShirtColor or DEFAULT_SHIRT
	d.LeftLegColor = o.PantsColor or DEFAULT_PANTS
	d.RightLegColor = o.PantsColor or DEFAULT_PANTS
	if not plain then
		d.Shirt = o.Shirt or 0
		d.Pants = o.Pants or 0
		d.HatAccessory = list(o.Hats)
		d.FaceAccessory = list(o.Face)
		d.NeckAccessory = list(o.Neck)
		d.BackAccessory = list(o.Back)
	end
	return d
end

function Outfits.byRole(role: string): { string }
	local out = {}
	for id, o in Outfits.List do
		if o.Role == role then
			table.insert(out, id)
		end
	end
	table.sort(out)
	return out
end

-- every outfit id used by these roles, sorted (stable build order)
function Outfits.ambientIds(roles: { string }): { string }
	local seen, out = {}, {}
	for _, role in roles do
		for _, id in Outfits.byRole(role) do
			if not seen[id] then
				seen[id] = true
				table.insert(out, id)
			end
		end
	end
	return out
end

return Outfits
