## Faction conquest AI — faction-vs-faction warfare and territorial expansion.
## Mirrors Python systems/faction_conquest.py.
class_name FactionConquestAI
extends RefCounted

var pending_actions: Array = []
var history: Array = []
var _turn_counter: int = 0


class ConquestAction extends Resource:
	@export var action_id: String = ""
	@export var aggressor_id: String = ""
	@export var target_id: String = ""
	@export var action_type: String = ""
	@export var strength: int = 0
	@export var resolved: bool = false
	@export var outcome: String = ""

	func to_dict() -> Dictionary:
		return {
			"action_id": action_id,
			"aggressor_id": aggressor_id,
			"target_id": target_id,
			"action_type": action_type,
			"strength": strength,
			"resolved": resolved,
			"outcome": outcome,
		}

	static func from_dict(data: Dictionary) -> ConquestAction:
		var ca := ConquestAction.new()
		ca.action_id = data.get("action_id", "")
		ca.aggressor_id = data.get("aggressor_id", "")
		ca.target_id = data.get("target_id", "")
		ca.action_type = data.get("action_type", "")
		ca.strength = data.get("strength", 0)
		ca.resolved = data.get("resolved", false)
		ca.outcome = data.get("outcome", "")
		return ca


# ------------------------------------------------------------------
# AI decision-making
# ------------------------------------------------------------------

func plan_faction_actions(game_state: GameStateData) -> Array:
	_turn_counter += 1
	var new_actions: Array = []
	for fid in game_state.faction_registry:
		if fid == "felid_corsairs":
			continue
		var faction: Faction = game_state.faction_registry[fid]
		if randi_range(0, 100) > faction.conquest_intent:
			continue
		var target_id := _pick_target(game_state, fid)
		if target_id.is_empty():
			continue
		var at := _choose_action_type(faction)
		var action := ConquestAction.new()
		action.action_id = "turn%d_%s_%s" % [_turn_counter, fid, target_id]
		action.aggressor_id = fid
		action.target_id = target_id
		action.action_type = at
		action.strength = faction.military_strength
		new_actions.append(action)
	pending_actions.append_array(new_actions)
	return new_actions


func _pick_target(game_state: GameStateData, faction_id: String) -> String:
	var relationships: Dictionary = game_state.relationship_matrix.get(faction_id, {})
	if relationships.is_empty():
		return ""
	var candidates: Array = []
	var total: int = 0
	for target_id in relationships:
		if target_id == faction_id:
			continue
		if not game_state.faction_registry.has(target_id):
			continue
		var rep: int = int(relationships[target_id])
		var weight := maxi(1, 100 - rep + randi_range(0, 30))
		candidates.append([target_id, weight])
		total += weight
	if candidates.is_empty():
		return ""
	var roll := randi_range(1, total)
	var cumulative: int = 0
	for c in candidates:
		cumulative += int(c[1])
		if roll <= cumulative:
			return c[0]
	return candidates[-1][0]


func _choose_action_type(faction: Faction) -> String:
	var aggression: int = faction.aggression_level
	var political: int = faction.political_influence
	var options: Array[String]
	if aggression > 30:
		options = ["attack", "attack", "blockade", "fortify"]
	elif political > 50:
		options = ["diplomacy", "diplomacy", "blockade", "fortify"]
	else:
		options = ["fortify", "blockade", "diplomacy", "attack"]
	return options[randi_range(0, options.size() - 1)]


# ------------------------------------------------------------------
# Action resolution
# ------------------------------------------------------------------

func resolve_actions(game_state: GameStateData) -> Array:
	var resolved_arr: Array = []
	for action in pending_actions:
		if action.resolved:
			continue
		var aggressor: Faction = game_state.faction_registry.get(action.aggressor_id)
		var target: Faction = game_state.faction_registry.get(action.target_id)
		if aggressor == null or target == null:
			action.resolved = true
			action.outcome = "invalid"
			resolved_arr.append(action)
			continue
		match action.action_type:
			"attack":
				_resolve_attack(action, aggressor, target)
			"blockade":
				_resolve_blockade(action, aggressor, target)
			"diplomacy":
				_resolve_diplomacy(game_state, action, aggressor)
			"fortify":
				_resolve_fortify(action, aggressor)
		action.resolved = true
		resolved_arr.append(action)
		history.append(action)
	pending_actions = pending_actions.filter(func(a): return not a.resolved)
	return resolved_arr


func _resolve_attack(action: ConquestAction, aggressor: Faction, target: Faction) -> void:
	var attacker_power: float = aggressor.military_strength + aggressor.tactical_rating * 0.3
	var defender_power: float = target.military_strength + target.internal_stability * 0.2
	if attacker_power > defender_power:
		var loss := mini(10, int((attacker_power - defender_power) * 0.2))
		target.military_strength = maxi(0, target.military_strength - loss)
		var crystal_loot := mini(target.crystal_reserves, loss * 2)
		target.crystal_reserves -= crystal_loot
		aggressor.crystal_reserves += crystal_loot
		target.internal_stability = maxi(0, target.internal_stability - 5)
		action.outcome = "victory"
	else:
		var loss := mini(5, int((defender_power - attacker_power) * 0.1))
		aggressor.military_strength = maxi(0, aggressor.military_strength - loss)
		action.outcome = "repelled"


func _resolve_blockade(action: ConquestAction, aggressor: Faction, target: Faction) -> void:
	if aggressor.military_strength >= target.military_strength * 0.5:
		target.crystal_reserves = maxi(0, target.crystal_reserves - aggressor.military_strength / 5)
		action.outcome = "blockade_effective"
	else:
		action.outcome = "blockade_broken"


func _resolve_diplomacy(game_state: GameStateData, action: ConquestAction, aggressor: Faction) -> void:
	var matrix: Dictionary = game_state.relationship_matrix
	var current: int = matrix.get(action.aggressor_id, {}).get(action.target_id, 0)
	if aggressor.political_influence > 30:
		var new_val := mini(100, current + 10)
		action.outcome = "improved_relations"
		if matrix.has(action.aggressor_id):
			matrix[action.aggressor_id][action.target_id] = new_val
		if matrix.has(action.target_id):
			matrix[action.target_id][action.aggressor_id] = new_val
	else:
		action.outcome = "diplomacy_failed"


func _resolve_fortify(action: ConquestAction, aggressor: Faction) -> void:
	aggressor.military_strength = mini(100, aggressor.military_strength + 3)
	aggressor.internal_stability = mini(100, aggressor.internal_stability + 2)
	action.outcome = "fortified"


# ------------------------------------------------------------------
# Query helpers
# ------------------------------------------------------------------

func get_faction_threats(faction_id: String) -> Array[String]:
	var result: Array[String] = []
	for a in pending_actions:
		if a.target_id == faction_id and a.action_type in ["attack", "blockade"]:
			result.append(a.aggressor_id)
	return result


func get_recent_conflicts(limit: int = 10) -> Array:
	var recent: Array = history.slice(maxi(0, history.size() - limit))
	var result: Array = []
	for i in range(recent.size() - 1, -1, -1):
		result.append(recent[i].to_dict())
	return result


func get_power_rankings(game_state: GameStateData) -> Array:
	var rankings: Array = []
	for fid in game_state.faction_registry:
		var faction: Faction = game_state.faction_registry[fid]
		var power: float = (
			faction.military_strength * 0.5
			+ faction.tactical_rating * 0.3
			+ faction.crystal_reserves * 0.1
			+ faction.internal_stability * 0.1
		)
		rankings.append({
			"faction_id": fid,
			"name": faction.faction_name,
			"military_strength": faction.military_strength,
			"power_score": snappedf(power, 0.1),
		})
	rankings.sort_custom(func(a, b): return a["power_score"] > b["power_score"])
	return rankings
