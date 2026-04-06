# Asset Manifest — Whisper Crystals

Track all game assets with their intended in-game dimensions to prevent scaling bugs.

## Format

| Asset | Type | File Path | In-Game Size | Status |
| ------- | ------ | ----------- | ------------- | -------- |
| Example Ship | Sprite Sheet | `assets/sprites/ships/player_ship.png` | 64x48 per frame | done |

## Asset Types

- **Sprite Sheet** — animated sprite grid; record per-frame display size
- **Static Sprite** — single image; record display dimensions in pixels
- **Background** — full or tiled background; record pixel dimensions
- **Audio SFX** — sound effect; record duration
- **Audio Music** — background music track; record duration
- **UI Element** — interface graphic; record display dimensions

## Sizing Discipline

Every asset entry MUST include its intended in-game size:

- Sprite sheets: per-frame display size (e.g., "64x48 per frame")
- Backgrounds: pixel dimensions (e.g., "1280x720")
- UI elements: display dimensions (e.g., "200x32")

This prevents the common bug of generating detailed assets that get shrunk to icons, or creating tiny assets that get stretched.

## Current Assets

<!-- Add assets here as they are created -->
