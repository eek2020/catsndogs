## Narrative system — tracks story flags, arc progression, exit conditions.
## Mirrors Python systems/narrative.py.
class_name NarrativeSystem
extends RefCounted

var data_loader: DataLoader
var arc_definitions: Array = []
var _loaded: bool = false


func _init(p_data_loader: DataLoader) -> void:
	data_loader = p_data_loader


func load_arcs() -> void:
	arc_definitions = data_loader.load_arc_definitions()
	_loaded = true


func get_current_arc_def(game_state: GameStateData) -> Dictionary:
	if not _loaded:
		load_arcs()
	for arc in arc_definitions:
		if arc["arc_id"] == game_state.current_arc:
			return arc
	return {}


func check_arc_exit(game_state: GameStateData) -> bool:
	var arc_def := get_current_arc_def(game_state)
	if arc_def.is_empty():
		return false
	var exit_conditions: Dictionary = arc_def.get("exit_conditions", {})
	if exit_conditions.is_empty():
		return false
	for flag_name in exit_conditions:
		var expected = exit_conditions[flag_name]
		var actual = game_state.story_flags.get(flag_name)
		if expected == "!null":
			if actual == null:
				return false
		elif actual != expected:
			return false
	return true


func advance_arc(game_state: GameStateData) -> String:
	var arc_def := get_current_arc_def(game_state)
	if arc_def.is_empty():
		return ""
	var next_arc_id: String = arc_def.get("next_arc_id", "")
	if next_arc_id.is_empty():
		EventBus.game_ending_reached.emit()
		return ""
	var old_arc := game_state.current_arc
	game_state.current_arc = next_arc_id
	EventBus.arc_advanced.emit(old_arc, next_arc_id)
	return next_arc_id


func get_arc_title(arc_id: String) -> String:
	if not _loaded:
		load_arcs()
	for arc in arc_definitions:
		if arc["arc_id"] == arc_id:
			return arc.get("title", arc_id)
	return arc_id


func get_arc_progress(game_state: GameStateData) -> Dictionary:
	var arc_def := get_current_arc_def(game_state)
	if arc_def.is_empty():
		return {}
	var exit_conditions: Dictionary = arc_def.get("exit_conditions", {})
	var progress: Dictionary = {}
	for flag_name in exit_conditions:
		var expected = exit_conditions[flag_name]
		var actual = game_state.story_flags.get(flag_name)
		if expected == "!null":
			progress[flag_name] = actual != null
		else:
			progress[flag_name] = actual == expected
	return progress
