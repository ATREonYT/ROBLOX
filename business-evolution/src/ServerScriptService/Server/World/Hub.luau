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
local Palette = require(ReplicatedStorage.Shared.Config.Palette)
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
	-- 90x90 (ART 4.1). Everything below is packed inside it: the whole point
	-- of the shrink is that bare ground is the enemy.
	Kit.ground(parent, base, 0, 0, width, depth, ground)

	Kit.cliffWall(parent, base, 0, -depth / 2 - 10, width + 40, 20, 30, cliff, cliffTop)
	Kit.cliffWall(parent, base, 0, depth / 2 + 10, width + 40, 20, 30, cliff, cliffTop)
	Kit.cliffWall(parent, base, -width / 2 - 10, 0, 20, depth + 20, 30, cliff, cliffTop)
	-- East wall opens for the road out to Stage 1.
	for _, side in { -1, 1 } do
		Kit.cliffWall(parent, base, width / 2 + 10, side * (depth / 4 + 12), 20, depth / 2 - 22, 30, cliff, cliffTop)
	end
	Kit.fence(parent, base, 0, -depth / 2 - 1, width, 90, ground)
	Kit.fence(parent, base, 0, depth / 2 + 1, width, 90, ground)
	Kit.fence(parent, base, -width / 2 - 1, 0, depth, 0, ground)

	-- ── THE LANDMARK ───────────────────────────────────────────────────────
	-- Exactly one, 70 studs, north of centre. It is the thing you orient by
	-- from anywhere in the world, and the only object in this tier.
	Kit.landmark(parent, base, 0, -34, 70, prop, accent, Color3.fromRGB(150, 214, 240), "BUSINESS EVOLUTION")

	-- ── Central plaza + spawn ──────────────────────────────────────────────
	-- Spawn dead centre: with a 90x90 zone that is the only position from which
	-- every interactive object lands inside the 40-stud reach ART 4.1 asks for.
	Kit.plaza(parent, base, 0, 2, 52, 44, plazaCol, accent)
	local spawnPad = Kit.pad(parent, base, 0, 2, 12, accent, "HQ PLAZA", "Click anywhere for +1")
	spawnPad.Name = "SpawnPad"
	local spawnCf = base * CFrame.new(0, 4, 2) * CFrame.Angles(0, math.rad(-90), 0)

	-- The road out, and the arrows that sell it.
	Kit.plaza(parent, base, 34, 0, 28, 24, plazaCol, accent)
	Kit.arrowTrail(parent, base, 10, 2, width / 2 + 4, 0, 8)

	-- ── Training bags (south) ──────────────────────────────────────────────
	-- One row of eight along the south edge, deliberately NOT evenly spaced:
	-- step, rotation and scale all wobble per index (ART 4.3).
	local bagManifest: { { BagId: string, Pad: BasePart } } = {}
	Kit.label(parent, base * CFrame.new(0, 16, 38), "TRAINING YARD", accent, 40, 22)
	for index, bag in TrainingBags.List do
		local color = Kit.rgb(bag.Color)
		local valueText = ("x%s POWER"):format(Format.abbreviate(bag.BaseMultiplier))
		local subtitle = if bag.MinRestructures > 0
			then ("LOCKED - %d RESTRUCTURES"):format(bag.MinRestructures)
			else bag.Name
		-- Two rows of four. Rows sit at different depths and the step wobbles,
		-- so the yard reads as a cluster rather than a grid line.
		local row = if index <= 4 then 0 else 1
		local slot = (index - 1) % 4
		local bagX = -19.5 + slot * Kit.varySpacing(13, index, 0.14)
		local z = if row == 0 then 13 else 26
		local jittered = Kit.jitter(base * CFrame.new(bagX, 0, z), index, 1.1, 13)
		local _model, bagPad = Kit.punchingBag(
			parent,
			jittered,
			0,
			0,
			Palette.vary(color, index),
			subtitle,
			valueText
		)
		local pad: BasePart = bagPad
		table.insert(bagManifest, { BagId = bag.Id, Pad = pad })
	end

	-- ── Wardrobe (west), two rows on a raised deck ─────────────────────────
	local skinManifest: { { SkinId: string, Pad: BasePart } } = {}
	local deckX = -28
	Kit.plaza(parent, base, deckX - 2, 0, 22, 52, Kit.lighten(plazaCol, 0.04), accent)
	local deck = Kit.part(parent, base * CFrame.new(deckX - 5, 2, 0), Vector3.new(11, 4, 52), Kit.lighten(plazaCol, 0.08))
	deck.Name = "WardrobeDeck"
	Kit.stairs(parent, base, deckX - 5, 30, 3, 11, 1.4, 2.6, Kit.lighten(plazaCol, 0.02), 180)
	Kit.label(parent, base * CFrame.new(deckX, 15, -32), "THE WARDROBE", accent, 38, 20)

	for index, skin in SkinsConfig.List do
		local row = if index <= 5 then 0 else 1
		local slot = (index - 1) % 5
		local px = deckX - 5 + row * 9
		local pz = -20 + slot * Kit.varySpacing(10, index, 0.12)
		local color = Kit.rgb(skin.Accent)
		local yOffset = if row == 0 then 4 else 0
		local pad: BasePart = Kit.part(
			parent,
			base * CFrame.new(px, yOffset + 0.5, pz),
			Vector3.new(8, 0.8, 8),
			color,
			Enum.Material.Neon
		)
		pad.Name = "SkinPad_" .. skin.Id
		pad.CanCollide = false
		Kit.decor(parent, base * CFrame.new(px, yOffset + 0.2, pz), Vector3.new(9.6, 0.5, 9.6), Kit.darken(color, 0.55), Enum.Material.Metal)
		Kit.dummy(
			parent,
			Kit.jitter(base * CFrame.new(0, yOffset, 0), index + 40, 0.5, 12),
			px,
			pz,
			-90,
			Kit.rgb(skin.Shirt),
			Kit.rgb(skin.Trousers),
			color,
			skin.Glow
		)
		local priceText = if skin.Cost == 0 then "OWNED" else ("%s WINS"):format(Format.abbreviate(skin.Cost))
		Kit.label(
			parent,
			base * CFrame.new(px, yOffset + 12, pz),
			priceText,
			Kit.lighten(color, 0.5),
			26,
			9,
			("+%s/click"):format(Format.abbreviate(skin.PowerPerClick))
		)
		-- Rarer skins get a light on the pad, the way the reference marks value.
		if skin.Cost >= 3000 then
			local light = Instance.new("PointLight")
			light.Color = color
			light.Brightness = 1.6
			light.Range = 14
			light.Shadows = false
			light.Parent = pad
		end
		table.insert(skinManifest, { SkinId = skin.Id, Pad = pad })
	end

	-- ── Briefcase stands (north-east cluster) ──────────────────────────────
	local eggManifest: { { EggId: string, Pad: BasePart } } = {}
	Kit.plaza(parent, base, 22, -20, 32, 26, Kit.lighten(plazaCol, 0.02), accent)
	Kit.label(parent, base * CFrame.new(22, 14, -33), "BRIEFCASES", accent, 36, 18)
	for index, egg in Eggs.List do
		local ex = 14 + ((index - 1) % 2) * Kit.varySpacing(13, index, 0.14)
		local ez = -25 + math.floor((index - 1) / 2) * 12
		local color = Kit.rgb(egg.Color)
		local pad: BasePart = Kit.pad(parent, base, ex, ez, 11, color, egg.Name, ("%s WINS"):format(Format.abbreviate(egg.Cost)))
		pad.Name = "EggPad_" .. egg.Id
		Kit.briefcase(parent, Kit.jitter(base, index + 70, 0.4, 14), ex, ez, color)
		table.insert(eggManifest, { EggId = egg.Id, Pad = pad })
	end

	-- ── Leaderboard pillars (south-west) ───────────────────────────────────
	local pillarTitles = { "TOP POWER", "TOP RESTRUCTURES", "TOP WINS" }
	for index, title in pillarTitles do
		Kit.pillar(parent, base, -40 + (index - 1) * Kit.varySpacing(9, index + 90, 0.1), 34 + (index % 2) * 3, 20 + index, title, Kit.darken(prop, 0.1), accent)
	end

	-- ── Chest, rebirth desk, gear stand (near spawn, east side) ────────────
	local _chestModel, chestPad = Kit.chest(parent, base, 15, 14, accent)

	local rebirthPad = Kit.pad(parent, base, 26, 26, 11, Palette.Stop, "RESTRUCTURE", "Reset for permanent power")
	rebirthPad.Name = "RebirthPad"
	Kit.part(parent, base * CFrame.new(26, 2.2, 32), Vector3.new(10, 4.4, 4.5), Kit.darken(prop, 0.25), Enum.Material.WoodPlanks)
	Kit.decor(parent, base * CFrame.new(26, 4.7, 32), Vector3.new(11, 0.6, 5.4), accent, Enum.Material.Metal)

	local gearPad = Kit.pad(parent, base, -10, 14, 11, Palette.Productivity, "GEAR SHOP", "Keyboards - Chairs - Coffee")
	gearPad.Name = "GearPad"
	Kit.part(parent, base * CFrame.new(-10, 2.2, 8), Vector3.new(10, 4.4, 4.5), Kit.darken(prop, 0.25), Enum.Material.WoodPlanks)
	Kit.decor(parent, base * CFrame.new(-10, 4.7, 8), Vector3.new(11, 0.6, 5.4), accent, Enum.Material.Metal)

	-- ── Set dressing, packed with rhythm rather than scattered evenly ──────
	local leaf = Color3.fromRGB(96, 176, 82)
	local trunk = Color3.fromRGB(122, 84, 56)
	-- A dense corner cluster, then breathing room, then a looser pair.
	for i, spot in { { -40, -40 }, { -35, -34 }, { -42, -28 }, { 40, 34 }, { 36, 40 }, { 43, 20 } } do
		Kit.tree(parent, base, spot[1], spot[2], (1 + (i % 3) * 0.18) * Kit.varyScale(i + 120), trunk, Palette.vary(leaf, i, 0.06))
	end
	-- Planters and bollards filling the bare edges of the plaza.
	for i = 0, 5 do
		local px = -20 + i * Kit.varySpacing(9, i + 140, 0.2)
		Kit.decor(parent, Kit.jitter(base, i + 150, 0.6, 18) * CFrame.new(px, 1.4, 17), Vector3.new(4.4, 2.8, 4.4), Kit.darken(plazaCol, 0.2), Enum.Material.Concrete)
		Kit.decor(parent, base * CFrame.new(px, 3.2, 17), Vector3.new(5, 1.4, 5), Palette.vary(leaf, i + 3, 0.05), Enum.Material.LeafyGrass)
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
