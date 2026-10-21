--[[
	Removes the owner's "black block" for everyone (owner, Oct 21: "don't try to hide it, remove it"): once a second
	every player's character is checked on the server and any loose part inside it (Shared/LooseParts) is destroyed,
	which takes it off every screen. One "[HuzzBlock] removed (server) ..." line in Output each (at most MAX_LINES), so
	the maker can still be named. Each screen also checks what only it made (HuzzClient/Gameplay/FollowGuard).
	Errors go to Output on "[Huzz] BlockSweep:" lines; one body's error never stops the others.
]]
local Players = game:GetService("Players")
local LooseParts = require(game:GetService("ReplicatedStorage").Shared.LooseParts)

local BlockSweep = {}
BlockSweep.EVERY = 1
BlockSweep.MAX_LINES = 12

-- One pass over these characters ({ { name, character } }); say(line) for each removed part. Returns how many.
function BlockSweep.sweep(bodies: { { name: string, character: Instance } }, say: (string) -> (), told: { n: number }): number
	local n = 0
	for _, b in bodies do
		local ok, err = pcall(function()
			for _, l in LooseParts.find(b.character) do
				if told.n < BlockSweep.MAX_LINES then
					told.n += 1
					say(LooseParts.line(l.part, b.name, l.gap, "server"))
				end
				l.part:Destroy()
				n += 1
			end
		end)
		if not ok then say("[Huzz] BlockSweep: " .. tostring(err)) end
	end
	return n
end

function BlockSweep.start()
	local told = { n = 0 }
	task.spawn(function()
		while true do
			task.wait(BlockSweep.EVERY)
			local bodies = {}
			for _, p in Players:GetPlayers() do
				if p.Character then table.insert(bodies, { name = p.Name, character = p.Character }) end
			end
			BlockSweep.sweep(bodies, warn, told)
		end
	end)
end

return BlockSweep
