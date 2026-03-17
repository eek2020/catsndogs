## Ending screen — game completion summary and return to menu.
## Mirrors Python ui/ending_screen.py EndingState.
extends Control

@onready var summary_label: RichTextLabel = $VBox/Summary
@onready var menu_btn: Button = $VBox/MenuBtn

var _summary_reveal_accumulator: float = 0.0
var _revealing_summary: bool = false

const SUMMARY_REVEAL_CPS: float = 120.0


func _ready() -> void:
	menu_btn.pressed.connect(_on_menu)
	menu_btn.modulate.a = 0.0
	summary_label.modulate.a = 0.0
	menu_btn.grab_focus()
	_build_summary()
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(summary_label, "modulate:a", 1.0, 0.35)
	tween.tween_property(menu_btn, "modulate:a", 1.0, 0.45).set_delay(0.12)


func _process(dt: float) -> void:
	if not _revealing_summary:
		return
	_summary_reveal_accumulator += dt * SUMMARY_REVEAL_CPS
	summary_label.visible_characters = mini(
		summary_label.get_total_character_count(),
		int(_summary_reveal_accumulator)
	)
	if summary_label.visible_characters >= summary_label.get_total_character_count():
		_revealing_summary = false


func _build_summary() -> void:
	var gs: GameStateData = GameSession.game_state
	summary_label.bbcode_enabled = true
	if gs == null:
		summary_label.text = "[b]Your journey has ended.[/b]"
		return
	var lines: Array[String] = []
	var captain_name := gs.player_character.character_name if gs.player_character else "Aristotle"
	lines.append("[font_size=24][b]Captain %s's journey is complete.[/b][/font_size]" % captain_name)
	lines.append("")
	lines.append("[color=#96c8ff][b]VOYAGE SUMMARY[/b][/color]")
	lines.append("Final Arc: %s" % gs.current_arc.replace("_", " ").to_upper())
	lines.append("Crystals Collected: %d" % gs.crystal_inventory)
	lines.append("Salvage Recovered: %d" % gs.salvage)
	lines.append("Encounters Completed: %d" % gs.completed_encounters.size())
	lines.append("Decisions Made: %d" % gs.player_decisions.size())
	var completed_missions: int = 0
	var failed_missions: int = 0
	for m in gs.side_missions.values():
		if m.status == "completed":
			completed_missions += 1
		elif m.status == "failed":
			failed_missions += 1
	lines.append("Missions Completed: %d" % completed_missions)
	lines.append("Missions Failed: %d" % failed_missions)
	lines.append("")
	if gs.protagonist_id == "dave":
		lines.append("[color=#96c8ff]Commander Dave's campaign has concluded.[/color]")
	lines.append("[color=#f0d47a]Thank you for playing Whisper Crystals.[/color]")
	summary_label.text = "\n".join(lines)
	summary_label.visible_characters = 0
	_summary_reveal_accumulator = 0.0
	_revealing_summary = true


func _on_menu() -> void:
	GameSession.quit_to_menu()
	var main: Control = get_tree().current_scene
	if main.has_method("switch_scene"):
		main.switch_scene("menu")
