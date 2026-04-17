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
var _pause_timer: float = 0.0

const TEXT_REVEAL_CPS: float = 62.0
const LINE_PAUSE_SECONDS: float = 0.5


func setup(p_title: String, p_subtitle: String, p_lines: Array[String]) -> void:
	lines = p_lines
	if title_label:
		title_label.text = p_title
		subtitle_label.text = p_subtitle
		text_body.text = ""
		_current_line = 0
		_show_next_line()


func _ready() -> void:
	# Load intro from protagonist config if no setup call provided lines
	if lines.is_empty():
		var config: Dictionary = GameSession.get_protagonist_config()
		title_label.text = config.get("intro_title", "WHISPER CRYSTALS")
		subtitle_label.text = config.get("intro_subtitle", "")
		var raw_lines: Array = config.get("intro_lines", [
			"And so the journey begins.",
		])
		for line in raw_lines:
			lines.append(str(line))
	_current_line = 0
	continue_label.text = "ESC: skip"
	_show_next_line()


func _process(dt: float) -> void:
	# Handle pause between lines — auto-advance after timer expires
	if _pause_timer > 0.0:
		_pause_timer -= dt
		if _pause_timer <= 0.0:
			if _current_line < lines.size():
				_show_next_line()
			else:
				_finish()
		return
	if not _revealing:
		return
	_reveal_accumulator += dt * TEXT_REVEAL_CPS
	text_body.visible_characters = mini(
		_reveal_target_chars,
		_reveal_start_chars + int(_reveal_accumulator)
	)
	if text_body.visible_characters >= _reveal_target_chars:
		_revealing = false
		# Start pause timer before auto-advancing to next line
		_pause_timer = LINE_PAUSE_SECONDS


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
		_pause_timer = 0.0
		text_body.modulate.a = 0.72
		var tween := create_tween()
		tween.tween_property(text_body, "modulate:a", 1.0, 0.22)
	else:
		_finish()


func _reveal_to_end() -> void:
	text_body.visible_characters = _reveal_target_chars
	_revealing = false
	_pause_timer = LINE_PAUSE_SECONDS


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("skip") or event.is_action_pressed("pause"):
		_finish()


func _finish() -> void:
	var main: Control = get_tree().current_scene
	if main.has_method("switch_scene"):
		main.switch_scene("navigation")
