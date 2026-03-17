## Dialogue UI — encounter choices and outcome display.
## Mirrors Python ui/dialogue_ui.py DialogueState.
extends Control

@onready var title_label: Label = $Panel/HBox/VBox/Title
@onready var description_label: RichTextLabel = $Panel/HBox/VBox/Description
@onready var choices_container: VBoxContainer = $Panel/HBox/VBox/ChoicesContainer
@onready var portrait_rect: TextureRect = $Panel/HBox/PortraitContainer/PortraitRect
@onready var portrait_container: VBoxContainer = $Panel/HBox/PortraitContainer
@onready var name_label: Label = $Panel/HBox/PortraitContainer/NameLabel

var encounter: Encounter = null
var on_complete: Callable = Callable()
var on_combat: Callable = Callable()
var _reveal_accumulator: float = 0.0
var _revealing_description: bool = false
var _active_description_text: String = ""

const DESCRIPTION_REVEAL_CPS: float = 95.0

# Character portrait paths keyed by npc_id
const CHARACTER_PORTRAITS := {
	"aristotle": "res://assets/characters/aristotle_head.png",
	"dave": "res://assets/characters/dave_head.png",
	"death": "res://assets/characters/death_head.png",
}


func setup(p_encounter: Encounter) -> void:
	encounter = p_encounter
	_build_ui()


func _ready() -> void:
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


func _build_ui() -> void:
	if encounter == null:
		return
	title_label.text = encounter.title
	_set_description(encounter.description)
	_setup_portrait()
	# Clear old choice buttons
	for child in choices_container.get_children():
		child.queue_free()
	# Build choice buttons
	for i in range(encounter.choices.size()):
		var choice: Encounter.EncounterChoice = encounter.choices[i]
		var btn := Button.new()
		btn.text = "[%d] %s" % [i + 1, choice.text]
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.modulate.a = 0.0
		btn.position.x = 14.0
		btn.pressed.connect(_on_choice_selected.bind(i))
		choices_container.add_child(btn)
		var tween := create_tween()
		tween.set_parallel(true)
		tween.tween_property(btn, "modulate:a", 1.0, 0.12).set_delay(0.05 * i)
		tween.tween_property(btn, "position:x", 0.0, 0.12).set_delay(0.05 * i)
		if i == 0:
			btn.call_deferred("grab_focus")


func _set_description(text: String) -> void:
	_active_description_text = text
	description_label.text = text
	description_label.visible_characters = 0
	_reveal_accumulator = 0.0
	_revealing_description = true


func _setup_portrait() -> void:
	if encounter == null:
		return
	var npc_id := ""
	if encounter.npc_ids.size() > 0:
		npc_id = encounter.npc_ids[0].to_lower()
	var portrait_path: String = CHARACTER_PORTRAITS.get(npc_id, "")
	if portrait_path.is_empty() or not ResourceLoader.exists(portrait_path):
		portrait_container.visible = false
		return
	portrait_container.visible = true
	portrait_container.modulate.a = 0.0
	var texture: Texture2D = load(portrait_path)
	if texture != null:
		texture = _remove_near_white_bg(texture)
		portrait_rect.texture = texture
	name_label.text = npc_id.capitalize()
	var tween := create_tween()
	tween.tween_property(portrait_container, "modulate:a", 1.0, 0.2)


static func _remove_near_white_bg(
	tex: Texture2D, hard_threshold: float = 0.91, soft_threshold: float = 0.77
) -> Texture2D:
	"""Make bright neutral background pixels transparent, with soft feathering."""
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
	_set_description(outcome_text)
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
