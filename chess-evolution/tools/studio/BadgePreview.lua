-- +1 Chess Evolution: Studio-only badge preview. Paste into Studio's Command Bar (View > Command Bar)
-- and press Enter. No Play needed. Run it again to hide the preview.
-- Shows every battle badge on screen (StarterGui > ChessBadgePreview) and prints the five
-- test fights in Output on [ChessBadges] lines (normal win, no-input loss, pause and recovery,
-- deep comeback, failed recovery). Screenshot Output and the preview for Claude.
local RS = game:GetService("ReplicatedStorage")
local SG = game:GetService("StarterGui")
local old = SG:FindFirstChild("ChessBadgePreview")
if old then
	old:Destroy()
	print("[ChessBadges] preview hidden")
	return
end
local ok, err = pcall(function()
	local Kit = RS:WaitForChild("Kit", 5)
	local Config = require(RS:WaitForChild("ChessConfig", 5))
	local Preview = require(Kit.BadgePreview)
	local gui = Preview.Build(Config)
	gui.Parent = SG
	for _, line in Preview.Scenarios(Config, require(Kit.Battle), require(Kit.Badges)) do
		print(line)
	end
	print("[ChessBadges] preview shown: StarterGui > ChessBadgePreview (run this again to hide it)")
end)
if not ok then
	warn("[ChessBadges] preview failed: " .. tostring(err))
end
