# Visual QA Checklist

Manual quality assurance checklists for reviewing Godot game screenshots. Adapted from the godogen Visual QA framework.

## Static Scene Review

Use this checklist when reviewing screenshots of non-animated scenes (terrain, decorations, UI layouts).

### Implementation Quality
- [ ] **Organic placement** — objects arranged naturally, not on a grid or evenly spaced
- [ ] **Scale and proportion** — varied, purposeful sizing; not everything at uniform/default scale
- [ ] **Scene composition** — depth and layering present; not flat
- [ ] **Texture/material application** — no stretching, tiling seams, or carelessly applied materials
- [ ] **Spatial sophistication** — objects relate to environment; not just placed on a flat plane
- [ ] **Camera framing** — perspective matches intended design

### Visual Bugs
- [ ] **No z-fighting** — no flickering or overlapping surfaces at same depth
- [ ] **No texture issues** — no stretching, tiling seams, missing textures (magenta/checkerboard)
- [ ] **No geometry clipping** — objects not visibly intersecting
- [ ] **No floating objects** — everything that should be grounded is grounded
- [ ] **No shadow artifacts** — no detached shadows, shadows through walls, or missing shadows
- [ ] **No lighting leaks** — no bright spots through opaque geometry
- [ ] **No culling errors** — no missing faces or disappearing objects
- [ ] **No UI issues** — no overlapping elements, truncated text, or offscreen elements

### Logical Consistency
- [ ] **Correct orientations** — nothing sideways, upside-down, or embedded in terrain
- [ ] **Scale matches** — trees bigger than characters, doors fit characters, etc.
- [ ] **Correct placement** — furniture on floors, rocks on ground, etc.
- [ ] **Spatial relationships** — bridges connect, stairs lead somewhere, etc.
- [ ] **UI values** — no impossible values displayed

### Placeholder Detection
- [ ] **No primitive geometry** — no untextured cubes/spheres contrasting with detailed elements
- [ ] **No default materials** — no grey StandardMaterial3D, no magenta missing shader
- [ ] **No debug artifacts** — no collision shapes, nav mesh, axis gizmos, path lines visible
- [ ] **No orphaned UI** — no UI elements stuck at default positions

## Dynamic Scene Review

Use this checklist when reviewing frame sequences of animated/interactive scenes. Frames are typically captured at 2 FPS (0.5s between frames).

### All Static Checks Above, Plus:

### Motion & Animation
- [ ] **Entities move** — position changes across frames when movement expected
- [ ] **No jitter/teleportation** — smooth position changes, no large jumps between frames
- [ ] **No sliding** — animation pose changes with position (not ice-skating)
- [ ] **Physics correct** — no objects passing through walls/floors, no endless bouncing
- [ ] **Animation matches action** — walk animation at walking speed, idle when stopped
- [ ] **Camera tracks** — no sudden jumps, no clipping through geometry
- [ ] **Collision works** — objects that should collide do collide
- [ ] **Timing correct** — animations not too fast/slow relative to game speed

## Verdict Categories

- **Pass** — no major issues, acceptable for shipping
- **Warning** — minor issues that don't block progress but should be noted
- **Fail** — major issues that must be fixed before proceeding

## Issue Severity

- **Major** — must fix; affects gameplay, breaks immersion, or indicates broken functionality
- **Minor** — should fix; noticeable but doesn't affect gameplay
- **Note** — cosmetic; acceptable to ship, nice to fix if time allows

## Issue Types

- **Style mismatch** — implementation doesn't match intended design
- **Visual bug** — rendering error or artifact
- **Logical inconsistency** — something that doesn't make sense in the game world
- **Motion anomaly** — animation or physics problem (dynamic scenes only)
- **Placeholder** — unfinished or placeholder content remaining
