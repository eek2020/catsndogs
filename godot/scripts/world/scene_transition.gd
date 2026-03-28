## Scene transition — Area2D-based door detection with fade transitions.
## Attach to an Area2D in the world. When the player enters, triggers a scene change.
extends Area2D

@export var target_scene_path: String = ""
@export var spawn_position: Vector2 = Vector2.ZERO
@export var spawn_facing: String = "down"
@export var transition_label: String = ""

const FADE_DURATION: float = 0.4
var _is_transitioning: bool = false


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if not (body.is_in_group("player") or body.name == "Player"):
		return
	if _is_transitioning:
		return
	if target_scene_path.is_empty():
		return
	_do_transition(body)


func _do_transition(player: Node2D) -> void:
	if _is_transitioning:
		return
	_is_transitioning = true
	var tree: SceneTree = get_tree()
	if tree == null:
		_is_transitioning = false
		return

	# Disable player input during transition
	player.set_physics_process(false)
	player.set_process_unhandled_input(false)

	# Store return position in GameSession
	var current_scene: Node = tree.current_scene
	var current_scene_path: String = current_scene.scene_file_path if current_scene != null else ""
	var facing: String = player.get("_facing") if "_facing" in player else "down"
	if not GameSession.has_return_position():
		GameSession.store_return_position(current_scene_path, player.global_position, facing)

	# Fade out
	var overlay: ColorRect = _get_transition_overlay_from_tree(tree)
	if overlay:
		var tween := create_tween()
		tween.tween_property(overlay, "color", Color(0, 0, 0, 1), FADE_DURATION)
		await tween.finished

	# Change scene
	var change_err: Error = tree.change_scene_to_file(target_scene_path)
	if change_err != OK:
		player.set_physics_process(true)
		player.set_process_unhandled_input(true)
		_is_transitioning = false
		return

	# Fade in after one frame (new scene is loaded)
	await tree.process_frame
	await tree.process_frame

	# Position player at spawn point in the new scene
	_position_player_in_new_scene(tree)

	var new_overlay: ColorRect = _get_transition_overlay_from_tree(tree)
	if new_overlay:
		new_overlay.color = Color(0, 0, 0, 1)
		var tween := tree.create_tween()
		tween.tween_property(new_overlay, "color", Color(0, 0, 0, 0), FADE_DURATION)
		await tween.finished

	_is_transitioning = false


func _position_player_in_new_scene(tree: SceneTree) -> void:
	# Find the player in the new scene and set position
	if tree == null:
		return
	var target_scene: Node = tree.current_scene
	var active_scene_path: String = target_scene.scene_file_path if target_scene != null else ""
	var players: Array[Node] = tree.get_nodes_in_group("player")
	if players.is_empty():
		return
	var player: Node2D = players[0] as Node2D
	if player == null:
		return
	var use_return_position := (
		GameSession.has_return_position()
		and GameSession.get_return_scene_path() == active_scene_path
	)
	if use_return_position:
		player.global_position = GameSession.get_return_position()
		if "_facing" in player and not GameSession.get_return_facing().is_empty():
			player.set("_facing", GameSession.get_return_facing())
		GameSession.clear_return_position()
	else:
		if spawn_position != Vector2.ZERO:
			player.global_position = spawn_position
		if "_facing" in player and not spawn_facing.is_empty():
			player.set("_facing", spawn_facing)
	player.set_physics_process(true)
	player.set_process_unhandled_input(true)


func _get_transition_overlay_from_tree(tree: SceneTree) -> ColorRect:
	if tree == null:
		return null
	var main: Node = tree.current_scene
	if main == null:
		return null
	return main.get_node_or_null("TransitionOverlay") as ColorRect
