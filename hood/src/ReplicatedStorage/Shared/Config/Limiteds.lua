-- Limiteds: the special-sale spots' third line (stock left and the time left on the sale).
--
-- PLACEHOLDER until the real global stock and the real sale-end timer exist. The lobby's two special-sale spots
-- (TheBlockV2 Lobby.saleSpot) carry an empty, hidden third line under the price: the TextLabels LimitedStock and
-- LimitedTimer in the words' billboard (which wears the attribute LimitedLine). The map never bakes words into it.
-- Until the real system lands, this module can fill it with a STATIC look-only sample ("37/100 LEFT" and "23:59:59":
-- no counting down, nothing decreasing), and only where no player can ever see it: when ShowPlaceholders is on AND
-- RunService:IsStudio() is true. A live server (a published place) never shows it, so no fake stock or timer reaches
-- players (kid-safe rule: no fake timers or scarcity). The real limiteds system will write real numbers into the same
-- labels, and this sample goes.
local RunService = game:GetService('RunService')

local Limiteds = {}

Limiteds.ShowPlaceholders = true -- (PLACEHOLDER) the owner's look check in Studio; never shown in a live server
Limiteds.PlaceholderStock = '37/100 LEFT' -- (PLACEHOLDER) static sample text, not a real count
Limiteds.PlaceholderTimer = '23:59:59' -- (PLACEHOLDER) static sample text, never counts down

-- Whether the sample may show: the flag on and running in Studio (the offline preview harness reports Studio too).
function Limiteds.placeholdersOn(): boolean
	if Limiteds.ShowPlaceholders ~= true then return false end
	local ok, studio = pcall(function() return RunService:IsStudio() end)
	return ok and studio == true
end

-- Fill (or clear) every special-sale spot's third line under `root`. Returns how many lines it filled.
function Limiteds.applyPlaceholders(root: Instance?): number
	if not root then return 0 end
	local on = Limiteds.placeholdersOn()
	local n = 0
	for _, d in root:GetDescendants() do
		if d:IsA('TextLabel') and (d.Name == 'LimitedStock' or d.Name == 'LimitedTimer') then
			d.Text = on and (d.Name == 'LimitedStock' and Limiteds.PlaceholderStock or Limiteds.PlaceholderTimer) or ''
			d.Visible = on
			if on and d.Name == 'LimitedStock' then n += 1 end
		end
	end
	return n
end

return Limiteds
