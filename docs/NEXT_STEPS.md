# Whisper Crystals — Next Steps

**Date:** 2026-04-16
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

Restore test safety, fix the critical bugs, decompose the UI god-scripts, cut UI↔GameSession coupling, and wire the dormant systems so the player can feel crew morale, hazards, realm control, and conquest.

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

### Sprint 2 — Art direction + sprite pilot (parallel with Sprint 1)

**Track A only.** Can start the day Sprint 1 starts.

| Task | Outcome | Reference |
| --- | --- | --- |
| Update `design/art_direction/art_direction_guide.md` | Delete the "to be decided" line; commit to **Track A floor (64×64 native, 12–16 colours, shaded)** + **Track B aspirational (painterly portraits for named cast)** | CODE_REVIEW §6.4 |
| Add reference-pin section | 3–5 games pinned as visual benchmarks (Stardew, Death's Door, Moonlighter) | CODE_REVIEW §6.3 |
| Pilot redraw: `aristotle_spritesheet.png` at 64×64 / 256×256 | Single sheet redrawn, runs in-game without rigging changes | CODE_REVIEW §6.4 step 2 |
| In-game parity screenshot | `aristotle.png` portrait and the new sprite placed side by side — same character, same palette, same silhouette | CODE_REVIEW §6.5 |

**Exit criteria:** art direction guide has no "to be decided" left; one spritesheet redrawn; parity screenshot committed to `docs/qa/`.

### Sprint 3 — UI view-model layer (cut the coupling at the source)

**Track E.** Matches MASTER_PLAN Sprint 2 scope but adds the view-model layer that CODE_REVIEW §2.1 identifies as load-bearing.

| Task | Outcome | Reference |
| --- | --- | --- |
| Create `godot/scripts/ui/view_models/` | Location for per-screen adapters | CODE_REVIEW §2.1 |
| `NavigationViewModel` | Exposes the 12–15 reads `navigation.gd` actually needs | Coupling inventory |
| Convert `navigation.gd` to consume the VM via `initialize(vm)` | Direct `GameSession.` refs inside `navigation.gd` drop to zero | CODE_REVIEW §2.1 |
| `CombatViewModel` | Same for `combat_ui.gd` | — |
| Decompose `combat_ui.gd` (586 → 5 files) | As per REFACTORING_PLAN Phase 2 | MASTER_PLAN Sprint 2 |
| Fix: R-key collision, scene_transition tween, `_show_bark` recursion, portrait cache | Should-fix bugs | MASTER_PLAN §5.3 |
| Tests for new combat components | Green | Quality policy |

**Exit criteria:** `rg "GameSession\." godot/scripts/ui/navigation.gd` returns 0; `rg "GameSession\." godot/scripts/ui | wc -l` ≤ 140 (down from 206); combat_ui split into `scripts/ui/combat/`.

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

**Track E.** Matches MASTER_PLAN Sprint 3, plus the "wire the dormant systems" work from CODE_REVIEW §3.

| Task | Outcome | Reference |
| --- | --- | --- |
| `StarMapViewModel` + decompose `star_map_screen.gd` (1093 → 5 files) | View model + split | MASTER_PLAN Sprint 3 |
| Wire crew morale into `CombatSystem.calculate_damage` and `EconomySystem.trade` | Morale visibly affects gameplay | CODE_REVIEW §3 |
| Apply astral hazards during navigation tick | Ship takes damage / status in hazard regions | CODE_REVIEW §3 |
| Gate docking via `realm_control_system.controlling_faction` + reputation | Low-rep players locked out of hostile stations | CODE_REVIEW §3 |
| Surface conquest actions as visible world changes | Distress spawns / blockades / price shifts | CODE_REVIEW §3 |
| Fix: DataLoader cache invalidation + redundant calls | MASTER_PLAN §5.3 Apr-05 #4, #12 | — |
| HUD: segmented hull bar, objective on top bar, morale pip | CODE_REVIEW §4.6 | — |

**Exit criteria:** EventBus log over a 20-minute session emits `crew_morale_*`, `astral_hazard_*`, `realm_control_*`, and `faction_conquest_*` signals (they are no longer dormant). HUD shows objective without opening mission log.

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

| Task | Outcome | Reference |
| --- | --- | --- |
| Rebuild `no_tail_outpost.blend` | Proper material slots with meaningful names, UV unwraps, **interior room modeled in-scene**, burn marks painted into textures, door as single named mesh on an Empty pivot, no placeholder character geometry in export | CODE_REVIEW §6A.6 step 1 |
| Author camera animation in Blender | 6 keyframes matching existing `camera_path.json`, baked into an AnimationPlayer track on export | CODE_REVIEW §6A.2 |
| Rewrite `cutscene_scene.gd` | ≤ 100 lines — wiring only, no geometry manipulation | CODE_REVIEW §6A.7 |
| Delete `MaterialApplicator` (370 lines) | Runtime painter no longer needed | CODE_REVIEW §6A.6 step 3 |
| Replace `CameraController` with AnimationPlayer driver | Hero shots use baked animation; JSON-keyed tweens remain as generic fallback | CODE_REVIEW §6A.6 step 4 |
| Fix `_fade_in_character` material mutation | Shader-based fade (uniform) or AnimationPlayer modulate track — no shared-material side effects | CODE_REVIEW §6A.3 |
| Wire cutscene return flow | `_on_cutscene_finished` emits `cutscene_completed(cutscene_id, karma_delta, recruited)` on EventBus; `SceneManager` re-enters gameplay (no stub print) | CODE_REVIEW §6A.3 |
| Fix `camera_controller.gd` indentation | Tabs, matching project convention | CODE_REVIEW §6A.2 |
| Unify dialogue UIs | Merge `CutsceneDialogueUI` + `scripts/ui/dialogue_ui.gd` (already flagged Apr-07 #14) | CODE_REVIEW §6A.6 step 8 |
| Optimise character GLBs | Bake 1024×1024 textures + mesh compression; target ≤ 4 MB each (from 34 MB today) | CODE_REVIEW §6A.4, MASTER_PLAN §6 |
| Add cutscene registry | `data/cutscenes/_registry.json` with `{id, scene_path, dialogue_path, camera_animation_name}` — adding a cutscene becomes data-only | MASTER_PLAN Sprint 6 |
| Lighting pass | Volumetric fog on wides, ember/dust particles at door, DoorRim flicker, baked indirect GI | CODE_REVIEW §6A.5 |

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

Minimum viable "first commit" from this plan:

1. Fix the four critical bugs (MASTER_PLAN §5.2) — hours, not days.
2. Install GUT and commit one green test.
3. Update `art_direction_guide.md` to remove the "to be decided" line and state the Track A floor.
4. Open this file and MASTER_PLAN §7 side by side at the start of every subsequent work session.

Everything else is sequenced above.

---

## 6. Changelog of this plan

| Date | Change |
| --- | --- |
| 2026-04-16 | Initial plan. Folds CODE_REVIEW.md (enhanced) and MASTER_PLAN.md §7 into a two-track sprint schedule. Adds sprite modernisation track. Adds tidy-up menu. |
