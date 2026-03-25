## Encounter engine — evaluates triggers, dispatches encounters.
## Mirrors Python systems/encounter_engine.py.
class_name EncounterEngine
extends RefCounted

var data_loader: DataLoader
var encounter_table: Array = []  # Array of Encounter


func _init(p_data_loader: DataLoader) -> void:
	data_loader = p_data_loader


func load_encounters(arc_id: String, suffix: String = "") -> void:
	encounter_table = data_loader.load_encounters(arc_id, suffix)


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
	# Apply crew trait discovery/detection bonuses to effective priority
	var discovery_bonus: float = 0.0
	var ambush_bonus: float = 0.0
	if GameSession.crew_trait_system != null and game_state.player_ship != null:
		discovery_bonus = GameSession.crew_trait_system.get_bonus(game_state.player_ship, "exploration_discovery_rate")
		ambush_bonus = GameSession.crew_trait_system.get_bonus(game_state.player_ship, "ambush_detection")
	sorted_table.sort_custom(func(a, b):
		var a_pri: float = a.priority
		var b_pri: float = b.priority
		if discovery_bonus > 0.0:
			if a.encounter_type == "exploration":
				a_pri *= (1.0 + discovery_bonus)
			if b.encounter_type == "exploration":
				b_pri *= (1.0 + discovery_bonus)
		if ambush_bonus > 0.0:
			if a.encounter_type == "combat":
				a_pri *= (1.0 + ambush_bonus)
			if b.encounter_type == "combat":
				b_pri *= (1.0 + ambush_bonus)
		return a_pri > b_pri
	)
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
		elif key == "highest_stat":
			if game_state.player_character == null:
				return false
			if StatEvaluator.get_highest_stat(game_state.player_character) != expected:
				return false
		elif key.begins_with("min_"):
			if game_state.player_character == null:
				return false
			var stat_name: String = key.substr(4)
			if not StatEvaluator.check_threshold(game_state.player_character, stat_name, int(expected)):
				return false
		elif key == "karma_tier":
			if GameSession.karma_system != null:
				if GameSession.karma_system.get_tier(game_state) != expected:
					return false
		else:
			var actual = game_state.story_flags.get(key)
			if expected is String and expected == "!null":
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
		if flag == "fairy_cartographer_rescued":
			GameSession.star_map_system.on_cartographer_rescued()

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

	# Apply karma change
	if outcome.karma_delta != 0 and GameSession.karma_system != null:
		var karma_reason: String = "%s:%s" % [encounter.encounter_id, choice.choice_id]
		GameSession.karma_system.change_karma(game_state, outcome.karma_delta, karma_reason)

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

	# NOTE: arc-exit check is NOT deferred here — the caller is responsible
	# for popping the dialogue overlay first, then triggering the arc check.
	# See dialogue_ui.gd _on_legacy_choice_selected and _end_dialogue.

	return outcome.description


## Apply a mid-dialogue choice outcome without completing the encounter.
## Used during multi-step dialogue when a choice is made but the conversation continues.
func apply_dialogue_step_outcome(
	game_state: GameStateData,
	encounter: Encounter,
	choice: Encounter.DialogueStepChoice,
) -> void:
	var outcome: Encounter.EncounterOutcome = choice.outcome
	if outcome == null:
		return

	# Set story flags
	for flag in outcome.story_flags_set:
		game_state.story_flags[flag] = true
		if flag == "fairy_cartographer_rescued":
			GameSession.star_map_system.on_cartographer_rescued()

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

	# Apply karma change
	if outcome.karma_delta != 0 and GameSession.karma_system != null:
		var karma_reason: String = "%s:%s" % [encounter.encounter_id, choice.choice_id]
		GameSession.karma_system.change_karma(game_state, outcome.karma_delta, karma_reason)

	# Record decision
	var pd := GameStateData.PlayerDecision.new()
	pd.decision_id = "%s_%s" % [encounter.encounter_id, choice.choice_id]
	pd.encounter_id = encounter.encounter_id
	pd.choice_id = choice.choice_id
	pd.arc_id = encounter.arc_id
	pd.timestamp = game_state.playtime_seconds
	pd.outcome_weight = 0.0
	game_state.player_decisions.append(pd)


## Mark an encounter as completed and check arc progression.
## Called once at the end of a multi-step dialogue conversation.
func complete_encounter(game_state: GameStateData, encounter: Encounter) -> void:
	if encounter.encounter_id not in game_state.completed_encounters:
		game_state.completed_encounters.append(encounter.encounter_id)

	EventBus.encounter_triggered.emit()

	# Defer arc-exit check so the dialogue overlay can pop itself first.
	GameSession.call_deferred("_deferred_arc_check")
