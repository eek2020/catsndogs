# Changelog

All notable changes to the Whisper Crystals project are documented here.

Format: Each entry includes the date, phase/task reference, and summary of changes.

---

## 2026-03-19 — Arc Transition: Stats Summary + Hyperspace Jump

**Feature:** When a story arc completes, a full-screen stats summary and hyperspace jump animation play before entering the next sector.

1. **Arc Summary Screen** — Overlay showing completed arc title, next arc title + theme teaser, and 8 animated count-up stats: encounters completed, combat victories, crew recruited, missions completed, crystals, salvage, hull status, and playtime.

2. **Hyperspace Jump Shader** — Custom canvas_item shader with radial star streaks, blue-white tunnel intensification, flash-to-white, and fade-to-black. Driven by a single `progress` uniform (0→1) over ~2.5 seconds.

3. **Combat Victory Counter** — Added `combat_victories` field to `GameStateData` with full save/load persistence, incremented on each `combat_victory` signal.

4. **Flow:** Arc exit conditions met → `arc_advanced` signal → navigation pushes `arc_summary` overlay → player reads stats → presses "JUMP TO NEXT SECTOR" → stats fade out → hyperspace shader plays → `arc_transition_complete` signal → POIs refresh for new arc.

### New Files

- `scripts/ui/arc_summary.gd` — Stats screen + hyperspace jump controller
- `scenes/ui/arc_summary.tscn` — Scene layout with panel, stats container, continue button, hyperspace ColorRect
- `shaders/hyperspace_jump.gdshader` — Radial streak warp shader with 3-phase animation

### Modified Files

- `scripts/core/game_state_data.gd` — Added `combat_victories` field + persistence in `to_dict()`/`from_dict()`
- `scripts/autoload/game_session.gd` — Connected `combat_victory` signal, added `_on_combat_victory()` handler
- `scripts/autoload/event_bus.gd` — Added `arc_transition_complete(new_arc)` signal
- `scripts/ui/main.gd` — Registered `arc_summary` in SCENES dictionary
- `scripts/ui/navigation.gd` — Replaced flash message with `push_overlay("arc_summary")`, added `_on_arc_transition_complete()` to refresh POIs after jump

---

## 2026-03-19 — Crew recruitment encounters converted to dialogue_steps

**Feature:** All 8 crew member recruitment encounters now use two-sided branching dialogue.

1. **Cat crew encounters** - Nine Lives, No Tail, Silky, and Blood Paw recruitment conversations converted to dialogue_steps with Aristotle. Each crew member has distinct personality: Nine Lives (cocky), No Tail (gruff), Silky (enigmatic), Blood Paw (dedicated healer).

2. **Dog crew encounters** - Charlie, Bombardier, Luna, and Thistle recruitment conversations converted to dialogue_steps with Dave. Each crew member has distinct personality: Charlie (enthusiastic), Bombardier (sarcastic), Luna (calculating), Thistle (principled).

3. **Arc 1-2 story encounters** — Key Dave/Aristotle confrontations converted: arc1 face-to-face meeting and arc2 route seizure standoff.

4. **Arc 3 story encounters** — Dave/Aristotle parley (both perspectives), Death reveal on Aristotle's bridge, Death's offer to Dave in the Forgotten Realm.

5. **Arc 4 story encounters** — Dave's assault on crystal fields (Dave/Aristotle comms exchange before combat), Death's Vault bid (Aristotle/Death confrontation), Death's mid-battle betrayal (Dave/Death), and the climactic Dave/Aristotle showdown with three branching endings (surrender terms, shared governance, destruction).

6. **Portrait support** — Added 8 crew member portraits to CHARACTER_PORTRAITS registry including Nine Lives portrait.

### Changes

- `scripts/ui/dialogue_ui.gd` — Added crew member portrait paths
- `data/encounters/crew_nine_lives.json` — Converted to dialogue_steps
- `data/encounters/crew_no_tail.json` — Converted to dialogue_steps
- `data/encounters/crew_silky.json` — Converted to dialogue_steps
- `data/encounters/crew_blood_paw.json` — Converted to dialogue_steps
- `data/encounters/crew_charlie.json` — Converted to dialogue_steps
- `data/encounters/crew_bombardier.json` — Converted to dialogue_steps
- `data/encounters/crew_luna.json` — Converted to dialogue_steps
- `data/encounters/crew_thistle.json` — Converted to dialogue_steps
- `data/encounters/arc1_encounters_dave.json` — Dave/Aristotle meeting converted
- `data/encounters/arc2_encounters.json` — Route seizure confrontation converted
- `data/encounters/arc3_encounters.json` — Dave parley + Death reveal converted
- `data/encounters/arc3_encounters_dave.json` — Aristotle parley + Death offer converted
- `data/encounters/arc4_encounters.json` — Dave assault + Death bid converted
- `data/encounters/arc4_encounters_dave.json` — Death betrayal + Aristotle showdown converted

---

## 2026-03-19 — Two-sided branching dialogue system

**Feature:** Encounters can now have multi-step, two-sided conversations with branching outcomes.

1. **Dialogue steps format** — Encounters support an optional `dialogue_steps` array in JSON. Each step has a `speaker`, `text`, and optional `choices` with `next_step` branching. Steps can end peacefully (`"end": true`) or escalate to combat (`"start_combat": true`).

2. **Two-portrait UI** — Dialogue screen now shows Aristotle on the left and the NPC on the right. The active speaker's portrait is highlighted at full opacity while the other dims to 0.4 alpha.

3. **Step state machine** — The dialogue UI walks through steps sequentially, pausing for player choices and auto-advancing non-choice lines. Choices apply mid-dialogue outcomes (flags, resources, factions) and jump to branch targets via `step_id`.

4. **Backwards compatible** — Encounters without `dialogue_steps` use the original single-step flow unchanged.

5. **Proof-of-concept** — `enc_arc1_dave_trade` converted to a branching two-sided conversation with three paths: friendly trade, negotiation, and hostile escalation to combat.

### Changes

- `scripts/entities/encounter.gd` — added `DialogueStep`, `DialogueStepChoice` inner classes, `dialogue_steps` field
- `scripts/systems/encounter_engine.gd` — added `apply_dialogue_step_outcome()`, `complete_encounter()`
- `scripts/autoload/event_bus.gd` — added `dialogue_step_advanced` signal
- `scenes/ui/dialogue_ui.tscn` — restructured to left/right portrait layout
- `scripts/ui/dialogue_ui.gd` — added step state machine, two-portrait handling, speaker highlighting, branching flow
- `data/encounters/arc1_encounters.json` — converted Dave trade encounter to branching dialogue

---

## 2026-03-19 — Add ship purchasing and Pirate Destroyer to shipyard

**Feature:** Players can now buy new ships in the shipyard alongside repairs and upgrades.

1. **Pirate Destroyer template** — Added to `ship_templates.json` with `purchasable: true`, costing 80 crystals + 60 salvage. Stats: Spd 4, Arm 8, Fp 9, Hull 160, Cargo 5, Crew 8. Uses `ship_destroyer_r_side.png` sprite.

2. **Ship purchase logic** — Added `purchase_ship()` to `economy_system.gd`. Validates affordability, prevents re-buying current ship class, transfers crew and cargo to the new vessel, emits `EventBus.ship_purchased`.

3. **Data loader** — Added `load_purchasable_ships()` to `data_loader.gd` filtering templates with `purchasable == true`.

4. **Shipyard UI** — Left panel now shows current ship sprite preview and ship name/class. Right panel split into "Ships For Sale" (with thumbnails, stat summary, cost, buy button) and "Ship Upgrades". Buying a ship swaps your vessel and refreshes the entire UI.

### Changes

- `data/ships/ship_templates.json` — added Pirate Destroyer template with purchase cost fields
- `scripts/core/data_loader.gd` — added `load_purchasable_ships()`
- `scripts/systems/economy_system.gd` — added `purchase_ship()`
- `scripts/ui/purchase_screen.gd` — added ship preview, ship purchasing UI, ship list builder
- `scenes/ui/purchase_screen.tscn` — added ShipPreview, ShipNameLabel, ShipList nodes; restructured right panel

---

## 2026-03-19 — Implement ship upgrade shop in the shipyard screen

**Problem:** The shipyard (R key) only offered hull repair. Ship upgrades were fully defined in data (7 upgrades in `ship_templates.json`) and the `Ship.ShipUpgrade` entity class existed, but there was no way to browse, buy, or apply upgrades during gameplay. This made combat increasingly unwinnable as enemies scaled up.

**Solution:** Built the full upgrade purchase pipeline:

1. **Economy logic** — Added `purchase_upgrade()` and `_apply_stat_modifier()` to `economy_system.gd`. Handles cost deduction (crystals + salvage), stat application (including side effects like Siege Cannons: +2 firepower / -1 speed), duplicate prevention, and emits `EventBus.upgrade_purchased`.

2. **Shipyard UI overhaul** — Rebuilt `purchase_screen.gd` to show current ship stats, repair with dynamic cost display, and a scrollable list of all 7 upgrades. Each row shows the upgrade name, stat effect, cost (crystals + salvage), affordability colour coding, and a Buy button. Installed upgrades show as green "INSTALLED" labels.

3. **Scene layout** — Expanded `purchase_screen.tscn` panel to fit ship stats line, repair button, upgrades header, scrollable upgrade list, and close button.

### Changes

- `scripts/systems/economy_system.gd` — added `purchase_upgrade()` and `_apply_stat_modifier()` functions
- `scripts/ui/purchase_screen.gd` — full rewrite with upgrade list UI, dynamic repair cost, ship stats display
- `scenes/ui/purchase_screen.tscn` — expanded layout with `ShipStatsLabel`, `ScrollContainer`/`UpgradeList`, `UpgradesHeader`

---

## 2026-03-19 — Fix story arc progression, add repair access and arc progress HUD

**Problem:** Story arcs never advanced because `NarrativeSystem.check_arc_exit()` and `advance_arc()` were defined but never called after encounters. This meant the game stayed stuck in Arc 1 forever, making battles increasingly pointless. Additionally, the repair/purchase screen existed but had no keybind to access it, so players couldn't repair their ship during gameplay.

**Solution:** Three changes to make gameplay progression work:

1. **Wired arc progression** — After each encounter outcome is applied in `encounter_engine.gd`, the game now checks if the current arc's exit conditions are satisfied and automatically advances to the next arc. This loads new encounters, side missions, and updates music.

2. **Added repair screen access (R key)** — Added a `repair` input action bound to R and wired it in `navigation.gd` so players can open the purchase/repair screen at any time. Updated the controls bar hint text.

3. **Added arc progress feedback** — The HUD arc label now shows progress as "ARC TITLE (2/3)" indicating how many exit conditions have been met. When an arc advances, a 6-second flash notification announces the new arc.

### Changes

- `scripts/systems/encounter_engine.gd` — added `check_arc_exit()` + `advance_arc()` call after `apply_choice_outcome()`
- `scripts/ui/navigation.gd` — connected `arc_advanced` signal, added `_on_arc_advanced()` flash + POI refresh, added R key handler for purchase overlay, updated HUD to show arc progress count, updated controls bar hint
- `project.godot` — added `repair` input action mapped to R key

---

## 2026-03-19 — Improved ship orientation during navigation

**Problem:** The player ship used a single side-view sprite rotated 360 degrees, which looked unnatural at vertical angles.

**Solution:** Replaced free rotation with a banking + smooth flip + directional sprite blending system:
- 3-sprite flip transition: cross-fades through a 3/4 angle turning sprite (`ship_rotate.png`) during horizontal direction changes, blending from rotate sprite to side sprite with overlapping alpha curves
- Ease-out-quad curve on flip progress so the rotate midpoint transitions quickly
- Slight banking tilt (up to ~17 degrees) when moving vertically for momentum feel
- Cross-fades between side-view sprite (`ship_r_side.png`) and top-down sprite (`ship_up_side.png`) based on vertical movement dominance
- Engine glow and trail particles adapt to the new orientation system

### Changes
- `scripts/ui/navigation.gd` — replaced `_ship_angle` rotation system with `_facing_right` flip, `_bank_angle` tilt, `_vertical_blend` dual-sprite blending, and `_heading_angle` for trail/minimap; added `_draw_ship_perspective()` helper that renders the ship as a UV-mapped trapezoid for pseudo-3D turning; loaded and processed `ship_up_side.png` as second directional sprite; updated engine glow to blend between side-rear and heading-based offsets

---

## 2026-03-19 — Fix ESC-to-skip cutscene, navigation & combat music

**Bug 1:** ESC key did not skip the intro cutscene. The `skip` input action was mapped to keycode `4194306` (Tab) instead of `4194305` (Escape).

**Bug 2:** Navigation music never played. `on_state_change("navigation")` always resolved to the arc-specific theme (`"theme_arc1"`) which doesn't exist, instead of falling back to `"theme_navigation"`. Additionally, `_play_theme()` set `_current_theme` even when no file was found, poisoning subsequent calls.

**Bug 3:** Combat music never played. Combat starts via `replace_overlay()` which was missing the `MusicManager.on_state_change()` call that `push_overlay()` and `switch_scene()` both have.

### Changes
- `project.godot` — fixed `skip` input action keycode from `4194306` (Tab) to `4194305` (Escape)
- `scripts/autoload/music_manager.gd` — added `_theme_file_exists()` helper; `on_state_change()` and `on_arc_change()` now fall back to default themes when arc-specific files don't exist; `_play_theme()` now resolves the new stream before stopping the current track — if no file exists, current music keeps playing instead of going silent; lowered default music volume from -10 dB to -20 dB
- `scripts/ui/main.gd` — `replace_overlay()` now calls `MusicManager.on_state_change(scene_key)` and sets overlay meta key

---

## 2026-03-19 — Music volume control & playback continuity

**Features:**
- Volume control: settings slider now controls music volume (0–100% linear scale, mapped to dB)
- Music continuity: when switching themes (e.g., navigation → combat → navigation), tracks resume where they left off instead of restarting from the beginning
- Navigation music support: place `theme_navigation.ogg/.mp3` in `assets/audio/music/` and it plays during flight

### Changes
- `scripts/autoload/music_manager.gd` — added `set_music_volume()`, `set_sfx_volume()`, playback position save/restore in `_play_theme()`, default volume at -10 dB, wired `EventBus.volume_changed`
- `scripts/ui/settings_screen.gd` — slider initializes from current volume, toggles reflect current state, calls `MusicManager.set_music_volume()` directly

---

## 2026-03-19 — Fix overlay music (combat, trade, etc.)

**Bug:** `push_overlay()` in `main.gd` did not call `MusicManager.on_state_change()`, so combat music (and any other overlay-based screen music) never played.

### Changes
- `scripts/ui/main.gd` — `push_overlay()` now triggers `MusicManager.on_state_change(scene_key)` and saves the prior scene key; `pop_overlay()` restores the previous music when all overlays are cleared.

---

## 2026-03-18 — Crew Missions Feature

**Task:** Add crew recruitment missions — 4 named crew members per protagonist with story-driven recruitment and trait bonuses

### New Files

- `data/characters/crew_members.json` — 8 crew member definitions (4 per protagonist) with roles, traits, backstories
- `data/side_missions/crew_missions_aristotle.json` — 4 crew recruitment missions for Aristotle
- `data/side_missions/crew_missions_dave.json` — 4 crew recruitment missions for Dave
- `data/encounters/crew_nine_lives.json` — Nine Lives recruitment encounters (2 encounters)
- `data/encounters/crew_no_tail.json` — No Tail recruitment encounters (3 encounters)
- `data/encounters/crew_silky.json` — Silky recruitment encounters (2 encounters)
- `data/encounters/crew_blood_paw.json` — Blood Paw recruitment encounters (3 encounters)
- `data/encounters/crew_charlie.json` — Charlie recruitment encounters (2 encounters)
- `data/encounters/crew_bombardier.json` — Bombardier recruitment encounters (3 encounters)
- `data/encounters/crew_luna.json` — Luna recruitment encounters (2 encounters)
- `data/encounters/crew_thistle.json` — Thistle recruitment encounters (3 encounters)
- `scripts/systems/crew_trait_system.gd` — CrewTraitSystem: loads crew definitions, calculates active trait bonuses per ship
- `assets/characters/crew/.gdkeep` — Placeholder directory for crew portrait art

### Modified Files

- `scripts/entities/ship.gd` — Extended `CrewMember` with `trait_id`, `portrait`, `backstory`, `recruitment_status` fields + serialization
- `scripts/entities/side_mission.gd` — Added `crew_member_id` field + serialization
- `scripts/entities/encounter.gd` — Added `mission_type`, `crew_member_id` fields + deserialization
- `scripts/core/data_loader.gd` — Added `load_crew_members()`, `load_crew_missions()`, `load_crew_encounters()`
- `scripts/systems/side_mission_system.gd` — Added `load_crew_missions()` to append crew missions to templates
- `scripts/systems/combat_system.gd` — Applied `firepower_bonus` and `critical_hit_chance` crew trait bonuses to damage calculation
- `scripts/systems/crew_morale_system.gd` — Applied `morale_recovery` crew trait bonus to positive morale changes
- `scripts/systems/economy_system.gd` — Applied `hull_repair_rate` crew trait bonus to reduce repair costs
- `scripts/systems/encounter_engine.gd` — Applied `exploration_discovery_rate` and `ambush_detection` bonuses to encounter priority sorting
- `scripts/autoload/event_bus.gd` — Added `crew_member_recruited(crew_id, protagonist_id)` signal
- `scripts/autoload/game_session.gd` — Added `CrewTraitSystem` initialization, crew mission/encounter loading, recruitment listener, `recruit_crew_member()` helper
- `scripts/ui/dialogue_ui.gd` — Added crew recruitment detection (`_check_crew_recruitment`) and confirmation display (`_show_crew_recruitment_confirmation`)
- `scripts/ui/ship_screen.gd` — Enhanced crew roster with role labels, trait descriptions, morale colours, and empty role slots
- `scripts/ui/mission_log.gd` — Added "CREW MISSIONS" group header with crew/main/side sorting
- `scripts/ui/navigation.gd` — Added crew count indicator to HUD (`Crew: X/Y`)

### Updated Documentation

- `docs/plans/MASTER_PLAN.md` — Marked Crew Missions Feature as COMPLETE (2026-03-18) with full implementation summary

---

## 2026-03-17 — Character Selection Feature (ISSUE-001)

**Task:** Add dual-protagonist support — choose Aristotle or Dave at game start
**Model:** Opus 4.6

### Changes

- **GameStateData:** Added `protagonist_id` field with backward-compatible save/load
- **DataLoader:** Added `load_protagonists()`, suffix parameter on `load_encounters()` and `load_side_missions()` with fallback to shared files
- **GameSession:** Refactored `start_new_game(protagonist_id)` and `create_new_game_state()` to be data-driven from `protagonists.json` config
- **Character Select UI:** New scene (`character_select.tscn`) and controller (`character_select.gd`) with two-panel layout, portraits, stats, and select buttons
- **Menu:** "New Game" now routes to character selection screen
- **Cutscene:** Intro text loaded from protagonist config instead of hardcoded Aristotle lines
- **Faction systems:** Replaced hardcoded `"felid_corsairs"` references with dynamic `player_character.faction_id` in `faction_system.gd` and `faction_conquest_system.gd`
- **EventBus:** Added `protagonist_selected` signal
- **Ending screen:** Added protagonist-specific flavor text for Dave
- **Data files:** Created `protagonists.json`, Dave arc 1-4 encounters, Dave dialogue files, Dave side missions

---

## 2026-03-17 — Godogen Asset & Workflow Integration

**Task:** Integrate godogen Godot 4 development resources into Whisper Crystals
**Model:** Opus 4.6

### Phase 1: Documentation Structure

- Created `docs/godot-reference/` with 7 core reference documents:
  - `gdscript-reference.md` — Complete GDScript syntax, types, operators, patterns
  - `quirks-and-gotchas.md` — 18 known engine issues and runtime pitfalls
  - `best-practices.md` — Coding standards for Godot development
  - `scene-generation-patterns.md` — Scene builder patterns and ownership chains
  - `script-generation-patterns.md` — Runtime script templates
  - `scene-script-coordination.md` — Rules for scene/script interaction
  - `test-harness-patterns.md` — Testing approaches for Godot scenes
  - `screenshot-capture.md` — Screenshot and video capture workflow
- Copied 862 Godot API reference files to `docs/godot-reference/api/`
- Created workflow templates: `PLAN.md`, `ASSETS.md`, `MEMORY.md` at project root

### Phase 2: Local Tools

- Set up `tools/godot-dev/` with 4 tool categories:
  - `sprites/` — spritesheet_template.py, spritesheet_slice.py
  - `assets/` — rembg_matting.py (background removal with alpha matting)
  - `docs/` — godot_api_converter.py, class_list.py, ensure_doc_api.sh
  - `capture/` — gpu_detect.sh, screenshot.sh (with macOS support)

### Phase 3: Development Methodology

- Created `docs/development-methodology/` with 3 guides:
  - `task-decomposition.md` — Feature classification and task planning
  - `architecture-planning.md` — Scene hierarchy and script design
  - `iteration-strategy.md` — Progress-based stopping criteria
- Created `docs/qa/visual-qa-checklist.md` — Manual QA checklists from VQA prompts

### Phase 4: Testing Infrastructure

- Created `examples/godot-patterns/test-harness-example/` with working test template

### Phase 5: Project-Specific Adaptations

- Created `docs/GODOT_DEV_GUIDE.md` — Central reference linking all godogen assets
- Created quick reference cards in `docs/godot-reference/quick-refs/`:
  - `gdscript-cheat-sheet.md` — Type inference rules, common patterns
  - `common-nodes.md` — Node types by category with use cases
- Created working examples in `examples/godot-patterns/`:
  - `scene-builder-example/` — 2D scene builder with ownership chain
  - `runtime-script-example/` — Player controller with proper type annotations
  - `test-harness-example/` — Test with simulated input and assertions

### Excluded (API-Dependent)

- asset_gen.py (Gemini API), tripo3d.py (Tripo3D API), visual_qa.py (Gemini Vision)
- All SKILL.md files (Claude Code skill invocation system)

---

## 2026-03-03 — PLAN-003 (3.2, 3.4) Ship Sprite Integration

**Tasks:** Register new ship art, faction ship sprites in navigation, combat ship sprites
**Model:** Opus 4.6

### New Art Assets

- `design/ships/wolf_ship.png` — Wolf Clans strike craft
- `design/ships/fairy_ship.png` — Fairy Court vessel
- `design/ships/knight_ship.png` — Knight Order warship
- `design/ships/goblin_scrapper.png` — Goblin Syndicate scrapship

### Modified Files

- `engine/sprite_manager.py` — Registered 4 new ship sprites (wolf, fairy, knight, goblin) in
  SHIP_SPRITES registry. Only `alien_craft` remains as a placeholder.
- `__main__.py` — Creates SpriteManager and passes to GameSession.
- `core/session.py` — Accepts `sprite_manager` parameter, stores it, passes to CombatState.
- `ui/navigation.py` — Faction ship sprites rendered at combat POIs (with bobbing animation and
  cutlass sub-icon). Faction inferred from encounter data via `_infer_faction()`. Player ship
  loading refactored to use SpriteManager. Location-to-faction and faction-to-template mappings.
- `ui/combat_ui.py` — Ship sprites replace vector shapes when available. Player sprite (facing
  right) and enemy sprite (flipped left). Vector fallback preserved. Lazy-loaded via
  `_ensure_sprites_loaded()`.
- `systems/combat.py` — Added `ship_template_id` field to `CombatShip` dataclass. Populated
  in both `from_game_ship()` and `from_template()` factory methods.
- `tests/test_sprite_manager.py` — Updated tests: new assets have paths, only `alien_craft`
  is empty. Test count: 26.

### Test Results

- 281 tests, 100% pass rate
- EAL compliance verified (zero pygame imports in core/systems/entities)

---

## 2026-03-03 — Phase 4 (4.1, 4.1b, 4.3) + PLAN-003 (3.1)

**Tasks:** Music System, SFX System, Ending Summary Screen, Sprite Asset Manager
**Model:** Opus 4.6

### New Files

- `core/music_manager.py` — MusicManager with per-state theme mapping, arc-specific navigation
  themes, SFX event registry, enable/disable controls. Engine-agnostic (uses AudioInterface ABC).
- `engine/sprite_manager.py` — SpriteManager with centralised sprite loading, caching, scaling,
  faction-keyed ship/portrait/character registries, faction colour palettes. Lazy-load with
  graceful fallback to None (callers use vector shapes).
- `tests/test_music_manager.py` — 18 tests covering theme registry, state transitions, arc themes,
  overlay behaviour, SFX triggers, enable/disable, no-audio fallback.
- `tests/test_sprite_manager.py` — 25 tests covering registry completeness, lookup/caching,
  flip/scale, faction colour lookup, preload, cache clearing.
- `tests/test_ending_screen.py` — 18 tests covering ending calculation, summary builder
  (stats, factions, decisions, missions), input handling (scroll, confirm), text wrapping.
- `assets/audio/music/.gitkeep` — Directory for BGM track files
- `assets/audio/sfx/.gitkeep` — Directory for SFX files

### Modified Files

- `core/session.py` — Replaced raw audio event subscriptions with MusicManager. Added
  `music.on_state_change()` at all key transitions (menu, cutscene, navigation, dialogue,
  combat, trade, ending). Wired SFX events through music manager. Arc advancement updates
  navigation theme via `music.on_arc_change()`.
- `ui/ending_screen.py` — Full rewrite: scrollable decision summary with voyage statistics
  (duration, crystals, salvage, encounters, decisions, ship status), faction standings with
  reputation tags (Allied/Friendly/Neutral/Hostile/At War), side mission summary, decision
  history grouped by arc with positive/negative indicators. Arrow key scrolling. Fixed
  `.reputation` → `.reputation_with_player` bug.

### Bug Fixes

- Fixed `EndingState._calculate_ending()` using non-existent `.reputation` attribute on
  Faction entities (should be `.reputation_with_player`). Same fix in `_build_summary()`.

### Test Results

- All 280 tests pass (210 previous + 70 new)
- All tests run headless without pygame display context
- EAL verification: zero pygame imports in `core/`, `systems/`, `entities/`

---

## 2026-03-02 — PLAN-002: Side Missions & Distress Signals

**Task:** Entertainment Enhancements — Side Missions + Distress Signals (13 tasks)
**Model:** Opus 4.6

### New Files

- `systems/side_mission.py` — SideMissionSystem with mission lifecycle, objective tracking, reward
  application, and distress signal spawning (timer-based, weighted random)
- `data/side_missions/arc1_side_missions.json` — 4 side missions for Arc 1 (bounty, retrieval, escort, salvage)
- `data/side_missions/distress_signals.json` — 5 distress signal encounters with 3 choices each
  (help/exploit/ignore), repeatable, weighted spawn
- `ui/mission_log.py` — MissionLogState overlay (two-panel: mission list + detail with objectives/rewards)
- `tests/test_side_missions.py` — 24 tests covering entity serialization, data loading, system lifecycle,
  rewards, events, and GameStateData round-trip

### Modified Files

- `core/interfaces.py` — Added `MISSION_LOG` to `Action` enum
- `core/state_machine.py` — Added `MISSION_LOG` to `GameStateType` enum
- `core/data_loader.py` — Added `load_side_missions(arc_id)`, `load_distress_signals()`
- `core/game_state.py` — Added `side_missions: dict[str, SideMission]` field + to_dict/from_dict
- `core/session.py` — Wired SideMissionSystem, M key hotkey, `_open_mission_log()`,
  load on new game/load/arc transition
- `entities/encounter.py` — Added `spawn_weight: float` field
- `engine/input_handler.py` — Mapped `pygame.K_m` to `Action.MISSION_LOG`
- `ui/navigation.py` — Distress POI spawning, mission objective checking, distress_signal colour
- `ui/hud.py` — Active mission count indicator (amber text in top bar)

### Updated Documentation

- `docs/MASTER_PLAN.md` — Marked PLAN-002 complete, added PLAN-003 (Sprite Character & Visual Identity),
  updated metrics (210 tests, 10 systems, 14 UI states, 20 data files)

### Test Results

- All 210 tests pass (186 previous + 24 new)
- All tests run headless without pygame display context
- EAL verification: zero pygame imports in `core/`, `systems/`, `entities/`

---

## 2026-03-02 — Documentation Audit & Restructure

**Task:** Documentation consolidation and master plan creation
**Scope:** Full /docs reorganisation — no source code changes

### Documentation Structure

- Created `docs/MASTER_PLAN.md` — unified single source of truth for all planning and status
- Created `docs/architecture/` — moved all TRDs (TRD-001, TRD-002, TRD-003) here from `docs/trd/`
- Created `docs/architecture/decisions/` — moved ADR_TEMPLATE and ADR-001 here from `docs/decisions/`
- Created `docs/process/` — moved `CONTRIBUTING.md` here; updated all plan references to `MASTER_PLAN.md`
- Created `docs/archive/prds/` — archived PRD-001, PRD-002, PRD-003 with completion summaries
- Created `docs/archive/plans/` — archived PLAN-001 (superseded) and PLAN-002 (absorbed into MASTER_PLAN.md)
- Created `docs/archive/briefs/` — moved `suggestions.md` here

### Reviews

- Moved `CODE_REVIEW_2026-03-02.md` → `docs/reviews/REVIEW-002_code_review_2026-03-02.md`
- Moved `IMPLEMENTATION_PLAN_2026-03-02.md` → `docs/reviews/REVIEW-002_remediation_plan_2026-03-02.md`
- Updated `docs/reviews/REVIEW_LOG.md` with REVIEW-002 entry

### Removed

- `docs/trd/` — empty after TRD migration to `docs/architecture/`
- `docs/prd/` — empty after PRD archival
- `docs/decisions/` — empty after ADR migration to `docs/architecture/decisions/`
- `docs/plans/` — superseded by `docs/MASTER_PLAN.md`
- `docs/suggestions.md` — moved to `docs/archive/briefs/`

### Updated

- `README.md` — updated project structure, docs links point to new locations, added game status
- `docs/process/CONTRIBUTING.md` — updated all plan references to `MASTER_PLAN.md` and new path structure
- `docs/reviews/REVIEW_LOG.md` — added REVIEW-002 entry

---

## 2026-03-01 — Phase 2: Game Systems

**Tasks:** 2.1, 2.2, 2.3, 2.4, 2.5, 2.6 (PLAN-001)
**Model:** Opus 4.6

### Task 2.1 — Economy System

- Created `systems/economy.py` — crystal extraction, supply routes, market pricing, buy/sell trade
- Added `to_dict()` / `from_dict()` to `CrystalDeposit`, `SupplyRoute`, `CrystalMarket` entities
- Added economy fields to `GameStateData` (crystal_deposits, supply_routes, crystal_market, trade_ledger)
- Updated `GameStateData` serialization for full economy round-trip
- Created `data/economy/economy_data.json` — 6 crystal deposits, 5 supply routes, market config, trade goods
- Added `load_crystal_deposits()`, `load_supply_routes()`, `load_crystal_market()` to `DataLoader`
- Wired `EconomySystem` into `GameSession`
- Created `tests/test_economy.py` — 38 tests covering extraction, discovery, routes, trade, faction economics, serialization

### Task 2.2 — Trade UI

- Created `ui/trade_screen.py` — `TradeScreenState` overlay with buy/sell modes, quantity selection, price display
- Faction-aware pricing with reputation modifiers and trade margin (75% sell/buy ratio)
- Cargo capacity checks, faction reserve limits, trade ledger summary
- Added `open_trade_screen()` to `GameSession` for encounter/dialogue integration

### Task 2.3 — Exploration System

- Created `systems/exploration.py` — `ExplorationSystem` with `Region` and `PointOfInterest` dataclasses
- Region discovery, accessibility, and travel with connected-region validation
- POI discovery via scanning (probability-based), visitation with reward application
- Procedural exploration events with weighted random selection based on region danger
- Full serialization via `get_state_dict()` / `load_state_dict()`
- Created `data/economy/regions.json` — 7 regions with connections, 5 POIs with rewards
- Added `load_regions()`, `load_points_of_interest()` to `DataLoader`
- Created `tests/test_exploration.py` — 16 tests covering regions, travel, POIs, events, serialization

### Task 2.4 — Crew Morale System

- Created `systems/crew_morale.py` — `CrewMoraleSystem` tracking individual and average crew morale
- Morale thresholds: MUTINY (≤20), DISGRUNTLED (≤40), STEADY (≤60), CONTENT (≤80), INSPIRED (>80)
- Combat modifier (0.7x–1.2x) and trade modifier (0.9x–1.1x) based on morale
- Event-driven morale effects: combat victory/defeat, trade outcomes, idle decay
- Faction loyalty checks: crew from hostile factions suffer morale penalties
- Mutiny risk events published when morale drops below threshold
- Created `tests/test_crew_morale.py` — 16 tests covering queries, changes, combat modifiers, loyalty

### Task 2.5 — Faction Conquest AI

- Created `systems/faction_conquest.py` — `FactionConquestAI` with AI-driven faction-vs-faction warfare
- `ConquestAction` dataclass for attack, blockade, diplomacy, and fortify actions
- AI target selection weighted by negative relationships; action type by personality traits
- Resolution: attacks compare military + tactical vs military + stability; blockades reduce reserves
- Diplomacy improves inter-faction relations; fortify boosts military and stability
- Power rankings, threat queries, conflict history tracking
- Created `tests/test_faction_conquest.py` — 8 tests covering planning, all action types, rankings, serialization

### Task 2.6 — Realm Control

- Created `systems/realm_control.py` — `RealmControlSystem` with `RealmState` tracking per-region influence
- Influence-based control: faction with highest influence controls region
- Contested detection when second-place faction has >70% of leader's influence
- Natural drift: home realm influence grows, foreign influence decays
- Conflict result application: winner gains influence, loser loses
- Danger modifiers for contested regions
- Full serialization via `get_state_dict()` / `load_state_dict()`
- Created tests in `test_faction_conquest.py` — 9 tests covering initialization, influence, control changes, territories

### Test Results

- All 151 tests pass (99 previous + 52 new)
- All tests run headless without pygame display context
- EAL verification: zero pygame imports in `core/`, `systems/`, `entities/`

---

## 2026-03-01 — Phase 1: Core Infrastructure

**Tasks:** 1.1, 1.2, 1.3, 1.4 (PLAN-001)
**Model:** Opus 4.6

### Task 1.1 — Save/Load Manager

- Created `core/save_manager.py` — engine-agnostic save/load system with JSON persistence
- Supports 3 save slots with metadata (character name, arc, playtime, timestamp)
- Atomic writes via temp file + `os.replace()` to prevent corruption
- Created `tests/test_save_manager.py` — 12 tests covering round-trip, corruption, slots, deletion

### Task 1.2 — Wire Save/Load into UI

- Updated `core/session.py` — integrated SaveManager, settings, pause menu, and quit-to-menu flow
- Updated `ui/menu.py` — dynamic "Load Game" options based on available save slots
- Pause menu intercepts `Action.PAUSE` from navigation in `GameSession.tick()`
- Load game from menu or pause restores state and relaunches navigation

### Task 1.3 — Pause Menu

- Created `ui/pause_menu.py` — overlay state with Resume / Save / Load / Settings / Quit to Menu
- Quick save to current slot with visual feedback flash
- Follows overlay pattern (semi-transparent background, `machine.pop()` to resume)

### Task 1.4 — Settings Screen

- Created `ui/settings_screen.py` — overlay with music/SFX volume sliders and difficulty toggle
- Settings persisted to `~/.whisper_crystals/settings.json`
- `load_settings()` / `save_settings()` helpers with defaults merging
- Created `tests/test_settings.py` — 5 tests covering round-trip, defaults, corruption, directory creation

### Test Results

- All 61 tests pass (44 previous + 17 new)
- All tests run headless without pygame display context
- EAL verification: zero pygame imports in `core/`, `systems/`, `entities/`

---

## 2026-03-01 — Phase 0: Structural Refactor

**Tasks:** 0.1, 0.2, 0.3, 0.4, 0.5 (PLAN-001)
**Model:** Opus 4.6

### Task 0.1 — Extract GameSession from `__main__.py`

- Created `core/session.py` — engine-agnostic `GameSession` class with all callbacks, state transitions, and system orchestration
- Created `core/config.py` — game constants (screen size, FPS, splash duration)
- Created `engine/startup.py` — pygame-specific splash screen and loading frame rendering
- Created `engine/image_utils.py` — centralised pygame image loading and transformation
- Reduced `__main__.py` from 488 lines to 87 lines (pygame init, engine setup, thin main loop)

### Task 0.2 — Separate CombatState UI from combat logic

- Created `ui/combat_ui.py` — CombatState (GameState subclass) with all rendering and interaction
- Stripped `systems/combat.py` to pure logic only: CombatShip, CombatLog, calculate_damage, dodge_chance
- `systems/combat.py` now has zero imports from `core.interfaces` or `core.state_machine`

### Task 0.3 — Fix Engine Abstraction Layer violations

- Added `draw_image()`, `get_image_size()`, `measure_text()` to `RenderInterface` in `core/interfaces.py`
- Implemented all three in `engine/renderer.py` (PygameRenderer)
- Removed `import pygame` from `ui/menu.py`, `ui/navigation.py`, `ui/dialogue_ui.py`, `ui/cutscene.py`
- All UI files now use `RenderInterface` methods exclusively (draw_image, get_image_size, measure_text)
- **Verification:** zero pygame imports in `core/`, `systems/`, `entities/`, `ui/`

### Task 0.4 — Add missing GameStateTypes, remove dead code

- Added `FACTION_SCREEN`, `SHIP_SCREEN`, `SETTINGS` to `GameStateType` enum
- Updated `ui/faction_screen.py` to use `GameStateType.FACTION_SCREEN`
- Updated `ui/ship_screen.py` to use `GameStateType.SHIP_SCREEN`
- Deleted unused `core/game_loop.py`

### Task 0.5 — GameStateData serialization

- Added `to_dict()` / `from_dict()` to `PlayerDecision` and `GameStateData`
- Fixed `Faction.from_dict()` to accept both `reputation_with_player` and `starting_reputation` keys
- Created `tests/test_game_state_serialization.py` — 5 tests covering fresh/modified round-trip, JSON serialization, faction and NPC registry persistence

### Test Results

- All 44 tests pass (27 original + 17 new/modified)
- All tests run headless without pygame display context

---

## 2026-03-01 — Step 1: Project Management Structure

**Task:** Step 1 (PLAN-001)
**Model:** Opus 4.6 (planning), Haiku (execution)

### Added

- `CLAUDE.md` — Project-level AI agent instructions with architecture rules and conventions
- `docs/CONTRIBUTING.md` — Task workflow guide for AI agents and developers
- `docs/plans/PLAN-001_Implementation_Master_Plan.md` — Full implementation plan (31 tasks across 6 phases)
- `docs/plans/PLAN-001_Task_Tracker.md` — Checkbox-based progress tracker for all tasks
- `docs/reviews/REVIEW_TEMPLATE.md` — Code review template with EAL compliance checklist
- `docs/reviews/REVIEW_LOG.md` — Master review log
- `docs/issues/ISSUE_TEMPLATE.md` — Issue reporting template
- `docs/issues/ISSUE_LOG.md` — Master issue index
- `docs/decisions/ADR_TEMPLATE.md` — Architecture Decision Record template
- `docs/decisions/ADR-001_Project_Structure_Refactor.md` — First ADR documenting the refactor rationale
- `docs/changelog/CHANGELOG.md` — This file

### Directory Structure

- Created archive directories for: plans, reviews, issues, decisions, PRDs, TRDs, design, story
- Created issue tracking directories: open, in-progress, closed
