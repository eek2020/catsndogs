# Refactoring Plan — UI Decomposition & Test Framework

**Created:** 2026-04-07
**Source:** Code Review Issues #18, #19, #20, #22
**Status:** In progress — Phases 1, 2, 3 done (2026-04-16); Phase 4 pending (Sprint 6); Phases 5–6 pending.

**Phase status summary:**

| Phase | Scope | Status |
| --- | --- | --- |
| 1 | Test framework (GUT) | **Done 2026-04-16** — 121 tests across 14 files (Sprint 5b added crew-morale wiring coverage) |
| 2 | `combat_ui.gd` decomposition (Issue #18) | **Done 2026-04-16** (Sprint 3b) — 585→399 + `scripts/ui/combat/` + `CombatViewModel` |
| 3 | `star_map_screen.gd` decomposition (Issue #19) | **Done 2026-04-16** (Sprint 5a) — 1,092→375 + `scripts/ui/star_map/` + `StarMapViewModel` |
| 4 | `dialogue_ui.gd` decomposition (Issue #20) | Pending — NEXT_STEPS Sprint 6 |
| 5 | 2.5D / 3D asset pipeline + cutscene expansion | Pending — NEXT_STEPS Sprint 7 |
| 6 | Art direction resolution | **Partial** — guide updated + Track A/B committed (NEXT_STEPS Sprint 2); sprite pilot redraw pending artist |

---

## Phase 1: Test Framework Setup (Issue #22) — DONE 2026-04-16

**Landed in Sprint 1.** GUT 9.6.0 vendored at `godot/addons/gut/`. Test suite grew across subsequent sprints:

- **Sprint 1** — 9 tests (MathUtils, EncounterOutcome, AstralHazard hull death + 4 critical-bug regressions).
- **Sprint 3a** — 22 tests (`test_navigation_view_model.gd`).
- **Sprint 3b** — 31 tests (`test_combat_view_model.gd`, `test_combat_layout.gd`, `test_combat_logic.gd`).
- **Sprint 3c** — 15 tests (`test_input_map_collisions.gd`, `test_dialogue_manager_bark.gd`, `test_portrait_cache.gd`, `test_scene_transition_handoff.gd`).
- **Sprint 5a** — 20 tests (`test_star_map_view_model.gd`).
- **Sprint 5b** — 24 tests (`test_crew_morale_combat_wiring.gd`, `test_crew_morale_trade_wiring.gd`).

**Total: 121 tests across 14 files, all green.** Headless runner pinned in `docs/architecture/CODE_REVIEW.md` §8.

Original phase details preserved below for reference.

**Effort:** 1–2 sessions | **Priority:** Do first — enables safe refactoring

### 1.1 Install GUT (Godot Unit Test)

GUT is the most mature GDScript test framework. GdUnit4 is an alternative but GUT has wider adoption.

```bash
# Install via AssetLib or git submodule:
git submodule add https://github.com/bitwes/Gut.git godot/addons/gut
```

Then enable the plugin in `Project > Project Settings > Plugins`.

### 1.2 Create test directory structure

```text
godot/tests/
├── unit/
│   ├── test_condition_evaluator.gd
│   ├── test_combat_system.gd
│   ├── test_stat_evaluator.gd
│   ├── test_karma_system.gd
│   ├── test_economy_system.gd
│   ├── test_math_utils.gd
│   └── test_exploration_system.gd
├── integration/
│   └── test_save_load_round_trip.gd
└── .gutconfig.json
```

### 1.3 Priority test targets (pure-logic RefCounted classes)

These classes have zero scene-tree dependencies and can be tested immediately:

| Class | Why | Key tests |
| ----- | --- | --------- |
| `ConditionEvaluator` | New code, central to encounter/mission gating | All condition types: arc, stat, karma, flags, `!null` sentinel |
| `CombatSystem` | Recently decoupled, static functions | Damage calc with/without bonuses, dodge chance bounds, crit multiplier |
| `StatEvaluator` | Refactored to property access | `_get_stat`, `set_stat`, `get_highest_stat`, `check_threshold` |
| `MathUtils` | New utility | `weighted_pick` with zero weights, single item, empty array |
| `EconomySystem` | Complex branching | Buy/sell price, repair cost with bonuses, sell ratio |
| `ExplorationSystem` | Critical persistence path | `get_state_dict` → `load_state_dict` round-trip, region discovery |
| `FactionSystem` | Cascade rules | `change_reputation` with cascade, clamping to [-100, 100] |

### 1.4 Example test skeleton

```gdscript
# godot/tests/unit/test_condition_evaluator.gd
extends GutTest

var game_state: GameStateData

func before_each() -> void:
    game_state = GameStateData.new()
    game_state.current_arc = "arc_1"
    game_state.player_character = Character.new()
    game_state.player_character.cunning = 5
    game_state.player_character.combat_skill = 8

func test_current_arc_match() -> void:
    assert_true(ConditionEvaluator.evaluate({"current_arc": "arc_1"}, game_state))

func test_current_arc_mismatch() -> void:
    assert_false(ConditionEvaluator.evaluate({"current_arc": "arc_2"}, game_state))

func test_min_stat_passes() -> void:
    assert_true(ConditionEvaluator.evaluate({"min_combat_skill": 5}, game_state))

func test_min_stat_fails() -> void:
    assert_false(ConditionEvaluator.evaluate({"min_cunning": 10}, game_state))

func test_story_flag_null_check() -> void:
    game_state.story_flags["quest_started"] = true
    assert_true(ConditionEvaluator.evaluate({"quest_started": "!null"}, game_state))

func test_empty_conditions_pass() -> void:
    assert_true(ConditionEvaluator.evaluate({}, game_state))
```

### 1.5 CI integration (optional)

Add a headless test run command:

```bash
godot --headless --path godot -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit
```

---

## Phase 2: combat_ui.gd Decomposition (Issue #18) — DONE 2026-04-16 (Sprint 3b)

**Actual outcome:** `combat_ui.gd` 585 → **399-line orchestrator** + 4 focused components under `scripts/ui/combat/`:

- `scripts/ui/combat/combat_layout.gd` — pure `compute(viewport, design_w, design_h) -> Dictionary` (unit-testable)
- `scripts/ui/combat/combat_logic.gd` — `resolve_player_attack` / `resolve_enemy_attack` / `resolve_flee` returning result dicts
- `scripts/ui/combat/combat_animations.gd` — Node child owning laser Line2D + shake timers
- `scripts/ui/combat/health_bar.gd` — reusable steampunk brass-frame renderer

Plus `scripts/ui/view_models/combat_view_model.gd` (`has_state`, `sync_player_hull`, `apply_victory_loot` with null-guards). `combat_ui.gd` GameSession refs 4 → 0. Tests: `test_combat_view_model.gd` (8), `test_combat_layout.gd` (12), `test_combat_logic.gd` (11). Full details: CHANGELOG entry `2026-04-16 — Sprint 3b`.

Original phase plan preserved below for reference.

**Effort:** 1 session | **Original:** 586 lines | **Target:** ~150 lines per component

### Analysis of current responsibilities

The file handles four distinct concerns:

1. **Layout** (lines 149–234) — maps design coordinates to screen, positions all nodes
2. **Combat logic** (lines 266–392) — attack, flee, enemy turn, result, loot
3. **Animations** (lines 394–508) — laser beams, ship shake, pulsing labels
4. **Health bar drawing** (lines 510–551) — custom `_draw()` for steampunk bars

### Proposed structure

```text
scripts/ui/combat/
├── combat_ui.gd              # Main controller (~150 lines) — wires sub-components
├── combat_layout.gd          # Layout calculations, coordinate mapping
├── combat_logic.gd           # Turn logic, damage, flee, result state
├── combat_animations.gd      # Laser beams, ship shake, pulsing effects
└── health_bar.gd             # Reusable HealthBar Control node with _draw()
```

### Extraction steps

1. **Create `health_bar.gd`** — extract `_draw_health_bar()` into a reusable `HealthBar` Control
   - Properties: `current_hp: int`, `max_hp: int`, `bar_color: Color`
   - Owns the steampunk frame drawing
   - Can be reused in star base / planet screens later

2. **Create `combat_layout.gd`** — pure data class
   - Takes viewport size + design constants → produces `CombatLayoutData` (positions, rects, scale)
   - No node references — just math
   - Easily unit-testable

3. **Create `combat_animations.gd`** — extends Node, added as child
   - `fire_laser(from, to, color, hit)`, `apply_shake(ship_tex, duration)`
   - Owns `LaserBeam`, `LaserGlow` Line2D references
   - Emits `animation_finished` signal

4. **Create `combat_logic.gd`** — extends RefCounted
   - `execute_player_attack()`, `execute_enemy_attack()`, `attempt_flee()`
   - Returns result dictionaries (no UI coupling)
   - CombatSystem calls move here from combat_ui
   - Unit-testable

5. **Slim `combat_ui.gd`** — orchestrator only
   - Holds references to sub-components
   - Connects signals between them
   - Handles input routing

### Safety checks

- Write tests for `CombatSystem.calculate_damage` and `dodge_chance` first (Phase 1)
- Extract one component at a time, run game to verify after each extraction
- Keep the original `combat_ui.gd` in git history for rollback

---

## Phase 3: star_map_screen.gd Decomposition (Issue #19) — DONE 2026-04-16 (Sprint 5a)

**Actual outcome:** `star_map_screen.gd` 1,092 → **375-line orchestrator** + 3 layer components under `scripts/ui/star_map/`:

- `scripts/ui/star_map/star_map_galaxy_layer.gd` — 367 lines; galaxy graph, connections, fog arcs, danger pips, legend, info box, travel-confirm dialog.
- `scripts/ui/star_map/star_map_region_layer.gd` — 320 lines; circular sector view with fog-of-war + POIs.
- `scripts/ui/star_map/star_map_local_layer.gd` — 258 lines; player-centered zoomed scan.

Plus `scripts/ui/view_models/star_map_view_model.gd` (184 lines, null-guarded wrappers over `game_state`/`star_map_system`/`exploration` + `travel_to_region` + `set_world_entry_region`). `star_map_screen.gd` GameSession refs 23 → 0. Layer components have 0 GameSession refs. Tests: `test_star_map_view_model.gd` (20). Full details: CHANGELOG entry `2026-04-16 — Sprint 5a`.

The original phase proposed `map_utils.gd` + three renderers; we collapsed `map_utils` into per-layer `const` blocks and the VM, and renamed "renderer" → "layer" to match the in-game terminology (Galaxy / Region / Local layers of the Celestial Codex).

Original phase plan preserved below for reference.

**Effort:** 2 sessions (actual: 1) | **Original:** 1,093 lines | **Target:** ~200 lines per renderer

### Star map responsibilities

The file has clear layer boundaries already marked with comment headers:

1. **Galaxy layer** (lines 101–383) — node graph, connections, legend, info box
2. **Region layer** (lines 389–631) — circular map, fog rendering, POIs, legend
3. **Local layer** (lines 637–820) — player-centered radar, nearby objects
4. **Input handling** (lines 850–996) — per-layer input dispatch
5. **Layer transitions** (lines 925–955) — zoom in/out between layers
6. **Shared helpers** (lines 827–844) — navigation controller, display names

### Star map target structure

```text
scripts/ui/star_map/
├── star_map_screen.gd          # Main controller (~200 lines) — layer dispatch + transitions
├── galaxy_layer_renderer.gd    # Galaxy layer draw + input + legend
├── region_layer_renderer.gd    # Region layer draw + fog + input + legend
├── local_layer_renderer.gd     # Local layer draw + input
└── map_utils.gd                # Shared helpers (display names, fog math)
```

### Star map extraction steps

1. **Create `map_utils.gd`** — static helpers
   - `_get_region_display_name()`, `_find_navigation_controller()`
   - Shared constants: `MAP_PADDING`, `POI_BLIP_SIZE`, `TYPE_COLORS`, `LEGEND_WIDTH`

2. **Create `galaxy_layer_renderer.gd`** — extends RefCounted
   - Constructor takes `map_canvas: Control` reference
   - `draw(game_state, star_map_system, exploration_system)` — main entry
   - Contains galaxy legend, info box, dashed-line helpers
   - `handle_input(event)` → returns action enum
   - `move_selection(direction)`, `get_selected_region()`

3. **Create `region_layer_renderer.gd`** — extends RefCounted
   - `draw(game_state, star_map_system, region_id, bounds)`
   - Contains fog rendering, POI drawing, region legend
   - `handle_input(event)` → returns action enum

4. **Create `local_layer_renderer.gd`** — extends RefCounted
   - `draw(game_state, star_map_system, player_pos)`
   - Radar-style rendering
   - `handle_input(event)` → returns action enum

5. **Slim `star_map_screen.gd`** — layer manager
   - Holds current layer enum, dispatches draw/input
   - Manages layer transitions (drill/zoom)
   - Owns shared state (selected region, backdrop textures)

### Key constraint

All three renderers draw onto the same `map_canvas: Control` using `map_canvas.draw_*()` calls. The renderers receive the canvas as a parameter — they don't own it.

---

## Phase 4: dialogue_ui.gd Decomposition (Issue #20)

**Effort:** 1–2 sessions | **Current:** 632 lines | **Target:** ~200 lines per handler

### Dialogue responsibilities

The file has two distinct dialogue modes with interleaved code:

1. **Legacy single-step** (lines 348–419) — one description + choice buttons → outcome
2. **Multi-step branching** (lines 142–276) — step-by-step dialogue with speaker switching
3. **Portrait management** (lines 290–370) — loading, white-bg removal, highlighting
4. **Combat transitions** (lines 554–632) — building enemy ships, pushing combat overlay
5. **Shared UI helpers** (lines 448–525) — typewriter, description collapse, button creation

### Dialogue target structure

```text
scripts/ui/dialogue/
├── dialogue_ui.gd                  # Main controller (~200 lines) — shared UI, dispatch
├── legacy_dialogue_handler.gd      # Legacy single-step encounter flow
├── branching_dialogue_handler.gd   # Multi-step dialogue flow + step map
├── portrait_manager.gd             # Portrait loading, white-bg removal, highlighting
└── combat_transition.gd            # Enemy ship construction, overlay push
```

### Dialogue extraction steps

1. **Create `portrait_manager.gd`** — extends RefCounted
   - `setup_two_portraits(encounter, left_rect, right_rect, ...)`
   - `setup_legacy_portrait(encounter, left_rect, ...)`
   - `highlight_speaker(speaker_id)`
   - Contains `CHARACTER_PORTRAITS` dictionary and `_remove_near_white_bg()`

2. **Create `combat_transition.gd`** — extends RefCounted
   - `start_combat(encounter, game_state, scene_tree)`
   - `start_combat_from_encounter(encounter, game_state, scene_tree)`
   - Contains enemy ship construction and overlay management
   - No portrait/dialogue coupling

3. **Create `legacy_dialogue_handler.gd`** — extends RefCounted
   - `setup(encounter, choices_container, ...)`
   - `_on_choice_selected(index)`
   - Emits signals: `dialogue_finished`, `combat_requested`
   - Contains crew recruitment check logic

4. **Create `branching_dialogue_handler.gd`** — extends RefCounted
   - `setup(encounter)`, `show_step(index)`
   - Manages `_step_map`, `_steps_visited`, `MAX_STEPS`
   - Emits signals: `dialogue_finished`, `combat_requested`, `step_advanced`

5. **Slim `dialogue_ui.gd`** — shared UI host
   - Owns the scene-tree nodes (`panel`, `description_label`, etc.)
   - Typewriter effect, description management
   - Dispatches to legacy or branching handler based on `encounter.has_dialogue_steps()`
   - Listens for handler signals to trigger combat transitions or close

### Remaining cleanup

Line 506 in `dialogue_ui.gd` still has a Python `"""..."""` docstring that was missed in Issue #4:

```gdscript
"""Make bright neutral background pixels transparent, with soft feathering."""
```

Fix this during extraction into `portrait_manager.gd`.

---

## Phase 5: 2.5D/3D Asset Pipeline & Cutscene Expansion

**Effort:** 2–3 sessions | **Priority:** Parallel with UI refactoring

### Current 3D inventory

The project already has significant 3D work underway:

| Asset | Path | Size | Notes |
| ----- | ---- | ---- | ----- |
| Aristotle 3D model | `assets/characters/aristotle_3d.glb` | 36 MB | High-poly, textured |
| No Tail 3D model | `assets/characters/no_tail_3d.glb` | 36 MB | High-poly, textured |
| Outpost environment | `assets/cutscenes/no_tail_outpost.glb` | 260 KB | Low-poly environment |
| Character textures | `assets/characters/*_3d_texture_*.png` | ~20 MB each | Baked textures |
| Camera paths | `data/cutscenes/camera_path.json` | 3 KB | 9 camera keyframes |
| Dialogue data | `data/cutscenes/no_tail_dialogue.json` | 11 KB | Full branching cutscene |

The cutscene pipeline (`CutsceneManager` → `CutsceneDialogueUI` → `CameraController`) is functional for the No Tail recruitment scene. The 2D world layer (`world.tscn`, `player_controller.gd`, `npc_controller.gd`) is also emerging.

### 5.1 Establish asset directory conventions

Currently 3D and 2D assets are mixed in `assets/characters/`. Separate them:

```text
assets/
├── characters/
│   ├── 2d/                    # Existing 2D portraits, sprite sheets
│   │   ├── aristotle.png
│   │   ├── aristotle_head.png
│   │   └── crew/
│   └── 3d/                    # GLB models + textures
│       ├── aristotle/
│       │   ├── aristotle.glb
│       │   └── aristotle_texture.png
│       └── no_tail/
│           ├── no_tail.glb
│           └── no_tail_texture.png
├── environments/
│   ├── 2d/                    # Existing backgrounds, tilesets
│   └── 3d/                    # GLB environments for cutscenes
│       └── outposts/
│           └── no_tail_outpost.glb
├── cutscenes/                 # Moved from assets/cutscenes — co-locate with environments/3d
└── ships/                     # Existing 2D ship sprites (add 3d/ when ready)
```

**Note:** Moving assets requires updating all `.import` files and scene references. Use `tools/import_assets.sh` pattern or a bulk-rename script.

### 5.2 Optimise 3D model sizes

The character `.glb` files are **36 MB each** — very large for a game that's primarily 2D. Before adding more:

- **LOD variants:** Export low-poly cutscene versions (target < 5 MB) alongside high-poly source
- **Texture compression:** The 20 MB PNGs should be converted to `.basis` or `.ktx2` (Godot's GPU-compressed formats) via import settings
- **Naming convention:** `<character>_lod0.glb` (hero), `<character>_lod1.glb` (cutscene), `<character>_lod2.glb` (distant)
- **Consider `.tres` material libraries:** Share materials across characters to reduce duplication

### 5.3 Cutscene authoring pipeline

The existing `CutsceneManager` is a good foundation. To scale to more cutscenes:

**a) Cutscene data schema**

Formalise the JSON schema in `data/cutscenes/` so new cutscenes are consistent:

```text
data/cutscenes/
├── _schema.json               # JSON Schema for validation
├── no_tail_dialogue.json       # Existing
├── camera_path.json            # Existing — consider per-cutscene camera files
├── arc2_betrayal/
│   ├── dialogue.json
│   └── camera_path.json
└── arc4_finale/
    ├── dialogue.json
    └── camera_path.json
```

**b) Reusable cutscene scene template**

The current `no_tail_cutscene.tscn` + `cutscene_scene.gd` builds the interior room, burn marks, and lighting programmatically (~400 lines). For future cutscenes:

- Extract `MaterialApplicator`, interior-building, and burn-mark logic into **reusable utilities** in `scripts/systems/cutscene/`
- Create a **cutscene template scene** (`scenes/cutscenes/cutscene_template.tscn`) with pre-wired `CutsceneManager` + `CutsceneDialogueUI` + `CameraController`
- Each new cutscene just needs: a `.glb` environment, a dialogue JSON, a camera JSON, and a thin scene script

**c) Camera path editor (stretch goal)**

Currently camera paths are hand-authored in JSON. A simple in-editor tool that lets you place camera markers in the 3D viewport and exports to the JSON format would speed up cutscene authoring significantly.

### 5.4 2.5D rendering strategy

The game is currently 2D with 3D cutscenes. If 2.5D is planned for gameplay:

- **Option A: 3D characters on 2D backgrounds** (Paper Mario style) — render 3D models with orthographic camera, keep 2D UI and backgrounds. Lowest risk.
- **Option B: Full 3D world layer** — the `world/world.tscn` already uses 2D `CharacterBody2D`. Migrating to 3D means replacing `CharacterBody2D` with `CharacterBody3D`, adding a 3D camera, and building 3D tilesets/environments.
- **Option C: Pre-rendered 2.5D** — render 3D models to sprite sheets (isometric or side-view) and keep the engine 2D. Maintains performance on GL Compatibility renderer.

**Recommendation:** Start with **Option A** for cutscenes (already working) and port to 2.5D gameplay incrementally if needed. The cutscene pipeline proves the 3D rendering path works in the project.

### 5.5 Asset manifest

Create an `ASSETS_3D.md` (or expand `ASSETS.md`) tracking:

- All 3D models with poly count, texture resolution, file size
- Source files (Blender? Which version?)
- Export settings used
- Which cutscenes/scenes reference each asset
- LOD status (has LOD variants or not)

---

## Phase 6: Art Direction Resolution

**Effort:** Design decision + 1 session | **Priority:** Before major new asset creation

The art direction guide (`design/art_direction/art_direction_guide.md`) currently says:

> *"Style: 2D pixel art or clean vector sprites (to be decided in prototype phase)"*

But the project has evolved beyond prototype — it has:
- 2D vector-style UI with steampunk theme (`ThemeBuilder`)
- 2D sprite portraits and ship images
- 3D character models and environment GLBs for cutscenes
- A 2D top-down world layer (`world.tscn`)

### Decisions needed

1. **Core gameplay rendering:** Stays 2D, goes 2.5D, or goes full 3D?
2. **Cutscene standard:** All future cutscenes use 3D (like No Tail), or some stay 2D (like the text crawl `cutscene.gd`)?
3. **Character asset standard:** Do all recruitable characters need 3D models, or only story-critical ones?
4. **Ship rendering:** Do ships get 3D models (for combat?), or stay 2D sprites?
5. **Performance target:** GL Compatibility renderer limits 3D quality — is that acceptable, or will the project move to Forward+/Vulkan?

### Deliverable

Update `design/art_direction/art_direction_guide.md` with:
- Resolved rendering strategy per game layer (navigation, combat, dialogue, cutscenes, world)
- Asset specification per character tier (protagonist = 3D + 2D, crew = 2D only, etc.)
- Target poly budgets and texture sizes for 3D assets
- Cutscene complexity tiers (full 3D cinematic vs. 2D dialogue-over-portrait vs. text crawl)

---

## Sprint Schedule

This is the original sprint map from the April 7 plan. The **actual** sprint sequence landed as **NEXT_STEPS.md §2**, which sliced the work finer (Sprint 3 → 3a/3b/3c; Sprint 5 → 5a/5b/5c) and folded in a parallel art track. Both sprint indexings are kept aligned inside MASTER_PLAN.md §7.

| Sprint (this plan) | Phase | Deliverable | Status |
| --- | --- | --- | --- |
| 1 | 1 | GUT installed, ConditionEvaluator/CombatSystem/StatEvaluator/MathUtils tests | **Done 2026-04-16** (NEXT_STEPS Sprint 1) |
| 2 | 2 | combat_ui decomposition + tests | **Done 2026-04-16** (NEXT_STEPS Sprint 3b) |
| 3 | 3 | star_map_screen decomposition | **Done 2026-04-16** (NEXT_STEPS Sprint 5a) |
| 4 | 4 | dialogue_ui decomposition + `"""..."""` fix | Pending — NEXT_STEPS Sprint 6 |
| 5 | 6 | Art direction resolution | **Partial** (guide updated; sprite pilot pending artist) — NEXT_STEPS Sprint 2 |
| 5 | 5.1–5.2 | Asset directory restructure + model optimisation | Pending — NEXT_STEPS Sprint 7 (3D cutscene modernisation) |
| 6 | 5.3–5.4 | Cutscene pipeline templates + 2.5D strategy | Pending — NEXT_STEPS Sprint 7 |
| 6 | 5.5 | 3D asset manifest documentation | Pending — NEXT_STEPS Sprint 7 |

---

## Risk Mitigation

- **Git branches:** Each phase on a dedicated feature branch (`refactor/combat-ui`, `refactor/star-map`, `refactor/dialogue-ui`, `asset/3d-pipeline`)
- **Incremental extraction:** Move one component at a time, test in-engine after each
- **Backward compatibility:** Keep the same public API on the main script — sub-components are internal
- **Scene files:** `combat.tscn`, `star_map.tscn`, `dialogue.tscn` node paths stay the same; new components are instantiated in code, not in the scene tree
- **No renames of root scripts:** The main `.gd` files keep their paths so `.tscn` references don't break
- **Asset moves are high-risk:** Godot tracks assets by `uid://` but also caches paths in `.import` files. Test thoroughly after any directory restructure. Consider doing asset moves in a dedicated branch with a full reimport.
- **3D model sizes:** The 36 MB GLBs and 20 MB textures will bloat the repo. Consider Git LFS for `*.glb` and large `*.png` files if not already enabled.

---

## Success Criteria

Status snapshot as of 2026-04-16 post-Sprint 5a.

- [x] All unit tests pass (GUT green) — **121/121**
- [ ] No file exceeds 250 lines after decomposition — `combat_ui.gd` 399, `star_map_screen.gd` 375, layer components 258–367; orchestrators still over 250 but well under the originals. `navigation.gd` 1,717 and `dialogue_ui.gd` 632 still pending.
- [x] Each new component has at least basic unit test coverage — all VMs + combat components covered; layer components exercised via VM tests.
- [x] Game runs identically before and after each phase — all orchestrators fall back to constructing a VM from the `GameSession` autoload in `_ready`, so no scene wiring changed.
- [x] No new autoload dependencies introduced.
- [ ] 3D assets separated from 2D assets with clear directory conventions — pending Sprint 7.
- [ ] Art direction guide updated with resolved rendering strategy — **partial** (Track A/B committed; 3D gameplay decision pending).
- [ ] Cutscene template scene created — pending Sprint 7.
- [ ] All 3D models have LOD variants under 5 MB for runtime use — pending Sprint 7.
- [ ] 3D asset manifest documenting all models, textures, and dependencies — pending Sprint 7.
