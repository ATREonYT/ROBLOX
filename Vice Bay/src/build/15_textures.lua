-- 15 textures: make every Vice Bay MaterialVariant actually render.
-- The original uploads (owned by the atredev account) are blocked in the group-owned experience
-- ("The experience doesn't have access permission to use asset id ..."), and a blocked variant renders
-- as flat dark grey. Until access is shared, each variant borrows the maps of a PUBLIC Creator Store
-- material (CC0 AmbientCG pack, Roblox Modern City pack, PBR packs) that loads for everyone.
-- The original ids are kept as attributes, so R.run("15_textures", "restore") puts them back.
return function(L, mode)
	local MS = game:GetService("MaterialService")
	local root = MS:FindFirstChild("Realistic")
	if not root then return "no Realistic folder" end
	-- public sources: color, normal, roughness, metalness, studsPerTile
	local SRC = {
		Asphalt = { "9533203050", "9533202378", "9533202005", "9533202772", 12 }, -- AmbientCG slate (fine dark grain)
		SidewalkClean = { "11163338992", "11163318474", "11163318234", "", 22.5 }, -- Modern City sidewalk slabs
		ConcreteDirty = { "9400228712", "9400231053", "9400231980", "", 20 }, -- stained concrete
		BoardFormed = { "9942998923", "9942998998", "9942998661", "", 10 },
		Ribbed = { "9942398333", "9942398530", "9942397909", "", 10 },
		Precast = { "9932977788", "9932948078", "9932518345", "", 20 },
		Block = { "9992640403", "9992640582", "9992640243", "", 10 },
		Stucco = { "5430750348", "5430314970", "5430311381", "", 10 }, -- rough stucco
		Plaster = { "10960894634", "10960879839", "10960879369", "", 10 }, -- smooth plaster
		Brick = { "9533015864", "9533015177", "9533014934", "9533016127", 10 },
		PaintedBrick = { "11306286615", "10967950030", "10967950866", "", 5 },
		StoneBlock = { "10872901256", "10853928851", "", "", 10 },
		Marble = { "11000110064", "11000113980", "11000112185", "", 10 },
		Tile = { "10998918995", "10998920777", "10998918338", "", 8 },
		Rust = { "9533229452", "9533228628", "9533227819", "9533230317", 4 },
		Metal = { "9533088414", "9533087638", "9533087368", "9533088987", 10 },
		Diamond = { "9533054652", "9533053834", "9533053350", "9533054362", 10 },
		Planks = { "9529159196", "9529158475", "9529157747", "", 10 },
		RoofTiles = { "9407830442", "9407832790", "9407839130", "", 4 },
		Mud = { "5430802240", "5430805661", "5430814080", "", 10 },
		Gravel = { "9533002162", "9533001232", "9533000876", "9533001834", 14.5 },
		Sand = { "9533317359", "9533316353", "9533316047", "", 10 },
		Rock = { "10991780334", "10991780653", "10991780698", "", 6 },
		Bark = { "6351534437", "6351536891", "6351539388", "", 10 },
		Pavers = { "10999736192", "10999787880", "", "", 10 },
		Concrete = { "6929796707", "6929798342", "6929799140", "", 10 },
	}
	local MAP = {
		Asphalt = { "HoodAsphaltCracked", "HoodAsphaltFaded", "HoodRoadPotholes", "AsphaltWorn", "DowntownAsphaltClean", "AsphaltGranular", "RoadDamagedB", "AsphaltDarkFresh", "AsphaltPlain", "ParkingLotAsphalt", "AsphaltTarPatch", "AsphaltAerialWide", "RoofFlatBitumen" },
		SidewalkClean = { "SidewalkConcrete", "DowntownSidewalkTiles", "DowntownPavers", "SidewalkSlabs", "ConcreteDriveway" },
		ConcreteDirty = { "HoodSidewalkCracked", "SidewalkWornStained", "SidewalkCrackedB", "ConcreteStained", "ParkingLotStained", "LotConcreteWorn", "HoodPaintedConcrete", "HoodConcreteDirty", "ChannelConcreteDirty", "ChannelConcreteDamaged", "ChannelWall", "ConcreteLayers" },
		Block = { "HoodCinderBlock", "CinderBlockB" },
		Precast = { "DowntownPrecastPanel", "OverpassPrecast", "BridgeConcretePanels" },
		Concrete = { "DowntownConcreteFacade", "ConcretePlain", "OverpassConcrete" },
		Ribbed = { "DowntownRibbedConcrete" },
		BoardFormed = { "BoardFormedConcrete" },
		Stucco = { "HoodStuccoWorn", "HoodStuccoCracked", "HoodPlasterChipped", "HoodPlasterExposedBrick", "StuccoBlueWeathered", "StuccoPinkWeathered", "StuccoYellow", "PlasterWorn", "PlasterCrackedB", "PlasterMossyHumid", "StuccoBeige" },
		Plaster = { "StuccoSuburb", "DowntownRender", "StuccoWhite", "StuccoGreyFine" },
		PaintedBrick = { "HoodPaintedBrick", "HoodPaintedBrickYellow" },
		Brick = { "HoodBrickDamaged", "DowntownBrickRed", "DowntownBrickOld", "HoodBrickDark", "BrickRedClassic", "BrickBrownOld", "BrickMixed", "BrickBroken", "DowntownBrickPavers" },
		StoneBlock = { "ConcreteBrick", "DowntownStoneBlocks" },
		Marble = { "LobbyMarble" },
		Tile = { "PlazaTiles" },
		Rust = { "ShutterRusty", "CorrugatedWorn", "CorrugatedRusty", "MetalPaintedRusty", "ShutterRustedB", "DumpsterGreenRust", "RustyGrate", "RustySheet", "RustCoarse" },
		Metal = { "ShutterPainted", "ShippingContainer", "IndustrialWall", "RoofBoxProfile", "ShutterWorn", "CorrugatedPlain", "CorrugatedB", "MetalBluePlate" },
		Diamond = { "MetalPlate" },
		Planks = { "WoodPaintedDistressed", "WoodPlanksOld", "SidingBlue", "SidingBlack", "FenceWoodRaw", "FenceGreenRough" },
		RoofTiles = { "RoofShinglesGrey", "RoofClayTiles", "RoofClayMission", "RoofCeramic", "RoofSlatesDark", "RoofRedSlate" },
		Mud = { "DirtLot", "ParkDirt", "DryGround", "MudDry", "MudLeaves", "DryMudField", "LeafLitter", "DryLeaves" },
		Gravel = { "GravelLot", "GravelRoad", "GravelLeaves", "CoralGravel" },
		Sand = { "BeachSand", "BeachSandB" },
		Rock = { "RockGrey", "RockMossy" },
		Bark = { "PalmBark", "PalmBarkB" },
		Pavers = { "HerringbonePavers", "InterlockPavers", "BrickPavementB" },
	}
	local function rid(s) return (s and s ~= "") and ("rbxassetid://" .. s) or "" end
	local done, missing = 0, {}
	for key, names in pairs(MAP) do
		local s = SRC[key]
		for _, n in ipairs(names) do
			local v = root:FindFirstChild(n)
			if not v then
				table.insert(missing, n)
			else
				if v:GetAttribute("OrigColorMap") == nil then
					v:SetAttribute("OrigColorMap", v.ColorMap)
					v:SetAttribute("OrigNormalMap", v.NormalMap)
					v:SetAttribute("OrigRoughnessMap", v.RoughnessMap)
					v:SetAttribute("OrigMetalnessMap", v.MetalnessMap)
					v:SetAttribute("OrigStuds", v.StudsPerTile)
				end
				if mode == "restore" then
					v.ColorMap = v:GetAttribute("OrigColorMap")
					v.NormalMap = v:GetAttribute("OrigNormalMap")
					v.RoughnessMap = v:GetAttribute("OrigRoughnessMap")
					v.MetalnessMap = v:GetAttribute("OrigMetalnessMap")
					v.StudsPerTile = v:GetAttribute("OrigStuds")
				else
					v.ColorMap = rid(s[1])
					v.NormalMap = rid(s[2])
					v.RoughnessMap = rid(s[3])
					v.MetalnessMap = rid(s[4])
					v.StudsPerTile = s[5]
				end
				done += 1
			end
		end
	end
	return string.format("%s %d variants (missing: %s)", mode == "restore" and "restored" or "public maps on", done, table.concat(missing, ","))
end
