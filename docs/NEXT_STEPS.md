# Whisper Crystals — Next Steps

**Date:** 2026-04-16 (post-Sprint 5b)
**Status:** Active plan, reconciled with `docs/MASTER_PLAN.md` and `docs/architecture/CODE_REVIEW.md`.
**Scope:** What to do next, in order, across engineering, gameplay, and art.
**Relationship to other plans:**

- `docs/MASTER_PLAN.md` — authoritative roadmap and issue tracker. This file sequences a subset of that roadmap into "do next" form. It does not supersede MASTER_PLAN.
- `docs/architecture/CODE_REVIEW.md` — current review (enhanced 2026-04-16). Findings from §2, §6, §7 feed this plan directly.
- `docs/REFACTORING_PLAN.md` — detailed UI decomposition + test setup. Still authoritative for phase mechanics.
- `docs/PLAN.md` — task DAG template. Currently empty; becomes the working task list once Sprint N starts.

---

## 1. Two parallel tracks, running in lockstep

Most of the outstanding work falls into two independent tracks. They do not block each other and should run simultaneously.

### Track E — Engineering

Test safety (**done** Sprint 1), critical bugs (**done** Sprint 1), should-fix bugs (**done** Sprint 3c), UI god-scripts decomposed one at a time (combat **done** 3b, star_map **done** 5a, dialogue pending 6, navigation decomposition pending), UI↔GameSession coupling cut screen-by-screen via ViewModels (**in progress** — 3 of ~19 screens converted, 206→106 refs), and wire the dormant systems so the player can feel crew morale, hazards, realm control, and conquest (crew morale **done** 5b; astral hazards **retired** as stale tracker in 5b — already ticking at `navigation.gd:213`; realm control + faction conquest still pending 5c).

### Track A — Art

Commit to a single visual language, modernise world sprites to close the gap with the painted portraits and ship art, and extend the painterly portrait set to the full named cast.

The numbered sprints below fold both tracks into MASTER_PLAN's existing sprint structure.

---

## 2. Sprint schedule (next 6 sprints)

Each sprint is 1–2 focused sessions. Assume all sprints include: **test before merge + changelog entry + MASTER_PLAN §5 status update.**

### Sprint 1 — Safety net (critical, do first) — **DONE 2026-04-16**

**Track E only.** Matches MASTER_PLAN Sprint 1. Commits `fbb6362` (GUT vendor) + `b6d5c53` (fixes, tests, docs). Two of the four §5.2 bugs were stale-tracker entries already fixed in code (Mar-27 §2.1, §2.2); two were real (Apr-05 #1 dead field removed, Apr-05 #2 `combat_defeat` now emits on hull 0). GUT 9.6.0 vendored at `godot/addons/gut/`; 9/9 tests green via `godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit`.

| Task | Outcome | Reference |
| --- | --- | --- |
| Install GUT test framework | `godot/addons/gut/` present, plugin enabled, sample test passes | MASTER_PLAN 7.1, REFACTORING_PLAN Phase 1 |
| Unit-test `ConditionEvaluator`, `StatEvaluator`, `MathUtils`, `CombatSystem` | Green baseline to refactor against | REFACTORING_PLAN 1.3–1.4 |
| Fix: `trigger_encounter_id` never evaluated | Encounter chains work or field is removed | MASTER_PLAN §5.2 Apr-05 #1 |
| Fix: hull death not emitted from hazard damage | `combat_defeat` emitted when hazards reach 0 hull | MASTER_PLAN §5.2 Apr-05 #2 |
| Fix: null guard on `player_ship` in morale system | Hardened against early-game state | MASTER_PLAN §5.2 Mar-27 §2.1 |
| Fix: `dialogue_manager.push_overlay` API | Correct key passed, no instance leak | MASTER_PLAN §5.2 Mar-27 §2.2 |
| Regression test per critical fix | Each fix has a GUT test committed with it | Quality policy, MASTER_PLAN §4 |

**Exit criteria:** `godot -s addons/gut/gut_cmdln.gd` returns green locally; four critical bugs closed in MASTER_PLAN §5.2; CHANGELOG entry added.

### Sprint 2 — Art direction + sprite pilot (parallel with Sprint 1) — **PARTIAL 2026-04-16**

**Track A only.** Engineering-tractable rows done; sprite pilot still pending a human artist.

| Task | Outcome | Reference | Status |
| --- | --- | --- | --- |
| Update `design/art_direction/art_direction_guide.md` | "To be decided" line removed; committed to **Track A floor (64×64 native, 12–16 colours, shaded)** + **Track B aspirational (painterly portraits for named cast)** | CODE_REVIEW §6.4 | **Done** |
| Add reference-pin section | Stardew, Death's Door, Moonlighter, Eastward, Sea of Stars pinned as visual benchmarks | CODE_REVIEW §6.3 | **Done** |
| Pilot redraw: `aristotle_spritesheet.png` at 64×64 / 256×256 | Single sheet redrawn, runs in-game without rigging changes | CODE_REVIEW §6.4 step 2 | Pending artist |
| In-game parity screenshot | `aristotle.png` portrait and the new sprite placed side by side — same character, same palette, same silhouette | CODE_REVIEW §6.5 | Pending artist |

**Exit criteria:** art direction guide has no "to be decided" left **(done)**; one spritesheet redrawn; parity screenshot committed to `docs/qa/`.

### Sprint 3 — UI view-model layer (cut the coupling at the source)

**Track E.** Matches MASTER_PLAN Sprint 2 scope but adds the view-model layer that CODE_REVIEW §2.1 identifies as load-bearing. Sliced into three parts for safer iteration; 3a establishes the pattern, 3b applies it to a harder case, 3c is independent bugs.

**Sprint 3a — NavigationViewModel — DONE 2026-04-16.**

| Task | Outcome | Reference | Status |
| --- | --- | --- | --- |
| Create `godot/scripts/ui/view_models/` | Directory created; holds per-screen adapters | CODE_REVIEW §2.1 | **Done** |
| `NavigationViewModel` | ~30 methods covering navigation.gd's reads, actions, and system calls; two escape hatches (`star_map()`, `astral_hazards()`) for deep draw-loop access | Coupling inventory | **Done** |
| Convert `navigation.gd` to consume the VM via `initialize(vm)` | 73 → 0 direct `GameSession.` refs in navigation.gd; fallback to autoload in `_ready` keeps main.gd untouched | CODE_REVIEW §2.1 | **Done** |
| Tests for the VM | 22 tests using `SessionDouble` + per-system RefCounted doubles; full suite 31/31 green | Quality policy | **Done** |

**Sprint 3b — CombatViewModel + combat_ui decomposition — DONE 2026-04-16.**

| Task | Outcome | Reference | Status |
| --- | --- | --- | --- |
| `CombatViewModel` | `godot/scripts/ui/view_models/combat_view_model.gd`; narrow GameSession adapter (`has_state`, `sync_player_hull`, `apply_victory_loot`) with null-guards | — | **Done** |
| Decompose `combat_ui.gd` (585 → 5 files) | 585 → 399 orchestrator + 4 focused components (`combat_layout.gd`, `combat_logic.gd`, `combat_animations.gd`, `health_bar.gd`) under `scripts/ui/combat/` | MASTER_PLAN Sprint 2, REFACTORING_PLAN Phase 2 | **Done** |
| Tests for new combat components | 31 new tests across `test_combat_view_model.gd`, `test_combat_layout.gd`, `test_combat_logic.gd`; full suite 62/62 green | Quality policy | **Done** |

**Sprint 3c — should-fix bugs — DONE 2026-04-16.**

| Task | Outcome | Reference | Status |
| --- | --- | --- | --- |
| Fix: R-key collision (menu_select vs repair) | Stale tracker — `repair` had already been rebound R→T in Sprint 1. Broad `test_input_map_collisions.gd` regression guard added | MASTER_PLAN §5.3 Mar-27 §2.4 | **Done** |
| Fix: scene_transition tween after scene change | Post-scene-change work moved to persistent `GameSession.complete_scene_transition(...)`; `scene_transition.gd` no longer awaits on self after the swap | MASTER_PLAN §5.3 Mar-27 §2.3 | **Done** |
| Fix: `_show_bark` recursion | Dedicated `EventBus.npc_bark` signal — no longer reuses `exploration_event`, so `_on_exploration_event` is structurally incapable of re-entering | MASTER_PLAN §5.3 Mar-27 §2.5 | **Done** |
| Cache processed portrait textures | Static cache keyed by `resource_path` + thresholds in `dialogue_ui.gd._remove_near_white_bg`; O(w·h) work runs once per portrait per run | MASTER_PLAN §5.3 Apr-05 #7 | **Done** |

**Findings from 3c:** the broad input-collision regression test surfaced an unrelated existing collision — `pause` and `skip` both bound to ESC (keycode 4194305). Currently context-separated (pause is navigation/combat, skip is cutscene/intro_crawl) and whitelisted in the test; logged in MASTER_PLAN §5.3 for the Sprint 6 input-rebind work.

**Exit criteria:** `rg "GameSession\." godot/scripts/ui/navigation.gd` returns 0 **(done: 73 → 0)**; `rg "GameSession\." godot/scripts/ui | wc -l` ≤ 140 **(done: 206 → 129)**; combat_ui split into `scripts/ui/combat/` **(done: 585 → 399 + 4 components)**; four should-fix bugs closed **(done — 3c)**; full GUT suite **77/77** green (was 62/62; +15 regression tests across 4 new files).

### Sprint 4 — Sprite roll-out (the named cast)

**Track A.** Expands the Sprint 2 pilot across the named cast.

| Task | Outcome | Reference |
| --- | --- | --- |
| Redraw Dave spritesheet at 64×64 | Matches Aristotle pilot | CODE_REVIEW §6.4 step 3 |
| Redraw the 8 named crew (Silky, Whiskers, Nine Lives, Blood Paw, No Tail, Death, Fairy Cartographer, +1) | Full named cast at the new floor | — |
| Keep generic NPC sheets (bard, guard, sailor, urchin, landlord, merchant) at current resolution | Scope control | — |
| Add painterly portrait card for each named character | Track B extension — dialogue/cutscene overlays only | CODE_REVIEW §6.4 step 4 |
| Visual QA pass | Portrait ↔ sprite parity screenshots for each named character | CODE_REVIEW §6.5 |

**Exit criteria:** every named character has both a 64×64 spritesheet and a painterly portrait card; generic NPCs unchanged; no mid-sprint engineering regressions (verified by GUT).

### Sprint 5 — Star map decomposition + system wiring (gameplay gets teeth)

**Track E.** Matches MASTER_PLAN Sprint 3, plus the "wire the dormant systems" work from CODE_REVIEW §3. Sliced into 5a / 5b / 5c the same way Sprint 3 was sliced.

**Sprint 5a — StarMapViewModel + star_map_screen decomposition — DONE 2026-04-16.**

| Task | Outcome | Reference | Status |
| --- | --- | --- | --- |
| `StarMapViewModel` | `godot/scripts/ui/view_models/star_map_view_model.gd`; 184 lines; narrow GameSession adapter (has_state, current_region, player_position, star-map wrappers, POI accessors, exploration lookups, travel_to_region, set_world_entry_region). Session + system doubles shape the VM in tests. | MASTER_PLAN Sprint 3 | **Done** |
| Decompose `star_map_screen.gd` (1092 → 4 files) | 1092 → **375-line orchestrator** + 3 layer components (`star_map_galaxy_layer.gd` 367, `star_map_region_layer.gd` 320, `star_map_local_layer.gd` 258) under `scripts/ui/star_map/`. Each layer takes the VM at construction; orchestrator passes a per-frame context dict (elapsed, selected_region, backdrops, travel state, nav_pois). | MASTER_PLAN Sprint 3, REFACTORING_PLAN Phase 3 | **Done** |
| Tests for the VM | 20 tests in `test_star_map_view_model.gd` using SessionDouble + RefCounted doubles for star_map_system and exploration. Covers state/POI/exploration reads, travel action, world-entry meta write. | Quality policy | **Done** |

**Sprint 5b — Wire dormant systems — DONE 2026-04-16.**

| Task | Outcome | Reference | Status |
| --- | --- | --- | --- |
| Wire crew morale into `CombatSystem.calculate_damage` and `EconomySystem.trade` | `calculate_damage` now takes a `morale_modifier` parameter applied to effective firepower; `EconomySystem.get_buy_price`/`get_sell_price`/`buy_crystals`/`sell_crystals` all take it too. Sell side uses `2.0 - m` so low morale hurts the player on both buy and sell. `CombatViewModel.combat_morale_modifier()` routes the value from the session; `trade_screen.gd` fetches via `GameSession.crew_morale.get_trade_modifier`. | CODE_REVIEW §3 | **Done** |
| Apply astral hazards during navigation tick | **Stale tracker** — already wired. `navigation.gd:213` has called `_update_astral_hazards(dt)` every frame since the hazard feature shipped (entropy timer, collision detection, status HUD, off-course drift all active). Retired from the active list during Sprint 5b audit. | CODE_REVIEW §3 | **Done** (stale) |
| Regression tests | 24 tests across `test_crew_morale_combat_wiring.gd` (12) + `test_crew_morale_trade_wiring.gd` (12). Covers VM null-guards, morale-scales-damage math, MoraleDouble and live `CrewMoraleSystem` integration paths; trade covers buy/sell directionality + default-param backwards compatibility + composed karma×morale. | Quality policy | **Done** (121/121 green) |

**Sprint 5c — Dock gating, conquest surfacing, data/HUD polish (pending).**

| Task | Outcome | Reference |
| --- | --- | --- |
| Gate docking via `realm_control_system.controlling_faction` + reputation | Low-rep players locked out of hostile stations | CODE_REVIEW §3 |
| Surface conquest actions as visible world changes | Distress spawns / blockades / price shifts | CODE_REVIEW §3 |
| Fix: DataLoader cache invalidation + redundant calls | MASTER_PLAN §5.3 Apr-05 #4, #12 | — |
| HUD: segmented hull bar, objective on top bar, morale pip | CODE_REVIEW §4.6 | — |

**Exit criteria:** `rg "GameSession\." godot/scripts/ui/star_map_screen.gd` returns 0 **(done: 23 → 0)**; `rg "GameSession\." godot/scripts/ui | wc -l` ≤ 110 **(done: 129 → 106)**; `star_map_screen.gd` ≤ 400 lines **(done: 1092 → 375)**; crew morale bends combat damage + trade prices with regression tests (**done 5b**); astral hazards drive navigation tick (**done — stale tracker, already wired**); HUD shows objective without opening mission log (5c pending); `realm_control_*` + `faction_conquest_*` emissions observable in a 20-minute session (5c pending).

### Sprint 6 — Dialogue decomposition + onboarding + save slots

**Track E.** Matches MASTER_PLAN Sprint 4, plus onboarding/accessibility basics.

| Task | Outcome | Reference |
| --- | --- | --- |
| `DialogueViewModel` + decompose `dialogue_ui.gd` (632 → 5 files) | As per REFACTORING_PLAN Phase 4 | MASTER_PLAN Sprint 4 |
| Tutorial encounter (first-navigation scripted path) | New players get a concrete goal within 30s | CODE_REVIEW §4.1 |
| Input rebind panel in `settings_screen.gd` | Per-action rebinding via `InputMap` | CODE_REVIEW §4.2 |
| Controller support — additive JoyButton events in `project.godot` | Plug-and-play gamepad | CODE_REVIEW §4.2 |
| Multiple save slots | `pause_menu.gd` no longer hardcodes slot 0 | CODE_REVIEW §4.3 |
| Game feel: camera shake, hit flash, audio ducking | CODE_REVIEW §4.5 | — |

**Exit criteria:** new player can start the game, rebind a key, plug in a controller, save to slot 2, and reach the first encounter prompt without reading documentation.

### Sprint 7 — 3D cutscene modernisation (Blender-first)

**Track A (with engineering glue).** Parallelisable with any engineering sprint because the .blend rework is offline work. Expected to delete ~500 lines of GDScript.

**Context:** the existing "No Tail Outpost" cutscene plays, but the runtime code builds an interior room from BoxMeshes, hides back walls by AABB heuristic, force-finds light fixtures by proximity, and paints materials by node-name keyword match. See `CODE_REVIEW.md §6A` for the full teardown. Blender is available, so most of these runtime hacks can move into the source .blend.

**Engineering-only prep landed 2026-04-16** alongside Sprint 5b (companion commit). Non-breaking items that do not require the `.blend` rework:

| Prep task | Status | Notes |
| --- | --- | --- |
| `data/cutscenes/_registry.json` with `no_tail_outpost` entry | **Done** | Schema documents `{id, scene_path, dialogue_path, camera_animation_name, camera_path_json, title, arc, tags, notes}`. New cutscenes become data-only when the .blend rework lands. |
| `EventBus.cutscene_completed(cutscene_id, karma_delta, recruited)` signal | **Done** | `cutscene_scene.gd._on_cutscene_finished` emits it with the CutsceneManager's accumulated karma delta + recruited ids. Replaces the `"In a real game, transition back to the main scene here."` stub. |
| `camera_controller.gd` 4-space → tabs | **Done** | Converted via python3 pass; project convention restored. |
| `_fade_in_character` shared-material fix | **Done** | Per-surface duplicated override materials contain the transparency mutation; pristine originals restored via `set_surface_override_material(s, null)` on completion. CODE_REVIEW §6A.3 closed. |
| `TODO(S7):` markers on runtime geometry hacks | **Done** | `_hide_back_wall`, `_build_interior`, `_apply_burn_marks`, `_hide_placeholder_characters`, `_force_red_light_fixture`, and the `MaterialApplicator.apply()` call site all carry back-references to the CODE_REVIEW step that explains why each belongs in the .blend. Mechanical deletion when the rework lands. |

**Blender tooling — install before Sprint 7 begins:**

Two tools change the Sprint 7 workflow significantly. Install both before the Blender rework starts.

| Tool | What it does | Install |
| --- | --- | --- |
| **blender-mcp** ([ahujasid/blender-mcp](https://github.com/ahujasid/blender-mcp), 19 900+ stars) | MCP server + Blender addon that give Claude a live two-way socket connection to a running Blender instance. Claude can create/modify objects, apply materials, inspect the scene, and execute arbitrary Python — interactively, with viewport screenshots. Changes the .blend rework from "offline human task" to "Claude-driven session". | Install the Blender addon (`addon.py`) from the repo, then add the MCP server to Claude. Requires Blender 3.0+, `uv` (`brew install uv`). **Do not use blender-mcp.org — it is unofficial and unaffiliated; the README explicitly warns against it.** |
| **blender-claude-plugin** ([ra100/blender-claude-plugin](https://github.com/ra100/blender-claude-plugin), experimental) | Claude Code plugin that loads Blender 5.x API reference skills (geometry nodes, modifiers, Python scripting, animation/rigging, rendering) into context. Prevents hallucinated `bpy` calls when writing scripts outside a live MCP session. | `claude plugin marketplace add ra100/blender-claude-plugin && claude plugin install blender-skills@blender-claude-marketplace`. Verify your Blender version is 5.x before relying on the API refs. |

**Remaining — Blender rework (Claude-drivable via blender-mcp; human judgment required for artistic calls):**

| Task | Who | Outcome | Reference |
| --- | --- | --- | --- |
| Rebuild `no_tail_outpost.blend` | Claude (blender-mcp) | Proper material slots with meaningful names, UV unwraps, **interior room modeled in-scene**, burn marks painted into textures, door as single named mesh on an Empty pivot, no placeholder character geometry in export | CODE_REVIEW §6A.6 step 1 |
| Author camera animation in Blender | Claude (blender-mcp) | 6 keyframes matching existing `camera_path.json`, baked into an AnimationPlayer track on export | CODE_REVIEW §6A.2 |
| Optimise character GLBs | Human artist | Bake 1024×1024 textures + mesh compression; target ≤ 4 MB each (from 34 MB today) — artistic texture decisions need a human eye | CODE_REVIEW §6A.4, MASTER_PLAN §6 |
| Lighting pass | Human artist | Volumetric fog on wides, ember/dust particles at door, DoorRim flicker, baked indirect GI | CODE_REVIEW §6A.5 |
| Rewrite `cutscene_scene.gd` | Claude | ≤ 100 lines — wiring only, no geometry manipulation | CODE_REVIEW §6A.7 |
| Delete `MaterialApplicator` (370 lines) | Claude | Runtime painter no longer needed | CODE_REVIEW §6A.6 step 3 |
| Replace `CameraController` with AnimationPlayer driver | Claude | Hero shots use baked animation; JSON-keyed tweens remain as generic fallback | CODE_REVIEW §6A.6 step 4 |
| Fix `_fade_in_character` material mutation | Claude | Shader-based fade (uniform) or AnimationPlayer modulate track — no shared-material side effects | CODE_REVIEW §6A.3 |
| Wire cutscene return flow | Claude | `_on_cutscene_finished` emits `cutscene_completed(cutscene_id, karma_delta, recruited)` on EventBus; `SceneManager` re-enters gameplay (no stub print) | CODE_REVIEW §6A.3 |
| Fix `camera_controller.gd` indentation | Claude | Tabs, matching project convention | CODE_REVIEW §6A.2 |
| Unify dialogue UIs | Claude | Merge `CutsceneDialogueUI` + `scripts/ui/dialogue_ui.gd` (already flagged Apr-07 #14) | CODE_REVIEW §6A.6 step 8 |
| Add cutscene registry | Claude | `data/cutscenes/_registry.json` with `{id, scene_path, dialogue_path, camera_animation_name}` — adding a cutscene becomes data-only | MASTER_PLAN Sprint 6 |

**Exit criteria:** `wc -l godot/scripts/systems/cutscene/cutscene_scene.gd` ≤ 100; `MaterialApplicator` removed; `aristotle_3d.glb` ≤ 4 MB; new cutscene addable by JSON + .blend only. Playthrough screenshot of the "No Tail Outpost" cutscene posted to `docs/qa/cutscenes/` for before/after comparison.

### Backlog — preserved from MASTER_PLAN

Everything in MASTER_PLAN §7 "Backlog: Visual Polish & Features" remains valid. Items most likely to move into Sprint 7+:

- Arc branching upgrade (OR-of-flags, path-gated encounters, per-faction stance).
- Combat abilities (2–3 per role) and status effects reusing `astral_hazard_system` shape.
- Upgrade-tier pricing and consumables.
- Time-limited and arc-cascade side missions.
- Procedural distress events driven by faction state.
- Live World News, Wanted/Notoriety system, Black Market, Astral Dice, Tavern/Station hubs.

---

## 3. Sprite modernisation — the standalone plan

Cross-linked from `CODE_REVIEW.md` §6. Summarised here for art-focused work.

### 3.1 The problem in one line

Hand-painted portraits + gorgeous painted ship illustrations + 32×32 Game-Boy-era character sprites = a visual identity that reads as inconsistent. The floor needs to come up.

### 3.2 The three tracks

- **Track A (floor, do this).** Redraw to 64×64 native / 256×256 exported, 12–16 colours per sprite, shaded, selective AA. Reference bar: Stardew, Death's Door, Moonlighter.
- **Track B (aspirational, for named cast).** Painterly portrait cards in the same style as `aristotle.png` / `dave.png`. Used during dialogue, cutscenes, shop flow.
- **Track C (cheapest, defer).** Hybrid — keep 32×32 rigs, bolt painterly portrait cards onto dialogue. Only sensible if Track A pilot fails.

### 3.3 Pilot first, roll out second

Sprint 2 redraws Aristotle only. Sprint 4 rolls out to Dave + the 8 named crew only. Generic NPC sheets (bard/guard/sailor/urchin/landlord/merchant) stay at their current resolution to keep scope contained. Revisit them only after the named cast is consistent and in-engine.

### 3.4 Acceptance bar per sheet

- Native 64×64, exported 256×256.
- ≥ 12 colour palette.
- Readable at minimap scale (tested at 24×24 render).
- Silhouette recognisable in ≤ 200ms from a cold glance.
- Portrait-to-sprite parity screenshot committed to `docs/qa/sprite_parity/`.

### 3.5 Non-goals for this modernisation

- Not changing the rig (29 animation rows × existing frame counts).
- Not changing the SpriteFrames setup.
- Not redrawing ships (they are already strong).
- Not redrawing tiles (separate future pass).

---

## 4. Tidy-up — executed 2026-04-16

All actions below were completed; references were swept before and after.

| # | Item | Action taken |
| --- | --- | --- |
| 4.1 | `other_data/` (1.3 GB Pioneer-lineage source data) | **Deleted** (`git rm -r`). Zero references from code/docs. |
| 4.2 | `backup_assets/` (20 MB stale music) | **Deleted** (`git rm -r`). |
| 4.3 | `logs/runtime.log` (one-off debug output) | **Deleted** (untracked; `logs/` already gitignored). |
| 4.4 | `examples/godot-patterns/` (3 reference GDScripts) | **Moved** to `docs/godot-reference/examples/godot-patterns/`. Removed empty `examples/` dir. `GODOT_DEV_GUIDE.md` path updated. |
| 4.5 | `docs/` root md files | **Minimal tidy**: `sprite_sheet_notes.md` moved, `MEMORY.md` renamed, new `docs/README.md` index added, pre-existing `STRUCTURE.md` path bugs fixed in `README.md` and `GODOT_DEV_GUIDE.md` and `MASTER_PLAN.md`. No other moves. |
| 4.6 | `docs/MEMORY.md` (Godot engineering notes) | **Renamed** to `docs/GODOT_NOTES.md` for clarity. |
| 4.7 | `.DS_Store` files | **Deleted** (already gitignored; were untracked). |
| 4.8 | `docs/sprite_sheet_notes.md` | **Moved** to `design/art_direction/sprite_sheet_notes.md` (lives next to `art_direction_guide.md`). |

Repo size dropped from ~5.0 GB to ~3.7 GB.

---

## 5. What to do today (if starting now)

The "first commit" items from the original plan are all landed. Current state as of 2026-04-16 post-Sprint 5b:

- Sprint 1 (critical bugs + GUT) **done**.
- Sprint 2 (art guide + Track A/B commitment) **done**; sprite pilot pending artist.
- Sprint 3a/3b/3c (NavigationViewModel, CombatViewModel + combat_ui decomposition, should-fix bugs) **done**.
- Sprint 5a (StarMapViewModel + star_map_screen decomposition) **done**.
- Sprint 5b (crew morale wired into combat + trade; astral hazards retired as stale tracker — already wired) **done**.

**Pick next from:**

1. **Sprint 5c** — dock gating (realm_control + reputation), conquest surfacing, DataLoader cache invalidation, HUD polish (segmented hull bar + objective + morale pip). Two dormant systems left — this is the finish line.
2. **Sprint 7 cutscene modernisation** — offline Blender work, parallelisable with 5c. Prep scaffolding already in place (cutscene registry + EventBus signal + indentation + fade fix, per Sprint 7-prep commit alongside 5b).
3. **Human-artist slice** — Aristotle pilot spritesheet redraw at 64×64 + parity screenshot (Sprint 2 exit criterion).
4. **Sprint 6** — dialogue decomposition + onboarding + multi-slot saves (includes ESC rebind for pause/skip collision surfaced in 3c).

Open this file and MASTER_PLAN §7 side by side at the start of every work session. Everything else is sequenced above.

---

## 6. Changelog of this plan

| Date | Change |
| --- | --- |
| 2026-04-16 | Initial plan. Folds CODE_REVIEW.md (enhanced) and MASTER_PLAN.md §7 into a two-track sprint schedule. Adds sprite modernisation track. Adds tidy-up menu. |
| 2026-04-16 | Sprint 1 closed. Sprint 2 partial (art guide + reference pins done; sprite pilot pending artist). Sprint 3 sliced into 3a/3b/3c; 3a closed (NavigationViewModel + navigation.gd conversion, 73 → 0 refs, UI total 206 → 134, 22 new tests). |
| 2026-04-16 | Sprint 3b closed (CombatViewModel + `combat_ui.gd` decomposition 585 → 399 orchestrator + 4 components under `scripts/ui/combat/`, 4 → 0 refs, UI total 134 → 129, 31 new tests, full suite 62/62 green). Sprint 3c still pending. |
| 2026-04-16 | Sprint 3c closed. All four should-fix bugs resolved: R-key was already fixed in Sprint 1 (stale tracker); `scene_transition` post-change work delegated to `GameSession.complete_scene_transition`; `_show_bark` migrated to dedicated `EventBus.npc_bark` signal; `_remove_near_white_bg` results cached by resource_path + thresholds. +15 regression tests across 4 new files (`test_input_map_collisions.gd`, `test_dialogue_manager_bark.gd`, `test_portrait_cache.gd`, `test_scene_transition_handoff.gd`); full suite 77/77 green. New finding: `pause` and `skip` both on ESC — tolerated via whitelist, flagged for Sprint 6 input-rebind work. |
| 2026-04-16 | Sprint 5 sliced into 5a/5b/5c (mirrors the 3a/3b/3c pattern). Sprint 5a closed: StarMapViewModel + `star_map_screen.gd` decomposition. 1092 → 375-line orchestrator + 3 layer components (`scripts/ui/star_map/{galaxy,region,local}_layer.gd`) + 184-line VM. 23 → 0 refs in `star_map_screen.gd`; UI total 129 → 106. +20 tests in `test_star_map_view_model.gd`; full suite 97/97 green. Sprint 5b (system wiring: morale, hazards) and 5c (dock gating, conquest, DataLoader, HUD) still pending. |
| 2026-04-16 | Sprint 5b closed. Crew morale threaded through `CombatSystem.calculate_damage` (new `morale_modifier` parameter applied to effective firepower) and `EconomySystem.get_buy_price`/`get_sell_price`/`buy_crystals`/`sell_crystals` (low morale costs more on buy AND earns less on sell, via `2.0 - m` inversion on the sell side). `CombatViewModel.combat_morale_modifier()` fetches from `GameSession.crew_morale.get_combat_modifier(gs)`; `trade_screen.gd` uses `get_trade_modifier(gs)`. **Astral hazards finding:** the "apply astral hazards during navigation tick" row was a stale tracker — hazards have been ticking at `navigation.gd:213` since the feature shipped. Retired from the plan rather than re-implemented. +24 tests across `test_crew_morale_combat_wiring.gd` and `test_crew_morale_trade_wiring.gd`; full suite 121/121 green. Dormant-systems count 4 → 2 (realm_control + faction_conquest still open in 5c). |
| 2026-04-16 | Sprint 7 tooling: added blender-mcp (ahujasid/blender-mcp, 19 900+ stars) and blender-claude-plugin (ra100, experimental) to the Sprint 7 setup block. blender-mcp gives Claude live socket control of Blender (create/modify objects, materials, camera, arbitrary Python), changing the .blend rework from "blocked on human artist" to "Claude-drivable". Remaining table split into "Claude" vs "human artist" rows accordingly. Warning added: blender-mcp.org is unofficial — use the GitHub repo directly. |
| 2026-04-16 | Sprint 7 prep (companion commit to 5b). Engineering-only scaffolding that doesn't require the `.blend` rework: new `data/cutscenes/_registry.json` with the `no_tail_outpost` entry; `EventBus.cutscene_completed(cutscene_id, karma_delta, recruited)` signal + `cutscene_scene.gd._on_cutscene_finished` wired to emit it (no more stub print); `camera_controller.gd` 4-space → tabs; `_fade_in_character` shared-material mutation replaced with per-surface duplicated override materials (CODE_REVIEW §6A.3 closed); `TODO(S7)` headers on all runtime geometry hacks (`_hide_back_wall`, `_build_interior`, `_apply_burn_marks`, `_hide_placeholder_characters`, `_force_red_light_fixture`, `MaterialApplicator.apply()` call site) so deletion is mechanical when the rework lands. Remaining Sprint 7 work blocked on human artist / Blender rework. |
