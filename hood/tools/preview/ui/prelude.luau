-- prelude.luau (shoot.sh puts it before the game starts): every uploaded icon counts as loaded, so the windows keep
-- their PNG pictures (drawn by the renderer from hood/art/icons3d) instead of swapping to the flat stand-ins the way an
-- upload that never answers does. This is how the windows look once the icons are live in Roblox.
do
	local Kit = require(game.ReplicatedStorage.Shared.UIKit)
	Kit.Preloader = function(content, callback) callback(content, Enum.AssetFetchStatus.Success) end
	Kit.IsLoaded = function() return true end
	-- (round 3) the packed pictures (Shared/ImageLoader) count as drawn: the renderer draws their PNGs (hood/art/ui_owner,
	-- hood/art/icons3d). In Studio they need Game Settings > Security > "Allow Mesh / Image APIs".
	local Loader = require(game.ReplicatedStorage.Shared.ImageLoader)
	Loader.Supported = true
	Loader.make = function() return { Destroy = function() end }, {} end
end
