## Pause menu overlay — resume, save, load, settings, quit.
## Mirrors Python ui/pause_menu.py PauseMenuState.
extends Control

@onready var resume_btn: Button = $Panel/VBox/ResumeBtn
@onready var save_btn: Button = $Panel/VBox/SaveBtn
@onready var load_btn: Button = $Panel/VBox/LoadBtn
@onready var settings_btn: Button = $Panel/VBox/SettingsBtn
@onready var quit_btn: Button = $Panel/VBox/QuitBtn


func _ready() -> void:
	resume_btn.pressed.connect(_on_resume)
	save_btn.pressed.connect(_on_save)
	load_btn.pressed.connect(_on_load)
	settings_btn.pressed.connect(_on_settings)
	quit_btn.pressed.connect(_on_quit)
	resume_btn.grab_focus()


func _on_resume() -> void:
	var main: Control = get_tree().current_scene
	if main.has_method("pop_overlay"):
		main.pop_overlay()


func _on_save() -> void:
	GameSession.save_game(0)
	EventBus.save_game.emit()


func _on_load() -> void:
	if GameSession.load_game(0):
		EventBus.load_game.emit()
		var main: Control = get_tree().current_scene
		if main.has_method("switch_scene"):
			main.switch_scene("navigation")


func _on_settings() -> void:
	var main: Control = get_tree().current_scene
	if main.has_method("push_overlay"):
		main.push_overlay("settings")


func _on_quit() -> void:
	GameSession.quit_to_menu()
	var main: Control = get_tree().current_scene
	if main.has_method("switch_scene"):
		main.switch_scene("menu")
