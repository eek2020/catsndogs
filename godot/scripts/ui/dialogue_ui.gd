## Dialogue UI — encounter choices, outcome display, and multi-step branching dialogue.
## Supports both legacy single-step encounters and new two-sided dialogue_steps encounters.
##
## All GameSession access flows through DialogueViewModel (injected via
## initialize(vm) or built from the GameSession autoload in _ready). Portrait
## rendering lives in DialoguePortraitManager; combat transitions live in
## DialogueCombatTransition. This file owns only the scene-tree nodes, the
## typewriter reveal, the choice-button construction, and the dialogue flow
## dispatch. Sprint 6a decomposition (REFACTORING_PLAN §4 + VM layer).
extends Control


const DialoguePortraitManagerScript := preload(
	"res://scripts/ui/dialogue/portrait_manager.gd"
)
const DialogueCombatTransitionScript := preload(
	"res://scripts/ui/dialogue/combat_transition.gd"
)


@onready var dim_backdrop: ColorRect = $DimBackdrop
@onready var dialogue_background: TextureRect = $DialogueBackground
@onready var panel: PanelContainer = $Panel
@onready var title_label: Label = $Panel/HBox/VBox/Title
@onready var description_label: RichTextLabel = $Panel/HBox/VBox/Description
@onready var choices_container: VBoxContainer = $Panel/HBox/VBox/ChoicesContainer

# Left portrait — always the player character (Aristotle)
@onready var left_portrait_container: VBoxContainer = $"Panel/HBox/LeftPortraitContainer"
@onready var left_portrait_rect: TextureRect = $"Panel/HBox/LeftPortraitContainer/PortraitRect"
@onready var left_name_label: Label = $"Panel/HBox/LeftPortraitContainer/NameLabel"

# Right portrait — NPC
@onready var right_portrait_container: VBoxContainer = $"Panel/HBox/RightPortraitContainer"
@onready var right_portrait_rect: TextureRect = $"Panel/HBox/RightPortraitContainer/PortraitRect"
@onready var right_name_label: Label = $"Panel/HBox/RightPortraitContainer/NameLabel"


var encounter: Encounter = null
var on_complete: Callable = Callable()
var on_combat: Callable = Callable()

var _vm: DialogueViewModel = null
var _portraits: DialoguePortraitManager = null
var _combat: DialogueCombatTransition = null

var _reveal_accumulator: float = 0.0
var _revealing_description: bool = false
var _active_description_text: String = ""
var _space_advance: bool = false  # set true when player presses space to skip wait

# Multi-step dialogue state
var _using_dialogue_steps: bool = false
var _step_index: int = 0
var _step_map: Dictionary = {}  # step_id -> index in dialogue_steps
var _steps_visited: int = 0
const MAX_STEPS: int = 50

const BASE_PANEL_HEIGHT: float = 280.0
const DESCRIPTION_REVEAL_CPS: float = 95.0
const AUTO_ADVANCE_DELAY_MIN: float = 2.0
const READING_SEC_PER_WORD: float = 0.24  # ~250 WPM comfortable reading pace

# Parchment text styling
const PARCHMENT_TITLE_COLOR := Color(0.35, 0.15, 0.05, 1.0)
const PARCHMENT_DESC_COLOR := Color(0.2, 0.12, 0.05, 1.0)
const PARCHMENT_NAME_COLOR := Color(0.3, 0.12, 0.0, 1.0)
const DEFAULT_TITLE_COLOR := Color(0.94, 0.75, 0.25, 1.0)
const DEFAULT_NAME_COLOR := Color(0.3, 0.8, 0.9, 1.0)


# ---------------------------------------------------------------------------
# External API
# ---------------------------------------------------------------------------

## Inject a pre-built ViewModel (used by tests and custom pushers).
## Production callers rely on the `_ready` fallback, which builds a VM from
## the GameSession autoload.
func initialize(vm: DialogueViewModel) -> void:
	_vm = vm


func setup(p_encounter: Encounter) -> void:
	encounter = p_encounter
	_build_ui()


# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------

func _ready() -> void:
	if _vm == null:
		_vm = DialogueViewModel.new(GameSession)
	_portraits = DialoguePortraitManagerScript.new(self)
	_combat = DialogueCombatTransitionScript.new(_vm)

	# Fade in the dim backdrop so the dialogue stands out
	dim_backdrop.color.a = 0.0
	var backdrop_tween := create_tween()
	backdrop_tween.tween_property(dim_backdrop, "color:a", 0.55, 0.25)
	_build_ui()


func _process(dt: float) -> void:
	if not _revealing_description:
		return
	_reveal_accumulator += dt * DESCRIPTION_REVEAL_CPS
	description_label.visible_characters = mini(
		description_label.get_total_character_count(),
		int(_reveal_accumulator)
	)
	if description_label.visible_characters >= description_label.get_total_character_count():
		_revealing_description = false


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_SPACE:
			get_viewport().set_input_as_handled()
			if _revealing_description:
				# Instantly finish the typewriter reveal
				_reveal_accumulator = description_label.get_total_character_count()
				description_label.visible_characters = description_label.get_total_character_count()
				_revealing_description = false
			else:
				# Skip the reading-time wait
				_space_advance = true


# ---------------------------------------------------------------------------
# Top-level flow
# ---------------------------------------------------------------------------

func _build_ui() -> void:
	if encounter == null or _vm == null:
		return

	title_label.text = encounter.title

	# Always show the dialogue background for all interaction types
	dialogue_background.visible = true
	var transparent_style := StyleBoxEmpty.new()
	transparent_style.content_margin_left = 50.0
	transparent_style.content_margin_right = 50.0
	transparent_style.content_margin_top = 16.0
	transparent_style.content_margin_bottom = 16.0
	panel.add_theme_stylebox_override("panel", transparent_style)
	_apply_parchment_text_style()

	if encounter.has_dialogue_steps():
		_using_dialogue_steps = true
		_build_step_map()
		_portraits.setup_two_portraits(
			encounter,
			_vm.protagonist_id(),
			left_portrait_rect, left_name_label, left_portrait_container,
			right_portrait_rect, right_name_label, right_portrait_container,
		)
		_show_step(0)
	else:
		_using_dialogue_steps = false
		_set_description(encounter.description)
		_portraits.setup_legacy_portrait(
			encounter,
			left_portrait_rect, left_name_label, left_portrait_container,
			right_portrait_container,
		)
		_build_legacy_choices()


# ---------------------------------------------------------------------------
# Multi-step dialogue flow
# ---------------------------------------------------------------------------

func _build_step_map() -> void:
	_step_map.clear()
	for i in range(encounter.dialogue_steps.size()):
		var step: Encounter.DialogueStep = encounter.dialogue_steps[i]
		if not step.step_id.is_empty():
			_step_map[step.step_id] = i


func _show_step(index: int) -> void:
	_steps_visited += 1
	if _steps_visited > MAX_STEPS:
		push_warning("DialogueUI: exceeded max steps (%d) — ending dialogue." % MAX_STEPS)
		_end_dialogue()
		return

	if index < 0 or index >= encounter.dialogue_steps.size():
		push_warning("DialogueUI: invalid step index %d — ending dialogue." % index)
		_end_dialogue()
		return

	_step_index = index
	var step: Encounter.DialogueStep = encounter.dialogue_steps[index]

	EventBus.dialogue_step_advanced.emit(encounter.encounter_id, index)
	_portraits.highlight_speaker(
		step.speaker, _vm.protagonist_id(),
		left_portrait_container, right_portrait_container,
	)

	for child in choices_container.get_children():
		child.queue_free()

	_set_description(step.text)
	while _revealing_description:
		await get_tree().process_frame

	if step.start_combat:
		await _reading_pause(step.text)
		_complete_and_start_combat()
	elif step.end:
		await _reading_pause(step.text)
		_end_dialogue()
	elif step.choices.size() > 0:
		_show_dialogue_choices(step.choices)
	else:
		await _reading_pause(step.text)
		_show_step(index + 1)


func _show_dialogue_choices(choices: Array) -> void:
	_collapse_description_for_choices(choices.size())
	for i in range(choices.size()):
		var choice: Encounter.DialogueStepChoice = choices[i]
		var btn := _create_choice_button(i, _strip_outer_quotes(choice.text), choices.size())
		btn.pressed.connect(_on_dialogue_choice_selected.bind(i))
		choices_container.add_child(btn)
		var tween := create_tween()
		tween.set_parallel(true)
		tween.tween_property(btn, "modulate:a", 1.0, 0.12).set_delay(0.05 * i)
		tween.tween_property(btn, "position:x", 0.0, 0.12).set_delay(0.05 * i)
		if i == 0:
			btn.call_deferred("grab_focus")


func _on_dialogue_choice_selected(choice_index: int) -> void:
	if encounter == null or not _vm.has_state():
		return

	var step: Encounter.DialogueStep = encounter.dialogue_steps[_step_index]
	if choice_index < 0 or choice_index >= step.choices.size():
		return

	var choice: Encounter.DialogueStepChoice = step.choices[choice_index]
	_vm.apply_step_outcome(encounter, choice)

	for child in choices_container.get_children():
		child.queue_free()
	_restore_description()

	if not choice.next_step.is_empty():
		if _step_map.has(choice.next_step):
			_show_step(_step_map[choice.next_step])
		else:
			push_warning("DialogueUI: unknown next_step '%s' — ending dialogue." % choice.next_step)
			_end_dialogue()
	else:
		_show_step(_step_index + 1)


func _end_dialogue() -> void:
	var recruited_crew_id := _check_crew_recruitment_from_flags()
	if not recruited_crew_id.is_empty():
		await _show_crew_recruitment_confirmation(recruited_crew_id)

	await get_tree().create_timer(1.5).timeout

	# Pop ourselves BEFORE completing the encounter, because complete_encounter
	# may trigger advance_arc which pushes arc_summary on top of us.
	# If we pop after, we'd pop arc_summary instead and get stuck.
	var main: Control = get_tree().current_scene
	if main.has_method("pop_overlay"):
		main.pop_overlay()

	_vm.complete_encounter(encounter)


func _complete_and_start_combat() -> void:
	_vm.complete_encounter(encounter)
	_combat.start_encounter_combat(encounter, self)


func _check_crew_recruitment_from_flags() -> String:
	if encounter == null or encounter.mission_type != "crew_recruitment":
		return ""
	if encounter.crew_member_id.is_empty():
		return ""
	var flag_name := "crew_%s_recruited" % encounter.crew_member_id
	if _vm.story_flag(flag_name):
		return encounter.crew_member_id
	return ""


# ---------------------------------------------------------------------------
# Legacy single-step encounter flow
# ---------------------------------------------------------------------------

func _build_legacy_choices() -> void:
	for child in choices_container.get_children():
		child.queue_free()
	_collapse_description_for_choices(encounter.choices.size())
	for i in range(encounter.choices.size()):
		var choice: Encounter.EncounterChoice = encounter.choices[i]
		var choice_text := _strip_outer_quotes(choice.text)
		var btn := _create_choice_button(i, choice_text, encounter.choices.size())
		btn.pressed.connect(_on_legacy_choice_selected.bind(i))
		choices_container.add_child(btn)
		var tween := create_tween()
		tween.set_parallel(true)
		tween.tween_property(btn, "modulate:a", 1.0, 0.12).set_delay(0.05 * i)
		tween.tween_property(btn, "position:x", 0.0, 0.12).set_delay(0.05 * i)
		if i == 0:
			btn.call_deferred("grab_focus")


func _on_legacy_choice_selected(index: int) -> void:
	if encounter == null or not _vm.has_state():
		return
	var choice: Encounter.EncounterChoice = encounter.choices[index]
	var outcome_text := _vm.apply_choice_outcome(encounter, index)
	if _should_start_combat(choice):
		_combat.start_legacy_combat(encounter, choice, self)
		return

	var recruited_crew_id := _check_crew_recruitment(choice)

	for child in choices_container.get_children():
		child.queue_free()
	_restore_description()
	_set_description(outcome_text)
	while _revealing_description:
		await get_tree().process_frame

	if not recruited_crew_id.is_empty():
		await _show_crew_recruitment_confirmation(recruited_crew_id)
	await get_tree().create_timer(2.0).timeout

	# Pop ourselves BEFORE triggering the arc check, so that if advance_arc
	# pushes arc_summary it goes on top of navigation, not on top of us.
	var main: Control = get_tree().current_scene
	if main.has_method("pop_overlay"):
		main.pop_overlay()
	_vm.deferred_arc_check()


func _check_crew_recruitment(choice: Encounter.EncounterChoice) -> String:
	if encounter == null or encounter.mission_type != "crew_recruitment":
		return ""
	if encounter.crew_member_id.is_empty():
		return ""
	for flag in choice.outcome.story_flags_set:
		if flag.begins_with("crew_") and flag.ends_with("_recruited"):
			return encounter.crew_member_id
	return ""


func _show_crew_recruitment_confirmation(crew_id: String) -> void:
	_vm.recruit_crew(crew_id)
	var defn: Dictionary = _vm.crew_definition(crew_id)
	if defn.is_empty():
		return
	var crew_name: String = defn.get("name", crew_id)
	var role: String = defn.get("role", "").replace("_", " ").capitalize()
	var trait_desc: String = defn.get("trait_description", "")
	var confirm_text := "[b]%s[/b] has joined your crew as [b]%s[/b]!\n%s" \
		% [crew_name, role, trait_desc]
	_set_description(confirm_text)
	while _revealing_description:
		await get_tree().process_frame
	await get_tree().create_timer(2.5).timeout


func _should_start_combat(choice: Encounter.EncounterChoice) -> bool:
	if encounter == null or choice == null:
		return false
	return encounter.encounter_type == "combat"


# ---------------------------------------------------------------------------
# Shared description/reveal helpers
# ---------------------------------------------------------------------------

func _reading_pause(text: String) -> void:
	## Wait long enough for the player to read, or until they press space.
	_space_advance = false
	var word_count: int = text.split(" ", false).size()
	var pause: float = maxf(AUTO_ADVANCE_DELAY_MIN, word_count * READING_SEC_PER_WORD)
	var elapsed: float = 0.0
	while elapsed < pause:
		if _space_advance:
			_space_advance = false
			return
		await get_tree().process_frame
		elapsed += get_process_delta_time()


func _set_description(text: String) -> void:
	_active_description_text = text
	description_label.clear()
	description_label.push_color(description_label.get_theme_color("default_color"))
	description_label.append_text(text)
	description_label.pop()
	description_label.visible_characters = 0
	_reveal_accumulator = 0.0
	_revealing_description = true


## Shrink the description area so choices fit within the fixed panel height.
## The player has already read the description via the typewriter reveal,
## so we can safely reduce it to a single-line summary.
func _collapse_description_for_choices(choice_count: int) -> void:
	if choice_count <= 2:
		return  # Fits fine at current size
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(description_label, "custom_minimum_size:y", 0.0, 0.2)
	tw.tween_property(description_label, "modulate:a", 0.0, 0.15)
	choices_container.add_theme_constant_override("separation", 2)


func _restore_description() -> void:
	description_label.custom_minimum_size.y = 80.0
	description_label.modulate.a = 1.0
	choices_container.remove_theme_constant_override("separation")


## Create a choice button styled to fit compactly when many options exist.
func _create_choice_button(_index: int, text: String, total_choices: int) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn.modulate.a = 0.0
	btn.position.x = 14.0
	if total_choices > 2:
		btn.add_theme_font_size_override("font_size", 13)
	return btn


static func _strip_outer_quotes(text: String) -> String:
	if text.length() >= 2 and text.begins_with("\"") and text.ends_with("\""):
		return text.substr(1, text.length() - 2)
	return text


# ---------------------------------------------------------------------------
# Text styling
# ---------------------------------------------------------------------------

func _apply_parchment_text_style() -> void:
	title_label.add_theme_color_override("font_color", PARCHMENT_TITLE_COLOR)
	title_label.add_theme_font_size_override("font_size", 26)
	description_label.add_theme_color_override("default_color", PARCHMENT_DESC_COLOR)
	left_name_label.add_theme_color_override("font_color", PARCHMENT_NAME_COLOR)
	right_name_label.add_theme_color_override("font_color", PARCHMENT_NAME_COLOR)


func _restore_default_text_style() -> void:
	title_label.add_theme_color_override("font_color", DEFAULT_TITLE_COLOR)
	title_label.remove_theme_font_size_override("font_size")
	description_label.remove_theme_color_override("default_color")
	left_name_label.add_theme_color_override("font_color", DEFAULT_NAME_COLOR)
	right_name_label.add_theme_color_override("font_color", DEFAULT_NAME_COLOR)
