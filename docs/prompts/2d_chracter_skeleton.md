# Whisper Crystals — Rig Pirate Cat as Skeleton2D in Godot 4

## Context

Godot 4 narrative 2D game. I have a single static character illustration (`pirate_cat.png`) — anthropomorphic tabby cat pirate: tricorn hat, eyepatch, blue coat, cutlass in right paw, striding pose, tail visible. Transparent/white background. I want to rig it as a Skeleton2D cutout rig so I can animate it with AnimationPlayer instead of needing a sprite sheet.

## Goal

Produce a reusable `PirateCat.tscn` scene containing a Skeleton2D rig driving Polygon2D body parts cut from the source image, plus a handful of starter animations on an AnimationPlayer.

## Tasks

1. **Prep the source image**
   - Read `assets/characters/pirate_cat.png` from the project root.
   - Write a Python helper script (`tools/slice_pirate_cat.py`, uses Pillow) that splits the image into separate PNGs with alpha, one per body part, saved to `assets/characters/pirate_cat/parts/`. Parts needed:
     - `head` (head + hat + eyepatch as one piece for now)
     - `torso` (coat + shirt)
     - `arm_sword_upper`, `arm_sword_lower` (right arm holding cutlass — split at elbow)
     - `sword` (the cutlass, separate so it can swing)
     - `arm_free_upper`, `arm_free_lower` (left arm)
     - `leg_front_upper`, `leg_front_lower`
     - `leg_back_upper`, `leg_back_lower`
     - `tail`
   - The script should use bounding-box detection where possible and leave TODO comments + rough rectangles for me to refine manually. Do not try to be clever about occlusion — overlap is fine, Z-ordering handles it.

2. **Build the scene**
   - Create `scenes/characters/PirateCat.tscn` with this node structure:
 PirateCat (Node2D)
 └── Skeleton2D
     ├── Bone_Root (Bone2D)
     │   ├── Bone_Torso
     │   │   ├── Bone_Head
     │   │   ├── Bone_ArmSwordUpper → Bone_ArmSwordLower → Bone_Sword
     │   │   ├── Bone_ArmFreeUpper → Bone_ArmFreeLower
     │   │   └── Bone_Tail
     │   ├── Bone_LegFrontUpper → Bone_LegFrontLower
     │   └── Bone_LegBackUpper → Bone_LegBackLower
     └── Parts (Node2D)  # holds Polygon2D nodes, one per part
 └── AnimationPlayer
   - Each Polygon2D uses the corresponding part PNG as its texture, with `internal_vertex_count` left at 0 for now (simple quad deform). Assign bones via `skeleton` NodePath and set weights so each polygon is driven 100% by its parent bone — no smooth skinning yet, clean cutout style.
   - Set Z-indices so back leg < tail < torso < front leg < head < arms < sword.

3. **Starter animations on AnimationPlayer**
   Create these, each 1 second, looping where it makes sense:
   - `idle` — subtle breathing (torso scale Y ±2%), tail sway, head bob
   - `walk` — leg swing, opposing arm swing, slight torso bounce
   - `attack_slash` — sword arm winds up and slashes across, 0.4s, non-looping
   - `taunt` — free paw beckons, head tilts, tail flicks

4. **Scripting**
   - Attach `pirate_cat.gd` to the root with a clean API: `play_idle()`, `play_walk()`, `play_attack()`, `play_taunt()`, and a `facing: int` property (1 or -1) that flips the whole Node2D via `scale.x`.
   - Keep it minimal — no state machine yet, just a thin wrapper over AnimationPlayer.

## Constraints

- Godot 4.3+ syntax. GDScript, not C#.
- No external addons. Vanilla Skeleton2D + Polygon2D + AnimationPlayer only.
- Vibe-coding friendly: prefer working-and-rough over architecturally pure. I'll iterate on the rig visually in the editor afterwards.
- Don't invent art. If a body part can't be cleanly extracted, leave a placeholder ColorRect with a TODO and tell me which parts need manual cutting in an image editor.

## Deliverables

1. `tools/slice_pirate_cat.py`
2. `assets/characters/pirate_cat/parts/` populated (or TODO list for manual cuts)
3. `scenes/characters/PirateCat.tscn`
4. `scenes/characters/pirate_cat.gd`
5. A short `RIGGING_NOTES.md` explaining how to tweak bone rest positions in the editor and how to add new animations.

Start by reading the source image and reporting its dimensions + a proposed slice map before you cut anything. I want to sanity-check the regions first.
