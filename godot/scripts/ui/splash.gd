## Splash screen — displays startup artwork briefly before transitioning to menu.
## Mirrors Python engine/startup.py show_startup_splash().
extends Control

const SPLASH_DURATION: float = 4.0
const FADE_IN_DURATION: float = 0.6

var _elapsed: float = 0.0
var _dismissed: bool = false


func _ready() -> void:
	modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 1.0, FADE_IN_DURATION)


func _process(dt: float) -> void:
	_elapsed += dt
	if _elapsed >= SPLASH_DURATION and not _dismissed:
		_go_to_menu()


func _unhandled_input(event: InputEvent) -> void:
	if _dismissed:
		return
	if event is InputEventKey and event.pressed:
		_go_to_menu()
	elif event is InputEventMouseButton and event.pressed:
		_go_to_menu()


func _go_to_menu() -> void:
	_dismissed = true
	var main: Control = get_tree().current_scene
	if main.has_method("switch_scene"):
		main.switch_scene("menu")
