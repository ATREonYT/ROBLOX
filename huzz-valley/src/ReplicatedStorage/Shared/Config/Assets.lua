--!strict
-- Image IDs for the UI icons and pictures. Optional: while an ID is empty, the game draws the image itself from the
-- pixels packed into Shared/Images (tools/icons/pack_images.py). Uploaded IDs load faster and use less memory.
--
-- The easy way to fill them in: run ServerStorage/HuzzStudioTools/UploadPictures (tools/studio/upload-images.lua) in Studio's Command Bar. It uploads every image
-- and writes the IDs into Config/ImageIds (checked first). IDs typed below by hand also work.
-- The PNGs are the owner's exact icon files from the UI kit (design/exact-pixel-icon-references), same pixels and
-- size, with only the baked-in background made transparent (tools/icons/clear_background.py).
local Uploaded = require(script.Parent.ImageIds) :: { [string]: string }
local Assets = {}

Assets.Icons = {
	AudioMusic = "",          -- audio-music.png
	AudioSpeaker = "",        -- audio-speaker.png
	AudioWaveform = "",       -- audio-waveform.png
	ChatBenefit = "",         -- chat-benefit.png
	CheckEquipped = "",       -- check-equipped.png
	CheckOwned = "",          -- check-owned.png
	Close = "",               -- close.png
	CollectionBook = "",      -- collection-book.png
	CompanionEffects = "",    -- companion-effects.png
	ControlsDash = "",        -- controls-dash.png
	ControlsKeyboard = "",    -- controls-keyboard.png
	ControlsMenu = "",        -- controls-menu.png
	CurrencyCoin = "",        -- currency-coin.png
	CurrencyGem = "",         -- currency-gem.png
	CurrencyPlus = "",        -- currency-plus.png
	DancesNote = "",          -- dances-note.png
	Envelope = "",            -- envelope.png
	FavouriteFilled = "",     -- favourite-filled.png
	FavouriteOutline = "",    -- favourite-outline.png
	GiftAction = "",          -- gift-action.png
	GiftBenefit = "",         -- gift-benefit.png
	InventoryBackpack = "",   -- inventory-backpack.png (his Inventory button tile, Oct 22: the whole button)
	InventoryVisibility = "", -- inventory-visibility.png
	Lock = "",                -- lock.png
	MainMenuLines = "",       -- main-menu-lines.png
	Monitor = "",             -- monitor.png
	MusicBenefit = "",        -- music-benefit.png
	Play = "",                -- play.png
	Players = "",             -- players.png
	QuestsClipboard = "",     -- quests-clipboard.png
	RewardsTrophy = "",       -- rewards-trophy.png
	Search = "",              -- search.png
	SettingsGear = "",        -- settings-gear.png
	ShirtBenefit = "",        -- shirt-benefit.png
	ShirtEquip = "",          -- shirt-equip.png
	ShopCart = "",            -- shop-cart.png
	Sneaker = "",             -- sneaker.png
	Stop = "",                -- stop.png
	StudTile = "",            -- stud-tile.png (header stud texture, drawn by tools/icons/make_stud_tile.py)
	Stopwatch = "",           -- stopwatch.png
	TagFist = "",             -- tag-fist.png
	TierCrown = "",           -- tier-crown.png
	VipCrown = "",            -- vip-crown.png
	XpBadge = "",             -- xp-badge.png
}

-- Product pictures, cropped unchanged from the kit's pages (design/pages 01, 07, 08). Import them the same way.
Assets.Art = {
	MapBase = "",        -- assets/art/map-base.png (the owner's map pictures, Oct 18: the map vote cards and NEXT MAP tiles)
	MapBasketball = "",  -- assets/art/map-basketball.png
	MapHalloween = "",   -- assets/art/map-halloween.png
	BlossomAura = "",    -- assets/art/blossom-aura.png
	CoinPack2000 = "",   -- assets/art/coin-pack-2000.png (cut from the Oct 17 mockup: placeholder until a sharp PNG)
	CoinPack500 = "",    -- assets/art/coin-pack-500.png (same)
	CoinPack5000 = "",   -- assets/art/coin-pack-5000.png (same)
	CrownPose = "",      -- assets/art/crown-pose.png
	DancePack = "",      -- assets/art/dance-pack.png
	LightRays = "",      -- assets/art/light-rays.png (made by us: soft rays that turn behind featured pictures)
	MidnightOutfit = "", -- assets/art/midnight-outfit.png
	PassKnifeFrost = "",   -- assets/art/pass-knife-frost.png (the knife Game Pass cards, cut from the owner's mockup
	PassKnifeHunter = "",  -- assets/art/pass-knife-hunter.png  design/knives/Five_Elemental_Knife_Cards.png by
	PassKnifeInferno = "", -- assets/art/pass-knife-inferno.png tools/icons/cut_pass_knife_cards.py; drawn in Play
	PassKnifeMoonlit = "", -- assets/art/pass-knife-moonlit.png until uploaded)
	PassKnifeSunrise = "", -- assets/art/pass-knife-sunrise.png
	SunsetTrail = "",    -- assets/art/sunset-trail.png
	Vip = "",            -- assets/art/vip.png
}

-- "Avatar" is not an uploaded image: rows that use it show the viewing player's own avatar (Roblox thumbnail).
function Assets.icon(name: string): string
	local id = Uploaded["Icons/" .. name]
	if id and id ~= "" then return id end
	return (Assets.Icons :: any)[name] or ""
end

function Assets.art(name: string): string
	local id = Uploaded["Art/" .. name]
	if id and id ~= "" then return id end
	return (Assets.Art :: any)[name] or ""
end

return Assets
