-- FX lab: one emitter per texture in front of a dark wall, to check textures and flipbooks in the renderer.
-- Run from hood/tools/preview:  lune run harness.luau ../../src fxlab.json "$(cat ../../../.claude/skills/roblox-vfx/scripts/fxlab.luau)"
-- then render with a camera at (0, 6, -30) looking at (0, 6, 0). Remember +X is screen-left from there.
local root = Instance.new('Model') root.Name = 'FxLab' root.Parent = workspace
local function block(size, cf, color)
	local p = Instance.new('Part') p.Anchored = true p.Size = size p.CFrame = cf p.Color = color p.Parent = root
	return p
end
block(Vector3.new(80, 20, 1), CFrame.new(0, 10, 6), Color3.fromRGB(30, 32, 40))
block(Vector3.new(80, 1, 30), CFrame.new(0, -0.5, 0), Color3.fromRGB(200, 200, 206))
local names = { 'aura', 'wisp', 'flame', 'arc', 'mist', 'ray', 'glitter', 'swirl', 'dust', 'softglow' }
for i, n in names do
	local p = block(Vector3.new(0.5, 0.5, 0.5), CFrame.new((i - 5.5) * 8, 4, 0), Color3.new(1, 1, 1))
	p.Transparency = 1
	local e = Instance.new('ParticleEmitter')
	e.Rate, e.Lifetime, e.Speed = 3, NumberRange.new(1.5), NumberRange.new(1)
	e.Size, e.Rotation, e.LightEmission, e.LightInfluence = NumberSequence.new(5), NumberRange.new(0), 0, 0
	e.Color = ColorSequence.new(Color3.fromRGB(255, 120, 60))
	if n == 'flame' then e.Orientation = Enum.ParticleOrientation.FacingCameraWorldUp end
	e:SetAttribute('PreviewTexture', n) -- the renderer draws hood/art/vfx/<n>.png
	e.Parent = p
end
return #names
