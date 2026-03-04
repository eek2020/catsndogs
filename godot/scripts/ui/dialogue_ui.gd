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
	var choice: Encounter.EncounterChoice = encounter.choices[index]
	var outcome_text := GameSession.encounter_engine.apply_choice_outcome(
		GameSession.game_state, encounter, index
	)
	if _should_start_combat(choice):
		_start_combat(choice)
		return
	# Show outcome briefly
	description_label.text = outcome_text
	for child in choices_container.get_children():
		child.queue_free()
	await get_tree().create_timer(2.0).timeout
	# Return to navigation
	var main: Control = get_tree().current_scene
	if main.has_method("pop_overlay"):
		main.pop_overlay()


func _should_start_combat(choice: Encounter.EncounterChoice) -> bool:
	if encounter == null or choice == null:
		return false
	if encounter.encounter_type != "combat":
		return false
	return choice.choice_id.to_lower().contains("fight")


func _start_combat(choice: Encounter.EncounterChoice) -> void:
	var game_state: GameStateData = GameSession.game_state
	if game_state == null:
		return

	var enemy_faction := "canis_league"
	for faction_id in choice.outcome.faction_changes.keys():
		enemy_faction = String(faction_id)
		break

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
	var combat_overlay: Control = main.push_overlay("combat")
	if combat_overlay and combat_overlay.has_method("setup"):
		combat_overlay.setup(player_ship, enemy_ship)
