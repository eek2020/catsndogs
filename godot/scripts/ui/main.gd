## Main scene controller — manages UI state transitions via scene swapping.
## Replaces the Python GameStateMachine push/pop/switch with scene-tree control.
extends Control

@onready var scene_container: Control = $SceneContainer
@onready var transition_overlay: ColorRect = $TransitionOverlay

var _current_scene: Control = null
var _transitioning: bool = false

const TRANSITION_DURATION := 0.3

# Scene paths
const SCENES := {
	"menu": "res://scenes/ui/menu.tscn",
	"navigation": "res://scenes/ui/navigation.tscn",
	"combat": "res://scenes/ui/combat_ui.tscn",
	"dialogue": "res://scenes/ui/dialogue_ui.tscn",
	"cutscene": "res://scenes/ui/cutscene.tscn",
	"trade": "res://scenes/ui/trade_screen.tscn",
	"faction": "res://scenes/ui/faction_screen.tscn",
	"ship": "res://scenes/ui/ship_screen.tscn",
	"purchase": "res://scenes/ui/purchase_screen.tscn",
	"mission_log": "res://scenes/ui/mission_log.tscn",
	"pause": "res://scenes/ui/pause_menu.tscn",
	"settings": "res://scenes/ui/settings_screen.tscn",
	"ending": "res://scenes/ui/ending_screen.tscn",
}

var _overlay_stack: Array[Control] = []


func _ready() -> void:
	theme = ThemeBuilder.build()
	transition_overlay.color = Color(0, 0, 0, 1)
	switch_scene("menu")


func switch_scene(scene_key: String) -> void:
	if _transitioning:
		return
	_clear_overlays()
	var path: String = SCENES.get(scene_key, "")
	if path.is_empty():
		push_error("Unknown scene key: %s" % scene_key)
		return
	if _current_scene:
		_transitioning = true
		await _fade_out()
		_current_scene.queue_free()
		_current_scene = null
	var scene: PackedScene = load(path)
	_current_scene = scene.instantiate()
	scene_container.add_child(_current_scene)
	MusicManager.on_state_change(scene_key)
	await _fade_in()
	_transitioning = false


func push_overlay(scene_key: String) -> Control:
	var path: String = SCENES.get(scene_key, "")
	if path.is_empty():
		push_error("Unknown overlay key: %s" % scene_key)
		return null
	var scene: PackedScene = load(path)
	var overlay: Control = scene.instantiate()
	overlay.modulate.a = 0.0
	scene_container.add_child(overlay)
	_overlay_stack.append(overlay)
	var tween := create_tween()
	tween.tween_property(overlay, "modulate:a", 1.0, 0.15)
	return overlay


func pop_overlay() -> void:
	if _overlay_stack.is_empty():
		return
	var overlay := _overlay_stack.pop_back()
	var tween := create_tween()
	tween.tween_property(overlay, "modulate:a", 0.0, 0.15)
	tween.tween_callback(overlay.queue_free)


func _clear_overlays() -> void:
	for overlay in _overlay_stack:
		if is_instance_valid(overlay):
			overlay.queue_free()
	_overlay_stack.clear()


func _fade_out() -> void:
	transition_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	var tween := create_tween()
	tween.tween_property(transition_overlay, "color:a", 1.0, TRANSITION_DURATION)
	await tween.finished


func _fade_in() -> void:
	var tween := create_tween()
	tween.tween_property(transition_overlay, "color:a", 0.0, TRANSITION_DURATION)
	await tween.finished
	transition_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
