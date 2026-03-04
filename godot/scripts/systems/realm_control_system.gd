## Realm control system — regional dominance and faction territorial presence.
## Mirrors Python systems/realm_control.py.
class_name RealmControlSystem
extends RefCounted

var realm_states: Dictionary = {}


class RealmState extends Resource:
	@export var region_id: String = ""
	@export var controlling_faction: String = ""
	@export var faction_influence: Dictionary = {}
	@export var contested: bool = false
	@export var danger_modifier: int = 0

	func to_dict() -> Dictionary:
		return {
			"region_id": region_id,
			"controlling_faction": controlling_faction,
			"faction_influence": faction_influence.duplicate(),
			"contested": contested,
			"danger_modifier": danger_modifier,
		}

	static func from_dict(data: Dictionary) -> RealmState:
		var rs := RealmState.new()
		rs.region_id = data.get("region_id", "")
		rs.controlling_faction = data.get("controlling_faction", "")
		rs.faction_influence = data.get("faction_influence", {})
		rs.contested = data.get("contested", false)
		rs.danger_modifier = data.get("danger_modifier", 0)
		return rs


func initialize_realms(game_state: GameStateData) -> void:
	var region_to_faction: Dictionary = {}
	for fid in game_state.faction_registry:
		var faction: Faction = game_state.faction_registry[fid]
		var realm: String = faction.realm
		if realm != "":
			if not region_to_faction.has(realm):
				region_to_faction[realm] = []
			region_to_faction[realm].append(fid)
	for region_id in region_to_faction:
		var faction_ids: Array = region_to_faction[region_id]
		var influence: Dictionary = {}
		var controller: String = ""
		var max_inf: float = 0.0
		for fid in faction_ids:
			var faction: Faction = game_state.faction_registry[fid]
			var inf: float = (
				faction.military_strength * 0.3
				+ faction.political_influence * 0.4
				+ faction.crystal_reserves * 0.1
				+ faction.internal_stability * 0.2
			)
			influence[fid] = snappedf(inf, 0.1)
			if inf > max_inf:
				max_inf = inf
				controller = fid
		var sorted_inf: Array = influence.values().duplicate()
		sorted_inf.sort()
		sorted_inf.reverse()
		var is_contested: bool = sorted_inf.size() > 1 and sorted_inf[1] > sorted_inf[0] * 0.7
		var rs := RealmState.new()
		rs.region_id = region_id
		rs.controlling_faction = controller
		rs.faction_influence = influence
		rs.contested = is_contested
		realm_states[region_id] = rs


func add_influence(region_id: String, faction_id: String, amount: float) -> void:
	var state: RealmState = realm_states.get(region_id)
	if state == null:
		state = RealmState.new()
		state.region_id = region_id
		realm_states[region_id] = state
	var current: float = state.faction_influence.get(faction_id, 0.0)
	state.faction_influence[faction_id] = clampf(current + amount, 0.0, 100.0)
	_recalculate_control(state)


func remove_influence(region_id: String, faction_id: String, amount: float) -> void:
	add_influence(region_id, faction_id, -amount)


func _recalculate_control(state: RealmState) -> void:
	if state.faction_influence.is_empty():
		state.controlling_faction = ""
		state.contested = false
		return
	var sorted_factions: Array = []
	for fid in state.faction_influence:
		sorted_factions.append([fid, state.faction_influence[fid]])
	sorted_factions.sort_custom(func(a, b): return a[1] > b[1])
	var new_controller: String = sorted_factions[0][0]
	var top_inf: float = sorted_factions[0][1]
	state.contested = (
		sorted_factions.size() > 1
		and sorted_factions[1][1] > top_inf * 0.7
	)
	state.danger_modifier = 2 if state.contested else 0
	if new_controller != state.controlling_faction and top_inf > 0:
		state.controlling_faction = new_controller


func apply_conflict_result(region_id: String, winner_id: String, loser_id: String, intensity: float = 10.0) -> void:
	add_influence(region_id, winner_id, intensity)
	remove_influence(region_id, loser_id, intensity * 0.7)


func update_realm_control(game_state: GameStateData) -> void:
	for region_id in realm_states:
		var state: RealmState = realm_states[region_id]
		for fid in state.faction_influence.keys():
			var faction: Faction = game_state.faction_registry.get(fid)
			if faction == null:
				continue
			if faction.realm == region_id:
				add_influence(region_id, fid, 1.0)
			else:
				var current: float = state.faction_influence.get(fid, 0.0)
				if current > 0:
					remove_influence(region_id, fid, 0.5)


func get_region_controller(region_id: String) -> String:
	var state: RealmState = realm_states.get(region_id)
	return state.controlling_faction if state else ""


func is_contested(region_id: String) -> bool:
	var state: RealmState = realm_states.get(region_id)
	return state.contested if state else false


func get_region_danger(region_id: String) -> int:
	var state: RealmState = realm_states.get(region_id)
	return state.danger_modifier if state else 0


func get_faction_territories(faction_id: String) -> Array[String]:
	var result: Array[String] = []
	for rid in realm_states:
		if realm_states[rid].controlling_faction == faction_id:
			result.append(rid)
	return result


func get_realm_overview() -> Array:
	var overview: Array = []
	for rid in realm_states:
		var state: RealmState = realm_states[rid]
		overview.append({
			"region_id": rid,
			"controller": state.controlling_faction,
			"contested": state.contested,
			"danger": state.danger_modifier,
			"influence": state.faction_influence.duplicate(),
		})
	overview.sort_custom(func(a, b): return a["region_id"] < b["region_id"])
	return overview


func get_state_dict() -> Dictionary:
	var result: Dictionary = {}
	for rid in realm_states:
		result[rid] = realm_states[rid].to_dict()
	return result


func load_state_dict(data: Dictionary) -> void:
	realm_states.clear()
	for rid in data:
		realm_states[rid] = RealmState.from_dict(data[rid])
