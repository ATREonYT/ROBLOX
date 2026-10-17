# Character placeholder replacement map

Every slot below is defined. This does not mean its model exists: real Roblox models/animation assets must be supplied.

Live players use their Roblox avatar, not Aiko. Collectible NPCs use a shared catalogue model. Product previews show the player or specified cosmetic. A pictured avatar is never proof of an actual rig.

| Slot | Page | Binding | Type | Pose |
|---|---|---|---|---|
| vip-promotion-character | 01-shop-passes | equippedCharacterId | cosmetic_promotion | idle |
| dance-pack-promotion-character | 01-shop-passes | equippedCharacterId | cosmetic_promotion | dance_pack_preview |
| card-aiko | 02-character-index | catalogue:aiko | collectible_npc | idle |
| card-ren | 02-character-index | catalogue:ren | collectible_npc | idle |
| card-sora | 02-character-index | catalogue:sora | collectible_npc | idle |
| card-hina | 02-character-index | catalogue:hina | collectible_npc | idle |
| selected-character-model | 02-character-index | selectedCharacterId | collectible_npc | idle |
| dance-card-step | 03-dances | localPlayerAvatar | player_avatar_preview | step |
| dance-card-shuffle | 03-dances | localPlayerAvatar | player_avatar_preview | shuffle |
| dance-card-spin | 03-dances | localPlayerAvatar | player_avatar_preview | spin |
| dance-card-wave | 03-dances | localPlayerAvatar | player_avatar_preview | wave |
| selected-dance-preview | 03-dances | localPlayerAvatar | player_avatar_preview | selectedDanceId |
| wave-dance-reward | 04-progression-rewards | localPlayerAvatar | reward_preview | wave |
| aiko-outfit-reward | 04-progression-rewards | reward:outfit_aiko | outfit_mesh_no_person | idle |
| bonus-ren_outfit | 04-progression-rewards | reward:ren_outfit | outfit_mesh_no_person | idle |
| bonus-sora_character | 04-progression-rewards | reward:sora_character | collectible_npc | idle |
| bonus-silver_hair | 04-progression-rewards | reward:silver_hair | accessory_mesh_no_person | idle |
| bonus-aiko_outfit | 04-progression-rewards | reward:aiko_outfit | outfit_mesh_no_person | idle |
| next-reward-04-progression-rewards | 04-progression-rewards | nextReward.modelId | reward_preview | idle |
| next-reward-05-progression-quests | 05-progression-quests | nextReward.modelId | reward_preview | idle |
| sunset-trail-demonstration | 07-shop-cosmetics | localPlayerAvatar | effect_on_player_avatar | run |
| blossom-aura-demonstration | 07-shop-cosmetics | localPlayerAvatar | effect_on_player_avatar | idle |
| crown-pose-demonstration | 07-shop-cosmetics | localPlayerAvatar | player_avatar_preview | victory |
| midnight-outfit-mesh | 07-shop-cosmetics | product:midnight_outfit | outfit_mesh_no_person | idle |
| highest-tier-character-preview | 11-tier-index | highestOwnedTierCharacterId | collectible_npc | idle |
| world-player | 12-main-menu | localPlayerAvatar | live_world_player | idle |
| world-player-lobby | 13-lobby-hud | localPlayerAvatar | live_world_player | idle |
| world-companion-lobby | 13-lobby-hud | equippedCharacterId | live_world_npc | idle |
| world-local-player-match | 14-match-hud | localPlayerAvatar | live_world_player | run |
| world-current-leader | 14-match-hud | round.leaderUserId | live_world_player | run |
| round-featured-companion | 14-match-hud | round.featuredCharacterId | live_world_npc | run |
| recruit-aiko | 16-recruitment | catalogue:aiko | collectible_npc | idle |
| recruit-ren | 16-recruitment | catalogue:ren | collectible_npc | idle |
| recruit-sora | 16-recruitment | catalogue:sora | collectible_npc | idle |
| results-second | 17-round-results | round.podium.second.userId | remote_player_avatar | idle |
| results-winner | 17-round-results | round.podium.winner.userId | remote_player_avatar | idle |
| results-third | 17-round-results | round.podium.third.userId | remote_player_avatar | idle |
| recruitment-result-portrait | 17-round-results | round.featuredCharacterId | collectible_npc | idle |
| recipient-alex | 18-gift-picker | serverPlayers[i].UserId | remote_player_avatar | idle |
| recipient-jade | 18-gift-picker | serverPlayers[i].UserId | remote_player_avatar | idle |
| recipient-sam | 18-gift-picker | serverPlayers[i].UserId | remote_player_avatar | idle |
| selected-recipient-thumbnail | 18-gift-picker | gift.selectedUserId | remote_player_avatar | idle |

## Global replacement rules

1. Keep a shared CharacterCatalogue keyed by stable character ID. Resolve ModelAsset/ModelPath, Portrait camera, Tier, DisplayName, IdleAnimation and Source.
2. Replace a catalogue model once, then rebuild every dependent ViewportFrame. Do not keep independent Aiko copies in individual screens.
3. Use a shared renderer/camera for card art and a full-body preview profile for details. Do not stretch body proportions.
4. Player avatars load by actual UserId. Names such as Alex/Jade/Sam are sample labels only.
5. Locked slots show a genuine silhouette and no hidden full-colour render.
6. Dance poses come from real animation IDs, with explicit missing-asset state.
7. Outfit and hair rewards use isolated mesh/accessory previews, not a fabricated new companion.
8. Map thumbnails depict maps; generic cart/book/star/gear icons stay icons and do not become characters.
9. World-model screen locations are illustrative: camera/player movement changes them. Anchor HUD only; never position live characters with UI pixel coordinates.