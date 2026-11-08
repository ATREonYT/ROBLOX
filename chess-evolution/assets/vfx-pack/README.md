# VFX pack textures for the chess items

Six textures from Alex's LihFolk Asset Pack (`LihFolk Vault V2 (imported)/LihFolk Asset Pack/VFX/Textures`), used as they are.
Until they are uploaded, `src/Shared/ChessItems.luau` uses Roblox's built-in particle pictures instead.

To switch them on:
1. In Studio, open View > Asset Manager > Bulk Import and pick these six PNGs.
2. Right-click each one > Copy Asset ID.
3. Paste each number into `ChessItems.PackIds` (top of `src/Shared/ChessItems.luau`), e.g. `glint_star4 = 123456789`.

| File | Used for |
|---|---|
| glint_star4.png | Marble, Gold, Royal, Cosmic, Champion glints |
| flip_petals_8x8.png | Jade falling leaves (8x8 flipbook) |
| spark_streak.png | Sapphire sparks |
| crystal_facets.png | Crystal shards |
| glow_soft.png | soft halos |
| frost_ring.png | Crystal frost ring |
