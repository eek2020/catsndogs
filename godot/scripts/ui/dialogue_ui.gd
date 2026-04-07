## Dialogue UI — encounter choices, outcome display, and multi-step branching dialogue.
## Supports both legacy single-step encounters and new two-sided dialogue_steps encounters.
extends Control

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

# Character portrait paths keyed by npc_id
const CHARACTER_PORTRAITS := {
	"aristotle": "res://assets/characters/aristotle_head.png",
	"dave": "res://assets/characters/dave_head.png",
	"death": "res://assets/characters/death_head.png",
	"fairy_cartographer": "res://assets/characters/support/fairy_cartographer.png",
	"nine_lives": "res://assets/characters/crew/nine_lives.png",
	"no_tail": "res://assets/characters/crew/no_tail.png",
	"silky": "res://assets/characters/crew/silky.png",
	"blood_paw": "res://assets/characters/crew/blood_paw.png",
	"charlie": "res://assets/characters/crew/charlie.png",
	"bombardier": "res://assets/characters/crew/bombardier.png",
	"luna": "res://assets/characters/crew/luna.png",
	"thistle": "res://assets/characters/crew/thistle.png",
}


func setup(p_encounter: Encounter) -> void:
	encounter = p_encounter
	_build_ui()


func _ready() -> void:
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


func _build_ui() -> void:
	if encounter == null:
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
		_setup_two_portraits()
		_show_step(0)
	else:
		_using_dialogue_steps = false
		_set_description(encounter.description)
		_setup_legacy_portrait()
		_build_legacy_choices()


# ---------------------------------------------------------------------------
# Step map: builds an index from step_id -> array position for branch jumps
# ---------------------------------------------------------------------------
func _build_step_map() -> void:
	_step_map.clear()
	for i in range(encounter.dialogue_steps.size()):
		var step: Encounter.DialogueStep = encounter.dialogue_steps[i]
		if not step.step_id.is_empty():
			_step_map[step.step_id] = i


# ---------------------------------------------------------------------------
# Multi-step dialogue flow
# ---------------------------------------------------------------------------
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

	# Highlight the active speaker
	_highlight_speaker(step.speaker)

	# Clear old choice buttons
	for child in choices_container.get_children():
		child.queue_free()

	# Start typewriter reveal
	_set_description(step.text)

	# Wait for typewriter to finish
	while _revealing_description:
		await get_tree().process_frame

	# Now decide what happens next
	if step.start_combat:
		await _reading_pause(step.text)
		_complete_and_start_combat()
	elif step.end:
		await _reading_pause(step.text)
		_end_dialogue()
	elif step.choices.size() > 0:
		_show_dialogue_choices(step.choices)
	else:
		# Auto-advance to next sequential step
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
	if encounter == null or GameSession.game_state == null:
		return

	var step: Encounter.DialogueStep = encounter.dialogue_steps[_step_index]
	if choice_index < 0 or choice_index >= step.choices.size():
		return

	var choice: Encounter.DialogueStepChoice = step.choices[choice_index]

	# Apply mid-dialogue outcome (flags, resources, factions) without completing encounter
	GameSession.encounter_engine.apply_dialogue_step_outcome(
		GameSession.game_state, encounter, choice
	)

	# Clear choices and restore description
	for child in choices_container.get_children():
		child.queue_free()
	_restore_description()

	# Jump to the target step
	if not choice.next_step.is_empty():
		if _step_map.has(choice.next_step):
			_show_step(_step_map[choice.next_step])
		else:
			push_warning("DialogueUI: unknown next_step '%s' — ending dialogue." % choice.next_step)
			_end_dialogue()
	else:
		# No next_step specified — advance sequentially
		_show_step(_step_index + 1)


func _end_dialogue() -> void:
	# Check for crew recruitment before popping
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

	# Now complete the encounter (may trigger arc advance + arc_summary overlay)
	if GameSession.game_state != null:
		GameSession.encounter_engine.complete_encounter(GameSession.game_state, encounter)


func _complete_and_start_combat() -> void:
	# Complete the encounter before transitioning to combat
	if GameSession.game_state != null:
		GameSession.encounter_engine.complete_encounter(GameSession.game_state, encounter)

	# Reuse the existing combat setup logic
	_start_combat_from_encounter()


## Check if any crew_*_recruited flag was set during the dialogue.
func _check_crew_recruitment_from_flags() -> String:
	if encounter == null or encounter.mission_type != "crew_recruitment":
		return ""
	if encounter.crew_member_id.is_empty():
		return ""
	var flag_name := "crew_%s_recruited" % encounter.crew_member_id
	if GameSession.game_state != null and GameSession.game_state.story_flags.get(flag_name, false):
		return encounter.crew_member_id
	return ""


# ---------------------------------------------------------------------------
# Two-portrait setup
# ---------------------------------------------------------------------------
func _setup_two_portraits() -> void:
	# Left = Aristotle (player character)
	var protagonist_id: String = "aristotle"
	if GameSession.game_state != null and not GameSession.game_state.protagonist_id.is_empty():
		protagonist_id = GameSession.game_state.protagonist_id
	_load_portrait(left_portrait_rect, left_name_label, left_portrait_container, protagonist_id)

	# Right = first NPC from encounter
	var npc_id := ""
	for nid in encounter.npc_ids:
		if nid.to_lower() != protagonist_id:
			npc_id = nid.to_lower()
			break
	if npc_id.is_empty():
		right_portrait_container.visible = false
	else:
		_load_portrait(right_portrait_rect, right_name_label, right_portrait_container, npc_id)


func _load_portrait(
	rect: TextureRect, name_lbl: Label, container: VBoxContainer, character_id: String
) -> void:
	var portrait_path: String = CHARACTER_PORTRAITS.get(character_id.to_lower(), "")
	if portrait_path.is_empty() or not ResourceLoader.exists(portrait_path):
		container.visible = false
		return
	container.visible = true
	container.modulate.a = 0.4
	var texture: Texture2D = load(portrait_path)
	if texture != null:
		texture = _remove_near_white_bg(texture)
		rect.texture = texture
	name_lbl.text = character_id.capitalize()


func _highlight_speaker(speaker_id: String) -> void:
	var protagonist_id: String = "aristotle"
	if GameSession.game_state != null and not GameSession.game_state.protagonist_id.is_empty():
		protagonist_id = GameSession.game_state.protagonist_id

	var left_active: bool = speaker_id.to_lower() == protagonist_id
	var left_target: float = 1.0 if left_active else 0.4
	var right_target: float = 0.4 if left_active else 1.0

	if left_portrait_container.visible:
		var tw := create_tween()
		tw.tween_property(left_portrait_container, "modulate:a", left_target, 0.15)
	if right_portrait_container.visible:
		var tw := create_tween()
		tw.tween_property(right_portrait_container, "modulate:a", right_target, 0.15)


# ---------------------------------------------------------------------------
# Legacy single-step encounter support (unchanged behavior)
# ---------------------------------------------------------------------------
func _setup_legacy_portrait() -> void:
	# Hide left portrait, show right portrait (original single-portrait on the left side of scene)
	right_portrait_container.visible = false

	if encounter == null:
		left_portrait_container.visible = false
		return
	var npc_id := ""
	if encounter.npc_ids.size() > 0:
		npc_id = encounter.npc_ids[0].to_lower()
	var portrait_path: String = CHARACTER_PORTRAITS.get(npc_id, "")
	if portrait_path.is_empty() or not ResourceLoader.exists(portrait_path):
		left_portrait_container.visible = false
		return
	left_portrait_container.visible = true
	left_portrait_container.modulate.a = 0.0
	var texture: Texture2D = load(portrait_path)
	if texture != null:
		texture = _remove_near_white_bg(texture)
		left_portrait_rect.texture = texture
	left_name_label.text = npc_id.capitalize()
	var tween := create_tween()
	tween.tween_property(left_portrait_container, "modulate:a", 1.0, 0.2)


func _build_legacy_choices() -> void:
	for child in choices_container.get_children():
		child.queue_free()
	_collapse_description_for_choices(encounter.choices.size())
	for i in range(encounter.choices.size()):
		var choice: Encounter.EncounterChoice = encounter.choices[i]
		var btn := _create_choice_button(i, _strip_outer_quotes(choice.text), encounter.choices.size())
		btn.pressed.connect(_on_legacy_choice_selected.bind(i))
		choices_container.add_child(btn)
		var tween := create_tween()
		tween.set_parallel(true)
		tween.tween_property(btn, "modulate:a", 1.0, 0.12).set_delay(0.05 * i)
		tween.tween_property(btn, "position:x", 0.0, 0.12).set_delay(0.05 * i)
		if i == 0:
			btn.call_deferred("grab_focus")


func _on_legacy_choice_selected(index: int) -> void:
	if encounter == null or GameSession.game_state == null:
		return
	var choice: Encounter.EncounterChoice = encounter.choices[index]
	var outcome_text := GameSession.encounter_engine.apply_choice_outcome(
		GameSession.game_state, encounter, index
	)
	if _should_start_combat(choice):
		_start_combat(choice)
		return
	# Check for crew recruitment completion
	var recruited_crew_id := _check_crew_recruitment(choice)
	# Show outcome briefly — restore description, clear choices
	for child in choices_container.get_children():
		child.queue_free()
	_restore_description()
	_set_description(outcome_text)
	while _revealing_description:
		await get_tree().process_frame
	# If crew member was recruited, show confirmation then trigger recruitment
	if not recruited_crew_id.is_empty():
		await _show_crew_recruitment_confirmation(recruited_crew_id)
	await get_tree().create_timer(2.0).timeout
	# Pop ourselves BEFORE triggering the arc check, so that if advance_arc
	# pushes arc_summary it goes on top of navigation, not on top of us.
	var main: Control = get_tree().current_scene
	if main.has_method("pop_overlay"):
		main.pop_overlay()
	# Now trigger the arc-exit check (may push arc_summary overlay)
	GameSession.call_deferred("_deferred_arc_check")


# ---------------------------------------------------------------------------
# Parchment text styling
# ---------------------------------------------------------------------------
const PARCHMENT_TITLE_COLOR := Color(0.35, 0.15, 0.05, 1.0)
const PARCHMENT_DESC_COLOR := Color(0.2, 0.12, 0.05, 1.0)
const PARCHMENT_NAME_COLOR := Color(0.3, 0.12, 0.0, 1.0)
const DEFAULT_TITLE_COLOR := Color(0.94, 0.75, 0.25, 1.0)
const DEFAULT_NAME_COLOR := Color(0.3, 0.8, 0.9, 1.0)


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


# ---------------------------------------------------------------------------
# Shared helpers
# ---------------------------------------------------------------------------
static func _strip_outer_quotes(text: String) -> String:
	if text.length() >= 2 and text.begins_with("\"") and text.ends_with("\""):
		return text.substr(1, text.length() - 2)
	return text


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
	# Fade-shrink the description to make room — keep one visible line as context
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(description_label, "custom_minimum_size:y", 0.0, 0.2)
	tw.tween_property(description_label, "modulate:a", 0.0, 0.15)
	# Tighten spacing between choice buttons
	choices_container.add_theme_constant_override("separation", 2)


## Create a choice button styled to fit compactly when many options exist.
func _create_choice_button(index: int, text: String, total_choices: int) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn.modulate.a = 0.0
	btn.position.x = 14.0
	if total_choices > 2:
		btn.add_theme_font_size_override("font_size", 13)
	return btn


## Restore description visibility after choices are cleared.
func _restore_description() -> void:
	description_label.custom_minimum_size.y = 80.0
	description_label.modulate.a = 1.0
	choices_container.remove_theme_constant_override("separation")


## Make bright neutral background pixels transparent, with soft feathering.
static func _remove_near_white_bg(
	tex: Texture2D, hard_threshold: float = 0.91, soft_threshold: float = 0.77
) -> Texture2D:
	if tex == null:
		return tex
	var image: Image = tex.get_image()
	if image == null:
		return tex
	image.convert(Image.FORMAT_RGBA8)
	var w: int = image.get_width()
	var h: int = image.get_height()
	for y in h:
		for x in w:
			var c: Color = image.get_pixel(x, y)
			var whiteness: float = minf(c.r, minf(c.g, c.b))
			if whiteness >= hard_threshold:
				image.set_pixel(x, y, Color(c.r, c.g, c.b, 0.0))
			elif whiteness >= soft_threshold:
				var span: float = maxf(0.001, hard_threshold - soft_threshold)
				var alpha_scale: float = (hard_threshold - whiteness) / span
				image.set_pixel(x, y, Color(c.r, c.g, c.b, c.a * alpha_scale))
	return ImageTexture.create_from_image(image)


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
	GameSession.recruit_crew_member(crew_id)
	var defn: Dictionary = GameSession.crew_trait_system.get_definition(crew_id)
	if defn.is_empty():
		return
	var crew_name: String = defn.get("name", crew_id)
	var role: String = defn.get("role", "").replace("_", " ").capitalize()
	var trait_desc: String = defn.get("trait_description", "")
	var confirm_text := "[b]%s[/b] has joined your crew as [b]%s[/b]!\n%s" % [crew_name, role, trait_desc]
	_set_description(confirm_text)
	while _revealing_description:
		await get_tree().process_frame
	await get_tree().create_timer(2.5).timeout


func _should_start_combat(choice: Encounter.EncounterChoice) -> bool:
	if encounter == null or choice == null:
		return false
	return encounter.encounter_type == "combat"


func _start_combat(choice: Encounter.EncounterChoice) -> void:
	var game_state: GameStateData = GameSession.game_state
	if game_state == null:
		return

	var enemy_faction := "canis_league"
	for faction_id in choice.outcome.faction_changes.keys():
		enemy_faction = String(faction_id)
		break

	_do_combat_transition(enemy_faction)


## Start combat from a dialogue step (uses encounter npc_ids for faction).
func _start_combat_from_encounter() -> void:
	var game_state: GameStateData = GameSession.game_state
	if game_state == null:
		return

	# Derive enemy faction from npc_ids or encounter data
	var enemy_faction := "canis_league"
	for npc_id in encounter.npc_ids:
		if npc_id.to_lower() != "aristotle":
			# Look up the faction associated with this NPC in the faction registry
			for faction_id in game_state.faction_registry:
				var faction: Faction = game_state.faction_registry[faction_id]
				if faction.faction_id == npc_id or faction.faction_name.to_lower().find(npc_id) >= 0:
					enemy_faction = faction_id
					break
			break

	_do_combat_transition(enemy_faction)


func _do_combat_transition(enemy_faction: String) -> void:
	var game_state: GameStateData = GameSession.game_state
	if game_state == null:
		return

	var templates: Dictionary = GameSession.data_loader.load_ship_templates()
	var faction: Faction = game_state.faction_registry.get(enemy_faction)
	var template_id: String = "league_cruiser"
	if faction != null and not faction.ship_template_id.is_empty():
		template_id = faction.ship_template_id
	var enemy_template: Dictionary = templates.get(template_id, templates.get("league_cruiser", {}))

	var enemy_name := "Enemy Ship"
	if faction != null:
		enemy_name = "%s Ship" % faction.faction_name

	var player_ship: CombatSystem.CombatShip = CombatSystem.CombatShip.from_game_ship(game_state.player_ship, true)
	var enemy_ship: CombatSystem.CombatShip = CombatSystem.CombatShip.from_template(
		enemy_template,
		enemy_name,
		enemy_faction
	)

	var main: Control = get_tree().current_scene
	if main.has_method("replace_overlay"):
		var combat_overlay: Control = main.replace_overlay(self, "combat")
		if combat_overlay and combat_overlay.has_method("setup"):
			combat_overlay.setup(player_ship, enemy_ship)
		return

	if not main.has_method("pop_overlay") or not main.has_method("push_overlay"):
		return

	main.pop_overlay()
	await get_tree().create_timer(0.16).timeout
	var combat_screen: Control = main.push_overlay("combat")
	if combat_screen and combat_screen.has_method("setup"):
		combat_screen.setup(player_ship, enemy_ship)
