# Character Asset Reorganization — Dry-Run Plan

**Status:** proposed, awaiting sign-off.
**Scope:** `godot/assets/characters/`, `godot/assets/sprites/`, `design/charcters/`, plus all references in code/data/scenes/docs.

## Target layout

### `godot/assets/characters/` (runtime, shipped)

```text
godot/assets/characters/
  aristotle/
    2d/
      head.png
      spritesheet.png
    3d/
      source.glb
      source_texture.png
      rigged.glb
      rigged_texture.png
      rigged.expected.json
      rigged.validate.json
  dave/
    2d/ { head.png, spritesheet.png }
    3d/ { source.glb, source_texture.png }
  crew/
    nine_lives/
      2d/ { portrait.png, spritesheet.png }
      3d/ { rigged.glb, rigged_texture.png, rigged.expected.json, rigged.validate.json, rigged.retarget.json }
    no_tail/
      2d/ { portrait.png, spritesheet.png }
      3d/ { source.glb, source_texture.png }
    silky/      { 2d/ { portrait.png, spritesheet.png } }
    blood_paw/  { 2d/ { portrait.png, spritesheet.png } }
    charlie/    { .gdkeep }
    bombardier/ { .gdkeep }
    luna/       { .gdkeep }
    thistle/    { .gdkeep }
  npc/
    death/              { 2d/ { head.png, spritesheet.png } }
    fairy_cartographer/ { 2d/ { portrait.png, spritesheet.png } }
    landlord/           { 2d/ { spritesheet.png } }
    merchant/           { 2d/ { spritesheet.png } }
    whiskers/           { 2d/ { spritesheet.png } }
    bard/               { 2d/ { spritesheet.png } }
    guard/              { 2d/ { spritesheet.png } }
    sailor/             { 2d/ { spritesheet.png } }
    urchin/             { 2d/ { spritesheet.png } }
```

### `design/charcters/` (source, working files)

```text
design/charcters/
  _pipeline/
    cc0_source/                      # was 3d/cc0_source
  aristotle/
    3d/
      source.glb                     # aristotle_3d.glb
      t_pose.fbx                     # aristotle_t_pose_3d.fbx (Mixamo-prepped)
      t_pose.inspect.json
      previews/
        t_pose_front.png
        t_pose_side.png
        t_pose_three_quarter.png
    animations/
      mixamo_raw/                    # user drops downloaded FBX anims here
  dave/
    3d/
      source.glb                     # dave_3d.glb
  crew/
    nine_lives/
      3d/
        clean.fbx
        clean.glb
        clean.prep.json
        previews/
          source_front.png           # was preview/nine_lives_clean_front.png
          source_side.png
          source_three_quarter.png
          rigged_front.png
          rigged_side.png
          rigged_three_quarter.png
      animations/
        mixamo_raw/
    no_tail/
      3d/
        source.glb                   # no_tail_3d.glb
```

The CC0 UAL source stays under `_pipeline/cc0_source/` because it's pipeline infrastructure (45 reference anims), not per-character.

Retire `godot/assets/sprites/` entirely. Retire `design/charcters/3d/` as a top-level dir (contents move into per-character subtrees).

## 1. Orphan files → `_unused/` bucket (no deletions)

All files below are confirmed unreferenced by grep. They move into a top-level
`_unused/` bucket at each tree so you can eyeball or permanently delete them
later. Nothing is removed from the repo in this pass.

### Godot runtime orphans → `godot/assets/characters/_unused/`

- `aristotle.png` + `.import` (full-body, superseded by head)
- `dave.png` + `.import`
- `death.jpg` + `.import`
- `death_v2.jpg` + `.import`
- `death_head_front.png` + `.import`
- `crew/nine_lives_full.png` + `.import`
- `crew/no_tail_full.png` + `.import`
- `crew/nine_live_walking.glb` + `.import` + `.inspect.json`
- `crew/nine_live_walking_texture_20250901.png` + `.import`

### Design-side orphans → `design/charcters/_unused/`

These are all duplicates of the Godot runtime copies — the same PNG/JPG
exists in both trees.

- `aristotle.png`, `aristotle_head.png`, `aristotle_spritesheet.png`
- `blood_paw.png`
- `crew/nine_lives.png`, `crew/no_tail.png`, `crew/no_tail_full.png`, `crew/silky.png`
- `dave.png`, `dave_head.png`, `dave_spritesheet.png`
- `death.jpg`, `death_head.png`, `death_head_front.jpg`, `death_v2.jpg`

### Empty-dir cleanup

The only outright removal is the empty `godot/assets/characters/crew/.gdkeep`
once the `crew/` directory has real content (it will). No asset file is
deleted. The `.gdkeep` was only a git-tracking placeholder for an otherwise
empty dir.

## 2. Moves — `godot/assets/characters/`

Every line is a `git mv`. PNG + its `.import` sidecar always move together to preserve the UID and avoid scene breakage.

| From | To |
|---|---|
| `godot/assets/characters/aristotle_head.png(.import)` | `aristotle/2d/head.png(.import)` |
| `godot/assets/characters/aristotle_3d.glb(.import)` | `aristotle/3d/source.glb(.import)` |
| `godot/assets/characters/aristotle_3d_texture_20250901.png(.import)` | `aristotle/3d/source_texture.png(.import)` |
| `godot/assets/characters/crew/aristotle_rigged.glb(.import)` | `aristotle/3d/rigged.glb(.import)` |
| `godot/assets/characters/crew/aristotle_rigged_texture_20250901.png(.import)` | `aristotle/3d/rigged_texture.png(.import)` |
| `godot/assets/characters/crew/aristotle_rigged.expected.json` | `aristotle/3d/rigged.expected.json` |
| `godot/assets/characters/crew/aristotle_rigged.validate.json` | `aristotle/3d/rigged.validate.json` |
| `godot/assets/characters/dave_head.png(.import)` | `dave/2d/head.png(.import)` |
| `godot/assets/characters/no_tail_3d.glb(.import)` | `crew/no_tail/3d/source.glb(.import)` |
| `godot/assets/characters/no_tail_3d_texture_20250901.png(.import)` | `crew/no_tail/3d/source_texture.png(.import)` |
| `godot/assets/characters/death_head.png(.import)` | `npc/death/2d/head.png(.import)` |
| `godot/assets/characters/support/fairy_cartographer.png(.import)` | `npc/fairy_cartographer/2d/portrait.png(.import)` |
| `godot/assets/characters/crew/nine_lives.png(.import)` | `crew/nine_lives/2d/portrait.png(.import)` |
| `godot/assets/characters/crew/no_tail.png(.import)` | `crew/no_tail/2d/portrait.png(.import)` |
| `godot/assets/characters/crew/silky.png(.import)` | `crew/silky/2d/portrait.png(.import)` |
| `godot/assets/characters/crew/blood_paw.png(.import)` | `crew/blood_paw/2d/portrait.png(.import)` |
| `godot/assets/characters/crew/nine_lives_rigged.glb(.import)` | `crew/nine_lives/3d/rigged.glb(.import)` |
| `godot/assets/characters/crew/nine_lives_rigged_texture_20250901.png(.import)` | `crew/nine_lives/3d/rigged_texture.png(.import)` |
| `godot/assets/characters/crew/nine_lives_rigged.validate.json` | `crew/nine_lives/3d/rigged.validate.json` |
| `godot/assets/characters/crew/nine_lives_rigged.retarget.json` | `crew/nine_lives/3d/rigged.retarget.json` |

Delete `godot/assets/characters/support/` (empty after the one move).

## 3. Moves — `godot/assets/sprites/` → per-character

| From | To |
|---|---|
| `godot/assets/sprites/aristotle_spritesheet.png(.import)` | `godot/assets/characters/aristotle/2d/spritesheet.png(.import)` |
| `godot/assets/sprites/dave_spritesheet.png(.import)` | `godot/assets/characters/dave/2d/spritesheet.png(.import)` |
| `godot/assets/sprites/nine_lives_spritesheet.png(.import)` | `godot/assets/characters/crew/nine_lives/2d/spritesheet.png(.import)` |
| `godot/assets/sprites/no_tail_spritesheet.png(.import)` | `godot/assets/characters/crew/no_tail/2d/spritesheet.png(.import)` |
| `godot/assets/sprites/silky_spritesheet.png(.import)` | `godot/assets/characters/crew/silky/2d/spritesheet.png(.import)` |
| `godot/assets/sprites/blood_paw_spritesheet.png(.import)` | `godot/assets/characters/crew/blood_paw/2d/spritesheet.png(.import)` |
| `godot/assets/sprites/death_spritesheet.png(.import)` | `godot/assets/characters/npc/death/2d/spritesheet.png(.import)` |
| `godot/assets/sprites/fairy_cartographer_spritesheet.png(.import)` | `godot/assets/characters/npc/fairy_cartographer/2d/spritesheet.png(.import)` |
| `godot/assets/sprites/landlord_spritesheet.png(.import)` | `godot/assets/characters/npc/landlord/2d/spritesheet.png(.import)` |
| `godot/assets/sprites/merchant_spritesheet.png(.import)` | `godot/assets/characters/npc/merchant/2d/spritesheet.png(.import)` |
| `godot/assets/sprites/whiskers_spritesheet.png(.import)` | `godot/assets/characters/npc/whiskers/2d/spritesheet.png(.import)` |
| `godot/assets/sprites/npc_bard_spritesheet.png(.import)` | `godot/assets/characters/npc/bard/2d/spritesheet.png(.import)` |
| `godot/assets/sprites/npc_guard_spritesheet.png(.import)` | `godot/assets/characters/npc/guard/2d/spritesheet.png(.import)` |
| `godot/assets/sprites/npc_sailor_spritesheet.png(.import)` | `godot/assets/characters/npc/sailor/2d/spritesheet.png(.import)` |
| `godot/assets/sprites/npc_urchin_spritesheet.png(.import)` | `godot/assets/characters/npc/urchin/2d/spritesheet.png(.import)` |

Delete `godot/assets/sprites/` (empty after).

## 4. Moves — `design/charcters/`

| From | To |
|---|---|
| `design/charcters/3d/cc0_source/` | `design/charcters/_pipeline/cc0_source/` |
| `design/charcters/3d/mixamo_raw/README.md` | `design/charcters/_pipeline/mixamo_raw_README.md` (becomes generic pipeline doc) |
| `design/charcters/3d/mixamo_raw/aristotle/` | `design/charcters/aristotle/animations/mixamo_raw/` |
| `design/charcters/3d/mixamo_raw/nine_lives/` | `design/charcters/crew/nine_lives/animations/mixamo_raw/` |
| `design/charcters/3d/aristotle_3d.glb` | `design/charcters/aristotle/3d/source.glb` |
| `design/charcters/3d/aristotle_t_pose_3d.fbx` | `design/charcters/aristotle/3d/t_pose.fbx` |
| `design/charcters/3d/aristotle_t_pose_3d.inspect.json` | `design/charcters/aristotle/3d/t_pose.inspect.json` |
| `design/charcters/3d/preview_mixamo/aristotle_t_pose_3d_*.png` | `design/charcters/aristotle/3d/previews/t_pose_*.png` |
| `design/charcters/3d/dave_3d.glb` | `design/charcters/dave/3d/source.glb` |
| `design/charcters/3d/nine_lives_clean.fbx` | `design/charcters/crew/nine_lives/3d/clean.fbx` |
| `design/charcters/3d/nine_lives_clean.glb` | `design/charcters/crew/nine_lives/3d/clean.glb` |
| `design/charcters/3d/nine_lives_clean.prep.json` | `design/charcters/crew/nine_lives/3d/clean.prep.json` |
| `design/charcters/3d/preview/nine_lives_clean_*.png` | `design/charcters/crew/nine_lives/3d/previews/source_*.png` |
| `design/charcters/3d/preview_rigged/nine_lives_rigged_*.png` | `design/charcters/crew/nine_lives/3d/previews/rigged_*.png` |
| `design/charcters/3d/preview_source/UAL1_Standard_*.png` | `design/charcters/_pipeline/cc0_source/previews/*.png` |
| `design/charcters/3d/no_tail_3d.glb` | `design/charcters/crew/no_tail/3d/source.glb` |
| `design/charcters/3d/preview_animations/` (empty) | deleted |
| `design/charcters/crew/` (empty root) | deleted |

Delete `design/charcters/3d/` (empty after).

## 5. Code / data updates

### `godot/scripts/ui/dialogue/portrait_manager.gd` lines 14-27

```gdscript
const CHARACTER_PORTRAITS := {
    "aristotle":          "res://assets/characters/aristotle/2d/head.png",
    "dave":               "res://assets/characters/dave/2d/head.png",
    "death":              "res://assets/characters/npc/death/2d/head.png",
    "fairy_cartographer": "res://assets/characters/npc/fairy_cartographer/2d/portrait.png",
    "nine_lives":         "res://assets/characters/crew/nine_lives/2d/portrait.png",
    "no_tail":            "res://assets/characters/crew/no_tail/2d/portrait.png",
    "silky":              "res://assets/characters/crew/silky/2d/portrait.png",
    "blood_paw":          "res://assets/characters/crew/blood_paw/2d/portrait.png",
    "charlie":            "res://assets/characters/crew/charlie/2d/portrait.png",
    "bombardier":         "res://assets/characters/crew/bombardier/2d/portrait.png",
    "luna":               "res://assets/characters/crew/luna/2d/portrait.png",
    "thistle":            "res://assets/characters/crew/thistle/2d/portrait.png",
}
```

### `godot/data/characters/protagonists.json`

- line 17: `"res://assets/characters/aristotle_head.png"` → `"res://assets/characters/aristotle/2d/head.png"`
- line 82: `"res://assets/characters/dave_head.png"` → `"res://assets/characters/dave/2d/head.png"`

### `godot/data/characters/crew_members.json`

Eight `"portrait"` fields rewritten to the new per-character paths (nine_lives, no_tail, silky, blood_paw, charlie, bombardier, luna, thistle).

### `godot/scenes/cutscenes/no_tail_cutscene.tscn` lines 8-9

- `res://assets/characters/aristotle_3d.glb` → `res://assets/characters/aristotle/3d/source.glb`
- `res://assets/characters/no_tail_3d.glb` → `res://assets/characters/crew/no_tail/3d/source.glb`

### `godot/scripts/characters/animation_preview_controller.gd` line 18

- `res://assets/characters/crew/nine_lives_rigged.glb` → `res://assets/characters/crew/nine_lives/3d/rigged.glb`

### `godot/scripts/ui/planet_screen.gd` lines 79-80, `planet_surface.gd` lines 185-186 and 635-645

The `"res://assets/sprites/%s_spritesheet.png" % pid` template needs to resolve per-character. Proposed helper in each file:

```gdscript
func _spritesheet_path(char_id: String) -> String:
    # Protagonist lookup first, then crew, then npc — order matches
    # the directory layout under assets/characters/.
    for prefix in ["res://assets/characters/%s/2d/spritesheet.png",
                   "res://assets/characters/crew/%s/2d/spritesheet.png",
                   "res://assets/characters/npc/%s/2d/spritesheet.png"]:
        var p := prefix % char_id
        if ResourceLoader.exists(p):
            return p
    return "res://assets/characters/aristotle/2d/spritesheet.png"
```

Apply at every `res://assets/sprites/*` site (four in `planet_surface.gd`, one in `planet_screen.gd`). The hard-coded NPC fallbacks (`npc_guard`, `npc_urchin`, etc.) become `guard`, `urchin` under the new layout.

### All 15 `godot/resources/*_spriteframes.tres`

Each `ext_resource` path rewritten to its new per-character spritesheet location. This is the only textual edit — UIDs in the `.import` files are preserved by `git mv`, so no re-import dialog.

### `godot/tools/validate_rigged_glb.gd` lines 9, 13

- Comment example path and `DEFAULT_TARGET` updated to `res://assets/characters/crew/nine_lives/3d/rigged.glb`.

### `tools/blender-dev/retarget_to_cc0_rig.py` lines 23-28

Example paths in docstring updated to new locations (design-side).

### Docs

- `docs/CHARACTER_PIPELINE.md` — all path examples updated.
- `tools/blender-dev/README.md` — ditto.
- `docs/MASTER_PLAN.md`, `docs/REFACTORING_PLAN.md`, `docs/architecture/CODE_REVIEW.md`, `docs/changelog/CHANGELOG.md` — occurrences updated + changelog entry added.
- `design/charcters/_pipeline/mixamo_raw_README.md` — merge command examples updated.

Worktree copy `/.claude/worktrees/stoic-mclaren/` is NOT touched. That's a separate branch; it'll be updated whenever that branch rebases on main.

## 6. Validation steps (after all edits)

1. `godot --headless --path godot --quit --verbose` — confirms no resource-load errors on boot.
2. `godot --headless --path godot --script res://tools/validate_rigged_glb.gd -- res://assets/characters/crew/nine_lives/3d/rigged.glb` — rigged validator passes.
3. Same for Aristotle.
4. Load `res://scenes/cutscenes/no_tail_cutscene.tscn` headless → no missing ext_resources.
5. Grep: `rg "assets/(sprites|characters/(aristotle|dave)\.png|characters/(aristotle|dave|death|no_tail)_|characters/crew/\w+\.png|characters/support)" godot/` returns zero hits.

## 7. Commit

One atomic commit: `chore(assets): reorganize character assets into per-character 2d/3d folders`.

---

**Sign-off needed before execution.** Anything you want changed in the layout or move list, flag now.
