# Whisper Crystals — Code Map

> **Auto-generated.** Do not hand-edit. Regenerate via the `codemap` skill or
> `bash .claude/skills/codemap/generate.sh`.
>
> Inputs last changed: **2026-04-17**

Code-anchored index: every section links to real files. This is the
companion to [.claude/PROJECT_INDEX.md](../../.claude/PROJECT_INDEX.md)
(narrative project overview) and [CLAUDE.md](../../CLAUDE.md)
(architecture rules).

## Contents

- [Autoloads](#autoloads)
- [EventBus signals](#eventbus-signals)
- [Core](#core)
- [Entities](#entities)
- [Systems](#systems)
- [Cutscene subsystem](#cutscene-subsystem)
- [World layer](#world-layer)
- [ViewModels](#viewmodels)
- [UI screens](#ui-screens)
- [Scenes](#scenes)
- [Data files](#data-files)
- [Inventory](#inventory)

---

## Autoloads

Registered in [project.godot](../../godot/project.godot) under `[autoload]`.

| Singleton | Script |
|---|---|
| `EventBus` | [godot/scripts/autoload/event_bus.gd](../../godot/scripts/autoload/event_bus.gd) |
| `GameSession` | [godot/scripts/autoload/game_session.gd](../../godot/scripts/autoload/game_session.gd) |
| `MusicManager` | [godot/scripts/autoload/music_manager.gd](../../godot/scripts/autoload/music_manager.gd) |
| `ProceduralMapManager` | [godot/scripts/autoload/procedural_map_manager.gd](../../godot/scripts/autoload/procedural_map_manager.gd) |

## EventBus signals

Single source of truth: [event_bus.gd](../../godot/scripts/autoload/event_bus.gd).
Groups match the `# --- Foo events ---` section headers in that file.

### Combat events

- `combat_hit` — [event_bus.gd:14](../../godot/scripts/autoload/event_bus.gd#L14)
- `combat_miss` — [event_bus.gd:15](../../godot/scripts/autoload/event_bus.gd#L15)
- `combat_victory` — [event_bus.gd:16](../../godot/scripts/autoload/event_bus.gd#L16)
- `combat_defeat` — [event_bus.gd:17](../../godot/scripts/autoload/event_bus.gd#L17)
- `combat_flee` — [event_bus.gd:18](../../godot/scripts/autoload/event_bus.gd#L18)

### Pickup events

- `crystal_pickup` — [event_bus.gd:21](../../godot/scripts/autoload/event_bus.gd#L21)
- `salvage_pickup` — [event_bus.gd:22](../../godot/scripts/autoload/event_bus.gd#L22)

### Encounter events

- `encounter_triggered` — [event_bus.gd:25](../../godot/scripts/autoload/event_bus.gd#L25)
- `dialogue_step_advanced` — [event_bus.gd:26](../../godot/scripts/autoload/event_bus.gd#L26)

### Trade events

- `trade_buy` — [event_bus.gd:29](../../godot/scripts/autoload/event_bus.gd#L29)
- `trade_sell` — [event_bus.gd:30](../../godot/scripts/autoload/event_bus.gd#L30)

### Mission events

- `mission_accepted` — [event_bus.gd:33](../../godot/scripts/autoload/event_bus.gd#L33)
- `mission_completed` — [event_bus.gd:34](../../godot/scripts/autoload/event_bus.gd#L34)
- `mission_failed` — [event_bus.gd:35](../../godot/scripts/autoload/event_bus.gd#L35)

### Save/load events

- `save_game` — [event_bus.gd:38](../../godot/scripts/autoload/event_bus.gd#L38)
- `load_game` — [event_bus.gd:39](../../godot/scripts/autoload/event_bus.gd#L39)

### Narrative events

- `protagonist_selected` — [event_bus.gd:42](../../godot/scripts/autoload/event_bus.gd#L42)
- `arc_advanced` — [event_bus.gd:43](../../godot/scripts/autoload/event_bus.gd#L43)
- `arc_transition_complete` — [event_bus.gd:44](../../godot/scripts/autoload/event_bus.gd#L44)
- `game_ending_reached` — [event_bus.gd:45](../../godot/scripts/autoload/event_bus.gd#L45)

### Audio events

- `volume_changed` — [event_bus.gd:48](../../godot/scripts/autoload/event_bus.gd#L48)

### Faction events

- `faction_score_changed` — [event_bus.gd:51](../../godot/scripts/autoload/event_bus.gd#L51)

### Realm / exploration events

- `realm_control_changed` — [event_bus.gd:54](../../godot/scripts/autoload/event_bus.gd#L54)
- `region_discovered` — [event_bus.gd:55](../../godot/scripts/autoload/event_bus.gd#L55)
- `region_changed` — [event_bus.gd:56](../../godot/scripts/autoload/event_bus.gd#L56)
- `poi_discovered` — [event_bus.gd:57](../../godot/scripts/autoload/event_bus.gd#L57)
- `poi_visited` — [event_bus.gd:58](../../godot/scripts/autoload/event_bus.gd#L58)
- `exploration_event` — [event_bus.gd:59](../../godot/scripts/autoload/event_bus.gd#L59)

### Economy events

- `deposit_depleted` — [event_bus.gd:62](../../godot/scripts/autoload/event_bus.gd#L62)
- `deposit_discovered` — [event_bus.gd:63](../../godot/scripts/autoload/event_bus.gd#L63)
- `route_status_changed` — [event_bus.gd:64](../../godot/scripts/autoload/event_bus.gd#L64)
- `ship_repaired` — [event_bus.gd:65](../../godot/scripts/autoload/event_bus.gd#L65)
- `upgrade_purchased` — [event_bus.gd:66](../../godot/scripts/autoload/event_bus.gd#L66)
- `ship_purchased` — [event_bus.gd:67](../../godot/scripts/autoload/event_bus.gd#L67)

### Conquest events

- `faction_conflict` — [event_bus.gd:70](../../godot/scripts/autoload/event_bus.gd#L70)
- `faction_diplomacy` — [event_bus.gd:71](../../godot/scripts/autoload/event_bus.gd#L71)

### Crew events

- `crew_morale_changed` — [event_bus.gd:74](../../godot/scripts/autoload/event_bus.gd#L74)
- `crew_mutiny_risk` — [event_bus.gd:75](../../godot/scripts/autoload/event_bus.gd#L75)
- `crew_member_recruited` — [event_bus.gd:76](../../godot/scripts/autoload/event_bus.gd#L76)

### Star map events

- `map_purchased` — [event_bus.gd:79](../../godot/scripts/autoload/event_bus.gd#L79)
- `fog_revealed` — [event_bus.gd:80](../../godot/scripts/autoload/event_bus.gd#L80)
- `hidden_location_discovered` — [event_bus.gd:81](../../godot/scripts/autoload/event_bus.gd#L81)
- `cartographer_rescued` — [event_bus.gd:82](../../godot/scripts/autoload/event_bus.gd#L82)
- `region_boundary_reached` — [event_bus.gd:83](../../godot/scripts/autoload/event_bus.gd#L83)

### Astral hazard events

- `hazard_entered` — [event_bus.gd:86](../../godot/scripts/autoload/event_bus.gd#L86)
- `hazard_mitigated` — [event_bus.gd:87](../../godot/scripts/autoload/event_bus.gd#L87)
- `hazard_damage` — [event_bus.gd:88](../../godot/scripts/autoload/event_bus.gd#L88)
- `hazard_status_applied` — [event_bus.gd:89](../../godot/scripts/autoload/event_bus.gd#L89)
- `hazard_status_expired` — [event_bus.gd:90](../../godot/scripts/autoload/event_bus.gd#L90)

### Stat events

- `stats_changed` — [event_bus.gd:93](../../godot/scripts/autoload/event_bus.gd#L93)
- `resonance_shard_found` — [event_bus.gd:94](../../godot/scripts/autoload/event_bus.gd#L94)

### Karma events

- `karma_changed` — [event_bus.gd:97](../../godot/scripts/autoload/event_bus.gd#L97)
- `karma_tier_changed` — [event_bus.gd:98](../../godot/scripts/autoload/event_bus.gd#L98)

### Planet events

- `planet_landed` — [event_bus.gd:101](../../godot/scripts/autoload/event_bus.gd#L101)
- `planet_departed` — [event_bus.gd:102](../../godot/scripts/autoload/event_bus.gd#L102)
- `planet_treasure_found` — [event_bus.gd:103](../../godot/scripts/autoload/event_bus.gd#L103)
- `planet_merchant_interacted` — [event_bus.gd:104](../../godot/scripts/autoload/event_bus.gd#L104)

### Star base events

- `base_docked` — [event_bus.gd:107](../../godot/scripts/autoload/event_bus.gd#L107)
- `base_undocked` — [event_bus.gd:108](../../godot/scripts/autoload/event_bus.gd#L108)
- `artifact_acquired` — [event_bus.gd:109](../../godot/scripts/autoload/event_bus.gd#L109)

### Celestial Codex events

- `codex_layer_changed` — [event_bus.gd:112](../../godot/scripts/autoload/event_bus.gd#L112)

### World layer events

- `world_scene_entered` — [event_bus.gd:115](../../godot/scripts/autoload/event_bus.gd#L115)
- `world_scene_exited` — [event_bus.gd:116](../../godot/scripts/autoload/event_bus.gd#L116)
- `npc_interaction_started` — [event_bus.gd:117](../../godot/scripts/autoload/event_bus.gd#L117)
- `npc_interaction_ended` — [event_bus.gd:118](../../godot/scripts/autoload/event_bus.gd#L118)
- `npc_bark` — [event_bus.gd:119](../../godot/scripts/autoload/event_bus.gd#L119)
- `door_transition` — [event_bus.gd:120](../../godot/scripts/autoload/event_bus.gd#L120)

### Cutscene events

- `cutscene_completed` — [event_bus.gd:123](../../godot/scripts/autoload/event_bus.gd#L123)

### UI navigation

- `ui_select` — [event_bus.gd:126](../../godot/scripts/autoload/event_bus.gd#L126)
- `ui_cancel` — [event_bus.gd:127](../../godot/scripts/autoload/event_bus.gd#L127)
- `ui_navigate` — [event_bus.gd:128](../../godot/scripts/autoload/event_bus.gd#L128)

## Core

Reusable primitives in `godot/scripts/core/`.

- [config.gd](../../godot/scripts/core/config.gd)
- [data_loader.gd](../../godot/scripts/core/data_loader.gd)
- [game_state_data.gd](../../godot/scripts/core/game_state_data.gd)
- [math_utils.gd](../../godot/scripts/core/math_utils.gd)
- [save_manager.gd](../../godot/scripts/core/save_manager.gd)
- [state_machine.gd](../../godot/scripts/core/state_machine.gd)

## Entities

Data models in `godot/scripts/entities/`.

- [character.gd](../../godot/scripts/entities/character.gd)
- [crystal.gd](../../godot/scripts/entities/crystal.gd)
- [encounter.gd](../../godot/scripts/entities/encounter.gd)
- [faction.gd](../../godot/scripts/entities/faction.gd)
- [planet.gd](../../godot/scripts/entities/planet.gd)
- [ship.gd](../../godot/scripts/entities/ship.gd)
- [side_mission.gd](../../godot/scripts/entities/side_mission.gd)
- [star_base.gd](../../godot/scripts/entities/star_base.gd)

## Systems

Gameplay systems in `godot/scripts/systems/` (excluding cutscene subsystem).

- [astral_hazard_system.gd](../../godot/scripts/systems/astral_hazard_system.gd)
- [combat_system.gd](../../godot/scripts/systems/combat_system.gd)
- [condition_evaluator.gd](../../godot/scripts/systems/condition_evaluator.gd)
- [crew_morale_system.gd](../../godot/scripts/systems/crew_morale_system.gd)
- [crew_trait_system.gd](../../godot/scripts/systems/crew_trait_system.gd)
- [economy_system.gd](../../godot/scripts/systems/economy_system.gd)
- [encounter_engine.gd](../../godot/scripts/systems/encounter_engine.gd)
- [exploration_system.gd](../../godot/scripts/systems/exploration_system.gd)
- [faction_conquest_system.gd](../../godot/scripts/systems/faction_conquest_system.gd)
- [faction_system.gd](../../godot/scripts/systems/faction_system.gd)
- [karma_system.gd](../../godot/scripts/systems/karma_system.gd)
- [narrative_system.gd](../../godot/scripts/systems/narrative_system.gd)
- [planet_system.gd](../../godot/scripts/systems/planet_system.gd)
- [realm_control_system.gd](../../godot/scripts/systems/realm_control_system.gd)
- [side_mission_system.gd](../../godot/scripts/systems/side_mission_system.gd)
- [star_base_system.gd](../../godot/scripts/systems/star_base_system.gd)
- [star_map_system.gd](../../godot/scripts/systems/star_map_system.gd)
- [stat_evaluator.gd](../../godot/scripts/systems/stat_evaluator.gd)

## Cutscene subsystem

3D / scripted-cutscene pieces under `godot/scripts/systems/cutscene/`.

- [camera_controller.gd](../../godot/scripts/systems/cutscene/camera_controller.gd)
- [cutscene_manager.gd](../../godot/scripts/systems/cutscene/cutscene_manager.gd)
- [cutscene_scene.gd](../../godot/scripts/systems/cutscene/cutscene_scene.gd)
- [dialogue_ui.gd](../../godot/scripts/systems/cutscene/dialogue_ui.gd)
- [material_applicator.gd](../../godot/scripts/systems/cutscene/material_applicator.gd)

## World layer

Player / NPC / scene-transition controllers in `godot/scripts/world/`.

- [dialogue_manager.gd](../../godot/scripts/world/dialogue_manager.gd)
- [fringe_haven_outpost.gd](../../godot/scripts/world/fringe_haven_outpost.gd)
- [npc_controller.gd](../../godot/scripts/world/npc_controller.gd)
- [player_controller.gd](../../godot/scripts/world/player_controller.gd)
- [scene_transition.gd](../../godot/scripts/world/scene_transition.gd)
- [tavern.gd](../../godot/scripts/world/tavern.gd)

## ViewModels

Per-screen RefCounted wrappers around `GameSession` — the only layer allowed
to touch the session autoload. See CLAUDE.md → "UI ↔ GameSession coupling via
ViewModels".

| ViewModel | Screen controller | Scene |
|---|---|---|
| [combat_view_model.gd](../../godot/scripts/ui/view_models/combat_view_model.gd) | [combat_ui.gd](../../godot/scripts/ui/combat_ui.gd) | [combat_ui.tscn](../../godot/scenes/ui/combat_ui.tscn) |
| [navigation_view_model.gd](../../godot/scripts/ui/view_models/navigation_view_model.gd) | [navigation.gd](../../godot/scripts/ui/navigation.gd) | [navigation.tscn](../../godot/scenes/ui/navigation.tscn) |
| [star_map_view_model.gd](../../godot/scripts/ui/view_models/star_map_view_model.gd) | [star_map_screen.gd](../../godot/scripts/ui/star_map_screen.gd) | [star_map_screen.tscn](../../godot/scenes/ui/star_map_screen.tscn) |

## UI screens

All UI controllers in `godot/scripts/ui/` (top-level). Subfolders
(`combat/`, `star_map/`, `view_models/`) are listed separately.

- [arc_summary.gd](../../godot/scripts/ui/arc_summary.gd)
- [character_select.gd](../../godot/scripts/ui/character_select.gd)
- [combat_ui.gd](../../godot/scripts/ui/combat_ui.gd)
- [cutscene.gd](../../godot/scripts/ui/cutscene.gd)
- [dialogue_ui.gd](../../godot/scripts/ui/dialogue_ui.gd)
- [ending_screen.gd](../../godot/scripts/ui/ending_screen.gd)
- [faction_screen.gd](../../godot/scripts/ui/faction_screen.gd)
- [intro_crawl.gd](../../godot/scripts/ui/intro_crawl.gd)
- [main.gd](../../godot/scripts/ui/main.gd)
- [menu.gd](../../godot/scripts/ui/menu.gd)
- [mission_log.gd](../../godot/scripts/ui/mission_log.gd)
- [navigation.gd](../../godot/scripts/ui/navigation.gd)
- [pause_menu.gd](../../godot/scripts/ui/pause_menu.gd)
- [planet_screen.gd](../../godot/scripts/ui/planet_screen.gd)
- [planet_surface.gd](../../godot/scripts/ui/planet_surface.gd)
- [purchase_screen.gd](../../godot/scripts/ui/purchase_screen.gd)
- [settings_screen.gd](../../godot/scripts/ui/settings_screen.gd)
- [ship_screen.gd](../../godot/scripts/ui/ship_screen.gd)
- [skill_allocation.gd](../../godot/scripts/ui/skill_allocation.gd)
- [splash.gd](../../godot/scripts/ui/splash.gd)
- [star_map_screen.gd](../../godot/scripts/ui/star_map_screen.gd)
- [station_screen.gd](../../godot/scripts/ui/station_screen.gd)
- [theme_builder.gd](../../godot/scripts/ui/theme_builder.gd)
- [trade_screen.gd](../../godot/scripts/ui/trade_screen.gd)

### UI subfolder: combat

- [combat_animations.gd](../../godot/scripts/ui/combat/combat_animations.gd)
- [combat_layout.gd](../../godot/scripts/ui/combat/combat_layout.gd)
- [combat_logic.gd](../../godot/scripts/ui/combat/combat_logic.gd)
- [health_bar.gd](../../godot/scripts/ui/combat/health_bar.gd)

### UI subfolder: star_map

- [star_map_galaxy_layer.gd](../../godot/scripts/ui/star_map/star_map_galaxy_layer.gd)
- [star_map_local_layer.gd](../../godot/scripts/ui/star_map/star_map_local_layer.gd)
- [star_map_region_layer.gd](../../godot/scripts/ui/star_map/star_map_region_layer.gd)

## Scenes

### Entry point

- [main.tscn](../../godot/scenes/main.tscn) — set as `run/main_scene` in project.godot

### UI scenes

- [arc_summary.tscn](../../godot/scenes/ui/arc_summary.tscn)
- [character_select.tscn](../../godot/scenes/ui/character_select.tscn)
- [combat_ui.tscn](../../godot/scenes/ui/combat_ui.tscn)
- [cutscene.tscn](../../godot/scenes/ui/cutscene.tscn)
- [dialogue_ui.tscn](../../godot/scenes/ui/dialogue_ui.tscn)
- [ending_screen.tscn](../../godot/scenes/ui/ending_screen.tscn)
- [faction_screen.tscn](../../godot/scenes/ui/faction_screen.tscn)
- [intro_crawl.tscn](../../godot/scenes/ui/intro_crawl.tscn)
- [menu.tscn](../../godot/scenes/ui/menu.tscn)
- [mission_log.tscn](../../godot/scenes/ui/mission_log.tscn)
- [navigation.tscn](../../godot/scenes/ui/navigation.tscn)
- [pause_menu.tscn](../../godot/scenes/ui/pause_menu.tscn)
- [planet_screen.tscn](../../godot/scenes/ui/planet_screen.tscn)
- [planet_surface.tscn](../../godot/scenes/ui/planet_surface.tscn)
- [purchase_screen.tscn](../../godot/scenes/ui/purchase_screen.tscn)
- [settings_screen.tscn](../../godot/scenes/ui/settings_screen.tscn)
- [ship_screen.tscn](../../godot/scenes/ui/ship_screen.tscn)
- [skill_allocation.tscn](../../godot/scenes/ui/skill_allocation.tscn)
- [splash.tscn](../../godot/scenes/ui/splash.tscn)
- [star_map_screen.tscn](../../godot/scenes/ui/star_map_screen.tscn)
- [station_screen.tscn](../../godot/scenes/ui/station_screen.tscn)
- [trade_screen.tscn](../../godot/scenes/ui/trade_screen.tscn)

### World scenes

- [fringe_haven_outpost.tscn](../../godot/scenes/world/fringe_haven_outpost.tscn)
- [npc.tscn](../../godot/scenes/world/npc.tscn)
- [oakhaven_outpost.tscn](../../godot/scenes/world/oakhaven_outpost.tscn)
- [player.tscn](../../godot/scenes/world/player.tscn)
- [tavern.tscn](../../godot/scenes/world/tavern.tscn)
- [world.tscn](../../godot/scenes/world/world.tscn)

### Cutscene scenes

- [no_tail_cutscene.tscn](../../godot/scenes/cutscenes/no_tail_cutscene.tscn)

## Data files

All JSON content lives under `godot/data/`. Each subfolder is one category.

### data/characters

- [crew_members.json](../../godot/data/characters/crew_members.json)
- [protagonists.json](../../godot/data/characters/protagonists.json)

### data/cutscenes

- [_registry.json](../../godot/data/cutscenes/_registry.json)
- [camera_path.json](../../godot/data/cutscenes/camera_path.json)
- [no_tail_dialogue.json](../../godot/data/cutscenes/no_tail_dialogue.json)

### data/dialogue

- [aristotle_hub.json](../../godot/data/dialogue/aristotle_hub.json)
- [aristotle_internal.json](../../godot/data/dialogue/aristotle_internal.json)
- [dave_hub.json](../../godot/data/dialogue/dave_hub.json)
- [dave_internal.json](../../godot/data/dialogue/dave_internal.json)
- [death_hub.json](../../godot/data/dialogue/death_hub.json)
- [ember_hub.json](../../godot/data/dialogue/ember_hub.json)
- [kiln_hub.json](../../godot/data/dialogue/kiln_hub.json)
- [mira_hub.json](../../godot/data/dialogue/mira_hub.json)
- [wraith_hub.json](../../godot/data/dialogue/wraith_hub.json)

### data/economy

- [economy_data.json](../../godot/data/economy/economy_data.json)
- [regions.json](../../godot/data/economy/regions.json)

### data/encounters

- [arc10_encounters.json](../../godot/data/encounters/arc10_encounters.json)
- [arc10_encounters_dave.json](../../godot/data/encounters/arc10_encounters_dave.json)
- [arc1_encounters.json](../../godot/data/encounters/arc1_encounters.json)
- [arc1_encounters_dave.json](../../godot/data/encounters/arc1_encounters_dave.json)
- [arc2_encounters.json](../../godot/data/encounters/arc2_encounters.json)
- [arc2_encounters_dave.json](../../godot/data/encounters/arc2_encounters_dave.json)
- [arc3_encounters.json](../../godot/data/encounters/arc3_encounters.json)
- [arc3_encounters_dave.json](../../godot/data/encounters/arc3_encounters_dave.json)
- [arc4_encounters.json](../../godot/data/encounters/arc4_encounters.json)
- [arc4_encounters_dave.json](../../godot/data/encounters/arc4_encounters_dave.json)
- [arc5_encounters.json](../../godot/data/encounters/arc5_encounters.json)
- [arc5_encounters_dave.json](../../godot/data/encounters/arc5_encounters_dave.json)
- [arc6_encounters.json](../../godot/data/encounters/arc6_encounters.json)
- [arc6_encounters_dave.json](../../godot/data/encounters/arc6_encounters_dave.json)
- [arc7_encounters.json](../../godot/data/encounters/arc7_encounters.json)
- [arc7_encounters_dave.json](../../godot/data/encounters/arc7_encounters_dave.json)
- [arc8_encounters.json](../../godot/data/encounters/arc8_encounters.json)
- [arc8_encounters_dave.json](../../godot/data/encounters/arc8_encounters_dave.json)
- [arc9_encounters.json](../../godot/data/encounters/arc9_encounters.json)
- [arc9_encounters_dave.json](../../godot/data/encounters/arc9_encounters_dave.json)
- [crew_blood_paw.json](../../godot/data/encounters/crew_blood_paw.json)
- [crew_bombardier.json](../../godot/data/encounters/crew_bombardier.json)
- [crew_charlie.json](../../godot/data/encounters/crew_charlie.json)
- [crew_luna.json](../../godot/data/encounters/crew_luna.json)
- [crew_nine_lives.json](../../godot/data/encounters/crew_nine_lives.json)
- [crew_no_tail.json](../../godot/data/encounters/crew_no_tail.json)
- [crew_silky.json](../../godot/data/encounters/crew_silky.json)
- [crew_thistle.json](../../godot/data/encounters/crew_thistle.json)
- [fairy_cartographer.json](../../godot/data/encounters/fairy_cartographer.json)
- [special_characters.json](../../godot/data/encounters/special_characters.json)

### data/factions

- [faction_registry.json](../../godot/data/factions/faction_registry.json)

### data/hazards

- [astral_hazards.json](../../godot/data/hazards/astral_hazards.json)
- [static_hazards.json](../../godot/data/hazards/static_hazards.json)

### data/items

- [resonance_shards.json](../../godot/data/items/resonance_shards.json)

### data/karma

- [karma_config.json](../../godot/data/karma/karma_config.json)
- [karma_triggers.json](../../godot/data/karma/karma_triggers.json)

### data/maps

- [galaxy_layout.json](../../godot/data/maps/galaxy_layout.json)
- [purchasable_maps.json](../../godot/data/maps/purchasable_maps.json)
- [region_maps.json](../../godot/data/maps/region_maps.json)

### data/planets

- [biomes.json](../../godot/data/planets/biomes.json)
- [planet_registry.json](../../godot/data/planets/planet_registry.json)

### data/ships

- [ship_templates.json](../../godot/data/ships/ship_templates.json)

### data/side_missions

- [arc10_side_missions.json](../../godot/data/side_missions/arc10_side_missions.json)
- [arc10_side_missions_dave.json](../../godot/data/side_missions/arc10_side_missions_dave.json)
- [arc1_side_missions.json](../../godot/data/side_missions/arc1_side_missions.json)
- [arc1_side_missions_dave.json](../../godot/data/side_missions/arc1_side_missions_dave.json)
- [arc2_side_missions.json](../../godot/data/side_missions/arc2_side_missions.json)
- [arc2_side_missions_dave.json](../../godot/data/side_missions/arc2_side_missions_dave.json)
- [arc3_side_missions.json](../../godot/data/side_missions/arc3_side_missions.json)
- [arc3_side_missions_dave.json](../../godot/data/side_missions/arc3_side_missions_dave.json)
- [arc4_side_missions.json](../../godot/data/side_missions/arc4_side_missions.json)
- [arc4_side_missions_dave.json](../../godot/data/side_missions/arc4_side_missions_dave.json)
- [arc5_side_missions.json](../../godot/data/side_missions/arc5_side_missions.json)
- [arc5_side_missions_dave.json](../../godot/data/side_missions/arc5_side_missions_dave.json)
- [arc6_side_missions.json](../../godot/data/side_missions/arc6_side_missions.json)
- [arc6_side_missions_dave.json](../../godot/data/side_missions/arc6_side_missions_dave.json)
- [arc7_side_missions.json](../../godot/data/side_missions/arc7_side_missions.json)
- [arc7_side_missions_dave.json](../../godot/data/side_missions/arc7_side_missions_dave.json)
- [arc8_side_missions.json](../../godot/data/side_missions/arc8_side_missions.json)
- [arc8_side_missions_dave.json](../../godot/data/side_missions/arc8_side_missions_dave.json)
- [arc9_side_missions.json](../../godot/data/side_missions/arc9_side_missions.json)
- [arc9_side_missions_dave.json](../../godot/data/side_missions/arc9_side_missions_dave.json)
- [crew_missions_aristotle.json](../../godot/data/side_missions/crew_missions_aristotle.json)
- [crew_missions_dave.json](../../godot/data/side_missions/crew_missions_dave.json)
- [distress_signals.json](../../godot/data/side_missions/distress_signals.json)

### data/star_bases

- [artifacts.json](../../godot/data/star_bases/artifacts.json)
- [star_bases.json](../../godot/data/star_bases/star_bases.json)

### data/story

- [arc_definitions.json](../../godot/data/story/arc_definitions.json)

## Inventory

| Category | Count |
|---|---|
| Autoloads | 4 |
| EventBus signals | 71 |
| Systems | 18 |
| UI screens (top-level) | 24 |
| ViewModels | 3 |
| Scenes | 30 |
| Data JSON files | 84 |
