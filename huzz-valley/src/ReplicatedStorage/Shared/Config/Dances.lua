--!strict
-- Dances. AnimationId is "" until the owner supplies the animation: those dances can't play yet (the UI says so).
--   Starter  owned by every new player. Pack = granted by the Dance Pack pass. Reward = from the reward track.
export type Dance = { Id: string, Name: string, AnimationId: string, Art: string?, Starter: boolean?, Pack: boolean?, Order: number }

local Dances = {}

Dances.List = {
	{ Id = "Step", Name = "Step", AnimationId = "", Art = "DanceStep", Starter = true, Pack = true, Order = 1 },
	{ Id = "Shuffle", Name = "Shuffle", AnimationId = "", Art = "DanceShuffle", Pack = true, Order = 2 },
	{ Id = "Spin", Name = "Spin", AnimationId = "", Art = nil, Pack = true, Order = 3 },
	{ Id = "Wave", Name = "Wave", AnimationId = "", Art = "DanceWave", Pack = true, Order = 4 },
} :: { Dance }

local byId: { [string]: Dance } = {}
for _, d in Dances.List do byId[d.Id] = d end

function Dances.get(id: string): Dance?
	return byId[id]
end

return Dances
