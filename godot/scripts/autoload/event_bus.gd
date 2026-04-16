## Global event bus — pub/sub signal hub for decoupled communication.
##
## Replaces Python EventBus. All game systems connect to these signals.
## Usage:
##   EventBus.combat_hit.emit()
##   EventBus.combat_hit.connect(_on_combat_hit)
##
## All signals are emitted from external files (pub/sub), so Godot considers
## them "unused" at this declaration site. Suppress globally (Issue #12).
@warning_ignore("unused_signal")
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
signal dialogue_step_advanced(encounter_id: String, step_index: int)

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
signal protagonist_selected(protagonist_id: String)
signal arc_advanced(old_arc: String, new_arc: String)
signal arc_transition_complete(new_arc: String)
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
signal crew_member_recruited(crew_id: String, protagonist_id: String)

# --- Star map events ---
signal map_purchased(region_id: String)
signal fog_revealed(region_id: String, percentage: float)
signal hidden_location_discovered(poi_id: String)
signal cartographer_rescued
signal region_boundary_reached(from_region: String, to_region: String)

# --- Astral hazard events ---
signal hazard_entered(hazard_id: String, hazard_type: String)
signal hazard_mitigated(hazard_id: String, crew_id: String)
signal hazard_damage(hazard_id: String, damage: int)
signal hazard_status_applied(effect_id: String, duration: float)
signal hazard_status_expired(effect_id: String)

# --- Stat events ---
signal stats_changed(character_id: String)
signal resonance_shard_found(shard_id: String)

# --- Karma events ---
signal karma_changed(old_value: int, new_value: int, reason: String)
signal karma_tier_changed(old_tier: String, new_tier: String)

# --- Planet events ---
signal planet_landed(planet_id: String)
signal planet_departed(planet_id: String)
signal planet_treasure_found(treasure_id: String)
signal planet_merchant_interacted(merchant_id: String)

# --- Star base events ---
signal base_docked(base_id: String)
signal base_undocked(base_id: String)
signal artifact_acquired(artifact_id: String)

# --- Celestial Codex events ---
signal codex_layer_changed(layer_name: String)

# --- World layer events ---
signal world_scene_entered(region_id: String)
signal world_scene_exited(region_id: String)
signal npc_interaction_started(npc_id: String)
signal npc_interaction_ended(npc_id: String)
signal npc_bark(npc_name: String, text: String)
signal door_transition(from_scene: String, to_scene: String)

# --- UI navigation ---
signal ui_select
signal ui_cancel
signal ui_navigate
