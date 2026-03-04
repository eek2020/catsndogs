## Dialogue UI — encounter choices and outcome display.
## Mirrors Python ui/dialogue_ui.py DialogueState.
extends Control

@onready var title_label: Label = $Panel/VBox/Title
@onready var description_label: RichTextLabel = $Panel/VBox/Description
@onready var choices_container: VBoxContainer = $Panel/VBox/ChoicesContainer

var encounter: Encounter = null
var on_complete: Callable = Callable()
var on_combat: Callable = Callable()


func setup(p_encounter: Encounter) -> void:
	encounter = p_encounter
	_build_ui()


func _ready() -> void:
	_build_ui()


func _build_ui() -> void:
	if encounter == null:
		return
	title_label.text = encounter.title
	description_label.text = encounter.description
	# Clear old choice buttons
	for child in choices_container.get_children():
		child.queue_free()
	# Build choice buttons
	for i in range(encounter.choices.size()):
		var choice: Encounter.EncounterChoice = encounter.choices[i]
		var btn := Button.new()
		btn.text = choice.text
		btn.pressed.connect(_on_choice_selected.bind(i))
		choices_container.add_child(btn)
		if i == 0:
			btn.call_deferred("grab_focus")


func _on_choice_selected(index: int) -> void:
	if encounter == null or GameSession.game_state == null:
		return
	var outcome_text := GameSession.encounter_engine.apply_choice_outcome(
		GameSession.game_state, encounter, index
	)
	# Show outcome briefly
	description_label.text = outcome_text
	for child in choices_container.get_children():
		child.queue_free()
	await get_tree().create_timer(2.0).timeout
	# Return to navigation
	var main: Control = get_tree().current_scene
	if main.has_method("pop_overlay"):
		main.pop_overlay()
