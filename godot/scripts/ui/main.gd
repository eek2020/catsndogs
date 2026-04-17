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
	"splash": "res://scenes/ui/splash.tscn",
	"menu": "res://scenes/ui/menu.tscn",
	"character_select": "res://scenes/ui/character_select.tscn",
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
	"arc_summary": "res://scenes/ui/arc_summary.tscn",
	"star_map": "res://scenes/ui/star_map_screen.tscn",
	"skill_allocation": "res://scenes/ui/skill_allocation.tscn",
	"station": "res://scenes/ui/station_screen.tscn",
	"planet": "res://scenes/ui/planet_surface.tscn",
	"intro_crawl": "res://scenes/ui/intro_crawl.tscn",
	"controls_rebind": "res://scenes/ui/controls_rebind.tscn",
	"save_load": "res://scenes/ui/save_load_menu.tscn",
}

var _overlay_stack: Array[Control] = []
var _scene_key_before_overlay: String = ""
var _current_scene_key: String = ""


func _ready() -> void:
	theme = ThemeBuilder.build()
	transition_overlay.color = Color(0, 0, 0, 1)
	_apply_saved_input_bindings()
	switch_scene("splash")


func _apply_saved_input_bindings() -> void:
	var vm := InputRebindViewModel.new()
	vm.load()


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
	_current_scene_key = scene_key
	MusicManager.on_state_change(scene_key)
	await _fade_in()
	_transitioning = false


func push_overlay(scene_key: String) -> Control:
	# Prevent stacking duplicate overlays of the same type
	for existing in _overlay_stack:
		if is_instance_valid(existing) and existing.has_meta("_overlay_key") and existing.get_meta("_overlay_key") == scene_key:
			return null
	var path: String = SCENES.get(scene_key, "")
	if path.is_empty():
		push_error("Unknown overlay key: %s" % scene_key)
		return null
	var scene: PackedScene = load(path)
	var overlay: Control = scene.instantiate()
	overlay.set_meta("_overlay_key", scene_key)
	overlay.modulate.a = 0.0
	scene_container.add_child(overlay)
	_overlay_stack.append(overlay)
	if _overlay_stack.size() == 1:
		_scene_key_before_overlay = _current_scene_key
	MusicManager.on_state_change(scene_key)
	var tween := create_tween()
	tween.tween_property(overlay, "modulate:a", 1.0, 0.15)
	return overlay


func replace_overlay(current_overlay: Control, scene_key: String) -> Control:
	var path: String = SCENES.get(scene_key, "")
	if path.is_empty():
		push_error("Unknown overlay key: %s" % scene_key)
		return null
	var existing_idx := _overlay_stack.find(current_overlay)
	if existing_idx >= 0:
		_overlay_stack.remove_at(existing_idx)
	if is_instance_valid(current_overlay):
		current_overlay.queue_free()
	var scene: PackedScene = load(path)
	var overlay: Control = scene.instantiate()
	overlay.set_meta("_overlay_key", scene_key)
	overlay.modulate.a = 0.0
	scene_container.add_child(overlay)
	_overlay_stack.append(overlay)
	MusicManager.on_state_change(scene_key)
	var tween := create_tween()
	tween.tween_property(overlay, "modulate:a", 1.0, 0.15)
	return overlay


func has_active_overlay() -> bool:
	for overlay in _overlay_stack:
		if is_instance_valid(overlay):
			return true
	return false


func pop_overlay() -> void:
	while not _overlay_stack.is_empty() and not is_instance_valid(_overlay_stack[-1]):
		_overlay_stack.pop_back()
	if _overlay_stack.is_empty():
		return
	var overlay: Control = _overlay_stack.pop_back()
	var tween := create_tween()
	tween.tween_property(overlay, "modulate:a", 0.0, 0.15)
	tween.tween_callback(overlay.queue_free)
	# Restore previous music when all overlays are cleared
	if _overlay_stack.is_empty() and not _scene_key_before_overlay.is_empty():
		MusicManager.on_state_change(_scene_key_before_overlay)
		_scene_key_before_overlay = ""


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
