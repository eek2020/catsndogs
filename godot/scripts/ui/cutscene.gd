## Cutscene screen — title card with scrolling text lines.
## Mirrors Python ui/cutscene.py CutsceneState.
extends Control

@onready var title_label: Label = $VBox/Title
@onready var subtitle_label: Label = $VBox/Subtitle
@onready var text_body: RichTextLabel = $VBox/TextBody
@onready var continue_label: Label = $VBox/ContinueLabel

var lines: Array[String] = []
var _current_line: int = 0
var _revealing: bool = false
var _reveal_accumulator: float = 0.0
var _reveal_start_chars: int = 0
var _reveal_target_chars: int = 0

const TEXT_REVEAL_CPS: float = 62.0


func setup(p_title: String, p_subtitle: String, p_lines: Array[String]) -> void:
	lines = p_lines
	if title_label:
		title_label.text = p_title
		subtitle_label.text = p_subtitle
		text_body.text = ""
		_current_line = 0
		_show_next_line()


func _ready() -> void:
	# Default intro cutscene if no setup call
	if lines.is_empty():
		title_label.text = "WHISPER CRYSTALS"
		lines = [
			"In a multiverse where cats, dogs, fairies, and goblins sail between realms...",
			"Captain Aristotle — a street cat turned Corsair — discovers a crystal that hums with unearthly power.",
			"Whisper Crystals. Fuel for ships, currency for empires, and now... his burden.",
			"The Canis League wants them. The Lions demand tribute. Something ancient watches from the shadows.",
			"And so the journey begins.",
		]
	_current_line = 0
	continue_label.text = "SPACE: reveal text"
	_show_next_line()


func _process(dt: float) -> void:
	if not _revealing:
		return
	_reveal_accumulator += dt * TEXT_REVEAL_CPS
	text_body.visible_characters = mini(
		_reveal_target_chars,
		_reveal_start_chars + int(_reveal_accumulator)
	)
	if text_body.visible_characters >= _reveal_target_chars:
		_revealing = false
		if _current_line < lines.size():
			continue_label.text = "SPACE: next line"
		else:
			continue_label.text = "Press SPACE to begin..."


func _show_next_line() -> void:
	if _revealing:
		_reveal_to_end()
		return
	if _current_line < lines.size():
		_reveal_start_chars = text_body.get_total_character_count()
		text_body.text += lines[_current_line] + "\n\n"
		_current_line += 1
		_reveal_accumulator = 0.0
		_reveal_target_chars = text_body.get_total_character_count()
		text_body.visible_characters = _reveal_start_chars
		_revealing = true
		continue_label.text = "SPACE: reveal text"
		text_body.modulate.a = 0.72
		var tween := create_tween()
		tween.tween_property(text_body, "modulate:a", 1.0, 0.22)
	else:
		_finish()


func _reveal_to_end() -> void:
	text_body.visible_characters = _reveal_target_chars
	_revealing = false
	if _current_line < lines.size():
		continue_label.text = "SPACE: next line"
	else:
		continue_label.text = "Press SPACE to begin..."


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("fire") or event.is_action_pressed("confirm"):
		if _revealing:
			_reveal_to_end()
		elif _current_line < lines.size():
			_show_next_line()
		else:
			_finish()
	elif event.is_action_pressed("skip"):
		_finish()


func _finish() -> void:
	var main: Control = get_tree().current_scene
	if main.has_method("switch_scene"):
		main.switch_scene("navigation")
