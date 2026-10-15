--[[
	Removes a known scam hidden in free models (found in the owner's Basket Ball
	Hoop): a "Dependencies > Utilities > CoreValidation" script that shows a fake
	"Model corruption detected… paste this into the Command Bar" box, whose code
	installs a backdoor. Runs when the server starts; the owner should still
	delete the hoops' Dependencies folders in Studio.
]]
local SafetyService = {}

function SafetyService.clean()
	for _, d in workspace:GetDescendants() do
		if d:IsA("Script") and d.Name == "CoreValidation" and d.Parent and d.Parent.Name == "Utilities" then
			local dependencies = d.Parent.Parent
			warn(`[Huzz] Removed a scam script hidden in {dependencies and dependencies:GetFullName() or d:GetFullName()}. Delete it in Studio too.`)
			if dependencies and dependencies.Name == "Dependencies" then
				dependencies:Destroy()
			else
				d.Parent:Destroy()
			end
		end
	end
end

return SafetyService
