## Settings overlay — music, SFX, volume controls.
## Mirrors Python ui/settings_screen.py SettingsScreenState.
extends Control

@onready var music_toggle: CheckButton = $Panel/VBox/MusicToggle
@onready var sfx_toggle: CheckButton = $Panel/VBox/SfxToggle
@onready var volume_slider: HSlider = $Panel/VBox/VolumeSlider
@onready var close_btn: Button = $Panel/VBox/CloseBtn


func _ready() -> void:
	music_toggle.toggled.connect(_on_music_toggled)
	sfx_toggle.toggled.connect(_on_sfx_toggled)
	volume_slider.value_changed.connect(_on_volume_changed)
	close_btn.pressed.connect(_on_close)
	close_btn.grab_focus()


func _on_music_toggled(pressed: bool) -> void:
	MusicManager.set_music_enabled(pressed)


func _on_sfx_toggled(pressed: bool) -> void:
	MusicManager.set_sfx_enabled(pressed)


func _on_volume_changed(value: float) -> void:
	EventBus.volume_changed.emit(value)


func _on_close() -> void:
	var main: Control = get_tree().current_scene
	if main.has_method("pop_overlay"):
		main.pop_overlay()
