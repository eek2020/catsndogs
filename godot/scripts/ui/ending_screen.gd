## Ending screen — game completion summary and return to menu.
## Mirrors Python ui/ending_screen.py EndingState.
extends Control

@onready var summary_label: RichTextLabel = $VBox/Summary
@onready var menu_btn: Button = $VBox/MenuBtn


func _ready() -> void:
	menu_btn.pressed.connect(_on_menu)
	menu_btn.grab_focus()
	_build_summary()


func _build_summary() -> void:
	var gs: GameStateData = GameSession.game_state
	if gs == null:
		summary_label.text = "Your journey has ended."
		return
	var lines: Array[String] = []
	lines.append("Captain %s's journey is complete." % (gs.player_character.character_name if gs.player_character else "Aristotle"))
	lines.append("")
	lines.append("Final Arc: %s" % gs.current_arc)
	lines.append("Crystals collected: %d" % gs.crystal_inventory)
	lines.append("Salvage: %d" % gs.salvage)
	lines.append("Encounters completed: %d" % gs.completed_encounters.size())
	lines.append("Decisions made: %d" % gs.player_decisions.size())
	var completed_missions: int = 0
	for m in gs.side_missions.values():
		if m.status == "completed":
			completed_missions += 1
	lines.append("Missions completed: %d" % completed_missions)
	lines.append("")
	lines.append("Thank you for playing Whisper Crystals.")
	summary_label.text = "\n".join(lines)


func _on_menu() -> void:
	GameSession.quit_to_menu()
	var main: Control = get_tree().current_scene
	if main.has_method("switch_scene"):
		main.switch_scene("menu")
