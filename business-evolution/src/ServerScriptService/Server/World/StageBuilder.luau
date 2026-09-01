--!strict
-- One stage: a canyon you walk east through, fight your way across, and cash
-- out at the far end. The skeleton is shared so every stage plays the same;
-- the LOOK is delegated to StageDecor, which gives each one its own location.
--
-- Plan (+X east, player enters from the west):
--
--   [ARCH: STAGE N          ]        [enemies]        [PADS] [BARRIER] →
--    Recommended Power: X                            10x  1x   locked
--
-- The barrier is solid until the stage is cleared; StageService unlocks it.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Kit = require(script.Parent.OutdoorKit)
local StageDecor = require(script.Parent.StageDecor)
local Stages = require(ReplicatedStorage.Shared.Config.Stages)
local Surfaces = require(ReplicatedStorage.Shared.Config.Surfaces)
local Format = require(ReplicatedStorage.Shared.Util.Format)

export type StageManifest = {
	Number: number,
	Id: string,
	EnemySpots: { CFrame },
	BigPad: BasePart,
	ReturnPad: BasePart,
	Barrier: BasePart,
	EntryCf: CFrame,
}

local StageBuilder = {}

function StageBuilder.build(parent: Folder, stage: Stages.Stage): StageManifest
	local theme = stage.Theme
	local base = CFrame.new(Vector3.new(stage.Origin[1], stage.Origin[2], stage.Origin[3]))
	Kit.setSurfaces(Surfaces.forStage(stage.Id))

	local ground = Kit.rgb(theme.Ground)
	local cliff = Kit.rgb(theme.Cliff)
	local cliffTop = Kit.rgb(theme.CliffTop)
	local plazaCol = Kit.rgb(theme.Plaza)
	local accent = Kit.rgb(theme.Accent)

	local width, depth = stage.Size[1], stage.Size[2]
	local halfW, halfD = width / 2, depth / 2

	-- ── Terrain shell ──────────────────────────────────────────────────────
	Kit.ground(parent, base, 0, 0, width, depth, ground)

	-- North and south canyon walls run the full length.
	Kit.cliffWall(parent, base, 0, -halfD - 12, width + 40, 24, 40, cliff, cliffTop)
	Kit.cliffWall(parent, base, 0, halfD + 12, width + 40, 24, 40, cliff, cliffTop)
	Kit.fence(parent, base, 0, -halfD - 2, width, 90, ground)
	Kit.fence(parent, base, 0, halfD + 2, width, 90, ground)

	-- East and west walls, each with a 70-stud road gap in the middle.
	for _, side in { -1, 1 } do
		Kit.cliffWall(parent, base, -halfW - 12, side * (depth / 4 + 20), 24, halfD - 26, 40, cliff, cliffTop)
		Kit.cliffWall(parent, base, halfW + 12, side * (depth / 4 + 20), 24, halfD - 26, 40, cliff, cliffTop)
	end

	-- The road that carries you through, with the arrow trail on it.
	Kit.plaza(parent, base, 0, 0, width - 20, 40, plazaCol, accent)
	Kit.arrowTrail(parent, base, -halfW + 24, 0, halfW - 34, 0, 18)

	-- ── Entry arch ─────────────────────────────────────────────────────────
	local archX = -halfW + 14
	Kit.stageArch(
		parent,
		base,
		archX,
		("STAGE %d"):format(stage.Number),
		("Recommended Power: %s"):format(Format.abbreviate(stage.RecommendedPower)),
		accent,
		Kit.darken(cliff, 0.1)
	)
	-- Where a player lands when the game places them at this stage.
	local entryCf = base * CFrame.new(archX + 16, 4, 0) * CFrame.Angles(0, math.rad(-90), 0)

	-- Name of the place, on the north wall, so the location has an identity.
	Kit.label(parent, base * CFrame.new(-halfW * 0.25, 34, -halfD - 4), stage.DisplayName:upper(), accent, 56, 40)
	Kit.label(parent, base * CFrame.new(-halfW * 0.25, 29, -halfD - 4), stage.Blurb, Color3.fromRGB(255, 255, 255), 26, 40)

	-- ── Enemy positions ────────────────────────────────────────────────────
	-- Spread across the middle third in two ranks, facing back down the road
	-- toward the player's approach.
	local enemySpots: { CFrame } = {}
	local arenaStart, arenaEnd = -width * 0.16, width * 0.24
	for i = 1, stage.EnemyCount do
		local t = if stage.EnemyCount == 1 then 0.5 else (i - 1) / (stage.EnemyCount - 1)
		local x = arenaStart + (arenaEnd - arenaStart) * t
		-- Alternate sides of the road so the fight fills the arena.
		local z = if i % 2 == 0 then 16 + (i % 3) * 7 else -16 - (i % 3) * 7
		table.insert(enemySpots, base * CFrame.new(x, 0, z) * CFrame.Angles(0, math.rad(-90), 0))
	end

	-- ── Cash-out pads + barrier (east end) ─────────────────────────────────
	local padX = halfW - 44
	local bigPad = Kit.pad(
		parent,
		base,
		padX,
		-16,
		18,
		Color3.fromRGB(236, 64, 200),
		("%d WINS"):format(stage.WinsReward * Stages.BigPadMultiplier),
		("%dx WINS"):format(Stages.BigPadMultiplier)
	)
	bigPad.Name = "BigWinPad"

	local returnPad = Kit.pad(
		parent,
		base,
		padX,
		16,
		18,
		Color3.fromRGB(252, 216, 64),
		("%d WINS"):format(stage.WinsReward),
		"RETURN TO HQ"
	)
	returnPad.Name = "ReturnPad"

	local _barrierModel, barrier = Kit.barrier(
		parent,
		base,
		halfW - 8,
		70,
		30,
		Color3.fromRGB(240, 70, 70),
		("DEFEAT %d %sS TO PASS"):format(stage.EnemyCount, stage.EnemyName:upper())
	)

	-- ── The stage's own look ───────────────────────────────────────────────
	StageDecor.decorate(stage.Id, parent, base, stage, Kit)

	-- ── Shared ambient detail ──────────────────────────────────────────────
	-- Every stage gets ground clutter, kerb stones and cliff-top greenery on
	-- top of its own dressing, so no location ever reads as an empty box.
	-- Placement is deterministic (index-derived, no RNG) so all servers match.
	local detail = Kit.lighten(ground, 0.08)
	local shade = Kit.darken(ground, 0.12)
	for i = 1, 46 do
		local t = (i * 37 % 100) / 100
		local x = -halfW + 18 + t * (width - 36)
		local side = if i % 2 == 0 then 1 else -1
		local z = side * (26 + (i * 13 % 60))
		local scale = 0.6 + (i % 4) * 0.35
		-- A tuft/rubble cluster: three small blocks at slightly different sizes.
		Kit.decor(parent, base * CFrame.new(x, 0.5 * scale, z), Vector3.new(2.4 * scale, 1 * scale, 2.4 * scale), if i % 3 == 0 then shade else detail)
		Kit.decor(parent, base * CFrame.new(x + 1.6, 0.35 * scale, z + 1.2), Vector3.new(1.4 * scale, 0.7 * scale, 1.4 * scale), detail)
		Kit.decor(parent, base * CFrame.new(x - 1.4, 0.3 * scale, z - 1.1), Vector3.new(1.2 * scale, 0.6 * scale, 1.2 * scale), shade)
	end
	-- Kerb stones edging the road the whole way through.
	for i = 0, math.floor(width / 14) do
		local x = -halfW + 12 + i * 14
		for _, side in { -1, 1 } do
			Kit.decor(parent, base * CFrame.new(x, 1.1, side * 21), Vector3.new(12, 1.4, 1.6), Kit.lighten(plazaCol, 0.1))
		end
	end
	-- Greenery and lamps on the cliff tops, so the skyline is not a flat edge.
	local leaf = Kit.rgb(theme.CliffTop)
	local trunk = Kit.darken(leaf, 0.55)
	for i = 0, math.floor(width / 40) do
		local x = -halfW + 20 + i * 40
		for _, side in { -1, 1 } do
			Kit.tree(parent, base, x, side * (halfD + 22), 1.1 + (i % 3) * 0.2, trunk, leaf)
		end
	end

	return {
		Number = stage.Number,
		Id = stage.Id,
		EnemySpots = enemySpots,
		BigPad = bigPad,
		ReturnPad = returnPad,
		Barrier = barrier,
		EntryCf = entryCf,
	}
end

return StageBuilder
