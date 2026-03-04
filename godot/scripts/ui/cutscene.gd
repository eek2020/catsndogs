## Cutscene screen — title card with scrolling text lines.
## Mirrors Python ui/cutscene.py CutsceneState.
extends Control

@onready var title_label: Label = $VBox/Title
@onready var subtitle_label: Label = $VBox/Subtitle
@onready var text_body: RichTextLabel = $VBox/TextBody
@onready var continue_label: Label = $VBox/ContinueLabel

var lines: Array[String] = []
var _current_line: int = 0


func setup(p_title: String, p_subtitle: String, p_lines: Array[String]) -> void:
	lines = p_lines
	if title_label:
		title_label.text = p_title
		subtitle_label.text = p_subtitle
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
	_show_next_line()


func _show_next_line() -> void:
	if _current_line < lines.size():
		text_body.text += lines[_current_line] + "\n\n"
		_current_line += 1
		if _current_line >= lines.size():
			continue_label.text = "Press SPACE to begin..."
	else:
		_finish()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("fire") or event.is_action_pressed("confirm"):
		if _current_line < lines.size():
			_show_next_line()
		else:
			_finish()
	elif event.is_action_pressed("skip"):
		_finish()


func _finish() -> void:
	var main: Control = get_tree().current_scene
	if main.has_method("switch_scene"):
		main.switch_scene("navigation")
