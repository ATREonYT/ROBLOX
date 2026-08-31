--!strict
-- HQ PLAZA — the hub. Everything a player needs in their first ten seconds is
-- visible from the spawn pad: the training bags to their left, the skin shop
-- ahead on its raised deck, the briefcase stands to the right, and an arrow
-- trail pointing east to Stage 1.
--
-- Layout (looking down, +X is east toward the stages):
--
--        ╔═══════════ cliffs ═══════════╗
--        ║   [TOP 100 pillars]          ║
--        ║   ┌── SKIN SHOP deck ──┐     ║
--        ║   TRAINING   [SPAWN]   BRIEFCASES  →→→ to Stage 1
--        ║   BAGS x8    chest              ║
--        ║              rebirth desk       ║
--        ╚══════════════════════════════╝

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Kit = require(script.Parent.OutdoorKit)
local Stages = require(ReplicatedStorage.Shared.Config.Stages)
local Surfaces = require(ReplicatedStorage.Shared.Config.Surfaces)
local TrainingBags = require(ReplicatedStorage.Shared.Config.TrainingBags)
local SkinsConfig = require(ReplicatedStorage.Shared.Config.Skins)
local Eggs = require(ReplicatedStorage.Shared.Config.Eggs)
local Format = require(ReplicatedStorage.Shared.Util.Format)

export type HubManifest = {
	Spawn: CFrame,
	TrainingBags: { { BagId: string, Pad: BasePart } },
	SkinPodiums: { { SkinId: string, Pad: BasePart } },
	EggPads: { { EggId: string, Pad: BasePart } },
	RebirthPad: BasePart,
	GearPad: BasePart,
	ChestPad: BasePart,
}

local Hub = {}

function Hub.build(parent: Folder, origin: Vector3): HubManifest
	local stage = Stages.get("Hub")
	assert(stage, "Hub stage config is missing")
	local theme = stage.Theme
	local base = CFrame.new(origin)
	Kit.setSurfaces(Surfaces.forStage("Hub"))

	local ground = Kit.rgb(theme.Ground)
	local cliff = Kit.rgb(theme.Cliff)
	local cliffTop = Kit.rgb(theme.CliffTop)
	local plazaCol = Kit.rgb(theme.Plaza)
	local accent = Kit.rgb(theme.Accent)
	local prop = Kit.rgb(theme.Prop)

	local width, depth = stage.Size[1], stage.Size[2]

	-- ── Terrain shell ──────────────────────────────────────────────────────
	Kit.ground(parent, base, 0, 0, width, depth, ground)

	-- Cliffs on three sides; the east side is left open for the stage road.
	Kit.cliffWall(parent, base, 0, -depth / 2 - 12, width + 60, 24, 34, cliff, cliffTop)
	Kit.cliffWall(parent, base, 0, depth / 2 + 12, width + 60, 24, 34, cliff, cliffTop)
	Kit.cliffWall(parent, base, -width / 2 - 12, 0, 24, depth + 24, 34, cliff, cliffTop)
	-- East wall in two pieces, leaving a 70-stud road gap in the middle.
	for _, side in { -1, 1 } do
		Kit.cliffWall(parent, base, width / 2 + 12, side * (depth / 4 + 26), 24, depth / 2 - 34, 34, cliff, cliffTop)
	end
	-- Invisible walls so nobody walks off the edge of the world.
	Kit.fence(parent, base, 0, -depth / 2 - 2, width, 90, ground)
	Kit.fence(parent, base, 0, depth / 2 + 2, width, 90, ground)
	Kit.fence(parent, base, -width / 2 - 2, 0, depth, 0, ground)

	-- ── Central plaza + spawn ──────────────────────────────────────────────
	Kit.plaza(parent, base, 0, 0, 130, 110, plazaCol, accent)
	local spawnPad = Kit.pad(parent, base, 0, 20, 16, accent, "HQ PLAZA", "Click anywhere for +1")
	spawnPad.Name = "SpawnPad"
	-- Face east: the stage road, the arch and the arrow trail are all that way.
	local spawnCf = base * CFrame.new(0, 4, 20) * CFrame.Angles(0, math.rad(-90), 0)

	-- The road out, and the arrows that sell it.
	Kit.plaza(parent, base, width / 2 - 30, 0, 120, 56, plazaCol, accent)
	Kit.arrowTrail(parent, base, 20, 20, width / 2 + 20, 0, 16)

	-- ── Training bags (west) ───────────────────────────────────────────────
	-- Two rows of four. Locked bags still show their multiplier: the point is
	-- to see what the next rebirth buys you.
	local bagManifest: { { BagId: string, Pad: BasePart } } = {}
	Kit.plaza(parent, base, -108, 0, 96, 150, Kit.darken(plazaCol, 0.06), accent)
	Kit.label(parent, base * CFrame.new(-108, 26, -80), "TRAINING YARD", accent, 52, 30)
	for index, bag in TrainingBags.List do
		local row = if index <= 4 then 0 else 1
		local slot = (index - 1) % 4
		local x = -140 + row * 56
		local z = -54 + slot * 36
		local color = Kit.rgb(bag.Color)
		local valueText = ("x%s POWER"):format(Format.abbreviate(bag.BaseMultiplier))
		local subtitle = if bag.MinRestructures > 0
			then ("🔒 %d Restructures"):format(bag.MinRestructures)
			else bag.Name
		local _model, bagPad = Kit.punchingBag(parent, base, x, z, color, subtitle, valueText)
		local pad: BasePart = bagPad
		table.insert(bagManifest, { BagId = bag.Id, Pad = pad })
	end

	-- ── Skin shop (north, raised deck with stairs) ─────────────────────────
	local skinManifest: { { SkinId: string, Pad: BasePart } } = {}
	local shopZ = -96
	Kit.plaza(parent, base, 0, shopZ, 190, 60, Kit.lighten(plazaCol, 0.04), accent)
	-- Raised tier the mannequins stand on, reached by stairs from the plaza.
	local deck = Kit.part(parent, base * CFrame.new(0, 3, shopZ - 14), Vector3.new(190, 6, 34), Kit.lighten(plazaCol, 0.08))
	deck.Name = "SkinShopDeck"
	Kit.stairs(parent, base, -40, shopZ + 12, 4, 26, 1.5, 3, Kit.lighten(plazaCol, 0.02))
	Kit.stairs(parent, base, 40, shopZ + 12, 4, 26, 1.5, 3, Kit.lighten(plazaCol, 0.02))
	Kit.label(parent, base * CFrame.new(0, 30, shopZ - 26), "THE WARDROBE", accent, 60, 34)

	for index, skin in SkinsConfig.List do
		local x = -85 + (index - 1) * 19
		local z = shopZ - 14
		local color = Kit.rgb(skin.Accent)
		-- Podium sits on the raised deck, so everything is offset up by 6.
		local pad: BasePart = Kit.part(parent, base * CFrame.new(x, 6.4, z), Vector3.new(11, 0.8, 11), color, Enum.Material.Neon)
		pad.Name = "SkinPad_" .. skin.Id
		pad.CanCollide = false
		Kit.dummy(
			parent,
			base * CFrame.new(0, 6, 0),
			x,
			z,
			180,
			Kit.rgb(skin.Shirt),
			Kit.rgb(skin.Trousers),
			color,
			skin.Glow
		)
		local priceText = if skin.Cost == 0 then "OWNED" else ("🏆 %s"):format(Format.abbreviate(skin.Cost))
		Kit.label(parent, base * CFrame.new(x, 21, z), priceText, Kit.lighten(color, 0.5), 34, 12)
		Kit.label(parent, base * CFrame.new(x, 18.6, z), ("+%s/click"):format(Format.abbreviate(skin.PowerPerClick)), Color3.fromRGB(255, 255, 255), 24, 12)
		table.insert(skinManifest, { SkinId = skin.Id, Pad = pad })
	end

	-- ── Briefcase stands (east of spawn) ───────────────────────────────────
	local eggManifest: { { EggId: string, Pad: BasePart } } = {}
	Kit.plaza(parent, base, 96, 66, 120, 60, Kit.lighten(plazaCol, 0.02), accent)
	Kit.label(parent, base * CFrame.new(96, 24, 40), "BRIEFCASES", accent, 52, 28)
	for index, egg in Eggs.List do
		local x = 48 + (index - 1) * 32
		local z = 70
		local color = Kit.rgb(egg.Color)
		local pad: BasePart = Kit.pad(parent, base, x, z, 14, color, egg.Name, ("🏆 %s"):format(Format.abbreviate(egg.Cost)))
		pad.Name = "EggPad_" .. egg.Id
		Kit.briefcase(parent, base, x, z, color)
		table.insert(eggManifest, { EggId = egg.Id, Pad = pad })
	end

	-- ── Leaderboard pillars (north-east) ───────────────────────────────────
	local pillarTitles = { "TOP 100 POWER", "TOP 100 RESTRUCTURES", "TOP 100 WINS" }
	for index, title in pillarTitles do
		Kit.pillar(parent, base, 60 + (index - 1) * 26, -86, 26, title, Kit.darken(prop, 0.1), accent)
	end

	-- ── Free power chest, rebirth desk, gear stand ─────────────────────────
	local _chestModel, chestPad = Kit.chest(parent, base, -46, 44, accent)

	local rebirthPad = Kit.pad(parent, base, 46, 6, 14, Kit.rgb({ 232, 84, 96 }), "RESTRUCTURE", "Reset for permanent power")
	rebirthPad.Name = "RebirthPad"
	-- A desk behind the pad so it reads as an HR station, not a floating tile.
	Kit.part(parent, base * CFrame.new(46, 2.4, -4), Vector3.new(12, 4.8, 5), Kit.darken(prop, 0.25))
	Kit.decor(parent, base * CFrame.new(46, 5.1, -4), Vector3.new(13, 0.6, 6), accent)

	local gearPad = Kit.pad(parent, base, -46, 6, 14, Kit.rgb({ 96, 176, 255 }), "GEAR SHOP", "Keyboards · Chairs · Coffee")
	gearPad.Name = "GearPad"
	Kit.part(parent, base * CFrame.new(-46, 2.4, -4), Vector3.new(12, 4.8, 5), Kit.darken(prop, 0.25))
	Kit.decor(parent, base * CFrame.new(-46, 5.1, -4), Vector3.new(13, 0.6, 6), accent)

	-- ── Dressing: trees, planters, a few low offices on the skyline ────────
	local leaf = Color3.fromRGB(96, 176, 82)
	local trunk = Color3.fromRGB(122, 84, 56)
	for _, spot in
		{
			{ -150, 118 }, { -104, 126 }, { -60, 130 }, { 8, 128 }, { 62, 124 }, { 132, 116 },
			{ -152, -126 }, { -96, -132 }, { 140, -120 }, { 156, 44 }, { 150, -52 },
		}
	do
		Kit.tree(parent, base, spot[1], spot[2], 1 + ((spot[1] + spot[2]) % 3) * 0.12, trunk, leaf)
	end
	-- Low-rise offices peeking over the cliffs, so the hub feels like a city.
	for _, b in
		{
			{ -120, -150, 34, 30, 22 }, { -40, -158, 28, 44, 20 }, { 46, -152, 30, 26, 24 },
			{ 130, -148, 26, 38, 20 }, { -140, 152, 30, 34, 22 }, { 30, 158, 34, 28, 20 },
		}
	do
		Kit.building(parent, base, b[1], b[2], b[3], b[4], b[5], Kit.lighten(prop, 0.1), accent, true)
	end

	return {
		Spawn = spawnCf,
		TrainingBags = bagManifest,
		SkinPodiums = skinManifest,
		EggPads = eggManifest,
		RebirthPad = rebirthPad,
		GearPad = gearPad,
		ChestPad = chestPad,
	}
end

return Hub
