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

	# Fade out — create the tween on the tree so it survives any odd lifecycle
	var overlay: ColorRect = _get_transition_overlay_from_tree(tree)
	if overlay:
		var tween: Tween = tree.create_tween()
		tween.tween_property(overlay, "color", Color(0, 0, 0, 1), FADE_DURATION)
		await tween.finished

	# Change scene. `self` (this Area2D) belongs to the outgoing scene and
	# will be freed at the end of the frame, so we do NOT keep awaiting here.
	var change_err: Error = tree.change_scene_to_file(target_scene_path)
	if change_err != OK:
		# Scene change failed — restore player input and release the guard.
		# `self` is still valid because no scene swap actually happened.
		player.set_physics_process(true)
		player.set_process_unhandled_input(true)
		_is_transitioning = false
		return

	# Hand off the post-change half of the transition (position player + fade
	# in) to GameSession, which is a persistent autoload and therefore
	# survives `self` being freed during the scene swap. This replaces the
	# old pattern of awaiting `process_frame` on a soon-to-be-freed Area2D
	# (Mar-27 §2.3).
	GameSession.complete_scene_transition(spawn_position, spawn_facing, FADE_DURATION)


func _get_transition_overlay_from_tree(tree: SceneTree) -> ColorRect:
	if tree == null:
		return null
	var main: Node = tree.current_scene
	if main == null:
		return null
	return main.get_node_or_null("TransitionOverlay") as ColorRect
