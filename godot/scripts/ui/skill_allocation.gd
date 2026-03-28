## Skill allocation screen — redistribute starting stat points before gameplay.
##
## Shown after character selection. The player distributes a fixed pool of
## skill points across six stats, then confirms to begin the game.
extends Control

const STAT_NAMES: Array[String] = [
	"cunning", "leadership", "negotiation",
	"combat_skill", "intimidation", "stealth",
]
const MIN_STAT: int = 1
const MAX_STAT: int = 10

@onready var title_label: Label = $VBox/Title
@onready var pool_label: Label = $VBox/PoolLabel
@onready var stat_container: VBoxContainer = $VBox/StatContainer
@onready var preset_container: HBoxContainer = $VBox/PresetContainer
@onready var confirm_btn: Button = $VBox/ConfirmBtn
@onready var back_btn: Button = $VBox/BackBtn

var _stat_values: Dictionary = {}
var _total_pool: int = 0
var _remaining: int = 0
var _protagonist_id: String = ""
var _default_stats: Dictionary = {}
var _stat_rows: Dictionary = {}  # stat_name -> {minus_btn, plus_btn, value_label, bar_label}


func _ready() -> void:
	confirm_btn.pressed.connect(_on_confirm)
	back_btn.pressed.connect(_on_back)

	_protagonist_id = GameSession.game_state.protagonist_id if GameSession.game_state else "aristotle"
	var character: Character = GameSession.game_state.player_character if GameSession.game_state else null
	if character == null:
		return

	# Read default stats from character
	for stat_name in STAT_NAMES:
		_default_stats[stat_name] = StatEvaluator._get_stat(character, stat_name)
		_stat_values[stat_name] = _default_stats[stat_name]

	_total_pool = StatEvaluator.get_total_points(character)
	_remaining = 0

	title_label.text = "HARMONIC ATTUNEMENT"

	_build_stat_rows()
	_build_presets()
	_update_display()

	# Fade in
	modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.3)
	confirm_btn.grab_focus()


func _build_stat_rows() -> void:
	for stat_name in STAT_NAMES:
		var row := HBoxContainer.new()
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		var name_label := Label.new()
		name_label.text = stat_name.replace("_", " ").capitalize()
		name_label.custom_minimum_size.x = 160
		row.add_child(name_label)

		var minus_btn := Button.new()
		minus_btn.text = "-"
		minus_btn.custom_minimum_size.x = 36
		minus_btn.pressed.connect(_on_stat_change.bind(stat_name, -1))
		row.add_child(minus_btn)

		var value_label := Label.new()
		value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		value_label.custom_minimum_size.x = 40
		row.add_child(value_label)

		var plus_btn := Button.new()
		plus_btn.text = "+"
		plus_btn.custom_minimum_size.x = 36
		plus_btn.pressed.connect(_on_stat_change.bind(stat_name, 1))
		row.add_child(plus_btn)

		var bar_label := Label.new()
		bar_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(bar_label)

		stat_container.add_child(row)
		_stat_rows[stat_name] = {
			"minus_btn": minus_btn,
			"plus_btn": plus_btn,
			"value_label": value_label,
			"bar_label": bar_label,
		}


func _build_presets() -> void:
	# Default preset
	var default_btn := Button.new()
	default_btn.text = "Default"
	default_btn.pressed.connect(_apply_preset.bind(_default_stats.duplicate()))
	preset_container.add_child(default_btn)

	# Warrior preset — heavy combat and intimidation
	var warrior: Dictionary = _create_preset({"combat_skill": 3, "intimidation": 2, "stealth": 1}, {"negotiation": -3, "leadership": -2, "cunning": -1})
	var warrior_btn := Button.new()
	warrior_btn.text = "Warrior"
	warrior_btn.pressed.connect(_apply_preset.bind(warrior))
	preset_container.add_child(warrior_btn)

	# Diplomat preset — heavy negotiation and leadership
	var diplomat: Dictionary = _create_preset({"negotiation": 3, "leadership": 2, "cunning": 1}, {"combat_skill": -3, "intimidation": -2, "stealth": -1})
	var diplomat_btn := Button.new()
	diplomat_btn.text = "Diplomat"
	diplomat_btn.pressed.connect(_apply_preset.bind(diplomat))
	preset_container.add_child(diplomat_btn)

	# Shadow preset — heavy stealth and cunning
	var shadow: Dictionary = _create_preset({"stealth": 3, "cunning": 2, "intimidation": 1}, {"leadership": -3, "negotiation": -2, "combat_skill": -1})
	var shadow_btn := Button.new()
	shadow_btn.text = "Shadow"
	shadow_btn.pressed.connect(_apply_preset.bind(shadow))
	preset_container.add_child(shadow_btn)


func _create_preset(bonuses: Dictionary, penalties: Dictionary) -> Dictionary:
	var preset: Dictionary = _default_stats.duplicate()
	for stat_name in bonuses:
		preset[stat_name] = clampi(preset[stat_name] + bonuses[stat_name], MIN_STAT, MAX_STAT)
	for stat_name in penalties:
		preset[stat_name] = clampi(preset[stat_name] + penalties[stat_name], MIN_STAT, MAX_STAT)
	# Ensure total matches pool
	var total: int = 0
	for stat_name in STAT_NAMES:
		total += preset[stat_name]
	# Adjust largest stat to match pool
	if total != _total_pool:
		var diff: int = _total_pool - total
		var highest_stat: String = "cunning"
		var highest_val: int = 0
		for stat_name in STAT_NAMES:
			if preset[stat_name] > highest_val:
				highest_val = preset[stat_name]
				highest_stat = stat_name
		preset[highest_stat] = clampi(preset[highest_stat] + diff, MIN_STAT, MAX_STAT)
	return preset


func _apply_preset(preset: Dictionary) -> void:
	for stat_name in STAT_NAMES:
		_stat_values[stat_name] = preset.get(stat_name, _default_stats.get(stat_name, 5))
	_recalculate_remaining()
	_update_display()


func _on_stat_change(stat_name: String, delta: int) -> void:
	var current: int = _stat_values[stat_name]
	var new_value: int = current + delta
	if new_value < MIN_STAT or new_value > MAX_STAT:
		return
	if delta > 0 and _remaining <= 0:
		return
	_stat_values[stat_name] = new_value
	_recalculate_remaining()
	_update_display()


func _recalculate_remaining() -> void:
	var used: int = 0
	for stat_name in STAT_NAMES:
		used += _stat_values[stat_name]
	_remaining = _total_pool - used


func _update_display() -> void:
	pool_label.text = "Skill Points: %d / %d remaining" % [_remaining, _total_pool]
	if _remaining == 0:
		pool_label.add_theme_color_override("font_color", Color(0.3, 0.8, 0.4))
	elif _remaining < 0:
		pool_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
	else:
		pool_label.add_theme_color_override("font_color", Color(0.9, 0.75, 0.25))

	for stat_name in STAT_NAMES:
		var row: Dictionary = _stat_rows[stat_name]
		var val: int = _stat_values[stat_name]
		row["value_label"].text = str(val)
		row["bar_label"].text = "|".repeat(val)
		row["minus_btn"].disabled = (val <= MIN_STAT)
		row["plus_btn"].disabled = (val >= MAX_STAT or _remaining <= 0)

	confirm_btn.disabled = (_remaining != 0)


func _on_confirm() -> void:
	if _remaining != 0:
		return
	# Apply stats to the player character
	var character: Character = GameSession.game_state.player_character
	if character == null:
		return
	for stat_name in STAT_NAMES:
		StatEvaluator.set_stat(character, stat_name, _stat_values[stat_name])
	EventBus.stats_changed.emit(character.character_id)
	# Continue to cutscene
	var main: Control = get_tree().current_scene
	if main.has_method("switch_scene"):
		main.switch_scene("intro_crawl")


func _on_back() -> void:
	# Go back to character select (reset game state)
	GameSession.game_state = null
	var main: Control = get_tree().current_scene
	if main.has_method("switch_scene"):
		main.switch_scene("character_select")
