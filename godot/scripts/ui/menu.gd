## Main menu screen — new game, load, settings, quit.
## Mirrors Python ui/menu.py MenuState.
extends Control

@onready var new_game_btn: Button = $VBox/NewGameBtn
@onready var load_game_btn: Button = $VBox/LoadGameBtn
@onready var settings_btn: Button = $VBox/SettingsBtn
@onready var quit_btn: Button = $VBox/QuitBtn


func _ready() -> void:
	new_game_btn.pressed.connect(_on_new_game)
	load_game_btn.pressed.connect(_on_load_game)
	settings_btn.pressed.connect(_on_settings)
	quit_btn.pressed.connect(_on_quit)
	new_game_btn.grab_focus()


func _on_new_game() -> void:
	GameSession.start_new_game()
	var main: Control = get_tree().current_scene
	if main.has_method("switch_scene"):
		main.switch_scene("cutscene")


func _on_load_game() -> void:
	if GameSession.load_game(0):
		var main: Control = get_tree().current_scene
		if main.has_method("switch_scene"):
			main.switch_scene("navigation")


func _on_settings() -> void:
	var main: Control = get_tree().current_scene
	if main.has_method("push_overlay"):
		main.push_overlay("settings")


func _on_quit() -> void:
	get_tree().quit()
