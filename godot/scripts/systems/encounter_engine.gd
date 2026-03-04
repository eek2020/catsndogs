## Encounter engine — evaluates triggers, dispatches encounters.
## Mirrors Python systems/encounter_engine.py.
class_name EncounterEngine
extends RefCounted

var data_loader: DataLoader
var encounter_table: Array = []  # Array of Encounter


func _init(p_data_loader: DataLoader) -> void:
	data_loader = p_data_loader


func load_encounters(arc_id: String) -> void:
	encounter_table = data_loader.load_encounters(arc_id)


func check_triggers(game_state: GameStateData) -> Encounter:
	var eligible := _get_eligible_encounters(game_state)
	if eligible.is_empty():
		return null
	return eligible[0]


func get_available_encounters(game_state: GameStateData) -> Array:
	return _get_eligible_encounters(game_state)


func _get_eligible_encounters(game_state: GameStateData) -> Array:
	var result: Array = []
	var sorted_table := encounter_table.duplicate()
	sorted_table.sort_custom(func(a, b): return a.priority > b.priority)
	for encounter in sorted_table:
		if not encounter.repeatable and encounter.encounter_id in game_state.completed_encounters:
			continue
		if _evaluate_conditions(encounter.trigger_conditions, game_state):
			result.append(encounter)
	return result


func _evaluate_conditions(conditions: Dictionary, game_state: GameStateData) -> bool:
	for key in conditions:
		var expected = conditions[key]
		if key == "current_arc":
			if game_state.current_arc != expected:
				return false
		else:
			var actual = game_state.story_flags.get(key)
			if expected == "!null":
				if actual == null:
					return false
			else:
				if actual == null and expected is bool:
					actual = false
				if actual != expected:
					return false
	return true


func apply_choice_outcome(
	game_state: GameStateData,
	encounter: Encounter,
	choice_index: int,
) -> String:
	var choice: Encounter.EncounterChoice = encounter.choices[choice_index]
	var outcome: Encounter.EncounterOutcome = choice.outcome

	# Set story flags
	for flag in outcome.story_flags_set:
		game_state.story_flags[flag] = true

	# Clear story flags
	for flag in outcome.story_flags_cleared:
		game_state.story_flags.erase(flag)

	# Apply resource changes
	for resource_key in outcome.resource_changes:
		var delta: int = outcome.resource_changes[resource_key]
		if resource_key == "crystal_inventory":
			game_state.crystal_inventory = maxi(0, game_state.crystal_inventory + delta)
		elif resource_key == "crystal_quality":
			game_state.crystal_quality = clampi(game_state.crystal_quality + delta, 1, 5)
		elif resource_key == "salvage":
			game_state.salvage = maxi(0, game_state.salvage + delta)

	# Apply faction reputation changes
	for faction_id in outcome.faction_changes:
		var delta: int = outcome.faction_changes[faction_id]
		if game_state.faction_registry.has(faction_id):
			var faction: Faction = game_state.faction_registry[faction_id]
			faction.reputation_with_player = clampi(faction.reputation_with_player + delta, -100, 100)
			faction.update_diplomatic_state()
			EventBus.faction_score_changed.emit(faction_id, delta)

	# Record decision
	var pd := GameStateData.PlayerDecision.new()
	pd.decision_id = "%s_%s" % [encounter.encounter_id, choice.choice_id]
	pd.encounter_id = encounter.encounter_id
	pd.choice_id = choice.choice_id
	pd.arc_id = encounter.arc_id
	pd.timestamp = game_state.playtime_seconds
	pd.outcome_weight = choice.outcome_weight
	game_state.player_decisions.append(pd)

	# Mark encounter as completed
	if encounter.encounter_id not in game_state.completed_encounters:
		game_state.completed_encounters.append(encounter.encounter_id)

	EventBus.encounter_triggered.emit()
	return outcome.description
