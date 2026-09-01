--!strict
-- THE colour system (ART Part 5). Nothing in this project picks a colour
-- outside this file.
--
-- Rule zero: never pure black, never pure white (ART 5.1, audit tell #8).
-- Pure values look like untouched defaults; INK and PAPER read as chosen.

local Palette = {}

local function rgb(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

-- ── The two "neutrals" that replace #000 and #FFF ───────────────────────────
Palette.Ink = rgb(22, 18, 40) -- outlines, text strokes, anything you'd have made black
Palette.InkSoft = rgb(46, 40, 72)
Palette.Paper = rgb(250, 248, 255) -- anything you'd have made white

-- ── Semantic colours (ART 5.2). Colour must always mean the same thing ──────
Palette.Go = rgb(86, 214, 108) -- unlocked, affordable, confirm
Palette.Stop = rgb(232, 74, 74) -- locked, premium, cancel
Palette.Value = rgb(255, 200, 52) -- Wins, coins, gold tier
Palette.Productivity = rgb(96, 190, 255) -- the click stat and everything tied to it
Palette.Special = rgb(178, 106, 255) -- rare gear, the Consultant, rare interns
Palette.Surface = rgb(58, 62, 84) -- panel backgrounds

-- ── Rarity ladder (ART 5.3). One system, used by gear, interns and tiers ────
export type RarityName = "Common" | "Uncommon" | "Rare" | "Epic" | "Legendary"

export type RarityTier = {
	Color: Color3,
	Gradient: boolean,
	Sparkle: boolean,
	Light: boolean, -- a PointLight on the pad
	Outline: boolean, -- a Highlight outline (mind the mobile cap of 6)
	IdleSpin: boolean,
}

Palette.Rarity = {
	Common = { Color = rgb(168, 178, 196), Gradient = false, Sparkle = false, Light = false, Outline = false, IdleSpin = false },
	Uncommon = { Color = rgb(86, 214, 108), Gradient = true, Sparkle = false, Light = false, Outline = false, IdleSpin = false },
	Rare = { Color = rgb(96, 190, 255), Gradient = true, Sparkle = true, Light = false, Outline = false, IdleSpin = false },
	Epic = { Color = rgb(178, 106, 255), Gradient = true, Sparkle = true, Light = true, Outline = false, IdleSpin = false },
	Legendary = { Color = rgb(255, 200, 52), Gradient = true, Sparkle = true, Light = true, Outline = true, IdleSpin = true },
} :: { [string]: RarityTier }

Palette.RarityOrder = { "Common", "Uncommon", "Rare", "Epic", "Legendary" }

function Palette.rarity(name: string): RarityTier
	return Palette.Rarity[name] or Palette.Rarity.Common
end

-- ── Gold gradient for premium signage (ART 6.1) ─────────────────────────────
-- Rotation 90 (vertical) reads as metal; horizontal reads as a shine sweep.
-- Kept here so every gold thing in the game is the same gold.
Palette.GoldSequence = ColorSequence.new({
	ColorSequenceKeypoint.new(0.00, rgb(255, 244, 186)),
	ColorSequenceKeypoint.new(0.42, rgb(255, 205, 62)),
	ColorSequenceKeypoint.new(0.50, rgb(255, 170, 20)), -- the "metal line"
	ColorSequenceKeypoint.new(0.58, rgb(233, 138, 12)),
	ColorSequenceKeypoint.new(1.00, rgb(255, 226, 140)),
})

-- ── Small helpers so callers never hand-roll a tint ─────────────────────────
function Palette.lighten(color: Color3, amount: number): Color3
	return color:Lerp(Palette.Paper, amount)
end

function Palette.darken(color: Color3, amount: number): Color3
	return color:Lerp(Palette.Ink, amount)
end

-- Deterministic hue jitter for the variance pass (ART 4.3): same index always
-- gives the same shade, so servers agree and nothing shimmers between rebuilds.
function Palette.vary(color: Color3, index: number, amount: number?): Color3
	local spread = amount or 0.04
	local h, s, v = color:ToHSV()
	local wobble = ((index * 37 % 100) / 100 - 0.5) * 2 * spread
	return Color3.fromHSV((h + wobble) % 1, math.clamp(s + wobble * 0.5, 0, 1), math.clamp(v - wobble * 0.35, 0, 1))
end

return Palette
