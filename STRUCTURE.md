# Whisper Crystals — Architecture Reference

Compact reference for scene structure, signal wiring, and system responsibilities.

## Game States

`MENU | NAVIGATION | COMBAT | TRADE | DIALOGUE | CUTSCENE | PAUSE | SHIP_SCREEN | FACTION_SCREEN | MISSION_LOG | ENDING`

Stack operations: `switch` (replace top), `push` (overlay), `pop` (return to previous).

## Autoloads

| Singleton | File | Role |
|-----------|------|------|
| EventBus | `scripts/autoload/event_bus.gd` | Pub/sub signal hub |
| GameSession | `scripts/autoload/game_session.gd` | All game state, save/load, inventory, faction scores, story flags, crew |
| MusicManager | `scripts/autoload/music_manager.gd` | BGM tracks, SFX triggers |

## Signal Map

### EventBus Signals

| Signal | Emitted By | Consumed By |
|--------|-----------|-------------|
| encounter_triggered | POI / EncounterEngine | GameManager (dispatch to combat/trade/dialogue) |
| combat_started | CombatSystem | MusicManager, HUD |
| combat_ended | CombatSystem | GameManager (pop back to navigation) |
| trade_opened | TradeScreen | MusicManager |
| trade_closed | TradeScreen | GameManager (pop back to navigation) |
| dialogue_started | DialogueUI | MusicManager |
| dialogue_ended | DialogueUI | GameManager (pop back or chain to combat/trade) |
| faction_changed | FactionSystem | FactionScreen (update bars), HUD |
| crystal_changed | GameSession | HUD (update crystal count) |
| story_flag_set | GameSession | EncounterEngine (check new triggers) |
| arc_changed | EncounterEngine | HUD (update arc label), NavigationState (refresh POIs) |
| mission_updated | SideMissionSystem | HUD, MissionLog |
| mission_completed | SideMissionSystem | HUD, MissionLog |
| state_changed | GameManager/StateMachine | HUD (show/hide) |
| poi_entered | POI | NavigationState |
| game_saved | SaveManager | HUD (confirmation) |
| game_loaded | SaveManager | GameManager (restore state) |
| conquest_update | FactionConquest | HUD (world news) |

## Core Systems (non-autoload)

Instantiated as children of GameManager or the main scene tree.

| System | File | Responsibility |
|--------|------|---------------|
| StateMachine | `core/state_machine.gd` | Push/pop/switch game states |
| DataLoader | `core/data_loader.gd` | Load and parse all JSON from `data/` |
| SaveManager | `core/save_manager.gd` | 3 save slots, atomic writes |
| GameStateData | `core/game_state_data.gd` | Serializable game state container |
| CombatSystem | `systems/combat_system.gd` | Turn-based combat resolution, damage formula, loot |
| FactionSystem | `systems/faction_system.gd` | Reputation tracking, diplomatic state, cascade rules |
| EconomySystem | `systems/economy_system.gd` | Crystal extraction, supply routes, market pricing |
| EncounterEngine | `systems/encounter_engine.gd` | Evaluate triggers, select encounters, dispatch |
| SideMissionSystem | `systems/side_mission_system.gd` | Mission lifecycle, objectives, rewards |
| CrewMoraleSystem | `systems/crew_morale_system.gd` | Morale score, stat modifiers, desertion risk |
| FactionConquest | `systems/faction_conquest_system.gd` | Background faction warfare, territory control, news |
| ExplorationSystem | `systems/exploration_system.gd` | Region discovery, POI scanning |
| NarrativeSystem | `systems/narrative_system.gd` | Story arc progression, dialogue dispatch |
| RealmControlSystem | `systems/realm_control_system.gd` | Region ownership and control |

## UI Screens

| Screen | Scene | Controller | Root Type |
|--------|-------|-----------|-----------|
| Main Menu | `scenes/ui/menu.tscn` | `scripts/ui/menu.gd` | Control |
| Navigation | `scenes/ui/navigation.tscn` | `scripts/ui/navigation.gd` | Control |
| Combat | `scenes/ui/combat.tscn` | `scripts/ui/combat_ui.gd` | Control |
| Dialogue | `scenes/ui/dialogue.tscn` | `scripts/ui/dialogue_ui.gd` | Control |
| Trade | `scenes/ui/trade.tscn` | `scripts/ui/trade_screen.gd` | Control |
| Ship Screen | `scenes/ui/ship_screen.tscn` | `scripts/ui/ship_screen.gd` | Control |
| Faction Screen | `scenes/ui/faction_screen.tscn` | `scripts/ui/faction_screen.gd` | Control |
| Mission Log | `scenes/ui/mission_log.tscn` | `scripts/ui/mission_log.gd` | Control |
| Pause Menu | `scenes/ui/pause_menu.tscn` | `scripts/ui/pause_menu.gd` | Control |
| Ending | `scenes/ui/ending.tscn` | `scripts/ui/ending_screen.gd` | Control |
| Cutscene | `scenes/ui/cutscene.tscn` | `scripts/ui/cutscene.gd` | Control |
| Splash | `scenes/ui/splash.tscn` | `scripts/ui/splash.gd` | Control |

## Data Files (JSON)

```
godot/data/
  encounters/      — arc1-4 encounters + arc1-4 Dave-specific encounters
  dialogue/        — aristotle_hub, dave_hub, death_hub, aristotle_internal, dave_internal
  factions/        — faction_registry.json (8 factions + relationship matrix)
  ships/           — ship_registry.json (templates + upgrades)
  economy/         — regions, supply_routes
  story/           — arc definitions, exit conditions, endings
  side_missions/   — arc1 missions, distress_signals
  characters/      — character profiles
```

## Input Actions

| Action | Keys |
|--------|------|
| move_up | W, Up |
| move_down | S, Down |
| move_left | A, Left |
| move_right | D, Right |
| fire | Space |
| interact | E |
| confirm | Enter |
| pause | Escape |
| ship_screen | S (UI context) |
| faction_screen | F |
| mission_log | M |
| dialogue_1 | 1 |
| dialogue_2 | 2 |
| dialogue_3 | 3 |
