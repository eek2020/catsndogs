## Scene transition — Area2D-based door detection with fade transitions.
## Attach to an Area2D in the world. When the player enters, triggers a scene change.
extends Area2D

@export var target_scene_path: String = ""
@export var spawn_position: Vector2 = Vector2.ZERO
@export var spawn_facing: String = "down"
@export var transition_label: String = ""

const FADE_DURATION: float = 0.4


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if not (body.is_in_group("player") or body.name == "Player"):
		return
	if target_scene_path.is_empty():
		return
	_do_transition(body)


func _do_transition(player: Node2D) -> void:
	# Disable player input during transition
	player.set_physics_process(false)
	player.set_process_unhandled_input(false)

	# Store return position in GameSession
	var current_scene_path: String = player.get_tree().current_scene.scene_file_path
	var facing: String = player.get("_facing") if "_facing" in player else "down"
	GameSession.store_return_position(current_scene_path, player.global_position, facing)

	# Fade out
	var overlay: ColorRect = _get_transition_overlay()
	if overlay:
		var tween := create_tween()
		tween.tween_property(overlay, "color", Color(0, 0, 0, 1), FADE_DURATION)
		await tween.finished

	# Change scene
	get_tree().change_scene_to_file(target_scene_path)

	# Fade in after one frame (new scene is loaded)
	await get_tree().process_frame
	await get_tree().process_frame

	# Position player at spawn point in the new scene
	_position_player_in_new_scene()

	var new_overlay: ColorRect = _get_transition_overlay()
	if new_overlay:
		new_overlay.color = Color(0, 0, 0, 1)
		var tween := create_tween()
		tween.tween_property(new_overlay, "color", Color(0, 0, 0, 0), FADE_DURATION)


func _position_player_in_new_scene() -> void:
	# Find the player in the new scene and set position
	var players: Array[Node] = get_tree().get_nodes_in_group("player")
	if players.is_empty():
		return
	var player: Node2D = players[0] as Node2D
	if player == null:
		return
	if spawn_position != Vector2.ZERO:
		player.global_position = spawn_position
	if "_facing" in player and not spawn_facing.is_empty():
		player.set("_facing", spawn_facing)


func _get_transition_overlay() -> ColorRect:
	var main: Node = get_tree().current_scene
	if main == null:
		return null
	return main.get_node_or_null("TransitionOverlay") as ColorRect
