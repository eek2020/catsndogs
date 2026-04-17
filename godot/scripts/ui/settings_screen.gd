## Settings overlay — music, SFX, volume controls.
## Mirrors Python ui/settings_screen.py SettingsScreenState.
extends Control

@onready var music_toggle: CheckButton = $Panel/VBox/MusicToggle
@onready var sfx_toggle: CheckButton = $Panel/VBox/SfxToggle
@onready var volume_slider: HSlider = $Panel/VBox/VolumeSlider
@onready var controls_btn: Button = $Panel/VBox/ControlsBtn
@onready var close_btn: Button = $Panel/VBox/CloseBtn


func _ready() -> void:
	# Initialize slider range (0.0 to 1.0 linear volume)
	volume_slider.min_value = 0.0
	volume_slider.max_value = 1.0
	volume_slider.step = 0.05
	volume_slider.value = db_to_linear(MusicManager._music_volume_db)
	music_toggle.button_pressed = MusicManager._music_enabled
	sfx_toggle.button_pressed = MusicManager._sfx_enabled
	music_toggle.toggled.connect(_on_music_toggled)
	sfx_toggle.toggled.connect(_on_sfx_toggled)
	volume_slider.value_changed.connect(_on_volume_changed)
	controls_btn.pressed.connect(_on_controls)
	close_btn.pressed.connect(_on_close)
	close_btn.grab_focus()


func _on_music_toggled(pressed: bool) -> void:
	MusicManager.set_music_enabled(pressed)


func _on_sfx_toggled(pressed: bool) -> void:
	MusicManager.set_sfx_enabled(pressed)


func _on_volume_changed(value: float) -> void:
	MusicManager.set_music_volume(value)


func _on_controls() -> void:
	var main: Control = get_tree().current_scene
	if main.has_method("push_overlay"):
		main.push_overlay("controls_rebind")


func _on_close() -> void:
	var main: Control = get_tree().current_scene
	if main.has_method("pop_overlay"):
		main.pop_overlay()
