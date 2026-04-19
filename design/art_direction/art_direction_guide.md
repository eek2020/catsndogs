# Whisper Crystals — Art Direction Guide

**Companion docs.**

- [`cutscene_visual_language.md`](cutscene_visual_language.md) — painterly-3D cutscene aesthetic (Track C). Shading, outlines, camera grammar, dialogue card style. Read this before authoring a pre-rendered cutscene.
- [`sprite_sheet_notes.md`](sprite_sheet_notes.md) — Track A sprite-sheet conventions.

---

## Visual Style

### Overall Aesthetic
- **Tone:** Spelljammer-inspired — serious stakes with a fun, accessible cast of anthropomorphic animals
- **Style:** 2D pixel art — two tracks running together:
  - **Track A (floor, applies to all characters):** native 64×64 sprites (exported 256×256), 12–16 colour palette per sheet, shaded with selective anti-aliasing, readable silhouettes at minimap scale.
  - **Track B (aspirational, named cast only):** painterly portrait cards in the style of `aristotle.png` / `dave.png`. Used in dialogue, cutscenes, and shop flow. Generic NPCs do not get painterly portraits.
- **Palette:** Deep space blacks and blues contrasted with warm ship interiors and crystal glow effects
- **Mood:** Adventurous, slightly chaotic, with moments of grandeur and menace

### Reference Pins

The floor and fidelity bar for Track A is calibrated against these shipped games. When in doubt, match their readability and silhouette clarity at equivalent zoom.

- **Stardew Valley** — colour discipline, 16×16 readability scaled up, warm lit interiors.
- **Death's Door** — silhouette clarity, moody palette, restrained animation.
- **Moonlighter** — 64×64 character sprite floor, portrait-to-sprite parity, shop/dialogue UI integration.
- **Eastward** — painterly backgrounds with pixel-art foregrounds (useful when mixing Track A sprites with painted ship illustrations).
- **Sea of Stars** — lighting and shader polish on top of a pixel-art floor.

### Colour Palettes by Faction

**Felid Corsairs (Cats)**
- Primary: Deep purple, crimson red
- Accent: Gold, amber
- Feel: Pirate flags, royal rebellion, independence

**Canis League (Dogs)**
- Primary: Navy blue, steel grey
- Accent: White, brass
- Feel: Military uniforms, battleship hulls, disciplined order

**The Lions**
- Primary: Gold, royal purple
- Accent: White marble, ivory
- Feel: Nobility, cathedrals, divine right

**The Wolves**
- Primary: Charcoal, dark green
- Accent: Silver, ice blue
- Feel: Tactical gear, winter campaigns, cold efficiency

**Fairies**
- Primary: Iridescent blue-green, soft pink
- Accent: Starlight white, crystal shimmer

**Goblins**
- Primary: Rust orange, sickly green
- Accent: Brass, salvage metal

**Knights**
- Primary: Silver, red, heraldic blue
- Accent: Gold trim, banner colours

**Aliens**
- Primary: Neon cyan, deep black
- Accent: Bioluminescent greens and purples

---

## Ship Design Principles

### Cat Ships (Felid Corsairs)
- Asymmetric silhouettes — no two look identical
- Jury-rigged appearance: mismatched panels, improvised additions
- Sleek and fast — long, narrow profiles
- Visible crystal fuel chambers glowing in the hull
- Pirate flags / pennants trailing behind

### Dog Ships (Canis League)
- Symmetrical, imposing silhouettes
- Heavy plating, visible gun turrets, military markings
- Broader, more armoured hulls
- Fleet formation — ships designed to work in groups
- Military insignia and rank markings

### Lion Ships
- Ornate and decorative — gold filigree, carved prow
- Cathedral-ship aesthetic — stained glass viewports
- Balanced but slightly ostentatious

### Wolf Ships
- Streamlined predator shapes
- Tactical and minimal decoration
- Dark paint, low-visibility profiles
- Built for strike missions

---

## Character Portrait Style

- Head and shoulders frame
- Expressive faces — emotions readable at small sizes
- Distinct silhouettes — each character identifiable by outline alone
- Faction colours in clothing / armour
- Aristotle: Confident smirk, captain's coat, crystal pendant
- Dave: Calm intensity, military collar, steady gaze
- Death: Hooded, glowing eyes, shadowy presence

---

## Environment Art

### Space Backgrounds
- Layered parallax: distant stars → mid nebulae → near asteroids
- Each realm has a distinct colour temperature:
  - Starting realm: warm amber/gold (crystal discovery)
  - Trade hubs: bright, busy, multi-coloured (commerce)
  - Canis territory: cool blue/grey (military)
  - Lion territory: golden/ivory (nobility)
  - Deep space: dark, sparse, mysterious

### Whisper Crystal Visual Effects
- Crystals emit a soft, pulsing glow (blue-white core, purple edges)
- "Whisper" effect: subtle particle trails that look like sound waves
- Refined crystals glow brighter than raw deposits
- Crystal fuel chambers on ships pulse in rhythm with engine thrust

---

## UI Visual Style

- Clean, semi-transparent panels with faction-appropriate borders
- Dialogue boxes: dark background, character portrait on left, text on right
- HUD: Minimal, docked to screen edges, non-obstructive
- Trade UI: Split-screen with clear inventory grids
- Faction colours integrated into UI elements when viewing faction-specific content

---

## Placeholder Asset Guidelines (Phase 1)

For the prototype, simple geometric shapes with faction colours are acceptable:
- Ships: Coloured triangles/polygons with faction colour fills
- Characters: Coloured circles with name labels for portraits
- Crystals: Glowing hexagons
- Backgrounds: Gradient fills with particle dots for stars
- UI: Solid colour rectangles with text labels

The priority is gameplay and systems — art polish comes in Phase 2.
