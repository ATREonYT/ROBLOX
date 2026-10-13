--!strict
-- Image IDs for the UI icons. Empty = not imported yet: the icon stays blank in Studio (nothing is faked).
--
-- To fill these in: Studio > Asset Manager (View tab) > Bulk Import > pick every file in huzz-valley/assets/icons.
-- Then right-click each imported image > Copy ID, and paste it between the quotes below as "rbxassetid://<number>".
-- The PNGs are cut out from the kit's exact-pixel reference crops (tools/icons/cutout.py): reconstructions, not
-- the original artwork, and small (about 4x the reference size).
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
	ShopCart = "",            -- shop-cart.png
	Sneaker = "",             -- sneaker.png
	Stop = "",                -- stop.png
	Stopwatch = "",           -- stopwatch.png
	TagFist = "",             -- tag-fist.png
	TierCrown = "",           -- tier-crown.png
	VipCrown = "",            -- vip-crown.png
	XpBadge = "",             -- xp-badge.png
}

-- "Avatar" is not an uploaded image: rows that use it show the viewing player's own avatar (Roblox thumbnail).
function Assets.icon(name: string): string
	return (Assets.Icons :: any)[name] or ""
end

return Assets
