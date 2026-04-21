extends Node3D

## Root script for no_tail_cutscene.tscn.
##
## Finds the imported .glb nodes (Door, Aristotle, NoTail, etc.), wires up
## the CutsceneManager, CameraController, and CutsceneDialogueUI, and kicks off
## the cutscene when the scene loads.

@onready var cutscene_manager: CutsceneManager = $CutsceneManager
@onready var camera_controller: CameraController = $CameraController
@onready var camera: Camera3D = $CameraController/Camera3D
@onready var dialogue_ui: CutsceneDialogueUI = $DialogueUI
@onready var world: Node3D = $World


## Cutscene id used when emitting the EventBus completion signal. Must match
## the `id` in `res://data/cutscenes/_registry.json`.
@export var cutscene_id: String = "no_tail_outpost"


func _ready() -> void:
	var door_node: Node3D = _find_node_by_name(world, "Door")
	if door_node == null:
		push_warning("Could not find 'Door' node in the imported scene.")

	var aristotle_node: Node3D = $World/Aristotle if has_node("World/Aristotle") else null
	var no_tail_node: Node3D = $World/NoTail if has_node("World/NoTail") else null
	if aristotle_node == null:
		push_warning("Could not find 'Aristotle' node in the scene.")
	if no_tail_node == null:
		push_warning("Could not find 'NoTail' node in the scene.")

	cutscene_manager.dialogue_ui = dialogue_ui
	cutscene_manager.camera_controller = camera_controller
	cutscene_manager.door_node = door_node
	cutscene_manager.aristotle_node = aristotle_node
	cutscene_manager.no_tail_node = no_tail_node
	camera_controller.camera = camera

	cutscene_manager.choice_presented.connect(
		func(prompt: String, options: Array) -> void:
			dialogue_ui.show_choice(prompt, options)
	)
	cutscene_manager.cutscene_finished.connect(_on_cutscene_finished)
	cutscene_manager.event_triggered.connect(_on_event_triggered)


func _find_node_by_name(root: Node, target: String) -> Node:
	if root.name == target:
		return root
	for child in root.get_children():
		var found: Node = _find_node_by_name(child, target)
		if found:
			return found
	return null


func _on_cutscene_finished() -> void:
	var karma_delta := 0
	var recruited: Array = []
	if cutscene_manager != null:
		if "_karma_delta" in cutscene_manager:
			karma_delta = cutscene_manager.get("_karma_delta")
		if "_recruited" in cutscene_manager:
			var r: Variant = cutscene_manager.get("_recruited")
			if r is Array:
				recruited = r
	EventBus.cutscene_completed.emit(cutscene_id, karma_delta, recruited)
	print("Cutscene %s complete. Karma delta: %d. Recruited: %s" % [
		cutscene_id, karma_delta, str(recruited),
	])


func _on_event_triggered(event_name: String) -> void:
	print("Event: %s" % event_name)
	# Parent scenes can intercept events here to trigger real gameplay
	# (combat encounters, scene transitions, save points, etc.)
