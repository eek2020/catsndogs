# Whisper Crystals — Architecture Reference

Compact reference for scene structure, signal wiring, and system responsibilities. Reflects the Godot 4.6 codebase as of **2026-04-16 (post-Sprint 5a)**.

## Game States

`SPLASH | MENU | CHARACTER_SELECT | SKILL_ALLOCATION | INTRO_CRAWL | NAVIGATION | COMBAT | TRADE | DIALOGUE | CUTSCENE | PAUSE | SETTINGS | SHIP_SCREEN | FACTION_SCREEN | MISSION_LOG | PURCHASE | STAR_MAP | STATION | PLANET | ARC_SUMMARY | ENDING`

Stack operations: `switch` (replace top), `push` (overlay), `pop` (return to previous).

## Autoloads

| Singleton | File | Role |
| ----------- | ------ | ------ |
| EventBus | `scripts/autoload/event_bus.gd` | Pub/sub signal hub (70 signals) |
| GameSession | `scripts/autoload/game_session.gd` | Master orchestrator — owns all systems, game state, save/load |
| MusicManager | `scripts/autoload/music_manager.gd` | Dynamic BGM tracks, SFX triggers, arc-specific themes |
| ProceduralMapManager | `scripts/autoload/procedural_map_manager.gd` | Wraps `procedural_world_map` addon for navigation/star map backdrops |

## Signal Map

### EventBus Signals

| Signal | Emitted By | Consumed By |
| ----------- | ----------- | ----------- |
| **Combat** | | |
| combat_hit / combat_miss | CombatUI | MusicManager (SFX) |
| combat_victory / combat_defeat / combat_flee | CombatUI | GameSession, MusicManager |
| **Pickups** | | |
| crystal_pickup / salvage_pickup | EncounterEngine outcomes | GameSession |
| **Encounters** | | |
| encounter_triggered | Navigation POIs | GameSession (dispatch) |
| dialogue_step_advanced | DialogueUI | MusicManager |
| **Trade** | | |
| trade_buy / trade_sell | EconomySystem | MusicManager |
| **Missions** | | |
| mission_accepted / mission_completed / mission_failed | SideMissionSystem | MissionLog, Navigation HUD |
| **Save/Load** | | |
| save_game / load_game | PauseMenu | GameSession |
| **Narrative** | | |
| protagonist_selected | CharacterSelect | GameSession |
| arc_advanced | NarrativeSystem | GameSession, MusicManager, Navigation |
| arc_transition_complete | ArcSummary | Navigation (refresh) |
| game_ending_reached | NarrativeSystem | GameSession |
| **Audio** | | |
| volume_changed | SettingsScreen | MusicManager |
| **Factions** | | |
| faction_score_changed | FactionSystem | FactionScreen, Navigation, MusicManager |
| **Realm / Exploration** | | |
| realm_control_changed | RealmControlSystem | Navigation |
| region_discovered / region_changed | ExplorationSystem | Navigation, StarMap |
| poi_discovered / poi_visited | ExplorationSystem | Navigation |
| exploration_event | PlayerController / Navigation | DialogueManager, GameSession |
| **Economy** | | |
| deposit_depleted / deposit_discovered | EconomySystem | Navigation |
| route_status_changed | EconomySystem | Navigation |
| ship_repaired / upgrade_purchased / ship_purchased | EconomySystem | ShipScreen, PurchaseScreen |
| **Conquest** | | |
| faction_conflict / faction_diplomacy | FactionConquestAI | Navigation HUD |
| **Crew** | | |
| crew_morale_changed | CrewMoraleSystem | ShipScreen |
| crew_mutiny_risk | CrewMoraleSystem | Navigation HUD |
| crew_member_recruited | DialogueUI | GameSession |
| **Star Map** | | |
| map_purchased / fog_revealed | StarMapSystem | StarMapScreen, Navigation |
| hidden_location_discovered | StarMapSystem | Navigation |
| cartographer_rescued | EncounterEngine | GameSession → StarMapSystem |
| region_boundary_reached | Navigation | Navigation (transition prompt) |
| **Astral Hazards** | | |
| hazard_entered | Navigation (collision) | MusicManager, Navigation HUD |
| hazard_mitigated | AstralHazardSystem | Navigation HUD |
| hazard_damage | AstralHazardSystem | Navigation HUD |
| hazard_status_applied / hazard_status_expired | AstralHazardSystem | Navigation |
| **Stats** | | |
| stats_changed | SkillAllocation | GameSession |
| resonance_shard_found | EncounterEngine | GameSession |
| **Karma** | | |
| karma_changed | KarmaSystem | Navigation HUD |
| karma_tier_changed | KarmaSystem | Navigation HUD |
| **Planets** | | |
| planet_landed / planet_departed | PlanetSystem | GameSession, Navigation, MusicManager |
| planet_treasure_found / planet_merchant_interacted | PlanetSurface | GameSession |
| **Star Bases** | | |
| base_docked / base_undocked | StarBaseSystem | Navigation, MusicManager |
| artifact_acquired | StarBaseSystem | GameSession |
| **Celestial Codex** | | |
| codex_layer_changed | StarMapScreen | StarMapScreen (internal) |
| **World Layer** | | |
| world_scene_entered / world_scene_exited | SceneTransition | GameSession |
| npc_interaction_started / npc_interaction_ended | NPCController | DialogueManager |
| npc_bark | DialogueManager._show_bark | any bark-listener UI (added Sprint 3c, replaces type:"npc_bark" exploration_event) |
| door_transition | SceneTransition | SceneTransition |
| **UI Navigation** | | |
| ui_select / ui_cancel / ui_navigate | Various UI | Various UI |

## Core Systems (non-autoload)

Instantiated as `RefCounted` objects owned by `GameSession`.

| System | File | Responsibility |
| ----------- | ------ | --------------- |
| StateMachine | `core/state_machine.gd` | Push/pop/switch game states |
| DataLoader | `core/data_loader.gd` | Load and cache all JSON from `data/` |
| SaveManager | `core/save_manager.gd` | 3 save slots, atomic writes, version migration |
| GameStateData | `core/game_state_data.gd` | Serializable game state container (`Resource`) |
| Config | `core/config.gd` | Constants: screen size, FPS |
| CombatSystem | `systems/combat_system.gd` | Damage formula, dodge chance, crew trait bonuses |
| NarrativeSystem | `systems/narrative_system.gd` | Arc progression, exit condition evaluation |
| FactionSystem | `systems/faction_system.gd` | Reputation tracking, diplomatic state, cascade rules |
| EconomySystem | `systems/economy_system.gd` | Crystal extraction, supply routes, market pricing, repair, upgrades, ship purchase |
| EncounterEngine | `systems/encounter_engine.gd` | Evaluate triggers, select encounters, apply outcomes |
| ExplorationSystem | `systems/exploration_system.gd` | Region discovery, POI scanning, travel validation |
| SideMissionSystem | `systems/side_mission_system.gd` | Mission lifecycle, objectives, rewards, distress signals |
| CrewMoraleSystem | `systems/crew_morale_system.gd` | Morale score, stat modifiers, mutiny risk |
| CrewTraitSystem | `systems/crew_trait_system.gd` | Crew definitions, active trait bonuses per ship |
| FactionConquestAI | `systems/faction_conquest_system.gd` | Background faction warfare, territory control |
| RealmControlSystem | `systems/realm_control_system.gd` | Region ownership, influence drift, contested status |
| StarMapSystem | `systems/star_map_system.gd` | Fog of war, spawn zones, purchasable maps, cartographer |
| AstralHazardSystem | `systems/astral_hazard_system.gd` | Static/dynamic hazards, crew mitigation, status effects |
| KarmaSystem | `systems/karma_system.gd` | Karma tracking, tier calculation, price/NPC modifiers |
| StatEvaluator | `systems/stat_evaluator.gd` | Skill checks, stat queries, highest stat |
| PlanetSystem | `systems/planet_system.gd` | Planet landing, departure, treasure, biomes |
| StarBaseSystem | `systems/star_base_system.gd` | Base visibility, docking, services, artifacts |

## Entities

All `extends Resource` with `to_dict()` / `from_dict()` serialization.

| Entity | File | Fields |
| ----------- | ------ | -------- |
| Character | `entities/character.gd` | Species, BehaviourState, 6 stats (cunning/leadership/negotiation/combat_skill/intimidation/stealth) |
| Ship | `entities/ship.gd` | Stats, hull, cargo, crew roster (CrewMember), upgrades (ShipUpgrade) |
| Faction | `entities/faction.gd` | DiplomaticState, reputation, military strength, conquest intent, traits |
| Encounter | `entities/encounter.gd` | Choices, outcomes, dialogue steps, trigger conditions |
| CrystalDeposit | `entities/crystal.gd` | Deposits, SupplyRoute, CrystalMarket (inner classes) |
| SideMission | `entities/side_mission.gd` | Objectives, rewards, status, crew_member_id |
| Planet | `entities/planet.gd` | Biome, merchants, treasures, hostiles |
| StarBase | `entities/star_base.gd` | Type, services, artifacts, reputation gate |

## UI Screens

Screen controllers sit in `scripts/ui/`. Decomposed screens additionally have companion modules under subdirectories:

- `scripts/ui/view_models/` — per-screen `RefCounted` adapters that wrap `GameSession` access. Pattern established in Sprint 3a; used by `combat_ui.gd` (Sprint 3b) and `star_map_screen.gd` (Sprint 5a). Full doc: `docs/architecture/CODE_REVIEW.md` §2.1.
- `scripts/ui/combat/` — focused components for `combat_ui.gd` (`combat_layout.gd`, `combat_logic.gd`, `combat_animations.gd`, `health_bar.gd`).
- `scripts/ui/star_map/` — layer components for the Celestial Codex (`star_map_galaxy_layer.gd`, `star_map_region_layer.gd`, `star_map_local_layer.gd`).

| Screen | Scene | Controller | Type |
| ----------- | ------- | ----------- | ------ |
| Main (root) | `scenes/main.tscn` | `scripts/ui/main.gd` | Control |
| Splash | `scenes/ui/splash.tscn` | `scripts/ui/splash.gd` | Control |
| Main Menu | `scenes/ui/menu.tscn` | `scripts/ui/menu.gd` | Control |
| Character Select | `scenes/ui/character_select.tscn` | `scripts/ui/character_select.gd` | Control |
| Skill Allocation | `scenes/ui/skill_allocation.tscn` | `scripts/ui/skill_allocation.gd` | Control |
| Intro Crawl | `scenes/ui/intro_crawl.tscn` | `scripts/ui/intro_crawl.gd` | Control |
| Navigation | `scenes/ui/navigation.tscn` | `scripts/ui/navigation.gd` | Control |
| Combat | `scenes/ui/combat_ui.tscn` | `scripts/ui/combat_ui.gd` | Control |
| Dialogue | `scenes/ui/dialogue_ui.tscn` | `scripts/ui/dialogue_ui.gd` | Control |
| Trade | `scenes/ui/trade_screen.tscn` | `scripts/ui/trade_screen.gd` | Control |
| Purchase (Shipyard) | `scenes/ui/purchase_screen.tscn` | `scripts/ui/purchase_screen.gd` | Control |
| Ship Screen | `scenes/ui/ship_screen.tscn` | `scripts/ui/ship_screen.gd` | Control |
| Faction Screen | `scenes/ui/faction_screen.tscn` | `scripts/ui/faction_screen.gd` | Control |
| Mission Log | `scenes/ui/mission_log.tscn` | `scripts/ui/mission_log.gd` | Control |
| Pause Menu | `scenes/ui/pause_menu.tscn` | `scripts/ui/pause_menu.gd` | Control |
| Settings | `scenes/ui/settings_screen.tscn` | `scripts/ui/settings_screen.gd` | Control |
| Star Map (Codex) | `scenes/ui/star_map_screen.tscn` | `scripts/ui/star_map_screen.gd` | Control |
| Station | `scenes/ui/station_screen.tscn` | `scripts/ui/station_screen.gd` | Control |
| Planet Screen | `scenes/ui/planet_screen.tscn` | `scripts/ui/planet_screen.gd` | Control |
| Planet Surface | `scenes/ui/planet_surface.tscn` | `scripts/ui/planet_surface.gd` | Control |
| Cutscene | `scenes/ui/cutscene.tscn` | `scripts/ui/cutscene.gd` | Control |
| Arc Summary | `scenes/ui/arc_summary.tscn` | `scripts/ui/arc_summary.gd` | Control |
| Ending | `scenes/ui/ending_screen.tscn` | `scripts/ui/ending_screen.gd` | Control |

## World Scenes

| Scene | Script | Purpose |
| ----------- | -------- | --------- |
| `scenes/world/world.tscn` | — | Base world scene container |
| `scenes/world/player.tscn` | `scripts/world/player_controller.gd` | Player CharacterBody2D (8-dir movement, AnimatedSprite2D) |
| `scenes/world/npc.tscn` | `scripts/world/npc_controller.gd` | NPC CharacterBody2D (patrol AI, NavigationAgent2D, interact zone) |
| `scenes/world/tavern.tscn` | `scripts/world/tavern.gd` | Procedural tavern interior (TileMap) |
| `scenes/world/fringe_haven_outpost.tscn` | `scripts/world/fringe_haven_outpost.gd` | Procedural outpost map (44x25 tiles, 5 tileset sources) |
| `scenes/world/oakhaven_outpost.tscn` | — | Outpost location |

### World Support Scripts

| Script | Purpose |
| ----------- | --------- |
| `scripts/world/dialogue_manager.gd` | Loads dialogue JSON, builds encounters from NPC interactions |
| `scripts/world/scene_transition.gd` | Area2D-based scene transitions with fade, position persistence |

## Data Files (JSON)

```text
godot/data/
  characters/      — protagonists.json, crew_members.json
  dialogue/        — aristotle_hub, dave_hub, death_hub, aristotle_internal, dave_internal
  encounters/      — arc1-10 encounters (Aristotle + Dave), 8 crew encounters, fairy cartographer, special characters
  factions/        — faction_registry.json (8 factions + relationship matrix + cascade rules)
  ships/           — ship_templates.json (templates + upgrades + purchasable ships)
  economy/         — economy_data.json (deposits, routes, market), regions.json
  story/           — arc_definitions.json (10 arcs, exit conditions, endings)
  side_missions/   — arc1-10 missions (Aristotle + Dave), crew missions, distress_signals
  maps/            — region_maps.json, galaxy_layout.json, purchasable_maps.json
  hazards/         — astral_hazards.json, static_hazards.json
  karma/           — karma_config.json, karma_triggers.json
  items/           — resonance_shards.json
  planets/         — planet_registry.json, biomes.json
  star_bases/      — star_bases.json, artifacts.json
```

## Shaders

| Shader | File | Purpose |
| ----------- | ------ | --------- |
| Starfield | `shaders/starfield.gdshader` | Procedural animated starfield for navigation background |
| Hyperspace Jump | `shaders/hyperspace_jump.gdshader` | Arc-transition radial light streak effect |

## Input Actions

| Action | Keys |
| ----------- | ------ |
| move_up | W, Up |
| move_down | S, Down |
| move_left | A, Left |
| move_right | D, Right |
| fire | Space |
| interact | E |
| confirm | Enter |
| cancel | Backspace |
| pause | Escape |
| skip | Escape |
| menu_select | R |
| mission_log | M |
| repair | T |
| star_map | F2 |

## Addon

| Addon | Path | Purpose |
| ----------- | ------ | --------- |
| procedural_world_map | `addons/procedural_world_map/` | FastNoiseLite-based procedural map rendering (MIT, Edwin Cox) |
