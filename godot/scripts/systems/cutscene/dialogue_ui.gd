class_name CutsceneDialogueUI
extends CanvasLayer

## Simple dialogue UI for cutscenes (renamed from DialogueUI — Issue #14).
##
## Shows a dialogue box at the bottom of the screen with the speaker's name
## and their line, typed out character by character. Click / space / enter
## to advance. For choices, displays buttons and emits choice_made when one
## is clicked.

signal choice_made(index: int)

@onready var dialogue_box: Panel = $DialogueBox
@onready var speaker_label: Label = $DialogueBox/VBox/SpeakerLabel
@onready var text_label: RichTextLabel = $DialogueBox/VBox/TextLabel
@onready var advance_hint: Label = $DialogueBox/VBox/AdvanceHint
@onready var choice_container: VBoxContainer = $ChoicePanel/VBox
@onready var choice_panel: Panel = $ChoicePanel
@onready var choice_prompt_label: Label = $ChoicePanel/VBox/PromptLabel
@onready var fade_rect: ColorRect = $FadeRect

var _line_finished: bool = true
var _advance_requested: bool = false
var _current_tween: Tween = null


func _ready() -> void:
	dialogue_box.visible = false
	choice_panel.visible = false
	fade_rect.color = Color(0, 0, 0, 0)
	set_process_input(true)


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode in [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER]:
			_advance_requested = true
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_advance_requested = true


## Show a single dialogue line with typewriter effect.
## Awaits until the player presses advance.
func show_line(speaker: String, text: String, typewriter_speed: float = 0.025) -> void:
	dialogue_box.visible = true
	speaker_label.text = speaker
	text_label.text = ""
	advance_hint.visible = false
	_line_finished = false
	_advance_requested = false

	# Typewriter effect.
	if typewriter_speed > 0.0:
		var total := text.length()
		for i in range(total + 1):
			if _advance_requested:
				text_label.text = text
				break
			text_label.text = text.substr(0, i)
			await get_tree().create_timer(typewriter_speed).timeout
	else:
		text_label.text = text

	_line_finished = true
	advance_hint.visible = true
	_advance_requested = false

	# Wait for player to advance.
	while not _advance_requested:
		await get_tree().process_frame
	_advance_requested = false
	advance_hint.visible = false


## Show a choice prompt with buttons. Returns (via signal) the chosen index.
func show_choice(prompt: String, options: Array) -> void:
	dialogue_box.visible = false
	choice_panel.visible = true
	choice_prompt_label.text = prompt

	# Clear existing buttons.
	for child in choice_container.get_children():
		if child != choice_prompt_label:
			child.queue_free()

	for i in range(options.size()):
		var option: Dictionary = options[i]
		var btn := Button.new()
		btn.text = str(option.get("label", "Option %d" % (i + 1)))
		btn.custom_minimum_size = Vector2(400, 40)
		var idx := i
		btn.pressed.connect(func() -> void:
			choice_panel.visible = false
			choice_made.emit(idx)
		)
		choice_container.add_child(btn)


## Fade the screen to black over the given duration.
func fade_black(duration: float) -> void:
	if _current_tween:
		_current_tween.kill()
	_current_tween = create_tween()
	_current_tween.tween_property(fade_rect, "color", Color(0, 0, 0, 1), duration)
	await _current_tween.finished


func fade_clear(duration: float) -> void:
	if _current_tween:
		_current_tween.kill()
	_current_tween = create_tween()
	_current_tween.tween_property(fade_rect, "color", Color(0, 0, 0, 0), duration)
	await _current_tween.finished
