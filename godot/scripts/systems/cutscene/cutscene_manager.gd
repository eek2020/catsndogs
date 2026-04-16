class_name CutsceneManager
extends Node

## Data-driven cutscene manager for Whisper Crystals.
##
## Reads a dialogue JSON file describing sequences, dialogue, choices, and
## camera moves, then drives the scene accordingly. Designed to be reusable:
## point it at a different JSON file and a different .glb scene and it should
## play any cutscene you author.
##
## Usage (from parent scene):
##   cutscene_manager.start("res://data/cutscenes/no_tail_dialogue.json")
##
## Signals:
##   sequence_started(sequence_id)  — fires at the start of each sequence
##   line_shown(speaker, text)	  — fires for each dialogue line
##   choice_presented(prompt, options) — fires when a choice is shown
##   event_triggered(event_name)	— fires for event-type sequences (combat etc.)
##   cutscene_finished			  — fires when reaching the end sequence

signal sequence_started(sequence_id: String)
signal line_shown(speaker: String, text: String)
signal choice_presented(prompt: String, options: Array)
signal event_triggered(event_name: String)
signal cutscene_finished

## Path to the dialogue JSON file (can be overridden per-cutscene).
@export_file("*.json") var dialogue_path: String = "res://data/cutscenes/no_tail_dialogue.json"

## Path to the camera path JSON (used to build camera keyframes from the .glb companion data).
@export_file("*.json") var camera_path_path: String = "res://data/cutscenes/camera_path.json"

## Seconds per character when the dialogue UI types out text. 0 = instant.
@export var typewriter_speed: float = 0.025

## Whether the cutscene starts automatically on _ready.
@export var autostart: bool = true

# References to sibling nodes — assigned from the parent scene.
var dialogue_ui: Node = null	   # a CutsceneDialogueUI instance
var camera_controller: Node = null # a CameraController instance
var door_node: Node3D = null	   # the Door mesh imported from the .glb
var aristotle_node: Node3D = null  # Aristotle character model
var no_tail_node: Node3D = null	# No Tail character model

# Runtime state.
var _data: Dictionary = {}
var _sequence_map: Dictionary = {}  # id -> sequence dict
var _current_sequence_id: String = ""
var _karma_delta: int = 0
var _recruited: Array[String] = []
var _active: bool = false


func _ready() -> void:
	if autostart:
		call_deferred("start", dialogue_path)


func start(path: String) -> void:
	if not _load_data(path):
		push_error("CutsceneManager: failed to load %s" % path)
		return
	_active = true
	var first_id: String = _data.sequences[0].id
	_run_sequence(first_id)


func _load_data(path: String) -> bool:
	if not FileAccess.file_exists(path):
		push_error("CutsceneManager: file not found: %s" % path)
		return false
	var text := FileAccess.get_file_as_string(path)
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("CutsceneManager: JSON is not a dictionary")
		return false
	_data = parsed
	_sequence_map.clear()
	for seq in _data.sequences:
		_sequence_map[seq.id] = seq
	return true


# ------------------------------------------------------------------
# Sequence dispatch — the main state machine.
# ------------------------------------------------------------------
func _run_sequence(sequence_id: String) -> void:
	if not _sequence_map.has(sequence_id):
		push_error("CutsceneManager: unknown sequence id: %s" % sequence_id)
		_finish()
		return

	_current_sequence_id = sequence_id
	var seq: Dictionary = _sequence_map[sequence_id]
	sequence_started.emit(sequence_id)

	match seq.get("type", ""):
		"camera_sequence":
			await _run_camera_sequence(seq)
		"dialogue":
			await _run_dialogue(seq)
		"choice":
			await _run_choice(seq)
		"event":
			await _run_event(seq)
		_:
			push_warning("Unknown sequence type: %s" % seq.get("type", ""))

	# Auto-advance if the sequence declares a next_sequence (non-choice).
	var next_id: String = seq.get("next_sequence", "")
	if next_id != "" and _active:
		_run_sequence(next_id)


# ------------------------------------------------------------------
# Camera sequence — flies the camera through several keys with dialogue.
# ------------------------------------------------------------------
func _run_camera_sequence(seq: Dictionary) -> void:
	var keys: Array = seq.get("camera_keys", [])
	var lines: Array = seq.get("lines", [])

	# Line-to-key mapping: distribute lines evenly across keys.
	# Simple approach — show each line while camera is at a key.
	for i in range(max(keys.size(), lines.size())):
		if i < keys.size() and camera_controller:
			await camera_controller.move_to_key(keys[i])

		if i < lines.size():
			var line: Dictionary = lines[i]
			await _show_line(line.get("speaker", ""), line.get("text", ""))

	# If there are more lines than keys, show the rest at the final key.
	if lines.size() > keys.size():
		for i in range(keys.size(), lines.size()):
			var line: Dictionary = lines[i]
			await _show_line(line.get("speaker", ""), line.get("text", ""))


# ------------------------------------------------------------------
# Dialogue sequence — plays a list of lines, optionally with door / camera ops.
# ------------------------------------------------------------------
func _run_dialogue(seq: Dictionary) -> void:
	# Move camera if specified.
	var cam_key: String = seq.get("camera_key", "")
	if cam_key != "" and camera_controller:
		await camera_controller.move_to_key(cam_key)

	# Handle door state changes.
	var door_state: String = seq.get("door_state", "")
	if door_state == "opening":
		await _open_door()
	elif door_state == "closing":
		await _close_door()

	# Play dialogue lines.
	var lines: Array = seq.get("lines", [])
	for line in lines:
		# Per-line camera override.
		var line_cam: String = line.get("camera", "")
		if line_cam != "" and camera_controller:
			await camera_controller.move_to_key(line_cam)
		await _show_line(line.get("speaker", ""), line.get("text", ""))


# ------------------------------------------------------------------
# Choice — presents options and waits for selection.
# ------------------------------------------------------------------
func _run_choice(seq: Dictionary) -> void:
	var prompt: String = seq.get("prompt", "")
	var options: Array = seq.get("options", [])
	choice_presented.emit(prompt, options)

	if dialogue_ui == null:
		push_warning("CutsceneManager: no dialogue_ui; auto-selecting first option")
		_apply_choice(options[0])
		return

	var chosen_index: int = await dialogue_ui.choice_made
	if chosen_index < 0 or chosen_index >= options.size():
		chosen_index = 0
	_apply_choice(options[chosen_index])


func _apply_choice(option: Dictionary) -> void:
	_karma_delta += int(option.get("karma", 0))
	if option.has("recruit"):
		_recruited.append(str(option.recruit))
	var next_id: String = option.get("next_sequence", "")
	if next_id != "":
		_run_sequence(next_id)
	else:
		_finish()


# ------------------------------------------------------------------
# Event sequence — emits a signal the parent scene can hook into.
# ------------------------------------------------------------------
func _run_event(seq: Dictionary) -> void:
	var event_name: String = seq.get("event_name", "")
	event_triggered.emit(event_name)
	if event_name == "cutscene_complete":
		_finish()
		return
	# For "combat_encounter" style events, do a simple fade / wait placeholder.
	# The parent scene can intercept event_triggered to do something richer.
	if dialogue_ui and dialogue_ui.has_method("fade_black"):
		await dialogue_ui.fade_black(0.5)
		await get_tree().create_timer(1.0).timeout
		await dialogue_ui.fade_clear(0.5)


# ------------------------------------------------------------------
# Line display helper.
# ------------------------------------------------------------------
func _show_line(speaker: String, text: String) -> void:
	line_shown.emit(speaker, text)
	if dialogue_ui and dialogue_ui.has_method("show_line"):
		await dialogue_ui.show_line(speaker, text, typewriter_speed)
	else:
		# Fallback: print and wait.
		print("[%s] %s" % [speaker, text])
		await get_tree().create_timer(2.0).timeout


# ------------------------------------------------------------------
# Door animation — simple tween slide upward.
# ------------------------------------------------------------------
func _open_door() -> void:
	if door_node != null:
		var start_pos: Vector3 = door_node.position
		var end_pos: Vector3 = start_pos + Vector3(0, 3.2, 0)
		var tween := create_tween()
		tween.set_ease(Tween.EASE_OUT)
		tween.set_trans(Tween.TRANS_CUBIC)
		tween.tween_property(door_node, "position", end_pos, 1.2)
		await tween.finished
	else:
		push_warning("CutsceneManager: Door node not found, skipping animation.")
		await get_tree().create_timer(1.2).timeout
	# Reveal No Tail with a fade-in silhouette effect.
	if no_tail_node:
		_fade_in_character(no_tail_node, 0.8)


## Fade a character node in from invisible over the given duration.
##
## Uses per-surface override materials that are duplicated copies of the
## originals. This contains the transparency mutation to the specific
## MeshInstance3D — imported GLBs often share materials across many mesh
## instances, and the previous implementation mutated the shared resource
## directly, which bled transparency state across unrelated meshes. When
## the tween completes the surface overrides are cleared so the pristine
## originals take over again (CODE_REVIEW §6A.3 fix).
func _fade_in_character(character: Node3D, duration: float) -> void:
	# Collect all MeshInstance3D children.
	var meshes: Array[MeshInstance3D] = []
	_collect_meshes(character, meshes)

	# Per-surface duplicated overrides. Outer array parallels `meshes`; each
	# inner array holds one Material per surface.
	var overrides: Array = []
	for mi in meshes:
		var mesh_overrides: Array = []
		if mi.mesh == null:
			overrides.append(mesh_overrides)
			continue
		for s in range(mi.mesh.get_surface_count()):
			var source: Material = mi.get_active_material(s)
			var dup_mat: Material = source.duplicate() if source != null else StandardMaterial3D.new()
			if dup_mat is StandardMaterial3D:
				var smat := dup_mat as StandardMaterial3D
				smat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
				smat.albedo_color.a = 0.0
			mi.set_surface_override_material(s, dup_mat)
			mesh_overrides.append(dup_mat)
		overrides.append(mesh_overrides)

	character.visible = true

	# Tween alpha from 0 to 1 on the per-surface overrides only.
	var tween := create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_QUAD)
	tween.tween_method(
		func(val: float) -> void:
			for mesh_overrides in overrides:
				for m in mesh_overrides:
					if m is StandardMaterial3D:
						(m as StandardMaterial3D).albedo_color.a = val,
		0.0,
		1.0,
		duration
	)
	await tween.finished

	# Clear the surface overrides — the pristine originals re-take control.
	for mi in meshes:
		if mi.mesh == null:
			continue
		for s in range(mi.mesh.get_surface_count()):
			mi.set_surface_override_material(s, null)


func _collect_meshes(node: Node, out: Array[MeshInstance3D]) -> void:
	if node is MeshInstance3D:
		out.append(node as MeshInstance3D)
	for child in node.get_children():
		_collect_meshes(child, out)


func _close_door() -> void:
	if door_node == null:
		return
	var start_pos: Vector3 = door_node.position
	var end_pos: Vector3 = start_pos - Vector3(0, 3.2, 0)
	var tween := create_tween()
	tween.set_ease(Tween.EASE_IN)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(door_node, "position", end_pos, 1.0)
	await tween.finished


# ------------------------------------------------------------------
# Completion.
# ------------------------------------------------------------------
func _finish() -> void:
	_active = false
	cutscene_finished.emit()
	print("Cutscene finished. Karma delta: %d. Recruited: %s" % [_karma_delta, str(_recruited)])
