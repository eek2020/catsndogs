## Faction system — reputation tracking, cascade rules, diplomatic state.
## Mirrors Python systems/faction_system.py.
class_name FactionSystem
extends RefCounted


func change_reputation(
	game_state: GameStateData,
	faction_id: String,
	delta: int,
	apply_cascade: bool = true,
) -> void:
	var faction: Faction = game_state.faction_registry.get(faction_id)
	if faction == null:
		return
	var old_score: int = faction.reputation_with_player
	faction.reputation_with_player = clampi(old_score + delta, -100, 100)
	faction.update_diplomatic_state()
	EventBus.faction_score_changed.emit(faction_id, faction.reputation_with_player - old_score)
	if apply_cascade:
		_apply_cascade(game_state, faction_id, delta)


func _apply_cascade(
	game_state: GameStateData,
	trigger_faction_id: String,
	delta: int,
) -> void:
	for rule in game_state.cascade_rules:
		if rule.get("trigger_faction") == trigger_faction_id:
			var affected_id: String = rule.get("affected_faction", "")
			var ratio: float = rule.get("cascade_ratio", 0.0)
			if affected_id != "" and game_state.faction_registry.has(affected_id):
				var cascade_delta := int(delta * ratio)
				if cascade_delta != 0:
					change_reputation(game_state, affected_id, cascade_delta, false)


func get_diplomatic_state(
	game_state: GameStateData,
	faction_id: String,
) -> int:
	var faction: Faction = game_state.faction_registry.get(faction_id)
	if faction == null:
		return -1
	return faction.diplomatic_state


func get_all_standings(game_state: GameStateData) -> Array:
	var standings: Array = []
	for fid in game_state.faction_registry:
		var faction: Faction = game_state.faction_registry[fid]
		standings.append({
			"faction_id": fid,
			"name": faction.faction_name,
			"reputation": faction.reputation_with_player,
			"state": faction.diplomatic_state,
			"ideology": faction.ideology,
			"species": faction.species,
		})
	standings.sort_custom(func(a, b):
		if a["faction_id"] == "felid_corsairs":
			return true
		if b["faction_id"] == "felid_corsairs":
			return false
		return a["reputation"] > b["reputation"]
	)
	return standings
