--[[
	The effect pictures, by name, for every effect in the game (girls' auras, cosmetics, the Secret cutscene).
	Our own art: drawn by tools/fx/make_fx.py into assets/fx, packed for the upload helper, and uploaded by the owner
	once (tools/studio/upload-images.lua writes "Fx/<Name>" into Config/ImageIds). Until a picture is uploaded the
	effect uses the Roblox built-in texture named here, so nothing ever shows blank.
	Sheets (flipbooks): FxTexture.SHEETS says the layout; use FxTexture.flipbook(emitter, name) so a stand-in
	texture never gets cut into a grid.
]]
local Shared = script.Parent
local ImageIds = require(Shared.Config.ImageIds) :: { [string]: string }

local FxTexture = {}

local SPARKLE = "rbxasset://textures/particles/sparkles_main.dds"
local FIRE = "rbxasset://textures/particles/fire_main.dds"
local SMOKE = "rbxasset://textures/particles/smoke_main.dds"

FxTexture.FALLBACK = {
	-- the first set (soft shapes)
	Flame = FIRE, Wisp = SMOKE, Star = SPARKLE, Glow = SPARKLE, Heart = SPARKLE, Petal = SPARKLE, Feather = SPARKLE,
	Snow = SPARKLE, Leaf = SPARKLE, Bubble = SPARKLE, Shard = SPARKLE,
	-- the anime set (hard cel shapes: docs/vfx-guide.md section 3)
	Crescent = SPARKLE, RingHard = SPARKLE, RingSoft = SPARKLE, BurstStar = SPARKLE, Twinkle = SPARKLE, Spark = SPARKLE,
	Swirl = SPARKLE, SwirlStrip = SPARKLE, FlameSheet = FIRE, ShockSheet = SPARKLE, SlashSheet = SPARKLE, Bolt = SPARKLE,
	Streak = SPARKLE, Sigil = SPARKLE, Crown = SPARKLE, Moon = SPARKLE, Butterfly = SPARKLE,
}

-- Flipbook layouts of the sheets (each picture is square; a 2x2 or 4x4 grid of frames).
FxTexture.SHEETS = {
	BurstStar = Enum.ParticleFlipbookLayout.Grid2x2,
	Twinkle = Enum.ParticleFlipbookLayout.Grid2x2,
	Bolt = Enum.ParticleFlipbookLayout.Grid2x2,
	FlameSheet = Enum.ParticleFlipbookLayout.Grid4x4,
	ShockSheet = Enum.ParticleFlipbookLayout.Grid4x4,
	SlashSheet = Enum.ParticleFlipbookLayout.Grid4x4,
	Butterfly = Enum.ParticleFlipbookLayout.Grid2x2,
}

local function uploaded(name: string): string?
	local id = ImageIds["Fx/" .. name]
	if type(id) == "string" and id ~= "" then
		return if id:find("^rbx") then id else "rbxassetid://" .. id
	end
	return nil
end

-- True once the owner has uploaded this picture.
function FxTexture.ready(name: string): boolean
	return uploaded(name) ~= nil
end

function FxTexture.get(name: string): string
	return uploaded(name) or FxTexture.FALLBACK[name] or SPARKLE
end

-- Sets an emitter's texture and, for an uploaded sheet, its flipbook (mode: "OneShot" plays once over each
-- particle's life; "Random" gives each particle one random frame; else it loops at fps). A stand-in texture stays whole.
function FxTexture.flipbook(e: ParticleEmitter, name: string, mode: string?, fps: number?)
	e.Texture = FxTexture.get(name)
	local layout = FxTexture.SHEETS[name]
	if layout and uploaded(name) then
		e.FlipbookLayout = layout
		if mode == "OneShot" then
			e.FlipbookMode = Enum.ParticleFlipbookMode.OneShot
		elseif mode == "Random" then -- (a looping sheet frozen on a random frame: one variant per particle)
			e.FlipbookMode = Enum.ParticleFlipbookMode.Loop
			e.FlipbookStartRandom = true
			e.FlipbookFramerate = NumberRange.new(fps or 0)
		else
			e.FlipbookMode = Enum.ParticleFlipbookMode.Loop
			e.FlipbookFramerate = NumberRange.new(fps or 16)
		end
	else
		e.FlipbookLayout = Enum.ParticleFlipbookLayout.None
	end
end

return FxTexture
