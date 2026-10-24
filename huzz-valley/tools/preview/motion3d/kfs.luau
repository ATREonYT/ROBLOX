-- Plays a Roblox KeyframeSequence (the owner's animation files) on a preview rig, as Roblox's Animator would.
-- The sampling is the game's own Shared/KeyframeSampler (load, sample); this adds apply() for preview rigs.
-- KFS.load(keyframeSequence) -> anim { length, loop, tracks = { [partName] = { {t, cframe, style, dir} } } }
-- KFS.apply(anim, rig, t, weight?) sets rig motors' Transform (motor found by its Part1 name; weight blends
-- from the current Transform, for walk -> run fades).
local Env = require("./env")
local Sampler = Env.load("huzz-valley/src/ReplicatedStorage/Shared/KeyframeSampler.lua")
local KFS = {}
KFS.load = Sampler.load
KFS.sample = Sampler.sample

function KFS.apply(anim, rig, t, weight)
	local pose = KFS.sample(anim, t)
	for _, m in rig.motors do
		local cf = pose[m.Part1.Name]
		if cf then
			m.Transform = if weight and weight < 1 then m.Transform:Lerp(cf, weight) else cf
		end
	end
end

return KFS
