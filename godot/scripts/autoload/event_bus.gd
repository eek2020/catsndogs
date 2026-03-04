## Global event bus — pub/sub signal hub for decoupled communication.
##
## Replaces Python EventBus. All game systems connect to these signals.
## Usage:
##   EventBus.combat_hit.emit()
##   EventBus.combat_hit.connect(_on_combat_hit)
extends Node

# --- Combat events ---
signal combat_hit
signal combat_miss
signal combat_victory
signal combat_defeat
signal combat_flee

# --- Pickup events ---
signal crystal_pickup
signal salvage_pickup

# --- Encounter events ---
signal encounter_triggered

# --- Trade events ---
signal trade_buy
signal trade_sell

# --- Mission events ---
signal mission_accepted
signal mission_completed
signal mission_failed

# --- Save/load events ---
signal save_game
signal load_game

# --- Narrative events ---
signal arc_advanced(old_arc: String, new_arc: String)
signal game_ending_reached

# --- Audio events ---
signal volume_changed(volume: float)

# --- Faction events ---
signal faction_score_changed(faction_id: String, delta: int)

# --- Realm / exploration events ---
signal realm_control_changed(region_id: String, old_controller: String, new_controller: String)
signal region_discovered(region_id: String)
signal region_changed(old_region: String, new_region: String)
signal poi_discovered(poi_id: String)
signal poi_visited(poi_id: String)
signal exploration_event(event_data: Dictionary)

# --- Economy events ---
signal deposit_depleted(deposit_id: String)
signal deposit_discovered(deposit_id: String)
signal route_status_changed(route_id: String, new_status: String)
signal ship_repaired(current_hull: int, max_hull: int)
signal upgrade_purchased(upgrade_id: String)
signal ship_purchased(template_id: String)

# --- Conquest events ---
signal faction_conflict(aggressor_id: String, target_id: String, outcome: String)
signal faction_diplomacy(aggressor_id: String, target_id: String, outcome: String)

# --- Crew events ---
signal crew_morale_changed(average_morale: int)
signal crew_mutiny_risk(crew_id: String)

# --- UI navigation ---
signal ui_select
signal ui_cancel
signal ui_navigate
